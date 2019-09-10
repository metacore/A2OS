(* ETH Oberon, Copyright 2001 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

MODULE Rot13 IN Oberon;	(** portable *)	(** eos 24-Nov-95 **)

	IMPORT
		Fonts, Texts, Oberon;

	VAR
		W: Texts.Writer;

	(** decode rot13 encrypted selection **)
	PROCEDURE Decode*;
		VAR text: Texts.Text; beg, end, time: SIGNED32; r: Texts.Reader; ch: CHAR;
	BEGIN
		Oberon.GetSelection(text, beg, end, time);
		IF time >= 0 THEN
			Texts.OpenReader(r, text, beg);
			WHILE Texts.Pos(r) < end DO
				Texts.Read(r, ch);
				IF r.lib IS Fonts.Font THEN
					IF CAP(ch) < "A" THEN
						Texts.Write(W, ch)
					ELSIF CAP(ch) < CHR(ORD("A") + 13) THEN
						Texts.Write(W, CHR(ORD(ch) + 13))
					ELSIF CAP(ch) <= "Z" THEN
						Texts.Write(W, CHR(ORD(ch) - 13))
					ELSE
						Texts.Write(W, ch)
					END
				ELSE
					Texts.Delete(text, beg, Texts.Pos(r) - 1);
					Texts.Insert(text, beg, W.buf);
					beg := Texts.Pos(r)
				END
			END;
			Texts.Delete(text, beg, end);
			Texts.Insert(text, beg, W.buf)
		END
	END Decode;

BEGIN
	Texts.OpenWriter(W)
END Rot13.
