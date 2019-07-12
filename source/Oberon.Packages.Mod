(* ETH Oberon, Copyright 2001 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

MODULE Packages IN Oberon; (** portable / source: Native.Packages.Mod *)	(* ejz  *)
	IMPORT FileDir, Files, BTrees, Objects, Dates, Strings, Display, Texts, Oberon, Compress,
		Compiler, Gadgets, Documents, Watson, Attributes, Links;

(**
	Module Packages is used to build (see: Packages.Build) and install (see: Packages.Install) application
	packages. Application packages are compressed files containing application files together with installation
	instructions and version information.

	Package file format: DocHead Compress ( PackHead { Data | URL | Cmd } ) .
		DocHead = Documents.Id "Packages.NewDoc" (INTEGER) 0 0 0 0 Attachments .
		PackHead = HeadTag Resource gen options .
		Data = DataTag Resource len data .
		URL = URLTag Resource url options .
		Cmd = CmdTag Resource parstring1 parstring2 .
		Resource = name len time date minor major .
*)

	CONST
		HeadTag = 0; DataTag = 1; URLTag = 2; CmdTag = 3;
		VerNewResource = 0; VerSameVersion = 1;
		VerNewBuild = 2; VerOldBuild = 3;
		VerNewMajorVersion = 4; VerOldMajorVersion = 5;
		VerNewMinorVersion = 6; VerOldMinorVersion = 7;
		VerError = 8;

	TYPE
		ResourcePtr = POINTER TO Resource;
		Resource = RECORD
			name: FileDir.FileName;
			time, date, pos: LONGINT;
			minor, major: INTEGER;
			next: ResourcePtr
		END;

		Package = RECORD (Resource)
			R: Files.Rider;
			gen, options: FileDir.FileName
		END;

		(** 0: Done, 1: NetworkErr, 2: UserBreak, 3: OtherError, -1: Transfering (see also PlugIns.Mod) *)
		GetURLProc* = PROCEDURE (context: Objects.Object; CONST url: ARRAY OF CHAR): LONGINT;

	VAR
		W: Texts.Writer;
		index: BTrees.Tree;
		useCrypt: BOOLEAN;

	PROCEDURE OpenScanner(VAR T: Texts.Text; VAR S: Texts.Scanner);
		VAR crypt, key: ARRAY 64 OF CHAR;  beg, end, time: LONGINT;
	BEGIN
		Texts.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos);
		Texts.Scan(S);
		IF (S.class = Texts.Char) & (S.c = Oberon.OptionChar) THEN (* encryption *)
			Texts.Scan(S); ASSERT((S.class = Texts.Name) & (CAP(S.s[0]) = "C"));
			Texts.Scan(S); ASSERT(S.class = Texts.Name); COPY(S.s, crypt);
			Texts.Scan(S); ASSERT(S.class IN {Texts.Name, Texts.String}); COPY(S.s, key);
			Compress.InstallCrypt(crypt, key);
			Texts.Scan(S); useCrypt := TRUE
		ELSE
			useCrypt := FALSE
		END;
		IF S.class = Texts.Char THEN
			T := NIL; beg := 0;
			IF S.c = "^" THEN
				Oberon.GetSelection(T, beg, end, time)
			ELSIF S.c = "*" THEN
				T := Oberon.MarkedText()
			END;
			IF T # NIL THEN
				Texts.OpenScanner(S, T, beg); Texts.Scan(S)
			ELSE
				S.class := Texts.Inval; S.eot := TRUE
			END
		ELSE
			T := Oberon.Par.text
		END
	END OpenScanner;

	PROCEDURE WriteResource(VAR R: Files.Rider; VAR res: Resource; tag: INTEGER; dLen: SIZE);
	BEGIN
		Files.WriteInt(R, tag); Files.WriteString(R, res.name); Files.WriteLInt(R, dLen(LONGINT)+12);
		Files.WriteLInt(R, res.time); Files.WriteLInt(R, res.date);
		Files.WriteInt(R, res.minor); Files.WriteInt(R, res.major)
	END WriteResource;

	PROCEDURE ClosePackage(VAR pack: Package);
		VAR F: Files.File; R: Files.Rider; h: Compress.Header; attr: Attributes.BoolAttr;
	BEGIN
		F := Files.Base(pack.R); h.length := Files.Length(F); Files.Set(pack.R, F, 0);
		F := Files.New(pack.name); Files.Set(R, F, 0);
		(* Document Head *)
		Files.WriteInt(R, Documents.Id);
		Files.WriteString(R, "Packages.NewDoc");
		Files.WriteInt(R, 0); Files.WriteInt(R, 0);
		Files.WriteInt(R, 0); Files.WriteInt(R, 0);
		h.extensions := {};
		IF useCrypt THEN
			INCL(h.extensions, Compress.encryption);
			NEW(attr); attr.next := NIL;
			attr.name := "Encryption"; attr.b := TRUE
		ELSE
			attr := NIL
		END;
		Documents.StoreAttachments(R, attr, NIL);
		Compress.CopyToArc(pack.R, R, h.length, h);
		Files.Register(F); Files.Set(pack.R, NIL, 0)
	END ClosePackage;

(** Builds new application package(s) from a package description. Syntax:
		packages = [ "\C" crypt key ] package { ";" package } "~" .
		package = "PACKAGE" name version gen [ "\" options ] { data | url | cmd } . options: "A"
		data = "DATA" name [ version ] [ ":=" file ] .
		url = "URL" name [ version ] [ "\" options ] [ ":=" url ] . options: "S"
		cmd = filecmd | "DEST" dir | "MSG" text | "SET" key ":=" value" .
		filecmd = ( "COMPILE" | "COPY" | "DEF" ) name . *)
	PROCEDURE Build*;
		VAR
			T: Texts.Text; S: Texts.Scanner; pos: LONGINT;
			pack: Package; err: BOOLEAN;
		PROCEDURE Error(CONST msg1, msg2: ARRAY OF CHAR);
		BEGIN
			IF ~err THEN
				Texts.WriteString(W, msg1); Texts.WriteString(W, msg2); Texts.WriteLn(W)
			END;
			err := TRUE
		END Error;
		PROCEDURE Scan;
		BEGIN
			pos := Texts.Pos(S); Texts.Scan(S)
		END Scan;
		PROCEDURE Version(VAR res: Resource);
		BEGIN
			IF S.class = Texts.Int THEN
				res.major := SHORT(S.i); res.minor := 0
			ELSIF S.class = Texts.Real THEN
				res.major := SHORT(ENTIER(S.x));
				res.minor := SHORT(ENTIER(100.0*(S.x-res.major)+0.5))
			ELSE
				Error("version expected", "")
			END;
			Scan()
		END Version;
		PROCEDURE Name(VAR name: ARRAY OF CHAR);
		BEGIN
			IF S.class = Texts.Name THEN
				COPY(S.s, name); Scan()
			ELSE
				Error("name expected", "")
			END
		END Name;
		PROCEDURE String(VAR str: ARRAY OF CHAR);
			VAR R: Texts.Reader; i: LONGINT;
		BEGIN
			IF S.class IN {Texts.Name, Texts.String} THEN
				COPY(S.s, str); Scan()
			ELSIF (S.class = Texts.Char) & (S.c = "'") THEN
				Texts.OpenReader(R, T, pos+1);
				i := 0; Texts.Read(R, str[i]);
				WHILE str[i] # "'" DO
					INC(i); Texts.Read(R, str[i])
				END;
				str[i] := 0X;
				Texts.OpenScanner(S, T, Texts.Pos(R));
				Scan()
			ELSE
				Error("string expected", "")
			END
		END String;
		PROCEDURE Equals;
		BEGIN
			IF (S.class = Texts.Char) & (S.c = ":") THEN
				Scan();
				IF (S.class = Texts.Char) & (S.c = "=") THEN
					Scan(); RETURN
				END
			END;
			Error(":= expected", "")
		END Equals;
		PROCEDURE ResHead(VAR res: Resource; VAR options, url: ARRAY OF CHAR);
		BEGIN
			Scan(); Name(res.name);
			IF S.class IN {Texts.Int, Texts.Real} THEN
				Version(res)
			ELSE
				res.minor := pack.minor; res.major := pack.major
			END;
			IF (S.class = Texts.Char) & (S.c = Oberon.OptionChar) THEN
				Scan(); Name(options)
			ELSE
				COPY("", options)
			END;
			IF (S.class = Texts.Char) & (S.c # "~") THEN
				Equals(); String(url)
			ELSE
				COPY(res.name, url)
			END
		END ResHead;
		PROCEDURE data;
			VAR
				res: Resource; file: FileDir.FileName;
				F: Files.File; R: Files.Rider; buf: ARRAY 1024 OF CHAR;
		BEGIN
			ResHead(res, buf, file);
			F := Files.Old(file);
			IF F # NIL THEN
				Files.GetDate(F, res.time, res.date);
				WriteResource(pack.R, res, DataTag, 4+Files.Length(F));
				Files.WriteLInt(pack.R, Files.Length(F));
				Files.Set(R, F, 0);
				Files.ReadBytes(R, buf, 1024);
				WHILE ~R.eof DO
					Files.WriteBytes(pack.R, buf, 1024);
					Files.ReadBytes(R, buf, 1024)
				END;
				Files.WriteBytes(pack.R, buf, 1024-R.res)
			ELSE
				Error("file not found ", file)
			END
		END data;
		PROCEDURE url;
			VAR res: Resource; options, url: FileDir.FileName;
		BEGIN
			ResHead(res, options, url);
			res.time := Dates.ToTime(0, 0, 0); res.date := Dates.ToDate(1980, 1, 1);
			WriteResource(pack.R, res, URLTag, Strings.Length(url)+1+Strings.Length(options)+1);
			Files.WriteString(pack.R, url); Files.WriteString(pack.R, options)
		END url;
		PROCEDURE cmd;
			VAR res: Resource; file, value: FileDir.FileName;
		BEGIN
			Name(res.name); value := "";
			IF res.name = "COMPILE" THEN
				WHILE ~err & (S.class = Texts.Char) & (S.c = Oberon.OptionChar) DO
					Scan(); Name(file); Strings.Append(value, file)
				END;
				Name(file)
			ELSIF (res.name = "COPY") OR (res.name = "DEF") THEN
				Name(file)
			ELSIF (res.name = "DEST") OR (res.name = "MSG") THEN
				String(file)
			ELSIF res.name = "SET" THEN
				String(file); Equals(); String(value)
			ELSE
				Error("unknown command ", res.name)
			END;
			WriteResource(pack.R, res, CmdTag, Strings.Length(file)+1+Strings.Length(value)+1);
			Files.WriteString(pack.R, file); Files.WriteString(pack.R, value)
		END cmd;
		PROCEDURE package;
		BEGIN
			Scan();
			Name(pack.name); Texts.WriteString(W, pack.name);
			Version(pack); String(pack.gen);
			IF (S.class = Texts.Char) & (S.c = Oberon.OptionChar) THEN
				Scan(); String(pack.options)
			ELSE
				pack.options := ""
			END;
			Files.Set(pack.R, Files.New(""), 0);
			Oberon.GetClock(pack.time, pack.date);
			WriteResource(pack.R, pack, HeadTag, Strings.Length(pack.gen)+1+Strings.Length(pack.options)+1);
			Files.WriteString(pack.R, pack.gen); Files.WriteString(pack.R, pack.options);
			LOOP
				IF ~err & (S.class = Texts.Name) THEN
					IF S.s = "DATA" THEN
						data()
					ELSIF S.s = "URL" THEN
						url()
					ELSIF S.s = "PACKAGE" THEN
						EXIT
					ELSE
						cmd()
					END
				ELSE
					EXIT
				END
			END;
			IF ~err THEN
				ClosePackage(pack);
				Texts.WriteString(W, " done"); Texts.WriteLn(W); Texts.Append(Oberon.Log, W.buf)
			END
		END package;
	BEGIN
		OpenScanner(T, S); err := FALSE;
		WHILE ~err & (S.class = Texts.Name) & (S.s = "PACKAGE") DO
			package()
		END;
		IF useCrypt THEN Compress.ClearCrypt(); useCrypt := FALSE END;
		Texts.Append(Oberon.Log, W.buf)
	END Build;

	PROCEDURE ReadResource(VAR R: Files.Rider; VAR res: Resource; VAR tag: INTEGER; VAR dLen: LONGINT);
		VAR p: LONGINT;
	BEGIN
		p := Files.Pos(R);
		Files.ReadInt(R, tag); Files.ReadString(R, res.name); Files.ReadLInt(R, dLen);
		dLen := dLen + Files.Pos(R)-p;
		Files.ReadLInt(R, res.time); Files.ReadLInt(R, res.date);
		Files.ReadInt(R, res.minor); Files.ReadInt(R, res.major)
	END ReadResource;

	PROCEDURE FindResource(CONST name: ARRAY OF CHAR; VAR res: Resource);
		VAR R: Files.Rider; org: LONGINT; err: INTEGER;
	BEGIN
		BTrees.SearchStr(index, name, org, err);
		IF err = BTrees.Done THEN
			Files.Set(R, BTrees.Base(index), org);
			Files.ReadInt(R, res.major); Files.ReadInt(R, res.minor);
			Files.ReadLInt(R, res.date); Files.ReadLInt(R, res.time);
			COPY(name, res.name)
		ELSE
			res.name := ""
		END
	END FindResource;

	PROCEDURE RegisterResource(VAR res: Resource; package: ARRAY OF CHAR);
		VAR R: Files.Rider; org: LONGINT; err: INTEGER;
	BEGIN
		BTrees.SearchStr(index, res.name, org, err);
		IF err # BTrees.Done THEN
			BTrees.InsertStr(index, res.name, -1, err);
			org := Files.Length(BTrees.Base(index));
			BTrees.InsertStr(index, res.name, org, err);
			ASSERT(err = BTrees.EntryChanged);
			BTrees.Flush(index)
		END;
		Files.Set(R, BTrees.Base(index), org);
		Files.WriteInt(R, res.major); Files.WriteInt(R, res.minor);
		Files.WriteLInt(R, res.date); Files.WriteLInt(R, res.time);
		Files.WriteBytes(R, package, LEN(package)(LONGINT));
		Files.Close(BTrees.Base(index))
	END RegisterResource;

	PROCEDURE CompareVersion(VAR old, new: Resource): LONGINT;
	BEGIN
		IF new.major > old.major THEN
			RETURN VerNewMajorVersion
		ELSIF new.major < old.major THEN
			RETURN VerOldMajorVersion
		ELSIF new.minor > old.minor THEN
			RETURN VerNewMinorVersion
		ELSIF new.minor < old.minor THEN
			RETURN VerOldMinorVersion
		ELSIF new.date > old.date THEN
			RETURN VerNewBuild
		ELSIF new.date = old.date THEN
			IF new.time > old.time THEN
				RETURN VerNewBuild
			ELSIF new.time < old.time THEN
				RETURN VerOldBuild
			ELSE
				RETURN VerSameVersion
			END
		ELSE
			RETURN VerOldBuild
		END
	END CompareVersion;

	PROCEDURE CheckVersion(VAR res: Resource; CONST options: ARRAY OF CHAR; file: BOOLEAN): LONGINT;
		VAR ver: Resource; v: LONGINT;
	BEGIN
		FindResource(res.name, ver);
		IF ver.name = res.name THEN
			v := CompareVersion(ver, res);
			IF (v IN {VerSameVersion, VerOldBuild, VerOldMinorVersion}) & (options = "A") THEN
				RETURN VerNewBuild
			ELSE
				RETURN v
			END
		ELSIF file & ~(options = "A") & (Files.Old(res.name) # NIL) THEN
			RETURN VerError
		ELSE
			RETURN VerNewResource
		END
	END CheckVersion;

	PROCEDURE Cleanup;

	END Cleanup;

	PROCEDURE SystemName(VAR name: ARRAY OF CHAR);
		VAR prefixes: FileDir.FileName;
	BEGIN
		prefixes := "Native."; Strings.Append(prefixes, name);
		COPY(prefixes, name)
	END SystemName;

	PROCEDURE ReadDocHeader(VAR R: Files.Rider; VAR ch: CHAR);
		VAR len: LONGINT; x, y, w, h: INTEGER; name: ARRAY 32 OF CHAR;
	BEGIN
		Files.Read(R, ch);
		Files.ReadString(R, name);
		Files.ReadInt(R, x); Files.ReadInt(R, y);
		Files.ReadInt(R, w); Files.ReadInt(R, h);
		Files.Read(R, ch);
		IF ch = 0F7X THEN	(* skip meta info *)
			Files.Read(R, ch); ASSERT(ch = 08X);
			Files.ReadLInt(R, len);
			Files.Set(R, Files.Base(R), Files.Pos(R) + len);
			Files.Read(R, ch)
		END
	END ReadDocHeader;

	PROCEDURE OpenPackage(VAR pack: Package; F: Files.File): BOOLEAN;
		VAR
			R: Files.Rider; h: Compress.Header; i: INTEGER;
			attr, attrs: Attributes.Attr; links: Links.Link; ch: CHAR;
	BEGIN
		Files.Set(pack.R, F, 0); Files.ReadInt(pack.R, i);
		IF i # Documents.Id THEN COPY("not a document", pack.gen); RETURN FALSE END;
		Files.ReadString(pack.R, pack.gen);
		Files.ReadInt(pack.R, i); Files.ReadInt(pack.R, i);
		Files.ReadInt(pack.R, i); Files.ReadInt(pack.R, i);
		Files.Read(pack.R, ch);
		IF ch = 0F7X THEN	(* skip meta info *)
			Documents.LoadAttachments(pack.R, attrs, links);
			attr := Attributes.FindAttr("Encryption", attrs);
			IF (attr # NIL) & (attr IS Attributes.BoolAttr) THEN
				useCrypt := attr(Attributes.BoolAttr).b
			END
		END;
		h.extensions := {}; h.length := Files.Length(F)-Files.Pos(pack.R);
		IF useCrypt THEN INCL(h.extensions, Compress.encryption) END;
		F := Files.New(""); Files.Set(R, F, 0);
		Compress.CopyFromArc(pack.R, R, h, i);
		IF i # Compress.Done THEN COPY("error in file", pack.gen); RETURN FALSE END;
		Files.Set(pack.R, F, 0);
		RETURN TRUE
	END OpenPackage;

	(** Install the application package F. getURL (passing context as first parameter) is called when additional files
		are needed by install. Return values:
		0: Installation susceeded, gen containes the generator for the default object if any.
		1: Installation could not be finished, since some getURL requests are still pending. Retry install again when all
			getURL request are resolved.
		2: F is not a valid package file.
		3: A version conflict occurd while installing the package. See gen for the name of the conflicting resource.
		4: Installation failed for some other reason. *)
	PROCEDURE install*(F: Files.File; VAR gen: ARRAY OF CHAR; context: Objects.Object; getURL: GetURLProc): LONGINT;
		VAR
			options: FileDir.FileName;
			pack: Package; resl, res: ResourcePtr;
			R: Files.Rider; regT: Texts.Text;
			p, l, v, urls: LONGINT; i: INTEGER;
			ch: CHAR; restore: BOOLEAN;
		PROCEDURE StoreState;
		BEGIN
			restore := TRUE
		END StoreState;
		PROCEDURE RestoreState;
		BEGIN
			IF restore THEN
				Texts.Append(Oberon.Log, W.buf);
				restore := FALSE
			END
		END RestoreState;
		PROCEDURE Error(CONST msg: ARRAY OF CHAR);
		BEGIN
			COPY(msg, gen); RestoreState();
			Cleanup()
		END Error;
		PROCEDURE CopyData(VAR from: Files.Rider; to: Files.File; len: LONGINT);
			VAR R: Files.Rider; buf: ARRAY 1024 OF CHAR;
		BEGIN
			Files.Set(R, to, 0);
			Files.ReadBytes(from, buf, 1024);
			WHILE len >= 1024 DO
				Files.WriteBytes(R, buf, 1024); Files.ReadBytes(from, buf, 1024); DEC(len, 1024)
			END;
			Files.WriteBytes(R, buf, len)
		END CopyData;
		PROCEDURE Backup(VAR res: Resource);
			VAR bak: FileDir.FileName; err: INTEGER;
		BEGIN
			IF Files.Old(res.name) # NIL THEN
				COPY(res.name, bak); Strings.Append(bak, ".Bak");
				Files.Rename(res.name, bak, err)
			END
		END Backup;
		PROCEDURE DoCmd(VAR cmd: Resource): BOOLEAN;
			VAR
				key, file, value: FileDir.FileName;
				i, j, v: LONGINT; res: ResourcePtr; cRes: Resource;
				F2, F3: Files.File; R, R2: Files.Rider; ok: BOOLEAN;
				T: Texts.Text; r: Texts.Reader; re: INTEGER;
		BEGIN
			Files.Set(R, F, cmd.pos); Files.ReadString(R, file); Files.ReadString(R, value);
			IF cmd.name # "MSG" THEN
				Texts.WriteString(W, cmd.name); Texts.Write(W, 09X);
				Texts.WriteString(W, file); Texts.Write(W, 09X);
				Texts.WriteString(W, value); Texts.WriteLn(W);
				Texts.Append(Oberon.Log, W.buf)
			END;
			res := resl;
			WHILE (res # NIL) & (res.name # file) DO
				res := res.next
			END;
			IF (res # NIL) & (cmd.name = "COMPILE") THEN
				cRes := res^; Strings.ChangeSuffix(cRes.name, "Obj"); (* should be same as resulting .Obj file *)
				v := CheckVersion(cRes, pack.options, TRUE);
				IF v IN {VerNewResource, VerNewBuild, VerNewMinorVersion} THEN
					Backup(cRes);
					Files.Set(R, F, res.pos); Files.ReadLInt(R, i);
					F2 := Files.New(""); CopyData(R, F2, i);
					Files.Set(R2, F2, 0); Files.Read(R2, ch);
					IF ch = 0F7X THEN ReadDocHeader(R2, ch) END;
					IF ch = Texts.TextBlockId THEN
						NEW(T); Texts.Open(T, ""); Texts.Load(T, F2, Files.Pos(R2), i);
						Texts.OpenReader(r, T, 0); ok := TRUE;
						Compiler.Module(r, "", value, 0, Oberon.Log, ok);
						IF ~ok THEN
							i := 0; j := 0;
							WHILE cRes.name[i] # 0X DO
								IF cRes.name[i] = FileDir.PathChar THEN
									j := 0
								ELSE
									cRes.name[j] := cRes.name[i]; INC(j)
								END;
								INC(i)
							END;
							cRes.name[j] := 0X;
							RegisterResource(cRes, pack.name);
							RETURN TRUE
						END
					END;
					COPY(res.name, gen); RETURN FALSE
				ELSIF ~(v IN {VerSameVersion, VerOldBuild, VerOldMinorVersion}) THEN
					COPY(cRes.name, gen); RETURN FALSE
				END
			ELSIF (res # NIL) & (cmd.name = "COPY") THEN
				v := CheckVersion(res^, pack.options, TRUE);
				IF v IN {VerNewResource, VerNewBuild, VerNewMinorVersion} THEN
					Backup(cRes);
					Files.Set(R, F, res.pos); Files.ReadLInt(R, i);
					F2 := Files.New(file); CopyData(R, F2, i);
					Files.Register(F2);
					RegisterResource(res^, pack.name)
				ELSIF ~(v IN {VerSameVersion, VerOldBuild, VerOldMinorVersion}) THEN
					COPY(res.name, gen); RETURN FALSE
				END
			ELSIF (res # NIL) & (cmd.name = "DEF") THEN
				Strings.GetSuffix(file, value); cRes := res^;
				Files.Set(R, F, res.pos); Files.ReadLInt(R, i);
				file := "Temp.Def"; F2 := Files.New(file);
				CopyData(R, F2, i);
				IF value # "Def" THEN
					Files.Register(F2);
					NEW(T); Texts.Open(T, "");
					Watson.MakeDef(file, T);
					COPY(file, cRes.name); Strings.Append(cRes.name, ".Def");
					F2 := Files.New(""); Texts.Store(T, F2, 0, i)
				END;
				v := CheckVersion(cRes, pack.options, FALSE);
				IF v IN {VerNewResource, VerNewBuild, VerNewMinorVersion} THEN
					file := "Definitions.Arc"; F3 := Files.Old(file);
					IF F3 # NIL THEN
						Files.GetName(F3, file)
					ELSE
						Compress.CreateArchive(file, re); ASSERT(re = Compress.Done)
					END;
					Compress.DeleteFile(file, cRes.name, re);
					Files.Set(R2, F2, 0);
					Compress.AddFile(file, cRes.name, R2, Files.Length(F2), re);
					IF re = Compress.Done THEN
						RegisterResource(cRes, pack.name)
					ELSE
						RETURN FALSE
					END
				ELSIF ~(v IN {VerSameVersion, VerOldBuild, VerOldMinorVersion}) THEN
					COPY(cRes.name, gen); RETURN FALSE
				END
			ELSIF cmd.name = "DEST" THEN
				(* FileDir.ChangeDirectory(workDir, ok); ASSERT(ok);
				Strings.Upper(file, file); i := 0;
				WHILE (i < NoPaths) & (paths[i].name # file) DO
					INC(i)
				END;
				IF (i < NoPaths) & (paths[i].path # "") THEN
					FileDir.ChangeDirectory(paths[i].path, ok)
				ELSE
					FileDir.ChangeDirectory(file, ok)
				END;
				RETURN ok *)
			ELSIF cmd.name = "MSG" THEN
				Texts.SetColor(W, 1);
				Texts.WriteString(W, file); Texts.WriteLn(W); Texts.Append(Oberon.Log, W.buf);
				Texts.SetColor(W, Display.FG)
			ELSIF cmd.name = "SET" THEN
				i := 0; j := 0; v := -1;
				WHILE file[i] # 0X DO
					IF (*(file[i] = ".") OR*) (file[i] = "\") THEN (* allow dots in key name *)
						file[i] := "\"; j := 0; v := i
					ELSE
						key[j] := file[i]; INC(j)
					END;
					INC(i)
				END;
				key[j] := 0X; IF v > 0 THEN file[v] := 0X END;
				IF regT = NIL THEN
					NEW(regT); Texts.Open(regT, "");
					Texts.SetColor(W, 1);
					Texts.WriteString(W, "Add the following settings to the Oberon.Text.");
					Texts.WriteLn(W); Texts.WriteLn(W);
					Texts.SetColor(W, Display.FG)
				END;
				Texts.WriteString(W, file); Texts.Write(W, Strings.Tab);
				Texts.WriteString(W, key); Texts.WriteString(W, " = ");
				Texts.WriteString(W, value); Texts.WriteLn(W);
				Texts.Append(regT, W.buf);
				(* Registry.OberonPath(file, file);
				Registry.SetKeyValue(Registry.CurrentUser, file, key, value);
				RETURN Registry.res = Registry.Done *)
			ELSIF res = NIL THEN
				COPY(file, gen); RETURN FALSE
			ELSE
				COPY(cmd.name, gen); RETURN FALSE
			END;
			RETURN TRUE
		END DoCmd;
	BEGIN
		COPY("", gen); restore := FALSE; regT := NIL;
		IF ~OpenPackage(pack, F) THEN Error(pack.gen); RETURN 2 END;
(* Package Header *)
		F := Files.Base(pack.R);
		Files.Set(R, F, Files.Pos(pack.R)); p := 0;
		ReadResource(R, pack, i, l);
		IF i # HeadTag THEN Error("error in file"); RETURN 2 END;
		Files.ReadString(R, pack.gen); Files.ReadString(R, pack.options);
		v := CheckVersion(pack, "", FALSE);
		IF (v IN {VerNewResource, VerNewBuild, VerNewMinorVersion}) OR ((v IN {VerSameVersion, VerOldBuild, VerOldMinorVersion}) & (pack.options = "A")) THEN
(* URLs *)
			urls := 0; resl := NIL; NEW(res);
			WHILE ((p+l) < Files.Length(F)) DO
				p := p+l; Files.Set(R, F, p);
				ReadResource(R, res^, i, l);
				res.pos := Files.Pos(R);
				IF i = DataTag THEN
					res.next := resl; resl := res; NEW(res)
				ELSIF i = URLTag THEN
					Files.ReadString(R, res.name); Files.ReadString(R, options);
					IF options # "" THEN SystemName(res.name) END; (* \S *)
					v := CheckVersion(res^, "", FALSE);
					IF v IN {VerNewResource, VerNewBuild, VerNewMinorVersion} THEN
						v := getURL(context, res.name); INC(urls);
						IF v # 0 THEN Error(res.name); RETURN 4 END
					ELSIF ~(v IN {VerSameVersion, VerOldBuild, VerOldMinorVersion}) THEN
						Error(res.name); RETURN 3
					END
				END
			END;
			IF urls = 0 THEN
(* Install *)
				Files.Set(R, F, 0); p := 0;
				ReadResource(R, pack, i, l);
				Files.ReadString(R, pack.gen); Files.ReadString(R, pack.options);
				StoreState();
				WHILE ((p+l) < Files.Length(F)) DO
					p := p+l; Files.Set(R, F, p);
					ReadResource(R, res^, i, l);
					res.pos := Files.Pos(R);
					IF i IN {DataTag, URLTag} THEN
						(* done *)
					ELSIF i = CmdTag THEN
						IF ~DoCmd(res^) THEN Error(gen); RETURN 4 END
					ELSE
						Error(res.name); RETURN 2
					END
				END;
				RegisterResource(pack, ""); RestoreState();
				IF regT # NIL THEN
					Oberon.OpenText("Update Oberon.Text", regT, 512, 512)
				END
			ELSE
				RETURN 1
			END
		ELSIF ~(v IN {VerSameVersion, VerOldBuild, VerOldMinorVersion}) THEN
			Error(pack.name); RETURN 3
		END;
		COPY(pack.gen, gen); RETURN 0
	END install;

	(** Create an object using the generator returned by install . *)
	PROCEDURE CreateObject*(gen: ARRAY OF CHAR; VAR err: ARRAY OF CHAR): Objects.Object;
		VAR
			D: Documents.Document; obj: Objects.Object;
			prefix: ARRAY 8 OF CHAR; i, j: LONGINT;
	BEGIN
		obj := NIL; D := NIL; i := 0;
		WHILE (i < 8) & (gen[i] # ":") DO
			prefix[i] := gen[i]; INC(i)
		END;
		IF i < 8 THEN
			prefix[i] := 0X; INC(i); j := 0;
			WHILE gen[i] # 0X DO
				gen[j] := gen[i]; INC(i); INC(j)
			END;
			gen[j] := 0X;
			IF prefix = "obj" THEN
				obj := Gadgets.CreateObject(gen)
			ELSIF prefix = "doc" THEN
				IF gen[0] = "(" THEN
					j := 0; i := 1;
					WHILE (gen[i] # 0X) & (gen[i] # ")") DO
						gen[j] := gen[i]; INC(i); INC(j)
					END;
					gen[j] := 0X;
					obj := Gadgets.CreateObject(gen);
					IF (obj # NIL) & (obj IS Documents.Document) THEN
						D := obj(Documents.Document); D.Load(D)
					END
				ELSE
					D := Documents.Open(gen)
				END;
				IF (D # NIL) & (D.dsc # NIL) THEN obj := D END
			ELSIF prefix = "lib" THEN
				obj := Gadgets.FindPublicObj(gen) (* ref, deep, shallow ? *)
			ELSE
				COPY(prefix, err); Strings.Append(err, ": invalid generator prefix")
			END;
			IF obj # NIL THEN
				COPY("", err); RETURN obj
			ELSE
				COPY(gen, err); Strings.Append(err, ": loading failed")
			END
		ELSE
			COPY(gen, err); Strings.Append(err, ": invalid generator")
		END;
		RETURN NIL
	END CreateObject;

(* Implementation of an Application installer for local package files. *)

	PROCEDURE GetURL(context: Objects.Object; CONST purl: ARRAY OF CHAR): LONGINT;
		VAR F: Files.File; gen: FileDir.FileName; res: WORD; url: POINTER TO ARRAY OF CHAR;
	BEGIN
		NEW(url,LEN(purl));
		COPY (purl,url^);
		F := Files.Old(url^);
		IF F = NIL THEN
			SystemName(url^); F := Files.Old(url^)
		END;
		IF F # NIL THEN
			Texts.WriteString(W, "installing "); Texts.WriteString(W, url^); Texts.WriteLn(W);
			REPEAT
				res := install(F, gen, context, GetURL)
			UNTIL res # 1;
			Texts.WriteString(W, url^);
			IF res # 0 THEN
				Texts.Write(W, 09X);
				Texts.WriteString(W, gen); Texts.WriteString(W, " (");
				Texts.WriteInt(W, res, 0); Texts.Write(W, ")"); res := 3
			ELSE
				Texts.WriteString(W, " done"); res := 0
			END
		ELSE
			Texts.WriteString(W, url^); Texts.WriteString(W, " not found"); res := 1
		END;
		Texts.WriteLn(W); Texts.Append(Oberon.Log, W.buf);
		RETURN res
	END GetURL;

	(** Install packages available in your Oberon directories. For network installation of packages use
		HTMLPlugIns.Install. *)
	PROCEDURE Install*;
		VAR T: Texts.Text; S: Texts.Scanner; res: WORD;
	BEGIN
		OpenScanner(T, S); res := 0;
		WHILE (S.class IN {Texts.Name, Texts.String}) & (res = 0) DO
			res := GetURL(NIL, S.s); Texts.Scan(S)
		END;
		IF useCrypt THEN Compress.ClearCrypt(); useCrypt := FALSE  END
	END Install;

	PROCEDURE Load(D: Documents.Document);
		VAR F: Files.File; obj: Objects.Object; gen, err: FileDir.FileName; res: WORD;
	BEGIN
		D.dsc := NIL;
		F := Files.Old(D.name);
		REPEAT
			res := install(F, gen, NIL, GetURL)
		UNTIL res # 1;
		IF res = 0 THEN
			obj := CreateObject(gen, err);
			IF obj # NIL THEN
				IF obj IS Documents.Document THEN
					D^ := obj(Documents.Document)^
				ELSIF obj IS Display.Frame THEN
					WITH obj: Display.Frame DO
						D.dsc := obj; D.W := obj.W; D.H := obj.H
					END
				ELSE
					Texts.WriteString(W, "not a Frame"); Texts.WriteLn(W); Texts.Append(Oberon.Log, W.buf)
				END
			ELSE
				Texts.WriteString(W, err); Texts.WriteLn(W); Texts.Append(Oberon.Log, W.buf)
			END
		ELSE
			(* error reported by GetURL *)
		END
	END Load;

	PROCEDURE NewDoc*;
		VAR D: Documents.Document;
	BEGIN
		NEW(D); D.Load := Load; D.Store := NIL; D.handle := Documents.Handler;
		Objects.NewObj := D
	END NewDoc;

	PROCEDURE WriteRes(VAR W: Texts.Writer; VAR res: Resource);
	BEGIN
		Texts.WriteString(W, res.name); Texts.Write(W, " ");
		Texts.WriteInt(W, res.major, 0); Texts.Write(W, "."); Texts.WriteInt(W, res.minor, 0);
		Texts.WriteString(W, " /"); Texts.WriteDate(W, res.time, res.date)
	END WriteRes;

	PROCEDURE Directory*;
		VAR
			T: Texts.Text; S: Texts.Scanner;
			F: Files.File; R: Files.Rider;
			pack: Package; res: Resource;
			options, file, value: FileDir.FileName;
			p, l: LONGINT; i: INTEGER;
	BEGIN
		OpenScanner(T, S);
		IF S.class IN {Texts.Name, Texts.String} THEN
			F := Files.Old(S.s);
			IF F # NIL THEN
				IF OpenPackage(pack, F) THEN
					F := Files.Base(pack.R); Files.Set(R, F, Files.Pos(pack.R));
					ReadResource(R, pack, i, l); p := 0;
					ASSERT(i = HeadTag);
					Files.ReadString(R, pack.gen); Files.ReadString(R, pack.options);
					Texts.WriteString(W, "PACKAGE "); WriteRes(W, pack);
					Texts.WriteString(W, ' "'); Texts.WriteString(W, pack.gen); Texts.Write(W, '"');
					IF pack.options # "" THEN
						Texts.WriteString(W, " \"); Texts.WriteString(W, pack.options)
					END;
					Texts.WriteLn(W);
					WHILE ((p+l) < Files.Length(F)) DO
						p := p+l; Files.Set(R, F, p);
						ReadResource(R, res, i, l);
						Texts.Write(W, 09X);
						IF i = DataTag THEN
							Texts.WriteString(W, "DATA "); WriteRes(W, res)
						ELSIF i = URLTag THEN
							Files.ReadString(R, file); Files.ReadString(R, options);
							Texts.WriteString(W, "URL "); WriteRes(W, res);
							IF file # res.name THEN
								Texts.WriteString(W, " := "); Texts.WriteString(W, file)
							END;
							IF options # "" THEN
								Texts.WriteString(W, " \"); Texts.WriteString(W, options)
							END
						ELSIF i = CmdTag THEN
							Files.ReadString(R, file); Files.ReadString(R, value);
							Texts.WriteString(W, res.name); Texts.Write(W, " ");
							Texts.WriteString(W, file);
							IF value # "" THEN
								Texts.Write(W, " "); Texts.WriteString(W, value)
							END
						ELSE
							HALT(99)
						END;
						Texts.WriteLn(W)
					END
				ELSE
					Texts.WriteString(W, S.s); Texts.WriteString(W, pack.gen)
				END
			ELSE
				Texts.WriteString(W, S.s); Texts.WriteString(W, " not found")
			END;
			Texts.WriteLn(W); Texts.Append(Oberon.Log, W.buf)
		END;
		IF useCrypt THEN Compress.ClearCrypt(); useCrypt := FALSE END
	END Directory;

	PROCEDURE Init;
		VAR F: Files.File;
	BEGIN
		F := Files.Old("Packages.Index");
		IF F # NIL THEN
			index := BTrees.Old(F, 0)
		ELSE
			F := Files.New("Packages.Index");
			index := BTrees.NewStr(F, 0, 32);
			BTrees.Flush(index);
			Files.Register(F)
		END
	END Init;

BEGIN
	Texts.OpenWriter(W); Init()
END Packages.
