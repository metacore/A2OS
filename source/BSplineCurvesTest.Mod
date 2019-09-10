MODULE BSplineCurvesTest;
(**
	AUTHOR "Alexey Morozov";
	PURPOSE "Parametric curves in B-Spline representation, a testing module";
*)

IMPORT
	BSplineCurves, KernelLog, MathL, Kernel;

	PROCEDURE Test*;
	VAR
		degree: SIGNED32;
		closed: BOOLEAN;
		curve: BSplineCurves.Curve;
		i, N: SIGNED32;
		d, t: FLOAT64;
		kx, ky, x, y: ARRAY [*] OF FLOAT64;
		t1, t2, t3: SIGNED32;
		timer: Kernel.MilliTimer;
	BEGIN

		degree := 3; (* B-Spline degree *)
		closed := TRUE; (* flag for open/closed curve *)
		N := 32; (* number of curve knots *)

		(* use knots as points on an ellipse *)
		NEW(kx,N); NEW(ky,N);
		d := 2.0D0*MathL.pi / N; t := 0;
		FOR i := 0 TO N-1 DO
			kx[i] := 640*MathL.cos(t);
			ky[i] := 480*MathL.sin(t);
			t := t + d;
		END;

		(* construct a curve object *)
		Kernel.SetTimer(timer,0);
		NEW(curve,degree,closed);
		t1 := Kernel.Elapsed(timer);

		(* set curve control knots *)
		Kernel.SetTimer(timer,0);
		curve.SetKnots(kx,ky);
		t2 := Kernel.Elapsed(timer);

		(* get polyline for rendering the curve *)
		Kernel.SetTimer(timer,0);
		curve.GetPoly(1/2,x,y);
		t3 := Kernel.Elapsed(timer);

		KernelLog.String("Number of output points: "); KernelLog.Int(LEN(x,0),0); KernelLog.Ln;
		KernelLog.String("Curve construction: "); KernelLog.Int(t1,0); KernelLog.String(" ms"); KernelLog.Ln;
		KernelLog.String("Setting curve knots: "); KernelLog.Int(t2,0); KernelLog.String(" ms"); KernelLog.Ln;
		KernelLog.String("Getting curve polyline points: "); KernelLog.Int(t3,0); KernelLog.String(" ms"); KernelLog.Ln;

		KernelLog.String("Done!"); KernelLog.Ln;
	END Test;

END BSplineCurvesTest.


BSplineCurvesTest.Test ~