MODULE CryptoHMAC;  	(** AUTHOR "G.F."; PURPOSE "RFC 2104 HMAC"; *)

IMPORT Hashes := CryptoHashes, Strings, BIT;

TYPE
	HMac* = OBJECT
		VAR
			size-: SIZE;		(** mac size L in bytes *)
			name-: ARRAY 64 OF CHAR;
			ih, oh: Hashes.Hash;
			L: SIZE;  (* hash blocksize, mac size *)
			n: SIZE; (* processed data bytes *)

		PROCEDURE & Init*( CONST hashmod: ARRAY OF CHAR );
		BEGIN
			ih := Hashes.NewHash( hashmod );
			oh := Hashes.NewHash( hashmod );
			L := ih.size;  size := L;
			n := 0;
			name := "hmac-";  Strings.Append( name, ih.name );
		END Init;
		
		PROCEDURE ShrinkLength*( len: SIZE );
		VAR bits: ARRAY 8 OF CHAR;
		BEGIN
			ASSERT( (len < size) & (n = 0) );
			Strings.IntToStr( 8*len, bits );
			Strings.Append( name, "-" );
			Strings.Append( name, bits );
			size := len
		END ShrinkLength;

		(** Set a key, recommended key-length is the hash-size of the underlying hash-function.
			This method has to be invoked for EACH mac to be calculated *)
		PROCEDURE Initialize*( CONST key: ARRAY OF CHAR; len: SIZE );
		VAR
			usedkey, buf: ARRAY 64 OF CHAR;
			i: SIZE;
		BEGIN
			IF len > 64 THEN
				ih.Initialize;
				ih.Update( key, 0, len );
				ih.GetHash( usedkey, 0 ); 
				i := L;
				WHILE i < 64 DO  usedkey[i] := 0X;  INC( i )  END;
			ELSE
				i := 0;
				WHILE i < len DO  usedkey[i] := key[i];  INC( i )  END;
				WHILE i < 64 DO  usedkey[i] := 0X;  INC( i )  END;
			END;
			oh.Initialize;
			FOR i := 0 TO 63 DO  buf[i] := BIT.CXOR( 5CX, usedkey[i] )  END;
			oh.Update( buf, 0, 64 );
			ih.Initialize;
			FOR i := 0 TO 63 DO  buf[i] := BIT.CXOR( 36X, usedkey[i] )  END;
			ih.Update( buf, 0, 64 )
		END Initialize;

		(** set string from which a mac will be calculated. strings can be concatenated by
			invoking Update several times without invoking Initialize *)
		PROCEDURE Update*( CONST data: ARRAY OF CHAR;  pos, len: SIZE );
		BEGIN
			ih.Update( data, pos, len );  INC( n, len )
		END Update;

		(** Load the generated mac of size L into buf, starting at position pos *)
		PROCEDURE GetMac*( VAR buf: ARRAY OF CHAR;  pos: SIZE );
		VAR
			tmp: ARRAY 64 OF CHAR;
			i: SIZE;
		BEGIN
			ih.GetHash( tmp, 0 );
			oh.Update( tmp, 0, L );
			oh.GetHash( tmp, 0 );
			FOR i := 0 TO size-1 DO  buf[pos + i] := tmp[i]  END
		END GetMac;

	END HMac;

END CryptoHMAC.


System.Free CryptoHMAC ~
