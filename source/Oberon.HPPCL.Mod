(* ETH Oberon, Copyright 2001 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

MODULE HPPCL IN Oberon;  (*bh, ard 27.11.92  /  kr 23.12. 92 / 03.08.93 - js 4.8.0 *)

	IMPORT SYSTEM, Modules, Files, Objects, Oberon, Fonts, Texts, Printer, Display, Pictures, In;

(* uses about 1M for bitmaps in 4 plane mode *)

	CONST
		InstallCmd = "HPPCL.Install";

		(* Planes = 1; HP 500 *)
		(* Planes = 3; HP 500C *)
		(* Planes = 4; HP 550C *)

		ReleaseMem = FALSE;
		C3 = TRUE; (* use only 3 colors for blocks *)

		HPPageWidth = 2480;  HPPageHeight = 3508;

		maxfonts = 24;
		PW = 2336; PH = 3281; PL = PW DIV 32;
		ESC = 1BX; CH = PH DIV 4;
		N = 40;

	ColSubDiv = 6;

	TYPE
		HPPrinter = POINTER TO HPPrinterDesc;
		HPPrinterDesc = RECORD (Printer.PrinterDesc)
			file, spoolFile: Files.File;
			pictList: PictList;
			color: BOOLEAN;
		END;
		Bitmap = POINTER TO ARRAY CH, PL OF SET;
		Pattern = ARRAY 16 OF SET;
		Font = Fonts.Font;
		PictList = POINTER TO RECORD
			pict: Pictures.Picture;
			next: PictList;
		END;

		RealVector = ARRAY N OF REAL;
		Poly = RECORD a, b, c, d, t: REAL END ;
		PolyVector = ARRAY N OF Poly;

	(* used for printing pictures *)
	RunP = POINTER TO RunDscP;
	RunDscP = RECORD
		next, prev: RunP;
		x, y, w, h, col: INTEGER
	END;
	SpoolList = POINTER TO SpoolListDesc;
	SpoolListDesc = RECORD
		next: SpoolList;
		P: HPPrinter;
		file, spoolFile: Files.File;
		pictList: PictList;
		readR, spoolr: Files.Rider;
		actPos, actPict, lastActPict: LONGINT;
		color: BOOLEAN;
	END;

	VAR
		Width*, Height*, Depth*, planes, Planes: INTEGER;
		FrameX*, FrameY*, FrameW*, FrameH*: INTEGER;
		Unit*: LONGINT;
		nofonts, nopage: INTEGER;
		font: ARRAY maxfonts OF ARRAY 32 OF CHAR;
		printerfile: Files.Rider;
		cY, cT  : INTEGER;
		sX, sY: INTEGER; (* actual string coordinates *)
		rev: ARRAY 256 OF CHAR; (* bit reverse table *)
		Cmap, Ymap, Mmap, Kmap : Bitmap; (* color planes *)
		empty: INTEGER;
		pattern: ARRAY 10 OF Pattern;
		intens : ARRAY 17 OF Pattern;
		yellow, magenta, cyan, black : INTEGER;
		Default  : Font;
		spool: SpoolList;
		task : Oberon.Task;
		W: Texts.Writer;
		freeP: RunP;

	(* V2/V3 ======================================= *)

	PROCEDURE DisplayGetChar (F: Font; ch: CHAR; VAR dx, x, y, w, h: INTEGER; VAR pat: Display.Pattern);
		VAR obj: Objects.Object; c: Fonts.Char;
	BEGIN
		F.GetObj(F, ORD(ch), obj);
		IF obj = NIL THEN Default.GetObj(Default,ORD(ch), obj) END;
		c := obj(Fonts.Char);
		dx := c.dx; x := c.x; y := c.y; w := c.w; h := c.h; pat := c.pat;
		IF h < 0 THEN h := 256 + h END;
	END DisplayGetChar;

	(* ======================================= *)
	PROCEDURE PrinterSend(x: CHAR);
	BEGIN
		Files.Write(spool.spoolr, x);
	END PrinterSend;

	(* ======================================= *)

	PROCEDURE XShift(x : INTEGER) : INTEGER;
	BEGIN RETURN x - FrameX
	END XShift;

	PROCEDURE YShift(y : INTEGER) : INTEGER;
	BEGIN RETURN y - FrameY
	END YShift;

	PROCEDURE Write(x: SYSTEM.BYTE);
	BEGIN Files.Write(printerfile,x) END Write;

	PROCEDURE WriteInt(k: INTEGER);
	BEGIN Write(SHORT(k MOD 100H)); Write(SHORT(k DIV 100H)) END WriteInt;

	PROCEDURE WriteBytes(VAR x: ARRAY OF SYSTEM.BYTE; n: INTEGER);
		VAR i: INTEGER;
	BEGIN
		i := 0;
		WHILE i < n DO Write(x[i]); INC(i) END;
	END WriteBytes;

	PROCEDURE WriteString(VAR s: ARRAY OF CHAR);
		VAR i: INTEGER;
	BEGIN i := 0;
		WHILE s[i] > 0X DO Write(s[i]); INC(i) END ;
		Write(0)
	END WriteString;

	PROCEDURE GetDim(label: ARRAY OF CHAR;  def: INTEGER;  VAR val: INTEGER);
	VAR v: REAL; S: Texts.Scanner;
	BEGIN
		Oberon.OpenScanner(S, label);
		IF (S.class = Texts.Int) OR (S.class = Texts.Real) THEN
			IF S.class = Texts.Int THEN v := S.i
			ELSE v := S.x
			END;
			Texts.Scan(S);
			IF S.class = Texts.Name THEN
				IF S.s = "cm" THEN v := v*360000.0
				ELSIF S.s = "mm" THEN v := v*36000.0
				ELSIF S.s = "in" THEN v := v*36000.0*25.4
				ELSE v := v*36000.0
				END
			ELSE v := v*36000.0
			END;
			val := SHORT(ENTIER(v/Unit + 0.5))
		ELSE val := def
		END
	END GetDim;

	PROCEDURE SetMetrics(P: Printer.Printer);
	VAR S: Texts.Scanner;
	BEGIN
		Unit := 3048;  P.Unit := Unit;
		Depth := 10(*?*);  P.Depth := Depth;
		IF planes # 0 THEN Planes := planes
		ELSE Oberon.OpenScanner(S, "HPPCL.Planes");
			IF (S.class = Texts.Int) & (S.i IN {1, 3, 4}) THEN Planes := SHORT(S.i)
			ELSE Planes := 1
			END;
		END;
		GetDim("HPPCL.Width", 2480, Width);
		IF Width > HPPageWidth THEN Width := HPPageWidth END;
		GetDim("HPPCL.Height", 3508, Height);
		IF Height > HPPageHeight THEN Height := HPPageHeight END;
		P.Width := Width;  P.Height := Height;

		GetDim("HPPCL.LeftMargin", 236, P.FrameX);
		GetDim("HPPCL.RightMargin", 236, FrameW);
		P.FrameW := FrameW;
		P.FrameW := Width-P.FrameX-P.FrameW;
		GetDim("HPPCL.BottomMargin", 177, P.FrameY);
		GetDim("HPPCL.TopMargin", 177, FrameH);
		P.FrameH := Height-P.FrameY-FrameH;
	END SetMetrics;

	PROCEDURE InitMetrics*(P: Printer.Printer);
	VAR M: Display.ControlMsg;  N: Oberon.ControlMsg;
	BEGIN
		SetMetrics(P);
		IF Printer.current # NIL THEN
			N.id := Oberon.neutralize;  M.F := NIL; Display.Broadcast(N);
			M.id := Display.newprinter;  M.F := NIL; Display.Broadcast(M);
			M.id := Display.suspend;  M.F := NIL; Display.Broadcast(M);
			M.id := Display.restore;  M.F := NIL; Display.Broadcast(M)
		END
	END InitMetrics;

	PROCEDURE Open*(P: Printer.Printer;  printer, options: ARRAY OF CHAR);
		VAR i: INTEGER;
	BEGIN
		WITH P: HPPrinter DO
			P.pictList := NIL;
			nofonts := 0; nopage := 0; P.color := FALSE;
			P.file := Files.New(""); Files.Set(printerfile, P.file, 0);
			P.spoolFile := Files.New(printer);
			i := 1; Files.Write(printerfile,0FCX); Files.Write(printerfile,03X); Files.WriteBytes(printerfile,i,2);
			FrameX := 94; FrameY := 59;
			P.res := 0
		END;
	END Open;

	PROCEDURE ReplConst*(P: Printer.Printer; x, y, w, h: INTEGER);
	BEGIN Write(2); Write(0);
		WriteInt(x); WriteInt(y); WriteInt(w); WriteInt(h)
	END ReplConst;

	PROCEDURE fontno(name: ARRAY OF CHAR): SHORTINT;
		VAR i, j: INTEGER;
	BEGIN i := 0;
		WHILE (i < nofonts) & (font[i] # name) DO INC(i) END ;
		IF i = nofonts THEN
			IF nofonts < maxfonts THEN
				COPY(name,font[i]);  INC(nofonts);
				Write(3); Write(SHORT(i)); j := 0;
				WHILE name[j] >= "0" DO Write(name[j]); INC(j) END ;
				Write(0)
			ELSE i := 0
			END
		END ;
		RETURN SHORT(i)
	END fontno;

	PROCEDURE UseListFont*(P: Printer.Printer; name: ARRAY OF CHAR);
		VAR i: INTEGER;
			listfont: ARRAY 10 OF CHAR;
	BEGIN listfont := "Gacha10l"; i := 0;
		WHILE (i < nofonts) & (font[i] # name) DO INC(i) END ;
		IF i = nofonts THEN
			COPY(name,font[i]); INC(nofonts);
			Write(3); Write(SHORT(i)); WriteBytes(listfont, 9)
		END ;
	END UseListFont;

	PROCEDURE GetMetric* (P: Printer.Printer;  fnt: Fonts.Font): Fonts.Font;
	VAR name: ARRAY 32 OF CHAR; i: INTEGER; metric: Fonts.Font;
	BEGIN
		COPY(fnt.name, name);
		i := 0; WHILE (name[i] # ".") & (name[i] # 0X) DO INC(i) END;
		(* look for Mdx *)
		name[i] := "."; name[i+1] := "M"; name[i+2] := "d"; name[i+3] := "3";
		name[i+4] := "."; name[i+5] := "F"; name[i+6] := "n"; name[i+7] := "t";
		name[i+8] := 0X;
		metric := Fonts.This(name);
		IF metric.type = Fonts.substitute THEN metric := NIL END;
		RETURN metric
	END GetMetric;

	PROCEDURE String*(P: Printer.Printer; x, y: INTEGER; s: ARRAY OF CHAR; fnt: Fonts.Font);
		VAR fno: SHORTINT;
	BEGIN fno := fontno(fnt.name); Write(1); Write(fno); WriteInt(x); WriteInt(y); WriteString(s)
	END String;

	PROCEDURE ContString*(P: Printer.Printer; s: ARRAY OF CHAR; fnt: Fonts.Font);
		VAR fno: SHORTINT;
	BEGIN fno := fontno(fnt.name); Write(0); Write(fno); WriteString(s)
	END ContString;

	PROCEDURE ReplPattern*(P: Printer.Printer; x, y, w, h, col: INTEGER);
	BEGIN Write(5); Write(SHORT(col)); WriteInt(x); WriteInt(y); WriteInt(w); WriteInt(h)
	END ReplPattern;

	PROCEDURE Line*(P: Printer.Printer; x0, y0, x1, y1: INTEGER);
	BEGIN Write(6); Write(0); WriteInt(x0); WriteInt(y0); WriteInt(x1); WriteInt(y1)
	END Line;

	PROCEDURE Circle*(P: Printer.Printer; x0, y0, r: INTEGER);
	BEGIN Write(9); Write(0); WriteInt(x0); WriteInt(y0); WriteInt(r)
	END Circle;

	PROCEDURE Ellipse*(P: Printer.Printer; x0, y0, a, b: INTEGER);
	BEGIN Write(7); Write(0); WriteInt(x0); WriteInt(y0); WriteInt(a); WriteInt(b)
	END Ellipse;

	PROCEDURE Spline*(P: Printer.Printer; x0, y0, n, open: INTEGER; VAR X, Y: ARRAY OF INTEGER);
		VAR i: INTEGER;
	BEGIN Write(10); Write(SHORT(open)); WriteInt(x0); WriteInt(y0); WriteInt(n); i := 0;
		WHILE i < n DO WriteInt(X[i]); WriteInt(Y[i]); INC(i) END
	END Spline;

	PROCEDURE Picture*(print: Printer.Printer; P: Pictures.Picture; px, py, pw, ph, x, y, w, h, mode: INTEGER);
	VAR pl, plh, prev: PictList;
	BEGIN
		IF Planes # 1 THEN print(HPPrinter).color := TRUE END;
		Write(8);
		WriteInt(px); WriteInt(py); WriteInt(pw); WriteInt(ph);
		WriteInt(x); WriteInt(y); WriteInt(w); WriteInt(h);
		Write(SHORT(mode));
		plh := print(HPPrinter).pictList; prev := NIL;
		WHILE plh # NIL DO prev := plh; plh := plh.next END;
		NEW(pl); pl.pict := P; pl.next := NIL;
		IF prev = NIL THEN print(HPPrinter).pictList := pl ELSE prev.next := pl END;
	END Picture;

	PROCEDURE Page*(P: Printer.Printer; nofcopies: INTEGER);
	BEGIN Write(4); Write(SHORT(nofcopies)); INC(nopage);
	END Page;


	(*== HP Printer =================================================================== *)
	PROCEDURE SendNum(n: INTEGER);
	BEGIN
		IF n > 9 THEN SendNum(n DIV 10) END;
		PrinterSend(CHR(n MOD 10 + ORD("0")))
	END SendNum;

	PROCEDURE OpenPrinter(P: HPPrinter);
	BEGIN
		PrinterSend(ESC); PrinterSend("E"); (* reset printerfile *)
		PrinterSend(ESC); PrinterSend("&"); PrinterSend("l"); PrinterSend("0"); PrinterSend("L"); (* perforation off *)
		PrinterSend(ESC); PrinterSend("*"); PrinterSend("t"); SendNum(300); PrinterSend("R"); (* resolution *)
		IF P.color THEN
			PrinterSend(ESC); PrinterSend("*"); PrinterSend("r"); PrinterSend("-"); PrinterSend(CHR(ORD("0") + Planes));
			PrinterSend("U"); (* CYMK planes *)
		ELSE
			PrinterSend(ESC); PrinterSend("*"); PrinterSend("r");  PrinterSend("1"); PrinterSend("U"); (* K plane *)
		END;
	END OpenPrinter;

	PROCEDURE OpenPage;
	BEGIN
		PrinterSend(ESC); PrinterSend("&"); PrinterSend("a"); SendNum(150); PrinterSend("H"); (* hor cursor pos *)
		PrinterSend(ESC); PrinterSend("*"); PrinterSend("r"); PrinterSend("1"); PrinterSend("A"); (* start raster *)
		PrinterSend(ESC); PrinterSend("*"); PrinterSend("b"); PrinterSend("2"); PrinterSend("M"); (* TIFF format *)
		empty := 0
	END OpenPage;

	PROCEDURE Last(VAR line: ARRAY OF CHAR) : INTEGER;
		VAR last: INTEGER;
	BEGIN
		last := PL*4 - 1;
		WHILE (last >= 0) & (line[last] = 0X) DO DEC(last) END;
		RETURN last;
	END Last;

	PROCEDURE Compress(VAR line: ARRAY OF CHAR; com: CHAR; last : INTEGER; VAR max: INTEGER);
		VAR i, j, k, n: INTEGER; ch: CHAR; comp: ARRAY 512 OF CHAR;
	BEGIN
		IF last > max THEN max := last END;
		IF last >= 0 THEN
			i := 0; k := 0;
			WHILE i <= last DO
				ch := line[i]; j := i; INC(i); n := 0;
				IF (i <= last) & (ch = line[i]) THEN
					INC(i); INC(n);
					WHILE (i <= last) & (n < 127) & (line[i] = ch) DO INC(i); INC(n) END;
					comp[k] := CHR(-n); INC(k);
					comp[k] := rev[ORD(ch)]; INC(k)
				ELSE
					WHILE (i <= last) & (n < 127) &
						((i + 2 > last) OR (line[i] # line[i+1]) OR (line[i] # line[i+2])) DO INC(i); INC(n) END;
					comp[k] := CHR(n); INC(k);
					WHILE j < i DO comp[k] := rev[ORD(line[j])]; INC(k); INC(j) END
				END
			END;
			PrinterSend(ESC); PrinterSend("*"); PrinterSend("b");
			IF empty > 0 THEN SendNum(empty); PrinterSend("y") END;
			SendNum(k); PrinterSend(com); i := 0;
			WHILE i < k DO PrinterSend(comp[i]); INC(i) END;
			empty := 0;
		END;
	END Compress;

	PROCEDURE SendEmpty(com : CHAR);
	BEGIN
		PrinterSend(ESC); PrinterSend("*"); PrinterSend("b");
		IF empty > 0 THEN SendNum(empty); PrinterSend("y") END;
		SendNum(0); PrinterSend(com);
		empty := 0;
	END SendEmpty;

	PROCEDURE PrintLine(VAR c, y, m, k: ARRAY OF CHAR);
		VAR max, lc, lm, ly, lk: INTEGER;
	BEGIN
		max := -1;
		lk := Last(k);
		IF spool.color THEN
			lc := Last(c); lm := Last(m); ly := Last(y);
			IF (lc >= 0) OR (lm >= 0) OR (ly >= 0) OR ((Planes = 4) & (lk >= 0)) THEN
				IF Planes =4  THEN
					IF lk >= 0 THEN Compress(k, "V", lk,max) ELSE SendEmpty("V") END;
				END;
				IF lc >= 0 THEN Compress(c, "V", lc,max) ELSE SendEmpty("V") END;
				IF lm >= 0 THEN Compress(m, "V", lm,max) ELSE SendEmpty("V") END;
				IF ly >= 0 THEN Compress(y, "W", ly,max) ELSE SendEmpty("W") END;
			END
		ELSE
			IF lk >= 0 THEN  Compress(k, "W", lk,max) END;
		END;
		IF max < 0 THEN INC(empty) END
	END PrintLine;

	PROCEDURE ClosePage;
	BEGIN
		PrinterSend(ESC); PrinterSend("*"); PrinterSend("r"); PrinterSend("b"); PrinterSend("C"); (* end raster *)
		PrinterSend(ESC); PrinterSend("&"); PrinterSend("l"); PrinterSend("0"); PrinterSend("H"); (* print page *)
	END ClosePage;

	PROCEDURE ClosePrinter;
	BEGIN
(*		Files.Register(file);*)
		PrinterSend(ESC); PrinterSend("E"); (* reset printer *)
	END ClosePrinter;

	(* ---------- Raster Operations ---------- *)

	PROCEDURE Block(x,  y, w, h : LONGINT);
		VAR lx, rx, t, b  : LONGINT; lm, rm, s, p, help, m: SET;
	BEGIN
		IF x < 0 THEN w := w + x; x := 0 END; IF x + w > PW THEN w := PW - x END;
		t := y + h; IF y < cY THEN y := cY  END; IF t >= cT THEN t := cT  END; h := t - y;
		IF (w > 0) & (h > 0)  THEN
			lx := x DIV 32; lm := {x MOD 32 .. 31};
			rx := (x + w - 1) DIV 32; rm := {0 .. (x + w - 1) MOD 32};
			y := (CH-1) - (y- cY);
			IF C3 & spool.color THEN b := black ELSE b := 0 END;
			WHILE h > 0 DO
				(* yellow *)
				IF Ymap # NIL THEN
					p := intens[yellow+b,y MOD 16];
					s := lm * p; x := lx;  m := lm;
					WHILE x < rx DO Ymap[y, x] := Ymap[y, x] - m + s; s := p; m := {0..31}; INC(x) END;
					m := m * rm; help := rm * s; Ymap[y, rx] := Ymap[y, rx] - m + help;
				END;
				(* magenta *)
				IF Mmap # NIL THEN
					p := intens[magenta+b,y MOD 16];
					s := lm * p; x := lx; m := lm;
					WHILE x < rx DO Mmap[y, x] := Mmap[y, x]  - m + s; s := p; m := {0..31};  INC(x) END;
					m := m * rm; help := rm * s; Mmap[y, rx] := Mmap[y, rx] - m  + help;
				END;
				(* cyan *)
				IF Cmap # NIL THEN
					p := intens[cyan+b,y MOD 16];
					s := lm * p; x := lx; m := lm;
					WHILE x < rx DO Cmap[y, x] := Cmap[y, x]  - m + s; s := p; m := {0..31}; INC(x) END;
					m := m * rm; help := rm * s; Cmap[y, rx] := Cmap[y, rx] - m + help;
				END;
				(* black *)
				p := intens[black-b,y MOD 16];
				s := lm * p; x := lx; m := lm;
				WHILE x < rx DO Kmap[y, x] := Kmap[y, x] - m + s; s := p; m := {0..31}; INC(x) END;
				m := m * rm; help := rm * s; Kmap[y, rx] := Kmap[y, rx] - m + help;
				DEC(y); DEC(h)
			END
		END
	END Block;

	PROCEDURE PatternBlock(x,  y, w, h : LONGINT; pat : INTEGER);
		VAR lx, rx, t, b   : LONGINT; lm, rm, s, p, help, m : SET;
	BEGIN
		IF x < 0 THEN w := w + x; x := 0 END; IF x + w > PW THEN w := PW - x END;
		t := y + h; IF y < cY THEN y := cY  END; IF t >= cT THEN t := cT  END; h := t - y;
		IF (w > 0) & (h > 0)  THEN
			lx := x DIV 32; lm := {x MOD 32 .. 31};
			rx := (x + w - 1) DIV 32; rm := {0 .. (x + w - 1) MOD 32};
			y := (CH-1) - (y- cY);
			IF C3 & spool.color THEN b := black ELSE b := 0 END;
			WHILE h > 0 DO
				(* yellow *)
				IF Ymap # NIL THEN
					p := intens[yellow+b,y MOD 16] * pattern[pat, y MOD 16];
					s := lm * p; x := lx; m := lm;
					WHILE x < rx DO Ymap[y, x] := Ymap[y, x] - m + s; s := p; m := {0..31}; INC(x) END;
					m := m * rm; help := rm * s; Ymap[y, rx] := Ymap[y, rx] - m + help;
				END;
				(* magenta *)
				IF Mmap # NIL THEN
					p := intens[magenta+b,y MOD 16]* pattern[pat, y MOD 16];
					s := lm * p; x := lx; m := lm;
					WHILE x < rx DO Mmap[y, x] := Mmap[y, x] - m+ s; s := p; m := {0..31}; INC(x) END;
					m := m * rm; help := rm * s; Mmap[y, rx] := Mmap[y, rx]  - m + help;
				END;
				(* cyan *)
				IF Cmap # NIL THEN
					p := intens[cyan+b,y MOD 16] * pattern[pat, y MOD 16];
					s := lm * p; x := lx; m := lm;
					WHILE x < rx DO Cmap[y, x] := Cmap[y, x] - m+ s; s := p; m := {0..31}; INC(x) END;
					m := m * rm; help := rm * s; Cmap[y, rx] := Cmap[y, rx] - m + help;
				END;
				(* black *)
				p := intens[black-b,y MOD 16] * pattern[pat, y MOD 16];
				s := lm * p; x := lx; m := lm;
				WHILE x < rx DO Kmap[y, x] := Kmap[y, x] - m + s; s := p; m := {0..31};  INC(x) END;
				m := m * rm; help := rm * s; Kmap[y, rx] := Kmap[y, rx] - m + help;

				DEC(y); DEC(h)
			END
		END
	END PatternBlock;

	PROCEDURE Character(p: Display.Pattern; x, y, w, h: INTEGER);
		VAR n, c, x0,b: INTEGER; s, t, m, help, h2: SET;
	BEGIN
		IF (x >= 0) & (x + w <= PW) THEN
			c := x MOD 32; x0 := x DIV 32; m := {c .. 31};
			INC(p, 2); y := (CH - 1) - (y - cY);
			IF FALSE & (C3 & spool.color) THEN b := black ELSE b := 0 END;
			WHILE h > 0 DO
				n := w; t := {}; x := x0;
				WHILE n > 0 DO
					SYSTEM.GET(p, s);
					IF n < 32 THEN s := s * {0 .. n-1} END; (* correction for byte patterns *)
					s := ROT(s, c); help := (s * m + t);
					IF (y >=0) & (y < CH) THEN
						(* yellow *)
						IF Ymap # NIL THEN
							h2 := intens[yellow+b,y MOD 16];
							Ymap[y , x] := Ymap[y , x] -help + help * h2;
						END;
						(* magenta *)
						IF Mmap # NIL THEN
							h2 := intens[magenta+b,y MOD 16];
							Mmap[y , x] := Mmap[y , x] -help +help * h2;
						END;
						(* cyan *)
						IF Cmap # NIL THEN
							h2 := intens[cyan+b,y MOD 16];
							Cmap[y , x] := Cmap[y , x] -help + help * h2;
						END;
						(* black *)
						h2 := intens[black-b,y MOD 16];
						Kmap[y , x] := Kmap[y , x] -help + help * h2;
					END;
					t := s - m;
					DEC(n, 32); INC(p, 4); INC(x)
				END;
				IF c + n > 0 THEN
					IF (y >=0) & (y < CH) THEN
						IF Ymap # NIL THEN
							h2 := intens[yellow+b,y MOD 16];
							Ymap[y , x] := Ymap[y , x] -t + t * h2;
						END;
						IF Mmap # NIL THEN
							h2 := intens[magenta+b,y MOD 16];
							Mmap[y , x] := Mmap[y , x] -t + t * h2;
						END;
						IF Cmap # NIL THEN
							h2 := intens[cyan+b,y MOD 16];
							Cmap[y , x] := Cmap[y , x] -t + t * h2;
						END;
						h2 := intens[black-b,y MOD 16];
						Kmap[y , x] := Kmap[y , x] -t + t * h2;
					END;
				END;
				DEC(p, LONG(-n) DIV 8); (* correction for byte patterns *)
				DEC(y); DEC(h)
			END
		END
	END Character;

	PROCEDURE Dot(x, y: LONGINT);
		VAR p : SET; b : LONGINT;
	BEGIN
		IF (x >= 0) & (x < PW) & (y >= cY) & (y < cT) THEN
			y := (CH-1) - (y - cY);
			IF C3 & spool.color THEN b := black ELSE b := 0 END;
			IF Ymap # NIL THEN
				p := intens[yellow+b,y  MOD 16];
				IF x MOD 32 IN p THEN INCL(Ymap[y, x DIV 32], x MOD 32) ELSE EXCL(Ymap[y, x DIV 32], x MOD 32) END;
			END;
			IF Mmap # NIL THEN
				p := intens[magenta+b,y MOD 16];
				IF x MOD 32 IN p THEN INCL(Mmap[y, x DIV 32], x MOD 32) ELSE EXCL(Mmap[y, x DIV 32], x MOD 32) END;
			END;
			IF Cmap # NIL THEN
				p := intens[cyan+b,y  MOD 16];
				IF x MOD 32 IN p THEN INCL(Cmap[y, x DIV 32], x MOD 32) ELSE EXCL(Cmap[y, x DIV 32], x MOD 32)END;
			END;
			p := intens[black-b,y  MOD 16];
			IF x MOD 32 IN p THEN INCL(Kmap[y, x DIV 32], x MOD 32) ELSE EXCL(Kmap[y, x DIV 32], x MOD 32) END
		END
	END Dot;

	PROCEDURE GetLine(y: INTEGER; map: Bitmap; VAR line: ARRAY OF CHAR);
		VAR i, j: INTEGER; x: LONGINT;
	BEGIN
		IF map # NIL THEN
			i := 0; j := 0;
			WHILE j < PL DO
				x := LONGINT(map[y, j]);
				line[i] := CHR(x); x := x DIV 256; INC(i);
				line[i] := CHR(x); x := x DIV 256; INC(i);
				line[i] := CHR(x); x := x DIV 256; INC(i);
				line[i] := CHR(x); INC(i);
				INC(j)
			END
		END
	END GetLine;

	PROCEDURE Clear(map: Bitmap);
		VAR i, j: INTEGER;
	BEGIN
		IF map # NIL THEN
			i := 0;
			WHILE i < CH DO
				j := 0;
				WHILE j < PL DO map[i, j] := {}; INC(j) END;
				INC(i)
			END
		END;
	END Clear;

	(* ---------- Printer Procedures---------- *)

	PROCEDURE PrinterOpen;
	BEGIN
		OpenPrinter(spool.P);
		IF spool.color THEN
			IF Cmap = NIL THEN NEW(Cmap) END;
			IF Ymap = NIL THEN NEW(Ymap) END;
			IF Mmap = NIL THEN NEW(Mmap) END;
			Clear(Cmap); Clear(Ymap); Clear(Mmap);
		END;
		IF Kmap = NIL THEN NEW(Kmap) END;
		Clear(Kmap);
	END PrinterOpen;

	PROCEDURE PrinterReplConst(x, y, w, h: INTEGER);
	BEGIN Block( x, y, w, h) END PrinterReplConst;

	PROCEDURE PrinterFont(name: ARRAY OF CHAR): Font;
		VAR i, j: INTEGER; app : ARRAY 32 OF CHAR; font: Fonts.Font;
	BEGIN
		app := ".Pr3.Fnt";
		i := 0;
		WHILE (name[i] # ".") &  (name[i] # 0X) DO INC(i) END;
		j := 0;
		name[i] := app[j]; WHILE app[j] # 0X DO INC(i); INC(j); name[i] := app[j] END;
		font := Fonts.This(name);
		IF font.type # Fonts.font THEN font := Default END;
		RETURN font
	END PrinterFont;

	PROCEDURE PrinterString(x, y: INTEGER; VAR s, fname: ARRAY OF CHAR);
		VAR f: Font; i, dx, w, h: INTEGER; p: Display.Pattern;
	BEGIN
		sX := x; sY := y;
		f := PrinterFont(fname); i := 0;
		WHILE s[i] # 0X DO
			DisplayGetChar(f, s[i], dx, x, y, w, h, p);
			Character(p,  sX+x, sY+y, w, h);
			INC(sX, dx); INC(i)
		END
	END PrinterString;

	PROCEDURE PrinterContString(VAR s, fname: ARRAY OF CHAR);
		VAR f: Font; i, dx, x, y, w, h: INTEGER; p: Display.Pattern;
	BEGIN
		f := PrinterFont(fname); i := 0;
		WHILE s[i] # 0X DO
			DisplayGetChar(f, s[i], dx, x, y, w, h, p);
			Character(p, sX+x, sY+y, w, h);
			INC(sX, dx); INC(i)
		END
	END PrinterContString;

	PROCEDURE PrinterReplPattern(x, y, w, h, pat: INTEGER);
	BEGIN PatternBlock(x, y, w, h, pat) END PrinterReplPattern;

	PROCEDURE PrinterLine(x0, y0, x1, y1: INTEGER);
		VAR x, y, dx, dy, d, inc: INTEGER;
	BEGIN
		IF y1 - y0 < x0 - x1 THEN x := x0; x0 := x1; x1 := x; y := y0; y0 := y1; y1 := y END;
		dx := 2 * (x1 - x0);
		dy := 2 * (y1 - y0);
		x := x0; y := y0; inc := 1;
		IF dy > dx THEN
			d := dy DIV 2;
			IF dx < 0 THEN inc := -1; dx := -dx END;
			WHILE y <= y1 DO
				Dot(x, y);
				INC(y); DEC(d, dx);
				IF d < 0 THEN INC(d, dy); INC(x, inc) END
			END
		ELSE
			d := dx DIV 2;
			IF dy < 0 THEN inc := -1; dy := -dy END;
			WHILE x <= x1 DO
				Dot( x, y);
				INC(x); DEC(d, dy);
				IF d < 0 THEN INC(d, dx); INC(y, inc) END
			END
		END
	END PrinterLine;

	PROCEDURE PrinterCircle(x0, y0, r: INTEGER);
		VAR x, y, q: INTEGER;
	BEGIN
		x := 0; y := r; q := r;
		WHILE x <= y DO
			Dot( x0 + x, y0 + y); Dot( x0 + y, y0 + x);
			Dot( x0 - x, y0 + y); Dot( x0 - y, y0 + x);
			Dot( x0 + x, y0 - y); Dot( x0 + y, y0 - x);
			Dot( x0 - x, y0 - y); Dot( x0 - y, y0 - x);
			INC(x); DEC(q, 2 * x - 1);
			IF q <= 0 THEN DEC(y); INC(q, 2 * y) END
		END
	END PrinterCircle;

	PROCEDURE PrinterEllipse(x0, y0, a, b: INTEGER);
		VAR a2, b2, ex, ey, q: LONGINT; x, y: INTEGER;
	BEGIN
		IF (a <= 800) & (b <= 800) THEN (* longint range guard *)
			a2 := LONG(a) * a; b2 := LONG(b) * b;
			ex := b2; ey := a2 * (b * 2 - 1); q := 0;
			a2 := a2 * 2; b2 := b2 * 2;
			x := 0; y := b;
			WHILE ey > ex DO
				Dot( x0 + x, y0 + y); Dot( x0 - x, y0 + y);
				Dot( x0 + x, y0 - y); Dot( x0 - x, y0 - y);
				INC(x); INC(q, 2 * ex); INC(ex, b2);
				IF q > ey THEN DEC(y); DEC(q, 2 * ey); DEC(ey, a2) END
			END;
			WHILE y >= 0 DO
				Dot( x0 + x, y0 + y); Dot( x0 - x, y0 + y);
				Dot( x0 + x, y0 - y); Dot( x0 - x, y0 - y);
				DEC(y); DEC(q, 2 * ey); DEC(ey, a2);
				IF q < -ex THEN INC(x); INC(q, 2 * ex); INC(ex, b2) END
			END
		END
	END PrinterEllipse;

	(*
	PROCEDURE Bezier(col, x0, y0, xd0, yd0, x1, y1, xd1, yd1: INTEGER);
		VAR t, dt, dx, dy, ax, bx, ay, by: REAL;
	BEGIN
		dx := x1 - x0; ax := xd0 + xd1 - 2.0*dx; bx := 3.0*dx - 2.0*xd0 - xd1;
		dy := y1 - y0; ay := yd0 + yd1 - 2.0*dy; by := 3.0*dy - 2.0*yd0 - yd1;
		dt := 1.0 / (ABS(dx) + ABS(dy)); t := 0;
		REPEAT
			Dot(col, SHORT(ENTIER(((ax * t + bx) * t + xd0) * t + x0 + 0.5)),
						SHORT(ENTIER(((ay * t + by) * t + yd0) * t + y0 + 0.5)));
			t := t + dt
		UNTIL t >= 1.0
	END Bezier;
	*)

	PROCEDURE PrintPoly(x0, y0: INTEGER; VAR p, q: Poly; lim: REAL);
		VAR t: REAL;
	BEGIN t := 0;
		REPEAT
			Dot(SHORT(ENTIER(((p.a * t + p.b) * t + p.c) * t + p.d) + x0),SHORT(ENTIER(((q.a * t + q.b) * t + q.c) * t + q.d) + y0));
			t := t + 1.0
		UNTIL t >= lim
	END PrintPoly;

	PROCEDURE SolveTriDiag(VAR a, b, c, y: RealVector; n: INTEGER);
		VAR i: INTEGER;  t: REAL;
	BEGIN (*a, b, c of tri-diag matrix T; solve Ty' = y for y', assign y' to y*)
		i := 1;
		WHILE i < n DO
			t := c[i-1]*y[i-1];  y[i] := y[i] - t;  INC(i)
		END ;
		i := n-1; y[i] := y[i]/a[i];
		WHILE i > 0 DO
			DEC(i);  t := b[i]*y[i+1];  y[i] := (y[i] - t)/a[i]
		END
	END SolveTriDiag;

	PROCEDURE OpenSpline(VAR x, y, d: RealVector; n: INTEGER);
		VAR i: INTEGER; d1, d2: REAL;
			a, b, c: RealVector;
	BEGIN (*from x, y compute d = y'*)
		b[0] := 1.0/(x[1] - x[0]); a[0] := 2.0*b[0]; c[0] := b[0];
		d1 := (y[1] - y[0])*3.0*b[0]*b[0]; d[0] := d1; i := 1;
		WHILE i < n-1 DO
			b[i] := 1.0/(x[i+1] - x[i]);
			a[i] := 2.0*(c[i-1] + b[i]);
			c[i] := b[i];
			d2 := (y[i+1] - y[i])*3.0*b[i]*b[i];
			d[i] := d1 + d2; d1 := d2; INC(i)
		END ;
		a[i] := 2.0*b[i-1]; d[i] := d1; i := 0;
		WHILE i < n-1 DO c[i] := c[i]/a[i]; a[i+1] := a[i+1] - c[i]*b[i]; INC(i) END ;
		SolveTriDiag(a, b, c, d, n)
	END OpenSpline;

	PROCEDURE ClosedSpline(VAR x, y, d: RealVector; n: INTEGER);
		VAR i: INTEGER; d1, d2, hn, dn: REAL;
			a, b, c, w: RealVector;
	BEGIN (*from x, y compute d = y'*)
		hn := 1.0/(x[n-1] - x[n-2]);
		dn := (y[n-1] - y[n-2])*3.0*hn*hn;
		b[0] := 1.0/(x[1] - x[0]);
		a[0] := 2.0*b[0] + hn;
		c[0] := b[0];
		d1 := (y[1] - y[0])*3.0*b[0]*b[0]; d[0] := dn + d1;
		w[0] := 1.0; i := 1;
		WHILE i < n-2 DO
			b[i] := 1.0/(x[i+1] - x[i]);
			a[i] := 2.0*(c[i-1] + b[i]);
			c[i] := b[i];
			d2 := (y[i+1] - y[i])*3.0*b[i]*b[i]; d[i] := d1 + d2; d1 := d2;
			w[i] := 0; INC(i)
		END ;
		a[i] := 2.0*b[i-1] + hn; d[i] := d1 + dn;
		w[i] := 1.0; i := 0;
		WHILE i < n-2 DO c[i] := c[i]/a[i]; a[i+1] := a[i+1] - c[i]*b[i]; INC(i) END ;
		SolveTriDiag(a, b, c, d, n-1); SolveTriDiag(a, b, c, w, n-1);
		d1 := (d[0] + d[i])/(w[0] + w[i] + x[i+1] - x[i]); i := 0;
		WHILE i < n-1 DO d[i] := d[i] - d1*w[i]; INC(i) END ;
		d[i] := d[0]
	END ClosedSpline;

	PROCEDURE PrinterSpline(x0, y0, n, open : INTEGER; u,v : ARRAY OF INTEGER);
		VAR i : INTEGER; dx, dy, ds: REAL;
			x, xd, y, yd, s: RealVector;
			p, q: PolyVector;
	BEGIN (*from u, v compute x, y, s*)
		x[0] := u[0]; y[0] := v[0]; s[0] := 0;  i := 1;
		WHILE i < n DO
			x[i] := u[i]; dx := x[i] - x[i-1];
			y[i] := v[i]; dy := y[i] - y[i-1];
			s[i] := ABS(dx) + ABS(dy) + s[i-1]; INC(i)
		END ;
		IF open = 1  THEN OpenSpline(s, x, xd, n); OpenSpline(s, y, yd, n)
		ELSE ClosedSpline(s, x, xd, n); ClosedSpline(s, y, yd, n)
		END ;
		(*compute coefficients from x, y, xd, yd, s*)  i := 0;
		WHILE i < n-1 DO
			ds := 1.0/(s[i+1] - s[i]);
			dx := (x[i+1] - x[i])*ds;
			p[i].a := ds*ds*(xd[i] + xd[i+1] - 2.0*dx);
			p[i].b := ds*(3.0*dx - 2.0*xd[i] -xd[i+1]);
			p[i].c := xd[i];
			p[i].d := x[i];
			p[i].t := s[i];
			dy := ds*(y[i+1] - y[i]);
			q[i].a := ds*ds*(yd[i] + yd[i+1] - 2.0*dy);
			q[i].b := ds*(3.0*dy - 2.0*yd[i] - yd[i+1]);
			q[i].c := yd[i];
			q[i].d := y[i];
			q[i].t := s[i]; INC(i)
		END ;
		p[i].t := s[i]; q[i].t := s[i];
		(*display polynomials*)
		i := 0;
		WHILE i < n-1 DO PrintPoly( x0, y0, p[i], q[i], p[i+1].t - p[i].t); INC(i) END
	END PrinterSpline;

(*
	PROCEDURE ClipAgainst(VAR x, y, w, h: INTEGER; x1, y1, w1, h1: INTEGER);
	VAR r, t, r1, t1: INTEGER;
	BEGIN
		r := x + w - 1; r1 := x1 + w1 - 1; t := y + h - 1; t1 := y1 + h1 - 1;
		IF x < x1 THEN x := x1 END;
		IF y < y1 THEN y := y1 END;
		IF r > r1 THEN r := r1 END;
		IF t > t1 THEN t := t1 END;
		w := r - x + 1; h := t - y + 1;
	END ClipAgainst;
*)

	PROCEDURE RGBToPatNr(red, green, blue: INTEGER; VAR pNr: INTEGER);
	(* pNr: 0..ColSubdiv-1  [white, light ...dark, black] *)
		CONST ColNrRange = 2550 DIV ColSubDiv;
	BEGIN
		pNr := 10 * 255 - 3 * red - 6 * green - blue;	(* 10 * 255 -> invert value *)
		pNr := pNr DIV ColNrRange;
		IF pNr >= ColSubDiv THEN pNr := ColSubDiv - 1 ELSIF pNr < 0 THEN pNr := 0 END
	END RGBToPatNr;

	(* DOS/Native-Oberon *)
	PROCEDURE PrinterPicture(P: Pictures.Picture; px, py, pw, ph, (* picture *) X, Y, W, H: INTEGER(* printer *));
		CONST Shift = 100000;	(* max device distance: MAX(LONGINT) DIV Shift *)
		VAR scaleX, scaleY: LONGINT;
			trailer, run: RunP;	x0, x, y, col: INTEGER;	colored: BOOLEAN;

		PROCEDURE Scale(pixel, scale: LONGINT): INTEGER;
		BEGIN
			RETURN SHORT(pixel * scale DIV Shift)
		END Scale;

		PROCEDURE PrintRun(VAR run: RunP);
			VAR red, green, blue, pNr: INTEGER;
		BEGIN
			run.w := Scale(run.x + run.w, scaleX); run.x := Scale(run.x, scaleX);	(* scale right and left *)
			run.h := Scale(run.y + run.h, scaleY); run.y := Scale(run.y, scaleY);	(* scale top and bottom *)
			DEC(run.w, run.x); DEC(run.h, run.y);		(* scaled width and height *)
			IF (run.w > 0) & (run.h > 0) THEN	(* run visible *)
				IF colored THEN
					Pictures.GetColor(P, run.col, red, green, blue);
					IF Printer.Depth > 1 THEN
						PrinterUseColor(64 + (red * 3) DIV 4, 64 + (green * 3) DIV 4, 64 + (blue * 3) DIV 4);
						(*PrinterUseColor((*128 +*) red, (*DIV 2, 128 + *)green,  (*DIV 2, 128 +*) blue  (*DIV 2*));*)
						PrinterReplConst(X + run.x, Y + run.y, run.w, run.h)
					ELSE
						RGBToPatNr(red, green, blue, pNr);
						IF pNr = ColSubDiv - 1 THEN PrinterReplConst(X + run.x, Y + run.y, run.w, run.h)
						ELSE PrinterReplPattern(X + run.x, Y + run.y, run.w, run.h, pNr)
						END
					END
				ELSE
					PrinterReplConst(X + run.x, Y + run.y, run.w, run.h)
				END
			END;
			run.prev.next := run.next; run.next.prev := run.prev;	(* remove from run list *)
			run.prev := freeP; freeP := run;				(* recycle printed run *)
			run := run.next; freeP.next := NIL		(* advance in run list *)
		END PrintRun;

		PROCEDURE InsertRun(run: RunP; x, y, w, col: INTEGER);
		(* inserts a new run before run *)
			VAR r: RunP;
		BEGIN	(* x + w <= run.x *)
			IF freeP # NIL THEN r := freeP; freeP := freeP.prev ELSE NEW(r) END;
			r.x := x; r.y := y; r.w := w; r.h := 1; r.col := col;
			r.next := run; r.prev := run.prev; run.prev.next := r; run.prev := r	(* add r to run list *)
		END InsertRun;

		PROCEDURE EnlargeRun(trailer: RunP; VAR run: RunP; x, y, w, col: INTEGER);
		BEGIN
			WHILE (run # trailer) & (run.x < x) DO PrintRun(run) END;	(* print runs before x *)
			IF run = trailer THEN InsertRun(run, x, y, w, col)
			ELSIF (run.x = x) & (run.w = w) & (run.col = col) THEN INC(run.h); run := run.next	(* enlarge run height *)
			ELSE	(* run.x >= x *)
				WHILE (run # trailer) & (run.x < x + w) DO PrintRun(run) END;
				InsertRun(run, x, y, w, col)
			END
		END EnlargeRun;

	BEGIN
		scaleX := W * Shift DIV (*P.width*) pw; scaleY := H * Shift DIV (*P.height*) ph;
		NEW(trailer); trailer.next := trailer; trailer.prev := trailer;
		y := py; colored := P.depth > 1;

		IF Depth = 1 THEN PrinterUseColor(0, 0, 0) END; (* set color at the beginning !*)

		WHILE y < py + ph DO
			x := px; run := trailer.next;
			WHILE x <  px + pw DO
				x0 := x; Pictures.GetRun(P, col, x, y);
				IF x > px + pw THEN x := px + pw END;
				IF colored OR (col # Display.BG) THEN
					EnlargeRun(trailer, run, x0 - px, y - py, x-x0, col)
				END
			END;
			WHILE run # trailer DO PrintRun(run) END;
			INC(y)
		END;

		run := trailer.next; WHILE run # trailer DO PrintRun(run) END;
		PrinterUseColor(0, 0, 0);
		Oberon.Collect
	END PrinterPicture;
	(**)

	PROCEDURE PrinterStripe(nofcopies: INTEGER);
		VAR i: INTEGER; c, y, m, k: ARRAY PL*4 OF CHAR;
	BEGIN
		WHILE nofcopies > 0 DO
			i := 0;
			WHILE i < CH DO
				IF spool.color THEN
					GetLine(i, Cmap, c); GetLine(i, Ymap, y); GetLine(i, Mmap, m);
				END;
				GetLine(i, Kmap, k);
				PrintLine(c, y, m, k); INC(i)
			END;
			DEC(nofcopies )
		END;
		IF spool.color THEN
			Clear(Cmap); Clear(Ymap); Clear(Mmap);
		END;
		Clear(Kmap);
	END PrinterStripe;

	PROCEDURE PrinterUseColor(r,g,b : INTEGER);
	BEGIN
	cyan  := (255 - r) * 17 DIV 256; magenta := (255 - g) * 17 DIV 256; yellow := (255  -  b) *  17 DIV 256;
		IF Planes # 1 THEN
			IF Planes = 4 THEN
				IF (cyan = magenta) & (magenta = yellow) THEN black := magenta; magenta := 0; cyan := 0; yellow := 0
				ELSE black := 0 END
			ELSE black := 0 END
		ELSE
			(*black := (cyan *3 + magenta * 6+ yellow ) DIV 10*)
			black := (cyan *2 + magenta * 2+ yellow ) DIV 5
		END
	END PrinterUseColor;

	PROCEDURE PrinterClose;
	BEGIN
		ClosePrinter;
		Printer.Spool(spool.spoolFile);
		Files.Set(spool.spoolr, NIL, 0);
		Files.Set(spool.readR, NIL, 0);
		IF ReleaseMem THEN Cmap := NIL; Ymap := NIL; Mmap := NIL; Kmap := NIL END;
		freeP := NIL; spool.pictList := NIL;
		Oberon.Collect
	END PrinterClose;

	PROCEDURE InitR;
		VAR i, j, a, b: INTEGER;
	BEGIN
		i := 0;
		WHILE i < 256 DO
			a := i; j := 0; b := 0;
			WHILE j < 8 DO b := 2 * b + a MOD 2; a := a DIV 2; INC(j) END;
			rev[i] := CHR(b); INC(i)
		END
	END InitR;

	PROCEDURE InitP(p, a, b, c: INTEGER);
		VAR i, j, k: INTEGER; s: SET;
	BEGIN
		i := 0; k := 0;
		WHILE i < 16 DO
			s := {}; j := k;
			WHILE j < 32 DO INCL(s, j); j := j + a END;
			pattern[p, i] := s; i := i + b; k := k + c;
			IF k >= a THEN k := k - a END;
		END
	END InitP;

	PROCEDURE InitIntens;
		VAR s : ARRAY 4 OF SET;

		PROCEDURE Init(i : INTEGER);
			VAR j,k : INTEGER;
		BEGIN
			intens[i,0] :=s[0]; intens[i,1] :=s[1]; intens[i,2] :=s[2]; intens[i,3] := s[3];
			j := 0;
			WHILE j < 4 DO
				intens[i,j] := intens[i,j] + ROT(intens[i,j],4) ;
				intens[i,j] := intens[i,j] + ROT(intens[i,j],8) ;
				intens[i,j] := intens[i,j] + ROT(intens[i,j],16);
				INC(j);
			END;
			j := 0;
			WHILE j < 12 DO k := 0;
				WHILE k < 4 DO intens[i,j + k + 4] := intens[i,j+k]; INC(k) END;
				INC(j,4)
			END;
			j := 0;
			WHILE j < 16 DO
				intens[16-i,j] := - intens[i,j];
				INC(j)
			END;
		END Init;

	BEGIN
		s[0] := {}; s[1] := {}; s[2] := {}; s[3] := {}; Init(0);
		s[0] := {1}; s[1] := {}; s[2] := {}; s[3] := {}; Init(1);
		s[0] := {1}; s[1] := {}; s[2] := {3}; s[3] := {}; Init(2);
		s[0] := {1}; s[1] := {3}; s[2] := {1}; s[3] := {}; Init(3);
		s[0] := {1}; s[1] := {3}; s[2] := {1}; s[3] := {3}; Init(4);
		s[0] := {1,3}; s[1] := {0}; s[2] := {1,3}; s[3] := {}; Init(5);
		s[0] := {1,3}; s[1] := {0}; s[2] := {1,3}; s[3] := {2}; Init(6);
		s[0] := {1,3}; s[1] := {0,2}; s[2] := {1,3}; s[3] := {2}; Init(7);
		s[0] := {1,3}; s[1] := {0,2}; s[2] := {1,3}; s[3] := {0,2}; Init(8);
	END InitIntens;

	(* ===================================================================== *)

	PROCEDURE Log(s1, s2 : ARRAY OF CHAR);
	BEGIN
		Texts.WriteString(W,s1); Texts.WriteString(W,"  "); Texts.WriteString(W,s2);
		Texts.WriteLn(W); Texts.Append(Oberon.Log,W.buf);
	END Log;

	PROCEDURE Shift(VAR x,y,w,h : INTEGER);
		VAR r, t : INTEGER;
	BEGIN
		r := x + w; t := y + h; x := XShift(x); y := YShift(y);
		w := XShift(r) - x; h :=  YShift(t) - y;
	END Shift;

	PROCEDURE Spool(me: Oberon.Task);
		VAR x, y, w, h, px, py, pw, ph, i, n, r, g, b, y0: INTEGER;  T, ip: LONGINT; pl: PictList;
		string : ARRAY 400 OF CHAR; ch : CHAR; col, open, fno, mode : SHORTINT; X, Y : ARRAY 200 OF INTEGER;

	PROCEDURE Clip(VAR  y, h : INTEGER) : BOOLEAN;
		VAR  t : INTEGER;
	BEGIN
		t := y + h;
		IF y < cY THEN y := cY ELSIF t > cT THEN t := cT END; h := t - y;
		RETURN h > 0;
	END Clip;

	BEGIN
		T := Oberon.Time();
		me.time := T;
		LOOP
			Files.Read(spool.readR, ch);
			IF spool.readR.eof THEN EXIT END;
			IF ch = 2X THEN (* replconst *)
				Files.Read(spool.readR,col); Files.ReadBytes(spool.readR,x,2); Files.ReadBytes(spool.readR,y,2);
				Files.ReadBytes(spool.readR, w, 2); Files.ReadBytes(spool.readR, h, 2);
				Shift(x,y,w,h);
				IF Clip(y,h) THEN PrinterReplConst(x,y,w,h) END
			ELSIF ch = 1X THEN (* String *)
				Files.Read(spool.readR,fno); Files.ReadBytes(spool.readR,x,2); Files.ReadBytes(spool.readR,y,2);
				x := XShift(x); y := YShift(y);
				i := 0; REPEAT Files.Read(spool.readR,string[i]); INC(i) UNTIL string[i-1] = 0X;
				h := 130; y0 := y -20; sX := x; sY := y;
				IF Clip(y0,h) THEN
					PrinterString(x, y, string, font[fno])
				END
			ELSIF ch = 3X THEN
				Files.Read(spool.readR,fno);
				i := 0; REPEAT Files.Read(spool.readR,font[fno][i]); INC(i) UNTIL font[fno][i-1] = 0X; DEC(i);
			ELSIF ch = 0X THEN (* ContString *)
				Files.Read(spool.readR,fno);
				i := 0; REPEAT Files.Read(spool.readR,string[i]); INC(i) UNTIL string[i-1] = 0X;
				h := 130; y0 := sY -20;
				IF Clip(y0,h) THEN
					PrinterContString(string, font[fno]);
				END
			ELSIF ch = 5X THEN (* ReplPattern *)
				Files.Read(spool.readR,col); Files.ReadBytes(spool.readR,x,2);
				Files.ReadBytes(spool.readR,y,2);Files.ReadBytes(spool.readR,w,2); Files.ReadBytes(spool.readR,h,2);
				Shift(x,y,w,h);
				PrinterReplPattern(x, y, w, h, col);
			ELSIF ch = 6X THEN (* line *)
				Files.Read(spool.readR,col); Files.ReadBytes(spool.readR,x,2);
				Files.ReadBytes(spool.readR,y,2);Files.ReadBytes(spool.readR,w,2); Files.ReadBytes(spool.readR,h,2);
				x := XShift(x); y := YShift(y); w := XShift(w); h := YShift(h);
				PrinterLine(x,y,w,h);
			ELSIF ch = 9X THEN (* circle *)
				Files.Read(spool.readR,col); Files.ReadBytes(spool.readR,x,2);
				Files.ReadBytes(spool.readR, y, 2); Files.ReadBytes(spool.readR, r, 2);
				h  := 0; Shift(x, y, r, h);
				PrinterCircle(x, y, r);
			ELSIF ch = 7X THEN (*Ellipse*)
				Files.Read(spool.readR,col); Files.ReadBytes(spool.readR,x,2);
				Files.ReadBytes(spool.readR,y,2); Files.ReadBytes(spool.readR,w,2); Files.ReadBytes(spool.readR,h,2);
				Shift(x,y,w,h);
				PrinterEllipse (x, y, w, h);
			ELSIF ch = 0AX THEN  (* Spline *)
				Files.Read(spool.readR,open);
				Files.ReadBytes(spool.readR,x,2); Files.ReadBytes(spool.readR,y,2);
				x := XShift(x); y := YShift(y);
				Files.ReadBytes(spool.readR,n,2);
				i := 0; WHILE i < n DO
					Files.ReadBytes(spool.readR,X[i],2);Files.ReadBytes(spool.readR,Y[i],2);
					X[i] := XShift(X[i]); Y[i] := YShift(Y[i]);
					INC(i)
				END;
				PrinterSpline(x, y, n, open, X, Y);
			ELSIF ch = 0BX THEN (* usecolor *)
				Files.Read(spool.readR,ch); r := ORD(ch);
				Files.Read(spool.readR,ch); g := ORD(ch);
				Files.Read(spool.readR,ch); b := ORD(ch);
				PrinterUseColor(r,g,b);
			ELSIF ch = 8X THEN (* picture *)
				Files.ReadBytes(spool.readR,px,2); Files.ReadBytes(spool.readR,py,2);
				Files.ReadBytes(spool.readR,pw,2); Files.ReadBytes(spool.readR,ph,2);
				Files.ReadBytes(spool.readR,x,2); Files.ReadBytes(spool.readR,y,2);
				x := XShift(x); y := YShift(y);
				Files.ReadBytes(spool.readR,w,2); Files.ReadBytes(spool.readR,h,2);
				Files.Read(spool.readR, mode);
				pl := spool.pictList; ip := spool.actPict;
				WHILE ip > 0 DO pl := pl.next; DEC(ip) END;
				PrinterPicture(pl.pict, px, py, pw, ph, x, y, w, h);
				INC(spool.actPict)
			ELSIF ch = 4X THEN (* page *)
				Files.Read(spool.readR,ch);
				IF cT = PH THEN OpenPage; END;
				IF cY - CH > 0 THEN
					Files.Set(spool.readR, spool.file, spool.actPos);
					spool.actPict := spool.lastActPict;
					PrinterStripe(ORD(ch));
					DEC(cY, CH); DEC(cT, CH);
				ELSE
					PrinterStripe(ORD(ch));
					cY := PH - CH ; cT := PH; spool.actPos := Files.Pos(spool.readR);
					spool.lastActPict := spool.actPict;
					ClosePage
				END
			ELSE Log("error in Printer File",""); EXIT;
			END;
			IF Oberon.Time()-T > 20 THEN RETURN END;
		END; (* loop *)
		PrinterClose;
		spool := spool.next;
		IF spool = NIL THEN
			task := NIL; Oberon.Remove(me);
		END;
	END Spool;

	PROCEDURE StartSpool(P: HPPrinter);
		VAR i : INTEGER; ch : CHAR; p, n: SpoolList;
	BEGIN
		i := 0; WHILE i < maxfonts DO font[i] := ""; INC(i) END; (*?*)
		NEW(n); n.next := NIL; n.readR := printerfile; Files.Set(printerfile, NIL, 0); n.P := P; n.file := P.file; P.file := NIL;
		Files.Set(n.readR, n.file, 1); Files.Read(n.readR, ch);
		n.spoolFile := P.spoolFile; P.spoolFile := NIL; Files.Set(n.spoolr, n.spoolFile, 0);
		n.pictList := P.pictList;
		n.color := P.color;
		n.actPos := 4; Files.Set(n.readR, n.file, n.actPos);
		n.actPict := 0; n.lastActPict := 0;
		yellow := 0; magenta := 0; cyan := 0;
		IF n.color THEN
			IF Planes = 4 THEN black := 16
			ELSE yellow := 16; magenta := 16; cyan := 16 END;
		ELSE black := 16 END;
		cY := PH - CH; cT := PH;
		IF spool = NIL THEN
			ASSERT(task = NIL);
			spool := n;
			NEW(task);  task.time := Oberon.Time();  task.safe := FALSE;  task.handle := Spool;
			Oberon.Install(task)
		ELSE	(* busy *)
			ASSERT(task # NIL);
			p := spool;  WHILE p.next # NIL DO p := p.next END;
			p.next := n
		END;
		PrinterOpen;
	END StartSpool;

	PROCEDURE Close*(P: Printer.Printer);
	BEGIN
		WITH P: HPPrinter DO
			IF P.color THEN Files.Set(printerfile, P.file, 1); Files.Write(printerfile, 5X) END;
			Files.Set(printerfile, P.file, 2); Files.WriteBytes(printerfile, nopage, 2); (*Files.Register(P.file);*)
			WHILE nofonts > 0 DO DEC(nofonts); font[nofonts] := "" END;
			StartSpool(P);
			P.res := 0;
		END;
	END Close;

	PROCEDURE UseColor*(P: Printer.Printer; red,green,blue : INTEGER);
	BEGIN
		IF Planes # 1 THEN P(HPPrinter).color := P(HPPrinter).color OR (red # blue) OR (green # blue) END;
		IF (red < 0) OR (red > 255) OR (green < 0) OR (green > 255) OR (blue< 0) OR (blue> 255) THEN HALT(99) END;
		Write(11); Write(SHORT(red)); Write(SHORT(green)); Write(SHORT(blue))
	END UseColor;

PROCEDURE NewPrinter*(): Printer.Printer;
VAR P: HPPrinter;
BEGIN
	NEW(P);
	P.name := InstallCmd;
	P.InitMetrics := InitMetrics;
	P.Open := Open;
	P.Close := Close;
	P.Page := Page;
	P.ReplConst := ReplConst;
	P.ReplPattern := ReplPattern;
	P.Line := Line;
	P.Circle := Circle;
	P.Ellipse := Ellipse;
	P.Spline := Spline;
	P.Picture := Picture;
	P.UseListFont := UseListFont;
	P.String := String;
	P.ContString := ContString;
	P.UseColor := UseColor;
	P.GetMetric := GetMetric;
	RETURN P
END NewPrinter;

PROCEDURE Cleanup;
BEGIN
	IF (Printer.current # NIL) & (Printer.current.name = InstallCmd) THEN
		Printer.current := NIL
	END;
	IF task # NIL THEN spool := NIL; task := NIL END;
END Cleanup;

PROCEDURE SetPlanes0*(n: INTEGER);
BEGIN
	planes := n;
END SetPlanes0;

PROCEDURE SetPlanes*;
VAR planes: INTEGER;
BEGIN
	In.Open; In.Int(planes);
	IF In.Done THEN SetPlanes0(planes) END;
END SetPlanes;

PROCEDURE Install*;
BEGIN
	(* register font loader for special metrics, if needed *)
	Printer.Install(NewPrinter());
END Install;

BEGIN
	spool := NIL; task := NIL;
	planes := 0; Planes := 1;
	freeP := NIL;
	nofonts := 0;
	Width := 2480;
	Height := 3508;
	InitR;
	InitP(1, 16, 4, 8);
	InitP(2, 8, 2, 4);
	InitP(3, 4, 2, 2);
	InitP(4, 2, 1, 1);
	InitP(5, 1, 1, 0);
	InitP(6, 16, 1, 15);
	InitP(7, 16, 1, 1);
	InitP(8, 16, 1, 0);
	InitP(9, 1, 16, 0);
	InitIntens;
	Default := Fonts.This("Oberon10.Pr3.Fnt");
	Texts.OpenWriter(W);
	Unit := 3048;
	Modules.InstallTermHandler(Cleanup)
END HPPCL.Print

Builder.Free HPPCL.Mod ~

HPPCL.Install
HPPCL.SetPlanes 4
