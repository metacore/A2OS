MODULE ZipFS; (** AUTHOR "ejz"; PURPOSE "mount a zipped file as a file-system"; *)
	IMPORT Modules, Streams, Files, Unzip, Dates;

	TYPE
		FileSystem = OBJECT (Files.FileSystem)
			VAR zip: Unzip.ZipFile;

			PROCEDURE &Init*(zip: Unzip.ZipFile);
			BEGIN
				SELF.zip := zip
			END Init;

			PROCEDURE Old0*(name: ARRAY OF CHAR): Files.File;
				VAR E: Unzip.Entry; key, res: LONGINT; F: File; F0: Files.File; W: Files.Writer;
			BEGIN {EXCLUSIVE}
				key := 0;
				E := zip.GetFirst();
				WHILE E # NIL DO
					INC(key);
					IF E.name^ = name THEN
						F0 := localFS.New0("");
						Files.OpenWriter(W, F0, 0);
						zip.Extract(E, W, res);
						W.Update();
						NEW(F);
						F.fs := SELF; F.key := key; F.E := E; F.F := F0;
						RETURN F
					END;
					E := zip.GetNext(E)
				END;
				RETURN NIL
			END Old0;

			PROCEDURE Enumerate0*(mask: ARRAY OF CHAR; flags: SET; enum: Files.Enumerator);
				VAR E: Unzip.Entry; name: Files.FileName; d, t: LONGINT;
			BEGIN {EXCLUSIVE}
				E := zip.GetFirst();
				WHILE E # NIL DO
					IF Match(mask, E.name^) THEN
						Files.JoinName(prefix, E.name^, name);
						IF Files.EnumTime IN flags THEN
							Dates.DateTimeToOberon(E.td, d, t)
						END;
						enum.PutEntry(name, {}, t, d, E.size)
					END;
					E := zip.GetNext(E)
				END
			END Enumerate0;

			PROCEDURE FileKey*(name: ARRAY OF CHAR): LONGINT;
				VAR E: Unzip.Entry; key: LONGINT;
			BEGIN {EXCLUSIVE}
				key := 0;
				E := zip.GetFirst();
				WHILE E # NIL DO
					INC(key);
					IF E.name^ = name THEN RETURN key END;
					E := zip.GetNext(E)
				END;
				RETURN 0
			END FileKey;

			PROCEDURE Finalize*;
			BEGIN {EXCLUSIVE}
				Finalize^()
			END Finalize;

		END FileSystem;

		File = OBJECT (Files.File)
			VAR F: Files.File; E: Unzip.Entry;

			PROCEDURE Set*(VAR r: Files.Rider; pos: LONGINT);
			BEGIN
				F.Set(r, pos); r.file := SELF
			END Set;

			PROCEDURE Pos*(VAR r: Files.Rider): LONGINT;
			BEGIN
				RETURN F.Pos(r)
			END Pos;

			PROCEDURE Read*(VAR r: Files.Rider; VAR x: CHAR);
			BEGIN
				F.Read(r, x)
			END Read;

			PROCEDURE ReadBytes*(VAR r: Files.Rider; VAR x: ARRAY OF CHAR; ofs, len: LONGINT);
			BEGIN
				F.ReadBytes(r, x, ofs, len)
			END ReadBytes;

			PROCEDURE Length*(): LONGINT;
			BEGIN
				RETURN F.Length()
			END Length;

			PROCEDURE GetDate*(VAR t, d: LONGINT);
			BEGIN
				Dates.DateTimeToOberon(E.td, d, t)
			END GetDate;

			PROCEDURE GetName*(VAR name: ARRAY OF CHAR);
			BEGIN
				Files.JoinName(fs.prefix, E.name^, name)
			END GetName;

			PROCEDURE Update*;
			BEGIN
				F.Update END
			Update;

		END File;

	VAR
		localFS: Files.FileSystem;

	(* Match - check if pattern matches file name; copied from DiskFS.Match and MatchPrefix *)
	PROCEDURE Match(pat, name: ARRAY OF CHAR): BOOLEAN;
		VAR pos, i0, i1, j0, j1: LONGINT; f: BOOLEAN;
	BEGIN
		f := TRUE;
		LOOP
			IF pat[pos] = 0X THEN
				pos := -1; EXIT
			ELSIF pat[pos] = "*" THEN
				IF pat[pos+1] = 0X THEN pos := -1 END;
				EXIT
			ELSIF pat[pos] # name[pos] THEN
				f := FALSE; EXIT
			END;
			INC(pos)
		END;
		IF pos # -1 THEN
			i0 := pos; j0 := pos;
			LOOP
				IF pat[i0] = "*" THEN
					INC(i0);
					IF pat[i0] = 0X THEN EXIT END
				ELSE
					IF name[j0] # 0X THEN f := FALSE END;
					EXIT
				END;
				f := FALSE;
				LOOP
					IF name[j0] = 0X THEN EXIT END;
					i1 := i0; j1 := j0;
					LOOP
						IF (pat[i1] = 0X) OR (pat[i1] = "*") THEN f := TRUE; EXIT END;
						IF pat[i1] # name[j1] THEN EXIT END;
						INC(i1); INC(j1)
					END;
					IF f THEN j0 := j1; i0 := i1; EXIT END;
					INC(j0)
				END;
				IF ~f THEN EXIT END
			END
		END;
		RETURN f & (name[0] # 0X)
	END Match;

	PROCEDURE NewFS*(context : Files.Parameters);
	VAR
		name: Files.FileName;
		F: Files.File; zip: Unzip.ZipFile; fs: FileSystem; res: LONGINT;
	BEGIN
		IF (Files.This(context.prefix) = NIL) THEN
			context.arg.SkipWhitespace; context.arg.String(name);
			F := Files.Old(name);
			IF F # NIL THEN
				NEW(zip, F, res);
				IF res = Streams.Ok THEN
					NEW(fs, zip);
					Files.Add(fs, context.prefix)
				ELSE
					context.error.String("ZipFS: "); context.error.String(name); context.error.String(" not a valid zip file");
					context.error.Ln;
				END
			ELSE
				context.error.String("ZipFS: "); context.error.String(name); context.error.String(" not found");
				context.error.Ln;
			END
		ELSE
			context.error.String("ZipFS: "); context.error.String(context.prefix); context.error.String(" already in use");
			context.error.Ln;
		END;
	END NewFS;

	PROCEDURE Finalization;
		VAR ft: Files.FileSystemTable; i: LONGINT;
	BEGIN
		IF Modules.shutdown = Modules.None THEN
			Files.GetList(ft);
			IF ft # NIL THEN
				FOR i := 0 TO LEN(ft^)-1 DO
					IF ft[i] IS FileSystem THEN Files.Remove(ft[i]) END
				END
			END
		END
	END Finalization;

	PROCEDURE Init;
		VAR fs: Files.FileSystemTable; i: LONGINT;
	BEGIN
		i := 0;
		Files.GetList(fs);
		WHILE (i < LEN(fs)) & ((fs[i].vol = NIL) OR (Files.ReadOnly IN fs[i].vol.flags)) DO
			INC(i)	(* find a writable file system *)
		END;
		IF (i < LEN(fs)) THEN localFS := fs[i] END;
		Modules.InstallTermHandler(Finalization)
	END Init;

BEGIN
	Init()
END ZipFS.

System.Free ZipFS ~

OFSTools.Mount Test ZipFS ARM.Backup.zip ~
OFSTools.Unmount Test

System.Directory Test:*\d
