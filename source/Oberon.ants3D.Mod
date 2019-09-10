MODULE ants3D IN Oberon; 	(** JM  **)
(* Copyright notice:

This file is part of AntsInFields
Copyright (C) 1997-2002, Felix Friedrich

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
Report any problems as soon as possible to ants@AntsInFields.de
*)




IMPORT vyLinks, antsArrayObjects, antsCommands, vyRealVec, vyBase, vyCG := vyName, vyHostStrings, antsRegions,
	Objects, antsPictCoordinate, antsToolbox, antsViews, aM := antsMessages,antsHybridObjects,Files,Gadgets;

TYPE
	ConsistencyObject= OBJECT (antsHybridObjects.Object)
	VAR in: antsArrayObjects.tINTEGERObject;
		out: vyRealVec.tChunkedMatrix;  x0, y0, w0, h0: SIGNED32;

	PROCEDURE Update*;
	BEGIN
		UpdateMatrix(in,out.buf,x0, y0, w0, h0,TRUE);
		(* vyBase.Update(out); *)
	END Update;

	PROCEDURE Bind*(VAR M:Objects.BindMsg);
	BEGIN
		BindObj(M,in); BindObj(M,out); Bind^(M);
	END Bind;

	PROCEDURE Load*(VAR R: Files.Rider);
	VAR obj: Objects.Object;
	BEGIN
		Load^(R);
		Files.ReadLInt(R,x0); Files.ReadLInt(R,y0);Files.ReadLInt(R,w0); Files.ReadLInt(R,h0);
		Gadgets.ReadRef(R,lib,obj); IF obj # NIL THEN in := obj(antsArrayObjects.tINTEGERObject) END;
		Gadgets.ReadRef(R,lib,obj); IF obj # NIL THEN out := obj(vyRealVec.tChunkedMatrix) END;

	END Load;

	PROCEDURE Store*(VAR R: Files.Rider);
	BEGIN
		Store^(R);
		Files.WriteLInt(R,x0); Files.WriteLInt(R,y0); Files.WriteLInt(R,w0); Files.WriteLInt(R,h0);
		Gadgets.WriteRef(R,lib,in); Gadgets.WriteRef(R,lib,out);
	END Store;


	END ConsistencyObject;

PROCEDURE GenConsistencyObject*;
VAR c: ConsistencyObject;
BEGIN
	NEW(c); Objects.NewObj := c;
END GenConsistencyObject;

PROCEDURE UpdateMatrix(A: antsArrayObjects.tINTEGERObject;  VAR m: vyRealVec.tMatrixChunk;  x0, y0, w0, h0: SIGNED32;  scaleminmax: BOOLEAN);
	VAR min, max: SIGNED32;  x, y: SIGNED32;
BEGIN
	IF scaleminmax THEN
		min := MAX(SIGNED16);  max := MIN(SIGNED16);
		FOR y := y0 TO y0 + h0 - 1 DO
			FOR x := x0 TO x0 + w0 - 1 DO
				IF A.A[y, x] > max THEN max := A.A[y, x] END;
				IF A.A[y, x] < min THEN min := A.A[y, x] END
			END
		END;
		IF min = max THEN max := min + 1 END
	ELSE min := 0;  max := SHORT(A.depth)
	END;
	FOR y := y0 TO y0 + h0 - 1 DO
		FOR x := x0 TO x0 + w0 - 1 DO
			vyRealVec.WriteMatrix (m, y - y0, x - x0, (A.A[y, x] - min) / (max - min))
		END
	END
END UpdateMatrix;


PROCEDURE MatrixFromArray (A: antsArrayObjects.tINTEGERObject;  VAR m: vyRealVec.tMatrixChunk;  x0, y0, w0, h0: SIGNED32;  scaleminmax: BOOLEAN);
BEGIN
	m := vyRealVec.NEWMatrix (h0, w0);
	UpdateMatrix(A,m,x0,y0,w0,h0,scaleminmax);
END MatrixFromArray;

PROCEDURE ScaleMatrix*;
	VAR  obj: vyBase.Object;  par: FLOAT64;  y, x: SIGNED32;
BEGIN
	antsCommands.InitScan("name=NAME scale=FLOAT32");
	IF antsCommands.ExpectObject("name", obj) &
		antsCommands.ExpectReal("scale", par) THEN
		WITH obj: vyRealVec.tChunkedMatrix DO
			FOR y := 0 TO obj.buf.row - 1 DO
				FOR x := 0 TO obj.buf.col - 1 DO
					vyRealVec.WriteMatrix (obj.buf, y, x, vyRealVec.ReadMatrix(obj.buf, y, x) * par)
				END
			END

		END
	END
END ScaleMatrix;

PROCEDURE MatrixObjectFromArray* (A: antsArrayObjects.tINTEGERObject;  x, y, w, h: SIGNED32;  scaleminmax: BOOLEAN):
vyRealVec.tChunkedMatrix;
	VAR m: vyRealVec.tMatrixChunk;  data: vyRealVec.tChunkedMatrix; c: ConsistencyObject;
BEGIN
	IF x < 0 THEN w := w+x; x := 0 END;
	IF y<0 THEN h := h+y; y := 0; END;
	IF x+w>A.w THEN w := A.w-x END;
	IF y+h > A.h THEN h := A.h-y END;
	MatrixFromArray(A, m, x, y, w, h, scaleminmax);
	data := vyRealVec.NewMatrixObject(m);
	NEW(c);
	c.in := A; c.out := data; c.x0 := x; c.y0 := y; c.w0 := w; c.h0 := h;
	vyBase.Subscribe(c.in,c); vyBase.Subscribe(c,c.out);
	RETURN data
END MatrixObjectFromArray;

PROCEDURE View3d*;  (* called from antsViews *)
	VAR data: vyRealVec.tChunkedMatrix;  tc: antsPictCoordinate.Selection;  obj: vyLinks.Link;
BEGIN
	IF (antsViews.tempLayer = NIL) OR  (antsViews.tempLayer.refArray = NIL ) OR (antsPictCoordinate.currentsel = NIL) THEN RETURN END;
	tc := antsPictCoordinate.currentsel;
	data := MatrixObjectFromArray(antsViews.tempLayer.refArray, tc.px, tc.py, tc.pw, tc.ph, FALSE);
	vyLinks.InsertObj (obj, data);
	vyBase.Show(obj, 1, "Surface");
	antsToolbox.NameOpenedWId("3DPlot of part", antsViews.tempLayer.refArray)

END View3d;


PROCEDURE DataFromArray (A: antsArrayObjects.tINTEGERObject;  name: vyCG.tNameArray;  x, y, w, h: SIGNED32;  scaleminmax: BOOLEAN);
	VAR m: vyRealVec.tMatrixChunk;  data: vyRealVec.tChunkedMatrix;  obj: vyLinks.Link;
BEGIN
	MatrixFromArray(A, m, x, y, w, h, scaleminmax);
	data := vyRealVec.NewMatrixObject(m);
	vyCG.RegisterNamed(data, name);
	vyLinks.InsertObj (obj, data)
END DataFromArray;

PROCEDURE MakeMatrixFromArray*;
	VAR l: antsCommands.tScanList;   name: vyCG.tNameArray;
	obj: vyBase.Object;  A: antsArrayObjects.tINTEGERObject;
	x, y, w, h: SIGNED32;

BEGIN
	l := antsCommands.ScanFromPar("from=OBJ name=NAME [x=INT y=INT w=INT h=INT]");
	IF
		antsCommands.GetObjectFromKeyword(l, "from", obj) &
		antsCommands.GetNameFromKeyword(l, "name", name)
		THEN
		A := obj(antsArrayObjects.tINTEGERObject);

		IF
			antsCommands.GetNumberFromKeyword (l, "x", x) &
			antsCommands.GetNumberFromKeyword (l, "y", y) &
			antsCommands.GetNumberFromKeyword (l, "w", w) &
			antsCommands.GetNumberFromKeyword (l, "h", h) THEN
		ELSE
			x := 0;  y := 0;  w := A.w;  h := A.h
		END;
		DataFromArray(A, name, x, y, w, h, TRUE)
	END
END MakeMatrixFromArray;

PROCEDURE NewFromRegion*;
	VAR A: antsArrayObjects.tINTEGERObject;  region: antsRegions.tRegion;   name: vyCG.tNameArray;
	x, y, w, h: SIGNED32;
BEGIN
	antsCommands.InitScan("name=NAME ~# interactive creates 3d-Matrix from Array");
	IF
		antsCommands.ExpectName( "name",  name)
		THEN
		antsRegions.Gen;  region := Objects.NewObj(antsRegions.tRegion);
		antsRegions.DoSelectRegion(region);
		IF ~region.valid  THEN RETURN END;
		A := antsRegions.A;


		IF A # NIL THEN
			antsRegions.Get(region, A, x, y, w, h);
			DataFromArray(A, name, x, y, w, h, FALSE)
		END
	END
END NewFromRegion;


(*PROCEDURE MakeMatrixFromLayer*;
VAR l: antsCommands.tScanList; p: antsCommands.tParameter; name: vyCG.tNameArray;
real: FLOAT64; obj: vyBase.Object; A: antsArrayObjects.tINTEGERObject; obj2: vyLinks.Link; 			surface: vyPicture.tLayer;
c3: vyLayers3d.tCoordinate3d;
pict : vyPicture.Picture; x,y,w,h: SIGNED32; l1: vyPort.tLayer; l2 : antsViews.tLayer;

BEGIN
l := antsCommands.ScanFromPar();
IF
antsCommands.GetNameFromKeyword(l,"name",name) THEN
l1:= vyPort.FocusLayer();
l2 := l1(antsViews.tLayer);
A := l2.refArray(antsArrayObjects.tINTEGERObject);
DataFromArray(A,name,l2.sx,l2.sy,l2.sw,l2.sh);
END;
END MakeMatrixFromLayer;
*)



PROCEDURE MakeVectorFromLine*;
	VAR l: antsCommands.tScanList ;  name: vyCG.tNameArray;
	obj: vyBase.Object;  A: antsArrayObjects.tINTEGERObject;  x, y: SIGNED32;  v: vyBase.tVector;  vertical: BOOLEAN;

BEGIN
	l := antsCommands.ScanFromPar("from=OBJ name=NAME y=INT [>vertical] ~# put content of line in <from> in new vector <name> ");
	IF
		antsCommands.ExpectObjectFromKeyword(l, "from", obj) &
		antsCommands.ExpectNameFromKeyword(l, "name", name) &
		antsCommands.ExpectNumberFromKeyword (l, "y", y)
		THEN
		vertical := antsCommands.FindKeyword(l, "vertical");

		v := vyRealVec.New(0);
		A := obj(antsArrayObjects.tINTEGERObject);
		IF vertical THEN
			FOR x := 0 TO A.h - 1 DO
				vyRealVec.Append(A.A[x, y], v)
			END
		ELSE
			FOR x := 0 TO A.w - 1 DO
				vyRealVec.Append(A.A[y, x], v)
			END
		END;
		vyCG.RegisterNamed(v, name);
		v := vyRealVec.New(0);
		IF vertical THEN
			FOR x := 0 TO A.h - 1 DO
				vyRealVec.Append(x, v)
			END
		ELSE
			FOR x := 0 TO A.w - 1 DO
				vyRealVec.Append(x, v)
			END
		END;
		vyHostStrings.Append(name, "Y");
		vyCG.RegisterNamed(v, name)
	END
END MakeVectorFromLine;

BEGIN aM.launch;
END ants3D.

ants3D.MakeMatrixFromArray > from myArray > name Matrix > x 0 > y 0 > w 16 > h 16 ~
ants3d.ViewLine > from Array > name Vector > y 50 ~
Voyager.Show  Matrix as vySurface ~
Voyager.Show Vector as LinePlot ~
vySurface.ShowP ~
