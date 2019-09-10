(* ETH Oberon, Copyright 2001 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

MODULE LeoImageEditors IN Oberon; (** portable **)	(* eos  *)

	(**
		Tool and editor for Leonardo images
	**)

	IMPORT
		Objects, Display, Input, Oberon, Attributes, Links, Display3, Effects, Gadgets, Images,
		Leonardo, LeoImages, LeoFrames, LeoTools, LeoPanels;


	VAR
		Name: Objects.Object;
		Template: Images.Image;


	(*--- Tool Editor ---*)

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
		IF (obj # NIL) & (obj IS Images.Image) THEN Template := obj(Images.Image) END
	END ApplyTool;

	PROCEDURE Load*;
		VAR s: Attributes.Scanner; img: Images.Image; done: BOOLEAN; e: LeoPanels.Editor;
	BEGIN
		Attributes.OpenScanner(s, Oberon.Par.text, Oberon.Par.pos); Attributes.Scan(s);
		IF s.class = Attributes.Name THEN
			NEW(img); Images.Load(img, s.s, done);
			IF done THEN
				e := LeoPanels.FindEditor(Gadgets.context);
				IF e # NIL THEN
					Attributes.SetString(e, "Name", s.s);
					Links.SetLink(e, "Template", img);
					Gadgets.Update(e)
				END
			END
		END
	END Load;


	(*--- Tool ---*)

	PROCEDURE Track (frame: LeoFrames.Frame; VAR msg: Oberon.InputMsg);
		VAR
			tool: LeoTools.Tool; fx, fy, hx, hy, len, mx, my, l, x, y: SIGNED16; x0, y0, x1, y1: FLOAT32; s: ARRAY 128 OF CHAR;
			mask: Display3.Mask; state, keysum, keys: SET; fig: Leonardo.Figure; img: LeoImages.Image;
	BEGIN
		IF msg.keys = {} THEN
			LeoTools.TrackTool(LeoTools.Current(frame), "insert image", Effects.Cross, msg)
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
				fig := frame.obj(Leonardo.Figure);
				NEW(img); LeoImages.Init(img, x0, y0, Template);
				Leonardo.Integrate(fig, img);
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
					msg.obj := LeoPanels.CopyObj("ImageToolPanel", TRUE);
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
		VAR obj: Objects.Object; img: LeoImages.Image;
	BEGIN
		Links.GetLink(e, "Model", obj);
		IF (obj # NIL) & (obj IS LeoImages.Image) THEN
			img := obj(LeoImages.Image);
			Attributes.SetInt(e, "Filter", img.filter); Attributes.SetBool(e, "Quick", img.quick);
			Attributes.SetInt(e, "Color", Display.RGB(img.color.r, img.color.g, img.color.b));
			Gadgets.Update(e)
		END
	END Revert;

	PROCEDURE Apply (e: LeoPanels.Editor);
		VAR obj: Objects.Object; img: LeoImages.Image; i: SIGNED32; b: BOOLEAN;
	BEGIN
		Links.GetLink(e, "Model", obj);
		IF (obj # NIL) & (obj IS LeoImages.Image) THEN
			img := obj(LeoImages.Image);
			Leonardo.BeginCommand(e.fig);
			Attributes.GetInt(e, "Filter", i); Leonardo.SetInt(e.fig, img, "Filter", i);
			Attributes.GetBool(e, "Quick", b); Leonardo.SetBool(e.fig, img, "Quick", b);
			Attributes.GetInt(e, "Color", i); Leonardo.SetColor(e.fig, img, i);
			Leonardo.EndCommand(e.fig)
		END
	END Apply;

	PROCEDURE New*;
		VAR obj: Objects.Object; e: LeoPanels.Editor;
	BEGIN
		Objects.NewObj := LeoPanels.CopyObj("ImagePanel", TRUE);
		Links.GetLink(Objects.NewObj, "Model", obj);
		IF (obj # NIL) & (obj IS LeoPanels.Editor) THEN
			e := obj(LeoPanels.Editor); e.revert := Revert; e.apply := Apply
		END
	END New;


BEGIN
	Name := Gadgets.CreateObject("String")
END LeoImageEditors.
