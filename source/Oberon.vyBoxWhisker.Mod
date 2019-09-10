MODULE vyBoxWhisker IN Oberon;
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
(*= 	Box and Whisker plot. This plot has no interactive capabilities *)
(*! whats about more then one B&W plot in one picture?
the sorting algorithm in the recall routine works on the original data *)

IMPORT Files, Gadgets, Objects, Display, vyHostTexts, vyBase, vyTypes, vyName, vyPort, vyLinks,
	vyHostDisplay := vyGraphBase, vyPatterns, vyGraphBase, vyDisplay2d;

CONST
	idversion* = "vyBoxWhisker v0r0a2";  cMin = 0;  cMax = 1;

TYPE
	tLayer* = POINTER TO tLayerDesc;
	tLayerDesc = RECORD (vyPort.tLayerDesc)
		yLoc, height: FLOAT32;
		(*! location of the greatest box as region for interactive features *)
	END;

VAR
	slink*, dlink*: Objects.Object;  newlayer-: tLayer;

(* PROCEDURE^ Alloc*; *)

	PROCEDURE Recall( boxWhisker: tLayer );
	(*vs 0.0a1	md  10.08.94 *)
	(* converted from the box and whisker plot in Shorty (c) G. Sawitzki *)
	VAR count: SIGNED32;  I: SIGNED32;  minVal, maxVal, range, minRange: FLOAT32;  Q1, med, Q3, WH1, WH3, FO1, FO3: FLOAT32;
	BEGIN
		IF boxWhisker.x # NIL THEN
			count := boxWhisker.x.nrData;
			(*! sort operate work on a copy of the data *)
			vyTypes.Sort( boxWhisker.x );  vyHostDisplay.SetDisplayMode( vyHostDisplay.replace );

			minVal := vyTypes.VGetR( boxWhisker.x, 0 );  maxVal := vyTypes.VGetR( boxWhisker.x, count - 1 );
			Q1 := vyTypes.VGetR( boxWhisker.x, ENTIER( (count / 4) + 0.5 ) - 1 );
			med := vyTypes.VGetR( boxWhisker.x, ENTIER( (count / 2) + 0.5 ) - 1 );
			Q3 := vyTypes.VGetR( boxWhisker.x, ENTIER( (3 * count / 4) + 0.5 ) - 1 );

			WH1 := Q1 - 1.5 * (Q3 - Q1);  WH3 := Q3 + 1.5 * (Q3 - Q1);

			FO1 := Q1 - 3 * (Q3 - Q1);  FO3 := Q3 + 3 * (Q3 - Q1);

			range := maxVal;  range := range - minVal;
			IF range = 0 THEN range := 1 END;   (*IF*)  minRange := minVal - 0.1 * range;  range := 300 / (range * 1.2);
			vyHostDisplay.SetForeColor( vyHostDisplay.white );
			vyGraphBase.PaintRect2d( Q1, boxWhisker.yLoc, Q3 - Q1, boxWhisker.height );
			vyHostDisplay.SetForeColor( vyHostDisplay.mgrey );
			vyGraphBase.PaintRect2d( med - 1.58 * (Q3 - Q1) / count, boxWhisker.yLoc, (2 * 1.58 * (Q3 - Q1) / count),
													    boxWhisker.height );
			vyHostDisplay.SetForeColor( vyHostDisplay.black );
			vyGraphBase.Line2d( med, boxWhisker.yLoc, med, boxWhisker.yLoc + boxWhisker.height );
			vyGraphBase.FrameRect2d( Q1, boxWhisker.yLoc, Q3 - Q1, boxWhisker.height );

			I := 0;  vyHostDisplay.SetPatternJustification( vyHostDisplay.center, vyHostDisplay.center );
			WHILE vyTypes.VGetR( boxWhisker.x, I ) < FO1 DO
				vyGraphBase.PaintPat2d( vyTypes.VGetR( boxWhisker.x, I ), 0.5, vyPatterns.cross.sgn0 );  INC( I )
			END;   (*WHILE*)

			WHILE vyTypes.VGetR( boxWhisker.x, I ) < WH1 DO
				vyGraphBase.PaintPat2d( vyTypes.VGetR( boxWhisker.x, I ), 0.5, vyPatterns.circle.sgn0 );  INC( I )
			END;   (*WHILE*)
			IF vyTypes.VGetR( boxWhisker.x, I ) < Q1 THEN vyGraphBase.Line2d( vyTypes.VGetR( boxWhisker.x, I ), 0.5, Q1, 0.5 ) END;   (*IF*)
			I := count - 1;
			WHILE vyTypes.VGetR( boxWhisker.x, I ) > FO3 DO
				vyGraphBase.PaintPat2d( vyTypes.VGetR( boxWhisker.x, I ), 0.5, vyPatterns.cross.sgn0 );  DEC( I )
			END;   (*WHILE*)
			WHILE vyTypes.VGetR( boxWhisker.x, I ) > WH3 DO
				vyGraphBase.PaintPat2d( vyTypes.VGetR( boxWhisker.x, I ), 0.5, vyPatterns.circle.sgn0 );  DEC( I )
			END;   (*WHILE*)
			IF vyTypes.VGetR( boxWhisker.x, I ) > Q3 THEN vyGraphBase.Line2d( vyTypes.VGetR( boxWhisker.x, I ), 0.5, Q3, 0.5 )
				END;   (*IF*)
		END
	END Recall;

	PROCEDURE Copy( source, dest: tLayer );   (* FOF inserted *)
	BEGIN
		dest^ := source^
	END Copy;

	PROCEDURE Consume( o: tLayer;  msg: Display.ConsumeMsg );
	VAR v: vyBase.tVector;  minX, maxX: FLOAT32;  p: vyPort.Picture;  nans: SIGNED32;
	BEGIN
		p := msg.dlink( vyPort.Picture );  v := vyBase.GetVFromObj( msg.obj );
		IF v # NIL THEN
			vyBase.UnSubscribe( o.x, o );  Init( o, msg.obj );  vyTypes.VGetMinMaxR( o.x, minX, maxX, nans );
			vyPort.SetNewC2d( p, minX, 0, maxX - minX, 1 );  vyBase.Update( v )
		END
	END Consume;

	PROCEDURE HandleAttributes( obj: tLayer;  VAR M: Objects.AttrMsg );
	BEGIN
		IF M.id = Objects.get THEN
			IF M.name = "Gen" THEN
				(*COPY('vyBoxWhisker.Alloc', M.s);  *) COPY( 'vyBoxWhisker.New', M.s );  M.class := Objects.String;  M.res := 0
			ELSIF M.name = "yLoc" THEN M.class := Objects.Real;  M.x := obj.yLoc;  M.res := 0
			ELSIF M.name = "height" THEN M.class := Objects.Real;  M.x := obj.height;  M.res := 0
			ELSE vyPort.LayerHandler( obj, M )
			END
		ELSIF M.id = Objects.enum THEN M.Enum( "yLoc" );  M.Enum( "height" )
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
		IF (obj.x = NIL ) THEN vyHostTexts.Note( vyHostTexts.cWarning, "vyBoxWhisker.SetModel: can't show these data as a scatter1" )
		ELSE
			COPY( "box&whisker: ", id );  vyName.AppendObjId( data( vyBase.Object ), id );  vyName.RegisterNamed( obj, id );
			vyBase.Subscribe( (*for messages from source*) obj.x, obj );
			AdjustCoord( pict, obj );  vyBase.Update( data )
		END
	END SetModel;

	PROCEDURE HandleLinks( obj: tLayer;  VAR msg: Objects.LinkMsg );
	(*! handle subscribe/unsubscribe. Move to vyPort *)
	VAR pict: vyPort.Picture;
	BEGIN
		IF (msg.id = Objects.enum) THEN msg.Enum( "x" );  vyPort.LayerHandler( obj, msg )
		ELSIF (msg.id = Objects.get) & (msg.name = "x") THEN msg.obj := obj.x;  msg.res := 0
		ELSIF (msg.id = Objects.set) & ((msg.name = "x") OR (msg.name = "Model")) & (msg.obj # NIL ) & (msg.obj IS vyBase.tVector) THEN
			(* check proper type *)
			IF msg.dlink # NIL THEN pict := msg.dlink( vyPort.Picture ) ELSE pict := NIL END;
			SetModel( pict, obj, msg.obj );  msg.res := 0
		ELSE vyPort.LayerHandler( obj, msg )
		END
	END HandleLinks;

	PROCEDURE Store0( obj: tLayer;  VAR M: Objects.FileMsg );
	BEGIN
		Files.WriteReal( M.R, obj.yLoc );  Files.WriteReal( M.R, obj.height );  Gadgets.WriteRef( M.R, obj.lib, obj.x )
	END Store0;

	PROCEDURE Load0( obj: tLayer;  VAR M: Objects.FileMsg );
	VAR objsub: Objects.Object;
	BEGIN
		dlink := M.dlink;  Files.ReadReal( M.R, obj.yLoc );  Files.ReadReal( M.R, obj.height );
		Gadgets.ReadRef( M.R, obj.lib, objsub );
		IF (objsub # NIL ) & (objsub IS vyBase.tVector) THEN obj.x := objsub( vyBase.tVector ) END
	END Load0;

	PROCEDURE New*;   (* Gadgets.Insert vyBoxWhisker.New *)
	BEGIN
		NEW( newlayer );  Init( newlayer, NIL );  Objects.NewObj := newlayer
	END New;

	PROCEDURE Handler*( obj: Objects.Object;  VAR msg: Objects.ObjMsg );
	(*vs 0.0a1	md  20.07.94 *)
	VAR pict: vyPort.Picture;  minX, maxX: FLOAT32;  nans: SIGNED32;
	BEGIN
		WITH obj: tLayer DO
			IF msg IS Display.DisplayMsg THEN
				WITH msg: Display.DisplayMsg DO Recall( obj );
				END;
			ELSIF msg IS Objects.CopyMsg THEN
				WITH msg: Objects.CopyMsg DO
				(*Alloc;  copy := Objects.NewObj(tLayer);  msg.obj := copy; vyPort.LayerHandler (obj, msg);
			Copy (obj, msg.obj(tLayer)); *)
					New;  msg.obj := newlayer;  vyPort.LayerHandler( obj, msg );  Copy( obj, msg.obj( tLayer ) );
				END;
			ELSIF msg IS Objects.FileMsg THEN
				WITH msg: Objects.FileMsg DO
					IF msg.id = Objects.load THEN
						Load0( obj, msg );  vyPort.LayerHandler( obj, msg );
						(*! hack *) IF obj.x # NIL THEN
							pict := msg.dlink( vyPort.Picture );
							IF pict # NIL THEN
								vyTypes.VGetMinMaxR( obj.x, minX, maxX, nans );  vyPort.SetNewC2d( pict, minX, 0, maxX - minX, 1 )
							ELSE  (*vyHostTexts.Note(vyHostTexts.cWarning,"vyBoxWhisker: no host picture  ");*)
							END
						ELSE vyHostTexts.Note( vyHostTexts.cWarning, "vyBoxWhisker: no x obj loaded  " )
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

	PROCEDURE Init*( boxWhisk: tLayer;  data: Objects.Object );
	VAR id: vyName.tNameArray;
	BEGIN
		COPY( "box&whisker: ", id );  boxWhisk.handle := Handler;  boxWhisk.yLoc := 0;  boxWhisk.height := 1;
		boxWhisk.x := vyBase.GetVFromObj( data );
		IF (boxWhisk.x = NIL ) & (data # NIL ) THEN vyHostTexts.Msg( "can't plot this data as a box&whisker plot: not the right type!" ) END;
		IF data # NIL THEN vyName.AppendObjId( data( vyBase.Object ), id ) END;
		vyPort.OpenLayer( boxWhisk, id );
		IF boxWhisk.x # NIL THEN
			(*	vyBase.Subscribe((*for messages from source*) vyHighlight.GetSelectionAttribute (boxWhisk.x.nrData), boxWhisk);
		vyBase.Subscribe((*for messages from source*) vyHighlight.GetColorAttribute (boxWhisk.x.nrData), boxWhisk);
		*)
			vyBase.Subscribe( (*for messages from source*) boxWhisk.x, boxWhisk )
		END
	END Init;

	PROCEDURE ShowP*;
	VAR data: Objects.Object;   (*boxWhisk: tLayer; *)
	BEGIN
		data := vyBase.NextParObj();
		WHILE data # NIL DO
			New;  Init( newlayer, data );  vyPort.AddLayer( vyPort.InsertNewVecPicture( newlayer.x, NIL ), newlayer );
			data := vyBase.NextParObj()
		END
	END ShowP;

	PROCEDURE ShowL*( list: vyLinks.Link );
	BEGIN
		WHILE list # NIL DO
			New;  Init( newlayer, list.obj );  vyPort.AddLayer( vyPort.InsertNewVecPicture( newlayer.x, NIL ), newlayer );
			list := list.link
		END
	END ShowL;

	PROCEDURE ShowO*( obj: Objects.Object );
	BEGIN
		New;  Init( newlayer, obj );  vyPort.AddLayer( vyPort.InsertNewVecPicture( newlayer.x, NIL ), newlayer )
	END ShowO;

	PROCEDURE NewPict*;   (* System.Free vyBoxWhisker* ~ Gadgets.Insert vyBoxWhisker.NewPict *)
	VAR pict: vyPort.Picture;
	BEGIN
		New;  pict := vyPort.XNewCPicture( 0, 0, 1, 1, vyDisplay2d.NewC2d( 0, cMin, 1, cMax - cMin ) );
		vyPort.AddLayer( pict, newlayer );  Objects.NewObj := pict
		(* Out.String('vyBoxWhisker.XNewPict done'); IF pict.gcontext#NIL THEN Out.String(' w.context');END; Out.Ln; *)
	END NewPict;


(*PROCEDURE Alloc*;
VAR	layer: tLayer;
BEGIN NEW (layer); layer.handle := Handler;  Objects.NewObj := layer  END Alloc;*)

END vyBoxWhisker.
System.Free vyBoxWhisker * ~can't plot this data as a box&whisker plot: not the right type!'
