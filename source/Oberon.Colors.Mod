(* ETH Oberon, Copyright 2004 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

MODULE Colors IN Oberon; (** portable **)	(* eos  *)

	(**
		Color conversions and abstract color objects
	**)

	IMPORT
		Files, Objects, Plugins IN A2, Displays IN A2, Display, Strings;


	CONST
		undefined* = -1; red* = 0; yellow* = 1/6; green* = 2/6; cyan* = 3/6; blue* = 4/6; magenta* = 5/6;	(** hues **)


	TYPE
		(** color objects **)
		Color* = POINTER TO ColorDesc;
		ColorDesc* = RECORD (Objects.ObjDesc)
			r, g, b: FLOAT32;	(* internal representation is RGB *)
		END;

		(** inverse color lookup table **)
		Index* = RECORD
			bits: SIGNED16;	(* number of bits per component in color cube *)
			cube: POINTER TO ARRAY OF CHAR;	(* maps RGB triples to palette indices, size is (2^bits)^3 *)
		END;


	VAR
		DisplayIndex*: Index;	(** inverse color lookup table for display palette **)
		DisplayBits*: SIGNED16;	(** number of bits used for DisplayIndex **)
		Red*, Green*, Blue*: ARRAY 256 OF SIGNED16;	(** copy of display palette (faster lookup) **)


	(**--- Inverse Color Lookup ---**)

	(** return index of best match in inverse color lookup table **)
	PROCEDURE Match* (index: Index; bits, red, green, blue: SIGNED16): SIGNED32;
		VAR shift: SIGNED16;
	BEGIN
		IF bits > 6 THEN bits := 6 END;
		shift := bits-8;
		RETURN ORD(index.cube[ASH(ASH(red, shift), 2*bits) + ASH(ASH(green, shift), bits) + ASH(blue, shift)])
	END Match;

	(** initialize inverse color lookup table **)
	PROCEDURE MakeIndex* (VAR index: Index; bits: SIGNED16; colors: SIGNED32; VAR red, green, blue: ARRAY OF SIGNED16);
		VAR
			cur : SIGNED32;
			nbits, x, colormax, rcol, gcol, bcol: SIGNED16;
			xsqr, txsqr, rstride, gstride, size, i, rdist, gdist, bdist, cdist: SIGNED32;
			dbuf: POINTER TO ARRAY OF SIGNED32;
			rcenter, gcenter, bcenter, ghere, bhere, gmin, bmin, gmax, bmax: SIGNED16;
			incr, incg, incb, p, rp, gp: SIGNED32;
			ginc, binc: SIGNED32;

		PROCEDURE blueloop(): BOOLEAN;
			VAR detect: BOOLEAN; blue: SIGNED16; bp, bdist, bxx: SIGNED32;
		BEGIN
			detect := FALSE;
			blue := bhere; bp := gp; bdist := gdist; bxx := binc;
			WHILE (blue < bmax) & (dbuf[bp] <= bdist) DO
				INC(blue); INC(bp); INC(bdist, bxx); INC(bxx, txsqr)
			END;
			IF blue < bmax THEN	(* found applicable cell *)
				IF blue > bhere THEN
					bhere := blue; gp := bp; gdist := bdist; binc := bxx
				END;
				detect := TRUE;
				WHILE (blue < bmax) & (dbuf[bp] > bdist) DO
					dbuf[bp] := bdist; index.cube[bp] := CHR(cur);
					INC(blue); INC(bp); INC(bdist, bxx); INC(bxx, txsqr)
				END
			END;

			blue := bhere-1; bp := gp-1; bxx := binc - txsqr; bdist := gdist - bxx;
			IF ~detect THEN
				WHILE (blue >= bmin) & (dbuf[bp] <= bdist) DO
					DEC(blue); DEC(bp); DEC(bxx, txsqr); DEC(bdist, bxx)
				END;
				IF blue >= bmin THEN
					bhere := blue; gp := bp; gdist := bdist; binc := bxx; detect := TRUE
				END
			END;
			WHILE (blue >= bmin) & (dbuf[bp] > bdist) DO
				dbuf[bp] := bdist; index.cube[bp] := CHR(cur);
				DEC(blue); DEC(bp); DEC(bxx, txsqr); DEC(bdist, bxx)
			END;

			RETURN detect
		END blueloop;

		PROCEDURE greenloop(): BOOLEAN;
			VAR detect: BOOLEAN; green: SIGNED16; ggp, ggdist, gxx: SIGNED32;
		BEGIN
			detect := FALSE;
			bhere := bcenter; bmin := 0; bmax := colormax; binc := incb;	(* restart blueloop *)
			green := ghere; gp := rp; ggp := gp; gdist := rdist; ggdist := gdist; gxx := ginc;
			WHILE green < gmax DO
				IF blueloop() THEN
					IF ~detect THEN
						IF green > ghere THEN
							ghere := green; rp := ggp; rdist := ggdist; ginc := gxx
						END;
						detect := TRUE
					END;
					INC(green); INC(gp, gstride); INC(ggp, gstride); INC(gdist, gxx); INC(ggdist, gxx); INC(gxx, txsqr)
				ELSIF ~detect THEN
					green := gmax
				ELSE
					INC(green); INC(gp, gstride); INC(ggp, gstride); INC(gdist, gxx); INC(ggdist, gxx); INC(gxx, txsqr)
				END
			END;

			bhere := bcenter; bmin := 0; bmax := colormax; binc := incb;	(* restart blueloop *)
			green := ghere-1; gp := rp - gstride; ggp := gp; gxx := ginc - txsqr; gdist := rdist - gxx; ggdist := gdist;
			WHILE green >= gmin DO
				IF blueloop() THEN
					IF ~detect THEN
						ghere := green; rp := ggp; rdist := ggdist; ginc := gxx; detect := TRUE
					END;
					DEC(green); DEC(gp, gstride); DEC(ggp, gstride); DEC(gxx, txsqr); DEC(gdist, gxx); DEC(ggdist, gxx)
				ELSIF ~detect THEN
					green := gmin-1
				ELSE
					DEC(green); DEC(gp, gstride); DEC(ggp, gstride); DEC(gxx, txsqr); DEC(gdist, gxx); DEC(ggdist, gxx)
				END
			END;

			RETURN detect
		END greenloop;

		PROCEDURE redloop;
			VAR detect: BOOLEAN; red: SIGNED16; rxx: SIGNED32;
		BEGIN
			(* red up loop *)
			detect := FALSE;
			ghere := gcenter; gmin := 0; gmax := colormax; ginc := incg;	(* restart greenloop *)
			red := rcenter; rp := p; rdist := cdist; rxx := incr;
			WHILE red < colormax DO
				IF greenloop() THEN detect := TRUE; INC(red); INC(rp, rstride); INC(rdist, rxx); INC(rxx, txsqr)
				ELSIF detect THEN red := colormax	(* leave loop *)
				ELSE INC(red); INC(rp, rstride); INC(rdist, rxx); INC(rxx, txsqr)
				END
			END;

			(* red down loop *)
			ghere := gcenter; gmin := 0; gmax := colormax; ginc := incg;	(* restart greenloop *)
			red := rcenter-1; rp := p - rstride; rxx := incr - txsqr; rdist := cdist - rxx;
			WHILE red >= 0 DO
				IF greenloop() THEN detect := TRUE; DEC(red); DEC(rp, rstride); DEC(rxx, txsqr); DEC(rdist, rxx)
				ELSIF detect THEN red := -1	(* leave loop *)
				ELSE DEC(red); DEC(rp, rstride); DEC(rxx, txsqr); DEC(rdist, rxx)
				END
			END
		END redloop;

	BEGIN
		(* uses Spencer W. Thomas' algorithm from Graphics Gems II (ugly as it is) *)
		ASSERT(colors <= 10000H, 100);
		IF bits > 6 THEN bits := 6 END;	(* (2^6)^3 = 262144! *)
		nbits := 8-bits; x := SIGNED16(ASH(1, nbits)); xsqr := ASH(1, 2*nbits); txsqr := 2*xsqr;
		colormax := SIGNED16(ASH(1, bits)); rstride := ASH(1, 2*bits); gstride := colormax;

		(* fill buffer with maximal distance *)
		size := ASH(1, 3*bits); NEW(dbuf, size);
		i := 0; WHILE i < size DO dbuf[i] := MAX(SIGNED32); INC(i) END;
		IF (index.cube = NIL) OR (LEN(index.cube^) < size) THEN NEW(index.cube, size) END;
		index.bits := bits;

		cur := 0;
		WHILE cur < colors DO
			rcol := red[cur]; rcenter := SIGNED16(ASH(rcol, -nbits)); rdist := rcol - (rcenter * x + x DIV 2);
			gcol := green[cur]; gcenter := SIGNED16(ASH(gcol, -nbits)); gdist := gcol - (gcenter * x + x DIV 2);
			bcol := blue[cur]; bcenter := SIGNED16(ASH(bcol, -nbits)); bdist := bcol - (bcenter * x + x DIV 2);
			cdist := rdist * rdist + gdist * gdist + bdist * bdist;
			incr := 2*((rcenter+1) * xsqr - rcol * x); incg := 2*((gcenter+1) * xsqr - gcol * x); incb := 2*((bcenter+1) * xsqr - bcol * x);
			p := rcenter * rstride + gcenter * gstride + bcenter;
			redloop;
			INC(cur)
		END
	END MakeIndex;

	(** update the inverse color lookup table for the display palette **)
	PROCEDURE Update*;
		VAR colors, n: SIGNED16; p: Plugins.Plugin; d: Displays.Display; col: SIGNED32;
	BEGIN
		p := Displays.registry.Await("");	(* default display *)
		IF p # NIL THEN d := p(Displays.Display) ELSE d := NIL END;
		IF (d # NIL) & (d.format = Displays.index8) THEN	(* use real palette *)
			IF d.IndexToColor(0) = d.IndexToColor(16) THEN colors := 16 ELSE colors := 256 END;
			FOR n := 0 TO colors-1 DO
				col := d.IndexToColor(n);
				Red[n] := SIGNED16(ASH(col, -16) MOD 100H);
				Green[n] := SIGNED16(ASH(col, -8) MOD 100H);
				Blue[n] := SHORT(col MOD 100H)
			END;
			MakeIndex(DisplayIndex, DisplayBits, colors, Red, Green, Blue)
		ELSE
			colors := SIGNED16(ASH(1, Display.Depth(Display.ColLeft)));
			IF colors > 256 THEN colors := 256 END;
			FOR n := 0 TO colors-1 DO
				Display.GetColor(n, Red[n], Green[n], Blue[n])
			END;
			MakeIndex(DisplayIndex, DisplayBits, colors, Red, Green, Blue)
		END
	END Update;


	(**--- Conversion Routines ---**)

	(** Oberon display model **)
	PROCEDURE DisplayToRGB* (dcol: Display.Color; VAR r, g, b: FLOAT32);
		VAR dr, dg, db: SIGNED16;
	BEGIN
		IF dcol < 0 THEN Display.GetColor(dcol, dr, dg, db)
		ELSE dr := Red[dcol]; dg := Green[dcol]; db := Blue[dcol]
		END;
		r := (1/255)*dr; g := (1/255)*dg; b := (1/255)*db
	END DisplayToRGB;

	PROCEDURE RGBToDisplay* (r, g, b: FLOAT32; VAR dcol: Display.Color);
		VAR dr, dg, db: SIGNED32;
	BEGIN
		dr := ENTIER(255*r); dg := ENTIER(255*g); db := ENTIER(255*b);
		IF Display.TrueColor(Display.ColLeft) THEN
			dcol := Display.RGB(dr, dg, db)
		ELSE
			dcol := Match(DisplayIndex, DisplayBits, SHORT(dr), SHORT(dg), SHORT(db))
		END
	END RGBToDisplay;


	(** HSV (Hue Saturation Value) model **)
	PROCEDURE RGBToHSV* (r, g, b: FLOAT32; VAR h, s, v: FLOAT32);
		VAR min, d: FLOAT32;
	BEGIN
		(* conversion algorithm: Foley et al. fig 13.33 *)
		IF r < g THEN
			IF g < b THEN min := r; v := b
			ELSIF b < r THEN min := b; v := g
			ELSE min := r; v := g
			END
		ELSE
			IF b > r THEN min := g; v := b
			ELSIF g > b THEN min := b; v := r
			ELSE min := g; v := r
			END
		END;
		d := v - min;
		IF v = 0 THEN s := 0	(* black is a special case with saturation 0 *)
		ELSE s := d/v
		END;
		IF s = 0 THEN	(* achromatic case *)
			h := undefined
		ELSE
			IF r = v THEN h := (g - b)/d	(* hue between yellow and magenta *)
			ELSIF g = v THEN h := 2 + (b - r)/d	(* hue between cyan and yellow *)
			ELSE h := 4 + (r - g)/d	(* hue between magenta and cyan *)
			END;
			h := (1/6)*h;
			IF h < 0 THEN h := h+1
			ELSIF h >= 1 THEN h := h-1
			END
		END
	END RGBToHSV;

	PROCEDURE HSVToRGB* (h, s, v: FLOAT32; VAR r, g, b: FLOAT32);
		VAR i: SIGNED32; f, p, q, t: FLOAT32;
	BEGIN
		(* conversion algorithm: Foley et al. fig 13.34 *)
		IF s = 0 THEN	(* achromatic case  *)
			r := v; g := v; b := v
		ELSE
			h := 6*h; i := ENTIER(h); f := h - i;
			p := v * (1-s); q := v * (1 - s*f); t := v * (1 - s*(1-f));
			CASE i MOD 6 OF
			| 0: r := v; g := t; b := p
			| 1: r := q; g := v; b := p
			| 2: r := p; g := v; b := t
			| 3: r := p; g := q; b := v
			| 4: r := t; g := p; b := v
			| 5: r := v; g := p; b := q
			END
		END
	END HSVToRGB;


	(** CMY (Cyan Magenta Yellow) model **)
	PROCEDURE RGBToCMY* (r, g, b: FLOAT32; VAR c, m, y: FLOAT32);
	BEGIN
		c := 1 - r; m := 1 - g; y := 1 - b
	END RGBToCMY;

	PROCEDURE CMYToRGB* (c, m, y: FLOAT32; VAR r, g, b: FLOAT32);
	BEGIN
		r := 1 - c; g := 1 - m; b := 1 - y
	END CMYToRGB;


	(** CMYK (Cyan Magenta Yellow blacK) model **)
	PROCEDURE RGBToCMYK* (r, g, b: FLOAT32; VAR c, m, y, k: FLOAT32);
	BEGIN
		c := 1 - r; m := 1 - g; y := 1 - b;
		IF r < g THEN
			IF b < r THEN k := b
			ELSE k := r
			END
		ELSE
			IF b < g THEN k := b
			ELSE k := g
			END
		END;
		c := c - k; m := m - k; y := y - k
	END RGBToCMYK;

	PROCEDURE CMYKToRGB* (c, m, y, k: FLOAT32; VAR r, g, b: FLOAT32);
	BEGIN
		r := 1 - (k + c); g := 1 - (k + m); b := 1 - (k + y)
	END CMYKToRGB;


	(**--- Colors ---**)

	(** copy color contents **)
	PROCEDURE Copy* (VAR msg: Objects.CopyMsg; from, to: Color);
	BEGIN
		to.handle := from.handle;
		to.r := from.r; to.g := from.g; to.b := from.b
	END Copy;

	(** message handler **)
	PROCEDURE Handle* (obj: Objects.Object; VAR msg: Objects.ObjMsg);
		VAR col, copy: Color; x, y, z, w: FLOAT32; lib: Objects.Library; ref: SIGNED16; ver: SIGNED32;
	BEGIN
		col := obj(Color);
		IF msg IS Objects.AttrMsg THEN
			WITH msg: Objects.AttrMsg DO
				IF msg.id = Objects.enum THEN
					msg.Enum("RedGB"); msg.Enum("RGreenB"); msg.Enum("RGBlue");
					msg.Enum("Color");
					msg.Enum("HueSV"); msg.Enum("HSaturationV"); msg.Enum("HSValue");
					msg.Enum("CyanMY"); msg.Enum("CMagentaY"); msg.Enum("CMYellow");
					msg.Enum("CyanMYK"); msg.Enum("CMagentaYK"); msg.Enum("CMYellowK"); msg.Enum("CMYblacK")
				ELSIF msg.id = Objects.get THEN
					IF msg.name = "Gen" THEN
						msg.class := Objects.String; msg.s := "Colors.New"; msg.res := 0
					ELSIF msg.name = "RedGB" THEN
						msg.class := Objects.Real; msg.x := col.r; msg.res := 0
					ELSIF msg.name = "RGreenB" THEN
						msg.class := Objects.Real; msg.x := col.g; msg.res := 0
					ELSIF msg.name = "RGBlue" THEN
						msg.class := Objects.Real; msg.x := col.b; msg.res := 0
					ELSIF msg.name = "Color" THEN
						msg.class := Objects.Int; RGBToDisplay(col.r, col.g, col.b, msg.i); msg.res := 0
					ELSIF msg.name = "HueSV" THEN
						msg.class := Objects.Real; RGBToHSV(col.r, col.g, col.b, msg.x, x, y); msg.res := 0
					ELSIF msg.name = "HSaturationV" THEN
						msg.class := Objects.Real; RGBToHSV(col.r, col.g, col.b, x, msg.x, y); msg.res := 0
					ELSIF msg.name = "HSValue" THEN
						msg.class := Objects.Real; RGBToHSV(col.r, col.g, col.b, x, y, msg.x); msg.res := 0
					ELSIF msg.name = "CyanMY" THEN
						msg.class := Objects.Real; RGBToCMY(col.r, col.g, col.b, msg.x, x, y); msg.res := 0
					ELSIF msg.name = "CMagentaY" THEN
						msg.class := Objects.Real; RGBToCMY(col.r, col.g, col.b, x, msg.x, y); msg.res := 0
					ELSIF msg.name = "CMYellow" THEN
						msg.class := Objects.Real; RGBToCMY(col.r, col.g, col.b, x, y, msg.x); msg.res := 0
					ELSIF msg.name = "CyanMYK" THEN
						msg.class := Objects.Real; RGBToCMYK(col.r, col.g, col.b, msg.x, x, y, z); msg.res := 0
					ELSIF msg.name = "CMagentaYK" THEN
						msg.class := Objects.Real; RGBToCMYK(col.r, col.g, col.b, x, msg.x, y, z); msg.res := 0
					ELSIF msg.name = "CMYellowK" THEN
						msg.class := Objects.Real; RGBToCMYK(col.r, col.g, col.b, x, y, msg.x, z); msg.res := 0
					ELSIF msg.name = "CMYblacK" THEN
						msg.class := Objects.Real; RGBToCMYK(col.r, col.g, col.b, x, y, z, msg.x); msg.res := 0
					ELSIF msg.name = "Red255" THEN
						msg.class := Objects.Int; msg.i := ENTIER(255*col.r); msg.res := 0
					ELSIF msg.name = "Green255" THEN
						msg.class := Objects.Int; msg.i := ENTIER(255*col.g); msg.res := 0
					ELSIF msg.name = "Blue255" THEN
						msg.class := Objects.Int; msg.i := ENTIER(255*col.b); msg.res := 0
					ELSIF msg.name = "Hue360" THEN
						RGBToHSV(col.r, col.g, col.b, x, y, z);
						IF x < 0 THEN msg.class := Objects.String; msg.s := ""; msg.res := 0
						ELSE msg.class := Objects.Int; msg.i := ENTIER(360*x); msg.res := 0
						END
					ELSIF msg.name = "Saturation100" THEN
						msg.class := Objects.Int; RGBToHSV(col.r, col.g, col.b, x, y, z); msg.i := ENTIER(100*y); msg.res := 0
					ELSIF msg.name = "Value100" THEN
						msg.class := Objects.Int; RGBToHSV(col.r, col.g, col.b, x, y, z); msg.i := ENTIER(100*z); msg.res := 0
					END
				ELSIF msg.id = Objects.set THEN
					IF msg.class = Objects.Int THEN
						msg.x := msg.i
					ELSIF msg.class = Objects.LongReal THEN
						msg.x := SHORT(msg.y); msg.i := ENTIER(msg.x)
					ELSIF msg.class = Objects.String THEN
						Strings.StrToReal(msg.s, msg.y); msg.x := SHORT(msg.y);
						Strings.StrToInt(msg.s, msg.i)
					ELSIF msg.class = Objects.Real THEN
						msg.i := ENTIER(msg.x)
					ELSE
						RETURN
					END;
					IF (msg.name = "RedGB") & (0 <= msg.x) & (msg.x <= 1) THEN
						col.r := msg.x; msg.res := 0
					ELSIF (msg.name = "RGreenB") & (0 <= msg.x) & (msg.x <= 1) THEN
						col.g := msg.x; msg.res := 0
					ELSIF (msg.name = "RGBlue") & (0 <= msg.x) & (msg.x <= 1) THEN
						col.b := msg.x; msg.res := 0
					ELSIF (msg.name = "Color") & (msg.i < 256) THEN
						DisplayToRGB(msg.i, col.r, col.g, col.b); msg.res := 0
					ELSIF (msg.name = "HueSV") & (0 <= msg.x) & (msg.x <= 1) THEN
						RGBToHSV(col.r, col.g, col.b, x, y, z); HSVToRGB(msg.x, y, z, col.r, col.g, col.b); msg.res := 0
					ELSIF (msg.name = "HSaturationV") & (0 <= msg.x) & (msg.x <= 1) THEN
						RGBToHSV(col.r, col.g, col.b, x, y, z); HSVToRGB(x, msg.x, z, col.r, col.g, col.b); msg.res := 0
					ELSIF (msg.name = "HSValue") & (0 <= msg.x) & (msg.x <= 1) THEN
						RGBToHSV(col.r, col.g, col.b, x, y, z); HSVToRGB(x, y, msg.x, col.r, col.g, col.b); msg.res := 0
					ELSIF (msg.name = "CyanMY") & (0 <= msg.x) & (msg.x <= 1) THEN
						RGBToCMY(col.r, col.g, col.b, x, y, z); CMYToRGB(msg.x, y, z, col.r, col.g, col.b); msg.res := 0
					ELSIF (msg.name = "CMagentaY") & (0 <= msg.x) & (msg.x <= 1) THEN
						RGBToCMY(col.r, col.g, col.b, x, y, z); CMYToRGB(x, msg.x,  z, col.r, col.g, col.b); msg.res := 0
					ELSIF (msg.name = "CMYellow") & (0 <= msg.x) & (msg.x <= 1) THEN
						RGBToCMY(col.r, col.g, col.b, x, y, z); CMYToRGB(x, y, msg.x, col.r, col.g, col.b); msg.res := 0
					ELSIF (msg.name = "CyanMYK") & (0 <= msg.x) & (msg.x <= 1) THEN
						RGBToCMYK(col.r, col.g, col.b, x, y, z, w); CMYKToRGB(msg.x, y, z, w, col.r, col.g, col.b); msg.res := 0
					ELSIF (msg.name = "CMagentaYK") & (0 <= msg.x) & (msg.x <= 1) THEN
						RGBToCMYK(col.r, col.g, col.b, x, y, z, w); CMYKToRGB(x, msg.x, z, w, col.r, col.g, col.b); msg.res := 0
					ELSIF (msg.name = "CMYellowK") & (0 <= msg.x) & (msg.x <= 1) THEN
						RGBToCMYK(col.r, col.g, col.b, x, y, z, w); CMYKToRGB(x, y, msg.x, w, col.r, col.g, col.b); msg.res := 0
					ELSIF (msg.name = "CMYblacK") & (0 <= msg.x) & (msg.x <= 1) THEN
						RGBToCMYK(col.r, col.g, col.b, x, y, z, w); CMYKToRGB(x, y, z, msg.x, col.r, col.g, col.b); msg.res := 0
					ELSIF (msg.name = "Red255") & (0 <= msg.i) & (msg.i < 256) THEN
						col.r := msg.i/255; msg.res := 0
					ELSIF (msg.name = "Green255") & (0 <= msg.i) & (msg.i < 256) THEN
						col.g := msg.i/255; msg.res := 0
					ELSIF (msg.name = "Blue255") & (0 <= msg.i) & (msg.i < 256) THEN
						col.b := msg.i/255; msg.res := 0
					ELSIF (msg.name = "Hue360") & (0 <= msg.i) & (msg.i < 360) THEN
						RGBToHSV(col.r, col.g, col.b, x, y, z);
						IF (msg.class = Objects.String) & (msg.s = "") THEN HSVToRGB(-1, 0, z, col.r, col.g, col.b); msg.res := 0
						ELSE HSVToRGB(msg.i/360, y, z, col.r, col.g, col.b); msg.res := 0
						END
					ELSIF (msg.name = "Saturation100") & (0 <= msg.i) & (msg.i <= 100) THEN
						RGBToHSV(col.r, col.g, col.b, x, y, z); HSVToRGB(x, msg.i/100, z, col.r, col.g, col.b); msg.res := 0
					ELSIF (msg.name = "Value100") & (0 <= msg.i) & (msg.i <= 100) THEN
						RGBToHSV(col.r, col.g, col.b, x, y, z); HSVToRGB(x, y, msg.i/100, col.r, col.g, col.b); msg.res := 0
					END
				END
			END
		ELSIF msg IS Objects.CopyMsg THEN
			WITH msg: Objects.CopyMsg DO
				IF msg.stamp # col.stamp THEN
					NEW(copy); col.dlink := copy; col.stamp := msg.stamp;
					Copy(msg, col, copy)
				END;
				msg.obj := col.dlink
			END
		ELSIF msg IS Objects.BindMsg THEN
			lib := msg(Objects.BindMsg).lib;
			IF (lib # NIL) & ((col.lib = NIL) OR (col.lib.name[0] = 0X) & (col.lib # lib)) THEN
				lib.GenRef(lib, ref);
				IF ref >= 0 THEN
					lib.PutObj(lib, ref, col)
				END
			END
		ELSIF msg IS Objects.FileMsg THEN
			WITH msg: Objects.FileMsg DO
				IF msg.id = Objects.store THEN
					Files.WriteNum(msg.R, 1);
					Files.WriteReal(msg.R, col.r); Files.WriteReal(msg.R, col.g); Files.WriteReal(msg.R, col.b)
				ELSIF msg.id = Objects.load THEN
					Files.ReadNum(msg.R, ver);
					Files.ReadReal(msg.R, col.r); Files.ReadReal(msg.R, col.g); Files.ReadReal(msg.R, col.b)
				END
			END
		END
	END Handle;

	(** generator command **)
	PROCEDURE New*;
		VAR col: Color;
	BEGIN
		NEW(col); col.handle := Handle;
		Objects.NewObj := col
	END New;

	(** initialization **)
	PROCEDURE InitRGB* (col: Color; r, g, b: FLOAT32);
	BEGIN
		col.handle := Handle; col.r := r; col.g := g; col.b := b
	END InitRGB;

	PROCEDURE InitDisplay* (col: Color; dcol: Display.Color);
	BEGIN
		col.handle := Handle;
		DisplayToRGB(dcol, col.r, col.g, col.b)
	END InitDisplay;

	PROCEDURE InitHSV* (col: Color; h, s, v: FLOAT32);
	BEGIN
		col.handle := Handle;
		HSVToRGB(h, s, v, col.r, col.g, col.b)
	END InitHSV;

	PROCEDURE InitCMY* (col: Color; c, m, y: FLOAT32);
	BEGIN
		col.handle := Handle;
		CMYToRGB(c, m, y, col.r, col.g, col.b)
	END InitCMY;

	PROCEDURE InitCMYK* (col: Color; c, m, y, k: FLOAT32);
	BEGIN
		col.handle := Handle;
		CMYKToRGB(c, m, y, k, col.r, col.g, col.b)
	END InitCMYK;

	(** get color values **)
	PROCEDURE GetRGB* (col: Color; VAR r, g, b: FLOAT32);
	BEGIN
		r := col.r; g := col.g; b := col.b
	END GetRGB;

	PROCEDURE GetDisplay* (col: Color; VAR dcol: Display.Color);
	BEGIN
		RGBToDisplay(col.r, col.g, col.b, dcol)
	END GetDisplay;

	PROCEDURE GetHSV* (col: Color; VAR h, s, v: FLOAT32);
	BEGIN
		RGBToHSV(col.r, col.g, col.b, h, s, v)
	END GetHSV;

	PROCEDURE GetCMY* (col: Color; VAR c, m, y: FLOAT32);
	BEGIN
		RGBToCMY(col.r, col.b, col.b, c, m, y)
	END GetCMY;

	PROCEDURE GetCMYK* (col: Color; VAR c, m, y, k: FLOAT32);
	BEGIN
		RGBToCMYK(col.r, col.g, col.b, c, m, y, k)
	END GetCMYK;

	(** set color values **)
	PROCEDURE SetRGB* (col: Color; r, g, b: FLOAT32);
	BEGIN
		col.r := r; col.g := g; col.b := b
	END SetRGB;

	PROCEDURE SetDisplay* (col: Color; dcol: Display.Color);
	BEGIN
		DisplayToRGB(dcol, col.r, col.g, col.b)
	END SetDisplay;

	PROCEDURE SetHSV* (col: Color; h, s, v: FLOAT32);
	BEGIN
		HSVToRGB(h, s, v, col.r, col.g, col.b)
	END SetHSV;

	PROCEDURE SetCMY* (col: Color; c, m, y: FLOAT32);
	BEGIN
		CMYToRGB(c, m, y, col.r, col.b, col.b)
	END SetCMY;

	PROCEDURE SetCMYK* (col: Color; c, m, y, k: FLOAT32);
	BEGIN
		CMYKToRGB(c, m, y, k, col.r, col.b, col.b)
	END SetCMYK;


BEGIN
	DisplayBits := 4;
	Update
END Colors.

(**
Notes

1. Color Conversions
In order to support RGB, HSV, CMY(K) and the Oberon display color model, several procedures convert from RGB to another model or vice versa. The range of all components is usually [0..1], except for display colors which are integers ranging from 0 to 255 (palette color) or from MIN(SIGNED32) to -1 (true color).

2. Color Objects
Color objects are extensions of Objects.Object and can thus be used as models for visual gadgets which deal with color. Their internal representation is kept private, but components for all color models are accessible as object attributes.

3. Inverse Color Lookup
To speed up the conversion from an RGB triple to a palette index, an inverse color mapping can be computed with MakeIndex. The more bits are used for the index structure, the more memory is consumed. A reasonable value for bits is 4, allocating 4096 bytes on the heap.

4. Display Colors
The colors in the Oberon default palette are mirrored in global variables Red, Green and Blue. An inverse color lookup table using DisplayBits is available in DisplayIndex. When the display palette is modified, Update should be called to adapt all of these to the new palette.
**)