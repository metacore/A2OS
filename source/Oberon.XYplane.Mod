(* ETH Oberon, Copyright 2001 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

MODULE XYplane IN Oberon;	(** portable *)
(** virtual screen consiting of W x H pixels *)

IMPORT Objects, Display, MenuViewers, Oberon, TextFrames, Input;

CONST
	SetSize = 32;
	closed = 0;  displayed = 2;
	black = Display.FG; white = Display.BG;
	erase* = 0;  draw* = 1; (** values for parameter mode in Dot *)

TYPE
	XYframe = POINTER TO XYframeDesc;
	XYframeDesc = RECORD (Display.FrameDesc) END;

VAR
	F: XYframe;  V: MenuViewers.Viewer;
	bitmap: POINTER TO ARRAY OF SET;
	max: SIGNED32;
	W*, H*: SIGNED16;	(** size of virtual screen in pixel *)

PROCEDURE Modify(F: XYframe; VAR M: Display.ModifyMsg);
VAR i, j: SIGNED32; x, y: SIGNED16;
BEGIN
	IF M.id = Display.extend THEN
		Display.CopyBlock(F.X, F.Y, F.W, F.H, F.X, F.Y + M.dY, Display.replace);
		Display.ReplConst(black, F.X, M.Y, F.W, M.H-F.H, Display.replace);

		i := LONG(H - M.H)*W DIV SetSize; j := LONG(H - F.H)*W DIV SetSize;
		y := M.Y;
		WHILE i < j DO
			x := 0;
			WHILE x < F.W DO
				IF (x MOD SetSize) IN bitmap[i + x DIV SetSize] THEN
					Display.Dot(white, F.X+x, y, Display.replace)
				END;
				INC(x)
			END;
			i := i + (W DIV SetSize); INC(y)
		END
	ELSIF (M.id = Display.reduce) & (M.dY > 0) THEN
		Display.CopyBlock(F.X, F.Y + M.dY, F.W, M.H, F.X, M.Y, Display.replace)
	END
END Modify;

PROCEDURE XYhandle*(F: Objects.Object; VAR M: Objects.ObjMsg);
BEGIN
	WITH F: XYframe DO
		IF M IS Oberon.InputMsg THEN
			WITH M: Oberon.InputMsg DO
				IF M.id = Oberon.track THEN
					Oberon.DrawCursor(Oberon.Mouse, Oberon.Arrow, M.X, M.Y);
				END
			END
		ELSIF M IS Display.ModifyMsg THEN
			WITH M: Display.ModifyMsg DO
				Modify(F, M)
			END
		END
	END
END XYhandle;

PROCEDURE Clear*;
VAR j: SIGNED32;
BEGIN
	Display.ReplConst(black, F.X, F.Y, F.W, F.H, Display.replace);
	j := 0;  WHILE j < max DO  bitmap[j] := {}; INC(j) END
END Clear;

PROCEDURE Open*;
VAR menuF: TextFrames.Frame; X, Y: SIGNED16;
BEGIN
	IF V.state # displayed THEN
		(* Oberon.OpenTrack(Oberon.Pointer.X, 0); *)
		Oberon.AllocateUserViewer(Oberon.Pointer.X, X, Y);
		menuF := TextFrames.NewMenu("XY Plane", "System.Close");
		NEW(F);  F.handle := XYhandle;
		V := MenuViewers.New(menuF, F, TextFrames.menuH, X, Y)
	END;
	Clear
END Open;

PROCEDURE Dot*(x, y, mode: SIGNED16);
VAR k, i, j: SIGNED32;
BEGIN
	IF (x >= 0) & (x < W) & (y >= 0) & (y < H) THEN
		k := LONG(y)*W + x; i := k DIV SetSize; j := k MOD SetSize;
		INC(y, F.Y + F.H - H);
		CASE mode OF
			  erase: EXCL(bitmap[i], j); IF (x < F.W) & (y >= F.Y) THEN Display.Dot(black, F.X+x, y, Display.replace) END
			|draw: INCL(bitmap[i], j); IF (x < F.W) & (y >= F.Y) THEN Display.Dot(white, F.X+x, y, Display.replace) END
		END
	END
END Dot;

PROCEDURE IsDot*(x, y: SIGNED16): BOOLEAN;
VAR k, i, j: SIGNED32;
BEGIN
	IF (x >= 0) & (x < W) & (y >= 0) & (y < H) THEN
		k := LONG(y)*W + x; i := k DIV SetSize; j := k MOD SetSize;
		RETURN j IN bitmap[i]
	ELSE RETURN FALSE
	END
END IsDot;

PROCEDURE Key*(): CHAR;
VAR ch: CHAR;
BEGIN ch := 0X;
	IF Input.Available() > 0 THEN  Input.Read(ch)  END;
	RETURN ch
END Key;

BEGIN
	W := Display.Width; W := W + 32 - (W MOD 32);
	H := Display.Height; H := H + 32 - (H MOD 32);
	max := LONG(W)*LONG(H) DIV 32;
	NEW(bitmap, max);
	NEW(F);  F.H := 0;  NEW(V);  V.state := closed
END XYplane.
