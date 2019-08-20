MODULE SVNAdmin; (** AUTHOR "rstoll"; *)

(*
	.svn directories are per default write protected. Changing file properties is only supported in the Win32 version
	by kernel calls.
*)

IMPORT
	SVNOutput, SVNUtil,
	Strings, Dates,
	Commands, Files, Kernel32, KernelLog;

CONST
	EntryFileFormat* = 8; (* expected svn version *)

TYPE

	EntryEntity* = RECORD
		Format* : LONGINT; (* 1 *)
		Name* : ARRAY 256 OF CHAR; (* 2 *)
		NodeKind* : ARRAY 32 OF CHAR; (* 3 *)
		Revision* : LONGINT; (* 4 *)
		GlobalRemoval* : BOOLEAN;
		Url*, UrlConst* : ARRAY 256 OF CHAR; (* 5 *)
		RepositoryRoot* : ARRAY 256 OF CHAR; (* 6 *)
		Schedule* : ARRAY 32 OF CHAR; (* 7 *)
		TextLastUpdated* : ARRAY 32 OF CHAR; (* 8 *)
		Checksum* : ARRAY 33 OF CHAR; (* 9 *)
		LastChangedDate* : ARRAY 32 OF CHAR; (* 10: len ?= 28? *)
		LastChangedRevision* : LONGINT; (* 11 *)
		LastChangedAuthor* : ARRAY 256 OF CHAR; (* 12 *)
		Props* : ARRAY 256 OF CHAR; (* 13: maybe longer? *)
		(*PropsMods : ARRAY 256 OF CHAR; (* 14: maybe longer *)*)
		RepositoryUUID* : ARRAY 37 OF CHAR; (* 27 *)

		VersionUrl* : ARRAY 256 OF CHAR;
	END;

TYPE
	TraverseHandler* = PROCEDURE {DELEGATE} ( CONST path : ARRAY OF CHAR; fileEntry : EntryEntity; data : ANY ) : BOOLEAN;

TYPE

	Entry* = OBJECT
	VAR
		adminDir : EntryEntity;
		path : ARRAY 256 OF CHAR;
		name : ARRAY 32 OF CHAR;
		context : Commands.Context;
		fAdmin, fAdminTemp : Files.File;
		entriesfile, entriesfiletemp, svnpath : ARRAY 256 OF CHAR;
		pathIsFile, readGlobalData, readFromTempfile : BOOLEAN;
		r : Files.Reader;
		w : Files.Writer;
		pathLength : SIZE;

		PROCEDURE &Init* ( c: Commands.Context );
		BEGIN
			context := c;
			readGlobalData := FALSE;
		END Init;

		PROCEDURE ReadVersionUrl* ( CONST filename : ARRAY OF CHAR );
		VAR
			propsfile, p, n, tmp : ARRAY 256 OF CHAR;
			nextFileEntry : BOOLEAN;
			pf : Files.File;
			pr : Files.Reader;
		BEGIN
			IF fAdmin # NIL THEN

				IF pathIsFile THEN
					Files.SplitPath ( path, p, n );
					Files.JoinPath ( p, ".svn/all-wcprops", propsfile );
				ELSE
					Files.JoinPath ( path, ".svn/all-wcprops", propsfile );
				END;

				IF filename # "" THEN
					COPY ( filename, n );
				END;

				pf := Files.Old ( propsfile );
				ASSERT ( pf # NIL );

				Files.OpenReader ( pr, pf, 0 );
				ASSERT ( pr # NIL );

				IF pathIsFile OR (n # "") THEN (* search for the file *)
					nextFileEntry := FALSE;
					LOOP
						pr.Ln ( tmp );
						IF pr.res # Files.Ok THEN
							KernelLog.String ( "ERROR: didn't find entry in the .svn/all-wcprops file for: " );
							KernelLog.String ( p ); KernelLog.String ( " file: " ); KernelLog.String ( n );
							KernelLog.Ln;
							RETURN;
						END;

						IF nextFileEntry & (tmp = n) THEN EXIT END;
						nextFileEntry := (tmp = "END");
					END;
				END;

				(* get url *)
				pr.SkipLn; pr.SkipLn; pr.SkipLn;
				pr.Ln ( adminDir.VersionUrl );
			END;
		END ReadVersionUrl;

		PROCEDURE SetPath* ( CONST p : ARRAY OF CHAR; VAR res : WORD );
		BEGIN
			r := NIL;
			readGlobalData := FALSE;
			COPY ( p, path );

			AnalyzePath ( res );

			ASSERT ( (res = SVNOutput.ResOK) OR (res = SVNOutput.ResNOTVERSIONED) );
		END SetPath;

		PROCEDURE AnalyzePath ( VAR res : WORD );
		BEGIN
			pathIsFile := FALSE;
			res := SVNOutput.ResOK;

			IF (path = ".") OR (path = "") THEN
				fAdmin := Files.Old (".svn/entries");

				IF fAdmin = NIL THEN
					res := SVNOutput.ResNOTVERSIONED;
					RETURN;
				END;
			ELSE
				Files.JoinPath ( path, ".svn/entries", entriesfile );
				fAdmin := Files.Old ( entriesfile );

				IF fAdmin = NIL THEN (* our parameter was a file destination *)
					Files.SplitPath ( path, svnpath, name );
					Files.JoinPath ( svnpath, ".svn/entries", entriesfile );
					fAdmin := Files.Old ( entriesfile );

					IF fAdmin = NIL THEN
						res := SVNOutput.ResNOTVERSIONED;
						RETURN;
					END;

					pathIsFile := TRUE; (* search the file in the svn-entries file *)

					Files.JoinPath ( svnpath, ".svn/tmp/od-entries", entriesfiletemp );
				ELSE
(*					Kernel32.SetFileAttributes ( entriesfile, {} );*)
					Files.JoinPath ( path, ".svn/tmp/od-entries", entriesfiletemp );
				END;
			END;

			ASSERT ( fAdmin # NIL );
		END AnalyzePath;

		PROCEDURE CreateTempfile*;
		VAR
			res : WORD;
		BEGIN
			IF SVNUtil.FileExists ( entriesfiletemp ) THEN
				Files.Delete ( entriesfiletemp, res );
				ASSERT ( res = Files.Ok );
			END;
			fAdminTemp := Files.New ( entriesfiletemp );

			ReadFromTempfile ( TRUE );
		END CreateTempfile;

		PROCEDURE ReadFromTempfile* ( b : BOOLEAN );
		BEGIN
			IF b THEN
				ASSERT ( fAdmin # NIL );
				ASSERT ( fAdminTemp # NIL );

				Files.OpenWriter ( w, fAdminTemp, 0 );
				Files.OpenReader ( r, fAdmin, 0 );
			END;
			readFromTempfile := b;
		END ReadFromTempfile;

		PROCEDURE GetUrl* ( VAR url : ARRAY OF CHAR );
		BEGIN
			COPY ( adminDir.Url, url );
		END GetUrl;

		PROCEDURE GetRepo* ( VAR repos : ARRAY OF CHAR );
		BEGIN
			COPY ( adminDir.RepositoryRoot, repos );
		END GetRepo;

		PROCEDURE GetVersion* () : LONGINT;
		BEGIN
			IF ~pathIsFile THEN
				RETURN adminDir.Revision;
			ELSE
				RETURN adminDir.LastChangedRevision;
			END;
		END GetVersion;

		PROCEDURE SkipGlobalData;
		VAR
			temp : ARRAY 256 OF CHAR;
			start: ARRAY 2 OF CHAR;
		BEGIN
(*			IF ~readGlobalData THEN
				readGlobalData := TRUE;*)

				ASSERT ( fAdmin # NIL );
				NEW( r, fAdmin, 0 );
				start[0] := CHR(12); start[1] := 0X;
				REPEAT
					r.Ln ( temp );
					IF readFromTempfile THEN
						WriteString ( w, temp );
					END;
				UNTIL Strings.StartsWith2(start, temp);
(*			END;*)
		END SkipGlobalData;

		(* read all lines until we reach end of entry *)
		PROCEDURE SkipReaderToEOE;
		VAR
			temp : ARRAY 256 OF CHAR;
			start: ARRAY 2 OF CHAR;
		BEGIN
			ASSERT ( r # NIL );
			start[0] := CHR(12); start[1] := 0X;
			REPEAT
				r.Ln ( temp );
				IF r.res # Files.Ok THEN RETURN END;
			UNTIL Strings.StartsWith2(start, temp);
		END SkipReaderToEOE;

		PROCEDURE IsItemVersioned* ( CONST filename : ARRAY OF CHAR ) : BOOLEAN;
		VAR
			temp : ARRAY 256 OF CHAR;
		BEGIN
			(* global data hasn't been read, so we need to do it now *)
			SkipGlobalData;

			readGlobalData := FALSE;

			ASSERT ( r # NIL );

			LOOP
				r.Ln(temp); (* 2: read name of file *)
				IF r.res # Files.Ok THEN RETURN FALSE END;

				IF readFromTempfile THEN
					WriteString ( w, temp );
				END;

				Strings.TrimWS(temp);

				IF filename = temp THEN
					RETURN TRUE;
				ELSE
					IF readFromTempfile THEN
						ReadWriteToEOE;
					ELSE
						SkipReaderToEOE;
					END;
					IF r.res # Files.Ok THEN RETURN FALSE END;
				END;
			END;
		END IsItemVersioned;

		(* add everything in the directory recursively
			- path
			- name: name of the directory inside the path which will be added
			- addGlobal: usually the first
		*)
		PROCEDURE Add* ( CONST path : ARRAY OF CHAR; CONST name : ARRAY OF CHAR; addGlobal : BOOLEAN; VAR res : WORD );
		VAR
			file, entryfile, tmp, tmp2 : Files.FileName;
			res1: WORD; time, date : LONGINT;
			size : Files.Size;
			w : Files.Writer;
			flags : SET;
			enum : Files.Enumerator;
			urlRepo : Strings.String;
		BEGIN
			res := SVNOutput.ResOK;

			SetPath ( path, res1 );
			ASSERT ( res1 = SVNOutput.ResOK );
			ASSERT ( ~pathIsFile );

			IF IsItemVersioned ( name ) THEN
				res := SVNOutput.ResALREADYVERSIONED;
				RETURN;
			END;

			Files.JoinPath ( path, name, file );
			ASSERT ( ~SVNUtil.FileExists ( file ) ); (* 'name' must be a directory *)

			NEW ( enum );
			enum.Open ( file, {} ); (* get all files/dirs in the actual directory *)

			Files.JoinPath ( path, ".svn/entries", entryfile );

			IF addGlobal THEN
				pathLength := Strings.Length(path)+1;

				fAdmin := Files.Old ( entryfile );
				ASSERT ( fAdmin # NIL );
				RemoveFileAttribute2 ( entryfile, fAdmin );

				ReadData ( res1 );

				fAdmin := Files.Old ( entryfile ); (* needed? *)
				Files.OpenWriter ( w, fAdmin, fAdmin.Length() );
				WriteAddEntry ( w, name, FALSE );
				w.Update;

				SetFileAttribute2 ( entryfile, fAdmin );
			END;

			urlRepo := Strings.Substring2 ( pathLength, file );
			w := CreateDummy ( file, urlRepo^ );

			(* add all files/dirs in the actual directory *)
			WHILE enum.HasMoreEntries() DO
				IF enum.GetEntry ( tmp, flags, time, date, size ) THEN
					KernelLog.String ( " A " ); KernelLog.String ( tmp ); KernelLog.Ln;

					Files.SplitPath ( tmp, tmp, tmp2 );

					IF Files.Directory IN flags THEN
						Add ( file, tmp2, FALSE, res );
						ASSERT ( res = SVNOutput.ResOK );
					END;
					(* TODO check whether file is already versioned.... hmm can this even happen?? *)
					WriteAddEntry ( w, tmp2, ~(Files.Directory IN flags) );
				END;
			END;
			w.Update;

			SetFileAttribute2 ( entryfile, fAdmin );
		END Add;

		(* creates a dummy .svn entry; scheduled for adding *)
		PROCEDURE CreateDummy* ( CONST path, urlRepoDir : ARRAY OF CHAR ) : Files.Writer;
		VAR
			entryfile : Files.FileName;
			f : Files.File;
			w : Files.Writer;
			data : EntryEntity;
		BEGIN

			CreateDirectory ( path );

			Files.JoinPath ( path, ".svn/entries", entryfile );
			f := Files.New ( entryfile );
			Files.OpenWriter ( w, f, 0 );

			data.Schedule := "add";
			Files.JoinPath ( adminDir.Url, urlRepoDir, data.Url );
			COPY ( adminDir.RepositoryRoot, data.RepositoryRoot );
			Write ( w, data );

			Files.Register ( f );

			RETURN w;
		END CreateDummy;

		PROCEDURE ReadData* ( VAR res : WORD );
		VAR
			i : INTEGER;
			tmp : ARRAY 256 OF CHAR;
			start: ARRAY 2 OF CHAR;
		BEGIN
			res := SVNOutput.ResOK;
			readGlobalData := TRUE; (* now we read global data *)

			Files.OpenReader ( r, fAdmin, 0 );

			r.Int ( adminDir.Format, FALSE ); r.SkipLn; (* 1 *)

			IF adminDir.Format < EntryFileFormat THEN
				res := SVNOutput.ResCLIENTOLD;
				RETURN;
			END;

			r.SkipLn; (* 2: name...first entry is empty *)

			r.Ln ( adminDir.NodeKind ); (* 3 *)
			r.Ln ( tmp ); (* 4 *)
			IF tmp # "" THEN
				Strings.StrToInt ( tmp, adminDir.Revision ); (* 4 *)
			END;
			r.Ln ( adminDir.Url ); (* 5 *)
			COPY ( adminDir.Url, adminDir.UrlConst );
			r.Ln ( adminDir.RepositoryRoot ); (* 6 *)
			r.Ln ( adminDir.Schedule ); (* 7 *)
			adminDir.GlobalRemoval := (adminDir.Schedule = "delete");

			r.SkipLn; (* 8 *)
			r.SkipLn; (* 9 *)

			r.Ln ( adminDir.LastChangedDate ); (* 10 *)
			r.Ln ( tmp ); (* 11 *)
			IF tmp # "" THEN
				Strings.StrToInt ( tmp, adminDir.LastChangedRevision ); (* 11 *)
			END;
			r.Ln ( adminDir.LastChangedAuthor ); (* 12 *)
			r.SkipLn; (* 13 *)

			(* empty line?? *)
			r.SkipLn; (* 14 *)

			r.Ln ( adminDir.Props ); (* 15 *)

			r.Ln ( tmp ); (* 16 *)
			start[0] := CHR(12); start[1] := 0X;
			IF ~Strings.StartsWith2(start, tmp) THEN
				FOR i:=1 TO 10 DO
					r.SkipLn; (* 17-27 *)
				END;

				r.Ln ( adminDir.RepositoryUUID );

				r.SkipLn; (* ^L *)
			END;

			IF pathIsFile THEN (* search for more deatils in entries file... file or directory entry *)
				IF ~IsItemVersioned ( name ) THEN
					res := SVNOutput.ResNOTVERSIONED;
				ELSE
					(* found file entry... read data into adminDir *)
					ReadFileData ( name, res );
				END;
			END;
		END ReadData;

		PROCEDURE ReadFileData ( CONST name : ARRAY OF CHAR; VAR res : WORD );
		VAR
			tmp : ARRAY 256 OF CHAR;
			start: ARRAY 2 OF CHAR;
		BEGIN
			res := SVNOutput.ResOK;
			IF name = "" THEN
				r.Ln ( adminDir.Name ); (* 2*)
			ELSE
				COPY ( name, adminDir.Name );
			END;

			Strings.Concat ( adminDir.UrlConst, "/", adminDir.Url ); Strings.Append ( adminDir.Url, adminDir.Name );

			r.Ln ( adminDir.NodeKind ); (* 3*)


			IF r.Peek() # CHR(12) THEN
				r.Ln ( tmp ); (* 4*)
				IF tmp # "" THEN
					Strings.StrToInt ( tmp, adminDir.Revision );
				END;

				r.SkipLn; r.SkipLn; (* 5-6 *)
				r.Ln ( adminDir.Schedule ); (* 7 *)
				IF adminDir.Schedule = "" THEN
					r.Ln ( adminDir.TextLastUpdated ); (* 8 *)
					r.Ln ( adminDir.Checksum ); (* 9 *)
					r.Ln ( adminDir.LastChangedDate ); (* 10 *)
					r.Ln ( tmp ); (* 11 *)
					IF tmp # "" THEN
						Strings.StrToInt ( tmp, adminDir.LastChangedRevision );
					ELSE
						res := SVNOutput.ResNOTVERSIONED;
						RETURN;
					END;
					r.Ln ( adminDir.LastChangedAuthor ); (* 12 *)
				END;
			END;

			(* read all lines until we reach end of entry; including CHR(12) *)
			start[0] := CHR(12); start[1] := 0X;
			REPEAT
				r.Ln ( tmp );
				IF r.res # Files.Ok THEN RETURN END;
			UNTIL Strings.StartsWith2(start, tmp);
		END ReadFileData;

		PROCEDURE PrintData*;
		BEGIN
			context.out.String ("Path: "); context.out.String ( path ); context.out.Ln; context.out.Update;

			context.out.String ("URL: ");
			context.out.String (adminDir.Url);
			context.out.Ln;

			context.out.String ("Repository Root: ");
			context.out.String (adminDir.RepositoryRoot);
			context.out.Ln;

			context.out.String ("Repository UUID: ");
			context.out.String (adminDir.RepositoryUUID);
			context.out.Ln;

			context.out.String ("Revision: ");
			context.out.Int (adminDir.Revision, 0);
			context.out.Ln;

			context.out.String ("Node Kind: ");
			IF adminDir.NodeKind = "dir" THEN
				context.out.String ("directory");
			ELSE
				context.out.String (adminDir.NodeKind);
			END;
			context.out.Ln;

			context.out.String ( "Schedule: " );
			IF (adminDir.Schedule = "") OR (adminDir.Schedule = "normal") THEN
				context.out.String ( "normal" );
			ELSE
				context.out.String ( adminDir.Schedule );
			END;
			context.out.Ln;

			(* if we added a file the rest of the informations aren't important *)
			IF adminDir.Schedule = "add" THEN
				RETURN;
			END;

			context.out.String ("Last Changed Author: ");
			context.out.String (adminDir.LastChangedAuthor);
			context.out.Ln;

			context.out.String ("Last Changed Revision: ");
			context.out.Int (adminDir.LastChangedRevision, 0);
			context.out.Ln;

			context.out.String ("Last Changed Date: ");
			context.out.String (adminDir.LastChangedDate);
			context.out.Ln;

			IF adminDir.NodeKind = "file" THEN
				context.out.String ("Text Last Updated: ");
				context.out.String (adminDir.TextLastUpdated);
				context.out.Ln;

				context.out.String ("Checksum: ");
				context.out.String (adminDir.Checksum);
				context.out.Ln;
			END;

			context.out.Update;

		END PrintData;



		PROCEDURE ReadWriteLines* ( count : LONGINT );
		VAR
			i : LONGINT;
			tmp : ARRAY 256 OF CHAR;
		BEGIN
			FOR i := 1 TO count DO
				IF r.Peek() = CHR(12) THEN
					tmp := "";
				ELSE
					r.Ln ( tmp );

				END;

				ASSERT ( r.res = Files.Ok );
				w.String ( tmp ); w.Char ( 0AX );
			END;
		END ReadWriteLines;

		PROCEDURE ReadWriteLine* ( VAR str : ARRAY OF CHAR );
		BEGIN
			IF r.Peek() # CHR(12) THEN
				r.Ln ( str );
			ELSE
				str := "";
			END;
			w.String ( str );
			w.Char ( 0AX );
		END ReadWriteLine;

		PROCEDURE ReadWriteRest*;
		VAR
			tmp : ARRAY 256 OF CHAR;
			len : SIZE;
		BEGIN
			REPEAT
				r.Bytes ( tmp, 0, LEN(tmp), len );
				w.Bytes ( tmp, 0, len );
			UNTIL len < LEN(tmp);
		END ReadWriteRest;

		PROCEDURE ReadWriteString* ( CONST str : ARRAY OF CHAR );
		BEGIN
			IF r.Peek() # CHR(12) THEN
				r.SkipLn;
			END;
			w.String ( str );
			w.Char ( 0AX );
		END ReadWriteString;

		(* EOE = end of entry CHR(12) *)
		PROCEDURE ReadWriteToEOE*;
		VAR
			tmp : ARRAY 256 OF CHAR; start: ARRAY 2 OF CHAR;
		BEGIN
			start[0] := CHR(12); start[1] := 0X;
			REPEAT
				r.Ln ( tmp );
				IF r.res # Files.Ok THEN RETURN END;
				w.String ( tmp ); w.Char ( 0AX );
			UNTIL Strings.StartsWith2(start, tmp);
		END ReadWriteToEOE;

		PROCEDURE IsEOF* () : BOOLEAN;
		VAR
			c : CHAR;
		BEGIN
			c := r.Peek();
			RETURN (r.res # Files.Ok) OR (c = 0X);
		END IsEOF;

		PROCEDURE WriteUpdate*;
		VAR
			res : WORD;
			overwrite : BOOLEAN;
		BEGIN
			w.Update;
			Files.Register ( fAdminTemp );

			overwrite := TRUE;
			RemoveFileAttribute ( entriesfile );
			Files.CopyFile ( entriesfiletemp, entriesfile, overwrite, res );
			SetFileAttribute ( entriesfile );
			ASSERT ( res = Files.Ok );
		END WriteUpdate;

		PROCEDURE ReadWriteEOE*;
		BEGIN
			SkipReaderToEOE;
			w.Char ( CHR(12) ); w.Char ( 0AX );
		END ReadWriteEOE;


	END Entry;







	PROCEDURE WriteAddEntry* ( w : Files.Writer; CONST name : ARRAY OF CHAR; file : BOOLEAN );
	VAR
		data : EntryEntity;
	BEGIN
		COPY ( name, data.Name );
		data.Schedule := "add";
		IF file THEN data.NodeKind := "file" ELSE data.NodeKind := "dir" END;

		Write ( w, data );
	END WriteAddEntry;

	PROCEDURE WriteString ( w : Files.Writer; CONST line : ARRAY OF CHAR );
	BEGIN
		w.String ( line );
		w.Char ( 0AX );
	END WriteString;

	PROCEDURE WriteInt ( w : Files.Writer; line : LONGINT );
	BEGIN
		IF line # 0 THEN
			w.Int ( line, 0 );
		END;
		w.Char ( 0AX );
	END WriteInt;

	PROCEDURE Write* ( w : Files.Writer; data : EntryEntity );
	VAR
		i : LONGINT;
		tmp : ARRAY 34 OF CHAR;
	BEGIN
		IF data.Name = "" THEN
			(* write the header section in .svn/entries *)
			WriteInt ( w, EntryFileFormat ); (* 1 *)
			w.Char ( 0AX ); (* 2 *)
			WriteString ( w, "dir" ); (* 3 *)
			IF data.Schedule = "add" THEN
				w.String ( "0" ); w.Char ( 0AX ); (* 4 *)
			ELSE
				WriteInt ( w, data.Revision ); (* 4 *)
			END;
			WriteString ( w, data.Url ); (* 5 *)
			WriteString ( w, data.RepositoryRoot ); (* 6 *)
			WriteString ( w, data.Schedule ); (* 7 *)
			w.Char ( 0AX ); (* 8 *)
			w.Char ( 0AX ); (* 9 *)
			WriteString ( w, data.LastChangedDate ); (* 10 *)
			WriteInt ( w, data.LastChangedRevision ); (* 11 *)
			WriteString ( w, data.LastChangedAuthor ); (* 12 *)
			WriteString ( w, data.Props ); (* 13 *)
			w.Char ( 0AX ); (* 14 *)
			w.String ( "svn:special svn:externals svn:needs-lock" ); w.Char ( 0AX ); (* 15 *)

			IF data.Schedule = "" THEN
				FOR i := 16 TO 26 DO w.Char ( 0AX ) END;
				WriteString ( w, data.RepositoryUUID ); (* 27 *)
			END;
		ELSIF data.NodeKind = "file" THEN
			(* write the file section in .svn/entries *)
			WriteString ( w, data.Name ); (* 2 *)
			w.String ( "file" ); w.Char ( 0AX ); (* 3 *)
			IF data.Schedule = "add" THEN
				w.String ( "0" ); w.Char ( 0AX ); (* 4 *)
			ELSE
				WriteInt ( w, data.Revision ); (* 4 *)
			END;
			w.Char ( 0AX ); (* 5 *)
			w.Char ( 0AX ); (* 6 *)
			WriteString ( w, data.Schedule ); (* 7 *)

			IF data.Schedule = "" THEN
				IF data.TextLastUpdated = "" THEN
					(* TODO is this precise enough? maybe we need to get the time from the file directly *)
					Strings.FormatDateTime ( SVNOutput.DateFormat, Dates.Now(), tmp );
					WriteString ( w, tmp ); (* 8 *)
				ELSE
					WriteString ( w, data.TextLastUpdated ); (* 8 *)
				END;
				WriteString ( w, data.Checksum ); (* 9 *)
				WriteString ( w, data.LastChangedDate ); (* 10 *)
				WriteInt ( w, data.LastChangedRevision ); (* 11 *)
				WriteString ( w, data.LastChangedAuthor ); (* 12 *)

				(* TODO more parameters.. like has-props.. add them if needed *)
			END;
		ELSE
			(* write the directory section in .svn/entries *)
			WriteString ( w, data.Name ); (* 2 *)
			w.String ( "dir" ); w.Char ( 0AX ); (* 3 *)

			IF data.Schedule # "" THEN
				w.Char ( 0AX ); (* 4 *)
				w.Char ( 0AX ); (* 5 *)
				w.Char ( 0AX ); (* 6 *)
				WriteString ( w, data.Schedule ); (* 7 *)
			END;
		END;

		w.Char ( CHR(12) ); w.Char ( 0AX );
		w.Update;
	END Write;

	(* write data to the .svn/all-wcprops file *)
	PROCEDURE WriteWCPROPS* ( CONST path, filename, verurl : ARRAY OF CHAR );
	CONST
		key = "svn:wc:ra_dav:version-url";
	VAR
		tmp,fstr,fstr2 : ARRAY 256 OF CHAR;
		read, len: SIZE; i : LONGINT; res: WORD;
		keyLength: SIZE;
		fr, fw : Files.File;
		r : Files.Reader;
		w : Files.Writer;
		overwrite, nextFileEntry, hasDirEntry : BOOLEAN;
	BEGIN
		keyLength := Strings.Length ( key );

		Files.JoinPath ( path, ".svn/all-wcprops", fstr );
		Files.JoinPath ( path, ".svn/tmp/od-all-wcprops", fstr2 );

		fw := Files.Old ( fstr );
		IF fw = NIL THEN
			fw := Files.New ( fstr );
			Files.Register ( fw );
		END;

		RemoveFileAttribute2 ( fstr, fw );

		overwrite := TRUE;
		Files.CopyFile ( fstr, fstr2, overwrite, res );
		ASSERT ( res = Files.Ok );

		fr := Files.Old ( fstr2 );
		ASSERT ( fr # NIL );

		Files.OpenWriter ( w, fw, 0 );
		Files.OpenReader ( r, fr, 0 );

		hasDirEntry := FALSE;

		IF filename # "" THEN
			(* we have a file, first search for it and then add it at the correct position *)
			nextFileEntry := FALSE;
			LOOP
				r.Ln ( tmp );
				IF r.res # Files.Ok THEN
					IF ~hasDirEntry THEN
						(* make dummy dir entry *)
						w.String ( "K " ); w.String ( "0" ); w.Char ( 0AX );
						w.String ( "" ); w.Char ( 0AX );
						w.String ( "V " ); w.String ( "0" ); w.Char ( 0AX );
						w.String ( "" ); w.Char ( 0AX );
						w.String ( "END" ); w.Char ( 0AX );
					END;

					(* didn't find the file..so we add a new one *)
					w.String ( filename ); w.Char ( 0AX );
					w.Update;
					EXIT;
				END;

				hasDirEntry := TRUE;
				w.String ( tmp ); w.Char ( 0AX );

				IF nextFileEntry & (tmp = filename) THEN EXIT END;

				nextFileEntry := (tmp = "END");
			END;
		END;

		(* directory entry comes at the beginning *)
		w.String ( "K " ); w.Int ( keyLength, 0 ); w.Char ( 0AX );
		w.String ( key ); w.Char ( 0AX );
		w.String ( "V " ); w.Int ( Strings.Length ( verurl ), 0 ); w.Char ( 0AX );
		w.String ( verurl ); w.Char ( 0AX );
		w.String ( "END" ); w.Char ( 0AX );

		(* search the start position of the remaining entries *)
		FOR i := 1 TO 5 DO
			r.SkipLn;
		END;

		(* copy the rest *)
		read := 0;
		LOOP
			r.Bytes ( tmp, read, LEN(tmp), len );
			w.Bytes ( tmp, read, len );
			INC ( read, len );
			IF len <= LEN(tmp) THEN EXIT END;
		END;

		w.Update;

		SetFileAttribute2 ( fstr, fw );
	END WriteWCPROPS;


	PROCEDURE CreateDirectory* ( CONST path : ARRAY OF CHAR );
	VAR
		tmp, tmp2, svndir : Files.FileName;
		res : WORD;
		f : Files.File;
		w : Files.Writer;
	BEGIN
		Files.JoinPath ( path, ".svn", svndir ); Files.CreateDirectory ( svndir, res ); ASSERT ( res = 0 );
		Files.JoinPath ( svndir, "prop-base", tmp ); Files.CreateDirectory ( tmp, res ); ASSERT ( res = 0 );
		Files.JoinPath ( svndir, "props", tmp ); Files.CreateDirectory ( tmp, res ); ASSERT ( res = 0 );
		Files.JoinPath ( svndir, "text-base", tmp ); Files.CreateDirectory ( tmp, res ); ASSERT ( res = 0 );
		Files.JoinPath ( svndir, "tmp", tmp ); Files.CreateDirectory ( tmp, res ); ASSERT ( res = 0 );
		Files.JoinPath ( tmp, "prop-base", tmp2 ); Files.CreateDirectory ( tmp2, res ); ASSERT ( res = 0 );
		Files.JoinPath ( tmp, "props", tmp2 ); Files.CreateDirectory ( tmp2, res ); ASSERT ( res = 0 );
		Files.JoinPath ( tmp, "text-base", tmp2 ); Files.CreateDirectory ( tmp2, res ); ASSERT ( res = 0 );

		Files.JoinPath ( svndir, "format", tmp );
		f := Files.New ( tmp );
		Files.OpenWriter ( w, f, 0 );
		w.Int ( EntryFileFormat, 0 );
		w.Char ( 0AX );
		w.Update;
		Files.Register ( f );

		SetFileAttribute ( tmp );
	END CreateDirectory;


	(* refactor: use SVNAdmin.Read* to get checksum.. *)
	PROCEDURE ReadChecksum* ( CONST file : ARRAY OF CHAR ) : Strings.String;
	VAR
		tmp, path, name : ARRAY 256 OF CHAR;
		nextFileEntry : BOOLEAN;
		f : Files.File;
		r : Files.Reader;
		i : LONGINT;
		s : Strings.String;
		start: ARRAY 2 OF CHAR;
	BEGIN
		NEW ( s, 34 );

		Files.SplitPath ( file, path, name );

		IF Strings.EndsWith ( "svn-base", file ) THEN
			Files.SplitPath ( path, path, tmp );
			Files.SplitPath ( path, path, tmp );
			Strings.Truncate ( name, Strings.Length ( name ) - Strings.Length ( ".svn-base" ) );
		END;

		Files.JoinPath ( path, ".svn/entries", tmp );

		f := Files.Old ( tmp );
		ASSERT ( f # NIL );
		Files.OpenReader ( r, f, 0 );

		nextFileEntry := FALSE;
		LOOP
			r.Ln ( tmp );
			IF r.res # Files.Ok THEN RETURN NIL END;

			IF nextFileEntry & (tmp = name) THEN
				FOR i := 1 TO 6 DO
					r.Ln ( tmp );
					ASSERT ( r.res = Files.Ok );
				END;

				r.Ln ( s^ );
				RETURN s;
			END;
			start[0] := CHR(12); start[1] := 0X;
			nextFileEntry := Strings.StartsWith ( start, 0, tmp );
		END;
	END ReadChecksum;



PROCEDURE CheckChecksum* ( CONST file : ARRAY OF CHAR ) : BOOLEAN;
VAR
	s, s2 : Strings.String;
BEGIN
	s := SVNUtil.GetChecksum ( file );
	s2 := ReadChecksum ( file );
	RETURN s^ = s2^;
END CheckChecksum;


	PROCEDURE Traverse* ( CONST path : ARRAY OF CHAR; handler : TraverseHandler; data : ANY; verurl : BOOLEAN;  VAR res : WORD );
	VAR
		tmp, tmp2 : ARRAY 256 OF CHAR;
		adminEntry : Entry;
	BEGIN
		NEW ( adminEntry, NIL );

		adminEntry.SetPath ( path, res );
		IF res # SVNOutput.ResOK THEN RETURN END;

		adminEntry.ReadData ( res );
		IF res # SVNOutput.ResOK THEN RETURN END;

		IF verurl & (adminEntry.adminDir.Schedule = "") THEN
			adminEntry.ReadVersionUrl ( "" );
		END;

		IF adminEntry.pathIsFile THEN
			Files.SplitPath ( path, tmp, tmp2 );
			IF handler ( tmp,adminEntry.adminDir, data ) THEN END;
			RETURN;
		END;

		IF ~handler ( path, adminEntry.adminDir, data ) THEN
			RETURN;
		END;

		WHILE adminEntry.r.Peek() # 0X DO
			adminEntry.ReadFileData ( "", res );
			ASSERT ( res = SVNOutput.ResOK );

			IF adminEntry.adminDir.NodeKind = "dir" THEN
				Files.JoinPath ( path, adminEntry.adminDir.Name, tmp );
				Traverse ( tmp, handler, data, verurl, res );
			ELSE
				IF verurl & (adminEntry.adminDir.Schedule = "") THEN
					adminEntry.ReadVersionUrl ( adminEntry.adminDir.Name );
				END;

				IF ~handler ( path, adminEntry.adminDir, data ) THEN
					RETURN;
				END;
			END;
		END;
	END Traverse;



	PROCEDURE CopyToBaseFile* ( CONST file : ARRAY OF CHAR );
	VAR
		res : WORD;
		overwrite : BOOLEAN;
		dest, path, name : Files.FileName;
	BEGIN
		IF SVNUtil.FileExists ( file ) THEN
			overwrite := TRUE;

			Files.SplitPath ( file, path, name );
			Files.JoinPath ( path, ".svn/text-base", path );
			Files.JoinPath ( path, name, dest );
			Strings.Append ( dest, ".svn-base" );

			IGNORE Kernel32.SetFileAttributes ( dest, {} );
			Files.CopyFile ( file, dest, overwrite, res );
			IGNORE Kernel32.SetFileAttributes ( dest, {Files.ReadOnly} );
			ASSERT ( res = Files.Ok );
		END;
	END CopyToBaseFile;



	PROCEDURE SetFileAttribute* ( file : ARRAY OF CHAR );
	BEGIN
		IGNORE Kernel32.SetFileAttributes ( file, {Files.ReadOnly} );
	END SetFileAttribute;

	PROCEDURE RemoveFileAttribute* ( file : ARRAY OF CHAR );
	BEGIN
		IGNORE Kernel32.SetFileAttributes ( file, {} );
	END RemoveFileAttribute;


	PROCEDURE SetFileAttribute2* ( file : ARRAY OF CHAR; f : Files.File );
	BEGIN
		IGNORE Kernel32.SetFileAttributes ( file, {Files.ReadOnly} );
		INCL ( f.flags, Files.ReadOnly );
	END SetFileAttribute2;

	PROCEDURE RemoveFileAttribute2* ( file : ARRAY OF CHAR; f : Files.File );
	BEGIN
		IGNORE Kernel32.SetFileAttributes ( file, {} );
		EXCL ( f.flags, Files.ReadOnly );
	END RemoveFileAttribute2;

END SVNAdmin.
