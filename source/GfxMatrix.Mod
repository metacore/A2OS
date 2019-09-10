(* ETH Oberon, Copyright 2001 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

MODULE GfxMatrix; (** portable *)	(* eos  *)
(** AUTHOR "eos"; PURPOSE "Affine transformations in 2D"; *)

	(*
		21.02.2000 - bugfix in Scaled: didn't recognize downscaling
		15.04.2000 - added Atan2
	*)

	IMPORT
		Streams, Math;


	CONST
		Eps = 1.0E-5;


	TYPE
		(**
			Transformation matrix
				3x2_matrices can represent any combination of affine transformations, i.e. of translation, rotation, scaling and
				shearing.

			Translate by tx, ty:
				[  1  0 ]
				[  0  1 ]
				[ tx ty ]

			Scale by sx, sy:
				[ sx   0 ]
				[  0  sy ]
				[  0   0 ]

			Rotate counter-clockwise by angle phi:
				[  cos(phi)   sin(phi) ]
				[ -sin(phi)  cos(phi) ]
				[       0             0       ]

			Shear along x_axis by factor f:
				[ 1   0 ]
				[ f    1 ]
				[ 0   0 ]
		**)

		Matrix* = ARRAY 3, 2 OF FLOAT32;


	VAR
		Identity*: Matrix;	(** identity matrix (read_only) **)


	(**--- Matrix Computation ---**)

	(** initialize matrix with given values **)
	PROCEDURE Init* (VAR m: Matrix; m00, m01, m10, m11, m20, m21: FLOAT32);
	BEGIN
		m[0, 0] := m00; m[0, 1] := m01;
		m[1, 0] := m10; m[1, 1] := m11;
		m[2, 0] := m20; m[2, 1] := m21
	END Init;

	(**
		Procedures Get3PointTransform, Get2PointTransform and Invert may not be able to find a solution. In that case,
		they return a singular matrix with all elements set to zero.
	**)

	(** calculate matrix that maps p0 to p1, q0 to q1, and r0 to r1 **)
	PROCEDURE Get3PointTransform* (px0, py0, px1, py1, qx0, qy0, qx1, qy1, rx0, ry0, rx1, ry1: FLOAT32; VAR res: Matrix);
		VAR m: ARRAY 6, 7 OF FLOAT32; i, j, k: SIGNED32; max, t: FLOAT32; v: ARRAY 6 OF FLOAT32;
	BEGIN
		(* initialize set of linear equations for matrix coefficients *)
		m[0, 0] := px0; m[0, 1] := py0; m[0, 2] := 1.0; m[0, 3] := 0.0; m[0, 4] := 0.0; m[0, 5] := 0.0; m[0, 6] := px1;
		m[1, 0] := qx0; m[1, 1] := qy0; m[1, 2] := 1.0; m[1, 3] := 0.0; m[1, 4] := 0.0; m[1, 5] := 0.0; m[1, 6] := qx1;
		m[2, 0] := rx0; m[2, 1] := ry0; m[2, 2] := 1.0; m[2, 3] := 0.0; m[2, 4] := 0.0;  m[2, 5] := 0.0; m[2, 6] := rx1;
		m[3, 0] := 0.0; m[3, 1] := 0.0; m[3, 2] := 0.0; m[3, 3] := px0; m[3, 4] := py0; m[3, 5] := 1.0; m[3, 6] := py1;
		m[4, 0] := 0.0; m[4, 1] := 0.0; m[4, 2] := 0.0; m[4, 3] := qx0; m[4, 4] := qy0; m[4, 5] := 1.0; m[4, 6] := qy1;
		m[5, 0] := 0.0; m[5, 1] := 0.0; m[5, 2] := 0.0; m[5, 3] := rx0; m[5, 4] := ry0; m[5, 5] := 1.0; m[5, 6] := ry1;

		(* Gaussian elimination with pivoting *)
		FOR i := 0 TO 5 DO
			k := i; max := ABS(m[i, i]);
			FOR j := i+1 TO 5 DO
				IF ABS(m[j, i]) > max THEN
					k := j; max := ABS(m[j, i])
				END
			END;
			IF max < Eps THEN	(* matrix is singular *)
				Init(res, 0, 0, 0, 0, 0, 0);
				RETURN
			END;
			IF k # i THEN	(* swap rows to bring largest element up *)
				FOR j := i TO 6 DO
					t := m[i, j]; m[i, j] := m[k, j]; m[k, j] := t
				END
			END;
			FOR k := i+1 TO 5 DO
				t := m[k, i]/m[i, i];
				FOR j := i+1 TO 6 DO
					m[k, j] := m[k, j] - t * m[i, j]
				END
			END
		END;

		(* solve equations *)
		FOR i := 5 TO 0 BY -1 DO
			t := m[i, 6];
			FOR j := i+1 TO 5 DO
				t := t - v[j] * m[i, j]
			END;
			v[i] := t/m[i, i]
		END;

		Init(res, v[0], v[3], v[1], v[4], v[2], v[5])
	END Get3PointTransform;

	(** calculate matrix that maps p0 to p1 and q0 to q1 **)
	PROCEDURE Get2PointTransform* (px0, py0, px1, py1, qx0, qy0, qx1, qy1: FLOAT32; VAR res: Matrix);
		VAR rx0, ry0, rx1, ry1: FLOAT32;
	BEGIN
		rx0 := px0 + py0 - qy0; ry0 := py0 + qx0 - px0;
		rx1 := px1 + py1 - qy1; ry1 := py1 + qx1 - px1;
		Get3PointTransform(px0, py0, px1, py1, qx0, qy0, qx1, qy1, rx0, ry0, rx1, ry1, res)
	END Get2PointTransform;

	(** calculate inverse of matrix **)
	PROCEDURE Invert* (m: Matrix; VAR res: Matrix);
		VAR det, inv: FLOAT32;
	BEGIN
		det := m[0, 0] * m[1, 1] - m[0, 1] * m[1, 0];
		IF ABS(det) >= Eps THEN	(* matrix can be inverted; use Cramer's rule *)
			inv := 1/det;
			res[0, 0] := +inv * m[1, 1];
			res[0, 1] := -inv * m[0, 1];
			res[1, 0] := -inv * m[1, 0];
			res[1, 1] := +inv * m[0, 0];
			res[2, 0] := +inv * (m[1, 0] * m[2, 1] - m[1, 1] * m[2, 0]);
			res[2, 1] := +inv * (m[0, 1] * m[2, 0] - m[0, 0] * m[2, 1])
		ELSE
			Init(res, 0, 0, 0, 0, 0, 0)
		END
	END Invert;


	(**--- Detection of Special Cases ---**)

	(** return determinant of matrix **)
	PROCEDURE Det* (VAR m: Matrix): FLOAT32;
	BEGIN
		RETURN m[0, 0] * m[1, 1] - m[0, 1] * m[1, 0]
	END Det;

	(** return whether matrix is singular **)
	PROCEDURE Singular* (VAR m: Matrix): BOOLEAN;
	BEGIN
		RETURN ABS(m[0, 0] * m[1, 1] - m[0, 1] * m[1, 0]) < Eps
	END Singular;

	(** return whether matrix changes vector lengths **)
	PROCEDURE Scaled* (VAR m: Matrix): BOOLEAN;
	BEGIN
		RETURN ABS(ABS(m[0, 0] * m[1, 1] - m[0, 1] * m[1, 0]) - 1) > Eps
	END Scaled;

	(** return whether matrix includes rotation, shear, or mirror transformation **)
	PROCEDURE Rotated* (VAR m: Matrix): BOOLEAN;
	BEGIN
		RETURN (m[0, 0] < -Eps) OR (m[1, 1] < -Eps) OR (ABS(m[0, 1]) > Eps) OR (ABS(m[1, 0]) > Eps)
	END Rotated;

	(** return whether matrices should be considered equal **)
	PROCEDURE Equal* (VAR m, n: Matrix): BOOLEAN;
	BEGIN
		RETURN
			(ABS(m[0, 0] - n[0, 0]) < Eps) & (ABS(m[0, 1] - n[0, 1]) < Eps) &
			(ABS(m[1, 0] - n[1, 0]) < Eps) & (ABS(m[1, 1] - n[1, 1]) < Eps) &
			(ABS(m[2, 0] - n[2, 0]) < Eps) & (ABS(m[2, 1] - n[2, 1]) < Eps)
	END Equal;


	(**--- Matrix Concatenation ---**)

	(**
		Combinations of single transformations are evaluated from left to right. Executing Translate, Rotate or Scale
		pre-concatenates a corresponding matrix to the left of the given matrix parameter. This has the effect that
		the new transformation is applied before all previously accumulated transformations. Every transformation is
		therefore executed in the context of the coordinate system defined by the concatenation of all transformations
		to its right.
	**)

	(** translation by (dx, dy) **)
	PROCEDURE Translate* (m: Matrix; dx, dy: FLOAT32; VAR res: Matrix);
	BEGIN
		res[0, 0] := m[0, 0]; res[0, 1] := m[0, 1];
		res[1, 0] := m[1, 0]; res[1, 1] := m[1, 1];
		res[2, 0] := m[2, 0] + dx * m[0, 0] + dy * m[1, 0];
		res[2, 1] := m[2, 1] + dx * m[0, 1] + dy * m[1, 1]
	END Translate;

	(** scale by (sx, sy) **)
	PROCEDURE Scale* (m: Matrix; sx, sy: FLOAT32; VAR res: Matrix);
	BEGIN
		res[0, 0] := sx * m[0, 0]; res[0, 1] := sx * m[0, 1];
		res[1, 0] := sy * m[1, 0]; res[1, 1] := sy * m[1, 1];
		res[2, 0] := m[2, 0]; res[2, 1] := m[2, 1]
	END Scale;

	(** scale at (ox, oy) by (sx, sy) **)
	PROCEDURE ScaleAt* (m: Matrix; ox, oy, sx, sy: FLOAT32; VAR res: Matrix);
		VAR tx, ty: FLOAT32;
	BEGIN
		res[0, 0] := sx * m[0, 0]; res[0, 1] := sx * m[0, 1];
		res[1, 0] := sy * m[1, 0]; res[1, 1] := sy * m[1, 1];
		tx := ox * (1-sx); ty := oy * (1-sy);
		res[2, 0] := tx * m[0, 0] + ty * m[1, 0] + m[2, 0];
		res[2, 1] := tx * m[0, 1] + ty * m[1, 1] + m[2, 1]
	END ScaleAt;

	(** rotate counter-clockwise by angle specified by its sine and cosine **)
	PROCEDURE Rotate* (m: Matrix; sin, cos: FLOAT32; VAR res: Matrix);
	BEGIN
		res[0, 0] := cos * m[0, 0] + sin * m[1, 0]; res[0, 1] := cos * m[0, 1] + sin * m[1, 1];
		res[1, 0] := -sin * m[0, 0] + cos * m[1, 0]; res[1, 1] := -sin * m[0, 1] + cos * m[1, 1];
		res[2, 0] := m[2, 0]; res[2, 1] := m[2, 1]
	END Rotate;

	(** rotate counter-clockwise around (ox, oy) by angle specified by its sine and cosine **)
	PROCEDURE RotateAt* (m: Matrix; ox, oy, sin, cos: FLOAT32; VAR res: Matrix);
		VAR tx, ty: FLOAT32;
	BEGIN
		res[0, 0] := cos * m[0, 0] + sin * m[1, 0]; res[0, 1] := cos * m[0, 1] + sin * m[1, 1];
		res[1, 0] := -sin * m[0, 0] + cos * m[1, 0]; res[1, 1] := -sin * m[0, 1] + cos * m[1, 1];
		tx := ox * (1-cos) + oy * sin; ty := oy * (1-cos) - ox * sin;
		res[2, 0] := tx * m[0, 0] + ty * m[1, 0] + m[2, 0];
		res[2, 1] := tx * m[0, 1] + ty * m[1, 1] + m[2, 1]
	END RotateAt;

	(** concatenate matrices **)
	PROCEDURE Concat* (m, n: Matrix; VAR res: Matrix);
	BEGIN
		res[0, 0] := m[0, 0] * n[0, 0] + m[0, 1] * n[1, 0];
		res[0, 1] := m[0, 0] * n[0, 1] + m[0, 1] * n[1, 1];
		res[1, 0] := m[1, 0] * n[0, 0] + m[1, 1] * n[1, 0];
		res[1, 1] := m[1, 0] * n[0, 1] + m[1, 1] * n[1, 1];
		res[2, 0] := m[2, 0] * n[0, 0] + m[2, 1] * n[1, 0] + n[2, 0];
		res[2, 1] := m[2, 0] * n[0, 1] + m[2, 1] * n[1, 1] + n[2, 1]
	END Concat;


	(**--- Arctan of Vector ---**)

	PROCEDURE Atan2* (x, y: FLOAT32): FLOAT32;
		VAR phi: FLOAT32;
	BEGIN
		IF (ABS(x) < 1.0) & (ABS(y) >= ABS(x * MAX(FLOAT32))) THEN	(* y/x would overflow *)
			IF y >= 0.0 THEN phi := Math.pi/2
			ELSE phi := -Math.pi/2
			END
		ELSIF x > 0.0 THEN	(* 1st or 4th quadrant *)
			phi := Math.arctan(y/x)
		ELSIF x < 0.0 THEN	(* 2nd or 3rd quadrant *)
			phi := Math.arctan(y/x) + Math.pi
		END;
		RETURN phi
	END Atan2;


	(**--- Matrix Application ---**)

	(** apply transformation matrix to point **)
	PROCEDURE Apply* (VAR m: Matrix; xin, yin: FLOAT32; VAR xout, yout: FLOAT32);
	BEGIN
		xout := xin * m[0, 0] + yin * m[1, 0] + m[2, 0];
		yout := xin * m[0, 1] + yin * m[1, 1] + m[2, 1]
	END Apply;

	(** apply transformation matrix to vector (ignoring translation) **)
	PROCEDURE ApplyToVector* (VAR m: Matrix; xin, yin: FLOAT32; VAR xout, yout: FLOAT32);
	BEGIN
		xout := xin * m[0, 0] + yin * m[1, 0];
		yout := xin * m[0, 1] + yin * m[1, 1]
	END ApplyToVector;

	(** apply transformation matrix to distance **)
	PROCEDURE ApplyToDist* (VAR m: Matrix; din: FLOAT32; VAR dout: FLOAT32);
		VAR x, y: FLOAT32;
	BEGIN
		x := din * m[0, 0]; y := din * m[0, 1];
		IF ABS(y) < 1.0E-3 THEN dout := x
		ELSE dout := Math.sqrt(x * x + y * y)
		END
	END ApplyToDist;

	(** apply transformation matrix to axis-aligned rectangle; result is enclosing axis-aligned rectangle **)
	PROCEDURE ApplyToRect* (VAR m: Matrix; ilx, ily, irx, iuy: FLOAT32; VAR olx, oly, orx, ouy: FLOAT32);
		VAR l, h: FLOAT32;
	BEGIN
		olx := m[2, 0]; orx := m[2, 0];
		l := ilx * m[0, 0]; h := irx * m[0, 0];
		IF l <= h THEN olx := olx + l; orx := orx + h ELSE olx := olx + h; orx := orx + l END;
		l := ily * m[1, 0]; h := iuy * m[1, 0];
		IF l <= h THEN olx := olx + l; orx := orx + h ELSE olx := olx + h; orx := orx + l END;
		oly := m[2, 1]; ouy := m[2, 1];
		l := ilx * m[0, 1]; h := irx * m[0, 1];
		IF l <= h THEN oly := oly + l; ouy := ouy + h ELSE oly := oly + h; ouy := ouy + l END;
		l := ily * m[1, 1]; h := iuy * m[1, 1];
		IF l <= h THEN oly := oly + l; ouy := ouy + h ELSE oly := oly + h; ouy := ouy + l END
	END ApplyToRect;

	(** apply inverse of matrix to point **)
	PROCEDURE Solve* (VAR m: Matrix; u, v: FLOAT32; VAR x, y: FLOAT32);
		VAR det: FLOAT32;
	BEGIN
		det := m[0, 0] * m[1, 1] - m[0, 1] * m[1, 0];
		IF ABS(det) >= Eps THEN	(* matrix can be inverted *)
			u := u - m[2, 0]; v := v - m[2, 1];
			x := (m[1, 1] * u - m[1, 0] * v)/det;
			y := (m[0, 0] * v - m[0, 1] * u)/det
		END
	END Solve;


	(**--- Matrix I/O ---**)

	PROCEDURE Write* (VAR w: Streams.Writer; VAR m: Matrix);
		VAR i: SIGNED32;
	BEGIN
		FOR i := 0 TO 2 DO
			w.RawReal(m[i, 0]); w.RawReal(m[i, 1])
		END
	END Write;

	PROCEDURE Read* (VAR r: Streams.Reader; VAR m: Matrix);
		VAR i: SIGNED32;
	BEGIN
		FOR i := 0 TO 2 DO
			r.RawReal(m[i, 0]); r.RawReal(m[i, 1])
		END
	END Read;


BEGIN
	Init(Identity, 1, 0, 0, 1, 0, 0)
END GfxMatrix.
