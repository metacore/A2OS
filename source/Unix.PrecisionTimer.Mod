(**
	AUTHOR: Alexey Morozov
	PURPOSE: high precision timer support for Unix platforms
*)
MODULE PrecisionTimer;

IMPORT
	Unix, KernelLog;

TYPE
	Counter* = HUGEINT; (** Timer counter value type *)

CONST
	(*
		The IDs of the various system clocks (for POSIX.1b interval timers):
	*)
	CLOCK_REALTIME = 0;
	CLOCK_MONOTONIC = 1;
	CLOCK_PROCESS_CPUTIME_ID = 2;
	CLOCK_THREAD_CPUTIME_ID = 3;
	CLOCK_MONOTONIC_RAW = 4;
	CLOCK_REALTIME_COARSE = 5;
	CLOCK_MONOTONIC_COARSE = 6;
	CLOCK_BOOTTIME = 7;
	CLOCK_REALTIME_ALARM = 8;
	CLOCK_BOOTTIME_ALARM = 9;

TYPE
	Timespec = RECORD
		sec: LONGWORD;
		nsec: LONGINT;
	END;

VAR
	clock_gettime: PROCEDURE{C}(clk_id: LONGINT; CONST tp: Timespec): LONGINT;
	clock_getres: PROCEDURE{C}(clk_id: LONGINT; CONST res: Timespec): LONGINT;

	(*! It is preferable to use CLOCK_MONOTONIC_RAW (not influenced by system time adjustments),
		but for some reason CLOCK_MONOTONIC is ~3 times faster
	*)
	clockType := CLOCK_MONOTONIC: LONGINT; (* timer clock type *)
	frequency: Counter; (* timer frequency in Hz *)

	(**
		Query timer counter in ticks
	*)
	PROCEDURE GetCounter*(): Counter;
	VAR t: Timespec;
	BEGIN
		IF clock_gettime(clockType, t) = 0 THEN
			RETURN HUGEINT(t.sec)*1000000000 + HUGEINT(t.nsec);
		ELSE
			RETURN 0;
		END;
	END GetCounter;

	(**
		Query timer tick frequency in Hz
	*)
	PROCEDURE GetFrequency*(): Counter;
	VAR t: Timespec;
	BEGIN
		IF clock_getres(clockType, t) = 0 THEN
			(*! a workaround for not known actual clock frequency *)
			RETURN ENTIERH(1.0D9 / t.nsec + 0.5D0);
		ELSE
			RETURN 0;
		END;
	END GetFrequency;

	PROCEDURE InitMod;
	VAR frequency: Counter;
	BEGIN
		Unix.Dlsym(Unix.libc, "clock_gettime", ADDRESSOF(clock_gettime));
		ASSERT(clock_gettime # NIL);
		Unix.Dlsym(Unix.libc, "clock_getres", ADDRESSOF(clock_getres));
		ASSERT(clock_getres # NIL);

		KernelLog.String("PrecisionTimer: timer tick frequency is "); KernelLog.Int(GetFrequency(),0); KernelLog.String(" Hz"); KernelLog.Ln;
	END InitMod;

BEGIN
	InitMod;
END PrecisionTimer.

SystemTools.Free PrecisionTimer ~