(* ETH Oberon, Copyright 2001 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

MODULE LeoFrames IN Oberon; (** portable **)	(* eos  *)

	(**
		Frames displaying Leonardo figures

		The frames in this module are passive, i.e. they don't provide any functionality for editing figures. Their main
		purpose is to serve as light-weight objects displaying embedded figures in texts, panels, and other containers.
		By linking a tool structure to a frame and exchanging its handler, a frame can be turned into a full-fledged
		figure editor at run time (see LeoTools)
	**)

	(*
		12.05.2000 - made Color() more careful in accepting positive values
	*)

	IMPORT
		Files, Display, Printer, Objects, Oberon, Display3, Printer3, Gadgets, Colors, GfxRegions, Gfx,
		GfxDisplay, GfxPrinter, Leonardo;


	TYPE
		(** figure frame **)
		Frame* = POINTER TO FrameDesc;
		FrameDesc* = RECORD (Gadgets.FrameDesc)
			ox*, oy*: SIGNED16;	(** vector from upper left corner of frame to figure origin in screen space **)
			scale*: FLOAT32;	(** viewport scale factor **)
			col*: Display.Color;	(** background color (unless transparent) **)
			framed*: BOOLEAN;	(** if true then a pseudo-3D border is drawn around the frame **)
		END;

		RegData = RECORD (GfxRegions.EnumData)
			reg: GfxRegions.Region;
			scale: FLOAT32;
			border: SIGNED16;
			dx, dy: SIGNED16;
		END;

		MaskData = RECORD (GfxRegions.EnumData)
			mask: Display3.Mask;
		END;


	VAR
		MaskReg, ScaleReg: GfxRegions.Region;
		DC: GfxDisplay.Context;
		PC: GfxPrinter.Context;


	(**--- Rendering Support ---**)

	PROCEDURE AddRegionRect (x, y, w, h: SIGNED16);
	BEGIN
		GfxRegions.AddRect(MaskReg, x, y, x + w, y + h)
	END AddRegionRect;

	(** convert mask to region **)
	PROCEDURE RegionFromMask* (mask: Display3.Mask): GfxRegions.Region;
	BEGIN
		GfxRegions.Clear(MaskReg);
		Display3.EnumRect(mask, mask.X, mask.Y, mask.W, mask.H, AddRegionRect);
		RETURN MaskReg
	END RegionFromMask;

	PROCEDURE AddScaledRect (llx, lly, urx, ury: SIGNED16; VAR data: GfxRegions.EnumData);
	BEGIN
		WITH data: RegData DO
			llx := SHORT(ENTIER(llx * data.scale)) - data.border;
			lly := SHORT(ENTIER(lly * data.scale)) - data.border;
			urx := -SHORT(ENTIER(- urx * data.scale)) + data.border;
			ury := -SHORT(ENTIER(- ury * data.scale)) + data.border;
			GfxRegions.AddRect(data.reg, llx + data.dx, lly + data.dy, urx + data.dx, ury + data.dy)
		END
	END AddScaledRect;

	(** convert region from figure space to frame space and clip to frame **)
	PROCEDURE ScaledRegion* (src: GfxRegions.Region; scale, border: FLOAT32; dx, dy: SIGNED16): GfxRegions.Region;
		VAR rdata: RegData;
	BEGIN
		rdata.border := -SHORT(ENTIER(-scale * border));
		IF rdata.border < Leonardo.border THEN rdata.border := Leonardo.border END;
		GfxRegions.Clear(ScaleReg);
		rdata.reg := ScaleReg; rdata.scale := scale; rdata.dx := dx; rdata.dy := dy;
		GfxRegions.Enumerate(src, src.llx, src.lly, src.urx, src.ury, AddScaledRect, rdata);
		RETURN ScaleReg
	END ScaledRegion;

	PROCEDURE AddMaskRect (llx, lly, urx, ury: SIGNED16; VAR data: GfxRegions.EnumData);
	BEGIN
		Display3.Add(data(MaskData).mask, llx, lly, urx - llx, ury - lly)
	END AddMaskRect;

	(** convert region to mask **)
	PROCEDURE MaskFromRegion* (reg: GfxRegions.Region): Display3.Mask;
		VAR data: MaskData;
	BEGIN
		NEW(data.mask); Display3.Open(data.mask);
		GfxRegions.Enumerate(reg, reg.llx, reg.lly, reg.urx, reg.ury, AddMaskRect, data);
		RETURN data.mask
	END MaskFromRegion;

	(** initialize and return display context for rendering into frame rectangle **)
	PROCEDURE DisplayContext* (frame: Frame; llx, lly, urx, ury: SIGNED16; clip: GfxRegions.Region): Gfx.Context;
		VAR col: Gfx.Color;
	BEGIN
		GfxDisplay.SetCoordinates(DC, llx + frame.ox, ury + frame.oy, 1);
		IF frame.framed THEN
			INC(llx); INC(lly); DEC(urx); DEC(ury)
		END;
		GfxRegions.IntersectRect(clip, llx, lly, urx, ury);
		GfxDisplay.SetClipRegion(DC, clip);
		Display.GetColor(frame.col, col.r, col.g, col.b);
		GfxDisplay.SetBGColor(DC, col);
		Gfx.Reset(DC);
		Gfx.Scale(DC, frame.scale, frame.scale);
		RETURN DC
	END DisplayContext;

	(** initialize and return printer context **)
	PROCEDURE PrinterContext* (frame: Frame; llx, lly, urx, ury: SIGNED16; clip: GfxRegions.Region): Gfx.Context;
		VAR pix: SIGNED16;
	BEGIN
		GfxPrinter.Init(PC);
		GfxPrinter.SetCoordinates(PC, llx + PC.scale * frame.ox, ury + PC.scale * frame.oy, PC.scale);
		IF frame.framed THEN
			pix := SHORT((Display.Unit + Printer.Unit DIV 2) DIV Printer.Unit);
			INC(llx, pix); INC(lly, pix); DEC(urx, pix); DEC(ury, pix)
		END;
		GfxRegions.IntersectRect(clip, llx, lly, urx, ury);
		GfxPrinter.SetClipRegion(PC, clip);
		Gfx.Reset(PC);
		Gfx.Scale(PC, frame.scale, frame.scale);
		RETURN PC
	END PrinterContext;

	(** return color value suitable for rendering on the display **)
	PROCEDURE Color* (frame: Frame): Display.Color;
		VAR r, g, b: SIGNED16;
	BEGIN
		IF (0 <= frame.col) & (frame.col < 256) OR (frame.col < 0) & Display.TrueColor(Display.ColLeft) THEN
			RETURN frame.col
		END;
		Display.GetColor(frame.col, r, g, b);
		RETURN Colors.Match(Colors.DisplayIndex, Colors.DisplayBits, r, g, b)
	END Color;


	(*--- Rendering ---*)

	PROCEDURE Restore (frame: Frame; x, y, w, h, fx, fy: SIGNED16; mask: Display3.Mask);
		VAR ctxt: Gfx.Context;
	BEGIN
		Oberon.RemoveMarks(fx + x, fy + y, w, h);
		IF ~(Gadgets.transparent IN frame.state) THEN
			Display3.ReplConst(mask, Color(frame), fx + x, fy + y, w, h, Display.replace)
		END;
		ctxt := DisplayContext(frame, fx, fy, fx + frame.W, fy + frame.H, RegionFromMask(mask));
		Leonardo.Render(frame.obj(Leonardo.Figure), Leonardo.passive, ctxt);
		IF frame.framed THEN
			Display3.Rect3D(mask, Display3.topC, Display3.bottomC, fx, fy, frame.W, frame.H, 1, Display.replace)
		END;
		IF Gadgets.selected IN frame.state THEN
			Display3.FillPattern(mask, Display3.white, Display3.selectpat, fx, fy, fx + x, fy + y, w, h, Display.paint)
		END
	END Restore;

	PROCEDURE Print (frame: Frame; VAR msg: Display.DisplayMsg);
		VAR mask: Display3.Mask; w, h: SIGNED16; ctxt: Gfx.Context;

		PROCEDURE pc (x: SIGNED32): SIGNED16;
		BEGIN
			RETURN SHORT((x * Display.Unit + Printer.Unit DIV 2) DIV Printer.Unit)
		END pc;

	BEGIN
		Gadgets.MakePrinterMask(frame, msg.x, msg.y, msg.dlink, mask);
		w := pc(frame.W); h := pc(frame.H);
		IF ~(Gadgets.transparent IN frame.state) THEN
			Printer3.ReplConst(mask, frame.col, msg.x, msg.y, w, h, Display.replace)
		END;
		ctxt := PrinterContext(frame, msg.x, msg.y, msg.x + w, msg.y + h, RegionFromMask(mask));
		Leonardo.Render(frame.obj(Leonardo.Figure), Leonardo.passive, ctxt);
		IF frame.framed THEN
			Display3.Rect3D(mask, Display3.topC, Display3.bottomC, msg.x, msg.y, w, h, pc(1), Display.replace)
		END;
		IF Gadgets.selected IN frame.state THEN
			Printer3.FillPattern(mask, Display3.white, Display3.selectpat, msg.x, msg.y, msg.x, msg.y, w, h, Display.paint)
		END
	END Print;


	(*--- Figure Updates ---*)

	PROCEDURE Update (frame: Frame; VAR msg: Leonardo.UpdateMsg);
		VAR
			bw, llx, lly, urx, ury, x, y, w, h: SIGNED16; dm: Display.DisplayMsg; clip: GfxRegions.Region; ctxt: Gfx.Context;
			mask: Display3.Mask;
	BEGIN
		IF msg.fig = frame.obj THEN	(* redisplay frame *)
			IF Gadgets.transparent IN frame.state THEN	(* parent has to restore background *)
				bw := -SHORT(ENTIER(-frame.scale * msg.bw));
				IF bw < Leonardo.border THEN bw := Leonardo.border END;
				llx := SHORT(ENTIER(msg.reg.llx * frame.scale)) - bw;
				lly := SHORT(ENTIER(msg.reg.lly * frame.scale)) - bw;
				urx := SHORT(ENTIER(msg.reg.urx * frame.scale)) + bw;
				ury := SHORT(ENTIER(msg.reg.ury * frame.scale)) + bw;
				GfxRegions.ClipRect(llx, lly, urx, ury, -frame.ox, -(frame.H + frame.oy), -frame.ox + frame.W, -frame.oy);
				IF (llx < urx) & (lly < ury) THEN
					(* I'd love to update only the affected area but TextGadgets0.RestoreChild updates the whole frame area
					dm.F := frame; dm.device := Display.screen; dm.id := Display.area;
					dm.u := frame.ox + llx; dm.v := frame.oy + lly - (-1); dm.w := urx - llx; dm.h := ury - lly
					*)
					dm.F := frame; dm.device := Display.screen; dm.id := Display.full;
					Display.Broadcast(dm)
				END
			ELSE	(* restore directly *)
				llx := msg.x + frame.X; lly := msg.y + frame.Y; urx := llx + frame.W; ury := lly + frame.H;
				clip := ScaledRegion(msg.reg, frame.scale, msg.bw, llx + frame.ox, ury + frame.oy);
				Gadgets.MakeMask(frame, llx, lly, msg.dlink, mask);
				GfxRegions.Intersect(clip, RegionFromMask(mask));
				ctxt := DisplayContext(frame, llx, lly, urx, ury, clip);
				mask := MaskFromRegion(clip);
				x := clip.llx; y := clip.lly; w := clip.urx - clip.llx; h := clip.ury - clip.lly;
				Oberon.RemoveMarks(x, y, w, h);
				Display3.ReplConst(mask, Color(frame), x, y, w, h, Display.replace);
				Leonardo.Render(frame.obj(Leonardo.Figure), Leonardo.passive, ctxt);
				IF Gadgets.selected IN frame.state THEN
					Display3.FillPattern(mask, Display3.white, Display3.selectpat, llx, lly, x, y, w, h, Display.paint)
				END
			END
		END
	END Update;


	(*--- Selection ---*)

	PROCEDURE Select (frame: Frame; VAR msg: Display.SelectMsg);
		VAR fig: Leonardo.Figure; sel: Leonardo.Shape;
	BEGIN
		IF msg.id = Display.get THEN
			fig := frame.obj(Leonardo.Figure);
			IF fig.seltime > msg.time THEN
				sel := Leonardo.Selection(fig);
				IF sel # NIL THEN
					msg.obj := sel; msg.time := fig.seltime; msg.sel := frame
				END
			END
		ELSE
			Gadgets.framehandle(frame, msg)
		END
	END Select;


	(**--- Frames ---**)

	(** handle frame attributes **)
	PROCEDURE HandleAttr* (frame: Frame; VAR msg: Objects.AttrMsg);
	BEGIN
		IF msg.id = Objects.enum THEN
			msg.Enum("Color"); msg.Enum("Scale"); msg.Enum("OriginX"); msg.Enum("OriginY");
			msg.Enum("Transparent"); msg.Enum("Framed");
			Gadgets.framehandle(frame, msg)
		ELSIF msg.id = Objects.get THEN
			IF msg.name = "Gen" THEN msg.class := Objects.String; msg.s := "LeoFrames.New"; msg.res := 0
			ELSIF msg.name = "Color" THEN msg.class := Objects.Int; msg.i := frame.col; msg.res := 0;
			ELSIF msg.name = "Scale" THEN msg.class := Objects.Real; msg.x := frame.scale; msg.res := 0
			ELSIF msg.name = "OriginX" THEN msg.class := Objects.Int; msg.i := frame.ox; msg.res := 0
			ELSIF msg.name = "OriginY" THEN msg.class := Objects.Int; msg.i := frame.oy; msg.res := 0
			ELSIF msg.name = "Transparent" THEN msg.class := Objects.Bool; msg.b := Gadgets.transparent IN frame.state; msg.res := 0
			ELSIF msg.name = "Framed" THEN msg.class := Objects.Bool; msg.b := frame.framed; msg.res := 0
			ELSE Gadgets.framehandle(frame, msg)
			END
		ELSIF msg.id = Objects.set THEN
			IF msg.name = "Color" THEN
				IF (msg.class = Objects.Int) & (msg.i < 256) THEN frame.col := msg.i; msg.res := 0 END
			ELSIF msg.name = "Scale" THEN
				IF msg.class = Objects.Int THEN frame.scale := msg.i; msg.res := 0
				ELSIF msg.class = Objects.Real THEN frame.scale := msg.x; msg.res := 0
				ELSIF msg.class = Objects.LongReal THEN frame.scale := SHORT(msg.y); msg.res := 0
				END
			ELSIF msg.name = "OriginX" THEN
				IF msg.class = Objects.Int THEN frame.ox := SHORT(msg.i); msg.res := 0 END
			ELSIF msg.name = "OriginY" THEN
				IF msg.class = Objects.Int THEN frame.oy := SHORT(msg.i); msg.res := 0 END
			ELSIF msg.name = "Transparent" THEN
				IF msg.class = Objects.Bool THEN
					IF msg.b THEN INCL(frame.state, Gadgets.transparent)
					ELSE EXCL(frame.state, Gadgets.transparent)
					END;
					msg.res := 0
				END
			ELSIF msg.name = "Framed" THEN
				IF msg.class = Objects.Bool THEN frame.framed := msg.b; msg.res := 0 END
			ELSE
				Gadgets.framehandle(frame, msg)
			END
		END
	END HandleAttr;

	(** copy frame fields **)
	PROCEDURE Copy* (VAR msg: Objects.CopyMsg; from, to: Frame);
	BEGIN
		Gadgets.CopyFrame(msg, from, to);
		to.ox := from.ox; to.oy := from.oy; to.scale := from.scale;
		to.col := from.col; to.framed := from.framed
	END Copy;

	(** frame handler **)
	PROCEDURE Handle* (obj: Objects.Object; VAR msg: Objects.ObjMsg);
		VAR frame, copy: Frame; fx, fy: SIGNED16; mask: Display3.Mask; ver: SIGNED32;
	BEGIN
		frame := obj(Frame);
		IF msg IS Display.FrameMsg THEN
			WITH msg: Display.FrameMsg DO
				IF (msg.F = NIL) OR (msg.F = frame) THEN
					IF msg IS Oberon.ControlMsg THEN
						WITH msg: Oberon.ControlMsg DO
							IF msg.id = Oberon.neutralize THEN
								Leonardo.ClearSelection(frame.obj(Leonardo.Figure))
							END;
							Gadgets.framehandle(frame, msg)
						END
					ELSIF msg IS Leonardo.UpdateMsg THEN
						Update(frame, msg(Leonardo.UpdateMsg))
					ELSIF msg IS Leonardo.BroadcastMsg THEN
						frame.obj.handle(frame.obj, msg)
					ELSIF msg IS Display.DisplayMsg THEN
						WITH msg: Display.DisplayMsg DO
							IF msg.device = Display.screen THEN
								fx := msg.x + frame.X; fy := msg.y + frame.Y;
								IF (msg.id = Display.full) OR (msg.F = NIL) THEN
									Gadgets.MakeMask(frame, fx, fy, msg.dlink, mask);
									Restore(frame, 0, 0, frame.W, frame.H, fx, fy, mask)
								ELSIF msg.id = Display.area THEN
									Gadgets.MakeMask(frame, fx, fy, msg.dlink, mask);
									Display3.AdjustMask(mask, fx + msg.u, fy + (frame.H-1) + msg.v, msg.w, msg.h);
									Restore(frame, msg.u, msg.v + frame.H - 1, msg.w, msg.h, fx, fy, mask)
								END;
							ELSIF msg.device = Display.printer THEN
								Print(frame, msg)
							END
						END
					ELSIF msg IS Display.ControlMsg THEN
						Gadgets.framehandle(frame, msg)
					ELSIF msg IS Display.SelectMsg THEN
						Select(frame, msg(Display.SelectMsg))
					ELSE
						Gadgets.framehandle(frame, msg)
					END
				END
			END
		ELSIF msg IS Objects.AttrMsg THEN
			HandleAttr(frame, msg(Objects.AttrMsg))
		ELSIF msg IS Objects.CopyMsg THEN
			WITH msg: Objects.CopyMsg DO
				IF msg.stamp # frame.stamp THEN
					NEW(copy); frame.dlink := copy; frame.stamp := msg.stamp;
					Copy(msg, frame, copy)
				END;
				msg.obj := frame.dlink
			END
		ELSIF msg IS Objects.FileMsg THEN
			WITH msg: Objects.FileMsg DO
				Gadgets.framehandle(frame, msg);
				IF msg.id = Objects.store THEN
					Files.WriteNum(msg.R, 1);
					Files.WriteInt(msg.R, frame.ox); Files.WriteInt(msg.R, frame.oy); Files.WriteReal(msg.R, frame.scale);
					Files.WriteNum(msg.R, frame.col); Files.WriteBool(msg.R, frame.framed)
				ELSIF msg.id = Objects.load THEN
					Files.ReadNum(msg.R, ver);
					Files.ReadInt(msg.R, frame.ox); Files.ReadInt(msg.R, frame.oy); Files.ReadReal(msg.R, frame.scale);
					Files.ReadNum(msg.R, frame.col); Files.ReadBool(msg.R, frame.framed)
				END
			END
		ELSE
			Gadgets.framehandle(frame, msg)
		END
	END Handle;

	(** initialize frame to default values **)
	PROCEDURE Init* (frame: Frame; fig: Leonardo.Figure);
	BEGIN
		frame.handle := Handle;
		frame.W := 100; frame.H := 100;
		frame.obj := fig; frame.state := {Gadgets.transparent};
		frame.ox := 0; frame.oy := 0; frame.scale := 1;
		frame.col := Display3.textbackC; frame.framed := FALSE
	END Init;

	(** frame generator **)
	PROCEDURE New*;
		VAR frame: Frame;
	BEGIN
		NEW(frame); Init(frame, NIL);
		Objects.NewObj := frame
	END New;


	(**--- Legacy Support ---**)

	PROCEDURE NewFrame*;
	BEGIN
		Objects.NewObj := Gadgets.CreateObject("LeoTools.NewLegacyFrame")
	END NewFrame;

	PROCEDURE ReadContainer (VAR r: Files.Rider; cont: Leonardo.Container);
		VAR ver: SIGNED32; i: SIGNED16; real: FLOAT32; obj: Objects.Object; cm: Objects.CopyMsg; s: Leonardo.Shape; bool: BOOLEAN;
	BEGIN
		(* shape part *)
		Files.ReadNum(r, ver);
		ASSERT(ver IN {1, 2}, 110);
		IF ver = 1 THEN
			Files.ReadInt(r, i); Files.ReadInt(r, i); Files.ReadInt(r, i); Files.ReadInt(r, i);
			Files.ReadReal(r, real)
		END;

		(* container part *)
		Files.ReadNum(r, ver);
		ASSERT(ver IN {1, 2}, 111);
		REPEAT
			Gadgets.ReadRef(r, cont.lib, obj)
		UNTIL (obj = NIL) OR (obj IS Leonardo.Shape);
		IF obj # NIL THEN
			Objects.Stamp(cm); cm.id := Objects.shallow; cm.obj := obj; obj.handle(obj, cm);
			s := cm.obj(Leonardo.Shape); s.cont := cont; cont.bottom := s; cont.top := s;
			Gadgets.ReadRef(r, cont.lib, obj);
			WHILE (obj # NIL) & (obj IS Leonardo.Shape) DO
				Objects.Stamp(cm); cm.id := Objects.shallow; cm.obj := obj; obj.handle(obj, cm);
				s := cm.obj(Leonardo.Shape); s.cont := cont; s.down := cont.top; cont.top.up := s; cont.top := s;
				Gadgets.ReadRef(r, cont.lib, obj)
			END
		END;
		Leonardo.GetComponentsBox(cont.bottom, cont.llx, cont.lly, cont.urx, cont.ury, cont.bw);
		IF ver = 1 THEN
			Files.ReadBool(r, bool)
		END
	END ReadContainer;

	PROCEDURE HandleLayer (obj: Objects.Object; VAR msg: Objects.ObjMsg);
	BEGIN
		IF msg IS Objects.FileMsg THEN
			WITH msg: Objects.FileMsg DO
				ASSERT(msg.id = Objects.load, 110);
				ReadContainer(msg.R, obj(Leonardo.Layer));
				obj.handle := Leonardo.HandleLayer
			END
		ELSE
			Leonardo.HandleLayer(obj, msg)
		END
	END HandleLayer;

	PROCEDURE NewLayer*;
		VAR layer: Leonardo.Layer;
	BEGIN
		NEW(layer); Leonardo.InitLayer(layer, "Main", TRUE, TRUE, TRUE); layer.handle := HandleLayer;
		Objects.NewObj := layer
	END NewLayer;


BEGIN
	NEW(MaskReg); GfxRegions.Init(MaskReg, GfxRegions.Winding);
	NEW(ScaleReg); GfxRegions.Init(ScaleReg, GfxRegions.Winding);
	NEW(DC); GfxDisplay.Init(DC, Display.ColLeft, Display.Bottom, Display.ColLeft + Display.Width, Display.Bottom + Display.Height);
	NEW(PC)
END LeoFrames.
