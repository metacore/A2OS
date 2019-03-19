MODULE CryptoTools; (** AUTHOR ""; PURPOSE ""; *)

IMPORT
	Commands, Files, Streams,
	CryptoHashes, CryptoUtils;

	(** Hash hashname filenames... ~ *)
	PROCEDURE Hash*(context : Commands.Context);
	VAR
		buf, value: ARRAY 1024 OF CHAR;
		file: ARRAY 256 OF CHAR;
		hash: ARRAY 32 OF CHAR;
		len: LONGINT;
		h: CryptoHashes.Hash;
		f: Files.File;
		r: Files.Reader;
	BEGIN
		IF context.arg.GetString(hash) THEN
			h := CryptoHashes.NewHash(hash);
			IF h = NIL THEN
				context.error.String("Error: Unknown hash '");
				context.error.String(hash);
				context.error.String("'.");
				context.error.Ln;
				RETURN
			END;

			LOOP
				h.Initialize;
				IF ~context.arg.GetString(file) THEN EXIT END;
				f := Files.Old(file);
				IF f = NIL THEN
					context.error.String("Error: could not find file '");
					context.error.String(file);
					context.error.String("'.");
					context.error.Ln;
					RETURN
				END;
				Files.OpenReader(r, f, 0);
				IF r = NIL THEN
					context.error.String("Error: could not read file '");
					context.error.String(file);
					context.error.String("'.");
					context.error.Ln;
					RETURN
				END;

				WHILE r.res = Streams.Ok DO
					r.Bytes(buf, 0, LEN(buf), len);
					h.Update(buf, 0, len)
				END;

				h.GetHash(buf, 0);
				CryptoUtils.Bin2Hex(buf, 0, value, 0, h.size);
				context.out.String(file);
				context.out.String(": ");
				context.out.String(value);
				context.out.Ln;
				context.out.Update
			END;
		ELSE
			context.error.String("Error: expected hash name");
			context.error.Ln
		END
	END Hash;


END CryptoTools.
