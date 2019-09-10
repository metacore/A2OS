(* Aos, Copyright 2001, Pieter Muller, ETH Zurich *)

MODULE Copyright IN Oberon;	(* pjm *)

(* based on Copyright.Mod *)

	IMPORT Files, Fonts, Texts, Oberon;

	CONST
		Len = 6; Tag = "(* Aos";
		CopyText = "Copyright.Text";

	VAR
		W: Texts.Writer;

	PROCEDURE Check(T: Texts.Text);
		VAR R: Texts.Reader; copy: ARRAY Len+1 OF CHAR; ch: CHAR; i: SIGNED32;
	BEGIN
		Texts.OpenReader(R, T, 0);
		FOR i := 0 TO Len-1 DO Texts.Read(R, copy[i]) END;
		copy[Len] := 0X; ASSERT(copy = Tag);
		Texts.Read(R, ch);
		WHILE ~R.eot & (ch # "*") DO Texts.Read(R, ch) END;
		ASSERT(ch = "*");
		Texts.Read(R, ch);
		ASSERT(ch = ")");
		Texts.Read(R, ch);
		WHILE ~R.eot & ((ch = " ") OR (ch = 9X) OR (ch = 0DX)) DO Texts.Read(R, ch) END;
		ASSERT(R.eot)
	END Check;

	PROCEDURE GetName(VAR name: ARRAY OF CHAR);
	VAR f: Files.File;
	BEGIN
		f := Files.Old(name);
		IF f # NIL THEN Files.GetName(f, name) END
	END GetName;

	PROCEDURE Scan(VAR S: Texts.Scanner);
	BEGIN
		Texts.Scan(S);
		IF (S.class = Texts.Char) & (S.c = Oberon.OptionChar) THEN
			Texts.Scan(S);  Texts.Scan(S)
		END
	END Scan;

	PROCEDURE Add*;
		VAR S: Texts.Scanner; C, T: Texts.Text; B: Texts.Buffer; F: Files.File; len: SIGNED32;
	BEGIN
		NEW(C); Texts.Open(C, CopyText); Check(C);
		NEW(B); Texts.OpenBuf(B);
		Texts.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos);
		Scan(S);
		WHILE S.class IN {Texts.Name, Texts.String} DO
			GetName(S.s);
			Texts.Save(C, 0, C.len, B);
			Texts.WriteString(W, S.s); Texts.Append(Oberon.Log, W.buf);
			NEW(T); Texts.Open(T, S.s);
			Texts.Insert(T, 0, B);
			F := Files.New(S.s); len := 0;
			Texts.Store(T, F, 0, len); Files.Register(F);
			Texts.WriteLn(W); Texts.Append(Oberon.Log, W.buf);
			Scan(S)
		END
	END Add;

	PROCEDURE Remove*;
		VAR S: Texts.Scanner; T: Texts.Text; F: Files.File; len, i: SIGNED32; R: Texts.Reader;
			copy: ARRAY Len+1 OF CHAR; ch: CHAR;
	BEGIN
		Texts.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos);
		Scan(S); copy[Len] := 0X;
		WHILE S.class IN {Texts.Name, Texts.String} DO
			GetName(S.s);
			Texts.WriteString(W, S.s); Texts.Append(Oberon.Log, W.buf);
			NEW(T); Texts.Open(T, S.s);
			Texts.OpenReader(R, T, 0);
			FOR i := 0 TO Len-1 DO Texts.Read(R, copy[i]) END;
			IF copy = Tag THEN
				WHILE ~R.eot & (ch # "*") DO
					Texts.Read(R, ch)
				END;
				IF ch = "*" THEN
					Texts.Read(R, ch); ASSERT(ch = ")");
					Texts.Read(R, ch);
					WHILE ~R.eot & (ch <= " ") & (R.lib IS Fonts.Font) DO
						Texts.Read(R, ch)
					END
				END;
				Texts.Delete(T, 0, Texts.Pos(R)-1);
				F := Files.New(S.s); len := 0;
				Texts.Store(T, F, 0, len);
				Files.Register(F);
			ELSE
				Texts.WriteString(W, " no copyright found")
			END;
			Texts.WriteLn(W); Texts.Append(Oberon.Log, W.buf);
			Scan(S)
		END
	END Remove;

	PROCEDURE Replace*;
		VAR S: Texts.Scanner; C, T: Texts.Text; B: Texts.Buffer; F: Files.File; len, i: SIGNED32; R: Texts.Reader;
			copy: ARRAY Len+1 OF CHAR; ch: CHAR;
	BEGIN
		Texts.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos);
		Scan(S); copy[Len] := 0X;
		NEW(C); Texts.Open(C, CopyText);  Check(C);
		NEW(B); Texts.OpenBuf(B);
		WHILE S.class IN {Texts.Name, Texts.String} DO
			GetName(S.s);
			Texts.WriteString(W, S.s); Texts.Append(Oberon.Log, W.buf);
			NEW(T); Texts.Open(T, S.s);
			Texts.OpenReader(R, T, 0);
			FOR i := 0 TO Len-1 DO Texts.Read(R, copy[i]) END;
			IF copy = Tag THEN
				WHILE ~R.eot & (ch # "*") DO
					Texts.Read(R, ch)
				END;
				IF ch = "*" THEN
					Texts.Read(R, ch); ASSERT(ch = ")");
					Texts.Read(R, ch);
					WHILE ~R.eot & (ch <= " ") & (R.lib IS Fonts.Font) DO
						Texts.Read(R, ch)
					END
				END;
				Texts.Delete(T, 0, Texts.Pos(R)-1);
				Texts.Save(C, 0, C.len, B);
				Texts.Insert(T, 0, B);
				F := Files.New(S.s); len := 0;
				Texts.Store(T, F, 0, len);
				Files.Register(F);
			ELSE
				Texts.WriteString(W, " no copyright found")
			END;
			Texts.WriteLn(W); Texts.Append(Oberon.Log, W.buf);
			Scan(S)
		END
	END Replace;

BEGIN
	Texts.OpenWriter(W)
END Copyright.

Copyright.Add Aos.Mod ~
Copyright.Remove Aos.Mod ~
Copyright.Replace Aos.Mod ~
