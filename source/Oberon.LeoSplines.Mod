(* ETH Oberon, Copyright 2001 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

MODULE LeoSplines IN Oberon; (** portable **)	(* eos  *)

	(**
		Leonardo natural spline segments
	**)

	(*
		to do:
		- split splines
	*)

	IMPORT
		Files, Math IN A2, Objects, Attributes, Gadgets, GfxMatrix, GfxPaths, Gfx, Leonardo, LeoPaths, LeoPens;


	TYPE
		Spline* = POINTER TO SplineDesc;
		SplineDesc* = RECORD (LeoPaths.SegmentDesc)
			dx0*, dy0*: FLOAT32;
		END;

		BoxData = RECORD (GfxPaths.EnumData)
			llx, lly, urx, ury: FLOAT32;	(* bounding box *)
			dx0, dy0: FLOAT32;	(* direction of last element *)
			cx, cy: FLOAT32;	(* start point of current path element *)
		END;

		DrawData = RECORD (GfxPaths.EnumData)
			ctxt: Gfx.Context;
			pen: LeoPens.Pen;
		END;

		ProjectData = RECORD (GfxPaths.EnumData)
			llx, lly, urx, ury: FLOAT32;	(* query rectangle *)
			qx, qy, px, py: FLOAT32;	(* query point and projected point *)
			cx, cy: FLOAT32;	(* start point of current path element *)
			hit: BOOLEAN;
		END;


	PROCEDURE GetCoords (s: Spline; VAR xc, yc: ARRAY OF FLOAT32; VAR n: SIGNED16);
		VAR p: Leonardo.Shape;
	BEGIN
		p := s.bottom; n := 0;
		WHILE p # NIL DO
			xc[n] := p(LeoPaths.Point).x; yc[n] := p(LeoPaths.Point).y;
			p := p.up; INC(n)
		END;
		IF s.closed & (n > 0) THEN
			xc[n] := s.bottom(LeoPaths.Point).x; yc[n] := s.bottom(LeoPaths.Point).y;
			INC(n)
		END
	END GetCoords;

	PROCEDURE IncludeElem (VAR data: GfxPaths.EnumData);
		VAR rx, ry, r: FLOAT32;

		PROCEDURE incl (VAR data: BoxData; x, y: FLOAT32);
		BEGIN
			IF x < data.llx THEN data.llx := x
			ELSIF x > data.urx THEN data.urx := x
			END;
			IF y < data.lly THEN data.lly := y
			ELSIF y > data.ury THEN data.ury := y
			END
		END incl;

	BEGIN
		WITH data: BoxData DO
			CASE data.elem OF
			| GfxPaths.Line:
				data.dx0 := data.x - data.cx; data.dy0 := data.y - data.cy;
				incl(data, data.x, data.y)
			| GfxPaths.Arc:
				data.dx0 := data.x2 - data.x0; data.dy0 := data.y2 - data.y0;
				rx := data.x - data.x0; ry := data.y - data.y0; r := Math.sqrt(rx * rx + ry * ry);
				incl(data, data.x0 - r, data.y0 - r); incl(data, data.x0 + r, data.y0 + r)
			| GfxPaths.Bezier:
				data.dx0 := data.x - data.x2; data.dy0 := data.y - data.y2;
				incl(data, data.x, data.y); incl(data, data.x1, data.y1); incl(data, data.x2, data.y2)
			END
		END
	END IncludeElem;

	PROCEDURE CalcBox (s: Spline; VAR mat: GfxMatrix.Matrix);
		VAR xc, yc: ARRAY GfxPaths.MaxSplinePoints OF FLOAT32; n: SIGNED16; data: BoxData; bw: FLOAT32;
	BEGIN
		Leonardo.GetComponentsBox(s.bottom, s.llx, s.lly, s.urx, s.ury, s.bw);
		GetCoords(s, xc, yc, n);
		IF n > 1 THEN
			data.cx := xc[0]; data.cy := yc[0];
			data.llx := s.llx; data.lly := s.lly; data.urx := s.urx; data.ury := s.ury;
			GfxPaths.EnumSpline(xc, yc, n, s.closed, IncludeElem, data);
			s.dx0 := data.dx0; s.dy0 := data.dy0;
			s.llx := data.llx; s.lly := data.lly; s.urx := data.urx; s.ury := data.ury
		END;
		Attributes.GetReal(s.pen, "Border", bw);
		GfxMatrix.ApplyToDist(mat, bw, bw);
		IF bw > s.bw THEN s.bw := bw END
	END CalcBox;

	PROCEDURE Control (s: Spline; VAR msg: Leonardo.ControlMsg);
		VAR bot, top: Leonardo.Shape; copy: Spline;
	BEGIN
		IF (msg.id = Leonardo.clone) & ~s.marked THEN
			bot := msg.bottom; top := msg.top; msg.bottom := NIL; msg.top := NIL;
			Leonardo.ControlContainer(s, msg);
			IF msg.top # NIL THEN
				NEW(copy); Leonardo.InitContainer(copy, s.handle, msg.bottom, msg.top);
				copy.llx := s.llx; copy.lly := s.lly; copy.urx := s.urx; copy.ury := s.ury; copy.bw := s.bw;
				copy.pen := s.pen; copy.closed := s.closed; copy.len := s.len;
				msg.top := copy; copy.down := top;
				IF top = NIL THEN msg.bottom := copy
				ELSE msg.bottom := bot; top.up := copy
				END
			ELSE
				msg.bottom := bot; msg.top := top
			END
		ELSE
			LeoPaths.ControlSegment(s, msg)
		END
	END Control;

	PROCEDURE Validate (s: Spline; VAR msg: Leonardo.ValidateMsg);
	BEGIN
		Leonardo.ToComponents(s.bottom, msg);
		IF s.marked THEN
			Leonardo.UpdateShape(msg.fig, s);
			CalcBox(s, msg.lgm);
			Leonardo.UpdateShape(msg.fig, s);
			LeoPaths.ValidateSegmentLength(s, msg);
			s.marked := FALSE; s.cont.marked := TRUE
		END
	END Validate;

	PROCEDURE DrawElem (VAR data: GfxPaths.EnumData);
	BEGIN
		WITH data: DrawData DO
			CASE data.elem OF
			| GfxPaths.Line: data.pen.do.line(data.pen, data.x, data.y)
			| GfxPaths.Arc: data.pen.do.arc(data.pen, data.x, data.y, data.x0, data.y0, data.x1, data.y1, data.x2, data.y2)
			| GfxPaths.Bezier: data.pen.do.bezier(data.pen, data.x, data.y, data.x1, data.y1, data.x2, data.y2)
			END
		END
	END DrawElem;

	PROCEDURE Draw (s: Spline; pen: LeoPens.Pen);
		VAR xc, yc: ARRAY GfxPaths.MaxSplinePoints OF FLOAT32; n: SIGNED16; data: DrawData; dx, dy: FLOAT32;
	BEGIN
		IF (s.bottom # NIL) & (s.bottom # s.top) THEN
			GetCoords(s, xc, yc, n);
			IF s.closed THEN pen.do.enter(pen, xc[0], yc[0], s.dx0, s.dy0, 0)
			ELSE LeoPaths.GetPred(s, dx, dy); pen.do.enter(pen, xc[0], yc[0], dx, dy, s.boff)
			END;
			data.x := xc[0]; data.y := yc[0]; data.pen := pen;
			GfxPaths.EnumSpline(xc, yc, n, s.closed, DrawElem, data);
			IF s.closed THEN pen.do.exit(pen, s.dx0, s.dy0, 0)
			ELSE LeoPaths.GetSucc(s, dx, dy); pen.do.exit(pen, dx, dy, s.eoff)
			END
		END
	END Draw;

	PROCEDURE DragElem (VAR data: GfxPaths.EnumData);
	BEGIN
		WITH data: DrawData DO
			CASE data.elem OF
			| GfxPaths.Line: Gfx.LineTo(data.ctxt, data.x, data.y)
			| GfxPaths.Arc: Gfx.ArcTo(data.ctxt, data.x, data.y, data.x0, data.y0, data.x1, data.y1, data.x2, data.y2)
			| GfxPaths.Bezier: Gfx.BezierTo(data.ctxt, data.x, data.y, data.x1, data.y1, data.x2, data.y2)
			END
		END
	END DragElem;

	PROCEDURE Drag (s: Spline; ctxt: Gfx.Context);
		VAR p: Leonardo.Shape; xc, yc: ARRAY GfxPaths.MaxSplinePoints OF FLOAT32; n: SIGNED16; data: DrawData;
	BEGIN
		IF (s.bottom # NIL) & (s.bottom # s.top) THEN
			p := s.bottom;
			WHILE (p # NIL) & ~p.marked DO p := p.up END;
			IF p # NIL THEN
				Gfx.Begin(ctxt, {Gfx.Stroke});
				GetCoords(s, xc, yc, n);
				Gfx.Enter(ctxt, xc[0], yc[0], s.dx0, s.dy0);
				data.x := xc[0]; data.y := yc[0]; data.ctxt := ctxt;
				GfxPaths.EnumSpline(xc, yc, n, s.closed, DragElem, data);
				Gfx.Exit(ctxt, s.dx0, s.dy0);
				Gfx.End(ctxt)
			END
		END
	END Drag;

	PROCEDURE Render (s: Spline; VAR msg: Leonardo.RenderMsg);
		VAR state: Gfx.State;
	BEGIN
		IF (s.llx - s.bw < msg.urx) & (msg.llx < s.urx + s.bw) & (s.lly - s.bw < msg.ury) & (msg.lly < s.ury + s.bw) THEN
			IF msg.id = Leonardo.marked THEN
				Drag(s, msg.ctxt)
			END;
			IF msg.id IN {Leonardo.active, Leonardo.passive} THEN
				Gfx.Save(msg.ctxt, Gfx.attr, state);
				s.pen.do.begin(s.pen, msg.ctxt);
				Draw(s, s.pen);
				s.pen.do.end(s.pen);
				Gfx.Restore(msg.ctxt, state)
			END;
			LeoPaths.RenderSegment(s, msg)
		END
	END Render;

	PROCEDURE ProjectElem (VAR data: GfxPaths.EnumData);
		VAR project: GfxPaths.Enumerator; x, y: FLOAT32;
	BEGIN
		project := ProjectElem;	(* WITH workaround *)
		WITH data: ProjectData DO
			CASE data.elem OF
			| GfxPaths.Line:
				IF LeoPaths.OnLine(data.cx, data.cy, data.x, data.y, data.qx, data.qy, data.llx, data.lly, data.urx, data.ury,
					data.px, data.py)
				THEN
					data.hit := TRUE
				END
			| GfxPaths.Arc:
				x := data.x; y := data.y; data.x := data.cx; data.y := data.cy;
				GfxPaths.EnumArc(data.x0, data.y0, data.x1, data.y1, data.x2, data.y2, x, y, 1, project, data)
			| GfxPaths.Bezier:
				x := data.x; y := data.y; data.x := data.cx; data.y := data.cy;
				GfxPaths.EnumBezier(data.x1, data.y1, data.x2, data.y2, x, y, 1, project, data)
			END;
			data.cx := data.x; data.cy := data.y
		END
	END ProjectElem;

	PROCEDURE Project (s: Spline; x, y, llx, lly, urx, ury: FLOAT32; VAR px, py: FLOAT32): BOOLEAN;
		VAR xc, yc: ARRAY GfxPaths.MaxSplinePoints OF FLOAT32; n: SIGNED16; data: ProjectData;
	BEGIN
		IF (s.bottom # NIL) & (s.bottom # s.top) THEN
			GetCoords(s, xc, yc, n);
			data.x := xc[0]; data.y := yc[0]; data.cx := xc[0]; data.cy := yc[0];
			data.llx := llx; data.lly := lly; data.urx := urx; data.ury := ury; data.qx := x; data.qy := y;
			data.hit := FALSE;
			GfxPaths.EnumSpline(xc, yc, n, s.closed, ProjectElem, data);
			IF data.hit THEN
				px := data.px; py := data.py;
				RETURN TRUE
			END
		END;
		RETURN FALSE
	END Project;

	PROCEDURE Locate (s: Spline; VAR msg: Leonardo.LocateMsg);
		VAR res: Leonardo.Shape; glm: GfxMatrix.Matrix; llx, lly, urx, ury, px, py: FLOAT32;
	BEGIN
		IF (msg.llx <= s.urx) & (s.llx <= msg.urx) & (msg.lly <= s.ury) & (s.lly <= msg.ury) THEN
			IF msg.id = Leonardo.inside THEN
				IF (msg.llx <= s.llx) & (s.urx <= msg.urx) & (msg.lly <= s.lly) & (s.ury <= msg.ury) THEN
					s.slink := msg.res; msg.res := s
				ELSE
					Leonardo.ToComponents(s.bottom, msg)
				END
			ELSE
				res := msg.res;
				Leonardo.ToComponents(s.bottom, msg);
				IF msg.id = Leonardo.overlap THEN
					IF msg.res = res THEN
						GfxMatrix.Invert(msg.lgm, glm);
						GfxMatrix.ApplyToRect(glm, msg.llx, msg.lly, msg.urx, msg.ury, llx, lly, urx, ury);
						GfxMatrix.Apply(glm, 0.5*(msg.llx + msg.urx), 0.5*(msg.lly + msg.ury), px, py);
						IF Project(s, px, py, llx, lly, urx, ury, px, py) THEN
							s.slink := msg.res; msg.res := s
						END
					ELSIF ~s.sel THEN
						msg.res := s; s.slink := res	(* select curve before points can be located *)
					END
				ELSIF (msg.id = Leonardo.project) & (msg.res = res) THEN
					GfxMatrix.Invert(msg.lgm, glm);
					GfxMatrix.ApplyToRect(glm, msg.llx, msg.lly, msg.urx, msg.ury, llx, lly, urx, ury);
					GfxMatrix.Apply(glm, msg.x, msg.y, px, py);
					IF Project(s, px, py, llx, lly, urx, ury, px, py) THEN
						msg.res := s; msg.px := px; msg.py := py
					END
				END
			END
		END
	END Locate;

	PROCEDURE Copy* (VAR msg: Objects.CopyMsg; from, to: Spline);
	BEGIN
		LeoPaths.CopySegment(msg, from, to);
		to.dx0 := from.dx0; to.dy0 := from.dy0
	END Copy;

	PROCEDURE Handle* (obj: Objects.Object; VAR msg: Objects.ObjMsg);
		VAR s, copy: Spline;
	BEGIN
		s := obj(Spline);
		IF msg IS Leonardo.ShapeMsg THEN
			IF msg IS Leonardo.ControlMsg THEN
				Control(s, msg(Leonardo.ControlMsg))
			ELSIF msg IS Leonardo.ValidateMsg THEN
				Validate(s, msg(Leonardo.ValidateMsg))
			ELSIF msg IS Leonardo.RenderMsg THEN
				Render(s, msg(Leonardo.RenderMsg))
			ELSIF msg IS Leonardo.LocateMsg THEN
				Locate(s, msg(Leonardo.LocateMsg))
			ELSIF msg IS LeoPaths.RenderMsg THEN
				Draw(s, msg(LeoPaths.RenderMsg).pen)
			ELSIF msg IS LeoPaths.ConnectMsg THEN
				LeoPaths.ConnectSegment(s, msg(LeoPaths.ConnectMsg))
			ELSIF msg IS Leonardo.ConsumeMsg THEN
				LeoPaths.ConsumePoints(s, msg(Leonardo.ConsumeMsg))
			ELSE
				LeoPaths.HandleSegment(s, msg)
			END
		ELSIF msg IS Objects.AttrMsg THEN
			WITH msg: Objects.AttrMsg DO
				IF msg.id = Objects.get THEN
					IF msg.name = "Gen" THEN msg.class := Objects.String; msg.s := "LeoSplines.New"; msg.res := 0
					ELSIF msg.name = "Item" THEN msg.class := Objects.String; msg.s := "Spline"; msg.res := 0
					ELSE LeoPaths.HandleSegment(s, msg)
					END
				ELSE LeoPaths.HandleSegment(s, msg)
				END
			END
		ELSIF msg IS Objects.CopyMsg THEN
			WITH msg: Objects.CopyMsg DO
				IF msg.stamp # s.stamp THEN
					NEW(copy); s.dlink := copy; s.stamp := msg.stamp;
					Copy(msg, s, copy)
				END;
				msg.obj := s.dlink
			END
		ELSIF msg IS Objects.FileMsg THEN
			WITH msg: Objects.FileMsg DO
				LeoPaths.HandleSegment(s, msg);
				IF msg.id = Objects.load THEN
					CalcBox(s, GfxMatrix.Identity)
				END
			END
		ELSE
			LeoPaths.HandleSegment(s, msg)
		END
	END Handle;

	PROCEDURE Init* (s: Spline; bottom, top: LeoPaths.Point; closed: BOOLEAN; pen: LeoPens.Pen);
	BEGIN
		LeoPaths.InitSegment(s, Handle, bottom, top, closed, pen);
		CalcBox(s, GfxMatrix.Identity)
	END Init;

	PROCEDURE New*;
		VAR s: Spline;
	BEGIN
		NEW(s); Init(s, NIL, NIL, FALSE, LeoPens.Default);
		Objects.NewObj := s
	END New;


	(**--- Legacy Support ---**)

	PROCEDURE HandleSpline (obj: Objects.Object; VAR msg: Objects.ObjMsg);
		VAR
			c: Spline; ver: SIGNED32; i: SIGNED16; real, x0, y0, x1, y1, bw: FLOAT32; cm: Objects.CopyMsg;
			s: Leonardo.Shape; bool: BOOLEAN;
	BEGIN
		IF msg IS Objects.FileMsg THEN
			WITH msg: Objects.FileMsg DO
				ASSERT(msg.id = Objects.load, 110);
				c := obj(Spline);

				(* shape part *)
				Files.ReadNum(msg.R, ver);
				ASSERT(ver IN {1, 2}, 111);
				IF ver = 1 THEN
					Files.ReadInt(msg.R, i); Files.ReadInt(msg.R, i); Files.ReadInt(msg.R, i); Files.ReadInt(msg.R, i);
					Files.ReadReal(msg.R, real)
				END;

				(* container part *)
				Files.ReadNum(msg.R, ver);
				ASSERT(ver IN {1, 2}, 112);
				REPEAT
					Gadgets.ReadRef(msg.R, c.lib, obj);
					IF (obj # NIL) & (obj IS Leonardo.Shape) THEN
						Objects.Stamp(cm); cm.id := Objects.shallow; cm.obj := obj; obj.handle(obj, cm);
						s := cm.obj(Leonardo.Shape); s.cont := c;
						IF c.bottom = NIL THEN c.bottom := s ELSE c.top.up := s END;
						s.down := c.top; c.top := s
					END
				UNTIL obj = NIL;
				Leonardo.GetComponentsBox(c.bottom, c.llx, c.lly, c.urx, c.ury, c.bw);
				IF ver = 1 THEN
					Files.ReadBool(msg.R, bool)
				END;

				IF c.bottom # c.top THEN
					Attributes.GetReal(c.bottom, "X", x0); Attributes.GetReal(c.bottom, "Y", y0);
					Attributes.GetReal(c.top, "X", x1); Attributes.GetReal(c.top, "Y", y1);
					IF (x0 = x1) & (y0 = y1) THEN
						c.closed := TRUE;
						c.top := c.top.down; c.top.up := NIL
					END
				END;

				(* curve part *)
				Files.ReadNum(msg.R, ver);
				ASSERT(ver = 1, 111);
				Gadgets.ReadRef(msg.R, c.lib, obj);
				IF (obj # NIL) & (obj IS LeoPens.Pen) THEN
					c.pen := obj(LeoPens.Pen);
					Attributes.GetReal(obj, "Border", bw);
					IF bw > c.bw THEN c.bw := bw END
				END;
				Gadgets.ReadRef(msg.R, c.lib, obj); Gadgets.ReadRef(msg.R, c.lib, obj);	(* pred and succ curves *)

				c.handle := Handle
			END
		ELSE
			Handle(obj, msg)
		END
	END HandleSpline;

	PROCEDURE NewSpline*;
		VAR c: Spline;
	BEGIN
		NEW(c); Init(c, NIL, NIL, FALSE, LeoPens.Default); c.handle := HandleSpline;
		Objects.NewObj := c
	END NewSpline;


END LeoSplines.
