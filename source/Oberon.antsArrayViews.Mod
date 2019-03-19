MODULE antsArrayViews IN Oberon;   (* fof *)
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




IMPORT vyPort, vyName, vyBase, vyGraphBase, Display, vyEvents, antsArrayObjects, antsViews, antsColors, Files, antsObjects,
	vyRectangles, antsCommands, antsPictCoordinate, Objects, vyCommandMenus, Gadgets, vyHostTexts, aM := antsMessages;

CONST
	Vertices* = 0;  vEdges* = 1;  hEdges* = 2;  Plain* = 3;

TYPE

	tLayer* = POINTER TO tLayerDesc;
	tLayerDesc* = RECORD (antsViews.tLayerDesc)
		E-: antsArrayObjects.tINTEGERObject;
		type: INTEGER
	END;

VAR
	newlayer-: tLayer;  maxw, maxh: INTEGER;  texture: BOOLEAN;

	PROCEDURE Copy( source, dest: tLayer );
	BEGIN
		dest^ := source^
	END Copy;

	PROCEDURE GetRunX( A: antsArrayObjects.tINTEGERArray;  VAR col: INTEGER;  VAR x, y, w: INTEGER );
	BEGIN
		col := A[y, x];
		WHILE (A[y, x] = col) DO
			INC( x );
			IF x > w - 1 THEN RETURN END
		END;
		RETURN
	END GetRunX;

	PROCEDURE GetRunY( A: antsArrayObjects.tINTEGERArray;  VAR col: INTEGER;  VAR x, y, h: INTEGER );
	BEGIN
		col := A[y, x];
		WHILE (A[y, x] = col) DO
			INC( y );
			IF y > h - 1 THEN RETURN END
		END;
		RETURN
	END GetRunY;

	PROCEDURE Recall( layer: tLayer );
	VAR px, py, pw, ph, px0, py0, col, width: INTEGER;  y0, x0: INTEGER;  vx, vy, vpx, vpy, vpw, vph: INTEGER;  c: antsPictCoordinate.tCoordinate;
		pal: antsColors.Palette;
	BEGIN
		antsViews.CheckColors( layer, layer.E( antsArrayObjects.tINTEGERObject ).depth );
		vyGraphBase.SetForeColor( layer.style.fcol );  layer.refArray := layer.E;  c := antsPictCoordinate.tc;
		IF c.dx > 4 THEN width := 3 ELSE width := 1 END;   (* remove !*)

		vx := c.vx;  vy := c.vy;   (* coordinates of first visible point in array coordinates*)
		vpx := c.px;  vpy := c.py;  vpw := c.pw;  vph := c.ph;   (* coordinates of visible area in display-array coordinates (with stretching) *)
		pw := SHORT( layer.E.w );  ph := SHORT( layer.E.h );   (* array width and height *)
		c.pictW := pw;  c.pictH := ph;  vyRectangles.RectIntersection( vpx, vpy, vpw, vph, 0, 0, SHORT( layer.E.w ), SHORT( layer.E.h ) );

		IF layer.type = Vertices THEN  (* vertices *)
			px := vpx;  x0 := vx;
			WHILE px < (vpw + vpx) DO
				py := vpy;  y0 := vy;
				WHILE py < vpy + vph DO
					col := layer.E.A[py, px];
					IF col = 1 THEN vyGraphBase.ReplConst( x0 - width DIV 2, y0 - width DIV 2, width, width ) END;
					INC( py );  INC( y0, c.dy )
				END;
				INC( px );  INC( x0, c.dx )
			END
		ELSIF (layer.type = hEdges) THEN  (* hor edges *)
			py := vpy;  y0 := vy;
			WHILE py < vpy + vph DO
				px := vpx;  x0 := vx;
				WHILE px < (vpw + vpx) DO
					px0 := px;  GetRunX( layer.E.A, col, px0, py, pw );
					IF col = 1 THEN vyGraphBase.ReplConst( x0, y0 - width DIV 2, c.dx * (px0 - px), width ) END;
					INC( x0, (px0 - px) * c.dx );  px := px0
				END;
				INC( py );  INC( y0, c.dy )
			END
		ELSIF (layer.type = Plain) THEN
			pal := layer.pal;  py := vpy;  y0 := vy;
			WHILE py < vpy + vph DO
				px := vpx;  x0 := vx;
				WHILE px < (vpw + vpx) DO
					px0 := px;  GetRunX( layer.E.A, col, px0, py, pw );  vyGraphBase.SetForeColor( pal.dcol[col] );
					vyGraphBase.ReplConst( x0, y0, c.dx * (px0 - px), c.dx );  INC( x0, (px0 - px) * c.dx );  px := px0
				END;
				INC( py );  INC( y0, c.dy )
			END
		ELSIF layer.type = vEdges THEN  (* ver edges *)
			px := vpx;  x0 := vx;
			WHILE px < (vpw + vpx) DO
				py := vpy;  y0 := vy;
				WHILE py < vpy + vph DO
					py0 := py;  GetRunY( layer.E.A, col, px, py0, ph );
					IF col = 1 THEN vyGraphBase.ReplConst( x0 - width DIV 2, y0, width, c.dy * (py0 - py) ) END;
					INC( y0, (py0 - py) * c.dy );  py := py0
				END;
				INC( px );  INC( x0, c.dx )
			END
		END;

		IF layer.grid THEN
			vyGraphBase.SetForeColor( layer.style.fcol );  vx := vpx;
			WHILE (vx < vpx + vpw) DO vyGraphBase.Line2d( vx, vpy, vx, vpy + vph );  INC( vx ) END;
			vy := vpy;
			WHILE (vy < vpy + vph) DO vyGraphBase.Line2d( vpx, vy, vpx + vpw, vy );  INC( vy ) END
		END

	END Recall;

	PROCEDURE Responsible( layer: tLayer;  VAR event: vyEvents.EventMsg );
	VAR priority: INTEGER;
	BEGIN
		priority := vyEvents.PrioNone;
		IF ((event.gesture = vyEvents.EvtIdent)) THEN priority := vyEvents.PrioNormal END;
		IF event.priority < priority THEN event.responder := layer;  event.priority := priority END
	END Responsible;

	PROCEDURE Center;
	VAR tempLayer: tLayer;
	BEGIN
		tempLayer := antsViews.tempLayer( tLayer );
		antsPictCoordinate.Center( SHORT( tempLayer.E.w ), SHORT( tempLayer.E.h ), antsPictCoordinate.tc );  vyBase.Update( tempLayer )
	END Center;

	PROCEDURE HandleFileMsg( obj: tLayer;  VAR msg: Objects.FileMsg );
	VAR objsub: Objects.Object;  version: INTEGER;
	BEGIN
		IF msg.id = Objects.load THEN
			Files.ReadInt( msg.R, version );  antsViews.Handler( obj, msg );  Gadgets.ReadRef( msg.R, obj.lib, objsub );
			IF (objsub # NIL ) & (objsub IS antsArrayObjects.tObject) THEN obj.E := objsub( antsArrayObjects.tINTEGERObject ) END;
			Files.ReadInt( msg.R, obj.type )
		ELSIF msg.id = Objects.store THEN
			ASSERT ( obj.lib = obj.E.lib, 100 );
			Files.WriteInt( msg.R, 0 );  antsViews.Handler( obj, msg );  Gadgets.WriteRef( msg.R, obj.lib, obj.E );
			Files.WriteInt( msg.R, obj.type )
		ELSE antsViews.Handler( obj, msg )
		END
	END HandleFileMsg;

	PROCEDURE HandleAttributes( obj: tLayer;  VAR M: Objects.AttrMsg );
	BEGIN
		IF M.id = Objects.enum THEN M.Enum( "Gen" );  M.Enum( "type" );  antsViews.Handler( obj, M )
		ELSIF M.id = Objects.get THEN
			IF M.name = "Gen" THEN COPY( 'antsArrayViews.New', M.s );  M.class := Objects.String;  M.res := 0
			ELSIF M.name = "type" THEN
				IF obj.type = hEdges THEN M.s := "hEdges"
				ELSIF obj.type = vEdges THEN M.s := "vEdges"
				ELSIF obj.type = Vertices THEN M.s := "Vertices"
				ELSE M.s := "Plain"
				END;
				M.class := Objects.String;  M.res := 0
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
					vyBase.Update( obj );  M.res := 0
				END
			ELSE antsViews.Handler( obj, M )
			END
		ELSE antsViews.Handler( obj, M )
		END
	END HandleAttributes;

	PROCEDURE HandleLinks( obj: tLayer;  VAR msg: Objects.LinkMsg );
	BEGIN
		IF (msg.id = Objects.enum) THEN msg.Enum( "E" );  antsViews.Handler( obj, msg )
		ELSIF (msg.id = Objects.get) & (msg.name = "E") THEN msg.obj := obj.E;  msg.res := 0
		ELSIF (msg.id = Objects.set) & ((msg.name = "E") OR (msg.name = "Model")) & (msg.obj # NIL ) &
				(msg.obj IS antsArrayObjects.tObject) THEN
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
				IF msg.callForResponder THEN Responsible( layer, msg );  antsViews.Handler( layer, msg )
				ELSE antsViews.Handler( layer, msg )
				END;
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
				IF msg.lib # layer.lib THEN antsViews.Handler( layer, msg );  antsObjects.Bind( layer.E, msg ) END
			END;
		ELSE antsViews.Handler( layer, msg )
		END;
		IF ~done THEN END
	END Handler;

	PROCEDURE Init( layer: tLayer );
	BEGIN
		antsViews.Init( layer );  layer.handle := Handler;  vyCommandMenus.Add( layer.commands, Center, "Center" )
	END Init;

	PROCEDURE Open*( layer: tLayer;  E: antsArrayObjects.tINTEGERObject;  type: INTEGER );
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

	PROCEDURE DoShow*( E: antsArrayObjects.tINTEGERObject;  type: INTEGER;  add: BOOLEAN;  VAR c: antsPictCoordinate.tCoordinate ): tLayer;
	VAR port: vyPort.Frame;  picture: vyPort.Picture;  layer: tLayer;  w, h: INTEGER;
	BEGIN
		NEW( layer );  Open( layer, E, type );
		IF c = NIL THEN NEW( c );  antsPictCoordinate.OpenC( c, 1, 1 ) END;
		IF ~add THEN
			w := SHORT( E.w );  h := SHORT( E.h );
			IF w > maxw THEN w := maxw END;
			IF h > maxh THEN h := maxh END;
			port := vyPort.XNewFrame( w + 2 * vyPort.Border, h + 2 * vyPort.Border );  port.W := (w + 2 * vyPort.Border);
			port.H := (h + 2 * vyPort.Border);  picture := vyPort.NewP( c );  picture.W := (w);  picture.H := (h);
			picture.backGround := vyGraphBase.dgrey;  vyPort.AddPicture( port, picture, 0, 0, 1, 1 )
		ELSE picture := vyPort.GetFocusPicture()
		END;
		layer.style.fcol := vyGraphBase.green;  layer.style.fillcol := vyGraphBase.red;
		IF type = Vertices THEN layer.style.fcol := vyGraphBase.red END;
		vyPort.AddLayer( picture, layer );
		IF ~add THEN vyHostTexts.InsertGadget( port ) END;
		RETURN layer
	END DoShow;

	PROCEDURE Show*;
	VAR l: antsCommands.tScanList;  obj, o: vyBase.Object;  la: tLayer;  name: vyName.tNameArray;  hor, ver, add: BOOLEAN;
		c: antsPictCoordinate.tCoordinate;  type: INTEGER;
	BEGIN
		l := antsCommands.ScanFromPar( "name=NAME [>hEdges|>vEdges|>Vertices] [>add] [>texture]" );
		IF antsCommands.ExpectNameFromKeyword( l, "name", name ) THEN
			hor := FALSE;  ver := FALSE;
			IF antsCommands.FindKeyword( l, "hEdges" ) THEN type := hEdges
			ELSIF antsCommands.FindKeyword( l, "vEdges" ) THEN type := vEdges
			ELSIF antsCommands.FindKeyword( l, "Vertices" ) THEN type := Vertices
			ELSE type := Plain
			END;
			add := antsCommands.FindKeyword( l, "add" );
			IF antsCommands.FindKeyword( l, "texture" ) THEN texture := TRUE END;
			obj := vyName.FindObj( name );  o := obj;  la := DoShow( o( antsArrayObjects.tINTEGERObject ), type, add, c )
		END
	END Show;

	PROCEDURE ShowP*;
	VAR data: Objects.Object;  editor: tLayer;  c: antsPictCoordinate.tCoordinate;
	BEGIN
		data := vyBase.NextParObj();
		WHILE (data # NIL ) DO
			editor := DoShow( data( antsArrayObjects.tINTEGERObject ), Plain, FALSE , c );  data := vyBase.NextParObj()
		END
	END ShowP;

BEGIN
	aM.launch;  maxw := Display.Width DIV 3;  maxh := Display.Height DIV 3;  texture := FALSE
END antsArrayViews.
System.Free antsArrayViews~

antsArrayObjects.New testarray 100 100 2 ~
antsArrayObjects.Uniform testarray ~
antsArrayViews.Show testarray ~
