(* ETH Oberon, Copyright 2001 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

MODULE Plotter IN Oberon;

IMPORT Display, Display3, Gadgets, Objects, BasicGadgets, Oberon;

CONST MaxPoints = 362;

TYPE
	Plotter = POINTER TO PlotterDesc;
	PlotterDesc = RECORD (Gadgets.FrameDesc)
		points: ARRAY MaxPoints OF SIGNED32;
		min, max: SIGNED32;
		end: SIGNED16
	END;

PROCEDURE Min(x, y: SIGNED32): SIGNED32;
BEGIN  IF x < y THEN RETURN x ELSE RETURN y END
END Min;

PROCEDURE Max(x, y: SIGNED32): SIGNED32;
BEGIN  IF x > y THEN RETURN x ELSE RETURN y END
END Max;

PROCEDURE DisplayPlotter(P: Plotter; X, Y, W, H: SIGNED16; VAR M: Display3.Mask);
VAR i, p : SIGNED16; range, min: SIGNED32;
BEGIN
	Display3.FilledRect3D(M, Display3.white, Display3.black, 12, X, Y, W, H, 1, Display.replace);
	range := P.max - P.min + 10; min := P.min - 5;
	IF range = 0 THEN range := 1 END;

	i := 0;
	WHILE i < P.end DO
		p := SHORT((P.points[i] - min) * (H - 4) DIV range);
		Display3.Dot(M, Display3.black, X + i + 1, Y + p + 2, Display.replace);
		INC(i);
	END;
	IF Gadgets.selected IN P.state THEN Display3.FillPattern(M, Display3.black, Display3.selectpat, X, Y, X, Y, W, H, Display.paint) END
END DisplayPlotter;

PROCEDURE Plot(P: Plotter; value: SIGNED32; X, Y, W, H: SIGNED16; VAR M: Display3.Mask);
VAR i, p, end : SIGNED16; oldrange, range, min: SIGNED32;
BEGIN
	oldrange := P.max - P.min + 10;
	IF oldrange = 0 THEN oldrange := 1 END;

	end := P.end;
	P.points[P.end] := value; P.end := (P.end + 1) MOD MaxPoints;
	IF P.end = 0 THEN (* overflow *)
		P.points[0] := value; P.end := 1;
		DisplayPlotter(P, X, Y, W, H, M);
		RETURN
	END;

	P.min := MAX(SIGNED32); P.max := MIN(SIGNED32);
	i := 0;
	WHILE i # P.end DO
		P.min := Min(P.min, P.points[i]); P.max := Max(P.max, P.points[i]);
		i := (i + 1) MOD MaxPoints
	END;
	range := P.max - P.min + 10; min := P.min - 5;
	IF range = 0 THEN range := 1 END;

	IF range # oldrange THEN DisplayPlotter(P, X, Y, W, H, M);
	ELSE p := SHORT((value - min) * (H - 4) DIV range);
		Display3.Dot(M, Display3.black, X + end + 1, Y + p + 2, Display.replace)
	END;
	IF Gadgets.selected IN P.state THEN Display3.FillPattern(M, Display3.black, Display3.selectpat, X, Y, X, Y, W, H, Display.paint) END
END Plot;

PROCEDURE PlotterHandler(P: Objects.Object; VAR M: Objects.ObjMsg);
VAR x, y, w, h: SIGNED16; P0: Plotter; R: Display3.Mask;
BEGIN
	WITH P: Plotter DO
		IF M IS Objects.AttrMsg THEN
			WITH M: Objects.AttrMsg DO
				IF (M.id = Objects.get) & (M.name = "Gen") THEN M.s := "Plotter.NewPlotter"; M.res := 0; M.class := Objects.String
				ELSE Gadgets.framehandle(P, M)
				END
			 END;
		ELSIF M IS Objects.CopyMsg THEN
			WITH M: Objects.CopyMsg DO
				IF M.stamp = P.stamp THEN M.obj := P.dlink	(* copy msg arrives again *)
				ELSE	(* first time copy message arrives *)
					NEW(P0); P.stamp := M.stamp; P.dlink := P0; Gadgets.CopyFrame(M, P, P0); M.obj := P0
				END
			END
		ELSIF M IS Display.FrameMsg THEN
			WITH M: Display.FrameMsg DO
				IF (M.F = NIL) OR (M.F = P) THEN	(* message addressed to this frame *)
					x := M.x + P.X; y := M.y + P.Y; w := P.W; h := P.H; (* calculate actual display coordinates *)
					IF M IS Display.DisplayMsg THEN
						WITH M: Display.DisplayMsg  DO
							IF M.device = Display.screen THEN
								IF (M.id = Display.full) OR (M.F = NIL) THEN
									Gadgets.MakeMask(P, x, y, M.dlink, R);
									DisplayPlotter(P, x, y, w, h, R);
								ELSIF M.id = Display.area THEN
									Gadgets.MakeMask(P, x, y, M.dlink, R);
									Display3.AdjustMask(R, x + M.u, y + h - 1 + M.v, M.w, M.h);
									DisplayPlotter(P, x, y, w, h, R);
								END
							ELSIF M.device = Display.printer THEN Gadgets.framehandle(P, M)
							END
						END;
					ELSIF  M IS Gadgets.UpdateMsg THEN
						WITH M: Gadgets.UpdateMsg  DO
							IF (M.obj = P.obj) & (M.obj IS BasicGadgets.Integer) THEN
								Gadgets.MakeMask(P, x, y, M.dlink, R);
								Plot(P, P.obj(BasicGadgets.Integer).val, x, y, w, h, R);
							END
						END
					ELSIF M IS Oberon.InputMsg THEN
						WITH M: Oberon.InputMsg DO
							Gadgets.framehandle(P, M)
						END
					ELSE Gadgets.framehandle(P, M)
					END
				ELSE Gadgets.framehandle(P, M)
				END
			END
		ELSE Gadgets.framehandle(P, M)
		END
	END
END PlotterHandler;

PROCEDURE NewPlotter*;
VAR P: Plotter;
BEGIN NEW(P); P.W := 130; P.H := 100; P.handle := PlotterHandler; Objects.NewObj := P
END NewPlotter;

END Plotter.

