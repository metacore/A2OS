MODULE vyHighlight IN Oberon;   (*vs 0.0a1 md   09.08.95 *)
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

(*= Highlight selections *)
(*! change to index types defined by vyHost, and clean up: use vector operations *)
(*	history:
03.06.96 removed SHORT size restrictions.
9.8.95 md 0.0a1	alpha version
*)
(* jb 11.11.00 - AdjustHighlight changed *)
(* fof 001205 - Changes for update mechanisms marked with fof 1205 *)

IMPORT Objects, Display, Gadgets, Files, vyHostTexts, vyGraphBase, vyHostStrings, vyParser, vyBase, vyBooleanVec,
	vyRealVec, vyName, vyPort, vyEvents (*,Out*) ;

CONST
	idversion* = "vyHighlight v0r0a3";

	(*mode constants for the selection *)
	define* = 0;  invert* = 1;  add* = 2;  remove* = 3;

TYPE
	Real = vyBase.Real;  Coordinate = vyGraphBase.Coordinate;  tVisualizer* = PROCEDURE ( x0, y0, x1, y1: Coordinate );
	tIdentifier* = PROCEDURE ( layer: vyPort.tLayer;  sel: vyBase.tVector;  x0O, y0O, x1O, y1O, x0N, y0N, x1N, y1N: Real;
											    VAR somethingChanged: BOOLEAN );

	tSelector* = POINTER TO tSelectorDesc;
	tSelectorDesc* = RECORD (vyBase.ObjDesc)
		sel: vyBase.tVector;   (* actual selection vector *)
		selChanges: vyBase.tVector;   (* changes of the selection by the last action *)
		oldSelection: vyBase.tVector;   (* safed old selection for restoring after interclick *)
		selection: vyBase.tVector;
		nrData-: SIGNED32;

		(* dynamic entries - not stored. May be modified *)
		layer: vyPort.tLayer;
		picture: vyPort.Picture;
		visualize: tVisualizer;
		selectionIdentify: tIdentifier;
		do*: PROCEDURE ( selector: tSelector;  VAR event: vyEvents.EventMsg );
	END;

VAR
	selectionMode*: SIGNED16;  lastDataSize: SIGNED32;  newselector*: tSelector;

	PROCEDURE New*;
	BEGIN
		NEW( newselector );  newselector.handle := Handler;  newselector.nrData := 0;  Objects.NewObj := newselector
	END New;

	PROCEDURE HandleFileMsg( obj: tSelector;  VAR msg: Objects.FileMsg );
	VAR objsub: Objects.Object;
	BEGIN
		IF msg.id = Objects.load THEN
			vyBase.objecthandle( obj, msg );  Gadgets.ReadRef( msg.R, obj.lib, objsub );
			IF (objsub # NIL ) & (objsub IS vyBase.tVector) THEN obj.sel := objsub( vyBase.tVector ) END;
			Gadgets.ReadRef( msg.R, obj.lib, objsub );
			IF (objsub # NIL ) & (objsub IS vyBase.tVector) THEN obj.selChanges := objsub( vyBase.tVector ) END;
			Gadgets.ReadRef( msg.R, obj.lib, objsub );
			IF (objsub # NIL ) & (objsub IS vyBase.tVector) THEN obj.oldSelection := objsub( vyBase.tVector ) END;
			Gadgets.ReadRef( msg.R, obj.lib, objsub );
			IF (objsub # NIL ) & (objsub IS vyBase.tVector) THEN obj.selection := objsub( vyBase.tVector ) END;
			Files.ReadLInt( msg.R, obj.nrData )
		ELSIF msg.id = Objects.store THEN
			vyBase.objecthandle( obj, msg );  Gadgets.WriteRef( msg.R, obj.lib, obj.sel );
			Gadgets.WriteRef( msg.R, obj.lib, obj.selChanges );   (*! remove unneccessary entries *)
			Gadgets.WriteRef( msg.R, obj.lib, obj.oldSelection );  Gadgets.WriteRef( msg.R, obj.lib, obj.selection );
			Files.WriteLInt( msg.R, obj.nrData )
		ELSE vyBase.objecthandle( obj, msg )
		END
	END HandleFileMsg;

	PROCEDURE HandleAttributes( obj: tSelector;  VAR M: Objects.AttrMsg );
	BEGIN
		IF M.id = Objects.get THEN
			IF M.name = "Gen" THEN COPY( 'vyHighlight.New', M.s );  M.class := Objects.String;  M.res := 0 ELSE vyBase.objecthandle( obj, M ) END
		ELSE vyBase.objecthandle( obj, M )
		END
	END HandleAttributes;

	PROCEDURE Handler*( obj: Objects.Object;  VAR msg: Objects.ObjMsg );
	BEGIN
		WITH obj: tSelector DO
			IF msg IS Display.FrameMsg THEN vyBase.objecthandle( obj, msg )
					ELSE  (* ~ msg IS Display.FrameMsg *)
				IF msg IS Objects.AttrMsg THEN
					WITH msg: Objects.AttrMsg DO HandleAttributes( obj, msg )
					END;
				ELSIF msg IS Objects.FileMsg THEN
					WITH msg: Objects.FileMsg DO HandleFileMsg( obj, msg )
					END;
				ELSE vyBase.objecthandle( obj, msg )
				END
			END
		END
	END Handler;

	PROCEDURE GetAttribute( n: SIGNED32;  type: SIGNED16;  name: vyName.tNameArray ): vyBase.tVector;
	(*vs 0.0a1 *)  (* md  05.06.95 *)
	VAR attr: vyBase.Object;

		PROCEDURE InstallBool( ): vyBase.Object;
		(*vs 0.0a1 *)  (* md  05.06.95 *)
		VAR o: vyBase.tVector;
		BEGIN
			o := vyBooleanVec.NewConstVector( n, FALSE );
			ASSERT ( o # NIL );
			vyName.RegisterNamed( o, name );  RETURN o
		END InstallBool;

		PROCEDURE InstallReal( ): vyBase.Object;
		(*vs 0.0a1 *)  (* md  05.06.95 *)
		VAR o: vyBase.tVector;
		BEGIN
			o := vyRealVec.New( n );
			ASSERT ( o # NIL );
			vyRealVec.Fill( o, 15, 0, n );  vyName.RegisterNamed( o, name );  RETURN o
		END InstallReal;

	BEGIN
		attr := vyName.Find( vyName.NameBase, name );
		IF attr = NIL THEN
			IF type = 0 THEN attr := InstallBool()
			ELSIF type = 1 THEN attr := InstallReal()
			END
		END;
		RETURN attr( vyBase.tVector )
	END GetAttribute;

	PROCEDURE GetSelectionAttribute*( selector: Objects.Object ): vyBase.tVector;
	(*vs 0.0a1 *)  (* md  05.06.95 *)
	VAR name: vyName.tNameArray;  selObj: vyBase.Object;
	BEGIN
		IF selector = NIL THEN RETURN NIL END;

		ASSERT ( (selector # NIL ) & (selector IS tSelector) );
		WITH selector: tSelector DO
			IF (selector.selection # NIL ) & (selector.selection.nrData = selector.nrData) THEN RETURN (selector.selection) END;
			name := "Attr.selection ";  vyHostStrings.AppendInt( selector.nrData, 0, name );  selObj := GetAttribute( selector.nrData, 0, name );
			ASSERT ( selObj # NIL );
			RETURN selObj( vyBase.tVector )
		END
	END GetSelectionAttribute;

	(*
PROCEDURE GetColorAttribute (selector: tSelector): vyBase.tVector;
(*vs 0.0a1 *)	(* md  05.06.95 *)
VAR name: vyName.tNameArray;   colObj: vyBase.Object;
BEGIN  ASSERT(selector # NIL);
name := "Attr.color ";
vyHostStrings.AppendInt (selector.nrData , 0, name);
colObj := GetAttribute (selector.nrData, 1, name);
ASSERT (colObj # NIL);
RETURN colObj(vyBase.tVector)
END GetColorAttribute;

PROCEDURE GetDesignAttribute (selector: tSelector): vyBase.tVector;
(*vs 0.0a1 *)	(* md  05.06.95 *)
VAR  name: vyName.tNameArray;   dsgnObj: vyBase.Object;
BEGIN ASSERT(selector # NIL);
name := "Attr.design ";
vyHostStrings.AppendInt (selector.nrData , 0, name);
dsgnObj := GetAttribute (selector.nrData, 1, name);
ASSERT (dsgnObj # NIL, 100);
RETURN dsgnObj(vyBase.tVector)
END GetDesignAttribute;
*)

	(*PROCEDURE CheckDataAttributes (selector:tSelector);
VAR x: vyBase.tVector;
BEGIN ASSERT(selector#NIL);
x := GetSelectionAttribute (selector);
IF x = NIL THEN
vyHostTexts.Note (vyHostTexts.cAlert, "Unable to install selection vector!!");
ASSERT (x # NIL)
END;
x := GetColorAttribute (selector);
IF x = NIL THEN
vyHostTexts.Note (vyHostTexts.cAlert, "Unable to install color vector!!");
ASSERT (x # NIL)
END;
x := GetDesignAttribute (selector);
IF x = NIL THEN
vyHostTexts.Note (vyHostTexts.cAlert, "Unable to install design vector!!");
ASSERT (x # NIL)
END
END CheckDataAttributes;
*)
(*PROCEDURE ReturnToPicture (selector: tSelector);
BEGIN vyPort.PictureHandleSetPicture(selector.picture)
END ReturnToPicture;*)

	PROCEDURE Actor( selector: tSelector;  x0, y0, xLast, yLast, xNew, yNew: Coordinate );
	(*vs 0.0a1	md  17.08.94 *)
	VAR x0R, y0R, xLastR, yLastR, xNewR, yNewR: Real;  i: SIGNED32;  x0O, y0O, x1O, y1O, x0N, y0N, x1N, y1N: Real;
		somethingChanged: BOOLEAN;  p: vyPort.Picture;

		PROCEDURE GetRegularRect( lx0, ly0, lx1, ly1: Real;  VAR X0, Y0, X1, Y1: Real );
		BEGIN
			IF lx1 < lx0 THEN X0 := lx1;  X1 := lx0 ELSE X0 := lx0;  X1 := lx1 END;
			IF ly1 < ly0 THEN Y0 := ly1;  Y1 := ly0 ELSE Y1 := ly1;  Y0 := ly0 END
		END GetRegularRect;

	BEGIN
		vyPort.PictureHandleSetPicture( selector.picture );  p := selector.picture;
		vyGraphBase.PointToPoint2d( x0, y0, x0R, y0R );  vyGraphBase.PointToPoint2d( xLast, yLast, xLastR, yLastR );
		vyGraphBase.PointToPoint2d( xNew, yNew, xNewR, yNewR );

		GetRegularRect( x0R, y0R, xLastR, yLastR, x0O, y0O, x1O, y1O );
		GetRegularRect( x0R, y0R, xNewR, yNewR, x0N, y0N, x1N, y1N );

		somethingChanged := FALSE;   (* fof 1205 *)
		selector.selectionIdentify( selector.layer, selector.selChanges, x0O, y0O, x1O, y1O, x0N, y0N, x1N, y1N,
												   somethingChanged );

		IF somethingChanged THEN
			FOR i := 0 TO (selector.nrData) - 1 DO
				IF vyBooleanVec.Get( selector.selChanges, i ) THEN
					CASE selectionMode OF
					define, invert:
							vyBooleanVec.Set( ~vyBooleanVec.Get( selector.sel, i ), selector.sel, i )
					| add:
							vyBooleanVec.Set( TRUE , selector.sel, i )
					| remove:
							vyBooleanVec.Set( FALSE , selector.sel, i )
					END  (*CASE *)
				END
			END;
			vyBase.Update( selector );   (* fof 1205 *)
			vyBase.Update( selector.selection );   (* fof 1205 *)  (*Out.String('vyHighlight.Actor Update');Out.Ln;*)
			(* Gadgets.Update(p); (* fof 1205 , need that for Display3.Mask to be set*) (*! move to vyPort.PictureHandleSetPicture, did not work with p today. *)  *)
			vyPort.PictureHandleSetPicture( p );  vyGraphBase.SetDisplayMode( vyGraphBase.invert );
			selector.visualize( x0, y0, xNew, yNew )
		END
	END Actor;

	PROCEDURE DoSelection( selector: tSelector;  VAR event: vyEvents.EventMsg );
	(*vs 0.0a1	md  17.08.94 *)
	VAR x0, y0, xOld, yOld, xNew, yNew, xLast, yLast: Coordinate;  gesture: SIGNED16;
	BEGIN
		vyGraphBase.SetDisplayMode( vyGraphBase.invert );  vyPort.PictureHandleSetPicture( selector.picture );
		x0 := event.x;  y0 := event.y;  xOld := x0;  yOld := y0;  xLast := x0;  yLast := y0;  xNew := event.x;  yNew := event.y;

		gesture := event.gesture;
		WHILE event.gesture = gesture DO
			IF (xNew # xOld) OR (yNew # yOld) THEN
				selector.visualize( x0, y0, xOld, yOld );  selector.visualize( x0, y0, xNew, yNew );  xOld := xNew;  yOld := yNew
			ELSE Actor( selector, x0, y0, xLast, yLast, xNew, yNew );  xLast := xNew;  yLast := yNew
			END;
			xNew := event.x;  yNew := event.y;  vyEvents.GetEvent( event )
		END;
		selector.visualize( x0, y0, xNew, yNew );
		(*vyBase.Update(selector.sel); *)  (*? gs *)
	END DoSelection;

	PROCEDURE AdjustHighlight*( layer: vyPort.tLayer );
	VAR selector: tSelector;
	BEGIN
		IF layer.highlight = NIL THEN
			IF (layer.x # NIL ) THEN layer.highlight := layer.x.cacheHighlight END;
			IF (layer.highlight = NIL ) & (layer.y # NIL ) THEN layer.highlight := layer.y.cacheHighlight END;
			IF (layer.highlight = NIL ) & (layer.z # NIL ) THEN layer.highlight := layer.z.cacheHighlight END;
			(* not found: create new *)
			IF layer.highlight = NIL THEN
				New;  layer.highlight := newselector;
				(* jb 11.11.00 - added to avoid selector.nrData = 0 when vec.nrData # 0 *)
				(*! hack. needs correction *)
				IF layer.x # NIL THEN newselector.nrData := layer.x.nrData
				ELSIF layer.y # NIL THEN newselector.nrData := layer.y.nrData
				ELSIF layer.z # NIL THEN newselector.nrData := layer.z.nrData
				END

			END;
			vyBase.Subscribe( (*for messages from source*) layer.highlight, layer )
		END;
		ASSERT ( layer.highlight # NIL , 100 );   (*! remove temporary tests *)
		ASSERT ( layer.highlight IS tSelector, 101 );

		selector := layer.highlight( tSelector );
		IF (layer.x # NIL ) & (layer.x.cacheHighlight = NIL ) THEN layer.x.cacheHighlight := selector END;
		IF (layer.y # NIL ) & (layer.y.cacheHighlight = NIL ) THEN layer.y.cacheHighlight := selector END;
		IF (layer.z # NIL ) & (layer.z.cacheHighlight = NIL ) THEN layer.z.cacheHighlight := selector END

	END AdjustHighlight;

	PROCEDURE OpenSelector*( layer: vyPort.tLayer;  n: SIGNED32;  vizor: tVisualizer;  actor: tIdentifier;  VAR msg: Objects.ObjMsg );
	(*vs 0.0a1	md  17.08.94 *)
	VAR i: SIGNED32;  o: vyBase.Object;  selector: tSelector;
	BEGIN
		(* heuristics: find highlight candidate *)
		AdjustHighlight( layer );  selector := layer.highlight( tSelector );

		ASSERT ( vizor # NIL );
		ASSERT ( actor # NIL );

		selector.nrData := n;  selector.selection := GetSelectionAttribute( selector );  o := GetSelectionAttribute( selector );
		selector.oldSelection := o( vyBase.tVector );  selector.layer := layer;  selector.picture := msg.dlink( vyPort.Picture );

		selector.visualize := vizor;  selector.selectionIdentify := actor;  selector.do := DoSelection;

		selector.sel := selector.selection( vyBase.tVector );  selector.selChanges := vyBooleanVec.New( selector.nrData );

		IF selectionMode = define THEN
			FOR i := 0 TO selector.nrData - 1 DO
				vyBooleanVec.Set( vyBooleanVec.Get( selector.sel, i ), selector.oldSelection, i );
				(*? cpy selection to old sel, change:=FALSE; sel:=FALSE *)
				vyBooleanVec.Set( FALSE , selector.selChanges, i );  vyBooleanVec.Set( FALSE , selector.sel, i )
			END;
			vyBase.Update( selector.selection )
		ELSE
			FOR i := 0 TO selector.nrData - 1 DO
				vyBooleanVec.Set( vyBooleanVec.Get( selector.sel, i ), selector.oldSelection, i );
				vyBooleanVec.Set( FALSE , selector.selChanges, i )
			END
		END;
		lastDataSize := n;  vyBase.Subscribe( (*for messages from source*) selector, layer );
		vyBase.Subscribe( (*for messages from source*) selector.selection, layer ) (* fof 1205 *)
	END OpenSelector;

	PROCEDURE SetMode*;
	VAR s: vyParser.Scanner;
		mode: ARRAY 16 OF CHAR;

	BEGIN
		vyParser.OpenParScanner( s );
		IF ~vyParser.Name( s, mode ) THEN
			IF selectionMode = define THEN vyHostTexts.Note( vyHostTexts.cNotify, "selection mode: define" )
			ELSIF selectionMode = invert THEN vyHostTexts.Note( vyHostTexts.cNotify, "selection mode: invert" )
			ELSIF selectionMode = add THEN vyHostTexts.Note( vyHostTexts.cNotify, "selection mode: add" )
			ELSIF selectionMode = remove THEN vyHostTexts.Note( vyHostTexts.cNotify, "selection mode: remove" )
			END;
			RETURN
		END;

		IF mode = "define" THEN selectionMode := define;  vyHostTexts.Note( vyHostTexts.cNotify, "new selection mode: define" )
		ELSIF mode = "invert" THEN selectionMode := invert;  vyHostTexts.Note( vyHostTexts.cNotify, "new selection mode: invert" )
		ELSIF mode = "add" THEN selectionMode := add;  vyHostTexts.Note( vyHostTexts.cNotify, "new selection mode: add" )
		ELSIF mode = "remove" THEN selectionMode := remove;  vyHostTexts.Note( vyHostTexts.cNotify, "new selection mode: remove" )
		END
	END SetMode;
(*
PROCEDURE ColorData*;   (*! remove this from vyHighlight *)
VAR s: vyParser.Scanner;   color: SIGNED32;   i: SIGNED32;
sel, col: vyBase.tVector;

BEGIN
IF lastDataSize > 0 THEN
vyParser.OpenParScanner(s);
IF ~vyParser.ExpectNumber(s, color) THEN RETURN END;
IF color < 0 THEN
vyHostTexts.Note (vyHostTexts.cNotify, "the color should be greater then 0");   RETURN
END;
IF color > 15 THEN
vyHostTexts.Note (vyHostTexts.cNotify, "the color should be tess then 15");   RETURN
END;
sel := GetSelectionAttribute (lastDataSize);
col := GetColorAttribute (lastDataSize);
FOR i := 0 TO lastDataSize - 1 DO
IF vyBooleanVec.Get (sel, i) THEN
vyRealVec.Set (color, col, i)
END
END;
vyBase.Update (col)
END
END ColorData;
*)
BEGIN
	selectionMode := define;  lastDataSize := 0
END vyHighlight.
