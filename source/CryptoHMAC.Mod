MODULE CryptoHMAC;  	(** AUTHOR "G.F."; PURPOSE "RFC 2104 HMAC"; *)

IMPORT Hashes := CryptoHashes, BIT;

TYPE
	HMac* = OBJECT
		VAR
			size-: LONGINT;		(** mac size in bytes *)
			name-: ARRAY 64 OF CHAR;
			ih, oh: Hashes.Hash;

		PROCEDURE & Init*( CONST hashmod: ARRAY OF CHAR );
		VAR i, l: LONGINT; c: CHAR;
		BEGIN
			ih := Hashes.NewHash( hashmod );
			oh := Hashes.NewHash( hashmod );
			size := ih.size;
			name := "hmac-";  l := 5; i := 0;
			REPEAT  c := ih.name[i];  name[l] := c;  INC( l );  INC( i )  UNTIL c = 0X;
			IF (size < ih.size) & (size = 12) THEN
				name[l - 1] := '-'; name[l] := '9';  name[l+1] := '6'; name[l+2] := 0X
			END;
			SELF.size := size
		END Init;

		(** Set a key, recommended key-length is the hash-size of the underlying hash-function.
			This method has to be invoked for EACH mac to be calculated *)
		PROCEDURE Initialize*( CONST key: ARRAY OF CHAR; keyLen: LONGINT );
		VAR
			buf, buf2: ARRAY 64 OF CHAR;
			i: LONGINT;
		BEGIN
			FOR i := 0 TO keyLen-1 DO  buf[i] := key[i]  END;
			FOR i := keyLen TO 63 DO  buf[i] := 0X  END;

			FOR i := 0 TO 63 DO  buf2[i] := BIT.CXOR( 36X, buf[i] )  END;
			ih.Initialize;
			ih.Update( buf2, 0, 64 );

			FOR i := 0 TO 63 DO  buf2[i] := BIT.CXOR( 5CX, buf[i] )  END;
			oh.Initialize;
			oh.Update( buf2, 0, 64 )
		END Initialize;

		(** set string from which a mac will be calculated. strings can be concatenated by
			invoking Update several times without invoking Initialize *)
		PROCEDURE Update*( CONST data: ARRAY OF CHAR;  pos, len: LONGINT );
		BEGIN
			ih.Update( data, pos, len )
		END Update;

		(** Load the generated mac of size SELF.size into buf, starting at position pos *)
		PROCEDURE GetMac*( VAR buf: ARRAY OF CHAR;  pos: LONGINT );
		VAR
			tmp: ARRAY 64 OF CHAR;
			i: LONGINT;
		BEGIN
			ih.GetHash( tmp, 0 );
			oh.Update( tmp, 0, ih.size );
			oh.GetHash( tmp, 0 );
			FOR i := 0 TO size - 1 DO  buf[pos + i] := tmp[i]  END
		END GetMac;

	END HMac;

END CryptoHMAC.


System.Free CryptoHMAC ~
