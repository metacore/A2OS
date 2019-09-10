(* ETH Oberon, Copyright 2001 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

MODULE BMPImages IN Oberon; (** portable **)	(* eos  *)

	(**
		Load and store Windows .BMP files
	**)

	(*
		- store files
		- support for JPEG and PNG compression in newer versions of file format
	*)

	IMPORT
		Files, Texts, Oberon, Images;


	CONST
		FileHeaderSize = 14;
		RGB = 0; RLE8 = 1; RLE4 = 2; BITFIELDS = 3;	(* compression *)


	VAR
		W: Texts.Writer;


	PROCEDURE Log (msg: ARRAY OF CHAR);
	BEGIN
		Texts.WriteString(W, "BMPImages: "); Texts.WriteString(W, msg); Texts.WriteLn(W); Texts.Append(Oberon.Log, W.buf)
	END Log;

	PROCEDURE LogInt (msg: ARRAY OF CHAR; val: SIGNED32);
		VAR i, j, n: SIGNED32; s: ARRAY 100 OF CHAR;
	BEGIN
		i := 0; WHILE msg[i] # "%" DO s[i] := msg[i]; INC(i) END; j := i+1;
		n := 1000000; WHILE n > val DO n := n DIV 10 END;
		WHILE n > 1 DO s[i] := CHR(ORD("0") + val DIV n); INC(i); val := val MOD n; n := n DIV 10 END;
		s[i] := CHR(ORD("0") + val); INC(i);
		WHILE msg[j] # 0X DO s[i] := msg[j]; INC(i); INC(j) END;
		s[i] := 0X;
		Log(s)
	END LogInt;

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

	PROCEDURE Load1 (img: Images.Image; w, h: SIGNED32; VAR pal: Images.Palette; VAR r: Files.Rider);
		VAR y, dy, x, p, b, i: SIGNED32; fmt: Images.Format; ch: CHAR;
	BEGIN
		IF h > 0 THEN y := 0; dy := 1
		ELSE h := -h; y := h-1; dy := -1
		END;
		Images.InitPaletteFormat(fmt, pal);
		Images.Create(img, SHORT(w), SHORT(h), fmt);
		WHILE h > 0 DO
			x := 0; p := y * img.bpr;
			WHILE x < w DO
				Files.Read(r, ch); b := ORD(ch);
				FOR i := -7 TO 0 DO
					IF x < w THEN
						img.mem[p] := CHR(ASH(b, i) MOD 2); INC(p)
					END;
					INC(x)
				END
			END;
			WHILE x MOD 32 # 0 DO Files.Read(r, ch); INC(x, 8) END;	(* align to double word boundary *)
			DEC(h); INC(y, dy)
		END
	END Load1;

	PROCEDURE Load4 (img: Images.Image; w, h, compression: SIGNED32; pal: Images.Palette; VAR r: Files.Rider);
		VAR y, dy, x, p, b, i: SIGNED32; fmt: Images.Format; ch: CHAR; col: ARRAY 2 OF CHAR;
	BEGIN
		IF h > 0 THEN y := 0; dy := 1
		ELSE h := -h; y := h-1; dy := -1
		END;
		Images.InitPaletteFormat(fmt, pal);
		Images.Create(img, SHORT(w), SHORT(h), fmt);
		WHILE h > 0 DO
			x := 0; p := y * img.bpr;
			WHILE x < w DO
				Files.Read(r, ch); b := ORD(ch);
				IF compression = RLE4 THEN
					Files.Read(r, ch);
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
						Files.Read(r, ch); INC(x, LONG(ORD(ch)));
						Files.Read(r, ch); INC(y, LONG(ORD(ch))); p := y * img.bpr + x
					ELSE	(* absolute mode *)
						b := ORD(ch);
						FOR i := 1 TO b DO
							IF ODD(i) THEN Files.Read(r, ch); img.mem[p] := CHR(ORD(ch) DIV 10H); INC(p)
							ELSE img.mem[p] := CHR(ORD(ch) MOD 10H); INC(p)
							END
						END;
						INC(x, b);
						IF ODD((b+1) DIV 2) THEN Files.Read(r, ch) END;	(* align run length to even number of bytes *)
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
				WHILE x MOD 8 # 0 DO Files.Read(r, ch); INC(x, 2) END	(* align to double word boundary *)
			END;
			DEC(h); INC(y, dy)
		END
	END Load4;

	PROCEDURE Load8 (img: Images.Image; w, h, compression: SIGNED32; pal: Images.Palette; VAR r: Files.Rider);
		VAR y, dy, x, p, b, i: SIGNED32; fmt: Images.Format; ch: CHAR;
	BEGIN
		IF h > 0 THEN y := 0; dy := 1
		ELSE h := -h; y := h-1; dy := -1
		END;
		Images.InitPaletteFormat(fmt, pal);
		Images.Create(img, SHORT(w), SHORT(h), fmt);
		WHILE h > 0 DO
			x := 0; p := y * img.bpr;
			WHILE x < w DO
				Files.Read(r, ch);
				IF compression = RLE8 THEN
					b := ORD(ch); Files.Read(r, ch);
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
						Files.Read(r, ch); INC(x, LONG(ORD(ch)));
						Files.Read(r, ch); INC(y, LONG(ORD(ch))); p := y * img.bpr + x
					ELSE	(* absolute mode *)
						b := ORD(ch);
						FOR i := 1 TO b DO
							Files.Read(r, img.mem[p]); INC(p)
						END;
						INC(x, b);
						IF ODD(b) THEN Files.Read(r, ch) END;	(* align run length to even number of bytes *)
					END
				ELSE	(* uncompressed *)
					img.mem[p] := ch; INC(p); INC(x)
				END
			END;
			IF compression = RGB THEN	(* is this also needed for RLE8 compression? *)
				WHILE x MOD 4 # 0 DO Files.Read(r, ch); INC(x) END	(* align to double word boundary *)
			END;
			DEC(h); INC(y, dy)
		END
	END Load8;

	PROCEDURE Load16 (img: Images.Image; w, h, compression, rMask, gMask, bMask: SIGNED32; VAR r: Files.Rider);
		VAR y, dy, x, p, val, red, green, blue: SIGNED32; convert: BOOLEAN; align: ARRAY 2 OF CHAR;
	BEGIN
		IF h > 0 THEN y := 0; dy := 1
		ELSE h := -h; y := h-1; dy := -1
		END;
		convert := FALSE;
		IF (compression = RGB) OR (compression = BITFIELDS) & (rMask = 7C00H) & (gMask = 3E0H) & (bMask = 1FH) THEN
			Images.Create(img, SHORT(w), SHORT(h), Images.BGR555)
		ELSIF (compression = BITFIELDS) & (rMask = 0F800H) & (gMask = 7E0H) & (bMask = 1FH) THEN
			Images.Create(img, SHORT(w), SHORT(h), Images.BGR565)
		ELSIF (compression = BITFIELDS) & (rMask = 0FC00H) & (gMask = 3F0H) & (bMask = 0FH) THEN
			Images.Create(img, SHORT(w), SHORT(h), Images.BGR466)
		ELSE
			Images.Create(img, SHORT(w), SHORT(h), Images.BGR565);
			convert := TRUE
		END;
		WHILE h > 0 DO
			x := 0; p := y * img.bpr;
			WHILE x < w DO
				Files.Read(r, img.mem[p]); Files.Read(r, img.mem[p+1]);
				IF convert THEN
					val := ORD(img.mem[p]) + ASH(ORD(img.mem[p+1]), 8);
					red := Unmask(val, rMask, 5); green := Unmask(val, gMask, 6); blue := Unmask(val, bMask, 5);
					val := blue + ASH(green, 5) + ASH(red, 11);
					img.mem[p] := CHR(val); img.mem[p+1] := CHR(val DIV 100H);
				END;
				INC(x); INC(p, 2)
			END;
			IF ODD(w) THEN Files.ReadBytes(r, align, 2) END;
			DEC(h); INC(y, dy)
		END
	END Load16;

	PROCEDURE Load24 (img: Images.Image; w, h: SIGNED32; VAR r: Files.Rider);
		VAR y, dy, x, p: SIGNED32; align: ARRAY 3 OF CHAR;
	BEGIN
		IF h > 0 THEN y := 0; dy := 1
		ELSE h := -h; y := h-1; dy := -1
		END;
		Images.Create(img, SHORT(w), SHORT(h), Images.BGR888);
		WHILE h > 0 DO
			x := 0; p := y * img.bpr;
			WHILE x < w DO
				Files.Read(r, img.mem[p]); Files.Read(r, img.mem[p+1]); Files.Read(r, img.mem[p+2]);
				INC(x); INC(p, 3)
			END;
			Files.ReadBytes(r, align, w MOD 4);
			DEC(h); INC(y, dy)
		END
	END Load24;

	PROCEDURE Load32 (img: Images.Image; w, h, compression, rMask, gMask, bMask: SIGNED32; VAR r: Files.Rider);
		VAR y, dy, x, p, val, red, green, blue: SIGNED32; convert: BOOLEAN; ch: CHAR;
	BEGIN
		IF h > 0 THEN y := 0; dy := 1
		ELSE h := -h; y := h-1; dy := -1
		END;
		Images.Create(img, SHORT(w), SHORT(h), Images.BGR888);
		convert := (compression = BITFIELDS) & ((rMask # 0FF0000H) OR (gMask # 0FF00H) OR (bMask # 0FFH));
		WHILE h > 0 DO
			x := 0; p := y * img.bpr;
			WHILE x < w DO
				Files.Read(r, img.mem[p]); Files.Read(r, img.mem[p+1]); Files.Read(r, img.mem[p+2]); Files.Read(r, ch);
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

	PROCEDURE Load (img: Images.Image; VAR fname: ARRAY OF CHAR; VAR done: BOOLEAN);
		VAR
			file: Files.File; r: Files.Rider; type: ARRAY 2 OF CHAR;
			size, reserved, offset, width, height, compression, colors, importantColors, col, redMask, greenMask, blueMask: SIGNED32;
			planes, bpp: SIGNED16; pal: Images.Palette; pix: Images.Pixel; ch: CHAR;
	BEGIN
		file := Files.Old(fname);
		IF file = NIL THEN RETURN END;
		Files.Set(r, file, 0);

		(* bitmap file header *)
		Files.ReadBytes(r, type, 2);
		IF (type[0] # "B") OR (type[1] # "M") THEN RETURN END;
		Files.ReadLInt(r, size); Files.ReadLInt(r, reserved); Files.ReadLInt(r, offset);

		(* bitmap info header *)
		Files.ReadLInt(r, size);	(* size of bitmap info header *)
		IF size > 28H THEN Log("ignoring extra header fields") END;
		Files.ReadLInt(r, width); Files.ReadLInt(r, height);
		Files.ReadInt(r, planes);
		IF planes # 1 THEN LogInt("don't know how to treat % planes", planes) END;
		Files.ReadInt(r, bpp);
		IF ~((bpp = 1) OR (bpp = 4) OR (bpp = 8) OR (bpp = 16) OR (bpp = 24) OR (bpp = 32)) THEN
			LogInt("can't deal with % bits per pixel", bpp); RETURN
		END;
		Files.ReadLInt(r, compression);
		IF ~(compression IN {RGB, RLE8, RLE4, BITFIELDS}) THEN
			LogInt("can't deal with compression type %", compression); RETURN
		END;
		Files.Set(r, file, Files.Pos(r) + 12); Files.ReadLInt(r, colors);
		IF (colors = 0) & (bpp < 16) THEN colors := ASH(1, bpp) END;
		Files.ReadLInt(r, importantColors);

		(* color table *)
		IF bpp < 16 THEN
			Files.Set(r, file, FileHeaderSize + size);
			NEW(pal); col := 0; pix[Images.a] := 0FFX;
			WHILE col < colors DO
				Files.Read(r, pix[Images.b]); Files.Read(r, pix[Images.g]); Files.Read(r, pix[Images.r]); Files.Read(r, ch);
				pal.col[col] := pix;
				INC(col)
			END;
			Images.InitPalette(pal, SHORT(colors), 2 + bpp DIV 4)
		ELSIF ((bpp = 16) OR (bpp = 32)) & (compression = BITFIELDS) THEN
			Files.ReadLInt(r, redMask); Files.ReadLInt(r, greenMask); Files.ReadLInt(r, blueMask)
		END;

		(* bitmap data *)
		Files.Set(r, file, offset);
		CASE bpp OF
		| 1: Load1(img, width, height, pal, r)
		| 4: Load4(img, width, height, compression, pal, r)
		| 8: Load8(img, width, height, compression, pal, r)
		| 16: Load16(img, width, height, compression, redMask, greenMask, blueMask, r)
		| 24: Load24(img, width, height, r)
		| 32: Load32(img, width, height, compression, redMask, greenMask, blueMask, r)
		END;

		done := TRUE
	END Load;

	PROCEDURE Store (img: Images.Image; VAR fname: ARRAY OF CHAR; VAR done: BOOLEAN);
	BEGIN
		Texts.WriteString(W, "(can't write .bmp yet)"); Texts.WriteLn(W); Texts.Append(Oberon.Log, W.buf)
	END Store;

	PROCEDURE Install*;
	BEGIN
		Images.LoadProc := Load; Images.StoreProc := Store
	END Install;


BEGIN
	Texts.OpenWriter(W)
END BMPImages.
