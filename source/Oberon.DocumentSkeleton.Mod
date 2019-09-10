(* ETH Oberon, Copyright 2001 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

MODULE DocumentSkeleton IN Oberon; (* jm 25.10.93 *)
IMPORT Attributes, Desktops, Display, Documents, Files, Gadgets, Links, Oberon, Objects, Texts, ColorDriver;

CONST Menu = "Desktops.StoreDoc[Store] DocumentSkeleton.Cycle[Cycle]";

VAR W: Texts.Writer;

PROCEDURE Cycle*;
	VAR doc: Documents.Document; F: Gadgets.Frame; col: SIGNED32;
BEGIN
	doc := Desktops.CurDoc(Gadgets.context);
	IF (doc # NIL) & (doc.dsc IS Gadgets.Frame) THEN
		F := doc.dsc(Gadgets.Frame);
		Attributes.GetInt(F, "Color", col);
		Attributes.SetInt(F, "Color", (col + 1) MOD 4);
		Gadgets.Update(F)
	END
END Cycle;

PROCEDURE NextColor (doc: Documents.Document; col: SIGNED16);
	VAR F: Gadgets.Frame;
BEGIN
	F := doc.dsc(Gadgets.Frame);
	Attributes.SetInt(F, "Color", col);
	Gadgets.Update(F)
END NextColor;

PROCEDURE Load (D: Documents.Document);
	VAR
	obj: Objects.Object;
	tag, x, y, w, h, col: SIGNED16;
	name: ARRAY 64 OF CHAR; F: Files.File; R: Files.Rider; ch: CHAR;
	CM: Gadgets.CmdMsg;
BEGIN
	obj := Gadgets.CreateObject("Panels.NewPanel");
	WITH obj: Gadgets.Frame DO
		x := 0; y := 0; w := 250; h := 200; col := 1; (* default *)

		F := Files.Old(D.name);
		IF F # NIL THEN
			Files.Set(R, F, 0);
			Files.ReadInt(R, tag);
			IF tag = Documents.Id THEN
				Files.ReadString(R, name);
				Files.ReadInt(R, x); Files.ReadInt(R, y); Files.ReadInt(R, w); Files.ReadInt(R, h);

				Files.Read(R, ch);
				IF ch = 0F7X THEN (* attachments *)
					Documents.LoadAttachments(R, D.attr, D.link);
					IF D.link # NIL THEN
						CM.cmd := "PREPARE"; CM.res := -1; CM.dlink := D; Objects.Stamp(CM);
						Links.Broadcast(D.link, CM)
					END
				ELSE
					Files.Set(R, F, Files.Pos(R)-1)
				END;
				Files.ReadInt(R, col)
			END
		ELSE (* COPY("DefaultName", D.name) *)
		END;
		D.X := x; D.Y := y; D.W := w; D.H := h;
		Attributes.SetInt(obj, "Color", col);
		Documents.Init(D, obj)
	END
END Load;

PROCEDURE Store (D: Documents.Document);
	VAR obj: Gadgets.Frame; F: Files.File; R: Files.Rider; col: SIGNED32;
BEGIN
	obj := D.dsc(Gadgets.Frame);
	Texts.WriteString(W, "Store "); Texts.Append(Oberon.Log, W.buf);
	IF D.name # "" THEN
		F := Files.New(D.name);
		IF F = NIL THEN HALT(99) END;

		Files.Set(R, F, 0);
		Files.WriteInt(R, Documents.Id); Files.WriteString(R, "DocumentSkeleton.NewDoc");
		Files.WriteInt(R, D.X); Files.WriteInt(R, D.Y);
		Files.WriteInt(R, D.W); Files.WriteInt(R, D.H);

		IF (D.attr # NIL) OR (D.link # NIL) THEN (* attachments *)
			Documents.StoreAttachments(R, D.attr, D.link)
		END;
		Attributes.GetInt(obj, "Color", col);
		Files.WriteInt(R, SHORT(col));
		Files.Register(F);
		Texts.Write(W, 22X); Texts.WriteString(W, D.name); Texts.Write(W, 22X)
	ELSE Texts.WriteString(W, "[Untitled document]")
	END;
	Texts.WriteLn(W); Texts.Append(Oberon.Log, W.buf)
END Store;

PROCEDURE Handler (D: Objects.Object; VAR M: Objects.ObjMsg);
BEGIN
	WITH D: Documents.Document DO
		IF M IS Objects.AttrMsg THEN
			WITH M: Objects.AttrMsg DO
				IF M.id = Objects.get THEN
					IF M.name = "Gen" THEN
						M.class := Objects.String; M.s := "DocumentSkeleton.NewDoc"; M.res := 0
					ELSIF M.name = "Adaptive" THEN
						M.class := Objects.Bool; M.b := FALSE; M.res := 0
					ELSIF M.name = "Icon" THEN
						M.class := Objects.String; M.s := "Icons.Tool"; M.res := 0
					ELSE Documents.Handler(D, M)
					END
				ELSE Documents.Handler(D, M)
				END
			END
		ELSIF M IS Objects.LinkMsg THEN
			WITH M: Objects.LinkMsg DO
				IF (M.id = Objects.get) & (M.name = "DeskMenu") THEN
					M.obj := Gadgets.CopyPublicObject("TestMenus.DeskMenu", TRUE);
					IF M.obj = NIL THEN M.obj := Desktops.NewMenu(Menu) END;
					M.res := 0
				ELSIF (M.id = Objects.get) & (M.name = "SystemMenu") THEN
					M.obj := Gadgets.CopyPublicObject("TestMenus.DeskMenu", TRUE);
					IF M.obj = NIL THEN M.obj := Desktops.NewMenu(Menu) END;
					M.res := 0
				ELSIF (M.id = Objects.get) & (M.name = "UserMenu") THEN
					M.obj := Gadgets.CopyPublicObject("TestMenus.DeskMenu", TRUE);
					IF M.obj = NIL THEN M.obj := Desktops.NewMenu(Menu) END;
					M.res := 0
				ELSE Documents.Handler(D, M)
				END
			END
		ELSIF M IS ColorDriver.ColorMsg THEN
			NextColor(D, M(ColorDriver.ColorMsg).col)
		ELSIF M IS Display.DisplayMsg THEN
			WITH M: Display.DisplayMsg DO
				IF (M.device = Display.printer) & (M.id = Display.contents) & (D.dsc # NIL) THEN
					(* print *)
				ELSE Documents.Handler(D, M)
				END
			END
		ELSE Documents.Handler(D, M)
		END
	END
END Handler;

PROCEDURE NewDoc*;
	VAR D: Documents.Document;
BEGIN
	NEW(D); D.Load := Load; D.Store := Store; D.handle := Handler;
	D.W := 250; D.H := 200; Objects.NewObj := D
END NewDoc;

BEGIN Texts.OpenWriter(W)
END DocumentSkeleton.

Desktops.OpenDoc (DocumentSkeleton.NewDoc)
