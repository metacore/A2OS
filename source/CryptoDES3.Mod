
MODULE CryptoDES3;   (** AUTHOR "G.F."; PUROSE "Triple DES Cipher";	 *)

(*  based on  POLARSSL des.c *)

IMPORT Ciphers := CryptoCiphers, U := CryptoUtils, D := CryptoDES;



TYPE
	Cipher* = OBJECT (Ciphers.Cipher)
			VAR
				ske, skd: ARRAY 96 OF SET32; ski: LONGINT;
				ivx, ivy: SET32;

				PROCEDURE InitKey*( CONST src: ARRAY OF CHAR; keybits: LONGINT );
				VAR X, Y: SET32;  i: LONGINT;
				BEGIN
					ASSERT( keybits = 192 );
					InitKey^( src, 64 );

					X := U.SetFromBufferBE( src, 0 );  Y := U.SetFromBufferBE( src, 4 );
					D.ComputeSubkeys( X, Y, ske, 0 );

					X := U.SetFromBufferBE( src, 8 );  Y := U.SetFromBufferBE( src, 12 );
					D.ComputeSubkeys( X, Y, skd, 32 );

					X := U.SetFromBufferBE( src, 16);  Y := U.SetFromBufferBE( src, 20 );
					D.ComputeSubkeys( X, Y, ske, 64 );

					FOR i := 0 TO 30 BY 2 DO
						skd[i + 0] := ske[94 - i];
						skd[i + 1] := ske[95 - i];

						ske[i + 32] := skd[62 - i];
						ske[i + 33] := skd[63 - i];

						skd[i + 64] := ske[30 - i];
						skd[i + 65] := ske[31 - i]
					END
				END InitKey;

				PROCEDURE SetIV*( CONST src: ARRAY OF CHAR; mode: SHORTINT );
				BEGIN
					SetIV^( src, mode );   (* set mode *)
					ivx := U.SetFromBufferBE( src, 0 );  ivy := U.SetFromBufferBE( src, 4 )
				END SetIV;

				PROCEDURE Encrypt*( VAR buf: ARRAY OF CHAR;  ofs, len: LONGINT );
				VAR i, r: LONGINT;  X, Y: SET32;
				BEGIN
					ASSERT( isKeyInitialized & (mode IN {Ciphers.ECB, Ciphers.CBC}) );
					ASSERT( len MOD blockSize = 0 );   (* padding must have been added *)
					i := 0;
					WHILE i < len DO
						X := U.SetFromBufferBE( buf, ofs + i );  Y := U.SetFromBufferBE( buf, ofs + i + 4 );
						IF mode = Ciphers.CBC THEN  X := X / ivx;  Y := Y / ivy   END;

						D.IP( X, Y );
						ski := 0;
						FOR r := 0 TO 7 DO
							RoundE( Y, X );  RoundE( X, Y );
						END;
						FOR r := 0 TO 7 DO
							RoundE( X, Y );  RoundE( Y, X );
						END;
						FOR r := 0 TO 7 DO
							RoundE( Y, X );  RoundE( X, Y );
						END;
						D.FP( Y, X );

						U.SetToBufferBE( Y, buf, ofs + i );   U.SetToBufferBE( X, buf, ofs + i + 4);
						IF mode = Ciphers.CBC THEN  ivx := Y;  ivy := X  END;
						INC( i, blockSize )
					END
				END Encrypt;

				PROCEDURE Decrypt*( VAR buf: ARRAY OF CHAR;  ofs, len: LONGINT );
				VAR i, r: LONGINT;  X, Y, X0, Y0: SET32;
				BEGIN
					ASSERT( isKeyInitialized );
					ASSERT( len MOD blockSize = 0 );   (* padding must have been added *)
					i := 0;
					WHILE i < len DO
						X := U.SetFromBufferBE( buf, ofs + i );  Y := U.SetFromBufferBE( buf, ofs + i + 4 );
						IF mode = Ciphers.CBC THEN  X0 := X;  Y0 := Y  END;

						D.IP( X, Y );
						ski := 0;
						FOR r := 0 TO 7 DO
							RoundD( Y, X );  RoundD( X, Y );
						END;
						FOR r := 0 TO 7 DO
							RoundD( X, Y );  RoundD( Y, X );
						END;
						FOR r := 0 TO 7 DO
							RoundD( Y, X );  RoundD( X, Y );
						END;
						D.FP( Y, X );

						IF mode = Ciphers.CBC THEN
							Y := Y / ivx;  X := X / ivy  ;
							ivx := X0;  ivy := Y0
						END;
						U.SetToBufferBE( Y, buf, ofs + i );   U.SetToBufferBE( X, buf, ofs + i + 4);
						INC( i, blockSize )
					END
				END Decrypt;


				PROCEDURE RoundE*( VAR x, y: SET32 );
				VAR i: D.Ind4;
				BEGIN
					D.Split( ske[ski] / x, i );  INC( ski );
					y := y / D.sb8[i.a] / D.sb6[i.b] / D.sb4[i.c] / D.sb2[i.d];
					D.Split( ske[ski] / ROT( x, -4 ), i );  INC( ski );
					y := y / D.sb7[i.a] / D.sb5[i.b] / D.sb3[i.c] / D.sb1[i.d]
				END RoundE;

				PROCEDURE RoundD*( VAR x, y: SET32 );
				VAR i: D.Ind4;
				BEGIN
					D.Split( skd[ski] / x, i );  INC( ski );
					y := y / D.sb8[i.a] / D.sb6[i.b] / D.sb4[i.c] / D.sb2[i.d];
					D.Split( skd[ski] / ROT( x, -4 ), i );  INC( ski );
					y := y / D.sb7[i.a] / D.sb5[i.b] / D.sb3[i.c] / D.sb1[i.d]
				END RoundD;

				PROCEDURE & Init*;
				BEGIN
					SetNameAndBlocksize( "3des", 8 );
				END Init;

			END Cipher;



	PROCEDURE NewCipher*( ): Ciphers.Cipher;
	VAR cipher: Cipher;
	BEGIN
		NEW( cipher );  RETURN cipher
	END NewCipher;


END CryptoDES3.

