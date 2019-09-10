(* ETH Oberon, Copyright 2001 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

MODULE Printer IN Oberon; (** portable *)	(* jm 26.10.95 *)

(** Module Printer provide an interface for installable printers. *)

IMPORT KernelLog IN A2, Modules, Pictures, Display, Fonts, Texts, Oberon;

CONST
	Unit300 = 3048; (* 300 dpi resolution *)
	defaultPrinter = "WinPrinter.Install";

TYPE
	Printer* = POINTER TO PrinterDesc;
	PrinterDesc* = RECORD
		res*: SIGNED16; (** Result code for Open method. *)
		gen*: ARRAY 64 OF CHAR; (** Command used for installing the printer. *)
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

VAR
	Height*, Width*, Depth*: SIGNED16;	(** In printer pixels, and bit depth *)
	FrameX*, FrameY*, FrameW*, FrameH*: SIGNED16;	(** Printable area. *)
	Unit*: SIGNED32;	(** Printer resolution in 1/36000 mm per pixel. *)
	res*: SIGNED16;	(** result code. 0 = ok, 1 = no such printer, 2 = no link, 3 = printer not ready, 4 = no permission *)
	current*: Printer;	(** Current active printer. *)

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
		KernelLog.String("Printer.LoadDefaultPrinter "); KernelLog.String(s); KernelLog.String(" not found"); KernelLog.Ln();
		Mod := Modules.ThisMod("WinPrinter");
		IF Modules.res = 0 THEN
			Cmd := Modules.ThisCommand(Mod, "Install");
			IF Modules.res = 0 THEN
				Cmd()
			END
		END
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

(** Open specified printer. res code is set. *)
PROCEDURE Open*(printer, options: ARRAY OF CHAR);
	VAR P: Printer;
BEGIN
	IF current # NIL THEN
		P := current;
		P.Open(P, printer, options);
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

PROCEDURE Page*(nofcopies: SIGNED16);
BEGIN
	current.Page(current, nofcopies)
END Page;

PROCEDURE ReplConst*(x, y, w, h: SIGNED16);
BEGIN
	current.ReplConst(current, x, y, w, h)
END ReplConst;

PROCEDURE ReplPattern*(x, y, w, h: SIGNED16; patno: SIGNED16);
BEGIN
	current.ReplPattern(current, x, y, w, h, patno)
END ReplPattern;

PROCEDURE Line*(x0, y0, x1, y1: SIGNED16);
BEGIN
	current.Line(current, x0, y0, x1, y1)
END Line;

PROCEDURE Circle*(x0, y0, r: SIGNED16);
BEGIN
	current.Circle(current, x0, y0, r)
END Circle;

PROCEDURE Ellipse*(x0, y0, a, b: SIGNED16);
BEGIN
	current.Ellipse(current, x0, y0, a, b)
END Ellipse;

PROCEDURE Spline*(x0, y0, n, open: SIGNED16; VAR X, Y: ARRAY OF SIGNED16);
BEGIN
	current.Spline(current, x0, y0, n, open, X, Y)
END Spline;

PROCEDURE Picture*(P: Pictures.Picture; sx, sy, sw, sh, dx, dy, dw, dh, mode: SIGNED16);
BEGIN
	current.Picture(current, P, sx, sy, sw, sh, dx, dy, dw, dh, mode)
END Picture;

PROCEDURE UseListFont*(name: ARRAY OF CHAR);
BEGIN
	current.UseListFont(current, name)
END UseListFont;

PROCEDURE String*(x, y: SIGNED16; str: ARRAY OF CHAR; fnt: Fonts.Font);
BEGIN
	current.String(current, x, y, str, fnt)
END String;

PROCEDURE ContString*(str: ARRAY OF CHAR; fnt: Fonts.Font);
BEGIN
	current.ContString(current, str, fnt)
END ContString;

PROCEDURE UseColor*(red, green, blue: SIGNED16);
BEGIN
	current.UseColor(current, red, green, blue)
END UseColor;

PROCEDURE GetMetric*(fnt: Fonts.Font): Fonts.Font;
BEGIN
	IF current # NIL THEN
	RETURN current.GetMetric(current, fnt)
	ELSE RETURN NIL
	END;
END GetMetric;

BEGIN
	Height := 0; Width := 0;
	Unit := Unit300;
	LoadDefaultPrinter
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

11. The default printer that is installed at startup is specified in the System section of the registry under key DefaultPrinter. The value of the key must be the name of a command that installs a printer. Windows Oberon supports WinPrinter.Install and PSPrinter.Install. Oberon has to be rebooted before a change will take effect.

	System.Set Printer Default := "WinPrinter.Install"
	System.Get Printer *)