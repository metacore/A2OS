(* ETH Oberon, Copyright 2001 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

MODULE LeoTools IN Oberon; (** portable **)	(* eos  *)

	(**
		Tool objects and tool handles for turning Leonardo frames into figure editors
	**)

	(*
		17.05.2000 - fixed invalid rotations in CalcMatrix (found by ejz)
	*)

	IMPORT
		Files, Math IN A2, Objects, Display, Fonts, Printer, Input, Oberon, Pictures, Strings, Attributes, Links, Display3, Printer3,
		Effects, Gadgets, Colors, Images, GfxMatrix, GfxImages, GfxPaths, GfxRegions, GfxFonts, Gfx, GfxPrinter, GfxBuffer,
		Leonardo, LeoFrames;


	CONST
		inch* = 91.44; cm* = inch/2.54;	(** standard units in global figure units **)
		A4W* = 21*cm; A4H* = 29.7*cm;
		LetterW* = 8.5*inch; LetterH* = 11*inch;

		RulerW = 32; RulerH = 19; InfoH = 16; AuxH = RulerH + InfoH;
		ML = 2; MM = 1; MR = 0;

		translate = 0; scale = 1; rotate = 2; shear = 3; mirror = 4; aux = 5;	(* focus styles *)


	TYPE
		(** tool object **)
		Tool* = POINTER TO ToolDesc;
		ToolDesc* = RECORD (Gadgets.ObjDesc)
			frame*: LeoFrames.Frame;	(** frame that the tool objects is linked to **)
			unit*: FLOAT32;	(** current unit of measurement (in figure coordinates) **)
			zx*, zy*: FLOAT32;	(** vector from figure origin to ruler zero point (in figure coordinates) **)
			pageW*, pageH*: FLOAT32;	(** page size in figure coordinates **)
			buffered*: BOOLEAN;	(** true if rendering goes into bitmap first **)
			grid*: RECORD
				ticks*: SIGNED16;	(** number of ticks per unit **)
				visible*: BOOLEAN;	(** true if grid is visible **)
				active*: BOOLEAN;	(** true if automatic alignment to grid points is active **)
			END;
			hints*: RECORD
				visible*: BOOLEAN;	(** true if hint lines are currently visible **)
				incontents*: BOOLEAN;	(** true if hint lines cover content area **)
				x*, y*: SIGNED16;	(** coordinates relative to frame origin **)
			END
		END;

		(** message requesting all visible Leonardo frames to exchange their handler **)
		ToolMsg* = RECORD (Display.FrameMsg)
			handle*: Objects.Handler;	(** new handler **)
		END;

		(* special context for simplified rendering in invert mode *)
		Context* = POINTER TO ContextDesc;
		ContextDesc* = RECORD (Gfx.ContextDesc)
			orgX, orgY: FLOAT32;	(* origin of default coordinate system *)
			scale: FLOAT32;	(* default coordinate system scale factor *)
			cx, cy, cw, ch: SIGNED16;	(* clip rectangle *)
			u, v, u0, v0: FLOAT32;
			px, py: SIGNED16;
			deferred: BOOLEAN;
		END;

		PathData = RECORD (GfxPaths.EnumData)
			context: Context;
		END;


	VAR
		DC*: Context;	(** context for dragging graphics around **)
		Tolerance*: Objects.Object;	(** tolerance when locating shapes at mouse position **)
		AlignAxes*: Objects.Object;	(** number of axes to align to **)
		ToolHandler*: Objects.Handler;	(** current frame handler **)

		Methods: Gfx.Methods;

		Unit, PageWidth, PageHeight, GridTicks, GridVisible, GridActive, Buffered: Objects.Object;	(* public objects *)

		Focus*: RECORD
			frame*: LeoFrames.Frame;	(* frame displaying focus *)
			style*: SIGNED16;	(* one of translate, scale, rotate, shear, mirror *)
			points*: SIGNED16;	(* number of focus points *)
			x*, y*: ARRAY 2 OF FLOAT32;	(* focus point coordinates *)
			visible*: BOOLEAN;	(* true if focus is displayed *)
		END;
		Pat: ARRAY 6 OF Display.Pattern;

		BC: GfxBuffer.Context;	(* render buffer *)
		Font: Fonts.Font;	(* font for ruler and feedback info *)
		Pict: Pictures.Picture;	(* character picture *)


	(**--- Drag Contexts ---**)

	PROCEDURE ResetCTM (ctxt: Gfx.Context);
		VAR dc: Context;
	BEGIN
		dc := ctxt(Context);
		GfxMatrix.Translate(GfxMatrix.Identity, dc.orgX, dc.orgY, dc.ctm);
		GfxMatrix.Scale(dc.ctm, dc.scale, dc.scale, dc.ctm)
	END ResetCTM;

	PROCEDURE ResetClip (ctxt: Gfx.Context);
	END ResetClip;

	PROCEDURE GetClipRect (ctxt: Gfx.Context; VAR llx, lly, urx, ury: FLOAT32);
		VAR dc: Context; inv: GfxMatrix.Matrix;
	BEGIN
		dc := ctxt(Context);
		GfxMatrix.Invert(dc.ctm, inv);
		GfxMatrix.ApplyToRect(inv, dc.cx, dc.cy, dc.cx + dc.cw, dc.cy + dc.ch, llx, lly, urx, ury)
	END GetClipRect;

	PROCEDURE GetClip (ctxt: Gfx.Context): Gfx.ClipArea;
	BEGIN
		RETURN NIL
	END GetClip;

	PROCEDURE SetClip (ctxt: Gfx.Context; clip: Gfx.ClipArea);
	BEGIN
		ASSERT(clip = NIL, 100)
	END SetClip;

	PROCEDURE EnterLine (dc: Context; u, v: FLOAT32; draw: BOOLEAN);
	BEGIN
		dc.px := SHORT(ENTIER(u)); dc.py := SHORT(ENTIER(v));
		IF draw & (dc.cx <= dc.px) & (dc.px < dc.cx + dc.cw) & (dc.cy <= dc.py) & (dc.py < dc.cy + dc.ch) THEN
			Display.Dot(Display3.invertC, dc.px, dc.py, Display.invert)
		END;
		dc.u := u; dc.v := v
	END EnterLine;

	PROCEDURE DrawLine (dc: Context; u, v: FLOAT32);
		VAR cx, cy, cw, ch, px, py, xstep, ystep, steps: SIGNED16; du, dv, eu, ev, e: FLOAT32;
	BEGIN
		Display.GetClip(cx, cy, cw, ch);
		Display.SetClip(dc.cx, dc.cy, dc.cw, dc.ch);
		px := SHORT(ENTIER(u)); py := SHORT(ENTIER(v));
		IF px = dc.px THEN
			IF py > dc.py THEN
				Display.ReplConst(Display3.invertC, px, dc.py+1, 1, py - dc.py, Display.invert)
			ELSIF py < dc.py THEN
				Display.ReplConst(Display3.invertC, px, py, 1, dc.py - py, Display.invert)
			END;
			dc.py := py
		ELSIF py = dc.py THEN
			IF px > dc.px THEN
				Display.ReplConst(Display3.invertC, dc.px+1, py, px - dc.px, 1, Display.invert)
			ELSE
				Display.ReplConst(Display3.invertC, px, py, dc.px - px, 1, Display.invert)
			END;
			dc.px := px
		ELSE
			du := u - dc.u; dv := v - dc.v;
			IF du >= 0 THEN
				xstep := 1; eu := dc.u - (dc.px + 0.5)
			ELSE
				xstep := -1; du := -du; eu := dc.px + 0.5 - dc.u
			END;
			IF dv >= 0 THEN
				ystep := 1; ev := dc.v - (dc.py + 0.5)
			ELSE
				ystep := -1; dv := -dv; ev := dc.py + 0.5 - dc.v
			END;
			IF du >= dv THEN
				e := du * ev - dv * eu + dv - 0.5*du;
				steps := ABS(px - dc.px);
				WHILE steps > 0 DO
					IF (e >= 0) & ((e > 0) OR (ystep <= 0)) THEN
						INC(dc.py, ystep);
						e := e - du
					END;
					INC(dc.px, xstep);
					e := e + dv;
					Display.Dot(Display3.invertC, dc.px, dc.py, Display.invert);
					DEC(steps)
				END
			ELSE
				e := dv * eu - du * ev + du - 0.5*dv;
				steps := ABS(py - dc.py);
				WHILE steps > 0 DO
					IF (e >= 0) & ((e > 0) OR (xstep <= 0)) THEN
						INC(dc.px, xstep);
						e := e - dv
					END;
					INC(dc.py, ystep);
					e := e + du;
					Display.Dot(Display3.invertC, dc.px, dc.py, Display.invert);
					DEC(steps)
				END
			END
		END;
		dc.u := u; dc.v := v;
		Display.SetClip(cx, cy, cw, ch)
	END DrawLine;

	PROCEDURE StrokePathElem (VAR data: GfxPaths.EnumData);
		VAR dc: Context;
	BEGIN
		dc := data(PathData).context;
		CASE data.elem OF
		| GfxPaths.Enter: EnterLine(dc, data.x, data.y, (data.dx = 0) & (data.dy = 0))
		| GfxPaths.Line: DrawLine(dc, data.x, data.y)
		ELSE
		END
	END StrokePathElem;

	PROCEDURE Begin (ctxt: Gfx.Context; mode: SET);
	BEGIN
		ctxt.mode := mode;
		ctxt.cam := ctxt.ctm;	(* preserve current transformation for attributes *)
		IF Gfx.Record IN ctxt.mode THEN
			IF ctxt.path = NIL THEN NEW(ctxt.path) END;
			GfxPaths.Clear(ctxt.path)
		END;
		ctxt(Context).deferred := FALSE
	END Begin;

	PROCEDURE End (ctxt: Gfx.Context);
	END End;

	PROCEDURE Enter (ctxt: Gfx.Context; x, y, dx, dy: FLOAT32);
		VAR dc: Context; du, dv: FLOAT32;
	BEGIN
		dc := ctxt(Context);
		GfxMatrix.Apply(dc.ctm, x, y, dc.u, dc.v);
		IF Gfx.Record IN dc.mode THEN
			GfxMatrix.ApplyToVector(dc.ctm, dx, dy, du, dv);
			GfxPaths.AddEnter(dc.path, dc.u, dc.v, du, dv)
		END;
		IF dc.mode * {Gfx.Stroke, Gfx.Fill} # {} THEN
			EnterLine(dc, dc.u, dc.v, (dx = 0) & (dy = 0))
		END;
		IF (dx = 0) & (dy = 0) THEN
			dc.deferred := TRUE;
			dc.u0 := dc.u; dc.v0 := dc.v
		END;
		dc.cpx := x; dc.cpy := y
	END Enter;

	PROCEDURE Exit (ctxt: Gfx.Context; dx, dy: FLOAT32);
		VAR du, dv: FLOAT32;
	BEGIN
		IF Gfx.Record IN ctxt.mode THEN
			GfxMatrix.ApplyToVector(ctxt.ctm, dx, dy, du, dv);
			GfxPaths.AddExit(ctxt.path, du, dv)
		END;
		ctxt(Context).deferred := FALSE
	END Exit;

	PROCEDURE Close (ctxt: Gfx.Context);
		CONST eps = 0.001;
		VAR dc: Context;
	BEGIN
		dc := ctxt(Context);
		IF ~dc.deferred THEN
			Exit(dc, 0, 0)
		ELSE
			IF Gfx.Record IN ctxt.mode THEN
				IF (ABS(dc.u - dc.u0) > eps) OR (ABS(dc.v - dc.v0) > eps) THEN
					GfxPaths.AddLine(dc.path, dc.u0, dc.v0)
				END;
				GfxPaths.AddExit(dc.path, 0, 0);
				GfxPaths.Close(dc.path)
			END;
			dc.deferred := FALSE
		END
	END Close;

	PROCEDURE LineTo (ctxt: Gfx.Context; x, y: FLOAT32);
		VAR dc: Context; u, v: FLOAT32;
	BEGIN
		dc := ctxt(Context);
		GfxMatrix.Apply(dc.ctm, x, y, u, v);
		IF Gfx.Record IN dc.mode THEN
			GfxPaths.AddLine(dc.path, u, v)
		END;
		IF dc.mode * {Gfx.Stroke, Gfx.Fill} # {} THEN
			DrawLine(dc, u, v)
		END;
		dc.cpx := x; dc.cpy := y
	END LineTo;

	PROCEDURE ArcTo (ctxt: Gfx.Context; x, y, x0, y0, x1, y1, x2, y2: FLOAT32);
		VAR dc: Context; u, v, u0, v0, u1, v1, u2, v2: FLOAT32; data: PathData;
	BEGIN
		dc := ctxt(Context);
		GfxMatrix.Apply(dc.ctm, x, y, u, v);
		GfxMatrix.Apply(dc.ctm, x0, y0, u0, v0);
		GfxMatrix.Apply(dc.ctm, x1, y1, u1, v1);
		GfxMatrix.Apply(dc.ctm, x2, y2, u2, v2);
		IF Gfx.Record IN dc.mode THEN
			GfxPaths.AddArc(dc.path, u, v, u0, v0, u1, v1, u2, v2)
		END;
		IF dc.mode * {Gfx.Stroke, Gfx.Fill} # {} THEN
			data.context := dc; data.x := dc.u; data.y := dc.v;
			GfxPaths.EnumArc(u0, v0, u1, v1, u2, v2, u, v, 1, StrokePathElem, data)
		END;
		dc.cpx := x; dc.cpy := y
	END ArcTo;

	PROCEDURE BezierTo (ctxt: Gfx.Context; x, y, x1, y1, x2, y2: FLOAT32);
		VAR dc: Context; u, v, u1, v1, u2, v2: FLOAT32; data: PathData;
	BEGIN
		dc := ctxt(Context);
		GfxMatrix.Apply(dc.ctm, x, y, u, v);
		GfxMatrix.Apply(dc.ctm, x1, y1, u1, v1);
		GfxMatrix.Apply(dc.ctm, x2, y2, u2, v2);
		IF Gfx.Record IN dc.mode THEN
			GfxPaths.AddBezier(dc.path, u, v, u1, v1, u2, v2)
		END;
		IF dc.mode * {Gfx.Stroke, Gfx.Fill} # {} THEN
			data.context := dc; data.x := dc.u; data.y := dc.v;
			GfxPaths.EnumBezier(u1, v1, u2, v2, u, v, 1, StrokePathElem, data)
		END;
		dc.cpx := x; dc.cpy := y
	END BezierTo;

	PROCEDURE Show (ctxt: Gfx.Context; x, y: FLOAT32; VAR str: ARRAY OF CHAR);
		VAR font: GfxFonts.Font; dx, dy: FLOAT32;
	BEGIN
		font := ctxt.font;
		GfxFonts.GetStringWidth(font, str, dx, dy);
		Enter(ctxt, x, y + font.ymin, 0, 0);
		LineTo(ctxt, x, y + font.ymax); LineTo(ctxt, x + dx, y + dy + font.ymax);
		LineTo(ctxt, x + dx, y + dy + font.ymin); LineTo(ctxt, x, y + font.ymin);
		Exit(ctxt, 0, 0)
	END Show;

	PROCEDURE Render (ctxt: Gfx.Context; mode: SET);
		VAR data: PathData;
	BEGIN
		IF mode * {Gfx.Fill, Gfx.Stroke} # {} THEN
			ctxt.cam := ctxt.ctm;
			data.context := ctxt(Context);
			GfxPaths.EnumFlattened(ctxt.path, ctxt.flatness, StrokePathElem, data)
		END
	END Render;

	PROCEDURE Image (ctxt: Gfx.Context; x, y: FLOAT32; img: GfxImages.Image; VAR filter: GfxImages.Filter);
	BEGIN
		Gfx.DrawRect(ctxt, x, y, x + img.width, y + img.height, {Gfx.Stroke})
	END Image;

	PROCEDURE InitMethods;
		VAR do: Gfx.Methods;
	BEGIN
		NEW(do);
		Methods := do;
		do.reset := Gfx.DefResetContext;
		do.resetCTM := ResetCTM; do.setCTM := Gfx.DefSetCTM; do.translate := Gfx.DefTranslate;
		do.scale := Gfx.DefScale; do.rotate := Gfx.DefRotate; do.concat := Gfx.DefConcat;
		do.resetClip := ResetClip; do.getClipRect := GetClipRect; do.getClip := GetClip; do.setClip := SetClip;
		do.setStrokeColor := Gfx.DefSetStrokeColor; do.setStrokePattern := Gfx.DefSetStrokePattern;
		do.setFillColor := Gfx.DefSetFillColor; do.setFillPattern := Gfx.DefSetFillPattern;
		do.setLineWidth := Gfx.DefSetLineWidth; do.setDashPattern := Gfx.DefSetDashPattern;
		do.setCapStyle := Gfx.DefSetCapStyle; do.setJoinStyle := Gfx.DefSetJoinStyle;
		do.setStyleLimit := Gfx.DefSetStyleLimit; do.setFlatness := Gfx.DefSetFlatness;
		do.setFont := Gfx.DefSetFont; do.getWidth := Gfx.DefGetStringWidth;
		do.begin := Begin; do.end := End;
		do.enter := Enter; do.exit := Exit; do.close := Close;
		do.line := LineTo; do.arc := ArcTo; do.bezier := BezierTo; do.show := Show;
		do.flatten := Gfx.DefFlatten; do.outline := Gfx.DefOutline; do.render := Render;
		do.rect := Gfx.DefRect; do.ellipse := Gfx.DefEllipse;
		do.image := Image; do.newPattern := Gfx.DefNewPattern;
	END InitMethods;

	(** reset drag context **)
	PROCEDURE Reset* (frame: LeoFrames.Frame; fx, fy: SIGNED16);
	BEGIN
		DC.orgX := fx + RulerW + frame.ox; DC.orgY := fy + frame.H - RulerH + frame.oy; DC.scale := frame.scale;
		DC.cx := fx + RulerW; DC.cy := fy + InfoH; DC.cw := frame.W - RulerW; DC.ch := frame.H - AuxH;
		DC.do.reset(DC)
	END Reset;


	(**--- Tools ---**)

	PROCEDURE Copy* (VAR msg: Objects.CopyMsg; from, to: Tool);
	BEGIN
		Gadgets.CopyObject(msg, from, to);
		to.unit := from.unit; to.zx := from.zx; to.zy := from.zy;
		to.pageW := from.pageW; to.pageH := from.pageH;
		to.buffered := from.buffered;
		to.grid.ticks := from.grid.ticks; to.grid.visible := from.grid.visible; to.grid.active := from.grid.active
	END Copy;

	(** tool handler **)
	PROCEDURE Handle* (obj: Objects.Object; VAR msg: Objects.ObjMsg);
		VAR tool, copy: Tool; ver: SIGNED32;
	BEGIN
		tool := obj(Tool);
		IF msg IS Objects.AttrMsg THEN
			WITH msg: Objects.AttrMsg DO
				IF msg.id = Objects.enum THEN
					msg.Enum("Unit"); msg.Enum("OriginX"); msg.Enum("OriginY");
					msg.Enum("Width"); msg.Enum("Height");
					msg.Enum("Buffered");
					msg.Enum("GridTicks"); msg.Enum("GridVisible"); msg.Enum("GridActive");
					Gadgets.objecthandle(tool, msg)
				ELSIF msg.id = Objects.get THEN
					IF msg.name = "Gen" THEN msg.class := Objects.String; msg.s := "LeoTools.New"; msg.res := 0
					ELSIF msg.name = "Unit" THEN msg.class := Objects.Real; msg.x := tool.unit; msg.res := 0
					ELSIF msg.name = "OriginX" THEN msg.class := Objects.Real; msg.x := tool.zx; msg.res := 0
					ELSIF msg.name = "OriginY" THEN msg.class := Objects.Real; msg.x := tool.zy; msg.res := 0
					ELSIF msg.name = "Width" THEN msg.class := Objects.Real; msg.x := tool.pageW; msg.res := 0
					ELSIF msg.name = "Height" THEN msg.class := Objects.Real; msg.x := tool.pageH; msg.res := 0
					ELSIF msg.name = "Buffered" THEN msg.class := Objects.Bool; msg.b := tool.buffered; msg.res := 0
					ELSIF msg.name = "GridTicks" THEN msg.class := Objects.Int; msg.i := tool.grid.ticks; msg.res := 0
					ELSIF msg.name = "GridVisible" THEN msg.class := Objects.Bool; msg.b := tool.grid.visible; msg.res := 0
					ELSIF msg.name = "GridActive" THEN msg.class := Objects.Bool; msg.b := tool.grid.active; msg.res := 0
					ELSE Gadgets.objecthandle(tool, msg)
					END
				ELSIF msg.id = Objects.set THEN
					IF msg.name = "Unit" THEN
						IF msg.class = Objects.Real THEN tool.unit := msg.x; msg.res := 0 END
					ELSIF msg.name = "OriginX" THEN
						IF msg.class = Objects.Real THEN tool.zx := msg.x; msg.res := 0 END
					ELSIF msg.name = "OriginY" THEN
						IF msg.class = Objects.Real THEN tool.zy := msg.x; msg.res := 0 END
					ELSIF msg.name = "Width" THEN
						IF msg.class = Objects.Real THEN tool.pageW := msg.x; msg.res := 0 END
					ELSIF msg.name = "Height" THEN
						IF msg.class = Objects.Real THEN tool.pageH := msg.x; msg.res := 0 END
					ELSIF msg.name = "Buffered" THEN
						IF msg.class = Objects.Bool THEN tool.buffered := msg.b; msg.res := 0 END
					ELSIF msg.name = "GridTicks" THEN
						IF msg.class = Objects.Int THEN tool.grid.ticks := SHORT(msg.i); msg.res := 0 END
					ELSIF msg.name = "GridVisible" THEN
						IF msg.class = Objects.Bool THEN tool.grid.visible := msg.b; msg.res := 0 END
					ELSIF msg.name = "GridActive" THEN
						IF msg.class = Objects.Bool THEN tool.grid.active := msg.b; msg.res := 0 END
					ELSE
						Gadgets.objecthandle(tool, msg)
					END
				END
			END
		ELSIF msg IS Objects.CopyMsg THEN
			WITH msg: Objects.CopyMsg DO
				IF msg.stamp # tool.stamp THEN
					NEW(copy); tool.dlink := copy; tool.stamp := msg.stamp;
					Copy(msg, tool, copy)
				END;
				msg.obj := tool.dlink
			END
		ELSIF msg IS Objects.FileMsg THEN
			WITH msg: Objects.FileMsg DO
				Gadgets.objecthandle(tool, msg);
				IF msg.id = Objects.store THEN
					Files.WriteNum(msg.R, 2);
					Files.WriteReal(msg.R, tool.unit); Files.WriteReal(msg.R, tool.zx); Files.WriteReal(msg.R, tool.zy);
					Files.WriteReal(msg.R, tool.pageW); Files.WriteReal(msg.R, tool.pageH);
					Files.WriteInt(msg.R, tool.grid.ticks); Files.WriteBool(msg.R, tool.grid.visible); Files.WriteBool(msg.R, tool.grid.active);
					Files.WriteBool(msg.R, tool.buffered)
				ELSIF msg.id = Objects.load THEN
					Files.ReadNum(msg.R, ver);
					Files.ReadReal(msg.R, tool.unit); Files.ReadReal(msg.R, tool.zx); Files.ReadReal(msg.R, tool.zy);
					Files.ReadReal(msg.R, tool.pageW); Files.ReadReal(msg.R, tool.pageH);
					Files.ReadInt(msg.R, tool.grid.ticks); Files.ReadBool(msg.R, tool.grid.visible); Files.ReadBool(msg.R, tool.grid.active);
					IF ver >= 2 THEN Files.ReadBool(msg.R, tool.buffered) END
				END
			END
		ELSE
			Gadgets.objecthandle(tool, msg)
		END
	END Handle;

	(** initialize tool **)
	PROCEDURE Init* (tool: Tool);
		VAR ticks: SIGNED32;
	BEGIN
		tool.handle := Handle;
		Attributes.GetReal(Unit, "Value", tool.unit); tool.zx := 0; tool.zy := 0;
		Attributes.GetReal(PageWidth, "Value", tool.pageW);
		Attributes.GetReal(PageHeight, "Value", tool.pageH);
		Attributes.GetBool(Buffered, "Value", tool.buffered);
		Attributes.GetInt(GridTicks, "Value", ticks); tool.grid.ticks := SHORT(ticks);
		Attributes.GetBool(GridVisible, "Value", tool.grid.visible);
		Attributes.GetBool(GridActive, "Value", tool.grid.active)
	END Init;

	PROCEDURE New*;
		VAR tool: Tool;
	BEGIN
		NEW(tool); Init(tool);
		Objects.NewObj := tool
	END New;

	(** get currently installed tool; create and link one if none is present **)
	PROCEDURE Current* (frame: LeoFrames.Frame): Tool;
		VAR obj: Objects.Object; tool: Tool;
	BEGIN
		Links.GetLink(frame, "Tool", obj);
		IF (obj # NIL) & (obj IS Tool) THEN
			tool := obj(Tool)
		ELSE
			NEW(tool); Init(tool);
			Links.SetLink(frame, "Tool", tool)
		END;
		tool.frame := frame;
		RETURN tool
	END Current;

	(** initialize frame with current tool handler **)
	PROCEDURE InitFrame* (frame: LeoFrames.Frame; fig: Leonardo.Figure);
	BEGIN
		LeoFrames.Init(frame, fig); frame.handle := ToolHandler; frame.framed := TRUE
	END InitFrame;

	PROCEDURE NewFrame*;
		VAR frame: LeoFrames.Frame;
	BEGIN
		NEW(frame); InitFrame(frame, NIL);
		Objects.NewObj := frame
	END NewFrame;


	(**--- Content Area ---**)

	(** return if point is in content area of frame rectangle **)
	PROCEDURE InContents* (x, y, fx, fy, fw, fh: SIGNED16): BOOLEAN;
	BEGIN
		RETURN (fx + RulerW <= x) & (x < fx + fw) & (fy + InfoH <= y) & (y < fy + fh - RulerH)
	END InContents;

	(** adjust mask to content area **)
	PROCEDURE AdjustMask* (mask: Display3.Mask; frame: LeoFrames.Frame; fx, fy: SIGNED16);
	BEGIN
		Display3.AdjustMask(mask, fx + RulerW, fy + InfoH, frame.W - RulerW, frame.H - AuxH)
	END AdjustMask;


	(**--- Coordinate Conversions ---**)

	(** map pixel relative to frame origin to point in figure space **)
	PROCEDURE FrameToPoint* (frame: LeoFrames.Frame; fx, fy: SIGNED16; VAR px, py: FLOAT32);
	BEGIN
		px := (fx - RulerW - frame.ox)/frame.scale;
		py := (fy - (frame.H - RulerH) - frame.oy)/frame.scale
	END FrameToPoint;

	(** map point in figure space to pixel relative to frame origin **)
	PROCEDURE PointToFrame* (frame: LeoFrames.Frame; px, py: FLOAT32; VAR fx, fy: SIGNED16);
	BEGIN
		fx := SHORT(ENTIER(frame.ox + px * frame.scale)) + RulerW;
		fy := SHORT(ENTIER(frame.oy + py * frame.scale)) + frame.H - RulerH
	END PointToFrame;

	(** map point in figure space to ruler coordinates **)
	PROCEDURE PointToRuler* (tool: Tool; px, py: FLOAT32; VAR rx, ry: FLOAT32);
	BEGIN
		rx := (px - tool.zx)/tool.unit;
		ry := -(py - tool.zy)/tool.unit
	END PointToRuler;

	(** map point in ruler space to point in figure space **)
	PROCEDURE RulerToPoint* (tool: Tool; rx, ry: FLOAT32; VAR px, py: FLOAT32);
	BEGIN
		px := tool.zx + rx * tool.unit;
		py := tool.zy - ry * tool.unit
	END RulerToPoint;


	(**--- Auto-Alignment ---**)

	(** return angle of normalized direction vector **)
	PROCEDURE Angle* (dx, dy: FLOAT32): FLOAT32;
		VAR phi: FLOAT32;
	BEGIN
		IF (ABS(dx) < 1.0) & (ABS(dy) >= ABS(dx * MAX(FLOAT32))) THEN	(* dy/dx would result in overflow/divide by zero trap *)
			IF dy >= 0 THEN phi := Math.pi/2
			ELSE phi := -Math.pi/2
			END
		ELSIF dx > 0 THEN	(* 1st or 4th quadrant *)
			phi := Math.arctan(dy/dx)
		ELSIF dx < 0 THEN	(* 2nd or 3rd quadrant *)
			phi := Math.arctan(dy/dx) + Math.pi
		END;
		IF phi < 0 THEN
			phi := phi + 2*Math.pi
		END;
		RETURN phi
	END Angle;

	(** align point to grid **)
	PROCEDURE AlignToGrid* (tool: Tool; VAR px, py: FLOAT32);
		VAR dist: FLOAT32;
	BEGIN
		IF tool.grid.active THEN
			dist := tool.unit/tool.grid.ticks;
			px := ENTIER((px - tool.zx)/dist + 0.5) * dist + tool.zx;
			py := ENTIER((py - tool.zy)/dist + 0.5) * dist + tool.zy
		END
	END AlignToGrid;

	(** align point to axis through (sx, sy) **)
	PROCEDURE AlignToAxis* (tool: Tool; sx, sy: FLOAT32; VAR x, y: FLOAT32);
		VAR axes: SIGNED32; phi, dx, dy, len, tol, atan: FLOAT32;
	BEGIN
		Attributes.GetInt(AlignAxes, "Value", axes);
		IF axes > 0 THEN
			phi := 2.0 * Math.pi/axes;
			dx := x - sx; dy := y - sy;
			len := Math.sqrt(dx * dx + dy * dy);
			Attributes.GetReal(Tolerance, "Value", tol);
			IF len >= tol/tool.frame.scale THEN
				atan := ENTIER(Angle(dx, dy)/phi + 0.5) * phi;
				x := sx + len * Math.cos(atan); y := sy + len * Math.sin(atan)
			ELSE
				x := sx; y := sy
			END
		END
	END AlignToAxis;

	(** align point to shape (by projection) **)
	PROCEDURE AlignToShape* (tool: Tool; x, y: FLOAT32; VAR px, py: FLOAT32);
		VAR frame: LeoFrames.Frame; fig: Leonardo.Figure; tol, s, d, tx, ty: FLOAT32; res: Leonardo.Shape;
	BEGIN
		frame := tool.frame; fig := frame.obj(Leonardo.Figure);
		Attributes.GetReal(Tolerance, "Value", tol); s := 1/frame.scale; d := tol * s;
		Leonardo.Project(fig, x, y, x - d, y - d, x + d, y + d, px, py, res);
		IF res = NIL THEN
			Leonardo.Project(fig, x, y, x - d, -(frame.oy + frame.H - AuxH) * s, x + d, -frame.oy * s, px, ty, res);
			Leonardo.Project(fig, x, y, -frame.ox * s, y - d, -(frame.ox - frame.W) * s, y + d, tx, py, res)
		END
	END AlignToShape;

	(** align point with respect to currently pressed modifier keys **)
	PROCEDURE Align* (tool: Tool; ox, oy: FLOAT32; VAR px, py: FLOAT32);
		VAR state: SET;
	BEGIN
		Input.KeyState(state);
		AlignToGrid(tool, px, py);
		IF Input.CTRL IN state THEN
			AlignToShape(tool, px, py, px, py)
		END;
		IF Input.SHIFT IN state THEN
			IF (tool.frame = Focus.frame) & Focus.visible & (Focus.points >= 1) THEN
				AlignToAxis(tool, Focus.x[0], Focus.y[0], px, py)
			ELSE
				AlignToAxis(tool, ox, oy, px, py)
			END
		END
	END Align;


	(**--- Coordinate Hints ---**)

	PROCEDURE FlipHints (tool: Tool; fx, fy: SIGNED16; mask: Display3.Mask);
		VAR frame: LeoFrames.Frame; y, h, w: SIGNED16;
	BEGIN
		frame := tool.frame;
		IF tool.hints.incontents THEN
			y := fy + InfoH; h := frame.H - InfoH; w := frame.W
		ELSE
			y := fy + frame.H - RulerH; h := RulerH; w := RulerW
		END;
		IF (RulerW <= tool.hints.x) & (tool.hints.x < frame.W) THEN
			Oberon.RemoveMarks(fx + tool.hints.x, y, 1, h);
			Display3.FillPattern(mask, Display3.invertC, Display.grey2, fx, fy, fx + tool.hints.x, y, 1, h, Display.invert)
		END;
		IF (InfoH <= tool.hints.y) & (tool.hints.y < frame.H - RulerH) THEN
			Oberon.RemoveMarks(fx, fy + tool.hints.y, w, 1);
			Display3.FillPattern(mask, Display3.invertC, Display.grey2, fx, fy, fx, fy + tool.hints.y, w, 1, Display.invert)
		END
	END FlipHints;

	(** display tracking hints in ruler and possibly content area **)
	PROCEDURE ShowHints* (tool: Tool; fx, fy: SIGNED16; mask: Display3.Mask; x, y: SIGNED16; inContents: BOOLEAN);
	BEGIN
		IF ~tool.hints.visible THEN
			tool.hints.visible := TRUE; tool.hints.incontents := inContents; tool.hints.x := x; tool.hints.y := y;
			FlipHints(tool, fx, fy, mask)
		ELSIF (inContents # tool.hints.incontents) OR (x # tool.hints.x) OR (y # tool.hints.y) THEN
			FlipHints(tool, fx, fy, mask);
			tool.hints.incontents := inContents; tool.hints.x := x; tool.hints.y := y;
			FlipHints(tool, fx, fy, mask)
		END
	END ShowHints;

	PROCEDURE ClearHints* (tool: Tool; fx, fy: SIGNED16; mask: Display3.Mask);
	BEGIN
		IF tool.hints.visible THEN
			FlipHints(tool, fx, fy, mask);
			tool.hints.visible := FALSE
		END
	END ClearHints;


	(**--- Status Line ---**)

	(** display string at given position with minimized flickering **)
	PROCEDURE String* (mask: Display3.Mask; fg, bg: Display.Color; sx, sy: SIGNED16; s: ARRAY OF CHAR);
		VAR r, g, b, px, dx, x, y, w, h: SIGNED16; i: SIGNED32; pat: Display.Pattern;
	BEGIN
		IF fg < 0 THEN
			Display.GetColor(fg, r, g, b); fg := Colors.Match(Colors.DisplayIndex, Colors.DisplayBits, r, g, b)
		END;
		IF bg < 0 THEN
			Display.GetColor(bg, r, g, b); bg := Colors.Match(Colors.DisplayIndex, Colors.DisplayBits, r, g, b)
		END;
		Pictures.ReplConst(Pict, SHORT(bg), 0, 0, Pict.width, Font.height, Display.replace);
		i := 0; px := 0;
		WHILE s[i] # 0X DO
			Fonts.GetChar(Font, s[i], dx, x, y, w, h, pat);
			IF px + dx > Pict.width THEN
				Display3.Pict(mask, Pict, 0, 0, px, Font.height, sx, sy, Display.replace);
				Pictures.ReplConst(Pict, SHORT(bg), 0, 0, Pict.width, Font.height, Display.replace);
				INC(sx, px); px := 0
			END;
			IF pat # 0 THEN
				Pictures.CopyPattern(Pict, SHORT(fg), pat, px + x, y - Font.minY, Display.paint)
			END;
			INC(px, dx); INC(i)
		END;
		IF px > 0 THEN
			Display3.Pict(mask, Pict, 0, 0, px, Font.height, sx, sy, Display.replace)
		END
	END String;

	(** return string width **)
	PROCEDURE StringWidth* (s: ARRAY OF CHAR): SIGNED16;
		VAR w, h, dsr: SIGNED16;
	BEGIN
		Display3.StringSize(s, Font, w, h, dsr);
		RETURN w
	END StringWidth;

	(** display string in frame status line **)
	PROCEDURE ShowStatus* (frame: LeoFrames.Frame; fx, fy: SIGNED16; mask: Display3.Mask; s: ARRAY OF CHAR);
		VAR x, y, w: SIGNED16;
	BEGIN
		x := fx + RulerW + 2; y := fy + 1;
		Oberon.RemoveMarks(x, y, frame.W - RulerW - 3, Font.height);
		String(mask, Display3.black, frame.col, x, y, s);
		x := x + StringWidth(s); w := fx + (frame.W-1) - x;
		IF w > 0 THEN
			Display3.ReplConst(mask, LeoFrames.Color(frame), x, y, w, Font.height, Display.replace)
		END
	END ShowStatus;

	(** clear frame status line **)
	PROCEDURE ClearStatus* (frame: LeoFrames.Frame; fx, fy: SIGNED16; mask: Display3.Mask);
		VAR x, w: SIGNED16;
	BEGIN
		x := fx + RulerW; w := frame.W - RulerW;
		Display3.FilledRect3D(mask, Display3.topC, Display3.bottomC, LeoFrames.Color(frame), x, fy, w, InfoH, 1, Display.replace)
	END ClearStatus;

	(** append string and update length **)
	PROCEDURE Append* (t: ARRAY OF CHAR; VAR s: ARRAY OF CHAR; VAR len: SIGNED16);
		VAR i, j: SIGNED32;
	BEGIN
		i := 0; j := len;
		WHILE (i < LEN(t)) & (t[i] # 0X) & (j < LEN(s)-1) DO
			s[j] := t[i]; INC(i); INC(j)
		END;
		s[j] := 0X; len := SHORT(j)
	END Append;

	(** append number to string and update len **)
	PROCEDURE AppendReal* (x: FLOAT32; VAR s: ARRAY OF CHAR; VAR len: SIGNED16);
		VAR t: ARRAY 12 OF CHAR; i, j: SIGNED32; ch: CHAR;
	BEGIN
		Strings.RealToFixStr(x, t, 0, 2, 0);
		i := 0; WHILE t[i] = " " DO INC(i) END;
		IF i # 0 THEN
			j := 0; REPEAT ch := t[i]; t[j] := ch; INC(i); INC(j) UNTIL ch = 0X
		END;
		Append(t, s, len)
	END AppendReal;

	(** convert pair of coordinates to ruler, append to string, and update len **)
	PROCEDURE AppendPoint* (tool: Tool; px, py: FLOAT32; VAR s: ARRAY OF CHAR; VAR len: SIGNED16);
		VAR rx, ry: FLOAT32;
	BEGIN
		Append("(", s, len);
		PointToRuler(tool, px, py, rx, ry);
		AppendReal(rx, s, len); Append(", ", s, len);
		AppendReal(ry, s, len); Append(")", s, len)
	END AppendPoint;

	(** append direction vector and angle **)
	PROCEDURE AppendDir* (tool: Tool; dx, dy: FLOAT32; VAR s: ARRAY OF CHAR; VAR len: SIGNED16);
		VAR d: FLOAT32;
	BEGIN
		d := Math.sqrt(dx * dx + dy * dy);
		IF d = 0 THEN
			Append("0", s, len)
		ELSE
			dx := dx/d; dy := dy/d;
			Append("(", s, len); AppendReal(Angle(dx, dy) * (180/Math.pi), s, len);
			Append(", ", s, len); AppendReal(d/tool.unit, s, len);
			Append(")", s, len)
		END
	END AppendDir;

	(** append focus transformation status **)
	PROCEDURE AppendFocus* (tool: Tool; VAR s: ARRAY OF CHAR; VAR len: SIGNED16);
	VAR x: SIGNED16;
	BEGIN
		IF tool.frame # Focus.frame THEN
			Append("translate", s, len)
		ELSE
			x := Focus.style;
			CASE x OF
			| translate: Append("translate", s, len)
			| scale: Append("scale", s, len)
			| rotate: Append("rotate", s, len)
			| shear: Append("shear", s, len)
			| mirror: Append("mirror", s, len)
			END;
			IF Focus.points = 1 THEN
				Append(" at ", s, len); AppendPoint(tool, Focus.x[0], Focus.y[0], s, len)
			END;
			IF Focus.points > 1 THEN
				Append(" along ", s, len); AppendDir(tool, Focus.x[1] - Focus.x[0], Focus.y[1] - Focus.y[0], s, len)
			END
		END
	END AppendFocus;

	(** build status line for tool overriding ML only **)
	PROCEDURE AppendTool* (tool: Tool; x, y: FLOAT32; str: ARRAY OF CHAR; VAR s: ARRAY OF CHAR; VAR len: SIGNED16);
	BEGIN
		AppendPoint(tool, x, y, s, len);
		Append("  ML: ", s, len);
		Append(str, s, len);
		Append(", MM: ", s, len);
		AppendFocus(tool, s, len);
		Append(", MR: select", s, len)
	END AppendTool;


	(*--- Drawing ---*)

	PROCEDURE Number (mask: Display3.Mask; x, y: SIGNED16; n: SIGNED32);
		VAR dx, cx, cy, cw, ch: SIGNED16; pat: Display.Pattern; m: SIGNED32;
	BEGIN
		IF n < 0 THEN
			Fonts.GetChar(Font, "-", dx, cx, cy, cw, ch, pat);
			Display3.CopyPattern(mask, Display3.black, pat, x - dx + cx, y + cy, Display.paint);
			n := -n
		END;
		m := 10000;
		WHILE m > n DO m := m DIV 10 END;
		WHILE m > 1 DO
			Fonts.GetChar(Font, CHR(ORD("0") + n DIV m), dx, cx, cy, cw, ch, pat);
			Display3.CopyPattern(mask, Display3.black, pat, x + cx, y + cy, Display.paint);
			INC(x, dx); n := n MOD m; m := m DIV 10
		END;
		Fonts.GetChar(Font, CHR(ORD("0") + n), dx, cx, cy, cw, ch, pat);
		Display3.CopyPattern(mask, Display3.black, pat, x + cx, y + cy, Display.paint)
	END Number;

	PROCEDURE CalcTicks (unit: FLOAT32; ticks: SIGNED16; VAR ticks0, ticks1: SIGNED32);
	BEGIN
		ticks0 := ticks;
		WHILE (ticks0 > 1) & ((ticks MOD ticks0 # 0) OR (unit/ticks0 < 10)) DO
			DEC(ticks0)
		END;
		CASE ENTIER(unit) OF
		| 0: ticks1 := 100; WHILE ticks1 * unit < 50 DO ticks1 := 10*ticks1 END;
		| 1..2: ticks1 := 50*ticks0
		| 3..4: ticks1 := 20*ticks0
		| 5..9: ticks1 := 10*ticks0
		| 10..24: ticks1 := 5*ticks0
		| 25..49: ticks1 := 2*ticks0
		ELSE ticks1 := ticks0
		END
	END CalcTicks;

	PROCEDURE RestoreVRuler (tool: Tool; fx, fy: SIGNED16; mask: Display3.Mask);
		VAR frame: LeoFrames.Frame; unit, th, zy, ty: FLOAT32; ticks0, ticks1, t: SIGNED32; x, y: SIGNED16;
	BEGIN
		frame := tool.frame;
		Display3.FilledRect3D(mask, Display3.topC, Display3.bottomC, LeoFrames.Color(frame),
			fx, fy + InfoH, RulerW, frame.H - AuxH, 1, Display.replace);
		unit := tool.unit * frame.scale;	(* unit in frame space *)
		CalcTicks(unit, tool.grid.ticks, ticks0, ticks1);
		th := unit/ticks0;	(* height of one tick *)
		zy := frame.oy + tool.zy * frame.scale;	(* zero in frame coordinates *)
		t := -ENTIER(-zy/th);	(* topmost tick *)
		ty := frame.H - RulerH + zy - t * th;	(* coordinate for current tick *)
		x := fx+1;
		WHILE ty > InfoH DO
			y := fy + SHORT(ENTIER(ty));
			IF t MOD ticks1 = 0 THEN
				Display3.ReplConst(mask, Display3.black, x, y, RulerW-2, 1, Display.replace);
				IF y - Font.maxY > fy + InfoH THEN
					Number(mask, x+7, y - Font.maxY, t DIV ticks0)
				END
			ELSE
				Display3.ReplConst(mask, Display3.black, x + RulerW-6, y, 4, 1, Display.replace)
			END;
			INC(t); ty := ty - th
		END
	END RestoreVRuler;

	PROCEDURE RestoreHRuler (tool: Tool; fx, fy: SIGNED16; mask: Display3.Mask);
		VAR frame: LeoFrames.Frame; unit, tw, zx, tx: FLOAT32; ticks0, ticks1, t: SIGNED32; y, x: SIGNED16;
	BEGIN
		frame := tool.frame;
		Display3.FilledRect3D(mask, Display3.topC, Display3.bottomC, LeoFrames.Color(frame),
			fx + RulerW, fy + frame.H - RulerH, frame.W - RulerW, RulerH, 1, Display.replace);
		unit := tool.unit * frame.scale;	(* unit in frame space *)
		CalcTicks(unit, tool.grid.ticks, ticks0, ticks1);
		tw := unit/ticks0;	(* width of one tick *)
		zx := frame.ox + tool.zx * frame.scale;	(* zero in frame coordinates *)
		t := -ENTIER(zx/tw);	(* leftmost tick *)
		tx := RulerW + zx + t * tw;	(* coordinate for current tick *)
		y := fy + frame.H - (RulerH-1);
		WHILE tx < frame.W DO
			x := fx + SHORT(ENTIER(tx));
			IF t MOD ticks1 = 0 THEN
				Display3.ReplConst(mask, Display3.black, x, y, 1, RulerH-2, Display.replace);
				Number(mask, x+2, y + (RulerH-2) - Font.maxY, t DIV ticks0)
			ELSE
				Display3.ReplConst(mask, Display3.black, x, y, 1, 4, Display.replace)
			END;
			INC(t); tx := tx + tw
		END
	END RestoreHRuler;

	PROCEDURE RestoreOrigin (tool: Tool; fx, fy: SIGNED16; mask: Display3.Mask);
		VAR y: SIGNED16;
	BEGIN
		y := fy + tool.frame.H - RulerH;
		Display3.FilledRect3D(mask, Display3.topC, Display3.bottomC, LeoFrames.Color(tool.frame),
			fx, y, RulerW, RulerH, 3, Display.replace);
		Display3.Rect3D(mask, Display3.bottomC, Display3.topC, fx+1, y+1, RulerW-2, RulerH-2, 1, Display.replace);
		Display3.String(mask, Display3.bottomC, fx+4, y+6, Font, "(0,0)", Display.paint)
	END RestoreOrigin;

	PROCEDURE RestoreZoom (tool: Tool; fx, fy: SIGNED16; mask: Display3.Mask);
		VAR n: SIGNED32; dx, x, y, w, h: SIGNED16; pat: Display.Pattern;
	BEGIN
		Display3.FilledRect3D(mask, Display3.topC, Display3.bottomC, LeoFrames.Color(tool.frame),
			fx, fy, RulerW, InfoH, 3, Display.replace);
		Display3.Rect3D(mask, Display3.bottomC, Display3.topC, fx+1, fy+1, RulerW-2, InfoH-2, 1, Display.replace);
		INC(fx, 3); INC(fy, 4); n := ENTIER(tool.frame.scale * 100 + 0.5) MOD 1000;
		Fonts.GetChar(Font, CHR(ORD("0") + n DIV 100), dx, x, y, w, h, pat);
		IF n >= 100 THEN
			Display3.CopyPattern(mask, Display3.black, pat, fx, fy, Display.paint)
		END;
		INC(fx, dx);
		Fonts.GetChar(Font, CHR(ORD("0") + (n MOD 100) DIV 10), dx, x, y, w, h, pat);
		IF n >= 10 THEN
			Display3.CopyPattern(mask, Display3.black, pat, fx, fy, Display.paint)
		END;
		INC(fx, dx);
		Fonts.GetChar(Font, CHR(ORD("0") + n MOD 10), dx, x, y, w, h, pat);
		Display3.CopyPattern(mask, Display3.black, pat, fx, fy, Display.paint);
		INC(fx, dx);
		Fonts.GetChar(Font, "%", dx, x, y, w, h, pat);
		Display3.CopyPattern(mask, Display3.black, pat, fx, fy, Display.paint)
	END RestoreZoom;

	PROCEDURE RestorePage (tool: Tool; llx, lly, urx, ury: SIGNED16; mask: Display3.Mask);
		VAR frame: LeoFrames.Frame; x, y, w, h, pw, ph: SIGNED16;
	BEGIN
		frame := tool.frame;
		IF (lly + frame.ox < urx) & (ury + frame.oy > lly) THEN
			x := mask.X; y := mask.Y; w := mask.W; h := mask.H;
			Display3.AdjustMask(mask, llx, lly, urx - llx, ury - lly);
			IF (tool.pageW = 0) OR (tool.pageH = 0) THEN
				IF frame.ox > 0 THEN
					Display3.ReplConst(mask, Display3.groupC, llx + frame.ox, lly, 1, ury + frame.oy - lly, Display.replace)
				END;
				IF frame.oy < 0 THEN
					Display3.ReplConst(mask, Display3.groupC, llx + frame.ox, ury + frame.oy, urx - llx - frame.ox, 1, Display.replace)
				END
			ELSE
				pw := SHORT(ENTIER(tool.pageW * frame.scale));
				ph := SHORT(ENTIER(tool.pageH * frame.scale));
				Display3.Rect(mask, Display3.groupC, Display.solid, llx + frame.ox, ury + frame.oy - ph, pw, ph, 1, Display.replace);
				Display3.ReplConst(mask, Display3.groupC, llx + frame.ox + 3, ury + frame.oy - ph - 3, pw, 3, Display.replace);
				Display3.ReplConst(mask, Display3.groupC, llx + frame.ox + pw, ury + frame.oy - ph, 3, ph-3, Display.replace)
			END;
			mask.X := x; mask.Y := y; mask.W := w; mask.H := h
		END;
		IF frame.framed THEN
			Display3.Rect3D(mask, Display3.topC, Display3.bottomC, llx, lly, urx - llx, ury - lly, 1, Display.replace);
		END
	END RestorePage;

	PROCEDURE RestoreGrid (tool: Tool; llx, lly, urx, ury: SIGNED16; mask: Display3.Mask);
		VAR frame: LeoFrames.Frame; unit, td, zx, zy, tx, ty, y: FLOAT32; ticks0, ticks1: SIGNED32; x: SIGNED16;
	BEGIN
		frame := tool.frame;
		unit := tool.unit * frame.scale;	(* unit in frame space *)
		CalcTicks(unit, tool.grid.ticks, ticks0, ticks1);
		td := unit/ticks0;
		zx := frame.ox + tool.zx * frame.scale; zy := frame.oy + tool.zy * frame.scale;
		tx := llx + zx; tx := tx - ENTIER(zx/td) * td; ty := ury + zy; ty := ty + ENTIER(-zy/td) * td;
		WHILE tx < urx DO
			x := SHORT(ENTIER(tx)); y := ty;
			WHILE y > lly DO
				Display3.Dot(mask, Display3.groupC, x, SHORT(ENTIER(y)), Display.replace);
				y := y - td
			END;
			tx := tx + td
		END
	END RestoreGrid;

	PROCEDURE RestoreFigure (tool: Tool; llx, lly, urx, ury: SIGNED16; clip: GfxRegions.Region);
		VAR frame: LeoFrames.Frame; ctxt: Gfx.Context; col: Gfx.Color; pix: Images.Pixel; x0, y0, x1, y1: FLOAT32;
	BEGIN
		frame := tool.frame;
		ctxt := LeoFrames.DisplayContext(frame, llx, lly, urx, ury, clip);
		Display.GetColor(frame.col, col.r, col.g, col.b);
		IF tool.buffered THEN
			Images.Create(BC.img, urx - llx, ury - lly, Images.DisplayFormat);
			GfxBuffer.SetCoordinates(BC, frame.ox, ury - lly + frame.oy, 1);
			GfxBuffer.SetBGColor(BC, col);
			Gfx.Reset(BC);
			Gfx.Scale(BC, frame.scale, frame.scale);
			Images.SetRGB(pix, col.r, col.g, col.b);
			Images.Fill(BC.img, 0, 0, BC.img.width, BC.img.height, pix, Images.SrcCopy);
			Leonardo.Render(frame.obj(Leonardo.Figure), Leonardo.active, BC);
			Gfx.Scale(ctxt, 1/frame.scale, 1/frame.scale);	(* undo scale *)
			Gfx.DrawImageAt(ctxt, -frame.ox, -(ury - lly + frame.oy), BC.img, GfxImages.NoFilter)
		ELSE
			Gfx.SetFillColor(ctxt, col);
			Gfx.GetClipRect(ctxt, x0, y0, x1, y1);
			Gfx.DrawRect(ctxt, x0, y0, x1, y1, {Gfx.Fill});
			Gfx.SetFillColor(ctxt, Gfx.Black);
			Leonardo.Render(frame.obj(Leonardo.Figure), Leonardo.active, ctxt)
		END;
	END RestoreFigure;

	PROCEDURE Restore (tool: Tool; x, y, w, h, fx, fy: SIGNED16; mask: Display3.Mask);
		VAR frame: LeoFrames.Frame; llx, lly, urx, ury: SIGNED16;
	BEGIN
		frame := tool.frame;
		Oberon.RemoveMarks(fx + x, fy + y, w, h);
		IF x < RulerW THEN
			IF y + h > frame.H - RulerH THEN
				RestoreOrigin(tool, fx, fy, mask)
			END;
			IF frame.H > InfoH + RulerH THEN
				RestoreVRuler(tool, fx, fy, mask);
				IF y < InfoH THEN
					RestoreZoom(tool, fx, fy, mask)
				END
			END
		END;
		IF y + h > frame.H - RulerH THEN
			RestoreHRuler(tool, fx, fy, mask)
		END;
		IF (RulerH < frame.H) & (frame.H <= InfoH + RulerH) THEN
			Display3.Rect3D(mask, Display3.topC, Display3.bottomC, fx, fy, RulerW, frame.H - RulerH, 1, Display.replace);
			Display3.Rect3D(mask, Display3.topC, Display3.bottomC, fx + RulerW, fy, frame.W - RulerW, frame.H - RulerH, 1, Display.replace)
		END;
		IF (frame.H > InfoH + RulerH) & (y < InfoH) THEN
			ClearStatus(frame, fx, fy, mask)
		END;
		llx := fx + RulerW; lly := fy + InfoH; urx := fx + frame.W; ury := fy + frame.H - RulerH;
		IF (llx < urx) & (lly < ury) THEN
			RestoreFigure(tool, llx, lly, urx, ury, LeoFrames.RegionFromMask(mask));
			RestorePage(tool, llx, lly, urx, ury, mask);
			RestoreGrid(tool, llx, lly, urx, ury, mask)
		END;
		IF tool.hints.visible THEN
			FlipHints(tool, fx, fy, mask)
		END;
		IF Gadgets.selected IN frame.state THEN
			Display3.FillPattern(mask, Display3.white, Display3.selectpat, fx, fy, fx + x, fy + y, w, h, Display.paint)
		END
	END Restore;


	(*--- Printing ---*)

	PROCEDURE PNumber (mask: Display3.Mask; x, y: SIGNED16; n: SIGNED32);
		VAR metric: Fonts.Font; s: ARRAY 2 OF CHAR; dx, cx, cy, cw, ch: SIGNED16; pat: Display.Pattern; m: SIGNED32;
	BEGIN
		metric := Printer.GetMetric(Font); s[1] := 0X;
		IF n < 0 THEN
			s[0] := "-";
			Fonts.GetChar(metric, "-", dx, cx, cy, cw, ch, pat);
			Printer3.String(mask, Display3.black, x - dx + cx, y + cy, Font, s, Display.paint);
			n := -n
		END;
		m := 10000;
		WHILE m > n DO m := m DIV 10 END;
		WHILE m > 1 DO
			s[0] := CHR(ORD("0") + n DIV m);
			Fonts.GetChar(metric, s[0], dx, cx, cy, cw, ch, pat);
			Printer3.String(mask, Display3.black, x + cx, y + cy, Font, s, Display.paint);
			INC(x, dx); n := n MOD m; m := m DIV 10
		END;
		s[0] := CHR(ORD("0") + n);
		Fonts.GetChar(metric, s[0], dx, cx, cy, cw, ch, pat);
		Printer3.String(mask, Display3.black, x + cx, y + cy, Font, s, Display.paint)
	END PNumber;

	PROCEDURE PrintVRuler (tool: Tool; x, y, w, h, p: SIGNED16; mask: Display3.Mask);
		VAR frame: LeoFrames.Frame; unit, th, zy, ty, s: FLOAT32; ticks0, ticks1, t: SIGNED32; y0: SIGNED16;
	BEGIN
		frame := tool.frame;
		Printer3.FilledRect3D(mask, Display3.topC, Display3.bottomC, frame.col, x, y, w, h, p, Display.replace);
		unit := tool.unit * frame.scale;
		CalcTicks(unit, tool.grid.ticks, ticks0, ticks1);
		th := unit/ticks0;
		zy := frame.oy + tool.zy * frame.scale;
		t := -ENTIER(-zy/th);
		ty := zy - t * th;
		x := x + p; y0 := y;
		s := Display.Unit/Printer.Unit;
		y := y0 + h + SHORT(ENTIER(ty * s));
		WHILE y > y0 DO
			IF t MOD ticks1 = 0 THEN
				Printer3.ReplConst(mask, Display3.black, x, y, w - 2*p, p, Display.replace);
				IF y - Font.maxY * p > y0 THEN
					PNumber(mask, x + 6*p, y - Font.maxY * p, t DIV ticks0)
				END
			ELSE
				Printer3.ReplConst(mask, Display3.black, x + w - 5*p, y, 4*p, p, Display.replace)
			END;
			INC(t); ty := ty - th;
			y := y0 + h + SHORT(ENTIER(ty * s))
		END
	END PrintVRuler;

	PROCEDURE PrintHRuler (tool: Tool; x, y, w, h, p: SIGNED16; mask: Display3.Mask);
		VAR frame: LeoFrames.Frame; unit, tw, zx, tx, s: FLOAT32; ticks0, ticks1, t: SIGNED32; x0: SIGNED16;
	BEGIN
		frame := tool.frame;
		Printer3.FilledRect3D(mask, Display3.topC, Display3.bottomC, frame.col, x, y, w, h, p, Display.replace);
		unit := tool.unit * frame.scale;
		CalcTicks(unit, tool.grid.ticks, ticks0, ticks1);
		tw := unit/ticks0;
		zx := frame.ox + tool.zx * frame.scale;
		t := -ENTIER(zx/tw);
		tx := zx + t * tw;
		y := y + p; x0 := x;
		s := Display.Unit/Printer.Unit;
		x := x0 + SHORT(ENTIER(tx * s));
		WHILE x < x0 + w DO
			IF t MOD ticks1 = 0 THEN
				Printer3.ReplConst(mask, Display3.black, x, y, p, h - 2*p, Display.replace);
				PNumber(mask, x + 2*p, y + h - 2*p - Font.maxY*p, t DIV ticks0)
			ELSE
				Printer3.ReplConst(mask, Display3.black, x, y, p, 4*p, Display.replace)
			END;
			INC(t); tx := tx + tw;
			x := x0 + SHORT(ENTIER(tx * s))
		END
	END PrintHRuler;

	PROCEDURE PrintOrigin (tool: Tool; x, y, w, h, p: SIGNED16; mask: Display3.Mask);
	BEGIN
		Printer3.FilledRect3D(mask, Display3.topC, Display3.bottomC, tool.frame.col, x, y, w, h, 3*p, Display.replace);
		Printer3.Rect3D(mask, Display3.bottomC, Display3.topC, x+p, y+p, w-2*p, h-2*p, p, Display.replace);
		Printer3.String(mask, Display3.bottomC, x+4*p, y+6*p, Font, "(0,0)", Display.paint)
	END PrintOrigin;

	PROCEDURE PrintZoom (tool: Tool; x, y, w, h, p: SIGNED16; mask: Display3.Mask);
		VAR n: SIGNED32; s: ARRAY 5 OF CHAR;
	BEGIN
		Printer3.FilledRect3D(mask, Display3.topC, Display3.bottomC, tool.frame.col, x, y, w, h, 3*p, Display.replace);
		Printer3.Rect3D(mask, Display3.bottomC, Display3.topC, x + p, y + p, w - 2*p, h - 2*p, p, Display.replace);
		n := ENTIER(tool.frame.scale * 100 + 0.5) MOD 1000;
		s := "   %";
		IF n >= 100 THEN s[0] := CHR(ORD("0") + n DIV 100) END;
		IF n >= 10 THEN s[1] := CHR(ORD("0") + n DIV 10 MOD 10) END;
		s[2] := CHR(ORD("0") + n MOD 100);
		Printer3.String(mask, Display3.black, x + 3*p, y + 4*p, Font, s, Display.paint)
	END PrintZoom;

	PROCEDURE PrintPage (tool: Tool; llx, lly, urx, ury, p: SIGNED16; mask: Display3.Mask);
		VAR frame: LeoFrames.Frame; ox, oy, x, y, w, h, pw, ph: SIGNED16;
	BEGIN
		frame := tool.frame;
		ox := SHORT(LONG(frame.ox) * Printer.Unit DIV Display.Unit);
		oy := SHORT(LONG(frame.oy) * Printer.Unit DIV Display.Unit);
		IF (lly + ox < urx) & (ury + oy > lly) THEN
			x := mask.X; y := mask.Y; w := mask.W; h := mask.H;
			Display3.AdjustMask(mask, llx, lly, urx - llx, ury - lly);
			IF (tool.pageW = 0) OR (tool.pageH = 0) THEN
				IF ox > 0 THEN
					Printer3.ReplConst(mask, Display3.groupC, llx + ox, lly, p, ury + oy - lly, Display.replace)
				END;
				IF oy < 0 THEN
					Printer3.ReplConst(mask, Display3.groupC, llx + ox, ury + oy, urx - llx - ox, p, Display.replace)
				END
			ELSE
				pw := SHORT(ENTIER(tool.pageW * frame.scale * (Printer.Unit/Display.Unit)));
				ph := SHORT(ENTIER(tool.pageH * frame.scale * (Printer.Unit/Display.Unit)));
				Printer3.Rect(mask, Display3.groupC, Display.solid, llx + ox, ury + oy - ph, pw, ph, p, Display.replace);
				Printer3.ReplConst(mask, Display3.groupC, llx + ox + 3*p, ury + oy - ph - 3*p, pw, 3*p, Display.replace);
				Printer3.ReplConst(mask, Display3.groupC, llx + ox + pw, ury + oy - ph, 3*p, ph-3*p, Display.replace)
			END;
			mask.X := x; mask.Y := y; mask.W := w; mask.H := h
		END;
		IF frame.framed THEN
			Printer3.Rect3D(mask, Display3.topC, Display3.bottomC, llx, lly, urx - llx, ury - lly, p, Display.replace)
		END
	END PrintPage;

	PROCEDURE PrintGrid (tool: Tool; llx, lly, urx, ury, p: SIGNED16; mask: Display3.Mask);
		VAR frame: LeoFrames.Frame; unit, td, zx, zy, tx, ty, s, y: FLOAT32; ticks0, ticks1: SIGNED32; x: SIGNED16;
	BEGIN
		frame := tool.frame;
		unit := tool.unit * frame.scale;	(* unit in frame space *)
		CalcTicks(unit, tool.grid.ticks, ticks0, ticks1);
		td := unit/ticks0;
		zx := frame.ox + tool.zx * frame.scale; zy := frame.oy + tool.zy * frame.scale;
		tx := zx - ENTIER(zx/td) * td; ty := zy + ENTIER(-zy/td) * td;
		s := Display.Unit/Printer.Unit;
		x := llx + SHORT(ENTIER(tx * s));
		WHILE x < urx DO
			y := ury + ty * s;
			WHILE y > lly DO
				Printer3.ReplConst(mask, Display3.groupC, x, SHORT(ENTIER(y)), p, p, Display.replace);
				y := y - td * s
			END;
			tx := tx + td; x := llx + SHORT(ENTIER(tx * s))
		END
	END PrintGrid;

	PROCEDURE Print (tool: Tool; VAR msg: Display.DisplayMsg);
		VAR
			frame: LeoFrames.Frame; pc: GfxPrinter.Context; fw, fh, p1, rw, rh, ih, llx, lly, urx, ury: SIGNED16;
			mask: Display3.Mask; clip: GfxRegions.Region; ctxt: Gfx.Context;

		PROCEDURE p (x: SIGNED32): SIGNED16;
		BEGIN
			RETURN SHORT((x * Display.Unit + Printer.Unit DIV 2) DIV Printer.Unit)
		END p;

	BEGIN
		frame := tool.frame;
		IF msg.id = Display.contents THEN
			NEW(pc); GfxPrinter.Init(pc);
			GfxPrinter.SetCoordinates(pc, 0, pc.scale * tool.pageH, pc.scale);
			Gfx.Reset(pc);
			Leonardo.Render(frame.obj(Leonardo.Figure), Leonardo.passive, pc);
			Printer.Page(1)
		ELSE
			fw := p(frame.W); fh := p(frame.H);
			p1 := p(1); rw := p(RulerW); rh := p(RulerH); ih := p(InfoH);
			Gadgets.MakePrinterMask(frame, msg.x, msg.y, msg.dlink, mask);
			PrintOrigin(tool, msg.x, msg.y + fh - rh, rw, rh, p1, mask);
			IF fh > ih + rh THEN
				PrintVRuler(tool, msg.x, msg.y + ih, rw, fh - ih - rh, p1, mask);
				PrintZoom(tool, msg.x, msg.y, rw, ih, p1, mask)
			END;
			PrintHRuler(tool, msg.x + rw, msg.y + fh - rh, fw - rw, rh, p1, mask);
			IF (rh < fh) & (fh <= ih + rh) THEN
				Printer3.Rect3D(mask, Display3.topC, Display3.bottomC, msg.x, msg.y, rw, fh - rh, p1, Display.replace);
				Printer3.Rect3D(mask, Display3.topC, Display3.bottomC, msg.x + rw, msg.y, fw - rw, fh - rh, p1, Display.replace)
			END;
			IF fh > ih + rh THEN
				Printer3.FilledRect3D(mask, Display3.topC, Display3.bottomC, LeoFrames.Color(frame),
					msg.x + rw, msg.y, fw - rw, ih, p1, Display.replace)
			END;
			llx := msg.x + rw; lly := msg.y + ih; urx := msg.x + fw; ury := msg.y + fh - rh;
			clip := LeoFrames.RegionFromMask(mask);
			ctxt := LeoFrames.PrinterContext(frame, llx, lly, urx, ury, clip);
			Leonardo.Render(frame.obj(Leonardo.Figure), Leonardo.active, ctxt);
			PrintPage(tool, llx, lly, urx, ury, p1, mask);
			PrintGrid(tool, llx, lly, urx, ury, p1, mask);
			IF Gadgets.selected IN frame.state THEN
				Printer3.FillPattern(mask, Display3.white, Display3.selectpat, msg.x, msg.y, msg.x, msg.y, fw, fh, Display.paint)
			END
		END
	END Print;


	(*--- Updates ---*)

	PROCEDURE Update (tool: Tool; VAR msg: Leonardo.UpdateMsg);
		VAR
			frame: LeoFrames.Frame; fx, fy, llx, lly, urx, ury, x, y, w, h: SIGNED16; clip: GfxRegions.Region;
			mask: Display3.Mask;
	BEGIN
		frame := tool.frame;
		IF msg.fig = frame.obj THEN	(* redisplay frame *)
			fx := msg.x + frame.X; fy := msg.y + frame.Y;
			llx := fx + RulerW; lly := fy + InfoH; urx := fx + frame.W; ury := fy + frame.H - RulerH;
			clip := LeoFrames.ScaledRegion(msg.reg, frame.scale, msg.bw, llx + frame.ox, ury + frame.oy);
			Gadgets.MakeMask(frame, llx, lly, msg.dlink, mask);
			GfxRegions.Intersect(clip, LeoFrames.RegionFromMask(mask));
			mask := LeoFrames.MaskFromRegion(clip);
			x := clip.llx; y := clip.lly; w := clip.urx - clip.llx; h := clip.ury - clip.lly;
			Oberon.RemoveMarks(x, y, w, h);
			RestoreFigure(tool, llx, lly, urx, ury, clip);
			RestorePage(tool, llx, lly, urx, ury, mask);
			RestoreGrid(tool, llx, lly, urx, ury, mask);
			IF tool.hints.visible & tool.hints.incontents THEN
				FlipHints(tool, fx, fy, mask)
			END;
			IF Gadgets.selected IN frame.state THEN
				Display3.FillPattern(mask, Display3.white, Display3.selectpat, llx, lly, x, y, w, h, Display.paint)
			END
		END
	END Update;


	(*--- View ---*)

	PROCEDURE Scroll (frame: LeoFrames.Frame; dx, dy: SIGNED16);
		VAR cm: Oberon.ControlMsg; dm: Display.DisplayMsg;
	BEGIN
		frame.ox := frame.ox + dx; frame.oy := frame.oy + dy;
		cm.F := frame; cm.id := Oberon.defocus; Display.Broadcast(cm);
		dm.F := frame; dm.device := Display.screen; dm.id := Display.full; Display.Broadcast(dm)
	END Scroll;


	(*--- Focus ---*)

	PROCEDURE InitFocusPatterns;
		VAR p: ARRAY 9 OF SET;
	BEGIN
		p[0] := {4}; p[1] := {4}; p[2] := {4}; p[3] := {4}; p[4] := {0..8}; p[5] := {4}; p[6] := {4}; p[7] := {4}; p[8] := {4};
		Pat[translate] := Display.NewPattern(9, 9, p);
		p[0] := {3..5}; p[1] := {1..2, 6..7}; p[2] := {1, 7}; p[3] := {0, 8}; p[4] := {0, 4, 8};
		p[5] := {0, 8}; p[6] := {1, 7}; p[7] := {1..2, 6..7}; p[8] := {3..5};
		Pat[rotate] := Display.NewPattern(9, 9, p);
		p[0] := {0, 8}; p[1] := {1, 7}; p[2] := {2, 6}; p[3] := {3, 5}; p[4] := {4};
		p[5] := {3, 5}; p[6] := {2, 6}; p[7] := {1, 7}; p[8] := {0, 8};
		Pat[scale] := Display.NewPattern(9, 9, p);
		p[0] := {4}; p[1] := {3, 5}; p[2] := {2, 6}; p[3] := {1, 7}; p[4] := {0, 4, 8}; p[5] := {1, 7}; p[6] := {2, 6}; p[7] := {3, 5}; p[8] := {4};
		Pat[shear] := Display.NewPattern(9, 9, p);
		p[0] := {0..8}; p[1] := {0..1, 7..8}; p[2] := {0, 2, 6, 8}; p[3] := {0, 3, 5, 8}; p[4] := {0, 4, 8};
		p[5] := {0, 3, 5, 8}; p[6] := {0, 2, 6, 8}; p[7] := {0..1, 7..8}; p[8] := {0..8};
		Pat[mirror] := Display.NewPattern(9, 9, p);
		p[0] := {0..4}; p[1] := {0, 4}; p[2] := {0, 4}; p[3] := {0, 4}; p[4] := {0..4};
		Pat[aux] := Display.NewPattern(5, 5, p)
	END InitFocusPatterns;

	PROCEDURE FlipFocus (fx, fy: SIGNED16; mask: Display3.Mask);
		VAR mx, my, mw, mh, x0, y0, x1, y1: SIGNED16;
	BEGIN
		IF Focus.points > 0 THEN
			mx := mask.X; my := mask.Y; mw := mask.W; mh := mask.H;
			AdjustMask(mask, Focus.frame, fx, fy);
			PointToFrame(Focus.frame, Focus.x[0], Focus.y[0], x0, y0); INC(x0, fx); INC(y0, fy);
			Display3.CopyPattern(mask, Display3.invertC, Pat[Focus.style], x0 - 4, y0 - 4, Display.invert);
			IF Focus.points > 1 THEN
				PointToFrame(Focus.frame, Focus.x[1], Focus.y[1], x1, y1); INC(x1, fx); INC(y1, fy);
				Display3.Line(mask, Display3.invertC, Display.solid, x0, y0, x1, y1, 1, Display.invert);
				Display3.CopyPattern(mask, Display3.invertC, Pat[aux], x1 - 2, y1 - 2, Display.invert)
			END;
			mask.X := mx; mask.Y := my; mask.W := mw; mask.H := mh
		END;
		Focus.visible := ~Focus.visible
	END FlipFocus;

	PROCEDURE ShowFocus (fx, fy: SIGNED16; mask: Display3.Mask);
	BEGIN
		IF ~Focus.visible THEN FlipFocus(fx, fy, mask) END
	END ShowFocus;

	PROCEDURE HideFocus (fx, fy: SIGNED16; mask: Display3.Mask);
	BEGIN
		IF Focus.visible THEN FlipFocus(fx, fy, mask) END
	END HideFocus;

	PROCEDURE CycleFocus;
	VAR x: SIGNED16;
	BEGIN
		x := Focus.style;
		CASE x  OF
		| translate: Focus.style := scale
		| scale: Focus.style := rotate
		| rotate, shear: Focus.style := mirror
		| mirror: Focus.style := translate
		END
	END CycleFocus;

	PROCEDURE GetDragStyle (frame: LeoFrames.Frame; VAR style, points: SIGNED16; VAR fx0, fy0, fx1, fy1: FLOAT32);
	BEGIN
		IF (Focus.frame # frame) OR ~Focus.visible THEN
			style := translate; points := 0
		ELSE
			style := Focus.style; points := Focus.points;
			IF points > 0 THEN
				fx0 := Focus.x[0]; fy0 := Focus.y[0];
				IF points > 1 THEN
					fx1 := Focus.x[1]; fy1 := Focus.y[1]
				END
			END
		END
	END GetDragStyle;

	PROCEDURE CalcMatrix (
		tool: Tool; style, points: SIGNED16; fx0, fy0, fx1, fy1, x0, y0, x1, y1: FLOAT32; VAR mat: GfxMatrix.Matrix;
		VAR s: ARRAY OF CHAR; VAR len: SIGNED16
	);
		CONST
			eps = 1.0E-4;
		VAR
			dx, dy, dx0, dy0, d0, dx1, dy1, d1, t, d, cos, sin, u, v, cp: FLOAT32;
	BEGIN
		CASE style OF
		| translate:
			IF points = 2 THEN
				GfxPaths.ProjectToLine(x0, y0, x0 + fx1 - fx0, y0 + fy1 - fy0, x1, y1, x1, y1)
			END;
			dx := x1 - x0; dy := y1 - y0;
			GfxMatrix.Init(mat, 1, 0, 0, 1, dx, dy);
			Append(" from ", s, len); AppendPoint(tool, x0, y0, s, len);
			Append(" to ", s, len); AppendPoint(tool, x1, y1, s, len);
			Append(", dist=", s, len); AppendReal(Math.sqrt(dx * dx + dy * dy)/tool.unit, s, len)

		| scale:
			dx0 := x0 - fx0; dy0 := y0 - fy0; d0 := dx0 * dx0 + dy0 * dy0;
			IF d0 < eps THEN Append(" invalid starting point", s, len); mat := GfxMatrix.Identity; RETURN END;
			dx1 := x1 - fx0; dy1 := y1 - fy0; d1 := dx1 * dx1 + dy1 * dy1;
			t := Math.sqrt(d1/d0);
			IF dx0 * dx1 + dy0 * dy1 < 0 THEN t := -t END;
			IF points = 1 THEN
				GfxMatrix.ScaleAt(GfxMatrix.Identity, fx0, fy0, t, t, mat)
			ELSE
				dx := fx1 - fx0; dy := fy1 - fy0; d := Math.sqrt(dx * dx + dy * dy);
				IF d < eps THEN d := eps END;
				cos := dx/d; sin := dy/d;
				GfxMatrix.RotateAt(GfxMatrix.Identity, fx0, fy0, sin, cos, mat);
				GfxMatrix.ScaleAt(mat, fx0, fy0, t, 1, mat);
				GfxMatrix.RotateAt(mat, fx0, fy0, -sin, cos, mat)
			END;
			Append(" factor ", s, len); AppendReal(t, s, len)

		| rotate:
			dx0 := x0 - fx0; dy0 := y0 - fy0; d0 := Math.sqrt(dx0 * dx0 + dy0 * dy0);
			IF d0 < eps THEN Append(" invalid starting point", s, len); mat := GfxMatrix.Identity; RETURN END;
			dx1 := x1 - fx0; dy1 := y1 - fy0; d1 := Math.sqrt(dx1 * dx1 + dy1 * dy1);
			IF d1 < eps THEN Append(" invalid end point", s, len); mat := GfxMatrix.Identity; RETURN END;
			t := d1/d0;
			GfxMatrix.Get2PointTransform(fx0, fy0, fx0, fy0, x0, y0, fx0 + dx1/t, fy0 + dy1/t, mat);
			Append(" angle=", s, len); AppendReal((Angle(dx1/d1, dy1/d1) - Angle(dx0/d0, dy0/d0)) * (180/Math.pi), s, len)

		| shear:
			dx := fx1 - fx0; dy := fy1 - fy0;
			GfxPaths.ProjectToLine(fx0, fy0, fx0 - dy, fy0 + dx, x0, y0, u, v);
			dx1 := x1 - fx0; dy1 := y1 - fy0;
			cp := dx * dy1 - dy * dx1;
			IF (-eps < cp) & (cp < 0) THEN cp := -eps
			ELSIF (0 <= cp) & (cp < eps) THEN cp := eps
			END;
			t := ((fx0 - u) * dy1 - (fy0 - v) * dx1)/cp;
			GfxMatrix.Get3PointTransform(fx0, fy0, fx0, fy0, fx1, fy1, fx1, fy1, x0, y0, u + t * dx, v + t * dy, mat)

		| mirror:
			IF points = 1 THEN
				GfxMatrix.ScaleAt(GfxMatrix.Identity, fx0, fy0, -1, -1, mat)
			ELSE
				dx := fx1 - fx0; dy := fy1 - fy0; d := Math.sqrt(dx * dx + dy * dy);
				IF d < eps THEN d := eps END;
				cos := dx/d; sin := dy/d;
				GfxMatrix.RotateAt(GfxMatrix.Identity, fx0, fy0, sin, cos, mat);
				GfxMatrix.ScaleAt(mat, fx0, fy0, 1, -1, mat);
				GfxMatrix.RotateAt(mat, fx0, fy0, -sin, cos, mat)
			END
		END
	END CalcMatrix;

	PROCEDURE CalcDrag (tool: Tool; x0, y0, x1, y1: FLOAT32; VAR mat: GfxMatrix.Matrix; VAR s: ARRAY OF CHAR; VAR len: SIGNED16);
		VAR points, style: SIGNED16; fx0, fy0, fx1, fy1: FLOAT32;
	BEGIN
		GetDragStyle(tool.frame, points, style, fx0, fy0, fx1, fy1);
		CalcMatrix(tool, points, style, fx0, fy0, fx1, fy1, x0, y0, x1, y1, mat, s, len)
	END CalcDrag;


	(**--- Tracking ---**)

	PROCEDURE TrackVRuler (frame: LeoFrames.Frame; fx, fy: SIGNED16; VAR msg: Oberon.InputMsg);
		VAR mask: Display3.Mask; my, x, y: SIGNED16; keysum, keys: SET;
	BEGIN
		IF msg.keys # {} THEN
			Gadgets.MakeMask(frame, fx, fy, msg.dlink, mask);
			Oberon.FadeCursor(Oberon.Mouse);
			IF msg.keys # {MM} THEN
				Display3.FillPattern(mask, Display3.invertC, Display.grey2, fx, fy, fx, msg.Y, frame.W, 1, Display.invert)
			END;
			my := msg.Y; keysum := msg.keys;
			Oberon.DrawCursor(Oberon.Mouse, Effects.PointHand, msg.X, msg.Y);
			REPEAT
				Input.Mouse(keys, x, y); keysum := keysum + keys;
				IF (keys # {}) & (y # my) & (fy + InfoH <= y) & (y < fy + frame.H - InfoH) THEN
					Oberon.FadeCursor(Oberon.Mouse);
					Display3.FillPattern(mask, Display3.invertC, Display.grey2, fx, fy, fx, my, frame.W, 1, Display.invert);
					my := y;
					Display3.FillPattern(mask, Display3.invertC, Display.grey2, fx, fy, fx, my, frame.W, 1, Display.invert);
					Oberon.DrawCursor(Oberon.Mouse, Effects.PointHand, x, y)
				END
			UNTIL keys = {};
			Oberon.FadeCursor(Oberon.Mouse);
			Display3.FillPattern(mask, Display3.invertC, Display.grey2, fx, fy, fx, my, frame.W, 1, Display.invert);
			IF msg.keys = {MM} THEN
				Display3.FillPattern(mask, Display3.invertC, Display.grey2, fx, fy, fx, msg.Y, frame.W, 1, Display.invert)
			END;
			IF keysum = {ML} THEN Scroll(frame, 0, fy + frame.H - RulerH - my)
			ELSIF keysum = {MM} THEN Scroll(frame, 0, my - msg.Y)
			ELSIF keysum = {MR} THEN Scroll(frame, 0, fy + InfoH - my)
			END
		END
	END TrackVRuler;

	PROCEDURE TrackHRuler (frame: LeoFrames.Frame; fx, fy: SIGNED16; VAR msg: Oberon.InputMsg);
		VAR mask: Display3.Mask; mx, x, y: SIGNED16; keysum, keys: SET;
	BEGIN
		IF msg.keys # {} THEN
			Gadgets.MakeMask(frame, fx, fy, msg.dlink, mask);
			Oberon.FadeCursor(Oberon.Mouse);
			IF msg.keys # {MM} THEN
				Display3.FillPattern(mask, Display3.invertC, Display.grey2, fx, fy, msg.X, fy + InfoH, 1, frame.H - InfoH, Display.invert)
			END;
			mx := msg.X; keysum := msg.keys;
			Oberon.DrawCursor(Oberon.Mouse, Effects.PointHand, msg.X, msg.Y);
			REPEAT
				Input.Mouse(keys, x, y); keysum := keysum + keys;
				IF (keys # {}) & (x # mx) & (fx + RulerW <= x) & (x < fx + frame.W) THEN
					Oberon.FadeCursor(Oberon.Mouse);
					Display3.FillPattern(mask, Display3.invertC, Display.grey2, fx, fy, mx, fy + InfoH, 1, frame.H - InfoH, Display.invert);
					mx := x;
					Display3.FillPattern(mask, Display3.invertC, Display.grey2, fx, fy, mx, fy + InfoH, 1, frame.H - InfoH, Display.invert);
					Oberon.DrawCursor(Oberon.Mouse, Effects.PointHand, x, y)
				END
			UNTIL keys = {};
			Oberon.FadeCursor(Oberon.Mouse);
			Display3.FillPattern(mask, Display3.invertC, Display.grey2, fx, fy, mx, fy + InfoH, 1, frame.H - InfoH, Display.invert);
			IF msg.keys = {MM} THEN
				Display3.FillPattern(mask, Display3.invertC, Display.grey2, fx, fy, msg.X, fy + InfoH, 1, frame.H - InfoH, Display.invert)
			END;
			IF keysum = {ML} THEN Scroll(frame, fx + RulerW - mx, 0)
			ELSIF keysum = {MM} THEN Scroll(frame, mx - msg.X, 0)
			ELSIF keysum = {MR} THEN Scroll(frame, fx + frame.W - mx, 0)
			END
		END
	END TrackHRuler;

	PROCEDURE TrackOrigin (tool: Tool; fx, fy: SIGNED16; VAR msg: Oberon.InputMsg);
		VAR
			frame: LeoFrames.Frame; mask: Display3.Mask; zx, zy, px, py: FLOAT32; ox, oy, hx, hy, len, mx, my, l, x, y: SIGNED16;
			keysum, keystate, keys, kstate: SET; s: ARRAY 64 OF CHAR; dm: Display.DisplayMsg;
	BEGIN
		frame := tool.frame;
		Gadgets.MakeMask(frame, fx, fy, msg.dlink, mask);
		IF msg.keys = {} THEN
			len := 0; Append("ML: move origin, MM: reset view, MR: reset origin", s, len);
			ShowStatus(frame, fx, fy, mask, s)
		ELSE
			Oberon.RemoveMarks(fx, fy + frame.H - RulerH, RulerW, RulerH);
			Display3.Rect(mask, Display3.invertC, Display.solid, fx+2, fy + frame.H - RulerH + 2, RulerW-4, RulerH-4, 1, Display.invert);
			zx := tool.zx; zy := tool.zy; ox := frame.ox; oy := frame.oy;
			PointToFrame(frame, zx, zy, hx, hy);
			IF msg.keys = {ML} THEN
				len := 0; Append("move origin to ", s, len);
				Oberon.FadeCursor(Oberon.Mouse);
				mx := -1; my := -1; keysum := msg.keys; keystate := {};
				REPEAT
					l := len; AppendPoint(tool, zx, zy, s, l);
					ShowStatus(frame, fx, fy, mask, s);
					px := zx; py := zy;
					REPEAT
						Input.Mouse(keys, x, y); keysum := keysum + keys;
						IF (keys # {}) & ((x # mx) OR (y # my)) THEN
							Oberon.FadeCursor(Oberon.Mouse);
							IF Effects.Inside(x, y, fx + RulerW, fy + InfoH, frame.W - RulerW, frame.H - AuxH) THEN
								FrameToPoint(frame, x - fx, y - fy, zx, zy);
								Align(tool, zx, zy, zx, zy);
								PointToFrame(frame, zx, zy, hx, hy);
								ShowHints(tool, fx, fy, mask, hx, hy, Input.CTRL IN keystate);
								Oberon.DrawCursor(Oberon.Mouse, Effects.Cross, x, y)
							ELSE
								zx := tool.zx; zy := tool.zy;
								Oberon.DrawCursor(Oberon.Mouse, Effects.Arrow, x, y)
							END;
							mx := x; my := y
						END;
						Input.KeyState(kstate)
					UNTIL (keys = {}) OR (zx # px) OR (zy # py) OR (kstate # keystate);
					ShowHints(tool, fx, fy, mask, hx, hy, Input.CTRL IN kstate);
					keystate := kstate
				UNTIL keys = {}
			ELSE
				IF msg.keys = {MR} THEN
					s := "reset origin"; zx := 0; zy := 0;
				ELSIF msg.keys = {MM} THEN
					s := "reset view"; ox := 0; oy := 0
				END;
				ShowStatus(frame, fx, fy, mask, s);
				keysum := msg.keys;
				REPEAT
					Input.Mouse(keys, x, y); keysum := keysum + keys;
					Oberon.DrawCursor(Oberon.Mouse, Effects.Arrow, x, y)
				UNTIL keys = {}
			END;

			Oberon.FadeCursor(Oberon.Mouse);
			ClearHints(tool, fx, fy, mask); ClearStatus(frame, fx, fy, mask);
			Display3.Rect(mask, Display3.invertC, Display.solid, fx+2, fy + frame.H - RulerH + 2, RulerW-4, RulerH-4, 1, Display.invert);
			IF keysum = msg.keys THEN
				tool.zx := zx; tool.zy := zy; frame.ox := ox; frame.oy := oy;
				dm.F := frame; dm.device := Display.screen; dm.id := Display.full; Display.Broadcast(dm)
			END
		END
	END TrackOrigin;

	PROCEDURE TrackZoom (frame: LeoFrames.Frame; fx, fy: SIGNED16; VAR msg: Oberon.InputMsg);
		VAR
			mask: Display3.Mask; scale: FLOAT32; len, x, y: SIGNED16; s: ARRAY 64 OF CHAR; keysum, keys: SET;
			dm: Display.DisplayMsg;
	BEGIN
		Gadgets.MakeMask(frame, fx, fy, msg.dlink, mask);
		IF msg.keys = {} THEN
			len := 0; Append("ML: zoom in, MM: reset zoom, MR: zoom out", s, len);
			ShowStatus(frame, fx, fy, mask, s)
		ELSE
			Oberon.RemoveMarks(fx, fy, RulerW, RulerH);
			Display3.Rect(mask, Display3.invertC, Display.solid, fx+2, fy+2, RulerW-4, InfoH-4, 1, Display.invert);
			scale := frame.scale;
			len := 0; Append("zoom to ", s, len);
			IF msg.keys = {MR} THEN
				CASE ENTIER(100*scale) OF
				| 0..25: Append("15% (min)", s, len); scale := 0.15
				| 26..50: Append("25%", s, len); scale := 0.25
				| 51..75: Append("50%", s, len); scale := 0.5
				| 76..100: Append("75%", s, len); scale := 0.75
				| 101..150: Append("100%", s, len); scale := 1.0
				| 151..200: Append("150%", s, len); scale := 1.5
				| 201..250: Append("200%", s, len); scale := 2.0
				| 251..375: Append("250%", s, len); scale := 2.5
				| 376..500: Append("375%", s, len); scale := 3.75
				ELSE Append("500%", s, len); scale := 5.0
				END
			ELSIF msg.keys = {ML} THEN
				CASE ENTIER(100*scale) OF
				| 0..24: Append("25%", s, len); scale := 0.25
				| 25..49: Append("50%", s, len); scale := 0.5
				| 50..74: Append("75%", s, len); scale := 0.75
				| 75..99: Append("100%", s, len); scale := 1.0
				| 100..149: Append("150%", s, len); scale := 1.5
				| 150..199: Append("200%", s, len); scale := 2.0
				| 200..249: Append("250%", s, len); scale := 2.5
				| 250..374: Append("375%", s, len); scale := 3.75
				| 375..499: Append("500%", s, len); scale := 5.0
				ELSE Append("750% (max)", s, len); scale := 7.5
				END
			ELSE
				Append("100% (reset)", s, len); scale := 1.0
			END;
			ShowStatus(frame, fx, fy, mask, s);
			keysum := msg.keys;
			REPEAT
				Input.Mouse(keys, x, y); keysum := keysum + keys;
				Oberon.DrawCursor(Oberon.Mouse, Effects.Arrow, x, y)
			UNTIL keys = {};
			Oberon.FadeCursor(Oberon.Mouse);
			ClearStatus(frame, fx, fy, mask);
			Display3.Rect(mask, Display3.invertC, Display.solid, fx+2, fy+2, RulerW-4, InfoH-4, 1, Display.invert);
			IF keysum = msg.keys THEN
				frame.scale := scale;
				dm.F := frame; dm.device := Display.screen; dm.id := Display.full; Display.Broadcast(dm)
			END
		END
	END TrackZoom;

	PROCEDURE TrackFocus (tool: Tool; VAR msg: Oberon.InputMsg);
		VAR
			frame: LeoFrames.Frame; fx, fy, len, mx, my, x, y, hx, hy: SIGNED16; mask: Display3.Mask; x0, y0, tol, x1, y1: FLOAT32;
			s: ARRAY 128 OF CHAR; keys, keystate, kstate: SET;
	BEGIN
		frame := tool.frame;
		fx := msg.x + frame.X; fy := msg.y + frame.Y;
		Gadgets.MakeMask(frame, fx, fy, msg.dlink, mask);
		Oberon.RemoveMarks(fx, fy, frame.W, frame.H);

		(* get first focus point and style *)
		FrameToPoint(frame, msg.X - fx, msg.Y - fy, x0, y0);
		Align(tool, x0, y0, x0, y0);
		IF Focus.frame # frame THEN
			Oberon.Defocus;
			Focus.frame := frame; Focus.style := scale; Focus.visible := FALSE
		ELSE
			HideFocus(fx, fy, mask);
			Attributes.GetReal(Tolerance, "Value", tol); tol := tol/frame.scale;
			IF (Focus.points > 0) & (ABS(x0 - Focus.x[0]) <= tol) & (ABS(y0 - Focus.y[0]) <= tol) THEN	(* change style *)
				x0 := Focus.x[0]; y0 := Focus.y[0];
				CycleFocus
			ELSE	(* new location always starts with scale focus *)
				Focus.style := scale
			END
		END;
		Focus.x[0] := x0; Focus.y[0] := y0; Focus.points := 1;
		ShowFocus(fx, fy, mask);
		len := 0; AppendFocus(tool, s, len);
		ShowStatus(frame, fx, fy, mask, s);

		(* track mouse until it's clear if a second point is being specified *)
		mx := -1; my := -1; x1 := x0; y1 := y0;
		REPEAT
			Input.Mouse(keys, x, y);
			IF (keys # {}) & ((x # mx) OR (y # my)) THEN
				FrameToPoint(frame, x - fx, y - fy, x1, y1);
				Align(tool, x0, y0, x1, y1);
				mx := x; my := y;
				Oberon.DrawCursor(Oberon.Mouse, Effects.Cross, x, y)
			END
		UNTIL (keys = {}) OR (ABS(x1 - x0) > tol) OR (ABS(y1 - y0) > tol);

		IF keys # {} THEN	(* track line to auxiliary focus point *)
			Oberon.FadeCursor(Oberon.Mouse);
			FlipFocus(fx, fy, mask);
			Focus.x[1] := x1; Focus.y[1] := y1; Focus.points := 2;
			IF Focus.style = rotate THEN Focus.style := shear END;
			FlipFocus(fx, fy, mask);
			mx := -1; my := -1; Input.KeyState(keystate);
			REPEAT
				Input.Mouse(keys, x, y); Input.KeyState(kstate);
				IF (keys # {}) & ((x # mx) OR (y # my) OR (kstate # keystate)) THEN
					Oberon.FadeCursor(Oberon.Mouse);
					FlipFocus(fx, fy, mask);
					FrameToPoint(frame, x - fx, y - fy, x1, y1);
					Align(tool, x0, y0, x1, y1);
					PointToFrame(frame, x1, y1, hx, hy);
					ShowHints(tool, fx, fy, mask, hx, hy, Input.CTRL IN kstate);
					mx := x; my := y; keystate := kstate; Focus.x[1] := x1; Focus.y[1] := y1;
					FlipFocus(fx, fy, mask);
					len := 0; AppendFocus(tool, s, len);
					ShowStatus(frame, fx, fy, mask, s);
					Oberon.DrawCursor(Oberon.Mouse, Effects.Cross, x, y)
				END
			UNTIL keys = {}

		ELSIF Focus.style = translate THEN	(* translate with one reference point is same as no points *)
			Oberon.FadeCursor(Oberon.Mouse);
			FlipFocus(fx, fy, mask);
			Focus.points := 0
		END
	END TrackFocus;

	PROCEDURE TrackMove (tool: Tool; VAR msg: Oberon.InputMsg);
		VAR
			frame: LeoFrames.Frame; fx, fy, len, mx, my, l, x, y, hx, hy: SIGNED16; x0, y0, tol, x1, y1, px, py: FLOAT32;
			fig: Leonardo.Figure; loc, shapes, recv: Leonardo.Shape; mask: Display3.Mask; s: ARRAY 128 OF CHAR;
			keysum, keystate, keys, kstate: SET; mat: GfxMatrix.Matrix; mm: Leonardo.MatrixMsg;
			cm: Display.ConsumeMsg;
	BEGIN
		(* get list of shapes to move *)
		frame := tool.frame;
		fx := msg.x + frame.X; fy := msg.y + frame.Y;
		FrameToPoint(frame, msg.X - fx, msg.Y - fy, x0, y0);
		Align(tool, x0, y0, x0, y0);
		fig := frame.obj(Leonardo.Figure);
		Attributes.GetReal(Tolerance, "Value", tol); tol := tol/frame.scale;
		loc := Leonardo.Locate(fig, Leonardo.overlap, x0 - tol, y0 - tol, x0 + tol, y0 + tol);
		IF (loc # NIL) & (~loc.sel OR (loc IS Leonardo.Container) & loc(Leonardo.Container).subsel) THEN	(* select located shape *)
			loc.slink := NIL;
			Leonardo.DisableUpdate(fig);
			Leonardo.ClearSelection(fig); Leonardo.Select(fig, loc);
			Leonardo.EnableUpdate(fig)
		END;
		shapes := Leonardo.Selection(fig);

		IF shapes # NIL THEN
			(* set up drag loop *)
			Gadgets.MakeMask(frame, fx, fy, msg.dlink, mask);
			len := 0; AppendFocus(tool, s, len);
			Reset(frame, fx, fy);
			Oberon.FadeCursor(Oberon.Mouse);
			keysum := msg.keys; mx := -1; my := -1; x1 := x0; y1 := y0;
			REPEAT
				l := len;
				CalcDrag(tool, x0, y0, x1, y1, mat, s, l);
				IF loc # NIL THEN
					Objects.Stamp(mm); mm.dest := loc; mm.done := FALSE;
					mm.x0 := x0; mm.y0 := y0; mm.x1 := x1; mm.y1 := y1; mm.tol := tol;
					fig.handle(fig, mm);
					IF mm.done THEN
						mat := mm.mat; s[0] := 0X
					END
				END;
				Leonardo.BeginTransform(fig, shapes, mat);
				Leonardo.Render(fig, Leonardo.marked, DC);
				Input.KeyState(keystate);
				PointToFrame(frame, x1, y1, hx, hy);
				ShowHints(tool, fx, fy, mask, hx, hy, Input.CTRL IN keystate);
				ShowStatus(frame, fx, fy, mask, s);
				px := x1; py := y1;
				REPEAT
					Input.Mouse(keys, x, y); keysum := keysum + keys;
					IF (keys # {}) & ((x # mx) OR (y # my)) THEN
						Oberon.DrawCursor(Oberon.Mouse, Effects.Cross, x, y);
						FrameToPoint(frame, x - fx, y - fy, x1, y1);
						Align(tool, x0, y0, x1, y1);
						mx := x; my := y
					END;
					Input.KeyState(kstate)
				UNTIL (keys = {}) OR (x1 # px) OR (y1 # py) OR (kstate # keystate);
				Oberon.FadeCursor(Oberon.Mouse);
				Leonardo.Render(fig, Leonardo.marked, DC);
				Leonardo.CancelTransform(fig)
			UNTIL keys = {};

			IF keysum = {MM} THEN
				Leonardo.Transform(fig, shapes, mat)
			ELSIF keysum # {ML, MM, MR} THEN
				Leonardo.DisableUpdate(fig);
				IF keysum = {MM, ML} THEN	(* consume selection at new mouse location *)
					Leonardo.BeginCommand(fig);
					Leonardo.Transform(fig, shapes, mat);
					Leonardo.Consume(fig, x1 - tol, y1 - tol, x1 + tol, y1 + tol, shapes, recv);
					Leonardo.EndCommand(fig)
				ELSIF keysum = {MM, MR} THEN	(* integrate copy of selection at new mouse location *)
					Gadgets.ThisFrame(mx, my, cm.F, cm.u, cm.v);
					IF cm.F # frame THEN	(* copy to different frame *)
						mat[2, 0] := mat[2, 0] - x1; mat[2, 1] := mat[2, 1] - y1
					END;
					Leonardo.BeginCommand(fig);
					Leonardo.Transform(fig, shapes, mat);
					Leonardo.Clone(fig, shapes, shapes);
					Leonardo.CancelCommand(fig);	(* return original shapes to old location *)
					IF cm.F # frame THEN
						cm.id := Display.drop; cm.obj := shapes; Display.Broadcast(cm)
					ELSE
						Leonardo.Integrate(fig, shapes)
					END
				END;
				Leonardo.EnableUpdate(fig)
			END
		END
	END TrackMove;

	PROCEDURE TrackSelection (tool: Tool; VAR msg: Oberon.InputMsg);
		VAR
			frame: LeoFrames.Frame; fx, fy, mx, my, rx, ry, rw, rh, x, y: SIGNED16; mask: Display3.Mask;
			px, py, d, llx, lly, urx, ury: FLOAT32; fig: Leonardo.Figure; shape, sh: Leonardo.Shape; keys, keysum: SET;
			obj: Objects.Object;
	BEGIN
		frame := tool.frame;
		fx := msg.x + frame.X; fy := msg.y + frame.Y;
		Gadgets.MakeMask(frame, fx, fy, msg.dlink, mask);
		ClearHints(tool, fx, fy, mask); ClearStatus(frame, fx, fy, mask);

		(* locate shape(s) at mouse pos *)
		FrameToPoint(frame, msg.X - fx, msg.Y - fy, px, py);
		Align(tool, px, py, px, py);
		Attributes.GetReal(Tolerance, "Value", d); d := d/frame.scale;
		fig := frame.obj(Leonardo.Figure);
		shape := Leonardo.Locate(fig, Leonardo.overlap, px - d, py - d, px + d, py + d);

		(* flip selection state of located shape (possibly clearing selection first) *)
		Leonardo.DisableUpdate(fig);
		Input.KeyState(keys);
		IF ~(Input.SHIFT IN keys) THEN
			Leonardo.ClearSelection(fig)
		END;
		IF shape # NIL THEN
			shape.slink := NIL;
			IF shape.sel THEN Leonardo.Deselect(fig, shape)
			ELSE Leonardo.Select(fig, shape)
			END
		END;
		Leonardo.EnableUpdate(fig);

		keysum := msg.keys;
		REPEAT
			Input.Mouse(keys, mx, my); keysum := keysum + keys;
			Oberon.DrawCursor(Oberon.Mouse, Effects.PointHand, mx, my)
		UNTIL (keys = {}) OR (ABS(mx - msg.X) + ABS(my - msg.Y) >= 8);
		IF (keys # {}) & (shape # NIL) THEN	(* flip selection back *)
			IF shape.sel THEN Leonardo.Deselect(fig, shape)
			ELSE Leonardo.Select(fig, shape)
			END
		END;

		Leonardo.DisableUpdate(fig);
		IF keys # {} THEN	(* track selection rectangle *)
			Input.KeyState(keys);
			IF ~(Input.SHIFT IN keys) THEN
				Leonardo.ClearSelection(fig)
			END;
			mx := -1; my := -1; rx := msg.X; ry := msg.Y; rw := 0; rh := 0;
			Oberon.FadeCursor(Oberon.Mouse);
			Display3.Rect(mask, Display3.invertC, Display.grey2, rx, ry, rw, rh, 1, Display.invert);
			REPEAT
				Input.Mouse(keys, x, y); keysum := keysum + keys;
				IF (keys # {}) & ((x # mx) OR (y # my)) THEN
					Oberon.FadeCursor(Oberon.Mouse);
					Display3.Rect(mask, Display3.invertC, Display.grey2, rx, ry, rw, rh, 1, Display.invert);
					mx := x; my := y;
					IF mx > msg.X THEN rx := msg.X ELSE rx := mx END;
					IF my > msg.Y THEN ry := msg.Y ELSE ry := my END;
					rw := ABS(mx - msg.X); rh := ABS(my - msg.Y);
					Display3.Rect(mask, Display3.invertC, Display.grey2, rx, ry, rw, rh, 1, Display.invert);
					Oberon.DrawCursor(Oberon.Mouse, Effects.PointHand, mx, my)
				END
			UNTIL keys = {};
			Oberon.FadeCursor(Oberon.Mouse);
			Display3.Rect(mask, Display3.invertC, Display.grey2, rx, ry, rw, rh, 1, Display.invert);
			FrameToPoint(frame, rx - fx, ry - fy, llx, lly);
			FrameToPoint(frame, rx + rw - fx, ry + rh - fy, urx, ury);
			shape := Leonardo.Locate(fig, Leonardo.inside, llx, lly, urx, ury);
			obj := shape;
			WHILE obj # NIL DO
				sh := obj(Leonardo.Shape); sh.sel := ~sh.sel; obj := obj.slink;
				Leonardo.UpdateShape(fig, sh)
			END;
			Leonardo.ValidateSelection(fig)
		END;

		IF keysum = {ML, MR} THEN
			Leonardo.Delete(fig, Leonardo.Selection(fig))
		END;
		Leonardo.EnableUpdate(fig)
	END TrackSelection;

	(** default mouse handling if no button is pressed **)
	PROCEDURE TrackTool* (tool: Tool; str: ARRAY OF CHAR; marker: Oberon.Marker; VAR msg: Oberon.InputMsg);
		VAR
			frame: LeoFrames.Frame; fx, fy, len, hx, hy: SIGNED16; x, y: FLOAT32; state: SET; mask: Display3.Mask;
			s: ARRAY 128 OF CHAR;
	BEGIN
		frame := tool.frame;
		fx := msg.x + frame.X; fy := msg.y + frame.Y;
		FrameToPoint(frame, msg.X - fx, msg.Y - fy, x, y);
		Align(tool, x, y, x, y);
		Input.KeyState(state);
		Gadgets.MakeMask(frame, fx, fy, msg.dlink, mask);
		PointToFrame(frame, x, y, hx, hy);
		ShowHints(tool, fx, fy, mask, hx, hy, Input.CTRL IN state);
		len := 0; AppendTool(tool, x, y, str, s, len);
		ShowStatus(frame, fx, fy, mask, s);
		Oberon.DrawCursor(Oberon.Mouse, marker, msg.X, msg.Y);
		msg.res := 0
	END TrackTool;

	(** default mouse tracker **)
	PROCEDURE Track* (tool: Tool; VAR msg: Oberon.InputMsg);
		VAR
			frame: LeoFrames.Frame; fx, fy, mx, my, len, hx, hy: SIGNED16; mask: Display3.Mask; keys: SET; px, py: FLOAT32;
			s: ARRAY 128 OF CHAR;
	BEGIN
		ASSERT(~(Gadgets.selected IN tool.frame.state), 100);
		frame := tool.frame;
		fx := msg.x + frame.X; fy := msg.y + frame.Y;
		Gadgets.MakeMask(frame, fx, fy, msg.dlink, mask);
		IF InContents(msg.X, msg.Y, fx, fy, frame.W, frame.H) THEN
			IF msg.keys = {ML} THEN
				TrackFocus(tool, msg)
			ELSIF msg.keys = {MM} THEN
				TrackMove(tool, msg)
			ELSIF msg.keys = {MR} THEN
				TrackSelection(tool, msg)
			END;
			Input.Mouse(keys, mx, my);
			FrameToPoint(frame, mx - fx, my - fy, px, py);
			Align(tool, px, py, px, py);
			Input.KeyState(keys);
			PointToFrame(frame, px, py, hx, hy);
			Gadgets.MakeMask(frame, fx, fy, msg.dlink, mask);	(* mask may have been adjusted *)
			ShowHints(tool, fx, fy, mask, hx, hy, Input.CTRL IN keys);
			len := 0; AppendTool(tool, px, py, "set/change focus", s, len);
			ShowStatus(frame, fx, fy, mask, s);
			Oberon.DrawCursor(Oberon.Mouse, Effects.Cross, mx, my);
			msg.res := 0
		ELSE
			ClearHints(tool, fx, fy, mask);
			IF Effects.Inside(msg.X, msg.Y, fx, fy + InfoH, RulerW, frame.H - AuxH) THEN
				ClearStatus(frame, fx, fy, mask); TrackVRuler(frame, fx, fy, msg)
			ELSIF Effects.Inside(msg.X, msg.Y, fx + RulerW, fy + frame.H - RulerH, frame.W - RulerW, RulerH) THEN
				ClearStatus(frame, fx, fy, mask); TrackHRuler(frame, fx, fy, msg)
			ELSIF Effects.Inside(msg.X, msg.Y, fx, fy + frame.H - RulerH, RulerW, RulerH) THEN
				TrackOrigin(tool, fx, fy, msg)
			ELSIF Effects.Inside(msg.X, msg.Y, fx, fy, RulerW, RulerH) THEN
				TrackZoom(frame, fx, fy, msg)
			ELSE
				ClearStatus(frame, fx, fy, mask)
			END;
			Input.Mouse(keys, mx, my);
			Oberon.DrawCursor(Oberon.Mouse, Effects.Arrow, mx, my);
			msg.res := 0
		END
	END Track;


	(**--- Default Tool ---**)

	PROCEDURE Consume (frame: LeoFrames.Frame; VAR msg: Display.ConsumeMsg);
		VAR fig: Leonardo.Figure; shapes: Leonardo.Shape; x, y: FLOAT32; mat: GfxMatrix.Matrix;
	BEGIN
		IF (msg.id = Display.drop) & (msg.F = frame) & (msg.obj IS Leonardo.Shape) THEN
			fig := frame.obj(Leonardo.Figure); shapes := msg.obj(Leonardo.Shape);
			Leonardo.DisableUpdate(fig);
			Leonardo.BeginCommand(fig);
			Leonardo.Integrate(fig, shapes);
			FrameToPoint(frame, msg.u, msg.v + (frame.H-1), x, y);
			Align(Current(frame), x, y, x, y);
			GfxMatrix.Init(mat, 1, 0, 0, 1, x, y);
			Leonardo.Transform(fig, shapes, mat);
			Leonardo.EndCommand(fig);
			Leonardo.EnableUpdate(fig)
		END
	END Consume;

	PROCEDURE HandleFrame* (obj: Objects.Object; VAR msg: Objects.ObjMsg);
		VAR frame: LeoFrames.Frame; fx, fy: SIGNED16; mask: Display3.Mask;
	BEGIN
		frame := obj(LeoFrames.Frame);
		IF msg IS Display.FrameMsg THEN
			WITH msg: Display.FrameMsg DO
				IF (msg.F = frame) OR (msg.F = NIL) THEN
					IF msg IS Oberon.InputMsg THEN
						WITH msg: Oberon.InputMsg DO
							IF (msg.id = Oberon.track) & ~(Gadgets.selected IN frame.state) THEN Track(Current(frame), msg)
							ELSE LeoFrames.Handle(frame, msg)
							END
						END
					ELSIF msg IS Oberon.ControlMsg THEN
						IF (msg(Oberon.ControlMsg).id IN {Oberon.neutralize, Oberon.defocus}) & (frame = Focus.frame) THEN
							fx := msg.x + frame.X; fy := msg.y + frame.Y;
							Gadgets.MakeMask(frame, fx, fy, msg.dlink, mask);
							HideFocus(fx, fy, mask); Focus.frame := NIL
						END;
						LeoFrames.Handle(frame, msg)
					ELSIF msg IS Leonardo.UpdateMsg THEN
						IF frame = Focus.frame THEN
							fx := msg.x + frame.X; fy := msg.y + frame.Y;
							Gadgets.MakeMask(frame, fx, fy, msg.dlink, mask);
							HideFocus(fx, fy, mask)
						END;
						Update(Current(frame), msg(Leonardo.UpdateMsg));
						IF frame = Focus.frame THEN
							ShowFocus(fx, fy, mask)
						END
					ELSIF msg IS Display.DisplayMsg THEN
						WITH msg: Display.DisplayMsg DO
							IF msg.device = Display.screen THEN
								fx := msg.x + frame.X; fy := msg.y + frame.Y;
								Gadgets.MakeMask(frame, fx, fy, msg.dlink, mask);
								IF frame = Focus.frame THEN
									HideFocus(fx, fy, mask)
								END;
								IF (msg.id = Display.full) OR (msg.F = NIL) THEN
									Restore(Current(frame), 0, 0, frame.W, frame.H, fx, fy, mask)
								ELSIF msg.id = Display.area THEN
									Display3.AdjustMask(mask, fx + msg.u, fy + (frame.H-1) + msg.v, msg.w, msg.w);
									Restore(Current(frame), msg.u, msg.v + (frame.H-1), msg.w, msg.h, fx, fy, mask)
								END;
								IF frame = Focus.frame THEN
									ShowFocus(fx, fy, mask)
								END
							ELSIF msg.device = Display.printer THEN
								Print(Current(frame), msg)
							END
						END
					ELSIF msg IS Display.ModifyMsg THEN
						fx := msg.x + frame.X; fy := msg.y + frame.Y;
						Gadgets.MakeMask(frame, fx, fy, msg.dlink, mask);
						ClearHints(Current(frame), fx, fy, mask);
						IF frame = Focus.frame THEN
							HideFocus(fx, fy, mask); Focus.frame := NIL
						END;
						Gadgets.Adjust(frame, msg(Display.ModifyMsg))
					ELSIF msg IS Display.ControlMsg THEN
						IF (msg(Display.ControlMsg).id = Display.suspend) & (frame = Focus.frame) THEN
							fx := msg.x + frame.X; fy := msg.y + frame.Y;
							Gadgets.MakeMask(frame, fx, fy, msg.dlink, mask);
							HideFocus(fx, fy, mask)
						END;
						LeoFrames.Handle(frame, msg)
					ELSIF msg IS Display.ConsumeMsg THEN
						Consume(frame, msg(Display.ConsumeMsg))
					ELSIF msg IS ToolMsg THEN
						fx := msg.x + frame.X; fy := msg.y + frame.Y;
						Gadgets.MakeMask(frame, fx, fy, msg.dlink, mask);
						ClearStatus(frame, fx, fy, mask);
						IF frame = Focus.frame THEN
							HideFocus(fx, fy, mask); Focus.frame := NIL
						END;
						frame.handle := msg(ToolMsg).handle
					ELSE
						LeoFrames.Handle(frame, msg)
					END
				END
			END
		ELSIF msg IS Objects.AttrMsg THEN
			WITH msg: Objects.AttrMsg DO
				IF (msg.id = Objects.get) & (msg.name = "Gen") THEN
					msg.class := Objects.String; msg.s := "LeoTools.NewFrame"; msg.res := 0
				ELSE
					LeoFrames.Handle(frame, msg)
				END
			END
		ELSIF msg IS Objects.LinkMsg THEN
			WITH msg: Objects.LinkMsg DO
				IF (msg.id = Objects.get) & (msg.name = "Editor") THEN
					msg.obj := Gadgets.CreateObject("LeoPanels.NewFocus");
					IF msg.obj # NIL THEN msg.res := 0 END
				ELSE
					LeoFrames.Handle(frame, msg)
				END
			END
		ELSE
			LeoFrames.Handle(frame, msg)
		END
	END HandleFrame;


	(**--- Tool Activation ---**)

	(** ask every visible tool frame to install new handler and copy of tool object **)
	PROCEDURE Activate* (handle: Objects.Handler);
		VAR tm: ToolMsg;
	BEGIN
		ToolHandler := handle;
		tm.F := NIL; tm.handle := handle;
		Display.Broadcast(tm)
	END Activate;

	(** activate focus tool **)
	PROCEDURE ActivateFocus*;
	BEGIN
		Activate(HandleFrame)
	END ActivateFocus;


	(**--- Legacy Support ---**)

	PROCEDURE HandleLegacyFrame (obj: Objects.Object; VAR msg: Objects.ObjMsg);
		VAR
			frame: LeoFrames.Frame; ver, l: SIGNED32; set: SET; real: FLOAT32; int, red, green, blue, dr, dg, db: SIGNED16;
			bool: BOOLEAN; tool: Tool;
	BEGIN
		IF msg IS Objects.FileMsg THEN
			WITH msg: Objects.FileMsg DO
				ASSERT(msg.id = Objects.load, 110);
				frame := obj(LeoFrames.Frame);
				Gadgets.framehandle(frame, msg);

				Files.ReadNum(msg.R, ver);
				ASSERT((1 <= ver) & (ver <= 3), 111);

				(* first part of code is same as in FigureGadgets *)
				IF ver = 1 THEN
					Files.ReadSet(msg.R, set); Files.ReadReal(msg.R, real); Files.ReadInt(msg.R, int); frame.col := int
				ELSE
					Files.ReadBool(msg.R, bool);	(* buffered *)
					IF ver = 2 THEN
						Files.ReadLInt(msg.R, l);
						frame.col := SIGNED16(ASH(l, -24) MOD 100H)
					ELSIF ver >= 3 THEN
						Files.ReadInt(msg.R, red); Files.ReadInt(msg.R, green); Files.ReadInt(msg.R, blue);
						int := 0;
						LOOP
							IF int = 256 THEN
								frame.col := Colors.Match(Colors.DisplayIndex, Colors.DisplayBits, red, green, blue);
								EXIT
							END;
							Display.GetColor(int, dr, dg, db);
							IF (dr = red) & (dg = green) & (db = blue) THEN
								frame.col := int;
								EXIT
							END;
							INC(int)
						END
					END
				END;
				Files.ReadReal(msg.R, frame.scale);
				Files.ReadReal(msg.R, real); frame.ox := SHORT(ENTIER(real));
				Files.ReadReal(msg.R, real); frame.oy := SHORT(ENTIER(real));

				(* read old LeoFrames data *)
				Files.ReadNum(msg.R, ver);
				ASSERT(ver = 1, 110);
				tool := Current(frame);
				Files.ReadReal(msg.R, tool.unit);
				Files.ReadInt(msg.R, tool.grid.ticks);
				Files.ReadBool(msg.R, tool.grid.active);

				frame.handle := ToolHandler
			END
		ELSE
			ToolHandler(obj, msg)
		END
	END HandleLegacyFrame;

	PROCEDURE NewLegacyFrame*;
		VAR frame: LeoFrames.Frame;
	BEGIN
		NEW(frame); InitFrame(frame, NIL); frame.handle := HandleLegacyFrame;
		Objects.NewObj := frame
	END NewLegacyFrame;


BEGIN
	InitMethods;
	NEW(DC); DC.do := Methods;
	Unit := Gadgets.FindPublicObj("Leonardo.FrameUnit");
	IF Unit = NIL THEN
		Unit := Gadgets.CreateObject("Real"); Attributes.SetReal(Unit, "Value", cm)
	END;
	PageWidth := Gadgets.FindPublicObj("Leonardo.PageWidth");
	IF PageWidth = NIL THEN
		PageWidth := Gadgets.CreateObject("Real"); Attributes.SetReal(PageWidth, "Value", A4W)
	END;
	PageHeight := Gadgets.FindPublicObj("Leonardo.PageHeight");
	IF PageHeight = NIL THEN
		PageHeight := Gadgets.CreateObject("Real"); Attributes.SetReal(PageHeight, "Value", A4H)
	END;
	Buffered := Gadgets.FindPublicObj("Leonardo.Buffered");
	IF Buffered = NIL THEN
		Buffered := Gadgets.CreateObject("Boolean"); Attributes.SetBool(Buffered, "Value", TRUE)
	END;
	GridTicks := Gadgets.FindPublicObj("Leonardo.GridTicks");
	IF GridTicks = NIL THEN
		GridTicks := Gadgets.CreateObject("Integer"); Attributes.SetInt(GridTicks, "Value", 10)
	END;
	GridVisible := Gadgets.FindPublicObj("Leonardo.GridVisible");
	IF GridVisible = NIL THEN
		GridVisible := Gadgets.CreateObject("Boolean"); Attributes.SetBool(GridVisible, "Value", TRUE)
	END;
	GridActive := Gadgets.FindPublicObj("Leonardo.GridActive");
	IF GridActive = NIL THEN
		GridActive := Gadgets.CreateObject("Boolean"); Attributes.SetBool(GridActive, "Value", TRUE)
	END;
	Tolerance := Gadgets.FindPublicObj("Leonardo.Tolerance");
	IF Tolerance = NIL THEN
		Tolerance := Gadgets.CreateObject("Real"); Attributes.SetReal(Tolerance, "Value", 5)
	END;
	AlignAxes := Gadgets.FindPublicObj("Leonardo.AlignAxes");
	IF AlignAxes = NIL THEN
		AlignAxes := Gadgets.CreateObject("Integer"); Attributes.SetInt(AlignAxes, "Value", 8)
	END;
	ToolHandler := HandleFrame;	(* default tool *)
	InitFocusPatterns;
	Font := Fonts.This("Oberon10.Scn.Fnt");
	NEW(Pict); Pictures.Create(Pict, 640, Font.height, Pictures.colorD);
	NEW(BC); NEW(BC.img); GfxBuffer.Init(BC, BC.img)
END LeoTools.
