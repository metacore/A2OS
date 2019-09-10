(* ETH Oberon, Copyright 2001 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

MODULE Snapshot IN Oberon;	(** portable *)	(* Native *)

(**
	jm 10.7.95 / pjm 17.10.97

	Snapshot.Viewer *		Make snapshot of viewer
	Snapshot.Document *		Make snapshot of document
	Snapshot.Gadget *		Make snapshot of marked gadget

	Snapshot.InsertViewer *		Insert snapshot of viewer at caret
	Snapshot.InsertDocument *		Insert snapshot of document at caret
	Snapshot.InsertGadget *		Insert snapshot of marked gadget

	Snapshot.Screen 	Make snapshot of the screen
*)

(* known bugs: truecolor/hicolor is very slow *)

IMPORT SYSTEM, Display, Display3, Effects, Objects, Oberon, Pictures, Gadgets,
	Documents, Viewers, Rembrandt, RembrandtDocs, Machine IN A2;

TYPE
	PositionMsg = RECORD (Display.FrameMsg)
		FX, FY, FW, FH: SIGNED16;
	END;

VAR
	GetPixel: PROCEDURE (x, y: SIGNED32): SIGNED32;
	handle: Objects.Handler;
	base, maxy: SIGNED32;
	pal: ARRAY 256 OF RECORD
		r, g, b: SIGNED32
	END;
	rm, gm, bm, rs, gs: SIGNED32;

PROCEDURE CopyBlock(p: Pictures.Picture;  x, y, w, h: SIGNED16);
VAR xi, yi: SIGNED16;
BEGIN
	FOR xi := x TO x+w-1 DO
		FOR yi := y TO y+h-1 DO
			Pictures.Dot(p, SHORT(GetPixel(xi, yi)), xi-x, yi-y, Display.replace)
		END
	END
END CopyBlock;

PROCEDURE InitPal(p: Pictures.Picture);
VAR i, r, g, b: SIGNED16;
BEGIN
	FOR i := 0 TO 255 DO
		Pictures.GetColor(p, i, r, g, b);
		pal[i].r := r DIV (256 DIV rm);
		pal[i].g := g DIV (256 DIV gm);
		pal[i].b := b DIV (256 DIV bm)
	END
END InitPal;

PROCEDURE Border(obj: Rembrandt.Frame; flag: BOOLEAN);
VAR M: Objects.AttrMsg;
BEGIN
	M.id := Objects.set; M.class := Objects.Bool; M.b := flag; M.name := "Border"; M.res := -1;
	obj.handle(obj, M)
END Border;

(* Make a snapshot of any visual gadget. *)
PROCEDURE SnapFrame*(F: Gadgets.Frame; VAR P: Pictures.Picture);
VAR dlink: Objects.Object; D: Display.DisplayMsg; O: Display3.OverlapMsg;
BEGIN
	Effects.OpenMenu(0, 0, F.W, F.H);
	D.id := Display.full; D.device := Display.screen;
	D.x := -F.X; D.y := -F.Y;
	dlink := F.dlink;
	O.M := NIL; O.res := -1; Objects.Stamp(O); F.handle(F, O); F.dlink := NIL;
	IF O.res >= 0 THEN
		D.res := -1; F.handle(F, D);
		F.dlink := dlink;
		NEW(P);  Pictures.Create(P, F.W, F.H, 8);
		InitPal(P);
		CopyBlock(P, 0, 0, F.W, F.H)
	ELSE
		P := NIL
	END;
	Effects.CloseMenu
END SnapFrame;

PROCEDURE Viewer*;
VAR V: Viewers.Viewer; P: Pictures.Picture;
BEGIN
	V := Oberon.MarkedViewer();
	IF V # NIL THEN
		Oberon.RemoveMarks(V.X, V.Y, V.W, V.H);
		NEW(P);  Pictures.Create(P, V.W, V.H, 8);
		InitPal(P);
		CopyBlock(P, V.X, V.Y, V.W, V.H);
		RembrandtDocs.OpenPict(P, "Snapshot.Pict")
	END
END Viewer;

PROCEDURE InsertViewer*;
VAR V: Viewers.Viewer; P: Pictures.Picture; obj: Rembrandt.Frame;
BEGIN
	V := Oberon.MarkedViewer();
	IF V # NIL THEN
		Oberon.RemoveMarks(V.X, V.Y, V.W, V.H);
		NEW(P);  Pictures.Create(P, V.W, V.H, 8);
		InitPal(P);
		CopyBlock(P, V.X, V.Y, V.W, V.H);
		NEW(obj); Rembrandt.NewP(obj, P); Border(obj, FALSE);
		Gadgets.Integrate(obj);
	END
END InsertViewer;

PROCEDURE NewHandler(obj: Objects.Object; VAR M: Objects.ObjMsg);
BEGIN
	WITH obj: Display.Frame DO
		IF M IS PositionMsg THEN
			WITH M: PositionMsg DO
				IF M.res < 0 THEN
					M.FX := M.x + obj.X; M.FY := M.y + obj.Y; M.FW := obj.W; M.FH := obj.H;
					M.res := 0
				END
			END
		ELSE handle(obj, M)
		END
	END
END NewHandler;

PROCEDURE Document*;
VAR D: Documents.Document; M: PositionMsg; P: Pictures.Picture;
BEGIN
	D := Documents.MarkedDoc();
	IF D # NIL THEN
		handle := D.handle;
		D.handle := NewHandler;
		M.F := D; Display.Broadcast(M);
		D.handle := handle;
		Oberon.RemoveMarks(M.FX, M.FY, M.FW, M.FH);
		NEW(P);  Pictures.Create(P, M.FW, M.FH, 8);
		InitPal(P);
		CopyBlock(P, M.FX, M.FY, M.FW, M.FH);
		RembrandtDocs.OpenPict(P, "Snapshot.Pict")
	END
END Document;

PROCEDURE Gadget*;
VAR D: Display.Frame; M: PositionMsg; P: Pictures.Picture;
BEGIN
	D := Oberon.MarkedFrame();
	IF D # NIL THEN
		handle := D.handle;
		D.handle := NewHandler;
		M.F := D; Display.Broadcast(M);
		D.handle := handle;
		Oberon.RemoveMarks(M.FX, M.FY, M.FW, M.FH);
		NEW(P);  Pictures.Create(P, M.FW, M.FH, 8);
		InitPal(P);
		CopyBlock(P, M.FX, M.FY, M.FW, M.FH);
		RembrandtDocs.OpenPict(P, "Snapshot.Pict")
	END
END Gadget;

PROCEDURE InsertDocument*;
VAR D: Documents.Document; M: PositionMsg; P: Pictures.Picture; obj: Rembrandt.Frame;
BEGIN
	D := Documents.MarkedDoc();
	IF D # NIL THEN
		handle := D.handle;
		D.handle := NewHandler;
		M.F := D; Display.Broadcast(M);
		D.handle := handle;
		Oberon.RemoveMarks(M.FX, M.FY, M.FW, M.FH);
		NEW(P);  Pictures.Create(P, M.FW, M.FH, 8);
		InitPal(P);
		CopyBlock(P, M.FX, M.FY, M.FW, M.FH);
		NEW(obj); Rembrandt.NewP(obj, P); Border(obj, FALSE);
		Gadgets.Integrate(obj);
	END
END InsertDocument;

PROCEDURE InsertGadget*;
VAR D: Display.Frame; M: PositionMsg; P: Pictures.Picture; obj: Rembrandt.Frame;
BEGIN
	D := Oberon.MarkedFrame();
	IF D # NIL THEN
		handle := D.handle;
		D.handle := NewHandler;
		M.F := D; Display.Broadcast(M);
		D.handle := handle;
		Oberon.RemoveMarks(M.FX, M.FY, M.FW, M.FH);
		NEW(P);  Pictures.Create(P, M.FW, M.FH, 8);
		InitPal(P);
		CopyBlock(P, M.FX, M.FY, M.FW, M.FH);
		NEW(obj); Rembrandt.NewP(obj, P); Border(obj, FALSE);
		Gadgets.Integrate(obj);
	END
END InsertGadget;

PROCEDURE Screen*;
	VAR
		P: Pictures.Picture;
		x, y: SIGNED32;
		r, g, b, i: SIGNED16;
BEGIN
	NEW(P); Pictures.Create(P, Display.Width, Display.Height, 8);
	FOR i := 0 TO 255 DO
		Display.GetColor(i, r, g, b);
		Pictures.SetColor(P, i, r, g, b)
	END;
	FOR x := 0 TO Display.Width-1 DO
		FOR y := 0 TO Display.Height-1 DO
			Pictures.Dot(P, SHORT(GetPixel(x, y)), SHORT(x), SHORT(y), Display.replace)
		END
	END;
	RembrandtDocs.OpenPict(P, "Snapshot.Pict")
END Screen;

PROCEDURE BankGetPixelPlane(x, y: SIGNED32): SIGNED32;	(* harry *)
VAR offset, mask, col: SIGNED32;  pg: SET;  byte: CHAR;
BEGIN
	offset := y*80 + (x DIV 8);	(* Setup the video page *)
	pg := SYSTEM.VAL(SET, offset DIV 10000H) * {0..3};
	pg := pg + LSH(pg, 4);
	Machine.Portout8(3CDH, CHR(SYSTEM.VAL(SIGNED32, pg)));
	offset := offset MOD 10000H;
	mask := LSH(80H, -(x MOD 8));
	Machine.Portout8(3CEH, 8X);	(* Select bit *)
	Machine.Portout8(3CFH, CHR(mask));
	col := 0;  INC(offset, base);
	Machine.Portout8(3CEH, 4X);	(* Select plane 0 *)
	Machine.Portout8(3CFH, 0X);
	SYSTEM.GET(offset, byte);
	IF SYSTEM.VAL(SET, byte) * SYSTEM.VAL(SET, mask) # {} THEN INC(col, 1) END;
	Machine.Portout8(3CEH, 4X);	(* Select plane 1 *)
	Machine.Portout8(3CFH, 1X);
	SYSTEM.GET(offset, byte);
	IF SYSTEM.VAL(SET, byte) * SYSTEM.VAL(SET, mask) # {} THEN INC(col, 2) END;
	Machine.Portout8(3CEH, 4X);	(* Select plane 2 *)
	Machine.Portout8(3CFH, 2X);
	SYSTEM.GET(offset, byte);
	IF SYSTEM.VAL(SET, byte) * SYSTEM.VAL(SET, mask) # {} THEN INC(col, 4) END;
	Machine.Portout8(3CEH, 4X);	(* Select plane 3 *)
	Machine.Portout8(3CFH, 3X);
	SYSTEM.GET(offset, byte);
	IF SYSTEM.VAL(SET, byte) * SYSTEM.VAL(SET, mask) # {} THEN INC(col, 8) END;
	RETURN col
END BankGetPixelPlane;

PROCEDURE BankGetPixel(x, y: SIGNED32): SIGNED32;	(* harry *)
VAR offset: SIGNED32;  byte: CHAR;  pg: SET;
BEGIN
	offset := y*Display.Width + x;
	pg := SYSTEM.VAL(SET, offset DIV 10000H) * {0..3};
	pg := pg + LSH(pg, 4);
	Machine.Portout8(3CDH, CHR(SYSTEM.VAL(SIGNED32, pg)));
	SYSTEM.GET(base + offset MOD 010000H, byte);
	RETURN ORD(byte)
END BankGetPixel;

PROCEDURE LinearGetPixel(x, y: SIGNED32): SIGNED32;
VAR ch: CHAR;
BEGIN
	SYSTEM.GET(base + (maxy-y) * Display.Width + x, ch);
	RETURN ORD(ch)
END LinearGetPixel;

PROCEDURE TransferGetPixel8(x, y: SIGNED32): SIGNED32;
VAR buf: ARRAY 4 OF CHAR;
BEGIN
	Display.TransferBlock(buf, 0, 0, x, y, 1, 1, Display.get);
	RETURN ORD(buf[0])
END TransferGetPixel8;

PROCEDURE TransferGetPixel(x, y: SIGNED32): SIGNED32;	(* very slow! *)
TYPE Arr4 = ARRAY 4 OF CHAR;
VAR col, r, g, b, r1, g1, b1, i, j, d, m: SIGNED32;
BEGIN
	Display.TransferBlock(SYSTEM.VAL(Arr4, col), 0, 0, x, y, 1, 1, Display.get);
	r := ASH(col, rs) MOD rm;
	g := ASH(col, gs) MOD gm;
	b := col MOD bm;
	m := MAX(SIGNED32);
	FOR i := 0 TO 255 DO
		r1 := pal[i].r - r;  g1 := pal[i].g - g;  b1 := pal[i].b - b;
		d := r1*r1 + g1*g1 + b1*b1;
		IF d < m THEN j := i;  m := d END
	END;
	RETURN j
END TransferGetPixel;

PROCEDURE Init;
VAR format: SIGNED32;
BEGIN
	rm := 256;  gm := 256;  bm := 256;
	maxy := Display.Height-1;
	GetPixel := NIL;
	format := Display.TransferFormat(0);
	IF format = Display.index8 THEN
		GetPixel := TransferGetPixel8
	ELSIF format # Display.unknown THEN
		CASE format OF
			|Display.color555: rm := 32;  gm := 32;  bm := 32;  rs := -10; gs := -5
			|Display.color565: rm := 32;  gm := 64;  bm := 32;  rs := -11;  gs := -5
			|Display.color664: rm := 64;  gm := 64;  bm := 16;  rs := -10;  gs := -4
			|Display.color888, Display.color8888: rm := 256;  gm := 256;  bm := 256;  rs := -16;  gs := -8
		END;
		GetPixel := TransferGetPixel
	ELSE
		base := Display.Map(0);
		IF (base > 0) & (base < 1000000H) THEN
			IF Display.Width = 640 THEN GetPixel := BankGetPixelPlane
	 	   ELSE GetPixel := BankGetPixel
	 	   END
		ELSIF base # 0 THEN
			GetPixel := LinearGetPixel
		ELSE
			(* skip *)
		END
	END
END Init;

BEGIN
	Init
END Snapshot.

Snapshot.Screen
Snapshot.Gadget *
