MODULE antsArrayPictures16 IN Oberon;   (* fof *)
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




IMPORT antsArrayPictures, Objects, antsObjects, antsArrayObjects, Pictures, antsCommands, vyName, vyBase, vyLinks,
	antsFunctions, vyLongrealVec, antsHistogramEdit, antsPointPlot, vyPort, Files, Gadgets, vyCommandMenus, aM := antsMessages;

TYPE

	tObject* = POINTER TO tObjectDesc;
	tObjectDesc = RECORD (antsArrayPictures.tObjectDesc);
		histogram*: vyBase.tVector;
		curve*: antsHistogramEdit.tObject;
		warned: SET;
	END;

	(* depth is not consistent with A.depth, depth is the VISIBLE depth ! *)

VAR
	greyvF: antsFunctions.Function;  global: tObject;
CONST
	maxHistogramLen* = 1000;

	PROCEDURE SetHisto( obj: tObject );
	VAR y, x: LONGINT;  val, pos: LONGINT;  len: LONGINT;  nrNaNs: LONGINT;  min, max: LONGREAL;
	BEGIN
		IF obj.A.depth > maxHistogramLen THEN len := maxHistogramLen ELSE len := obj.A.depth END;
		(* len := maxHistogramLen;  *)
		obj.depth := Min( obj.A.depth, 256 );   (* hack !!! *)

		IF obj.histogram = NIL THEN obj.histogram := vyLongrealVec.New( len );  vyName.RegisterNamed( obj.histogram, "Histogram" )
		ELSIF vyLongrealVec.Len( obj.histogram ) # len THEN vyLongrealVec.SetLen( obj.histogram, len )
		END;
		vyLongrealVec.Fill( obj.histogram, 0, 0, len );
		FOR y := 0 TO obj.h - 1 DO
			FOR x := 0 TO obj.w - 1 DO
				val := obj.A.A[y, x];
				(* IF val < 0 THEN INC(val, 65536) END;*)
				pos := ENTIER( val / (obj.A.depth - 1) * (len - 1) );
				IF pos >= len THEN
					IF ~(0 IN obj.warned) THEN aM.eSI( "Warning: antsArrayPictures16, Histogramoverflow:", pos );  INCL( obj.warned, 0 ) END;

					pos := len - 1
				ELSIF pos < 0 THEN
					IF ~(1 IN obj.warned) THEN aM.eSI( "Warning: antsArrayPictures, Histogramoverflow:", pos );  INCL( obj.warned, 1 ) END;
					pos := 0;
				END;
				vyLongrealVec.Set( vyLongrealVec.Get( obj.histogram, pos ) + 1, obj.histogram, pos )
				(* a[val] := a[val]+1; *)
			END
		END;
		vyLongrealVec.GetMinMax( obj.histogram, min, max, nrNaNs );
		vyLongrealVec.Scale( obj.histogram, obj.histogram, 0, 1 / max )
		(*
	Out.Ln; Out.String("Sending update to objhisto");
	vyBase.Update(obj.histogram);
	Out.Ln; Out.String("Sent update to objhisto");
	*)
	END SetHisto;

	PROCEDURE HandleAttributes( o: tObject;  VAR M: Objects.AttrMsg );
	BEGIN
		IF M.id = Objects.enum THEN M.Enum( "Gen" );  antsArrayPictures.Handler( o, M )
		ELSIF M.id = Objects.get THEN
			IF M.name = "Gen" THEN COPY( 'antsArrayPictures16.Gen', M.s );  M.class := Objects.String;  M.res := 0 ELSE antsArrayPictures.Handler( o, M ) END
		ELSE antsArrayPictures.Handler( o, M )
		END
	END HandleAttributes;

	PROCEDURE HandleFileMsg( obj: tObject;  VAR msg: Objects.FileMsg );
	VAR objsub: Objects.Object;  version: INTEGER;
		(*! store Picts as GIF for color preserving or store colors *)
	BEGIN
		IF msg.id = Objects.load THEN
			Files.ReadInt( msg.R, version );  antsArrayPictures.Handler( obj, msg );  Gadgets.ReadRef( msg.R, obj.lib, objsub );
			IF (objsub # NIL ) & (objsub IS vyBase.tVector) THEN obj.histogram := objsub( vyBase.tVector ) END;
			Gadgets.ReadRef( msg.R, obj.lib, objsub );
			IF (objsub # NIL ) & (objsub IS antsHistogramEdit.tObject) THEN obj.curve := objsub( antsHistogramEdit.tObject ) END
		ELSIF msg.id = Objects.store THEN
			Files.WriteInt( msg.R, 0 );  antsArrayPictures.Handler( obj, msg );  Gadgets.WriteRef( msg.R, obj.lib, obj.histogram );
			Gadgets.WriteRef( msg.R, obj.lib, obj.curve )
		ELSE antsArrayObjects.Handler( obj, msg )
		END
	END HandleFileMsg;

	PROCEDURE Handler*( obj: Objects.Object;  VAR msg: Objects.ObjMsg );
	VAR
	BEGIN
		WITH obj: tObject DO
			IF msg IS Objects.AttrMsg THEN
				WITH msg: Objects.AttrMsg DO HandleAttributes( obj, msg )
				END;
			ELSIF msg IS Objects.FileMsg THEN
				WITH msg: Objects.FileMsg DO HandleFileMsg( obj, msg );
				END;
			ELSIF msg IS vyBase.UpdateMessage THEN
				WITH msg: vyBase.UpdateMessage DO antsArrayPictures.Handler( obj, msg );
				END;
			ELSIF msg IS antsHistogramEdit.AdaptMsg THEN
				WITH msg: antsHistogramEdit.AdaptMsg DO antsArrayPictures.Sync( obj );  SetHisto( obj );  AdjustCurve( obj );
				END;
			ELSIF msg IS Objects.LinkMsg THEN
				WITH msg: Objects.LinkMsg DO
					IF msg.id = Objects.enum THEN msg.Enum( "histogram" );  msg.Enum( "curve" );  antsArrayPictures.Handler( obj, msg )
					ELSIF msg.id = Objects.get THEN
						IF msg.name = "histogram" THEN msg.obj := obj.histogram;  msg.res := 0;  RETURN
						ELSIF msg.name = "curve" THEN msg.obj := obj.curve;  msg.res := 0;  RETURN
						ELSE antsArrayPictures.Handler( obj, msg )
						END
					ELSE antsArrayPictures.Handler( obj, msg )
					END;
				END;
			ELSIF msg IS Objects.BindMsg THEN
				WITH msg: Objects.BindMsg DO
					IF obj.lib # msg.lib THEN
						antsArrayPictures.Handler( obj, msg );
						antsObjects.Bind( obj, msg );   (* possibly double bound, no problem at that point, for security reasons only.. *)
						antsObjects.Bind( obj.histogram, msg );  antsObjects.Bind( obj.curve, msg )
					END;
				END;
			ELSIF msg IS vyCommandMenus.enumMsg THEN
				WITH msg: vyCommandMenus.enumMsg DO
					global := obj;  msg.Enum( "ViewHistogram", viewhist, obj );  vyCommandMenus.Ask( obj.histogram );
					vyCommandMenus.Ask( obj.curve );  antsArrayPictures.Handler( obj, msg )
				END;
			ELSE antsArrayPictures.Handler( obj, msg )
			END
		END
	END Handler;

	PROCEDURE A2P*( o: Objects.Object );
	VAR x, y: LONGINT;  obj: tObject;   (* pix: Images.Pixel; *) val: LONGINT;  valr: LONGREAL;  len: LONGINT;  r: INTEGER;
	BEGIN

		obj := o( tObject );
		IF obj.A.depth > maxHistogramLen THEN len := maxHistogramLen ELSE len := obj.A.depth END;
		SetHisto( obj );
		(*
	FOR i := 0 TO 65535 DO gv[i] := 0 END;
	obj := o(tObject);
	FOR y := 0 TO obj.h-1 DO
	FOR x := 0 TO obj.w-1 DO
	val := obj.A.A[y,x]; IF val <0 THEN INC(val,65536) END;
	INC(gv[val]);
	END;
	END;

	sum := 0; i := 0;
	WHILE(sum<obj.h*obj.w*0.99) DO
	sum := sum+gv[i]; INC(i);
	END;
	*)


		FOR y := 0 TO obj.h - 1 DO
			FOR x := 0 TO obj.w - 1 DO
				val := obj.A.A[y, x];
				(* IF val < 0 THEN INC(val, 65536) END;*)
				valr := (len - 1) * (val / (obj.A.depth - 1));

				r := SHORT( ENTIER( (obj.depth - 1) * antsHistogramEdit.GetValue( obj.curve, valr ) + 0.5 ) );
				IF r < 0 THEN r := 0
				ELSIF r > (obj.depth - 1) THEN r := SHORT( obj.depth - 1 )
				END;
				IF r = 255 THEN r := 254 END;   (* bug in pictures *)
				Pictures.Dot( obj.pict, r, SHORT( x ), SHORT( y ), 0 )
				(*
			Images.SetRGB(pix,r,g,b);
			Images.Put(obj.img,SHORT(x),SHORT(y),pix,Images.SrcCopy);
			*)
			END
		END
	END A2P;

	PROCEDURE Gen*;
	VAR obj: tObject;
	BEGIN
		NEW( obj );  antsArrayPictures.Init( obj );  obj.handle := Handler;  obj.trans := A2P;  Objects.NewObj := obj
	END Gen;

	PROCEDURE Min( a, b: LONGINT ): LONGINT;
	BEGIN
		IF a < b THEN RETURN a ELSE RETURN b END
	END Min;

	PROCEDURE AdjustCurve( obj: tObject );
	VAR sum, up: LONGREAL;  i: LONGINT;  len: LONGINT;
	BEGIN
		IF obj.A.depth > maxHistogramLen THEN len := maxHistogramLen ELSE len := obj.A.depth END;

		IF obj.curve = NIL THEN NEW( obj.curve );  vyBase.Subscribe( obj.curve, obj )
		END;
		antsHistogramEdit.InitObject( obj.curve, 0, 0, len, 1 );   (* delete all points *)

		sum := 0;
		FOR i := 0 TO len - 1 DO sum := sum + vyLongrealVec.Get( obj.histogram, i ) END;
		up := sum * 0.99;  i := 0;  sum := 0;
		WHILE (up > sum) & (i < len - 1) DO sum := sum + vyLongrealVec.Get( obj.histogram, i );  INC( i ) END;
		IF (i < maxHistogramLen) & antsHistogramEdit.AddPoint( obj.curve, i ) & antsHistogramEdit.SetXY( obj.curve, i, 1, 1 ) THEN
		END
	END AdjustCurve;

	PROCEDURE FromArray*( obj: tObject;  A: antsArrayObjects.tINTEGERObject );
	VAR r, g, b: INTEGER;  i: LONGINT;   (* pal: Images.Palette; fmt: Images.Format; *)
	BEGIN
		obj.A := A;  obj.w := A.w;  obj.h := A.h;  obj.depth := Min( A.depth, 256 );  NEW( obj.pict );
		Pictures.Create( obj.pict, SHORT( obj.w ), SHORT( obj.h ), 8 );

		FOR i := 0 TO obj.depth - 1 DO r := SHORT( (i) * 255 DIV (obj.depth - 1) );  g := r;  b := r;  Pictures.SetColor( obj.pict, SHORT( i ), r, g, b ) END;

		FOR i := obj.depth TO 255 DO Pictures.SetColor( obj.pict, SHORT( i ), 255, 0, 0 ) END;
		vyBase.Subscribe( obj.A, obj );  SetHisto( obj );
		(*AdjustCurve(obj);*)
		antsArrayPictures.Sync( obj )
	END FromArray;

	PROCEDURE DoShow*( A: antsArrayObjects.tINTEGERObject;  VAR obj: tObject );
	VAR link: vyLinks.Link;  len: LONGINT;
	BEGIN
		Gen;  obj := Objects.NewObj( tObject );
		IF A.depth > maxHistogramLen THEN len := maxHistogramLen ELSE len := A.depth END;

		NEW( obj.curve );  antsHistogramEdit.InitObject( obj.curve, 0, 0, len, 1 );  vyBase.Subscribe( obj.curve, obj );
		FromArray( obj, A );  link := NIL;  vyLinks.InsertObj( link, obj );  vyBase.Show( link, 1, "antsViews" )
	END DoShow;

	PROCEDURE DoShowI*( a: antsArrayObjects.tINTEGERArray;  depth: LONGINT;  VAR obj: tObject );
	VAR A: antsArrayObjects.tINTEGERObject;
	BEGIN
		A := antsArrayObjects.NewINTEGERObject( LEN( a[0] ), LEN( a ), depth );  antsArrayObjects.SetInt( A, a );  DoShow( A, obj )
	END DoShowI;

	PROCEDURE DoShowR*( a: antsArrayObjects.tLONGREALArray;  depth: LONGINT;  VAR obj: tObject );
	VAR A: antsArrayObjects.tINTEGERObject;
	BEGIN
		A := antsArrayObjects.NewINTEGERObject( LEN( a[0] ), LEN( a ), depth );  antsArrayObjects.SetLongreal( A, a );
		DoShow( A, obj )
	END DoShowR;

	PROCEDURE New*;
	VAR l: antsCommands.tScanList;  name: vyName.tNameArray;  from: vyBase.Object;  obj: tObject;  link: vyLinks.Link;  len: LONGINT;
	BEGIN
		l := antsCommands.ScanFromPar( "name=NAME from=OBJ [>show] ~# create new ArrayPicture  with Histogram from <from>" );
		IF antsCommands.ExpectNameFromKeyword( l, "name", name ) & antsCommands.ExpectObjectFromKeyword( l, "from", from ) THEN
			WITH from: antsArrayObjects.tINTEGERObject DO
				Gen;  obj := Objects.NewObj( tObject );
				IF from.depth > maxHistogramLen THEN len := maxHistogramLen ELSE len := from.depth END;
				NEW( obj.curve );  antsHistogramEdit.InitObject( obj.curve, 0, 0, len, 1 );  vyBase.Subscribe( obj.curve, obj );
				FromArray( obj, from );  vyName.RegisterNamed( obj, name );  antsObjects.Register( obj );
				IF antsCommands.FindKeyword( l, "show" ) THEN link := NIL;  vyLinks.InsertObj( link, obj );  vyBase.Show( link, 1, "antsViews" ) END
			END
		END
	END New;

	PROCEDURE DoShowHistogram*( obj: tObject );
	VAR layer: antsPointPlot.tLayer;  len: LONGINT;
	BEGIN
		IF obj.A.depth > maxHistogramLen THEN len := maxHistogramLen ELSE len := obj.A.depth END;
		antsHistogramEdit.DoShow( obj.curve, 0, 0, len, 1 );  antsPointPlot.Alloc;
		layer := Objects.NewObj( antsPointPlot.tLayer );  antsPointPlot.Open( layer, obj.histogram );
		vyPort.AddLayer( vyPort.GetFocusPicture(), layer );  vyPort.SetC2d( vyPort.GetFocusPicture(), 0, 0, len, 1 );
	END DoShowHistogram;

	PROCEDURE viewhist;
	BEGIN
		DoShowHistogram( global )
	END viewhist;

	PROCEDURE ShowHistogram*;
	VAR l: antsCommands.tScanList;  from: vyBase.Object;  obj: tObject;
	BEGIN
		l := antsCommands.ScanFromPar( "name=OBJ ~# view Histogram of ArrayPicture <name>" );
		IF antsCommands.ExpectObjectFromKeyword( l, "name", from ) THEN obj := from( tObject );  DoShowHistogram( obj ) END
	END ShowHistogram;

	PROCEDURE Test*;
	VAR A: antsArrayObjects.tINTEGERObject;  obj: tObject;  i: INTEGER;
	BEGIN
		A := antsArrayObjects.NewINTEGERObject( 200, 200, 65535 );
		FOR i := 0 TO 32000 DO A.A[i MOD 200, i DIV 200] := i END;
		Gen;  obj := Objects.NewObj( tObject );  vyName.RegisterNamed( obj, "TestImage" );  antsObjects.Register( obj );
		FromArray( obj, A )
	END Test;

BEGIN
	aM.launch;  antsFunctions.Gen;  greyvF := Objects.NewObj( antsFunctions.Function )
END antsArrayPictures16.

System.Free  Katrin antsImageViews antsViews antsArrayPictures antsArrayPictures16  antsArrayPictures ~

antsArrayObjects.New Array 100 100 4 ~
antsArrayPictures.New > name testimg > from Array ~
antsArrayPictures.LoadImg > name testimg > fname "Bart.Pict"
Voyager.Show testimg as antsObjectView ~

Voyager.Show testimg as antsImageViews ~


Voyager.Show Array as antsViews ~

antsArrayPictures.LoadImg > name testimg > fname ^

antsArrayPictures16.Test ~
Voyager.Show TestImage as antsImageViews ~
ants / antsImageViews.Mod

fofAutomatic.Do
Katrin.OpenMammo  Mammo patch071010.pgm  ~
antsArrayPictures16.New MammoBild Mammo ~
Voyager.Show MammoBild as antsViews ~
~

Voyager.Show MammoBild as antsObjectView ~


antsFunctions.Define myfunction ~
Voyager.Show myfunction as antsFctEdit ~
antsObjects.WriteAttributes myfunction ~


a := RanV(20);
b := RanV(20);
Voyager.Show a b as Charts ~



antsArrayPictures16.ShowHistogram MammoBild ~



System.DeleteFiles fofAutomatic.Do ~~~

ants / src / antsImageViews.Mod


