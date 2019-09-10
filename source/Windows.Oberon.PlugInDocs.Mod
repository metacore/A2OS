(* ETH Oberon, Copyright 2001 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

MODULE PlugInDocs IN Oberon; (** portable *)	(* ejz  *)
	IMPORT FileDir, Win32FS:=WinFS IN A2, Objects, Oberon, Attributes, Gadgets, PlugIns, Documents, Out;

	TYPE
		Request = POINTER TO RECORD (Objects.Object)
			plugin: PlugIns.PlugIn;
			url: PlugIns.URLStr;
			obj: Objects.Object
		END;

	PROCEDURE Exchange(old, new: Documents.Document);
		VAR name: Objects.Name; w, h: SIGNED16;
	BEGIN
		Gadgets.GetObjName(old, name); w := old.W; h := old.H;
		old^ := new^;
		Gadgets.NameObj(old, name); old.W := w; old.H := h;
		Gadgets.Update(old); Gadgets.Update(old.dsc)
	END Exchange;

	PROCEDURE GetStream(doc: Documents.Document; R: Request; stream: PlugIns.Stream; state: SIGNED32): BOOLEAN;
		VAR new: Documents.Document;
	BEGIN
Out.String("GetStream "); Out.Int(state, 0); Out.Ln();
		IF state # PlugIns.Transfering THEN
			doc.handle := R.handle; doc.obj := R.obj;
			IF state # PlugIns.Done THEN
				IF stream = NIL THEN
					NEW(stream); COPY(R.url, stream.url); stream.state := state
				END;
				PlugIns.StreamError(R.plugin, stream)
			ELSIF stream # NIL THEN
				new := Documents.Open(stream.file);
Out.String("GetStream "); Out.String(stream.file); Out.Ln();
				IF (new # NIL) & (new.dsc # NIL) THEN
					Exchange(doc, new)
				ELSE
HALT(100);
					stream.state := PlugIns.OtherError; PlugIns.StreamError(R.plugin, stream)
				END
			ELSE (* wait for update *)
				RETURN FALSE
			END;
			RETURN TRUE
		END;
		RETURN FALSE
	END GetStream;

	PROCEDURE GetHandler(doc: Objects.Object; VAR M: Objects.ObjMsg);
		VAR R: Request; stream: PlugIns.Stream;
	BEGIN
		WITH doc: Documents.Document DO
			R := doc.obj(Request); doc.handle := R.handle; doc.obj := R.obj;
			IF M IS Gadgets.UpdateMsg THEN
				WITH M: Gadgets.UpdateMsg DO
					IF (M.obj # NIL) & (M.obj IS PlugIns.Stream) THEN
						stream := M.obj(PlugIns.Stream);
						IF PlugIns.SameURL(stream.url, R.url) & GetStream(doc, R, stream, stream.state) THEN
							RETURN
						END
					END
				END
			END;
			doc.handle(doc, M);
			doc.handle := GetHandler; doc.obj := R
		END
	END GetHandler;

	(* name url *)
	PROCEDURE Load*;
		VAR
			S: Attributes.Scanner; R: Request;
			obj: Objects.Object; doc: Documents.Document;
			res: INTEGER;
	BEGIN
		Attributes.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos);
		Attributes.Scan(S);
		IF S.class IN {Attributes.Name, Attributes.String} THEN
Out.String("PlugInDocs.Load name "); Out.String(S.s); Out.Ln();
			NEW(R);
			obj := Gadgets.FindObj(Gadgets.context, S.s);
			R.plugin := PlugIns.CurrentPlugIn(Gadgets.context);
			IF (R.plugin # NIL) & (obj # NIL) & (obj IS Documents.Document) THEN
				Attributes.Scan(S); doc := obj(Documents.Document);
				IF S.class IN {Attributes.Name, Attributes.String} THEN
					COPY(S.s, R.url); PlugIns.MakeFullURL(R.plugin, R.url);
Out.String("PlugInDocs.Load URL "); Out.String(R.url); Out.Ln();
					R.handle := doc.handle; R.obj := doc.obj; doc.obj := R;
					doc.handle := GetHandler;
					res := R.plugin.getURL(R.plugin, R.url);
					IF (res # PlugIns.Done) & GetStream(doc, R, NIL, res) THEN
					END
				END
			END
		END
	END Load;

	PROCEDURE PostStream(doc: Documents.Document; R: Request; stream: PlugIns.Stream; state: SIGNED32): BOOLEAN;
	BEGIN
Out.String("PostStream "); Out.Int(state, 0); Out.Ln();
		IF state # PlugIns.Transfering THEN
			doc.handle := R.handle; doc.obj := R.obj;
			IF state # PlugIns.Done THEN
				IF stream = NIL THEN
					NEW(stream); COPY(R.url, stream.url); stream.state := state
				END;
				PlugIns.StreamError(R.plugin, stream)
			END;
			RETURN TRUE
		END;
		RETURN FALSE
	END PostStream;

	PROCEDURE PostHandler(doc: Objects.Object; VAR M: Objects.ObjMsg);
		VAR R: Request; stream: PlugIns.Stream;
	BEGIN
		WITH doc: Documents.Document DO
			R := doc.obj(Request); doc.handle := R.handle; doc.obj := R.obj;
			IF M IS Gadgets.UpdateMsg THEN
				WITH M: Gadgets.UpdateMsg DO
					IF (M.obj # NIL) & (M.obj IS PlugIns.Stream) THEN
						stream := M.obj(PlugIns.Stream);
						IF PlugIns.SameURL(stream.url, R.url) & PostStream(doc, R, stream, stream.state) THEN
							RETURN
						END
					END
				END
			END;
			doc.handle(doc, M);
			doc.handle := PostHandler; doc.obj := R
		END
	END PostHandler;

	PROCEDURE PostNames(VAR url, file: ARRAY OF CHAR);
		VAR i, j, k, l: SIGNED32;
	BEGIN
		Win32FS.GetTempDirectory(file);
		l := 0; WHILE file[l] # 0X DO INC(l) END;
		i := 0; j := l; k := 0;
		WHILE url[i] # 0X DO
			IF url[i] = FileDir.PathChar THEN
				j := l; k := i
			END;
			file[j] := url[i]; INC(j); INC(i)
		END;
		url[k] := 0X; file[j] := 0X
	END PostNames;

	(* name url *)
	PROCEDURE Store*;
		VAR
			S: Attributes.Scanner; R: Request;
			obj: Objects.Object; doc: Documents.Document;
			file, name: FileDir.FileName; res: INTEGER;
	BEGIN
		Attributes.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos);
		Attributes.Scan(S);
		IF S.class IN {Attributes.Name, Attributes.String} THEN
Out.String("PlugInDocs.Store name "); Out.String(S.s); Out.Ln();
			NEW(R);
			obj := Gadgets.FindObj(Gadgets.context, S.s);
			R.plugin := PlugIns.CurrentPlugIn(Gadgets.context);
			IF (R.plugin # NIL) & (obj # NIL) & (obj IS Documents.Document) THEN
				Attributes.Scan(S); doc := obj(Documents.Document);
				IF S.class IN {Attributes.Name, Attributes.String} THEN
					COPY(S.s, R.url); PlugIns.MakeFullURL(R.plugin, R.url);
					file := ""; PostNames(R.url, file);
Out.String("PlugInDocs.Store "); Out.String(file); Out.String(" => "); Out.String(R.url); Out.Ln();
					COPY(doc.name, name); COPY(file, doc.name);
					doc.Store(doc); COPY(name, doc.name);
					R.handle := doc.handle; R.obj := doc.obj; doc.obj := R;
					doc.handle := PostHandler;
					res := R.plugin.postURL(R.plugin, R.url, file);
					IF (res # PlugIns.Done) & PostStream(doc, R, NIL, res) THEN
					END
				END
			END
		END
	END Store;

END PlugInDocs.

Packages.Build
	PACKAGE test.oaf 2.4 "doc:PlugInDocs.Panel" ~

PlugInDocs.Panel	PlugInDocs.Lib
EditTools.OpenAscii test.html

ftp://zeller@lillian/home/zeller/Test.Panel


Packages.Build
	PACKAGE Hello.oaf 2.4 "lib:Hello.TextArea" ~

Hello.Lib

