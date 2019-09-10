MODULE W3dMatrix;	(** AUTHOR "TF"; PURPOSE "Matrix operations for 3d (case study)"; *)

IMPORT
	Vectors := W3dVectors, MathL;

TYPE Matrix4x4* = ARRAY 4 OF ARRAY 4 OF FLOAT64;

VAR Identity4x4- : Matrix4x4;

(* BEGIN 4x4 implementation *)
PROCEDURE Translation4x4*(dx, dy, dz : FLOAT64) : Matrix4x4;
VAR result : Matrix4x4;
BEGIN
  result := Identity4x4; result[3, 0] := dx; result[3, 1] := dy; result[3, 2] := dz;
  RETURN result
END Translation4x4;

PROCEDURE Stretch4x4*(dx, dy, dz : FLOAT64) : Matrix4x4;
VAR result : Matrix4x4;
BEGIN
  result := Identity4x4; result[0, 0] := dx; result[1, 1] := dy; result[2, 2] := dz;
  RETURN result
END Stretch4x4;

PROCEDURE Rotation4x4*(u : Vectors.TVector3d; phi : FLOAT64) : Matrix4x4;
VAR result : Matrix4x4; t, c, s : FLOAT64;
BEGIN
	s := MathL.sin(phi); c := MathL.cos(phi); t := 1 - c;
	result := Identity4x4;
	result[0, 0] := t*u.x*u.x+c; 		result[1, 0] := t*u.x*u.y+s*u.z; result[2, 0] := t*u.x*u.z-s*u.y;
	result[0, 1] := t*u.x*u.y-s*u.z;	result[1, 1] := t*u.y*u.y+c; 	result[2, 1] := t*u.y*u.z+s*u.x;
	result[0, 2] := t*u.x*u.z+s*u.y;	result[1, 2] := t*u.y*u.z-s*u.x;  result[2, 2] :=t*u.z*u.z+c;
	RETURN result
END Rotation4x4;

PROCEDURE MulMat*(A, B: Matrix4x4):Matrix4x4;
VAR x, y, t: SIGNED32;
		result : Matrix4x4;
BEGIN
  FOR x := 0 TO 3 DO FOR y := 0 TO 3 DO
    result[x, y] := 0; FOR t := 0 TO 3 DO result[x, y] := result[x, y] + B[x, t]* A[t, y] END
  END END;
  RETURN result
END MulMat;

PROCEDURE Mul*(M: Matrix4x4; P : Vectors.TVector3d) : Vectors.TVector3d;
VAR result : Vectors.TVector3d;
BEGIN
	result.x :=   M[0][0]*P.x + M[1][0]*P.y + M[2][0]*P.z + M[3][0];
	result.y :=   M[0][1]*P.x + M[1][1]*P.y + M[2][1]*P.z + M[3][1];
	result.z :=   M[0][2]*P.x + M[1][2]*P.y + M[2][2]*P.z + M[3][2];
	RETURN result
END Mul;

PROCEDURE TransformDir*(M: Matrix4x4; P : Vectors.TVector3d) : Vectors.TVector3d;
VAR result : Vectors.TVector3d;
BEGIN
	result := Vectors.VNormed3(Vectors.VSub3(Mul(M, P), Mul(M, Vectors.Vector3d(0, 0, 0))));
	RETURN result
END TransformDir;

(** all input vectors have to be normalized ! *)
PROCEDURE CameraMatrix*(p:Vectors.TVector3d; lookAt, up:Vectors.TVector3d) : Matrix4x4;
VAR result : Matrix4x4;
	 hx : Vectors.TVector3d;
BEGIN
  hx := Vectors.Cross(up, lookAt);

  result := Identity4x4;

  result[0, 0] := hx.x;  result[0, 1] := up.x; result[0, 2] := lookAt.x;
  result[1, 0] := hx.y;  result[1, 1] := up.y; result[1, 2] := lookAt.y;
  result[2, 0] := hx.z;  result[2, 1] := up.z; result[2, 2] := lookAt.z;

  RETURN MulMat(result, Translation4x4(-p.x, -p.y, -p.z));
END CameraMatrix;

(** assume an object at 0,0,0 up in +y, direction in +x
	returns a matrix, repositioning the obj to p and turning in lookAt direction
	lookAt and up need to be normalized *)
PROCEDURE PositionMatrix*(p, d, u: Vectors.TVector3d) : Matrix4x4;
VAR hx : Vectors.TVector3d;
	result : Matrix4x4;
BEGIN
	hx := Vectors.Cross(d, u);
	result := Identity4x4;
	result[0, 0] := d.x;  result[1, 0] := u.x; result[2, 0] := hx.x;
	result[0, 1] := d.y;  result[1, 1] := u.y; result[2, 1] := hx.y;
	result[0, 2] := d.z;  result[1, 2] := u.z; result[2, 2] := hx.z;
	result := MulMat(Translation4x4(p.x, p.y, p.z), result);
	RETURN result
END PositionMatrix;

BEGIN
	Identity4x4[0, 0] := 1; Identity4x4[1, 1] := 1; Identity4x4[2, 2] := 1; Identity4x4[3, 3] := 1
END W3dMatrix.


