(* ETH Oberon, Copyright 2001 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

MODULE GZip IN Oberon;	(** eos  **)

	(** minimal gzip implementation **)

	IMPORT
		Files, Texts, Oberon, Strings, GZReaders, GZWriters;

	CONST
		BufSize = 16384;
		Ok* = 0;
		FileError* = -1;
		DataError* = -3;

		(** compression levels **)
		DefaultCompression* = GZWriters.DefaultCompression; NoCompression* = GZWriters.NoCompression;
		BestSpeed* = GZWriters.BestSpeed; BestCompression* = GZWriters.BestCompression;

		(** compression strategies **)
		DefaultStrategy* = GZWriters.DefaultStrategy; Filtered* = GZWriters.Filtered; HuffmanOnly* = GZWriters.HuffmanOnly;

	VAR
		W: Texts.Writer;


	(** uncompress (".gz"-) file in to file out **)
	PROCEDURE UnzipFile*(in, out: Files.File; VAR res: INTEGER);
	VAR
		gzr: GZReaders.Reader; r: Files.Rider; buf: ARRAY BufSize OF CHAR; read: SIGNED32;
	BEGIN
		IF (in = NIL) OR (out = NIL) THEN
			res := FileError
		ELSE
			GZReaders.Open(gzr, in);
			IF gzr.res # GZReaders.Ok THEN
				res := FileError
			ELSE
				Files.Set(r, out, 0);
				REPEAT
					GZReaders.ReadBytes(gzr, buf, 0, LEN(buf), read);
					Files.WriteBytes(r, buf, read)
				UNTIL (gzr.res # GZReaders.Ok) OR (read = 0);
				GZReaders.Close(gzr);
				CASE gzr.res OF
				| GZReaders.Ok: Files.Register(out); res := Ok
				| GZReaders.FileError: res := FileError
				| GZReaders.DataError: res := DataError
				ELSE res := gzr.res
				END
			END
		END;
	END UnzipFile;

	(** uncompress list of files, automatically appending ".gz" to filename if not present.
		GZip.Unzip [\o] (^ | {GZFile})
		Options:
		\o: If set, files with the same name are overwritten, otherwise they are renamed to filename.Bak **)
	PROCEDURE Unzip*;
		VAR
			S: Texts.Scanner; T: Texts.Text; beg, end, time: SIGNED32; overwrite, oldfilefound: BOOLEAN;
			suffix, infile, outfile, newname: ARRAY 256 OF CHAR; in, out: Files.File; res: INTEGER; res2: SIGNED16;
	BEGIN
		T := Oberon.Par.text;
		Texts.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos); Texts.Scan(S);
		Texts.WriteString(W, "GZip.Unzip"); Texts.WriteLn(W); Texts.Append(Oberon.Log, W.buf);
		IF (S.class = Texts.Char) & (S.c = Oberon.OptionChar) THEN
			overwrite := (S.nextCh = "o");
			IF ~overwrite THEN
				Texts.WriteString(W, "unknown option "); Texts.Write(W, S.nextCh); Texts.WriteLn(W); Texts.Append(Oberon.Log, W.buf)
			END;
			Texts.Scan(S); Texts.Scan(S)
		END;
		IF (S.class = Texts.Char) & (S.c = "^") THEN
			Oberon.GetSelection(T, beg, end, time);
			IF time # -1 THEN Texts.OpenScanner(S, T, beg); Texts.Scan(S) END;
		ELSE
			end := T.len
		END;
		WHILE (S.class IN {Texts.Name, Texts.String}) & (Texts.Pos(S) <= end + S.len) DO
			Strings.GetSuffix(S.s, suffix);
			IF suffix = "gz" THEN
				COPY(S.s, infile);
				COPY(S.s, outfile); outfile[Strings.Length(outfile)-3] := 0X
			ELSE
				COPY(S.s, infile); Strings.Append(infile, ".gz");
				COPY(S.s, outfile)
			END;
			Texts.WriteString(W, " "); Texts.WriteString(W, infile);
			in := Files.Old(infile);
			IF in = NIL THEN
				Texts.WriteString(W, "-- can't open");
			ELSE
				IF Files.Old(outfile) # NIL THEN
					oldfilefound := TRUE;
					IF ~overwrite THEN
						COPY(outfile, newname); Strings.Append(newname, ".Bak");
						Files.Rename(outfile, newname, res2);
					END
				ELSE
					oldfilefound := FALSE
				END;
				out := Files.New(outfile);
				IF out = NIL THEN
					Texts.WriteString(W, "-- can't open "); Texts.Write(W, 22X); Texts.WriteString(W, outfile); Texts.Write(W, 22X);
					Texts.WriteLn(W); Texts.Append(Oberon.Log, W.buf)
				ELSE
					UnzipFile(in, out, res);
					CASE res OF
					| Ok:
						Texts.WriteString(W, " => "); Texts.WriteString(W, outfile);
						IF oldfilefound & overwrite THEN
							Texts.WriteString(W, "; old file overwritten")
						ELSIF
							oldfilefound & ~overwrite & (res2 = 0) THEN
							Texts.WriteString(W, "; old file renamed into "); Texts.WriteString(W, newname)
						END
					| FileError: Texts.WriteString(W, "-- error in input file")
					| GZReaders.DataError: Texts.WriteString(W, "-- data error")
					ELSE Texts.WriteString(W, "-- error "); Texts.WriteInt(W, res, 0)
					END
				END
			END;
			Texts.WriteLn(W); Texts.Append(Oberon.Log, W.buf);
			Texts.Scan(S)
		END;
	END Unzip;

	(** compress file in into file out **)
	PROCEDURE ZipFile*(in, out: Files.File; level, strategy: SIGNED8; VAR res: INTEGER);
	VAR
		gzw: GZWriters.Writer; r: Files.Rider; buf: ARRAY BufSize OF CHAR; len, written, totWritten: SIGNED32;
	BEGIN
		IF (in = NIL) OR (out = NIL) THEN
				res := FileError
		ELSE
			GZWriters.Open(gzw, level, strategy, out);
			IF gzw.res # GZWriters.Ok THEN
				res := FileError
			ELSE
				len := Files.Length(in);
				totWritten := 0;
				Files.Set(r, in, 0);
				REPEAT
					Files.ReadBytes(r, buf, BufSize);
					GZWriters.WriteBytes(gzw, buf, 0, BufSize - r.res, written);
					INC(totWritten, written)
				UNTIL (gzw.res # GZWriters.Ok) OR (totWritten >= len);
				CASE gzw.res OF
				| GZWriters.Ok: Files.Register(out); res := Ok
				| GZWriters.FileError: res := FileError
				| GZWriters.DataError: res := DataError
				ELSE res := gzw.res
				END;
				GZWriters.Close(gzw);
			END
		END
	END ZipFile;

	(** compress list of files, automatically appending ".gz" to filename if not present
		GZip.Zip [\level [\strategy]] (^ | {File [GZFile]})
		Options:
		\level: specifies the compression level (0: no compression, 9: best compression)
			if not set, default level (-1) is used
		\strategy: specifies the compression strategy (from 0 - 2) **)
	PROCEDURE Zip*;
	VAR
		S: Texts.Scanner; T: Texts.Text; beg, end, time: SIGNED32;
		level, strategy: SIGNED8; res: INTEGER;
		suffix, outfile: ARRAY 256 OF CHAR; in, out: Files.File;
	BEGIN
		T := Oberon.Par.text;
		strategy := DefaultStrategy;
		level := DefaultCompression;
		Texts.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos); Texts.Scan(S);
		Texts.WriteString(W, "GZip.Zip"); Texts.WriteLn(W); Texts.Append(Oberon.Log, W.buf);
		IF (S.class = Texts.Char) & (S.c = '\') THEN	(* read level *)
			Texts.Scan(S);
			IF S.class = Texts.Int THEN
				level := SHORT(SHORT(S.i));
				Texts.Scan(S);
				IF (S.class = Texts.Char) & (S.c = '\') THEN	(* read strategy *)
					Texts.Scan(S);
					IF S.class = Texts.Int THEN
						strategy := SHORT(SHORT(S.i));
						Texts.Scan(S)
					END
				END
			END
		END;
		IF (S.class = Texts.Char) & (S.c = "^") THEN
			Oberon.GetSelection(T, beg, end, time);
			IF time # -1 THEN Texts.OpenScanner(S, T, beg); Texts.Scan(S) END;
		ELSE
			end := T.len
		END;
		WHILE (S.class IN {Texts.Name, Texts.String}) & (Texts.Pos(S) <= end + S.len) DO
			COPY(S.s, outfile);
			Texts.WriteString(W, " "); Texts.WriteString(W, S.s);
			in := Files.Old(S.s);
			Texts.Scan(S);
			IF S.class IN {Texts.Name, Texts.String} THEN
				Strings.GetSuffix(S.s, suffix);
				IF suffix = "gz" THEN
					COPY(S.s, outfile);
					Texts.Scan(S)
				ELSE
					Strings.Append(outfile, ".gz")
				END
			ELSE
				Strings.Append(outfile, ".gz")
			END;
			IF in = NIL THEN
				Texts.WriteString(W, "-- can't open");
			ELSE
				out := Files.New(outfile);
				IF out = NIL THEN
					Texts.WriteString(W, "-- can't open: "); Texts.Write(W, 22X); Texts.WriteString(W, outfile); Texts.Write(W, 22X);
				ELSE
					ZipFile(in, out, level, strategy, res);
					IF res  # Ok THEN
						CASE res OF
						| FileError: Texts.WriteString(W, " -- error in input file")
						| DataError: Texts.WriteString(W, " -- data error")
						ELSE Texts.WriteString(W, "--error"); Texts.WriteInt(W, res, 0)
						END;
					ELSE
						Texts.WriteString(W, " => "); Texts.WriteString(W, outfile); Texts.WriteLn(W);
						Texts.WriteString(W, " original size: "); Texts.WriteInt(W, Files.Length(in), 1);
						Texts.WriteString(W, ", compressed size: "); Texts.WriteInt(W, Files.Length(out), 1);
						Texts.WriteString(W, ", compression degree: ");
						Texts.WriteInt(W, ENTIER(((1 - Files.Length(out) / Files.Length(in)) * 100) + 0.5), 1); Texts.WriteString(W, "%");
					END
				END
			END;
			Texts.WriteLn(W); Texts.Append(Oberon.Log, W.buf)
		END;
	END Zip;


BEGIN
	Texts.OpenWriter(W)
END GZip.