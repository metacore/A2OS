MODULE AFM; (** AUTHOR "TF"; PURPOSE "AFN - Adobe Font Metrics (minimal support and only unicode < 256)"; *)

IMPORT
	Files, KernelLog;

TYPE
	CharInfo = RECORD
		w : SIGNED32;
	END;

	FontMetrics* = OBJECT
	VAR chars : ARRAY 256 OF CharInfo;
		fontName : ARRAY 64 OF CHAR;

		PROCEDURE AddCharInfo(ucs : SIGNED32; ci : CharInfo);
		BEGIN
			IF (ucs >= 0) & (ucs < 256) THEN
				chars[ucs] := ci
			END
		END AddCharInfo;

		PROCEDURE InternalGetWidth(ucs : SIGNED32) : SIGNED32;
		BEGIN
			IF (ucs >= 0) & (ucs < 256) THEN RETURN chars[ucs].w
			ELSE RETURN 0
			END
		END InternalGetWidth;

		PROCEDURE GetWidth*(size : FLOAT32; ucs : SIGNED32) : FLOAT32;
		BEGIN
			IF (ucs >= 0) & (ucs < 256) THEN RETURN chars[ucs].w * size / 1000
			ELSE RETURN 0
			END
		END GetWidth;

		PROCEDURE Kerning(ucs0, ucs1 : SIGNED32) : SIGNED32;
		BEGIN
			RETURN 0
		END Kerning;

		PROCEDURE GetStringWidth*(size : FLOAT32; str : ARRAY OF CHAR) : FLOAT32;
		VAR i, w : SIGNED32;
		BEGIN
			IF str[0] = 0X THEN RETURN 0.0 END;
			w := InternalGetWidth(ORD(str[0])); i := 1;
			WHILE str[i] # 0X DO
				w := w + InternalGetWidth(ORD(str[i])) + Kerning(ORD(str[i - 1]), ORD(str[i]));
				INC(i)
			END;
			RETURN (w * size) / 1000
		END GetStringWidth;

		PROCEDURE LoadAFM(filename : ARRAY OF CHAR; VAR res : INTEGER);
		VAR f : Files.File; r : Files.Reader;
			t  : ARRAY 32 OF CHAR;
			hasName, hasCharMetrics, isC : BOOLEAN;
			char : SIGNED32;
			ci : CharInfo;
		BEGIN
			f := Files.Old(filename);
			IF f # NIL THEN
				Files.OpenReader(r, f, 0);
				WHILE (r.res = 0) & (~hasName) DO
					r.Token(t);
					IF t = "FontName" THEN hasName := TRUE
					ELSE r.SkipLn
					END
				END;
				IF ~hasName THEN res := 1; RETURN END;
				r.SkipWhitespace; r.String(fontName); r.SkipLn;

				WHILE (r.res = 0) & (~hasCharMetrics) DO
					r.Token(t);
					IF t = "StartCharMetrics" THEN hasCharMetrics := TRUE
					ELSE r.SkipLn
					END
				END;
				r.SkipLn;
				IF ~hasCharMetrics THEN res := 2; RETURN END;

				isC := TRUE;
				WHILE (r.res = 0) & (isC) DO
					r.Token(t);
					isC := t = "C";
					IF isC THEN
						r.SkipWhitespace;
						r.Int(char, FALSE);
						r.SkipWhitespace;
						IF r.Get() # ";" THEN res := 3; RETURN END;
						r.SkipWhitespace;
						r.Token(t);
						IF t # "WX" THEN res := 3; RETURN END;
						r.SkipWhitespace;
						r.Int(ci.w, FALSE);
						r.SkipLn;
						AddCharInfo(char, ci)
					END
				END
			END
		END LoadAFM;

	END FontMetrics;

VAR times*, helvetica*, helveticaBold*  : FontMetrics;
	res : INTEGER;
BEGIN
	NEW(times);
	times.LoadAFM("TIR.AFM", res);
	KernelLog.String("res = "); KernelLog.Int(res, 0); KernelLog.Ln;

	NEW(helvetica);
	helvetica.LoadAFM("HV.AFM", res);
	KernelLog.String("res = "); KernelLog.Int(res, 0); KernelLog.Ln;

	NEW(helveticaBold);
	helveticaBold.LoadAFM("HVB.AFM", res);
	KernelLog.String("res = "); KernelLog.Int(res, 0); KernelLog.Ln;
END AFM.X

System.Free AFM ~
