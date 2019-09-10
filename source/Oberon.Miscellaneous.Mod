(* ETH Oberon, Copyright 2001 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

MODULE Miscellaneous IN Oberon;	(** portable, except where noted *) (*JG 20.5.94 / NW 22.2.88*)

(* AFI 12.03.2003 - procedure PrintFiles modified to support 8 serial ports i.o. 4 *)

  IMPORT Files, Fonts, Texts, Oberon, Centronics, V24, Strings;

  CONST  TAB =  9X; CR = 0DX; LF = 0AX; BitmapId = 39X;
        StandardMenu = "System.Close System.Copy System.Grow Edit.Search Edit.Store";
        xOn = 11X; xOff = 13X;

  TYPE FileName = ARRAY 32 OF CHAR;

  VAR W: Texts.Writer;
  		port: SIGNED16;

	PROCEDURE OpenScanner(VAR S: Texts.Scanner);
		VAR
			text: Texts.Text;
			beg, end, time: SIGNED32;
	BEGIN
		Texts.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos);
		Texts.Scan(S);
		IF (S.class = Texts.Char) & (S.c = "^") THEN
			text := NIL; time := -1; Oberon.GetSelection(text, beg, end, time);
			IF (text = NIL) OR (time = -1) THEN S.class := Texts.Inval; RETURN END;
			Texts.OpenScanner(S, text, beg); Texts.Scan(S)
		END
	END OpenScanner;

	PROCEDURE Count(name: ARRAY OF CHAR; VAR nofLines: SIGNED32; what: CHAR);
		VAR T: Texts.Text; R: Texts.Reader; ch: CHAR;
  BEGIN
		Texts.WriteString(W, name); Texts.Write(W, Strings.Tab);
		NEW(T); Texts.Open(T, name);
		Texts.OpenReader(R, T, 0); Texts.Read(R, ch);
		nofLines := 0;
		WHILE ~R.eot DO
			IF ch = what THEN INC(nofLines) END;
			Texts.Read(R, ch)
		END;
		Texts.WriteInt(W, nofLines, 0); Texts.Write(W, " ");
		IF what = Strings.CR THEN
			Texts.WriteString(W, "CR")
		ELSE
			Texts.Write(W, what)
		END;
		Texts.WriteLn(W)
  END Count;

	(** Count the number of lines in the specified texts. With \s switch count semicolons. *)
	PROCEDURE CountLines*;	(** non-portable *)
		VAR
			S: Texts.Scanner; T: Texts.Text;
			nofLines, totalLines, beg, end, time: SIGNED32;
			what: CHAR;
	BEGIN
		totalLines := 0; what := Strings.CR;
		Texts.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos); Texts.Scan(S);
		IF (S.class = Texts.Char) & (S.c = Oberon.OptionChar) THEN
			IF S.nextCh = "s" THEN what := ";" END;
			Texts.Scan(S); Texts.Scan(S)
		END;
		IF (S.class = Texts.Char) & (S.c = "^") THEN
			T := NIL; time := -1;
			Oberon.GetSelection(T, beg, end, time);
			IF (T # NIL) & (time # -1) THEN
				Texts.OpenScanner(S, T, beg); Texts.Scan(S)
			ELSE
				S.class := Texts.Inval
			END
		ELSE
			end := Oberon.Par.text.len
		END;
		IF S.class IN {Texts.Name, Texts.String} THEN
			WHILE (S.class IN {Texts.Name, Texts.String}) & ((Texts.Pos(S)-S.len) <= end) DO
				Count(S.s, nofLines, what); totalLines := totalLines + nofLines; Texts.Scan(S)
			END;
			NEW(T); Texts.Open(T, "");
			IF what = Strings.CR THEN
				Oberon.OpenText("Lines", T, 380, 300)
			ELSE
				Oberon.OpenText("Semicolons", T, 380, 300)
			END;
			Texts.WriteLn(W); Texts.WriteString(W, "Total");
			Texts.Write(W, Strings.Tab); Texts.WriteInt(W, totalLines, 1);
			Texts.WriteLn(W); Texts.Append(T, W.buf)
		END
	END CountLines;

	PROCEDURE GetSize (VAR name: ARRAY OF CHAR; VAR varSize: SIGNED32;
		VAR constSize: SIGNED32; VAR codeSize: SIGNED32; T: Texts.Text);
		VAR f: Files.File; R: Files.Rider; x: SIGNED16; ch1, ch2: CHAR;  size: SIGNED32;
	BEGIN
		Texts.WriteString(W, name);  Texts.Append(T, W.buf);
		varSize := 0;  constSize := 0;  codeSize := 0;
		f := Files.Old(name);
		IF f # NIL THEN
			Files.Set(R, f, 0);
			Files.Read(R, ch1);  Files.Read(R, ch2);
			IF  (ch1 = 0BBX) & ((ch2 = 0AFX) OR (ch2= 0B0X)) THEN
				Files.ReadNum(R, size);
				Files.Set(R, f, Files.Pos(R)+size + 18);	(* skip symbol file & first header fields *)
				Files.ReadLInt(R, varSize);
				Files.ReadInt(R, x);  constSize := LONG(x) MOD 10000H;
				Files.ReadInt(R, x);  codeSize := LONG(x) MOD 10000H;
				Texts.WriteString(W, " var "); Texts.WriteInt(W, varSize, 1);
				Texts.WriteString(W, " const "); Texts.WriteInt(W, constSize, 1);
				Texts.WriteString(W, " code "); Texts.WriteInt(W, codeSize, 1)
			ELSE
				Texts.WriteString(W, " not an object file")
			END
		ELSE Texts.WriteString(W, " not found")
		END;
		Texts.WriteLn(W);  Texts.Append(T, W.buf)
	END GetSize;

(** Get the variable, constant and code segment sizes for the specified object files. *)
  PROCEDURE GetObjSize*;	(** non-portable *)
    VAR par: Oberon.ParList;
      S: Texts.Scanner;
      T: Texts.Text;
      constSize, codeSize,
      varSize, totalConstSize, totalVarSize, totalCodeSize: SIGNED32;
      beg, end, time: SIGNED32;
  BEGIN
    NEW(T); Texts.Open(T, "");
    Oberon.OpenText("ObjSize", T, 380, 300);
    totalVarSize := 0; totalConstSize := 0; totalCodeSize := 0;
    par := Oberon.Par;
    Texts.OpenScanner(S, par.text, par.pos); Texts.Scan(S);
    WHILE S.class = Texts.Name DO
      GetSize(S.s, varSize, constSize, codeSize, T);
      totalVarSize := totalVarSize + varSize;
      totalConstSize := totalConstSize + constSize;
      totalCodeSize := totalCodeSize + codeSize;
      Texts.Scan(S)
    END;
    IF (S.class = Texts.Char) & (S.c = "^") THEN Oberon.GetSelection(T, beg, end, time);
      IF time # -1 THEN Texts.OpenScanner(S, T, beg); Texts.Scan(S);
        IF S.class = Texts.Name THEN
          GetSize(S.s, varSize, constSize, codeSize, T);
          totalVarSize := totalVarSize + varSize;
          totalConstSize := totalConstSize + constSize;
          totalCodeSize := totalCodeSize + codeSize
        END
      END
    END;
    Texts.WriteString(W, " var "); Texts.WriteInt(W, totalVarSize, 1);
    Texts.WriteString(W, " const "); Texts.WriteInt(W, totalConstSize, 1);
    Texts.WriteString(W, " code "); Texts.WriteInt(W, totalCodeSize, 1);
    Texts.WriteLn(W);
    Texts.WriteInt(W, totalVarSize + totalConstSize + totalCodeSize, 1);
    Texts.WriteLn(W);
    Texts.Append(T, W.buf)
  END GetObjSize;

(** Convert Oberon text files to plain ASCII.  Syntax like System.CopyFiles. *)
  PROCEDURE MakeAscii*;	(** non-portable *)
    VAR  R: Texts.Reader; S: Texts.Scanner; T: Texts.Text;
      g: Files.File; Wg: Files.Rider; ch: CHAR; name: ARRAY 32 OF CHAR;
  BEGIN
    Texts.WriteString(W, "Miscellaneous.MakeAscii"); Texts.WriteLn(W);
    Texts.Append(Oberon.Log, W.buf);
    Texts.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos); Texts.Scan(S);
    WHILE S.class = Texts.Name DO
      COPY(S.s, name); Texts.Scan(S);
      IF (S.class = Texts.Char) & (S.c = "=") THEN Texts.Scan(S);
        IF (S.class = Texts.Char) & (S.c = ">") THEN Texts.Scan(S);
          IF S.class = Texts.Name THEN
            Texts.WriteString(W, name); Texts.WriteString(W," => ");
            Texts.WriteString(W, S.s); Texts.Append(Oberon.Log, W.buf);
            NEW(T); Texts.Open(T, name);
            g := Files.New(S.s); Files.Set(Wg, g, 0);
            Texts.OpenReader(R, T, 0); Texts.Read(R, ch);
            WHILE ~R.eot DO
           	 IF (R.lib IS Fonts.Font) & ((ch >= " ") & (ch < 7FX) OR (ch = TAB) OR (ch = CR)) THEN
            		Files.Write(Wg, ch)
         	   END;
          	  Texts.Read(R, ch)
            END;
            Files.Register(g);
            Texts.WriteLn(W);
            Texts.Append(Oberon.Log, W.buf)
          END
        END
      END;
      Texts.Scan(S)
    END;
  END MakeAscii;

    PROCEDURE DOSRead (VAR R: Files.Rider; VAR ch: CHAR);
    BEGIN Files.Read(R, ch);
       IF ch >= 80X THEN
         IF ch = 8EX THEN ch := 80X
           ELSIF ch = 99X THEN ch := 81X
           ELSIF ch = 9AX THEN ch := 82X
           ELSIF ch = 84X THEN ch := 83X
           ELSIF ch = 94X THEN ch := 84X
           ELSIF ch = 81X THEN ch := 85X
         END
      END
    END DOSRead;

(** Convert DOS text files to Oberon.  Syntax like System.CopyFiles. *)
  PROCEDURE MakeOberonText*;	(** non-portable *)
    VAR S: Texts.Scanner; f, g: Files.File; Rf, Wg: Files.Rider;
         ch: CHAR; name: ARRAY 32 OF CHAR;
  BEGIN
        Texts.WriteString(W, "Miscellaneous.MakeOberonText"); Texts.WriteLn(W);
        Texts.Append(Oberon.Log, W.buf);
    Texts.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos); Texts.Scan(S);
    WHILE S.class = Texts.Name DO
      COPY(S.s, name); Texts.Scan(S);
      IF (S.class = Texts.Char) & (S.c = "=") THEN Texts.Scan(S);
        IF (S.class = Texts.Char) & (S.c = ">") THEN Texts.Scan(S);
          IF S.class = Texts.Name THEN
            Texts.WriteString(W, name); Texts.WriteString(W," => ");
            Texts.WriteString(W, S.s); Texts.Append(Oberon.Log, W.buf);
            f := Files.Old(name); Files.Set(Rf, f, 0);
            g := Files.New(S.s); Files.Set(Wg, g, 0);
            DOSRead(Rf, ch);
            WHILE ~Rf.eof DO
                IF ch # LF THEN Files.Write(Wg, ch) END;
            	DOSRead(Rf, ch)
            END;
            Files.Register(g);
            Texts.WriteLn(W);
            Texts.Append(Oberon.Log, W.buf)
          END
        END
      END;
      Texts.Scan(S)
    END;
  END MakeOberonText;

    PROCEDURE OberonRead (VAR R: Texts.Reader; VAR ch: CHAR);
    BEGIN Texts.Read(R, ch);
       IF ch >= 80X THEN
         IF ch = 80X THEN ch := 8EX
           ELSIF ch = 81X THEN ch := 99X
           ELSIF ch = 82X THEN ch := 9AX
           ELSIF ch = 83X THEN ch := 84X
           ELSIF ch = 84X THEN ch := 94X
           ELSIF ch = 85X THEN ch := 81X
         END
      END
    END OberonRead;

(** Convert Oberon text to DOS ASCII format.  Syntax like System.CopyFiles. *)
  PROCEDURE MakeDOSText*;	(** non-portable *)
    CONST MaxWord = 128;
    VAR R: Texts.Reader; S: Texts.Scanner; T: Texts.Text;
          g: Files.File; Wg: Files.Rider; termCh: CHAR; pos, len, i: SIGNED16;
          name: ARRAY 32 OF CHAR; buf: ARRAY MaxWord OF CHAR;
  BEGIN
    Texts.WriteString(W, "Miscellaneous.MakeDOSText"); Texts.WriteLn(W);
    Texts.Append(Oberon.Log, W.buf);
    Texts.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos); Texts.Scan(S);
    WHILE S.class = Texts.Name DO
      COPY(S.s, name); Texts.Scan(S);
      IF (S.class = Texts.Char) & (S.c = "=") THEN Texts.Scan(S);
        IF (S.class = Texts.Char) & (S.c = ">") THEN Texts.Scan(S);
          IF S.class = Texts.Name THEN
            Texts.WriteString(W, name); Texts.WriteString(W," => ");
            Texts.WriteString(W, S.s); Texts.Append(Oberon.Log, W.buf);
            NEW(T); Texts.Open(T, name);
            g := Files.New(S.s); Files.Set(Wg, g, 0);
            Texts.OpenReader(R, T, 0); termCh := 0X; pos := 0;
            OberonRead(R, buf[0]);
            WHILE ~R.eot DO
            	len := 0;
                WHILE (len # MaxWord-1) & (buf[len] > " ") DO INC(len); OberonRead(R, buf[len]) END;
                IF (termCh = CR) OR (termCh # 0X) & (pos + 1 + len > 78) THEN
                  Files.Write(Wg, CR); Files.Write(Wg, LF); termCh := 0X; pos := 0
                END;
                IF termCh # 0X THEN Files.Write(Wg, termCh); INC(pos) END;
                i := 0;
                WHILE i # len DO Files.Write(Wg, buf[i]); INC(i) END;
                pos := pos + len; termCh := buf[i];
                OberonRead(R, buf[0])
            END;
            IF (termCh = CR) OR (termCh # 0X) & (pos + 1 > 78) THEN
              Files.Write(Wg, CR); Files.Write(Wg, LF); termCh := 0X; pos := 0
            END;
            IF termCh # 0X THEN Files.Write(Wg, termCh); INC(pos) END;
        Files.Register(g);
        Texts.WriteLn(W);
        Texts.Append(Oberon.Log, W.buf)
          END
        END
      END;
      Texts.Scan(S)
    END;
  END MakeDOSText;

	PROCEDURE V24Write(ch: CHAR);
	VAR dr: CHAR;  res: INTEGER;
	BEGIN
		IF V24.Available(port) > 0 THEN
			V24.Receive(port, dr, res);
			IF dr = xOff THEN
				REPEAT IF V24.Available(port) > 0 THEN V24.Receive(port, dr, res) END UNTIL dr = xOn
			END
		END;
		V24.Send(port, ch, res)
	END V24Write;

(** Send the listed files directly to the printer specified as first parameter. *)
	PROCEDURE PrintFiles*;	(** non-portable *)
	VAR S: Texts.Scanner; Port, fname: ARRAY 32 OF CHAR;
			f: Files.File; R: Files.Rider; ch: CHAR;  res: INTEGER;
	BEGIN
		Texts.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos); Texts.Scan(S);
		IF (S.class = Texts.Name) OR (S.class = Texts.String) THEN
			COPY(S.s, Port); Texts.Scan(S);
			WHILE (S.class = Texts.Name) OR (S.class = Texts.String) DO
				COPY(S.s, fname); Texts.WriteString(W, fname); Texts.WriteLn(W); Texts.Append(Oberon.Log, W.buf);
				IF (Port = "COM1") OR (Port = "COM2") OR (Port = "COM3") OR (Port = "COM4")
					OR (Port = "COM5") OR (Port = "COM6") OR (Port = "COM7") OR (Port = "COM8") THEN
					IF Port = "COM1" THEN port := 0
					ELSIF Port = "COM2" THEN port := 1
					ELSIF Port = "COM3" THEN port := 2
					ELSIF Port = "COM4" THEN port := 3
					ELSIF Port = "COM5" THEN port := 4
					ELSIF Port = "COM6" THEN port := 5
					ELSIF Port = "COM7" THEN port := 6
					ELSE port := 7
					END;
					V24.Start(port, 9600, 8, V24.ParNo, 1, res);  ASSERT(res = 0);
					f := Files.Old(fname);
					IF f # NIL THEN
						Files.Set(R, f, 0); Files.Read(R, ch);
						(*WHILE ch # "%" DO Files.Read(R, ch) END;*)
						WHILE ~R.eof DO V24Write(ch); Files.Read(R, ch) END;
						(*V24Write(4X);
						REPEAT IF V24.Available(port) > 0 THEN V24.Receive(port, ch) END UNTIL ch = 4X;*)
						V24.Stop(port);
						Files.Close(f);
					ELSE Texts.WriteString(W, "file not found"); Texts.WriteLn(W); Texts.Append(Oberon.Log, W.buf) END;
				ELSIF (Port = "LPT1") OR (Port = "LPT2") OR (Port = "LPT3") THEN
					IF Port = "LPT1" THEN port := Centronics.LPT1
					ELSIF Port = "LPT2" THEN port := Centronics.LPT2
					ELSE port := Centronics.LPT3 END;
					Centronics.Start(port);
					f := Files.Old(fname);
					IF f # NIL THEN
						Files.Set(R, f, 0); Files.Read(R, ch);
						(*WHILE ch # "%" DO Files.Read(R, ch) END;*)
						WHILE ~R.eof DO Centronics.Send(port, ch); Files.Read(R, ch) END;
						(*Centronics.Send(port, 4X);*)
						Files.Close(f)
					ELSE Texts.WriteString(W, "file not found"); Texts.WriteLn(W); Texts.Append(Oberon.Log, W.buf)
					END
				ELSE Texts.WriteString(W, "not a valid port"); Texts.WriteLn(W); Texts.Append(Oberon.Log, W.buf)
				END;
				Texts.Scan(S)
			END
		ELSE Texts.WriteString(W, "no port specified"); Texts.WriteLn(W); Texts.Append(Oberon.Log, W.buf)
		END
	END PrintFiles;

  PROCEDURE ExtName (i: SIGNED16; VAR org, new: ARRAY OF CHAR);
    VAR j: SIGNED16; strnum: ARRAY 10 OF CHAR; ch : CHAR;
  BEGIN j := 0;
    WHILE org[j] # 0X DO new[j] := org[j]; INC(j) END;
    Strings.IntToStr(i,strnum);
    i := 0;
    REPEAT
      ch := strnum[i];
      new[j] := ch;
      INC(i); INC(j);
    UNTIL ch = 0X;
  END ExtName;

(** Copy the specified file "File" into subfiles named "File0", "File1" etc., maximally 700k each *)
  PROCEDURE SplitFile*;
    VAR S: Texts.Scanner; f, g: Files.File; Rf, Rg: Files.Rider; i: SIGNED16; n: SIGNED32; ch: CHAR;
      name: ARRAY 32 OF CHAR;
  BEGIN
    OpenScanner(S);
    IF S.class = Texts.Name THEN f := Files.Old(S.s);
      IF f # NIL THEN Files.Set(Rf, f, 0); i := 0; n := 0; Files.Read(Rf, ch);
        WHILE ~Rf.eof DO
          ExtName(i, S.s, name); Texts.WriteString(W, name); Texts.Write(W, " ");
          Texts.Append(Oberon.Log, W.buf);
          g := Files.New(name); Files.Set(Rg, g, 0);
          REPEAT Files.Write(Rg, ch); INC(n); Files.Read(Rf, ch) UNTIL Rf.eof OR (n MOD (700*1024) = 0);
          Files.Register(g); Files.Close(g); INC(i)
        END;
        Texts.WriteLn(W); Texts.Append(Oberon.Log, W.buf)
      END
    END
  END SplitFile;

(** Copy subfiles "File0", "File1" etc. to a combined file "File".  Specify only parameter "File". *)
  PROCEDURE JoinFiles*;
    VAR S: Texts.Scanner; f, g: Files.File; Rf, Rg: Files.Rider; i: SIGNED16; ch: CHAR;
      name: ARRAY 32 OF CHAR;
  BEGIN
    OpenScanner(S);
    IF S.class = Texts.Name THEN g := Files.New(S.s); Files.Set(Rg, g, 0); i := 0;
      ExtName(i, S.s, name); f := Files.Old(name);
      WHILE f # NIL DO Files.Set(Rf, f, 0); Files.Read(Rf, ch);
        WHILE ~Rf.eof DO Files.Write(Rg, ch); Files.Read(Rf, ch) END;
        INC(i); ExtName(i, S.s, name); f := Files.Old(name)
      END;
      Files.Register(g)
    END
  END JoinFiles;

(** Usage: Miscellaneous.ShowMod <modname>
	Show the source code for module <modname>. *)
PROCEDURE ShowMod*;
	VAR
		S: Texts.Scanner;
		T: Texts.Text;
		file, name, prefixes, prefix: FileName;
		i, j: SIGNED32;
	PROCEDURE Try;
	BEGIN
		COPY(prefix, file); Strings.Append(file, name);
		NEW(T); Texts.Open(T, file);
		IF T.len = 0 THEN
			T := NIL
		END
	END Try;
BEGIN
	OpenScanner(S);
	IF S.class IN {Texts.Name, Texts.String} THEN
		i := 0;
		WHILE (S.s[i] # 0X) & (S.s[i] # ".") DO
			INC(i)
		END;
		S.s[i] := 0X; Strings.Append(S.s, ".Mod");
		COPY(S.s, name);
		Oberon.OpenScanner(S, "System.FilePrefixes");
		IF S.class IN {Texts.Name, Texts.String} THEN
			COPY(S.s, prefixes)
		ELSE
			prefixes := ""
		END;
		i := 0; j := 0; T := NIL;
		WHILE (T = NIL) & (prefixes[i] # 0X) DO
			IF prefixes[i] = ";" THEN
				prefix[j] := "."; prefix[j+1] := 0X; j := 0;
				Try()
			ELSE
				prefix[j] := prefixes[i]; INC(j)
			END;
			INC(i)
		END;
		IF T = NIL THEN
			prefix[j] := "."; prefix[j+1] := 0X; Try();
			IF T = NIL THEN
				prefix := ""; Try()
			END
		END;
		IF T # NIL THEN
			Oberon.OpenText(file, T, 512, 512)
		ELSE
			Texts.WriteString(W, name); Texts.WriteString(W, " not found");
			Texts.WriteLn(W); Texts.Append(Oberon.Log, W.buf)
		END
	END
END ShowMod;

PROCEDURE EqualFiles(f1, f2: Files.File): BOOLEAN;
CONST BufSize = 16384;
VAR r1, r2: Files.Rider; i, len: SIGNED32; buf1, buf2: ARRAY BufSize OF CHAR;
BEGIN
	IF Files.Length(f1) = Files.Length(f2) THEN
		Files.Set(r1, f1, 0); Files.Set(r2, f2, 0);
		LOOP
			Files.ReadBytes(r1, buf1, BufSize);
			Files.ReadBytes(r2, buf2, BufSize);
			len := BufSize-r1.res;
			i := 0; WHILE (i # len) & (buf1[i] = buf2[i]) DO INC(i) END;
			IF (i # len) OR (r1.res # r2.res) THEN RETURN FALSE END;
			IF len = 0 THEN RETURN TRUE END
		END
	ELSE
		RETURN FALSE
	END
END EqualFiles;

(** Compare files byte-by-byte. *)

PROCEDURE CompareFiles*;	(** { file1 => file2 } ~ *)
VAR f1, f2: Files.File; s: Texts.Scanner;
BEGIN
	OpenScanner(s);
	WHILE s.class IN {Texts.Name, Texts.String} DO
		Texts.WriteString(W, s.s);
		f1 := Files.Old(s.s);
		Texts.Scan(s);
		IF f1 # NIL THEN
			IF s.class IN {Texts.Name, Texts.String} THEN
				Texts.Write(W, " "); Texts.WriteString(W, s.s);
				f2 := Files.Old(s.s);
				Texts.Scan(s);
				IF f2 # NIL THEN
					IF EqualFiles(f1, f2) THEN Texts.WriteString(W, " ok")
					ELSE Texts.WriteString(W, " mismatch")
					END
				ELSE
					Texts.WriteString(W, " not found")
				END
			ELSE
				Texts.WriteString(W, " parameter expected"); s.class := Texts.Inval
			END
		ELSE
			Texts.WriteString(W, " not found"); Texts.Scan(s)
		END;
		Texts.WriteLn(W); Texts.Append(Oberon.Log, W.buf)
	END
END CompareFiles;

BEGIN
	Texts.OpenWriter(W)
END Miscellaneous.

