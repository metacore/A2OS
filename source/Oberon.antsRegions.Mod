MODULE antsRegions IN Oberon;   (** fof  **)
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




IMPORT Files, Objects, antsObjects, vyBase, antsViews, antsCommands, vyName, vyTracking, vyPort,  (* vyEvents,*) Display,
	Gadgets, vyGraphBase, antsPictCoordinate, aM := antsMessages, Input, antsArrayObjects, antsToolbox, vyHostStrings,
	Effects, antsPortability, antsSecurity, vyRectangles;

TYPE
	tRegion* = POINTER TO tRegionDesc;
	tRegionDesc* = RECORD (vyBase.ObjDesc)
		x*, y*, w*, h*: SIGNED16;
		view*: antsViews.tLayer;
		valid*: BOOLEAN
	END;

	tLayer* = POINTER TO tLayerDesc;
	tLayerDesc* = RECORD (vyPort.tLayerDesc)
		r*: tRegion;
		filled: BOOLEAN
	END;

VAR
	A-: antsArrayObjects.tINTEGERObject;  current*: tRegion;

	PROCEDURE Recall( layer: tLayer );
	VAR x, y, w, h, pen: SIGNED16;
	BEGIN
		IF layer.r.valid THEN
			vyGraphBase.Rect2dToRect( layer.r.x, layer.r.y, layer.r.w, layer.r.h, x, y, w, h );  pen := layer.style.pensize;
			IF ~layer.filled THEN vyGraphBase.FrameRect( x - pen, y - pen, w + 2 * pen, h + 2 * pen )
			ELSE
				vyGraphBase.SetForeColor( layer.style.fillcol );  vyGraphBase.FillRect( x, y, w, h );
				vyGraphBase.SetForeColor( layer.style.fcol );  vyGraphBase.FrameRect( x - pen, y - pen, w + 2 * pen, h + 2 * pen )
			END
		END
	END Recall;

(*
PROCEDURE Responsible (layer: tLayer;                VAR event: vyEvents.EventMsg);
VAR
	priority: SIGNED16;
BEGIN
	priority := vyEvents.PrioNone;
	IF ( (event.gesture = vyEvents.EvtIdent) OR (event.gesture = vyEvents.EvtSelect)) THEN
		priority := vyEvents.PrioNormal
	END;
	IF event.priority < priority THEN
		event.responder := layer;                event.priority := priority
	END
END Responsible;
*)

	PROCEDURE LayerHandleFileMsg( obj: tLayer;  VAR msg: Objects.FileMsg );
	VAR objsub: Objects.Object;  version: SIGNED16;
	BEGIN
		IF msg.id = Objects.load THEN
			Files.ReadInt( msg.R, version );  Gadgets.ReadRef( msg.R, obj.lib, objsub );
			IF objsub # NIL THEN obj.r := objsub( tRegion ) END;
			Files.ReadBool( msg.R, obj.filled )
		ELSIF msg.id = Objects.store THEN
			Files.WriteInt( msg.R, 1 );  Gadgets.WriteRef( msg.R, obj.lib, obj.r );  Files.WriteBool( msg.R, obj.filled )
		END
	END LayerHandleFileMsg;

	PROCEDURE LayerHandleLinks( obj: tLayer;  VAR msg: Objects.LinkMsg );
	BEGIN
		IF (msg.id = Objects.enum) THEN msg.Enum( "Region" );  vyPort.LayerHandler( obj, msg )
		ELSIF msg.id = Objects.get THEN
			IF msg.name = "Region" THEN msg.obj := obj.r;  msg.res := 0;  RETURN ELSE vyPort.LayerHandler( obj, msg ) END
		ELSE vyPort.LayerHandler( obj, msg )
		END
	END LayerHandleLinks;

	PROCEDURE LayerHandler*( o: Objects.Object;  VAR msg: Objects.ObjMsg );
	VAR layer: tLayer;
	BEGIN
		ASSERT ( o IS tLayer, 100 );
		layer := o( tLayer );
		IF msg IS Display.DisplayMsg THEN
			WITH msg: Display.DisplayMsg DO Recall( layer );
			END;
		ELSIF msg IS Objects.AttrMsg THEN
			WITH msg: Objects.AttrMsg DO
				IF msg.id = Objects.enum THEN msg.Enum( "filled" );  vyPort.LayerHandler( o, msg )
				ELSIF msg.id = Objects.get THEN
					IF msg.name = "Gen" THEN COPY( 'antsRegions.GenL', msg.s );  msg.class := Objects.String;  msg.res := 0;  RETURN
					ELSIF msg.name = "filled" THEN msg.class := Objects.Bool;  msg.b := layer.filled;  msg.res := 0;  RETURN
					ELSE vyPort.LayerHandler( o, msg )
					END
				ELSIF msg.id = Objects.set THEN
					IF msg.name = "filled" THEN
						IF msg.class = Objects.Bool THEN layer.filled := msg.b;  msg.res := 0;  vyBase.Update( layer );  RETURN END
					ELSE vyPort.LayerHandler( o, msg )
					END
				ELSE vyPort.LayerHandler( o, msg )
				END;
			END;
		ELSIF msg IS Objects.CopyMsg THEN
			WITH msg: Objects.CopyMsg DO vyPort.LayerHandler( layer, msg );  msg.obj^ := layer^;
			END;
		ELSIF msg IS Objects.FileMsg THEN
			WITH msg: Objects.FileMsg DO vyPort.LayerHandler( layer, msg );  LayerHandleFileMsg( layer, msg )
			END;
		ELSIF msg IS Objects.LinkMsg THEN
			WITH msg: Objects.LinkMsg DO LayerHandleLinks( layer, msg )
			END;
		ELSIF msg IS Objects.BindMsg THEN
			WITH msg: Objects.BindMsg DO
				IF msg.lib # layer.lib THEN
					vyPort.LayerHandler( layer, msg );  antsObjects.Bind( layer, msg );  antsObjects.Bind( layer.r, msg )
				END
			END;
		ELSE vyPort.LayerHandler( layer, msg )
		END
	END LayerHandler;

(*PROCEDURE LayerInit (layer: tLayer);
BEGIN
END LayerInit;
*)

	PROCEDURE GenL*;
	VAR m: tLayer;
	BEGIN
		NEW( m );  m.handle := LayerHandler;  Objects.NewObj := m;  antsObjects.Register( m );  m.filled := FALSE
	END GenL;

	PROCEDURE Open*( layer: tLayer;  id: vyName.tNameArray;  r: tRegion );
	VAR
	BEGIN
		vyPort.OpenLayer( layer, id );  layer.r := r;  vyName.RegisterNamed( layer, id );  vyBase.Subscribe( r, layer );
		layer.filled := FALSE;  layer.style.fcol := vyGraphBase.red;  layer.style.fillcol := vyGraphBase.green
	END Open;

	PROCEDURE InsertView*;
	VAR l: antsCommands.tScanList;  obj: vyBase.Object;  layer: tLayer;  name: vyName.tNameArray;
	BEGIN
		l := antsCommands.ScanFromPar( "name=NAME" );
		IF antsCommands.ExpectNameFromKeyword( l, "name", name ) THEN
			obj := vyName.FindObj( name );
			IF obj = NIL THEN RETURN END;
			GenL;  layer := Objects.NewObj( tLayer );  vyHostStrings.Append( name, "View" );  Open( layer, name, obj( tRegion ) );
			vyPort.AddLayer( vyPort.GetFocusPicture(), layer )
		END
	END InsertView;

	PROCEDURE Handler*( o: Objects.Object;  VAR M: Objects.ObjMsg );
	VAR version: SIGNED16;
	BEGIN
		WITH o: tRegion DO
			IF M IS Objects.AttrMsg THEN
				WITH M: Objects.AttrMsg DO
					IF M.id = Objects.enum THEN
						M.Enum( "Gen" );  M.Enum( "x" );  M.Enum( "y" );  M.Enum( "w" );  M.Enum( "h" );  vyBase.objecthandle( o, M )
					ELSIF M.id = Objects.get THEN
						IF M.name = "Gen" THEN COPY( 'antsRegions.Gen', M.s );  M.class := Objects.String;  M.res := 0;  RETURN
						ELSIF M.name = "x" THEN M.class := Objects.Int;  M.res := 0;  M.i := o.x
						ELSIF M.name = "y" THEN M.class := Objects.Int;  M.res := 0;  M.i := o.y
						ELSIF M.name = "w" THEN M.class := Objects.Int;  M.res := 0;  M.i := o.w
						ELSIF M.name = "h" THEN M.class := Objects.Int;  M.res := 0;  M.i := o.h
						ELSE vyBase.objecthandle( o, M )
						END
					ELSIF M.id = Objects.set THEN
						IF M.name = "x" THEN
							IF M.class = Objects.Int THEN o.x := SHORT( M.i );  M.res := 0;  vyBase.Update( o ) END
						ELSIF M.name = "y" THEN
							IF M.class = Objects.Int THEN o.y := SHORT( M.i );  M.res := 0;  vyBase.Update( o ) END
						ELSIF M.name = "w" THEN
							IF M.class = Objects.Int THEN o.w := SHORT( M.i );  M.res := 0;  vyBase.Update( o ) END
						ELSIF M.name = "h" THEN
							IF M.class = Objects.Int THEN o.h := SHORT( M.i );  M.res := 0;  vyBase.Update( o ) END
						ELSE vyBase.objecthandle( o, M )
						END
					ELSE vyBase.objecthandle( o, M )
					END;
				END;
			ELSIF M IS Objects.FileMsg THEN
				WITH M: Objects.FileMsg DO
					IF M.id = Objects.load THEN
						vyBase.objecthandle( o, M );  Files.ReadInt( M.R, version );  Files.ReadInt( M.R, o.x );
						Files.ReadInt( M.R, o.y );  Files.ReadInt( M.R, o.w );  Files.ReadInt( M.R, o.h )
					ELSIF M.id = Objects.store THEN
						vyBase.objecthandle( o, M );  Files.WriteInt( M.R, 0 );  Files.WriteInt( M.R, o.x );  Files.WriteInt( M.R, o.y );
						Files.WriteInt( M.R, o.w );  Files.WriteInt( M.R, o.h )
					END
				END;
			ELSE vyBase.objecthandle( o, M )
			END
		END  (* tVector*)
	END Handler;

	PROCEDURE Gen*;
	VAR m: tRegion;
	BEGIN
		aM.cmd;  NEW( m );  m.handle := Handler;  Objects.NewObj := m;  antsObjects.Register( m )
	END Gen;

	PROCEDURE New*;
	VAR l: antsCommands.tScanList;  name: vyName.tNameArray;  r: tRegion;
	BEGIN
		l := antsCommands.ScanFromPar( "name=NAME" );
		IF antsCommands.ExpectNameFromKeyword( l, "name", name ) THEN
			Gen;  r := Objects.NewObj( tRegion );  r.x := 0;  r.y := 0;  r.w := MAX( SIGNED16 );  r.h := MAX( SIGNED16 );  vyName.RegisterNamed( r, name )
		END
	END New;

	PROCEDURE GrowRectangleRLFilled*( x, y, w, h: SIGNED16;  VAR dx, dy: SIGNED16 );
	(*vs 0.0a1  md  29.05.95 *)
	VAR keys, keys0: SET;  x1, y1, x0, y0, xOld, yOld: SIGNED16;  oldm: SIGNED16;
	BEGIN
		vyGraphBase.UseClipMask( NIL );  vyGraphBase.GetDisplayMode( oldm );
		vyGraphBase.SetDisplayMode( vyGraphBase.invert );  vyGraphBase.SetForeColor( 1 );  Input.Mouse( keys0, x0, y0 );
		Input.Mouse( keys, x1, y1 );  xOld := x0;  yOld := y0;
		WHILE (keys = keys0) DO
			IF ((x1 # xOld) OR (y1 # yOld)) THEN
				vyGraphBase.FillRect( x, y, w, h );  y := y + (y1 - yOld);  w := w + (x1 - xOld);  h := h - (y1 - yOld);
				vyGraphBase.FillRect( x, y, w, h );  xOld := x1;  yOld := y1
			END;
			Input.Mouse( keys, x1, y1 );  vyGraphBase.DrawCursor( x1, y1 )
		END;
		vyGraphBase.FillRect( x, y, w, h );
		IF keys # {vyBase.rightKey, vyBase.middleKey, vyBase.leftKey} THEN dx := x1 - x0;  dy := y1 - y0 ELSE dx := 0;  dy := 0 END;
		vyGraphBase.SetDisplayMode( oldm )

	END GrowRectangleRLFilled;

(*
PROCEDURE DoSelectRegion* (r: tRegion);
VAR   pict: vyPort.Picture;  event: vyEvents.EventMsg;
x, y, w, h: SIGNED16;  c: Objects.Object;   x0, y0, x1, y1: SIGNED16;
getMsg: antsPictCoordinate.tCoordinate;  f: vyPort.tLayer;  o: Objects.Object;
BEGIN
r.view := NIL;
vyEvents.GetEvent (event);
vyGraphBase.SetStringJustification (vyGraphBase.center, vyGraphBase.bottom);
vyTracking.FramedString (event.x, event.y, "", "destination?", w, h);
antsToolbox.StartDisplayHelp("Move mouse to select dest area, any button to adopt. ");
vyEvents.GetEvent (event);
f := antsToolbox.TypedLayerXY(event.x, event.y, "antsViews.tLayerDesc",pict);
IF (f # NIL ) & (f IS antsViews.tLayer) THEN
A := f(antsViews.tLayer).refArray;
r.view := f(antsViews.tLayer);
ELSIF
f  = NIL THEN
aM.S("No focus layer");  r.valid := FALSE;  antsToolbox.EndDisplayHelp; RETURN
ELSE
aM.S("Is not antsViews.tLayer !! ");  r.valid := FALSE;  antsToolbox.EndDisplayHelp;    RETURN
END;
(* IF event.gesture #  vyEvents.EvtSelect THEN RETURN END; *)
x := event.x;             y := event.y;
antsToolbox.ZoomRect(0, 0, 255, x, y, 0, 0, w, h);
(* GrowRectangleRLFilled (x, y, 0, 0, w, h); *)
WHILE event.gesture #  vyEvents.EvtEmpty DO  vyEvents.GetEvent (event) END;

antsToolbox.EndDisplayHelp;

IF w < 0 THEN x := x + w;             w := - w END;
IF h < 0 THEN y := y + h;             h := - h END;

c := pict.gcontext ;
IF (w # 0) & (h # 0) THEN
WITH c: antsPictCoordinate.tCoordinate DO
antsPictCoordinate.GetXY(c, x, y, x0, y0);
antsPictCoordinate.GetXY(c, x + w, y + h, x1, y1);
aM.SISI("x", x0, "y", y0);
aM.SISI("w", x1 - x0, "h", y1 - y0);
r.x := x0;  r.y := y0;  r.w := x1 - x0+1;  r.h := y1 - y0+1 ;
r.dlink := A;
IF r.x < 0 THEN INC(r.w, r.x);  r.x := 0 END;
IF r.y < 0 THEN INC(r.h, r.y);  r.y := 0 END;
IF r.x + r.w > A.w - 1 THEN r.w := SHORT(A.w) - r.x  END;
IF r.y + r.h > A.h - 1 THEN r.h := SHORT(A.h) - r.y  END;
r.valid := (r.w > 0) & (r.h > 0);
vyBase.Update(r)
ELSE
r.valid := FALSE
END
END;
vyBase.Update(r);
END DoSelectRegion;

*)

	PROCEDURE DoSelectRegion*( r: tRegion );
	VAR pict: vyPort.Picture;  x, y, w, h: SIGNED16;  c: Objects.Object;  x0, y0, x1, y1: SIGNED16;  f: vyPort.tLayer;  mx, my: SIGNED16;  keys: SET;
		cur: antsPortability.display;
	BEGIN
		antsSecurity.Block;  cur := antsPortability.GetCurrentDisplay();  r.view := NIL;  Input.Mouse( keys, mx, my );
		vyTracking.HelpAt( mx, my, "move mouse to a vertice of destination rectangle, click and hold button" );  vyGraphBase.SetStringJustification( vyGraphBase.center, vyGraphBase.bottom );
		antsSecurity.Block;  vyTracking.TrackMouseCont( keys, mx, my, Effects.PointHand );  antsToolbox.EndDisplayHelp;
		vyTracking.HelpAt( mx, my, "move mouse, release when done" );  antsSecurity.Block;
		(*
	vyTracking.FramedString (event.x, event.y, "", "destination?", w, h);
	*)
		(* antsToolbox.StartDisplayHelp("Move mouse to select dest area, any button to adopt. ");
	vyEvents.GetEvent (event);*)

		f := antsToolbox.TypedLayerXY( mx, my, "antsViews.tLayerDesc", pict );
		IF (f # NIL ) & (f IS antsViews.tLayer) THEN A := f( antsViews.tLayer ).refArray;  r.view := f( antsViews.tLayer )
		ELSIF f = NIL THEN aM.S( "No focus layer" );  r.valid := FALSE;  antsToolbox.EndDisplayHelp;  RETURN
		ELSE aM.S( "Is not antsViews.tLayer !! " );  r.valid := FALSE;  antsToolbox.EndDisplayHelp;  RETURN
		END;
		(* IF event.gesture #  vyEvents.EvtSelect THEN RETURN END; *)
		x := mx;  y := my;  antsToolbox.ZoomRect( 0, 0, 255, x, y, 0, 0, w, h );
		(* GrowRectangleRLFilled (x, y, 0, 0, w, h); *)

		antsToolbox.EndDisplayHelp;

		IF w < 0 THEN x := x + w;  w := -w
		END;
		IF h < 0 THEN y := y + h;  h := -h END;

		c := pict.gcontext;
		IF (w # 0) & (h # 0) THEN
			IF c IS antsPictCoordinate.tCoordinate THEN
				WITH c: antsPictCoordinate.tCoordinate DO
					antsPictCoordinate.GetXY( c, x, y, x0, y0 );  antsPictCoordinate.GetXY( c, x + w, y + h, x1, y1 );
					aM.SISI( "x", x0, "y", y0 );  aM.SISI( "w", x1 - x0, "h", y1 - y0 );  r.x := x0;  r.y := y0;  r.w := x1 - x0 + 1;  r.h := y1 - y0 + 1;
					r.dlink := A;
					IF r.x < 0 THEN INC( r.w, r.x );  r.x := 0 END;
					IF r.y < 0 THEN INC( r.h, r.y );  r.y := 0 END;
					IF r.x + r.w > A.w - 1 THEN r.w := SHORT( A.w ) - r.x END;
					IF r.y + r.h > A.h - 1 THEN r.h := SHORT( A.h ) - r.y END;
					r.valid := (r.w > 0) & (r.h > 0);  vyBase.Update( r )
				END;
			ELSE r.valid := FALSE
			END
		END;
		vyBase.Update( r );  antsPortability.SetCurrentDisplay( cur );  antsSecurity.Release
	END DoSelectRegion;

	PROCEDURE SelectRegion*;
	VAR l: antsCommands.tScanList;  obj: vyBase.Object;  r: tRegion;  x, y: SIGNED16;  set: SET;
	BEGIN
		l := antsCommands.ScanFromPar( "name=OBJ" );
		IF antsCommands.ExpectObjectFromKeyword( l, "name", obj ) THEN
			r := obj( tRegion );  Input.Mouse( set, x, y );  vyTracking.HelpEnd;  DoSelectRegion( r )
		END
	END SelectRegion;

	PROCEDURE Get*( r: tRegion;  A: antsArrayObjects.tObject;  VAR x, y, w, h: SIGNED32 );
	VAR xi, yi, wi, hi: SIGNED16;
	BEGIN
		xi := 0;  yi := 0;  wi := SHORT( A.w );  hi := SHORT( A.h );
		IF r # NIL THEN vyRectangles.RectIntersection( xi, yi, wi, hi, r.x, r.y, r.w, r.h ) END;
		x := xi;  y := yi;  h := hi;  w := wi
	END Get;

	PROCEDURE InteractiveGetArray*( r: tRegion ): antsArrayObjects.tObject;
	VAR msg: antsToolbox.GetCoordMsg;
	BEGIN
		msg.layer := NIL;  msg.update := TRUE;
		IF r = NIL THEN
			antsToolbox.InteractiveMsg( msg );  antsToolbox.MsgToTypedXY( msg.x, msg.y, msg, "antsViews.tLayerDesc" );
			IF (msg.a = NIL ) OR (~(msg.a IS antsArrayObjects.tObject)) THEN RETURN NIL
			ELSE RETURN msg.a( antsArrayObjects.tObject )
			END
			(*
		IF msg.layer # NIL THEN
		layer := msg.layer;
		WITH layer: antsPictureViews.tLayer DO RETURN  layer.E.A ;
		|layer: antsImageViews.tLayer DO  RETURN  layer.E.A
		ELSE RETURN NIL
		END
		ELSE RETURN NIL
		END
		*)
		ELSE
			DoSelectRegion( r );
			IF r.view # NIL THEN RETURN A ELSE RETURN NIL END
			(*
		layer := r.view;

		WITH layer: antsPictureViews.tLayer DO RETURN  layer.E.A ;
		|layer: antsImageViews.tLayer DO  RETURN  layer.E.A
		ELSE RETURN NIL
		END
		ELSE
		RETURN NIL
		END
		*)
		END
	END InteractiveGetArray;

	PROCEDURE Init*;
	END Init;

BEGIN
	aM.launch;  Init;
END antsRegions.

System.Free antsRegions ~


antsRegions.New MyRegion ~
antsRegions.SelectRegion  MyRegion ~
Voyager.Show MyRegion as antsObjectView ~
antsRegions.InsertView MyRegion ~


antsDiscreteFields.NewArray array 100 100 8 ~
antsViews.Show array ~
ants / Freiberg1.Panel

vyScale.Insert

fofAutomatic.Do
antsArrayObjects.New testarray 100 100 10 ~
antsArrayPictures.New testpict testarray ~
Voyager.Show testpict as antsPictureViews ~
antsArrayObjects.Uniform testarray ~
~

antsObjects.WriteAttributes MyRegionView ~
