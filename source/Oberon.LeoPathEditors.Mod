(* ETH Oberon, Copyright 2001 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

MODULE LeoPathEditors IN Oberon; (** portable **)	(* eos  *)

	(**
		Leonardo path and segment tools and editors
	**)

	(*
		to do:
		- unlink points
	*)

	IMPORT
		Input, Objects, Oberon, Display3, Effects, Attributes, Links, Gadgets, GfxMatrix, Gfx, Leonardo, LeoPens,
		LeoPaths, LeoFrames, LeoTools, LeoPanels, LeoPenEditors;


	VAR
		ClosedCurve*, AutoConnect*: Objects.Object;
		ArcMode: Objects.Object;


	(**--- Point Editor ---**)

	PROCEDURE RevertPoint (editor: LeoPanels.Editor);
		VAR obj: Objects.Object; p: LeoPaths.Point;
	BEGIN
		Links.GetLink(editor, "Model", obj);
		IF (obj # NIL) & (obj IS LeoPaths.Point) THEN
			p := obj(LeoPaths.Point);
			Attributes.SetReal(editor, "X", p.x); Attributes.SetReal(editor, "Y", p.y);
			Gadgets.Update(editor)
		END
	END RevertPoint;

	PROCEDURE ApplyPoint (editor: LeoPanels.Editor);
		VAR obj: Objects.Object; p: LeoPaths.Point; x, y: FLOAT32;
	BEGIN
		Links.GetLink(editor, "Model", obj);
		IF (obj # NIL) & (obj IS LeoPaths.Point) & (editor.fig # NIL) THEN
			p := obj(LeoPaths.Point);
			Leonardo.BeginCommand(editor.fig);
			Attributes.GetReal(editor, "X", x); Attributes.GetReal(editor, "Y", y);
			Leonardo.SetReal(editor.fig, p, "X", x);
			Leonardo.SetReal(editor.fig, p, "Y", y);
			Leonardo.EndCommand(editor.fig)
		END
	END ApplyPoint;

	PROCEDURE NewPoint*;
		VAR obj: Objects.Object; editor: LeoPanels.Editor;
	BEGIN
		Objects.NewObj := LeoPanels.CopyObj("PointPanel", TRUE);
		Links.GetLink(Objects.NewObj, "Model", obj);
		IF (obj # NIL) & (obj IS LeoPanels.Editor) THEN
			editor := obj(LeoPanels.Editor); editor.revert := RevertPoint; editor.apply := ApplyPoint
		END
	END NewPoint;

	PROCEDURE Unlink*;
		VAR e: LeoPanels.Editor; obj: Objects.Object; p: LeoPaths.Point; sm: LeoPaths.SplitMsg;
	BEGIN
		e := LeoPanels.FindEditor(Gadgets.context);
		Links.GetLink(e, "Model", obj);
		IF (obj # NIL) & (obj IS LeoPaths.Point) THEN
			p := obj(LeoPaths.Point);
			IF (e.fig # NIL) & (p.link # NIL) THEN
				Leonardo.BeginCommand(e.fig);
				sm.fig := e.fig; sm.llx := p.llx; sm.lly := p.lly; sm.urx := p.urx; sm.ury := p.ury; p.handle(p, sm);
				Leonardo.EndCommand(e.fig)
			END
		END
	END Unlink;



	(**--- Segment Inspector ---**)

	PROCEDURE RevertSegment (editor: LeoPanels.Editor);
		VAR obj: Objects.Object; seg: LeoPaths.Segment; b: BOOLEAN;
	BEGIN
		Links.GetLink(editor, "Model", obj);
		IF (obj # NIL) & (obj IS LeoPaths.Segment) THEN
			seg := obj(LeoPaths.Segment);
			Links.SetLink(editor, "Pen", seg.pen); Attributes.SetBool(editor, "Closed", seg.closed);
			Attributes.SetInt(editor, "Pred", seg.pred); Attributes.SetInt(editor, "Succ", seg.succ);
			Links.GetLink(editor, "List", obj);
			IF obj # NIL THEN
				Links.SetLink(obj, "Model", Leonardo.ContainingFigure(seg));
				Links.SetLink(obj, "Container", seg);
				Gadgets.Update(obj)
			END;
			Links.GetLink(editor, "Bar", obj);
			IF obj # NIL THEN
				Attributes.GetBool(obj, "ArrowBoxes", b); Attributes.SetBool(obj, "ArrowBoxes", b)	(* force AdjustKnoblen *)
			END;
			Gadgets.Update(editor)
		END
	END RevertSegment;

	PROCEDURE ApplySegment (editor: LeoPanels.Editor);
		VAR obj: Objects.Object; seg: LeoPaths.Segment; b: BOOLEAN; i: SIGNED32;
	BEGIN
		Links.GetLink(editor, "Model", obj);
		IF (obj # NIL) & (obj IS LeoPaths.Segment) & (editor.fig # NIL) THEN
			seg := obj(LeoPaths.Segment);
			Leonardo.BeginCommand(editor.fig);
			Links.GetLink(editor, "Pen", obj);
			IF (obj # seg.pen) & (obj # NIL) & (obj IS LeoPens.Pen) THEN
				LeoPenEditors.SetPen(editor.fig, seg, "Pen", obj(LeoPens.Pen))
			END;
			Attributes.GetBool(editor, "Closed", b); Leonardo.SetBool(editor.fig, seg, "Closed", b);
			Attributes.GetInt(editor, "Pred", i); LeoPaths.SetPred(editor.fig, seg, SHORT(SHORT(i)));
			Attributes.GetInt(editor, "Succ", i); LeoPaths.SetSucc(editor.fig, seg, SHORT(SHORT(i)));
			Leonardo.EndCommand(editor.fig)
		END
	END ApplySegment;

	PROCEDURE NewSegment*;
		VAR obj: Objects.Object; editor: LeoPanels.Editor;
	BEGIN
		Objects.NewObj := LeoPanels.CopyObj("SegmentPanel", TRUE);
		Links.GetLink(Objects.NewObj, "Model", obj);
		IF (obj # NIL) & (obj IS LeoPanels.Editor) THEN
			editor := obj(LeoPanels.Editor); editor.handle := LeoPenEditors.HandleShapeEditor;
			editor.revert := RevertSegment; editor.apply := ApplySegment;
			Links.SetLink(editor, "List", Gadgets.FindObj(Objects.NewObj, "List"));
			Links.SetLink(editor, "Bar", Gadgets.FindObj(Objects.NewObj, "Bar"))
		END
	END NewSegment;


	(**--- Segment Tools ---**)

	PROCEDURE RevertTool* (e: LeoPanels.Editor);
		VAR b: BOOLEAN;
	BEGIN
		Attributes.GetBool(ClosedCurve, "Value", b); Attributes.SetBool(e, "Closed", b);
		Links.SetLink(e, "Pen", LeoPenEditors.Find("Segment", b));
		Attributes.GetBool(AutoConnect, "Value", b); Attributes.SetBool(e, "Connect", b);
		Gadgets.Update(e)
	END RevertTool;

	PROCEDURE ApplyTool* (e: LeoPanels.Editor);
		VAR b: BOOLEAN; obj: Objects.Object;
	BEGIN
		Attributes.GetBool(e, "Closed", b); Attributes.SetBool(ClosedCurve, "Value", b);
		Links.GetLink(e, "Pen", obj);
		IF (obj # NIL) & (obj IS LeoPens.Pen) & (obj # LeoPenEditors.Find("Segment", b)) THEN
			LeoPenEditors.Register(obj(LeoPens.Pen), "Segment")
		END;
		Attributes.GetBool(e, "Connect", b); Attributes.SetBool(AutoConnect, "Value", b)
	END ApplyTool;

	PROCEDURE DragPoint* (
		tool: LeoTools.Tool; fx, fy: SIGNED16; mask: Display3.Mask; c: Leonardo.Container;
		ox, oy: FLOAT32; CONST str: ARRAY OF CHAR; VAR keys: SET
	);
		VAR
			frame: LeoFrames.Frame; fig: Leonardo.Figure; rm: Leonardo.RenderMsg; p: LeoPaths.Point;
			mkeys, keystate, kstate: SET; x0, y0, x1, y1, len, mx, my: SIGNED16; tol: FLOAT32; s: ARRAY 128 OF CHAR;
	BEGIN
		frame := tool.frame; fig := frame.obj(Leonardo.Figure);
		Oberon.FadeCursor(Oberon.Mouse);
		rm.fig := fig; rm.id := Leonardo.marked; rm.ctxt := LeoTools.DC;
		GfxMatrix.Init(rm.gsm, 1, 0, 0, 1, rm.ctxt.ctm[2, 0], rm.ctxt.ctm[2, 1]);
		Gfx.GetClipRect(rm.ctxt, rm.llx, rm.lly, rm.urx, rm.ury);
		c.handle(c, rm);
		p := c.top(LeoPaths.Point);
		mkeys := keys; Input.Mouse(keys, x0, y0);
		x1 := x0; y1 := y0;
		tool := LeoTools.Current(frame);
		Attributes.GetReal(LeoTools.Tolerance, "Value", tol);
		REPEAT
			len := 0; LeoTools.AppendPoint(tool, p.x, p.y, s, len);
			LeoTools.Append(str, s, len);
			Input.KeyState(keystate);
			LeoTools.PointToFrame(frame, p.x, p.y, mx, my);
			LeoTools.ShowHints(tool, fx, fy, mask, mx, my, Input.CTRL IN keystate);
			LeoTools.ShowStatus(frame, fx, fy, mask, s);
			Oberon.DrawCursor(Oberon.Mouse, Effects.Cross, x1, y1);
			mx := x1; my := y1;
			REPEAT
				Input.Mouse(keys, x1, y1);
				Input.KeyState(kstate)
			UNTIL (keys # mkeys) OR (x1 # mx) OR (y1 # my) OR (kstate # keystate);
			Oberon.FadeCursor(Oberon.Mouse);
			c.handle(c, rm);
			LeoTools.FrameToPoint(frame, x1 - fx, y1 - fy, p.x, p.y);
			LeoTools.Align(tool, ox, oy, p.x, p.y);
			c.handle(c, rm)
		UNTIL (keys # mkeys) OR (ABS(x1 - x0) > tol) OR (ABS(y1 - y0) > tol);
		p.llx := p.x - 0.5; p.lly := p.y - 0.5; p.urx := p.x + 0.5; p.ury := p.y + 0.5;
		c.handle(c, rm)
	END DragPoint;

	PROCEDURE Append* (cont: Leonardo.Container; p: LeoPaths.Point);
	BEGIN
		p.cont := cont;
		p.down := cont.top; cont.top.up := p; cont.top := p
	END Append;


	(**--- Polyline Tool ---**)

	PROCEDURE TrackPolyline (frame: LeoFrames.Frame; VAR msg: Oberon.InputMsg);
		CONST
			status = " +MM: insert point";
		VAR
			tool: LeoTools.Tool; fx, fy, x, y: SIGNED16; px, py, tol: FLOAT32; k, keysum, keys: SET; mask: Display3.Mask;
			closed, connect: BOOLEAN; pen: LeoPens.Pen; p0, p1, p: LeoPaths.Point; poly: LeoPaths.Segment;
			fig: Leonardo.Figure; sm: LeoPaths.SplitMsg; recv: Leonardo.Shape;
	BEGIN
		IF msg.keys = {} THEN
			LeoTools.TrackTool(LeoTools.Current(frame), "start polyline", Effects.Cross, msg)
		ELSIF msg.keys = {2} THEN
			tool := LeoTools.Current(frame);
			fx := msg.x + frame.X; fy := msg.y + frame.Y;
			LeoTools.FrameToPoint(frame, msg.X - fx, msg.Y - fy, px, py);
			LeoTools.Align(tool, px, py, px, py);
			Input.KeyState(k);
			Gadgets.MakeMask(frame, fx, fy, msg.dlink, mask);
			LeoTools.PointToFrame(frame, px, py, x, y);
			LeoTools.ShowHints(tool, fx, fy, mask, x, y, Input.CTRL IN k);
			Attributes.GetBool(ClosedCurve, "Value", closed);
			pen := LeoPenEditors.Find("Segment", closed);
			NEW(p0); LeoPaths.InitPoint(p0, px, py); p0.marked := TRUE;
			NEW(p1); LeoPaths.InitPoint(p1, px, py); p1.marked := TRUE;
			p0.up := p1; p1.down := p0;
			NEW(poly); LeoPaths.InitPolyline(poly, p0, p1, closed, pen);
			LeoTools.Reset(frame, fx, fy);
			Oberon.FadeCursor(Oberon.Mouse);
			keysum := msg.keys; keys := msg.keys;
			DragPoint(tool, fx, fy, mask, poly, px, py, status, keys);
			IF keys = {} THEN
				fig := frame.obj(Leonardo.Figure);
				Leonardo.BeginCommand(fig);
				Attributes.GetReal(LeoTools.Tolerance, "Value", tol); tol := tol/frame.scale;
				sm.llx := px - tol; sm.lly := py - tol; sm.urx := px + tol; sm.ury := py + tol; fig.handle(fig, sm);
				Leonardo.EndCommand(fig)
			ELSIF keys = {2} THEN	(* moving last point => new curve *)
				REPEAT
					REPEAT DragPoint(tool, fx, fy, mask, poly, px, py, status, keys) UNTIL keys # {2};
					IF keys = {2, 1} THEN	(* append point *)
						k := keys;	(* save key state *)
						REPEAT DragPoint(tool, fx, fy, mask, poly, px, py, status, keys) UNTIL keys # k;
						IF keys = {2} THEN	(* released extra key *)
							NEW(p); LeoPaths.InitPoint(p, p1.x, p1.y); p.marked := TRUE;
							Append(poly, p);
							REPEAT
								DragPoint(tool, fx, fy, mask, poly, px, py, status, keys);
								keysum := keysum + keys;
							UNTIL (keys = {2}) OR (keys = {}) OR (keysum = {0..2});
							IF keys = {} THEN	(* didn't move far enough; remove last point *)
								p1.up := NIL; poly.top := p1
							ELSIF keys = {2} THEN
								px := p1.x; py := p1.y;	(* use p1 as new origin *)
								p1 := p	(* continue with appended point *)
							END
						ELSE
							keysum := {0..2}
						END
					END
				UNTIL (keys = {}) OR (keysum = {0..2});
				IF keysum # {0..2} THEN
					LeoPaths.InitPolyline(poly, p0, p1, closed, pen);
					fig := frame.obj(Leonardo.Figure);
					Leonardo.DisableUpdate(fig); Leonardo.BeginCommand(fig);
					Leonardo.Integrate(fig, poly);
					Attributes.GetBool(AutoConnect, "Value", connect);
					IF connect THEN
						Leonardo.Consume(fig, p0.llx, p0.lly, p0.urx, p0.ury, p0, recv);
						Leonardo.Consume(fig, p1.llx, p1.lly, p1.urx, p1.ury, p1, recv)
					END;
					Leonardo.EndCommand(fig); Leonardo.EnableUpdate(fig)
				END
			END;
			REPEAT
				Input.Mouse(keys, x, y);
				Oberon.DrawCursor(Oberon.Mouse, Effects.Cross, x, y)
			UNTIL keys = {};
			msg.res := 0
		ELSE
			LeoTools.Track(LeoTools.Current(frame), msg)
		END
	END TrackPolyline;

	PROCEDURE PolylineTool (obj: Objects.Object; VAR msg: Objects.ObjMsg);
		VAR frame: LeoFrames.Frame; e: LeoPanels.Editor;
	BEGIN
		IF msg IS Oberon.InputMsg THEN
			WITH msg: Oberon.InputMsg DO
				frame := obj(LeoFrames.Frame);
				IF (msg.id = Oberon.track) & ~(Gadgets.selected IN frame.state) &
					LeoTools.InContents(msg.X, msg.Y, msg.x + frame.X, msg.y + frame.Y, frame.W, frame.H)
				THEN
					TrackPolyline(frame, msg)
				ELSE
					LeoTools.HandleFrame(obj, msg)
				END
			END
		ELSIF msg IS Objects.LinkMsg THEN
			WITH msg: Objects.LinkMsg DO
				IF (msg.id = Objects.get) & (msg.name = "Editor") & (msg.res < 0) THEN
					msg.obj := LeoPanels.CopyObj("SegmentToolPanel", TRUE);
					Links.GetLink(msg.obj, "Model", obj);
					IF (obj # NIL) & (obj IS LeoPanels.Editor) THEN
						e := obj(LeoPanels.Editor); e.handle := LeoPenEditors.HandleShapeEditor;
						e.revert := RevertTool; e.apply := ApplyTool; RevertTool(e)
					END
				ELSE
					LeoTools.HandleFrame(obj, msg)
				END
			END
		ELSE
			LeoTools.HandleFrame(obj, msg)
		END
	END PolylineTool;

	(** activate polyline tool **)
	PROCEDURE ActivatePolyline*;
	BEGIN
		LeoTools.Activate(PolylineTool)
	END ActivatePolyline;


	(**--- Bezier Tool ---**)

	PROCEDURE TrackBezier (frame: LeoFrames.Frame; VAR msg: Oberon.InputMsg);
		CONST
			status = " +MM: insert point";
		VAR
			tool: LeoTools.Tool; fx, fy, x, y: SIGNED16; px, py, tol: FLOAT32; k, keysum, keys: SET; mask: Display3.Mask;
			closed, connect: BOOLEAN; pen: LeoPens.Pen; p0, p1, p: LeoPaths.Point; bez: LeoPaths.Segment;
			fig: Leonardo.Figure; sm: LeoPaths.SplitMsg; recv: Leonardo.Shape;
	BEGIN
		IF msg.keys = {} THEN
			LeoTools.TrackTool(LeoTools.Current(frame), "start bezier", Effects.Cross, msg)
		ELSIF msg.keys = {2} THEN
			tool := LeoTools.Current(frame);
			fx := msg.x + frame.X; fy := msg.y + frame.Y;
			LeoTools.FrameToPoint(frame, msg.X - fx, msg.Y - fy, px, py);
			LeoTools.Align(tool, px, py, px, py);
			Input.KeyState(k);
			Gadgets.MakeMask(frame, fx, fy, msg.dlink, mask);
			LeoTools.PointToFrame(frame, px, py, x, y);
			LeoTools.ShowHints(tool, fx, fy, mask, x, y, Input.CTRL IN k);
			Attributes.GetBool(ClosedCurve, "Value", closed);
			pen := LeoPenEditors.Find("Segment", closed);
			NEW(p0); LeoPaths.InitPoint(p0, px, py); p0.marked := TRUE;
			NEW(p1); LeoPaths.InitPoint(p1, px, py); p1.marked := TRUE;
			p0.up := p1; p1.down := p0;
			NEW(bez); LeoPaths.InitBezier(bez, p0, p1, closed, pen);
			LeoTools.Reset(frame, fx, fy);
			Oberon.FadeCursor(Oberon.Mouse);
			keysum := msg.keys; keys := msg.keys;
			DragPoint(tool, fx, fy, mask, bez, px, py, status, keys);
			IF keys = {} THEN
				fig := frame.obj(Leonardo.Figure);
				Leonardo.BeginCommand(fig);
				Attributes.GetReal(LeoTools.Tolerance, "Value", tol); tol := tol/frame.scale;
				sm.llx := px - tol; sm.lly := py - tol; sm.urx := px + tol; sm.ury := py + tol; fig.handle(fig, sm);
				Leonardo.EndCommand(fig)
			ELSIF keys = {2} THEN	(* moving last point => new curve *)
				REPEAT
					REPEAT DragPoint(tool, fx, fy, mask, bez, px, py, status, keys) UNTIL keys # {2};
					IF keys = {2, 1} THEN	(* append point *)
						k := keys;	(* save key state *)
						REPEAT DragPoint(tool, fx, fy, mask, bez, px, py, status, keys) UNTIL keys # k;
						IF keys = {2} THEN	(* released extra key *)
							NEW(p); LeoPaths.InitPoint(p, p1.x, p1.y); p.marked := TRUE;
							Append(bez, p);
							REPEAT
								DragPoint(tool, fx, fy, mask, bez, px, py, status, keys);
								keysum := keysum + keys;
							UNTIL (keys = {2}) OR (keys = {}) OR (keysum = {0..2});
							IF keys = {} THEN	(* didn't move far enough; remove last point *)
								p1.up := NIL; bez.top := p1
							ELSIF keys = {2} THEN
								px := p1.x; py := p1.y;	(* use p1 as new origin *)
								p1 := p	(* continue with appended point *)
							END
						ELSE
							keysum := {0..2}
						END
					END
				UNTIL (keys = {}) OR (keysum = {0..2});
				IF keysum # {0..2} THEN
					LeoPaths.InitBezier(bez, p0, p1, closed, pen);
					fig := frame.obj(Leonardo.Figure);
					Leonardo.DisableUpdate(fig); Leonardo.BeginCommand(fig);
					Leonardo.Integrate(fig, bez);
					Attributes.GetBool(AutoConnect, "Value", connect);
					IF connect THEN
						Leonardo.Consume(fig, p0.llx, p0.lly, p0.urx, p0.ury, p0, recv);
						Leonardo.Consume(fig, p1.llx, p1.lly, p1.urx, p1.ury, p1, recv)
					END;
					Leonardo.EndCommand(fig); Leonardo.EnableUpdate(fig)
				END
			END;
			REPEAT
				Input.Mouse(keys, x, y);
				Oberon.DrawCursor(Oberon.Mouse, Effects.Cross, x, y)
			UNTIL keys = {};
			msg.res := 0
		ELSE
			LeoTools.Track(LeoTools.Current(frame), msg)
		END
	END TrackBezier;

	PROCEDURE BezierTool (obj: Objects.Object; VAR msg: Objects.ObjMsg);
		VAR frame: LeoFrames.Frame; e: LeoPanels.Editor;
	BEGIN
		IF msg IS Oberon.InputMsg THEN
			WITH msg: Oberon.InputMsg DO
				frame := obj(LeoFrames.Frame);
				IF (msg.id = Oberon.track) & ~(Gadgets.selected IN frame.state) &
					LeoTools.InContents(msg.X, msg.Y, msg.x + frame.X, msg.y + frame.Y, frame.W, frame.H)
				THEN
					TrackBezier(frame, msg)
				ELSE
					LeoTools.HandleFrame(obj, msg)
				END
			END
		ELSIF msg IS Objects.LinkMsg THEN
			WITH msg: Objects.LinkMsg DO
				IF (msg.id = Objects.get) & (msg.name = "Editor") & (msg.res < 0) THEN
					msg.obj := LeoPanels.CopyObj("SegmentToolPanel", TRUE);
					Links.GetLink(msg.obj, "Model", obj);
					IF (obj # NIL) & (obj IS LeoPanels.Editor) THEN
						e := obj(LeoPanels.Editor); e.handle := LeoPenEditors.HandleShapeEditor;
						e.revert := RevertTool; e.apply := ApplyTool; RevertTool(e)
					END
				ELSE
					LeoTools.HandleFrame(obj, msg)
				END
			END
		ELSE
			LeoTools.HandleFrame(obj, msg)
		END
	END BezierTool;

	(** activate bezier tool **)
	PROCEDURE ActivateBezier*;
	BEGIN
		LeoTools.Activate(BezierTool)
	END ActivateBezier;


	(**--- Arc Tool ---**)

	PROCEDURE TrackArc (frame: LeoFrames.Frame; VAR msg: Oberon.InputMsg);
		VAR
			tool: LeoTools.Tool; fx, fy, hx, hy, len, mx, my, l, x, y: SIGNED16; x0, y0, x1, y1, px, py: FLOAT32; s: ARRAY 128 OF CHAR;
			mask: Display3.Mask; state, keysum, keys: SET; closed: BOOLEAN; pen: LeoPens.Pen; arc: LeoPaths.Arc; fig: Leonardo.Figure;
	BEGIN
		IF msg.keys = {} THEN
			LeoTools.TrackTool(LeoTools.Current(frame), "arc", Effects.Cross, msg)
		ELSIF msg.keys = {2} THEN
			tool := LeoTools.Current(frame);
			fx := msg.x + frame.X; fy := msg.y + frame.Y;
			LeoTools.FrameToPoint(frame, msg.X - fx, msg.Y - fy, x0, y0);
			LeoTools.Align(tool, x0, y0, x0, y0);
			Input.KeyState(state);
			Gadgets.MakeMask(frame, fx, fy, msg.dlink, mask);
			LeoTools.PointToFrame(frame, x0, y0, hx, hy);
			LeoTools.ShowHints(tool, fx, fy, mask, hx, hy, Input.CTRL IN state);
			Attributes.GetBool(ClosedCurve, "Value", closed);
			pen := LeoPenEditors.Find("Segment", closed);
			len := 0; LeoTools.AppendPoint(tool, x0, y0, s, len);
			LeoTools.ShowStatus(frame, fx, fy, mask, s);
			LeoTools.Append(", ", s, len);
			LeoTools.Reset(frame, fx, fy);
			Oberon.FadeCursor(Oberon.Mouse);
			keysum := msg.keys; mx := -1; my := -1; x1 := x0; y1 := y0;
			REPEAT
				Gfx.DrawEllipse(LeoTools.DC, 0.5*(x0 + x1), 0.5*(y0 + y1), 0.5*(x1 - x0), 0.5*(y1 - y0), {Gfx.Stroke});
				Input.KeyState(state);
				LeoTools.PointToFrame(frame, x1, y1, hx, hy);
				LeoTools.ShowHints(tool, fx, fy, mask, hx, hy, Input.CTRL IN state);
				l := len;
				LeoTools.AppendPoint(tool, x1, y1, s, l);
				LeoTools.Append("  width=", s, l); LeoTools.AppendReal(ABS(x1 - x0)/tool.unit, s, l);
				LeoTools.Append("  height=", s, l); LeoTools.AppendReal(ABS(y1 - y0)/tool.unit, s, l);
				LeoTools.ShowStatus(frame, fx, fy, mask, s);
				px := x1; py := y1;
				REPEAT
					Input.Mouse(keys, x, y); keysum := keysum + keys;
					IF (keys # {}) & ((x # mx) OR (y # my)) THEN
						Oberon.DrawCursor(Oberon.Mouse, Effects.Cross, x, y);
						LeoTools.FrameToPoint(frame, x - fx, y - fy, x1, y1);
						LeoTools.Align(tool, x0, y0, x1, y1);
						mx := x; my := y
					END
				UNTIL (keys = {}) OR (x1 # px) OR (y1 # py);
				Oberon.FadeCursor(Oberon.Mouse);
				Gfx.DrawEllipse(LeoTools.DC, 0.5*(x0 + px), 0.5*(y0 + py), 0.5*(px - x0), 0.5*(py - y0), {Gfx.Stroke})
			UNTIL keys = {};
			IF (keysum = {2}) & (x1 # x0) & (y1 # y0) THEN
				NEW(arc); LeoPaths.InitArc(arc, 0.5*(x0 + x1), 0.5*(y0 + y1), 0.5*(x1 - x0), 0.5*(y1 - y0), 0, 0, pen);
				fig := frame.obj(Leonardo.Figure);
				Leonardo.Integrate(fig, arc)
			END;
			Oberon.DrawCursor(Oberon.Mouse, Effects.Cross, mx, my);
			msg.res := 0
		ELSE
			LeoTools.Track(LeoTools.Current(frame), msg)
		END
	END TrackArc;

	PROCEDURE RevertArcTool (e: LeoPanels.Editor);
		VAR b: BOOLEAN; m: SIGNED32;
	BEGIN
		Attributes.GetBool(ClosedCurve, "Value", b); Attributes.SetBool(e, "Closed", b);
		Attributes.GetInt(ArcMode, "Value", m); Attributes.SetInt(e, "Mode", m);
		Links.SetLink(e, "Pen", LeoPenEditors.Find("Segment", b));
		Gadgets.Update(e)
	END RevertArcTool;

	PROCEDURE ApplyArcTool (e: LeoPanels.Editor);
		VAR b: BOOLEAN; m: SIGNED32; obj: Objects.Object;
	BEGIN
		Attributes.GetBool(e, "Closed", b); Attributes.SetBool(ClosedCurve, "Value", b);
		Attributes.GetInt(e, "Mode", m); Attributes.SetInt(ArcMode, "Value", m);
		Links.GetLink(e, "Pen", obj);
		IF (obj # NIL) & (obj IS LeoPens.Pen) & (obj # LeoPenEditors.Find("Segment", b)) THEN
			LeoPenEditors.Register(obj(LeoPens.Pen), "Segment")
		END
	END ApplyArcTool;

	PROCEDURE ArcTool (obj: Objects.Object; VAR msg: Objects.ObjMsg);
		VAR frame: LeoFrames.Frame; e: LeoPanels.Editor;
	BEGIN
		IF msg IS Oberon.InputMsg THEN
			WITH msg: Oberon.InputMsg DO
				frame := obj(LeoFrames.Frame);
				IF (msg.id = Oberon.track) & ~(Gadgets.selected IN frame.state) &
					LeoTools.InContents(msg.X, msg.Y, msg.x + frame.X, msg.y + frame.Y, frame.W, frame.H)
				THEN
					TrackArc(frame, msg)
				ELSE
					LeoTools.HandleFrame(obj, msg)
				END
			END
		ELSIF msg IS Objects.LinkMsg THEN
			WITH msg: Objects.LinkMsg DO
				IF (msg.id = Objects.get) & (msg.name = "Editor") & (msg.res < 0) THEN
					msg.obj := LeoPanels.CopyObj("ArcToolPanel", TRUE);
					Links.GetLink(msg.obj, "Model", obj);
					IF (obj # NIL) & (obj IS LeoPanels.Editor) THEN
						e := obj(LeoPanels.Editor); e.handle := LeoPenEditors.HandleShapeEditor;
						e.revert := RevertArcTool; e.apply := ApplyArcTool; RevertArcTool(e)
					END
				ELSE
					LeoTools.HandleFrame(obj, msg)
				END
			END
		ELSE
			LeoTools.HandleFrame(obj, msg)
		END
	END ArcTool;

	PROCEDURE ActivateArc*;
	BEGIN
		LeoTools.Activate(ArcTool)
	END ActivateArc;

	PROCEDURE RevertArc (editor: LeoPanels.Editor);
		VAR obj: Objects.Object; arc: LeoPaths.Arc; b: BOOLEAN;
	BEGIN
		Links.GetLink(editor, "Model", obj);
		IF (obj # NIL) & (obj IS LeoPaths.Arc) THEN
			arc := obj(LeoPaths.Arc);
			Links.SetLink(editor, "Pen", arc.pen); Attributes.SetBool(editor, "Closed", arc.closed);
			Attributes.SetInt(editor, "Mode", arc.mode);
			Attributes.SetInt(editor, "Pred", arc.pred); Attributes.SetInt(editor, "Succ", arc.succ);
			Links.GetLink(editor, "List", obj);
			IF obj # NIL THEN
				Links.SetLink(obj, "Model", Leonardo.ContainingFigure(arc));
				Links.SetLink(obj, "Container", arc);
				Gadgets.Update(obj)
			END;
			Links.GetLink(editor, "Bar", obj);
			IF obj # NIL THEN
				Attributes.GetBool(obj, "ArrowBoxes", b); Attributes.SetBool(obj, "ArrowBoxes", b)	(* force AdjustKnoblen *)
			END;
			Gadgets.Update(editor)
		END
	END RevertArc;

	PROCEDURE ApplyArc (editor: LeoPanels.Editor);
		VAR obj: Objects.Object; arc: LeoPaths.Arc; b: BOOLEAN; i: SIGNED32;
	BEGIN
		Links.GetLink(editor, "Model", obj);
		IF (obj # NIL) & (obj IS LeoPaths.Arc) & (editor.fig # NIL) THEN
			arc := obj(LeoPaths.Arc);
			Leonardo.BeginCommand(editor.fig);
			Links.GetLink(editor, "Pen", obj);
			IF (obj # arc.pen) & (obj # NIL) & (obj IS LeoPens.Pen) THEN
				LeoPenEditors.SetPen(editor.fig, arc, "Pen", obj(LeoPens.Pen))
			END;
			Attributes.GetBool(editor, "Closed", b); Leonardo.SetBool(editor.fig, arc, "Closed", b);
			Attributes.GetInt(editor, "Mode", i); Leonardo.SetInt(editor.fig, arc, "Mode", i);
			Attributes.GetInt(editor, "Pred", i); LeoPaths.SetPred(editor.fig, arc, SHORT(SHORT(i)));
			Attributes.GetInt(editor, "Succ", i); LeoPaths.SetSucc(editor.fig, arc, SHORT(SHORT(i)));
			Leonardo.EndCommand(editor.fig)
		END
	END ApplyArc;

	PROCEDURE NewArc*;
		VAR obj: Objects.Object; editor: LeoPanels.Editor;
	BEGIN
		Objects.NewObj := LeoPanels.CopyObj("ArcPanel", TRUE);
		Links.GetLink(Objects.NewObj, "Model", obj);
		IF (obj # NIL) & (obj IS LeoPanels.Editor) THEN
			editor := obj(LeoPanels.Editor); editor.handle := LeoPenEditors.HandleShapeEditor;
			editor.revert := RevertArc; editor.apply := ApplyArc;
			Links.SetLink(editor, "List", Gadgets.FindObj(Objects.NewObj, "List"));
			Links.SetLink(editor, "Bar", Gadgets.FindObj(Objects.NewObj, "Bar"))
		END
	END NewArc;


	(**--- Paths ---**)

	PROCEDURE RevertPath (editor: LeoPanels.Editor);
		VAR obj: Objects.Object; path: LeoPaths.Path; b: BOOLEAN;
	BEGIN
		Links.GetLink(editor, "Model", obj);
		IF (obj # NIL) & (obj IS LeoPaths.Path) THEN
			path := obj(LeoPaths.Path);
			Links.SetLink(editor, "Pen", path.pen);
			Links.GetLink(editor, "List", obj);
			IF obj # NIL THEN
				Links.SetLink(obj, "Model", Leonardo.ContainingFigure(path));
				Links.SetLink(obj, "Container", path);
				Gadgets.Update(obj)
			END;
			Links.GetLink(editor, "Bar", obj);
			IF obj # NIL THEN
				Attributes.GetBool(obj, "ArrowBoxes", b); Attributes.SetBool(obj, "ArrowBoxes", b)	(* force AdjustKnoblen *)
			END;
			Gadgets.Update(editor)
		END
	END RevertPath;

	PROCEDURE ApplyPath (editor: LeoPanels.Editor);
		VAR obj: Objects.Object; path: LeoPaths.Path;
	BEGIN
		Links.GetLink(editor, "Model", obj);
		IF (obj # NIL) & (obj IS LeoPaths.Path) THEN
			path := obj(LeoPaths.Path);
			Leonardo.BeginCommand(editor.fig);
			Links.GetLink(editor, "Pen", obj);
			IF (obj # path.pen) & (obj # NIL) & (obj IS LeoPens.Pen) THEN
				LeoPenEditors.SetPen(editor.fig, path, "Pen", obj(LeoPens.Pen))
			END;
			Leonardo.EndCommand(editor.fig)
		END
	END ApplyPath;

	PROCEDURE NewPath*;
		VAR obj: Objects.Object; editor: LeoPanels.Editor;
	BEGIN
		Objects.NewObj := LeoPanels.CopyObj("PathPanel", TRUE);
		Links.GetLink(Objects.NewObj, "Model", obj);
		IF (obj # NIL) & (obj IS LeoPanels.Editor) THEN
			editor := obj(LeoPanels.Editor); editor.handle := LeoPenEditors.HandleShapeEditor;
			editor.revert := RevertPath; editor.apply := ApplyPath;
			Links.SetLink(editor, "List", Gadgets.FindObj(Objects.NewObj, "List"));
			Links.SetLink(editor, "Bar", Gadgets.FindObj(Objects.NewObj, "Bar"))
		END
	END NewPath;

	PROCEDURE HandlePath (obj: Objects.Object; VAR msg: Objects.ObjMsg);
	BEGIN
		IF msg IS Leonardo.ControlMsg THEN Leonardo.HandleContainer(obj, msg)
		ELSE LeoPaths.HandlePath(obj, msg)
		END
	END HandlePath;

	PROCEDURE Realize*;
		VAR e: LeoPanels.Editor; obj: Objects.Object;
	BEGIN
		e := LeoPanels.FindEditor(Gadgets.context);
		Links.GetLink(e, "Model", obj);
		IF (obj # NIL) & (obj IS LeoPaths.Path) THEN
			LeoPaths.Realize(obj(LeoPaths.Path))
		END
	END Realize;

	PROCEDURE Dissolve*;
		VAR obj: Objects.Object; path: LeoPaths.Path; fig: Leonardo.Figure;
	BEGIN
		Links.GetLink(LeoPanels.FindEditor(Gadgets.context), "Model", obj);
		IF (obj # NIL) & (obj IS LeoPaths.Path) THEN
			path := obj(LeoPaths.Path);
			fig := Leonardo.ContainingFigure(path);
			Leonardo.DisableUpdate(fig);
			Leonardo.BeginCommand(fig);
			Leonardo.AddDeleteAction(fig, path.down, path, path, path.up, path.cont(Leonardo.Container));
			Leonardo.AddConsumeAction(fig, path.down, path.bottom, path.top, path.up, path.cont(Leonardo.Container));
			Leonardo.EndCommand(fig);
			Leonardo.EnableUpdate(fig);
			LeoPanels.GetSelection
		END
	END Dissolve;

	PROCEDURE SelToPath*;
		VAR
			fig: Leonardo.Figure; sel, s, bot: Leonardo.Shape; obj: Objects.Object;
			cm: LeoPaths.ContourMsg; path: LeoPaths.Path;
	BEGIN
		fig := LeoPanels.FindFigure(Gadgets.context);
		IF fig # NIL THEN
			sel := Leonardo.Selection(fig); obj := sel;
			LOOP
				IF obj = NIL THEN RETURN END;
				cm.done := FALSE; obj.handle(obj, cm);
				IF cm.done THEN EXIT END;
				obj := obj.slink
			END;
			Leonardo.BeginCommand(fig);
			sel.sel := FALSE;
			NEW(path); LeoPaths.InitPath(path, s, sel, LeoPenEditors.Find("Path", FALSE)); path.handle := HandlePath;
			Leonardo.Integrate(fig, path); bot := NIL;
			REPEAT
				sel := obj(Leonardo.Shape); s := sel; s.sel := FALSE; obj := obj.slink;
				WHILE (obj # NIL) & (obj = s.down) & cm.done DO
					cm.done := FALSE; obj.handle(obj, cm);
					IF cm.done THEN
						s := obj(Leonardo.Shape); s.sel := FALSE; obj := obj.slink
					END
				END;
				s.slink := NIL; Leonardo.Delete(fig, sel);
				Leonardo.BeginCommand(fig);
				Leonardo.AddConsumeAction(fig, NIL, s, sel, bot, path); bot := s;
				Leonardo.EndCommand(fig);
				WHILE (obj # NIL) & ~cm.done DO
					obj := obj.slink;
					IF obj # NIL THEN
						cm.done := FALSE; obj.handle(obj, cm)
					END
				END
			UNTIL obj = NIL;
			path.handle := LeoPaths.HandlePath;
			Leonardo.EndCommand(fig)
		END
	END SelToPath;


BEGIN
	ClosedCurve := LeoPanels.FindObj("ClosedCurve");
	AutoConnect := LeoPanels.FindObj("AutoConnect");
	ArcMode := LeoPanels.FindObj("ArcMode")
END LeoPathEditors.
