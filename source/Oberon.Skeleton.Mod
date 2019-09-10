(* ETH Oberon, Copyright 2001 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

MODULE Skeleton IN Oberon (*JM/ JG 26.7.94*);

IMPORT Display, Display3, Effects, Files, Gadgets, Oberon, Objects, Printer, Printer3;

CONST red = 1; middle = 1;

TYPE
	Frame* = POINTER TO FrameDesc;
	FrameDesc* = RECORD (Gadgets.FrameDesc)
		col*: SIGNED16
	END;

(*
	To save memory we can use the framehandler to allocate the "Cmd" attribute
	only when one exists. We have however to simulate an attribute if
	none really exists (see the handling of "Cmd" in the "get" part below)
*)

PROCEDURE Attributes (F: Frame; VAR M: Objects.AttrMsg);
BEGIN
	IF M.id = Objects.get THEN
		IF M.name = "Gen" THEN
			M.class := Objects.String; COPY("Skeleton.New", M.s); M.res := 0
		ELSIF M.name = "Color" THEN
			M.class := Objects.Int; M.i := F.col; M.res := 0
		ELSIF M.name = "Cmd" THEN
			Gadgets.framehandle(F, M);
			IF M.res < 0 THEN (* no such attribute, simulate one *)
				M.class := Objects.String; M.s := ""; M.res := 0
			END
		ELSE Gadgets.framehandle(F, M)
		END
	ELSIF M.id = Objects.set THEN
		IF (M.name = "Color") & (M.class = Objects.Int) THEN
				F.col := SHORT(M.i); M.res := 0
		ELSE Gadgets.framehandle(F, M)
		END
	ELSIF M.id = Objects.enum THEN
		M.Enum("Color"); M.Enum("Cmd"); Gadgets.framehandle(F, M)
	END
END Attributes;

PROCEDURE Restore (F: Frame; Q: Display3.Mask; x, y, w, h: SIGNED16);
BEGIN
	Display3.ReplConst(Q, F.col, x, y, w, h, Display.replace);
	IF Gadgets.selected IN F.state THEN
		Display3.FillPattern(Q, Display3.white, Display3.selectpat,
			x, y, x, y, w, h, Display.paint)
	END
END Restore;

PROCEDURE Print (F: Frame; VAR M: Display.DisplayMsg);
	VAR Q: Display3.Mask;

	PROCEDURE P(x: SIGNED16): SIGNED16;
	BEGIN RETURN SHORT(x * Display.Unit DIV Printer.Unit)
	END P;

BEGIN
	Gadgets.MakePrinterMask(F, M.x, M.y, M.dlink, Q);
	Printer3.ReplConst(Q, F.col, M.x, M.y, P(F.W), P(F.H), Display.replace)
END Print;

PROCEDURE Copy* (VAR M: Objects.CopyMsg; from, to: Frame);
BEGIN to.col := from.col; Gadgets.CopyFrame(M, from, to)
END Copy;

PROCEDURE Handle* (F: Objects.Object; VAR M: Objects.ObjMsg);
	VAR x, y, w, h: SIGNED16; F1: Frame; Q: Display3.Mask; keysum: SET;
BEGIN
	WITH F: Frame DO
		IF M IS Display.FrameMsg THEN
			WITH M: Display.FrameMsg DO
				IF (M.F = NIL) OR (M.F = F) THEN (* message addressed to this frame *)
					x := M.x + F.X; y := M.y + F.Y; w := F.W; h := F.H;
					IF M IS Display.DisplayMsg THEN
						WITH M: Display.DisplayMsg DO
							IF M.device = Display.screen THEN
								IF (M.id = Display.full) OR (M.F = NIL) THEN
									Gadgets.MakeMask(F, x, y, M.dlink, Q);
									Restore(F, Q, x, y, w, h)
								ELSIF M.id = Display.area THEN
									Gadgets.MakeMask(F, x, y, M.dlink, Q);
									Display3.AdjustMask(Q, x + M.u, y + h - 1 + M.v, M.w, M.h);
									Restore(F, Q, x, y, w, h)
								END
							ELSIF M.device = Display.printer THEN Print(F, M)
							END
						END
					ELSIF M IS Oberon.InputMsg THEN
						WITH M: Oberon.InputMsg DO
							IF (M.id = Oberon.track) & Gadgets.InActiveArea(F, M) & (M.keys = {middle}) THEN
								Gadgets.MakeMask(F, x, y, M.dlink, Q);
								Oberon.RemoveMarks(x, y, w, h);
								Display3.ReplConst(Q, Display3.FG, x, y, w, h, Display.invert);
								keysum := M.keys;
								REPEAT
									Effects.TrackMouse(M.keys, M.X, M.Y, Effects.PointHand);
									keysum := keysum + M.keys
								UNTIL M.keys = {};
								Oberon.RemoveMarks(x, y, w, h);
								Display3.ReplConst(Q, Display3.FG, x, y, w, h, Display.invert);
								IF keysum = {middle} THEN
									Gadgets.ExecuteAttr(F, "Cmd", M.dlink, NIL, NIL)
								END;
								M.res := 0
							ELSE Gadgets.framehandle(F, M)
							END
						END
					ELSE Gadgets.framehandle(F, M)
					END
				END
			END
		ELSIF M IS Objects.AttrMsg THEN Attributes(F, M(Objects.AttrMsg))
		ELSIF M IS Objects.CopyMsg THEN
			WITH M: Objects.CopyMsg DO
				IF M.stamp = F.stamp THEN M.obj := F.dlink (*non-first arrival*)
				ELSE (*first arrival*)
					NEW(F1); F.stamp := M.stamp; F.dlink := F1;
					Copy(M, F, F1); M.obj := F1
				END
			END
		ELSIF M IS Objects.FileMsg THEN
			WITH M: Objects.FileMsg DO
				IF M.id = Objects.store THEN Files.WriteInt(M.R, F.col)
				ELSIF M.id = Objects.load THEN Files.ReadInt(M.R, F.col)
				END;
				Gadgets.framehandle(F, M)
			END
		ELSE Gadgets.framehandle(F, M)
		END
	END
END Handle;

PROCEDURE Init* (F: Frame);
BEGIN F.W := 50; F.H := 50; F.col := red; F.handle := Handle
END Init;

PROCEDURE New*;
VAR F: Frame;
BEGIN NEW(F); Init(F); Objects.NewObj := F
END New;

END Skeleton.

System.Free Skeleton ~
Gadgets.Insert Skeleton.New ~
