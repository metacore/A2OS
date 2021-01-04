MODULE CryptoSHA256;	(** AUTHOR "G.F."; PURPOSE "SHA-256"; *)

IMPORT
	Hashes := CryptoHashes, U := CryptoUtils;

CONST
	BlockSize = 64;

VAR
	K256: ARRAY 64 OF SIGNED32;


TYPE
	Hash* = OBJECT (Hashes.Hash)
	VAR
		hash: ARRAY 8 OF SIGNED32;		(* state *)
		bitlen: SIGNED64;
		cdata: ARRAY BlockSize OF CHAR;	(* pending data *)
		cn: SIGNED32;	(* number of chars in cdata *)

		PROCEDURE &Init*;
		BEGIN
			SetNameAndSize( "sha2-256", 32 );
			initialized := FALSE
		END Init;

		PROCEDURE Initialize*;
		BEGIN
			hash[0] := SIGNED32( 6A09E667H );		hash[1] := SIGNED32( 0BB67AE85H );
			hash[2] := SIGNED32( 3C6EF372H );	hash[3] := SIGNED32( 0A54FF53AH );
			hash[4] := SIGNED32( 510E527FH );		hash[5] := SIGNED32( 09B05688CH );
			hash[6] := SIGNED32( 1F83D9ABH);		hash[7] := SIGNED32( 05BE0CD19H );
			bitlen := 0;
			cn := 0;
			initialized := TRUE
		END Initialize;

		PROCEDURE HashBlock;
		VAR 
			a, b, c, d, e, f, g, h, s0, s1, s, T1, T2, i: SIGNED32;
			X: ARRAY 16 OF SIGNED32;
		BEGIN
			a := hash[0];  b := hash[1];  c := hash[2];  d := hash[3];
			e := hash[4];  f := hash[5];  g := hash[6];  h := hash[7];

			FOR i := 0 TO 63 DO
				IF i < 16 THEN
					X[i] := U.IntFromBufferBE( cdata, 4*i )
				ELSE
					s0 := sigma0( SET32(X[(i+1) MOD 16]) );
					s1 := sigma1( SET32(X[(i+14) MOD 16]) );
					s := s0 + s1 + X[(i+9) MOD 16];
					INC( X[i MOD 16], s );
				END;
				T1 := X[i MOD 16] + h + Sigma1Ch( SET32(e), SET32(f), SET32(g) ) + K256[i];
				T2 := Sigma0Maj( SET32(a), SET32(b), SET32(c) );
				h := g;  g := f;  f := e;  e := d + T1;
				d := c;  c := b;  b := a;  a := T1 + T2;
			END;

			INC( hash[0], a );  INC( hash[1],  b );  INC( hash[2],  c );  INC( hash[3],  d );
			INC( hash[4], e );  INC( hash[5],  f );  INC( hash[6],  g );  INC( hash[7],  h );
		END HashBlock;


		(** data: value to be hashed *)
		PROCEDURE Update*( CONST data: ARRAY OF CHAR;  pos, len: SIZE );
		BEGIN
			ASSERT( initialized );
			INC( bitlen, len*8 );
			
			WHILE len > 0 DO
				cdata[cn] := data[pos];  INC( cn );  INC( pos );  DEC( len );
				IF cn = 64 THEN  
					HashBlock;  cn := 0
				END
			END;
		END Update;

		(** get the hashvalue of length SELF.size *)
		PROCEDURE GetHash*( VAR buf: ARRAY OF CHAR;  pos: SIZE );
			VAR p, i: SIGNED32;
		BEGIN
			cdata[cn] := 80X;  INC( cn );
			IF cn > BlockSize - 8 THEN
				WHILE cn < BlockSize  DO  cdata[cn] := 0X;  INC( cn )  END;
				HashBlock;
			END;
			p := BlockSize - 8;
			WHILE cn < p  DO  cdata[cn] := 0X;  INC( cn )  END;
			U.IntToBufferBE( SIGNED32( LSH( bitlen, -32 ) ), cdata, p );  
			U.IntToBufferBE( SIGNED32( bitlen ), cdata, p + 4 );
			HashBlock;

			FOR i := 0 TO 7 DO  U.IntToBufferBE( hash[i], buf, pos );  INC( pos, 4 )  END;
		END GetHash;

	END Hash;



	(* PROCEDURES *******************************************************************************)

	(** get an instance of SHA256 *)
	PROCEDURE NewHash*( ) : Hashes.Hash;
		VAR h: Hash;
	BEGIN
		NEW( h );  RETURN h
	END NewHash;



	PROCEDURE -Sigma0Maj( x, y, z: SET32 ): SIGNED32;
	VAR a, b: SET32;
	BEGIN
		a := ROT( x, 30 ) / ROT( x, 19 ) / ROT( x, 10 );
		b := (x*y) / (x*z) / (y*z);
		RETURN SIGNED32( a ) + SIGNED32( b )
	END Sigma0Maj;

	PROCEDURE -Sigma1Ch( x, y, z: SET32 ): SIGNED32;
	VAR a, b: SET32;
	BEGIN
		a := ROT( x, 26 ) / ROT( x, 21 ) / ROT( x, 7 );
		b := (x*y) / ((-x)*z);
		RETURN SIGNED32( a ) + SIGNED32( b )
	END Sigma1Ch;

	PROCEDURE -sigma0( x: SET32 ): SIGNED32;
	BEGIN
		RETURN SIGNED32( ROT( x , 25 ) / ROT( x, 14 ) / LSH( x, -3 ) )
	END sigma0;

	PROCEDURE -sigma1( x: SET32 ): SIGNED32;
	BEGIN
		RETURN SIGNED32( ROT( x , 15 ) / ROT( x, 13 ) / LSH( x, -10 ) )
	END sigma1;


	PROCEDURE InitializeK;
	VAR
		buf: U.InitBuffer; i: SIGNED32;
	BEGIN
		NEW( buf, 2048 );
		buf.Add( "428A2F98 71374491 B5C0FBCF E9B5DBA5  " );
		buf.Add( "3956C25B 59F111F1 923F82A4 AB1C5ED5  " );
		buf.Add( "D807AA98 12835B01 243185BE 550C7DC3  " );
		buf.Add( "72BE5D74 80DEB1FE 9BDC06A7 C19BF174  " );
		buf.Add( "E49B69C1 EFBE4786 0FC19DC6 240CA1CC  " );
		buf.Add( "2DE92C6F 4A7484AA 5CB0A9DC 76F988DA  " );
		buf.Add( "983E5152 A831C66D B00327C8 BF597FC7  " );
		buf.Add( "C6E00BF3 D5A79147 06CA6351 14292967  " );
		buf.Add( "27B70A85 2E1B2138 4D2C6DFC 53380D13  " );
		buf.Add( "650A7354 766A0ABB 81C2C92E 92722C85  " );
		buf.Add( "A2BFE8A1 A81A664B C24B8B70 C76C51A3  " );
		buf.Add( "D192E819 D6990624 F40E3585 106AA070  " );
		buf.Add( "19A4C116 1E376C08 2748774C 34B0BCB5  " );
		buf.Add( "391C0CB3 4ED8AA4A 5B9CCA4F 682E6FF3  " );
		buf.Add( "748F82EE 78A5636F 84C87814 8CC70208  " );
		buf.Add( "90BEFFFA A4506CEB BEF9A3F7 C67178F2  " );
		FOR i := 0 TO 63 DO K256[i] := buf.GetInt()  END;
	END InitializeK;

BEGIN
	InitializeK
END CryptoSHA256.
