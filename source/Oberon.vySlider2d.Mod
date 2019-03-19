MODULE vySlider2d IN Oberon;
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


(* 	(c) Project Voyager, StatLab Heidelberg
(c) M. Diller, StatLab Heidelberg *)
(*= a slider for the 2d plane*)
(*	history:
9.8.95 md 0.0a1	alpha version
26.1.95 md 0.0d3	cleaned
27.10.94 md 0.0d2	adaped to the renamed vyHostDisplay & vyPictures
19.08.94 md 0.0d0	created *)
(*!	type guard missed: lousy mistake *)

IMPORT Objects, Display, vyHostTexts, vyBase, vyName, vyRealVec, vyTypes, vyHostDisplay := vyGraphBase, vyGraphBase,
	vyDisplay2d, vyPort, vyCharts, vySlider, vyEvents;

CONST
	idversion* = "vySlider2d v0r0d6";

TYPE
	Real = vyBase.Real;
	tLayer* = POINTER TO tLayerDesc;

	tCtlSlider = POINTER TO tCtlSliderDesc;
	tCtlSliderDesc = RECORD (vySlider.tSliderDesc)
		host: tLayer
	END;

	tLayerDesc = RECORD (vyCharts.tLayerDesc)
		locked: BOOLEAN;
		pos: LONGINT;
		slider: tCtlSlider
	END;

	tMsg* = RECORD (Objects.ObjMsg) END;

VAR
	ball, canal: vyHostDisplay.tSign;

	PROCEDURE Line( x, y, X, Y: INTEGER );
	(* from Curves.Mod with simple modifications 	md 08.02.94 *)
	VAR x1, y1, u, d, w, h: INTEGER;
	BEGIN
		w := X - x;  h := Y - y;
		IF w < 0 THEN x := x + w;  y := y + h;  w := -w;  h := -h END;
		IF h < 0 THEN y := y + h;  h := -h;  d := -1 ELSE d := 1 END;

		IF h < w THEN
			x1 := x + w;  u := (h - w) DIV 2;
			IF d = -1 THEN INC( y, h ) END;
			WHILE x < x1 DO
				vyHostDisplay.PaintPat( x, y, canal );  INC( x );
				IF u < 0 THEN INC( u, h ) ELSE INC( u, h - w );  INC( y, d ) END
			END
		ELSE
			y1 := y + h;  u := (w - h) DIV 2;
			IF d = -1 THEN INC( x, w ) END;
			WHILE y < y1 DO
				vyHostDisplay.PaintPat( x, y, canal );  INC( y );
				IF u < 0 THEN INC( u, w ) ELSE INC( u, w - h );  INC( x, d ) END
			END
		END
	END Line;

	PROCEDURE MoveBallTo( slider2d: tLayer;  pos: LONGINT );
	VAR x, y: INTEGER;  lastPos: LONGINT;
	BEGIN
		vyHostDisplay.SetPatternJustification( vyHostDisplay.center, vyHostDisplay.center );  lastPos := slider2d.pos;
		vyGraphBase.Point2dToPoint( vyTypes.VGetR( slider2d.x, lastPos ), vyTypes.VGetR( slider2d.y, lastPos ), x, y );
		vyHostDisplay.SetForeColor( 15 );  vyHostDisplay.PaintPat( x, y, ball );
		vyGraphBase.Point2dToPoint( vyTypes.VGetR( slider2d.x, pos ), vyTypes.VGetR( slider2d.y, pos ), x, y );
		vyHostDisplay.SetForeColor( 0 );  vyHostDisplay.PaintPat( x, y, ball );  slider2d.pos := pos
	END MoveBallTo;

	PROCEDURE Recall( slider2d: tLayer;  VAR msg: Display.DisplayMsg );
	VAR xOld, yOld, x, y, w, h: INTEGER;  i: LONGINT;

		PROCEDURE RecallBall( slider2d: tLayer );
		VAR X, Y: INTEGER;  p: LONGINT;
		BEGIN
			vyHostDisplay.SetDisplayMode( vyHostDisplay.invert );  p := slider2d.pos;
			vyGraphBase.Point2dToPoint( vyTypes.VGetR( slider2d.x, p ), vyTypes.VGetR( slider2d.y, p ), X, Y );
			vyHostDisplay.SetForeColor( 0 );  vyHostDisplay.PaintPat( X, Y, ball );
			vyHostDisplay.SetDisplayMode( vyHostDisplay.replace )
		END RecallBall;

	BEGIN
		vyHostDisplay.SetPatternJustification( vyHostDisplay.center, vyHostDisplay.center );
		IF ~slider2d.locked THEN
			vyPort.GetPictureScreenRegion( msg.dlink( vyPort.Picture ), x, y, w, h );  vyHostDisplay.String( x + 10, y + 10, "", "define slider's path" )
		END;
		vyGraphBase.Point2dToPoint( vyTypes.VGetR( slider2d.x, 0 ), vyTypes.VGetR( slider2d.y, 0 ), xOld, yOld );
		FOR i := 1 TO slider2d.x.nrData - 1 DO
			vyGraphBase.Point2dToPoint( vyTypes.VGetR( slider2d.x, i ), vyTypes.VGetR( slider2d.y, i ), x, y );
			Line( xOld, yOld, x, y );  xOld := x;  yOld := y
		END;   (* FOR i := 0 TO layer.firstUnUsed -  1 *)

		IF slider2d.locked THEN RecallBall( slider2d ) END
	END Recall;

	PROCEDURE Copy( sLayer, dLayer: tLayer );
	(*  *)
	BEGIN
		dLayer.locked := sLayer.locked;  dLayer.pos := sLayer.pos
	END Copy;

	PROCEDURE DefinePath( slider2d: tLayer;  VAR event: vyEvents.EventMsg );
	VAR x, y: INTEGER;

		PROCEDURE WriteData;
		VAR x2d, y2d: Real;
		BEGIN
			vyGraphBase.PointToPoint2d( x, y, x2d, y2d );  vyRealVec.Append( x2d, slider2d.x );
			vyRealVec.Append( y2d, slider2d.y )
			(*		INC(slider2d.firstUnUsed);*)
		END WriteData;

		PROCEDURE Lock;
		VAR res: INTEGER;
		BEGIN
			slider2d.locked := TRUE;  NEW( slider2d.slider );
			vySlider.Open( slider2d.slider, event.dlink( vyPort.Picture ), 0, slider2d.x.nrData - 1, 0, SHORT( slider2d.x.nrData ) );
			slider2d.slider.host := slider2d;  vyPort.AddLayer( event.dlink( vyPort.Picture ), slider2d.slider );
			vyBase.CallWString( idversion, "vySlider.Cmd", "vySlider2d.Sync", TRUE , res )
		END Lock;

		PROCEDURE Clear;
		BEGIN  (*slider2d.firstUnUsed := 1 *)
			vyBase.Clear( slider2d.x );  vyBase.Clear( slider2d.y )
		END Clear;

	BEGIN
		vyHostDisplay.SetDisplayMode( vyHostDisplay.replace );  x := event.x;  y := event.y;  WriteData;
		WHILE (event.gesture = vyEvents.EvtIdent) DO
			vyEvents.GetEvent( event );
			IF (x # event.x) OR (y # event.y) THEN
				vyHostDisplay.FadeCursor;  Line( x, y, event.x, event.y );  vyHostDisplay.DrawCursor( event.x, event.y );
				x := event.x;  y := event.y;  WriteData
			END
		END;   (* WHILE (event IS Events.tPick) *)

		IF event.gesture = vyEvents.EvtEmpty THEN Lock ELSE Clear END;
		vyPort.UpdateHostPicture( slider2d, event )
	END DefinePath;

	PROCEDURE Responsible( slider: tLayer;  VAR event: vyEvents.EventMsg );
	VAR priority: INTEGER;
	BEGIN
		priority := vyEvents.PrioNone;
		IF (event.gesture = vyEvents.EvtIdent) & ~(slider.locked) THEN priority := vyEvents.PrioNormal
		ELSIF (event.gesture = vyEvents.EvtSelect) & (slider.locked) THEN priority := vyEvents.PrioNormal
		END;

		IF event.priority < priority THEN event.responder := slider;  event.priority := priority
		END
	END Responsible;

	PROCEDURE Handler*( o: Objects.Object;  VAR msg: Objects.ObjMsg );
	(*s 0.0a1	md  20.07.94 *)
	VAR slider, copy: tLayer;  done: BOOLEAN;  i: LONGINT;
	BEGIN
		slider := o( tLayer );  done := FALSE;

		IF msg IS Display.DisplayMsg THEN
			WITH msg: Display.DisplayMsg DO Recall( slider, msg );  done := TRUE
			END;
		ELSIF msg IS tMsg THEN
			WITH msg: tMsg DO vyHostTexts.Msg( "handler ok" );  MoveBallTo( slider, ENTIER( slider.slider.value ) );  done := TRUE
			END;
		ELSIF msg IS vyEvents.EventMsg THEN
			WITH msg: vyEvents.EventMsg DO
				IF msg.callForResponder THEN Responsible( slider, msg ) ELSE
					IF msg.gesture = vyEvents.EvtSelect THEN
						WHILE msg.gesture = vyEvents.EvtSelect DO
							i := (slider.pos + 1) MOD  (*slider.firstUnUsed;*) slider.x.nrData;  MoveBallTo( slider, i );
							vyEvents.GetEvent( msg )
						END

					ELSIF msg.gesture = vyEvents.EvtIdent THEN DefinePath( slider, msg )
					END
				END;
				done := TRUE
			END;
		ELSIF msg IS Objects.CopyMsg THEN
			WITH msg: Objects.CopyMsg DO
				NEW( copy );  msg.obj := copy;  vyCharts.Handler( slider, msg );  Copy( slider, msg.obj( tLayer ) );  done := TRUE
			END;
		ELSIF msg IS vyBase.UpdateMessage THEN
			WITH msg: vyBase.UpdateMessage DO MoveBallTo( slider, ENTIER( slider.slider.value ) )
			END;
		ELSE
		END;

		IF ~done THEN vyCharts.Handler( slider, msg )
		END
	END Handler;

	PROCEDURE Open( slider: tLayer;  picture: vyPort.Picture );
	VAR id: vyName.tNameArray;
	BEGIN
		COPY( "2d slider", id );  vyCharts.OpenChart128( slider, id );  slider.pos := 0;  slider.slider := NIL;  slider.handle := Handler;
		slider.locked := FALSE
	END Open;

	PROCEDURE Insert*;
	VAR pict: vyPort.Picture;  slider: tLayer;

	BEGIN  (*	get and check focused picture			  *)
		pict := vyPort.GetFocusPicture();
		IF pict = NIL THEN vyHostTexts.Msg( "no picture focused" );  RETURN END;

		(*	add slider to the focus pict	  *)
		NEW( slider );  Open( slider, pict );  vyPort.AddLayer( pict, slider );  vyPort.PictureUpdate( pict )
	END Insert;

	PROCEDURE Define*;
	VAR pict: vyPort.Picture;  slider: tLayer;

	BEGIN  (*	new picture			  *)
		pict := vyPort.InsertNewCPicture( 0, 0, 1, 1, vyDisplay2d.NewC2d( 0, 0, 1, 1 ) );
		IF pict = NIL THEN vyHostTexts.Msg( "no focus picture" );  RETURN END;

		(*	add slider to the focus pict	  *)
		NEW( slider );  Open( slider, pict );  vyPort.AddLayer( pict, slider );  vyPort.PictureUpdate( pict )
	END Define;

	PROCEDURE Sync*;
	VAR layer: vyPort.tLayer;  slider2d: tLayer;  id: vyName.tNameArray;  event: tMsg;
	BEGIN
		layer := vyPort.FocusLayer();  vyName.GetObjId( layer, id );  vyHostTexts.Msg( id );  layer.handle( layer, event );
		RETURN;

		IF layer IS tLayer THEN slider2d := layer( tLayer );  vyHostTexts.Msg( "layer IS tLayer, ok!" )
		ELSIF layer IS vyCharts.tLayer THEN vyHostTexts.Msg( "mist: alter Fehler vyCharts statt 2dSlider" );  RETURN

		ELSIF layer IS tCtlSlider THEN slider2d := layer( tCtlSlider ).host;  vyHostTexts.Msg( "layer IS tCtlSlider, ok!" )
		ELSIF layer IS vySlider.tSlider THEN vyHostTexts.Msg( "mist: jetzt auch tCtlSlider als vySlider.tSlider" );  RETURN

		ELSE vyHostTexts.Msg( "can't get the slider" );  RETURN
		END;

		MoveBallTo( slider2d, ENTIER( slider2d.slider.value ) )
	END Sync;

	PROCEDURE InitPattern;
	VAR image: ARRAY 10 OF SET;
	BEGIN  (*	ball		  *)
		image[1] := {1, 2};  image[2] := {0, 1, 2, 3};  image[3] := image[2];  image[4] := image[1];
		ball := vyHostDisplay.NewPattern( image, 4, 4, NIL );

		(*	canal	  *)
		image[1] := {2, 3};  image[2] := {1, 2, 3, 4};  image[3] := {0, 1, 2, 3, 4, 5};  image[4] := image[3];
		image[5] := image[2];  image[6] := image[1];  canal := vyHostDisplay.NewPattern( image, 6, 6, NIL )
	END InitPattern;

BEGIN
	InitPattern;
END vySlider2d.