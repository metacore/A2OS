MODULE srGL;
IMPORT srBase, srMath, Math;

TYPE SREAL=srBase.SREAL;
TYPE PT = srBase.PT;
TYPE Matrix = ARRAY 3, 4 OF SREAL;	(** 4X4 homogeneous coordinates, but bottom row is always assumed to be [0, 0, 0, 1] **)

VAR identity: Matrix;

TYPE Context* = OBJECT

VAR
	Stack: ARRAY 20 OF Matrix;
	spointer: SIGNED16;
PROCEDURE & new*;
BEGIN
	Stack[0]:= identity;
	spointer := 0;
	push;
END new;

PROCEDURE push*;
BEGIN
	IF spointer < 19 THEN
		Stack[spointer+1] := Stack[spointer];
		INC(spointer);
	END;
END push;
PROCEDURE pop*;
BEGIN
	IF spointer > 1 THEN
		DEC(spointer);
	END;
END pop;

PROCEDURE transform*(VAR p: PT);
BEGIN
	Transform(Stack[spointer], p);
END transform;

PROCEDURE translatep*(VAR p: PT);
BEGIN
	Translate(Stack[spointer], p.x, p.y, p.z)
END translatep;

PROCEDURE rotatep*(VAR angle: SREAL; p: PT);
BEGIN
	Rotate(Stack[spointer], angle, p.x, p.y, p.z)
END rotatep;

PROCEDURE scalep*(VAR p:PT);
BEGIN
	Scale(Stack[spointer],p.x, p.y, p.z)
END scalep;

PROCEDURE translate*(x,y,z: SREAL);
BEGIN
	Translate(Stack[spointer],x,y,z)
END translate;

PROCEDURE rotate*(angle,x,y,z: SREAL);
BEGIN
	Rotate(Stack[spointer],angle, x,y,z)
END rotate;

PROCEDURE scale*(x,y,z: SREAL);
BEGIN
	Scale(Stack[spointer], x,y,z)
END scale;


END Context;

(** --- Matrix code which follows was taken (adapted) from Dim3Engine.Mod. --- **)
(**--- Matrix Operations ---**)

(* All routines use VAR parameters for efficiency, so beware of alias problems *)

 PROCEDURE ConcatMatrix (VAR A, B, C: Matrix);
VAR i: SIGNED16; a0, a1, a2: SREAL;
BEGIN
	FOR i := 0 TO 2 DO
		a0 := A[i, 0]; a1 := A[i, 1]; a2 := A[i, 2];
		C[i, 0] := a0*B[0, 0] + a1*B[1, 0] + a2*B[2, 0];	(* + A[i, 3]*B[3, 0] = 0 *)
		C[i, 1] := a0*B[0, 1] + a1*B[1, 1] + a2*B[2, 1];	(* + A[i, 3]*B[3, 1] = 0 *)
		C[i, 2] := a0*B[0, 2] + a1*B[1, 2] + a2*B[2, 2];	(* + A[i, 3]*B[3, 2] = 0 *)
		C[i, 3] := a0*B[0, 3] + a1*B[1, 3] + a2*B[2, 3] + A[i, 3]
	END
END ConcatMatrix;

PROCEDURE Transform (VAR M: Matrix; VAR x: PT);
VAR
	y: PT;
BEGIN
	y.x := M[0, 0]*x.x + M[0, 1]*x.y + M[0, 2]*x.z + M[0, 3];
	y.y := M[1, 0]*x.x + M[1, 1]*x.y + M[1, 2]*x.z + M[1, 3];
	y.z := M[2, 0]*x.x + M[2, 1]*x.y + M[2, 2]*x.z + M[2, 3];
	x := y;
END Transform;

PROCEDURE GetRotation (VAR M: Matrix; angle, x, y, z: SREAL);
CONST eps = 1.E-10;
VAR s, c, t: SREAL;
BEGIN
	t := Math.sqrt(x*x + y*y + z*z);
	IF t > eps THEN
		(* the following formula comes from: A. S. Glassner,  Graphic Gems, Addison-Wesley 1990, p. 466 (Rotation Tools) *)
		x := x/t; y := y/t; z := z/t;	(* normalize axis *)
		s := srMath.sin(angle); c := srMath.cos(angle); t := 1 - c;
		M[0, 0] := t*x*x + c; M[0, 1] := t*x*y - s*z; M[0, 2] := t*x*z + s*y; M[0, 3] := 0;
		M[1, 0] := t*y*x + s*z; M[1, 1] := t*y*y + c; M[1, 2] := t*y*z - s*x; M[1, 3] := 0;
		M[2, 0] := t*z*x - s*y; M[2, 1] := t*z*y + s*x; M[2, 2] := t*z*z + c; M[2, 3] := 0
	ELSE (* Halt("GetRotation", "axis is too short to be normalized") *)
	END
END GetRotation;

PROCEDURE Translate (VAR M: Matrix; dx, dy, dz: SREAL);
VAR i: SIGNED16; m0, m1, m2: SREAL;
BEGIN
	FOR i := 0 TO 2 DO
		m0 := M[i, 0]; m1 := M[i, 1]; m2 := M[i, 2];
		M[i, 3] := M[i, 3] + m0*dx + m1*dy + m2*dz
	END
END Translate;

PROCEDURE Rotate (VAR M: Matrix; angle, x, y, z: SREAL);
VAR R, Q: Matrix;
BEGIN
	GetRotation(R, angle, x, y, z);
	Q := M;
	ConcatMatrix(Q, R, M)
END Rotate;

PROCEDURE Scale (VAR M: Matrix; sx, sy, sz: SREAL);
VAR i: SIGNED16;
BEGIN
	FOR i:= 0 TO 2 DO
		M[i, 0] := sx*M[i, 0];
		M[i, 1] := sy*M[i, 1];
		M[i, 2] := sz*M[i, 2]
	END
END Scale;

(* End taken (adapted) code section *)

BEGIN
	identity[0, 0] := 1; identity[0, 1] := 0; identity[0, 2] := 0; identity[0, 3] := 0;
	identity[1, 0] := 0; identity[1, 1] := 1; identity[1, 2] := 0; identity[1, 3] := 0;
	identity[2, 0] := 0; identity[2, 1] := 0; identity[2, 2] := 1; identity[2, 3] := 0;
END srGL.