MODULE antsPlots IN Oberon; 	(** fof   **)
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




IMPORT antsCommands, vyBase, vyTracking, antsArrayObjects, ants3dArrayObjects, vyPort, antsPictCoordinate, antsPictureViews, antsHistogramEdit,aM := antsMessages,
	antsArrayImages, antsArrayPictures, vyLinks, Objects, Input, ants1dArrayVectors, antsFctVector, antsFunctions, antsArrayPictures16, vyName, antsToolbox;

VAR
	port: vyPort.Frame;                    c: Objects.Object;
	cc: antsPictCoordinate.tCoordinate;

PROCEDURE Add (VAR l: vyTracking.List;  name: ARRAY OF CHAR);
	VAR s: vyTracking.List;
BEGIN
	s := l;
	IF l = NIL THEN NEW(l);  COPY(name, l.name);  RETURN END;
	WHILE(l.next # NIL) DO
		l := l.next
	END;
	NEW(l.next);  l := l.next;  COPY(name, l.name);
	l := s
END Add;

PROCEDURE DoShow* (obj: vyBase.Object);
	VAR  link: vyLinks.Link;  l, res: vyTracking.List;  keys: SET;  x, y: INTEGER;
BEGIN
	Add(l, "antsObjectView");   Add(l, "antsDependency");    Add(l, "antsLinkView");
	IF obj IS ants1dArrayVectors.tObject THEN
		obj := obj(ants1dArrayVectors.tObject).vec
	ELSIF obj IS antsFctVector.Object THEN
		obj := obj(antsFctVector.Object).x
	END;

	IF obj IS vyBase.tVector THEN
		Add(l, "vyLinePlot");  Add(l, "vyScatter");  Add(l, "vyHistogram");  Add(l, "antsPointPlot")
	ELSIF obj IS antsArrayObjects.tObject THEN
		Add(l, "antsArrayViews");
		Add(l, "antsPictureViews")
	ELSIF obj IS antsArrayPictures.tObject THEN
		Add(l, "antsPictureViews")
	ELSIF obj IS antsArrayImages.tObject THEN
		Add(l, "antsImageViews")
	ELSIF obj IS ants3dArrayObjects.tObject THEN
		Add(l, "ants3dArrayViews")
	ELSIF obj IS antsFunctions.Function THEN
		Add(l, "antsFctEdit")
	END;
	vyLinks.InsertObj(link, obj);
	Input.Mouse(keys, x, y);
	vyTracking.ScrollList(l, x, y, res);
	IF res # NIL THEN  vyBase.Show(link, 1, res.name)	END
END DoShow;

PROCEDURE Show*;
	VAR l: antsCommands.tScanList;      obj: vyBase.Object;
BEGIN
	l := antsCommands.ScanFromPar("name=OBJ");
	IF 	antsCommands.ExpectObjectFromKeyword(l, "name",  obj) THEN
		DoShow(obj)
	END
END Show;

PROCEDURE ShowP*;
	VAR data: Objects.Object;
BEGIN
	aM.vS("antsPlots.ShowP");
	data := vyBase.NextParObj();
	WHILE (data # NIL)  DO
		DoShow(data(vyBase.Object));
		data := vyBase.NextParObj()
	END
END ShowP;

PROCEDURE ShowArray* (a: antsArrayObjects.tObject;  name: ARRAY OF CHAR;  samecoord, sameport: BOOLEAN);
	VAR	obj: antsArrayPictures16.tObject;                   la: vyPort.tLayer;   pict: vyPort.Picture;
BEGIN
	(* Oberon.LockOberon(); *)(* not needed, locked vy vyHostTexts.InsertGadget *)

	IF ~sameport THEN port := NIL END;
	IF ~samecoord THEN cc := NIL END;

	WITH a: antsArrayObjects.tINTEGERObject DO
		antsArrayPictures16.Gen;                    obj := Objects.NewObj(antsArrayPictures16.tObject);
		NEW(obj.curve);                      antsHistogramEdit.InitObject(obj.curve, 0, 0, antsArrayPictures16.maxHistogramLen, 1);
		vyBase.Subscribe(obj.curve, obj);
		antsArrayPictures16.FromArray(obj, a);
		vyName.RegisterNamed(obj, name);
		IF port = NIL THEN
			la := antsPictureViews.DoShow(obj, FALSE, cc);
			port := vyPort.GetFocus();                    pict := vyPort.GetFocusPicture();
			c := cc
		ELSE
			antsPictureViews.New;
			la := Objects.NewObj(antsPictureViews.tLayer);
			antsPictureViews.Open(la(antsPictureViews.tLayer), obj);
			pict := NIL;
			antsToolbox.ViewLayer(port, pict, la, c)
		END
	END;
	(*Oberon.UnlockOberon();*)
END ShowArray;

BEGIN aM.launch;
END antsPlots.

antsPlots.Show test ~
