MODULE StdCoder; (** AUTHOR "GF"; PURPOSE "Extract sources from BlackBox standardcoded archives" *)

IMPORT Streams, Commands, Files, Strings, Log := KernelLog;

CONST
	Tag = "StdCoder.Decode";
	Ok = Streams.Ok;
	OldVersion = 0; ThisVersion = 1;
	View = 1; File = 2; List = 3;
	N = 16384;

TYPE
	FileType = ARRAY 16 OF CHAR;

	FileList = POINTER TO RECORD
		next: FileList;
		oberonSource: BOOLEAN;
		oberonDoku: BOOLEAN;
		name: Files.FileName
	END;


VAR
	code: ARRAY 64 OF CHAR;
	revCode: ARRAY 256 OF SIGNED8;
	table: ARRAY N OF SIGNED8;

	PROCEDURE ShowError( n: SIGNED32 );
	BEGIN
		Log.String( "### StdCoder.Decode: " );
		CASE n OF
		|  1: Log.String("bad characters or EOT" );
		|  2: Log.String("checksum error" );
		|  3: Log.String("incompatible version" );
		|  4: Log.String("filing error" );
		|  5: Log.String("directory ^0 not found" );
		|  6: Log.String("file ^0 not found" );
		|  7: Log.String("illegal path" );
		|  8: Log.String("bad tag" );
		|  9: Log.String("disk write protected" );
		| 10: Log.String("io error" );
		END;
		Log.Ln
	END ShowError;


	PROCEDURE read( r: Streams.Reader; VAR res: INTEGER ): SIGNED32;
	VAR ch: CHAR; x: SIGNED32;
	BEGIN
		IF res = 0 THEN
			REPEAT  r.Char( ch );  x := revCode[ORD( ch )]  UNTIL (x >= 0) OR (r.res # Ok);
			IF r.res # Ok THEN  res := 1  END
		END;
		IF res # 0 THEN  x := 0  END;
		RETURN x
	END read;


	PROCEDURE peeknext( r: Streams.Reader ): CHAR;
	VAR ch: CHAR;
	BEGIN
		r.Char( ch );  (* consume *)  RETURN  r.Peek()
	END peeknext;


	PROCEDURE ReadHeader(		r: Streams.Reader;
									VAR res: INTEGER;  VAR name: ARRAY OF CHAR;  VAR type: SIGNED32 );
	VAR
		x, bits, i: SIGNED32; ch: CHAR; tag: ARRAY 16 OF CHAR;
	BEGIN
		tag := Tag; i := 0;  res := 0;
		r.SkipWhitespace;  ch := r.Peek( );
		IF ch = tag[0] THEN
			ch := peeknext( r );  i := 1;
			WHILE (tag[i] # 0X) & (ch = tag[i]) DO  ch := peeknext( r );  INC( i )  END;
			IF tag[i] # 0X THEN  res := 8  END
		END;
		IF res = 0 THEN
			i := 0;  bits := 0;  x := 0;
			REPEAT
				WHILE (res = 0) & (bits < 8) DO
					INC( x, ASH( read( r, res ), bits ) ); INC( bits, 6 )
				END;
				IF res = 0 THEN
					ch := CHR(x MOD 256);  x := x DIV 256;  DEC( bits, 8 );
					name[i] := ch; INC(i);
				END
			UNTIL (res # 0) OR (ch = 0X);
			i := read(r, res);
			IF res = 0 THEN
				IF i IN {OldVersion, ThisVersion} THEN  type := read( r, res )
				ELSE  res := 3
				END
			END
		ELSE  res := 8
		END
	END ReadHeader;


	PROCEDURE SkipFileType(r: Streams.Reader; VAR res: INTEGER ): BOOLEAN;
	VAR x, bits, i: SIGNED32; ch: CHAR;  ftype: FileType;
	BEGIN
		res := 0;  i := 0; bits := 0;  x := 0;
		REPEAT
			WHILE (res = 0) & (bits < 8) DO  INC( x, ASH( read( r, res ), bits ) ); INC( bits, 6 )  END;
			IF res = 0 THEN
				ch := CHR( x MOD 256 );  x := x DIV 256;  DEC( bits, 8 );  ftype[i] := ch;  INC( i )
			END
		UNTIL (res # 0) OR (ch = 0X);
		RETURN res = 0
	END SkipFileType;


	PROCEDURE ReadInteger( r: Streams.Reader; VAR res: INTEGER ): SIGNED32;
	VAR bits, val: SIGNED32;
	BEGIN
		bits := 0;  val := 0;
		REPEAT  val := val + ASH( read( r, res ), bits ); INC( bits, 6 )  UNTIL (res # 0) OR (bits >= 32);
		RETURN val
	END ReadInteger;


	PROCEDURE ReadFile( r: Streams.Reader; VAR res: INTEGER ): Files.File;
	VAR
		hash, x, bits, i, len, sum, s: SIGNED32; byte: SIGNED8;  f: Files.File;  w: Files.Writer;
	BEGIN
		f := Files.New( "" );  Files.OpenWriter( w, f, 0 );
		FOR i := 0 TO N - 1 DO  table[i] := 0  END;
		bits := 0;  hash := 0;  sum := 0;  len := ReadInteger( r, res );
		WHILE (res = 0) & (len # 0) DO
			IF bits = 0 THEN  x := read( r, res ); bits := 6  END;
			IF ODD( x ) THEN	(* Incorrect prediction -> 1'xxxx'xxxx *)
				x := x DIV 2;  DEC( bits );
				WHILE (res = 0) & (bits < 8) DO  INC( x, ASH( read( r, res ), bits ) ); INC( bits, 6 )  END;
				i := x MOD 256;
				IF i > MAX(SIGNED8) THEN  i := i - 256  END;
				byte := SIGNED8( i );  x := x DIV 256;  DEC( bits, 8 );
				table[hash] := byte
			ELSE  (* correct prediction *)
				byte := table[hash];  x := x DIV 2;  DEC( bits )
			END;
			hash := (16 * hash + byte MOD 256) MOD N;
			sum := (sum + byte MOD 256) MOD (16 * 1024);

			w.Char( CHR( byte ) );  DEC( len );
		END;
		IF res = 0 THEN
			s := ReadInteger( r, res );
			IF (res = 0) & (s # sum) THEN  res := 2  END
		END;
		w.Update;
		RETURN f
	END ReadFile;


	PROCEDURE NewFile( CONST name: ARRAY OF CHAR ): Files.File;
	VAR
		f: Files.File;  res: INTEGER;  name2: Files.FileName;
	BEGIN
		f := Files.Old( name );
		IF f # NIL THEN
			COPY( name, name2 );  Strings.Append( name2, ".Bak" );  Files.Rename( name, name2, res );
			Log.String( "Backup created in " );  Log.String( name2 );  Log.Ln
		END;
		RETURN Files.New( name );
	END NewFile;


	PROCEDURE CutSuffixODC( VAR n: Files.FileName );
	VAR i: SIGNED32
	BEGIN
		i := 0;  WHILE n[i] # 0X DO  INC(i)  END;
		IF (i > 4) & (n[i -4] = ".") & (CAP(n[i-3]) = "O") & (CAP(n[i-2]) = "D") & (CAP(n[i-1]) = "C") THEN
			n[i - 4] := 0X
		END;
	END CutSuffixODC;


	PROCEDURE PositionReader( VAR r: Files.Reader; str: ARRAY OF CHAR );
	VAR pos, i: SIGNED32; c: CHAR;
	BEGIN
		pos := 0;
		LOOP
			r.SetPos( pos );
			REPEAT r.Char( c ); INC( pos )  UNTIL (c = str[0]) OR (r.res # Ok);
			i := 1;
			LOOP
				IF r.res = Ok THEN  r.Char( c )  ELSE (*failed*) r.SetPos( 0 );  RETURN  END;
				IF c # str[i] THEN  (*try again*)  EXIT  END;
				INC( i );
				IF str[i] = 0X THEN  (* found *) r.SetPos( pos - 1 );  RETURN  END
			END
		END
	END PositionReader;


	PROCEDURE ExtractAscii( src: Files.File;  CONST startstring, destname: ARRAY OF CHAR );
	CONST CR = 0DX; LF = 0AX;  HT = 09X;
	VAR r: Files.Reader; w: Files.Writer; destfile: Files.File; ch: CHAR;
	BEGIN
		Log.String( "extract: " ); Log.String( destname ); Log.Ln;
		destfile := NewFile( destname );  Files.OpenWriter( w, destfile, 0 );
		Files.OpenReader( r, src, 0 );  PositionReader( r, startstring );
		r.Char( ch );
		REPEAT
			IF (ch = CR) OR (ch = LF) THEN  w.Ln
			ELSIF ((ch >= ' ') & (ch <= '~')) OR (ch = HT) THEN  w.Char( ch )
			END;
			r.Char( ch )
		UNTIL r.res # Ok;
		w.Update;  Files.Register( destfile )
	END ExtractAscii;


	PROCEDURE DecodeFile( r: Streams.Reader; CONST name: Files.FileName );
	VAR res: INTEGER; f: Files.File;
	BEGIN
		IF SkipFileType( r, res ) THEN
			f := ReadFile( r, res );
			IF res = 0 THEN  ExtractAscii( f, "???????", name )
			ELSE  ShowError( res )
			END
		ELSE  ShowError( res )
		END
	END DecodeFile;


	PROCEDURE DecodeFileList ( r: Streams.Reader; VAR res: INTEGER );
	VAR
		i: SIGNED32; p, files: FileList; ch: CHAR;
		f: Files.File; fr: Files.Reader; path: Files.FileName;
		sa: Strings.StringArray; suffix: ARRAY 16 OF CHAR;
	BEGIN
		IF SkipFileType( r, res ) THEN
			f := ReadFile( r, res );
			IF res = 0 THEN
				files := NIL;  p := NIL;
				Files.OpenReader( fr, f, 0 );
				fr.Char( ch );
				WHILE (fr.res = Ok) & (res = 0) DO
					i := 0;
					WHILE (fr.res = Ok) & (ch # 0X) DO  path[i] := ch;  INC( i );  fr.Char( ch )  END;
					path[i] := 0X;
					CutSuffixODC( path );
					sa := Strings.Split( path, '/' );
					IF LEN( sa ) > 1 THEN
						COPY( sa[LEN( sa ) - 1]^, path );
						COPY( sa[LEN( sa ) - 2]^, suffix );
						Strings.Append( path, '.' );  Strings.Append( path, suffix )
					END;
					IF fr.res=Ok THEN
						IF p = NIL THEN  NEW( p ); files := p  ELSE  NEW( p.next ); p := p.next  END;
						p.oberonSource := suffix = "Mod";
						p.oberonDoku := suffix = "Docu";
						p.name := path;
						fr.Char( ch )
					ELSE res := 1
					END
				END;
				p := files;
				WHILE (res = 0) & (p # NIL) DO
					IF SkipFileType( r, res ) THEN
						f := ReadFile( r, res );
						IF res = 0 THEN
							IF p.oberonSource THEN  ExtractAscii( f, "MODULE", p.name )
							ELSIF p.oberonDoku THEN  ExtractAscii( f, "DEFINITION", p.name )
							ELSE  (* ignore *)
							END
						END
					END;
					p := p.next
				END
			END
		END
	END DecodeFileList;


	PROCEDURE Decode* ( c: Commands.Context );
	VAR
		name: Files.FileName;
		res, type: SIGNED32;
		r: Streams.Reader;
	BEGIN
		r := c.arg;
		ReadHeader( r, res, name, type );
		CutSuffixODC( name );
		IF res = 0 THEN
			IF type = View THEN (*DecodeView(rd, name)	*) DecodeFile( r, name )
			ELSIF type = File THEN  DecodeFile( r, name )
			ELSIF type = List THEN  DecodeFileList( r, res );
				IF res # 0 THEN  ShowError( res )  END
			ELSE ShowError( 3 )
			END
		ELSE ShowError( res )
		END
	END Decode;


	PROCEDURE InitCodes;
	VAR i: SIGNED8;  j: SIGNED32;
	BEGIN
		FOR j := 0 TO 255 DO  revCode[j] := -1  END;
		code[0] := ".";  revCode[ORD(".")] := 0;
		code[1] := ",";  revCode[ORD(",")] := 1;
		i := 2;  j := ORD("0");
		WHILE j <= ORD("9") DO code[i] := CHR(j); revCode[j] := i; INC(i); INC(j) END;
		j := ORD("A");
		WHILE j <= ORD("Z") DO code[i] := CHR(j); revCode[j] := i; INC(i); INC(j) END;
		j := ORD("a");
		WHILE j <= ORD("z") DO code[i] := CHR(j); revCode[j] := i; INC(i); INC(j) END;
		ASSERT(i = 64, 60)
	END InitCodes;

BEGIN
	InitCodes
END StdCoder.


	System.Free StdCoder ~
