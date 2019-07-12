MODULE Unzip; (** AUTHOR "ejz"; PURPOSE "Aos unzip program"; *)
	IMPORT Streams, Inflate, CRC, Files, Dates, Strings, Commands;

	CONST
		EndOfCentralDirSig = 006054B50H;
		CentralFileHeadSig = 002014B50H;
		LocalFileHeadSig = 004034B50H;

	TYPE
		Entry* = POINTER TO RECORD
			method, pos: LONGINT;
			crc*, csize*, size*: LONGINT;
			td*: Dates.DateTime;
			name*: Strings.String;
			next: Entry
		END;

		SizeReader = OBJECT
			VAR input: Streams.Reader; max: LONGINT;

			PROCEDURE Receive(VAR buf: ARRAY OF CHAR; ofs, size, min: LONGINT; VAR len: LONGINT; VAR res: WORD);
			BEGIN
				IF min > max THEN min := max END;
				input.Bytes(buf, ofs, min, len);
				DEC(max, len); res := input.res;
				IF (max = 0) & (res = Streams.Ok) THEN
					res := Streams.EOF
				END
			END Receive;

			PROCEDURE &Init*(input: Streams.Reader; size: LONGINT);
			BEGIN
				SELF.input := input; SELF.max := size
			END Init;

		END SizeReader;

		ZipFile* = OBJECT
			VAR
				F: Files.File;
				root: Entry; entries: LONGINT;

			PROCEDURE FindEntry*(CONST name: ARRAY OF CHAR): Entry;
				VAR e: Entry; i: LONGINT;
			BEGIN
				e := root; i := 0;
				WHILE (e # NIL) & (e.name^ # name) DO
					e := e.next
				END;
				RETURN e
			END FindEntry;

			PROCEDURE GetFirst*(): Entry;
			BEGIN
				RETURN root
			END GetFirst;

			PROCEDURE GetNext*(e: Entry): Entry;
			BEGIN
				RETURN e.next
			END GetNext;

			PROCEDURE NoOfEntries*(): LONGINT;
			BEGIN
				RETURN entries
			END NoOfEntries;

			PROCEDURE OpenReceiver*(VAR R: Streams.Receiver; entry: Entry; VAR res: WORD);
				VAR fR: Files.Reader; sig: LONGINT; e: Entry; I: Inflate.Reader; S: SizeReader;
			BEGIN
				R := NIL; res := Streams.FormatError;
				Files.OpenReader(fR, F, entry.pos); fR.RawLInt(sig);
				IF sig # LocalFileHeadSig THEN RETURN END;
				NEW(e); ReadEntry(fR, e, TRUE);
				IF e.crc = entry.crc THEN
					IF e.method = 8 THEN (* Deflate *)
						NEW(I, fR); R := I.Receive; res := Streams.Ok
					ELSIF (e.method = 0) & (e.size = e.csize) THEN (* Stored *)
						NEW(S, fR, e.size); R := S.Receive; res := Streams.Ok
					END
				END
			END OpenReceiver;

			PROCEDURE Extract*(entry: Entry; dest: Streams.Writer; VAR res: WORD);
				VAR receiver : Streams.Receiver; R: Streams.Reader; buf: ARRAY 1024 OF CHAR; l: LONGINT; crc: CRC.CRC32Stream;
			BEGIN
				OpenReceiver(receiver, entry, res);
				NEW(R, receiver, 1024);
				IF res # Streams.Ok THEN RETURN END;
				NEW(crc);
				R.Bytes(buf, 0, 1024, l);
				WHILE l > 0 DO
					dest.Bytes(buf, 0, l); crc.Bytes(buf, 0, l);
					R.Bytes(buf, 0, 1024, l)
				END;
				crc.Update();
				IF R.res = Streams.EOF THEN
					IF entry.crc = crc.GetCRC() THEN
						res := Streams.Ok
					END
				ELSE
					res := R.res
				END
			END Extract;

			PROCEDURE &New*(F: Files.File; VAR res: WORD);
				VAR R: Files.Reader; r, e: Entry; pos, sig, l, j: LONGINT; i: INTEGER;
			BEGIN
				res := Streams.Ok; SELF.F := NIL; root := NIL; entries := 0;
				pos := F.Length()-20; sig := 0;
				WHILE (sig # EndOfCentralDirSig) & (pos > 0) DO
					DEC(pos);
					Files.OpenReader(R, F, pos);
					R.RawLInt(sig)
				END;
				IF sig # EndOfCentralDirSig THEN res := Streams.FormatError; RETURN END;
				R.RawInt(i); R.RawInt(i);
				R.RawInt(i); entries := i;
				R.RawInt(i); R.RawLInt(l);
				R.RawLInt(pos);
				IF R.res # Streams.Ok THEN res := R.res END;
				IF (pos < 0) OR (pos >= F.Length()) THEN res := Streams.FormatError; RETURN END;
				Files.OpenReader(R, F, pos);
				NEW(r); r.next := NIL; e := r;
				j := 0;
				WHILE j < entries DO
					NEW(e.next); e := e.next; e.next := NIL;
					R.RawLInt(sig);
					IF sig = CentralFileHeadSig THEN
						ReadEntry(R, e, FALSE)
					ELSE
						res := Streams.FormatError; RETURN
					END;
					INC(j)
				END;
				R.RawLInt(sig);
				IF sig # EndOfCentralDirSig THEN res := Streams.FormatError; RETURN END;
				IF res = Streams.Ok THEN
					SELF.F := F; root := r.next
				ELSE
					SELF.F := NIL; root := NIL; entries := 0
				END
			END New;

		END ZipFile;

	PROCEDURE DosToOberonTime(t: LONGINT): LONGINT;
	BEGIN
		RETURN t DIV 800H MOD 20H * 1000H + t DIV 20H MOD 40H * 40H + t MOD 20H * 2
	END DosToOberonTime;

	PROCEDURE DosToOberonDate(d: LONGINT): LONGINT;
	BEGIN
		RETURN (d DIV 200H MOD 80H + 1980 - 1900) * 200H + d MOD 200H
	END DosToOberonDate;

	PROCEDURE ReadEntry(R: Streams.Reader; entry: Entry; local: BOOLEAN);
		VAR l, nl, xl, t, d: LONGINT; i: INTEGER;
	BEGIN
		IF local THEN
			R.RawInt(i);
			R.RawInt(i); R.RawInt(i); entry.method := i;
			R.RawInt(i); t := DosToOberonTime(i);
			R.RawInt(i); d := DosToOberonDate(i);
			entry.td := Dates.OberonToDateTime(d, t);
			R.RawLInt(entry.crc);
			R.RawLInt(entry.csize);
			R.RawLInt(entry.size);
			R.RawInt(i); nl := i;
			R.RawInt(i); xl := i;
			NEW(entry.name, nl+1);
			l := 0;
			WHILE l < nl DO
				R.Char(entry.name[l]); INC(l)
			END;
			entry.name[l] := 0X;
			R.SkipBytes(xl)
		ELSE
			R.RawInt(i); R.RawInt(i);
			R.RawInt(i); R.RawInt(i); entry.method := i;
			R.RawInt(i); t := DosToOberonTime(i);
			R.RawInt(i); d := DosToOberonDate(i);
			entry.td := Dates.OberonToDateTime(d, t);
			R.RawLInt(entry.crc);
			R.RawLInt(entry.csize);
			R.RawLInt(entry.size);
			R.RawInt(i); nl := i;
			R.RawInt(i); xl := i;
			R.RawInt(i); xl := xl + i;
			R.RawInt(i); R.RawInt(i);
			R.RawLInt(l); R.RawLInt(entry.pos);
			NEW(entry.name, nl+1);
			l := 0;
			WHILE l < nl DO
				R.Char(entry.name[l]); INC(l)
			END;
			entry.name[l] := 0X;
			R.SkipBytes(xl)
		END
	END ReadEntry;

	PROCEDURE StripPrefix(CONST long: ARRAY OF CHAR; VAR short: ARRAY OF CHAR);
		VAR i, j: LONGINT; ch: CHAR;
	BEGIN
		i := 0; j := 0; ch := long[0];
		WHILE ch # 0X DO
			IF (ch = "/") OR (ch = "\") THEN
				j := 0
			ELSE
				short[j] := ch; INC(j)
			END;
			INC(i); ch := long[i]
		END;
		short[j] := 0X
	END StripPrefix;

	PROCEDURE ExtractEntry(w: Streams.Writer; zip: ZipFile; entry: Entry; name: ARRAY OF CHAR; backup, path: BOOLEAN);
		VAR F: Files.File; W: Files.Writer; res: WORD; bak: Files.FileName;
	BEGIN
		IF ~path THEN StripPrefix(name, name) END;
		w.String(name);
		F := Files.New(name);
		IF F = NIL THEN
			w.String(" failed"); w.Ln(); RETURN
		END;
		Files.OpenWriter(W, F, 0);
		zip.Extract(entry, W, res);
		IF res = Streams.Ok THEN
			IF backup THEN
				COPY(name, bak); Strings.Append(bak, ".Bak");
				Files.Rename(name, bak, res);
				(* ASSERT(res = 0) what if it did not exist before ? *)
				IF (res # 0) & (res # 2) THEN w.String("Backup failed on "); w.String(name); w.Ln END
			END;
			W.Update(); Files.Register(F)
		ELSE
			w.String(" failed")
		END;
		w.Ln()
	END ExtractEntry;

	(* Extract [ \o ] [ \d ] [ \p prefix ] zip { entry } ~ *)
	PROCEDURE Extract*(context : Commands.Context);
	VAR
		F: Files.File; zip: ZipFile; name, fs: Files.FileName; res: WORD;
		e: Entry; opt: ARRAY 32 OF CHAR; ch: CHAR; backup, path, prefix: BOOLEAN;
	BEGIN
		context.arg.SkipWhitespace();
		backup := TRUE; prefix := FALSE; path := FALSE;
		WHILE context.arg.Peek() = "\" DO
			context.arg.Char(ch); context.arg.SkipWhitespace(); context.arg.String(opt);
			IF opt = "o" THEN
				backup := FALSE
			ELSIF opt = "d" THEN
				path := TRUE
			ELSIF opt = "p" THEN
				prefix := TRUE;
				context.arg.SkipWhitespace(); context.arg.String(fs)
			ELSE
				context.error.String("unknown option "); context.error.String(opt); context.error.Ln();
				RETURN
			END;
			context.arg.SkipWhitespace()
		END;
		context.arg.String(name); context.arg.SkipWhitespace();
		IF name = "" THEN RETURN END;
		F := Files.Old(name);
		IF F = NIL THEN RETURN END;
		NEW(zip, F, res);
		IF res = Streams.Ok THEN
			context.arg.String(name);
			WHILE name # "" DO
				e := zip.FindEntry(name);
				IF e # NIL THEN
					IF prefix THEN
						COPY(fs, name); Strings.Append(name, e.name^)
					END;
					ExtractEntry(context.out, zip, e, name, backup, path)
				ELSE
					context.error.String(name); context.error.String(" not found"); context.error.Ln()
				END;
				context.arg.SkipWhitespace(); context.arg.String(name)
			END;
		ELSE
			context.error.String(name); context.error.String(" is not a valid zip file"); context.error.Ln()
		END;
	END Extract;

	(* ExtractAll [ \o ] [ \d ] [ \p prefix ] zip ~ *)
	PROCEDURE ExtractAll*(context : Commands.Context);
	VAR
		F: Files.File; zip: ZipFile; name, fs: Files.FileName; res: WORD;
		e: Entry; opt: ARRAY 32 OF CHAR; ch: CHAR; backup, path, prefix: BOOLEAN;
	BEGIN
		context.arg.SkipWhitespace();
		backup := TRUE; prefix := FALSE; path := FALSE;
		WHILE context.arg.Peek() = "\" DO
			context.arg.Char(ch); context.arg.SkipWhitespace(); context.arg.String(opt);
			IF opt = "o" THEN
				backup := FALSE
			ELSIF opt = "d" THEN
				path := TRUE
			ELSIF opt = "p" THEN
				prefix := TRUE;
				context.arg.SkipWhitespace(); context.arg.String(fs)
			ELSE
				context.error.String("unknown option "); context.error.String(opt); context.error.Ln();
				RETURN
			END;
			context.arg.SkipWhitespace()
		END;
		context.arg.String(name);
		WHILE name # "" DO
			F := Files.Old(name);
			IF F # NIL THEN
				NEW(zip, F, res);
				IF res = Streams.Ok THEN
					e := zip.GetFirst();
					WHILE e # NIL DO
						IF prefix THEN
							COPY(fs, name); Strings.Append(name, e.name^)
						ELSE
							COPY(e.name^, name)
						END;
						ExtractEntry(context.out, zip, e, name, backup, path);
						e := zip.GetNext(e)
					END;
				ELSE
					context.error.String(name); context.error.String(" is not a valid zip file"); context.error.Ln()
				END
			ELSE
				context.error.String(name); context.error.String(" not found"); context.error.Ln()
			END;
			context.arg.SkipWhitespace(); context.arg.String(name)
		END;
	END ExtractAll;

	(* Directory [ \d ] zip ~ *)
	PROCEDURE Directory*(context : Commands.Context);
	VAR
		F: Files.File; zip: ZipFile; name: Files.FileName; res: WORD; i: LONGINT;
		e: Entry; opt: ARRAY 32 OF CHAR; ch: CHAR; detail: BOOLEAN;
	BEGIN
		context.arg.SkipWhitespace();
		detail := FALSE;
		WHILE context.arg.Peek() = "\" DO
			context.arg.Char(ch); context.arg.SkipWhitespace(); context.arg.String(opt);
			IF opt = "d" THEN
				detail := TRUE
			ELSE
				context.error.String("unknown option "); context.error.String(opt); context.error.Ln();
				RETURN
			END;
			context.arg.SkipWhitespace()
		END;
		context.arg.String(name);
		IF name = "" THEN RETURN END;
		F := Files.Old(name);
		IF F = NIL THEN RETURN END;
		NEW(zip, F, res);
		IF res = Streams.Ok THEN
			context.out.String("Directory of "); context.out.String(name);
			context.out.Ln(); context.out.Ln();
			e := zip.GetFirst(); i := 0;
			WHILE e # NIL DO
				INC(i);
				context.out.String(e.name^);
				IF detail THEN
					context.out.Char(09X); Strings.DateToStr(e.td, opt); context.out.String(opt);
					context.out.String(" "); Strings.TimeToStr(e.td, opt); context.out.String(opt);
					context.out.Char(09X); context.out.Int(e.size, 0);
					context.out.Char(09X); context.out.Int(e.csize, 0);
					context.out.Ln()
				ELSE
					IF (i MOD 2) = 0 THEN
						context.out.Ln()
					ELSE
						context.out.Char(09X)
					END
				END;
				e := zip.GetNext(e)
			END;
			context.out.Ln()
		ELSE
			context.error.String(name); context.error.String(" is not a valid zip file"); context.error.Ln()
		END;
	END Directory;

END Unzip.

System.Free Unzip Inflate ~

Inflate.Mod	Unzip.Mod
