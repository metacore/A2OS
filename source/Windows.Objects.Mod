 (* Aos, Copyright 2001, Pieter Muller, ETH Zurich; this module ported for the windows version, fof. *)

MODULE Objects;   (** AUTHOR "pjm, ejz, fof"; PURPOSE "Active object runtime support"; *)

IMPORT SYSTEM, Trace, Kernel32, Machine, Modules, Heaps;

CONST
	HandleExcp = TRUE;   (* FALSE -> we asume that it is done correctly by Traps *)
	TraceVerbose = FALSE;
	StrongChecks = FALSE;  defaultStackSize = 0;
	TraceOpenClose = FALSE;

CONST
	(* Process flags *)
	Restart* = 0;   (* Restart/Destroy process on exception *)
	PleaseHalt* = 10;   (* Process requested to Halt itself soon *)
	Unbreakable* = 11;
	SelfTermination* = 12;
	Preempted* = 27;   (* Has been preempted. *)
	Resistant* = 28;   (* Can only be destroyed by itself *)
	PleaseStop* = 31;   (* Process requested to Terminate or Halt itself soon *)
(*#IF SHAREDLIB THEN*)
	External = 13; (* external (non A2) process attached in case of a DLL *)
(*#END;*)

	InActive* = 26;   (* needed to prevent processes to call finalizers while in await or lock or unlock, see Kernel.GC *)

	(** Process modes *)
	Unknown* = 0; Ready* = 1; (* for compatibility with native A2 *)
	Running* = 2; AwaitingLock* = 3; AwaitingCond* = 4; AwaitingEvent* = 5; Suspended* = 6; Terminated* = 7;

	(** Process priorities *)
	MinPriority = 0;							(* only system idle processes run at this priority level *)
	Low* = 1; Normal* = 2; High* = 3;		(* "user" priorities *)
	GCPriority* = 4;							(* priority of garbage collector *)
	Realtime* = 5;							(* reserved for interrupt handling and realtime apps, these processes are not allowed to allocate memory *)

	(* Process termination halt codes *)
	halt* = 2222;
	haltUnbreakable* = 2223;


TYPE
	CpuCyclesArray* = ARRAY Machine.MaxCPU OF HUGEINT;

	ProtectedObject = POINTER TO RECORD END;   (* protected object (10000) *)

	ProcessQueue = Heaps.ProcessQueue;

	Body = PROCEDURE (self: ProtectedObject);
	Condition = PROCEDURE (slink: ADDRESS): BOOLEAN;

	EventHandler* = PROCEDURE {DELEGATE};
	RealtimeEventHandler* = PROCEDURE {DELEGATE, REALTIME};

	Timer* = POINTER TO RECORD
		next, prev : Timer;
		trigger: LONGINT;
		handler: EventHandler
	END;

	RealtimeTimer* = POINTER TO RECORD
		next, prev: RealtimeTimer;
		trigger: LONGINT;
		handler: RealtimeEventHandler
	END;

	Clock = OBJECT
		VAR h: Timer;
			ticks: LONGINT;
			hevent: Kernel32.HANDLE;
			res: Kernel32.BOOL;
			mode: LONGINT;
			process: Process;
			exiting: BOOLEAN;

		PROCEDURE Wakeup;
		VAR res: Kernel32.BOOL;
		BEGIN {EXCLUSIVE}
			res := Kernel32.SetEvent(hevent)
		END Wakeup;
		
		PROCEDURE Exit;
		BEGIN
			exiting := TRUE;
			Wakeup;
		END Exit;

		PROCEDURE Finalize(ptr: ANY);
		BEGIN
			Exit;
		END Finalize;

		PROCEDURE &Init*;
		VAR fn: Heaps.FinalizerNode;
		BEGIN
			hevent := Kernel32.CreateEvent(NIL, 0, 0, NIL);
			ASSERT(hevent # 0);
			NEW(fn); fn.finalizer := SELF.Finalize; Heaps.AddFinalizer(SELF, fn)
		END Init;

	BEGIN {ACTIVE, SAFE, PRIORITY(High)}
		process := CurrentProcess();
		mode := process.mode;
		LOOP
			Machine.Acquire(Machine.Objects);
			process.mode := mode;
			LOOP
				h := event.next;  (* event: head of timer event queue *)
				ticks := Kernel32.GetTickCount();
				IF (h = event) OR (h.trigger - ticks > 0) THEN EXIT END;
				event.next := h.next;  event.next.prev := event;   (* unlink *)
				h.next := NIL;  h.prev := NIL;
				Machine.Release(Machine.Objects);
				h.handler();   (* assume handler will return promptly *)
				Machine.Acquire(Machine.Objects)
			END;
			mode := process.mode;
			process.mode := AwaitingEvent;
			Machine.Release(Machine.Objects);
			IF h = event THEN (* sentinel head of timer event queue: wait forever until a new event has been entered in queue *)
				res := Kernel32.WaitForSingleObject(hevent, MAX(LONGINT));
			ELSE
				res := Kernel32.WaitForSingleObject(hevent, h.trigger - ticks);
			END;
			IF exiting THEN EXIT; END;
		END;
		process.mode := Running; (*! avoid a trap in terminate *)
		IF hevent # 0 THEN res := Kernel32.CloseHandle(hevent); END;
	END Clock;

TYPE

	Win32Event = Kernel32.HANDLE;
	
	GCContext = RECORD
		nextPos: SIZE; (* 0 to start with *)
		(*first,*)  last: ARRAY 256 OF ADDRESS; (* first might be not required *)
	END;

	Process* = OBJECT(Heaps.ProcessLink)
	VAR
		rootedNext : Process; (*  to prevent process to be GCed in WinAos *)
		obj-: ProtectedObject;   (* associated active object *)
		state- {ALIGNED=16}: Kernel32.Context;
		condition-: Condition;   (* awaited process' condition *)
		condFP-: ADDRESS;   (* awaited process' condition's context *)
		mode-: LONGINT;   (* process state *)  (* only changed inside Objects lock ??? *)
		procID-: LONGINT;   (* processor ID where running,  exported for compatibilty , useless in WinAos *)
		waitingOn-: ProtectedObject;   (* obj this process is waiting on (for lock or condition) *)
		id-: LONGINT;   (* unique process ID for tracing *)
		flags*: SET;   (* process flags *)
		priority-: LONGINT;   (* process priority *)

		stackBottom: ADDRESS;
		handle-: Kernel32.HANDLE; (* handle to corresponding Windows thread *)
		body: Body;
		event: Win32Event;
		restartPC-: ADDRESS;   (** entry point of body, for SAFE exception recovery *)
		restartSP-: ADDRESS;   (** stack level at start of body, for SAFE exception recovery *)

		lastThreadTimes: HUGEINT;   (*ALEX 2005.12.12*)
		gcContext: GCContext;
		context: ANY; (* commands contect *)

		PROCEDURE FindRoots;   (* override, called while GC, replaces Threads.CheckStacks *)
		VAR sp: ADDRESS; res: Kernel32.BOOL; pc, bp: ADDRESS;
			n,adr: ADDRESS; desc {UNTRACED}: Modules.ProcedureDescPointer; p {UNTRACED}: ANY; i: SIZE;
			a0,a1, obp, osb, osbp, opc, gbp: ADDRESS;
			O: ANY; ID: LONGINT;
			mod {UNTRACED}: Modules.Module;
			proc {UNTRACED}: Modules.ProcedureDescPointer;
			modName: ARRAY 128 OF CHAR;
			contextPos: SIZE;
		BEGIN{UNCHECKED} (* avoid winapi call indirection *)
			O := obj; ID := id;
			IF (handle = 0) OR (mode = Terminated) OR (mode < Ready) (* procedure Wrapper not yet started *)
			OR (priority > High) (* stack of GC and realtime processes not traced *) THEN
				RETURN
			END;
						
			IF CurrentProcess() = SELF THEN
				sp := SYSTEM.GetStackPointer();  bp :=SYSTEM.GetFramePointer(); pc := Machine.CurrentPC(); 
			ELSE
				(*! this should never happen or must be changed with mode change eetc.
					res := Kernel32.SuspendThread(handle); (* can suspend a suspended thread -- no problem at all *)
				*)
				state.ContextFlags := Kernel32.ContextControl + Kernel32.ContextInteger;
				res := Kernel32.GetThreadContext( handle, state );
				IF res = 0 THEN Trace.String("could not get thread context:"); Trace.Int(Kernel32.GetLastError(),1) END;
				
				sp :=  state.SP; bp := state.BP; pc := state.PC;
				
				mod := Modules.ThisModuleByAdr0(pc);
				IF mod # NIL THEN
					COPY(mod.name, modName);
					proc := Modules.FindProc(pc,mod.procTable);
				END;
				
				obp := bp; osb := stackBottom; opc := pc;
				osbp := state.BP;
			END;
			
			IF TraceProcessHook # NIL THEN
				TraceProcessHook(SELF,pc,bp,sp,stackBottom);
			END;

			contextPos := gcContext.nextPos;
			IF contextPos < 0 THEN RETURN END; (* this thread is currently not active in A2 *)
			(* stack garbage collection *)

			IF Heaps.GCType= Heaps.HeuristicStackInspectionGC THEN
			#IF I386 THEN
				Heaps.Candidate( state.RDI );  Heaps.Candidate( state.RSI );
				Heaps.Candidate( state.RB ); Heaps.Candidate( state.RD );
				Heaps.Candidate( state.RC ); Heaps.Candidate( state.RA );
			#ELSIF AMD64 THEN
				Heaps.Candidate( state.RDI );  Heaps.Candidate( state.RSI );
				Heaps.Candidate( state.RB ); Heaps.Candidate( state.RD );
				Heaps.Candidate( state.RC ); Heaps.Candidate( state.RA );
				Heaps.Candidate( state.R9 );  Heaps.Candidate( state.R10 );
				Heaps.Candidate( state.R11 ); Heaps.Candidate( state.R12 );
				Heaps.Candidate( state.R13 ); Heaps.Candidate( state.R14 );
				Heaps.Candidate( state.R15 );
			#ELSE
				ASSERT(FALSE);
			#END
				
				IF (stackBottom # 0) & (sp # 0) THEN
					Heaps.RegisterCandidates( sp, stackBottom - sp );
				END;
			ELSIF Heaps.GCType = Heaps.MetaDataForStackGC THEN
				IF TraceVerbose THEN
					Trace.String("GC, process id = "); Trace.Int(id,1); Trace.Ln;
				END;
				LOOP
					IF (bp = NIL) OR (bp >= stackBottom) THEN EXIT END;
					IF Machine.ValidHeapAddress(pc) THEN
						(* ok, valid stack frame from A2, we can trace this *)
					ELSE
						(* no, cannot trace this Windows stack frame, we have to check if we recorded when we exited A2 previously *)
						bp := NIL;
						WHILE (contextPos > 0) & (bp = NIL) DO
							DEC(contextPos); 
							bp := gcContext.last[contextPos]; 
						END; 
						IF bp = NIL THEN
							EXIT;
						END;
					END;
					
					SYSTEM.GET(bp, n);
					IF ODD(n) THEN (* procedure descriptor at bp *)
						desc := SYSTEM.VAL(Modules.ProcedureDescPointer, n-1);
						IF desc # NIL THEN
							IF TraceVerbose THEN
								WriteType(desc); Trace.Ln;
							END;
							a0 := ADDRESSOF(desc.offsets);
							a1 :=  SYSTEM.VAL(ADDRESS, desc.offsets);
							ASSERT(a0+SIZEOF(ADDRESS)=a1,54321);
							FOR i := 0 TO LEN(desc.offsets)-1 DO
								adr := bp + desc.offsets[i]; (* pointer at offset *)
								SYSTEM.GET(adr, p); (* load pointer *)
								IF p # NIL THEN 
									Heaps.Mark(p);
								END;
							END;
						END;
						SYSTEM.GET(bp + 2*SIZEOF(ADDRESS), pc); 
						SYSTEM.GET(bp + SIZEOF(ADDRESS), bp);
					ELSE (* classical stack frame without procedure descriptor *)
						SYSTEM.GET(bp + SIZEOF(ADDRESS), pc); 
						bp := n; 
					END;
				END;
				(* ASSERT((bp = stackBottom) OR (bp=0) ,12345); can be violated when coming from windows *)
			END; 
			
			IF (CurrentProcess() # SELF) (* & (mode # Suspended) *) THEN
				res := Kernel32.ResumeThread(handle);
				ASSERT(res # -1);
			END;

		END FindRoots;
		
	END Process;

TYPE
	ExceptionHandler* = PROCEDURE(	VAR context: Kernel32.Context;
										VAR excpRec: Kernel32.ExceptionRecord;
										VAR handled: BOOLEAN);


	GCStatusExt = OBJECT(Heaps.GCStatus)
	
	(* called from Heaps.InvokeGC, i.e. this is a hidden upcall. However, it is necessary to take the Machine.Objects lock here since writing
		    the set of variables here must not be interrupted, i.e. atomic writing of the set of variables is absolutely necessary.  They system may hang
		    if the lock is not taken. *)
		PROCEDURE SetgcOngoing(value: BOOLEAN);
		VAR p: Heaps.ProcessLink; cur, r: Process; res: Kernel32.BOOL; num: LONGINT; time: LONGINT;
		BEGIN (* serialize writers *)
			IF value THEN
				(* Low, Medium or High priority process calls this *)
				time := Kernel32.GetTickCount();
				Machine.Acquire(Machine.Objects);
				Machine.Acquire(Machine.Heaps); (* to protect agains concurrent LazySweep *)
				r := CurrentProcess();
				num := 0;
				p := ready.head;
				WHILE p # NIL DO
					cur := p(Process);
					IF ((cur.mode = Ready) OR (cur.mode = Running)) & (cur.priority <= High) & (cur # r) & (cur.gcContext.nextPos >= 0) THEN
						res := Kernel32.SuspendThread(cur.handle);
						ASSERT(res >= 0);
						cur.mode := Suspended
					ELSE INC(num);
					END;
					p := p.next
				END;

				Heaps.CollectGarbage(Modules.root);
				p := ready.head;
				WHILE (p # NIL) DO
					cur := p(Process);
					(* only suspended and awaiting processes of ready queue are resumed *)
					IF cur.mode = Suspended THEN
						res := Kernel32.ResumeThread(cur.handle);
						ASSERT(res >= 0);
						cur.mode := Running
					END;
					p := p.next
				END;

				Machine.Release(Machine.Heaps);
				Machine.Release(Machine.Objects);
				time := Kernel32.GetTickCount()-time;
				IF Heaps.trace THEN Trace.String("GC Called -- duration "); Trace.Int(time,0); Trace.String(" ms."); Trace.Ln END;
				IF finalizerCaller # NIL THEN finalizerCaller.Activate() END;
			END;
		END SetgcOngoing;

	END GCStatusExt;

	FinalizedCollection* = OBJECT
		PROCEDURE RemoveAll*(obj: ANY); (** abstract *)
		BEGIN HALT(301) END RemoveAll;
	END FinalizedCollection;

	FinalizerNode* = POINTER TO RECORD (Heaps.FinalizerNode)
		c*: FinalizedCollection (* base type for collection containing object *)
	END;

	FinalizerCaller = OBJECT  (* separate active object that calls finalizers *)
	VAR n: Heaps.FinalizerNode;
		event: Kernel32.HANDLE;
		process: Process;
		exiting: BOOLEAN;

		PROCEDURE &Init;
		BEGIN
			event := Kernel32.CreateEvent( NIL, Kernel32.False (* automatic *), Kernel32.False, NIL );
			ASSERT(event # 0);
		END Init;

		PROCEDURE Wait(): BOOLEAN;
		VAR res: Kernel32.BOOL; mode: LONGINT;
		BEGIN
			mode := process.mode;
			process.mode := AwaitingEvent;
			res := Kernel32.WaitForSingleObject(event, Kernel32.Infinite);
			process.mode := mode;
			ASSERT(res = Kernel32.WaitObject0);
			IF ~exiting THEN
				RETURN TRUE;
			ELSE
				RETURN FALSE;
			END;
		END Wait;

		PROCEDURE Activate;
		VAR res: Kernel32.BOOL;
		BEGIN
			res := Kernel32.SetEvent(event);
		END Activate;
		
		PROCEDURE Exit;
		BEGIN
			exiting := TRUE;
			Activate;
		END Exit;

	BEGIN {ACTIVE, SAFE, PRIORITY(High)}
		process := CurrentProcess();
		WHILE Wait() DO
			LOOP
				n := Heaps.GetFinalizer();
				IF n = NIL THEN EXIT END;
				IF n IS FinalizerNode THEN
					n( FinalizerNode ).c.RemoveAll( n.objStrong ) (* remove it if it is not removed yet *)
				END;
				IF n.finalizer # NIL THEN
					n.finalizer( n.objStrong ) (* may acquire locks *)
				END
			END;
		END;
		IF event # 0 THEN IGNORE Kernel32.CloseHandle(event); END;
	END FinalizerCaller;

VAR
	awc-, awl-: LONGINT;
	oberonLoop*: ANY;   (* Oberon Loop Process temporary workaround for Threads.oberonLoop *)
	break: ARRAY 16 OF CHAR;
	terminateProc: PROCEDURE;
	ready: ProcessQueue;	(* contains running processes in this implementation *)

	numberOfProcessors: LONGINT; (* cached value of Machine.NumberOfProcessors() *)
	finalizerCaller: FinalizerCaller; (* active object for finalizer process, regarded as aprt of GC *)

	event: Timer; (* list of events *)
	clock: Clock;
	tlsIndex: LONGINT;
	nProcs: LONGINT;

	excplock: Kernel32.CriticalSection;  exceptionhandler: ExceptionHandler;

(* Set the current process' priority. *)
PROCEDURE SetPriority*( priority: LONGINT );
VAR r: Process; prio: LONGINT; res: Kernel32.BOOL;
BEGIN
	ASSERT((priority >= Low) & (priority <= Realtime));   (* priority in bounds *)
	r := CurrentProcess();  r.priority := priority;
	CASE priority OF
	MinPriority:
			prio := Kernel32.ThreadPriorityIdle
	| Low:
			prio := Kernel32.ThreadPriorityBelowNormal
	| High:
			prio := Kernel32.ThreadPriorityAboveNormal
	| GCPriority, Realtime:
			prio := Kernel32.ThreadPriorityTimeCritical
	ELSE  (* Normal *)
		prio := Kernel32.ThreadPriorityNormal
	END;
	res := Kernel32.SetThreadPriority( r.handle, prio );
	ASSERT(r.handle # 0);
	ASSERT(res # 0)
END SetPriority;

(** Return TRUE iff the specified protected object is locked exclusive to the current process. *)
PROCEDURE LockedByCurrent*( obj: ANY ): BOOLEAN;
VAR hdr {UNTRACED}: Heaps.ProtRecBlock; res: BOOLEAN;
BEGIN
	SYSTEM.GET(SYSTEM.VAL(ADDRESS, obj) + Heaps.HeapBlockOffset, hdr);
	ASSERT(hdr IS Heaps.ProtRecBlock);
	Machine.Acquire(Machine.Objects);
	res := (hdr.lockedBy = ActiveObject());
	Machine.Release(Machine.Objects);
	RETURN res
END LockedByCurrent;

PROCEDURE Yield*;
BEGIN
	Kernel32.Sleep(0)
END Yield;

(** Return current process. (DEPRECATED, use ActiveObject) *)
PROCEDURE CurrentProcess*( ): Process;
BEGIN{UNCHECKED} (* makes sure that Enter and Leave are not emitted *)
	RETURN SYSTEM.VAL(Process, Kernel32.TlsGetValue(tlsIndex));
END CurrentProcess;

PROCEDURE CurrentContext*(): ANY;
VAR p: Process;
BEGIN
	p := CurrentProcess();
	IF p # NIL THEN RETURN p.context
	ELSE RETURN NIL
	END;
END CurrentContext;

PROCEDURE SetContext*(context: ANY);
VAR p: Process;
BEGIN
	p := CurrentProcess();
	IF p # NIL THEN p.context := context END;
END SetContext;

(* Return stack bottom of process. For compatibility WinAos/UnixAos/NativeAos  *)
PROCEDURE GetStackBottom*(p: Process): ADDRESS;
BEGIN
	RETURN p.stackBottom
END GetStackBottom;

(** Return the active object currently executing. *)
PROCEDURE ActiveObject* (): ANY;
VAR r: Process;
BEGIN
	r := SYSTEM.VAL(Process, Kernel32.TlsGetValue(tlsIndex));
	RETURN r.obj
END ActiveObject;

(** Return the ID of the active currently executing process. *)
PROCEDURE GetProcessID* (): LONGINT;
VAR r: Process;
BEGIN
	r := SYSTEM.VAL (Process, Kernel32.TlsGetValue( tlsIndex ));
	RETURN r.id
END GetProcessID;

(* Get a process from a queue (NIL if none). Caller must hold lock for specific queue. *)
PROCEDURE Get(VAR queue: ProcessQueue; VAR new: Process);
VAR t: Heaps.ProcessLink;
BEGIN
	t := queue.head;
	IF t = NIL THEN  (* zero elements in queue *)
		(* skip *)
	ELSIF t = queue.tail THEN  (* one element in queue *)
		queue.head := NIL; queue.tail := NIL  (* {(t.next = NIL) & (t.prev = NIL)} *)
	ELSE  (* more than one element in queue *)
		queue.head := t.next; t.next := NIL; queue.head.prev := NIL
	END;
	ASSERT((t = NIL) OR (t.next = NIL ) & (t.prev = NIL)); (* temp strong check *)
	IF t = NIL THEN
		new := NIL
	ELSE
		ASSERT(t IS Process);
		new := t(Process)
	END
END Get;

(* Put a process in a queue. Caller must hold lock for specific queue. *)
(* If t was running, be careful to protect Put and the subsequent SwitchTo with the ready lock. *)
PROCEDURE Put(VAR queue: ProcessQueue; t: Process);
BEGIN (* {t # NIL & t.next = NIL & t.prev = NIL} *)
	IF StrongChecks THEN
		ASSERT((t.next = NIL) & (t.prev = NIL))
	END;
	t.next := NIL; t.prev := NIL; (* ug *)
	IF queue.head = NIL THEN (* queue empty *)
		queue.head := t
	ELSE (* queue not empty *)
		queue.tail.next := t; t.prev := queue.tail
	END;
	queue.tail := t
END Put;


PROCEDURE {WINAPI} ExcpFrmHandler( CONST exceptionPointers: Kernel32.ExceptionPointers): Kernel32.DWORD ;
VAR m: Modules.Module;  eip, ebp, stack: ADDRESS;  pc, handler, fp, sp: ADDRESS;  handled: BOOLEAN;  t: Process;
BEGIN
	handled := FALSE;

	Kernel32.EnterCriticalSection( excplock );

	(*
	fof: commenting this resolved a problem with multiple traps that a are catched with FINALLY statements in Windows Vista
	in Windows XP not necessary if Kernel32.SetThreadContext is not used (better to return gracefully from this handler)
	SetCurrent(excpFrame);
	*)

	t := CurrentProcess();

	IF exceptionhandler = NIL THEN
		Trace.StringLn ( "Objects: No exception handler installed" );
		IF HandleExcp THEN

			Trace.String( "EXCEPTION " );  Trace.Address(exceptionPointers.exception.ExceptionCode);
			Trace.String( " at " );  Trace.Address(exceptionPointers.exception.ExceptionAddress);
			#IF I386 THEN
				Trace.Ln();  Trace.String( "EAX " );  Trace.Hex( exceptionPointers.context.RA, 1 );
				Trace.String( "  EBX " );  Trace.Hex( exceptionPointers.context.RB, 1 );  Trace.Ln();
				Trace.String( "ECX " );  Trace.Hex( exceptionPointers.context.RC, 1 );  Trace.String( "  EDX " );
				Trace.Hex( exceptionPointers.context.RD, 1 );  Trace.Ln();  Trace.String( "EDI " );
				Trace.Hex( exceptionPointers.context.RDI, 1 );  Trace.String( "  ESI " );
				Trace.Hex( exceptionPointers.context.RSI, 1 );  Trace.Ln();  
			#ELSIF AMD64 THEN
				Trace.Ln();  Trace.String( "RAX " );  Trace.Address(exceptionPointers.context.RA);
				Trace.String( "  RBX " );  Trace.Address(exceptionPointers.context.RB);  Trace.Ln();
				Trace.String( "RCX " );  Trace.Address(exceptionPointers.context.RC);  Trace.String( "  RDX " );
				Trace.Address(exceptionPointers.context.RD);  Trace.Ln();  Trace.String( "RDI " );
				Trace.Address(exceptionPointers.context.RDI);  Trace.String( "  RSI " );
				Trace.Address(exceptionPointers.context.RSI);  Trace.Ln(); 
				
				Trace.String( "R8 " ); Trace.Address(exceptionPointers.context.R8);
				Trace.String( " R9 " ); Trace.Address(exceptionPointers.context.R9);  Trace.Ln();  
				Trace.String( "R10 " ); Trace.Address(exceptionPointers.context.R10);
				Trace.String( " R11 " ); Trace.Address(exceptionPointers.context.R11);  Trace.Ln();  
				Trace.String( "R12 " ); Trace.Address(exceptionPointers.context.R12);
				Trace.String( " R13 " ); Trace.Address(exceptionPointers.context.R13);  Trace.Ln();  
				Trace.String( "R14 " ); Trace.Address(exceptionPointers.context.R14);
				Trace.String( " R15 " ); Trace.Address(exceptionPointers.context.R15);  Trace.Ln();  
				Trace.Ln; 
			#ELSE 
				-- UNIMPLEMENTED --
			#END
			
			Trace.String( "BP " );
			Trace.Address(exceptionPointers.context.BP);  Trace.String( "  SP " );
			Trace.Address(exceptionPointers.context.SP);  Trace.Ln();  Trace.String( "PC " );
			Trace.Address(exceptionPointers.context.PC);  Trace.Ln();  
			
			
			Trace.Ln();

			
			eip := exceptionPointers.exception.ExceptionAddress;  ebp := exceptionPointers.context.BP;
			IF eip = 0 THEN SYSTEM.GET( exceptionPointers.context.SP, eip ) END;
			stack := t.stackBottom;
			LOOP
				Trace.String( "at ebp= " );  Trace.Address(ebp);  Trace.String( "H : " );
				m := Modules.ThisModuleByAdr( eip );
				IF m # NIL THEN
					Trace.String( m.name );  Trace.String( " " );
					Trace.Address(eip - SYSTEM.VAL( LONGINT, ADDRESSOF( m.code[0] ) ));
				ELSE Trace.String( "EIP " );  Trace.Address(eip)
				END;
				Trace.Ln();
				IF (ebp # 0) & (ebp < stack) THEN  (* if ebp is 0 in first frame *)
					SYSTEM.GET( ebp + SIZEOF(ADDRESS), eip );   (* return addr from stack *)
					SYSTEM.GET( ebp, ebp );   (* follow dynamic link *)
				ELSE EXIT
				END
			END;
			Trace.Ln();
			
			handled := FALSE;  fp := exceptionPointers.context.BP;  sp := exceptionPointers.context.SP;
			pc := exceptionPointers.context.PC;  handler := Modules.GetExceptionHandler( pc );
			IF handler # -1 THEN  (* Handler in the current PAF *)
				exceptionPointers.context.PC := handler;  handled := TRUE;
				(*SetTrapVariable(pc, fp);  SetLastExceptionState(exc)*)
			ELSE
				WHILE (fp # 0) & (handler = -1) DO
					SYSTEM.GET( fp + SIZEOF(ADDRESS), pc );
					pc := pc - 1;   (*  CALL instruction, machine dependant!!! *)
					handler := Modules.GetExceptionHandler( pc );
					sp := fp;   (* Save the old framepointer into the stack pointer *)
					SYSTEM.GET( fp, fp ) (* Unwind PAF *)
				END;
				IF handler = -1 THEN handled := FALSE;
				ELSE
					exceptionPointers.context.PC := handler;  exceptionPointers.context.BP := fp;  exceptionPointers.context.SP := sp;
					(* SetTrapVariable(pc, fp); SetLastExceptionState(exc);*)
					handled := TRUE
				END
			END;
		ELSE Trace.StringLn ( "Warning: FINALLY statement cannot be treated !" );
		END
	ELSE exceptionhandler(exceptionPointers.context^, exceptionPointers.exception^,handled );
	END;
	IF ~handled THEN 
		exceptionPointers.context.PC := t.restartPC ; 
		exceptionPointers.context.SP := t.restartSP;
		exceptionPointers.context.BP := t.stackBottom;
	ELSIF TraceVerbose THEN Trace.StringLn ( "trying to jump to FINALLY pc..." );
	END;
	Kernel32.LeaveCriticalSection( excplock );

	IF TraceVerbose THEN
		Machine.Acquire (Machine.TraceOutput);
		Trace.String( "recover process; pc=" );  Trace.Address( exceptionPointers.context.PC );
		Trace.String( "; sp= " );  Trace.Address( exceptionPointers.context.SP);  Trace.String( "; bp= " );
		Trace.Address( exceptionPointers.context.BP); Trace.Ln;
		Machine.Release (Machine.TraceOutput);
	END;

	RETURN Kernel32.ExceptionContinueExecution; (* sets thread context and continues where specified in context *)
END ExcpFrmHandler;

PROCEDURE RemoveExcpFrm( VAR excpfrm: Kernel32.ExcpFrm );
VAR this: Kernel32.ExcpFrmPtr;
BEGIN
	IGNORE Kernel32.RemoveVectoredContinueHandler(ExcpFrmHandler);
END RemoveExcpFrm;

PROCEDURE InstallExcpFrm( VAR excpfrm: Kernel32.ExcpFrm );
BEGIN
	Kernel32.AddVectoredContinueHandler(1, ExcpFrmHandler); 
END InstallExcpFrm;

PROCEDURE InQueue( queue: ProcessQueue;  t: Process ): BOOLEAN;
VAR p: Heaps.ProcessLink;
BEGIN
	p := queue.head;
	WHILE (p # NIL ) & (p # t) DO p := p.next;  END;
	RETURN (p = t);
END InQueue;

(* Remove a process from a queue that contains it. Caller must hold lock for specific queue. *)
(* Not intended for frequent use. *)
(* does not check if queue contained t ! *)
PROCEDURE Remove( VAR queue: ProcessQueue;  t: Process );
BEGIN
	IF StrongChecks THEN
		ASSERT(InQueue(queue, t));
		ASSERT(t # NIL);
	END;
	IF t.prev # NIL THEN t.prev.next := t.next END;
	IF t.next # NIL THEN t.next.prev := t.prev END;
	IF t = queue.head THEN queue.head := t.next END;
	IF t = queue.tail THEN queue.tail := t.prev END;
	ASSERT((queue.head = NIL) OR (queue.head.prev = NIL) & (queue.tail.next = NIL));
	t.prev := NIL;  t.next := NIL
END Remove;

PROCEDURE WriteType(obj: ANY);
VAR type: LONGINT;
BEGIN
	IF obj = NIL THEN Trace.String(" > NIL");
	ELSE
		Trace.String(" > ");  SYSTEM.GET(SYSTEM.VAL(LONGINT, obj) + Heaps.TypeDescOffset, type);
		Heaps.WriteType(type);
	END;
END WriteType;

PROCEDURE terminate( t: Process );
VAR hdr {UNTRACED}: Heaps.ProtRecBlock; res: Kernel32.BOOL; shutdown: BOOLEAN;
BEGIN
	IF t = NIL THEN RETURN END;
	(* see Objects.TerminateThis *)
	Machine.Acquire( Machine.Objects );

	IF TraceVerbose OR TraceOpenClose THEN
		Machine.Acquire (Machine.TraceOutput);
		Trace.String( "Terminating process " );  Trace.Int( t.id, 1 );  WriteType( t.obj ); Trace.Ln;
		Machine.Release (Machine.TraceOutput);
	END;

	IF (t.mode = Ready) OR (t.mode = Running) THEN Remove( ready, t );
	ELSIF t.mode = AwaitingLock THEN
		SYSTEM.GET(SYSTEM.VAL(ADDRESS, t.waitingOn) + Heaps.HeapBlockOffset, hdr);
		ASSERT(hdr IS Heaps.ProtRecBlock);
		Remove( hdr.awaitingLock, t );  Machine.Release( Machine.Objects );
		HALT( 97 )
	ELSIF t.mode = AwaitingCond THEN
		SYSTEM.GET(SYSTEM.VAL(ADDRESS, t.waitingOn) + Heaps.HeapBlockOffset, hdr);
		ASSERT(hdr IS Heaps.ProtRecBlock);
		Remove( hdr.awaitingCond, t );  Machine.Release( Machine.Objects );
		HALT( 98 )
	ELSE Machine.Release( Machine.Objects );
		HALT( 99 )
	END;
	t.mode := Terminated;   (* a process can also be "terminated" if the queue containing it is garbage collected *)
	t.stackBottom := 0;  t.state.SP := 0;
	t.restartPC := 0;
	IF t.event # 0 THEN res := Kernel32.CloseHandle( t.event );  t.event := 0 END;
	DEC( nProcs );  shutdown := (nProcs = 0);

	Machine.Release( Machine.Objects );
	IF shutdown THEN
		Trace.StringLn ( " Objects: shutdown" ); Modules.Shutdown( -1 );
		Kernel32.ExitProcess( 0 )
	END
END terminate;

PROCEDURE {WINAPI} Wrapper( lpParameter: ANY ): LONGINT;
VAR t: Process;  obj: ProtectedObject; res: Kernel32.BOOL; bp,sp: ADDRESS;
	excpfrm: Kernel32.ExcpFrm;
BEGIN
	(* it may happen that the garbage collector runs right here and ignores this procedure.
	    This is not a problem since lpParameter (being a reference to a process) is protected by the process lists *)
	Machine.Acquire(Machine.Objects);

	res := Kernel32.TlsSetValue(tlsIndex, SYSTEM.VAL(ADDRESS, lpParameter));
	t := lpParameter(Process);  obj := t.obj;
	ASSERT(res # 0);
	SetPriority(t.priority);
	bp := SYSTEM.GetFramePointer();
	sp := SYSTEM.GetStackPointer();
	t.restartSP := sp;
	t.stackBottom := bp;
	IF t.restartPC = SYSTEM.VAL(ADDRESS, terminateProc) THEN DEC(t.restartSP, SIZEOF(ADDRESS))
	ELSE DEC(t.restartSP, 2*SIZEOF(ADDRESS))
	END;
	IF TraceVerbose THEN
		Machine.Acquire(Machine.TraceOutput);
		Trace.String("New process; restartPC= "); Trace.Address(t.restartPC);
		Trace.String("; stackBottom= ");
		Trace.Address(t.stackBottom);
		Trace.String("; id= ");
		Trace.Int(t.id,0); Trace.Ln;
		Machine.Release(Machine.TraceOutput);
	END;
	t.mode := Running;
	(* now gc is enabled for this process stack *)
	Machine.Release(Machine.Objects);
	(* loop all processes that the GC did not see during process suspending because they were in the very moment being generated (just before the locked section) *)

	(*! should not be necessary any more as GC runs immediately and without scheduling decisions
	WHILE (gcActivity # NIL) & (gcActivity.process # NIL) & (gcActivity.process.mode = Running) DO END;
	*)
	t.body(obj);
	terminate(t);
	RemoveExcpFrm(excpfrm);
	RETURN 0
END Wrapper;

PROCEDURE FinalizeProcess(t: ANY);
VAR p: Process;  res: Kernel32.BOOL;
BEGIN
	p := t(Process);

	IF TraceVerbose THEN
		Machine.Acquire (Machine.TraceOutput);
		Trace.String("Finalizing Process"); Trace.Int(p.id, 1);
		WriteType(p.obj); Trace.Ln;
		Machine.Release (Machine.TraceOutput);
	END;
	IF p.mode # Terminated THEN
		IF p.mode = AwaitingLock THEN DEC(awl);
		ELSIF p.mode = AwaitingCond THEN DEC(awc);
		END;
		(* no reference to the object any more *)
		Trace.String ("Closing unreferenced process"); (*Trace.Int(p.mode,20); Trace.Int( p.id, 20 ); *) Trace.Ln; (* Trace.Ln *)
		(* this usually happens, when an objects process waits on its own objtec and no reference exists any more. Then the object is discarded and
		consequently the process is unreferenced (except in the object). This cannot happen when there are still other references on the object.
		example:
			TYPE
			Object= OBJECT VAR active: BOOLEAN; BEGIN{ACTIVE} active := FALSE; AWAIT(active) END Object;
			VAR o: Object;
			BEGIN NEW(o);
			END;
		 *)
	END;
	p.mode := Terminated; (* fof for GC problem *)

	IF p.handle # 0 THEN
		res := Kernel32.CloseHandle(p.handle); p.handle := 0
	END
END FinalizeProcess;

PROCEDURE TerminateProc;
BEGIN
	terminate(CurrentProcess());
	Kernel32.ExitThread(0);
	Kernel32.Sleep(999999);   (* wait until dependent threads terminated *)
END TerminateProc;

(* Allocate a new process associated with "obj". Must be outside lock region, because of potential GC. *)
PROCEDURE NewProcess(body: Body; priority: LONGINT;  flags: SET; obj: ProtectedObject; VAR new: Process);
VAR t,r: Process;  fn: Heaps.FinalizerNode;
BEGIN
	NEW(t);
	t.gcContext.nextPos := 0; 
	t.context := CurrentContext(); (* inherit context from parent process *)
	t.handle := 0;
	IF priority = 0 THEN  (* no priority specified *)
		r := CurrentProcess();
		t.priority := r.priority (* inherit priority of creator *)
	ELSIF priority > 0 THEN  (* positive priority specified *)
		t.priority := priority
	ELSE  (* negative priority specified (only for Idle process) *)
		t.priority := MinPriority
	END;

	NEW(fn);   (* implicit call Heaps.NewRec -> might invoke GC *)

	Machine.Acquire(Machine.Objects);
	t.next := NIL; t.prev := NIL; t.rootedNext := NIL;
	t.waitingOn := NIL; t.flags := flags; t.obj := obj; t.mode := Unknown;
	t.body := body; t.event := 0; fn.finalizer := FinalizeProcess;
	Heaps.AddFinalizer(t, fn);
	IF Restart IN flags THEN  (* restart object body *)
		t.restartPC := SYSTEM.VAL(ADDRESS, body);
	ELSE  (* terminate process *)
		t.restartPC := SYSTEM.VAL(ADDRESS, terminateProc);
	END;
	
	(*! Put the process into the process queue before the thread is created.
		this is highly important in case of a DLL, where Objects.AttachThread 
		will be called by Kernel32.EntryPoint (DllMain)
	*)
	Put(ready, t);
	t.handle := Kernel32.CreateThread(0, defaultStackSize, Wrapper, t, {}, t.id);

	IF TraceVerbose OR TraceOpenClose THEN
		Machine.Acquire(Machine.TraceOutput);
		Trace.String("NewProcess: " ); Trace.Int(t.id, 1); WriteType(obj); Trace.Ln;
		Machine.Release(Machine.TraceOutput);
	END;

	ASSERT(t.handle # 0);
	new := t;
END NewProcess;

(* Create the process associated with an active object (kernel call). *)
PROCEDURE CreateProcess*(body: Body; priority: LONGINT; flags: SET; obj: ProtectedObject);
VAR t : Process; heapBlock {UNTRACED}: Heaps.HeapBlock;
BEGIN
	ASSERT(priority >= 0, 1000); ASSERT(priority <=Realtime, 1001);
	SYSTEM.GET(SYSTEM.VAL(ADDRESS, obj) + Heaps.HeapBlockOffset, heapBlock);
	
	ASSERT(heapBlock IS Heaps.ProtRecBlock); (* protected object *)
	IF Restart IN flags THEN INCL(flags, Resistant) END;   (* SAFE => Restart & Resistant *)
	NewProcess(body, priority, flags, obj, t);  INC(nProcs);  (* acquires Machine.Objects lock *)
	t.mode := Ready;
	Machine.Release(Machine.Objects);
END CreateProcess;


(* The procedure Lock, Unlock and Await do not use header locks since it turned out that the header locks sometimes were finalized
     too early. *)
PROCEDURE Lock*(obj: ProtectedObject; exclusive: BOOLEAN );
VAR hdr {UNTRACED}: Heaps.ProtRecBlock; r: Process; res: WORD;
BEGIN  (* {called from user level} *)
	SYSTEM.GET(SYSTEM.VAL(ADDRESS, obj) + Heaps.HeapBlockOffset, hdr);
	IF StrongChecks THEN
		ASSERT(hdr IS Heaps.ProtRecBlock); (* protected object *)
		ASSERT(exclusive)	(* shared not implemented yet *)
	END;
	r := CurrentProcess();
	IF StrongChecks THEN
		ASSERT(hdr # NIL, 1001);
		ASSERT(r # NIL, 1002);
	END;
	Machine.Acquire(Machine.Objects);
	IF hdr.count = 0 THEN  (* not locked *)
		hdr.count := -1; hdr.lockedBy := r;
		Machine.Release(Machine.Objects)
	ELSE  (* already locked *)
		IF hdr.lockedBy = r THEN
			Machine.Release(Machine.Objects);
			HALT(2203) (* nested locks not allowed *)
		END;
		ASSERT(r.waitingOn = NIL); (* sanity check *)
		Remove(ready, r);
		IF r.event = 0 THEN
			r.event := Kernel32.CreateEvent( NIL, Kernel32.False (* auto *), Kernel32.False, NIL );   (* auto reset event with initial state = reset *)
			ASSERT ( r.event # 0, 1239 );
		END;
		r.waitingOn := obj;  r.mode := AwaitingLock;
		Put(hdr.awaitingLock, r); INC(awl);
		Machine.Release(Machine.Objects);
		res := Kernel32.WaitForSingleObject(r.event, Kernel32.Infinite); (* block execution *)
		ASSERT(res = Kernel32.WaitObject0);
		IF StrongChecks THEN
			ASSERT(hdr.lockedBy = r); (* at this moment only this process can own the lock and only this process can release it*)
		END;
	END
END Lock;

(* Find the first true condition from the queue and remove it. Assume the object is currently locked. *)
PROCEDURE FindCondition( VAR q: ProcessQueue ): Process;
VAR first, cand: Process;
BEGIN
	Get( q, first );
	IF first.condition( first.condFP ) THEN RETURN first END;
	Put( q, first );
	WHILE q.head # first DO
		Get( q, cand );
		IF cand.condition( cand.condFP ) THEN RETURN cand END;
		Put( q, cand )
	END;
	RETURN NIL
END FindCondition;

(* The procedure Lock, Unlock and Await do not use header locks since it turned out that the header locks sometimes were finalized
     too early. *)
PROCEDURE Unlock*( obj: ProtectedObject;  dummy: BOOLEAN );
VAR hdr {UNTRACED}: Heaps.ProtRecBlock; t, c: Process; res: WORD;
BEGIN
	SYSTEM.GET(SYSTEM.VAL(ADDRESS, obj) + Heaps.HeapBlockOffset, hdr);
	IF StrongChecks THEN
		ASSERT(hdr IS Heaps.ProtRecBlock) (* protected object *)
	END;
	ASSERT(hdr.count = -1);	(* exclusive locked *)
	Machine.Acquire(Machine.Objects);

	IF hdr.awaitingCond.head # NIL THEN  (* evaluate the waiting conditions *)
		(* we are holding the lock, so the queue can not change (to do: except in TerminateThis) *)
		c := FindCondition(hdr.awaitingCond);   (* interrupts should be on during this call *)
	ELSE
		c := NIL
	END;
	IF c = NIL THEN  (* no true condition found, check the lock queue *)
		Get(hdr.awaitingLock, t);
		IF t # NIL THEN
			hdr.lockedBy := t;
			t.waitingOn := NIL;
		ELSE
			hdr.lockedBy := NIL; hdr.count := 0
		END
	ELSE  (* true condition found, transfer the lock *)
		c.waitingOn := NIL; hdr.lockedBy := c;
		t := NIL
	END;
	IF c # NIL THEN
		Put(ready, c); c.mode := Running; DEC(awc);
		res := Kernel32.SetEvent(c.event);
		ASSERT (res # 0, 1001);
	ELSIF t # NIL THEN
		Put(ready, t); t.mode := Running; DEC(awl);
		res := Kernel32.SetEvent(t.event);
		ASSERT (res # 0, 1002);
	END;
	Machine.Release( Machine.Objects )
END Unlock;

(* The procedure Lock, Unlock and Await do not use header locks since it turned out that the header locks sometimes were finalized
     too early. *)
PROCEDURE Await*( cond: Condition;  slink: LONGINT;  obj: ProtectedObject;  flags: SET );
VAR hdr {UNTRACED}: Heaps.ProtRecBlock; r, c, t: Process;  res: WORD;
BEGIN
	IF 1 IN flags THEN  (* compiler did not generate IF *)
		IF cond(slink) THEN
			RETURN  (* condition already true *)
		END
	END;
	SYSTEM.GET(SYSTEM.VAL(ADDRESS, obj) + Heaps.HeapBlockOffset, hdr);
	IF StrongChecks THEN
		ASSERT(hdr IS Heaps.ProtRecBlock) (* protected object *)
	END;
	r := CurrentProcess();
	Machine.Acquire(Machine.Objects);
	IF hdr.lockedBy = r THEN  (* current process holds exclusive lock *)
		IF StrongChecks THEN ASSERT(hdr.count = -1) END; (* exclusive locked *)
		IF hdr.awaitingCond.head # NIL THEN	(* evaluate the waiting conditions *)
			(* we are holding the lock, so the queue can not change (to do: except in TerminateThis) *)
			c := FindCondition(hdr.awaitingCond)	(* interrupts should be on during this call *)
		ELSE
			c := NIL
		END;
		IF c = NIL THEN
			Get(hdr.awaitingLock, t);
			IF t = NIL THEN	(* none waiting - remove lock *)
				hdr.count := 0; hdr.lockedBy := NIL;
			ELSE	(* transfer lock to first waiting process *)
				IF StrongChecks THEN ASSERT(t.mode = AwaitingLock) END;
				t.waitingOn := NIL;
				hdr.lockedBy := t;
			END;
		ELSE
			c.waitingOn := NIL; hdr.lockedBy := c;
			t := NIL;
		END;
	ELSE  (* no lock, or some other process may hold the lock, but that's the user's indaba (may be monotonic condition) *)
		Machine.Release(Machine.Objects);
		HALT( 2204 ) (* await must be exclusive region *)
	END;
	r.condition := cond; r.condFP := slink;
	r.waitingOn := obj; r.mode := AwaitingCond;
	Remove(ready, r);
	IF r.event = 0 THEN
		r.event := Kernel32.CreateEvent( NIL, Kernel32.False (* auto *), Kernel32.False, NIL );   (* auto-reset event with initial state = reset *)
		ASSERT ( r.event # 0, 1239 );
	END;
	IF c # NIL THEN
		DEC(awc); Put(ready, c); c.mode := Running;
		res := Kernel32.SetEvent(c.event); (* restart execution *)
		ASSERT(res # 0, 1002);
	END;
	IF t # NIL THEN
		DEC(awl); Put(ready, t);  t.mode := Running;
		res := Kernel32.SetEvent( t.event ); (* restart execution *)
		ASSERT(res # 0, 1003);
	END;
	Put(hdr.awaitingCond, r); INC(awc);
	Machine.Release(Machine.Objects);
	res := Kernel32.WaitForSingleObject(r.event, Kernel32.Infinite); (* block execution *)
	ASSERT(res = Kernel32.WaitObject0);
	IF StrongChecks THEN
		ASSERT(cond(slink));
		ASSERT(hdr.lockedBy = r) (* lock held again *)
	END
END Await;

	PROCEDURE Break*( t: Process );
	CONST MaxTry = 50;
	VAR mod: Modules.Module;  try: LONGINT;  retBOOL: Kernel32.BOOL;   (* Dan 09.11.05 *)

		PROCEDURE SafeForBreak( mod: Modules.Module ): BOOLEAN;
		BEGIN
			Trace.String( "Safe for break?: " );
			IF mod # NIL THEN
				Trace.StringLn ( mod.name );
				IF (mod.name = "Trace") OR (mod.name = "Machine") OR
					(mod.name = "Heaps") OR (mod.name = "Modules") OR
					(mod.name = "Objects") OR (mod.name = "Kernel") THEN
					Trace.StringLn ( " - no" );  RETURN FALSE
				ELSE Trace.StringLn ( " - yes" );  RETURN TRUE
				END
			ELSE Trace.StringLn ( "unknown module" );  RETURN FALSE
			END
		END SafeForBreak;

	BEGIN
		IF CurrentProcess() # t THEN
			Machine.Acquire( Machine.Objects );
			LOOP
				retBOOL := Kernel32.SuspendThread( t.handle );
				t.state.ContextFlags := Kernel32.ContextControl;
				retBOOL := Kernel32.GetThreadContext( t.handle, t.state );
				mod := Modules.ThisModuleByAdr( t.state.PC );  Trace.String( "Objects Break at adr: " );
				Trace.Int( t.state.PC, 5 );  Trace.Ln;
				IF mod # NIL THEN
					Trace.String( "In module: " );  Trace.StringLn ( mod.name );
				END;
				IF ~SafeForBreak( mod ) (* we do not break Kernel modules *) THEN
					retBOOL := Kernel32.ResumeThread( t.handle );  INC( try );
					IF try > MaxTry THEN
						Trace.StringLn ( "Threads.Break: failed " );
						Machine.Release( Machine.Objects );
						RETURN
					END
				ELSE EXIT
				END;
			END;
			(* push cont.Eip *) break[0] := 68X;
			SYSTEM.MOVE( ADDRESSOF( t.state.PC ), ADDRESSOF( break[1] ), 4 );
			(* push ebp *) break[5] := 055X;
			(* mov ebp, esp *) break[6] := 08BX;  break[7] := 0ECX;
			(* push 13 *) break[8] := 06AX;  break[9] := 0DX;
			(* int 3 *) break[10] := 0CCX;
			(* mov esp, ebp *) break[11] := 08BX;  break[12] := 0E5X;
			(* pop ebp *) break[13] := 05DX;
			(* ret *) break[14] := 0C3X;  t.state.PC := ADDRESSOF( break[0] );
			retBOOL := Kernel32.SetThreadContext( t.handle, t.state );
			retBOOL := Kernel32.ResumeThread( t.handle );   (*  INC( Kernel.GClevel ); *)

			Machine.Release( Machine.Objects );
		ELSE HALT( 99 )
		END;

	END Break;

(* Attempt to terminate a specific process (mostly ignoring its locks). DEPRECATED *)
PROCEDURE TerminateThis*( t: Process;  halt: BOOLEAN );
BEGIN
	terminate(t);
END TerminateThis;

PROCEDURE Terminate*;
BEGIN
	TerminateProc();
END Terminate;

PROCEDURE Init;   (* can not use NEW *)
VAR t: Process;  fn: Heaps.FinalizerNode;  proc: Kernel32.HANDLE;
	res: Kernel32.BOOL;
BEGIN
	Kernel32.AddVectoredExceptionHandler(1, ExcpFrmHandler); 
	Kernel32.InitializeCriticalSection(excplock);
	numberOfProcessors := Machine.NumberOfProcessors();

#IF SHAREDLIB THEN
	EnterA2; (*! ExitA2 for the DLL loading thread will be called after execution of all module bodies (see Modules.Main) *)
#ELSE
	NEW(t);
	NEW(fn);

	Machine.Acquire(Machine.Objects);
	t.gcContext.nextPos := 0;
	nProcs := 1;
	t.next := NIL;  t.prev := NIL;
	t.waitingOn := NIL;
	t.flags := {};
	t.obj := NIL;
	t.mode := Unknown; t.body := NIL;
	t.priority := Normal;

	fn.finalizer := FinalizeProcess;
	Heaps.AddFinalizer(t, fn);

	t.handle := Kernel32.GetCurrentThread();
	t.id := Kernel32.GetCurrentThreadId();
	proc := Kernel32.GetCurrentProcess();
	res := Kernel32.DuplicateHandle(proc, t.handle, proc, t.handle, {}, 0, {Kernel32.DuplicateSameAccess});
	ASSERT(res # 0);
	res := Kernel32.TlsSetValue(tlsIndex, SYSTEM.VAL(ADDRESS, t));
	ASSERT(res # 0);
	t.stackBottom := Machine.stackBottom;
	t.mode := Running;
	Put( ready, t );
	ASSERT(t.handle # 0);
	Machine.Release(Machine.Objects);
#END;

	InitEventHandling; (* implicit call of NewProcess! *)
	InitGCHandling; (* do. *)
	Heaps.gcStatus := GCStatusFactory();
END Init;

(** Set (or reset) an event handler object's timeout value. *)
PROCEDURE SetTimeout*(t: Timer; h: EventHandler;  ms: LONGINT );
VAR e: Timer;  trigger: LONGINT;
BEGIN
	ASSERT(Machine.Second= 1000); (* assume milliseconds for now *)
	ASSERT((t # NIL) & (h # NIL));
	ASSERT(ms >= 0);
	Machine.Acquire(Machine.Objects);
	trigger := Kernel32.GetTickCount() + ms;   (* ignore overflow *)
	IF t.next # NIL THEN  (* cancel previous timeout *)
		t.next.prev := t.prev;  t.prev.next := t.next
	END;
	t.trigger := trigger;  t.handler := h;
	e := event.next;   (* performance: linear search! *)
	WHILE (e # event) & (e.trigger - trigger <= 0) DO e := e.next END;
	t.prev := e.prev;  e.prev := t;  t.next := e;  t.prev.next := t;
	Machine.Release(Machine.Objects);
	clock.Wakeup()
END SetTimeout;

(** Set (or reset) an event handler object's timeout value. Here ms is absolute *)
PROCEDURE SetTimeoutAt*(t: Timer; h: EventHandler; ms: LONGINT);
VAR e: Timer; trigger: LONGINT;
BEGIN
	ASSERT(Machine.Second= 1000);	(* assume milliseconds for now *)
	ASSERT((t # NIL) & (h # NIL));
	Machine.Acquire(Machine.Objects);
	trigger := ms; (* ignore overflow *)
	IF t.next # NIL THEN (* cancel previous timeout *)
		t.next.prev := t.prev; t.prev.next := t.next
	END;
	t.trigger := trigger; t.handler := h;
	e := event.next;	(* performance: linear search! *)
	WHILE (e # event) & (e.trigger - trigger <= 0) DO e := e.next END;
	t.prev := e.prev; e.prev := t; t.next := e; t.prev.next := t;
	Machine.Release(Machine.Objects);
	clock.Wakeup()
END SetTimeoutAt;

(** Cancel an event handler object's timeout, if any. It is possible that the timer has expired, but not yet been scheduled to run. *)
PROCEDURE CancelTimeout*( t: Timer );
BEGIN
	Machine.Acquire(Machine.Objects);
	ASSERT (t # event );
	IF t.next # NIL THEN
		t.next.prev := t.prev;  
		IF t.prev#NIL THEN t.prev.next := t.next; END;
		t.next := NIL;
		t.prev := NIL
	END;
	Machine.Release(Machine.Objects);
END CancelTimeout;

PROCEDURE InitEventHandling;
BEGIN
	NEW(event); event.next := event; event.prev := event;  (* event: head of timer event queue, only a sentinel *)
	NEW(clock);
END InitEventHandling;

PROCEDURE InitGCHandling;
BEGIN
	NEW(finalizerCaller);
END InitGCHandling;

PROCEDURE GCStatusFactory(): Heaps.GCStatus;
VAR gcStatusExt : GCStatusExt;
BEGIN
	ASSERT(Heaps.gcStatus = NIL);
	NEW(gcStatusExt);
	RETURN gcStatusExt
END GCStatusFactory;

PROCEDURE InstallExceptionHandler*( e: ExceptionHandler );
BEGIN
	exceptionhandler := e;
END InstallExceptionHandler;

PROCEDURE UpdateProcessState*( p: Process );
VAR res: Kernel32.BOOL;
BEGIN
	res := Kernel32.GetThreadContext( p.handle, p.state );
	ASSERT (p.handle # 0);
END UpdateProcessState;

(*ALEX 2005.12.12 added for WMPerfMon needs*)

PROCEDURE NumReady*( ): LONGINT;
VAR n: LONGINT; p: Heaps.ProcessLink;
BEGIN
	n := 0;
	Machine.Acquire( Machine.Objects );
	p := ready.head;
	WHILE p # NIL DO INC( n );  p := p.next END;
	Machine.Release( Machine.Objects );
	RETURN n
END NumReady;

(** Return number of CPU cycles consumed by the specified process. If all is TRUE,
	return the number of cycles since the process has been created. If FALSE, return the number of cycles
	consumed since the last time asked. *)
PROCEDURE GetCpuCycles*(process : Process; VAR cpuCycles : CpuCyclesArray; all : BOOLEAN);
VAR res : Kernel32.BOOL; temp : HUGEINT; 
BEGIN
	ASSERT(process # NIL);
	IF (Kernel32.QueryThreadCycleTime # NIL) THEN
		res := Kernel32.QueryThreadCycleTime(process.handle, cpuCycles[0]);
	ELSE
		cpuCycles[0] := Machine.GetTimer(); res := Kernel32.True;
	END;

	IF ~all & (res = Kernel32.True) THEN
		temp := process.lastThreadTimes;
		process.lastThreadTimes := cpuCycles[0];
		cpuCycles[0] := cpuCycles[0] - temp;
	END;
END GetCpuCycles;

PROCEDURE CurrentProcessTime*(): HUGEINT;
VAR res: WORD; result: HUGEINT;
BEGIN
	IF (Kernel32.QueryThreadCycleTime # NIL) THEN
		res := Kernel32.QueryThreadCycleTime(CurrentProcess().handle, result);
	ELSE (* fallback *)
		result := Machine.GetTimer();
	END;
	RETURN result;
END CurrentProcessTime;

PROCEDURE TimerFrequency*(): HUGEINT;
BEGIN
	RETURN 1000000000;
END TimerFrequency;

VAR GetProcedureName*: PROCEDURE (pc: ADDRESS; VAR n: ARRAY OF CHAR; VAR spc: ADDRESS);

(* Leave A2 is called when a process leaves A2 by a call to the windows API *)
PROCEDURE LeaveA2*;
VAR cur: Process; ebp,n: ADDRESS;
BEGIN
	#IF AMD64 THEN	
	CODE
		PUSH RCX
		PUSH RDX
		PUSH R8
		PUSH R9
	END;
	#END
	IF clock = NIL THEN 
		RETURN 
	END;

	cur := CurrentProcess();
	IF cur # NIL THEN 
		ebp := SYSTEM.GetFramePointer();
		SYSTEM.GET(ebp, n);
		IF ODD(n) THEN SYSTEM.GET(ebp + SIZEOF(ADDRESS), ebp) ELSE ebp := n END;
		cur.gcContext.last[cur.gcContext.nextPos] := ebp;
		INC(cur.gcContext.nextPos);
		ASSERT(cur.gcContext.nextPos < 255); 
	END;
	#IF AMD64 THEN
	CODE
		POP R9
		POP R8
		POP RDX
		POP RCX
	END;
	#END
END LeaveA2;

(* reenter is called when a process returns from a call to the windows API *)
PROCEDURE ReenterA2*;
VAR cur: Process;
BEGIN
	IF clock = NIL THEN RETURN END;
	cur := CurrentProcess();
	IF cur # NIL THEN
		IF (cur.gcContext.nextPos > 0) THEN 
			DEC(cur.gcContext.nextPos);
		END;
		cur.gcContext.last[cur.gcContext.nextPos] := NIL; (* returned *)
		(*cur.gcContext.first[cur.gcContext.nextPos] := NIL; (* returned *)*)
	END;	
END ReenterA2;

#IF SHAREDLIB THEN

	PROCEDURE AcquireLock(VAR lock: BOOLEAN);
	BEGIN
		REPEAT UNTIL CAS(lock, FALSE, TRUE) = FALSE;
	END AcquireLock;

	PROCEDURE ReleaseLock(VAR lock: BOOLEAN);
	BEGIN
		IGNORE CAS(lock, TRUE, FALSE);
	END ReleaseLock;

VAR
	protect: Process;
	protectLock: BOOLEAN;

    PROCEDURE RegisterExternalProcess;
    VAR
        t: Process;
        proc: Kernel32.HANDLE;
        res: Kernel32.BOOL;
        low, high: SIZE;
    BEGIN
        (*! global variable "protect" is used for avoiding problems when GC is invoked
        	by calling NEW while the current external thread is not yet registered.
        *)
		AcquireLock(protectLock);

		NEW(protect); t := protect;
		NEW(t.obj); (*! required for ActiveObject() to return non-NIL *)

		t.gcContext.nextPos := 0; (*! the registered process is considered as entered into A2 *)
		t.next := NIL;  t.prev := NIL;
		t.waitingOn := NIL;
		t.flags := {External}; (*! mark the process as external (non A2) *)
		t.mode := Unknown; t.body := NIL;

		t.handle := Kernel32.GetCurrentThread();

		t.priority := Kernel32.GetThreadPriority(t.handle);
		ASSERT(t.priority # Kernel32.ThreadPriorityErrorReturn);
		CASE t.priority OF
			|Kernel32.ThreadPriorityIdle: t.priority := MinPriority;
			|Kernel32.ThreadPriorityBelowNormal: t.priority := Low;
			|Kernel32.ThreadPriorityAboveNormal,Kernel32.ThreadPriorityHighest: t.priority := High;
			|Kernel32.ThreadPriorityTimeCritical: t.priority := Realtime;
		ELSE
			ASSERT(t.priority = Kernel32.ThreadPriorityNormal);
			t.priority := Normal;
		END;

		t.id := Kernel32.GetCurrentThreadId();
		proc := Kernel32.GetCurrentProcess();
		res := Kernel32.DuplicateHandle(proc, t.handle, proc, t.handle, {}, 0, {Kernel32.DuplicateSameAccess});
		ASSERT(res # 0);
		Kernel32.GetCurrentThreadStackLimits(low,high);
		t.stackBottom := high;
		t.mode := Running;
		res := Kernel32.TlsSetValue(tlsIndex, SYSTEM.VAL(ADDRESS, t));
		ASSERT(res # 0);

		Machine.Acquire(Machine.Objects);
		Put(ready, t);
		INC(nProcs);
		Machine.Release(Machine.Objects);

		ReleaseLock(protectLock);

		Machine.Acquire(Machine.TraceOutput);
		Trace.String("registered an external thread: id=");
		Trace.Int(t.id,0);
		Trace.String(", handle=");
		Trace.Int(t.handle,0);
		Trace.String(", stackBottom=");
		Trace.Hex(t.stackBottom,-8);
		Trace.Ln;
		Machine.Release(Machine.TraceOutput);
    END RegisterExternalProcess;

	(* enter A2 should be called when a process enters A2 from windows or from A2 via a call to a WINAPI A2 function *)
	PROCEDURE EnterA2*;
	VAR cur: Process; ebp, n: ADDRESS;
	BEGIN
		cur := CurrentProcess();
		IF cur = NIL THEN (* create a process descriptor *)
			RegisterExternalProcess;
			cur := CurrentProcess();
			IF TraceVerbose THEN
				Machine.Acquire(Machine.TraceOutput);
				Trace.String("First Enter: "); Trace.Int(cur.id,0); Trace.Ln;
				Machine.Release(Machine.TraceOutput);
			END;
		ELSE
			ebp := SYSTEM.GetFramePointer();
			SYSTEM.GET(ebp, n);
			IF ODD(n) THEN SYSTEM.GET(ebp + SIZEOF(ADDRESS), ebp) ELSE ebp := n END;
			IF cur.gcContext.nextPos = -1 THEN (* re-entry *)
				cur.gcContext.nextPos := 0;
				cur.stackBottom := ebp;
				IF TraceVerbose THEN
					Machine.Acquire(Machine.TraceOutput);
					Trace.String("Reenter: "); Trace.Int(cur.id,0); Trace.Ln;
					Machine.Release(Machine.TraceOutput);
				END;
			ELSE
				INC(cur.gcContext.nextPos);
				cur.gcContext.last[cur.gcContext.nextPos] := NIL;
			END;
		END;

		(*
		cur.gcContext.first[cur.gcContext.nextPos] := ebp; (* here our responsibility starts -- currently this field is not strictly required to be set valid *)
		cur.gcContext.last[cur.gcContext.nextPos] := NIL; (* we do not know where it ends yet *)
		*)
	END EnterA2;

	(* exit A2 should be called when a process exits a WINAPI procedure *)
	PROCEDURE ExitA2*();
	VAR cur: Process;
	BEGIN
		cur := CurrentProcess();
		ASSERT(cur # NIL);
		IF cur.gcContext.nextPos > 0 THEN
			DEC(cur.gcContext.nextPos);
			cur.gcContext.last[cur.gcContext.nextPos] := NIL;
		ELSE
			IF TraceVerbose THEN
				Machine.Acquire(Machine.TraceOutput);
				Trace.String("Exiting: "); Trace.Int(cur.id,0); Trace.Ln;
				Machine.Release(Machine.TraceOutput);
			END;
			cur.gcContext.nextPos := -1;
		END;
	END ExitA2;

	PROCEDURE AttachThread*();
	BEGIN
	END AttachThread;

	(* Cleanup resources of an external process. Must be called while Objects lock is taken *)
	PROCEDURE CleanupExternalProcess(t: Process);
	BEGIN
		ASSERT(External IN t.flags);
		IF InQueue(ready,t) THEN
			Remove(ready,t); DEC(nProcs);
		END;
		IF t.event # 0 THEN IGNORE Kernel32.CloseHandle(t.event); END;
	END CleanupExternalProcess;

	(* Called when a thread is detaching from the DLL *)
	PROCEDURE DetachThread*();
	VAR
		t: Process;
		res: Kernel32.BOOL;
	BEGIN
		t := CurrentProcess();
		IF (t = NIL) OR ~(External IN t.flags) THEN RETURN; END;

		Machine.Acquire (Machine.TraceOutput);
		Trace.String("detaching a thread: id="); Trace.Int(t.id,0); Trace.Ln;
		Machine.Release (Machine.TraceOutput);

		Machine.Acquire(Machine.Objects);
		CleanupExternalProcess(t);
		res := Kernel32.TlsSetValue(tlsIndex, NIL);
        ASSERT(res # 0);
		Machine.Release(Machine.Objects);

		Machine.Acquire (Machine.TraceOutput);
		Trace.String("detached a thread: id="); Trace.Int(t.id,0); Trace.Ln;
		Machine.Release (Machine.TraceOutput);
	END DetachThread;

	PROCEDURE CleanupProcesses;
	VAR
		t: Process;
		res: Kernel32.BOOL;
	BEGIN
		Machine.Acquire(Machine.Objects);
		Get(ready, t); DEC(nProcs);
		WHILE t # NIL DO
			IF t.mode # Terminated THEN
				IF External IN t.flags THEN
					Machine.Acquire (Machine.TraceOutput);
					Trace.String("cleaning up an external process: id="); Trace.Int(t.id,0); Trace.String(", mode="); Trace.Int(t.mode,0); Trace.Ln;
					Machine.Release (Machine.TraceOutput);
					CleanupExternalProcess(t);
				ELSE
					Machine.Acquire (Machine.TraceOutput);
					Trace.String("killing a process: id="); Trace.Int(t.id,0); Trace.String(", mode="); Trace.Int(t.mode,0); Trace.Ln;
					Machine.Release (Machine.TraceOutput);
					res := Kernel32.TerminateThread(t.handle,-1);
					IF res = 0 THEN
						Machine.Acquire (Machine.TraceOutput);
						Trace.String("failed to kill a process: id="); Trace.Int(t.id,0); Trace.String(", error="); Trace.Int(Kernel32.GetLastError(),0); Trace.Ln;
						Machine.Release (Machine.TraceOutput);
					END;
				END;
			END;
			Get(ready, t); DEC(nProcs);
		END;
		Trace.String("nProcs="); Trace.Int(nProcs,0); Trace.Ln;
		Machine.Release(Machine.Objects);
	END CleanupProcesses;

	(* Called when the DLL loading process is detaching from the DLL *)
	PROCEDURE DetachProcess*();
	CONST
		TerminationTimeout = 1000;
	VAR
		p: Heaps.ProcessLink;
		t: Process;
		res: Kernel32.BOOL;
		tick: LONGINT;
		numNonTerminated, numExternals: SIZE;
	BEGIN
		EnterA2;

		Machine.Acquire(Machine.TraceOutput);
		Trace.String("detaching the process: id="); Trace.Int(Kernel32.GetCurrentThreadId(),0); Trace.Ln;
		Machine.Release(Machine.TraceOutput);

		Modules.Shutdown(-1);
		finalizerCaller.Exit;
		clock.Exit;

		Machine.Acquire(Machine.TraceOutput);
		Trace.StringLn("wait until all A2 processes terminate");
		Machine.Release(Machine.TraceOutput);

		tick := Kernel32.GetTickCount();
		REPEAT
			numNonTerminated := 0;
			numExternals := 0;
			Machine.Acquire(Machine.Objects);
			p := ready.head;
			WHILE p # NIL DO
				t := p(Process);
				IF External IN t.flags THEN
					INC(numExternals);
				ELSIF t.mode # Terminated THEN
					INC(numNonTerminated);
				END;
				p := p.next;
			END;
			Machine.Release(Machine.Objects);
		UNTIL (numNonTerminated = 0) OR (Kernel32.GetTickCount() - tick >= TerminationTimeout);

		IF numNonTerminated # 0 THEN
			Machine.Acquire(Machine.TraceOutput);
			Trace.String("there are "); Trace.Int(numNonTerminated,0); Trace.StringLn(" A2 processes to terminate forcedly");
			Machine.Release(Machine.TraceOutput);
			CleanupProcesses;
		ELSE
			Machine.Acquire(Machine.TraceOutput);
			Trace.StringLn("all A2 processes terminated");
			Machine.Release(Machine.TraceOutput);

			IF numExternals # 0 THEN
				CleanupProcesses;
			END;
		END;

		res := Kernel32.TlsFree(tlsIndex);
		IF res = 0 THEN
			Machine.Acquire (Machine.TraceOutput);
			Trace.String("failed free TLS: error="); Trace.Int(Kernel32.GetLastError(),0); Trace.Ln;
			Machine.Release (Machine.TraceOutput);
		END;

		(*!TODO: free resources allocated in Machine (e.g. critical section objects) *)
	END DetachProcess;

#END;

VAR
	TraceProcessHook*: PROCEDURE (prcoess: Process; pc, bp: ADDRESS; stacklow, stackhigh: ADDRESS);
	
BEGIN
	TraceProcessHook := NIL;
	exceptionhandler := NIL;
	terminateProc := TerminateProc;
	ready.head := NIL; ready.tail := NIL;
	tlsIndex := Kernel32.TlsAlloc();
	ASSERT ( tlsIndex # Kernel32.TLSOutOfIndexes );
	Kernel32.SendToDebugger("Modules.root", ADDRESSOF(Modules.root));
	
	
	Init;
END Objects.



		Linker.Link --fileFormat=PE32CUI --fileName=oberonn.exe --extension=GofW --displacement=401000H
			Builtins Trace Kernel32 Heaps Modules Objects Kernel KernelLog Streams Commands Files WinFS Clock Dates Reals Strings Diagnostics BitSets
			StringPool ObjectFile GenericLinker Reflection Loader Shell StdIOShell Traps System ~
