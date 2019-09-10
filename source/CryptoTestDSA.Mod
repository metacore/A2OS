MODULE CryptoTestDSA;	(** AUTHOR "G.F."; PURPOSE "DSA Test"; *)

IMPORT
	B := CryptoBigNumbers, DSA := CryptoDSA, Strings, Out := KernelLog;

(*
seed, outp, outq, outg are taken from the updated Appendix 5 to
FIPS PUB 186 and also appear in Appendix 5 to FIPS PIB 186-1
*)

CONST
	seed	= "d5014e4b60ef2ba8b6211b4062ba3224e0427dd3";
	outpa	= "8df2a494492276aa3d25759bb06869cbeac0d83afb8d0cf7cbb8324f0d7882e5";
	outpb	= "d0762fc5b7210eafc2e9adac32ab7aac49693dfbf83724c2ec0736ee31c80291";
	outq	= "c773218c737ec8ee993b4f2ded30f48edace915f";
	outga	= "626d027839ea0a13413163a55b4cb500299d5522956cefcb3bff10f399ce2c2e";
	outgb	= "71cb9de5fa24babf58e5b79521925c9cc42e9f6f464b088cc572af53e6d78802";

	PROCEDURE error( CONST msg: ARRAY OF CHAR );
	BEGIN
		HALT( 99 );
	END error;

	PROCEDURE Hex2Bin( CONST  hex: ARRAY OF CHAR; VAR bin: ARRAY OF CHAR; len: SIGNED16 );
	VAR
		i, j: SIGNED16;
		h, b: SIGNED32;
		c: CHAR;
	BEGIN
		i := 0;  j := 0;
		WHILE i < 2*len DO  (* parse one nibble at a time *)
			c := hex[i];
			IF (c >= '0') & (c <= '9') THEN  h := ORD( c ) - ORD( '0' );
			ELSIF (c >= 'a') & (c <= 'f') THEN  h := ORD( c ) - ORD( 'a' ) + 10;
			ELSIF (c >= 'A') & (c <= 'F') THEN  h := ORD( c ) - ORD( 'A' ) + 10;
			ELSIF c = 0X THEN  error( "hex source too short" );
			ELSE  error( "error in hex string" );
			END;
			IF ODD( i ) THEN
				bin[j] := CHR( b + h );  INC( j );
			ELSE
				b := h*16;
			END;
			INC( i );
		END
	END Hex2Bin;

	PROCEDURE Do*;
	VAR
		buf: ARRAY 1024 OF CHAR;
		p, q, g: B.BigNumber;
		pub, priv: DSA.Key;
		sig: DSA.Signature;
	BEGIN
		buf := outpa;  Strings.Append( buf, outpb );
		B.AssignHex( p, buf, 128 );
		B.AssignHex( q, outq, 40 );
		buf := outga;  Strings.Append( buf, outgb );
		B.AssignHex( g, buf, 128 );

		Out.String( "generating DSA parameters ..." );  Out.Ln;
		Hex2Bin( seed, buf, 20 );
		DSA.MakeKeys( 512, buf, pub, priv );

		Out.String("q = "); B.Print( priv.q );
		IF B.Cmp( priv.q, q ) = 0 THEN  Out.String( "ok" );
		ELSE  Out.String( "wrong value" );
		END;
		Out.Ln;

		Out.String("p = "); B.Print( priv.p );
		IF B.Cmp( priv.p, p ) = 0 THEN  Out.String( "ok" );
		ELSE  Out.String( "wrong value" );
		END;
		Out.Ln;

		Out.String("g = "); B.Print( priv.g );
		IF B.Cmp( priv.g, g ) = 0 THEN  Out.String( "ok" );
		ELSE  Out.String( "wrong value" );
		END;
		Out.Ln; Out.Ln;

		buf := "12345678901234567890";
		sig := priv.Sign( buf, 20 );
		IF pub.Verify( buf, 20, sig ) THEN
			Out.String( "sign : verify  ok" );
		ELSE
			Out.String( "sign : verify  failed" );
		END;
		Out.Ln;
	END Do;

END CryptoTestDSA.


System.Free CryptoTestDSA CryptoDSA CryptoSHA1 ~
CryptoTestDSA.Do ~