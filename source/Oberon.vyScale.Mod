MODULE vyScale IN Oberon;
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
(c) M. Diller, StatLab Heidelberg
(c) F. Friedrich, StatLab Heidelberg
*)

(*= Scale *)

(*	history:
960822 fof reimplemented variable digits and axis translation
9.8.95 md 0.0a1 	alpha version
10.3.95 md 0.0d0	created
*)

(*!		concept for digits*)

IMPORT Objects, Display, vyGraphBase, Files, vyRectangles, vyPort, vyAxis, vyParser, vyEvents;

CONST
	idversion* = "vyScale v0r0a2";  yTopMargin = 10 * vyGraphBase.pixel;  yBotMargin = 35 * vyGraphBase.pixel;
	yWidth = 35 * vyGraphBase.pixel;  xLeftMargin = yWidth;  xRigthMargin = 10 * vyGraphBase.pixel;
	xHeigth = yBotMargin;  LabelFont = "Syntax10.Scn.Fnt";  left = 0;  middle = 1;  right = 2;  top = 0;  bottom = 2;

TYPE
	Real = vyGraphBase.Real;  Coordinate = vyGraphBase.Coordinate;

	tLayer* = POINTER TO tLayerDesc;
	tLayerDesc* = RECORD (vyPort.tLayerDesc)
		hdigits, vdigits: SIGNED16;
		haxe: vyAxis.tAxe;
		vaxe: vyAxis.tAxe;
		ow, oh: Coordinate;
		hr, vr: Real;
		dx, dy: Coordinate;
		xregion, yregion: Coordinate;
		ToReal: BOOLEAN;
		trx, try: FLOAT32
	END;

VAR
	newlayer-: tLayer;

	PROCEDURE Min( a, b: SIGNED16 ): SIGNED16;
	BEGIN
		IF a < b THEN RETURN a ELSE RETURN b END
	END Min;

	PROCEDURE Max( a, b: SIGNED16 ): SIGNED16;
	BEGIN
		IF a > b THEN RETURN a ELSE RETURN b END
	END Max;

	PROCEDURE GiveXAxisRect( scale: tLayer;  VAR x, y, w, h: Coordinate;  VAR flip: BOOLEAN;  VAR msg: Objects.ObjMsg );
	VAR X, Y, W, H, temp: Coordinate;
	BEGIN
		vyPort.GetPictureScreenRegion( msg.dlink( vyPort.Picture ), X, Y, W, H );  x := X + xLeftMargin;  y := Y + scale.dy;
		w := W - (xLeftMargin + xRigthMargin);  h := xHeigth;
		IF (y - Y + h) > (H DIV 2) THEN flip := TRUE ELSE flip := FALSE END;
		IF (y - Y + h) > (3 * H DIV 5) THEN scale.yregion := top;
		ELSIF (y - Y + h) > (2 * H DIV 5) THEN scale.yregion := middle;
		ELSE scale.yregion := bottom;
		END;
		IF scale.xregion = right THEN x := X + xRigthMargin;  w := (xLeftMargin + scale.dx - xRigthMargin);
		ELSIF scale.xregion = middle THEN x := X + xRigthMargin;  w := W - 2 * xRigthMargin
		ELSE x := X + scale.dx + xLeftMargin;  w := W - (scale.dx + xLeftMargin + xRigthMargin)
		END;
		IF scale.ToReal THEN
			vyGraphBase.Point2dToPoint( scale.trx, scale.try, temp, y );  DEC( y, h );
			IF (y - Y + h) > (H DIV 2) THEN flip := TRUE ELSE flip := FALSE;  END;
		END;

	END GiveXAxisRect;

	PROCEDURE GiveYAxisRect( scale: tLayer;  VAR x, y, w, h: Coordinate;  VAR flip: BOOLEAN;  VAR msg: Objects.ObjMsg );
	VAR X, Y, W, H, temp: Coordinate;
	BEGIN
		vyPort.GetPictureScreenRegion( msg.dlink( vyPort.Picture ), X, Y, W, H );  x := X + scale.dx;  y := Y + yBotMargin;
		w := yWidth;  h := H - (yTopMargin + yBotMargin);
		IF (x - X + w) > (W DIV 2) THEN flip := TRUE ELSE flip := FALSE;  END;
		IF (x - X + w) <= (2 * W DIV 5) THEN scale.xregion := left
		ELSIF (x - X + w) <= (3 * W DIV 5) THEN scale.xregion := middle
		ELSE scale.xregion := right
		END;
		IF scale.yregion = top THEN y := Y + yTopMargin;  h := (yBotMargin + scale.dy - yTopMargin);
		ELSIF scale.yregion = middle THEN y := Y + yTopMargin;  h := H - 2 * yTopMargin;
		ELSE y := Y + scale.dy + yBotMargin;  h := H - (scale.dy + yBotMargin + yTopMargin);
		END;
		IF scale.ToReal THEN
			vyGraphBase.Point2dToPoint( scale.trx, scale.try, x, temp );  DEC( x, w );
			IF (x - X + w) > (W DIV 2) THEN flip := TRUE ELSE flip := FALSE;  END;
		END;
	END GiveYAxisRect;

	PROCEDURE PointInXAxis( scale: tLayer;  X, Y: Coordinate;  VAR msg: Objects.ObjMsg ): BOOLEAN;
	VAR x, y, w, h: Coordinate;  flip: BOOLEAN;
	BEGIN
		GiveXAxisRect( scale, x, y, w, h, flip, msg );
		IF flip THEN y := y + h;  END;
		RETURN vyRectangles.PointInRect( X, Y, x, y, w, h );
	END PointInXAxis;

	PROCEDURE PointInYAxis( scale: tLayer;  X, Y: Coordinate;  VAR msg: Objects.ObjMsg ): BOOLEAN;
	VAR x, y, w, h: Coordinate;  flip: BOOLEAN;
	BEGIN
		GiveYAxisRect( scale, x, y, w, h, flip, msg );
		IF flip THEN x := x + w;  END;
		RETURN vyRectangles.PointInRect( X, Y, x, y, w, h );
	END PointInYAxis;

	PROCEDURE Recall( scale: tLayer;  VAR msg: Display.DisplayMsg );
	VAR x, y, w, h: Coordinate;  x2d1, x2d2, y2d1, y2d2, d: Real;  flip: BOOLEAN;
	BEGIN
		vyAxis.SetColors( scale.style.fcol, scale.style.fcol, scale.style.fcol );  vyAxis.PlotLabels( TRUE );
		vyAxis.SetLabelFont( scale.style.fnt );  vyAxis.FlipAxesOrientation( FALSE );  vyAxis.AutomaticTicks( TRUE );

		GiveXAxisRect( scale, x, y, w, h, flip, msg );  vyAxis.FlipAxesOrientation( flip );
		IF (w > 0) & (h > 0) THEN
			vyGraphBase.PointToPoint2d( x, y, x2d1, d );  vyGraphBase.PointToPoint2d( x + w, y, x2d2, d );
			vyAxis.SetDigitsAfterPoint( scale.hdigits );
			IF scale.haxe = NIL THEN
				NEW( scale.haxe );  vyAxis.Prepare( scale.haxe, x, y + h, x + w, y + h, x2d1, x2d2, (x2d2 - x2d1) / 2 );  scale.ow := w;
			ELSE
				IF (scale.ow = w) & (scale.hr = x2d2 - x2d1) THEN
					vyAxis.AxeTo( scale.haxe, x, y + h );  vyAxis.RealTo( scale.haxe, x2d1 );
				ELSE
					NEW( scale.haxe );  vyAxis.Prepare( scale.haxe, x, y + h, x + w, y + h, x2d1, x2d2, (x2d2 - x2d1) / 2 );
					scale.ow := w;
				END;
			END;
			vyAxis.Plot( scale.haxe );  scale.hr := x2d2 - x2d1;
		END;

		GiveYAxisRect( scale, x, y, w, h, flip, msg );  vyAxis.FlipAxesOrientation( flip );
		IF (w > 0) & (h > 0) THEN
			vyGraphBase.PointToPoint2d( x, y, d, y2d1 );  vyGraphBase.PointToPoint2d( x, y + h, d, y2d2 );
			vyAxis.SetDigitsAfterPoint( scale.vdigits );
			IF scale.vaxe = NIL THEN
				NEW( scale.vaxe );  vyAxis.Prepare( scale.vaxe, x + w, y, x + w, y + h, y2d1, y2d2, (y2d2 - y2d1) / 2 );  scale.oh := h;
			ELSE
				IF (scale.oh = h) & (scale.vr = y2d2 - y2d1) THEN
					vyAxis.AxeTo( scale.vaxe, x + w, y );  vyAxis.RealTo( scale.vaxe, y2d1 );
				ELSE
					NEW( scale.vaxe );  vyAxis.Prepare( scale.vaxe, x + w, y, x + w, y + h, y2d1, y2d2, (y2d2 - y2d1) / 2 );
					scale.oh := h;
				END;
			END;
			vyAxis.Plot( scale.vaxe );  scale.vr := y2d2 - y2d1;
		END
	END Recall;

	PROCEDURE DoControl( scale: tLayer;  VAR event: vyEvents.EventMsg );
	VAR pict: vyPort.Picture;  x, y: Coordinate;  olddx, olddy: Coordinate;
	BEGIN
		x := event.x;  y := event.y;  pict := event.dlink( vyPort.Picture );  olddx := scale.dx;  olddy := scale.dy;
		WHILE event.gesture = vyEvents.EvtIdent DO
			vyEvents.GetEvent( event );   (* END;*)
			scale.dx := olddx + event.x - x;  scale.dy := olddy + event.y - y;  vyPort.PictureUpdate( pict )
		END;
	END DoControl;

	PROCEDURE DoControl2( scale: tLayer;  VAR event: vyEvents.EventMsg );
	VAR pict: vyPort.Picture;  x, y: Coordinate;  olddx, olddy: Coordinate;
	BEGIN
		x := event.x;  y := event.y;  pict := event.dlink( vyPort.Picture );  olddx := scale.dx;  olddy := scale.dy;
		WHILE event.gesture = vyEvents.EvtSelect DO vyEvents.GetEvent( event );  END;
		IF (x # event.x) THEN
			IF x - event.x > 0 THEN
				(*reduce digits*)
				IF PointInYAxis( scale, x, y, event ) THEN scale.vdigits := Max( 0, scale.vdigits - 1 );
				ELSE scale.hdigits := Max( 0, scale.hdigits - 1 );
				END;
			ELSE
				(* increase digits*)
				IF PointInYAxis( scale, x, y, event ) THEN scale.vdigits := Min( 8, scale.vdigits + 1 );
				ELSE scale.hdigits := Min( 8, scale.hdigits + 1 );
				END;
			END;
			scale.haxe := NIL;  scale.vaxe := NIL;  vyPort.PictureUpdate( pict )
		END;
	END DoControl2;

	PROCEDURE Responsible( scale: tLayer;  VAR event: vyEvents.EventMsg );
	VAR priority: SIGNED16;
	BEGIN
		priority := vyEvents.PrioNone;
		IF ((event.gesture = vyEvents.EvtIdent) OR (event.gesture = vyEvents.EvtSelect)) &
		    (PointInXAxis( scale, event.x, event.y, event ) OR PointInYAxis( scale, event.x, event.y, event )) THEN
			priority := vyEvents.PrioNormal;
			IF event.priority < priority THEN event.responder := scale;  event.priority := priority END;
		END;
	END Responsible;

	PROCEDURE Store0( o: tLayer;  VAR M: Objects.FileMsg );
	BEGIN
		Files.WriteInt( M.R, o.hdigits );  Files.WriteInt( M.R, o.vdigits );  vyAxis.StoreAxe( M.R, o.haxe );
		vyAxis.StoreAxe( M.R, o.vaxe );  Files.WriteInt( M.R, o.ow );  Files.WriteInt( M.R, o.oh );  Files.WriteLReal( M.R, o.hr );
		Files.WriteLReal( M.R, o.vr );  Files.WriteInt( M.R, o.dx );  Files.WriteInt( M.R, o.dy );  Files.WriteInt( M.R, o.xregion );
		Files.WriteInt( M.R, o.yregion );  Files.WriteBool( M.R, o.ToReal );  Files.WriteReal( M.R, o.trx );
		Files.WriteReal( M.R, o.try );
	END Store0;

	PROCEDURE Load0( o: tLayer;  VAR M: Objects.FileMsg );
	BEGIN
		Files.ReadInt( M.R, o.hdigits );  Files.ReadInt( M.R, o.vdigits );  vyAxis.LoadAxe( M.R, o.haxe );
		vyAxis.LoadAxe( M.R, o.vaxe );  Files.ReadInt( M.R, o.ow );  Files.ReadInt( M.R, o.oh );  Files.ReadLReal( M.R, o.hr );
		Files.ReadLReal( M.R, o.vr );  Files.ReadInt( M.R, o.dx );  Files.ReadInt( M.R, o.dy );  Files.ReadInt( M.R, o.xregion );
		Files.ReadInt( M.R, o.yregion );  Files.ReadBool( M.R, o.ToReal );  Files.ReadReal( M.R, o.trx );
		Files.ReadReal( M.R, o.try );
	END Load0;

	PROCEDURE Copy*( VAR M: Objects.CopyMsg;  src, dest: tLayer );
	BEGIN
		dest^ := src^;  vyPort.LayerCopy( M, src, dest );
		(* (* never deepcopy data in a layer ! *)
	IF M.id = Objects.deep THEN
	ELSE
	END;
	*)
	END Copy;

	PROCEDURE Alloc*;
	BEGIN
		NEW( newlayer );  newlayer.handle := Handler;  Objects.NewObj := newlayer;
	END Alloc;

	PROCEDURE Handler*( o: Objects.Object;  VAR M: Objects.ObjMsg );
	VAR copy: tLayer;  uhandle: Objects.Handler;  gen: PROCEDURE;

	CONST GenProc = "vyScale.Alloc";   (* Gen Procedure as String *)
	BEGIN
		uhandle := vyPort.LayerHandler;   (* handler of root object*)
		gen := Alloc;   (* gen Procedure as PROCEDURE *)

		WITH o: tLayer DO
			IF M IS Display.DisplayMsg THEN
				WITH M: Display.DisplayMsg DO
					uhandle( o, M );  Recall( o, M ) (* call root handle first if in background *)
				END;
			ELSIF M IS vyEvents.EventMsg THEN
				WITH M: vyEvents.EventMsg DO
					IF M.callForResponder THEN
						Responsible( o, M );  uhandle( o, M );   (* if not responsible: maybe root is *)
					ELSE
						IF M.gesture = vyEvents.EvtIdent THEN DoControl( o, M )
						ELSIF M.gesture = vyEvents.EvtSelect THEN DoControl2( o, M )
						ELSE
							uhandle( o, M );   (* that M belongs to root *)
						END
					END;
				END;
			ELSIF M IS Objects.CopyMsg THEN
				WITH M: Objects.CopyMsg DO
					IF M.stamp = o.stamp THEN
						M.obj := o.dlink (* copy M arrives again *)
					ELSE
						gen;  copy := Objects.NewObj( tLayer );  M.obj := copy;   (* Generator  *)
						Copy( M, o, M.obj( tLayer ) );   (* do not call uhanlde, may result in new object of type "root" *)
					END;
				END;
			ELSIF M IS Objects.FileMsg THEN
				WITH M: Objects.FileMsg DO
					uhandle( o, M );
					IF M.id = Objects.load THEN Load0( o, M );
					ELSIF M.id = Objects.store THEN Store0( o, M );
					END;
				END;
			ELSIF M IS Objects.AttrMsg THEN
				WITH M: Objects.AttrMsg DO
					IF M.id = Objects.get THEN
						IF M.name = "Gen" THEN COPY( GenProc, M.s );  M.class := Objects.String;  M.res := 0 ELSE uhandle( o, M ) END
					ELSIF M.id = Objects.enum THEN uhandle( o, M );
					ELSE uhandle( o, M )
					END
				END;
			ELSIF M IS Objects.BindMsg THEN
				WITH M: Objects.BindMsg DO
					uhandle( o, M );
					(* add own binds here: Bind(o.entry,M) *)
				END;
			ELSE uhandle( o, M )
			END
		END
	END Handler;

	PROCEDURE Open*( scale: tLayer;  id: ARRAY OF CHAR );
	BEGIN
		vyPort.OpenLayer( scale, id );  scale.style.fnt := LabelFont;  scale.handle := Handler;  scale.hdigits := 2;
		scale.vdigits := 2;  scale.dx := 0;  scale.dy := 0;  scale.xregion := left;  scale.yregion := bottom;  scale.ToReal := FALSE;
		scale.trx := 0;  scale.try := 0;
	END Open;

	PROCEDURE New*;
	BEGIN
		NEW( newlayer );  Open( newlayer, "scale" );  Objects.NewObj := newlayer;
	END New;

	PROCEDURE Insert*;
	VAR pict: vyPort.Picture;  sc: vyParser.Scanner;  x, y: FLOAT32;
	BEGIN
		vyParser.OpenParScanner( sc );  pict := vyPort.GetFocusPicture();
		(*! teste auf 2d Koordinaten *)
		IF pict # NIL THEN
			NEW( newlayer );  Open( newlayer, "scale" );  vyPort.AddLayer( pict, newlayer );
			IF vyParser.Real( sc, x ) & vyParser.Real( sc, y ) THEN newlayer.ToReal := TRUE;  newlayer.trx := x;  newlayer.try := y END;
			vyPort.PictureUpdate( pict );
		END;
	END Insert;

	PROCEDURE InsertX*;
	VAR pict: vyPort.Picture;
	BEGIN
		pict := vyPort.GetFocusPicture();
		(*! teste auf 2d Koordinaten *)
		IF pict # NIL THEN NEW( newlayer );  Open( newlayer, "scale" );  vyPort.AddLayer( pict, newlayer );  vyPort.PictureUpdate( pict );  END;

	END InsertX;

END vyScale.