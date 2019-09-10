MODULE vyCaption IN Oberon;   (*vs 0.0a1 md   10.08.95 *)
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
(*=	Contents	a caption as a simple comment in a plot*)
(*	history:
10.8.95 md 0.0a1	alpha version
4.7.95 md 0.0d5	renamed: vyText -> vyCaption
26.1.95 md 0.0d4	cleaned
27.10.94 md 0.0d3	adaped to the renamed vyDisplay & vyPictures
22.07.94 md 0.0d0	created *)

(*! move string: Paint.InvertString *)

IMPORT Files, Objects, Display, vyHostTexts, vyScanners, vyBase, vyName, vyGraphBase, vyHostStrings, vyRectangles,
	vyTracking, vyHostDisplay := vyGraphBase, vyPort, vyEvents;

CONST
	idversion* = "vyCaption 0r0a2";

TYPE
	Real = vyBase.Real;
	tLayer* = POINTER TO tLayerDesc;
	tLayerDesc = RECORD (vyPort.tLayerDesc)
		xr, yr: Real;
		string: ARRAY 128 OF CHAR;
		font: ARRAY 32 OF CHAR
	END;

VAR
	font: ARRAY 32 OF CHAR;

	PROCEDURE Copy( source, dest: tLayer );   (* FOF inserted *)
	BEGIN
		dest^ := source^
	END Copy;

	PROCEDURE Recall( caption: tLayer );
	BEGIN
		vyHostDisplay.SetStringJustification( vyHostDisplay.center, vyHostDisplay.center );
		vyGraphBase.String2d( caption.xr, caption.yr, caption.font, caption.string )
	END Recall;

	PROCEDURE Respond( caption: tLayer;  VAR event: vyEvents.EventMsg );
	VAR x, y, dx, dy: SIGNED16;
	BEGIN
		vyHostDisplay.SetStringJustification( vyHostDisplay.center, vyHostDisplay.center );
		vyGraphBase.Point2dToPoint( caption.xr, caption.yr, x, y );
		vyTracking.FramedString( x, y, caption.font, caption.string, dx, dy );
		IF (dx # 0) OR (dy # 0) THEN
			vyGraphBase.PointToPoint2d( x + dx, y + dy, caption.xr, caption.yr );
			(*vyPort.PictureUpdate (vyPort.HostPicture (caption))*) vyPort.UpdateHostPicture( caption, event )
		END;
		WHILE event.gesture # vyEvents.EvtEmpty DO vyEvents.GetEvent( event ) END
	END Respond;

	PROCEDURE Responsible( caption: tLayer;  VAR event: vyEvents.EventMsg );
	VAR priority: SIGNED16;

		PROCEDURE PointInCaption( ): BOOLEAN;
		VAR x, y, X, Y, W, H, dsr: SIGNED16;
		BEGIN
			vyGraphBase.Point2dToPoint( caption.xr, caption.yr, x, y );
			vyHostDisplay.SetStringJustification( vyHostDisplay.center, vyHostDisplay.center );
			vyHostDisplay.GetStringFrame( x, y, caption.font, caption.string, X, Y, W, H, dsr );
			RETURN vyRectangles.PointInRect( event.x, event.y, X, Y, W, H )
		END PointInCaption;

	BEGIN
		priority := vyEvents.PrioNone;
		IF (event.gesture = vyEvents.EvtIdent) & PointInCaption() THEN priority := vyEvents.PrioHigh END;

		IF event.priority < priority THEN event.responder := caption;  event.priority := priority
		END
	END Responsible;

	PROCEDURE HandleAttributes( obj: tLayer;  VAR M: Objects.AttrMsg );
	BEGIN
		IF M.id = Objects.get THEN
			IF M.name = "Gen" THEN COPY( 'vyCaption.Alloc', M.s );  M.class := Objects.String;  M.res := 0 ELSE vyPort.LayerHandler( obj, M ) END
		ELSE vyPort.LayerHandler( obj, M )
		END
	END HandleAttributes;

	PROCEDURE Store0( obj: tLayer;  VAR M: Objects.FileMsg );
	BEGIN
		Files.WriteLReal( M.R, obj.xr );  Files.WriteLReal( M.R, obj.yr );  Files.WriteString( M.R, obj.string );
		Files.WriteString( M.R, obj.font )
	END Store0;

	PROCEDURE Load0( obj: tLayer;  VAR M: Objects.FileMsg );
	BEGIN
		(* dlink:=M.dlink;	*)
		Files.ReadLReal( M.R, obj.xr );  Files.ReadLReal( M.R, obj.yr );  Files.ReadString( M.R, obj.string );
		Files.ReadString( M.R, obj.font )
	END Load0;

	PROCEDURE Handler*( obj: Objects.Object;  VAR msg: Objects.ObjMsg );
	VAR copy: tLayer;
	BEGIN
		WITH obj: tLayer DO
			IF msg IS Display.DisplayMsg THEN
				WITH msg: Display.DisplayMsg DO Recall( obj )
				END;
			ELSIF msg IS vyEvents.EventMsg THEN
				WITH msg: vyEvents.EventMsg DO
					IF msg.callForResponder THEN Responsible( obj, msg ) ELSE
						IF msg.gesture = vyEvents.EvtIdent THEN Respond( obj, msg ) END
					END;
				END;
			ELSIF msg IS Objects.CopyMsg THEN
				WITH msg: Objects.CopyMsg DO
					NEW( copy );  msg.obj := copy;  vyPort.LayerHandler( obj, msg );  Copy( obj, msg.obj( tLayer ) )
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

	PROCEDURE Open*( F: tLayer;  string: ARRAY OF CHAR );
	VAR id: vyName.tNameArray;
	BEGIN
		Init( F );  F.style := vyHostDisplay.defaultStyle;  COPY( "caption: ", id );  vyHostStrings.Append( id, string );
		vyName.RegisterNamed( F, id );  COPY( string, F.string );  COPY( font, F.font );  F.xr := 0.5;  F.yr := 0.5
	END Open;

	PROCEDURE Insert*;
	VAR caption: tLayer;  pict: vyPort.Picture;  s: vyScanners.Scanner;
		str: ARRAY 128 OF CHAR;
	BEGIN
		(*	get and check focused picture			  *)
		pict := vyPort.GetFocusPicture();
		IF pict = NIL THEN vyHostTexts.Note( vyHostTexts.cNotify, "no picture focused" );  RETURN END;

		vyScanners.NewSScanner( s );  vyScanners.OpenParScanner( s );
		IF ~vyScanners.ExpectName( s, str ) THEN vyHostTexts.Note( vyHostTexts.cNotify, "" ) END;

		NEW( caption );  Open( caption, str );  vyPort.AddLayer( pict, caption );  vyPort.PictureUpdate( pict )
	END Insert;

	PROCEDURE Alloc*;
	VAR layer: tLayer;
	BEGIN
		NEW( layer );  layer.handle := Handler;  Objects.NewObj := layer
	END Alloc;

BEGIN
	font := "Syntax10.Scn.Fnt"
END vyCaption.