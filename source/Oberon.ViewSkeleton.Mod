(* ETH Oberon, Copyright 2001 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

MODULE ViewSkeleton IN Oberon;	(* jt, 13.12.94 *)
	IMPORT Display, Display3, Fonts, Gadgets, Oberon, Objects;

	TYPE
		Frame* = POINTER TO FrameDesc;
		FrameDesc* = RECORD (Gadgets.ViewDesc)
			(* view is adjusted to model size, no border *)
		END;

	PROCEDURE ToModel (F: Frame; x, y: SIGNED16; VAR M: Display.FrameMsg);
		VAR obj: Display.Frame;
	BEGIN
		IF (F.obj # NIL) & (F.obj IS Display.Frame) THEN
			obj := F.obj(Display.Frame);
			M.x := x - obj.X; M.y := y + F.H - (obj.Y + obj.H);
			Gadgets.Send(F, x, y, obj, M)
		END
	END ToModel;

	PROCEDURE Restore (F: Frame; x, y: SIGNED16; dlink: Objects.Object);
		VAR R: Display3.Mask; M: Display.DisplayMsg;
	BEGIN
		Gadgets.MakeMask(F, x, y, dlink, R);	(* simplified *)
		IF F.obj = NIL THEN
			Display3.ReplConst(R, Display3.green, x, y, F.W, F.H, Display.replace);
			Display3.String(R, Display3.FG, x + 3, y + 3, Fonts.Default,
								"empty view", Display3.textmode)
		ELSE
			M.device := Display.screen; M.id := Display.full; M.F := NIL;
			M.dlink := dlink; M.res := -1; ToModel(F, x, y, M)
		END ;
		IF Gadgets.selected IN F.state THEN
			Display3.FillPattern(R, Display3.blue, Display3.selectpat,
								x, y, x, y, F.W, F.H, Display3.paint)
		END
	END Restore;

	PROCEDURE Adjust (F: Frame; X, Y, W, H: SIGNED16);
		VAR MM: Display.ModifyMsg;
	BEGIN
		MM.F := F; MM.mode := Display.display;
		MM.dX := X - F.X; MM.dY := Y - F.Y; MM.dW := W - F.W; MM.dH := H - F.H;
		MM.X := X; MM.Y := Y; MM.W := W; MM.H := H;
		Display.Broadcast(MM)
	END Adjust;

	PROCEDURE Consume (F: Frame; x, y: SIGNED16; VAR M: Display.ConsumeMsg);
		VAR f: Objects.Object; CM: Display.ControlMsg;
	BEGIN f := M.obj;
		IF (M.id = Display.drop) & (M.F = F) & (F.obj = NIL) & (f IS Gadgets.Frame) THEN
			WITH f: Gadgets.Frame DO
				f.slink := NIL;
				CM.id := Display.remove; CM.F := f; Display.Broadcast(CM);
				F.obj := f; f.X := 0; f.Y := 0; f.mask := NIL;
				F.state := f.state*{Gadgets.transparent};
				Adjust(F, F.X + M.u, F.Y + F.H - 1 + M.v, f.W, f.H); M.res := 0
			END
		ELSE ToModel(F, x, y, M)
		END;
	END Consume;

	PROCEDURE UpdateMask (F: Frame; x, y: SIGNED16; VAR M: Display3.UpdateMaskMsg);
		VAR R: Display3.Mask; O: Display3.OverlapMsg;
	BEGIN
		IF M.F = F.obj THEN
			NEW(R); Display3.Open(R);
			Display3.Add(R, 0, -F.obj(Display.Frame).H+1,
								F.obj(Display.Frame).W, F.obj(Display.Frame).H);
			O.F := F.obj(Display.Frame); O.x := 0; O.y := 0; O.M := R; O.res := -1;
			O.dlink := NIL; ToModel(F, x, y, O); M.res := 0
		ELSIF M.F = F THEN
			NEW(F.mask); Display3.Open(F.mask);
			Display3.Add(F.mask, 0, -F.H+1, F.W, F.H);
			F.mask.x := 0; F.mask.y := 0
		ELSE ToModel(F, x, y, M)
		END
	END UpdateMask;

	PROCEDURE FrameHandler* (F: Objects.Object; VAR M: Objects.ObjMsg);
		VAR x, y, u, v: SIGNED16; F0: Frame;
	BEGIN
		WITH F: Frame DO
			IF M IS Objects.AttrMsg THEN
				WITH M: Objects.AttrMsg DO
					IF (M.id = Objects.get) & (M.name = "Gen") THEN
						M.s := "ViewSkeleton.NewFrame"; M.class := Objects.String; M.res := 0
					ELSE Gadgets.framehandle(F, M)
					END
				END
			ELSIF M IS Objects.CopyMsg THEN
				WITH M: Objects.CopyMsg DO
					IF M.stamp = F.stamp THEN M.obj := F.dlink
					ELSE
						NEW(F0); F.stamp := M.stamp; F.dlink := F0;
						Gadgets.CopyFrame(M, F, F0); F0.border := F.border; M.obj := F0
					END
				END
			ELSIF M IS Objects.FileMsg THEN Gadgets.framehandle(F, M)
			ELSIF M IS Objects.BindMsg THEN Gadgets.framehandle(F, M)
			ELSIF M IS Objects.LinkMsg THEN Gadgets.framehandle(F, M)
			ELSIF M IS Objects.FindMsg THEN Gadgets.framehandle(F, M)
			ELSIF M IS Display.FrameMsg THEN
				WITH M: Display.FrameMsg DO
					x := M.x + F.X; y := M.y + F.Y;
					u := M.x; v := M.y; (* save *)
					IF M IS Display.DisplayMsg THEN
						WITH M: Display.DisplayMsg DO
							IF M.device = Display.screen THEN
								IF (M.F = NIL) OR (M.F = F) THEN Restore(F, x, y, M.dlink)
								ELSE ToModel(F, x, y, M)
								END
							ELSIF M.device = Display.printer THEN
							END
						END
					ELSIF M IS Display.ConsumeMsg THEN
						Consume(F, x, y, M(Display.ConsumeMsg))
					ELSIF M IS Gadgets.UpdateMsg THEN
						WITH M: Gadgets.UpdateMsg DO
							IF M.obj = F.obj THEN Restore(F, x, y, M.dlink)
							ELSE ToModel(F, x, y, M)
							END
						END
					ELSIF M IS Oberon.InputMsg THEN
						WITH M: Oberon.InputMsg DO
							IF F.obj # NIL THEN ToModel(F, x, y, M)
							ELSE Gadgets.framehandle(F, M)
							END
						END
					ELSIF M IS Oberon.ControlMsg THEN ToModel(F, x, y, M)
					ELSIF M IS Display.LocateMsg THEN Gadgets.framehandle(F, M)
					ELSIF M IS Display.SelectMsg THEN
						Gadgets.framehandle(F, M) (* should be more elaborate *)
					ELSIF M IS Display.ModifyMsg THEN
						WITH M: Display.ModifyMsg DO
							IF M.F = F THEN Gadgets.framehandle(F, M)
							ELSIF M.F = F.obj THEN
								ToModel(F, x, y, M); Adjust(F, F.X + M.dX, F.Y + M.dY, M.W, M.H)
							ELSE ToModel(F, x, y, M)
							END
						END
					ELSIF M IS Display.ControlMsg THEN
						IF (M(Display.ControlMsg).id = Display.remove) & (M.F = F.obj) THEN
							F.obj := NIL; Gadgets.Update(F)
						END
					ELSIF M IS Display3.OverlapMsg THEN Gadgets.framehandle(F, M);
					ELSIF M IS Display3.UpdateMaskMsg THEN
						UpdateMask(F, x, y, M(Display3.UpdateMaskMsg))
					ELSE ToModel(F, x, y, M)
					END;
					M.x := u; M.y := v (* restore *)
				END
			ELSIF F.obj # NIL THEN F.obj.handle(F.obj, M)
			END
		END
	END FrameHandler;

	PROCEDURE InitFrame* (F: Frame);
	BEGIN F.W := 100; F.H := 100; F.border := 0; F.handle := FrameHandler
	END InitFrame;

	PROCEDURE NewFrame*;
		VAR F: Frame;
	BEGIN NEW(F); InitFrame(F); Objects.NewObj := F;
	END NewFrame;

END ViewSkeleton.

Gadgets.Insert ViewSkeleton.NewFrame ~

