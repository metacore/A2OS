MODULE BenchLocks;	(* pjm *)

(* Test lock performance *)

IMPORT Machine, Kernel, Commands;

CONST
	Level = Machine.KernelLog;

TYPE

	Thread = OBJECT
	VAR
		nofLoops, holdTime : SIGNED32;
		i, j : SIGNED32;

		PROCEDURE &Init*(nofLoops, holdTime : SIGNED32);
		BEGIN
			ASSERT((nofLoops > 0) & (holdTime >= 0));
			SELF.nofLoops := nofLoops;
			SELF.holdTime := holdTime;
		END Init;

	BEGIN {ACTIVE}
		LOOP
			FOR i := 7 TO 0 BY -1 DO
				Machine.Acquire(i);
				FOR j := 0 TO holdTime DO
					(* skip *)
				END;
				Machine.Release(i);
			END;
			DEC(nofLoops);
			IF (nofLoops <= 0) THEN EXIT; END;
		END;
		DecNofThreadsRunning;
	END Thread;

VAR
	nofThreadsRunning : SIGNED32;

PROCEDURE DecNofThreadsRunning;
BEGIN {EXCLUSIVE}
	DEC(nofThreadsRunning);
END DecNofThreadsRunning;

PROCEDURE Bench*(context : Commands.Context); (** nofThreads nofLoops [holdTime] ~*)
VAR start, nofThreads, nofLoops, holdTime : SIGNED32; i : SIZE; threads : POINTER TO ARRAY OF Thread;
BEGIN {EXCLUSIVE}
	context.arg.SkipWhitespace; context.arg.Int(nofThreads, FALSE);
	context.arg.SkipWhitespace; context.arg.Int(nofLoops, FALSE);
	context.arg.SkipWhitespace; context.arg.Int(holdTime, FALSE);
	IF (nofThreads > 0) & (nofLoops > 0) & (holdTime >= 0) THEN
		context.out.String("Starting "); context.out.Int(nofThreads, 0);
		context.out.String(" threads where each acquires each kernel lock ");
		context.out.Int(nofLoops, 0); context.out.String(" times (HoldTime: ");
		context.out.Int(holdTime, 0); context.out.String(") ..."); context.out.Update;
		nofThreadsRunning := nofThreads;
		NEW(threads, nofThreads);
		start := Kernel.GetTicks();
		FOR i := 0 TO LEN(threads)-1 DO
			NEW(threads[i], nofLoops, holdTime);
		END;
		AWAIT(nofThreadsRunning = 0);
		context.out.String("Time required: "); context.out.Int(Kernel.GetTicks() - start, 0);
		context.out.String(" ms");
	ELSE
		context.out.String("Parameter error: nofThreads & nofLoops must be > 0, holdTime must be >= 0");
	END;
	context.out.Ln;
END Bench;

PROCEDURE TestAcquire*(context : Commands.Context);	(* num *)
VAR i, n, t: SIGNED32;
BEGIN
	IF context.arg.GetInteger(n, FALSE) & (n > 0) THEN
		i := Kernel.GetTicks();
		REPEAT t := Kernel.GetTicks() UNTIL t # i;
		FOR i := 1 TO n DO
			Machine.Acquire(Level);
			Machine.Release(Level)
		END;
		t := Kernel.GetTicks() - t;
		context.out.Int(n, 1); context.out.String(" loops, ");
		context.out.Int(t*1000 DIV Kernel.second, 1); context.out.String(" ms");
		context.out.Ln;
	END;
END TestAcquire;

END BenchLocks.

System.Repeat 3
	BenchLocks.Bench 32 100000 500 ~

BenchLocks.Bench 64 100000 500 ~

System.Free BenchLocks ~

Configuration.DoCommands
System.Time start
Aos.Call \w BenchLocks.TestAcquire 10000000 ~
System.Time lap
~

{P1 1000000 loops, 6105 ms} with Stats and nestCount
{P1 1000000 loops, 6005 ms} removed nestCount
{P1 1000000 loops, 2270 ms} disabled Stats
{P1 1000000 loops, 2201 ms} added quick acquire
