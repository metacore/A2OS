MODULE antsInteractivePar IN Oberon;   (** fof  **)
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




IMPORT vyPort, Objects, vyName, vyBase, vyGraphBase, Display, vyEvents, Files, Gadgets, vyCommandMenus,
	aM := antsMessages, vyHostStrings, vyRectangles, vyCG := vyName, antsCommands, vyLayers2d := vyDisplay2d,
	antsNeighbourhoods, antsToolbox, Math := MathL IN A2;

TYPE


	(** Layer definition *)
	tLayer* = POINTER TO tLayerDesc;
	tLayerDesc* = RECORD (vyPort.tLayerDesc);
		n-: antsNeighbourhoods.Neighbours;
		maxx, maxy: SIGNED32;
		dim: SIGNED16;
		isotropic: BOOLEAN;
		commands: vyCommandMenus.List;
		viewnum: BOOLEAN;
		max: FLOAT64
	END;
VAR
	tempLayer: tLayer;

	PROCEDURE Recall( layer: tLayer );
	VAR cells: SIGNED32;  cellsize: FLOAT64;  i, j: SIGNED32;
		str: ARRAY 20 OF CHAR;

		PROCEDURE PaintCell( x, y: SIGNED32;  val: FLOAT64 );
		BEGIN
			vyHostStrings.RealToFixStr( val, str, 1, 2, 0 );
			IF val = MIN( FLOAT64 ) THEN val := layer.max;  str := "";  vyGraphBase.SetForeColor( layer.style.bcol )
			ELSIF val < 0 THEN val := -val;  vyGraphBase.SetForeColor( layer.style.selectcol )
			ELSE vyGraphBase.SetForeColor( layer.style.fcol )
			END;
			vyGraphBase.SetBackColor( layer.style.fillcol );
			IF val > layer.max THEN val := layer.max END;
			val := val / layer.max;

			vyGraphBase.EraseRect2d( x * cellsize - cellsize / 2, y * cellsize - cellsize / 2, cellsize, cellsize );
			vyGraphBase.FillRect2d( x * cellsize - val * cellsize / 2, y * cellsize - val * cellsize / 2, val * cellsize, val * cellsize );
			vyGraphBase.SetForeColor( vyGraphBase.mgrey );
			vyGraphBase.FrameRect2d( x * cellsize - cellsize / 2, y * cellsize - cellsize / 2, cellsize, cellsize );
			IF layer.viewnum THEN
				vyGraphBase.SetForeColor( vyGraphBase.blue );  vyGraphBase.String2d( x * cellsize, y * cellsize, "Syntax8.Scn.Fnt", str )
			END
		END PaintCell;

	BEGIN
		vyGraphBase.SetStringJustification( vyGraphBase.center, vyGraphBase.center );
		IF (layer.dim # layer.n.dim) OR (layer.isotropic # layer.n.isotropic) THEN
			layer.dim := layer.n.dim;  layer.isotropic := layer.n.isotropic;  AdjustXY( layer )
		END;
		vyGraphBase.SetForeColor( layer.style.fcol );
		IF layer.maxx > layer.maxy THEN cells := layer.maxx ELSE cells := layer.maxy END;
		cellsize := 1 / (cells + 1);

		FOR i := 0 TO layer.n.dim - 1 DO
			FOR j := 0 TO layer.n.count[i] - 1 DO PaintCell( layer.n.x[i, j], layer.n.y[i, j], layer.n.par[i] ) END
		END
	END Recall;

	PROCEDURE Responsible( layer: tLayer;  VAR event: vyEvents.EventMsg );
	VAR priority: SIGNED16;
	BEGIN
		priority := vyEvents.PrioNone;
		IF ((event.gesture = vyEvents.EvtSelect) OR (event.gesture = vyEvents.EvtLoc) OR
			 (event.gesture = vyEvents.EvtWheelUp) OR (event.gesture = vyEvents.EvtWheelDown)) THEN
			IF OnLayer( layer, event ) THEN priority := vyEvents.PrioNormal END
		ELSIF (event.gesture = vyEvents.EvtIdent) THEN priority := vyEvents.PrioNormal
		END;
		IF event.priority < priority THEN event.responder := layer;  event.priority := priority END
	END Responsible;

	PROCEDURE Copy( source, dest: tLayer );
	BEGIN
		dest^ := source^
	END Copy;

	PROCEDURE Prompt( layer: tLayer;  VAR event: vyEvents.EventMsg );
	BEGIN
		tempLayer := layer;  vyCommandMenus.ExecuteListedCommand( event.x, event.y, event, layer.commands )
	END Prompt;

	PROCEDURE OnLayer( layer: tLayer;  VAR event: vyEvents.EventMsg ): BOOLEAN;
	VAR i, j: SIGNED16;  cells: SIGNED32;  cellsize: FLOAT64;

		PROCEDURE InCell( x, y: SIGNED32;  cx, cy: SIGNED16 ): BOOLEAN;
		VAR rx, ry, rw, rh: SIGNED16;
		BEGIN
			vyGraphBase.Rect2dToRect( x * cellsize - cellsize / 2, y * cellsize - cellsize / 2, cellsize, cellsize, rx, ry, rw, rh );
			IF vyRectangles.PointInRect( cx, cy, rx, ry, rw, rh ) THEN RETURN TRUE ELSE RETURN FALSE END
		END InCell;

	BEGIN
		IF layer.maxx > layer.maxy THEN cells := layer.maxx ELSE cells := layer.maxy END;
		cellsize := 1 / (cells + 1);

		FOR i := 0 TO layer.n.dim - 1 DO
			FOR j := 0 TO layer.n.count[i] - 1 DO
				IF InCell( layer.n.x[i, j], layer.n.y[i, j], event.x, event.y ) THEN RETURN TRUE END
			END
		END;
		RETURN FALSE
	END OnLayer;

	PROCEDURE Select( layer: tLayer;  VAR event: vyEvents.EventMsg );
	VAR cells: SIGNED32;  cellsize: FLOAT64;  i, j: SIGNED32;  origx, origy: SIGNED16;  gesture: SIGNED16;  oldx: SIGNED16;

		PROCEDURE InCell( x, y: SIGNED32;  cx, cy: SIGNED16 ): BOOLEAN;
		VAR rx, ry, rw, rh: SIGNED16;
		BEGIN
			vyGraphBase.Rect2dToRect( x * cellsize - cellsize / 2, y * cellsize - cellsize / 2, cellsize, cellsize, rx, ry, rw, rh );
			IF vyRectangles.PointInRect( cx, cy, rx, ry, rw, rh ) THEN RETURN TRUE ELSE RETURN FALSE END
		END InCell;

	BEGIN
		IF layer.maxx > layer.maxy THEN cells := layer.maxx ELSE cells := layer.maxy END;
		cellsize := 1 / (cells + 1);  oldx := MAX( SIGNED16 );
		FOR i := 0 TO layer.n.dim - 1 DO
			IF layer.n.par[i] # MIN( FLOAT64 ) THEN
				FOR j := 0 TO layer.n.count[i] - 1 DO
					IF InCell( layer.n.x[i, j], layer.n.y[i, j], event.x, event.y ) THEN
						origx := event.x;  origy := event.y;  gesture := event.gesture;
						IF (gesture = vyEvents.EvtLoc) OR (gesture = vyEvents.EvtSelect) THEN
							WHILE (event.gesture = gesture) DO
								vyEvents.GetEvent( event );
								IF event.x # oldx THEN
									layer.n.par[i] := (event.x - origx) / 100 * layer.max;
									IF ABS( event.x - origx ) < ABS( event.y - origy ) THEN
										layer.n.par[i] := ABS( layer.n.par[i] ) / layer.n.par[i] * ABS( event.y - origy ) / 100
									END;

									IF layer.n.par[i] > layer.max THEN layer.n.par[i] := layer.max
									ELSIF layer.n.par[i] < -layer.max THEN layer.n.par[i] := -layer.max
									END;
									vyBase.Update( layer )
								END;
								oldx := event.x
							END
						END
					END
				END
			END
		END;
		antsNeighbourhoods.FillCache( layer.n );  vyBase.Update( layer.n )
	END Select;

	PROCEDURE Wheel( layer: tLayer;  VAR event: vyEvents.EventMsg );
	VAR cells: SIGNED32;  cellsize: FLOAT64;  i, j: SIGNED32;  origx, origy: SIGNED16;  gesture: SIGNED16;  oldx: SIGNED16;  add, val: FLOAT64;

		PROCEDURE InCell( x, y: SIGNED32;  cx, cy: SIGNED16 ): BOOLEAN;
		VAR rx, ry, rw, rh: SIGNED16;
		BEGIN
			vyGraphBase.Rect2dToRect( x * cellsize - cellsize / 2, y * cellsize - cellsize / 2, cellsize, cellsize, rx, ry, rw, rh );
			IF vyRectangles.PointInRect( cx, cy, rx, ry, rw, rh ) THEN RETURN TRUE ELSE RETURN FALSE END
		END InCell;

	BEGIN
		IF layer.maxx > layer.maxy THEN cells := layer.maxx ELSE cells := layer.maxy END;
		cellsize := 1 / (cells + 1);  oldx := MAX( SIGNED16 );
		FOR i := 0 TO layer.n.dim - 1 DO
			IF layer.n.par[i] # MIN( FLOAT64 ) THEN
				FOR j := 0 TO layer.n.count[i] - 1 DO
					IF InCell( layer.n.x[i, j], layer.n.y[i, j], event.x, event.y ) THEN
						add := layer.max / 20;
						IF event.gesture = vyEvents.EvtWheelUp THEN layer.n.par[i] := layer.n.par[i] + add;
						ELSE layer.n.par[i] := layer.n.par[i] - add;
						END;
					END
				END
			END
		END;
		antsNeighbourhoods.FillCache( layer.n );  vyBase.Update( layer.n )
	END Wheel;

	PROCEDURE HandleFileMsg( obj: tLayer;  VAR msg: Objects.FileMsg );
	VAR objsub: Objects.Object;  version: SIGNED16;

	BEGIN
		IF msg.id = Objects.load THEN
			Files.ReadInt( msg.R, version );  vyPort.LayerHandler( obj, msg );  Files.ReadLInt( msg.R, obj.maxx );
			Files.ReadLInt( msg.R, obj.maxy );  Files.ReadBool( msg.R, obj.isotropic );
			Gadgets.ReadRef( msg.R, obj.lib, objsub );
			IF objsub # NIL THEN obj.n := objsub( antsNeighbourhoods.Neighbours ) END;
			IF version > 0 THEN Files.ReadBool( msg.R, obj.viewnum ) END;
			IF version > 1 THEN Files.ReadLReal( msg.R, obj.max ) END
		ELSIF msg.id = Objects.store THEN
			Files.WriteInt( msg.R, 2 );  vyPort.LayerHandler( obj, msg );  Files.WriteLInt( msg.R, obj.maxx );
			Files.WriteLInt( msg.R, obj.maxy );  Files.WriteBool( msg.R, obj.isotropic );
			Gadgets.WriteRef( msg.R, obj.lib, obj.n );  Files.WriteBool( msg.R, obj.viewnum );  Files.WriteLReal( msg.R, obj.max )
		ELSE vyPort.LayerHandler( obj, msg )
		END
	END HandleFileMsg;

	PROCEDURE HandleAttributes( obj: tLayer;  VAR M: Objects.AttrMsg );
	BEGIN
		IF M.id = Objects.enum THEN M.Enum( "Gen" );  M.Enum( "isotropic" );  M.Enum( "max" );  vyPort.LayerHandler( obj, M )
		ELSIF M.id = Objects.get THEN
			IF M.name = "Gen" THEN COPY( 'antsInteractivePar.Gen', M.s );  M.class := Objects.String;  M.res := 0
			ELSIF M.name = "isotropic" THEN M.b := obj.isotropic;  M.class := Objects.Bool;  M.res := 0
			ELSIF M.name = "max" THEN M.y := obj.max;  M.class := Objects.LongReal;  M.res := 0
			ELSE vyPort.LayerHandler( obj, M )
			END
		ELSIF M.id = Objects.set THEN
			IF M.name = "max" THEN
				IF M.class = Objects.LongReal THEN obj.max := M.y;  M.res := 0;  vyBase.Update( obj );  END
			ELSE vyPort.LayerHandler( obj, M )
			END

		ELSE vyPort.LayerHandler( obj, M )
		END
	END HandleAttributes;

	PROCEDURE HandleLinks( obj: tLayer;  VAR msg: Objects.LinkMsg );
	BEGIN
		IF (msg.id = Objects.enum) THEN msg.Enum( "Neighbourhood" );  vyPort.LayerHandler( obj, msg )
		ELSIF (msg.id = Objects.get) & (msg.name = "Neighbourhood") THEN msg.obj := obj.n;  msg.res := 0
		ELSIF (msg.id = Objects.set) & ((msg.name = "Neighbourhood") OR (msg.name = "Model")) & (msg.obj # NIL ) &
				(msg.obj IS antsNeighbourhoods.Neighbours) THEN
		ELSE vyPort.LayerHandler( obj, msg )
		END
	END HandleLinks;

	PROCEDURE GHandler*( o: Objects.Object;  VAR msg: Objects.ObjMsg );   (*= layer handling, responsible for messages and vyPort event handling *)
	VAR layer, copy: tLayer;  done: BOOLEAN;
	BEGIN
		ASSERT ( o IS tLayer, 100 );
		layer := o( tLayer );  done := FALSE;
		IF msg IS Display.DisplayMsg THEN
			WITH msg: Display.DisplayMsg DO
			(* IF layer.Edges THEN Recall2(layer) ELSE *)
				Recall( layer );   (*  END;     *) done := TRUE;
			END;
		ELSIF msg IS vyBase.UpdateMessage THEN
			WITH msg: vyBase.UpdateMessage DO vyPort.LayerHandler( o, msg )
			END;
		ELSIF msg IS vyEvents.EventMsg THEN
			WITH msg: vyEvents.EventMsg DO
				IF msg.callForResponder THEN Responsible( layer, msg ) ELSE
					IF (msg.gesture = vyEvents.EvtSelect) OR (msg.gesture = vyEvents.EvtLoc) THEN Select( layer, msg )
					ELSIF msg.gesture = vyEvents.EvtIdent THEN Prompt( layer, msg )
					ELSIF (msg.gesture = vyEvents.EvtWheelDown) OR (msg.gesture = vyEvents.EvtWheelUp) THEN
						Wheel( layer, msg );
					END
				END;
				done := TRUE
			END;
		ELSIF msg IS Objects.CopyMsg THEN
			WITH msg: Objects.CopyMsg DO NEW( copy );  msg.obj := copy;  Copy( layer, msg.obj( tLayer ) );  done := TRUE
			END;
		ELSIF msg IS Objects.FileMsg THEN
			WITH msg: Objects.FileMsg DO HandleFileMsg( layer, msg )
			END;
		ELSIF msg IS Objects.AttrMsg THEN
			WITH msg: Objects.AttrMsg DO HandleAttributes( layer, msg )
			END;
		ELSIF msg IS Objects.LinkMsg THEN
			WITH msg: Objects.LinkMsg DO HandleLinks( layer, msg )
			END;
		ELSIF msg IS Objects.BindMsg THEN
			WITH msg: Objects.BindMsg DO
				IF msg.lib # layer.lib THEN
					vyPort.LayerHandler( layer, msg );  Gadgets.BindObj( layer.n, msg.lib );
					IF (layer.n # NIL ) & (layer.n.handle # NIL ) THEN layer.n.handle( layer.n, msg ) END
				END;
			END;
		ELSIF msg IS vyCommandMenus.enumMsg THEN
			WITH msg: vyCommandMenus.enumMsg DO
				tempLayer := layer;  msg.EnumSender( "", NIL , layer );  msg.Enum( "Write Parameters", WriteOut, layer );
				msg.Enum( "Toggle View Nums", ViewNum, layer );  msg.Enum( "Store Parameters", StorePar, layer );  msg.Enum( "Load Parameters", LoadPar, layer )
			END;
		ELSE
		END;
		IF ~done THEN END
	END GHandler;

	PROCEDURE WriteOut;
	BEGIN
		antsNeighbourhoods.DoWrite( tempLayer.n )
	END WriteOut;

	PROCEDURE ViewNum;
	BEGIN
		tempLayer.viewnum := ~tempLayer.viewnum;  vyBase.Update( tempLayer )
	END ViewNum;

	PROCEDURE openfile( VAR f: Files.File;  name: ARRAY OF CHAR );
	VAR msg: Objects.FileMsg;
	BEGIN
		IF f = NIL THEN RETURN END;
		msg.id := Objects.load;  Files.Set( msg.R, f, 0 );  tempLayer.n.handle( tempLayer.n, msg );
		vyBase.Update( tempLayer.n )
	END openfile;

	PROCEDURE LoadPar;
	BEGIN
		antsToolbox.FileOpen( openfile, "*.antsNpar", "*.antsNpar" )
	END LoadPar;

	PROCEDURE storefile( VAR f: Files.File;  name: ARRAY OF CHAR );
	VAR msg: Objects.FileMsg;
	BEGIN
		IF f = NIL THEN RETURN END;
		msg.id := Objects.store;  Files.Set( msg.R, f, 0 );  tempLayer.n.handle( tempLayer.n, msg );  Files.Register( f )
	END storefile;

	PROCEDURE StorePar;
	BEGIN
		antsToolbox.FileStore( storefile, "*.antsNpar", "*.antsNpar", "antsNpar", "my.antsNpar" )
	END StorePar;

	PROCEDURE Init( layer: tLayer );
	BEGIN
		layer.handle := GHandler;  layer.commands := NIL;  vyCommandMenus.Add( layer.commands, WriteOut, "WriteParameters" );
		vyCommandMenus.Add( layer.commands, ViewNum, "Nums" );  vyCommandMenus.Add( layer.commands, StorePar, "Store Parameters" );
		vyCommandMenus.Add( layer.commands, LoadPar, "Load Parameters" )
	END Init;

	PROCEDURE AdjustXY( layer: tLayer );
	VAR i, j: SIGNED32;
	BEGIN
		layer.maxx := 0;  layer.maxy := 0;
		FOR i := 0 TO layer.n.dim - 1 DO
			FOR j := 0 TO layer.n.count[i] - 1 DO
				IF layer.n.x[i, j] > layer.maxx THEN layer.maxx := layer.n.x[i, j] END;
				IF layer.n.y[i, j] > layer.maxy THEN layer.maxy := layer.n.y[i, j] END
			END
		END
	END AdjustXY;

	PROCEDURE OpenLayer( layer: tLayer;  n: antsNeighbourhoods.Neighbours );
	VAR name: vyName.tNameArray;
	BEGIN
		vyName.GetObjId( n, name );  vyHostStrings.Append( name, "dim:" );  vyHostStrings.AppendInt( n.dim, 2, name );
		vyPort.OpenLayer( layer, name );  Init( layer );  layer.style.fcol := vyGraphBase.black;
		layer.style.fillcol := vyGraphBase.yellow;  layer.style.selectcol := vyGraphBase.red;  layer.n := n;  layer.dim := n.dim;
		layer.isotropic := n.isotropic;  AdjustXY( layer );  vyBase.Subscribe( layer.n, layer )
	END OpenLayer;

	PROCEDURE Gen*;
	VAR m: tLayer;
	BEGIN
		aM.cmd;  NEW( m );  Init( m );  m.handle := GHandler;  Objects.NewObj := m;  m.viewnum := FALSE;  m.max := 1
	END Gen;

	PROCEDURE NewLayer*( n: antsNeighbourhoods.Neighbours ): tLayer;
	VAR m: tLayer;
	BEGIN
		Gen;  m := Objects.NewObj( tLayer );  OpenLayer( m, n );  RETURN m
	END NewLayer;

	PROCEDURE DoShow*( n: antsNeighbourhoods.Neighbours ): tLayer;
	(*= creates new instance of a layer, calls Open, opens new port and picture, adds layer to picture *)
	VAR port: vyPort.Frame;  picture: vyPort.Picture;  c: vyLayers2d.tCoordinate2d;  layer: tLayer;
	BEGIN
		layer := NewLayer( n );  c := vyLayers2d.NewC2d( -1.2, -1.2, 2.4, 2.4 );  port := vyPort.InsertNewFrame( 150, 150 );
		picture := vyPort.NewP( c );  picture.backGround := vyGraphBase.dgrey;  vyPort.AddPicture( port, picture, 0, 0, 1, 1 );

		vyPort.AddLayer( picture, layer );  RETURN layer
	END DoShow;

	PROCEDURE Show*;
	VAR l: antsCommands.tScanList;  obj: vyBase.Object;  la: tLayer;  n: antsNeighbourhoods.Neighbours;
	BEGIN
		l := antsCommands.ScanFromPar( "name=OBJ" );
		IF antsCommands.ExpectObjectFromKeyword( l, "name", obj ) THEN
			n := obj( antsNeighbourhoods.Neighbours );  la := DoShow( n )
		END
	END Show;

	PROCEDURE ShowP*;
	VAR data: Objects.Object;  editor: tLayer;  name: vyCG.tNameArray;
	BEGIN
		data := vyBase.NextParObj();
		WHILE (data # NIL ) DO
			vyName.GetObjId( data( vyBase.Object ), name );  editor := DoShow( data( antsNeighbourhoods.Neighbours ) );
			data := vyBase.NextParObj()
		END
	END ShowP;


(* Set Focus on Interactive Par Layer, then call antsInteractivePar.ToggleDisable (num) to disable interaction and parameter (num)
[functionality to make panels easier to understand,  general method would be to kick off parameter (num) beforehand!!]
*)
	PROCEDURE ToggleDisable*;
	VAR layer: tLayer;  l: vyPort.tLayer;  num: SIGNED32;
	BEGIN
		l := vyPort.FocusLayer();

		IF (l # NIL ) & (l IS tLayer) THEN
			layer := l( tLayer );  antsCommands.InitScan( "num=INT" );
			IF antsCommands.ExpectNumber( "num", num ) THEN
				IF layer.n.par[num] # MIN( FLOAT64 ) THEN layer.n.par[num] := MIN( FLOAT64 ) ELSE layer.n.par[num] := 0 END
			END
		END
	END ToggleDisable;

BEGIN
	aM.launch;
END antsInteractivePar.

System.Free antsInteractivePar antsMessages ~

antsInteractivePar.New > name testit > size 3 ~    > nonisotropic ~
vyScale.Insert
antsInteractivePar.Read > name testit > pars 0 0.1 0.2 - 0.8 - 0.3 > nonisotropic~
antsInteractivePar.Write > name testit ~

