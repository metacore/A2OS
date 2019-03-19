MODULE antsNDistrView IN Oberon;   (** fof  **)
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



IMPORT vyPort, Objects, antsArrayObjects, vyName, vyBase, vyGraphBase, Display, vyEvents, Files, Gadgets,
	antsViews, vyHostStrings, antsCommands, vyLayers2d := vyDisplay2d, antsNeighbourhoods, antsRegions, antsFunctions, aM := antsMessages;

TYPE


	(** Layer definition *)

	tLayer* = POINTER TO tLayerDesc;
	tLayerDesc* = RECORD (antsViews.tLayerDesc);
		n-: antsNeighbourhoods.Neighbours;
		r-: antsRegions.tRegion;
		mapping: antsFunctions.Function;
		maxx, maxy: LONGINT;
		dim: INTEGER;
		Correlations: POINTER TO ARRAY OF antsArrayObjects.tLONGINTArray;
		isotropic: BOOLEAN
	END;
VAR

	PROCEDURE Recall( layer: tLayer );
	VAR cells: LONGINT;  cellsize: LONGREAL;  i, j: LONGINT;  A: antsArrayObjects.tINTEGERObject;  x, y: LONGINT;  ry, rx: LONGINT;  vx, vn: LONGINT;  rx1, ry1, rx2, ry2: LONGINT;

		PROCEDURE PaintCell( x, y: LONGINT );
		VAR
		BEGIN
			vyGraphBase.SetBackColor( layer.style.fillcol );
			vyGraphBase.EraseRect2d( x * cellsize - cellsize / 2, y * cellsize - cellsize / 2, cellsize, cellsize );
			vyGraphBase.SetForeColor( layer.style.fcol );
			vyGraphBase.FrameRect2d( x * cellsize - cellsize / 2, y * cellsize - cellsize / 2, cellsize, cellsize )
		END PaintCell;

		PROCEDURE PaintCell2( x, y: LONGINT;  C: antsArrayObjects.tLONGINTArray );
		VAR yi, xi: LONGINT;  y0r, x0r, yr, xr, wr, hr: LONGREAL;  maxr: LONGREAL;  col: LONGINT;  index: LONGINT;
		BEGIN
			maxr := 0;
			FOR yi := 0 TO A.depth - 1 DO
				FOR xi := 0 TO A.depth - 1 DO
					IF C[yi, xi] > maxr THEN maxr := C[yi, xi] END
				END
			END;
			wr := cellsize / A.depth;  hr := cellsize / A.depth;  y0r := y * cellsize - cellsize / 2;  x0r := x * cellsize - cellsize / 2;

			FOR yi := 0 TO A.depth - 1 DO
				yr := y0r + yi * hr;
				FOR xi := 0 TO A.depth - 1 DO
					xr := x0r + xi * wr;
					index :=
						255 -
						SHORT( ENTIER( layer.mapping.get( layer.mapping, C[yi, xi] ) / layer.mapping.get( layer.mapping, maxr ) * 255 + 0.5 ) );
					col := layer.pal.dcol[index];  vyGraphBase.SetForeColor( col );  vyGraphBase.FillRect2d( xr, yr, wr, hr )
				END
			END;
			vyGraphBase.SetForeColor( layer.style.selectcol );
			vyGraphBase.FrameRect2d( x * cellsize - cellsize / 2, y * cellsize - cellsize / 2, cellsize, cellsize )

		END PaintCell2;

	BEGIN
		vyGraphBase.SetStringJustification( vyGraphBase.center, vyGraphBase.center );
		IF (layer.dim # layer.n.dim) OR (layer.isotropic # layer.n.isotropic) THEN
			layer.dim := layer.n.dim;  layer.isotropic := layer.n.isotropic;  AdjustXY( layer )
		END;
		vyGraphBase.SetForeColor( layer.style.fcol );
		IF layer.maxx > layer.maxy THEN cells := layer.maxx ELSE cells := layer.maxy END;
		cellsize := 1 / (cells + 1);

		FOR i := 0 TO layer.n.dim - 1 DO
			FOR j := 0 TO layer.n.count[i] - 1 DO PaintCell( layer.n.x[i, j], layer.n.y[i, j] ) END
		END;

		IF (layer.r # NIL ) & (layer.r.dlink # NIL ) THEN A := layer.r.dlink( antsArrayObjects.tINTEGERObject )
		ELSE A := NIL
		END;

		IF A # NIL THEN
			IF (layer.Correlations = NIL ) OR (LEN( layer.Correlations ) # layer.dim) OR (LEN( layer.Correlations[0] ) # A.depth) THEN
				NEW( layer.Correlations, layer.dim );
				FOR i := 0 TO layer.dim - 1 DO NEW( layer.Correlations[i], A.depth, A.depth ) END
			END;

			FOR i := 0 TO layer.dim - 1 DO
				FOR y := 0 TO A.depth - 1 DO
					FOR x := 0 TO A.depth - 1 DO layer.Correlations[i, y, x] := 0 END
				END
			END;

			antsRegions.Get( layer.r, A, rx1, ry1, rx2, ry2 );  rx2 := rx2 + rx1;  ry2 := ry1 + ry2;

			(*rx1 := layer.r.x;
		ry1 := layer.r.y;
		rx2 := layer.r.x+layer.r.w;
		ry2 := layer.r.y+layer.r.h;
		IF rx2<rx1 THEN rx2 := rx1 END;
		IF ry2<ry1 THEN ry2 := ry1  END;
		*)
			FOR y := ry1 TO ry2 DO
				FOR x := rx1 TO rx2 DO
					vx := A.A[y, x];
					FOR i := 0 TO layer.n.dim - 1 DO
						FOR j := 0 TO layer.n.count[i] - 1 DO
							ry := (y + layer.n.y[i, j]) MOD A.h;  rx := (x + layer.n.x[i, j]) MOD A.w;  vn := A.A[ry, rx];
							INC( layer.Correlations[i, vx, vn] )
						END
					END
				END
			END;

			FOR i := 0 TO layer.n.dim - 1 DO
				FOR j := 0 TO layer.n.count[i] - 1 DO PaintCell2( layer.n.x[i, j], layer.n.y[i, j], layer.Correlations[i] ) END
			END

		END

	END Recall;

	PROCEDURE Responsible( layer: tLayer;  VAR event: vyEvents.EventMsg );
	VAR priority: INTEGER;
	BEGIN
		priority := vyEvents.PrioNone;
		IF ((event.gesture = vyEvents.EvtSelect)) THEN priority := vyEvents.PrioNormal END;
		IF event.priority < priority THEN event.responder := layer;  event.priority := priority END
	END Responsible;

	PROCEDURE Copy( source, dest: tLayer );
	BEGIN
		dest^ := source^
	END Copy;

	PROCEDURE Select( layer: tLayer;  VAR event: vyEvents.EventMsg );
	(*	VAR         cells: LONGINT;   cellsize : LONGREAL;   i, j: LONGINT;
	origx, origy: INTEGER;

	PROCEDURE InCell (x, y: LONGINT;   cx, cy: INTEGER ): BOOLEAN;
	VAR rx, ry, rw, rh: INTEGER;
	BEGIN
	vyGraphBase.Rect2dToRect(x * cellsize - cellsize / 2, y * cellsize - cellsize / 2, cellsize, cellsize, rx, ry, rw, rh);
	IF vyRectangles.PointInRect(cx, cy, rx, ry, rw, rh) THEN RETURN TRUE ELSE RETURN FALSE END
	END InCell;

	BEGIN
	IF layer.maxx > layer.maxy THEN
	cells := layer.maxx
	ELSE
	cells := layer.maxy
	END;
	cellsize := 1 / (cells + 1);

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
			Files.ReadInt( msg.R, version );  vyPort.LayerHandler( obj, msg );  Files.ReadLInt( msg.R, obj.maxx );
			Files.ReadLInt( msg.R, obj.maxy );  Files.ReadBool( msg.R, obj.isotropic );
			Gadgets.ReadRef( msg.R, obj.lib, objsub );
			IF objsub # NIL THEN obj.n := objsub( antsNeighbourhoods.Neighbours ) END

		ELSIF msg.id = Objects.store THEN
			Files.WriteInt( msg.R, 0 );  vyPort.LayerHandler( obj, msg );  Files.WriteLInt( msg.R, obj.maxx );
			Files.WriteLInt( msg.R, obj.maxy );  Files.WriteBool( msg.R, obj.isotropic );  Gadgets.WriteRef( msg.R, obj.lib, obj.n )
		ELSE vyPort.LayerHandler( obj, msg )
		END
	END HandleFileMsg;

	PROCEDURE HandleAttributes( obj: tLayer;  VAR M: Objects.AttrMsg );
	BEGIN
		IF M.id = Objects.enum THEN M.Enum( "Gen" );  M.Enum( "isotropic" );  vyPort.LayerHandler( obj, M )
		ELSIF M.id = Objects.get THEN
			IF M.name = "Gen" THEN COPY( 'antsNDistrView.Gen', M.s );  M.class := Objects.String;  M.res := 0
			ELSIF M.name = "isotropic" THEN M.b := obj.isotropic;  M.class := Objects.Bool;  M.res := 0
			ELSE vyPort.LayerHandler( obj, M )
			END
		ELSIF M.id = Objects.set THEN vyPort.LayerHandler( obj, M )

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
				IF msg.callForResponder THEN Responsible( layer, msg );  antsViews.Handler( layer, msg ) ELSE
					IF msg.gesture = vyEvents.EvtSelect THEN
						Select( layer, msg )
						(*
				ELSIF msg.gesture = vyEvents.EvtIdent THEN Prompt (layer, msg)
				*)
					ELSE antsViews.Handler( layer, msg )
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


(*
PROCEDURE WriteOut;
BEGIN
antsNeighbourhoods.DoWrite(tempLayer.n)
END WriteOut;

PROCEDURE ViewNum;
BEGIN
tempLayer.viewnum := ~tempLayer.viewnum;
vyBase.Update(tempLayer);
END ViewNum;
*)

	PROCEDURE Init( layer: tLayer );
	BEGIN
		antsViews.Init( layer );

		layer.handle := GHandler
		(*
	vyCommandMenus.Add(layer.commands, WriteOut, "WriteParameters");
	vyCommandMenus.Add(layer.commands, ViewNum, "Nums");
	*)
	END Init;

	PROCEDURE AdjustXY( layer: tLayer );
	VAR i, j: LONGINT;
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
		vyPort.OpenLayer( layer, name );  Init( layer );  antsViews.DefaultPath( layer, FALSE );

		layer.style.fcol := vyGraphBase.black;  layer.style.fillcol := vyGraphBase.yellow;
		layer.style.selectcol := vyGraphBase.red;  layer.n := n;  layer.dim := n.dim;  layer.isotropic := n.isotropic;
		AdjustXY( layer );  vyBase.Subscribe( layer.n, layer )
	END OpenLayer;

	PROCEDURE Gen*;
	VAR m: tLayer;
	BEGIN
		aM.cmd;  NEW( m );  Init( m );  m.handle := GHandler;  Objects.NewObj := m (* m.viewnum := FALSE; *)
	END Gen;

	PROCEDURE NewLayer*( n: antsNeighbourhoods.Neighbours ): tLayer;
	VAR m: tLayer;
	BEGIN
		Gen;  m := Objects.NewObj( tLayer );  OpenLayer( m, n );  RETURN m
	END NewLayer;

	PROCEDURE DoShow*( n: antsNeighbourhoods.Neighbours;  r: antsRegions.tRegion;  f: antsFunctions.Function ): tLayer;
	(*= creates new instance of a layer, calls Open, opens new port and picture, adds layer to picture *)
	VAR port: vyPort.Frame;  picture: vyPort.Picture;  c: vyLayers2d.tCoordinate2d;  layer: tLayer;
	BEGIN
		layer := NewLayer( n );  layer.r := r;  layer.mapping := f;  c := vyLayers2d.NewC2d( -1.2, -1.2, 2.4, 2.4 );
		port := vyPort.InsertNewFrame( 150, 150 );  picture := vyPort.NewP( c );  picture.backGround := vyGraphBase.dgrey;
		vyPort.AddPicture( port, picture, 0, 0, 1, 1 );

		vyPort.AddLayer( picture, layer );  RETURN layer
	END DoShow;

	PROCEDURE Show*;
	VAR l: antsCommands.tScanList;  r: antsRegions.tRegion;  obj, obj2, obj3: vyBase.Object;  f: antsFunctions.Function;
		la: tLayer;  n: antsNeighbourhoods.Neighbours;
	BEGIN
		l := antsCommands.ScanFromPar( "name=OBJ function=OBJ region=OBJ" );
		IF antsCommands.ExpectObjectFromKeyword( l, "name", obj ) & antsCommands.ExpectObjectFromKeyword( l, "function", obj2 ) &
		    antsCommands.ExpectObjectFromKeyword( l, "region", obj3 ) THEN
			n := obj( antsNeighbourhoods.Neighbours );  f := obj2( antsFunctions.Function );  r := obj3( antsRegions.tRegion );
			antsRegions.Gen;  la := DoShow( n, r, f );
			IF (r # NIL ) & (r.dlink # NIL ) THEN vyBase.Subscribe( r.dlink( vyBase.Object ), la ) END;
			vyBase.Subscribe( f, la );  vyBase.Subscribe( r, la )
		END
	END Show;

	PROCEDURE ShowP*;
	(*
	BEGIN
	data := vyBase.NextParObj();
	WHILE (data # NIL)  DO
	vyName.GetObjId(data(vyBase.Object), name);
	editor := DoShow(data(antsNeighbourhoods.Neighbours),NIL,NIL);
	data := vyBase.NextParObj()
	END
	*)
	END ShowP;

BEGIN
	aM.launch;
END antsNDistrView.

System.Free antsNDistrView  ~

antsNeighbourhoods.New > name myN > size 100 > nonisotropic ~
antsFunctions.Define myF ~
antsFunctions.Set myF x ~
antsRegions.New myR ~
antsNDistrView.Show myN myF myR ~
antsRegions.SelectRegion myR ~

Voyager.Show myN as antsNDistrView ~

antsObjects.WriteAttribute myF Mapping ~
antsObjects.WriteAttribute myN dim ~
antsObjects.WriteAttribute myN isotropic ~
