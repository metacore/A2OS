(* ETH Oberon, Copyright 2001 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

MODULE AsciiCoder IN Oberon;	(** portable *) (* Wolfgang Weck 14 Dec 93, compression due to Stefan Ludwig/ jm modified for System 3 *)

	IMPORT Oberon, Texts, Files, Display;

	CONST
		Base = 48; StopBase = 35;
		N = 16384;

	TYPE
		NameList = POINTER TO NameDesc;
		NameDesc = RECORD
			next: NameList;
			name: ARRAY 64 OF CHAR
		END;

	VAR
		w: Texts.Writer;
		table: ARRAY N OF CHAR;	(* hash table for compression *)

	PROCEDURE Compress*(src, dest: Files.File);	(* due to Stefan Ludwig *)
		VAR hash, byte, bit, i: SIGNED32; ch: CHAR; from, to: Files.Rider;
	BEGIN
		i := 0; REPEAT table[i] := 0X; INC(i) UNTIL i = N;
		Files.Set(from, src, 0); Files.Set(to, dest, 0);
		i := Files.Length(src); Files.WriteNum(to, i);
		IF i > 0 THEN
			hash := 0; bit := 0; byte := 0;
			REPEAT
				Files.Read(from, ch);
				IF table[hash] = ch THEN	(* 0 bit for correct prediction *)
					INC(bit); IF bit = 8 THEN Files.Write(to, CHR(byte)); byte := 0; bit := 0 END
				ELSE	(* Incorrect prediction -> 1'xxxx'xxxx bits where x = ch[0..7] *)
					table[hash] := ch; INC(byte, ASH(1, bit)); INC(bit);
					IF bit = 8 THEN Files.Write(to, CHR(byte)); Files.Write(to, ch);  byte := 0; bit := 0
					ELSE Files.Write(to, CHR(byte+ASH(ORD(ch), bit) MOD 256)); byte := ASH(ORD(ch), bit) DIV 256
					END
				END;
				DEC(i); hash := (16*hash+ORD(ch)) MOD N	(* hash value *)
			UNTIL i = 0;
			IF bit # 0 THEN Files.Write(to, CHR(byte)) END	(* write last byte *)
		END
	END Compress;

	PROCEDURE Expand*(src, dest: Files.File);	(* due to Stefan Ludwig *)
		VAR hash, val, byte, bit, i: SIGNED32; ch: CHAR; from, to: Files.Rider;
	BEGIN
		i := 0; REPEAT table[i] := 0X; INC(i) UNTIL i = N;
		Files.Set(from, src, 0); Files.Set(to, dest, 0);
		Files.ReadNum(from, i);
		IF i > 0 THEN
			Files.Read(from, ch); val := ORD(ch); bit := 0; hash := 0;
			REPEAT
				INC(bit);
				IF ODD(val) THEN	(* Incorrect prediction -> 1'xxxx'xxxx *)
					Files.Read(from, ch);
					IF bit = 8 THEN byte := ORD(ch)
					ELSE byte := val DIV 2 + ASH(ORD(ch), 8-bit) MOD 256; val := ASH(ORD(ch), -bit)
					END;
					table[hash] := CHR(byte)
				ELSE byte := ORD(table[hash]); val := val DIV 2	(* correct prediction *)
				END;
				hash := (16*hash+byte) MOD N; Files.Write(to, CHR(byte)); DEC(i);
				IF bit = 8 THEN Files.Read(from, ch); val := ORD(ch); bit := 0 END
			UNTIL i = 0
		END
	END Expand;

	PROCEDURE Code*(from: Files.File; to: Texts.Text);
		VAR byte, rest, div, factor, packs: SIGNED16; ch: CHAR; r: Files.Rider;
	BEGIN Files.Set(r, from, 0); Files.Read(r, ch); byte := ORD(ch); rest := 0; div := 64; factor  := 1; packs := 0;
		WHILE ~r.eof DO Texts.Write(w, CHR(Base + rest + (byte MOD div) * factor)); rest := byte DIV div;
			IF div = 4 THEN Texts.Write(w, CHR(Base + rest));
				rest := 0; div := 64; factor  := 1; INC(packs);
				IF packs = 19 THEN Texts.WriteLn(w); packs := 0 END
			ELSE factor := factor * 4; div := div DIV 4
			END;
			Files.Read(r, ch); byte := ORD(ch)
		END;
		IF div = 64 THEN Texts.Write(w, CHR(StopBase))
		ELSIF div = 16 THEN Texts.Write(w, CHR(Base + rest)); Texts.Write(w, CHR(StopBase + 1))
		ELSIF div = 4 THEN Texts.Write(w, CHR(Base + rest)); Texts.Write(w, CHR(StopBase + 2))
		END;
		Texts.WriteLn(w); Texts.Append(to, w.buf)
	END Code;

	PROCEDURE Decode*(from: Texts.Text; VAR pos: SIGNED32; to: Files.File; VAR ok: BOOLEAN);
		VAR rest, div, factor, byte: SIGNED16; ch: CHAR; r: Texts.Reader; w: Files.Rider;
	BEGIN Texts.OpenReader(r, from, pos); Files.Set(w, to, 0); factor := 1; div := 256; rest := 0;
		REPEAT Texts.Read(r, ch) UNTIL (ch > " ") OR r.eot;
		WHILE ~r.eot & (ch >= CHR(Base)) & (ch < CHR(Base + 64)) DO byte := ORD(ch) - Base;
			IF factor # 1 THEN Files.Write(w, CHR(rest + (byte MOD div) * factor));
				rest := byte DIV div; div := div * 4; factor := factor DIV 4
			ELSE rest := byte; div := 4; factor := 64
			END;
			REPEAT Texts.Read(r, ch) UNTIL (ch > " ") OR r.eot
		END;
		byte := ORD(ch) - StopBase;
		ok := (byte = 0) & (div = 256) OR (byte = 1) & (div = 16) OR (byte = 2) & (div = 64) & (rest = 0);
		pos := Texts.Pos(r)
	END Decode;

	PROCEDURE OpenViewer(name: ARRAY OF CHAR; text: Texts.Text);
	BEGIN
		Oberon.OpenText(name, text, Display.Width DIV 8 * 3 + 20, Display.Height DIV 2)
	END OpenViewer;

	PROCEDURE ReadFileNames(t: Texts.Text; beg, end: SIGNED32; VAR names: NameList; VAR pos: SIGNED32);
		VAR last, n: NameList; s: Texts.Scanner;
	BEGIN NEW(names); last := names; Texts.OpenScanner(s, t, beg); pos := beg; Texts.Scan(s);
		WHILE (pos < end) & ((s.class = Texts.String) OR (s.class = Texts.Name)) DO NEW(n); last.next := n; last := n;
			COPY(s.s, n.name);
			pos := Texts.Pos(s); Texts.Scan(s);
			IF (s.class = Texts.Char) & (s.c = ",") THEN Texts.Scan(s) END
		END;
		last.next := NIL; names := names.next; pos := Texts.Pos(s)
	END ReadFileNames;

	PROCEDURE CodeFiles*;
		VAR pos, beg, end, time: SIGNED32; compress: BOOLEAN; names, n: NameList;
			f, f1: Files.File; text: Texts.Text; s: Texts.Scanner;
	BEGIN pos := Oberon.Par.pos; compress := FALSE;
		Texts.OpenScanner(s, Oberon.Par.text, pos); Texts.Scan(s);
		IF (s.line = 0) & (s.class = Texts.Char)  & (s.c = "%") THEN compress := TRUE; pos := Texts.Pos(s); Texts.Scan(s) END;
		IF (s.line = 0) & (s.class = Texts.Char)  & (s.c = "^") THEN Oberon.GetSelection(text, beg, end, time);
			IF time >= 0 THEN ReadFileNames(text, beg, end, names, time) ELSE names := NIL END
		ELSE ReadFileNames(Oberon.Par.text, pos, Oberon.Par.text.len, names, time)
		END;
		IF names # NIL THEN n := names; NEW(text); Texts.Open(text, "");
			Texts.WriteString(w, "AsciiCoder.CodeFiles"); Texts.WriteLn(w);
			REPEAT f := Files.Old(n.name); Texts.WriteString(w, n.name);
				IF f = NIL THEN Texts.WriteString(w, " not found"); n.name := ""
				ELSE Texts.WriteString(w, " coding"); Texts.Append(Oberon.Log, w.buf);
					IF compress THEN f1 := Files.New(""); Compress(f, f1); f := f1 END;
					Code(f, text)
				END;
				Texts.WriteLn(w); Texts.Append(Oberon.Log, w.buf); n := n.next
			UNTIL n = NIL;
			Texts.WriteString(w,"To: "); Texts.WriteLn(w);
			Texts.WriteString(w,"Subject:");
			n := names;
			WHILE n # NIL DO
				IF n.name # "" THEN Texts.Write(w, " "); Texts.WriteString(w, n.name) END;
				n := n.next
			END;
			Texts.WriteLn(w); Texts.WriteLn(w);
			Texts.WriteString(w,"AsciiCoder.DecodeFiles ");
			IF compress THEN Texts.WriteString(w, "% ") END;
			REPEAT
				IF names.name # "" THEN Texts.WriteString(w, names.name); Texts.Write(w, " ") END;
				names := names.next
			UNTIL names = NIL;
			Texts.Write(w, "~"); Texts.WriteLn(w); Texts.WriteLn(w); Texts.Insert(text, 0, w.buf);
			Texts.WriteInt(w, text.len, 0); Texts.WriteString(w, " characters"); Texts.WriteLn(w);
			Texts.Append(Oberon.Log, w.buf);
			OpenViewer("AsciiCoder.CodeFiles", text)
		END
	END CodeFiles;

	PROCEDURE DecodeFiles*;
		VAR pos, beg, end, time: SIGNED32; i, res: SIGNED16; ch: CHAR; ok, compress: BOOLEAN;
			f, f1: Files.File; text: Texts.Text; s: Texts.Scanner; names: NameList; bakname: ARRAY 256 OF CHAR;
	BEGIN text := Oberon.Par.text; pos := Oberon.Par.pos; compress := FALSE;
		Texts.OpenScanner(s, text, pos); Texts.Scan(s);
		IF (s.line = 0) & (s.class = Texts.Char)  & (s.c = "%") THEN compress := TRUE; pos := Texts.Pos(s); Texts.Scan(s) END;
		IF (s.line = 0) & (s.class = Texts.Char)  & (s.c = "@") THEN Oberon.GetSelection(text, beg, end, time);
			IF time >= 0 THEN ReadFileNames(text, beg, end, names, pos) ELSE names := NIL END
		ELSE ReadFileNames(text, pos, text.len, names, pos)
		END;
		Texts.WriteString(w, "AsciiCoder.DecodeFiles"); Texts.WriteLn(w); ok := TRUE;
		WHILE (names # NIL) & ok DO f := Files.New(names.name);
			Texts.WriteString(w, names.name); Texts.WriteString(w, " decoding"); Texts.Append(Oberon.Log, w.buf);
			i := 0; ch := names.name[0];
			WHILE ch # 0X DO bakname[i] := ch; INC(i); ch := names.name[i] END;
			bakname[i] := "."; bakname[i + 1] := "B"; bakname[i + 2] := "a"; bakname[i + 3] := "k"; bakname[i + 4] := 0X;
			Files.Rename(names.name, bakname, res); Decode(text, pos, f, ok);
			IF ok THEN
				IF compress THEN f1 := Files.New(names.name); Expand(f, f1); f := f1 END;
				Files.Register(f)
			ELSE Texts.WriteString(w, " error.")
			END;
			Texts.WriteLn(w); Texts.Append(Oberon.Log, w.buf); names := names.next
		END
	END DecodeFiles;

	PROCEDURE CodeText*;
		VAR beg, end, time: SIGNED32; compress: BOOLEAN;
			f, f1: Files.File; t, text: Texts.Text; s: Texts.Scanner; len: SIGNED32;
	BEGIN compress := FALSE;
		Texts.OpenScanner(s, Oberon.Par.text, Oberon.Par.pos); Texts.Scan(s);
		IF (s.line = 0) & (s.class = Texts.Char)  & (s.c = "%") THEN compress := TRUE; Texts.Scan(s) END;
		IF (s.line = 0) & (s.class = Texts.Char) THEN t := NIL;
			IF s.c = "*" THEN t := Oberon.MarkedText()
			ELSIF s.c = "@" THEN Oberon.GetSelection(text, beg, end, time);
				IF time >= 0 THEN NEW(t); Texts.Open(t, ""); Texts.Save(text, beg, end, w.buf); Texts.Append(t, w.buf) END
			END;
			IF t # NIL THEN f := Files.New(""); (*Files.Set(r, f, 0);
				Files.Write(r, 0F0X); Files.Write(r, 01X); Texts.Store(r, t); *)
				Texts.Store(t, f, 0, len);
				NEW(text); Texts.Open(text, "");
				Texts.WriteString(w,"To: "); Texts.WriteLn(w);
				Texts.WriteString(w,"Subject: "); Texts.WriteLn(w); Texts.WriteLn(w);
				Texts.WriteString(w, "AsciiCoder.DecodeText");
				IF compress THEN Texts.WriteString(w, " %") END;
				Texts.WriteLn(w); Texts.WriteLn(w); Texts.Append(text, w.buf);
				IF compress THEN f1 := Files.New(""); Compress(f, f1); f := f1 END;
				Code(f, text); OpenViewer("AsciiCoder.CodeText", text);
				Texts.WriteString(w, "AsciiCoder.CodeText "); Texts.WriteInt(w, text.len, 0);
				Texts.WriteString(w, " characters"); Texts.WriteLn(w); Texts.Append(Oberon.Log, w.buf)
			END
		END
	END CodeText;

	PROCEDURE DecodeText*;
		VAR pos, beg, end, time: SIGNED32; ok, compress: BOOLEAN;
			f, f1: Files.File; text: Texts.Text; s: Texts.Scanner; len: SIGNED32;
	BEGIN compress := FALSE; pos := Oberon.Par.pos; f := Files.New("");
		Texts.OpenScanner(s, Oberon.Par.text, Oberon.Par.pos); Texts.Scan(s);
		IF (s.line = 0) & (s.class = Texts.Char)  & (s.c = "%") THEN compress := TRUE; pos := Texts.Pos(s); Texts.Scan(s) END;
		IF (s.line = 0) & (s.class = Texts.Char)  & (s.c = "@") THEN Oberon.GetSelection(text, beg, end, time);
			IF time >= 0 THEN Decode(text, beg, f, ok) ELSE ok := FALSE END
		ELSE Decode(Oberon.Par.text, pos, f, ok)
		END;
		IF ok THEN
			IF compress THEN f1 := Files.New(""); Expand(f, f1); f := f1 END;
			NEW(text); Texts.Open(text, ""); (*Files.Set(r, f, 2); Texts.Load(r, text);*) Texts.Load(text, f, 1, len);
			OpenViewer("AsciiCoder.DecodeText", text)
		ELSE Texts.WriteString(w, "AsciiCoder.DecodeText error."); Texts.WriteLn(w); Texts.Append(Oberon.Log, w.buf)
		END
	END DecodeText;

BEGIN Texts.OpenWriter(w)
END AsciiCoder.

AsciiCoder.CodeText *
AsciiCoder.DecodeText
