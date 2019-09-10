(* ETH Oberon, Copyright 2001 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

MODULE GfxTest IN Oberon; (** portable *)	(* eos  *)

	(*
		12.2.98 - eliminated offset parameter in subpath begin
		26.8.99 - replaced GfxMaps with Images/GfxImages, GfxPictures with PictImages
	*)

	IMPORT
		Files, Display, Fonts, Math IN A2, Texts, Oberon, Printer, Images, PictImages,
		GfxMatrix, GfxImages, GfxFonts, Gfx, GfxDisplay, GfxBuffer, GfxPrinter, GfxPS;


	CONST
		FontName = "Oberon"; BoldFontName = "Oberon-Bold";	(* or a TrueType font, if installed *)


	VAR
		Ctxt: Gfx.Context;
		Scn: GfxDisplay.Context;
		Img: Images.Image;
		Buf: GfxBuffer.Context;
		Prt: GfxPrinter.Context;
		PS: GfxPS.Context;


	PROCEDURE Init*;
	BEGIN
		Gfx.Reset(Ctxt)
	END Init;

	PROCEDURE Colors*;
		VAR i, j: SIGNED16; col: Gfx.Color;
	BEGIN
		Gfx.Reset(Ctxt);
		FOR i := 0 TO 255 BY 8 DO
			FOR j := 0 TO 255 BY 8 DO
				col.r := 255-ABS(i - j); col.g := i; col.b := j;
				Gfx.SetFillColor(Ctxt, col);
				Gfx.DrawRect(Ctxt, i, j, i+8, j+8, {Gfx.Fill})
			END
		END
	END Colors;

	PROCEDURE Lines*;
	BEGIN
		Gfx.Reset(Ctxt);
		Gfx.DrawLine(Ctxt, 72, 72, 72, 432, {Gfx.Stroke});
		Gfx.DrawLine(Ctxt, 72, 360, 72 + 144, 360 + 72, {Gfx.Stroke});
		Gfx.DrawLine(Ctxt, 144, 432, 144, 432 - 216, {Gfx.Stroke});
	END Lines;

	PROCEDURE Box1*;
	BEGIN
		Gfx.Reset(Ctxt);
		Gfx.SetLineWidth(Ctxt, 4);
		Gfx.Begin(Ctxt, {Gfx.Stroke});
		Gfx.MoveTo(Ctxt, 270, 360);
		Gfx.LineTo(Ctxt, 270, 360 + 72);
		Gfx.LineTo(Ctxt, 270 + 72, 360 + 72);
		Gfx.LineTo(Ctxt, 270 + 72, 360);
		Gfx.LineTo(Ctxt, 270, 360);
		Gfx.End(Ctxt)
	END Box1;

	PROCEDURE Box2*;
	BEGIN
		Gfx.Reset(Ctxt);
		Gfx.SetLineWidth(Ctxt, 4);
		Gfx.DrawRect(Ctxt, 270, 360, 270 + 72, 360 + 72, {Gfx.Stroke})
	END Box2;

	PROCEDURE Box3*;
		VAR col: Gfx.Color;
	BEGIN
		Gfx.Reset(Ctxt);
		Gfx.SetFillColor(Ctxt, Gfx.Black);
		Gfx.DrawRect(Ctxt, 252, 324, 252 + 72, 324 + 72, {Gfx.Fill});
		col.r := 255 * 4 DIV 10; col.g := col.r; col.b := col.g;
		Gfx.SetFillColor(Ctxt, col);
		Gfx.DrawRect(Ctxt, 270, 360, 270 + 72, 360 + 72, {Gfx.Fill});
		col.r := 255 * 8 DIV 10; col.g := col.r; col.b := col.g;
		Gfx.SetFillColor(Ctxt, col);
		Gfx.DrawRect(Ctxt, 288, 396, 288 + 72, 396 + 72, {Gfx.Fill});
	END Box3;

	PROCEDURE Squares1*;
	BEGIN
		Gfx.Reset(Ctxt);
		Gfx.SetFontName(Ctxt, FontName, 24);
		Gfx.DrawRect(Ctxt, 0, 0, 90, 90, {Gfx.Fill});
		Gfx.DrawStringAt(Ctxt, 6, 92, "A Box");
		Gfx.Translate(Ctxt, 300, 150);
		Gfx.Rotate(Ctxt, 0.866, 0.5);
		Gfx.DrawRect(Ctxt, 0, 0, 90, 90, {Gfx.Fill});
		Gfx.DrawStringAt(Ctxt, 6, 92, "A Box");
		Gfx.Translate(Ctxt, 300, 150);
		Gfx.Rotate(Ctxt, 0.866, 0.5);
		Gfx.DrawRect(Ctxt, 0, 0, 90, 90, {Gfx.Fill});
		Gfx.DrawStringAt(Ctxt, 6, 92, "A Box");
	END Squares1;

	PROCEDURE Squares2*;
	BEGIN
		Gfx.Reset(Ctxt);
		Gfx.SetFontName(Ctxt, FontName, 24);
		Gfx.DrawRect(Ctxt, 0, 0, 90, 90, {Gfx.Fill});
		Gfx.DrawStringAt(Ctxt, 6, 92, "A Box");
		Gfx.Translate(Ctxt, 100, 100);
		Gfx.Scale(Ctxt, 1.5, 1.5);
		Gfx.DrawRect(Ctxt, 0, 0, 90, 90, {Gfx.Fill});
		Gfx.DrawStringAt(Ctxt, 6, 92, "A Box");
		Gfx.Translate(Ctxt, 100, 100);
		Gfx.Scale(Ctxt, 0.75, 1.25);
		Gfx.DrawRect(Ctxt, 0, 0, 90, 90, {Gfx.Fill});
		Gfx.DrawStringAt(Ctxt, 6, 92, "A Box");
	END Squares2;

	PROCEDURE Star1*;
		VAR col: Gfx.Color; i: SIGNED32;
	BEGIN
		Gfx.Reset(Ctxt);
		col.r := 127; col.g := 127; col.b := 127;
		Gfx.SetFillColor(Ctxt, col);
		Gfx.SetLineWidth(Ctxt, 3);
		Gfx.Begin(Ctxt, {Gfx.Fill, Gfx.Stroke});
		Gfx.MoveTo(Ctxt, 200, 200);
		Gfx.Translate(Ctxt, Ctxt.cpx, Ctxt.cpy);
		FOR i := 1 TO 5 DO
			Gfx.LineTo(Ctxt, 72, 0);
			Gfx.Translate(Ctxt, Ctxt.cpx, Ctxt.cpy);
			Gfx.Rotate(Ctxt, Math.sin(-4*Math.pi/5), Math.cos(-4*Math.pi/5))
		END;
		Gfx.Close(Ctxt);
		Gfx.End(Ctxt)
	END Star1;

	PROCEDURE Star2*;
		VAR i: SIGNED32; col: Gfx.Color;
	BEGIN
		Gfx.Reset(Ctxt);
		Gfx.Begin(Ctxt, {Gfx.Record});
		Gfx.MoveTo(Ctxt, 200, 200);
		Gfx.Translate(Ctxt, Ctxt.cpx, Ctxt.cpy);
		FOR i := 1 TO 4 DO
			Gfx.LineTo(Ctxt, 72, 0);
			Gfx.Translate(Ctxt, Ctxt.cpx, Ctxt.cpy);
			Gfx.Rotate(Ctxt, Math.sin(-4*Math.pi/5), Math.cos(-4*Math.pi/5))
		END;
		Gfx.LineTo(Ctxt, 72, 0);
		Gfx.End(Ctxt);
		col.r := 127; col.g := 127; col.b := 127;
		Gfx.SetFillColor(Ctxt, col);
		Gfx.SetLineWidth(Ctxt, 3);
		Gfx.Render(Ctxt, {Gfx.Fill, Gfx.Stroke})
	END Star2;

	PROCEDURE Arcs*;
		CONST sqrt2 = 1.414;
		VAR sin, cos: FLOAT32;
	BEGIN
		Gfx.Reset(Ctxt);
		Gfx.Begin(Ctxt, {Gfx.Stroke});
		Gfx.MoveTo(Ctxt, 100 + 36/sqrt2, 160 + 36/sqrt2);
		Gfx.ArcTo(Ctxt, 100, 160 + 36, 100, 160, 100 + 36, 160, 100, 160 + 36);
		Gfx.MoveTo(Ctxt, 100 + 36/sqrt2, 150 + 36/sqrt2);
		Gfx.ArcTo(Ctxt, 100, 150 + 36, 100, 150, 100 + 36, 150, 100, 150 - 36);
		sin := Math.sin(40*Math.pi/180); cos := Math.cos(40*Math.pi/180);
		Gfx.MoveTo(Ctxt, 300 + 54*cos, 400 + 54*sin);
		Gfx.ArcTo(Ctxt, 300 - 54*cos, 400 + 54*sin, 300, 400, 300 + 54, 400, 300, 400 + 54);
		Gfx.MoveTo(Ctxt, 300 + 5*cos, 345 + 5*sin);
		Gfx.ArcTo(Ctxt, 300 - 54*cos, 345 + 54*sin, 300, 345, 300 + 54, 345, 300, 345 + 54);
		Gfx.End(Ctxt)
	END Arcs;

	PROCEDURE Ellipses*;
		VAR ctm: GfxMatrix.Matrix; j, i: SIGNED32;
	BEGIN
		Gfx.Reset(Ctxt); Gfx.SetLineWidth(Ctxt, 2);
		Gfx.SetFlatness(Ctxt, 0.25);
		FOR j := 1 TO 4 DO
			ctm := Ctxt.ctm;
			Gfx.Translate(Ctxt, 100*j, 500);
			Gfx.DrawCircle(Ctxt, 0, 0, 54, {Gfx.Stroke});
			FOR i := 1 TO 4 DO
				Gfx.Translate(Ctxt, 0, -72);
				Gfx.Scale(Ctxt, 1, 0.75);
				Gfx.DrawCircle(Ctxt, 0, 0, 54, {Gfx.Stroke})
			END;
			Gfx.SetCTM(Ctxt, ctm);
			Gfx.SetFlatness(Ctxt, 4*Ctxt.flatness)
		END;
		Gfx.SetFlatness(Ctxt, 1)
	END Ellipses;

	PROCEDURE Trapezoids*;
		VAR factor: FLOAT32; col: Gfx.Color; i: SIGNED32; ctm: GfxMatrix.Matrix;
	BEGIN
		Gfx.Reset(Ctxt);
		Gfx.Translate(Ctxt, 250, 350);
		factor := 1; col.r := 127; col.g := 127; col.b := 127;
		FOR i := 1 TO 5 DO
			ctm := Ctxt.ctm;
			Gfx.Scale(Ctxt, 1, factor);
			IF ODD(i) THEN
				Gfx.SetFillColor(Ctxt, Gfx.Black)
			ELSE
				Gfx.SetFillColor(Ctxt, col)
			END;
			Gfx.Begin(Ctxt, {Gfx.Fill});
			Gfx.Enter(Ctxt, 0, 0, 90, 0);
			Gfx.LineTo(Ctxt, 90, 0); Gfx.LineTo(Ctxt, 70, 45); Gfx.LineTo(Ctxt, 20, 45); Gfx.LineTo(Ctxt, 0, 0);
			Gfx.Exit(Ctxt, -20, -45);
			Gfx.End(Ctxt);
			Gfx.SetCTM(Ctxt, ctm);
			factor := factor - 0.2;
			Gfx.Translate(Ctxt, 0, 20)
		END
	END Trapezoids;

	PROCEDURE Circles*;
		PROCEDURE lineOfCircles (r, y: FLOAT32);
			VAR x: FLOAT32;
		BEGIN
			x := 0;
			WHILE x < 700 DO
				Gfx.DrawCircle(Ctxt, x, y, r, {Gfx.Stroke});
				x := x + r
			END
		END lineOfCircles;
	BEGIN
		Gfx.Reset(Ctxt);
		lineOfCircles(10, 400);
		lineOfCircles(30, 400);
		lineOfCircles(90, 400)
	END Circles;

	PROCEDURE Fractal*;
		PROCEDURE arrow (depth: SIGNED16; x, y: FLOAT32);
			CONST sqrt2 = 1.414;
			VAR ctm: GfxMatrix.Matrix; lw: FLOAT32;
		BEGIN
			ctm := Ctxt.ctm; lw := Ctxt.lineWidth;
			Gfx.Scale(Ctxt, 0.7, 0.7);
			Gfx.SetLineWidth(Ctxt, 10);
			Gfx.Begin(Ctxt, {Gfx.Stroke});
			Gfx.MoveTo(Ctxt, x, y);
			Gfx.LineTo(Ctxt, Ctxt.cpx, Ctxt.cpy + 144);
			Gfx.End(Ctxt);
			Gfx.Translate(Ctxt, Ctxt.cpx, Ctxt.cpy);
			x := 0; y := 0;
			IF depth < 8 THEN
				Gfx.Rotate(Ctxt, 1/sqrt2, -1/sqrt2);
				arrow(depth + 1, x, y);
				Gfx.Rotate(Ctxt, 1, 0);
				arrow(depth + 1, x, y)
			END;
			Gfx.SetCTM(Ctxt, ctm); Gfx.SetLineWidth(Ctxt, lw)
		END arrow;
	BEGIN
		Gfx.Reset(Ctxt);
		arrow(0, 300, 400)
	END Fractal;

	PROCEDURE Triangle*;
		VAR clip: Gfx.ClipArea; i: SIGNED32;
	BEGIN
		Gfx.Reset(Ctxt);
		clip := Gfx.GetClip(Ctxt);
		Gfx.Translate(Ctxt, 230, 300);
		Gfx.Begin(Ctxt, {Gfx.Clip});
		Gfx.MoveTo(Ctxt, 0, 0);
		Gfx.LineTo(Ctxt, 144, 0); Gfx.LineTo(Ctxt, 72, 200);
		Gfx.Close(Ctxt);
		Gfx.End(Ctxt);
		Gfx.Begin(Ctxt, {Gfx.Stroke});
		FOR i := 0 TO 144 BY 9 DO
			Gfx.MoveTo(Ctxt, i, 0);
			Gfx.LineTo(Ctxt, i, 216)
		END;
		FOR i := 0 TO 200 BY 10 DO
			Gfx.MoveTo(Ctxt, 0, i);
			Gfx.LineTo(Ctxt, 144, i)
		END;
		Gfx.End(Ctxt);
		Gfx.SetClip(Ctxt, clip);
		Gfx.Rotate(Ctxt, 0.5, Math.sqrt(0.75));
		Gfx.SetFont(Ctxt, GfxFonts.OpenSize("Oberon", 20));
		Gfx.DrawStringAt(Ctxt, 30, 40, "Hello World")
	END Triangle;

	PROCEDURE Caps*;
		PROCEDURE line (col: Gfx.Color; y, w: FLOAT32; style: Gfx.CapStyle);
		BEGIN
			Gfx.SetStrokeColor(Ctxt, col);
			Gfx.SetLineWidth(Ctxt, w);
			Gfx.SetCapStyle(Ctxt, style);
			Gfx.Begin(Ctxt, {Gfx.Stroke});
			Gfx.Enter(Ctxt, 72, y, 0, 0);
			Gfx.LineTo(Ctxt, 216, y);
			Gfx.Exit(Ctxt, 0, 0);
			Gfx.End(Ctxt)
		END line;
	BEGIN
		Gfx.Reset(Ctxt);
		line(Gfx.Black, 100, 20, Gfx.ButtCap); line(Gfx.White, 100, 1, Gfx.ButtCap);
		line(Gfx.Black, 150, 20, Gfx.RoundCap); line(Gfx.White, 150, 1, Gfx.ButtCap);
		line(Gfx.Black, 200, 20, Gfx.SquareCap); line(Gfx.White, 200, 1, Gfx.ButtCap)
	END Caps;

	PROCEDURE Joints*;
		PROCEDURE lines (col: Gfx.Color; y, w: FLOAT32; style: Gfx.JoinStyle);
		BEGIN
			Gfx.SetStrokeColor(Ctxt, col);
			Gfx.SetLineWidth(Ctxt, w);
			Gfx.SetJoinStyle(Ctxt, style);
			Gfx.Begin(Ctxt, {Gfx.Stroke});
			Gfx.Enter(Ctxt, 72 + 144, y, 0, 0);
			Gfx.LineTo(Ctxt, 72, y); Gfx.LineTo(Ctxt, 72 + 72, y + 72);
			Gfx.Exit(Ctxt, 0, 0);
			Gfx.End(Ctxt)
		END lines;
	BEGIN
		Gfx.Reset(Ctxt);
		lines(Gfx.Black, 100, 20, Gfx.MiterJoin); lines(Gfx.White, 100, 1, Gfx.MiterJoin);
		lines(Gfx.Black, 200, 20, Gfx.BevelJoin); lines(Gfx.White, 200, 1, Gfx.MiterJoin);
		lines(Gfx.Black, 300, 20, Gfx.RoundJoin); lines(Gfx.White, 300, 1, Gfx.MiterJoin)
	END Joints;

	PROCEDURE Dashes*;
		PROCEDURE doLine (n: SIGNED32; d0, d1, d2, d3, phase, y: FLOAT32);
			VAR on, off: ARRAY 2 OF FLOAT32;
		BEGIN
			IF n > 0 THEN
				on[0] := d0; off[0] := d1;
				IF n > 1 THEN
					on[1] := d2; off[1] := d3
				END
			END;
			Gfx.SetDashPattern(Ctxt, on, off, n, phase);
			Gfx.DrawLine(Ctxt, 0, y, 100, y, {Gfx.Stroke})
		END doLine;
	BEGIN
		Gfx.Reset(Ctxt);
		Gfx.Translate(Ctxt, 250, 300);
		Gfx.SetLineWidth(Ctxt, 5);
		Gfx.DrawLine(Ctxt, -2.5, 0, -2.5, 135, {Gfx.Stroke});
		Gfx.DrawLine(Ctxt, 102.5, 0, 102.5, 135, {Gfx.Stroke});
		Gfx.SetLineWidth(Ctxt, 0.5);
		doLine(0, 0, 0, 0, 0, 0, 130);
		doLine(1, 4, 2, 0, 0, 0, 115);
		doLine(1, 2, 4, 0, 0, 0, 100);
		doLine(2, 6, 4, 2, 4, 0, 85);
		doLine(1, 4, 4, 0, 0, 0, 70);
		doLine(1, 4, 4, 0, 0, 1, 55);
		doLine(1, 4, 4, 0, 0, 2, 40);
		doLine(1, 4, 4, 0, 0, 3, 25);
		doLine(1, 4, 4, 0, 0, 4, 10)
	END Dashes;

	PROCEDURE Image*;
		VAR img: Images.Image; b0, b1: ARRAY 8 OF CHAR; i: SIGNED16;
	BEGIN
		Gfx.Reset(Ctxt);
		NEW(img); Images.Create(img, 8, 8, Images.D8);
		b0[0] := 0FX; b0[1] := 0FX; b0[2] := 0X; b0[3] := 0X; b0[4] := 0FX; b0[5] := 0X; b0[6] := 0X; b0[7] := 0FX;
		b1[0] := 0X; b1[1] := 0X; b1[2] := 0FX; b1[3] := 0FX; b1[4] := 0X; b1[5] := 0FX; b1[6] := 0FX; b1[7] := 0X;
		FOR i := 0 TO 6 BY 2 DO
			Images.PutPixels(img, 0, 7-i, 8, Images.D8, b0, Images.SrcCopy);
			Images.PutPixels(img, 0, 6-i, 8, Images.D8, b1, Images.SrcCopy)
		END;
		Gfx.Translate(Ctxt, 300, 400);
		Gfx.Scale(Ctxt, 72/8, 72/8);
		Gfx.DrawImageAt(Ctxt, 0, 0, img, GfxImages.NoFilter);
		Gfx.Reset(Ctxt)
	END Image;

	PROCEDURE Helicopter*;
		VAR img, simg: Images.Image; pix: Images.Pixel; i: SIGNED32;
	BEGIN
		Gfx.Reset(Ctxt);
		NEW(img); Images.Create(img, 16, 6, Images.A1);
		pix[0] := 0X; pix[1] := 0X; pix[2] := 0X; pix[3] := 0FFX;
		Images.Put(img, 2, 0, pix, Images.SrcCopy);
		Images.Put(img, 6, 0, pix, Images.SrcCopy);
		Images.Fill(img, 0, 1, 8, 2, pix, Images.SrcCopy);
		Images.Put(img, 0, 2, pix, Images.SrcCopy);
		Images.Put(img, 2, 2, pix, Images.SrcCopy);
		Images.Put(img, 4, 2, pix, Images.SrcCopy);
		Images.Fill(img, 6, 2, 11, 3, pix, Images.SrcCopy);
		Images.Fill(img, 1, 3, 14, 4, pix, Images.SrcCopy);
		Images.Put(img, 5, 4, pix, Images.SrcCopy);
		Images.Fill(img, 13, 4, 15, 5, pix, Images.SrcCopy);
		Images.Fill(img, 0, 5, 11, 6, pix, Images.SrcCopy);
		Images.Put(img, 15, 5, pix, Images.SrcCopy);
		NEW(simg); Images.Create(simg, 72, 72, Images.A8);
		GfxImages.Scale(img, simg, 72/16, 72/6, 0, 0, GfxImages.NoFilter);
		FOR i := 0 TO 11 DO
			Gfx.Translate(Ctxt, 300, 300);
			Gfx.Rotate(Ctxt, Math.sin(i * Math.pi/6), Math.cos(i * Math.pi/6));
			Gfx.Translate(Ctxt, 2*72, 0);
			(*Gfx.Scale(Ctxt, 72/16, 72/6);*)
			Gfx.DrawImageAt(Ctxt, 0, 0, simg, GfxImages.LinearFilter);
			Gfx.Reset(Ctxt)
		END
	END Helicopter;

	PROCEDURE Text*;
	BEGIN
		Gfx.Reset(Ctxt);
		Gfx.SetFontName(Ctxt, FontName, 14);
		Gfx.DrawStringAt(Ctxt, 72, 200, "typography")
	END Text;

	PROCEDURE Gorilla*;
	BEGIN
		Gfx.Reset(Ctxt);
		Gfx.SetFontName(Ctxt, FontName, 6);
		Gfx.DrawStringAt(Ctxt, 72, 300, "Gorilla");
		Gfx.SetFontName(Ctxt, FontName, 10);
		Gfx.DrawStringAt(Ctxt, 72, 275, "Gorilla");
		Gfx.SetFontName(Ctxt, FontName, 15);
		Gfx.DrawStringAt(Ctxt, 72, 250, "Gorilla");
		Gfx.SetFontName(Ctxt, FontName, 20);
		Gfx.DrawStringAt(Ctxt, 72, 225, "Gorilla")
	END Gorilla;

	PROCEDURE Typefaces*;
	BEGIN
		Gfx.Reset(Ctxt);
		Gfx.SetFontName(Ctxt, "Oberon", 15);
		Gfx.DrawStringAt(Ctxt, 72, 300, "Typefaces");
		Gfx.SetFontName(Ctxt, "Oberon-Italic", 15);
		Gfx.DrawStringAt(Ctxt, 72, 285, "Typefaces");
		Gfx.SetFontName(Ctxt, "Oberon-Bold", 15);
		Gfx.DrawStringAt(Ctxt, 72, 270, "Typefaces");
		Gfx.SetFontName(Ctxt, "Greek", 15);
		Gfx.DrawStringAt(Ctxt, 72, 240, "Typefaces");
		Gfx.SetFontName(Ctxt, "Math", 15);
		Gfx.DrawStringAt(Ctxt, 72, 225, "Typefaces");
		Gfx.SetFontName(Ctxt, "Syntax", 15);
		Gfx.DrawStringAt(Ctxt, 72, 195, "Typefaces");
		Gfx.SetFontName(Ctxt, "Syntax-Italic", 15);
		Gfx.DrawStringAt(Ctxt, 72, 180, "Typefaces");
		Gfx.SetFontName(Ctxt, "Syntax-Medium", 15);
		Gfx.DrawStringAt(Ctxt, 72, 165, "Typefaces");
		Gfx.SetFontName(Ctxt, "Syntax-Bold", 15);
		Gfx.DrawStringAt(Ctxt, 72, 150, "Typefaces");
	END Typefaces;

	PROCEDURE Zip*;
		VAR grey: SIGNED16; col: Gfx.Color;
	BEGIN
		Gfx.Reset(Ctxt);
		Gfx.SetFontName(Ctxt, FontName, 24);
		Gfx.Translate(Ctxt, 320, 400);
		grey := 256;
		WHILE grey > 0 DO
			DEC(grey, 16);
			col.r := grey; col.g := grey; col.b := grey;
			Gfx.SetFillColor(Ctxt, col);
			Gfx.DrawStringAt(Ctxt, 0, 0, "Zip");
			Gfx.Translate(Ctxt, -1, 0.5)
		END;
		Gfx.SetFillColor(Ctxt, Gfx.White);
		Gfx.DrawStringAt(Ctxt, 0, 0, "Zip");
		Gfx.Reset(Ctxt)
	END Zip;

	PROCEDURE Binky*;
		VAR dx, dy: FLOAT32;
		PROCEDURE fillPage (str: ARRAY OF CHAR);
			VAR i: SIGNED16; char: ARRAY 2 OF CHAR;
		BEGIN
			i := 0; char[1] := 0X;
			WHILE Ctxt.cpy > -13 DO
				char[0] := str[i]; INC(i);
				IF str[i] = 0X THEN i := 0 END;
				Gfx.DrawString(Ctxt, char);
				IF Ctxt.cpx >= 700 THEN
					Gfx.DrawStringAt(Ctxt, 0, Ctxt.cpy - 13, "")
				END
			END
		END fillPage;
	BEGIN
		Gfx.Reset(Ctxt);
		Gfx.SetFontName(Ctxt, BoldFontName, 10);
		Gfx.DrawStringAt(Ctxt, 0, 360, "");
		Gfx.SetFillColor(Ctxt, Gfx.DGrey);
		fillPage("Binky Inc.  ");
		Gfx.SetFontName(Ctxt, BoldFontName, 48);
		Gfx.GetStringWidth(Ctxt, "Binky Inc.", dx, dy);
		Gfx.SetFillColor(Ctxt, Gfx.Black);
		Gfx.DrawStringAt(Ctxt, 0.5*(650 - dx), 170, "Binky Inc.")
	END Binky;

	PROCEDURE Font*;
		VAR mat: GfxMatrix.Matrix;
	BEGIN
		Gfx.Reset(Ctxt);
		Gfx.SetFont(Ctxt, GfxFonts.Open(FontName, 12, GfxMatrix.Identity));
		Gfx.DrawStringAt(Ctxt, 0, 300, '"Talking of axes,"');
		GfxMatrix.Init(mat, 17/12, 0, 0, 1, 0, 0);
		Gfx.SetFont(Ctxt, GfxFonts.Open(FontName, 12, mat));
		Gfx.DrawStringAt(Ctxt, 0, 287, 'said the Duchess,');
		GfxMatrix.Init(mat, 7/12, 0, 0, 1, 0, 0);
		Gfx.SetFont(Ctxt, GfxFonts.Open(FontName, 12, mat));
		Gfx.DrawStringAt(Ctxt, 0, 274, '"Off with her head!"');
		GfxMatrix.Init(mat, 1, 0, 6.93/12, 1, 0, 0);
		Gfx.SetFont(Ctxt, GfxFonts.Open(FontName, 12, mat));
		Gfx.DrawStringAt(Ctxt, 0, 261, '      - Lewis Carroll');
	END Font;

	PROCEDURE Adobe*;
		VAR phi: SIGNED16; ctm: GfxMatrix.Matrix;
	BEGIN
		Gfx.Reset(Ctxt);
		Gfx.SetFontName(Ctxt, BoldFontName, 30);
		Gfx.Translate(Ctxt, 250, 300);
		Gfx.SetLineWidth(Ctxt, 0.5);
		FOR phi := 15 TO 345 BY 15 DO
			ctm := Ctxt.ctm;
			Gfx.Rotate(Ctxt, Math.sin(phi*Math.pi/180), Math.cos(phi*Math.pi/180));
			Gfx.Begin(Ctxt, {Gfx.Stroke});
			Gfx.ShowAt(Ctxt, 0, 0, "Adobe");
			Gfx.End(Ctxt);
			Gfx.SetCTM(Ctxt, ctm)
		END;
		Gfx.SetFillColor(Ctxt, Gfx.White);
		Gfx.Begin(Ctxt, {Gfx.Fill, Gfx.Stroke});
		Gfx.ShowAt(Ctxt, 0, 0, "Adobe Systems");
		Gfx.End(Ctxt);
		Gfx.Reset(Ctxt)
	END Adobe;

	PROCEDURE StarLines*;
		VAR phi: FLOAT32; ctm: GfxMatrix.Matrix;
	BEGIN
		Gfx.Reset(Ctxt);
		Gfx.SetFontName(Ctxt, BoldFontName, 42);
		Gfx.Translate(Ctxt, 100, 200);
		Gfx.SetLineWidth(Ctxt, 0.25);
		Gfx.Begin(Ctxt, {Gfx.Clip});
		Gfx.ShowAt(Ctxt, 0, 0, "StarLines");
		Gfx.End(Ctxt);
		Gfx.Translate(Ctxt, 100, -15);
		phi := 0;
		WHILE phi < 180 DO
			ctm := Ctxt.ctm;
			Gfx.Rotate(Ctxt, Math.sin(phi*Math.pi/180), Math.cos(phi*Math.pi/180));
			Gfx.DrawLine(Ctxt, 0, 0, 200, 0, {Gfx.Stroke});
			Gfx.SetCTM(Ctxt, ctm);
			phi := phi + 1.5
		END;
		Gfx.Reset(Ctxt)
	END StarLines;

	PROCEDURE Patterns*;
		VAR img: Images.Image; done: BOOLEAN;

		PROCEDURE rect (pat: Display.Pattern; x, y, w, h: SIGNED16);
		BEGIN
			PictImages.PatternToImage(pat, img);
			Gfx.SetFillPattern(Ctxt, Gfx.NewPattern(Ctxt, img, 0, 0));
			Gfx.DrawRect(Ctxt, x, y, x + w, y + h, {Gfx.Fill, Gfx.Stroke})
		END rect;

	BEGIN
		Gfx.Reset(Ctxt);
		NEW(img);
		rect(1, 0, 0, 50, 40);
		rect(2, 100, 0, 50, 40);
		rect(3, 200, 0, 50, 40);
		rect(4, 300, 0, 50, 40);
		rect(5, 0, 80, 50, 40);
		rect(6, 100, 80, 50, 40);
		rect(7, 200, 80, 50, 40);
		rect(8, 300, 80, 50, 40);
		rect(Display.grey0, 0, 160, 50, 40);
		rect(Display.grey1, 100, 160, 50, 40);
		rect(Display.grey2, 200, 160, 50, 40);
		rect(Display.ticks, 300, 160, 50, 40);
		Images.Load(img, "Bart.Pict", done);
		Gfx.SetFillPattern(Ctxt, Gfx.NewPattern(Ctxt, img, 0, 0));
		Gfx.DrawRect(Ctxt, 0, 240, 350, 360, {Gfx.Fill, Gfx.Stroke});
	END Patterns;

	PROCEDURE Bart*;
		VAR img: Images.Image; done: BOOLEAN;
	BEGIN
		Gfx.Reset(Ctxt);
		NEW(img); Images.Load(img, "Bart.Pict", done);
		Gfx.SetFillPattern(Ctxt, Gfx.NewPattern(Ctxt, img, 0, 0));
		Gfx.SetFontName(Ctxt, BoldFontName, 64);
		Gfx.Begin(Ctxt, {Gfx.Fill});
		Gfx.ShowAt(Ctxt, 0, 0, "Bart");
		Gfx.End(Ctxt);
		Gfx.Reset(Ctxt)
	END Bart;

	PROCEDURE StrokePat*;
		VAR img: Images.Image; pat: ARRAY 1 OF FLOAT32;
	BEGIN
		NEW(img);
		Gfx.Reset(Ctxt);
		Gfx.SetLineWidth(Ctxt, 4);
		Gfx.DrawRect(Ctxt, 10, 10, 200, 150, {Gfx.Record});
		Gfx.Outline(Ctxt);
		PictImages.PatternToImage(6, img);
		Gfx.SetFillPattern(Ctxt, Gfx.NewPattern(Ctxt, img, 0, 0));
		Gfx.Render(Ctxt, {Gfx.Fill});
		Gfx.SetLineWidth(Ctxt, 8);
		pat[0] := 10;
		Gfx.SetDashPattern(Ctxt, pat, pat, 1, 0);
		PictImages.PatternToImage(7, img);
		Gfx.SetStrokePattern(Ctxt, Gfx.NewPattern(Ctxt, img, 0, 0));
		Gfx.DrawEllipse(Ctxt, 300, 200, 150, 100, {Gfx.Stroke})
	END StrokePat;

	PROCEDURE Show*;
		VAR s: Texts.Scanner;
	BEGIN
		Texts.OpenScanner(s, Oberon.Par.text, Oberon.Par.pos);
		Texts.Scan(s);
		IF (s.class # Texts.Name) & (s.class # Texts.String) THEN s.s := "no text given" END;
		Gfx.Reset(Ctxt);
		Gfx.SetFontName(Ctxt, BoldFontName, 128);
		Gfx.SetFillColor(Ctxt, Gfx.White);
		Gfx.Begin(Ctxt, {Gfx.Fill, Gfx.Stroke});
		Gfx.ShowAt(Ctxt, 10, 10, s.s);
		Gfx.End(Ctxt);
		Gfx.Reset(Ctxt)
	END Show;

	PROCEDURE ImgCmd*;
		VAR s: Texts.Scanner; text: Texts.Text; beg, end, time: SIGNED32; tmpCtxt: Gfx.Context; res: SIGNED16;
	BEGIN
		text := Oberon.Par.text;
		Texts.OpenScanner(s, text, Oberon.Par.pos);
		Texts.Scan(s);
		IF (s.class = Texts.Char) & (s.c = "^") THEN
			Oberon.GetSelection(text, beg, end, time);
			IF time >= 0 THEN Texts.OpenScanner(s, text, beg); Texts.Scan(s) END
		END;
		IF s.class = Texts.Name THEN
			tmpCtxt := Ctxt; Ctxt := Buf;
			Oberon.Par.text := text; Oberon.Par.pos := Texts.Pos(s);
			Gfx.Reset(Ctxt);
			Gfx.SetFillColor(Ctxt, Gfx.White);
			Gfx.DrawRect(Ctxt, 0, 0, Img.width, Img.height, {Gfx.Fill});
			Oberon.Call(s.s, Oberon.Par, FALSE, res);
			Ctxt := tmpCtxt;
			Gfx.Reset(Ctxt);
			Gfx.DrawImageAt(Ctxt, 0, 0, Img, GfxImages.NoFilter)
		END
	END ImgCmd;

	PROCEDURE PrtCmd*;
		VAR s: Texts.Scanner; text: Texts.Text; beg, end, time: SIGNED32; tmpCtxt: Gfx.Context; w, h, res: SIGNED16;
	BEGIN
		text := Oberon.Par.text;
		Texts.OpenScanner(s, text, Oberon.Par.pos);
		Texts.Scan(s);
		IF (s.class = Texts.Name) OR (s.class = Texts.String) THEN
			Printer.Open(s.s, "");
			IF Printer.res = 0 THEN
				Texts.Scan(s);
				IF (s.class = Texts.Char) & (s.c = "^") THEN
					Oberon.GetSelection(text, beg, end, time);
					IF time >= 0 THEN Texts.OpenScanner(s, text, beg); Texts.Scan(s) END
				END;
				IF s.class = Texts.Name THEN
					Printer.UseColor(0, 0, 0);
					Printer.String(Printer.FrameX, Printer.FrameY + Printer.FrameH - 500, s.s, Fonts.This("Syntax16b.Scn.Fnt"));
					w := SHORT(6500000 DIV Printer.Unit); h := SHORT(6000000 DIV Printer.Unit);
					GfxPrinter.Init(Prt);
					GfxPrinter.SetClipRect(Prt, Printer.FrameX, Printer.FrameY, Printer.FrameX + w, Printer.FrameY + h);
					tmpCtxt := Ctxt; Ctxt := Prt;
					Oberon.Par.text := text; Oberon.Par.pos := Texts.Pos(s);
					Oberon.Call(s.s, Oberon.Par, FALSE, res);
					Printer.Page(1); Printer.Close;
					Ctxt := tmpCtxt
				END
			END
		END
	END PrtCmd;

	PROCEDURE PSCmd*;
		VAR s: Texts.Scanner; text: Texts.Text; beg, end, time: SIGNED32; tmpCtxt: Gfx.Context; res: SIGNED16;
	BEGIN
		text := Oberon.Par.text;
		Texts.OpenScanner(s, text, Oberon.Par.pos);
		Texts.Scan(s);
		IF (s.class = Texts.Name) OR (s.class = Texts.String) THEN
			GfxPS.Init(PS, TRUE, TRUE, GfxPS.A4H, GfxPS.A4W, 50, GfxPS.A4H - 50 - 650, 50, GfxPS.A4W - 50 - 600, 300);
			GfxPS.Open(PS, Files.New(s.s));
			Texts.Scan(s);
			IF (s.class = Texts.Char) & (s.c = "^") THEN
				Oberon.GetSelection(text, beg, end, time);
				IF time >= 0 THEN Texts.OpenScanner(s, text, beg); Texts.Scan(s) END
			END;
			IF s.class = Texts.Name THEN
				tmpCtxt := Ctxt; Ctxt := PS;
				Oberon.Par.text := text; Oberon.Par.pos := Texts.Pos(s);
				Oberon.Call(s.s, Oberon.Par, FALSE, res);
				GfxPS.ShowPage(PS);
				GfxPS.Close(PS);
				Ctxt := tmpCtxt
			END
		END
	END PSCmd;


BEGIN
	NEW(Scn); GfxDisplay.Init(Scn, 50, 50, 700, 650);
	Ctxt := Scn;
	NEW(Img); Images.Create(Img, 650, 600, Images.BGR888);
	NEW(Buf); GfxBuffer.Init(Buf, Img);
	NEW(Prt);
	NEW(PS);
END GfxTest.

Builder.Free GfxTest.Mod GfxPS.Mod GfxDisplay.Mod GfxBuffer.Mod GfxPrinter.Mod GfxRaster.Mod Gfx.Mod ~
Builder.Free GfxOType.Mod GfxPKFonts.Mod GfxFonts.Mod GfxRegions.Mod GfxPaths.Mod ~
Builder.Free GfxImages.Mod PictImages.Mod GfxMatrix.Mod Images.Mod ~

GfxTest.ImgCmd ^
GfxTest.PrtCmd out.ps ^
GfxTest.PSCmd out.ps ^	EditTools.OpenAscii out.ps	LPRPrinter.PrintPSFile lph1@lillian out.ps ~

GfxTest.Init	GfxTest.Colors
GfxTest.Lines	GfxTest.Box1	GfxTest.Box2	GfxTest.Box3
GfxTest.Squares1	GfxTest.Squares2
GfxTest.Star1	GfxTest.Star2
GfxTest.Arcs	GfxTest.Ellipses
GfxTest.Trapezoids	GfxTest.Circles	GfxTest.Fractal
GfxTest.Triangle
GfxTest.Caps	GfxTest.Joints	GfxTest.Dashes
GfxTest.Image	GfxTest.Helicopter
GfxTest.Text	GfxTest.Gorilla	GfxTest.Typefaces
GfxTest.Zip	GfxTest.Binky	GfxTest.Font
GfxTest.Adobe	GfxTest.StarLines
GfxTest.Patterns	GfxTest.Bart
GfxTest.StrokePat
GfxTest.Show Oberon
