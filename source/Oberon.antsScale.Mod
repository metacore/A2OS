MODULE antsScale IN Oberon;
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




IMPORT antsContainers, Objects, Display, vyGraphBase, Files, vyDisplay2d, vyPort, vyBase, vyHostTexts, vyAxis, vyEvents, aM := antsMessages;

CONST
	left = 0;  right = 1;  top = 2;  bottom = 3;

TYPE
	Coordinate = vyGraphBase.Coordinate;

	tLayer* = POINTER TO tLayerDesc;
	tLayerDesc* = RECORD (vyPort.tLayerDesc)
		pos: SIGNED16;
		digits: SIGNED16
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

	PROCEDURE Recall( scale: tLayer;  VAR msg: Display.DisplayMsg );
	VAR x, y, w, h: Coordinate;  x2d1, x2d2, y2d1, y2d2: FLOAT64;
	BEGIN
		vyAxis.SetColors( scale.style.fcol, scale.style.fcol, scale.style.fcol );  vyAxis.PlotLabels( TRUE );
		vyAxis.SetLabelFont( scale.style.fnt );  vyAxis.AutomaticTicks( TRUE );
		vyPort.GetPictureScreenRegion( msg.dlink( vyPort.Picture ), x, y, w, h );  vyAxis.FlipAxesOrientation( TRUE );
		vyGraphBase.PointToPoint2d( x, y, x2d1, y2d1 );  vyGraphBase.PointToPoint2d( x + w, y + h, x2d2, y2d2 );
		vyAxis.SetDigitsAfterPoint( scale.digits );  vyAxis.SetLabelFont( scale.style.fnt );
		IF scale.pos = top THEN
			vyAxis.FlipAxesOrientation( TRUE );  vyAxis.ForcePlot( x, y, x + w, y, x2d1, x2d2, (x2d2 - x2d1) / 2 )
		ELSIF scale.pos = bottom THEN
			vyAxis.FlipAxesOrientation( FALSE );  vyAxis.ForcePlot( x, y + h - 1, x + w, y + h - 1, x2d1, x2d2, (x2d2 - x2d1) / 2 )
		ELSIF scale.pos = left THEN
			vyAxis.FlipAxesOrientation( TRUE );  vyAxis.ForcePlot( x, y, x, y + h, y2d1, y2d2, (y2d2 - y2d1) / 2 )
		ELSIF scale.pos = right THEN
			vyAxis.FlipAxesOrientation( FALSE );  vyAxis.ForcePlot( x + w - 1, y, x + w - 1, y + h, y2d1, y2d2, (y2d2 - y2d1) / 2 )
		END
	END Recall;

(* PROCEDURE DoControl (scale: tLayer; VAR event: vyEvents.EventMsg);
VAR x,y,w,h: SIGNED16; X,Y,W,H: SIGNED16;
BEGIN
x := event.x;   y := event.y;   pict := event.dlink(vyPort.Picture);
WHILE event.gesture=vyEvents.Evt DO vyEvents.GetEvent (event);

END;
END DoControl; *)



	PROCEDURE DoControl2( scale: tLayer;  VAR event: vyEvents.EventMsg );
	VAR pict: vyPort.Picture;  x, y: Coordinate;
	BEGIN
		x := event.x;  y := event.y;  pict := event.dlink( vyPort.Picture );
		WHILE event.gesture = vyEvents.EvtSelect DO vyEvents.GetEvent( event ) END;
		IF (x # event.x) THEN
			IF x - event.x > 0 THEN
				(*reduce digits*)
				scale.digits := Max( 0, scale.digits - 1 )
			ELSE scale.digits := Min( 8, scale.digits + 1 )
			END;
			vyPort.PictureUpdate( pict )
		END
	END DoControl2;

	PROCEDURE Responsible( scale: tLayer;  VAR event: vyEvents.EventMsg );
	VAR priority: SIGNED16;
	BEGIN
		priority := vyEvents.PrioNone;
		IF ((event.gesture = vyEvents.EvtIdent) OR (event.gesture = vyEvents.EvtSelect)) THEN
			priority := vyEvents.PrioNormal;
			IF event.priority < priority THEN event.responder := scale;  event.priority := priority END
		END
	END Responsible;

	PROCEDURE Store0( o: tLayer;  VAR M: Objects.FileMsg );
	BEGIN
		Files.WriteInt( M.R, 0 );  Files.WriteInt( M.R, o.pos );  Files.WriteInt( M.R, o.digits )
	END Store0;

	PROCEDURE Load0( o: tLayer;  VAR M: Objects.FileMsg );
	VAR version: SIGNED16;
	BEGIN
		Files.ReadInt( M.R, version );  Files.ReadInt( M.R, o.pos );  Files.ReadInt( M.R, o.digits )
	END Load0;

	PROCEDURE Copy*( VAR M: Objects.CopyMsg;  src, dest: tLayer );
	BEGIN
		dest^ := src^;  vyPort.LayerCopy( M, src, dest )
		(* (* never deepcopy data in a layer ! *)
	IF M.id = Objects.deep THEN
	ELSE
	END;
	*)
	END Copy;

	PROCEDURE Alloc*;
	BEGIN
		NEW( newlayer );  newlayer.handle := Handler;  Objects.NewObj := newlayer
	END Alloc;

	PROCEDURE Handler*( o: Objects.Object;  VAR M: Objects.ObjMsg );
	VAR copy: tLayer;  uhandle: Objects.Handler;  gen: PROCEDURE;

	CONST GenProc = "antsScale.Alloc";   (* Gen Procedure as String *)
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
						Responsible( o, M );  uhandle( o, M ) (* if not responsible: maybe root is *)
					ELSE
						IF M.gesture = vyEvents.EvtIdent THEN
						ELSIF M.gesture = vyEvents.EvtSelect THEN DoControl2( o, M )
						ELSE
							uhandle( o, M ) (* that M belongs to root *)
						END
					END;
				END;
			ELSIF M IS Objects.CopyMsg THEN
				WITH M: Objects.CopyMsg DO
					IF M.stamp = o.stamp THEN
						M.obj := o.dlink (* copy M arrives again *)
					ELSE
						gen;  copy := Objects.NewObj( tLayer );  M.obj := copy;   (* Generator  *)
						Copy( M, o, M.obj( tLayer ) ) (* do not call uhanlde, may result in new object of type "root" *)
					END;
				END;
			ELSIF M IS Objects.FileMsg THEN
				WITH M: Objects.FileMsg DO
					uhandle( o, M );
					IF M.id = Objects.load THEN Load0( o, M )
					ELSIF M.id = Objects.store THEN Store0( o, M )
					END;
				END;
			ELSIF M IS Objects.AttrMsg THEN
				WITH M: Objects.AttrMsg DO
					IF M.id = Objects.get THEN
						IF M.name = "Gen" THEN COPY( GenProc, M.s );  M.class := Objects.String;  M.res := 0
						ELSIF M.name = "Position" THEN M.class := Objects.Int;  M.i := o.pos;  M.res := 0
						ELSE uhandle( o, M )
						END
					ELSIF M.id = Objects.set THEN
						IF M.name = "Position" THEN
							IF M.class = Objects.Int THEN o.pos := SHORT( M.i );  M.res := 0;  vyBase.Update( o ) END
						ELSE uhandle( o, M )
						END
					ELSIF M.id = Objects.enum THEN M.Enum( "Position" );  uhandle( o, M )
					ELSE uhandle( o, M )
					END
				END;
			ELSIF M IS Objects.BindMsg THEN
				WITH M: Objects.BindMsg DO
					uhandle( o, M )
					(* add own binds here: Bind(o.entry,M) *)
				END;
			ELSE uhandle( o, M )
			END
		END
	END Handler;

	PROCEDURE Open*( scale: tLayer;  id: ARRAY OF CHAR );
	BEGIN
		vyPort.OpenLayer( scale, id );  scale.handle := Handler;  scale.style.fnt := vyAxis.DefaultLabelFont
	END Open;

	PROCEDURE New*;
	BEGIN
		aM.cmd;  NEW( newlayer );  Open( newlayer, "scale" );  Objects.NewObj := newlayer
	END New;

	PROCEDURE Insert*;
	VAR pict: vyPort.Picture;  layer: tLayer;
	BEGIN
		New;  layer := Objects.NewObj( tLayer );  Open( layer, "test" );  layer.digits := 2;  layer.pos := 0;
		pict := vyPort.NewP( vyDisplay2d.NewC2d( 0, 0, 1, 1 ) );
		vyGraphBase.SetCoordinate( pict.gcontext( vyDisplay2d.tCoordinate2d ).c2d );  vyPort.AddLayer( pict, layer );
		vyPort.Write( pict )
	END Insert;

	PROCEDURE ScaleToPicture( p: vyPort.Picture;  posx, posy: SIGNED32 );
	VAR p1: vyPort.Picture;  a: Objects.AttrMsg;  layer: tLayer;  minw, minh: SIGNED16;  x, y, w, h, dsr: SIGNED16;
	BEGIN
		New;  layer := Objects.NewObj( tLayer );  layer.digits := 2;  minw := vyAxis.MinStdWidth();
		minh := vyAxis.MinStdWidth();  vyGraphBase.GetStringFrame( 0, 0, layer.style.fnt, "999.99", x, y, w, h, dsr );  INC( minw, w );
		INC( minh, h );  INC( minh, dsr );
		IF (ABS( posx ) = 1) & (ABS( posy ) = 1) THEN layer.pos := -1
		ELSIF posx > 0 THEN layer.pos := left
		ELSIF posx < 0 THEN layer.pos := right
		ELSIF posy > 0 THEN layer.pos := top
		ELSIF posy < 0 THEN layer.pos := bottom
		END;
		p1 := vyPort.NewP( p.gcontext( vyBase.Object ) );  vyPort.AddLayer( p1, layer );
		antsContainers.Resize( p1, minw, minh );

		a.res := -1;  a.name := "hdr";  a.class := Objects.Bool;  a.b := FALSE;  a.id := Objects.set;  p1.handle( p1, a );  a.res := -1;
		a.name := "borderW";  a.class := Objects.Int;  a.i := 0;  a.id := Objects.set;  p1.handle( p1, a );

		vyHostTexts.InsertGadget( p1 );  antsContainers.StickOn( p, p1, posx, posy )
	END ScaleToPicture;

	PROCEDURE ScalesToPort*;
	VAR M: Display.SelectMsg;  pict: vyPort.Picture;  i, j: SIGNED16;  a: Objects.AttrMsg;
	BEGIN
		M.id := Display.get;  M.F := NIL;  M.sel := NIL;  M.obj := NIL;  M.time := -1;  Display.Broadcast( M );
		IF M.time # -1 THEN
			pict := M.obj( vyPort.Picture );  a.res := -1;  a.name := "borderW";  a.class := Objects.Int;  a.i := 0;  a.id := Objects.set;
			pict.handle( pict, a );
			FOR i := -1 TO 1 DO
				FOR j := -1 TO 1 DO
					IF ~((i = 0) & (j = 0)) THEN ScaleToPicture( pict, i, j ) END
				END
			END
		END
	END ScalesToPort;

BEGIN
	aM.launch;
END antsScale.

antsFunctions.Define test ~
Voyager.Show test as antsFctEdit ~
antsScale.Insert ~
System.Free antsScale vyAxis~
antsObjects.WriteAllFields test~
antsScale.ScalesToPort
Gadgets.Insert Panels.NewPanel ~
Voyager.Random 20 ~
Generator:  U
New random numbers generated as
System.Free antsFctEdit ~










vyAxis.Prepare




Voyager.Random 20 ~
Generator:  U
New random numbers generated as
UPM70A1BF22

Voyager.Show UPM70A1BF22
~
Gadgets.ChangeAttr borderW 0 ~
