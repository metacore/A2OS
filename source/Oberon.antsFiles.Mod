MODULE antsFiles IN Oberon;   (** fof  **)
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
Parts of this module, especially writing and scanning Ascii-Streams is taken from Texts.Mod,
Writing and Reading Numbers is taken from Files.Mod

copyright by ETH recalled:

ETH Oberon, Copyright 2000 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/
*)



IMPORT Files, Texts, Strings, antsSecurity, Reals IN A2, SYSTEM, aM := antsMessages, vyIntVec, vyLongintVec, vyRealVec, vyLongrealVec;

CONST
	CR* = Strings.CR;  LF* = Strings.LF;  TAB* = Strings.Tab;

	OldTextBlockId = 1X;

	inval* = 0;  bin* = 1;  ascii* = 2;

TYPE
	Rider* = OBJECT
	VAR R*: Files.Rider;
		type*: SIGNED16;

		reverse*: BOOLEAN;
		ignoreNL*, noExponent*: BOOLEAN;   (** skip new line characters before reading a line *)
		eot*, err*: BOOLEAN;
		nextCh: CHAR;   (** Character immediately following the last symbol scanned. *)
		line*: SIGNED32;   (** # carriage returns scanned so far. *)
		class: SIGNED16;   (** Scan result: Int, Real, String etc. *)
		i: SIGNED32;
		x: FLOAT32;
		y: FLOAT64;
		c: CHAR;
		len: SIGNED8;   (** Length of name or string scanned. *)
		s: ARRAY 64 OF CHAR;
		scanneropen: BOOLEAN;
		check: SIGNED32;

		PROCEDURE  (* VAR R: Rider*) WriteType*;
		BEGIN
			CASE SELF.type OF
			bin:  SELF.Write( 0F1X );  SELF.Write( "b" );  SELF.Write( "i" );  SELF.Write( "n" );
			| ascii:
			END
		END WriteType;

		PROCEDURE  (* VAR R: Rider*) ReadType*;
		VAR ch: CHAR;  pos: SIGNED32;
		BEGIN
			pos := SELF.Pos();  SELF.Read( ch );
			IF ch # 0F1X THEN SELF.SetPos( pos );  SELF.SetAscii;  aM.SI( "Type: ASCII at pos ", pos );  RETURN END;
			SELF.Read( ch );
			IF ch # "b" THEN SELF.SetPos( pos );  SELF.SetAscii;  RETURN END;
			SELF.Read( ch );
			IF ch # "i" THEN SELF.SetPos( pos );  SELF.SetAscii;  RETURN END;
			SELF.Read( ch );
			IF ch # "n" THEN SELF.SetPos( pos );  SELF.SetAscii;  RETURN END;
			SELF.SetBin;  aM.SI( "Type: BIN at pos", pos )
		END ReadType;

		PROCEDURE  (* VAR R: Rider*) Read*( VAR ch: CHAR );
		BEGIN
			DoRead( SELF, ch )
		END Read;

		PROCEDURE  (* VAR R: Rider*) ReadBytes*( VAR ch: ARRAY OF SYSTEM.BYTE;  num: SIGNED32 );
		BEGIN
			Files.ReadBytes( SELF.R, ch, num );
			IF SELF.reverse THEN Turn( ch, num ) END;
			SELF.eot := SELF.R.eof
		END ReadBytes;

		PROCEDURE  (* VAR R: Rider*) ReadInt*( VAR x: SIGNED16 );
		BEGIN
			CASE SELF.type OF
			bin:  BinReadInt( SELF, x )
			| ascii:
					AsciiReadInt( SELF, x )
			END
		END ReadInt;

		PROCEDURE  (* VAR R: Rider*) ReadIntsFix*( VAR x: ARRAY OF SIGNED16;  num: SIGNED32 );
		VAR i: SIGNED32;
		BEGIN
			i := 0;
			WHILE (i < num) DO SELF.ReadInt( x[i] );  INC( i ) END
		END ReadIntsFix;

		PROCEDURE  (* VAR R: Rider*) ReadIntsLine*( VAR x: vyIntVec.tVector );
		VAR num: SIGNED32;  val: SIGNED16;
		BEGIN
			IF x = NIL THEN x := vyIntVec.New( 0 ) ELSE vyIntVec.SetLen( x, 0 ) END;
			StartReading( SELF );  num := 0;
			WHILE (~StopReading( SELF, num )) DO SELF.ReadInt( val );  vyIntVec.Append( val, x ) END
		END ReadIntsLine;

		PROCEDURE  (* VAR R: Rider*) ReadLInt*( VAR x: SIGNED32 );
		BEGIN
			CASE SELF.type OF
			bin:  BinReadLInt( SELF, x )
			| ascii:
					AsciiReadLInt( SELF, x )
			END
		END ReadLInt;

		PROCEDURE  (* VAR R: Rider*) ReadLIntsFix*( VAR x: ARRAY OF SIGNED32;  num: SIGNED32 );
		VAR i: SIGNED32;
		BEGIN
			i := 0;
			WHILE (i < num) DO SELF.ReadLInt( x[i] );  INC( i ) END
		END ReadLIntsFix;

		PROCEDURE  (* VAR R: Rider*) ReadLIntsLine*( VAR x: vyLongintVec.tVector );
		VAR num: SIGNED32;  val: SIGNED32;
		BEGIN
			IF x = NIL THEN x := vyLongintVec.New( 0 ) ELSE vyLongintVec.SetLen( x, 0 ) END;
			StartReading( SELF );  num := 0;
			WHILE (~StopReading( SELF, num )) DO SELF.ReadLInt( val );  vyLongintVec.Append( val, x ) END
		END ReadLIntsLine;

		PROCEDURE  (* VAR R: Rider*) ReadReal*( VAR x: FLOAT32 );
		BEGIN
			CASE SELF.type OF
			bin:  BinReadReal( SELF, x )
			| ascii:
					AsciiReadReal( SELF, x )
			END
		END ReadReal;

		PROCEDURE  (* VAR R: Rider*) ReadRealsFix*( VAR x: ARRAY OF FLOAT32;  num: SIGNED32 );
		VAR i: SIGNED32;
		BEGIN
			i := 0;
			WHILE (i < num) DO SELF.ReadReal( x[i] );  INC( i ) END
		END ReadRealsFix;

		PROCEDURE  (* VAR R: Rider*) ReadRealsLine( VAR x: vyRealVec.tVector );
		VAR num: SIGNED32;  val: FLOAT32;
		BEGIN
			IF x = NIL THEN x := vyRealVec.New( 0 ) ELSE vyRealVec.SetLen( x, 0 ) END;
			StartReading( SELF );  num := 0;
			WHILE (~StopReading( SELF, num )) DO SELF.ReadReal( val );  vyRealVec.Append( val, x ) END
		END ReadRealsLine;

		PROCEDURE  (* VAR R: Rider*) ReadLReal*( VAR x: FLOAT64 );
		BEGIN
			CASE SELF.type OF
			bin:  BinReadLReal( SELF, x )
			| ascii:
					AsciiReadLReal( SELF, x )
			END
		END ReadLReal;

		PROCEDURE  (* VAR R: Rider*) ReadLRealsFix*( VAR x: ARRAY OF FLOAT64;  num: SIGNED32 );
		VAR i: SIGNED32;
		BEGIN
			i := 0;
			WHILE (i < num) DO SELF.ReadLReal( x[i] );  INC( i ) END
		END ReadLRealsFix;

		PROCEDURE  (* VAR R: Rider*) ReadLRealsLine*( VAR x: vyLongrealVec.tVector );
		VAR num: SIGNED32;  val: FLOAT64;
		BEGIN
			IF x = NIL THEN x := vyLongrealVec.New( 0 ) ELSE vyLongrealVec.SetLen( x, 0 ) END;
			StartReading( SELF );  num := 0;
			WHILE (~StopReading( SELF, num )) DO SELF.ReadLReal( val );  vyLongrealVec.Append( val, x ) END
		END ReadLRealsLine;

		PROCEDURE  (* VAR R: Rider*) ReadString*( VAR x: ARRAY OF CHAR );
		BEGIN
			CASE SELF.type OF
			bin:  BinReadString( SELF, x )
			| ascii:
					AsciiReadString( SELF, x )
			END
		END ReadString;

		PROCEDURE  (* VAR R: Rider*) ReadUntil*( ch: CHAR ): BOOLEAN;
		BEGIN
			RETURN WaitFor( SELF, ch )
		END ReadUntil;

	(*PROCEDURE (VAR R: Rider) ReadLn* ();  (* Skip white spaces and read until CR or until no white space *)
	VAR ch: CHAR;
BEGIN
	LOOP
		SELF.Read(ch);
		IF ch = CR THEN INC(SELF.line);  RETURN
		ELSIF (ch # " ") & (ch # TAB) & (ch # LF) THEN EXIT
		END
	END;
	SELF.SetPos(SELF.Pos() - 1);  SELF.nextCh := ch
END ReadLn;
*)

		PROCEDURE  (* VAR R: Rider*) ReadLn*;   (* Skip white spaces and read until CR, CR-LF, LF OR LF-CR  or until no white space *)
		VAR ch: CHAR;
		BEGIN
			LOOP
				SELF.Read( ch );
				IF (ch = CR) THEN
					INC( SELF.line );  SELF.Read( ch );
					IF ch = LF THEN SELF.Read( ch );  END;
					EXIT
				ELSIF (ch = LF) THEN
					INC( SELF.line );  SELF.Read( ch );
					IF ch = CR THEN SELF.Read( ch );  END;
					EXIT;
				ELSIF (ch # " ") & (ch # TAB) THEN EXIT
				END
			END;
			SELF.SetPos( SELF.Pos() - 1 );  SELF.nextCh := ch
		END ReadLn;

		PROCEDURE  (* VAR R: Rider*) Write*( ch: CHAR );
		BEGIN
			DoWrite( SELF, ch )
		END Write;

		PROCEDURE  (* VAR R: Rider*) WriteBytes*( VAR ch: ARRAY OF SYSTEM.BYTE;  num: SIGNED32 );
		BEGIN
			IF SELF.reverse THEN Turn( ch, num ) END;
			Files.WriteBytes( SELF.R, ch, num )
		END WriteBytes;

		PROCEDURE  (* VAR R: Rider*) WriteInt*( x: SIGNED16 );
		BEGIN
			CASE SELF.type OF
			bin:  BinWriteInt( SELF, x )
			| ascii:
					AsciiWriteInt( SELF, x )
			END
		END WriteInt;

		PROCEDURE  (* VAR R: Rider*) WriteEmptyLine*;
		BEGIN
			CASE SELF.type OF
			bin:  SELF.WriteLInt( 0 );
			| ascii:
					SELF.WriteLn()
			END
		END WriteEmptyLine;

		PROCEDURE  (* VAR R: Rider*) WriteIntsFix*( VAR x: ARRAY OF SIGNED16;  num: SIGNED32 );
		VAR i: SIGNED32;
		BEGIN
			i := 0;
			WHILE (i < num) DO SELF.WriteInt( x[i] );  INC( i ) END;
			StopWriting( SELF )
		END WriteIntsFix;

		PROCEDURE  (* VAR R: Rider*) WriteIntsLine*( x: vyIntVec.tVector );
		VAR i, num: SIGNED32;
		BEGIN
			IF x = NIL THEN num := 0 ELSE num := vyIntVec.Len( x );  END;
			StartWriting( SELF, num );  i := 0;
			WHILE (i < num) DO SELF.WriteInt( vyIntVec.Get( x, i ) );  INC( i ) END;
			StopWriting( SELF )
		END WriteIntsLine;

		PROCEDURE  (* VAR R: Rider*) WriteLInt*( x: SIGNED32 );
		BEGIN
			CASE SELF.type OF
			bin:  BinWriteLInt( SELF, x )
			| ascii:
					AsciiWriteLInt( SELF, x )
			END
		END WriteLInt;

		PROCEDURE  (* VAR R: Rider*) WriteLIntsFix*( VAR x: ARRAY OF SIGNED32;  num: SIGNED32 );
		VAR i: SIGNED32;
		BEGIN
			i := 0;
			WHILE (i < num) DO SELF.WriteLInt( x[i] );  INC( i ) END;
			StopWriting( SELF )
		END WriteLIntsFix;

		PROCEDURE  (* VAR R: Rider*) WriteLIntsLine*( x: vyLongintVec.tVector );
		VAR i, num: SIGNED32;
		BEGIN
			IF x = NIL THEN num := 0 ELSE num := vyLongintVec.Len( x );  END;
			StartWriting( SELF, num );  i := 0;
			WHILE (i < num) DO SELF.WriteLInt( vyLongintVec.Get( x, i ) );  INC( i ) END;
			StopWriting( SELF )
		END WriteLIntsLine;

		PROCEDURE  (* VAR R: Rider*) WriteReal*( x: FLOAT32 );
		BEGIN
			CASE SELF.type OF
			bin:  BinWriteReal( SELF, x )
			| ascii:
					AsciiWriteReal( SELF, x )
			END
		END WriteReal;

		PROCEDURE  (* VAR R: Rider*) WriteRealsFix*( VAR x: ARRAY OF FLOAT32;  num: SIGNED32 );
		VAR i: SIGNED32;
		BEGIN
			i := 0;
			WHILE (i < num) DO SELF.WriteReal( x[i] );  INC( i ) END;
			StopWriting( SELF )
		END WriteRealsFix;

		PROCEDURE  (* VAR R: Rider*) WriteRealsLine*( x: vyRealVec.tVector );
		VAR i, num: SIGNED32;
		BEGIN
			IF x = NIL THEN num := 0 ELSE num := vyRealVec.Len( x );  END;
			StartWriting( SELF, num );  i := 0;
			WHILE (i < num) DO SELF.WriteReal( vyRealVec.Get( x, i ) );  INC( i ) END;
			StopWriting( SELF )
		END WriteRealsLine;

		PROCEDURE  (* VAR R: Rider*) WriteLReal*( x: FLOAT64 );
		BEGIN
			CASE SELF.type OF
			bin:  BinWriteLongReal( SELF, x )
			| ascii:
					AsciiWriteLongReal( SELF, x )
			END
		END WriteLReal;

		PROCEDURE  (* VAR R: Rider*) WriteLRealsFix*( VAR x: ARRAY OF FLOAT64;  num: SIGNED32 );
		VAR i: SIGNED32;
		BEGIN
			i := 0;
			WHILE (i < num) DO SELF.WriteLReal( x[i] );  INC( i ) END;
			StopWriting( SELF )
		END WriteLRealsFix;

		PROCEDURE  (* VAR R: Rider*) WriteLRealsLine*( x: vyLongrealVec.tVector );
		VAR i, num: SIGNED32;
		BEGIN
			num := vyLongrealVec.Len( x );  StartWriting( SELF, num );  i := 0;
			WHILE (i < num) DO SELF.WriteLReal( vyLongrealVec.Get( x, i ) );  INC( i ) END;
			StopWriting( SELF )
		END WriteLRealsLine;

		PROCEDURE  (* VAR R: Rider*) WriteString*( x: ARRAY OF CHAR );
		BEGIN
			CASE SELF.type OF
			bin:  BinWriteString( SELF, x )
			| ascii:
					AsciiWriteString( SELF, x )
			END
		END WriteString;

		PROCEDURE  (* VAR R: Rider*) WriteLn*;
		BEGIN
			SELF.Write( CR )
		END WriteLn;

		PROCEDURE  (* VAR R: Rider*) SetPos*( pos: SIGNED32 );
		BEGIN
			Files.Set( SELF.R, Files.Base( SELF.R ), pos )
		END SetPos;

		PROCEDURE  (* VAR R: Rider*) Set*( type: SIGNED16 );
		BEGIN
			aM.dSI( "antsFiles: SetRider to type", type );  SELF.type := type;  SELF.scanneropen := FALSE
		END Set;

		PROCEDURE  (* VAR R: Rider*) SetAscii*;
		BEGIN
			aM.dS( "antsFiles: SetRider Ascii" );  SELF.Set( ascii )
		END SetAscii;

		PROCEDURE  (* VAR R: Rider*) SetBin*;
		BEGIN
			aM.dS( "antsFiles: SetRider Bin" );  SELF.Set( bin )
		END SetBin;

		PROCEDURE  (* VAR R: Rider*) Enter*( VAR FR: Files.Rider );
		BEGIN
			aM.dS( "antsFiles.EnterRider" );  SELF.R := FR;  SELF.Set( bin );  SELF.scanneropen := FALSE;  SELF.eot := FR.eof;  SELF.reverse := FALSE;
			SELF.ignoreNL := FALSE;  SELF.err := FALSE;  SELF.line := 0;  SELF.noExponent := FALSE;
		END Enter;

		PROCEDURE  (* VAR R: Rider*) Leave*( VAR FR: Files.Rider );
		BEGIN
			aM.dS( "antsFiles.LeaveRider" );  FR := SELF.R
		END Leave;

		PROCEDURE  (* VAR R: Rider*) Old*( name: ARRAY OF CHAR ): BOOLEAN;
		VAR F: Files.File;  FR: Files.Rider;
		BEGIN
			aM.vSS( "antsFiles.Old", name );  F := Files.Old( name );
			IF F = NIL THEN aM.vS( "antsFiles.Old: failed" );  RETURN FALSE END;
			aM.vS( "antsFiles.Old: success" );  Files.Set( FR, F, 0 );  CheckIfText( FR );  SELF.Enter( FR );  RETURN TRUE
		END Old;

		PROCEDURE  (* VAR R: Rider*) ForceOld*( name: ARRAY OF CHAR );
		VAR F: Files.File;  FR: Files.Rider;
		BEGIN
			aM.vSS( "antsFiles.ForceOld", name );
			IF ~SELF.Old( name ) THEN antsSecurity.Halt( "could not open file" ) END;
		END ForceOld;

		PROCEDURE  (* VAR R: Rider*) New*( name: ARRAY OF CHAR ): BOOLEAN;
		VAR F: Files.File;  FR: Files.Rider;
		BEGIN
			aM.vSS( "antsFiles.New", name );  F := Files.New( name );
			IF F = NIL THEN aM.vS( "antsFiles.New: failed" );  RETURN FALSE END;
			aM.vS( "antsFiles.New: success" );  Files.Set( FR, F, 0 );  SELF.Enter( FR );  RETURN TRUE
		END New;

		PROCEDURE  (* VAR R: Rider*) ForceNew*( name: ARRAY OF CHAR );
		VAR F: Files.File;  FR: Files.Rider;
		BEGIN
			aM.vSS( "antsFiles.ForceNew", name );
			IF ~SELF.New( name ) THEN antsSecurity.Halt( "could not open file" ) END;
		END ForceNew;

		PROCEDURE  (* VAR R: Rider*) Pos*( ): SIGNED32;
		BEGIN
			RETURN Files.Pos( SELF.R )
		END Pos;

		PROCEDURE  (* VAR R: Rider*) Close*;
		BEGIN
			Files.Register( Files.Base( SELF.R ) );  Files.Close( Files.Base( SELF.R ) )
		END Close;

	END Rider;

VAR
	nameChars: ARRAY 256 OF BOOLEAN;
	TextBlockId (** First character of a text block. *) , DocBlockId, NoSpex, NoSpex2, TextSpex: CHAR;

	PROCEDURE StartReading( R: Rider );
	BEGIN
		CASE R.type OF
		bin:  R.ReadLInt( R.check );   (* aM.SI("Lencheck:",R.check); *)
		| ascii:
				R.check := R.line;
				R.ReadLn();   (* aM.SI("Starting to read line at:",R.check); *)
				IF R.ignoreNL THEN
					WHILE (R.line > R.check) DO R.check := R.line;  R.ReadLn();  END;
				END;
		END
	END StartReading;

	PROCEDURE StopReading( R: Rider;  VAR num: SIGNED32 ): BOOLEAN;
	BEGIN
		IF R.eot OR R.err THEN num := 0;  RETURN TRUE END;
		CASE R.type OF
		bin:  IF num < R.check THEN INC( num );  RETURN FALSE ELSE RETURN TRUE END;
		| ascii:
				R.ReadLn();
				(* aM.SISI("Stop?",R.line,"  > ",R.check); *)
				IF R.line > R.check THEN RETURN TRUE ELSE INC( num );  RETURN FALSE END
		END
	END StopReading;

	PROCEDURE StartWriting( R: Rider;  num: SIGNED32 );
	BEGIN
		CASE R.type OF
		bin:  R.WriteLInt( num );
		| ascii:
		END
	END StartWriting;

	PROCEDURE StopWriting( R: Rider );
	BEGIN
		CASE R.type OF
		bin:  | ascii:
				R.WriteLn()
		END
	END StopWriting;


	(*** ASCII Methods ****)

(** Write string s to W's buffer. *)
	PROCEDURE AsciiWriteString(W: Rider;  s: ARRAY OF CHAR );
	VAR i: SIGNED32;
	BEGIN
		i := 0;
		WHILE s[i] # 0X DO W.Write( s[i] );  INC( i ) END
	END AsciiWriteString;

(** Write integer x to W's buffer. Spaces are padded to the left until the number field is at least n characters long. *)
	PROCEDURE WriteInt( W: Rider;  x, n: SIGNED32 );
	VAR i, x0: SIGNED32;
		a: ARRAY 10 OF CHAR;
	BEGIN
		i := 0;
		IF x < 0 THEN
			IF x = MIN( SIGNED32 ) THEN AsciiWriteString( W, " -2147483648" );  RETURN ELSE DEC( n );  x0 := -x END
		ELSE x0 := x
		END;
		REPEAT a[i] := CHR( x0 MOD 10 + 30H );  x0 := x0 DIV 10;  INC( i ) UNTIL x0 = 0;
		WHILE n > i DO W.Write( " " );  DEC( n ) END;
		IF x < 0 THEN W.Write( "-" ) END;
		REPEAT DEC( i );  W.Write( a[i] ) UNTIL i = 0
	END WriteInt;

	PROCEDURE AsciiWriteInt( W: Rider;  x: SIGNED16 );
	BEGIN
		WriteInt( W, x, 0 );  W.Write( TAB )
	END AsciiWriteInt;

	PROCEDURE AsciiWriteLInt( W: Rider;  x: SIGNED32 );
	BEGIN
		WriteInt( W, x, 0 );  W.Write( TAB )
	END AsciiWriteLInt;

(** Write real x to W's buffer using n character positions. *)
	PROCEDURE WriteReal( W: Rider;  x: FLOAT32;  n: SIGNED32 );
	(* BM 1993.4.22. Do not simplify rounding! *)
	VAR e, h, i: SIGNED32;  y: FLOAT64;  z: FLOAT32;
		d: ARRAY 8 OF CHAR;
	BEGIN
		e := Reals.Expo( x );
		IF e = 255 THEN
			WHILE n > 8 DO W.Write( " " );  DEC( n ) END;
			h := Reals.NaNCode( x );
			IF h # 0 THEN AsciiWriteString( W, "     NaN" )
			ELSIF x < 0 THEN AsciiWriteString( W, "    -INF" )
			ELSE AsciiWriteString( W, "      INF" )
			END
		ELSE
			IF n <= 8 THEN n := 1 ELSE DEC( n, 7 ) END;
			REPEAT W.Write( " " );  DEC( n ) UNTIL n <= 7;   (* 0 <= n <= 7 fraction digits *)
			IF (e # 0) & (x < 0) THEN W.Write( "-" );  x := -x ELSE W.Write( " " ) END;
			IF e = 0 THEN
				h := 0 (* no denormals *)
			ELSE
				e := (e - 127) * 301 DIV 1000;   (* ln(2)/ln(10) = 0.301029996 *)
				IF e < 38 THEN
					z := SHORT( Reals.Ten( e + 1 ) );
					IF x >= z THEN y := LONG( x ) / LONG( z );  INC( e ) ELSE y := x * Reals.Ten( -e ) END
				ELSE y := x * Reals.Ten( -38 )
				END;
				IF y >= 10 THEN y := y * Reals.Ten( -1 ) + 0.5D0 / Reals.Ten( n );  INC( e )
				ELSE
					y := y + 0.5D0 / Reals.Ten( n );
					IF y >= 10 THEN y := y * Reals.Ten( -1 );  INC( e ) END
				END;
				y := y * Reals.Ten( 7 );  h := ENTIER( y )
			END;
			i := 7;
			WHILE i >= 0 DO d[i] := CHR( h MOD 10 + ORD( "0" ) );  h := h DIV 10;  DEC( i ) END;
			W.Write( d[0] );  W.Write( "." );  i := 1;
			WHILE i <= n DO W.Write( d[i] );  INC( i ) END;
			IF e < 0 THEN AsciiWriteString( W, "E-" );  e := -e ELSE AsciiWriteString( W, "E+" ) END;
			W.Write( CHR( e DIV 10 + ORD( "0" ) ) );  W.Write( CHR( e MOD 10 + ORD( "0" ) ) )
		END
	END WriteReal;
(** Write real x in a fixed point notation. n is the overall minimal length for the output field, f the number of fraction digits following the decimal point, E the fixed exponent (printed only when E # 0). *)
	PROCEDURE WriteRealFix( W: Rider;  x: FLOAT32;  n, f, E: SIGNED32 );
	(* BM 1993.4.22. Do not simplify rounding ! / JG formatting adjusted *)
	VAR e, h, i: SIGNED32;  r, y: FLOAT64;  z: FLOAT32;  s: CHAR;
		d: ARRAY 8 OF CHAR;
	BEGIN
		e := Reals.Expo( x );
		IF (e = 255) OR (ABS( E ) > 38) THEN
			WHILE n > 8 DO DoWrite( W, " " );  DEC( n ) END;
			h := Reals.NaNCode( x );
			IF h # 0 THEN AsciiWriteString( W, "     NaN" )
			ELSIF x < 0 THEN AsciiWriteString( W, "    -INF" )
			ELSE AsciiWriteString( W, "      INF" )
			END
		ELSE
			IF E = 0 THEN DEC( n, 2 ) ELSE DEC( n, 6 ) END;
			IF f < 0 THEN f := 0 END;
			IF n < f + 2 THEN n := f + 2 END;
			DEC( n, f );
			IF (e # 0) & (x < 0) THEN s := "-";  x := -x ELSE s := " " END;
			IF e = 0 THEN
				h := 0;  DEC( e, E - 1 ) (* no denormals *)
			ELSE
				e := (e - 127) * 301 DIV 1000;   (* ln(2)/ln(10) = 0.301029996 *)
				IF e < 38 THEN
					z := SHORT( Reals.Ten( e + 1 ) );
					IF x >= z THEN y := LONG( x ) / LONG( z );  INC( e ) ELSE y := x * Reals.Ten( -e ) END
				ELSE y := x * Reals.Ten( -38 )
				END;
				DEC( e, E - 1 );  i := -(e + f);
				IF i <= 0 THEN r := 5 * Reals.Ten( i ) ELSE r := 0 END;
				IF y >= 10 THEN y := y * Reals.Ten( -1 ) + r;  INC( e )
				ELSE
					y := y + r;
					IF y >= 10 THEN y := y * Reals.Ten( -1 );  INC( e ) END
				END;
				y := y * Reals.Ten( 7 );  h := ENTIER( y )
			END;
			i := 7;
			WHILE i >= 0 DO d[i] := CHR( h MOD 10 + ORD( "0" ) );  h := h DIV 10;  DEC( i ) END;
			IF n <= e THEN n := e + 1 END;
			IF e > 0 THEN
				WHILE n > e DO DoWrite( W, " " );  DEC( n ) END;
				DoWrite( W, s );  e := 0;
				WHILE n > 0 DO
					DEC( n );
					IF e < 8 THEN DoWrite( W, d[e] );  INC( e ) ELSE DoWrite( W, "0" ) END
				END;
				DoWrite( W, "." )
			ELSE
				WHILE n > 1 DO DoWrite( W, " " );  DEC( n ) END;
				DoWrite( W, s );  DoWrite( W, "0" );  DoWrite( W, "." );
				WHILE (0 < f) & (e < 0) DO DoWrite( W, "0" );  DEC( f );  INC( e ) END
			END;
			WHILE f > 0 DO
				DEC( f );
				IF e < 8 THEN DoWrite( W, d[e] );  INC( e ) ELSE DoWrite( W, "0" ) END
			END;
			IF E # 0 THEN
				IF E < 0 THEN AsciiWriteString( W, "E-" );  E := -E ELSE AsciiWriteString( W, "E+" ) END;
				DoWrite( W, CHR( E DIV 10 + ORD( "0" ) ) );  DoWrite( W, CHR( E MOD 10 + ORD( "0" ) ) )
			END
		END
	END WriteRealFix;

	PROCEDURE AsciiWriteReal( W: Rider;  x: FLOAT32 );
	BEGIN
		IF W.noExponent THEN WriteRealFix( W, x, 0, 15, 0 );  W.Write( TAB ) ELSE WriteReal( W, x, 20 );  W.Write( TAB ) END;
	END AsciiWriteReal;

(** Write FLOAT64 x to W's buffer using n character positions. *)
	PROCEDURE WriteLongReal(W: Rider;  x: FLOAT64;  n: SIGNED32 );
	(* BM 1993.4.22. Do not simplify rounding! *)
	VAR e, h, l, i: SIGNED32;  z: FLOAT64;
		d: ARRAY 16 OF CHAR;
	BEGIN
		e := Reals.ExpoL( x );
		IF e = 2047 THEN
			WHILE n > 9 DO W.Write( " " );  DEC( n ) END;
			Reals.NaNCodeL( x, h, l );
			IF (h # 0) OR (l # 0) THEN AsciiWriteString( W, "      NaN" )
			ELSIF x < 0 THEN AsciiWriteString( W, "     -INF" )
			ELSE AsciiWriteString( W, "      INF" )
			END
		ELSE
			IF n <= 9 THEN n := 1 ELSE DEC( n, 8 ) END;
			REPEAT W.Write( " " );  DEC( n ) UNTIL n <= 15;   (* 0 <= n <= 15 fraction digits *)
			IF (e # 0) & (x < 0) THEN W.Write( "-" );  x := -x ELSE W.Write( " " ) END;
			IF e = 0 THEN
				h := 0;  l := 0 (* no denormals *)
			ELSE
				e := (e - 1023) * 301029 DIV 1000000;   (* ln(2)/ln(10) = 0.301029996 *)
				z := Reals.Ten( e + 1 );
				IF x >= z THEN x := x / z;  INC( e ) ELSE x := x * Reals.Ten( -e ) END;
				IF x >= 10 THEN x := x * Reals.Ten( -1 ) + 0.5D0 / Reals.Ten( n );  INC( e )
				ELSE
					x := x + 0.5D0 / Reals.Ten( n );
					IF x >= 10 THEN x := x * Reals.Ten( -1 );  INC( e ) END
				END;
				x := x * Reals.Ten( 7 );  h := ENTIER( x );  x := (x - h) * Reals.Ten( 8 );  l := ENTIER( x )
			END;
			i := 15;
			WHILE i > 7 DO d[i] := CHR( l MOD 10 + ORD( "0" ) );  l := l DIV 10;  DEC( i ) END;
			WHILE i >= 0 DO d[i] := CHR( h MOD 10 + ORD( "0" ) );  h := h DIV 10;  DEC( i ) END;
			W.Write( d[0] );  W.Write( "." );  i := 1;
			WHILE i <= n DO W.Write( d[i] );  INC( i ) END;
			IF e < 0 THEN AsciiWriteString( W, "E-" );  e := -e ELSE AsciiWriteString( W, "E+" ) END;
			W.Write( CHR( e DIV 100 + ORD( "0" ) ) );  e := e MOD 100;  W.Write( CHR( e DIV 10 + ORD( "0" ) ) );  W.Write( CHR( e MOD 10 + ORD( "0" ) ) )
		END
	END WriteLongReal;
(** Write FLOAT64 x in a fixed point notation. n is the overall minimal length for the output field, f the number of fraction digits following the decimal point,
D the fixed exponent (printed only when D # 0). *)
	PROCEDURE WriteLongRealFix( W: Rider;  x: FLOAT64;  n, f, D: SIGNED32 );
	(* BM 1993.4.22. Do not simplify rounding! / JG formatting adjusted *)
	VAR e, h, l, i: SIGNED32;  r, z: FLOAT64;
		d: ARRAY 16 OF CHAR;
		s: CHAR;
	BEGIN
		e := Reals.ExpoL( x );
		IF (e = 2047) OR (ABS( D ) > 308) THEN
			WHILE n > 9 DO DoWrite( W, " " );  DEC( n ) END;
			Reals.NaNCodeL( x, h, l );
			IF (h # 0) OR (l # 0) THEN AsciiWriteString( W, "      NaN" )
			ELSIF x < 0 THEN AsciiWriteString( W, "     -INF" )
			ELSE AsciiWriteString( W, "      INF" )
			END
		ELSE
			IF D = 0 THEN DEC( n, 2 ) ELSE DEC( n, 7 ) END;
			IF n < 2 THEN n := 2 END;
			IF f < 0 THEN f := 0 END;
			IF n < f + 2 THEN n := f + 2 END;
			DEC( n, f );
			IF (e # 0) & (x < 0) THEN s := "-";  x := -x ELSE s := " " END;
			IF e = 0 THEN
				h := 0;  l := 0;  DEC( e, D - 1 ) (* no denormals *)
			ELSE
				e := (e - 1023) * 301029 DIV 1000000;   (* ln(2)/ln(10) = 0.301029996 *)
				z := Reals.Ten( e + 1 );
				IF x >= z THEN x := x / z;  INC( e ) ELSE x := x * Reals.Ten( -e ) END;
				DEC( e, D - 1 );  i := -(e + f);
				IF i <= 0 THEN r := 5 * Reals.Ten( i ) ELSE r := 0 END;
				IF x >= 10 THEN x := x * Reals.Ten( -1 ) + r;  INC( e )
				ELSE
					x := x + r;
					IF x >= 10 THEN x := x * Reals.Ten( -1 );  INC( e ) END
				END;
				x := x * Reals.Ten( 7 );  h := ENTIER( x );  x := (x - h) * Reals.Ten( 8 );  l := ENTIER( x )
			END;
			i := 15;
			WHILE i > 7 DO d[i] := CHR( l MOD 10 + ORD( "0" ) );  l := l DIV 10;  DEC( i ) END;
			WHILE i >= 0 DO d[i] := CHR( h MOD 10 + ORD( "0" ) );  h := h DIV 10;  DEC( i ) END;
			IF n <= e THEN n := e + 1 END;
			IF e > 0 THEN
				WHILE n > e DO DoWrite( W, " " );  DEC( n ) END;
				DoWrite( W, s );  e := 0;
				WHILE n > 0 DO
					DEC( n );
					IF e < 16 THEN DoWrite( W, d[e] );  INC( e ) ELSE DoWrite( W, "0" ) END
				END;
				DoWrite( W, "." )
			ELSE
				WHILE n > 1 DO DoWrite( W, " " );  DEC( n ) END;
				DoWrite( W, s );  DoWrite( W, "0" );  DoWrite( W, "." );
				WHILE (0 < f) & (e < 0) DO DoWrite( W, "0" );  DEC( f );  INC( e ) END
			END;
			WHILE f > 0 DO
				DEC( f );
				IF e < 16 THEN DoWrite( W, d[e] );  INC( e ) ELSE DoWrite( W, "0" ) END
			END;
			IF D # 0 THEN
				IF D < 0 THEN AsciiWriteString( W, "E-" );  D := -D ELSE AsciiWriteString( W, "E+" ) END;
				DoWrite( W, CHR( D DIV 100 + ORD( "0" ) ) );  D := D MOD 100;  DoWrite( W, CHR( D DIV 10 + ORD( "0" ) ) );
				DoWrite( W, CHR( D MOD 10 + ORD( "0" ) ) )
			END
		END
	END WriteLongRealFix;

	PROCEDURE AsciiWriteLongReal( W: Rider;  x: FLOAT64 );
	BEGIN
		IF W.noExponent THEN WriteLongRealFix( W, x, 0, 15, 0 );  W.Write( TAB )
		ELSE WriteLongReal( W, x, 20 );  W.Write( TAB )
		END;
	END AsciiWriteLongReal;

	(***** file Reader and Rider Block ******)

(** Open text scanner S and set it up at position pos in text T. *)
	PROCEDURE OpenScanner( R: Rider );
	BEGIN
		R.line := 0;  R.class := Texts.Inval;  R.Read( R.nextCh );
		IF ~R.eot THEN Files.Set( R.R, Files.Base( R.R ), Files.Pos( R.R ) - 1 ) END;
		R.scanneropen := TRUE
	END OpenScanner;

	PROCEDURE DoRead(R: Rider;  VAR ch: CHAR );
	BEGIN
		Files.Read( R.R, ch );  R.eot := R.R.eof
	END DoRead;



(** Read the next symbol. Whitespace is ignored. CR increments the line counter. *)
	PROCEDURE Scan( VAR S: Rider );
	CONST maxD = 32;   (* fixed size: maxD <= LEN(S.s)! *)
	VAR ch, E: CHAR;  neg, negE, hex, sign: BOOLEAN;  i, j, h, e, k, k1, k2, k3: SIGNED32;  y: FLOAT64;
		d: ARRAY maxD OF CHAR;

		PROCEDURE Read( VAR S: Rider;  VAR ch: CHAR );
		BEGIN
			S.Read( ch )
		END Read;

	BEGIN
		IF ~S.scanneropen THEN OpenScanner( S ) END;
		(*
	aM.SI("Scanning at pos: ",S.Pos());
	*)
		Read( S, ch );   (* undo undoing of lookahead *) S.nextCh := ch;  ch := S.nextCh;  i := 0;
		LOOP
			IF ch = CR THEN INC( S.line )
			ELSIF (ch # " ") & (ch # TAB) & (ch # LF) THEN EXIT
			END;
			S.Read( ch )
		END;
		IF ("A" <= CAP( ch )) & (CAP( ch ) <= "Z") OR (ch = ".") OR (ch = "/") (* OR (ch = ":") *) THEN  (*name*)
			REPEAT S.s[i] := ch;  INC( i );  Read( S, ch ) UNTIL ~(nameChars[ORD( ch )]) OR (i = LEN( S.s ) - 1);
			S.s[i] := 0X;
			IF (i = 1) & ((CAP( S.s[0] ) < "A") OR (CAP( S.s[0] ) > "Z")) THEN S.c := S.s[0];  S.class := Texts.Char
			ELSE S.len := SHORT( SHORT( i ) );  S.class := Texts.Name
			END
		ELSIF ch = 22X THEN  (*literal string*)
			Read( S, ch );
			WHILE (ch # 22X) & (ch >= " ") & (i # LEN( S.s ) - 1) DO S.s[i] := ch;  INC( i );  Read( S, ch ) END;
			WHILE (ch # 22X) & (ch >= " ") DO Read( S, ch ) END;
			S.s[i] := 0X;  S.len := SHORT( SHORT( i ) );  Read( S, ch );  S.class := Texts.String
		ELSE
			IF ch = "-" THEN sign := TRUE;  neg := TRUE;  Read( S, ch )
			ELSIF ch = "+" THEN sign := TRUE;  neg := FALSE;  Read( S, ch )
			ELSE sign := FALSE;  neg := FALSE
			END;
			IF ("0" <= ch) & (ch <= "9") THEN  (*number*)
				hex := FALSE;  j := 0;
				LOOP
					d[i] := ch;  INC( i );  Read( S, ch );
					IF (ch < "0") OR (i >= maxD) THEN EXIT END;
					IF "9" < ch THEN
						IF ("A" <= ch) & (ch <= "F") THEN hex := TRUE;  ch := CHR( ORD( ch ) - 7 )
						ELSIF ("a" <= ch) & (ch <= "f") THEN hex := TRUE;  ch := CHR( ORD( ch ) - 27H )
						ELSE EXIT
						END
					END
				END;
				IF (ch = "H") THEN  (*hex number*)
					Read( S, ch );  S.class := Texts.Int;
					IF i - j > 8 THEN j := i - 8 END;
					k := ORD( d[j] ) - 30H;  INC( j );
					IF (i - j = 7) & (k >= 8) THEN DEC( k, 16 ) END;
					WHILE j < i DO k := k * 10H + (ORD( d[j] ) - 30H);  INC( j ) END;
					IF neg THEN S.i := -k ELSE S.i := k END
				ELSIF (ch = ".") THEN  (*read real*)
					Read( S, ch );  h := i;
					WHILE ("0" <= ch) & (ch <= "9") & (i <= maxD) DO d[i] := ch;  INC( i );  Read( S, ch ) END;
					(*-------- begin floating-point handling BM 1993.3.10 -----------------------------------*)
					WHILE i MOD 8 # 0 DO d[i] := "0";  INC( i ) END;
					j := 0;  k := 0;  k1 := 0;  k2 := 0;  k3 := 0;   (* store digits 0..7, 8..15, 16..23, 24..31 in k, k1, k2, k3 *)
					WHILE j < 8 DO k := k * 10 + ORD( d[j] ) - ORD( "0" );  INC( j ) END;
					IF 8 < i THEN
						WHILE j < 16 DO k1 := k1 * 10 + ORD( d[j] ) - ORD( "0" );  INC( j ) END
					END;
					IF 16 < i THEN
						WHILE j < 24 DO k2 := k2 * 10 + ORD( d[j] ) - ORD( "0" );  INC( j ) END
					END;
					IF 24 < i THEN
						WHILE j < 32 DO k3 := k3 * 10 + ORD( d[j] ) - ORD( "0" );  INC( j ) END
					END;
					e := 0;  E := ch;
					IF ((E = "D") OR (E = "E") OR (E = "e")) THEN
						Read( S, ch );
						IF (ch = "-") THEN negE := TRUE;  Read( S, ch )
						ELSE
							negE := FALSE;
							IF (ch = "+") THEN Read( S, ch ) END
						END;
						WHILE ("0" <= ch) & (ch <= "9") DO e := e * 10 + ORD( ch ) - ORD( "0" );  Read( S, ch ) END;
						IF negE THEN e := -e END
					END;
					y := k3 * Reals.Ten( -32 ) + k2 * Reals.Ten( -24 );  y := y + k1 * Reals.Ten( -16 );
					IF ABS( e + h ) < 308 THEN y := (y + k * Reals.Ten( -8 )) / Reals.Ten( -e - h )
					ELSE
						y := (y + k * Reals.Ten( -8 )) * Reals.Ten( h );
						IF (e <= 308 - 32) OR (e <= 308) & (y < MAX( FLOAT64 ) / Reals.Ten( e )) THEN y := y * Reals.Ten( e ) ELSE y := MAX( FLOAT64 ) END
					END;

					IF E = "D" THEN
						IF y = MAX( FLOAT64 ) THEN
							S.class := Texts.Inval (* NaN *)
						ELSE
							S.class := Texts.LongReal;
							IF neg THEN S.y := -y ELSE S.y := y END;
							IF Reals.ExpoL( S.y ) = 0 THEN S.y := 0 END
						END
					ELSIF MAX( FLOAT32 ) < y THEN
						S.class := Texts.Inval (* NaN *)
					ELSE
						S.class := Texts.Real;
						IF neg THEN S.x := SHORT( -y ) ELSE S.x := SHORT( y ) END;
						IF Reals.Expo( S.x ) = 0 THEN S.x := 0 END
					END;
					(*-------- end floating-point handling BM 1993.3.10 -----------------------------------*)
					IF hex THEN S.class := Texts.Inval END
				ELSE  (*decimal integer*)
					S.class := Texts.Int;  k := 0;
					WHILE (j # i) & ((k < MAX( SIGNED32 ) DIV 10) OR
						(k = MAX( SIGNED32 ) DIV 10) & ((ORD( d[j] ) - 30H) <= MAX( SIGNED32 ) MOD 10)) DO  (*JG*)
						k := k * 10 + (ORD( d[j] ) - 30H);  INC( j )
					END;
					IF j # i THEN S.class := Texts.Inval ELSE
						IF neg THEN S.i := -k ELSE S.i := k END;
						IF hex THEN S.class := Texts.Inval ELSE S.class := Texts.Int END
					END
				END
			ELSE
				S.class := Texts.Char;
				IF sign THEN
					IF neg THEN S.c := "-" ELSE S.c := "+" END
				ELSE S.c := ch;  Read( S, ch )
				END
			END
		END;
		S.nextCh := ch;
		IF ~S.eot THEN Files.Set( S.R, Files.Base( S.R ), Files.Pos( S.R ) - 1 ) END
	END Scan;

	PROCEDURE InitScan;
	VAR i: SIGNED32;
	BEGIN
		FOR i := 0 TO 255 DO nameChars[i] := FALSE END;
		FOR i := 80H TO 96H DO nameChars[i] := TRUE END;   (* german characters *)
		FOR i := ORD( "0" ) TO ORD( "9" ) DO nameChars[i] := TRUE END;
		FOR i := ORD( "A" ) TO ORD( "Z" ) DO nameChars[i] := TRUE END;
		FOR i := ORD( "a" ) TO ORD( "z" ) DO nameChars[i] := TRUE END;
		nameChars[ORD( "@" )] := TRUE;   (* mail, compiler *)
		nameChars[ORD( "." )] := TRUE;   (* mail, filenames, compiler *)
		nameChars[ORD( "/" )] := TRUE;   (* filenames *)
		nameChars[ORD( ":" )] := TRUE;   (* filenames (Mac) *)
		nameChars[ORD( "_" )] := TRUE
	END InitScan;

(***** End of FileRider Block *****)


	PROCEDURE WhiteSpace*( c: CHAR ): BOOLEAN;
	BEGIN
		RETURN ((c = CR) OR (c = LF) OR (c = TAB) OR (c = " "))
	END WhiteSpace;

	PROCEDURE AsciiReadInt( R: Rider;  VAR x: SIGNED16 );   (* Read Integer Value ignoring Names *)
	VAR pos: SIGNED32;
	BEGIN
		pos := R.Pos();  Scan( R );
		WHILE (R.class = Texts.Name) & (~R.eot) DO Scan( R ) END;
		IF R.class = Texts.Int THEN
			IF R.i > MAX( SIGNED16 ) THEN HALT( 100 )
			ELSIF R.i < MIN( SIGNED16 ) THEN HALT( 101 )
			END;
			x := SHORT( R.i )
		ELSE R.err := TRUE;  R.SetPos( pos )
		END
	END AsciiReadInt;

	PROCEDURE BinReadInt( R: Rider;  VAR x: SIGNED16 );   (* Read Integer Value ignoring Names *)
	BEGIN
		R.ReadBytes( x, 2 )
	END BinReadInt;

	PROCEDURE AsciiReadLInt( R: Rider;  VAR x: SIGNED32 );   (* Read Integer Value ignoring Names *)
	VAR pos: SIGNED32;
	BEGIN
		pos := R.Pos();  Scan( R );
		WHILE (R.class = Texts.Name) & (~R.eot) DO Scan( R ) END;
		IF R.class = Texts.Int THEN x := (R.i) ELSE R.err := TRUE;  R.SetPos( pos ) END
	END AsciiReadLInt;

	PROCEDURE BinReadLInt( R: Rider;  VAR x: SIGNED32 );   (* Read Integer Value ignoring Names *)
	BEGIN
		R.ReadBytes( x, 4 )
	END BinReadLInt;

	PROCEDURE AsciiReadReal( R: Rider;  VAR x: FLOAT32 );   (* Read Integer Value ignoring Names *)
	VAR pos: SIGNED32;
	BEGIN
		pos := R.Pos();  Scan( R );
		WHILE (R.class = Texts.Name) & (~R.eot) DO Scan( R ) END;

		IF R.class = Texts.Int THEN x := R.i
		ELSIF R.class = Texts.Real THEN x := R.x
		ELSE R.err := TRUE;  R.SetPos( pos )
		END
	END AsciiReadReal;

	PROCEDURE BinReadReal( R: Rider;  VAR x: FLOAT32 );
	BEGIN
		R.ReadBytes( x, 4 )
	END BinReadReal;

	PROCEDURE AsciiReadLReal( R: Rider;  VAR x: FLOAT64 );   (* Read Integer Value ignoring Names *)
	VAR pos: SIGNED32;
	BEGIN
		pos := R.Pos();  Scan( R );
		WHILE (R.class = Texts.Name) & (~R.eot) DO Scan( R ) END;
		IF R.class = Texts.Int THEN x := R.i
		ELSIF R.class = Texts.Real THEN x := R.x
		ELSIF R.class = Texts.LongReal THEN x := R.y
		ELSE R.err := TRUE;  R.SetPos( pos )
		END
	END AsciiReadLReal;

	PROCEDURE BinReadLReal( R: Rider;  VAR x: FLOAT64 );
	BEGIN
		R.ReadBytes( x, 8 )
	END BinReadLReal;

	PROCEDURE AsciiReadString( R: Rider;  VAR x: ARRAY OF CHAR );
	VAR pos: SIGNED32;
	BEGIN
		pos := R.Pos();  Scan( R );
		IF (R.class = Texts.Name) OR (R.class = Texts.String) THEN COPY( R.s, x ) ELSE R.err := TRUE;  R.SetPos( pos ) END
	END AsciiReadString;

	PROCEDURE BinReadString( R: Rider;  VAR x: ARRAY OF CHAR );
	BEGIN
		Files.ReadString( R.R, x );  R.eot := R.R.eof
	END BinReadString;

	PROCEDURE WaitFor( R: Rider;  ch: CHAR ): BOOLEAN;
	VAR c: CHAR;
	BEGIN
		LOOP
			R.Read( c );
			IF c = ch THEN RETURN TRUE END;
			IF R.eot THEN RETURN FALSE END
		END
	END WaitFor;

	PROCEDURE DoWrite( R: Rider;  ch: CHAR );
	BEGIN
		Files.Write( R.R, ch )
	END DoWrite;

	PROCEDURE Turn( VAR ch: ARRAY OF SYSTEM.BYTE;  num: SIGNED32 );
	VAR c: SYSTEM.BYTE;  i: SIGNED32;
	BEGIN
		FOR i := 0 TO ((num - 1) DIV 2) DO c := ch[i];  ch[i] := ch[num - 1 - i];  ch[num - 1 - i] := c END
	END Turn;

	PROCEDURE BinWriteInt( R: Rider;  x: SIGNED16 );
	BEGIN
		R.WriteBytes( x, 2 )
	END BinWriteInt;

	PROCEDURE BinWriteLInt( R: Rider;  x: SIGNED32 );
	BEGIN
		R.WriteBytes( x, 4 )
	END BinWriteLInt;

	PROCEDURE BinWriteReal( R: Rider;  x: FLOAT32 );
	BEGIN
		R.WriteBytes( x, 4 )
	END BinWriteReal;

	PROCEDURE BinWriteLongReal( R: Rider;  x: FLOAT64 );
	BEGIN
		R.WriteBytes( x, 8 )
	END BinWriteLongReal;

	PROCEDURE BinWriteString( R: Rider;  x: ARRAY OF CHAR );
	BEGIN
		Files.WriteString( R.R, x )
	END BinWriteString;

	PROCEDURE ReadDocHeader( VAR R: Files.Rider;  VAR ch: CHAR );
	VAR len: SIGNED32;  x, y, w, h: SIGNED16;
		name: ARRAY 32 OF CHAR;
	BEGIN
		Files.Read( R, ch );
		ASSERT ( ch = 07X );
		Files.ReadString( R, name );  Files.ReadInt( R, x );  Files.ReadInt( R, y );  Files.ReadInt( R, w );  Files.ReadInt( R, h );
		Files.Read( R, ch );
		IF ch = 0F7X THEN  (* skip meta info *)
			Files.Read( R, ch );
			IF ch = 08X THEN Files.ReadLInt( R, len );  Files.Set( R, Files.Base( R ), Files.Pos( R ) + len );  Files.Read( R, ch ) END
		END
	END ReadDocHeader;

	PROCEDURE ToAscii( T: Texts.Text;  VAR R: Files.Rider );
	VAR r: Texts.Reader;  f: Files.File;  ch: CHAR;
	BEGIN
		f := Files.New( "" );  Files.Set( R, f, 0 );  Texts.OpenReader( r, T, 0 );  Texts.Read( r, ch );
		WHILE ~r.eot DO Files.Write( R, ch );  Texts.Read( r, ch ) END;
		Files.Set( R, f, 0 )
	END ToAscii;

	PROCEDURE CheckIfText*( VAR R: Files.Rider );
	VAR len: SIGNED32;  ch: CHAR;  T: Texts.Text;
	BEGIN
		Files.Read( R, ch );
		IF ch = DocBlockId THEN ReadDocHeader( R, ch ) END;
		IF (ch = TextBlockId) OR (ch = OldTextBlockId) THEN
			NEW( T );  Texts.Load( T, Files.Base( R ), Files.Pos( R ), len );  ToAscii( T, R )
		ELSE Files.Set( R, Files.Base( R ), Files.Pos( R ) - 1 )
		END
	END CheckIfText;

	PROCEDURE Test*;
	VAR RR: Rider;  i: SIGNED32;
		test: ARRAY 256 OF CHAR;
		v: vyRealVec.tVector;
	BEGIN
		(*
	F := Files.Old("testa");
	Files.Set(R,F,0);
	CheckIfText(R);
	RR.Open(R);
	RR.SetAscii;
	FOR i := 0 TO 10 DO
	Scan(RR);
	END;
	*)

		v := vyRealVec.New( 0 );  vyRealVec.Append( 0.010, v );  vyRealVec.Append( 0.020, v );  vyRealVec.Append( 1.010, v );
		vyRealVec.Append( 3.010, v );  vyRealVec.Append( 10.010, v );

		RR.ForceNew( "testc" );

		RR.Set( ascii );  RR.WriteString( "Testabc" );  RR.WriteLn();  RR.WriteRealsLine( v );  RR.WriteEmptyLine();  RR.WriteString( "Ende " );
		RR.Close;

		RR.ForceOld( "testc" );  RR.Set( ascii );  RR.ReadString( test );  aM.S( test );

		RR.ReadRealsLine( v );  aM.SI( "line1 ", vyLongrealVec.Len( v ) );  aM.SI( "pos", RR.Pos() );  RR.ReadRealsLine( v );  aM.SI( "line2 ", i );
		aM.SI( "pos", RR.Pos() );  RR.ReadRealsLine( v );  aM.SI( "line3 ", i );  aM.SI( "pos", RR.Pos() );  RR.ReadRealsLine( v );  aM.SI( "line4 ", i );
		aM.SI( "pos", RR.Pos() );

		RR.ReadString( test );  aM.S( test );
		IF RR.err THEN aM.S( "ERR" ) END;
		RR.Close
	END Test;

BEGIN
	aM.launch;  InitScan;  TextBlockId := 0F0X;  DocBlockId := 0F7X;  NoSpex := 0X;  TextSpex := 1X;  NoSpex2 := 2X;
END antsFiles.


antsFiles.Test

testc