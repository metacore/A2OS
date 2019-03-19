MODULE vyDisplay2d IN Oberon;
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



(*	(c) Project Voyager, StatLab Heidelberg
(c) G. Sawitzki, StatLab Heidelberg
(c) M. Diller, StatLab Heidelberg
(c) F.Friedrich, StatLab Heidelberg
*)

(*= basic 2d graphic routines
Mainly, this module provides a 2d coordinate system together with the necessary support routines
(including the explicit conversion from 2d to pixel and vice versa).
All display routines just convert the 2d coordinates and uses then the appropriate vyHostDisplay routines.*)

(*	history:
17.10.99 gs renamed to vyDisplay2d from vyPaint2d
7.8.95 md 0.0a1	alpha version
3.07.95 md 0.0d19	SyncFactors added / ScreenRgnChange & RealWorldRgnChange removed
___ new numberation ---
26.07.94 md 0.3d3	EraseString & InvertString added
27.07.94 md 0.3d4	GetRealWorldRgn added
27.10.94 md 0.0d13	adaped to the renamed vyHostDisplay
18.1.95 md 0.0d14	unnecessary Texts.Elem s  removed
26.1.95 md 0.0d15	cleaned
16.2.95 md 0.0d16	InsetRealWorldRegion added
12.4.95 md 0r0d17	FillArea added
21.06.94 md 0.1d1	created *)

(*!		zoom in and zoom out: no support of copy and load/store
add inset parameter to the tCoordinate: left, bottom, right, top, so that
(x-left, y-bottom, w-(left+right), h-(bottom+top))
represents the real world region (x2d, y2d, w2d, h2d).
Useful for plots with axis! *)

(*! move to vyGraphBase as far as possible *)
IMPORT Objects, vyBase, vyGraphBase, vyHostDisplay := vyGraphBase, Display, vyEvents, vyTracking (*,Out*) ,
	antsCommandList := vyCommandMenus, Input, Gadgets;

CONST
	idversion* = "vyDisplay2d v0r0a5";
	(*! remove restrictions *)
TYPE

	Real = vyBase.Real;  Coordinate = vyGraphBase.Coordinate;
	Selection* = POINTER TO SelDesc;
	SelDesc* = RECORD (Objects.ObjDesc)
		x*, y*, w*, h*: LONGREAL
	END;

	tCoordinate2d* = POINTER TO tCoordinate2dDesc;
	tCoordinate2dDesc* = RECORD (vyBase.ObjDesc)
		c2d*: vyGraphBase.tCoordinate2d;
		sel*: Selection
	END;

	CoordinateMessage* = RECORD (Objects.ObjMsg) END;

	CoordRgnMessage* = RECORD  (* tell the coordinate its actual screen region *)
	(CoordinateMessage)
		X*, Y*, W*, H*: INTEGER
	END;

	CoordSetMessage* = RECORD (CoordinateMessage) END;   (* tell the coordinate to be the current *)

	CoordZoomMessage* = RECORD (CoordinateMessage)
		in*: BOOLEAN;
		x*, y*, w*, h*: INTEGER
	END;
	AdjustCoordMsg* = RECORD (CoordinateMessage) END;
	ttt = RECORD
		x, y, dx, dy: INTEGER;
		c: tCoordinate2d
	END;
VAR
	command: ttt;
	currentsel*: Selection;   (* handled by antsGlobals *)
	passevent: BOOLEAN;


	(*PROCEDURE ShiftCoordinate (c: tCoordinate2d;      event: vyEvents.EventMsg);
	(*vs 0.0d0 *)	(* md  01.06.95 10:08:55 *)
	VAR  x0, y0: Coordinate;      dx, dy : Real;
	BEGIN
	x0 := event.x;      y0 := event.y;
	WHILE event.gesture = vyEvents.EvtLoc DO
	IF (event.x # x0) OR (event.y # y0) THEN
	vyGraphBase.VectorToVector2d ((event.x - x0), (event.y - y0), dx, dy);
	vyGraphBase.MoveRealWorldRgn (- dx, - dy);
	vyHostDisplay.FadeCursor;
	IF (dx # 0) OR (dy # 0) THEN (* fof 980427 *)
	(*Out.String("coordinates send update");Out.Ln(); *)
	vyBase.Update (c);
	(*Out.String("coordinate ready");Out.Ln(); *)
	END;
	vyGraphBase.SetCoordinate (c.c2d);      (* just in case some update did not restore it *)
	x0 := event.x;      y0 := event.y
	END;
	vyEvents.GetEvent (event)
	END
	END ShiftCoordinate;*)
	PROCEDURE ShiftCoordinate( c: tCoordinate2d;  event: vyEvents.EventMsg );
	(*vs 0.0d0 *)  (* md  01.06.95 10:08:55 *)
	VAR x0, y0, dxi, dyi: Coordinate;  dx, dy: Real;  x, y, w, h: Coordinate;
	BEGIN
		vyGraphBase.GetScreenRgn( x, y, w, h );  x0 := event.x;  y0 := event.y;
		WHILE event.gesture = vyEvents.EvtLoc DO
			IF (event.x # x0) OR (event.y # y0) THEN
				vyGraphBase.VectorToVector2d( (event.x - x0), (event.y - y0), dx, dy );
				vyGraphBase.MoveRealWorldRgn( -dx, -dy );  vyHostDisplay.FadeCursor;
				IF (dx # 0) OR (dy # 0) THEN  (* fof 980427 *)
					(*Out.String("coordinates send update");Out.Ln(); *)
					vyBase.Update( c );
					(*Out.String("coordinate ready");Out.Ln(); *)
				END;
				vyGraphBase.SetCoordinate( c.c2d );   (* just in case some update did not restore it *)
				vyGraphBase.SetScreenRgn( x, y, w, h );   (* just in case some update did not restore it (fof)*)
				x0 := event.x;  y0 := event.y
			END;
			vyEvents.GetEvent( event )
		END;
		IF event.gesture = vyEvents.EvtCopyAttr THEN
			vyGraphBase.SetCoordinate( c.c2d );  vyGraphBase.SetScreenRgn( x, y, w, h );
			vyTracking.GrowRectangleRL( x0, y0, 0, 0, dxi, dyi );
			IF dxi < 0 THEN x0 := x0 + dxi;  dxi := -dxi END;
			IF dyi < 0 THEN y0 := y0 + dyi;  dyi := -dyi END;
			IF (dxi # 0) & (dyi # 0) THEN vyGraphBase.ZoomIn( x0, y0, dxi, dyi );  vyBase.Update( c ) END

		END;
		IF event.gesture = vyEvents.EvtPointCmd (*EvtLeftMiddle *) THEN vyGraphBase.ZoomOut();  vyBase.Update( c ) END;
		Gadgets.Update( c )
	END ShiftCoordinate;

	PROCEDURE GrowRectangleRL*( x, y, w, h: INTEGER;  VAR dx, dy: INTEGER );
	(*vs 0.0a1  md  29.05.95 *)
	VAR keys, keys0: SET;  x1, y1, x0, y0, xOld, yOld: INTEGER;  oldm: INTEGER;
	BEGIN
		(* antsToolbox.StartDisplayHelp("Hold buttons and zoom rect"); *)
		vyGraphBase.GetDisplayMode( oldm );  vyGraphBase.SetDisplayMode( vyGraphBase.invert );
		Input.Mouse( keys0, x0, y0 );  vyGraphBase.DrawCursor( x0, y0 );  vyGraphBase.FrameRect( x, y, w, h );
		Input.Mouse( keys, x1, y1 );  xOld := x0;  yOld := y0;
		WHILE (keys = keys0) DO
			IF ((x1 # xOld) OR (y1 # yOld)) THEN
				vyGraphBase.FrameRect( x, y, w, h );  y := y + (y1 - yOld);  w := w + (x1 - xOld);  h := h - (y1 - yOld);
				vyGraphBase.FrameRect( x, y, w, h );  xOld := x1;  yOld := y1
			END;
			Input.Mouse( keys, x1, y1 );  vyGraphBase.DrawCursor( x1, y1 )
		END;
		vyGraphBase.FrameRect( x, y, w, h );  dx := x1 - x0;  dy := y1 - y0;  vyGraphBase.SetDisplayMode( oldm )
	END GrowRectangleRL;

	PROCEDURE AdjustRect( VAR x, y, w, h: INTEGER );
	BEGIN
		IF w < 0 THEN x := x + w;  w := -w END;
		IF h < 0 THEN y := y + h;  h := -h END
	END AdjustRect;

	PROCEDURE zoomin;
	BEGIN
		vyGraphBase.SetCoordinate( command.c.c2d );  AdjustRect( command.x, command.y, command.dx, command.dy );
		vyGraphBase.ZoomIn( command.x, command.y, command.dx, command.dy );  vyBase.Update( command.c )
	END zoomin;

	PROCEDURE zoomout;
	BEGIN
		vyGraphBase.SetCoordinate( command.c.c2d );  vyGraphBase.ZoomOut();  vyBase.Update( command.c )
	END zoomout;

	PROCEDURE AdjustRectR( VAR x, y, w, h: LONGREAL );
	BEGIN
		IF w < 0 THEN x := x + w;  w := -w END;
		IF h < 0 THEN y := y + h;  h := -h END
	END AdjustRectR;

	PROCEDURE usecurrentsel;
	VAR c: tCoordinate2d;
	BEGIN
		c := command.c;  c.sel := currentsel
	END usecurrentsel;

	PROCEDURE removesel;
	BEGIN
		command.c.sel := NIL
	END removesel;

	PROCEDURE selectlayer;
	BEGIN
		passevent := TRUE
	END selectlayer;

	PROCEDURE MakeSel*( c: tCoordinate2d;  sel: Selection;  x, y, w, h: INTEGER );
	BEGIN
		(* vyGraphBase.Global2Local(x,y); *)
		vyGraphBase.SetCoordinate( c.c2d );  vyGraphBase.RectToRect2d( x, y, w, h, sel.x, sel.y, sel.w, sel.h );
		AdjustRectR( sel.x, sel.y, sel.w, sel.h )
	END MakeSel;

	PROCEDURE Select( c: tCoordinate2d;  VAR event: vyEvents.EventMsg );
	VAR x0, y0, dx, dy: INTEGER;  l: antsCommandList.List;

	BEGIN
		currentsel := c.sel;  passevent := FALSE;  l := antsCommandList.current;  x0 := event.x;  y0 := event.y;
		GrowRectangleRL( x0, y0, 0, 0, dx, dy );  command.x := x0;  command.y := y0;  command.dx := dx;  command.dy := dy;
		command.c := c;
		IF (dx # 0) & (dy # 0) THEN
			antsCommandList.currentmode := antsCommandList.select;  antsCommandList.current := NIL;  l := NIL;
			antsCommandList.Add( l, zoomout, "Zoom out " );  antsCommandList.Add( l, zoomin, "Zoom in" );  antsCommandList.current := l;
			vyGraphBase.SetDisplayMode( vyGraphBase.invert );  vyGraphBase.SetPenSize( 2 );
			vyGraphBase.FrameRect( x0, y0, dx, dy );  vyGraphBase.SetPenSize( 1 );
			vyGraphBase.SetDisplayMode( vyGraphBase.paint );  antsCommandList.Add( l, usecurrentsel, "Keep Selection" );  NEW( currentsel );
			MakeSel( c, currentsel, x0, y0, dx, dy )
		ELSE
			antsCommandList.Add( l, zoomout, "Zoom out " );  antsCommandList.currentmode := antsCommandList.click;  currentsel := NIL;
			IF c.sel # NIL THEN antsCommandList.Add( l, removesel, "Remove Selection" ) END;
			antsCommandList.Add( l, selectlayer, "mouse event to layers" )
		END;
		antsCommandList.ExecuteListedCommand( x0 + dx, y0 + dy, event, l );
		IF ~passevent THEN antsCommandList.Wait() END;
		vyGraphBase.SetCoordinate( c.c2d );  vyBase.Update( c );
		IF passevent THEN event.callForResponder := TRUE ELSE event.callForResponder := FALSE END  (* port goes on with event *)
	END Select;

	PROCEDURE CopyC2d*( source, dest: tCoordinate2d );   (* fof 01011 marked as exported *)
	BEGIN
		NEW( dest.c2d );  vyGraphBase.CopyCoordinate2d( source.c2d, dest.c2d );  dest.handle := source.handle;
		dest.sel := source.sel
	END CopyC2d;

	PROCEDURE DoHandleC2dAttributes( o: tCoordinate2d;  VAR M: Objects.AttrMsg );
	BEGIN
		IF (M.id = Objects.get) & (M.name = "Gen") THEN M.class := Objects.String;  COPY( "vyDisplay2d.C2dGen", M.s );  M.res := 0
		ELSE
			vyGraphBase.HandleCoordinate2dAttr( M, o.c2d );
			IF (M.id = Objects.set) & (M.res = 0) THEN vyBase.Update( o ) END
		END
	END DoHandleC2dAttributes;

	PROCEDURE C2dHandler*( o: Objects.Object;  VAR msg: Objects.ObjMsg );   (* fof 01011 marked as exported *)
	(*vs 0.0d0 *)  (* md  01.06.95 09:37:47 *)
	VAR c, c2dcopy: tCoordinate2d;
	BEGIN
		ASSERT ( o IS tCoordinate2d, 102 );
		c := o( tCoordinate2d );
		IF msg IS CoordRgnMessage THEN
			WITH msg: CoordRgnMessage DO vyGraphBase.SetScreenRgn( msg.X, msg.Y, msg.W, msg.H )
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
					ELSIF (msg.gesture = vyEvents.EvtWheelUp) THEN
						vyGraphBase.SetCoordinate( c.c2d );  vyGraphBase.ZoomIn( msg.x, msg.y, 0, 0 );  vyBase.Update( c );
					ELSIF (msg.gesture = vyEvents.EvtWheelDown) THEN
						vyGraphBase.SetCoordinate( c.c2d );  vyGraphBase.ZoomOut;  vyBase.Update( c );
					ELSE ShiftCoordinate( c, msg )
					END
				END;
			END;
		ELSIF msg IS CoordSetMessage THEN
			WITH msg: CoordSetMessage DO vyGraphBase.SetCoordinate( c.c2d )
			END;
		ELSIF msg IS Objects.CopyMsg THEN
			WITH msg: Objects.CopyMsg DO
				IF msg.stamp = c.stamp THEN msg.obj := c.dlink ELSE
					IF msg.id = Objects.deep THEN
						NEW( c2dcopy );  vyBase.CopyObject( msg, c, c2dcopy );  CopyC2d( c, c2dcopy );  msg.obj := c2dcopy
					ELSE c2dcopy := c;  msg.obj := c2dcopy
					END
				END
			END;
		ELSIF msg IS CoordZoomMessage THEN
			WITH msg: CoordZoomMessage DO
			(* Out.Ln; Out.String("Zoom"); *)
				IF ~msg.in THEN vyGraphBase.ZoomOut ELSE vyGraphBase.ZoomIn( msg.x, msg.y, msg.w, msg.h ) END
			END;
		ELSIF msg IS Display.DisplayMsg THEN
			WITH msg: Display.DisplayMsg DO
				IF c.sel # NIL THEN
					vyGraphBase.SetDisplayMode( vyGraphBase.invert );  vyGraphBase.SetPenSize( 2 );
					vyGraphBase.FrameRect2d( c.sel.x, c.sel.y, c.sel.w, c.sel.h );  vyGraphBase.SetPenSize( 1 );
					vyGraphBase.SetDisplayMode( vyGraphBase.paint )
				END;

			END;
		ELSIF msg IS Objects.AttrMsg THEN
			WITH msg: Objects.AttrMsg DO DoHandleC2dAttributes( c, msg( Objects.AttrMsg ) );
			END;
		ELSIF msg IS Objects.FileMsg THEN
			WITH msg: Objects.FileMsg DO  (* Implement magic number ! , do it by storing NIL once, that could help .. *)
				IF msg.id = Objects.load THEN vyBase.objecthandle( o, msg );  vyGraphBase.ReadCoordinate2d( msg.R, c.c2d )
				ELSIF msg.id = Objects.store THEN vyBase.objecthandle( o, msg );  vyGraphBase.WriteCoordinate2d( msg.R, c.c2d )
				ELSE vyBase.objecthandle( o, msg )
				END
			END;
		ELSE vyBase.objecthandle( o, msg )
		END
	END C2dHandler;

	PROCEDURE C2dGen*;
	VAR c: tCoordinate2d;
	BEGIN
		NEW( c );  NEW( c.c2d );  vyGraphBase.OpenCoordinate2d( c.c2d, 0, 0, 1, 1 );  c.handle := C2dHandler;  Objects.NewObj := c
	END C2dGen;

	PROCEDURE OpenC2d*( c: tCoordinate2d;  x, y, w, h: Real );
	(*vs 0.0d0 *)  (* md  01.06.95 09:39:06 *)
	(*? support additional slack, eg. in a separate open routine ?*)
	VAR coord: vyGraphBase.tCoordinate2d;
	BEGIN
		NEW( coord );  vyGraphBase.OpenCoordinate2d( coord, x, y, w, h );  c.c2d := coord;  c.handle := C2dHandler
	END OpenC2d;

	PROCEDURE NewC2d*( x, y, w, h: Real ): tCoordinate2d;   (*= NewOpenC2d *)
	VAR c: tCoordinate2d;
	BEGIN
		NEW( c );  OpenC2d( c, x, y, w, h );  RETURN c
	END NewC2d;

END vyDisplay2d.

