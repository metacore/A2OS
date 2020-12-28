MODULE SSHAuthorize; 	(* GF	12.12.2001 / 15.12.2020 *)

IMPORT U := CryptoUtils, B := CryptoBigNumbers, RSA := CryptoRSA, 
	SHA1 := CryptoSHA1, G := SSHGlobals,
	P := SSHPackets, SSHTransport, 
	Strings, Log := KernelLog, Files, WMDialogs, Beep;

TYPE
	Connection* = SSHTransport.Connection;
	Packet = P.Packet;

CONST
	Connected = SSHTransport.Connected;


VAR
	privKey, pubKey: RSA.Key;


	PROCEDURE RequestService( VAR ssh: Connection;  CONST service: ARRAY OF CHAR ): BOOLEAN;
	VAR p: Packet; 
	BEGIN
		NEW( p, P.ServiceRequest, 256 );  p.AppString( service );
		ssh.SendPacket( p );
		p := ssh.GetPacket( );
		IF p.type = P.ServiceAccept THEN  
			RETURN TRUE
		ELSE  
			ssh.Disconnect( 11, "" );  RETURN FALSE
		END
	END RequestService;


	PROCEDURE RequestAuthorizeNone( ssh: Connection;  CONST user: ARRAY OF CHAR; VAR allowed: ARRAY OF CHAR ): BOOLEAN;
	VAR p: Packet; 
	BEGIN
		NEW( p, P.UserauthRequest, 256 );
			p.AppString( user );
			p.AppString( "ssh-connection" );
			p.AppString( "none" );
		ssh.SendPacket( p );
		p := ssh.GetPacket( );
		IF p.type = P.UserauthSuccess THEN
			RETURN TRUE;
		ELSE
			p.SetPos( 1 );
			p.GetString( allowed );
			RETURN FALSE
		END
	END RequestAuthorizeNone;


	PROCEDURE RequestPWAuthorizing( ssh: Connection;  CONST user, host: ARRAY OF CHAR );
	VAR p: Packet;  headline, pw: ARRAY 64 OF CHAR;
	BEGIN
		headline := "SSH: Enter Password for ";
		Strings.Append( headline, user );
		Strings.Append( headline, "@" );
		Strings.Append( headline, host );
		Beep.Beep( 1000 );
		IGNORE WMDialogs.QueryPassword( headline, pw );
		
		NEW( p, P.UserauthRequest, 1024 );
			p.AppString( user );
			p.AppString( "ssh-connection" );
			p.AppString( "password" );
			p.AppChar( 0X );
			p.AppString( pw );
		ssh.SendPacket( p )
	END RequestPWAuthorizing;


	PROCEDURE AuthorizePassword( ssh: Connection; CONST host, user: ARRAY OF CHAR ): BOOLEAN;
	VAR
		p: Packet;
		msg: ARRAY 2048 OF CHAR;
	BEGIN
		RequestPWAuthorizing( ssh, user, host );
		LOOP
			p := ssh.GetPacket( );
			CASE p.type OF
			| P.UserauthBanner:
					p.SetPos( 1 );
					p.GetString( msg );
					Log.String( msg ); Log.Ln;
			| P.UserauthSuccess:
					IF G.debug THEN  Log.String( "password authentication succeeded" );  Log.Ln  END;
					RETURN TRUE
			| P.UserauthFailure:
					RETURN FALSE
			ELSE
				Log.String( "SSHAuthorization.AuthorizePasswd: protocol error: got " );  Log.Int( ORD( msg[0] ), 3 );  Log.Ln;
				RETURN FALSE
			END
		END
	END AuthorizePassword;


	PROCEDURE MakePubKeyBlob( VAR buf: ARRAY OF CHAR;  VAR len: SIZE );
	BEGIN
		len := 0;
		U.PutString( buf, len, "ssh-rsa" );
		U.PutBigNumber( buf, len, pubKey.exponent );
		U.PutBigNumber( buf, len, pubKey.modulus );
	END MakePubKeyBlob;

	PROCEDURE MakeSignatureBlob( VAR buf: ARRAY OF CHAR; VAR len: SIZE;  sign: B.BigNumber );
	BEGIN
		len := 0;
		U.PutString( buf, len, "ssh-rsa" );
		U.PutBigNumber( buf, len, sign );
	END MakeSignatureBlob;


	PROCEDURE AuthorizePublicKey( ssh: Connection;  CONST user: ARRAY OF CHAR ): BOOLEAN;
	CONST
		Asn1DerSha1 = "3021300906052B0E03021A05000414";
		HashLen = 20;
		MsgLen = 15 + HashLen;
		EmSize = 256;
		PadLen = EmSize - MsgLen;
	VAR
		sp, rp: Packet;
		pkblob, sigblob, buf: ARRAY 512 OF CHAR; pos, blen, sbsize: SIZE;
		signature: B.BigNumber;
		sha1: SHA1.Hash;
		em: ARRAY EmSize OF CHAR;
		i: SIGNED32;
	BEGIN
		MakePubKeyBlob( pkblob, blen );
		NEW( sha1 );  sha1.Initialize;

		pos := 0;
		U.PutArray( buf, pos, ssh.session_id, 0, ssh.session_id_size );
		U.PutChar( buf, pos, P.UserauthRequest );
		U.PutString( buf, pos, user );
		U.PutString( buf, pos, "ssh-connection" );
		U.PutString( buf, pos, "publickey" );
		U.PutChar( buf, pos, 1X );
		U.PutString( buf, pos, "ssh-rsa" );
		U.PutArray( buf, pos, pkblob, 0, blen );
		sha1.Update( buf, 0, pos );

		(* padding PKCS1 type 1 *)
		em[0] := 0X;  em[1] := 1X;
		FOR i := 2 TO PadLen - 2 DO em[i] := 0FFX  END;
		em[PadLen - 1] := 0X;
		U.Hex2Bin( Asn1DerSha1, 0, em, EmSize - MsgLen, 15 );
		sha1.GetHash( em, EmSize - HashLen );

		signature := privKey.Sign( em, EmSize );
		MakeSignatureBlob( sigblob, sbsize, signature );

		NEW( sp, P.UserauthRequest, 1024 );
			sp.AppString( user );
			sp.AppString( "ssh-connection" );
			sp.AppString( "publickey" );
			sp.AppChar( 1X );  (* true *)
			sp.AppString( "ssh-rsa" );
			sp.AppArray( pkblob, 0, blen );
			sp.AppArray( sigblob, 0, sbsize );
		ssh.SendPacket( sp );
		rp := ssh.GetPacket( );
		IF rp.type # P.UserauthSuccess THEN
			RETURN FALSE
		END;
		IF G.debug THEN  Log.String( "public key authentication succeeded" );  Log.Ln  END;
		RETURN TRUE
	END AuthorizePublicKey;
	
	PROCEDURE GetPublicKey( msg: BOOLEAN ): BOOLEAN;
	VAR f: Files.File; r: Files.Reader; 
	BEGIN
		f := Files.Old( G.PublicKeyFile );
		IF f = NIL THEN
			IF msg THEN
				Log.String( "### public key file '" );  Log.String( G.PublicKeyFile );
				Log.String( "' not found" );  Log.Ln
			END;
			RETURN FALSE
		END;
		Files.OpenReader( r, f, 0 );
		pubKey := RSA.LoadPublicKey( r );
		RETURN TRUE
	END GetPublicKey;
	
	PROCEDURE GetKeys( msg: BOOLEAN ): BOOLEAN;
	CONST
		headline = "enter passphrase for opening your private key";
	VAR
		f: Files.File; r: Files.Reader; i: INTEGER;
		pw: ARRAY 64 OF CHAR;
	BEGIN
		IF privKey = NIL THEN
			f := Files.Old( G.PrivateKeyFile );
			IF f = NIL THEN
				IF msg THEN
					Log.String( "### private key file '" ); Log.String( G.PrivateKeyFile );
					Log.String( "' not found" ); Log.Ln;
				END;
				RETURN FALSE
			ELSE
				IF GetPublicKey( msg ) THEN
					Files.OpenReader( r, f, 0 );  i := 0;
					REPEAT
						Beep.Beep( 1000 );
						IGNORE WMDialogs.QueryPassword( headline, pw );
						r.SetPos( 0 );
						privKey := RSA.LoadPrivateKey( r, pw );
						INC( i )
					UNTIL (privKey # NIL) OR (i = 2);
					IF privKey = NIL THEN
						Log.String( "### error: wrong passphrase" ); Log.Ln;  RETURN FALSE
					END
				ELSE
					RETURN FALSE
				END
			END
		END;
		RETURN TRUE
	END GetKeys;


	(** Open an outhorized SSH connection, returns NIL on failure *)
	PROCEDURE OpenConnection*( CONST host, user: ARRAY OF CHAR ): Connection;
	VAR
		conn: Connection;
		allowed: ARRAY 128 OF CHAR;
		try: INTEGER;
	BEGIN
		try := 0;
		REPEAT
			INC( try );
			NEW( conn, host );
			IF conn.state = Connected THEN
				IF RequestService( conn, "ssh-userauth" ) THEN
					IF RequestAuthorizeNone( conn, user, allowed ) THEN  RETURN conn  END;
					IF Strings.Match( "*publickey*", allowed ) THEN
						IF GetKeys( try = 1 ) THEN
							IF AuthorizePublicKey( conn, user ) THEN  RETURN conn  END;
						END
					END;
					IF Strings.Match( "*password*", allowed ) THEN
						IF AuthorizePassword( conn, host, user ) THEN  RETURN conn  END
					END
				ELSE
					conn.Disconnect( 11, "" );  RETURN NIL
				END
			END;		
		UNTIL try > 2;
		Log.String( "### error: ssh authentication failed" );  Log.Ln;
		conn.Disconnect( 11, "" ); 
		RETURN NIL
	END OpenConnection;
	
END SSHAuthorize.

