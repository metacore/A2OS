(* ETH Oberon, Copyright 2001 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

MODULE LeoPenEditors IN Oberon; (** portable **)	(* eos  *)

	(**
		Editor commands for Leonardo pen objects
	**)

	IMPORT
		Files, Objects, Display, Printer, Input, Fonts, Oberon, Out, Strings, Attributes, Links, Display3, Effects,
		Printer3, Gadgets, Documents, Desktops, ListRiders, Colors, Gfx, GfxDisplay, GfxPrinter,
		Leonardo, LeoPens, LeoOutliners, LeoFrames, LeoPanels;


	TYPE
		(** gadget for previewing pen appearance **)
		Preview* = POINTER TO PreviewDesc;
		PreviewDesc* = RECORD (Gadgets.FrameDesc)
			const*: BOOLEAN;	(** no drag-and-drop allowed if set **)
		END;

		(** message asking receiver to consume a new pen **)
		DropMsg* = RECORD (Display.FrameMsg)
			pen*: LeoPens.Pen;	(** pen to consume **)
		END;

		SetPenAction = POINTER TO SetPenActionDesc;
		SetPenActionDesc = RECORD (Leonardo.ActionDesc)
			shape: Leonardo.Shape;
			name: Objects.Name;
			pen: LeoPens.Pen;
		END;

		SetLinkAction = POINTER TO SetLinkActionDesc;
		SetLinkActionDesc = RECORD (Leonardo.ActionDesc)
			pen: LeoPens.Pen;
			name: Objects.Name;
			obj: Objects.Object;
		END;

		SetIntAction = POINTER TO SetIntActionDesc;
		SetIntActionDesc = RECORD (Leonardo.ActionDesc)
			pen: LeoPens.Pen;
			name: Objects.Name;
			val: SIGNED32;
		END;

		SetRealAction = POINTER TO SetRealActionDesc;
		SetRealActionDesc = RECORD (Leonardo.ActionDesc)
			pen: LeoPens.Pen;
			name: Objects.Name;
			val: FLOAT32;
		END;

		SetBoolAction = POINTER TO SetBoolActionDesc;
		SetBoolActionDesc = RECORD (Leonardo.ActionDesc)
			pen: LeoPens.Pen;
			name: Objects.Name;
			val: BOOLEAN;
		END;


	VAR
		DC: GfxDisplay.Context;
		PFont: Fonts.Font;
		PenLib: Objects.Library;


	(**--- Pen Editors ---**)

	PROCEDURE HandleShapeEditor* (obj: Objects.Object; VAR msg: Objects.ObjMsg);
		VAR pen: Objects.Object;
	BEGIN
		IF msg IS LeoPens.UpdateMsg THEN
			Links.GetLink(obj, "Pen", pen);
			IF msg(LeoPens.UpdateMsg).pen = pen THEN
				Gadgets.Update(obj)
			ELSIF pen # NIL THEN
				pen.handle(pen, msg)
			END
		ELSE
			LeoPanels.HandleEditor(obj, msg)
		END
	END HandleShapeEditor;

	PROCEDURE HandleEditor* (obj: Objects.Object; VAR msg: Objects.ObjMsg);
		VAR pen, prev: Objects.Object; s: ARRAY 64 OF CHAR; cm: Objects.CopyMsg;
	BEGIN
		IF msg IS LeoPens.UpdateMsg THEN
			Links.GetLink(obj, "Model", pen);
			IF msg(LeoPens.UpdateMsg).pen = pen THEN
				Gadgets.Update(obj)
			ELSIF pen # NIL THEN
				pen.handle(pen, msg)
			END
		ELSIF msg IS Objects.AttrMsg THEN
			WITH msg: Objects.AttrMsg DO
				IF msg.id = Objects.set THEN
					LeoPanels.HandleEditor(obj, msg);
					IF msg.res >= 0 THEN
						Links.GetLink(obj, "Pen", prev);
						IF prev # NIL THEN	(* apply same change to preview, using automatic conversion of Attributes module *)
							Attributes.GetString(obj, msg.name, s);
							Attributes.SetString(prev, msg.name, s)
						END
					END
				ELSE
					LeoPanels.HandleEditor(obj, msg)
				END
			END
		ELSIF msg IS Objects.LinkMsg THEN
			WITH msg: Objects.LinkMsg DO
				IF msg.id = Objects.set THEN
					LeoPanels.HandleEditor(obj, msg);
					IF msg.res >= 0 THEN
						IF msg.name = "Model" THEN
							Objects.Stamp(cm); cm.id := Objects.shallow; cm.obj := NIL;
							IF msg.obj # NIL THEN msg.obj.handle(msg.obj, cm) END;
							Links.SetLink(obj, "Pen", cm.obj)
						ELSIF msg.name # "Pen" THEN
							Links.GetLink(obj, "Pen", prev);
							IF prev # NIL THEN
								prev.handle(prev, msg)	(* apply same change to preview *)
							END
						END
					END
				ELSE
					LeoPanels.HandleEditor(obj, msg)
				END
			END
		ELSE
			LeoPanels.HandleEditor(obj, msg)
		END
	END HandleEditor;


	(**--- New Pen Panel ---**)

	PROCEDURE Replace (pen: Objects.Object);
		VAR p: Gadgets.Frame; ed, obj, ref: Objects.Object; lname: Objects.Name; doc: Documents.Document;
	BEGIN
		p := LeoPanels.Create(pen);
		IF p # NIL THEN
			Links.GetLink(p, "Model", ed); obj := LeoPanels.FindEditor(Gadgets.context);
			Links.GetLink(obj, "Referer", ref); Links.SetLink(ed, "Referer", ref);
			Attributes.GetString(obj, "Link", lname); Attributes.SetString(ed, "Link", lname);
			NEW(doc); LeoPanels.InitDoc(doc, p);
			Desktops.ReplaceCurrentDoc(doc)
		END
	END Replace;

	PROCEDURE Create*;
		VAR s: Attributes.Scanner; pen: Objects.Object;
	BEGIN
		Attributes.OpenScanner(s, Oberon.Par.text, Oberon.Par.pos); Attributes.Scan(s);
		IF s.class = Attributes.Name THEN
			pen := Gadgets.CreateObject(s.s);
			IF (pen # NIL) & (pen IS LeoPens.Pen) THEN
				Replace(pen)
			END
		END
	END Create;

	PROCEDURE Make*;
		VAR
			e: LeoPanels.Editor; mode, am, col, dm, dlen: SIGNED32; c: Gfx.Color; fill: LeoPens.Filler; pen: LeoPens.Pen;
			w, dp: FLOAT32; arr: LeoOutliners.Arrow; stroke: LeoPens.Stroker; fork: LeoPens.Forker; ol: LeoOutliners.Outliner;
			on, off: ARRAY 2 OF FLOAT32; dash: LeoPens.Dasher;
	BEGIN
		e := LeoPanels.FindEditor(Gadgets.context);
		IF e # NIL THEN
			Attributes.GetInt(e, "Mode", mode);
			Attributes.GetInt(e, "ArrowMode", am);
			IF mode IN {0, 1, 4} THEN
				Attributes.GetInt(e, "AreaColor", col);
				Display.GetColor(col, c.r, c.g, c.b);
				NEW(fill); LeoPens.InitFiller(fill, c);
				pen := fill
			END;
			IF mode IN {1, 2, 3, 4} THEN
				Attributes.GetInt(e, "LineColor", col);
				Display.GetColor(col, c.r, c.g, c.b);
				Attributes.GetReal(e, "Width", w)
			END;
			IF (mode = 2) & (am IN {1..3}) THEN
				IF w < 1 THEN w := 1 END;
				NEW(fill); LeoPens.InitFiller(fill, c);
				NEW(arr); LeoOutliners.InitArrow(arr, fill, SHORT(SHORT(am-1)), LeoOutliners.outlined, 8*w, 8*w, 4*w, w);
				pen := arr
			ELSIF mode = 2 THEN
				NEW(stroke); LeoPens.InitStroker(stroke, c, w);
				pen := stroke
			ELSIF mode = 1 THEN
				NEW(stroke); LeoPens.InitStroker(stroke, c, w);
				NEW(fork); LeoPens.InitForker(fork, fill, stroke);
				pen := fork
			ELSIF mode IN {3, 4} THEN
				NEW(stroke); LeoPens.InitStroker(stroke, c, 1);
				pen := stroke;
				IF mode = 4 THEN
					NEW(fork); LeoPens.InitForker(fork, fill, stroke);
					pen := fork
				END
			END;
			IF mode IN {3, 4} THEN
				IF (am IN {1..3}) THEN
					NEW(arr); LeoOutliners.InitArrow(arr, pen, SHORT(SHORT(am-1)), LeoOutliners.outlined, 10*w, 10*w, 5*w, w);
					pen := arr
				ELSE
					NEW(ol); LeoOutliners.InitOutliner(ol, pen, w, LeoOutliners.outlined);
					pen := ol
				END
			END;
			IF mode IN {2..4} THEN
				Attributes.GetInt(e, "DashMode", dm);
				Attributes.GetReal(e, "DashPeriod", dp);
				IF dp < 1.0E-3 THEN
					dm := 0
				ELSIF dm = 1 THEN
					on[0] := 0.5*dp; off[0] := on[0]; dlen := 1
				ELSIF dm = 2 THEN
					IF w = 0 THEN on[0] := 0.01*dp ELSE on[0] := 0.01*w END;
					off[0] := dp - on[0]; dlen := 1; Attributes.SetInt(pen, "CapStyle", Gfx.RoundCap)
				END;
				IF dm # 0 THEN
					NEW(dash); LeoPens.InitDasher(dash, pen, on, off, dlen);
					dash.continuous := am # 0;
					pen := dash
				END
			END;
			Replace(pen)
		END
	END Make;

	PROCEDURE EditNew*;
		VAR p: Gadgets.Frame; s: Attributes.Scanner; lname: Objects.Name; ref, ed: Objects.Object;
	BEGIN
		p := LeoPanels.CopyObj("NewPenPanel", TRUE);
		IF p # NIL THEN
			Attributes.OpenScanner(s, Oberon.Par.text, Oberon.Par.pos); Attributes.Scan(s);
			IF s.class IN {Attributes.Name, Attributes.String} THEN COPY(s.s, lname)
			ELSE lname := "Pen"
			END;
			ref := LeoPanels.FindEditor(Gadgets.context);
			Links.GetLink(p, "Model", ed);
			Links.SetLink(ed, "Referer", ref); Attributes.SetString(ed, "Link", lname);
			LeoPanels.Open(p, Gadgets.context)
		END
	END EditNew;


	(**--- Default Pens ---**)

	PROCEDURE FindPen (CONST name: ARRAY OF CHAR): LeoPens.Pen;
		VAR ref: SIGNED16; obj: Objects.Object;
	BEGIN
		Objects.GetRef(PenLib.dict, name, ref);
		IF ref >= 0 THEN
			PenLib.GetObj(PenLib, ref, obj);
			IF (obj # NIL) & (obj IS LeoPens.Pen) THEN
				RETURN obj(LeoPens.Pen)
			END
		END;
		RETURN NIL
	END FindPen;

	PROCEDURE Find* (CONST name: ARRAY OF CHAR; closed: BOOLEAN): LeoPens.Pen;
		VAR pen: LeoPens.Pen;
	BEGIN
		pen := FindPen(name);
		IF pen = NIL THEN
			IF closed THEN pen := FindPen("Closed")
			ELSE pen := FindPen("Open")
			END;
			IF pen = NIL THEN
				pen := LeoPens.Default
			END
		END;
		RETURN pen
	END Find;

	PROCEDURE Register* (pen: LeoPens.Pen; CONST name: ARRAY OF CHAR);
		VAR ref: SIGNED16;
	BEGIN
		Objects.GetRef(PenLib.dict, name, ref);
		IF ref < 0 THEN
			PenLib.GenRef(PenLib, ref);
			Objects.PutName(PenLib.dict, ref, name)
		END;
		PenLib.PutObj(PenLib, ref, pen)
	END Register;


	(**--- Undoable Actions ---**)

	PROCEDURE DoSetPenAction (fig: Leonardo.Figure; act: Leonardo.Action);
		VAR a: SetPenAction; lm: Objects.LinkMsg; obj: Objects.Object;
	BEGIN
		a := act(SetPenAction);
		lm.id := Objects.get; COPY(a.name, lm.name); lm.obj := NIL; lm.res := -1; a.shape.handle(a.shape, lm);
		obj := lm.obj; lm.obj := a.pen; a.pen := obj(LeoPens.Pen);
		lm.id := Objects.set; lm.res := -1; a.shape.handle(a.shape, lm);
		a.shape.sel := TRUE; a.shape.marked := TRUE
	END DoSetPenAction;

	(** set shape pen with undoable action **)
	PROCEDURE SetPen* (fig: Leonardo.Figure; shape: Leonardo.Shape; CONST name: ARRAY OF CHAR; pen: LeoPens.Pen);
		VAR lm: Objects.LinkMsg; a: SetPenAction;
	BEGIN
		lm.id := Objects.get; COPY(name, lm.name); lm.obj := NIL; lm.res := -1; shape.handle(shape, lm);
		IF (lm.res >= 0) & (lm.obj # NIL) & (lm.obj IS LeoPens.Pen) & (lm.obj # pen) THEN
			NEW(a); a.shape := shape; COPY(name, a.name); a.pen := pen; a.do := DoSetPenAction; a.undo := DoSetPenAction;
			Leonardo.AddAction(fig, a)
		END
	END SetPen;

	PROCEDURE DoSetLinkAction (fig: Leonardo.Figure; act: Leonardo.Action);
		VAR a: SetLinkAction; lm: Objects.LinkMsg; obj: Objects.Object;
	BEGIN
		a := act(SetLinkAction);
		lm.id := Objects.get; COPY(a.name, lm.name); lm.obj := NIL; lm.res := -1; a.pen.handle(a.pen, lm);
		obj := lm.obj; lm.obj := a.obj; a.obj := obj;
		lm.id := Objects.set; lm.res := -1; a.pen.handle(a.pen, lm);
		LeoPens.Update(a.pen)
	END DoSetLinkAction;

	(** set link with undoable action **)
	PROCEDURE SetLink* (fig: Leonardo.Figure; pen: LeoPens.Pen; CONST name: ARRAY OF CHAR; obj: Objects.Object);
		VAR lm: Objects.LinkMsg; a: SetLinkAction;
	BEGIN
		lm.id := Objects.get; COPY(name, lm.name); lm.obj := NIL; lm.res := -1; pen.handle(pen, lm);
		IF (lm.res >= 0) & (lm.obj # NIL) & (lm.obj # obj) THEN
			IF fig # NIL THEN
				NEW(a); a.pen := pen; COPY(name, a.name); a.obj := obj; a.do := DoSetLinkAction; a.undo := DoSetLinkAction;
				Leonardo.AddAction(fig, a)
			ELSE
				lm.id := Objects.set; lm.obj := obj; lm.res := -1; pen.handle(pen, lm)
			END
		END
	END SetLink;

	PROCEDURE DoSetIntAction (fig: Leonardo.Figure; act: Leonardo.Action);
		VAR a: SetIntAction; am: Objects.AttrMsg; val: SIGNED32;
	BEGIN
		a := act(SetIntAction);
		am.id := Objects.get; COPY(a.name, am.name); am.res := -1; a.pen.handle(a.pen, am);
		val := am.i; am.i := a.val; a.val := val;
		am.id := Objects.set; am.res := -1; a.pen.handle(a.pen, am);
		LeoPens.Update(a.pen)
	END DoSetIntAction;

	(** set integer attribute value with undoable action **)
	PROCEDURE SetInt* (fig: Leonardo.Figure; pen: LeoPens.Pen; CONST name: ARRAY OF CHAR; val: SIGNED32);
		VAR am: Objects.AttrMsg; a: SetIntAction;
	BEGIN
		am.id := Objects.get; COPY(name, am.name); am.res := -1; pen.handle(pen, am);
		IF (am.res >= 0) & (am.class = Objects.Int) & (am.i # val) THEN
			IF fig # NIL THEN
				NEW(a); a.pen := pen; COPY(name, a.name); a.val := val; a.do := DoSetIntAction; a.undo := DoSetIntAction;
				Leonardo.AddAction(fig, a)
			ELSE
				am.id := Objects.set; am.i := val; am.res := -1; pen.handle(pen, am)
			END
		END
	END SetInt;

	PROCEDURE DoSetRealAction (fig: Leonardo.Figure; act: Leonardo.Action);
		VAR a: SetRealAction; am: Objects.AttrMsg; val: FLOAT32;
	BEGIN
		a := act(SetRealAction);
		am.id := Objects.get; COPY(a.name, am.name); am.res := -1; a.pen.handle(a.pen, am);
		val := am.x; am.x := a.val; a.val := val;
		am.id := Objects.set; am.res := -1; a.pen.handle(a.pen, am);
		LeoPens.Update(a.pen)
	END DoSetRealAction;

	(** set real attribute value with undoable action **)
	PROCEDURE SetReal* (fig: Leonardo.Figure; pen: LeoPens.Pen; CONST name: ARRAY OF CHAR; val: FLOAT32);
		VAR am: Objects.AttrMsg; a: SetRealAction;
	BEGIN
		am.id := Objects.get; COPY(name, am.name); am.res := -1; pen.handle(pen, am);
		IF (am.res >= 0) & (am.class = Objects.Real) & (am.x # val) THEN
			IF fig # NIL THEN
				NEW(a); a.pen := pen; COPY(name, a.name); a.val := val; a.do := DoSetRealAction; a.undo := DoSetRealAction;
				Leonardo.AddAction(fig, a)
			ELSE
				am.id := Objects.set; am.x := val; am.res := -1; pen.handle(pen, am)
			END
		END
	END SetReal;

	PROCEDURE DoSetBoolAction (fig: Leonardo.Figure; act: Leonardo.Action);
		VAR a: SetBoolAction; am: Objects.AttrMsg; val: BOOLEAN;
	BEGIN
		a := act(SetBoolAction);
		am.id := Objects.get; COPY(a.name, am.name); am.res := -1; a.pen.handle(a.pen, am);
		val := am.b; am.b := a.val; a.val := val;
		am.id := Objects.set; am.res := -1; a.pen.handle(a.pen, am);
		LeoPens.Update(a.pen)
	END DoSetBoolAction;

	(** set boolean attribute value with undoable action **)
	PROCEDURE SetBool* (fig: Leonardo.Figure; pen: LeoPens.Pen; CONST name: ARRAY OF CHAR; val: BOOLEAN);
		VAR am: Objects.AttrMsg; a: SetBoolAction;
	BEGIN
		am.id := Objects.get; COPY(name, am.name); am.res := -1; pen.handle(pen, am);
		IF (am.res >= 0) & (am.class = Objects.Bool) & (am.b # val) THEN
			IF fig # NIL THEN
				NEW(a); a.pen := pen; COPY(name, a.name); a.val := val; a.do := DoSetBoolAction; a.undo := DoSetBoolAction;
				Leonardo.AddAction(fig, a)
			ELSE
				am.id := Objects.set; am.b := val; am.res := -1; pen.handle(pen, am)
			END
		END
	END SetBool;

	PROCEDURE SetColor* (fig: Leonardo.Figure; pen: LeoPens.Pen; col: SIGNED32);
		VAR r, g, b: SIGNED16;
	BEGIN
		Display.GetColor(col, r, g, b);
		SetInt(fig, pen, "Red", r); SetInt(fig, pen, "Green", g); SetInt(fig, pen, "Blue", b)
	END SetColor;


	(**--- Pen Panel ---**)

	PROCEDURE InitPenLib;
		VAR open: LeoPens.Stroker; fill: LeoPens.Filler; closed: LeoPens.Forker;
	BEGIN
		NEW(PenLib); Objects.OpenLibrary(PenLib);
		NEW(open); LeoPens.InitStroker(open, Gfx.Black, 1.0);
		Register(open, "Open");
		NEW(fill); LeoPens.InitFiller(fill, Gfx.White);
		NEW(closed); LeoPens.InitForker(closed, fill, open);
		Register(closed, "Closed")
	END InitPenLib;

	PROCEDURE MakePenList (list: Objects.Object);
		VAR cm: ListRiders.ConnectMsg; ref: SIGNED16; obj: Objects.Object; name: ARRAY 64 OF CHAR; sd: ListRiders.String;
	BEGIN
		IF list # NIL THEN
			Objects.Stamp(cm); cm.R := NIL; list.handle(list, cm);
			IF cm.R # NIL THEN
				WHILE ~cm.R.eol DO cm.R.do.DeleteLink(NIL, cm.R) END;
				cm.R.do.Set(cm.R, 0); ref := 0;
				WHILE ref <= PenLib.maxref DO
					PenLib.GetObj(PenLib, ref, obj);
					IF (obj # NIL) & (obj IS LeoPens.Pen) THEN
						Objects.GetName(PenLib.dict, ref, name);
						IF name # "" THEN
							NEW(sd); COPY(name, sd.s);
							cm.R.do.Write(cm.R, sd)
						END
					END;
					INC(ref)
				END;
				Gadgets.Update(list)
			END
		END
	END MakePenList;

	PROCEDURE StorePenLib*;
		VAR s: Attributes.Scanner; file: Files.File; bm: Objects.BindMsg; ref: SIGNED16; obj: Objects.Object; len: SIGNED32;
	BEGIN
		Oberon.Defocus;
		Attributes.OpenScanner(s, Oberon.Par.text, Oberon.Par.pos); Attributes.Scan(s);
		IF s.class = Attributes.Name THEN
			file := Files.New(s.s);
			IF file # NIL THEN
				Objects.Stamp(bm); bm.lib := PenLib;
				ref := 0;
				WHILE ref <= PenLib.maxref DO
					PenLib.GetObj(PenLib, ref, obj);
					IF (obj # NIL) & (obj IS LeoPens.Pen) THEN
						obj.handle(obj, bm)	(* bind all referenced objects as well *)
					END;
					INC(ref)
				END;
				Out.String("store "); Out.String(s.s); Out.Ln;
				Objects.StoreLibrary(PenLib, file, 0, len);
				Files.Register(file)
			END
		END
	END StorePenLib;

	PROCEDURE LoadPenLib*;
		VAR s: Attributes.Scanner; lib: Objects.Library; obj: Objects.Object;
	BEGIN
		Oberon.Defocus;
		Attributes.OpenScanner(s, Oberon.Par.text, Oberon.Par.pos); Attributes.Scan(s);
		IF s.class = Attributes.Name THEN
			lib := Objects.ThisLibrary(s.s);
			IF lib # NIL THEN
				Out.String("load "); Out.String(s.s); Out.Ln;
				PenLib := lib;
				Links.GetLink(LeoPanels.FindEditor(Gadgets.context), "PenList", obj);
				MakePenList(obj)
			END
		END
	END LoadPenLib;

	PROCEDURE SelListPen*;
		VAR s: Attributes.Scanner; ref: SIGNED16; obj: Objects.Object; e: LeoPanels.Editor;
	BEGIN
		Attributes.OpenScanner(s, Oberon.Par.text, Oberon.Par.pos); Attributes.Scan(s);
		IF s.class IN {Attributes.Name, Attributes.String} THEN
			Objects.GetRef(PenLib.dict, s.s, ref);
			IF ref >= 0 THEN
				PenLib.GetObj(PenLib, ref, obj);
				IF (obj # NIL) & (obj IS LeoPens.Pen) THEN
					e := LeoPanels.FindEditor(Gadgets.context);
					IF e # NIL THEN
						Links.SetLink(e, "Pen", obj);
						Attributes.SetString(e, "PenName", s.s);
						Gadgets.Update(e)
					END
				END
			END
		END
	END SelListPen;

	PROCEDURE AddListPen*;
		VAR e: LeoPanels.Editor; obj: Objects.Object; name: ARRAY 64 OF CHAR;
	BEGIN
		e := LeoPanels.FindEditor(Gadgets.context);
		IF e # NIL THEN
			Links.GetLink(e, "Pen", obj);
			IF (obj # NIL) & (obj IS LeoPens.Pen) THEN
				Attributes.GetString(e, "PenName", name);
				IF name # "" THEN
					Register(obj(LeoPens.Pen), name);
					Links.GetLink(e, "PenList", obj);
					IF obj # NIL THEN
						MakePenList(obj);
						Gadgets.Update(obj)
					END
				END
			END
		END
	END AddListPen;

	PROCEDURE DelListPen*;
		VAR e: LeoPanels.Editor; name: ARRAY 64 OF CHAR; ref: SIGNED16; obj: Objects.Object;
	BEGIN
		e := LeoPanels.FindEditor(Gadgets.context);
		IF e # NIL THEN
			Attributes.GetString(e, "PenName", name);
			IF name # "" THEN
				Objects.GetRef(PenLib.dict, name, ref);
				IF ref >= 0 THEN
					PenLib.FreeObj(PenLib, ref);
					Objects.PutName(PenLib.dict, ref, "");
					Links.GetLink(e, "PenList", obj);
					IF obj # NIL THEN
						MakePenList(obj);
						Gadgets.Update(obj)
					END
				END
			END
		END
	END DelListPen;

	PROCEDURE InspectSel*;
		VAR e: LeoPanels.Editor; fig: Leonardo.Figure; sel: Leonardo.Shape; pen: Objects.Object;
	BEGIN
		e := LeoPanels.FindEditor(Gadgets.context); fig := LeoPanels.FindFigure(Gadgets.context);
		IF (e # NIL) & (fig # NIL) THEN
			sel := Leonardo.Selection(fig);
			IF sel # NIL THEN
				Links.GetLink(sel, "Pen", pen);
				IF (pen # NIL) & (pen IS LeoPens.Pen) THEN
					Links.SetLink(e, "Pen", pen);
					Gadgets.Update(e)
				END
			END
		END
	END InspectSel;

	PROCEDURE ApplySel*;
		VAR e: LeoPanels.Editor; fig: Leonardo.Figure; obj: Objects.Object; pen: LeoPens.Pen;
	BEGIN
		e := LeoPanels.FindEditor(Gadgets.context); fig := LeoPanels.FindFigure(Gadgets.context);
		IF (e # NIL) & (fig # NIL) THEN
			Links.GetLink(e, "Pen", obj);
			IF (obj # NIL) & (obj IS LeoPens.Pen) THEN
				pen := obj(LeoPens.Pen);
				obj := Leonardo.Selection(fig);
				IF obj # NIL THEN
					Leonardo.BeginCommand(fig);
					REPEAT
						SetPen(fig, obj(Leonardo.Shape), "Pen", pen);
						obj := obj.slink
					UNTIL obj = NIL;
					Leonardo.EndCommand(fig)
				END
			END
		END
	END ApplySel;

	PROCEDURE RevertPens (e: LeoPanels.Editor);
		VAR list: Objects.Object;
	BEGIN
		Links.GetLink(e, "PenList", list); MakePenList(list)
	END RevertPens;

	PROCEDURE ApplyPens (e: LeoPanels.Editor);
	END ApplyPens;

	PROCEDURE EditPens*;
		VAR p: Gadgets.Frame; obj: Objects.Object; e: LeoPanels.Editor;
	BEGIN
		p := LeoPanels.CopyObj("PenPanel", TRUE);
		IF p # NIL THEN
			Links.GetLink(p, "Model", obj);
			IF (obj # NIL) & (obj IS LeoPanels.Editor) THEN
				e := obj(LeoPanels.Editor); e.handle := HandleShapeEditor;
				e.revert := RevertPens; e.apply := ApplyPens;
				RevertPens(e);
				LeoPanels.Open(p, Gadgets.context)
			END
		END
	END EditPens;


	(**--- Select Pen ---**)

	PROCEDURE RevertSelect (e: LeoPanels.Editor);
		VAR ref, obj, list: Objects.Object; VAR lname: ARRAY 64 OF CHAR;
	BEGIN
		Links.GetLink(e, "Referer", ref); Attributes.GetString(e, "Link", lname);
		Links.GetLink(ref, lname, obj); Links.SetLink(e, "Pen", obj); Links.SetLink(e, "Model", obj);
		Links.GetLink(e, "PenList", list); MakePenList(list);
		Gadgets.Update(e)
	END RevertSelect;

	PROCEDURE ApplySelect (e: LeoPanels.Editor);
		VAR ref, obj: Objects.Object; VAR lname: ARRAY 64 OF CHAR;
	BEGIN
		Links.GetLink(e, "Referer", ref);
		IF ref # NIL THEN
			Attributes.GetString(e, "Link", lname);
			Links.GetLink(e, "Pen", obj); Links.SetLink(ref, lname, obj); Links.SetLink(e, "Model", obj);
			Gadgets.Update(ref)
		END
	END ApplySelect;

	PROCEDURE Select*;
		VAR p: Gadgets.Frame; s: Attributes.Scanner; lname: ARRAY 64 OF CHAR; ref, e: LeoPanels.Editor; obj: Objects.Object;
	BEGIN
		p := LeoPanels.CopyObj("PenPanel", TRUE);
		IF p # NIL THEN
			Attributes.OpenScanner(s, Oberon.Par.text, Oberon.Par.pos); Attributes.Scan(s);
			IF s.class IN {Attributes.Name, Attributes.String} THEN COPY(s.s, lname)
			ELSE lname := "Pen"
			END;
			ref := LeoPanels.FindEditor(Gadgets.context);
			Links.GetLink(p, "Model", obj);
			IF (obj # NIL) & (obj IS LeoPanels.Editor) THEN
				e := obj(LeoPanels.Editor); e.revert := RevertSelect; e.apply := ApplySelect;
				Links.SetLink(e, "Referer", ref); Attributes.SetString(e, "Link", lname);
				RevertSelect(e);
				LeoPanels.Open(p, Gadgets.context)
			END
		END
	END Select;


	(**--- Previews ---**)

	PROCEDURE TrackPreview (prev: Preview; VAR msg: Oberon.InputMsg);
		VAR
			px, py, mx, my, x, y, u, v: SIGNED16; mask: Display3.Mask; keysum, keys: SET; obj: Objects.Object;
			cm: Objects.CopyMsg; target: Display.Frame; dm: DropMsg;
	BEGIN
		px := msg.x + prev.X; py := msg.y + prev.Y;
		Gadgets.MakeMask(prev, px, py, msg.dlink, mask);
		Oberon.FadeCursor(Oberon.Mouse);
		Display3.Rect(mask, Display3.invertC, Display.solid, px, py, prev.W, prev.H, 1, Display.invert);
		keysum := msg.keys; mx := -1; my := -1;
		REPEAT
			Input.Mouse(keys, x, y);
			IF (keys # {}) & ((keysum + keys # keysum) OR (x # mx) OR (y # my)) THEN
				keysum := keysum + keys;
				IF (keysum = {1, 2}) OR (keysum = {1, 0}) THEN Oberon.DrawCursor(Oberon.Mouse, Effects.FlatHand, x, y)
				ELSE Oberon.DrawCursor(Oberon.Mouse, Effects.Arrow, x, y)
				END;
				mx := x; my := y
			END
		UNTIL keys = {};
		Display3.Rect(mask, Display3.invertC, Display.solid, px, py, prev.W, prev.H, 1, Display.invert);
		IF keysum # {0, 1, 2} THEN
			IF keysum = {1} THEN
				Gadgets.ExecuteAttr(prev, "Cmd", msg.dlink, NIL, NIL)
			ELSE
				Links.GetLink(prev.obj, "Pen", obj);
				IF (obj # NIL) & (obj IS LeoPens.Pen) THEN
					IF keysum = {1, 0} THEN	(* use copy of pen *)
						Objects.Stamp(cm); cm.dlink := NIL; cm.id := Objects.shallow; cm.obj := NIL; obj.handle(obj, cm);
						IF (cm.obj # NIL) & (cm.obj IS LeoPens.Pen) THEN
							obj := cm.obj
						END
					END;
					Gadgets.ThisFrame(mx, my, target, u, v);
					dm.F := target; dm.pen := obj(LeoPens.Pen);
					Display.Broadcast(dm)
				END
			END
		END;
		Oberon.DrawCursor(Oberon.Mouse, Effects.Arrow, mx, y);
		msg.res := 0
	END TrackPreview;

	PROCEDURE RenderPreview (ctxt: Gfx.Context; pen: LeoPens.Pen; w, h: FLOAT32);
	BEGIN
		pen.do.begin(pen, ctxt);
		pen.do.enter(pen, -w, h, 0, 0, 0);
		pen.do.line(pen, 0, -h); pen.do.line(pen, w, h);
		pen.do.exit(pen, 0, 0, 0);
		pen.do.end(pen)
	END RenderPreview;

	PROCEDURE RestorePreview (prev: Preview; px, py: SIGNED16; mask: Display3.Mask);
		VAR obj: Objects.Object; pen: LeoPens.Pen; bw, d, w, h: FLOAT32; scale: SIGNED32; s, t: ARRAY 16 OF CHAR;
	BEGIN
		Display3.FilledRect3D(mask, Display3.bottomC, Display3.topC, Display3.textbackC, px, py, prev.W, prev.H, 1, Display.replace);
		Links.GetLink(prev.obj, "Pen", obj);
		IF (obj # NIL) & (obj IS LeoPens.Pen) THEN
			pen := obj(LeoPens.Pen);
			Attributes.GetReal(pen, "Border", bw); scale := 1;
			IF prev.W < prev.H THEN d := prev.W/4 ELSE d := prev.H/4 END;
			WHILE bw > d DO
				scale := 2*scale; bw := 0.5*bw
			END;
			w := 0.25 * prev.W * scale; h := 0.25 * prev.H * scale;
			GfxDisplay.SetCoordinates(DC, px + prev.W DIV 2, py + prev.H DIV 2, 1/scale);
			GfxDisplay.SetClipRegion(DC, LeoFrames.RegionFromMask(mask));
			Gfx.Reset(DC);
			RenderPreview(DC, pen, w, h);
			IF scale # 1 THEN
				s := "x 1/"; Strings.IntToStr(scale, t); Strings.Append(s, t);
				Display3.CenterString(mask, Display3.black, px+1, py-1, prev.W, prev.H, PFont, s, Display.paint);
				Display3.CenterString(mask, Display3.white, px, py, prev.W, prev.H, PFont, s, Display.paint)
			END
		END;
		IF Gadgets.selected IN prev.state THEN
			Display3.FillPattern(mask, Display3.white, Display3.selectpat, px, py, px, py, prev.W, prev.H, Display.paint)
		END
	END RestorePreview;

	PROCEDURE PrintPreview (prev: Preview; VAR msg: Display.DisplayMsg);
		VAR
			pw, ph, pix: SIGNED16; mask: Display3.Mask; obj: Objects.Object; pen: LeoPens.Pen;
			bw, d, w, h: FLOAT32; scale: SIGNED32; ctxt: GfxPrinter.Context; s, t: ARRAY 16 OF CHAR;
	BEGIN
		pw := SHORT(LONG(prev.W) * Display.Unit DIV Printer.Unit);
		ph := SHORT(LONG(prev.H) * Display.Unit DIV Printer.Unit);
		pix := SHORT(Display.Unit DIV Printer.Unit);
		Gadgets.MakePrinterMask(prev, msg.x, msg.y, msg.dlink, mask);
		Printer3.FilledRect3D(mask, Display3.bottomC, Display3.topC, Display3.textbackC, msg.x, msg.y, pw, ph, pix, Display.replace);
		Links.GetLink(prev.obj, "Pen", obj);
		IF (obj # NIL) & (obj IS LeoPens.Pen) THEN
			pen := obj(LeoPens.Pen);
			Attributes.GetReal(pen, "Border", bw); scale := 1;
			IF prev.W < prev.H THEN d := prev.W/5 ELSE d := prev.H/5 END;
			WHILE bw > d DO
				scale := 2*scale; bw := 0.5*bw
			END;
			w := 0.25 * prev.W * scale; h := 0.25 * prev.H * scale;
			NEW(ctxt); GfxPrinter.Init(ctxt);
			GfxPrinter.SetCoordinates(ctxt, msg.x + pw DIV 2, msg.y + ph DIV 2, ctxt.scale/scale);
			GfxPrinter.SetClipRegion(ctxt, LeoFrames.RegionFromMask(mask));
			Gfx.Reset(ctxt);
			RenderPreview(ctxt, pen, w, h);
			IF scale # 1 THEN
				s := "x 1/"; Strings.IntToStr(scale, t); Strings.Append(s, t);
				Printer3.CenterString(mask, Display3.black, msg.x + pix, msg.y - pix, pw, ph, PFont, s, Display.paint);
				Printer3.CenterString(mask, Display3.white, msg.x, msg.y, pw, ph, PFont, s, Display.paint)
			END
		END;
		IF Gadgets.selected IN prev.state THEN
			Printer3.FillPattern(mask, Display3.white, Display3.selectpat, msg.x, msg.y, msg.x, msg.y, pw, ph, Display.paint)
		END
	END PrintPreview;

	PROCEDURE CopyPreview* (VAR msg: Objects.CopyMsg; from, to: Preview);
	BEGIN
		Gadgets.CopyFrame(msg, from, to);
		to.const := from.const
	END CopyPreview;

	PROCEDURE HandlePreview* (obj: Objects.Object; VAR msg: Objects.ObjMsg);
		VAR prev, copy: Preview; px, py: SIGNED16; mask: Display3.Mask; ver: SIGNED32;
	BEGIN
		prev := obj(Preview);
		IF msg IS Display.FrameMsg THEN
			WITH msg: Display.FrameMsg DO
				IF (msg.F = NIL) OR (msg.F = prev) THEN
					IF msg IS Oberon.InputMsg THEN
						WITH msg: Oberon.InputMsg DO
							IF (msg.id = Oberon.track) & (msg.keys = {1}) & Gadgets.InActiveArea(prev, msg) THEN
								TrackPreview(prev, msg)
							ELSE
								Gadgets.framehandle(prev, msg)
							END
						END
					ELSIF msg IS Display.DisplayMsg THEN
						WITH msg: Display.DisplayMsg DO
							IF msg.device = Display.screen THEN
								px := msg.x + prev.X; py := msg.y + prev.Y;
								IF msg.id = Display.full THEN
									Gadgets.MakeMask(prev, px, py, msg.dlink, mask);
									RestorePreview(prev, px, py, mask)
								ELSIF msg.id = Display.area THEN
									Gadgets.MakeMask(prev, px, py, msg.dlink, mask);
									Display3.AdjustMask(mask, px + msg.u, py + (prev.H-1) + msg.v, msg.w, msg.h);
									RestorePreview(prev, px, py, mask)
								END
							ELSIF msg.device = Display.printer THEN
								PrintPreview(prev, msg)
							END
						END
					ELSIF msg IS Gadgets.UpdateMsg THEN
						IF msg(Gadgets.UpdateMsg).obj = prev.obj THEN
							px := msg.x + prev.X; py := msg.y + prev.Y;
							Gadgets.MakeMask(prev, px, py, msg.dlink, mask);
							RestorePreview(prev, px, py, mask)
						END
					ELSIF msg IS LeoPens.UpdateMsg THEN
						prev.obj.handle(prev.obj, msg)
					ELSIF msg IS DropMsg THEN
						WITH msg: DropMsg DO
							IF ~prev.const THEN
								Links.SetLink(prev.obj, "Pen", msg.pen);
								Gadgets.Update(prev.obj)
							END
						END
					ELSE
						Gadgets.framehandle(prev, msg)
					END
				END
			END
		ELSIF msg IS Objects.AttrMsg THEN
			WITH msg: Objects.AttrMsg DO
				IF msg.id = Objects.enum THEN
					msg.Enum("Constant"); Gadgets.framehandle(prev, msg)
				ELSIF msg.id = Objects.get THEN
					IF msg.name = "Gen" THEN msg.class := Objects.String; msg.s := "LeoPenEditors.NewPreview"; msg.res := 0
					ELSIF msg.name = "Constant" THEN msg.class := Objects.Bool; msg.b := prev.const; msg.res := 0
					ELSE Gadgets.framehandle(prev, msg)
					END
				ELSIF msg.id = Objects.set THEN
					IF msg.name = "Constant" THEN
						IF msg.class = Objects.Bool THEN prev.const := msg.b; msg.res := 0 END
					ELSE
						Gadgets.framehandle(prev, msg)
					END
				ELSE
					Gadgets.framehandle(prev, msg)
				END
			END
		ELSIF msg IS Objects.CopyMsg THEN
			WITH msg: Objects.CopyMsg DO
				IF msg.stamp # prev.stamp THEN
					NEW(copy); prev.dlink := copy; prev.stamp := msg.stamp;
					CopyPreview(msg, prev, copy)
				END;
				msg.obj := prev.dlink
			END
		ELSIF msg IS Objects.FileMsg THEN
			WITH msg: Objects.FileMsg DO
				Gadgets.framehandle(prev, msg);
				IF msg.id = Objects.store THEN
					Files.WriteNum(msg.R, 1)
				ELSIF msg.id = Objects.load THEN
					Files.ReadNum(msg.R, ver)
				END
			END
		ELSE
			Gadgets.framehandle(prev, msg)
		END
	END HandlePreview;

	PROCEDURE InitPreview* (prev: Preview; model: Objects.Object);
	BEGIN
		prev.handle := HandlePreview; prev.W := 60; prev.H := 60; prev.const := FALSE;
		prev.obj := model
	END InitPreview;

	PROCEDURE NewPreview*;
		VAR prev: Preview;
	BEGIN
		NEW(prev); InitPreview(prev, NIL);
		Objects.NewObj := prev
	END NewPreview;


	(**--- Stroker ---**)

	PROCEDURE RevertStroker (editor: LeoPanels.Editor);
		VAR obj: Objects.Object; pen: LeoPens.Stroker; col: Display.Color;
	BEGIN
		Links.GetLink(editor, "Model", obj);
		IF (obj # NIL) & (obj IS LeoPens.Stroker) THEN
			pen := obj(LeoPens.Stroker);
			Attributes.SetReal(editor, "Width", pen.width); Attributes.SetReal(editor, "Limit", pen.limit);
			Attributes.SetInt(editor, "Cap", pen.capstyle); Attributes.SetInt(editor, "Join", pen.joinstyle);
			col := Display.RGB(pen.col.r, pen.col.g, pen.col.b);
			IF col = MIN(SIGNED32) THEN
				col := Colors.Match(Colors.DisplayIndex, Colors.DisplayBits, pen.col.r, pen.col.g, pen.col.b)
			END;
			Attributes.SetInt(editor, "Color", col);
			Links.SetLink(editor, "Image", pen.img);
			Attributes.SetReal(editor, "PinX", pen.px); Attributes.SetReal(editor, "PinY", pen.py);
			Gadgets.Update(editor)
		END
	END RevertStroker;

	PROCEDURE ApplyStroker (editor: LeoPanels.Editor);
		VAR obj: Objects.Object; pen: LeoPens.Stroker; x: FLOAT32; i: SIGNED32;
	BEGIN
		Links.GetLink(editor, "Model", obj);
		IF (obj # NIL) & (obj IS LeoPens.Stroker) THEN
			pen := obj(LeoPens.Stroker);
			IF editor.fig # NIL THEN
				Leonardo.BeginCommand(editor.fig)
			END;
			Attributes.GetReal(editor, "Width", x); SetReal(editor.fig, pen, "Width", x);
			Attributes.GetReal(editor, "Limit", x); SetReal(editor.fig, pen, "Limit", x);
			Attributes.GetInt(editor, "Cap", i); SetInt(editor.fig, pen, "CapStyle", i);
			Attributes.GetInt(editor, "Join", i); SetInt(editor.fig, pen, "JoinStyle", i);
			Attributes.GetInt(editor, "Color", i); SetColor(editor.fig, pen, i);
			Links.GetLink(editor, "Image", obj); SetLink(editor.fig, pen, "Image", obj);
			Attributes.GetReal(editor, "PinX", x); SetReal(editor.fig, pen, "PinX", x);
			Attributes.GetReal(editor, "PinY", x); SetReal(editor.fig, pen, "PinY", x);
			LeoPens.Update(pen);
			IF editor.fig # NIL THEN
				Leonardo.EndCommand(editor.fig)
			END
		END
	END ApplyStroker;

	PROCEDURE NewStroker*;
		VAR obj: Objects.Object; editor: LeoPanels.Editor;
	BEGIN
		Objects.NewObj := LeoPanels.CopyObj("StrokerPanel", TRUE);
		Links.GetLink(Objects.NewObj, "Model", obj);
		IF (obj # NIL) & (obj IS LeoPanels.Editor) THEN
			editor := obj(LeoPanels.Editor); editor.handle := HandleEditor;
			editor.revert := RevertStroker; editor.apply := ApplyStroker
		END
	END NewStroker;


	(**--- Filler ---**)

	PROCEDURE RevertFiller (editor: LeoPanels.Editor);
		VAR obj: Objects.Object; pen: LeoPens.Filler; col: Display.Color;
	BEGIN
		Links.GetLink(editor, "Model", obj);
		IF (obj # NIL) & (obj IS LeoPens.Filler) THEN
			pen := obj(LeoPens.Filler);
			col := Display.RGB(pen.col.r, pen.col.g, pen.col.b);
			IF col = MIN(SIGNED32) THEN
				col := Colors.Match(Colors.DisplayIndex, Colors.DisplayBits, pen.col.r, pen.col.g, pen.col.b)
			END;
			Attributes.SetInt(editor, "Color", col);
			Links.SetLink(editor, "Image", pen.img);
			Attributes.SetReal(editor, "PinX", pen.px); Attributes.SetReal(editor, "PinY", pen.py);
			Gadgets.Update(editor)
		END
	END RevertFiller;

	PROCEDURE ApplyFiller (editor: LeoPanels.Editor);
		VAR obj: Objects.Object; pen: LeoPens.Filler; i: SIGNED32; x: FLOAT32;
	BEGIN
		Links.GetLink(editor, "Model", obj);
		IF (obj # NIL) & (obj IS LeoPens.Filler) THEN
			pen := obj(LeoPens.Filler);
			IF editor.fig # NIL THEN
				Leonardo.BeginCommand(editor.fig)
			END;
			Attributes.GetInt(editor, "Color", i); SetColor(editor.fig, pen, i);
			Links.GetLink(editor, "Image", obj); SetLink(editor.fig, pen, "Image", obj);
			Attributes.GetReal(editor, "PinX", x); SetReal(editor.fig, pen, "PinX", x);
			Attributes.GetReal(editor, "PinY", x); SetReal(editor.fig, pen, "PinY", x);
			LeoPens.Update(pen);
			IF editor.fig # NIL THEN
				Leonardo.EndCommand(editor.fig)
			END
		END
	END ApplyFiller;

	PROCEDURE NewFiller*;
		VAR obj: Objects.Object; editor: LeoPanels.Editor;
	BEGIN
		Objects.NewObj := LeoPanels.CopyObj("FillerPanel", TRUE);
		Links.GetLink(Objects.NewObj, "Model", obj);
		IF (obj # NIL) & (obj IS LeoPanels.Editor) THEN
			editor := obj(LeoPanels.Editor); editor.handle := HandleEditor;
			editor.revert := RevertFiller; editor.apply := ApplyFiller
		END
	END NewFiller;


	(**--- Dasher ---**)

	PROCEDURE RevertDasher (editor: LeoPanels.Editor);
		VAR obj: Objects.Object; pen: LeoPens.Dasher; n: SIGNED32; name: ARRAY 5 OF CHAR;
	BEGIN
		Links.GetLink(editor, "Model", obj);
		IF (obj # NIL) & (obj IS LeoPens.Dasher) THEN
			pen := obj(LeoPens.Dasher);
			Links.SetLink(editor, "Base", pen.base);
			Attributes.SetInt(editor, "Length", pen.len);
			n := 0;
			WHILE n < pen.len DO
				name := "On?"; name[2] := CHR(ORD("0") + n);
				Attributes.SetReal(editor, name, pen.on[n]);
				name := "Off?"; name[3] := CHR(ORD("0") + n);
				Attributes.SetReal(editor, name, pen.off[n]);
				INC(n)
			END;
			WHILE n < Gfx.MaxDashPatSize DO
				name := "On?"; name[2] := CHR(ORD("0") + n);
				Attributes.SetString(editor, name, "");
				name := "Off?"; name[3] := CHR(ORD("0") + n);
				Attributes.SetString(editor, name, "");
				INC(n)
			END;
			Attributes.SetReal(editor, "Phase", pen.phase);
			Attributes.SetBool(editor, "Continuous", pen.continuous)
		END
	END RevertDasher;

	PROCEDURE ApplyDasher (editor: LeoPanels.Editor);
		VAR obj: Objects.Object; pen: LeoPens.Dasher; len, n: SIGNED32; name: ARRAY 5 OF CHAR; x: FLOAT32; b: BOOLEAN;
	BEGIN
		Links.GetLink(editor, "Model", obj);
		IF (obj # NIL) & (obj IS LeoPens.Dasher) THEN
			pen := obj(LeoPens.Dasher);
			IF editor.fig # NIL THEN
				Leonardo.BeginCommand(editor.fig)
			END;
			Links.GetLink(editor, "Base", obj); SetLink(editor.fig, pen, "Base", obj);
			Attributes.GetInt(editor, "Length", len); SetInt(editor.fig, pen, "Length", len);
			n := 0;
			WHILE n < len DO
				name := "On?"; name[2] := CHR(ORD("0") + n);
				Attributes.GetReal(editor, name, x); SetReal(editor.fig, pen, name, x);
				name := "Off?"; name[3] := CHR(ORD("0") + n);
				Attributes.GetReal(editor, name, x); SetReal(editor.fig, pen, name, x);
				INC(n)
			END;
			Attributes.GetReal(editor, "Phase", x); SetReal(editor.fig, pen, "Phase", x);
			Attributes.GetBool(editor, "Continuous", b); SetBool(editor.fig, pen, "Continuous", b);
			LeoPens.Update(pen);
			IF editor.fig # NIL THEN
				Leonardo.EndCommand(editor.fig)
			END
		END
	END ApplyDasher;

	PROCEDURE HandleDasher (obj: Objects.Object; VAR msg: Objects.ObjMsg);
		VAR len, n: SIGNED32; name: ARRAY 5 OF CHAR;
	BEGIN
		IF msg IS Objects.AttrMsg THEN
			WITH msg: Objects.AttrMsg DO
				IF msg.id = Objects.get THEN
					IF (msg.name[0] = "O") & (msg.name[1] = "n") & (msg.name[3] = 0X) THEN
						Attributes.GetInt(obj, "Length", len);
						n := ORD(msg.name[2]) - ORD("0");
						IF (0 <= n) & (n < len) THEN
							HandleEditor(obj, msg)
						END
					ELSIF (msg.name[0] = "O") & (msg.name[1] = "f") & (msg.name[2] = "f") & (msg.name[4] = 0X) THEN
						Attributes.GetInt(obj, "Length", len);
						n := ORD(msg.name[3]) - ORD("0");
						IF (0 <= n) & (n < len) THEN
							HandleEditor(obj, msg)
						END
					ELSE
						HandleEditor(obj, msg)
					END
				ELSIF msg.id = Objects.set THEN
					IF msg.name = "Length" THEN
						Attributes.GetInt(obj, "Length", n);
						HandleEditor(obj, msg);
						Attributes.GetInt(obj, "Length", len);
						WHILE n < len DO
							name := "On?"; name[2] := CHR(ORD("0") + n);
							Attributes.SetReal(obj, name, 5);
							name := "Off?"; name[3] := CHR(ORD("0") + n);
							Attributes.SetReal(obj, name, 5);
							INC(n)
						END
					ELSE
						HandleEditor(obj, msg)
					END
				ELSE
					HandleEditor(obj, msg)
				END
			END
		ELSE
			HandleEditor(obj, msg)
		END
	END HandleDasher;

	PROCEDURE NewDasher*;
		VAR obj: Objects.Object; editor: LeoPanels.Editor;
	BEGIN
		Objects.NewObj := LeoPanels.CopyObj("DasherPanel", TRUE);
		Links.GetLink(Objects.NewObj, "Model", obj);
		IF (obj # NIL) & (obj IS LeoPanels.Editor) THEN
			editor := obj(LeoPanels.Editor); editor.handle := HandleDasher;
			editor.revert := RevertDasher; editor.apply := ApplyDasher
		END
	END NewDasher;


	(**--- Forker ---**)

	PROCEDURE RevertForker (editor: LeoPanels.Editor);
		VAR obj: Objects.Object; pen: LeoPens.Forker;
	BEGIN
		Links.GetLink(editor, "Model", obj);
		IF (obj # NIL) & (obj IS LeoPens.Forker) THEN
			pen := obj(LeoPens.Forker);
			Links.SetLink(editor, "Upper", pen.upper);
			Links.SetLink(editor, "Lower", pen.lower);
			Gadgets.Update(editor)
		END
	END RevertForker;

	PROCEDURE ApplyForker (editor: LeoPanels.Editor);
		VAR obj: Objects.Object; pen: LeoPens.Forker;
	BEGIN
		Links.GetLink(editor, "Model", obj);
		IF (obj # NIL) & (obj IS LeoPens.Forker) THEN
			pen := obj(LeoPens.Forker);
			IF editor.fig # NIL THEN
				Leonardo.BeginCommand(editor.fig)
			END;
			Links.GetLink(editor, "Upper", obj); SetLink(editor.fig, pen, "Upper", obj);
			Links.GetLink(editor, "Lower", obj); SetLink(editor.fig, pen, "Lower", obj);
			LeoPens.Update(pen);
			IF editor.fig # NIL THEN
				Leonardo.EndCommand(editor.fig)
			END
		END
	END ApplyForker;

	PROCEDURE NewForker*;
		VAR obj: Objects.Object; editor: LeoPanels.Editor;
	BEGIN
		Objects.NewObj := LeoPanels.CopyObj("ForkerPanel", TRUE);
		Links.GetLink(Objects.NewObj, "Model", obj);
		IF (obj # NIL) & (obj IS LeoPanels.Editor) THEN
			editor := obj(LeoPanels.Editor); editor.handle := HandleEditor;
			editor.revert := RevertForker; editor.apply := ApplyForker
		END
	END NewForker;


	(**--- Outliner ---**)

	PROCEDURE RevertOutliner (editor: LeoPanels.Editor);
		VAR obj: Objects.Object; pen: LeoOutliners.Outliner;
	BEGIN
		Links.GetLink(editor, "Model", obj);
		IF (obj # NIL) & (obj IS LeoOutliners.Outliner) THEN
			pen := obj(LeoOutliners.Outliner);
			Attributes.SetReal(editor, "Width", pen.width); Attributes.SetReal(editor, "Limit", pen.limit);
			Attributes.SetInt(editor, "Cap", pen.capstyle); Attributes.SetInt(editor, "Join", pen.joinstyle);
			Links.SetLink(editor, "Base", pen.base);
			Attributes.SetInt(editor, "Mode", pen.mode);
			Gadgets.Update(editor)
		END
	END RevertOutliner;

	PROCEDURE ApplyOutliner (editor: LeoPanels.Editor);
		VAR obj: Objects.Object; pen: LeoOutliners.Outliner; x: FLOAT32; i: SIGNED32;
	BEGIN
		Links.GetLink(editor, "Model", obj);
		IF (obj # NIL) & (obj IS LeoOutliners.Outliner) THEN
			pen := obj(LeoOutliners.Outliner);
			IF editor.fig # NIL THEN
				Leonardo.BeginCommand(editor.fig)
			END;
			Attributes.GetReal(editor, "Width", x); SetReal(editor.fig, pen, "Width", x);
			Attributes.GetReal(editor, "Limit", x); SetReal(editor.fig, pen, "Limit", x);
			Attributes.GetInt(editor, "Cap", i); SetInt(editor.fig, pen, "CapStyle", i);
			Attributes.GetInt(editor, "Join", i); SetInt(editor.fig, pen, "JoinStyle", i);
			Links.GetLink(editor, "Base", obj); SetLink(editor.fig, pen, "Base", obj);
			Attributes.GetInt(editor, "Mode", i); SetInt(editor.fig, pen, "Mode", i);
			LeoPens.Update(pen);
			IF editor.fig # NIL THEN
				Leonardo.EndCommand(editor.fig)
			END
		END
	END ApplyOutliner;

	PROCEDURE NewOutliner*;
		VAR obj: Objects.Object; editor: LeoPanels.Editor;
	BEGIN
		Objects.NewObj := LeoPanels.CopyObj("OutlinerPanel", TRUE);
		Links.GetLink(Objects.NewObj, "Model", obj);
		IF (obj # NIL) & (obj IS LeoPanels.Editor) THEN
			editor := obj(LeoPanels.Editor); editor.handle := HandleEditor;
			editor.revert := RevertOutliner; editor.apply := ApplyOutliner
		END
	END NewOutliner;


	(**--- Arrow ---**)

	PROCEDURE RevertArrow (editor: LeoPanels.Editor);
		VAR obj: Objects.Object; pen: LeoOutliners.Arrow;
	BEGIN
		Links.GetLink(editor, "Model", obj);
		IF (obj # NIL) & (obj IS LeoOutliners.Arrow) THEN
			pen := obj(LeoOutliners.Arrow);
			Attributes.SetReal(editor, "Width", pen.width); Attributes.SetReal(editor, "Limit", pen.limit);
			Attributes.SetInt(editor, "Cap", pen.capstyle); Attributes.SetInt(editor, "Join", pen.joinstyle);
			Links.SetLink(editor, "Base", pen.base);
			Attributes.SetInt(editor, "Mode", pen.mode);
			Attributes.SetInt(editor, "Direction", pen.dir);
			Attributes.SetReal(editor, "Length", pen.len);
			Attributes.SetReal(editor, "CornerOffset", pen.coff);
			Attributes.SetReal(editor, "CornerDist", pen.cdist);
			Gadgets.Update(editor)
		END
	END RevertArrow;

	PROCEDURE ApplyArrow (editor: LeoPanels.Editor);
		VAR obj: Objects.Object; pen: LeoOutliners.Arrow; i: SIGNED32; x: FLOAT32;
	BEGIN
		Links.GetLink(editor, "Model", obj);
		IF (obj # NIL) & (obj IS LeoOutliners.Arrow) THEN
			pen := obj(LeoOutliners.Arrow);
			IF editor.fig # NIL THEN
				Leonardo.BeginCommand(editor.fig)
			END;
			Attributes.GetReal(editor, "Width", x); SetReal(editor.fig, pen, "Width", x);
			Attributes.GetReal(editor, "Limit", x); SetReal(editor.fig, pen, "Limit", x);
			Attributes.GetInt(editor, "Cap", i); SetInt(editor.fig, pen, "CapStyle", i);
			Attributes.GetInt(editor, "Join", i); SetInt(editor.fig, pen, "JoinStyle", i);
			Links.GetLink(editor, "Base", obj); SetLink(editor.fig, pen, "Base", obj);
			Attributes.GetInt(editor, "Mode", i); SetInt(editor.fig, pen, "Mode", i);
			Attributes.GetInt(editor, "Direction", i); SetInt(editor.fig, pen, "Direction", i);
			Attributes.GetReal(editor, "Length", x); SetReal(editor.fig, pen, "Length", x);
			Attributes.GetReal(editor, "CornerOffset", x); SetReal(editor.fig, pen, "CornerOffset", x);
			Attributes.GetReal(editor, "CornerDist", x); SetReal(editor.fig, pen, "CornerDist", x);
			LeoPens.Update(pen);
			IF editor.fig # NIL THEN
				Leonardo.EndCommand(editor.fig)
			END
		END
	END ApplyArrow;

	PROCEDURE NewArrow*;
		VAR obj: Objects.Object; editor: LeoPanels.Editor;
	BEGIN
		Objects.NewObj := LeoPanels.CopyObj("ArrowPanel", TRUE);
		Links.GetLink(Objects.NewObj, "Model", obj);
		IF (obj # NIL) & (obj IS LeoPanels.Editor) THEN
			editor := obj(LeoPanels.Editor); editor.handle := HandleEditor;
			editor.revert := RevertArrow; editor.apply := ApplyArrow
		END
	END NewArrow;


BEGIN
	NEW(DC); GfxDisplay.Init(DC, 0, 0, Display.Width, Display.Height);
	PFont := Fonts.This("Oberon10.Scn.Fnt");
	InitPenLib
END LeoPenEditors.
