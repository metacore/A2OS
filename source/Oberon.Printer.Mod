(* ETH Oberon, Copyright 2001 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

MODULE Printer IN Oberon; (** portable, except where noted *) (* jm, pjm *)

(* AFI 12.03.2003 - procedure Spool modified to support 8 serial ports i.o. 4 *)

(**Module Printer provide an interface for installable printers.
*)

IMPORT Files, Modules, Fonts, Texts, Input, Display, Oberon, Pictures, Centronics, V24;

CONST
	Unit300 = 3048; (* 300 dpi resolution *)
	defaultPrinter = "PSPrinter.Install";

TYPE
	Printer* = POINTER TO PrinterDesc;
	PrinterDesc* = RECORD
		res*: SIGNED16; (** Result code for Open method. *)
		name*: ARRAY 64 OF CHAR; (** Command used for installing the printer. *)
		Height*, Width*, Depth*: SIGNED16;	(** Page size (in printer pixels), and available colors (bit depth) **)
		FrameX*, FrameY*, FrameW*, FrameH*: SIGNED16; (** Printable region of the page. *)
		Unit*: SIGNED32;	(** Printer resolution in 1/36000 mm per pixel. *)

		InitMetrics*: PROCEDURE (P: Printer);
		Open*: PROCEDURE (P: Printer; printer, options: ARRAY OF CHAR); (** Initialize printer & set result code. *)
		Close*: PROCEDURE (P: Printer);	(** Stop printing & set result code. *)
		Page*: PROCEDURE (P: Printer; nofcopies: SIGNED16);	(** End of page reached. *)
		ReplConst*: PROCEDURE (P: Printer; x, y, w, h: SIGNED16);	(** Block fill. *)
		ReplPattern*: PROCEDURE (P: Printer; x, y, w, h: SIGNED16; patno: SIGNED16);	(** Pattern fill. *)
		Line*: PROCEDURE (P: Printer; x0, y0, x1, y1: SIGNED16);	(** Line between (x0, y0) and (x1, y1). *)
		Circle*: PROCEDURE (P: Printer; x0, y0, r: SIGNED16);
		Ellipse*: PROCEDURE (P: Printer; x0, y0, a, b: SIGNED16);
		Spline*: PROCEDURE (P: Printer; x0, y0, n, open: SIGNED16; VAR X, Y: ARRAY OF SIGNED16);
		Picture*: PROCEDURE (P: Printer; pict: Pictures.Picture; sx, sy, sw, sh, dx, dy, dw, dh, mode: SIGNED16);
		UseListFont*: PROCEDURE (P: Printer; name: ARRAY OF CHAR);
		String*: PROCEDURE (P: Printer; x, y: SIGNED16; str: ARRAY OF CHAR; fnt: Fonts.Font);
		ContString*: PROCEDURE (P: Printer; str: ARRAY OF CHAR; fnt: Fonts.Font);
		UseColor*: PROCEDURE (P: Printer; red, green, blue: SIGNED16);
		GetMetric*: PROCEDURE (P: Printer; fnt: Fonts.Font): Fonts.Font
	END;

	SendProc = PROCEDURE (port: SIGNED16;  ch: CHAR;  VAR done: BOOLEAN);
	SpoolList = POINTER TO SpoolListDesc;
	SpoolListDesc = RECORD
		next: SpoolList;
		send: SendProc;
		r: Files.Rider;
		port: SIGNED16;
		done: BOOLEAN;
		ch: CHAR;
		v24: BOOLEAN
	END;

VAR
	Height*, Width*, Depth*: SIGNED16;	(** In printer pixels, and bit depth *)
	FrameX*, FrameY*, FrameW*, FrameH*: SIGNED16;	(** Printable area. *)
	Unit*: SIGNED32;	(** Printer resolution in 1/36000 mm per pixel. *)
	res*: SIGNED16;	(** result code. 0 = ok, 1 = no such printer, 2 = no link, 3 = printer not ready, 4 = no permission *)
	current*: Printer;	(** Current active printer. *)
	spool: SpoolList;
	W: Texts.Writer;
	task: Oberon.Task;
	timeslice: SIGNED32;
	spoollength, spoolpos: SIGNED32;	(* view with System.State Printer *)
	default: ARRAY 64 OF CHAR;

PROCEDURE SplitName(VAR name, MName, PName: ARRAY OF CHAR);
	VAR i, j: SIGNED32;
BEGIN i := 0;
	WHILE name[i] # "." DO MName[i] := name[i]; INC(i) END;
	MName[i] := 0X; INC(i); j := 0;
	WHILE name[i] # 0X DO PName[j] := name[i]; INC(i); INC(j) END;
	PName[j] := 0X
END SplitName;

PROCEDURE LoadDefaultPrinter;
	VAR
		S: Texts.Scanner;
		s, defMod, defCmd: ARRAY 64 OF CHAR;
		Mod: Modules.Module; Cmd: Modules.Command;
BEGIN
	current := NIL;
	Oberon.OpenScanner(S, "Printer.Default");
	IF S.class IN {Texts.Name, Texts.String} THEN
		COPY(S.s, s)
	ELSE
		COPY(defaultPrinter, s)
	END;
	SplitName(s, defMod, defCmd);
	Mod := Modules.ThisMod(defMod);
	IF Modules.res = 0 THEN
		Cmd := Modules.ThisCommand(Mod, defCmd);
		IF Modules.res = 0 THEN
			Cmd()
		END
	ELSE
		Texts.WriteString(W, "Printer: ");  Texts.WriteString(W, S.s);  Texts.WriteString(W, " not found");
		Texts.WriteLn(W);  Texts.Append(Oberon.Log, W.buf)
	END;
	Oberon.OpenScanner(S, "Printer.DefaultName");
	IF S.class IN {Texts.Name, Texts.String} THEN
		COPY(S.s, default)
	ELSE
		default := "Temp.Printer.Out"
	END
END LoadDefaultPrinter;

(** Install printer driver. P.InitMetrics is called to initialise the page metrics. *)
PROCEDURE Install*(P: Printer);
	VAR M: Display.ControlMsg; N: Oberon.ControlMsg;
BEGIN
	ASSERT(P # NIL, 100);
	P.InitMetrics(P);
	Width := P.Width; Height := P.Height; Depth := P.Depth;
	FrameX := P.FrameX; FrameY := P.FrameY; FrameW := P.FrameW; FrameH := P.FrameH;
	Unit := P.Unit; current := P;
	N.id := Oberon.neutralize; M.F := NIL; Display.Broadcast(N);
	M.id := Display.newprinter; M.F := NIL; Display.Broadcast(M);
	M.id := Display.suspend; M.F := NIL; Display.Broadcast(M);
	M.id := Display.restore; M.F := NIL; Display.Broadcast(M)
END Install;

(** Open specified printer.  res code is set. *)
PROCEDURE Open* (printer, options: ARRAY OF CHAR);
VAR P: Printer;
BEGIN
	IF current = NIL THEN LoadDefaultPrinter END;	(* load driver when printer first used *)
	IF current # NIL THEN
		P := current;
		IF printer = "Default" THEN P.Open(P, default, options);
		ELSE P.Open(P, printer, options)
		END;
		res := P.res;
		Width := P.Width; Height := P.Height; Depth := P.Depth;
		FrameX := P.FrameX; FrameY := P.FrameY; FrameW := P.FrameW; FrameH := P.FrameH;
		Unit := P.Unit
	ELSE
		res := 1	(* no such printer *)
	END
END Open;

PROCEDURE Close*;
VAR P: Printer;
BEGIN
	P := current;
	P.Close(P);
	res := P.res;
	Width := P.Width; Height := P.Height; Depth := P.Depth;
	FrameX := P.FrameX; FrameY := P.FrameY; FrameW := P.FrameW; FrameH := P.FrameH;
	Unit := P.Unit
END Close;

PROCEDURE Page* (nofcopies: SIGNED16);
BEGIN current.Page(current, nofcopies)
END Page;

PROCEDURE ReplConst* (x, y, w, h: SIGNED16);
BEGIN current.ReplConst(current, x, y, w, h)
END ReplConst;

PROCEDURE ReplPattern* (x, y, w, h: SIGNED16; patno: SIGNED16);
BEGIN current.ReplPattern(current, x, y, w, h, patno)
END ReplPattern;

PROCEDURE Line* (x0, y0, x1, y1: SIGNED16);
BEGIN current.Line(current, x0, y0, x1, y1)
END Line;

PROCEDURE Circle* (x0, y0, r: SIGNED16);
BEGIN current.Circle(current, x0, y0, r)
END Circle;

PROCEDURE Ellipse* (x0, y0, a, b: SIGNED16);
BEGIN current.Ellipse(current, x0, y0, a, b)
END Ellipse;

PROCEDURE Spline* (x0, y0, n, open: SIGNED16; VAR X, Y: ARRAY OF SIGNED16);
BEGIN current.Spline(current, x0, y0, n, open, X, Y)
END Spline;

PROCEDURE Picture* (P: Pictures.Picture; sx, sy, sw, sh, dx, dy, dw, dh, mode: SIGNED16);
BEGIN current.Picture(current, P, sx, sy, sw, sh, dx, dy, dw, dh, mode)
END Picture;

PROCEDURE UseListFont* (name: ARRAY OF CHAR);
BEGIN current.UseListFont(current, name)
END UseListFont;

PROCEDURE String* (x, y: SIGNED16; str: ARRAY OF CHAR; fnt: Fonts.Font);
BEGIN current.String(current, x, y, str, fnt)
END String;

PROCEDURE ContString* (str: ARRAY OF CHAR; fnt: Fonts.Font);
BEGIN current.ContString(current, str, fnt)
END ContString;

PROCEDURE UseColor* (red, green, blue: SIGNED16);
BEGIN current.UseColor(current, red, green, blue)
END UseColor;

PROCEDURE GetMetric* (fnt: Fonts.Font): Fonts.Font;
BEGIN
	IF current # NIL THEN RETURN current.GetMetric(current, fnt) ELSE RETURN NIL END
END GetMetric;

(* System.PrinterCOMn configuration syntax (default 9600,8,n,1)
	config = bps ["," databits ["," parity ["," stopbits]]] .
	bps = <any valid numeric value> .
	databits = "5"|"6"|"7"|"8" .
	parity = "n"|"o"|"e"|"m"|"s" .
	stopbits = "1"|"2" .
*)

PROCEDURE GetConfig(port: SIGNED32;  VAR bps, data, parity, stop: SIGNED32);
VAR s: Texts.Scanner;  label: ARRAY 32 OF CHAR;  i: SIGNED32;
BEGIN
	bps := 9600;  data := 8;  parity := V24.ParNo;  stop := V24.Stop1;
	label := "Printer.COM#";
	i := 0;  WHILE label[i] # 0X DO INC(i) END;
	label[i-1] := CHR(ORD("1")+port-V24.COM1);
	Oberon.OpenScanner(s, label);
	IF s.class = Texts.Int THEN
		bps := s.i;  Texts.Scan(s);
		IF (s.class = Texts.Char) & (s.c = ",") THEN
			Texts.Scan(s);
			IF s.class = Texts.Int THEN
				data := s.i;  Texts.Scan(s);
				IF (s.class = Texts.Char) & (s.c = ",") THEN
					Texts.Scan(s);
					IF s.class IN {Texts.Name, Texts.String} THEN
						CASE CAP(s.s[0]) OF
							"N": parity := V24.ParNo
							|"O": parity := V24.ParOdd
							|"E": parity := V24.ParEven
							|"M": parity := V24.ParMark
							|"S": parity := V24.ParSpace
						ELSE
						END;
						Texts.Scan(s);
						IF (s.class = Texts.Char) & (s.c = ",") THEN
							Texts.Scan(s);
							IF s.class = Texts.Int THEN stop := s.i END
						END
					END
				END
			END
		END
	END
END GetConfig;

(* Spooling *)

PROCEDURE StartJob(n: SpoolList);
VAR err, bps, data, parity, stop: SIGNED32;
BEGIN
	spoollength := Files.Length(Files.Base(n.r));
	IF n.v24 THEN
		GetConfig(n.port, bps, data, parity, stop);
		V24.Start(n.port, bps, data, parity, stop, err);
		ASSERT(err = 0)
	ELSE
		Centronics.Start(n.port)
	END
END StartJob;

PROCEDURE EndJob(n: SpoolList);
BEGIN
	spoollength := 0;  spoolpos := 0;
	IF n.v24 THEN
		V24.Stop(n.port)
	ELSE
		Centronics.Stop(n.port)
	END
END EndJob;

PROCEDURE V24Send(port: SIGNED16;  ch: CHAR;  VAR done: BOOLEAN);
VAR s: SET;  err: SIGNED32;
BEGIN
	V24.GetMC(port, s);
	IF V24.CTS IN s THEN
		V24.Send(port, ch, err);
		done := err = 0
	ELSE
		done := FALSE
	END
END V24Send;

PROCEDURE Spooler(me: Oberon.Task);
VAR t: SIGNED32;
BEGIN
	t := Input.Time();
	LOOP
		WHILE ~spool.done DO
			spool.send(spool.port, spool.ch, spool.done);
			IF Input.Time() - t > timeslice THEN EXIT END	(* end of timeslice *)
		END;
		Files.Read(spool.r, spool.ch);
		INC(spoolpos);
		IF spool.r.eof THEN
			EndJob(spool);
			spool := spool.next;
			IF spool = NIL THEN
				task := NIL;  Oberon.Remove(me);
				Texts.WriteString(W, "Printing finished");  Texts.WriteLn(W);
				Texts.Append(Oberon.Log, W.buf);
				EXIT
			END;
			spool.done := TRUE;
			StartJob(spool)
		ELSE
			spool.done := FALSE
		END
	END;
	me.time := t
END Spooler;

PROCEDURE Enter(f: Files.File;  port: SIGNED16;  v24: BOOLEAN);
VAR p, n: SpoolList;
BEGIN
	NEW(n);  n.next := NIL;
	Files.Set(n.r, f, 0);  n.port := port;  n.done := TRUE;  n.v24 := v24;
	IF v24 THEN n.send := V24Send ELSE n.send := Centronics.SendPoll END;
	IF spool = NIL THEN	(* idle *)
		ASSERT(task = NIL);
		StartJob(n);
		spool := n;
		NEW(task);  task.time := Input.Time();  task.safe := FALSE;  task.handle := Spooler;
		Oberon.Install(task)
	ELSE	(* busy *)
		ASSERT(task # NIL);
		p := spool;  WHILE p.next # NIL DO p := p.next END;
		p.next := n
	END
END Enter;

(** Send file to the local printer specified by its name, or if not a known printer, register the file.  res code is set. *)
PROCEDURE Spool*(f: Files.File);	(** non-portable *)
VAR name: ARRAY 64 OF CHAR;  pre: ARRAY 6 OF CHAR;  p: SIGNED16;  i, j: SIGNED32;
BEGIN
	Files.GetName(f, name);
	i := 0;  WHILE (name[i] # 0X) & (name[i] # ":") DO INC(i) END;
	IF name[i] = ":" THEN
		j := 0;  REPEAT INC(i); name[j] := name[i]; INC(j) UNTIL name[i] = 0X
	END;
	COPY(name, pre); pre[3] := 0X;
	IF name = "" THEN
		res := 0
	ELSIF (pre = "LPT") & (name[3] >= "1") & (name[3] <= "3") & (name[4] = 0X) THEN	(* centronics *)
		CASE name[3] OF
			"1": p := Centronics.LPT1
			|"2": p := Centronics.LPT2
			|"3": p := Centronics.LPT3
		END;
		Enter(f, p, FALSE);
		res := 0
	ELSIF (pre = "COM") & (name[3] >= "1") & (name[3] <= "8") & (name[4] = 0X) THEN	(* V24 *)
		CASE name[3] OF
			"1": p := V24.COM1
			|"2": p := V24.COM2
			|"3": p := V24.COM3
			|"4": p := V24.COM4
			|"5": p := V24.COM5
			|"6": p := V24.COM6
			|"7": p := V24.COM7
			|"8": p := V24.COM8
		END;
		Enter(f, p, TRUE)
	ELSE
		Files.Register(f);
		res := 0
	END
END Spool;

PROCEDURE Cleanup;
BEGIN
	IF task # NIL THEN
		Oberon.Remove(task);  task := NIL;  spool := NIL;
		Texts.WriteString(W, "Printing aborted");  Texts.WriteLn(W);
		Texts.Append(Oberon.Log, W.buf)
	END
END Cleanup;

PROCEDURE Init;
BEGIN
	Texts.OpenWriter(W);
	spool := NIL;  task := NIL;  spoollength := 0;  spoolpos := 0;
	timeslice := Input.TimeUnit DIV 50;
	(*Height := 0; Width := 0;*)
	Height := 3508; Width := 2480; Depth := 24;
	FrameX := 236; FrameY := 177; FrameW := 2008; FrameH := 3154;
	Unit := Unit300;	(* 300 dpi resolution *)
	Modules.InstallTermHandler(Cleanup)
END Init;

BEGIN
	Init
END Printer.

(** Remarks:

1. Installing a printer involves calling Printer.Install with a filled-out printer (say P) descriptor. The installed printer is assigned to Printer.current. Immediately after installation, the InitMetrics method is called so that the printer can return its metrics in P.Width, P.Height, P.Depth, P.FrameX, P.FrameY, P.FrameW, P.FrameH, and P.Unit (see next remark also). These variables are copied to the global variables with the same names. Calling procedures of module Printer results in a call to a corresponding method of the currently active printer Printer.current.

2. The Open method may interpret the user and password for allowing access to a printer. A res code of 0 indicates that the printer has successfully been opened. The Open method must fill in the fields Height, Width, Depth, FrameX, FrameY, FrameW, FrameH, and Unit of the printer descriptor. All values except Unit and Depth are in printer pixels. Typical printers have 300 pixels per inch (commonly abbreviated dots-per-inch (dpi)). Unit specifies the width and height of a single pixel in units of 1/36000 mm. The printer origin 0, 0 is the left bottom corner of the page (and may not be printable). FrameX, FrameY, FrameW, FrameH indicate the printable area of the page. Depth (bits per pixel) has a typical value of 1 (black and white printer) or 24 (true-color printer). A printer must be closed for output to appear.

3. All coordinates are in printer pixels. Only the first characters of a font name (fname) up to the first period are relevant. Strings are positioned relative to their base-line. A module is free to print anywhere on the page regardless of the printer connected (there is no need to print from the top to the bottom of a page when a line printer is connected).

4. The printer patterns are defined as follows:

1	2	3	4	5	6	7	8

5. UseListFont has no meaning.

6. The String method keeps track of where the last character ends, allowing ContString to continue from that position.

7. UseColor takes intensity values in the range 0 <= x < 256 for each color component. Setting a color influences all further drawing operations. Setting the color to white allows you to delete already printer areas (a single page is normally cached in memory).

8. Method Spline draws a spline through the n points in arrays X, Y. (x0, y0) specifies a translation vector. Open set to 1 indicates an open spline should be drawn, otherwise a closed spline is assumed.

9. Implementation restriction: On Oberon for Windows nofcopies is ignored and defaults to 1.

10. Method Picture prints the area sx, sy, sw, sh of a picture onto the area dx, dy, dw, dh of the printer (scaling as needed).

11. The default printer driver that is installed at startup is specified with System.DefaultPrinter in the Oberon.Text/Registry. The value of the key must be the name of a command that installs a printer.
*)
