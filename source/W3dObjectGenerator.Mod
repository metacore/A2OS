MODULE W3dObjectGenerator;	(** AUTHOR "TF"; PURPOSE "Generator procedures for 3d objects (case study)"; *)

IMPORT
	AbstractWorld := W3dAbstractWorld, Matrix := W3dMatrix, Vectors := W3dVectors, MathL;

TYPE
	VectorArray = POINTER TO ARRAY OF Vectors.TVector3d;
	VertexArray = POINTER TO ARRAY OF AbstractWorld.Vertex;
	(* trivial implementation *)
	Path* = OBJECT
	VAR
		points : VectorArray;
		nofPoints : SIZE;

		PROCEDURE &Init*;
		BEGIN
			NEW(points, 4);
			nofPoints := 0
		END Init;

		PROCEDURE AddPoint*(p : Vectors.TVector3d);
		VAR tempPoints : VectorArray; i :SIZE;
		BEGIN
			IF nofPoints = LEN(points) THEN
				NEW(tempPoints, LEN(points) * 2);
				FOR i := 0 TO LEN(points) - 1 DO tempPoints[i] := points[i] END;
				points := tempPoints;
			END;
			points[nofPoints] := p;
			INC(nofPoints)
		END AddPoint;

		PROCEDURE GetNofPoints*(): SIZE;
		BEGIN
			RETURN nofPoints
		END GetNofPoints;

		PROCEDURE GetPoint*(i : SIZE): Vectors.TVector3d;
		BEGIN
			RETURN points[i]
		END GetPoint;
	END Path;

PROCEDURE RotationObject*(mat : Matrix.Matrix4x4; path : Path; axis: Vectors.TVector3d; sides : SIGNED32;
				obj : AbstractWorld.Object; color : SIGNED32);
VAR first, last, current : VertexArray;
	m : Matrix.Matrix4x4;
	i, j : SIZE;
BEGIN
	NEW(first, path.GetNofPoints()); NEW(last, path.GetNofPoints()); NEW(current, path.GetNofPoints());
	FOR i := 0 TO path.GetNofPoints() - 1 DO first[i] := obj.AddVertex(Matrix.Mul(mat, path.GetPoint(i))) END;

	FOR i := 0 TO path.GetNofPoints() - 1 DO last[i] := first[i] END;
	FOR i := 0 TO sides - 1 DO
		m := Matrix.Rotation4x4(axis, i / sides * 2 * MathL.pi); m := Matrix.MulMat(mat, m);
		FOR j := 0 TO path.GetNofPoints() - 1 DO current[j] := obj.AddVertex(Matrix.Mul(m, path.GetPoint(j))) END;
		ConnectVLists(last, current, obj, color);
		FOR j := 0 TO path.GetNofPoints() - 1 DO last[j] := current[j] END;
	END;
	ConnectVLists(current, first, obj, color)
END RotationObject;

PROCEDURE ConnectVLists(a, b: VertexArray; obj : AbstractWorld.Object; color : SIGNED32);
VAR i : SIZE;
BEGIN
	(* top can be only one triangle*)
	IF a[0] = b[0] THEN
		obj.AddTriangle(a[1], a[0], b[1], color, NIL, FALSE, FALSE)
	ELSE
		obj.AddTriangle(a[1], a[0], b[1], color, NIL, FALSE, FALSE);
		obj.AddTriangle(b[0], b[1], a[0], color, NIL, FALSE, FALSE)
	END;
	FOR i := 1 TO LEN(a) - 3 DO
		obj.AddTriangle(a[i + 1], a[i], b[i + 1], color, NIL, FALSE, FALSE);
		obj.AddTriangle(b[i], b[i + 1], a[i], color, NIL, FALSE, FALSE);
	END;
	(* bottom can be only one triangle*)
	IF a[LEN(a) - 1] = b[LEN(b) - 1] THEN
		obj.AddTriangle(a[LEN(a) - 1], a[LEN(a) - 2], b[LEN(b) - 2], color, NIL, FALSE, FALSE)
	ELSE
		obj.AddTriangle(a[LEN(a) - 1], a[LEN(a) - 2], b[LEN(b) - 1], color, NIL, FALSE, FALSE);
		obj.AddTriangle(b[LEN(b) - 2], b[LEN(b) - 1], a[LEN(a) - 2], color, NIL, FALSE, FALSE)
	END
END ConnectVLists;

PROCEDURE Arrow*(mat : Matrix.Matrix4x4; l0, l1, r0, r1 : FLOAT64; segments : SIGNED32; obj : AbstractWorld.Object; color : SIGNED32);
VAR p : Path;
BEGIN
	NEW(p);
	p.AddPoint(Vectors.Vector3d(l0+l1, 0, 0));
	p.AddPoint(Vectors.Vector3d(l0, r1, 0));
	p.AddPoint(Vectors.Vector3d(l0, r0, 0));
	p.AddPoint(Vectors.Vector3d(0, r0, 0));
	RotationObject(mat, p, Vectors.Vector3d(1, 0, 0), segments, obj, color);
END Arrow;

PROCEDURE Sphere*(mat : Matrix.Matrix4x4; radius : FLOAT64; segments : SIGNED32; obj : AbstractWorld.Object; color : SIGNED32);
VAR p : Path;
	i : SIGNED32;
BEGIN
	NEW(p);
	FOR i := 0 TO segments DO
		p.AddPoint(Vectors.Vector3d(-MathL.sin(i / segments * MathL.pi) * radius, MathL.cos(i / segments * MathL.pi) * radius, 0));
	END;
  RotationObject(mat, p, Vectors.Vector3d(0, 1, 0), segments, obj, color)
END Sphere;

PROCEDURE Box*(mat : Matrix.Matrix4x4; x, y, z: FLOAT64; obj : AbstractWorld.Object; color : SIGNED32);
VAR vert : ARRAY 8 OF AbstractWorld.Vertex;
BEGIN
	x := x/2; y := y/2; z := z/2;
	(* front *)
	vert[0] := obj.AddVertex(Matrix.Mul(mat, Vectors.Vector3d(-x, -y, -z)));
	vert[1] := obj.AddVertex(Matrix.Mul(mat, Vectors.Vector3d(x, -y, -z)));
	vert[2] := obj.AddVertex(Matrix.Mul(mat, Vectors.Vector3d(x, y, -z)));
	vert[3] := obj.AddVertex(Matrix.Mul(mat, Vectors.Vector3d(-x, y, -z)));
	(* back *)
	vert[4] := obj.AddVertex(Matrix.Mul(mat, Vectors.Vector3d(-x, -y, z)));
	vert[5] := obj.AddVertex(Matrix.Mul(mat, Vectors.Vector3d(x, -y, z)));
	vert[6] := obj.AddVertex(Matrix.Mul(mat, Vectors.Vector3d(x, y, z)));
	vert[7] := obj.AddVertex(Matrix.Mul(mat, Vectors.Vector3d(-x, y, z)));

	(* triangles *)
	(* front *)
	obj.AddTriangle(vert[1], vert[0], vert[2], color, NIL, FALSE, TRUE); obj.AddTriangle(vert[2], vert[0], vert[3], color, NIL, FALSE, TRUE);
	(* right *)
	obj.AddTriangle(vert[5], vert[1], vert[6], color, NIL, FALSE, TRUE); obj.AddTriangle(vert[6], vert[1], vert[2], color, NIL, FALSE, TRUE);
	(* back *)
	obj.AddTriangle(vert[4], vert[5], vert[7], color, NIL, FALSE, TRUE); obj.AddTriangle(vert[7], vert[5], vert[6], color, NIL, FALSE, TRUE);
	(* left *)
	obj.AddTriangle(vert[0], vert[4], vert[3], color, NIL, FALSE, TRUE); obj.AddTriangle(vert[3], vert[4], vert[7], color, NIL, FALSE, TRUE);
	(* top *)
	obj.AddTriangle(vert[2], vert[3], vert[6], color, NIL, FALSE, TRUE); obj.AddTriangle(vert[7], vert[6], vert[3], color, NIL, FALSE, TRUE);
	(* bottom *)
	obj.AddTriangle(vert[1], vert[5], vert[0], color, NIL, FALSE, TRUE); obj.AddTriangle(vert[0], vert[5], vert[4], color, NIL, FALSE, TRUE)
END Box;

PROCEDURE TexBox*(mat : Matrix.Matrix4x4; x, y, z: FLOAT64; obj : AbstractWorld.Object; color : SIGNED32; tex: AbstractWorld.Texture);
VAR vert : ARRAY 8 OF Vectors.TVector3d;
		va, vb, vc, vd: AbstractWorld.Vertex;
BEGIN
	x := x/2; y := y/2; z := z/2;
	(* front *)
	vert[0] := Matrix.Mul(mat, Vectors.Vector3d(-x, -y, -z));
	vert[1] := Matrix.Mul(mat, Vectors.Vector3d(x, -y, -z));
	vert[2] := Matrix.Mul(mat, Vectors.Vector3d(x, y, -z));
	vert[3] := Matrix.Mul(mat, Vectors.Vector3d(-x, y, -z));
	(* back *)
	vert[4] := Matrix.Mul(mat, Vectors.Vector3d(-x, -y, z));
	vert[5] := Matrix.Mul(mat, Vectors.Vector3d(x, -y, z));
	vert[6] := Matrix.Mul(mat, Vectors.Vector3d(x, y, z));
	vert[7] := Matrix.Mul(mat, Vectors.Vector3d(-x, y, z));

	(* triangles *)
	(* front *)
	va := obj.AddVertex(vert[1]); va.SetUV(1, 1);
	vb := obj.AddVertex(vert[0]); vb.SetUV(0, 1);
	vc := obj.AddVertex(vert[2]); vc.SetUV(1, 0);
	vd := obj.AddVertex(vert[3]); vd.SetUV(0, 0);
	obj.AddTriangle(va, vb, vc, color, tex, FALSE, TRUE); obj.AddTriangle(vc, vb, vd, color, tex, FALSE, TRUE);
	(* right *)
	va := obj.AddVertex(vert[5]); va.SetUV(1, 1);
	vb := obj.AddVertex(vert[1]); vb.SetUV(0, 1);
	vc := obj.AddVertex(vert[6]); vc.SetUV(1, 0);
	vd := obj.AddVertex(vert[2]); vd.SetUV(0, 0);
	obj.AddTriangle(va, vb, vc, color, tex, FALSE, TRUE); obj.AddTriangle(vc, vb, vd, color, tex, FALSE, TRUE);
	(* back *)
	va := obj.AddVertex(vert[4]); va.SetUV(1, 1);
	vb := obj.AddVertex(vert[5]); vb.SetUV(0, 1);
	vc := obj.AddVertex(vert[7]); vc.SetUV(1, 0);
	vd := obj.AddVertex(vert[6]); vd.SetUV(0, 0);
	obj.AddTriangle(va, vb, vc, color, tex, FALSE, TRUE); obj.AddTriangle(vc, vb, vd, color, tex, FALSE, TRUE);
	(* left *)
	va := obj.AddVertex(vert[0]); va.SetUV(1, 1);
	vb := obj.AddVertex(vert[4]); vb.SetUV(0, 1);
	vc := obj.AddVertex(vert[3]); vc.SetUV(1, 0);
	vd := obj.AddVertex(vert[7]); vd.SetUV(0, 0);
	obj.AddTriangle(va, vb, vc, color, tex, FALSE, TRUE); obj.AddTriangle(vc, vb, vd, color, tex, FALSE, TRUE);
	(* top *)
	va := obj.AddVertex(vert[2]); va.SetUV(1, 1);
	vb := obj.AddVertex(vert[3]); vb.SetUV(0, 1);
	vc := obj.AddVertex(vert[6]); vc.SetUV(1, 0);
	vd := obj.AddVertex(vert[7]); vd.SetUV(0, 0);
	obj.AddTriangle(va, vb, vc, color, tex, FALSE, TRUE); obj.AddTriangle(vd, vc, vb, color, tex, FALSE, TRUE);
	(* bottom *)
	va := obj.AddVertex(vert[1]); va.SetUV(1, 1);
	vb := obj.AddVertex(vert[5]); vb.SetUV(0, 1);
	vc := obj.AddVertex(vert[0]); vc.SetUV(1, 0);
	vd := obj.AddVertex(vert[4]); vd.SetUV(0, 0);
	obj.AddTriangle(va, vb, vc, color, tex, FALSE, TRUE); obj.AddTriangle(vc, vb, vd, color, tex, FALSE, TRUE);
END TexBox;

END W3dObjectGenerator.
