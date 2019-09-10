(* Aos, Copyright 2001, Pieter Muller, ETH Zurich *)

MODULE BenchSpeedup;	(* pjm *)

(* A trivially parallel program to test speedups. *)

IMPORT Kernel, Commands;

TYPE
	Work = OBJECT
		VAR n, i: SIGNED32; done: BOOLEAN;

		PROCEDURE &Init*(n: SIGNED32);
		BEGIN
			SELF.n := n; done := FALSE
		END Init;

		PROCEDURE WaitFinished;
		BEGIN {EXCLUSIVE}
			AWAIT(done)
		END WaitFinished;

		PROCEDURE Finish;
		BEGIN {EXCLUSIVE}
			done := TRUE
		END Finish;

	BEGIN {ACTIVE}
		FOR i := 1 TO n DO (* skip *) END;
		Finish
	END Work;

PROCEDURE Mark*(context : Commands.Context);	(** procs n *)
VAR i, p, n, t: SIGNED32; w: POINTER TO ARRAY OF Work;
BEGIN
	context.arg.SkipWhitespace; context.arg.Int(p, FALSE);
	context.arg.SkipWhitespace; context.arg.Int(n, FALSE);
	IF p > 0 THEN
		NEW(w, p);
		i := Kernel.GetTicks();
		REPEAT t := Kernel.GetTicks() UNTIL t # i;
		FOR i := 0 TO p-1 DO NEW(w[i], n) END;
		FOR i := 0 TO p-1 DO w[i].WaitFinished END;
		t := Kernel.GetTicks() - t;
		context.out.Int(p, 1); context.out.String(" procs, "); context.out.Int(n, 1); context.out.String(" loops, ");
		context.out.Int(t*1000 DIV Kernel.second, 1); context.out.String(" ms");
	END;
END Mark;

END BenchSpeedup.

System.Free BenchSpeedup ~

System.OpenKernelLog

Aos.Call BenchSpeedup.Mark 1 1000000000
Aos.Call BenchSpeedup.Mark 2 500000000
Aos.Call BenchSpeedup.Mark 3 333333333
Aos.Call BenchSpeedup.Mark 4 250000000
Aos.Call BenchSpeedup.Mark 5 200000000
Aos.Call BenchSpeedup.Mark 6 166666666
Aos.Call BenchSpeedup.Mark 7 142857142
Aos.Call BenchSpeedup.Mark 8 125000000

On rosebud, 07.02.2001 19:00
{P0 1 procs, 1000000000 loops, 9272 ms}
{P4 1 procs, 1000000000 loops, 9525 ms}
{P2 1 procs, 1000000000 loops, 9528 ms}
{P4 2 procs, 500000000 loops, 4783 ms}
{P4 2 procs, 500000000 loops, 4782 ms}
{P0 2 procs, 500000000 loops, 4732 ms}
{P0 3 procs, 333333333 loops, 3187 ms}
{P1 3 procs, 333333333 loops, 3190 ms}
{P4 3 procs, 333333333 loops, 3190 ms}
{P4 4 procs, 250000000 loops, 2385 ms}
{P3 4 procs, 250000000 loops, 2386 ms}
{P3 4 procs, 250000000 loops, 2384 ms}
{P3 5 procs, 200000000 loops, 1905 ms}
{P4 5 procs, 200000000 loops, 1909 ms}
{P1 5 procs, 200000000 loops, 1904 ms}
{P2 6 procs, 166666666 loops, 1589 ms}
{P2 6 procs, 166666666 loops, 1591 ms}
{P4 6 procs, 166666666 loops, 1586 ms}
{P0 7 procs, 142857142 loops, 1583 ms}
{P0 7 procs, 142857142 loops, 1580 ms}
{P1 7 procs, 142857142 loops, 1581 ms}
{P2 8 procs, 125000000 loops, 1583 ms}
{P0 8 procs, 125000000 loops, 1583 ms}
{P4 8 procs, 125000000 loops, 1583 ms}
