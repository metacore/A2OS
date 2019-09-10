(* ETH Oberon, Copyright 2001 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

MODULE VinciGadgets IN Oberon; (** portable *)	(* eos  *)

	(**
		Frames displaying Vinci descriptions
	**)

	IMPORT
		Files, Objects, Display, Texts, Oberon, Printer, Display3, Printer3, Effects, Gadgets,
		GfxRegions, Gfx, GfxDisplay, GfxPrinter, Scheme, Vinci;


	TYPE
		Frame* = POINTER TO FrameDesc;
		FrameDesc* = RECORD (Gadgets.FrameDesc)
			(* obj is Texts.Text containing the current description *)
			body*: Scheme.Object;	(** parsed description **)
			ox*, oy*: SIGNED16;	(** vector from upper left corner of frame to origin in screen space **)
			scale*: FLOAT32;	(** viewport scale factor **)
		END;


	VAR
		DC: GfxDisplay.Context;	(* shared context for rendering to the screen *)
		ClipReg: GfxRegions.Region;	(* shared region for calculating clip region from mask *)
		W: Texts.Writer;


	(**--- Parsing and Evaluation ---**)

	PROCEDURE Parse* (text: Texts.Text; pos: SIGNED32; VAR body: Scheme.Object);
		VAR ctxt: Vinci.Context;
	BEGIN
		NEW(ctxt); Vinci.MakeContext(ctxt, Scheme.NewTextInput(text, pos), NIL);
		Vinci.Parse(ctxt, body);
		IF ctxt.failed OR (body = NIL) THEN
			Vinci.ShowError;
			body := Scheme.nil
		END
	END Parse;

	PROCEDURE Evaluate* (frame: Frame; gc: Gfx.Context);
		VAR ctxt: Vinci.Context;
	BEGIN
		IF Scheme.IsNull(frame.body) THEN
			Parse(frame.obj(Texts.Text), 0, frame.body)
		END;
		IF ~Scheme.IsNull(frame.body) THEN
			NEW(ctxt); Vinci.MakeContext(ctxt, Scheme.nil, gc);
			Scheme.EvaluateSequence(ctxt, Vinci.globals, frame.body);
			IF ctxt.failed THEN
				Vinci.ShowError
			END
		END
	END Evaluate;


	(*--- Rendering ---*)

	PROCEDURE AddMaskRect (x, y, w, h: SIGNED16);
	BEGIN
		GfxRegions.AddRect(ClipReg, x, y, x + w, y + h)
	END AddMaskRect;

	PROCEDURE RestoreFrame (frame: Frame; x, y, w, h, fx, fy: SIGNED16; mask: Display3.Mask);
	BEGIN
		INC(x, fx); INC(y, fy);
		Oberon.RemoveMarks(x, y, w, h);
		Display3.ReplConst(mask, Display3.textbackC, x, y, w, h, Display.replace);
		GfxRegions.Clear(ClipReg);
		Display3.EnumRect(mask, mask.X, mask.Y, mask.W, mask.H, AddMaskRect);
		GfxDisplay.SetClipRegion(DC, ClipReg);
		GfxDisplay.SetCoordinates(DC, fx + frame.ox, fy + frame.H + frame.oy, DC.scale);
		Gfx.Reset(DC);
		Gfx.Scale(DC, frame.scale, frame.scale);
		Evaluate(frame, DC);
		IF Gadgets.selected IN frame.state THEN
			Display3.FillPattern(mask, Display3.white, Display3.selectpat, fx, fy, x, y, w, h, Display.paint)
		END
	END RestoreFrame;

	PROCEDURE DisplayFrame (frame: Frame; VAR msg: Display.DisplayMsg);
		VAR fx, fy: SIGNED16; mask: Display3.Mask; pc: GfxPrinter.Context; scale: FLOAT32;
	BEGIN
		IF msg.device = Display.screen THEN
			fx := msg.x + frame.X; fy := msg.y + frame.Y;
			IF (msg.id = Display.full) OR (msg.F = NIL) THEN
				Gadgets.MakeMask(frame, fx, fy, msg.dlink, mask);
				RestoreFrame(frame, 0, 0, frame.W, frame.H, fx, fy, mask)
			ELSIF msg.id = Display.area THEN
				Gadgets.MakeMask(frame, fx, fy, msg.dlink, mask);
				Display3.AdjustMask(mask, fx + msg.u, fy + frame.H - 1 + msg.v, msg.w, msg.h);
				RestoreFrame(frame, msg.u, msg.v + frame.H - 1, msg.w, msg.h, fx, fy, mask)
			END
		ELSIF msg.device = Display.printer THEN
			IF msg.id = Display.contents THEN
				NEW(pc); GfxPrinter.Init(pc);
				Gfx.Reset(pc);
				Evaluate(frame, pc);
				Printer.Page(1)
			ELSIF msg.id = Display.full THEN
				NEW(pc); GfxPrinter.Init(pc);
				Gfx.Reset(pc);
				Gadgets.MakePrinterMask(frame, msg.x, msg.y, msg.dlink, mask);
				GfxRegions.Clear(ClipReg);
				Display3.EnumRect(mask, mask.X, mask.Y, mask.W, mask.H, AddMaskRect);
				Printer3.ReplConst(mask, Display3.textbackC, mask.X, mask.Y, mask.W, mask.H, Display.replace);
				scale := pc.scale;
				GfxPrinter.SetClipRegion(pc, ClipReg);
				GfxPrinter.SetCoordinates(pc, msg.x + scale * frame.ox, msg.y + scale * (frame.H + frame.oy), scale);
				Gfx.Reset(pc);
				Gfx.Scale(pc, frame.scale, frame.scale);
				Evaluate(frame, pc)
			END
		END
	END DisplayFrame;


	(*--- Mouse Tracking ---*)

	PROCEDURE TrackRect (frame: Frame; mx, my: SIGNED16; keys: SET; VAR x, y, w, h: SIGNED16; VAR keysum: SET);
	BEGIN
		x := mx; y := my; w := 0; h := 0;
		Effects.SizeRect(NIL, keysum, mx, my, x, y, w, h, NIL);
		IF keysum = keys THEN
			IF 16*w < frame.W THEN
				x := x + w DIV 2 - frame.W DIV 4;
				y := y + h DIV 2 - frame.H DIV 4;
				w := frame.W DIV 2; h := frame.H DIV 2
			END
		END
	END TrackRect;

	PROCEDURE TrackZoomIn (frame: Frame; VAR msg: Oberon.InputMsg);
		VAR x, y, w, h: SIGNED16; keysum: SET; scale: FLOAT32;
	BEGIN
		TrackRect(frame, msg.X, msg.Y, msg.keys, x, y, w, h, keysum);
		IF keysum = msg.keys THEN
			DEC(x, msg.x + frame.X); DEC(y, msg.y + frame.Y);
			scale := frame.W/w;
			frame.ox := SHORT(ENTIER(scale * (frame.ox - x)));
			frame.oy := SHORT(ENTIER(scale * (frame.H + frame.oy - y))) - frame.H;
			frame.scale := frame.scale * scale;
			Gadgets.Update(frame)
		END;
		msg.res := 0
	END TrackZoomIn;

	PROCEDURE TrackZoomOut (frame: Frame; VAR msg: Oberon.InputMsg);
		VAR x, y, w, h: SIGNED16; keysum: SET; scale: FLOAT32;
	BEGIN
		TrackRect(frame, msg.X, msg.Y, msg.keys, x, y, w, h, keysum);
		IF keysum = msg.keys THEN
			DEC(x, msg.x + frame.X); DEC(y, msg.y + frame.Y);
			scale := w/frame.W;
			frame.ox := x + SHORT(ENTIER(scale * frame.ox));
			frame.oy := y + SHORT(ENTIER(scale * (frame.oy + frame.H))) - frame.H;
			frame.scale := frame.scale * scale;
			Gadgets.Update(frame)
		END;
		msg.res := 0
	END TrackZoomOut;

	PROCEDURE TrackMove (frame: Frame; VAR msg: Oberon.InputMsg);
		VAR mx, my, x, y, w, h: SIGNED16; keysum: SET;
	BEGIN
		mx := msg.X; my := msg.Y;
		x := msg.x + frame.X; y := msg.y + frame.Y; w := frame.W; h := frame.H;
		Effects.MoveRect(NIL, keysum, mx, my, x, y, w, h);
		IF keysum = msg.keys THEN
			frame.ox := frame.ox + mx - msg.X;
			frame.oy := frame.oy + my - msg.Y;
			Gadgets.Update(frame)
		END;
		msg.res := 0
	END TrackMove;


	(*--- Handler ---*)

	PROCEDURE Handle (obj: Objects.Object; VAR msg: Objects.ObjMsg);
		VAR frame, copy: Frame; ver: SIGNED32;
	BEGIN
		frame := obj(Frame);
		IF msg IS Display.FrameMsg THEN
			WITH msg: Display.FrameMsg DO
				IF (msg.F = NIL) OR (msg.F = frame) THEN
					IF msg IS Oberon.InputMsg THEN
						WITH msg: Oberon.InputMsg DO
							IF (msg.id = Oberon.track) & Gadgets.InActiveArea(frame, msg) THEN
								IF msg.keys = {2} THEN TrackZoomIn(frame, msg)
								ELSIF msg.keys = {0} THEN TrackZoomOut(frame, msg)
								ELSIF msg.keys = {1} THEN TrackMove(frame, msg)
								ELSE Oberon.DrawCursor(Oberon.Mouse, Effects.Arrow, msg.X, msg.Y); msg.res := 0
								END
							ELSE
								Gadgets.framehandle(frame, msg)
							END
						END
					ELSIF msg IS Display.DisplayMsg THEN
						DisplayFrame(frame, msg(Display.DisplayMsg))
					ELSIF msg IS Texts.UpdateMsg THEN
						WITH msg: Texts.UpdateMsg DO
							IF msg.text = frame.obj THEN
								frame.body := Scheme.nil;
								Gadgets.Update(frame)
							END
						END
					ELSE
						Gadgets.framehandle(frame, msg)
					END
				END
			END
		ELSIF msg IS Objects.AttrMsg THEN
			WITH msg: Objects.AttrMsg DO
				IF msg.id = Objects.enum THEN
					msg.Enum("OrgX"); msg.Enum("OrgY"); msg.Enum("Scale");
				ELSIF msg.id = Objects.get THEN
					IF msg.name = "Gen" THEN msg.class := Objects.String; msg.s := "VinciGadgets.New"; msg.res := 0
					ELSIF msg.name = "OrgX" THEN msg.class := Objects.Int; msg.i := frame.ox; msg.res := 0
					ELSIF msg.name = "OrgY" THEN msg.class := Objects.Int; msg.i := frame.oy; msg.res := 0
					ELSIF msg.name = "Scale" THEN msg.class := Objects.Real; msg.x := frame.scale; msg.res := 0
					ELSE Gadgets.framehandle(frame, msg)
					END
				ELSIF msg.id = Objects.set THEN
					IF msg.name = "OrgX" THEN
						IF msg.class = Objects.Int THEN frame.ox := SHORT(msg.i); msg.res := 0 END
					ELSIF msg.name = "OrgY" THEN
						IF msg.class = Objects.Int THEN frame.oy := SHORT(msg.i); msg.res := 0 END
					ELSIF msg.name = "Scale" THEN
						IF msg.class = Objects.Int THEN frame.scale := msg.i; msg.res := 0
						ELSIF msg.class = Objects.Real THEN frame.scale := msg.x; msg.res := 0
						ELSIF msg.class = Objects.LongReal THEN frame.scale := SHORT(msg.y); msg.res := 0
						END
					ELSE
						Gadgets.framehandle(frame, msg)
					END
				ELSE
					Gadgets.framehandle(frame, msg)
				END
			END
		ELSIF msg IS Objects.LinkMsg THEN
			WITH msg: Objects.LinkMsg DO
				IF (msg.id = Objects.set) & (msg.name = "Model") THEN
					IF (msg.obj # NIL) & (msg.obj IS Texts.Text) THEN
						frame.obj := msg.obj; frame.body := Scheme.nil; msg.res := 0
					END
				ELSE
					Gadgets.framehandle(frame, msg)
				END
			END
		ELSIF msg IS Objects.CopyMsg THEN
			WITH msg: Objects.CopyMsg DO
				IF msg.stamp # frame.stamp THEN
					NEW(copy); frame.dlink := copy; frame.stamp := msg.stamp;
					Gadgets.CopyFrame(msg, frame, copy);
					copy.body := frame.body;
					copy.ox := frame.ox; copy.oy := frame.oy; copy.scale := frame.scale
				END;
				msg.obj := frame.dlink
			END
		ELSIF msg IS Objects.FileMsg THEN
			WITH msg: Objects.FileMsg DO
				Gadgets.framehandle(frame, msg);
				IF msg.id = Objects.store THEN
					Files.WriteNum(msg.R, 1);	(* version *)
					Files.WriteInt(msg.R, frame.ox); Files.WriteInt(msg.R, frame.oy + frame.H);
					Files.WriteReal(msg.R, frame.scale)
				ELSIF msg.id = Objects.load THEN
					Files.ReadNum(msg.R, ver);
					IF ver > 0 THEN
						Files.ReadInt(msg.R, frame.ox); Files.ReadInt(msg.R, frame.oy);
						frame.oy := frame.oy - frame.H;
						Files.ReadReal(msg.R, frame.scale)
					END;
					frame.body := Scheme.nil
				END
			END
		ELSE
			Gadgets.framehandle(frame, msg)
		END
	END Handle;

	PROCEDURE Init* (frame: Frame; obj: Objects.Object);
	BEGIN
		frame.handle := Handle; frame.W := 300; frame.H := 400;
		frame.obj := obj; frame.body := Scheme.nil;
		frame.ox := 0; frame.oy := -frame.H; frame.scale := 1
	END Init;

	PROCEDURE New*;
		VAR frame: Frame;
	BEGIN
		NEW(frame); Init(frame, Gadgets.CreateObject("Texts.New"));
		Objects.NewObj := frame
	END New;

	PROCEDURE Insert*;
		VAR
			s: Texts.Scanner; text: Texts.Text; beg, end, time: SIGNED32; buf: Texts.Buffer;
			frame: Frame; cm: Display.ConsumeMsg;
	BEGIN
		Texts.OpenScanner(s, Oberon.Par.text, Oberon.Par.pos); Texts.Scan(s);
		text := NIL;
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
			NEW(text); Texts.Open(text, s.s);
			IF text.len = 0 THEN text := NIL END
		END;
		IF text # NIL THEN
			NEW(frame); Init(frame, text);
			cm.F := NIL; cm.id := Display.integrate; cm.obj := frame;
			Display.Broadcast(cm)
		END
	END Insert;


BEGIN
	NEW(ClipReg); GfxRegions.Init(ClipReg, GfxRegions.Winding);
	NEW(DC); GfxDisplay.Init(DC, Display.ColLeft, Display.Bottom, Display.ColLeft + Display.Width, Display.Bottom + Display.Height);
	Texts.OpenWriter(W)
END VinciGadgets.
