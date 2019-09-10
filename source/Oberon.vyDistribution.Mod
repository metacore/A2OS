MODULE vyDistribution IN Oberon;
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
(*= Distribution plot. This plot has no interactive capabilities*)
(*	history:
5.12.00 jb 			unmapped memory trap when loading fixed
16.2.00 gs 0.0a4	S3 adaptation
9.8.95 md 0.0a1	alpha version
27.10.94 md 0.0d3	adaped to the renamed vyDisplay & vyPictures
10.08.94 md 0.0d0	created *)

(*!	what about more then one distribution plot in one picture?
the sorting algorithm in the recall routine works on the original data *)

IMPORT Objects, Display, vyHostTexts, vyBase, vyLinks, vyTypes, vyName, vyDisplay2d, vyPort, Gadgets, vyGraphBase;

CONST
	idversion* = "vyDistribution v0r0a4";  cMin = 0;  cMax = 1;

TYPE
	tLayer* = POINTER TO tLayerDesc;
	tLayerDesc* = RECORD (vyPort.tLayerDesc) END;

VAR
	slink*, dlink*: Objects.Object;  newlayer-: tLayer;

(*PROCEDURE^ Alloc*;*)

	PROCEDURE Recall( F: tLayer );   (*vs 0.0a2	gs/fof  6.9.95 *)
	VAR count, dataPoint: SIGNED32;  xp, yp: FLOAT32;
	BEGIN
		IF F.x # NIL THEN
			count := F.x.nrData;
			(*! sort should work on a copy of the data *)
			vyTypes.Sort( F.x );

			vyGraphBase.SetDisplayMode( vyGraphBase.replace );

			yp := 0;  vyGraphBase.MoveTo2d( 0, yp );
			FOR dataPoint := 0 TO count - 1 DO
				xp := vyTypes.VGetR( F.x, dataPoint );  vyGraphBase.LineTo2d( xp, yp );  yp := (dataPoint / count);
				vyGraphBase.MoveTo2d( xp, yp )
			END;   (*FOR*)
		ELSE
			(*! erase old layer*)
			vyHostTexts.Note( vyHostTexts.cWarning, "vyDistribution: no data for distribution plot" )
		END
	END Recall;

	PROCEDURE Copy( source, dest: tLayer );   (* FOF inserted *)
	BEGIN
		dest^ := source^
	END Copy;

	PROCEDURE Consume( o: tLayer;  msg: Display.ConsumeMsg );
	VAR v: vyBase.tVector;  minX, maxX: FLOAT32;  pict: vyPort.Picture;  nans: SIGNED32;

	BEGIN
		pict := msg.dlink( vyPort.Picture );  v := vyBase.GetVFromObj( msg.obj );
		IF v # NIL THEN vyBase.UnSubscribe( (*for messages from source*) o.x, o );

			Init( o, msg.obj );  vyTypes.VGetMinMaxR( o.x, minX, maxX, nans );
			vyPort.SetNewC2d( pict, minX, 0, maxX - minX, 1 );

			vyBase.Update( v )
		END
	END Consume;

	PROCEDURE HandleAttributes( obj: tLayer;  VAR M: Objects.AttrMsg );
	BEGIN
		IF M.id = Objects.get THEN
			IF M.name = "Gen" THEN
				COPY( 'vyDistribution.Alloc', M.s );   (* Alloc instead of New - jb 22.11.00 *)
				M.class := Objects.String;  M.res := 0
			ELSE vyPort.LayerHandler( obj, M )
			END
		ELSE vyPort.LayerHandler( obj, M )
		END
	END HandleAttributes;

	PROCEDURE AdjustCoord( pict: vyPort.Picture;  obj: tLayer );
	VAR minX, maxX: FLOAT32;  nans: SIGNED32;
	BEGIN
		IF pict # NIL THEN
			IF obj.x # NIL THEN vyTypes.VGetMinMaxR( obj.x, minX, maxX, nans ) ELSE minX := 0;  maxX := 1 END;
			vyPort.SetNewC2d( pict, minX, cMin, maxX - minX, cMax - cMin )
		END
	END AdjustCoord;

	PROCEDURE SetModel( pict: vyPort.Picture;  obj: tLayer;  data: Objects.Object );
	VAR id: vyName.tNameArray;
	BEGIN
		IF (obj.x # NIL ) THEN vyBase.UnSubscribe( obj.x, obj );  obj.x := NIL END;
		IF data = NIL THEN RETURN END;
		obj.sources := NIL;  obj.x := vyBase.GetVFromObj( data );
		IF (obj.x = NIL ) THEN vyHostTexts.Note( vyHostTexts.cWarning, "vyDistribution.SetModel: can't show these data as a distribution-plot" )
		ELSE
			COPY( "distribution: ", id );  vyName.AppendObjId( data( vyBase.Object ), id );  vyName.RegisterNamed( obj, id );
			vyBase.Subscribe( (*for messages from source*) obj.x, obj );
			AdjustCoord( pict, obj );  vyBase.Update( data )
		END
	END SetModel;

	PROCEDURE HandleLinks( obj: tLayer;  VAR msg: Objects.LinkMsg );
	(*! handle subscribe/unsubscribe. Move to vyPort *)
	VAR pict: vyPort.Picture;
	BEGIN
		vyHostTexts.Msg( 'vyDistribution: handling Link' );

		IF (msg.id = Objects.enum) THEN msg.Enum( "x" );  vyPort.LayerHandler( obj, msg )
		ELSIF (msg.id = Objects.get) & (msg.name = "x") THEN msg.obj := obj.x;  msg.res := 0
		ELSIF (msg.id = Objects.set) & ((msg.name = "x") OR (msg.name = 'Model')) & (msg.obj # NIL ) & (msg.obj IS vyBase.tVector) THEN
			vyHostTexts.Msg( 'vyDistribution: handling Model' );
			(* check proper type *)
			IF msg.dlink # NIL THEN pict := msg.dlink( vyPort.Picture ) ELSE pict := NIL END;
			SetModel( pict, obj, msg.obj );  msg.res := 0
		ELSE vyPort.LayerHandler( obj, msg )
		END
	END HandleLinks;

	PROCEDURE Store0( obj: tLayer;  VAR M: Objects.FileMsg );
	BEGIN
		Gadgets.WriteRef( M.R, obj.lib, obj.x )
	END Store0;

	PROCEDURE Load0( obj: tLayer;  VAR M: Objects.FileMsg );
	VAR objsub: Objects.Object;
	BEGIN
		dlink := M.dlink;  Gadgets.ReadRef( M.R, obj.lib, objsub );
		IF (objsub # NIL ) & (objsub IS vyBase.tVector) THEN obj.x := objsub( vyBase.tVector ) END
	END Load0;

	PROCEDURE New*;   (* Gadgets.Insert vyDistribution.New *)
	BEGIN
		NEW( newlayer );  Init( newlayer, NIL );  Objects.NewObj := newlayer
	END New;

	PROCEDURE Handler*( obj: Objects.Object;  VAR msg: Objects.ObjMsg );
	(*vs 0.0a1	md  20.07.94 *)
	VAR minX, maxX: FLOAT32;  pict: vyPort.Picture;  nans: SIGNED32;
	BEGIN
		WITH obj: tLayer DO
			IF msg IS Display.DisplayMsg THEN
				WITH msg: Display.DisplayMsg DO Recall( obj );
				END;
			ELSIF msg IS Objects.CopyMsg THEN
				WITH msg: Objects.CopyMsg DO
				(*NEW(copy);  msg.obj := copy;  vyPort.LayerHandler (obj, msg);
			Copy (obj, msg.obj(tLayer));*)
					New;  msg.obj := newlayer;  vyPort.LayerHandler( obj, msg );  Copy( obj, msg.obj( tLayer ) );
				END;
			ELSIF msg IS Objects.FileMsg THEN
				WITH msg: Objects.FileMsg DO
					IF msg.id = Objects.load THEN
						Load0( obj, msg );  vyPort.LayerHandler( obj, msg );
						(*! hack *) IF obj.x # NIL THEN
							IF msg.dlink # NIL THEN  (* jb 5.12.00 *)
								pict := msg.dlink( vyPort.Picture );  vyTypes.VGetMinMaxR( obj.x, minX, maxX, nans );
								vyPort.SetNewC2d( pict, minX, 0, maxX - minX, 1 )
							ELSE  (*vyHostTexts.Note(vyHostTexts.cWarning,"vyDistribution: no host picture  ")*)
							END
						ELSE vyHostTexts.Note( vyHostTexts.cWarning, "vyDistribution: no x obj loaded  " )
						END
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
					IF obj.x # NIL THEN Gadgets.BindObj( obj.x, msg.lib ) END
				END;
			ELSE vyPort.LayerHandler( obj, msg )
			END
		END
	END Handler;

	PROCEDURE Alloc*;
	VAR layer: tLayer;
	BEGIN
		NEW( layer );  layer.handle := Handler;  Objects.NewObj := layer
	END Alloc;

	PROCEDURE Init*( F: tLayer;  data: Objects.Object );
	VAR id: vyName.tNameArray;
	BEGIN
		F.handle := Handler;  COPY( "distribution: ", id );  F.x := vyBase.GetVFromObj( data );
		IF (F.x = NIL ) & (data # NIL ) THEN vyHostTexts.Note( vyHostTexts.cWarning, "vyDistribution.Open: can't plot this data as a distribution-plot: not the right type!" ) END;
		IF data # NIL THEN vyName.AppendObjId( data( vyBase.Object ), id ) END;
		vyPort.OpenLayer( F, id );
		IF F.x # NIL THEN vyBase.Subscribe( (*for messages from source*) F.x, F ) END
	END Init;

	PROCEDURE ShowP*;
	VAR data: Objects.Object;  pict: vyPort.Picture;
	BEGIN
		data := vyBase.NextParObj();
		WHILE data # NIL DO
			New;  Init( newlayer, data );
			(*pict := vyPort.InsertNewVecPicture (F.x,NIL);
		vyPort.AddLayer (pict, F);*)
			vyPort.AddLayer( vyPort.InsertNewVecPicture( newlayer.x, NIL ), newlayer );  data := vyBase.NextParObj()
		END;
		Objects.NewObj := pict
	END ShowP;

	PROCEDURE ShowL*( list: vyLinks.Link );
	VAR pict: vyPort.Picture;
	BEGIN
		WHILE list # NIL DO
			New;  Init( newlayer, list.obj );
			(*pict := vyPort.InsertNewVecPicture (F.x,NIL);
		vyPort.AddLayer (pict, F);*)
			vyPort.AddLayer( vyPort.InsertNewVecPicture( newlayer.x, NIL ), newlayer );  list := list.link
		END;
		Objects.NewObj := pict
	END ShowL;

	PROCEDURE ShowO*( obj: Objects.Object );
	BEGIN
		New;  Init( newlayer, obj );
		(*pict := vyPort.InsertNewVecPicture (F.x,NIL);
	vyPort.AddLayer (pict, F);
	Objects.NewObj := pict;*)
		vyPort.AddLayer( vyPort.InsertNewVecPicture( newlayer.x, NIL ), newlayer )
	END ShowO;

	PROCEDURE NewPict*;   (* Gadgets.Insert vyDistri.NewPict *)
	VAR pict: vyPort.Picture;
	BEGIN
		New;  pict := vyPort.XNewCPicture( 0, 0, 1, 1, vyDisplay2d.NewC2d( 0, cMin, 1, cMax - cMin ) );
		vyPort.AddLayer( pict, newlayer );  Objects.NewObj := pict
		(* Out.String('vyDistribution.XNewPict done'); IF pict.gcontext#NIL THEN Out.String(' w.context');END; Out.Ln; *)
	END NewPict;


(*PROCEDURE Alloc*;
VAR layer: tLayer;
BEGIN NEW (layer);  layer.handle := Handler;  Objects.NewObj := layer END Alloc;*)

	PROCEDURE NewPic*;
	CONST minX = 0.0;  maxX = 1.0;
	VAR F: tLayer;  pict: vyPort.Picture;
	BEGIN
		pict := vyPort.InsertNewCPicture( 0, 0, 1, 1, vyDisplay2d.NewC2d( minX, 0, maxX - minX, 1 ) );  NEW( F );  Init( F, NIL );
		vyPort.AddLayer( pict, F );  Objects.NewObj := pict
	END NewPic;

END vyDistribution.

scr
System.Free vyDistribution * ~
Gadgets.Insert vyDistribution.NewPic dbgTestVec.RVec128 ~
vyDistribution.NewPic ~