(* ETH Oberon, Copyright 2001 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

MODULE LeoCaptionEditors IN Oberon; (** portable **)	(* eos  *)

	(**
		Tool and editor for Leonardo captions
	**)

	IMPORT
		Objects, Display, Input, Fonts, Texts, Oberon, Attributes, Links, Display3, Effects, Gadgets,
		GfxMatrix, GfxFonts, Gfx, Leonardo, LeoCaptions, LeoFrames, LeoTools, LeoPanels;


	VAR
		Cursor: Oberon.Marker;
		CursorFG, CursorBG: Display.Pattern;
		Focus: RECORD
			frame: LeoFrames.Frame;	(* frame displaying caret *)
			fig: Leonardo.Figure;	(* figure containing focus shape *)
			shape: Leonardo.Shape;	(* focus shape *)
			px, py: FLOAT32;	(* figure coordinates of caret *)
			x, y: SIGNED16;	(* screen position of caret *)
			visible: BOOLEAN;
		END;


	VAR
		Font, Size, Color: Objects.Object;	(* public objects containing current attributes for new captions *)


	(**--- Tool Editor ---**)

	PROCEDURE InspectSel*;
		VAR fig: Leonardo.Figure; editor: LeoPanels.Editor; sel: Leonardo.Shape; cap: LeoCaptions.Caption;
	BEGIN
		fig := LeoPanels.FindFigure(Gadgets.context);
		editor := LeoPanels.FindEditor(Gadgets.context);
		IF (fig # NIL) & (editor # NIL) THEN
			sel := Leonardo.Selection(fig);
			IF (sel # NIL) & (sel IS LeoCaptions.Caption) THEN
				cap := sel(LeoCaptions.Caption);
				Attributes.SetString(editor, "Font", cap.font.name); Attributes.SetInt(editor, "Size", cap.font.ptsize);
				Attributes.SetInt(editor, "Color", Display.RGB(cap.color.r, cap.color.g, cap.color.b));
				Gadgets.Update(editor)
			END
		END
	END InspectSel;

	PROCEDURE ApplySel*;
		VAR
			fig: Leonardo.Figure; editor: LeoPanels.Editor; obj: Objects.Object; cap: LeoCaptions.Caption;
			font: ARRAY 64 OF CHAR; size, col: SIGNED32;
	BEGIN
		fig := LeoPanels.FindFigure(Gadgets.context);
		editor := LeoPanels.FindEditor(Gadgets.context);
		IF (fig # NIL) & (editor # NIL) THEN
			obj := Leonardo.Selection(fig);
			IF obj # NIL THEN
				Leonardo.BeginCommand(fig);
				REPEAT
					IF obj IS LeoCaptions.Caption THEN
						cap := obj(LeoCaptions.Caption);
						Attributes.GetString(editor, "Font", font); Leonardo.SetString(fig, cap, "Font", font);
						Attributes.GetInt(editor, "Size", size); Leonardo.SetInt(fig, cap, "Size", size);
						Attributes.GetInt(editor, "Color", col); Leonardo.SetColor(fig, cap, col)
					END;
					obj := obj.slink
				UNTIL obj = NIL;
				Leonardo.EndCommand(fig)
			END
		END
	END ApplySel;

	PROCEDURE RevertTool (editor: LeoPanels.Editor);
		VAR s: ARRAY 64 OF CHAR; i: SIGNED32;
	BEGIN
		Attributes.GetString(Font, "Value", s); Attributes.SetString(editor, "Font", s);
		Attributes.GetInt(Size, "Value", i); Attributes.SetInt(editor, "Size", i);
		Attributes.GetInt(Color, "Color", i); Attributes.SetInt(editor, "Color", i);
		Gadgets.Update(editor)
	END RevertTool;

	PROCEDURE ApplyTool (editor: LeoPanels.Editor);
		VAR s: ARRAY 64 OF CHAR; i: SIGNED32;
	BEGIN
		Attributes.GetString(editor, "Font", s); Attributes.SetString(Font, "Value", s);
		Attributes.GetInt(editor, "Size", i); Attributes.SetInt(Size, "Value", i);
		Attributes.GetInt(editor, "Color", i); Attributes.SetInt(Color, "Color", i)
	END ApplyTool;


	(**--- Tool ---**)

	PROCEDURE DrawCursor (x, y: SIGNED16);
	BEGIN
		DEC(x, 4); DEC(y, 6);
		Effects.OpenCursor(x, y, 9, 20);
		Display.CopyPattern(Display3.textbackC, CursorBG, x, y, Display.paint);
		Display.CopyPattern(Display3.black, CursorFG, x, y, Display.paint)
	END DrawCursor;

	PROCEDURE FadeCursor (x, y: SIGNED16);
	BEGIN
		Effects.CloseCursor
	END FadeCursor;

	PROCEDURE InitCursor;
		VAR p: ARRAY 20 OF SET; i: SIGNED32;
	BEGIN
		p[0] := {}; p[1] := {2..3, 5..6}; p[2] := {1, 4, 7};
		FOR i := 3 TO 16 DO p[i] := {4} END; p[6] := {2..6};
		p[17] := {1, 4, 7}; p[18] := {2..3, 5..6}; p[19] := {};
		CursorFG := Display.NewPattern(9, 20, p);
		p[0] := {2..3, 5..6}; p[1] := {1, 4, 7}; p[2] := {0, 2..3, 5..6, 8};
		FOR i := 3 TO 16 DO p[i] := {3, 5} END; p[6] := {1, 7};
		p[17] := {0, 2..3, 5..6, 8}; p[18] := {1, 4, 7}; p[19] := {2..3, 5..6};
		CursorBG := Display.NewPattern(9, 20, p);
		Cursor.Draw := DrawCursor; Cursor.Fade := FadeCursor
	END InitCursor;

	PROCEDURE FlipCaret (fx, fy: SIGNED16; mask: Display3.Mask);
		VAR mx, my, mw, mh, w, h: SIGNED16;
	BEGIN
		mx := mask.X; my := mask.Y; mw := mask.W; mh := mask.H;
		LeoTools.AdjustMask(mask, Focus.frame, fx, fy);
		Display.GetDim(Display.hook, w, h);
		Display3.CopyPattern(mask, Display3.invertC, Display.hook, Focus.x, Focus.y - (h+1), Display.invert);
		mask.X := mx; mask.Y := my; mask.W := mw; mask.H := mh;
		Focus.visible := ~Focus.visible
	END FlipCaret;

	PROCEDURE ShowCaret (fx, fy: SIGNED16; mask: Display3.Mask);
	BEGIN
		IF ~Focus.visible THEN FlipCaret(fx, fy, mask) END
	END ShowCaret;

	PROCEDURE HideCaret (fx, fy: SIGNED16; mask: Display3.Mask);
	BEGIN
		IF Focus.visible THEN FlipCaret(fx, fy, mask) END
	END HideCaret;

	PROCEDURE Show (frame: LeoFrames.Frame; VAR msg: Display.FrameMsg);
		VAR fx, fy: SIGNED16; mask: Display3.Mask;
	BEGIN
		IF ~Focus.visible THEN
			fx := msg.x + frame.X; fy := msg.y + frame.Y;
			Gadgets.MakeMask(frame, fx, fy, msg.dlink, mask);
			FlipCaret(fx, fy, mask)
		END
	END Show;

	PROCEDURE Hide (frame: LeoFrames.Frame; VAR msg: Display.FrameMsg);
		VAR fx, fy: SIGNED16; mask: Display3.Mask;
	BEGIN
		IF Focus.visible THEN
			fx := msg.x + frame.X; fy := msg.y + frame.Y;
			Gadgets.MakeMask(frame, fx, fy, msg.dlink, mask);
			FlipCaret(fx, fy, mask)
		END
	END Hide;

	PROCEDURE GetText (text: Texts.Text; beg, end: SIGNED32; VAR s: ARRAY OF CHAR);
		VAR r: Texts.Reader; i: SIGNED32; ch: CHAR;
	BEGIN
		Texts.OpenReader(r, text, beg);
		Texts.Read(r, ch); i := 0;
		WHILE (beg < end) & (i < LEN(s)-1) & (r.lib IS Fonts.Font) & (ch >= " ") DO
			s[i] := ch;
			Texts.Read(r, ch);
			INC(i); INC(beg)
		END;
		s[i] := 0X
	END GetText;

	PROCEDURE ConsumeText (fig: Leonardo.Figure; text: Texts.Text; beg, end: SIGNED32);
		VAR r: Texts.Reader; ch: CHAR; res: SIGNED16;
	BEGIN
		IF fig = Focus.fig THEN
			Leonardo.DisableUpdate(fig); Leonardo.BeginCommand(fig);
			Texts.OpenReader(r, text, beg);
			WHILE beg < end DO
				Texts.Read(r, ch);
				IF (r.lib IS Fonts.Font) & (ch >= " ") THEN
					LeoCaptions.Consume(fig, Focus.shape, ch, res)
				END;
				INC(beg)
			END;
			Leonardo.EndCommand(fig); Leonardo.EnableUpdate(fig)
		END
	END ConsumeText;

	PROCEDURE SetFocus (frame: LeoFrames.Frame; x, y: FLOAT32): BOOLEAN;
		VAR fig: Leonardo.Figure; dmat: GfxMatrix.Matrix; shape: Leonardo.Shape;
	BEGIN
		fig := frame.obj(Leonardo.Figure);
		GfxMatrix.Init(dmat, frame.scale, 0, 0, frame.scale, 0, 0);
		shape := LeoCaptions.Accept(fig, x, y, dmat);
		IF shape # NIL THEN
			Focus.fig := fig; Focus.shape := shape
		END;
		RETURN shape # NIL
	END SetFocus;

	PROCEDURE Integrate (frame: LeoFrames.Frame; CONST s: ARRAY OF CHAR);
		VAR
			fig: Leonardo.Figure; name: ARRAY 64 OF CHAR; size, col: SIGNED32; font: GfxFonts.Font; color: Gfx.Color;
			cap: LeoCaptions.Caption; done: BOOLEAN;
	BEGIN
		fig := frame.obj(Leonardo.Figure);
		Leonardo.DisableUpdate(fig);
		Attributes.GetString(Font, "Value", name); Attributes.GetInt(Size, "Value", size);
		IF size = 0 THEN size := 12 END;
		font := GfxFonts.OpenSize(name, SHORT(size));
		IF font = NIL THEN font := GfxFonts.Default END;
		Attributes.GetInt(Color, "Color", col);
		Display.GetColor(col, color.r, color.g, color.b);
		NEW(cap); LeoCaptions.Init(cap, Focus.px, Focus.py, s, font, color);
		Leonardo.Integrate(fig, cap);
		done := SetFocus(frame, cap.urx-0.5, 0.5*(cap.lly + cap.ury));
		Leonardo.EnableUpdate(fig)
	END Integrate;

	PROCEDURE Track (frame: LeoFrames.Frame; VAR msg: Oberon.InputMsg);
		VAR
			fx, fy, mx, my, x, y, len: SIGNED16; px, py: FLOAT32; keysum, keys, state: SET; done: BOOLEAN; text: Texts.Text;
			beg, end, time: SIGNED32; tool: LeoTools.Tool; mask: Display3.Mask; s: ARRAY 128 OF CHAR;
	BEGIN
		IF msg.keys = {} THEN
			LeoTools.TrackTool(LeoTools.Current(frame), "caption", Cursor, msg)
		ELSIF msg.keys = {2} THEN
			fx := msg.x + frame.X; fy := msg.y + frame.Y;
			LeoTools.FrameToPoint(frame, msg.X - fx, msg.Y - fy, px, py);
			IF SetFocus(frame, px, py) THEN	(* track focus within existing shape *)
				mx := msg.X; my := msg.Y; keysum := msg.keys;
				REPEAT
					Input.Mouse(keys, x, y);
					keysum := keysum + keys;
					IF (keys # {}) & ((x # mx) OR (y # my)) THEN
						LeoTools.FrameToPoint(frame, x - fx, y - fy, px, py);
						done := SetFocus(frame, px, py);
						mx := x; my := y;
						Oberon.DrawCursor(Oberon.Mouse, Cursor, x, y)
					END
				UNTIL keys = {};
				IF keysum = {2, 1} THEN
					Oberon.GetSelection(text, beg, end, time);
					IF time >= 0 THEN
						ConsumeText(frame.obj(Leonardo.Figure), text, beg, end)
					END
				END

			ELSE
				Oberon.RemoveMarks(fx, fy, frame.W, frame.H);
				IF Focus.frame # frame THEN
					Oberon.Defocus;
					Focus.frame := frame; Focus.visible := FALSE
				END;
				tool := LeoTools.Current(frame);
				LeoTools.Align(tool, px, py, px, py);
				Focus.px := px; Focus.py := py;
				Gadgets.MakeMask(frame, fx, fy, msg.dlink, mask);

				Oberon.FadeCursor(Oberon.Mouse);
				keysum := msg.keys; mx := -1; my := -1;
				REPEAT
					HideCaret(fx, fy, mask);
					LeoTools.PointToFrame(frame, Focus.px, Focus.py, Focus.x, Focus.y);
					Focus.x := fx + Focus.x; Focus.y := fy + Focus.y;
					Input.KeyState(state);
					LeoTools.ShowHints(tool, fx, fy, mask, Focus.x, Focus.y, Input.CTRL IN state);
					len := 0; LeoTools.AppendPoint(tool, Focus.px, Focus.py, s, len);
					LeoTools.ShowStatus(frame, fx, fy, mask, s);
					ShowCaret(fx, fy, mask);
					px := Focus.px; py := Focus.py;
					REPEAT
						Input.Mouse(keys, x, y); keysum := keysum + keys;
						IF (keys # {}) & ((x # mx) OR (y # my)) THEN
							IF LeoTools.InContents(x, y, fx, fy, frame.W, frame.H) THEN
								LeoTools.FrameToPoint(frame, x - fx, y - fy, Focus.px, Focus.py);
								LeoTools.Align(tool, Focus.px, Focus.py, Focus.px, Focus.py)
							END;
							mx := x; my := y
						END
					UNTIL (keys = {}) OR (Focus.px # px) OR (Focus.py # py);
				UNTIL keys = {};

				IF keysum = {2, 1} THEN
					Oberon.GetSelection(text, beg, end, time);
					IF time >= 0 THEN
						HideCaret(fx, fy, mask); Focus.frame := NIL;
						GetText(text, beg, end, s);
						Integrate(frame, s)
					END
				END
			END;
			Oberon.DrawCursor(Oberon.Mouse, Cursor, mx, my);
			msg.res := 0
		ELSE
			LeoTools.Track(LeoTools.Current(frame), msg)
		END
	END Track;

	PROCEDURE Handle (obj: Objects.Object; VAR msg: Objects.ObjMsg);
		VAR frame: LeoFrames.Frame; s: ARRAY 256 OF CHAR; e: LeoPanels.Editor;
	BEGIN
		frame := obj(LeoFrames.Frame);
		IF msg IS Display.FrameMsg THEN
			WITH msg: Display.FrameMsg DO
				IF (msg.F = NIL) OR (msg.F = frame) THEN
					IF msg IS Oberon.InputMsg THEN
						WITH msg: Oberon.InputMsg DO
							IF (msg.id = Oberon.track) & ~(Gadgets.selected IN frame.state) &
								LeoTools.InContents(msg.X, msg.Y, msg.x + frame.X, msg.y + frame.Y, frame.W, frame.H)
							THEN
								Track(frame, msg)
							ELSIF msg.id = Oberon.consume THEN
								IF frame = Focus.frame THEN	(* create new caption *)
									s[0] := msg.ch; s[1] := 0X;
									Integrate(frame, s);
									msg.res := 0
								ELSIF frame.obj = Focus.fig THEN
									LeoCaptions.Consume(Focus.fig, Focus.shape, msg.ch, msg.res)
								END
							ELSE
								LeoTools.HandleFrame(frame, msg)
							END
						END
					ELSIF msg IS Oberon.ConsumeMsg THEN
						WITH msg: Oberon.ConsumeMsg DO
							IF frame = Focus.frame THEN
								Focus.frame := NIL;
								GetText(msg.text, msg.beg, msg.end, s);
								Integrate(frame, s)
							ELSIF frame.obj = Focus.fig THEN
								ConsumeText(Focus.fig, msg.text, msg.beg, msg.end)
							END
						END
					ELSIF msg IS Oberon.ControlMsg THEN
						IF (frame = Focus.frame) & (msg(Oberon.ControlMsg).id IN {Oberon.neutralize, Oberon.defocus}) THEN
							Hide(frame, msg); Focus.frame := NIL
						ELSIF (frame.obj = Focus.fig) & (msg(Oberon.ControlMsg).id IN {Oberon.neutralize, Oberon.defocus}) THEN
							LeoCaptions.Release(Focus.fig, Focus.shape)
						END;
						LeoTools.HandleFrame(frame, msg)
					ELSIF (msg IS Leonardo.UpdateMsg) & (msg(Leonardo.UpdateMsg).fig = frame.obj) THEN
						IF frame = Focus.frame THEN Hide(frame, msg) END;
						LeoTools.HandleFrame(frame, msg);
						IF frame = Focus.frame THEN Show(frame, msg) END
					ELSIF (msg IS Display.DisplayMsg) & (msg(Display.DisplayMsg).device = Display.screen) THEN
						IF frame = Focus.frame THEN Hide(frame, msg) END;
						LeoTools.HandleFrame(frame, msg);
						IF frame = Focus.frame THEN Show(frame, msg) END
					ELSIF msg IS Display.ModifyMsg THEN
						IF frame = Focus.frame THEN Hide(frame, msg); Focus.frame := NIL END;
						LeoTools.HandleFrame(frame, msg)
					ELSIF msg IS Display.ControlMsg THEN
						IF frame = Focus.frame THEN Hide(frame, msg) END;
						LeoTools.HandleFrame(frame, msg)
					ELSIF msg IS LeoTools.ToolMsg THEN
						IF frame = Focus.frame THEN Hide(frame, msg)
						ELSIF frame.obj = Focus.fig THEN LeoCaptions.Release(Focus.fig, Focus.shape)
						END;
						LeoTools.HandleFrame(frame, msg)
					ELSE
						LeoTools.HandleFrame(frame, msg)
					END
				END
			END
		ELSIF msg IS Objects.LinkMsg THEN
			WITH msg: Objects.LinkMsg DO
				IF (msg.id = Objects.get) & (msg.name = "Editor") & (msg.res < 0) THEN
					msg.obj := LeoPanels.CopyObj("CaptionToolPanel", TRUE);
					Links.GetLink(msg.obj, "Model", obj);
					IF (obj # NIL) & (obj IS LeoPanels.Editor) THEN
						e := obj(LeoPanels.Editor); e.revert := RevertTool; e.apply := ApplyTool; RevertTool(e);
						msg.res := 0
					END
				ELSE
					LeoTools.HandleFrame(frame, msg)
				END
			END
		ELSE
			LeoTools.HandleFrame(frame, msg)
		END
	END Handle;

	(** activate caption tool **)
	PROCEDURE Activate*;
	BEGIN
		LeoTools.Activate(Handle)
	END Activate;


	(**--- Editor ---**)

	PROCEDURE Revert (editor: LeoPanels.Editor);
		VAR obj: Objects.Object; cap: LeoCaptions.Caption;
	BEGIN
		Links.GetLink(editor, "Model", obj);
		IF (obj # NIL) & (obj IS LeoCaptions.Caption) THEN
			cap := obj(LeoCaptions.Caption);
			Attributes.SetString(editor, "Text", cap.text^);
			Attributes.SetString(editor, "Font", cap.font.name); Attributes.SetInt(editor, "Size", cap.font.ptsize);
			Attributes.SetInt(editor, "Color", Display.RGB(cap.color.r, cap.color.g, cap.color.b));
			Gadgets.Update(editor)
		END
	END Revert;

	PROCEDURE Apply (editor: LeoPanels.Editor);
		VAR obj: Objects.Object; cap: LeoCaptions.Caption; s: ARRAY 64 OF CHAR; i: SIGNED32;
	BEGIN
		Links.GetLink(editor, "Model", obj);
		IF (obj # NIL) & (obj IS LeoCaptions.Caption) & (editor.fig # NIL) THEN
			cap := obj(LeoCaptions.Caption);
			Leonardo.BeginCommand(editor.fig);
			Attributes.GetString(editor, "Text", s); Leonardo.SetString(editor.fig, cap, "Text", s);
			Attributes.GetString(editor, "Font", s); Leonardo.SetString(editor.fig, cap, "Font", s);
			Attributes.GetInt(editor, "Size", i); Leonardo.SetInt(editor.fig, cap, "Size", i);
			Attributes.GetInt(editor, "Color", i); Leonardo.SetColor(editor.fig, cap, i);
			Leonardo.EndCommand(editor.fig)
		END
	END Apply;

	PROCEDURE New*;
		VAR obj: Objects.Object; editor: LeoPanels.Editor;
	BEGIN
		Objects.NewObj := LeoPanels.CopyObj("CaptionPanel", TRUE);
		Links.GetLink(Objects.NewObj, "Model", obj);
		IF (obj # NIL) & (obj IS LeoPanels.Editor) THEN
			editor := obj(LeoPanels.Editor); editor.revert := Revert; editor.apply := Apply
		END
	END New;


BEGIN
	InitCursor;
	Font := LeoPanels.FindObj("CaptionFont");
	Size := LeoPanels.FindObj("CaptionSize");
	Color := LeoPanels.FindObj("CaptionColor")
END LeoCaptionEditors.
