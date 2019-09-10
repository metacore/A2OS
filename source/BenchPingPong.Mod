MODULE BenchPingPong;	(* pjm *)

(* Test process ping-pong. *)

IMPORT Objects, Commands, Kernel;

CONST
	MaxProcs = 1024;

TYPE
	Yielder = OBJECT
		VAR count: SIGNED32; done: BOOLEAN;

		PROCEDURE &Init*;
		BEGIN
			done := FALSE
		END Init;

		PROCEDURE Join;
		BEGIN {EXCLUSIVE}
			AWAIT(done)
		END Join;

	BEGIN {ACTIVE, PRIORITY(Objects.Low)}
		WHILE wait DO Objects.Yield END;
		WHILE run DO INC(count); Objects.Yield END;
		BEGIN {EXCLUSIVE} done := TRUE END
	END Yielder;

VAR
	wait, run: BOOLEAN;

PROCEDURE Test1*(context : Commands.Context);	(* procs ms *)
VAR n, t, i, total: SIGNED32; timer: Kernel.Timer; p: ARRAY MaxProcs OF Yielder;
BEGIN
	IF context.arg.GetInteger(n, FALSE) & context.arg.GetInteger(t, FALSE) & (n >= 1) & (n <= LEN(p)) & (t > 0) THEN
		context.out.String("Test1 "); context.out.Int(n, 1); context.out.Char(" "); context.out.Int(t, 1);
		wait := TRUE; run := TRUE;
		FOR i := 0 TO n-1 DO NEW(p[i]) END;
		NEW(timer);
		wait := FALSE; timer.Sleep(t); run := FALSE;
		FOR i := 0 TO n-1 DO p[i].Join END;
		total := 0;
		FOR i := 0 TO n-1 DO INC(total, p[i].count) END;
		context.out.Char(" "); context.out.Int(total, 1);
		FOR i := 0 TO n-1 DO
			context.out.Char(" "); context.out.Int(p[i].count, 1)
		END;
		context.out.Ln
	END;
END Test1;

END BenchPingPong.

System.Free BenchPingPong ~

Aos.Call BenchPingPong.Test1 2 1000
Aos.Call BenchPingPong.Test1 3 1000
Aos.Call BenchPingPong.Test1 4 1000
Aos.Call BenchPingPong.Test1 5 1000
Aos.Call BenchPingPong.Test1 6 1000
Aos.Call BenchPingPong.Test1 7 1000
Aos.Call BenchPingPong.Test1 8 1000
Aos.Call BenchPingPong.Test1 64 1000
Aos.Call BenchPingPong.Test1 1024 1000

Aos.Call BenchPingPong.Test1 2 10000
Aos.Call BenchPingPong.Test1 4 10000
