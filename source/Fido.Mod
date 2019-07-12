(* Aos, Copyright 2001, Pieter Muller, ETH Zurich *)

MODULE Fido; (** AUTHOR "pjm"; PURPOSE "Watchdog debugging"; *)

IMPORT KernelLog, Modules, Objects, Kernel, Streams, ProcessInfo;

TYPE
	Watchdog* = OBJECT
		VAR
			timer: Kernel.Timer; delay: LONGINT; time: Kernel.MilliTimer; alive, done: BOOLEAN;
			name: ARRAY 32 OF CHAR;

		PROCEDURE Cleanup;
		BEGIN {EXCLUSIVE}
			timer.Wakeup;
			alive := FALSE;
			AWAIT(done)
		END Cleanup;

		PROCEDURE Done;
		BEGIN {EXCLUSIVE}
			done := TRUE
		END Done;

		PROCEDURE Reset*;
		BEGIN
			Kernel.SetTimer(time, delay)
		END Reset;

		PROCEDURE &Init*(CONST name: ARRAY OF CHAR; delay: LONGINT);
		BEGIN
			COPY(name, SELF.name); SELF.delay := delay;
			alive := TRUE; done := FALSE;
			NEW(timer)
		END Init;

	BEGIN {ACTIVE}
		LOOP
			timer.Sleep(delay);
			IF ~alive THEN EXIT END;
			IF Kernel.Expired(time) THEN
				KernelLog.String("Watchdog "); KernelLog.String(name); KernelLog.Ln;
				Action
			END
		END;
		Done
	END Watchdog;

VAR
	watchdog: Watchdog;

PROCEDURE Action*;
VAR
	processes : ARRAY ProcessInfo.MaxNofProcesses OF Objects.Process;
	nofProcesses, i : SIZE;
	writer: Streams.Writer;
BEGIN
	Streams.OpenWriter(writer, KernelLog.Send);
	ProcessInfo.GetProcesses(processes, nofProcesses);
	ProcessInfo.Sort(processes, nofProcesses, ProcessInfo.SortByID);
	FOR i := 0 TO nofProcesses - 1 DO
		ProcessInfo.ShowProcess(processes[i], writer);
	END;
END Action;

PROCEDURE Allocate;
BEGIN {EXCLUSIVE}
	IF watchdog = NIL THEN NEW(watchdog, "Default", 5000) END
END Allocate;

PROCEDURE Reset*;
BEGIN
	IF watchdog = NIL THEN Allocate END;
	watchdog.Reset
END Reset;

PROCEDURE Cleanup;
BEGIN
	IF watchdog # NIL THEN watchdog.Cleanup END
END Cleanup;

BEGIN
	watchdog := NIL;
	Modules.InstallTermHandler(Cleanup)
END Fido.

Fido.Reset

System.Free Fido ~
