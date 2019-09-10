(* ETH Oberon, Copyright 2001 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

MODULE PrinterInfo IN Oberon; (** portable *)	(* ejz  *)
	IMPORT Objects, Display, Fonts, Printer, Pictures, Strings, Texts, Oberon, Attributes, Gadgets;

	VAR
		W: Texts.Writer;

	PROCEDURE Int(name: ARRAY OF CHAR; val: SIGNED32);
		VAR obj: Objects.Object;
	BEGIN
		obj := Gadgets.FindObj(Gadgets.context, name);
		IF obj # NIL THEN
			Attributes.SetInt(obj, "Value", val);
			Gadgets.Update(obj)
		END
	END Int;

	PROCEDURE FixedStr(val: FLOAT32; VAR str: ARRAY OF CHAR);
		VAR v, i: SIGNED32;
	BEGIN
		v := ENTIER(val*100.0+0.5); i := 1;
		IF v >= 1000 THEN
			str[0] := CHR(ORD("0")+v DIV 1000)
		ELSE
			COPY(" ", str)
		END;
		str[i] := CHR(ORD("0")+(v DIV 100) MOD 10); INC(i);
		str[i] := "."; INC(i);
		str[i] := CHR(ORD("0")+(v DIV 10) MOD 10); INC(i);
		str[i] := CHR(ORD("0")+v MOD 10); INC(i);
		str[i] := 0X
	END FixedStr;

	PROCEDURE Fixed(name: ARRAY OF CHAR; val: FLOAT32);
		VAR
			obj: Objects.Object;
			str: ARRAY 8 OF CHAR;
	BEGIN
		obj := Gadgets.FindObj(Gadgets.context, name);
		IF obj # NIL THEN
			FixedStr(val, str);
			Attributes.SetString(obj, "Value", str);
			Gadgets.Update(obj)
		END
	END Fixed;

	PROCEDURE Str(name, val: ARRAY OF CHAR);
		VAR obj: Objects.Object;
	BEGIN
		obj := Gadgets.FindObj(Gadgets.context, name);
		IF obj # NIL THEN
			Attributes.SetString(obj, "Value", val);
			Gadgets.Update(obj)
		END
	END Str;

	PROCEDURE unit(VAR cm: BOOLEAN);
		VAR
			obj: Objects.Object;
			i: SIGNED32;
	BEGIN
		obj := Gadgets.FindObj(Gadgets.context, "unit");
		IF obj # NIL THEN
			Attributes.GetInt(obj, "Value", i);
			cm := i = 0
		ELSE
			cm := TRUE
		END
	END unit;

	PROCEDURE PrInfo;
		VAR
			P: Printer.Printer;
			cm: BOOLEAN;
	BEGIN
		unit(cm);
		P := Printer.current;
		IF P # NIL THEN
			Str("driver", P.gen);
			Int("res", 914400 DIV P.Unit);
			IF cm THEN
				Fixed("width", P.Unit*P.Width / 360000.0);
				Fixed("height", P.Unit*P.Height / 360000.0)
			ELSE
				Fixed("width", P.Unit*P.Width / 36000.0 / 25.4);
				Fixed("height", P.Unit*P.Height / 36000.0 / 25.4)
			END
		ELSE
			Str("driver", "no printer installed");
			Fixed("width", 0.0); Fixed("height", 0.0);
			Fixed("res", 0.0)
		END
	END PrInfo;

	PROCEDURE PgInfo;
		VAR
			P: Printer.Printer;
			cm: BOOLEAN;
	BEGIN
		unit(cm);
		P := Printer.current;
		IF P # NIL THEN
			IF cm THEN
				Fixed("left", P.Unit*P.FrameX / 360000.0);
				Fixed("bottom", P.Unit*P.FrameY / 360000.0);
				Fixed("right", P.Unit*(P.Width-P.FrameW-P.FrameX) / 360000.0);
				Fixed("top", P.Unit*(P.Height-P.FrameH-P.FrameY) / 360000.0)
			ELSE
				Fixed("left", P.Unit*P.FrameX / 36000.0 / 25.4);
				Fixed("bottom", P.Unit*P.FrameY / 36000.0 / 25.4);
				Fixed("right", P.Unit*(P.Width-P.FrameW-P.FrameX) / 36000.0 / 25.4);
				Fixed("top", P.Unit*(P.Height-P.FrameH-P.FrameY) / 36000.0 / 25.4)
			END
		ELSE
			Fixed("left", 0.0); Fixed("right", 0.0);
			Fixed("top", 0.0); Fixed("bottom", 0.0)
		END
	END PgInfo;

	PROCEDURE Update*;
		VAR
			S: Texts.Scanner;
			res: SIGNED16;
	BEGIN
		Texts.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos);
		Texts.Scan(S);
		IF S.class = Texts.Name THEN
			Oberon.Call(S.s, Oberon.Par, FALSE, res);
			Gadgets.context := Gadgets.context.dlink
		END;
		PrInfo(); PgInfo()
	END Update;

	PROCEDURE Print*;
		VAR
			S: Texts.Scanner;
			fnt: Fonts.Font;
			str: ARRAY 256 OF CHAR;
			printer: ARRAY 64 OF CHAR;
			P: Printer.Printer;
			t, d: SIGNED32;
			pict: Pictures.Picture;
			cm1, cm4, left, left1, left2, FrameTop, y, dy, i, r, g, b: SIGNED16;
			cm: BOOLEAN;
	BEGIN
		Texts.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos);
		Texts.Scan(S);
		IF S.class IN {Texts.Name, Texts.String} THEN
			COPY(S.s, printer); Texts.Scan(S);
			IF S.class IN {Texts.Name, Texts.String} THEN
				COPY(S.s, str)
			ELSE
				str := ""
			END;
			Strings.AppendCh(str, Oberon.OptionChar);
			Strings.Append(str, "ETH Oberon Printer Test Page");
			Printer.Open(printer, str);
			IF Printer.res = 0 THEN
				P := Printer.current; unit(cm);
				Texts.WriteString(W, "Printing test page on "); Texts.WriteString(W, str);
				Texts.WriteLn(W); Texts.Append(Oberon.Log, W.buf);
				IF S.s # "" THEN
					Texts.WriteString(W, ", options: "); Texts.WriteString(W, S.s)
				END;
				FrameTop := P.FrameY+P.FrameH;

				Printer.ReplConst(P.FrameX, P.FrameY, P.FrameW, 1);
				Printer.ReplConst(P.FrameX, P.FrameY, 1, P.FrameH);
				Printer.ReplConst(P.FrameX, FrameTop-1, P.FrameW, 1);
				Printer.ReplConst(P.FrameX+P.FrameW-1, P.FrameY, 1, P.FrameH);

				cm1 := SHORT(ENTIER((360000.0 / P.Unit)+0.5));
				left := SHORT(ENTIER(P.FrameX+0.5*cm1+0.5));
				left1 := SHORT(ENTIER(left+0.5*cm1+0.5)); left2 := SHORT(ENTIER(left+3.0*cm1+0.5));

				fnt := Fonts.This("Default24.Scn.Fnt");
				Printer.String(left, SHORT(ENTIER(FrameTop-1.25*cm1+0.5)), "ETH Oberon Printer Test Page", fnt);
				Printer.ReplConst(P.FrameX, SHORT(ENTIER(FrameTop-2.0*cm1+0.5)), P.FrameW, 1);

				y := SHORT(ENTIER(FrameTop-3.0*cm1+0.5)); dy := SHORT(ENTIER(0.5*cm1+0.5));
				fnt := Fonts.This("Default12m.Scn.Fnt");
				Printer.String(left, y, "Printer Information", fnt); DEC(y, dy);

				fnt := Fonts.This("Default12.Scn.Fnt");
				Printer.String(left1, y, "Printer Driver:", fnt);
				Printer.String(left2, y, P.gen, fnt); DEC(y, dy);

				Printer.String(left1, y, "Resolution:", fnt);
				Strings.IntToStr(914400 DIV P.Unit, str); Strings.Append(str, " dpi");
				Printer.String(left2, y, str, fnt); DEC(y, dy);

				IF cm THEN
					Printer.String(left1, y, "Page Width:", fnt);
					FixedStr(P.Unit*P.Width / 360000.0, str); Strings.Append(str, " cm");
					Printer.String(left2, y, str, fnt); DEC(y, dy);

					Printer.String(left1, y, "Page Height:", fnt);
					FixedStr(P.Unit*P.Height / 360000.0, str); Strings.Append(str, " cm");
					Printer.String(left2, y, str, fnt); DEC(y, dy);
				ELSE
					Printer.String(left1, y, "Page Width:", fnt);
					FixedStr(P.Unit*P.Width / 36000.0 / 25.4, str); Strings.Append(str, " inch");
					Printer.String(left2, y, str, fnt); DEC(y, dy);

					Printer.String(left1, y, "Page Height:", fnt);
					FixedStr(P.Unit*P.Height / 36000.0, str); Strings.Append(str, " inch");
					Printer.String(left2, y, str, fnt); DEC(y, dy)
				END;

				y := SHORT(ENTIER(FrameTop-3.0*cm1+0.5)); left := SHORT(ENTIER(P.FrameX+P.FrameW/2.0+0.5));
				left1 := SHORT(ENTIER(left+0.5*cm1+0.5)); left2 := SHORT(ENTIER(left+3.0*cm1+0.5));
				fnt := Fonts.This("Default12m.Scn.Fnt");
				Printer.String(left, y, "Page Setup", fnt);
				fnt := Fonts.This("Default12.Scn.Fnt"); DEC(y, dy);

				IF cm THEN
					Printer.String(left1, y, "Left Margin:", fnt);
					FixedStr(P.Unit*P.FrameX / 360000.0, str); Strings.Append(str, " cm");
					Printer.String(left2, y, str, fnt); DEC(y, dy);

					Printer.String(left1, y, "Right Margin:", fnt);
					FixedStr(P.Unit*(P.Width-P.FrameW-P.FrameX) / 360000.0, str); Strings.Append(str, " cm");
					Printer.String(left2, y, str, fnt); DEC(y, dy);

					Printer.String(left1, y, "Bottom Margin:", fnt);
					FixedStr(P.Unit*P.FrameY / 360000.0, str); Strings.Append(str, " cm");
					Printer.String(left2, y, str, fnt); DEC(y, dy);

					Printer.String(left1, y, "Top Margin:", fnt);
					FixedStr(P.Unit*(P.Height-P.FrameH-P.FrameY) / 360000.0, str); Strings.Append(str, " cm");
					Printer.String(left2, y, str, fnt); DEC(y, dy)
				ELSE
					Printer.String(left1, y, "Left Margin:", fnt);
					FixedStr(P.Unit*P.FrameX / 36000.0 / 25.4, str); Strings.Append(str, " inch");
					Printer.String(left2, y, str, fnt); DEC(y, dy);

					Printer.String(left1, y, "Right Margin:", fnt);
					FixedStr(P.Unit*(P.Width-P.FrameW-P.FrameX) / 36000.0 / 25.4, str); Strings.Append(str, " inch");
					Printer.String(left2, y, str, fnt); DEC(y, dy);

					Printer.String(left1, y, "Bottom Margin:", fnt);
					FixedStr(P.Unit*P.FrameY / 36000.0 / 25.4, str); Strings.Append(str, " inch");
					Printer.String(left2, y, str, fnt); DEC(y, dy);

					Printer.String(left1, y, "Top Margin:", fnt);
					FixedStr(P.Unit*(P.Height-P.FrameH-P.FrameY) / 36000.0 / 25.4, str); Strings.Append(str, " inch");
					Printer.String(left2, y, str, fnt); DEC(y, dy)
				END;

				left := SHORT(ENTIER(P.FrameX+0.5*cm1+0.5));
				DEC(y, dy); fnt := Fonts.This("Default12m.Scn.Fnt");
				Printer.String(left, y, "Font Test", fnt);
				DEC(y, dy); DEC(y, dy);

				fnt := Fonts.This("Default10.Scn.Fnt"); Printer.String(left, y, "Default10", fnt);
				fnt := Fonts.This("Default12.Scn.Fnt"); Printer.ContString("Default12", fnt);
				fnt := Fonts.This("Default14.Scn.Fnt"); Printer.ContString("Default14", fnt);
				fnt := Fonts.This("Default16.Scn.Fnt"); Printer.ContString("Default16", fnt);
				fnt := Fonts.This("Default20.Scn.Fnt"); Printer.ContString("Default20", fnt);
				fnt := Fonts.This("Default24.Scn.Fnt"); Printer.ContString("Default24", fnt);
				DEC(y, dy); DEC(y, dy);

				fnt := Fonts.This("Default10i.Scn.Fnt"); Printer.String(left, y, "Default10i", fnt);
				fnt := Fonts.This("Default12i.Scn.Fnt"); Printer.ContString("Default12", fnt);
				fnt := Fonts.This("Default14i.Scn.Fnt"); Printer.ContString("Default14i", fnt);
				fnt := Fonts.This("Default16i.Scn.Fnt"); Printer.ContString("Default16i", fnt);
				fnt := Fonts.This("Default20i.Scn.Fnt"); Printer.ContString("Default20i", fnt);
				fnt := Fonts.This("Default24i.Scn.Fnt"); Printer.ContString("Default24i", fnt);
				DEC(y, dy); DEC(y, dy);

				fnt := Fonts.This("Default10m.Scn.Fnt"); Printer.String(left, y, "Default10m", fnt);
				fnt := Fonts.This("Default12m.Scn.Fnt"); Printer.ContString("Default12m", fnt);
				fnt := Fonts.This("Default14m.Scn.Fnt"); Printer.ContString("Default14m", fnt);
				fnt := Fonts.This("Default16m.Scn.Fnt"); Printer.ContString("Default16m", fnt);
				fnt := Fonts.This("Default20m.Scn.Fnt"); Printer.ContString("Default20m", fnt);
				fnt := Fonts.This("Default24m.Scn.Fnt"); Printer.ContString("Default24m", fnt);
				DEC(y, dy); DEC(y, dy);

				fnt := Fonts.This("Default10b.Scn.Fnt"); Printer.String(left, y, "Default10b", fnt);
				fnt := Fonts.This("Default12b.Scn.Fnt"); Printer.ContString("Default12b", fnt);
				fnt := Fonts.This("Default14b.Scn.Fnt"); Printer.ContString("Default14b", fnt);
				fnt := Fonts.This("Default16b.Scn.Fnt"); Printer.ContString("Default16b", fnt);
				fnt := Fonts.This("Default20b.Scn.Fnt"); Printer.ContString("Default20b", fnt);
				fnt := Fonts.This("Default24b.Scn.Fnt"); Printer.ContString("Default24b", fnt);
				DEC(y, dy);

				DEC(y, dy); fnt := Fonts.This("Default12m.Scn.Fnt");
				Printer.String(left, y, "Font Color Test", fnt);
				DEC(y, dy); DEC(y, dy);
				fnt := Fonts.This("Default12.Scn.Fnt");
				Printer.String(left, y, "", fnt);
				FOR i := 0 TO 15 DO
					Display.GetColor(i, r, g, b);
					Printer.UseColor(r, g, b);
					Strings.IntToStr(i, str); Strings.AppendCh(str, " ");
					Printer.ContString(str, fnt)
				END;
				Printer.UseColor(0, 0, 0);
				DEC(y, dy);

				DEC(y, dy); fnt := Fonts.This("Default12m.Scn.Fnt");
				Printer.String(left, y, "Pattern Test", fnt);
				DEC(y, dy); DEC(y, dy); DEC(y, dy);
				left1 := SHORT(ENTIER(P.FrameX+(P.FrameW-16*cm1)/2.0+0.5));
				FOR i := 0 TO 15 DO
					Printer.ReplPattern(left1+i*cm1, y, cm1, cm1, i)
				END; DEC(y, dy);

				DEC(y, dy); fnt := Fonts.This("Default12m.Scn.Fnt");
				Printer.String(left, y, "Color Test", fnt); DEC(y, dy); DEC(y, cm1);
				cm4 := SHORT(ENTIER((360000.0 / P.Unit / 4.0)+0.5));

				FOR i := 0 TO 255 DO
					Display.GetColor(i, r, g, b);
					Printer.UseColor(r, g, b);
					Printer.ReplConst(left1+(i MOD 64)*cm4, y+(i DIV 64)*cm4, cm4, cm4)
				END;
				Printer.UseColor(0, 0, 0);

				DEC(y, dy); DEC(y, dy); fnt := Fonts.This("Default12m.Scn.Fnt");
				Printer.String(left, y, "Miscellaneous Test", fnt); DEC(y, dy);

				Printer.Line(left1, y-cm1, left1, y); Printer.Line(left1+16*cm1, y-cm1,left1+16*cm1, y);
				Printer.Line(left1, y-cm1, left1+16*cm1, y); Printer.Line(left1, y, left1+16*cm1, y-cm1);
				Printer.Line(left1, y, left1+16*cm1, y); Printer.Line(left1, y-cm1, left1+16*cm1, y-cm1);
				Printer.Circle(left1+8*cm1, SHORT(ENTIER(y-cm1/2.0+0.5)), SHORT(ENTIER(cm1/2.0+0.5)));
				FOR i := 1 TO 8 DO
					Printer.Ellipse(left1+8*cm1, SHORT(ENTIER(y-cm1/2.0+0.5)), i*cm1, SHORT(ENTIER(cm1/2.0+0.5)))
				END;

				NEW(pict); Pictures.Open(pict, "Default.Pict", TRUE);
				Printer.Picture(pict, 0, 0, pict.width, pict.height, left1, SHORT(ENTIER(P.FrameY+1.5*cm1+0.5)), 16*cm1, y-P.FrameY-3*cm1, Display.replace);

				Printer.ReplConst(P.FrameX, P.FrameY+cm1, P.FrameW, 1);
				fnt := Fonts.This("Default12.Scn.Fnt"); str := "Printed on ";
				Strings.Append(str, printer);
				IF S.s # "" THEN
					Strings.Append(str, ", options: "); Strings.Append(str, S.s)
				END;
				Printer.String(left, SHORT(ENTIER(P.FrameY+0.3*cm1+0.5)), str, fnt);
				Oberon.GetClock(t, d);
				Strings.TimeToStr(t, str); Strings.DateToStr(d, printer);
				Strings.AppendCh(str, " "); Strings.Append(str, printer);
				Printer.String(SHORT(ENTIER(Printer.FrameX+P.FrameW-3.5*cm1+0.5)), SHORT(ENTIER(P.FrameY+0.3*cm1+0.5)), str, fnt);
				Printer.Page(1); Printer.Close()
			ELSE
				Texts.WriteString(W, "Printer.Open failed")
			END;
			Texts.WriteLn(W); Texts.Append(Oberon.Log, W.buf)
		END
	END Print;

BEGIN
	Texts.OpenWriter(W)
END PrinterInfo.

PrinterInfo.Panel

System.Free PrinterInfo ~
