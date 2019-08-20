(* ETH Oberon, Copyright 2001 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

MODULE GfxBuffer; (** portable *)	(* eos  *)
(** AUTHOR "eos"; PURPOSE "Raster contexts rendering into background buffers"; *)

	(*
		10.12.98 - first version; derived from GfxDev
		25.8.99 - replaced GfxMaps with Images/GfxImages
		10.8.99 - scratched SetPoint, added Close method
		13.02.2000 - new get/set clip methods
		10.05.2000 - Rect now ignores empty rectangles
	*)


	IMPORT
		Images := Raster, GfxMatrix, GfxImages, GfxRegions, Gfx, GfxRaster;


	TYPE
		Context* = POINTER TO ContextDesc;
		ContextDesc* = RECORD (GfxRaster.ContextDesc)
			orgX*, orgY*: REAL;	(** origin of default coordinate system **)
			scale*: REAL;	(** default scale factor **)
			bgCol*: Gfx.Color;	(** background color for erasing **)
			img*: Images.Image;	(** target buffer **)
			pix: Images.Pixel;
			compOp:SHORTINT; (* composition operation for raster device *)
		END;

		RegData = RECORD (GfxRegions.EnumData)
			dx, dy: INTEGER;
			bc: Context;
			mode: Images.Mode;
		END;


	VAR
		Methods: Gfx.Methods;


	(*--- Rendering ---*)

	PROCEDURE Color (llx, lly, urx, ury: INTEGER; VAR data: GfxRegions.EnumData);
		VAR bc: Context; mode: Images.Mode;
	BEGIN
		bc := data(RegData).bc;
		Images.InitMode(mode, bc.compOp);
		Images.Fill(bc.img, llx, lly, urx, ury, bc.pix, mode)
	END Color;

	PROCEDURE Tile (llx, lly, urx, ury: INTEGER; VAR data: GfxRegions.EnumData);
		VAR bc: Context;
	BEGIN
		WITH data: RegData DO
			bc := data.bc;
			Images.FillPattern(bc.pat.img, bc.img, llx, lly, urx, ury, data.dx, data.dy, data.mode)
		END
	END Tile;

	PROCEDURE Dot (rc: GfxRaster.Context; x, y: LONGINT);
		VAR bc: Context; px, py: SIZE; mode: Images.Mode;
	BEGIN
		IF (rc.clipState = GfxRaster.In) OR
			(rc.clipState = GfxRaster.InOut) & GfxRegions.RectInside(INTEGER(x), INTEGER(y), INTEGER(x+1), INTEGER(y+1), rc.clipReg)
		THEN
			bc := rc(Context);
			IF bc.pat = NIL THEN
				Images.InitMode(mode, bc.compOp);
				Images.Put(bc.img, INTEGER(x), INTEGER(y), bc.pix, mode)
			ELSE
				px := (x - ENTIER(bc.orgX + bc.pat.px + 0.5)) MOD bc.pat.img.width;
				py := (y - ENTIER(bc.orgY + bc.pat.py + 0.5)) MOD bc.pat.img.height;
				Images.InitModeColor(mode, Images.srcOverDst, bc.col.r, bc.col.g, bc.col.b);
				Images.Copy(bc.pat.img, bc.img, px, py, px+1, py+1, INTEGER(x), INTEGER(y), mode)
			END
		END
	END Dot;

	PROCEDURE Rect (rc: GfxRaster.Context; llx, lly, urx, ury: LONGINT);
		VAR bc: Context; data: RegData; mode: Images.Mode;
	BEGIN
		IF (rc.clipState # GfxRaster.Out) & (llx < urx) & (lly < ury) THEN
			bc := rc(Context);
			IF bc.pat = NIL THEN
				IF rc.clipState = GfxRaster.In THEN
					Images.InitMode(mode, bc.compOp);
					Images.Fill(bc.img, SHORT(llx), SHORT(lly), SHORT(urx), SHORT(ury), bc.pix, mode)
				ELSE
					data.bc := bc;
					GfxRegions.Enumerate(bc.clipReg, SHORT(llx), SHORT(lly), SHORT(urx), SHORT(ury), Color, data)
				END
			ELSE
				data.bc := bc;
				data.dx := SHORT(ENTIER(bc.orgX + bc.pat.px + 0.5));
				data.dy := SHORT(ENTIER(bc.orgY + bc.pat.py + 0.5));
				Images.InitModeColor(data.mode, Images.srcOverDst, bc.col.r, bc.col.g, bc.col.b);
				GfxRegions.Enumerate(bc.clipReg, SHORT(llx), SHORT(lly), SHORT(urx), SHORT(ury), Tile, data)
			END
		END
	END Rect;

	PROCEDURE SetColPat (rc: GfxRaster.Context; col: Gfx.Color; pat: Gfx.Pattern);
		VAR bc: Context;
	BEGIN
		bc := rc(Context);
		bc.col := col; bc.pat := pat;
		Images.SetRGBA(bc.pix, col.r, col.g, col.b, col.a)
	END SetColPat;


	(*--- Methods ---*)

	PROCEDURE ResetCTM (ctxt: Gfx.Context);
		VAR bc: Context;
	BEGIN
		bc := ctxt(Context);
		GfxMatrix.Translate(GfxMatrix.Identity, bc.orgX, bc.orgY, bc.ctm);
		GfxMatrix.Scale(bc.ctm, bc.scale, bc.scale, bc.ctm)
	END ResetCTM;

	PROCEDURE ResetClip (ctxt: Gfx.Context);
		VAR bc: Context;
	BEGIN
		bc := ctxt(Context);
		GfxRaster.ResetClip(bc);
		GfxRegions.SetToRect(bc.clipReg, 0, 0, INTEGER(bc.img.width), INTEGER(bc.img.height))
	END ResetClip;

	PROCEDURE Image (ctxt: Gfx.Context; x, y: REAL; img: Images.Image; VAR filter: GfxImages.Filter);
		VAR bc: Context; m: GfxMatrix.Matrix; dx, dy, llx, lly, urx, ury: INTEGER; col: Images.Pixel;
	BEGIN
		bc := ctxt(Context);
		GfxMatrix.Translate(bc.ctm, x, y, m);
		dx := SHORT(ENTIER(m[2, 0] + 0.5));
		dy := SHORT(ENTIER(m[2, 1] + 0.5));
		col := filter.col;
		Images.SetModeColor(filter, bc.fillCol.r, bc.fillCol.g, bc.fillCol.b);
		IF (filter.hshift # GfxImages.hshift) & (dx + 0.1 < m[2, 0]) & (m[2, 0] < dx + 0.9) OR
			(filter.vshift # GfxImages.vshift) & (dy + 0.1 < m[2, 1]) & (m[2, 1] < dy + 0.9) OR
			GfxMatrix.Scaled(m) OR
			GfxMatrix.Rotated(m)
		THEN
			GfxImages.Transform(img, bc.img, m, filter)
		ELSE
			llx := 0; lly := 0; urx := INTEGER(img.width); ury := INTEGER(img.height);
			GfxRegions.ClipRect(llx, lly, urx, ury, bc.clipReg.llx - dx, bc.clipReg.lly - dy, bc.clipReg.urx - dx, bc.clipReg.ury - dy);
			IF bc.clipReg.llx >  dx THEN dx := bc.clipReg.llx END;
			IF bc.clipReg.lly > dy THEN dy := bc.clipReg.lly END;
			IF dx + urx > bc.img.width THEN urx := INTEGER(bc.img.width - dx) END;
			IF dy + ury > bc.img.height THEN ury := INTEGER(bc.img.height - dy) END;
			IF dx < 0 THEN llx := -dx; dx := 0 END;
			IF dy < 0 THEN lly := -dy; dy := 0 END;
			IF (llx < urx) & (lly < ury) THEN
				IF ~GfxRegions.RectEmpty(llx, lly, urx, ury) THEN
					Images.Copy(img, bc.img, llx, lly, urx, ury, dx, dy, filter)
				END
			END
		END;
		Images.SetModeColor(filter, ORD(col[Images.r]), ORD(col[Images.g]), ORD(col[Images.b]))
	END Image;

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
		do.show := GfxRaster.Show;
		do.flatten := Gfx.DefFlatten; do.outline := Gfx.DefOutline;
		do.render := GfxRaster.Render;
		do.rect := GfxRaster.Rect; do.ellipse := GfxRaster.Ellipse;
		do.image := Image; do.newPattern := Gfx.DefNewPattern;
	END InitMethods;


	(*--- Exported Interface ---*)

	(** set default coordinate origin and scale factor **)
	PROCEDURE SetCoordinates* (bc: Context; x, y, scale: REAL);
	BEGIN
		bc.orgX := x; bc.orgY := y; bc.scale := scale
	END SetCoordinates;

	(** set background color **)
	PROCEDURE SetBGColor* (bc: Context; col: Gfx.Color);
	BEGIN
		bc.bgCol := col
	END SetBGColor;

	(** set composition operation as defined in Raster **)
	PROCEDURE SetCompOp* (bc: Context; op:SHORTINT);
	BEGIN
		bc.compOp := op
	END SetCompOp;

	(** initialize buffered context **)
	PROCEDURE Init* (bc: Context; img: Images.Image);
	BEGIN
		GfxRaster.InitContext(bc);
		bc.compOp := 1; (* Copy Op is default *)
		bc.img := img; bc.do := Methods; bc.dot := Dot; bc.rect := Rect; bc.setColPat := SetColPat;
		SetCoordinates(bc, 0, 0, 1);
		SetBGColor(bc, Gfx.White);
		Gfx.DefResetContext(bc)
	END Init;


BEGIN
	InitMethods
END GfxBuffer.
