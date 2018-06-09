
MODULE SSHKeys;  (* g.f.	2002.08.29 *)

(*	2002.10.15	g.f.	RSA hostkeys added*)

IMPORT
	RSA := CryptoRSA, DSA := CryptoDSA, B:= CryptoBigNumbers, U := CryptoUtils, SHA1 := CryptoSHA1,
	MD5 := CryptoMD5, P := CryptoPrimes, G := SSHGlobals,
	Files, Streams, Out := KernelLog, WMDialogs, Strings;

CONST
	Ok = WMDialogs.ResOk;
	Abort = WMDialogs.ResAbort;

TYPE
	BigNumber = B.BigNumber;



	PROCEDURE SSHDSSVerify( dsa: DSA.Key;  sig: DSA.Signature;  CONST hash: ARRAY OF CHAR ): BOOLEAN;
	VAR h: SHA1.Hash;  digest: ARRAY 20 OF CHAR;
	BEGIN
		NEW( h );
		h.Initialize;  h.Update( hash, 0, 20 );  h.GetHash( digest, 0 );
		RETURN dsa.Verify( digest, 20, sig )
	END SSHDSSVerify;

	PROCEDURE SSHRSAVerify( rsa: RSA.Key;  sig: BigNumber;  CONST hash: ARRAY OF CHAR ): BOOLEAN;
	VAR h1: SHA1.Hash;  h2: MD5.Hash;  digest: ARRAY 20 OF CHAR;
	BEGIN
		NEW( h1 );
		h1.Initialize;  h1.Update( hash, 0, 20 );  h1.GetHash( digest, 0 );
		IF rsa.Verify( digest, 20, sig ) THEN   RETURN TRUE
		ELSE
			(* SSH_BUG_RSASIGMD5 in server implementation ? *)
			NEW( h2 );
			h2.Initialize;  h2.Update( hash, 0, 20 );  h2.GetHash( digest, 0 );
			RETURN rsa.Verify( digest, 16, sig )
		END
	END SSHRSAVerify;



	PROCEDURE GetKeyStart( CONST keykind, host: ARRAY OF CHAR ): Files.Reader;
	VAR
		f: Files.File; r: Files.Reader;
		buf1, buf2: ARRAY 512 OF CHAR;
		i: LONGINT;
		names: Strings.StringArray;
	BEGIN
		f := Files.Old( G.HostkeysFile );
		IF f = NIL THEN  RETURN NIL
		ELSE
			Files.OpenReader( r, f, 0 );
			REPEAT
				r.SkipWhitespace; r.String( buf1 );
				r.SkipWhitespace; r.String( buf2 );
				IF buf2 = keykind THEN
					names := Strings.Split( buf1, ',' );
					i := 0;
					REPEAT
						IF names[i]^ = host THEN  RETURN r  END;
						INC( i )
					UNTIL i >= LEN( names^ )
				END;
				r.SkipLn;
			UNTIL r.Available() = 0;
			RETURN NIL
		END;
	END GetKeyStart;


	PROCEDURE WriterAtEnd(): Streams.Writer;
	VAR
		f: Files.File;  w: Files.Writer;  r: Files.Reader; c: CHAR;
	BEGIN
		f := Files.Old( G.HostkeysFile );
		IF f = NIL THEN
			f := Files.New( G.HostkeysFile );  Files.Register( f );
			Files.OpenWriter( w, f, 0 );
			RETURN w
		ELSE
			Files.OpenReader( r, f, f.Length() -1 );
			r.Char( c );
			Files.OpenWriter( w, f, f.Length() );
			IF c >= ' ' THEN  w.Ln  END;
			RETURN w
		END;
	END WriterAtEnd;


	PROCEDURE CompareDSAKeys( CONST host: ARRAY OF CHAR; key: DSA.Key ): BOOLEAN;
	VAR
		r: Streams.Reader;  w: Streams.Writer;
		msg: ARRAY 512 OF CHAR;
		res: WORD;
		knownKey: DSA.Key;
	BEGIN
		r := GetKeyStart( "ssh-dss", host );
		IF r = NIL THEN
			msg := "no suitable dsa hostkey found in ";
			Strings.Append( msg, G.HostkeysFile );
			Strings.AppendChar( msg, 0DX );
			Strings.Append( msg, "will you trust the connection anyway?" );
			res := WMDialogs.Message( 1, "Load Public Server Hostkey", msg, {Ok, Abort} );
			IF res # Ok THEN  RETURN FALSE
			ELSE
				w := WriterAtEnd();
				w.String( host );  w.Char( ' ' );
				DSA.StorePublicKey( w, key );
				w.Update;
				RETURN TRUE
			END
		END;
		knownKey := DSA.LoadPublicKey( r );
		IF B.Cmp( key.y, knownKey.y ) # 0 THEN
			Out.String( "### error: hostkey of remote host has changed" ); Out.Ln;
			RETURN FALSE
		END;
		RETURN TRUE
	END CompareDSAKeys;


	PROCEDURE CompareRSAKeys( CONST host: ARRAY OF CHAR; key: RSA.Key ): BOOLEAN;
	VAR
		r: Streams.Reader;  w: Streams.Writer;
		msg: ARRAY 512 OF CHAR;
		res: WORD;
		knownKey: RSA.Key;
	BEGIN
		r := GetKeyStart( "ssh-rsa", host );
		IF r = NIL THEN
			msg := "no suitable rsa hostkey found in ";
			Strings.Append( msg, G.HostkeysFile );
			Strings.AppendChar( msg, 0DX );
			Strings.Append( msg, "will you trust the connection anyway?" );
			res := WMDialogs.Message( 1, "Load Public Server Hostkey", msg, {Ok, Abort} );
			IF res # Ok THEN  RETURN FALSE
			ELSE
				w := WriterAtEnd();
				w.String( host );  w.Char( ' ' );
				RSA.StorePublicKey( w, key );
				w.Update;
				RETURN TRUE
			END
		END;
		knownKey := RSA.LoadPublicKey( r );
		IF B.Cmp( key.modulus, knownKey.modulus ) # 0 THEN
			Out.String( "### error: hostkey of remote host has changed" ); Out.Ln;
			RETURN FALSE
		END;
		RETURN TRUE
	END CompareRSAKeys;


	PROCEDURE VerifyIdentity*( CONST keyblob, signature, host, hash: ARRAY OF CHAR ): BOOLEAN;
	VAR
		name1, name2: ARRAY 128 OF CHAR; i, j, len: LONGINT;
		dsa: DSA.Key; dsasig: DSA.Signature;
		rsa: RSA.Key; e, n, rsasig: BigNumber;
		p, q, g, pub, r, s: BigNumber;
	BEGIN
		i := 0;  U.GetString( keyblob, i, name1 );
		j := 0;  U.GetString( signature, j, name2 );
		IF name1 # name2 THEN  RETURN FALSE  END;
		IF name1 = "ssh-dss" THEN
			U.GetBigNumber( keyblob, i, p );
			U.GetBigNumber( keyblob, i, q );
			U.GetBigNumber( keyblob, i, g );
			U.GetBigNumber( keyblob, i, pub );
			dsa := DSA.PubKey( p, q, g, pub );
			U.GetLength( signature, j, len );
			IF len # 40 THEN  RETURN FALSE  END;
			B.AssignBin( r, signature, j, 20 ); INC( j, 20 );
			B.AssignBin( s, signature, j, 20 );
			NEW( dsasig, r, s );
			IF SSHDSSVerify( dsa, dsasig, hash ) THEN  RETURN CompareDSAKeys( host, dsa )
			ELSE  RETURN FALSE
			END
		ELSIF name1 = "ssh-rsa" THEN
			U.GetBigNumber( keyblob, i, e );
			U.GetBigNumber( keyblob, i, n );
			rsa := RSA.PubKey( e, n );
			U.GetBigNumber( signature, j, rsasig );
			IF (rsa.name = "unkown") (* from openssh! *) OR SSHRSAVerify( rsa, rsasig, hash ) THEN
				RETURN CompareRSAKeys( host, rsa )
			ELSE  RETURN FALSE
			END
		ELSE
			Out.String( "### error: unsupported public hostkey type: " );  Out.String( name1 ); Out.Ln;
			RETURN FALSE
		END;
	END VerifyIdentity;



	PROCEDURE RSAKeyGen*;
	CONST
		headline1 = "enter passphrase for new rsa key";
		headline2 = "repeat passphrase for new rsa key";
		Size = 2048;

	VAR
		pw1, pw2: ARRAY 32 OF CHAR; ignore, res: LONGINT; ok: BOOLEAN;
		p, q, e: BigNumber;
		priv, pub: RSA.Key;
		f: Files.File; w: Files.Writer;
	BEGIN
		REPEAT
			ignore := WMDialogs.QueryPassword( headline1, pw1 );
			ok := Strings.Length( pw1 ) > 5;
			IF ~ok THEN
				res := WMDialogs.Message( 1, "RSA Keygen", "pease insert a longer key", {Ok, Abort} );
				IF res = Abort THEN  RETURN  END
			END
		UNTIL ok;
		ignore := WMDialogs.QueryPassword( headline2, pw2 );
		IF pw1 # pw2 THEN
			res := WMDialogs.Message( 1, "RSA Keygen", "passphrases don't match", {Ok} );
			RETURN
		END;
		p := P.NewPrime( Size DIV 2, FALSE );
		q := P.NewPrime( Size DIV 2, FALSE );
		B.AssignInt( e, 3 );
		RSA.MakeKeys( p, q, e, "Aos rsa-key", pub, priv );
		f := Files.New( G.PrivateKeyFile );  Files.OpenWriter( w, f, 0 );
		RSA.StorePrivateKey( w, priv, pw1 );
		w.Update;
		Files.Register( f );
		f := Files.New( G.PublicKeyFile );  Files.OpenWriter( w, f, 0 );
		RSA.StorePublicKey( w, pub );
		w.Update;
		Files.Register( f );
	END RSAKeyGen;

BEGIN
END SSHKeys.
.


SSHKeys.RSAKeyGen ~

System.Free SSHKeys ~
