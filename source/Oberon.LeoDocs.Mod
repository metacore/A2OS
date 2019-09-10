(* ETH Oberon, Copyright 2001 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

MODULE LeoDocs IN Oberon; (** portable **)	(* eos  *)

	(**
		Leonardo documents
	**)

	IMPORT
		Objects, Files, Display, Texts, Oberon, Strings, Attributes, Links, Gadgets, Documents, Desktops,
		Gfx, GfxPS, Leonardo, LeoFrames, LeoTools;


	CONST
		MenuBar = "Desktops.Copy[Copy] LeoDocs.Undo[Undo] LeoDocs.Redo[Redo] Desktops.StoreDoc[Store]";


	TYPE
		(* message for clearing document edited state *)
		StoreMsg = RECORD (Display.FrameMsg)
			fig: Leonardo.Figure;
		END;


	VAR
		W: Texts.Writer;


	(**--- Documents ---**)

	PROCEDURE Load (doc: Documents.Document);
		VAR
			main: LeoFrames.Frame; file: Files.File; r: Files.Rider; tag, ref: SIGNED16; name: ARRAY 64 OF CHAR; ch: CHAR;
			lib: Objects.Library; len: SIGNED32; obj: Objects.Object; ff: Gadgets.Frame; fig: Leonardo.Figure;
	BEGIN
		main := NIL;
		file := Files.Old(doc.name);
		IF file # NIL THEN
			Files.Set(r, file, 0); Files.ReadInt(r, tag);
			IF tag = Documents.Id THEN
				Files.ReadString(r, name);
				Files.ReadInt(r, doc.X); Files.ReadInt(r, doc.Y);
				Files.ReadInt(r, doc.W); Files.ReadInt(r, doc.H);
				Files.ReadInt(r, ref);
				Files.Read(r, ch);
				IF ch = Objects.LibBlockId THEN
					NEW(lib); Objects.OpenLibrary(lib);
					Objects.LoadLibrary(lib, file, Files.Pos(r), len);
					lib.GetObj(lib, ref, obj);
					IF (obj # NIL) & (obj IS LeoFrames.Frame) THEN
						main := obj(LeoFrames.Frame)
					ELSIF (obj # NIL) & (obj IS Gadgets.Frame) THEN
						ff := obj(Gadgets.Frame);
						IF (ff.obj # NIL) & (ff.obj IS Leonardo.Figure) THEN
							NEW(main); LeoTools.InitFrame(main, ff.obj(Leonardo.Figure))
						END
					END
				END
			END
		END;
		IF main = NIL THEN	(* open with empty figure *)
			IF doc.name = "" THEN doc.name := "Unnamed.Fig" END;
			NEW(fig); Leonardo.InitFigure(fig);
			NEW(main); LeoTools.InitFrame(main, fig)
		END;
		Documents.Init(doc, main)
	END Load;

	PROCEDURE Store (doc: Documents.Document);
		VAR
			bak, gen: ARRAY 64 OF CHAR; res: SIGNED16; frame: Display.Frame; main: LeoFrames.Frame;
			bm: Objects.BindMsg; file: Files.File; r: Files.Rider; len: SIGNED32; sm: StoreMsg;
	BEGIN
		Texts.WriteString(W, "Store ");
		Texts.Write(W, 22X); Texts.WriteString(W, doc.name); Texts.Write(W, 22X);
		Texts.Append(Oberon.Log, W.buf);

		(* keep backup *)
		COPY(doc.name, bak);
		Strings.Append(bak, ".Bak");
		Files.Rename(doc.name, bak, res);

		frame := doc.dsc;
		IF (frame # NIL) & (frame IS LeoFrames.Frame) THEN
			main := frame(LeoFrames.Frame);
			NEW(bm.lib); Objects.OpenLibrary(bm.lib);
			main.handle(main, bm);

			file := Files.New(doc.name);
			IF file # NIL THEN
				Files.Set(r, file, 0);
				Files.WriteInt(r, Documents.Id);
				Attributes.GetString(doc, "Gen", gen);
				Files.WriteString(r, gen);
				Files.WriteInt(r, doc.X); Files.WriteInt(r, doc.Y);
				Files.WriteInt(r, doc.W); Files.WriteInt(r, doc.H);
				Files.WriteInt(r, main.ref);
				Objects.StoreLibrary(bm.lib, file, Files.Pos(r), len);
				Files.Register(file);
				sm.F := NIL; sm.fig := main.obj(Leonardo.Figure);
				Display.Broadcast(sm)
			ELSE
				Texts.WriteString(W, " - invalid document name")
			END
		ELSE
			Texts.WriteString(W, " - unknown content frame")
		END;
		Texts.WriteLn(W); Texts.Append(Oberon.Log, W.buf)
	END Store;

	PROCEDURE HandleAttr (doc: Documents.Document; VAR msg: Objects.AttrMsg);
	BEGIN
		IF msg.id = Objects.get THEN
			IF msg.name = "Gen" THEN msg.class := Objects.String; msg.s := "LeoDocs.New"; msg.res := 0
			ELSIF msg.name = "Adaptive" THEN msg.class := Objects.Bool; msg.b := TRUE; msg.res := 0
			ELSE Documents.Handler(doc, msg)
			END
		ELSE Documents.Handler(doc, msg)
		END
	END HandleAttr;

	PROCEDURE HandleLink (doc: Documents.Document; VAR msg: Objects.LinkMsg);
	BEGIN
		IF msg.id = Objects.get THEN
			IF msg.name = "DeskMenu" THEN
				msg.obj := Gadgets.CopyPublicObject("Leonardo.DeskMenu", TRUE);
				IF msg.obj = NIL THEN msg.obj := Desktops.NewMenu(MenuBar) END;
				msg.res := 0
			ELSIF msg.name = "SystemMenu" THEN
				msg.obj := Gadgets.CopyPublicObject("Leonardo.SystemMenu", TRUE);
				IF msg.obj = NIL THEN msg.obj := Desktops.NewMenu(MenuBar) END;
				msg.res := 0
			ELSIF msg.name = "UserMenu" THEN
				msg.obj := Gadgets.CopyPublicObject("Leonardo.UserMenu", TRUE);
				IF msg.obj = NIL THEN msg.obj := Desktops.NewMenu(MenuBar) END;
				msg.res := 0
			ELSE
				Documents.Handler(doc, msg)
			END
		ELSE
			Documents.Handler(doc, msg)
		END
	END HandleLink;

	PROCEDURE ReplaceCaption (dlink: Objects.Object; CONST from, to: ARRAY OF CHAR);
		VAR menu, dsc: Display.Frame; s: ARRAY 64 OF CHAR;
	BEGIN
		menu := Desktops.CurMenu(dlink);
		IF menu # NIL THEN
			dsc := menu.dsc;
			WHILE dsc # NIL DO
				Attributes.GetString(dsc, "Caption", s);
				IF s = from THEN
					Attributes.SetString(dsc, "Caption", to);
					Gadgets.Update(dsc);
					dsc := NIL
				ELSE
					dsc := dsc.next
				END
			END
		END
	END ReplaceCaption;

	(** document handler **)
	PROCEDURE Handle* (obj: Objects.Object; VAR msg: Objects.ObjMsg);
		VAR doc: Documents.Document; main: LeoFrames.Frame;
	BEGIN
		doc := obj(Documents.Document);
		IF msg IS Leonardo.UpdateMsg THEN
			WITH msg: Leonardo.UpdateMsg DO
				main := doc.dsc(LeoFrames.Frame);
				IF (main.obj = msg.fig) & ~(16 IN doc.state) THEN
					INCL(doc.state, 16);
					ReplaceCaption(msg.dlink, "Store", "Store!")
				END;
				Documents.Handler(doc, msg)
			END
		ELSIF msg IS StoreMsg THEN
			WITH msg: StoreMsg DO
				main := doc.dsc(LeoFrames.Frame);
				IF (msg.fig = main.obj) & (16 IN doc.state) THEN
					EXCL(doc.state, 16);
					ReplaceCaption(msg.dlink, "Store!", "Store")
				END;
				Documents.Handler(doc, msg)
			END
		ELSIF msg IS Objects.AttrMsg THEN
			HandleAttr(doc, msg(Objects.AttrMsg))
		ELSIF msg IS Objects.LinkMsg THEN
			HandleLink(doc, msg(Objects.LinkMsg))
		ELSE
			Documents.Handler(doc, msg)
		END
	END Handle;

	(** initialize document **)
	PROCEDURE Init* (doc: Documents.Document);
	BEGIN
		doc.handle := Handle;
		doc.Load := Load; doc.Store := Store;
		doc.X := 0; doc.W := Display.Width DIV 2; doc.H := Display.Height DIV 2
	END Init;

	(** document generator **)
	PROCEDURE New*;
		VAR doc: Documents.Document;
	BEGIN
		NEW(doc); Init(doc);
		Objects.NewObj := doc
	END New;

	(** return new document for figure ready for displaying **)
	PROCEDURE Make* (fig: Leonardo.Figure): Documents.Document;
		VAR frame: LeoFrames.Frame; doc: Documents.Document;
	BEGIN
		NEW(frame); LeoTools.InitFrame(frame, fig);
		NEW(doc); Init(doc); doc.name := "Unnamed.Fig";
		Documents.Init(doc, frame);
		RETURN doc
	END Make;

	(** open document with figure **)
	PROCEDURE Show* (fig: Leonardo.Figure; CONST name: ARRAY OF CHAR);
		VAR doc: Documents.Document;
	BEGIN
		doc := Make(fig); COPY(name, doc.name);
		Desktops.ShowDoc(doc)
	END Show;

	(** undo last operation **)
	PROCEDURE Undo*;
		VAR doc: Documents.Document; model: Objects.Object;
	BEGIN
		doc := Desktops.CurDoc(Gadgets.context);
		IF (doc # NIL) & (doc.dsc # NIL) THEN
			Links.GetLink(doc.dsc, "Model", model);
			IF (model # NIL) & (model IS Leonardo.Figure) THEN
				Leonardo.Undo(model(Leonardo.Figure))
			END
		END
	END Undo;

	(** redo most recently undone operation **)
	PROCEDURE Redo*;
		VAR doc: Documents.Document; model: Objects.Object;
	BEGIN
		doc := Desktops.CurDoc(Gadgets.context);
		IF (doc # NIL) & (doc.dsc # NIL) THEN
			Links.GetLink(doc.dsc, "Model", model);
			IF (model # NIL) & (model IS Leonardo.Figure) THEN
				Leonardo.Redo(model(Leonardo.Figure))
			END
		END
	END Redo;


	(**--- Printing ---**)

	(** print document to PostScript file **)
	PROCEDURE PrintPS*;
		VAR
			s: Attributes.Scanner; name: ARRAY 64 OF CHAR; landscape, level2: BOOLEAN; dpi: SIGNED32;
			doc: Documents.Document; frame: LeoFrames.Frame; w, h: FLOAT32; ps: GfxPS.Context; file: Files.File;
	BEGIN
		Attributes.OpenScanner(s, Oberon.Par.text, Oberon.Par.pos); Attributes.Scan(s);
		IF s.class IN {Attributes.Name, Attributes.String} THEN
			COPY(s.s, name); landscape := FALSE; level2 := FALSE; dpi := 600; doc := NIL;
			Attributes.Scan(s);
			WHILE (s.class = Attributes.Char) & (s.c = Oberon.OptionChar) DO
				Attributes.Scan(s);
				IF s.class = Attributes.Name THEN
					IF (s.s = "ls") OR (s.s = "landscape") THEN landscape := TRUE END;
					Attributes.Scan(s)
				ELSIF s.class = Attributes.Int THEN
					IF s.i = 1 THEN level2 := FALSE
					ELSIF s.i = 2 THEN level2 := TRUE
					ELSIF s.i = 300 THEN dpi := 300
					ELSIF s.i = 600 THEN dpi := 600
					END;
					Attributes.Scan(s)
				END
			END;
			IF (s.class = Attributes.Char) & (s.c = "*") THEN
				doc := Documents.MarkedDoc()
			END;
			IF (doc # NIL) & (doc.dsc # NIL) & (doc.dsc IS LeoFrames.Frame) THEN
				frame := doc.dsc(LeoFrames.Frame);
				IF (frame.obj # NIL) & (frame.obj IS Leonardo.Figure) THEN
					Attributes.GetReal(frame, "PageW", w);
					Attributes.GetReal(frame, "PageH", h);
					NEW(ps); GfxPS.Init(ps, level2, landscape, 72/91.44 * w, 72/91.44 * h, 0, 0, 0, 0, dpi);
					file := Files.New(name);
					IF file # NIL THEN
						GfxPS.Open(ps, file);
						Gfx.Translate(ps, 0, h);
						Leonardo.Render(frame.obj(Leonardo.Figure), Leonardo.passive, ps);
						GfxPS.ShowPage(ps);
						GfxPS.Close(ps);
						Files.Register(file)
					END
				END
			END
		END
	END PrintPS;


BEGIN
	Texts.OpenWriter(W)
END LeoDocs.
