(* Runtime support for high precision timer *)
(* Copyright (C) Florian Negele *)

MODULE Timer;

IMPORT Unix;

CONST Clock = Unix.CLOCK_MONOTONIC;

TYPE Counter* = LONGINTEGER;

PROCEDURE GetCounter- (): Counter;
VAR timespec: Unix.Timespec; result: Counter;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	ASSERT (Unix.clock_gettime (Clock, ADDRESS OF timespec) = 0);
	result := timespec.tv_sec; result := result * 1000000; INC (result, timespec.tv_nsec DIV 1000); RETURN result;
END GetCounter;

PROCEDURE GetFrequency- (): Counter;
VAR timespec: Unix.Timespec;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	IF Unix.clock_getres (Clock, ADDRESS OF timespec) # 0 THEN RETURN 0 END;
	ASSERT ((timespec.tv_sec = 0) & (timespec.tv_nsec = 1)); RETURN 1000000;
END GetFrequency;

END Timer.
