MODULE BMPCodec; (** AUTHOR "eos,afi,tf"; PURPOSE "BMP Codec"; *)

(* some of the load and store routines look suspicious but i dont have the spec right now *)
(* 2008-02-15 : pboenhof : fixing SkipBytes values in BMPDecoder.Open (in.received had been used instead of in.Pos()) *)
IMPORT
	Codecs, KernelLog, Streams, WMGraphics, Raster, Strings;


CONST
	FileHeaderSize = 14;
	RGB = 0; RLE8 = 1; RLE4 = 2; BITFIELDS = 3;	(* compression *)


TYPE
	BMPDecoder = OBJECT(Codecs.ImageDecoder)
	VAR errors : BOOLEAN;
		in : Streams.Reader;
		size, reserved, offset, width, height, compression, colors, importantColors, col, redMask, greenMask, blueMask: SIGNED32;
		planes, bpp: SIGNED16; pal: Raster.Palette;
		img : Raster.Image;
		decoded : BOOLEAN;

		PROCEDURE Error(x : ARRAY OF CHAR);
		BEGIN
			KernelLog.String("BMP Decoder Error: ");
			KernelLog.String(x); KernelLog.Ln;
			errors := TRUE
		END Error;

		PROCEDURE Log(x : ARRAY OF CHAR);
		BEGIN
			KernelLog.String("BMP Decoder Info: ");
			KernelLog.String(x); KernelLog.Ln;
		END Log;

		(* open the decoder on a file *)
		PROCEDURE Open*(in : Streams.Reader; VAR res : INTEGER);
		VAR
			pix: Raster.Pixel; ch: CHAR;
		BEGIN
			errors := FALSE;
			decoded := FALSE;
			res := -1;
			IF in = NIL THEN Error("Input Stream is NIL"); RETURN END;
			SELF.in := in;

			(* bitmap file header *)
			IF (in.Get() # "B") OR (in.Get() # "M") THEN Error("Not a BMP stream"); RETURN END;

			in.RawLInt(size); in.RawLInt(reserved); in.RawLInt(offset);

			(* bitmap info header *)
			in.RawLInt(size);	(* size of bitmap info header *)
			IF size > 40 THEN Log("ignoring extra header fields") END;
			in.RawLInt(width); in.RawLInt(height);
			in.RawInt(planes);
			IF planes # 1 THEN Error("Can not handle multi-plane files"); RETURN  END;
			in.RawInt(bpp);
			IF ~((bpp = 1) OR (bpp = 4) OR (bpp = 8) OR (bpp = 16) OR (bpp = 24) OR (bpp = 32)) THEN
				 Log("Can not handle this bpp."); KernelLog.String("bpp = "); KernelLog.Int(bpp, 0); KernelLog.Ln; RETURN
			END;
			in.RawLInt(compression);
			IF ~(compression IN {RGB, RLE8, RLE4, BITFIELDS}) THEN
				Log("can't deal with compression type "); KernelLog.String("compression = "); KernelLog.Int(compression, 0); RETURN
			END;
			in.SkipBytes(12); in.RawLInt(colors);
			IF (colors = 0) & (bpp < 16) THEN colors := ASH(1, bpp) END;
			in.RawLInt(importantColors);

			(* 54 bytes consumed by "in" up to here *)

			(* color table *)
			IF bpp < 16 THEN
				in.SkipBytes(FileHeaderSize + size - in.Pos());
				NEW(pal); col := 0; pix[Raster.a] := 0FFX;
				WHILE col < colors DO
					in.Char(pix[Raster.b]); in.Char(pix[Raster.g]); in.Char(pix[Raster.r]); in.Char(ch);
					pal.col[col] := pix;
					INC(col)
				END;
				Raster.InitPalette(pal, SHORT(colors), 2 + bpp DIV 4)
			ELSIF ((bpp = 16) OR (bpp = 32)) & (compression = BITFIELDS) THEN
				in.RawLInt(redMask); in.RawLInt(greenMask); in.RawLInt(blueMask)
			END;
			NEW(img);
			(* bitmap data *)
			in.SkipBytes(offset - in.Pos());
			res := 0;
		END Open;

		PROCEDURE GetImageInfo*(VAR width, height : SIZE; VAR format, maxProgressionLevel : SIGNED32);
		BEGIN
			width := SELF.width;
			height := SELF.height;
		END GetImageInfo;

		(** Render will read and decode the image data up to progrssionLevel.
			If the progressionLevel is lower than a previously rendered progressionLevel,
			the new level can be ignored by the decoder. If no progressionLevel is set with
			SetProgressionLevel, the level is assumed to be maxProgressionLevel of the image,
			which corresponds to best image quality.
		 *)
		PROCEDURE SetProgressionLevel*(progressionLevel: SIGNED32);
		END SetProgressionLevel;

		(* return the image in Raster format that best matches the format *)
		PROCEDURE GetNativeImage*(VAR img : Raster.Image);
		BEGIN
			IF ~decoded & ~errors THEN
				img := SELF.img;
				CASE bpp OF
				| 1: Load1(img, width, height, pal, in)
				| 4: Load4(img, width, height, compression, pal, in)
				| 8: Load8(img, width, height, compression, pal, in)
				| 16: Load16(img, width, height, compression, redMask, greenMask, blueMask, in)
				| 24: Load24(img, width, height, in)
				| 32: Load32(img, width, height, compression, redMask, greenMask, blueMask, in)
				END;
				decoded := TRUE
			END
		END GetNativeImage;

		(* renders the image into the given Raster.Image at the given progressionLevel *)
		PROCEDURE Render*(img : Raster.Image);
		VAR canvas : WMGraphics.BufferCanvas;
		BEGIN
			GetNativeImage(SELF.img);
			IF ~errors THEN
				NEW(canvas, img);
				canvas.DrawImage(0, 0, SELF.img, WMGraphics.ModeCopy);
			END
		END Render;
	END BMPDecoder;

	BMPEncoder* = OBJECT(Codecs.ImageEncoder)
	VAR out : Streams.Writer;

		(* open the encoder on a Streams writer *)
		PROCEDURE Open*(out : Streams.Writer);
		BEGIN
			SELF.out := out
		END Open;

		PROCEDURE SetQuality*(quality : SIGNED32);
		END SetQuality;

		PROCEDURE WriteImage*(img : Raster.Image; VAR res : INTEGER);
		VAR
			col, redMask, greenMask, blueMask: SIGNED32;
			palentries, dataSize: SIGNED32; bpp: SIGNED16;
			sm: Strings.Buffer;
			buf : Streams.Writer;
			data : Strings.String;
		BEGIN
			IF img.fmt.pal # NIL THEN palentries := img.fmt.pal.used ELSE palentries := 0 END;

			NEW(sm, img.width * img.height * 4); (* conservative *)
			buf := sm.GetWriter();
			(* Bitmap data *)
			IF img.fmt.code = Raster.bgra8888 THEN Store32(img, img.width, -img.height, redMask, greenMask, blueMask, buf)
			ELSIF img.fmt.code = Raster.bgr888 THEN Store24(img, img.width, -img.height, buf)
			ELSIF img.fmt.code = Raster.bgr466 THEN Store16(img, img.width, -img.height, redMask, greenMask, blueMask, buf)
			ELSIF img.fmt.code = Raster.bgr555 THEN Store16(img, img.width, -img.height, redMask, greenMask, blueMask, buf)
			ELSIF img.fmt.code = Raster.bgr565 THEN Store16(img, img.width, -img.height, redMask, greenMask, blueMask, buf)
			ELSIF img.fmt.pal.used = 256 THEN Store8(img, img.width, -img.height, buf)
			ELSIF img.fmt.pal.used = 16 THEN Store4(img, img.width, -img.height, buf)
			ELSIF img.fmt.pal.used = 2 THEN Store1(img, img.width, -img.height, buf)
			END;
			dataSize := sm.GetLength()(SIGNED32);

			(* Bitmap file header *)
			out.String("BM");
			IF (img.fmt.code = Raster.bgra8888) OR (img.fmt.code = Raster.bgr888) OR (img.fmt.code = Raster.bgr466) OR
				(img.fmt.code = Raster.bgr555) OR (img.fmt.code = Raster.bgr565)
			THEN
				(* additional size of color masks *)
				out.RawLInt(12 + 14 + 40 + palentries * 4 + dataSize); out.RawLInt(0); out.RawLInt(12 + 14 + 40 + palentries * 4);
			ELSE
				out.RawLInt(14 + 40 + palentries * 4 + dataSize); out.RawLInt(0); out.RawLInt(14 + 40 + palentries * 4);
			END;

			(* Bitmap info header *)
			out.RawLInt(40); (* header size *)
			out.RawLInt(img.width(SIGNED32));
			out.RawLInt(img.height(SIGNED32));
			out.RawInt(1);	(* biPlanes *)
			IF img.fmt.pal # NIL THEN
				CASE img.fmt.pal.used OF
					  2: bpp := 1
					| 16: bpp := 4
					| 256: bpp := 8
				ELSE
				END
			ELSIF (img.fmt.code = Raster.bgr565) OR (img.fmt.code = Raster.bgr555) OR (img.fmt.code = Raster.bgr466) THEN
				bpp := 16
			ELSIF img.fmt.code = Raster.bgr888 THEN bpp := 24
			ELSIF img.fmt.code = Raster.bgra8888 THEN bpp := 32
			END;
			out.RawInt(bpp);	(* biBitCount *)
			(* biCompression *)
			CASE img.fmt.code OF
				  Raster.bgr565: out.RawLInt(BITFIELDS)	(* BITFIELDS compression *)
				| Raster.bgr555: out.RawLInt(BITFIELDS)	(* BITFIELDS compression *)
				| Raster.bgr466: out.RawLInt(BITFIELDS)	(* BITFIELDS compression *)
				| Raster.bgra8888: out.RawLInt(BITFIELDS)	(* BITFIELDS compression *)
			ELSE
				out.RawLInt(0)
			END;
			out.RawLInt(dataSize);(* biSizeImage *)
			out.RawLInt(0);(* biXPelsPerMeter *)
			out.RawLInt(0);(* biYPelsPerMeter *)
			IF img.fmt.pal # NIL THEN
				out.RawLInt(img.fmt.pal.used);	(* biClrUsed *)
				out.RawLInt(img.fmt.pal.used);	(* biClrImportant *)
				(* RGBQUAD color table *)
				col := 0;
				WHILE col < img.fmt.pal.used DO
					out.Char(img.fmt.pal.col[col, Raster.b]);
					out.Char(img.fmt.pal.col[col, Raster.g]);
					out.Char(img.fmt.pal.col[col, Raster.r]);
					out.Char(0X);
					INC(col)
				END
			ELSE
				out.RawLInt(0);
				out.RawLInt(0)
			END;

			CASE img.fmt.code OF
				  Raster.bgr565: out.RawLInt(0F800H); out.RawLInt(07E0H); out.RawLInt(01FH)
				| Raster.bgr555: out.RawLInt(07C00H); out.RawLInt(03E0H); out.RawLInt(01FH)
				| Raster.bgr466: out.RawLInt(0FC00H); out.RawLInt(03F0H); out.RawLInt(00FH)
				| Raster.bgr888: out.RawLInt(0FF00H); out.RawLInt(0FF0H); out.RawLInt(0FFH)
				| Raster.bgra8888: out.RawLInt(0FF0000H); out.RawLInt(0FF00H); out.RawLInt(0FFH)
			ELSE
			END;

			data := sm.GetString();
			out.Bytes(data^, 0, sm.GetLength());

			res := 0;
			out.Update
		END WriteImage;

	END BMPEncoder;

PROCEDURE Unmask (val, mask, nbits: SIGNED32): SIGNED32;
	VAR res, m, bits: SIGNED32;
BEGIN
	res := val; m := mask; bits := 0;
	WHILE (m # 0) & ~ODD(m) DO	(* shift down to first valid bit *)
		m := m DIV 2; res := res DIV 2
	END;
	WHILE ODD(m) DO	(* count valid bits *)
		m := m DIV 2; INC(bits)
	END;
	res := res MOD ASH(1, bits);	(* mask out everything else *)
	WHILE bits > nbits DO	(* reduce to requested number of bits *)
		res := res DIV 2; DEC(bits)
	END;
	WHILE bits < nbits DO	(* blow up to requested number of bits *)
		res := 2*res+1; INC(bits)
	END;
	RETURN res
END Unmask;

PROCEDURE Load1 (img: Raster.Image; w, h: SIGNED32; VAR pal: Raster.Palette; r : Streams.Reader);
	VAR y, dy, x, b, i: SIGNED32; p: SIZE; fmt: Raster.Format;
BEGIN
	IF h > 0 THEN y := 0; dy := 1
	ELSE h := -h; y := h-1; dy := -1
	END;
	Raster.InitPaletteFormat(fmt, pal);
	Raster.Create(img, w, h, fmt);
	WHILE h > 0 DO
		x := 0; p := (img.height - y - 1) * img.bpr;
		WHILE x < w DO
			b := ORD(r.Get());
			FOR i := -7 TO 0 DO
				IF x < w THEN
					img.mem[p] := CHR(ASH(b, i) MOD 2); INC(p)
				END;
				INC(x)
			END
		END;
		WHILE x MOD 32 # 0 DO r.SkipBytes(1); INC(x, 8) END;	(* align to double word boundary *)
		DEC(h); INC(y, dy)
	END
END Load1;

PROCEDURE Load4 (img: Raster.Image; w, h, compression: SIGNED32; pal: Raster.Palette; r: Streams.Reader);
	VAR y, dy, x, b, i: SIGNED32; fmt: Raster.Format; ch: CHAR; col: ARRAY 2 OF CHAR; p: SIZE;
BEGIN
	IF h > 0 THEN y := 0; dy := 1
	ELSE h := -h; y := h-1; dy := -1
	END;
	Raster.InitPaletteFormat(fmt, pal);
	Raster.Create(img, w, h, fmt);
	WHILE h > 0 DO
		x := 0; p := (img.height - y - 1) * img.bpr;
		WHILE x < w DO
			b := ORD(r.Get());
			IF compression = RLE4 THEN
				r.Char(ch);
				IF b # 0 THEN	(* encoded mode *)
					i := 0; col[0] := CHR(ORD(ch) DIV 10H); col[1] := CHR(ORD(ch) MOD 10H);
					WHILE i < b DO
						img.mem[p] := col[i MOD 2]; INC(i); INC(p)
					END;
					INC(x, b)
				ELSIF ch = 0X THEN	(* end of line *)
					DEC(h); INC(y, dy); x := 0; p := y * img.bpr	(* align to double word boundary? *)
				ELSIF ch = 1X THEN	(* end of bitmap data *)
					RETURN
				ELSIF ch = 2X THEN	(* delta record *)
					r.Char(ch); INC(x, LONG(ORD(ch)));
					r.Char(ch); INC(y, LONG(ORD(ch))); p := y * img.bpr + x
				ELSE	(* absolute mode *)
					b := ORD(ch);
					FOR i := 1 TO b DO
						IF ODD(i) THEN r.Char(ch); img.mem[p] := CHR(ORD(ch) DIV 10H); INC(p)
						ELSE img.mem[p] := CHR(ORD(ch) MOD 10H); INC(p)
						END
					END;
					INC(x, b);
					IF ODD((b+1) DIV 2) THEN r.Char(ch) END;	(* align run length to even number of bytes *)
				END
			ELSE	(* uncompressed *)
				img.mem[p] := CHR(b DIV 10H); INC(p);
				IF x+1 < w THEN
					img.mem[p] := CHR(b MOD 10H); INC(p)
				END;
				INC(x, 2)
			END
		END;
		IF compression = RGB THEN	(* is this also needed for RLE4 compression? *)
			WHILE x MOD 8 # 0 DO r.SkipBytes(1);  INC(x, 2) END	(* align to double word boundary *)
		END;
		DEC(h); INC(y, dy)
	END
END Load4;

PROCEDURE Load8 (img: Raster.Image; w, h, compression: SIGNED32; pal: Raster.Palette; r: Streams.Reader);
	VAR y, dy, x, b, i: SIGNED32; fmt: Raster.Format; ch: CHAR; p: SIZE;
BEGIN
	IF h > 0 THEN y := 0; dy := 1
	ELSE h := -h; y := h-1; dy := -1
	END;
	Raster.InitPaletteFormat(fmt, pal);
	Raster.Create(img, SHORT(w), SHORT(h), fmt);
	WHILE h > 0 DO
		x := 0; p := (img.height - y - 1) * img.bpr;
		WHILE x < w DO
			r.Char(ch);
			IF compression = RLE8 THEN
				b := ORD(ch); r.Char(ch);
				IF b # 0 THEN	(* encoded mode *)
					FOR i := 1 TO b DO
						img.mem[p] := ch; INC(p)
					END;
					INC(x, b)
				ELSIF ch = 0X THEN	(* end of line *)
					DEC(h); INC(y, dy); x := 0; p := y * img.bpr	(* align to double word boundary? *)
				ELSIF ch = 1X THEN	(* end of bitmap data *)
					RETURN
				ELSIF ch = 2X THEN	(* delta record *)
					r.Char(ch); INC(x, LONG(ORD(ch)));
					r.Char(ch); INC(y, LONG(ORD(ch))); p := y * img.bpr + x
				ELSE	(* absolute mode *)
					b := ORD(ch);
					FOR i := 1 TO b DO
						r.Char(img.mem[p]); INC(p)
					END;
					INC(x, b);
					IF ODD(b) THEN r.Char(ch) END;	(* align run length to even number of bytes *)
				END
			ELSE	(* uncompressed *)
				img.mem[p] := ch; INC(p); INC(x)
			END
		END;
		IF compression = RGB THEN	(* is this also needed for RLE8 compression? *)
			WHILE x MOD 4 # 0 DO r.SkipBytes(1); INC(x) END	(* align to double word boundary *)
		END;
		DEC(h); INC(y, dy)
	END
END Load8;

PROCEDURE Load16 (img: Raster.Image; w, h, compression, rMask, gMask, bMask: SIGNED32; r: Streams.Reader);
	VAR y, dy, x, val, red, green, blue: SIGNED32; convert: BOOLEAN; p: SIZE;
BEGIN
	IF h > 0 THEN y := 0; dy := 1
	ELSE h := -h; y := h-1; dy := -1
	END;
	convert := FALSE;
	IF (compression = RGB) OR (compression = BITFIELDS) & (rMask = 7C00H) & (gMask = 3E0H) & (bMask = 1FH) THEN
		Raster.Create(img, SHORT(w), SHORT(h), Raster.BGR555)
	ELSIF (compression = BITFIELDS) & (rMask = 0F800H) & (gMask = 7E0H) & (bMask = 1FH) THEN
		Raster.Create(img, SHORT(w), SHORT(h), Raster.BGR565)
	ELSIF (compression = BITFIELDS) & (rMask = 0FC00H) & (gMask = 3F0H) & (bMask = 0FH) THEN
		Raster.Create(img, SHORT(w), SHORT(h), Raster.BGR466)
	ELSE
		Raster.Create(img, SHORT(w), SHORT(h), Raster.BGR565);
		convert := TRUE
	END;
	WHILE h > 0 DO
		x := 0; p := (img.height - y - 1) * img.bpr;
		WHILE x < w DO
			r.Char(img.mem[p]); r.Char(img.mem[p+1]);
			IF convert THEN
				val := ORD(img.mem[p]) + ASH(ORD(img.mem[p+1]), 8);
				red := Unmask(val, rMask, 5); green := Unmask(val, gMask, 6); blue := Unmask(val, bMask, 5);
				val := blue + ASH(green, 5) + ASH(red, 11);
				img.mem[p] := CHR(val); img.mem[p+1] := CHR(val DIV 100H);
			END;
			INC(x); INC(p, 2)
		END;
		IF ODD(w) THEN r.SkipBytes(2) END;
		DEC(h); INC(y, dy)
	END
END Load16;

PROCEDURE Load24 (img: Raster.Image; w, h: SIGNED32; r: Streams.Reader);
	VAR y, dy, x: SIGNED32; p: SIZE;
BEGIN
	IF h > 0 THEN y := 0; dy := 1
	ELSE h := -h; y := h-1; dy := -1
	END;
	Raster.Create(img, SHORT(w), SHORT(h), Raster.BGR888);
	WHILE h > 0 DO
		x := 0; p := (img.height - y - 1) * img.bpr;
		WHILE x < w DO
			r.Char(img.mem[p]); r.Char(img.mem[p+1]); r.Char(img.mem[p+2]);
			INC(x); INC(p, 3)
		END;
		r.SkipBytes(w MOD 4);
		DEC(h); INC(y, dy)
	END
END Load24;

PROCEDURE Load32 (img: Raster.Image; w, h, compression, rMask, gMask, bMask: SIGNED32; r: Streams.Reader);
	VAR y, dy, x, val, red, green, blue: SIGNED32; convert: BOOLEAN; ch: CHAR; p: SIZE;
BEGIN
	IF h > 0 THEN y := 0; dy := 1
	ELSE h := -h; y := h-1; dy := -1
	END;
	Raster.Create(img, SHORT(w), SHORT(h), Raster.BGR888);
	convert := (compression = BITFIELDS) & ((rMask # 0FF0000H) OR (gMask # 0FF00H) OR (bMask # 0FFH));
	WHILE h > 0 DO
		x := 0; p := (img.height - y - 1)  * img.bpr;
		WHILE x < w DO
			r.Char(img.mem[p]); r.Char(img.mem[p+1]); r.Char(img.mem[p+2]); r.Char(ch);
			IF convert THEN
				val := ORD(img.mem[p]) + ASH(ORD(img.mem[p+1]), 8) + ASH(ORD(img.mem[p+2]), 16) + ASH(ORD(ch), 24);
				red := Unmask(val, rMask, 8); green := Unmask(val, gMask, 8); blue := Unmask(val, bMask, 8);
				img.mem[p] := CHR(blue); img.mem[p+1] := CHR(green); img.mem[p+2] := CHR(red)
			END;
			INC(x); INC(p, 3)
		END;
		DEC(h); INC(y, dy)
	END
END Load32;

PROCEDURE Store1 (img: Raster.Image; w, h: SIZE; out : Streams.Writer);
	VAR y, dy, x, b, i: SIZE; p: SIZE;
BEGIN
	IF h > 0 THEN y := 0; dy := 1
	ELSE h := -h; y := h-1; dy := -1
	END;
	WHILE h > 0 DO
		x := 0; p := y * img.bpr;
		WHILE x < w DO
			b := 0;
			FOR i := -7 TO 0 DO
				IF x < w THEN b := ASH(b, 1) + ORD(img.mem[p]); INC(p) END;
				INC(x)
			END;
			out.Char(CHR(b))
		END;
		WHILE x MOD 32 # 0 DO out.Char(0X); INC(x, 8) END;	(* Align to double word boundary *)
		DEC(h); INC(y, dy)
	END
END Store1;

PROCEDURE Store4 (img: Raster.Image; w, h: SIZE; out : Streams.Writer);
	VAR y, dy, x, b: SIZE; p: SIZE;
BEGIN
	IF h > 0 THEN y := 0; dy := 1
	ELSE h := -h; y := h-1; dy := -1
	END;
	WHILE h > 0 DO
		x := 0; p := y * img.bpr;
		WHILE x < w DO
			b := 0;
			b := ORD(img.mem[p]) MOD 10H; INC(p);
			IF x+1 < w THEN
				b := ASH(b, 4) + ORD(img.mem[p]) MOD 10H; INC(p)
			END;
			out.Char(CHR(b));
			INC(x, 2)
		END;
		DEC(h); INC(y, dy)
	END
END Store4;

PROCEDURE Store8 (img: Raster.Image; w, h: SIZE; out : Streams.Writer);
	VAR y, dy, x: SIZE; p: SIZE;
BEGIN
	IF h > 0 THEN y := 0; dy := 1
	ELSE h := -h; y := h-1; dy := -1
	END;
	WHILE h > 0 DO
		x := 0; p := y * img.bpr;
		WHILE x < w DO
			out.Char(img.mem[p]);
			INC(p); INC(x)
		END;
		DEC(h); INC(y, dy)
	END
END Store8;

PROCEDURE Store16 (img: Raster.Image; w, h: SIZE; rMask, gMask, bMask: SIGNED32; out : Streams.Writer);
	VAR y, dy, x: SIZE; p: SIZE;
BEGIN
	IF h > 0 THEN y := 0; dy := 1
	ELSE h := -h; y := h-1; dy := -1
	END;
	WHILE h > 0 DO
		x := 0; p := y * img.bpr;
		out.Bytes(img.mem^, p, w * 2);
		IF ODD(w) THEN out.Char(0X); out.Char(0X) END;
		DEC(h); INC(y, dy)
	END
END Store16;

PROCEDURE Store24 (img: Raster.Image; w, h: SIZE; out : Streams.Writer);
	VAR y, dy, x: SIZE; align: ARRAY 3 OF CHAR; p: SIZE;
BEGIN
	IF h > 0 THEN y := 0; dy := 1
	ELSE h := -h; y := h-1; dy := -1
	END;
	WHILE h > 0 DO
		x := 0; p := y * img.bpr;
		WHILE x < w DO
			out.Char(img.mem[p]); out.Char(img.mem[p+1]); out.Char(img.mem[p+2]);
			INC(x); INC(p, 3)
		END;
		out.Bytes(align, 0, w MOD 4);
		DEC(h); INC(y, dy)
	END
END Store24;

PROCEDURE Store32 (img: Raster.Image; w, h: SIZE; rMask, gMask, bMask: SIGNED32; out : Streams.Writer);
	VAR y, dy, x: SIZE; p: SIZE;
BEGIN
	IF h > 0 THEN y := 0; dy := 1
	ELSE h := -h; y := h-1; dy := -1
	END;
	WHILE h > 0 DO
		x := 0; p := y * img.bpr;
		WHILE x < w DO
			out.Char(img.mem[p]); out.Char(img.mem[p+1]); out.Char(img.mem[p+2]); out.Char(img.mem[p+3]);
			INC(x); INC(p, 4)
		END;
		DEC(h); INC(y, dy)
	END
END Store32;

PROCEDURE DecoderFactory*() : Codecs.ImageDecoder;
VAR p : BMPDecoder;
BEGIN
	NEW(p);
	RETURN p
END DecoderFactory;

PROCEDURE EncoderFactory*() : Codecs.ImageEncoder;
VAR p : BMPEncoder;
BEGIN
	NEW(p);
	RETURN p
END EncoderFactory;

END BMPCodec.
