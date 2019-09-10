(* ETH Oberon, Copyright 2001 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

MODULE ColorGadgets IN Oberon; (** portable **)	(* eos  *)

	(**
		Gadget controls for displaying and manipulating colors and color objects
	**)

	(*
		26.11.1999 - only convert display color to positive value for rendering
		10.05.2000 - avoid losing hue value when tracking wedge (suggested by pjm)
	*)

	IMPORT
		Files, Objects, Math IN A2, Display, Printer, Input, Texts, Oberon, Strings, Attributes, Display3, Printer3, Effects, Gadgets,
		Colors, Images;


	TYPE
		(** color wells displaying color model **)
		Well* = POINTER TO WellDesc;
		WellDesc* = RECORD (Gadgets.FrameDesc)
			dcol: Display.Color;	(* currently displayed value *)
		END;

		(** circular area for manipulating hue and saturation of a color **)
		Disc* = POINTER TO DiscDesc;
		DiscDesc* = RECORD (Gadgets.FrameDesc)
			bg: Display.Color;	(* background color *)
			hue, sat: FLOAT32;	(* current hue and saturation *)
			img: Images.Image;	(* background image with color circle *)
		END;

		(** wedge shaped area for manipulating saturation and value **)
		Wedge* = POINTER TO WedgeDesc;
		WedgeDesc* = RECORD (Gadgets.FrameDesc)
			bg: Display.Color;	(* background color *)
			hue, sat, val: FLOAT32;	(* current hue, saturation and value *)
			img: Images.Image;	(* background image with colored wedge *)
		END;


	VAR
		DragMarker: Oberon.Marker;
		MarkerFG, MarkerBG: Display.Pattern;
		Enum: RECORD
			img: Images.Image;
			x, y: SIGNED16;	(* map origin on device *)
		END;


	(*--- Support Procedures ---*)

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

	PROCEDURE RestoreRuns (x, y, w, h: SIGNED16);
		VAR x0, len, l, i, j: SIGNED16; line: ARRAY 512 OF CHAR; b: CHAR;
	BEGIN
		x0 := x;
		WHILE h > 0 DO
			x := x0; len := w;
			REPEAT
				IF len < LEN(line) THEN l := len ELSE l := LEN(line) END;
				Images.GetPixels(Enum.img, x - Enum.x, y - Enum.y, l, Images.D8, line, Images.SrcCopy);
				i := 0;
				WHILE i < l DO
					b := line[i]; j := i+1;
					WHILE (j < l) & (line[j] = b) DO INC(j) END;
					Display.ReplConst(ORD(b), x + i, y, j - i, 1, Display.replace);
					i := j
				END;
				INC(x, l); DEC(len, l)
			UNTIL len = 0;
			DEC(h); INC(y)
		END
	END RestoreRuns;

	PROCEDURE RestoreBlock (x, y, w, h: SIGNED16);
		VAR offset: SIGNED32;
	BEGIN
		offset := (y - Enum.y) * Enum.img.bpr + (x - Enum.x) * Enum.img.fmt.bpp DIV 8;
		Display.TransferBlock(Enum.img.mem^, offset, Enum.img.bpr, x, y, w, h, Display.set)
	END RestoreBlock;

	PROCEDURE RestoreImageRect (img: Images.Image; x, y, w, h, dx, dy: SIGNED16; mask: Display3.Mask);
		VAR xw, yh: SIGNED16;
	BEGIN
		INC(x, dx); INC(y, dy);
		xw := x + w; yh := y + h;
		IF x < mask.X THEN x := mask.X END;
		IF xw > mask.X + mask.W THEN xw := mask.X + mask.W END;
		IF y < mask.Y THEN y := mask.Y END;
		IF yh > mask.Y + mask.H THEN yh := mask.Y + mask.H END;
		w := xw - x; h := yh - y;
		Oberon.RemoveMarks(x, y, w, h);
		Enum.img := img; Enum.x := dx; Enum.y := dy;
		IF Display.TransferFormat(dx) = Display.unknown THEN
			Display3.EnumRect(mask, x, y, w, h, RestoreRuns)
		ELSE
			Display3.EnumRect(mask, x, y, w, h, RestoreBlock)
		END;
	END RestoreImageRect;


	(**--- Wells ---**)

	PROCEDURE DrawMarker (x, y: SIGNED16);
	BEGIN
		DEC(x, 3); DEC(y);
		Effects.OpenCursor(x, y, 16, 17);
		Display.CopyPattern(Display3.white, MarkerBG, x, y, Display.paint);
		Display.CopyPattern(Display3.black, MarkerFG, x, y, Display.paint)
	END DrawMarker;

	PROCEDURE FadeMarker (x, y: SIGNED16);
	BEGIN
		Effects.CloseCursor
	END FadeMarker;

	PROCEDURE InitDragMarker;
		VAR p: ARRAY 17 OF SET;
	BEGIN
		p[0] := {}; p[1] := {1, 2, 5, 6}; p[2] := {3, 4}; p[3] := {3, 4, 9, 10}; p[4] := {3, 4, 8, 11}; p[5] := {3, 4, 7, 12};
		p[6] := {3, 4, 6, 13}; p[7] := {3..5, 14}; p[8] := {3, 4, 9, 14}; p[9] := {3..5, 8, 10, 13}; p[10] := {4..6, 9, 12};
		p[11] := {6, 7, 9, 11, 13}; p[12] := {8..10, 12}; p[13] := {9, 12}; p[14] := {9, 12}; p[15] := {10, 11}; p[16] := {};
		MarkerFG := Display.NewPattern(16, 17, p);
		p[0] := {1..6}; p[1] := {0..7}; p[2] := {2..5}; p[3] := {2..5, 8..11}; p[4] := {2..5, 7..12}; p[5] := {2..13};
		p[6] := {2..7, 12..14}; p[7] := {2..6, 13..15}; p[8] := {2..5, 8..10, 13..15}; p[9] := {2..14}; p[10] := {3..13};
		p[11] := {5..14}; p[12] := {7..13}; p[13] := {8..13}; p[14] := {8..13}; p[15] := {9..12}; p[16] := {10, 11};
		MarkerBG := Display.NewPattern(16, 17, p);
		DragMarker.Draw := DrawMarker; DragMarker.Fade := FadeMarker
	END InitDragMarker;

	PROCEDURE TrackWell (well: Well; VAR msg: Oberon.InputMsg);
		VAR
			fx, fy, x, y, u, v, r, g, b: SIGNED16; mask: Display3.Mask; marker: Oberon.Marker; keysum, keys: SET;
			frame: Display.Frame; lm: Objects.LinkMsg; am: Objects.AttrMsg; cm: Objects.CopyMsg;
	BEGIN
		fx := msg.x + well.X; fy := msg.y + well.Y;
		Gadgets.MakeMask(well, fx, fy, msg.dlink, mask);
		Oberon.FadeCursor(Oberon.Mouse);
		Display3.Rect3D(mask, Display3.bottomC, Display3.topC, fx, fy, well.W, well.H, 1, Display.replace);
		marker := Effects.Arrow; keysum := msg.keys;
		REPEAT
			Input.Mouse(keys, x, y);
			IF keys - keysum # {} THEN	(* new key pressed *)
				Oberon.FadeCursor(Oberon.Mouse);
				Display3.Rect3D(mask, Display3.topC, Display3.bottomC, fx, fy, well.W, well.H, 1, Display.replace);
				keysum := keysum + keys;
				IF keysum = {0..2} THEN marker := Effects.Arrow
				ELSE marker := DragMarker
				END
			END;
			Oberon.DrawCursor(Oberon.Mouse, marker, x, y);
			Input.Mouse(keys, x, y)
		UNTIL keys = {};
		Oberon.FadeCursor(Oberon.Mouse);
		Display3.Rect3D(mask, Display3.topC, Display3.bottomC, fx, fy, well.W, well.H, 1, Display.replace);
		IF keysum = {1} THEN
			Gadgets.ExecuteAttr(well, "Cmd", msg.dlink, NIL, NIL)
		ELSIF keysum # {} THEN
			Gadgets.ThisFrame(x, y, frame, u, v);
			IF frame # NIL THEN
				IF keysum = {2, 1} THEN	(* share model with target *)
					lm.id := Objects.set; lm.obj := well.obj; lm.res := -1;
					IF well.obj # NIL THEN
						Attributes.GetString(well, "TargetLink", lm.name);
						IF keysum = {1, 0} THEN
							Objects.Stamp(cm); cm.id := Objects.shallow; well.obj.handle(well.obj, cm); lm.obj := cm.obj
						END;
						lm.id := Objects.set; lm.res := -1; frame.handle(frame, lm);
						IF lm.res >= 0 THEN
							Gadgets.Update(well.obj)
						END
					END
				END;
				IF (keysum = {1, 0}) OR (lm.res < 0) THEN	(* copy color value *)
					Attributes.GetString(well, "TargetField", am.name);
					am.id := Objects.set; am.class := Objects.Int; am.i := well.dcol; am.res := -1; frame.handle(frame, am);
					IF (am.res < 0) & (well.dcol < 0) THEN
						Display.GetColor(well.dcol, r, g, b);
						am.i := Colors.Match(Colors.DisplayIndex, Colors.DisplayBits, r, g, b); frame.handle(frame, am)
					END;
					IF am.res >= 0 THEN
						Gadgets.Update(frame)
					END
				END
			END
		END;
		Oberon.DrawCursor(Oberon.Mouse, Effects.Arrow, x, y);
		msg.res := 0
	END TrackWell;

	PROCEDURE RestoreWell (well: Well; fx, fy: SIGNED16; mask: Display3.Mask);
		VAR w, h, r, g, b: SIGNED16; dcol: Display.Color;
	BEGIN
		w := well.W; h := well.H;
		Oberon.RemoveMarks(fx, fy, w, h);
		Display3.Rect3D(mask, Display3.topC, Display3.bottomC, fx, fy, w, h, 1, Display.replace);
		Display3.Rect(mask, Display3.groupC, Display.solid, fx+1, fy+1, w-2, h-2, 1, Display.replace);
		dcol := well.dcol;
		IF (dcol < 0) & ~Display.TrueColor(fx) THEN
			Display.GetColor(dcol, r, g, b);
			dcol := Colors.Match(Colors.DisplayIndex, Colors.DisplayBits, r, g, b)
		END;
		Display3.FilledRect3D(mask, Display3.bottomC, Display3.topC, dcol, fx+2, fy+2, w-4, h-4, 1, Display.replace);
		IF Gadgets.selected IN well.state THEN
			Display3.FillPattern(mask, Display3.white, Display3.selectpat, fx, fy, fx, fy, w, h, Display.paint)
		END
	END RestoreWell;

	PROCEDURE PrintWell (well: Well; VAR msg: Display.DisplayMsg);
		VAR mask: Display3.Mask; x, y, w, h, one, two: SIGNED16;

		PROCEDURE pc (x: SIGNED32): SIGNED16;
		BEGIN
			RETURN SHORT(x * Display.Unit DIV Printer.Unit)
		END pc;

	BEGIN
		Gadgets.MakePrinterMask(well, msg.x, msg.y, msg.dlink, mask);
		x := msg.x; y := msg.y; w := pc(well.W); h := pc(well.H); one := pc(1); two := 2*one;
		Printer3.Rect3D(mask, Display3.topC, Display3.bottomC, x, y, w, h, one, Display.replace);
		Printer3.Rect(mask, Display3.groupC, Display.solid, x + one, y + one, w - two, h - two, one, Display.replace);
		Printer3.FilledRect3D(mask, Display3.bottomC, Display3.topC, well.dcol, x + two, y + two, w - 2*two, h - 2*two, one, Display.replace);
		IF Gadgets.selected IN well.state THEN
			Printer3.FillPattern(mask, Display3.white, Display3.selectpat, x, y, x, y, w, h, Display.paint)
		END
	END PrintWell;

	PROCEDURE UpdateWell (well: Well; VAR msg: Display.FrameMsg);
		VAR am: Objects.AttrMsg; fx, fy: SIGNED16; mask: Display3.Mask;
	BEGIN
		IF well.obj # NIL THEN
			Attributes.GetString(well, "Field", am.name);
			am.id := Objects.get; am.class := Objects.Inval; am.res := -1; well.obj.handle(well.obj, am);
			IF (am.res >= 0) & (am.class = Objects.Int) & (am.i # well.dcol) THEN
				well.dcol := am.i;
				fx := msg.x + well.X; fy := msg.y + well.Y;
				Gadgets.MakeMask(well, fx, fy, msg.dlink, mask);
				RestoreWell(well, fx, fy, mask)
			END
		END
	END UpdateWell;

	PROCEDURE ConsumeWell (well: Well; VAR msg: Display.ConsumeMsg);
		VAR am: Objects.AttrMsg;
	BEGIN
		am.id := Objects.get; am.name := "Value"; am.class := Objects.Inval; am.res := -1; msg.obj.handle(msg.obj, am);
		IF (am.res >= 0) & (am.class = Objects.Int) THEN
			well.dcol := am.i;
			IF well.obj # NIL THEN
				Attributes.GetString(well, "Field", am.name);
				am.id := Objects.set; am.res := -1; well.obj.handle(well.obj, am);
				IF am.res >= 0 THEN
					Gadgets.Update(well.obj)
				END
			ELSE
				Gadgets.Update(well)
			END
		END
	END ConsumeWell;

	PROCEDURE WellAttr (well: Well; VAR msg: Objects.AttrMsg);
		VAR am: Objects.AttrMsg;
	BEGIN
		IF msg.id = Objects.enum THEN
			msg.Enum("Color"); msg.Enum("Field"); msg.Enum("Cmd");
			msg.Enum("TargetLink"); msg.Enum("TargetField");
			Gadgets.framehandle(well, msg)
		ELSIF msg.id = Objects.get THEN
			IF msg.name = "Gen" THEN
				msg.class := Objects.String; msg.s := "ColorGadgets.NewWell"; msg.res := 0
			ELSIF msg.name = "Color" THEN
				msg.class := Objects.Int; msg.i := well.dcol; msg.res := 0
			ELSE
				Gadgets.framehandle(well, msg);
				IF msg.res < 0 THEN
					IF msg.name = "Field" THEN msg.class := Objects.String; msg.s := "Color"; msg.res := 0
					ELSIF msg.name = "Cmd" THEN msg.class := Objects.String; msg.s := ""; msg.res := 0
					ELSIF msg.name = "TargetLink" THEN msg.class := Objects.String; msg.s := "Model"; msg.res := 0
					ELSIF msg.name = "TargetField" THEN msg.class := Objects.String; msg.s := "Color"; msg.res := 0
					END
				END
			END
		ELSIF msg.id = Objects.set THEN
			IF msg.name = "Color" THEN
				IF (msg.class = Objects.Int) & (msg.i < 256) THEN
					well.dcol := msg.i; msg.res := 0;
					IF well.obj # NIL THEN
						Attributes.GetString(well, "Field", am.name);
						am.id := Objects.set; am.class := Objects.Int; am.i := well.dcol; am.res := -1; well.obj.handle(well.obj, am);
						IF am.res >= 0 THEN
							Gadgets.Update(well.obj)
						END
					END
				END
			ELSE
				Gadgets.framehandle(well, msg)
			END
		END
	END WellAttr;

	PROCEDURE CopyWell* (VAR msg: Objects.CopyMsg; from, to: Well);
	BEGIN
		Gadgets.CopyFrame(msg, from, to);
		to.dcol := from.dcol
	END CopyWell;

	PROCEDURE HandleWell* (obj: Objects.Object; VAR msg: Objects.ObjMsg);
		VAR well, copy: Well; fx, fy: SIGNED16; mask: Display3.Mask; ver: SIGNED32;
	BEGIN
		well := obj(Well);
		IF msg IS Display.FrameMsg THEN
			WITH msg: Display.FrameMsg DO
				IF (msg.F = NIL) OR (msg.F = well) THEN
					IF msg IS Oberon.InputMsg THEN
						WITH msg: Oberon.InputMsg DO
							IF (msg.id = Oberon.track) & (msg.keys = {1}) & ~(Gadgets.selected IN well.state) &
								Gadgets.InActiveArea(well, msg)
							THEN
								TrackWell(well, msg)
							ELSE
								Gadgets.framehandle(well, msg)
							END
						END
					ELSIF msg IS Display.DisplayMsg THEN
						WITH msg: Display.DisplayMsg DO
							IF msg.device = Display.screen THEN
								fx := msg.x + well.X; fy := msg.y + well.Y;
								IF msg.id = Display.full THEN
									Gadgets.MakeMask(well, fx, fy, msg.dlink, mask);
									RestoreWell(well, fx, fy, mask)
								ELSIF msg.id = Display.area THEN
									Gadgets.MakeMask(well, fx, fy, msg.dlink, mask);
									Display3.AdjustMask(mask, fx + msg.u, fy + (well.H-1) + msg.v, msg.w, msg.h);
									RestoreWell(well, fx, fy, mask)
								END
							ELSIF msg.device = Display.printer THEN
								PrintWell(well, msg)
							END
						END
					ELSIF msg IS Gadgets.UpdateMsg THEN
						WITH msg: Gadgets.UpdateMsg DO
							IF msg.obj = well.obj THEN
								UpdateWell(well, msg)
							ELSIF msg.obj = well THEN
								fx := msg.x + well.X; fy := msg.y + well.Y;
								Gadgets.MakeMask(well, fx, fy, msg.dlink, mask);
								RestoreWell(well, fx, fy, mask)
							END
						END
					ELSIF msg IS Display.ControlMsg THEN
						WITH msg: Display.ControlMsg DO
							IF well.obj # NIL THEN
								well.obj.handle(well.obj, msg)
							END;
							IF (msg.id = Display.restore) & (msg.stamp # well.stamp) THEN
								well.stamp := msg.stamp;
								UpdateWell(well, msg)
							END
						END
					ELSIF msg IS Display.ConsumeMsg THEN
						WITH msg: Display.ConsumeMsg DO
							IF (msg.id = Display.drop) & (msg.obj # NIL) THEN
								ConsumeWell(well, msg)
							END
						END
					ELSE
						Gadgets.framehandle(well, msg)
					END
				END
			END
		ELSIF msg IS Objects.AttrMsg THEN
			WellAttr(well, msg(Objects.AttrMsg))
		ELSIF msg IS Objects.CopyMsg THEN
			WITH msg: Objects.CopyMsg DO
				IF msg.stamp # well.stamp THEN
					NEW(copy); well.dlink := copy; well.stamp := msg.stamp;
					CopyWell(msg, well, copy)
				END;
				msg.obj := well.dlink
			END
		ELSIF msg IS Objects.FileMsg THEN
			WITH msg: Objects.FileMsg DO
				Gadgets.framehandle(well, msg);
				IF msg.id = Objects.store THEN
					Files.WriteNum(msg.R, 1);
					Files.WriteLInt(msg.R, well.dcol)
				ELSIF msg.id = Objects.load THEN
					Files.ReadNum(msg.R, ver);
					Files.ReadLInt(msg.R, well.dcol)
				END
			END
		ELSE
			Gadgets.framehandle(well, msg)
		END
	END HandleWell;

	PROCEDURE NewWell*;
		VAR well: Well;
	BEGIN
		NEW(well); well.handle := HandleWell; well.W := 20; well.H := 20;
		Objects.NewObj := well
	END NewWell;


	(**--- Discs ---**)

	PROCEDURE GetDiscCoords (disc: Disc; VAR x, y: SIGNED16);
	BEGIN
		IF disc.sat < 0.001 THEN
			x := disc.W DIV 2;
			y := disc.H DIV 2
		ELSE
			x := SHORT(ENTIER((1 + disc.sat * Math.cos(2*Math.pi * disc.hue)) * (disc.W/2)));
			y := SHORT(ENTIER((1 + disc.sat * Math.sin(2*Math.pi * disc.hue)) * (disc.H/2)))
		END
	END GetDiscCoords;

	PROCEDURE UpdateDiscModel (disc: Disc);
		VAR am: Objects.AttrMsg;
	BEGIN
		IF disc.obj # NIL THEN
			Attributes.GetString(disc, "SatField", am.name);
			am.id := Objects.set; am.class := Objects.Real; am.x := disc.sat; am.res := -1; disc.obj.handle(disc.obj, am);
			IF am.res >= 0 THEN
				Attributes.GetString(disc, "HueField", am.name);
				am.id := Objects.set; am.class := Objects.Real; am.x := disc.hue; am.res := -1; disc.obj.handle(disc.obj, am);
				IF am.res >= 0 THEN
					Gadgets.Update(disc.obj)
				END
			END
		END
	END UpdateDiscModel;

	PROCEDURE TrackDisc (disc: Disc; VAR msg: Oberon.InputMsg);
		VAR fx, fy, px, py, mx, my, x, y: SIGNED16; mask: Display3.Mask; hue, sat, dx, dy: FLOAT32; keysum, keys: SET;
	BEGIN
		fx := msg.x + disc.X; fy := msg.y + disc.Y;
		Gadgets.MakeMask(disc, fx, fy, msg.dlink, mask);
		GetDiscCoords(disc, px, py);
		hue := disc.hue; sat := disc.sat;
		keysum := msg.keys; mx := -1; my := -1;
		REPEAT
			Input.Mouse(keys, x, y); keysum := keysum + keys;
			IF (keys # {}) & ((x # mx) OR (y # my)) THEN
				RestoreImageRect(disc.img, px-2, py-2, 5, 5, fx, fy, mask);
				dx := 2*(x - fx)/disc.W - 1; dy := 2*(y - fy)/disc.H - 1;
				disc.sat := Math.sqrt(dx * dx + dy * dy);
				IF disc.sat > 1.0 THEN disc.sat := 1.0 END;
				IF disc.sat < 0.001 THEN disc.hue := Colors.undefined
				ELSE disc.hue := atan2(dx, dy) * (1/(2*Math.pi))
				END;
				UpdateDiscModel(disc);
				GetDiscCoords(disc, px, py);
				Display3.Rect(mask, Display3.black, Display.solid, fx + px - 2, fy + py - 2, 5, 5, 1, Display.replace);
				mx := x; my := y;
				Oberon.DrawCursor(Oberon.Mouse, Effects.Arrow, x, y)
			END
		UNTIL keys = {};
		IF keysum = {0..2} THEN
			RestoreImageRect(disc.img, px-2, py-2, 5, 5, fx, fy, mask);
			disc.hue := hue; disc.sat := sat;
			GetDiscCoords(disc, px, py);
			Display3.Rect(mask, Display3.black, Display.solid, fx + px - 2, fy + py - 2, 5, 5, 1, Display.replace);
			UpdateDiscModel(disc)
		END;
		Oberon.DrawCursor(Oberon.Mouse, Effects.Arrow, x, y);
		msg.res := 0
	END TrackDisc;

	PROCEDURE RestoreDiscImage (disc: Disc);
		VAR r, g, b, j, i: SIGNED16; pix: Images.Pixel; dx, dy, y, x, sat, hue, rr, gg, bb: FLOAT32;
	BEGIN
		IF disc.img = NIL THEN
			NEW(disc.img)
		END;
		IF (disc.img.width # disc.W) OR (disc.img.height # disc.H) THEN
			Images.Create(disc.img, disc.W, disc.H, Images.DisplayFormat);
			Display.GetColor(disc.bg, r, g, b); Images.SetRGB(pix, r, g, b);
			Images.Fill(disc.img, 0, 0, disc.W, disc.H, pix, Images.SrcCopy);
			dx := 2/disc.W; dy := 2/disc.H;
			j := 0; y := -1.0;
			WHILE j < disc.H DO
				i := 0; x := -1.0;
				WHILE i < disc.W DO
					sat := Math.sqrt(x * x + y * y);
					IF sat <= 1 THEN
						hue := atan2(x, y) * (1/(2*Math.pi));
						Colors.HSVToRGB(hue, sat, 1.0, rr, gg, bb);
						r := SHORT(ENTIER(255*rr)); g := SHORT(ENTIER(255*gg)); b := SHORT(ENTIER(255*bb));
						Images.SetRGB(pix, r, g, b);
						Images.Put(disc.img, i, j, pix, Images.SrcCopy)
					END;
					INC(i); x := x + dx
				END;
				INC(j); y := y + dy
			END
		END
	END RestoreDiscImage;

	PROCEDURE RestoreDisc (disc: Disc; fx, fy: SIGNED16; mask: Display3.Mask);
		VAR x, y: SIGNED16;
	BEGIN
		RestoreDiscImage(disc);
		RestoreImageRect(disc.img, 0, 0, disc.W, disc.H, fx, fy, mask);
		GetDiscCoords(disc, x, y);
		Display3.Rect(mask, Display3.black, Display.solid, fx + x - 2, fy + y - 2, 5, 5, 1, Display.replace);
		IF Gadgets.selected IN disc.state THEN
			Display3.FillPattern(mask, Display3.white, Display3.selectpat, fx, fy, fx, fy, disc.W, disc.H, Display.paint)
		END
	END RestoreDisc;

	PROCEDURE PrintDisc (disc: Disc; VAR msg: Display.DisplayMsg);
		VAR mask: Display3.Mask; w, h, j, i: SIGNED16; dx, dy, y, x, sat, hue, r, g, b: FLOAT32;
	BEGIN
		Gadgets.MakePrinterMask(disc, msg.x, msg.y, msg.dlink, mask);
		w := SHORT(disc.W * Display.Unit DIV Printer.Unit);
		h := SHORT(disc.H * Display.Unit DIV Printer.Unit);
		Printer3.ReplConst(mask, disc.bg, msg.x, msg.y, w, h, Display.replace);
		dx := 2/w; dy := 2/h;
		j := 0; y := -1.0;
		WHILE j < h DO
			i := 0; x := -1.0;
			WHILE i < w DO
				IF Display3.Visible(mask, msg.x + i, msg.y + j, 1, 1) THEN
					sat := Math.sqrt(x * x + y * y);
					IF sat <= 1 THEN
						hue := atan2(x, y) * (1/(2*Math.pi));
						Colors.HSVToRGB(hue, sat, 1.0, r, g, b);
						Printer.UseColor(SHORT(ENTIER(255*r)), SHORT(ENTIER(255*g)), SHORT(ENTIER(255*b)));
						Printer.ReplConst(msg.x + i, msg.y + j, 1, 1)
					END;
					INC(i); x := x + dx
				END;
				INC(j); y := y + dy
			END
		END;
		IF Gadgets.selected IN disc.state THEN
			Printer3.FillPattern(mask, Display3.white, Display3.selectpat, msg.x, msg.y, msg.x, msg.y, w, h, Display.paint)
		END
	END PrintDisc;

	PROCEDURE UpdateDisc (disc: Disc; VAR msg: Display.FrameMsg);
		VAR hue, sat: FLOAT32; fld: ARRAY 32 OF CHAR; fx, fy: SIGNED16; mask: Display3.Mask;
	BEGIN
		IF disc.obj # NIL THEN
			hue := disc.hue; sat := disc.sat;
			Attributes.GetString(disc, "HueField", fld); Attributes.GetReal(disc.obj, fld, hue);
			Attributes.GetString(disc, "SatField", fld); Attributes.GetReal(disc.obj, fld, sat);
			IF (hue # disc.hue) OR (sat # disc.sat) THEN
				disc.hue := hue; disc.sat := sat;
				fx := msg.x + disc.X; fy := msg.y + disc.Y;
				Gadgets.MakeMask(disc, fx, fy, msg.dlink, mask);
				RestoreDisc(disc, fx, fy, mask)
			END
		END
	END UpdateDisc;

	PROCEDURE DiscAttr (disc: Disc; VAR msg: Objects.AttrMsg);
	BEGIN
		IF msg.id = Objects.enum THEN
			msg.Enum("BGColor"); msg.Enum("Hue"); msg.Enum("Saturation");
			msg.Enum("HueField"); msg.Enum("SatField");
			Gadgets.framehandle(disc, msg)
		ELSIF msg.id = Objects.get THEN
			IF msg.name = "Gen" THEN
				msg.class := Objects.String; msg.s := "ColorGadgets.NewDisc"; msg.res := 0
			ELSIF msg.name = "BGColor" THEN
				msg.class := Objects.Int; msg.i := disc.bg; msg.res := 0
			ELSIF msg.name = "Hue" THEN
				msg.class := Objects.Real; msg.x := disc.hue; msg.res := 0
			ELSIF msg.name = "Saturation" THEN
				msg.class := Objects.Real; msg.x := disc.sat; msg.res := 0
			ELSE
				Gadgets.framehandle(disc, msg);
				IF msg.res < 0 THEN
					IF msg.name = "HueField" THEN msg.class := Objects.String; msg.s := "HueSV"; msg.res := 0
					ELSIF msg.name = "SatField" THEN msg.class := Objects.String; msg.s := "HSaturationV"; msg.res := 0
					END
				END
			END
		ELSIF msg.id = Objects.set THEN
			IF msg.name = "BGColor" THEN
				IF (msg.class = Objects.Int) & (msg.i < 256) THEN disc.bg := msg.i; msg.res := 0; disc.img := NIL END
			ELSIF msg.name = "Hue" THEN
				IF (msg.class = Objects.Int) & (0 <= msg.i) & (msg.i <= 1) THEN disc.hue := msg.i; msg.res := 0
				ELSIF (msg.class = Objects.Real) & (0 <= msg.x) & (msg.x <= 1) THEN disc.hue := msg.x; msg.res := 0
				ELSIF (msg.class = Objects.LongReal) & (0 <= msg.y) & (msg.y <= 1) THEN disc.hue := SHORT(msg.y); msg.res := 0
				ELSIF msg.class = Objects.String THEN
					Strings.StrToReal(msg.s, msg.y);
					IF (0 <= msg.y) & (msg.y <= 1) THEN disc.hue := SHORT(msg.y); msg.res := 0 END
				END;
				IF (msg.res >= 0) & (disc.obj # NIL) THEN
					UpdateDiscModel(disc)
				END
			ELSIF msg.name = "Saturation" THEN
				IF (msg.class = Objects.Int) & (0 <= msg.i) & (msg.i <= 1) THEN disc.sat := msg.i; msg.res := 0
				ELSIF (msg.class = Objects.Real) & (0 <= msg.x) & (msg.x <= 1) THEN disc.sat := msg.x; msg.res := 0
				ELSIF (msg.class = Objects.LongReal) & (0 <= msg.y) & (msg.y <= 1) THEN disc.sat := SHORT(msg.y); msg.res := 0
				ELSIF msg.class = Objects.String THEN
					Strings.StrToReal(msg.s, msg.y);
					IF (0 <= msg.y) & (msg.y <= 1) THEN disc.sat := SHORT(msg.y); msg.res := 0 END
				END;
				IF (msg.res >= 0) & (disc.obj # NIL) THEN
					UpdateDiscModel(disc)
				END
			ELSE
				Gadgets.framehandle(disc, msg)
			END
		END
	END DiscAttr;

	PROCEDURE CopyDisc* (VAR msg: Objects.CopyMsg; from, to: Disc);
	BEGIN
		Gadgets.CopyFrame(msg, from, to);
		to.bg := from.bg; to.hue := from.hue; to.sat := from.sat; to.img := NIL
	END CopyDisc;

	PROCEDURE HandleDisc* (obj: Objects.Object; VAR msg: Objects.ObjMsg);
		VAR disc, copy: Disc; fx, fy: SIGNED16; mask: Display3.Mask; ver: SIGNED32;
	BEGIN
		disc := obj(Disc);
		IF msg IS Display.FrameMsg THEN
			WITH msg: Display.FrameMsg DO
				IF (msg.F = NIL) OR (msg.F = disc) THEN
					IF msg IS Oberon.InputMsg THEN
						WITH msg: Oberon.InputMsg DO
							IF (msg.id = Oberon.track) & (msg.keys = {1}) & ~(Gadgets.selected IN disc.state) &
								Gadgets.InActiveArea(disc, msg)
							THEN
								TrackDisc(disc, msg)
							ELSE
								Gadgets.framehandle(disc, msg)
							END
						END
					ELSIF msg IS Display.DisplayMsg THEN
						WITH msg: Display.DisplayMsg DO
							IF msg.device = Display.screen THEN
								fx := msg.x + disc.X; fy := msg.y + disc.Y;
								IF msg.id = Display.full THEN
									Gadgets.MakeMask(disc, fx, fy, msg.dlink, mask);
									RestoreDisc(disc, fx, fy, mask)
								ELSIF msg.id = Display.area THEN
									Gadgets.MakeMask(disc, fx, fy, msg.dlink, mask);
									Display3.AdjustMask(mask, fx + msg.u, fy + (disc.H-1) + msg.v, msg.w, msg.h);
									RestoreDisc(disc, fx, fy, mask)
								END
							ELSIF msg.device = Display.printer THEN
								PrintDisc(disc, msg)
							END
						END
					ELSIF msg IS Gadgets.UpdateMsg THEN
						WITH msg: Gadgets.UpdateMsg DO
							IF msg.obj = disc.obj THEN
								UpdateDisc(disc, msg)
							ELSIF msg.obj = disc THEN
								fx := msg.x + disc.X; fy := msg.y + disc.Y;
								Gadgets.MakeMask(disc, fx, fy, msg.dlink, mask);
								RestoreDisc(disc, fx, fy, mask)
							END
						END
					ELSIF msg IS Display.ControlMsg THEN
						WITH msg: Display.ControlMsg DO
							IF disc.obj # NIL THEN
								disc.obj.handle(disc.obj, msg)
							END;
							IF (msg.id = Display.restore) & (msg.stamp # disc.stamp) THEN
								disc.stamp := msg.stamp;
								UpdateDisc(disc, msg)
							END
						END
					ELSE
						Gadgets.framehandle(disc, msg)
					END
				END
			END
		ELSIF msg IS Objects.AttrMsg THEN
			DiscAttr(disc, msg(Objects.AttrMsg))
		ELSIF msg IS Objects.CopyMsg THEN
			WITH msg: Objects.CopyMsg DO
				IF msg.stamp # disc.stamp THEN
					NEW(copy); disc.dlink := copy; disc.stamp := msg.stamp;
					CopyDisc(msg, disc, copy)
				END;
				msg.obj := disc.dlink
			END
		ELSIF msg IS Objects.FileMsg THEN
			WITH msg: Objects.FileMsg DO
				Gadgets.framehandle(disc, msg);
				IF msg.id = Objects.store THEN
					Files.WriteNum(msg.R, 1);
					Files.WriteLInt(msg.R, disc.bg);
					Files.WriteReal(msg.R, disc.hue); Files.WriteReal(msg.R, disc.sat)
				ELSIF msg.id = Objects.load THEN
					Files.ReadNum(msg.R, ver);
					Files.ReadLInt(msg.R, disc.bg);
					Files.ReadReal(msg.R, disc.hue); Files.ReadReal(msg.R, disc.sat);
					disc.img := NIL
				END
			END
		ELSE
			Gadgets.framehandle(disc, msg)
		END
	END HandleDisc;

	PROCEDURE NewDisc*;
		VAR disc: Disc;
	BEGIN
		NEW(disc); disc.handle := HandleDisc; disc.W := 100; disc.H := 100; disc.bg := Display3.groupC;
		Objects.NewObj := disc
	END NewDisc;


	(**--- Wedges ---**)

	PROCEDURE GetWedgeCoords (wedge: Wedge; VAR x, y: SIGNED16);
	BEGIN
		IF wedge.hue < 0 THEN
			x := 0
		ELSE
			x := SHORT(ENTIER(wedge.sat * wedge.val * wedge.W))
		END;
		y := SHORT(ENTIER(wedge.val * wedge.H - 0.001))
	END GetWedgeCoords;

	PROCEDURE UpdateWedgeModel (wedge: Wedge);
		VAR am: Objects.AttrMsg;
	BEGIN
		IF wedge.obj # NIL THEN
			Attributes.GetString(wedge, "SatField", am.name);
			am.id := Objects.set; am.class := Objects.Real; am.x := wedge.sat; am.res := -1; wedge.obj.handle(wedge.obj, am);
			IF am.res >= 0 THEN
				Attributes.GetString(wedge, "ValueField", am.name);
				am.id := Objects.set; am.class := Objects.Real; am.x := wedge.val; am.res := -1; wedge.obj.handle(wedge.obj, am);
				IF am.res >= 0 THEN
					Gadgets.Update(wedge.obj)
				END
			END
		END
	END UpdateWedgeModel;

	PROCEDURE TrackWedge (wedge: Wedge; VAR msg: Oberon.InputMsg);
		VAR fx, fy, px, py, mx, my, x, y: SIGNED16; mask: Display3.Mask; sat, val: FLOAT32; keysum, keys: SET;
	BEGIN
		fx := msg.x + wedge.X; fy := msg.y + wedge.Y;
		Gadgets.MakeMask(wedge, fx, fy, msg.dlink, mask);
		GetWedgeCoords(wedge, px, py);
		sat := wedge.sat; val := wedge.val;
		keysum := msg.keys; mx := -1; my := -1;
		REPEAT
			Input.Mouse(keys, x, y); keysum := keysum + keys;
			IF (keys # {}) & ((x # mx) OR (y # my)) THEN
				RestoreImageRect(wedge.img, px-2, py-2, 5, 5, fx, fy, mask);
				wedge.val := (y - fy)/wedge.H;
				IF wedge.val < 0.001 THEN wedge.val := 0.001
				ELSIF wedge.val > 1 THEN wedge.val := 1
				END;
				IF wedge.hue < 0 THEN
					wedge.sat := 0
				ELSE
					wedge.sat := (x - fx)/(wedge.val * wedge.W);
					IF wedge.sat < 0.001 THEN wedge.sat := 0.001
					ELSIF wedge.sat > 1 THEN wedge.sat := 1
					END
				END;
				UpdateWedgeModel(wedge);
				GetWedgeCoords(wedge, px, py);
				Display3.Rect(mask, Display3.black, Display.solid, fx + px - 2, fy + py - 2, 5, 5, 1, Display.replace);
				mx := x; my := y;
				Oberon.DrawCursor(Oberon.Mouse, Effects.Arrow, x, y)
			END
		UNTIL keys = {};
		IF keysum = {0..2} THEN
			RestoreImageRect(wedge.img, px-2, py-2, 5, 5, fx, fy, mask);
			wedge.sat := sat; wedge.val := val;
			GetWedgeCoords(wedge, px, py);
			Display3.Rect(mask, Display3.black, Display.solid, fx + px - 2, fy + py - 2, 5, 5, 1, Display.replace);
			UpdateWedgeModel(wedge)
		END;
		Oberon.DrawCursor(Oberon.Mouse, Effects.Arrow, x, y);
		msg.res := 0
	END TrackWedge;

	PROCEDURE RestoreWedgeImage (wedge: Wedge);
		VAR r, g, b, j, i: SIGNED16; bg, pix: Images.Pixel; val, dval, sat, dsat, rr, gg, bb: FLOAT32;
	BEGIN
		IF wedge.img = NIL THEN
			NEW(wedge.img)
		END;
		IF (wedge.img.width # wedge.W) OR (wedge.img.height # wedge.H) THEN
			Images.Create(wedge.img, wedge.W, wedge.H, Images.DisplayFormat);
			Display.GetColor(wedge.bg, r, g, b); Images.SetRGB(bg, r, g, b);
			Images.Fill(wedge.img, 0, 0, wedge.W, wedge.H, bg, Images.SrcCopy);
			j := 0; val := 0; dval := 1/wedge.H;
			WHILE j < wedge.H DO
				IF wedge.hue < 0 THEN
					g := SHORT(ENTIER(255*val));
					Images.SetRGB(pix, g, g, g);
					i := 1 + SHORT(LONG(j) * (wedge.W-1) DIV wedge.H);
					Images.Fill(wedge.img, 0, j, i, j+1, pix, Images.SrcCopy)
				ELSE
					i := 0; sat := 0; dsat := 1/(wedge.W * val);
					WHILE sat <= 1 DO
						Colors.HSVToRGB(wedge.hue, sat, val, rr, gg, bb);
						r := SHORT(ENTIER(255*rr)); g := SHORT(ENTIER(255*gg)); b := SHORT(ENTIER(255*bb));
						Images.SetRGB(pix, r, g, b);
						Images.Put(wedge.img, i, j, pix, Images.SrcCopy);
						INC(i); sat := sat + dsat
					END;
					IF i < wedge.img.width THEN
						Images.Put(wedge.img, i, j, bg, Images.SrcCopy)
					END
				END;
				INC(j); val := val + dval
			END
		END
	END RestoreWedgeImage;

	PROCEDURE RestoreWedge (wedge: Wedge; fx, fy: SIGNED16; mask: Display3.Mask);
		VAR x, y: SIGNED16;
	BEGIN
		RestoreWedgeImage(wedge);
		RestoreImageRect(wedge.img, 0, 0, wedge.W, wedge.H, fx, fy, mask);
		GetWedgeCoords(wedge, x, y);
		Display3.Rect(mask, Display3.black, Display.solid, fx + x - 2, fy + y - 2, 5, 5, 1, Display.replace);
		IF Gadgets.selected IN wedge.state THEN
			Display3.FillPattern(mask, Display3.white, Display3.selectpat, fx, fy, fx, fy, wedge.W, wedge.H, Display.paint)
		END
	END RestoreWedge;

	PROCEDURE PrintWedge (wedge: Wedge; VAR msg: Display.DisplayMsg);
		VAR mask: Display3.Mask; w, h, j, i, x0, x1: SIGNED16; val, dval, sat, dsat, r, g, b: FLOAT32;
	BEGIN
		Gadgets.MakePrinterMask(wedge, msg.x, msg.y, msg.dlink, mask);
		w := SHORT(wedge.W * Display.Unit DIV Printer.Unit);
		h := SHORT(wedge.H * Display.Unit DIV Printer.Unit);
		Printer3.ReplConst(mask, wedge.bg, msg.x, msg.y, w, h, Display.replace);
		j := 0; val := 0; dval := 1/h;
		WHILE j < h DO
			IF wedge.hue < 0 THEN
				i := SHORT(ENTIER(255*val));
				Printer.UseColor(i, i, i);
				i := 1 + SHORT(LONG(j) * (w-1) DIV h);
				IF Display3.Visible(mask, msg.x, msg.y + j, i, 1) THEN
					Printer.ReplConst(msg.x, msg.y + j, i, 1)
				ELSE
					x0 := 0;
					REPEAT
						WHILE (x0 < i) & ~Display3.Visible(mask, msg.x + x0, msg.y + j, 1, 1) DO INC(x0) END;
						x1 := x0; WHILE (x1 < i) & Display3.Visible(mask, msg.x + x1, msg.y + j, 1, 1) DO INC(x1) END;
						IF x0 < x1 THEN
							Printer.ReplConst(msg.x + x0, msg.y + j, x1 - x0, 1)
						END;
						x0 := x1
					UNTIL x0 >= i
				END
			ELSE
				i := 0; sat := 0; dsat := 1/(w * val);
				WHILE sat <= 1 DO
					IF Display3.Visible(mask, msg.x + i, msg.y + j, 1, 1) THEN
						Colors.HSVToRGB(wedge.hue, sat, val, r, g, b);
						Printer.UseColor(SHORT(ENTIER(255*r)), SHORT(ENTIER(255*g)), SHORT(ENTIER(255*b)));
						Printer.ReplConst(msg.x + i, msg.y + j, 1, 1)
					END;
					INC(i); sat := sat + dsat
				END
			END;
			INC(j); val := val + dval
		END;
		IF Gadgets.selected IN wedge.state THEN
			Printer3.FillPattern(mask, Display3.white, Display3.selectpat, msg.x, msg.y, msg.x, msg.y, w, h, Display.paint)
		END
	END PrintWedge;

	PROCEDURE UpdateWedge (wedge: Wedge; VAR msg: Display.FrameMsg);
		VAR hue, sat, val: FLOAT32; fld: ARRAY 32 OF CHAR; fx, fy: SIGNED16; mask: Display3.Mask;
	BEGIN
		IF wedge.obj # NIL THEN
			hue := wedge.hue; sat := wedge.sat; val := wedge.val;
			Attributes.GetString(wedge, "HueField", fld); Attributes.GetReal(wedge.obj, fld, hue);
			Attributes.GetString(wedge, "SatField", fld); Attributes.GetReal(wedge.obj, fld, sat);
			Attributes.GetString(wedge, "ValueField", fld); Attributes.GetReal(wedge.obj, fld, val);
			IF (hue # wedge.hue) OR (sat # wedge.sat) OR (val # wedge.val) THEN
				IF hue # wedge.hue THEN
					wedge.hue := hue; wedge.img := NIL
				END;
				wedge.sat := sat; wedge.val := val;
				fx := msg.x + wedge.X; fy := msg.y + wedge.Y;
				Gadgets.MakeMask(wedge, fx, fy, msg.dlink, mask);
				RestoreWedge(wedge, fx, fy, mask)
			END
		END
	END UpdateWedge;

	PROCEDURE WedgeAttr* (wedge: Wedge; VAR msg: Objects.AttrMsg);
	BEGIN
		IF msg.id = Objects.enum THEN
			msg.Enum("BGColor"); msg.Enum("Saturation"); msg.Enum("Value");
			msg.Enum("HueField"); msg.Enum("SatField"); msg.Enum("ValueField");
			Gadgets.framehandle(wedge, msg)
		ELSIF msg.id = Objects.get THEN
			IF msg.name = "Gen" THEN
				msg.class := Objects.String; msg.s := "ColorGadgets.NewWedge"; msg.res := 0
			ELSIF msg.name = "BGColor" THEN
				msg.class := Objects.Int; msg.i := wedge.bg; msg.res := 0
			ELSIF msg.name = "Saturation" THEN
				msg.class := Objects.Real; msg.x := wedge.sat; msg.res := 0
			ELSIF msg.name = "Value" THEN
				msg.class := Objects.Real; msg.x := wedge.val; msg.res := 0
			ELSE
				Gadgets.framehandle(wedge, msg);
				IF msg.res < 0 THEN
					IF msg.name = "HueField" THEN msg.class := Objects.String; msg.s := "HueSV"; msg.res := 0
					ELSIF msg.name = "SatField" THEN msg.class := Objects.String; msg.s := "HSaturationV"; msg.res := 0
					ELSIF msg.name = "ValueField" THEN msg.class := Objects.String; msg.s := "HSValue"; msg.res := 0
					END
				END
			END
		ELSIF msg.id = Objects.set THEN
			IF msg.name = "BGColor" THEN
				IF (msg.class = Objects.Int) & (msg.i < 256) THEN wedge.bg := msg.i; msg.res := 0; wedge.img := NIL END
			ELSIF msg.name = "Saturation" THEN
				IF (msg.class = Objects.Int) & (0 <= msg.i) & (msg.i <= 1) THEN wedge.sat := msg.i; msg.res := 0
				ELSIF (msg.class = Objects.Real) & (0 <= msg.x) & (msg.x <= 1) THEN wedge.sat := msg.x; msg.res := 0
				ELSIF (msg.class = Objects.LongReal) & (0 <= msg.y) & (msg.y <= 1) THEN wedge.sat := SHORT(msg.y); msg.res := 0
				ELSIF msg.class = Objects.String THEN
					Strings.StrToReal(msg.s, msg.y);
					IF (0 <= msg.y) & (msg.y <= 1) THEN wedge.sat := SHORT(msg.y); msg.res := 0 END
				END;
				IF (msg.res >= 0) & (wedge.obj # NIL) THEN
					UpdateWedgeModel(wedge)
				END
			ELSIF msg.name = "Value" THEN
				IF (msg.class = Objects.Int) & (0 <= msg.i) & (msg.i <= 1) THEN wedge.val := msg.i; msg.res := 0
				ELSIF (msg.class = Objects.Real) & (0 <= msg.x) & (msg.x <= 1) THEN wedge.val := msg.x; msg.res := 0
				ELSIF (msg.class = Objects.LongReal) & (0 <= msg.y) & (msg.y <= 1) THEN wedge.val := SHORT(msg.y); msg.res := 0
				ELSIF msg.class = Objects.String THEN
					Strings.StrToReal(msg.s, msg.y);
					IF (0 <= msg.y) & (msg.y <= 1) THEN wedge.val := SHORT(msg.y); msg.res := 0 END
				END;
				IF (msg.res >= 0) & (wedge.obj # NIL) THEN
					UpdateWedgeModel(wedge)
				END
			ELSE
				Gadgets.framehandle(wedge, msg)
			END
		END
	END WedgeAttr;

	PROCEDURE CopyWedge* (VAR msg: Objects.CopyMsg; from, to: Wedge);
	BEGIN
		Gadgets.CopyFrame(msg, from, to);
		to.bg := from.bg; to.hue := from.hue; to.sat := from.sat; to.val := from.val; to.img := NIL
	END CopyWedge;

	PROCEDURE HandleWedge* (obj: Objects.Object; VAR msg: Objects.ObjMsg);
		VAR wedge, copy: Wedge; fx, fy: SIGNED16; mask: Display3.Mask; ver: SIGNED32;
	BEGIN
		wedge := obj(Wedge);
		IF msg IS Display.FrameMsg THEN
			WITH msg: Display.FrameMsg DO
				IF (msg.F = NIL) OR (msg.F = wedge) THEN
					IF msg IS Oberon.InputMsg THEN
						WITH msg: Oberon.InputMsg DO
							IF (msg.id = Oberon.track) & (msg.keys = {1}) & ~(Gadgets.selected IN wedge.state) &
								Gadgets.InActiveArea(wedge, msg)
							THEN
								TrackWedge(wedge, msg)
							ELSE
								Gadgets.framehandle(wedge, msg)
							END
						END
					ELSIF msg IS Display.DisplayMsg THEN
						WITH msg: Display.DisplayMsg DO
							IF msg.device = Display.screen THEN
								fx := msg.x + wedge.X; fy := msg.y + wedge.Y;
								IF msg.id = Display.full THEN
									Gadgets.MakeMask(wedge, fx, fy, msg.dlink, mask);
									RestoreWedge(wedge, fx, fy, mask)
								ELSIF msg.id = Display.area THEN
									Gadgets.MakeMask(wedge, fx, fy, msg.dlink, mask);
									Display3.AdjustMask(mask, fx + msg.u, fy + (wedge.H-1) + msg.v, msg.w, msg.h);
									RestoreWedge(wedge, fx, fy, mask)
								END
							ELSIF msg.device = Display.printer THEN
								PrintWedge(wedge, msg)
							END
						END
					ELSIF msg IS Gadgets.UpdateMsg THEN
						WITH msg: Gadgets.UpdateMsg DO
							IF msg.obj = wedge.obj THEN
								UpdateWedge(wedge, msg)
							ELSIF msg.obj = wedge THEN
								fx := msg.x + wedge.X; fy := msg.y + wedge.Y;
								Gadgets.MakeMask(wedge, fx, fy, msg.dlink, mask);
								RestoreWedge(wedge, fx, fy, mask)
							END
						END
					ELSIF msg IS Display.ControlMsg THEN
						WITH msg: Display.ControlMsg DO
							IF wedge.obj # NIL THEN
								wedge.obj.handle(wedge.obj, msg)
							END;
							IF (msg.id = Display.restore) & (msg.stamp # wedge.stamp) THEN
								wedge.stamp := msg.stamp;
								UpdateWedge(wedge, msg)
							END
						END
					ELSE
						Gadgets.framehandle(wedge, msg)
					END
				END
			END
		ELSIF msg IS Objects.AttrMsg THEN
			WedgeAttr(wedge, msg(Objects.AttrMsg))
		ELSIF msg IS Objects.CopyMsg THEN
			WITH msg: Objects.CopyMsg DO
				IF msg.stamp # wedge.stamp THEN
					NEW(copy); wedge.dlink := copy; wedge.stamp := msg.stamp;
					CopyWedge(msg, wedge, copy)
				END;
				msg.obj := wedge.dlink
			END
		ELSIF msg IS Objects.FileMsg THEN
			WITH msg: Objects.FileMsg DO
				Gadgets.framehandle(wedge, msg);
				IF msg.id = Objects.store THEN
					Files.WriteNum(msg.R, 1);
					Files.WriteLInt(msg.R, wedge.bg);
					Files.WriteReal(msg.R, wedge.hue); Files.WriteReal(msg.R, wedge.sat); Files.WriteReal(msg.R, wedge.val)
				ELSIF msg.id = Objects.load THEN
					Files.ReadNum(msg.R, ver);
					Files.ReadLInt(msg.R, wedge.bg);
					Files.ReadReal(msg.R, wedge.hue); Files.ReadReal(msg.R, wedge.sat); Files.ReadReal(msg.R, wedge.val);
					wedge.img := NIL
				END
			END
		ELSE
			Gadgets.framehandle(wedge, msg)
		END
	END HandleWedge;

	PROCEDURE NewWedge*;
		VAR wedge: Wedge;
	BEGIN
		NEW(wedge); wedge.handle := HandleWedge; wedge.W := 50; wedge.H := 100;
		wedge.bg := Display3.groupC; wedge.hue := -1;
		Objects.NewObj := wedge
	END NewWedge;


	(**--- Commands ---**)

	(** set selected text color **)
	PROCEDURE SetText*;
		VAR text: Texts.Text; beg, end, time: SIGNED32; s: Attributes.Scanner; r, g, b, col: SIGNED16;
	BEGIN
		Oberon.GetSelection(text, beg, end, time);
		IF time # -1 THEN
			Attributes.OpenScanner(s, Oberon.Par.text, Oberon.Par.pos); Attributes.Scan(s);
			IF s.class = Attributes.Int THEN
				IF s.i < 0 THEN
					Display.GetColor(s.i, r, g, b);
					col := SHORT(Colors.Match(Colors.DisplayIndex, Colors.DisplayBits, r, g, b))
				ELSE
					col := SHORT(s.i)
				END;
				Texts.ChangeLooks(text, beg, end, {1}, NIL, SHORT(col), 0)
			END
		END
	END SetText;

	(** get color of selected text and store it in attribute (2.) of named (1.) object **)
	PROCEDURE GetText*;
		VAR
			text: Texts.Text; beg, end, time: SIGNED32; r: Texts.Reader; ch: CHAR; s: Attributes.Scanner;
			obj: Objects.Object; am: Objects.AttrMsg;
	BEGIN
		Oberon.GetSelection(text, beg, end, time);
		IF time # -1 THEN
			Texts.OpenReader(r, text, beg); Texts.Read(r, ch);
			Attributes.OpenScanner(s, Oberon.Par.text, Oberon.Par.pos); Attributes.Scan(s);
			IF s.class IN {Attributes.Name, Attributes.String} THEN
				obj := Gadgets.FindObj(Gadgets.context, s.s);
				IF obj # NIL THEN
					Attributes.Scan(s);
					IF s.class IN {Attributes.Name, Attributes.String} THEN
						am.id := Objects.set; COPY(s.s, am.name); am.class := Objects.Int; am.res := -1;
						obj.handle(obj, am);
						IF am.res >= 0 THEN
							Gadgets.Update(obj)
						END
					END
				END
			END
		END
	END GetText;

	(** set attribute (1.) of selected objects to color value (2.) **)
	PROCEDURE SetAttr*;
		VAR sel: Objects.Object; time: SIGNED32; s: Attributes.Scanner; am: Objects.AttrMsg; r, g, b: SIGNED16;
	BEGIN
		Gadgets.GetSelection(sel, time);
		IF (time # -1) & (sel # NIL) THEN
			Attributes.OpenScanner(s, Oberon.Par.text, Oberon.Par.pos); Attributes.Scan(s);
			IF s.class IN {Attributes.Name, Attributes.String} THEN
				COPY(s.s, am.name); Attributes.Scan(s);
				IF s.class = Attributes.Int THEN
					am.id := Objects.set; am.class := Objects.Int; am.i := s.i;
					REPEAT
						am.i := s.i; am.res := -1; sel.handle(sel, am);
						IF (am.res < 0) & (s.i < 0) THEN
							Display.GetColor(s.i, r, g, b);
							am.i := Colors.Match(Colors.DisplayIndex, Colors.DisplayBits, r, g, b);
							sel.handle(sel, am)
						END;
						IF am.res >= 0 THEN
							Gadgets.Update(sel)
						END;
						sel := sel.slink
					UNTIL sel = NIL
				END
			END
		END
	END SetAttr;

	(** get attribute (1.) of selected objects and set attribute (3.) of named (2.) object **)
	PROCEDURE GetAttr*;
		VAR sel, obj: Objects.Object; time, col: SIGNED32; s: Attributes.Scanner; am: Objects.AttrMsg;
	BEGIN
		Gadgets.GetSelection(sel, time);
		IF (time # -1) & (sel # NIL) THEN
			Attributes.OpenScanner(s, Oberon.Par.text, Oberon.Par.pos); Attributes.Scan(s);
			IF s.class IN {Attributes.Name, Attributes.String} THEN
				am.id := Objects.get; COPY(s.s, am.name); am.class := Objects.Inval; am.res := -1; sel.handle(sel, am);
				IF (am.res >= 0) & (am.class = Objects.Int) THEN
					col := am.i; Attributes.Scan(s);
					IF s.class IN {Attributes.Name, Attributes.String} THEN
						obj := Gadgets.FindObj(Gadgets.context, s.s);
						IF obj # NIL THEN
							Attributes.Scan(s);
							IF s.class IN {Attributes.Name, Attributes.String} THEN
								am.id := Objects.set; COPY(s.s, am.name); am.class := Objects.Int; am.i := col; am.res := -1;
								obj.handle(obj, am);
								IF am.res >= 0 THEN
									Gadgets.Update(obj)
								END
							END
						END
					END
				END
			END
		END
	END GetAttr;


BEGIN
	InitDragMarker;
END ColorGadgets.

System.Free ColorGadgets ~

Gadgets.Insert ColorGadgets.NewWell ~
Gadgets.Insert ColorGadgets.NewWell BasicGadgets.NewInteger ~
Gadgets.Insert ColorGadgets.NewWell Colors.New ~

Gadgets.Insert ColorGadgets.NewDisc ~
Gadgets.Insert ColorGadgets.NewDisc Colors.New ~

Gadgets.Insert ColorGadgets.NewWedge ~
Gadgets.Insert ColorGadgets.NewWedge Colors.New ~

