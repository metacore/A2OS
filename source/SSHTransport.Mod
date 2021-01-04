MODULE SSHTransport;  	(* GF	8.7.2002 / 10.12.2020 *)

IMPORT TCP, IP, DNS, Strings, Log := KernelLog,
	Ciphers := CryptoCiphers, B := CryptoBigNumbers, DH := CryptoDiffieHellman, CryptoHashes, CryptoHMAC,
	U := CryptoUtils, G := SSHGlobals, P := SSHPackets, SSHKeys;

CONST
	ClientVersion = "SSH-2.0-A2 SSH-1.8";  SSHport = 22;
	(* KEXAlgorythms	= built from contents of  SSHConfiguration.Text *)
	SHKAlgorythms		= "ssh-rsa,ssh-dss";
	(* Ciphers list			=  built from contents of  SSHConfiguration.Text *)
	(* HMAC list			=  built from contents of  SSHConfiguration.Text *)
	ComprAlgorythms	= "none";
	Languages 			= "";

	CR = 0DX;  NL = 0AX;

	Closed* = 0;  Connected* = 1;  Keyexchange* = 2;  (** Connection states *)


TYPE
	Key = ARRAY 64 OF CHAR;
	ModuleName = ARRAY 32 OF CHAR;
	
	Packet* = P.Packet;	
	
	SSHMac = OBJECT 
	VAR 
		size, keySize: SIZE;
		name: ARRAY 64 OF CHAR;
		key: ARRAY 64 OF CHAR;
		hmac: CryptoHMAC.HMac;
		
		PROCEDURE &NewMac( CONST modName: ARRAY OF CHAR; macLen: SIZE );
		BEGIN
			NEW( hmac, modName );
			keySize := hmac.size;
			IF macLen < hmac.size THEN  hmac.ShrinkLength( macLen ) END;
			COPY( hmac.name, name );
			size := hmac.size
		END NewMac;
		
		PROCEDURE SetKey( CONST macKey: ARRAY OF CHAR );
		VAR i: SIZE;
		BEGIN
			FOR i := 0 TO keySize-1 DO  key[i] := macKey[i]  END;
		END SetKey;
		
		PROCEDURE Initialize( nr: SIZE );
		VAR
			seqno: ARRAY 4 OF CHAR;
		BEGIN
			hmac.Initialize( key, keySize );
			Int2Chars( nr, seqno );
			hmac.Update( seqno, 0, 4 ); 
		END Initialize;
		
		PROCEDURE Update( CONST buf: ARRAY OF CHAR; pos, len: SIZE );
		BEGIN
			hmac.Update( buf, pos, len )
		END Update;
		
		PROCEDURE GetMac( VAR buf: ARRAY OF CHAR; pos: SIZE );
		BEGIN
			hmac.GetMac( buf, pos )
		END GetMac;
		
	END SSHMac;
	
	
	
	SecurityState = RECORD
		incipher, outcipher: Ciphers.Cipher;
		inkeybits, outkeybits: SIGNED32;		(* cipher keybits *)
		inmode, outmode: SIGNED8;				(* cipher modes *)
		inmac, outmac: SSHMac;
	END;
	
	

	Connection* = OBJECT
	VAR
		state-: INTEGER;
		tcp-: TCP.Connection;
		servername: ARRAY 128 OF CHAR;
		cvers, svers: ARRAY 260 OF CHAR;  (* string *)
		session_id-: Key;  session_id_size-: SIZE;
		session_key: Key;  session_key_size: SIZE;
		secret: ARRAY 1024 OF CHAR;	(* common secret, (mpint format) *)
		incount, outcount: SIGNED32;	(* packet counters *)
		incipher, outcipher: Ciphers.Cipher;
		inmac, outmac: SSHMac;
		
		cipherList, hmacList, kexList: ARRAY 1024 OF CHAR;	(* client methods *)
		clientChannelNo: SIGNED32;

		PROCEDURE & Open*( CONST hostname: ARRAY OF CHAR );
		VAR
			res: INTEGER;  adr: IP.Adr;  p: SIZE;
		BEGIN
			state := Closed;
			Log.String( "connecting to " );  Log.String( hostname );  Log.String( " ... " );
			DNS.HostByName( hostname, adr, res );
			IF res = DNS.Ok THEN
				NEW( tcp ); tcp.Open( 0, adr, SSHport, res );
				IF res = TCP.Ok THEN
					state := Connected;
					COPY( hostname, servername );
					Log.String( "connected" );  Log.Ln;
					tcp.KeepAlive( TRUE );
					p := 0;  U.PutString( cvers, p, ClientVersion );
					incipher := Ciphers.NewCipher( "" );
					outcipher := Ciphers.NewCipher( "" );		(* empty ciphers, no encryption *)
					incount := 0; outcount := 0;
					inmac := NIL;  outmac := NIL;
					IF GetServerVersion( ) THEN
						SendClientVersion;
						G.GetCipherList( cipherList );
						G.GetHMacList( hmacList );
						G.GetKexMethods( kexList );
						session_id_size := 0;
						NegotiateAlgorythms;
					END
				ELSE
					Log.Ln;  Log.String( "connection failed" );  Log.Ln;
				END
			ELSE
				Log.Ln;  Log.String( "DNS lookup failed" );  Log.Ln;
			END;
		END Open;


		PROCEDURE GetServerVersion( ): BOOLEAN;
		VAR receivebuf: ARRAY 2048 OF CHAR;  len, p1, p2: SIZE;
		BEGIN
			REPEAT
				len := ReceiveLine( tcp, receivebuf )
			UNTIL Head( receivebuf, "SSH-" );

			IF ~Head( receivebuf, "SSH-1.99" ) & ~Head( receivebuf, "SSH-2.0" ) THEN
				Log.String( "remote host does not support SSH version 2.0" );  Log.Ln;
				tcp.Close( );
				RETURN FALSE
			ELSE
				p1 := 0;  p2 := 0;
				U.PutArray( svers, p1, receivebuf, p2, len );
				RETURN TRUE
			END
		END GetServerVersion;
				

		PROCEDURE SendClientVersion;
		VAR
			len, pos: SIZE; res: INTEGER;
			nl: ARRAY 4 OF CHAR;
		BEGIN
			pos := 0;
			U.GetLength( cvers, pos, len );
			tcp.Send( cvers, 4, len, TRUE, res );
			nl[0] := CR; nl[1] := NL;
			tcp.Send( nl, 0, 2, TRUE, res );
		END SendClientVersion;
	

		(** Send packet p *)
		PROCEDURE SendPacket*( p: Packet );
		VAR
			i, trlen, payload, padsize, cbs: SIZE; res: INTEGER;
			trbuf: ARRAY 8196 OF CHAR;
		BEGIN {EXCLUSIVE}
			IF state = Closed THEN  RETURN  END;
			ASSERT( p.len > 0 );
			cbs := outcipher.blockSize;
			padsize := cbs - (p.len + 5) MOD cbs;
			IF padsize < 4 THEN INC( padsize, cbs ) END;
			payload := 1 + p.len + padsize;
			Int2Chars( payload, trbuf );  trbuf[4] := CHR( padsize );
			trlen := 4 + payload;
			FOR i := 0 TO p.len - 1 DO trbuf[i+5] := p.buf[i]  END;
			U.RandomBytes( trbuf, p.len + 5, padsize  );
			IF outmac # NIL THEN
				outmac.Initialize( outcount );
				outmac.Update( trbuf, 0, trlen );
				outmac.GetMac( trbuf, trlen );
			END;
			outcipher.Encrypt( trbuf, 0, trlen );
			IF outmac # NIL THEN INC( trlen, outmac.size ) END;
			tcp.Send( trbuf, 0, trlen, TRUE, res );
			INC( outcount );
			IF G.debug THEN	 p.Show  END;
		END SendPacket;

				
		(** Receive SSH Packet *)
		PROCEDURE GetPacket*( ): Packet;
		VAR i, l, pos, trlen: SIZE; padsize, cbs: SIGNED32; err, res: INTEGER;
			rmac, cmac: ARRAY 64 OF CHAR;
			trbuf: ARRAY 8196 OF CHAR;
			msg: ARRAY 128 OF CHAR;
			size: SIZE;
			p: Packet;	
		BEGIN
			ASSERT( state > Closed );
			cbs := incipher.blockSize;
			tcp.Receive( trbuf, 0, cbs, cbs, l, res );
			IF res # TCP.Ok THEN 
				Log.String( "### Broken connection, closed by peer" ); Log.Ln;
				state := Closed;
				RETURN  P.emptyPacket
			END;
			incipher.Decrypt( trbuf, 0, cbs );
			pos := 0;
			U.GetLength( trbuf, pos, trlen );
			ASSERT( (4 + trlen) MOD cbs = 0 );
			padsize := ORD( trbuf[4] );  size := trlen - 1 - padsize;
			INC( trlen, 4 );	(* the len bytes itself *)
			tcp.Receive( trbuf, cbs, trlen - cbs, trlen - cbs, l, res );
			incipher.Decrypt( trbuf, cbs, trlen - cbs );	
			IF inmac # NIL THEN
				tcp.Receive( rmac, 0, inmac.size, inmac.size, l, res );
				inmac.Initialize( incount );
				inmac.Update( trbuf, 0, trlen );
				inmac.GetMac( cmac, 0 );
				i := 0;
				WHILE (i < inmac.size) & (rmac[i] = cmac[i]) DO  INC( i )  END;
				IF i < inmac.size THEN
					Log.String( "### received a packet with wrong MAC" ); Log.Ln;
					Disconnect( 1, "wrong mac" );
					RETURN  P.emptyPacket
				END
			END;
			INC( incount );
			p := P.MakeReceivedPacket( trbuf, size );
			IF G.debug THEN  p.Show  END;
			
			IF p.type = P.Ignore THEN  
				RETURN GetPacket( )
			ELSIF p.type = P.Debug THEN  
				p.SetPos( 1 );
				IF p.GetChar( ) = 1X THEN
					p.GetString( msg );
					Log.String( msg ); Log.Ln;
				END;
				RETURN GetPacket( )
			ELSIF (p.type = P.KEXInit) & (state # Keyexchange) THEN
				Log.String( "reexchanging keys:  not yet implemented" ); Log.Ln;
				HALT( 99 );
				(* renegotiate( ssh, package )*)
			ELSE
				IF p.type = P.Disconn THEN
					p.SetPos( 1 );
					err := p.GetInteger( );
					p.GetString( msg );  
					Log.String( "### remote host closed the connection: " );
					Log.String( msg ); Log.Ln;
					state := Closed;
					p := P.emptyPacket
				END;
			END;
			RETURN p
		END GetPacket;	

		PROCEDURE DebugMessage*( msg: ARRAY OF CHAR );
		VAR 
			buf: ARRAY 256 OF CHAR;
			sp: Packet;
		BEGIN
			buf := "A2-SSH: ";  Strings.Append( buf, msg );
			NEW( sp,  P.Debug, 512 );
				sp.AppChar( 1X );			(* TRUE, always display *)
				sp.AppString( buf );			(* message *)
				sp.AppString( "" );			(* language *)
			SendPacket( sp )
		END DebugMessage;


		PROCEDURE Disconnect*( reason: INTEGER;  CONST msg: ARRAY  OF CHAR );
		VAR sp: Packet;
		BEGIN 
			IF state > Closed THEN
				NEW( sp, P.Disconn, 512 );
					sp.AppInteger( reason );
					sp.AppString( msg );
					sp.AppString( "" );	(* language *)
				SendPacket( sp );
				tcp.Close( );  state := Closed;
				Log.String( "connection to " );  Log.String( servername );  Log.String( " closed "); Log.Ln;
			END;
		END Disconnect;

		PROCEDURE GetChannelNo*( ): SIGNED32;
		BEGIN
			INC( clientChannelNo );
			RETURN clientChannelNo
		END GetChannelNo;

		PROCEDURE PacketAvailable*(  ): BOOLEAN;
		BEGIN
			IF state = Closed THEN  RETURN FALSE
			ELSE  RETURN tcp.Available( ) >= 16
			END
		END PacketAvailable;

				
		PROCEDURE NegotiateAlgorythms;
		VAR
			l, n, pos: SIZE;  kex: INTEGER;
			x, m: ARRAY 512 OF CHAR;  lbuf: ARRAY 4 OF CHAR;
			cipher: Ciphers.Cipher; keybits, maclen: SIGNED32;
			modname: ModuleName;
			mode: SIGNED8;
			sp, rp: Packet;
			hash: CryptoHashes.Hash;
			new: SecurityState;
		BEGIN
			state := Keyexchange;
			
			sp := ClientAlgorythms( );
			SendPacket( sp );
			
			rp := GetPacket( );	
			IF rp.type = P.KEXInit THEN	
				rp.SetPos( 17 ); (* skip serever random *)
				FOR n := 1 TO 8 DO
					rp.GetString( x );
					CASE n OF
					|1:
							AlgoMatch( "kex", kexList, x, m );
							IF m = "diffie-hellman-group1-sha1" THEN kex := 1
							ELSIF m = "diffie-hellman-group14-sha1" THEN kex := 2
							ELSIF m = "diffie-hellman-group-exchange-sha1" THEN kex := 3
							ELSIF m = "diffie-hellman-group1-sha256" THEN kex := 4
							ELSIF m = "diffie-hellman-group14-sha256" THEN kex := 5
							ELSIF m = "diffie-hellman-group-exchange-sha256" THEN kex := 6
							ELSE
								Disconnect( 2, "protocol error" );  RETURN
							END;
					|2:
							AlgoMatch( "hostkey", SHKAlgorythms, x, m );
							IF m = "" THEN
								Disconnect( 2, "protocol error" );  RETURN
							END
					|3, 4:
							AlgoMatch( "cipher", cipherList, x, m );
							IF m = "" THEN
								Disconnect( 2, "protocol error" );  RETURN
							END;
							G.GetCipherParams( m, modname, keybits, mode );
							cipher := Ciphers.NewCipher( modname );
							IF n = 3 THEN
								new.outcipher := cipher;  new.outkeybits := keybits; new.outmode := mode
							ELSE
								new.incipher := cipher;  new.inkeybits := keybits; new.inmode := mode
							END;
					|5, 6:
							AlgoMatch( "hmac", hmacList, x, m );
							IF m = "none" THEN
							ELSIF m # "" THEN
								G.GetHMacParams( m, modname, maclen );
							ELSE
								Disconnect( 2, "protocol error" );  RETURN
							END;
							IF n = 5 THEN  
								NEW( new.outmac, modname, maclen );
							ELSE  
								NEW( new.inmac, modname, maclen );
							END;
					|7, 8:
							AlgoMatch( "compr", ComprAlgorythms, x, m );
							IF m # "none" THEN
								Disconnect( 2, "protocol error" );  RETURN
							END
					END;
				END;
			ELSE 
				Disconnect( 2, "protocol error" );  RETURN
			END;
			IF kex < 4 THEN
				hash := CryptoHashes.NewHash( "CryptoSHA1" )
			ELSE
				hash := CryptoHashes.NewHash( "CryptoSHA256" );
				DEC( kex, 3 )
			END;
			hash.Initialize;
			pos := 0;  U.GetLength( cvers, pos, l );  hash.Update( cvers, 0, l + 4 );		(* VC *)
			pos := 0;  U.GetLength( svers, pos, l );  hash.Update( svers, 0, l + 4 );		(* VS *)
			Int2Chars( sp.len, lbuf );
			hash.Update( lbuf, 0, 4 );  hash.Update( sp.buf^, 0, sp.len );	(* IC *)
			Int2Chars( rp.len, lbuf );
			hash.Update( lbuf, 0, 4 );  hash.Update( rp.buf^, 0, rp.len );		(* IS *)

			IF kex = 1 THEN  rp := Group1( hash )
			ELSIF kex = 2 THEN  rp := Group14( hash )
			ELSIF kex = 3 THEN  rp := GroupExchange( hash )
			END;
			IF state # Closed THEN  CheckSHK( rp )  END;
			IF state # Closed THEN
				hash.GetHash( session_key, 0 );  
				session_key_size := hash.size;
				IF session_id_size = 0 THEN
					session_id := session_key;  
					session_id_size := session_key_size
				END;
				ActivateNewKeys( hash, new );
				state := Connected;
			ELSE
				Log.String( "### key exchange failed" ); Log.Ln
			END;
		END NegotiateAlgorythms; 

		PROCEDURE ClientAlgorythms(): Packet;
		VAR 
			rand: ARRAY 16 OF CHAR; i: INTEGER;
			sp: Packet;
		BEGIN
			NEW( sp, P.KEXInit, 2048 );
				U.RandomBytes( rand, 0, 16 );
				FOR i := 0 TO 15 DO  sp.AppChar( rand[i] )  END;	
				sp.AppString( kexList );
				sp.AppString( SHKAlgorythms );
				sp.AppString( cipherList );  sp.AppString( cipherList );
				sp.AppString( hmacList );  sp.AppString( hmacList );
				sp.AppString( ComprAlgorythms );  sp.AppString( ComprAlgorythms );
				sp.AppString( Languages );  sp.AppString( Languages );
				sp.AppChar(  0X );	(* FALSE *)
				sp.AppInteger( 0 );
			RETURN sp
		END ClientAlgorythms;

		PROCEDURE Group1( hash: CryptoHashes.Hash ): Packet;
		VAR
			pos, size: SIZE;
			pub, serverpub, sec: B.BigNumber;  
			dh: DH.DH;  
			sp, rp: Packet;
		BEGIN
			NEW( dh, 0, "dh.ssh.group1" );
			pub := dh.GenPubKey( );

			NEW( sp, P.DHInit, 1024 );
				sp.AppBigNumber( pub );
			SendPacket( sp );
			
			rp := GetPacket( );
			IF rp.type = P.DHReply THEN
				rp.SetPos( 1 );
				rp.GetBlobInfo( pos, size );
				hash.Update( rp.buf^, pos, size );						(* KS *)
				hash.Update( sp.buf^, 1, sp.len - 1 );					(* e *)
				rp.GetBlobInfo( pos, size );
				hash.Update( rp.buf^, pos, size );						(*  f *)
				rp.SetPos( pos );
				serverpub := rp.GetBigNumber( );
				sec := dh.ComputeKey( serverpub );
				pos := 0;  U.PutBigNumber( secret, pos, sec );
				hash.Update( secret, 0, pos );							(* K *)
			ELSE
				Disconnect( 2, "protocol error: 'DH REPLY' package expected" );
			END;
			RETURN rp
		END Group1;

		PROCEDURE Group14( hash: CryptoHashes.Hash ): Packet;
		VAR
			pos, size: SIZE; 
			pub, serverpub, sec: B.BigNumber;  
			dh: DH.DH;  
			sp, rp: Packet;
		BEGIN
			NEW( dh, 0, "dh.ssh.group14" );
			pub := dh.GenPubKey( );

			NEW( sp, P.DHInit, 2048 );  
				sp.AppBigNumber( pub );
			SendPacket( sp );
			
			rp := GetPacket( );
			IF rp.type = P.DHReply THEN
				rp.SetPos( 1 );
				rp.GetBlobInfo( pos, size );
				hash.Update( rp.buf^, pos, size );					(* KS *)
				hash.Update( sp.buf^, 1, sp.len - 1 );				(* e *)
				rp.GetBlobInfo( pos, size );
				hash.Update( rp.buf^, pos, size );					(* f *)
				rp.SetPos( pos );
				serverpub := rp.GetBigNumber( );
				sec := dh.ComputeKey( serverpub );
				pos := 0;  U.PutBigNumber( secret, pos, sec );
				hash.Update( secret, 0, pos );						(* K *)
			ELSE
				Disconnect( 2, "protocol error: 'DH REPLY' package expected" );
			END;
			 RETURN rp
		END Group14;
				

		PROCEDURE GroupExchange( hash: CryptoHashes.Hash ): Packet;
		VAR
			pos, size: SIZE; 
			clientpub, serverpub, sec, prim, gen: B.BigNumber;  
			dh: DH.DH;
			sp1, sp2, rp1, rp2: Packet;
		BEGIN
			NEW( sp1, P.GEXRequest, 64 );
				sp1.AppInteger( 1024 );  
				sp1.AppInteger( 1024 );  
				sp1.AppInteger( 2048 );
			SendPacket( sp1 );
			
			rp1 := GetPacket( );
			IF rp1.type = P.GEXGroup THEN
				rp1.SetPos( 1 );
				prim := rp1.GetBigNumber( );
				gen := rp1.GetBigNumber( );
				NEW( dh, 512, "" );  dh.SetPrime( prim, gen );
				clientpub := dh.GenPubKey( );

				NEW( sp2, P.GEXInit, 1024 );  
					sp2.AppBigNumber( clientpub );
				SendPacket( sp2 );
				
				rp2 := GetPacket( );
				IF rp2.type = P.GEXReply THEN
					rp2.SetPos( 1 );
					rp2.GetBlobInfo( pos, size );
					hash.Update( rp2.buf^, pos, size );					(* KS *)
					hash.Update( sp1.buf^, 1, 12 );					(* min || n || max *)
					hash.Update( rp1.buf^, 1, rp1.len - 1 );			(* p || g *)
					hash.Update( sp2.buf^, 1, sp2.len - 1 );			(* e *)
					rp2.GetBlobInfo( pos, size );						
					hash.Update( rp2.buf^, pos, size );					(* f *)
					rp2.SetPos( pos );
					serverpub := rp2.GetBigNumber( );
					sec := dh.ComputeKey( serverpub );
					pos := 0;  U.PutBigNumber( secret, pos, sec );
					hash.Update( secret, 0, pos );						(* K *)
				ELSE
					Disconnect( 2, "protocol error: 'DH GEX REPLY' package expected" );
				END
			ELSE
				Disconnect( 2, "protocol error: 'DH GEX GROUP' package expected" );
			END;
			RETURN rp2
		END GroupExchange;


		PROCEDURE CheckSHK( p: Packet );
		VAR keyblob, signature: ARRAY 2048 OF CHAR; len: SIZE;
		BEGIN
			(* current position *)
			p.GetArray( signature, len );
			p.SetPos( 1 );
			p.GetArray( keyblob, len );
			IF ~SSHKeys.VerifyHostkey(	keyblob, signature, servername, 
												session_key, session_key_size ) THEN
				Log.String( "### Server host key verification failed" ); Log.Ln;
				Disconnect( 2, "protocol error" );
			END;
		END CheckSHK;
				
	
		PROCEDURE ActivateNewKeys( hash: CryptoHashes.Hash; new: SecurityState );
		VAR key: ARRAY 512 OF CHAR; sp, rp: Packet;
		BEGIN
			NEW( sp, P.NewKeys, 64 );  
			SendPacket( sp );
			
			rp := GetPacket( );
			IF rp.type = P.NewKeys THEN		
				outcipher := new.outcipher;  	
				DeriveKey( 'C', new.outkeybits DIV 8, hash, key );
				outcipher.InitKey( key, new.outkeybits );
				DeriveKey( 'A', outcipher.blockSize, hash, key );
				outcipher.SetIV( key, new.outmode );
				
				incipher := new.incipher;
				DeriveKey( 'D', new.inkeybits DIV 8, hash, key );
				incipher.InitKey( key, new.inkeybits );
				DeriveKey( 'B', incipher.blockSize, hash, key );
				incipher.SetIV( key, new.inmode );
			
				outmac := new.outmac;
				DeriveKey( 'E', outmac.keySize, hash, key );
				outmac.SetKey( key );
				
				inmac := new.inmac;
				DeriveKey( 'F', inmac.keySize, hash, key );
				inmac.SetKey( key );
			ELSE
				Disconnect( 2, "protocol error:  'NEWKEYS' packet expected" )
			END
		END ActivateNewKeys;	


		PROCEDURE DeriveKey( keykind: CHAR;  len: SIZE;  hash: CryptoHashes.Hash; VAR key: ARRAY OF CHAR );
		VAR
			digest: ARRAY 512 OF CHAR;  ch: ARRAY 2 OF CHAR;
			i, have, secret_size: SIZE;
		BEGIN
			i := 0;  U.GetLength( secret, i, secret_size ); INC( secret_size, 4 );
			ch[0] := keykind;  
			
			hash.Initialize;
			hash.Update( secret, 0, secret_size );
			hash.Update( session_key, 0, session_key_size );
			hash.Update( ch, 0, 1 );
			hash.Update( session_id, 0, session_id_size );
			hash.GetHash( digest, 0 );  have :=  hash.size;
			WHILE have < len DO
				hash.Initialize;
				hash.Update( secret, 0, secret_size );
				hash.Update( session_key, 0, session_key_size );
				hash.Update( digest, 0, have );
				hash.GetHash( digest, have );  INC( have,  hash.size );
			END;
			FOR i := 0 TO len - 1 DO key[i] := digest[i] END;
		END DeriveKey;


	END Connection;



	PROCEDURE Int2Chars( v: SIZE;  VAR buf: ARRAY OF CHAR );
	VAR i: SIZE;
	BEGIN
		FOR i := 3 TO 0 BY -1 DO buf[i] := CHR( v MOD 256 );  v := v DIV 256 END;
	END Int2Chars;

	PROCEDURE Head( CONST buf, s: ARRAY OF CHAR ): BOOLEAN;
	VAR i: SIZE;
	BEGIN
		FOR i := 0 TO LEN( s ) - 1 DO
			IF (buf[i] # s[i]) & (s[i] # 0X) THEN  RETURN FALSE  END
		END;
		RETURN TRUE
	END Head;

	PROCEDURE ReceiveLine( tcp: TCP.Connection;  VAR buf: ARRAY OF CHAR ): SIZE;
	VAR i, l: SIZE; res: INTEGER;
	BEGIN
		i := 0;
		REPEAT tcp.Receive( buf, i, 1, 1, l, res );  INC( i );
		UNTIL buf[i - 1] = NL;
		IF buf[i - 2] = CR THEN i := i - 2 ELSE i := i - 1 END;
		buf[i] := 0X;
		RETURN i;
	END ReceiveLine;


	PROCEDURE AlgoMatch( CONST algo, cstr, sstr: ARRAY OF CHAR;  VAR match: ARRAY OF CHAR );
	VAR
		si, ci: SIGNED16;  matched: BOOLEAN;  tmp: ARRAY 64 OF CHAR;

		PROCEDURE nextSuit( CONST buf: ARRAY OF CHAR;  VAR i: SIGNED16;  VAR suit: ARRAY OF CHAR );
		VAR j: SIGNED16;
		BEGIN
			WHILE (i < LEN( buf )) & (buf[i] # 0X) & ((buf[i] = ',') OR (buf[i] = ' ')) DO  INC( i )  END;
			j := 0;
			WHILE (i < LEN( buf )) & (buf[i] # 0X) & ((buf[i] # ',') & (buf[i] # ' ')) DO
				suit[j]  := buf[i];  INC( i );  INC( j )
			END;
			suit[j] := 0X;
		END nextSuit;

	BEGIN  ci := 0;
		REPEAT  nextSuit( cstr, ci, match );  si := 0;
			REPEAT
				nextSuit( sstr, si, tmp );
				matched := (tmp # "") & (tmp = match)
			UNTIL matched OR (tmp = "");
		UNTIL matched OR (match = "");
		IF G.debug OR (match = "") THEN
			Log.String( algo ); Log.String( " server: " ); Log.String( sstr ); Log.Ln;
			Log.String( algo ); Log.String( " client: " ); Log.String( cstr ); Log.Ln;
			Log.String( algo ); Log.String( " match:  " ); Log.String( match ); Log.Ln;
		END;
	END AlgoMatch;

BEGIN
	Log.String( "A2-SSH, version 1.8" );  Log.Ln;
END SSHTransport.
