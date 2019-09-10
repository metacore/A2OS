(* ETH Oberon, Copyright 2001 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

MODULE GfxPKFonts IN Oberon; (** portable *)	(* eos  *)

	(**
		Make TeX's packed raster fonts available to Gfx
	**)

	(*
		22.02.2000 - made name matching more robust to be compatible with device specifiers in Native
		23.02.2000 - downscale large bitmaps by halving them as long as they are at least twice the requested size
	*)

	IMPORT
		Files, FileDir, Math IN A2, Display, Strings, Images, GfxMatrix, GfxImages, GfxPaths, GfxFonts;


	TYPE
		Base = POINTER TO BaseDesc;
		BaseDesc = RECORD
			next: Base;
			name: ARRAY 32 OF CHAR;	(* TeX font file name *)
			ptsize: SIGNED16;	(* original point size of TeX font *)
			scale: FLOAT32;	(* scale factor from default to font coordinates (dpi/91.44) *)
			xmin, ymin, xmax, ymax: SIGNED32;	(* union of character bounding boxes *)
			(*wscale: FLOAT32;*)	(* scale factor for character widths *)
			flag: ARRAY 256 OF CHAR;	(* character flag byte *)
			pos: ARRAY 256 OF SIGNED32;	(* character start position *)
			buf: POINTER TO ARRAY OF CHAR;	(* packed character descriptions *)
		END;

		Font* = POINTER TO FontDesc;
		FontDesc* = RECORD (GfxFonts.FontDesc)
			base: Base;	(* pk font where font is derived from *)
			bmat: GfxMatrix.Matrix;	(* matrix to apply to base characters *)
			fmt: Images.Format;	(* format to use for character maps *)
		END;


	VAR
		Bases: Base;	(* base cache *)
		Src, Dst: Images.Image;	(* temporary maps *)
		Inv: ARRAY 100H OF CHAR;	(* inverted bit patterns *)

		Class: GfxFonts.Methods;

		SizeScale, BestSizeScale, BestScale: FLOAT32;
		Name: ARRAY 32 OF CHAR;
		BestSize: SIGNED32;


	(*--- Bases ---*)

	PROCEDURE InitInv;
		VAR i, b, j: SIGNED32;
	BEGIN
		FOR i := 0 TO 0FFH DO
			b := 0;
			FOR j := 0 TO 7 DO
				IF ODD(ASH(i, j-7)) THEN INC(b, ASH(1, j)) END
			END;
			Inv[i] := CHR(b)
		END
	END InitInv;

	PROCEDURE GetBaseWidth (base: Base; ch: CHAR; VAR dx, dy: SIGNED32);
		VAR pos: SIGNED32;	(* tfm, n: SIGNED32;*)
	BEGIN
		pos := base.pos[ORD(ch)];
		IF pos >= 0 THEN
			CASE ORD(base.flag[ORD(ch)]) MOD 8 OF
			| 0..3:	(* short format *)
				dx := ORD(base.buf[pos+3]); dy := 0
			| 4..6:	(* extended short format *)
				dx := 100H*ORD(base.buf[pos+3]) + ORD(base.buf[pos+4]); dy := 0
			| 7:	(* long format *)
				dx := 100H*ORD(base.buf[pos+4]) + ORD(base.buf[pos+5]);
				dy := 100H*ORD(base.buf[pos+8]) + ORD(base.buf[pos+9]);
			END;
			(*
			tfm := 0;
			IF ORD(base.flag[ORD(ch)]) MOD 8 = 7 THEN n := 4	(* long format *)
			ELSE n := 3	(* short or extended-short format *)
			END;
			REPEAT
				tfm := 100H*tfm + ORD(base.buf[pos]); INC(pos); DEC(n)
			UNTIL n = 0;
			RETURN base.wscale * (tfm/ASH(1, 20))
			*)
		ELSE
			dx := 0; dy := 0
		END
	END GetBaseWidth;

	PROCEDURE GetBaseDim (base: Base; ch: CHAR; VAR x, y, w, h: SIGNED32);
		VAR pos, i: SIGNED32;
	BEGIN
		pos := base.pos[ORD(ch)];
		IF pos >= 0 THEN
			CASE ORD(base.flag[ORD(ch)]) MOD 8 OF
			| 0..3:	(* short format *)
				INC(pos, 4);
				w := ORD(base.buf[pos]); INC(pos);
				h := ORD(base.buf[pos]); INC(pos);
				x := -((ORD(base.buf[pos]) + 80H) MOD 100H - 80H); INC(pos);
				y := (ORD(base.buf[pos]) + 80H) MOD 100H - 80H - (h-1)
			| 4..6:	(* extended short format *)
				INC(pos, 5);
				w := 100H*ORD(base.buf[pos]) + ORD(base.buf[pos+1]); INC(pos, 2);
				h := 100H*ORD(base.buf[pos]) + ORD(base.buf[pos+1]); INC(pos, 2);
				x := -(100H*((ORD(base.buf[pos]) + 80H) MOD 100H - 80H) + ORD(base.buf[pos+1])); INC(pos, 2);
				y := (100H*((ORD(base.buf[pos]) + 80H) MOD 100H - 80H) + ORD(base.buf[pos+1])) - (h-1)
			| 7:	(* long format *)
				INC(pos, 12); w := 0; h := 0; x := 0; y := 0;
				FOR i := 1 TO 4 DO w := 100H*w + ORD(base.buf[pos]); INC(pos) END;
				FOR i := 1 TO 4 DO h := 100H*h + ORD(base.buf[pos]); INC(pos) END;
				FOR i := 1 TO 4 DO x := 100H*x - ORD(base.buf[pos]); INC(pos) END;
				FOR i := 1 TO 4 DO y := 100H*y + ORD(base.buf[pos]); INC(pos) END;
				DEC(y, h-1)
			END
		ELSE
			x := 0; y := 0; w := 0; h := 0
		END
	END GetBaseDim;

	PROCEDURE GetBaseMap (base: Base; ch: CHAR; VAR x, y: SIGNED32; VAR map: Images.Image);
		VAR pos, w, h, dynf, j, bit, len, bits, i, repeat, byte: SIGNED32; buf: ARRAY 32 OF CHAR; set: BOOLEAN;

		PROCEDURE getnib (VAR nib: SIGNED32);
		BEGIN
			IF bit = 0 THEN byte := ORD(base.buf[pos]); INC(pos); nib := byte DIV 16; bit := 4
			ELSE nib := byte MOD 16; bit := 0
			END
		END getnib;

		PROCEDURE getlen (VAR len: SIGNED32);
			VAR digits, nib: SIGNED32;
		BEGIN
			getnib(len);
			IF len = 0 THEN	(* large run *)
				digits := 0;
				REPEAT
					INC(digits); getnib(len)
				UNTIL len # 0;
				WHILE digits > 0 DO
					getnib(nib); len := 16*len + nib; DEC(digits)
				END;
				len := len - 15 + 16*(13 - dynf) + dynf
			ELSIF len >= 14 THEN	(* set repeat count *)
				ASSERT(repeat = 0, 110);
				repeat := 1;	(* assert that multiple repeat counts in a row will trap *)
				IF len = 14 THEN
					getlen(repeat)
				END;
				getlen(len)
			ELSIF len > dynf THEN	(* two-nibble length *)
				getnib(nib);
				len := 16*(len - dynf - 1) + nib + dynf + 1
			END
		END getlen;

		PROCEDURE fill (i, j, len: SIGNED32);
		BEGIN
			IF set THEN
				WHILE len > 8*LEN(buf) DO
					Images.Copy(Src, Dst, 0, 0, 8*LEN(buf), 1, SHORT(i), SHORT(j), Images.SrcCopy);
					INC(i, 8*LEN(buf)); DEC(len, 8*LEN(buf))
				END;
				Images.Copy(Src, Dst, 0, 0, SHORT(len), 1, SHORT(i), SHORT(j), Images.SrcCopy)
			END
		END fill;

	BEGIN
		pos := base.pos[ORD(ch)];
		IF pos >= 0 THEN
			GetBaseDim(base, ch, x, y, w, h);
			IF w * h # 0 THEN
				Images.Create(Dst, SHORT(w), SHORT(h), Images.A1);
				CASE ORD(base.flag[ORD(ch)]) MOD 8 OF
				| 0..3: INC(pos, 8)	(* short format *)
				| 4..6: INC(pos, 13)	(* extended short format *)
				| 7: INC(pos, 28)	(* long format *)
				END;
				Images.InitBuf(Src, 8*LEN(buf), 1, Images.A1, LEN(buf), 0, buf);
				dynf := ORD(base.flag[ORD(ch)]) DIV 10H;
				IF dynf = 14 THEN	(* bitmapped character data (no runs) *)
					j := h; bit := 0; len := 0; bits := 0;
					WHILE j > 0 DO
						DEC(j); i := 0;
						WHILE i + bits < w DO
							IF len = LEN(buf) THEN	(* flush buffer *)
								Images.Copy(Src, Dst, SHORT(bit), 0, SHORT(bits), 1, SHORT(i), SHORT(j), Images.SrcCopy);
								INC(i, bits); bits := 0; bit := 0; len := 0
							END;
							buf[len] := Inv[ORD(base.buf[pos])]; INC(len); INC(pos); INC(bits, 8)
						END;
						Images.Copy(Src, Dst, SHORT(bit), 0, SHORT(bit + w - i), 1, SHORT(i), SHORT(j), Images.SrcCopy);
						bit := (bit + w - i) MOD 8;
						IF bit = 0 THEN len := 0; bits := 0
						ELSE buf[0] := buf[len-1]; len := 1; bits := 8-bit
						END
					END
				ELSE	(* decode runs *)
					set := ODD(ORD(base.flag[ORD(ch)]) DIV 8);
					FOR len := 0 TO LEN(buf)-1 DO buf[len] := 0FFX END;	(* source for black runs *)
					repeat := 0; bit := 0;	(* used and modified in getlen *)
					j := h-1; i := 0;
					REPEAT
						getlen(len);
						IF i + len < w THEN	(* stay in same row *)
							fill(i, j, len); INC(i, len)
						ELSE	(* advance to next row *)
							fill(i, j, w - i); DEC(len, w - i);	(* complete current row *)
							WHILE repeat > 0 DO	(* duplicate row *)
								Images.Copy(Dst, Dst, 0, SHORT(j), SHORT(w), SHORT(j+1), 0, SHORT(j-1), Images.SrcCopy);
								DEC(j); DEC(repeat)
							END;
							DEC(j);
							WHILE len >= w DO	(* fill complete rows *)
								fill(0, j, w); DEC(len, w); DEC(j)
							END;
							IF len > 0 THEN
								fill(0, j, len)
							END;
							i := len
						END;
						set := ~set
					UNTIL j < 0
				END;
				map := Dst
			ELSE
				map := NIL
			END
		ELSE
			map := NIL
		END
	END GetBaseMap;

	PROCEDURE LoadBase (VAR name: ARRAY OF CHAR): Base;
		VAR
			base: Base; file: Files.File; r: Files.Rider; ch, id, flag: CHAR; i, pos, dsize, hppp, n, cc, xmin, ymin, xmax, ymax: SIGNED32;
			buf: ARRAY 4 OF CHAR;
	BEGIN
		base := NIL;
		file := Files.Old(name);	(* supposed to exist *)
		Files.Set(r, file, 0);
		Files.Read(r, ch); Files.Read(r, id);
		IF (ch = CHR(247)) & (id = CHR(89)) THEN
			NEW(base); NEW(base.buf, Files.Length(file));	(* longer than necessary :-( *)
			FOR i := 0 TO 0FFH DO base.pos[i] := -1 END;	(* mark as not present *)
			pos := 0;	(* offset into buffer *)
			Files.Read(r, ch); Files.Set(r, file, 3 + ORD(ch));	(* skip comment *)
			Files.ReadBytes(r, buf, 4); dsize := ASH(ORD(buf[0]), 24) + ASH(ORD(buf[1]), 16) + ASH(ORD(buf[2]), 8) + ORD(buf[0]);
			Files.ReadBytes(r, buf, 4);	(* skip checksum *)
			Files.ReadBytes(r, buf, 4); hppp := ASH(ORD(buf[0]), 24) + ASH(ORD(buf[1]), 16) + ASH(ORD(buf[2]), 8) + ORD(buf[0]);
			Files.ReadBytes(r, buf, 4);	(* skip vppp *)
			(*base.wscale := (dsize/ASH(1, 20)) * (hppp/ASH(1, 16));*)
			LOOP
				Files.Read(r, ch);
				WHILE ch >= CHR(240) DO	(* skip commands *)
					CASE ORD(ch) OF
					| 240..243:	(* pkxxx1..pkxxx4 *)
						n := 0; FOR i := 240 TO ORD(ch) DO Files.Read(r, ch); n := 100H*n + ORD(ch) END;
						Files.Set(r, file, Files.Pos(r) + n)
					| 244:	(* pkyyy *)
						Files.ReadBytes(r, buf, 4)
					| 245:	(* pkpost *)
						EXIT
					| 246:	(* pknoop *)
					ELSE	(* uh oh! something's wrong *)
						RETURN NIL
					END;
					Files.Read(r, ch)
				END;
				flag := ch; n := ORD(flag) MOD 8;
				CASE n OF
				| 0..3:	(* short format *)
					Files.Read(r, ch); n := 100H*n + ORD(ch);
					Files.Read(r, ch); cc := ORD(ch)
				| 4..6:	(* extended short format *)
					Files.Read(r, ch); n := 100H*(n-4) + ORD(ch);
					Files.Read(r, ch); n := 100H*n + ORD(ch);
					Files.Read(r, ch); cc := ORD(ch)
				| 7:	(* long format *)
					n := 0; FOR i := 1 TO 4 DO Files.Read(r, ch); n := 100H*n + ORD(ch) END;
					Files.ReadBytes(r, buf, 4);	(* character code *)
					IF (buf[0] = 0X) & (buf[1] = 0X) & (buf[2] = 0X) THEN cc := ORD(buf[3])
					ELSE cc := -1	(* can't specify character codes > 256 *)
					END
				END;
				IF cc >= 0 THEN
					base.flag[cc] := flag; base.pos[cc] := pos;
					FOR i := 1 TO n DO
						Files.Read(r, base.buf[pos]); INC(pos)
					END
				ELSE
					Files.Set(r, file, Files.Pos(r) + n)	(* skip character definition *)
				END
			END;	(* LOOP *)

			(* calculate bounding box *)
			base.xmin := MAX(SIGNED32); base.ymin := MAX(SIGNED32); base.xmax := MIN(SIGNED32); base.ymax := MIN(SIGNED32);
			FOR i := 0 TO 0FFH DO
				GetBaseDim(base, CHR(i), xmin, ymin, xmax, ymax);
				IF xmax * ymax # 0 THEN
					INC(xmax, xmin); INC(ymax, ymin);
					IF xmin < base.xmin THEN base.xmin := xmin END;
					IF ymin < base.ymin THEN base.ymin := ymin END;
					IF xmax > base.xmax THEN base.xmax := xmax END;
					IF ymax > base.ymax THEN base.ymax := ymax END
				END
			END
		END;
		RETURN base
	END LoadBase;


	PROCEDURE EnumFile (name: ARRAY OF CHAR; time, date, size: SIGNED32; VAR continue: BOOLEAN);
		CONST isDir = FALSE;
		VAR i, pt, dpi: SIGNED32; scale, pts: FLOAT32;

	BEGIN
		IF ~isDir THEN
			i := 0; pt := 0;
			WHILE (name[i] # 0X) & (name[i] < "0") OR ("9" < name[i]) DO INC(i) END;
			WHILE ("0" <= name[i]) & (name[i] <= "9") DO
				pt := 10*pt + ORD(name[i]) - ORD("0");
				INC(i)
			END;
			IF (pt # 0) & (name[i] = ".") THEN
				INC(i); dpi := 0;
				WHILE ("0" <= name[i]) & (name[i] <= "9") DO
					dpi := 10*dpi + ORD(name[i]) - ORD("0");
					INC(i)
				END;
				IF dpi # 0 THEN
					scale := dpi * (Display.Unit/914400); pts := pt * scale;
					IF (BestSizeScale < 0) OR (BestSizeScale < pts) & (pts <= SizeScale) OR (SizeScale <= pts) & (pts < BestSizeScale) THEN
						COPY(name, Name); BestSize := pt; BestScale := scale; BestSizeScale := pts;
						continue := (pts = SizeScale)
					END
				END
			END
		END
	END EnumFile;

	PROCEDURE OpenBase (VAR name: ARRAY OF CHAR; ptsize: SIGNED16; scale: FLOAT32): Base;
		VAR size: ARRAY 6 OF CHAR; pat: ARRAY 64 OF CHAR; base: Base;
	BEGIN
		(* first try with correct point size *)
		SizeScale := ptsize * scale; BestSizeScale := -1; Name := "";
		Strings.IntToStr(ptsize, size);
		COPY(name, pat); Strings.Append(pat, size); Strings.Append(pat, "*pk");

		FileDir.Enumerate(pat, FALSE, EnumFile);


		(* try any font of requested family (problematic because encoding may be different, e.g. cmr5 # cmr10) *)
		IF Name = "" THEN
			COPY(name, pat); Strings.Append(pat, "*pk");

			FileDir.Enumerate(pat, FALSE, EnumFile)

		END;

		IF Name # "" THEN
			(* go through cache *)
			base := Bases;
			WHILE base # NIL DO
				IF base.name = Name THEN
					RETURN base
				END;
				base := base.next
			END;

			(* load pk font *)
			base := LoadBase(Name);
			IF base # NIL THEN
				COPY(Name, base.name); base.ptsize := SHORT(BestSize); base.scale := BestScale;
				base.next := Bases; Bases := base
			END
		END;
		RETURN base
	END OpenBase;


	(*--- Fonts ---*)

	PROCEDURE Derive (gfont: GfxFonts.Font; ptsize: SIGNED16; VAR mat: GfxMatrix.Matrix): GfxFonts.Font;
	BEGIN
		RETURN NIL	(* base cache avoids multiple loading of same file *)
	END Derive;

	PROCEDURE GetWidth (gfont: GfxFonts.Font; ch: CHAR; VAR dx, dy: FLOAT32);
		VAR font: Font; bdx, bdy: SIGNED32;
	BEGIN
		font := gfont(Font);
		GetBaseWidth(font.base, ch, bdx, bdy);
		GfxMatrix.ApplyToVector(font.bmat, bdx, bdy, dx, dy)
	END GetWidth;

	PROCEDURE GetMap (gfont: GfxFonts.Font; ch: CHAR; VAR x, y, dx, dy: FLOAT32; VAR map: Images.Image);
		VAR font: Font; bdx, bdy, bx, by: SIGNED32; bmap, tmp: Images.Image; m: GfxMatrix.Matrix; llx, lly, urx, ury: FLOAT32;
	BEGIN
		font := gfont(Font);
		GetBaseWidth(font.base, ch, bdx, bdy);
		GfxMatrix.ApplyToVector(font.bmat, bdx, bdy, dx, dy);
		GetBaseMap(font.base, ch, bx, by, bmap);
		IF bmap = NIL THEN
			map := NIL
		ELSE
			m := font.bmat; tmp := bmap;
			WHILE GfxMatrix.Det(m) <= 0.25 DO
				NEW(map); Images.Create(map, (tmp.width+1) DIV 2, (tmp.height+1) DIV 2, Images.A8);
				GfxImages.Scale(tmp, map, 0.5, 0.5, 0, 0, GfxImages.LinearFilter);
				GfxMatrix.Scale(m, 2, 2, m);
				tmp := map
			END;
			GfxMatrix.ApplyToVector(font.bmat, bx, by, x, y);
			GfxMatrix.ApplyToRect(font.bmat, 0, 0, bmap.width, bmap.height, llx, lly, urx, ury);
			NEW(map); Images.Create(map, -SHORT(ENTIER(llx - urx)), -SHORT(ENTIER(lly - ury)), font.fmt);
			m[2, 0] := m[2, 0] - llx; m[2, 1] := m[2, 1] - lly;
			GfxImages.Transform(tmp, map, m, GfxImages.LinearFilter);
			x := x + llx; y := y + lly
		END
	END GetMap;

	PROCEDURE GetOutline (gfont: GfxFonts.Font; ch: CHAR; x, y: FLOAT32; path: GfxPaths.Path);
		VAR font: Font; bx, by, bw, bh: SIGNED32; llx, lly, urx, ury, l: FLOAT32;
	BEGIN
		font := gfont(Font);
		GfxPaths.Clear(path);
		GetBaseDim(font.base, ch, bx, by, bw, bh);
		IF bw * bh # 0 THEN
			GfxMatrix.ApplyToVector(font.bmat, bx, by, llx, lly);
			GfxMatrix.ApplyToVector(font.bmat, bx + bw, by + bh, urx, ury);
			l := 0.1*(ury - lly);
			GfxPaths.AddRect(path, x + llx, y + lly, x + urx, y + ury);
			GfxPaths.AddRect(path, x + llx + l, y + ury - l, x + urx - l, y + lly + l)
		END
	END GetOutline;

	PROCEDURE Open* (VAR family, style: ARRAY OF CHAR; ptsize: SIGNED16; VAR mat: GfxMatrix.Matrix): GfxFonts.Font;
		VAR font: Font; name: ARRAY 64 OF CHAR; scale, xmin, ymin, xmax, ymax: FLOAT32; base: Base;
	BEGIN
		font := NIL;
		COPY(family, name); Strings.Append(name, style);
		scale := Math.sqrt(ABS(GfxMatrix.Det(mat)));
		base := OpenBase(name, ptsize, scale);
		IF base # NIL THEN
			NEW(font); font.class := Class; font.base := base; font.niceMaps := TRUE;
			scale := ptsize/(base.ptsize * base.scale);
			GfxMatrix.Scale(mat, scale, scale, font.bmat);
			IF GfxMatrix.Equal(font.mat, GfxMatrix.Identity) THEN font.fmt := Images.A1
			ELSE font.fmt := Images.A8
			END;
			GfxMatrix.ApplyToRect(font.bmat, base.xmin, base.ymin, base.xmax, base.ymax, xmin, ymin, xmax, ymax);
			font.xmin := SHORT(ENTIER(xmin)); font.ymin := SHORT(ENTIER(ymin));
			font.xmax := -SHORT(ENTIER(-xmax)); font.ymax := -SHORT(ENTIER(-ymax))
		END;
		RETURN font
	END Open;

	(** install open procedure in GfxFonts.OpenProc **)
	PROCEDURE Install*;
	BEGIN
		GfxFonts.OpenProc := Open
	END Install;

	PROCEDURE InitClass;
	BEGIN
		NEW(Class); Class.derive := Derive; Class.getwidth := GetWidth; Class.getmap := GetMap; Class.getoutline := GetOutline
	END InitClass;


BEGIN
	NEW(Src); NEW(Dst);
	InitInv;
	InitClass
END GfxPKFonts.
