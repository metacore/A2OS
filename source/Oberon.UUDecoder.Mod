(* ETH Oberon, Copyright 2001 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

MODULE UUDecoder IN Oberon; (** portable *)	(* ejz  *)
	IMPORT Files, Texts, Oberon;

	VAR
		encTable: ARRAY 64 OF CHAR;
		decTable: ARRAY 97 OF SIGNED16;
		W: Texts.Writer;

	PROCEDURE GetName*(T: Texts.Text; VAR beg: SIGNED32; VAR name: ARRAY OF CHAR): BOOLEAN;
		VAR S: Texts.Scanner;
	BEGIN
		Texts.OpenScanner(S, T, beg);
		Texts.Scan(S);
		WHILE ~S.eot & ((S.class # Texts.Name) OR (S.s # "begin")) DO
			Texts.Scan(S)
		END;
		IF (S.class = Texts.Name) & (S.s = "begin") THEN
			Texts.Scan(S);
			IF S.class # Texts.Name THEN
				Texts.Scan(S)
			END;
			IF S.class IN {Texts.Name, Texts.String} THEN
				beg := Texts.Pos(S);
				COPY(S.s, name);
				RETURN TRUE
			END
		END;
		RETURN FALSE
	END GetName;

	PROCEDURE DecodeText*(T: Texts.Text; beg: SIGNED32; F: Files.File): BOOLEAN;
		VAR
			R: Texts.Reader;
			ch: CHAR;
			bytes, chars, c0, c1, c2, c3: SIGNED16;
			Ri: Files.Rider;
			ok: BOOLEAN;
	BEGIN
		Files.Set(Ri, F, 0);
		ok := TRUE;
		Texts.OpenReader(R, T, beg);
		Texts.Read(R, ch);
		REPEAT
			WHILE ~R.eot & (ch <= " ") DO
				Texts.Read(R, ch)
			END;
			IF (ch >= CHR(32)) & (ch <= CHR(96)) THEN
				bytes := decTable[ORD(ch)];
				chars := bytes DIV 3;
				IF (bytes MOD 3) # 0 THEN
					INC(chars)
				END;
				Texts.Read(R, ch);
				WHILE ~R.eot & (chars > 0) & ok DO
					IF (ch >= CHR(32)) & (ch <= CHR(96)) THEN
						c0 := decTable[ORD(ch)]
					ELSE
						ok := FALSE
					END;
					Texts.Read(R, ch);
					IF (ch >= CHR(32)) & (ch <= CHR(96)) THEN
						c1 := decTable[ORD(ch)]
					ELSE
						ok := FALSE
					END;
					Texts.Read(R, ch);
					IF (ch >= CHR(32)) & (ch <= CHR(96)) THEN
						c2 := decTable[ORD(ch)]
					ELSE
						ok := FALSE
					END;
					Texts.Read(R, ch);
					IF (ch >= CHR(32)) & (ch <= CHR(96)) THEN
						c3 := decTable[ORD(ch)]
					ELSE
						ok := FALSE
					END;
					Files.Write(Ri, CHR(ASH(c0, 2)+ASH(c1, -4)));
					DEC(bytes);
					IF bytes > 0 THEN
						Files.Write(Ri, CHR(ASH(c1, 4)+ASH(c2, -2)));
						DEC(bytes);
						IF bytes > 0 THEN
							Files.Write(Ri, CHR(ASH(c2, 6)+c3));
							DEC(bytes)
						END
					END;
					DEC(chars);
					Texts.Read(R, ch)
				END;
				ok := chars <= 0
			ELSE
				RETURN ch = "e"
			END;
		UNTIL R.eot OR ~ok;
		RETURN ok
	END DecodeText;

	PROCEDURE Do(T: Texts.Text; beg: SIGNED32);
		VAR
			name: ARRAY 32 OF CHAR;
			F: Files.File;
	BEGIN
		IF GetName(T, beg, name) THEN
			Texts.WriteString(W, name);
			Texts.WriteString(W, " decoding ");
			Texts.Append(Oberon.Log, W.buf);
			F := Files.New(name);
			IF DecodeText(T, beg, F) THEN
				Files.Register(F);
				Texts.WriteString(W, "done")
			ELSE
				Texts.WriteString(W, "failed")
			END
		ELSE
			Texts.WriteString(W, "begin not found")
		END;
		Texts.WriteLn(W);
		Texts.Append(Oberon.Log, W.buf)
	END Do;

	PROCEDURE Decode*;
		VAR
			S: Texts.Scanner;
			T: Texts.Text;
			beg, end, time: SIGNED32;
	BEGIN
		Texts.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos);
		Texts.Scan(S);
		IF (S.class = Texts.Char) & (S.c = "@") THEN
			T := NIL;
			time := -1;
			Oberon.GetSelection(T, beg, end, time);
			IF T # NIL THEN
				Do(T, beg)
			END
		ELSIF (S.class = Texts.Name) & (S.s = "begin") THEN
			Do(Oberon.Par.text, Oberon.Par.pos)
		ELSE
			NEW(T);
			WHILE S.class IN {Texts.Name, Texts.String} DO
				Texts.Open(T, S.s);
				Do(T, 0);
				Texts.Scan(S)
			END;
			IF (S.class = Texts.Char) & (S.c ="^") THEN
				T := NIL;
				time := -1;
				Oberon.GetSelection(T, beg, end, time);
				IF T # NIL THEN
					Texts.OpenScanner(S, T, beg);
					WHILE S.class IN {Texts.Name, Texts.String} DO
						Texts.Open(T, S.s);
						Do(T, 0);
						Texts.Scan(S)
					END
				END
			END
		END
	END Decode;

	PROCEDURE InitUUTables;
		VAR i: SIGNED16;
	BEGIN
		FOR i := 0 TO 63 DO
			encTable[i] := CHR(i+32)
		END;
		encTable[0] := CHR(96);
		FOR i := 0 TO 96 DO
			decTable[i] := 0
		END;
		FOR i := 0 TO 63 DO
			decTable[ORD(encTable[i])] := i
		END
	END InitUUTables;

BEGIN
	Texts.OpenWriter(W);
	InitUUTables()
END UUDecoder.