(* ETH Oberon, Copyright 2001 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

MODULE QuotedPrintable IN Oberon; (* ejz,  *)
	IMPORT Files, Fonts, Strings, Texts, Oberon;

	VAR
		W: Texts.Writer;

	PROCEDURE HexVal(ch: CHAR): SIGNED32;
	BEGIN
		IF (ch >= "0") & (ch <= "9") THEN
			RETURN ORD(ch)-ORD("0")
		ELSIF (ch >= "A") & (ch <= "F") THEN
			RETURN ORD(ch)-ORD("A")+10
		ELSIF (ch >= "a") & (ch <= "f") THEN
			RETURN ORD(ch)-ORD("a")+10
		END
	END HexVal;

	PROCEDURE decodeText*(T: Texts.Text; beg: SIGNED32; F: Files.File; binary: BOOLEAN): BOOLEAN;
		VAR
			R: Texts.Reader;
			Ri: Files.Rider;
			ch, ch1, ch2: CHAR;
		PROCEDURE ReadWrite(c: CHAR);
		BEGIN
			Texts.Read(R, ch);
			IF ~R.eot & (R.lib IS Fonts.Font) THEN
				Files.Write(Ri, c)
			END
		END ReadWrite;
	BEGIN
		Files.Set(Ri, F, 0);
		Texts.OpenReader(R, T, beg);
		Texts.Read(R, ch);
		WHILE ~R.eot & (ch <= " ") & (R.lib IS Fonts.Font) DO
			Texts.Read(R, ch)
		END;
		WHILE ~R.eot & (R.lib IS Fonts.Font) DO
			IF ch = "=" THEN
				Texts.Read(R, ch1); Texts.Read(R, ch2);
				IF Strings.IsHexDigit(ch1) & Strings.IsHexDigit(ch2) THEN
					ch := CHR(HexVal(ch1)*16+HexVal(ch2));
					IF ~binary THEN
						ch := Strings.ISOToOberon[ORD(ch)]
					END;
					ReadWrite(ch)
				ELSIF ch1 = Strings.CR THEN
					ch := ch2
				ELSE
					Files.Write(Ri, "="); Files.Write(Ri, ch1);
					ReadWrite(ch2)
				END
			ELSE
				ReadWrite(ch)
			END
		END;
		RETURN TRUE
	END decodeText;

	PROCEDURE Decode(binary: BOOLEAN);
		VAR
			S: Texts.Scanner;
			F: Files.File;
			T: Texts.Text;
			beg, end, time: SIGNED32;
	BEGIN
		Texts.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos);
		Texts.Scan(S);
		IF S.class IN {Texts.Name, Texts.String} THEN
			Texts.WriteString(W, S.s);
			F := Files.New(S.s);
			Texts.Scan(S);
			IF (S.class = Texts.Char) & ((S.c = "@") OR (S.c = "^")) THEN
				T := NIL;
				time := -1;
				Oberon.GetSelection(T, beg, end, time);
				IF T = NIL THEN
					RETURN
				END
			ELSIF S.class IN {Texts.Name, Texts.String} THEN
				NEW(T);
				Texts.Open(T, S.s);
				beg := 0
			ELSE
				beg := Texts.Pos(S);
				T := Oberon.Par.text
			END;
			IF decodeText(T, beg, F, binary) THEN
				Files.Register(F);
				Texts.WriteString(W, " done")
			ELSE
				Texts.WriteString(W, " failed")
			END;
			Texts.WriteLn(W);
			Texts.Append(Oberon.Log, W.buf)
		END
	END Decode;

	PROCEDURE DecodeText*;
	BEGIN
		Decode(FALSE)
	END DecodeText;

	PROCEDURE DecodeFile*;
	BEGIN
		Decode(TRUE)
	END DecodeFile;

BEGIN
	Texts.OpenWriter(W)
END QuotedPrintable.