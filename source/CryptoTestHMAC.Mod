MODULE CryptoTestHMAC;	(** AUTHOR "F.N."; PURPOSE "HMAC Test"; *)

IMPORT
		CryptoHMAC, Utils := CryptoUtils, Log := KernelLog;
	
	
	PROCEDURE Check( CONST a, b: ARRAY OF CHAR; len: SIZE ): BOOLEAN;
	VAR i: SIZE;
	BEGIN
		i := 0;
		WHILE (i < len) & (a[i] = b[i]) DO  INC( i )  END;
		RETURN i = len
	END Check;

	PROCEDURE DoTest( CONST modname, data, key, expDigest: ARRAY OF CHAR; dataLen, keyLen, hashLen: SIGNED32 );
		VAR
			hmac: CryptoHMAC.HMac;
			output: ARRAY 64 OF CHAR;
	BEGIN
		NEW( hmac, modname );
		IF hashLen < hmac.size THEN  hmac.ShrinkLength( hashLen )  END;
		Log.Ln; Log.String( "=========================================" ); Log.Ln;
		Log.String( "HMAC-Test: " ); Log.String( hmac.name ); Log.Ln;
		hmac.Initialize( key, keyLen );
		hmac.Update( data, 0, dataLen );
		hmac.GetMac( output, 0 );
		IF Check( output, expDigest, hashLen ) THEN
			Log.String( "Test Ok" ); Log.Ln
		ELSE
			Log.String( "Test failed" ); Log.Ln; Log.Ln;
			Log.String( "key: " ); Utils.PrintHex( key, 0, keyLen ); Log.Ln;
			Log.String( "data: " ); Utils.PrintHex( data, 0, dataLen ); Log.Ln;
			Log.String( "expected digest: " ); Utils.PrintHex( expDigest, 0, hmac.size ); Log.Ln;
			Log.String( "computed digest: " ); Utils.PrintHex( output, 0, hmac.size ); Log.Ln;	
		END;
		
	END DoTest;

	(* produces two macs from the same data: in one and in two iterations respective *)
	PROCEDURE ConcatenateTest( modname: ARRAY OF CHAR; hashLen: SIZE );
		VAR
			hmac: CryptoHMAC.HMac;
			binData, output, key: ARRAY 20 OF CHAR;
	BEGIN
		NEW( hmac, modname );
		Log.Ln; Log.String( "=========================================" ); Log.Ln;
		Log.String( "HMAC Concatenation-Test. Digest: " ); Log.String( modname ); Log.Ln; Log.Ln;
		key := "abcdefghijklmnop";
		binData := "hey mister music";
		hmac.Initialize( key, 16 );
		hmac.Update( binData, 0, 16 );
		hmac.GetMac( output, 0 );
		Log.String( "digest when Update is invoked once:" ); Utils.PrintHex( output, 0, hmac.size ); Log.Ln;
		hmac.Initialize( key, 16 );
		hmac.Update( binData, 0, 4 );
		hmac.Update( binData, 4, 6 );
		hmac.Update( binData, 10, 6 );
		hmac.GetMac( output, 0 );
		Log.String( "digest when Update is invoked three times:" ); Utils.PrintHex( output, 0, hmac.size ); Log.Ln
	END ConcatenateTest;

	(* test vectors from rfc 2104 *)
	PROCEDURE Test1MD5*;
		VAR key, hexKey, hexDigest, digest: ARRAY 64 OF CHAR;
	BEGIN
		hexKey := "0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b";
		hexDigest := "9294727a3638bb1c13f48ef8158bfc9d";
		Utils.Hex2Bin( hexKey, 0, key, 0, 16 );
		Utils.Hex2Bin( hexDigest, 0, digest, 0, 16 );
		DoTest( "CryptoMD5", "Hi There", key, digest, 8, 16, 16 );
		
		hexDigest := "750c783e6ab0b503eaa86e310a5db738";
		Utils.Hex2Bin( hexDigest, 0, digest, 0, 16 );
		DoTest( "CryptoMD5", "what do ya want for nothing?", "Jefe", digest, 28, 4, 16 );
		DoTest( "CryptoMD5", "what do ya want for nothing?", "Jefe", digest, 28, 4, 12 );
	
	END Test1MD5;

	PROCEDURE Test1SHA1*;
		VAR key, hexKey, hexDigest, digest: ARRAY 64 OF CHAR;
	BEGIN
		hexKey := "0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b";
		hexDigest := "b617318655057264e28bc0b6fb378c8ef146be00";
		Utils.Hex2Bin( hexKey, 0, key, 0, 20 );
		Utils.Hex2Bin( hexDigest, 0, digest, 0, 20 );
		DoTest( "CryptoSHA1", "Hi There", key, digest, 8, 20, 20 );
		DoTest( "CryptoSHA1", "Hi There", key, digest, 8, 20, 12 )
	END Test1SHA1;

	PROCEDURE Fill( VAR a: ARRAY OF CHAR; len: SIZE; val: CHAR );
	VAR i: SIZE;
	BEGIN
		FOR i := 0 TO len-1 DO  a[i] := val  END
	END Fill;
	
	PROCEDURE Test1SHA256*;
		VAR hexKey, key, text, hexDigest, digest: ARRAY 128 OF CHAR;
	BEGIN
		hexDigest := "f7bc83f430538424b13298e6aa6fb143ef4d59a14946175997479dbc2d1a3cd8";
		Utils.Hex2Bin( hexDigest, 0, digest, 0, 32 );
		DoTest( "CryptoSHA256", 
						"The quick brown fox jumps over the lazy dog", 
						"key", digest, 43, 3, 32 );
						
		hexDigest := "82558a389a443c0ea4cc819899f2083a85f0faa3e578f8077a2e3ff46729665b";
		hexKey := "0102030405060708090a0b0c0d0e0f10111213141516171819";
		Fill( text, 50, 0CDX );
		Utils.Hex2Bin( hexDigest, 0, digest, 0, 32 );
		Utils.Hex2Bin( hexKey, 0, key, 0, 25 );
		DoTest( "CryptoSHA256", text, key, digest, 50, 25, 32 );
		DoTest( "CryptoSHA256", text, key, digest, 50, 25, 12 );
	END Test1SHA256;
	

	PROCEDURE MD5ConcatenateTest*;
	BEGIN
		ConcatenateTest( "CryptoMD5", 16 );
	END MD5ConcatenateTest;

END CryptoTestHMAC.


System.Free CryptoTestHMAC CryptoHMAC CryptoMD5 CryptoSHA1 CryptoSHA256~

 CryptoTestHMAC.Test1MD5~
 CryptoTestHMAC.Test1SHA1~
 CryptoTestHMAC.Test1SHA256~
 CryptoTestHMAC.MD5ConcatenateTest~

