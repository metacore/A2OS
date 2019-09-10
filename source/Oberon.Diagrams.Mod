(* ETH Oberon, Copyright 2001 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

MODULE Diagrams IN Oberon; (*HM/JG 10.10.93*)

IMPORT Files, Display, Display3, Objects, Gadgets;

CONST margin = 1; black = 15;

TYPE
	Frame* = POINTER TO FrameDesc;
	FrameDesc* = RECORD (Gadgets.FrameDesc)
		col*: SIGNED16;
	END;

    UpdateMsg* = RECORD (Display.FrameMsg)
      n*: SIGNED16
    END;

PROCEDURE FrameAttr(F: Frame; VAR M: Objects.AttrMsg);
BEGIN
	IF M.id = Objects.get THEN
		IF M.name = "Gen" THEN
		  M.class := Objects.String; COPY("Diagrams.NewFrame", M.s); M.res := 0
		ELSE Gadgets.framehandle(F, M)
		END
	ELSIF M.id = Objects.set THEN Gadgets.framehandle(F, M)
	ELSIF M.id = Objects.enum THEN
		M.Enum("Value"); Gadgets.framehandle(F, M)
	END
END FrameAttr;

PROCEDURE RestoreFrame(F: Frame; M: Display3.Mask; x, y, w, h: SIGNED16);
BEGIN
	Display3.FilledRect3D(M, Display3.topC, Display3.bottomC, F.col, x, y, w, h, margin, Display.replace);
	IF Gadgets.selected IN F.state THEN
		Display3.FillPattern(M, Display3.white, Display3.selectpat, x, y, x, y, w, h, Display.paint)
	END
END RestoreFrame;

PROCEDURE UpdateDiagram(F: Frame; M: Display3.Mask; n, x, y, w, h: SIGNED16; VAR res: SIGNED16);
BEGIN
	IF Display3.Visible(M, x, y, w, h) THEN
      x := x + margin; y := y + margin; w := w - margin*2; h := h - margin*2;
      Display.CopyBlock (x + 2, y, w - 2, h, x, y, Display.replace);
      IF n*4 <= h THEN
        Display.ReplConst(black, x + w - 2, y, 1, n*4, Display.replace);
        Display.ReplConst(F.col, x + w - 2, y + n*4, 1, h - n*4, Display.replace);
        res := 0
      ELSE Display.ReplConst(black, x + w - 2, y, 1, h, Display.replace); res := 1
      END
    END
END UpdateDiagram;

PROCEDURE CopyFrame*(VAR M: Objects.CopyMsg; from, to: Frame);
BEGIN
	to.col := from.col;
	Gadgets.CopyFrame(M, from, to);
END CopyFrame;

PROCEDURE FrameHandler*(F: Objects.Object; VAR M: Objects.ObjMsg);
VAR x, y, w, h: SIGNED16; F0: Frame; R: Display3.Mask;
BEGIN
	WITH F: Frame DO
		IF M IS Display.FrameMsg THEN
			WITH M: Display.FrameMsg DO
				IF (M.F = NIL) OR (M.F = F) THEN	(* message addressed to this frame *)
					x := M.x + F.X; y := M.y + F.Y; w := F.W; h := F.H; (* calculate display coordinates *)
					IF M IS Display.DisplayMsg THEN
						WITH M: Display.DisplayMsg  DO
							IF M.device = Display.screen THEN
								IF (M.id = Display.full) OR (M.F = NIL) THEN
									Gadgets.MakeMask(F, x, y, M.dlink, R);
									RestoreFrame(F, R, x, y, w, h)
								ELSIF M.id = Display.area THEN
									Gadgets.MakeMask(F, x, y, M.dlink, R);
									Display3.AdjustMask(R, x + M.u, y + h - 1 + M.v, M.w, M.h);
									RestoreFrame(F, R, x, y, w, h)
								END
							ELSIF M.device = Display.printer THEN
							END
						END
  				  ELSIF M IS UpdateMsg THEN
  				    WITH M: UpdateMsg DO
  				      Gadgets.MakeMask(F, x, y, M.dlink, R);
  				      UpdateDiagram(F, R, M.n, x, y, w, h, M.res); M.res := -1;
  				    END
					ELSE Gadgets.framehandle(F, M)
					END
				ELSIF M IS UpdateMsg THEN
				    WITH M: UpdateMsg DO
				      Gadgets.MakeMask(F, x, y, M.dlink, R);
				      UpdateDiagram(F, R, M.n, x, y, w, h, M.res)
				    END
				END
			END

		(* Object messages *)

		ELSIF M IS Objects.AttrMsg THEN FrameAttr(F, M(Objects.AttrMsg))
		ELSIF M IS Objects.FileMsg THEN
			WITH M: Objects.FileMsg DO
				IF M.id = Objects.store THEN (* store private data here *)
					Files.WriteInt(M.R, F.col);
					Gadgets.framehandle(F, M)
				ELSIF M.id = Objects.load THEN (* load private data here *)
					Files.ReadInt(M.R, F.col);
					Gadgets.framehandle(F, M)
				END
			END
		ELSIF M IS Objects.CopyMsg THEN
			WITH M: Objects.CopyMsg DO
				IF M.stamp = F.stamp THEN M.obj := F.dlink	(* copy msg arrives again *)
				ELSE	(* first time copy message arrives *)
					NEW(F0); F.stamp := M.stamp; F.dlink := F0; CopyFrame(M, F, F0); M.obj := F0
				END
			END
		ELSE	(* unknown msg, framehandler might know it *)
			Gadgets.framehandle(F, M)
		END
	END
END FrameHandler;

PROCEDURE NewFrame*;
VAR F: Frame;
BEGIN NEW(F); F.W := 20; F.H := 20; F.col := 14; F.handle := FrameHandler;
  Objects.NewObj := F;
END NewFrame;

END Diagrams.

System.Free Simulator Diagrams ~
Gadgets.Insert Diagrams.NewFrame ~
My.Desk