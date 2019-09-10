MODULE vyLabel IN Oberon;
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
(c) F.Friedrich, StatLab Heidelberg

*)

IMPORT Objects, Oberon, Display, Texts, Files, Fonts, vyBase, vyHostStrings, vyRectangles, vyGraphBase,
	vyHostDisplay := vyGraphBase, vyPort, vyParser, vyHostTexts, vyEvents;

CONST
	idversion* = "vyLabel v0r0a2";  VMargin = 5;  HMargin = 10;  StdFont = "Syntax10.Scn.Fnt";  realcoord = 5;

TYPE
	Real = vyBase.Real;
	tLayer* = POINTER TO tLayerDesc;
	tLayerDesc* = RECORD (vyPort.tLayerDesc)
		xi, yi, w, h, dsr: SIGNED16;
		xr, yr: Real;
		atx, aty: SIGNED16;
		name: ARRAY 64 OF CHAR
	END;

VAR
	UsedFont-: ARRAY 32 OF CHAR;
	AttachX-, AttachY-: SIGNED16;  slink*, dlink*: Objects.Object;

	PROCEDURE Copy( src, dest: tLayer );
	BEGIN
		dest^ := src^
	END Copy;

	PROCEDURE PointInLabel( label: tLayer;  X1, Y1: SIGNED16;  VAR msg: Objects.ObjMsg ): BOOLEAN;
	VAR x, y, X, Y, W, H: SIGNED16;
	BEGIN
		vyHostDisplay.GetStringSize( label.style.fnt, label.name, label.w, label.h, label.dsr );
		vyPort.GetPictureScreenRegion( msg.dlink( vyPort.Picture ), X, Y, W, H );
		IF (label.atx = realcoord) THEN x := label.xi - label.w DIV 2
		ELSIF (label.atx = vyHostDisplay.left) THEN x := label.xi + X + HMargin
		ELSIF (label.atx = vyHostDisplay.center) THEN x := label.xi + X + W DIV 2 - label.w DIV 2
		ELSIF (label.atx = vyHostDisplay.right) THEN x := X + W + label.xi - HMargin - label.w
		END;
		IF label.aty = realcoord THEN y := label.yi - label.h DIV 2
		ELSIF label.aty = vyHostDisplay.bottom THEN y := label.yi + Y + VMargin
		ELSIF label.aty = vyHostDisplay.center THEN y := label.yi + Y + H DIV 2 - label.h DIV 2
		ELSIF label.aty = vyHostDisplay.top THEN y := Y + H + label.yi - VMargin - label.h
		END;
		RETURN vyRectangles.PointInRect( X1, Y1, x, y, label.w, label.h )
	END PointInLabel;

	PROCEDURE Recall( label: tLayer;  VAR msg: Objects.ObjMsg );
	VAR X, Y, W, H, x, y: SIGNED16;  xor, yor: SIGNED16;  temp: SIGNED16;
	BEGIN
		vyPort.GetPictureScreenRegion( msg.dlink( vyPort.Picture ), X, Y, W, H );
		IF (label.atx = realcoord) THEN
			vyGraphBase.Point2dToPoint( label.xr, label.yr, label.xi, temp );  x := label.xi;  xor := vyHostDisplay.center
		ELSIF (label.atx = vyHostDisplay.left) THEN x := label.xi + X + HMargin;  xor := vyHostDisplay.left
		ELSIF (label.atx = vyHostDisplay.center) THEN x := label.xi + X + W DIV 2;  xor := vyHostDisplay.center
		ELSIF (label.atx = vyHostDisplay.right) THEN x := X + W + label.xi - HMargin;  xor := vyHostDisplay.right
		END;
		IF (label.aty = realcoord) THEN
			vyGraphBase.Point2dToPoint( label.xr, label.yr, temp, label.yi );  y := label.yi;  yor := vyHostDisplay.center
		ELSIF label.aty = vyHostDisplay.bottom THEN y := label.yi + Y + VMargin;  yor := vyHostDisplay.bottom
		ELSIF label.aty = vyHostDisplay.center THEN y := label.yi + Y + H DIV 2;  yor := vyHostDisplay.center
		ELSIF label.aty = vyHostDisplay.top THEN y := Y + H + label.yi - VMargin;  yor := vyHostDisplay.top
		END;
		vyHostDisplay.SetStringJustification( xor, yor );  vyHostDisplay.String( x, y + label.dsr, label.style.fnt, label.name )
	END Recall;

	PROCEDURE DoControl( label: tLayer;  VAR event: vyEvents.EventMsg );
	VAR pict: vyPort.Picture;  x, y, oldx, oldy: SIGNED16;
	BEGIN
		x := event.x;  y := event.y;  pict := event.dlink( vyPort.Picture );  oldx := label.xi;  oldy := label.yi;
		WHILE event.gesture = vyEvents.EvtIdent DO
			vyEvents.GetEvent( event );  label.xi := oldx + event.x - x;  label.yi := oldy + event.y - y;
			IF (label.atx = realcoord) OR (label.aty = realcoord) THEN
				vyGraphBase.PointToPoint2d( label.xi, label.yi, label.xr, label.yr )
			END;
			vyPort.UpdateHostPicture( label, event )
		END
	END DoControl;

	PROCEDURE Responsible( label: tLayer;  VAR event: vyEvents.EventMsg );
	VAR priority: SIGNED16;
	BEGIN
		priority := vyEvents.PrioNone;
		IF (event.gesture = vyEvents.EvtIdent) & (PointInLabel( label, event.x, event.y, event )) THEN
			priority := vyEvents.PrioNormal;

			IF event.priority < priority THEN event.responder := label;  event.priority := priority
			END
		END
	END Responsible;

	PROCEDURE HandleAttributes( obj: tLayer;  VAR M: Objects.AttrMsg );
	BEGIN
		IF M.id = Objects.get THEN
			IF M.name = "Gen" THEN COPY( 'vyLabel.Alloc', M.s );  M.class := Objects.String;  M.res := 0
			ELSIF M.name = "label" THEN COPY( obj.name, M.s );  M.class := Objects.String;  M.res := 0;
			ELSE vyPort.LayerHandler( obj, M )
			END
		ELSIF M.id = Objects.set THEN
			IF M.name = "label" THEN
				IF M.class = Objects.String THEN COPY( M.s, obj.name );  M.res := 0;  END;
			ELSE vyPort.LayerHandler( obj, M )
			END;
		ELSIF M.id = Objects.enum THEN M.Enum( "label" );  vyPort.LayerHandler( obj, M )
		ELSE

			vyPort.LayerHandler( obj, M )
		END
	END HandleAttributes;

	PROCEDURE Store0( obj: tLayer;  VAR M: Objects.FileMsg );
	BEGIN
		Files.WriteInt( M.R, obj.xi );  Files.WriteInt( M.R, obj.yi );  Files.WriteInt( M.R, obj.w );  Files.WriteInt( M.R, obj.h );
		Files.WriteInt( M.R, obj.dsr );  Files.WriteLReal( M.R, obj.xr );  Files.WriteLReal( M.R, obj.yr );
		Files.WriteInt( M.R, obj.atx );  Files.WriteInt( M.R, obj.aty );  Files.WriteString( M.R, obj.name )
	END Store0;

	PROCEDURE Load0( obj: tLayer;  VAR M: Objects.FileMsg );
	BEGIN
		dlink := M.dlink;  Files.ReadInt( M.R, obj.xi );  Files.ReadInt( M.R, obj.yi );  Files.ReadInt( M.R, obj.w );
		Files.ReadInt( M.R, obj.h );  Files.ReadInt( M.R, obj.dsr );  Files.ReadLReal( M.R, obj.xr );
		Files.ReadLReal( M.R, obj.yr );  Files.ReadInt( M.R, obj.atx );  Files.ReadInt( M.R, obj.aty );
		Files.ReadString( M.R, obj.name )
	END Load0;

	PROCEDURE Handler*( obj: Objects.Object;  VAR msg: Objects.ObjMsg );
	VAR copy: tLayer;
	BEGIN
		WITH obj: tLayer DO
			IF msg IS Display.DisplayMsg THEN
				WITH msg: Display.DisplayMsg DO Recall( obj, msg );
				END;
			ELSIF msg IS Objects.CopyMsg THEN
				WITH msg: Objects.CopyMsg DO
					Alloc;  copy := Objects.NewObj( tLayer );  msg.obj := copy;  vyPort.LayerHandler( obj, msg );
					Copy( obj, msg.obj( tLayer ) );
				END;
			ELSIF msg IS vyEvents.EventMsg THEN
				WITH msg: vyEvents.EventMsg DO
					IF msg.callForResponder THEN Responsible( obj, msg )
					ELSIF msg.gesture = vyEvents.EvtIdent THEN DoControl( obj, msg )
					END;
				END;
			ELSIF msg IS Objects.FileMsg THEN
				WITH msg: Objects.FileMsg DO
					IF msg.id = Objects.load THEN Load0( obj, msg );  vyPort.LayerHandler( obj, msg )
					ELSIF msg.id = Objects.store THEN Store0( obj, msg );  vyPort.LayerHandler( obj, msg )
					ELSE vyPort.LayerHandler( obj, msg )
					END;
				END;
			ELSIF msg IS Objects.AttrMsg THEN
				WITH msg: Objects.AttrMsg DO HandleAttributes( obj, msg )
				END;
			ELSE vyPort.LayerHandler( obj, msg )
			END
		END
	END Handler;

	PROCEDURE Init( F: tLayer );
	BEGIN
		F.handle := Handler
	END Init;

	PROCEDURE Open*( F: tLayer;  name: ARRAY OF CHAR );
	VAR id: ARRAY 32 OF CHAR;
		i: SIGNED16;
	BEGIN
		Init( F );  id := "label:";
		IF vyHostStrings.Length( name ) < 8 THEN vyHostStrings.Append( name, id ) ELSE
			FOR i := 0 TO 8 DO id[i + 6] := name[i] END;
			id[i + 6] := 0X;  vyHostStrings.Append( id, ".." )
		END;
		vyPort.OpenLayer( F, id );  COPY( name, F.name );  COPY( UsedFont, F.style.fnt );  F.xi := 0;  F.yi := 0;  F.xr := 0;  F.yr := 0;
		vyHostDisplay.GetStringSize( F.style.fnt, F.name, F.w, F.h, F.dsr );  F.atx := AttachX;  F.aty := AttachY
	END Open;

	PROCEDURE Insert*;
	VAR pict: vyPort.Picture;  label: tLayer;  sc: Texts.Scanner;
		name: ARRAY 32 OF CHAR;
		X, Y, W, H: SIGNED16;
	BEGIN
		Texts.OpenScanner( sc, Oberon.Par.text, Oberon.Par.pos );  Texts.Scan( sc );
		IF (sc.class # Texts.Name) & (sc.class # Texts.String) THEN vyHostTexts.Msg( "Syntax: vyLabel.Insert <name>" ) END;
		COPY( sc.s, name );  pict := vyPort.GetFocusPicture();
		(*! teste auf 2d Koordinaten *)
		IF pict # NIL THEN
			NEW( label );  Open( label, name );  vyPort.AddLayer( pict, label );  vyPort.GetPictureScreenRegion( pict, X, Y, W, H );
			vyGraphBase.PointToPoint2d( X + W DIV 2, Y + H DIV 2, label.xr, label.yr );  vyPort.PictureUpdate( pict )
		END
	END Insert;

	PROCEDURE DoSetAttachment*( hor, ver: SIGNED16 );
	BEGIN
		AttachX := hor;  AttachY := ver
	END DoSetAttachment;

	PROCEDURE SetAttachment*;
	VAR sc: vyParser.Scanner;
		xident, yident: ARRAY 32 OF CHAR;
		x, y: SIGNED16;
	BEGIN
		vyParser.OpenParScanner( sc );
		IF ~(vyParser.Name( sc, xident ) & vyParser.Name( sc, yident )) THEN vyHostTexts.Msg( "Justification [left|center|right|real][top|center|bottom|real]" );  RETURN END;
		IF xident = "center" THEN x := vyHostDisplay.center
		ELSIF xident = "left" THEN x := vyHostDisplay.left
		ELSIF xident = "right" THEN x := vyHostDisplay.right
		ELSIF xident = "real" THEN x := realcoord
		END;
		IF yident = "center" THEN y := vyHostDisplay.center
		ELSIF yident = "top" THEN y := vyHostDisplay.top
		ELSIF yident = "bottom" THEN y := vyHostDisplay.bottom
		ELSIF yident = "real" THEN y := realcoord
		END;
		DoSetAttachment( x, y )
	END SetAttachment;

	PROCEDURE SetFont*;
	VAR sc: Texts.Scanner;
		font: ARRAY 32 OF CHAR;
	BEGIN
		Texts.OpenScanner( sc, Oberon.Par.text, Oberon.Par.pos );  Texts.Scan( sc );  COPY( sc.s, font );
		IF Fonts.This( font ) = NIL THEN vyHostTexts.NoteSS( 1, font, " : no valid font !" ) END;
		COPY( font, UsedFont )
	END SetFont;

	PROCEDURE Alloc*;
	VAR layer: tLayer;
	BEGIN
		NEW( layer );  layer.handle := Handler;  Objects.NewObj := layer
	END Alloc;

BEGIN
	AttachX := vyHostDisplay.center;  AttachY := vyHostDisplay.top;  UsedFont := StdFont;
END vyLabel.