MODULE antsColors IN Oberon;   (** fof   **)
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




IMPORT Display, antsCommands, Colors, vyBase, Objects, Gadgets, Files, vyPort, vyEvents, vyName, antsObjects,
	vyCommandMenus, aM := antsMessages, vyGraphBase, vyDisplay2d, vyTracking, Input, Attributes, Oberon, antsToolbox,
	vyHostTexts, Effects, vyColorPalettes, Texts;

TYPE
	Palette* = vyColorPalettes.Palette;

	tLayer* = POINTER TO tLayerDesc;
	tLayerDesc* = RECORD (vyPort.tLayerDesc)
		p-: Palette
	END;

VAR
	tempLayer: tLayer;

	PROCEDURE PNew*;   (* for Consistency with older version, do not remove! *)
	BEGIN
		aM.cmd;  vyColorPalettes.PNew
	END PNew;

	PROCEDURE Copy( source, dest: tLayer );
	BEGIN
		dest^ := source^
	END Copy;

	PROCEDURE Recall( layer: tLayer );
	VAR x, y, i: SIGNED16;  col: SIGNED32;  w, h: SIGNED16;
	BEGIN
		vyGraphBase.Rect2dToRect( 0, 0, 1, 1, x, y, w, h );
		FOR y := 0 TO 15 DO
			FOR x := 0 TO 15 DO
				i := ((15 - y) * 16 + (x));
				IF (layer.p # NIL ) & (layer.p.col[i] # NIL ) & (i < layer.p.used) THEN
					Colors.GetDisplay( layer.p.col[i], col );  vyGraphBase.SetBackColor( col );  vyGraphBase.EraseRect2d( x, y, 1, 1 )
					(* vyGraphBase.FrameRect2d(x,y,1,1); *)
				ELSE vyGraphBase.FrameRect2d( x, y, 1, 1 )
				END
			END
		END;
		IF w > 5 THEN
			FOR x := 0 TO 16 DO vyGraphBase.Line2d( 0, x, 16, x );  vyGraphBase.Line2d( x, 0, x, 16 ) END
		END;
		vyGraphBase.SetDisplayMode( vyGraphBase.invert );  y := 15 - layer.p.first DIV 16;  x := layer.p.first MOD 16;
		vyGraphBase.PaintRect2d( x + 0.25, y + 0.25, 0.5, 0.5 );  y := 15 - (layer.p.last) DIV 16;  x := (layer.p.last) MOD 16;
		vyGraphBase.PaintRect2d( x + 0.25, y + 0.25, 0.5, 0.5 );  vyGraphBase.SetDisplayMode( vyGraphBase.paint )
	END Recall;

	PROCEDURE LGetCol*( l: tLayer;  x, y: SIGNED16;  VAR index: SIGNED16 ): BOOLEAN;
	VAR x2d, y2d: FLOAT64;
	BEGIN
		vyGraphBase.PointToPoint2d( x, y, x2d, y2d );
		IF (x2d < 0) OR (y2d < 0) OR (x2d > 16) OR (y2d > 16) THEN RETURN FALSE END;
		x := SHORT( ENTIER( x2d ) );  y := SHORT( ENTIER( y2d ) );  index := ((15 - y) * 16 + (x));  RETURN TRUE
	END LGetCol;

	PROCEDURE rgbp( p: Palette;  first, last: SIGNED16 );
	VAR r1, r2, g1, g2, b1, b2: FLOAT32;
	BEGIN
		Colors.GetRGB( p.col[first], r1, g1, b1 );  Colors.GetRGB( p.col[last], r2, g2, b2 );
		vyColorPalettes.RGBPath( p, first, last, r1, g1, b1, r2, g2, b2 )
	END rgbp;

	PROCEDURE Prompt( layer: tLayer;  VAR event: vyEvents.EventMsg );
	VAR index, index2: SIGNED16;  dx, dy: SIGNED16;
	BEGIN
		IF LGetCol( layer, event.x, event.y, index ) THEN
			vyTracking.FramedString( event.x + 10, event.y, "Syntax10.Scn.Fnt", "smear to?", dx, dy );
			IF LGetCol( layer, event.x + dx, event.y + dy, index2 ) THEN
				IF index2 > index THEN rgbp( layer.p, index, index2 )
				ELSIF index > index2 THEN rgbp( layer.p, index2, index )
				END
			END
		END
	END Prompt;

	PROCEDURE Select( layer: tLayer;  VAR event: vyEvents.EventMsg );
	VAR index, index2: SIGNED16;  dx, dy: SIGNED16;  r, g, b: FLOAT32;  dcol: SIGNED32;  r1, g1, b1: FLOAT32;  dcol1: SIGNED32;
	BEGIN
		IF LGetCol( layer, event.x, event.y, index ) THEN
			vyTracking.FramedString( event.x + 10, event.y, "Syntax10.Scn.Fnt", "exchange with ?", dx, dy );
			IF LGetCol( layer, event.x + dx, event.y + dy, index2 ) THEN
				IF index2 # index THEN
					Colors.GetRGB( layer.p.col[index], r, g, b );  Colors.GetRGB( layer.p.col[index2], r1, g1, b1 );
					Colors.SetRGB( layer.p.col[index2], r, g, b );  Colors.SetRGB( layer.p.col[index], r1, g1, b1 );
					Colors.GetDisplay( layer.p.col[index2], dcol );  Colors.GetDisplay( layer.p.col[index], dcol1 );
					vyColorPalettes.SetCol( layer.p, index2, dcol );  vyColorPalettes.SetCol( layer.p, index, dcol1 )
					(*
				layer.p.dcol[index2] := dcol;  layer.p.dcol[index] := dcol1;
				Images.SetRGB(layer.p.icol[index2],SHORT(ENTIER(r*255+0.5)),SHORT(ENTIER(g*255+0.5)),SHORT(ENTIER(b*255+0.5)));
				Images.SetRGB(layer.p.icol[index],SHORT(ENTIER(r1*255+0.5)),SHORT(ENTIER(g1*255+0.5)),SHORT(ENTIER(b1*255+0.5)));
				*)
				END
			END
		END;
		vyBase.Update( layer.p )
	END Select;

	PROCEDURE Responsible( layer: tLayer;  VAR event: vyEvents.EventMsg );
	VAR priority: SIGNED16;
	BEGIN
		priority := vyEvents.PrioNone;
		IF ((event.gesture = vyEvents.EvtIdent) OR (event.gesture = vyEvents.EvtSelect)) THEN priority := vyEvents.PrioNormal END;
		IF event.priority < priority THEN event.responder := layer;  event.priority := priority END
	END Responsible;

	PROCEDURE HandleFileMsg( obj: tLayer;  VAR msg: Objects.FileMsg );
	VAR objsub: Objects.Object;  version: SIGNED16;
	BEGIN
		IF msg.id = Objects.load THEN
			Files.ReadInt( msg.R, version );  vyPort.LayerHandler( obj, msg );  Gadgets.ReadRef( msg.R, obj.lib, objsub );
			IF (objsub # NIL ) & (objsub IS Palette) THEN obj.p := objsub( Palette ) END
		ELSIF msg.id = Objects.store THEN
			Files.WriteInt( msg.R, 0 );   (* version id *)
			vyPort.LayerHandler( obj, msg );  Gadgets.WriteRef( msg.R, obj.lib, obj.p )
		ELSE vyPort.LayerHandler( obj, msg )
		END
	END HandleFileMsg;

	PROCEDURE HandleAttributes( obj: tLayer;  VAR M: Objects.AttrMsg );
	BEGIN
		IF M.id = Objects.enum THEN M.Enum( "Gen" );  vyPort.LayerHandler( obj, M )
		ELSIF M.id = Objects.get THEN
			IF M.name = "Gen" THEN COPY( 'antsColors.New', M.s );  M.class := Objects.String;  M.res := 0 ELSE vyPort.LayerHandler( obj, M ) END
		ELSIF M.id = Objects.set THEN vyPort.LayerHandler( obj, M )
		ELSE vyPort.LayerHandler( obj, M )
		END
	END HandleAttributes;

	PROCEDURE HandleLinks( obj: tLayer;  VAR msg: Objects.LinkMsg );
	BEGIN
		IF (msg.id = Objects.enum) THEN msg.Enum( "p" );  vyPort.LayerHandler( obj, msg )
		ELSIF (msg.id = Objects.get) & (msg.name = "p") THEN msg.obj := obj.p;  msg.res := 0
		ELSE vyPort.LayerHandler( obj, msg )
		END
	END HandleLinks;

	PROCEDURE SendColors;
	VAR keys: SET;  x, y, dx, dy: SIGNED16;  msg: vyColorPalettes.GetColMsg;
	BEGIN
		Input.Mouse( keys, x, y );
		WHILE (keys # {}) DO Input.Mouse( keys, x, y ) END;

		msg.pal := NIL;
		(*
	vyTracking.FramedString(x+10,y,"Syntax.10.Scn.Fnt","Destination ?",dx,dy);
	antsToolbox.MsgToXY(x+dx,y+dy,msg);
	*)
		vyTracking.HelpAt( x, y, "move mouse to destination and click" );  vyTracking.TrackMouseCont( keys, dx, dy, Effects.PointHand );
		antsToolbox.MsgToXY( dx, dy, msg );   (* better to do by interactive msg ! *)
		vyTracking.HelpEnd;

		IF msg.pal # NIL THEN vyColorPalettes.CopyPalette( tempLayer.p, msg.pal );  vyBase.Update( msg.pal )
		END
	END SendColors;

	PROCEDURE openfile( VAR f: Files.File;  name: ARRAY OF CHAR );
	VAR msg: Objects.FileMsg;
	BEGIN
		IF f = NIL THEN RETURN END;
		msg.id := Objects.load;  Files.Set( msg.R, f, 0 );  tempLayer.p.handle( tempLayer.p, msg );
		vyBase.Update( tempLayer.p )
	END openfile;

	PROCEDURE LoadPal;
	BEGIN
		antsToolbox.FileOpen( openfile, "*.antsPalette", "*.antsPalette" )
	END LoadPal;

	PROCEDURE storefile( VAR f: Files.File;  name: ARRAY OF CHAR );
	VAR msg: Objects.FileMsg;
	BEGIN
		IF f = NIL THEN RETURN END;
		msg.id := Objects.store;  Files.Set( msg.R, f, 0 );  tempLayer.p.handle( tempLayer.p, msg )
	END storefile;

	PROCEDURE StorePal;
	BEGIN
		antsToolbox.FileStore( storefile, "*.antsPalette", "*.antsPalette", "antsPalette", "my.antsPalette" )
	END StorePal;

	PROCEDURE Handler*( o: Objects.Object;  VAR msg: Objects.ObjMsg );
	VAR layer, copy: tLayer;  done: BOOLEAN;
	BEGIN
		ASSERT ( o IS tLayer, 100 );
		layer := o( tLayer );  done := FALSE;
		IF msg IS Display.DisplayMsg THEN
			WITH msg: Display.DisplayMsg DO Recall( layer );  done := TRUE;
			END;
		ELSIF msg IS vyColorPalettes.GetColMsg THEN
			WITH msg: vyColorPalettes.GetColMsg DO msg.pal := layer.p;
			END;
		ELSIF msg IS vyBase.UpdateMessage THEN
			WITH msg: vyBase.UpdateMessage DO vyPort.LayerHandler( layer, msg );
			END;
		ELSIF msg IS vyEvents.EventMsg THEN
			WITH msg: vyEvents.EventMsg DO
				IF msg.callForResponder THEN Responsible( layer, msg ) ELSE
					IF msg.gesture = vyEvents.EvtIdent THEN Prompt( layer, msg )
					ELSIF msg.gesture = vyEvents.EvtSelect THEN Select( layer, msg )
					ELSE vyPort.LayerHandler( layer, msg )
					END
				END;
				done := TRUE
			END;
		ELSIF msg IS Objects.CopyMsg THEN
			WITH msg: Objects.CopyMsg DO NEW( copy );  msg.obj := copy;  Copy( layer, msg.obj( tLayer ) );  done := TRUE
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
				IF layer.lib # msg.lib THEN vyPort.LayerHandler( layer, msg );  antsObjects.Bind( layer.p, msg ) END;
			END;
		ELSIF msg IS vyCommandMenus.enumMsg THEN
			WITH msg: vyCommandMenus.enumMsg DO
				tempLayer := layer;  msg.Enum( "Send Colors", SendColors, layer );  msg.Enum( "Store Palette", StorePal, layer );  msg.Enum( "Load Palette", LoadPal, layer )

			END;
		ELSE
		END;
		IF ~done THEN END
	END Handler;

	PROCEDURE Open*( layer: tLayer;  p: Palette );
	VAR id: vyName.tNameArray;
	BEGIN
		layer.handle := Handler;  id := "PaletteViewer";  vyPort.OpenLayer( layer, id );  layer.p := p;  vyBase.Subscribe( layer.p, layer )
	END Open;

	PROCEDURE New*;
	VAR newlayer: tLayer;
	BEGIN
		aM.cmd;  NEW( newlayer );  newlayer.handle := Handler;  Objects.NewObj := newlayer
	END New;

	PROCEDURE Path1*;
	VAR keys: SET;  x, y, dx, dy: SIGNED16;  msg: vyColorPalettes.GetColMsg;
	BEGIN
		aM.vS( "antsColors.Path1" );  Input.Mouse( keys, x, y );

		msg.pal := NIL;
		(*
	vyTracking.FramedString(x+10,y,"Syntax.10.Scn.Fnt","Destination ?",dx,dy);
	antsToolbox.MsgToXY(x+dx,y+dy,msg);
	*)
		vyTracking.HelpAt( x, y, "move mouse to destination and click" );  vyTracking.TrackMouseCont( keys, dx, dy, Effects.PointHand );
		antsToolbox.MsgToXY( dx, dy, msg );   (* better to do by interactive msg ! *)
		vyTracking.HelpEnd;

		IF msg.pal # NIL THEN vyColorPalettes.PathFromTo( vyColorPalettes.standard1, msg.pal )
		END
	END Path1;

	PROCEDURE Path2*;
	VAR keys: SET;  x, y, dx, dy: SIGNED16;  msg: vyColorPalettes.GetColMsg;
	BEGIN
		aM.vS( "antsColors.Path2" );  Input.Mouse( keys, x, y );  msg.pal := NIL;  vyTracking.HelpAt( x, y, "move mouse to destination and click" );
		vyTracking.TrackMouseCont( keys, dx, dy, Effects.PointHand );
		antsToolbox.MsgToXY( dx, dy, msg );   (* better to do by interactive msg ! *)
		vyTracking.HelpEnd;

		IF msg.pal # NIL THEN vyColorPalettes.PathFromTo( vyColorPalettes.standard2, msg.pal )
		END
	END Path2;

	PROCEDURE LPath*;
	VAR r1, g1, b1, r2, g2, b2: FLOAT32;  keys: SET;  x, y, dx, dy: SIGNED16;  from, to: SIGNED32;  msg: vyColorPalettes.GetColMsg;  sc: Texts.Scanner;
		obj: Objects.Object;
	BEGIN

		obj := Gadgets.FindObj( Gadgets.context, "from" );
		IF obj # NIL THEN Attributes.GetInt( obj, "Color", from ) ELSE aM.eS( "expected Gadget from" ) END;
		obj := Gadgets.FindObj( Gadgets.context, "to" );
		IF obj # NIL THEN Attributes.GetInt( obj, "Color", to ) ELSE aM.eS( "expected Gadget from" ) END;

		(* antsCommandScanner does not work for number of that size, error in vyScanners *)

		Colors.DisplayToRGB( (from), r1, g1, b1 );  Colors.DisplayToRGB( (to), r2, g2, b2 );  Input.Mouse( keys, x, y );
		msg.pal := NIL;  vyTracking.HelpAt( x, y, "move mouse to destination and click" );  vyTracking.TrackMouseCont( keys, dx, dy, Effects.PointHand );
		antsToolbox.MsgToXY( dx, dy, msg );   (* better to do by interactive msg ! *)
		vyTracking.HelpEnd;
		(*
		vyTracking.FramedString(x+10,y,"Syntax.10.Scn.Fnt","Destination ?",dx,dy);
		antsToolbox.MsgToXY(x+dx,y+dy,msg);
		*)
		IF msg.pal # NIL THEN vyColorPalettes.RGBPath( msg.pal, msg.pal.first, msg.pal.last, (r1), (g1), (b1), (r2), (g2), (b2) ) END
		(*
		layer := antsToolbox.FrontLayerXY(x+dx,y+dy); IF layer=NIL THEN RETURN END;
		WITH layer: tLayer DO
		RGBPath(layer.p,layer.p.first,layer.p.last,SHORT(r1),SHORT(g1),SHORT(b1),SHORT(r2),SHORT(g2),SHORT(b2));
		ELSE END;
		*)

	END LPath;

	PROCEDURE Path*;
	VAR l: antsCommands.tScanList;  r1, g1, b1, r2, g2, b2: FLOAT64;  keys: SET;  x, y, dx, dy: SIGNED16;  msg: vyColorPalettes.GetColMsg;
	BEGIN
		l := antsCommands.ScanFromPar( "r1=INT g1=INT b1=INT r2=INT g2=INT b2=INT" );
		IF antsCommands.ExpectRealFromKeyword( l, "r1", r1 ) & antsCommands.ExpectRealFromKeyword( l, "g1", g1 ) &
		    antsCommands.ExpectRealFromKeyword( l, "b1", b1 ) & antsCommands.ExpectRealFromKeyword( l, "r2", r2 ) &
		    antsCommands.ExpectRealFromKeyword( l, "g2", g2 ) & antsCommands.ExpectRealFromKeyword( l, "b2", b2 ) THEN
			Input.Mouse( keys, x, y );  msg.pal := NIL;  vyTracking.HelpAt( x, y, "move mouse to destination and click" );
			vyTracking.TrackMouseCont( keys, dx, dy, Effects.PointHand );
			antsToolbox.MsgToXY( dx, dy, msg );   (* better to do by interactive msg ! *)
			vyTracking.HelpEnd;
			(*
		vyTracking.FramedString(x+10,y,"Syntax.10.Scn.Fnt","Destination ?",dx,dy);
		antsToolbox.MsgToXY(x+dx,y+dy,msg);
		*)
			IF msg.pal # NIL THEN
				vyColorPalettes.RGBPath( msg.pal, msg.pal.first, msg.pal.last, SHORT( r1 ), SHORT( g1 ), SHORT( b1 ), SHORT( r2 ), SHORT( g2 ), SHORT( b2 ) )
			END
			(*
		layer := antsToolbox.FrontLayerXY(x+dx,y+dy); IF layer=NIL THEN RETURN END;
		WITH layer: tLayer DO
		RGBPath(layer.p,layer.p.first,layer.p.last,SHORT(r1),SHORT(g1),SHORT(b1),SHORT(r2),SHORT(g2),SHORT(b2));
		ELSE END;
		*)
		END
	END Path;

	PROCEDURE InteractiveSetCol*;
	VAR keys: SET;  x, y, dx, dy: SIGNED16;  layer: vyPort.tLayer;  index: SIGNED16;  s: Attributes.Scanner;  pict: vyPort.Picture;
	BEGIN
		aM.vS( "antsColors.InteractiveSetCol" );  Attributes.OpenScanner( s, Oberon.Par.text, Oberon.Par.pos );  Attributes.Scan( s );
		IF s.class = Attributes.Int THEN  (* col is in s.i *)
			Input.Mouse( keys, x, y );  vyTracking.HelpAt( x, y, "move mouse to destination and click" );  vyTracking.TrackMouseCont( keys, dx, dy, Effects.Cross );
			x := 0;  y := 0;  vyTracking.HelpEnd;
			(*
		vyTracking.FramedString(x+10,y,"Syntax.10.Scn.Fnt","Destination ?",dx,dy);
		*)
			layer := antsToolbox.FrontLayerXY( x + dx, y + dy, pict );
			IF layer = NIL THEN RETURN END;
			IF layer IS tLayer THEN
				WITH layer: tLayer DO
					IF LGetCol( layer, x + dx, y + dy, index ) THEN vyColorPalettes.SetCol( layer.p, index, s.i ) END
				END;
			ELSE
			END
		END
	END InteractiveSetCol;

	PROCEDURE ShowPalette*( pa: Palette );
	VAR p: vyPort.Picture;  layer: tLayer;  c: vyBase.Object;  a: Objects.AttrMsg;
	BEGIN
		New;  layer := Objects.NewObj( tLayer );  Open( layer, pa );  c := vyDisplay2d.NewC2d( 0, 0, 16, 16 );
		p := vyPort.NewP( c );  vyPort.AddLayer( p, layer );  Gadgets.ModifySize( p, 200, 200 );  a.res := -1;  a.name := "hdr";
		a.class := Objects.Bool;  a.b := FALSE;  a.id := Objects.set;  p.handle( p, a );  vyHostTexts.InsertGadget( p )
		(* Gadgets.Integrate(p); *)
	END ShowPalette;

	PROCEDURE ShowCurrent*;
	BEGIN
		aM.vS( "antsColors.ShowCurrent" );  ShowPalette( vyColorPalettes.current )
	END ShowCurrent;

	PROCEDURE ShowTinyPalette*( pa: Palette );
	VAR p: vyPort.Picture;  layer: tLayer;  c: vyBase.Object;  a: Objects.AttrMsg;
	BEGIN
		New;  layer := Objects.NewObj( tLayer );  Open( layer, pa );  c := vyDisplay2d.NewC2d( 0, 0, 16, 16 );
		p := vyPort.NewP( c );  vyPort.AddLayer( p, layer );  Gadgets.ModifySize( p, 50, 50 );  a.res := -1;  a.name := "hdr";
		a.class := Objects.Bool;  a.b := FALSE;  a.id := Objects.set;  p.handle( p, a );  vyHostTexts.InsertGadget( p )
		(*
	Gadgets.Integrate(p);
	*)
	END ShowTinyPalette;

	PROCEDURE ViewNewPalette*;
	VAR pa: Palette;
	BEGIN
		NEW( pa );  vyColorPalettes.InitPalette( pa );  ShowPalette( pa )
	END ViewNewPalette;

	PROCEDURE Edit*;
	BEGIN
		aM.vS( "antsColors.Edit" );  ShowPalette( vyColorPalettes.standard1 );  ShowPalette( vyColorPalettes.standard2 )
	END Edit;

	PROCEDURE Test*;
	VAR r, g, b: SIGNED16;  p: Palette;
	BEGIN
		vyColorPalettes.InitConversion( 255, p );  r := 10;  g := 0;  b := 0;  aM.SI( "", vyColorPalettes.Convert( r, g, b ) )
	END Test;

BEGIN
	aM.launch;
END antsColors.

antsColors.ViewNewPalette ~
antsColors.Path 0 0 1 1 0 0 ~
antsColors.Test ~
antsColors.Edit ~

ants / antsArrayObjects.Mod


