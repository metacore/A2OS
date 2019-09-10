MODULE BenchNew;	(* pjm *)

(* Test memory allocation performance. *)

IMPORT Kernel, Commands;

PROCEDURE TestNew*(context : Commands.Context);
VAR i, n, t: SIGNED32;
BEGIN
	i := Kernel.GetTicks();
	REPEAT t := Kernel.GetTicks() UNTIL t # i;
	t := Kernel.GetTicks() - t;
	context.out.Int(n, 1); context.out.String(" loops, ");
	context.out.Int(t*1000 DIV Kernel.second, 1); context.out.String(" ms");
END TestNew;

END BenchNew.
