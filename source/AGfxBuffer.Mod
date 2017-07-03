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
		Context* = OBJECT(GfxRaster.Context)
		VAR
			orgX*, orgY*: REAL;	(** origin of default coordinate system **)
			scale*: REAL;	(** default scale factor **)
			bgCol*: Gfx.Color;	(** background color for erasing **)
			img*: Images.Image;	(** target buffer **)
			pix: Images.Pixel;
			compOp:SHORTINT; (* composition operation for raster device *)

			(** initialize buffered context **)
			PROCEDURE InitBuffer* (img: Images.Image);
			BEGIN
				InitRaster();
				SELF.compOp := 1; (* Copy Op is default *)
				SELF.img := img;
				SELF.SetCoordinates(0, 0, 1);
				SELF.SetBGColor(Gfx.White);
				SELF.Reset();
			END InitBuffer;

			(*--- Methods ---*)

			(** current transformation matrix **)
			PROCEDURE ResetCTM*();
			BEGIN
				GfxMatrix.Translate(GfxMatrix.Identity, SELF.orgX, SELF.orgY, SELF.ctm);
				GfxMatrix.Scale(SELF.ctm, SELF.scale, SELF.scale, SELF.ctm)
			END ResetCTM;

			(** clipping **)
			PROCEDURE ResetClip*();
			BEGIN
				ResetClip^();
				SELF.clipReg.SetToRect(0, 0, SHORT(SELF.img.width), SHORT(SELF.img.height))
			END ResetClip;

			(** images and patterns **)
			PROCEDURE Image* (x, y: REAL; img: Images.Image; VAR filter: GfxImages.Filter);
				VAR m: GfxMatrix.Matrix; dx, dy, llx, lly, urx, ury: INTEGER; col: Images.Pixel;
			BEGIN
				GfxMatrix.Translate(SELF.ctm, x, y, m);
				dx := SHORT(ENTIER(m[2, 0] + 0.5));
				dy := SHORT(ENTIER(m[2, 1] + 0.5));
				col := filter.col;
				Images.SetModeColor(filter, SELF.fillCol.r, SELF.fillCol.g, SELF.fillCol.b);
				IF (filter.hshift # GfxImages.hshift) & (dx + 0.1 < m[2, 0]) & (m[2, 0] < dx + 0.9) OR
					(filter.vshift # GfxImages.vshift) & (dy + 0.1 < m[2, 1]) & (m[2, 1] < dy + 0.9) OR
					GfxMatrix.Scaled(m) OR
					GfxMatrix.Rotated(m)
				THEN
					GfxImages.Transform(img, SELF.img, m, filter)
				ELSE
					llx := 0; lly := 0; urx := SHORT(img.width); ury := SHORT(img.height);
					GfxRegions.ClipRect(llx, lly, urx, ury, SELF.clipReg.llx - dx, SELF.clipReg.lly - dy, SELF.clipReg.urx - dx, SELF.clipReg.ury - dy);
					IF SELF.clipReg.llx >  dx THEN dx := SELF.clipReg.llx END;
					IF SELF.clipReg.lly > dy THEN dy := SELF.clipReg.lly END;
					IF dx + urx > SELF.img.width THEN urx := SHORT(SELF.img.width - dx) END;
					IF dy + ury > SELF.img.height THEN ury := SHORT(SELF.img.height - dy) END;
					IF dx < 0 THEN llx := -dx; dx := 0 END;
					IF dy < 0 THEN lly := -dy; dy := 0 END;
					IF (llx < urx) & (lly < ury) THEN
						IF ~GfxRegions.RectEmpty(llx, lly, urx, ury) THEN
							Images.Copy(img, SELF.img, llx, lly, urx, ury, dx, dy, filter)
						END
					END
				END;
				Images.SetModeColor(filter, ORD(col[Images.r]), ORD(col[Images.g]), ORD(col[Images.b]))
			END Image;

			PROCEDURE SetColPat* (col: Gfx.Color; pat: Gfx.Pattern);
			BEGIN
				SELF.col := col; SELF.pat := pat;
				Images.SetRGBA(SELF.pix, col.r, col.g, col.b, col.a)
			END SetColPat;

			PROCEDURE FillDot* (x, y: LONGINT);
				VAR px, py: LONGINT; mode: Images.Mode;
			BEGIN
				IF (SELF.clipState = GfxRaster.In) OR
					(SELF.clipState = GfxRaster.InOut) & SELF.clipReg.RectInside(SHORT(x), SHORT(y), SHORT(x+1), SHORT(y+1))
				THEN
					IF SELF.pat = NIL THEN
						Images.InitMode(mode, SELF.compOp);
						Images.Put(SELF.img, SHORT(x), SHORT(y), SELF.pix, mode)
					ELSE
						px := (x - ENTIER(SELF.orgX + SELF.pat.px + 0.5)) MOD SELF.pat.img.width;
						py := (y - ENTIER(SELF.orgY + SELF.pat.py + 0.5)) MOD SELF.pat.img.height;
						Images.InitModeColor(mode, Images.srcOverDst, SELF.col.r, SELF.col.g, SELF.col.b);
						Images.Copy(SELF.pat.img, SELF.img, px, py, px+1, py+1, SHORT(x), SHORT(y), mode)
					END
				END
			END FillDot;

			PROCEDURE FillRect* (llx, lly, urx, ury: LONGINT);
				VAR data: RegData; mode: Images.Mode;
			BEGIN
				IF (SELF.clipState # GfxRaster.Out) & (llx < urx) & (lly < ury) THEN
					IF SELF.pat = NIL THEN
						IF SELF.clipState = GfxRaster.In THEN
							Images.InitMode(mode, SELF.compOp);
							Images.Fill(SELF.img, SHORT(llx), SHORT(lly), SHORT(urx), SHORT(ury), SELF.pix, mode)
						ELSE
							data.bc := SELF;
							SELF.clipReg.Enumerate(SHORT(llx), SHORT(lly), SHORT(urx), SHORT(ury), Color, data)
						END
					ELSE
						data.bc := SELF;
						data.dx := SHORT(ENTIER(SELF.orgX + SELF.pat.px + 0.5));
						data.dy := SHORT(ENTIER(SELF.orgY + SELF.pat.py + 0.5));
						Images.InitModeColor(data.mode, Images.srcOverDst, SELF.col.r, SELF.col.g, SELF.col.b);
						SELF.clipReg.Enumerate(SHORT(llx), SHORT(lly), SHORT(urx), SHORT(ury), Tile, data)
					END
				END
			END FillRect;

			(*--- Exported Interface ---*)

			(** set default coordinate origin and scale factor **)
			PROCEDURE SetCoordinates* (x, y, scale: REAL);
			BEGIN
				SELF.orgX := x; SELF.orgY := y; SELF.scale := scale
			END SetCoordinates;

			(** set background color **)
			PROCEDURE SetBGColor* (col: Gfx.Color);
			BEGIN
				SELF.bgCol := col
			END SetBGColor;

			(** set composition operation as defined in Raster **)
			PROCEDURE SetCompOp* (op:SHORTINT);
			BEGIN
				SELF.compOp := op
			END SetCompOp;

		END Context;

		RegData = RECORD (GfxRegions.EnumData)
			dx, dy: INTEGER;
			bc: Context;
			mode: Images.Mode;
		END;


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

	(*--- Exported Interface ---*)

	(** set default coordinate origin and scale factor **)
	PROCEDURE SetCoordinates* (bc: Context; x, y, scale: REAL);
	BEGIN
		bc.SetCoordinates (x, y, scale);
	END SetCoordinates;

	(** set background color **)
	PROCEDURE SetBGColor* (bc: Context; col: Gfx.Color);
	BEGIN
		bc.SetBGColor (col);
	END SetBGColor;

	(** set composition operation as defined in Raster **)
	PROCEDURE SetCompOp* (bc: Context; op:SHORTINT);
	BEGIN
		bc.SetCompOp (op);
	END SetCompOp;

	(** initialize buffered context **)
	PROCEDURE Init* (bc: Context; img: Images.Image);
	BEGIN
		bc.InitBuffer(img);
	END Init;

END GfxBuffer.
