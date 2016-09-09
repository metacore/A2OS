MODULE StdIO;	(** AUTHOR gf;  PURPOSE "Unix standard IO and argument channels *)

(* Commands.Context for programs running outside Aos *)

IMPORT S := SYSTEM, Modules, Commands, Streams, Unix;

CONST 
	AddrSize = SIZEOF( ADDRESS );
TYPE
	String=POINTER TO ARRAY OF CHAR;
VAR 
	env-: Commands.Context;

PROCEDURE Args(): String;
VAR size, pos: SIZE; i,j: LONGINT; str: String;
	argc: LONGINT;
	argv {UNTRACED}: POINTER {UNSAFE} TO ARRAY OF POINTER {UNSAFE} TO ARRAY OF CHAR;
BEGIN
	argc := Unix.argc;
	argv := Unix.argv;
	pos := 0;
	FOR i := 0 TO argc-1 DO
		j := 0; 
		WHILE argv[i,j] # 0X DO
			INC(pos); INC(j);
		END;
		INC(pos);
	END;
	size := pos + 1;
	NEW(str, size);
	pos := 0;
	FOR i := 0 TO argc-1 DO
		j := 0; 
		WHILE argv[i,j] # 0X DO
			str[pos] := argv[i,j];
			INC(pos); INC(j);
		END;
		str[pos] := " ";
		INC(pos);
	END;
	str[pos] := 0X;
	RETURN str;
END Args;

PROCEDURE ReceiveStdin( VAR data: ARRAY OF CHAR;  ofs, size, min: LONGINT;  VAR len, res: LONGINT );
VAR ures: LONGINT;
BEGIN
	len := 0;
	REPEAT
		ures := Unix.read( 0, ADDRESSOF( data[ofs] ), size );
		IF ures > 0 THEN  INC( ofs, ures );  DEC( size, ures );  INC( len, ures )  END;
	UNTIL (len >= min) OR ((ures <= 0) & (Unix.errno() # Unix.EINTR));
	IF len > 0 THEN  res := Streams.Ok  ELSE  res := Streams.EOF  END
END ReceiveStdin;

PROCEDURE SendStdout( CONST data: ARRAY OF CHAR;  ofs, len: LONGINT;  prop: BOOLEAN;  VAR res: LONGINT );
VAR ignore: LONGINT;
BEGIN
	ignore := Unix.write( 1, ADDRESSOF( data[ofs] ), len );  res := Streams.Ok
END SendStdout;


PROCEDURE SendErrout( CONST data: ARRAY OF CHAR;  ofs, len: LONGINT;  prop: BOOLEAN;  VAR res: LONGINT );
VAR ignore: LONGINT;
BEGIN
	ignore := Unix.write( 2, ADDRESSOF( data[ofs] ), len );  res := Streams.Ok
END SendErrout;

PROCEDURE Cleanup;
BEGIN
	env.error.Update;
	env.out.Update
END Cleanup;

PROCEDURE Setup;
VAR
	arg: Streams.StringReader;
	stdin: Streams.Reader;
	stdout: Streams.Writer;
	errout: Streams.Writer;
	str: String;
BEGIN
	str := Args();
	NEW( arg, LEN(str) ); arg.Set(str^);
	NEW( stdin, ReceiveStdin, 1024 );
	NEW( stdout, SendStdout, 1024 );
	NEW( errout, SendErrout, 512 );
	NEW( env, stdin, arg, stdout, errout, NIL );
	Modules.InstallTermHandler( Cleanup )
END Setup

BEGIN
	Setup
END  StdIO.
