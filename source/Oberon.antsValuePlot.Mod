MODULE antsValuePlot IN Oberon;
(* Copyright notice:

This file is part of AntsInFields
Copyright (C) 1997-2002, Felix Friedrich

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
Report any problems as soon as possible to ants@AntsInFields.de
*)




IMPORT Files, Gadgets, Objects, Display, vyBase, vyGraphBase, vyLongrealVec, antsCommands, vyName, vyPort, vyTypes,
	vyDisplay2d, aM := antsMessages;

CONST
	idversion* = "antsPointPlot";

TYPE

	tLayer* = POINTER TO tLayerDesc;
	tLayerDesc = RECORD (vyPort.tLayerDesc)
		xr, yr: vyBase.tData
	END;

VAR
	dlink-: Objects.Object;  newlayer-: tLayer;

	PROCEDURE Copy( src, dest: tLayer );
	BEGIN
		dest^ := src^
	END Copy;

	PROCEDURE Recall( scatter: tLayer );
	VAR xx, yy: SIGNED16;  temp: SIGNED16;  xr, yr: FLOAT32;
	BEGIN
		IF scatter.xr # NIL THEN xr := vyTypes.GetValueR( scatter.xr );  vyGraphBase.Point2dToPoint( xr, 0, xx, temp )
		ELSE xx := MIN( SIGNED16 )
		END;
		IF scatter.yr # NIL THEN yr := vyTypes.GetValueR( scatter.yr );  vyGraphBase.Point2dToPoint( 0, yr, temp, yy ) ELSE yy := MAX( SIGNED16 ) END;
		vyGraphBase.Line( xx, MIN( SIGNED16 ) DIV 10, xx, MAX( SIGNED16 ) DIV 10 );  vyGraphBase.Line( MIN( SIGNED16 ) DIV 10, yy, MAX( SIGNED16 ) DIV 10, yy )
	END Recall;
(* selection methods for the use of the Interactive.tSelector *)

	PROCEDURE HandleAttributes( obj: tLayer;  VAR M: Objects.AttrMsg );
	BEGIN
		IF M.id = Objects.get THEN
			IF M.name = "Gen" THEN COPY( 'antsValuePlot.Alloc', M.s );  M.class := Objects.String;  M.res := 0 ELSE vyPort.LayerHandler( obj, M )
				END  (*IF*)
		ELSIF M.id = Objects.set THEN vyPort.LayerHandler( obj, M )
		ELSIF M.id = Objects.enum THEN vyPort.LayerHandler( obj, M )
		ELSE vyPort.LayerHandler( obj, M )
		END  (*IF*)
	END HandleAttributes;

	PROCEDURE Store0( obj: tLayer;  VAR M: Objects.FileMsg );
	BEGIN
		Files.WriteInt( M.R, 0 );  Gadgets.WriteRef( M.R, obj.lib, obj.xr );  Gadgets.WriteRef( M.R, obj.lib, obj.yr )
	END Store0;

	PROCEDURE Load0( obj: tLayer;  VAR M: Objects.FileMsg );

	VAR objsub: Objects.Object;  version: SIGNED16;

	BEGIN
		Files.ReadInt( M.R, version );  dlink := M.dlink;  Gadgets.ReadRef( M.R, obj.lib, objsub );
		IF (objsub # NIL ) & (objsub IS vyBase.tData) THEN obj.xr := objsub( vyBase.tData ) END;
		Gadgets.ReadRef( M.R, obj.lib, objsub );

		IF (objsub # NIL ) & (objsub IS vyBase.tData) THEN obj.yr := objsub( vyBase.tData )
		END

	END Load0;

	PROCEDURE HandleLinks( obj: tLayer;  VAR msg: Objects.LinkMsg );
	(*! handle subscribe/unsubscribe. Move to vyPort *)
	BEGIN
		IF (msg.id = Objects.enum) THEN msg.Enum( "x" );  msg.Enum( "y" );  vyPort.LayerHandler( obj, msg )
		ELSIF (msg.id = Objects.get) & (msg.name = "x") THEN msg.obj := obj.xr;  msg.res := 0
		ELSIF (msg.id = Objects.get) & (msg.name = "y") THEN msg.obj := obj.yr;  msg.res := 0
		ELSE vyPort.LayerHandler( obj, msg )
		END
	END HandleLinks;

	PROCEDURE Handler*( obj: Objects.Object;  VAR msg: Objects.ObjMsg );
	VAR copy: tLayer;
	BEGIN
		WITH obj: tLayer DO
			IF msg IS Display.DisplayMsg THEN
				WITH msg: Display.DisplayMsg DO Recall( obj )
				END;
			ELSIF msg IS Objects.CopyMsg THEN
				WITH msg: Objects.CopyMsg DO NEW( copy );  msg.obj := copy;  vyPort.LayerHandler( obj, msg );  Copy( obj, copy )
				END;
			ELSIF msg IS Objects.FileMsg THEN
				WITH msg: Objects.FileMsg DO
					IF msg.id = Objects.load THEN vyPort.LayerHandler( obj, msg );  Load0( obj, msg )
					ELSIF msg.id = Objects.store THEN vyPort.LayerHandler( obj, msg );  Store0( obj, msg )
					ELSE vyPort.LayerHandler( obj, msg )
					END
				END;
			ELSIF msg IS Objects.AttrMsg THEN
				WITH msg: Objects.AttrMsg DO HandleAttributes( obj, msg )
				END;
			ELSIF msg IS Objects.LinkMsg THEN
				WITH msg: Objects.LinkMsg DO HandleLinks( obj, msg )
				END;
			ELSIF msg IS Objects.BindMsg THEN
				WITH msg: Objects.BindMsg DO
					IF obj.lib # msg.lib THEN
						IF obj.x # NIL THEN Gadgets.BindObj( obj.x, msg.lib ) END
					END;
					vyPort.LayerHandler( obj, msg )
				END;
			ELSE vyPort.LayerHandler( obj, msg )
			END
		END  (*WITH*)
	END Handler;

	PROCEDURE Open*( linePlot: tLayer;  xr, yr: vyBase.tData );
	VAR id: vyName.tNameArray;
	BEGIN
		id := "value Plot ";  vyPort.OpenLayer( linePlot, id );  linePlot.xr := xr;
		IF xr # NIL THEN vyBase.Subscribe( (*for messages from source*) linePlot.xr, linePlot ) END;
		linePlot.yr := yr;
		IF yr # NIL THEN vyBase.Subscribe( (*for messages from source*) linePlot.yr, linePlot ) END
	END Open;

	PROCEDURE Alloc*;
	BEGIN
		aM.cmd;  NEW( newlayer );  newlayer.handle := Handler;  Objects.NewObj := newlayer
	END Alloc;

	PROCEDURE NewValue*;
	VAR sc: antsCommands.tScanList;  obj: vyBase.tData;
		name: ARRAY 128 OF CHAR;
	BEGIN
		sc := antsCommands.ScanFromPar( "name=NAME" );
		IF antsCommands.ExpectNameFromKeyword( sc, "name", name ) THEN
			vyLongrealVec.GenLongrealObject;  obj := Objects.NewObj( vyLongrealVec.tLONGREAL );
			obj( vyLongrealVec.tLONGREAL ).x := 0.5;  vyName.RegisterNamed( obj, name );  aM.vSR( "antsValuePlot: new standard value:", 0.5 );
		END
	END NewValue;

	PROCEDURE ShowP*;
	VAR data, data2: Objects.Object;  linePlot: tLayer;  pict: vyPort.Picture;  c: vyDisplay2d.tCoordinate2d;
	BEGIN
		data := vyBase.NextParObj();  aM.vS( "antsValuePlot.ShowP" );
		WHILE data # NIL DO
			Alloc;  data2 := vyBase.NextParObj();  linePlot := Objects.NewObj( tLayer );
			IF data2 # NIL THEN Open( linePlot, data( vyBase.tData ), data2( vyBase.tData ) )
			ELSE Open( linePlot, data( vyBase.tData ), NIL )
			END;
			NEW( c );  vyDisplay2d.OpenC2d( c, 0, 0, 1, 1 );  pict := vyPort.InsertNewCPicture( 0, 0, 1, 1, c );
			vyPort.AddLayer( pict, linePlot );  data := vyBase.NextParObj();  data := vyBase.NextParObj()
		END;
		Objects.NewObj := pict
	END ShowP;

BEGIN
	aM.launch;
END antsValuePlot.

antsValuePlot.NewValue x ~
antsValuePlot.NewValue y ~

Voyager.Show x y as antsValuePlot ~
