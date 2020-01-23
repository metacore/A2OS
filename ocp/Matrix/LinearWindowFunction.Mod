MODULE LinearWindowFunction; (** AUTHOR "Patrick Hunziker"; PURPOSE ""; *)

IMPORT MatrixBase, Commands, MatrixInterpolation;

TYPE Datatype*=MatrixBase.Datatype;

(* window with weights in B-spline shape *)
PROCEDURE SplineWindow*(CONST d: ARRAY [*] OF Datatype; splineDegree: SIGNED32): ARRAY [*] OF Datatype;
VAR B: ARRAY [*] OF Datatype; i:SIGNED32;
BEGIN
	CASE splineDegree OF
		1: HALT(200); (*implementation of degree 1 buggy, do not use at currrent*)
			B:=[0,1,0]; (*spline coefficient in spline domain *) (* quadratic B-spline support is -1 .. 1 *)
			FOR i:=0 TO LEN(d,0)-1 DO
				RESULT[i]:= MatrixInterpolation.InterpolateSpline(B,  i* 2/LEN(d,0), 1);
			END;
		|2: B:=[0, 0,1,0,0]; (* quadratic B-spline support is -1.5 .. 1.5 *)
			FOR i:=0 TO LEN(d,0)-1 DO
				RESULT[i]:= MatrixInterpolation.InterpolateSpline(B,  0.5 + i* 3/LEN(d,0), 2);
			END;
		|3: B:=[0,0,1,0,0]; (*cubic B-spline support is -2..2*)
			FOR i:=0 TO LEN(d,0)-1 DO
				RESULT[i]:= MatrixInterpolation.InterpolateSpline(B,  i* 4/LEN(d,0), 3);
			END;
		|4: B:=[0,0,0,1,0,0, 0]; (*quartic B-spline support is -2.5..2.5*)
			FOR i:=0 TO LEN(d,0)-1 DO
				RESULT[i]:= MatrixInterpolation.InterpolateSpline(B,  0.5 + i* 5/LEN(d,0), 4);
			END;
	END;
	RETURN RESULT
END SplineWindow;


PROCEDURE Do*(context:Commands.Context);
VAR r,b: ARRAY [*] OF Datatype; i:SIGNED32;
BEGIN

	NEW(r,5);
	b:=[0,0,0,1,0,0,0];
	FOR i:=5 TO 55 DO (*quartic B-spline support is -2.5..2.5*)
		context.out.FloatFix(10/6*MatrixInterpolation.InterpolateSpline(b, i/10, 4), 0, 5, 0); context.out.Update;  (*approximate gain*)
	END;
	context.out.Ln;
	b:=[0,0,1,0,0];
	FOR i:=0 TO 40 DO (*cubic B-spline support is -2..2*)
		context.out.FloatFix(3/2*MatrixInterpolation.InterpolateSpline(b, i/10, 3), 0, 5, 0); context.out.Update; (*gain such that peak is 1*)
	END;
	context.out.Ln;
	b:=[0,0,1,0,0];
	FOR i:=5 TO 35 DO (* quadratic B-spline support is -1.5 .. 1.5 *)
		context.out.FloatFix(4/3*MatrixInterpolation.InterpolateSpline(b, i/10, 2), 0, 5, 0); context.out.Update; (*gain such that peak is 1*)
	END;
	context.out.Ln;
	b:=[0,1,0];
	FOR i:=0 TO 20 DO (* linear B-spline support is -1 .. 1 *)
		context.out.FloatFix(MatrixInterpolation.InterpolateSpline(b, i/10, 1), 0, 5, 0); context.out.Update; (* ? is this correct- probably not, expecting linear interplation ?*)
	END;
	context.out.Ln;
	b:=[0,1,0];
	FOR i:=0 TO 20 DO (* 0 degree B-spline support is -0 .. 0 *)
		context.out.FloatFix(4/3*MatrixInterpolation.InterpolateSpline(b, i/10, 0), 0, 5, 0); context.out.Update; (* ? is this correct ?*)
	END;
	context.out.Ln;
END Do;


END LinearWindowFunction.

LinearWindowFunction.Do
