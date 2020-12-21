MODULE CryptoTestDH;

IMPORT D := CryptoDiffieHellman, B := CryptoBigNumbers, Kernel, Log := KernelLog;




	PROCEDURE Do( CONST nprime: ARRAY OF CHAR );
	VAR t: SIGNED32;
		dh1, dh2: D.DH;
		pub1, pub2: B.BigNumber;
		k1, k2: B.BigNumber;
	BEGIN
		NEW( dh1, 0, nprime );
		pub1 := dh1.GenPubKey( );
		Log.String( "public key 1:" );  Log.Ln;  B.Print( pub1 );  Log.Ln;

		NEW( dh2, 0, nprime );
		pub2 := dh2.GenPubKey( );
		Log.String( "public key 2:" );  Log.Ln;  B.Print( pub2 );  Log.Ln;  Log.Ln;


		k1 := dh1.ComputeKey( pub2 );
		Log.String( "key a:" );  Log.Ln;  B.Print( k1 );  Log.Ln;

		t := Kernel.GetTicks( );
		k2 := dh2.ComputeKey( pub1 );
		t := Kernel.GetTicks( ) - t;
		Log.String( "key b:" );  Log.Ln; B.Print( k2 );   Log.Ln;

		IF (B.Cmp( k1, k2 ) = 0) THEN Log.String( "ok" ) ELSE Log.String( "failed" ) END;
		Log.String( " (" );  Log.Int( t, 1 );  Log.String( " ms)" );  Log.Ln;
	END Do;

	PROCEDURE SSL192*;
	BEGIN
		Do( "dh.ssl.192" )
	END SSL192;

	PROCEDURE SSL512*;
	BEGIN
		Do( "dh.ssl.512"  )
	END SSL512;

	PROCEDURE SSL1024*;
	BEGIN
		Do( "dh.ssl.1024"  )
	END SSL1024;

	PROCEDURE SSH*;
	BEGIN
		Do( "dh.ssh.group1" )
	END SSH;

	PROCEDURE SSL2048*;
	BEGIN
		Do( "dh.2048.MODP.256"  )
	END SSL2048;


END CryptoTestDH.

CryptoTestDH.SSL192
CryptoTestDH.SSL512
CryptoTestDH.SSL1024
CryptoTestDH.SSH
CryptoTestDH.SSL2048


System.Free CryptoTestDH CryptoDiffieHellman  ~
