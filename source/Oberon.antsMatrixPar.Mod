MODULE antsMatrixPar IN Oberon;   (** fof  **)
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




IMPORT antsObjects, Files, vyBase, Objects, vyName, antsCommands, aM := antsMessages;

TYPE

	MatrixArray* = POINTER TO ARRAY OF ARRAY OF LONGREAL;

	Matrix* = POINTER TO MatrixDesc;
	MatrixDesc* = RECORD (vyBase.ObjDesc)
		dimx-, dimy-: INTEGER;   (* number of rows and columns*)
		par*: MatrixArray
	END;

	PROCEDURE WriteMatrix( VAR R: Files.Rider;  n: Matrix );
	VAR y, x: INTEGER;
	BEGIN
		Files.WriteInt( R, 0 );  Files.WriteInt( R, n.dimy );  Files.WriteInt( R, n.dimx );
		FOR y := 0 TO n.dimy - 1 DO
			FOR x := 0 TO n.dimx - 1 DO Files.WriteLReal( R, n.par[y, x] ) END
		END
	END WriteMatrix;

	PROCEDURE ReadMatrix( VAR R: Files.Rider;  VAR n: Matrix );
	VAR y, x: INTEGER;  version: INTEGER;
	BEGIN
		Files.ReadInt( R, version );  Files.ReadInt( R, n.dimy );  Files.ReadInt( R, n.dimx );  NEW( n.par, n.dimy, n.dimx );
		FOR y := 0 TO n.dimy - 1 DO
			FOR x := 0 TO n.dimx - 1 DO Files.ReadLReal( R, n.par[y, x] ) END
		END
	END ReadMatrix;

	PROCEDURE Handler*( o: Objects.Object;  VAR M: Objects.ObjMsg );
	BEGIN
		WITH o: Matrix DO
			IF M IS Objects.AttrMsg THEN
				WITH M: Objects.AttrMsg DO
					IF M.id = Objects.enum THEN M.Enum( "Gen" );  M.Enum( "dimy" );  M.Enum( "dimx" );  vyBase.objecthandle( o, M )
					ELSIF M.id = Objects.get THEN
						IF M.name = "Gen" THEN COPY( 'antsMatrixPar.Gen', M.s );  M.class := Objects.String;  M.res := 0;  RETURN
						ELSIF M.name = "dimy" THEN M.class := Objects.Int;  M.res := 0;  M.i := o.dimy
						ELSIF M.name = "dimx" THEN M.class := Objects.Int;  M.res := 0;  M.i := o.dimx
						ELSE vyBase.objecthandle( o, M )
						END
					ELSIF M.id = Objects.set THEN
						IF M.name = "dimx" THEN
							IF M.class = Objects.Int THEN ChangeDim( o, o.dimy, SHORT( M.i ) );  M.res := 0 END
						ELSIF M.name = "dimy" THEN
							IF M.class = Objects.Int THEN ChangeDim( o, SHORT( M.i ), o.dimx );  M.res := 0 END
						ELSE vyBase.objecthandle( o, M )
						END
					ELSE vyBase.objecthandle( o, M )
					END;
				END;
			ELSIF M IS Objects.FileMsg THEN
				WITH M: Objects.FileMsg DO
					IF M.id = Objects.load THEN vyBase.objecthandle( o, M );  ReadMatrix( M.R, o )
					ELSIF M.id = Objects.store THEN vyBase.objecthandle( o, M );  WriteMatrix( M.R, o )
					END
				END;
			ELSE vyBase.objecthandle( o, M )
			END
		END  (* tVector*)
	END Handler;

	PROCEDURE Gen*;
	VAR m: Matrix;
	BEGIN
		aM.cmd;  NEW( m );  m.handle := Handler;  Objects.NewObj := m;  antsObjects.Register( m )
	END Gen;

	PROCEDURE DoNew*( dimy, dimx: INTEGER ): Matrix;
	VAR n: Matrix;
	BEGIN
		Gen;  n := Objects.NewObj( Matrix );  n.handle := Handler;  n.dimy := dimy;  n.dimx := dimx;  NEW( n.par, dimy, dimx );
		Fill( n.par, 0 );  RETURN n
	END DoNew;

	PROCEDURE Min( x, y: INTEGER ): INTEGER;
	BEGIN
		IF x < y THEN RETURN x ELSE RETURN y END
	END Min;

	PROCEDURE CopyMatrixArray( n: Matrix;  from: MatrixArray );
	VAR y, x: INTEGER;
	BEGIN
		FOR y := 0 TO n.dimy - 1 DO
			FOR x := 0 TO n.dimx - 1 DO n.par[y, x] := from[y, x] END
		END
	END CopyMatrixArray;

	PROCEDURE Fill( a: MatrixArray;  with: LONGREAL );
	VAR y, x: LONGINT;
	BEGIN
		FOR y := 0 TO LEN( a ) - 1 DO
			FOR x := 0 TO LEN( a[0] ) - 1 DO a[y, x] := with END
		END
	END Fill;

	PROCEDURE ChangeDim*( n: Matrix;  dimy, dimx: INTEGER );
	VAR par: MatrixArray;
	BEGIN
		IF (dimy < 1) OR (dimx < 1) THEN RETURN END;
		IF (dimy # n.dimy) OR (dimx # n.dimx) THEN
			NEW( par, dimy, dimx );  Fill( par, 0 );  n.dimy := Min( dimy, n.dimy );  n.dimx := Min( dimx, n.dimx );
			CopyMatrixArray( n, par );  n.dimx := dimx;  n.dimy := dimy;  n.par := par;  vyBase.Update( n )
		END
	END ChangeDim;

	PROCEDURE Symmetry*( n: Matrix );
	VAR y, x: LONGINT;
	BEGIN
		FOR y := 0 TO n.dimy - 1 DO
			FOR x := 0 TO n.dimx - 1 DO n.par[x, y] := n.par[y, x] END
		END
	END Symmetry;

	PROCEDURE MinMax*( n: Matrix;  VAR min, max: LONGREAL );
	VAR y, x: LONGINT;
	BEGIN
		min := MAX( LONGREAL );  max := MIN( LONGREAL );
		FOR y := 0 TO n.dimy - 1 DO
			FOR x := 0 TO n.dimx - 1 DO
				IF n.par[y, x] > max THEN max := n.par[y, x] END;
				IF n.par[y, x] < min THEN min := n.par[y, x] END
			END
		END
	END MinMax;

	PROCEDURE Standardize*( n: Matrix );
	VAR y, x: LONGINT;  min, max: LONGREAL;
	BEGIN
		MinMax( n, min, max );
		IF min = max THEN Fill( n.par, 0 ) ELSE
			FOR y := 0 TO n.dimy - 1 DO
				FOR x := 0 TO n.dimx - 1 DO n.par[y, x] := (n.par[y, x] - min) / (max - min) END
			END
		END
	END Standardize;

	PROCEDURE L0*( n: Matrix );
	VAR y, x: LONGINT;
	BEGIN
		FOR y := 0 TO n.dimy - 1 DO
			FOR x := 0 TO n.dimx - 1 DO
				IF y = x THEN n.par[y, x] := 0 ELSE n.par[y, x] := 1 END
			END
		END
	END L0;

	PROCEDURE L1*( n: Matrix );
	VAR y, x: LONGINT;
	BEGIN
		FOR y := 0 TO n.dimy - 1 DO
			FOR x := 0 TO n.dimx - 1 DO n.par[y, x] := ABS( y - x ) END
		END;
		Standardize( n )
	END L1;

	PROCEDURE L2*( n: Matrix );
	VAR y, x: LONGINT;
	BEGIN
		FOR y := 0 TO n.dimy - 1 DO
			FOR x := 0 TO n.dimx - 1 DO n.par[y, x] := (y - x) * (y - x) END
		END;
		Standardize( n )
	END L2;

	PROCEDURE New*;
	VAR l: antsCommands.tScanList;  name: vyName.tNameArray;  n: Matrix;
	BEGIN
		l := antsCommands.ScanFromPar( "name=NAME" );
		IF antsCommands.ExpectNameFromKeyword( l, "name", name ) THEN n := DoNew( 1, 1 );  vyName.RegisterNamed( n, name ) END
	END New;

	PROCEDURE DoWrite*( n: Matrix );
	VAR y, x: LONGINT;
	BEGIN
		aM.SISI( "dimy = ", n.dimy, "dimx= ", n.dimx );
		FOR y := 0 TO n.dimy - 1 DO
			aM.S( "" );
			FOR x := 0 TO n.dimx - 1 DO aM.SR( " ", n.par[y, x] ) END
		END
	END DoWrite;

	PROCEDURE Write*;
	VAR obj: vyBase.Object;  l: antsCommands.tScanList;
	BEGIN
		l := antsCommands.ScanFromPar( "name=OBJ" );
		IF antsCommands.ExpectObjectFromKeyword( l, "name", obj ) THEN DoWrite( obj( Matrix ) ) END
	END Write;

BEGIN
	aM.launch;
END antsMatrixPar.

antsMatrixPar.New test ~
antsMatrixPar.Write test ~
antsObjects.WriteAttributes test ~





