(* ETH Oberon, Copyright 2001 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

MODULE GfxPrinter IN Oberon; (** portable *)	(* eos  *)

	(**
		Raster contexts rendering to Oberon printer
	**)

	(*
		10.12.98 - first version; derived from GfxDev
		25.8.99 - replaced GfxMaps with Images/GfxImages
		10.8.99 - scratched SetPoint, added Close method
		13.02.2000 - new get/set clip methods
		30.03.2000 - use font as metric if printer metric is NIL
	*)

	IMPORT
		SYSTEM, Display, Fonts, Printer, Images, GfxMatrix, GfxImages, GfxRegions, GfxFonts, Gfx, GfxRaster;


	CONST
		R = Images.r; G = Images.g; B = Images.b; A = Images.a;


	TYPE
		Context* = POINTER TO ContextDesc;
		ContextDesc* = RECORD (GfxRaster.ContextDesc)
			orgX*, orgY*: FLOAT32;	(** origin of default coordinate system **)
			scale*: FLOAT32;	(** scale factor of default coordinate system **)
			defClip*: GfxRegions.Region;	(** default clipping region **)
			prcol: Gfx.Color;
		END;

		RegData = RECORD (GfxRegions.EnumData)
			pc: Context;
			dx, dy: SIGNED16;
			img: Images.Image;
			col: Images.Pixel;
		END;


	VAR
		Methods: Gfx.Methods;
		White: Images.Pixel;


	(*--- Rendering ---*)

	PROCEDURE UseColor (pc: Context; col: Gfx.Color);
	BEGIN
		IF (col.r # pc.prcol.r) OR (col.g # pc.prcol.g) OR (col.b # pc.prcol.b) THEN
			Printer.UseColor(col.r, col.g, col.b);
			pc.prcol := col
		END
	END UseColor;

	PROCEDURE Color (llx, lly, urx, ury: SIGNED16; VAR data: GfxRegions.EnumData);
	BEGIN
		WITH data: RegData DO
			UseColor(data.pc, data.pc.col);
			Printer.ReplConst(llx, lly, urx - llx, ury - lly)
		END
	END Color;

	PROCEDURE Tile (llx, lly, urx, ury: SIGNED16; VAR data: GfxRegions.EnumData);
		VAR mw, mh, mx, my, y, x, len, r, g, b, a: SIGNED16; col: Gfx.Color; bit: SIGNED32; adr: ADDRESS; pix: Images.Pixel;
	BEGIN
		WITH data: RegData DO
			mw := data.img.width; mh := data.img.height;
			col.r := -1; col.g := -1; col.b := -1;
			y := lly; my := (lly - data.dy) MOD mh;
			WHILE y < ury DO
				x := llx; mx := (llx - data.dx) MOD mw; len := 0;
				bit := mx * data.img.fmt.bpp; adr := data.img.adr + my * data.img.bpr + bit DIV 8; bit := bit MOD 8;
				WHILE x + len < urx DO
					pix := data.col;
					data.img.fmt.unpack(data.img.fmt, adr, bit, pix);
					IF pix[A] # 0X THEN	(* pixel visible *)
						Images.GetRGBA(pix, r, g, b, a);
						IF (r = col.r) & (g = col.g) & (b = col.b) THEN	(* same color as last pixel *)
							INC(len)
						ELSE
							IF len > 0 THEN
								UseColor(data.pc, col);
								Printer.ReplConst(x, y, len, 1);
								INC(x, len)
							END;
							col.r := r; col.g := g; col.b := b;
							len := 1
						END
					ELSE
						IF len > 0 THEN
							UseColor(data.pc, col);
							Printer.ReplConst(x, y, len, 1);
							INC(x, len); len := 0
						END;
						INC(x)
					END;
					INC(mx);
					IF mx = mw THEN
						mx := 0; adr := data.img.adr + my * data.img.bpr; bit := 0
					ELSE
						bit := bit + data.img.fmt.bpp; INC(adr, bit DIV 8); bit := bit MOD 8
					END
				END;
				IF len > 0 THEN
					UseColor(data.pc, col);
					Printer.ReplConst(x, y, len, 1)
				END;
				INC(y); my := (my + 1) MOD mh
			END
		END
	END Tile;

	PROCEDURE Dot (rc: GfxRaster.Context; x, y: SIGNED32);
		VAR pc: Context; mode: Images.Mode; px, py: SIGNED16; pix: Images.Pixel; col: Gfx.Color;
	BEGIN
		IF (rc.clipState = GfxRaster.In) OR
			(rc.clipState = GfxRaster.InOut) & GfxRegions.RectInside(SHORT(x), SHORT(y), SHORT(x+1), SHORT(y+1), rc.clipReg)
		THEN
			pc := rc(Context);
			IF rc.pat = NIL THEN
				UseColor(pc, pc.col);
				Printer.ReplConst(SHORT(x), SHORT(y), 1, 1)
			ELSE
				px := SHORT(x - ENTIER(pc.orgX + pc.pat.px + 0.5)) MOD pc.pat.img.width;
				py := SHORT(y - ENTIER(pc.orgY + pc.pat.py + 0.5)) MOD pc.pat.img.height;
				Images.InitModeColor(mode, Images.srcOverDst, pc.col.r, pc.col.g, pc.col.b);
				pix := White;
				Images.GetPixels(pc.pat.img, px, py, 1, Images.PixelFormat, pix, mode);
				IF pix[A] # 0X THEN
					col.r := ORD(pix[R]); col.g := ORD(pix[G]); col.b := ORD(pix[B]);
					UseColor(pc, col);
					Printer.ReplConst(SHORT(x), SHORT(y), 1, 1)
				END
			END
		END
	END Dot;

	PROCEDURE Rect (rc: GfxRaster.Context; llx, lly, urx, ury: SIGNED32);
		VAR pc: Context; data: RegData;
	BEGIN
		IF rc.clipState # GfxRaster.Out THEN
			pc := rc(Context);
			IF pc.pat = NIL THEN
				IF pc.clipState = GfxRaster.In THEN
					UseColor(pc, pc.col);
					Printer.ReplConst(SHORT(llx), SHORT(lly), SHORT(urx - llx), SHORT(ury - lly))
				ELSE
					data.pc := pc;
					GfxRegions.Enumerate(pc.clipReg, SHORT(llx), SHORT(lly), SHORT(urx), SHORT(ury), Color, data)
				END
			ELSE
				Images.SetRGB(data.col, pc.col.r, pc.col.g, pc.col.b);
				data.dx := SHORT(ENTIER(pc.orgX + pc.pat.px + 0.5));
				data.dy := SHORT(ENTIER(pc.orgY + pc.pat.py + 0.5));
				data.img := pc.pat.img; data.pc := pc;
				GfxRegions.Enumerate(pc.clipReg, SHORT(llx), SHORT(lly), SHORT(urx), SHORT(ury), Tile, data)
			END
		END
	END Rect;

	PROCEDURE SetColPat (rc: GfxRaster.Context; col: Gfx.Color; pat: Gfx.Pattern);
		VAR pc: Context;
	BEGIN
		pc := rc(Context);
		pc.col := col; pc.pat := pat
	END SetColPat;


	(*--- Methods ---*)

	PROCEDURE ResetCTM (ctxt: Gfx.Context);
		VAR pc: Context;
	BEGIN
		pc := ctxt(Context);
		GfxMatrix.Translate(GfxMatrix.Identity, pc.orgX, pc.orgY, pc.ctm);
		GfxMatrix.Scale(pc.ctm, pc.scale, pc.scale, pc.ctm)
	END ResetCTM;

	PROCEDURE ResetClip (ctxt: Gfx.Context);
		VAR pc: Context;
	BEGIN
		pc := ctxt(Context);
		GfxRaster.ResetClip(pc);
		GfxRegions.Copy(pc.defClip, pc.clipReg)
	END ResetClip;

	PROCEDURE Show (ctxt: Gfx.Context; x, y: FLOAT32; VAR str: ARRAY OF CHAR);
		VAR
			mat, m: GfxMatrix.Matrix; font: GfxFonts.Font; pc: Context; u, v, du, dv: FLOAT32; metric: Fonts.Font;
			i, aw, dx, bx, by, w, h, px, py: SIGNED16; pat: Display.Pattern;
	BEGIN
		GfxMatrix.Concat(ctxt.font.mat, ctxt.ctm, mat);
		GfxMatrix.Scale(mat, Printer.Unit/Display.Unit, Printer.Unit/Display.Unit, m);	(* check for screen font *)
		font := GfxFonts.Open(ctxt.font.name, ctxt.font.ptsize, m);
		IF (font.rfont # NIL) & (ctxt.mode * {Gfx.Record..Gfx.EvenOdd} = {Gfx.Fill}) & (ctxt.fillPat = NIL) THEN
			pc := ctxt(Context);
			GfxMatrix.Apply(pc.ctm, x, y, u, v);
			metric := Printer.GetMetric(font.rfont);
			IF metric = NIL THEN metric := font.rfont END;
			i := 0; aw := 0;
			WHILE str[i] # 0X DO
				Fonts.GetChar(metric, str[i], dx, bx, by, w, h, pat);
				INC(aw, dx); INC(i)
			END;
			px := SHORT(ENTIER(u)); py := SHORT(ENTIER(v));
			IF GfxRegions.RectInside(px, py + metric.minY, px + aw, py + metric.maxY, pc.clipReg) THEN
				UseColor(pc, pc.fillCol);
				Printer.String(px, py, str, font.rfont);
				font := GfxFonts.Open(pc.font.name, pc.font.ptsize, mat);	(* use same metrics as GfxRaster.Show *)
				GfxFonts.GetStringWidth(font, str, du, dv);
				GfxMatrix.Solve(pc.ctm, u + du, v + dv, pc.cpx, pc.cpy)
			ELSE
				GfxRaster.Show(ctxt, x, y, str)
			END
		ELSE
			GfxRaster.Show(ctxt, x, y, str)
		END
	END Show;

	PROCEDURE Image (ctxt: Gfx.Context; x, y: FLOAT32; img: Images.Image; VAR filter: GfxImages.Filter);
		VAR
			pc: Context; tmp: Images.Image; m: GfxMatrix.Matrix; dx, dy, x0, y0, x1, y1, op, j, i: SIGNED16; llx, lly, urx, ury: FLOAT32;
			col: Gfx.Color; mode: Images.Mode; pix: Images.Pixel; p: SIGNED32; data: RegData;
	BEGIN
		pc := ctxt(Context); tmp := NIL;
		GfxMatrix.Translate(pc.ctm, x, y, m);
		dx := SHORT(ENTIER(m[2, 0])); m[2, 0] := m[2, 0] - dx;
		dy := SHORT(ENTIER(m[2, 1])); m[2, 1] := m[2, 1] - dy;
		IF (filter.hshift # GfxImages.NoFilter.hshift) & (0.1 < m[2, 0]) & (m[2, 0] < 0.9) OR
			(filter.vshift # GfxImages.NoFilter.vshift) & (0.1 < m[2, 1]) & (m[2, 1] < 0.9) OR
			GfxMatrix.Scaled(m) OR
			GfxMatrix.Rotated(m)
		THEN	(* transform to intermediate map *)
			GfxMatrix.ApplyToRect(m, 0, 0, img.width, img.height, llx, lly, urx, ury);
			x0 := SHORT(ENTIER(llx)); y0 := SHORT(ENTIER(lly));
			x1 := -SHORT(ENTIER(-urx)); y1 := -SHORT(ENTIER(-ury));
			GfxRegions.ClipRect(x0, y0, x1, y1, pc.clipReg.llx - dx, pc.clipReg.lly - dy, pc.clipReg.urx - dx, pc.clipReg.ury - dy);
			NEW(tmp); Images.Create(tmp, x1 - x0, y1 - y0, Images.BGRA8888);

			m[2, 0] := m[2, 0] - x0; m[2, 1] := m[2, 1] - y0;
			op := filter.op; col.r := ORD(filter.col[R]); col.g := ORD(filter.col[G]); col.b := ORD(filter.col[B]);
			Images.InitModeColor(filter, Images.srcCopy, pc.fillCol.r, pc.fillCol.g, pc.fillCol.b);
			GfxImages.Transform(img, tmp, m, filter);
			Images.InitModeColor(filter, op, col.r, col.g, col.b);
			img := tmp; INC(dx, x0); INC(dy, y0)
		END;

		IF filter.op # Images.srcCopy THEN	(* blend with background color *)
			IF tmp = NIL THEN	(* need intermediate image to blend *)
				NEW(tmp); Images.Create(tmp, img.width, img.height, Images.BGRA8888);
				Images.InitModeColor(mode, Images.srcCopy, pc.fillCol.r, pc.fillCol.g, pc.fillCol.b);
				Images.Copy(img, tmp, 0, 0, img.width, img.height, 0, 0, mode);
				img := tmp
			END;
			Images.Bind(filter, Images.BGRA8888, Images.BGRA8888);
			NEW(tmp); Images.InitBuf(tmp, 1, 1, Images.BGRA8888, 0, 0, pix);
			j := 0;
			WHILE j < img.height DO
				i := 0; p := j * img.bpr;
				WHILE i < img.width DO
					IF img.mem[p + A] # 0X THEN	(* ignore pixels with zero alpha (not part of transformed image) *)
						pix := White;	(* substitute white background *)
						filter.transfer(filter, img.adr + p, 0, tmp.adr, 0, 1);
						img.mem[p] := pix[0]; img.mem[p+1] := pix[1]; img.mem[p+2] := pix[2]; img.mem[p+3] := pix[3]
					END;
					INC(i); INC(p, 4)
				END;
				INC(j)
			END
		END;

		(* display visible parts *)
		Images.SetRGB(data.col, pc.fillCol.r, pc.fillCol.g, pc.fillCol.b);
		data.pc := pc; data.img := img; data.dx := dx; data.dy := dy;
		GfxRegions.Enumerate(pc.clipReg, dx, dy, dx + img.width, dy + img.height, Tile, data)
	END Image;

	PROCEDURE NewPattern (ctxt: Gfx.Context; img: Images.Image; px, py: FLOAT32): Gfx.Pattern;
		VAR scale: FLOAT32; pat: Gfx.Pattern; w, h: SIGNED16;
	BEGIN
		scale := 10000/Printer.Unit;
		NEW(pat); pat.px := scale * px; pat.py := scale * py;
		w := -SHORT(ENTIER(-scale * img.width)); h := -SHORT(ENTIER(-scale * img.height));
		NEW(pat.img); Images.Create(pat.img, w, h, img.fmt);
		GfxImages.Scale(img, pat.img, scale, scale, 0, 0, GfxImages.LinearFilter);
		RETURN pat
	END NewPattern;

	PROCEDURE InitMethods;
		VAR do: Gfx.Methods;
	BEGIN
		NEW(do); Methods := do;
		do.reset := Gfx.DefResetContext;
		do.resetCTM := ResetCTM; do.setCTM := Gfx.DefSetCTM; do.translate := Gfx.DefTranslate;
		do.scale := Gfx.DefScale; do.rotate := Gfx.DefRotate; do.concat := Gfx.DefConcat;
		do.resetClip := ResetClip; do.getClipRect := GfxRaster.GetClipRect;
		do.getClip := GfxRaster.GetClip; do.setClip := GfxRaster.SetClip;
		do.setStrokeColor := Gfx.DefSetStrokeColor; do.setStrokePattern := Gfx.DefSetStrokePattern;
		do.setFillColor := Gfx.DefSetFillColor; do.setFillPattern := Gfx.DefSetFillPattern;
		do.setLineWidth := Gfx.DefSetLineWidth; do.setDashPattern := Gfx.DefSetDashPattern;
		do.setCapStyle := Gfx.DefSetCapStyle; do.setJoinStyle := Gfx.DefSetJoinStyle;
		do.setStyleLimit := Gfx.DefSetStyleLimit; do.setFlatness := Gfx.DefSetFlatness;
		do.setFont := Gfx.DefSetFont; do.getWidth := Gfx.DefGetStringWidth;
		do.begin := GfxRaster.Begin; do.end := GfxRaster.End;
		do.enter := GfxRaster.Enter; do.exit := GfxRaster.Exit; do.close := GfxRaster.Close;
		do.line := GfxRaster.Line; do.arc := GfxRaster.Arc; do.bezier := GfxRaster.Bezier;
		do.show := Show;
		do.flatten := Gfx.DefFlatten; do.outline := Gfx.DefOutline;
		do.render := GfxRaster.Render;
		do.rect := GfxRaster.Rect; do.ellipse := GfxRaster.Ellipse;
		do.image := Image; do.newPattern := NewPattern;
	END InitMethods;


	(*--- Exported Interface ---*)

	(** set default clip region to rectangle **)
	PROCEDURE SetClipRect* (pc: Context; llx, lly, urx, ury: SIGNED16);
	BEGIN
		GfxRegions.SetToRect(pc.defClip, llx, lly, urx, ury)
	END SetClipRect;

	(** copy given region to default clip region **)
	PROCEDURE SetClipRegion* (pc: Context; reg: GfxRegions.Region);
	BEGIN
		GfxRegions.Copy(reg, pc.defClip)
	END SetClipRegion;

	(** set default coordinate origin and scale factor **)
	PROCEDURE SetCoordinates* (pc: Context; x, y, scale: FLOAT32);
	BEGIN
		pc.orgX := x; pc.orgY := y; pc.scale := scale
	END SetCoordinates;

	(** initialize context to printable range **)
	PROCEDURE Init* (pc: Context);
	BEGIN
		GfxRaster.InitContext(pc);
		pc.do := Methods; pc.dot := Dot; pc.rect := Rect; pc.setColPat := SetColPat;
		pc.prcol.r := -1; pc.prcol.g := -1; pc.prcol.b := -1;
		NEW(pc.defClip); GfxRegions.Init(pc.defClip, GfxRegions.Winding);
		SetClipRect(pc, Printer.FrameX, Printer.FrameY, Printer.FrameX + Printer.FrameW, Printer.FrameY + Printer.FrameH);
		SetCoordinates(pc, Printer.FrameX, Printer.FrameY, 10000/Printer.Unit);
		Gfx.DefResetContext(pc)
	END Init;


BEGIN
	InitMethods;
	White[0] := 0FFX; White[1] := 0FFX; White[2] := 0FFX; White[3] := 0FFX
END GfxPrinter.
