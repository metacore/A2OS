(* ETH Oberon, Copyright 2001 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

MODULE ImageGadgets IN Oberon; (** portable **)	(* eos  *)

	(**
		Frame displaying a raster image
	**)

	(*
		11.04.2000 - fixed bug in PrintRect: didn't handle transparent images
		24.05.2000 - RestoreRuns: fixed infinite loop with transparent images; improved transparency handling
	*)

	IMPORT
		Files, Display, Printer, Objects, Fonts, Oberon, Display3, Printer3, Gadgets, Colors, Images;


	CONST
		buffered* = 0; dithered* = 1;	(** available options **)


	TYPE
		(** frame **)
		Frame* = POINTER TO FrameDesc;
		FrameDesc* = RECORD (Gadgets.FrameDesc)
			options*: SET;	(** adjust udpate and resize behaviour **)
			cache: Images.Image;	(* displayed image (in display format) *)
		END;


	VAR
		Enum: RECORD
			img: Images.Image;
			x, y: SIGNED16;	(* map origin on device *)
		END;


	(*--- Image Cache ---*)

	PROCEDURE ValidateCache (frame: Frame);
		VAR img: Images.Image; bg: Images.Pixel;
	BEGIN
		IF (buffered IN frame.options) & (frame.obj # NIL) & (frame.cache = NIL) THEN
			img := frame.obj(Images.Image);
			IF Images.Same(img.fmt, Images.DisplayFormat) OR (img.width * img.height = 0) THEN
				frame.cache := img
			ELSE
				NEW(frame.cache); Images.Create(frame.cache, img.width, img.height, Images.DisplayFormat);
				IF dithered IN frame.options THEN
					Images.Dither(img, frame.cache)
				ELSIF (Images.alpha IN img.fmt.components) & ~(Images.alpha IN frame.cache.fmt.components) THEN
					Images.SetRGB(bg, Colors.Red[Display3.textbackC], Colors.Green[Display3.textbackC], Colors.Blue[Display3.textbackC]);
					Images.Fill(frame.cache, 0, 0, img.width, img.height, bg, Images.SrcCopy);
					Images.Copy(img, frame.cache, 0, 0, img.width, img.height, 0, 0, Images.SrcOverDst)
				ELSE
					Images.Copy(img, frame.cache, 0, 0, img.width, img.height, 0, 0, Images.SrcCopy)
				END
			END
		END
	END ValidateCache;

	PROCEDURE UpdateCache (frame: Frame; llx, lly, urx, ury: SIGNED16);
		VAR img: Images.Image; bg: Images.Pixel;
	BEGIN
		IF (buffered IN frame.options) & (frame.obj # NIL) THEN
			img := frame.obj(Images.Image);
			IF frame.cache = NIL THEN
				ValidateCache(frame)
			ELSIF ~Images.Same(img.fmt, Images.DisplayFormat) THEN
				IF dithered IN frame.options THEN
					Images.Dither(img, frame.cache)
				ELSE
					IF llx < 0 THEN llx := 0 END;
					IF lly < 0 THEN lly := 0 END;
					IF urx > img.width THEN urx := img.width END;
					IF ury > img.height THEN ury := img.height END;
					IF (Images.alpha IN img.fmt.components) & ~(Images.alpha IN frame.cache.fmt.components) THEN
						Images.SetRGB(bg, Colors.Red[Display3.textbackC], Colors.Green[Display3.textbackC], Colors.Blue[Display3.textbackC]);
						Images.Fill(frame.cache, llx, lly, urx, ury, bg, Images.SrcCopy);
						Images.Copy(img, frame.cache, llx, lly, urx, ury, llx, lly, Images.SrcOverDst)
					ELSE
						Images.Copy(img, frame.cache, llx, lly, urx, ury, llx, lly, Images.SrcCopy)
					END
				END
			END
		END
	END UpdateCache;


	PROCEDURE RestoreRuns (x, y, w, h: SIGNED16);
		VAR x0, len, l, i, j: SIGNED16; line: ARRAY 512 OF CHAR; b: CHAR;
	BEGIN
		x0 := x;
		WHILE h > 0 DO
			x := x0; len := w;
			REPEAT
				IF len < LEN(line) THEN l := len ELSE l := LEN(line) END;
				IF Images.alpha IN Enum.img.fmt.components THEN
					i := 0; WHILE i < l DO line[i] := CHR(Display3.textbackC); INC(i) END
				END;
				Images.GetPixels(Enum.img, x - Enum.x, y - Enum.y, l, Images.D8, line, Images.SrcOverDst);
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

	PROCEDURE RestoreLines (x, y, w, h: SIGNED16);
		VAR x0, lineLen, len, l: SIGNED16; line: ARRAY 512 OF CHAR; tmp: Images.Image; bg: Images.Pixel;
	BEGIN
		x0 := x; lineLen := 8*LEN(line) DIV Images.DisplayFormat.bpp;
		NEW(tmp); Images.InitBuf(tmp, lineLen, 1, Images.DisplayFormat, 0, 0, line);
		Images.SetRGB(bg, Colors.Red[Display3.textbackC], Colors.Green[Display3.textbackC], Colors.Blue[Display3.textbackC]);
		WHILE h > 0 DO
			x := x0; len := w;
			REPEAT
				IF len < lineLen THEN l := len ELSE l := lineLen END;
				IF Images.alpha IN Enum.img.fmt.components THEN
					Display.TransferBlock(line, 0, 0, x, y, l, 1, Display.get)
				END;
				Images.GetPixels(Enum.img, x - Enum.x, y - Enum.y, l, Images.DisplayFormat, line, Images.SrcOverDst);
				Display.TransferBlock(line, 0, 0, x, y, l, 1, Display.set);
				INC(x, l); DEC(len, l)
			UNTIL len = 0;
			DEC(h); INC(y)
		END
	END RestoreLines;

	PROCEDURE RestoreBlock (x, y, w, h: SIGNED16);
		VAR offset: SIGNED32;
	BEGIN
		offset := (y - Enum.y) * Enum.img.bpr + (x - Enum.x) * Enum.img.fmt.bpp DIV 8;
		Display.TransferBlock(Enum.img.mem^, offset, Enum.img.bpr, x, y, w, h, Display.set)
	END RestoreBlock;

	(** restore frame area **)
	PROCEDURE Restore* (frame: Frame; x, y, w, h, fx, fy: SIGNED16; mask: Display3.Mask);
		VAR img: Images.Image; rx, ry, rw, rh, th: SIGNED16;
	BEGIN
		Oberon.RemoveMarks(fx + x, fy + y, w, h);
		IF frame.obj = NIL THEN
			Display3.ReplConst(mask, Display3.textbackC, fx + x, fy + y, w, h, Display.replace);
			Display3.CenterString(mask, Display3.textC, fx, fy, frame.W, frame.H, Fonts.Default, "No Model", Display.paint)
		ELSE
			IF buffered IN frame.options THEN ValidateCache(frame); img := frame.cache
			ELSE img := frame.obj(Images.Image)
			END;
			rx := fx + x; ry := fy + y; rw := w; rh := h;
			IF ~(Gadgets.transparent IN frame.state) THEN
				IF x + w > img.width THEN
					Display3.ReplConst(mask, Display3.textbackC, fx + img.width, ry, x + w - img.width, rh, Display.replace);
					rw := img.width - x
				END;
				th := frame.H - y - img.height;
				IF th > 0 THEN
					Display3.ReplConst(mask, Display3.textbackC, rx, ry, rw, th, Display3.replace);
					DEC(rh, th); INC(ry, th)
				END
			END;
			IF rx < mask.X THEN DEC(rw, mask.X - rx); rx := mask.X END;
			IF rx + rw > mask.X + mask.W THEN rw := mask.X + mask.W - rx END;
			IF ry < mask.Y THEN DEC(rh, mask.Y - ry); ry := mask.Y END;
			IF ry + rh > mask.Y + mask.H THEN rh := mask.Y + mask.H - ry END;
			IF (rw > 0) & (rh > 0) THEN
				Enum.img := img; Enum.x := fx; Enum.y := fy + frame.H - img.height;
				IF Display.TransferFormat(fx) = Display.unknown THEN	(* can't use TransferBlock *)
					Display3.EnumRect(mask, rx, ry, rw, rh, RestoreRuns)
				ELSIF Images.Same(Images.DisplayFormat, img.fmt) & (img.mem # NIL) & ~(Images.alpha IN img.fmt.components) THEN
					Display3.EnumRect(mask, rx, ry, rw, rh, RestoreBlock)
				ELSE	(* must convert map to display format *)
					Display3.EnumRect(mask, rx, ry, rw, rh, RestoreLines)
				END
			END
		END;
		IF Gadgets.selected IN frame.state THEN
			Display3.FillPattern(mask, Display3.white, Display3.selectpat, fx, fy, fx + x, fy + y, w, h, Display.paint)
		END
	END Restore;

	PROCEDURE PrintRect (dx, dy, dw, dh: SIGNED16);
		CONST red = Images.r; green = Images.g; blue = Images.b; alpha = Images.a;
		VAR du, pu, hpu, fy, fx: SIGNED32; sy, y, h, sx, x, w, rw: SIGNED16; col, pix: Images.Pixel;
	BEGIN
		DEC(dx, Enum.x); DEC(dy, Enum.y);
		du := Display.Unit; pu := Printer.Unit; hpu := pu DIV 2;
		sy := SHORT((dy * pu + hpu) DIV du); fy := (dy * pu + hpu) MOD du;
		y := dy; h := 0;
		REPEAT
			INC(h); INC(fy, pu);
			IF (y + h = dy + dh) OR (fy > du) THEN
				sx := SHORT((dx * pu + hpu) DIV du); fx := (dx * pu + hpu) MOD du;
				col[red] := 0FFX; col[green] := 0FFX; col[blue] := 0FFX; col[alpha] := 0FFX;
				Images.Get(Enum.img, sx, sy, col, Images.SrcOverDst);
				x := dx; w := 0; rw := 0;
				REPEAT
					INC(w); INC(fx, pu);
					IF (x + w = dx + dw) OR (fx > du) THEN
						DEC(fx, du); INC(sx);
						INC(rw, w); INC(x, w);
						IF x = dx + dw THEN
							IF col[alpha] # 0X THEN
								Printer.UseColor(ORD(col[red]), ORD(col[green]), ORD(col[blue]));
								Printer.ReplConst(Enum.x + x - rw, Enum.y + y, rw, h)
							END
						ELSE
							pix[red] := 0FFX; pix[green] := 0FFX; pix[blue] := 0FFX; pix[alpha] := 0FFX;
							Images.Get(Enum.img, sx, sy, pix, Images.SrcOverDst);
							IF (pix[red] # col[red]) OR (pix[green] # col[green]) OR (pix[blue] # col[blue]) THEN
								IF col[alpha] # 0X THEN
									Printer.UseColor(ORD(col[red]), ORD(col[green]), ORD(col[blue]));
									Printer.ReplConst(Enum.x + x - rw, Enum.y + y, rw, h)
								END;
								col := pix; rw := w
							END;
							w := 0
						END
					END
				UNTIL x = dx + dw;
				DEC(fy, du); INC(sy);
				INC(y, h); h := 0
			END
		UNTIL y = dy + dh
	END PrintRect;

	(** print frame **)
	PROCEDURE Print* (frame: Frame; VAR msg: Display.DisplayMsg);
		VAR img: Images.Image; iw, ih, w, h, rx, ry, rw, rh: SIGNED16; mask: Display3.Mask;

		PROCEDURE p (x: SIGNED16): SIGNED16;
		BEGIN
			RETURN SHORT(x * Display.Unit DIV Printer.Unit)
		END p;

	BEGIN
		IF msg.id = Display.contents THEN
			IF frame.obj # NIL THEN
				img := frame.obj(Images.Image);
				iw := p(img.width); ih := p(img.height);
				IF iw * ih # 0 THEN
					Enum.img := img; Enum.x := (Printer.Width - iw) DIV 2; Enum.y := (Printer.Height - ih) DIV 2;
					PrintRect(Enum.x, Enum.y, iw, ih)
				END;
				Printer.Page(1)
			END
		ELSE
			Gadgets.MakePrinterMask(frame, msg.x, msg.y, msg.dlink, mask);
			w := p(frame.W); h := p(frame.H);
			IF frame.obj = NIL THEN
				Printer3.ReplConst(mask, Display3.textbackC, msg.x, msg.y, w, h, Display.replace);
				Printer3.CenterString(mask, Display3.textC, msg.x, msg.y, w, h, Fonts.Default, "No Model", Display.paint)
			ELSE
				img := frame.obj(Images.Image);
				iw := p(img.width); ih := p(img.height);
				rx := msg.x; ry := msg.y; rw := w; rh := h;
				IF ~(Gadgets.transparent IN frame.state) THEN
					IF frame.W > img.width THEN
						rw := iw;
						Printer3.ReplConst(mask, Display3.textbackC, msg.x + rw, msg.y, w - rw, h, Display.replace)
					END;
					IF frame.H > img.height THEN
						rh := ih; ry := msg.y + h - rh;
						Printer3.ReplConst(mask, Display3.textbackC, msg.x, msg.y, rw, ry, Display.replace)
					END
				END;
				IF rx < mask.X THEN DEC(rw, mask.X - rx); rx := mask.X END;
				IF rx + rw > mask.X + mask.W THEN rw := mask.X + mask.W - rx END;
				IF ry < mask.Y THEN DEC(rh, mask.Y - ry); ry := mask.Y END;
				IF ry + rh > mask.Y + mask.H THEN rh := mask.Y + mask.H - ry END;
				IF (rw > 0) & (rh > 0) THEN
					Enum.img := img; Enum.x := msg.x; Enum.y := msg.y + h - ih;
					Display3.EnumRect(mask, rx, ry, rw, rh, PrintRect)
				END
			END;
			IF Gadgets.selected IN frame.state THEN
				Printer3.FillPattern(mask, Display3.white, Display3.selectpat, msg.x, msg.y, msg.x, msg.y, w, h, Display.paint)
			END
		END
	END Print;

	(** copy frame **)
	PROCEDURE Copy* (VAR msg: Objects.CopyMsg; from, to: Frame);
	BEGIN
		Gadgets.CopyFrame(msg, from, to);
		to.options := from.options;
		ValidateCache(to)
	END Copy;

	(** frame handler **)
	PROCEDURE Handle* (obj: Objects.Object; VAR msg: Objects.ObjMsg);
		VAR frame, copy: Frame; fx, fy: SIGNED16; mask: Display3.Mask; img: Images.Image; ver: SIGNED32;
	BEGIN
		frame := obj(Frame);
		IF msg IS Display.FrameMsg THEN
			WITH msg: Display.FrameMsg DO
				IF (msg.F = NIL) OR (msg.F = frame) THEN
					IF msg IS Display.DisplayMsg THEN
						WITH msg: Display.DisplayMsg DO
							IF msg.device = Display.screen THEN
								fx := msg.x + frame.X; fy := msg.y + frame.Y;
								IF (msg.id = Display.full) OR (msg.F = NIL) THEN
									Gadgets.MakeMask(frame, fx, fy, msg.dlink, mask);
									Restore(frame, 0, 0, frame.W, frame.H, fx, fy, mask)
								ELSIF msg.id = Display.area THEN
									Gadgets.MakeMask(frame, fx, fy, msg.dlink, mask);
									Display3.AdjustMask(mask, fx + msg.u, fy + (frame.H-1) + msg.v, msg.w, msg.h);
									Restore(frame, msg.u, msg.v + (frame.H-1), msg.w, msg.h, fx, fy, mask)
								END
							ELSIF msg.device = Display.printer THEN
								Print(frame, msg)
							END
						END
					ELSIF (msg IS Gadgets.UpdateMsg) & (msg(Gadgets.UpdateMsg).obj = frame.obj) THEN
						fx := msg.x + frame.X; fy := msg.y + frame.Y;
						Gadgets.MakeMask(frame, fx, fy, msg.dlink, mask);
						Restore(frame, 0, 0, frame.W, frame.H, fx, fy, mask)
					ELSIF msg IS Images.UpdateMsg THEN
						WITH msg: Images.UpdateMsg DO
							IF (msg.img = frame.obj) THEN
								fx := msg.x + frame.X; fy := msg.y + frame.Y;
								Gadgets.MakeMask(frame, fx, fy, msg.dlink, mask);
								Display3.AdjustMask(mask, fx + msg.llx, fy + frame.H - msg.img.height + msg.lly, msg.urx - msg.llx, msg.ury - msg.lly);
								UpdateCache(frame, msg.llx, msg.lly, msg.urx, msg.ury);
								Restore(frame, msg.llx, msg.lly, msg.urx - msg.llx, msg.ury - msg.lly, fx, fy, mask)
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
					Gadgets.framehandle(frame, msg);
					msg.Enum("Locked"); msg.Enum("Buffered"); msg.Enum("Dithered")
				ELSIF msg.id = Objects.get THEN
					IF msg.name = "Gen" THEN msg.class := Objects.String; msg.s := "ImageGadgets.New"; msg.res := 0
					ELSIF msg.name = "Locked" THEN msg.class := Objects.Bool; msg.b := Gadgets.lockedcontents IN frame.state; msg.res := 0
					ELSIF msg.name = "Buffered" THEN msg.class := Objects.Bool; msg.b := buffered IN frame.options; msg.res := 0
					ELSIF msg.name = "Dithered" THEN msg.class := Objects.Bool; msg.b := dithered IN frame.options; msg.res := 0
					ELSE Gadgets.framehandle(frame, msg)
					END
				ELSIF msg.id = Objects.set THEN
					IF msg.name = "Locked" THEN
						IF msg.class = Objects.Bool THEN
							IF msg.b THEN INCL(frame.state, Gadgets.lockedcontents) ELSE EXCL(frame.state, Gadgets.lockedcontents) END;
							msg.res := 0
						END
					ELSIF msg.name = "Buffered" THEN
						IF msg.b & ~(buffered IN frame.options) THEN INCL(frame.options, buffered); frame.cache := NIL; msg.res := 0
						ELSIF ~msg.b & (buffered IN frame.options) THEN EXCL(frame.options, buffered); frame.cache := NIL; msg.res := 0
						END
					ELSIF msg.name = "Dithered" THEN
						IF msg.b & ~(dithered IN frame.options) THEN INCL(frame.options, dithered); frame.cache := NIL; msg.res := 0
						ELSIF ~msg.b & (dithered IN frame.options) THEN EXCL(frame.options, dithered); frame.cache := NIL; msg.res := 0
						END
					ELSE
						Gadgets.framehandle(frame, msg)
					END
				END
			END
		ELSIF msg IS Objects.LinkMsg THEN
			WITH msg: Objects.LinkMsg DO
				IF (msg.id = Objects.set) & (msg.name = "Model") THEN
					IF (msg.obj # NIL) & (msg.obj IS Images.Image) THEN
						frame.obj := msg.obj; frame.cache := NIL; msg.res := 0;
						img := msg.obj(Images.Image);
						IF Images.alpha IN img.fmt.components THEN INCL(frame.state, Gadgets.transparent)
						ELSE EXCL(frame.state, Gadgets.transparent)
						END
					END
				ELSE
					Gadgets.framehandle(frame, msg)
				END
			END
		ELSIF msg IS Objects.CopyMsg THEN
			WITH msg: Objects.CopyMsg DO
				IF msg.stamp # frame.stamp THEN
					NEW(copy); frame.dlink := copy; frame.stamp := msg.stamp;
					Copy(msg, frame, copy)
				END;
				msg.obj := frame.dlink
			END
		ELSIF msg IS Objects.FileMsg THEN
			WITH msg: Objects.FileMsg DO
				Gadgets.framehandle(frame, msg);
				IF msg.id = Objects.store THEN
					Files.WriteNum(msg.R, 1);
					Files.WriteSet(msg.R, frame.options)
				ELSIF msg.id = Objects.load THEN
					Files.ReadNum(msg.R, ver);
					Files.ReadSet(msg.R, frame.options);
					IF (frame.obj # NIL) & (frame.obj IS Images.Image) THEN
						img := frame.obj(Images.Image);
						IF Images.alpha IN img.fmt.components THEN INCL(frame.state, Gadgets.transparent)
						ELSE EXCL(frame.state, Gadgets.transparent)
						END
					END
				END
			END
		ELSE
			Gadgets.framehandle(frame, msg)
		END
	END Handle;

	(** initialize frame with map model **)
	PROCEDURE Init* (frame: Frame; img: Images.Image);
	BEGIN
		frame.handle := Handle; frame.W := 100; frame.H := 100;
		frame.obj := img; frame.options := {buffered};
		IF img # NIL THEN
			INCL(frame.state, Gadgets.lockedcontents); frame.W := img.width; frame.H := img.height;
			IF img.fmt.bpp > Images.DisplayFormat.bpp THEN INCL(frame.options, dithered) END;
			IF Images.alpha IN img.fmt.components THEN INCL(frame.state, Gadgets.transparent) END
		END
	END Init;

	(** frame generator **)
	PROCEDURE New*;
		VAR frame: Frame;
	BEGIN
		NEW(frame); Init(frame, NIL);
		Objects.NewObj := frame
	END New;


END ImageGadgets.
