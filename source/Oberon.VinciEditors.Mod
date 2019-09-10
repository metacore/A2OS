(* ETH Oberon, Copyright 2001 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

MODULE VinciEditors IN Oberon; (** portable *)	(* eos  *)

	(**
		Tool and Editor for Vinci shapes
	**)

	(*
		18.05.2000 - get inspector title from shape's "Item" attribute
		18.05.2000 - changed buttons beside pen preview
	*)

	IMPORT
		Objects, Input, Texts, Oberon, Strings, Attributes, Links, Display3, Effects, Gadgets, GfxMatrix,
		Leonardo, LeoPens, LeoFrames, LeoTools, LeoPanels, LeoPenEditors, VinciShapes;


	VAR
		Name: Objects.Object;
		Template: Texts.Text;


	(**--- Tool Editor ---**)

	PROCEDURE RevertTool (editor: LeoPanels.Editor);
		VAR s: ARRAY 64 OF CHAR;
	BEGIN
		Attributes.GetString(Name, "Value", s); Attributes.SetString(editor, "Name", s);
		Links.SetLink(editor, "Template", Template);
	END RevertTool;

	PROCEDURE ApplyTool (editor: LeoPanels.Editor);
		VAR s: ARRAY 64 OF CHAR; obj: Objects.Object;
	BEGIN
		Attributes.GetString(editor, "Name", s); Attributes.SetString(Name, "Value", s);
		Links.GetLink(editor, "Template", obj);
		IF (obj # NIL) & (obj IS Texts.Text) THEN Template := obj(Texts.Text) END
	END ApplyTool;

	PROCEDURE Load*;
		VAR s: Attributes.Scanner; text: Texts.Text; shape: VinciShapes.Shape; e: LeoPanels.Editor;
	BEGIN
		Attributes.OpenScanner(s, Oberon.Par.text, Oberon.Par.pos); Attributes.Scan(s);
		IF s.class = Texts.Name THEN
			NEW(text); Texts.Open(text, s.s);
			IF text.len # 0 THEN
				NEW(shape); VinciShapes.InitShape(shape, text);
				IF shape.valid THEN
					e := LeoPanels.FindEditor(Gadgets.context);
					IF e # NIL THEN
						Attributes.SetString(e, "Name", s.s);
						Links.SetLink(e, "Template", text);
						Gadgets.Update(e)
					END
				END
			END
		END
	END Load;


	(*--- Tool ---*)

	PROCEDURE Track (frame: LeoFrames.Frame; VAR msg: Oberon.InputMsg);
		VAR
			tool: LeoTools.Tool; fx, fy, hx, hy, len, mx, my, l, x, y: SIGNED16; x0, y0, x1, y1: FLOAT32; s: ARRAY 128 OF CHAR;
			mask: Display3.Mask; state, keysum, keys: SET; fig: Leonardo.Figure; shape: VinciShapes.Shape;
			m: GfxMatrix.Matrix;
	BEGIN
		IF msg.keys = {} THEN
			LeoTools.TrackTool(LeoTools.Current(frame), "insert description", Effects.Cross, msg)
		ELSIF msg.keys = {2} THEN
			tool := LeoTools.Current(frame);
			fx := msg.x + frame.X; fy := msg.y + frame.Y;
			LeoTools.FrameToPoint(frame, msg.X - fx, msg.Y - fy, x0, y0);
			LeoTools.Align(tool, x0, y0, x0, y0);
			Input.KeyState(state);
			Gadgets.MakeMask(frame, fx, fy, msg.dlink, mask);
			LeoTools.PointToFrame(frame, x0, y0, hx, hy);
			LeoTools.ShowHints(tool, fx, fy, mask, hx, hy, Input.CTRL IN state);
			len := 0; LeoTools.AppendPoint(tool, x0, y0, s, len);
			LeoTools.ShowStatus(frame, fx, fy, mask, s);
			LeoTools.Append(", ", s, len);
			keysum := msg.keys; mx := -1; my := -1; x1 := x0; y1 := y0;
			REPEAT
				Input.KeyState(state);
				LeoTools.PointToFrame(frame, x0, y0, hx, hy);
				LeoTools.ShowHints(tool, fx, fy, mask, hx, hy, Input.CTRL IN state);
				l := len;
				LeoTools.AppendPoint(tool, x0, y0, s, l);
				LeoTools.ShowStatus(frame, fx, fy, mask, s);
				x1 := x0; y1 := y0;
				REPEAT
					Input.Mouse(keys, x, y); keysum := keysum + keys;
					IF (keys # {}) & ((x # mx) OR (y # my)) THEN
						Oberon.DrawCursor(Oberon.Mouse, Effects.Cross, x, y);
						LeoTools.FrameToPoint(frame, x - fx, y - fy, x0, y0);
						LeoTools.Align(tool, x0, y0, x0, y0);
						mx := x; my := y
					END
				UNTIL (keys = {}) OR (x0 # x1) OR (y0 # y1);
			UNTIL keys = {};
			IF (keysum = {2}) & (Template # NIL) THEN
				NEW(shape); VinciShapes.InitShape(shape, Template(Texts.Text));
				IF shape.valid THEN
					fig := frame.obj(Leonardo.Figure);
					Leonardo.DisableUpdate(fig); Leonardo.BeginCommand(fig);
					Leonardo.Integrate(fig, shape);
					GfxMatrix.Init(m, 1, 0, 0, 1, x0, y0);
					Leonardo.Transform(fig, shape, m);
					Leonardo.EndCommand(fig);
					Leonardo.ClearSelection(fig); shape.slink := NIL; Leonardo.Select(fig, shape);
					Leonardo.EnableUpdate(fig)
				END
			END;
			Oberon.DrawCursor(Oberon.Mouse, Effects.Cross, mx, my);
			msg.res := 0
		ELSE
			LeoTools.Track(LeoTools.Current(frame), msg)
		END
	END Track;

	PROCEDURE HandleTool (obj: Objects.Object; VAR msg: Objects.ObjMsg);
		VAR frame: LeoFrames.Frame; e: LeoPanels.Editor;
	BEGIN
		IF msg IS Oberon.InputMsg THEN
			WITH msg: Oberon.InputMsg DO
				frame := obj(LeoFrames.Frame);
				IF (msg.id = Oberon.track) & ~(Gadgets.selected IN frame.state) &
					LeoTools.InContents(msg.X, msg.Y, msg.x + frame.X, msg.y + frame.Y, frame.W, frame.H)
				THEN
					Track(frame, msg)
				ELSE
					LeoTools.HandleFrame(frame, msg)
				END
			END
		ELSIF msg IS Objects.LinkMsg THEN
			WITH msg: Objects.LinkMsg DO
				IF (msg.id = Objects.get) & (msg.name = "Editor") & (msg.res < 0) THEN
					msg.obj := LeoPanels.CopyObj("VinciToolPanel", TRUE);
					Links.GetLink(msg.obj, "Model", obj);
					ASSERT(obj IS LeoPanels.Editor, 100);
					IF (obj # NIL) & (obj IS LeoPanels.Editor) THEN
						e := obj(LeoPanels.Editor); e.revert := RevertTool; e.apply := ApplyTool; RevertTool(e);
						msg.res := 0
					END
				ELSE
					LeoTools.HandleFrame(obj, msg)
				END
			END
		ELSE
			LeoTools.HandleFrame(obj, msg)
		END
	END HandleTool;

	PROCEDURE Activate*;
	BEGIN
		LeoTools.Activate(HandleTool);
	END Activate;


	(**--- Editor ---**)

	PROCEDURE Revert (e: LeoPanels.Editor);
		VAR
			obj, link: Objects.Object; vs: VinciShapes.Shape; par: VinciShapes.Parameter; b: BOOLEAN; i: SIGNED32;
			r: FLOAT32; s: ARRAY 64 OF CHAR;
	BEGIN
		Links.GetLink(e, "Model", obj);
		IF (obj # NIL) & (obj IS VinciShapes.Shape) THEN
			vs := obj(VinciShapes.Shape); par := vs.par;
			WHILE par # NIL DO
				CASE par.kind OF
				| VinciShapes.bool: Attributes.GetBool(vs, par.name, b); Attributes.SetBool(e, par.name, b)
				| VinciShapes.int, VinciShapes.color: Attributes.GetInt(vs, par.name, i); Attributes.SetInt(e, par.name, i)
				| VinciShapes.real: Attributes.GetReal(vs, par.name, r); Attributes.SetReal(e, par.name, r)
				| VinciShapes.string: Attributes.GetString(vs, par.name, s); Attributes.SetString(e, par.name, s)
				| VinciShapes.pen: Links.GetLink(vs, par.name, link); Links.SetLink(e, par.name, link)
				ELSE
				END;
				par := par.next
			END;
			Gadgets.Update(e)
		END
	END Revert;

	PROCEDURE Apply (e: LeoPanels.Editor);
		VAR
			obj, link: Objects.Object; vs: VinciShapes.Shape; par: VinciShapes.Parameter; b: BOOLEAN; i: SIGNED32;
			r: FLOAT32; s: ARRAY 64 OF CHAR;
	BEGIN
		Links.GetLink(e, "Model", obj);
		IF (obj # NIL) & (obj IS VinciShapes.Shape) THEN
			Leonardo.BeginCommand(e.fig);
			vs := obj(VinciShapes.Shape); par := vs.par;
			WHILE par # NIL DO
				CASE par.kind OF
				| VinciShapes.bool: Attributes.GetBool(e, par.name, b); Leonardo.SetBool(e.fig, vs, par.name, b)
				| VinciShapes.int, VinciShapes.color: Attributes.GetInt(e, par.name, i); Leonardo.SetInt(e.fig, vs, par.name, i)
				| VinciShapes.real: Attributes.GetReal(e, par.name, r); Leonardo.SetReal(e.fig, vs, par.name, r)
				| VinciShapes.string: Attributes.GetString(e, par.name, s); Leonardo.SetString(e.fig, vs, par.name, s)
				| VinciShapes.pen: Links.GetLink(e, par.name, link); LeoPenEditors.SetPen(e.fig, vs, par.name, link(LeoPens.Pen))
				ELSE
				END;
				par := par.next
			END;
			Leonardo.EndCommand(e.fig)
		END
	END Apply;

	PROCEDURE BuildPanel (e: LeoPanels.Editor);
		VAR
			obj: Objects.Object; vs: VinciShapes.Shape; list, f: Gadgets.Frame; y: SIGNED16;
			s, cmd: ARRAY 64 OF CHAR;par: VinciShapes.Parameter;
	BEGIN
		Links.GetLink(e, "Model", obj);
		IF (obj # NIL) & (obj IS VinciShapes.Shape) THEN
			vs := obj(VinciShapes.Shape); list := NIL; y := -8;
			Attributes.GetString(vs, "Item", s); Attributes.SetString(e, "Title", s);
			Links.SetLink(e, "Menu", LeoPanels.CopyObj("ShapeMenu", TRUE));
			par := vs.par;
			WHILE par # NIL DO
				IF par.kind IN {VinciShapes.bool..VinciShapes.color, VinciShapes.pen} THEN
					DEC(y, 22);
					obj := Gadgets.CreateObject("Caption");
					IF (obj # NIL) & (obj IS Gadgets.Frame) THEN
						f := obj(Gadgets.Frame);
						Attributes.SetString(f, "Value", par.name);
						Attributes.SetString(f, "Font", "Oberon10i.Scn.Fnt");
						f.X := 8; f.Y := y+4; f.W := 54; f.next := list; list := f
					END;
					f := NIL;
					CASE par.kind OF
					| VinciShapes.bool:
						obj := Gadgets.CreateObject("CheckBox");
						IF (obj # NIL) & (obj IS Gadgets.Frame) THEN
							f := obj(Gadgets.Frame); f.W := 18
						END
					| VinciShapes.int, VinciShapes.real, VinciShapes.string:
						obj := Gadgets.CreateObject("TextField");
						IF (obj # NIL) & (obj IS Gadgets.Frame) THEN
							f := obj(Gadgets.Frame); f.W := 72
						END
					| VinciShapes.color:
						obj := Gadgets.CreateObject("ColorGadgets.NewWell");
						IF (obj # NIL) & (obj IS Gadgets.Frame) THEN
							Attributes.SetString(obj, "Cmd", "LeoPanels.EditColor");
							f := obj(Gadgets.Frame); f.W := 18
						END
					| VinciShapes.pen:
						DEC(list.Y, 18); DEC(y, 36);
						obj := Gadgets.CreateObject("LeoPenEditors.NewPreview");
						IF (obj # NIL) & (obj IS Gadgets.Frame) THEN
							Links.SetLink(obj, "Model", e);
							f := obj(Gadgets.Frame); f.X := 62; f.Y := y; f.W := 54; f.H := 54; f.next := list; list := f
						END;
						obj := Gadgets.CreateObject("Button");
						IF (obj # NIL) & (obj IS Gadgets.Frame) THEN
							Attributes.SetString(obj, "Caption", "Edit..");
							cmd := "LeoPanels.EditCopy "; Strings.Append(cmd, par.name);
							Attributes.SetString(obj, "Cmd", cmd);
							f := obj(Gadgets.Frame); f.X := 134; f.Y := y+18; f.W := 54; f.H := 18; f.next := list; list := f
						END;
						obj := Gadgets.CreateObject("Button");
						IF (obj # NIL) & (obj IS Gadgets.Frame) THEN
							Attributes.SetString(obj, "Caption", "New..");
							cmd := "LeoPenEditors.EditNew "; Strings.Append(cmd, par.name);
							Attributes.SetString(obj, "Cmd", cmd);
							f := obj(Gadgets.Frame); f.X := 188; f.Y := y+18; f.W := 54; f.H := 18; f.next := list; list := f
						END;
						obj := Gadgets.CreateObject("Button");
						IF (obj # NIL) & (obj IS Gadgets.Frame) THEN
							Attributes.SetString(obj, "Caption", "Select..");
							cmd := "LeoPenEditors.Select "; Strings.Append(cmd, par.name);
							Attributes.SetString(obj, "Cmd", cmd);
							f := obj(Gadgets.Frame); f.X := 242; f.Y := y+18; f.W := 54; f.H := 18; f.next := list; list := f
						END;
						f := NIL
					END;
					IF f # NIL THEN
						Links.SetLink(f, "Model", e); Attributes.SetString(f, "Field", par.name);
						f.X := 62; f.Y := y; f.H := 18; f.next := list; list := f
					END
				END;
				par := par.next
			END;
			obj := Gadgets.CreateObject("Button");
			IF (obj # NIL) & (obj IS Gadgets.Frame) THEN
				DEC(y, 22);
				Attributes.SetString(obj, "Caption", "Transform..");
				Attributes.SetString(obj, "Cmd", "LeoPanels.EditTransform");
				f := obj(Gadgets.Frame); f.X := 62; f.Y := y; f.W := 72; f.H := 18; f.next := list; list := f
			END;
			Links.GetLink(e, "Panel", obj);
			IF (obj # NIL) & (obj IS Gadgets.Frame) THEN
				f := obj(Gadgets.Frame); f.W := 384; f.H := -(y-8); f.dsc := list;
				Attributes.SetBool(f, "Locked", TRUE)
			END
		END
	END BuildPanel;

	PROCEDURE Handle (obj: Objects.Object; VAR msg: Objects.ObjMsg);
	BEGIN
		LeoPanels.HandleEditor(obj, msg);
		IF msg IS Objects.LinkMsg THEN
			WITH msg: Objects.LinkMsg DO
				IF (msg.id = Objects.set) & (msg.name = "Model") THEN
					BuildPanel(obj(LeoPanels.Editor))
				END
			END
		END
	END Handle;

	PROCEDURE New*;
		VAR p: Objects.Object; e: LeoPanels.Editor;
	BEGIN
		p := Gadgets.CreateObject("Panel");
		IF (p # NIL) & (p IS Gadgets.Frame) THEN
			NEW(e); e.handle := Handle; e.revert := Revert; e.apply := Apply;
			Links.SetLink(e, "Menu", LeoPanels.FindObj("EditorMenu"));
			Links.SetLink(p, "Model", e); Links.SetLink(e, "Panel", p)
		END;
		Objects.NewObj := p
	END New;


BEGIN
	Name := Gadgets.CreateObject("String")
END VinciEditors.
