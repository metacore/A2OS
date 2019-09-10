MODULE CryptoTestHMAC;	(** AUTHOR "F.N."; PURPOSE "HMAC Test"; *)

IMPORT
		CryptoHMAC, Utils := CryptoUtils, Out := KernelLog;

	PROCEDURE DoTest( modname, data, key, expDigest: ARRAY OF CHAR; dataLen, keyLen: SIGNED32 );
		VAR
			hmac: CryptoHMAC.HMac;
			output: ARRAY 20 OF CHAR;
	BEGIN
		NEW( hmac, modname );
		Out.Ln; Out.String( "*************************" ); Out.Ln;
		Out.String( "HMAC-Test. Digest: " ); Out.String( modname ); Out.Ln; Out.Ln;
		Out.String( "key: " ); Utils.PrintHex( key, 0, keyLen ); Out.Ln;
		Out.String( "data: " ); Out.String( data ); Out.Ln;
		Out.String( "expected digest: " ); Utils.PrintHex( expDigest, 0, hmac.size ); Out.Ln;
		hmac.Initialize( key, keyLen );
		hmac.Update( data, 0, dataLen );
		hmac.GetMac( output, 0 );
		Out.String( "computed digest: " ); Utils.PrintHex( output, 0, hmac.size ); Out.Ln;
	END DoTest;

	(* produces two macs from the same data: in one and in two iterations respective *)
	PROCEDURE ConcatenateTest( modname: ARRAY OF CHAR );
		VAR
			hmac: CryptoHMAC.HMac;
			binData, output, key: ARRAY 20 OF CHAR;
	BEGIN
		NEW( hmac, modname );
		Out.Ln; Out.String( "*************************" ); Out.Ln;
		Out.String( "HMAC Concatenation-Test. Digest: " ); Out.String( modname ); Out.Ln; Out.Ln;
		key := "abcdefghijklmnop";
		binData := "hey mister music";
		hmac.Initialize( key, 16 );
		hmac.Update( binData, 0, 16 );
		hmac.GetMac( output, 0 );
		Out.String( "digest when Update is invoked once:" ); Utils.PrintHex( output, 0, hmac.size ); Out.Ln;
		hmac.Initialize( key, 16 );
		hmac.Update( binData, 0, 4 );
		hmac.Update( binData, 4, 6 );
		hmac.Update( binData, 10, 6 );
		hmac.GetMac( output, 0 );
		Out.String( "digest when Update is invoked three times:" ); Utils.PrintHex( output, 0, hmac.size ); Out.Ln
	END ConcatenateTest;

	(* test vectors from rfc 2104 *)
	PROCEDURE Test1MD5*;
		VAR binKey, hexKey, hexDigest, binDigest: ARRAY 64 OF CHAR;
	BEGIN
		hexKey := "0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b";
		hexDigest := "9294727a3638bb1c13f48ef8158bfc9d";
		Utils.Hex2Bin( hexKey, 0, binKey, 0, 16 );
		Utils.Hex2Bin( hexDigest, 0, binDigest, 0, 16 );
		DoTest( "CryptoMD5", "Hi There", binKey, binDigest, 8, 16 );
	END Test1MD5;

	PROCEDURE Test1SHA1*;
		VAR binKey, hexKey, hexDigest, binDigest: ARRAY 64 OF CHAR;
	BEGIN
		hexKey := "0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b";
		hexDigest := "b617318655057264e28bc0b6fb378c8ef146be00";
		Utils.Hex2Bin( hexKey, 0, binKey, 0, 20 );
		Utils.Hex2Bin( hexDigest, 0, binDigest, 0, 20 );
		DoTest( "CryptoSHA1", "Hi There", binKey, binDigest, 8, 20 );
	END Test1SHA1;

	PROCEDURE Test2*;
		VAR
			binKey, hexKey, hexDigest, binDigest: ARRAY 64 OF CHAR;
			hexData, binData: ARRAY 104 OF CHAR;
	BEGIN
		hexKey := "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
		hexDigest := "125d7342b2ac11cd91a39af48aa17b4f63f175d3";
		hexData := "dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd";
		Utils.Hex2Bin( hexKey, 0, binKey, 0, 20 );
		Utils.Hex2Bin( hexDigest, 0, binDigest, 0, 20 );
		Utils.Hex2Bin( hexData, 0, binData, 0, 50 );
		DoTest( "CryptoSHA1", binData, binKey, binDigest, 50, 20 );
	END Test2;

	PROCEDURE Test3*;
		VAR
			hexDigest, binDigest: ARRAY 64 OF CHAR;
	BEGIN
		hexDigest := "750c783e6ab0b503eaa86e310a5db738";
		Utils.Hex2Bin( hexDigest, 0, binDigest, 0, 16 );
		DoTest( "CryptoMD5", "what do ya want for nothing?", "Jefe", binDigest, 28, 4 );
	END Test3;

	PROCEDURE MD5ConcatenateTest*;
	BEGIN
		ConcatenateTest( "CryptoMD5" );
	END MD5ConcatenateTest;

END CryptoTestHMAC.


System.Free CryptoTestHMAC CryptoHMAC CryptoMD5 AosCryptoSHA~

Aos.Call CryptoTestHMAC.Test1MD5~
Aos.Call CryptoTestHMAC.Test1SHA1~
Aos.Call CryptoTestHMAC.Test2~
Aos.Call CryptoTestHMAC.Test3~
Aos.Call CryptoTestHMAC.MD5ConcatenateTest~

