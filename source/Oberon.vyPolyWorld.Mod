MODULE vyPolyWorld IN Oberon;
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

(*= 	Contents: a set of rendering routines for 3d objects
up to now only for surfaces
*)

(* 	history:
11.8.95 md 0.0d4	cleaned for alpha version
10.04.95 md 0.0d2	first rendering methods
26.1.95 md 0.0d1	cleaned
09.12.94 md 0.0d0	created *)

(*!	todo:
replace scanner stuff somewhere else
*)

IMPORT	Oberon, Math := MathL IN A2, Files,
	vyHostTexts,  vyBase,
	vyRealVec, vyGraphBase, Display, Out, Gadgets, Objects,
	vyHostDisplay := vyGraphBase, vyPort, vyPHIGS3D, vyPaint3d, SYSTEM, vyLongreal;

CONST
	idversion* = 	"vyPolyWorld v0r0d5";
	(* rendering ids *)
	wireFrameId* = 0;
	niveauLineId* = 1;
	backFaceColoringId* = 2;
	painterId* = 3;
	lightingId* = 4;
	smoothLightingId* = 5;
	hiddenLineId* = 6;
	niveauColoringId* = 7;

TYPE
	Real = vyBase.Real;
	(* the abstract ancestor of all supported 3d objects *)
	tObject* = POINTER TO tObjectDesc;
	tPlotRoutine = PROCEDURE (o3d: tObject);
	tObjectDesc* = RECORD
		plot*: tPlotRoutine
	END;

	(* special stuff for surfaces *)
	tVertex = POINTER TO tVertexDesc;
	tHalfEdge = POINTER TO tHalfEdgeDesc;
	tFace = POINTER TO tFaceDesc;

	tVertexDesc = RECORD
		i, j: SIGNED16;      		(* vertex coordinates in matrix indices *)
		between: BOOLEAN;      (* center point *)
		x, y, z: Real;      		(* vertex coordinates in VRS *)
		nx, ny, nz: Real;      	(* vertex coordinates in NPS *)
		(*visible: BOOLEAN;*)	(* to be deleted? *)
		next: tVertex
	END;

	tHalfEdgeDesc = RECORD
		startVertex: tVertex;
		leftNeighbor: tFace;
		visible: BOOLEAN;      	(* to be deleted? *)
		done: BOOLEAN;      	(* marker: already displayed *)
		next: tHalfEdge
	END;

	tFaceDesc = RECORD
		firstHalfEdge: tHalfEdge;
		nx, ny, nz: Real;      	(* normal vector of that face *)
		d: Real;      			(* the face: nx*x + ny*y + nz*z + d = 0 *)
		backFace: BOOLEAN;
		sx, sy, sz: Real;      	(* schwerpunkt der Fläche in RWS *)
		nsx, nsy, nsz: Real;      	(* schwerpunkt der Fläche in NPS *)
		region: SET;
		visible: BOOLEAN;      	(* to be deleted? *)
		pref, next: tFace
	END;

	(*for the display of a function, given by its values on a aquidistant grid*)
	tMap = POINTER TO tMapDesc;
	tMapDesc = RECORD (tObjectDesc)
		x0, y0, x1, y1: Real;
		mdata: vyRealVec.tChunkedMatrix;
		firstFace, lastFace: tFace;      	(* first element in this list is a dummy *)
		firstVertex: tVertex;      		(* first element in this list is a dummy *)
		vx, vy, vz: Real		(* the actual view direction - the vector N of the coordintes*)
	END;

	ColorMap* = ARRAY 256 OF SIGNED32;

VAR
	theHLHSRroutine: tPlotRoutine;
	PHIGS3DError: SIGNED16;
	lightDirX, lightDirY, lightDirZ: Real;      	(* light direction: this vector have to be normed to 1 *)
	maxFaces: SIGNED32;
	faceDepths: POINTER TO ARRAY OF FLOAT64;
	faceIndex: POINTER TO ARRAY OF SIGNED32;  (* POINTER ! *)
	triangulate: BOOLEAN;
	lines: BOOLEAN;
	colorTable*: ColorMap;
	(**  general help routines  *)

PROCEDURE StoreMap* (VAR R: Files.Rider;  lib: Objects.Library;  m: tMap);
	VAR id: SIGNED16;
BEGIN
	IF m = NIL THEN Files.WriteInt(R, - 1) ELSE Files.WriteInt(R, 0) END;
	GetRendering(m, id);   Files.WriteInt(R, id);
	Files.WriteLReal(R, m.x0);
	Files.WriteLReal(R, m.y0);
	Files.WriteLReal(R, m.x1);
	Files.WriteLReal(R, m.y1);
	Gadgets.WriteRef(R, lib, m.mdata);
	Files.WriteLReal(R, m.vx);
	Files.WriteLReal(R, m.vy);
	Files.WriteLReal(R, m.vz)
END StoreMap;

PROCEDURE LoadMap* (VAR R: Files.Rider;  lib: Objects.Library;  VAR m: tMap);
	VAR objsub: Objects.Object;  ver: SIGNED16;  id: SIGNED16;
BEGIN
	Files.ReadInt(R, ver);
	IF ver < 0 THEN m := NIL;  RETURN END;
	NEW(m);
	Files.ReadInt(R, id);  SetRendering(m, id);
	Files.ReadLReal(R, m.x0);
	Files.ReadLReal(R, m.y0);
	Files.ReadLReal(R, m.x1);
	Files.ReadLReal(R, m.y1);
	Gadgets.ReadRef(R, lib, objsub);
	IF objsub # NIL THEN m.mdata := objsub(vyRealVec.tChunkedMatrix) END;
	Files.ReadLReal(R, m.vx);
	Files.ReadLReal(R, m.vy);
	Files.ReadLReal(R, m.vz)
END LoadMap;

PROCEDURE LoadObj* (VAR R: Files.Rider;  lib: Objects.Library;  VAR m: tObject);
	VAR ver: SIGNED16;  map: tMap;
BEGIN
	Files.ReadInt(R, ver);
	IF ver < 0 THEN m := NIL;  RETURN END;
	LoadMap(R, lib, map);  m := map
END LoadObj;

PROCEDURE StoreObj* (VAR R: Files.Rider;  lib: Objects.Library;  VAR m: tObject);
BEGIN
	IF (m # NIL) & ( m IS tMap ) THEN Files.WriteInt(R, 0) ELSE Files.WriteInt(R, - 1);  RETURN END;
	StoreMap(R, lib, m(tMap))
END StoreObj;


(*

PROCEDURE WriteVertex0 (VAR R: Files.Rider; v: tVertex);
BEGIN
IF v = NIL THEN Files.WriteInt(R,-1); RETURN  ELSE Files.WriteInt(R,1) END;
Files.WriteInt(R,v.i);
Files.WriteInt(R,v.j);
Files.WriteLReal(R,v.x);
Files.WriteLReal(R,v.y);
Files.WriteLReal(R,v.z);
Files.WriteLReal(R,v.nx);
Files.WriteLReal(R,v.ny);
Files.WriteLReal(R,v.nz);
END WriteVertex0;

PROCEDURE ReadVertex0 (VAR R: Files.Rider; VAR v: tVertex);
VAR ver: SIGNED16;
BEGIN
Files.ReadInt(R,ver); IF ver < 0 THEN v := NIL; RETURN END;
NEW(v);
Files.ReadInt(R,v.i);
Files.ReadInt(R,v.j);
Files.ReadLReal(R,v.x);
Files.ReadLReal(R,v.y);
Files.ReadLReal(R,v.z);
Files.ReadLReal(R,v.nx);
Files.ReadLReal(R,v.ny);
Files.ReadLReal(R,v.nz);
END ReadVertex0;

PROCEDURE WriteVertex (VAR R: Files.Rider; v: tVertex);
BEGIN
WHILE(v#NIL) DO WriteVertex0(R,v); v := v.next END;
END WriteVertex;

PROCEDURE ReadVertex (VAR R: Files.Rider; VAR v: tVertex);
VAR o: tVertex;
BEGIN
ReadVertex(R,v);
IF v = NIL THEN RETURN END;
o := v;
ReadVertex(R,o.next);
WHILE(o.next # NIL) DO o := o.next; ReadVertex(R,o.next) END;
END ReadVertex;

*)


(** ------------  display surfaces during interactions (rotation) ------------ *)
PROCEDURE ReplOnTheFly (o3d: tObject);
	(*vs 0.0d0   md  12.12.94 14:55:52 *)
	VAR map: tMap;      m: vyRealVec.tMatrixChunk;      row, col, r, c, i, j: SIGNED32;      dx, dy, x, y, z: Real;
	t: SIGNED32;

PROCEDURE ReplRow (i: SIGNED32);
	(*vs 0.0d0   md  12.04.95 16:13:45 *)
BEGIN x := map.x0;
	y := i * dy / (row - 1) + map.y0;
	z := vyRealVec.ReadMatrix (m, i, 0);
	vyPaint3d.MoveTo (x, y, z);
	FOR j := 0 TO col - 1  DO
		x := j * dx / (col - 1) + map.x0;
		z := vyRealVec.ReadMatrix (m, i, j);
		vyPaint3d.LineTo (x, y, z)
	END
END ReplRow;

PROCEDURE ReplCol (j: SIGNED32);
	(*vs 0.0d0   md  12.04.95 16:13:09 *)
BEGIN x := j * dx / (col - 1) + map.x0;
	y := map.y0;
	z := vyRealVec.ReadMatrix (m, 0, j);
	vyPaint3d.MoveTo (x, y, z);
	FOR i := 0 TO row - 1  DO
		y := i * dy / (row - 1) + map.y0;
		z := vyRealVec.ReadMatrix (m, i, j);
		vyPaint3d.LineTo (x, y, z)
	END
END ReplCol;

BEGIN  t := Oberon.Time ();
	ASSERT (o3d IS tMap);      map := o3d(tMap);
	m := map.mdata.buf;      row := m.row;      col := m.col;      dx := map.x1 - map.x0;      dy := map.y1 - map.y0;
	FOR r := 0 TO row - 1  DO ReplRow (r) END;
	FOR c := 0 TO col - 1   DO ReplCol (c) END
END ReplOnTheFly;

(** ------------  wireframe plot ------------ *)
PROCEDURE WireFrameMapH (o3d: tObject);
	(*vs 0.0d0   md  12.12.94 14:55:52 *)
	VAR map: tMap;      m: vyRealVec.tMatrixChunk;      row, col, i, j: SIGNED32;      dx, dy, x, y, z: Real;
BEGIN ASSERT (o3d IS tMap);      map := o3d(tMap);
	m := map.mdata.buf;      row := m.row;      col := m.col;      dx := map.x1 - map.x0;      dy := map.y1 - map.y0;
	FOR i := 0 TO row - 1 DO
		x := map.x0;
		y := i * dy / (row - 1) + map.y0;
		z := vyRealVec.ReadMatrix (m, i, 0);
		vyPaint3d.MoveTo (x, y, z);
		FOR j := 0 TO col - 1 DO
			x := j * dx / (col - 1) + map.x0;
			z := vyRealVec.ReadMatrix (m, i, j);
			vyPaint3d.LineTo (x, y, z)
		END
	END
END WireFrameMapH;

PROCEDURE WireFrameMapV (o3d: tObject);
	(*vs 0.0d0   md  12.12.94 14:55:52 *)
	VAR map: tMap;      m: vyRealVec.tMatrixChunk;      row, col, i, j: SIGNED32;      dx, dy, x, y, z: Real;
BEGIN ASSERT (o3d IS tMap);      map := o3d(tMap);
	m := map.mdata.buf;      row := m.row;      col := m.col;      dx := map.x1 - map.x0;      dy := map.y1 - map.y0;
	FOR j := 0 TO col - 1 DO
		x := j * dx / (col - 1) + map.x0;
		y := map.y0;
		z := vyRealVec.ReadMatrix (m, 0, j);
		vyPaint3d.MoveTo (x, y, z);
		FOR i := 0 TO row - 1 DO
			y := i * dy / (row - 1) + map.y0;
			z := vyRealVec.ReadMatrix (m, i, j);
			vyPaint3d.LineTo (x, y, z)
		END
	END
END WireFrameMapV;

PROCEDURE WireFrameMap (o3d: tObject);
	(*vs 0.0d0   md  12.12.94 14:55:52 *)
BEGIN  IF vyPort.onTheFly THEN ReplOnTheFly (o3d);      RETURN END;
WireFrameMapH (o3d);      WireFrameMapV (o3d) END WireFrameMap;

(** ------------  mathematical support ------------ *)
PROCEDURE VectorProduct (x0, y0, z0, x1, y1, z1: Real;      VAR x, y, z: Real);
BEGIN x := y0 * z1 - z0 * y1;      y := z0 * x1 - x0 * z1;      z := x0 * y1 - y0 * x1 END VectorProduct;

PROCEDURE Norm (x, y, z: Real): Real;
BEGIN RETURN Math.sqrt (x * x + y * y + z * z) END Norm;

PROCEDURE FaceEquiation (f: tFace);
	(*= returns in f.nx, f.ny, f.nz and f.d the plane parameter of the face
	condition: f is plane! *)
	(* fof 020527: that is EXACTLY the problem, how could one ever guarantee f to be a plane ? in general it's not, we have to triangulate !!!! *)

	VAR v1, v2, v3: tVertex;
BEGIN v1 := f.firstHalfEdge.startVertex;
	v2 := f.firstHalfEdge.next.startVertex;
	v3 := f.firstHalfEdge.next.next.startVertex;
	f.nx := (v1.y - v2.y) * (v3.z - v2.z) - (v1.z - v2.z) * (v3.y - v2.y);
	f.ny := (v1.z - v2.z) * (v3.x - v2.x) - (v1.x - v2.x) * (v3.z - v2.z);
	f.nz := (v1.x - v2.x) * (v3.y - v2.y) - (v1.y - v2.y) * (v3.x - v2.x);
	f.d := - (f.nx * v1.x + f.ny * v1.y + f.nz * v1.z)
END FaceEquiation;

PROCEDURE GetFaceDepth (f: tFace): Real;
	(*= returns the depth (between 0 and 1) of the faces Schwerpunkt  *)
	VAR x, y, depth: Real;
BEGIN


	vyPHIGS3D.PointToViewPoint (f.sx, f.sy, f.sz, PHIGS3DError, x, y, depth);

	RETURN depth
END GetFaceDepth;

PROCEDURE PrefFaceConnection (m: tMap);
	VAR prefFace, face: tFace;
BEGIN prefFace := m.firstFace;      prefFace.pref := NIL;      face := prefFace.next;
	WHILE (face # NIL) DO
		face.pref := prefFace;
		prefFace := face;      face := face.next
	END;
	m.lastFace := prefFace
END PrefFaceConnection;

(** ------------  installation of a surface as a geometrical and topological object ------------ *)
PROCEDURE InstallHalfEdgeDesc (map: tMap;      update: BOOLEAN);
	(* *)
	VAR m: vyRealVec.tMatrixChunk;      row, col, i, j: SIGNED16;      dx, dy: Real;
	face, lastFace: tFace;      lastVertex: tVertex;     faces: SIGNED32; n: SIGNED32;

PROCEDURE UpdateSurface;
	(** vs 0.0d0 *)	(* md  28.08.95 16:29:38 *)
	VAR v: tVertex;      edge: tHalfEdge;      m: vyRealVec.tMatrixChunk;      sx, sy, sz: Real;
BEGIN m := map.mdata.buf;
	v := map.firstVertex.next;
	WHILE v # NIL DO
		IF v.between THEN
			v.z := vyRealVec.ReadMatrix (m, v.i, v.j) + vyRealVec.ReadMatrix (m, v.i - 1, v.j) + vyRealVec.ReadMatrix (m, v.i, v.j - 1) + vyRealVec.ReadMatrix(m, v.i - 1, v.j - 1);
			v.z := v.z / 4
		ELSE
			v.z := vyRealVec.ReadMatrix (m, v.i, v.j)
		END;
		v := v.next
	END;
	face := map.firstFace.next;
	WHILE face # NIL DO
		sx := 0;      sy := 0;      sz := 0;
		edge := face.firstHalfEdge; n := 0;
		WHILE edge # NIL DO
			sx := sx + edge.startVertex.x;
			sy := sy + edge.startVertex.y;
			sz := sz + edge.startVertex.z;
			INC(n);
			edge := edge.next
		END;
		face.sx := sx / n;      face.sy := sy / n;      face.sz := sz / n;
		face := face.next
	END
END UpdateSurface;


PROCEDURE NewFace (i, j: SIGNED16;      part: SIGNED16): tFace;
	VAR face: tFace;      sx, sy, sz: Real;         (* triangulating. fof 020527 *)

PROCEDURE NewHalfEdge (i, j, direction: SIGNED16): tHalfEdge;
	VAR edge: tHalfEdge;

PROCEDURE NewVertex (i, j: SIGNED16): tVertex;
	(*! region defintion *)
	VAR v: tVertex;
BEGIN
	NEW (v);
	v.i := i;      v.j := j;
	v.x := map.x0 + j * dx / (col - 1);
	v.y := map.y0 + i * dy / (row - 1);
	v.z := vyRealVec.ReadMatrix (m, i, j);
	v.next := NIL;      lastVertex.next := v;      lastVertex := v;
	v.between := FALSE;
	sx := sx + v.x;      sy := sy + v.y;      sz := sz + v.z;      	(* schwerpunkt *)
	RETURN v
END NewVertex;

PROCEDURE NewCenterVertex (i, j: SIGNED16): tVertex;
	VAR v: tVertex;
BEGIN
	NEW (v);
	v.i := i;      v.j := j;
	v.x := map.x0 + (j - 0.5) * dx / (col - 1);
	v.y := map.y0 + (i - 0.5) * dy / (row - 1);
	v.z := vyRealVec.ReadMatrix (m, i, j) + vyRealVec.ReadMatrix (m, i - 1, j) + vyRealVec.ReadMatrix (m, i, j - 1) + vyRealVec.ReadMatrix(m, i - 1, j - 1);
	v.z := v.z / 4;
	v.next := NIL;      lastVertex.next := v;      lastVertex := v;
	v.between := TRUE;
	sx := sx + v.x;      sy := sy + v.y;      sz := sz + v.z;      	(* schwerpunkt *)
	RETURN v

END NewCenterVertex;


BEGIN
	NEW (edge);
	IF direction = 1 THEN edge.startVertex := NewVertex (i - 1, j - 1)
	ELSIF direction = 2 THEN edge.startVertex := NewVertex (i, j - 1)
	ELSIF direction = 3 THEN edge.startVertex := NewVertex (i, j)
	ELSIF direction = 4 THEN edge.startVertex := NewVertex (i - 1, j)
	ELSIF direction = 5 THEN edge.startVertex := NewCenterVertex(i, j)
	END;
	edge.leftNeighbor := lastFace;
	RETURN edge
END NewHalfEdge;

BEGIN
	INC(faces);

	IF ~triangulate THEN

		NEW (face);   sx := 0;   sy := 0;   sz := 0;
		face.firstHalfEdge := NewHalfEdge (i, j, 1);
		face.firstHalfEdge.next := NewHalfEdge (i, j, 2);
		face.firstHalfEdge.next.next := NewHalfEdge (i, j, 3);
		face.firstHalfEdge.next.next.next := NewHalfEdge (i, j, 4);
		face.firstHalfEdge.next.next.next.next := NIL;
		face.sx := sx / 4;   face.sy := sy / 4;   face.sz := sz / 4;
		FaceEquiation (face);

		RETURN face

	ELSE

		NEW (face);      sx := 0;      sy := 0;      sz := 0;

		IF part = 1 THEN
			face.firstHalfEdge := NewHalfEdge (i, j, 1);
			face.firstHalfEdge.next := NewHalfEdge (i, j, 2);
			face.firstHalfEdge.next.next := NewHalfEdge (i, j, 5)
		ELSIF part = 2 THEN
			face.firstHalfEdge := NewHalfEdge (i, j, 2);
			face.firstHalfEdge.next := NewHalfEdge (i, j, 3);
			face.firstHalfEdge.next.next := NewHalfEdge (i, j, 5)
		ELSIF part = 3 THEN
			face.firstHalfEdge := NewHalfEdge (i, j, 3);
			face.firstHalfEdge.next := NewHalfEdge (i, j, 4);
			face.firstHalfEdge.next.next := NewHalfEdge (i, j, 5)
		ELSIF part = 4 THEN
			face.firstHalfEdge := NewHalfEdge (i, j, 4);
			face.firstHalfEdge.next := NewHalfEdge (i, j, 1);
			face.firstHalfEdge.next.next := NewHalfEdge (i, j, 5)
		END;
		face.sx := sx / 3;      face.sy := sy / 3;      face.sz := sz / 3;
		FaceEquiation (face);
		RETURN face

	END
END NewFace;

BEGIN
	IF ~update THEN
		faces := 0;
		m := map.mdata.buf;      row := SHORT(m.row);      col := SHORT(m.col);
		dx := map.x1 - map.x0;      dy := map.y1 - map.y0;
		NEW (lastVertex);      map.firstVertex := lastVertex;      						(* dummy *)
		NEW (lastFace);      lastFace.nsz := - 999;      map.firstFace := lastFace;      		(* dummy *)
		FOR i := 1 TO  row - 1  DO
			FOR j := 1 TO col - 1 DO
				IF ~triangulate THEN
					face := NewFace (i, j, 1);
					lastFace.next := face;   lastFace := face

				ELSE

					face := NewFace (i, j, 1);
					lastFace.next := face;      lastFace := face;
					face := NewFace (i, j, 2);
					lastFace.next := face;      lastFace := face;
					face := NewFace (i, j, 3);
					lastFace.next := face;      lastFace := face;
					face := NewFace (i, j, 4);
					lastFace.next := face;      lastFace := face

				END
			END      	(* FOR j :=1 TO  col-1 *)
		END;      	(* FOR i :=1 TO  row-1 *)
		lastFace.next := NIL;
		PrefFaceConnection (map);
		IF faces > maxFaces THEN maxFaces := faces END;
		NEW(faceDepths, maxFaces);  NEW(faceIndex, maxFaces)
	ELSE
		UpdateSurface
	END
END InstallHalfEdgeDesc;

(** ------------  general tMap help routines ------------ *)
PROCEDURE MapToViewMap (m: tMap);
	(*vs 0.0d0   md  10.04.95 12:51:05 *)
	(*= transform the real world system (RWS) coordinates in normal projection system (NPS) coordinates *)
	VAR v: tVertex;      f: tFace;
BEGIN PHIGS3DError := 0;      v := m.firstVertex.next;
	WHILE (v # NIL)  DO
		vyPHIGS3D.PointToViewPoint (v.x, v.y, v.z, PHIGS3DError, v.nx, v.ny, v.nz);
		v := v.next
	END;
	f := m.firstFace.next;
	WHILE (f # NIL) DO
		vyPHIGS3D.PointToViewPoint (f.sx, f.sy, f.sz, PHIGS3DError, f.nsx, f.nsy, f.nsz);
		FaceEquiation (f);
		f := f.next
	END;
	ASSERT (PHIGS3DError = 0)
END MapToViewMap;

PROCEDURE RegionSplitting (m: tMap);
	(*! not yet implemented *)
	(*VAR face: tFace; edge: tHalfEdge; v: tVertex;*)
(*
BEGIN
	face := map.firstFace.next;
	WHILE face#NIL DO
	edge := face.firstHalfEdge;
	WHILE edge#NIL DO edge.visible := TRUE; edge := edge.next;  END;
	face := face.next;
	END;
	*)
END RegionSplitting;

PROCEDURE BackFaceIdentification (m: tMap);
	(*vs 0.0d0   md  07.04.95 10:03:39 *)
	VAR face: tFace;      vx, vy, vz: Real;
BEGIN
	vyPHIGS3D.GetViewDirection (vx, vy, vz);
	(*IF (! view has changed ) THEN
	vyHostTexts.Note (vyHostTexts.cAlert, "no BackFaceIdentification   "); RETURN END;*)
	m.vx := vx;      m.vy := vy;      m.vz := vz;
	face := m.firstFace.next;
	WHILE face # NIL DO
		face.backFace := (vx * face.nx + vy * face.ny + vz * face.nz + face.d + 0.01  < 0);
		face := face.next
	END
END BackFaceIdentification;

PROCEDURE SortFaces (m: tMap);
	(*! optimieren *)
	VAR face: tFace;     faces: SIGNED32;      count, i: SIGNED32;
BEGIN

	face := m.firstFace.next;  count := 0;
	WHILE(face # NIL) DO
		(* SYSTEM.GET((face), *)
		faceIndex[count] := SYSTEM.VAL(SIGNED32, face);
		faceDepths[count] :=  GetFaceDepth (face);
		face := face.next;  INC(count)
	END;

	vyLongreal.SortIndexed(count, faceDepths^, 0, faceIndex^);

	i := 0;  face := m.firstFace;
	WHILE(i < count) DO
		face.next := SYSTEM.VAL(tFace, faceIndex[i]);
		face := face.next;
		INC(i)
	END;
	face.next := NIL;

	face := m.firstFace.next;  count := 0;
	WHILE(face # NIL) DO
		face := face.next;  INC(count)
	END;
	Out.Ln;  Out.String("faces after system sort");  Out.Int(count, 10);
	(*

	prevFace := m.firstFace;     face := prevFace.next;
	faces := 0;
	Out.Ln;     Out.String("before SORT");
	(* Out.Ln;    Out.LongReal(GetFaceDepth (m.firstFace),20);  *)
	faceDepth := MIN(FLOAT64);
	WHILE (face # NIL)  DO
	INC(faces);

	lastfaceD := faceDepth;
	faceDepth := GetFaceDepth (face);
	(* Out.Ln;    Out.LongReal(faceDepth,20);    *)

	IF   lastfaceD > faceDepth  THEN

	slideFace := m.firstFace;
	WHILE ((slideFace.next # NIL) & (slideFace.next # face) & (GetFaceDepth (slideFace.next) < faceDepth))  DO
	slideFace := slideFace.next;
	END;

	IF (slideFace.next # NIL) & (slideFace.next # face) THEN
	prevFace.next := face.next;
	face.next := slideFace.next;
	slideFace.next := face;
	face := prevFace.next;
	ELSE
	prevFace := prevFace.next;     face := face.next;
	END;
	faceDepth := lastfaceD;
	ELSE
	prevFace := prevFace.next;     face := face.next;
	END;

	END;     	(* WHILE (face#NIL) *)
	*)

	PrefFaceConnection (m);



	Out.Ln;      Out.String("faces:");      Out.Int(faces, 10);
	Out.Ln;      Out.String("after SORT")
	(*
	faces := 0;
	face := m.firstFace.next;
	faceDepth := MIN(FLOAT64);
	WHILE (face # NIL)  DO
	INC(faces);
	lastfaceD := faceDepth;
	faceDepth := GetFaceDepth (face);
	IF lastfaceD > faceDepth THEN Out.Ln;  Out.String("faceDepth error");  END;
	face := face.next;
	(* Out.Ln;    Out.LongReal(faceDepth,20);    *)
	END;
	Out.Ln;     Out.String("faces:");     Out.Int(faces,10);
	*)
END SortFaces;

(**
PROCEDURE SortFaces (m: tMap);
(*! optimieren *)
TYPE

faceList = POINTER TO faceListDesc;
faceListDesc = RECORD
this: tFace;
next: faceList;
END;

VAR prevFace, face, slideFace: tFace; faceDepth: Real; faces: SIGNED32;
faceList,current: faceList;
BEGIN
NEW(faceList);
current := faceList;
face := m.firstFace.next;
WHILE (face # NIL)  DO
NEW(current.next);
current := current.next;
current.face := face;
face := face.next;
END;


prevFace := m.firstFace; face := prevFace.next;
faces := 0;
Out.Ln; Out.String("before SORT");
Out.Ln; Out.LongReal(GetFaceDepth (m.firstFace),20);
current := faceList.next;
WHILE (current # NIL)  DO
face := current.face;
INC(faces);
faceDepth := GetFaceDepth (face);
Out.Ln; Out.LongReal(faceDepth,20);

slideFace := m.firstFace;
WHILE ((slideFace.next # NIL) & (GetFaceDepth (slideFace.next) < faceDepth))  DO
slideFace := slideFace.next;
END; 	(* WHILE ((slideFace.next#NIL) & (sfd<fd)) *)
IF (slideFace.next # NIL) & (slideFace.next # face) THEN
prevFace.next := face.next;
face.next := slideFace.next;
slideFace.next := face;
face := prevFace.next;
ELSE
prevFace := prevFace.next; (* face := face.next;
END;
END; 	(* WHILE (face#NIL) *)
PrefFaceConnection (m);

Out.Ln; Out.String("faces:"); Out.Int(faces,10);
Out.Ln; Out.String("after SORT");
faces := 0;
face := m.firstFace;
WHILE (face # NIL)  DO
INC(faces);
faceDepth := GetFaceDepth (face);
face := face.next;
Out.Ln; Out.LongReal(faceDepth,20);
END;
Out.Ln; Out.String("faces:"); Out.Int(faces,10);

END SortFaces;
*)  *)

PROCEDURE ResetFaceVisibleMarker (m: tMap);
	VAR face: tFace;
BEGIN face := m.firstFace.next;
	WHILE face # NIL DO face.visible := TRUE;     face := face.next END
END ResetFaceVisibleMarker;

PROCEDURE ResetDoneMarker (m: tMap);
	VAR  face: tFace;     edge: tHalfEdge;
BEGIN face := m.firstFace.next;
	WHILE face # NIL DO
		edge := face.firstHalfEdge;
		WHILE edge # NIL DO edge.done := FALSE;     edge := edge.next      END;
		face := face.next
	END
END ResetDoneMarker;

PROCEDURE VertexCoverByFace (v: tVertex;     f: tFace): BOOLEAN;
	VAR xmax, ymax, r: Real;     e: tHalfEdge;
BEGIN
	xmax := 0;     ymax := 0;
	e := f.firstHalfEdge;
	WHILE e # NIL DO
		r := ABS(e.startVertex.nx - f.nsx);     IF r > xmax THEN xmax := r END;
		r := ABS(e.startVertex.ny - f.nsy);     IF r > ymax THEN ymax := r END;
		e := e.next
	END;

	IF (ABS(v.nx - f.nsx) >  xmax) OR (ABS(v.ny - f.nsy) > ymax) THEN RETURN FALSE END;

	RETURN TRUE
END VertexCoverByFace;

(** ------------  niveau line plot ------------ *)
PROCEDURE NiveauLineMap (o3d: tObject);
	(*! not yet implemented *)
	VAR self: tMap;
BEGIN
	self := o3d(tMap);
	vyHostTexts.Note (vyHostTexts.cAlert, "niveau lines: not yet implemented - switch to wireframe plot");
	theHLHSRroutine := WireFrameMap;
	self.plot := theHLHSRroutine;
	self.plot (self)
END NiveauLineMap;

(** ------------  hidden line plot ------------ *)
PROCEDURE HiddenLineIdent (map: tMap);
	(*vs 0.0d0   md  10.04.95 12:26:56 *)
	VAR  face, potCover: tFace;     edge: tHalfEdge;

	(*PROCEDURE VIsCovered (): BOOLEAN;
	VAR
	BEGIN
	END VIsCovered; *)

PROCEDURE FaceIsCovered (): BOOLEAN;
	(*vs 0.0d0   md  10.04.95 14:51:45 *)
	VAR e: tHalfEdge;
BEGIN
	e := face.firstHalfEdge;
	WHILE (e # NIL) & ~(e.visible) DO e := e.next END;
	RETURN (e = NIL)
END FaceIsCovered;

BEGIN
	ResetFaceVisibleMarker (map);
	RegionSplitting (map);
	face := map.lastFace;
	WHILE face # map.firstFace.next DO
		edge := face.firstHalfEdge;
		WHILE edge # NIL DO
			potCover := map.firstFace;
			WHILE (face.visible) & (potCover # face) & (potCover # NIL) DO
				IF (potCover.region = face.region) & (potCover.visible) THEN
					IF VertexCoverByFace (edge.startVertex, potCover) THEN
						edge.visible := FALSE;     face.visible := FaceIsCovered ()
					ELSE edge.visible := TRUE
					END
				END;
				potCover := potCover.next
			END;     	(* (face.visible) & (potCover#NIL) & (potCover#face) *)
			edge := edge.next
		END;     	(* WHILE edge#NIL *)
		face := face.pref
	END     	(* WHILE face#NIL *)
END HiddenLineIdent;

PROCEDURE ReplHiddenLine (map: tMap);
	(*vs 0.0d0   md  10.04.95 12:28:33 *)
	VAR  face: tFace;     edge: tHalfEdge;     sv, v: tVertex;
BEGIN ResetDoneMarker (map);
	face := map.firstFace.next;
	WHILE face # NIL DO
		IF face.backFace THEN vyHostDisplay.SetForeColor (4) ELSE vyHostDisplay.SetForeColor (1) END;
		edge := face.firstHalfEdge;     sv := edge.startVertex;     vyPaint3d.MoveTo (sv.x, sv.y, sv.z);
		edge := edge.next;
		WHILE edge # NIL DO
			v := edge.startVertex;
			IF edge.visible & ~edge.done THEN vyPaint3d.LineTo (v.x, v.y, v.z);     edge.done := TRUE
			ELSE vyPaint3d.MoveTo (v.x, v.y, v.z) END;
			edge := edge.next
		END;
		IF face.firstHalfEdge.visible & ~face.firstHalfEdge.done THEN vyPaint3d.LineTo (sv.x, sv.y, sv.z) END;
		face := face.next
	END
END ReplHiddenLine;

PROCEDURE HiddenLineMap (o3d: tObject);
	(*vs 0.0d0   md  12.12.94 15:26:48 *)
	VAR self: tMap;     sort: BOOLEAN;     t0, t1: SIGNED32;

BEGIN IF vyPort.onTheFly THEN WireFrameMap (o3d);     RETURN END;
	self := o3d(tMap);     sort := FALSE;
	IF self.firstFace = NIL THEN
		t0 := Oberon.Time ();     InstallHalfEdgeDesc (self, FALSE);     t1 := Oberon.Time ();
		vyHostTexts.NoteSI (vyHostTexts.cAlert, "InstallHalfEdgeDesc:   ", t1 - t0);
		sort := TRUE
	ELSE
		t0 := Oberon.Time ();     InstallHalfEdgeDesc (self, TRUE);     t1 := Oberon.Time ();
		vyHostTexts.NoteSI (vyHostTexts.cAlert, "InstallHalfEdgeDesc:   ", t1 - t0)
	END;

	t0 := Oberon.Time ();     BackFaceIdentification (self);     t1 := Oberon.Time ();
	vyHostTexts.NoteSI (vyHostTexts.cAlert, "BackFaceIdentification:   ", t1 - t0);

	IF sort THEN
		t0 := Oberon.Time ();     SortFaces (self);     t1 := Oberon.Time ();
		vyHostTexts.NoteSI (vyHostTexts.cAlert, "SortFaces:   ", t1 - t0)
	END;

	t0 := Oberon.Time ();     HiddenLineIdent (self);     t1 := Oberon.Time ();
	vyHostTexts.NoteSI (vyHostTexts.cAlert, "HiddenLineIdentification:   ", t1 - t0);

	t0 := Oberon.Time ();     ReplHiddenLine (self);     t1 := Oberon.Time ();
	vyHostTexts.NoteSI (vyHostTexts.cAlert, "ReplHiddenLine:   ", t1 - t0)

END HiddenLineMap;

(** ------------  the painters algorithm ------------ *)
PROCEDURE ReplPainter (map: tMap);
	(*vs 0.0d0   md  10.04.95 12:28:33 *)
	VAR  face: tFace;     x, y: ARRAY 10 OF Real;     i: SIGNED16;     he: tHalfEdge;

BEGIN ResetDoneMarker (map);
	face := map.lastFace;
	WHILE face # map.firstFace DO
		he := face.firstHalfEdge;     i := 0;
		WHILE he # NIL DO x[i] := he.startVertex.nx;     y[i] := he.startVertex.ny;     INC (i);     he := he.next END;
		IF FALSE (* face.backFace *)THEN vyHostDisplay.SetForeColor (Display.RGB(100, 100, 100)) ELSE
			vyHostDisplay.SetForeColor (colorTable[128])
		END;
		(* fof disabled backFace *)
		IF triangulate THEN

			vyGraphBase.PaintFillArea2d (x, y, 3);
			(*
			vyHostDisplay.SetForeColor (15);
			vyGraphBase.FrameFillArea2d (x, y, 3);
			*)
			vyHostDisplay.SetForeColor (15);
			vyGraphBase.Line2d(x[0], y[0], x[1], y[1]);
			face := face.pref
		ELSE

			vyGraphBase.PaintFillArea2d (x, y, 4);
			vyHostDisplay.SetForeColor (15);
			vyGraphBase.FrameFillArea2d (x, y, 4);
			face := face.pref;     (*Pause*)
		END
	END
END ReplPainter;

PROCEDURE PainterMap (o3d: tObject);
	(*vs 0.0d0   md  12.12.94 15:26:48 *)
	VAR self: tMap;     sort: BOOLEAN;     t0, t1: SIGNED32; lightingMap: tPlotRoutine;

BEGIN IF vyPort.onTheFly THEN ReplOnTheFly (o3d);     RETURN END;
	self := o3d(tMap);     sort := FALSE;
	lightingMap := LightingMap;
	IF ((self.mdata.buf.row) > 512) OR ((self.mdata.buf.col) > 512) THEN WireFrameMap(o3d);  RETURN
	ELSIF ((self.mdata.buf.row) > 32) OR ((self.mdata.buf.col) > 32)  THEN triangulate := FALSE
	ELSIF (self.plot = lightingMap) THEN  triangulate := TRUE
	ELSE triangulate := FALSE
	END;

	IF self.firstFace = NIL THEN
		t0 := Oberon.Time ();     InstallHalfEdgeDesc (self, FALSE);     t1 := Oberon.Time ();
		vyHostTexts.NoteSI (vyHostTexts.cAlert, "InstallHalfEdgeDesc:   ", t1 - t0);
		sort := TRUE
	ELSE
		t0 := Oberon.Time ();     InstallHalfEdgeDesc (self, TRUE);     t1 := Oberon.Time ();
		vyHostTexts.NoteSI (vyHostTexts.cAlert, "InstallHalfEdgeDesc:   ", t1 - t0)
	END;

	t0 := Oberon.Time ();     MapToViewMap (self);     t1 := Oberon.Time ();
	vyHostTexts.NoteSI (vyHostTexts.cAlert, "MapToViewMap:   ", t1 - t0);

	t0 := Oberon.Time ();     BackFaceIdentification (self);     t1 := Oberon.Time ();
	vyHostTexts.NoteSI (vyHostTexts.cAlert, "BackFaceIdentification:   ", t1 - t0);

	t0 := Oberon.Time ();     SortFaces (self);     t1 := Oberon.Time ();
	vyHostTexts.NoteSI (vyHostTexts.cAlert, "SortFaces:   ", t1 - t0);

	t0 := Oberon.Time ();     ReplPainter (self);     t1 := Oberon.Time ();
	vyHostTexts.NoteSI (vyHostTexts.cAlert, "ReplPainter:   ", t1 - t0)

END PainterMap;

(** ------------  painters ligthning plot ------------ *)
PROCEDURE SetLightDirection* (x, y, z: Real);
	(*vs 0.0d0   md  14.08.95 19:22:39 *)
	VAR n: Real;
BEGIN n := Norm (x, y, z);
	lightDirX := x / n;     lightDirY := y / n;     lightDirZ := z / n
END SetLightDirection;

PROCEDURE SetFaceColor (nx, ny, nz: Real);
	VAR a: Real;     col: SIGNED32;     vx, vy, vz: FLOAT64;
BEGIN
	vx :=  lightDirX;     vy := lightDirY;     vz := lightDirZ;
	a := (nx * lightDirX + ny * lightDirY + nz * lightDirZ) / (Norm (nx, ny, nz)) + 1;
	a := a / 2;
	col := SHORT(ENTIER(a * 255 + 0.5));
	IF a < 0 THEN vyHostDisplay.SetForeColor (colorTable[0])
	ELSE (* vyHostDisplay.SetForeColor (13-SHORT (ENTIER (a*9+0.5))); *)
		vyHostDisplay.SetForeColor(colorTable[col]);
		(*
		vyHostDisplay.SetForeColor(SHORT(ENTIER((vyHostDisplay.mincol + (vyHostDisplay.maxcol - vyHostDisplay.mincol) * a))) )
		*)
	END;
END SetFaceColor;

PROCEDURE ReplLighting (map: tMap);
	(*vs 0.0d0   md  10.04.95 12:28:33 *)
	VAR  face: tFace;     x, y: ARRAY 10 OF Real;     i: SIGNED16;     he: tHalfEdge;

BEGIN

	ResetDoneMarker (map);
	face := map.lastFace;
	WHILE face # map.firstFace DO
		he := face.firstHalfEdge;     i := 0;
		WHILE he # NIL DO x[i] := he.startVertex.nx;     y[i] := he.startVertex.ny;     INC (i);     he := he.next END;
		IF FALSE (* face.backFace*)THEN vyHostDisplay.SetForeColor (2) ELSE  SetFaceColor (face.nx, face.ny, face.nz);     END;
		IF ~ face.backFace THEN
			IF triangulate THEN

				vyGraphBase.PaintFillArea2d (x, y, 3);
				(*
				vyHostDisplay.SetForeColor (15);
				vyGraphBase.FrameFillArea2d (x, y, 3);
				*)
				vyHostDisplay.SetForeColor (15);
				IF lines THEN
				vyGraphBase.Line2d(x[0], y[0], x[1], y[1]);
				END;
			ELSE

				vyGraphBase.PaintFillArea2d (x, y, 4);

				vyHostDisplay.SetForeColor (15);
				IF lines THEN
				vyGraphBase.FrameFillArea2d (x, y, 4);
				END;
			END;
		END;

		face := face.pref

	END;
END ReplLighting;

PROCEDURE LightingMap (o3d: tObject);
	(*vs 0.0d0   md  12.12.94 15:26:48 *)
	VAR self: tMap;     sort: BOOLEAN;     t0, t1: SIGNED32;

BEGIN IF vyPort.onTheFly THEN ReplOnTheFly (o3d);     RETURN END;
	self := o3d(tMap);     sort := FALSE;

	IF ((self.mdata.buf.row) > 512) OR ((self.mdata.buf.col) > 512) THEN WireFrameMap(o3d);  RETURN
	ELSIF ((self.mdata.buf.row) > 32) OR ((self.mdata.buf.col) > 32)  THEN triangulate := FALSE;
	ELSE triangulate := TRUE
	END;

	IF self.firstFace = NIL THEN
		t0 := Oberon.Time ();     InstallHalfEdgeDesc (self, FALSE);     t1 := Oberon.Time ();
		vyHostTexts.NoteSI (vyHostTexts.cAlert, "InstallHalfEdgeDesc:   ", t1 - t0);
		sort := TRUE
	ELSE
		t0 := Oberon.Time ();     InstallHalfEdgeDesc (self, TRUE);     t1 := Oberon.Time ();
		vyHostTexts.NoteSI (vyHostTexts.cAlert, "InstallHalfEdgeDesc:   ", t1 - t0);
	END;

	t0 := Oberon.Time ();     MapToViewMap (self);     t1 := Oberon.Time ();
	vyHostTexts.NoteSI (vyHostTexts.cAlert, "MapToViewMap:   ", t1 - t0);

	t0 := Oberon.Time ();     BackFaceIdentification (self);     t1 := Oberon.Time ();
	vyHostTexts.NoteSI (vyHostTexts.cAlert, "BackFaceIdentification:   ", t1 - t0);

	t0 := Oberon.Time ();     SortFaces (self);     t1 := Oberon.Time ();
	vyHostTexts.NoteSI (vyHostTexts.cAlert, "SortFaces:   ", t1 - t0);

	t0 := Oberon.Time ();     ReplLighting (self);     t1 := Oberon.Time ();
	vyHostTexts.NoteSI (vyHostTexts.cAlert, "ReplLighting:   ", t1 - t0);

END LightingMap;

(** ------------  painters smooth ligthing plot ------------ *)
PROCEDURE ReplSmoothLighting (map: tMap);
	(*vs 0.0d0   md  10.04.95 12:28:33 *)
	VAR  face: tFace;     xa, ya: ARRAY 10 OF Real;     i: SIGNED16;     he: tHalfEdge;

PROCEDURE PaintFace (f: tFace);
	(*vs 0.0d0   md  19.04.95 09:28:22 *)
	VAR done: BOOLEAN;     x0, y0, z0, x1, y1, z1, x, y, z: Real;
BEGIN
	he := face.firstHalfEdge;     done := FALSE;
	WHILE ~done DO
		i := 0;
		xa[i] := he.startVertex.nx;     ya[i] := he.startVertex.ny;
		x0 := he.startVertex.x;     y0 := he.startVertex.y;     z0 := he.startVertex.z;
		INC (i);

		xa[i] := face.nsx;     ya[i] := face.nsy;     INC (i);

		he := he.next;     IF he = NIL THEN he := face.firstHalfEdge;     done := TRUE END;
		xa[i] := he.startVertex.nx;     ya[i] := he.startVertex.ny;
		x1 := he.startVertex.x;     y1 := he.startVertex.y;     z1 := he.startVertex.z;
		INC (i);

		(*
		IF face.backFace THEN vyHostDisplay.SetForeColor (2) (* bullshit, since rectangle can't know about hidden or not *)
		ELSE
		*)

		x := face.sx;     y := face.sy;     z := face.sz;
		VectorProduct (x - x0, y - y0, z - z0, x - x1, y - y1, z - z1, x, y, z);
		SetFaceColor (- x, - y, - z);

		(*
		END;
		*)

		vyGraphBase.PaintFillArea2d (xa, ya, i);
	END;
END PaintFace;

PROCEDURE FrameFace (f: tFace);
	(*vs 0.0d0   md  19.04.95 09:28:37 *)
BEGIN
	he := face.firstHalfEdge;     i := 0;
	WHILE he # NIL DO xa[i] := he.startVertex.nx;     ya[i] := he.startVertex.ny;     INC (i);     he := he.next END;
	vyHostDisplay.SetForeColor (15);     vyGraphBase.FrameFillArea2d (xa, ya, i);
END FrameFace;

BEGIN ResetDoneMarker (map);
	face := map.lastFace;
	WHILE face # map.firstFace DO
		PaintFace (face);
		IF lines THEN FrameFace (face);
		END;
		face := face.pref
	END;
END ReplSmoothLighting;


PROCEDURE SmoothLightingMap (o3d: tObject);
	(*vs 0.0d0   md  12.12.94 15:26:48 *)
	VAR self: tMap;     sort: BOOLEAN;     t0, t1: SIGNED32;

BEGIN IF vyPort.onTheFly THEN ReplOnTheFly (o3d);     RETURN END;
	self := o3d(tMap);     sort := FALSE;
	IF self.firstFace = NIL THEN
		t0 := Oberon.Time ();     InstallHalfEdgeDesc (self, FALSE);     t1 := Oberon.Time ();
		vyHostTexts.NoteSI (vyHostTexts.cAlert, "InstallHalfEdgeDesc:   ", t1 - t0);
		sort := TRUE
	ELSE
		t0 := Oberon.Time ();     InstallHalfEdgeDesc (self, TRUE);     t1 := Oberon.Time ();
		vyHostTexts.NoteSI (vyHostTexts.cAlert, "InstallHalfEdgeDesc:   ", t1 - t0);
	END;

	t0 := Oberon.Time ();     MapToViewMap (self);     t1 := Oberon.Time ();
	vyHostTexts.NoteSI (vyHostTexts.cAlert, "MapToViewMap:   ", t1 - t0);

	t0 := Oberon.Time ();     BackFaceIdentification (self);     t1 := Oberon.Time ();
	vyHostTexts.NoteSI (vyHostTexts.cAlert, "BackFaceIdentification:   ", t1 - t0);

	t0 := Oberon.Time ();     SortFaces (self);     t1 := Oberon.Time ();
	vyHostTexts.NoteSI (vyHostTexts.cAlert, "SortFaces:   ", t1 - t0);

	t0 := Oberon.Time ();     ReplSmoothLighting (self);     t1 := Oberon.Time ();
	vyHostTexts.NoteSI (vyHostTexts.cAlert, "ReplSmoothLighting:   ", t1 - t0);

END SmoothLightingMap;

(** ------------  niveau coloring plot ------------ *)
PROCEDURE SetFaceNiveauColor (face: tFace;     min, max: Real);
	VAR r: Real;    col: SIGNED32;
BEGIN r := (face.sz - min) / (max - min);
	col := ENTIER(255 * r + 0.5);
	(*vyHostTexts.MsgSRSR("r ",r,"col ",col); *)
	IF col < 0 THEN col := 0 ELSIF col > 255 THEN col := 255 END;
	vyHostDisplay.SetForeColor(colorTable[col]);
	(* vyHostDisplay.SetForeColor (14-SHORT (ENTIER (r*10+0.5))); *)
	(*
	vyHostDisplay.SetForeColor (SHORT(ENTIER(vyHostDisplay.mincol + (vyHostDisplay.maxcol - vyHostDisplay.mincol) * r)));
	*)
END SetFaceNiveauColor;

PROCEDURE ReplNiveauColoring (map: tMap);
	(*vs 0.0d0   md  10.04.95 12:28:33 *)
	VAR  face: tFace;     x, y: ARRAY 10 OF Real;     i: SIGNED16;     he: tHalfEdge;
	m: vyRealVec.tMatrixChunk;     row, col, k, l: SIGNED32;     r, min, max: Real;
BEGIN ResetDoneMarker (map);
	face := map.lastFace;
	m := map.mdata.buf;     row := m.row;     col := m.col;
	min := vyRealVec.ReadMatrix (m, 0, 0);     max := vyRealVec.ReadMatrix (m, 0, 0);
	FOR k := 0 TO row - 1 DO
		FOR l := 0 TO col - 1 DO
			r := vyRealVec.ReadMatrix (m, k, l);
			IF r < min THEN min := r END;
			IF r > max THEN max := r END;
		END;
	END;
	WHILE face # map.firstFace DO
		he := face.firstHalfEdge;     i := 0;
		WHILE he # NIL DO x[i] := he.startVertex.nx;     y[i] := he.startVertex.ny;     INC (i);     he := he.next END;
		IF  FALSE (* face.backFace *)THEN vyHostDisplay.SetForeColor (2) ELSE SetFaceNiveauColor (face, min, max) END;     (* fof disabled back faces*)
		IF ~triangulate THEN
			vyGraphBase.PaintFillArea2d (x, y, 4);
			vyHostDisplay.SetForeColor (15);
			IF lines THEN
			vyGraphBase.FrameFillArea2d (x, y, 4);
			END;
		ELSE
			vyGraphBase.PaintFillArea2d (x, y, 3);
			vyHostDisplay.SetForeColor (15);
			(*vyGraphBase.FrameFillArea2d (x, y, 3);*)
			IF lines THEN
			vyGraphBase.Line2d(x[0], y[0], x[1], y[1]);
			END;

		END;
		face := face.pref;     (*Pause*)
	END;
END ReplNiveauColoring;

PROCEDURE NiveauColoringMap (o3d: tObject);
	(*vs 0.0d0   md  12.12.94 15:26:48 *)
	VAR self: tMap;     sort: BOOLEAN;     t0, t1: SIGNED32;

BEGIN IF vyPort.onTheFly THEN ReplOnTheFly (o3d);     RETURN END;
	self := o3d(tMap);     sort := FALSE;

	IF ((self.mdata.buf.row) > 512) OR ((self.mdata.buf.col) >512) THEN WireFrameMap(o3d);  RETURN
	ELSIF ((self.mdata.buf.row) > 32) OR ((self.mdata.buf.col) > 32)  THEN triangulate := FALSE;
	ELSE triangulate := TRUE
	END;

	IF self.firstFace = NIL THEN
		t0 := Oberon.Time ();     InstallHalfEdgeDesc (self, FALSE);     t1 := Oberon.Time ();
		vyHostTexts.NoteSI (vyHostTexts.cAlert, "InstallHalfEdgeDesc:   ", t1 - t0);
		sort := TRUE
	ELSE
		t0 := Oberon.Time ();     InstallHalfEdgeDesc (self, TRUE);     t1 := Oberon.Time ();
		vyHostTexts.NoteSI (vyHostTexts.cAlert, "InstallHalfEdgeDesc:   ", t1 - t0);
	END;

	t0 := Oberon.Time ();     MapToViewMap (self);     t1 := Oberon.Time ();
	vyHostTexts.NoteSI (vyHostTexts.cAlert, "MapToViewMap:   ", t1 - t0);

	t0 := Oberon.Time ();     BackFaceIdentification (self);     t1 := Oberon.Time ();
	vyHostTexts.NoteSI (vyHostTexts.cAlert, "BackFaceIdentification:   ", t1 - t0);

	t0 := Oberon.Time ();     SortFaces (self);     t1 := Oberon.Time ();
	vyHostTexts.NoteSI (vyHostTexts.cAlert, "SortFaces:   ", t1 - t0);

	t0 := Oberon.Time ();     ReplNiveauColoring (self);     t1 := Oberon.Time ();
	vyHostTexts.NoteSI (vyHostTexts.cAlert, "ReplLighting:   ", t1 - t0);

END NiveauColoringMap;

(** ------------  backface coloring plot ------------ *)
PROCEDURE ReplBackFaceColoring (map: tMap);
	(*vs 0.0d0   md  10.04.95 12:28:33 *)
	VAR  face: tFace;     edge: tHalfEdge;     sv, v: tVertex;

BEGIN ResetDoneMarker (map);
	face := map.firstFace.next;
	WHILE face # NIL DO
		IF face.backFace THEN vyHostDisplay.SetForeColor (1) ELSE vyHostDisplay.SetForeColor (15) END;
		edge := face.firstHalfEdge;     sv := edge.startVertex;     vyPaint3d.MoveTo (sv.x, sv.y, sv.z);
		edge := edge.next;
		WHILE edge # NIL DO
			v := edge.startVertex;
			IF ~edge.done THEN vyPaint3d.LineTo (v.x, v.y, v.z);     edge.done := TRUE
			ELSE vyPaint3d.MoveTo (v.x, v.y, v.z) END;
			edge := edge.next;
		END;
		IF ~face.firstHalfEdge.done THEN vyPaint3d.LineTo (sv.x, sv.y, sv.z) END;
		face := face.next;
	END;
END ReplBackFaceColoring;

PROCEDURE BackFaceColoringMap (o3d: tObject);
	(*vs 0.0d0   md  12.12.94 15:26:48 *)
	VAR self: tMap;     t0, t1: SIGNED32;

BEGIN IF vyPort.onTheFly THEN WireFrameMap (o3d);     RETURN END;
	self := o3d(tMap);
	IF self.firstFace = NIL THEN
		t0 := Oberon.Time ();     InstallHalfEdgeDesc (self, FALSE);     t1 := Oberon.Time ();
		vyHostTexts.NoteSI (vyHostTexts.cAlert, "InstallHalfEdgeDesc:   ", t1 - t0);
	ELSE
		t0 := Oberon.Time ();     InstallHalfEdgeDesc (self, TRUE);     t1 := Oberon.Time ();
		vyHostTexts.NoteSI (vyHostTexts.cAlert, "InstallHalfEdgeDesc:   ", t1 - t0);
	END;

	t0 := Oberon.Time ();     BackFaceIdentification (self);     t1 := Oberon.Time ();
	vyHostTexts.NoteSI (vyHostTexts.cAlert, "BackFaceIdentification:   ", t1 - t0);

	t0 := Oberon.Time ();     SortFaces (self);     t1 := Oberon.Time ();
	vyHostTexts.NoteSI (vyHostTexts.cAlert, "SortFaces:   ", t1 - t0);

	t0 := Oberon.Time ();     ReplBackFaceColoring (self);     t1 := Oberon.Time ();
	vyHostTexts.NoteSI (vyHostTexts.cAlert, "ReplHiddenLine:   ", t1 - t0);

END BackFaceColoringMap;

(** ------------  Open ------------ *)
PROCEDURE OpenMap* (x0, y0, x1, y1: Real;     m: vyRealVec.tChunkedMatrix): tObject;
	(*vs 0.0d0   md  12.12.94 14:53:56 *)
	VAR map: tMap;
BEGIN
	NEW (map);     ASSERT (map # NIL);
	map.x0 := x0;     map.y0 := y0;     map.x1 := x1;     map.y1 := y1;
	map.mdata := m;
	map.plot := theHLHSRroutine;
	RETURN map;
END OpenMap;

(** ------------  set plot attributes ------------ *)
PROCEDURE SetHLHSRIdentifier* (HLHSRidentifier: SIGNED16);
	(*vs 0.0d0   md  05.04.95 10:09:39 *)
BEGIN
	IF HLHSRidentifier = wireFrameId THEN theHLHSRroutine := WireFrameMap
	ELSIF HLHSRidentifier = niveauLineId THEN theHLHSRroutine := NiveauLineMap
	ELSIF HLHSRidentifier = backFaceColoringId THEN theHLHSRroutine := BackFaceColoringMap
	ELSIF HLHSRidentifier = painterId THEN theHLHSRroutine := PainterMap
	ELSIF HLHSRidentifier = lightingId THEN theHLHSRroutine := LightingMap;
	ELSIF HLHSRidentifier = smoothLightingId THEN theHLHSRroutine := SmoothLightingMap;
	ELSIF HLHSRidentifier = hiddenLineId THEN theHLHSRroutine := HiddenLineMap
	ELSIF HLHSRidentifier = niveauColoringId THEN theHLHSRroutine := NiveauColoringMap
	ELSE vyHostTexts.NoteSI (vyHostTexts.cNotify,
		"SetHLHSRIdentifier got unknown identifier = ", HLHSRidentifier)
	END;
END SetHLHSRIdentifier;

PROCEDURE SetRendering* (map: tObject;     HLHSRidentifier: SIGNED16);
	VAR oldmap : tPlotRoutine;
BEGIN oldmap := theHLHSRroutine;  SetHLHSRIdentifier (HLHSRidentifier);     map.plot := theHLHSRroutine;    theHLHSRroutine := oldmap;
END SetRendering;

PROCEDURE GetRendering (map: tObject;    VAR HLHSRidentifier: SIGNED16);
	VAR wireFrameMap, niveauLineMap, backFaceColoringMap, painterMap, lightingMap, smoothLightingMap, hiddenLineMap, niveauColoringMap: tPlotRoutine;
BEGIN
	wireFrameMap := WireFrameMap ;
	niveauLineMap := NiveauLineMap;
	backFaceColoringMap := BackFaceColoringMap;
	painterMap := PainterMap;
	lightingMap := LightingMap;
	smoothLightingMap := SmoothLightingMap;
	hiddenLineMap := HiddenLineMap;
	niveauColoringMap := NiveauColoringMap;

	IF map.plot = wireFrameMap THEN HLHSRidentifier := wireFrameId
	ELSIF  map.plot = niveauLineMap THEN HLHSRidentifier := niveauLineId
	ELSIF  map.plot = backFaceColoringMap THEN HLHSRidentifier := backFaceColoringId
	ELSIF  map.plot = painterMap THEN HLHSRidentifier := painterId
	ELSIF  map.plot = lightingMap THEN HLHSRidentifier := lightingId
	ELSIF  map.plot = smoothLightingMap THEN HLHSRidentifier := smoothLightingId
	ELSIF map.plot  = hiddenLineMap THEN HLHSRidentifier := hiddenLineId
	ELSIF map.plot  = niveauColoringMap THEN HLHSRidentifier := niveauColoringId
	ELSE HLHSRidentifier := - 1
	END;
END GetRendering;




PROCEDURE SetInteractiveMode* (switch: BOOLEAN);
BEGIN vyPort.onTheFly := switch END SetInteractiveMode;

(** ------------- palette stuff ---------------- *)

PROCEDURE InitColorMap;
	VAR i: SIGNED16;
BEGIN
	FOR i := 0 TO LEN(colorTable) - 1 DO
		Display.GetColor(colorTable[i], i, i, i)
	END;
END InitColorMap;


PROCEDURE SetColorMap* (colors: ARRAY OF SIGNED32);
	VAR i: SIGNED16;
BEGIN
	ASSERT(LEN(colors) >= LEN(colorTable));
	FOR i := 0 TO LEN(colorTable) - 1 DO
		colorTable[i] := colors[i];
	END;
END SetColorMap;

PROCEDURE SetLines*(VAR b: BOOLEAN);
VAR temp: BOOLEAN;
BEGIN
	temp := b;
	b := lines;
	lines := temp;
END SetLines;


BEGIN
	SetLightDirection (12 , - 4, 12);
	SetHLHSRIdentifier (wireFrameId);
	triangulate := TRUE; lines := TRUE;
	InitColorMap;
END vyPolyWorld.