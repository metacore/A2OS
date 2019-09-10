MODULE antsNeighbourhoods IN Oberon;   (** fof  **)
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




IMPORT antsObjects, Files, vyBase, Objects, vyName, antsCommands, antsMessages, antsArrayObjects, antsGlobals, aM := antsMessages;

TYPE
	NeighbourTable* = antsArrayObjects.tLONGINTArray;

	pars* = antsGlobals.Parameters;
	NumOFN* = POINTER TO ARRAY OF SIGNED16;
	Index* = NumOFN;
	NeighbArray* = POINTER TO ARRAY OF ARRAY 8 OF SIGNED16;

	Neighbours* = POINTER TO NeighboursDesc;
	NeighboursDesc* = RECORD (vyBase.ObjDesc)
		dim-: SIGNED16;   (* number of neighbourhoods to be parametrized*)
		count-: NumOFN;   (* number of neighbours per neighbourhood (max 8)*)
		x-, y-: NeighbArray;   (* neighbours in x, y direction *)
		isotropic-: BOOLEAN;
		par*: pars;
		parnames: antsGlobals.ParameterNames;
		cx-, cy-: Index;   (* cache for fast access in Sampling methods, one to one correspondence of masked pixels to pars *)
		cpar-: pars;
		clen-: SIGNED16
	END;

	PROCEDURE FillParCache*( n: Neighbours );
	VAR len, i, j: SIGNED16;
	BEGIN
		len := 0;
		FOR i := 0 TO n.dim - 1 DO
			FOR j := 0 TO n.count[i] - 1 DO n.cpar[len] := n.par[i];  INC( len ) END
		END
	END FillParCache;

	PROCEDURE FillCache*( n: Neighbours );
	VAR len, i, j: SIGNED16;
	BEGIN
		len := 0;
		FOR i := 0 TO n.dim - 1 DO len := len + n.count[i] END;
		n.clen := len;
		IF (n.cx = NIL ) OR (LEN( n.x ) # len) THEN NEW( n.cx, len );  NEW( n.cy, len );  NEW( n.cpar, len ) END;
		len := 0;
		FOR i := 0 TO n.dim - 1 DO
			FOR j := 0 TO n.count[i] - 1 DO n.cx[len] := n.x[i, j];  n.cy[len] := n.y[i, j];  n.cpar[len] := n.par[i];  INC( len ) END
		END
	END FillCache;

	PROCEDURE WritePars( VAR R: Files.Rider;  par: pars );
	VAR i: SIGNED32;
	BEGIN
		Files.WriteInt( R, 0 );  Files.WriteLInt( R, LEN( par^ ) );
		FOR i := 0 TO LEN( par^ ) - 1 DO Files.WriteLReal( R, par[i] ) END
	END WritePars;

	PROCEDURE ReadPars( VAR R: Files.Rider;  VAR par: pars );
	VAR len, i: SIGNED32;  version: SIGNED16;
	BEGIN
		Files.ReadInt( R, version );  Files.ReadLInt( R, len );  NEW( par, len );
		FOR i := 0 TO len - 1 DO Files.ReadLReal( R, par[i] ) END
	END ReadPars;

	PROCEDURE WriteNeighbours( VAR R: Files.Rider;  n: Neighbours );
	VAR i, j: SIGNED16;
	BEGIN
		Files.WriteInt( R, 0 );  Files.WriteInt( R, n.dim );
		FOR i := 0 TO n.dim - 1 DO
			Files.WriteInt( R, n.count[i] );
			FOR j := 0 TO 7 DO Files.WriteInt( R, n.x[i, j] );  Files.WriteInt( R, n.y[i, j] ) END
		END;
		WritePars( R, n.par );  Files.WriteBool( R, n.isotropic )
	END WriteNeighbours;

	PROCEDURE ReadNeighbours( VAR R: Files.Rider;  VAR n: Neighbours );
	VAR dim, i, j: SIGNED16;  version: SIGNED16;

	BEGIN
		Files.ReadInt( R, version );  Files.ReadInt( R, dim );  n.dim := dim;  NEW( n.count, dim );  NEW( n.x, dim );  NEW( n.y, dim );
		FOR i := 0 TO n.dim - 1 DO
			Files.ReadInt( R, n.count[i] );
			FOR j := 0 TO 7 DO Files.ReadInt( R, n.x[i, j] );  Files.ReadInt( R, n.y[i, j] ) END
		END;
		ReadPars( R, n.par );  Files.ReadBool( R, n.isotropic );  FillCache( n )
	END ReadNeighbours;

	PROCEDURE ChangeIsotropy*( n: Neighbours;  iso: BOOLEAN );
	BEGIN
		n.isotropic := iso;  ChangeDim( n, n.dim );  FillCache( n );  vyBase.Update( n )
	END ChangeIsotropy;

	PROCEDURE Handler*( o: Objects.Object;  VAR M: Objects.ObjMsg );
	BEGIN
		WITH o: Neighbours DO
			IF M IS Objects.AttrMsg THEN
				WITH M: Objects.AttrMsg DO
					IF M.id = Objects.enum THEN
						M.Enum( "Gen" );  M.Enum( "dim" );  M.Enum( "isotropic" );
						IF antsGlobals.ParameterHandleAttribute( M, o.par, o.parnames ) THEN END;
						vyBase.objecthandle( o, M );
					ELSIF M.id = Objects.get THEN
						IF M.name = "Gen" THEN COPY( 'antsNeighbourhoods.Gen', M.s );  M.class := Objects.String;  M.res := 0;  RETURN
						ELSIF M.name = "isotropic" THEN M.class := Objects.Bool;  M.res := 0;  M.b := o.isotropic
						ELSIF M.name = "dim" THEN M.class := Objects.Int;  M.res := 0;  M.i := o.dim
						ELSIF M.name = "Name" THEN
							IF o.Name = o THEN vyName.RegisterNamed( o, "dummyname" ) ELSE vyBase.objecthandle( o, M ) END;
						ELSIF antsGlobals.ParameterHandleAttribute( M, o.par, o.parnames ) THEN
						ELSE vyBase.objecthandle( o, M )
						END
					ELSIF M.id = Objects.set THEN
						IF M.name = "dim" THEN
							IF M.class = Objects.Int THEN ChangeDim( o, SHORT( M.i ) );  M.res := 0 END
						ELSIF M.name = "isotropic" THEN
							IF M.class = Objects.Bool THEN ChangeIsotropy( o, M.b );  M.res := 0 END
						ELSIF antsGlobals.ParameterHandleAttribute( M, o.par, o.parnames ) THEN FillCache( o );  vyBase.Update( o );
						ELSE vyBase.objecthandle( o, M )
						END
					ELSE vyBase.objecthandle( o, M )
					END;
				END;
			ELSIF M IS Objects.FileMsg THEN
				WITH M: Objects.FileMsg DO
					IF M.id = Objects.load THEN vyBase.objecthandle( o, M );  ReadNeighbours( M.R, o )
					ELSIF M.id = Objects.store THEN vyBase.objecthandle( o, M );  WriteNeighbours( M.R, o )
					END
				END;
			ELSE vyBase.objecthandle( o, M )
			END
		END  (* tVector*)
	END Handler;

	PROCEDURE swap( VAR x, y: SIGNED16 );
	VAR temp: SIGNED16;
	BEGIN
		temp := x;  x := y;  y := temp
	END swap;

	PROCEDURE OpenL2*( n: Neighbours;  dim: SIGNED32;  isotropic: BOOLEAN );
	VAR x, y: SIGNED16;  pos: SIGNED32;  dist: SIGNED32;  len: SIGNED16;  par: pars;  i: SIGNED32;
	BEGIN
		NEW( n.x, dim );  NEW( n.y, dim );  NEW( n.count, dim );  n.dim := SHORT( dim );  n.isotropic := isotropic;  pos := 0;  x := 0;  y := 0;  dist := 0;
		NEW( par, n.dim );
		FOR i := 0 TO dim - 1 DO par[i] := 0 END;
		n.par := par;

		LOOP
			IF (dist = 0) & (x * x + y * y = 0) THEN
				n.count[0] := 1;  n.x[pos, 0] := 0;  n.y[pos, 0] := 0;  INC( pos );
				IF pos = dim THEN FillCache( n );  RETURN END
			ELSIF x * x + y * y = dist THEN
				len := 1;

				(* Point and it's opposite : *)
				n.x[pos, len - 1] := x;  n.y[pos, len - 1] := y;  INC( len );  n.x[pos, len - 1] := -x;  n.y[pos, len - 1] := -y;  INC( len );

				IF ~isotropic THEN
					n.count[pos] := len - 1;  INC( pos );  len := 1;
					IF pos = dim THEN FillCache( n );  RETURN END
				END;

				IF (x # y) THEN swap( x, y );

					n.x[pos, len - 1] := x;  n.y[pos, len - 1] := y;  INC( len );  n.x[pos, len - 1] := -x;  n.y[pos, len - 1] := -y;  INC( len );

					IF ~isotropic THEN
						n.count[pos] := len - 1;  INC( pos );  len := 1;
						IF pos = dim THEN FillCache( n );  RETURN END
					END;
					swap( x, y )
				END;

				IF (x # 0) & (y # 0) THEN

					n.x[pos, len - 1] := x;  n.y[pos, len - 1] := -y;  INC( len );  n.x[pos, len - 1] := -x;  n.y[pos, len - 1] := y;  INC( len );
					IF ~isotropic THEN
						n.count[pos] := len - 1;  INC( pos );  len := 1;
						IF pos = dim THEN FillCache( n );  RETURN END
					END;
					IF (x # y) THEN swap( x, y );

						n.x[pos, len - 1] := x;  n.y[pos, len - 1] := -y;  INC( len );  n.x[pos, len - 1] := -x;  n.y[pos, len - 1] := y;  INC( len );

						IF ~isotropic THEN
							n.count[pos] := len - 1;  INC( pos );  len := 1;
							IF pos = dim THEN FillCache( n );  RETURN END
						END;
						swap( x, y )
					END
				END;
				IF isotropic THEN
					n.count[pos] := len - 1;  INC( pos );
					IF pos = dim THEN FillCache( n );  RETURN END
				END
			END;

			INC( x );
			IF x > y THEN x := 0;  INC( y ) END;

			IF y > dist THEN INC( dist );  x := 0;  y := 0
			END

		END
	END OpenL2;

	PROCEDURE Gen*;
	VAR m: Neighbours;
	BEGIN
		aM.cmd;  NEW( m );  m.handle := Handler;  Objects.NewObj := m;  antsObjects.Register( m )
	END Gen;

	PROCEDURE NewL2*( dim: SIGNED32;  isotropic: BOOLEAN ): Neighbours;
	VAR n: Neighbours;
	BEGIN
		Gen;  n := Objects.NewObj( Neighbours );  n.handle := Handler;  OpenL2( n, dim, isotropic );  RETURN n
	END NewL2;

	PROCEDURE Min( x, y: SIGNED32 ): SIGNED32;
	BEGIN
		IF x < y THEN RETURN x ELSE RETURN y END
	END Min;

	PROCEDURE ChangeDim*( n: Neighbours;  newdim: SIGNED16 );
	VAR i: SIGNED32;  par: pars;
	BEGIN
		IF newdim > 55 THEN newdim := 55 END;
		IF newdim < 1 THEN newdim := 1 END;
		par := n.par;  n.count := NIL;  n.x := NIL;  n.y := NIL;  n.par := NIL;  OpenL2( n, newdim, n.isotropic );
		FOR i := 0 TO Min( LEN( par^ ), LEN( n.par^ ) ) - 1 DO n.par[i] := par[i] END;
		FillCache( n );  vyBase.Update( n )
	END ChangeDim;

	PROCEDURE ReadNew*;
	VAR l: antsCommands.tScanList;  dim: SIGNED32;  thisp, p: antsCommands.tParameter;  name: vyName.tNameArray;  par: pars;
	VAR isotropic: BOOLEAN;  n: Neighbours;
	BEGIN
		l := antsCommands.ScanFromPar( "name=NAME >par {FLOAT32} [>nonisotropic] " );
		IF antsCommands.ExpectNameFromKeyword( l, "name", name ) THEN
			p := antsCommands.ParsFromKeyword( l, "par" );  thisp := p;  dim := 0;
			WHILE thisp # NIL DO INC( dim );  thisp := thisp.next END;
			IF dim = 0 THEN HALT( 200 ) END;
			isotropic := ~antsCommands.FindKeyword( l, "nonisotropic" );  n := NewL2( dim, isotropic );  par := n.par;  thisp := p;  dim := 0;
			WHILE thisp # NIL DO
				IF thisp IS antsCommands.tReal THEN
					WITH thisp: antsCommands.tReal DO
						par[dim] := thisp.real
						(* vyHostTexts.MsgSR("Par:",thisp.real);  *)
					END;
				ELSE HALT( 201 )
				END;
				INC( dim );  thisp := thisp.next
			END;
			FillCache( n );  vyName.RegisterNamed( n, name )
		END
	END ReadNew;

	PROCEDURE New*;
	VAR l: antsCommands.tScanList;  name: vyName.tNameArray;  isotropic: BOOLEAN;  n: Neighbours;  size: SIGNED32;
	BEGIN
		l := antsCommands.ScanFromPar( "name=NAME size=INT [>isotropic]" );
		IF antsCommands.ExpectNameFromKeyword( l, "name", name ) & antsCommands.ExpectNumberFromKeyword( l, "size", size ) THEN
			isotropic := antsCommands.FindKeyword( l, "isotropic" );  n := NewL2( size, isotropic );  vyName.RegisterNamed( n, name )
		END
	END New;

	PROCEDURE DoWrite*( n: Neighbours );
	VAR i: SIGNED32;
	BEGIN
		antsMessages.S( " >par " );
		FOR i := 0 TO n.dim - 1 DO antsMessages.SR( " ", n.par[i] ) END;
		IF n.isotropic THEN antsMessages.S( "  >isotropic" ) ELSE antsMessages.S( "  >nonisotropic" ) END
	END DoWrite;

	PROCEDURE Write*;
	VAR obj: vyBase.Object;  l: antsCommands.tScanList;
	BEGIN
		l := antsCommands.ScanFromPar( "name=OBJ" );
		IF antsCommands.ExpectObjectFromKeyword( l, "name", obj ) THEN DoWrite( obj( Neighbours ) ) END
	END Write;

	PROCEDURE SortTable*;
	END SortTable;

	PROCEDURE st( VAR A, B: ARRAY OF SIGNED32;  VAR equal: BOOLEAN ): BOOLEAN;
	VAR i, len: SIGNED32;
	BEGIN
		i := 0;  len := LEN( A );
		WHILE (i < len) & (A[i] = B[i]) DO INC( i ) END;
		IF i = len THEN INC( B[i] );  equal := TRUE;  RETURN FALSE
		ELSE
			equal := FALSE;
			IF A[i] < B[i] THEN RETURN TRUE ELSE RETURN FALSE END
		END
	END st;

	PROCEDURE Insert( VAR A: ARRAY OF SIGNED32;  VAR to: ARRAY OF ARRAY OF SIGNED32;  VAR len: SIGNED32 );
	VAR i, j, pos: SIGNED32;  equal: BOOLEAN;
	BEGIN
		(* LEN of A is one less then LEN of to[i] ! *)
		i := 0;
		WHILE (st( A, to[i], equal )) DO INC( i ) END;
		IF equal THEN  (* INC(to[i,LEN(A)]); *) RETURN END;
		pos := i;

		WHILE (to[i, LEN( A )] > 0) DO INC( i )
		END;
		len := i;
		WHILE (i > pos) DO
			FOR j := 0 TO LEN( to[i] ) - 1 DO to[i, j] := to[i - 1, j] END;
			DEC( i )
		END;
		FOR j := 0 TO LEN( A ) - 1 DO to[i, j] := A[j] END;
		to[i, LEN( A )] := 1
	END Insert;

	PROCEDURE MakeNeighbourTable*( o: antsArrayObjects.tINTEGERObject;  x0, y0, w0, h0: SIGNED32;
															    n: Neighbours ): NeighbourTable;
	VAR table: NeighbourTable;
		val: POINTER TO ARRAY OF SIGNED32;
		x, y, i: SIGNED32;  tlen: SIGNED32;  exceeded: BOOLEAN;
	BEGIN
		antsMessages.SISI( "W0", w0, "h0", h0 );  NEW( table, w0 * h0 + 1, n.clen + 1 );  antsMessages.SI( "Making a table, max len: ", LEN( table ) - 1 );

		IF (o.depth < 8) & (n.clen < 8) THEN
		END;
		FOR y := 0 TO LEN( table ) - 1 DO
			FOR x := 0 TO LEN( table[0] ) - 1 DO table[y, x] := 0 END
		END;
		NEW( val, n.clen );  tlen := 0;  exceeded := FALSE;
		FOR y := y0 TO y0 + h0 - 1 DO
			FOR x := x0 TO x0 + w0 - 1 DO
				IF (~exceeded) & (tlen > 1000) & (tlen / ((y - y0) * w0 + (x - x0)) > 0.5) THEN exceeded := TRUE END;

				IF (~exceeded) THEN
					FOR i := 0 TO n.clen - 1 DO val[i] := o.A[(y + n.cy[i]) MOD o.h, (x + n.cx[i]) MOD o.w] END;
					Insert( val^, table^, tlen )
				ELSE
					FOR i := 0 TO n.clen - 1 DO table[tlen, i] := o.A[(y + n.cy[i]) MOD o.h, (x + n.cx[i]) MOD o.w] END;
					table[tlen, LEN( val )] := 1;  INC( tlen )
				END
			END
		END;

		i := 0;
		WHILE (table[i, LEN( val )] > 0) DO
			(*
		Out.Ln;
		FOR j := 0 TO LEN(table[i])-1 DO Out.Int(table[i,j],1); END;
		*)
			INC( i )
		END;
		antsMessages.SI( "Len of table, used: ", i );

		RETURN table
	END MakeNeighbourTable;

BEGIN
	aM.launch;
END antsNeighbourhoods.
