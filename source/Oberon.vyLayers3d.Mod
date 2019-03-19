MODULE vyLayers3d IN Oberon;   (*vs 0.0a1 md   09.08.95 *)
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
(*= abstract ancestor of all 3d layers *)
(*! place the coordinate system somewhere else (e.g. vyCoordinates in vyPort)	*)

IMPORT Objects, vyBase, vyGraphBase, Oberon, vyDisplay2d, vyPHIGS3D, vyPaint3d, Input,
	antsCommandList := vyCommandMenus, vyPort, vyEvents;

CONST
	idversion* = "vyLayer3d v0r0a3";

TYPE
	Coordinate = vyGraphBase.Coordinate;
	tCoordinate3d* = POINTER TO tCoordinate3dDesc;
	tCoordinate3dDesc = RECORD (vyDisplay2d.tCoordinate2dDesc)
		c3d-: vyPHIGS3D.tCoordinate3d
	END;

	tLayer* = POINTER TO tLayerDesc;
	tLayerDesc* = RECORD (vyPort.tLayerDesc) END;

VAR
	newcoordinate3d*: tCoordinate3d;  newLayer*: tLayer;  passevent: BOOLEAN;

	PROCEDURE CopyC3d( src, dest: tCoordinate3d );
	BEGIN
		NEW( dest.c3d );  vyPHIGS3D.CopyCoordinate( src.c3d, dest.c3d );  NEW( dest.c2d );
		vyGraphBase.CopyCoordinate2d( src.c2d, dest.c2d );  dest.handle := src.handle
	END CopyC3d;

	PROCEDURE Handler*( o: Objects.Object;  VAR msg: Objects.ObjMsg );
	BEGIN
		vyPort.LayerHandler( o, msg )
	END Handler;

	PROCEDURE Open*( layer: tLayer;  id: ARRAY OF CHAR );
	BEGIN
		vyPort.OpenLayer( layer, id )
	END Open;

	PROCEDURE OpenViewWindow( c: tCoordinate3d;  event: vyEvents.EventMsg );
	VAR time: LONGINT;
	BEGIN
		vyPort.onTheFly := TRUE;  time := Oberon.Time();
		WHILE event.gesture = vyEvents.EvtCopyAttr DO
			time := Oberon.Time() + Input.TimeUnit DIV 10;  vyPHIGS3D.ResizeVWL( 0.05, 0.05 );  vyBase.Update( c );
			WHILE (event.gesture = vyEvents.EvtCopyAttr) & (time - Oberon.Time() > 0) DO vyEvents.GetEvent( event ) END
		END;
		WHILE event.gesture # vyEvents.EvtEmpty DO vyEvents.GetEvent( event ) END;
		vyPort.onTheFly := FALSE;  vyBase.Update( c )
	END OpenViewWindow;

	PROCEDURE OpenViewWindow2( c: tCoordinate3d;  event: vyEvents.EventMsg );
	VAR time: LONGINT;
	BEGIN
		vyPort.onTheFly := TRUE;  time := Oberon.Time();
		WHILE event.gesture = vyEvents.EvtPointCmd DO
			time := Oberon.Time() + Input.TimeUnit DIV 10;  vyPHIGS3D.ResizeVWL( -0.05, -0.05 );  vyBase.Update( c );
			WHILE (event.gesture = vyEvents.EvtPointCmd) & (time - Oberon.Time() > 0) DO vyEvents.GetEvent( event ) END
		END;
		WHILE event.gesture # vyEvents.EvtEmpty DO vyEvents.GetEvent( event ) END;
		vyPort.onTheFly := FALSE;  vyBase.Update( c )
	END OpenViewWindow2;

	PROCEDURE CloseViewWindow( c: tCoordinate3d;  event: vyEvents.EventMsg );
	BEGIN
		vyPort.onTheFly := TRUE;
		WHILE event.gesture = vyEvents.EvtUnknown DO
			vyPHIGS3D.ResizeVWL( -0.05, -0.05 );  vyBase.Update( c );  vyEvents.GetEvent( event )
		END;
		WHILE event.gesture # vyEvents.EvtEmpty DO vyEvents.GetEvent( event ) END;
		vyPort.onTheFly := FALSE;  vyBase.Update( c )
	END CloseViewWindow;

	PROCEDURE Rotate( c: tCoordinate3d;  event: vyEvents.EventMsg );
	(*vs 0.0a1 *)  (* md	 03.05.94 *)
	CONST toleranz = 1;
	VAR x0, y0, x1, y1: Coordinate;

		PROCEDURE NextRotationStep( continously: BOOLEAN );
		(*vs 0.0a1 *)  (* md  15.12.94 *)
		BEGIN
			vyPHIGS3D.rotate( continously, x0, y0, x1, y1 );  vyBase.Update( c )
		END NextRotationStep;

	BEGIN
		x0 := event.x;  y0 := event.y;  x1 := x0;  y1 := y0;  vyPHIGS3D.SetRotationControl( x0, y0 );  vyPort.onTheFly := TRUE;
		WHILE event.gesture = vyEvents.EvtLoc DO
			IF (x1 # x0) OR (y1 # y0) THEN NextRotationStep( FALSE );  x0 := x1;  y0 := y1 END;
			vyEvents.GetEvent( event );  x1 := event.x;  y1 := event.y
		END;

		IF (event.gesture = vyEvents.EvtEmpty) & (ABS( x1 - x0 ) > toleranz) OR (ABS( y1 - y0 ) > toleranz) THEN
			WHILE event.gesture = vyEvents.EvtEmpty DO NextRotationStep( TRUE );  vyEvents.GetEvent( event ) END
		ELSIF event.gesture = vyEvents.EvtCopyAttr THEN OpenViewWindow( c, event )
		ELSIF event.gesture = vyEvents.EvtPointCmd THEN OpenViewWindow2( c, event )
		END;
		vyPort.onTheFly := FALSE;  vyBase.Update( c )
	END Rotate;

	PROCEDURE DoHandleC3dAttributes( o: tCoordinate3d;  VAR M: Objects.AttrMsg );
	BEGIN
		IF (M.id = Objects.get) & (M.name = "Gen") THEN M.class := Objects.String;  COPY( "vyLayers3d.NewCoordinate3d", M.s );  M.res := 0 ELSE END
	END DoHandleC3dAttributes;

	PROCEDURE selectlayer;
	BEGIN
		passevent := TRUE
	END selectlayer;

	PROCEDURE Select( c: tCoordinate3d;  VAR event: vyEvents.EventMsg );
	VAR x0, y0: INTEGER;  l: antsCommandList.List;
	BEGIN
		passevent := FALSE;  l := antsCommandList.current;  x0 := event.x;  y0 := event.y;
		antsCommandList.currentmode := antsCommandList.click;  antsCommandList.Add( l, selectlayer, "mouse event to layers" );
		antsCommandList.Wait();  antsCommandList.ExecuteListedCommand( x0, y0, event, l );
		IF ~passevent THEN antsCommandList.Wait() END;
		vyBase.Update( c );
		IF passevent THEN event.callForResponder := TRUE ELSE event.callForResponder := FALSE END  (* port goes on with event *)
	END Select;

	PROCEDURE C3dHandler( o: Objects.Object;  VAR msg: Objects.ObjMsg );
	(*vs 0.0a1 *)  (* md  01.06.95 *)
	VAR c, copy: tCoordinate3d;
	BEGIN
		ASSERT ( o IS tCoordinate3d, 102 );
		c := o( tCoordinate3d );

		IF msg IS vyDisplay2d.CoordRgnMessage THEN
			WITH msg: vyDisplay2d.CoordRgnMessage DO vyGraphBase.SetScreenRgn( msg.X, msg.Y, msg.W, msg.H )
			END;
		ELSIF msg IS vyDisplay2d.CoordSetMessage THEN
			WITH msg: vyDisplay2d.CoordSetMessage DO vyGraphBase.SetCoordinate( c.c2d );  vyPaint3d.SetCoordinate( c.c3d )
			END;
		ELSIF msg IS vyEvents.EventMsg THEN
			WITH msg: vyEvents.EventMsg DO
				IF msg.callForResponder THEN
					IF (msg.gesture = vyEvents.EvtLoc) OR (msg.gesture = vyEvents.EvtWheelUp) OR
					    (msg.gesture = vyEvents.EvtWheelDown) THEN
						IF msg.responder # NIL THEN msg.responder := NIL ELSE msg.responder := o END
					ELSIF (msg.gesture = vyEvents.EvtSelect) THEN msg.responder := o
					END
				ELSE
					IF msg.gesture = vyEvents.EvtSelect THEN Select( c, msg )
					ELSIF msg.gesture = vyEvents.EvtLoc THEN Rotate( c, msg )
					ELSIF msg.gesture = vyEvents.EvtCopyAttr THEN OpenViewWindow( c, msg )
					ELSIF msg.gesture = vyEvents.EvtPointCmd THEN OpenViewWindow2( c, msg )
					ELSIF (msg.gesture = vyEvents.EvtWheelUp) THEN vyPHIGS3D.ResizeVWL( -0.05, -0.05 );  vyBase.Update( c );

					ELSIF (msg.gesture = vyEvents.EvtWheelDown) THEN vyPHIGS3D.ResizeVWL( 0.05, 0.05 );  vyBase.Update( c );
					END
				END;
			END;
		ELSIF msg IS Objects.CopyMsg THEN
			WITH msg: Objects.CopyMsg DO NEW( copy );  CopyC3d( c, copy );  msg.obj := copy;
			END;
		ELSIF msg IS vyDisplay2d.CoordZoomMessage THEN
			WITH msg: vyDisplay2d.CoordZoomMessage DO
				IF ~msg.in THEN  (*vyPaint3d.ZoomOut*)
				ELSE  (*vyPaint3d.ZoomIn (msg.x, msg.y, msg.w, msg.h)*)
				END
			END;
		ELSIF msg IS Objects.AttrMsg THEN
			WITH msg: Objects.AttrMsg DO DoHandleC3dAttributes( c, msg( Objects.AttrMsg ) );
			END;
		ELSIF msg IS Objects.FileMsg THEN
			WITH msg: Objects.FileMsg DO
				IF msg.id = Objects.load THEN vyDisplay2d.C2dHandler( c, msg );  vyPHIGS3D.LoadCoord3d( msg.R, c.c3d )
				ELSIF msg.id = Objects.store THEN vyDisplay2d.C2dHandler( c, msg );  vyPHIGS3D.StoreCoord3d( msg.R, c.c3d )
				ELSE vyDisplay2d.C2dHandler( o, msg )
				END
			END;
		ELSE vyDisplay2d.C2dHandler( o, msg )
		END

	END C3dHandler;

	PROCEDURE OpenC3d*( c: tCoordinate3d );
	VAR coord: vyPHIGS3D.tCoordinate3d;  c2d: vyGraphBase.tCoordinate2d;  err: INTEGER;
	BEGIN
		NEW( coord );  vyPHIGS3D.OpenCoordinate( coord, err );  NEW( c2d );  vyGraphBase.OpenCoordinate2d( c2d, 0, 0, 1, 1 );
		c.c3d := coord;  c.c2d := c2d;  c.handle := C3dHandler
	END OpenC3d;

	PROCEDURE NewCoordinate3d*;
	BEGIN
		NEW( newcoordinate3d );  OpenC3d( newcoordinate3d );  Objects.NewObj := newcoordinate3d
	END NewCoordinate3d;

	PROCEDURE NewLayer3d*;
	BEGIN
		NEW( newLayer );  Open( newLayer, '- new -' );  Objects.NewObj := newLayer
	END NewLayer3d;

END vyLayers3d.