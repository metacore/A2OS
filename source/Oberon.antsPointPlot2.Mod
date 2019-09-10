MODULE antsPointPlot2 IN Oberon;
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
	vyHostStrings, vyTypes, vyDisplay2d, vyBooleanVec, vyHighlight, vyEvents, vyRectangles, aM := antsMessages,
	vyLongrealVec, vyRealVec, vyCommandMenus;

CONST
	idversion* = "antsPointPlot2";

TYPE
	Real = vyBase.Real;

	tLayer* = POINTER TO tLayerDesc;
	tLayerDesc = RECORD (vyPort.tLayerDesc)
		edit: BOOLEAN;
	END;

VAR
	tempLayer: tLayer;  tempNum: SIGNED32;  tempX, tempY: FLOAT64;

	dlink-: Objects.Object;  newlayer-: tLayer;

	PROCEDURE Copy( src, dest: tLayer );
	BEGIN
		dest^ := src^
	END Copy;

	PROCEDURE Min( x, y: SIGNED32 ): SIGNED32;
	BEGIN
		IF x < y THEN RETURN x ELSE RETURN y END;
	END Min;

	PROCEDURE Recall( scatter: tLayer );
	VAR nrData, i: SIGNED32;  sel: vyBase.tVector;  xx, yy: SIGNED16;  b: BOOLEAN;
	BEGIN
		IF (scatter.x # NIL ) THEN
			IF (scatter.x.nrData > 0) & (scatter.y.nrData > 0) THEN
				nrData := Min( scatter.x.nrData, scatter.y.nrData );
				IF scatter.highlight = NIL THEN vyHighlight.AdjustHighlight( scatter ) END;

				sel := vyHighlight.GetSelectionAttribute( scatter.highlight );

				FOR i := 0 TO nrData - 1 DO
					vyGraphBase.Point2dToPoint( vyTypes.VGetR( scatter.x, i ), vyTypes.VGetR( scatter.y, i ), xx, yy );
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
							vyHostDisplay.FrameCircle( xx, yy, vyHostDisplay.pixel );
							(*
						vyHostDisplay.PaintRect(xx - (vyHostDisplay.pixel * scatter.style.pensize) DIV 2, yy - (vyHostDisplay.pixel * scatter.style.pensize) DIV 2,
						vyHostDisplay.pixel * scatter.style.pensize, vyHostDisplay.pixel * scatter.style.pensize);
						*)
						END;
					END
				END
			END
		END
	END Recall;
(* selection methods for the use of the Interactive.tSelector *)
	PROCEDURE Vizor( x0, y0, x1, y1: SIGNED16 );
	BEGIN
		vyHostDisplay.FrameRect( x0, y0, x1 - x0, y1 - y0 )
	END Vizor;

	PROCEDURE Actor( layer: vyPort.tLayer;  sel: vyBase.tVector;  x0O, y0O, x1O, y1O, x0N, y0N, x1N, y1N: Real;
								VAR somethingChanged: BOOLEAN );
	VAR scatter: tLayer;  nrData, i: SIGNED32;  new: BOOLEAN;  X, Y: Real;

		PROCEDURE PointInRect( px, py, x0, y0, x1, y1: Real ): BOOLEAN;
		BEGIN
			RETURN (x0 <= px) & (px <= x1) & (y0 <= py) & (py <= y1)
		END PointInRect;

	BEGIN
		IF sel # NIL THEN  (* gs hack *)
			scatter := layer( tLayer );  nrData := Min( scatter.x.nrData, scatter.y.nrData );
			FOR i := 0 TO nrData - 1 DO
				Y := vyTypes.VGetR( scatter.y, i );  X := vyTypes.VGetR( scatter.x, i );
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
	VAR p: vyPort.Picture;  found, i, nrData: SIGNED32;  r: Real;  lx, ly, x0, y0: SIGNED16;  id, val: vyName.tNameArray;
	BEGIN
		vyHostDisplay.SetCursor( vyHostDisplay.Wheel );  found := -1;  nrData := Min( scatter.x.nrData, scatter.y.nrData );
		p := event.dlink( vyPort.Picture );  id := "";
		WHILE event.gesture = vyEvents.EvtIdent DO
			FOR i := 0 TO nrData - 1 DO
				vyGraphBase.Point2dToPoint( vyTypes.VGetR( scatter.x, i ), vyTypes.VGetR( scatter.y, i ), x0, y0 );
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

	PROCEDURE InPoint( scatter: tLayer;  x, y: SIGNED16;  VAR i: SIGNED32 ): BOOLEAN;
	VAR nrData: SIGNED32;  size, x0, y0: SIGNED16;
	BEGIN
		nrData := Min( scatter.x.nrData, scatter.y.nrData );  size := scatter.style.pensize;
		FOR i := 0 TO nrData - 1 DO
			vyGraphBase.Point2dToPoint( vyTypes.VGetR( scatter.x, i ), vyTypes.VGetR( scatter.y, i ), x0, y0 );
			IF (x0 - size <= x) & (x0 + size >= x) & (y0 - size <= y) & (y0 + size >= y) THEN RETURN TRUE END;
		END;
		RETURN FALSE;
	END InPoint;

	PROCEDURE Loc( scatter: tLayer;  VAR event: vyEvents.EventMsg );
	VAR num: SIGNED32;  vx, vy: vyBase.tVector;  xr, yr: FLOAT64;  oldx, oldy: SIGNED16;  x, y, w, h: SIGNED16;  c: vyGraphBase.tCoordinate2d;  gesture: SIGNED16;

	BEGIN
		c := vyGraphBase.GetCoordinate();  vyGraphBase.GetScreenRgn( x, y, w, h );

		vx := scatter.x;  vy := scatter.y;  oldx := MAX( SIGNED16 );
		IF ~InPoint( scatter, event.x, event.y, num ) THEN RETURN END;
		WHILE event.gesture = vyEvents.EvtLoc DO
			IF (event.x # oldx) OR (event.y # oldy) THEN
				vyGraphBase.PointToPoint2d( event.x, event.y, xr, yr );
				IF vx IS vyLongrealVec.tVector THEN
					WITH vx: vyLongrealVec.tVector DO vyLongrealVec.Set( xr, vx, num );
					END;
				ELSIF vx IS vyRealVec.tVector THEN
					WITH vx: vyRealVec.tVector DO vyRealVec.Set( xr, vx, num );
					END;
				END;
				IF vy IS vyLongrealVec.tVector THEN
					WITH vy: vyLongrealVec.tVector DO vyLongrealVec.Set( yr, vy, num );
					END;
				ELSIF vy IS vyRealVec.tVector THEN
					WITH vy: vyRealVec.tVector DO vyRealVec.Set( yr, vy, num );
					END;
				END;
				vyBase.Update( scatter );  vyGraphBase.SetCoordinate( c );  vyGraphBase.SetScreenRgn( x, y, w, h )
			END;
			oldx := event.x;  oldy := event.y;  vyEvents.GetEvent( event )
		END;
		vyBase.Update( vx );  vyBase.Update( vy );
	END Loc;

	PROCEDURE Responsible( scatter: tLayer;  VAR event: vyEvents.EventMsg );
	VAR priority: SIGNED16;  i: SIGNED32;

		PROCEDURE InScatter( x, y: SIGNED16 ): BOOLEAN;
		CONST eps = 3;
		VAR minX, minY, maxX, maxY: Real;  x0, y0, x1, y1: SIGNED16;  nans: SIGNED32;
		BEGIN
			vyTypes.VGetMinMax( scatter.x, minX, maxX, nans );  vyTypes.VGetMinMax( scatter.y, minY, maxY, nans );

			vyGraphBase.Point2dToPoint( minX, minY, x0, y0 );  vyGraphBase.Point2dToPoint( maxX, maxY, x1, y1 );
			RETURN vyRectangles.PointInRect( x, y, x0 - eps, y0 - eps, x1 - x0 + 2 * eps, y1 - y0 + 2 * eps )
		END InScatter;

	BEGIN
		priority := vyEvents.PrioNone;
		IF ((event.gesture = vyEvents.EvtSelect) OR (event.gesture = vyEvents.EvtIdent)) & (InScatter( event.x, event.y )) THEN
			priority := vyEvents.PrioNormal
		ELSIF (event.gesture = vyEvents.EvtLoc) & (scatter.edit) & InPoint( scatter, event.x, event.y, i ) THEN
			aM.dS( "met Point" );  priority := vyEvents.PrioNormal;
		ELSIF (event.gesture = vyEvents.EvtDoubleClick) & (scatter.edit) THEN priority := vyEvents.PrioNormal;
		END;
		IF event.priority < priority THEN event.responder := scatter;  event.priority := priority END
	END Responsible;

	PROCEDURE Consume( o: tLayer;  msg: Display.ConsumeMsg );
	VAR v: vyBase.tVector;  minX, maxX: Real;  pict: vyPort.Picture;  nans: SIGNED32;
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
			IF M.name = "Gen" THEN COPY( 'antsPointPlot2.Alloc', M.s );  M.class := Objects.String;  M.res := 0
			ELSIF M.name = "edit" THEN M.class := Objects.Bool;  M.b := obj.edit;  M.res := 0;
			ELSE vyPort.LayerHandler( obj, M )
			END  (*IF*)
		ELSIF M.id = Objects.set THEN
			IF M.name = "edit" THEN
				IF M.class = Objects.Bool THEN obj.edit := M.b;  M.res := 0;  END;
			ELSE vyPort.LayerHandler( obj, M )
			END;
		ELSIF M.id = Objects.enum THEN M.Enum( "edit" );  vyPort.LayerHandler( obj, M )
		ELSE vyPort.LayerHandler( obj, M )
		END  (*IF*)
	END HandleAttributes;

	PROCEDURE Store0( obj: tLayer;  VAR M: Objects.FileMsg );
	BEGIN
		Files.WriteInt( M.R, 0 );  Gadgets.WriteRef( M.R, obj.lib, obj.x );  Gadgets.WriteRef( M.R, obj.lib, obj.y );
		Files.WriteBool( M.R, obj.edit );
	END Store0;

	PROCEDURE Load0( obj: tLayer;  VAR M: Objects.FileMsg );

	VAR objsub: Objects.Object;  version: SIGNED16;

	BEGIN
		Files.ReadInt( M.R, version );  dlink := M.dlink;  Gadgets.ReadRef( M.R, obj.lib, objsub );
		IF (objsub # NIL ) & (objsub IS vyBase.tVector) THEN obj.x := objsub( vyBase.tVector ) END;
		Gadgets.ReadRef( M.R, obj.lib, objsub );
		IF (objsub # NIL ) & (objsub IS vyBase.tVector) THEN obj.y := objsub( vyBase.tVector ) END;
		Files.ReadBool( M.R, obj.edit );
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

	PROCEDURE deletePoint;
	VAR vx, vy: vyBase.tVector;  i: SIGNED32;
	BEGIN
		vx := tempLayer.x;  vy := tempLayer.y;
		FOR i := tempNum TO vx.nrData - 2 DO
			tempX := vyTypes.VGetR( vx, i + 1 );  tempY := vyTypes.VGetR( vy, i + 1 );
			IF vx IS vyLongrealVec.tVector THEN
				WITH vx: vyLongrealVec.tVector DO vyLongrealVec.Set( tempX, vx, i );
				END;
			ELSIF vx IS vyRealVec.tVector THEN
				WITH vx: vyRealVec.tVector DO vyRealVec.Set( tempX, vx, i );
				END;
			END;
			IF vy IS vyLongrealVec.tVector THEN
				WITH vy: vyLongrealVec.tVector DO vyLongrealVec.Set( tempY, vy, i );
				END;
			ELSIF vy IS vyRealVec.tVector THEN
				WITH vy: vyRealVec.tVector DO vyRealVec.Set( tempY, vy, i );
				END;
			END;
		END;
		IF vx IS vyLongrealVec.tVector THEN
			WITH vx: vyLongrealVec.tVector DO vyLongrealVec.SetLen( vx, vx.nrData - 1 );
			END;
		ELSIF vx IS vyRealVec.tVector THEN
			WITH vx: vyRealVec.tVector DO vyRealVec.SetLen( vx, vx.nrData - 1 );
			END;
		END;
		IF vy IS vyLongrealVec.tVector THEN
			WITH vy: vyLongrealVec.tVector DO vyLongrealVec.SetLen( vy, vy.nrData - 1 );
			END;
		ELSIF vy IS vyRealVec.tVector THEN
			WITH vy: vyRealVec.tVector DO vyRealVec.SetLen( vy, vy.nrData - 1 );
			END;
		END;

		vyBase.Update( vx );  vyBase.Update( vy );
	END deletePoint;

	PROCEDURE addPoint;
	VAR vx, vy: vyBase.tVector;
	BEGIN
		vx := tempLayer.x;  vy := tempLayer.y;
		IF vx IS vyLongrealVec.tVector THEN
			WITH vx: vyLongrealVec.tVector DO vyLongrealVec.Append( tempX, vx );
			END;
		ELSIF vx IS vyRealVec.tVector THEN
			WITH vx: vyRealVec.tVector DO vyRealVec.Append( tempX, vx );
			END;
		END;
		IF vy IS vyLongrealVec.tVector THEN
			WITH vy: vyLongrealVec.tVector DO vyLongrealVec.Append( tempY, vy );
			END;
		ELSIF vy IS vyRealVec.tVector THEN
			WITH vy: vyRealVec.tVector DO vyRealVec.Append( tempY, vy );
			END;
		END;
		vyBase.Update( vx );  vyBase.Update( vy );
	END addPoint;

	PROCEDURE Handler*( obj: Objects.Object;  VAR msg: Objects.ObjMsg );
	VAR copy: tLayer;  num: SIGNED32;
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
						ELSIF msg.gesture = vyEvents.EvtLoc THEN Loc( obj, msg )
						ELSIF msg.gesture = vyEvents.EvtDoubleClick THEN
							tempLayer := obj;
							IF InPoint( obj, msg.x, msg.y, num ) THEN tempNum := num;  deletePoint;
							ELSE vyGraphBase.PointToPoint2d( msg.x, msg.y, tempX, tempY );  addPoint;
							END;

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
			ELSIF msg IS vyCommandMenus.enumMsg THEN
				WITH msg: vyCommandMenus.enumMsg DO
					tempLayer := obj;
					IF obj.edit THEN
						IF InPoint( obj, msg.x, msg.y, num ) THEN msg.Enum( "deletePoint", deletePoint, obj );  tempNum := num;
						ELSE msg.Enum( "PointPlot: add Point", addPoint, obj );  vyGraphBase.PointToPoint2d( msg.x, msg.y, tempX, tempY );
						END;
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
			IF data # NIL THEN data := data.slink END;
			linePlot.y := vyBase.GetVFromObj( data );
			IF (linePlot.x = NIL ) OR (linePlot.y = NIL ) THEN aM.eS( "antsPointPlot2: need two vectors !" );  RETURN END;
			vyPort.OpenLayer( linePlot, id );  linePlot.handle := Handler;  vyBase.Subscribe( (*for messages from source*) linePlot.x,
																																															linePlot );
			vyBase.Subscribe( (*for messages from source*) linePlot.y, linePlot );
		END
	END Open;

	PROCEDURE Alloc*;
	BEGIN
		aM.cmd;  NEW( newlayer );  newlayer.handle := Handler;  Objects.NewObj := newlayer;  newlayer.edit := TRUE;
	END Alloc;

	PROCEDURE New*;
	VAR data: Objects.Object;
	BEGIN
		IF Objects.NewObj # NIL THEN data := Objects.NewObj ELSE RETURN END;
		Alloc;  Open( newlayer, data );  Objects.NewObj := newlayer
	END New;

	PROCEDURE ShowP*;
	VAR data: Objects.Object;  linePlot: tLayer;  pict: vyPort.Picture;  c: vyDisplay2d.tCoordinate2d;  minX, maxX: Real;
		nans: SIGNED32;
	BEGIN
		aM.vS( "antsPointPlot2.Show" );  data := vyBase.NextParObj();
		WHILE (data # NIL ) & (vyBase.parameterCount > 0) DO
			data.slink := vyBase.NextParObj();  Alloc;  linePlot := Objects.NewObj( tLayer );  Open( linePlot, data );
			vyTypes.VGetMinMax( linePlot.x, minX, maxX, nans );
			IF maxX = minX THEN minX := minX - 0.5;  maxX := minX + 1 END;

			NEW( c );  vyDisplay2d.OpenC2d( c, 0, minX, linePlot.x.nrData, maxX - minX );
			pict := vyPort.InsertNewCPicture( 0, 0, 1, 1, c );  vyPort.AddLayer( pict, linePlot );  data := vyBase.NextParObj()
		END;
		Objects.NewObj := pict
	END ShowP;

	PROCEDURE ShowL*( list: vyLinks.Link );
	VAR linePlot: tLayer;  pict: vyPort.Picture;  c: vyDisplay2d.tCoordinate2d;  minX, maxX: Real;  nans: SIGNED32;
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
	VAR linePlot: tLayer;  pict: vyPort.Picture;  c: vyDisplay2d.tCoordinate2d;  minX, maxX: Real;  nans: SIGNED32;
	BEGIN
		Alloc;  linePlot := Objects.NewObj( tLayer );  Open( linePlot, obj );
		vyTypes.VGetMinMax( linePlot.x, minX, maxX, nans );
		IF maxX = minX THEN minX := minX - 0.5;  maxX := minX + 1 END;

		NEW( c );  vyDisplay2d.OpenC2d( c, 0, minX, linePlot.x.nrData, maxX - minX );
		pict := vyPort.InsertNewCPicture( 0, 0, 1, 1, c );  vyPort.AddLayer( pict, linePlot );  Objects.NewObj := pict
	END ShowO;

BEGIN
	aM.launch;
END antsPointPlot2.

Voyager vyRegress vyLinePlot

Voyager.Random 200 ~
Voyager.Show @ as antsPointPlot ~
Voyager.Show @ as LinePlot ~
Voyager.Show @ ~
~
Generator:  U
New random numbers generated as
UPM05272EE6

Generator:  U
System.Free antsPointPlot2 ~
Voyager.Show UPM2BACE144 UPM2333720C as antsPointPlot2 ~
Generator:  U
New random numbers generated as
fofAutomatic.Do
antsFctVector.NewVec myvec 10 ~
antsFctVector.NewVec myvec2 10 ~
antsVecOpt.AddUniformNoise myvec myvec 1~
antsVecOpt.AddUniformNoise myvec2 myvec2 1~
Voyager.Show myvec myvec2 as antsPointPlot2 ~
Voyager.Show myvec myvec2 as Charts
~

antsTravelingS.Mod