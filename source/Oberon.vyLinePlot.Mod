MODULE vyLinePlot IN Oberon;
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
(*=  a line plot *)
(*	history:
9.8.95 md 0.0a1	alpha version
16.3.95 md 0.0d18	bug in PROC Recall corrected
26.1.95 md 0.0d17	cleaned
27.10.94 md 0.0d16	adaped to the renamed vyHostDisplay & vyPictures
20.10.94 md 0.0d15	renamed: Curve -> LinePlot (Curve doesn't exist anymore)
12.08.94 md 0.0d0	created *)
(*! seperate the two destinct cases: a line plot given by a vector or by a function *)

IMPORT Files, Gadgets, Objects, Display, vyBase, vyGraphBase, vyHostDisplay := vyGraphBase, vyHostTexts, vyLinks,
	vyLongrealVec, vyName, vyParser, vyPatterns, vyPort, vyRealVec, vyTypes, vyDisplay2d;

CONST
	idversion* = "vyLinePlot v0r0a3";

TYPE
	Real = vyBase.Real;

	tParameter* = POINTER TO tParameterDesc;
	tParameterDesc* = RECORD END;
	tFunction* = PROCEDURE ( x: Real;  p: tParameter ): Real;

	tLayer* = POINTER TO tLayerDesc;
	tLayerDesc = RECORD (vyPort.tLayerDesc)
		D1, D2: Real;   (* *)
		f: tFunction;   (* *)
		ticks: LONGINT;
		parameter: tParameter;
		sign: vyHostDisplay.tSign
	END;

VAR
	dlink-: Objects.Object;  newlayer-: tLayer;

	PROCEDURE Copy( src, dest: tLayer );
	BEGIN
		dest^ := src^
	END Copy;

	PROCEDURE Recall( linePlot: tLayer );
	VAR nrData, i: LONGINT;  d, val: Real;
	BEGIN
		nrData := linePlot.x.nrData;
		IF nrData = 0 THEN RETURN END;
		d := (linePlot.D2 - linePlot.D1) / linePlot.ticks;   (* val := vyVec.Get (linePlot.x, 0); *)
		val := vyTypes.VGetR( linePlot.x, 0 );  vyGraphBase.MoveTo2d( linePlot.D1, val );
		IF linePlot.sign # NIL THEN
			vyGraphBase.PaintPat2d( linePlot.D1, val, linePlot.sign );
			FOR i := 1 TO nrData - 1 DO
				val := vyTypes.VGetR( linePlot.x, i );   (* fof 980617 *)
				(* val := vyVec.Get (linePlot.x, i); *)
				vyGraphBase.LineTo2d( linePlot.D1 + i * d, val );  vyGraphBase.PaintPat2d( linePlot.D1 + i * d, val, linePlot.sign )
			END
		ELSE
			FOR i := 1 TO nrData - 1 DO val := vyTypes.VGetR( linePlot.x, i );  vyGraphBase.LineTo2d( linePlot.D1 + i * d, val ) END
		END
	END Recall;

	PROCEDURE InstallData( linePlot: tLayer );
	VAR d, x: Real;  i: LONGINT;
	BEGIN
		IF linePlot.f # NIL THEN
			d := (linePlot.D2 - linePlot.D1) / linePlot.ticks;
			FOR i := 0 TO linePlot.ticks DO
				x := linePlot.D1 + d * i;
				(* vyTypes.RSetV (linePlot.f(x, linePlot.parameter), linePlot.x, i) *)
				IF linePlot.x IS vyLongrealVec.tVector THEN vyLongrealVec.Set( linePlot.f( x, linePlot.parameter ), linePlot.x, i )
				ELSE vyRealVec.Set( linePlot.f( x, linePlot.parameter ), linePlot.x, i )
				END
			END
		END
	END InstallData;

	PROCEDURE Consume( o: tLayer;  msg: Display.ConsumeMsg );
	VAR v: vyBase.tVector;  minX, maxX: Real;  pict: vyPort.Picture;  nans: LONGINT;
	BEGIN
		pict := msg.dlink( vyPort.Picture );  v := vyBase.GetVFromObj( msg.obj );
		IF v # NIL THEN vyBase.UnSubscribe( o.x, o );

			Open( o, msg.obj, 0, 0, NIL , NIL , 0 );  vyTypes.VGetMinMax( o.x, minX, maxX, nans );
			vyPort.SetNewC2d( pict, 0, minX, o.x.nrData, maxX - minX );  vyBase.Update( v )
		END
	END Consume;

	PROCEDURE HandleAttributes( obj: tLayer;  VAR M: Objects.AttrMsg );
	BEGIN
		IF M.id = Objects.get THEN
			IF M.name = "Gen" THEN COPY( 'vyLinePlot.Alloc', M.s );  M.class := Objects.String;  M.res := 0
			ELSIF M.name = 'Left margin' THEN M.class := Objects.LongReal;  M.y := obj.D1;  M.res := 0
			ELSIF M.name = 'Right margin' THEN M.class := Objects.LongReal;  M.y := obj.D2;  M.res := 0
			ELSIF M.name = 'Ticks' THEN M.class := Objects.Int;  M.i := obj.ticks;  M.res := 0
			ELSE vyPort.LayerHandler( obj, M )
			END  (*IF*)
		ELSIF M.id = Objects.set THEN
			IF M.class = Objects.LongReal THEN
				IF M.name = 'Left margin' THEN obj.D1 := M.y
				ELSIF M.name = 'Right margin' THEN obj.D2 := M.y
				END;
				M.res := 0
			ELSIF (M.class = Objects.Int) & (M.name = 'Ticks') THEN obj.ticks := M.i;  M.res := 0
			ELSE vyPort.LayerHandler( obj, M )
			END  (*IF*)
		ELSIF M.id = Objects.enum THEN vyPort.LayerHandler( obj, M );  M.Enum( 'Left margin' );  M.Enum( 'Right margin' );  M.Enum( 'Ticks' )
		ELSE vyPort.LayerHandler( obj, M )
		END  (*IF*)
	END HandleAttributes;

	PROCEDURE Store0( obj: tLayer;  VAR M: Objects.FileMsg );
	BEGIN
		Gadgets.WriteRef( M.R, obj.lib, obj.x );  Files.WriteLReal( M.R, obj.D1 );  Files.WriteLReal( M.R, obj.D2 );
		Files.WriteLInt( M.R, obj.ticks );  vyHostDisplay.StorePattern( M.R, obj.sign );
		(*! How should obj.f and obj.parameter be stored?*)
	END Store0;

	PROCEDURE Load0( obj: tLayer;  VAR M: Objects.FileMsg );

	VAR objsub: Objects.Object;

	BEGIN
		dlink := M.dlink;  Gadgets.ReadRef( M.R, obj.lib, objsub );
		IF (objsub # NIL ) & (objsub IS vyBase.tVector) THEN obj.x := objsub( vyBase.tVector ) END;
		Files.ReadLReal( M.R, obj.D1 );  Files.ReadLReal( M.R, obj.D2 );  Files.ReadLInt( M.R, obj.ticks );
		obj.sign := vyHostDisplay.LoadPattern( M.R );
		(*! How should obj.f and obj.parameter be loaded?*)
	END Load0;

	PROCEDURE HandleLinks( obj: tLayer;  VAR msg: Objects.LinkMsg );
	(*! handle subscribe/unsubscribe. Move to vyPort *)
	BEGIN
		IF (msg.id = Objects.enum) THEN msg.Enum( "x" );  vyPort.LayerHandler( obj, msg )
		ELSIF (msg.id = Objects.get) & (msg.name = "x") THEN msg.obj := obj.x;  msg.res := 0
		ELSIF (msg.id = Objects.set) & (msg.name = "x") & (msg.obj # NIL ) & (msg.obj IS vyBase.tVector) THEN
			(* check proper type *)
			obj.x := msg.obj( vyBase.tVector )
		ELSE vyPort.LayerHandler( obj, msg )
		END
	END HandleLinks;

	PROCEDURE Handler*( obj: Objects.Object;  VAR msg: Objects.ObjMsg );
	(*vs 0.0a1	md  20.07.94 *)

	VAR copy: tLayer;  minX, minY, maxY, maxX: LONGREAL;  nansY: LONGINT;

	BEGIN
		WITH obj: tLayer DO
			IF msg IS Display.DisplayMsg THEN
				WITH msg: Display.DisplayMsg DO InstallData( obj );  Recall( obj )
				END;
			ELSIF msg IS Objects.CopyMsg THEN
				WITH msg: Objects.CopyMsg DO NEW( copy );  msg.obj := copy;  vyPort.LayerHandler( obj, msg );  Copy( obj, copy )
				END;
			ELSIF msg IS Objects.FileMsg THEN
				WITH msg: Objects.FileMsg DO
					IF msg.id = Objects.load THEN
						vyPort.LayerHandler( obj, msg );  Load0( obj, msg );   (* wrong ordering repaired, fof 0111 *)
						(* fof 0111, commented, vyPort is doing that!
				(*! hack *) IF obj.x # NIL THEN
				pict := msg.dlink(vyPort.Picture);
				IF pict # NIL THEN
				vyTypes.VGetMinMaxR(obj.x, minX, maxX, nans);
				vyPort.SetNewC2d (pict, minX, 0, maxX - minX, 1)
				(*ELSE
				vyHostTexts.Note(vyHostTexts.cWarning,"vyLinePlot: no host picture  ")*)
				END
				ELSE
				vyHostTexts.Note(vyHostTexts.cWarning,"vyLinePlot: no x obj loaded  ")
				;HALT(100)
				END
				*)
					ELSIF msg.id = Objects.store THEN
						(* repaired order: fof 0111, Portlayerhandler before store0 *)
						vyPort.LayerHandler( obj, msg );  Store0( obj, msg )

					ELSE vyPort.LayerHandler( obj, msg )
					END
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
				WITH msg: vyPort.AdjustCoordMsg DO
					vyTypes.VGetMinMax( obj.x, minY, maxY, nansY );  minX := 0;  maxX := obj.x.nrData;
					IF (minX # maxX) & (minY # maxY) THEN
						minY := minY - 0.1 * (maxY - minY);  maxY := maxY + 0.1 * (maxY - minY);
						vyPort.SetC2d( obj.dlink( vyPort.Picture ), minX, minY, maxX - minX, maxY - minY );
					END;
				END;
			ELSE vyPort.LayerHandler( obj, msg )
			END
		END  (*WITH*)
	END Handler;

	PROCEDURE Open*( linePlot: tLayer;  data: Objects.Object;  D1, D2: Real;  f: tFunction;  p: tParameter;  ticks: LONGINT );
	VAR id: vyName.tNameArray;  object: vyBase.tVector;
	BEGIN
		id := "linePlot: ";
		IF data # NIL THEN vyName.AppendObjId( data( vyBase.Object ), id ) ELSE END;
		IF data = NIL THEN
			object := vyLongrealVec.New( ticks + 1 );   (*(*?gs*)object.nrData := ticks;*)
			vyBase.Register( object );   (*! check name registration. Missing ? *)
			NEW( data );  data.slink := NIL;  data := object;  linePlot.D1 := D1;  linePlot.D2 := D2;  linePlot.ticks := ticks
		ELSE linePlot.D1 := 0;  linePlot.D2 := data( vyBase.tVector ).nrData;  linePlot.ticks := SHORT( ENTIER( linePlot.D2 ) )
		END;
		linePlot.x := vyBase.GetVFromObj( data );  vyPort.OpenLayer( linePlot, id );  linePlot.handle := Handler;  linePlot.f := f;
		linePlot.parameter := p;  linePlot.sign := NIL;  vyBase.Subscribe( (*for messages from source*) linePlot.x, linePlot )
	END Open;

	PROCEDURE Alloc*;
	BEGIN
		NEW( newlayer );  newlayer.handle := Handler;  Objects.NewObj := newlayer
	END Alloc;

	PROCEDURE New*;
	VAR data: Objects.Object;
	BEGIN
		IF Objects.NewObj # NIL THEN data := Objects.NewObj ELSE RETURN END;
		Alloc;  Open( newlayer, data, 0, 0, NIL , NIL , 0 );  Objects.NewObj := newlayer
	END New;

	PROCEDURE ShowP*;
	VAR data: Objects.Object;  linePlot: tLayer;  pict: vyPort.Picture;  c: vyDisplay2d.tCoordinate2d;  minX, maxX: Real;
		nans: LONGINT;
	BEGIN
		data := vyBase.NextParObj();
		WHILE data # NIL DO
			Alloc;  linePlot := Objects.NewObj( tLayer );  Open( linePlot, data, 0, 0, NIL , NIL , 0 );
			vyTypes.VGetMinMax( linePlot.x, minX, maxX, nans );
			IF maxX = minX THEN minX := minX - 0.5;  maxX := minX + 1 END;
			NEW( c );  vyDisplay2d.OpenC2d( c, 0, minX, linePlot.x.nrData, maxX - minX );
			pict := vyPort.InsertNewCPicture( 0, 0, 1, 1, c );  vyPort.AddLayer( pict, linePlot );  data := vyBase.NextParObj()
		END;
		Objects.NewObj := pict
	END ShowP;

	PROCEDURE ShowL*( list: vyLinks.Link );
	VAR linePlot: tLayer;  pict: vyPort.Picture;  c: vyDisplay2d.tCoordinate2d;  minX, maxX: Real;  nans: LONGINT;
	BEGIN
		WHILE list # NIL DO
			Alloc;  linePlot := Objects.NewObj( tLayer );  Open( linePlot, list.obj, 0, 0, NIL , NIL , 0 );
			vyTypes.VGetMinMax( linePlot.x, minX, maxX, nans );
			IF maxX = minX THEN minX := minX - 0.5;  maxX := minX + 1 END;
			NEW( c );  vyDisplay2d.OpenC2d( c, 0, minX, linePlot.x.nrData, maxX - minX );
			pict := vyPort.InsertNewCPicture( 0, 0, 1, 1, c );  vyPort.AddLayer( pict, linePlot );  list := list.link;
			Objects.NewObj := pict
		END
	END ShowL;

	PROCEDURE ShowO*( obj: Objects.Object );
	VAR linePlot: tLayer;  pict: vyPort.Picture;  c: vyDisplay2d.tCoordinate2d;  minX, maxX: Real;  nans: LONGINT;
	BEGIN
		Alloc;  linePlot := Objects.NewObj( tLayer );  Open( linePlot, obj, 0, 0, NIL , NIL , 0 );
		vyTypes.VGetMinMax( linePlot.x, minX, maxX, nans );
		IF maxX = minX THEN minX := minX - 0.5;  maxX := minX + 1 END;
		NEW( c );  vyDisplay2d.OpenC2d( c, 0, minX, linePlot.x.nrData, maxX - minX );
		pict := vyPort.InsertNewCPicture( 0, 0, 1, 1, c );  vyPort.AddLayer( pict, linePlot );  Objects.NewObj := pict
	END ShowO;

	PROCEDURE set;

	VAR code: ARRAY 32 OF CHAR;
		layer: Objects.Object;  linePlot: tLayer;  pict: vyPort.Picture;  s: vyParser.Scanner;

		PROCEDURE SetPattern( sgn: vyHostDisplay.tSign );
		BEGIN
			IF (linePlot.sign # sgn) THEN linePlot.sign := sgn;  vyPort.PictureUpdate( pict ) END
		END SetPattern;

	BEGIN
		pict := vyPort.GetFocusPicture();
		IF pict = NIL THEN vyHostTexts.Msg( "no picture active! KLICK" );  RETURN END;
		layer := vyLinks.GetLastObj( pict.vylinks );
		IF layer IS tLayer THEN linePlot := layer( tLayer ) ELSE vyHostTexts.Msg( "the frontmost layer is no LinePlot!" );  RETURN END;
		vyParser.OpenParScanner( s );
		IF (vyParser.Name( s, code )) & (code = "pattern") THEN
			IF vyParser.Name( s, code ) THEN
				IF code = "cross0" THEN SetPattern( vyPatterns.cross.sgn0 )
				ELSIF code = "cross1" THEN SetPattern( vyPatterns.cross.sgn1 )
				ELSIF code = "circle0" THEN SetPattern( vyPatterns.circle.sgn0 )
				ELSIF code = "circle1" THEN SetPattern( vyPatterns.circle.sgn1 )
				ELSIF code = "dot0" THEN SetPattern( vyPatterns.dot.sgn0 )
				ELSIF code = "dot1" THEN SetPattern( vyPatterns.dot.sgn1 )
				ELSIF code = "none" THEN SetPattern( NIL )
				END
			END
		END
	END set;   (* use this to implement a non-generic version *)

	PROCEDURE Set*;
	BEGIN
		set
	END Set;

	PROCEDURE Changed*( linePlot: tLayer;  p: tParameter );
	VAR i: LONGINT;  d, x: Real;
	BEGIN
		d := (linePlot.D2 - linePlot.D1) / linePlot.ticks;
		FOR i := 0 TO linePlot.ticks DO
			x := linePlot.D1 + d * i;
			IF linePlot.x IS vyLongrealVec.tVector THEN vyLongrealVec.Set( linePlot.f( x, p ), linePlot.x, i )
			ELSE vyRealVec.Set( linePlot.f( x, p ), linePlot.x, i )
			END
		END;
		linePlot.parameter := p
	END Changed;

END vyLinePlot.

Voyager vyRegress vyLinePlot