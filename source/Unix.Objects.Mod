(* Aos, Copyright 2001, Pieter Muller, ETH Zurich *)

MODULE Objects;   (** AUTHOR "pjm, G.F."; PURPOSE "Active object runtime support"; *)


IMPORT S := SYSTEM, Trace, Glue, Unix, Machine, Heaps, Modules;

CONST
	ConcurrentGC=FALSE; (* if TRUE then release needs to be compiled with --writeBarriers *)	

	(*! Process flags, meaningless in Unix ports !!! *)
	PleaseHalt* = 10;		(* Process requested to Halt itself soon *)
	Unbreakable*= 11;		(* FINALLY shall not catch HALT exception (PleaseHalt is also set) *)
	SelfTermination*=12;	(* Indicates the process has requested to terminate ifself (PleaseHalt is also set) *)
	Preempted* = 27;		(* Has been preempted. *)
	Resistant* = 28;		(* Can only be destroyed by itself *)


	MinPriority*	= Unix.ThreadLow;
	Low*			= Unix.ThreadLow + 1;
	Normal*		= Unix.ThreadNormal;
	High*			= Unix.ThreadHigh - 2;
	GCPriority*	= Unix.ThreadHigh - 1;
	Realtime*	= Unix.ThreadHigh;

	(* Process flag defined by compiler in OPC.CallRecBody *)
	Restart* = 0;	(* Restart/Destroy process on exception *)

	(* Process modes (in UnixAos Running means Running or Ready!) *)
	Unknown* = 0;  Ready* = 1;  Running* = 2;  AwaitingLock* = 3;
	AwaitingCond* = 4;  AwaitingEvent* = 5;  Terminated* = 6;

	Second* = 1000;	(* frequency of ticks increments in Hz *)

	DefaultStacksize = 128*1024;


VAR
	(* timer *)
	timerActivity		: TimerActivity;
	clock				: Clock;
	timers				: Timer;
	timerListMutex	: Unix.Mutex_t;

	timerStopped: BOOLEAN;

	(* processes *)
	root-	: Process;	(*!  Anchor of all instantiated threads in system *)
	stacksize: LONGINT;		(* stack size of active objects, adjustable via boot parameter *)

	processList		: Unix.Mutex_t;
	createProcess	: Unix.Mutex_t;
	startProcess		: Unix.Mutex_t;
	startEventLock		: Unix.Mutex_t;
	lockMutex		: Unix.Mutex_t;
	childrunning		: Unix.Condition_t;

	processPointer	: Unix.Key_t;

	newProcess: Process;
	nextPID: LONGINT;

	finalizerCaller	: FinalizerCaller;
	mainthread: Unix.Thread_t;


TYPE

	LockT= POINTER TO RECORD
		mtx, enter: ADDRESS;
	END;

	CpuCyclesArray* = ARRAY Machine.MaxCPU OF HUGEINT;

	ProtectedObject = POINTER TO RECORD END;

	ObjectHeader = Heaps.ProtRecBlock;

	ProcessQueue = Heaps.ProcessQueue;

	EventHandler* = PROCEDURE  {DELEGATE};



	Timer* =  OBJECT
	VAR
		next: Timer;
		trigger: LONGINT;
		handler: EventHandler
	END Timer;

	TimerActivity = OBJECT
	VAR
		t, r: Timer;  h: EventHandler;  restart: BOOLEAN;

		PROCEDURE UpdateTicks;
		BEGIN {EXCLUSIVE}
			Machine.UpdateTicks
		END UpdateTicks;

		PROCEDURE Restart;
		BEGIN {EXCLUSIVE}
			restart := TRUE
		END Restart;

	BEGIN {ACTIVE, SAFE, PRIORITY(High)}
		restart := FALSE;
		LOOP
			t := timers;
			IF t # NIL THEN
				h := NIL;  r := NIL;
				BEGIN {EXCLUSIVE}
					AWAIT( (Machine.ticks >= t.trigger) OR restart );  restart := FALSE;
					IF Machine.ticks >= t.trigger THEN
						h := t.handler;  r := t
					END
				END;
				IF r # NIL THEN  Remove( r )  END;
				IF h # NIL THEN  (* not canceled *) h END
			ELSE
				BEGIN{EXCLUSIVE}
					AWAIT( restart );  restart := FALSE;
				END
			END
		END
	END TimerActivity;

	Clock* = OBJECT
	BEGIN {ACTIVE}
		LOOP
			Unix.ThrSleep( 10 );
			IF ~timerStopped THEN  timerActivity.UpdateTicks  END
		END;
	END Clock;

	FinalizerCaller = OBJECT	(* separate active object that calls finalizers *)
	VAR
		n: Heaps.FinalizerNode;  start: BOOLEAN;

		PROCEDURE Activate;
		BEGIN {EXCLUSIVE}
			start := TRUE
		END Activate;

	BEGIN {ACTIVE, SAFE, PRIORITY(High)}
		start := FALSE;
		LOOP
			BEGIN {EXCLUSIVE} AWAIT( start ) END;
			start := FALSE;
			LOOP
				n := Heaps.GetFinalizer();
				IF n = NIL THEN EXIT END;
				IF n.collection # NIL THEN
					n.collection.RemoveAll(n.objStrong)	(* remove it if it is not removed yet *)
				END;
				IF n.finalizer # NIL THEN
					n.finalizer(n.objStrong)	(* may acquire locks *)
				END;
			END;
		END
	END FinalizerCaller;



	Body = PROCEDURE ( self: ProtectedObject );
	Condition = PROCEDURE ( slink: ADDRESS ): BOOLEAN;

	GCContext = RECORD
		nextPos: SIZE; (* 0 to start with *)
		last: ARRAY 256 OF ADDRESS;
	END;
	
	Process* = OBJECT (Heaps.ProcessLink)
	VAR
		threadId-			: Unix.Thread_t;
		nextProcess-	: Process;	(* next in list of all processes *)
		stackBottom	-	: ADDRESS;
		id-				: LONGINT;
		body			: Body;
		mode-		: LONGINT;
		flags-			: SET;
		priority-		: LONGINT;	(* only effective if Aos is running SUID root *)
		succ			: Process;   		  	(* in ProcessQueue *)
		obj-			: ProtectedObject;	(* associated active object *)
		condition-	: Condition;   			(* awaited process' condition *)
		condFP-		: ADDRESS;			(* awaited process' condition's context *)
		continue		: Unix.Condition_t;	(* gets signaled when condition yields true *)
		waitingOn-	: ProtectedObject;
		procID-		: LONGINT;				(*! processor ID where running, not used in UnixAos *)
		state-			: Machine.State;
		state0	: ARRAY 2048 OF CHAR;		(* thread state at body start, used for restart after trap *)
		context: ANY; (* commands context *)
		lastThreadTimes: HUGEINT;
		gcContext: GCContext;

		PROCEDURE FindRoots;
		VAR sp, bp, sb, n, a0, a1, adr, pc: ADDRESS; desc: Modules.ProcedureDescPointer; i: LONGINT; p {UNTRACED}: ANY;
			contextPos: SIZE;
	BEGIN
			IF mode # Terminated THEN

				IF SELF = CurrentProcess() THEN
					state.SP := S.GetStackPointer( );
					state.BP := S.GetFramePointer( );
					state.PC := Machine.CurrentPC();
				ELSIF ConcurrentGC THEN
					Unix.ThrSuspend( threadId, mode = Running );						
				END;
				
				sp := state.SP; bp := state.BP; sb := stackBottom; pc := state.PC;

				contextPos := gcContext.nextPos;
				IF contextPos >= 0 THEN (* this thread is currently active in A2 *)			
					IF Heaps.GCType = Heaps.HeuristicStackInspectionGC THEN
						IF  (stackBottom # 0) & (bp < stackBottom) & (bp >= sp - SIZE OF ADDRESS) THEN
							S.GET( bp, n );
							IF ODD( n ) THEN (* procedure descriptor at bp *)
								IF n > 1024 THEN
								desc := S.VAL( Modules.ProcedureDescPointer, n-1 ); (* tracing !*)
								END;
							END;
						END;
						IF (stackBottom # 0) & (sp # 0) & (sp <= stackBottom) THEN
							Heaps.RegisterCandidates( sp, stackBottom - sp );
						END;
					ELSIF Heaps.GCType = Heaps.MetaDataForStackGC THEN
						IF bp < stackBottom THEN
							LOOP
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
								S.GET( bp, n );
								IF ODD( n ) THEN (* procedure descriptor at bp *)
									IF n > 1024 THEN
										desc := S.VAL( Modules.ProcedureDescPointer, n-1 );
										IF desc # NIL THEN
											a0 := ADDRESSOF( desc.offsets );
											a1 :=  S.VAL( ADDRESS, desc.offsets );
											ASSERT( a0+SIZEOF( ADDRESS ) = a1, 54321 );
											FOR i := 0 TO LEN( desc.offsets ) - 1 DO
												adr := bp + desc.offsets[i]; (* pointer at offset *)
												S.GET( adr, p ); (* load pointer *)
												IF p # NIL THEN
													Heaps.Inspect( p );
												END
											END
										END
									END;
									S.GET( bp + SIZEOF( ADDRESS ), bp );
									S.GET(bp + 2*SIZEOF(ADDRESS), pc);
								ELSE (* classical stack frame *)
									S.GET(bp + SIZEOF(ADDRESS), pc);
									bp := n;
								END;
							END; (* LOOP *)
						END; (* stackbottom *)
					END; (* gctype *)
				END; (* contextpos *)
				IF ConcurrentGC THEN
					IF SELF # CurrentProcess() THEN
						Unix.ThrResume( threadId);						
					END;
				END;
			END; (* mode terminated *)
			Heaps.Mark( nextProcess )					
		END FindRoots;

		PROCEDURE Cancel;
		VAR pt, t: Process;  kt: Unix.Thread_t;
		BEGIN
			IF SELF = CurrentProcess() THEN  Exit
			ELSE
				Machine.Acquire( Machine.X11 );  (* let the thread to be killed first finish its last I/O, if any *)
				Unix.MtxLock( processList );
					pt := NIL; t := root;  kt := 0;
					WHILE (t # NIL ) & (t # SELF) DO  pt := t;  t := t.nextProcess  END;
					IF t = SELF THEN
						kt := threadId;
						IF pt = NIL THEN  root := t.nextProcess  ELSE  pt.nextProcess := t.nextProcess  END;
					END;
				Unix.MtxUnlock( processList );
				IF kt # 0 THEN  Unix.ThrKill( kt )  END;
				Machine.Release( Machine.X11 );
			END
		END Cancel;

		PROCEDURE GetPriority( ): LONGINT;
		BEGIN
			RETURN Unix.ThrGetPriority( threadId )
		END GetPriority;

		PROCEDURE SetPriority( prio: LONGINT );
		VAR pr: LONGINT;
		BEGIN
		(*
			Linux/Solaris11: works only with SUID root and FIFO threads
			Solaris10: woks only with SUID root
			Darwin: works allways
		*)
			pr := MAX( Machine.prioLow, MIN( prio, Machine.prioHigh ) );
			Unix.ThrSetPriority( threadId, pr );
			priority := GetPriority( )
		END SetPriority;


		PROCEDURE & Initialize( obj: ProtectedObject;  bodyProc: Body;  prio: LONGINT; fl: SET; stacksize: LONGINT);
		BEGIN
			SELF.obj := obj;  condition := NIL;  continue := Unix.NewCond( );
			flags := fl;
			priority := prio;
			nextProcess := NIL;
			context := CurrentContext();
			IF root # NIL THEN
				newProcess := SELF;
				ASSERT( bodyProc # NIL );
				body := bodyProc;
				gcContext.nextPos := 0;
				context := CurrentContext(); (* inherit context from parent process *)
				Unix.MtxLock( startProcess );
				Unix.MtxLock( startEventLock ); (* the cond wait below opens this lock again! *)
				threadId := Unix.ThrStart( BodyStarter, stacksize );
				Unix.CondWait( childrunning, startEventLock );
				Unix.MtxUnlock( startEventLock );
				Unix.MtxUnlock( startProcess );
				RegisterFinalizer( SELF, FinalizeProcess );
			ELSE
				(* first process *)
				stackBottom := Glue.stackBottom;
				threadId := Unix.ThrThis( );
				id := 0;  nextPID := 1;
				root := SELF;
				mode := Running;
				gcContext.nextPos := 0;
				context := CurrentContext(); (* inherit context from parent process *)
				Unix.WriteKey( processPointer, SELF );
			END;
		END Initialize;

	END Process;


	GCStatusExt = OBJECT (Heaps.GCStatus)

		(*	called from Heaps.InvokeGC, i.e. this is a hidden upcall. However, it is necessary to take the Machine.Objects
			lock here since writing the set of variables here must not be interrupted, i.e. atomic writing of the set of variables
			is absolutely necessary.  They system may hang if the lock is not taken. *)
		PROCEDURE SetgcOngoing( value: BOOLEAN );
		VAR cur: Process;
		BEGIN (* serialize writers *)
			cur := CurrentProcess();
			IF value THEN
				Machine.Acquire( Machine.Objects );
				Machine.Acquire( Machine.Heaps );
				cur.state.SP := S.GetStackPointer();
				cur.state.BP := S.GetFramePointer();
				cur.state.PC := ADDRESSOF( GCLoop );
				IF ConcurrentGC THEN
					Heaps.CollectGarbage( Modules.root );
				ELSE
					SuspendActivities;
					Heaps.CollectGarbage( Modules.root );
					ResumeActivities;
				END; 
				Machine.Release( Machine.Heaps );
				Machine.Release( Machine.Objects );
				finalizerCaller.Activate;
			END;
		END SetgcOngoing;

	END GCStatusExt;



	PROCEDURE BodyStarter;
	VAR p: Process;  res: WORD; prevBP, sp: ADDRESS;
	BEGIN
		Unix.MtxLock( startEventLock );
			p := newProcess;  newProcess := NIL;
			Unix.WriteKey( processPointer, p );
			p.id := nextPID;  INC( nextPID );
			p.stackBottom := S.GetFramePointer( );
			S.GET( p.stackBottom, prevBP );
			S.PUT( prevBP, S.VAL( ADDRESS, 0 ) );	(* for terminating Reflection.StackTraceBack *)
			Unix.MtxLock( processList );
			p.nextProcess := root;  root := p;
			Unix.MtxUnlock( processList );
			Unix.CondSignal( childrunning );
		Unix.MtxUnlock( startEventLock );

		p.SetPriority( p.priority );

		IF Restart IN p.flags THEN
			(* store and restore stack pointer because it is saved on the stack during SYSVABI calls to ensure stack alignment *)
			sp := S.GetStackPointer ();
			res := Unix.sigsetjmp( ADDRESSOF( p.state0[0] ), 1 );
			S.SetStackPointer (sp);
		END;

		p.mode := Running;
		p.body( p.obj );
		p.mode := Terminated;
		Exit
	END BodyStarter;




	(*---------------------   create,  lock,  await,  unlock   -------------------------*)


	(* initialize the ObjectHeader, requires lockMutex temporarily *)
	PROCEDURE InitProtHeader( hdr {UNTRACED}: ObjectHeader);
	VAR lock: LockT;
	BEGIN
		(* we cannot hold the lockMute here because allocation can trigger the GC that requires the lock when activating the finalizers *)
		NEW(lock);
		Unix.MtxLock(lockMutex);
		IF hdr.lock = NIL THEN
			lock.mtx := Unix.NewMtx( );  lock.enter := Unix.NewCond( );  hdr.lockedBy := NIL;
			hdr.lock := lock;
		END;
		Unix.MtxUnlock(lockMutex);
	END InitProtHeader;


	PROCEDURE CreateProcess*( body: Body;  priority: LONGINT;  flags: SET;  obj: ProtectedObject );
	VAR p: Process;  hdr{UNTRACED}: ObjectHeader;
	BEGIN
		Unix.MtxLock( createProcess );
		S.GET( S.VAL( ADDRESS, obj ) + Heaps.HeapBlockOffset, hdr );
		InitProtHeader( hdr );
		IF priority = 0 THEN  priority := Normal  END;
		NEW( p, obj, body, priority, flags, stacksize ) ;	(* execute BodyStarter as new (posix or solaris) thread *)
		Unix.MtxUnlock( createProcess );
		RegisterFinalizer( obj, FinalizeActiveObj )
	END CreateProcess;

	PROCEDURE Lock*( obj: ProtectedObject;  exclusive: BOOLEAN );
	VAR hdr {UNTRACED}: ObjectHeader;  p : Process; lock: LockT;
	BEGIN
		ASSERT( exclusive );   (* shared not implemented yet *)
		S.GET( S.VAL( ADDRESS, obj ) + Heaps.HeapBlockOffset, hdr );
		p := CurrentProcess();
		p.state.SP := S.GetStackPointer( );
		p.state.BP := S.GetFramePointer( );
		p.state.PC := Machine.CurrentPC( );
		p.mode := AwaitingLock;

		(*! we might want to replace the lock mutex by a lock free construct *)
		IF hdr.lock = NIL THEN  InitProtHeader( hdr )  END;
		lock := S.VAL(LockT, hdr.lock);
		p.mode := AwaitingLock;
		Unix.MtxLock( lock.mtx );
		WHILE hdr.lockedBy # NIL DO
			(* wait until threads with complied AWAIT conditions have left the monitor *)
			Unix.CondWait( lock.enter, lock.mtx );
		END;
		p.mode := Running;  hdr.lockedBy := p;  p.waitingOn := NIL
	END Lock;

	PROCEDURE Await*( cond: Condition;  slink: ADDRESS;  obj: ProtectedObject;  flags: SET );
	VAR hdr {UNTRACED}: ObjectHeader;  p, c: Process; lock: LockT;
	BEGIN
		IF 1 IN flags THEN  (* compiler did not generate IF *)
			IF cond( slink ) THEN  (* condition already true *)  RETURN  END
		END;
		S.GET( S.VAL( ADDRESS, obj ) + Heaps.HeapBlockOffset, hdr );  c := NIL;
		lock := S.VAL(LockT, hdr.lock);
		IF hdr.awaitingCond.head # NIL THEN  c := FindCondition( hdr.awaitingCond )  END;

		p := CurrentProcess();
		ASSERT( hdr.lockedBy = p, 2204 );
		p.succ := NIL;  p.condition := cond;  p.condFP := slink;
		p.waitingOn := obj;  p.mode := AwaitingCond;

		Put( hdr.awaitingCond, p );
		hdr.lockedBy := c;
		IF c # NIL THEN  Unix.CondSignal( c.continue )  ELSE  Unix.CondSignal( lock.enter )  END;

		p.state.SP := S.GetStackPointer( );
		p.state.BP := S.GetFramePointer( );
		p.state.PC := Machine.CurrentPC( );
		Unix.CondWait( p.continue, lock.mtx );

		p.mode := Running;  hdr.lockedBy := p;  p.waitingOn := NIL
	END Await;

	PROCEDURE Unlock*( obj: ProtectedObject;  dummy: BOOLEAN );
	VAR hdr{UNTRACED}: ObjectHeader;  c: Process; lock: LockT;
	BEGIN
		S.GET( S.VAL( ADDRESS, obj ) + Heaps.HeapBlockOffset, hdr );  c := NIL;
		lock := S.VAL(LockT,hdr.lock);
		IF hdr.awaitingCond.head # NIL THEN  c := FindCondition( hdr.awaitingCond )  END;

		hdr.lockedBy := c;
		IF c # NIL THEN  Unix.CondSignal( c.continue )  ELSE  Unix.CondSignal( lock.enter )  END;
		Unix.MtxUnlock( lock.mtx );
	END Unlock;

	PROCEDURE FindCondition( VAR q: ProcessQueue ): Process;
	VAR first, cand: Process;
	BEGIN
		Get( q, first );
		IF first.condition( first.condFP ) THEN  RETURN first  ELSE  Put( q, first )  END;
		WHILE q.head # first DO
			Get( q, cand );
			IF cand.condition( cand.condFP ) THEN  RETURN cand  ELSE  Put( q, cand )  END;
		END;
		RETURN NIL
	END FindCondition;

	PROCEDURE Get( VAR queue: ProcessQueue;  VAR new: Process );
	VAR t: Process;
	BEGIN
		t := queue.head(Process);
		IF t # NIL THEN
			IF t = queue.tail THEN  queue.head := NIL;  queue.tail := NIL
			ELSE  queue.head := t.succ;  t.succ := NIL
			END
		END;
		new := t
	END Get;

	PROCEDURE Put( VAR queue: ProcessQueue;  t: Process );
	BEGIN
		IF queue.head = NIL THEN  queue.head := t  ELSE  queue.tail(Process).succ := t  END;
		queue.tail := t
	END Put;

	(*-------------------------------------------------------------------------*)

	PROCEDURE Terminate*;
	BEGIN
		Exit
	END Terminate;

	PROCEDURE TerminateThis*( p: Process; unbreakable: BOOLEAN );
	BEGIN
		p.mode := Terminated;
		p.Cancel
	END TerminateThis;

	PROCEDURE SetPriority*( pri: LONGINT );		(* Set the current process' priority. *)
	VAR me: Process;
	BEGIN
		me := CurrentProcess();
		me.SetPriority( pri )
	END SetPriority;

	PROCEDURE Sleep*( ms: LONGINT );
	BEGIN
		Unix.ThrSleep( ms );
	END Sleep;

	PROCEDURE Yield*;	(* Relinquish control. *)
	BEGIN
		Unix.ThrYield( );
	END Yield;

	(* Return current process. (DEPRECATED, use ActiveObject) *)
	PROCEDURE CurrentProcess*( ):  Process;
	BEGIN
		RETURN S.VAL( Process , Unix.ReadKey( processPointer ) )
	END CurrentProcess;

	PROCEDURE CurrentContext*(): ANY;
	VAR p : Process;
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


	(* Return the active object currently executing. *)
	PROCEDURE ActiveObject*( ): ANY;
	VAR p: Process;
	BEGIN
		p := CurrentProcess();
		RETURN p.obj
	END ActiveObject;


	(* Return stack bottom of process. For compatibility WinAos/UnixAos/NativeAos  *)
	PROCEDURE GetStackBottom*(p: Process): ADDRESS;
	BEGIN
		RETURN p.stackBottom
	END GetStackBottom;


	PROCEDURE GetProcessID*( ): LONGINT;
	VAR p: Process;
	BEGIN
		p := CurrentProcess();
		RETURN p.id;
	END GetProcessID;


	PROCEDURE GetCpuCycles*( process : Process; VAR cpuCycles: CpuCyclesArray; all: BOOLEAN );
	VAR temp : HUGEINT;
	BEGIN
		ASSERT(process # NIL);
		cpuCycles[0] := Machine.GetTimer();

		IF ~all THEN
			temp := process.lastThreadTimes;
			process.lastThreadTimes := cpuCycles[0];
			cpuCycles[0] := cpuCycles[0] - temp;
		END;
	END GetCpuCycles;



	(*-----------------------------------------------------------------------*)


	PROCEDURE RegisterFinalizer( obj: ANY;  fin: Heaps.Finalizer );
	VAR n: Heaps.FinalizerNode;
	BEGIN
		NEW( n ); n.finalizer := fin;  Heaps.AddFinalizer( obj, n );
	END RegisterFinalizer;


	PROCEDURE FinalizeActiveObj( obj: ANY );
	VAR p: Process;
	BEGIN
		Unix.MtxLock( processList );
			p := root;
			WHILE (p # NIL) & (p.obj # obj) DO p := p.nextProcess  END;
		Unix.MtxUnlock( processList );
		IF (p # NIL) & (p.obj = obj) THEN
			p.mode := Terminated;
			Unix.CondDestroy( p.continue );  p.continue := 0;
			FinalizeProtObject( obj );
			p.Cancel
		END;
	END FinalizeActiveObj;

	PROCEDURE FinalizeProtObject( obj: ANY );
	VAR hdr{UNTRACED}: ObjectHeader; lock: LockT;
	BEGIN
		S.GET( S.VAL( ADDRESS, obj ) + Heaps.HeapBlockOffset, hdr );
		IF hdr.lock # NIL THEN
			lock := S.VAL(LockT, hdr.lock);
			Unix.MtxDestroy( lock.mtx );  lock.mtx := 0
		END
	END FinalizeProtObject;


	PROCEDURE FinalizeProcess( obj: ANY );
	VAR p: Process;
	BEGIN
		p := obj(Process);
		IF p.continue # 0 THEN
			Unix.CondDestroy( p.continue );  p.continue := 0
		END
	END FinalizeProcess;

	(* Terminate calling thread. *)
	PROCEDURE Exit;
	VAR prev, p, me: Process;
	BEGIN
		me := CurrentProcess();
		me.mode := Terminated;
		Unix.MtxLock( processList );
		prev := NIL;  p := root;
		WHILE (p # NIL ) & (p # me) DO  prev := p;  p := p.nextProcess  END;
		IF p = me THEN
			IF prev = NIL THEN  root := p.nextProcess  ELSE  prev.nextProcess := p.nextProcess  END;
		END;
		Unix.MtxUnlock( processList );
		Unix.ThrExit( );
	END Exit;

	PROCEDURE ExitTrap*;
	VAR p: Process;
	BEGIN
		p := CurrentProcess();
		(* restart the object body if it was given the SAFE flag *)
		IF Restart IN p.flags THEN
			Unix.siglongjmp( ADDRESSOF( p.state0[0] ), 1 )
		END;
		Exit
	END ExitTrap;




	(*---------------------------- Timer --------------------------------*)


	PROCEDURE Remove( t: Timer );  (* remove timer from list of active timers *)
	VAR p, x: Timer;
	BEGIN
		Unix.MtxLock( timerListMutex );
		t.trigger := 0;  t.handler := NIL;
		IF timers # NIL THEN
			IF t = timers THEN
				timers := t.next
			ELSE
				p := timers;  x := p.next;
				WHILE (x # NIL) & (x # t)  DO  p := x;  x := p.next  END;
				IF x = t THEN  p.next := t.next  END
			END;
			t.next := NIL
		END;
		Unix.MtxUnlock( timerListMutex )
	END Remove;

	PROCEDURE Insert( t: Timer );
	VAR  p, x: Timer;
	BEGIN
		Unix.MtxLock( timerListMutex );
		p := NIL;  x := timers;
		WHILE (x # NIL) & (x.trigger < t.trigger)  DO  p := x;  x := p.next  END;
		t.next := x;
		IF p = NIL THEN  timers := t  ELSE   p.next := t  END;
		Unix.MtxUnlock( timerListMutex )
	END Insert;

	PROCEDURE SetTimeout*( t: Timer;  h: EventHandler;  ms: LONGINT );
	BEGIN
		ASSERT( ( t # NIL) & ( h # NIL) );
		Remove( t );
		IF ms < 1 THEN ms := 1 END;
		t.trigger := Machine.ticks + ms;  t.handler := h;
		Insert( t );
		timerActivity.Restart
	END SetTimeout;

	PROCEDURE SetTimeoutAt*( t: Timer;  h: EventHandler;  ms: LONGINT );
	BEGIN
		ASSERT( (t # NIL) & (h # NIL) );
		Remove( t );
		t.trigger := ms;  t.handler := h;
		Insert( t );
		timerActivity.Restart
	END SetTimeoutAt;

	PROCEDURE CancelTimeout*( t: Timer );
	BEGIN
		Remove( t )
	END CancelTimeout;



	(*--------------------  Garbage Collection  ------------------------------------*)


	PROCEDURE GetContext( ctxt: Unix.Ucontext );
	VAR t: Process; context: Unix.McontextDesc;
	BEGIN
		t := CurrentProcess( );
		Unix.CopyContext( ctxt.mc, context );
		t.state.PC := context.r_pc;
		t.state.BP := context.r_bp;
		t.state.SP := context.r_sp
	END GetContext;

	(* called by WMProcessInfo to obtain the current state of a running process *)
	PROCEDURE UpdateProcessState*( p: Process );
	BEGIN
		IF p.threadId = Unix.ThrThis( ) THEN
			p.state.PC := Machine.CurrentPC( );
			p.state.BP := S.GetFramePointer( );
			p.state.SP := S.GetStackPointer( )
		ELSE
			IF p.mode = Running THEN
				timerStopped := TRUE;
				Unix.ThrSleep( 3 );
				IF p.mode = Running THEN	(* still running *)
					Unix.ThrSuspend( p.threadId, TRUE );
					Unix.ThrResume( p.threadId );
				END;
				timerStopped := FALSE
			END
		END
	END UpdateProcessState;

	PROCEDURE SuspendActivities;
	VAR t, me: Process;
	BEGIN
		Unix.MtxLock( processList ); (* no process should silently quit during global thread suspension *)
		me := CurrentProcess();
		t := root;
		WHILE t # NIL DO
			IF t # me THEN
				Unix.ThrSuspend( t.threadId, t.mode = Running );
			END;
			t := t.nextProcess
		END;
		Unix.MtxUnlock( processList );
	END SuspendActivities;

	PROCEDURE ResumeActivities;
	VAR t, me: Process;
	BEGIN
		Unix.MtxLock( processList ); (* no process should silently quit during global thread suspension *)
		me := CurrentProcess();
		t := root;
		WHILE t # NIL DO
			IF (t # me) THEN
				Unix.ThrResume( t.threadId );
			END;
			t := t.nextProcess
		END;
		Unix.MtxUnlock( processList );
	END ResumeActivities;


	PROCEDURE GCLoop*;	(* Timer and GC activity *)
	BEGIN
		(*
		If using BootConsole keep main thread running.
		If the thread is blocked by a mutex (MainThreadSleep)
		the signals SIGHUP, SIGINT and SIGQUIT don't branch into SignalHandler
		but terminate A2 (at least in Solaris).
		*)
		LOOP Sleep( 100 ) END
	END GCLoop;

	PROCEDURE CurrentProcessTime*(): HUGEINT;
	BEGIN
		RETURN  Machine.GetTimer()
	END CurrentProcessTime;

	PROCEDURE TimerFrequency*(): HUGEINT;
	BEGIN
		RETURN Machine.mhz * 1000000
	END TimerFrequency;

	(* Leave A2 is called when a process leaves A2 by a call to the Unix API *)
	PROCEDURE LeaveA2*;
	VAR cur: Process; ebp,n: ADDRESS;
	BEGIN{UNTRACKED}
		IF clock # NIL THEN
			cur := CurrentProcess();
			IF cur # NIL THEN
				ebp := S.GetFramePointer();
				S.GET(ebp, n);
				IF ODD(n) THEN S.GET(ebp + SIZEOF(ADDRESS), ebp) ELSE ebp := n END;
				cur.gcContext.last[cur.gcContext.nextPos] := ebp;
				INC(cur.gcContext.nextPos);				
				ASSERT(cur.gcContext.nextPos < 255);
			END;
		END;
	END LeaveA2;

	(* reenter is called when a process returns from a call to the Unix API *)
	PROCEDURE ReenterA2*;
	VAR cur: Process;
	BEGIN{UNTRACKED}
		IF clock # NIL THEN 
		cur := CurrentProcess();
		IF cur # NIL THEN
			IF (cur.gcContext.nextPos > 0) THEN
				DEC(cur.gcContext.nextPos);
			END;
			cur.gcContext.last[cur.gcContext.nextPos] := NIL; (* returned *)
		END;
		END;
	END ReenterA2;


	(*----------------------------- initialization ----------------------------------*)

	PROCEDURE StartTimerActivity;
	BEGIN
		timerListMutex := Unix.NewMtx( );  timers := NIL;
		NEW( timerActivity );
	END StartTimerActivity;


	PROCEDURE GetStacksize;
	VAR str: ARRAY  32 OF  CHAR;  i: LONGINT;
	BEGIN
		Machine.GetConfig( "StackSize", str );
		IF str = "" THEN  stacksize := DefaultStacksize
		ELSE
			i := 0;  stacksize := Machine.StrToInt( i, str );
			stacksize := stacksize * 1024;
		END;
		IF Glue.debug # {} THEN
			Trace.String( "Stacksize of active objects = " );
			Trace.Int( stacksize DIV 1024, 0 );  Trace.StringLn( "K"  )
		END;
	END GetStacksize;


	PROCEDURE Convert;
	VAR p: Process;
	BEGIN
		(* make current thread the first active object  *)
		mainthread := Unix.ThrThis();
		NEW( p, NIL, NIL, 0, {}, 0 );
	END Convert;

	PROCEDURE Init;
	BEGIN
		Unix.suspendHandler := GetContext;

		createProcess := Unix.NewMtx( );  processList := Unix.NewMtx( );
		startEventLock := Unix.NewMtx( );  childrunning := Unix.NewCond( );
		lockMutex := Unix.NewMtx( );
		startProcess := Unix.NewMtx( );

		processPointer := Unix.NewKey( );

		GetStacksize;
		Convert;
		StartTimerActivity;  timerStopped := FALSE;
		NEW( clock );
		NEW( finalizerCaller );

		Heaps.gcStatus := GCStatusFactory()
	END Init;

TYPE
	MainThread = OBJECT
	VAR exit: BOOLEAN;

		PROCEDURE & Init;
		BEGIN
			exit := FALSE;
		END Init;

		PROCEDURE Await();
		BEGIN {EXCLUSIVE}
			AWAIT( exit );
		END Await;

	END MainThread;

VAR main: MainThread;

	PROCEDURE MainThreadSleep;
	BEGIN
		NEW( main );
		main.Await( );
		Unix.exit( 0 );
	END MainThreadSleep;

	PROCEDURE {FINAL} Final;
	BEGIN
		MainThreadSleep;
	END Final;

	PROCEDURE GCStatusFactory(): Heaps.GCStatus;
	VAR gcStatusExt : GCStatusExt;
	BEGIN
		ASSERT( Heaps.gcStatus = NIL );
		NEW( gcStatusExt );
		RETURN gcStatusExt
	END GCStatusFactory;

VAR
	(* for compatibility and later extension *)
	TraceProcessHook*: PROCEDURE (prcoess: Process; pc, bp: ADDRESS; stacklow, stackhigh: ADDRESS);

BEGIN
	TraceProcessHook := NIL;
	Init;
END Objects.

