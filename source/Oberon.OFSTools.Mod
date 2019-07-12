(* Aos, Copyright 2001, Pieter Muller, ETH Zurich *)

MODULE OFSTools IN Oberon; (** AUTHOR "pjm"; PURPOSE "Aos version of Native Oberon's OFSTools"; *)

IMPORT Modules IN A2, Streams IN A2, Commands IN A2, AosFS := Files IN A2, Texts, Oberon, In, Out, Files, NatFiles := Files;

VAR
	W: Texts.Writer;

PROCEDURE ExpandAlias(VAR alias, genvol, genfs: ARRAY OF CHAR);
VAR t: ARRAY 64 OF CHAR; s: Texts.Scanner; i, j: LONGINT;
BEGIN
	genvol[0] := 0X; genfs[0] := 0X;
	t := "AosFS.Alias.";
	i := 0; WHILE t[i] # 0X DO INC(i) END;
	j := 0; WHILE alias[j] # 0X DO t[i] := alias[j]; INC(i); INC(j) END;
	t[i] := 0X;
	Oberon.OpenScanner(s, t);
	IF s.class = Texts.Name THEN
		COPY(s.s, genvol); Texts.Scan(s);
		IF s.class = Texts.Name THEN
			COPY(s.s, genfs)
		END
	END
END ExpandAlias;

PROCEDURE GetSelection(VAR par: ARRAY OF CHAR);
VAR t: Texts.Text; r: Texts.Reader; beg, end, time, i: LONGINT; ch: CHAR;
BEGIN
	Oberon.GetSelection(t, beg, end, time);
	IF (time # -1) & (t # NIL) THEN
		Texts.OpenReader(r, t, beg);
		i := 0; Texts.Read(r, ch);
		WHILE (ch >= " ") & (i # LEN(par)-1) DO par[i] := ch; INC(i); Texts.Read(r, ch) END;
		par[i] := 0X
	ELSE
		In.Done := FALSE
	END
END GetSelection;

PROCEDURE GetFileSystemFactory(CONST name : ARRAY OF CHAR; error : Streams.Writer) : AosFS.FileSystemFactory;
VAR
	factory : AosFS.FileSystemFactory;
	moduleName, procedureName : Modules.Name; msg : ARRAY 128 OF CHAR; res : WORD;
BEGIN
	factory := NIL;
	Commands.Split(name, moduleName, procedureName, res, msg);
	IF (res = Commands.Ok) THEN
		GETPROCEDURE(moduleName, procedureName, factory);
	ELSE
		error.String(msg); error.Ln;
	END;
	RETURN factory;
END GetFileSystemFactory;

PROCEDURE Mount*;	(** prefix alias ([volpar] ["|" fspar] ~ | ^ ) *)
VAR
	factory : AosFS.FileSystemFactory;
	parvol, parfs: AosFS.Parameters; s: Texts.Scanner; i, k : LONGINT;
	temp, par, alias, genvol, genfs: ARRAY 64 OF CHAR; prefix: AosFS.Prefix;
	r : Streams.StringReader; w : Streams.StringWriter; string : ARRAY 1024 OF CHAR; res : WORD;
BEGIN
	string := "";
	Texts.OpenScanner(s, Oberon.Par.text, Oberon.Par.pos); Texts.Scan(s);
	IF s.class = Texts.Name THEN COPY(s.s, prefix); Texts.Scan(s) ELSE s.class := Texts.Inval END;
	IF s.class = Texts.Name THEN COPY(s.s, alias) ELSE s.class := Texts.Inval END;
	IF s.class # Texts.Inval THEN
		i := -1;
		REPEAT INC(i); Texts.Read(s, par[i]) UNTIL s.eot OR (par[i] < 20X) OR (par[i] = "~");
		par[i] := 0X;
		IF par[0] = "^" THEN GetSelection(par) END;
		ExpandAlias(alias, genvol, genfs);
		Out.String(prefix); Out.String(": ");
		NEW(r, 1024); NEW(w, 1024);
		IF AosFS.This(prefix) # NIL THEN
			Out.String("already used")
		ELSIF (genvol[0] = 0X) OR (genfs[0] = 0X) THEN
			Out.String("unknown alias "); Out.String(alias);
		ELSE
			IF genvol # "NIL" THEN
				i := 0; WHILE (i < LEN(temp)-1) & (par[i] # 0X) & (par[i] # "|") DO temp[i] := par[i]; INC(i) END;
				temp[i] := 0X;
				r.SetRaw(temp, 0, i+1);
				NEW(parvol, NIL, r, w, w, NIL);
				parvol.vol := NIL; res := 0;
				COPY(prefix, parvol.prefix);
				factory := GetFileSystemFactory(genvol, w);
				IF (factory # NIL) THEN
					factory(parvol);
				END;
				IF (factory = NIL) OR (parvol.vol = NIL) THEN
					parvol.error.Update; Out.String(string);
					res := 1;
				END;
			ELSE
				i := 0
			END;
			IF (res = Commands.Ok) THEN
				IF par[i] = "|" THEN INC(i) END;
				k := 0; WHILE (k < LEN(temp)-1) & (par[i] # 0X) DO temp[k] := par[i]; INC(i); INC(k) END;
				temp[k] := 0X;
				r.SetRaw(temp, 0, k+1);
				NEW(parfs, NIL, r, w, w, NIL);
				parfs.vol := parvol.vol; COPY(prefix, parfs.prefix);
				factory := GetFileSystemFactory(genfs, w);
				IF (factory # NIL) THEN
					factory(parfs);
					IF (AosFS.This(prefix) = NIL) THEN
						res := 1;
						parfs.error.Update; Out.String(string);
					ELSE
						Out.String(prefix); Out.String(": mounted"); Out.Ln;
					END;
				ELSE
					res := 1;
					Out.String("Alias not defined"); Out.Ln;
				END;

				IF (res # 0) & (parvol.vol # NIL) THEN
					parvol.vol.Finalize()	(* unmount volume *)
				END
			ELSE
				(* skip *)
			END
		END;
		Out.Ln
	END
END Mount;

PROCEDURE Unmount*;	(** prefix *)
VAR prefix: AosFS.Prefix; fs: AosFS.FileSystem; i: LONGINT;
BEGIN
	In.Open;  In.Name(prefix);
	IF In.Done THEN
		i := 0; WHILE (prefix[i] # 0X) & (prefix[i] # ":") DO INC(i) END;
		prefix[i] := 0X;
		Out.String(prefix); Out.Char(":");
		fs := AosFS.This(prefix);
		IF fs # NIL THEN
			IF (fs.vol = NIL) OR ~(AosFS.Boot IN fs.vol.flags) THEN
				AosFS.Remove(fs);
				Out.String(" unmounted")
			ELSE
				Out.String(" can't unmount boot volume")
			END
		ELSE
			Out.String(" not found")
		END;
		Out.Ln
	END
END Unmount;

PROCEDURE SetDefault*;	(** prefix *)
VAR prefix: AosFS.Prefix; fs: AosFS.FileSystem; i: LONGINT; ft: AosFS.FileSystemTable;
BEGIN
	In.Open;  In.Name(prefix);
	IF In.Done THEN
		i := 0; WHILE (prefix[i] # 0X) & (prefix[i] # ":") DO INC(i) END;
		prefix[i] := 0X;
		fs := AosFS.This(prefix);
		IF fs # NIL THEN
			AosFS.Promote(fs);
			AosFS.GetList(ft);
			IF ft # NIL THEN
				Out.String("Path: ");
				FOR i := 0 TO LEN(ft)-1 DO
					Out.String(ft[i].prefix);  Out.String(" ")
				END
			END
		ELSE
			Out.String(prefix);  Out.String(": not found")
		END;
		Out.Ln
	END
END SetDefault;

PROCEDURE ModifyName(in, prefix: ARRAY OF CHAR;  add: BOOLEAN;  VAR out: ARRAY OF CHAR);
VAR i, j: LONGINT;
BEGIN
	IF add THEN
		i := 0; WHILE prefix[i] # 0X DO out[i] := prefix[i]; INC(i) END;
		j := 0; WHILE in[j] # 0X DO out[i] := in[j]; INC(i); INC(j) END;
		out[i] := 0X
	ELSE
		i := 0; WHILE (prefix[i] # 0X) & (in[i] = prefix[i]) DO INC(i) END;
		IF prefix[i] # 0X THEN i := 0 END;
		j := 0; WHILE in[i] # 0X DO out[j] := in[i]; INC(i); INC(j) END;
		out[j] := 0X
	END
END ModifyName;

PROCEDURE GenCopyFiles*;	(** remprefix addprefix ( "mask" | &file | { file [=> file] } ) ~ *)
VAR
	s: Texts.Scanner; t: Texts.Text; time, date, size: LONGINT; enum: AosFS.Enumerator;
	prefix1, prefix2: AosFS.Prefix; name: AosFS.FileName; flags: SET;
BEGIN
	StartScan(s);
	IF s.class IN {Texts.Name, Texts.String} THEN COPY(s.s, prefix1); Texts.Scan(s) END;
	IF s.class IN {Texts.Name, Texts.String} THEN COPY(s.s, prefix2); Texts.Scan(s) END;
	IF s.class = Texts.String THEN	(* directory mask *)
		NEW(enum);
		enum.Open(s.s, {});
		WHILE enum.GetEntry(name, flags, time, date, size) DO
			Texts.WriteString(W, name); Texts.WriteLn(W)
		END;
		enum.Close;
		NEW(t);  Texts.Open(t, "");
		Texts.Append(t, W.buf);
		Texts.OpenScanner(s, t, 0);  Texts.Scan(s)
	ELSIF (s.class = Texts.Char) & (s.c = "&") THEN
		Texts.Scan(s);
		IF s.class = Texts.Name THEN
			NEW(t);  Texts.Open(t, s.s);
			Texts.OpenScanner(s, t, 0);  Texts.Scan(s)
		END
	END;
	Texts.WriteString(W, "System.CopyFiles");  Texts.WriteLn(W);
	WHILE s.class = Texts.Name DO
		Texts.WriteString(W, "  ");  Texts.WriteString(W, s.s);  Texts.WriteString(W, " => ");
		COPY(s.s, name);
		Texts.Scan(s);
		IF (s.class = Texts.Char) & (s.c = "=") THEN
			Texts.Scan(s);
			IF (s.class = Texts.Char) & (s.c = ">") THEN
				Texts.Scan(s);
				IF s.class = Texts.Name THEN
					COPY(s.s, name);
					Texts.Scan(s)
				ELSE
					(* skip *)
				END
			ELSE
				(* skip *)
			END
		END;
		ModifyName(name, prefix1, FALSE, name);
		ModifyName(name, prefix2, TRUE, name);
		Texts.WriteString(W, name);  Texts.WriteLn(W)
	END;
	Texts.Write(W, "~");
	NEW(t);  Texts.Open(t, "");
	Texts.Append(t, W.buf);
	Oberon.OpenText("", t, 200, 200)
END GenCopyFiles;

PROCEDURE StartScan(VAR S: Texts.Scanner);
VAR beg, end, time: LONGINT;  T: Texts.Text;
BEGIN
	Texts.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos);
	Texts.Scan(S);
	IF (S.class = Texts.Char) & (S.c = "^") OR (S.line # 0) THEN
		Oberon.GetSelection(T, beg, end, time);
		IF time >= 0 THEN Texts.OpenScanner(S, T, beg); Texts.Scan(S) END
	END
END StartScan;

PROCEDURE CopyTo*;	(** dstprefix srcprefix ( &file | { file [=> file]} ) ~ *)
CONST BufSize = 32768;
VAR
	S: Texts.Scanner;  sf: NatFiles.File;  df: Files.File;  sr: NatFiles.Rider;  dr: Files.Rider;
	sLen, dLen, i: INTEGER;  ch: CHAR;  src, dest: ARRAY 64 OF CHAR;  t: Texts.Text;
	buf: ARRAY BufSize OF CHAR;
BEGIN
	StartScan(S);
	IF ~(S.class IN {Texts.Name, Texts.String}) THEN
		Texts.WriteString(W, "Missing destination prefix");  Texts.WriteLn(W)
	ELSE
		dLen := 0;  WHILE S.s[dLen] # 0X DO  dest[dLen] := S.s[dLen];  INC(dLen)  END;
		Texts.Scan(S);
		IF ~(S.class IN {Texts.Name, Texts.String}) THEN
			Texts.WriteString(W, "Missing source prefix");  Texts.WriteLn(W)
		ELSE
			sLen := 0;  WHILE S.s[sLen] # 0X DO  src[sLen] := S.s[sLen];  INC(sLen)  END;
			Texts.Scan(S);
			IF (S.class = Texts.Char) & (S.c = "&") THEN
				Texts.Scan(S);
				IF S.class IN {Texts.Name, Texts.String} THEN
					NEW(t);  Texts.Open(t, S.s);
					Texts.OpenScanner(S, t, 0);  Texts.Scan(S)
				END
			END;
			WHILE S.class IN {Texts.Name, Texts.String} DO
				i := 0;  ch := S.s[i];
				WHILE ch # 0X DO  src[sLen+i] := ch;  dest[dLen+i] := ch;  INC(i);  ch := S.s[i]  END;
				src[sLen+i] := 0X;  dest[dLen+i] := 0X;
				Texts.WriteString(W, src);
				sf := NatFiles.Old(src);
				IF sf # NIL THEN
					Texts.Scan(S);
					IF (S.class = Texts.Char) & (S.c = "=") THEN
						Texts.Scan(S);
						IF (S.class = Texts.Char) & (S.c = ">") THEN
							Texts.Scan(S);
							IF S.class IN {Texts.Name, Texts.String} THEN
								i := 0;  ch := S.s[i];
								WHILE ch # 0X DO  dest[dLen+i] := ch;  INC(i);  ch := S.s[i]  END;
								dest[dLen+i] := 0X;
								Texts.Scan(S)
							ELSE
								(* skip *)
							END
						ELSE
							(* skip *)
						END
					END;
					Texts.WriteString(W, " => ");  Texts.WriteString(W, dest);
					df := Files.New(dest);
					IF df # NIL THEN
						Texts.WriteString(W, " copying");
						Texts.Append(Oberon.Log, W.buf);
						NatFiles.Set(sr, sf, 0);  Files.Set(dr, df, 0);
						LOOP
							NatFiles.ReadBytes(sr, buf, BufSize);
							IF sr.res = BufSize THEN EXIT END;
							Files.WriteBytes(dr, buf, BufSize - sr.res)
						END;
						Files.Register(df);
						ASSERT(Files.Length(df) = Files.Length(sf))
					ELSE
						Texts.WriteString(W, " create failed");
						S.class := Texts.Inval
					END
				ELSE
					Texts.WriteString(W, " open failed");
					S.class := Texts.Inval
				END;
				Texts.WriteLn(W)
			END
		END
	END;
	Texts.Append(Oberon.Log, W.buf)
END CopyTo;

PROCEDURE WriteK(VAR W: Texts.Writer;  k: LONGINT);
VAR suffix: CHAR;
BEGIN
	IF k < 10*1024 THEN suffix := "K"
	ELSIF k < 10*1024*1024 THEN suffix := "M"; k := k DIV 1024
	ELSE suffix := "G"; k := k DIV (1024*1024)
	END;
	Texts.WriteInt(W, k, 1);  Texts.Write(W, suffix);  Texts.Write(W, "B")
END WriteK;

PROCEDURE Watch*;
VAR free, total, i: LONGINT; fs: AosFS.FileSystem; ft: AosFS.FileSystemTable;
BEGIN
	Texts.WriteString(W, "OFSTools.Watch");  Texts.WriteLn(W);
	AosFS.GetList(ft);
	IF ft # NIL THEN
		FOR i := 0 TO LEN(ft)-1 DO
			fs := ft[i];
			Texts.WriteString(W, fs.prefix);  Texts.WriteString(W, ": ");
			Texts.WriteString(W, fs.desc);
			IF fs.vol # NIL THEN
				Texts.WriteString(W, " on "); Texts.WriteString(W, fs.vol.name);
				IF AosFS.ReadOnly IN fs.vol.flags THEN Texts.WriteString(W, " (read-only)") END;
				IF AosFS.Removable IN fs.vol.flags THEN Texts.WriteString(W, " (removable)") END;
				IF AosFS.Boot IN fs.vol.flags THEN Texts.WriteString(W, " (boot)") END;
				Texts.WriteLn(W);  Texts.Write(W, 9X);
				free := ENTIER(fs.vol.Available()/1024.0D0 * fs.vol.blockSize);
				total := ENTIER(fs.vol.size/1024.0D0 * fs.vol.blockSize);
				WriteK(W, free);  Texts.WriteString(W, " of ");
				WriteK(W, total);  Texts.WriteString(W, " free")
			END;
			Texts.WriteLn(W)
		END
	END;
	Texts.Append(Oberon.Log, W.buf)
END Watch;

BEGIN
	Texts.OpenWriter(W)
END OFSTools.
