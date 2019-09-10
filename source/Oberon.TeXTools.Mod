MODULE TeXTools IN Oberon;	(* pjm *)

(** Simple text-based tools for TeX files. *)

IMPORT Texts, Oberon;

VAR
	w: Texts.Writer;
	verb: ARRAY 10 OF CHAR;

PROCEDURE IsSpecial(ch: CHAR): BOOLEAN;
BEGIN
	RETURN (ch = "#") OR (ch = "$") OR (ch = "%") OR (ch = "&") OR (ch = "_") OR (ch = "{") OR (ch = "}")
END IsSpecial;

PROCEDURE IsVerbatim(ch: CHAR): BOOLEAN;
BEGIN
	RETURN (ch = "~") OR (ch = "^") OR (ch = "\") OR (ch = ">") OR (ch = "<") OR (ch = "|")
END IsVerbatim;

(** Convert selected text in-place from readable text to LaTeX tabbing environment syntax. *)

PROCEDURE Tabbing*;	(** ^ *)
VAR text: Texts.Text; beg, end, time: SIGNED32; r: Texts.Reader; ch: CHAR;
BEGIN
	Oberon.GetSelection(text, beg, end, time);
	IF time # -1 THEN
		Texts.OpenReader(r, text, beg); Texts.Read(r, ch);
		WHILE ~r.eot & (Texts.Pos(r) <= end) DO
			IF ch = 9X THEN Texts.WriteString(w, "\>")
			ELSIF (ch = 0DX) & (Texts.Pos(r) # end) THEN Texts.WriteString(w, "\\"); Texts.WriteLn(w)
			ELSIF IsSpecial(ch) THEN Texts.Write(w, "\"); Texts.Write(w, ch)
			ELSIF IsVerbatim(ch) THEN Texts.WriteString(w, "\verb"); Texts.Write(w, 22X); Texts.Write(w, ch); Texts.Write(w, 22X)
			ELSE Texts.Write(w, ch)
			END;
			Texts.Read(r, ch)
		END;
		Texts.Insert(text, end, w.buf);
		Texts.Delete(text, beg, end)
	ELSE
		Texts.WriteString(w, "No text selected"); Texts.WriteLn(w);
		Texts.Append(Oberon.Log, w.buf)
	END
END Tabbing;

(** Convert selected text in-place from LaTeX tabbing environment syntax to readable text. *)

PROCEDURE Tabs*;
VAR text: Texts.Text; beg, end, time, i: SIGNED32; r: Texts.Reader; ch: CHAR; s: ARRAY 10 OF CHAR;
BEGIN
	Oberon.GetSelection(text, beg, end, time);
	IF time # -1 THEN
		Texts.OpenReader(r, text, beg); Texts.Read(r, ch);
		WHILE ~r.eot & (Texts.Pos(r) <= end) DO
			IF ch = "\" THEN
				Texts.Read(r, ch);
				IF ch = 0X THEN (* skip *)
				ELSIF ch = ">" THEN Texts.Write(w, 9X)
				ELSIF ch = "\" THEN (* skip *)
				ELSIF IsSpecial(ch) THEN Texts.Write(w, ch)
				ELSIF ch = "v" THEN 	(* possibly \verb"x" *)
					s := "\v"; i := 2;
					Texts.Read(r, ch);
					WHILE (ch # 0X) & (ch = verb[i]) DO s[i] := ch; INC(i); Texts.Read(r, ch) END;
					IF (ch # 0X) & (verb[i] = 0X) THEN (* full match *)
						s[i] := ch; INC(i);	(* starting quote *)
						Texts.Read(r, ch);	(* special character *)
						IF IsVerbatim(ch) THEN
							Texts.Write(w, ch);
							Texts.Read(r, ch);	(* closing quote *)
							i := 0; ch := 0X
						END
					END;
					s[i] := 0X; Texts.WriteString(w, s);
					IF ch # 0X THEN Texts.Write(w, ch) END
				ELSE Texts.Write(w, "\"); Texts.Write(w, ch)
				END
			ELSE Texts.Write(w, ch)
			END;
			IF ~r.eot THEN Texts.Read(r, ch) END
		END;
		Texts.Insert(text, end, w.buf);
		Texts.Delete(text, beg, end)
	ELSE
		Texts.WriteString(w, "No text selected"); Texts.WriteLn(w);
		Texts.Append(Oberon.Log, w.buf)
	END
END Tabs;

BEGIN
	Texts.OpenWriter(w);
	verb := "\verb"
END TeXTools.

(*
to do:
o > and < should really be math mode
*)

System.Free TeXTools ~

TeXTools.Tabbing
TeXTools.Tabs

