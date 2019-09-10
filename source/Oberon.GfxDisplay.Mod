(* ETH Oberon, Copyright 2001 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

MODULE GfxDisplay IN Oberon; (** portable *)	(* eos  *)

	(**
		Raster contexts on Oberon display
	**)

	(*
		10.12.98 - first release; derived from former GfxDev
		16.4.99 - bugfix in CopyIndex and BlendIndex: used wrong offset into bitmap
		19.4.99 - uses Display transfer and truecolor functionality
		[26.5.99 - use 300 dpi metrics in Show (removed 14.7.99)]
		25.8.99 - replaced GfxMaps with Images/GfxImages
		10.8.99 - scratched SetPoint, added Close method
		17.11.1999 - added Colors
		13.02.2000 - new get/set clip methods
	*)

	IMPORT
		Display, Fonts, Colors, Images, GfxMatrix, GfxImages, GfxRegions, GfxFonts, Gfx, GfxRaster;


	CONST
		red = Images.r; green = Images.g; blue = Images.b; alpha = Images.a;
		MaxRun = 256;


	TYPE
		Context* = POINTER TO ContextDesc;
		ContextDesc* = RECORD (GfxRaster.ContextDesc)
			orgX*, orgY*: FLOAT32;	(** origin of default coordinate system **)
			scale*: FLOAT32;	(** scale factor of default coordinate system **)
			defClip*: GfxRegions.Region;	(** default clipping region **)
			bg*: Gfx.Color;	(** background color for erasing **)
			bgCol: Display.Color;	(* display color corresponding to background color *)
			bgPix: Images.Pixel;	(* pixel value corresponding to background color *)
			dcol: Display.Color;	(* current display color *)
			srcOverDst: Images.Mode;	(* srcOverDst mode with current color *)
		END;

		RegData = RECORD (GfxRegions.EnumData)
			dc: Context;
			dx, dy: SIGNED16;
			pat: Display.Pattern;
			img: Images.Image;
			col: Display.Color;
		END;

		BlendDotProc = PROCEDURE (dc: Context; img: Images.Image; mx, my: SIGNED16; x, y: SIGNED32);
		CopyRunProc = PROCEDURE (img: Images.Image; mx, my, len: SIGNED16; x, y: SIGNED32);
		BlendRunProc = PROCEDURE (dc: Context; img: Images.Image; mx, my, len: SIGNED16; x, y: SIGNED32);
		WarpProc = PROCEDURE (dc: Context; img: Images.Image; dx, dy, x0, y0, x1, y1: SIGNED16; VAR m: GfxMatrix.Matrix; VAR f: GfxImages.Filter);
		CopyImageProc = PROCEDURE (dc: Context; img: Images.Image; dx, dy: SIGNED16; VAR filter: GfxImages.Filter);


	VAR
		TrueColor, TransferBlock: BOOLEAN;	(* set if corresponding Display features are available *)
		Methods: Gfx.Methods;

		BlendDot: BlendDotProc;	(* copies dot from pattern to display *)
		CopyRun: CopyRunProc;	(* copies run from image to display *)
		BlendRun: BlendRunProc;	(* blends buffer run with display *)
		TileRect: GfxRegions.Enumerator;	(* fills rectangular area with pattern *)
		Warp: WarpProc;	(* applies matrix to image and stores result in buffer *)
		BlendImageRect: GfxRegions.Enumerator;	(* blends image rectangle *)
		CopyImage: CopyImageProc;	(* copies visible parts of image to display *)

		Buffer: Images.Image;	(* shadow map *)


	PROCEDURE CreateBuffer (w, h: SIGNED16);
	BEGIN
		(*
			Display.TransferBlock on Windows Oberon requires that the size of the supplied memory block is a
			multiple of 4 bytes. We therefore ensure that one row occupies at least 4 bytes and allocate one
			row more than requested.
		*)
		IF w * Images.DisplayFormat.bpp < 32 THEN
			w := 32 DIV Images.DisplayFormat.bpp
		END;
		Images.Create(Buffer, w, h+1, Images.DisplayFormat)
	END CreateBuffer;


	(*--- Blend Dot Into Display ---*)

	PROCEDURE BlendDotBlk (dc: Context; img: Images.Image; mx, my: SIGNED16; x, y: SIGNED32);
		VAR buf: ARRAY 4 OF CHAR;
	BEGIN
		IF Images.alpha IN img.fmt.components THEN	(* get original color from display *)
			Display.TransferBlock(buf, 0, 0, x, y, 1, 1, Display.get)
		END;
		Images.GetPixels(img, mx, my, 1, Images.DisplayFormat, buf, dc.srcOverDst);
		Display.TransferBlock(buf, 0, 0, x, y, 1, 1, Display.set)
	END BlendDotBlk;

	PROCEDURE BlendDotRGB (dc: Context; img: Images.Image; mx, my: SIGNED16; x, y: SIGNED32);
		VAR pix: Images.Pixel;
	BEGIN
		IF Images.alpha IN img.fmt.components THEN
			pix := dc.bgPix
		END;
		Images.GetPixels(img, mx, my, 1, Images.PixelFormat, pix, dc.srcOverDst);
		Display.Dot(Display.RGB(ORD(pix[red]), ORD(pix[green]), ORD(pix[blue])), x, y, Display.replace)
	END BlendDotRGB;

	PROCEDURE BlendDotIdx (dc: Context; img: Images.Image; mx, my: SIGNED16; x, y: SIGNED32);
		VAR buf: ARRAY 1 OF CHAR;
	BEGIN
		IF Images.alpha IN img.fmt.components THEN
			buf[0] := CHR(dc.bgCol)
		END;
		Images.GetPixels(img, mx, my, 1, Images.D8, buf, dc.srcOverDst);
		Display.Dot(ORD(buf[0]), x, y, Display.replace)
	END BlendDotIdx;

	PROCEDURE Dot (rc: GfxRaster.Context; x, y: SIGNED32);
		VAR dc: Context; img: Images.Image; mw, mh, mx, my: SIGNED16;
	BEGIN
		IF (rc.clipState = GfxRaster.In) OR
			(rc.clipState = GfxRaster.InOut) & GfxRegions.RectInside(SHORT(x), SHORT(y), SHORT(x+1), SHORT(y+1), rc.clipReg)
		THEN
			IF rc.pat = NIL THEN
				Display.Dot(rc(Context).dcol, x, y, Display.replace)
			ELSE
				dc := rc(Context); img := dc.pat.img;
				mw := img.width; mh := img.height;
				mx := SHORT(x - ENTIER(dc.orgX + dc.pat.px + 0.5)) MOD mw;
				my := SHORT(y - ENTIER(dc.orgY + dc.pat.py + 0.5)) MOD mh;
				BlendDot(dc, img, mx, my, x, y)
			END
		END
	END Dot;


	(*--- Draw Run ---*)

	PROCEDURE DrawRunRGB (VAR buf: ARRAY OF CHAR; len, x, y: SIGNED32);
		VAR i, l: SIGNED32; r, g, b: CHAR;
	BEGIN
		i := 0;
		WHILE len > 0 DO
			r := buf[i + red]; g := buf[i + green]; b := buf[i + blue]; INC(i, 3); l := 1;
			WHILE (l < len) & (buf[i + red] = r) & (buf[i + green] = g) & (buf[i + blue] = b) DO
				INC(i, 3); INC(l)
			END;
			Display.ReplConst(Display.RGB(ORD(r), ORD(g), ORD(b)), x, y, l, 1, Display.replace);
			INC(x, l); DEC(len, l)
		END
	END DrawRunRGB;

	PROCEDURE DrawRunIdx (VAR buf: ARRAY OF CHAR; len, x, y: SIGNED32);
		VAR i, l: SIGNED32; idx: CHAR;
	BEGIN
		i := 0;
		WHILE len > 0 DO
			idx := buf[i]; INC(i); l := 1;
			WHILE (l < len) & (buf[i] = idx) DO INC(i); INC(l) END;
			Display.ReplConst(ORD(idx), x, y, l, 1, Display.replace);
			INC(x, l); DEC(len, l)
		END
	END DrawRunIdx;


	(*--- Copy Image Run ---*)

	PROCEDURE CopyRunRGB (img: Images.Image; mx, my, len: SIGNED16; x, y: SIGNED32);
		VAR buf: ARRAY 3*MaxRun OF CHAR;
	BEGIN
		Images.GetPixels(img, mx, my, len, Images.BGR888, buf, Images.SrcCopy);
		DrawRunRGB(buf, len, x, y)
	END CopyRunRGB;

	PROCEDURE CopyRunIdx (img: Images.Image; mx, my, len: SIGNED16; x, y: SIGNED32);
		VAR buf: ARRAY MaxRun OF CHAR;
	BEGIN
		Images.GetPixels(img, mx, my, len, Images.D8, buf, Images.SrcCopy);
		DrawRunIdx(buf, len, x, y)
	END CopyRunIdx;


	(*--- Blend Image Run ---*)

	PROCEDURE BlendRunRGB (dc: Context; img: Images.Image; mx, my, len: SIGNED16; x, y: SIGNED32);
		VAR i, j, l: SIGNED32; buf: ARRAY 3*MaxRun OF CHAR; alpha: ARRAY MaxRun OF CHAR; a, r, g, b: CHAR;
	BEGIN
		i := 0; j := 0;
		WHILE i < len DO
			buf[j + blue] := dc.bgPix[blue]; buf[j + green] := dc.bgPix[green]; buf[j + red] := dc.bgPix[red];
			INC(i); INC(j, 3)
		END;
		Images.GetPixels(img, mx, my, len, Images.BGR888, buf, dc.srcOverDst);
		Images.GetPixels(img, mx, my, len, Images.A8, alpha, Images.SrcCopy);
		i := 0; j := 0;
		WHILE len > 0 DO
			a := alpha[i]; INC(i);
			IF a = 0X THEN
				INC(j, 3); INC(x); DEC(len)
			ELSE
				r := buf[j + red]; g := buf[j + green]; b := buf[j + blue]; INC(j, 3); l := 1;
				WHILE (l < len) & (alpha[i] # 0X) & (buf[j + red] = r) & (buf[j + green] = g) & (buf[j + blue] = b) DO
					INC(i); INC(j, 3); INC(l)
				END;
				Display.ReplConst(Display.RGB(ORD(r), ORD(g), ORD(b)), x, y, l, 1, Display.replace);
				INC(x, l); DEC(len, SHORT(l))
			END
		END
	END BlendRunRGB;

	PROCEDURE BlendRunIdx (dc: Context; img: Images.Image; mx, my, len: SIGNED16; x, y: SIGNED32);
		VAR i, l: SIGNED32; buf, alpha: ARRAY MaxRun OF CHAR; idx: CHAR;
	BEGIN
		i := 0; WHILE i < len DO buf[i] := CHR(dc.bgCol); INC(i) END;
		Images.GetPixels(img, mx, my, len, Images.D8, buf, dc.srcOverDst);
		Images.GetPixels(img, mx, my, len, Images.A8, alpha, Images.SrcCopy);
		i := 0;
		WHILE len > 0 DO
			IF alpha[i] = 0X THEN
				INC(i); INC(x); DEC(len)
			ELSE
				idx := buf[i]; INC(i); l := 1;
				WHILE (l < len) & (alpha[i] # 0X) & (buf[i] = idx) DO INC(i); INC(l) END;
				Display.ReplConst(ORD(idx), x, y, l, 1, Display.replace);
				INC(x, l); DEC(len, SHORT(l))
			END
		END
	END BlendRunIdx;


	(*--- Draw Rectangle ---*)

	PROCEDURE DrawRect (llx, lly, urx, ury: SIGNED16; VAR data: GfxRegions.EnumData);
	BEGIN
		Display.ReplConst(data(RegData).col, llx, lly, urx - llx, ury - lly, Display.replace)
	END DrawRect;

	PROCEDURE TileRectBlk (llx, lly, urx, ury: SIGNED16; VAR data: GfxRegions.EnumData);
		VAR w, h: SIGNED16;
	BEGIN
		WITH data: RegData DO
			w := urx - llx; h := ury - lly;
			CreateBuffer(w, h);
			IF Images.alpha IN data.img.fmt.components THEN
				Display.TransferBlock(Buffer.mem^, 0, Buffer.bpr, llx, lly, w, h, Display.get)
			END;
			Images.FillPattern(data.img, Buffer, 0, 0, w, h, data.dx - llx, data.dy - lly, data.dc.srcOverDst);
			Display.TransferBlock(Buffer.mem^, 0, Buffer.bpr, llx, lly, w, h, Display.set)
		END
	END TileRectBlk;

	PROCEDURE TileRectPix (llx, lly, urx, ury: SIGNED16; VAR data: GfxRegions.EnumData);
		VAR mw, mh, y, my, x, mx, len: SIGNED16;
	BEGIN
		WITH data: RegData DO
			mw := data.img.width; mh := data.img.height;
			y := lly; my := (lly - data.dy) MOD mh;
			WHILE y < ury DO
				x := llx; mx := (llx - data.dx) MOD mw;
				WHILE x < urx DO
					len := urx - x;
					IF mx + len > mw THEN len := mw - mx END;
					IF len > MaxRun THEN len := MaxRun END;
					IF Images.alpha IN data.img.fmt.components THEN
						BlendRun(data.dc, data.img, mx, my, len, x, y)
					ELSE
						CopyRun(data.img, mx, my, len, x, y)
					END;
					INC(x, len); INC(mx, len);
					IF mx = mw THEN mx := 0 END
				END;
				INC(y); INC(my);
				IF my = mh THEN my := 0 END
			END
		END
	END TileRectPix;

	PROCEDURE Rect (rc: GfxRaster.Context; llx, lly, urx, ury: SIGNED32);
		VAR data: RegData; dc: Context;
	BEGIN
		IF rc.clipState # GfxRaster.Out THEN
			IF rc.pat = NIL THEN
				IF rc.clipState = GfxRaster.In THEN
					Display.ReplConst(rc(Context).dcol, llx, lly, urx - llx, ury - lly, Display.replace)
				ELSE
					data.col := rc(Context).dcol;
					GfxRegions.Enumerate(rc.clipReg, SHORT(llx), SHORT(lly), SHORT(urx), SHORT(ury), DrawRect, data)
				END
			ELSE
				dc := rc(Context);
				data.dx := SHORT(ENTIER(dc.orgX + dc.pat.px + 0.5));
				data.dy := SHORT(ENTIER(dc.orgY + dc.pat.py + 0.5));
				data.dc := dc; data.img := dc.pat.img;
				GfxRegions.Enumerate(dc.clipReg, SHORT(llx), SHORT(lly), SHORT(urx), SHORT(ury), TileRect, data)
			END
		END
	END Rect;


	(*--- Set Color/Pattern for Raster Context ---*)

	PROCEDURE SetColPatRGB (rc: GfxRaster.Context; col: Gfx.Color; pat: Gfx.Pattern);
		VAR dc: Context;
	BEGIN
		dc := rc(Context);
		dc.col := col; dc.pat := pat; dc.dcol := Display.RGB(col.r, col.g, col.b);
		Images.SetModeColor(dc.srcOverDst, col.r, col.g, col.b)
	END SetColPatRGB;

	PROCEDURE SetColPatIdx (rc: GfxRaster.Context; col: Gfx.Color; pat: Gfx.Pattern);
		VAR dc: Context;
	BEGIN
		dc := rc(Context);
		dc.col := col; dc.pat := pat; dc.dcol := Colors.Match(Colors.DisplayIndex, Colors.DisplayBits, col.r, col.g, col.b);
		Images.SetModeColor(dc.srcOverDst, col.r, col.g, col.b)
	END SetColPatIdx;


	(*--- Draw String ---*)

	PROCEDURE CopyPattern (llx, lly, urx, ury: SIGNED16; VAR data: GfxRegions.EnumData);
	BEGIN
		WITH data: RegData DO
			Display.SetClip(llx, lly, urx - llx, ury - lly);
			Display.CopyPattern(data.col, data.pat, data.dx, data.dy, Display.paint);
			Display.ResetClip
		END
	END CopyPattern;

	PROCEDURE Show (ctxt: Gfx.Context; x, y: FLOAT32; VAR str: ARRAY OF CHAR);
		VAR
			mat: GfxMatrix.Matrix; font: GfxFonts.Font; dc: Context; u, v: FLOAT32;
			px, py, i, aw, dx, bx, by, w, h: SIGNED16; pat: Display.Pattern; data: RegData;
	BEGIN
		GfxMatrix.Concat(ctxt.font.mat, ctxt.ctm, mat);
		font := GfxFonts.Open(ctxt.font.name, ctxt.font.ptsize, mat);
		IF font = NIL THEN font := GfxFonts.Default END;
		IF (font.rfont # NIL) & (ctxt.mode * {Gfx.Record..Gfx.EvenOdd} = {Gfx.Fill}) & (ctxt.fillPat = NIL) THEN
			dc := ctxt(Context);
			dc.setColPat(dc, dc.fillCol, NIL);
			GfxMatrix.Apply(dc.ctm, x, y, u, v);
			px := SHORT(ENTIER(u + 0.5)); py := SHORT(ENTIER(v + 0.5));
			i := 0; aw := 0;
			WHILE str[i] # 0X DO
				Fonts.GetChar(font.rfont, str[i], dx, bx, by, w, h, pat);
				INC(aw, dx); INC(i)
			END;
			IF GfxRegions.RectInside(px, py + font.rfont.minY, px + aw, py + font.rfont.maxY, dc.clipReg) THEN
				i := 0;
				WHILE str[i] # 0X DO
					Fonts.GetChar(font.rfont, str[i], dx, bx, by, w, h, pat);
					IF w * h # 0 THEN
						Display.CopyPattern(dc.dcol, pat, px + bx, py + by, Display.paint)
					END;
					INC(px, dx); INC(i)
				END
			ELSE
				data.col := dc.dcol; i := 0;
				WHILE str[i] # 0X DO
					Fonts.GetChar(font.rfont, str[i], dx, bx, by, w, h, pat);
					IF (w * h # 0) & GfxRegions.RectOverlaps(px + bx, py + by, px + bx + w, py + by + h, dc.clipReg) THEN
						data.dx := px + bx; data.dy := py + by; data.pat := pat;
						GfxRegions.Enumerate(dc.clipReg, data.dx, data.dy, data.dx + w, data.dy + h, CopyPattern, data)
					END;
					INC(px, dx); INC(i)
				END
			END;
			dc.cpx := x + aw; dc.cpy := y	(* font coordinates are same as world coordinates *)
		ELSE
			GfxRaster.Show(ctxt, x, y, str)
		END
	END Show;


	(*--- Transform To Temporary Bitmap ---*)

	PROCEDURE WarpBlk (dc: Context; img: Images.Image; dx, dy, x0, y0, x1, y1: SIGNED16; VAR m: GfxMatrix.Matrix; VAR f: GfxImages.Filter);
		VAR col: Images.Pixel;
	BEGIN
		CreateBuffer(x1 - x0, y1 - y0);
		Display.TransferBlock(Buffer.mem^, 0, Buffer.bpr, dx + x0, dy + y0, x1 - x0, y1 - y0, Display.get);
		m[2, 0] := m[2, 0] - x0; m[2, 1] := m[2, 1] - y0;	(* make transform local to Buffer origin *)
		col := f.col;
		Images.SetModeColor(f, dc.fillCol.r, dc.fillCol.g, dc.fillCol.b);
		GfxImages.Transform(img, Buffer, m, f);
		Images.SetModeColor(f, ORD(col[red]), ORD(col[green]), ORD(col[blue]))
	END WarpBlk;

	PROCEDURE WarpPix (dc: Context; img: Images.Image; dx, dy, x0, y0, x1, y1: SIGNED16; VAR m: GfxMatrix.Matrix; VAR f: GfxImages.Filter);
		VAR op: SIGNED16; col: Images.Pixel;
	BEGIN
		Images.Create(Buffer, x1 - x0, y1 - y0, Images.BGRA8888);
		m[2, 0] := m[2, 0] - x0; m[2, 1] := m[2, 1] - y0;	(* make transform local to Buffer origin *)
		op := f.op; col := f.col;
		Images.InitModeColor(f, Images.srcCopy, dc.fillCol.r, dc.fillCol.g, dc.fillCol.b);
		GfxImages.Transform(img, Buffer, m, f);
		Images.InitModeColor(f, op, ORD(col[red]), ORD(col[green]), ORD(col[blue]))
	END WarpPix;


	(*--- Draw/Blend Image Rectangle ---*)

	PROCEDURE DrawImageRectBlk (llx, lly, urx, ury: SIGNED16; VAR data: GfxRegions.EnumData);
		VAR off: SIGNED32;
	BEGIN
		WITH data: RegData DO
			off := (lly - data.dy) * data.img.bpr + LONG(llx - data.dx) * (data.img.fmt.bpp DIV 8);
			Display.TransferBlock(data.img.mem^, off, data.img.bpr, llx, lly, urx - llx, ury - lly, Display.set)
		END
	END DrawImageRectBlk;

	PROCEDURE DrawImageRectPix (llx, lly, urx, ury: SIGNED16; VAR data: GfxRegions.EnumData);
		VAR y, x, len: SIGNED16;
	BEGIN
		WITH data: RegData DO
			y := lly;
			WHILE y < ury DO
				x := llx;
				WHILE x < urx DO
					len := MaxRun;
					IF x + MaxRun > urx THEN len := urx - x END;
					CopyRun(data.img, x - data.dx, y - data.dy, len, x, y);
					INC(x, len)
				END;
				INC(y)
			END
		END
	END DrawImageRectPix;

	PROCEDURE BlendImageRectPix (llx, lly, urx, ury: SIGNED16; VAR data: GfxRegions.EnumData);
		VAR y, x, len: SIGNED16;
	BEGIN
		WITH data: RegData DO
			y := lly;
			WHILE y < ury DO
				x := llx;
				WHILE x < urx DO
					len := MaxRun;
					IF x + MaxRun > urx THEN len := urx - x END;
					BlendRun(data.dc, data.img, x - data.dx, y - data.dy, len, x, y);
					INC(x, len)
				END;
				INC(y)
			END
		END
	END BlendImageRectPix;


	(*--- Copy Image To Display ---*)

	PROCEDURE CopyImageBlk (dc: Context; img: Images.Image; dx, dy: SIGNED16; VAR filter: GfxImages.Filter);
		VAR data: RegData; llx, lly, urx, ury: SIGNED16; col: Images.Pixel;
	BEGIN
		IF Images.Same(img.fmt, Images.DisplayFormat) & (img.mem # NIL) &
			((filter.op IN {Images.srcCopy, Images.srcInDst}) OR
			 (filter.op IN {Images.srcOverDst, Images.srcAtopDst}) & ~(Images.alpha IN img.fmt.components))
		THEN	(* copy directly from image *)
			data.img := img; data.dx := dx; data.dy := dy;
			GfxRegions.Enumerate(dc.clipReg, dx, dy, dx + img.width, dy + img.height, DrawImageRectBlk, data)
		ELSE	(* blend into temporary map first *)
			llx := dx; lly := dy; urx := llx + img.width; ury := lly + img.height;
			GfxRegions.ClipRect(llx, lly, urx, ury, dc.clipReg.llx, dc.clipReg.lly, dc.clipReg.urx, dc.clipReg.ury);
			IF ~GfxRegions.RectEmpty(llx, lly, urx, ury) THEN
				CreateBuffer(urx - llx, ury - lly);
				IF ~(filter.op IN {Images.srcCopy, Images.srcInDst}) &
					~((filter.op IN {Images.srcOverDst, Images.srcAtopDst}) & ~(Images.alpha IN img.fmt.components))
				THEN
					Display.TransferBlock(Buffer.mem^, 0, Buffer.bpr, llx, lly, urx - llx, ury - lly, Display.get)
				END;
				col := filter.col;
				Images.SetModeColor(filter, dc.fillCol.r, dc.fillCol.g, dc.fillCol.b);
				Images.Copy(img, Buffer, llx - dx, lly - dy, urx - dx, ury - dy, 0, 0, filter);
				Images.SetModeColor(filter, ORD(col[red]), ORD(col[green]), ORD(col[blue]));
				data.img := Buffer; data.dx := llx; data.dy := lly;
				GfxRegions.Enumerate(dc.clipReg, llx, lly, urx, ury, DrawImageRectBlk, data)
			END
		END
	END CopyImageBlk;

	PROCEDURE CopyImagePix (dc: Context; img: Images.Image; dx, dy: SIGNED16; VAR filter: GfxImages.Filter);
		VAR data: RegData; llx, lly, urx, ury: SIGNED16; buf: Images.Image; col: Images.Pixel; mode: Images.Mode;
	BEGIN
		IF (filter.op IN {Images.srcCopy, Images.srcInDst}) & ~(Images.alpha IN img.fmt.components) THEN
			data.img := img; data.dx := dx; data.dy := dy;
			GfxRegions.Enumerate(dc.clipReg, dx, dy, dx + img.width, dy + img.height, DrawImageRectPix, data)
		ELSIF filter.op IN {Images.srcOverDst, Images.srcAtopDst} THEN
			dc.setColPat(dc, dc.fillCol, NIL);
			data.dc := dc; data.img := img; data.dx := dx; data.dy := dy;
			GfxRegions.Enumerate(dc.clipReg, dx, dy, dx + img.width, dy + img.height, BlendImageRectPix, data)
		ELSE
			llx := dx; lly := dy; urx := llx + img.width; ury := lly + img.height;
			GfxRegions.ClipRect(llx, lly, urx, ury, dc.clipReg.llx, dc.clipReg.lly, dc.clipReg.urx, dc.clipReg.ury);
			IF ~GfxRegions.RectEmpty(llx, lly, urx, ury) THEN
				NEW(buf); Images.Create(buf, urx - llx, ury - lly, Images.PixelFormat);
				Images.Fill(buf, 0, 0, urx - llx, ury - lly, dc.bgPix, Images.SrcCopy);
				col := filter.col;
				Images.SetModeColor(filter, dc.fillCol.r, dc.fillCol.g, dc.fillCol.b);
				Images.Copy(img, buf, llx - dx, lly - dy, urx - dx, ury - dy, 0, 0, filter);
				Images.SetModeColor(filter, ORD(col[red]), ORD(col[green]), ORD(col[blue]));
				Images.InitMode(mode, Images.dstInSrc);
				Images.Copy(img, buf, llx - dx, lly - dy, urx - dx, ury - dy, 0, 0, mode);	(* reduce buf to opaque parts of img *)
				data.img := buf; data.dx := llx; data.dy := lly;
				GfxRegions.Enumerate(dc.clipReg, llx, lly, urx, ury, BlendImageRectPix, data)
			END
		END
	END CopyImagePix;


	(*--- Draw Bitmap ---*)

	PROCEDURE Image (ctxt: Gfx.Context; x, y: FLOAT32; img: Images.Image; VAR filter: GfxImages.Filter);
		VAR dc: Context; m: GfxMatrix.Matrix; dx, dy, llx, lly, urx, ury: SIGNED16; x0, y0, x1, y1: FLOAT32; data: RegData;
	BEGIN
		dc := ctxt(Context);
		GfxMatrix.Translate(dc.ctm, x, y, m);
		dx := SHORT(ENTIER(m[2, 0])); m[2, 0] := m[2, 0] - dx;
		dy := SHORT(ENTIER(m[2, 1])); m[2, 1] := m[2, 1] - dy;
		IF (filter.hshift # GfxImages.NoFilter.hshift) & (0.1 < m[2, 0]) & (m[2, 0] < 0.9) OR
			(filter.vshift # GfxImages.NoFilter.vshift) & (0.1 < m[2, 1]) & (m[2, 1] < 0.9) OR
			GfxMatrix.Scaled(m) OR
			GfxMatrix.Rotated(m)
		THEN	(* transform into temporary image and copy from there *)
			GfxMatrix.ApplyToRect(m, 0, 0, img.width, img.height, x0, y0, x1, y1);
			llx := SHORT(ENTIER(x0)); lly := SHORT(ENTIER(y0));
			urx := -SHORT(ENTIER(-x1)); ury := -SHORT(ENTIER(-y1));
			GfxRegions.ClipRect(llx, lly, urx, ury, dc.clipReg.llx - dx, dc.clipReg.lly - dy, dc.clipReg.urx - dx, dc.clipReg.ury - dy);
			IF ~GfxRegions.RectEmpty(llx, lly, urx, ury) THEN
				Warp(dc, img, dx, dy, llx, lly, urx, ury, m, filter);
				data.dc := dc; data.img := Buffer; data.dx := dx + llx; data.dy := dy + lly;
				GfxRegions.Enumerate(dc.clipReg, data.dx, data.dy, dx + urx, dy + ury, BlendImageRect, data)
			END
		ELSE
			CopyImage(dc, img, dx, dy, filter)
		END
	END Image;


	(*--- Gfx Context Methods ---*)

	PROCEDURE ResetCTM (ctxt: Gfx.Context);
		VAR dc: Context;
	BEGIN
		dc := ctxt(Context);
		GfxMatrix.Translate(GfxMatrix.Identity, dc.orgX, dc.orgY, dc.ctm);
		GfxMatrix.Scale(dc.ctm, dc.scale, dc.scale, dc.ctm)
	END ResetCTM;

	PROCEDURE ResetClip (ctxt: Gfx.Context);
		VAR dc: Context;
	BEGIN
		dc := ctxt(Context);
		GfxRaster.ResetClip(dc);
		GfxRegions.Copy(dc.defClip, dc.clipReg)
	END ResetClip;

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
		do.image := Image; do.newPattern := Gfx.DefNewPattern;
		IF TransferBlock THEN
			BlendDot := BlendDotBlk; TileRect := TileRectBlk;
			BlendImageRect := DrawImageRectBlk;
			Warp := WarpBlk; CopyImage := CopyImageBlk
		ELSIF TrueColor THEN
			BlendDot := BlendDotRGB; TileRect := TileRectPix;
			CopyRun := CopyRunRGB; BlendRun := BlendRunRGB;
			BlendImageRect := BlendImageRectPix;
			Warp := WarpPix; CopyImage := CopyImagePix
		ELSE
			BlendDot := BlendDotIdx; TileRect := TileRectPix;
			CopyRun := CopyRunIdx; BlendRun := BlendRunIdx;
			BlendImageRect := BlendImageRectPix;
			Warp := WarpPix; CopyImage := CopyImagePix
		END
	END InitMethods;


	(*--- Exported Interface ---*)

	(** set default clip region to rectangle **)
	PROCEDURE SetClipRect* (dc: Context; llx, lly, urx, ury: SIGNED16);
	BEGIN
		GfxRegions.SetToRect(dc.defClip, llx, lly, urx, ury)
	END SetClipRect;

	(** copy given region to default clip region **)
	PROCEDURE SetClipRegion* (dc: Context; reg: GfxRegions.Region);
	BEGIN
		GfxRegions.Copy(reg, dc.defClip)
	END SetClipRegion;

	(** set default coordinate origin and scale factor **)
	PROCEDURE SetCoordinates* (dc: Context; x, y, scale: FLOAT32);
	BEGIN
		dc.orgX := x; dc.orgY := y; dc.scale := scale
	END SetCoordinates;

	(** set background color for display context **)
	PROCEDURE SetBGColor* (dc: Context; col: Gfx.Color);
	BEGIN
		dc.bg := col; Images.SetRGB(dc.bgPix, col.r, col.g, col.b);
		IF TrueColor THEN dc.bgCol := Display.RGB(col.r, col.g, col.b)
		ELSE dc.bgCol := Colors.Match(Colors.DisplayIndex, Colors.DisplayBits, col.r, col.g, col.b)
		END
	END SetBGColor;

	(** initialize display context to rectangle **)
	PROCEDURE Init* (dc: Context; llx, lly, urx, ury: SIGNED16);
	BEGIN
		GfxRaster.InitContext(dc);
		dc.do := Methods; dc.dot := Dot; dc.rect := Rect;
		IF TrueColor THEN dc.setColPat := SetColPatRGB
		ELSE dc.setColPat := SetColPatIdx
		END;
		Images.InitMode(dc.srcOverDst, Images.srcOverDst);
		NEW(dc.defClip); GfxRegions.Init(dc.defClip, GfxRegions.Winding);
		SetClipRect(dc, llx, lly, urx, ury);
		SetCoordinates(dc, llx, lly, 1);
		SetBGColor(dc, Gfx.White);
		Gfx.DefResetContext(dc)
	END Init;


BEGIN
	TrueColor := Display.TrueColor(Display.ColLeft);
	TransferBlock := Display.TransferFormat(Display.ColLeft) # Display.unknown;
	NEW(Buffer);
	InitMethods
END GfxDisplay.
