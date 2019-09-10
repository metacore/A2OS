MODULE vyPHIGS3D IN Oberon;   		(*vs 0.0a1 md   08.08.95 *)
(* Copyright notice:

This file is part of Voyager
Copyright (C) 1993-2002 Project Voyager, StatLab Heidelberg ; (C) 1993-2002 G. Sawitzki et al.

This library is free software; you can redistribute it and/or
modify it under the terms of the GNU Lesser General Public
License as published by the Free Software Foundation; either
version 2.1 of the License, or (at your option) any later version.

This library is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
Lesser General Public License for more details.

You should have received a copy of the GNU Lesser General Public
License along with this library; if not, write to the Free Software
Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

Copy of the GNU Lesser General Public License can be found in the file COPYING.TXT
Report any problems as soon as possible to voyager@statlab.uni-heidelberg.de
*)


(*		(c) Project Voyager, StatLab Heidelberg
(c) M. Diller, StatLab Heidelberg
*)

(*= the mathematics for the 3d graphic
Because of its special necessities, the 3d graphic got its own linear algebra.
The model of that graphic implementation, especially the definitions of the different coordinate system, is nearly identical with that of the standard PHIGS3D graphic.
Literature: 	"A primer for PHIGS"  F.R.A. Hopgood, D.A. Duce (Wiley&Sons)
"Computer Grafik" W.D. Fellner  (B.I. Wissenschaftsverlag)
For interaction, stee also
Foley, van Dam et al., Computer Graphics, Addison Wesley 1990
M.J. Chen: Siggraph 88, 121 - 129
*)

(* IN A FINAL VERSION THIS MODULE SHOULD BE PLACED IN vyPaint3d *)

(*	history:
8.8.95 md 0.0a1	alpha version
8.6.95 md 0.0d11	cleaned (dumps and test removed)
25.4.95 md 0.0d10	definitionTime & GetDefinitionTime added
16.2.95 md 0.0d9	rename: Circle -> DisplayRotationControl
new: Proc ErrorMsg
rotation implemented
26.1.95 md 0.0d8	cleaned
5.12.94 md 0.0d4	avoid all the unnecessary NEWs
2.12.94 md 0.0d3	killed all testing routines
21.11.94 md 0.0d0	created *)

(*!	kleiner Fehler beim invertieren der MappingMatrix; teste Inversion von: B1 und B2
Zoom in and zoom out
sometimes the rotation seems to go the wrong direction
up to now there is no support of the definitionTime of a coordinate
use this to decide if a plot is still guilty or not.*)

IMPORT	vyBase, vyGraphBase, vyHostTexts,
	Math := MathL IN A2, Oberon, Files, Out,
	vyHostDisplay := vyGraphBase;

CONST
	idversion* = 	"vyPHIGS3D v0r0a2";
	(*error codes*)
	(* the range 1-32 are reserved for critical errors; they cause a Trap *)
	zeroPlaneNormal = 31;
	notYetImplemented = 32;
	zeroVectorNorm = 33;


TYPE
	(*Interface to vyBase. No other dependencies on vyBase*)
	Real = vyBase.Real;
	Coordiate = vyGraphBase.Coordinate;

	tMatrixARRAY = ARRAY 4 OF ARRAY 4 OF Real;

	tMatrix = POINTER TO tMatrixDesc;
	tMatrixDesc = RECORD
		m: tMatrixARRAY;
		inv: tMatrixARRAY
	END;

	tCoordinate3d* = POINTER TO tCoordinate3dDesc;
	tCoordinate3dDesc* = RECORD
(* definition of the View reference system (VRS)
the VRS is defined in real world coordinates (RWC)  and the axis are labeled U, V,  N*)
VRPx* , VRPy * , VRPz * : Real;
(* View reference point (VRP) - the origin of the VRS
this point should define somthing like the center (the middle) of the scene*)
Nx* , Ny* , Nz* : Real;
(* N - the z-axis of the VRS	think of the viewing direction*)
VUVx, VUVy, VUVz: Real;
(* Viewing up vector (V) - the y-axis of the VRS
this direction will be the up direction in the 2d projection of the scene (?)*)
OrientationMatrix: tMatrix;
(* represents the transformation of the RWS in the VRS *)
(* help variables for caching the transformation information*)
alpha, beta, delta: Real;
(*  *)
mtVRP, mrx, mry, mrxy, mrz, mr: tMatrix;
(*  *)
(* definition of the normal projection coordinates (NPC)
the NPC is (apart of the reference point PRP) defined in coordinates of the VRS *)
VWLu0, VWLv0, VWLu1, VWLv1: Real;
(* View window limits (VWL) - the window, you are looking through *)
PVLu0, PVLu1, PVLv0, PVLv1, PVLn0, PVLn1: Real;
(**)
ProjectionType: SIGNED16;
(* perspectiv projection = 0
parallel projection = 1 (not yet implemented) *)
PRPu, PRPv, PRPn: Real;
(* Projection reference point (PRP) in VRC *)
VPd, BPd, FPd: Real;
(* distances of the view plane (VPd) back plane (BPd) and front plane (FPd)
from the VRP *)
(* VPd should be 0! *)
MappingMatrix: tMatrix;
(* represents the transformation of the VRS in the NPS *)
(* help variables for caching the transformation information*)
mtPRP, B1, B2, B: tMatrix;
(*  *)
(* the transformation from RWS in NPS *)
View: tMatrix;
(* represents the transformation of the RWS in the NPS
simply the product: View = OrientationMatrix*MappingMatrix *)
definitionTime: SIGNED32
END;

VAR
(* schmiervariablen - avoid unnecessary NEWs *)
m1, m2, m3, m4, m5, smrx, smry, smrz, smr: tMatrix;
(* default values *)
defVRPx, defVRPy, defVRPz, defNx, defNy, defNz, defVUVx, defVUVy, defVUVz,
defVWLu0, defVWLu1, defVWLv0, defVWLv1,
defPVLu0, defPVLu1, defPVLv0, defPVLv1, defPVLn0, defPVLn1,
defPRPu, defPRPv, defPRPn, defVPd, defBPd, defFPd: Real;
defProjectionType: SIGNED16;
(* the actuall coordinate system *)
theC3D: tCoordinate3d;
(*rotation variables*)
rotate * : PROCEDURE (countinously: BOOLEAN;   x0, y0, x1, y1: Coordiate);   (*current rotation procedure*)
rotation: tMatrix;

PROCEDURE CopyMatrixArray (VAR src, dest: tMatrixARRAY);
BEGIN dest := src  END CopyMatrixArray;

PROCEDURE CopyMatrix (VAR src, dest: tMatrix);
BEGIN CopyMatrixArray(src.m, dest.m);   CopyMatrixArray(src.inv, dest.inv) END CopyMatrix;

PROCEDURE WriteMatrix (VAR R: Files.Rider;  m: tMatrix);
VAR i, j: SIGNED16;
BEGIN
IF m = NIL THEN Files.WriteInt(R, - 1);  Out.Ln;  Out.String("NIL Matrix");    RETURN ELSE Files.WriteInt(R, 4) END;  (* size *)
FOR i := 0 TO 3 DO
FOR j := 0 TO 3 DO
Files.WriteLReal(R, m.m[i, j]);  Files.WriteLReal(R, m.inv[i, j]);
END;
END;
END WriteMatrix;

PROCEDURE ReadMatrix (VAR R: Files.Rider;  VAR m: tMatrix);
VAR i, j: SIGNED16;
BEGIN
Files.ReadInt(R, i);
IF i > 0 THEN NEW(m) ELSE m := NIL;  Out.Ln;  Out.String("NIL Matrix");   RETURN END;
FOR i := 0 TO 3 DO
FOR j := 0 TO 3 DO
Files.ReadLReal(R, m.m[i, j]);  Files.ReadLReal(R, m.inv[i, j]);
END;
END;
END ReadMatrix;

PROCEDURE StoreCoord3d* (VAR R: Files.Rider;  c: tCoordinate3d);
BEGIN
IF c = NIL THEN Files.WriteInt(R, - 1);  RETURN ELSE Files.WriteInt(R, 0) END;
Files.WriteLReal(R, c.VRPx);
Files.WriteLReal(R, c.VRPy);
Files.WriteLReal(R, c.VRPz);
Files.WriteLReal(R, c.Nx);
Files.WriteLReal(R, c.Ny);
Files.WriteLReal(R, c.Nz);
Files.WriteLReal(R, c.VUVx);
Files.WriteLReal(R, c.VUVy);
Files.WriteLReal(R, c.VUVz);
WriteMatrix(R, c.OrientationMatrix);
Files.WriteLReal(R, c.alpha);
Files.WriteLReal(R, c.beta);
Files.WriteLReal(R, c.delta);
WriteMatrix(R, c.mtVRP);
WriteMatrix(R, c.mrx);
WriteMatrix(R, c.mry);
WriteMatrix(R, c.mrxy);
WriteMatrix(R, c.mrz);
WriteMatrix(R, c.mr);
Files.WriteLReal(R, c.VWLu0);
Files.WriteLReal(R, c.VWLv0);
Files.WriteLReal(R, c.VWLu1);
Files.WriteLReal(R, c.VWLv1);
Files.WriteLReal(R, c.PVLu0);
Files.WriteLReal(R, c.PVLu1);
Files.WriteLReal(R, c.PVLv0);
Files.WriteLReal(R, c.PVLv1);
Files.WriteLReal(R, c.PVLn0);
Files.WriteLReal(R, c.PVLn1);
Files.WriteInt(R, c.ProjectionType);
Files.WriteLReal(R, c.PRPu);
Files.WriteLReal(R, c.PRPv);
Files.WriteLReal(R, c.PRPn);
Files.WriteLReal(R, c.VPd);
Files.WriteLReal(R, c.BPd);
Files.WriteLReal(R, c.FPd);
WriteMatrix(R, c.MappingMatrix);
WriteMatrix(R, c.mtPRP);
WriteMatrix(R, c.B1);
WriteMatrix(R, c.B2);
WriteMatrix(R, c.B);
WriteMatrix(R, c.View);
Files.WriteLInt(R, c.definitionTime);
END StoreCoord3d;

PROCEDURE LoadCoord3d* (VAR R: Files.Rider; VAR c: tCoordinate3d);
VAR ver: SIGNED16;
BEGIN
Files.ReadInt(R, ver);  IF ver < 0 THEN c := NIL;  RETURN END;
Out.Ln;  Out.String("Loading coord 3d ");
Files.ReadLReal(R, c.VRPx);
Files.ReadLReal(R, c.VRPy);
Files.ReadLReal(R, c.VRPz);
Files.ReadLReal(R, c.Nx);
Files.ReadLReal(R, c.Ny);
Files.ReadLReal(R, c.Nz);
Files.ReadLReal(R, c.VUVx);
Files.ReadLReal(R, c.VUVy);
Files.ReadLReal(R, c.VUVz);
ReadMatrix(R, c.OrientationMatrix);
Files.ReadLReal(R, c.alpha);
Files.ReadLReal(R, c.beta);
Files.ReadLReal(R, c.delta);
ReadMatrix(R, c.mtVRP);
ReadMatrix(R, c.mrx);
ReadMatrix(R, c.mry);
ReadMatrix(R, c.mrxy);
ReadMatrix(R, c.mrz);
ReadMatrix(R, c.mr);
Files.ReadLReal(R, c.VWLu0);
Files.ReadLReal(R, c.VWLv0);
Files.ReadLReal(R, c.VWLu1);
Files.ReadLReal(R, c.VWLv1);
Files.ReadLReal(R, c.PVLu0);
Files.ReadLReal(R, c.PVLu1);
Files.ReadLReal(R, c.PVLv0);
Files.ReadLReal(R, c.PVLv1);
Files.ReadLReal(R, c.PVLn0);
Files.ReadLReal(R, c.PVLn1);
Files.ReadInt(R, c.ProjectionType);
Files.ReadLReal(R, c.PRPu);
Files.ReadLReal(R, c.PRPv);
Files.ReadLReal(R, c.PRPn);
Files.ReadLReal(R, c.VPd);
Files.ReadLReal(R, c.BPd);
Files.ReadLReal(R, c.FPd);
ReadMatrix(R, c.MappingMatrix);
ReadMatrix(R, c.mtPRP);
ReadMatrix(R, c.B1);
ReadMatrix(R, c.B2);
ReadMatrix(R, c.B);
ReadMatrix(R, c.View);
Files.ReadLInt(R, c.definitionTime);

END LoadCoord3d;



PROCEDURE CopyCoordinate* (src, dest: tCoordinate3d);
BEGIN
dest^ := src^;
NEW(dest.OrientationMatrix);   CopyMatrix(src.OrientationMatrix, dest.OrientationMatrix);
NEW(dest.mtVRP);   CopyMatrix(src.mtVRP, dest.mtVRP);
NEW(dest.mrx);   CopyMatrix(src.mrx, dest.mrx);
NEW(dest.mry);   CopyMatrix(src.mry, dest.mry);
NEW(dest.mrxy);   CopyMatrix(src.mrxy, dest.mrxy);
NEW(dest.mrz);   CopyMatrix(src.mrz, dest.mrz);
NEW(dest.mr);   CopyMatrix(src.mr, dest.mr);
NEW(dest.MappingMatrix);   CopyMatrix(src.MappingMatrix, dest.MappingMatrix);
NEW(dest.mtPRP);   CopyMatrix(src.mtPRP, dest.mtPRP);
NEW(dest.B1);   CopyMatrix(src.B1, dest.B1);
NEW(dest.B2);   CopyMatrix(src.B2, dest.B2);
NEW(dest.B);   CopyMatrix(src.B, dest.B);
NEW(dest.View);   CopyMatrix(src.View, dest.View)
END CopyCoordinate;

PROCEDURE ErrorMsg (code: SIGNED16);

PROCEDURE Msg (code: SIGNED16;   errString: ARRAY OF CHAR);
BEGIN vyHostTexts.NoteSIS (vyHostTexts.cWarning, "PHIGS3D: error ", code, errString) END Msg;

BEGIN
IF (code # 0) THEN
IF (code = 1) THEN
ELSIF (code = zeroPlaneNormal) THEN
Msg (code, "plane given by its normal:  (0 0 0)")
ELSIF (code = notYetImplemented) THEN
Msg (code, "sorry: not yet implemented")
ELSIF (code = zeroVectorNorm) THEN
Msg (code, "could not normalize zero vector")
END;
IF code < 33 THEN ASSERT (code = 0) END
END
END ErrorMsg;


(* linear algebra for the 3d Graphic *)
PROCEDURE SumOfSquare (x, y, z: Real): Real;
BEGIN RETURN x * x + y * y + z * z END SumOfSquare;

PROCEDURE Norm (x, y, z: Real): Real;
BEGIN	RETURN Math.sqrt (SumOfSquare(x, y, z))	END Norm;

PROCEDURE ScalarMultiplication (VAR x, y, z: Real;   s: Real);
BEGIN x := s * x;   y := s * y;   z := s * z	END ScalarMultiplication;

PROCEDURE NormVector (VAR x, y, z: Real);
VAR n: Real;
BEGIN n := Norm (x, y, z);
IF n > 0 THEN ScalarMultiplication (x, y, z, 1 / n)
ELSE ErrorMsg (zeroVectorNorm) END
END NormVector;

PROCEDURE ScalarProduct (x, y, z, u, v, w: Real): Real;
BEGIN	RETURN x * u + y * v + z * w	END ScalarProduct;

PROCEDURE VectorProduct (x, y, z, u, v, w: Real;   VAR nx, ny, nz: Real);
(*= returns the vectorproduct (x, y, z) x (u, v, w) *)
BEGIN	nx := y * w - z * v;   ny := z * u - x * w;   nz := x * v - y * u	END VectorProduct;
(*
PROCEDURE ProjectToPlane (x, y, z, nx, ny, nz: Real; VAR px, py, pz: Real);
(*= given a plane by its normal (nx, ny, nz) this routine returns the projection (px, py, pz)
of (x, y, z) to that plane *)
VAR f: Real; sos: Real;
BEGIN	sos := SumOfSquare (nx, ny, nz);
IF sos = 0 THEN ErrorMsg (zeroPlaneNormal) END;
f := ScalarProduct (nx, ny, nz, x, y, z)/sos;
px := x-f*nx; py := y-f*ny; pz := z-f*nz;
END ProjectToPlane;
*)
PROCEDURE Angle2 (ak, gk: Real): Real;
VAR phi: Real;
BEGIN
IF gk = 0 THEN IF ak >= 0 THEN RETURN 0 ELSE RETURN Math.pi END
ELSIF ak = 0 THEN IF gk >= 0 THEN RETURN Math.pi / 2 ELSE RETURN 3 * Math.pi / 2 END
ELSE
phi := Math.arctan (ABS(gk / ak));
IF (ak > 0) & (gk > 0) THEN RETURN phi
ELSIF (ak < 0) & (gk > 0) THEN RETURN Math.pi - phi
ELSIF (ak < 0) & (gk < 0) THEN RETURN Math.pi + phi
ELSIF (ak > 0) & (gk < 0) THEN RETURN Math.pi * 2 - phi
ELSE RETURN 0
END
END
END Angle2;

PROCEDURE Angle3 (x, y, z, u, v, w: Real): Real;
(*= returns the angle to rotate the first vector into the second
using the rotation axis rx, ry, rz, given by VectorProduct (x, y, z, u, v, w, rx, ry, rz).
Remember: each rotation follows the right hand rule! *)
(*! optimieren *)
VAR a, b, xx, xy, xz, zx, zy, zz: Real;
BEGIN IF ((x = 0) & (y = 0) & (z = 0)) OR ((u = 0) & (v = 0) & (w = 0)) THEN RETURN 0 END;
NormVector (u, v, w);
VectorProduct (x, y, z, u, v, w, zx, zy, zz);
NormVector (zx, zy, zz);
VectorProduct (u, v, w, zx, zy, zz, xx, xy, xz);
a := ScalarProduct (x, y, z, xx, xy, xz);
b := ScalarProduct (x, y, z, u, v, w);
RETURN Angle2 (b, a)
END Angle3;

PROCEDURE InitMatrix (m: tMatrix);
(*= initializes the matrix m to the unit matrix *)
VAR i, j: SIGNED16;
BEGIN
FOR i := 0 TO 3 DO
FOR j := 0 TO 3 DO	m.m[i, j] := 0;   m.inv[i, j] := 0	END;
m.m[i, i] := 1;   m.inv[i, i] := 1
END
END InitMatrix;

PROCEDURE InvertMatrix (m, inv: tMatrix);
(*= tricky as hell, isn't it? *)
BEGIN ASSERT ((m # NIL) & (inv # NIL));   inv.m := m.inv;   inv.inv := m.m	END InvertMatrix;

PROCEDURE ComposeMatrix3 (InMatrixA, InMatrixB, m: tMatrix);
(*= returns in m the product of InMatrixA and InMatrixB: m := InMatrixA*InMatrixB*)

PROCEDURE MatrixProduct (A, B : tMatrixARRAY;   VAR res: tMatrixARRAY);
VAR i, j, k: SIGNED16;   sum: Real;
BEGIN
FOR i := 0 TO 3 DO
FOR j := 0 TO 3 DO
sum := 0;
FOR k := 0 TO 3 DO sum := sum + A[i, k] * B[k, j] END;
res[i, j] := sum
END
END
END MatrixProduct;

BEGIN ASSERT ((InMatrixA # NIL) & (InMatrixA # NIL) & (m # NIL));
MatrixProduct (InMatrixA.m, InMatrixB.m, m.m);
MatrixProduct (InMatrixB.inv, InMatrixA.inv, m.inv)
END ComposeMatrix3;

PROCEDURE TransformPoint3 (x, y, z: Real;   VAR m: tMatrixARRAY;   VAR tx, ty, tz: Real);
VAR tw: Real;
BEGIN
tx := x * m[0, 0] + y * m[1, 0] + z * m[2, 0] + m[3, 0];
ty := x * m[0, 1] + y * m[1, 1] + z * m[2, 1] + m[3, 1];
tz := x * m[0, 2] + y * m[1, 2] + z * m[2, 2] + m[3, 2];
tw := x * m[0, 3] + y * m[1, 3] + z * m[2, 3] + m[3, 3];
tx := tx / tw;   ty := ty / tw;   tz := tz / tw
END TransformPoint3;

PROCEDURE Translate3 (tx, ty, tz: Real;   m: tMatrix);
BEGIN ASSERT (m # NIL);   InitMatrix (m);
m.m[3, 0] := tx;   	m.m[3, 1] := ty;   	m.m[3, 2] := tz;
m.inv[3, 0] := - tx;   m.inv[3, 1] := - ty;   m.inv[3, 2] := - tz
END Translate3;
(*
PROCEDURE Scale3 (sx, sy, sz: Real; m: tMatrix);
(** vs 0.0d0 *)	(* md  21.11.94 13:02:35 *)
BEGIN ASSERT (m#NIL); InitMatrix (m, 1);
m.m[0, 0] := sx;	m.m[1, 1] := sy;	m.m[2, 2] := sz;
m.inv[0, 0] := 1/sx;	m.inv[1, 1] := 1/sy;	m.inv[2, 2] := 1/sz;
END Scale3;
*)
PROCEDURE RotateX (px: Real;   m: tMatrix);
(*! optimieren *)
PROCEDURE rotateX (p: Real;   VAR m: tMatrixARRAY);
BEGIN
m[1, 1] := Math.cos (p);   	m[1, 2] := Math.sin (p);
m[2, 1] := - Math.sin (p);   	m[2, 2] := Math.cos (p)
END rotateX;

BEGIN ASSERT (m # NIL);   InitMatrix (m);
IF px # 0 THEN rotateX (px, m.m);   rotateX (- px, m.inv) END
END RotateX;

PROCEDURE RotateY (py: Real;   m: tMatrix);
(*! optimieren *)
PROCEDURE rotateY (p: Real;   VAR m: tMatrixARRAY);
BEGIN
m[0, 0] := Math.cos (p);   	m[0, 2] := - Math.sin (p);
m[2, 0] := Math.sin (p);   	m[2, 2] := Math.cos (p)
END rotateY;

BEGIN ASSERT (m # NIL);   InitMatrix (m);
IF py # 0 THEN rotateY (py, m.m);   rotateY (- py, m.inv) END
END RotateY;

PROCEDURE RotateZ (pz: Real;   m: tMatrix);
(*! optimieren *)
PROCEDURE rotateZ (p: Real;   VAR m: tMatrixARRAY);
BEGIN
m[0, 0] := Math.cos (p);   	m[0, 1] := Math.sin (p);
m[1, 0] := - Math.sin (p);   	m[1, 1] := Math.cos (p)
END rotateZ;

BEGIN ASSERT (m # NIL);   InitMatrix (m);
IF pz # 0 THEN rotateZ (pz, m.m);   rotateZ (- pz, m.inv) END
END RotateZ;

PROCEDURE RotateAxis (x, y, z, phi: Real;   m: tMatrix);
(*= returns the transformationmatrix, for the rotation about the axis (x, y, z) (through the origin)
with the angle phi*)
VAR alpha, beta: Real;
BEGIN ASSERT (m # NIL);
(*rotation of a (about x) in the xz-plane => a' *)
alpha := Angle2 (z, y);   	(*angle of the projection of a to the yz-plane and z*)
RotateX (alpha, smrx);
(*rotation of a' (about y) in z => a''*)
TransformPoint3 (x, y, z, smrx.m, x, y, z);
beta := - Angle2 (z, x);   		(*angle of a' and z*)
RotateY (beta, smry);
RotateZ (phi, smrz);
InvertMatrix (smrx, m1);
InvertMatrix (smry, m2);
ComposeMatrix3 (smrx, smry, m3);
ComposeMatrix3 (m3, smrz, m4);
ComposeMatrix3 (m4, m2, m5);
ComposeMatrix3 (m5, m1, m)
END RotateAxis;


(*
PROCEDURE BuildRotationMatrix3 (px, py, pz: Real; m: tMatrix);
(** vs 0.0d0 *)	(* md  21.11.94 13:51:26 *)
BEGIN ASSERT (m#NIL);
RotateX (px, smrx); RotateY (py, smry); RotateZ (pz, smrz);
ComposeMatrix3 (smry, smrz, smr);
ComposeMatrix3 (smrx, smr, m);
END BuildRotationMatrix3;

PROCEDURE BuildTransformMatrix3
 (fx, fy, fz, tx, ty, tz, px, py, pz, sx, sy, sz: Real; m: tMatrix);
(** vs 0.0d0 *)	(* md  21.11.94 13:47:07 *)
(* fx, fy, fz:	FixedPoint of the scaling and rotation
tx, ty, tz:	TranslationVector
px, py, pz:	RotationAngles
sx, sy, sz:	ScaleFactors*)
(**! returns the transformation matrix for the following operation:
translate the fix point in the origin,
scale
rotate
translate
and invert the translation of the fixed point
*)
BEGIN ASSERT (m#NIL);
Translate3 (-fx, -fy, -fz, m2);			InvertMatrix (m2, m5);
Scale3 (sx, sy, sz, m3);				ComposeMatrix3 (m2, m3, m4);
BuildRotationMatrix3 (px, py, pz, m3);	ComposeMatrix3 (m4, m3, m2);
Translate3 (tx, ty, tz, m3);			ComposeMatrix3 (m2, m3, m4);
ComposeMatrix3 (m4, m5, m);
END BuildTransformMatrix3;

PROCEDURE ComposeTransformMatrix3
 (InMatrix: tMatrix; fx, fy, fz, tx, ty, tz, px, py, pz, sx, sy, sz: Real; m: tMatrix);
(** vs 0.0d0 *)	(* md  21.11.94 14:04:27 *)
BEGIN ASSERT ((m#NIL) & (InMatrix#NIL));
BuildTransformMatrix3 (fx, fy, fz, tx, ty, tz, px, py, pz, sx, sy, sz, m1);
ComposeMatrix3 (InMatrix, m1, m)
END ComposeTransformMatrix3;
*)

PROCEDURE EvalViewOrientMatrix3
 (VRPx, VRPy, VRPz, Nx, Ny, Nz, VUVx, VUVy, VUVz: Real;   err: SIGNED16);
(*vs 0.0a1 *)	(* md  22.11.94 15:55:38 *)
(*! optimieren *)
(*= returns the matrix for the transformation from the
real world system in the view reference system.
the vectors are given in real world coordinates and have the following meaning:
VRPx, VRPy, VRPz:	Origin of the VRC-System (= ViewReferenzPoint)
normally the center of the scene to be displayed
Nx, Ny, Nz:		View plane normal (= N axis)
VUVx, VUVy, VUVz:	View up vector (= V axis)
*)
VAR alpha, beta, delta: Real;
BEGIN
(*VUV should be orthogonal to N*)
(*ProjectToPlane (VUVx, VUVy, VUVz, Nx, Ny, Nz, VUVx, VUVy, VUVz);
theC3D.VUVx := VUVx; theC3D.VUVy := VUVy; theC3D.VUVz := VUVz;*)
(**)
theC3D.VRPx := VRPx;   theC3D.VRPy := VRPy;   theC3D.VRPz := VRPz;
Translate3 (- theC3D.VRPx, - theC3D.VRPy, - theC3D.VRPz, theC3D.mtVRP);

alpha := Angle2 (Nz, Ny);   				(*angle of the projection of N to the yz-plane and z*)
theC3D.alpha := alpha;
RotateX (theC3D.alpha, theC3D.mrx);   		(*rotation of N (about x) in the xz-plane => N' *)

TransformPoint3 (Nx, Ny, Nz, theC3D.mrx.m, Nx, Ny, Nz);
beta := - Angle2 (Nz, Nx);   					(*angle of N' and z*)
theC3D.beta := beta;
RotateY (theC3D.beta, theC3D.mry);   		(*rotation of N (about y) in z => N''*)

ComposeMatrix3 (theC3D.mrx, theC3D.mry, theC3D.mrxy);

TransformPoint3 (VUVx, VUVy, VUVz, theC3D.mrxy.m, VUVx, VUVy, VUVz);

delta := Angle2 (VUVy, VUVx);   				(*angle of (the rotated) VUV and y*)
theC3D.delta := delta;
RotateZ (theC3D.delta, theC3D.mrz);   		(*rotation of VUV (about z) in y*)

ComposeMatrix3 (theC3D.mrxy, theC3D.mrz, theC3D.mr);
ComposeMatrix3 (theC3D.mtVRP, theC3D.mr, theC3D.OrientationMatrix)
END EvalViewOrientMatrix3;

PROCEDURE EvalViewMappingMatrix3
 (wlUmin, wlUmax, wlVmin, wlVmax: Real;   PVlXmin, PVlXmax, PVlYmin, PVlYmax, PVlBack, PVlFront: Real;
projection: SIGNED16;   PRPu, PRPv, PRPn: Real;   VPd, BPd, FPd: Real;   VAR err: SIGNED16);
(*vs 0.0a1 *)	(* md  22.11.94 15:56:03 *)
(*= returns the matrix for the transformation from the
view reference system in the normalized projection system
all values, apart of the projection view port limits, are given in in VRS coordinates
and have the following meaning

wlUmin, wlUmax, wlVmin, wlVmax:
defines the limits of the part of the view plane
which should be displayed
projection:			the type of projection: 0 = perspective, 1= parallel
PRPu, PRPv, PRPn:	the projection reference point
VPd, BPd, FPd:		the distance along the N-axis of the view plane
(resp. back plane, front plane) from the VRP
PVlXmin, PVlXmax, PVlYmin, PVlYmax, PVlBack, PVlFront:
the projection view port limits, this part of the unit cube,
the scene is projected on
** this parameter are given in NPC - coordinates **
err:
*)
PROCEDURE RegularPyramidTransform (B1: tMatrix);
(*vs 0.0a1 *)	(* md  24.11.94 14:57:50 *)
VAR d, Vx, Vy: Real;
BEGIN InitMatrix (B1);
d := PRPn - VPd;   Vx := wlUmax - wlUmin;   Vy := wlVmax - wlVmin;
B1.m [0, 0] := 2 * d / Vx;
B1.m[1, 1] := 2 * d / Vy;
B1.m[2, 0] := (wlUmin + wlUmax) / Vx;   B1.m[2, 1] := (wlVmin + wlVmax) / Vy;

B1.inv[0, 0] := 1 / B1.m[0, 0];
B1.inv[1, 1] := 1 / B1.m[1, 1];
B1.inv[2, 0] := - B1.m[2, 0] / B1.m[0, 0];
B1.inv[2, 1] := - B1.m[2, 1] / B1.m[1, 1]
END RegularPyramidTransform;

PROCEDURE UnitCubeTransformation (B2: tMatrix);
(*vs 0.0a1 *)	(* md  24.11.94 14:57:50 *)
VAR dmax, dmin, delta: Real;
BEGIN dmax := PRPn - BPd;   dmin := PRPn - FPd;   delta := dmax - dmin;
(*dmax := BPd; dmin := FPd; delta := dmax-dmin;*)
B2.m[0, 0] := - 1 / 2;   	B2.m[0, 1] := 0;   	B2.m[0, 2] := 0;   				B2.m[0, 3] := 0;
B2.m[1, 0] := 0;   	B2.m[1, 1] := - 1 / 2;   	B2.m[1, 2] := 0;   				B2.m[1, 3] := 0;
B2.m[2, 0] := 1 / 2;   	B2.m[2, 1] := 1 / 2;   	B2.m[2, 2] := dmax / delta;   		 B2.m[2, 3] := 1;
B2.m[3, 0] := 0;   	B2.m[3, 1] := 0;   	B2.m[3, 2] := dmax * dmin / delta;   B2.m[3, 3] := 0;

B2.inv[0, 0] := 1 / B2.m[0, 0];   B2.inv[0, 1] := 0;   B2.inv[0, 2] := 0;   B2.inv[0, 3] := 0;
B2.inv[1, 0] := 0;   B2.inv[1, 1] := 1 / B2.m[0, 0];   B2.inv[1, 2] := 0;   B2.inv[1, 3] := 0;
B2.inv[2, 0] := 0;   B2.inv[2, 1] := 0;   B2.inv[2, 2] := 0;   B2.inv[2, 3] := 1 / B2.m[3, 2];
B2.inv[3, 0] := 1;   B2.inv[3, 1] := 1;   B2.inv[3, 2] := 1;   B2.inv[3, 3] := - B2.m[2, 2] / B2.m[3, 2]
END UnitCubeTransformation;


BEGIN
IF projection = 0 THEN	(* perspective projection*)
theC3D.PRPu := PRPu;   theC3D.PRPv := PRPv;   theC3D.PRPn := PRPn;
(* Translate the origin in the projection reference point
here we assume, that PRP lay on the n-axis, so we ignore the other coordinates*)
Translate3 (0, 0, - theC3D.PRPn, theC3D.mtPRP);
(* transformation in the normalized projection system *)
RegularPyramidTransform (theC3D.B1);
UnitCubeTransformation (theC3D.B2);
ComposeMatrix3 (theC3D.B1, theC3D.B2, theC3D.B);
ComposeMatrix3 (theC3D.mtPRP, theC3D.B, theC3D.MappingMatrix)
ELSE
err := notYetImplemented;   ErrorMsg (err)
END

END EvalViewMappingMatrix3;

(*
PROCEDURE SetViewRepresentation3 (ViewOrientationMatrix, ViewMappingMatrix: tMatrix;
(*ViewClippingLimits*)
xyClipping, BackClippingIndicator, FrontClippingIndicator: BOOLEAN);
(** vs 0.0d0 *)	(* md  22.11.94 15:51:24 *)
VAR
BEGIN

END SetViewRepresentation3;
*)
PROCEDURE GetViewDirection* (VAR Nx, Ny, Nz: Real);
BEGIN Nx := theC3D.Nx + theC3D.VRPx;   Ny := theC3D.Ny + theC3D.VRPy;    Nz := theC3D.Nz + theC3D.VRPz
END GetViewDirection;

(* 3d managment features *)
(* coordinate control *)
PROCEDURE SetCoordinate* (c: tCoordinate3d);
BEGIN	theC3D := c END SetCoordinate;

PROCEDURE SetViewRefSystem (VRPx, VRPy, VRPz, Nx, Ny, Nz, VUVx, VUVy, VUVz: Real;   err: SIGNED16);
BEGIN
theC3D.VRPx := VRPx;   	theC3D.VRPy := VRPy;   	theC3D.VRPz := VRPz;
theC3D.Nx := Nx;   	theC3D.Ny := Ny;   	theC3D.Nz := Nz;
theC3D.VUVx := VUVx;   	theC3D.VUVy := VUVy;   	theC3D.VUVz := VUVz;
EvalViewOrientMatrix3 (
theC3D.VRPx, theC3D.VRPy, theC3D.VRPz,
theC3D.Nx, theC3D.Ny, theC3D.Nz,
theC3D.VUVx, theC3D.VUVy, theC3D.VUVz,
err)
END SetViewRefSystem;

PROCEDURE SetNormProjSystem (VWLu0, VWLu1, VWLv0, VWLv1,
PVLu0, PVLu1, PVLv0, PVLv1, PVLBack, PVLFront: Real;
projection: SIGNED16;   PRPu, PRPv, PRPn, VPd, BPd, FPd: Real;   VAR err: SIGNED16);
BEGIN
theC3D.VWLu0 := VWLu0;   	theC3D.VWLu1 := VWLu1;
theC3D.VWLv0 := VWLv0;   	theC3D.VWLv1 := VWLv1;
theC3D.PVLu0 := PVLu0;   	theC3D.PVLu1 := PVLu1;
theC3D.PVLv0 := PVLv0;   	theC3D.PVLv1 := PVLv1;
theC3D.PVLn0 := PVLBack;   	theC3D.PVLn1 := PVLFront;
theC3D.ProjectionType := projection;
theC3D.PRPu := PRPu;   	theC3D.PRPv := PRPv;
theC3D.PRPn := PRPn;
theC3D.VPd := VPd;   	theC3D.BPd := BPd;   	theC3D.FPd := FPd;
EvalViewMappingMatrix3  (
theC3D.VWLu0, theC3D.VWLu1, theC3D.VWLv0, theC3D.VWLv1,
theC3D.PVLu0, theC3D.PVLu1, theC3D.PVLv0, theC3D.PVLv1, theC3D.PVLn0, theC3D.PVLn1,
theC3D.ProjectionType,
theC3D.PRPu, theC3D.PRPv, theC3D.PRPn,
theC3D.VPd, theC3D.BPd, theC3D.FPd,
err)
END SetNormProjSystem;

PROCEDURE SetViewMatrix;
BEGIN ComposeMatrix3 (theC3D.OrientationMatrix, theC3D.MappingMatrix, theC3D.View);
theC3D.definitionTime := Oberon.Time ()
END SetViewMatrix;

PROCEDURE OpenCoordinate* (c: tCoordinate3d;   VAR err: SIGNED16);
PROCEDURE OpenMatrices;
BEGIN
NEW (theC3D.OrientationMatrix);
ASSERT (theC3D.OrientationMatrix # NIL);   InitMatrix (theC3D.OrientationMatrix);
NEW (theC3D.mtVRP);   	ASSERT (theC3D.mtVRP # NIL);     InitMatrix (theC3D.mtVRP);
NEW (theC3D.mrx);   	ASSERT (theC3D.mrx # NIL);   	InitMatrix (theC3D.mrx);
NEW (theC3D.mry);   	ASSERT (theC3D.mry # NIL);   	InitMatrix (theC3D.mry);
NEW (theC3D.mrxy);   	ASSERT (theC3D.mrxy # NIL);   	InitMatrix (theC3D.mrxy);
NEW (theC3D.mrz);   	ASSERT (theC3D.mrz # NIL);   	InitMatrix (theC3D.mrz);
NEW (theC3D.mr);   		ASSERT (theC3D.mr # NIL);   	InitMatrix (theC3D.mr);
NEW (theC3D.MappingMatrix);
ASSERT (theC3D.MappingMatrix # NIL);   InitMatrix (theC3D.MappingMatrix);
NEW (theC3D.mtPRP);   	ASSERT (theC3D.mtPRP # NIL);     InitMatrix (theC3D.mtPRP);
NEW (theC3D.B1);   		ASSERT (theC3D.B1 # NIL);   	InitMatrix (theC3D.B1);
NEW (theC3D.B2);   		ASSERT (theC3D.B2 # NIL);   	InitMatrix (theC3D.B2);
NEW (theC3D.B);   		ASSERT (theC3D.B # NIL);   	InitMatrix (theC3D.B);
NEW (theC3D.View);   	ASSERT (theC3D.View # NIL);   	InitMatrix (theC3D.View)
END OpenMatrices;

BEGIN
SetCoordinate (c);
OpenMatrices;
SetViewRefSystem (defVRPx, defVRPy, defVRPz, 					(*VPR*)
defNx, defNy, defNz, 						(*N*)
defVUVx, defVUVy, defVUVz, 					(*VUV*)
err);
SetNormProjSystem  (	defVWLu0, defVWLu1, defVWLv0, defVWLv1, 	(*VWL*)
defPVLu0, defPVLu1, defPVLv0, defPVLv1, defPVLn0, defPVLn1, 	(*PVL*)
defProjectionType, 							(*proj.type*)
defPRPu, defPRPv, defPRPn, 					(*PRP*)
defVPd, defBPd, defFPd, 						(*VPd, BPd, FPd*)
err);
SetViewMatrix
END OpenCoordinate;




(* transformations *)
PROCEDURE PointToDisplayPoint* (x3d, y3d, z3d: Real;   err: SIGNED16;   VAR x, y: Coordiate);
VAR vx, vy, vz: Real;
BEGIN TransformPoint3 (x3d, y3d, z3d, theC3D.View.m, vx, vy, vz);
vyGraphBase.Point2dToPoint (vx, vy, x, y)
END PointToDisplayPoint;

PROCEDURE PointToViewPoint* (x3d, y3d, z3d: Real;   err: SIGNED16;   VAR vx, vy, vz: Real);
BEGIN TransformPoint3 (x3d, y3d, z3d, theC3D.View.m, vx, vy, vz) END PointToViewPoint;

PROCEDURE ViewPointToDisplayPoint* (vx, vy, vz: Real;   err: SIGNED16;   VAR x, y: Coordiate);
BEGIN vyGraphBase.Point2dToPoint (vx, vy, x, y) END ViewPointToDisplayPoint;

PROCEDURE DisplayPointToPoint* (x, y: Coordiate;   err: SIGNED16;   VAR x3d, y3d, z3d: Real);
VAR vx, vy, vz: Real;
BEGIN PointToViewPoint (theC3D.VRPx, theC3D.VRPy, theC3D.VRPz, err, vx, vy, vz);
vyGraphBase.PointToPoint2d (x, y, vx, vy);
TransformPoint3 (vx, vy, vz, theC3D.View.inv, x3d, y3d, z3d)
END DisplayPointToPoint;

PROCEDURE SetViewDirection* (Nx, Ny, Nz: Real);
VAR error: SIGNED16;
BEGIN
theC3D.Nx := - Nx;   theC3D.Ny := - Ny;   theC3D.Nz := - Nz;
EvalViewOrientMatrix3 (
theC3D.VRPx, theC3D.VRPy, theC3D.VRPz,
theC3D.Nx, theC3D.Ny, theC3D.Nz,
theC3D.VUVx, theC3D.VUVy, theC3D.VUVz,
error);
SetViewMatrix
END SetViewDirection;


PROCEDURE RotateFree (countinously: BOOLEAN;   x0, y0, x1, y1: Coordiate);
(*vs 0.0a1 *)	(* md  29.11.94 10:47:31 *)
VAR error: SIGNED16;   p0x, p0y, p0z, p1x, p1y, p1z, rx, ry, rz, alpha: Real;

PROCEDURE Pix2Sphere (x, y: Coordiate;   VAR sx, sy, sz: Real);
(** vs 0.0d0 *)	(* md  19.12.94 11:04:00 *)
VAR d: Real;
BEGIN
vyGraphBase.PointToPoint2d (x, y, sx, sy);
d := (sx - 1 / 2) * (sx - 1 / 2) + (sy - 1 / 2) * (sy - 1 / 2);
IF (d > 1 / 4) THEN
d := 2 * Math.sqrt (d);   sx := (sx - 1 / 2) / d + 1 / 2;
sy := (sy - 1 / 2) / d + 1 / 2 (*was: sy := (sx - 1 / 2) / d + 1 / 2 fix for HALT(40)?? *)
END;
d := 1 / 2 - Math.sqrt (1 / 4 - (sx - 1 / 2) * (sx - 1 / 2) - (sy - 1 / 2) * (sy - 1 / 2));   (*! HALT(40) occuring from Math.sqrt *)
TransformPoint3 (sx, sy, d, theC3D.View.inv, sx, sy, sz);
sx := sx - theC3D.VRPx;   sy := sy - theC3D.VRPy;   sz := sz - theC3D.VRPz
END Pix2Sphere;

BEGIN
IF ~ countinously THEN
(*berechne den Rotationswinkel alpha durch:*)
(*1.) transformiere screen pixel (x0, y0) und (x1, y1) in Punkte p0, p1 auf der Sphere um VRP*)
Pix2Sphere (x0, y0, p0x, p0y, p0z);
Pix2Sphere (x1, y1, p1x, p1y, p1z);
(*2.) berechne den Winkel alpha zwischen p0 und p1*)
alpha := Angle3 (p0x, p0y, p0z, p1x, p1y, p1z);

(*DumpVector ("  Sphere: ", p0x, p0y, p0z); vyHostTexts.Msg ("");
DumpVector ("  Sphere: ", p1x, p1y, p1z); vyHostTexts.Msg ("");
Texts.WriteRealFix (vyHostTexts.w, alpha*180/Math.pi, 5, 3); vyHostTexts.Msg ("");
vyHostTexts.Msg ("___________________________"); *)
(*berechne die Rotationsachse durch:*)
(*1.) transformiere screen pixel (x0, y0) und (x1, y1) in Punkte v0, v1 auf der View ebene*)
(*DisplayPointToPoint (x0, y0, error, p0x, p0y, p0z);
DisplayPointToPoint (x1, y1, error, p1x, p1y, p1z);
(*2.) berechne die orthogonale n zu v1-v0 durch 0 als rotationsachse*)
VectorProduct (p1x-p0x, p1y-p0y, p1z-p0z, theC3D.Nx, theC3D.Ny, theC3D.Nz, rx, ry, rz);*)
VectorProduct (p0x, p0y, p0z, p1x, p1y, p1z, rx, ry, rz);
(*berechne die Transformationsmatrix m: rotation um g mit dem Winkel alpha*)
RotateAxis (rx, ry, rz, - alpha, rotation)

END;
(*Transformiere theC3D.N und theC3D.VUV via m*)
TransformPoint3 (theC3D.Nx, theC3D.Ny, theC3D.Nz, rotation.m,
theC3D.Nx, theC3D.Ny, theC3D.Nz);
TransformPoint3 (theC3D.VUVx, theC3D.VUVy, theC3D.VUVz, rotation.m,
theC3D.VUVx, theC3D.VUVy, theC3D.VUVz);
(*berechne neue Orientationmatrix*)
EvalViewOrientMatrix3 (	theC3D.VRPx, theC3D.VRPy, theC3D.VRPz,
theC3D.Nx, theC3D.Ny, theC3D.Nz,
theC3D.VUVx, theC3D.VUVy, theC3D.VUVz,
error);
(*berechne neue Viewmatrix*)
SetViewMatrix
END RotateFree;

PROCEDURE RotateN (countinously: BOOLEAN;   x0, y0, x1, y1: Coordiate);
(*vs 0.0a1 *)	(* md  29.11.94 10:47:31 *)
VAR error: SIGNED16;   p0x, p0y, p0z, p1x, p1y, p1z, rx, ry, rz, alpha: Real;

PROCEDURE Pix2ViewPlane (x, y: Coordiate;   VAR sx, sy, sz: Real);
(** vs 0.0d0 *)	(* md  19.12.94 11:04:00 *)
VAR err: SIGNED16;
BEGIN DisplayPointToPoint (x, y, err, sx, sy, sz);
sx := sx - theC3D.VRPx;   sy := sy - theC3D.VRPy;   sz := sz - theC3D.VRPz
END Pix2ViewPlane;

BEGIN
IF ~ countinously THEN
(*berechne den Rotationswinkel alpha durch:*)
(*1.) transformiere screen pixel (x0, y0) und (x1, y1) in Punkte p0, p1 auf der View Ebene*)
Pix2ViewPlane (x0, y0, p0x, p0y, p0z);
Pix2ViewPlane (x1, y1, p1x, p1y, p1z);
(*2.) berechne den Winkel alpha zwischen p0 und p1*)
alpha := Angle3 (p0x, p0y, p0z, p1x, p1y, p1z);
(*DumpVector ("  1.: ", p0x, p0y, p0z); vyHostTexts.Msg ("");
DumpVector ("  2.: ", p1x, p1y, p1z); vyHostTexts.Msg ("");
vyHostTexts.MsgSR ("alpha", alpha*180/Math.pi);*)
(*berechne die Transformationsmatrix m: rotation um N mit dem Winkel alpha*)
VectorProduct (p0x, p0y, p0z, p1x, p1y, p1z, rx, ry, rz);
(*RotateAxis (theC3D.Nx, theC3D.Ny, theC3D.Nz, -alpha, rotation);*)
RotateAxis (rx, ry, rz, - alpha, rotation)
END;
(*Transformiere theC3D.N und theC3D.VUV via m*)
(*TransformPoint3 (theC3D.Nx, theC3D.Ny, theC3D.Nz, rotation.m,
theC3D.Nx, theC3D.Ny, theC3D.Nz);*)
TransformPoint3 (theC3D.VUVx, theC3D.VUVy, theC3D.VUVz, rotation.m,
theC3D.VUVx, theC3D.VUVy, theC3D.VUVz);
(*berechne neue Orientationmatrix*)
EvalViewOrientMatrix3 (	theC3D.VRPx, theC3D.VRPy, theC3D.VRPz,
theC3D.Nx, theC3D.Ny, theC3D.Nz,
theC3D.VUVx, theC3D.VUVy, theC3D.VUVz,
error);
(*berechne neue Viewmatrix*)
SetViewMatrix
END RotateN;

PROCEDURE DisplayRotationControl;
(*vs 0.0a1 *)	(* md  14.12.94 16:22:07 *)
CONST ticks = 36;   VAR i: SIGNED16;
BEGIN
vyHostDisplay.SetForeColor (1);   vyHostDisplay.SetDisplayMode (2);   (* 2 = Display.invert *)
vyGraphBase.MoveTo2d (1, 1 / 2);
FOR i := 0 TO ticks DO
vyGraphBase.LineTo2d (	1 / 2 + 1 / 2 * Math.cos (i * Math.pi * 2 / ticks),
1 / 2 + 1 / 2 * Math.sin (i * Math.pi * 2 / ticks))
END
END DisplayRotationControl;

PROCEDURE SetRotationControl* (x, y: Coordiate);
(*vs 0.0a1 *)	(* md  20.12.94 16:08:05 *)
VAR X, Y: Real;
BEGIN DisplayRotationControl;
vyGraphBase.PointToPoint2d (x, y, X, Y);
IF ((X - 1 / 2) * (X - 1 / 2) + (Y - 1 / 2) * (Y - 1 / 2) > 1 / 4) THEN rotate := RotateN ELSE rotate := RotateFree END
END SetRotationControl;

PROCEDURE UpdateCoordinateSystem;
VAR err: SIGNED16;
BEGIN
SetViewRefSystem (		theC3D.VRPx, theC3D.VRPy, theC3D.VRPz, 			(*VPR*)
theC3D.Nx, theC3D.Ny, theC3D.Nz, 				(*N*)
theC3D.VUVx, theC3D.VUVy, theC3D.VUVz, 			(*VUV*)
err);
SetNormProjSystem  (
theC3D.VWLu0, theC3D.VWLu1, theC3D.VWLv0, theC3D.VWLv1, 			(*VWL*)
theC3D.PVLu0, theC3D.PVLu1, theC3D.PVLv0, theC3D.PVLv1, theC3D.PVLn0, theC3D.PVLn1, 	(*PVL*)
theC3D.ProjectionType, 												(*proj.type*)
theC3D.PRPu, theC3D.PRPv, theC3D.PRPn, 								(*PRP*)
theC3D.VPd, theC3D.BPd, theC3D.FPd, 									(*VPd, BPd, FPd*)
err);
SetViewMatrix
END UpdateCoordinateSystem;

(*______________________________________________
______________________________________________*)
PROCEDURE SetVRP* (VRPx, VRPy, VRPz: Real);
BEGIN
theC3D.VRPx := VRPx;   theC3D.VRPy := VRPy;   theC3D.VRPz := VRPz;
UpdateCoordinateSystem
END SetVRP;

PROCEDURE SetPRP* (PRPu, PRPv, PRPn: Real);
BEGIN
theC3D.PRPu := PRPu;   theC3D.PRPv := PRPv;   theC3D.PRPn := PRPn;
UpdateCoordinateSystem
END SetPRP;

PROCEDURE ResizeVWL* (uFactor, vFactor: Real);
VAR du, dv: Real;
BEGIN
IF (theC3D.VWLu1 - theC3D.VWLu0 > 0.05) & (theC3D.VWLv1 - theC3D.VWLv0 > 0.05) THEN
du := (theC3D.VWLu1 - theC3D.VWLu0) * uFactor;
dv := (theC3D.VWLv1 - theC3D.VWLv0) * vFactor;
theC3D.VWLu0 :=  theC3D.VWLu0 - du;   theC3D.VWLv0 := theC3D.VWLv0 - dv;
theC3D.VWLu1 :=  theC3D.VWLu1 + du;   theC3D.VWLv1 := theC3D.VWLv1 + dv;
UpdateCoordinateSystem
END
END ResizeVWL;

PROCEDURE LookAtScenery* (x, y, z, w, d, h: Real);
VAR diagonal: Real;
BEGIN
theC3D.VRPx := x + w / 2;   theC3D.VRPy := y + d / 2;   theC3D.VRPz := z + h / 2;
(*
vyHostTexts.MsgSRSR ("theC3D.VRPx = ", theC3D.VRPx, "theC3D.VRPz = ", theC3D.VRPz);
*)
diagonal := Math.sqrt (w * w + d * d + h * h);
(*
vyHostTexts.MsgSR ("diagonal = ", diagonal);
*)
IF diagonal = 0 THEN diagonal := 1 END;
theC3D.VWLu0 :=  - diagonal / 2;
theC3D.VWLu1 :=  diagonal / 2;
theC3D.VWLv0 :=  - diagonal / 2;
theC3D.VWLv1 :=  diagonal / 2;
UpdateCoordinateSystem
END LookAtScenery;



PROCEDURE InitGlobals;
BEGIN
NEW (m1);   NEW (m2);   NEW (m3);   NEW (m4);   NEW (m5);
NEW (smrx);   NEW (smry);   NEW (smrz);   NEW (smr);   NEW (rotation);
ASSERT 	((m1 # NIL) &
(m2 # NIL) &
(m3 # NIL) &
(m4 # NIL) &
(m5 # NIL) &
(smrx # NIL) &
(smry # NIL) &
(smrz # NIL) &
(smr # NIL) &
(rotation # NIL));
InitMatrix (rotation)
END InitGlobals;

PROCEDURE InitDefaults;
BEGIN
(*defaults for the View Reference System *)
defVRPx  := 0;
defVRPy := 0;
defVRPz := 0;
(* just for testing hidden lines *)

defVRPx  := 0.5;
defVRPy := 0.5;
defVRPz := 0.5;


defNx := 1.5;
defNy := - 2.9;
defNz := 9.7;

(*
(* fof *)
defNx := 0;
defNy :=  0.1;
defNz := 0;
(* fof *)
*)

defVUVx := - 3.4;   	(* VUV had to be orthogonal to N !!! *)
defVUVy := 10;
defVUVz := 3.5;

(*
(* fof *)
defVUVx := 0;
defVUVy := 0 ;
defVUVz :=  -0.1;
(* fof *)
*)

(*defaults for the Normal Projection System *)
defVWLu0 := - 2;
defVWLu1 := 2;
defVWLv0 := - 2;
defVWLv1 := 2;
(* just for testing hidden lines *)

defVWLu0 := - 0.76;
defVWLu1 := 0.76;
defVWLv0 := - 0.67;
defVWLv1 := 0.67;

defPVLu0 := 0;
defPVLu1 := 1;
defPVLv0 := 0;
defPVLv1 := 1;
defPVLn0 := 0;
defPVLn1 := 1;
defPRPu := 0;
defPRPv := 0;
defPRPn := 100;   (* fof, orig = 10 *)
defVPd := 0;
defBPd := - 1;
defFPd := 2;
defProjectionType := 0;

rotate := RotateN
END InitDefaults;

PROCEDURE InitCoordinate;
VAR error: SIGNED16;
BEGIN NEW (theC3D);   OpenCoordinate (theC3D, error) END InitCoordinate;

PROCEDURE UpToDate* (date: SIGNED32): BOOLEAN;
BEGIN RETURN (date > theC3D.definitionTime) END UpToDate;

PROCEDURE DumpSpec*;
(** vs 0.0d0 *)	(* md  28.08.95 21:06:35 *)
(*
VAR
BEGIN
vyHostTexts.MsgSR ("theC3D.Nx =", theC3D.Nx);
vyHostTexts.MsgSR ("theC3D.Ny =", theC3D.Ny);
vyHostTexts.MsgSR ("theC3D.Nz =", theC3D.Nz);
vyHostTexts.MsgSR ("theC3D.VUVx =", theC3D.VUVx);
vyHostTexts.MsgSR ("theC3D.VUVy =", theC3D.VUVy);
vyHostTexts.MsgSR ("theC3D.VUVz =", theC3D.VUVz);
*)
END DumpSpec;



BEGIN
InitGlobals;
InitDefaults;
InitCoordinate;
END vyPHIGS3D.

(*---------- testing ---------*)

PROCEDURE DumpReal (x: Real);
BEGIN Texts.WriteRealFix (vyHostTexts.w, x, 4, 2);   Texts.WriteString (vyHostTexts.w, "  ")
END DumpReal;

PROCEDURE DumpVRP*;
BEGIN Texts.WriteString (vyHostTexts.w, "vyPort3d.SetVRP ");
DumpReal (theC3D.VRPx);   DumpReal (theC3D.VRPy);   DumpReal (theC3D.VRPz);   vyHostTexts.Msg ("")
END DumpVRP;

PROCEDURE DumpPRP*;
BEGIN Texts.WriteString (vyHostTexts.w, "vyPort3d.SetPRP ");
DumpReal (theC3D.PRPu);   DumpReal (theC3D.PRPv);   DumpReal (theC3D.PRPn);   vyHostTexts.Msg ("")
END DumpPRP;

PROCEDURE DumpVWL*;
BEGIN Texts.WriteString (vyHostTexts.w, "vyPort3d.SetVWL ");
DumpReal (theC3D.VWLu0);   DumpReal (theC3D.VWLv0);
DumpReal (theC3D.VWLu1);   DumpReal (theC3D.VWLv1);
vyHostTexts.Msg ("")
END DumpVWL;

PROCEDURE DumpVector (com: ARRAY OF CHAR;   x, y, z: Real);
(** vs 0.0d0 *)	(* md7  30.11.94 14:48:04 *)
CONST n = 2;   k = 3;
BEGIN
Texts.WriteString (vyHostTexts.w, com);
Texts.WriteString (vyHostTexts.w, "(");
Texts.WriteRealFix (vyHostTexts.w, x, n, k);
Texts.WriteString (vyHostTexts.w, ", ");
Texts.WriteRealFix (vyHostTexts.w, y, n, k);
Texts.WriteString (vyHostTexts.w, ", ");
Texts.WriteRealFix (vyHostTexts.w, z, n, k);
Texts.WriteString (vyHostTexts.w, ")");
Texts.WriteString (vyHostTexts.w, "   ")
END DumpVector;

PROCEDURE InversionTest (com: ARRAY OF CHAR;   m: tMatrix);
(** vs 0.0d0 *)	(* md  07.12.94 09:58:14 *)
VAR res: tMatrix;
PROCEDURE MatrixProduct (A, B : tMatrixARRAY;   VAR res: tMatrixARRAY);
(** vs 0.0d0 *)	(* md  21.11.94 13:40:41 *)
(* returns in res the product of A and B: res := A*B*)
VAR i, j, k: SIGNED16;   sum: Real;
BEGIN
FOR i := 0 TO 3 DO
FOR j := 0 TO 3 DO
sum := 0;
FOR k := 0 TO 3 DO sum := sum + A[i, k] * B[k, j] END;
res[i, j] := sum
END
END
END MatrixProduct;

BEGIN
NEW (res);
MatrixProduct (m.m, m.inv, res.m);
DumpMatrix ("m", m.m);
DumpMatrix ("inv(m)", m.inv);
DumpMatrix (com, res.m)
END InversionTest;

PROCEDURE DumpMatrix (com: ARRAY OF CHAR;   m: tMatrixARRAY);
(** vs 0.0d0 *)	(* md  24.11.94 13:03:39 *)
CONST n = 3;   k = 9;
VAR i, j: SIGNED16;
BEGIN
Texts.WriteString (vyHostTexts.w, com);   Texts.WriteLn (vyHostTexts.w);
FOR i := 0 TO 3 DO
Texts.WriteInt (vyHostTexts.w, i + 1, 1);   Texts.WriteString (vyHostTexts.w, ".)   ");
FOR j := 0 TO 3 DO
Texts.WriteRealFix (vyHostTexts.w, m[i, j], n, k);   Texts.WriteString (vyHostTexts.w, "          ")
END;
Texts.WriteLn (vyHostTexts.w)
END;
Texts.WriteLn (vyHostTexts.w)
END DumpMatrix;



PROCEDURE DumpVRPTranslation*;
(** vs 0.0d0 *)	(* md  08.12.94 12:54:09 *)
BEGIN InversionTest ("VRP translation matrix", theC3D.mtVRP);   vyHostTexts.Msg ("")
END DumpVRPTranslation;

PROCEDURE DumpAngle*;
(** vs 0.0d0 *)	(* md  08.12.94 12:58:24 *)
BEGIN DumpVector ("rotation angles: alpa, beta, delta: ",
theC3D.alpha * 180 / Math.pi, theC3D.beta * 180 / Math.pi, theC3D.delta * 180 / Math.pi);
vyHostTexts.Msg ("")
END DumpAngle;


PROCEDURE DumpRotateX*;
(** vs 0.0d0 *)	(* md  08.12.94 12:54:09 *)
BEGIN InversionTest ("X-rotation matrix", theC3D.mrx);   vyHostTexts.Msg ("")
END DumpRotateX;

PROCEDURE DumpRotateY*;
(** vs 0.0d0 *)	(* md  08.12.94 12:54:09 *)
BEGIN InversionTest ("Y-rotation matrix", theC3D.mry);   vyHostTexts.Msg ("")
END DumpRotateY;

PROCEDURE DumpRotateXY*;
(** vs 0.0d0 *)	(* md  08.12.94 12:54:09 *)
BEGIN InversionTest ("XY-rotation matrix", theC3D.mrxy);   vyHostTexts.Msg ("")
END DumpRotateXY;

PROCEDURE DumpRotateZ*;
(** vs 0.0d0 *)	(* md  08.12.94 12:54:09 *)
BEGIN InversionTest ("Z-rotation matrix", theC3D.mrz);   vyHostTexts.Msg ("")
END DumpRotateZ;

PROCEDURE DumpRotate*;
(** vs 0.0d0 *)	(* md  08.12.94 12:54:09 *)
BEGIN InversionTest ("rotation matrix", theC3D.mr);   vyHostTexts.Msg ("")
END DumpRotate;

PROCEDURE DumpOrient*;
(** vs 0.0d0 *)	(* md  08.12.94 12:54:09 *)
BEGIN InversionTest ("view orientation", theC3D.OrientationMatrix);   vyHostTexts.Msg ("")
END DumpOrient;


PROCEDURE DumpPRPTranslation*;
(** vs 0.0d0 *)	(* md  08.12.94 12:54:09 *)
BEGIN InversionTest ("PRP Translatin matrix", theC3D.mtPRP);   vyHostTexts.Msg ("")
END DumpPRPTranslation;

PROCEDURE DumpB1*;
(** vs 0.0d0 *)	(* md  08.12.94 12:54:09 *)
BEGIN InversionTest ("B1: regular pyramid matrix", theC3D.B1);   vyHostTexts.Msg ("")
END DumpB1;

PROCEDURE DumpB2*;
(** vs 0.0d0 *)	(* md  08.12.94 12:54:09 *)
BEGIN InversionTest ("B2: unitsquare", theC3D.B2);   vyHostTexts.Msg ("")
END DumpB2;

PROCEDURE DumpB*;
(** vs 0.0d0 *)	(* md  08.12.94 12:54:09 *)
BEGIN InversionTest ("B: ", theC3D.B);    vyHostTexts.Msg ("")
END DumpB;

PROCEDURE DumpMap*;
(** vs 0.0d0 *)	(* md  08.12.94 12:54:09 *)
BEGIN InversionTest ("mapping matrix ", theC3D.MappingMatrix);   vyHostTexts.Msg ("")
END DumpMap;


PROCEDURE DumpView*;
(** vs 0.0d0 *)	(* md  08.12.94 12:54:09 *)
BEGIN InversionTest ("viewing matrix ", theC3D.View);   vyHostTexts.Msg ("")
END DumpView;


PROCEDURE Test1*;
(** vs 0.0d0 *)	(* md  05.12.94 16:33:21 *)
BEGIN
(*InversionTest ("orientation matrix inversion test: orient*inv(orient) = ", theC3D.B1); vyHostTexts.Msg ("");
InversionTest ("B1 inversion test: B1*inv(B1) = ", theC3D.B1); vyHostTexts.Msg ("");
InversionTest ("B2 inversion test: B2*inv(B2) = ", theC3D.B2); vyHostTexts.Msg ("");*)
InversionTest ("mapping matrix inversion test: mapping*inv(mapping) = ", theC3D.MappingMatrix);
vyHostTexts.Msg ("");
InversionTest ("view matrix inversion test: view*inv(view) = ", theC3D.View);   vyHostTexts.Msg ("")
END Test1;

PROCEDURE Test2;
(** vs 0.0d0 *)	(* md  19.12.94 11:35:39 *)
CONST ticks = 12;
VAR x, y, z, alpha: Real;   i: SIGNED16;
BEGIN x := 1;   y := 0;   z := 1;
RotateZ (Math.pi * 2 / ticks, smr);
FOR i := 0 TO ticks DO
alpha := Angle3 (x, y, z, 5, 0, 0);
DumpVector ("x: ", 5, 0, 0);   DumpVector (" y: ", x, y, z);
Texts.WriteRealFix (vyHostTexts.w, alpha * 180 / Math.pi, 5, 3);
vyHostTexts.Msg ("");
TransformPoint3 (x, y, z, smr.m, x, y, z)
END
END Test2;

PROCEDURE Test3*;
(** vs 0.0d0 *)	(*   26.01.95 09:06:47 *)
VAR i: SIGNED16;   X, Y, Z: Real;
PROCEDURE ListCoordinates (x, y, z: Real);
(** vs 0.0d0 *)	(*   31.01.95 13:19:25 *)
VAR  xi, yi, err: SIGNED16;   vx, vy, vz: Real;
BEGIN
DumpVector ("RWS: ", x, y, z);   vyHostTexts.Msg ("");

TransformPoint3 (x, y, z, theC3D.OrientationMatrix.m, x, y, z);
DumpVector ("VRS: ", x, y, z);   vyHostTexts.Msg ("");

TransformPoint3 (x, y, z, theC3D.MappingMatrix.m, x, y, z);
DumpVector ("NPS: ", x, y, z);   vyHostTexts.Msg ("");

vyGraphBase.Point2dToPoint (x, y, xi, yi);
DumpVector ("dis: ", xi, yi, 0);   vyHostTexts.Msg ("");

(*_______________________*)

vyGraphBase.PointToPoint2d (xi, yi, x, y);
DumpVector ("NPS: ", x, y, 0);   vyHostTexts.Msg ("");

PointToViewPoint (theC3D.VRPx, theC3D.VRPy, theC3D.VRPz, err, vx, vy, vz);
TransformPoint3 (x, y, vz, theC3D.MappingMatrix.inv, x, y, z);
DumpVector ("VRS: ", x, y, z);   vyHostTexts.Msg ("");

TransformPoint3 (x, y, z, theC3D.OrientationMatrix.inv, x, y, z);
DumpVector ("RWS: ", x, y, z);   vyHostTexts.Msg ("");
vyHostTexts.Msg ("")
END ListCoordinates;

BEGIN
X := 0.8;   Y := 1.1;   Z := - 1;
FOR i := 0 TO 10 DO
ListCoordinates (X, Y, - 1 + i * 1 / 3)
END
END Test3;

PROCEDURE Test4* (X, Y: SIGNED16;   VAR x, y, z: Real);
(** vs 0.0d0 *)	(*   26.01.95 10:27:09 *)
VAR vx, vy, vz: Real;   err: SIGNED16;
BEGIN PointToViewPoint (theC3D.VRPx, theC3D.VRPy, theC3D.VRPz, err, vx, vy, vz);
vyGraphBase.PointToPoint2d (X, Y, vx, vy);
DumpVector ("2d Display Coord.:   ", vx, vy, 0);   vyHostTexts.Msg ("");
(*vz := theC3D.FPd;*)
(*vz := 0;*)
(*vz := theC3D.FPd/(theC3D.FPd-theC3D.BPd);*)
DumpVector ("unit cube Coordinate:  ", vx, vy, vz);   vyHostTexts.Msg ("");
TransformPoint3 (vx, vy, vz, theC3D.View.inv, x, y, z);
DumpVector ("real world Coord.:  ", x, y, z);   vyHostTexts.Msg ("")
END Test4;


PROCEDURE Test5*;
(** vs 0.0d0 *)	(*   31.01.95 17:30:56 *)
VAR x, y, z, u, v, w: Real;
BEGIN
x := 1;   y := 0.5;   z := 3.2;
u := x;   v := y;   w := z;
REPEAT
Texts.WriteString (vyHostTexts.w, "angle: ");
Texts.WriteRealFix (vyHostTexts.w, Angle3 (x, y, z, u, v, w) * 180 / Math.pi, 5, 3);
vyHostTexts.Msg ("");
TransformPoint3 (u, v, w, rotation.m, u, v, w)
UNTIL Input.Available () > 0
END Test5;

PROCEDURE Test6*;
(** vs 0.0d0 *)	(*   01.02.95 14:48:03 *)
VAR
BEGIN
Texts.WriteRealFix (vyHostTexts.w,  Angle3 (1, 0, 0, - 1, - 1, 0) * 180 / Math.pi, 5, 3);   vyHostTexts.Msg ("");
Texts.WriteRealFix (vyHostTexts.w,  Angle3 (- 1, - 1, 0, 1, 0, 0) * 180 / Math.pi, 5, 3);   vyHostTexts.Msg ("")
END Test6;

