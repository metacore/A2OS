(* ETH Oberon, Copyright 2001 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

MODULE ZipTool; (** AUTHOR "Stefan Walthert"; PURPOSE "Command line  front-end for Zip  **)

IMPORT
	Streams, Commands, Options, Files, Strings, Zip;

CONST
	EXTRACT = 1;
	OPEN = 2;

	Tab = 9X;

(* Get the suffix of str. The suffix is started by the last sepchar in str. If sepchar does not occur in str, str is returned *)
PROCEDURE GetSuffix(CONST str : ARRAY OF CHAR; VAR suf : ARRAY OF CHAR; sepchar: CHAR);
VAR i, j, len, sep: LONGINT;
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
PROCEDURE Append(VAR to: ARRAY OF CHAR; CONST this: ARRAY OF CHAR);
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

PROCEDURE OpenArchive(CONST archiveName : ARRAY OF CHAR; errorLog : Streams.Writer) : Zip.Archive;
VAR archive : Zip.Archive; res : WORD;
BEGIN
	archive := Zip.OpenArchive(archiveName, res);
	IF (res # Zip.Ok) THEN
		archive := NIL;
		errorLog.String("Could not open archive '"); errorLog.String(archiveName); errorLog.String("': ");
		Zip.ShowError(res, errorLog); errorLog.Ln; errorLog.Update;
	END;
	RETURN archive;
END OpenArchive;


(** Writes the directory of an archive. **)
PROCEDURE WriteDirectory*(out, error : Streams.Writer; CONST archiveName: ARRAY OF CHAR; details: BOOLEAN; VAR res: WORD);
VAR
	archive: Zip.Archive;
	entry: Zip.Entry;
	ratio : LONGINT;
BEGIN
	ASSERT(out # NIL);
	archive := OpenArchive(archiveName, error);
	IF (archive # NIL) THEN
		IF details THEN
			out.String("Name"); out.Char(Tab);  out.Char(Tab); out.String("Date"); out.Char(Tab); out.Char(Tab);
			out.String("Size"); out.Char(Tab); out.String("Ratio"); out.Char(Tab);
			out.String("Compressed"); out.Ln; out.Ln;
		END;
		entry := Zip.FirstEntry(archive);
		WHILE (entry # NIL) DO
			out.String(entry.name);
			IF details THEN
				out.Char(Tab); out.Char(Tab); out.Date(entry.time, entry.date);
				out.Char(Tab); out.Char(Tab); out.Int(entry.uncompSize, 0);
				ratio := ENTIER(((1 - entry.compSize / entry.uncompSize) * 100) + 0.5);
				IF ratio < 0 THEN ratio := 0 END;	(* ratio can not be less than zero *)
				out.Char(Tab); out.Int(ratio, 0); out.String("%");
				out.Char(Tab); out.Int(entry.compSize, 0);
			END;
			out.Ln;
			entry := Zip.NextEntry(entry)
		END;
		out.Ln;
		out.Int(archive.nofEntries, 0);
		IF (archive.nofEntries = 1) THEN out.String(" entry");
		ELSE out.String(" entries");
		END;
		out.Ln;
	END
END WriteDirectory;

(** Shows the content of the selected zip-archive in a new viewer.
	ZipTool.Directory [-d ] ZipFile ~
	Options:
	--details: If set, details of entries of selected zip-archive are shown  *)
PROCEDURE Directory*(context : Commands.Context);
VAR
	archiveName : Files.FileName;
	options : Options.Options;
	res: WORD;
BEGIN
	NEW(options);
	options.Add("d", "details", Options.Flag);

	IF options.Parse(context.arg, context.error) THEN
		context.arg.SkipWhitespace; context.arg.String(archiveName);
		WriteDirectory(context.out, context.error, archiveName, options.GetFlag("details"), res);
	END;
END Directory;

PROCEDURE DoExtract(
	action: LONGINT;
	archive: Zip.Archive; entry: Zip.Entry; name: ARRAY OF CHAR; VAR tempfile: Files.File;
	path, overwrite, show: BOOLEAN; out, error : Streams.Writer; VAR res: WORD);
VAR
	f, of: Files.File; r: Files.Rider;
	bakname, temp: ARRAY 256 OF CHAR; res2: LONGINT;
	suf: ARRAY 32 OF CHAR;
BEGIN
	IF action = EXTRACT THEN
		IF ~path THEN
	(*		GetSuffix(name, name, ':'); *)
			GetSuffix(name, name, '/')
		END;
		f := Files.New(name);
		IF (f # NIL) THEN
			IF (out # NIL) THEN
				out.String("Extracting "); out.String(entry.name);
				IF (entry.name # name) THEN
					out.String(" -> "); out.String(name);
				END;
				out.String(" ... ");
			END;
		ELSE
			IF (error # NIL) THEN error.String("Could not create file "); error.String(name); END;
			res := -1;
			RETURN;
		END;
	ELSE
		temp := "Temp.Zip.";
		GetSuffix(name,suf,'.');
		Append(temp,suf);
		f := Files.New(temp);
		IF (f = NIL) THEN
			IF (error # NIL) THEN error.String("Could not create temporary file Temp.Zip"); END;
			res := -1;
			RETURN;
		END;
	END;
	tempfile := f;
	f.Set(r, 0);
	Zip.ExtractEntry(archive, entry, r, res);
	IF (res = Zip.Ok) THEN
		IF action = EXTRACT THEN
			of := Files.Old(name);
			IF (of # NIL) THEN (* file exists on this volume or another volume in search path *)
				IF ~overwrite THEN
					COPY(name, bakname); Append(bakname, ".Bak"); (* assume enough space for .Bak *)
					Files.Rename(name, bakname, res2);
					IF (res2 = Files.Ok) THEN
						IF (out # NIL) THEN out.String(" done (backup in "); out.String(bakname); out.String(")."); END;
					ELSE (* assume old file was in another place in the search path *)
						of.GetName(bakname);
						IF (out # NIL) THEN out.String(" done (masks "); out.String(bakname); out.String(")."); END;
					END
				ELSE
					IF (out # NIL) THEN out.String("done (overwritten)."); END;
				END;
			ELSE
				IF (out # NIL) THEN out.String("done."); END;
			END;
			f.SetDate(entry.time, entry.date);
		END;
		Files.Register(f);
		tempfile := f;
	ELSE
		IF (out # NIL) THEN Zip.ShowError(res, out); END;
	END;
	IF (out # NIL) THEN out.Ln; out.Update; END;
END DoExtract;

(** Extracts the entry ent from the zip-archive ent and stores as under the filename name. Some log-output is generated.
	If path is set, the file is stored in the directory according to the relative path in name.
	If overwrite is set, files with the same name are overwritten, otherwise they are renamed to name.Bak.
	Possible results: cf. Zip.ExtractEntry **)
PROCEDURE ExtractFile*(arc: Zip.Archive; ent: Zip.Entry; CONST name: ARRAY OF CHAR; path, overwrite: BOOLEAN; log, error : Streams.Writer; VAR res: WORD);
VAR temp: Files.File;
BEGIN
	DoExtract(EXTRACT, arc, ent, name, temp, path, overwrite, FALSE, log, error, res);
END ExtractFile;

(** Extracts the entry ent from the zip-archive ent and stores as under the filename name. Some log-output is generated.
	If path is set, the file is stored in the directory according to the relative path in name.
	If overwrite is set, files with the same name are overwritten, otherwise they are renamed to name.Bak.
	Possible results: cf. Zip.ExtractEntry **)
PROCEDURE OpenFile*(
	arc: Zip.Archive; ent: Zip.Entry; CONST name: ARRAY OF CHAR; VAR tempfile: Files.File;
	path, overwrite, show: BOOLEAN; log, error : Streams.Writer; VAR res: WORD);
BEGIN
	DoExtract(OPEN, arc, ent, name, tempfile, path, overwrite, show, log, error, res);
END OpenFile;


(** Extracts the selected entries of the selected zip-Archive. The relative path in the file name of the entry
	is ignored (c.f. option \d).
	ZipTool.Extract [-d] [-o] ZipFile {Entry [=> NewName]}
	Options:
	--directory: If set, the file is stored in the directory according to the relative path in the file name of the entry
	--overwrite: If set, files with the same name are overwritten, otherwise they are renamed to filename.Bak
	--ignore: Continue in case of errors
	--prefix: Add prefix to extracted files **)
PROCEDURE Extract*(context : Commands.Context);
VAR
	archivename, entryname, filename, prefix: Files.FileName;
	options : Options.Options;
	archive: Zip.Archive; entry: Zip.Entry;
	path, overwrite, stopOnError: BOOLEAN;
	nofExtracted, nofErrors, res: LONGINT;
BEGIN
	NEW(options);
	options.Add("d", "directory", Options.Flag);
	options.Add("o", "overwrite", Options.Flag);
	options.Add("i", "ignore", Options.Flag);
	options.Add("p", "prefix", Options.String);

	IF options.Parse(context.arg, context.error) THEN

		path := options.GetFlag("directory");
		overwrite := options.GetFlag("overwrite");
		stopOnError := ~options.GetFlag("ignore");
		IF ~options.GetString("prefix", prefix) THEN prefix := ""; END;

		context.arg.SkipWhitespace; context.arg.String(archivename);
		archive := OpenArchive(archivename, context.error);
		IF (archive # NIL) THEN
			nofExtracted := 0; nofErrors := 0;
			WHILE context.arg.GetString(entryname) & ((nofErrors = 0) OR ~stopOnError) DO
				entry := Zip.GetEntry(archive, entryname, res);
				IF (res = Zip.Ok) THEN
					IF (prefix # "") THEN
						COPY(prefix, filename); Append(filename, entry.name);
					ELSE
						COPY(entry.name, filename);
					END;
					ExtractFile(archive, entry, filename, path, overwrite, context.out, context.error, res);
					IF (res = Zip.Ok) THEN
						INC(nofExtracted);
					ELSE
						INC(nofErrors);
					END;
				ELSE
					INC(nofErrors);
					context.out.String("Extracting "); context.out.String(entryname);
					context.out.String(" ... "); Zip.ShowError(res, context.out); context.out.Ln;
				END;
			END;
			context.out.Int(nofExtracted, 0);
			IF (nofExtracted = 1) THEN context.out.String(" entry extracted"); ELSE context.out.String(" entries extracted"); END;
			IF (nofErrors > 0) THEN
				context.out.String(" ("); context.out.Int(nofErrors, 0);
				IF (nofErrors = 1) THEN context.out.String(" error)");
				ELSE context.out.String(" errors)");
				END;
			END;
			context.out.Ln;
		END;
	END;
END Extract;

(** Extracts all entries of the selected zip-archives. The relative path in the file name of the entry
	is ignored (c.f. option \d).
	ZipTool.ExtractAll [-d] [-o] [-p=DstPrefix] [-sourcePath=SrcPrefix] [-s] {ZipFile} ~
	Options:
	--directory: If set, the file is stored in the directory according to the relative path in the file name of the entry
	--overwrite: If set, files with the same name are overwritten, otherwise they are renamed to filename.Bak
	--ignore: If set, continue extraction in case of an error, otherwise abort
	--prefix: If set, DstPrefix is prefixed to all file names of the entries in the zip-archives
	--sourcePath: If set, SrcPrefix is prefixed to all archive names *)
PROCEDURE ExtractAll*(context : Commands.Context);
VAR
	fullArchiveName, archiveName, filename,  prefix : Files.FileName;
	options : Options.Options;
	path, overwrite, stopOnError, silent: BOOLEAN;
	archive: Zip.Archive;
	entry: Zip.Entry;
	nofExtracted, nofErrors, res: LONGINT;
BEGIN
	NEW(options);
	options.Add("d", "directory", Options.Flag);
	options.Add("o", "overwrite", Options.Flag);
	options.Add("i", "ignore", Options.Flag);
	options.Add("p", "prefix", Options.String);
	options.Add(0X, "sourcePath", Options.String);
	options.Add("s", "silent", Options.Flag);

	IF options.Parse(context.arg, context.error) THEN

		path := options.GetFlag("directory");
		overwrite := options.GetFlag("overwrite");
		stopOnError := options.GetFlag("ignore");
		silent := options.GetFlag("silent");
		IF ~options.GetString("prefix", prefix) THEN prefix := ""; END;

		WHILE context.arg.GetString(archiveName) DO

			IF ~options.GetString("sourcePath", fullArchiveName) THEN fullArchiveName := ""; END;
			Strings.Append(fullArchiveName, archiveName);

			archive := OpenArchive(fullArchiveName, context.error);
			IF (archive # NIL) THEN
				context.out.String("Extracting "); context.out.String(fullArchiveName); context.out.String(" ... ");
				IF ~silent THEN context.out.Ln; END;
				context.out.Update;
				nofExtracted := 0; nofErrors := 0;
				entry := Zip.FirstEntry(archive);
				WHILE (entry # NIL) & ((nofErrors = 0) OR ~stopOnError) DO
					IF (prefix # "") THEN
						COPY(prefix, filename); Append(filename, entry.name);
					ELSE
						COPY(entry.name, filename);
					END;
					IF silent THEN
						ExtractFile(archive, entry, filename, path, overwrite, NIL, NIL, res);
					ELSE
						ExtractFile(archive, entry, filename, path, overwrite, context.out, context.error, res);
					END;
					IF (res = Zip.Ok) THEN
						INC(nofExtracted);
					ELSE
						INC(nofErrors);
					END;
					entry := Zip.NextEntry(entry);
				END;
				IF (nofExtracted > 1) THEN
					context.out.Int(nofExtracted, 0);	context.out.String(" entries extracted");
				END;
				IF (nofErrors > 0) THEN
					context.out.String(" (");
					IF (nofErrors = 1) THEN context.out.String("1 error)");
					ELSE context.out.Int(nofErrors, 0); context.out.String(" errors)");
					END;
				END;
				IF (nofExtracted > 1) OR (nofErrors > 0) THEN context.out.Ln; END;
			END;
		END;
	END;
END ExtractAll;

(** Adds a file to the selected zip-archive.
	level: specifies the compression level (0: no compression, 9: best compression)
	strategy: specifies the compression strategy (from 0 - 2)
	res = Zip.Ok, Zip.BadName, Zip.EntryAlreadyExists, Zip.DataError **)
PROCEDURE AddFile*(arc: Zip.Archive; CONST srcname : ARRAY OF CHAR; CONST dstname: ARRAY OF CHAR; level, strategy: LONGINT; VAR res: WORD);
VAR f: Files.File; r: Files.Rider;
BEGIN
	f := Files.Old(srcname);
	IF f = NIL THEN
		res := Zip.BadName
	ELSE
		f.Set(r, 0);
		Zip.AddEntry(arc, dstname, r, f.Length(), SHORT(SHORT(level)), SHORT(SHORT(strategy)), res);
	END;
END AddFile;

PROCEDURE GetFileName(CONST fullname : ARRAY OF CHAR; VAR filename : ARRAY OF CHAR);
VAR prefix : Files.Prefix; pathname, path : Files.FileName;
BEGIN
	Files.SplitName(fullname, prefix, pathname);
	Files.SplitPath(pathname, path, filename);
END GetFileName;

PROCEDURE GetName(CONST fullname : ARRAY OF CHAR; VAR name : ARRAY OF CHAR);
VAR prefix : Files.Prefix;
BEGIN
	Files.SplitName(fullname, prefix, name);
	IF (name[0] = Files.PathDelimiter) THEN Strings.Delete(name, 0, 1); END;
END GetName;

(** Adds the selected files to the selected zip-archive.
	ZipTool.Add [--level=<int> [--strategy=<int>]] [--nopath] ZipFile  {Entry} ~
	Options:
	--level=<integer>: specifies the compression level (0: no compression, 9: best compression)
		if not set, default level (-1) is used
	--strategy=<integer>: specifies the compression strategy (from 0 - 2)
	--nopath: remove prefix & path from filename
	--removePrefix: remove prefix from filename (but keep path)
	--ignore: continue in case of errors
	--silent: Only error output *)
PROCEDURE Add*(context : Commands.Context);
VAR
	archiveName, entryName : Files.FileName;
	options : Options.Options;
	archive: Zip.Archive;
	strategy, level: LONGINT; stopOnError : BOOLEAN;
	oldname, newname: ARRAY 256 OF CHAR;
	nofAdded, nofErrors, res : LONGINT;

	PROCEDURE ShowFile(CONST oldname, newname : ARRAY OF CHAR; out : Streams.Writer);
	BEGIN
		context.out.String("Adding "); context.out.String(oldname);
		IF (oldname # newname) THEN context.out.String(" -> "); context.out.String(newname); END;
		context.out.String(" ... ");
	END ShowFile;

BEGIN
	NEW(options);
	options.Add("l", "level", Options.Integer);
	options.Add("s", "strategy", Options.Integer);
	options.Add("n", "nopath", Options.Flag);
	options.Add("i", "ignore", Options.Flag);
	options.Add("r", "removePrefix", Options.Flag);
	options.Add(0X, "silent", Options.Flag);

	IF options.Parse(context.arg, context.error) THEN

		IF ~options.GetInteger("level", level) THEN level := Zip.DefaultCompression; END;
		IF ~options.GetInteger("strategy", strategy) THEN strategy := Zip.DefaultStrategy; END;
		stopOnError := ~options.GetFlag("ignore");

		context.arg.SkipWhitespace; context.arg.String(archiveName);

		archive := Zip.CreateArchive(archiveName, res);
		IF (res = Zip.Ok) THEN
			nofAdded := 0; nofErrors := 0;
			WHILE context.arg.GetString(entryName) & ((nofErrors = 0) OR ~stopOnError) DO

				COPY(entryName, oldname);
				IF options.GetFlag("nopath") THEN
					GetFileName(entryName, newname);
				ELSE
					IF options.GetFlag("removePrefix") THEN
						GetName(entryName, newname);
					ELSE
						COPY(entryName, newname);
					END;
				END;

				IF ~options.GetFlag("silent") THEN
					ShowFile(oldname, newname, context.out);
				END;
				AddFile(archive, oldname, newname, level, strategy, res);
				IF (res = Zip.Ok) THEN
					INC(nofAdded);
					IF ~options.GetFlag("silent") THEN
						context.out.String("done."); context.out.Ln;
					END;
				ELSE
					INC(nofErrors);
					IF options.GetFlag("silent") THEN
						ShowFile(oldname, newname, context.out);
					END;
					Zip.ShowError(res, context.out); context.out.Ln;
				END;
			END;
			IF (nofAdded > 1) THEN
				context.out.Int(nofAdded, 0); context.out.String(" entries added to archive "); context.out.String(archiveName);
			END;
			IF (nofErrors > 0) THEN
				context.out.String(" ("); context.out.Int(nofErrors, 0);
				IF (nofErrors = 1) THEN context.out.String(" error)"); ELSE context.out.String(" errors)"); END;
			END;
			IF (nofAdded > 1) OR (nofErrors > 0) THEN context.out.Ln; END;
		ELSE
			context.error.String("Could not create archive '"); context.error.String(archiveName); context.error.String("': ");
			Zip.ShowError(res, context.error); context.error.Ln;
		END;
	END;
END Add;

(** Deletes the selected entries from the selected zip-archive.
	ZipTool.Delete [--ignore] ZipFile {Entry} ~ **)
PROCEDURE Delete*(context : Commands.Context);
VAR
	archiveName, entryName : Files.FileName;
	options : Options.Options;
	archive: Zip.Archive;
	entry: Zip.Entry;
	stopOnError : BOOLEAN;
	nofDeleted, nofErrors, res: LONGINT;
BEGIN
	NEW(options);
	options.Add("i", "ignore", Options.Flag);

	IF options.Parse(context.arg, context.error) THEN

		stopOnError := ~options.GetFlag("ignore");

		context.arg.SkipWhitespace; context.arg.String(archiveName);
		archive := OpenArchive(archiveName, context.error);
		IF (archive # NIL) THEN
			nofDeleted := 0; nofErrors := 0;
			WHILE context.arg.GetString(entryName) & ((nofErrors = 0) OR ~stopOnError) DO
				entry := Zip.GetEntry(archive, entryName, res);
				context.out.String("Deleting entry "); context.out.String(entryName); context.out.String(" ... ");
				IF (res = Zip.Ok) THEN
					Zip.DeleteEntry(archive, entry, res);
					IF (res = Zip.Ok) THEN
						INC(nofDeleted);
						context.out.String("done.");
					END;
				END;
				IF (res # Zip.Ok) THEN
					INC(nofErrors);
					Zip.ShowError(res, context.out);
				END;
				context.out.Ln;
			END;
			IF (nofDeleted > 1) THEN
				context.out.Int(nofDeleted, 0);
				IF (nofDeleted = 1) THEN context.out.String(" entry deleted");
				ELSE context.out.String(" entries deleted");
				END;
			END;
			IF (nofErrors > 0) THEN
				context.out.String(" (");
				context.out.Int(nofErrors, 0);
				IF (nofErrors = 1) THEN context.out.String("error)");
				ELSE context.out.String(" errors)");
				END;
			END;
			IF (nofDeleted > 1) OR (nofErrors > 0) THEN context.out.Ln; END;
		END;
	END;
END Delete;

END ZipTool.

SystemTools.Free ZipTool ~

ZipTool.Directory ZeroSkin.zip ~
ZipTool.Directory --details ZeroSkin.zip ~

ZipTool.Extract ZeroSkin.zip arrow.png ~

ZipTool.ExtractAll ZeroSkin.zip ~