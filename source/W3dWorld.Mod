MODULE W3dWorld;	(** AUTHOR "TF"; PURPOSE "Implementation of a 3d world data structure and renderer"; *)

IMPORT
	AbstractWorld := W3dAbstractWorld, Vectors := W3dVectors, Matrix := W3dMatrix, Raster, Classes := TFClasses,
	Rasterizer := W3dRasterizer, W3dGeometry;

CONST TraceNormals = FALSE;

TYPE
	Vertex* = Rasterizer.Vertex;
	VertexArray = POINTER TO ARRAY OF Vertex;

	Texture = Rasterizer.Texture;

	Triangle = Rasterizer.Triangle;
	TriangleArray = POINTER TO ARRAY OF Triangle;
	AABB = RECORD a, b : Vectors.TVector3d; empty : BOOLEAN END;

	Object* = OBJECT (AbstractWorld.Object)
		VAR
			triangles : TriangleArray;
			nofTriangles : LONGINT;

			vertices : VertexArray;
			nofVertices : LONGINT;
			aabb : AABB;
			bsCenter : Vectors.TVector3d;
			bsRadius : LONGREAL;
			bsValid : BOOLEAN;
			isAnimated : BOOLEAN;
			index : LONGINT;

		PROCEDURE &Init*;
		BEGIN
			NEW(vertices, 64);
			NEW(triangles, 32);
			aabb.empty := TRUE;
			bsValid := FALSE
		END Init;

		PROCEDURE SetIndex*(idx : LONGINT);
		BEGIN
			index := idx
		END SetIndex;

		PROCEDURE AddTexture*(img : Raster.Image): AbstractWorld.Texture;
		VAR t : Texture;
		BEGIN
			NEW(t);
			t.img := img;
			RETURN t
		END AddTexture;

		PROCEDURE AddVertex*(p : Vectors.TVector3d): AbstractWorld.Vertex;
		VAR n : VertexArray; i : LONGINT;
			v: Vertex;
		BEGIN
			NEW(v); v.SetPos(p); GrowAABB(aabb, p); bsValid := FALSE;
			IF nofVertices = LEN(vertices) THEN
				NEW(n, LEN(vertices) * 2);
				FOR i := 0 TO nofVertices - 1 DO n[i] := vertices[i] END;
				vertices := n
			END;
			vertices[nofVertices] := v; INC(nofVertices);
			RETURN v
		END AddVertex;

		PROCEDURE CalcBS;
		BEGIN
			bsCenter := Vectors.VScaled3(Vectors.VAdd3(aabb.a, aabb.b), 0.5); bsRadius := Vectors.VLength3VV(aabb.a, aabb.b) / 2;
			bsValid := TRUE
		END CalcBS;

		PROCEDURE AddTriangle*(a, b, c : AbstractWorld.Vertex; color : LONGINT; tex : AbstractWorld.Texture; mask0, culled: BOOLEAN);
		VAR n : TriangleArray; i : LONGINT;
				f : REAL;
		BEGIN
			IF nofTriangles = LEN(triangles) THEN
				NEW(n, LEN(triangles) * 2);
				FOR i := 0 TO nofTriangles - 1 DO n[i] := triangles[i] END;
				triangles := n
			END;
			triangles[nofTriangles].vert[0] := a(Vertex);
			triangles[nofTriangles].vert[1] := b(Vertex);
			triangles[nofTriangles].vert[2] := c(Vertex);
			triangles[nofTriangles].color := color;
			triangles[nofTriangles].culled := culled;
			triangles[nofTriangles].normal := Vectors.VNormed3(Vectors.Cross(
				Vectors.VSub3(b(Vertex).p, a(Vertex).p), Vectors.VSub3(c(Vertex).p, a(Vertex).p)));
			IF tex # NIL THEN triangles[nofTriangles].tex := tex(Texture) END;

			f := (1 + ABS(SHORT(
				Vectors.Scalar3(triangles[nofTriangles].normal, Vectors.VNormed3(Vectors.Vector3d(0.2, 0.9, 0.4)))))) / 2;
			triangles[nofTriangles].transColor := ASH(ENTIER(color MOD 256 * f), -3) +
					ASH(ASH(ENTIER(color DIV 256 MOD 256 * f ), -2), 5) +
					ASH(ASH(ENTIER(color DIV 65536 MOD 256 * f), -3), 11);

			 INC(nofTriangles)
		END AddTriangle;

		PROCEDURE Clear*;
		VAR i : LONGINT;
		BEGIN
			FOR i := nofVertices - 1 TO 0 BY - 1 DO vertices[i] := NIL END;
			nofTriangles := 0;
			nofVertices := 0;
		END Clear;

	END Object;

	World* = OBJECT (AbstractWorld.World)
	VAR
		objects, animated : Classes.List;
		p, d, u : Vectors.TVector3d;
		trans : Matrix.Matrix4x4;
		distpp : LONGREAL;
		rasterizer : Rasterizer.Rasterizer;
		width, height : LONGINT;
		quality* 	: LONGINT;
		frustum* : W3dGeometry.Frustum;
		clearColor : LONGINT;

		tempTri : Triangle;
		tempv0, tempv1 : Vertex;
		changed, invertable : BOOLEAN;

		worldValid : BOOLEAN; (* is the non-animated part of the world valid ?
						No if not rendered, trans matrix changed or isAnimated of an object is changed *)

		PROCEDURE &Init*(w, h, clearColor :LONGINT);
		BEGIN
			NEW(objects); NEW(animated); distpp := w/2; NEW(rasterizer); rasterizer.SetSize(w, h);
			NEW(frustum);
			width := w; height := h; SELF.clearColor := clearColor;
			NEW(tempv0); NEW(tempv1);
		END Init;

		PROCEDURE CreateObject*(): AbstractWorld.Object;
		VAR obj : Object;
		BEGIN
			NEW(obj); RETURN obj
		END CreateObject;

		PROCEDURE AddObject*(x: AbstractWorld.Object);
		BEGIN
			objects.Add(x)
		END AddObject;

		PROCEDURE ReplaceObject*(x, y : AbstractWorld.Object);
		BEGIN
			objects.Replace(x, y)
		END ReplaceObject;

		PROCEDURE SetAnimated*(obj : AbstractWorld.Object; animated: BOOLEAN);
		BEGIN
			obj(Object).isAnimated := animated;
			worldValid := FALSE
		END SetAnimated;

		PROCEDURE Clear*;
		BEGIN
			objects.Clear;
			animated.Clear
		END Clear;

		PROCEDURE SetCamera*(p, d, u : Vectors.TVector3d);
		BEGIN {EXCLUSIVE}
			SELF.p := p; SELF.d := d; SELF.u := u;
			trans := Matrix.CameraMatrix(p, d, u);
			frustum.Make(p, d, u, distpp, rasterizer.width, rasterizer.height, 100, 1000);
			worldValid := FALSE
		END SetCamera;

		PROCEDURE ScreenPos(p : Vectors.TVector3d; VAR x, y: LONGREAL);
		VAR inv : LONGREAL;
		BEGIN
			inv := distpp / p.z;
			x := p.x * inv + (rasterizer.width DIV 2);
			y := rasterizer.height - (p.y * inv + (rasterizer.height DIV 2))
		END ScreenPos;

		PROCEDURE RasterTriangle(VAR tri : Triangle);
		VAR p, d: Vectors.TVector3d;
			a, b : Rasterizer.Vertex;
		BEGIN
			CASE quality OF
				0 :rasterizer.RenderTriangle(tri)
				|1 :rasterizer.SubDivTriangle(tri)
				|2 :rasterizer.RenderPerspTriangle(tri)
				|3 :rasterizer.SubDivLine(tri.vert[0], tri.vert[1]);
					rasterizer.SubDivLine(tri.vert[1], tri.vert[2]);
					rasterizer.SubDivLine(tri.vert[2], tri.vert[0])
			ELSE
			END;

			IF TraceNormals THEN
				p := Vectors.VScaled3(Vectors.VAdd3(Vectors.VAdd3(tri.vert[0].pt, tri.vert[1].pt), tri.vert[2].pt), 0.3333);
				d := Vectors.VAdd3(p, Vectors.VScaled3(Vectors.VNormed3(Vectors.Cross(
				Vectors.VSub3(tri.vert[1].pt, tri.vert[0].pt), Vectors.VSub3(tri.vert[2].pt, tri.vert[0].pt))), 30));
				NEW(a); NEW(b);
				a.pt := p; b.pt := d; ScreenPos(a.pt, a.x, a.y); ScreenPos(b.pt, b.x, b.y);
				rasterizer.SubDivLine(a, b);
			END
		END RasterTriangle;

		PROCEDURE ClipDrawTriangle(VAR tri : Triangle);
		VAR c : LONGINT; v0, v1, v2 : Vertex; d, m: LONGREAL;
		BEGIN
			IF ~(tri.vert[0].behind OR tri.vert[1].behind OR tri.vert[2].behind) THEN
				RasterTriangle(tri)
			ELSE
				c := 0 ; IF tri.vert[0].behind THEN INC(c) END; IF tri.vert[1].behind THEN INC(c) END;
				IF tri.vert[2].behind THEN INC(c) END;
				IF c = 2 THEN
					IF ~tri.vert[0].behind THEN v0 := tri.vert[0]; v1 := tri.vert[1]; v2 := tri.vert[2] END;
					IF ~tri.vert[1].behind THEN v0 := tri.vert[1]; v1 := tri.vert[2]; v2 := tri.vert[0] END;
					IF ~tri.vert[2].behind THEN v0 := tri.vert[2]; v1 := tri.vert[0]; v2 := tri.vert[1] END;
					d := Vectors.Scalar3(frustum.nearP.n, Vectors.VNormed3(Vectors.VSub3(v1.p, v0.p)));
					IF d # 0 THEN
						m := - (Vectors.Scalar3(frustum.nearP.n, v0.p) + frustum.nearP.d) / d / Vectors.VLength3VV(v1.p, v0.p);
						tempv0.u := v0.u + (v1.u - v0.u) * m;
						tempv0.v := v0.v + (v1.v - v0.v) * m;
						tempv0.p := Vectors.VAdd3(v0.p, Vectors.VScaled3(Vectors.VSub3(v1.p, v0.p), m));

						tempv0.pt := Matrix.Mul(trans, tempv0.p); ScreenPos(tempv0.pt, tempv0.x, tempv0.y);
					END;
					d := Vectors.Scalar3(frustum.nearP.n, Vectors.VNormed3(Vectors.VSub3(v2.p, v0.p)));
					IF d # 0 THEN
						m := - (Vectors.Scalar3(frustum.nearP.n, v0.p) + frustum.nearP.d) / d / Vectors.VLength3VV(v2.p, v0.p);
						tempv1.u := v0.u + (v2.u - v0.u) * m;
						tempv1.v := v0.v + (v2.v - v0.v) * m;
						tempv1.p := Vectors.VAdd3(v0.p, Vectors.VScaled3(Vectors.VSub3(v2.p, v0.p), m));

						tempv1.pt := Matrix.Mul(trans, tempv1.p); ScreenPos(tempv1.pt, tempv1.x, tempv1.y);
					END;

					tempTri.vert[0] := v0; tempTri.vert[1] := tempv0; tempTri.vert[2] := tempv1; tempTri.tex := tri.tex;
					tempTri.color := tri.color; tempTri.transColor := tri.transColor;

					RasterTriangle(tempTri);
				ELSIF c = 1 THEN
					IF tri.vert[0].behind THEN v0 := tri.vert[0]; v1 := tri.vert[1]; v2 := tri.vert[2] END;
					IF tri.vert[1].behind THEN v0 := tri.vert[1]; v1 := tri.vert[2]; v2 := tri.vert[0] END;
					IF tri.vert[2].behind THEN v0 := tri.vert[2]; v1 := tri.vert[0]; v2 := tri.vert[1] END;
					d := Vectors.Scalar3(frustum.nearP.n, Vectors.VNormed3(Vectors.VSub3(v1.p, v0.p)));
					IF d # 0 THEN
						m := - (Vectors.Scalar3(frustum.nearP.n, v0.p) + frustum.nearP.d) / d / Vectors.VLength3VV(v0.p, v1.p);
						tempv0.u := v0.u + (v1.u - v0.u) * m;
						tempv0.v := v0.v + (v1.v - v0.v) * m;
						tempv0.p := Vectors.VAdd3(v0.p, Vectors.VScaled3(Vectors.VSub3(v1.p, v0.p), m));
						tempv0.pt := Matrix.Mul(trans, tempv0.p); ScreenPos(tempv0.pt, tempv0.x, tempv0.y);
					END;
					d := Vectors.Scalar3(frustum.nearP.n, Vectors.VNormed3(Vectors.VSub3(v2.p, v0.p)));
					IF d # 0 THEN
						m := - (Vectors.Scalar3(frustum.nearP.n, v0.p) + frustum.nearP.d) / d / Vectors.VLength3VV(v0.p, v2.p);
						tempv1.u := v0.u + (v2.u - v0.u) * m;
						tempv1.v := v0.v + (v2.v - v0.v) * m;
						tempv1.p := Vectors.VAdd3(v0.p, Vectors.VScaled3(Vectors.VSub3(v2.p, v0.p), m));

						tempv1.pt := Matrix.Mul(trans, tempv1.p); ScreenPos(tempv1.pt, tempv1.x, tempv1.y);
					END;
					tempTri.vert[0] := tempv0; tempTri.vert[1] := tempv1; tempTri.vert[2] := v2; tempTri.tex := tri.tex;
					tempTri.color := tri.color; tempTri.transColor := tri.transColor;
					RasterTriangle(tempTri);
					tempTri.vert[0] := tempv0; tempTri.vert[1] := v1; tempTri.vert[2] := v2; tempTri.tex := tri.tex;
					tempTri.color := tri.color; tempTri.transColor := tri.transColor;
					RasterTriangle(tempTri);
				END;
			END
		END ClipDrawTriangle;

		PROCEDURE RenderInternal*(img : Raster.Image; animatedOnly:BOOLEAN);
		VAR i, j : LONGINT; obj : Object; huga : ANY; srcCopy:Raster.Mode;
		BEGIN
			Raster.InitMode(srcCopy, Raster.srcCopy);

			IF animatedOnly & worldValid THEN
				rasterizer.Restore;
				objects.Lock;
				FOR i := 0 TO objects.GetCount() - 1 DO
					huga := objects.GetItem(i); obj := huga(Object);
					IF obj.isAnimated THEN
						IF ~obj.bsValid THEN obj.CalcBS END;

						IF ~frustum.IsBSOutsideBehind(obj.bsCenter, obj.bsRadius) THEN
							rasterizer.SetObjectIndex(obj.index);
							FOR j := 0 TO obj.nofVertices - 1 DO
								obj.vertices[j].pt := Matrix.Mul(trans, obj.vertices[j].p);
								ScreenPos(obj.vertices[j].pt, obj.vertices[j].x, obj.vertices[j].y);
								obj.vertices[j].behind := W3dGeometry.Distance(frustum.nearP, obj.vertices[j].p) > 0;
							END;

							FOR j := 0 TO obj.nofTriangles - 1 DO ClipDrawTriangle(obj.triangles[j]) END
						END
					END
				END;
				objects.Unlock
			ELSE
				objects.Lock;
				rasterizer.SetInvertable(invertable); IF ~invertable THEN changed := TRUE ELSE changed := FALSE END;
				rasterizer.Clear(clearColor);
				FOR i := 0 TO objects.GetCount() - 1 DO
					huga := objects.GetItem(i); obj := huga(Object);

					IF ~obj.isAnimated THEN
						IF ~obj.bsValid THEN obj.CalcBS END;

						IF ~frustum.IsBSOutsideBehind(obj.bsCenter, obj.bsRadius) THEN
							rasterizer.SetObjectIndex(obj.index);
							FOR j := 0 TO obj.nofVertices - 1 DO
								obj.vertices[j].pt := Matrix.Mul(trans, obj.vertices[j].p);
								ScreenPos(obj.vertices[j].pt, obj.vertices[j].x, obj.vertices[j].y);
								obj.vertices[j].behind := W3dGeometry.Distance(frustum.nearP, obj.vertices[j].p) > 0;
							END;

							FOR j := 0 TO obj.nofTriangles - 1 DO ClipDrawTriangle(obj.triangles[j]) END
						END
					END
				END;
				rasterizer.SetInvertable(FALSE);
				rasterizer.Keep; worldValid := TRUE;
				FOR i := 0 TO objects.GetCount() - 1 DO
					huga := objects.GetItem(i); obj := huga(Object);

					IF obj.isAnimated THEN
						IF ~obj.bsValid THEN obj.CalcBS END;

						IF ~frustum.IsBSOutsideBehind(obj.bsCenter, obj.bsRadius) THEN
							rasterizer.SetObjectIndex(obj.index);
							FOR j := 0 TO obj.nofVertices - 1 DO
								obj.vertices[j].pt := Matrix.Mul(trans, obj.vertices[j].p);
								ScreenPos(obj.vertices[j].pt, obj.vertices[j].x, obj.vertices[j].y);
								obj.vertices[j].behind := W3dGeometry.Distance(frustum.nearP, obj.vertices[j].p) > 0;
							END;

							FOR j := 0 TO obj.nofTriangles - 1 DO ClipDrawTriangle(obj.triangles[j]) END
						END
					END
				END;
				objects.Unlock
			END;
			IF img # NIL THEN Raster.Copy(rasterizer.img, img, 0, 0, width, height, 0, 0, srcCopy) END;
		END RenderInternal;

		PROCEDURE Render*(img : Raster.Image; movingOnly : BOOLEAN);
		BEGIN {EXCLUSIVE}
			RenderInternal(img, movingOnly)
		END Render;

		PROCEDURE GetOwnerIndex*(x, y : LONGINT): LONGINT;
		BEGIN {EXCLUSIVE}
			IF ~changed THEN RETURN rasterizer.GetInvIdx(x, y) ELSE
				invertable := TRUE;
				RenderInternal(NIL, FALSE);
				invertable := FALSE;
				RETURN rasterizer.GetInvIdx(x, y)
			END
		END GetOwnerIndex;

	END World;

PROCEDURE Min(a, b: LONGREAL):LONGREAL;
BEGIN IF a < b THEN RETURN a ELSE RETURN b END
END Min;

PROCEDURE Max(a, b: LONGREAL):LONGREAL;
BEGIN IF a > b THEN RETURN a ELSE RETURN b END
END Max;

PROCEDURE GrowAABB(VAR aabb : AABB; p : Vectors.TVector3d);
BEGIN
	IF aabb.empty THEN
		aabb.a := p; aabb.b := p; aabb.empty := FALSE
	ELSE
		aabb.a.x := Min(aabb.a.x, p.x); aabb.a.y := Min(aabb.a.y, p.y); aabb.a.z := Min(aabb.a.z, p.z);
		aabb.b.x := Max(aabb.b.x, p.x); aabb.b.y := Max(aabb.b.y, p.y); aabb.b.z := Max(aabb.b.z, p.z)
	END
END GrowAABB;

END W3dWorld.
