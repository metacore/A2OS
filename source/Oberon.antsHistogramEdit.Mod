MODULE antsHistogramEdit IN Oberon;   (** fof  **)
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




IMPORT vyBase, vyLongrealVec, antsObjects, vyPort, Objects, Display, vyGraphBase, vyTypes, vyDisplay2d, vyEvents,
	vyCommandMenus, Files, Gadgets, aM := antsMessages;

CONST
	grabsize = 5;  outergrab = 20;

TYPE
	tObject* = POINTER TO tObjectDesc;
	tObjectDesc* = RECORD (vyBase.ObjDesc)
		x, y: vyBase.tVector;
		x0, y0, w, h: FLOAT64;
	END;

	tView* = POINTER TO tViewDesc;
	tViewDesc* = RECORD (vyPort.tLayerDesc);
		o: tObject;
		commands: vyCommandMenus.List
	END;

	AdaptMsg* = RECORD (Objects.ObjMsg) END;

VAR
	tempLayer: tView;

	PROCEDURE GetPosition*( o: tObject;  x, y, epsx, epsy: FLOAT64 ): SIGNED32;
	VAR i, len: SIGNED32;
	BEGIN
		len := vyLongrealVec.Len( o.x );
		FOR i := 0 TO len - 1 DO
			IF (ABS( x - vyLongrealVec.Get( o.x, i ) ) < epsx) & (ABS( y - vyLongrealVec.Get( o.y, i ) ) < epsy) THEN RETURN i END
		END;
		RETURN -1
	END GetPosition;

	PROCEDURE SetXY*( o: tObject;  x, y: FLOAT64;  pos: SIGNED32 ): BOOLEAN;
	VAR lx, rx, ly, ry, tx, ty: FLOAT64;
	BEGIN
		IF pos = 0 THEN RETURN FALSE END;
		IF pos = vyLongrealVec.Len( o.x ) - 1 THEN RETURN FALSE END;
		lx := vyLongrealVec.Get( o.x, pos - 1 );  rx := vyLongrealVec.Get( o.x, pos + 1 );  tx := vyLongrealVec.Get( o.x, pos );
		ly := vyLongrealVec.Get( o.y, pos - 1 );  ry := vyLongrealVec.Get( o.y, pos + 1 );  ty := vyLongrealVec.Get( o.y, pos );

		IF x < lx THEN x := lx
		ELSIF x > rx THEN x := rx
		END;
		IF y < ly THEN y := ly
		ELSIF y > ry THEN y := ry
		END;
		vyLongrealVec.Set( x, o.x, pos );  vyLongrealVec.Set( y, o.y, pos );
		IF (tx # x) OR (ty # y) THEN RETURN TRUE ELSE RETURN FALSE END

	END SetXY;

	PROCEDURE GetValue*( o: tObject;  x: FLOAT64 ): FLOAT64;
	VAR cur: FLOAT64;  last: FLOAT64;  pos: SIGNED32;  y, yl: FLOAT64;
	BEGIN
		IF x <= o.x0 THEN RETURN o.y0
		ELSIF x >= o.x0 + o.w THEN RETURN o.y0 + o.h
		END;
		pos := 0;  cur := vyLongrealVec.Get( o.x, pos );  last := cur;
		WHILE (cur < x) DO last := cur;  INC( pos );  cur := vyLongrealVec.Get( o.x, pos ) END;
		y := vyLongrealVec.Get( o.y, pos );  yl := vyLongrealVec.Get( o.y, pos - 1 );  RETURN yl + (x - last) / (cur - last) * (y - yl)
	END GetValue;

	PROCEDURE AddPoint*( o: tObject;  x: FLOAT64 ): BOOLEAN;
	VAR x0, cval: FLOAT64;  pos, len, cur: SIGNED32;  y: FLOAT64;
	BEGIN
		IF (x < o.x0) OR (x >= o.x0 + o.w) THEN RETURN FALSE END;
		len := vyLongrealVec.Len( o.x );
		(*
	FOR i := 0 TO len-1 DO
	Out.String("x at pos "); Out.Int(i,3); Out.String(" = "); Out.LongReal(vyLongrealVec.Get(o.x,i),5);
	Out.String("       y at pos "); Out.Int(i,3); Out.String(" = "); Out.LongReal(vyLongrealVec.Get(o.y,i),5); Out.Ln;
	END;
	*)
		x0 := o.x0;  pos := 0;  cval := vyLongrealVec.Get( o.x, pos );
		WHILE (x > cval) DO INC( pos );  cval := vyLongrealVec.Get( o.x, pos ) END;
		cur := len;  vyLongrealVec.Append( 0, o.x );  vyLongrealVec.Append( 0, o.y );
		WHILE (cur > pos) DO
			vyLongrealVec.Set( vyLongrealVec.Get( o.x, cur - 1 ), o.x, cur );
			vyLongrealVec.Set( vyLongrealVec.Get( o.y, cur - 1 ), o.y, cur );  DEC( cur )
		END;
		vyLongrealVec.Set( x, o.x, pos );
		y :=
			(vyLongrealVec.Get( o.x, pos ) - vyLongrealVec.Get( o.x, pos - 1 )) /
			(vyLongrealVec.Get( o.x, pos + 1 ) - vyLongrealVec.Get( o.x, pos - 1 )) *
			   (vyLongrealVec.Get( o.y, pos + 1 ) - vyLongrealVec.Get( o.y, pos - 1 )) + vyLongrealVec.Get( o.y, pos - 1 );
		vyLongrealVec.Set( y, o.y, pos );
		(*
	FOR i := 0 TO len DO
	Out.String("x at pos "); Out.Int(i,3); Out.String(" = "); Out.LongReal(vyLongrealVec.Get(o.x,i),20);
	Out.String("       y at pos "); Out.Int(i,3); Out.String(" = "); Out.LongReal(vyLongrealVec.Get(o.y,i),5); Out.Ln;
	END;
	*)

		vyBase.Update( o.x );  RETURN TRUE
	END AddPoint;

	PROCEDURE AddGenericPoint*( o: tObject );
	VAR max, mean: FLOAT64;  len, i: SIGNED32;
	BEGIN
		max := MIN( FLOAT64 );  len := vyLongrealVec.Len( o.x );
		FOR i := 0 TO len - 2 DO
			IF (vyLongrealVec.Get( o.x, i + 1 ) - vyLongrealVec.Get( o.x, i )) > max THEN
				max := (vyLongrealVec.Get( o.x, i + 1 ) - vyLongrealVec.Get( o.x, i ));
				mean := vyLongrealVec.Get( o.x, i ) + 1 / 2 * max
			END
		END;
		IF ~AddPoint( o, mean ) THEN HALT( 100 ) END
	END AddGenericPoint;

	PROCEDURE InitObject*( o: tObject;  x, y, w, h: FLOAT64 );
	BEGIN
		o.handle := ObjectHandler;  o.x0 := x;  o.y0 := y;  o.w := w;  o.h := h;  o.x := vyLongrealVec.New( 2 );
		o.y := vyLongrealVec.New( 2 );  vyLongrealVec.Set( x, o.x, 0 );  vyLongrealVec.Set( y, o.y, 0 );
		vyLongrealVec.Set( x + w, o.x, 1 );  vyLongrealVec.Set( y + h, o.y, 1 )
	END InitObject;

	PROCEDURE Gen*;
	VAR obj: tObject;
	BEGIN
		aM.cmd;  NEW( obj );  InitObject( obj, 0, 0, 1, 1 );  Objects.NewObj := obj
	END Gen;

	PROCEDURE Add*;
	BEGIN
		AddGenericPoint( tempLayer.o );  vyBase.Update( tempLayer.o )
	END Add;

	PROCEDURE Nothing;
	END Nothing;

	PROCEDURE InitView*( o: tView;  obj: tObject );
	BEGIN
		o.handle := ViewHandler;  o.style.fcol := vyGraphBase.black;  o.style.selectcol := vyGraphBase.red;
		o.style.fillcol := vyGraphBase.black;  o.o := obj;
		IF obj # NIL THEN vyBase.Subscribe( obj, o ) END;
		o.commands := NIL;  vyCommandMenus.Add( o.commands, Add, "Add" );  vyCommandMenus.Add( o.commands, Nothing, "-" )
	END InitView;

	PROCEDURE GenV*;
	VAR v: tView;
	BEGIN
		NEW( v );  InitView( v, NIL );  Objects.NewObj := v
	END GenV;

	PROCEDURE Edit( layer: tView;  event: vyEvents.EventMsg );
	(*vs 0.0a1   md  14.02.95 *)
	VAR

		xr, yr, epsx, epsy: FLOAT64;  pos: SIGNED32;  gesture: SIGNED16;
	BEGIN
		(*
	Out.Ln; Out.String("edit");
	*)
		tempLayer := layer;  vyGraphBase.PointToPoint2d( event.x, event.y, xr, yr );
		vyGraphBase.VectorToVector2d( outergrab, outergrab, epsx, epsy );
		IF GetPosition( layer.o, xr, yr, epsx, epsy ) = -1 THEN
			vyCommandMenus.ExecuteListedCommand( event.x, event.y, event, layer.commands )
		ELSE

			vyGraphBase.VectorToVector2d( grabsize, grabsize, epsx, epsy );

			pos := GetPosition( layer.o, xr, yr, epsx, epsy );
			IF pos # -1 THEN
				gesture := event.gesture;
				WHILE event.gesture = gesture DO
					IF SetXY( layer.o, xr, yr, pos ) THEN vyBase.Update( layer ) END;
					vyGraphBase.PointToPoint2d( event.x, event.y, xr, yr );  vyEvents.GetEvent( event )
				END;
				vyBase.Update( layer.o )
			END
		END
	END Edit;

	PROCEDURE Responsible( editor: tView;  VAR event: vyEvents.EventMsg );
	VAR priority: SIGNED16;  xr, yr, epsx, epsy: FLOAT64;

	BEGIN
		IF event.gesture = vyEvents.EvtIdent THEN priority := vyEvents.PrioHigh
		ELSIF event.gesture = vyEvents.EvtSelect THEN priority := vyEvents.PrioNone
		ELSIF event.gesture = vyEvents.EvtLoc THEN
			vyGraphBase.PointToPoint2d( event.x, event.y, xr, yr );
			vyGraphBase.VectorToVector2d( grabsize, grabsize, epsx, epsy );
			IF GetPosition( editor.o, xr, yr, epsx, epsy ) # -1 THEN priority := vyEvents.PrioHigh END
		ELSIF event.gesture = vyEvents.EvtDoubleClick THEN priority := vyEvents.PrioHigh
		END;

		IF event.priority < priority THEN event.responder := editor;  event.priority := priority
		END
	END Responsible;

	PROCEDURE Recall( layer: tView );
	VAR i: SIGNED32;  len: SIGNED32;  x0, y0, x1, y1: SIGNED16;
	BEGIN
		IF layer.o = NIL THEN RETURN END;
		len := vyLongrealVec.Len( layer.o.x );

		vyGraphBase.SetForeColor( layer.style.fillcol );
		vyGraphBase.FrameRect2d( layer.o.x0, layer.o.y0, layer.o.w, layer.o.h );  vyGraphBase.SetForeColor( layer.style.fcol );

		vyGraphBase.Point2dToPoint( vyTypes.VGetR( layer.o.x, 0 ), vyTypes.VGetR( layer.o.y, 0 ), x1, y1 );
		FOR i := 1 TO len - 1 DO
			x0 := x1;  y0 := y1;  vyGraphBase.Point2dToPoint( vyTypes.VGetR( layer.o.x, i ), vyTypes.VGetR( layer.o.y, i ), x1, y1 );
			vyGraphBase.Line( x0, y0, x1, y1 )
		END;
		vyGraphBase.SetForeColor( layer.style.selectcol );
		FOR i := 0 TO len - 1 DO
			vyGraphBase.Point2dToPoint( vyTypes.VGetR( layer.o.x, i ), vyTypes.VGetR( layer.o.y, i ), x1, y1 );
			vyGraphBase.PaintRect( x1 - grabsize DIV 2, y1 - grabsize DIV 2, grabsize, grabsize )
		END


		(*	IF (scatter.x # NIL) THEN
	IF (scatter.x.nrData > 0)  THEN
	nrData := scatter.x.nrData;
	IF scatter.highlight = NIL THEN vyHighlight.AdjustHighlight(scatter) END;

	sel := vyHighlight.GetSelectionAttribute (scatter.highlight);

	FOR i := 0 TO nrData - 1 DO
	vyGraphBase.Point2dToPoint (i, vyTypes.VGetR (scatter.x, i), xx, yy);
	IF sel.nrData > i THEN
	b := vyBooleanVec.Get (sel, i)
	ELSE b := FALSE END;
	IF b THEN vyHostDisplay.SetForeColor(scatter.style.selectcol);
	vyHostDisplay.FrameCircle(xx, yy, 2 * vyHostDisplay.pixel)
	ELSE
	vyHostDisplay.SetForeColor(scatter.style.fcol);
	vyHostDisplay.PaintRect(xx - vyHostDisplay.pixel, yy, 3 * vyHostDisplay.pixel, vyHostDisplay.pixel);
	vyHostDisplay.PaintRect(xx, yy - vyHostDisplay.pixel, vyHostDisplay.pixel, 3 * vyHostDisplay.pixel)
	END
	END
	END
	END
	*)
	END Recall;

	PROCEDURE CopyV( VAR M: Objects.CopyMsg;  obj, copy: tView );
	BEGIN
		copy^ := obj^
	END CopyV;

	PROCEDURE StoreV0( obj: tView;  VAR M: Objects.FileMsg );
	BEGIN
		Files.WriteInt( M.R, 0 );  vyPort.LayerHandler( obj, M );  Gadgets.WriteRef( M.R, obj.lib, obj.o )
	END StoreV0;

	PROCEDURE LoadV0( obj: tView;  VAR M: Objects.FileMsg );
	VAR objsub: Objects.Object;  version: SIGNED16;
	BEGIN
		Files.ReadInt( M.R, version );  vyPort.LayerHandler( obj, M );  Gadgets.ReadRef( M.R, obj.lib, objsub );
		IF objsub # NIL THEN obj.o := objsub( tObject ) END
	END LoadV0;

	PROCEDURE Min( a, b: FLOAT64 ): FLOAT64;
	BEGIN
		IF a < b THEN RETURN a ELSE RETURN b END;
	END Min;

	PROCEDURE ViewHandler*( obj: Objects.Object;  VAR msg: Objects.ObjMsg );
	VAR copy: tView;  x, y: FLOAT64;
	BEGIN
		WITH obj: tView DO
			IF msg IS Display.DisplayMsg THEN
				WITH msg: Display.DisplayMsg DO Recall( obj )
				END;
			ELSIF msg IS vyEvents.EventMsg THEN
				WITH msg: vyEvents.EventMsg DO
					IF msg.callForResponder THEN
						Responsible( obj, msg );   (*vyPort.LayerHandler (obj, msg)*)
					ELSE
						IF msg.gesture = vyEvents.EvtSelect THEN  (* Select (obj, msg) *)
						ELSIF (msg.gesture = vyEvents.EvtIdent) OR (msg.gesture = vyEvents.EvtLoc) THEN Edit( obj, msg )
						ELSIF (msg.gesture = vyEvents.EvtDoubleClick) THEN
							vyGraphBase.PointToPoint2d( msg.x, msg.y, x, y );
							IF AddPoint( obj.o, x ) THEN vyBase.Update( obj ) END
						END
					END;

				END;
			ELSIF msg IS Objects.CopyMsg THEN
				WITH msg: Objects.CopyMsg DO
					IF msg.stamp = obj.stamp THEN
						msg.obj := obj.dlink (* copy M arrives again *)
					ELSE
						GenV;  copy := Objects.NewObj( tView );  msg.obj := copy;  obj.dlink := copy;   (* Generator  *)
						CopyV( msg, obj, msg.obj( tView ) ) (* do not call uhanlde, may result in new object of type "root" *)
					END;
				END;
			ELSIF msg IS Objects.FileMsg THEN
				WITH msg: Objects.FileMsg DO
					IF msg.id = Objects.load THEN LoadV0( obj, msg )
					ELSIF msg.id = Objects.store THEN StoreV0( obj, msg )
					ELSE vyPort.LayerHandler( obj, msg )
					END
				END;
			ELSIF msg IS Objects.AttrMsg THEN
				WITH msg: Objects.AttrMsg DO
					IF msg.id = Objects.enum THEN vyPort.LayerHandler( obj, msg )
					ELSIF msg.id = Objects.get THEN
						IF msg.name = "Gen" THEN msg.s := "antsHistogramEdit.GenV";  msg.class := Objects.String;  msg.res := 0 ELSE vyPort.LayerHandler( obj, msg ) END
					ELSE vyPort.LayerHandler( obj, msg )
					END;
				END;
			ELSIF msg IS Objects.LinkMsg THEN
				WITH msg: Objects.LinkMsg DO
					IF msg.id = Objects.enum THEN msg.Enum( "vectors" );  vyPort.LayerHandler( obj, msg )
					ELSIF msg.id = Objects.get THEN
						IF msg.name = "vectors" THEN msg.obj := obj.o;  msg.res := 0 ELSE vyPort.LayerHandler( obj, msg ) END
					ELSE vyPort.LayerHandler( obj, msg )
					END;
				END;
			ELSIF msg IS Objects.BindMsg THEN
				WITH msg: Objects.BindMsg DO
					IF obj.lib # msg.lib THEN
						vyPort.LayerHandler( obj, msg );  antsObjects.Bind( obj, msg );  antsObjects.Bind( obj.o, msg )
					END
				END;
			ELSIF msg IS vyPort.AdjustCoordMsg THEN
				WITH msg: vyPort.AdjustCoordMsg DO
					vyPort.SetC2d( obj.dlink( vyPort.Picture ), Min( obj.o.x0, 0 ), Min( obj.o.y0, 0 ), Min( obj.o.w, 1 ),
											 Min( obj.o.h, 1 ) );

				END;
			ELSE vyPort.LayerHandler( obj, msg )
			END
		END  (*WITH*)
	END ViewHandler;

	PROCEDURE HandleAttributes( o: tObject;  VAR M: Objects.AttrMsg );
	BEGIN
		IF M.id = Objects.enum THEN
			M.Enum( "Gen" );  M.Enum( "x" );  M.Enum( "y" );  M.Enum( "w" );  M.Enum( "h" );  vyBase.objecthandle( o, M )
		ELSIF M.id = Objects.get THEN
			IF M.name = "Gen" THEN COPY( 'antsHistogramEdit.Gen', M.s );  M.class := Objects.String;  M.res := 0
			ELSIF M.name = "x" THEN M.class := Objects.LongReal;  M.y := o.x0;  M.res := 0
			ELSIF M.name = "y" THEN M.class := Objects.LongReal;  M.y := o.y0;  M.res := 0
			ELSIF M.name = "w" THEN M.class := Objects.LongReal;  M.y := o.w;  M.res := 0
			ELSIF M.name = "h" THEN M.class := Objects.LongReal;  M.y := o.h;  M.res := 0
			ELSE vyBase.objecthandle( o, M )
			END
		ELSIF M.id = Objects.set THEN vyBase.objecthandle( o, M )
		ELSE vyBase.objecthandle( o, M )
		END
	END HandleAttributes;

	PROCEDURE FrameLinks( F: tObject;  VAR M: Objects.LinkMsg );
	BEGIN
		IF M.id = Objects.enum THEN vyBase.objecthandle( F, M )
		ELSIF M.id = Objects.get THEN vyBase.objecthandle( F, M )
		ELSE vyBase.objecthandle( F, M )
		END
	END FrameLinks;

	PROCEDURE CopyObject*( from, to: tObject );
	BEGIN
		to := from
	END CopyObject;

	PROCEDURE ObjectCopy( from: tObject ): tObject;
	VAR to: tObject;
	BEGIN
		Gen;  to := Objects.NewObj( tObject );  CopyObject( from, to );  RETURN to
	END ObjectCopy;

	PROCEDURE HandleFileMsg( obj: tObject;  VAR msg: Objects.FileMsg );
	VAR version: SIGNED16;  objsub: Objects.Object;
		(*! store Picts as GIF for color preserving or store colors *)
	BEGIN
		IF msg.id = Objects.load THEN
			Files.ReadInt( msg.R, version );  vyBase.objecthandle( obj, msg );  Files.ReadLReal( msg.R, obj.x0 );
			Files.ReadLReal( msg.R, obj.y0 );  Files.ReadLReal( msg.R, obj.w );  Files.ReadLReal( msg.R, obj.h );
			Gadgets.ReadRef( msg.R, obj.lib, objsub );
			IF objsub # NIL THEN obj.x := objsub( vyBase.tVector ) ELSE obj.x := NIL END;
			Gadgets.ReadRef( msg.R, obj.lib, objsub );
			IF objsub # NIL THEN obj.y := objsub( vyBase.tVector ) ELSE obj.y := NIL END
		ELSIF msg.id = Objects.store THEN
			Files.WriteInt( msg.R, 0 );  vyBase.objecthandle( obj, msg );  Files.WriteLReal( msg.R, obj.x0 );
			Files.WriteLReal( msg.R, obj.y0 );  Files.WriteLReal( msg.R, obj.w );  Files.WriteLReal( msg.R, obj.h );
			Gadgets.WriteRef( msg.R, obj.lib, obj.x );  Gadgets.WriteRef( msg.R, obj.lib, obj.y )
		ELSE vyBase.objecthandle( obj, msg )
		END
	END HandleFileMsg;

	PROCEDURE ObjectHandler*( obj: Objects.Object;  VAR msg: Objects.ObjMsg );
	BEGIN
		WITH obj: tObject DO
			IF msg IS Objects.AttrMsg THEN
				WITH msg: Objects.AttrMsg DO HandleAttributes( obj, msg )
				END;
			ELSIF msg IS Objects.FileMsg THEN
				WITH msg: Objects.FileMsg DO HandleFileMsg( obj, msg )
				END;
			ELSIF msg IS Objects.LinkMsg THEN
				WITH msg: Objects.LinkMsg DO FrameLinks( obj, msg )
				END;
			ELSIF msg IS Objects.BindMsg THEN
				WITH msg: Objects.BindMsg DO
					IF obj.lib # msg.lib THEN
						vyBase.objecthandle( obj, msg );  antsObjects.Bind( obj, msg );  antsObjects.Bind( obj.x, msg );
						antsObjects.Bind( obj.y, msg )
					END;
				END;
			ELSIF msg IS Objects.CopyMsg THEN
				WITH msg: Objects.CopyMsg DO
					IF msg.stamp = obj.stamp THEN msg.obj := obj.dlink
					ELSE obj.stamp := msg.stamp;  obj.dlink := ObjectCopy( obj );  msg.obj := obj.dlink
					END
				END;
			ELSE vyBase.objecthandle( obj, msg )
			END
		END

	END ObjectHandler;

	PROCEDURE DoShow*( o: tObject;  x, y, w, h: FLOAT64 );
	VAR pict: vyPort.Picture;  obj: tView;
	BEGIN
		NEW( obj );  vyPort.OpenLayer( obj, "antsHisto" );  InitView( obj, o );  pict := vyPort.NewP( vyDisplay2d.NewC2d( x, y, w, h ) );
		vyGraphBase.SetCoordinate( pict.gcontext( vyDisplay2d.tCoordinate2d ).c2d );
		vyGraphBase.SetRealWorldRgn( x, y, w, h, 0 );  vyPort.AddLayer( pict, obj );  vyPort.SetC2d( pict, 0, 0, w, h );
		pict.backGround := vyGraphBase.dgrey;  vyPort.Write( pict );  vyPort.SetC2d( pict, 0, 0, w, h );  aM.dSRSR( "antsHistogramEdit setting: ", w, ",", h );
	END DoShow;

	PROCEDURE Test*;
	VAR o: tObject;
	BEGIN
		NEW( o );  InitObject( o, 0, 0, 1000, 1 );
		(* vyLinks.InsertObj(link,o.x);
	vyBase.Show(link,1,"Scatter"); *)
		(*	b := AddPoint(o,200);
	b := AddPoint(o,50);
	b := AddPoint(o,900);
	b := AddPoint(o,1);
	*)
		(*FOR i := 0 TO 2 DO
	AddGenericPoint(o)
	END;*)
		(*	FOR i := 0 TO 1000 BY 10 DO
	Out.LongReal(GetValue(o,i),20); Out.Ln;
	END;
	*)
		DoShow( o, 0, 0, 1000, 1 )
	END Test;

BEGIN
	aM.launch;
END antsHistogramEdit.

System.Free antsHistogramEdit ~
antsHistogramEdit.Test
