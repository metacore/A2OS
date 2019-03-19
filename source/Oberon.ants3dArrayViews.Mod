MODULE ants3dArrayViews IN Oberon;   (* fof *)
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




IMPORT vyPort, vyName, vyBase, vyGraphBase, Display, Display3, vyEvents, ants3dArrayObjects, antsViews, Files, Pictures,
	antsCommands, Objects, vyCommandMenus, Gadgets, vyHostTexts, vyDisplay2d, antsObjects, aM := antsMessages;

CONST
	Vertices* = 0;  vEdges* = 1;  hEdges* = 2;  Plain* = 3;

TYPE

	tLayer* = POINTER TO tLayerDesc;
	tLayerDesc* = RECORD (antsViews.tLayerDesc)
		E-: ants3dArrayObjects.tObject;
		img: Pictures.Picture;
		type: INTEGER;
		on: BOOLEAN
	END;

	Pattern = RECORD
		w, h, d: INTEGER;
		vals: POINTER TO ARRAY OF ARRAY OF INTEGER
	END;

VAR
	newlayer-: tLayer;  maxw, maxh: INTEGER;  texture: BOOLEAN;

	PROCEDURE Copy( source, dest: tLayer );
	BEGIN
		dest^ := source^
	END Copy;

	PROCEDURE MakePattern( layer: tLayer;  w, h: INTEGER ): Pattern;
	VAR p: Pattern;  y, x: LONGINT;  d: INTEGER;
	CONST fac = 3;  div = 8;
	BEGIN
		d := fac * w DIV div;  NEW( p.vals, h + d + 1, w + d + 1 );  p.w := w;  p.h := h;  p.d := d;
		(* rechteck *)
		FOR y := 0 TO (h + d) DO
			FOR x := 0 TO (w + d) DO
				p.vals[y, x] := MIN( INTEGER );

				IF (y > 0) & (x > 0) & (y < h) & (x < w) THEN  (* rechteck *)
					p.vals[y, x] := 1
				ELSIF ((y = 0) & (x < w)) OR ((x = 0) & (y < h)) OR
					((y = h) & (x < w)) OR ((x = w) & (y < h)) THEN  (*rechteck *)
					p.vals[y, x] := 2
				END;

				IF (x > w) & (y > (x - w)) THEN p.vals[y, x] := 1
				ELSIF (x > w) & (y = (x - w)) THEN p.vals[y, x] := 2
				END;

				IF (y > h) & (x > (y - h)) THEN p.vals[y, x] := 1
				ELSIF (y > h) & (x = (y - h)) THEN p.vals[y, x] := 2
				END;

				IF (y > h) & (x > w) & (y - h = x - w) THEN p.vals[y, x] := 2
				END;

				IF (y = h + d) & (x > d) THEN p.vals[y, x] := 2
				ELSIF (x = w + d) & (y > d) THEN p.vals[y, x] := 2
				END

			END
		END;
		RETURN p

	END MakePattern;

	PROCEDURE Max( a, b: INTEGER ): INTEGER;
	BEGIN
		IF a > b THEN RETURN a ELSE RETURN b END
	END Max;

	PROCEDURE Line( p: Pictures.Picture;  fx, fy, tx, ty: INTEGER;  col: INTEGER );
	VAR x, y, steps, pos: LONGINT;
	BEGIN
		steps := Max( ty - fy, tx - fx );
		IF steps <= 0 THEN RETURN END;
		pos := 0;
		WHILE (pos <= steps) DO
			x := fx + (tx - fx) * pos DIV steps;  y := fy + (ty - fy) * pos DIV steps;  Pictures.Dot( p, col, SHORT( x ), SHORT( y ), Display.replace );
			INC( pos )
		END

	END Line;

	PROCEDURE Recall( layer: tLayer );
	VAR pw, ph: INTEGER;  l, j, i: INTEGER;
		xx, yy: ARRAY 7 OF INTEGER;
		px, py, X, Y, W, H, dX, dY, dXl, dYl: INTEGER;  height, depth, width: INTEGER;  ox, oy: INTEGER;  p: Pattern;  r, g, b: INTEGER;
		data: POINTER TO ARRAY OF INTEGER;

		boxw, boxh, boxd: INTEGER;
	CONST fac = 2;  div = 5;

		PROCEDURE PaintPattern( p: Pattern;  pict: Pictures.Picture;  atx, aty, atz: INTEGER );
		VAR y, x, color: INTEGER;
		BEGIN
			IF (data = NIL ) OR (LEN( data ) # p.w + p.d + 1) THEN NEW( data, p.w + p.d + 1 ) END;

			FOR y := 0 TO (p.h + p.d) DO
				Pictures.GetLine( pict, data^, atx * p.w + atz * p.d, y + aty * p.h + atz * p.d, p.w + p.d + 1 );
				FOR x := 0 TO (p.w + p.d) DO
					color := p.vals[y, x];
					IF color # MIN( INTEGER ) THEN data[x] := color END
					(* Pictures.Dot(pict,color,x+atx*p.w+atz*p.d,y+aty*p.h+atz*p.d,Display.paint); *)
				END;
				Pictures.PutLine( pict, data^, atx * p.w + atz * p.d, y + aty * p.h + atz * p.d, p.w + p.d + 1 )

			END
		END PaintPattern;

	BEGIN
		antsViews.CheckColors( layer, layer.E.depth );

		vyGraphBase.SetForeColor( layer.style.fcol );  vyGraphBase.SetBackColor( layer.style.fillcol );
		vyGraphBase.Rect2dToRect( 0, 0, 1, 1, X, Y, dX, dY );  dXl := dX * fac DIV div;  dYl := dX * fac DIV div;

		vyGraphBase.Rect2dToRect( 0, 0, 1, 1, X, Y, W, H );   (* layer.E.d -> layer.E.h ? *)
		W := SHORT( W * layer.E.w DIV (layer.E.w + fac * layer.E.h DIV div) );
		H := SHORT( H * layer.E.d DIV (layer.E.d + fac * layer.E.h DIV div) );

		ox := X;  oy := Y;

		height := SHORT( layer.E.d );  width := SHORT( layer.E.w );  depth := SHORT( layer.E.h );

		xx[0] := X;  yy[0] := Y;  xx[1] := X + fac * W DIV div;  yy[1] := Y + fac * W DIV div;  xx[2] := xx[1];  yy[2] := yy[1] + H;
		xx[3] := xx[1] + W;  yy[3] := yy[1];

		IF layer.on THEN vyGraphBase.SetForeColor( layer.style.selectcol )
		ELSE vyGraphBase.SetForeColor( layer.style.fillcol )
		END;
		(*
	vyGraphBase.FrameFillArea(xx,yy,3);
	vyGraphBase.Line(xx[1],yy[1],xx[3],yy[3]);
	*)



		pw := (W) DIV width;  ph := (H) DIV height;  p := MakePattern( layer, pw, ph );
		IF (layer.img = NIL ) OR (layer.img.width # (pw * width + p.d * depth + 1)) OR
		    (layer.img.height # (ph * height + p.d * depth + 1)) THEN
			NEW( layer.img );  Pictures.Create( layer.img, (pw * width + p.d * depth + 1), (ph * height + p.d * depth + 1), 8 );
		END;
		Display.GetColor( layer.style.bcol, r, g, b );  Pictures.SetColor( layer.img, 0, r, g, b );
		Display.GetColor( layer.style.fillcol, r, g, b );  Pictures.SetColor( layer.img, 1, r, g, b );
		Display.GetColor( layer.style.fcol, r, g, b );  Pictures.SetColor( layer.img, 2, r, g, b );
		Display.GetColor( layer.style.selectcol, r, g, b );  Pictures.SetColor( layer.img, 3, r, g, b );
		Pictures.ReplConst( layer.img, 0, 0, 0, layer.img.width, layer.img.height, Display.replace );

		boxw := pw * width;  boxh := ph * height;  boxd := p.d * depth;

		Line( layer.img, 0, 0, boxd, boxd, 3 );  Line( layer.img, boxd, boxd, boxd, boxd + boxh, 3 );
		Line( layer.img, boxd, boxd, boxd + boxw, boxd, 3 );

		FOR l := 0 TO height - 1 DO
			FOR j := depth - 1 TO 0 BY -1 DO
				FOR i := 0 TO width - 1 DO
					IF layer.E.A[l, j, i] > 0 THEN PaintPattern( p, layer.img, i, l, j );  END;
				END;
			END;
		END;

		Line( layer.img, 0, 0, 0, boxh, 3 );  Line( layer.img, 0, 0, boxw, 0, 3 );  Line( layer.img, 0, boxh, boxw, boxh, 3 );
		Line( layer.img, boxw, 0, boxw, boxh, 3 );  Line( layer.img, boxw, 0, boxw + boxd, boxd, 3 );
		Line( layer.img, 0, boxh, boxd, boxd + boxh, 3 );  Line( layer.img, boxw, boxh, boxd + boxw, boxd + boxh, 3 );

		Line( layer.img, boxd, boxd + boxh, boxd + boxw, boxd + boxh, 3 );
		Line( layer.img, boxw + boxd, boxd, boxd + boxw, boxd + boxh, 3 );

		vyGraphBase.Pict( layer.img, 0, 0, layer.img.width, layer.img.height, X, Y );

		layer.on := FALSE;

		IF layer.on THEN
			vyGraphBase.SetDisplayStyle( {Display3.filled} );  vyGraphBase.SetBackColor( layer.style.fillcol );
			FOR l := 0 TO height - 1 DO  (* height coordinate *)
				FOR j := depth - 1 TO 0 BY -1 DO  (* depth coordinate *)
					FOR i := 0 TO width - 1 DO  (* width coordinate *)
						IF layer.E.A[l, j, i] > 0 THEN
							xx[0] := X + W * i DIV width + W * j DIV depth * fac DIV div;
							yy[0] := Y + H * l DIV height + W * j DIV depth * fac DIV div;
							px := X + W * (i + 1) DIV width + W * j DIV depth * fac DIV div;
							py := Y + H * (l + 1) DIV height + W * j DIV depth * fac DIV div;  xx[1] := px;  yy[1] := yy[0];
							xx[3] := X + W * (i + 1) DIV width + W * (j + 1) DIV depth * fac DIV div;
							yy[3] := Y + H * (l + 1) DIV height + W * (j + 1) DIV depth * fac DIV div;  xx[2] := xx[3];
							yy[2] := Y + H * (l) DIV height + W * (j + 1) DIV depth * fac DIV div;
							xx[4] := X + W * i DIV width + W * (j + 1) DIV depth * fac DIV div;  yy[4] := yy[3];  xx[5] := xx[0];
							yy[5] := py;  xx[6] := xx[0];  yy[6] := yy[0];

							vyGraphBase.SetForeColor( layer.style.fillcol );  vyGraphBase.PaintFillArea( xx, yy, 6 );  xx[4] := px;
							yy[4] := py;  vyGraphBase.SetForeColor( layer.style.fcol );  vyGraphBase.FrameFillArea( xx, yy, 7 );
							xx[0] := xx[1];  yy[0] := yy[1];  xx[1] := px;  yy[1] := py;  xx[2] := xx[3];  yy[2] := yy[3];
							xx[3] := X + W * i DIV width + W * (j + 1) DIV depth * fac DIV div;  yy[3] := yy[2];  yy[4] := yy[5];
							xx[4] := xx[5];  vyGraphBase.FrameFillArea( xx, yy, 5 );
						END;
					END;
				END;
			END;
		END;
		xx[0] := X - 1;  yy[0] := Y;  xx[1] := X + W;  yy[1] := Y;  xx[2] := X + W + W * fac DIV div;  yy[2] := Y + W * fac DIV div;
		xx[3] := xx[2];  yy[3] := yy[2] + H;  xx[4] := xx[3] - W - 1;  yy[4] := yy[3];  xx[5] := X - 1;  yy[5] := Y + H;
		xx[6] := xx[0];  yy[6] := yy[0];

		(*
	IF layer.on THEN
	vyGraphBase.SetForeColor(layer.style.selectcol);
	ELSE
	vyGraphBase.SetForeColor(layer.style.fillcol);
	vyGraphBase.PaintFillArea(xx,yy,7);
	END;
	vyGraphBase.SetForeColor(layer.style.selectcol);
	vyGraphBase.FrameFillArea(xx,yy,7);

	vyGraphBase.Line(xx[5],yy[5],xx[5]+W,yy[5]);
	vyGraphBase.Line(xx[1],yy[1],xx[1],yy[1]+H);
	vyGraphBase.Line(xx[1],yy[1]+H,xx[3],yy[3]);
	*)

	END Recall;

	PROCEDURE Responsible( layer: tLayer;  VAR event: vyEvents.EventMsg );
	VAR priority: INTEGER;
	BEGIN
		priority := vyEvents.PrioNone;
		IF ((event.gesture = vyEvents.EvtIdent)) THEN priority := vyEvents.PrioNormal END;
		IF event.priority < priority THEN event.responder := layer;  event.priority := priority END
	END Responsible;

	PROCEDURE HandleFileMsg( obj: tLayer;  VAR msg: Objects.FileMsg );
	VAR objsub: Objects.Object;  version: INTEGER;
	BEGIN
		IF msg.id = Objects.load THEN
			Files.ReadInt( msg.R, version );  antsViews.Handler( obj, msg );  Gadgets.ReadRef( msg.R, obj.lib, objsub );
			IF (objsub # NIL ) & (objsub IS ants3dArrayObjects.tObject) THEN obj.E := objsub( ants3dArrayObjects.tObject ) END;
			Files.ReadInt( msg.R, obj.type );
		ELSIF msg.id = Objects.store THEN
			ASSERT ( obj.lib = obj.E.lib, 100 );
			Files.WriteInt( msg.R, 0 );  antsViews.Handler( obj, msg );  Gadgets.WriteRef( msg.R, obj.lib, obj.E );
			Files.WriteInt( msg.R, obj.type );
		ELSE antsViews.Handler( obj, msg )
		END
	END HandleFileMsg;

	PROCEDURE HandleAttributes( obj: tLayer;  VAR M: Objects.AttrMsg );
	BEGIN
		IF M.id = Objects.enum THEN M.Enum( "Gen" );  M.Enum( "type" );  antsViews.Handler( obj, M )
		ELSIF M.id = Objects.get THEN
			IF M.name = "Gen" THEN COPY( 'ants3dArrayViews.New', M.s );  M.class := Objects.String;  M.res := 0
			ELSIF M.name = "type" THEN
				IF obj.type = hEdges THEN M.s := "hEdges"
				ELSIF obj.type = vEdges THEN M.s := "vEdges"
				ELSIF obj.type = Vertices THEN M.s := "Vertices"
				ELSE M.s := "Plain"
				END;
				M.class := Objects.String;  M.res := 0;
			ELSE antsViews.Handler( obj, M )
			END
		ELSIF M.id = Objects.set THEN
			IF M.name = "type" THEN
				IF M.class = Objects.String THEN
					IF M.s = "hEdges" THEN obj.type := hEdges
					ELSIF M.s = "vEdges" THEN obj.type := vEdges
					ELSIF M.s = "Vertices" THEN obj.type := Vertices
					ELSE obj.type := Plain
					END;
					vyBase.Update( obj );  M.res := 0;
				END;
			ELSE antsViews.Handler( obj, M )
			END;
		ELSE antsViews.Handler( obj, M )
		END
	END HandleAttributes;

	PROCEDURE HandleLinks( obj: tLayer;  VAR msg: Objects.LinkMsg );
	BEGIN
		IF (msg.id = Objects.enum) THEN msg.Enum( "E" );  antsViews.Handler( obj, msg )
		ELSIF (msg.id = Objects.get) & (msg.name = "E") THEN msg.obj := obj.E;  msg.res := 0
		ELSIF (msg.id = Objects.set) & ((msg.name = "E") OR (msg.name = "Model")) & (msg.obj # NIL ) &
				(msg.obj IS ants3dArrayObjects.tObject) THEN
		ELSE antsViews.Handler( obj, msg )
		END
	END HandleLinks;

	PROCEDURE Handler*( o: Objects.Object;  VAR msg: Objects.ObjMsg );
	VAR layer, copy: tLayer;  done: BOOLEAN;
	BEGIN
		ASSERT ( o IS tLayer, 100 );
		layer := o( tLayer );  done := FALSE;
		IF msg IS Display.DisplayMsg THEN
			WITH msg: Display.DisplayMsg DO Recall( layer );  done := TRUE;
			END;
		ELSIF msg IS vyBase.UpdateMessage THEN
			WITH msg: vyBase.UpdateMessage DO antsViews.Handler( layer, msg );
			END;
		ELSIF msg IS vyEvents.EventMsg THEN
			WITH msg: vyEvents.EventMsg DO
				IF msg.callForResponder THEN Responsible( layer, msg ) ELSE antsViews.Handler( layer, msg ) END;
				done := TRUE
			END;
		ELSIF msg IS Objects.CopyMsg THEN
			WITH msg: Objects.CopyMsg DO
				NEW( copy );  msg.obj := copy;  Copy( layer, msg.obj( tLayer ) );  antsViews.Handler( layer, msg );  done := TRUE
			END;
		ELSIF msg IS Objects.FileMsg THEN
			WITH msg: Objects.FileMsg DO HandleFileMsg( layer, msg )
			END;
		ELSIF msg IS Objects.AttrMsg THEN
			WITH msg: Objects.AttrMsg DO HandleAttributes( layer, msg )
			END;
		ELSIF msg IS Objects.LinkMsg THEN
			WITH msg: Objects.LinkMsg DO HandleLinks( layer, msg )
			END;
		ELSIF msg IS Objects.BindMsg THEN
			WITH msg: Objects.BindMsg DO
				IF layer.lib # msg.lib THEN antsViews.Handler( layer, msg );  antsObjects.Bind( layer.E, msg );  END;
			END;
		ELSE antsViews.Handler( layer, msg );
		END;
		IF ~done THEN END
	END Handler;

	PROCEDURE OnOff;
	BEGIN
		antsViews.tempLayer( tLayer ).on := ~antsViews.tempLayer( tLayer ).on;  vyBase.Update( antsViews.tempLayer );
	END OnOff;

	PROCEDURE Init( layer: tLayer );
	BEGIN
		antsViews.Init( layer );  layer.handle := Handler;  layer.on := TRUE;  vyCommandMenus.Add( layer.commands, OnOff, "OnOff" );
	END Init;

	PROCEDURE Open*( layer: tLayer;  E: ants3dArrayObjects.tObject;  type: INTEGER );
	VAR id: vyName.tNameArray;
	BEGIN
		Init( layer );  id := "ViewI:";  vyName.AppendObjId( E, id );  vyPort.OpenLayer( layer, id );  layer.E := E;  layer.pal.first := 0;
		layer.pal.last := SHORT( E.depth - 1 );  antsViews.DefaultPath( layer, texture );  texture := FALSE;

		layer.type := type;  vyBase.Subscribe( layer.E, layer )
	END Open;

	PROCEDURE New*;
	BEGIN
		aM.cmd;  NEW( newlayer );  Init( newlayer );  Objects.NewObj := newlayer
	END New;

	PROCEDURE DoShow*( E: ants3dArrayObjects.tObject;  type: INTEGER;  add: BOOLEAN;  VAR c: vyDisplay2d.tCoordinate2d ): tLayer;
	VAR port: vyPort.Frame;  picture: vyPort.Picture;  layer: tLayer;  w, h: INTEGER;
	BEGIN
		NEW( layer );  Open( layer, E, type );
		IF c = NIL THEN NEW( c );  vyDisplay2d.OpenC2d( c, 0, 0, E.w + E.h / 2, E.d + E.h / 2 ) END;
		IF ~add THEN
			w := SHORT( E.w + 10 );  h := SHORT( E.h + 10 );
			IF w > maxw THEN w := maxw END;
			IF h > maxh THEN h := maxh END;
			port := vyPort.XNewFrame( w + 2 * vyPort.Border, h + 2 * vyPort.Border );  port.W := (w + 2 * vyPort.Border);
			port.H := (h + 2 * vyPort.Border);  picture := vyPort.NewP( c );  picture.W := (w);  picture.H := (h);
			picture.backGround := vyGraphBase.dgrey;  vyPort.AddPicture( port, picture, 0, 0, 1, 1 )
		ELSE picture := vyPort.GetFocusPicture()
		END;
		layer.style.fcol := vyGraphBase.black;  layer.style.fillcol := vyGraphBase.red;
		layer.style.selectcol := vyGraphBase.yellow;  layer.style.style := {Display3.filled};
		IF type = Vertices THEN layer.style.fcol := vyGraphBase.red END;
		vyPort.AddLayer( picture, layer );
		IF ~add THEN vyHostTexts.InsertGadget( port ) END;
		RETURN layer
	END DoShow;

	PROCEDURE Show*;
	VAR l: antsCommands.tScanList;  obj, o: vyBase.Object;  la: tLayer;  name: vyName.tNameArray;  hor, ver, add: BOOLEAN;
		c: vyDisplay2d.tCoordinate2d;  type: INTEGER;
	BEGIN
		l := antsCommands.ScanFromPar( "name=NAME [>hEdges][>vEdges][>Vertices][>add][>texture]" );
		IF antsCommands.ExpectNameFromKeyword( l, "name", name ) THEN
			hor := FALSE;  ver := FALSE;
			IF antsCommands.FindKeyword( l, "hEdges" ) THEN type := hEdges
			ELSIF antsCommands.FindKeyword( l, "vEdges" ) THEN type := vEdges
			ELSIF antsCommands.FindKeyword( l, "Vertices" ) THEN type := Vertices
			ELSE type := Plain
			END;
			add := antsCommands.FindKeyword( l, "add" );
			IF antsCommands.FindKeyword( l, "texture" ) THEN texture := TRUE END;
			obj := vyName.FindObj( name );  o := obj;  la := DoShow( o( ants3dArrayObjects.tObject ), type, add, c )
		END
	END Show;

	PROCEDURE ShowP*;
	VAR data: Objects.Object;  editor: tLayer;  c: vyDisplay2d.tCoordinate2d;
	BEGIN
		data := vyBase.NextParObj();
		WHILE (data # NIL ) DO
			editor := DoShow( data( ants3dArrayObjects.tObject ), Plain, FALSE , c );  data := vyBase.NextParObj()
		END
	END ShowP;

BEGIN
	aM.launch;  maxw := Display.Width DIV 3;  maxh := Display.Height DIV 3;  texture := FALSE;
END ants3dArrayViews.
System.Free ants3dArrayViews~

antsArrayObjects.New testarray 100 100 2 ~
antsArrayObjects.Uniform testarray ~
antsArrayViews.Show testarray ~

fofAutomatic.Do
ants3dArrayObjects.New testarray 20 20 80   2 ~
ants3dArrayViews.Show testarray ~
ants3dArrayObjects.Example testarray ~
ants3dBinaryIsingS2.NewModel > name Model  > h 0.0 > beta 0.4 ~
antsKernel.Define > name Sampler ~
antsKernel.AttachModel > sampler Sampler > model Model ~
antsKernel.AttachArray > sampler Sampler > array testarray ~
antsMC.New chain ~
antsMC.Add chain Sampler ~
~
fofAutomatic.Do > interactive
antsMC.Forward chain 1 1 ~
~
antsMC.Init chain ~~~
System.Free ants3dBinaryIsingS2 ~
