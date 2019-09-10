MODULE antsMCView IN Oberon;
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




IMPORT antsCommands, aM := antsMessages, vyRandom, vyName, vyBase, Objects, vyGraphBase, vyPort, Display,
	vyDisplay2d, Oberon, Input, Files, Gadgets;

TYPE

	Map* = POINTER TO ARRAY OF SIGNED32;
	Usage* = POINTER TO ARRAY OF BOOLEAN;

	MapQueue* = POINTER TO MapQueueDesc;
	MapQueueDesc* = RECORD
		m: Map;
		u: Usage;
		next: MapQueue;
		coal: BOOLEAN
	END;

	Mapper* = PROCEDURE ( VAR A: ARRAY OF SIGNED32 );
	Matrix* = POINTER TO ARRAY OF ARRAY OF FLOAT64;
	Vector* = POINTER TO ARRAY OF FLOAT64;

	Chain = POINTER TO ChainDesc;
	ChainDesc = RECORD (vyBase.ObjDesc)
		backwards: BOOLEAN;
		q: MapQueue;
		qlen: SIGNED32;
		m: Mapper;
		A, cA: Matrix;
		dim: SIGNED32;
		ran: Vector
	END;

	tLayer* = POINTER TO tLayerDesc;
	tLayerDesc* = RECORD (vyPort.tLayerDesc)
		c: Chain;
		type: SIGNED16
	END;

CONST
	mappertype = 1;  matrixtype = 2;

VAR
	cur: vyBase.Object;  templ: tLayer;  globalCount: SIGNED32;

	PROCEDURE StoreVector( VAR R: Files.Rider;  VAR V: Vector );
	VAR i: SIGNED32;
	BEGIN
		IF V = NIL THEN Files.WriteLInt( R, 0 );  RETURN END;
		Files.WriteLInt( R, LEN( V ) );
		FOR i := 0 TO LEN( V ) - 1 DO Files.WriteLReal( R, V[i] ) END
	END StoreVector;

	PROCEDURE LoadVector( VAR R: Files.Rider;  VAR V: Vector );
	VAR i, w: SIGNED32;
	BEGIN
		Files.ReadLInt( R, w );
		IF w = 0 THEN V := NIL;  RETURN END;
		NEW( V, w );
		FOR i := 0 TO LEN( V ) - 1 DO Files.ReadLReal( R, V[i] ) END
	END LoadVector;

	PROCEDURE StoreMatrix( VAR R: Files.Rider;  VAR M: Matrix );
	VAR i, j: SIGNED32;
	BEGIN
		IF M = NIL THEN Files.WriteLInt( R, 0 );  Files.WriteLInt( R, 0 )
		ELSE
			Files.WriteLInt( R, LEN( M ) );  Files.WriteLInt( R, LEN( M[0] ) );
			FOR i := 0 TO LEN( M ) - 1 DO
				FOR j := 0 TO LEN( M[0] ) - 1 DO Files.WriteLReal( R, M[i, j] ) END
			END
		END
	END StoreMatrix;

	PROCEDURE LoadMatrix( VAR R: Files.Rider;  VAR M: Matrix );
	VAR w, h, i, j: SIGNED32;
	BEGIN
		Files.ReadLInt( R, h );  Files.ReadLInt( R, w );
		IF (h = 0) OR (w = 0) THEN M := NIL;  RETURN END;
		NEW( M, h, w );
		FOR i := 0 TO LEN( M ) - 1 DO
			FOR j := 0 TO LEN( M[0] ) - 1 DO Files.ReadLReal( R, M[i, j] ) END
		END
	END LoadMatrix;

	PROCEDURE StoreMap( VAR R: Files.Rider;  m: Map );
	VAR i: SIGNED32;
	BEGIN
		IF m = NIL THEN Files.WriteLInt( R, 0 )
		ELSE
			Files.WriteLInt( R, LEN( m ) );
			FOR i := 0 TO LEN( m ) - 1 DO Files.WriteLInt( R, m[i] ) END
		END
	END StoreMap;

	PROCEDURE LoadMap( VAR R: Files.Rider;  VAR m: Map );
	VAR len, i: SIGNED32;
	BEGIN
		Files.ReadLInt( R, len );
		IF len = 0 THEN m := NIL
		ELSE
			NEW( m, len );
			FOR i := 0 TO LEN( m ) - 1 DO Files.ReadLInt( R, m[i] ) END
		END
	END LoadMap;

	PROCEDURE StoreUsage( VAR R: Files.Rider;  m: Usage );
	VAR i: SIGNED32;
	BEGIN
		IF m = NIL THEN Files.WriteLInt( R, 0 )
		ELSE
			Files.WriteLInt( R, LEN( m ) );
			FOR i := 0 TO LEN( m ) - 1 DO Files.WriteBool( R, m[i] ) END
		END
	END StoreUsage;

	PROCEDURE LoadUsage( VAR R: Files.Rider;  VAR m: Usage );
	VAR len, i: SIGNED32;
	BEGIN
		Files.ReadLInt( R, len );
		IF len = 0 THEN m := NIL
		ELSE
			NEW( m, len );
			FOR i := 0 TO LEN( m ) - 1 DO Files.ReadBool( R, m[i] ) END
		END
	END LoadUsage;

	PROCEDURE StoreMapQueue( VAR R: Files.Rider;  q: MapQueue );
	BEGIN
		Files.WriteInt( R, 0 );
		WHILE (q # NIL ) DO
			Files.WriteInt( R, 1 );  StoreMap( R, q.m );  StoreUsage( R, q.u );  Files.WriteBool( R, q.coal );  q := q.next
		END;
		Files.WriteInt( R, 0 )
	END StoreMapQueue;

	PROCEDURE LoadMapQueue( VAR R: Files.Rider;  VAR q: MapQueue );
	VAR ver, ident: SIGNED16;  m: MapQueue;
	BEGIN
		Files.ReadInt( R, ver );  Files.ReadInt( R, ident );
		WHILE (ident # 0) DO
			IF m = NIL THEN NEW( m );  q := m ELSE NEW( m.next );  m := m.next END;
			LoadMap( R, m.m );  LoadUsage( R, m.u );  Files.ReadBool( R, m.coal );  Files.ReadInt( R, ident )
		END
	END LoadMapQueue;

	PROCEDURE StoreMapper( VAR R: Files.Rider;  VAR m: Mapper );
	VAR comp: Mapper;
	BEGIN
		comp := DefaultMapper;
		IF m = comp THEN Files.WriteInt( R, 1 );  RETURN END;
		comp := OneRMapper;
		IF m = comp THEN Files.WriteInt( R, 2 );  RETURN END;
		comp := MapperIt;
		IF m = comp THEN Files.WriteInt( R, 2 );  RETURN END;
		Files.WriteInt( R, 0 )
	END StoreMapper;

	PROCEDURE LoadMapper( VAR R: Files.Rider;  VAR m: Mapper );
	VAR type: SIGNED16;
	BEGIN
		Files.ReadInt( R, type );
		IF type = 1 THEN m := DefaultMapper
		ELSIF type = 2 THEN m := OneRMapper
		ELSIF type = 3 THEN m := MapperIt
		END
	END LoadMapper;

	PROCEDURE StoreChain( VAR R: Files.Rider;  VAR c: Chain );
	BEGIN
		Files.WriteInt( R, 0 );  StoreMapQueue( R, c.q );  Files.WriteLInt( R, c.qlen );  StoreMapper( R, c.m );
		StoreMatrix( R, c.A );  StoreMatrix( R, c.cA );  Files.WriteLInt( R, c.dim );  StoreVector( R, c.ran )
	END StoreChain;

	PROCEDURE LoadChain( VAR R: Files.Rider;  VAR c: Chain );
	VAR ver: SIGNED16;
	BEGIN
		Files.ReadInt( R, ver );  LoadMapQueue( R, c.q );  Files.ReadLInt( R, c.qlen );  LoadMapper( R, c.m );
		LoadMatrix( R, c.A );  LoadMatrix( R, c.cA );  Files.ReadLInt( R, c.dim );  LoadVector( R, c.ran )
	END LoadChain;

	PROCEDURE DefaultMapper( VAR m: ARRAY OF SIGNED32 );
	VAR c: Chain;  ran: FLOAT64;  A, cA: Matrix;  i, j: SIGNED32;  dim: SIGNED32;
	BEGIN
		c := cur( Chain );  A := c.A;  cA := c.cA;  dim := c.dim;

		FOR i := 0 TO dim - 1 DO
			ran := vyRandom.Uniform();  c.ran[i] := ran;  j := 0;
			WHILE (ran > cA[i][j]) DO INC( j ) END;
			m[i] := j
		END;
		INC( globalCount )
	END DefaultMapper;

	PROCEDURE OneRMapper( VAR m: ARRAY OF SIGNED32 );
	VAR c: Chain;  ran: FLOAT64;  A, cA: Matrix;  i, j: SIGNED32;  dim: SIGNED32;
	BEGIN
		c := cur( Chain );  A := c.A;  cA := c.cA;  dim := c.dim;  ran := vyRandom.Uniform();
		FOR i := 0 TO dim - 1 DO
			c.ran[i] := ran;
			(* ran := vyRandom.Uniform();    *)
			j := 0;
			WHILE (ran > cA[i][j]) DO INC( j ) END;
			m[i] := j
		END;
		INC( globalCount )
	END OneRMapper;

	PROCEDURE Count( VAR m: ARRAY OF SIGNED32;  dim: SIGNED32 ): SIGNED32;
	VAR used: ARRAY 1024 OF BOOLEAN;
		count, i: SIGNED32;
	BEGIN
		FOR i := 0 TO dim - 1 DO used[i] := FALSE END;
		FOR i := 0 TO dim - 1 DO used[m[i]] := TRUE END;
		FOR i := 0 TO dim - 1 DO
			IF used[i] THEN INC( count ) END
		END;
		RETURN count
	END Count;

	PROCEDURE Copy( VAR from, to: ARRAY OF SIGNED32;  dim: SIGNED32 );
	VAR i: SIGNED32;
	BEGIN
		FOR i := 0 TO dim - 1 DO to[i] := from[i] END
	END Copy;

	PROCEDURE ItApply( VAR m, n: ARRAY OF SIGNED32;  dim: SIGNED32;  count: SIGNED32 );
	VAR icount, i: SIGNED32;
	BEGIN
		FOR i := 0 TO dim - 1 DO n[i] := m[n[i]] END;
		icount := Count( n, dim );  aM.dSI( "Count is", icount );
		IF icount < count THEN ItApply( m, n, dim, icount ) END;
		INC( globalCount )
	END ItApply;

	PROCEDURE MapperIt( VAR m: ARRAY OF SIGNED32 );
	VAR c: Chain;  ran: FLOAT64;  A, cA: Matrix;  i, j: SIGNED32;  dim: SIGNED32;
		n: POINTER TO ARRAY OF SIGNED32;
	BEGIN
		c := cur( Chain );  A := c.A;  cA := c.cA;  dim := c.dim;
		FOR i := 0 TO dim - 1 DO
			ran := vyRandom.Uniform();  c.ran[i] := ran;  j := 0;
			WHILE (ran > cA[i][j]) DO INC( j ) END;
			m[i] := j
		END;
		NEW( n, dim );  Copy( m, n^, dim );  ItApply( m, n^, dim, Count( m, dim ) );  Copy( n^, m, dim )
	END MapperIt;

	PROCEDURE PaintPoint( dim: SIGNED32;  at: SIGNED32;  q: MapQueue );
	VAR i: SIGNED32;  x, y: SIGNED16;
	BEGIN
		vyGraphBase.SetForeColor( templ.style.fcol );
		FOR i := 0 TO dim - 1 DO
			vyGraphBase.Point2dToPoint( at, i, x, y );
			IF (q # NIL ) & (q.u[i] = TRUE ) THEN
				vyGraphBase.SetForeColor( vyGraphBase.blue );  vyGraphBase.PaintRect( x - 1, y - 1, 3, 3 )
			ELSE vyGraphBase.SetForeColor( templ.style.fcol );  vyGraphBase.PaintRect( x - 1, y - 1, 2, 2 )
			END
		END
	END PaintPoint;

	PROCEDURE PaintPoint2( dim: SIGNED32;  at: SIGNED32;  q: MapQueue );
	VAR i: SIGNED32;  x, y: SIGNED16;
	BEGIN
		vyGraphBase.SetForeColor( templ.style.fcol );
		FOR i := 0 TO dim - 1 DO
			vyGraphBase.Point2dToPoint( at, i, x, y );
			IF (q # NIL ) & (q.u[i] = TRUE ) THEN
				vyGraphBase.SetForeColor( templ.style.selectcol );  vyGraphBase.PaintRect( x - 3, y - 3, 6, 6 )
			ELSE vyGraphBase.SetForeColor( templ.style.fcol );  vyGraphBase.PaintRect( x - 1, y - 1, 2, 2 )
			END
		END
	END PaintPoint2;

	PROCEDURE PaintMap( q: MapQueue;  at: SIGNED32 );
	VAR i: SIGNED32;
	BEGIN
		vyGraphBase.SetForeColor( templ.style.fillcol );
		FOR i := 0 TO LEN( q.m ) - 1 DO
			IF q.u[i] = FALSE THEN vyGraphBase.Line2d( at, i, at + 1, q.m[i] ) END
		END;
		vyGraphBase.SetForeColor( templ.style.selectcol );
		FOR i := 0 TO LEN( q.m ) - 1 DO
			IF q.u[i] = TRUE THEN vyGraphBase.Line2d( at, i, at + 1, q.m[i] ) END
		END
	END PaintMap;

	PROCEDURE PaintChain( c: Chain );
	VAR at: SIGNED32;  q: MapQueue;
	BEGIN
		IF c.backwards THEN at := -c.qlen;  ELSE at := 0 END;
		q := c.q;
		WHILE (q.next # NIL ) DO PaintMap( q, at );  PaintPoint( c.dim, at, q );  INC( at );  q := q.next END;
		IF c.q.coal THEN PaintPoint2( c.dim, 0, q ) ELSE PaintPoint( c.dim, 0, q ) END
	END PaintChain;

	PROCEDURE PaintMatrix( c: Chain );
	VAR x, y: SIGNED16;  i, j: SIGNED16;  q: MapQueue;
	BEGIN
		IF c.backwards THEN q := c.q
		ELSE
			q := c.q;
			IF q.next # NIL THEN
				WHILE (q.next.next # NIL ) DO q := q.next END;
			END;
		END;
		FOR i := 0 TO SHORT( c.dim ) - 1 DO
			FOR j := 0 TO SHORT( c.dim ) - 1 DO
				vyGraphBase.SetForeColor( templ.style.selectcol );
				IF q.m[i] = j THEN
					IF j = 0 THEN
						vyGraphBase.FillRect2d( 0, i - 0.25, c.cA[i, j], 0.5 );  vyGraphBase.SetForeColor( templ.style.fillcol );
						vyGraphBase.Point2dToPoint( 0, i, x, y );  vyGraphBase.Line( x, y - 2, x, y + 2 );
					ELSE
						vyGraphBase.FillRect2d( c.cA[i, j - 1], i - 0.25, c.cA[i, j] - c.cA[i, j - 1], 0.5 );
						vyGraphBase.SetForeColor( templ.style.fillcol );  vyGraphBase.Point2dToPoint( c.cA[i, j - 1], i, x, y );
						vyGraphBase.Line( x, y - 2, x, y + 2 );
					END;
					vyGraphBase.SetForeColor( templ.style.selectcol );
					vyGraphBase.FillRect2d( 1.1 + (j) / c.dim, i - 0.25, 1 / c.dim, 0.5 )
				END;
				vyGraphBase.SetForeColor( templ.style.fillcol );  vyGraphBase.Point2dToPoint( c.cA[i, j], i, x, y );
				vyGraphBase.Line( x, y - 2, x, y + 2 );  vyGraphBase.Point2dToPoint( 1.1 + j / c.dim, i, x, y );
				vyGraphBase.Line( x, y - 2, x, y + 2 )
			END;
			vyGraphBase.SetForeColor( templ.style.fcol );  vyGraphBase.Line2d( 0, i, 1, i );  vyGraphBase.Line2d( 1.1, i, 2.1, i );
			vyGraphBase.SetForeColor( templ.style.fillcol );  vyGraphBase.Point2dToPoint( 0, i, x, y );
			vyGraphBase.Line( x, y - 2, x, y + 2 );  vyGraphBase.Point2dToPoint( 1, i, x, y );
			vyGraphBase.Line( x, y - 2, x, y + 2 );  vyGraphBase.Point2dToPoint( c.ran[i], i, x, y );
			vyGraphBase.SetForeColor( templ.style.fcol );  vyGraphBase.Line2d( c.ran[i], i - 0.5, c.ran[i], i + 0.5 )

		END;
		FOR j := 0 TO SHORT( c.dim ) - 1 DO
			vyGraphBase.SetForeColor( templ.style.fcol );  vyGraphBase.Point2dToPoint( 2.2, j, x, y );
			vyGraphBase.FillRect( x - 1, y - 1, 3, 3 );  vyGraphBase.Point2dToPoint( 2.3, j, x, y );
			vyGraphBase.FillRect( x - 1, y - 1, 3, 3 );  vyGraphBase.SetForeColor( templ.style.fillcol );
			vyGraphBase.Line2d( 2.2, j, 2.3, q.m[j] )
			(*
		vyGraphBase.Line2d(
		*)
		END
	END PaintMatrix;

	PROCEDURE Recall( layer: tLayer );
	BEGIN
		templ := layer;
		IF layer.type = mappertype THEN PaintChain( layer.c )
		ELSIF layer.type = matrixtype THEN PaintMatrix( layer.c )
		END
	END Recall;

	PROCEDURE HandleFileMsg( obj: tLayer;  VAR msg: Objects.FileMsg );
	VAR objsub: Objects.Object;  version: SIGNED16;

	BEGIN
		IF msg.id = Objects.load THEN
			Files.ReadInt( msg.R, version );  vyPort.LayerHandler( obj, msg );  Files.ReadInt( msg.R, obj.type );
			Gadgets.ReadRef( msg.R, obj.lib, objsub );
			IF objsub # NIL THEN obj.c := objsub( Chain ) END
		ELSIF msg.id = Objects.store THEN
			Files.WriteInt( msg.R, 0 );  vyPort.LayerHandler( obj, msg );  Files.WriteInt( msg.R, obj.type );
			Gadgets.WriteRef( msg.R, obj.lib, obj.c )
		ELSE vyPort.LayerHandler( obj, msg )
		END
	END HandleFileMsg;

	PROCEDURE HandleAttributes( obj: tLayer;  VAR M: Objects.AttrMsg );
	BEGIN
		IF M.id = Objects.enum THEN M.Enum( "Gen" );  vyPort.LayerHandler( obj, M )
		ELSIF M.id = Objects.get THEN
			IF M.name = "Gen" THEN COPY( 'antsMCView.GenL', M.s );  M.class := Objects.String;  M.res := 0 ELSE vyPort.LayerHandler( obj, M ) END
		ELSE vyPort.LayerHandler( obj, M )
		END
	END HandleAttributes;

	PROCEDURE HandleLinks( obj: tLayer;  VAR msg: Objects.LinkMsg );
	BEGIN
		IF (msg.id = Objects.enum) THEN msg.Enum( "Chain" );  vyPort.LayerHandler( obj, msg )
		ELSIF (msg.id = Objects.get) & (msg.name = "Chain") THEN msg.obj := obj.c;  msg.res := 0
		ELSIF (msg.id = Objects.set) THEN vyPort.LayerHandler( obj, msg )
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
		ELSIF msg IS Objects.CopyMsg THEN
			WITH msg: Objects.CopyMsg DO NEW( copy );  msg.obj := copy;  msg.obj( tLayer )^ := layer^;  done := TRUE
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
				IF msg.lib # layer.lib THEN vyPort.LayerHandler( layer, msg );  Gadgets.BindObj( layer.c, msg.lib ) END
			END;
		ELSE
		END;
		IF ~done THEN END
	END GHandler;

	PROCEDURE Open*( chart: tLayer;  data: Objects.Object );
	VAR id: vyName.tNameArray;
	BEGIN
		chart.c := data( Chain );  id := "MCView";  vyPort.OpenLayer( chart, id );  chart.handle := GHandler;
		vyBase.Subscribe( chart.c, chart )
	END Open;

	PROCEDURE ShowP*;
	VAR chart: tLayer;  data: Objects.Object;  pic: vyPort.Picture;  c: vyDisplay2d.tCoordinate2d;
	BEGIN
		aM.S( "ShowP is called" );  data := vyBase.NextParObj();
		WHILE (data # NIL ) DO

			NEW( chart );  Open( chart, data );  c := vyDisplay2d.NewC2d( -20, 0, 20, chart.c.dim );
			pic := vyPort.InsertNewCPicture( 0, 0, 1, 1, c );  chart.style.fcol := vyGraphBase.black;
			chart.style.selectcol := vyGraphBase.red;  chart.style.fillcol := vyGraphBase.mgrey;  chart.type := mappertype;
			vyPort.AddLayer( pic, chart );

			Objects.NewObj := pic;  data := vyBase.NextParObj()
		END
	END ShowP;

	PROCEDURE ShowMatrix*;
	VAR l: antsCommands.tScanList;  obj: vyBase.Object;  pic: vyPort.Picture;  c: vyDisplay2d.tCoordinate2d;  chart: tLayer;
	BEGIN
		l := antsCommands.ScanFromPar( "name=OBJ" );
		IF antsCommands.ExpectObjectFromKeyword( l, "name", obj ) THEN
			NEW( chart );  Open( chart, obj( Chain ) );  c := vyDisplay2d.NewC2d( 0, 0, 2.3, chart.c.dim );
			pic := vyPort.InsertNewCPicture( 0, 0, 1, 1, c );  chart.style.fcol := vyGraphBase.black;
			chart.style.selectcol := vyGraphBase.red;  chart.style.fillcol := vyGraphBase.blue;  chart.type := matrixtype;
			vyPort.AddLayer( pic, chart );

			Objects.NewObj := pic
		END
	END ShowMatrix;

	PROCEDURE cHandler( o: Objects.Object;  VAR M: Objects.ObjMsg );
	BEGIN
		WITH o: Chain DO
			IF M IS Objects.AttrMsg THEN
				WITH M: Objects.AttrMsg DO
					IF M.id = Objects.get THEN
						IF M.name = "Gen" THEN COPY( "antsMCView.Gen", M.s );  M.class := Objects.String;  M.res := 0;  RETURN ELSE vyBase.objecthandle( o, M ) END
					ELSE vyBase.objecthandle( o, M )
					END;
				END;
			ELSIF M IS Objects.FileMsg THEN
				WITH M: Objects.FileMsg DO
					IF M.id = Objects.load THEN vyBase.objecthandle( o, M );  LoadChain( M.R, o )
					ELSIF M.id = Objects.store THEN vyBase.objecthandle( o, M );  StoreChain( M.R, o )
					END
				END;
			ELSE vyBase.objecthandle( o, M )
			END
		END
	END cHandler;

	PROCEDURE Gen*;
	VAR c: Chain;
	BEGIN
		aM.cmd;  NEW( c );  c.backwards := TRUE;  c.handle := cHandler;  Objects.NewObj := c
	END Gen;

	PROCEDURE GenL*;
	VAR l: tLayer;
	BEGIN
		NEW( l );  l.handle := GHandler;  Objects.NewObj := l
	END GenL;

	PROCEDURE New*;
	VAR l: antsCommands.tScanList;  name: vyName.tNameArray;  c: Chain;
	BEGIN
		l := antsCommands.ScanFromPar( "name=NAME" );
		IF antsCommands.ExpectNameFromKeyword( l, "name", name ) THEN
			Gen;  c := Objects.NewObj( Chain );  vyName.RegisterNamed( c, name );  c.m := DefaultMapper;
			c.m := OneRMapper
		END
	END New;

	PROCEDURE SetMapper*;
	VAR l: antsCommands.tScanList;  obj: vyBase.Object;  c: Chain;
	BEGIN
		l := antsCommands.ScanFromPar( "name=OBJ [>independent|>oneR|mapperIt]" );
		IF ~antsCommands.ExpectObjectFromKeyword( l, "name", obj ) THEN RETURN END;
		c := obj( Chain );
		IF antsCommands.FindKeyword( l, "independent" ) THEN c.m := DefaultMapper
		ELSIF antsCommands.FindKeyword( l, "oneR" ) THEN c.m := OneRMapper
		ELSIF antsCommands.FindKeyword( l, "mapperIt" ) THEN c.m := MapperIt
		ELSE aM.S( "use keywords  'oneR' or 'independent'" )
		END
	END SetMapper;

	PROCEDURE NewQueue( dim: SIGNED32 ): MapQueue;
	VAR q: MapQueue;  i: SIGNED32;
	BEGIN
		NEW( q );  NEW( q.m, dim );  NEW( q.u, dim );
		FOR i := 0 TO dim - 1 DO q.u[i] := TRUE END;
		q.coal := FALSE;  RETURN q
	END NewQueue;

	PROCEDURE Init*;
	VAR l: antsCommands.tScanList;  obj: vyBase.Object;  dim: SIGNED32;  A, cA: Matrix;  c: Chain;  i, j: SIGNED32;  sum: FLOAT64;
	BEGIN
		l := antsCommands.ScanFromPar( "name=OBJ [dim=INT]" );
		IF ~antsCommands.ExpectObjectFromKeyword( l, "name", obj ) THEN RETURN END;
		c := obj( Chain );
		IF antsCommands.GetNumberFromKeyword( l, "dim", dim ) THEN

			NEW( A, dim, dim );

			IF antsCommands.FindKeyword( l, "const" ) THEN
				FOR i := 0 TO dim - 1 DO
					FOR j := 0 TO dim - 1 DO A[i, j] := 1 / dim END
				END
			ELSIF antsCommands.FindKeyword( l, "random" ) THEN
				FOR i := 0 TO dim - 1 DO
					FOR j := 0 TO dim - 1 DO A[i, j] := vyRandom.Uniform() END
				END;
				FOR i := 0 TO dim - 1 DO
					sum := 0;
					FOR j := 0 TO dim - 1 DO sum := sum + A[i, j] END;
					FOR j := 0 TO dim - 1 DO A[i, j] := A[i, j] / sum END
				END
			ELSE
				FOR i := 0 TO dim - 1 DO
					FOR j := 0 TO dim - 1 DO
						IF ~antsCommands.ExpectRealFromKeyword( l, "A", A[i, j] ) THEN RETURN END
					END
				END
			END;
			c.A := A;  cA := c.cA;
			IF (cA = NIL ) OR (LEN( cA ) # LEN( A )) THEN NEW( cA, LEN( A ), LEN( A ) );  c.cA := cA (* create cumulative transition matrix *) END;
			(* calculate cum distr matrix *)
			FOR i := 0 TO LEN( A ) - 1 DO
				cA[i][0] := A[i][0];
				FOR j := 1 TO LEN( A ) - 1 DO cA[i][j] := cA[i][j - 1] + A[i][j] END;
				IF ABS( cA[i][LEN( A ) - 1] - 1 ) > 0.000001 THEN aM.SI( "Matrix is no transition probability, problem in Line", i ) ELSE cA[i][LEN( A ) - 1] := 1 END
			END

		ELSE
			IF c.A = NIL THEN aM.S( "Need a dimension" );  RETURN END;
			dim := LEN( c.A )
		END;

		NEW( c.ran, dim );  c.dim := dim;  c.q := NewQueue( dim );  c.qlen := 0;
		IF ~antsCommands.Find( "noupdate" ) THEN vyBase.Update( c );  END;
		globalCount := 0
	END Init;

	PROCEDURE Check*;
	VAR l: antsCommands.tScanList;  c: Chain;  obj: vyBase.Object;  i, j: SIGNED32;
	BEGIN
		l := antsCommands.ScanFromPar( "name=OBJ" );
		IF antsCommands.ExpectObjectFromKeyword( l, "name", obj ) THEN
			c := obj( Chain );
			FOR i := 0 TO c.dim - 1 DO
				FOR j := 0 TO c.dim - 1 DO
					aM.SISI( "at pos", i, ",", j );  aM.SR( "Value: ", c.A[i, j] );
					IF c.cA # NIL THEN aM.SR( "cumulative", c.cA[i, j] ) END
				END
			END
		END
	END Check;

	PROCEDURE SetQUsage( first: MapQueue );
	VAR q: MapQueue;  next: MapQueue;  dim: SIGNED32;  i: SIGNED32;  count: SIGNED32;
	BEGIN
		ASSERT ( first # NIL );
		q := first;  dim := LEN( q.m );  next := q.next;

		WHILE (next # NIL ) DO
			FOR i := 0 TO dim - 1 DO next.u[i] := FALSE END;
			FOR i := 0 TO dim - 1 DO
				IF q.u[i] = TRUE THEN next.u[q.m[i]] := TRUE END
			END;
			q := next;  next := q.next
		END;
		count := 0;
		FOR i := 0 TO dim - 1 DO
			IF q.u[i] = TRUE THEN INC( count ) END
		END;
		IF count = 1 THEN first.coal := TRUE END
	END SetQUsage;

	PROCEDURE DoApplyMapper( c: Chain );
	VAR q, first: MapQueue;
	BEGIN
		cur := c;
		IF (c.q # NIL ) & (c.q.coal) THEN RETURN END;
		q := NewQueue( c.dim );  c.m( q.m^ );  first := c.q;  c.q := q;  q.next := first;  INC( c.qlen );  SetQUsage( c.q );
		aM.dSI( "count: ", globalCount )
	END DoApplyMapper;

	PROCEDURE ApplyMapper*;
	VAR l: antsCommands.tScanList;  c: Chain;  obj: vyBase.Object;
	BEGIN
		l := antsCommands.ScanFromPar( "name=OBJ" );
		IF antsCommands.ExpectObjectFromKeyword( l, "name", obj ) THEN
			c := obj( Chain );  cur := c;
			IF (c.q # NIL ) & (c.q.coal) THEN RETURN END;
			DoApplyMapper( c );  vyBase.Update( c )
		END
	END ApplyMapper;

	PROCEDURE DoApplyMapperForw( c: Chain );
	VAR q, first: MapQueue;
	BEGIN
		cur := c;
		IF (c.q # NIL ) & (c.q.coal) THEN RETURN END;
		q := NewQueue( c.dim );  first := c.q;
		WHILE (first.next # NIL ) DO first := first.next END;
		c.m( first.m^ );  first.next := q;  INC( c.qlen );  aM.dSI( "count: ", globalCount )
	END DoApplyMapperForw;

	PROCEDURE ApplyMapperForw*;
	VAR l: antsCommands.tScanList;  c: Chain;  obj: vyBase.Object;
	BEGIN
		l := antsCommands.ScanFromPar( "name=OBJ" );
		IF antsCommands.ExpectObjectFromKeyword( l, "name", obj ) THEN
			c := obj( Chain );  c.backwards := FALSE;  cur := c;  DoApplyMapperForw( c );  SetQUsage( c.q );  c.q.coal := FALSE;
			vyBase.Update( c )
		END
	END ApplyMapperForw;

	PROCEDURE TimeSlice( time: FLOAT64 );
	VAR etime: FLOAT64;
	BEGIN
		etime := time;  time := Oberon.Time();  etime := time + etime * Input.TimeUnit;
		WHILE (time < etime) DO time := Oberon.Time() END
	END TimeSlice;

	PROCEDURE ApplyMapperR*;
	VAR l: antsCommands.tScanList;  c: Chain;  obj: vyBase.Object;  time: FLOAT64;
	BEGIN
		l := antsCommands.ScanFromPar( "name=OBJ [>update|update=INT]" );
		IF antsCommands.ExpectObjectFromKeyword( l, "name", obj ) THEN
			c := obj( Chain );  cur := c;
			LOOP
				IF (c.q # NIL ) & (c.q.coal) THEN vyBase.Update( c );  RETURN END;
				DoApplyMapper( c );
				IF antsCommands.FindKeyword( l, "update" ) THEN
					vyBase.Update( c );
					IF antsCommands.GetRealFromKeyword( l, "update", time ) THEN TimeSlice( time ) END
				END
			END
		END
	END ApplyMapperR;

BEGIN
	aM.launch;
END antsMCView.
System.Free antsMCView ~

antsMCView.New myChain ~
antsMCView.Init
myChain 3
0.2 0.4 0.4
0.4 0.4 0.2
0.3 0.3 0.4
~
antsMCView.Check myChain ~
antsMCView.ApplyMapper myChain ~
antsMCView.SetMapper myChain > independent ~
antsMCView.SetMapper myChain > oneR ~
antsMCView.SetMapper myChain > mapperIt ~


fofAutomatic.Do > interactive > secure
antsMCView.Init myChain   10 > random ~
antsMCView.ApplyMapperR myChain > update 0.2~
fofAutomatic.Pause  > time 0.2
~
fofAutomatic.Do > interactive
antsMCView.ApplyMapper myChain ~
~
fofAutomatic.Stop
Voyager.Show myChain as antsMCView ~

vyScale.Insert
antsMCView.New myChain ~
fofAutomatic.Do > interactive
antsMCView.Init  myChain 5 0.2 0.2 0.2 0.2 0.2 0.15 0.2 0.2 0.2 0.25 0.15 0.15 0.15 0.15 0.4 0.1 0.1 0.1 0.1 0.6 0.05 0.05 0.05 0.05 0.8
antsMCView.ApplyMapperR myChain > update ~
fofAutomatic.Pause  > time 0.2
~
vyScale.Insert
~
antsMCView.ShowMatrix myChain ~


vyScale.Insert


fofAutomatic.Do
antsMCView.New myChain ~
antsMCView.Init  myChain 5 0.2 0.2 0.2 0.2 0.2 0.15 0.2 0.2 0.2 0.25 0.15 0.15 0.15 0.15 0.4 0.1 0.1 0.1 0.1 0.6 0.05 0.05 0.05 0.05 0.8
antsMCView.ApplyMapper myChain > update ~
Voyager.Show myChain as antsMCView ~
~

fofAutomatic.Stop
