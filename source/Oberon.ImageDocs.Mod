(* ETH Oberon, Copyright 2001 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

MODULE ImageDocs IN Oberon; (** portable **)	(* eos  *)

	(**
		Image documents
	**)

	IMPORT
		Files, Objects, Texts, Oberon, Strings, Documents, Desktops, Images, ImageGadgets;


	CONST
		MenuString = "Desktops.Copy[Copy] Desktops.StoreDoc[Store]";


	VAR
		W: Texts.Writer;


	(**--- Documents ---**)

	PROCEDURE LoadDoc (doc: Documents.Document);
		VAR img: Images.Image; done: BOOLEAN; main: ImageGadgets.Frame;
	BEGIN
		NEW(img); Images.Load(img, doc.name, done);
		IF ~done THEN
			Texts.WriteString(W, "can't load "); Texts.Write(W, 22X); Texts.WriteString(W, doc.name); Texts.Write(W, 22X);
			Texts.WriteLn(W); Texts.Append(Oberon.Log, W.buf);
			img := NIL
		END;
		NEW(main); ImageGadgets.Init(main, img); doc.W := main.W; doc.H := main.H;
		Documents.Init(doc, main)
	END LoadDoc;

	PROCEDURE StoreDoc (doc: Documents.Document);
		VAR lm: Objects.LinkMsg; img: Images.Image; bak: ARRAY 64 OF CHAR; res: SIGNED16; done: BOOLEAN;
	BEGIN
		lm.id := Objects.get; lm.name := "Model"; lm.res := -1; doc.dsc.handle(doc.dsc, lm);
		IF (lm.res >= 0) & (lm.obj # NIL) & (lm.obj IS Images.Image) THEN
			img := lm.obj(Images.Image);
			COPY(doc.name, bak);
			Strings.Append(bak, ".Bak");
			Files.Rename(doc.name, bak, res);
			Texts.WriteString(W, "storing "); Texts.Write(W, 22X); Texts.WriteString(W, doc.name); Texts.Write(W, 22X);
			Images.Store(img, doc.name, done);
			IF ~done THEN
				Files.Rename(bak, doc.name, res);
				Texts.WriteString(W, " failed")
			END;
			Texts.WriteLn(W); Texts.Append(Oberon.Log, W.buf)
		END
	END StoreDoc;

	PROCEDURE HandleDoc (obj: Objects.Object; VAR msg: Objects.ObjMsg);
	BEGIN
		IF msg IS Objects.AttrMsg THEN
			WITH msg: Objects.AttrMsg DO
				IF (msg.id = Objects.get) & (msg.name = "Gen") THEN
					msg.class := Objects.String; msg.s := "ImageDocs.NewDoc"; msg.res := 0
				ELSE
					Documents.Handler(obj, msg)
				END
			END
		ELSIF msg IS Objects.LinkMsg THEN
			WITH msg: Objects.LinkMsg DO
				IF (msg.id = Objects.get) & ((msg.name = "DeskMenu") OR (msg.name = "SystemMenu") OR (msg.name = "UserMenu")) THEN
					msg.obj := Desktops.NewMenu(MenuString); msg.res := 0
				ELSE
					Documents.Handler(obj, msg)
				END
			END
		ELSE
			Documents.Handler(obj, msg)
		END
	END HandleDoc;

	PROCEDURE InitDoc* (doc: Documents.Document);
	BEGIN
		doc.handle := HandleDoc; doc.Load := LoadDoc; doc.Store := StoreDoc;
		doc.W := 100; doc.H := 100
	END InitDoc;

	PROCEDURE NewDoc*;
		VAR doc: Documents.Document;
	BEGIN
		NEW(doc); InitDoc(doc);
		Objects.NewObj := doc
	END NewDoc;

	PROCEDURE Open*;
		VAR s: Texts.Scanner; text: Texts.Text; beg, end, time: SIGNED32; doc: Documents.Document;
	BEGIN
		Texts.OpenScanner(s, Oberon.Par.text, Oberon.Par.pos); Texts.Scan(s);
		IF (s.class = Texts.Char) & (s.c = "^") THEN
			Oberon.GetSelection(text, beg, end, time);
			IF time >= 0 THEN
				Texts.OpenScanner(s, text, beg); Texts.Scan(s)
			END
		END;
		IF s.class IN {Texts.Name, Texts.String} THEN
			NEW(doc); InitDoc(doc); COPY(s.s, doc.name);
			doc.Load(doc);
			Desktops.ShowDoc(doc)
		END
	END Open;


BEGIN
	Texts.OpenWriter(W)
END ImageDocs.

ImageDocs.Open Clown.Pict
ImageDocs.Open ^