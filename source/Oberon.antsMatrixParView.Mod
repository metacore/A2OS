MODULE antsMatrixParView IN Oberon;   (** fof  **)
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
	vyHostStrings, vyRectangles, vyCG := vyName, antsCommands, vyLayers2d := vyDisplay2d, antsMatrixPar, aM := antsMessages;

TYPE


	(** Layer definition *)
	tLayer* = POINTER TO tLayerDesc;
	tLayerDesc* = RECORD (vyPort.tLayerDesc);
		n-: antsMatrixPar.Matrix;
		commands: vyCommandMenus.List;
		viewnum: BOOLEAN;
		symmetric: BOOLEAN;
		method: INTEGER
	END;
VAR
	tempLayer: tLayer;

	PROCEDURE Recall( layer: tLayer );
	VAR cells: LONGINT;  cellsize: LONGREAL;  i, j: LONGINT;
		str: ARRAY 20 OF CHAR;

		PROCEDURE PaintCell( x, y: LONGINT;  val: LONGREAL );
		BEGIN
			vyHostStrings.RealToFixStr( val, str, 1, 2, 0 );
			IF val < 0 THEN val := -val;  vyGraphBase.SetForeColor( layer.style.selectcol )
			ELSE vyGraphBase.SetForeColor( layer.style.fcol )
			END;
			vyGraphBase.SetBackColor( layer.style.fillcol );

			vyGraphBase.EraseRect2d( x * cellsize - cellsize / 2, y * cellsize - cellsize / 2, cellsize, cellsize );

			CASE layer.method OF
			0:     vyGraphBase.FillRect2d( x * cellsize -  (* val * *) cellsize / 2, y * cellsize - val * cellsize / 2,  (* val * *) cellsize,
															val * cellsize );
			| 1:   vyGraphBase.FillRect2d( x * cellsize - val * cellsize / 2, y * cellsize - val * cellsize / 2, val * cellsize,
															 val * cellsize );
			| 2:   vyGraphBase.FillRect2d( x * cellsize - cellsize / 2, y * cellsize - cellsize / 2, cellsize, val * cellsize )
			END;

			vyGraphBase.SetForeColor( layer.style.fcol );
			vyGraphBase.FrameRect2d( x * cellsize - cellsize / 2, y * cellsize - cellsize / 2, cellsize, cellsize );
			IF layer.viewnum THEN
				vyGraphBase.SetForeColor( vyGraphBase.blue );  vyGraphBase.String2d( x * cellsize, y * cellsize, "Syntax8.Scn.Fnt", str )
			END
		END PaintCell;

	BEGIN
		vyGraphBase.SetStringJustification( vyGraphBase.center, vyGraphBase.center );
		(*
	IF (layer.dim # layer.n.dim) OR (layer.isotropic # layer.n.isotropic) THEN
	layer.dim := layer.n.dim;   layer.isotropic := layer.n.isotropic;
	AdjustXY(layer)
	END;
	*)
		vyGraphBase.SetForeColor( layer.style.fcol );
		IF layer.n.dimx > layer.n.dimy THEN cells := layer.n.dimx ELSE cells := layer.n.dimy END;
		cellsize := 1 / (cells + 1);

		FOR i := 0 TO layer.n.dimy - 1 DO
			FOR j := 0 TO layer.n.dimx - 1 DO PaintCell( j, -i, layer.n.par[i, j] ) END
		END
	END Recall;

	PROCEDURE Responsible( layer: tLayer;  VAR event: vyEvents.EventMsg );
	VAR priority: INTEGER;
	BEGIN
		priority := vyEvents.PrioNone;
		IF ((event.gesture = vyEvents.EvtSelect) OR (event.gesture = vyEvents.EvtIdent)) THEN priority := vyEvents.PrioNormal END;
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

	PROCEDURE Select( layer: tLayer;  VAR event: vyEvents.EventMsg );
	VAR cells: LONGINT;  cellsize: LONGREAL;  i, j: LONGINT;  origx, origy: INTEGER;

		PROCEDURE InCell( x, y: LONGINT;  cx, cy: INTEGER ): BOOLEAN;
		VAR rx, ry, rw, rh: INTEGER;
		BEGIN
			vyGraphBase.Rect2dToRect( x * cellsize - cellsize / 2, y * cellsize - cellsize / 2, cellsize, cellsize, rx, ry, rw, rh );
			IF vyRectangles.PointInRect( cx, cy, rx, ry, rw, rh ) THEN RETURN TRUE ELSE RETURN FALSE END
		END InCell;

	BEGIN
		IF layer.n.dimx > layer.n.dimy THEN cells := layer.n.dimx ELSE cells := layer.n.dimy END;
		cellsize := 1 / (cells + 1);

		FOR i := 0 TO layer.n.dimy - 1 DO
			FOR j := 0 TO layer.n.dimx - 1 DO
				IF InCell( j, -i, event.x, event.y ) THEN
					origx := event.x;  origy := event.y;
					WHILE (event.gesture = vyEvents.EvtSelect) DO
						vyEvents.GetEvent( event );  layer.n.par[i, j] := (event.x - origx) / 100;
						IF ABS( event.x - origx ) < ABS( event.y - origy ) THEN
							layer.n.par[i, j] := ABS( layer.n.par[i, j] ) / layer.n.par[i, j] * ABS( event.y - origy ) / 100
						END;
						IF layer.n.par[i, j] > 1 THEN layer.n.par[i, j] := 1
						ELSIF layer.n.par[i, j] < -1 THEN layer.n.par[i, j] := -1
						END;
						IF (layer.symmetric) & (j < layer.n.dimy) & (i < layer.n.dimx) THEN layer.n.par[j, i] := layer.n.par[i, j] END;
						vyBase.Update( layer )
					END
				END
			END
		END


		(*
	FOR i := 0 TO layer.n.dim - 1 DO
	FOR j := 0 TO layer.n.count[i] - 1 DO
	IF InCell(layer.n.x[i, j], layer.n.y[i, j], event.x, event.y) THEN
	origx := event.x;   origy := event.y;
	WHILE(event.gesture = vyEvents.EvtSelect) DO
	vyEvents.GetEvent(event);
	layer.n.par[i] := (event.x - origx) / 100;
	IF ABS(event.x - origx) < ABS(event.y - origy) THEN
	layer.n.par[i] := ABS(layer.n.par[i]) / layer.n.par[i] * ABS(event.y - origy) / 100
	END;
	IF layer.n.par[i] > 1 THEN layer.n.par[i] := 1
	ELSIF layer.n.par[i] < - 1 THEN layer.n.par[i] := - 1 END;
	vyBase.Update(layer)
	END
	END
	END
	END;
	antsNeighbourhoods.FillCache(layer.n); vyBase.Update(layer.n);
	*)
	END Select;

	PROCEDURE HandleFileMsg( obj: tLayer;  VAR msg: Objects.FileMsg );
	VAR objsub: Objects.Object;  version: INTEGER;

	BEGIN
		IF msg.id = Objects.load THEN
			Files.ReadInt( msg.R, version );  vyPort.LayerHandler( obj, msg );  Gadgets.ReadRef( msg.R, obj.lib, objsub );
			IF objsub # NIL THEN obj.n := objsub( antsMatrixPar.Matrix ) END

		ELSIF msg.id = Objects.store THEN
			Files.WriteInt( msg.R, 0 );  vyPort.LayerHandler( obj, msg );  Gadgets.WriteRef( msg.R, obj.lib, obj.n )
		ELSE vyPort.LayerHandler( obj, msg )
		END
	END HandleFileMsg;

	PROCEDURE HandleAttributes( obj: tLayer;  VAR M: Objects.AttrMsg );
	BEGIN
		IF M.id = Objects.enum THEN M.Enum( "Gen" );  M.Enum( "isotropic" );  vyPort.LayerHandler( obj, M )
		ELSIF M.id = Objects.get THEN
			IF M.name = "Gen" THEN COPY( 'antsMatrixParView.Gen', M.s );  M.class := Objects.String;  M.res := 0 ELSE vyPort.LayerHandler( obj, M ) END
		ELSIF M.id = Objects.set THEN vyPort.LayerHandler( obj, M )

		ELSE vyPort.LayerHandler( obj, M )
		END
	END HandleAttributes;

	PROCEDURE HandleLinks( obj: tLayer;  VAR msg: Objects.LinkMsg );
	BEGIN
		IF (msg.id = Objects.enum) THEN msg.Enum( "Neighbourhood" );  vyPort.LayerHandler( obj, msg )
		ELSIF (msg.id = Objects.get) & (msg.name = "Neighbourhood") THEN msg.obj := obj.n;  msg.res := 0
		ELSIF (msg.id = Objects.set) & ((msg.name = "Neighbourhood") OR (msg.name = "Model")) & (msg.obj # NIL ) & (msg.obj IS antsMatrixPar.Matrix) THEN
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
					IF msg.gesture = vyEvents.EvtSelect THEN Select( layer, msg )
					ELSIF msg.gesture = vyEvents.EvtIdent THEN Prompt( layer, msg )
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
				END
			END;
		ELSE
		END;
		IF ~done THEN END
	END GHandler;

	PROCEDURE WriteOut;
	BEGIN
		antsMatrixPar.DoWrite( tempLayer.n )
	END WriteOut;

	PROCEDURE ViewNum;
	BEGIN
		tempLayer.viewnum := ~tempLayer.viewnum;  vyBase.Update( tempLayer )
	END ViewNum;

	PROCEDURE IncMethod;
	BEGIN
		INC( tempLayer.method );
		IF tempLayer.method > 2 THEN tempLayer.method := 2 END;
		vyBase.Update( tempLayer )
	END IncMethod;

	PROCEDURE ToggleSymmetry;
	BEGIN
		tempLayer.symmetric := ~tempLayer.symmetric;
		IF tempLayer.symmetric THEN antsMatrixPar.Symmetry( tempLayer.n ) END;
		vyBase.Update( tempLayer )
	END ToggleSymmetry;

	PROCEDURE DecMethod;
	BEGIN
		DEC( tempLayer.method );
		IF tempLayer.method < 0 THEN tempLayer.method := 0 END;
		vyBase.Update( tempLayer )
	END DecMethod;

	PROCEDURE L0;
	BEGIN
		antsMatrixPar.L0( tempLayer.n );  vyBase.Update( tempLayer )
	END L0;

	PROCEDURE L1;
	BEGIN
		antsMatrixPar.L1( tempLayer.n );  vyBase.Update( tempLayer )
	END L1;

	PROCEDURE L2;
	BEGIN
		antsMatrixPar.L2( tempLayer.n );  vyBase.Update( tempLayer )
	END L2;

	PROCEDURE Init( layer: tLayer );
	BEGIN
		layer.handle := GHandler;  layer.commands := NIL;  vyCommandMenus.Add( layer.commands, L0, "L0" );
		vyCommandMenus.Add( layer.commands, L1, "L1" );  vyCommandMenus.Add( layer.commands, L2, "L2" );
		vyCommandMenus.Add( layer.commands, DecMethod, "prev Method" );  vyCommandMenus.Add( layer.commands, IncMethod, "next Method" );
		vyCommandMenus.Add( layer.commands, WriteOut, "WriteParameters" );  vyCommandMenus.Add( layer.commands, ToggleSymmetry, "Symmetry on/off" );
		vyCommandMenus.Add( layer.commands, ViewNum, "Nums" )
	END Init;

	PROCEDURE AdjustXY( layer: tLayer );
	(*
	BEGIN
	layer.maxx := 0;   layer.maxy := 0;
	FOR i := 0 TO layer.n.dim - 1 DO
	FOR j := 0 TO layer.n.count[i] - 1 DO
	IF layer.n.x[i, j] > layer.maxx THEN layer.maxx := layer.n.x[i, j] END;
	IF layer.n.y[i, j] > layer.maxy THEN layer.maxy := layer.n.y[i, j] END
	END
	END
	*)
	END AdjustXY;

	PROCEDURE OpenLayer( layer: tLayer;  n: antsMatrixPar.Matrix );
	VAR name: vyName.tNameArray;
	BEGIN
		vyName.GetObjId( n, name );  vyHostStrings.Append( name, "V" );  vyPort.OpenLayer( layer, name );  Init( layer );
		layer.style.fcol := vyGraphBase.black;  layer.style.fillcol := vyGraphBase.yellow;
		layer.style.selectcol := vyGraphBase.red;  layer.n := n;  AdjustXY( layer );  vyBase.Subscribe( layer.n, layer )
	END OpenLayer;

	PROCEDURE Gen*;
	VAR m: tLayer;
	BEGIN
		aM.cmd;  NEW( m );  Init( m );  m.handle := GHandler;  Objects.NewObj := m;  m.viewnum := FALSE;  m.symmetric := TRUE;
		m.method := 0
	END Gen;

	PROCEDURE NewLayer*( n: antsMatrixPar.Matrix ): tLayer;
	VAR m: tLayer;
	BEGIN
		Gen;  m := Objects.NewObj( tLayer );  OpenLayer( m, n );  RETURN m
	END NewLayer;

	PROCEDURE DoShow*( n: antsMatrixPar.Matrix ): tLayer;
	(*= creates new instance of a layer, calls Open, opens new port and picture, adds layer to picture *)
	VAR port: vyPort.Frame;  picture: vyPort.Picture;  c: vyLayers2d.tCoordinate2d;  layer: tLayer;
	BEGIN
		layer := NewLayer( n );  c := vyLayers2d.NewC2d( -1.2, -1.2, 2.4, 2.4 );  port := vyPort.InsertNewFrame( 150, 150 );
		picture := vyPort.NewP( c );  picture.backGround := vyGraphBase.dgrey;  vyPort.AddPicture( port, picture, 0, 0, 1, 1 );

		vyPort.AddLayer( picture, layer );  RETURN layer
	END DoShow;

	PROCEDURE Show*;
	VAR l: antsCommands.tScanList;  obj: vyBase.Object;  la: tLayer;  n: antsMatrixPar.Matrix;
	BEGIN
		l := antsCommands.ScanFromPar( "name=OBJ" );
		IF antsCommands.ExpectObjectFromKeyword( l, "name", obj ) THEN n := obj( antsMatrixPar.Matrix );  la := DoShow( n ) END
	END Show;

	PROCEDURE ShowP*;
	VAR data: Objects.Object;  editor: tLayer;  name: vyCG.tNameArray;
	BEGIN
		data := vyBase.NextParObj();
		WHILE (data # NIL ) DO
			vyName.GetObjId( data( vyBase.Object ), name );  editor := DoShow( data( antsMatrixPar.Matrix ) );
			data := vyBase.NextParObj()
		END
	END ShowP;

BEGIN
	aM.launch
END antsMatrixParView.

System.Free antsMatrixParView antsMatrixPar~

antsMatrixPar.New matrix ~
antsMatrixParView.Show matrix ~
antsObjects.WriteAttributes matrix ~
