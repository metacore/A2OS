MODULE ErrorGadgets IN Oberon;	(**  AUTHOR "fof"; PURPOSE "";  **)

IMPORT Gadgets, Display3, Display, Objects, Printer, Fonts, Strings, Printer3, Texts, Oberon, Effects, Files;
TYPE
	ErrorGadget* = POINTER TO ErrorGadgetDesc;
	ErrorGadgetDesc* = RECORD (Gadgets.FrameDesc)
		errno*: SIGNED16;
		showstr: BOOLEAN;
		str*: ARRAY 64 OF CHAR;
	END;

VAR W: Texts.Writer;
	first: BOOLEAN;	(* first attempt to read Oberon.Text/OP2.Errors *)

CONST
	MaxErrors = 500;

(** Get the marked text *)
PROCEDURE GetText(VAR par: Display.Frame): Texts.Text;
BEGIN
	par := Oberon.MarkedFrame();
	RETURN Oberon.MarkedText()
END GetText;

(* ---------------- ErrorGadget -------------- *)

PROCEDURE ErrorGadgetAttr(F: ErrorGadget; VAR M: Objects.AttrMsg);
BEGIN
	IF M.id = Objects.get THEN
		IF M.name = "Gen" THEN M.class := Objects.String; COPY("ErrorGadgets.NewErrorGadget", M.s); M.res := 0
		ELSIF M.name = "LineupHY" THEN M.class := Objects.Int; M.i := ABS(Fonts.Default.minY) + 1; M.res := 0
		ELSE Gadgets.framehandle(F, M)
		END
	ELSIF M.id = Objects.set THEN
		Gadgets.framehandle(F, M);
	ELSIF M.id = Objects.enum THEN
		Gadgets.framehandle(F, M)
	END
END ErrorGadgetAttr;
PROCEDURE RestoreErrorGadget(F: ErrorGadget; M: Display3.Mask; x, y, w, h: SIGNED16);
VAR s: ARRAY 128 OF CHAR;
BEGIN
(*
	Display3.FilledRect3D(M, Display3.topC, Display3.bottomC, Display3.groupC, x, y, w, h, 1, Display.replace);
*)
	Display3.ReplConst(M, Display3.groupC, x, y, w, h, Display.replace);
	IF F.showstr THEN
		Display3.CenterString(M, Display.FG, x, y, w, h, Fonts.Default, F.str, Display.paint)
	ELSE
		Strings.IntToStr(ABS(F.errno), s);
		Display3.CenterString(M, Display.FG, x, y, w, h, Fonts.Default, s, Display3.textmode)
	END;
	IF Gadgets.selected IN F.state THEN
		Display3.FillPattern(M, Display3.white, Display3.selectpat, x, y, x, y, w, h, Display3.paint)
	END
END RestoreErrorGadget;

PROCEDURE PrintErrorGadget(F: ErrorGadget; VAR M: Display.DisplayMsg);
	VAR
		R: Display3.Mask; x, y, w, h: SIGNED16;
		s: ARRAY 32 OF CHAR;

	PROCEDURE P(x: SIGNED16): SIGNED16;
	BEGIN RETURN SHORT(x * Display.Unit DIV Printer.Unit)
	END P;

BEGIN
	Gadgets.MakePrinterMask(F, M.x, M.y, M.dlink, R);
	x := M.x; y := M.y; w := P(F.W); h := P(F.H);
	(* Printer3.ReplConst(R, Display3.groupC, x, y, w, h, Display.replace); *)
	Printer3.ReplConst(R, 1, x, y, w, h, Display.replace);
	Printer3.ReplConst(R, Display.BG, x+4, y+4, w+8, h+8, Display.replace);
	IF F.showstr THEN
		Printer3.CenterString(R,  Display.FG, x, y, w, h, Fonts.Default, F.str, Display3.textmode)
	ELSE
		Strings.IntToStr(ABS(F.errno), s);
		Display3.CenterString(R, Display.FG, x, y, w, h, Fonts.Default, s, Display3.textmode)
	END;
END PrintErrorGadget;

PROCEDURE CopyErrorGadget*(VAR M: Objects.CopyMsg; from, to: ErrorGadget);
BEGIN
	to.errno := from.errno;
	Gadgets.CopyFrame(M, from, to);
END CopyErrorGadget;

PROCEDURE FlipMsg(F: ErrorGadget);
VAR w, h, dsr: SIGNED16; A: Display.ModifyMsg;
BEGIN
	F.showstr := ~F.showstr;
	IF F.showstr  THEN
		Display3.StringSize(F.str, Fonts.Default, w, h, dsr);
		INC(w, 5)
	ELSE w := 20
	END;
	A.F := F; A.id := Display.extend; A.mode := Display.display;
	A.X := F.X; A.Y := F.Y; A.W := w; A.H := F.H;
	A.dX := 0; A.dY := 0; A.dW := A.W - F.W; A.dH := 0;
	Display.Broadcast(A)
END FlipMsg;


PROCEDURE ErrorGadgetHandler*(F: Objects.Object; VAR M: Objects.ObjMsg);
VAR x, y, w, h: SIGNED16; F0: ErrorGadget; R: Display3.Mask; keysum: SET;
BEGIN
	WITH F: ErrorGadget DO
		IF M IS Display.FrameMsg THEN
			WITH M: Display.FrameMsg DO
				IF (M.F = NIL) OR (M.F = F) THEN	(* message addressed to this frame *)
					x := M.x + F.X; y := M.y + F.Y; w := F.W; h := F.H; (* calculate display coordinates *)
					IF M IS Display.DisplayMsg THEN
						WITH M: Display.DisplayMsg  DO
							IF M.device = Display.screen THEN
								IF (M.id = Display.full) OR (M.F = NIL) THEN
									Gadgets.MakeMask(F, x, y, M.dlink, R);
									RestoreErrorGadget(F, R, x, y, w, h)
								ELSIF M.id = Display.area THEN
									Gadgets.MakeMask(F, x, y, M.dlink, R);
									Display3.AdjustMask(R, x + M.u, y + h - 1 + M.v, M.w, M.h);
									RestoreErrorGadget(F, R, x, y, w, h)
								END
							ELSIF M.device = Display.printer THEN PrintErrorGadget(F, M)
							END
						END
					ELSIF M IS Oberon.InputMsg THEN
						WITH M: Oberon.InputMsg DO
							IF (M.id = Oberon.track) & Gadgets.InActiveArea(F, M) & (M.keys = {1}) THEN
								Gadgets.MakeMask(F, x, y, M.dlink, R);
								Effects.TrackHighlight(R, keysum, M.X, M.Y, x, y, w, h);
								IF (keysum = {1}) & Effects.Inside(M.X, M.Y, x, y, w, h) THEN
									FlipMsg(F);
								END;
								M.res := 0
							ELSE Gadgets.framehandle(F, M)
							END
						END
					ELSE Gadgets.framehandle(F, M)
					END
				END
			END

		(* Object messages *)

		ELSIF M IS Objects.AttrMsg THEN ErrorGadgetAttr(F, M(Objects.AttrMsg))
		ELSIF M IS Objects.FileMsg THEN
			WITH M: Objects.FileMsg DO
				IF M.id = Objects.store THEN
					Files.WriteInt(M.R, F.errno);
					Files.WriteBool(M.R,F.showstr);
					Files.WriteString(M.R, F.str);
					Gadgets.framehandle(F, M)
				ELSIF M.id = Objects.load THEN
					Files.ReadInt(M.R, F.errno);
					Files.ReadBool(M.R,F.showstr);
					Files.ReadString(M.R, F.str);
					Gadgets.framehandle(F, M)
				END
			END
		ELSIF M IS Objects.CopyMsg THEN
			WITH M: Objects.CopyMsg DO
				IF M.stamp = F.stamp THEN M.obj := F.dlink	(* copy msg arrives again *)
				ELSE	(* first time copy message arrives *)
					NEW(F0); F.stamp := M.stamp; F.dlink := F0; CopyErrorGadget(M, F, F0); M.obj := F0
				END
			END
		ELSE	(* unknown msg, framehandler might know it *)
			Gadgets.framehandle(F, M)
		END
	END
END ErrorGadgetHandler;

PROCEDURE NewErrorGadget*;
VAR F: ErrorGadget;
BEGIN NEW(F); F.W := 20; F.H := 14; F.errno := 255;F.handle := ErrorGadgetHandler; Objects.NewObj := F
END NewErrorGadget;

PROCEDURE MarkErrorPos(T: Texts.Text; pos: SIGNED32; err: SIGNED16; str: ARRAY OF CHAR);
VAR obj: Objects.Object;
BEGIN
	NewErrorGadget; obj := Objects.NewObj; obj(ErrorGadget).errno := err; COPY(str,obj(ErrorGadget).str);
	Texts.WriteObj(W, obj);
	Texts.Insert(T, pos, W.buf)
END MarkErrorPos;

PROCEDURE RemoveErrors*(T: Texts.Text);
VAR first: SIGNED32; F: Texts.Finder; o: Objects.Object;
BEGIN
	first := -1;
	LOOP
		Texts.OpenFinder(F, T, 0);
		IF F.eot THEN EXIT END;
		first := F.pos;
		Texts.FindObj(F, o);
		LOOP
			IF F.eot THEN EXIT END;
			IF (o # NIL) & (o IS ErrorGadget) THEN EXIT
			ELSE
				first := F.pos;
				Texts.FindObj(F, o);
			END;
		END;
		IF F.eot THEN EXIT END;
		IF (o # NIL) & (o IS ErrorGadget) THEN
			Texts.Delete(T, first, first+1)
		END
	END
END RemoveErrors;

(*
	PROCEDURE Locate(F: Display.Frame;  T: Texts.Text;  pos: SIGNED32);
	VAR M: Oberon.CaretMsg;  N: Oberon.ControlMsg;
	BEGIN
		IF pos < 0 THEN pos := 0
		ELSIF pos > T.len THEN pos := T.len
		END;
		N.F := NIL; N.id := Oberon.neutralize; Display.Broadcast(N);
		Oberon.FadeCursor(Oberon.Pointer);
		M.id := Oberon.set; M.F := F; M.car := F; M.text := T; M.pos := pos; Display.Broadcast(M)
	END Locate;
*)

PROCEDURE markErrors*(VAR S: Texts.Scanner; errtext: Texts.Text; par: Display.Frame);
VAR c, err: SIGNED16; pos, beg, l,line, k: SIGNED32; C: Oberon.CaretMsg;  warn: BOOLEAN;
	marked: ARRAY MaxErrors OF SIGNED32;str: ARRAY 64 OF CHAR; R: Texts.Reader; ch: CHAR; i,endpos: SIGNED32; valid: BOOLEAN;
BEGIN
	WHILE (~S.eot) & ((S.class # Texts.Name) OR (S.s # "compiling"))  DO
		Texts.Scan(S);
	END;
	IF (S.class = Texts.Name) & (S.s = "compiling") THEN
		l := S.line; REPEAT Texts.Scan(S) UNTIL (S.line # l) OR S.eot
	END;
	c := 0; beg := -1; marked[0] := 0;
	WHILE (S.class = Texts.Name) & (S.s = "pos") & (c # MaxErrors) DO
		Texts.Scan(S); pos := S.i; Texts.Scan(S);
		IF (S.class = Texts.Name) & ((S.s="warning") OR (S.s="err")) THEN
			valid := TRUE;
			warn := (S.class = Texts.Name) & (S.s = "warning");
			Texts.Scan(S); err := SHORT(S.i);
			IF warn THEN err := -err END;
			l := 0;  WHILE (l # c) & (marked[l] < pos) DO INC(l) END;
			k := c;  WHILE k # l DO marked[k] := marked[k-1];  DEC (k) END;
			marked[l] := pos;
			IF beg < 0 THEN
				beg := pos+l
			END;
		ELSE
			valid := FALSE;
		END;
		line := S.line;
		R := S;
		REPEAT Texts.Scan(S) UNTIL S.eot OR (S.line # line);
		endpos := Texts.Pos(S);

		Texts.Read(R,ch); i := 0;
		WHILE(~R.eot) & (Texts.Pos(R)<endpos) & (ch#0DX) & (ch#0AX) & (i<63) DO
			str[i] := ch; Texts.Read(R,ch); INC(i);
		END;
		str[i] := 0X;
		IF valid THEN MarkErrorPos(errtext, pos + l, err,str); INC(c); END;
	END;
	IF (beg > 0) & (par # NIL) THEN
		C.id := Oberon.set; C.F := par; C.car := par; C.text := errtext; C.pos := beg;
		Display.Broadcast(C)
	END;
END markErrors;

PROCEDURE MarkErrors*;
VAR S: Texts.Scanner; par: Display.Frame; beg, end, time: SIGNED32;  T, errtext: Texts.Text;
BEGIN
	errtext := GetText(par);
	IF errtext # NIL THEN
		Texts.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos); Texts.Scan(S);
		IF (S.class = Texts.Char) & (S.c = "^") OR (S.line # 0) THEN
			Oberon.GetSelection(T, beg, end, time);
			IF time # -1 THEN Texts.OpenScanner(S, T, beg); Texts.Scan(S) END
		END;
		markErrors(S, errtext, par)
	END
END MarkErrors;

PROCEDURE ClearErrors*;
VAR T: Texts.Text; par: Display.Frame;
BEGIN
	T := GetText(par);
	IF T # NIL THEN RemoveErrors(T) END
END ClearErrors;

PROCEDURE ErrorAfter(T: Texts.Text; VAR pos: SIGNED32);
VAR F: Texts.Finder; o: Objects.Object; p: SIGNED32;
BEGIN
	Texts.OpenFinder(F, T, pos);
	p := F.pos; Texts.FindObj(F, o);
	WHILE (o # NIL) & (~(o IS ErrorGadget) OR (p <= pos)) DO p := F.pos; Texts.FindObj(F, o) END;
	IF (o # NIL) & (o IS ErrorGadget) THEN pos := p + 1 ELSE pos := -1 END;
END ErrorAfter;

PROCEDURE NextError*;
VAR M: Oberon.CaretMsg; pos: SIGNED32;
BEGIN
	M.F := NIL; M.id := Oberon.get; M.car := NIL; M.text := NIL; Display .Broadcast(M);
	IF (M.car # NIL) & (M.text # NIL) THEN
		pos := M.pos; ErrorAfter(M.text, pos);
		IF pos >= 0 THEN
			M.id := Oberon.set; M.F := M.car; M.pos := pos; Display. Broadcast(M)
		ELSE (* no more errors *)
			pos := 0; ErrorAfter(M.text, pos);
			IF pos >= 0 THEN
				M.id := Oberon.set; M.F := M.car; M.pos := pos; Display.Broadcast(M)
			ELSE Oberon.Defocus
			END
		END
	END
END NextError;

BEGIN
	first := TRUE;
	Texts.OpenWriter(W);
END ErrorGadgets.
