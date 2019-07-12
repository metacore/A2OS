(* ETH Oberon, Copyright 2001 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

MODULE CompressCrypt IN Oberon; (** portable *)	(* ejz  *)
	IMPORT Files, Strings, Compress;

	PROCEDURE Decrypt(VAR Rin: Files.Rider; nIn: LONGINT; VAR Rout: Files.Rider; key: ARRAY OF CHAR; VAR res: INTEGER);
		VAR
			i, n: SIZE;
			ch: CHAR;
	BEGIN
		n := Strings.Length(key); i := 0;
		WHILE i < nIn DO
			Files.Read(Rin, ch);
			Files.Write(Rout, CHR( (ORD(ch)+ORD(key[i MOD n])) MOD 256 ) );
			INC(i)
		END;
		res := Compress.Done
	END Decrypt;

	PROCEDURE Encrypt(VAR Rin: Files.Rider; nIn: LONGINT; VAR Rout: Files.Rider; key: ARRAY OF CHAR; VAR res: INTEGER);
		VAR
			i, n: SIZE;
			ch: CHAR;
	BEGIN
		n := Strings.Length(key); i := 0;
		WHILE i < nIn DO
			Files.Read(Rin, ch);
			Files.Write(Rout, CHR( (ORD(ch)-ORD(key[i MOD n])) MOD 256 ) );
			INC(i)
		END;
		res := Compress.Done
	END Encrypt;

	PROCEDURE Install*;
	BEGIN
		Compress.Decrypt := Decrypt;
		Compress.Encrypt := Encrypt
	END Install;

END CompressCrypt.
