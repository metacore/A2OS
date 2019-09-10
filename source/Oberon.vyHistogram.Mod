MODULE vyHistogram IN Oberon;
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
(c) G. Sawitzki, StatLab Heidelberg
(c) M. Diller, StatLab Heidelberg
*)
(*= 	Contents	histogram plot *)
(*	history:
5.12.00 jb						unmapped memory trap when loading fixed
23.1.95 md 0.0d15		bins, nrBins, maxBinHeight and offSet added
InstallBins impl.
maxBins added
PointInOffSet, PointInDx added
Trim impl.
27.10.94 md 0.0d14	adaped to the renamed vyHostDisplay & vyPictures *)

(*! maxBins should restrict the histogram only in that region, the used has zoomed in*)

IMPORT Files, Gadgets, Objects, Display, vyHostTexts, vyBase, vyGraphBase, vyBooleanVec, vyTypes, vyLinks, vyName,
	vyHostDisplay := vyGraphBase, vyDisplay2d, vyPatterns, vyPort, vyHighlight, vyHostStrings, vyParser, vyEvents;

CONST
	idversion* = "vyHistogram v0r0a4";  toleranz = 5 * vyHostDisplay.pixel;  maxBins* = 256;  cBottom = 0;

TYPE
	Real = vyBase.Real;  Coordinate = vyGraphBase.Coordinate;
	(* histogram model *)
	(*	tHistogram*= POINTER TO tHistogramDesc;
	tHistogramDesc*= RECORD
	(* histogram definition *)
	offs,width,top: FLOAT64; (* offs<=x<top *)
	bincount: ARRAY maxBins OF SIGNED32; (* top:= offs+bincount*width *) (* bin:= ENTIER (x-offs/width) *)
	toosmall,toolarge,nans:SIGNED32 (* special counters *)

	END;
	*)
	tLayer* = POINTER TO tLayerDesc;
	tLayerDesc* = RECORD (vyPort.tLayerDesc)
		bins-: ARRAY maxBins+4096  OF SIGNED32;  (* patch fof 0711 *)
		selectBins-: ARRAY maxBins+4096  OF SIGNED32;  (* patch fof 0711 *)
		nrBins-: SIGNED16;
		maxBinHeight: SIGNED32;
		leftBound-, rightBound-, offset-: Real;   (* preset left border  , right border ,offset for bins*)
		leftHist-, rightHist-, width-: Real;   (* used left and right border *)
		adapting: BOOLEAN;   (* change left,right,width adaptive to new dataset,
		for the moment this is a restriction on user interaction ONLY *)
		respectBounds-: BOOLEAN;   (* if respectbounds then uleft = left, uright=right else use limits of dataset *)
		toosmall-, toolarge-, nans-: SIGNED32
	END;

VAR
	gTop: Real;  slink*, dlink*: Objects.Object;  newlayer*: tLayer;

	PROCEDURE InEps( x, y: Real ): BOOLEAN;
	CONST epsilon = 1 / MAX( Real );
	BEGIN
		IF ABS( x - y ) < epsilon THEN RETURN TRUE ELSE RETURN FALSE END
	END InEps;

	PROCEDURE Vizor( x0, y0, x1, y1: Coordinate );
	VAR x: Coordinate;
	BEGIN
		vyGraphBase.Point2dToPoint( 0, cBottom, x, y0 );  vyGraphBase.Point2dToPoint( 0, gTop, x, y1 );
		vyHostDisplay.FrameRect( x0, y0 - 2, x1 - x0, y1 - y0 + 4 )
	END Vizor;

	PROCEDURE SelectionActor( layer: vyPort.tLayer;  sel: vyBase.tVector;  x0O, y0O, x1O, y1O, x0N, y0N, x1N, y1N: Real;
												VAR somethingChanged: BOOLEAN );
	(*vs 0.0a1	md  16.08.94 *)
	VAR histogram: tLayer;  r: Real;  nrData, i: SIGNED32;  new: BOOLEAN;
	BEGIN
		histogram := layer( tLayer );  nrData := histogram.x.nrData;
		FOR i := 0 TO nrData - 1 DO
			r := vyTypes.VGetR( histogram.x, i );
			new :=
				(x0N <= r) & (r <= x1N) & ~((x0O <= r) & (r <= x1O)) OR ~((x0N <= r) & (r <= x1N)) & (x0O <= r) & (r <= x1O);
			vyBooleanVec.Set( new, sel, i );  somethingChanged := somethingChanged OR new
		END
	END SelectionActor;

	PROCEDURE InstallBins( hist: tLayer );
	VAR dataRec, sel: vyBase.tVector;  i: SIGNED32;  bin: SIGNED16;  r, x0, dx: Real;  max, min, maxh, minh: Real;  nans: SIGNED32;
	BEGIN
		IF hist.x # NIL THEN
			dataRec := hist.x;  vyTypes.VGetMinMax( dataRec, min, max, nans );  hist.nans := nans;

			IF hist.respectBounds THEN minh := hist.leftBound;  maxh := hist.rightBound
			ELSE minh := min;  maxh := max;  hist.leftBound := min;  hist.rightBound := max
			END;
			(*
			IF (maxh - minh) / hist.width > maxBins - 1 THEN vyHostTexts.Msg( "Histogram intervals too small!!" );  hist.width := (maxh - minh) / (maxBins - 1)
			END;
			*)
			(* width adjusted *)

			dx := hist.width;
			(*	IF minh < hist.offset THEN *)
			x0 := hist.offset - SHORT( ENTIER( (hist.offset - minh) / dx + 1 ) ) * dx
			(*	ELSE x0 := hist.offset END;*) ;
			IF InEps( x0 + dx, minh ) THEN x0 := minh END;
			hist.leftHist := x0;  hist.rightHist := hist.offset + SHORT( ENTIER( (maxh - hist.offset) / dx + 1 ) ) * dx;
			IF InEps( hist.rightHist - dx, maxh ) THEN hist.rightHist := maxh END;
			(* used left border adjusted *)
			hist.nrBins := SHORT( ENTIER( (hist.rightHist - hist.leftHist) / dx ) );
			(* nrBins adjusted *)  (* nrBins  invariant w/r to data if border respect is turned "on" *)
			(*hist.rightHist := hist.leftHist + hist.nrBins * hist.width; *)
			(* used right border adjusted (needed ?) *)

			FOR i := 0 TO maxBins - 1 DO hist.bins[i] := 0 END;
			hist.toosmall := 0;  hist.toolarge := 0;
			FOR i := 0 TO dataRec.nrData - 1 DO
				r := vyTypes.VGetR( dataRec, i );
				IF r < minh THEN INC( hist.toosmall )
				ELSIF r > maxh THEN INC( hist.toolarge )
				ELSE
					bin := SHORT( ENTIER( (r - x0) / dx ) );
					IF bin > 0 THEN INC( hist.bins[bin] ) ELSE INC( hist.bins[0] ) END
				END
			END;

			hist.maxBinHeight := 0;
			FOR i := 0 TO hist.nrBins - 1 DO
				IF hist.maxBinHeight < hist.bins[i] THEN hist.maxBinHeight := hist.bins[i] END
			END;
			(*	IF hist.highlight=NIL THEN
		vyHighlight.AdjustHighlight(hist)
		END;
		*)
			hist.highlight := NIL;  vyHighlight.AdjustHighlight( hist );  sel := vyHighlight.GetSelectionAttribute( hist.highlight );

			FOR i := 0 TO maxBins - 1 DO hist.selectBins[i] := 0 END;
			FOR i := 0 TO dataRec.nrData - 1 DO
				IF sel.nrData > i THEN  (* hack against invalid access , fof 020213 *)
					IF vyBooleanVec.Get( sel, i ) THEN
						r := vyTypes.VGetR( dataRec, i );
						IF r < minh THEN  (*! save ?? *)
						ELSIF r > maxh THEN  (*! save ?? *)
						ELSE
							bin := SHORT( ENTIER( (r - x0) / dx ) );
							IF bin > 0 THEN INC( hist.selectBins[bin] ) ELSE INC( hist.selectBins[0] ) END
						END
					END
				END
			END
		END
	END InstallBins;

	PROCEDURE Recall( hist: tLayer );
	VAR i, x, y, w, h: Coordinate;  x0, dx: Real;  mark: vyHostDisplay.tSign;
		nums: ARRAY 32 OF CHAR;
	BEGIN
		IF hist.x # NIL THEN dx := hist.width;  x0 := hist.leftHist;

			vyHostDisplay.SetDisplayMode( vyHostDisplay.replace );
			FOR i := 0 TO hist.nrBins - 1 DO
			(*data *)
				vyGraphBase.Rect2dToRect( x0 + i * dx, 0, dx, hist.bins[i], x, y, w, h );
				vyHostDisplay.SetForeColor( hist.style.fillcol );  vyHostDisplay.SetDisplayPattern( hist.style.fillpat );
				vyHostDisplay.PaintRect( x, y, w, h );
				(* selection *)
				vyGraphBase.Rect2dToRect( x0 + i * dx, 0, dx, hist.selectBins[i], x, y, w, h );
				vyHostDisplay.SetForeColor( hist.style.selectcol );  vyHostDisplay.SetDisplayPattern( hist.style.selectpat );
				vyHostDisplay.PaintRect( x, y, w, h );
				(* frame *)
				vyGraphBase.Rect2dToRect( x0 + i * dx, 0, dx, hist.bins[i], x, y, w, h );
				(*! computed twice; optimize *)
				vyHostDisplay.SetForeColor( hist.style.fcol );  vyHostDisplay.SetDisplayPattern( hist.style.pattern );
				vyHostDisplay.FrameRect( x, y, w, h )
			END;

			vyHostDisplay.SetForeColor( vyHostDisplay.black );  mark := vyPatterns.rhombus.sgn1;
			vyHostDisplay.SetPatternJustification( vyHostDisplay.center, vyHostDisplay.top );
			vyGraphBase.PaintPat2d( hist.offset, 0, mark );  vyGraphBase.PaintPat2d( hist.offset + hist.width, 0, mark );
			IF hist.respectBounds THEN
				vyHostDisplay.SetForeColor( vyHostDisplay.red );  mark := vyPatterns.vLine.sgn1;
				vyGraphBase.PaintPat2d( hist.leftBound, 0, mark );  vyGraphBase.PaintPat2d( hist.rightBound, 0, mark );
				IF hist.toosmall > 0 THEN
					vyHostDisplay.SetStringJustification( vyHostDisplay.right, vyHostDisplay.bottom );  nums := "#< : ";
					vyHostStrings.AppendInt( hist.toosmall, 0, nums );  vyGraphBase.String2d( hist.leftHist, 0, "", nums )
				END;
				IF hist.toolarge > 0 THEN
					vyHostDisplay.SetStringJustification( vyHostDisplay.left, vyHostDisplay.bottom );  nums := "#> : ";
					vyHostStrings.AppendInt( hist.toolarge, 0, nums );  vyGraphBase.String2d( hist.rightHist, 0, "", nums )
				END
			END
		END
	END Recall;

	PROCEDURE Copy( source, dest: tLayer );   (* FOF inserted *)
	BEGIN
		dest^ := source^
	END Copy;

	PROCEDURE Select( histogram: tLayer;  VAR event: vyEvents.EventMsg );
	VAR selector: vyHighlight.tSelector;
	BEGIN
		vyHighlight.OpenSelector( histogram, histogram.x.nrData, Vizor, SelectionActor, event );
		selector := histogram.highlight( vyHighlight.tSelector );  gTop := histogram.maxBinHeight;
		selector.do( selector, event )
	END Select;

	PROCEDURE PointInOffSet( x, y: Coordinate;  hist: tLayer ): BOOLEAN;
	VAR x0, y0: Coordinate;
	BEGIN
		vyGraphBase.Point2dToPoint( hist.offset, 0, x0, y0 );  y0 := y0 - 2;  RETURN (ABS( x - x0 ) + ABS( y - y0 ) < toleranz)
	END PointInOffSet;

	PROCEDURE PointInDx( x, y: Coordinate;  hist: tLayer ): BOOLEAN;
	VAR x0, y0: Coordinate;
	BEGIN
		vyGraphBase.Point2dToPoint( hist.offset + hist.width, 0, x0, y0 );  y0 := y0 - 2;  RETURN (ABS( x - x0 ) + ABS( y - y0 ) < toleranz)
	END PointInDx;

	PROCEDURE PointInLeft( x, y: Coordinate;  hist: tLayer ): BOOLEAN;
	VAR x0, y0: Coordinate;
	BEGIN
		IF ~hist.respectBounds THEN RETURN FALSE END;
		vyGraphBase.Point2dToPoint( hist.leftBound, 0, x0, y0 );  y0 := y0 - 2;  RETURN (ABS( x - x0 ) + ABS( y - y0 ) < toleranz)
	END PointInLeft;

	PROCEDURE PointInRight( x, y: Coordinate;  hist: tLayer ): BOOLEAN;
	VAR x0, y0: Coordinate;
	BEGIN
		IF ~hist.respectBounds THEN RETURN FALSE END;
		vyGraphBase.Point2dToPoint( hist.rightBound, 0, x0, y0 );  y0 := y0 - 2;  RETURN (ABS( x - x0 ) + ABS( y - y0 ) < toleranz)
	END PointInRight;

	PROCEDURE PointInHistogram( x, y: Coordinate;  hist: tLayer ): BOOLEAN;
	VAR x0, y0: Real;  min, max: Real;  nans: SIGNED32;

		PROCEDURE PointInRect( X, Y, X0, Y0, X1, Y1: Real ): BOOLEAN;
		BEGIN
			RETURN (X0 <= X) & (X <= X1) & (Y0 <= Y) & (Y <= Y1)
		END PointInRect;

	BEGIN
		vyGraphBase.PointToPoint2d( x, y, x0, y0 );  vyTypes.VGetMinMax( hist.x, min, max, nans );
		RETURN PointInRect( x0, y0, hist.leftHist, 0, hist.rightHist, hist.maxBinHeight )
	END PointInHistogram;

	PROCEDURE Respond( hist: tLayer;  VAR event: vyEvents.EventMsg );
	(*vs 0.0a1 *)  (* md  29.05.95 *)
	VAR x, y: Coordinate;  x2d, y2d: Real;  pict: vyPort.Picture;  this: SIGNED16;
	BEGIN
		this := event.gesture;
		IF (this # vyEvents.EvtLoc) & (this # vyEvents.EvtIdent) THEN RETURN END;
		pict := event.dlink( vyPort.Picture );
		IF hist.adapting = FALSE THEN RETURN END;
		IF PointInDx( event.x, event.y, hist ) THEN
			x := event.x;  y := event.y;
			WHILE event.gesture = this DO
				IF event.x # x THEN
					vyGraphBase.PointToPoint2d( event.x, y, x2d, y2d );
					IF (x2d > hist.offset) & ((hist.width * hist.nrBins) / (x2d - hist.offset) < maxBins) THEN
						hist.width := x2d - hist.offset;  InstallBins( hist );  vyPort.PictureUpdate( pict )
					ELSE vyHostTexts.Msg( "Histogram intervals too small!!" );  RETURN
					END;
					x := event.x;
				END;
				vyEvents.GetEvent( event )
			END;
		ELSIF PointInOffSet( event.x, event.y, hist ) THEN
			x := event.x;  y := event.y;
			WHILE event.gesture = this DO
				IF event.x # x THEN
					vyGraphBase.PointToPoint2d( event.x, y, x2d, y2d );  hist.offset := x2d;  InstallBins( hist );
					vyPort.PictureUpdate( pict );  x := event.x;
				END;
				vyEvents.GetEvent( event )
			END;
		ELSIF PointInLeft( event.x, event.y, hist ) THEN
			x := event.x;  y := event.y;
			WHILE event.gesture = this DO
				IF event.x # x THEN
					vyGraphBase.PointToPoint2d( event.x, y, x2d, y2d );  hist.leftBound := x2d;  InstallBins( hist );
					vyPort.PictureUpdate( pict );  x := event.x;
				END;
				vyEvents.GetEvent( event )
			END;
		ELSIF PointInRight( event.x, event.y, hist ) THEN
			x := event.x;  y := event.y;
			WHILE event.gesture = this DO
				IF event.x # x THEN
					vyGraphBase.PointToPoint2d( event.x, y, x2d, y2d );  hist.rightBound := x2d;  InstallBins( hist );
					vyPort.PictureUpdate( pict );  x := event.x;
				END;
				vyEvents.GetEvent( event )
			END;
		END;
	END Respond;

	PROCEDURE Responsible( histogram: tLayer;  VAR event: vyEvents.EventMsg );
	VAR priority: SIGNED16;
	BEGIN
		priority := vyEvents.PrioNone;
		IF (event.gesture = vyEvents.EvtIdent) OR (event.gesture = vyEvents.EvtLoc) THEN
			IF (PointInOffSet( event.x, event.y, histogram ) OR PointInDx( event.x, event.y, histogram ) OR
				 PointInLeft( event.x, event.y, histogram ) OR PointInRight( event.x, event.y, histogram )) THEN
				priority := vyEvents.PrioHigh
			END;
		ELSIF (event.gesture = vyEvents.EvtSelect) THEN
			IF PointInHistogram( event.x, event.y, histogram ) THEN priority := vyEvents.PrioNormal END;
		END;
		IF event.priority < priority THEN event.responder := histogram;  event.priority := priority END;
	END Responsible;

	PROCEDURE Consume( o: tLayer;  msg: Display.ConsumeMsg );
	VAR v: vyBase.tVector;  minX, maxX: Real;  pict: vyPort.Picture;  nans: SIGNED32;
	BEGIN
		pict := msg.dlink( vyPort.Picture );  v := vyBase.GetVFromObj( msg.obj );
		IF v # NIL THEN vyBase.UnSubscribe( o.x, o );

			Init( o, msg.obj );  vyTypes.VGetMinMax( o.x, minX, maxX, nans );
			vyPort.SetNewC2d( pict, minX - o.width, 0, maxX - minX + 2 * o.width, o.x.nrData / 3 );  vyBase.Update( v );
		END;
	END Consume;

	PROCEDURE HandleAttributes( obj: tLayer;  VAR M: Objects.AttrMsg );
	BEGIN
		IF M.id = Objects.get THEN
			IF M.name = "Gen" THEN
				COPY( 'vyHistogram.New', M.s );  M.class := Objects.String;  M.res := 0
				(*ELSIF M.name = "bins" THEN
			M.class :=
			M.
			M.res := 0
			ELSIF M.name = "selectBins" THEN
			M.class :=
			M.b :=
			M.res := 0*)
			ELSIF M.name = "nrBins" THEN M.class := Objects.Int;  M.i := obj.nrBins;  M.res := 0
			ELSIF M.name = "leftBound" THEN M.class := Objects.LongReal;  M.y := obj.leftBound;  M.res := 0
			ELSIF M.name = "rightBound" THEN M.class := Objects.LongReal;  M.y := obj.rightBound;  M.res := 0
			ELSIF M.name = "offset" THEN M.class := Objects.LongReal;  M.y := obj.offset;  M.res := 0
			ELSIF M.name = "leftHist" THEN M.class := Objects.LongReal;  M.y := obj.leftHist;  M.res := 0
			ELSIF M.name = "rightHist" THEN M.class := Objects.LongReal;  M.y := obj.rightHist;  M.res := 0
			ELSIF M.name = "width" THEN M.class := Objects.LongReal;  M.y := obj.width;  M.res := 0
			ELSIF M.name = "respectBounds" THEN M.class := Objects.Bool;  M.b := obj.respectBounds;  M.res := 0
			ELSIF M.name = "toosmall" THEN M.class := Objects.Int;  M.i := obj.toosmall;  M.res := 0
			ELSIF M.name = "toolarge" THEN M.class := Objects.Int;  M.i := obj.toolarge;  M.res := 0
			ELSIF M.name = "nans" THEN M.class := Objects.Int;  M.i := obj.nans;  M.res := 0
			ELSE vyPort.LayerHandler( obj, M )
			END
		ELSIF M.id = Objects.enum THEN
			vyPort.LayerHandler( obj, M );  M.Enum( "bins" );  M.Enum( "selectBins" );  M.Enum( "nrBins" );  M.Enum( "leftBound" );  M.Enum( "rightBound" );  M.Enum( "offset" );
			M.Enum( "leftHist" );  M.Enum( "rightHist" );  M.Enum( "width" );  M.Enum( "respectBounds" );  M.Enum( "toosmall" );  M.Enum( "toolarge" );  M.Enum( "nans" );
		ELSE vyPort.LayerHandler( obj, M )
		END
	END HandleAttributes;

	PROCEDURE AdjustCoord( pict: vyPort.Picture;  obj: tLayer );
	VAR minX, maxX: FLOAT32;  nans: SIGNED32;
	BEGIN
		IF pict # NIL THEN
			IF obj.x # NIL THEN
				vyTypes.VGetMinMaxR( obj.x, minX, maxX, nans );  obj.offset := minX;  obj.width := (maxX - minX) / 10;
				obj.leftBound := minX;  obj.rightBound := maxX;  obj.respectBounds := FALSE;  obj.adapting := TRUE;
			ELSE minX := 0;  maxX := 1
			END;
			vyPort.SetC2d( pict, minX - obj.width, 0, maxX - minX + 2 * obj.width, obj.x.nrData / 3 );
			(*vyPort.SetNewC2d ( pict, minX, cMin, maxX - minX, cMax - cMin)*)
		END;
	END AdjustCoord;

	PROCEDURE SetModel( pict: vyPort.Picture;  obj: tLayer;  data: Objects.Object );
	VAR id: vyName.tNameArray;
	BEGIN
		IF (obj.x # NIL ) THEN vyBase.UnSubscribe( obj.x, obj );  obj.x := NIL END;
		IF data = NIL THEN RETURN END;
		obj.sources := NIL;  obj.x := vyBase.GetVFromObj( data );
		IF (obj.x = NIL ) THEN vyHostTexts.Note( vyHostTexts.cWarning, "vyHistogram.SetModel: can't show these data as a scatter1" )
		ELSE
			COPY( "histogram: ", id );  vyName.AppendObjId( data( vyBase.Object ), id );  vyName.RegisterNamed( obj, id );
			(*	vyBase.Subscribe((*for messages from source*) vyHighlight.GetSelectionAttribute (obj.x.nrData), obj);
		vyBase.Subscribe((*for messages from source*) vyHighlight.GetColorAttribute (obj.x.nrData), obj);*)
			vyBase.Subscribe( (*for messages from source*) obj.x, obj );  AdjustCoord( pict, obj );  vyBase.Update( data )
		END;
	END SetModel;

	PROCEDURE HandleLinks( obj: tLayer;  VAR msg: Objects.LinkMsg );
	(*! handle subscribe/unsubscribe. Move to vyPort *)
	VAR pict: vyPort.Picture;
	BEGIN
		IF (msg.id = Objects.enum) THEN msg.Enum( "x" );  vyPort.LayerHandler( obj, msg )
		ELSIF (msg.id = Objects.get) & (msg.name = "x") THEN msg.obj := obj.x;  msg.res := 0
		ELSIF (msg.id = Objects.set) & ((msg.name = "x") OR (msg.name = "Model")) & (msg.obj # NIL ) & (msg.obj IS vyBase.tVector) THEN
			(* check proper type *)
			IF msg.dlink # NIL THEN pict := msg.dlink( vyPort.Picture ) ELSE pict := NIL END;
			SetModel( pict, obj, msg.obj );  msg.res := 0
		ELSE vyPort.LayerHandler( obj, msg )
		END
	END HandleLinks;

	PROCEDURE Store0( obj: tLayer;  VAR M: Objects.FileMsg );
	VAR i: SIGNED16;
	BEGIN
		Gadgets.WriteRef( M.R, obj.lib, obj.x );
		FOR i := 0 TO maxBins - 1 DO Files.WriteLInt( M.R, obj.bins[i] ) END;
		FOR i := 0 TO maxBins - 1 DO Files.WriteLInt( M.R, obj.selectBins[i] ) END;
		Files.WriteInt( M.R, obj.nrBins );
		IF obj.nrBins >= maxBins THEN (* patch, fof 0711 *)
			FOR i := maxBins TO obj.nrBins-1 DO
				Files.WriteLInt( M.R, obj.bins[i] );
				Files.WriteLInt( M.R, obj.selectBins[i] );
			END;
		END;

		Files.WriteLInt( M.R, obj.maxBinHeight );  Files.WriteLReal( M.R, obj.leftBound );
		Files.WriteLReal( M.R, obj.rightBound );  Files.WriteLReal( M.R, obj.offset );  Files.WriteLReal( M.R, obj.leftHist );
		Files.WriteLReal( M.R, obj.rightHist );  Files.WriteLReal( M.R, obj.width );  Files.WriteBool( M.R, obj.adapting );
		Files.WriteBool( M.R, obj.respectBounds );  Files.WriteLInt( M.R, obj.toosmall );  Files.WriteLInt( M.R, obj.toolarge );
		Files.WriteLInt( M.R, obj.nans )
	END Store0;

	PROCEDURE Load0( obj: tLayer;  VAR M: Objects.FileMsg );
	VAR objsub: Objects.Object;  i: SIGNED16;
	BEGIN
		dlink := M.dlink;  Gadgets.ReadRef( M.R, obj.lib, objsub );
		IF (objsub # NIL ) & (objsub IS vyBase.tVector) THEN obj.x := objsub( vyBase.tVector ) END;
		(*NEW(obj.bins, maxBins);*)
		FOR i := 0 TO maxBins - 1 DO Files.ReadLInt( M.R, obj.bins[i] ) END;
		(*NEW(obj.selectBins, maxBins);*)
		FOR i := 0 TO maxBins - 1 DO Files.ReadLInt( M.R, obj.selectBins[i] ) END;
		Files.ReadInt( M.R, obj.nrBins );
		IF obj.nrBins >= maxBins THEN (* patch, fof 0711*)
			FOR i := maxBins TO obj.nrBins-1 DO
				Files.ReadLInt( M.R, obj.bins[i] );
				Files.ReadLInt( M.R, obj.selectBins[i] );
			END;
		END;

		Files.ReadLInt( M.R, obj.maxBinHeight );  Files.ReadLReal( M.R, obj.leftBound );
		Files.ReadLReal( M.R, obj.rightBound );  Files.ReadLReal( M.R, obj.offset );  Files.ReadLReal( M.R, obj.leftHist );
		Files.ReadLReal( M.R, obj.rightHist );  Files.ReadLReal( M.R, obj.width );  Files.ReadBool( M.R, obj.adapting );
		Files.ReadBool( M.R, obj.respectBounds );  Files.ReadLInt( M.R, obj.toosmall );  Files.ReadLInt( M.R, obj.toolarge );
		Files.ReadLInt( M.R, obj.nans )
	END Load0;

	PROCEDURE Handler*( obj: Objects.Object;  VAR msg: Objects.ObjMsg );   (*vs 0.0a1	md  20.07.94 *)
	VAR minX, maxX: FLOAT64;  pict: vyPort.Picture;  nans: SIGNED32;
	BEGIN
		WITH obj: tLayer DO
			IF msg IS Display.DisplayMsg THEN
				WITH msg: Display.DisplayMsg DO InstallBins( obj );  Recall( obj );
				END;
			ELSIF msg IS Objects.CopyMsg THEN
				WITH msg: Objects.CopyMsg DO
				(*New; copy := Objects.NewObj(tLayer); msg.obj := copy;  vyPort.LayerHandler (obj, msg);
			Copy (obj, msg.obj(tLayer));	*)
					New;  msg.obj := newlayer;  vyPort.LayerHandler( obj, msg );  Copy( obj, msg.obj( tLayer ) );
				END;
			ELSIF msg IS vyEvents.EventMsg THEN
				WITH msg: vyEvents.EventMsg DO
					IF msg.callForResponder THEN Responsible( obj, msg ) ELSE
						IF msg.gesture = vyEvents.EvtSelect THEN Select( obj, msg )
						ELSIF (msg.gesture = vyEvents.EvtIdent) OR (msg.gesture = vyEvents.EvtLoc) THEN Respond( obj, msg )
						END
					END;
				END;
			ELSIF msg IS Objects.FileMsg THEN
				WITH msg: Objects.FileMsg DO
					IF msg.id = Objects.load THEN
						Load0( obj, msg );  vyPort.LayerHandler( obj, msg );
						(*! hack *) IF obj.x # NIL THEN
							IF msg.dlink # NIL THEN  (* jb 5.12.00 *)
								pict := msg.dlink( vyPort.Picture );  vyTypes.VGetMinMax( obj.x, minX, maxX, nans );
								vyPort.SetNewC2d( pict, minX, 0, maxX - minX, 1 )
							ELSE  (*vyHostTexts.Note(vyHostTexts.cWarning,"vyHistogram: no host picture  ")*)
							END
						ELSE vyHostTexts.Note( vyHostTexts.cWarning, "vyHistogram: no x obj loaded  " )
						END
					ELSIF msg.id = Objects.store THEN Store0( obj, msg );  vyPort.LayerHandler( obj, msg )
					ELSE vyPort.LayerHandler( obj, msg )
					END;
				END;
			ELSIF msg IS vyPort.AdjustCoordMsg THEN
				WITH msg: vyPort.AdjustCoordMsg DO AdjustCoord( obj.dlink( vyPort.Picture ), obj );

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
					vyPort.LayerHandler( obj, msg );
					IF obj.x # NIL THEN Gadgets.BindObj( obj.x, msg.lib ) END
				END;
			ELSE vyPort.LayerHandler( obj, msg )
			END
		END
	END Handler;

	PROCEDURE Init*( F: tLayer;  data: Objects.Object );
	VAR id: vyName.tNameArray;  min, max: Real;  nans: SIGNED32;
	BEGIN
		F.handle := Handler;  F.x := vyBase.GetVFromObj( data );  COPY( "histogram: ", id );
		IF (F.x = NIL ) & (data # NIL ) THEN vyHostTexts.Note( vyHostTexts.cWarning, "vyHistogram: can't plot this data as a histogram: not the right type!" );  END;
		IF data # NIL THEN vyName.AppendObjId( data( vyBase.Object ), id ) END;
		vyPort.OpenLayer( F, id );
		IF F.x # NIL THEN
			(*vyBase.Subscribe((*for messages from source*) vyHighlight.GetSelectionAttribute (F.x.nrData), F);
		vyBase.Subscribe((*for messages from source*) vyHighlight.GetColorAttribute (F.x.nrData), F);*)
			vyBase.Subscribe( (*for messages from source*) F.x, F )
		END;
		vyTypes.VGetMinMax( F.x, min, max, nans );  F.offset := min;  F.width := (max - min) / 10;  F.leftBound := min;
		F.rightBound := max;  F.respectBounds := FALSE;  F.adapting := TRUE;
	END Init;

	PROCEDURE ShowP*;
	VAR data: Objects.Object;  minX, maxX: Real;  nans: SIGNED32;
	BEGIN
		data := vyBase.NextParObj();
		WHILE data # NIL DO
			(*NEW (F); Init (F, data); *)
			New;  Init( newlayer, data );  vyTypes.VGetMinMax( newlayer.x, minX, maxX, nans );
			(*pict := vyPort.InsertNewCPicture (0, 0, 1, 1, vyDisplay2d.NewC2d ( minX-F.width, 0, maxX-minX+2*F.width, F.x.nrData/3));
		vyPort.AddLayer (pict, F);*)
			vyPort.AddLayer( vyPort.InsertNewVecPicture( newlayer.x, NIL ), newlayer );
			vyPort.SetNewC2d( vyPort.newpicture, minX - newlayer.width, 0, maxX - minX + 2 * newlayer.width,
											 newlayer.x.nrData / 3 );
			data := vyBase.NextParObj();
		END;
		(*Objects.NewObj := pict*)
	END ShowP;

	PROCEDURE ShowL*( list: vyLinks.Link );
	VAR nans: SIGNED32;  minX, maxX: Real;
	BEGIN
		WHILE list # NIL DO
			New;  Init( newlayer, list.obj );  vyTypes.VGetMinMax( newlayer.x, minX, maxX, nans );
			(*pict := vyPort.InsertNewCPicture (0, 0, 1, 1, vyDisplay2d.NewC2d ( minX-F.width, 0, maxX-minX+2*F.width, F.x.nrData/3));
		vyPort.AddLayer (pict, F);*)
			vyPort.AddLayer( vyPort.InsertNewVecPicture( newlayer.x, NIL ), newlayer );
			vyPort.SetNewC2d( vyPort.newpicture, minX - newlayer.width, 0, maxX - minX + 2 * newlayer.width,
											 newlayer.x.nrData / 3 );
			list := list.link;
		END
	END ShowL;

	PROCEDURE ShowO*( obj: Objects.Object );
	VAR nans: SIGNED32;  minX, maxX: Real;
	BEGIN
		New;  Init( newlayer, obj );  vyTypes.VGetMinMax( newlayer.x, minX, maxX, nans );
		(*pict := vyPort.InsertNewCPicture (0, 0, 1, 1, vyDisplay2d.NewC2d ( minX-F.width, 0, maxX-minX+2*F.width, F.x.nrData/3));
	vyPort.AddLayer (pict, F);*)
		vyPort.AddLayer( vyPort.InsertNewVecPicture( newlayer.x, NIL ), newlayer );
		vyPort.SetNewC2d( vyPort.newpicture, minX - newlayer.width, 0, maxX - minX + 2 * newlayer.width,
										 newlayer.x.nrData / 3 );
	END ShowO;


(*PROCEDURE New*;
VAR data:Objects.Object;
BEGIN data:=NIL;
IF Objects.NewObj # NIL THEN data := Objects.NewObj END;
NEW (newlayer); Init (newlayer, data);  Objects.NewObj := newlayer END New;*)

	PROCEDURE New*;   (* Gadgets.Insert vyHistogram.New *)
	BEGIN
		NEW( newlayer );  Init( newlayer, NIL );  Objects.NewObj := newlayer
	END New;

	PROCEDURE NewPict*;   (* Gadgets.Insert vyHistogram.NewPict *)
	VAR pict: vyPort.Picture;
	BEGIN
		New;  pict := vyPort.XNewCPicture( 0, 0, 1, 1, vyDisplay2d.NewC2d( 0, 0, 1, 1 ) );  vyPort.AddLayer( pict, newlayer );
		Objects.NewObj := pict;
	END NewPict;

	PROCEDURE DoSetBounds*( h: tLayer;  left, right: Real );
	BEGIN
		h.leftBound := left;  h.rightBound := right;  h.respectBounds := TRUE;
	END DoSetBounds;

	PROCEDURE TakeBoundsFromData*( h: tLayer );
	BEGIN
		h.respectBounds := FALSE;
	END TakeBoundsFromData;

	PROCEDURE DoSetOffsetWidth*( h: tLayer;  offset, width: Real );
	BEGIN
		h.offset := offset;
		IF width > 0 THEN h.width := width END;
	END DoSetOffsetWidth;

	PROCEDURE DoSet*( h: tLayer;  left, right: Real;  nrCells: SIGNED32 );
	BEGIN
		IF nrCells < maxBins THEN DoSetBounds( h, left, right );  DoSetOffsetWidth( h, left, (right - left) / nrCells );  END;
	END DoSet;

	PROCEDURE SetBounds*;
	VAR sc: vyParser.Scanner;  left, right: FLOAT32;  h: vyPort.tLayer;  hist: tLayer;
	BEGIN
		NEW( sc );  vyParser.OpenParScanner( sc );
		IF vyParser.ExpectReal( sc, left ) & vyParser.ExpectReal( sc, right ) THEN
			h := vyPort.FocusLayer();  hist := h( tLayer );  DoSetBounds( hist, left, right );
			vyPort.PictureUpdate( vyPort.GetFocusPicture() );
		END;
	END SetBounds;

	PROCEDURE SetOffsetWidth*;
	VAR sc: vyParser.Scanner;  offset, width: FLOAT32;  h: vyPort.tLayer;  hist: tLayer;
	BEGIN
		NEW( sc );  vyParser.OpenParScanner( sc );
		IF vyParser.ExpectReal( sc, offset ) & vyParser.ExpectReal( sc, width ) THEN
			h := vyPort.FocusLayer();
			IF ~(h IS tLayer) THEN RETURN END;
			hist := h( tLayer );  DoSetOffsetWidth( hist, offset, width );  vyPort.PictureUpdate( vyPort.GetFocusPicture() );
		END;
	END SetOffsetWidth;

	PROCEDURE SetBoundsAndCells*;
	VAR sc: vyParser.Scanner;  left, right: FLOAT32;  cells: SIGNED32;  h: vyPort.tLayer;  hist: tLayer;
	BEGIN
		NEW( sc );  vyParser.OpenParScanner( sc );
		IF vyParser.ExpectReal( sc, left ) & vyParser.ExpectReal( sc, right ) & vyParser.ExpectNumber( sc, cells ) THEN
			h := vyPort.FocusLayer();  hist := h( tLayer );  DoSet( hist, left, right, cells );
			vyPort.PictureUpdate( vyPort.GetFocusPicture() );
		END;
	END SetBoundsAndCells;

	PROCEDURE BoundsFromData*;
	VAR h: vyPort.tLayer;  hist: tLayer;
	BEGIN
		h := vyPort.FocusLayer();  hist := h( tLayer );  TakeBoundsFromData( hist );
		vyPort.PictureUpdate( vyPort.GetFocusPicture() );
	END BoundsFromData;

END vyHistogram.

System.Free vyHistogram ~
Voyager.Show @ as Histogram ~

Voyager.Random 30 ~
vyHistogram.SetBounds 0.2 0.8 ~
vyHistogram.SetOffsetWidth 0 0.1 ~
vyHistogram.SetBoundsAndCells 0.2
0.8 11~
vyHistogram.BoundsFromData ~

Voyager.Register Voyager.Run Voyager.Stop
Voyager.Random 100 ~

Voyager.Show @ as Histogram ~

vyHistogram.SetBounds 0.2 0.8 ~ (* Histogram views data in [0.2,0.8] only, outliers are counted and viewed left and right from
the histogram *)
now: shift the bounds by dragging them with the middle mouse button (ctrl)
vyHistogram.SetOffsetWidth 0 0.1 ~
(* offset set to 0, width to 0.1 , note that offset will not be automatically shifted in "viewed data area" *)
vyHistogram.SetBoundsAndCells 0 1 10 ~
(* Sets viewed area to [0,1] , offset to 0 and width to (1-0) / 10 *)
vyHistogram.BoundsFromData ~
(* take bounds from data set, take care in case you need a "fixed" histogram, e.g. for chisquare statistics, in this mode
the number of cells is NOT fixed, this is the default mode *)

