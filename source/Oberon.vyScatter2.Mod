MODULE vyScatter2 IN Oberon;
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
(c) M. Diller, G. Sawitzki, StatLab Heidelberg
*)

(*= 	Contents	Scatter plot of two variables
*)

(*	history:
9.8.95 md 0.0a1		alpha version
16.2.95 md 0.0d17		handling of empty chunks
27.10.94 md 0.0d14	adaped to the renamed vyHostDisplay & vyPictures
08.08.94 md v0r0d0	created *)

IMPORT Gadgets, Objects, Display, vyHostStrings, vyHostTexts, vyHostDisplay := vyGraphBase, vyBase, vyGraphBase, vyLinks,
	vyName, vyBooleanVec, vyTypes, Out, vyRectangles, Attributes, vyPort, vyDisplay2d, vyHighlight, vyEvents, Files, vyCommandMenus;

CONST
	idversion* = "vyScatter2 v0r0a3";  cMin = 0;  cMax = 1;

TYPE
	Real = vyBase.Real;  Coordinate = vyGraphBase.Coordinate;
	tLayer* = POINTER TO tLayerDesc;
	tLayerDesc = RECORD (vyPort.tLayerDesc)
		ViewLastOnly: BOOLEAN (* fof 020625 *)
	END;

VAR
	slink*, dlink*: Objects.Object;  newlayer-: tLayer;
VAR
	tempLayer: tLayer;

(*	PROCEDURE^ Alloc*;*)

	PROCEDURE Copy( source, dest: tLayer );
	BEGIN
		dest^ := source^
	END Copy;

	PROCEDURE Recall( scatter: tLayer );
	VAR nrData, i: LONGINT;  sel: vyBase.tVector;  xx, yy: Coordinate;  b, lastb: BOOLEAN;  lastx, lasty: Coordinate;  width: INTEGER;
		pattern: ARRAY 256 OF CHAR;
	BEGIN
		Attributes.GetString( scatter, "plotpattern", pattern );
		IF (scatter.x # NIL ) & (scatter.y # NIL ) THEN
			lastx := MAX( Coordinate );
			IF (scatter.x.nrData > 0) & (scatter.x.nrData = scatter.y.nrData) THEN
				nrData := scatter.x.nrData;
				IF (scatter.highlight = NIL ) OR (scatter.highlight( vyHighlight.tSelector ).nrData # scatter.x.nrData) THEN
					vyHighlight.AdjustHighlight( scatter )
				END;   (* fof 020625 *)

				IF ~scatter.ViewLastOnly THEN  (* fof 020625 *)

					sel := vyHighlight.GetSelectionAttribute( scatter.highlight );

					width := scatter.style.pensize;

					FOR i := 0 TO nrData - 1 DO
						vyGraphBase.Point2dToPoint( vyTypes.VGetR( scatter.x, i ), vyTypes.VGetR( scatter.y, i ), xx, yy );
						IF sel.nrData > i THEN b := vyBooleanVec.Get( sel, i )
								ELSE b := FALSE END;   (* fof 0111 *)

						IF (lastx # xx) OR (lasty # yy) OR (lastb # b) THEN
							vyHostDisplay.SetForeColor( scatter.style.fcol );
							IF pattern = "" THEN
								IF b THEN
									vyHostDisplay.SetForeColor( scatter.style.selectcol );
									vyHostDisplay.FrameCircle( xx, yy, 2 * vyHostDisplay.pixel )
								ELSIF width = 1 THEN
									vyHostDisplay.PaintRect( xx - vyHostDisplay.pixel, yy, 3 * vyHostDisplay.pixel, vyHostDisplay.pixel );
									vyHostDisplay.PaintRect( xx, yy - vyHostDisplay.pixel, vyHostDisplay.pixel, 3 * vyHostDisplay.pixel )
								ELSE
									vyHostDisplay.PaintRect( xx - vyHostDisplay.pixel * width DIV 2,
																			 yy - vyHostDisplay.pixel * width DIV 2, vyHostDisplay.pixel * width,
																			 vyHostDisplay.pixel * width );
								END
							ELSIF pattern = "framecircle" THEN vyHostDisplay.FrameCircle( xx, yy, 3 * width * vyHostDisplay.pixel DIV 2 );
							ELSIF pattern = "framerect" THEN
								vyHostDisplay.FrameRect( xx - 2 * vyHostDisplay.pixel * width, yy - 2 * vyHostDisplay.pixel * width,
																		   4 * vyHostDisplay.pixel * width, 4 * vyHostDisplay.pixel * width );
							ELSIF pattern = "filledrect" THEN
								vyHostDisplay.PaintRect( xx - 2 * vyHostDisplay.pixel * width, yy - 2 * vyHostDisplay.pixel * width,
																		 4 * vyHostDisplay.pixel * width, 4 * vyHostDisplay.pixel * width );
							ELSIF pattern = "cross" THEN
								vyHostDisplay.Line( xx - 1 * width, yy - 1 * width, xx + 1 * width, yy + 1 * width );
								vyHostDisplay.Line( xx - 1 * width, yy + 1 * width, xx + 1 * width, yy - 1 * width );
							END;

						END;
						lastb := b;  lastx := xx;  lasty := yy
					END
				ELSE
					vyHostDisplay.SetForeColor( scatter.style.selectcol );
					vyGraphBase.Point2dToPoint( vyTypes.VGetR( scatter.x, scatter.x.nrData - 1 ),
																	 vyTypes.VGetR( scatter.y, scatter.y.nrData - 1 ), xx, yy );
					vyHostDisplay.FrameCircle( xx, yy, 2 * vyHostDisplay.pixel )
				END
			END
		END
	END Recall;

(* selection methods for the use of the Interactive.tSelector *)
	PROCEDURE Vizor( x0, y0, x1, y1: Coordinate );
	BEGIN
		vyHostDisplay.FrameRect( x0, y0, x1 - x0, y1 - y0 )
	END Vizor;

	PROCEDURE Actor( layer: vyPort.tLayer;  sel: vyBase.tVector;  x0O, y0O, x1O, y1O, x0N, y0N, x1N, y1N: Real;
								VAR somethingChanged: BOOLEAN );
	(*vs 0.0a1	md  16.08.94 *)
	VAR scatter: tLayer;  nrData, i: LONGINT;  new: BOOLEAN;  X, Y: Real;

		PROCEDURE PointInRect( px, py, x0, y0, x1, y1: Real ): BOOLEAN;
		BEGIN
			RETURN (x0 <= px) & (px <= x1) & (y0 <= py) & (py <= y1)
		END PointInRect;

	BEGIN
		IF sel # NIL THEN  (* gs hack *)
			scatter := layer( tLayer );  nrData := scatter.x.nrData;
			FOR i := 0 TO nrData - 1 DO
				X := vyTypes.VGetR( scatter.x, i );  Y := vyTypes.VGetR( scatter.y, i );
				new :=
					(PointInRect( X, Y, x0N, y0N, x1N, y1N ) & ~PointInRect( X, Y, x0O, y0O, x1O, y1O )) OR
					(~PointInRect( X, Y, x0N, y0N, x1N, y1N ) & PointInRect( X, Y, x0O, y0O, x1O, y1O ));
				vyBooleanVec.Set( new, sel, i );  somethingChanged := somethingChanged OR new
			END
		END
	END Actor;

	PROCEDURE Select( scatter: tLayer;  VAR event: vyEvents.EventMsg );
	VAR selector: vyHighlight.tSelector;
	BEGIN
		vyHighlight.OpenSelector( scatter, scatter.x.nrData, Vizor, Actor, event );
		selector := scatter.highlight( vyHighlight.tSelector );  selector.do( selector, event )
	END Select;

	PROCEDURE Prompt( scatter: tLayer;  VAR event: vyEvents.EventMsg );
	(*? should be supported as the selections with an abstract identifier *)
	(*vs 0.0a1 *)  (* md  04.06.95 *)
	CONST toleranz = 2 * vyHostDisplay.pixel;
	VAR p: vyPort.Picture;  found, i, nrData: LONGINT;  r: Real;  lx, ly, x0, y0: Coordinate;  id, val: vyName.tNameArray;
	BEGIN
		vyHostDisplay.SetCursor( vyHostDisplay.Wheel );  found := -1;  nrData := scatter.x.nrData;
		p := event.dlink( vyPort.Picture );  id := "";
		WHILE event.gesture = vyEvents.EvtIdent DO
			FOR i := 0 TO nrData - 1 DO
				vyGraphBase.Point2dToPoint( vyTypes.VGetR( scatter.x, i ), vyTypes.VGetR( scatter.y, i ), x0, y0 );
				IF (i # found) & (ABS( x0 - event.x ) + ABS( y0 - event.y ) < toleranz) THEN
					vyHostDisplay.InvertString( lx, ly, "Syntax10.Scn.Fnt", id );  found := i;  id := "(";  val := "";
					(*! label *)

					Out.Ln;  Out.String( "at: " );  Out.Int( i, 10 );  r := vyTypes.VGetR( scatter.x, i );  Out.Ln;  Out.String( "x=" );
					Out.LongReal( r, 40 );  vyHostStrings.AppendRealFix( r, 4, 2, 5, val );  vyHostStrings.Append( id, val );
					vyHostStrings.Append( id, ", " );  val := "";  r := vyTypes.VGetR( scatter.y, i );  Out.Ln;  Out.String( "y=" );
					Out.LongReal( r, 40 );

					vyHostStrings.AppendRealFix( r, 4, 2, 5, val );  vyHostStrings.Append( id, val );  vyHostStrings.Append( id, ")" );
					vyHostDisplay.SetStringJustification( vyHostDisplay.left, vyHostDisplay.bottom );  lx := event.x;  ly := event.y;
					vyHostDisplay.InvertString( lx, ly, "Syntax10.Scn.Fnt", id )
				END
			END;
			vyEvents.GetEvent( event )
		END;
		vyHostDisplay.InvertString( lx, ly, "Syntax10.Scn.Fnt", id );  vyHostDisplay.SetCursor( vyHostDisplay.Crosshair );
		vyHostDisplay.DrawCursor( event.x, event.y )
	END Prompt;

	PROCEDURE Responsible( scatter: tLayer;  VAR event: vyEvents.EventMsg );
	VAR priority: INTEGER;

		PROCEDURE InScatter( x, y: Coordinate ): BOOLEAN;
		CONST eps = 3;
		VAR minX, minY, maxX, maxY: Real;  x0, y0, x1, y1: Coordinate;  nans: LONGINT;

		BEGIN
			vyTypes.VGetMinMax( scatter.x, minX, maxX, nans );  vyTypes.VGetMinMax( scatter.y, minY, maxY, nans );
			vyGraphBase.Point2dToPoint( minX, minY, x0, y0 );  vyGraphBase.Point2dToPoint( maxX, maxY, x1, y1 );
			RETURN vyRectangles.PointInRect( x, y, x0 - eps, y0 - eps, x1 - x0 + 2 * eps, y1 - y0 + 2 * eps )
		END InScatter;

	BEGIN
		priority := vyEvents.PrioNone;
		IF ((event.gesture = vyEvents.EvtSelect) OR (event.gesture = vyEvents.EvtIdent)) & (InScatter( event.x, event.y )) THEN
			priority := vyEvents.PrioNormal
		END;

		IF event.priority < priority THEN event.responder := scatter;  event.priority := priority
		END
	END Responsible;

	PROCEDURE Consume( o: tLayer;  msg: Display.ConsumeMsg );
	VAR v, w: vyBase.tVector;  minX, maxX, minY, maxY: Real;  pict: vyPort.Picture;  data: Objects.Object;  nans: LONGINT;
	BEGIN
		pict := msg.dlink( vyPort.Picture );  data := msg.obj;  v := vyBase.GetVFromObj( data );  data := data.slink;
		w := vyBase.GetVFromObj( data );
		IF (v # NIL ) & (w # NIL ) THEN Init( o, msg.obj );

			vyTypes.VGetMinMax( o.x, minX, maxX, nans );  vyTypes.VGetMinMax( o.y, minY, maxY, nans );
			vyPort.SetNewC2d( pict, minX, minY, maxX - minX, maxY - minY );  vyBase.Update( v )
		END
	END Consume;

	PROCEDURE LinkName( obj: vyBase.Object;  VAR M: Objects.AttrMsg );
	BEGIN
		M.s := '';  vyName.AppendObjId( obj, M.s );  M.class := Objects.String;  M.res := 0
	END LinkName;

	PROCEDURE HandleAttributes( obj: tLayer;  VAR M: Objects.AttrMsg );
	BEGIN
		IF M.id = Objects.get THEN
			IF M.name = "Gen" THEN COPY( 'vyScatter2.New', M.s );  M.class := Objects.String;  M.res := 0
			ELSIF (M.name = "xlink") & (obj.x # NIL ) THEN LinkName( obj.x, M )
			ELSIF (M.name = "ylink") & (obj.y # NIL ) THEN LinkName( obj.y, M )
			ELSIF (M.name = "ViewLastOnly") THEN M.class := Objects.Bool;  M.b := obj.ViewLastOnly;  M.res := 0
			ELSE vyPort.LayerHandler( obj, M )
			END
		ELSIF M.id = Objects.set THEN
			IF M.name = "ViewLastOnly" THEN
				IF M.class = Objects.Bool THEN obj.ViewLastOnly := M.b;  M.res := 0;  vyBase.Update( obj ) END
			ELSE vyPort.LayerHandler( obj, M )
			END
		ELSIF M.id = Objects.enum THEN M.Enum( "xlink" );  M.Enum( "ylink" );  M.Enum( "ViewLastOnly" );  vyPort.LayerHandler( obj, M )
		ELSE vyPort.LayerHandler( obj, M )
		END
	END HandleAttributes;

	PROCEDURE AdjustCoord( pict: vyPort.Picture;  obj: tLayer );
	VAR minX, maxX, minY, maxY: REAL;  nans: LONGINT;
	BEGIN
		IF pict # NIL THEN
			IF (obj.x # NIL ) & (obj.y # NIL ) THEN
				vyTypes.VGetMinMaxR( obj.x, minX, maxX, nans );  vyTypes.VGetMinMaxR( obj.y, minY, maxY, nans );
				vyPort.SetNewC2d( pict, minX, minY, maxX - minX, maxY - minY )
			END
		END
	END AdjustCoord;

	PROCEDURE SetModel( pict: vyPort.Picture;  obj: tLayer;  data: Objects.Object );
	VAR id: vyName.tNameArray;
	BEGIN
		IF (obj.x # NIL ) THEN vyBase.UnSubscribe( obj.x, obj );  obj.x := NIL END;
		IF (obj.y # NIL ) THEN vyBase.UnSubscribe( obj.y, obj );  obj.y := NIL END;
		IF data = NIL THEN RETURN END;
		obj.sources := NIL;
		IF (data = NIL ) OR (data.slink = NIL ) THEN vyHostTexts.Note( vyHostTexts.cWarning, "vyScatter2.SetModel: can't show these data as a scatter2" )
		ELSE
			obj.x := vyBase.GetVFromObj( data );  obj.y := vyBase.GetVFromObj( data.slink );  COPY( "scatter: ", id );
			vyName.AppendObjId( data( vyBase.Object ).slink( vyBase.Object ), id );  vyHostStrings.Append( id, " by " );
			vyName.AppendObjId( data( vyBase.Object ), id );  vyName.RegisterNamed( obj, id );
			(*vyHighlight.SubscribeSelector (obj.x.nrData, obj);*)
			(*	vyBase.Subscribe ((*for messages from source*) vyHighlight.GetSelectionAttribute (obj.x.nrData), obj);
		vyBase.Subscribe ((*for messages from source*) vyHighlight.GetColorAttribute (obj.x.nrData), obj);
		vyBase.Subscribe ((*for messages from source*) vyHighlight.GetSelectionAttribute (obj.y.nrData), obj);
		vyBase.Subscribe ((*for messages from source*) vyHighlight.GetColorAttribute (obj.y.nrData), obj);
		*)
			vyBase.Subscribe( (*for messages from source*) obj.x, obj );  vyBase.Subscribe( (*for messages from source*) obj.y,
																																														   obj );
			(* F.style.selectcol := F.style.fcol *)
			AdjustCoord( pict, obj );  vyBase.Update( data )
		END
	END SetModel;

	PROCEDURE HandleLinks( obj: tLayer;  VAR msg: Objects.LinkMsg );
	(*! handle subscribe/unsubscribe. Move to vyPort *)
	VAR pict: vyPort.Picture;
	BEGIN
		IF (msg.id = Objects.enum) THEN msg.Enum( "x" );  msg.Enum( "y" );  vyPort.LayerHandler( obj, msg )
		ELSIF (msg.id = Objects.get) & (msg.name = "x") THEN msg.obj := obj.x;  msg.res := 0
		ELSIF (msg.id = Objects.get) & (msg.name = "y") THEN msg.obj := obj.y;  msg.res := 0
		ELSIF ((msg.id = Objects.set) (*! Behandlung von msg.name = "y"*)
		& ((msg.name = "x") OR (msg.name = "Model")) & (msg.obj # NIL ) & (msg.obj IS vyBase.tVector)) THEN
			(* check proper type *)
			IF msg.dlink # NIL THEN pict := msg.dlink( vyPort.Picture ) ELSE pict := NIL END;
			SetModel( pict, obj, msg.obj );  msg.res := 0
		ELSE vyPort.LayerHandler( obj, msg )
		END
	END HandleLinks;

	PROCEDURE Store0( obj: tLayer;  VAR M: Objects.FileMsg );
	BEGIN
		Gadgets.WriteRef( M.R, obj.lib, NIL );   (* hack to insert version control, fof 020212 *)
		Files.WriteInt( M.R, 1 );   (* version control *)

		Gadgets.WriteRef( M.R, obj.lib, obj.x );  Gadgets.WriteRef( M.R, obj.lib, obj.y );
		Files.WriteBool( M.R, obj.ViewLastOnly )
	END Store0;

	PROCEDURE Load0( obj: tLayer;  VAR M: Objects.FileMsg );
	VAR objsub: Objects.Object;  version: INTEGER;
	BEGIN
		version := 0;  dlink := M.dlink;  Gadgets.ReadRef( M.R, obj.lib, objsub );
		IF objsub = NIL THEN Files.ReadInt( M.R, version );  Gadgets.ReadRef( M.R, obj.lib, objsub ) END;
		IF (objsub # NIL ) & (objsub IS vyBase.tVector) THEN obj.x := objsub( vyBase.tVector ) END;
		Gadgets.ReadRef( M.R, obj.lib, objsub );
		IF (objsub # NIL ) & (objsub IS vyBase.tVector) THEN obj.y := objsub( vyBase.tVector ) END;
		IF version > 0 THEN Files.ReadBool( M.R, obj.ViewLastOnly ) END
	END Load0;

	PROCEDURE pattern;
	VAR pattern: ARRAY 256 OF CHAR;
	BEGIN
		Attributes.GetString( tempLayer, "plotpattern", pattern );
		IF pattern = "" THEN pattern := "filledrect"
		ELSIF pattern = "filledrect" THEN pattern := "framecircle"
		ELSIF pattern = "framecircle" THEN pattern := "framerect";
		ELSIF pattern = "framerect" THEN pattern := "cross";

		ELSE pattern := "";
		END;
		Attributes.SetString( tempLayer, "plotpattern", pattern );  vyBase.Update( tempLayer );
	END pattern;

	PROCEDURE New*;   (* Gadgets.Insert vyScatter2.New *)
	BEGIN
		NEW( newlayer );  Init( newlayer, NIL );  Objects.NewObj := newlayer
	END New;

	PROCEDURE Handler*( obj: Objects.Object;  VAR msg: Objects.ObjMsg );
	(*vs 0.0a1	md  08.08.94 *)
	BEGIN
		WITH obj: tLayer DO
			tempLayer := obj;
			IF msg IS Display.DisplayMsg THEN
				WITH msg: Display.DisplayMsg DO Recall( obj );
				END;
			ELSIF msg IS vyEvents.EventMsg THEN
				WITH msg: vyEvents.EventMsg DO
					IF msg.callForResponder THEN
						Responsible( obj, msg );   (*vyPort.LayerHandler (obj, msg)*)
					ELSE
						IF msg.gesture = vyEvents.EvtSelect THEN Select( obj, msg )
						ELSIF msg.gesture = vyEvents.EvtIdent THEN Prompt( obj, msg )
						END
					END;
				END;
			ELSIF msg IS Objects.CopyMsg THEN
				WITH msg: Objects.CopyMsg DO
				(*Alloc;  copy := Objects.NewObj(tLayer);  msg.obj := copy;    vyPort.LayerHandler (obj, msg);
			ASSERT(msg.obj # NIL);
			Copy (obj, msg.obj(tLayer));*)
					New;  msg.obj := newlayer;  vyPort.LayerHandler( obj, msg );  Copy( obj, msg.obj( tLayer ) );
				END;
			ELSIF msg IS Objects.FileMsg THEN
				WITH msg: Objects.FileMsg DO
					IF msg.id = Objects.load THEN
						Load0( obj, msg );  vyPort.LayerHandler( obj, msg )
						(*
				(*! hack *)IF ((obj.x # NIL) & (obj.y # NIL)) THEN pict := msg.dlink(vyPort.Picture);
				IF pict # NIL THEN vyTypes.VGetMinMaxR(obj.x, minX, maxX, nans);
				vyPort.SetNewC2d (pict, minX, 0, maxX - minX, 1)
				(*!move error handling to vyPicture*)
				ELSE (*vyHostTexts.Note(vyHostTexts.cWarning, "vyScatter2: no host picture  ")*)
				END
				ELSE vyHostTexts.Note(vyHostTexts.cWarning, "vyScatter2: no x obj loaded  ")
				END
				*)
					ELSIF msg.id = Objects.store THEN Store0( obj, msg );  vyPort.LayerHandler( obj, msg )
					ELSE vyPort.LayerHandler( obj, msg )
					END;
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
					IF obj.x # NIL THEN Gadgets.BindObj( obj.x, msg.lib ) END;
					IF obj.y # NIL THEN Gadgets.BindObj( obj.y, msg.lib ) END
				END;
			ELSIF msg IS vyCommandMenus.enumMsg THEN
				WITH msg: vyCommandMenus.enumMsg DO
					tempLayer := obj;  msg.EnumSender( "", NIL , obj );  msg.Enum( "toggle patterns", pattern, obj );

				END;
			ELSE vyPort.LayerHandler( obj, msg )
			END
		END
	END Handler;

	PROCEDURE NewPict*;   (* Gadgets.Insert vyScatter1.NewPict *)
	VAR pict: vyPort.Picture;
	BEGIN
		New;  pict := vyPort.XNewCPicture( 0, 0, 1, 1, vyDisplay2d.NewC2d( 0, cMin, 1, cMax - cMin ) );
		vyPort.AddLayer( pict, newlayer );  Objects.NewObj := pict
		(* Out.String('vyScatter2.XNewPict done'); IF pict.gcontext#NIL THEN Out.String(' w.context');END; Out.Ln; *)
	END NewPict;

(*PROCEDURE Init (F : tLayer);
BEGIN 	F.handle := Handler
END Init;*)

	PROCEDURE Init*( F: tLayer;  data: Objects.Object );
	VAR id: vyName.tNameArray;  inconsistentConditions: BOOLEAN;
	BEGIN
		F.ViewLastOnly := FALSE;  F.handle := Handler;  COPY( "scatter: ", id );  F.x := vyBase.GetVFromObj( data );
		IF data # NIL THEN data := data.slink;  F.y := vyBase.GetVFromObj( data ) END;
		IF ((F.x = NIL ) OR (F.y = NIL )) & (data # NIL ) THEN vyHostTexts.Msg( "can't plot this data as a scatter plot: not the right type!" );  inconsistentConditions := TRUE;
			ASSERT ( ~inconsistentConditions, vyBase.precc + 1 )
		ELSIF (F.x # NIL ) & (F.y # NIL ) THEN
			IF (F.x.nrData # F.y.nrData) THEN vyHostTexts.Msg( "can't plot this data as a scatter plot: not the same length!" );  inconsistentConditions := TRUE;
				ASSERT ( ~inconsistentConditions, vyBase.precc + 2 )
			END
		END;
		IF (data # NIL ) & (data.slink # NIL ) THEN
			vyName.AppendObjId( data( vyBase.Object ).slink( vyBase.Object ), id );  vyHostStrings.Append( id, " by " );
			vyName.AppendObjId( data( vyBase.Object ), id )
		END;
		vyPort.OpenLayer( F, id );
		(*F.handle := Handler; *)
		(* F.dsg := vyPatterns.circle; *)
		IF (F.x # NIL ) & (F.y # NIL ) THEN
		(*vyHighlight.SubscribeSelector (F.x.nrData, F);*)
			(*		vyBase.Subscribe ((*for messages from source*) vyHighlight.GetSelectionAttribute (F.x.nrData), F);
		vyBase.Subscribe ((*for messages from source*) vyHighlight.GetColorAttribute (F.x.nrData), F);
		vyBase.Subscribe ((*for messages from source*) vyHighlight.GetSelectionAttribute (F.y.nrData), F);
		vyBase.Subscribe ((*for messages from source*) vyHighlight.GetColorAttribute (F.y.nrData), F);
		*)
			vyBase.Subscribe( (*for messages from source*) F.x, F );  vyBase.Subscribe( (*for messages from source*) F.y, F )
			(* F.style.selectcol := F.style.fcol *)
		END
	END Init;

	PROCEDURE OpenO*( F: tLayer;  x, y: Objects.Object );
	VAR id: vyName.tNameArray;  inconsistentConditions: BOOLEAN;
	BEGIN
		F.handle := Handler;  F.x := vyBase.GetVFromObj( x );  F.y := vyBase.GetVFromObj( y );
		IF (F.x = NIL ) OR (F.y = NIL ) THEN vyHostTexts.Msg( "can't plot this data as a scatter plot: not the right type!" );  inconsistentConditions := TRUE;
			ASSERT ( ~inconsistentConditions, vyBase.precc + 1 )
		ELSIF (F.x.nrData # F.y.nrData) THEN vyHostTexts.Msg( "can't plot this data as a scatter plot: not the same length!" );  inconsistentConditions := TRUE;
			ASSERT ( ~inconsistentConditions, vyBase.precc + 2 )
		END;
		COPY( "scatter: ", id );  vyName.AppendObjId( F.y, id );  vyHostStrings.Append( id, " by " );  vyName.AppendObjId( F.x, id );
		vyPort.OpenLayer( F, id );
		(*vyHighlight.SubscribeSelector (F.x.nrData, F);*)
		vyBase.Subscribe( (*for messages from source*) F.x, F );  vyBase.Subscribe( (*for messages from source*) F.y, F )
	END OpenO;

	PROCEDURE OpenL*( F: tLayer;  list: vyLinks.Link );
	VAR x, y: Objects.Object;
	BEGIN
		x := list.obj;  list := list.link;  y := list.obj;  OpenO( F, x, y )
	END OpenL;

	PROCEDURE ShowP*;
	VAR data: Objects.Object;
	BEGIN
		data := vyBase.NextParObj();

		WHILE (data # NIL ) & (vyBase.parameterCount > 0) DO
			data.slink := vyBase.NextParObj();  New;  Init( newlayer, data );
			(*pict := vyPort.InsertNewVecPicture (F.x,F.y);
		vyPort.AddLayer (pict, F);*)
			vyPort.AddLayer( vyPort.InsertNewVecPicture( newlayer.x, NIL ), newlayer );  data := vyBase.NextParObj()
		END;
		(*Objects.NewObj := pict*)
	END ShowP;

	PROCEDURE ShowL*( list: vyLinks.Link );
	VAR i: INTEGER;
	BEGIN
		WHILE list # NIL DO
			New;  Init( newlayer, list.obj );
			(*pict := vyPort.InsertNewVecPicture (F.x,F.y);
		vyPort.AddLayer (pict, F);*)
			vyPort.AddLayer( vyPort.InsertNewVecPicture( newlayer.x, NIL ), newlayer );
			(* fof: would take newlayer.x,newlayer.y, why NIL ? *)
			FOR i := 1 TO 2 DO
				IF list # NIL THEN
					IF list.link = NIL THEN list := NIL ELSE list := list.link END
				END
			END;
			(*Objects.NewObj := pict*)
		END
	END ShowL;

	PROCEDURE ShowO*( x, y: Objects.Object );
	BEGIN
		x.slink := y;  New;  Init( newlayer, x );
		(*pict := vyPort.InsertNewVecPicture (F.x,F.y);
	vyPort.AddLayer (pict, F);
	Objects.NewObj := pict*)
		vyPort.AddLayer( vyPort.InsertNewVecPicture( newlayer.x, NIL ), newlayer )
	END ShowO;

(*PROCEDURE Alloc*;
VAR	layer: tLayer;
BEGIN NEW (layer);    layer.handle := Handler;     Objects.NewObj := layer  END Alloc;*)

	PROCEDURE AddObservation*( x, y: Real;  scatter: tLayer );
	(*! up to now not tested
	VAR  (* dsg: vyPatterns.tDesign;  sgn: vyHostDisplay.tSign; *)
	BEGIN
	(*! repair ! *)

	vyRealVec.Append (x, scatter.x);
	vyRealVec.Append (y, scatter.y);

	(* dsg := scatter.dsg;  sgn := dsg.sgn0; *)
	(*IF case xCHunk.usedentries is selected THEN sgn := dsg.sgn1 ELSE sgn := dsg.sgn0 END;*)
	vyDisplay2d.PaintColPat (x, y, 15, sgn)
	*)
	END AddObservation;

END vyScatter2.