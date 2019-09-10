(* ETH Oberon, Copyright 2001 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

MODULE LeoPaths IN Oberon; (** portable **)	(* eos  *)

	(**
		Leonardo vector graphics: paths, path segments, contour protocol, etc.
	**)

	(*
		to do:
		- link shape to segment?
	*)

	IMPORT
		Files, Math IN A2, Display, Objects, Attributes, Strings, Gadgets, PictImages, GfxMatrix, GfxImages, GfxPaths, Gfx,
		Leonardo, LeoPens;


	CONST
		get* = 1; set* = 2;	(** link message id **)
		term* = 0; coincident* = 1; collinear* = 2; symmetric* = 3; wrap* = 4;	(** continuity modes **)
		start* = 1; end* = 2; notify* = 3;	(** connect message id **)

		wedge* = 0; segment* = 1;	(** arc modes **)


	TYPE
		Point* = POINTER TO PointDesc;
		PointDesc* = RECORD (Leonardo.ShapeDesc)
			x*, y*: FLOAT32;	(** point coordinates **)
			link*: Leonardo.Shape;	(** shape controlled by point **)
		END;

		(** message for getting and setting positional shape links **)
		LinkMsg* = RECORD (Leonardo.LocalizedMsg)
			id*: SIGNED8;	(** get/set **)
			done*: BOOLEAN;	(** to be set by receiver **)
			x*, y*: FLOAT32;	(** coordinates in global space (in/out) **)
		END;

		LinkAction = POINTER TO LinkActionDesc;
		LinkActionDesc = RECORD (Leonardo.ActionDesc)
			p: Point;
			link: Leonardo.Shape;
		END;

		(** container drawing several contours with the same pen **)
		Path* = POINTER TO PathDesc;
		PathDesc* = RECORD (Leonardo.ContainerDesc)
			pen*: LeoPens.Pen;	(** pen to use for all contours **)
		END;

		(** message for querying contour shapes **)
		ContourMsg* = RECORD (Leonardo.ShapeMsg)
			done*: BOOLEAN;	(** to be set by receiver if it can render itself with a pen **)
		END;

		(** message requesting a contour to render itself with the given pen **)
		RenderMsg* = RECORD (Leonardo.ShapeMsg)
			pen*: LeoPens.Pen;	(** (opened) pen to use **)
		END;

		(** connectable segments **)
		Segment* = POINTER TO SegmentDesc;
		SegmentDesc* = RECORD (Leonardo.ContainerDesc)
			pen*: LeoPens.Pen;	(** pen for rendering **)
			closed*: BOOLEAN;	(** set if segment returns to first point after last one **)
			pred*, succ*: SIGNED8;	(** continuity mode **)
			boff*, eoff*: FLOAT32;	(** offsets from begin and to end of connected contour **)
			len*: FLOAT32;	(** segment length **)
		END;

		(** message for exchanging information between neighboring contours **)
		ConnectMsg* = RECORD (Leonardo.ShapeMsg)
			id*: SIGNED8;	(** get/set **)
			pos*: SIGNED8;	(** start/end **)
			mode*: SIGNED8;	(** term/coincident/collinear/symmetric **)
			done*: BOOLEAN;	(** to be set by receiver **)
			x*, y*: FLOAT32;	(** position in local space **)
			dx*, dy*: FLOAT32;	(** direction vector in local space **)
		END;

		(** message for updating segment offsets **)
		ValidateMsg* = RECORD (Leonardo.ShapeMsg)
			pos*: SIGNED8;	(** start/end **)
			off*: FLOAT32;	(** start: boff, end: eoff **)
		END;

		(** segment splitting **)
		SplitMsg* = RECORD (Leonardo.LocalizedMsg)
			llx*, lly*, urx*, ury*: FLOAT32;	(** split location **)
		END;

		ModeAction = POINTER TO ModeActionDesc;
		ModeActionDesc = RECORD (Leonardo.ActionDesc)
			seg: Segment;
			mode: SIGNED8;
		END;

		(** arc segments **)
		Arc* = POINTER TO ArcDesc;
		ArcDesc* = RECORD (SegmentDesc)
			mode*: SIGNED8;	(** close mode: wedge/segment **)
			mat*: GfxMatrix.Matrix;	(** ellipse specification **)
			dx0, dy0, dx1, dy1: FLOAT32;
		END;

		ArcData = RECORD (GfxPaths.EnumData)
			n: SIGNED32;
			dx0, dy0, dx1, dy1: FLOAT32;
		END;

		(** pen for realizing contour into segments **)
		Pathifier* = POINTER TO PathifierDesc;
		PathifierDesc* = RECORD (LeoPens.PenDesc)
			bot*, top*: Segment;
			enter: Segment;
			elem: SIGNED8;
			x0, y0, x, y: FLOAT32;
		END;


	VAR
		Img*: ARRAY 4 OF GfxImages.Image;
		Rec: LeoPens.Recorder;
		ArcPath: GfxPaths.Path;
		PathifierMethods: LeoPens.Methods;


	(**--- Points ---**)

	PROCEDURE InitPointImages;
		VAR p: ARRAY 11 OF SET;
	BEGIN
		p[0] := {0..2}; p[1] := {0, 2}; p[2] := {0..2};
		NEW(Img[0]); PictImages.PatternToImage(Display.NewPattern(3, 3, p), Img[0]);
		p[0] := {1..3}; p[1] := {0, 4}; p[2] := {0, 4}; p[3] := {0, 4}; p[4] := {1..3};
		NEW(Img[1]); PictImages.PatternToImage(Display.NewPattern(5, 5, p), Img[1]);
		p[0] := {2..4}; p[1] := {1, 5}; p[2] := {0, 6}; p[3] := {0, 6}; p[4] := {0, 6}; p[5] := {1, 5}; p[6] := {2..4};
		NEW(Img[2]); PictImages.PatternToImage(Display.NewPattern(7, 7, p), Img[2]);
		p[0] := {3..4, 6..7}; p[1] := {1, 9}; p[2] := {}; p[3] := {0, 10}; p[4] := {0, 10}; p[5] := {};
		p[6] := {0, 10}; p[7] := {0, 10}; p[8] := {}; p[9] := {1, 9}; p[10] := {3..4, 6..7};
		NEW(Img[3]); PictImages.PatternToImage(Display.NewPattern(11, 11, p), Img[3])
	END InitPointImages;

	PROCEDURE DoLink (fig: Leonardo.Figure; a: Leonardo.Action);
		VAR act: LinkAction;
	BEGIN
		act := a(LinkAction); act.p.link := act.link; act.p.sel := TRUE
	END DoLink;

	PROCEDURE UndoLink (fig: Leonardo.Figure; a: Leonardo.Action);
		VAR act: LinkAction;
	BEGIN
		act := a(LinkAction); act.p.link := NIL; act.p.sel := TRUE
	END UndoLink;

	PROCEDURE Unlink (fig: Leonardo.Figure; p: Point);
		VAR act: LinkAction;
	BEGIN
		NEW(act); act.do := UndoLink; act.undo := DoLink; act.p := p; act.link := p.link;
		Leonardo.AddAction(fig, act)
	END Unlink;

	PROCEDURE ControlPoint (p: Point; VAR msg: Leonardo.ControlMsg);
		VAR link: Leonardo.Shape; cm: Objects.CopyMsg;
	BEGIN
		Leonardo.HandleShape(p, msg);
		IF msg.id = Leonardo.delete THEN
			link := p.link; WHILE (link # NIL) & ~link.marked DO link := link.cont END;
			IF link # NIL THEN	(* link will get deleted.. *)
				link := p; WHILE (link # NIL) & ~link.marked DO link := link.cont END;
				IF link = NIL THEN	(* ...but point won't *)
					Unlink(msg.fig, p)
				END
			END
		ELSIF (msg.id = Leonardo.clone) & p.marked THEN	(* link copy if original link gets cloned, too *)
			IF (p.link # NIL) & p.link.marked THEN
				cm.stamp := msg.stamp; cm.id := Objects.shallow; p.link.handle(p.link, cm);
				p.dlink(Point).link := cm.obj(Leonardo.Shape)
			END
		END
	END ControlPoint;

	PROCEDURE ValidatePoint (p: Point; VAR msg: Leonardo.ValidateMsg);
		VAR x, y: FLOAT32;
	BEGIN
		IF p.marked THEN
			Leonardo.UpdateShape(msg.fig, p);
			GfxMatrix.Apply(msg.lgm, p.x, p.y, x, y);
			p.llx := x - 0.5; p.lly := y - 0.5; p.urx := x + 0.5; p.ury := y + 0.5;
			Leonardo.UpdateShape(msg.fig, p);
			p.marked := FALSE; p.cont.marked := TRUE
		END
	END ValidatePoint;

	PROCEDURE ConsumePoint (p: Point; VAR msg: Leonardo.ConsumeMsg);
		VAR lm: LinkMsg; act: LinkAction;
	BEGIN
		IF (p.link = NIL) & (msg.recv = NIL) & (msg.bottom = msg.top) & (msg.top.cont # p.cont) &
			(msg.llx <= p.urx) & (p.llx <= msg.urx) & (msg.lly <= p.ury) & (p.lly <= msg.ury)
		THEN
			lm.fig := msg.fig; lm.lgm := msg.slgm; lm.id := get; lm.done := FALSE; msg.top.handle(msg.top, lm);
			IF lm.done THEN
				Leonardo.BeginCommand(msg.fig);
				GfxMatrix.Apply(msg.lgm, p.x, p.y, lm.x, lm.y);
				lm.id := set; lm.done := FALSE; msg.top.handle(msg.top, lm);
				Leonardo.EndCommand(msg.fig);
				IF lm.done THEN
					msg.top.slink := NIL; Leonardo.Transform(msg.fig, msg.top, GfxMatrix.Identity);
					NEW(act); act.do := DoLink; act.undo := UndoLink; act.p := p; act.link := msg.top;
					Leonardo.AddAction(msg.fig, act);
					msg.recv := p
				END
			END
		END
	END ConsumePoint;

	PROCEDURE RenderPoint* (p: Point; VAR msg: Leonardo.RenderMsg);
		VAR ctm: GfxMatrix.Matrix; x, y: FLOAT32; col: Gfx.Color;
	BEGIN
		ctm := msg.ctxt.ctm; Gfx.ResetCTM(msg.ctxt);
		GfxMatrix.Apply(ctm, p.x, p.y, x, y);
		GfxMatrix.Solve(ctm, ENTIER(x), ENTIER(y), x, y);	(* align to device pixel grid *)
		GfxMatrix.Apply(msg.lgm, x, y, x, y);
		GfxMatrix.Apply(msg.gsm, x, y, x, y);
		col := msg.ctxt.fillCol; Gfx.SetFillColor(msg.ctxt, Gfx.Black);
		IF p.link # NIL THEN
			Gfx.DrawImageAt(msg.ctxt, x-5, y-5, Img[3], GfxImages.NoFilter)
		END;
		Gfx.DrawImageAt(msg.ctxt, x-1, y-1, Img[0], GfxImages.NoFilter);
		IF p.sel THEN
			Gfx.DrawImageAt(msg.ctxt, x-3, y-3, Img[2], GfxImages.NoFilter);
			Gfx.SetFillColor(msg.ctxt, Gfx.LGrey);
			Gfx.DrawImageAt(msg.ctxt, x-2, y-2, Img[1], GfxImages.NoFilter)
		END;
		Gfx.SetFillColor(msg.ctxt, col);
		Gfx.SetCTM(msg.ctxt, ctm)
	END RenderPoint;

	PROCEDURE LocatePoint (p: Point; VAR msg: Leonardo.LocateMsg);
	BEGIN
		IF (msg.llx <= p.urx) & (p.llx <= msg.urx) & (msg.lly <= p.ury) & (p.lly <= msg.ury) THEN
			IF msg.id IN {Leonardo.inside, Leonardo.overlap} THEN p.slink := msg.res; msg.res := p
			ELSIF msg.id = Leonardo.project THEN GfxMatrix.Apply(msg.lgm, p.x, p.y, msg.px, msg.py); msg.res := p
			END
		END
	END LocatePoint;

	PROCEDURE TransformPoint (p: Point; VAR msg: Leonardo.TransformMsg);
		VAR x, y: FLOAT32; lm: LinkMsg;
	BEGIN
		IF msg.id = Leonardo.apply THEN
			IF ~p.marked THEN
				IF (p.link # NIL) & p.link.marked THEN
					msg.notify := TRUE
				END
			ELSIF msg.stamp # p.stamp THEN
				p.stamp := msg.stamp;
				GfxMatrix.Apply(msg.lgm, p.x, p.y, x, y);
				GfxMatrix.Apply(msg.mat, x, y, x, y);
				GfxMatrix.Solve(msg.lgm, x, y, x, y);
				Leonardo.SetReal(msg.fig, p, "X", x);
				Leonardo.SetReal(msg.fig, p, "Y", y);
				IF p.link # NIL THEN
					msg.notify := TRUE
				END
			END
		ELSIF (msg.id = Leonardo.notify) & (p.link # NIL) THEN
			IF p.marked & ~p.link.marked THEN
				lm.stamp := msg.stamp; lm.fig := msg.fig; lm.id := set; lm.done := FALSE;
				Leonardo.GetCoordSystem(p.link, lm.lgm);
				GfxMatrix.Apply(msg.lgm, p.x, p.y, lm.x, lm.y);
				p.link.handle(p.link, lm);
				IF lm.done THEN p.link.marked := TRUE; msg.notify := TRUE
				ELSE Unlink(msg.fig, p)
				END
			ELSIF ~p.marked & p.link.marked THEN
				lm.stamp := msg.stamp; lm.fig := msg.fig; lm.id := get; lm.done := FALSE;
				Leonardo.GetCoordSystem(p.link, lm.lgm);
				p.link.handle(p.link, lm);
				IF lm.done THEN
					GfxMatrix.Solve(msg.lgm, lm.x, lm.y, x, y);
					Leonardo.SetReal(msg.fig, p, "X", x);
					Leonardo.SetReal(msg.fig, p, "Y", y);
					p.marked := TRUE; msg.notify := TRUE
				ELSE
					Unlink(msg.fig, p)
				END
			END
		END
	END TransformPoint;

	PROCEDURE LinkPoint (p: Point; VAR msg: LinkMsg);
		VAR x, y: FLOAT32;
	BEGIN
		IF msg.id = get THEN
			GfxMatrix.Apply(msg.lgm, p.x, p.y, msg.x, msg.y);
			msg.done := TRUE
		ELSIF msg.id = set THEN
			GfxMatrix.Solve(msg.lgm, msg.x, msg.y, x, y);
			Leonardo.SetReal(msg.fig, p, "X", x);
			Leonardo.SetReal(msg.fig, p, "Y", y);
			msg.done := TRUE
		END
	END LinkPoint;

	PROCEDURE SplitPoint (p: Point; VAR msg: SplitMsg);
	BEGIN
		IF (p.link # NIL) & (p.llx <= msg.urx) & (msg.llx <= p.llx) & (p.lly <= msg.ury) & (msg.lly <= p.ury) THEN
			Unlink(msg.fig, p)
		END
	END SplitPoint;

	PROCEDURE GetPointItem* (p: Point; VAR s: ARRAY OF CHAR);
		VAR t: ARRAY 10 OF CHAR;
	BEGIN
		Strings.RealToFixStr(p.x, s, 8, 2, 0);
		Strings.RealToFixStr(p.y, t, 8, 2, 0);
		Strings.AppendCh(s, " "); Strings.Append(s, t)
	END GetPointItem;

	PROCEDURE CopyPoint* (VAR msg: Objects.CopyMsg; from, to: Point);
	BEGIN
		Leonardo.CopyShape(msg, from, to);
		to.x := from.x; to.y := from.y
	END CopyPoint;

	PROCEDURE HandlePoint* (obj: Objects.Object; VAR msg: Objects.ObjMsg);
		VAR p, copy: Point; ver, pos: SIGNED32; mode: SIGNED8;
	BEGIN
		p := obj(Point);
		IF msg IS Leonardo.ShapeMsg THEN
			IF msg IS Leonardo.ControlMsg THEN
				ControlPoint(p, msg(Leonardo.ControlMsg))
			ELSIF msg IS Leonardo.ValidateMsg THEN
				ValidatePoint(p, msg(Leonardo.ValidateMsg))
			ELSIF msg IS Leonardo.ConsumeMsg THEN
				ConsumePoint(p, msg(Leonardo.ConsumeMsg))
			ELSIF msg IS Leonardo.RenderMsg THEN
				RenderPoint(p, msg(Leonardo.RenderMsg))
			ELSIF msg IS Leonardo.LocateMsg THEN
				LocatePoint(p, msg(Leonardo.LocateMsg))
			ELSIF msg IS Leonardo.TransformMsg THEN
				TransformPoint(p, msg(Leonardo.TransformMsg))
			ELSIF msg IS LinkMsg THEN
				LinkPoint(p, msg(LinkMsg))
			ELSIF msg IS SplitMsg THEN
				SplitPoint(p, msg(SplitMsg))
			ELSE
				Leonardo.HandleShape(p, msg)
			END
		ELSIF msg IS Objects.AttrMsg THEN
			WITH msg: Objects.AttrMsg DO
				IF msg.id = Objects.enum THEN
					msg.Enum("X"); msg.Enum("Y"); Leonardo.HandleShape(p, msg)
				ELSIF msg.id = Objects.get THEN
					IF msg.name = "Gen" THEN msg.class := Objects.String; msg.s := "LeoPaths.NewPoint"; msg.res := 0
					ELSIF msg.name = "Item" THEN msg.class := Objects.String; GetPointItem(p, msg.s); msg.res := 0
					ELSIF msg.name = "X" THEN msg.class := Objects.Real; msg.x := p.x; msg.res := 0
					ELSIF msg.name = "Y" THEN msg.class := Objects.Real; msg.x := p.y; msg.res := 0
					ELSE Leonardo.HandleShape(p, msg)
					END
				ELSIF msg.id = Objects.set THEN
					IF msg.name = "X" THEN
						IF msg.class = Objects.Real THEN p.x := msg.x; msg.res := 0 END
					ELSIF msg.name = "Y" THEN
						IF msg.class = Objects.Real THEN p.y := msg.x; msg.res := 0 END
					ELSE
						Leonardo.HandleShape(p, msg)
					END
				END
			END
		ELSIF msg IS Objects.CopyMsg THEN
			WITH msg: Objects.CopyMsg DO
				IF msg.stamp # p.stamp THEN
					NEW(copy); p.dlink := copy; p.stamp := msg.stamp;
					CopyPoint(msg, p, copy)
				END;
				msg.obj := p.dlink
			END
		ELSIF msg IS Objects.BindMsg THEN
			IF p.link # NIL THEN
				p.link.handle(p.link, msg)
			END;
			Leonardo.HandleShape(p, msg)
		ELSIF msg IS Objects.FileMsg THEN
			WITH msg: Objects.FileMsg DO
				IF msg.id = Objects.store THEN
					Leonardo.HandleShape(p, msg);
					Files.WriteNum(msg.R, 3);
					Files.WriteReal(msg.R, p.x); Files.WriteReal(msg.R, p.y);
					Gadgets.WriteRef(msg.R, p.lib, p.link)
				ELSIF msg.id = Objects.load THEN
					pos := Files.Pos(msg.R);
					Files.ReadNum(msg.R, ver);
					IF ver = 1 THEN	(* old style point *)
						Files.ReadReal(msg.R, p.x); Files.ReadReal(msg.R, p.y)
					ELSE
						Files.Set(msg.R, Files.Base(msg.R), pos);	(* re-read version (belongs to shape) *)
						Leonardo.HandleShape(p, msg);
						Files.ReadNum(msg.R, ver);
						Files.ReadReal(msg.R, p.x); Files.ReadReal(msg.R, p.y);
						IF ver = 2 THEN
							Files.Read(msg.R, mode)
						ELSE
							Gadgets.ReadRef(msg.R, p.lib, obj);
							IF (obj # NIL) & (obj IS Leonardo.Shape) THEN
								p.link := obj(Leonardo.Shape)
							END
						END
					END;
					p.llx := p.x-0.5; p.lly := p.y-0.5; p.urx := p.x+0.5; p.ury := p.y+0.5
				END
			END
		ELSE
			Leonardo.HandleShape(p, msg)
		END
	END HandlePoint;

	PROCEDURE InitPoint* (p: Point; x, y: FLOAT32);
	BEGIN
		Leonardo.InitShape(p, HandlePoint);
		p.x := x; p.y := y;
		p.llx := x-0.5; p.lly := y-0.5; p.urx := x+0.5; p.ury := y+0.5; p.bw := 0
	END InitPoint;

	PROCEDURE NewPoint*;
		VAR p: Point;
	BEGIN
		NEW(p); InitPoint(p, 0, 0);
		Objects.NewObj := p
	END NewPoint;


	(**--- Paths ---**)

	PROCEDURE CalcPathBox (path: Path; VAR mat: GfxMatrix.Matrix);
		VAR bw: FLOAT32;
	BEGIN
		Leonardo.GetComponentsBox(path.bottom, path.llx, path.lly, path.urx, path.ury, path.bw);
		Attributes.GetReal(path.pen, "Border", bw);
		GfxMatrix.ApplyToDist(mat, bw, bw);
		IF bw > path.bw THEN path.bw := bw END
	END CalcPathBox;

	PROCEDURE SelectPath* (path: Path; VAR msg: Leonardo.SelectMsg);
		VAR cur: Leonardo.Shape;
	BEGIN
		IF msg.id = Leonardo.validate THEN
			Leonardo.ToComponents(path.bottom, msg);
			cur := path.bottom; WHILE (cur # NIL) & ~cur.sel DO cur := cur.up END;
			path.subsel := cur # NIL;
			IF path.subsel & ~path.sel THEN
				path.sel := TRUE;
				Leonardo.UpdateShape(msg.fig, path)
			END
		ELSE
			IF (msg.id = Leonardo.reset) & path.sel THEN
				Leonardo.UpdateShape(msg.fig, path)
			END;
			Leonardo.SelectContainer(path, msg)
		END
	END SelectPath;

	PROCEDURE ControlPath* (path: Path; VAR msg: Leonardo.ControlMsg);
		VAR s, bot, top: Leonardo.Shape; copy: Path;
	BEGIN
		IF msg.id = Leonardo.delete THEN
			Leonardo.ControlContainer(path, msg);
			s := path.bottom; WHILE (s # NIL) & s.marked DO s := s.up END;
			IF s = NIL THEN	(* all components deleted *)
				path.marked := TRUE
			END
		ELSIF (msg.id = Leonardo.clone) & ~path.marked THEN
			bot := msg.bottom; top := msg.top; msg.bottom := NIL; msg.top := NIL;
			Leonardo.ControlContainer(path, msg);
			IF msg.top # NIL THEN
				NEW(copy); Leonardo.InitContainer(copy, path.handle, msg.bottom, msg.top); copy.pen := path.pen;
				copy.llx := path.llx; copy.lly := path.lly; copy.urx := path.urx; copy.ury := path.ury; copy.bw := path.bw;
				msg.top := copy; copy.down := top;
				IF top = NIL THEN msg.bottom := copy
				ELSE msg.bottom := bot; top.up := copy
				END
			ELSE
				msg.bottom := bot; msg.top := top
			END
		ELSE
			Leonardo.ControlContainer(path, msg)
		END
	END ControlPath;

	PROCEDURE ValidatePath (path: Path; VAR msg: Leonardo.ValidateMsg);
	BEGIN
		Leonardo.ToComponents(path.bottom, msg);
		IF path.marked THEN
			Leonardo.UpdateShape(msg.fig, path);
			CalcPathBox(path, msg.lgm);
			Leonardo.UpdateShape(msg.fig, path);
			path.marked := FALSE; path.cont.marked := TRUE
		END
	END ValidatePath;

	PROCEDURE ConsumePath (path: Path; VAR msg: Leonardo.ConsumeMsg);
		VAR cm: ContourMsg; s: Leonardo.Shape; dm: Leonardo.ControlMsg;
	BEGIN
		IF (msg.recv = NIL) & (msg.llx <= path.urx + path.bw) & (path.llx - path.bw <= msg.urx) &
			(msg.lly <= path.ury + path.bw) & (path.lly - path.bw <= msg.ury)
		THEN
			cm.fig := msg.fig; s := msg.bottom;
			REPEAT
				cm.done := FALSE; s.handle(s, cm); s := s.up
			UNTIL ~cm.done OR (s = msg.top.up);
			IF cm.done THEN
				s := msg.bottom; WHILE s # msg.top.up DO s.marked := TRUE; s := s.up END;
				dm.id := Leonardo.delete; msg.fig.handle(msg.fig, dm);
				Leonardo.AddConsumeAction(msg.fig, path.top, msg.bottom, msg.top, NIL, path);
				msg.recv := path
			ELSE
				Leonardo.ToComponents(path.bottom, msg)
			END
		END
	END ConsumePath;

	PROCEDURE RenderPath (path: Path; VAR msg: Leonardo.RenderMsg);
		VAR state: Gfx.State; rm: RenderMsg; id: SIGNED16;

		PROCEDURE corner (x, y: FLOAT32);
		BEGIN
			GfxMatrix.Apply(msg.gsm, x, y, x, y);
			x := ENTIER(x); y := ENTIER(y);
			Gfx.DrawRect(msg.ctxt, x-7, y, x+8, y+1, {Gfx.Fill});
			Gfx.DrawRect(msg.ctxt, x, y-7, x+1, y+8, {Gfx.Fill})
		END corner;

	BEGIN
		IF (path.llx - path.bw < msg.urx) & (msg.llx < path.urx + path.bw) &
			(path.lly - path.bw < msg.ury) & (msg.lly < path.ury + path.bw)
		THEN
			IF msg.id = Leonardo.marked THEN
				Leonardo.ToComponents(path.bottom, msg)
			ELSE
				IF msg.id IN {Leonardo.active, Leonardo.passive} THEN
					Gfx.Save(msg.ctxt, Gfx.attr, state);
					path.pen.do.begin(path.pen, msg.ctxt);
					rm.stamp := msg.stamp; rm.dlink := msg.dlink; rm.fig := msg.fig; rm.pen := path.pen;
					Leonardo.ToComponents(path.bottom, rm);
					path.pen.do.end(path.pen);
					Gfx.Restore(msg.ctxt, state)
				END;
				IF path.sel THEN
					IF msg.id IN {Leonardo.active, Leonardo.marksonly} THEN
						id := msg.id; msg.id := Leonardo.marksonly;
						Leonardo.ToComponents(path.bottom, msg);
						msg.id := id
					END;
					IF msg.id = Leonardo.active THEN
						Gfx.Save(msg.ctxt, {Gfx.fillColPat, Gfx.ctm}, state);
						Gfx.SetFillColor(msg.ctxt, Gfx.DGrey); Gfx.SetFillPattern(msg.ctxt, NIL);
						Gfx.ResetCTM(msg.ctxt);
						corner(path.llx, path.lly); corner(path.urx, path.lly);
						corner(path.urx, path.ury); corner(path.llx, path.ury);
						Gfx.Restore(msg.ctxt, state)
					END
				END
			END
		END
	END RenderPath;

	PROCEDURE GetPathMatrix* (path: Path; VAR msg: Leonardo.MatrixMsg);
		VAR lgm: GfxMatrix.Matrix;
	BEGIN
		IF msg.dest = path THEN
			lgm := msg.lgm; msg.lgm := GfxMatrix.Identity;
			Leonardo.GetHandleMatrix(path.llx, path.lly, path.urx, path.ury, msg);
			msg.lgm := lgm
		ELSE
			Leonardo.GetContainerMatrix(path, msg)
		END
	END GetPathMatrix;

	PROCEDURE CopyPath* (VAR msg: Objects.CopyMsg; from, to: Path);
		VAR obj: Objects.Object;
	BEGIN
		Leonardo.CopyContainer(msg, from, to);
		obj := Gadgets.CopyPtr(msg, from.pen);
		IF (obj # NIL) & (obj IS LeoPens.Pen) THEN
			to.pen := obj(LeoPens.Pen)
		END
	END CopyPath;

	PROCEDURE HandlePath* (obj: Objects.Object; VAR msg: Objects.ObjMsg);
		VAR path, copy: Path; ver: SIGNED32;
	BEGIN
		path := obj(Path);
		IF msg IS Leonardo.ShapeMsg THEN
			IF msg IS Leonardo.SelectMsg THEN
				SelectPath(path, msg(Leonardo.SelectMsg))
			ELSIF msg IS Leonardo.ControlMsg THEN
				ControlPath(path, msg(Leonardo.ControlMsg))
			ELSIF msg IS Leonardo.ValidateMsg THEN
				ValidatePath(path, msg(Leonardo.ValidateMsg))
			ELSIF msg IS Leonardo.ConsumeMsg THEN
				ConsumePath(path, msg(Leonardo.ConsumeMsg))
			ELSIF msg IS Leonardo.RenderMsg THEN
				RenderPath(path, msg(Leonardo.RenderMsg))
			ELSIF msg IS Leonardo.MatrixMsg THEN
				GetPathMatrix(path, msg(Leonardo.MatrixMsg))
			ELSE
				Leonardo.HandleContainer(path, msg)
			END
		ELSIF msg IS LeoPens.UpdateMsg THEN
			WITH msg: LeoPens.UpdateMsg DO
				IF msg.pen = path.pen THEN path.marked := TRUE; path.sel := TRUE
				ELSE path.pen.handle(path.pen, msg)
				END
			END
		ELSIF msg IS Objects.AttrMsg THEN
			WITH msg: Objects.AttrMsg DO
				IF msg.id = Objects.enum THEN
					Leonardo.HandleContainer(path, msg)
				ELSIF msg.id = Objects.get THEN
					IF msg.name = "Gen" THEN msg.class := Objects.String; msg.s := "LeoPaths.New"; msg.res := 0
					ELSIF msg.name = "Item" THEN msg.class := Objects.String; msg.s := "Path"; msg.res := 0
					ELSE Leonardo.HandleContainer(path, msg)
					END
				ELSIF msg.id = Objects.set THEN
					Leonardo.HandleContainer(path, msg)
				END
			END
		ELSIF msg IS Objects.LinkMsg THEN
			WITH msg: Objects.LinkMsg DO
				IF msg.id = Objects.enum THEN
					msg.Enum("Pen"); Leonardo.HandleContainer(path, msg)
				ELSIF msg.id = Objects.get THEN
					IF msg.name = "Pen" THEN msg.obj := path.pen; msg.res := 0
					ELSE Leonardo.HandleContainer(path, msg)
					END
				ELSIF msg.id = Objects.set THEN
					IF msg.name = "Pen" THEN
						IF (msg.obj # NIL) & (msg.obj IS LeoPens.Pen) THEN path.pen := msg.obj(LeoPens.Pen); msg.res := 0 END
					ELSE
						Leonardo.HandleContainer(path, msg)
					END
				END
			END
		ELSIF msg IS Objects.CopyMsg THEN
			WITH msg: Objects.CopyMsg DO
				IF msg.stamp # path.stamp THEN
					NEW(copy); path.dlink := copy; path.stamp := msg.stamp;
					CopyPath(msg, path, copy)
				END;
				msg.obj := path.dlink
			END
		ELSIF msg IS Objects.BindMsg THEN
			path.pen.handle(path.pen, msg);
			Leonardo.HandleContainer(path, msg)
		ELSIF msg IS Objects.FileMsg THEN
			WITH msg: Objects.FileMsg DO
				Leonardo.HandleContainer(path, msg);
				IF msg.id = Objects.store THEN
					Files.WriteNum(msg.R, 1);
					Gadgets.WriteRef(msg.R, path.lib, path.pen)
				ELSIF msg.id = Objects.load THEN
					Files.ReadNum(msg.R, ver);
					Gadgets.ReadRef(msg.R, path.lib, obj);
					IF (obj # NIL) & (obj IS LeoPens.Pen) THEN
						path.pen := obj(LeoPens.Pen)
					END;
					CalcPathBox(path, GfxMatrix.Identity)
				END
			END
		ELSE
			Leonardo.HandleContainer(path, msg)
		END
	END HandlePath;

	PROCEDURE InitPath* (path: Path; bottom, top: Leonardo.Shape; pen: LeoPens.Pen);
	BEGIN
		Leonardo.InitContainer(path, HandlePath, bottom, top);
		path.pen := pen;
		CalcPathBox(path, GfxMatrix.Identity)
	END InitPath;

	PROCEDURE New*;
		VAR path: Path;
	BEGIN
		NEW(path); InitPath(path, NIL, NIL, LeoPens.Default);
		Objects.NewObj := path
	END New;


	(**--- Segments ---**)

	PROCEDURE GetFirstLast* (seg: Segment; VAR first, last: Point);
	BEGIN
		first := seg.bottom(Point); last := seg.top(Point);
		IF seg.closed THEN
			first.down := last; last.up := first;
			last := first
		END
	END GetFirstLast;

	PROCEDURE Pred* (seg: Segment): Leonardo.Shape;
		VAR cm: ConnectMsg; pred: Leonardo.Shape;
	BEGIN
		IF seg.pred = term THEN RETURN NIL
		ELSIF seg.pred < wrap THEN RETURN seg.down
		ELSE
			cm.id := get; cm.pos := end; pred := seg;
			LOOP
				cm.done := FALSE; pred.handle(pred, cm);
				IF ~cm.done THEN RETURN NIL
				ELSIF cm.mode >= wrap THEN RETURN pred
				ELSE pred := pred.up
				END
			END
		END
	END Pred;

	PROCEDURE Succ* (seg: Segment): Leonardo.Shape;
		VAR cm: ConnectMsg; succ: Leonardo.Shape;
	BEGIN
		IF seg.succ = term THEN RETURN NIL
		ELSIF seg.succ < wrap THEN RETURN seg.up
		ELSE
			cm.id := get; cm.pos := start; succ := seg;
			LOOP
				cm.done := FALSE; succ.handle(succ, cm);
				IF ~cm.done THEN RETURN NIL
				ELSIF cm.mode >= wrap THEN RETURN succ
				ELSE succ := succ.down
				END
			END
		END
	END Succ;

	PROCEDURE GetPred* (seg: Segment; VAR dx, dy: FLOAT32);
		VAR pred: Leonardo.Shape; cm: ConnectMsg;
	BEGIN
		pred := Pred(seg); dx := 0; dy := 0;
		IF pred # NIL THEN
			cm.id := get; cm.pos := end; cm.done := FALSE; pred.handle(pred, cm);
			IF cm.done THEN
				dx := cm.dx; dy := cm.dy
			END
		END
	END GetPred;

	PROCEDURE GetSucc* (seg: Segment; VAR dx, dy: FLOAT32);
		VAR succ: Leonardo.Shape; cm: ConnectMsg;
	BEGIN
		succ := Succ(seg); dx := 0; dy := 0;
		IF succ # NIL THEN
			cm.id := get; cm.pos := start; cm.done := FALSE; succ.handle(succ, cm);
			IF cm.done THEN
				dx := cm.dx; dy := cm.dy
			END
		END
	END GetSucc;

	PROCEDURE SwapPred (fig: Leonardo.Figure; a: Leonardo.Action);
		VAR act: ModeAction; seg: Segment; mode: SIGNED8;
	BEGIN
		act := a(ModeAction); seg := act.seg;
		mode := seg.pred; seg.pred := act.mode; act.mode := mode;
		seg.marked := TRUE; seg.sel := TRUE
	END SwapPred;

	PROCEDURE ChangePred* (fig: Leonardo.Figure; seg: Segment; mode: SIGNED8);
		VAR act: ModeAction;
	BEGIN
		NEW(act); act.do := SwapPred; act.undo := SwapPred; act.seg := seg; act.mode := mode;
		Leonardo.AddAction(fig, act)
	END ChangePred;

	PROCEDURE SwapSucc (fig: Leonardo.Figure; a: Leonardo.Action);
		VAR act: ModeAction; seg: Segment; mode: SIGNED8;
	BEGIN
		act := a(ModeAction); seg := act.seg;
		mode := seg.succ; seg.succ := act.mode; act.mode := mode;
		seg.marked := TRUE; seg.sel := TRUE
	END SwapSucc;

	PROCEDURE ChangeSucc* (fig: Leonardo.Figure; seg: Segment; mode: SIGNED8);
		VAR act: ModeAction;
	BEGIN
		NEW(act); act.do := SwapSucc; act.undo := SwapSucc; act.seg := seg; act.mode := mode;
		Leonardo.AddAction(fig, act)
	END ChangeSucc;

	PROCEDURE ConnectPred* (fig: Leonardo.Figure; seg: Segment; pred: Leonardo.Shape);
		VAR cm: ConnectMsg; p: Point;
	BEGIN
		IF pred # NIL THEN
			cm.fig := fig; cm.id := get; cm.pos := start; cm.done := FALSE; seg.handle(seg, cm);
			IF cm.done THEN
				p := seg.bottom(Point);
				cm.id := set; cm.pos := end; cm.mode := coincident; cm.x := p.x; cm.y := p.y; cm.done := FALSE;
				IF pred # seg.down THEN INC(cm.mode, wrap) END;
				pred.handle(pred, cm);
				IF cm.done THEN
					ChangePred(fig, seg, cm.mode)
				END
			END
		END
	END ConnectPred;

	PROCEDURE ConnectSucc* (fig: Leonardo.Figure; seg: Segment; succ: Leonardo.Shape);
		VAR cm: ConnectMsg; p: Point;
	BEGIN
		IF succ # NIL THEN
			cm.fig := fig; cm.id := get; cm.pos := end; cm.done := FALSE; seg.handle(seg, cm);
			IF cm.done THEN
				p := seg.top(Point);
				cm.id := set; cm.pos := start; cm.mode := coincident; cm.x := p.x; cm.y := p.y; cm.done := FALSE;
				IF succ # seg.up THEN INC(cm.mode, wrap) END;
				succ.handle(succ, cm);
				IF cm.done THEN
					ChangeSucc(fig, seg, cm.mode)
				END
			END
		END
	END ConnectSucc;

	PROCEDURE ControlSegment* (seg: Segment; VAR msg: Leonardo.ControlMsg);
		VAR p: Leonardo.Shape; n: SIGNED32; pred, succ, bot, top: Leonardo.Shape; cm: ConnectMsg; copy: Segment;
	BEGIN
		IF msg.id = Leonardo.delete THEN
			Leonardo.ControlContainer(seg, msg);
			p := seg.bottom; n := 0;
			WHILE p # NIL DO
				IF ~p.marked THEN INC(n) END;
				p := p.up
			END;
			IF n < 2 THEN	(* segment collapses *)
				seg.marked := TRUE
			END;
			pred := Pred(seg); succ := Succ(seg);
			IF (pred # NIL) & ~pred.marked & (seg.marked OR seg.bottom.marked) THEN
				cm.fig := msg.fig; cm.id := set; cm.pos := end; cm.mode := term; cm.done := FALSE; pred.handle(pred, cm);
				ChangePred(msg.fig, seg, term)
			END;
			IF (succ # NIL) & ~succ.marked & (seg.marked OR seg.top.marked) THEN
				cm.fig := msg.fig; cm.id := set; cm.pos := start; cm.mode := term; cm.done := FALSE; succ.handle(succ, cm);
				ChangeSucc(msg.fig, seg, term)
			END
		ELSIF msg.id = Leonardo.clone THEN
			IF seg.marked THEN
				Leonardo.ControlContainer(seg, msg);
				pred := Pred(seg); succ := Succ(seg); copy := seg.dlink(Segment);
				IF (pred # NIL) & pred.marked THEN copy.pred := seg.pred; copy.boff := seg.boff; copy.eoff := seg.eoff
				ELSE copy.pred := term
				END;
				IF (succ # NIL) & succ.marked THEN copy.succ := seg.succ; copy.boff := seg.boff; copy.eoff := seg.eoff
				ELSE copy.succ := term
				END
			ELSE
				bot := msg.bottom; top := msg.top; msg.bottom := NIL; msg.top := NIL;
				Leonardo.ControlContainer(seg, msg);
				IF msg.top # NIL THEN
					NEW(copy); Leonardo.InitContainer(copy, seg.handle, msg.bottom, msg.top);
					copy.llx := seg.llx; copy.lly := seg.lly; copy.urx := seg.urx; copy.ury := seg.ury; copy.bw := seg.bw;
					copy.pen := seg.pen; copy.closed := seg.closed; copy.len := seg.len;
					msg.top := copy; copy.down := top;
					IF top = NIL THEN msg.bottom := copy
					ELSE msg.bottom := bot; top.up := copy
					END
				ELSE
					msg.bottom := bot; msg.top := top
				END
			END
		ELSE
			Leonardo.ControlContainer(seg, msg)
		END
	END ControlSegment;

	PROCEDURE OrderSegment* (seg: Segment; VAR msg: Leonardo.OrderMsg);
		VAR pred, succ: Leonardo.Shape; cm: ConnectMsg;
	BEGIN
		Leonardo.HandleContainer(seg, msg);
		pred := Pred(seg); succ := Succ(seg);
		IF (pred # NIL) & ~pred.marked & (seg.marked OR seg.bottom.marked) THEN
			cm.fig := msg.fig; cm.id := set; cm.pos := end; cm.mode := term; cm.done := FALSE; pred.handle(pred, cm);
			ChangePred(msg.fig, seg, term)
		END;
		IF (succ # NIL) & ~succ.marked & (seg.marked OR seg.top.marked) THEN
			cm.fig := msg.fig; cm.id := set; cm.pos := start; cm.mode := term; cm.done := FALSE; succ.handle(succ, cm);
			ChangeSucc(msg.fig, seg, term)
		END
	END OrderSegment;

	PROCEDURE CalcSegmentBox* (seg: Segment; VAR mat: GfxMatrix.Matrix);
		VAR bw: FLOAT32;
	BEGIN
		Leonardo.GetComponentsBox(seg.bottom, seg.llx, seg.lly, seg.urx, seg.ury, seg.bw);
		Attributes.GetReal(seg.pen, "Border", bw);
		GfxMatrix.ApplyToDist(mat, bw, bw);
		IF bw > seg.bw THEN seg.bw := bw END
	END CalcSegmentBox;

	PROCEDURE ValidateSegmentLength* (seg: Segment; VAR msg: Leonardo.ValidateMsg);
		VAR rm: RenderMsg; len: FLOAT32; vm: ValidateMsg;
	BEGIN
		Rec.do.begin(Rec, NIL);
		rm.stamp := msg.stamp; rm.fig := msg.fig; rm.pen := Rec; seg.handle(seg, rm);
		Rec.do.end(Rec);
		len := GfxPaths.Length(Rec.path, 0.5);
		IF len # seg.len THEN
			seg.len := len;
			IF (seg.pred # term) & (seg.pred < wrap) THEN
				vm.fig := msg.fig; vm.pos := end; vm.off := seg.eoff + len; seg.down.handle(seg.down, vm)
			END;
			IF (seg.succ # term) & (seg.succ < wrap) THEN
				vm.fig := msg.fig; vm.pos := start; vm.off := seg.boff + len; seg.up.handle(seg.up, vm)
			END
		END
	END ValidateSegmentLength;

	PROCEDURE ValidateSegment* (seg: Segment; VAR msg: Leonardo.ValidateMsg);
	BEGIN
		Leonardo.ToComponents(seg.bottom, msg);
		IF seg.marked THEN
			Leonardo.UpdateShape(msg.fig, seg);
			CalcSegmentBox(seg, msg.lgm);
			Leonardo.UpdateShape(msg.fig, seg);
			ValidateSegmentLength(seg, msg);
			seg.marked := FALSE; seg.cont.marked := TRUE
		END
	END ValidateSegment;

	PROCEDURE ConsumeSegment* (seg: Segment; VAR msg: Leonardo.ConsumeMsg);
		VAR t, b, succ, pred: Leonardo.Shape; cm: ConnectMsg; x, y: FLOAT32;
	BEGIN
		IF (msg.recv = NIL) & (msg.top.cont # seg) & (msg.llx <= seg.urx + seg.bw) & (seg.llx - seg.bw <= msg.urx) &
			(msg.lly <= seg.ury + seg.bw) & (seg.lly - seg.bw <= msg.ury)
		THEN
			t := seg.top; b := seg.bottom;
			IF (seg.succ = term) & (msg.llx <= t.urx) & (t.llx <= msg.urx) & (msg.lly <= t.ury) & (t.lly <= msg.ury) THEN
				succ := msg.bottom; WHILE (succ.cont # NIL) & (succ.cont # seg.cont) DO succ := succ.cont END;
				IF succ.cont = seg.cont THEN
					IF (succ # seg.up) & (seg.pred # term) THEN
						cm.fig := msg.fig; cm.id := get; cm.pos := start; pred := seg;
						REPEAT
							pred := pred.down; cm.done := FALSE; pred.handle(pred, cm)
						UNTIL ~cm.done OR (cm.mode = term) OR (pred.down = NIL);
						IF ~cm.done OR (cm.mode # term) THEN pred := NIL END
					ELSE pred := NIL
					END;
					IF (succ = seg.up) OR (succ = pred) THEN
						cm.fig := msg.fig; cm.id := get; cm.pos := start; cm.done := FALSE; succ.handle(succ, cm);
						IF cm.done THEN
							GfxMatrix.Apply(msg.lgm, cm.x, cm.y, x, y);
							IF (msg.llx <= x) & (x <= msg.urx) & (msg.lly <= y) & (y <= msg.ury) THEN
								ConnectSucc(msg.fig, seg, succ);
								msg.recv := seg
							END
						END
					END
				END;
				IF msg.recv = NIL THEN
					Leonardo.ToComponents(seg.bottom, msg)
				END
			ELSIF (seg.pred = term) & (msg.llx <= b.urx) & (b.llx <= msg.urx) & (msg.lly <= b.ury) & (b.lly <= msg.ury) THEN
				pred := msg.bottom; WHILE (pred.cont # NIL) & (pred.cont # seg.cont) DO pred := pred.cont END;
				IF pred.cont = seg.cont THEN
					IF (pred # seg.down) & (seg.succ # term) THEN
						cm.fig := msg.fig; cm.id := get; cm.pos := end; succ := seg;
						REPEAT
							succ := succ.up; cm.done := FALSE; succ.handle(succ, cm)
						UNTIL ~cm.done OR (cm.mode = term) OR (succ.up = NIL);
						IF ~cm.done OR (cm.mode # term) THEN succ := NIL END
					ELSE succ := NIL
					END;
					IF (pred = seg.down) OR (pred = succ) THEN
						cm.fig := msg.fig; cm.id := get; cm.pos := end; cm.done := FALSE; pred.handle(pred, cm);
						IF cm.done THEN
							GfxMatrix.Apply(msg.lgm, cm.x, cm.y, x, y);
							IF (msg.llx <= x) & (x <= msg.urx) & (msg.lly <= y) & (y <= msg.ury) THEN
								ConnectPred(msg.fig, seg, pred);
								msg.recv := seg
							END
						END
					END
				END;
				IF msg.recv = NIL THEN
					Leonardo.ToComponents(seg.bottom, msg)
				END
			ELSE
				Leonardo.ToComponents(seg.bottom, msg)
			END
		END
	END ConsumeSegment;

	PROCEDURE ConsumePoints* (seg: Segment; VAR msg: Leonardo.ConsumeMsg);
		VAR b, t: Point;
	BEGIN
		IF (msg.recv = NIL) & (msg.top.cont = seg) & (msg.top.slink = NIL) & ~seg.closed THEN
			b := seg.bottom(Point); t := seg.top(Point);
			IF (msg.top = t) & (msg.llx <= b.x) & (b.x <= msg.urx) & (msg.lly <= b.y) & (b.y <= msg.ury) THEN
				Leonardo.AddDeleteAction(msg.fig, t.down, t, t, NIL, seg);
				Leonardo.SetBool(msg.fig, seg, "Closed", TRUE);
				msg.recv := seg
			ELSIF (msg.top = b) & (msg.llx <= t.x) & (t.x <= msg.urx) & (msg.lly <= t.y) & (t.y <= msg.ury) THEN
				Leonardo.SetReal(msg.fig, b, "X", t.x);
				Leonardo.SetReal(msg.fig, b, "Y", t.y);
				Leonardo.AddDeleteAction(msg.fig, t.down, t, t, NIL, seg);
				Leonardo.SetBool(msg.fig, seg, "Closed", TRUE);
				msg.recv := seg
			END
		ELSE
			ConsumeSegment(seg, msg)
		END
	END ConsumePoints;

	PROCEDURE RenderSegment* (seg: Segment; VAR msg: Leonardo.RenderMsg);
		VAR
			state: Gfx.State; cm: ConnectMsg; x, y, dx, dy, d: FLOAT32;

		PROCEDURE coinc (x, y, dx, dy: FLOAT32);
			VAR x0, y0, x1, y1, x2, y2, x3, y3: FLOAT32;
		BEGIN
			x0 := x + 4*dx; y0 := y + 4*dy; x1 := x + 12*dx; y1 := y + 12*dy;
			x2 := x1 - 4*dy; y2 := y1 + 4*dx; x3 := x1 + 4*dy; y3 := y1 - 4*dx;
			Gfx.Begin(msg.ctxt, {Gfx.Fill});
			Gfx.MoveTo(msg.ctxt, x2, y2); Gfx.LineTo(msg.ctxt, x0, y0); Gfx.LineTo(msg.ctxt, x3, y3); Gfx.Close(msg.ctxt);
			Gfx.End(msg.ctxt);
			Gfx.Begin(msg.ctxt, {Gfx.Stroke});
			Gfx.MoveTo(msg.ctxt, x2, y2); Gfx.LineTo(msg.ctxt, x0, y0); Gfx.LineTo(msg.ctxt, x3, y3); Gfx.Close(msg.ctxt);
			Gfx.End(msg.ctxt)
		END coinc;

		PROCEDURE coll (x, y, dx, dy: FLOAT32);
			VAR x0, y0, x1, y1, x2, y2, x3, y3: FLOAT32;
		BEGIN
			x0 := x + 4*dx; y0 := y + 4*dy; x1 := x + 12*dx; y1 := y + 12*dy;
			x2 := x0 - 4*dy; y2 := y0 + 4*dx; x3 := x0 + 4*dy; y3 := y0 - 4*dx;
			Gfx.Begin(msg.ctxt, {Gfx.Fill});
			Gfx.MoveTo(msg.ctxt, x2, y2); Gfx.LineTo(msg.ctxt, x1, y1); Gfx.LineTo(msg.ctxt, x3, y3); Gfx.Close(msg.ctxt);
			Gfx.End(msg.ctxt);
			Gfx.Begin(msg.ctxt, {Gfx.Stroke});
			Gfx.MoveTo(msg.ctxt, x2, y2); Gfx.LineTo(msg.ctxt, x1, y1); Gfx.LineTo(msg.ctxt, x3, y3); Gfx.Close(msg.ctxt);
			Gfx.End(msg.ctxt)
		END coll;

		PROCEDURE symm (x, y, dx, dy: FLOAT32);
			VAR x0, y0, x1, y1, x2, y2, x3, y3: FLOAT32;
		BEGIN
			x0 := x + 4*dx; y0 := y + 4*dy; x1 := x + 8*dx; y1 := y + 8*dy;
			x2 := x1 - 3*dy; y2 := y1 + 3*dx; x3 := x1 + 3*dy; y3 := y1 - 3*dx;
			x1 := x + 12*dx; y1 := y + 12*dy;
			Gfx.Begin(msg.ctxt, {Gfx.Fill});
			Gfx.MoveTo(msg.ctxt, x2, y2); Gfx.LineTo(msg.ctxt, x1, y1);
			Gfx.LineTo(msg.ctxt, x3, y3); Gfx.LineTo(msg.ctxt, x0, y0); Gfx.Close(msg.ctxt);
			Gfx.End(msg.ctxt);
			Gfx.Begin(msg.ctxt, {Gfx.Stroke});
			Gfx.MoveTo(msg.ctxt, x2, y2); Gfx.LineTo(msg.ctxt, x1, y1);
			Gfx.LineTo(msg.ctxt, x3, y3); Gfx.LineTo(msg.ctxt, x0, y0); Gfx.Close(msg.ctxt);
			Gfx.End(msg.ctxt);
		END symm;

	BEGIN
		IF seg.sel & (msg.id IN {Leonardo.active, Leonardo.marksonly}) THEN
			IF (seg.pred # term) OR (seg.succ # term) THEN
				Gfx.Save(msg.ctxt, {Gfx.strokeColPat, Gfx.fillColPat, Gfx.ctm}, state);
				Gfx.SetStrokeColor(msg.ctxt, Gfx.DGrey);
				Gfx.SetFillColor(msg.ctxt, Gfx.LGrey);
				IF seg.pred # term THEN
					cm.id := get; cm.pos := start; cm.done := FALSE; seg.handle(seg, cm);
					IF cm.done THEN
						GfxMatrix.Apply(msg.lgm, cm.x, cm.y, x, y);
						GfxMatrix.Apply(msg.gsm, x, y, x, y);
						GfxMatrix.ApplyToVector(msg.lgm, cm.dx, cm.dy, dx, dy);
						GfxMatrix.ApplyToVector(msg.gsm, dx, dy, dx, dy);
						Gfx.ResetCTM(msg.ctxt);
						d := 1/Math.sqrt(dx * dx + dy * dy + 0.1);
						dx := d * dx; dy := d * dy;
						IF cm.mode MOD wrap = coincident THEN coinc(x, y, dx, dy)
						ELSIF cm.mode MOD wrap = collinear THEN coll(x, y, dx, dy)
						ELSIF cm.mode MOD wrap = symmetric THEN symm(x, y, dx, dy)
						END
					END
				END;
				IF seg.succ # term THEN
					cm.id := get; cm.pos := end; cm.done := FALSE; seg.handle(seg, cm);
					IF cm.done THEN
						GfxMatrix.Apply(msg.lgm, cm.x, cm.y, x, y);
						GfxMatrix.Apply(msg.gsm, x, y, x, y);
						GfxMatrix.ApplyToVector(msg.lgm, -cm.dx, -cm.dy, dx, dy);
						GfxMatrix.ApplyToVector(msg.gsm, dx, dy, dx, dy);
						Gfx.ResetCTM(msg.ctxt);
						d := 1/Math.sqrt(dx * dx + dy * dy + 0.1);
						dx := d * dx; dy := d * dy;
						IF cm.mode MOD wrap = coincident THEN coinc(x, y, dx, dy)
						ELSIF cm.mode MOD wrap = collinear THEN coll(x, y, dx, dy)
						ELSIF cm.mode MOD wrap = symmetric THEN symm(x, y, dx, dy)
						END
					END
				END;
				Gfx.Restore(msg.ctxt, state)
			END;
			Leonardo.ToComponents(seg.bottom, msg)
		END
	END RenderSegment;

	PROCEDURE TransformSegment* (seg: Segment; VAR msg: Leonardo.TransformMsg);
		VAR first, last: Point; pred, succ: Leonardo.Shape; cm: ConnectMsg;
	BEGIN
		Leonardo.TransformContainer(seg, msg);
		IF (msg.id = Leonardo.apply) & ((seg.pred # term) OR (seg.succ # term)) THEN
			GetFirstLast(seg, first, last);
			LOOP
				IF first.marked THEN msg.notify := TRUE END;
				IF first = last THEN EXIT END;
				first := first.up(Point)
			END;
			seg.bottom.down := NIL; seg.top.up := NIL
		ELSIF (msg.id = Leonardo.notify) & (msg.stamp # seg.stamp) THEN
			pred := Pred(seg);
			IF (pred # NIL) & (seg.bottom.marked OR (seg.pred MOD wrap # coincident) & seg.bottom.up.marked) THEN
				cm.stamp := msg.stamp; cm.fig := msg.fig; cm.id := get; cm.pos := start; cm.done := FALSE; seg.handle(seg, cm);
				IF cm.done THEN
					cm.id := notify; cm.pos := end; cm.done := FALSE; pred.handle(pred, cm);
					IF cm.done THEN
						IF cm.mode # seg.pred THEN ChangePred(msg.fig, seg, cm.mode)
						ELSE msg.notify := TRUE
						END
					END
				END
			END;
			succ := Succ(seg);
			IF (succ # NIL) & (seg.top.marked OR (seg.succ MOD wrap # coincident) & seg.top.down.marked) THEN
				cm.stamp := msg.stamp; cm.fig := msg.fig; cm.id := get; cm.pos := end; cm.done := FALSE; seg.handle(seg, cm);
				IF cm.done THEN
					cm.id := notify; cm.pos := start; cm.done := FALSE; succ.handle(succ, cm);
					IF cm.done THEN
						IF cm.mode # seg.succ THEN ChangeSucc(msg.fig, seg, cm.mode)
						ELSE msg.notify := TRUE
						END
					END
				END
			END
		END
	END TransformSegment;

	PROCEDURE ConnectSegment* (seg: Segment; VAR msg: ConnectMsg);
		VAR first, last, p: Point; dx, dy, t, x, y: FLOAT32;
	BEGIN
		IF ~seg.closed & (seg.bottom # NIL) & (seg.bottom # seg.top) THEN
			first := seg.bottom(Point); last := seg.top(Point);
			IF msg.id = get THEN
				IF msg.pos = start THEN
					msg.mode := seg.pred; msg.x := first.x; msg.y := first.y;
					msg.dx := first.up(Point).x - first.x; msg.dy := first.up(Point).y - first.y
				ELSIF msg.pos = end THEN
					msg.mode := seg.succ; msg.x := last.x; msg.y := last.y;
					msg.dx := last.x - last.down(Point).x; msg.dy := last.y - last.down(Point).y
				END;
				msg.done := TRUE
			ELSIF msg.id = set THEN
				IF msg.pos = start THEN
					IF msg.mode # term THEN
						Leonardo.BeginCommand(msg.fig);
						Leonardo.SetReal(msg.fig, first, "X", msg.x);
						Leonardo.SetReal(msg.fig, first, "Y", msg.y);
						p := first.up(Point);
						IF msg.mode MOD wrap = collinear THEN
							dx := p.x - msg.x; dy := p.y - msg.y;
							t := Math.sqrt((dx * dx + dy * dy)/(msg.dx * msg.dx + msg.dy * msg.dy));
							Leonardo.SetReal(msg.fig, p, "X", msg.x + t * msg.dx);
							Leonardo.SetReal(msg.fig, p, "Y", msg.y + t * msg.dy)
						ELSIF msg.mode MOD wrap = symmetric THEN
							Leonardo.SetReal(msg.fig, p, "X", msg.x + msg.dx);
							Leonardo.SetReal(msg.fig, p, "Y", msg.y + msg.dy)
						END;
						Leonardo.EndCommand(msg.fig);
						first.slink := p; p.slink := NIL;
						Leonardo.Transform(msg.fig, first, GfxMatrix.Identity)
					END;
					IF msg.mode # seg.pred THEN
						ChangePred(msg.fig, seg, msg.mode)
					END;
					msg.done := TRUE
				ELSIF msg.pos = end THEN
					IF msg.mode # term THEN
						Leonardo.BeginCommand(msg.fig);
						Leonardo.SetReal(msg.fig, last, "X", msg.x);
						Leonardo.SetReal(msg.fig, last, "Y", msg.y);
						p := last.down(Point);
						IF msg.mode MOD wrap = collinear THEN
							dx := msg.x - p.x; dy := msg.y - p.y;
							t := Math.sqrt((dx * dx + dy * dy)/(msg.dx * msg.dx + msg.dy * msg.dy));
							Leonardo.SetReal(msg.fig, p, "X", msg.x - t * msg.dx);
							Leonardo.SetReal(msg.fig, p, "Y", msg.y - t * msg.dy)
						ELSIF msg.mode MOD wrap = symmetric THEN
							Leonardo.SetReal(msg.fig, p, "X", msg.x - msg.dx);
							Leonardo.SetReal(msg.fig, p, "Y", msg.y - msg.dy)
						END;
						Leonardo.EndCommand(msg.fig);
						last.slink := p; p.slink := NIL;
						Leonardo.Transform(msg.fig, last, GfxMatrix.Identity)
					END;
					IF msg.mode # seg.succ THEN
						ChangeSucc(msg.fig, seg, msg.mode)
					END;
					msg.done := TRUE
				END
			ELSIF (msg.id = notify) & (msg.stamp # seg.stamp) THEN
				IF (msg.pos = start) & (seg.pred # term) THEN
					IF ABS(msg.x - first.x) + ABS(msg.y - first.y) > 1.0E-3 THEN
						IF first.marked THEN
							msg.mode := term; ChangePred(msg.fig, seg, term)
						ELSE
							Leonardo.SetReal(msg.fig, first, "X", msg.x);
							Leonardo.SetReal(msg.fig, first, "Y", msg.y);
							first.marked := TRUE; seg.stamp := msg.stamp
						END;
						msg.done := TRUE
					END;
					p := first.up(Point); x := p.x; y := p.y;
					IF msg.mode MOD wrap = collinear THEN
						dx := p.x - msg.x; dy := p.y - msg.y;
						t := Math.sqrt((dx * dx + dy * dy)/(msg.dx * msg.dx + msg.dy * msg.dy));
						x := msg.x + t * msg.dx; y := msg.y + t * msg.dy
					ELSIF msg.mode MOD wrap = symmetric THEN
						x := msg.x + msg.dx; y := msg.y + msg.dy
					END;
					IF ABS(x - p.x) + ABS(y - p.y) > 1.0E-3 THEN
						IF ~p.marked THEN
							Leonardo.SetReal(msg.fig, p, "X", x);
							Leonardo.SetReal(msg.fig, p, "Y", y);
							p.marked := TRUE; seg.stamp := msg.stamp
						ELSE
							IF first.marked THEN msg.mode := term
							ELSE msg.mode := coincident + wrap * (msg.mode DIV wrap)
							END;
							ChangePred(msg.fig, seg, msg.mode)
						END;
						msg.done := TRUE
					END
				ELSIF (msg.pos = end) & (seg.succ # term) THEN
					IF ABS(msg.x - last.x) + ABS(msg.y - last.y) > 1.0E-3 THEN
						IF last.marked THEN
							msg.mode := term; ChangeSucc(msg.fig, seg, term)
						ELSE
							Leonardo.SetReal(msg.fig, last, "X", msg.x);
							Leonardo.SetReal(msg.fig, last, "Y", msg.y);
							last.marked := TRUE; seg.stamp := msg.stamp
						END;
						msg.done := TRUE
					END;
					p := last.down(Point); x := p.x; y := p.y;
					IF msg.mode MOD wrap = collinear THEN
						dx := msg.x - p.x; dy := msg.y - p.y;
						t := Math.sqrt((dx * dx + dy * dy)/(msg.dx * msg.dx + msg.dy * msg.dy));
						x := msg.x - t * msg.dx; y := msg.y - t * msg.dy
					ELSIF msg.mode MOD wrap = symmetric THEN
						x := msg.x - msg.dx; y := msg.y - msg.dy
					END;
					IF ABS(x - p.x) + ABS(y - p.y) > 1.0E-3 THEN
						IF ~p.marked THEN
							Leonardo.SetReal(msg.fig, p, "X", x);
							Leonardo.SetReal(msg.fig, p, "Y", y);
							p.marked := TRUE; seg.stamp := msg.stamp
						ELSE
							IF last.marked THEN msg.mode := term
							ELSE msg.mode := coincident + wrap * (msg.mode DIV wrap)
							END;
							ChangeSucc(msg.fig, seg, msg.mode)
						END;
						msg.done := TRUE
					END
				END
			END
		END
	END ConnectSegment;

	PROCEDURE CopySegment* (VAR msg: Objects.CopyMsg; from, to: Segment);
		VAR obj: Objects.Object;
	BEGIN
		Leonardo.CopyContainer(msg, from, to);
		obj := Gadgets.CopyPtr(msg, from.pen);
		to.pen := obj(LeoPens.Pen);
		to.closed := from.closed; to.pred := term; to.succ := term; to.boff := 0; to.eoff := 0
	END CopySegment;

	PROCEDURE HandleSegment* (obj: Objects.Object; VAR msg: Objects.ObjMsg);
		VAR seg, copy: Segment; p: Leonardo.Shape; ver: SIGNED32;
	BEGIN
		seg := obj(Segment);
		IF msg IS Leonardo.ShapeMsg THEN
			IF msg IS Leonardo.SelectMsg THEN
				WITH msg: Leonardo.SelectMsg DO
					IF (msg.id = Leonardo.reset) & seg.sel THEN
						p := seg.bottom; WHILE p # NIL DO p.sel := FALSE; p := p.up END;
						Leonardo.UpdateShape(msg.fig, seg);
						seg.sel := FALSE
					ELSE
						Leonardo.SelectContainer(seg, msg)
					END
				END
			ELSIF msg IS Leonardo.ControlMsg THEN
				ControlSegment(seg, msg(Leonardo.ControlMsg))
			ELSIF msg IS Leonardo.OrderMsg THEN
				OrderSegment(seg, msg(Leonardo.OrderMsg))
			ELSIF msg IS Leonardo.ValidateMsg THEN
				ValidateSegment(seg, msg(Leonardo.ValidateMsg))
			ELSIF msg IS Leonardo.ConsumeMsg THEN
				ConsumeSegment(seg, msg(Leonardo.ConsumeMsg))
			ELSIF msg IS Leonardo.TransformMsg THEN
				TransformSegment(seg, msg(Leonardo.TransformMsg))
			ELSIF msg IS ContourMsg THEN
				msg(ContourMsg).done := TRUE
			ELSIF msg IS ValidateMsg THEN
				WITH msg: ValidateMsg DO
					IF (msg.pos = start) & (msg.off # seg.boff) THEN
						Leonardo.UpdateShape(msg.fig, seg);
						seg.boff := msg.off;
						IF (seg.succ # term) & (seg.succ < wrap) THEN
							msg.off := seg.boff + seg.len; seg.up.handle(seg.up, msg)
						END
					ELSIF (msg.pos = end) & (msg.off # seg.eoff) THEN
						Leonardo.UpdateShape(msg.fig, seg);
						seg.eoff := msg.off;
						IF (seg.pred # term) & (seg.pred < wrap) THEN
							msg.off := seg.eoff + seg.len; seg.down.handle(seg.down, msg)
						END
					END
				END
			ELSE
				Leonardo.HandleContainer(seg, msg)
			END
		ELSIF msg IS LeoPens.UpdateMsg THEN
			WITH msg: LeoPens.UpdateMsg DO
				IF msg.pen = seg.pen THEN seg.marked := TRUE; seg.sel := TRUE
				ELSIF seg.pen # NIL THEN seg.pen.handle(seg.pen, msg)
				END
			END
		ELSIF msg IS Objects.AttrMsg THEN
			WITH msg: Objects.AttrMsg DO
				IF msg.id = Objects.enum THEN
					msg.Enum("Closed"); Leonardo.HandleContainer(seg, msg)
				ELSIF msg.id = Objects.get THEN
					IF msg.name = "Closed" THEN msg.class := Objects.Bool; msg.b := seg.closed; msg.res := 0
					ELSE Leonardo.HandleContainer(seg, msg)
					END
				ELSIF msg.id = Objects.set THEN
					IF msg.name = "Closed" THEN
						IF msg.class = Objects.Bool THEN
							IF ~msg.b THEN
								seg.closed := FALSE; msg.res := 0
							ELSIF (seg.bottom # seg.top) & (seg.pred = term) & (seg.succ = term) THEN
								seg.closed := TRUE; msg.res := 0
							END
						END
					ELSE
						Leonardo.HandleContainer(seg, msg)
					END
				END
			END
		ELSIF msg IS Objects.LinkMsg THEN
			WITH msg: Objects.LinkMsg DO
				IF msg.id = Objects.enum THEN
					msg.Enum("Pen"); Leonardo.HandleContainer(seg, msg)
				ELSIF msg.id = Objects.get THEN
					IF msg.name = "Pen" THEN msg.obj := seg.pen; msg.res := 0
					ELSE Leonardo.HandleContainer(seg, msg)
					END
				ELSIF msg.id = Objects.set THEN
					IF msg.name = "Pen" THEN
						IF (msg.obj # NIL) & (msg.obj IS LeoPens.Pen) THEN seg.pen := msg.obj(LeoPens.Pen); msg.res := 0 END
					ELSE
						Leonardo.HandleContainer(seg, msg)
					END
				END
			END
		ELSIF msg IS Objects.CopyMsg THEN
			WITH msg: Objects.CopyMsg DO
				IF msg.stamp # seg.stamp THEN
					NEW(copy); seg.dlink := copy; seg.stamp := msg.stamp;
					CopySegment(msg, seg, copy)
				END;
				msg.obj := seg.dlink
			END
		ELSIF msg IS Objects.BindMsg THEN
			seg.pen.handle(seg.pen, msg);
			Leonardo.HandleContainer(seg, msg)
		ELSIF msg IS Objects.FileMsg THEN
			WITH msg: Objects.FileMsg DO
				Leonardo.HandleContainer(seg, msg);
				IF msg.id = Objects.store THEN
					Files.WriteNum(msg.R, 2);
					Files.WriteBool(msg.R, seg.closed);
					Gadgets.WriteRef(msg.R, seg.lib, seg.pen);
					Files.Write(msg.R, seg.pred); Files.Write(msg.R, seg.succ);
					IF seg.pred # term THEN Files.WriteReal(msg.R, seg.boff) END;
					IF seg.succ # term THEN Files.WriteReal(msg.R, seg.eoff) END
				ELSIF msg.id = Objects.load THEN
					Files.ReadNum(msg.R, ver);
					Files.ReadBool(msg.R, seg.closed);
					Gadgets.ReadRef(msg.R, seg.lib, obj);
					IF (obj # NIL) & (obj IS LeoPens.Pen) THEN seg.pen := obj(LeoPens.Pen) END;
					IF ver > 1 THEN
						Files.Read(msg.R, seg.pred); Files.Read(msg.R, seg.succ);
						IF seg.pred # term THEN Files.ReadReal(msg.R, seg.boff) END;
						IF seg.succ # term THEN Files.ReadReal(msg.R, seg.eoff) END
					END;
					CalcSegmentBox(seg, GfxMatrix.Identity)
				END
			END
		ELSE
			Leonardo.HandleContainer(seg, msg)
		END
	END HandleSegment;

	PROCEDURE InitSegment* (seg: Segment; handle: Objects.Handler; bottom, top: Point; closed: BOOLEAN; pen: LeoPens.Pen);
	BEGIN
		Leonardo.InitContainer(seg, handle, bottom, top);
		seg.pen := pen; seg.closed := closed;
		seg.pred := term; seg.succ := term; seg.boff := 0; seg.eoff := 0;
		CalcSegmentBox(seg, GfxMatrix.Identity)
	END InitSegment;

	PROCEDURE SplitSegment* (fig: Leonardo.Figure; seg, new: Segment; at: Point; mode: SIGNED8);
		VAR p: Point;
	BEGIN
		InitSegment(new, seg.handle, NIL, NIL, FALSE, seg.pen);
		NEW(p); InitPoint(p, at.x, at.y);
		Leonardo.AddConsumeAction(fig, seg, new, new, seg.up, seg.cont(Leonardo.Container));
		Leonardo.AddDeleteAction(fig, at, at.up, seg.top, NIL, seg);
		Leonardo.AddConsumeAction(fig, NIL, at.up, seg.top, NIL, new);
		Leonardo.AddConsumeAction(fig, NIL, p, p, at.up, new);
		ChangeSucc(fig, new, seg.succ);
		ChangePred(fig, new, mode);
		ChangeSucc(fig, seg, mode)
	END SplitSegment;

	PROCEDURE SetPred* (fig: Leonardo.Figure; seg: Segment; mode: SIGNED8);
		VAR pred: Leonardo.Shape; cm: ConnectMsg;
	BEGIN
		pred := Pred(seg);
		IF pred # NIL THEN
			cm.fig := fig; cm.id := get; cm.pos := start; cm.done := FALSE; seg.handle(seg, cm);
			IF cm.done & (cm.mode # mode) THEN
				cm.id := set; cm.pos := end; cm.mode := mode; cm.done := FALSE; pred.handle(pred, cm);
				IF cm.done THEN
					cm.pos := start; cm.done := FALSE; seg.handle(seg, cm)
				END
			END
		END
	END SetPred;

	PROCEDURE SetSucc* (fig: Leonardo.Figure; seg: Segment; mode: SIGNED8);
		VAR succ: Leonardo.Shape; cm: ConnectMsg;
	BEGIN
		succ := Succ(seg);
		IF succ # NIL THEN
			cm.fig := fig; cm.id := get; cm.pos := end; cm.done := FALSE; seg.handle(seg, cm);
			IF cm.done & (cm.mode # mode) THEN
				cm.id := set; cm.pos := start; cm.mode := mode; cm.done := FALSE; succ.handle(succ, cm);
				IF cm.done THEN
					cm.pos := end; cm.done := FALSE; seg.handle(seg, cm)
				END
			END
		END
	END SetSucc;


	(**--- Polylines ---**)

	PROCEDURE OnLine* (x0, y0, x1, y1, x, y, llx, lly, urx, ury: FLOAT32; VAR px, py: FLOAT32): BOOLEAN;
		VAR dx, dy: FLOAT32;
	BEGIN
		GfxPaths.ProjectToLine(x0, y0, x1, y1, x, y, px, py);
		IF (llx <= px) & (px <= urx) & (lly <= py) & (py <= ury) THEN
			IF (llx <= x0) & (x0 <= urx) & (lly <= y0) & (y0 <= ury) & (llx <= x1) & (x1 <= urx) & (lly <= y1) & (y1 <= ury) THEN
				RETURN TRUE	(* even end points are within rectangle *)
			END;
			dx := x1 - x0; dy := y1 - y0;
			IF ((x - x0) * dx + (y - y0) * dy >= 0) & ((x1 - x) * dx + (y1 - y) * dy >= 0) THEN
				RETURN TRUE
			END
		END;
		RETURN FALSE
	END OnLine;

	PROCEDURE DrawPolyline (poly: Segment; pen: LeoPens.Pen);
		VAR first, last, p: Point; dx, dy: FLOAT32;
	BEGIN
		IF (poly.bottom # NIL) & (poly.bottom # poly.top) THEN
			GetFirstLast(poly, first, last);
			IF poly.closed THEN pen.do.enter(pen, first.x, first.y, last.x - last.down(Point).x, last.y - last.down(Point).y, 0)
			ELSIF poly.pred = term THEN pen.do.enter(pen, first.x, first.y, 0, 0, 0)
			ELSE
				GetPred(poly, dx, dy);
				pen.do.enter(pen, first.x, first.y, dx, dy, poly.boff)
			END;
			p := first.up(Point);
			WHILE p # last DO
				pen.do.line(pen, p.x, p.y);
				p := p.up(Point)
			END;
			pen.do.line(pen, p.x, p.y);
			IF poly.closed THEN pen.do.exit(pen, first.up(Point).x - first.x, first.up(Point).y - first.y, 0)
			ELSIF poly.succ = term THEN pen.do.exit(pen, 0, 0, 0)
			ELSE
				GetSucc(poly, dx, dy);
				pen.do.exit(pen, dx, dy, poly.eoff)
			END;
			poly.bottom.down := NIL; poly.top.up := NIL
		END
	END DrawPolyline;

	PROCEDURE DragPolyline (poly: Segment; ctxt: Gfx.Context);
		VAR first, last, p0, p1: Point; inpath: BOOLEAN;
	BEGIN
		IF (poly.bottom # NIL) & (poly.bottom # poly.top) THEN
			Gfx.Begin(ctxt, {Gfx.Stroke});
			GetFirstLast(poly, first, last);
			p0 := first; inpath := FALSE;
			REPEAT
				p1 := p0.up(Point);
				IF p0.marked OR p1.marked THEN
					IF ~inpath THEN
						Gfx.MoveTo(ctxt, p0.x, p0.y); inpath := TRUE
					END;
					Gfx.LineTo(ctxt, p1.x, p1.y)
				ELSE
					inpath := FALSE
				END;
				p0 := p1
			UNTIL p0 = last;
			poly.bottom.down := NIL; poly.top.up := NIL;
			Gfx.End(ctxt)
		END
	END DragPolyline;

	PROCEDURE RenderPolyline (poly: Segment; VAR msg: Leonardo.RenderMsg);
		VAR state: Gfx.State;
	BEGIN
		IF (poly.llx - poly.bw < msg.urx) & (msg.llx < poly.urx + poly.bw) &
			(poly.lly - poly.bw < msg.ury) & (msg.lly < poly.ury + poly.bw)
		THEN
			IF msg.id = Leonardo.marked THEN
				DragPolyline(poly, msg.ctxt)
			END;
			IF msg.id IN {Leonardo.active, Leonardo.passive} THEN
				Gfx.Save(msg.ctxt, Gfx.attr, state);
				poly.pen.do.begin(poly.pen, msg.ctxt);
				DrawPolyline(poly, poly.pen);
				poly.pen.do.end(poly.pen);
				Gfx.Restore(msg.ctxt, state)
			END;
			RenderSegment(poly, msg)
		END
	END RenderPolyline;

	PROCEDURE ProjectPolyline (poly: Segment; x, y, llx, lly, urx, ury: FLOAT32; VAR px, py: FLOAT32): BOOLEAN;
		VAR first, last, p0, p1: Point;
	BEGIN
		IF (poly.bottom # NIL) & (poly.bottom # poly.top) THEN
			GetFirstLast(poly, first, last);
			p0 := first;
			REPEAT
				p1 := p0.up(Point);
				IF OnLine(p0.x, p0.y, p1.x, p1.y, x, y, llx, lly, urx, ury, px, py) THEN
					poly.bottom.down := NIL; poly.top.up := NIL;
					RETURN TRUE
				END;
				p0 := p1
			UNTIL p0 = last;
			poly.bottom.down := NIL; poly.top.up := NIL
		END;
		RETURN FALSE
	END ProjectPolyline;

	PROCEDURE LocatePolyline (poly: Segment; VAR msg: Leonardo.LocateMsg);
		VAR res: Leonardo.Shape; glm: GfxMatrix.Matrix; llx, lly, urx, ury, px, py: FLOAT32;
	BEGIN
		IF (msg.llx <= poly.urx) & (poly.llx <= msg.urx) & (msg.lly <= poly.ury) & (poly.lly <= msg.ury) THEN
			IF msg.id = Leonardo.inside THEN
				IF (msg.llx <= poly.llx) & (poly.urx <= msg.urx) & (msg.lly <= poly.lly) & (poly.ury <= msg.ury) THEN
					poly.slink := msg.res; msg.res := poly
				ELSE
					Leonardo.ToComponents(poly.bottom, msg)
				END
			ELSE
				res := msg.res;
				Leonardo.ToComponents(poly.bottom, msg);
				IF msg.id = Leonardo.overlap THEN
					IF msg.res = res THEN
						GfxMatrix.Invert(msg.lgm, glm);
						GfxMatrix.ApplyToRect(glm, msg.llx, msg.lly, msg.urx, msg.ury, llx, lly, urx, ury);
						GfxMatrix.Apply(glm, 0.5*(msg.llx + msg.urx), 0.5*(msg.lly + msg.ury), px, py);
						IF ProjectPolyline(poly, px, py, llx, lly, urx, ury, px, py) THEN
							poly.slink := msg.res; msg.res := poly
						END
					ELSIF ~poly.sel THEN
						msg.res := poly; poly.slink := res	(* must select segment before points can be located *)
					END
				ELSIF (msg.id = Leonardo.project) & (msg.res = res) THEN
					GfxMatrix.Invert(msg.lgm, glm);
					GfxMatrix.ApplyToRect(glm, msg.llx, msg.lly, msg.urx, msg.ury, llx, lly, urx, ury);
					GfxMatrix.Apply(glm, msg.x, msg.y, px, py);
					IF ProjectPolyline(poly, px, py, llx, lly, urx, ury, px, py) THEN
						msg.res := poly; msg.px := px; msg.py := py
					END
				END
			END
		END
	END LocatePolyline;

	PROCEDURE SplitPolyline (poly: Segment; VAR msg: SplitMsg);
		VAR
			first, last, p, q: Point; succ, pred: Leonardo.Shape; cm: ConnectMsg; new: Segment; glm: GfxMatrix.Matrix;
			llx, lly, urx, ury, x, y, px, py: FLOAT32;
	BEGIN
		IF (poly.llx <= msg.urx) & (msg.llx <= poly.urx) & (poly.lly <= msg.ury) & (msg.lly <= poly.ury) THEN
			GetFirstLast(poly, first, last);
			IF (last.llx <= msg.urx) & (msg.llx <= last.urx) & (last.lly <= msg.ury) & (msg.lly <= last.ury) THEN
				IF poly.closed THEN
					NEW(p); InitPoint(p, first.x, first.y);
					Leonardo.AddConsumeAction(msg.fig, poly.top, p, p, NIL, poly);
					Leonardo.SetBool(msg.fig, poly, "Closed", FALSE)
				ELSIF poly.succ # term THEN
					succ := Succ(poly);
					IF succ # NIL THEN
						cm.fig := msg.fig; cm.id := set; cm.pos := start; cm.mode := term; cm.done := FALSE; succ.handle(succ, cm)
					END;
					ChangeSucc(msg.fig, poly, term)
				END
			ELSIF (first.llx <= msg.urx) & (msg.llx <= first.urx) & (first.lly <= msg.ury) & (msg.lly <= first.ury) THEN
				IF poly.pred # term THEN
					pred := Pred(poly);
					IF pred # NIL THEN
						cm.fig := msg.fig; cm.id := set; cm.pos := end; cm.mode := term; cm.done := FALSE; pred.handle(pred, cm)
					END;
					ChangePred(msg.fig, poly, term)
				END
			ELSE
				p := last.down(Point);
				WHILE p # first DO
					IF (p.llx <= msg.urx) & (msg.llx <= p.urx) & (p.lly <= msg.ury) & (msg.lly <= p.ury) THEN
						poly.bottom.down := NIL; poly.top.up := NIL;
						IF poly.closed THEN
							Leonardo.BeginCommand(msg.fig);
							NEW(q); InitPoint(q, first.x, first.y);
							Leonardo.AddConsumeAction(msg.fig, poly.top, q, q, NIL, poly);
							Leonardo.SetBool(msg.fig, poly, "Closed", FALSE);
							ChangePred(msg.fig, poly, coincident + wrap);
							ChangeSucc(msg.fig, poly, coincident + wrap);
							Leonardo.EndCommand(msg.fig)
						END;
						NEW(new); SplitSegment(msg.fig, poly, new, p, coincident);
						RETURN
					END;
					p := p.down(Point);
				END;
				GfxMatrix.Invert(msg.lgm, glm);
				GfxMatrix.ApplyToRect(glm, msg.llx, msg.lly, msg.urx, msg.ury, llx, lly, urx, ury);
				x := 0.5*(llx + urx); y := 0.5*(lly + ury);
				q := last; p := last.down(Point);
				LOOP
					IF OnLine(p.x, p.y, q.x, q.y, x, y, llx, lly, urx, ury, px, py) THEN
						poly.bottom.down := NIL; poly.top.up := NIL;
						NEW(q); InitPoint(q, px, py);
						Leonardo.AddConsumeAction(msg.fig, p, q, q, p.up, poly);
						RETURN
					END;
					IF p = first THEN EXIT END;
					q := p; p := p.down(Point)
				END
			END;
			poly.bottom.down := NIL; poly.top.up := NIL
		END
	END SplitPolyline;

	PROCEDURE HandlePolyline* (obj: Objects.Object; VAR msg: Objects.ObjMsg);
		VAR poly: Segment;
	BEGIN
		poly := obj(Segment);
		IF msg IS Leonardo.ShapeMsg THEN
			IF msg IS Leonardo.RenderMsg THEN
				RenderPolyline(poly, msg(Leonardo.RenderMsg))
			ELSIF msg IS Leonardo.LocateMsg THEN
				LocatePolyline(poly, msg(Leonardo.LocateMsg))
			ELSIF msg IS RenderMsg THEN
				DrawPolyline(poly, msg(RenderMsg).pen)
			ELSIF msg IS ConnectMsg THEN
				ConnectSegment(poly, msg(ConnectMsg))
			ELSIF msg IS Leonardo.ConsumeMsg THEN
				ConsumePoints(poly, msg(Leonardo.ConsumeMsg))
			ELSIF msg IS SplitMsg THEN
				SplitPolyline(poly, msg(SplitMsg))
			ELSE
				HandleSegment(poly, msg)
			END
		ELSIF msg IS Objects.AttrMsg THEN
			WITH msg: Objects.AttrMsg DO
				IF msg.id = Objects.get THEN
					IF msg.name = "Gen" THEN msg.class := Objects.String; msg.s := "LeoPaths.NewPolyline"; msg.res := 0
					ELSIF msg.name = "Item" THEN msg.class := Objects.String; msg.s := "Polyline"; msg.res := 0
					ELSE HandleSegment(poly, msg)
					END
				ELSE HandleSegment(poly, msg)
				END
			END
		ELSE
			HandleSegment(poly, msg)
		END
	END HandlePolyline;

	PROCEDURE InitPolyline* (poly: Segment; bottom, top: Point; closed: BOOLEAN; pen: LeoPens.Pen);
	BEGIN
		InitSegment(poly, HandlePolyline, bottom, top, closed, pen)
	END InitPolyline;

	PROCEDURE NewPolyline*;
		VAR poly: Segment;
	BEGIN
		NEW(poly); InitSegment(poly, HandlePolyline, NIL, NIL, FALSE, LeoPens.Default);
		Objects.NewObj := poly
	END NewPolyline;


	(**--- Beziers ---**)

	PROCEDURE SubdivideBezier (at, x0, y0, x1, y1, x2, y2, x3, y3: FLOAT32; VAR x11, y11, x12, y12, xm, ym, x21, y21, x22, y22: FLOAT32);
		VAR as, xt, yt: FLOAT32;
	BEGIN
		as := 1 - at;
		x11 := as * x0 + at * x1; y11 := as * y0 + at * y1;
		xt := as * x1 + at * x2; yt := as * y1 + at * y2;
		x22 := as * x2 + at * x3; y22 := as * y2 + at * y3;
		x12 := as * x11 + at * xt; y12 := as * y11 + at * yt;
		x21 := as * xt + at * x22; y21 := as * yt + at * y22;
		xm := as * x12 + at * x21; ym := as * y12 + at * y21
	END SubdivideBezier;

	PROCEDURE OnBezier (x0, y0, x1, y1, x2, y2, x3, y3, x, y, llx, lly, urx, ury: FLOAT32; VAR px, py: FLOAT32): BOOLEAN;
		VAR xa1, ya1, xa2, ya2, xm, ym, xb1, yb1, xb2, yb2: FLOAT32;
	BEGIN
		IF ((llx <= x0) OR (llx <= x1) OR (llx <= x2) OR (llx <= x3)) &
			((x0 <= urx) OR (x1 <= urx) OR (x2 <= urx) OR (x3 <= urx)) &
			((lly <= y0) OR (lly <= y1) OR (lly <= y2) OR (lly <= y3)) &
			((y0 <= ury) OR (y1 <= ury) OR (y2 <= ury) OR (y3 <= ury))
		THEN	(* within hull of control points *)
			IF (ABS(x3 - x0) <= 0.5*(urx - llx)) & (ABS(y3 - y0) <= 0.5*(ury - lly)) THEN	(* short enough *)
				RETURN OnLine(x0, y0, x3, y3, x, y, llx, lly, urx, ury, px, py)
			END;
			SubdivideBezier(0.5, x0, y0, x1, y1, x2, y2, x3, y3, xa1, ya1, xa2, ya2, xm, ym, xb1, yb1, xb2, yb2);
			RETURN
				OnBezier(x0, y0, xa1, ya1, xa2, ya2, xm, ym, x, y, llx, lly, urx, ury, px, py) OR
				OnBezier(xm, ym, xb1, yb1, xb2, yb2, x3, y3, x, y, llx, lly, urx, ury, px, py)
		ELSE
			RETURN FALSE
		END
	END OnBezier;

	PROCEDURE DrawBezier (bez: Segment; pen: LeoPens.Pen);
		VAR p0, p1, p2, p3: Point; x0, y0, dx, dy, x1, y1: FLOAT32;
	BEGIN
		IF (bez.bottom # NIL) & (bez.bottom # bez.top) THEN
			p0 := bez.bottom(Point);
			IF bez.closed THEN
				p1 := bez.top(Point); x0 := 0.5*(p0.x + p1.x); y0 := 0.5*(p0.y + p1.y);
				pen.do.enter(pen, x0, y0, p0.x - x0, p0.y - y0, 0);
				p1 := p0
			ELSE
				GetPred(bez, dx, dy); x0 := p0.x; y0 := p0.y;
				pen.do.enter(pen, x0, y0, dx, dy, bez.boff);
				p1 := p0.up(Point)
			END;
			REPEAT
				IF p1.up = NIL THEN
					IF bez.closed THEN
						p2 := bez.bottom(Point); x1 := 0.5*(p1.x + p2.x); y1 := 0.5*(p1.y + p2.y);
						pen.do.bezier(pen, x1, y1, (x0 + 2*p1.x)/3, (y0 + 2*p1.y)/3, (x1 + 2*p1.x)/3, (y1 + 2*p1.y)/3)
					ELSE
						pen.do.line(pen, p1.x, p1.y)
					END;
					p0 := p1	(* p1 = bez.top *)
				ELSE
					p2 := p1.up(Point);
					IF p2.up = NIL THEN
						IF bez.closed THEN
							p3 := bez.bottom(Point); x1 := 0.5*(p2.x + p3.x); y1 := 0.5*(p2.y + p3.y);
							pen.do.bezier(pen, x1, y1, p1.x, p1.y, p2.x, p2.y)
						ELSE
							pen.do.bezier(pen, p2.x, p2.y, (x0 + 2*p1.x)/3, (y0 + 2*p1.y)/3, (p2.x + 2*p1.x)/3, (p2.y + 2*p1.y)/3)
						END;
						p0 := p2	(* p2 = bez.top *)
					ELSE
						p3 := p2.up(Point);
						IF (p3 = bez.top) & ~bez.closed THEN
							pen.do.bezier(pen, p3.x, p3.y, p1.x, p1.y, p2.x, p2.y);
							p0 := p3
						ELSE
							x0 := 0.5*(p2.x + p3.x); y0 := 0.5*(p2.y + p3.y);
							pen.do.bezier(pen, x0, y0, p1.x, p1.y, p2.x, p2.y);
							p0 := p2; p1 := p3
						END
					END
				END
			UNTIL p0 = bez.top;
			IF bez.closed THEN
				pen.do.exit(pen, x1 - p0.x, y1 - p0.y, 0)
			ELSE
				GetSucc(bez, dx, dy);
				pen.do.exit(pen, dx, dy, bez.eoff)
			END
		END
	END DrawBezier;

	PROCEDURE DragBezier (bez: Segment; ctxt: Gfx.Context);
		VAR s: Leonardo.Shape; p0, p1, p2, p3: Point; x0, y0, x1, y1: FLOAT32; ctm: GfxMatrix.Matrix;
	BEGIN
		s := bez.bottom; WHILE (s # NIL) & ~s.marked DO s := s.up END;
		IF (s # NIL) & (bez.bottom # bez.top) & s.marked THEN
			Gfx.Begin(ctxt, {Gfx.Stroke});
			p0 := bez.bottom(Point);
			IF bez.closed THEN p1 := bez.top(Point); x0 := 0.5*(p0.x + p1.x); y0 := 0.5*(p0.y + p1.y); p1 := p0
			ELSE x0 := p0.x; y0 := p0.y; p1 := p0.up(Point)
			END;
			Gfx.MoveTo(ctxt, x0, y0);
			REPEAT
				IF p1.up = NIL THEN
					IF bez.closed THEN
						p2 := bez.bottom(Point); x1 := 0.5*(p1.x + p2.x); y1 := 0.5*(p1.y + p2.y);
						Gfx.BezierTo(ctxt, x1, y1, (x0 + 2*p1.x)/3, (y0 + 2*p1.y)/3, (x1 + 2*p1.x)/3, (y1 + 2*p1.y)/3)
					ELSE
						Gfx.LineTo(ctxt, p1.x, p1.y)
					END;
					p0 := p1	(* p1 = bez.top *)
				ELSE
					p2 := p1.up(Point);
					IF p2.up = NIL THEN
						IF bez.closed THEN
							p3 := bez.bottom(Point); x1 := 0.5*(p2.x + p3.x); y1 := 0.5*(p2.y + p3.y);
							Gfx.BezierTo(ctxt, x1, y1, p1.x, p1.y, p2.x, p2.y)
						ELSE
							Gfx.BezierTo(ctxt, p2.x, p2.y, (x0 + 2*p1.x)/3, (y0 + 2*p1.y)/3, (p2.x + 2*p1.x)/3, (p2.y + 2*p1.y)/3)
						END;
						p0 := p2	(* p2 = bez.top *)
					ELSE
						p3 := p2.up(Point);
						IF (p3 = bez.top) & ~bez.closed THEN
							Gfx.BezierTo(ctxt, p3.x, p3.y, p1.x, p1.y, p2.x, p2.y);
							p0 := p3
						ELSE
							x0 := 0.5*(p2.x + p3.x); y0 := 0.5*(p2.y + p3.y);
							Gfx.BezierTo(ctxt, x0, y0, p1.x, p1.y, p2.x, p2.y);
							p0 := p2; p1 := p3
						END
					END
				END
			UNTIL p0 = bez.top;
			Gfx.End(ctxt);
			ctm := ctxt.ctm; Gfx.ResetCTM(ctxt);
			p0 := bez.bottom.up(Point);
			WHILE p0 # bez.top DO
				GfxMatrix.Apply(ctm, p0.x, p0.y, x0, y0);
				x0 := ENTIER(x0); y0 := ENTIER(y0);
				Gfx.DrawRect(ctxt, x0-1, y0-1, x0+1, y0+1, {Gfx.Fill});
				p0 := p0.up(Point)
			END;
			Gfx.SetCTM(ctxt, ctm)
		END
	END DragBezier;

	PROCEDURE RenderBezier (bez: Segment; VAR msg: Leonardo.RenderMsg);
		VAR state: Gfx.State;
	BEGIN
		IF (bez.llx - bez.bw < msg.urx) & (msg.llx < bez.urx + bez.bw) &
			(bez.lly - bez.bw < msg.ury) & (msg.lly < bez.ury + bez.bw)
		THEN
			IF msg.id = Leonardo.marked THEN
				DragBezier(bez, msg.ctxt)
			END;
			IF msg.id IN {Leonardo.active, Leonardo.passive} THEN
				Gfx.Save(msg.ctxt, Gfx.attr, state);
				bez.pen.do.begin(bez.pen, msg.ctxt);
				DrawBezier(bez, bez.pen);
				bez.pen.do.end(bez.pen);
				Gfx.Restore(msg.ctxt, state)
			END;
			RenderSegment(bez, msg)
		END
	END RenderBezier;

	PROCEDURE ProjectBezier (bez: Segment; x, y, llx, lly, urx, ury: FLOAT32; VAR px, py: FLOAT32): BOOLEAN;
		VAR p0, p1, p2, p3: Point; x0, y0, x3, y3, x1, y1, x2, y2: FLOAT32;
	BEGIN
		IF (bez.bottom # NIL) & (bez.bottom # bez.top) THEN
			p0 := bez.bottom(Point);
			IF bez.closed THEN p1 := bez.top(Point); x0 := 0.5*(p0.x + p1.x); y0 := 0.5*(p0.y + p1.y); p1 := p0
			ELSE x0 := p0.x; y0 := p0.y; p1 := p0.up(Point)
			END;
			REPEAT
				IF p1.up = NIL THEN
					IF bez.closed THEN
						p2 := bez.bottom(Point); x3 := 0.5*(p1.x + p2.x); y3 := 0.5*(p1.y + p2.y);
						x1 := (x0 + 2*p1.x)/3; y1 := (y0 + 2*p1.y)/3; x2 := (x3 + 2*p1.x)/3; y2 := (y3 + 2*p1.y)/3;
						IF OnBezier(x0, y0, x1, y1, x2, y2, x3, y3, x, y, llx, lly, urx, ury, px, py) THEN
							RETURN TRUE
						END
					ELSIF OnLine(x0, y0, p1.x, p1.y, x, y, llx, lly, urx, ury, px, py) THEN
						RETURN TRUE
					END;
					p0 := p1	(* p1 = bez.top *)
				ELSE
					p2 := p1.up(Point);
					IF p2.up = NIL THEN
						IF bez.closed THEN
							p3 := bez.bottom(Point); x3 := 0.5*(p2.x + p3.x); y3 := 0.5*(p2.y + p3.y);
							IF OnBezier(x0, y0, p1.x, p1.y, p2.x, p2.y, x3, y3, x, y, llx, lly, urx, ury, px, py) THEN
								RETURN TRUE
							END
						ELSE
							x1 := (x0 + 2*p1.x)/3; y1 := (y0 + 2*p1.y)/3; x2 := (p2.x + 2*p1.x)/3; y2 := (p2.y + 2*p1.y)/3;
							IF OnBezier(x0, y0, x1, y1, x2, y2, p2.x, p2.y, x, y, llx, lly, urx, ury, px, py) THEN
								RETURN TRUE
							END
						END;
						p0 := p2	(* p2 = bez.top *)
					ELSE
						p3 := p2.up(Point);
						IF (p3 = bez.top) & ~bez.closed THEN
							IF OnBezier(x0, y0, p1.x, p1.y, p2.x, p2.y, p3.x, p3.y, x, y, llx, lly, urx, ury, px, py) THEN
								RETURN TRUE
							END;
							p0 := p3
						ELSE
							x3 := 0.5*(p2.x + p3.x); y3 := 0.5*(p2.y + p3.y);
							IF OnBezier(x0, y0, p1.x, p1.y, p2.x, p2.y, x3, y3, x, y, llx, lly, urx, ury, px, py) THEN
								RETURN TRUE
							END;
							p0 := p2; p1 := p3; x0 := x3; y0 := y3
						END
					END
				END
			UNTIL p0 = bez.top
		END;
		RETURN FALSE
	END ProjectBezier;

	PROCEDURE LocateBezier (bez: Segment; VAR msg: Leonardo.LocateMsg);
		VAR res: Leonardo.Shape; glm: GfxMatrix.Matrix; llx, lly, urx, ury, px, py: FLOAT32;
	BEGIN
		IF (msg.llx <= bez.urx) & (bez.llx <= msg.urx) & (msg.lly <= bez.ury) & (bez.lly <= msg.ury) THEN
			IF msg.id = Leonardo.inside THEN
				IF (msg.llx <= bez.llx) & (bez.urx <= msg.urx) & (msg.lly <= bez.lly) & (bez.ury <= msg.ury) THEN
					bez.slink := msg.res; msg.res := bez
				ELSE
					Leonardo.ToComponents(bez.bottom, msg)
				END
			ELSE
				res := msg.res;
				Leonardo.ToComponents(bez.bottom, msg);
				IF msg.id = Leonardo.overlap THEN
					IF msg.res = res THEN
						GfxMatrix.Invert(msg.lgm, glm);
						GfxMatrix.ApplyToRect(glm, msg.llx, msg.lly, msg.urx, msg.ury, llx, lly, urx, ury);
						GfxMatrix.Apply(glm, 0.5*(msg.llx + msg.urx), 0.5*(msg.lly + msg.ury), px, py);
						IF ProjectBezier(bez, px, py, llx, lly, urx, ury, px, py) THEN
							bez.slink := msg.res; msg.res := bez
						END
					ELSIF ~bez.sel THEN
						msg.res := bez; bez.slink := res	(* must select segment before points can be located *)
					END
				ELSIF (msg.id = Leonardo.project) & (msg.res = res) THEN
					GfxMatrix.Invert(msg.lgm, glm);
					GfxMatrix.ApplyToRect(glm, msg.llx, msg.lly, msg.urx, msg.ury, llx, lly, urx, ury);
					GfxMatrix.Apply(glm, msg.x, msg.y, px, py);
					IF ProjectBezier(bez, px, py, llx, lly, urx, ury, px, py) THEN
						msg.res := bez; msg.px := px; msg.py := py
					END
				END
			END
		END
	END LocateBezier;

	PROCEDURE SplitBezier (bez: Segment; VAR msg: SplitMsg);
		VAR
			p0, p1, p2, bt, tp, p3: Point; succ, pred: Leonardo.Shape; cm: ConnectMsg; glm: GfxMatrix.Matrix;
			llx, lly, urx, ury, x, y, x0, y0, x3, y3, x1, y1, x2, y2, px, py, t, x11, y11, x12, y12, xm, ym, x21, y21, x22, y22: FLOAT32;
			s: Segment;

		PROCEDURE split (x0, y0, x1, y1, x2, y2, x3, y3, x, y, t0, t1: FLOAT32; VAR px, py, t: FLOAT32): BOOLEAN;
			VAR x11, y11, x12, y12, x21, y21, x22, y22: FLOAT32;
		BEGIN
			IF (ABS(x3 - x0) <= 0.5*(urx - llx)) & (ABS(y3 - y0) <= 0.5*(ury - lly)) THEN
				IF OnLine(x0, y0, x3, y3, x, y, llx, lly, urx, ury, px, py) THEN
					t := Math.sqrt(((x3 - px)*(x3 - px) + (y3 - py)*(y3 - py)) / ((x3 - x0)*(x3 - x0) + (y3 - y0)*(y3 - y0)));
					t := t0 * t + t1 * (1-t);
					RETURN TRUE
				ELSE
					RETURN FALSE
				END
			END;
			SubdivideBezier(0.5, x0, y0, x1, y1, x2, y2, x3, y3, x11, y11, x12, y12, xm, ym, x21, y21, x22, y22);
			RETURN
				split(x0, y0, x11, y11, x12, y12, xm, ym, x, y, t0, 0.5*(t0 + t1), px, py, t) OR
				split(xm, ym, x21, y21, x22, y22, x3, y3, x, y, 0.5*(t0 + t1), t1, px, py, t)
		END split;

		PROCEDURE unclose (x, y: FLOAT32);
			VAR p: Point;
		BEGIN
			NEW(p); InitPoint(p, x, y);
			Leonardo.AddConsumeAction(msg.fig, NIL, p, p, bez.bottom, bez);
			Leonardo.SetBool(msg.fig, bez, "Closed", FALSE);
			ChangePred(msg.fig, bez, collinear + wrap);
			ChangeSucc(msg.fig, bez, collinear + wrap)
		END unclose;

		PROCEDURE move (p: Point; x, y: FLOAT32);
		BEGIN
			Leonardo.SetReal(msg.fig, p, "X", x);
			Leonardo.SetReal(msg.fig, p, "Y", y)
		END move;

		PROCEDURE make (x, y: FLOAT32; VAR b, t: Point);
		BEGIN
			NEW(b); InitPoint(b, x, y); t := b
		END make;

		PROCEDURE add (x, y: FLOAT32; VAR t: Point);
			VAR p: Point;
		BEGIN
			NEW(p); InitPoint(p, x, y);
			p.down := t; t.up := p; t := p
		END add;

		PROCEDURE bezier (x0, y0, x1, y1, x2, y2, x3, y3: FLOAT32): Segment;
			VAR p0, p3: Point; b: Segment;
		BEGIN
			make(x0, y0, p0, p3); add(x1, y1, p3); add(x2, y2, p3); add(x3, y3, p3);
			NEW(b); InitSegment(b, bez.handle, p0, p3, FALSE, bez.pen);
			RETURN b
		END bezier;

		PROCEDURE line (x0, y0, x1, y1: FLOAT32): Segment;
			VAR p0, p1: Point; l: Segment;
		BEGIN
			make(x0, y0, p0, p1); add(x1, y1, p1);
			NEW(l); InitPolyline(l, p0, p1, FALSE, bez.pen);
			RETURN l
		END line;

		PROCEDURE connect (seg: Segment);
		BEGIN
			Leonardo.AddConsumeAction(msg.fig, bez, seg, seg, bez.up, bez.cont(Leonardo.Container));
			seg.pred := collinear;
			IF bez.closed THEN seg.succ := collinear + wrap	(* hack: new mode from unclose() hasn't yet been set *)
			ELSE seg.succ := bez.succ
			END;
			IF bez.succ # collinear THEN
				ChangeSucc(msg.fig, bez, collinear)
			END
		END connect;

	BEGIN
		IF (bez.llx <= msg.urx) & (msg.llx <= bez.urx) & (bez.lly <= msg.ury) & (msg.lly <= bez.ury) THEN
			p0 := bez.bottom(Point); p1 := bez.top(Point);
			IF (p1.llx <= msg.urx) & (msg.llx <= p1.urx) & (p1.lly <= msg.ury) & (msg.lly <= p1.ury) THEN
				IF ~bez.closed & (bez.succ # term) THEN
					succ := Succ(bez);
					IF succ # NIL THEN
						cm.fig := msg.fig; cm.id := set; cm.pos := start; cm.mode := term; cm.done := FALSE; succ.handle(succ, cm)
					END;
					ChangeSucc(msg.fig, bez, term)
				END
			ELSIF (p0.llx <= msg.urx) & (msg.llx <= p0.urx) & (p0.lly <= msg.ury) & (msg.lly <= p0.ury) THEN
				IF ~bez.closed & (bez.pred # term) THEN
					pred := Pred(bez);
					IF pred # NIL THEN
						cm.fig := msg.fig; cm.id := set; cm.pos := end; cm.mode := term; cm.done := FALSE; pred.handle(pred, cm)
					END;
					ChangePred(msg.fig, bez, term)
				END
			ELSE
				GfxMatrix.Invert(msg.lgm, glm);
				GfxMatrix.ApplyToRect(glm, msg.llx, msg.lly, msg.urx, msg.ury, llx, lly, urx, ury);
				x := 0.5*(llx + urx); y := 0.5*(lly + ury);
				p0 := bez.bottom(Point);
				IF bez.closed THEN p1 := bez.top(Point); x0 := 0.5*(p0.x + p1.x); y0 := 0.5*(p0.y + p1.y); p1 := p0
				ELSE x0 := p0.x; y0 := p0.y; p1 := p0.up(Point)
				END;
				REPEAT
					IF p1.up = NIL THEN
						IF bez.closed THEN
							p2 := bez.bottom(Point); x3 := 0.5*(p1.x + p2.x); y3 := 0.5*(p1.y + p2.y);
							x1 := (x0 + 2*p1.x)/3; y1 := (y0 + 2*p1.y)/3; x2 := (x3 + 2*p1.x)/3; y2 := (y3 + 2*p1.y)/3;
							IF split(x0, y0, x1, y1, x2, y2, x3, y3, x, y, 0, 1, px, py, t) THEN
								unclose(x3, y3);
								SubdivideBezier(t, x0, y0, x1, y1, x2, y2, x3, y3, x11, y11, x12, y12, xm, ym, x21, y21, x22, y22);
								move(p1, x11, y11); make(x12, y12, bt, tp); add(xm, ym, tp);
								Leonardo.AddConsumeAction(msg.fig, p1, bt, tp, NIL, bez);
								connect(bezier(xm, ym, x21, y21, x22, y22, x3, y3));
								RETURN
							END
						ELSIF OnLine(x0, y0, p1.x, p1.y, x, y, llx, lly, urx, ury, px, py) THEN
							move(p1, px, py); connect(line(px, py, p1.x, p1.y));
							RETURN
						END;
						p0 := p1	(* p1 = bez.top *)
					ELSE
						p2 := p1.up(Point);
						IF p2.up = NIL THEN
							IF bez.closed THEN
								p3 := bez.bottom(Point); x3 := 0.5*(p2.x + p3.x); y3 := 0.5*(p2.y + p3.y);
								IF split(x0, y0, p1.x, p1.y, p2.x, p2.y, x3, y3, x, y, 0, 1, px, py, t) THEN
									unclose(x3, y3);
									SubdivideBezier(t, x0, y0, p1.x, p1.y, p2.x, p2.y, x3, y3, x11, y11, x12, y12, xm, ym, x21, y21, x22, y22);
									move(p1, x11, y11); move(p2, x12, y12); make(xm, ym, bt, tp);
									Leonardo.AddConsumeAction(msg.fig, p2, bt, tp, NIL, bez);
									connect(bezier(xm, ym, x21, y21, x22, y22, x3, y3));
									RETURN
								END
							ELSE
								x1 := (x0 + 2*p1.x)/3; y1 := (y0 + 2*p1.y)/3; x2 := (p2.x + 2*p1.x)/3; y2 := (p2.y + 2*p1.y)/3;
								IF split(x0, y0, x1, y1, x2, y2, p2.x, p2.y, x, y, 0, 1, px, py, t) THEN
									SubdivideBezier(t, x0, y0, x1, y1, x2, y2, p2.x, p2.y, x11, y11, x12, y12, xm, ym, x21, y21, x22, y22);
									move(p1, x11, y11); move(p2, x12, y12); make(xm, ym, bt, tp);
									Leonardo.AddConsumeAction(msg.fig, p2, bt, tp, NIL, bez);
									connect(bezier(xm, ym, x21, y21, x22, y22, p2.x, p2.y));
									RETURN
								END
							END;
							p0 := p2	(* p2 = bez.top *)
						ELSE
							p3 := p2.up(Point);
							IF (p3 = bez.top) & ~bez.closed THEN
								x3 := p3.x; y3 := p3.y;
								IF split(x0, y0, p1.x, p1.y, p2.x, p2.y, x3, y3, x, y, 0, 1, px, py, t) THEN
									SubdivideBezier(t, x0, y0, p1.x, p1.y, p2.x, p2.y, x3, y3, x11, y11, x12, y12, xm, ym, x21, y21, x22, y22);
									move(p1, x11, y11); move(p2, x12, y12); move(p3, xm, ym);
									make(xm, ym, bt, tp); add(x21, y21, tp); add(x22, y22, tp); add(x3, y3, tp);
									NEW(s); InitSegment(s, bez.handle, bt, tp, FALSE, bez.pen); connect(s);
									RETURN
								END;
								p0 := p3
							ELSE
								x3 := 0.5*(p2.x + p3.x); y3 := 0.5*(p2.y + p3.y);
								IF split(x0, y0, p1.x, p1.y, p2.x, p2.y, x3, y3, x, y, 0, 1, px, py, t) THEN
									SubdivideBezier(t, x0, y0, p1.x, p1.y, p2.x, p2.y, x3, y3, x11, y11, x12, y12, xm, ym, x21, y21, x22, y22);
									move(p1, x11, y11); move(p2, x12, y12);
									IF bez.closed THEN
										x1 := 0.5*(bez.bottom(Point).x + bez.top(Point).x);
										y1 := 0.5*(bez.bottom(Point).y + bez.top(Point).y);
										unclose(x1, y1)
									END;
									Leonardo.AddDeleteAction(msg.fig, p2, p3, bez.top, NIL, bez);
									make(xm, ym, bt, tp);
									Leonardo.AddConsumeAction(msg.fig, p2, bt, tp, NIL, bez);
									make(xm, ym, bt, tp); add(x21, y21, tp); add(x22, y22, tp);
									NEW(s); InitSegment(s, bez.handle, bt, tp, FALSE, bez.pen); connect(s);
									Leonardo.AddConsumeAction(msg.fig, tp, p3, bez.top, NIL, s);
									IF bez.closed THEN
										make(x1, y1, bt, tp);
										Leonardo.AddConsumeAction(msg.fig, bez.top, bt, tp, NIL, s)
									END;
									RETURN
								END;
								p0 := p2; p1 := p3; x0 := x3; y0 := y3
							END
						END
					END
				UNTIL p0 = bez.top
			END
		END
	END SplitBezier;

	PROCEDURE HandleBezier* (obj: Objects.Object; VAR msg: Objects.ObjMsg);
		VAR bez: Segment;
	BEGIN
		bez := obj(Segment);
		IF msg IS Leonardo.ShapeMsg THEN
			IF msg IS Leonardo.RenderMsg THEN
				RenderBezier(bez, msg(Leonardo.RenderMsg))
			ELSIF msg IS Leonardo.LocateMsg THEN
				LocateBezier(bez, msg(Leonardo.LocateMsg))
			ELSIF msg IS RenderMsg THEN
				DrawBezier(bez, msg(RenderMsg).pen)
			ELSIF msg IS ConnectMsg THEN
				ConnectSegment(bez, msg(ConnectMsg))
			ELSIF msg IS SplitMsg THEN
				SplitBezier(bez, msg(SplitMsg))
			ELSE
				HandleSegment(bez, msg)
			END
		ELSIF msg IS Objects.AttrMsg THEN
			WITH msg: Objects.AttrMsg DO
				IF msg.id = Objects.get THEN
					IF msg.name = "Gen" THEN msg.class := Objects.String; msg.s := "LeoPaths.NewBezierX"; msg.res := 0
					ELSIF msg.name = "Item" THEN msg.class := Objects.String; msg.s := "Bezier"; msg.res := 0
					ELSE HandleSegment(bez, msg)
					END
				ELSE HandleSegment(bez, msg)
				END
			END
		ELSE
			HandleSegment(bez, msg)
		END
	END HandleBezier;

	PROCEDURE InitBezier* (bezier: Segment; bottom, top: Point; closed: BOOLEAN; pen: LeoPens.Pen);
	BEGIN
		InitSegment(bezier, HandleBezier, bottom, top, closed, pen)
	END InitBezier;

	PROCEDURE NewBezierX*;
		VAR bez: Segment;
	BEGIN
		NEW(bez); InitSegment(bez, HandleBezier, NIL, NIL, FALSE, LeoPens.Default);
		Objects.NewObj := bez
	END NewBezierX;


	(**--- Arcs ---**)

	PROCEDURE ArcToPath (arc: Arc; path: GfxPaths.Path);
		VAR p0, p1: Point; x0, y0, x1, y1, x2, y2, dx, dy: FLOAT32;
	BEGIN
		GfxPaths.Clear(path);
		IF (arc.bottom # NIL) & (arc.bottom # arc.top) THEN
			p0 := arc.bottom(Point); p1 := arc.top(Point);
			x0 := arc.mat[2, 0]; y0 := arc.mat[2, 1];
			x1 := x0 - arc.mat[0, 0]; y1 := y0 - arc.mat[0, 1];
			x2 := x0 + arc.mat[1, 0]; y2 := y0 + arc.mat[1, 1];
			IF ~arc.closed THEN GetPred(arc, dx, dy)
			ELSIF arc.mode = wedge THEN dx := p0.x - x0; dy := p0.y - y0
			ELSE dx := p0.x - p1.x; dy := p0.y - p1.y
			END;
			GfxPaths.AddEnter(path, p0.x, p0.y, dx, dy);
			GfxPaths.AddArc(path, p1.x, p1.y, x0, y0, x1, y1, x2, y2);
			IF ~arc.closed THEN
				GetSucc(arc, dx, dy)
			ELSE
				IF arc.mode = wedge THEN GfxPaths.AddLine(path, x0, y0) END;
				GfxPaths.AddLine(path, p0.x, p0.y);
				dx := arc.dx0; dy := arc.dy0
			END;
			GfxPaths.AddExit(path, dx, dy)
		END
	END ArcToPath;

	PROCEDURE EnumArc (VAR data: GfxPaths.EnumData);
	BEGIN
		WITH data: ArcData DO
			IF data.n = 0 THEN
				data.dx0 := data.x - data.x0; data.dy0 := data.y - data.y0; data.dx1 := data.dx0; data.dy1 := data.dy0
			ELSE
				data.dx1 := data.x - data.x1; data.dy1 := data.y - data.y1
			END;
			data.x1 := data.x; data.y1 := data.y; INC(data.n)
		END
	END EnumArc;

	PROCEDURE CalcArcBox* (arc: Arc; VAR mat: GfxMatrix.Matrix);
		VAR m: GfxMatrix.Matrix; p0, p1: Point; x0, y0, x1, y1, x2, y2: FLOAT32; data: ArcData;
	BEGIN
		GfxMatrix.Concat(arc.mat, mat, m);
		GfxMatrix.ApplyToRect(m, -1, -1, 1, 1, arc.llx, arc.lly, arc.urx, arc.ury);
		Attributes.GetReal(arc.pen, "Border", arc.bw);
		GfxMatrix.ApplyToDist(mat, arc.bw, arc.bw);
		arc.dx0 := 0; arc.dy0 := 0; arc.dx1 := 0; arc.dy1 := 0;
		IF ~arc.closed THEN
			p0 := arc.bottom(Point); p1 := arc.top(Point);
			x0 := arc.mat[2, 0]; y0 := arc.mat[2, 1];
			x1 := x0 - arc.mat[0, 0]; y1 := y0 - arc.mat[0, 1];
			x2 := x0 + arc.mat[1, 0]; y2 := y0 + arc.mat[1, 1];
			data.x0 := p0.x; data.y0 := p0.y; data.x := data.x0; data.y := data.y0; data.n := 0;
			GfxPaths.EnumArc(x0, y0, x1, y1, x2, y2, p1.x, p1.y, 0.5, EnumArc, data);
			arc.dx0 := data.dx0; arc.dy0 := data.dy0; arc.dx1 := data.dx1; arc.dy1 := data.dy1
		END
	END CalcArcBox;

	PROCEDURE ControlArc (arc: Arc; VAR msg: Leonardo.ControlMsg);
	BEGIN
		IF msg.id = Leonardo.delete THEN
			arc.bottom.marked := FALSE; arc.top.marked := FALSE;
			ControlSegment(arc, msg)
		ELSIF msg.id = Leonardo.clone THEN
			IF arc.marked THEN
				ControlSegment(arc, msg)
			END
		ELSE
			ControlSegment(arc, msg)
		END
	END ControlArc;

	PROCEDURE ValidateArc (arc: Arc; VAR msg: Leonardo.ValidateMsg);
	BEGIN
		Leonardo.ToComponents(arc.bottom, msg);
		IF arc.marked THEN
			Leonardo.UpdateShape(msg.fig, arc);
			CalcArcBox(arc, msg.lgm);
			Leonardo.UpdateShape(msg.fig, arc);
			ValidateSegmentLength(arc, msg);
			arc.marked := FALSE; arc.cont.marked := TRUE
		END
	END ValidateArc;

	PROCEDURE DrawArc (arc: Arc; pen: LeoPens.Pen);
		VAR p0, p1: Point; x0, y0, x1, y1, x2, y2, dx, dy: FLOAT32;
	BEGIN
		IF (arc.bottom # NIL) & (arc.bottom # arc.top) THEN
			p0 := arc.bottom(Point); p1 := arc.top(Point);
			x0 := arc.mat[2, 0]; y0 := arc.mat[2, 1];
			x1 := x0 - arc.mat[0, 0]; y1 := y0 - arc.mat[0, 1];
			x2 := x0 + arc.mat[1, 0]; y2 := y0 + arc.mat[1, 1];
			IF ~arc.closed THEN GetPred(arc, dx, dy)
			ELSIF arc.mode = wedge THEN dx := p0.x - x0; dy := p0.y - y0
			ELSE dx := p0.x - p1.x; dy := p0.y - p1.y
			END;
			pen.do.enter(pen, p0.x, p0.y, dx, dy, arc.boff);
			pen.do.arc(pen, p1.x, p1.y, x0, y0, x1, y1, x2, y2);
			IF ~arc.closed THEN
				GetSucc(arc, dx, dy)
			ELSE
				IF arc.mode = wedge THEN pen.do.line(pen, x0, y0) END;
				pen.do.line(pen, p0.x, p0.y);
				dx := arc.dx0; dy := arc.dy0
			END;
			pen.do.exit(pen, dx, dy, arc.eoff)
		END
	END DrawArc;

	PROCEDURE DragArc (arc: Arc; ctxt: Gfx.Context);
		VAR p0, p1: Point; x0, y0, x1, y1, x2, y2: FLOAT32;
	BEGIN
		IF (arc.bottom # NIL) & (arc.bottom # arc.top) THEN
			p0 := arc.bottom(Point); p1 := arc.top(Point);
			IF arc.marked OR p0.marked OR p1.marked THEN
				x0 := arc.mat[2, 0]; y0 := arc.mat[2, 1];
				x1 := x0 - arc.mat[0, 0]; y1 := y0 - arc.mat[0, 1];
				x2 := x0 + arc.mat[1, 0]; y2 := y0 + arc.mat[1, 1];
				Gfx.Begin(ctxt, {Gfx.Stroke});
				Gfx.MoveTo(ctxt, p0.x, p0.y);
				Gfx.ArcTo(ctxt, p1.x, p1.y, x0, y0, x1, y1, x2, y2);
				IF arc.closed THEN
					IF arc.mode = wedge THEN Gfx.LineTo(ctxt, x0, y0) END;
					Gfx.LineTo(ctxt, p0.x, p0.y)
				END;
				Gfx.End(ctxt)
			END
		END
	END DragArc;

	PROCEDURE RenderArc (arc: Arc; VAR msg: Leonardo.RenderMsg);
		VAR state: Gfx.State; ctm, lgm: GfxMatrix.Matrix;
	BEGIN
		IF (arc.llx - arc.bw < msg.urx) & (msg.llx < arc.urx + arc.bw) & (arc.lly - arc.bw < msg.ury) & (msg.lly < arc.ury + arc.bw) THEN
			IF msg.id = Leonardo.marked THEN
				DragArc(arc, msg.ctxt)
			END;
			IF msg.id IN {Leonardo.active, Leonardo.passive} THEN
				Gfx.Save(msg.ctxt, Gfx.attr, state);
				arc.pen.do.begin(arc.pen, msg.ctxt);
				DrawArc(arc, arc.pen);
				arc.pen.do.end(arc.pen);
				Gfx.Restore(msg.ctxt, state)
			END;
			IF (msg.id IN {Leonardo.active, Leonardo.marksonly}) & arc.sel THEN
				ctm := msg.ctxt.ctm; Gfx.Concat(msg.ctxt, arc.mat);
				lgm := msg.lgm; GfxMatrix.Concat(arc.mat, lgm, msg.lgm);
				Leonardo.DrawHandles(-1, -1, 1, 1, msg);
				msg.lgm := lgm; Gfx.SetCTM(msg.ctxt, ctm)
			END;
			RenderSegment(arc, msg)
		END
	END RenderArc;

	PROCEDURE LocateArc (arc: Arc; VAR msg: Leonardo.LocateMsg);
		VAR res: Leonardo.Shape; px, py: FLOAT32;
	BEGIN
		IF (msg.llx <= arc.urx) & (arc.llx <= msg.urx) & (msg.lly <= arc.ury) & (arc.lly <= msg.ury) THEN
			IF msg.id = Leonardo.inside THEN
				IF (msg.llx <= arc.llx) & (arc.urx <= msg.urx) & (msg.lly <= arc.lly) & (arc.ury <= msg.ury) THEN
					arc.slink := msg.res; msg.res := arc
				ELSE
					Leonardo.ToComponents(arc.bottom, msg)
				END
			ELSE
				res := msg.res;
				Leonardo.ToComponents(arc.bottom, msg);
				IF msg.id = Leonardo.overlap THEN
					IF msg.res = res THEN
						ArcToPath(arc, ArcPath);
						GfxPaths.Apply(ArcPath, msg.lgm);
						GfxPaths.ProjectToPath(ArcPath, 0.5*(msg.llx + msg.urx), 0.5*(msg.lly + msg.ury), px, py);
						IF (msg.llx <= px) & (px <= msg.urx) & (msg.lly <= py) & (py <= msg.ury) THEN
							arc.slink := msg.res; msg.res := arc
						END
					ELSIF ~arc.sel THEN
						msg.res := arc; arc.slink := res
					END
				ELSIF (msg.id = Leonardo.project) & (msg.res = res) THEN
					ArcToPath(arc, ArcPath);
					GfxPaths.Apply(ArcPath, msg.lgm);
					GfxPaths.ProjectToPath(ArcPath, msg.x, msg.y, px, py);
					IF (msg.llx <= px) & (px <= msg.urx) & (msg.lly <= py) & (py <= msg.ury) THEN
						msg.res := arc; msg.px := px; msg.py := py
					END
				END
			END
		END
	END LocateArc;

	PROCEDURE TransformArc (arc: Arc; VAR msg: Leonardo.TransformMsg);
		VAR glm, m: GfxMatrix.Matrix; p: Point;

		PROCEDURE apply (p: Point);
			VAR x, y: FLOAT32;
		BEGIN
			IF msg.stamp # p.stamp THEN
				p.stamp := msg.stamp;
				GfxMatrix.Apply(msg.lgm, p.x, p.y, x, y);
				GfxMatrix.Apply(msg.mat, x, y, x, y);
				GfxMatrix.Solve(msg.lgm, x, y, x, y);
				x := x - arc.mat[2, 0]; y := y - arc.mat[2, 1];
				GfxPaths.ProjectToEllipse(-arc.mat[0, 0], -arc.mat[0, 1], arc.mat[1, 0], arc.mat[1, 1], x, y, x, y);
				Leonardo.SetReal(msg.fig, p, "X", x + arc.mat[2, 0]);
				Leonardo.SetReal(msg.fig, p, "Y",  y + arc.mat[2, 1]);
				IF p.link # NIL THEN
					msg.notify := TRUE
				END
			END
		END apply;

	BEGIN
		IF msg.id = Leonardo.apply THEN
			IF arc.marked & (msg.stamp # arc.stamp) THEN
				arc.stamp := msg.stamp;
				IF ~arc.bottom.marked THEN arc.bottom.marked := TRUE; msg.notify := TRUE END;
				IF ~arc.top.marked THEN arc.top.marked := TRUE; msg.notify := TRUE END;
				Leonardo.ToComponents(arc.bottom, msg);
				GfxMatrix.Invert(msg.lgm, glm);
				GfxMatrix.Concat(arc.mat, msg.lgm, m); GfxMatrix.Concat(m, msg.mat, m); GfxMatrix.Concat(m, glm, m);
				Leonardo.SetMatrix(msg.fig, arc, "M", m)
			END;
			IF arc.bottom.marked THEN
				apply(arc.bottom(Point));
				IF arc.pred # term THEN msg.notify := TRUE END
			END;
			IF arc.top.marked THEN
				apply(arc.top(Point));
				IF arc.succ # term THEN msg.notify := TRUE END
			END
		ELSIF msg.id = Leonardo.notify THEN
			p := arc.bottom(Point);
			IF ~p.marked & (p.link # NIL) & p.link.marked THEN
				Unlink(msg.fig, p)
			END;
			p := arc.top(Point);
			IF ~p.marked & (p.link # NIL) & p.link.marked THEN
				Unlink(msg.fig, p)
			END;
			TransformSegment(arc, msg)
		END
	END TransformArc;

	PROCEDURE GetArcMatrix (arc: Arc; VAR msg: Leonardo.MatrixMsg);
		VAR lgm: GfxMatrix.Matrix;
	BEGIN
		IF msg.dest = arc THEN
			lgm := msg.lgm; GfxMatrix.Concat(arc.mat, msg.lgm, msg.lgm);
			Leonardo.GetHandleMatrix(-1, -1, 1, 1, msg);
			msg.lgm := lgm
		END
	END GetArcMatrix;

	PROCEDURE ConnectArc (arc: Arc; VAR msg: ConnectMsg);
		VAR p0, p1: Point;
	BEGIN
		IF ~arc.closed & (arc.bottom # NIL) & (arc.bottom # arc.top) THEN
			p0 := arc.bottom(Point); p1 := arc.top(Point);
			IF msg.id = get THEN
				IF msg.pos = start THEN
					msg.mode := arc.pred; msg.x := p0.x; msg.y := p0.y; msg.dx := arc.dx0; msg.dy := arc.dy0
				ELSIF msg.pos = end THEN
					msg.mode := arc.succ; msg.x := p1.x; msg.y := p1.y; msg.dx := arc.dx1; msg.dy := arc.dy1
				END;
				msg.done := TRUE
			ELSIF msg.id = set THEN
				IF msg.pos = start THEN
					IF (msg.mode = term) OR (msg.mode MOD wrap = coincident) & (msg.x = p0.x) & (msg.y = p0.y) THEN
						IF msg.mode # arc.pred THEN
							ChangePred(msg.fig, arc, msg.mode)
						END;
						msg.done := TRUE
					END
				ELSIF msg.pos = end THEN
					IF (msg.mode = term) OR (msg.mode MOD wrap = coincident) & (msg.x = p1.x) & (msg.y = p1.y) THEN
						IF msg.mode # arc.succ THEN
							ChangeSucc(msg.fig, arc, msg.mode)
						END;
						msg.done := TRUE
					END
				END
			ELSIF msg.id = notify THEN
				IF (msg.pos = start) & (arc.pred # term) & (ABS(msg.x - p0.x) + ABS(msg.y - p0.y) > 1.0E-3) THEN
					msg.mode := term; msg.done := TRUE
				ELSIF (msg.pos = end) & (arc.succ # term) & (ABS(msg.x - p1.x) + ABS(msg.y - p1.y) > 1.0E-3) THEN
					msg.mode := term; msg.done := TRUE
				END
			END
		END
	END ConnectArc;

	PROCEDURE CopyArc* (VAR msg: Objects.CopyMsg; from, to: Arc);
	BEGIN
		CopySegment(msg, from, to);
		to.mode := from.mode; to.mat := from.mat;
		to.dx0 := from.dx0; to.dy0 := from.dy0; to.dx1 := from.dy1; to.dy1 := from.dy1
	END CopyArc;

	PROCEDURE HandleArc* (obj: Objects.Object; VAR msg: Objects.ObjMsg);
		VAR arc, copy: Arc; ver: SIGNED32;
	BEGIN
		arc := obj(Arc);
		IF msg IS Leonardo.ShapeMsg THEN
			IF msg IS Leonardo.ControlMsg THEN
				ControlArc(arc, msg(Leonardo.ControlMsg))
			ELSIF msg IS Leonardo.ValidateMsg THEN
				ValidateArc(arc, msg(Leonardo.ValidateMsg))
			ELSIF msg IS Leonardo.RenderMsg THEN
				RenderArc(arc, msg(Leonardo.RenderMsg))
			ELSIF msg IS Leonardo.LocateMsg THEN
				LocateArc(arc, msg(Leonardo.LocateMsg))
			ELSIF msg IS Leonardo.TransformMsg THEN
				TransformArc(arc, msg(Leonardo.TransformMsg))
			ELSIF msg IS Leonardo.MatrixMsg THEN
				GetArcMatrix(arc, msg(Leonardo.MatrixMsg))
			ELSIF msg IS RenderMsg THEN
				DrawArc(arc, msg(RenderMsg).pen)
			ELSIF msg IS ConnectMsg THEN
				ConnectArc(arc, msg(ConnectMsg))
			ELSE
				HandleSegment(arc,msg)
			END
		ELSIF msg IS Objects.AttrMsg THEN
			WITH msg: Objects.AttrMsg DO
				IF msg.id = Objects.enum THEN
					msg.Enum("Mode"); HandleSegment(arc, msg)
				ELSIF msg.id = Objects.get THEN
					IF msg.name = "Gen" THEN msg.class := Objects.String; msg.s := "LeoPaths.NewArcX"; msg.res := 0
					ELSIF msg.name = "Item" THEN msg.class := Objects.String; msg.s := "Arc"; msg.res := 0
					ELSIF msg.name = "Mode" THEN msg.class := Objects.Int; msg.i := arc.mode; msg.res := 0
					ELSIF msg.name = "M00" THEN msg.class := Objects.Real; msg.x := arc.mat[0, 0]; msg.res := 0
					ELSIF msg.name = "M01" THEN msg.class := Objects.Real; msg.x := arc.mat[0, 1]; msg.res := 0
					ELSIF msg.name = "M10" THEN msg.class := Objects.Real; msg.x := arc.mat[1, 0]; msg.res := 0
					ELSIF msg.name = "M11" THEN msg.class := Objects.Real; msg.x := arc.mat[1, 1]; msg.res := 0
					ELSIF msg.name = "M20" THEN msg.class := Objects.Real; msg.x := arc.mat[2, 0]; msg.res := 0
					ELSIF msg.name = "M21" THEN msg.class := Objects.Real; msg.x := arc.mat[2, 1]; msg.res := 0
					ELSE HandleSegment(arc, msg)
					END
				ELSIF msg.id = Objects.set THEN
					IF msg.name = "Mode" THEN
						IF (msg.class = Objects.Int) & (wedge <= msg.i) & (msg.i <= segment) THEN
							arc.mode := SHORT(SHORT(msg.i)); msg.res := 0
						END
					ELSIF msg.name = "M00" THEN
						IF msg.class = Objects.Real THEN arc.mat[0, 0] := msg.x; msg.res := 0 END
					ELSIF msg.name = "M01" THEN
						IF msg.class = Objects.Real THEN arc.mat[0, 1] := msg.x; msg.res := 0 END
					ELSIF msg.name = "M10" THEN
						IF msg.class = Objects.Real THEN arc.mat[1, 0] := msg.x; msg.res := 0 END
					ELSIF msg.name = "M11" THEN
						IF msg.class = Objects.Real THEN arc.mat[1, 1] := msg.x; msg.res := 0 END
					ELSIF msg.name = "M20" THEN
						IF msg.class = Objects.Real THEN arc.mat[2, 0] := msg.x; msg.res := 0 END
					ELSIF msg.name = "M21" THEN
						IF msg.class = Objects.Real THEN arc.mat[2, 1] := msg.x; msg.res := 0 END
					ELSE
						HandleSegment(arc, msg)
					END
				END
			END
		ELSIF msg IS Objects.CopyMsg THEN
			WITH msg: Objects.CopyMsg DO
				IF msg.stamp # arc.stamp THEN
					NEW(copy); arc.dlink := copy; arc.stamp := msg.stamp;
					CopyArc(msg, arc, copy)
				END;
				msg.obj := arc.dlink
			END
		ELSIF msg IS Objects.FileMsg THEN
			WITH msg: Objects.FileMsg DO
				HandleSegment(arc, msg);
				IF msg.id = Objects.store THEN
					Files.WriteNum(msg.R, 1);
					Files.Write(msg.R, arc.mode);
					GfxMatrix.Write(msg.R, arc.mat)
				ELSIF msg.id = Objects.load THEN
					Files.ReadNum(msg.R, ver);
					Files.Read(msg.R, arc.mode);
					GfxMatrix.Read(msg.R, arc.mat);
					CalcArcBox(arc, GfxMatrix.Identity)
				END
			END
		ELSE
			HandleSegment(arc, msg)
		END
	END HandleArc;

	PROCEDURE InitArc* (arc: Arc; x, y, rx, ry, start, end: FLOAT32; pen: LeoPens.Pen);
		VAR p0, p1: Point;
	BEGIN
		NEW(p0); InitPoint(p0, x + rx * Math.cos(start), y + ry * Math.sin(start));
		NEW(p1); InitPoint(p1, x + rx * Math.cos(end), y + ry * Math.sin(end));
		p0.up := p1; p1.down := p0;
		InitSegment(arc, HandleArc, p0, p1, start = end, pen);
		GfxMatrix.Init(arc.mat, rx, 0, 0, ry, x, y);
		arc.mode := segment;
		CalcArcBox(arc, GfxMatrix.Identity)
	END InitArc;

	PROCEDURE NewArcX*;
		VAR arc: Arc;
	BEGIN
		NEW(arc); InitArc(arc, 0, 0, 1, 1, 0, 0, LeoPens.Default);
		Objects.NewObj := arc
	END NewArcX;


	(**--- Pathification ---**)

	PROCEDURE HandlePathifier* (obj: Objects.Object; VAR msg: Objects.ObjMsg);
		VAR pen, copy: Pathifier; ver: SIGNED32;
	BEGIN
		pen := obj(Pathifier);
		IF msg IS Objects.AttrMsg THEN
			WITH msg: Objects.AttrMsg DO
				IF (msg.id = Objects.get) & (msg.name = "Gen") THEN
					msg.class := Objects.String; msg.s := "LeoPaths.NewPathifier"; msg.res := 0
				ELSE
					LeoPens.Handle(pen, msg)
				END
			END
		ELSIF msg IS Objects.CopyMsg THEN
			WITH msg: Objects.CopyMsg DO
				IF msg.stamp # pen.stamp THEN
					NEW(copy); pen.dlink := copy; pen.stamp := msg.stamp;
					LeoPens.Copy(msg, pen, copy)
				END;
				msg.obj := pen.dlink
			END
		ELSIF msg IS Objects.FileMsg THEN
			WITH msg: Objects.FileMsg DO
				LeoPens.Handle(pen, msg);
				IF msg.id = Objects.store THEN
					Files.WriteNum(msg.R, 1)
				ELSIF msg.id = Objects.load THEN
					Files.ReadNum(msg.R, ver)
				END
			END
		ELSE
			LeoPens.Handle(pen, msg)
		END
	END HandlePathifier;

	PROCEDURE InitPathifier* (pen: Pathifier);
	BEGIN
		pen.handle := HandlePathifier; pen.do := PathifierMethods;
		pen.destructive := FALSE; pen.needDist := FALSE; pen.zeroDistOnly := FALSE
	END InitPathifier;

	PROCEDURE NewPathifier*;
		VAR pen: Pathifier;
	BEGIN
		NEW(pen); InitPathifier(pen);
		Objects.NewObj := pen
	END NewPathifier;

	PROCEDURE BeginPathifier (pen: LeoPens.Pen; ctxt: Gfx.Context);
		VAR pp: Pathifier;
	BEGIN
		pp := pen(Pathifier);
		LeoPens.Begin(pp, ctxt);
		pp.bot := NIL; pp.top := NIL; pp.elem := GfxPaths.Stop
	END BeginPathifier;

	PROCEDURE EnterPathifier (pen: LeoPens.Pen; x, y, dx, dy, bdist: FLOAT32);
		VAR pp: Pathifier;
	BEGIN
		pp := pen(Pathifier);
		pp.x0 := x; pp.y0 := y; pp.x := x; pp.y := y; pp.elem := GfxPaths.Enter; pp.enter := NIL
	END EnterPathifier;

	PROCEDURE ExitPathifier (pen: LeoPens.Pen; dx, dy, dist: FLOAT32);
		VAR pp: Pathifier;
	BEGIN
		pp := pen(Pathifier);
		IF (pp.enter # NIL) & ((dx # 0) OR (dy # 0)) & (pp.x = pp.x0) & (pp.y = pp.y0) THEN
			IF pp.top = pp.enter THEN
				pp.enter.top := pp.enter.top.down; pp.enter.top.up := NIL;
				pp.enter.closed := TRUE
			ELSE
				pp.enter.pred := coincident + wrap; pp.top.succ := coincident + wrap
			END
		END;
		pp.elem := GfxPaths.Exit
	END ExitPathifier;

	PROCEDURE PathifyLine (pen: LeoPens.Pen; x, y: FLOAT32);
		VAR pp: Pathifier; seg: Segment; p, q: Point;
	BEGIN
		pp := pen(Pathifier);
		IF pp.elem = GfxPaths.Line THEN	(* append to current polyline *)
			seg := pp.top;
			NEW(p); InitPoint(p, x, y); p.cont := seg;
			p.down := seg.top; seg.top.up := p; seg.top := p
		ELSE
			NEW(p); InitPoint(p, pp.x, pp.y);
			NEW(q); InitPoint(q, x, y);
			p.up := q; q.down := p;
			NEW(seg); InitPolyline(seg, p, q, FALSE, LeoPens.Default); seg.marked := TRUE;
			IF pp.bot = NIL THEN
				pp.bot := seg
			ELSE
				pp.top.up := seg;
				IF pp.enter = NIL THEN pp.enter := seg
				ELSE pp.top.succ := coincident; seg.pred := coincident
				END
			END;
			seg.down := pp.top; pp.top := seg
		END;
		pp.x := x; pp.y := y; pp.elem := GfxPaths.Line
	END PathifyLine;

	PROCEDURE PathifyArc (pen: LeoPens.Pen; x, y, x0, y0, x1, y1, x2, y2: FLOAT32);
		VAR pp: Pathifier; p0, p1: Point; arc: Arc;
	BEGIN
		pp := pen(Pathifier);
		NEW(p0); InitPoint(p0, pp.x, pp.y);
		NEW(p1); InitPoint(p1, x, y);
		p0.up := p1; p1.down := p0;
		NEW(arc); InitSegment(arc, HandleArc, p0, p1, FALSE, LeoPens.Default); arc.marked := TRUE;
		GfxMatrix.Init(arc.mat, x1 - x0, x2 - x0, y1 - y0, y2 - y0, x0, y0);
		CalcArcBox(arc, GfxMatrix.Identity);
		IF pp.bot = NIL THEN
			pp.bot := arc
		ELSE
			pp.top.up := arc;
			IF pp.enter = NIL THEN pp.enter := arc
			ELSE pp.top.succ := coincident; arc.pred := coincident
			END
		END;
		arc.down := pp.top; pp.top := arc;
		pp.x := x; pp.y := y; pp.elem := GfxPaths.Arc
	END PathifyArc;

	PROCEDURE PathifyBezier (pen: LeoPens.Pen; x, y, x1, y1, x2, y2: FLOAT32);
		VAR pp: Pathifier; p0, p1, p2, p: Point; seg: Segment;
	BEGIN
		pp := pen(Pathifier);
		NEW(p0); InitPoint(p0, pp.x, pp.y);
		NEW(p1); InitPoint(p1, x1, y1);
		NEW(p2); InitPoint(p2, x2, y2);
		NEW(p); InitPoint(p, x, y);
		p0.up := p1; p1.down := p0; p1.up := p2; p2.down := p1; p2.up := p; p.down := p2;
		NEW(seg); InitBezier(seg, p0, p, FALSE, LeoPens.Default); seg.marked := TRUE;
		IF pp.bot = NIL THEN
			pp.bot := seg
		ELSE
			pp.top.up := seg;
			IF pp.enter = NIL THEN pp.enter := seg
			ELSE pp.top.succ := coincident; seg.pred := coincident
			END
		END;
		seg.down := pp.top; pp.top := seg;
		pp.x := x; pp.y := y; pp.elem := GfxPaths.Bezier
	END PathifyBezier;

	PROCEDURE InitPathifiers;
	BEGIN
		NEW(PathifierMethods);
		PathifierMethods.begin := BeginPathifier; PathifierMethods.end := LeoPens.End;
		PathifierMethods.enter := EnterPathifier; PathifierMethods.exit := ExitPathifier;
		PathifierMethods.line := PathifyLine; PathifierMethods.arc := PathifyArc; PathifierMethods.bezier := PathifyBezier;
		PathifierMethods.render := LeoPens.RenderPath
	END InitPathifiers;

	PROCEDURE Realize* (path: Path);
		VAR fig: Leonardo.Figure; pen: Pathifier; rm: RenderMsg; cur, down: Leonardo.Shape;
	BEGIN
		fig := Leonardo.ContainingFigure(path);
		Leonardo.DisableUpdate(fig); Leonardo.BeginCommand(fig);
		NEW(pen); InitPathifier(pen);
		Objects.Stamp(rm); rm.fig := fig; rm.pen := pen;
		cur := path.bottom; down := NIL;
		WHILE cur # NIL DO
			IF cur IS Segment THEN
				down := cur
			ELSE
				pen.do.begin(pen, NIL);
				cur.handle(cur, rm);
				pen.do.end(pen);
				Leonardo.AddDeleteAction(fig, down, cur, cur, cur.up, path);
				Leonardo.AddConsumeAction(fig, down, pen.bot, pen.top, cur.up, path);
				down := pen.top
			END;
			cur := cur.up
		END;
		Leonardo.EndCommand(fig); Leonardo.EnableUpdate(fig)
	END Realize;


	(**--- Legacy Code ---**)

	PROCEDURE NewPolygon*;
	BEGIN
		Objects.NewObj := Gadgets.CreateObject("LeoCurves.NewPolygon")
	END NewPolygon;

	PROCEDURE NewArc*;
	BEGIN
		Objects.NewObj := Gadgets.CreateObject("LeoCurves.NewArc")
	END NewArc;

	PROCEDURE NewBezier*;
	BEGIN
		Objects.NewObj := Gadgets.CreateObject("LeoCurves.NewBezier")
	END NewBezier;

	PROCEDURE NewSpline*;
	BEGIN
		Objects.NewObj := Gadgets.CreateObject("LeoSplines.NewSpline")
	END NewSpline;

	PROCEDURE ReadLegacyCurves (VAR r: Files.Rider; path: Path);
		VAR
			n, i, succ, pred, j, m: SIGNED32; key: SIGNED16; name: ARRAY 64 OF CHAR; obj: Objects.Object;
			cv: ARRAY 64 OF Segment; last: ARRAY 64 OF SIGNED32; p: Leonardo.Shape;
			curve: Segment; cm: Objects.CopyMsg;
	BEGIN
		Files.ReadNum(r, n);
		i := 0;
		WHILE i < n DO
			Files.ReadInt(r, key);
			Objects.GetName(path.lib.dict, key, name);
			IF (name = "LeoPaths.InitArcClass") OR (name = "LeoPaths.NewArcClass") THEN
				obj := Gadgets.CreateObject("LeoPaths.NewArc")
			ELSIF (name = "LeoPaths.InitBezierClass") OR (name = "LeoPaths.NewBezierClass") THEN
				obj := Gadgets.CreateObject("LeoPaths.NewBezier")
			ELSIF (name = "LeoPaths.InitSplineClass") OR (name = "LeoPaths.NewSplineClass") THEN
				obj := Gadgets.CreateObject("LeoPaths.NewSpline")
			ELSE
				obj := Gadgets.CreateObject("LeoPaths.NewPolygon")
			END;
			IF (obj # NIL) & (obj IS Segment) THEN
				cv[i] := obj(Segment)
			END;
			Gadgets.ReadRef(r, path.lib, obj);
			IF (cv[i] # NIL) & (obj # NIL) & (obj IS LeoPens.Pen) THEN
				cv[i].pen := obj(LeoPens.Pen)
			END;
			Files.ReadNum(r, succ); Files.ReadNum(r, pred);	(* successor and predecessor currently unused *)
			Files.ReadNum(r, last[i]);
			INC(i)
		END;

		p := path.bottom;
		i := 0; WHILE (i < n) & (cv[i] = NIL) DO INC(i) END;
		path.bottom := cv[i]; path.top := cv[i];
		WHILE i < n DO
			j := i+1; WHILE (j < n) & (cv[j] = NIL) DO INC(j) END;
			IF j < n THEN
				cv[i].up := cv[j]; cv[j].down := cv[i];
				path.top := cv[j]
			END;
			i := j
		END;

		i := 0; m := 0;
		WHILE i < n DO
			curve := cv[i];
			IF curve # NIL THEN
				curve.bottom := p; p.down := NIL
			END;
			WHILE m < last[i] DO p := p.up; INC(m) END;
			IF curve # NIL THEN
				curve.top := p; p := p.up; curve.top.up := NIL;
				IF p # NIL THEN	(* copy shared point *)
					Objects.Stamp(cm); cm.id := Objects.shallow; cm.obj := curve.top; curve.top.handle(curve.top, cm);
					cm.obj(Leonardo.Shape).up := p; p := cm.obj(Leonardo.Shape)
				END;
				Leonardo.GetComponentsBox(curve.bottom, curve.llx, curve.lly, curve.urx, curve.ury, curve.bw)
			END;
			INC(i)
		END
	END ReadLegacyCurves;

	PROCEDURE HandleLegacyPath (obj: Objects.Object; VAR msg: Objects.ObjMsg);
		VAR path: Path; ver: SIGNED32; i: SIGNED16; real: FLOAT32; cm: Objects.CopyMsg; s: Leonardo.Shape; bool: BOOLEAN;
	BEGIN
		IF msg IS Objects.FileMsg THEN
			WITH msg: Objects.FileMsg DO
				ASSERT(msg.id = Objects.load, 110);
				path := obj(Path);

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
					Gadgets.ReadRef(msg.R, path.lib, obj);
					IF (obj # NIL) & (obj IS Leonardo.Shape) THEN
						Objects.Stamp(cm); cm.id := Objects.shallow; cm.obj := obj; obj.handle(obj, cm);
						s := cm.obj(Leonardo.Shape); s.cont := path;
						IF path.bottom = NIL THEN path.bottom := s ELSE path.top.up := s END;
						s.down := path.top; path.top := s
					END
				UNTIL obj = NIL;
				IF ver = 1 THEN
					Files.ReadBool(msg.R, bool)
				END;
				Leonardo.GetComponentsBox(path.bottom, path.llx, path.lly, path.urx, path.ury, path.bw);

				(* area part *)
				Files.ReadNum(msg.R, ver);
				ASSERT(ver IN {1, 2}, 113);
				Gadgets.ReadRef(msg.R, path.lib, obj);
				IF (obj # NIL) & (obj IS LeoPens.Pen) THEN
					path.pen := obj(LeoPens.Pen)
				END;
				IF ver = 1 THEN
					ReadLegacyCurves(msg.R, path)
				END;

				path.handle := HandlePath
			END
		ELSE
			HandlePath(obj, msg)
		END
	END HandleLegacyPath;

	PROCEDURE NewPath*;
		VAR path: Path;
	BEGIN
		NEW(path); path.handle := HandleLegacyPath; path.pen := LeoPens.Default;
		Objects.NewObj := path
	END NewPath;


BEGIN
	InitPointImages;
	NEW(Rec); LeoPens.InitRecorder(Rec);
	NEW(ArcPath);
	InitPathifiers
END LeoPaths.
