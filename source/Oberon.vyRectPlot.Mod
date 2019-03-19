MODULE vyRectPlot IN Oberon;   (** jb  **)
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


(* 11.1.01 by Johannes Becker *)
IMPORT vyXPValues, G := vyGraphBase, S := vyHostStrings, vyPort, vyName, vyBase, vyDisplay2d, Display, Objects, Files, Gadgets;

TYPE
	tLayer* = POINTER TO tLayerDesc;
	tLayerDesc* = RECORD (vyPort.tLayerDesc)
		passConsume: BOOLEAN;
		xp-: vyXPValues.XPValue
	END;

	PROCEDURE Redraw( layer: tLayer );
	CONST fontname = "Syntax16m.Scn.Fnt";
	VAR s: ARRAY 32 OF CHAR;
	BEGIN
		G.SetDisplayMode( G.replace );  G.SetStringJustification( G.left, G.center );

		G.SetForeColor( layer.style.selectcol );  G.PaintRect2d( 0, 1, 1, layer.xp.p.x );  G.SetForeColor( layer.style.fcol );
		G.FrameRect2d( 0, 1, 1, 1 );

		s := "T~";  S.Append( s, layer.xp.distrName );  S.Append( s, ": " );  G.String2d( 0.1, 1.9, fontname, s );

		G.SetStringJustification( G.center, G.center );  s := "";  S.RealToFixStr( layer.xp.x.x, s, 6, 3, 0 );
		G.String2d( 0.5, 1.7, fontname, s );

		G.SetStringJustification( G.left, G.center );  s := "P(X<=T):";  G.String2d( 0.1, 1.5, fontname, s );

		G.SetStringJustification( G.left, G.center );  s := "";  S.RealToFixStr( layer.xp.p.x, s, 6, 3, 0 );
		G.String2d( 0.5, 1.3, fontname, s )
	END Redraw;

	PROCEDURE Consume( layer: tLayer;  msg: Display.ConsumeMsg );
	VAR xp: vyXPValues.XPValue;  accepted: BOOLEAN;
	BEGIN
		xp := layer.xp;
		IF layer.passConsume THEN
			WITH xp: vyXPValues.ActiveXPValue DO xp.TakeNewSource( msg.obj, accepted );  xp.NewData
			END
		ELSE
			vyBase.UnSubscribe( layer.xp, layer );  vyBase.UnSubscribe( layer.xp.p, layer );  layer.xp := xp;
			vyBase.Subscribe( xp, layer );  vyBase.Subscribe( xp.p, layer );  vyBase.Update( layer )
		END
	END Consume;

	PROCEDURE Load0( VAR r: Files.Rider;  VAR v: tLayerDesc );
	VAR objsub: Objects.Object;
	BEGIN
		Files.ReadBool( r, v.passConsume );  Gadgets.ReadRef( r, v.lib, objsub );
		IF (objsub # NIL ) THEN
			WITH objsub: vyXPValues.XPValue DO v.xp := objsub
			END
		ELSE HALT( 100 )
		END
	END Load0;

	PROCEDURE Store0( VAR r: Files.Rider;  VAR v: tLayerDesc );
	BEGIN
		Files.WriteBool( r, v.passConsume );  Gadgets.WriteRef( r, v.lib, v.xp )
	END Store0;

	PROCEDURE Handler*( obj: Objects.Object;  VAR msg: Objects.ObjMsg );
	VAR layer: tLayer;
	BEGIN
		IF obj IS tLayer THEN
			WITH obj: tLayer DO layer := obj
			END;
		ELSE HALT( 100 )
		END;

		IF msg IS Display.DisplayMsg THEN
			WITH msg: Display.DisplayMsg DO Redraw( layer )
			END;
		ELSIF msg IS Objects.FileMsg THEN
			WITH msg: Objects.FileMsg DO
				IF msg.id = Objects.load THEN Load0( msg.R, layer^ );  vyPort.LayerHandler( obj, msg )
				ELSIF msg.id = Objects.store THEN Store0( msg.R, layer^ );  vyPort.LayerHandler( obj, msg )
				ELSE vyPort.LayerHandler( obj, msg )
				END
			END;
		ELSIF msg IS Objects.AttrMsg THEN
			WITH msg: Objects.AttrMsg DO
				IF msg.id = Objects.get THEN
					IF msg.name = "Gen" THEN msg.s := "vyRectPlot.Alloc";  msg.class := Objects.String;  msg.res := 0 ELSE vyPort.LayerHandler( obj, msg ) END
				ELSE vyPort.LayerHandler( obj, msg )
				END
			END;
		ELSE vyPort.LayerHandler( obj, msg )
		END
	END Handler;

	PROCEDURE DoOpen*( layer: tLayer;  data: vyXPValues.XPValue;  VAR layerid: ARRAY OF CHAR;  passConsume: BOOLEAN );
	(* Handler should be set before calling this procedure *)
	BEGIN
		vyPort.OpenLayer( layer, layerid );  layer.xp := data;  layer.passConsume := passConsume;
		vyBase.Subscribe( layer.xp, layer );  vyBase.Subscribe( layer.xp.p, layer )
	END DoOpen;

	PROCEDURE Open*( layer: tLayer;  data: Objects.Object );
	VAR layerid: vyName.tNameArray;
	BEGIN
		ASSERT ( layer # NIL , 100 );
		ASSERT ( data # NIL , 101 );

		WITH data: vyXPValues.XPValue DO
			layer.handle := Handler;  layerid := "rectp: ";  vyName.AppendObjId( data, layerid );  DoOpen( layer, data, layerid, FALSE )
		END
	END Open;

	PROCEDURE ShowP*;
	VAR data: Objects.Object;  layer: tLayer;
	BEGIN
		data := vyBase.NextParObj();
		WHILE data # NIL DO
			NEW( layer );  Open( layer, data );
			vyPort.AddLayer( vyPort.InsertNewCPicture( 0, 0, 1, 1, vyDisplay2d.NewC2d( 0, 1, 1, 1 ) ), layer );
			data := vyBase.NextParObj()
		END
	END ShowP;

	PROCEDURE New*;
	VAR layer: tLayer;  data: Objects.Object;
	BEGIN
		IF Objects.NewObj = NIL THEN RETURN END;
		data := Objects.NewObj;  NEW( layer );  Open( layer, data );  Objects.NewObj := layer
	END New;

	PROCEDURE Alloc*;
	VAR layer: tLayer;
	BEGIN
		NEW( layer );  layer.handle := Handler;  Objects.NewObj := layer
	END Alloc;

END vyRectPlot.
