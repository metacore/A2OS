(* ETH Oberon, Copyright 2001 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

MODULE LeoBasic IN Oberon; (** portable **)	(* eos  *)

	(**
		Basic Leonardo Shapes
	**)

	IMPORT
		Files, Math IN A2, Objects, Attributes, Gadgets, GfxMatrix, Gfx, Leonardo, LeoPens, LeoPaths;


	TYPE
		Frame* = POINTER TO FrameDesc;
		FrameDesc* = RECORD (Leonardo.ContainerDesc)
			pen*: LeoPens.Pen;	(** pen for rendering **)
			mat*: GfxMatrix.Matrix;	(** mapping from unit square at (0, 0) to frame coordinates **)
		END;

		Link* = POINTER TO LinkDesc;
		LinkDesc* = RECORD (LeoPaths.PointDesc)
			lx*, ly*: FLOAT32;	(** logical coordinates within frame **)
		END;

		Rectangle* = Frame;
		Ellipse* = Frame;

		Group* = Leonardo.Container;


	(**--- Links ---**)

	PROCEDURE CopyLink* (VAR msg: Objects.CopyMsg; from, to: Link);
	BEGIN
		LeoPaths.CopyPoint(msg, from, to);
		to.lx := from.lx; to.ly := from.ly
	END CopyLink;

	PROCEDURE HandleLink* (obj: Objects.Object; VAR msg: Objects.ObjMsg);
		VAR l, copy: Link; ver: SIGNED32;
	BEGIN
		l := obj(Link);
		IF msg IS Leonardo.ValidateMsg THEN
			WITH msg: Leonardo.ValidateMsg DO
				IF l.marked THEN
					l.x := l.lx; l.y := l.ly;
					GfxMatrix.Apply(msg.lgm, l.x, l.y, l.llx, l.lly);
					l.urx := l.llx; l.ury := l.lly;
					l.marked := FALSE; l.cont.marked := TRUE
				END
			END
		ELSIF msg IS Leonardo.ShapeMsg THEN
			LeoPaths.HandlePoint(l, msg)
		ELSIF msg IS Objects.AttrMsg THEN
			WITH msg: Objects.AttrMsg DO
				IF (msg.id = Objects.get) & (msg.name = "Gen") THEN
					msg.class := Objects.String; msg.s := "LeoBasic.NewLink"; msg.res := 0
				ELSE
					LeoPaths.HandlePoint(l, msg)
				END
			END
		ELSIF msg IS Objects.CopyMsg THEN
			WITH msg: Objects.CopyMsg DO
				IF msg.stamp # l.stamp THEN
					NEW(copy); l.dlink := copy; l.stamp := msg.stamp;
					CopyLink(msg, l, copy)
				END;
				msg.obj := l.dlink
			END
		ELSIF msg IS Objects.FileMsg THEN
			WITH msg: Objects.FileMsg DO
				LeoPaths.HandlePoint(l, msg);
				IF msg.id = Objects.store THEN
					Files.WriteNum(msg.R, ver)
				ELSIF msg.id = Objects.load THEN
					Files.ReadNum(msg.R, ver);
					l.lx := l.x; l.ly := l.y
				END
			END
		ELSE
			LeoPaths.HandlePoint(l, msg)
		END
	END HandleLink;

	PROCEDURE InitLink* (l: Link; lx, ly: FLOAT32);
	BEGIN
		LeoPaths.InitPoint(l, lx, ly); l.handle := HandleLink;
		l.lx := lx; l.ly := ly
	END InitLink;

	PROCEDURE NewLink*;
		VAR l: Link;
	BEGIN
		NEW(l); InitLink(l, 0, 0);
		Objects.NewObj := l
	END NewLink;


	(**--- Frames ---**)

	PROCEDURE CalcFrameRect* (f: Frame; VAR mat: GfxMatrix.Matrix);
		VAR m: GfxMatrix.Matrix;
	BEGIN
		GfxMatrix.Concat(f.mat, mat, m);
		GfxMatrix.ApplyToRect(m, 0, 0, 1, 1, f.llx, f.lly, f.urx, f.ury);
		Attributes.GetReal(f.pen, "Border", f.bw);
		GfxMatrix.ApplyToDist(mat, f.bw, f.bw)
	END CalcFrameRect;

	PROCEDURE SelectFrame* (f: Frame; VAR msg: Leonardo.SelectMsg);
		VAR cur: Leonardo.Shape;
	BEGIN
		IF (msg.id = Leonardo.validate) & (f.bottom # NIL) THEN
			Leonardo.ToComponents(f.bottom, msg);
			cur := f.bottom; WHILE (cur # NIL) & ~cur.sel DO cur := cur.up END;
			f.subsel := cur # NIL;
			IF f.subsel & ~f.sel THEN
				f.sel := TRUE;
				Leonardo.UpdateShape(msg.fig, f)
			END
		ELSE
			IF (msg.id = Leonardo.reset) & f.sel THEN
				Leonardo.UpdateShape(msg.fig, f)
			END;
			Leonardo.SelectContainer(f, msg)
		END
	END SelectFrame;

	PROCEDURE ControlFrame* (f: Frame; VAR msg: Leonardo.ControlMsg);
		VAR cur: Leonardo.Shape;
	BEGIN
		IF msg.id = Leonardo.integrate THEN
			(* deny; only accept consume requests *)
		ELSE
			IF msg.id = Leonardo.clone THEN
				cur := f.bottom; WHILE cur # NIL DO cur.marked := FALSE; cur := cur.up END
			END;
			Leonardo.ControlContainer(f, msg)
		END
	END ControlFrame;

	PROCEDURE ValidateFrame* (f: Frame; VAR msg: Leonardo.ValidateMsg);
		VAR lgm: GfxMatrix.Matrix;
	BEGIN
		IF f.bottom # NIL THEN
			lgm := msg.lgm; GfxMatrix.Concat(f.mat, lgm, msg.lgm);
			Leonardo.ToComponents(f.bottom, msg);
			msg.lgm := lgm
		END;
		IF f.marked THEN
			Leonardo.UpdateShape(msg.fig, f);
			CalcFrameRect(f, msg.lgm);
			Leonardo.UpdateShape(msg.fig, f);
			f.marked := FALSE; f.cont.marked := TRUE
		END
	END ValidateFrame;

	PROCEDURE TransformFrame* (f: Frame; VAR msg: Leonardo.TransformMsg);
		VAR glm, mat, lgm: GfxMatrix.Matrix; cur, down: Leonardo.Shape; l: Link; x0, y0, x1, y1: FLOAT32;
	BEGIN
		IF (msg.id = Leonardo.apply) & (msg.stamp # f.stamp) THEN
			f.stamp := msg.stamp;
			IF f.marked THEN
				GfxMatrix.Invert(msg.lgm, glm);
				GfxMatrix.Concat(msg.lgm, msg.mat, mat);
				GfxMatrix.Concat(f.mat, mat, mat);
				GfxMatrix.Concat(mat, glm, mat);
				Leonardo.SetMatrix(msg.fig, f, "M", mat);
				cur := f.bottom;
				WHILE cur # NIL DO
					IF ~cur.marked THEN cur.marked := TRUE; msg.notify := TRUE END;
					cur := cur.up
				END
			ELSIF f.bottom # NIL THEN
				lgm := msg.lgm; GfxMatrix.Concat(f.mat, lgm, msg.lgm);
				Leonardo.ToComponents(f.bottom, msg);
				msg.lgm := lgm;
				cur := f.bottom; WHILE (cur # NIL) & ~cur.marked DO cur := cur.up END;
				IF cur # NIL THEN msg.notify := TRUE END
			END
		ELSIF (msg.id = Leonardo.notify) & (f.bottom # NIL) THEN
			cur := f.bottom; WHILE (cur # NIL) & ~cur.marked DO cur := cur.up END;
			IF (cur # NIL) & ~f.marked THEN
				l := cur(Link);
				GfxMatrix.Concat(f.mat, msg.lgm, lgm);
				GfxMatrix.Apply(lgm, l.lx, l.ly, x0, y0);
				GfxMatrix.Apply(lgm, l.x, l.y, x1, y1);
				GfxMatrix.Init(mat, 1, 0, 0, 1, x1 - x0, y1 - y0);
				l.x := l.lx; l.y := l.ly;	(* direct modification because undoable action has already been added *)
				GfxMatrix.Invert(msg.lgm, glm);
				GfxMatrix.Concat(lgm, mat, mat);
				GfxMatrix.Concat(mat, glm, mat);
				Leonardo.SetMatrix(msg.fig, f, "M", mat);
				f.marked := TRUE; msg.notify := TRUE;
				WHILE cur.down # NIL DO cur := cur.down; cur.marked := TRUE END;
				cur := l.up; down := l;
				WHILE cur # NIL DO
					IF cur.marked THEN Leonardo.AddDeleteAction(msg.fig, down, cur, cur, cur.up, f)
					ELSE down := cur
					END;
					cur := cur.up
				END
			ELSE
				lgm := msg.lgm; GfxMatrix.Concat(f.mat, lgm, msg.lgm);
				Leonardo.ToComponents(f.bottom, msg);
				msg.lgm := lgm
			END
		END
	END TransformFrame;

	PROCEDURE GetFrameMatrix* (f: Frame; VAR msg: Leonardo.MatrixMsg);
		VAR lgm: GfxMatrix.Matrix;
	BEGIN
		IF msg.dest = f THEN
			lgm := msg.lgm; GfxMatrix.Concat(f.mat, msg.lgm, msg.lgm);
			Leonardo.GetHandleMatrix(0, 0, 1, 1, msg);
			msg.lgm := lgm
		END
	END GetFrameMatrix;

	PROCEDURE HandleFrameAttr* (f: Frame; VAR msg: Objects.AttrMsg);
	BEGIN
		IF msg.id = Objects.enum THEN
			Leonardo.HandleContainer(f, msg)
		ELSIF msg.id = Objects.get THEN
			IF msg.name = "M00" THEN msg.class := Objects.Real; msg.x := f.mat[0, 0]; msg.res := 0
			ELSIF msg.name = "M01" THEN msg.class := Objects.Real; msg.x := f.mat[0, 1]; msg.res := 0
			ELSIF msg.name = "M10" THEN msg.class := Objects.Real; msg.x := f.mat[1, 0]; msg.res := 0
			ELSIF msg.name = "M11" THEN msg.class := Objects.Real; msg.x := f.mat[1, 1]; msg.res := 0
			ELSIF msg.name = "M20" THEN msg.class := Objects.Real; msg.x := f.mat[2, 0]; msg.res := 0
			ELSIF msg.name = "M21" THEN msg.class := Objects.Real; msg.x := f.mat[2, 1]; msg.res := 0
			ELSIF msg.name = "X0" THEN msg.class := Objects.Real; msg.x := f.mat[2, 0]; msg.res := 0
			ELSIF msg.name = "Y0" THEN msg.class := Objects.Real; msg.x := f.mat[2, 1]; msg.res := 0
			ELSIF msg.name = "X1" THEN msg.class := Objects.Real; msg.x := f.mat[2, 0] + f.mat[0, 0]; msg.res := 0
			ELSIF msg.name = "Y1" THEN msg.class := Objects.Real; msg.x := f.mat[2, 1] + f.mat[0, 1]; msg.res := 0
			ELSIF msg.name = "X2" THEN msg.class := Objects.Real; msg.x := f.mat[2, 0] + f.mat[0, 0] + f.mat[1, 0]; msg.res := 0
			ELSIF msg.name = "Y2" THEN msg.class := Objects.Real; msg.x := f.mat[2, 1] + f.mat[0, 1] + f.mat[1, 1]; msg.res := 0
			ELSIF msg.name = "X3" THEN msg.class := Objects.Real; msg.x := f.mat[2, 0] + f.mat[1, 0]; msg.res := 0
			ELSIF msg.name = "Y3" THEN msg.class := Objects.Real; msg.x := f.mat[2, 1] + f.mat[1, 1]; msg.res := 0
			ELSE Leonardo.HandleContainer(f, msg)
			END
		ELSIF msg.id = Objects.set THEN
			IF msg.name = "M00" THEN
				IF msg.class = Objects.Real THEN f.mat[0, 0] := msg.x; msg.res := 0 END
			ELSIF msg.name = "M01" THEN
				IF msg.class = Objects.Real THEN f.mat[0, 1] := msg.x; msg.res := 0 END
			ELSIF msg.name = "M10" THEN
				IF msg.class = Objects.Real THEN f.mat[1, 0] := msg.x; msg.res := 0 END
			ELSIF msg.name = "M11" THEN
				IF msg.class = Objects.Real THEN f.mat[1, 1] := msg.x; msg.res := 0 END
			ELSIF msg.name = "M20" THEN
				IF msg.class = Objects.Real THEN f.mat[2, 0] := msg.x; msg.res := 0 END
			ELSIF msg.name = "M21" THEN
				IF msg.class = Objects.Real THEN f.mat[2, 1] := msg.x; msg.res := 0 END
			ELSE
				Leonardo.HandleContainer(f, msg)
			END
		END
	END HandleFrameAttr;

	PROCEDURE HandleFrameLinks* (f: Frame; VAR msg: Objects.LinkMsg);
	BEGIN
		IF msg.id = Objects.enum THEN
			msg.Enum("Pen");
			Leonardo.HandleContainer(f, msg)
		ELSIF msg.id = Objects.get THEN
			IF msg.name = "Pen" THEN msg.obj := f.pen; msg.res := 0
			ELSE Leonardo.HandleContainer(f, msg)
			END
		ELSIF msg.id = Objects.set THEN
			IF msg.name = "Pen" THEN
				IF (msg.obj # NIL) & (msg.obj IS LeoPens.Pen) THEN f.pen := msg.obj(LeoPens.Pen); msg.res := 0 END
			ELSE
				Leonardo.HandleContainer(f, msg)
			END
		END
	END HandleFrameLinks;

	PROCEDURE CopyFrame* (VAR msg: Objects.CopyMsg; from, to: Frame);
		VAR obj: Objects.Object;
	BEGIN
		Leonardo.CopyContainer(msg, from, to);
		obj := Gadgets.CopyPtr(msg, from.pen);
		IF (obj = NIL) OR ~(obj IS LeoPens.Pen) THEN obj := Gadgets.CreateObject("LeoPens.NewStroker") END;
		to.pen := obj(LeoPens.Pen);
		to.mat := from.mat
	END CopyFrame;

	PROCEDURE HandleFrame* (obj: Objects.Object; VAR msg: Objects.ObjMsg);
		VAR f, copy: Frame; lgm: GfxMatrix.Matrix; ver, pos: SIGNED32; forker: LeoPens.Forker;
	BEGIN
		f := obj(Frame);
		IF msg IS Leonardo.ShapeMsg THEN
			IF msg IS Leonardo.SelectMsg THEN
				SelectFrame(f, msg(Leonardo.SelectMsg))
			ELSIF msg IS Leonardo.ControlMsg THEN
				ControlFrame(f, msg(Leonardo.ControlMsg))
			ELSIF msg IS Leonardo.ValidateMsg THEN
				ValidateFrame(f, msg(Leonardo.ValidateMsg))
			ELSIF msg IS Leonardo.TransformMsg THEN
				TransformFrame(f, msg(Leonardo.TransformMsg))
			ELSIF msg IS Leonardo.MatrixMsg THEN
				GetFrameMatrix(f, msg(Leonardo.MatrixMsg))
			ELSIF msg IS LeoPaths.ContourMsg THEN
				msg(LeoPaths.ContourMsg).done := TRUE
			ELSIF (msg IS Leonardo.LocalizedMsg) & (f.bottom # NIL) THEN
				WITH msg: Leonardo.LocalizedMsg DO
					lgm := msg.lgm; GfxMatrix.Concat(f.mat, lgm, msg.lgm);
					Leonardo.HandleContainer(f, msg);
					msg.lgm := lgm
				END
			ELSE
				Leonardo.HandleContainer(f, msg)
			END
		ELSIF msg IS LeoPens.UpdateMsg THEN
			WITH msg: LeoPens.UpdateMsg DO
				IF msg.pen = f.pen THEN f.marked := TRUE; f.sel := TRUE
				ELSE f.pen.handle(f.pen, msg)
				END
			END
		ELSIF msg IS Objects.AttrMsg THEN
			HandleFrameAttr(f, msg(Objects.AttrMsg))
		ELSIF msg IS Objects.LinkMsg THEN
			HandleFrameLinks(f, msg(Objects.LinkMsg))
		ELSIF msg IS Objects.CopyMsg THEN
			WITH msg: Objects.CopyMsg DO
				IF msg.stamp # f.stamp THEN
					NEW(copy); f.dlink := copy; f.stamp := msg.stamp;
					CopyFrame(msg, f, copy)
				END;
				msg.obj := f.dlink
			END
		ELSIF msg IS Objects.BindMsg THEN
			f.pen.handle(f.pen, msg);
			Leonardo.HandleContainer(f, msg)
		ELSIF msg IS Objects.FileMsg THEN
			WITH msg: Objects.FileMsg DO
				IF msg.id = Objects.store THEN
					Files.WriteNum(msg.R, 3);
					Leonardo.HandleContainer(f, msg);
					Gadgets.WriteRef(msg.R, f.lib, f.pen);
					GfxMatrix.Write(msg.R, f.mat)
				ELSIF msg.id = Objects.load THEN
					pos := Files.Pos(msg.R);
					Files.ReadNum(msg.R, ver);
					IF ver >= 3 THEN
						Leonardo.HandleContainer(f, msg);
					ELSE	(* legacy loader *)
						Files.Set(msg.R, Files.Base(msg.R), pos);
						Leonardo.HandleShape(f, msg);
						Files.ReadNum(msg.R, ver);
						ASSERT(ver IN {1, 2}, 110)
					END;
					IF ver >= 2 THEN
						Gadgets.ReadRef(msg.R, f.lib, obj);
						IF (obj = NIL) OR ~(obj IS LeoPens.Pen) THEN obj := Gadgets.CreateObject("LeoPens.NewStroker") END;
						f.pen := obj(LeoPens.Pen);
						GfxMatrix.Read(msg.R, f.mat)
					ELSE
						Gadgets.ReadRef(msg.R, f.lib, obj);
						IF (obj # NIL) & (obj IS LeoPens.Pen) THEN f.pen := obj(LeoPens.Pen)
						ELSE f.pen := NIL
						END;
						Gadgets.ReadRef(msg.R, f.lib, obj);
						IF (obj # NIL) & (obj IS LeoPens.Pen) THEN
							IF f.pen = NIL THEN f.pen := obj(LeoPens.Pen)
							ELSE NEW(forker); LeoPens.InitForker(forker, f.pen, obj(LeoPens.Pen)); f.pen := forker
							END
						ELSIF f.pen = NIL THEN
							f.pen := LeoPens.Default
						END;
						Files.ReadReal(msg.R, f.mat[2, 0]); Files.ReadReal(msg.R, f.mat[2, 1]);
						Files.ReadReal(msg.R, f.mat[0, 0]); Files.ReadReal(msg.R, f.mat[0, 1]);
						Files.ReadReal(msg.R, f.mat[1, 0]); Files.ReadReal(msg.R, f.mat[1, 1]);
						f.mat[2, 0] := f.mat[2, 0] - f.mat[0, 0] - f.mat[1, 0];
						f.mat[2, 1] := f.mat[2, 1] - f.mat[0, 1] - f.mat[1, 1];
						f.mat[0, 0] := 2*f.mat[0, 0]; f.mat[0, 1] := 2*f.mat[0, 1];
						f.mat[1, 0] := 2*f.mat[1, 0]; f.mat[1, 1] := 2*f.mat[1, 1]
					END;
					CalcFrameRect(f, GfxMatrix.Identity)
				END
			END
		ELSE
			Leonardo.HandleContainer(f, msg)
		END
	END HandleFrame;

	PROCEDURE InitFrame* (f: Frame; handle: Objects.Handler; pen: LeoPens.Pen; m: GfxMatrix.Matrix);
	BEGIN
		Leonardo.InitContainer(f, handle, NIL, NIL);
		f.pen := pen; f.mat := m;
		CalcFrameRect(f, GfxMatrix.Identity)
	END InitFrame;


	(**--- Rectangles ---**)

	PROCEDURE ConsumeRect (rect: Rectangle; VAR msg: Leonardo.ConsumeMsg);
		VAR lm: LeoPaths.LinkMsg; lgm: GfxMatrix.Matrix; x, y: FLOAT32; l: Link;
	BEGIN
		IF (msg.recv = NIL) & (msg.bottom = msg.top) & (msg.top.cont # rect) &
			(msg.llx <= rect.urx) & (rect.llx <= msg.urx) & (msg.lly <= rect.ury) & (rect.lly <= msg.ury)
		THEN
			lm.fig := msg.fig; lm.lgm := msg.slgm; lm.id := LeoPaths.get; lm.done := FALSE; msg.top.handle(msg.top, lm);
			IF lm.done THEN
				GfxMatrix.Concat(rect.mat, msg.lgm, lgm);
				GfxMatrix.Solve(lgm, lm.x, lm.y, x, y);
				IF (-0.05 < x) & (x < 0.05) THEN x := 0
				ELSIF (0.45 < x) & (x < 0.55) THEN x := 0.5
				ELSIF (0.95 < x) & (x < 1.05) THEN x := 1
				ELSE RETURN
				END;
				IF (-0.05 < y) & (y < 0.05) THEN y := 0
				ELSIF (0.45 < y) & (y < 0.55) THEN y := 0.5
				ELSIF (0.95 < y) & (y < 1.05) THEN y := 1
				ELSE RETURN
				END;
				Leonardo.BeginCommand(msg.fig);
				GfxMatrix.Apply(lgm, x, y, lm.x, lm.y);
				lm.id := LeoPaths.set; lm.done := FALSE; msg.top.handle(msg.top, lm);
				Leonardo.EndCommand(msg.fig);
				IF lm.done THEN
					msg.top.slink := NIL; Leonardo.Transform(msg.fig, msg.top, GfxMatrix.Identity);
					NEW(l); InitLink(l, x, y); l.link := msg.top;
					Leonardo.AddConsumeAction(msg.fig, rect.top, l, l, NIL, rect);
					msg.recv := rect
				END
			END
		END
	END ConsumeRect;

	PROCEDURE SplitRect (rect: Rectangle; VAR msg: LeoPaths.SplitMsg);
		VAR lgm, glm: GfxMatrix.Matrix; llx, lly, urx, ury, x, y: FLOAT32; l: Link;
	BEGIN
		IF (rect.llx <= msg.urx) & (msg.llx <= rect.urx) & (rect.lly <= msg.ury) & (msg.lly <= rect.ury) THEN
			GfxMatrix.Concat(rect.mat, msg.lgm, lgm);
			GfxMatrix.Invert(lgm, glm);
			GfxMatrix.ApplyToRect(glm, msg.llx, msg.lly, msg.urx, msg.ury, llx, lly, urx, ury);
			IF (-0.05 < urx) & (llx < 0.05) THEN x := 0
			ELSIF (0.45 < urx) & (llx < 0.55) THEN x := 0.5
			ELSIF (0.95 < urx) & (llx < 1.05) THEN x := 1
			ELSE RETURN
			END;
			IF (-0.05 < ury) & (lly < 0.05) THEN y := 0
			ELSIF (0.45 < ury) & (lly < 0.55) THEN y := 0.5
			ELSIF (0.95 < ury) & (lly < 1.05) THEN y := 1
			ELSE RETURN
			END;
			NEW(l); InitLink(l, x, y);
			Leonardo.AddConsumeAction(msg.fig, rect.top, l, l, NIL, rect)
		END
	END SplitRect;

	PROCEDURE DrawRect (rect: Rectangle; pen: LeoPens.Pen);
		VAR x0, y0, x1, y1, x2, y2, x3, y3: FLOAT32;
	BEGIN
		x0 := rect.mat[2, 0]; y0 := rect.mat[2, 1]; x1 := x0 + rect.mat[0, 0]; y1 := y0 + rect.mat[0, 1];
		x2 := x1 + rect.mat[1, 0]; y2 := y1 + rect.mat[1, 1]; x3 := x0 + rect.mat[1, 0]; y3 := y0 + rect.mat[1, 1];
		pen.do.enter(pen, x0, y0, x0 - x3, y0 - y3, 0);
		pen.do.line(pen, x1, y1); pen.do.line(pen, x2, y2); pen.do.line(pen, x3, y3); pen.do.line(pen, x0, y0);
		pen.do.exit(pen, x1 - x0, y1 - y0, 0)
	END DrawRect;

	PROCEDURE RenderRect (rect: Rectangle; VAR msg: Leonardo.RenderMsg);
		VAR llx, lly, urx, ury: FLOAT32; ctm, lgm: GfxMatrix.Matrix; state: Gfx.State; len: ARRAY 1 OF FLOAT32;
	BEGIN
		llx := rect.llx - rect.bw; lly := rect.lly - rect.bw; urx := rect.urx + rect.bw; ury := rect.ury + rect.bw;
		IF (llx < msg.urx) & (msg.llx < urx) & (lly < msg.ury) & (msg.lly < ury) THEN
			IF (msg.id = Leonardo.marked) & rect.marked THEN
				ctm := msg.ctxt.ctm; Gfx.Concat(msg.ctxt, rect.mat);
				Gfx.DrawRect(msg.ctxt, 0, 0, 1, 1, {Gfx.Stroke});
				Gfx.SetCTM(msg.ctxt, ctm)
			END;
			IF msg.id IN {Leonardo.active, Leonardo.passive} THEN
				ctm := msg.ctxt.ctm; Gfx.Concat(msg.ctxt, rect.mat);
				Gfx.DrawRect(msg.ctxt, 0, 0, 1, 1, {Gfx.Record});
				Gfx.SetCTM(msg.ctxt, ctm);
				Gfx.Save(msg.ctxt, Gfx.attr, state);
				len[0] := 0; rect.pen.do.render(rect.pen, msg.ctxt, len, len, 1);
				Gfx.Restore(msg.ctxt, state)
			END;
			IF (msg.id IN {Leonardo.active, Leonardo.marksonly}) & rect.sel THEN
				Gfx.Concat(msg.ctxt, rect.mat);
				lgm := msg.lgm; GfxMatrix.Concat(rect.mat, lgm, msg.lgm);
				Leonardo.DrawHandles(0, 0, 1, 1, msg);
				Leonardo.ToComponents(rect.bottom, msg);
				msg.lgm := lgm; Gfx.SetCTM(msg.ctxt, ctm)
			END
		END
	END RenderRect;

	PROCEDURE LocateRect (rect: Rectangle; VAR msg: Leonardo.LocateMsg);
		VAR lgm, glm: GfxMatrix.Matrix; llx, lly, urx, ury: FLOAT32;
	BEGIN
		IF (msg.id = Leonardo.inside) & (msg.llx <= rect.llx) & (rect.urx <= msg.urx) & (msg.lly <= rect.lly) & (rect.ury <= msg.ury) THEN
			rect.slink := msg.res; msg.res := rect
		ELSIF (msg.llx < rect.urx) & (rect.llx < msg.urx) & (msg.lly < rect.ury) & (rect.lly < msg.ury) THEN
			lgm := msg.lgm; GfxMatrix.Concat(rect.mat, lgm, msg.lgm);
			Leonardo.ToComponents(rect.bottom, msg);
			IF (msg.res = NIL) OR (msg.res.cont # rect) THEN
				IF msg.id = Leonardo.overlap THEN
					GfxMatrix.Invert(msg.lgm, glm);
					GfxMatrix.ApplyToRect(glm, msg.llx, msg.lly, msg.urx, msg.ury, llx, lly, urx, ury);
					IF ((llx <= 0) & (0 <= urx) OR (llx <= 1) & (1 <= urx)) & (lly <= 1) & (0 <= ury) OR
						((lly <= 0) & (0 <= ury) OR (lly <= 1) & (1 <= ury)) & (llx <= 1) & (0 <= urx)
					THEN
						rect.slink := msg.res; msg.res := rect
					END
				ELSIF msg.id = Leonardo.project THEN
					Leonardo.ProjectToHandles(rect, 0, 0, 1, 1, msg)
				END
			END;
			msg.lgm := lgm
		END
	END LocateRect;

	(** default rectangle handler **)
	PROCEDURE HandleRect* (obj: Objects.Object; VAR msg: Objects.ObjMsg);
		VAR rect: Rectangle;
	BEGIN
		rect := obj(Rectangle);
		IF msg IS Leonardo.ShapeMsg THEN
			IF msg IS Leonardo.ConsumeMsg THEN
				ConsumeRect(rect, msg(Leonardo.ConsumeMsg))
			ELSIF msg IS LeoPaths.SplitMsg THEN
				SplitRect(rect, msg(LeoPaths.SplitMsg))
			ELSIF msg IS Leonardo.RenderMsg THEN
				RenderRect(rect, msg(Leonardo.RenderMsg))
			ELSIF msg IS Leonardo.LocateMsg THEN
				LocateRect(rect, msg(Leonardo.LocateMsg))
			ELSIF msg IS LeoPaths.RenderMsg THEN
				DrawRect(rect, msg(LeoPaths.RenderMsg).pen)
			ELSE
				HandleFrame(rect, msg)
			END
		ELSIF msg IS Objects.AttrMsg THEN
			WITH msg: Objects.AttrMsg DO
				IF (msg.id = Objects.get) & (msg.name = "Gen") THEN
					msg.class := Objects.String; msg.s := "LeoBasic.NewRect"; msg.res := 0
				ELSIF (msg.id = Objects.get) & (msg.name = "Item") THEN
					msg.class := Objects.String; msg.s := "Rectangle"; msg.res := 0
				ELSE
					HandleFrameAttr(rect, msg)
				END
			END
		ELSE
			HandleFrame(rect, msg)
		END
	END HandleRect;

	(** initialize rectangle with current default pen **)
	PROCEDURE InitRect* (rect: Rectangle; x0, y0, x1, y1: FLOAT32; pen: LeoPens.Pen);
		VAR m: GfxMatrix.Matrix;
	BEGIN
		GfxMatrix.Init(m, x1 - x0, 0, 0, y1 - y0, x0, y0);
		InitFrame(rect, HandleRect, pen, m)
	END InitRect;

	(** rectangle generator **)
	PROCEDURE NewRect*;
		VAR rect: Rectangle;
	BEGIN
		NEW(rect); InitRect(rect, 0, 0, 1, 1, LeoPens.Default);
		Objects.NewObj := rect
	END NewRect;


	(**--- Ellipses ---**)

	PROCEDURE ConsumeEllipse (e: Ellipse; VAR msg: Leonardo.ConsumeMsg);
		VAR lm: LeoPaths.LinkMsg; lgm: GfxMatrix.Matrix; x, y: FLOAT32; l: Link;
	BEGIN
		IF (msg.recv = NIL) & (msg.bottom = msg.top) & (msg.top.cont # e) &
			(msg.llx <= e.urx) & (e.llx <= msg.urx) & (msg.lly <= e.ury) & (e.lly <= msg.ury)
		THEN
			lm.fig := msg.fig; lm.lgm := msg.slgm; lm.id := LeoPaths.get; lm.done := FALSE; msg.top.handle(msg.top, lm);
			IF lm.done THEN
				GfxMatrix.Concat(e.mat, msg.lgm, lgm);
				GfxMatrix.Solve(lgm, lm.x, lm.y, x, y);
				IF (-0.05 < x) & (x < 0.05) & (0.45 < y) & (y < 0.55) THEN x := 0; y := 0.5
				ELSIF (0.95 < x) & (x < 1.05) & (0.45 < y) & (y < 0.55) THEN x := 1; y := 0.5
				ELSIF (0.45 < x) & (x < 0.55) & (-0.05 < y) & (y < 0.05) THEN x := 0.5; y := 0
				ELSIF (0.45 < x) & (x < 0.55) & (0.95 < y) & (y < 1.05) THEN x := 0.5; y := 1
				ELSIF (0.45 < x) & (x < 0.55) & (0.45 < y) & (y < 0.55) THEN x := 0.5; y := 0.5
				ELSE RETURN
				END;
				Leonardo.BeginCommand(msg.fig);
				GfxMatrix.Apply(lgm, x, y, lm.x, lm.y);
				lm.id := LeoPaths.set; lm.done := FALSE; msg.top.handle(msg.top, lm);
				Leonardo.EndCommand(msg.fig);
				IF lm.done THEN
					msg.top.slink := NIL; Leonardo.Transform(msg.fig, msg.top, GfxMatrix.Identity);
					NEW(l); InitLink(l, x, y); l.link := msg.top;
					Leonardo.AddConsumeAction(msg.fig, e.top, l, l, NIL, e);
					msg.recv := e
				END
			END
		END
	END ConsumeEllipse;

	PROCEDURE DrawEllipse (e: Ellipse; pen: LeoPens.Pen);
		VAR rx1, rx2, ry1, ry2, x0, y0, x1, y1, x2, y2: FLOAT32;
	BEGIN
		rx1 := 0.5*e.mat[0, 0]; rx2 := 0.5*e.mat[1, 0];
		ry1 := 0.5*e.mat[0, 1]; ry2 := 0.5*e.mat[1, 1];
		x0 := e.mat[2, 0] + rx1 + rx2; y0 := e.mat[2, 1] + ry1 + ry2;
		x1 := x0 + rx1; y1 := y0 + ry1; x2 := x0 + rx2; y2 := y0 + ry2;
		pen.do.enter(pen, x1, y1, x2 - x0, y2 - y0, 0);
		pen.do.arc(pen, x1, y1, x0, y0, x1, y1, x2, y2);
		pen.do.exit(pen, x2 - x0, y2 - y0, 0)
	END DrawEllipse;

	PROCEDURE RenderEllipse (e: Ellipse; VAR msg: Leonardo.RenderMsg);
		VAR llx, lly, urx, ury: FLOAT32; ctm, lgm: GfxMatrix.Matrix; state: Gfx.State; len: ARRAY 1 OF FLOAT32;
	BEGIN
		llx := e.llx - e.bw; lly := e.lly - e.bw; urx := e.urx + e.bw; ury := e.ury + e.bw;
		IF (llx < msg.urx) & (msg.llx < urx) & (lly < msg.ury) & (msg.lly < ury) THEN
			IF (msg.id = Leonardo.marked) & e.marked THEN	(* drag ellipse *)
				ctm := msg.ctxt.ctm; Gfx.Concat(msg.ctxt, e.mat);
				Gfx.DrawCircle(msg.ctxt, 0.5, 0.5, 0.5, {Gfx.Stroke});
				Gfx.SetCTM(msg.ctxt, ctm)
			END;
			IF msg.id IN {Leonardo.active, Leonardo.passive} THEN
				ctm := msg.ctxt.ctm; Gfx.Concat(msg.ctxt, e.mat);
				Gfx.DrawCircle(msg.ctxt, 0.5, 0.5, 0.5, {Gfx.Record});
				Gfx.SetCTM(msg.ctxt, ctm);
				Gfx.Save(msg.ctxt, Gfx.attr, state);
				len[0] := 0; e.pen.do.render(e.pen, msg.ctxt, len, len, 1);
				Gfx.Restore(msg.ctxt, state);
			END;
			IF (msg.id IN {Leonardo.active, Leonardo.marksonly}) & e.sel THEN
				Gfx.Concat(msg.ctxt, e.mat);
				lgm := msg.lgm; GfxMatrix.Concat(e.mat, lgm, msg.lgm);
				Leonardo.DrawHandles(0, 0, 1, 1, msg);
				Leonardo.ToComponents(e.bottom, msg);
				msg.lgm := lgm; Gfx.SetCTM(msg.ctxt, ctm)
			END
		END
	END RenderEllipse;

	PROCEDURE LocateEllipse (e: Ellipse; VAR msg: Leonardo.LocateMsg);
		VAR lgm, glm: GfxMatrix.Matrix; llx, lly, urx, ury, min, max, x, y, d: FLOAT32;
	BEGIN
		IF (msg.id = Leonardo.inside) & (msg.llx <= e.llx) & (e.urx <= msg.urx) & (msg.lly <= e.lly) & (e.ury <= msg.ury) THEN
			e.slink := msg.res; msg.res := e
		ELSIF (msg.llx < e.urx) & (e.llx < msg.urx) & (msg.lly < e.ury) & (e.lly < msg.ury) THEN
			lgm := msg.lgm; GfxMatrix.Concat(e.mat, lgm, msg.lgm);
			Leonardo.ToComponents(e.bottom, msg);
			IF (msg.res = NIL) OR (msg.res.cont # e) THEN
				IF msg.id = Leonardo.overlap THEN
					GfxMatrix.Invert(msg.lgm, glm);
					GfxMatrix.ApplyToRect(glm, msg.llx, msg.lly, msg.urx, msg.ury, llx, lly, urx, ury);
					llx := 2*llx - 1; lly := 2*lly - 1; urx := 2*urx - 1; ury := 2*ury - 1;
					IF ABS(llx) < ABS(urx) THEN min := llx * llx; max := urx * urx
					ELSE min := urx * urx; max := llx * llx
					END;
					IF ABS(lly) < ABS(ury) THEN min := min + lly * lly; max := max + ury * ury
					ELSE min := min + ury * ury; max := max + lly * lly
					END;
					IF (min <= 1) & (1 <= max) THEN
						e.slink := msg.res; msg.res := e
					END
				ELSIF msg.id = Leonardo.project THEN
					Leonardo.ProjectToHandles(e, 0, 0, 1, 1, msg);
					IF msg.res # e THEN
						GfxMatrix.Solve(msg.lgm, msg.x, msg.y, x, y);
						d := Math.sqrt(x * x + y * y);
						GfxMatrix.Apply(msg.lgm, x/d, y/d, x, y);
						IF (msg.llx <= x) & (x <= msg.urx) & (msg.lly <= y) & (y <= msg.ury) THEN
							msg.res := e; msg.px := x; msg.py := y
						END
					END
				END
			END;
			msg.lgm := lgm
		END
	END LocateEllipse;

	(** default ellipse handler **)
	PROCEDURE HandleEllipse* (obj: Objects.Object; VAR msg: Objects.ObjMsg);
		VAR e: Ellipse;
	BEGIN
		e := obj(Ellipse);
		IF msg IS Leonardo.ShapeMsg THEN
			IF msg IS Leonardo.ConsumeMsg THEN
				ConsumeEllipse(e, msg(Leonardo.ConsumeMsg))
			ELSIF msg IS Leonardo.RenderMsg THEN
				RenderEllipse(e, msg(Leonardo.RenderMsg))
			ELSIF msg IS Leonardo.LocateMsg THEN
				LocateEllipse(e, msg(Leonardo.LocateMsg))
			ELSIF msg IS LeoPaths.RenderMsg THEN
				DrawEllipse(e, msg(LeoPaths.RenderMsg).pen)
			ELSE
				HandleFrame(e, msg)
			END
		ELSIF msg IS Objects.AttrMsg THEN
			WITH msg: Objects.AttrMsg DO
				IF (msg.id = Objects.get) & (msg.name = "Gen") THEN
					msg.class := Objects.String; msg.s := "LeoBasic.NewEllipse"; msg.res := 0
				ELSIF (msg.id = Objects.get) & (msg.name = "Item") THEN
					msg.class := Objects.String; msg.s := "Ellipse"; msg.res := 0
				ELSE
					HandleFrameAttr(e, msg)
				END
			END
		ELSE
			HandleFrame(e, msg)
		END
	END HandleEllipse;

	(** initialize ellipse with current default pen **)
	PROCEDURE InitEllipse* (e: Ellipse; x, y, rx, ry: FLOAT32; pen: LeoPens.Pen);
		VAR m: GfxMatrix.Matrix;
	BEGIN
		GfxMatrix.Init(m, 2*rx, 0, 0, 2*ry, x - rx, y - ry);
		InitFrame(e, HandleEllipse, pen, m)
	END InitEllipse;

	(** ellipse generator **)
	PROCEDURE NewEllipse*;
		VAR e: Ellipse;
	BEGIN
		NEW(e); InitEllipse(e, 0, 0, 1, 1, LeoPens.Default);
		Objects.NewObj := e
	END NewEllipse;


	(**--- Groups ---**)

	PROCEDURE HandleGroup* (obj: Objects.Object; VAR msg: Objects.ObjMsg);
		VAR group, copy: Group; sm: Leonardo.SelectMsg; res: Leonardo.Shape; lgm: GfxMatrix.Matrix;
	BEGIN
		group := obj(Group);
		IF msg IS Leonardo.SelectMsg THEN
			WITH msg: Leonardo.SelectMsg DO
				Leonardo.SelectContainer(group, msg);
				IF (msg.id = Leonardo.validate) & group.subsel THEN
					sm.id := Leonardo.reset; sm.fig := msg.fig;
					Leonardo.ToComponents(group.bottom, sm);
					group.subsel := FALSE
				END
			END
		ELSIF msg IS Leonardo.LocateMsg THEN
			WITH msg: Leonardo.LocateMsg DO
				IF (msg.id = Leonardo.inside) & (msg.llx <= group.llx) & (group.urx <= msg.urx) & (msg.lly <= group.lly) & (group.ury <= msg.ury) THEN
					group.slink := msg.res; msg.res := group
				ELSIF msg.id = Leonardo.overlap THEN
					res := msg.res;
					Leonardo.ToComponents(group.bottom, msg);
					IF msg.res # res THEN
						group.slink := res; msg.res := group
					END
				ELSE
					Leonardo.HandleContainer(group, msg)
				END
			END
		ELSIF msg IS Leonardo.MatrixMsg THEN
			WITH msg: Leonardo.MatrixMsg DO
				IF msg.dest = group THEN
					lgm := msg.lgm; msg.lgm := GfxMatrix.Identity;
					Leonardo.GetHandleMatrix(group.llx, group.lly, group.urx, group.ury, msg);
					msg.lgm := lgm
				END
			END
		ELSIF msg IS Objects.AttrMsg THEN
			WITH msg: Objects.AttrMsg DO
				IF msg.id = Objects.get THEN
					IF msg.name = "Gen" THEN msg.class := Objects.String; msg.s := "LeoBasic.NewGroup"; msg.res := 0
					ELSIF msg.name = "Item" THEN msg.class := Objects.String; msg.s := "Group"; msg.res := 0
					ELSE Leonardo.HandleContainer(group, msg)
					END
				ELSE Leonardo.HandleContainer(group, msg)
				END
			END
		ELSIF msg IS Objects.CopyMsg THEN
			WITH msg: Objects.CopyMsg DO
				IF msg.stamp # group.stamp THEN
					NEW(copy); group.dlink := copy; group.stamp := msg.stamp;
					Leonardo.CopyContainer(msg, group, copy)
				END;
				msg.obj := group.dlink
			END
		ELSE
			Leonardo.HandleContainer(group, msg)
		END
	END HandleGroup;

	PROCEDURE InitGroup* (group: Group; bottom, top: Leonardo.Shape);
	BEGIN
		Leonardo.InitContainer(group, HandleGroup, bottom, top)
	END InitGroup;

	PROCEDURE NewGroup*;
		VAR group: Group;
	BEGIN
		NEW(group); InitGroup(group, NIL, NIL);
		Objects.NewObj := group
	END NewGroup;


END LeoBasic.
