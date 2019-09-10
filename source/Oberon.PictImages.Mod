(* ETH Oberon, Copyright 2001 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

MODULE PictImages IN Oberon; (** non-portable *)	(* eos  **)

	(**
		Support for images in Oberon Picture format
	**)

	(*
		9.12.1998 - first release (together with GfxMaps)
		23.8.1999 - migrated from GfxPictures
		17.11.1999 - replaced F8 format by D8
		17.11.1999 - always use white/black for pictures with depth=1
		18.11.1999 - bugfix in run_length encoding (buf[0]+1 overflowed for buf[0]=127)
		19.11.1999 - don't dither when storing as picture
	*)

	IMPORT
		SYSTEM, Files, Display, Pictures, Colors, Images;


	CONST
		R = Images.r; G = Images.g; B = Images.b; A = Images.a;


	VAR
		PrntPat*: ARRAY 9 OF Display.Pattern;	(** printer patterns (same as in Printer3) **)
		PatPic: Pictures.Picture;	(* used for converting patterns to maps *)


	(**--- Oberon Pictures ---**)

	(** initialize image from picture by copying picture contents **)
	PROCEDURE PictToImage* (pict: Pictures.Picture; img: Images.Image);
		VAR
			idx, max, dr, dg, db, pr, pg, pb, y, x0, x1: SIGNED16; default: BOOLEAN; pal: Images.Palette;
			fmt: Images.Format; adr: ADDRESS;
	BEGIN
		(* check if palette matches fixed palette *)
		idx := 0; max := SIGNED16(ASH(1, pict.depth)); default := TRUE;
		WHILE (idx < max) & default DO
			Display.GetColor(idx, dr, dg, db);
			Pictures.GetColor(pict, idx, pr, pg, pb);
			default := (dr = pr) & (dg = pg) & (db = pb);
			INC(idx)
		END;

		IF default OR (max = 2) THEN	(* use display palette format *)
			Images.Create(img, pict.width, pict.height, Images.D8)
		ELSE	(* initialize specific palette *)
			NEW(pal); idx := 0;
			WHILE idx < max DO
				Pictures.GetColor(pict, idx, pr, pg, pb);
				Images.SetRGB(pal.col[idx], pr, pg, pb);
				INC(idx)
			END;
			Images.InitPalette(pal, max, 4);
			Images.InitPaletteFormat(fmt, pal);
			Images.Create(img, pict.width, pict.height, fmt)
		END;

		(* get picture contents *)
		y := 0; adr := img.adr;
		WHILE y < pict.height DO
			x0 := 0;
			WHILE x0 < pict.width DO
				x1 := x0;
				Pictures.GetRun(pict, idx, x1, y);
				IF (max = 2) & (idx = 1) THEN idx := 15 END;
				REPEAT SYSTEM.PUT(adr, CHR(idx)); INC(adr); INC(x0) UNTIL x0 = x1
			END;
			INC(y)
		END
	END PictToImage;

	(** initialize picture from map **)
	PROCEDURE ImageToPict* (img: Images.Image; pict: Pictures.Picture);
		VAR
			i, y, r, g, b, a, x, w: SIGNED16; pal: Images.Palette; fmt: Images.Format; byte: ARRAY 256 OF CHAR;
			int: ARRAY 256 OF SIGNED16;
	BEGIN
		Pictures.Create(pict, img.width, img.height, 8);	(* uses display palette *)
		IF img.fmt.pal # NIL THEN	(* modify picture palette *)
			i := 0; pal := img.fmt.pal;
			WHILE i < pal.used DO
				Images.GetRGBA(pal.col[i], r, g, b, a);
				Pictures.SetColor(pict, i, r, g, b);
				INC(i)
			END;
			Images.InitPaletteFormat(fmt, pal)
		ELSE
			fmt := Images.D8
		END;
		y := 0;
		WHILE y < img.height DO
			x := 0;
			WHILE x < img.width DO
				w := img.width - x;
				IF w > 256 THEN w := 256 END;
				Images.GetPixels(img, x, y, w, fmt, byte, Images.SrcCopy);
				FOR i := 0 TO w-1 DO
					int[i] := ORD(byte[i])
				END;
				Pictures.PutLine(pict, int, x, y, w);
				INC(x, w)
			END;
			INC(y)
		END
	END ImageToPict;

	(* pack/unpack procedures for 1 and 4 bit formats *)

	PROCEDURE PackP1 (VAR fmt: Images.Format0; adr: ADDRESS; bit: SIGNED32; VAR pix: Images.Pixel);
		VAR b: CHAR;
	BEGIN
		SYSTEM.GET(adr, b);
		IF ORD(pix[R]) + ORD(pix[G]) + ORD(pix[B]) >= 3*128 THEN
			IF ~ODD(ASH(ORD(b), -bit)) THEN
				SYSTEM.PUT(adr, CHR(ORD(b) + ASH(1, bit)))
			END
		ELSE
			IF ODD(ASH(ORD(b), -bit)) THEN
				SYSTEM.PUT(adr, CHR(ORD(b) - ASH(1, bit)))
			END
		END
	END PackP1;

	PROCEDURE UnpackP1 (VAR fmt: Images.Format0; adr: ADDRESS; bit: SIGNED32; VAR pix: Images.Pixel);
		VAR b: CHAR;
	BEGIN
		SYSTEM.GET(adr, b);
		IF ODD(ASH(ORD(b), -bit)) THEN pix[R] := 0X; pix[G] := 0X; pix[B] := 0X; pix[A] := 0FFX
		ELSE pix[R] := 0FFX; pix[G] := 0FFX; pix[B] := 0FFX; pix[A] := 0FFX
		END
	END UnpackP1;

	PROCEDURE PackP4 (VAR fmt: Images.Format0; adr: ADDRESS; bit: SIGNED32; VAR pix: Images.Pixel);
		VAR b: CHAR; i: SIGNED32;
	BEGIN
		SYSTEM.GET(adr, b);
		i := Images.PaletteIndex(fmt.pal, ORD(pix[R]), ORD(pix[G]), ORD(pix[B])) MOD 10H;
		IF bit = 0 THEN
			SYSTEM.PUT8(adr, CHR(ORD(b) - ORD(b) MOD 10H + i))
		ELSE
			SYSTEM.PUT8(adr, CHR(ORD(b) MOD 10H + 10H*i))
		END
	END PackP4;

	PROCEDURE UnpackP4 (VAR fmt: Images.Format0; adr: ADDRESS; bit: SIGNED32; VAR pix: Images.Pixel);
		VAR b: CHAR;
	BEGIN
		SYSTEM.GET(adr, b); pix := fmt.pal.col[ASH(ORD(b), -bit) MOD 10H]
	END UnpackP4;

	(* load Oberon picture from file *)
	PROCEDURE LoadPict (img: Images.Image; VAR fname: ARRAY OF CHAR; VAR done: BOOLEAN);
		VAR
			file: Files.File; r: Files.Rider; id, w, h, depth, dr, dg, db: SIGNED16; gen: ARRAY 64 OF CHAR; i, n: SIGNED32;
			default: BOOLEAN; red, green, blue: ARRAY 256 OF CHAR; pal: Images.Palette; adr, a: ADDRESS;
			fmt: Images.Format; byte: CHAR;
	BEGIN
		file := Files.Old(fname);
		IF file # NIL THEN
			Files.Set(r, file, 0); Files.ReadInt(r, id);
			IF id = 07F7H THEN	(* document *)
				Files.ReadString(r, gen); Files.Set(r, file, Files.Pos(r) + 4*2); Files.ReadInt(r, id)
			END;

			IF id = Pictures.PictFileId THEN
				Files.ReadInt(r, w); Files.ReadInt(r, h); Files.ReadInt(r, depth);

				(* load picture palette *)
				i := 0; n := ASH(1, depth); default := TRUE;
				WHILE i < n DO
					Files.Read(r, red[i]); Files.Read(r, green[i]); Files.Read(r, blue[i]);
					Display.GetColor(i, dr, dg, db);
					IF (red[i] # CHR(dr)) OR (green[i] # CHR(dg)) OR (blue[i] # CHR(db)) THEN
						default := FALSE
					END;
					INC(i)
				END;
				IF (depth # 1) OR ((depth # 8) OR ~default) THEN
					NEW(pal); i := 0;
					WHILE i < n DO
						Images.SetRGB(pal.col[i], ORD(red[i]), ORD(green[i]), ORD(blue[i]));
						INC(i)
					END;
					Images.InitPalette(pal, SHORT(n), 2 + depth DIV 4)
				END;

				(* initialize image *)
				IF depth = 1 THEN
					Images.InitFormat(fmt, Images.custom, 1, 1, {Images.index}, NIL, PackP1, UnpackP1)
				ELSIF depth = 4 THEN
					Images.InitFormat(fmt, Images.custom, 4, 1, {Images.index}, pal, PackP4, UnpackP4)
				ELSIF default THEN
					fmt := Images.D8
				ELSE
					Images.InitPaletteFormat(fmt, pal)
				END;
				Images.Create(img, w, h, fmt);

				(* load run-length encoded pixels *)
				adr := img.adr + h * img.bpr;
				WHILE h > 0 DO
					a := adr - img.bpr;
					WHILE a < adr DO
						Files.Read(r, byte); n := ORD(byte);
						IF n < 128 THEN
							REPEAT
								Files.Read(r, byte);
								SYSTEM.PUT(a, byte); INC(a);
								DEC(n)
							UNTIL n < 0
						ELSE
							n := 100H - n;
							Files.Read(r, byte);
							REPEAT
								SYSTEM.PUT(a, byte); INC(a);
								DEC(n)
							UNTIL n < 0
						END
					END;
					DEC(h); DEC(adr, img.bpr)
				END;

				done := TRUE
			END
		END
	END LoadPict;

	(* store Oberon picture *)
	PROCEDURE StorePict (img: Images.Image; VAR fname: ARRAY OF CHAR; VAR done: BOOLEAN);
		VAR
			file: Files.File; r: Files.Rider; pal: Images.Palette; i: SIGNED32; fmt: Images.Format; depth, y, inc, x: SIGNED16;
			pix: POINTER TO ARRAY OF CHAR; buf: ARRAY 129 OF SIGNED8;
	BEGIN
		file := Files.New(fname);
		IF file # NIL THEN
			Files.Set(r, file, 0);
			Files.WriteInt(r, Pictures.PictFileId);
			Files.WriteInt(r, img.width); Files.WriteInt(r, img.height);

			(* find out which format to use *)
			pal := img.fmt.pal;
			IF (img.fmt.components = {Images.index}) & (pal # NIL) THEN	(* contains index information *)
				IF img.fmt.bpp > 4 THEN
					Images.InitPaletteFormat(fmt, pal);
					depth := 8
				ELSIF img.fmt.bpp > 1 THEN
					Images.InitFormat(fmt, Images.custom, 4, 1, {Images.index}, pal, PackP4, UnpackP4);
					depth := 4
				ELSE
					Images.InitFormat(fmt, Images.custom, 1, 1, {Images.index}, pal, PackP1, UnpackP1);
					depth := 1
				END
			ELSE	(* calculate palette *)
				NEW(pal);
				FOR i := 0 TO 15 DO
					Images.SetRGB(pal.col[i], Colors.Red[i], Colors.Green[i], Colors.Blue[i])
				END;
				Images.ComputePalette(img, pal, 16, 240, 4);
				Images.InitPaletteFormat(fmt, pal);
				depth := 8
			END;

			(* write palette *)
			Files.WriteInt(r, depth);
			i := 0;
			WHILE i < ASH(1, depth) DO
				Files.Write(r, pal.col[i, R]); Files.Write(r, pal.col[i, G]); Files.Write(r, pal.col[i, B]);
				INC(i)
			END;

			(* write run-length encoded pixels *)
			NEW(pix, img.width); y := img.height; inc := 8 DIV depth;
			WHILE y > 0 DO
				DEC(y);
				Images.GetPixels(img, 0, y, img.width, fmt, pix^, Images.SrcCopy);
				buf[0] := 0; buf[1] := SHORT(ORD(pix[0])); x := inc; i := 1;
				WHILE x < img.width DO
					IF buf[0] < 0 THEN	(* accumulating equal bytes *)
						IF (buf[0] > -128) & (pix[i] = CHR(buf[1])) THEN
							DEC(buf[0])
						ELSE
							Files.WriteBytes(r, buf, 2);
							buf[0] := 0; buf[1] := SHORT(ORD(pix[i]))
						END
					ELSIF buf[0] > 0 THEN	(* accumulating different bytes *)
						IF buf[0] = 127 THEN	(* buffer full *)
							Files.WriteBytes(r, buf, buf[0]+2);
							buf[0] := 0; buf[1] := SHORT(ORD(pix[i]))
						ELSIF pix[i] # pix[i-1] THEN
							INC(buf[0]); buf[LONG(buf[0])+1] := SHORT(ORD(pix[i]))
						ELSE
							DEC(buf[0]);
							Files.WriteBytes(r, buf, buf[0]+2);
							buf[0] := -1; buf[1] := SHORT(ORD(pix[i]))
						END
					ELSIF pix[i] = CHR(buf[1]) THEN	(* starting to accumulate equal bytes *)
						buf[0] := -1
					ELSE	(* starting to accumulate different bytes *)
						buf[0] := 1; buf[2] := SHORT(ORD(pix[i]))
					END;
					INC(x, inc); INC(i)
				END;
				IF buf[0] >= 0 THEN Files.WriteBytes(r, buf, buf[0]+2)
				ELSE Files.WriteBytes(r, buf, 2)
				END
			END;

			Files.Register(file);
			done := TRUE
		END
	END StorePict;

	(** install load/store procedures for handling Oberon pictures **)
	PROCEDURE Install*;
	BEGIN
		Images.LoadProc := LoadPict; Images.StoreProc := StorePict
	END Install;


	(**--- Oberon Patterns ---**)

	(** create image from Oberon pattern (format=A1; pattern is copied) **)
	PROCEDURE PatternToImage* (pat: Display.Pattern; img: Images.Image);
		VAR w, h, y, x: SIGNED16; pix: Images.Pixel;
	BEGIN
		ASSERT(pat # 0, 100);
		IF (1 <= pat) & (pat <= 8) THEN pat := PrntPat[pat] END;
		Display.GetDim(pat, w, h);
		Images.Create(img, w, h, Images.A1);

		(* it seems that the only portable way to access a pattern is to render it into a picture first *)
		IF PatPic = NIL THEN NEW(PatPic) END;
		IF (PatPic.width < w) OR (PatPic.height < h) THEN Pictures.Create(PatPic, w, h, 1) END;
		Pictures.ReplConst(PatPic, 0, 0, 0, w, h, Display.replace);
		Pictures.CopyPattern(PatPic, 1, pat, 0, 0, Display.paint);

		y := 0; pix[A] := 0FFX;
		WHILE y < h DO
			x := 0;
			WHILE x < w DO
				IF Pictures.Get(PatPic, x, y) # 0 THEN
					Images.Put(img, x, y, pix, Images.SrcCopy)
				END;
				INC(x)
			END;
			INC(y)
		END
	END PatternToImage;

	(** create Oberon pattern from image **)
	PROCEDURE ImageToPattern* (img: Images.Image; VAR pat: Display.Pattern);
		VAR w, y, x, i, j: SIGNED16; s: POINTER TO ARRAY OF SET; pix: Images.Pixel;
	BEGIN
		w := -((-img.width) DIV 32);
		NEW(s, w * img.height);
		y := 0;
		WHILE y < img.height DO
			x := 0; i := y * w; j := 0;
			WHILE x < img.width DO
				Images.Get(img, x, y, pix, Images.SrcCopy);
				IF pix[A] >= 80X THEN
					INCL(s[i], j)
				END;
				INC(x);
				IF x MOD 32 = 0 THEN INC(i); j := 0 END
			END;
			INC(y)
		END;
		pat := Display.NewPattern(img.width, img.height, s^)
	END ImageToPattern;

	(* initialize printer patterns *)
	PROCEDURE InitPatterns;
		VAR pat: ARRAY 8 OF SET; i: SIGNED32;
	BEGIN
		(* adapted from Printer3 *)
		pat[0] := {}; pat[1] := {}; pat[2] := {}; pat[3] := {0,4,8,12,16,20,24,28};
		FOR i := 0 TO 3 DO pat[4 + i] := pat[i] END;
		PrntPat[1] := Display.NewPattern(32, 8, pat);
		pat[0] := {0,4,8,12,16,20,24,28}; pat[1] := {}; pat[2] := {2,6,10,14,18,22,26,30}; pat[3] := {};
		FOR i := 0 TO 3 DO pat[4 + i] := pat[i] END;
		PrntPat[2] := Display.NewPattern(32, 8, pat);
		pat[0] := {}; pat[1] := {0,2,4,6,8,10,12,14,16,18,20,22,24,26,28,30};
		FOR i := 0 TO 5 DO pat[2 + i] := pat[i] END;
		PrntPat[3] := Display.NewPattern(32, 8, pat);
		pat[0] := {0,4,8,12,16,20,24,28}; pat[1] := {2,6,10,14,18,22,26,30};
		FOR i := 0 TO 5 DO pat[2 + i] := pat[i] END;
		PrntPat[4] := Display.NewPattern(32, 8, pat);
		PrntPat[5] := Display.solid;
		pat[0] := {0,4,8,12,16,20,24,28}; pat[1] := {1,5,9,13,17,21,25,29};
		pat[2] := {2,6,10,14,18,22,26,30}; pat[3] := {3,7,11,15,19,23,27,31};
		FOR i := 0 TO 3 DO pat[4 + i] := pat[i] END;
		PrntPat[6] := Display.NewPattern(32, 8, pat);
		pat[0] := {3,7,11,15,19,23,27,31}; pat[1] := {2,6,10,14,18,22,26,30};
		pat[2] := {1,5,9,13,17,21,25,29}; pat[3] := {0,4,8,12,16,20,24,28};
		FOR i := 0 TO 3 DO pat[4 + i] := pat[i] END;
		PrntPat[7] := Display.NewPattern(32, 8, pat);
		FOR i := 0 TO 7 DO pat[i] := {0,4,8,12,16,20,24,28} END;
		PrntPat[8] := Display.NewPattern(32, 8, pat)
	END InitPatterns;


BEGIN
	InitPatterns
END PictImages.
