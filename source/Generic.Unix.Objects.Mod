(* Aos, Copyright 2001, Pieter Muller, ETH Zurich *)

MODULE Objects;   (** AUTHOR "pjm, G.F."; PURPOSE "Active object runtime support"; *)


IMPORT S := SYSTEM, Trace, Glue, Unix, Machine, Heaps, Modules;

CONST

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
	
	AddrSize = SIZEOF( ADDRESS )


VAR
	(* timer *)
	timerActivity		: TimerActivity;
	clock					: Clock;
	timers				: Timer;  
	timerListMutex	: Unix.Mutex_t;
	
	(* processes *)
	mainProcess	: Process;	(* runs the GC *)
	root-	: Process;	(*!  Anchor of all instantiated threads in system *)
	stacksize: LONGINT;		(* stack size of active objects, adjustable via boot parameter *)
	
	processList		: Unix.Mutex_t;
	createProcess	: Unix.Mutex_t;
	startProcess	: Unix.Mutex_t;
	lockMutex		: Unix.Mutex_t;
	childrunning	: Unix.Condition_t;
		
	newProcess: Process;
	nextPID: LONGINT;
	
	(* garbage colletion *)
	gcFinished: Unix.Condition_t; igc: Unix.Mutex_t;
	collect: BOOLEAN;
	finalizerCaller	: FinalizerCaller;
	finCaller			: Process;
	
	

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
				IF h # NIL THEN  (* not canceled *) h  END
			ELSE				
				BEGIN{EXCLUSIVE}
					AWAIT( restart );  restart := FALSE;
				END
			END
		END
	END TimerActivity;
	
	Clock* = OBJECT
	BEGIN{ACTIVE}
		LOOP
				Unix.ThrSleep( 10 ); 
				timerActivity.UpdateTicks
		END;
	END Clock;



	FinalizedCollection* = OBJECT (* base type for collection, extended in Kernel.Mod *)
		PROCEDURE RemoveAll*(obj: ANY); (** abstract *)
		BEGIN HALT(301) END RemoveAll;
	END FinalizedCollection;

	FinalizerNode* = POINTER TO RECORD (Heaps.FinalizerNode)
		c*: FinalizedCollection (* base type for collection containing object *)
	END;

		
	FinalizerCaller = OBJECT	(* separate active object that calls finalizers *)
	VAR 
		n: Heaps.FinalizerNode;  start: BOOLEAN;
	
		PROCEDURE Activate;
		BEGIN {EXCLUSIVE}
			start := TRUE
		END Activate;
		
	BEGIN {ACTIVE, SAFE, PRIORITY(High)}
		finCaller := CurrentProcess( );  start := FALSE;
		LOOP 
			BEGIN {EXCLUSIVE} AWAIT( start ) END;
			start := FALSE;
			LOOP
				n := Heaps.GetFinalizer();
				IF n = NIL THEN EXIT END;
				IF n IS FinalizerNode THEN
					n(FinalizerNode).c.RemoveAll(n.objStrong)	(* remove it if it is not removed yet *)
				END;
				IF n.finalizer # NIL THEN
					n.finalizer(n.objStrong)	(* may acquire locks *)
				END;
			END;
		END
	END FinalizerCaller;
	


	Body = PROCEDURE ( self: ProtectedObject );
	Condition = PROCEDURE ( slink: ADDRESS ): BOOLEAN;
	
	Process* = OBJECT (Heaps.ProcessLink)
	VAR
		threadId-			: Unix.Thread_t;
		nextProcess-	: Process;	(* next in list of all processes *)
		stackBottom	-	: ADDRESS;
		context*: Unix.McontextDesc;
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
		procID-		: LONGINT;				(* processor ID where running, not used in UnixAos *)
		state-			: Machine.State;		(*! not used in UnixAos! *)
		state0	: ARRAY 2048 OF CHAR;		(* thread state at body start, used for restart after trap *)
					
				
		PROCEDURE FindRoots*;
		VAR sp, ptr, bp, n, a0, a1, adr: ADDRESS; desc: Modules.ProcedureDescPointer; i: LONGINT; p {UNTRACED}: ANY;
			me: Process;
		BEGIN
			IF mode # Terminated THEN
			

			IF SELF = CurrentProcess() THEN
				context.r_sp := Machine.CurrentSP();
				context.r_bp := Machine.CurrentBP();
				context.r_pc := ADDRESS OF FindRoots;
			END;
			
			sp := context.r_sp; bp := context.r_bp; (*pc := context.r_pc;*)

			(*
			TRACE(context.r_si, context.r_di, context.r_bp, context.r_sp_x);
			TRACE(context.r_bx, context.r_dx, context.r_cx, context.r_ax);
			TRACE(context.r_pc, context.r_sp, context.fpc);
			TRACE(sp, bp, stackBottom);
			*)

			IF Heaps.GCType= Heaps.HeuristicStackInspectionGC THEN
				Heaps.Candidate( context.r_di);  Heaps.Candidate( context.r_si );
				Heaps.Candidate( context.r_bx ); Heaps.Candidate( context.r_dx);
				Heaps.Candidate( context.r_cx ); Heaps.Candidate( context.r_ax);
				IF (stackBottom # 0) & (sp # 0) & (sp <= stackBottom) THEN
					(*TRACE(sp, stackBottom -sp);*)
					Heaps.RegisterCandidates( sp, stackBottom - sp );
				END;
			ELSIF Heaps.GCType = Heaps.MetaDataForStackGC THEN
				IF bp < stackBottom THEN
					WHILE (bp # Heaps.NilVal) & (bp > 1024) & (bp < stackBottom)  DO (* do not test for bp >= sp: could be wrong temporarily! *)
						TRACE(bp);
						S.GET(bp, n);
						TRACE(n);
						IF ODD(n) THEN (* procedure descriptor at bp *)
							IF n > 1024 THEN
							desc := S.VAL(Modules.ProcedureDescPointer, n-1);
							IF desc # NIL THEN
								a0 := ADDRESSOF(desc.offsets);
								a1 :=  S.VAL(ADDRESS, desc.offsets);
								ASSERT(a0+SIZEOF(ADDRESS)=a1,54321);
								FOR i := 0 TO LEN(desc.offsets)-1 DO
									adr := bp + desc.offsets[i]; (* pointer at offset *)
									S.GET(adr, p); (* load pointer *)
									IF p # NIL THEN 
										Heaps.Mark(p);
									END;
								END;
							END;
							END;
							S.GET(bp + SIZEOF(ADDRESS), bp);
						ELSE (* classical stack frame *)
							bp := n; 
						END;
						TRACE(bp);
					END;
					
					ASSERT((bp = stackBottom) OR (bp<1024) ,12345);
				END; 
			END;

			(*
				sp := context.r_sp;
				WHILE sp < stackBottom DO  
					S.GET( sp, ptr );  
					IF (ptr # 0) & (ptr MOD 8 = 0) THEN  Heaps.Candidate( ptr )  END;  
					INC( sp, AddrSize )  
				END;
				*)
			END;
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
			pr := max( Machine.prioLow, min( prio, Machine.prioHigh ) );
			Unix.ThrSetPriority( threadId, pr );	(* works only if SUID root *)
			priority := GetPriority( )	
		END SetPriority;
				
				
		PROCEDURE & Initialize( obj: ProtectedObject;  bodyProc: Body;  prio: LONGINT; fl: SET; stacksize: LONGINT);
		VAR  thr: Unix.Thread_t;
		BEGIN
			SELF.obj := obj;  condition := NIL;  continue := Unix.ConInit(0);
			flags := fl;
			priority := prio;
			nextProcess := NIL;
			IF root # NIL THEN
				newProcess := SELF;
				ASSERT( bodyProc # NIL );
				body := bodyProc;  
				Unix.MtxLock( startProcess );
				thr := Unix.ThrStart( BodyStarter, stacksize );
				Unix.ConWait( childrunning, startProcess );
				Unix.MtxUnlock( startProcess );
				RegisterFinalizer( SELF, FinalizeProcess );
			ELSE 
				(* first process *)
				stackBottom := Glue.stackBottom;  
				threadId := Unix.ThrThis(0);
				id := 0;  nextPID := 1;
				root := SELF;
				mainProcess := SELF;
				mode := Running;
			END;
		END Initialize;
				
	END Process;

	GCStatusExt = OBJECT(Heaps.GCStatus)
	
	(* called from Heaps.InvokeGC, i.e. this is a hidden upcall. However, it is necessary to take the Machine.Objects lock here since writing
		    the set of variables here must not be interrupted, i.e. atomic writing of the set of variables is absolutely necessary.  They system may hang
		    if the lock is not taken. *)
		PROCEDURE SetgcOngoing(value: BOOLEAN);
		VAR p: Heaps.ProcessLink; cur, r: Process; res: LONGINT; num: LONGINT; time: LONGINT;
		BEGIN (* serialize writers *)
			cur:= CurrentProcess();
			IF value THEN
				(*collect := TRUE; 
				
				TRACE(collect); 
				collect := FALSE;
				*)
				Machine.Acquire(Machine.Objects);
				Machine.Acquire( Machine.Heaps );
				cur.context.r_sp := Machine.CurrentSP();
				cur.context.r_bp := Machine.CurrentBP();
				cur.context.r_pc := ADDRESS OF GCLoop;
				(*
				TRACE(cur, cur.threadId, cur.context.r_sp, cur.context.r_bp, cur.context.r_pc);
				*)
				SuspendActivities;
				
				Heaps.CollectGarbage( Modules.root );
				Machine.Release( Machine.Heaps );
				Machine.Release(Machine.Objects);
				ResumeActivities;
				finalizerCaller.Activate;
				
			END;
		END SetgcOngoing;

	END GCStatusExt;


	
	PROCEDURE BodyStarter;
	VAR p{UNTRACED}: Process;  res: LONGINT; prevBP: ADDRESS; i: LONGINT;
	BEGIN
		Unix.MtxLock( startProcess );
			p := newProcess;  newProcess := NIL;
			p.threadId := Unix.ThrThis(0);  
			p.id := nextPID;  INC( nextPID );
			p.stackBottom := Machine.CurrentBP( );
			S.GET( p.stackBottom, prevBP );
			S.PUT( prevBP, S.VAL( ADDRESS, 0 ) );	(* for terminating Reflection.StackTraceBack *)
			Unix.MtxLock( processList );
				p.nextProcess := root;  root := p;
			Unix.MtxUnlock( processList );
			Unix.ConSignal( childrunning );
		Unix.MtxUnlock( startProcess );

		p.SetPriority( p.priority );

		IF Restart IN p.flags THEN
			res := Unix.sigsetjmp( ADDRESSOF( p.state0[0] ), 1 );
		END;

		p.mode := Running;
		p.body( p.obj );
		p.mode := Terminated;
		Exit
	END BodyStarter;




	(*---------------------   create,  lock,  await,  unlock   -------------------------*)
	
	(* initialize the ObjectHeader, requires lockMutex temporarily *)
	PROCEDURE InitProtHeader( hdr: ObjectHeader);
	VAR lock: LockT;
	BEGIN
		(* we cannot hold the lockMute here because allocation can trigger the GC that requires the lock when activating the finalizers *)
		NEW(lock);
		Unix.MtxLock(lockMutex);
		IF hdr.lock = NIL THEN
			hdr.lock := lock;
			lock.mtx := Unix.MtxInit( 0 );  lock.enter := Unix.ConInit( 0 );  hdr.lockedBy := NIL; 
		END;
		Unix.MtxUnlock(lockMutex);
	END InitProtHeader;
	
	
	PROCEDURE CreateProcess*( body: Body;  priority: LONGINT;  flags: SET;  obj: ProtectedObject );
	VAR p: Process;  hdr: ObjectHeader;
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
	VAR hdr: ObjectHeader;  p: Process; lock: LockT;
	BEGIN
		ASSERT( exclusive );   (* shared not implemented yet *)
		S.GET( S.VAL( ADDRESS, obj ) + Heaps.HeapBlockOffset, hdr );
		p := CurrentProcess();
		p.mode := AwaitingLock;

		(*! we might want to replace the lock mutex by a lock free construct *)
		IF hdr.lock = NIL THEN  InitProtHeader( hdr )  END;		
		lock := S.VAL(LockT, hdr.lock);
		Unix.MtxLock( lock.mtx );
		WHILE hdr.lockedBy # NIL DO
			(* wait until threads with complied AWAIT conditions have left the monitor *)
			Unix.ConWait( lock.enter, lock.mtx );
		END;
		p.mode := Running;  hdr.lockedBy := p;  p.waitingOn := NIL
	END Lock;

	PROCEDURE Await*( cond: Condition;  slink: ADDRESS;  obj: ProtectedObject;  flags: SET );
	VAR hdr: ObjectHeader;  p, c: Process; lock: LockT;
	BEGIN
		IF 1 IN flags THEN  (* compiler did not generate IF *)
			IF cond( slink ) THEN  (* condition already true *)  RETURN  END
		END;
		S.GET( S.VAL( ADDRESS, obj ) + Heaps.HeapBlockOffset, hdr );  c := NIL;
		lock := S.VAL(LockT, hdr.lock);
		IF hdr.awaitingCond.head # NIL THEN  c := FindCondition( hdr.awaitingCond )  END;
		
		p := CurrentProcess();  p.succ := NIL;  p.condition := cond;  p.condFP := slink;   
		p.waitingOn := obj;  p.mode := AwaitingCond;
		
		Put( hdr.awaitingCond, p );
		hdr.lockedBy := c;
		IF c # NIL THEN  Unix.ConSignal( c.continue )  ELSE  Unix.ConSignal( lock.enter )  END;
		Unix.ConWait( p.continue, lock.mtx );   
		
		p.mode := Running;  hdr.lockedBy := p;  p.waitingOn := NIL
	END Await;

	PROCEDURE Unlock*( obj: ProtectedObject;  dummy: BOOLEAN );
	VAR hdr: ObjectHeader;  c: Process; lock: LockT;
	BEGIN
		S.GET( S.VAL( ADDRESS, obj ) + Heaps.HeapBlockOffset, hdr );  c := NIL;
		lock := S.VAL(LockT,hdr.lock);
		IF hdr.awaitingCond.head # NIL THEN  c := FindCondition( hdr.awaitingCond )  END;
		
		hdr.lockedBy := c;
		IF c # NIL THEN  Unix.ConSignal( c.continue )  ELSE  Unix.ConSignal( lock.enter )  END;
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
		Unix.ThrSleep( ms )
	END Sleep;

	PROCEDURE Yield*;	(* Relinquish control. *)
	BEGIN
		Unix.ThrYield(0);
	END Yield;
	
	(* Return current process. (DEPRECATED, use ActiveObject) *)
	PROCEDURE CurrentProcess*( ): Process;	
	VAR me: Unix.Thread_t;  p: Process;
	BEGIN
		me := Unix.ThrThis(0);
		Unix.MtxLock( processList );
		p := root;
		WHILE (p # NIL) & (p.threadId # me) DO  p := p.nextProcess  END;
		Unix.MtxUnlock( processList );
		RETURN p
	END CurrentProcess;

	
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
	VAR
		i,res: LONGINT;
		time: Unix.tvPtr;
	BEGIN
		ASSERT( process # NIL );
		NEW(time);
		(*res:=Unix.clock_gettime(3,time);
		cpuCycles[0]:=time.usec;*)
		cpuCycles[0]:=5;
		(*todo*)
		
		(*FOR i := 0 TO Machine.MaxCPU-1 DO  
		
			cpuCycles[i] := 0  
			
		END;*)
	END GetCpuCycles;
	
	
	
	(*-----------------------------------------------------------------------*)
	
	
	PROCEDURE min( a, b: LONGINT ): LONGINT;
	BEGIN
		IF a <= b THEN  RETURN a  ELSE  RETURN b  END
	END min;

	PROCEDURE max( a, b: LONGINT ): LONGINT;
	BEGIN
		IF a >= b THEN  RETURN a  ELSE  RETURN b  END
	END max;
	
	
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
			Unix.ConDestroy( p.continue );  p.continue := 0;
			FinalizeProtObject( obj );
			p.Cancel
		END;
	END FinalizeActiveObj;

	PROCEDURE FinalizeProtObject( obj: ANY );
	VAR hdr: ObjectHeader; lock: LockT;
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
			Unix.ConDestroy( p.continue );  p.continue := 0
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
		Unix.ThrExit(0);
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
	
	PROCEDURE GetContext(ctxt: Unix.Ucontext);
	VAR t: Process; bp: ADDRESS;
	BEGIN
		t := CurrentProcess();
		(*
		TRACE(t, t.threadId);
		TRACE(Machine.CurrentBP(), ctxt.mc.r_bp);
		*)
		Unix.CopyContext(ctxt.mc, t.context);
		(*
		bp := Machine.CurrentBP(); 
		TRACE(bp);
		S.GET(bp+4, bp); 
		TRACE(bp);
		t.context.r_bp := bp;
		*)
	END GetContext;
	
	PROCEDURE SuspendActivities;
	VAR t,me: Process;  res: LONGINT;
	BEGIN
		me := CurrentProcess();
		t := root;
				
		WHILE t # NIL DO
			IF (t # me) THEN  
				Unix.ThrSuspend(t.threadId ); 
			END;
			t := t.nextProcess
		END;
	(*
	VAR t, me: Process;  
	BEGIN
		
		t := root;
		WHILE t # NIL DO
			IF (t # mainProcess) & (t # finCaller) THEN  Unix.ThrSuspend( t.threadId )  END;
			t := t.nextProcess
		END;
	*)
	END SuspendActivities;

	PROCEDURE ResumeActivities;
	VAR t, me: Process;  
	BEGIN
		me := CurrentProcess();
		t := root;
		WHILE t # NIL DO
			IF (t # me) (* (t # mainProcess) & (t # finCaller)*)  THEN  Unix.ThrResume( t.threadId )  END;
			t := t.nextProcess
		END;
	END ResumeActivities;
	
	(*
	PROCEDURE InvokeGC;
	BEGIN
		IF Machine.AcquireGC() THEN (* gets released by FinalizerCaller *)
			collect := TRUE;
			Unix.ConWait( gcFinished, igc )
		END;
	END InvokeGC;
	
	*)
	
	(*!	GCLoop gets called as last procedure in BootConsole (main thread). 
		The stack of the main thread is not limited by the  boot parameter 'StackSize' !!
	*)
	
	PROCEDURE GCLoop*;	(* Timer and GC activity *)
	VAR cur: Process;
	BEGIN
		RETURN;
		(*
		cur:= CurrentProcess();
		SetPriority( GCPriority );
		LOOP
			IF collect THEN  
				TRACE(collect); 
				collect := FALSE;
				Machine.Acquire( Machine.Heaps );
				cur.context.r_sp := Machine.CurrentSP();
				cur.context.r_bp := Machine.CurrentBP();
				cur.context.r_sp := ADDRESS OF GCLoop;

				SuspendActivities;
				
				Heaps.CollectGarbage( Modules.root );
				Machine.Release( Machine.Heaps );
				ResumeActivities;
				finalizerCaller.Activate;
				(*Unix.ConSignal( gcFinished );*)
			ELSE
				Unix.ThrSleep( 10 ); 
			END;
			timerActivity.UpdateTicks
		END
		*)
	END GCLoop;	
	
	
	
	
	
	PROCEDURE CurrentProcessTime*(): HUGEINT;
	BEGIN
		RETURN  Machine.GetTimer()
	END CurrentProcessTime;
	
	PROCEDURE TimerFrequency*(): HUGEINT;
	BEGIN
		RETURN Machine.mhz * 1000000
	END TimerFrequency;

	
	(*----------------------------- initialization ----------------------------------*)
	
	PROCEDURE StartTimerActivity;
	BEGIN
		timerListMutex := Unix.MtxInit(0);  timers := NIL;  
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
		NEW( p, NIL, NIL, 0, {}, 0 );
	END Convert;

	PROCEDURE Init;
	BEGIN
		Unix.suspendHandler := GetContext;
		(*
		Unix.Dlsym( 0, "Unix.MtxInit",		ADDRESSOF( Unix.MtxInit ) );
		Unix.Dlsym( 0, "Unix.MtxDestroy",	ADDRESSOF( Unix.MtxDestroy ) );
		Unix.Dlsym( 0, "Unix.MtxLock",		ADDRESSOF( Unix.MtxLock ) );
		Unix.Dlsym( 0, "Unix.MtxUnlock",	ADDRESSOF( Unix.MtxUnlock ) );
		Unix.Dlsym( 0, "Unix.ConInit",		ADDRESSOF( Unix.ConInit ) );
		Unix.Dlsym( 0, "Unix.ConDestroy",	ADDRESSOF( Unix.ConDestroy ) );
		Unix.Dlsym( 0, "Unix.ConWait",		ADDRESSOF( Unix.ConWait ) );
		Unix.Dlsym( 0, "Unix.ConSignal",	ADDRESSOF( Unix.ConSignal ) );
		
		Unix.Dlsym( 0, "thrStart",	ADDRESSOF( thrStart ) );
		Unix.Dlsym( 0, "Unix.ThrThis",		ADDRESSOF( Unix.ThrThis ) );
		Unix.Dlsym( 0, "Unix.ThrSleep",	ADDRESSOF( Unix.ThrSleep ) );
		Unix.Dlsym( 0, "Unix.ThrYield",	ADDRESSOF( Unix.ThrYield ) );
		Unix.Dlsym( 0, "Unix.ThrExit",		ADDRESSOF( Unix.ThrExit ) );
		Unix.Dlsym( 0, "Unix.ThrSuspend",			ADDRESSOF( Unix.ThrSuspend ) );
		Unix.Dlsym( 0, "Unix.ThrResume",			ADDRESSOF( Unix.ThrResume ) );
		Unix.Dlsym( 0, "Unix.ThrGetPriority",	ADDRESSOF( Unix.ThrGetPriority ) );
		Unix.Dlsym( 0, "Unix.ThrSetPriority",	ADDRESSOF( Unix.ThrSetPriority ) );
		Unix.Dlsym( 0, "thrKill",				ADDRESSOF( thrKill ) );
		*)
		
		createProcess := Unix.MtxInit( 0 );  processList := Unix.MtxInit( 0 );
		startProcess := Unix.MtxInit(0);  childrunning := Unix.ConInit(0); 
		lockMutex := Unix.MtxInit(0);
				
		collect := FALSE;
		igc := Unix.MtxInit( 0 );  gcFinished := Unix.ConInit( 0 ); 
							
		GetStacksize;  
		Convert;
		NEW(clock);
		StartTimerActivity;
		
		NEW( finalizerCaller );
		Heaps.gcStatus := GCStatusFactory()
	END Init;

TYPE 
	MainThread = OBJECT
	VAR exit: BOOLEAN;
		
		PROCEDURE&  Init;
		BEGIN
			exit := FALSE;
		END Init;
		
		PROCEDURE Await();
		BEGIN{EXCLUSIVE}
			AWAIT(exit);
		END Await;

	END MainThread;
	
	VAR main: MainThread;
	
	PROCEDURE MainThreadSleep;
	BEGIN
		NEW(main);
		main.Await();
		Unix.exit(0);
	END MainThreadSleep;
	
	PROCEDURE {FINAL} Final;
	BEGIN
		MainThreadSleep;
	END Final;

	PROCEDURE GCStatusFactory(): Heaps.GCStatus;
	VAR gcStatusExt : GCStatusExt;
	BEGIN
		ASSERT(Heaps.gcStatus = NIL);
		NEW(gcStatusExt);
		RETURN gcStatusExt
	END GCStatusFactory;

BEGIN
	Init;
END Objects.

