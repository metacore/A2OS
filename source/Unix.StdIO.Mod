MODULE StdIO;	(** AUTHOR gf;  PURPOSE "Unix standard IO and argument channels *)

(* Commands.Context for programs running outside Aos *)

IMPORT SYSTEM, Modules, Commands, Streams,Pipes , Unix;

#IF COOP THEN
	IMPORT Activities, Counters, Environment;
#END

CONST
	Echo* = FALSE;
TYPE
	String=POINTER TO ARRAY OF CHAR;
VAR
	env-: Commands.Context;
	stdInDecoupler: Pipes.ReadDecoupler;

PROCEDURE Args(): String;
VAR size, pos: SIZE; i,j: LONGINT; str: String;
	argc: LONGINT;
	argv {UNTRACED}: POINTER {UNSAFE} TO ARRAY OF POINTER {UNSAFE,UNTRACED} TO ARRAY OF CHAR;
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

#IF COOP THEN

	VAR processor: Activities.Activity;
	VAR reader: Unix.Thread_t;
	VAR read : RECORD buffer: ADDRESS; size, result: SIZE; ready: BOOLEAN END;

	PROCEDURE {C} ReaderThread (): ADDRESS;
	BEGIN {UNCOOPERATIVE, UNCHECKED}
		Activities.CallVirtual (ReadActivity, NIL, processor);
		RETURN NIL;
	END ReaderThread;

	PROCEDURE ReadActivity (p: ADDRESS);
	BEGIN
		WHILE Environment.status = Environment.Running DO
			BEGIN {EXCLUSIVE}
				Counters.Inc (Activities.awaiting);
				AWAIT (~read.ready);
				read.result := Unix.read( Unix.stdin, read.buffer, read.size );
				read.ready := TRUE;
				Counters.Dec (Activities.awaiting);
			END;
		END;
	END ReadActivity;

	PROCEDURE Read (buffer: ADDRESS; size: SIZE): SIZE;
	BEGIN {EXCLUSIVE}
		read.buffer := buffer;
		read.size := size;
		read.ready := FALSE;
		IF processor = NIL THEN
			processor := Activities.CreateVirtualProcessor ();
			ASSERT (Unix.pthread_create(ADDRESS OF reader, NIL, ReaderThread, NIL) = 0);
		END;
		AWAIT (read.ready);
		RETURN read.result;
	END Read;

#ELSE

	PROCEDURE Read (buffer: ADDRESS; size: SIZE): SIZE;
	BEGIN RETURN Unix.read( Unix.stdin, buffer, size );
	END Read;

#END

PROCEDURE ReceiveStdin( VAR data: ARRAY OF CHAR;  ofs, size, min: LONGINT;  VAR len: LONGINT; VAR res: WORD );
VAR ures: SIZE;  i, err: LONGINT;
BEGIN
	len := 0;
	REPEAT
		ures := Read( ADDRESSOF (data[ofs]), size );
		IF ures > 0 THEN
			INC( ofs, LONGINT(ures) );  DEC( size, LONGINT(ures) );  INC( len, LONGINT(ures) )
		END;
		IF ures < 0 THEN err := Unix.errno() END;
	UNTIL (len >= min) OR ((ures <= 0) & (err # Unix.EINTR) & (err # 0));
	IF len >= min THEN  res := Streams.Ok  ELSE  res := Streams.EOF  END;
END ReceiveStdin;

PROCEDURE SendStdout( CONST data: ARRAY OF CHAR;  ofs, len: LONGINT;  prop: BOOLEAN;  VAR res: WORD );
VAR ignore: SIZE;
BEGIN
	ignore := Unix.write( 1, ADDRESSOF( data[ofs] ), len );  res := Streams.Ok
END SendStdout;


PROCEDURE SendErrout( CONST data: ARRAY OF CHAR;  ofs, len: LONGINT;  prop: BOOLEAN;  VAR res: WORD );
VAR ignore: SIZE;
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
	NEW(stdInDecoupler, ReceiveStdin);
	NEW( stdin, stdInDecoupler.Receive, 1024 );
	NEW( stdout, SendStdout, 1024 );
	NEW( errout, SendErrout, 512 );
	NEW( env, stdin, arg, stdout, errout, NIL );
	Modules.InstallTermHandler( Cleanup );
END Setup

BEGIN
	Setup;
END  StdIO.
