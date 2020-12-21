MODULE CryptoAES;   (** AES (Rijndael) de/encryption *)

(*	2002.07.22	g.f.  *)

IMPORT  Ciphers := CryptoCiphers, U := CryptoUtils;

CONST
	MaxRounds = 14;
	ECB = Ciphers.ECB;  CBC = Ciphers.CBC;  CTR = Ciphers.CTR;

	b0 = SET32( 0000000FFH );  b1 = SET32( 00000FF00H );
	b2 = SET32( 000FF0000H );  b3 = SET32( 0FF000000H );

TYPE
	RTable = ARRAY 256 OF SET32;
	RKeys = ARRAY 4*(MaxRounds + 1) OF SET32;

VAR
	e0, e1, e2, e3, e4: RTable;
	d0, d1, d2, d3, d4: RTable;
	rcon: ARRAY 10 OF SET32;   (* for 128-bit blocks, Rijndael never uses more than 10 rcon values *)

TYPE
	Cipher* = OBJECT (Ciphers.Cipher)
			TYPE
				Block = ARRAY 4 OF SET32;
				Ind4 = RECORD a, b, c, d: INTEGER END;
			VAR
				rounds: SIGNED8;
				key, dkey: RKeys;
				iv: Block;

				PROCEDURE InitKey*( CONST src: ARRAY OF CHAR; keybits: SIZE );
				BEGIN
					InitKey^( src, keybits );
					IF keybits = 128 THEN  rounds := Init128( src )
					ELSIF keybits = 192 THEN  rounds := Init192( src )
					ELSE  rounds := Init256( src )
					END;
					InvertKeys
				END InitKey;

				PROCEDURE SetIV*( CONST src: ARRAY OF CHAR; mode: SIGNED8 );
				BEGIN
					SetIV^( src, mode );   (* set mode *)
					U.BufferToBlockBE( src, 0, iv );
				END SetIV;

				PROCEDURE IncIV;
				VAR i, x: INTEGER;
				BEGIN
					i := 4;
					REPEAT
						DEC( i );
						x := INTEGER( iv[i] ) + 1;  iv[i] := SET32( x )
					UNTIL (x # 0) OR (i = 0)
				END IncIV;

				PROCEDURE Encrypt*( VAR buf: ARRAY OF CHAR;  ofs, len: SIZE );
				VAR i, j: SIZE;  x, y: Block;
				BEGIN
					ASSERT( isKeyInitialized );
					ASSERT( len MOD blockSize = 0 );   (* padding must have been added *)
					i := 0;
					WHILE i < len DO
						U.BufferToBlockBE( buf, ofs + i, x );
						CASE mode OF
						| ECB:
							FOR j := 0 TO 3 DO  x[j] := x[j] / key[j]  END;
							RoundE( x );
						| CBC:
							FOR j := 0 TO 3 DO  x[j] := x[j] / key[j] / iv[j]  END;
							RoundE( x );
							iv := x;
						| CTR:
							FOR j := 0 TO 3 DO  y[j] := iv[j] / key[j]  END;
							RoundE( y );
							FOR j := 0 TO 3 DO  x[j] := x[j] / y[j]  END;
							IncIV
						END;
						U.BlockToBufferBE( x, buf, ofs + i );
						INC( i, blockSize )
					END
				END Encrypt;

				PROCEDURE Decrypt*( VAR buf: ARRAY OF CHAR;  ofs, len: SIZE );
				VAR x0, x, y: Block;  i, j: SIZE;
				BEGIN
					ASSERT( isKeyInitialized );
					ASSERT( len MOD blockSize = 0 );   (* padding must have been added *)
					i := 0;
					WHILE i < len DO
						U.BufferToBlockBE( buf, ofs + i, x0 );
						CASE mode OF
						| ECB:
							FOR j := 0 TO 3 DO  x[j] := x0[j] / dkey[j]  END;
							RoundD( x );
						| CBC:
							FOR j := 0 TO 3 DO  x[j] := x0[j] / dkey[j]  END;
							RoundD( x );
							FOR j := 0 TO 3 DO  x[j] := x[j] / iv[j]  END;
							iv := x0;
						| CTR:
							FOR j := 0 TO 3 DO  y[j] := iv[j] / key[j]  END;
							RoundE( y );
							FOR j := 0 TO 3 DO  x[j] := x0[j] / y[j]  END;
							IncIV
						END;
						U.BlockToBufferBE( x, buf, ofs + i );
						INC( i, blockSize )
					END
				END Decrypt;


				PROCEDURE RoundE( VAR b: Block );
				VAR p, r: INTEGER;  t0, t1, t2, t3, s0, s1, s2, s3: Ind4;
				BEGIN
					split( b[0], s0 );  split( b[1], s1 );  split( b[2], s2 );  split( b[3], s3 );
					r := rounds DIV 2;  p := 0;
					LOOP
						split( e0[s0.d]/e1[s1.c]/e2[s2.b]/e3[s3.a]/key[p + 4], t0 );
						split( e0[s1.d]/e1[s2.c]/e2[s3.b]/e3[s0.a]/key[p + 5], t1 );
						split( e0[s2.d]/e1[s3.c]/e2[s0.b]/e3[s1.a]/key[p + 6], t2 );
						split( e0[s3.d]/e1[s0.c]/e2[s1.b]/e3[s2.a]/key[p + 7], t3 );
						INC( p, 8 );  DEC( r );
						IF r = 0 THEN  EXIT  END;
						split( e0[t0.d]/e1[t1.c]/e2[t2.b]/e3[t3.a]/key[p + 0], s0 );
						split( e0[t1.d]/e1[t2.c]/e2[t3.b]/e3[t0.a]/key[p + 1], s1 );
						split( e0[t2.d]/e1[t3.c]/e2[t0.b]/e3[t1.a]/key[p + 2], s2 );
						split( e0[t3.d]/e1[t0.c]/e2[t1.b]/e3[t2.a]/key[p + 3], s3 );
					END;
					b[0] := (e4[t0.d]*b3)/(e4[t1.c]*b2)/(e4[t2.b]*b1)/(e4[t3.a]*b0)/key[p + 0];
					b[1] := (e4[t1.d]*b3)/(e4[t2.c]*b2)/(e4[t3.b]*b1)/(e4[t0.a]*b0)/key[p + 1];
					b[2] := (e4[t2.d]*b3)/(e4[t3.c]*b2)/(e4[t0.b]*b1)/(e4[t1.a]*b0)/key[p + 2];
					b[3] := (e4[t3.d]*b3)/(e4[t0.c]*b2)/(e4[t1.b]*b1)/(e4[t2.a]*b0)/key[p + 3];
				END RoundE;

				PROCEDURE RoundD( VAR b: Block );
				VAR p, r: INTEGER;  t0, t1, t2, t3, s0, s1, s2, s3: Ind4;
				BEGIN
					split( b[0], s0 );  split( b[1], s1 );  split( b[2], s2 );  split( b[3], s3 );
					r := rounds DIV 2;  p := 0;
					LOOP
						split( d0[s0.d]/d1[s3.c]/d2[s2.b]/d3[s1.a]/dkey[p + 4], t0 );
						split( d0[s1.d]/d1[s0.c]/d2[s3.b]/d3[s2.a]/dkey[p + 5], t1 );
						split( d0[s2.d]/d1[s1.c]/d2[s0.b]/d3[s3.a]/dkey[p + 6], t2 );
						split( d0[s3.d]/d1[s2.c]/d2[s1.b]/d3[s0.a]/dkey[p + 7], t3 );
						INC( p, 8 );  DEC( r );
						IF r = 0 THEN  EXIT  END;
						split( d0[t0.d]/d1[t3.c]/d2[t2.b]/d3[t1.a]/dkey[p + 0], s0 );
						split( d0[t1.d]/d1[t0.c]/d2[t3.b]/d3[t2.a]/dkey[p + 1], s1 );
						split( d0[t2.d]/d1[t1.c]/d2[t0.b]/d3[t3.a]/dkey[p + 2], s2 );
						split( d0[t3.d]/d1[t2.c]/d2[t1.b]/d3[t0.a]/dkey[p + 3], s3 );
					END;
					b[0] := (d4[t0.d]*b3)/(d4[t3.c]*b2)/(d4[t2.b]*b1)/(d4[t1.a]*b0)/dkey[p + 0];
					b[1] := (d4[t1.d]*b3)/(d4[t0.c]*b2)/(d4[t3.b]*b1)/(d4[t2.a]*b0)/dkey[p + 1];
					b[2] := (d4[t2.d]*b3)/(d4[t1.c]*b2)/(d4[t0.b]*b1)/(d4[t3.a]*b0)/dkey[p + 2];
					b[3] := (d4[t3.d]*b3)/(d4[t2.c]*b2)/(d4[t1.b]*b1)/(d4[t0.a]*b0)/dkey[p + 3];
				END RoundD;

				PROCEDURE -split( s: SET32;  VAR b: Ind4 );   (* split set into 4 indexes *)
				BEGIN
					b.a := INTEGER( s ) MOD 100H;
					b.b := INTEGER( s ) DIV 100H MOD 100H;
					b.c := INTEGER( s ) DIV 10000H MOD 100H;
					b.d := INTEGER( s ) DIV 1000000H MOD 100H;
				END split;


				PROCEDURE Init128( CONST src: ARRAY OF CHAR ): SIGNED8;
				VAR i, p: INTEGER;  ib: Ind4;
				BEGIN
					FOR i := 0 TO 3 DO  key[i] := U.SetFromBufferBE( src, 4*i )  END;
					p := 0;  i := 0;
					LOOP
						split( key[p + 3], ib );
						key[p + 4] := key[p] / (e4[ib.c]*b3) / (e4[ib.b]*b2) / (e4[ib.a]*b1) / (e4[ib.d]*b0) / rcon[i];
						key[p + 5] := key[p + 1] / key[p + 4];
						key[p + 6] := key[p + 2] / key[p + 5];
						key[p + 7] := key[p + 3] / key[p + 6];
						INC( i );
						IF i = 10 THEN  EXIT   END;
						INC( p, 4 );
					END;
					RETURN 10
				END Init128;

				PROCEDURE Init192( CONST src: ARRAY OF CHAR ): SIGNED8;
				VAR i, p: INTEGER;  ib: Ind4;
				BEGIN
					FOR i := 0 TO 5 DO  key[i] := U.SetFromBufferBE( src, 4*i )  END;
					p := 0;  i := 0;
					LOOP
						split( key[p + 5], ib );
						key[p + 6] := key[p] / (e4[ib.c]*b3) / (e4[ib.b]*b2) / (e4[ib.a]*b1) / (e4[ib.d]*b0) / rcon[i];
						key[p + 7] := key[p + 1] / key[p + 6];
						key[p + 8] := key[p + 2] / key[p + 7];
						key[p + 9] := key[p + 3] / key[p + 8];
						INC( i );
						IF i = 8 THEN  EXIT   END;
						key[p + 10] := key[p + 4] / key[p + 9];
						key[p + 11] := key[p + 5] / key[p + 10];
						INC( p, 6 );
					END;
					RETURN 12
				END Init192;

				PROCEDURE Init256( CONST src: ARRAY OF CHAR ): SIGNED8;
				VAR i, p: INTEGER;  ib: Ind4;
				BEGIN
					FOR i := 0 TO 7 DO  key[i] := U.SetFromBufferBE( src, 4*i )  END;
					p := 0;  i := 0;
					LOOP
						split( key[p + 7], ib );
						key[p + 8] := key[p] / (e4[ib.c]*b3) / (e4[ib.b]*b2) / (e4[ib.a]*b1) / (e4[ib.d]*b0) / rcon[i];
						key[p + 9] := key[p + 1] / key[p + 8];
						key[p + 10] := key[p + 2] / key[p + 9];
						key[p + 11] := key[p + 3] / key[p + 10];
						INC( i );
						IF i = 7 THEN  EXIT   END;
						split( key[p + 11], ib );
						key[p + 12] := key[p + 4] / (e4[ib.d]*b3) / (e4[ib.c]*b2) / (e4[ib.b]*b1) / (e4[ib.a]*b0);
						key[p + 13] := key[p + 5] / key[p + 12];
						key[p + 14] := key[p + 6] / key[p + 13];
						key[p + 15] := key[p + 7] / key[p + 14];
						INC( p, 8 );
					END;
					RETURN 14
				END Init256;


				PROCEDURE InvertKeys;
				VAR i, j, k, p: INTEGER;  t: SET32;  ib: Ind4;

					PROCEDURE ind( s: SET32 ): INTEGER;   (* extract index byte 0 *)
					BEGIN
						RETURN  INTEGER( s ) MOD 100H
					END ind;

				BEGIN
					dkey := key;
					(* invert the order of the round keys: *)
					i := 0;  j := 4*rounds;
					WHILE i < j DO
						FOR k := 0 TO 3 DO  t := dkey[i + k];  dkey[i + k] := dkey[j + k];  dkey[j + k] := t  END;
						INC( i, 4 );  DEC( j, 4 );
					END;
					(* apply the inverse MixColumn transform to all round keys but the first and the last: *)
					FOR i := 1 TO rounds - 1 DO
						p := 4*i;
						split( dkey[p + 0], ib );
						dkey[p + 0] := d0[ind( e4[ib.d] )] / d1[ind( e4[ib.c] )] / d2[ind( e4[ib.b] )] / d3[ind( e4[ib.a] )];
						split( dkey[p + 1], ib );
						dkey[p + 1] := d0[ind( e4[ib.d] )] / d1[ind( e4[ib.c] )] / d2[ind( e4[ib.b] )] / d3[ind( e4[ib.a] )];
						split( dkey[p + 2], ib );
						dkey[p + 2] := d0[ind( e4[ib.d] )] / d1[ind( e4[ib.c] )] / d2[ind( e4[ib.b] )] / d3[ind( e4[ib.a] )];
						split( dkey[p + 3], ib );
						dkey[p + 3] := d0[ind( e4[ib.d] )] / d1[ind( e4[ib.c] )] / d2[ind( e4[ib.b] )] / d3[ind( e4[ib.a] )];
					END;
				END InvertKeys;


				PROCEDURE & Init*;
				BEGIN
					SetNameAndBlocksize( "aes", 16 )
				END Init;

			END Cipher;

	PROCEDURE NewCipher*(): Ciphers.Cipher;
	VAR cipher: Cipher;
	BEGIN
		NEW( cipher );  RETURN cipher
	END NewCipher;

(*-------------------------------------------------------------------------------*)

	PROCEDURE Initialize;
	VAR
		i1, i2, i4, i8, i9, ib, id, ie, v1, v2, v3, t: INTEGER;
		buf: U.InitBuffer;

		PROCEDURE xor( a, b: INTEGER ): INTEGER;
		BEGIN
			RETURN  INTEGER( SET32( a ) / SET32( b ) )
		END xor;

		PROCEDURE f1( x: INTEGER ): INTEGER;
		VAR y: INTEGER;
		BEGIN
			y := 2*x;
			IF y < 256 THEN  RETURN y  ELSE  RETURN xor( y, 11BH )  END
		END f1;

	BEGIN
		NEW( buf, 2048 );
		buf.Add( " 63 7C 77 7B F2 6B 6F C5 30 01 67 2B FE D7 AB 76 " );
		buf.Add( " CA 82 C9 7D FA 59 47 F0 AD D4 A2 AF 9C A4 72 C0 " );
		buf.Add( " B7 FD 93 26 36 3F F7 CC 34 A5 E5 F1 71 D8 31 15 " );
		buf.Add( " 04 C7 23 C3 18 96 05 9A 07 12 80 E2 EB 27 B2 75 " );
		buf.Add( " 09 83 2C 1A 1B 6E 5A A0 52 3B D6 B3 29 E3 2F 84 " );
		buf.Add( " 53 D1 00 ED 20 FC B1 5B 6A CB BE 39 4A 4C 58 CF " );
		buf.Add( " D0 EF AA FB 43 4D 33 85 45 F9 02 7F 50 3C 9F A8 " );
		buf.Add( " 51 A3 40 8F 92 9D 38 F5 BC B6 DA 21 10 FF F3 D2 " );
		buf.Add( " CD 0C 13 EC 5F 97 44 17 C4 A7 7E 3D 64 5D 19 73 " );
		buf.Add( " 60 81 4F DC 22 2A 90 88 46 EE B8 14 DE 5E 0B DB " );
		buf.Add( " E0 32 3A 0A 49 06 24 5C C2 D3 AC 62 91 95 E4 79 " );
		buf.Add( " E7 C8 37 6D 8D D5 4E A9 6C 56 F4 EA 65 7A AE 08 " );
		buf.Add( " BA 78 25 2E 1C A6 B4 C6 E8 DD 74 1F 4B BD 8B 8A " );
		buf.Add( " 70 3E B5 66 48 03 F6 0E 61 35 57 B9 86 C1 1D 9E " );
		buf.Add( " E1 F8 98 11 69 D9 8E 94 9B 1E 87 E9 CE 55 28 DF " );
		buf.Add( " 8C A1 89 0D BF E6 42 68 41 99 2D 0F B0 54 BB 16 " );

		FOR i1 := 0 TO 255 DO
			v1 := buf.GetInt();  v2 := f1( v1 );  v3 := xor( v2, v1 );
			i2 := f1( i1 );  i4 := f1( i2 );  i8 := f1( i4 );  i9 := xor( i8, i1 );
			ib := xor( i9, i2 );  id := xor( i9, i4 );  ie := xor( i8, xor( i4, i2 ) );

			e0[i1] := SET32( ((v2*100H + v1)*100H + v1)*100H + v3 );
			e1[i1] := SET32( ((v3*100H + v2)*100H + v1)*100H + v1 );
			e2[i1] := SET32( ((v1*100H + v3)*100H + v2)*100H + v1 );
			e3[i1] := SET32( ((v1*100H + v1)*100H + v3)*100H + v2 );
			e4[i1] := SET32( ((v1*100H + v1)*100H + v1)*100H + v1 );

			d0[v1] := SET32( ((ie*100H + i9)*100H + id)*100H + ib );
			d1[v1] := SET32( ((ib*100H + ie)*100H + i9)*100H + id );
			d2[v1] := SET32( ((id*100H + ib)*100H + ie)*100H + i9 );
			d3[v1] := SET32( ((i9*100H + id)*100H + ib)*100H + ie );
			d4[v1] := SET32( ((i1*100H + i1)*100H + i1)*100H + i1 );
		END;
		t := 1;
		FOR i1 := 0 TO 9 DO
			rcon[i1] := SET32( ASH( t, 24 ) );
			t := f1( t );
		END;
	END Initialize;


BEGIN
	Initialize;
END CryptoAES.
