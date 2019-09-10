(* Aos, Copyright 2001, Pieter Muller, ETH Zurich *)

MODULE BenchClockDrift;	(* pjm *)

(* Test clock drift on different processors. *)

IMPORT Machine, KernelLog, Kernel;

PROCEDURE Run*;
VAR t: SIGNED64; i: SIGNED32; m: Kernel.MilliTimer;
BEGIN
	FOR i := 1 TO 10 DO
		Kernel.SetTimer(m, 1);
		REPEAT UNTIL Kernel.Expired(m);
		t := Machine.GetTimer();
		Kernel.SetTimer(m, 1000);
		REPEAT UNTIL Kernel.Expired(m);
		t := Machine.GetTimer() - t;
		KernelLog.Enter;
		KernelLog.Int(SHORT (t), 1);
		KernelLog.Exit
	END
END Run;

END BenchClockDrift.

BenchClockDrift.Run
