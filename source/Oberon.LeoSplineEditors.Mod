(* ETH Oberon, Copyright 2001 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

MODULE LeoSplineEditors IN Oberon; (** portable **)	(* eos  *)

	(**
		Leonardo spline tool
	**)

	IMPORT
		Input, Objects, Oberon, Display3, Effects, Attributes, Links, Gadgets, Leonardo, LeoPens,
		LeoPaths, LeoFrames, LeoTools, LeoPanels, LeoPenEditors, LeoPathEditors, LeoSplines;


	(**--- Spline Tool ---**)

	PROCEDURE TrackSpline (frame: LeoFrames.Frame; VAR msg: Oberon.InputMsg);
		CONST
			status = " +MM: insert point";
		VAR
			tool: LeoTools.Tool; fx, fy, x, y: SIGNED16; px, py, tol: FLOAT32; k, keysum, keys: SET; mask: Display3.Mask;
			closed, connect: BOOLEAN; pen: LeoPens.Pen; p0, p1, p: LeoPaths.Point; sp: LeoSplines.Spline; fig: Leonardo.Figure;
			sm: LeoPaths.SplitMsg; recv: Leonardo.Shape;
	BEGIN
		IF msg.keys = {} THEN
			LeoTools.TrackTool(LeoTools.Current(frame), "spline", Effects.Cross, msg)
		ELSIF msg.keys = {2} THEN
			tool := LeoTools.Current(frame);
			fx := msg.x + frame.X; fy := msg.y + frame.Y;
			LeoTools.FrameToPoint(frame, msg.X - fx, msg.Y - fy, px, py);
			LeoTools.Align(tool, px, py, px, py);
			Input.KeyState(k);
			Gadgets.MakeMask(frame, fx, fy, msg.dlink, mask);
			LeoTools.PointToFrame(frame, px, py, x, y);
			LeoTools.ShowHints(tool, fx, fy, mask, x, y, Input.CTRL IN k);
			Attributes.GetBool(LeoPathEditors.ClosedCurve, "Value", closed);
			pen := LeoPenEditors.Find("Segment", closed);
			NEW(p0); LeoPaths.InitPoint(p0, px, py); p0.marked := TRUE;
			NEW(p1); LeoPaths.InitPoint(p1, px, py); p1.marked := TRUE;
			p0.up := p1; p1.down := p0;
			NEW(sp); LeoSplines.Init(sp, p0, p1, closed, pen);
			LeoTools.Reset(frame, fx, fy);
			Oberon.FadeCursor(Oberon.Mouse);
			keysum := msg.keys; keys := msg.keys;
			LeoPathEditors.DragPoint(tool, fx, fy, mask, sp, px, py, status, keys);
			IF keys = {} THEN
				fig := frame.obj(Leonardo.Figure);
				Leonardo.BeginCommand(fig);
				Attributes.GetReal(LeoTools.Tolerance, "Value", tol); tol := tol/frame.scale;
				sm.llx := px - tol; sm.lly := py - tol; sm.urx := px + tol; sm.ury := py + tol; fig.handle(fig, sm);
				Leonardo.EndCommand(fig)
			ELSIF keys = {2} THEN	(* moving last point => new curve *)
				REPEAT
					REPEAT LeoPathEditors.DragPoint(tool, fx, fy, mask, sp, px, py, status, keys) UNTIL keys # {2};
					IF keys = {2, 1} THEN	(* append point *)
						REPEAT LeoPathEditors.DragPoint(tool, fx, fy, mask, sp, px, py, status, keys) UNTIL keys # k;
						IF keys = {2} THEN	(* released extra key *)
							NEW(p); LeoPaths.InitPoint(p, p1.x, p1.y); p.marked := TRUE;
							LeoPathEditors.Append(sp, p);
							REPEAT
								LeoPathEditors.DragPoint(tool, fx, fy, mask, sp, px, py, status, keys);
								keysum := keysum + keys;
							UNTIL (keys = {2}) OR (keys = {}) OR (keysum = {0..2});
							IF keys = {} THEN	(* didn't move far enough; remove last point *)
								p1.up := NIL; sp.top := p1
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
					LeoSplines.Init(sp, p0, p1, closed, pen);
					fig := frame.obj(Leonardo.Figure);
					Leonardo.DisableUpdate(fig); Leonardo.BeginCommand(fig);
					Leonardo.Integrate(fig, sp);
					Attributes.GetBool(LeoPathEditors.AutoConnect, "Value", connect);
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
	END TrackSpline;

	PROCEDURE SplineTool (obj: Objects.Object; VAR msg: Objects.ObjMsg);
		VAR frame: LeoFrames.Frame; e: LeoPanels.Editor;
	BEGIN
		IF msg IS Oberon.InputMsg THEN
			WITH msg: Oberon.InputMsg DO
				frame := obj(LeoFrames.Frame);
				IF (msg.id = Oberon.track) & ~(Gadgets.selected IN frame.state) &
					LeoTools.InContents(msg.X, msg.Y, msg.x + frame.X, msg.y + frame.Y, frame.W, frame.H)
				THEN
					TrackSpline(frame, msg)
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
						e := obj(LeoPanels.Editor); e.revert := LeoPathEditors.RevertTool; e.apply := LeoPathEditors.ApplyTool;
						e.revert(e)
					END
				ELSE
					LeoTools.HandleFrame(obj, msg)
				END
			END
		ELSE
			LeoTools.HandleFrame(obj, msg)
		END
	END SplineTool;

	(** activate spline tool **)
	PROCEDURE ActivateSpline*;
	BEGIN
		LeoTools.Activate(SplineTool)
	END ActivateSpline;


END LeoSplineEditors.
