(* ETH Oberon, Copyright 2001 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

(*
	Cups.Mod, jm 08.10.93

	Fun example of a coffee cup. Coffee can be poured from one cup
	to another by dropping one into another.
*)

MODULE Cups IN Oberon;

IMPORT Files, Display, Display3, Objects, Gadgets;

TYPE
	Cup* = POINTER TO CupDesc;
	CupDesc* = RECORD (Gadgets.FrameDesc)
		coffee*: SIGNED16;
	END;

PROCEDURE Size(F: Cup): SIGNED16;
BEGIN RETURN (F.W - 6) * (F.H - 6)
END Size;

PROCEDURE CupAttr(F: Cup; VAR M: Objects.AttrMsg);
BEGIN
	IF M.id = Objects.get THEN
		IF M.name = "Gen" THEN M.class := Objects.String; COPY("Cups.NewCup", M.s); M.res := 0
		ELSIF M.name = "Coffee" THEN M.class := Objects.Int; M.i := F.coffee; M.res := 0
		ELSE Gadgets.framehandle(F, M)
		END
	ELSIF M.id = Objects.set THEN
		IF M.name = "Coffee" THEN
			IF M.class = Objects.Int THEN
				F.coffee := SHORT(M.i);
				IF F.coffee > Size(F) THEN F.coffee := Size(F) END;
				M.res := 0
			END;
		ELSE Gadgets.framehandle(F, M);
		END
	ELSIF M.id = Objects.enum THEN
		M.Enum("Coffee"); Gadgets.framehandle(F, M)
	END
END CupAttr;

PROCEDURE RestoreCup(F: Cup; M: Display3.Mask; x, y, w, h: SIGNED16);
BEGIN
	Display3.ReplConst(M, Display.BG, x, y, w, h, Display.replace);
	Display3.ReplConst(M, Display3.blue, x, y, 2, h, Display.replace);
	Display3.ReplConst(M, Display3.blue, x, y, w, 2, Display.replace);
	Display3.ReplConst(M, Display3.blue, x + w - 2, y, 2, h, Display.replace);

	IF F.coffee > Size(F) THEN F.coffee := Size(F) END;

	Display3.ReplConst(M, Display3.FG, x + 3, y + 3, w - 6, F.coffee DIV (w - 6), Display.replace);
	IF Gadgets.selected IN F.state THEN Display3.FillPattern(M, Display3.white, Display3.selectpat, x, y, x, y, w, h, Display.paint) END
END RestoreCup;

PROCEDURE CopyCup*(VAR M: Objects.CopyMsg; from, to: Cup);
BEGIN to.coffee := from.coffee;
	Gadgets.CopyFrame(M, from, to);
END CopyCup;

PROCEDURE CupHandler*(F: Objects.Object; VAR M: Objects.ObjMsg);
VAR x, y, w, h: SIGNED16; F0: Cup; R: Display3.Mask; f: Cup; space, take: SIGNED16;
BEGIN
	WITH F: Cup DO
		IF M IS Display.FrameMsg THEN
			WITH M: Display.FrameMsg DO
				IF (M.F = NIL) OR (M.F = F) THEN	(* message addressed to this frame *)
					x := M.x + F.X; y := M.y + F.Y; w := F.W; h := F.H; (* calculate display coordinates *)
					IF M IS Display.DisplayMsg THEN
						WITH M: Display.DisplayMsg  DO
							IF M.device = Display.screen THEN
								IF (M.id = Display.full) OR (M.F = NIL) THEN
									Gadgets.MakeMask(F, x, y, M.dlink, R);
									RestoreCup(F, R, x, y, w, h)
								ELSIF M.id = Display.area THEN
									Gadgets.MakeMask(F, x, y, M.dlink, R);
									Display3.AdjustMask(R, x + M.u, y + h - 1 + M.v, M.w, M.h);
									RestoreCup(F, R, x, y, w, h)
								END
							ELSE
								Gadgets.framehandle(F, M)
							END
						END
					ELSIF M IS Display.ConsumeMsg THEN
						WITH M: Display.ConsumeMsg DO
							IF (M.id = Display.drop) & (M.obj IS Cup) THEN
								f := M.obj(Cup);
								space := Size(F) - F.coffee;
								IF f.coffee < space THEN take := f.coffee
								ELSE take := space
								END;
								F.coffee := F.coffee + take; f.coffee := f.coffee - take;
								Gadgets.Update(F); Gadgets.Update(f);
								M.res := 0
							END
						END
					ELSE Gadgets.framehandle(F, M)
					END
				END
			END

		(* Object messages *)
		ELSIF M IS Objects.AttrMsg THEN CupAttr(F, M(Objects.AttrMsg))
		ELSIF M IS Objects.FileMsg THEN
			WITH M: Objects.FileMsg DO
				IF M.id = Objects.store THEN
					Files.WriteInt(M.R, F.coffee);
					Gadgets.framehandle(F, M)
				ELSIF M.id = Objects.load THEN
					Files.ReadInt(M.R, F.coffee);
					Gadgets.framehandle(F, M)
				END
			END
		ELSIF M IS Objects.CopyMsg THEN
			WITH M: Objects.CopyMsg DO
				IF M.stamp = F.stamp THEN M.obj := F.dlink	(* copy msg arrives again *)
				ELSE (* first time copy message arrives *)
					NEW(F0); F.stamp := M.stamp; F.dlink := F0; CopyCup(M, F, F0); M.obj := F0
				END
			END
		ELSE	(* unknown msg, framehandler might know it *)
			Gadgets.framehandle(F, M)
		END
	END
END CupHandler;

PROCEDURE NewCup*;
VAR F: Cup;
BEGIN NEW(F); F.W := 30; F.H := 30; F.coffee := Size(F); F.handle := CupHandler; Objects.NewObj := F;
END NewCup;

END Cups.

System.Free Cups ~
Gadgets.Insert Cups.NewCup ~