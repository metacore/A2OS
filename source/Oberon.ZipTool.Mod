(* ETH Oberon, Copyright 2001 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

MODULE ZipTool IN Oberon;	(** Stefan Walthert  **)

IMPORT Zip, Objects, Oberon, Texts, Files;

CONST
	ErrorStop = TRUE;	(* stop on error *)
	EditMenu = "System.Close System.Copy System.Grow Edit.Search Edit.Store";
	EXTRACT = 1;
	OPEN = 2;

VAR
	W: Texts.Writer;

(* Get the suffix of str. The suffix is started by the last sepchar in str.
	If sepchar does not occur in str, str is returned *)
PROCEDURE GetSuffix(VAR str(* in *), suf(* out *): ARRAY OF CHAR; sepchar: CHAR);
VAR
	i, j, len, sep: LONGINT;
BEGIN
	i := 0; sep := -1;
	WHILE str[i] # 0X DO
		IF str[i] = sepchar THEN
			sep := i
		END;
		INC(i)
	END;
	j := 0;
	len := LEN(suf) - 1; i := sep + 1;
	WHILE (j < len) & (str[i] # 0X) DO
		suf[j] := str[i]; INC(j); INC(i)
	END;
	suf[j] := 0X
END GetSuffix;

(* Append this to to *)
PROCEDURE Append(VAR to: ARRAY OF CHAR; this: ARRAY OF CHAR);
	VAR i, j, l: LONGINT;
BEGIN
	i := 0;
	WHILE to[i] # 0X DO
		INC(i)
	END;
	l := LEN(to)-1; j := 0;
	WHILE (i < l) & (this[j] # 0X) DO
		to[i] := this[j]; INC(i); INC(j)
	END;
	to[i] := 0X
END Append;

PROCEDURE NewStyle(width: LONGINT; tabs: ARRAY OF CHAR): Objects.Object;
VAR obj: Objects.Object; res: INTEGER; a: Objects.AttrMsg;
BEGIN
	Objects.NewObj := NIL;
	Oberon.Call("TextGadgets.NewStyleProc", Oberon.Par, FALSE, res);	(* ignore res *)
	obj := Objects.NewObj; Objects.NewObj := NIL;
	IF obj # NIL THEN
		a.id := Objects.set; a.name := "Width"; a.res := -1; Objects.Stamp(a);
		a.class := Objects.Int; a.i := width; obj.handle(obj, a);
		a.id := Objects.set; a.name := "Tabs"; a.res := -1; Objects.Stamp(a);
		a.class := Objects.String; COPY(tabs, a.s); obj.handle(obj, a)
	END;
	RETURN obj
END NewStyle;

(** Writes the directory of an archive. **)
PROCEDURE WriteDirectory*(VAR W: Texts.Writer; archive: ARRAY OF CHAR; details, tabs: BOOLEAN; VAR res: WORD);
VAR
	style: Objects.Object;
	arc: Zip.Archive;
	ent: Zip.Entry;
	width: INTEGER;
	ratio: LONGINT;
BEGIN
	arc := Zip.OpenArchive(archive, res);
	CASE res OF
	| Zip.Ok:
		width := 200;
		IF details THEN
			INC(width, 440);
			IF tabs THEN
				style := NewStyle(width, "160,280,330,380");
				IF style # NIL THEN Texts.WriteObj(W, style) END
			END;
			Texts.WriteString(W, "name"); Texts.Write(W, CHR(9)); Texts.WriteString(W, "date"); Texts.Write(W, CHR(9));
			Texts.WriteString(W, "size"); Texts.Write(W, CHR(9)); Texts.WriteString(W, "ratio"); Texts.Write(W, CHR(9));
			Texts.WriteString(W, "compressed"); Texts.WriteLn(W); Texts.WriteLn(W)
		END;
		ent := Zip.FirstEntry(arc);
		WHILE ent # NIL DO
			Texts.WriteString(W, ent.name);
			IF details THEN
				Texts.Write(W, CHR(9)); Texts.WriteDate(W, ent.time, ent.date);
				Texts.Write(W, CHR(9)); Texts.WriteInt(W, ent.uncompSize, 0);
				ratio := ENTIER(((1 - ent.compSize / ent.uncompSize) * 100) + 0.5);
				IF ratio < 0 THEN ratio := 0 END;	(* ratio can not be less than zero *)
				Texts.Write(W, CHR(9)); Texts.WriteInt(W, ratio, 0); Texts.WriteString(W, "%");
				Texts.Write(W, CHR(9)); Texts.WriteInt(W, ent.compSize, 0)
			END;
			Texts.WriteLn(W);
			ent := Zip.NextEntry(ent)
		END;
		Texts.WriteLn(W); Texts.WriteInt(W, arc.nofEntries, 0);
		IF arc.nofEntries = 1 THEN Texts.WriteString(W, " entry")
		ELSE Texts.WriteString(W, " entries")
		END;
		 Texts.WriteLn(W)
	| Zip.FileError:
		Texts.WriteString(W, archive); Texts.WriteString(W, " not found"); Texts.WriteLn(W)
	| Zip.NotZipArchiveError:
		Texts.WriteString(W, archive); Texts.WriteString(W, " is not a valid zip-archive"); Texts.WriteLn(W)
	END
END WriteDirectory;

(** Shows the content of the selected zip-archive in a new viewer.
	ZipTool.Directory [\d | \D] (^ | ZipFile)
	Options:
	\d: If set, details of entries of selected zip-archive are shown
	\D: same as \d, but without style element for tabbing **)
PROCEDURE Directory*;
VAR
	S: Texts.Scanner; T1, T2: Texts.Text; beg, end, time: LONGINT;
	details, tabs: BOOLEAN;	(* show details of Entries *)
	res: WORD; width: INTEGER;
BEGIN
	details := FALSE; tabs := FALSE;
	Texts.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos); Texts.Scan(S);
	IF (S.class = Texts.Char) & (S.c = Oberon.OptionChar) THEN
		details := (CAP(S.nextCh) = "D"); tabs := (S.nextCh = "d");
		IF ~details THEN
			Texts.WriteString(W, "unknown option "); Texts.Write(W, S.nextCh); Texts.WriteLn(W); Texts.Append(Oberon.Log, W.buf)
		END;
		Texts.Scan(S); Texts.Scan(S)
	END;
	IF (S.class = Texts.Char) & (S.c = "^") THEN
		Oberon.GetSelection(T1, beg, end, time);
		IF time # -1 THEN Texts.OpenScanner(S, T1, beg); Texts.Scan(S) END;
	END;
	IF S.class IN {Texts.Name, Texts.String} THEN
		WriteDirectory(W, S.s, details, tabs, res);
		IF res = Zip.Ok THEN
			NEW(T2); Texts.Open(T2, ""); Texts.Append(T2, W.buf);
			IF details THEN width := 200+440 ELSE width := 200 END;
			Oberon.OpenText(S.s, T2, width, 300)
		ELSE
			Texts.Append(Oberon.Log, W.buf)
		END
	END
END Directory;

PROCEDURE doExtract(action: INTEGER;
						arc: Zip.Archive; ent: Zip.Entry; name: ARRAY OF CHAR; VAR tempfile: Files.File;
						path, overwrite,show: BOOLEAN; VAR res: WORD);
VAR
	f, of: Files.File; r: Files.Rider;
	bakname, temp: ARRAY 256 OF CHAR; res2: INTEGER;
	suf: ARRAY 32 OF CHAR;
	T : Texts.Text;
BEGIN
	IF action = EXTRACT THEN
		IF ~path THEN
	(*		GetSuffix(name, name, ':'); *)
			GetSuffix(name, name, '/')
		END;
		f := Files.New(name);
	ELSE
		temp := "Temp.Zip.";
		GetSuffix(name,suf,'.');
		Append(temp,suf);
		f := Files.New(temp);
	END;
	tempfile := f;
	Files.Set(r, f, 0);
	Zip.ExtractEntry(arc, ent, r, res);
	CASE res OF
	| Zip.Ok:
		IF action = EXTRACT THEN
			Texts.WriteString(W, " extracted");
			of := Files.Old(name);
			IF of # NIL THEN	(* file exists on this volume or another volume in search path *)
				IF ~overwrite THEN
					COPY(name, bakname); Append(bakname, ".Bak");	(* assume enough space for .Bak *)
					Files.Rename(name, bakname, res2);
					IF res2 = 0 THEN
						Texts.WriteString(W, "; backup in "); Texts.WriteString(W, bakname)
					ELSE	(* assume old file was in another place in the search path *)
						Files.GetName(of, bakname);
						Texts.WriteString(W, "; masks "); Texts.WriteString(W, bakname)
					END
				ELSE
					Texts.WriteString(W, "; overwritten")
				END
			END;
			Files.SetDate(f, ent.time, ent.date);
		ELSE
			Texts.WriteString(W, " opened");
		END;
		Files.Register(f);
		tempfile := f;
		IF action =  OPEN THEN
			IF show THEN  (* if called by ZipTool then show direct ; if called by ZipDocs let ZipDocs handle this *)
				NEW(T); Texts.Open(T,temp);
				Oberon.OpenText(name,T,500,200);
				Files.Delete(temp, res2);
			END;
		END;
	| Zip.NotSupportedError: Texts.WriteString(W, " file encrypted / compression method not supported, could not extract")
	| Zip.DataError: Texts.WriteString(W, " data error (file corrupted), could not extract")
	| Zip.BadName: Texts.WriteString(W, " bad file name")
	ELSE (* should not happen *)
	END;
	Texts.WriteLn(W); Texts.Append(Oberon.Log, W.buf)
END doExtract;

(** Extracts the entry ent from the zip-archive ent and stores as under the filename name. Some log-output is generated.
	If path is set, the file is stored in the directory according to the relative path in name.
	If overwrite is set, files with the same name are overwritten, otherwise they are renamed to name.Bak.
	Possible results: cf. Zip.ExtractEntry **)
PROCEDURE ExtractFile*(arc: Zip.Archive; ent: Zip.Entry; name: ARRAY OF CHAR; path, overwrite: BOOLEAN; VAR res: WORD);
VAR
	temp: Files.File;
BEGIN
	doExtract(EXTRACT,arc,ent,name,temp,path,overwrite,FALSE,res);
END ExtractFile;

(** Extracts the entry ent from the zip-archive ent and stores as under the filename name. Some log-output is generated.
	If path is set, the file is stored in the directory according to the relative path in name.
	If overwrite is set, files with the same name are overwritten, otherwise they are renamed to name.Bak.
	Possible results: cf. Zip.ExtractEntry **)
PROCEDURE OpenFile*(arc: Zip.Archive; ent: Zip.Entry; name: ARRAY OF CHAR; VAR tempfile: Files.File;
										path, overwrite, show: BOOLEAN; VAR res: WORD);
BEGIN
	doExtract(OPEN,arc,ent,name,tempfile,path,overwrite,show,res);
END OpenFile;

PROCEDURE cmdOpenExtract (action: INTEGER);
VAR
	S: Texts.Scanner; T: Texts.Text; beg, end, time: LONGINT;
	arc: Zip.Archive; ent: Zip.Entry; name: ARRAY 256 OF CHAR;
	res: WORD;
	path, overwrite: BOOLEAN;
	temp: Files.File;
BEGIN
	Texts.WriteString(W,"ZipTool.");
	CASE action OF
	| EXTRACT: Texts.WriteString(W,"Extract ");
	| OPEN: Texts.WriteString(W,"Open ");
	END;
	Texts.Append(Oberon.Log,W.buf);
	path := FALSE; overwrite := FALSE;
	T := Oberon.Par.text;
	Texts.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos); Texts.Scan(S);
	WHILE (S.class = Texts.Char) & (S.c = Oberon.OptionChar) DO
		IF S.nextCh = "d" THEN
			 path := TRUE; Texts.Scan(S); Texts.Scan(S)
		ELSIF S.nextCh = "o" THEN
			overwrite := TRUE; Texts.Scan(S); Texts.Scan(S)
		ELSE
			Texts.WriteString(W, "unknown option "); Texts.Write(W, S.nextCh); Texts.WriteLn(W);
			Texts.Append(Oberon.Log, W.buf);
			Texts.Scan(S); Texts.Scan(S)
		END
	END;
	IF (S.class = Texts.Char) & (S.c = "^") THEN
		Oberon.GetSelection(T, beg, end, time);
		IF time # -1 THEN Texts.OpenScanner(S, T, beg); Texts.Scan(S) END;
	END;
	IF S.class IN {Texts.Name, Texts.String} THEN
		arc := Zip.OpenArchive(S.s, res);
		Texts.WriteString(W, S.s);
		CASE res OF
		| Zip.Ok:
			Texts.WriteLn(W);
			Texts.Scan(S);
			IF (S.class = Texts.Char) & (S.c = "^") THEN
				Oberon.GetSelection(T, beg, end, time);
				IF time # -1 THEN Texts.OpenScanner(S, T, beg); Texts.Scan(S) END;
			ELSE
				end := T.len
			END;
			WHILE (S.class IN {Texts.Name, Texts.String}) & (Texts.Pos(S) <= end + S.len) DO
				COPY(S.s, name);
				ent := Zip.GetEntry(arc, name, res);
				Texts.WriteString(W, " "); Texts.WriteString(W, name);
				Texts.Scan(S);
				IF (S.class = Texts.Char) & (S.c = "=") THEN
					Texts.Scan(S);
					IF (S.class = Texts.Char) & (S.c = ">") THEN
						Texts.Scan(S);
						IF S.class IN {Texts.Name, Texts.String} THEN
							COPY(S.s, name); Texts.Scan(S)
						ELSE
							S.class := Texts.Inval
						END
					ELSE
						S.class := Texts.Inval
					END
				END;
				IF S.class # Texts.Inval THEN
					CASE res OF
					| Zip.Ok:
						IF ent.name # name THEN Texts.WriteString(W, " => "); Texts.WriteString(W, name) END;
						Texts.Append(Oberon.Log, W.buf);
						IF action = EXTRACT THEN
							ExtractFile(arc, ent, name, path, overwrite, res)
						ELSE
							OpenFile(arc, ent, name, temp, path, overwrite, TRUE, res);
						END;
					| Zip.EntryNotFound: Texts.WriteString(W, " not found"); Texts.WriteLn(W)
					ELSE	(* should not happen *)
					END;
					Texts.Append(Oberon.Log, W.buf);
					IF ErrorStop & (res # Zip.Ok) THEN end := MIN(LONGINT) END
				END
			END
		| Zip.FileError: Texts.WriteString(W, " not found"); Texts.WriteLn(W)
		| Zip.NotZipArchiveError: Texts.WriteString(W, " is not a valid zip-archive"); Texts.WriteLn(W)
		END;
		Texts.Append(Oberon.Log, W.buf)
	END
END cmdOpenExtract;

(** Extracts the selected entries of the selected zip-Archive. The relative path in the file name of the entry
	is ignored (c.f. option \d).
	ZipTool.Extract [\d] [\o] (^ | ZipFile (^ | {Entry [=> NewName]}))
	Options:
	\d: If set, the file is stored in the directory according to the relative path in the file name of the entry
	\o: If set, files with the same name are overwritten, otherwise they are renamed to filename.Bak **)
PROCEDURE Extract*;
BEGIN
	cmdOpenExtract(EXTRACT);
END Extract;

(** Extracts all entries of the selected zip-archives. The relative path in the file name of the entry
	is ignored (c.f. option \d).
	ZipTool.ExtractAll [\d] [\o] [\p DstPrefix] (^ | {ZipFile})
	Options:
	\d: If set, the file is stored in the directory according to the relative path in the file name of the entry
	\o: If set, files with the same name are overwritten, otherwise they are renamed to filename.Bak
	\p: If set, DstPrefix is prefixed to all file names of the entries in the zip-archives **)
PROCEDURE ExtractAll*;
VAR
	S: Texts.Scanner; T: Texts.Text; beg, end, time: LONGINT;
	path, overwrite: BOOLEAN; prefix: ARRAY 64 OF CHAR; name: ARRAY 256 OF CHAR;
	arc: Zip.Archive;
	ent: Zip.Entry;
	res: WORD;
	n, m: LONGINT;	(* number of extracted files *)
BEGIN
	path := FALSE; overwrite := FALSE; prefix := "";
	T := Oberon.Par.text;
	Texts.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos); Texts.Scan(S);
	WHILE (S.class = Texts.Char) & (S.c = Oberon.OptionChar) DO
		IF S.nextCh = "d" THEN
			 path := TRUE; Texts.Scan(S); Texts.Scan(S)
		ELSIF S.nextCh = "o" THEN
			overwrite := TRUE; Texts.Scan(S); Texts.Scan(S)
		ELSIF S.nextCh = "p" THEN
			Texts.Scan(S); Texts.Scan(S);
			IF S.class IN {Texts.Name, Texts.String} THEN
				COPY(S.s, prefix)
			ELSE
				Texts.WriteString(W, "bad \p option"); Texts.WriteLn(W); Texts.Append(Oberon.Log, W.buf)
			END;
			Texts.Scan(S)
		ELSE
			Texts.WriteString(W, "unknown option "); Texts.Write(W, S.nextCh); Texts.WriteLn(W);
			Texts.Append(Oberon.Log, W.buf);
			Texts.Scan(S); Texts.Scan(S)
		END
	END;
	IF (S.class = Texts.Char) & (S.c = "^") THEN
		Oberon.GetSelection(T, beg, end, time);
		IF time # -1 THEN Texts.OpenScanner(S, T, beg); Texts.Scan(S) END
	ELSE
		end := T.len
	END;
	WHILE (S.class IN {Texts.Name, Texts.String})  & (Texts.Pos(S) <= end + S.len) DO
		arc := Zip.OpenArchive(S.s, res);
		Texts.WriteString(W, "ZipTool.ExtractAll "); Texts.WriteString(W, S.s); Texts.Append(Oberon.Log, W.buf);
		CASE res OF
		| Zip.Ok:
			ent := Zip.FirstEntry(arc);
			n := 0; m := 0; Texts.WriteLn(W);
			WHILE ent # NIL DO
				IF prefix # "" THEN
					COPY(prefix, name); Append(name, ent.name)
				ELSE
					COPY(ent.name, name)
				END;
				Texts.WriteString(W, " "); Texts.WriteString(W, name); Texts.Append(Oberon.Log, W.buf);
				ExtractFile(arc, ent, name, path, overwrite, res); Texts.Append(Oberon.Log, W.buf);
				IF res = Zip.Ok THEN INC(n) ELSE INC(m) END;
				ent := Zip.NextEntry(ent);
				IF ErrorStop & (res # Zip.Ok) THEN ent := NIL END
			END;
			Texts.WriteInt(W, n, 0); Texts.WriteString(W, " files extracted");
			IF m # 0 THEN
				Texts.WriteString(W, ", "); Texts.WriteInt(W, m, 0); Texts.WriteString(W, " errors");
				IF ErrorStop THEN end := MIN(LONGINT) END
			END
		| Zip.FileError: Texts.WriteString(W, " not found")
		| Zip.NotZipArchiveError: Texts.WriteString(W, " is not a valid zip-archive")
		END;
		Texts.WriteLn(W); Texts.Append(Oberon.Log, W.buf);
		Texts.Scan(S)
	END
END ExtractAll;

(** Extracts the selected entries of the selected zip-Archive. The relative path in the file name of the entry
	is ignored (c.f. option \d).
	ZipTool.Open [\d] [\o] (^ | ZipFile (^ | {Entry [=> NewName]}))
	Options:
	\d: If set, the file is stored in the directory according to the relative path in the file name of the entry
	\o: If set, files with the same name are overwritten, otherwise they are renamed to filename.Bak **)
PROCEDURE Open*;
BEGIN
	cmdOpenExtract(OPEN);
END Open;

(** Adds a file to the selected zip-archive.
	level: specifies the compression level (0: no compression, 9: best compression)
	strategy: specifies the compression strategy (from 0 - 2)
	res = Zip.Ok, Zip.BadName, Zip.EntryAlreadyExists, Zip.DataError **)
PROCEDURE AddFile*(arc: Zip.Archive; srcname, dstname: ARRAY OF CHAR; level, strategy: SHORTINT; VAR res: WORD);
VAR
	f: Files.File; r: Files.Rider;
BEGIN
	f := Files.Old(srcname);
	IF f = NIL THEN
		res := Zip.BadName
	ELSE
		Files.Set(r, f, 0);
		Zip.AddEntry(arc, dstname, r, Files.Length(f), level, strategy, res);
	END;
END AddFile;

(** Adds the selected files to the selected zip-archive.
	ZipTool.Add [\level [\strategy]] [\p] (^ | ZipFile (^ | {Entry [=> NewName]}))
	Options:
	\level: specifies the compression level (0: no compression, 9: best compression)
		if not set, default level (-1) is used
	\strategy: specifies the compression strategy (from 0 - 2)
	\p: remove prefix from filename **)
PROCEDURE Add*;
VAR
	S: Texts.Scanner; T: Texts.Text; beg, end, time, res: LONGINT;
	arc: Zip.Archive; i, j: LONGINT;
	strategy, level: SHORTINT; prefix: BOOLEAN;
	oldname, newname: ARRAY 256 OF CHAR;
BEGIN
	Texts.WriteString(W, "ZipTool.Add ");
	T := Oberon.Par.text; prefix := TRUE;
	level := Zip.DefaultCompression;
	strategy := Zip.DefaultStrategy;
	Texts.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos); Texts.Scan(S);
	WHILE (S.class = Texts.Char) & (S.c = '\') DO
		Texts.Scan(S);
		IF S.class = Texts.Int THEN
			level := SHORT(SHORT(S.i)); Texts.Scan(S);
			IF (S.class = Texts.Char) & (S.c = '\') THEN
				Texts.Scan(S);
				IF S.class = Texts.Int THEN
					strategy := SHORT(SHORT(S.i)); Texts.Scan(S)
				END
			END
		ELSIF (S.class = Texts.Name) & (S.s = "p") THEN
			prefix := FALSE; Texts.Scan(S)
		ELSE
			Texts.WriteString(W, "unknown option"); Texts.WriteLn(W);
			Texts.Append(Oberon.Log, W.buf); RETURN
		END
	END;
	IF (S.class = Texts.Char) & (S.c = "^") THEN
		Oberon.GetSelection(T, beg, end, time);
		IF time # -1 THEN Texts.OpenScanner(S, T, beg); Texts.Scan(S) END;
	END;
	IF S.class IN {Texts.Name, Texts.String} THEN
		arc := Zip.CreateArchive(S.s, res); Texts.WriteString(W, S.s); Texts.Append(Oberon.Log, W.buf);
		CASE res OF
		| Zip.Ok:
			Texts.WriteLn(W); Texts.Append(Oberon.Log, W.buf);
			Texts.Scan(S);
			IF (S.class = Texts.Char) & (S.c = "^") THEN
				Oberon.GetSelection(T, beg, end, time);
				IF time # -1 THEN Texts.OpenScanner(S, T, beg); Texts.Scan(S) END;
			ELSE
				end := T.len
			END;
			WHILE (S.class IN {Texts.Name, Texts.String}) & (Texts.Pos(S) <= (end + S.len)) DO
				COPY(S.s, oldname);
				IF ~prefix THEN
					i := 0; j := 0;
					WHILE S.s[i] # 0X DO
						IF S.s[i] = ":" THEN
							j := 0
						ELSE
							newname[j] := S.s[i]; INC(j)
						END;
						INC(i)
					END;
					newname[j] := 0X
				ELSE
					COPY(S.s, newname)
				END;
				Texts.Scan(S);
				IF (S.class = Texts.Char) & (S.c = "=") THEN
					Texts.Scan(S);
					IF (S.class = Texts.Char) & (S.c = ">") THEN
						Texts.Scan(S);
						IF S.class IN {Texts.Name, Texts.String} THEN
							COPY(S.s, newname); Texts.Scan(S)
						ELSE
							S.class := Texts.Inval
						END
					ELSE
						S.class := Texts.Inval
					END
				END;
				IF S.class # Texts.Inval THEN
					Texts.WriteString(W, " "); Texts.WriteString(W, oldname);
					IF oldname # newname THEN Texts.WriteString(W, " => "); Texts.WriteString(W, newname) END;
					Texts.Append(Oberon.Log, W.buf);
					AddFile(arc, oldname, newname, level, strategy, res);
					CASE res OF
					| Zip.Ok: Texts.WriteString(W, " added")
					| Zip.BadName: Texts.WriteString(W, " not found")
					| Zip.EntryAlreadyExists: Texts.WriteString(W, " entry already exists")
					| Zip.DataError: Texts.WriteString(W, " error during compression")
					END;
					Texts.WriteLn(W); Texts.Append(Oberon.Log, W.buf);
					IF ErrorStop & (res # Zip.Ok) THEN end := MIN(LONGINT) END
				END
			END
		| Zip.FileError: Texts.WriteString(W, " not found"); Texts.WriteLn(W)
		| Zip.NotZipArchiveError: Texts.WriteString(W, " is not a valid zip-archive"); Texts.WriteLn(W)
		END;
		Texts.Append(Oberon.Log, W.buf)
	END
END Add;

(** Deletes the selected entries from the selected zip-archive.
	ZipTool.Delete (^ | ZipFile (^ | {Entry})) **)
PROCEDURE Delete*;
VAR
	S: Texts.Scanner; T: Texts.Text; beg, end, time: LONGINT;
	arc: Zip.Archive;
	ent: Zip.Entry;
	res: WORD;
BEGIN
	Texts.WriteString(W, "ZipTool.Delete ");
	T := Oberon.Par.text;
	Texts.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos); Texts.Scan(S);
	IF (S.class = Texts.Char) & (S.c = "^") THEN
		Oberon.GetSelection(T, beg, end, time);
		IF time # -1 THEN Texts.OpenScanner(S, T, beg); Texts.Scan(S) END;
	END;
	IF S.class IN {Texts.Name, Texts.String} THEN
		arc := Zip.OpenArchive(S.s, res);
		Texts.WriteString(W, S.s); Texts.Append(Oberon.Log, W.buf);
		CASE res OF
		| Zip.Ok:
			Texts.WriteLn(W);
			Texts.Scan(S);
			IF (S.class = Texts.Char) & (S.c = "^") THEN
				Oberon.GetSelection(T, beg, end, time);
				IF time # -1 THEN Texts.OpenScanner(S, T, beg); Texts.Scan(S) END;
			ELSE
				end := T.len
			END;
			WHILE (S.class IN {Texts.Name, Texts.String}) & (Texts.Pos(S) <= (end + S.len)) DO
				ent := Zip.GetEntry(arc, S.s, res);
				Texts.WriteString(W, " "); Texts.WriteString(W, S.s); Texts.Append(Oberon.Log, W.buf);
				CASE res OF
				| Zip.Ok:
					Zip.DeleteEntry(arc, ent, res);
					CASE res OF
					| Zip.Ok: Texts.WriteString(W, " deleted")
					ELSE	(* should not happen *)
					END
				| Zip.EntryNotFound: Texts.WriteString(W, " not found")
				ELSE	(* should not happen *)
				END;
				Texts.WriteLn(W); Texts.Append(Oberon.Log, W.buf);
				Texts.Scan(S);
				IF ErrorStop & (res # Zip.Ok) THEN end := MIN(LONGINT) END
			END
		| Zip.FileError: Texts.WriteString(W, " not found"); Texts.WriteLn(W)
		| Zip.NotZipArchiveError: Texts.WriteString(W, " is not a valid zip-archive"); Texts.WriteLn(W)
		END;
		Texts.Append(Oberon.Log, W.buf)
	END
END Delete;

BEGIN
	Texts.OpenWriter(W)
END ZipTool.
