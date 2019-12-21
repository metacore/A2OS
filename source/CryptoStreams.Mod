MODULE CryptoStreams;	(* GF, de/encrypting streams *)

IMPORT Streams, CryptoCiphers, CryptoAES, CryptoMD5, Strings;

CONST
	WriteError = 2907;
	BufferSize = 1024;	(* multiple of any cipher blocksize ! *)
	
TYPE 
	Cipher* = CryptoCiphers.Cipher;
	Position = Streams.Position;
		
	EncryptingWriter* = OBJECT (Streams.Writer)
		VAR
			out: Streams.Writer;
			cipher: Cipher;
			eos: BOOLEAN;  (* end of stream reached *)

		PROCEDURE Send( CONST data: ARRAY OF CHAR;  ofs, len: SIZE;  prop: BOOLEAN;  VAR res: INTEGER );
		VAR
			buf: ARRAY BufferSize OF CHAR;  i: SIZE;
		BEGIN
			IF len > 0 THEN  (* len=0 may be caused by out.Update calls after padding *)
				ASSERT( ~eos, WriteError );
				ASSERT( (len MOD cipher.blockSize = 0) OR prop );
				i := 0;
				WHILE i < len DO
					buf[i] := data[ofs+i];  INC( i );
				END;
				WHILE i MOD cipher.blockSize # 0 DO
					buf[i] := 0X;  INC( i );  
					eos := TRUE (* after padding has occurred no further output is allowed *)
				END;
				cipher.Encrypt( buf, 0, i );
				out.Bytes( buf, 0, i );
				IF prop THEN  out.Update  END
			END;
			res := out.res;
		END Send;
		
		
		(* disable methods not allowed in encrypted streams ------- *)
		PROCEDURE CanSetPos*( ): BOOLEAN;
		BEGIN
			RETURN FALSE
		END CanSetPos;

		PROCEDURE SetPos*( pos: Position );
		BEGIN
			HALT( 1234 )
		END SetPos;
		
		
		PROCEDURE Pos*( ): Position;
		BEGIN
			RETURN  out.Pos()
		END Pos;
		

		PROCEDURE &InitCrWriter*( output: Streams.Writer; c: Cipher );
		(* cipher must be fully initialized (e.g. got by NewCippher() below) *)
		BEGIN
			out := output;  cipher := c;  eos := FALSE;
			InitWriter( Send, BufferSize )
		END InitCrWriter;
	
	END EncryptingWriter;
	
	
	
	DecryptingReader* = OBJECT (Streams.Reader)
		VAR
			in: Streams.Reader;
			cipher: Cipher;
			
		PROCEDURE Receive( VAR buf: ARRAY OF CHAR; ofs, size, min: SIZE; VAR len: SIZE; VAR res: INTEGER );
		VAR
			received, pos: SIZE;
		BEGIN
			ASSERT( size MOD cipher.blockSize = 0 );
			in.Bytes( buf, ofs, size, received ); 
			IF received >= cipher.blockSize THEN
				pos := 0;
				REPEAT
					cipher.Decrypt( buf, pos, cipher.blockSize );
					INC( pos, cipher.blockSize );  DEC( received, cipher.blockSize )
				UNTIL received < cipher.blockSize;
				len := pos;
				res := Streams.Ok
			ELSE
				res := Streams.EOF
			END;
		END Receive;
		
		
		(* disable methods that are not allowed in encrypted streams ------- *)
		PROCEDURE CanSetPos*( ): BOOLEAN;
		BEGIN
			RETURN FALSE
		END CanSetPos;

		PROCEDURE SetPos*( pos: Position );
		BEGIN
			HALT( 1234 )
		END SetPos;
		
		
		PROCEDURE &InitCrReader*( input: Streams.Reader; c: Cipher );
		(* cipher must be fully initialized, (e.g. got by NewCipher() below) *)
		BEGIN
			in := input; cipher := c; 
			InitReader( Receive, BufferSize );
			received := input.Pos()
		END InitCrReader;
	
	END DecryptingReader;
	
	
		
	PROCEDURE NewCipher*( CONST key: ARRAY OF CHAR ): Cipher;
	VAR
		cipher: CryptoAES.Cipher;
		md5: CryptoMD5.Hash;
		hkey: ARRAY 32 OF CHAR;
		i: INTEGER;
	BEGIN
		NEW( md5 );  md5.Initialize;
		md5.Update( key, 0, Strings.Length( key ) );  
		md5.GetHash( hkey, 0 );
		FOR i := 0 TO 15 DO  hkey[i + 16] := hkey[i]  END;
		NEW( cipher );  
		cipher.InitKey( hkey, 256 );  cipher.SetIV( hkey, CryptoCiphers.CBC );
		RETURN cipher
	END NewCipher;
	

END CryptoStreams.

