MODULE W3dVectors; (** AUTHOR "TF"; PURPOSE "Vector operations for 3d partial port from RAILY 4.0"; *)
(* 28.06.1998 *)
(* 30.06.1998 *)
(* 30.08.1998 *)
(* 15.12.1998 *)
(* 18.01.2001 Bounding Sphere *)
(* 09.06.2001 CCW *)
(* Limitations in Oberon Port :
	No overloading(Added 2 for 2d and 3 for 3d versions),
	No default values,
	No default result variable --> less efficient
	No const parameters (can not use VAR(less "functional" --> less efficient) *)
IMPORT Math := MathL;

TYPE
	 TVector2d* = RECORD x*, y*: FLOAT64 END;
     TVector3d* = RECORD x*, y*, z*: FLOAT64 END;

     TLineSegment2d* = RECORD A*, B*: TVector2d END;
     TRectangle* = RECORD A*, B*: TVector2d END;

     TBoundingSphere* = RECORD P*: TVector3d; r*:FLOAT64 END;


CONST TooSmall* = 0.00000000001;

PROCEDURE Sqr(x: FLOAT64):FLOAT64;
BEGIN
	RETURN x * x
END Sqr;

PROCEDURE Vector2d*(x:FLOAT64; y:FLOAT64):TVector2d;
VAR result : TVector2d;
BEGIN result.x := x; result.y := y; RETURN result END Vector2d;

PROCEDURE Vector3d*(x:FLOAT64; y:FLOAT64; z:FLOAT64):TVector3d;
VAR result : TVector3d;
BEGIN result.x := x; result.y := y; result.z := z; RETURN result END Vector3d;

PROCEDURE VAdd2*(a, b: TVector2d):TVector2d;
VAR result : TVector2d;
BEGIN result.x:=a.x+b.x; result.y:=a.y+b.y; RETURN result END VAdd2;

PROCEDURE VAdd3*(a, b: TVector3d):TVector3d;
VAR result : TVector3d;
BEGIN result.x:=a.x+b.x; result.y:=a.y+b.y; result.z:=a.z+b.z; RETURN result END VAdd3;

PROCEDURE VSub2*(a, b: TVector2d):TVector2d;
VAR result : TVector2d;
BEGIN result.x:=a.x-b.x; result.y:=a.y-b.y; RETURN result END VSub2;

PROCEDURE VSub3*(a, b: TVector3d):TVector3d;
VAR result : TVector3d;
BEGIN result.x:=a.x-b.x; result.y:=a.y-b.y; result.z:=a.z-b.z; RETURN result END VSub3;

PROCEDURE VNeg2*(a: TVector2d):TVector2d;
VAR result : TVector2d;
BEGIN result.x:=-a.x; result.y:=-a.y; RETURN result END VNeg2;

PROCEDURE VNeg3*(a: TVector3d):TVector3d;
VAR result : TVector3d;
BEGIN result.x:=-a.x; result.y:=-a.y; result.z:=-a.z; RETURN result END VNeg3;

PROCEDURE VLength2*(a: TVector2d):FLOAT64;
VAR t: FLOAT64;
BEGIN
	a.x := ABS(a.x); a.y:= ABS(a.y);
	IF a.x > a.y THEN t := a.x; a.x := a.y; a.y:=t END;
	IF a.x = 0 THEN RETURN a.y
	ELSE RETURN a.y * Math.sqrt(1 + Sqr(a.x/a.y))
	END
END VLength2;

PROCEDURE VLength2VV*(a, b: TVector2d):FLOAT64;
BEGIN
	RETURN VLength2(VSub2(a, b))
END VLength2VV;

PROCEDURE VLength3VV*(a, b: TVector3d):FLOAT64;
BEGIN
	RETURN VLength3(VSub3(a, b))
END VLength3VV;

PROCEDURE VLength3*(a: TVector3d):FLOAT64;
VAR t: FLOAT64;
BEGIN
	a.x := ABS(a.x); a.y:= ABS(a.y); a.z:=ABS(a.z);
	IF a.x > a.y THEN t := a.x; a.x := a.y; a.y:=t END;
	IF a.y > a.z THEN t := a.y; a.y := a.z; a.z:=t END;
	(* a.z >= a.y, a.z >= a.x *)
	IF a.z = 0 THEN RETURN 0
	ELSE RETURN a.z * Math.sqrt(1 + Sqr(a.x/a.z) + Sqr(a.y/a.z))
	END
END VLength3;

(* squared length *)
PROCEDURE VLength2Sq*(a: TVector2d):FLOAT64;
BEGIN
	RETURN Sqr(a.x) + Sqr(a.y)
END VLength2Sq;

PROCEDURE VLength2VVSq*(a, b: TVector2d):FLOAT64;
BEGIN
	RETURN VLength2Sq(VSub2(a, b))
END VLength2VVSq;

PROCEDURE VLength3VVSq*(a, b: TVector3d):FLOAT64;
BEGIN
	RETURN VLength3Sq(VSub3(a, b))
END VLength3VVSq;

PROCEDURE VLength3Sq*(a: TVector3d):FLOAT64;
BEGIN
	RETURN Sqr(a.x) + Sqr(a.y) + Sqr(a.z)
END VLength3Sq;

PROCEDURE VScaled2*(a:TVector2d; factor:FLOAT64):TVector2d;
VAR result : TVector2d;
BEGIN result.x:=factor*a.x; result.y:=factor*a.y; RETURN result END VScaled2;

PROCEDURE VScaled3*(a:TVector3d; factor:FLOAT64):TVector3d;
VAR result : TVector3d;
BEGIN result.x:=factor*a.x; result.y:=factor*a.y; result.z:=factor*a.z; RETURN result  END VScaled3;

PROCEDURE VRot90*(a: TVector2d):TVector2d;
VAR result : TVector2d;
BEGIN result.x:=a.y; result.y:=-a.x; RETURN result END VRot90;

PROCEDURE VNormed2*(a: TVector2d):TVector2d;
BEGIN
	RETURN VScaled2(a, 1/VLength2(a))
END VNormed2;

PROCEDURE VNormed3*(a: TVector3d):TVector3d;
BEGIN RETURN VScaled3(a, 1/VLength3(a)) END VNormed3;

PROCEDURE Scalar2*(a, b: TVector2d):FLOAT64;
BEGIN RETURN a.x*b.x+a.y*b.y END Scalar2;

PROCEDURE Scalar3*(a, b: TVector3d):FLOAT64;
BEGIN RETURN a.x*b.x+a.y*b.y +a.z*b.z END Scalar3;

PROCEDURE Cross*(a, b: TVector3d):TVector3d;
VAR result : TVector3d;
BEGIN result.x:=a.y*b.z-a.z*b.y; result.y:=a.z*b.x-a.x*b.z; result.z:=a.x*b.y-a.y*b.x; RETURN result END Cross;

PROCEDURE CCW*(a, b, c: TVector2d):BOOLEAN;
BEGIN RETURN (b.x-a.x) * (c.y-a.y) - (c.x-a.x) * (b.y-a.y) >= 0
END CCW;

END W3dVectors.

