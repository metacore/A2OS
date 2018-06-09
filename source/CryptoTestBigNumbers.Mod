MODULE CryptoTestBigNumbers;	(** AUTHOR "F.N."; PURPOSE "Tests"; *)

(*
Test vectors: (calculated with java.math.BigInteger)

	b1: 0A66791D  C6988168  DE7AB774  19BB7FB0
	b2: C001C627  10270075  142942E1  9A8D8C51
	b3: D053B3E3  782A1DE5  DC5AF4EB  E9946817

Test 1 - addition
	b1 + b2 = CA683F44  D6BF81DD  F2A3FA55  B4490C01

Test 2 - subtraction
	b1 - b2 = -B59B4D09  498E7F0C  35AE8B6D  80D20CA1

Test 3 - multiplication
	b1 * b2 = 07CCED49  A6019FFD 6F318DA3  F0C56B15  0E7EC8CE  70E1F3EA  8B7B1A93  E217A6B0

Test 4 - exponentiation modulo
	b1 ^ b2 mod b3 = CC924C7E  47A5EA96  CD5A5110  03DCCCFA
*)


IMPORT
	BN := CryptoBigNumbers, Out := KernelLog;

	PROCEDURE Test1*;
		VAR
			b1, b2, b3, result: BN.BigNumber;
	BEGIN
		BN.AssignHex( b1, "0a66791dc6988168de7ab77419bb7fb0", 32 );
		BN.AssignHex( b2, "c001c62710270075142942e19a8d8c51", 32 );
		BN.AssignHex( b3, "d053b3e3782a1de5dc5af4ebe9946817", 32 );
		Out.String("b1: ");  BN.Print( b1 );
		Out.String("b2: ");  BN.Print( b2 );
		Out.String("b3: ");  BN.Print( b3 ); Out.Ln;
		result := BN.Add( b1, b2 );
		Out.String("b1 + b2: ");  BN.Print( result );  Out.Ln;
		result := BN.Sub( b1, b2 );
		Out.String("b1 - b2: ");  BN.Print( result );  Out.Ln;
		result := BN.Mul( b1, b2 );
		Out.String("b1 * b2: ");	BN.Print( result );  Out.Ln;
		result := BN.ModExp( b1, b2, b3 );
		Out.String("b1^ b2 mod b3: ");  BN.Print( result );  Out.Ln;
	END Test1;

END CryptoTestBigNumbers.


System.Free CryptoTestBigNumbers CryptoBigNumbers~
CryptoTestBigNumbers.Test1~
