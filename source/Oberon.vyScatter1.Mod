MODULE vyScatter1 IN Oberon;
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

(*= 	Contents	scatter plot of one variable *)
(*! rects for selection increased. drawing mode not ok? *)
(*	history:
9.8.95 md 0.0a1		alpha version
2.6..95 md 0.0d17		adapted to new structure
26.1.95 md 0.0d16		cleaned
27.10.94 md 0.0d15	adaped to the renamed vyHostDisplay & vyPictures
17.08.94 md v0r0d13	Selector defined as object in module events
08.08.94 md v0r0d0	created *)

(*!		Display of selected cases*)

IMPORT Objects, Gadgets, Display, vyHostStrings, vyHostTexts, vyBase, vyGraphBase, vyLinks, vyName, vyBooleanVec,
	vyRealVec, vyTypes, vyRectangles, vyDisplay2d, vyPort, vyHighlight, vyEvents
	(*, Out*) ;

CONST
	idversion* = "Scatter1 v0r0a3";
	cBottom = 0.25;  cTop = 0.75;   (* unselected vertical range: (0,1) *)
	cSelBottom = 0.1;  cSelTop = 0.9;   (* selected vertical range: (0,1) *)
	cMin = 0;  cMax = 1;
TYPE
	Real = vyBase.Real;  Coordinate = vyGraphBase.Coordinate;

	tLayer* = POINTER TO RECORD (vyPort.tLayerDesc) END;

VAR
	newlayer-: tLayer;

	(*	VAR  dlink: Objects.Object;*)

	PROCEDURE Recall( layer: tLayer );
	VAR i, nrData: SIGNED32;  r: Real;  sel: vyBase.tVector;  b, lastb: BOOLEAN;  lastx: Real;
	BEGIN
		IF layer.x # NIL THEN
			lastb := FALSE;  lastx := MAX( Real );  nrData := layer.x.nrData;
			sel := vyHighlight.GetSelectionAttribute( layer.highlight );

			vyGraphBase.SetDisplayMode( vyGraphBase.replace );
			FOR i := 0 TO nrData - 1 DO
				r := vyTypes.VGetR( layer.x, i );
				IF sel.nrData > i THEN b := vyBooleanVec.Get( sel, i ) ELSE b := FALSE END;   (* fof 0111 *)  (* fof 020625 *)
				IF (lastx # r) OR (lastb # b) THEN
					IF b THEN  (*? How should selected cases be displayed *)
						vyGraphBase.SetForeColor( layer.style.selectcol );  vyGraphBase.Line2d( r, cSelBottom, r, cSelTop )
					ELSE vyGraphBase.SetForeColor( layer.style.fcol );  vyGraphBase.Line2d( r, cBottom, r, cTop )
					END
				END;
				lastb := b;  lastx := r
			END
		END
	END Recall;

	PROCEDURE Copy( source, dest: tLayer );
	BEGIN
		dest^ := source^
	END Copy;

(* selection methods for the use of the Interactive.tSelector *)
	PROCEDURE Vizor( x0, y0, x1, y1: Coordinate );
	VAR x: Coordinate;
	BEGIN
		vyGraphBase.Point2dToPoint( 0, cSelBottom, x, y0 );  vyGraphBase.Point2dToPoint( 0, cSelTop, x, y1 );
		vyGraphBase.FrameRect( x0, y0 - 2, x1 - x0, y1 - y0 + 4 )
	END Vizor;

	PROCEDURE Actor( layer: vyPort.tLayer;  sel: vyBase.tVector;  x0O, y0O, x1O, y1O, x0N, y0N, x1N, y1N: Real;
								VAR changed: BOOLEAN );
	VAR scatter: tLayer;  r: Real;  nrData, i: SIGNED32;  new: BOOLEAN;
	BEGIN
		scatter := layer( tLayer );  nrData := scatter.x.nrData;
		FOR i := 0 TO nrData - 1 DO
			r := vyTypes.VGetR( scatter.x, i );
			new :=
				(x0N <= r) & (r <= x1N) & ~((x0O <= r) & (r <= x1O)) OR ~((x0N <= r) & (r <= x1N)) & (x0O <= r) & (r <= x1O);
			vyBooleanVec.Set( new, sel, i );  changed := changed OR new
		END
	END Actor;

	PROCEDURE Select( layer: tLayer;  VAR event: vyEvents.EventMsg );
	VAR selector: vyHighlight.tSelector;
	BEGIN
		vyHighlight.OpenSelector( layer, layer.x.nrData, Vizor, Actor, event );
		selector := layer.highlight( vyHighlight.tSelector );  selector.do( selector, event );  Recall( layer );
		vyBase.Update( layer )
	END Select;

	PROCEDURE Prompt( layer: tLayer;  VAR event: vyEvents.EventMsg );
	(*? should be supported as the selections *)
	CONST toleranz = 2;
	VAR found, i, nrData: SIGNED32;  r: Real;  lx, ly, x0, y0: Coordinate;  id, val: vyName.tNameArray;
	BEGIN
		found := -1;  nrData := layer.x.nrData;  id := "";
		WHILE event.gesture = vyEvents.EvtIdent DO
			FOR i := 0 TO nrData - 1 DO
				vyGraphBase.Point2dToPoint( vyTypes.VGetR( layer.x, i ), 0, x0, y0 );
				IF (i # found) & (ABS( x0 - event.x ) < toleranz) THEN
					vyGraphBase.InvertString( lx, ly, "Syntax10.Scn.Fnt", id );  found := i;  id := "(";  val := "";
					(*! label *)
					r := vyTypes.VGetR( layer.x, i );
					(*Strings.RealToStr(r,val);*)
					vyHostStrings.AppendRealFix( r, 8, 3, 0, val );   (*! improve format and propagate to other plots *)
					vyHostStrings.Append( id, val );  vyHostStrings.Append( id, ")" );
					(*
				Out.String ('vyScatter1.Prompt');Out.Int(i,6);
				Out.String(' val:' );Out.String(val); Out.String(' id:' );
				Out.String(id);Out.LongReal(r,10);Out.Ln;
				*)
					vyGraphBase.SetStringJustification( vyGraphBase.left, vyGraphBase.bottom );  lx := event.x;  ly := event.y;
					vyGraphBase.InvertString( lx, ly, "Syntax10.Scn.Fnt", id )
				END
			END;
			vyEvents.GetEvent( event )
		END;
		vyGraphBase.InvertString( lx, ly, "Syntax10.Scn.Fnt", id );  vyGraphBase.SetCursor( vyGraphBase.Crosshair );
		vyGraphBase.DrawCursor( event.x, event.y )
	END Prompt;

	PROCEDURE Responsible( layer: tLayer;  VAR event: vyEvents.EventMsg );
	VAR priority: SIGNED16;

		PROCEDURE InScatter( X, Y: Coordinate ): BOOLEAN;
		VAR xMin, xMax, yMin, yMax: Coordinate;  min, max: Real;  nans: SIGNED32;

		BEGIN
			vyTypes.VGetMinMax( layer.x, min, max, nans );  vyGraphBase.Point2dToPoint( min, cSelBottom, xMin, yMin );
			vyGraphBase.Point2dToPoint( max, cSelTop, xMax, yMax );
			RETURN vyRectangles.PointInRect( X, Y, xMin - 2 * vyGraphBase.pixel, yMin - 2 * vyGraphBase.pixel,
																   xMax - xMin + 4 * vyGraphBase.pixel, yMax - yMin + 4 * vyGraphBase.pixel )
		END InScatter;

	BEGIN
		priority := vyEvents.PrioNone;
		IF (layer.x # NIL ) & ((event.gesture = vyEvents.EvtSelect) OR (event.gesture = vyEvents.EvtIdent)) &
		    InScatter( event.x, event.y ) THEN
			priority := vyEvents.PrioNormal
		END;

		IF event.priority < priority THEN event.responder := layer;  event.priority := priority
		END
	END Responsible;

	PROCEDURE AdjustCoord( pict: vyPort.Picture;  obj: tLayer );
	VAR minX, maxX: FLOAT32;  nans: SIGNED32;
	BEGIN
		(*Out.String('vyScatter1.AdjustCoord'); OutHex(pict);Out.Ln;*)
		IF pict # NIL THEN  (*Out.String('vyScatter1.AdjustCoord pict#NIL'); Out.Ln;*)
			IF obj.x # NIL THEN vyTypes.VGetMinMaxR( obj.x, minX, maxX, nans ) ELSE minX := 0;  maxX := 1 END;
			(*	Out.String(' setting ');*)
			(*IF pict = NIL THEN Out.String(' no pict  ') ELSIF pict.gcontext = NIL THEN Out.String(' no gc  ')END;*)
			vyPort.SetNewC2d( pict, minX, cMin, maxX - minX, cMax - cMin )

		END;   (*Out.String('vyScatter1.AdjustCoord done');*)
		(*IF pict = NIL THEN Out.String(' no pict  ') ELSIF pict.gcontext = NIL THEN Out.String(' no gc  ')END;
	Out.Ln*)
	END AdjustCoord;

	PROCEDURE SetModel( pict: vyPort.Picture;  obj: tLayer;  data: Objects.Object );
	VAR id: vyName.tNameArray;
	BEGIN  (*Out.String('vyScatter1.SetModel'); Out.Ln;*)
		IF (obj.x # NIL ) THEN vyBase.UnSubscribe( obj.x, obj );  obj.x := NIL END;
		IF data = NIL THEN RETURN END;
		obj.sources := NIL;  obj.x := vyBase.GetVFromObj( data );
		IF (obj.x = NIL ) THEN vyHostTexts.Note( vyHostTexts.cWarning, "vyScatter1.SetModel: can't show these data as a scatter1" )
		ELSE
			COPY( "scatter: ", id );  vyName.AppendObjId( data( vyBase.Object ), id );  vyName.RegisterNamed( obj, id );  obj.highlight := NIL;
			vyHighlight.AdjustHighlight( obj );  vyBase.Subscribe( (*for messages from source*) obj.x, obj );
			AdjustCoord( pict, obj );  vyBase.Update( data )
		END;   (*Out.String('vyScatter1.SetModel done');
	IF pict = NIL THEN Out.String(' no pict  ') ELSIF pict.gcontext = NIL THEN Out.String(' no gc  ')END;
	Out.Ln*)
	END SetModel;

	PROCEDURE Init*( F: tLayer;  data: Objects.Object );
	VAR id: vyName.tNameArray;
	BEGIN
		F.handle := Handler;  COPY( "scatter: ", id );  F.x := vyBase.GetVFromObj( data );
		IF (F.x = NIL ) & (data # NIL ) THEN vyHostTexts.Note( vyHostTexts.cWarning, "vyScatter1: can't plot this data as a scatter: not the right type!" ) END;
		IF data # NIL THEN vyName.AppendObjId( data( vyBase.Object ), id ) END;
		vyPort.OpenLayer( F, id );
		IF F.x # NIL THEN vyHighlight.AdjustHighlight( F );

			(*vyBase.Subscribe ((*for messages from source*) vyHighlight.GetSelectionAttribute (F.highlight), F);*)
			(*	vyBase.Subscribe ((*for messages from source*) vyHighlight.GetColorAttribute (F.highlight), F);*)
			vyBase.Subscribe( (*for messages from source*) F.x, F )
		END
	END Init;

	PROCEDURE Consume( o: tLayer;  msg: Display.ConsumeMsg );
	VAR v: vyBase.tVector;  minX, maxX: FLOAT32;  pict: vyPort.Picture;  nans: SIGNED32;
	BEGIN
		pict := msg.dlink( vyPort.Picture );  v := vyBase.GetVFromObj( msg.obj );
		IF v # NIL THEN
			vyBase.UnSubscribe( o.x, o );  Init( o, msg.obj );  vyTypes.VGetMinMaxR( o.x, minX, maxX, nans );
			vyPort.SetNewC2d( pict, minX, cSelBottom, maxX - minX, cSelTop - cSelBottom );  vyBase.Update( v )
		END
	END Consume;

	PROCEDURE HandleAttributes( obj: tLayer;  VAR M: Objects.AttrMsg );
	BEGIN
		IF M.id = Objects.get THEN
			IF M.name = "Gen" THEN COPY( 'vyScatter1.New', M.s );  M.class := Objects.String;  M.res := 0 ELSE vyPort.LayerHandler( obj, M ) END
		ELSE vyPort.LayerHandler( obj, M )
		END
	END HandleAttributes;

	PROCEDURE HandleLinks( obj: tLayer;  VAR msg: Objects.LinkMsg );
	(*! handle subscribe/unsubscribe. Move to vyPort *)
	VAR pict: vyPort.Picture;
	BEGIN
		IF (msg.id = Objects.enum) THEN msg.Enum( "x" );  vyPort.LayerHandler( obj, msg )
		ELSIF (msg.id = Objects.get) & (msg.name = "x") THEN msg.obj := obj.x;  msg.res := 0
		ELSIF (msg.id = Objects.set) & ((msg.name = "x") OR (msg.name = "Model")) & (msg.obj # NIL ) & (msg.obj IS vyBase.tVector) THEN
		(*Out.String('vyScatter1.HandleLinks:Set Model'); Out.Ln;*)
			(* check proper type *)
			IF msg.dlink # NIL THEN pict := msg.dlink( vyPort.Picture ) ELSE pict := NIL END;
			(*
		vyBase.UnSubscribe(obj.x, obj);	IF msg.dlink#NIL THEN pict := msg.dlink(vyPort.Picture) END;
		Open(obj, msg.obj);
		vyTypes.VGetMinMaxR(obj.x , minX, maxX, nans);
		IF pict#NIL THEN Out.String('vyScatter1.HandleLinks:AdjustCoord'); Out.Ln;
		vyPort.SetNewC2d ( pict, minX, cBottom, maxX - minX, cTop - cBottom); END;
		vyBase.Update(msg.obj);
		*)
			SetModel( pict, obj, msg.obj );
			(*Out.String('vyScatter1.HandleLinks:Set Model done ');
		IF pict = NIL THEN Out.String(' no pict  ') ELSIF pict.gcontext = NIL THEN Out.String(' no gc  ')END;
		Out.Ln;*)
			(*	obj.x := msg.obj(vyBase.tVector);*) msg.res := 0
		ELSE vyPort.LayerHandler( obj, msg )
		END
	END HandleLinks;
(*
PROCEDURE HandleFileMsg (obj: tLayer;        VAR msg: Objects.FileMsg);
VAR pict: vyPort.Picture;
VAR   minX, maxX: FLOAT32;    	nans: SIGNED32;
VAR     objsub: Objects.Object;

BEGIN
IF msg.id = Objects.load THEN

Gadgets.ReadRef(msg.R, obj.lib, objsub);
IF (objsub # NIL) & (objsub IS vyBase.tVector) THEN  (*obj.x := objsub(vyBase.tVector)*) Init(obj,objsub)
END;
vyPort.LayerHandler (obj, msg);

(*! hack *)IF (obj.x # NIL) & (msg.dlink # NIL)  THEN pict := msg.dlink(vyPort.Picture);
IF obj # NIL THEN vyTypes.VGetMinMaxR(obj.x, minX, maxX, nans);
vyPort.SetNewC2d (pict, minX, 0, maxX - minX, 1)
ELSE (*vyHostTexts.Note(vyHostTexts.cWarning, "vyScatter1: no host picture  ")*)
END
ELSE vyHostTexts.Note(vyHostTexts.cWarning, "vyScatter1: no x obj loaded  ")
END
ELSIF msg.id = Objects.store THEN ASSERT(obj.lib=obj.x.lib,100);
Gadgets.WriteRef(msg.R, obj.lib, obj.x) ;  vyPort.LayerHandler (obj, msg)
ELSE vyPort.LayerHandler (obj, msg) END
END HandleFileMsg;
*)

	PROCEDURE HandleFileMsg( obj: tLayer;  VAR msg: Objects.FileMsg );
	VAR objsub: Objects.Object;

	BEGIN
		IF msg.id = Objects.load THEN vyPort.LayerHandler( obj, msg );

			Gadgets.ReadRef( msg.R, obj.lib, objsub );
			IF (objsub # NIL ) & (objsub IS vyBase.tVector) THEN  (*obj.x := objsub(vyBase.tVector)*)  (*Init(obj,objsub)*)
				SetModel( NIL , obj, objsub )
			END
			(*
		(*! hack *)IF (obj.x # NIL) & (msg.dlink # NIL)  THEN pict := msg.dlink(vyPort.Picture);
		IF obj # NIL THEN vyTypes.VGetMinMaxR(obj.x, minX, maxX, nans);
		vyPort.SetNewC2d (pict, minX, 0, maxX - minX, 1)
		ELSE (*vyHostTexts.Note(vyHostTexts.cWarning, "vyScatter1: no host picture  ")*)
		END
		ELSE vyHostTexts.Note(vyHostTexts.cWarning, "vyScatter1: no x obj loaded  ")
		END
		*)
		ELSIF msg.id = Objects.store THEN
			ASSERT ( obj.lib = obj.x.lib, 100 );
			vyPort.LayerHandler( obj, msg );  Gadgets.WriteRef( msg.R, obj.lib, obj.x )
		ELSE vyPort.LayerHandler( obj, msg )
		END
	END HandleFileMsg;

	PROCEDURE New*;   (* Gadgets.Insert vyScatter1.New *)
	BEGIN
		NEW( newlayer );  Init( newlayer, NIL );  Objects.NewObj := newlayer
	END New;

	PROCEDURE Handler*( obj: Objects.Object;  VAR msg: Objects.ObjMsg );
	BEGIN
		WITH obj: tLayer DO
			IF msg IS Display.DisplayMsg THEN
				WITH msg: Display.DisplayMsg DO Recall( obj );
				END;
			ELSIF msg IS vyEvents.EventMsg THEN
				WITH msg: vyEvents.EventMsg DO
				(*Out.String('vyScatter1.Handler Event '); OutHex(obj);Out.Int(msg.gesture, 3); *)
					IF msg.callForResponder THEN  (*Out.String(' Call'); *) Responsible( obj, msg );  vyPort.LayerHandler( obj, msg ) ELSE
						IF msg.gesture = vyEvents.EvtSelect THEN  (*Out.String(' Select '); *) Select( obj, msg )
						ELSIF msg.gesture = vyEvents.EvtIdent THEN  (*Out.String(' Prompt '); *) Prompt( obj, msg )
						END
					END;
					(*Out.Ln;*)

				END;
			ELSIF msg IS Objects.CopyMsg THEN
				WITH msg: Objects.CopyMsg DO
					New;  msg.obj := newlayer;  vyPort.LayerHandler( obj, msg );  Copy( obj, msg.obj( tLayer ) );
					(*IF msg.stamp = obj.stamp THEN msg.obj := obj.dlink ELSE
			msg.stamp := obj.stamp; NEW(copy);     msg.obj := copy;     vyPort.LayerHandler (obj, msg);
			Copy (obj, msg.obj(tLayer));     obj.dlink := copy
			END;*)
				END;
			ELSIF msg IS Objects.FileMsg THEN
				WITH msg: Objects.FileMsg DO HandleFileMsg( obj, msg )
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
			ELSIF msg IS vyPort.AdjustCoordMsg THEN
				WITH msg: vyPort.AdjustCoordMsg DO AdjustCoord( msg.pict, msg.layer( tLayer ) )
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
		(* Out.String('vyScatter1.XNewPict done'); IF pict.gcontext#NIL THEN Out.String(' w.context');END; Out.Ln; *)
	END NewPict;

	PROCEDURE NewFrame*;   (* Gadgets.Insert vyScatter1.NewFrame *)
	VAR pict: vyPort.Picture;  F: vyPort.Frame;
	BEGIN
		NewPict;  pict := Objects.NewObj( vyPort.Picture );  vyPort.NewFrame;  F := Objects.NewObj( vyPort.Frame );
		vyPort.AddPicture( F, pict, 0, 0, 1, 1 )
	END NewFrame;

	PROCEDURE ShowO*( obj: Objects.Object );
	VAR minX, maxX: FLOAT32;  nans: SIGNED32;  pict: vyPort.Picture;
	BEGIN
		New;  Init( newlayer, obj );  vyTypes.VGetMinMaxR( newlayer.x, minX, maxX, nans );
		pict := vyPort.InsertNewCPicture( 0, 0, 1, 1, vyDisplay2d.NewC2d( minX, cMin, maxX - minX, cMax - cMin ) );
		vyPort.AddLayer( pict, newlayer );  Objects.NewObj := pict
	END ShowO;

	PROCEDURE ShowP*;
	VAR data: Objects.Object;
	BEGIN
		data := vyBase.NextParObj();
		WHILE data # NIL DO ShowO( data );  data := vyBase.NextParObj() END
	END ShowP;

	PROCEDURE ShowL*( list: vyLinks.Link );
	BEGIN
		WHILE list # NIL DO ShowO( list.obj );  list := list.link END
	END ShowL;

	PROCEDURE AddObservation*( x: Real;  layer: tLayer );
	(*! up to now not tested *)
	BEGIN
		vyRealVec.Append( x, layer.x );  vyGraphBase.Line2d( x, cBottom, x, cTop )
	END AddObservation;

END vyScatter1.

System.Free vyScatter1 * ~
Gadgets.Insert RefFrame vyScatter1.New ~
Gadgets.Insert RefFrame vyScatter1.New ~
Gadgets.Insert Button vyScatter1.New ~
Gadgets.Insert Button BasicGadgets.NewBoolean ~
Gadgets.Insert RefFrame BasicGadgets.NewBoolean ~
Gadgets.Insert vyScatter1.NewPict ~
Gadgets.Insert vyScatter1.NewPict dbgTestVec.LRConstVec128~
Gadgets.Insert vyScatter1.NewPict dbgTestVec.RConstVec128~
Gadgets.Insert vyScatter1.NewPict dbgTestVec.RRndmVec128~

vyGraphBase.ToggleDBActive ~
Gadgets.Insert vyScatter1.XNewPict dbgTestVec.LRConstVec128~
