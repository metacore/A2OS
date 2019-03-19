MODULE antsPointPlot IN Oberon;
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




IMPORT Files, Gadgets, Objects, Display, vyBase, vyGraphBase, vyHostDisplay := vyGraphBase, vyLinks, vyName, vyPort,
	vyHostStrings, vyTypes, vyDisplay2d, vyBooleanVec, vyHighlight, vyEvents, vyRectangles, aM := antsMessages;

CONST
	idversion* = "antsPointPlot";

TYPE
	Real = vyBase.Real;

	tLayer* = POINTER TO tLayerDesc;
	tLayerDesc = RECORD (vyPort.tLayerDesc) END;

VAR

	dlink-: Objects.Object;  newlayer-: tLayer;

	PROCEDURE Copy( src, dest: tLayer );
	BEGIN
		dest^ := src^
	END Copy;

	PROCEDURE Recall( scatter: tLayer );
	VAR nrData, i: LONGINT;  sel: vyBase.tVector;  xx, yy: INTEGER;  b: BOOLEAN;
	BEGIN
		IF (scatter.x # NIL ) THEN
			IF (scatter.x.nrData > 0) THEN
				nrData := scatter.x.nrData;
				IF scatter.highlight = NIL THEN vyHighlight.AdjustHighlight( scatter ) END;

				sel := vyHighlight.GetSelectionAttribute( scatter.highlight );

				FOR i := 0 TO nrData - 1 DO
					vyGraphBase.Point2dToPoint( i, vyTypes.VGetR( scatter.x, i ), xx, yy );
					IF sel.nrData > i THEN b := vyBooleanVec.Get( sel, i ) ELSE b := FALSE END;
					IF b THEN
						vyHostDisplay.SetForeColor( scatter.style.selectcol );
						vyHostDisplay.FrameCircle( xx, yy, 2 * vyHostDisplay.pixel )
					ELSE
						vyHostDisplay.SetForeColor( scatter.style.fcol );
						IF scatter.style.pensize = 1 THEN
							vyHostDisplay.PaintRect( xx - vyHostDisplay.pixel, yy, 3 * vyHostDisplay.pixel, vyHostDisplay.pixel );
							vyHostDisplay.PaintRect( xx, yy - vyHostDisplay.pixel, vyHostDisplay.pixel, 3 * vyHostDisplay.pixel )
						ELSE
							vyHostDisplay.PaintRect( xx - (vyHostDisplay.pixel * scatter.style.pensize) DIV 2,
																	 yy - (vyHostDisplay.pixel * scatter.style.pensize) DIV 2,
																	 vyHostDisplay.pixel * scatter.style.pensize,
																	 vyHostDisplay.pixel * scatter.style.pensize );
						END;
					END
				END
			END
		END
	END Recall;
(* selection methods for the use of the Interactive.tSelector *)
	PROCEDURE Vizor( x0, y0, x1, y1: INTEGER );
	BEGIN
		vyHostDisplay.FrameRect( x0, y0, x1 - x0, y1 - y0 )
	END Vizor;

	PROCEDURE Actor( layer: vyPort.tLayer;  sel: vyBase.tVector;  x0O, y0O, x1O, y1O, x0N, y0N, x1N, y1N: Real;
								VAR somethingChanged: BOOLEAN );
	VAR scatter: tLayer;  nrData, i: LONGINT;  new: BOOLEAN;  X, Y: Real;

		PROCEDURE PointInRect( px, py, x0, y0, x1, y1: Real ): BOOLEAN;
		BEGIN
			RETURN (x0 <= px) & (px <= x1) & (y0 <= py) & (py <= y1)
		END PointInRect;

	BEGIN
		IF sel # NIL THEN  (* gs hack *)
			scatter := layer( tLayer );  nrData := scatter.x.nrData;
			FOR i := 0 TO nrData - 1 DO
				Y := vyTypes.VGetR( scatter.x, i );  X := i;
				new :=
					(PointInRect( X, Y, x0N, y0N, x1N, y1N ) & ~PointInRect( X, Y, x0O, y0O, x1O, y1O )) OR
					(~PointInRect( X, Y, x0N, y0N, x1N, y1N ) & PointInRect( X, Y, x0O, y0O, x1O, y1O ));
				vyBooleanVec.Set( new, sel, i );  somethingChanged := somethingChanged OR new
			END
		END
	END Actor;

	PROCEDURE Select( scatter: tLayer;  VAR event: vyEvents.EventMsg );
	VAR selector: vyHighlight.tSelector;
	BEGIN
		vyHighlight.OpenSelector( scatter, scatter.x.nrData, Vizor, Actor, event );
		selector := scatter.highlight( vyHighlight.tSelector );  selector.do( selector, event )
	END Select;

	PROCEDURE Prompt( scatter: tLayer;  VAR event: vyEvents.EventMsg );
	CONST toleranz = 2 * vyHostDisplay.pixel;
	VAR p: vyPort.Picture;  found, i, nrData: LONGINT;  r: Real;  lx, ly, x0, y0: INTEGER;  id, val: vyName.tNameArray;
	BEGIN
		vyHostDisplay.SetCursor( vyHostDisplay.Wheel );  found := -1;  nrData := scatter.x.nrData;
		p := event.dlink( vyPort.Picture );  id := "";
		WHILE event.gesture = vyEvents.EvtIdent DO
			FOR i := 0 TO nrData - 1 DO
				vyGraphBase.Point2dToPoint( i, vyTypes.VGetR( scatter.x, i ), x0, y0 );
				IF (i # found) & (ABS( x0 - event.x ) + ABS( y0 - event.y ) < toleranz) THEN
					vyHostDisplay.InvertString( lx, ly, "Syntax10.Scn.Fnt", id );  found := i;  id := "(";  val := "";
					(*! label *)
					r := vyTypes.VGetR( scatter.x, i );  vyHostStrings.AppendRealFix( r, 4, 2, 5, val );
					vyHostStrings.Append( id, val );  vyHostStrings.Append( id, ", " );  val := "";  r := vyTypes.VGetR( scatter.y, i );
					vyHostStrings.AppendRealFix( r, 4, 2, 5, val );  vyHostStrings.Append( id, val );  vyHostStrings.Append( id, ")" );
					vyHostDisplay.SetStringJustification( vyHostDisplay.left, vyHostDisplay.bottom );  lx := event.x;  ly := event.y;
					vyHostDisplay.InvertString( lx, ly, "Syntax10.Scn.Fnt", id )
				END
			END;
			vyEvents.GetEvent( event )
		END;
		vyHostDisplay.InvertString( lx, ly, "Syntax10.Scn.Fnt", id );  vyHostDisplay.SetCursor( vyHostDisplay.Crosshair );
		vyHostDisplay.DrawCursor( event.x, event.y )
	END Prompt;

	PROCEDURE Responsible( scatter: tLayer;  VAR event: vyEvents.EventMsg );
	VAR priority: INTEGER;

		PROCEDURE InScatter( x, y: INTEGER ): BOOLEAN;
		CONST eps = 3;
		VAR minX, minY, maxX, maxY: Real;  x0, y0, x1, y1: INTEGER;  nans: LONGINT;

		BEGIN
			vyTypes.VGetMinMax( scatter.x, minY, maxY, nans );  minX := 0;  maxX := scatter.x.nrData;
			vyGraphBase.Point2dToPoint( minX, minY, x0, y0 );  vyGraphBase.Point2dToPoint( maxX, maxY, x1, y1 );
			RETURN vyRectangles.PointInRect( x, y, x0 - eps, y0 - eps, x1 - x0 + 2 * eps, y1 - y0 + 2 * eps )
		END InScatter;

	BEGIN
		priority := vyEvents.PrioNone;
		IF ((event.gesture = vyEvents.EvtSelect) OR (event.gesture = vyEvents.EvtIdent)) & (InScatter( event.x, event.y )) THEN
			priority := vyEvents.PrioNormal
		END;
		IF event.priority < priority THEN event.responder := scatter;  event.priority := priority END
	END Responsible;

	PROCEDURE Consume( o: tLayer;  msg: Display.ConsumeMsg );
	VAR v: vyBase.tVector;  minX, maxX: Real;  pict: vyPort.Picture;  nans: LONGINT;
	BEGIN
		pict := msg.dlink( vyPort.Picture );  v := vyBase.GetVFromObj( msg.obj );
		IF v # NIL THEN vyBase.UnSubscribe( o.x, o );

			Open( o, msg.obj );  vyTypes.VGetMinMax( o.x, minX, maxX, nans );
			vyPort.SetNewC2d( pict, 0, minX, o.x.nrData, maxX - minX );  vyBase.Update( v )
		END
	END Consume;

	PROCEDURE HandleAttributes( obj: tLayer;  VAR M: Objects.AttrMsg );
	BEGIN
		IF M.id = Objects.get THEN
			IF M.name = "Gen" THEN COPY( 'antsPointPlot.Alloc', M.s );  M.class := Objects.String;  M.res := 0 ELSE vyPort.LayerHandler( obj, M )
				END  (*IF*)
		ELSIF M.id = Objects.set THEN vyPort.LayerHandler( obj, M )
		ELSIF M.id = Objects.enum THEN vyPort.LayerHandler( obj, M )
		ELSE vyPort.LayerHandler( obj, M )
		END  (*IF*)
	END HandleAttributes;

	PROCEDURE Store0( obj: tLayer;  VAR M: Objects.FileMsg );
	BEGIN
		Files.WriteInt( M.R, 0 );  Gadgets.WriteRef( M.R, obj.lib, obj.x )
	END Store0;

	PROCEDURE Load0( obj: tLayer;  VAR M: Objects.FileMsg );

	VAR objsub: Objects.Object;  version: INTEGER;

	BEGIN
		Files.ReadInt( M.R, version );  dlink := M.dlink;  Gadgets.ReadRef( M.R, obj.lib, objsub );
		IF (objsub # NIL ) & (objsub IS vyBase.tVector) THEN obj.x := objsub( vyBase.tVector ) END
	END Load0;

	PROCEDURE HandleLinks( obj: tLayer;  VAR msg: Objects.LinkMsg );
	(*! handle subscribe/unsubscribe. Move to vyPort *)
	BEGIN
		IF (msg.id = Objects.enum) THEN msg.Enum( "x" );  vyPort.LayerHandler( obj, msg )
		ELSIF (msg.id = Objects.get) & (msg.name = "x") THEN msg.obj := obj.x;  msg.res := 0
		ELSIF (msg.id = Objects.set) & (msg.name = "x") & (msg.obj # NIL ) & (msg.obj IS vyBase.tVector) THEN
			(* check proper type *)
			obj.x := msg.obj( vyBase.tVector )
		ELSE vyPort.LayerHandler( obj, msg )
		END
	END HandleLinks;

	PROCEDURE Handler*( obj: Objects.Object;  VAR msg: Objects.ObjMsg );
	VAR copy: tLayer;
	BEGIN

		WITH obj: tLayer DO
			IF msg IS Display.DisplayMsg THEN
				WITH msg: Display.DisplayMsg DO Recall( obj )
				END;
			ELSIF msg IS vyEvents.EventMsg THEN
				WITH msg: vyEvents.EventMsg DO
					IF msg.callForResponder THEN
						Responsible( obj, msg );   (*vyPort.LayerHandler (obj, msg)*)
					ELSE
						IF msg.gesture = vyEvents.EvtSelect THEN Select( obj, msg )
						ELSIF msg.gesture = vyEvents.EvtIdent THEN Prompt( obj, msg )
						END
					END;
				END;
			ELSIF msg IS Objects.CopyMsg THEN
				WITH msg: Objects.CopyMsg DO NEW( copy );  msg.obj := copy;  vyPort.LayerHandler( obj, msg );  Copy( obj, copy )
				END;
			ELSIF msg IS Objects.FileMsg THEN
				WITH msg: Objects.FileMsg DO
					IF msg.id = Objects.load THEN
						vyPort.LayerHandler( obj, msg );  Load0( obj, msg )
						(*
				vyPort.LayerHandler (obj, msg);
				(*! hack *) IF obj.x # NIL THEN
				pict := msg.dlink(vyPort.Picture);
				IF pict # NIL THEN
				vyTypes.VGetMinMaxR(obj.x, minX, maxX, nans);
				vyPort.SetNewC2d (pict, minX, 0, maxX - minX, 1)
				(*ELSE
				vyHostTexts.Note(vyHostTexts.cWarning,"vyLinePlot: no host picture  ")*)
				END
				ELSE
				vyHostTexts.Note(vyHostTexts.cWarning,"vyLinePlot: no x obj loaded  ")
				;HALT(100);
				END
				*)
					ELSIF msg.id = Objects.store THEN
						vyPort.LayerHandler( obj, msg );  Store0( obj, msg )
						(* vyPort.LayerHandler (obj, msg)*)
					ELSE vyPort.LayerHandler( obj, msg )
					END
				END;
			ELSIF msg IS Display.ConsumeMsg THEN
				WITH msg: Display.ConsumeMsg DO Consume( obj, msg );  vyPort.LayerHandler( obj, msg )
				END;
			ELSIF msg IS Objects.AttrMsg THEN
				WITH msg: Objects.AttrMsg DO HandleAttributes( obj, msg )
				END;
			ELSIF msg IS Objects.LinkMsg THEN
				WITH msg: Objects.LinkMsg DO HandleLinks( obj, msg )
				END;
			ELSIF msg IS Objects.BindMsg THEN
				WITH msg: Objects.BindMsg DO
					IF obj.lib # msg.lib THEN
						vyPort.LayerHandler( obj, msg );
						IF obj.x # NIL THEN Gadgets.BindObj( obj.x, msg.lib ) END
					END;
				END;
			ELSE vyPort.LayerHandler( obj, msg )
			END
		END  (*WITH*)
	END Handler;

	PROCEDURE Open*( linePlot: tLayer;  data: Objects.Object );
	VAR id: vyName.tNameArray;
	BEGIN
		id := "pointPlot: ";
		IF data # NIL THEN
			vyName.AppendObjId( data( vyBase.Object ), id );  linePlot.x := vyBase.GetVFromObj( data );
			vyPort.OpenLayer( linePlot, id );  linePlot.handle := Handler;  vyBase.Subscribe( (*for messages from source*) linePlot.x,
																																															linePlot )
		END
	END Open;

	PROCEDURE Alloc*;
	BEGIN
		aM.cmd;  NEW( newlayer );  newlayer.handle := Handler;  Objects.NewObj := newlayer
	END Alloc;

	PROCEDURE New*;
	VAR data: Objects.Object;
	BEGIN
		IF Objects.NewObj # NIL THEN data := Objects.NewObj ELSE RETURN END;
		Alloc;  Open( newlayer, data );  Objects.NewObj := newlayer
	END New;

	PROCEDURE ShowP*;
	VAR data: Objects.Object;  linePlot: tLayer;  pict: vyPort.Picture;  c: vyDisplay2d.tCoordinate2d;  minX, maxX: Real;
		nans: LONGINT;
	BEGIN
		aM.vS( "antsPointPlot.Show" );  data := vyBase.NextParObj();
		WHILE data # NIL DO
			Alloc;  linePlot := Objects.NewObj( tLayer );  Open( linePlot, data );
			vyTypes.VGetMinMax( linePlot.x, minX, maxX, nans );
			IF maxX = minX THEN minX := minX - 0.5;  maxX := minX + 1 END;

			NEW( c );  vyDisplay2d.OpenC2d( c, 0, minX, linePlot.x.nrData, maxX - minX );
			pict := vyPort.InsertNewCPicture( 0, 0, 1, 1, c );  vyPort.AddLayer( pict, linePlot );  data := vyBase.NextParObj()
		END;
		Objects.NewObj := pict
	END ShowP;

	PROCEDURE ShowL*( list: vyLinks.Link );
	VAR linePlot: tLayer;  pict: vyPort.Picture;  c: vyDisplay2d.tCoordinate2d;  minX, maxX: Real;  nans: LONGINT;
	BEGIN
		WHILE list # NIL DO
			Alloc;  linePlot := Objects.NewObj( tLayer );  Open( linePlot, list.obj );
			vyTypes.VGetMinMax( linePlot.x, minX, maxX, nans );
			IF maxX = minX THEN minX := minX - 0.5;  maxX := minX + 1 END;

			NEW( c );  vyDisplay2d.OpenC2d( c, 0, minX, linePlot.x.nrData, maxX - minX );
			pict := vyPort.InsertNewCPicture( 0, 0, 1, 1, c );  vyPort.AddLayer( pict, linePlot );  list := list.link;
			Objects.NewObj := pict
		END
	END ShowL;

	PROCEDURE ShowO*( obj: Objects.Object );
	VAR linePlot: tLayer;  pict: vyPort.Picture;  c: vyDisplay2d.tCoordinate2d;  minX, maxX: Real;  nans: LONGINT;
	BEGIN
		Alloc;  linePlot := Objects.NewObj( tLayer );  Open( linePlot, obj );
		vyTypes.VGetMinMax( linePlot.x, minX, maxX, nans );
		IF maxX = minX THEN minX := minX - 0.5;  maxX := minX + 1 END;

		NEW( c );  vyDisplay2d.OpenC2d( c, 0, minX, linePlot.x.nrData, maxX - minX );
		pict := vyPort.InsertNewCPicture( 0, 0, 1, 1, c );  vyPort.AddLayer( pict, linePlot );  Objects.NewObj := pict
	END ShowO;

BEGIN
	aM.launch;
END antsPointPlot.

Voyager vyRegress vyLinePlot

Voyager.Random 200 ~
Voyager.Show @ as antsPointPlot ~
Voyager.Show @ as LinePlot ~
Voyager.Show @ ~
~
Generator:  U
New random numbers generated as
UPM05272EE6

