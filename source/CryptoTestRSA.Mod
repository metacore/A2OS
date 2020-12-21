MODULE CryptoTestRSA;

IMPORT
	RSA := CryptoRSA, B := CryptoBigNumbers, P := CryptoPrimes,
	Files, Log := KernelLog, WMDialogs;


CONST
	Size = 1024;
	PrivateKeyFile = "SSH.RSAKey.priv";
	PublicKeyFile = "SSH.RSAKey.pub";

	PROCEDURE Test1*;
	VAR
		pub, priv: RSA.Key;
		p, q, e, signature: B.BigNumber;
		digest: ARRAY 64 OF CHAR;
	BEGIN
		Log.String( "generating RSA Keys" ); Log.Ln;
		p := P.NewPrime( Size DIV 2, FALSE );
		Log.String("p = "); B.Print( p ); Log.Ln;

		q := P.NewPrime( Size DIV 2, FALSE );
		Log.String("q = "); B.Print( q ); Log.Ln;
		B.AssignInt( e, 3 );

		RSA.MakeKeys( p, q, e, "Test Key", pub, priv );
		digest := "Everyone gets Friday off her panties.";
		signature :=  priv.Sign( digest, 32 );
		IF signature # NIL THEN
			IF pub.Verify( digest, 32, signature ) THEN
				Log.String( "sign : verify  ok" ); Log.Ln;
			ELSE
				Log.String( "sign : verify failed" ); Log.Ln;
			END
		ELSE
			Log.String( "error: wrong passphrase for private key" ); Log.Ln
		END;
	END Test1;

	PROCEDURE TestRSAKeyFiles*;
	CONST
		headline = "enter passphrase for opening your private key";
	VAR
		pub, priv: RSA.Key;
		signature: B.BigNumber;
		pw, digest: ARRAY 64 OF CHAR;
		f: Files.File; r: Files.Reader;
		i, ignore: SIGNED32;
	BEGIN
		f := Files.Old( PrivateKeyFile ); Files.OpenReader( r, f, 0 );
		i := 0;
		REPEAT
			ignore := WMDialogs.QueryPassword( headline, pw );
			r.SetPos( 0 );
			priv := RSA.LoadPrivateKey( r, pw );
			INC( i )
		UNTIL (priv # NIL) OR (i = 3);
		IF priv = NIL THEN
			Log.String( "wrong passphrase" ); Log.Ln;  RETURN
		END;

		f := Files.Old( PublicKeyFile ); Files.OpenReader( r, f, 0 );
		pub := RSA.LoadPublicKey( r );

		digest := "Everyone gets Friday off her panties.";
		signature :=  priv.Sign( digest, 32 );
		IF pub.Verify( digest, 32, signature ) THEN
			Log.String( "sign : verify  ok" ); Log.Ln;
		ELSE
			Log.String( "sign : verify failed" ); Log.Ln;
		END
	END TestRSAKeyFiles;


END CryptoTestRSA.

Compiler.Compile CryptoRSA.Mod CryptoTestRSA.Mod ~

System.Free CryptoTestRSA CryptoRSA CryptoPrimes CryptoBigNumbers~

CryptoTestRSA.Test1 ~

CryptoTestRSA.TestRSAKeyFiles ~
