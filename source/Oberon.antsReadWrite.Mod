MODULE antsReadWrite IN Oberon;
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



(*
this is a very simple module to read and write matrices from ascii or oberon files.
All but numbers are ignored in a file.
*)


IMPORT aM := antsMessages, vyLongrealVec, vyLongintVec, vyIntVec, antsCommands, vyBase, vyName, antsSecurity,
	antsArrays, antsFiles, vyPort,SYSTEM;

TYPE

	Rider* = OBJECT (antsFiles.Rider)

		PROCEDURE  (*VAR R: Rider*) ReadI1d*( VAR x: antsArrays.I1d );
		VAR v: vyIntVec.tVector;
		BEGIN
			SELF.ReadIntsLine( v );
			IF vyIntVec.Len( v ) = 0 THEN x := NIL;  RETURN END;
			IF (x = NIL ) OR (LEN( x ) < vyIntVec.Len( v )) THEN NEW( x, vyIntVec.Len( v ) ) END;
			vyIntVec.CopyToArray( v, x^ )
		END ReadI1d;

		PROCEDURE  (*VAR R: Rider*) ReadL1d*( VAR x: antsArrays.L1d );
		VAR v: vyLongintVec.tVector;
		BEGIN
			SELF.ReadLIntsLine( v );
			IF vyLongintVec.Len( v ) = 0 THEN x := NIL;  RETURN END;
			IF (x = NIL ) OR (LEN( x ) < vyLongintVec.Len( v )) THEN NEW( x, vyIntVec.Len( v ) ) END;
			vyLongintVec.CopyToArray( v, x^ )
		END ReadL1d;

		PROCEDURE  (*VAR R: Rider*) ReadX1d*( VAR x: antsArrays.X1d );
		VAR v: vyLongrealVec.tVector;
		BEGIN
			SELF.ReadLRealsLine( v );
			IF vyLongrealVec.Len( v ) = 0 THEN x := NIL;  RETURN END;
			IF (x = NIL ) OR (LEN( x ) < vyLongrealVec.Len( v )) THEN NEW( x, vyIntVec.Len( v ) ) END;
			vyLongrealVec.CopyToArray( v, x^ )
		END ReadX1d;

		PROCEDURE  (*VAR R: Rider*) WriteI1d*( x: antsArrays.I1d );
		BEGIN
			SELF.WriteIntsLine( antsArrays.VecFromArrayI( x^ ) )
		END WriteI1d;

		PROCEDURE  (*VAR R: Rider*) WriteL1d*( x: antsArrays.L1d );
		BEGIN
			SELF.WriteLIntsLine( antsArrays.VecFromArrayL( x^ ) )
		END WriteL1d;

		PROCEDURE  (*VAR R: Rider*) WriteX1d*( x: antsArrays.X1d );
		BEGIN
			SELF.WriteLRealsLine( antsArrays.VecFromArrayX( x^ ) )
		END WriteX1d;

		PROCEDURE  (*VAR R: Rider*) ScanMatrix*( VAR rows, cols: SIGNED32 );
		VAR pos: SIGNED32;  min, max: SIGNED32;  v: vyLongrealVec.tVector;
		BEGIN
			pos := SELF.Pos();
			IF SELF.type = antsFiles.ascii THEN
				rows := 0;  cols := 0;  min := MAX( SIGNED32 );  max := MIN( SIGNED32 );
				(*
		aM.SI("pos ",SELF.Pos()); *)
				SELF.ReadLRealsLine( v );  cols := vyLongrealVec.Len( v );
				WHILE (cols > 0) DO
					IF min > cols THEN min := cols END;
					IF max < cols THEN max := cols END;
					(* aM.SI("cols ",cols);
			aM.SI("pos ",SELF.Pos());*)
					SELF.ReadLRealsLine( v );  cols := vyLongrealVec.Len( v );  INC( rows )
				END;
				cols := min;
				ASSERT ( min = max );
				aM.SI( "Read Ascii File, end: ", SELF.Pos() );  SELF.SetPos( pos )
			ELSE SELF.ReadLInt( rows );  SELF.ReadLInt( cols );  SELF.SetPos( pos )
			END
		END ScanMatrix;

		PROCEDURE  (*VAR R: Rider*) WriteNilMatrix*;
		BEGIN
			IF SELF.type = antsFiles.bin THEN SELF.WriteLInt( 0 );  SELF.WriteLInt( 0 );  ELSE SELF.WriteEmptyLine() END;
		END WriteNilMatrix;

		PROCEDURE  (*VAR R: Rider*) WriteMatrixX*( VAR A: ARRAY OF ARRAY OF FLOAT64 );
		VAR i: SIGNED32;
		BEGIN
			IF SELF.type = antsFiles.bin THEN
				SELF.WriteLInt( LEN( A ) );  SELF.WriteLInt( LEN( A[0] ) );
				FOR i := 0 TO LEN( A ) - 1 DO SELF.WriteLRealsFix( A[i], LEN( A[0] ) ) END
			ELSE
				i := 0;
				WHILE (i < LEN( A )) DO SELF.WriteLRealsLine( antsArrays.VecFromArrayX( A[i] ) );  INC( i ) END;
				SELF.WriteEmptyLine()
			END
		END WriteMatrixX;

		PROCEDURE  (*VAR R: Rider*) ReadMatrixX*( VAR A: ARRAY OF ARRAY OF FLOAT64 );
		VAR rows, cols, i: SIGNED32;  v: vyLongrealVec.tVector;
		BEGIN
			IF SELF.type = antsFiles.bin THEN
				SELF.ReadLInt( rows );  SELF.ReadLInt( cols );
				FOR i := 0 TO rows - 1 DO SELF.ReadLRealsFix( A[i], cols ) END
			ELSE
				i := 0;  SELF.ReadLRealsLine( v );
				WHILE (v.nrData > 0) DO vyLongrealVec.CopyToArray( v, A[i] );  INC( i );  SELF.ReadLRealsLine( v ) END
			END
		END ReadMatrixX;

		PROCEDURE  (*VAR R: Rider*) WriteMatrixL*( VAR A: ARRAY OF ARRAY OF SIGNED32 );
		VAR row, i: SIGNED32;
		BEGIN
			IF SELF.type = antsFiles.bin THEN
				SELF.WriteLInt( LEN( A ) );  SELF.WriteLInt( LEN( A[0] ) );
				FOR i := 0 TO LEN( A ) - 1 DO SELF.WriteLIntsFix( A[i], LEN( A[0] ) ) END
			ELSE
				row := 0;
				WHILE (row < LEN( A )) DO SELF.WriteLIntsLine( antsArrays.VecFromArrayL( A[row] ) );  INC( row ) END;
				SELF.WriteEmptyLine()
			END
		END WriteMatrixL;

		PROCEDURE  (*VAR R: Rider*) ReadMatrixL*( VAR A: ARRAY OF ARRAY OF SIGNED32 );
		VAR i, rows, cols: SIGNED32;  v: vyLongintVec.tVector;
		BEGIN
			IF SELF.type = antsFiles.bin THEN
				SELF.ReadLInt( rows );  SELF.ReadLInt( cols );
				FOR i := 0 TO rows - 1 DO SELF.ReadLIntsFix( A[i], cols ) END
			ELSE
				i := 0;  SELF.ReadLIntsLine( v );
				WHILE (v.nrData > 0) DO vyLongintVec.CopyToArray( v, A[i] );  INC( i );  SELF.ReadLIntsLine( v ) END
			END
		END ReadMatrixL;

		PROCEDURE  (*VAR R: Rider*) WriteMatrixI*( VAR A: ARRAY OF ARRAY OF SIGNED16 );
		VAR row, i: SIGNED32;
		BEGIN
			IF SELF.type = antsFiles.bin THEN
				SELF.WriteLInt( LEN( A ) );  SELF.WriteLInt( LEN( A[0] ) );
				FOR i := 0 TO LEN( A ) - 1 DO SELF.WriteIntsFix( A[i], LEN( A[0] ) ) END
			ELSE
				row := 0;
				WHILE (row < LEN( A )) DO SELF.WriteIntsLine( antsArrays.VecFromArrayI( A[row] ) );  INC( row ) END;
				SELF.WriteEmptyLine()
			END
		END WriteMatrixI;

		PROCEDURE  (*VAR R: Rider*) ReadMatrixI*( VAR A: ARRAY OF ARRAY OF SIGNED16 );
		VAR i, rows, cols: SIGNED32;  v: vyIntVec.tVector;
		BEGIN
			IF SELF.type = antsFiles.bin THEN
				SELF.ReadLInt( rows );  SELF.ReadLInt( cols );
				FOR i := 0 TO rows - 1 DO SELF.ReadIntsFix( A[i], cols ) END
			ELSE
				i := 0;  SELF.ReadIntsLine( v );
				WHILE (v.nrData > 0) DO vyIntVec.CopyToArray( v, A[i] );  INC( i );  SELF.ReadIntsLine( v ) END
			END
		END ReadMatrixI;

		PROCEDURE  (*VAR R: Rider*) ReadRowX*( VAR v: vyLongrealVec.tVector;  row: SIGNED32 );
		VAR r, rows, cols: SIGNED32;  A: antsArrays.X1d;
		BEGIN
			IF SELF.type = antsFiles.bin THEN
				SELF.ReadLInt( rows );  SELF.ReadLInt( cols );
				IF row >= rows THEN v := NIL;  RETURN END;
				SELF.SetPos( SELF.Pos() + row * cols * SIZEOF( FLOAT64 ) );  NEW( A, cols );  SELF.ReadLRealsFix( A^, cols );
				IF v = NIL THEN v := vyLongrealVec.New( cols ) ELSE vyLongrealVec.SetLen( v, cols ) END;
				vyLongrealVec.CopyToVec( A^, v, cols, 0, 0 )
			ELSE
				r := 0;
				WHILE (row >= r) DO
					SELF.ReadLRealsLine( v );
					IF vyLongrealVec.Len( v ) = 0 THEN v := NIL;  RETURN END;
					INC( r )
				END
			END
		END ReadRowX;

		PROCEDURE  (*VAR R: Rider*) ReadRowL*( VAR v: vyLongintVec.tVector;  row: SIGNED32 );
		VAR r, rows, cols: SIGNED32;  A: antsArrays.L1d;
		BEGIN
			IF SELF.type = antsFiles.bin THEN
				SELF.ReadLInt( rows );  SELF.ReadLInt( cols );
				IF row >= rows THEN v := NIL;  RETURN END;
				SELF.SetPos( SELF.Pos() + row * cols * SIZEOF( SIGNED32 ) );  NEW( A, cols );  SELF.ReadLIntsFix( A^, cols );
				IF v = NIL THEN v := vyLongintVec.New( cols ) ELSE vyLongintVec.SetLen( v, cols ) END;
				vyLongintVec.CopyToVec( A^, v, cols, 0, 0 )
			ELSE
				r := 0;
				WHILE (row >= r) DO
					SELF.ReadLIntsLine( v );
					IF vyLongintVec.Len( v ) = 0 THEN v := NIL;  RETURN END;
					INC( r )
				END
			END
		END ReadRowL;

		PROCEDURE  (*VAR R: Rider*) ReadRowI*( VAR v: vyIntVec.tVector;  row: SIGNED32 );
		VAR r, rows, cols: SIGNED32;  A: antsArrays.I1d;
		BEGIN
			IF SELF.type = antsFiles.bin THEN
				SELF.ReadLInt( rows );  SELF.ReadLInt( cols );
				IF row >= rows THEN v := NIL;  RETURN END;
				SELF.SetPos( SELF.Pos() + row * cols * SIZEOF( SIGNED16 ) );  NEW( A, cols );  SELF.ReadIntsFix( A^, cols );
				IF v = NIL THEN v := vyIntVec.New( cols ) ELSE vyIntVec.SetLen( v, cols ) END;
				vyIntVec.CopyToVec( A^, v, cols, 0, 0 )
			ELSE
				r := 0;
				WHILE (row >= r) DO
					SELF.ReadIntsLine( v );
					IF vyIntVec.Len( v ) = 0 THEN v := NIL;  RETURN END;
					INC( r )
				END
			END
		END ReadRowI;

		PROCEDURE  (*VAR R: Rider*) ReadColX*( VAR v: vyLongrealVec.tVector;  col: SIGNED32 );
		VAR r, rows, cols: SIGNED32;  v2: vyLongrealVec.tVector;  x: FLOAT64;
		BEGIN
			IF v = NIL THEN v := vyLongrealVec.New( 0 ) ELSE vyLongrealVec.SetLen( v, 0 ) END;
			IF SELF.type = antsFiles.bin THEN
				SELF.ReadLInt( rows );  SELF.ReadLInt( cols );
				IF col >= cols THEN v := NIL;  RETURN END;
				SELF.SetPos( SELF.Pos() + col * SIZEOF( FLOAT64 ) );
				FOR r := 0 TO rows - 1 DO
					SELF.ReadLReal( x );  vyLongrealVec.Append( x, v );  SELF.SetPos( SELF.Pos() + (cols - 1) * SIZEOF( FLOAT64 ) )
				END;
				SELF.SetPos( SELF.Pos() + (cols - 1 - col) * SIZEOF( FLOAT64 ) )
			ELSE
				r := 0;
				LOOP
					SELF.ReadLRealsLine( v2 );
					IF vyLongrealVec.Len( v2 ) = 0 THEN RETURN
					ELSIF vyLongrealVec.Len( v2 ) <= col THEN v := NIL;  RETURN
					END;
					vyLongrealVec.Append( vyLongrealVec.Get( v2, col ), v );  INC( r )
				END
			END
		END ReadColX;

		PROCEDURE  (*VAR R: Rider*) ReadColL*( VAR v: vyLongintVec.tVector;  col: SIGNED32 );
		VAR r, rows, cols: SIGNED32;  v2: vyLongintVec.tVector;  x: SIGNED32;
		BEGIN
			IF v = NIL THEN v := vyLongintVec.New( 0 ) ELSE vyLongintVec.SetLen( v, 0 ) END;
			IF SELF.type = antsFiles.bin THEN
				SELF.ReadLInt( rows );  SELF.ReadLInt( cols );
				IF col >= cols THEN v := NIL;  RETURN END;
				SELF.SetPos( SELF.Pos() + col * SIZEOF( SIGNED32 ) );
				FOR r := 0 TO rows - 1 DO
					SELF.ReadLInt( x );  vyLongintVec.Append( x, v );  SELF.SetPos( SELF.Pos() + (cols - 1) * SIZEOF( SIGNED32 ) )
				END;
				SELF.SetPos( SELF.Pos() + (cols - 1 - col) * SIZEOF( SIGNED32 ) )
			ELSE
				r := 0;
				LOOP
					SELF.ReadLIntsLine( v2 );
					IF vyLongintVec.Len( v2 ) = 0 THEN RETURN
					ELSIF vyLongintVec.Len( v2 ) <= col THEN v := NIL;  RETURN
					END;
					vyLongintVec.Append( vyLongintVec.Get( v2, col ), v );  INC( r )
				END
			END
		END ReadColL;

		PROCEDURE  (*VAR R: Rider*) ReadColI*( VAR v: vyIntVec.tVector;  col: SIGNED32 );
		VAR r, rows, cols: SIGNED32;  v2: vyIntVec.tVector;  x: SIGNED16;
		BEGIN
			IF v = NIL THEN v := vyIntVec.New( 0 ) ELSE vyIntVec.SetLen( v, 0 ) END;
			IF SELF.type = antsFiles.bin THEN
				SELF.ReadLInt( rows );  SELF.ReadLInt( cols );
				IF col >= cols THEN v := NIL;  RETURN END;
				SELF.SetPos( SELF.Pos() + col * SIZEOF( SIGNED32 ) );
				FOR r := 0 TO rows - 1 DO SELF.ReadInt( x );  vyIntVec.Append( x, v );  SELF.SetPos( SELF.Pos() + (cols - 1) * SIZEOF( SIGNED32 ) ) END;
				SELF.SetPos( SELF.Pos() + (cols - 1 - col) * SIZEOF( SIGNED32 ) )
			ELSE
				r := 0;
				LOOP
					SELF.ReadIntsLine( v2 );
					IF vyIntVec.Len( v2 ) = 0 THEN RETURN
					ELSIF vyIntVec.Len( v2 ) <= col THEN v := NIL;  RETURN
					END;
					vyIntVec.Append( vyIntVec.Get( v2, col ), v );  INC( r )
				END
			END
		END ReadColI;

		PROCEDURE  (*VAR R: Rider*) WriteX2d*( A: antsArrays.X2d );
		BEGIN
			IF A = NIL THEN SELF.WriteNilMatrix ELSE SELF.WriteMatrixX( A^ ) END;
		END WriteX2d;

		PROCEDURE  (*VAR R: Rider*) WriteL2d*( A: antsArrays.L2d );
		BEGIN
			IF A = NIL THEN SELF.WriteNilMatrix ELSE SELF.WriteMatrixL( A^ ) END;
		END WriteL2d;

		PROCEDURE  (*VAR R: Rider*) WriteI2d*( A: antsArrays.I2d );
		BEGIN
			IF A = NIL THEN SELF.WriteNilMatrix ELSE SELF.WriteMatrixI( A^ ) END;
		END WriteI2d;

		PROCEDURE  (*VAR R: Rider*) ReadX2d*( VAR A: antsArrays.X2d );
		VAR rows, cols: SIGNED32;
		BEGIN
			SELF.ScanMatrix( rows, cols );
			IF (rows = 0) OR (cols = 0) THEN A := NIL;  RETURN END;
			IF (A = NIL ) OR (LEN( A ) # rows) OR (LEN( A[0] ) # cols) THEN NEW( A, rows, cols ) END;
			SELF.ReadMatrixX( A^ )
		END ReadX2d;

		PROCEDURE  (*VAR R: Rider*) ReadI2d*( VAR A: antsArrays.I2d );
		VAR rows, cols: SIGNED32;
		BEGIN
			SELF.ScanMatrix( rows, cols );
			IF (rows = 0) OR (cols = 0) THEN A := NIL;  RETURN END;
			IF (A = NIL ) OR (LEN( A ) # rows) OR (LEN( A[0] ) # cols) THEN NEW( A, rows, cols ) END;
			SELF.ReadMatrixI( A^ )
		END ReadI2d;

		PROCEDURE  (*VAR R: Rider*) ReadL2d*( VAR A: antsArrays.L2d );
		VAR rows, cols: SIGNED32;
		BEGIN
			SELF.ScanMatrix( rows, cols );
			IF (rows = 0) OR (cols = 0) THEN A := NIL;  RETURN END;
			IF (A = NIL ) OR (LEN( A ) # rows) OR (LEN( A[0] ) # cols) THEN NEW( A, rows, cols ) END;
			SELF.ReadMatrixL( A^ )
		END ReadL2d;

	END Rider;

	PROCEDURE StorePGM*( VAR A: antsArrays.L2d;  fname: ARRAY OF CHAR;  d: SIGNED32 ): BOOLEAN;
	VAR w, h: SIGNED32;  R: antsFiles.Rider;  x, y: SIGNED32;
	BEGIN
		IF ~R.New( fname ) THEN aM.eSS( "could not open ", fname );  RETURN FALSE END;
		R.SetAscii;  R.WriteString( "P5" );  R.WriteLn();  h := LEN( A );  w := LEN( A[0] );  R.WriteLInt( w );  R.WriteLInt( h );  R.WriteLn();
		R.WriteLInt( d );  R.Write( 0DX );  R.Write( 0AX );  R.Write( 0DX );  R.Write( 0AX );  R.SetBin;
		(* data *)
		R.reverse := TRUE;   (*  writer higher  bits then lower  bits *)
		FOR y := 0 TO h - 1 DO
			FOR x := 0 TO w - 1 DO R.WriteInt( SHORT( A[y, x] ) ) END
		END;
		R.Close;  RETURN TRUE
	END StorePGM;

	PROCEDURE ReadLine( VAR RR: antsFiles.Rider );
	VAR ch: CHAR;
	CONST CR = 0DX;  LF = 0AX;
	BEGIN
		RR.Read( ch );
		WHILE (ch # CR) & (ch # LF) DO RR.Read( ch ) END;
		IF ch = CR THEN
			RR.Read( ch );
			IF ch # LF THEN RR.SetPos( RR.Pos() - 1 ) END
		END
	END ReadLine;

	PROCEDURE ReadPGM*( VAR A: antsArrays.L2d;  fname: ARRAY OF CHAR;  VAR d: SIGNED32 ): BOOLEAN;
	VAR name: ARRAY 64 OF CHAR;
		ch: CHAR;  pos: SIGNED32;  w, h: SIGNED32;  x, y: SIGNED32;  R: antsFiles.Rider;  int: SIGNED16;  lint: SIGNED32;
	BEGIN
		IF ~R.Old( fname ) THEN aM.eSS( "could not open ", fname );  RETURN FALSE END;
		R.SetAscii;  R.ReadString( name );
		IF (R.err) OR (name # "P5") THEN aM.SS( "no (variant of) PGM:", fname );  RETURN FALSE END;
		R.ReadLInt( w );   (* dimensions *)
		R.ReadLInt( h );  R.ReadLInt( d );
		ReadLine( R );   (* one empty line *)
		ReadLine( R );
		IF R.err THEN RETURN FALSE END;
		NEW( A, h, w );
		R.SetBin;  R.reverse := TRUE;   (*  read higher  bits then lower  bits *)
		(* data *)
		FOR y := 0 TO h - 1 DO
			FOR x := 0 TO w - 1 DO
				R.ReadInt( int );  lint := int;
				IF lint < 0 THEN INC( lint, 65536 ) END;
				A[y, x] := lint
			END
		END;

		pos := 0;
		WHILE ~R.eot DO
			INC( pos );
			IF pos > 100 THEN antsSecurity.Halt( "File end expected, PGM wrong format" ) END;
			R.Read( ch )
		END;
		R.Close;  RETURN TRUE
	END ReadPGM;

	PROCEDURE Analyze*;
	VAR l: antsCommands.tScanList;
		str: ARRAY 64 OF CHAR;
		rows, columns: SIGNED32;  R: Rider;
	BEGIN
		l := antsCommands.ScanFromPar( "filename=STR [>ignoreNL]" );
		IF antsCommands.ExpectStringFromKeyword( l, "filename", str ) THEN
			IF ~R.Old( str ) THEN aM.eSS( "antsReadWrite:Can not open ", str );  RETURN END;
			IF antsCommands.FindKeyword( l, "ignoreNL" ) THEN R.ignoreNL := TRUE END;
			R.ReadType;
			IF R.type = antsFiles.ascii THEN aM.SS( str, " is of type ASCII" ) ELSE aM.vSS( str, " is of type BIN" ) END;
			R.ScanMatrix( rows, columns );  aM.SISI( "File has rows: ", rows, " and columns: ", columns )
		END
	END Analyze;

	PROCEDURE Read*;
	VAR l: antsCommands.tScanList;
		str: ARRAY 64 OF CHAR;
		data: vyBase.Object;  row, col, len: SIGNED32;
		dataname: ARRAY 64 OF CHAR;
		R: Rider;  msg: vyPort.AdjustCoordMsg;
	BEGIN
		NEW(R);
		l := antsCommands.ScanFromPar( "filename=STR data=NAME (>row|>col) [>ignoreNL]" );
		IF antsCommands.ExpectStringFromKeyword( l, "filename", str ) & antsCommands.ExpectNameFromKeyword( l, "data", dataname ) THEN
			IF ~antsCommands.GetNumberFromKeyword( l, "row", row ) THEN row := -1 END;
			IF ~antsCommands.GetNumberFromKeyword( l, "col", col ) THEN col := -1 END;
			data := vyName.FindObj( dataname );
			IF data = NIL THEN data := vyLongrealVec.New( 0 );  vyName.RegisterNamed( data, dataname ) END;
			WITH data: vyLongrealVec.tVector DO
				len := 0;
				IF ~R.Old( str ) THEN aM.eSS( "antsReadWrite: Can not open ", str );  RETURN END;
				IF antsCommands.FindKeyword( l, "ignoreNL" ) THEN R.ignoreNL := TRUE END;
				R.ReadType;
				IF row # -1 THEN aM.SI( "antsReadWrite:reading row", row );  R.ReadRowX( data, row )
				ELSIF col # -1 THEN R.ReadColX( data, col )
				END;
				R.Close;
				IF data # NIL THEN aM.vSI( "antsReadWrite:Read File, len of data : ", vyLongrealVec.Len( data ) ) ELSE aM.eS( "antsReadWrite:Problems reading, check filename, row/column (index: 0..len-1)" ) END;
				vyBase.ForUsersHandle( data, msg )
			END
		END
	END Read;

	PROCEDURE Write*;
	VAR l: antsCommands.tScanList;
		str: ARRAY 64 OF CHAR;
		data: vyBase.Object;  R: Rider;  len: SIGNED32;  vec: antsArrays.X1d;
	BEGIN
		l := antsCommands.ScanFromPar( "data=OBJ  filename=STR " );
		IF antsCommands.ExpectStringFromKeyword( l, "filename", str ) & antsCommands.ExpectObjectFromKeyword( l, "data", data ) THEN
			IF data = NIL THEN aM.eS( "antsReadWrite: no Object " );  RETURN
			ELSE
				R.ForceNew( str );
				R.SetAscii;   (* remove if binary preferred *)
				R.WriteType;  len := vyLongrealVec.Len( data( vyLongrealVec.tVector ) );
				IF (vec = NIL ) OR (LEN( vec ) # len) THEN NEW( vec, len ) END;
				vyLongrealVec.CopyToArray( data( vyLongrealVec.tVector ), vec^ );  R.WriteX1d( vec );  R.Close;
			END
		END
	END Write;

	PROCEDURE ToBin*;
	VAR from, to: ARRAY 256 OF CHAR;
		R: Rider;  A: antsArrays.X2d;
	BEGIN
		antsCommands.InitScan( "from=STR to=STR" );
		IF antsCommands.ExpectString( "from", from ) & antsCommands.ExpectString( "to", to ) THEN
			aM.S( "converting" );  aM.S( from );  aM.S( to );
			IF ~R.Old( from ) THEN aM.eSS( "antsReadWrite: could not open ", from );  RETURN END;
			IF antsCommands.Find( "ignoreNL" ) THEN R.ignoreNL := TRUE END;
			R.ReadType;
			IF R.type = antsFiles.bin THEN aM.SS( from, " is of type bin, nothing to do" );  RETURN END;
			R.ReadX2d( A );  R.Close;
			IF ~R.New( to ) THEN aM.eSS( "antsReadWrite: could not open ", to );  RETURN END;
			R.SetBin;  R.WriteType;  R.WriteX2d( A );  R.Close;  aM.S( "done." )
		END
	END ToBin;

	PROCEDURE Test*;
	VAR i, j, rows, cols: SIGNED32;  R, RR: Rider;  AA: antsArrays.X2d;  v: vyLongrealVec.tVector;
	BEGIN
	(*
	b :=  ReadPGM(A,"private/fromPotts/patch071010.pgm",depth);
	b := StorePGM(A,"testpgm",depth);
	b := ReadPGM(A,"testpgm",depth);
	*)
		(* ReadPGM(A,"test.pgm",depth); *)

		rows := 10;  cols := 10;  NEW( AA, rows, cols );

		FOR i := 0 TO rows - 1 DO
			FOR j := 0 TO cols - 1 DO AA[i, j] := i * j END
		END;

		R.ForceNew( "testd" );  R.Set( antsFiles.ascii );  R.WriteType;  R.WriteMatrixX( AA^ );  R.Close;

		R.ForceOld( "testd" );  R.ReadType;  R.ScanMatrix( rows, cols );  aM.SISI( "rows", rows, "cols", cols );  R.ReadMatrixX( AA^ );
		(*
	FOR i := 0 TO rows-1 DO
	FOR j := 0 TO cols-1 DO
	aM.SR("val",AA[i,j]);
	END;
	END;
	*)

		R.Close;

		R.ForceNew( "testd" );  R.SetBin;  R.WriteType;  R.WriteMatrixX( AA^ );  R.Close;

		R.ForceOld( "testd" );  R.ReadType;  R.ScanMatrix( rows, cols );  aM.SISI( "rows", rows, "cols", cols );  R.ReadMatrixX( AA^ );

		FOR i := 0 TO rows - 1 DO
			FOR j := 0 TO cols - 1 DO aM.SR( "val", AA[i, j] ) END
		END;
		R.Close;

		RR.ForceOld( "testd" );  RR.ReadType;  RR.ScanMatrix( rows, cols );  aM.S( "before scan" );  RR.ReadRowX( v, 3 );  aM.S( "after read" );
		FOR i := 0 TO vyLongrealVec.Len( v ) - 1 DO aM.SR( " value    ***", vyLongrealVec.Get( v, i ) ) END;

		RR.ForceOld( "testd" );  RR.ReadType;  RR.ScanMatrix( rows, cols );  aM.S( "before scan" );

		RR.ReadColX( v, 3 );  aM.S( "after read col" );
		FOR i := 0 TO vyLongrealVec.Len( v ) - 1 DO aM.SR( " value    ***", vyLongrealVec.Get( v, i ) ) END;

		RR.Close
		(*
	R.ForceOld("angie/private/testMatr");
	R.ReadType;
	(* R.ScanMatrix(rows,cols); *)
	aM.SISI("rows",rows,"cols",cols);
	NEW(AA,rows,cols);
	R.ReadMatrixX(AA^);

	FOR i := 0 TO rows-1 DO
	FOR j := 0 TO cols-1 DO
	aM.SR("val",AA[i,j]);
	END;
	END;
	*)
	END Test;

BEGIN
	aM.launch;
END antsReadWrite.

testd

System.Free  antsReadWrite antsFiles  antsArrays antsArrayImages16 ~
antsReadWrite.Test ~


Analyze a file with
2
antsReadWrite.Analyze filename ~ ( filename = identifier|"identifier"] )
Output is number of rows and columns.


Read Row or Column with

antsReadWrite.Read filename vector - name [row = |col = ] num ~
(filename = identifier | "identifier", name = identifier , num = SIGNED16)

Voyager.Show TestImage as antsImageViews ~

antsReadWrite.Test1 ~
writertest writertest2

antsReadWrite.Read "angie/private/Orig3T"myrow row = 2000 ;   ~~
antsReadWrite.Read "angie/private/Orig3T"myrow col = 10 ;   ~~
antsReadWrite.Analyze "angie/private/Orig3T"~
ants.Show myrow ~
antsReadWrite.ToBin "angie/private/Orig3T""bintest"~
antsReadWrite.Analyze "bintest"~
antsReadWrite.Read "bintest"myrow row = 2000  ~
antsReadWrite.Read "bintest"myrow col = 10  ~
Voyager.WriteData myrow ~

Scan
(******************************* old stuff
PROCEDURE Scan (T: Texts.Text;    VAR r,c: SIGNED32;    v: vyLongrealVec.tVector;    VAR len: SIGNED32;    analyze: BOOLEAN);
VAR   sc: Texts.Scanner;  row,col,thisline: SIGNED32;
pos: SIGNED32;  num: FLOAT64; columns,rows: SIGNED32; 	type: SIGNED16;
CONST cnumber=0;    cname =1;    cunknown =2;
BEGIN
columns := MAX(SIGNED32);
IF T # NIL THEN
pos := 0;
Texts.OpenScanner(sc,T,0);
thisline := -1;    row := 0;    col := -1;
Texts.Scan(sc);    thisline := sc.line;
WHILE ~sc.eot DO
IF thisline#sc.line THEN
IF (col#-1) THEN (* otherwise empty line *)
INC(row);
columns := Min(col,columns);
END;
col := -1;    thisline := sc.line;
END;
IF sc.class = Texts.Name THEN  type:=cname;
ELSIF (sc.class= Texts.Int) THEN num := sc.i;    type:=cnumber;    INC(col);
ELSIF (sc.class=Texts.LongReal) THEN num := sc.y;    type:=cnumber;     INC(col);
ELSIF(sc.class=Texts.Real) THEN num := sc.x;    type:=cnumber;    INC(col);
ELSE  type:=cunknown;
END;
IF analyze THEN
IF type=cunknown THEN aM.Warning();    aM.SISI("Unknown at row ",row," , column ",col);
ELSIF type=cname THEN aM.SISI("name at row ",row," , column ",col);  aM.S(sc.s);
ELSIF type=cnumber THEN INC(pos);
END;
ELSE
IF (type=cnumber) & (((r=-1)&(col=c))OR ((c=-1)&(row=r)))  THEN
IF vyLongrealVec.Len(v)<=pos THEN vyLongrealVec.Append(num,v) ELSE vyLongrealVec.Set(num,v,pos) END;
INC(pos)
END;
END;
Texts.Scan(sc);
END;
len := pos;
rows := row+1;
IF col # -1 THEN  (* last line not empty *)
columns := Min(col,columns)
END;
columns := columns+1;
END;
IF len=0 THEN aM.Warning;  aM.S("No data read ! ") END;
IF r>=rows THEN aM.Warning;  aM.SISI("Tried to read row: ",r, "from rows: ",rows) END;
IF c>=columns THEN aM.Warning;  aM.SISI("Tried to read col: ",c, "from columns: ",columns) END;
r := rows; c := columns;
END Scan;


PROCEDURE DoWriteBinaryMatrix* (VAR R: Files.Rider; VAR A: ARRAY OF ARRAY OF FLOAT64);
VAR i,j: SIGNED32;
BEGIN
Files.WriteLInt(R,LEN(A)); Files.WriteLInt(R,LEN(A[0]));
FOR i := 0 TO LEN(A)-1 DO
FOR j := 0 TO LEN(A[0])-1 DO
Files.WriteLReal(R,A[i,j]);
END;
END;
END DoWriteBinaryMatrix;

PROCEDURE DoReadBinaryMatrix* (VAR R: Files.Rider; VAR A: ARRAY OF ARRAY OF FLOAT64; VAR h,w: SIGNED32): BOOLEAN;
VAR i,j: SIGNED32;
BEGIN
Files.ReadLInt(R,h); Files.ReadLInt(R,w);
IF  (LEN(A)<h) OR (LEN(A[0])<w) THEN RETURN FALSE END;
FOR i := 0 TO h-1 DO
FOR j := 0 TO w-1 DO
Files.ReadLReal(R,A[i,j]);
END;
END;
RETURN TRUE;
END DoReadBinaryMatrix;

PROCEDURE DoReadBinaryRow* (VAR R: Files.Rider; v: vyLongrealVec.tVector; y: SIGNED32; VAR w: SIGNED32);
VAR i,j,h: SIGNED32;dummy: FLOAT64;
BEGIN
Files.ReadLInt(R,h); Files.ReadLInt(R,w);
FOR i := 0 TO y-1 DO
FOR j := 0 TO w-1 DO
Files.ReadLReal(R,dummy);
END;
END;
FOR j := 0 TO w-1 DO
Files.ReadLReal(R,dummy);
vyLongrealVec.Set(dummy,v,j);
END;
END DoReadBinaryRow;

PROCEDURE DoReadMatrix (T: Texts.Text;    fr,tr,fc,tc: SIGNED32;   VAR A: ARRAY OF ARRAY OF FLOAT64);
VAR   sc: Texts.Scanner;  row,col,thisline: SIGNED32;
pos: SIGNED32;  num: FLOAT64; columns: SIGNED32; 	type: SIGNED16;
CONST cnumber=0;    cname =1;    cunknown =2;
BEGIN
columns := MAX(SIGNED32);
IF T # NIL THEN
pos := 0;
Texts.OpenScanner(sc,T,0);
thisline := -1;    row := 0;    col := -1;
Texts.Scan(sc);    thisline := sc.line;
WHILE ~sc.eot DO
IF thisline#sc.line THEN
IF (col#-1) THEN (* otherwise empty line *)
INC(row);
columns := Min(col,columns);
END;
col := -1;    thisline := sc.line;
END;
IF sc.class = Texts.Name THEN  type:=cname;
ELSIF (sc.class= Texts.Int) THEN num := sc.i;    type:=cnumber;    INC(col);
ELSIF (sc.class=Texts.LongReal) THEN num := sc.y;    type:=cnumber;     INC(col);
ELSIF(sc.class=Texts.Real) THEN num := sc.x;    type:=cnumber;    INC(col);
ELSE  type:=cunknown;
END;
IF (type=cnumber)
& (fr<=row) & (row<=tr) & (fc<=col) & (col<=tc)  THEN
A[row-fr,col-fc] := num;
END;
Texts.Scan(sc);
END;
END;
END DoReadMatrix;

PROCEDURE ReadMatrix* (f: ARRAY OF CHAR; fromrow,torow,fromcol,tocol: SIGNED32; VAR A: ARRAY OF ARRAY OF FLOAT64): BOOLEAN;
VAR r,c: SIGNED32;    T: Texts.Text;     F: Files.File; len: SIGNED32;
BEGIN
F := Files.Old(f);
IF F=NIL THEN aM.Warning;    aM.SS(f," does not exist");    RETURN FALSE END;
T := TextFrames.Text(f);
r:= -1;  c := -1;
Scan(T,r,c,NIL,len,TRUE);
IF (fromrow>torow) OR (fromcol>tocol) OR (torow>r) OR (tocol>c) THEN
aM.Warning; aM.SISI("Length of file: rows ",r," columns ",c);
aM.S("Problems with reading, check ranges");
RETURN FALSE;
END;
DoReadMatrix(T,fromrow,torow,fromcol,tocol,A);
RETURN TRUE;
END ReadMatrix;

PROCEDURE ReadRow* (f: ARRAY OF CHAR;    row: SIGNED32;    VAR v: vyLongrealVec.tVector;    VAR len: SIGNED32): BOOLEAN;
VAR r,c: SIGNED32;    T: Texts.Text;     F: Files.File;
BEGIN
IF v=NIL THEN v := vyLongrealVec.New(0) END;
F := Files.Old(f);
IF F=NIL THEN aM.Warning;    aM.SS(f," does not exist");    RETURN FALSE END;
T := TextFrames.Text(f);
r:= row;  c := -1;
Scan(T,r,c,v,len,FALSE);
IF len=0 THEN RETURN FALSE END;
vyLongrealVec.SetLen(v,len);
vyBase.Update(v);
RETURN TRUE;
END ReadRow;

PROCEDURE ReadBinaryRow* (f: ARRAY OF CHAR;    row: SIGNED32;    VAR v: vyLongrealVec.tVector;    VAR len: SIGNED32): BOOLEAN;
VAR   F: Files.File; R: Files.Rider;
BEGIN
IF v=NIL THEN v := vyLongrealVec.New(0) END;
F := Files.Old(f);
IF F=NIL THEN aM.Warning;    aM.SS(f," does not exist");    RETURN FALSE END;
Files.Set(R,F,0);
DoReadBinaryRow(R,v,row,len);
vyLongrealVec.SetLen(v,len);
vyBase.Update(v);
RETURN TRUE;
END ReadBinaryRow;

PROCEDURE ReadColumn* (f: ARRAY OF CHAR;    column: SIGNED32;    VAR v: vyLongrealVec.tVector;    VAR len: SIGNED32): BOOLEAN;
VAR r,c: SIGNED32;    T: Texts.Text;   F: Files.File;
BEGIN
IF v=NIL THEN v := vyLongrealVec.New(0) END;
F := Files.Old(f);
IF F=NIL THEN aM.Warning;    aM.SS(f," does not exist");    RETURN FALSE END;
T := TextFrames.Text(f);
r:= -1;  c := column;
Scan(T,r,c,v,len,FALSE);
IF len=0 THEN RETURN FALSE END;
vyLongrealVec.SetLen(v,len);
vyBase.Update(v);
RETURN TRUE
END ReadColumn;

PROCEDURE DoAnalyze* (f: ARRAY OF CHAR; VAR r,c: SIGNED32);
VAR  T: Texts.Text;   F: Files.File;   len: SIGNED32;
BEGIN
F := Files.Old(f);
IF F=NIL THEN aM.Warning;    aM.SS(f," does not exist");    RETURN  END;
T := TextFrames.Text(f);
Scan(T,r,c,NIL,len,TRUE);
END DoAnalyze;

PROCEDURE AppendRow* (f: ARRAY OF CHAR;    v: vyLongrealVec.tVector;    VAR len: SIGNED32;    id: BOOLEAN);
VAR w: Texts.Writer;   i: SIGNED32;    T: Texts.Text;    x: FLOAT64;    name: ARRAY 64 OF CHAR;
BEGIN
T := TextFrames.Text(f);    Texts.OpenWriter(w);
vyName.GetObjId(v,name);
IF id THEN
Texts.WriteString(w,name);     Texts.Write(w," ");
END;
FOR i := 0 TO vyLongrealVec.Len(v)-1 DO
x := vyLongrealVec.Get(v,i);
Texts.WriteLongRealFix (w,x,15,15,0);    Texts.Write(w," ");
END;
Texts.WriteLn(w);
Texts.Append(T,w.buf);
WriteAscii(T,f);
len := vyLongrealVec.Len(v)-1;
END AppendRow;

PROCEDURE AppendRowA* (f: ARRAY OF CHAR;    VAR A: ARRAY OF FLOAT64;    len: SIGNED32);
VAR w: Texts.Writer;   i: SIGNED32;    T: Texts.Text;    x: FLOAT64;
BEGIN
T := TextFrames.Text(f);    Texts.OpenWriter(w);
FOR i := 0 TO len-1 DO
x := A[i];
Texts.WriteLongRealFix (w,x,15,15,0);    Texts.Write(w," ");
END;
Texts.WriteLn(w);
Texts.Append(T,w.buf);
WriteAscii(T,f);
END AppendRowA;

PROCEDURE AppendRowAT (VAR w: Texts.Writer;  VAR A: ARRAY OF FLOAT64;    len: SIGNED32);
VAR   i: SIGNED32;       x: FLOAT64;
BEGIN
FOR i := 0 TO len-1 DO
x := A[i];
Texts.WriteLongRealFix (w,x,15,15,0);    Texts.Write(w," ");
END;
Texts.WriteLn(w);   Texts.Write(w,0AX);
END AppendRowAT;

PROCEDURE AppendRowATI (VAR w: Texts.Writer;  VAR A: ARRAY OF SIGNED16;    len: SIGNED32);
VAR   i: SIGNED32;       x: SIGNED16;
BEGIN
FOR i := 0 TO len-1 DO
x := A[i];
Texts.WriteInt (w,x,1);    Texts.Write(w," ");
END;
Texts.WriteLn(w);   Texts.Write(w,0AX);
END AppendRowATI;

PROCEDURE WriteMatrix* (f: ARRAY OF CHAR;    VAR A: ARRAY OF ARRAY OF FLOAT64): BOOLEAN;
VAR w: Texts.Writer;   i: SIGNED32;    T: Texts.Text;
BEGIN
NEW(T); Texts.Open(T,"");
Texts.OpenWriter(w );
FOR i := 0 TO LEN(A)-1 DO
AppendRowAT(w,A[i],LEN(A[i]));
END;
Texts.Append(T,w.buf);
WriteAscii(T,f);
RETURN TRUE;
END WriteMatrix;

PROCEDURE WriteMatrixI* (f: ARRAY OF CHAR;    VAR A: ARRAY OF ARRAY OF SIGNED16): BOOLEAN;
VAR w: Texts.Writer;   i: SIGNED32;    T: Texts.Text;
BEGIN
NEW(T); Texts.Open(T,"");
Texts.OpenWriter(w );
FOR i := 0 TO LEN(A)-1 DO
AppendRowATI(w,A[i],LEN(A[i]));
END;
Texts.Append(T,w.buf);
WriteAscii(T,f);
RETURN TRUE;
END WriteMatrixI;

PROCEDURE WriteMatrixTransposed* (f: ARRAY OF CHAR;    VAR A: ARRAY OF ARRAY OF FLOAT64): BOOLEAN;
VAR w: Texts.Writer;   i,y: SIGNED32;    T: Texts.Text;
X: POINTER TO ARRAY OF FLOAT64;
BEGIN
NEW(T); Texts.Open(T,"");
Texts.OpenWriter(w );
NEW(X,LEN(A));
FOR i := 0 TO LEN(A[0])-1 DO
FOR y := 0 TO LEN(A)-1 DO
X[y] := A[y,i];
END;
AppendRowAT(w,X^,LEN(X^));
END;
Texts.Append(T,w.buf);
WriteAscii(T,f);
RETURN TRUE;
END WriteMatrixTransposed;

PROCEDURE WriteVec* (f: ARRAY OF CHAR;    v: vyLongrealVec.tVector;    VAR len: SIGNED32);
VAR w: Texts.Writer;   i: SIGNED32;    T: Texts.Text;    x: FLOAT64;
BEGIN
NEW(T); Texts.Open(T,"test");
Texts.OpenWriter(w);
Texts.Delete(T,0,T.len);
FOR i := 0 TO vyLongrealVec.Len(v)-1 DO
Texts.WriteInt(w,i,5);     Texts.Write(w," ");
x := vyLongrealVec.Get(v,i);
Texts.WriteLongRealFix (w,x,15,15,0);    Texts.WriteLn(w);
END;
Texts.Append(T,w.buf);
WriteAscii(T,f);
len := vyLongrealVec.Len(v)-1;
END WriteVec;

PROCEDURE Analyze*;
VAR l: antsCommands.tScanList;    str: ARRAY 64 OF CHAR;    rows,columns: SIGNED32;
BEGIN
l:= antsCommands.ScanFromPar();
IF antsCommands.ExpectStringFromKeyword(l,"filename",str) THEN
DoAnalyze(str,rows,columns);
aM.SISI("File has rows: ",rows," and columns: ",columns);
END;
END Analyze;

PROCEDURE TransposeFile*;
VAR l: antsCommands.tScanList;    str,str2: ARRAY 64 OF CHAR;    rows,columns: SIGNED32;    A: POINTER TO ARRAY OF ARRAY OF FLOAT64;
BEGIN
l:= antsCommands.ScanFromPar();
IF antsCommands.ExpectStringFromKeyword(l,"from",str) &
antsCommands.ExpectStringFromKeyword(l,"to",str2)
THEN
DoAnalyze(str,rows,columns);
NEW(A,rows,columns);
IF ReadMatrix(str,0,rows-1,0,columns-1,A^) THEN
IF  WriteMatrixTransposed(str2,A^) THEN END;
END;
END;
END TransposeFile;

PROCEDURE FileToBinary*;
VAR l: antsCommands.tScanList;    str,str2: ARRAY 64 OF CHAR;    rows,columns: SIGNED32;
A: POINTER TO ARRAY OF ARRAY OF FLOAT64; F: Files.File; R: Files.Rider;
BEGIN
l:= antsCommands.ScanFromPar();
IF antsCommands.ExpectStringFromKeyword(l,"from",str) &
antsCommands.ExpectStringFromKeyword(l,"to",str2)
THEN
DoAnalyze(str,rows,columns);
NEW(A,rows,columns);
IF ReadMatrix(str,0,rows-1,0,columns-1,A^) THEN
F := Files.New(str2);
IF F=NIL THEN aM.Warning; aM.S("Something wrong! "); END;
Files.Set(R,F,0);
DoWriteBinaryMatrix(R,A^);
Files.Register(F);
ELSE
aM.Warning; aM.S("Something wrong ");
END;
END;
END FileToBinary;


PROCEDURE Append*;
VAR l: antsCommands.tScanList;    str: ARRAY 64 OF CHAR;    data: vyBase.Object;    len: SIGNED32;    id: BOOLEAN;
BEGIN
l:= antsCommands.ScanFromPar();
IF antsCommands.ExpectStringFromKeyword(l,"filename",str)
& antsCommands.ExpectObjectFromKeyword(l,"data",data)
THEN
WITH data: vyLongrealVec.tVector DO
IF antsCommands.FindKeyword(l,"id") THEN id := TRUE ELSE id := FALSE END;
AppendRow(str,data,len,id);
END;
END;
END Append;

PROCEDURE Write*;
VAR l: antsCommands.tScanList;    str: ARRAY 64 OF CHAR;    data: vyBase.Object;    len: SIGNED32;
BEGIN
l:= antsCommands.ScanFromPar();
IF antsCommands.ExpectStringFromKeyword(l,"filename",str)
& antsCommands.ExpectObjectFromKeyword(l,"data",data)
THEN
WITH data: vyLongrealVec.tVector DO
WriteVec(str,data,len);
END;
END;
END Write;


*)