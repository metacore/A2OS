MODULE SSH;   (* GF 26.07.2002 / 5.12.2020*)

IMPORT Streams, Files, Strings, Log := KernelLog, Commands, Beep,
	A := SSHAuthorize, SSHChannels, SSHTerminal;

CONST
	CR = 0DX; NL = 0AX;
	
TYPE
	Channel = SSHChannels.Channel;
	
	PROCEDURE Usage( send: BOOLEAN );
	BEGIN
		Log.String( "usage: SSH." );
		IF send THEN  Log.String( "Send" )  ELSE  Log.String( "Receive" )  END;
		Log.String( "  user@host  filename[>filename]  ... ~" );  Log.Ln
	END Usage;
	

	PROCEDURE Connect( arg: Streams.Reader; send: BOOLEAN;  VAR uid, host: ARRAY OF CHAR ): A.Connection;
	VAR
		str: ARRAY 128 OF CHAR;
		strings: Strings.StringArray;
		conn: A.Connection;
	BEGIN
		IGNORE arg.GetString( str );  conn := NIL;
		strings := Strings.Split( str, '@' );
		IF LEN( strings^ ) = 2 THEN
			COPY( strings[0]^, uid );
			COPY( strings[1]^, host );
			conn := A.OpenConnection( host, uid );
		ELSE  
			Usage( send )
		END;
		strings := Strings.Split( host, '.' );
		COPY( strings[0]^, host );
		RETURN conn
	END Connect;
	
	PROCEDURE Terminal*;
	BEGIN
		SSHTerminal.Open
	END Terminal;
	
	PROCEDURE SendCommand( w: Streams.Writer; CONST cmd, fname: ARRAY OF CHAR );
	BEGIN
		w.Update;
		w.String( "stty -echo raw; " );
		w.String( cmd );  w.Char( ' ' );  w.String( fname );
		w.Char( CR ); 
		w.Update
	END SendCommand;
	
	PROCEDURE Sync( w: Streams.Writer );
	BEGIN
		w.Char( 0X );  w.Update
	END Sync;


	(**  SSH.Send  user@host  {  <filename>[:<remote filename> ] }  ~ *)
	PROCEDURE Send*( context: Commands.Context );
	VAR
		f: Files.File;
		locFileName, remFileName, str, uid, host: ARRAY 128 OF CHAR;
		strings: Strings.StringArray;
		chan: Channel; 
		conn: A.Connection;
	BEGIN
		conn := Connect( context.arg, TRUE, uid, host );
		IF conn = NIL THEN  RETURN  END;
		WHILE context.arg.GetString( str ) DO
			strings := Strings.Split( str, '>' );
			IF LEN( strings^ ) = 1 THEN
				locFileName := str;  remFileName := str
			ELSE
				COPY( strings[0]^, locFileName );  COPY( strings[1]^, remFileName )
			END;
			Log.String( locFileName );  Log.String( "  =>  " );
			Log.String( host );  Log.Char( ':' );  Log.String( remFileName ); Log.String( "    " );
			
			f := Files.Old( locFileName );
			IF f # NIL THEN
				chan := SSHChannels.OpenSession( conn, FALSE );
				SendFile( f, chan, remFileName );
				chan.Close
			ELSE  
				Beep.Beep( 1000 );
				Log.Ln;  Log.String( "### file not found: " );  
				Log.String( locFileName );  Log.Ln
			END;
		END;
		conn.Disconnect( 11, "Good bye" )
	END Send;


	PROCEDURE SendFile( f: Files.File;  chan: Channel;  CONST fileName: ARRAY OF CHAR );
	VAR
		fr: Files.Reader;  flen, sent: Files.Size;
		rchan: Streams.Reader;  wchan: Streams.Writer; ch: CHAR;
	BEGIN
		Streams.OpenWriter( wchan, chan.Send );
		Streams.OpenReader( rchan, chan.Receive );
		
		SendCommand( wchan, "scp -q -t", fileName ); 
		rchan.Char( ch ); (* sync *)	
		
		flen := f.Length( );
		wchan.String( "C0644 " );  wchan.Int( flen, 0 );  wchan.Char( ' ' );  wchan.String( fileName );  
		wchan.Char( CR );  wchan.Char( NL );  wchan.Update;
		rchan.Char( ch ); (* sync *)
		IF ORD( ch ) IN {1, 2} THEN
			Beep.Beep( 1000 );
			Log.Ln;  Log.String( "### transfer failed: " );
			REPEAT
				rchan.Char( ch );  Log.Char( ch )
			UNTIL ch = NL;
			chan.Close
		ELSE
			IF flen > 100000H THEN  Log.Ln ELSE  Log.Char( '.' )  END;
			Files.OpenReader( fr, f, 0 );  sent := 0;
			WHILE sent < flen DO
				fr.Char( ch ); wchan.Char( ch ); INC( sent ); 
				IF sent MOD 2000H = 0 THEN  Log.Char( '.' )  END;
				IF sent MOD 100000H = 0 THEN  Log.Ln  END
			END;
			wchan.Update;
			chan.Eof;
			Log.Char( ' ' );  Log.Int( sent, 0 ); Log.String( " bytes sent." ); Log.Ln
			END
	END SendFile;


	(**  SSH.Receive  user@host  {  <filename>[:<local filename>] }  ~ *)
	PROCEDURE Receive*( context: Commands.Context );
	VAR
		locFileName, remFileName, str, uid, hostname: ARRAY 128 OF CHAR;
		strings: Strings.StringArray;
		conn: A.Connection;
		chan: Channel; 
	BEGIN
		conn := Connect( context.arg, FALSE, uid, hostname );
		IF conn = NIL THEN  RETURN  END;
		WHILE context.arg.GetString( str ) DO
			(* filename or filename:filename *)
			strings := Strings.Split( str, '>' );
			IF LEN( strings^ ) = 1 THEN
				remFileName := str;
				strings := Strings.Split( remFileName, '/' );
				COPY( strings[ LEN( strings ) - 1]^, locFileName )
			ELSE
				COPY( strings[0]^, remFileName );  COPY( strings[1]^, locFileName )
			END;
			Log.String( hostname );  Log.Char( ':' );  Log.String( remFileName );  
			Log.String( "  =>  " );  Log.String( locFileName );  Log.String( "    " );
			
			chan := SSHChannels.OpenSession( conn, FALSE );
			ReceiveFile( chan, remFileName, locFileName );
			chan.Close
		END;
		conn.Disconnect( 11, "Good bye" )
	END Receive;


	PROCEDURE ReceiveFile( chan: Channel; CONST remName, locName: ARRAY OF CHAR );
	VAR 
		f: Files.File;  fw: Files.Writer;  
		flen, received: SIGNED32;
		rchan: Streams.Reader;  
		wchan: Streams.Writer;
		ch: CHAR;
		name: ARRAY 64 OF CHAR;
	BEGIN
		Streams.OpenWriter( wchan, chan.Send );
		Streams.OpenReader( rchan, chan.Receive );
		SendCommand( wchan, "scp -q -f", remName ); 
		Sync( wchan );
		rchan.Char( ch ); (* sync *)
		IF ORD( ch ) IN {1, 2} THEN
			Beep.Beep( 1000 );
			Log.Ln;  Log.String( "### transfer failed: " );
			REPEAT
				rchan.Char( ch );  Log.Char( ch )
			UNTIL ch = NL;
			RETURN
		END;
		rchan.Char( ch );	
		WHILE ch # ' ' DO  rchan.Char( ch )  END;   (* skip file mode *)
		IGNORE rchan.GetInteger( flen, FALSE );
		IGNORE rchan.GetString( name );  (* skip filename *)
		Sync( wchan );
		rchan.Char( ch ); (* sync *)
		
		f := CreateFile( locName );  Files.OpenWriter( fw, f, 0 );  
		IF flen > 100000H THEN  Log.Ln ELSE  Log.Char( '.' )  END;
		received := 0;
		WHILE received < flen DO
			rchan.Char( ch ); fw.Char( ch );  INC( received );
			IF received MOD 2000H = 0 THEN  Log.Char( '.' )  END;
			IF received MOD 100000H = 0 THEN  Log.Ln  END
		END;
		fw.Update;
		Files.Register( f );
		Log.Char( ' ' );  Log.Int( received, 0 );  Log.String( " bytes received." ); Log.Ln
	END ReceiveFile;
	
	
	PROCEDURE CreateFile( CONST name: ARRAY OF CHAR ): Files.File;
	VAR 
		tname, backup: ARRAY 128 OF CHAR;  res: INTEGER;
		f: Files.File;
	BEGIN
		tname := "."; 
		Strings.Append( tname, Files.PathDelimiter ); 
		Strings.Append( tname, name );
		f := Files.Old( tname );
		IF f # NIL THEN
			(* file exists in current working directory, rename it *)
			f.Close;
			COPY( name, backup );  Strings.Append( backup, ".Bak" );
			Files.Rename( name, backup, res );
		END;
		RETURN Files.New( name )
	END CreateFile;


END SSH.


