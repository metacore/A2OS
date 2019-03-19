MODULE vyLine IN Oberon;   (*vs 0.0a1 md   09.08.95 *)
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
*)
(*= plotting an a,b line line*)

(*	history:
9.8.95 md 0.0a1	alpha version
9.6.95 md 0.0d16	adapted to the new graphic definition
26.1.95 md 0.0d15	cleaned
27.10.94 md 0.0d	adaped to the renamed vyPaint
07.04.94	0.1d2	update after add&copy changed: Ports.LayerAdded
22.06.94	0.1d1	created *)

IMPORT Files, Objects, Display, vyBase, vyGraphBase, vyEvents, vyHostDisplay := vyGraphBase, vyHostStrings, vyName, vyPort, vyParser;

CONST
	idversion* = "vyLine v0r0a2";

TYPE
	Real = vyBase.Real;
	tLayer* = POINTER TO tLayerDesc;
	tLayerDesc = RECORD (vyPort.tLayerDesc)
		lBounded, rBounded: BOOLEAN;
		lBound, rBound: REAL;
		a, b: REAL
	END;

	PROCEDURE New*;
	VAR line: tLayer;
	BEGIN
		NEW( line );  line.lBounded := FALSE;  line.rBounded := FALSE;  line.lBound := MIN( REAL );  line.rBound := MAX( REAL );  line.a := 0;  line.b := 0;
		line.handle := Handler;  Objects.NewObj := line
	END New;

	PROCEDURE Copy( src, dest: tLayer );
	BEGIN
		dest^ := src^
	END Copy;

	PROCEDURE Recall( line: tLayer;  VAR msg: Display.DisplayMsg );
	VAR x, y, w, h: INTEGER;  from, to, y2d: Real;
	BEGIN
		vyPort.GetPictureScreenRegion( msg.dlink( vyPort.Picture ), x, y, w, h );  from := line.lBound;  to := line.rBound;
		IF ~line.lBounded THEN vyGraphBase.PointToPoint2d( x, y, from, y2d ) END;
		IF ~line.rBounded THEN vyGraphBase.PointToPoint2d( x + w, y, to, y2d ) END;
		vyGraphBase.Line2d( from, line.a * from + line.b, to, line.a * to + line.b )
	END Recall;

	PROCEDURE Respond( line: tLayer;  VAR event: vyEvents.EventMsg );
	(** vs 0.0d0 *)  (* md  29.05.95 13:03:40 *)
	VAR lx, ly: INTEGER;  id, val: vyName.tNameArray;
	BEGIN
		id := "y := ";  val := "";  vyHostStrings.AppendRealFix( line.a, 5, 3, 5, val );  vyHostStrings.Append( id, val );
		vyHostStrings.Append( id, "*x + " );  val := "";  vyHostStrings.AppendRealFix( line.b, 5, 3, 5, val );
		vyHostStrings.Append( id, val );

		vyHostDisplay.SetStringJustification( vyHostDisplay.left, vyHostDisplay.bottom );  lx := event.x;  ly := event.y;
		vyHostDisplay.InvertString( lx, ly, "Syntax10.Scn.Fnt", id );

		WHILE event.gesture = vyEvents.EvtIdent DO vyEvents.GetEvent( event )
		END;

		vyHostDisplay.InvertString( lx, ly, "Syntax10.Scn.Fnt", id );  vyHostDisplay.SetCursor( vyHostDisplay.Crosshair );
		vyHostDisplay.DrawCursor( event.x, event.y )
	END Respond;

	PROCEDURE Responsible( line: tLayer;  VAR event: vyEvents.EventMsg );
	CONST toleranz = 4;
	VAR priority: INTEGER;  x, y: INTEGER;  x2d, y2d: Real;
	BEGIN
		priority := vyEvents.PrioNone;
		IF (event.gesture = vyEvents.EvtIdent) THEN
			vyGraphBase.PointToPoint2d( event.x, event.y, x2d, y2d );
			vyGraphBase.Point2dToPoint( x2d, line.a * x2d + line.b, x, y );
			IF (ABS( event.x - x ) + ABS( event.y - y ) < toleranz) THEN priority := vyEvents.PrioNormal END
		ELSIF (event.gesture = vyEvents.EvtSelect) THEN
		END;

		IF event.priority < priority THEN event.responder := line;  event.priority := priority
		END
	END Responsible;

	PROCEDURE HandleAttributes( obj: tLayer;  VAR M: Objects.AttrMsg );
	BEGIN
		IF M.id = Objects.get THEN
			IF M.name = "Gen" THEN COPY( 'vyLine.New', M.s );  M.class := Objects.String;  M.res := 0 ELSE vyPort.LayerHandler( obj, M ) END
		ELSE vyPort.LayerHandler( obj, M )
		END
	END HandleAttributes;

	PROCEDURE Store0( obj: tLayer;  VAR M: Objects.FileMsg );
	BEGIN
		Files.WriteBool( M.R, obj.lBounded );  Files.WriteBool( M.R, obj.rBounded );  Files.WriteReal( M.R, obj.lBound );
		Files.WriteReal( M.R, obj.rBound );  Files.WriteReal( M.R, obj.a );  Files.WriteReal( M.R, obj.b )
	END Store0;

	PROCEDURE Load0( obj: tLayer;  VAR M: Objects.FileMsg );
	VAR
	BEGIN
		Files.ReadBool( M.R, obj.lBounded );  Files.ReadBool( M.R, obj.rBounded );  Files.ReadReal( M.R, obj.lBound );
		Files.ReadReal( M.R, obj.rBound );  Files.ReadReal( M.R, obj.a );  Files.ReadReal( M.R, obj.b )
	END Load0;

	PROCEDURE Handler*( obj: Objects.Object;  VAR msg: Objects.ObjMsg );
	(*vs 0.0a1	md  20.07.94 *)
	VAR copy: tLayer;
	BEGIN
		WITH obj: tLayer DO
			IF msg IS Display.DisplayMsg THEN
				WITH msg: Display.DisplayMsg DO Recall( obj, msg );
				END;
			ELSIF msg IS Objects.CopyMsg THEN
				WITH msg: Objects.CopyMsg DO
					New;  copy := Objects.NewObj( tLayer );  msg.obj := copy;  vyPort.LayerHandler( obj, msg );
					Copy( obj, msg.obj( tLayer ) );
				END;
			ELSIF msg IS Objects.FileMsg THEN
				WITH msg: Objects.FileMsg DO
					IF msg.id = Objects.load THEN Load0( obj, msg );  vyPort.LayerHandler( obj, msg )
					ELSIF msg.id = Objects.store THEN Store0( obj, msg );  vyPort.LayerHandler( obj, msg )
					ELSE vyPort.LayerHandler( obj, msg )
					END;
				END;
			ELSIF msg IS vyEvents.EventMsg THEN
				WITH msg: vyEvents.EventMsg DO
					IF msg.callForResponder THEN Responsible( obj, msg ) ELSE
						IF msg.gesture = vyEvents.EvtSelect THEN
						ELSIF msg.gesture = vyEvents.EvtIdent THEN Respond( obj, msg )
						END
					END;
					(*	| msg: Display.ConsumeMsg DO
			Consume(obj, msg); vyPort.LayerHandler (obj, msg)*)
				END;
			ELSIF msg IS Objects.AttrMsg THEN
				WITH msg: Objects.AttrMsg DO
					HandleAttributes( obj, msg )
					(*	| msg: Objects.BindMsg DO vyPort.LayerHandler(obj, msg);
			IF obj.x # NIL THEN Gadgets.BindObj(obj.x, msg.lib) END*)
				END;
			ELSE vyPort.LayerHandler( obj, msg )
			END
		END
	END Handler;

	PROCEDURE Init( F: tLayer );
	BEGIN
		F.handle := Handler
	END Init;

	PROCEDURE Open*( F: tLayer;  lBounded, rBounded: BOOLEAN;  lBound, rBound, a, b: REAL );
	VAR id: vyName.tNameArray;
	BEGIN
		Init( F );  id := "line";  vyPort.OpenLayer( F, id );  F.lBounded := lBounded;  F.rBounded := rBounded;  F.lBound := lBound;
		F.rBound := rBound;  F.a := a;  F.b := b
	END Open;

(*PROCEDURE Show*;
VAR data: Objects.Object;  F: tLayer;  count: INTEGER;
pict: vyPort.Picture;
a, b : REAL;
inconsistentConditions : BOOLEAN;
BEGIN
data:=vyBase.NextParObj();
WHILE data#NIL DO
WITH data:  vyBase.tVector DO
IF (data.nrData # 2) OR (data = NIL) THEN
vyHostTexts.Msg ("can't plot this data as line : not the right type!");
inconsistentConditions := TRUE; ASSERT (~inconsistentConditions)
END;

a := vyRealVec.Get(data,0); b := vyRealVec.Get(data,1);
ELSE
END;
WHILE (data#NIL) & (vyBase.parameterCount>0) DO data.slink:=vyBase.NextParObj();
NEW (F);  Open (F, FALSE, FALSE, 0, 1, a, b);
pict := vyPort.NewCPicture (0, 0, 1, 1, vyPort.NewC2d (0, 0 , 1, 1));	(*should get coord. from picture*)
vyPort.AddLayer (pict, F);
data:=vyBase.NextParObj();
END;
Objects.NewObj := pict
END Show;*)

	PROCEDURE Insert*;
	VAR line: tLayer;  a, b: REAL;  sc: vyParser.Scanner;
	BEGIN
		vyParser.OpenParScanner( sc );
		IF ~(vyParser.Real( sc, a ) & vyParser.Real( sc, b )) THEN vyParser.MsgSyntax( "Insert", "??/2;??/2" );  RETURN END;
		New;  line := Objects.NewObj( tLayer );  Open( line, FALSE , FALSE , 0, 0, a, b );
		vyPort.AddLayer( vyPort.GetFocusPicture(), line )
	END Insert;

END vyLine.