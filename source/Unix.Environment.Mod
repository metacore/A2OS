(* Runtime environment for Unix *)
(* Copyright (C) Florian Negele *)

MODULE Environment;

IMPORT SYSTEM, Activities, Counters, Unix, Processors, Queues, Timer, Trace;

CONST IsNative* = FALSE;

CONST Running* = 0; ShuttingDown* = 1; Rebooting* = 2;

VAR status* := 0: WORD;
VAR clock: Timer.Counter;
VAR milliseconds: Timer.Counter;
VAR sleepingQueue: Queues.Queue;
VAR activity: Unix.Key_t;
VAR timer: Unix.Thread_t;

PROCEDURE {NORETURN} Abort-;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	IF Activities.GetCurrentActivity () # NIL THEN Activities.TerminateCurrentActivity END;
	Exit (1);
END Abort;

PROCEDURE Shutdown*;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	IF CAS (status, Running, ShuttingDown) # Running THEN RETURN END;
	Trace.StringLn ("system: shutting down...");
END Shutdown;

PROCEDURE Reboot*;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	Shutdown;
	ASSERT (CAS (status, ShuttingDown, Rebooting) = ShuttingDown);
END Reboot;

PROCEDURE {NORETURN} Exit- (status: WORD);
BEGIN {UNCOOPERATIVE, UNCHECKED}
	Trace.String ("system: exiting to Unix"); Trace.Ln;
	Unix.exit (status);
END Exit;

PROCEDURE Clock- (): LONGINT;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	RETURN LONGINT ((Timer.GetCounter () - clock) / milliseconds);
END Clock;

PROCEDURE Sleep- (milliseconds: LONGINT);
VAR nextActivity: Activities.Activity;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	INC (milliseconds, Clock ());
	Counters.Inc (Activities.awaiting);
	WHILE (status = Running) & (Clock () - milliseconds < 0) DO
		IF Activities.Select (nextActivity, Activities.IdlePriority) THEN
			Activities.SwitchTo (nextActivity, Enqueue, NIL);
			Activities.FinalizeSwitch;
		END;
	END;
	Counters.Dec (Activities.awaiting);
END Sleep;

PROCEDURE Enqueue (previous {UNTRACED}: Activities.Activity; argument: ADDRESS);
VAR item: Queues.Item;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	Queues.Enqueue (previous, sleepingQueue);
	IF status # Running THEN
		WHILE Queues.Dequeue (item, sleepingQueue) DO Activities.Resume (item(Activities.Activity)) END;
	END;
END Enqueue;

PROCEDURE {C} TimerThread (): ADDRESS;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	Activities.CallVirtual (TickLoop, NIL, Activities.CreateVirtualProcessor ());
	RETURN NIL;
END TimerThread;

PROCEDURE TickLoop (argument: ADDRESS);
VAR item: Queues.Item;
BEGIN
	WHILE status = Running DO
		Unix.ThrSleep (1);
		WHILE Queues.Dequeue (item, sleepingQueue) DO
			Activities.Resume (item(Activities.Activity));
		END;
	END;
	WHILE Queues.Dequeue (item, sleepingQueue) DO
		Activities.Resume (item(Activities.Activity));
	END;
END TickLoop;

PROCEDURE Allocate- (size: SIZE): ADDRESS;
VAR result, address: ADDRESS;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	result := Unix.malloc (size);
	IF result = NIL THEN RETURN NIL END;
	FOR address := result TO result + size - 1 DO SYSTEM.PUT8 (address, 0) END;
	RETURN result;
END Allocate;

PROCEDURE Deallocate- (address: ADDRESS);
BEGIN {UNCOOPERATIVE, UNCHECKED}
	Unix.free (address);
END Deallocate;

PROCEDURE GetInit- (n: SIZE; VAR val: LONGINT);
BEGIN val := 0;
END GetInit;

PROCEDURE GetString- (CONST name: ARRAY OF CHAR; VAR result: ARRAY OF CHAR);
BEGIN {UNCOOPERATIVE, UNCHECKED}
	result := "";
END GetString;

PROCEDURE StoreActivity-;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	Unix.WriteKey (activity, SYSTEM.GetActivity ());
END StoreActivity;

PROCEDURE RestoreActivity-;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	SYSTEM.SetActivity(SYSTEM.VAL(Activities.Activity,Unix.ReadKey (activity)));
END RestoreActivity;

PROCEDURE TrapHandler ( sig: LONGINT; mc: Unix.Mcontext );
PROCEDURE Trap EXTERN "Runtime.Trap" (number: SIZE);
BEGIN
	RestoreActivity;
	Trap (sig);
END TrapHandler;

PROCEDURE Initialize-;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	clock := Timer.GetCounter ();
	milliseconds := Timer.GetFrequency () DIV 1000;
	activity := Unix.NewKey ();
	Unix.HandleSignal(Unix.SIGSEGV);
	Unix.InstallTrap (TrapHandler);
END Initialize;

PROCEDURE Terminate-;
BEGIN {UNCOOPERATIVE, UNCHECKED}
END Terminate;

BEGIN
	Trace.String ("Build "); Trace.String (SYSTEM.Date); Trace.String (" (");
	Trace.String (Unix.Version); Trace.String (", GC, ");
	Trace.Int (Processors.count, 0); Trace.String (" CPU");
	IF Processors.count > 1 THEN Trace.Char ('s') END; Trace.String (", ");
	Trace.Int (SIZE OF ADDRESS * 8, 0); Trace.String ("-bit)"); Trace.Ln;
	ASSERT (Unix.pthread_create (ADDRESS OF timer, NIL, TimerThread, NIL) = 0);
END Environment.
