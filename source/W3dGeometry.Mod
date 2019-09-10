MODULE W3dGeometry;	(** AUTHOR "TF"; PURPOSE "Geometrical primitives (case study)"; *)

IMPORT
	Vectors := W3dVectors;

TYPE
	Plane* = RECORD n* : Vectors.TVector3d; d* : FLOAT64 END;
	Ray* = RECORD p, d : Vectors.TVector3d END;

	Frustum* = OBJECT
	VAR
		nearP*, farP*, bottomP*, rightP*, topP*, leftP* : Plane;

		PROCEDURE Make*(p, d, u : Vectors.TVector3d; focus, w, h, near, far : FLOAT64);
		VAR left, z, p0, p1, p2, p3, f0, f1, f2, near0, near1, near2, far0, far1, far2 : Vectors.TVector3d; factor : FLOAT64;
		BEGIN
			left := Vectors.Cross(d, u);
			z := Vectors.VAdd3(p, Vectors.VScaled3(d, - focus));
			p0 := Vectors.VAdd3(Vectors.VAdd3(p, Vectors.VScaled3(u, -h/2)), Vectors.VScaled3(left, w/2));
			p1 := Vectors.VAdd3(Vectors.VAdd3(p, Vectors.VScaled3(u, -h/2)), Vectors.VScaled3(left, -w/2));
			p2 := Vectors.VAdd3(Vectors.VAdd3(p, Vectors.VScaled3(u, h/2)), Vectors.VScaled3(left, -w/2));
			p3 := Vectors.VAdd3(Vectors.VAdd3(p, Vectors.VScaled3(u, h/2)), Vectors.VScaled3(left, w/2));

			f0 := Vectors.VNormed3(Vectors.VSub3(p0, z));
			f1 := Vectors.VNormed3(Vectors.VSub3(p1, z));
			f2 := Vectors.VNormed3(Vectors.VSub3(p2, z));

			factor := 1 / Vectors.Scalar3(f0, d); (* symmetric situation, all factors are the same *)
			near0 := Vectors.VAdd3(p0, Vectors.VScaled3(f0, near * factor));
			near1 := Vectors.VAdd3(p1, Vectors.VScaled3(f1, near * factor));
			near2 := Vectors.VAdd3(p1, Vectors.VScaled3(f2, near * factor));

			far0 := Vectors.VAdd3(p0, Vectors.VScaled3(f0, far * factor));
			far1 := Vectors.VAdd3(p1, Vectors.VScaled3(f1, far * factor));
			far2 := Vectors.VAdd3(p1, Vectors.VScaled3(f2, far * factor));

			nearP := MakePlane(near0, near2, near1);
			farP := MakePlane(far0, far1, far2);
			leftP := MakePlane(z, p0, p3);
			bottomP := MakePlane(z, p1, p0);
			rightP := MakePlane(z, p2, p1);
			topP := MakePlane(z, p3, p2);
		END Make;

		PROCEDURE IsBSOutsideBehind*(center : Vectors.TVector3d; r: FLOAT64): BOOLEAN;
		BEGIN
			RETURN  (Distance(nearP, center) > r) OR
							(Distance(leftP, center) > r) OR
							(Distance(rightP, center) > r) OR
							(Distance(bottomP, center) > r) OR
							(Distance(topP, center) > r)
		END IsBSOutsideBehind;
	END Frustum;

PROCEDURE MakePlane*(p0, p1, p2 : Vectors.TVector3d) : Plane;
VAR result : Plane;
BEGIN
	result.n := Vectors.VNormed3(Vectors.Cross(Vectors.VSub3(p1, p0), Vectors.VSub3(p2, p0)));
	result.d := - Vectors.Scalar3(result.n, p0);
	RETURN result
END MakePlane;

PROCEDURE Distance*(e: Plane; p : Vectors.TVector3d) : FLOAT64;
BEGIN
	RETURN Vectors.Scalar3(e.n, p) + e.d
END Distance;

(** intersection between g and e, g is treated as line *)
PROCEDURE Intersection*(VAR g : Ray; VAR e : Plane; VAR p : Vectors.TVector3d) : BOOLEAN;
VAR m, d: FLOAT64;
BEGIN
  d := Vectors.Scalar3(e.n, g.d);
  IF d = 0 THEN RETURN FALSE END;
  m := -(Vectors.Scalar3(e.n, g.p)+e.d) / d;
  p := Vectors.VAdd3(g.p, Vectors.VScaled3(g.d, m));
  RETURN TRUE
END Intersection;

END W3dGeometry.
