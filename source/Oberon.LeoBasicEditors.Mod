(* ETH Oberon, Copyright 2001 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

MODULE LeoBasicEditors IN Oberon; (** portable **)	(* eos  *)

	(**
		Tools and editor commands for basic Leonardo shapes
	**)

	IMPORT
		Objects, Input, Oberon, Attributes, Links, Display3, Effects, Gadgets, Gfx, Leonardo, LeoPens,
		LeoFrames, LeoTools, LeoPanels, LeoPenEditors, LeoBasic;


	(**--- Links ---**)

	PROCEDURE RevertLink (editor: LeoPanels.Editor);
		VAR obj: Objects.Object; l: LeoBasic.Link;
	BEGIN
		Links.GetLink(editor, "Model", obj);
		IF (obj # NIL) & (obj IS LeoBasic.Link) THEN
			l := obj(LeoBasic.Link);
			Attributes.SetReal(editor, "X", l.x); Attributes.SetReal(editor, "Y", l.y);
			Gadgets.Update(editor)
		END
	END RevertLink;

	PROCEDURE ApplyLink (editor: LeoPanels.Editor);
		VAR obj: Objects.Object; l: LeoBasic.Link; x, y: FLOAT32;
	BEGIN
		Links.GetLink(editor, "Model", obj);
		IF (obj # NIL) & (obj IS LeoBasic.Link) & (editor.fig # NIL) THEN
			l := obj(LeoBasic.Link);
			Leonardo.BeginCommand(editor.fig);
			Attributes.GetReal(editor, "X", x); Attributes.GetReal(editor, "Y", y);
			Leonardo.SetReal(editor.fig, l, "X", x);
			Leonardo.SetReal(editor.fig, l, "Y", y);
			Leonardo.EndCommand(editor.fig)
		END
	END ApplyLink;

	PROCEDURE NewLink*;
		VAR obj: Objects.Object; editor: LeoPanels.Editor;
	BEGIN
		Objects.NewObj := LeoPanels.CopyObj("LinkPanel", TRUE);
		Links.GetLink(Objects.NewObj, "Model", obj);
		IF (obj # NIL) & (obj IS LeoPanels.Editor) THEN
			editor := obj(LeoPanels.Editor); editor.revert := RevertLink; editor.apply := ApplyLink
		END
	END NewLink;

	PROCEDURE Unlink*;
		VAR e: LeoPanels.Editor; fig: Leonardo.Figure; obj: Objects.Object;
	BEGIN
		e := LeoPanels.FindEditor(Gadgets.context); fig := LeoPanels.FindFigure(Gadgets.context);
		Links.GetLink(e, "Model", obj);
		IF (obj # NIL) & (obj IS LeoBasic.Link) & (fig # NIL) THEN
			obj.slink := NIL; Leonardo.Delete(fig, obj(LeoBasic.Link))
		END
	END Unlink;


	(**--- Rectangle Tool ---**)

	PROCEDURE RevertRectTool (e: LeoPanels.Editor);
	BEGIN
		Links.SetLink(e, "Pen", LeoPenEditors.Find("Rectangle", TRUE));
		Gadgets.Update(e)
	END RevertRectTool;

	PROCEDURE ApplyRectTool (e: LeoPanels.Editor);
		VAR obj: Objects.Object;
	BEGIN
		Links.GetLink(e, "Pen", obj);
		IF (obj # NIL) & (obj IS LeoPens.Pen) & (obj # LeoPenEditors.Find("Rectangle", TRUE)) THEN
			LeoPenEditors.Register(obj(LeoPens.Pen), "Rectangle")
		END;
	END ApplyRectTool;

	PROCEDURE TrackRect (frame: LeoFrames.Frame; VAR msg: Oberon.InputMsg);
		VAR
			tool: LeoTools.Tool; fx, fy, hx, hy, len, mx, my, l, x, y: SIGNED16; x0, y0, x1, y1, px, py: FLOAT32; s: ARRAY 128 OF CHAR;
			mask: Display3.Mask; state, keysum, keys: SET; rect: LeoBasic.Rectangle; fig: Leonardo.Figure;
	BEGIN
		IF msg.keys = {} THEN
			LeoTools.TrackTool(LeoTools.Current(frame), "rectangle", Effects.Cross, msg)
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
			LeoTools.Reset(frame, fx, fy);
			Oberon.FadeCursor(Oberon.Mouse);
			keysum := msg.keys; mx := -1; my := -1; x1 := x0; y1 := y0;
			REPEAT
				Gfx.DrawRect(LeoTools.DC, x0, y0, x1, y1, {Gfx.Stroke});
				Input.KeyState(state);
				LeoTools.PointToFrame(frame, x1, y1, hx, hy);
				LeoTools.ShowHints(tool, fx, fy, mask, hx, hy, Input.CTRL IN state);
				l := len;
				LeoTools.AppendPoint(tool, x1, y1, s, l);
				LeoTools.Append("  width=", s, l); LeoTools.AppendReal(ABS(x1 - x0)/tool.unit, s, l);
				LeoTools.Append("  height=", s, l); LeoTools.AppendReal(ABS(y1 - y0)/tool.unit, s, l);
				LeoTools.ShowStatus(frame, fx, fy, mask, s);
				px := x1; py := y1;
				REPEAT
					Input.Mouse(keys, x, y); keysum := keysum + keys;
					IF (keys # {}) & ((x # mx) OR (y # my)) THEN
						Oberon.DrawCursor(Oberon.Mouse, Effects.Cross, x, y);
						LeoTools.FrameToPoint(frame, x - fx, y - fy, x1, y1);
						LeoTools.Align(tool, x0, y0, x1, y1);
						mx := x; my := y
					END
				UNTIL (keys = {}) OR (x1 # px) OR (y1 # py);
				Oberon.FadeCursor(Oberon.Mouse);
				Gfx.DrawRect(LeoTools.DC, x0, y0, px, py, {Gfx.Stroke})
			UNTIL keys = {};
			IF (keysum = {2}) & (x1 # x0) & (y1 # y0) THEN
				NEW(rect); LeoBasic.InitRect(rect, x0, y0, x1, y1, LeoPenEditors.Find("Rectangle", TRUE));
				fig := frame.obj(Leonardo.Figure);
				Leonardo.Integrate(fig, rect)
			END;
			Oberon.DrawCursor(Oberon.Mouse, Effects.Cross, mx, my);
			msg.res := 0
		ELSE
			LeoTools.Track(LeoTools.Current(frame), msg)
		END
	END TrackRect;

	PROCEDURE RectTool (obj: Objects.Object; VAR msg: Objects.ObjMsg);
		VAR frame: LeoFrames.Frame; e: LeoPanels.Editor;
	BEGIN
		IF msg IS Oberon.InputMsg THEN
			WITH msg: Oberon.InputMsg DO
				frame := obj(LeoFrames.Frame);
				IF (msg.id = Oberon.track) & ~(Gadgets.selected IN frame.state) &
					LeoTools.InContents(msg.X, msg.Y, msg.x + frame.X, msg.y + frame.Y, frame.W, frame.H)
				THEN
					TrackRect(frame, msg)
				ELSE
					LeoTools.HandleFrame(obj, msg)
				END
			END
		ELSIF msg IS Objects.LinkMsg THEN
			WITH msg: Objects.LinkMsg DO
				IF (msg.id = Objects.get) & (msg.name = "Editor") & (msg.res < 0) THEN
					msg.obj := LeoPanels.CopyObj("RectToolPanel", TRUE);
					Links.GetLink(msg.obj, "Model", obj);
					IF (obj # NIL) & (obj IS LeoPanels.Editor) THEN
						e := obj(LeoPanels.Editor); e.handle := LeoPenEditors.HandleShapeEditor;
						e.revert := RevertRectTool; e.apply := ApplyRectTool; RevertRectTool(e)
					END
				ELSE LeoTools.HandleFrame(obj, msg)
				END
			END
		ELSE
			LeoTools.HandleFrame(obj, msg)
		END
	END RectTool;

	(** activate rectangle tool **)
	PROCEDURE ActivateRect*;
	BEGIN
		LeoTools.Activate(RectTool)
	END ActivateRect;


	(**--- Rectangle Editor ---**)

	PROCEDURE RevertRect (editor: LeoPanels.Editor);
		VAR obj: Objects.Object; rect: LeoBasic.Rectangle; b: BOOLEAN;
	BEGIN
		Links.GetLink(editor, "Model", obj);
		IF (obj # NIL) & (obj IS LeoBasic.Rectangle) THEN
			rect := obj(LeoBasic.Rectangle);
			Links.SetLink(editor, "Pen", rect.pen);
			Links.GetLink(editor, "List", obj);
			IF obj # NIL THEN
				Links.SetLink(obj, "Model", Leonardo.ContainingFigure(rect));
				Links.SetLink(obj, "Container", rect);
				Gadgets.Update(obj)
			END;
			Links.GetLink(editor, "Bar", obj);
			IF obj # NIL THEN
				Attributes.GetBool(obj, "ArrowBoxes", b); Attributes.SetBool(obj, "ArrowBoxes", b)	(* force AdjustKnoblen *)
			END;
			Gadgets.Update(editor)
		END
	END RevertRect;

	PROCEDURE ApplyRect (editor: LeoPanels.Editor);
		VAR obj: Objects.Object; rect: LeoBasic.Rectangle;
	BEGIN
		Links.GetLink(editor, "Model", obj);
		IF (obj # NIL) & (obj IS LeoBasic.Rectangle) THEN
			rect := obj(LeoBasic.Rectangle);
			IF editor.fig # NIL THEN
				Leonardo.BeginCommand(editor.fig);
				Links.GetLink(editor, "Pen", obj);
				IF (obj # rect.pen) & (obj # NIL) & (obj IS LeoPens.Pen) THEN
					LeoPenEditors.SetPen(editor.fig, rect, "Pen", obj(LeoPens.Pen))
				END;
				Leonardo.EndCommand(editor.fig)
			END
		END
	END ApplyRect;

	PROCEDURE NewRect*;
		VAR obj: Objects.Object; editor: LeoPanels.Editor;
	BEGIN
		Objects.NewObj := LeoPanels.CopyObj("RectPanel", TRUE);
		Links.GetLink(Objects.NewObj, "Model", obj);
		IF (obj # NIL) & (obj IS LeoPanels.Editor) THEN
			editor := obj(LeoPanels.Editor); editor.handle := LeoPenEditors.HandleShapeEditor;
			editor.revert := RevertRect; editor.apply := ApplyRect;
			Links.SetLink(editor, "List", Gadgets.FindObj(Objects.NewObj, "List"));
			Links.SetLink(editor, "Bar", Gadgets.FindObj(Objects.NewObj, "Bar"))
		END
	END NewRect;


	(**--- Ellipse Tool ---**)

	PROCEDURE RevertEllipseTool (e: LeoPanels.Editor);
	BEGIN
		Links.SetLink(e, "Pen", LeoPenEditors.Find("Ellipse", TRUE));
		Gadgets.Update(e)
	END RevertEllipseTool;

	PROCEDURE ApplyEllipseTool (e: LeoPanels.Editor);
		VAR obj: Objects.Object;
	BEGIN
		Links.GetLink(e, "Pen", obj);
		IF (obj # NIL) & (obj IS LeoPens.Pen) & (obj # LeoPenEditors.Find("Ellipse", TRUE)) THEN
			LeoPenEditors.Register(obj(LeoPens.Pen), "Ellipse")
		END;
	END ApplyEllipseTool;

	PROCEDURE TrackEllipse (frame: LeoFrames.Frame; VAR msg: Oberon.InputMsg);
		VAR
			tool: LeoTools.Tool; fx, fy, hx, hy, len, mx, my, l, x, y: SIGNED16; x0, y0, x1, y1, px, py: FLOAT32; s: ARRAY 128 OF CHAR;
			mask: Display3.Mask; state, keysum, keys: SET; e: LeoBasic.Ellipse; fig: Leonardo.Figure;
	BEGIN
		IF msg.keys = {} THEN
			LeoTools.TrackTool(LeoTools.Current(frame), "ellipse", Effects.Cross, msg)
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
			LeoTools.Reset(frame, fx, fy);
			Oberon.FadeCursor(Oberon.Mouse);
			keysum := msg.keys; mx := -1; my := -1; x1 := x0; y1 := y0;
			REPEAT
				Gfx.DrawEllipse(LeoTools.DC, 0.5*(x0 + x1), 0.5*(y0 + y1), 0.5*(x1 - x0), 0.5*(y1 - y0), {Gfx.Stroke});
				Input.KeyState(state);
				LeoTools.PointToFrame(frame, x1, y1, hx, hy);
				LeoTools.ShowHints(tool, fx, fy, mask, hx, hy, Input.CTRL IN state);
				l := len;
				LeoTools.AppendPoint(tool, x1, y1, s, l);
				LeoTools.Append("  width=", s, l); LeoTools.AppendReal(ABS(x1 - x0)/tool.unit, s, l);
				LeoTools.Append("  height=", s, l); LeoTools.AppendReal(ABS(y1 - y0)/tool.unit, s, l);
				LeoTools.ShowStatus(frame, fx, fy, mask, s);
				px := x1; py := y1;
				REPEAT
					Input.Mouse(keys, x, y); keysum := keysum + keys;
					IF (keys # {}) & ((x # mx) OR (y # my)) THEN
						Oberon.DrawCursor(Oberon.Mouse, Effects.Cross, x, y);
						LeoTools.FrameToPoint(frame, x - fx, y - fy, x1, y1);
						LeoTools.Align(tool, x0, y0, x1, y1);
						mx := x; my := y
					END
				UNTIL (keys = {}) OR (x1 # px) OR (y1 # py);
				Oberon.FadeCursor(Oberon.Mouse);
				Gfx.DrawEllipse(LeoTools.DC, 0.5*(x0 + px), 0.5*(y0 + py), 0.5*(px - x0), 0.5*(py - y0), {Gfx.Stroke})
			UNTIL keys = {};
			IF (keysum = {2}) & (x1 # x0) & (y1 # y0) THEN
				NEW(e);
				LeoBasic.InitEllipse(e, 0.5*(x0 + x1), 0.5*(y0 + y1), 0.5*(x1 - x0), 0.5*(y1 - y0), LeoPenEditors.Find("Ellipse", TRUE));
				fig := frame.obj(Leonardo.Figure);
				Leonardo.Integrate(fig, e)
			END;
			Oberon.DrawCursor(Oberon.Mouse, Effects.Cross, mx, my);
			msg.res := 0
		ELSE
			LeoTools.Track(LeoTools.Current(frame), msg)
		END
	END TrackEllipse;

	PROCEDURE EllipseTool (obj: Objects.Object; VAR msg: Objects.ObjMsg);
		VAR frame: LeoFrames.Frame; e: LeoPanels.Editor;
	BEGIN
		IF msg IS Oberon.InputMsg THEN
			WITH msg: Oberon.InputMsg DO
				frame := obj(LeoFrames.Frame);
				IF (msg.id = Oberon.track) & ~(Gadgets.selected IN frame.state) &
					LeoTools.InContents(msg.X, msg.Y, msg.x + frame.X, msg.y + frame.Y, frame.W, frame.H)
				THEN
					TrackEllipse(frame, msg)
				ELSE
					LeoTools.HandleFrame(obj, msg)
				END
			END
		ELSIF msg IS Objects.LinkMsg THEN
			WITH msg: Objects.LinkMsg DO
				IF (msg.id = Objects.get) & (msg.name = "Editor") & (msg.res < 0) THEN
					msg.obj := LeoPanels.CopyObj("EllipseToolPanel", TRUE);
					Links.GetLink(msg.obj, "Model", obj);
					IF (obj # NIL) & (obj IS LeoPanels.Editor) THEN
						e := obj(LeoPanels.Editor); e.handle := LeoPenEditors.HandleShapeEditor;
						e.revert := RevertEllipseTool; e.apply := ApplyEllipseTool; RevertEllipseTool(e)
					END
				ELSE LeoTools.HandleFrame(obj, msg)
				END
			END
		ELSE
			LeoTools.HandleFrame(obj, msg)
		END
	END EllipseTool;

	(** activate ellipse tool **)
	PROCEDURE ActivateEllipse*;
	BEGIN
		LeoTools.Activate(EllipseTool)
	END ActivateEllipse;


	(**--- Ellipse Editor ---**)

	PROCEDURE RevertEllipse (editor: LeoPanels.Editor);
		VAR obj: Objects.Object; e: LeoBasic.Ellipse; b: BOOLEAN;
	BEGIN
		Links.GetLink(editor, "Model", obj);
		IF (obj # NIL) & (obj IS LeoBasic.Ellipse) THEN
			e := obj(LeoBasic.Ellipse);
			Links.SetLink(editor, "Pen", e.pen);
			Links.GetLink(editor, "List", obj);
			IF obj # NIL THEN
				Links.SetLink(obj, "Model", Leonardo.ContainingFigure(e));
				Links.SetLink(obj, "Container", e);
				Gadgets.Update(obj)
			END;
			Links.GetLink(editor, "Bar", obj);
			IF obj # NIL THEN
				Attributes.GetBool(obj, "ArrowBoxes", b); Attributes.SetBool(obj, "ArrowBoxes", b)	(* force AdjustKnoblen *)
			END;
			Gadgets.Update(editor)
		END
	END RevertEllipse;

	PROCEDURE ApplyEllipse (editor: LeoPanels.Editor);
		VAR obj: Objects.Object; e: LeoBasic.Ellipse;
	BEGIN
		Links.GetLink(editor, "Model", obj);
		IF (obj # NIL) & (obj IS LeoBasic.Ellipse) THEN
			e := obj(LeoBasic.Ellipse);
			IF editor.fig # NIL THEN
				Leonardo.BeginCommand(editor.fig);
				Links.GetLink(editor, "Pen", obj);
				IF (obj # e.pen) & (obj # NIL) & (obj IS LeoPens.Pen) THEN
					LeoPenEditors.SetPen(editor.fig, e, "Pen", obj(LeoPens.Pen))
				END;
				Leonardo.EndCommand(editor.fig)
			END
		END
	END ApplyEllipse;

	PROCEDURE NewEllipse*;
		VAR obj: Objects.Object; editor: LeoPanels.Editor;
	BEGIN
		Objects.NewObj := LeoPanels.CopyObj("EllipsePanel", TRUE);
		Links.GetLink(Objects.NewObj, "Model", obj);
		IF (obj # NIL) & (obj IS LeoPanels.Editor) THEN
			editor := obj(LeoPanels.Editor); editor.handle := LeoPenEditors.HandleShapeEditor;
			editor.revert := RevertEllipse; editor.apply := ApplyEllipse;
			Links.SetLink(editor, "List", Gadgets.FindObj(Objects.NewObj, "List"));
			Links.SetLink(editor, "Bar", Gadgets.FindObj(Objects.NewObj, "Bar"))
		END
	END NewEllipse;


	(**--- Groups ---**)

	PROCEDURE RevertGroup (editor: LeoPanels.Editor);
		VAR obj: Objects.Object; group: LeoBasic.Group; b: BOOLEAN;
	BEGIN
		Links.GetLink(editor, "Model", obj);
		IF (obj # NIL) & (obj IS LeoBasic.Group) THEN
			group := obj(LeoBasic.Group);
			Links.GetLink(editor, "List", obj);
			IF obj # NIL THEN
				Links.SetLink(obj, "Model", Leonardo.ContainingFigure(group));
				Links.SetLink(obj, "Container", group);
				Gadgets.Update(obj)
			END;
			Links.GetLink(editor, "Bar", obj);
			IF obj # NIL THEN
				Attributes.GetBool(obj, "ArrowBoxes", b); Attributes.SetBool(obj, "ArrowBoxes", b)	(* force AdjustKnoblen *)
			END;
			Gadgets.Update(editor)
		END
	END RevertGroup;

	PROCEDURE NewGroup*;
		VAR obj: Objects.Object; editor: LeoPanels.Editor;
	BEGIN
		Objects.NewObj := LeoPanels.CopyObj("GroupPanel", TRUE);
		Links.GetLink(Objects.NewObj, "Model", obj);
		IF (obj # NIL) & (obj IS LeoPanels.Editor) THEN
			editor := obj(LeoPanels.Editor); editor.revert := RevertGroup;
			Links.SetLink(editor, "List", Gadgets.FindObj(Objects.NewObj, "List"));
			Links.SetLink(editor, "Bar", Gadgets.FindObj(Objects.NewObj, "Bar"))
		END
	END NewGroup;

	PROCEDURE Group*;
		VAR fig: Leonardo.Figure; sel, bot, s: Leonardo.Shape; group: LeoBasic.Group;
	BEGIN
		fig := LeoPanels.FindFigure(Gadgets.context);
		IF fig # NIL THEN
			sel := Leonardo.Selection(fig);
			IF (sel # NIL) & (sel.slink # NIL) THEN
				NEW(group); LeoBasic.InitGroup(group, NIL, NIL);
				Leonardo.DisableUpdate(fig);
				Leonardo.BeginCommand(fig);
				Leonardo.Delete(fig, sel);
				Leonardo.Integrate(fig, group);
				bot := NIL;
				LOOP
					s := sel; WHILE (s.slink # NIL) & (s.slink = s.down) DO s := s.down END;
					Leonardo.BeginCommand(fig);
					Leonardo.AddConsumeAction(fig, NIL, s, sel, bot, group); bot := s;
					Leonardo.EndCommand(fig);
					IF s.slink = NIL THEN EXIT END;
					sel := s.slink(Leonardo.Shape)
				END;
				Leonardo.EndCommand(fig);
				Leonardo.EnableUpdate(fig)
			END
		END
	END Group;

	PROCEDURE Ungroup*;
		VAR obj: Objects.Object; group: LeoBasic.Group; fig: Leonardo.Figure;
	BEGIN
		Links.GetLink(LeoPanels.FindEditor(Gadgets.context), "Model", obj);
		IF (obj # NIL) & (obj IS LeoBasic.Group) THEN
			group := obj(LeoBasic.Group);
			fig := Leonardo.ContainingFigure(group);
			Leonardo.DisableUpdate(fig);
			Leonardo.BeginCommand(fig);
			Leonardo.AddDeleteAction(fig, group.down, group, group, group.up, group.cont(Leonardo.Container));
			Leonardo.AddConsumeAction(fig, group.down, group.bottom, group.top, group.up, group.cont(Leonardo.Container));
			Leonardo.EndCommand(fig);
			Leonardo.EnableUpdate(fig);
			LeoPanels.GetSelection
		END
	END Ungroup;


END LeoBasicEditors.
