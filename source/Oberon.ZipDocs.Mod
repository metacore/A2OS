(* ETH Oberon, Copyright 2001 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

MODULE ZipDocs IN Oberon; (** portable *)	(* ejz  *)
	IMPORT Files, Oberon, Objects, Texts, Zip, ZipTool, Gadgets, Documents, Desktops, TextGadgets, TextDocs;

	CONST
		Menu = "ZipDocs.Add[Add] ZipDocs.Open[Open] ZipDocs.Extract[Extract] ZipDocs.ExtractAll[ExtractAll] ZipDocs.Delete[Delete] TextDocs.Search[Search]";
		path = FALSE;
		overwrite = FALSE;
		EXTRACT = 1;
		OPEN = 2;

	VAR
		W: Texts.Writer;

	PROCEDURE GetArcName(VAR name: ARRAY OF CHAR);
		VAR D: Documents.Document;
	BEGIN
		IF Desktops.IsInMenu(Gadgets.context) THEN
			D := Desktops.CurDoc(Gadgets.context);
			IF D # NIL THEN
				COPY(D.name, name);
				RETURN
			END
		END;
	END GetArcName;

	PROCEDURE doExtract(action: SIGNED16);
	VAR
		S: Texts.Scanner; T, T2: Texts.Text; beg, end, time: SIGNED32;
		D: Documents.Document;
		arc: Zip.Archive; ent: Zip.Entry; arcname, name, tempname: ARRAY 256 OF CHAR;
		line, res: SIGNED32;
		tempfile: Files.File;
		res2 : SIGNED16;
	BEGIN
		Oberon.GetSelection(T, beg, end, time);
		D := Desktops.CurDoc(Gadgets.context);
		T2 := D.dsc(TextGadgets.Frame).text;
		GetArcName(arcname);
		Texts.WriteString(W, "Zip.");
		CASE action OF
		| EXTRACT: Texts.WriteString(W,"Extract ");
		| OPEN: Texts.WriteString(W,"Open ");
		END;
		Texts.WriteString(W, arcname);
		Texts.Append(Oberon.Log, W.buf);
		IF time # -1 THEN
			Texts.OpenScanner(S, T, beg); Texts.Scan(S);
			arc := Zip.OpenArchive(arcname, res);
			CASE res OF
			| Zip.Ok:
				Texts.WriteLn(W);
				WHILE (S.class IN {Texts.Name, Texts.String}) & (Texts.Pos(S) <= end + S.len) DO
					COPY(S.s, name);
					ent := Zip.GetEntry(arc, name, res);
					Texts.WriteString(W, " "); Texts.WriteString(W, name);
					line := S.line;
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
								ZipTool.ExtractFile(arc, ent, name, path, overwrite, res)
							ELSE
								ZipTool.OpenFile(arc, ent, name, tempfile, path, overwrite, FALSE, res);
								Files.GetName(tempfile,tempname);
								D:= Documents.Open(tempname);
								COPY(name,D.name);
								Desktops.ShowDoc(D);
								Files.Delete(tempname,res2);
							END;
						| Zip.EntryNotFound: Texts.WriteString(W, " not found"); Texts.WriteLn(W)
						ELSE	(* should not happen *)
						END;
						Texts.Append(Oberon.Log, W.buf);
						IF T2 = T THEN
							WHILE (Texts.Pos(S) <= (end + S.len))  & (line = S.line) DO
								Texts.Scan(S)
							END
						END
					END
				END
			| Zip.FileError: Texts.WriteString(W, " not found"); Texts.WriteLn(W)
			| Zip.NotZipArchiveError: Texts.WriteString(W, " is not a valid zip-archive"); Texts.WriteLn(W)
			END;
			Texts.Append(Oberon.Log, W.buf)
		ELSE
			Texts.WriteLn(W); Texts.Append(Oberon.Log, W.buf)
		END
	END doExtract;

	PROCEDURE Open*;
	BEGIN
		doExtract(OPEN);
	END Open;

	PROCEDURE Extract*;
	BEGIN
		doExtract(EXTRACT);
	END Extract;

	PROCEDURE ExtractAll*;
	VAR
		name: ARRAY 256 OF CHAR;
		arc: Zip.Archive;
		ent: Zip.Entry;
		res: INTEGER;
		n, m: SIGNED32;	(* number of extracted files *)
	BEGIN
		GetArcName(name);
		arc := Zip.OpenArchive(name, res);
		Texts.WriteString(W, "Zip.ExtractAll "); Texts.WriteString(W, name); Texts.Append(Oberon.Log, W.buf);
		CASE res OF
		| Zip.Ok:
			ent := Zip.FirstEntry(arc);
			n := 0; m := 0; Texts.WriteLn(W);
			WHILE ent # NIL DO
				Texts.WriteString(W, " "); Texts.WriteString(W, ent.name); Texts.Append(Oberon.Log, W.buf);
				ZipTool.ExtractFile(arc, ent, ent.name, path, overwrite, res); Texts.Append(Oberon.Log, W.buf);
				IF res = Zip.Ok THEN INC(n) ELSE INC(m) END;
				ent := Zip.NextEntry(ent)
			END;
			Texts.WriteInt(W, n, 0); Texts.WriteString(W, " files extracted");
			IF m # 0 THEN
				Texts.WriteString(W, ", "); Texts.WriteInt(W, m, 0); Texts.WriteString(W, " errors")
			END;
		| Zip.FileError: Texts.WriteString(W, " not found")
		| Zip.NotZipArchiveError: Texts.WriteString(W, " is not a valid zip-archive")
		END;
		Texts.WriteLn(W); Texts.Append(Oberon.Log, W.buf);
	END ExtractAll;

	PROCEDURE Add*;
	VAR
		S: Texts.Scanner; T: Texts.Text; beg, end, time, res: SIGNED32;
		arc: Zip.Archive;
		strategy, level: SIGNED8;
		arcname, oldname, newname: ARRAY 256 OF CHAR;
		D: Documents.Document;
	BEGIN
		Oberon.GetSelection(T, beg, end, time);
		GetArcName(arcname);
		Texts.WriteString(W, "Zip.Add "); Texts.WriteString(W, arcname); Texts.Append(Oberon.Log, W.buf);
		level := Zip.DefaultCompression;
		strategy := Zip.DefaultStrategy;
		IF time # -1 THEN Texts.OpenScanner(S, T, beg); Texts.Scan(S) END;
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
		IF S.class IN {Texts.Name, Texts.String} THEN
			arc := Zip.CreateArchive(arcname, res);
			CASE res OF
			| Zip.Ok:
				Texts.WriteLn(W); Texts.Append(Oberon.Log, W.buf);
				WHILE (S.class IN {Texts.Name, Texts.String}) & (Texts.Pos(S) <= (end + S.len)) DO
					COPY(S.s, oldname); COPY(S.s, newname);
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
						ZipTool.AddFile(arc, oldname, newname, level, strategy, res);
						CASE res OF
						| Zip.Ok: Texts.WriteString(W, " added")
						| Zip.BadName: Texts.WriteString(W, " not found")
						| Zip.EntryAlreadyExists: Texts.WriteString(W, " entry already exists")
						| Zip.DataError: Texts.WriteString(W, " error during compression")
						END;
						Texts.WriteLn(W); Texts.Append(Oberon.Log, W.buf)
					END
				END;
				D := Desktops.CurDoc(Gadgets.context);
				Texts.Delete(D.dsc(TextGadgets.Frame).text, 0, D.dsc(TextGadgets.Frame).text.len - 1);
				ZipTool.WriteDirectory(W, arcname, TRUE, TRUE, res);
				Texts.Append(D.dsc(TextGadgets.Frame).text, W.buf)
			| Zip.FileError: Texts.WriteString(W, " not found"); Texts.WriteLn(W)
			| Zip.NotZipArchiveError: Texts.WriteString(W, " is not a valid zip-archive"); Texts.WriteLn(W)
			END;
			Texts.Append(Oberon.Log, W.buf)
		END
	END Add;

	PROCEDURE Delete*;
	VAR
		name: ARRAY 256 OF CHAR;
		S: Texts.Scanner; T, T2: Texts.Text; beg, end, time: SIGNED32;
		D: Documents.Document;
		arc: Zip.Archive;
		ent: Zip.Entry;
		line, res: SIGNED32;
	BEGIN
		Oberon.GetSelection(T, beg, end, time);
		GetArcName(name);
		Texts.WriteString(W, "Zip.Delete "); Texts.WriteString(W, name); Texts.Append(Oberon.Log, W.buf);
		D := Desktops.CurDoc(Gadgets.context);
		T2 := D.dsc(TextGadgets.Frame).text;
		IF time # -1 THEN
			Texts.OpenScanner(S, T, beg); Texts.Scan(S);
			GetArcName(name);
			arc := Zip.OpenArchive(name, res);
			CASE res OF
			| Zip.Ok:
				Texts.WriteLn(W);
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
					IF T2 = T THEN
						line := S.line;
						WHILE (Texts.Pos(S) <= (end + S.len))  & (line = S.line) DO
							Texts.Scan(S)
						END
					ELSE
						Texts.Scan(S)
					END
				END;
				Texts.Append(Oberon.Log, W.buf);
				Texts.Delete(T2, 0, T2.len - 1);
				ZipTool.WriteDirectory(W, name, TRUE, TRUE, res);
				Texts.Append(T2, W.buf)
			| Zip.FileError: Texts.WriteString(W, " not found"); Texts.WriteLn(W)
			| Zip.NotZipArchiveError: Texts.WriteString(W, " is not a valid zip-archive"); Texts.WriteLn(W)
			END;
			Texts.Append(Oberon.Log, W.buf);
		ELSE
			Texts.WriteLn(W);
			Texts.Append(Oberon.Log, W.buf)
		END
	END Delete;

	PROCEDURE DocHandler(D: Objects.Object; VAR M: Objects.ObjMsg);
	BEGIN
		WITH D: Documents.Document DO
			IF M IS Objects.AttrMsg THEN
				WITH M: Objects.AttrMsg DO
					IF M.id = Objects.get THEN
						IF M.name = "Gen" THEN
							M.class := Objects.String; M.s := "ZipDocs.NewDoc"; M.res := 0
						ELSE
							TextDocs.DocHandler(D, M)
						END
					ELSE
						TextDocs.DocHandler(D, M)
					END
				END
			ELSIF M IS Objects.LinkMsg THEN
				WITH M: Objects.LinkMsg DO
					IF M.id = Objects.get THEN
						IF M.name = "DeskMenu" THEN
							M.obj := Gadgets.CopyPublicObject("ZipDocs.DeskMenu", TRUE);
							IF M.obj = NIL THEN M.obj := Desktops.NewMenu(Menu) END;
							M.res := 0
						ELSIF M.name = "SystemMenu" THEN
							M.obj := Gadgets.CopyPublicObject("ZipDocs.SystemMenu", TRUE);
							IF M.obj = NIL THEN M.obj := Desktops.NewMenu(Menu) END;
							M.res := 0
						ELSIF M.name = "UserMenu" THEN
							M.obj := Gadgets.CopyPublicObject("ZipDocs.UserMenu", TRUE);
							IF M.obj = NIL THEN M.obj := Desktops.NewMenu(Menu) END;
							M.res := 0
						ELSE
							TextDocs.DocHandler(D, M)
						END
					ELSE
						TextDocs.DocHandler(D, M)
					END
				END
			ELSE
				TextDocs.DocHandler(D, M)
			END
		END
	END DocHandler;

	PROCEDURE LoadDoc(D: Documents.Document);
		VAR res: INTEGER;
	BEGIN
		ZipTool.WriteDirectory(W, D.name, TRUE, TRUE, res);
		Texts.Append(D.dsc(TextGadgets.Frame).text, W.buf)
	END LoadDoc;

	PROCEDURE NewDoc*;
		VAR D: Objects.Object;
	BEGIN
		D := Gadgets.CreateObject("TextDocs.NewDoc");
		WITH D: Documents.Document DO
			D.Load := LoadDoc; D.Store := NIL;
			D.handle := DocHandler
		END;
		Objects.NewObj := D
	END NewDoc;

BEGIN
	Texts.OpenWriter(W)
END ZipDocs.

System.Set Gadgets.Documents zip := ZipDocs.NewDoc ~
System.Set MIME application/zip := zip ~

Documents = {
	zip = ZipDocs.NewDoc
}

MIME = {
 "application/zip" = zip
}
