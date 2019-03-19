MODULE vyScatter3 IN Oberon;
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
(*= 	Contents	Generic voyager module: scatter plot of three variables*)

(*	history:
9.8.95 md 0.0a1		alpha version
16.2.95 md 0.0d3
26.1.95 md 0.0d2		cleaned
28.11.94 md v0r0d0	created *)
IMPORT Gadgets, Objects, Display, vyHostStrings, vyHostTexts, vyBase, vyGraphBase, vyLinks, vyName, vyBooleanVec,
	vyTypes, vyPHIGS3D, vyPaint3d, Attributes, vyPort, vyLayers3d, vyHighlight, vyEvents;

CONST
	idversion* = "vyScatter3 v0r0a2";

TYPE
	Real = vyBase.Real;  Coordinate = vyGraphBase.Coordinate;
	tLayer* = POINTER TO tLayerDesc;
	tLayerDesc = RECORD (vyLayers3d.tLayerDesc) END;

VAR
	slink*, dlink*: Objects.Object;  newlayer-: tLayer;

	PROCEDURE New*;
	BEGIN
		NEW( newlayer );  newlayer.handle := Handler;  Init( newlayer, NIL );  Objects.NewObj := newlayer
	END New;

	PROCEDURE Copy( source, dest: tLayer );   (* FOF inserted *)
	BEGIN
		dest^ := source^
	END Copy;

	PROCEDURE Recall( scatter: tLayer );
	VAR i: LONGINT;  nrData: LONGINT;  sel: vyBase.tVector;  error: INTEGER;  xx, yy: Coordinate;  lastx, lasty: Coordinate;  b, lastb: BOOLEAN;  boxed: BOOLEAN;
	BEGIN
		lastx := MAX( Coordinate );  nrData := scatter.x.nrData;
		IF scatter.highlight = NIL THEN vyHighlight.AdjustHighlight( scatter ) END;
		sel := vyHighlight.GetSelectionAttribute( scatter.highlight );
		(* col := vyHighlight.GetColorAttribute (nrData);
	dsgn := vyHighlight.GetDesignAttribute (nrData);
	vyGraphBase.SetPatternJustification (vyGraphBase.center, vyGraphBase.center);
	dsg := scatter.dsg; sgn := dsg.sgn0;
	*)
		FOR i := 0 TO nrData - 1 DO
		(*
		IF vyTypes.VGetB (sel, i) THEN sgn := dsg.sgn1 ELSE sgn := dsg.sgn0 END;
		color := SHORT (ENTIER (vyTypes.VGetR(col, i)));
		color := scatter.style.fcol; (* fof 971202 *)
		vyPaint3d.PaintColPat (
		vyTypes.VGetR (scatter.x, i), vyTypes.VGetR (scatter.y, i),
		vyTypes.VGetR (scatter.z, i), color, sgn)
		*)
			vyPHIGS3D.PointToDisplayPoint( vyTypes.VGetR( scatter.x, i ), vyTypes.VGetR( scatter.y, i ),
																 vyTypes.VGetR( scatter.z, i ), error, xx, yy );
			IF sel.nrData > i THEN b := vyBooleanVec.Get( sel, i ) ELSE b := FALSE END;

			IF (xx # lastx) OR (yy # lasty) OR (lastb # b) THEN
				IF b THEN
					vyGraphBase.SetForeColor( scatter.style.selectcol );  vyGraphBase.FrameCircle( xx, yy, 2 * vyGraphBase.pixel )
				ELSE
					vyGraphBase.SetForeColor( scatter.style.fcol );
					vyGraphBase.PaintRect( xx - 1 * vyGraphBase.pixel, yy, 3 * vyGraphBase.pixel, 1 * vyGraphBase.pixel );
					vyGraphBase.PaintRect( xx, yy - 1 * vyGraphBase.pixel, 1 * vyGraphBase.pixel, 3 * vyGraphBase.pixel )
				END
			END;
			lastx := xx;  lasty := yy;

			Attributes.GetBool( scatter, "boxed", boxed );
			IF boxed THEN
				vyPaint3d.Line( 0, 0, 0, 0, 0, 1 );  vyPaint3d.Line( 0, 0, 0, 0, 1, 0 );  vyPaint3d.Line( 0, 0, 0, 1, 0, 0 );
				vyPaint3d.Line( 0, 0, 1, 1, 0, 1 );  vyPaint3d.Line( 0, 0, 1, 0, 1, 1 );  vyPaint3d.Line( 0, 1, 0, 0, 1, 1 );
				vyPaint3d.Line( 0, 1, 0, 1, 1, 0 );  vyPaint3d.Line( 1, 0, 0, 1, 0, 1 );  vyPaint3d.Line( 1, 0, 0, 1, 1, 0 );
				vyPaint3d.Line( 1, 1, 0, 1, 1, 1 );  vyPaint3d.Line( 1, 0, 1, 1, 1, 1 );  vyPaint3d.Line( 0, 1, 1, 1, 1, 1 )
			END

		END
	END Recall;

	PROCEDURE HandleAttributes( obj: tLayer;  VAR M: Objects.AttrMsg );
	BEGIN
		IF M.id = Objects.get THEN
			IF M.name = "Gen" THEN COPY( 'vyScatter3.New', M.s );  M.class := Objects.String;  M.res := 0 ELSE vyPort.LayerHandler( obj, M ) END
		ELSE vyPort.LayerHandler( obj, M )
		END
	END HandleAttributes;

	PROCEDURE HandleLinks( obj: tLayer;  VAR msg: Objects.LinkMsg );
	(*! handle subscribe/unsubscribe. Move to vyPort *)
	BEGIN
		IF (msg.id = Objects.enum) THEN
			vyPort.LayerHandler( obj, msg );  msg.Enum( "x" );  msg.Enum( "y" );  msg.Enum( "z" );  msg.res := 0
		ELSIF msg.id = Objects.get THEN
			IF msg.name = "x" THEN msg.obj := obj.x
			ELSIF msg.name = "y" THEN msg.obj := obj.y
			ELSIF msg.name = "z" THEN msg.obj := obj.z
			ELSE vyPort.LayerHandler( obj, msg )
			END;
			msg.res := 0
		ELSIF msg.id = Objects.set THEN
			IF (msg.name = "x") & (msg.obj # NIL ) & (msg.obj IS vyBase.tVector) THEN
				(* check proper type *)
				obj.x := msg.obj( vyBase.tVector )
			ELSIF (msg.name = "y") & (msg.obj # NIL ) & (msg.obj IS vyBase.tVector) THEN obj.y := msg.obj( vyBase.tVector )
			ELSIF (msg.name = "z") & (msg.obj # NIL ) & (msg.obj IS vyBase.tVector) THEN obj.z := msg.obj( vyBase.tVector )
			ELSE vyPort.LayerHandler( obj, msg )
			END;
			msg.res := 0
		ELSE vyPort.LayerHandler( obj, msg )
		END
	END HandleLinks;

	PROCEDURE Store0( obj: tLayer;  VAR M: Objects.FileMsg );
	BEGIN
		Gadgets.WriteRef( M.R, obj.lib, obj.x );  Gadgets.WriteRef( M.R, obj.lib, obj.y );  Gadgets.WriteRef( M.R, obj.lib, obj.z )
	END Store0;

	PROCEDURE Load0( obj: tLayer;  VAR M: Objects.FileMsg );
	VAR objsub: Objects.Object;
	BEGIN
		dlink := M.dlink;  Gadgets.ReadRef( M.R, obj.lib, objsub );
		IF (objsub # NIL ) & (objsub IS vyBase.tVector) THEN obj.x := objsub( vyBase.tVector ) END;
		Gadgets.ReadRef( M.R, obj.lib, objsub );
		IF (objsub # NIL ) & (objsub IS vyBase.tVector) THEN obj.y := objsub( vyBase.tVector ) END;
		Gadgets.ReadRef( M.R, obj.lib, objsub );
		IF (objsub # NIL ) & (objsub IS vyBase.tVector) THEN obj.z := objsub( vyBase.tVector ) END
	END Load0;

(* selection methods for the use of the Interactive.tSelector *)
	PROCEDURE Vizor( x0, y0, x1, y1: Coordinate );
	BEGIN
		vyGraphBase.FrameRect( x0, y0, x1 - x0, y1 - y0 )
	END Vizor;

	PROCEDURE Actor( layer: vyPort.tLayer;  sel: vyBase.tVector;  x0O, y0O, x1O, y1O, x0N, y0N, x1N, y1N: Real;
								VAR somethingChanged: BOOLEAN );
	(*vs 0.0a1	md  16.08.94 *)
	VAR scatter: tLayer;  error: INTEGER;  nrData, i: LONGINT;  new: BOOLEAN;  X, Y, Z, vx, vy, vz: Real;

		PROCEDURE PointInRect( x, y, x0, y0, x1, y1: Real ): BOOLEAN;
		BEGIN
			RETURN (x0 <= x) & (x <= x1) & (y0 <= y) & (y <= y1)
		END PointInRect;

	BEGIN
		scatter := layer( tLayer );  nrData := scatter.x.nrData;
		FOR i := 0 TO nrData - 1 DO
			X := vyTypes.VGetR( scatter.x, i );  Y := vyTypes.VGetR( scatter.y, i );  Z := vyTypes.VGetR( scatter.z, i );
			vyPHIGS3D.PointToViewPoint( X, Y, Z, error, vx, vy, vz );
			new :=
				(PointInRect( vx, vy, x0N, y0N, x1N, y1N ) & ~PointInRect( vx, vy, x0O, y0O, x1O, y1O )) OR
				(~PointInRect( vx, vy, x0N, y0N, x1N, y1N ) & PointInRect( vx, vy, x0O, y0O, x1O, y1O ));
			vyBooleanVec.Set( new, sel, i );  somethingChanged := somethingChanged OR new
		END

	END Actor;

	PROCEDURE Select( layer: tLayer;  VAR event: vyEvents.EventMsg );
	VAR selector: vyHighlight.tSelector;
	BEGIN
		vyHighlight.OpenSelector( layer, layer.x.nrData, Vizor, Actor, event );
		selector := layer.highlight( vyHighlight.tSelector );  selector.do( selector, event );  Recall( layer );
		vyBase.Update( layer )
	END Select;

	PROCEDURE Prompt( scatter: tLayer;  VAR event: vyEvents.EventMsg );
	(*? should be supported as the selections with an abstract identifier *)
	(*vs 0.0a1 *)  (* md  04.06.95 *)
	CONST toleranz = 2;
	VAR found, i, nrData: LONGINT;  r: Real;  error: INTEGER;  lx, ly, x0, y0: Coordinate;  id, val: vyName.tNameArray;
	BEGIN
		found := -1;  nrData := scatter.x.nrData;  id := "";
		WHILE event.gesture = vyEvents.EvtIdent DO
			FOR i := 0 TO nrData - 1 DO
				vyPHIGS3D.PointToDisplayPoint( vyTypes.VGetR( scatter.x, i ), vyTypes.VGetR( scatter.y, i ),
																	 vyTypes.VGetR( scatter.z, i ), error, x0, y0 );
				IF (i # found) & (ABS( x0 - event.x ) + ABS( y0 - event.y ) < toleranz) THEN
					vyGraphBase.InvertString( lx, ly, "Syntax10.Scn.Fnt", id );  found := i;  id := "(";  val := "";
					(*! label *)
					r := vyTypes.VGetR( scatter.x, i );  vyHostStrings.AppendRealFix( r, 4, 2, 5, val );
					vyHostStrings.Append( id, val );  vyHostStrings.Append( id, ", " );

					val := "";  r := vyTypes.VGetR( scatter.y, i );  vyHostStrings.AppendRealFix( r, 4, 2, 5, val );
					vyHostStrings.Append( id, val );  vyHostStrings.Append( id, ", " );  val := "";  r := vyTypes.VGetR( scatter.z, i );
					vyHostStrings.AppendRealFix( r, 4, 2, 5, val );  vyHostStrings.Append( id, val );  vyHostStrings.Append( id, ")" );
					vyGraphBase.SetStringJustification( vyGraphBase.left, vyGraphBase.bottom );  lx := event.x;  ly := event.y;
					vyGraphBase.InvertString( lx, ly, "Syntax10.Scn.Fnt", id )
				END
			END;
			vyEvents.GetEvent( event )
		END;
		vyGraphBase.InvertString( lx, ly, "Syntax10.Scn.Fnt", id );  vyGraphBase.SetCursor( vyGraphBase.Crosshair );
		vyGraphBase.DrawCursor( event.x, event.y )
	END Prompt;

	PROCEDURE Responsible( scatter: tLayer;  VAR event: vyEvents.EventMsg );
	VAR priority: INTEGER;

		PROCEDURE InScatter( x, y: Coordinate ): BOOLEAN;
		(*! not yet implemented *)
		BEGIN
			RETURN TRUE
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
	VAR v, w, z: vyBase.tVector;  minX, maxX, minY, maxY, minZ, maxZ: Real;  data: Objects.Object;
		c: vyLayers3d.tCoordinate3d;  pict: vyPort.Picture;  nans: LONGINT;

	BEGIN
		pict := msg.dlink( vyPort.Picture );  data := msg.obj;  v := vyBase.GetVFromObj( data );
		IF v = NIL THEN RETURN END;
		data := data.slink;
		IF data = NIL THEN RETURN END;
		w := vyBase.GetVFromObj( data );
		IF w = NIL THEN RETURN END;
		data := data.slink;
		IF data = NIL THEN RETURN END;
		z := vyBase.GetVFromObj( data );
		IF z = NIL THEN RETURN END;

		IF (v # NIL ) & (w # NIL ) & (z # NIL ) THEN
			Init( o, msg.obj );  vyTypes.VGetMinMax( o.x, minX, maxX, nans );  vyTypes.VGetMinMax( o.y, minY, maxY, nans );
			vyTypes.VGetMinMax( o.z, minZ, maxZ, nans );
			IF ((maxX - minX) > 1 / MAX( LONGINT )) & ((maxY - minY) > 1 / MAX( LONGINT )) & ((maxZ - minZ) > 1 / MAX( LONGINT )) THEN

				NEW( c );  vyLayers3d.OpenC3d( c );  pict.gcontext := c
			END;
			vyBase.Subscribe( (*for messages from source*) c, pict );

			vyBase.Update( v )
		END
	END Consume;

	PROCEDURE Handler*( obj: Objects.Object;  VAR msg: Objects.ObjMsg );
	(*vs 0.0a1	md  08.08.94 *)
	BEGIN
		WITH obj: tLayer DO
			IF msg IS Display.DisplayMsg THEN
				WITH msg: Display.DisplayMsg DO Recall( obj );
				END;
			ELSIF msg IS Objects.CopyMsg THEN
				WITH msg: Objects.CopyMsg DO
					New;  msg.obj := newlayer;  vyPort.LayerHandler( obj, msg );  Copy( obj, newlayer );
				END;
			ELSIF msg IS vyEvents.EventMsg THEN
				WITH msg: vyEvents.EventMsg DO
					IF msg.callForResponder THEN Responsible( obj, msg ) ELSE
						IF msg.gesture = vyEvents.EvtSelect THEN Select( obj, msg )
						ELSIF msg.gesture = vyEvents.EvtIdent THEN Prompt( obj, msg )
						END
					END;
				END;
			ELSIF msg IS Objects.FileMsg THEN
				WITH msg: Objects.FileMsg DO
					IF msg.id = Objects.load THEN
						vyPort.LayerHandler( obj, msg );  Load0( obj, msg );   (* fof 0111 changed ordering *)
						(*
				(*! hack *) IF ((obj.x#NIL) & (obj.y # NIL) & (obj.z # NIL)) THEN
				pict:=msg.dlink(vyPort.Picture);
				IF pict#NIL THEN
				vyTypes.VGetMinMax(obj.x , minX, maxX, nans);
				vyTypes.VGetMinMax(obj.y , minY, maxY, nans);
				vyTypes.VGetMinMax(obj.z , minZ, maxZ, nans);
				NEW (c);    vyLayers3d.OpenC3d (c)
				ELSE (*vyHostTexts.Note(vyHostTexts.cWarning,"vyScatter3: no host picture  ")*)
				END
				ELSE vyHostTexts.Note(vyHostTexts.cWarning,"vyScatter3: no x obj loaded  ")
				END
				*)
					ELSIF msg.id = Objects.store THEN vyPort.LayerHandler( obj, msg );  Store0( obj, msg )
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
					IF obj.y # NIL THEN Gadgets.BindObj( obj.y, msg.lib ) END;
					IF obj.z # NIL THEN Gadgets.BindObj( obj.z, msg.lib ) END
				END;
			ELSE vyPort.LayerHandler( obj, msg )
			END
		END
	END Handler;

	PROCEDURE Init*( F: tLayer;  data: Objects.Object );
	VAR id: vyName.tNameArray;  inconsistentConditions: BOOLEAN;
	BEGIN
		COPY( "scatter3: ", id );

		IF data # NIL THEN
			F.x := vyBase.GetVFromObj( data );  data := data.slink;  F.y := vyBase.GetVFromObj( data );  data := data.slink;
			F.z := vyBase.GetVFromObj( data );
			IF (F.x = NIL ) OR (F.y = NIL ) OR (F.z = NIL ) THEN vyHostTexts.Msg( "can't plot this data as a scatter plot: not the right type!" );  inconsistentConditions := TRUE;
				ASSERT ( ~inconsistentConditions )
			ELSIF (F.x.nrData # F.y.nrData) OR (F.y.nrData # F.z.nrData) THEN
				vyHostTexts.Msg( "can't plot this data as a scatter plot: not the same length!" );  inconsistentConditions := TRUE;
				ASSERT ( ~inconsistentConditions )
			END;

			vyName.AppendObjId( F.x, id );  vyHostStrings.Append( id, " by " );  vyName.AppendObjId( F.y, id );
			vyHostStrings.Append( id, " by " );  vyName.AppendObjId( F.z, id );

			(*	F.dsg := vyPatterns.circle; 	(**! md changed for workshop 23.3.95*) *)
			(*vyHighlight.SubscribeSelector (F.x.nrData, F);*)
			vyBase.Subscribe( (*for messages from source*) F.x, F );  vyBase.Subscribe( (*for messages from source*) F.y, F );
			vyBase.Subscribe( (*for messages from source*) F.z, F )
			(* F.style.selectcol := F.style.fcol *)
		END;
		vyLayers3d.Open( F, id );  Attributes.SetBool( F, "boxed", FALSE )
	END Init;

	PROCEDURE OpenO*( F: tLayer;  x, y, z: Objects.Object );
	VAR id: vyName.tNameArray;  inconsistentConditions: BOOLEAN;
	BEGIN
		F.x := vyBase.GetVFromObj( x );  F.y := vyBase.GetVFromObj( y );  F.z := vyBase.GetVFromObj( z );
		IF (F.x = NIL ) OR (F.y = NIL ) OR (F.z = NIL ) THEN vyHostTexts.Msg( "can't plot this data as a scatter plot: not the right type!" );  inconsistentConditions := TRUE;
			ASSERT ( ~inconsistentConditions )
		ELSIF (F.x.nrData # F.y.nrData) OR (F.y.nrData # F.z.nrData) THEN vyHostTexts.Msg( "can't plot this data as a scatter plot: not the same length!" );  inconsistentConditions := TRUE;
			ASSERT ( ~inconsistentConditions )
		END;
		COPY( "scatter: ", id );  vyName.AppendObjId( F.x, id );  vyHostStrings.Append( id, " by " );  vyName.AppendObjId( F.y, id );
		vyHostStrings.Append( id, " by " );  vyName.AppendObjId( F.z, id );  vyLayers3d.Open( F, id );
		(*	vyHighlight.SubscribeSelector (F.x.nrData, F);*)
		vyBase.Subscribe( (*for messages from source*) F.x, F );  vyBase.Subscribe( (*for messages from source*) F.y, F );
		vyBase.Subscribe( (*for messages from source*) F.z, F )
	END OpenO;

	PROCEDURE OpenL*( F: tLayer;  list: vyLinks.Link );
	VAR x, y, z: Objects.Object;
	BEGIN
		x := list.obj;  list := list.link;  y := list.obj;  list := list.link;  z := list.obj;  OpenO( F, x, y, z )
	END OpenL;

	PROCEDURE ShowP*;
	VAR data: Objects.Object;  F: tLayer;  c: vyLayers3d.tCoordinate3d;  pict: vyPort.Picture;
		minX, maxX, minY, maxY, minZ, maxZ: Real;  nans: LONGINT;
	BEGIN
		data := vyBase.NextParObj();
		WHILE (data # NIL ) & (vyBase.parameterCount > 1) DO
			data.slink := vyBase.NextParObj();  data.slink.slink := vyBase.NextParObj();  New;  F := newlayer;  Init( F, data );
			vyTypes.VGetMinMax( F.x, minX, maxX, nans );  vyTypes.VGetMinMax( F.y, minY, maxY, nans );
			vyTypes.VGetMinMax( F.z, minZ, maxZ, nans );  NEW( c );  vyLayers3d.OpenC3d( c );
			pict := vyPort.InsertNewCPicture( 0, 0, 1, 1, c );  vyPort.AddLayer( pict, F );  data := vyBase.NextParObj();
			Objects.NewObj := pict
		END
	END ShowP;

	PROCEDURE ShowL*( list: vyLinks.Link );
	VAR c: vyLayers3d.tCoordinate3d;  pict: vyPort.Picture;  minX, maxX, minY, maxY, minZ, maxZ: Real;  nans: LONGINT;  i: INTEGER;
	BEGIN
		WHILE list # NIL DO New;

			OpenL( newlayer, list );  vyTypes.VGetMinMax( newlayer.x, minX, maxX, nans );
			vyTypes.VGetMinMax( newlayer.y, minY, maxY, nans );  vyTypes.VGetMinMax( newlayer.z, minZ, maxZ, nans );  NEW( c );
			vyLayers3d.OpenC3d( c );  pict := vyPort.InsertNewCPicture( 0, 0, 1, 1, c );  vyPort.AddLayer( pict, newlayer );
			FOR i := 1 TO 3 DO
				IF list # NIL THEN
					IF list.link = NIL THEN list := NIL ELSE list := list.link END
				END
			END;
			Objects.NewObj := pict
		END
	END ShowL;

	PROCEDURE ShowO*( x, y, z: Objects.Object );
	VAR c: vyLayers3d.tCoordinate3d;  pict: vyPort.Picture;  minX, maxX, minY, maxY, minZ, maxZ: Real;  nans: LONGINT;
	BEGIN
		New;  OpenO( newlayer, x, y, z );  vyTypes.VGetMinMax( newlayer.x, minX, maxX, nans );
		vyTypes.VGetMinMax( newlayer.y, minY, maxY, nans );  vyTypes.VGetMinMax( newlayer.z, minZ, maxZ, nans );  NEW( c );
		vyLayers3d.OpenC3d( c );  pict := vyPort.InsertNewCPicture( 0, 0, 1, 1, c );  vyPort.AddLayer( pict, newlayer );
		Objects.NewObj := pict
	END ShowO;

END vyScatter3.