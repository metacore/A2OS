(* ETH Oberon, Copyright 2001 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

MODULE Graphs IN Oberon; (** portable *)

IMPORT Files, Display, Attributes, Display3, Objects, Gadgets, Oberon;

CONST
	BufSize = 360;
	ScaleFactor = 2.66;

TYPE
	Graph* = POINTER TO GraphDesc;
	GraphDesc* = RECORD (Gadgets.FrameDesc)
		col*: SIGNED16;
		beg*, end*: SIGNED16;
		x*: ARRAY BufSize OF FLOAT32;
		y*: ARRAY  BufSize OF FLOAT32
	END;

PROCEDURE GraphAttr(F: Graph; VAR M: Objects.AttrMsg);
BEGIN
	IF M.id = Objects.get THEN
		IF M.name = "Gen" THEN M.class := Objects.String; COPY("Graphs.NewGraph", M.s); M.res := 0
		ELSE Gadgets.framehandle(F, M)
		END
	ELSIF M.id = Objects.set THEN Gadgets.framehandle(F, M)
	ELSIF M.id = Objects.enum THEN Gadgets.framehandle(F, M)
	END
END GraphAttr;

PROCEDURE RestoreGraph(F: Graph; M: Display3.Mask; x, y, w, h: SIGNED16);
VAR i, p, q: SIGNED16;
BEGIN
	Display3.FilledRect3D(M, Display3.bottomC, Display3.topC, F.col, x, y, w, h, 1, Display.replace);

	p := x + w DIV 2; q := y + h DIV 2;
	i := F.beg;
	WHILE i # F.end DO
		Display3.Dot(M, Display3.FG,
			p + SHORT(ENTIER(F.x[i] * F.W / ScaleFactor + 0.5)),
			q + SHORT(ENTIER(F.y[i] * F.H / ScaleFactor + 0.5)), Display3.replace);
		i := (i + 1) MOD BufSize;
	END;

	IF Gadgets.selected IN F.state THEN
		Display3.FillPattern(M, Display3.white, Display3.selectpat, x, y, x, y, w, h, Display.paint)
	END
END RestoreGraph;

PROCEDURE CopyGraph*(VAR M: Objects.CopyMsg; from, to: Graph);
BEGIN
	to.col := from.col;
	Gadgets.CopyFrame(M, from, to);
END CopyGraph;

PROCEDURE GraphHandler*(F: Objects.Object; VAR M: Objects.ObjMsg);
VAR x, y, w, h, p, q: SIGNED16; F0: Graph; R: Display3.Mask;
	A: Objects.AttrMsg;
BEGIN
	WITH F: Graph DO
		IF M IS Display.FrameMsg THEN
			WITH M: Display.FrameMsg DO
				IF (M.F = NIL) OR (M.F = F) THEN	(* message addressed to this frame *)
					x := M.x + F.X; y := M.y + F.Y; w := F.W; h := F.H; (* calculate display coordinates *)
					IF M IS Display.DisplayMsg THEN
						WITH M: Display.DisplayMsg  DO
							IF M.device = Display.screen THEN
								IF (M.id = Display.full) OR (M.F = NIL) THEN
									Gadgets.MakeMask(F, x, y, M.dlink, R);
									RestoreGraph(F, R, x, y, w, h)
								ELSIF M.id = Display.area THEN
									Gadgets.MakeMask(F, x, y, M.dlink, R);
									Display3.AdjustMask(R, x + M.u, y + h - 1 + M.v, M.w, M.h);
									RestoreGraph(F, R, x, y, w, h)
								END
							ELSE
								Gadgets.framehandle(F, M)
							END
						END
					ELSIF M IS Gadgets.UpdateMsg THEN
						WITH M: Gadgets.UpdateMsg DO
							IF M.obj = F.obj THEN (* model has changed *)
								A.id := Objects.get; A.name := "Real"; F.obj.handle(F.obj, A); F.x[F.end] := A.x;
								A.id := Objects.get; A.name := "Imag"; F.obj.handle(F.obj, A); F.y[F.end] := A.x;

								(* Display new point added *)
								Gadgets.MakeMask(F, x, y, M.dlink, R);
								p := x + w DIV 2; q := y + h DIV 2;
								Display3.Dot(R, Display3.FG,
									p + SHORT(ENTIER(F.x[F.end] * F.W/ScaleFactor + 0.5)),
									q + SHORT(ENTIER(F.y[F.end] * F.H/ScaleFactor + 0.5)), Display3.replace);

								(* Increment buffer *)
								F.end := (F.end + 1) MOD BufSize;
								IF F.end = F.beg THEN F.beg := (F.beg + 1) MOD BufSize END
							ELSE Gadgets.framehandle(F, M) (* may be for this frame too *)
							END
						END
					ELSE Gadgets.framehandle(F, M)
					END
				END
			END

		(* Object messages *)
		ELSIF M IS Objects.AttrMsg THEN GraphAttr(F, M(Objects.AttrMsg))
		ELSIF M IS Objects.FileMsg THEN
			WITH M: Objects.FileMsg DO
				IF M.id = Objects.store THEN
					Files.WriteInt(M.R, F.col); Gadgets.framehandle(F, M)
				ELSIF M.id = Objects.load THEN
					Files.ReadInt(M.R, F.col); Gadgets.framehandle(F, M);
					IF F.col < 0 THEN F.col := Display3.textbackC END
				END
			END
		ELSIF M IS Objects.CopyMsg THEN
			WITH M: Objects.CopyMsg DO
				IF M.stamp = F.stamp THEN M.obj := F.dlink	(* copy msg arrives again *)
				ELSE	(* first time copy message arrives *)
					NEW(F0); F.stamp := M.stamp; F.dlink := F0; CopyGraph(M, F, F0); M.obj := F0
				END
			END
		ELSE	(* unknown msg, framehandler might know it *)
			Gadgets.framehandle(F, M)
		END
	END
END GraphHandler;

PROCEDURE NewGraph*;
VAR F: Graph;
BEGIN NEW(F); F.W := 200; F.H := 200;
	F.col := Display3.textbackC; F.beg := 0; F.end := 0;
	F.handle := GraphHandler; Objects.NewObj := F;
END NewGraph;

PROCEDURE Clear*;
VAR S: Attributes.Scanner; obj: Objects.Object;
BEGIN
	Attributes.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos);
	Attributes.Scan(S);
	IF S.class = Attributes.Name THEN
		obj := Gadgets.FindObj(Gadgets.context, S.s);
		IF (obj # NIL) & (obj IS Graph) THEN
			WITH obj: Graph DO
				obj.beg := 0; obj.end := 0; Gadgets.Update(obj)
			END
		END
	END
END Clear;

END Graphs.
