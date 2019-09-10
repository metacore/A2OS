(* ETH Oberon, Copyright 2001 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

MODULE LeoPanels IN Oberon; (** portable **)	(* eos  *)

	(**
		Leonardo Editor Panels
	**)

	(*
		12.05.2000 - don't open layer panel if no figure found
		12.05.2000 - SelectionToLayer: check for empty selection
		17.05.2000 - FindFrame uses Oberon.MarkedFrame to be compatible with new Windows Oberon (ejz)
	*)

	IMPORT
		Files, Objects, Math IN A2, Display, Printer, Texts, Viewers, Oberon, Out, Strings, Attributes, Links, Gadgets, Documents,
		Views, Desktops, Images, ImageGadgets, ImageDocs, GfxMatrix, Gfx, GfxPrinter, GfxBuffer, GfxPS,
		Leonardo, LeoFrames, LeoTools, LeoDocs;


	TYPE
		Editor* = POINTER TO EditorDesc;
		EditorDesc* = RECORD (Gadgets.ObjDesc)
			apply*, revert*: PROCEDURE (editor: Editor);
			fig*: Leonardo.Figure;	(** associated figure **)
			frame*: Gadgets.Frame;	(** associated frame **)
		END;


	VAR
		ResizeType, ResizeDim, AlignType, SpaceType, SpaceDim: ARRAY 2 OF Objects.Object;
		PrinterName, PrintLandscape, PrintPostscript, PSLevel2, PSDPI: Objects.Object;
		ExportMode, ExportBorder, ExportCopy, ExportName: Objects.Object;


	(**--- Editors ---**)

	PROCEDURE RevertEditor (editor: Editor);
	END RevertEditor;

	PROCEDURE ApplyEditor (editor: Editor);
	END ApplyEditor;

	PROCEDURE HandleEditor* (obj: Objects.Object; VAR msg: Objects.ObjMsg);
		VAR editor, copy: Editor;
	BEGIN
		IF msg IS Objects.AttrMsg THEN
			WITH msg: Objects.AttrMsg DO
				IF (msg.id = Objects.get) & (msg.name = "Gen") THEN
					msg.class := Objects.String; msg.s := "LeoPanels.NewEditor"; msg.res := 0
				ELSE
					Gadgets.objecthandle(obj, msg)
				END
			END
		ELSIF msg IS Objects.CopyMsg THEN
			WITH msg: Objects.CopyMsg DO
				IF msg.stamp # obj.stamp THEN
					editor := obj(Editor);
					NEW(copy); editor.dlink := copy; editor.stamp := msg.stamp;
					Gadgets.CopyObject(msg, editor, copy);
					copy.revert := editor.revert; copy.apply := editor.apply
				END;
				msg.obj := obj.dlink
			END
		ELSE
			Gadgets.objecthandle(obj, msg)
		END
	END HandleEditor;

	PROCEDURE NewEditor*;
		VAR editor: Editor;
	BEGIN
		NEW(editor); editor.handle := HandleEditor; editor.revert := RevertEditor; editor.apply := ApplyEditor;
		Objects.NewObj := editor
	END NewEditor;


	(**--- Documents ---**)

	PROCEDURE LoadStoreDoc (doc: Documents.Document);
	END LoadStoreDoc;

	PROCEDURE HandleDoc (obj: Objects.Object; VAR msg: Objects.ObjMsg);
		VAR doc: Documents.Document;
	BEGIN
		doc := obj(Documents.Document);
		IF msg IS Objects.AttrMsg THEN
			WITH msg: Objects.AttrMsg DO
				IF (msg.id = Objects.get) & (msg.name = "Gen") THEN
					msg.class := Objects.String; msg.s := "LeoPanels.NewDoc"; msg.res := 0
				ELSIF (msg.id = Objects.get) & (msg.name = "Adaptive") THEN
					msg.class := Objects.Bool; msg.b := FALSE; msg.res := 0
				ELSE
					Documents.Handler(doc, msg);
					IF (msg.res < 0) & (doc.obj # NIL) THEN
						doc.obj.handle(doc.obj, msg)
					END
				END
			END
		ELSIF msg IS Objects.LinkMsg THEN
			WITH msg: Objects.LinkMsg DO
				Documents.Handler(obj, msg);
				IF (msg.id = Objects.get) & (msg.res < 0) & (doc.obj # NIL) &
					(msg.name = "DeskMenu") OR (msg.name = "SystemMenu") OR (msg.name = "UserMenu")
				THEN
					Links.GetLink(doc.obj, msg.name, obj);
					IF obj = NIL THEN
						Links.GetLink(doc.obj, "Menu", obj)
					END;
					IF obj # NIL THEN
						msg.obj := Gadgets.Clone(obj, FALSE); msg.res := 0;
						obj := Gadgets.FindObj(msg.obj, "Title");
						Attributes.SetString(obj, "Value", doc.name)
					END
				END
			END
		ELSE
			Documents.Handler(doc, msg)
		END
	END HandleDoc;

	PROCEDURE InitDoc* (doc: Documents.Document; f: Gadgets.Frame);
	BEGIN
		doc.handle := HandleDoc; doc.Load := LoadStoreDoc; doc.Store := LoadStoreDoc;
		IF f # NIL THEN
			doc.W := f.W; doc.H := f.H;
			Links.GetLink(f, "Model", doc.obj);
			Attributes.GetString(doc.obj, "Title", doc.name)
		ELSE
			doc.W := 100; doc.H := 50
		END;
		Documents.Init(doc, f)
	END InitDoc;

	PROCEDURE NewDoc*;
		VAR doc: Documents.Document;
	BEGIN
		NEW(doc); InitDoc(doc, NIL);
		Objects.NewObj := doc
	END NewDoc;


	(**--- Panels ---**)

	(** return target frame of current context **)
	PROCEDURE FindFrame* (context: Objects.Object): Gadgets.Frame;
		VAR doc: Documents.Document; frame: Display.Frame; model, target: Objects.Object;
	BEGIN
		doc := Desktops.CurDoc(context);
		frame := Oberon.MarkedFrame();
		IF (frame # NIL) & Oberon.Pointer.on THEN	(* use marked frame and set panel target *)
			Links.GetLink(frame, "Model", model);
			IF (model # NIL) & (model IS Leonardo.Figure) THEN
				Links.SetLink(doc, "Target", frame);
				Oberon.FadeCursor(Oberon.Pointer);
				RETURN frame(Gadgets.Frame)
			END
		END;
		Links.GetLink(doc, "Target", target);	(* use previous target *)
		IF (target # NIL) & (target IS Gadgets.Frame) THEN
			RETURN target(Gadgets.Frame)
		END;
		IF frame # NIL THEN	(* last chance to find a frame *)
			Links.GetLink(frame, "Model", model);
			IF (model # NIL) & (model IS Leonardo.Figure) THEN
				Links.SetLink(doc, "Target", frame);
				RETURN frame(Gadgets.Frame)
			END
		END;
		RETURN NIL
	END FindFrame;

	(** return target figure of current context **)
	PROCEDURE FindFigure* (context: Objects.Object): Leonardo.Figure;
		VAR frame: Gadgets.Frame; model: Objects.Object;
	BEGIN
		frame := FindFrame(context);
		Links.GetLink(frame, "Model", model);
		IF (model # NIL) & (model IS Leonardo.Figure) THEN
			RETURN model(Leonardo.Figure)
		END;
		RETURN NIL
	END FindFigure;

	(** return editor of current context **)
	PROCEDURE FindEditor* (context: Objects.Object): Editor;
		VAR doc: Documents.Document;
	BEGIN
		doc := Desktops.CurDoc(context);
		IF (doc.obj # NIL) & (doc.obj IS Editor) THEN
			RETURN doc.obj(Editor)
		END;
		RETURN NIL
	END FindEditor;

	(* get generator for registered key string in registry section *)
	PROCEDURE FindGen (CONST key: ARRAY OF CHAR; VAR gen: ARRAY OF CHAR);
		VAR s: Texts.Scanner; k: ARRAY 64 OF CHAR;
	BEGIN
		gen[0] := 0X;
		Oberon.OpenScanner(s, "Leonardo");
		WHILE s.class IN {Texts.Name, Texts.String} DO
			COPY(s.s, k); Texts.Scan(s);
			IF (s.class = Texts.Char) & (s.c = "=") THEN
				Texts.Scan(s);
				IF s.class IN {Texts.Name, Texts.String} THEN
					IF k = key THEN
						COPY(s.s, gen);
						RETURN
					END;
					Texts.Scan(s)
				END
			END
		END
	END FindGen;

	(** create editor gadget for object **)
	PROCEDURE Create* (obj: Objects.Object): Gadgets.Frame;
		VAR key, gen: ARRAY 64 OF CHAR; res: SIGNED16; f: Gadgets.Frame; e: Objects.Object; editor: Editor;
	BEGIN
		Attributes.GetString(obj, "Item", key); gen := "";
		IF key # "" THEN
			FindGen(key, gen)
		END;
		IF gen = "" THEN
			Attributes.GetString(obj, "Gen", key);
			IF key # "" THEN
				FindGen(key, gen)
			END
		END;
		Objects.NewObj := NIL;
		IF gen # "" THEN
			Oberon.Call(gen, Oberon.Par, FALSE, res)
		END;
		IF (Objects.NewObj # NIL) & (Objects.NewObj IS Gadgets.Frame) THEN
			f := Objects.NewObj(Gadgets.Frame)
		ELSE
			f := NIL
		END;
		Links.GetLink(f, "Model", e);
		IF (e # NIL) & (e IS Editor) THEN
			editor := e(Editor);
			Links.SetLink(editor, "Model", obj);
			editor.revert(editor)
		END;
		RETURN f
	END Create;

	(** get public object from "Leonardo.Lib" **)
	PROCEDURE FindObj* (CONST name: ARRAY OF CHAR): Objects.Object;
		VAR lib: Objects.Library; obj: Objects.Object; ref: SIGNED16;
	BEGIN
		lib := Objects.ThisLibrary("Leonardo.Lib"); obj := NIL;
		IF lib # NIL THEN
			Objects.GetRef(lib.dict, name, ref);
			IF ref # MIN(SIGNED16) THEN
				lib.GetObj(lib, ref, obj)
			END
		END;
		IF obj = NIL THEN
			Out.String("warning: unknown object Leonardo."); Out.String(name); Out.Ln
		END;
		RETURN obj
	END FindObj;

	(** get copy of public panel in "Leonardo.Lib" **)
	PROCEDURE CopyObj* (CONST name: ARRAY OF CHAR; deep: BOOLEAN): Gadgets.Frame;
		VAR s: ARRAY 64 OF CHAR; obj: Objects.Object;
	BEGIN
		s := "Leonardo."; Strings.Append(s, name);
		obj := Gadgets.CopyPublicObject(s, deep);
		IF (obj # NIL) & (obj IS Gadgets.Frame) THEN RETURN obj(Gadgets.Frame)
		ELSE RETURN NIL
		END
	END CopyObj;

	(** open editor gadget in new document (at top of current context frame) **)
	PROCEDURE Open* (f: Gadgets.Frame; context: Objects.Object);
		VAR doc: Documents.Document; df: Display.Frame; x, y, h: SIGNED16; dlink: Objects.Object;
	BEGIN
		IF f = NIL THEN RETURN END;
		NEW(doc); InitDoc(doc, f);
		IF Oberon.Pointer.on THEN
			Gadgets.ThisFrame(Oberon.Pointer.X, Oberon.Pointer.Y, df, x, y);
			IF (df # NIL) & (df IS LeoFrames.Frame) THEN
				Links.SetLink(doc, "Target", df);
				Oberon.FadeCursor(Oberon.Pointer)
			END
		END;
		IF ~Oberon.Pointer.on & (context # NIL) & (context IS Display.Frame) THEN
			x := 10; y := 0; h := 0; dlink := context;
			REPEAT
				IF (dlink IS Display.Frame) & ~(dlink IS Documents.Document) THEN
					df := dlink(Display.Frame);
					IF df IS Views.View THEN
						INC(x, df(Views.View).vx); INC(y, df(Views.View).vy -  h)
					END;
					INC(x, df.X); h := df.H; INC(y, df.Y + h)
				END;
				dlink := dlink.dlink
			UNTIL (dlink = NIL) OR (df # NIL) & ((df IS Viewers.Viewer) OR (df IS Views.View));
			df := context(Display.Frame);
			IF (0 <= x) & (x < Display.Width) & (Desktops.menuH < y) & (y < Display.Height) THEN
				Oberon.DrawCursor(Oberon.Pointer, Oberon.Star, x, y)
			END
		END;
		Desktops.ShowDoc(doc);
		df := FindFrame(context);
		IF df # NIL THEN
			Links.SetLink(doc, "Target", df)
		END;
		IF f.obj # NIL THEN
			Gadgets.Update(f.obj)
		END
	END Open;


	(**--- Panel Commands ---**)

	(** open named panel **)
	PROCEDURE Append*;
		VAR s: Attributes.Scanner; name: ARRAY 64 OF CHAR; deep: BOOLEAN; f: Gadgets.Frame;
	BEGIN
		Attributes.OpenScanner(s, Oberon.Par.text, Oberon.Par.pos); Attributes.Scan(s);
		IF s.class IN {Attributes.String, Attributes.Name} THEN
			COPY(s.s, name); deep := FALSE; Attributes.Scan(s);
			IF (s.class = Attributes.Char) & (s.c = Oberon.OptionChar) THEN
				Attributes.Scan(s);
				IF (s.class = Attributes.Name) & ((s.s = "d") OR (s.s = "deep")) THEN
					deep := TRUE
				END
			END;
			f := CopyObj(name, deep);
			IF f # NIL THEN
				Open(f, Gadgets.context)
			END
		END
	END Append;

	(** edit named link in current context **)
	PROCEDURE EditLink*;
		VAR s: Attributes.Scanner; ref, link: Objects.Object; p: Gadgets.Frame;
	BEGIN
		Attributes.OpenScanner(s, Oberon.Par.text, Oberon.Par.pos); Attributes.Scan(s);
		IF s.class IN {Attributes.String, Attributes.Name} THEN
			ref := FindEditor(Gadgets.context);
			Links.GetLink(ref, s.s, link);
			IF link # NIL THEN
				p := Create(link);
				IF p # NIL THEN
					Open(p, Gadgets.context)
				END
			END
		END
	END EditLink;

	(** edit copy of named link in current context **)
	PROCEDURE EditCopy*;
		VAR s: Attributes.Scanner; ref, link, e: Objects.Object; lname: ARRAY 64 OF CHAR; cm: Objects.CopyMsg; p: Gadgets.Frame;
	BEGIN
		Attributes.OpenScanner(s, Oberon.Par.text, Oberon.Par.pos); Attributes.Scan(s);
		IF s.class IN {Attributes.String, Attributes.Name} THEN
			ref := FindEditor(Gadgets.context);
			Links.GetLink(ref, s.s, link);
			IF link # NIL THEN
				COPY(s.s, lname); Attributes.Scan(s);
				Objects.Stamp(cm); cm.id := Objects.shallow;
				IF (s.class = Attributes.Char) & (s.c = Oberon.OptionChar) THEN
					Attributes.Scan(s);
					IF (s.class = Attributes.Name) & (s.s = "deep") THEN
						cm.id := Objects.deep
					END
				END;
				link.handle(link, cm); link := cm.obj;
				p := Create(link);
				IF p # NIL THEN
					Links.GetLink(p, "Model", e);
					Links.SetLink(e, "Referer", ref); Attributes.SetString(e, "Link", s.s);
					Open(p, Gadgets.context)
				END
			END
		END
	END EditCopy;

	(** apply changes to edited object **)
	PROCEDURE Apply*;
		VAR editor: Editor; ref, obj: Objects.Object; lname: ARRAY 64 OF CHAR;
	BEGIN
		editor := FindEditor(Gadgets.context);
		IF editor # NIL THEN
			Oberon.Defocus;
			editor.fig := FindFigure(Gadgets.context);
			editor.frame := FindFrame(Gadgets.context);
			editor.apply(editor); editor.revert(editor);
			Links.GetLink(editor, "Referer", ref);
			IF ref # NIL THEN
				Links.GetLink(editor, "Model", obj);
				Attributes.GetString(editor, "Link", lname);
				Links.SetLink(ref, lname, obj);
				Gadgets.Update(ref)
			END
		END
	END Apply;

	(** revert to original object attributes **)
	PROCEDURE Revert*;
		VAR editor: Editor;
	BEGIN
		editor := FindEditor(Gadgets.context);
		IF editor # NIL THEN
			editor.fig := FindFigure(Gadgets.context);
			editor.revert(editor)
		END
	END Revert;

	(** apply changes and close current panel **)
	PROCEDURE Ok*;
		VAR editor: Editor;
	BEGIN
		editor := FindEditor(Gadgets.context);
		IF editor # NIL THEN
			Apply;
			Desktops.CloseDoc
		END
	END Ok;


	(**--- Color Panel ---**)

	PROCEDURE RevertColor (e: Editor);
		VAR obj, ref: Objects.Object; fld: ARRAY 32 OF CHAR; col: SIGNED32;
	BEGIN
		Links.GetLink(e, "Model", obj);
		IF obj # NIL THEN
			Links.GetLink(e, "Referer", ref); Attributes.GetString(e, "Field", fld);
			Attributes.GetInt(ref, fld, col); Attributes.SetInt(obj, "Color", col); Gadgets.Update(obj)
		END
	END RevertColor;

	PROCEDURE ApplyColor (e: Editor);
		VAR obj, ref: Objects.Object; col: SIGNED32; fld: ARRAY 32 OF CHAR;
	BEGIN
		Links.GetLink(e, "Model", obj); Attributes.GetInt(obj, "Color", col);
		Links.GetLink(e, "Referer", ref); Attributes.GetString(e, "Field", fld);
		Attributes.SetInt(ref, fld, col); Gadgets.Update(ref)
	END ApplyColor;

	PROCEDURE EditColor*;
		VAR p: Gadgets.Frame; obj: Objects.Object; e: Editor; fld: ARRAY 32 OF CHAR; col: SIGNED32;
	BEGIN
		p := CopyObj("ColorPanel", TRUE);
		IF p # NIL THEN
			Links.GetLink(p, "Model", obj);
			IF (obj # NIL) & (obj IS Editor) THEN
				e := obj(Editor); e.revert := RevertColor; e.apply := ApplyColor;
				obj := FindEditor(Gadgets.context);
				Attributes.GetString(Gadgets.executorObj, "Field", fld);
				IF fld[0] = 0X THEN fld := "Color" END;
				Links.SetLink(e, "Referer", obj); Attributes.SetString(e, "Field", fld);
				Attributes.GetInt(obj, fld, col);
				Links.GetLink(e, "Model", obj); Attributes.SetInt(obj, "Color", col);
				Open(p, Gadgets.context)
			END
		END
	END EditColor;


	(**--- Transformations ---**)

	PROCEDURE GetTransform (e: Editor; VAR m: GfxMatrix.Matrix);
	BEGIN
		Attributes.GetReal(e, "M00", m[0, 0]); Attributes.GetReal(e, "M01", m[0, 1]);
		Attributes.GetReal(e, "M10", m[1, 0]); Attributes.GetReal(e, "M11", m[1, 1]);
		Attributes.GetReal(e, "M20", m[2, 0]); Attributes.GetReal(e, "M21", m[2, 1])
	END GetTransform;

	PROCEDURE SetTransform (e: Editor; CONST m: GfxMatrix.Matrix);
	BEGIN
		Attributes.SetReal(e, "M00", m[0, 0]); Attributes.SetReal(e, "M01", m[0, 1]);
		Attributes.SetReal(e, "M10", m[1, 0]); Attributes.SetReal(e, "M11", m[1, 1]);
		Attributes.SetReal(e, "M20", m[2, 0]); Attributes.SetReal(e, "M21", m[2, 1]);
		Gadgets.Update(e)
	END SetTransform;

	PROCEDURE ResetTransform (e: Editor);
	BEGIN
		SetTransform(e, GfxMatrix.Identity)
	END ResetTransform;

	PROCEDURE ApplyTransform (e: Editor);
		VAR m, inv, mat: GfxMatrix.Matrix; tool: LeoTools.Tool; u: FLOAT32; ref, obj: Objects.Object; list: Leonardo.Shape;
	BEGIN
		IF e.fig # NIL THEN
			GetTransform(e, m);
			IF (e.frame # NIL) & (e.frame IS LeoFrames.Frame) THEN
				tool := LeoTools.Current(e.frame(LeoFrames.Frame));
				IF tool # NIL THEN	(* convert ruler units to standard coordinates *)
					u := 1/tool.unit;
					GfxMatrix.Init(inv, u, 0, 0, -u, -tool.zx * u, tool.zy * u);
					GfxMatrix.Init(mat, tool.unit, 0, 0, -tool.unit, tool.zx, -tool.zy);
					GfxMatrix.Concat(inv, m, m); GfxMatrix.Concat(m, mat, m)
				END
			END;
			Links.GetLink(e, "Referer", ref); Links.GetLink(ref, "Model", obj);
			IF (obj # NIL) & (obj IS Leonardo.Shape) THEN list := obj(Leonardo.Shape); list.slink := NIL
			ELSE list := Leonardo.Selection(e.fig)
			END;
			IF list # NIL THEN
				Leonardo.Transform(e.fig, list, m)
			END
		END
	END ApplyTransform;

	PROCEDURE EditTransform*;
		VAR f: Gadgets.Frame; obj: Objects.Object; e: Editor;
	BEGIN
		f := CopyObj("TransformPanel", TRUE);
		IF f # NIL THEN
			Links.GetLink(f, "Model", obj);
			IF (obj # NIL) & (obj IS Editor) THEN
				e := obj(Editor); e.revert := ResetTransform; e.apply := ApplyTransform;
				Links.SetLink(e, "Referer", FindEditor(Gadgets.context));
				Open(f, Gadgets.context)
			END
		END
	END EditTransform;

	PROCEDURE MakeTransform (e: Editor; VAR m: GfxMatrix.Matrix);
		VAR x0, y0, dx, dy, d, cos, sin, phi, tx, ty, sx, sy, rho, f: FLOAT32; dir, kind: SIGNED32;
	BEGIN
		m := GfxMatrix.Identity;
		Attributes.GetReal(e, "X0", x0); Attributes.GetReal(e, "Y0", y0);
		Attributes.GetInt(e, "Direction", dir);
		IF dir = 1 THEN	(* direction vector *)
			Attributes.GetReal(e, "DX", dx); Attributes.GetReal(e, "DY", dy);
			d := Math.sqrt(dx * dx + dy * dy);
			IF d > 0.001 THEN cos := dx/d; sin := dy/d
			ELSE dir := 0
			END
		ELSIF dir = 2 THEN	(* direction angle *)
			Attributes.GetReal(e, "Dir", phi); phi := phi * (Math.pi/180);
			cos := Math.cos(phi); sin := Math.sin(phi)
		END;
		Attributes.GetInt(e, "Kind", kind);
		CASE kind OF
		| 1:	(* translate *)
			Attributes.GetReal(e, "TX", tx); Attributes.GetReal(e, "TY", ty);
			IF dir = 0 THEN GfxMatrix.Init(m, 1, 0, 0, 1, tx, ty)
			ELSE GfxMatrix.Init(m, 1, 0, 0, 1, tx * cos + ty * sin, tx * sin - ty * cos)
			END
		| 2:	(* scale *)
			Attributes.GetReal(e, "SX", sx); Attributes.GetReal(e, "SY", sy);
			IF dir = 0 THEN GfxMatrix.ScaleAt(GfxMatrix.Identity, x0, y0, sx, sy, m)
			ELSE GfxMatrix.ScaleAt(GfxMatrix.Identity, x0, y0, sx * cos + sy * sin, sx * sin - sy * cos, m)
			END
		| 3:	(* rotate *)
			Attributes.GetReal(e, "Angle", rho); rho := rho * (Math.pi/180);
			GfxMatrix.RotateAt(GfxMatrix.Identity, x0, y0, Math.sin(rho), Math.cos(rho), m)
		| 4:	(* shear *)
			IF dir = 0 THEN cos := 1; sin := 0 END;
			Attributes.GetReal(e, "Factor", f);
			GfxMatrix.Get3PointTransform(
				x0, y0, x0, y0,
				x0 + cos, y0 + sin, x0 + cos, y0 + sin,
				x0 - sin, y0 + cos, x0 - sin + f * cos, y0 + cos + f * sin,
				m
			)
		| 5:	(* mirror *)
			IF dir = 0 THEN
				GfxMatrix.ScaleAt(GfxMatrix.Identity, x0, y0, -1, -1, m)
			ELSE
				GfxMatrix.RotateAt(GfxMatrix.Identity, x0, y0, sin, cos, m);
				GfxMatrix.ScaleAt(m, x0, y0, 1, -1, m);
				GfxMatrix.RotateAt(m, x0, y0, -sin, cos, m)
			END
		ELSE
		END
	END MakeTransform;

	PROCEDURE AppendTransform*;
		VAR e: Editor; m0, m1: GfxMatrix.Matrix;
	BEGIN
		e := FindEditor(Gadgets.context);
		IF e # NIL THEN
			GetTransform(e, m0); MakeTransform(e, m1);
			GfxMatrix.Concat(m0, m1, m0);
			SetTransform(e, m0)
		END
	END AppendTransform;

	PROCEDURE PrependTransform*;
		VAR e: Editor; m0, m1: GfxMatrix.Matrix;
	BEGIN
		e := FindEditor(Gadgets.context);
		IF e # NIL THEN
			MakeTransform(e, m0); GetTransform(e, m1);
			GfxMatrix.Concat(m0, m1, m1);
			SetTransform(e, m1)
		END
	END PrependTransform;


	(**--- Selection ---**)

	PROCEDURE EditSelection*;
		VAR fig: Leonardo.Figure; sel: Leonardo.Shape; f: Gadgets.Frame;
	BEGIN
		fig := FindFigure(Gadgets.context);
		IF fig # NIL THEN
			sel := Leonardo.Selection(fig);
			IF sel # NIL THEN
				f := Create(sel);
				IF f # NIL THEN
					Open(f, Gadgets.context)
				END
			END
		END
	END EditSelection;

	PROCEDURE GetSelection*;
		VAR fig: Leonardo.Figure; sel: Leonardo.Shape; f: Gadgets.Frame; doc: Documents.Document;
	BEGIN
		fig := FindFigure(Gadgets.context);
		IF fig # NIL THEN
			sel := Leonardo.Selection(fig);
			IF sel # NIL THEN
				f := Create(sel);
				IF f # NIL THEN
					NEW(doc); InitDoc(doc, f);
					Links.SetLink(doc, "Target", FindFrame(Gadgets.context));
					Desktops.ReplaceCurrentDoc(doc);
					IF f.obj # NIL THEN
						Gadgets.Update(f.obj)
					END
				END
			END
		END
	END GetSelection;


	(**--- Open Panel ---**)

	PROCEDURE OpenDoc*;
		VAR
			doc, panel: Documents.Document; s: Attributes.Scanner; frame: Display.Frame; x, y: SIGNED16;
			model: Objects.Object; fig: Leonardo.Figure;
	BEGIN
		doc := NIL;
		Attributes.OpenScanner(s, Oberon.Par.text, Oberon.Par.pos); Attributes.Scan(s);
		IF s.class IN {Attributes.Name, Attributes.String} THEN
			doc := Documents.Open(s.s);
			IF doc # NIL THEN
				Links.GetLink(doc.dsc, "Model", model);
				IF (model = NIL) OR ~(model IS Leonardo.Figure) THEN
					NEW(doc); LeoDocs.Init(doc); COPY(s.s, doc.name);
					doc.Load(doc)
				END
			END
		ELSIF (s.class = Attributes.Char) & (s.c = "*") THEN
			Gadgets.ThisFrame(Oberon.Pointer.X, Oberon.Pointer.Y, frame, x, y);
			Links.GetLink(frame, "Model", model);
			IF (model # NIL) & (model IS Leonardo.Figure) THEN
				doc := LeoDocs.Make(model(Leonardo.Figure));
				Oberon.FadeCursor(Oberon.Pointer)	(* otherwise document is likely to appear on top of marked figure *)
			END
		ELSE
			NEW(fig); Leonardo.InitFigure(fig);
			doc := LeoDocs.Make(fig)
		END;
		IF doc # NIL THEN
			panel := Desktops.CurDoc(Gadgets.context);
			Desktops.ShowDoc(doc);
			IF panel # NIL THEN
				Links.SetLink(panel, "Target", doc.dsc)
			END
		END
	END OpenDoc;


	(**--- Printing ---**)

	PROCEDURE Print*;
		VAR
			frame: Gadgets.Frame; obj: Objects.Object; tool: LeoTools.Tool; name: ARRAY 64 OF CHAR;
			ls, printps, level2: BOOLEAN; dpi: SIGNED32; ps: GfxPS.Context; file: Files.File; pc: GfxPrinter.Context;
	BEGIN
		frame := FindFrame(Gadgets.context);
		IF (frame # NIL) & (frame.obj # NIL) & (frame.obj IS Leonardo.Figure) THEN
			Links.GetLink(frame, "Tool", obj);
			IF (obj # NIL) & (obj IS LeoTools.Tool) THEN
				tool := obj(LeoTools.Tool);
				Attributes.GetString(PrinterName, "Value", name);
				Attributes.GetBool(PrintLandscape, "Value", ls);
				Attributes.GetBool(PrintPostscript, "Value", printps);
				IF printps THEN
					Attributes.GetBool(PSLevel2, "Value", level2);
					Attributes.GetInt(PSDPI, "Value", dpi);
					NEW(ps); GfxPS.Init(ps, level2, ls, tool.pageW, tool.pageH, 0, 0, 0, 0, dpi);
					Out.String("printing file "); Out.String(name);
					file := Files.New(name);
					IF file # NIL THEN
						GfxPS.Open(ps, file);
						Gfx.Translate(ps, 0, tool.pageH);
						Leonardo.Render(frame.obj(Leonardo.Figure), Leonardo.passive, ps);
						GfxPS.ShowPage(ps);
						GfxPS.Close(ps);
						Files.Register(file);
						Out.String(" -- done")
					ELSE Out.String(" -- cannot open")
					END;
					Out.Ln
				ELSE
					Printer.Open(name, "");
					Out.String("printing on "); Out.String(name);
					IF Printer.res = 0 THEN
						NEW(pc); GfxPrinter.Init(pc);
						GfxPrinter.SetCoordinates(pc, 0, 0, pc.scale); Gfx.Reset(pc);
						IF ls THEN Gfx.Rotate(pc, 1, 0)
						ELSE Gfx.Translate(pc, 0, tool.pageH)
						END;
						Leonardo.Render(frame.obj(Leonardo.Figure), Leonardo.passive, pc);
						Printer.Page(1);
						Printer.Close;
						Out.String(" -- done"); Out.Ln
					ELSE Out.String(" -- cannot open")
					END
				END
			END
		END
	END Print;


	(**--- Export ---**)

	PROCEDURE ExportFigure (fig: Leonardo.Figure; x0, y0, x1, y1: SIGNED16);
		VAR
			copy: BOOLEAN; cm: Objects.CopyMsg; frame: LeoFrames.Frame; dm: Display.ConsumeMsg;
			doc: Documents.Document;
	BEGIN
		Attributes.GetBool(ExportCopy, "Value", copy);
		IF copy THEN
			Objects.Stamp(cm); cm.id := Objects.deep; cm.obj := NIL; fig.handle(fig, cm); fig := cm.obj(Leonardo.Figure)
		END;
		NEW(frame); LeoFrames.Init(frame, fig);
		frame.W := x1 - x0; frame.H := y1 - y0; frame.ox := -x0; frame.oy := -y1;
		dm.id := Display.integrate; dm.obj := frame; Display.Broadcast(dm);
		IF dm.res < 0 THEN
			EXCL(frame.state, Gadgets.transparent);
			NEW(doc); LeoDocs.Init(doc); doc.W := frame.W; doc.H := frame.H;
			Documents.Init(doc, frame);
			Desktops.ShowDoc(doc)
		END
	END ExportFigure;

	PROCEDURE ExportImage (fig: Leonardo.Figure; x0, y0, x1, y1: SIGNED16);
		VAR
			img: Images.Image; frame: Gadgets.Frame; r, g, b: SIGNED16; pix: Images.Pixel; ctxt: GfxBuffer.Context;
			gad: ImageGadgets.Frame; dm: Display.ConsumeMsg; doc: Documents.Document;
	BEGIN
		NEW(img); Images.Create(img, x1 - x0, y1 - y0, Images.DisplayFormat);
		frame := FindFrame(Gadgets.context);
		IF (frame # NIL) & (frame IS LeoFrames.Frame) THEN
			Display.GetColor(frame(LeoFrames.Frame).col, r, g, b);
			Images.SetRGB(pix, r, g, b);
			Images.Fill(img, 0, 0, img.width, img.height, pix, Images.SrcCopy)
		END;
		NEW(ctxt); GfxBuffer.Init(ctxt, img); GfxBuffer.SetCoordinates(ctxt, -x0, -y0, 1); Gfx.Reset(ctxt);
		Leonardo.Render(fig, Leonardo.passive, ctxt);
		NEW(gad); ImageGadgets.Init(gad, img); gad.W := img.width; gad.H := img.height;
		dm.id := Display.integrate; dm.obj := gad; Display.Broadcast(dm);
		IF dm.res < 0 THEN
			NEW(doc); ImageDocs.InitDoc(doc); doc.W := gad.W; doc.H := gad.H;
			Documents.Init(doc, gad);
			Desktops.ShowDoc(doc)
		END
	END ExportImage;

	PROCEDURE ExportEPS (fig: Leonardo.Figure; x0, y0, x1, y1: SIGNED16);
		VAR level2: BOOLEAN; dpi: SIGNED32; name: ARRAY 64 OF CHAR; file: Files.File; eps: GfxPS.Context;
	BEGIN
		Attributes.GetBool(PSLevel2, "Value", level2);
		Attributes.GetInt(PSDPI, "Value", dpi);
		Attributes.GetString(ExportName, "Value", name);
		file := Files.New(name);
		IF file # NIL THEN
			Out.String("writing "); Out.String(name); Out.String(" ...");
			NEW(eps); GfxPS.InitEPS(eps, level2, dpi);
			GfxPS.Open(eps, file);
			Gfx.SetStrokeColor(eps, Gfx.White);
			Gfx.DrawRect(eps, x0, y0, x1, y1, {Gfx.Stroke});
			Gfx.SetStrokeColor(eps, Gfx.Black);
			Leonardo.Render(fig, Leonardo.passive, eps);
			GfxPS.Close(eps);
			Files.Register(file);
			Out.String("done"); Out.Ln
		END
	END ExportEPS;

	PROCEDURE Export*;
		VAR fig: Leonardo.Figure; mode: SIGNED32; border, llx, lly, urx, ury, bw: FLOAT32; x0, y0, x1, y1: SIGNED16;
	BEGIN
		fig := FindFigure(Gadgets.context);
		IF fig # NIL THEN
			Attributes.GetInt(ExportMode, "Value", mode);
			IF mode = 2 THEN
				Oberon.Defocus
			END;
			Attributes.GetReal(ExportBorder, "Value", border);
			Leonardo.GetComponentsBox(fig.bottom, llx, lly, urx, ury, bw);
			bw := bw + border; x0 := SHORT(ENTIER(llx - bw)); y0 := SHORT(ENTIER(lly - bw));
			x1 := -SHORT(ENTIER(-(urx + bw))); y1 := -SHORT(ENTIER(-(ury + bw)));
			IF mode = 0 THEN ExportFigure(fig, x0, y0, x1, y1)
			ELSIF mode = 1 THEN ExportImage(fig, x0, y0, x1, y1)
			ELSIF mode = 2 THEN ExportEPS(fig, x0, y0, x1, y1)
			END
		END
	END Export;


	(**--- Frames ---**)

	PROCEDURE RevertFrame (editor: Editor);
		VAR obj: Objects.Object; frame: LeoFrames.Frame; tool: LeoTools.Tool;
	BEGIN
		Links.GetLink(editor, "Model", obj);
		IF (obj # NIL) & (obj IS LeoFrames.Frame) THEN
			frame := obj(LeoFrames.Frame);
			Attributes.SetInt(editor, "Color", frame.col);
			Links.GetLink(frame, "Tool", obj);
			IF (obj # NIL) & (obj IS LeoTools.Tool) THEN
				tool := obj(LeoTools.Tool);
				Attributes.SetReal(editor, "Unit", tool.unit); Attributes.SetReal(editor, "OldUnit", tool.unit);
				Attributes.SetReal(editor, "Width", tool.pageW/tool.unit);
				Attributes.SetReal(editor, "Height", tool.pageH/tool.unit);
				Attributes.SetBool(editor, "Landscape", tool.pageW > tool.pageH);
				Attributes.SetBool(editor, "Buffered", tool.buffered);
				Attributes.SetInt(editor, "Ticks", tool.grid.ticks);
				Attributes.SetBool(editor, "Visible", tool.grid.visible);
				Attributes.SetBool(editor, "Active", tool.grid.active)
			ELSE
				Attributes.SetBool(editor, "Transparent", Gadgets.transparent IN frame.state);
				Attributes.SetBool(editor, "Framed", frame.framed)
			END;
			Gadgets.Update(editor)
		END
	END RevertFrame;

	PROCEDURE ApplyFrame (editor: Editor);
		VAR obj: Objects.Object; frame: LeoFrames.Frame; col, ticks: SIGNED32; tool: LeoTools.Tool; t: BOOLEAN;
	BEGIN
		Links.GetLink(editor, "Model", obj);
		IF (obj # NIL) & (obj IS LeoFrames.Frame) THEN
			frame := obj(LeoFrames.Frame);
			Attributes.GetInt(editor, "Color", col); frame.col := SHORT(col);
			Links.GetLink(frame, "Tool", obj);
			IF (obj # NIL) & (obj IS LeoTools.Tool) THEN
				tool := obj(LeoTools.Tool);
				Attributes.GetReal(editor, "Unit", tool.unit);
				Attributes.GetReal(editor, "Width", tool.pageW); tool.pageW := tool.pageW * tool.unit;
				Attributes.GetReal(editor, "Height", tool.pageH); tool.pageH := tool.pageH * tool.unit;
				Attributes.GetBool(editor, "Buffered", tool.buffered);
				Attributes.GetInt(editor, "Ticks", ticks); tool.grid.ticks := SHORT(ticks);
				Attributes.GetBool(editor, "Visible", tool.grid.visible);
				Attributes.GetBool(editor, "Active", tool.grid.active)
			ELSE
				Attributes.GetBool(editor, "Transparent", t);
				IF t THEN INCL(frame.state, Gadgets.transparent) ELSE EXCL(frame.state, Gadgets.transparent) END;
				Attributes.GetBool(editor, "Framed", frame.framed)
			END;
			Gadgets.Update(frame)
		END
	END ApplyFrame;

	PROCEDURE GetFramePanel (target: Gadgets.Frame; VAR p: Gadgets.Frame);
		VAR tool, obj: Objects.Object; editor: Editor;
	BEGIN
		IF target # NIL THEN
			Links.GetLink(target, "Tool", tool);
			IF (tool # NIL) & (tool IS LeoTools.Tool) THEN p := CopyObj("ActiveFramePanel", TRUE)
			ELSE p := CopyObj("PassiveFramePanel", TRUE)
			END;
			Links.GetLink(p, "Model", obj);
			IF (p # NIL) & (obj # NIL) & (obj IS Editor) THEN
				editor := obj(Editor); editor.revert := RevertFrame; editor.apply := ApplyFrame;
				Links.SetLink(editor, "Model", target);
				RevertFrame(editor)
			END
		END
	END GetFramePanel;

	PROCEDURE EditFrame*;
		VAR p: Gadgets.Frame;
	BEGIN
		GetFramePanel(FindFrame(Gadgets.context), p);
		Open(p, Gadgets.context)
	END EditFrame;

	PROCEDURE SetFrameUnit*;
		VAR editor: Editor; s: Attributes.Scanner; unit, w, h: FLOAT32;
	BEGIN
		editor := FindEditor(Gadgets.context);
		IF editor # NIL THEN
			Attributes.OpenScanner(s, Oberon.Par.text, Oberon.Par.pos); Attributes.Scan(s);
			IF s.class = Attributes.String THEN s.class := Attributes.Real; Strings.StrToReal(s.s, s.y); s.x := SHORT(s.y); END;
			IF (s.class = Attributes.Real) & (s.x >= 0.1) THEN
				Attributes.GetReal(editor, "OldUnit", unit);
				Attributes.SetReal(editor, "Unit", s.x); Attributes.SetReal(editor, "OldUnit", s.x);
				Attributes.GetReal(editor, "Width", w); Attributes.SetReal(editor, "Width", w * unit/s.x);
				Attributes.GetReal(editor, "Height", h); Attributes.SetReal(editor, "Height", h * unit/s.x);
				Gadgets.Update(editor)
			END
		END
	END SetFrameUnit;

	PROCEDURE SetFrameSize*;
		VAR editor: Editor; landscape: BOOLEAN; unit: FLOAT32; s: Attributes.Scanner;
	BEGIN
		editor := FindEditor(Gadgets.context);
		IF editor # NIL THEN
			Attributes.GetBool(editor, "Landscape", landscape);
			Attributes.GetReal(editor, "Unit", unit);
			Attributes.OpenScanner(s, Oberon.Par.text, Oberon.Par.pos); Attributes.Scan(s);
			IF s.class = Attributes.String THEN s.class := Attributes.Real; Strings.StrToReal(s.s, s.y); s.x := SHORT(s.y) END;
			IF s.class = Attributes.Real THEN
				IF landscape THEN Attributes.SetReal(editor, "Height", s.x/unit)
				ELSE Attributes.SetReal(editor, "Width", s.x/unit)
				END;
				Attributes.Scan(s)
			END;
			IF s.class = Attributes.String THEN s.class := Attributes.Real; Strings.StrToReal(s.s, s.y); s.x := SHORT(s.y) END;
			IF s.class = Attributes.Real THEN
				IF landscape THEN Attributes.SetReal(editor, "Width", s.x/unit)
				ELSE Attributes.SetReal(editor, "Height", s.x/unit)
				END
			END;
			Gadgets.Update(editor)
		END
	END SetFrameSize;

	PROCEDURE SetFrameOrientation*;
		VAR editor: Editor; w, h: FLOAT32;
	BEGIN
		editor := FindEditor(Gadgets.context);
		IF editor # NIL THEN
			Attributes.GetReal(editor, "Width", w); Attributes.GetReal(editor, "Height", h);
			Attributes.SetReal(editor, "Width", h); Attributes.SetReal(editor, "Height", w);
			Gadgets.Update(editor)
		END
	END SetFrameOrientation;

	PROCEDURE ActivateFrame*;
		VAR f, p: Gadgets.Frame; tool: Objects.Object; doc: Documents.Document;
	BEGIN
		f := FindFrame(Gadgets.context);
		Links.GetLink(f, "Tool", tool);
		IF (f # NIL) & (tool = NIL) THEN
			f.handle := LeoTools.ToolHandler;
			Attributes.SetBool(f, "Transparent", FALSE); Attributes.SetBool(f, "Framed", TRUE);
			Gadgets.Update(f);
			GetFramePanel(f, p);
			NEW(doc); InitDoc(doc, p);
			Links.SetLink(doc, "Target", f);
			Desktops.ReplaceCurrentDoc(doc);
		END
	END ActivateFrame;

	PROCEDURE PassivateFrame*;
		VAR f, p: Gadgets.Frame; tool: Objects.Object; tm: LeoTools.ToolMsg; doc: Documents.Document;
	BEGIN
		f := FindFrame(Gadgets.context);
		Links.GetLink(f, "Tool", tool);
		IF (f # NIL) & (tool # NIL) THEN
			tm.F := f; tm.handle := LeoFrames.Handle; Display.Broadcast(tm);
			Links.SetLink(f, "Tool", NIL);
			Gadgets.Update(f);
			GetFramePanel(f, p);
			NEW(doc); InitDoc(doc, p);
			Links.SetLink(doc, "Target", f);
			Desktops.ReplaceCurrentDoc(doc);
		END
	END PassivateFrame;


	(**--- Figures ---**)

	PROCEDURE RevertFigure (editor: Editor);
		VAR obj: Objects.Object; fig: Leonardo.Figure; limit: SIGNED32;
	BEGIN
		Links.GetLink(editor, "Model", obj);
		IF (obj # NIL) & (obj IS Leonardo.Figure) THEN
			fig := obj(Leonardo.Figure);
			Attributes.GetInt(fig, "UndoLimit", limit); Attributes.SetInt(editor, "UndoLimit", limit);
			Gadgets.Update(editor)
		END
	END RevertFigure;

	PROCEDURE ApplyFigure (editor: Editor);
		VAR obj: Objects.Object; fig: Leonardo.Figure; limit: SIGNED32;
	BEGIN
		Links.GetLink(editor, "Model", obj);
		IF (obj # NIL) & (obj IS Leonardo.Figure) THEN
			fig := obj(Leonardo.Figure);
			Attributes.GetInt(editor, "UndoLimit", limit); Attributes.SetInt(fig, "UndoLimit", limit)
		END
	END ApplyFigure;

	PROCEDURE EditFigure*;
		VAR fig: Leonardo.Figure; p: Gadgets.Frame; obj: Objects.Object; editor: Editor;
	BEGIN
		fig := FindFigure(Gadgets.context);
		p := CopyObj("FigurePanel", TRUE);
		Links.GetLink(p, "Model", obj);
		IF (fig # NIL) & (p # NIL) & (obj # NIL) & (obj IS Editor) THEN
			editor := obj(Editor); editor.revert := RevertFigure; editor.apply := ApplyFigure;
			Links.SetLink(editor, "Model", fig);
			RevertFigure(editor);
			Open(p, Gadgets.context)
		END
	END EditFigure;

	(** undo last operation **)
	PROCEDURE Undo*;
		VAR fig: Leonardo.Figure;
	BEGIN
		fig := FindFigure(Gadgets.context);
		IF fig # NIL THEN
			Leonardo.Undo(fig)
		END
	END Undo;

	(** redo most recently undone operation **)
	PROCEDURE Redo*;
		VAR fig: Leonardo.Figure;
	BEGIN
		fig := FindFigure(Gadgets.context);
		IF fig # NIL THEN
			Leonardo.Redo(fig)
		END
	END Redo;


	(**--- Layers ---**)

	PROCEDURE RevertLayer (editor: Editor);
		VAR obj: Objects.Object; layer: Leonardo.Layer;
	BEGIN
		Links.GetLink(editor, "Model", obj);
		IF (obj # NIL) & (obj IS Leonardo.Layer) THEN
			layer := obj(Leonardo.Layer);
			Attributes.SetString(editor, "Name", layer.name);
			Attributes.SetBool(editor, "Display", layer.display);
			Attributes.SetBool(editor, "Print", layer.print);
			Attributes.SetBool(editor, "Align", layer.align);
			Gadgets.Update(editor)
		END
	END RevertLayer;

	PROCEDURE ApplyLayer (editor: Editor);
		VAR obj: Objects.Object; layer: Leonardo.Layer; s: ARRAY 64 OF CHAR; b: BOOLEAN;
	BEGIN
		Links.GetLink(editor, "Model", obj);
		IF (obj # NIL) & (obj IS Leonardo.Layer) & (editor.fig # NIL) THEN
			layer := obj(Leonardo.Layer);
			Leonardo.BeginCommand(editor.fig);
			Attributes.GetString(editor, "Name", s); Leonardo.SetString(editor.fig, layer, "Name", s);
			Attributes.GetBool(editor, "Display", b); Leonardo.SetBool(editor.fig, layer, "Display", b);
			Attributes.GetBool(editor, "Print", b); Leonardo.SetBool(editor.fig, layer, "Print", b);
			Attributes.GetBool(editor, "Align", b); Leonardo.SetBool(editor.fig, layer, "Align", b);
			Leonardo.EndCommand(editor.fig)
		END
	END ApplyLayer;

	PROCEDURE EditLayers*;
		VAR p: Gadgets.Frame; obj, list: Objects.Object; editor: Editor; fig: Leonardo.Figure;
	BEGIN
		p := CopyObj("LayerPanel", TRUE);
		Links.GetLink(p, "Model", obj);
		IF (obj # NIL) & (obj IS Editor) THEN
			editor := obj(Editor); editor.revert := RevertLayer; editor.apply := ApplyLayer;
			fig := FindFigure(Gadgets.context);
			IF fig # NIL THEN
				Links.SetLink(editor, "Model", fig.active);
				list := Gadgets.FindObj(p, "List");
				IF list # NIL THEN
					Links.SetLink(editor, "List", list);
					Links.SetLink(list, "Model", fig); Links.SetLink(list, "Container", fig);
					Links.SetLink(list, "Active", fig.active)
				END;
				RevertLayer(editor);
				Open(p, Gadgets.context)
			END
		END
	END EditLayers;

	PROCEDURE UpdateLayer (layer: Leonardo.Layer);
		VAR list: Objects.Object; editor: Editor;
	BEGIN
		list := Gadgets.FindObj(Gadgets.context, "List");
		IF list # NIL THEN
			Links.SetLink(list, "Active", layer);
			Gadgets.Update(list)
		END;
		editor := FindEditor(Gadgets.context);
		IF editor # NIL THEN
			editor.revert := RevertLayer; editor.apply := ApplyLayer;	(* just to be sure *)
			Links.SetLink(editor, "Model", layer)
		END;
		RevertLayer(editor)
	END UpdateLayer;

	PROCEDURE Activate*;
		VAR obj: Objects.Object; layer: Leonardo.Layer; p: Gadgets.Frame;
	BEGIN
		Links.GetLink(Gadgets.executorObj, "Point", obj);
		IF (obj # NIL) & (obj IS Leonardo.Layer) THEN
			layer := obj(Leonardo.Layer);
			layer.fig.active := layer;
			UpdateLayer(layer)
		ELSE
			p := Create(obj);
			IF p # NIL THEN
				Open(p, Gadgets.context)
			END
		END
	END Activate;

	PROCEDURE AddLayer*;
		VAR fig: Leonardo.Figure; layer: Leonardo.Layer;
	BEGIN
		fig := FindFigure(Gadgets.context);
		IF fig # NIL THEN
			Leonardo.ClearSelection(fig);
			NEW(layer); Leonardo.InitLayer(layer, "New", TRUE, TRUE, TRUE);
			Leonardo.AddLayer(fig, layer);
			UpdateLayer(layer)
		END
	END AddLayer;

	PROCEDURE DeleteLayer*;
		VAR obj: Objects.Object; layer: Leonardo.Layer; fig: Leonardo.Figure;
	BEGIN
		Links.GetLink(FindEditor(Gadgets.context), "Model", obj);
		IF (obj # NIL) & (obj IS Leonardo.Layer) THEN
			layer := obj(Leonardo.Layer); fig := layer.fig;
			IF layer = fig.active THEN
				Leonardo.DeleteLayer(fig);
				UpdateLayer(fig.active)
			END
		END
	END DeleteLayer;

	PROCEDURE MoveLayerUp*;
		VAR obj: Objects.Object; layer: Leonardo.Layer;
	BEGIN
		Links.GetLink(FindEditor(Gadgets.context), "Model", obj);
		IF (obj # NIL) & (obj IS Leonardo.Layer) THEN
			layer := obj(Leonardo.Layer);
			IF layer = layer.fig.active THEN
				Leonardo.MoveLayerUp(layer.fig)
			END
		END
	END MoveLayerUp;

	PROCEDURE MoveLayerDown*;
		VAR obj: Objects.Object; layer: Leonardo.Layer;
	BEGIN
		Links.GetLink(FindEditor(Gadgets.context), "Model", obj);
		IF (obj # NIL) & (obj IS Leonardo.Layer) THEN
			layer := obj(Leonardo.Layer);
			IF layer = layer.fig.active THEN
				Leonardo.MoveLayerDown(layer.fig)
			END
		END
	END MoveLayerDown;

	PROCEDURE SelectLayer*;
		VAR obj: Objects.Object; layer: Leonardo.Layer; fig: Leonardo.Figure; cur, list: Leonardo.Shape;
	BEGIN
		Links.GetLink(FindEditor(Gadgets.context), "Model", obj);
		IF (obj # NIL) & (obj IS Leonardo.Layer) THEN
			layer := obj(Leonardo.Layer); fig := layer.fig;
			cur := layer.top; list := NIL;
			WHILE cur # NIL DO
				cur.slink := list; list := cur; cur := cur.down
			END;
			Leonardo.DisableUpdate(fig);
			Leonardo.ClearSelection(fig); Leonardo.Select(fig, list);
			Leonardo.EnableUpdate(fig)
		END
	END SelectLayer;

	PROCEDURE SelectionToLayer*;
		VAR obj: Objects.Object; layer, active: Leonardo.Layer; fig: Leonardo.Figure; sel: Leonardo.Shape;
	BEGIN
		Links.GetLink(FindEditor(Gadgets.context), "Model", obj);
		IF (obj # NIL) & (obj IS Leonardo.Layer) THEN
			layer := obj(Leonardo.Layer); fig := layer.fig;
			sel := Leonardo.Selection(fig);
			IF sel # NIL THEN
				active := fig.active; fig.active := layer;
				Leonardo.DisableUpdate(fig);
				Leonardo.BeginCommand(fig);
				Leonardo.Delete(fig, sel);
				Leonardo.Integrate(fig, sel);
				Leonardo.EndCommand(fig);
				Leonardo.EnableUpdate(fig);
				fig.active := active
			END
		END
	END SelectionToLayer;


	(**--- Shape Priority ---**)

	PROCEDURE OrderSelection*;
		VAR fig: Leonardo.Figure; s: Attributes.Scanner; om: Leonardo.OrderMsg;
	BEGIN
		fig := FindFigure(Gadgets.context);
		IF fig # NIL THEN
			Attributes.OpenScanner(s, Oberon.Par.text, Oberon.Par.pos); Attributes.Scan(s);
			IF s.class = Attributes.Int THEN
				Leonardo.BeginCommand(fig);
				Leonardo.MarkSelection(fig);
				Objects.Stamp(om); om.id := SHORT(s.i); fig.handle(fig, om);
				Leonardo.EndCommand(fig)
			END
		END
	END OrderSelection;


	(**--- Arrange Selection ---**)

	PROCEDURE Arrange*;
		CONST
			x = 0; y = 1;
			min = 0; max = 1; mid = 2;
			resizeMin = 1; resizeMax = 2; resizeConst = 3;
			alignMin = 1; alignMax = 2; alignCenter = 3;
			distribMin = 4; distribMax = 5; distribCenter = 6; distribSpace = 7;
			spaceMin = 1; spaceMax = 2; spaceConst = 3;

		TYPE
			Reference = POINTER TO RECORD
				shape: Leonardo.Shape;
				next: Reference;
				c, d: ARRAY 2, 3 OF FLOAT32;	(* coordinate and displacement for x/y, min/max/mid *)
			END;

		VAR
			fig: Leonardo.Figure; sel: Leonardo.Shape; first, last, ref: Reference; xy, val, n: SIGNED32;
			obj: Objects.Object; mat: GfxMatrix.Matrix;

		PROCEDURE const (obj: Objects.Object): FLOAT32;
			VAR val: FLOAT32; frame: Gadgets.Frame; tool: LeoTools.Tool;
		BEGIN
			Attributes.GetReal(obj, "Value", val);
			frame := FindFrame(Gadgets.context);
			IF (frame # NIL) & (frame IS LeoFrames.Frame) THEN
				tool := LeoTools.Current(frame(LeoFrames.Frame));
				IF tool # NIL THEN
					val := val*tool.unit
				END
			END;
			RETURN val
		END const;

		PROCEDURE findMax (xy, lo, hi: SIGNED32): FLOAT32;
			VAR ref: Reference; max, m: FLOAT32;
		BEGIN
			ref := first; max := ref.c[xy, hi] - ref.c[xy, lo]; ref := ref.next;
			WHILE ref # NIL DO
				m := ref.c[xy, hi] - ref.c[xy, lo];
				IF m > max THEN max := m END;
				ref := ref.next
			END;
			RETURN max
		END findMax;

		PROCEDURE setDim (xy: SIGNED32; dim: FLOAT32);
			VAR ref: Reference; d: FLOAT32;
		BEGIN
			ref := first;
			WHILE ref # NIL DO
				d := 0.5*(dim - ref.c[xy, max] + ref.c[xy, min]);
				ref.d[xy, min] := -d; ref.d[xy, max] := d;
				ref := ref.next
			END
		END setDim;

		PROCEDURE align (xy, m: SIGNED32; step: FLOAT32);
			VAR ref: Reference; to, d: FLOAT32;
		BEGIN
			ref := first; to := ref.c[xy, m] + ref.d[xy, m]; ref := ref.next;
			WHILE ref # NIL DO
				to := to + step;
				d := to - ref.c[xy, m] - ref.d[xy, m];
				ref.d[xy, min] := ref.d[xy, min] + d;
				ref.d[xy, max] := ref.d[xy, max] + d;
				ref := ref.next
			END
		END align;

		PROCEDURE sort (xy, m: SIGNED32);
			VAR sent, cand, ref: Reference; max, t: FLOAT32;
		BEGIN
			NEW(sent); sent.next := first; first := NIL;
			WHILE sent.next # NIL DO
				cand := sent; max := cand.next.c[xy, m] + cand.next.d[xy, m];
				ref := cand.next;
				WHILE ref.next # NIL DO
					t := ref.next.c[xy, m] + ref.next.d[xy, m];
					IF t > max THEN cand := ref; max := t END;
					ref := ref.next
				END;
				ref := cand.next; cand.next := ref.next;
				ref.next := first; first := ref
			END;
			last := first;
			WHILE last.next # NIL DO last := last.next END
		END sort;

		PROCEDURE distribute (xy, m: SIGNED32);
			VAR s: SIGNED32; p, q: Reference; step, t: FLOAT32;
		BEGIN
			sort(xy, m);
			Attributes.GetInt(SpaceType[xy], "Value", s);
			IF s = spaceMin THEN
				p := first; q := p.next; step := MAX(FLOAT32);
				REPEAT
					t := (q.c[xy, m] + q.d[xy, m]) - (p.c[xy, m] + p.d[xy, m]);
					IF t < step THEN step := t END;
					p := q; q := p.next
				UNTIL q = NIL
			ELSIF s = spaceMax THEN
				p := first; q := p.next; step := 0;
				REPEAT
					t := (q.c[xy, m] + q.d[xy, m]) - (p.c[xy, m] + p.d[xy, m]);
					IF t > step THEN step := t END;
					p := q; q := p.next
				UNTIL q = NIL
			ELSIF s = spaceConst THEN
				step := const(SpaceDim[xy])
			ELSE	(* average space *)
				step := ((last.c[xy, m] + last.d[xy, m]) - (first.c[xy, m] + first.d[xy, m]))/(n-1)
			END;
			align(xy, m, step)
		END distribute;

		PROCEDURE distributeSpace (xy: SIGNED32);
			VAR s: SIGNED32; p, q, ref: Reference; step, d, sum, to: FLOAT32;
		BEGIN
			sort(xy, mid);
			Attributes.GetInt(SpaceType[xy], "Value", s);
			IF s = spaceMin THEN
				p := first; q := p.next; step := MAX(FLOAT32);
				REPEAT
					d := (q.c[xy, min] + q.d[xy, min]) - (p.c[xy, max] + p.d[xy, max]);
					IF d < step THEN step := d END;
					p := q; q := p.next
				UNTIL q = NIL
			ELSIF s = spaceMax THEN
				p := first; q := p.next; step := 0;
				REPEAT
					d := (q.c[xy, min] + q.d[xy, min]) - (p.c[xy, max] + p.d[xy, max]);
					IF d > step THEN step := d END;
					p := q; q := p.next
				UNTIL q = NIL
			ELSIF s = spaceConst THEN
				step := const(SpaceDim[xy])
			ELSE	(* average space *)
				ref := first; sum := 0;
				WHILE ref # NIL DO
					sum := sum + (ref.c[xy, max] + ref.d[xy, max]) - (ref.c[xy, min] + ref.d[xy, min]);
					ref := ref.next
				END;
				step := ((last.c[xy, max] + last.d[xy, max]) - (first.c[xy, min] + first.d[xy, min]) - sum)/(n-1)
			END;
			ref := first; to := ref.c[xy, max] + ref.d[xy, max]; ref := ref.next;
			WHILE ref # NIL DO
				d := to + step - ref.c[xy, min] - ref.d[xy, min];
				ref.d[xy, min] := ref.d[xy, min] + d;
				ref.d[xy, max] := ref.d[xy, max] + d;
				to := ref.c[xy, max] + ref.d[xy, max];
				ref := ref.next
			END
		END distributeSpace;

	BEGIN
		fig := FindFigure(Gadgets.context);
		IF fig # NIL THEN
			sel := Leonardo.Selection(fig);
			IF sel # NIL THEN
				NEW(first); first.shape := sel;
				first.c[x, min] := sel.llx; first.c[y, min] := sel.lly; first.c[x, max] := sel.urx; first.c[y, max] := sel.ury;
				first.c[x, mid] := 0.5*(first.c[x, min] + first.c[x, max]); first.c[y, mid] := 0.5*(first.c[y, min] + first.c[y, max]);
				first.d[x, min] := 0; first.d[y, min] := 0; first.d[x, max] := 0; first.d[y, max] := 0; first.d[x, mid] := 0; first.d[y, mid] := 0;
				obj := sel.slink; n := 1; last := first;
				WHILE obj # NIL DO
					INC(n);
					NEW(ref); ref.next := first; first := ref; ref.shape := obj(Leonardo.Shape);
					ref.c[x, min] := ref.shape.llx; ref.c[y, min] := ref.shape.lly; ref.c[x, max] := ref.shape.urx; ref.c[y, max] := ref.shape.ury;
					ref.c[x, mid] := 0.5*(ref.c[x, min] + ref.c[x, max]); ref.c[y, mid] := 0.5*(ref.c[y, min] + ref.c[y, max]);
					ref.d[x, min] := 0; ref.d[y, min] := 0; ref.d[x, max] := 0; ref.d[y, max] := 0; ref.d[x, mid] := 0; ref.d[y, mid] := 0;
					obj := obj.slink
				END;
				FOR xy := x TO y DO
					Attributes.GetInt(ResizeType[xy], "Value", val);
					CASE val OF
					| resizeMax: setDim(xy, findMax(xy, min, max))
					| resizeMin: setDim(xy, -findMax(xy, max, min))
					| resizeConst: setDim(xy, const(ResizeDim[xy]))
					ELSE
					END
				END;
				IF first.next # NIL THEN
					FOR xy := x TO y DO
						Attributes.GetInt(AlignType[xy], "Value", val);
						CASE val OF
						| alignMin: align(xy, min, 0)
						| alignMax: align(xy, max, 0)
						| alignCenter: align(xy, mid, 0)
						| distribMin: distribute(xy, min)
						| distribMax: distribute(xy, max)
						| distribCenter: distribute(xy, mid)
						| distribSpace: distributeSpace(xy)
						ELSE
						END
					END
				END;
				Leonardo.DisableUpdate(fig);
				Leonardo.BeginCommand(fig);
				ref := first;
				WHILE ref # NIL DO
					IF (ref.d[x, min] # 0) OR (ref.d[x, max] # 0) OR (ref.d[y, min] # 0) OR (ref.d[y, max] # 0) THEN
						GfxMatrix.Get3PointTransform(
							ref.c[x, min], ref.c[y, min], ref.c[x, min] + ref.d[x, min], ref.c[y, min] + ref.d[y, min],
							ref.c[x, max], ref.c[y, min], ref.c[x, max] + ref.d[x, max], ref.c[y, min] + ref.d[y, min],
							ref.c[x, min], ref.c[y, max], ref.c[x, min] + ref.d[x, min], ref.c[y, max] + ref.d[y, max],
							mat
						);
						ref.shape.slink := NIL;
						Leonardo.Transform(fig, ref.shape, mat);
					END;
					ref := ref.next
				END;
				Leonardo.EndCommand(fig);
				Leonardo.EnableUpdate(fig)
			END
		END
	END Arrange;


	(**--- Current Tool ---**)

	PROCEDURE EditTool*;
		VAR frame: Gadgets.Frame; p: Objects.Object;
	BEGIN
		frame := FindFrame(Gadgets.context);
		IF frame # NIL THEN
			Links.GetLink(frame, "Editor", p);
			IF (p # NIL) & (p IS Gadgets.Frame) THEN
				Open(p(Gadgets.Frame), Gadgets.context)
			END
		END
	END EditTool;


	(**--- Focus Tool ---**)

	PROCEDURE atan2 (x, y: FLOAT32): FLOAT32;
		VAR phi: FLOAT32;
	BEGIN
		IF (ABS(x) < 1.0) & (ABS(y) >= ABS(x * MAX(FLOAT32))) THEN	(* y/x would result in overflow/divide by zero trap *)
			IF y >= 0 THEN phi := Math.pi/2
			ELSE phi := 3*Math.pi/2
			END
		ELSIF x < 0 THEN	(* 2nd or 3rd quadrant *)
			phi := Math.arctan(y/x) + Math.pi
		ELSIF y > 0 THEN	(* 1st quadrant *)
			phi := Math.arctan(y/x)
		ELSE	(* 4th quadrant *)
			phi := 2*Math.pi + Math.arctan(y/x)
		END;
		RETURN phi
	END atan2;

	PROCEDURE RevertFocus (e: Editor);
		VAR frame: LeoFrames.Frame; tool: LeoTools.Tool; x, y, dx, dy, d: FLOAT32;
	BEGIN
		IF e # NIL THEN
			Attributes.SetInt(e, "Kind", 0); Attributes.SetInt(e, "Direction", 0);
			IF (e.frame = LeoTools.Focus.frame) & LeoTools.Focus.visible THEN
				frame := LeoTools.Focus.frame; tool := LeoTools.Current(frame);
				LeoTools.PointToRuler(tool, LeoTools.Focus.x[0], LeoTools.Focus.y[0], x, y);
				Attributes.SetReal(e, "X0", x); Attributes.SetReal(e, "Y0", y);
				IF LeoTools.Focus.points > 1 THEN
					LeoTools.PointToRuler(tool, LeoTools.Focus.x[1], LeoTools.Focus.y[1], dx, dy);
					dx := dx - x; dy := dy - y; d := Math.sqrt(dx * dx + dy * dy);
					IF d > 0.01 THEN
						Attributes.SetReal(e, "DX", dx);
						Attributes.SetReal(e, "DY", dy);
						Attributes.SetInt(e, "Direction", 1);
						Attributes.SetReal(e, "Dir", atan2(dx/d, -dy/d) * (180/Math.pi))
					END
				END;
				IF LeoTools.Focus.style IN {1..4} THEN
					Attributes.SetInt(e, "Kind", LeoTools.Focus.style)
				END
			END;
			Gadgets.Update(e)
		END
	END RevertFocus;

	PROCEDURE ApplyFocus (e: Editor);
		VAR frame: LeoFrames.Frame; kind, dir: SIGNED32; pts: SIGNED16; tool: LeoTools.Tool; x, y, phi, dx, dy: FLOAT32;
	BEGIN
		IF e # NIL THEN
			IF (e.frame # LeoTools.Focus.frame) OR LeoTools.Focus.visible THEN
				Oberon.Defocus
			END;
			frame := e.frame(LeoFrames.Frame); LeoTools.Focus.frame := frame;
			Attributes.GetInt(e, "Kind", kind); Attributes.GetInt(e, "Direction", dir);
			IF (kind = 0) & (dir # 0) THEN pts := 0
			ELSIF (kind = 2) & (dir # 0) THEN pts := 1
			ELSIF (kind = 3) & (dir = 0) THEN kind := 2; pts := 1
			ELSIF dir = 0 THEN pts := 1
			ELSE pts := 2
			END;
			LeoTools.Focus.style := SHORT(kind); LeoTools.Focus.points := pts;
			IF pts > 0 THEN
				tool := LeoTools.Current(frame);
				Attributes.GetReal(e, "X0", x); Attributes.GetReal(e, "Y0", y);
				LeoTools.RulerToPoint(tool, x, y, LeoTools.Focus.x[0], LeoTools.Focus.y[0]);
				IF pts > 1 THEN
					IF dir = 2 THEN
						Attributes.GetReal(e, "Dir", phi); phi := phi * (Math.pi/180);
						dx := Math.cos(phi); dy := -Math.sin(phi)
					ELSE
						Attributes.GetReal(e, "DX", dx); Attributes.GetReal(e, "DY", dy)
					END;
					LeoTools.RulerToPoint(tool, x + dx, y + dy, LeoTools.Focus.x[1], LeoTools.Focus.y[1])
				END
			END;
			Gadgets.Update(e.frame)
		END
	END ApplyFocus;

	PROCEDURE NewFocus*;
		VAR f: Gadgets.Frame; obj: Objects.Object; e: Editor;
	BEGIN
		f := CopyObj("FocusToolPanel", TRUE);
		Links.GetLink(f, "Model", obj);
		IF (obj # NIL) & (obj IS Editor) THEN
			e := obj(Editor); e.revert := RevertFocus; e.apply := ApplyFocus;
			e.frame := FindFrame(Gadgets.context); RevertFocus(e);
			Objects.NewObj := f
		END
	END NewFocus;


BEGIN
	ResizeType[0] := FindObj("HorResizeType"); ResizeType[1] := FindObj("VertResizeType");
	ResizeDim[0] := FindObj("HorResizeDim"); ResizeDim[1] := FindObj("VertResizeDim");
	AlignType[0] := FindObj("HorAlign"); AlignType[1] := FindObj("VertAlign");
	SpaceType[0] := FindObj("HorSpaceType"); SpaceType[1] := FindObj("VertSpaceType");
	SpaceDim[0] := FindObj("HorSpaceDim"); SpaceDim[1] := FindObj("VertSpaceDim");
	PrinterName := FindObj("PrinterName"); PrintLandscape := FindObj("PrintLandscape");
	PrintPostscript := FindObj("PrintPostscript"); PSLevel2 := FindObj("PSLevel2"); PSDPI := FindObj("PSDPI");
	ExportMode := FindObj("ExportMode"); ExportBorder := FindObj("ExportBorder");
	ExportCopy := FindObj("ExportCopy"); ExportName := FindObj("ExportName")
END LeoPanels.
