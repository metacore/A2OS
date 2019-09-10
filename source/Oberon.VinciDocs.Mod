(* ETH Oberon, Copyright 2001 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

MODULE VinciDocs IN Oberon; (** portable *)	(* eos  *)

	(**
		documents for displaying graphical descriptions
	**)

	IMPORT
		Files, Objects, Display, Texts, Oberon, Attributes, Links, Strings, Gadgets, Documents, Desktops,
		TextGadgets, TextGadgets0, Scheme, Vinci, VinciGadgets, GfxPS;


	CONST
		GraphicMenuBar = "Desktops.Copy[Copy] VinciDocs.ShowText[Source] Desktops.StoreDoc[Store]";
		TextMenuBar = "Desktops.Copy[Copy] VinciDocs.ShowGraphics[Display] Desktops.StoreDoc[Store]";


	VAR
		W: Texts.Writer;


	(**--- Documents ---**)

	PROCEDURE LoadAttachments (VAR r: Files.Rider; doc: Documents.Document);
		VAR cm: Gadgets.CmdMsg;
	BEGIN
		Documents.LoadAttachments(r, doc.attr, doc.link);
		IF doc.link # NIL THEN
			Objects.Stamp(cm); cm.cmd := "PREPARE"; cm.res := -1; cm.dlink := doc;
			Links.Broadcast(doc.link, cm)
		END
	END LoadAttachments;

	PROCEDURE Load (doc: Documents.Document);
		VAR
			text: Texts.Text; file: Files.File; r: Files.Rider; tag, x, y, w, h: SIGNED16; gen: ARRAY 64 OF CHAR; ch: CHAR;
			pos, len: SIGNED32; body: Scheme.Object; tframe: TextGadgets.Frame;
			gframe: VinciGadgets.Frame;
	BEGIN
		NEW(text);
		file := Files.Old(doc.name);
		IF file = NIL THEN
			Texts.Open(text, "")
		ELSE
			Files.Set(r, file, 0);
			Files.ReadInt(r, tag);
			IF tag = Documents.Id THEN
				Files.ReadString(r, gen);
				Files.ReadInt(r, x); Files.ReadInt(r, y); Files.ReadInt(r, w); Files.ReadInt(r, h);
				IF gen = "VinciDocs.New" THEN
					doc.X := x; doc.Y := y; doc.W := w; doc.H := h
				END;
				Files.Read(r, ch);
				IF ch = 0F7X THEN
					LoadAttachments(r, doc);
					Files.Read(r, ch)
				END;
				IF (ch = Texts.TextBlockId) OR (ch = 1X) THEN
					pos := Files.Pos(r);
					Texts.Load(text, file, pos, len)
				ELSE
					Texts.Open(text, "")
				END
			ELSE
				Texts.Open(text, doc.name)
			END
		END;
		VinciGadgets.Parse(text, 0, body);
		IF body = NIL THEN	(* not a valid description *)
			NEW(tframe); TextGadgets.Init(tframe, text, FALSE);
			Documents.Init(doc, tframe)
		ELSE
			NEW(gframe); VinciGadgets.Init(gframe, text); gframe.body := body;
			IF pos + len < Files.Length(file) THEN
				Files.Set(r, file, pos + len);
				Files.ReadInt(r, gframe.ox); Files.ReadInt(r, gframe.oy); DEC(gframe.oy, gframe.H);
				Files.ReadReal(r, gframe.scale)
			END;
			Documents.Init(doc, gframe)
		END
	END Load;

	PROCEDURE Store (doc: Documents.Document);
		VAR
			file: Files.File; bak: ARRAY 64 OF CHAR; res: SIGNED16; r: Files.Rider; pos, len: SIGNED32;
			obj: Objects.Object; frame: VinciGadgets.Frame;
	BEGIN
		Texts.WriteString(W, "Store ");
		Texts.Write(W, 22X); Texts.WriteString(W, doc.name); Texts.Write(W, 22X);
		Texts.Append(Oberon.Log, W.buf);
		file := Files.New(doc.name);
		IF file # NIL THEN
			(* keep backup *)
			COPY(doc.name, bak);
			Strings.Append(bak, ".Bak");
			Files.Rename(doc.name, bak, res);
			Files.Set(r, file, 0); Files.WriteInt(r, Documents.Id); Files.WriteString(r, "VinciDocs.New");
			Files.WriteInt(r, doc.X); Files.WriteInt(r, doc.Y);
			Files.WriteInt(r, doc.W); Files.WriteInt(r, doc.H);
			IF (doc.attr # NIL) OR (doc.link # NIL) THEN
				Documents.StoreAttachments(r, doc.attr, doc.link)
			END;
			pos := Files.Pos(r);
			Links.GetLink(doc.dsc, "Model", obj);
			ASSERT((obj # NIL) & (obj IS Texts.Text));
			Texts.Store(obj(Texts.Text), file, pos, len);
			IF doc.dsc IS VinciGadgets.Frame THEN
				frame := doc.dsc(VinciGadgets.Frame);
				Files.Set(r, file, pos + len);
				Files.WriteInt(r, frame.ox); Files.WriteInt(r, frame.oy + frame.H);
				Files.WriteReal(r, frame.scale)
			END;
			Files.Register(file)
		ELSE Texts.WriteString(W, " -- illegal filename")
		END;
		Texts.WriteLn(W); Texts.Append(Oberon.Log, W.buf)
	END Store;

	PROCEDURE Handle (obj: Objects.Object; VAR msg: Objects.ObjMsg);
		VAR doc: Documents.Document;
	BEGIN
		doc := obj(Documents.Document);
		IF msg IS Objects.AttrMsg THEN
			WITH msg: Objects.AttrMsg DO
				IF msg.id = Objects.get THEN
					IF msg.name = "Gen" THEN msg.class := Objects.String; msg.s := "VinciDocs.New"; msg.res := 0
					ELSIF msg.name = "Adaptive" THEN msg.class := Objects.Bool; msg.b := TRUE; msg.res := 0
					ELSE Documents.Handler(doc, msg)
					END
				ELSE Documents.Handler(doc, msg)
				END
			END
		ELSIF msg IS Objects.LinkMsg THEN
			WITH msg: Objects.LinkMsg DO
				IF (msg.id = Objects.get) &
					((msg.name = "DeskMenu") OR (msg.name = "SystemMenu") OR (msg.name = "UserMenu"))
				THEN
					IF (doc.dsc # NIL) & (doc.dsc IS VinciGadgets.Frame) THEN msg.obj := Desktops.NewMenu(GraphicMenuBar)
					ELSE msg.obj := Desktops.NewMenu(TextMenuBar)
					END;
					msg.res := 0
				ELSE
					Documents.Handler(doc, msg)
				END
			END
		ELSIF msg IS Display.DisplayMsg THEN
			WITH msg: Display.DisplayMsg DO
				IF (msg.device = Display.printer) & (msg.id = Display.contents) & (doc.dsc # NIL) & (doc.dsc IS TextGadgets.Frame) THEN
					TextGadgets0.PrintText(doc.dsc(TextGadgets0.Frame), doc.name)
				ELSE
					Documents.Handler(doc, msg)
				END
			END
		ELSE
			Documents.Handler(doc, msg)
		END
	END Handle;

	PROCEDURE Init* (doc: Documents.Document);
	BEGIN
		doc.handle := Handle; doc.Load := Load; doc.Store := Store;
		doc.X := 0; doc.Y := 0; doc.W := Display.Width DIV 3; doc.H := Display.Height DIV 2
	END Init;

	PROCEDURE New*;
		VAR doc: Documents.Document;
	BEGIN
		NEW(doc); Init(doc);
		Objects.NewObj := doc
	END New;

	PROCEDURE Show* (text: Texts.Text; CONST name: ARRAY OF CHAR);
		VAR doc: Documents.Document; body: Scheme.Object; tframe: TextGadgets.Frame; gframe: VinciGadgets.Frame;
	BEGIN
		NEW(doc); Init(doc);
		COPY(name, doc.name);
		VinciGadgets.Parse(text, 0, body);
		IF body = NIL THEN
			NEW(tframe); TextGadgets.Init(tframe, text, FALSE);
			Documents.Init(doc, tframe)
		ELSE
			NEW(gframe); VinciGadgets.Init(gframe, text); gframe.body := body;
			Documents.Init(doc, gframe)
		END;
		Desktops.ShowDoc(doc)
	END Show;

	PROCEDURE Open*;
		VAR s: Texts.Scanner; text: Texts.Text; name: ARRAY 64 OF CHAR; beg, end, time: SIGNED32; buf: Texts.Buffer;
	BEGIN
		Texts.OpenScanner(s, Oberon.Par.text, Oberon.Par.pos); Texts.Scan(s);
		text := NIL; name := "";
		IF s.class = Texts.Char THEN
			IF s.c = "*" THEN
				text := Oberon.MarkedText()
			ELSIF s.c = "@" THEN
				Oberon.GetSelection(text, beg, end, time);
				IF time >= 0 THEN
					NEW(buf); Texts.OpenBuf(buf);
					Texts.Save(text, beg, end, buf);
					NEW(text); Texts.Open(text, "");
					Texts.Append(text, buf)
				END
			ELSIF s.c = "^" THEN
				Oberon.GetSelection(text, beg, end, time);
				IF time >= 0 THEN
					Texts.OpenScanner(s, text, beg); text := NIL;
					Texts.Scan(s)
				END
			END
		END;
		IF s.class IN {Texts.Name, Texts.String} THEN
			COPY(s.s, name);
			NEW(text); Texts.Open(text, s.s);
			IF text.len = 0 THEN text := NIL END
		END;
		IF text # NIL THEN
			Show(text, name)
		END
	END Open;

	PROCEDURE ShowText*;
		VAR doc: Documents.Document; obj, button: Objects.Object; frame: TextGadgets.Frame;
	BEGIN
		IF Desktops.IsInMenu(Gadgets.context) THEN
			doc := Desktops.CurDoc(Gadgets.context);
			Links.GetLink(doc.dsc, "Model", obj);
			IF (obj # NIL) & (obj IS Texts.Text) THEN
				button := Gadgets.executorObj;
				Attributes.SetString(button, "Caption", "Display");
				Attributes.SetString(button, "Cmd", "VinciDocs.ShowGraphics");
				Gadgets.Update(button);
				NEW(frame); TextGadgets.Init(frame, obj(Texts.Text), FALSE);
				frame.X := doc.dsc.X; frame.Y := doc.dsc.Y; frame.W := doc.dsc.W; frame.H := doc.dsc.H;
				doc.dsc := frame;
				Gadgets.Update(frame)
			END
		END
	END ShowText;

	PROCEDURE ShowGraphics*;
		VAR doc: Documents.Document; obj, button: Objects.Object; body: Scheme.Object; frame: VinciGadgets.Frame;
	BEGIN
		IF Desktops.IsInMenu(Gadgets.context) THEN
			doc := Desktops.CurDoc(Gadgets.context);
			Links.GetLink(doc.dsc, "Model", obj);
			IF (obj # NIL) & (obj IS Texts.Text) THEN
				VinciGadgets.Parse(obj(Texts.Text), 0, body);
				IF body # NIL THEN
					button := Gadgets.executorObj;
					Attributes.SetString(button, "Caption", "Source");
					Attributes.SetString(button, "Cmd", "VinciDocs.ShowText");
					Gadgets.Update(button);
					NEW(frame); VinciGadgets.Init(frame, obj); frame.body := body;
					frame.X := doc.dsc.X; frame.Y := doc.dsc.Y; frame.W := doc.dsc.W; frame.H := doc.dsc.H;
					doc.dsc := frame;
					Gadgets.Update(frame)
				END
			END
		END
	END ShowGraphics;

	PROCEDURE ToEPS*;
		VAR
			doc: Documents.Document; obj: Objects.Object; body: Scheme.Object; s: Attributes.Scanner; file: Files.File;
			level2: BOOLEAN; dpi: SIGNED32; eps: GfxPS.Context; ctxt: Vinci.Context;
	BEGIN
		doc := Documents.MarkedDoc();
		Links.GetLink(doc.dsc, "Model", obj);
		IF (obj # NIL) & (obj IS Texts.Text) THEN
			VinciGadgets.Parse(obj(Texts.Text), 0, body);
			IF ~Scheme.IsNull(body) THEN
				Attributes.OpenScanner(s, Oberon.Par.text, Oberon.Par.pos); Attributes.Scan(s);
				IF s.class = Attributes.Name THEN
					NEW(file); file := Files.New(s.s);
					IF file # NIL THEN
						Texts.WriteString(W, s.s);
						level2 := FALSE; dpi := 300; Attributes.Scan(s);
						WHILE (s.class = Attributes.Char) & (s.c = Oberon.OptionChar) DO
							Attributes.Scan(s);
							IF (s.class = Attributes.Name) & (s.s = "level2") THEN level2 := TRUE
							ELSIF (s.class = Attributes.Name) & (s.s = "dpi") THEN
								Attributes.Scan(s);
								IF (s.class = Attributes.Char) & (s.c = "=") THEN Attributes.Scan(s) END;
								IF s.class = Attributes.Int THEN dpi := s.i END
							END
						END;
						NEW(eps); GfxPS.InitEPS(eps, level2, dpi);
						GfxPS.Open(eps, file);
						NEW(ctxt); Vinci.MakeContext(ctxt, Scheme.nil, eps);
						Scheme.EvaluateSequence(ctxt, Vinci.globals, body);
						IF ctxt.failed THEN
							Vinci.ShowError
						ELSE
							GfxPS.Close(eps);
							Files.Register(file);
							Texts.WriteString(W, " done")
						END;
						Texts.WriteLn(W); Texts.Append(Oberon.Log, W.buf)
					END
				END
			END
		END
	END ToEPS;


BEGIN
	Texts.OpenWriter(W)
END VinciDocs.


VinciDocs.Open *
VinciDocs.Open ^
VinciDocs.ToEPS vinci.eps \level2 \dpi=600
(VinciDocs.New)
