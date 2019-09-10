(* ETH Oberon, Copyright 2001 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

MODULE BartSimpson IN Oberon; (** portable *)	(* Markus Dätwyler, 1996 *)

IMPORT Out, Objects, Display, Input, Gadgets, Oberon, Modules, Pictures, Math IN A2, Display3, Printer, Printer3;

CONST
	LEyeX = 16.5; REyeX = 23.5;
	LEyeY = 16.5; REyeY = 16.5;
	EyeR = 1.5;
	BartW = 34; BartH = 34;

TYPE
	MouseCoord* = POINTER TO MouseCoordDesc;
	MouseCoordDesc* = RECORD (Gadgets.ObjDesc)
		x, y: SIGNED16;
	END;

	Frame* = POINTER TO FrameDesc;
	FrameDesc* = RECORD(Gadgets.FrameDesc)
		oldLX, oldLY, oldRX, oldRY: SIGNED16;
		col: SIGNED16
	END;

	MoveMsg* = RECORD (Display.FrameMsg)
	END;

VAR
	task: Oberon.Task;		(* mouse controller *)
	mouse: MouseCoord;	(* the model *)
	bart: Pictures.Picture;	(* bart simpson picture *)
	keys: SET;
	oldX, oldY: SIGNED16;

PROCEDURE MouseSpy(me: Oberon.Task);
VAR U: Gadgets.UpdateMsg;
BEGIN
	Input.Mouse(keys, mouse.x, mouse.y);
	IF (mouse.x # oldX) OR (mouse.y # oldY) THEN
		oldX:= mouse.x; oldY:= mouse.y;
		(* infrom all views about position change of mouse *)
		U.F:= NIL; U.obj:= mouse; Objects.Stamp(U); U.res:= -1;
		Display.Broadcast(U)
	END;
	me.time := Oberon.Time() + Input.TimeUnit DIV 10	(* 100 ms *)
END MouseSpy;

PROCEDURE MouseAttr(F: MouseCoord; VAR M: Objects.AttrMsg);
BEGIN
	IF M.id = Objects.get THEN
		IF M.name = "Gen" THEN M.class:= Objects.String; COPY("BartSimpson.NewMouse", M.s); M.res:= 0
		ELSIF M.name = "MouseX" THEN M.class:= Objects.Int; M.i:= F.x; M.res:= 0
		ELSIF M.name = "MouseY" THEN M.class:= Objects.Int; M.i:= F.y; M.res:= 0
		ELSE Gadgets.objecthandle(F, M)
		END
	ELSIF M.id = Objects.set THEN
		Gadgets.objecthandle(F, M)
	ELSIF M.id = Objects.enum THEN
		M.Enum("MouseX"); M.Enum("MouseY"); Gadgets.objecthandle(F, M)
	END
END MouseAttr;

PROCEDURE MouseHandler*(F: Objects.Object; VAR M: Objects.ObjMsg);
BEGIN
	WITH F: MouseCoord DO
		IF M IS Objects.AttrMsg THEN
			MouseAttr(F, M(Objects.AttrMsg))
		ELSIF M IS Objects.CopyMsg THEN
			WITH M: Objects.CopyMsg DO
				IF M.stamp = F.stamp THEN	(* we already got this message *)
					M.obj:= mouse
				ELSE
					F.stamp:= M.stamp;
					M.obj:= mouse
				END
			END
		ELSIF M  IS Objects.FileMsg THEN
			WITH M: Objects.FileMsg DO
				IF M.id = Objects.store THEN
					Gadgets.objecthandle(F, M)
				ELSIF M.id = Objects.load THEN
					Gadgets.objecthandle(F, M);
					Input.Mouse(keys, mouse.x, mouse.y)
				END
			END
		ELSE
			Gadgets.objecthandle(F, M)
		END
	END
END MouseHandler;

PROCEDURE FrameAttr(F: Frame; VAR M: Objects.AttrMsg);
(* handles Objects.AttrMsg. Each object has to set at least the Gen attribute *)
BEGIN
	IF M.id = Objects.get THEN
		IF M.name = "Gen" THEN M.class:= Objects.String; COPY("BartSimpson.NewBart", M.s); M.res:= 0
		ELSE Gadgets.framehandle(F, M)
		END
	ELSIF M.id = Objects.set THEN
		Gadgets.framehandle(F, M);
	ELSIF M.id = Objects.enum THEN
		Gadgets.framehandle(F, M)
	END
END FrameAttr;

PROCEDURE DrawEyes(F: Frame; M: Display3.Mask; x, y: SIGNED16);
VAR A: Objects.AttrMsg; mx, my, py, px: SIGNED32; r, dx, dy, rp: FLOAT32;
BEGIN
	IF F.oldLX > 0 THEN
		Display3.ReplConst(M, Display3.BG, F.oldLX, F.oldLY, 2, 2, Display.replace);
		Display3.ReplConst(M, Display3.BG, F.oldRX, F.oldRY, 2, 2, Display.replace)
	END;
	A.id:= Objects.get; A.name:= "MouseX"; A.res:= -1; F.obj.handle(F.obj, A); mx:= SHORT(A.i);
	A.id:= Objects.get; A.name:= "MouseY"; A.res:= -1; F.obj.handle(F.obj, A); my:= SHORT(A.i);
	dx:= mx - LEyeX - x; dy:= my - LEyeY - y;
	r:= Math.sqrt(dx*dx + dy*dy);
	IF r > EyeR THEN rp:= EyeR ELSE rp:= r END;
	py:= SHORT(ENTIER(dy * rp / r)) + y + (ENTIER(LEyeY)); px:= (ENTIER(dx * rp / r)) + x + (ENTIER(LEyeX));
	Display3.ReplConst(M, Display3.FG, SHORT(px), SHORT(py), 2, 2, Display.replace);
	F.oldLX:= SHORT(px); F.oldLY:= SHORT(py);
	dx:= mx - REyeX - x; dy:= (my - REyeY - y);
	r:= Math.sqrt(dx*dx + dy*dy);
	IF r > EyeR THEN rp:= EyeR ELSE rp:= r END;
	py:= SHORT(ENTIER(dy * rp / r)) + y + (ENTIER(REyeY)); px:= (ENTIER(dx * rp / r)) + x + (ENTIER(REyeX));
	Display3.ReplConst(M, Display3.FG, SHORT(px), SHORT(py), 2, 2, Display.replace);
	F.oldRX:= SHORT(px); F.oldRY:= SHORT(py);
END DrawEyes;

PROCEDURE RestoreFrame(F: Frame; M: Display3.Mask; x, y, w, h: SIGNED16);
(* handles a redraw of the whole view *)
BEGIN
	Oberon.RemoveMarks(x, y, w, h);
	IF (F.obj # NIL) & (F.obj IS MouseCoord) THEN
		Display3.FilledRect3D(M, Display3.topC, Display3.bottomC, Display3.groupC, x, y, w, h, 1, Display.replace);
		(*Display3.EnumRect(M, fx, fy, w-2, h-2, DisplayBart);*)
		Display3.Pict(M, bart, 0, 0, bart.width, bart.height, x, y, Display.replace);
		F.oldLX:= -1;
		DrawEyes(F, M, x, y)
	END;
	IF Gadgets.selected IN F.state THEN
		Display3.FillPattern(M, Display3.white, Display3.selectpat, x, y, x, y, w, h, Display.paint)
	END
END RestoreFrame;

PROCEDURE CopyFrame*(VAR M: Objects.CopyMsg; from, to: Frame);
BEGIN
	Gadgets.CopyFrame(M, from, to);
END CopyFrame;

PROCEDURE Print(F: Frame; VAR M: Display.DisplayMsg);
VAR R: Display3.Mask;

	PROCEDURE P(x: SIGNED16): SIGNED16;
	BEGIN RETURN SHORT(x * Display.Unit DIV Printer.Unit)
	END P;

BEGIN
	Gadgets.MakePrinterMask(F, M.x, M.y, M.dlink, R);
	Printer3.Pict(R, bart, M.x, M.y, P(F.W), P(F.H), Display.replace);
END Print;

PROCEDURE FrameHandler*(F: Objects.Object; VAR M: Objects.ObjMsg);
VAR x, y, w, h: SIGNED16; R: Display3.Mask; F0: Frame;
BEGIN
	WITH F: Frame DO
		IF M IS Display.FrameMsg THEN
			WITH M: Display.FrameMsg DO
				IF (M.F = NIL) OR (M.F = F) THEN	(* message relevant for this frame *)
					x:= M.x + F.X; y:= M.y + F.Y; w:= F.W; h:= F.H;
					IF M IS Gadgets.UpdateMsg THEN
						WITH M: Gadgets.UpdateMsg DO
							IF (F.obj # NIL) & (M.obj = F.obj) THEN
								Gadgets.MakeMask(F, x, y, M.dlink, R);
								F.col := (F.col + 1) MOD 16;
								Oberon.RemoveMarks(x, y, w, h);
								DrawEyes(F, R, x, y)
							END
						END
					ELSIF M IS Display.DisplayMsg THEN
						WITH M: Display.DisplayMsg DO
							IF M.device = Display.screen THEN
								IF (M.id = Display.full) OR (M.F = NIL) THEN
									Gadgets.MakeMask(F, x, y, M.dlink, R);
									RestoreFrame(F, R, x, y, w, h)
								ELSIF M.id = Display.area THEN
									Gadgets.MakeMask(F, x, y, M.dlink, R);
									Display3.AdjustMask(R, x + M.u, y + h - 1 + M.v, M.w, M.h);
									RestoreFrame(F, R, x, y, w, h)
								END
							ELSIF M.device = Display.printer THEN Print(F, M)
							END
						END	(* WITH *)
					ELSIF M IS Oberon.InputMsg THEN
						Gadgets.framehandle(F, M)
					ELSE
						Gadgets.framehandle(F, M)
					END	(* IF *)
				END	(* IF *)
			END	(* WITH *)

		(* Object messages *)
		ELSIF M IS Objects.AttrMsg THEN
			FrameAttr(F, M(Objects.AttrMsg))
		ELSIF M IS Objects.CopyMsg THEN
			WITH M: Objects.CopyMsg DO
				IF M.stamp = F.stamp THEN M.obj:= F.dlink	(* copy msg arrives again *)
				ELSE	(* first time copy message arrives *)
					NEW(F0); F.stamp:= M.stamp; F.dlink:= F0; CopyFrame(M, F, F0); M.obj:= F0
				END
			END
		ELSE
			Gadgets.framehandle(F, M)
		END
	END
END FrameHandler;

PROCEDURE NewMouse*;
BEGIN
	Objects.NewObj:= mouse
END NewMouse;

PROCEDURE NewBart*;
VAR F: Frame;
BEGIN
	NEW(F);
	F.W:= BartW; F.H:= BartH; F.state:= {Gadgets.lockedsize};
	F.handle:= FrameHandler;
	Objects.NewObj:= F
END NewBart;

PROCEDURE Deinstall*;
BEGIN
	Oberon.Remove(task);
	Out.String("MouseSpy removed !"); Out.Ln;
END Deinstall;

BEGIN
	Out.String("BartSimpson by Mad 1994"); Out.Ln;

	NEW(bart); IF bart = NIL THEN HALT(99) END;
	Pictures.Open(bart, "Bart.Pict", TRUE);
	IF bart.width # 32 THEN HALT(99) END;

	NEW(mouse); IF mouse = NIL THEN HALT(99) END;
	Input.Mouse(keys, mouse.x, mouse.y);
	oldX:= mouse.x; oldY:= mouse.y;
	mouse.handle:= MouseHandler;

	NEW(task); IF task = NIL THEN HALT(99) END;
	task.safe:= FALSE; task.time := Oberon.Time();
	task.handle:= MouseSpy;
	Oberon.Install(task);
	Modules.InstallTermHandler(Deinstall)
END BartSimpson.


BartSimpson.Deinstall
System.Free BartSimpson Pictures3~

Desktops.OpenDoc MouseCoord.Doc~
MouseCoord.Doc
Gadgets.Insert BartSimpson.NewBart  BartSimpson.NewMouse~
Gadgets.Link BartSimpson.NewMouse~