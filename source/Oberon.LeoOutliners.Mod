(* ETH Oberon, Copyright 2001 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

MODULE LeoOutliners IN Oberon; (** portable **)	(* eos  *)

	(**
		Leonardo outline pens (for arrows and effects)
	**)

	IMPORT
		Files, Math IN A2, Objects, Gadgets, GfxMatrix, GfxPaths, Gfx, LeoPens;


	CONST
		outlined* = 0; inverted* = 1; parallel* = 2; left* = 3; right* = 4;	(** outline modes **)
		forwards* = 0; both* = 1; backwards* = 2;	(** arrow directions **)


	TYPE
		Outliner* = POINTER TO OutlinerDesc;
		OutlinerDesc* = RECORD (LeoPens.WidePenDesc)
			base*: LeoPens.Pen;	(** pen for rendering outline **)
			mode*: SIGNED8;	(** outline mode **)
		END;

		Arrow* = POINTER TO ArrowDesc;
		ArrowDesc* = RECORD (OutlinerDesc)
			dir*: SIGNED8;	(** arrow direction **)
			len*: FLOAT32;	(** arrow length **)
			coff*, cdist*: FLOAT32;	(** corner offset and distance **)
			bdist, edist, length: LeoPens.DistArray;
			n: SIGNED32;
		END;


	VAR
		OutlinerMethods, ArrowMethods: LeoPens.Methods;
		Split: ARRAY 3 OF FLOAT32;


	(*--- Auxiliaries ---*)

	PROCEDURE GetHalfAxisVector (dxi, dyi, dxo, dyo: FLOAT32; VAR hx, hy: FLOAT32);
	BEGIN
		Gfx.GetHalfAxisVector(dxi, dyi, dxo, dyo, hx, hy);
		IF (hx = 0) & (hy = 0) THEN hx := dyo; hy := -dxo	(* collinear vectors *)
		ELSIF dxi * dyo < dyi * dxo THEN hx := -hx; hy := -hy	(* ensure h points to the right *)
		END
	END GetHalfAxisVector;

	PROCEDURE Enter (pen: Outliner; w, x, y, dxi, dyi, dxo, dyo, tan: FLOAT32);
		CONST eps = 1.0E-3;
		VAR base: LeoPens.Pen; aw, hx, hy, ix, iy, t, dx, dy: FLOAT32;
	BEGIN
		base := pen.base;
		aw := ABS(w);
		IF (dxi = 0) & (dyi = 0) THEN	(* no adjacent curve *)
			IF aw < eps THEN	(* probably arrow peak *)
				base.do.enter(base, x, y, -(dxo - tan * dyo), -(dyo + tan * dxo), 0)
			ELSE
				hx := w * dyo; hy := -w * dxo;
				dxo := aw * dxo; dyo := aw * dyo;
				IF pen.capstyle = Gfx.ButtCap THEN
					base.do.enter(base, x, y, hx, hy, 0);
					base.do.line(base, x + hx, y + hy)
				ELSIF pen.capstyle = Gfx.SquareCap THEN
					base.do.enter(base, x - dxo, y - dyo, hx, hy, 0);
					base.do.line(base, x - dxo + hx, y - dyo + hy);
					base.do.line(base, x + hx, y + hy)
				ELSIF pen.capstyle = Gfx.RoundCap THEN
					base.do.enter(base, x - dxo, y - dyo, hx, hy, 0);
					base.do.arc(base, x + hx, y + hy, x, y, x - dxo, y - dyo, x + hx, y + hy)
				ELSE
					base.do.enter(base, x + hx, y + hy, 0, 0, 0)
				END
			END
		ELSE
			GetHalfAxisVector(dxi, dyi, dxo, dyo, hx, hy);
			IF (dxi * dyo - dyi * dxo) * w <= 0 THEN	(* inner corner *)
				base.do.enter(base, x + w * hx, y + w * hy, dxi, dyi, 0)
			ELSIF (pen.joinstyle = Gfx.BevelJoin) OR (pen.joinstyle = Gfx.MiterJoin) & (hx * hx + hy * hy > pen.limit * pen.limit) THEN
				GfxPaths.IntersectLines(x, y, hx, hy, x + w * dyo, y - w * dxo, -hy, hx, ix, iy);
				base.do.enter(base, ix, iy, -w * hy, w * hx, 0);
				base.do.line(base, x + w * dyo, y - w * dxo)
			ELSIF pen.joinstyle = Gfx.MiterJoin THEN
				base.do.enter(base, x + w * hx, y + w * hy, dxi, dyi, 0)
			ELSIF pen.joinstyle = Gfx.RoundJoin THEN
				t := w * Math.sqrt(1/(hx * hx + hy * hy)); tan := w/aw * tan;
				base.do.enter(base, x + t * hx, y + t * hy, -w * hy, w * hx, 0);
				IF ABS(tan) < eps THEN
					base.do.arc(base, x + w * dyo, y - w * dxo, x, y, x - aw * dxo, y - aw * dyo, x + w * dyo, y - w * dxo)
				ELSE
					t := w/Math.sqrt(1 + tan*tan);
					dx := t * (dxo + tan * dyo); dy := t * (dyo - tan * dxo);	(* effective contour direction *)
					IF hx * dx + hy * dy <= 0 THEN
						base.do.arc(base, x + dy, y - dx, x, y, x - aw * dxo, y - aw * dyo, x + w * dyo, y - w * dxo)
					END
				END
			ELSE
				base.do.enter(base, x + w * dyo, y - w * dxo, 0, 0, 0)
			END
		END
	END Enter;

	PROCEDURE Join (pen: Outliner; w, x, y, dxi, dyi, dxo, dyo, tani, tano: FLOAT32);
		CONST eps = 1.0E-3;
		VAR base: LeoPens.Pen; t, dx, dy, hx, hy, aw: FLOAT32;
	BEGIN
		base := pen.base;
		IF w < 0 THEN tani := -tani; tano := -tano END;
		GetHalfAxisVector(dxi, dyi, dxo, dyo, hx, hy);
		IF ABS(tani) >= eps THEN	(* get effective directions *)
			t := 1/Math.sqrt(1 + tani*tani);
			dx := t * (dxi + tani * dyi); dy := t * (dyi - tani * dxi);
			dxi := dx; dyi := dy;
			dx := t * (dxo + tano * dyo); dy := t * (dyo - tano * dxo);
			dxo := dx; dyo := dy
		END;
		IF (dxi * dyo - dyi * dxo) * w <= 0 THEN	(* inner corner *)
			base.do.line(base, x + w * hx, y + w * hy)
		ELSIF (pen.joinstyle = Gfx.BevelJoin) OR (pen.joinstyle = Gfx.MiterJoin) & (hx * hx + hy * hy > pen.limit * pen.limit) THEN
			base.do.line(base, x + w * dyi, y - w * dxi);
			base.do.line(base, x + w * dyo, y - w * dxo)
		ELSIF pen.joinstyle = Gfx.MiterJoin THEN
			base.do.line(base, x + w * hx, y + w * hy)
		ELSIF pen.joinstyle = Gfx.RoundJoin THEN
			aw := ABS(w);
			base.do.line(base, x + w * dyi, y - w * dxi);
			base.do.arc(base, x + w * dyo, y - w * dxo, x, y, x + w * dyi, y - w * dxi, x + aw * dxi, y + aw * dyi)
		ELSE
			base.do.line(base, x + w * dyi, y - w * dxi); base.do.exit(base, 0, 0, 0);
			base.do.enter(base, x + w * dyo, y - w * dxo, 0, 0, 0)
		END
	END Join;

	PROCEDURE Exit (pen: Outliner; w, x, y, dxi, dyi, dxo, dyo, tan: FLOAT32);
		CONST eps = 1.0E-3;
		VAR base: LeoPens.Pen; aw, hx, hy, ix, iy, t, dx, dy: FLOAT32;
	BEGIN
		base := pen.base;
		aw := ABS(w);
		IF (dxo = 0) & (dyo = 0) THEN
			IF aw < eps THEN
				base.do.line(base, x, y);
				base.do.exit(base, -dxi - tan * dyi, -dyi + tan * dxi, 0)
			ELSE
				hx := w * dyi; hy := -w * dxi;
				dxi := aw * dxi; dyi := aw * dyi;
				base.do.line(base, x + hx, y + hy);
				IF pen.capstyle = Gfx.ButtCap THEN
					base.do.line(base, x, y);
					base.do.exit(base, -hx, -hy, 0)
				ELSIF pen.capstyle = Gfx.SquareCap THEN
					base.do.line(base, x + dxi + hx, y + dyi + hy); base.do.line(base, x + dxi, y + dyi);
					base.do.exit(base, -hx, -hy, 0)
				ELSIF pen.capstyle = Gfx.RoundCap THEN
					base.do.arc(base, x + dxi, y + dyi, x, y, x + hx, y + hy, x + dxi, y + dyi);
					base.do.exit(base, -hx, -hy, 0)
				ELSE
					base.do.exit(base, 0, 0, 0)
				END
			END
		ELSE
			GetHalfAxisVector(dxi, dyi, dxo, dyo, hx, hy);
			IF (dxi * dyo - dyi * dxo) * w <= 0 THEN	(* inner corner *)
				base.do.line(base, x + w * hx, y + w * hy);
				base.do.exit(base, dxo, dyo, 0)
			ELSIF (pen.joinstyle = Gfx.BevelJoin) OR (pen.joinstyle = Gfx.MiterJoin) & (hx * hx + hy * hy > pen.limit * pen.limit) THEN
				base.do.line(base, x + w * dyi, y - w * dxi);
				GfxPaths.IntersectLines(x, y, hx, hy, x + w * dyi, y - w * dxi, -hy, hx, ix, iy);
				base.do.line(base, ix, iy);
				base.do.exit(base, -w * hy, w * hx, 0)
			ELSIF pen.joinstyle = Gfx.MiterJoin THEN
				base.do.line(base, x + w * hx, y + w * hy);
				base.do.exit(base, dxo, dyo, 0)
			ELSIF pen.joinstyle = Gfx.RoundJoin THEN
				t := w * Math.sqrt(1/(hx * hx + hy * hy)); tan := w/aw * tan;
				IF ABS(tan) < eps THEN
					base.do.line(base, x + w * dyi, y - w * dxi);
					base.do.arc(base, x + t * hx, y + t * hy, x, y, x + w * dyi, y - w * dxi, x + aw * dxi, y + aw * dyi)
				ELSE
					t := w/Math.sqrt(1 + tan*tan);
					dx := t * (dxi + tan * dyi); dy := t * (dyi - tan * dxi);	(* effective contour direction *)
					IF hx * dx + hy * dy >= 0 THEN
						base.do.line(base, x + dy, y - dx);
						base.do.arc(base, x + t * hx, y + t * hy, x, y, x - aw * dxi, y - aw * dyi, x + w * dyi, y - w * dxi)
					ELSE
						base.do.line(base, x + t * hx, y + t * hy)
					END
				END;
				base.do.exit(base, -w * hy, w * hx, 0)
			ELSE
				base.do.line(base, x + w * dyi, y - w * dxi);
				base.do.exit(base, 0, 0, 0)
			END
		END
	END Exit;


	(**--- Outliners ---**)

	PROCEDURE CopyOutliner* (VAR msg: Objects.CopyMsg; from, to: Outliner);
		VAR obj: Objects.Object;
	BEGIN
		LeoPens.CopyWidePen(msg, from, to);
		obj := Gadgets.CopyPtr(msg, from.base);
		IF (obj = NIL) OR ~(obj IS LeoPens.Pen) THEN obj := Gadgets.CreateObject("LeoPens.NewStroker") END;
		to.base := obj(LeoPens.Pen); to.mode := from.mode
	END CopyOutliner;

	PROCEDURE HandleOutliner* (obj: Objects.Object; VAR msg: Objects.ObjMsg);
		VAR pen, copy: Outliner; ver: SIGNED32;
	BEGIN
		pen := obj(Outliner);
		IF msg IS LeoPens.UpdateMsg THEN
			IF msg(LeoPens.UpdateMsg).pen = pen.base THEN
				LeoPens.Update(pen)
			END
		ELSIF msg IS Objects.AttrMsg THEN
			WITH msg: Objects.AttrMsg DO
				IF msg.id = Objects.enum THEN
					msg.Enum("Mode"); LeoPens.WidePenAttr(pen, msg)
				ELSIF msg.id = Objects.get THEN
					IF msg.name = "Gen" THEN msg.class := Objects.String; msg.s := "LeoOutliners.NewOutliner"; msg.res := 0
					ELSIF msg.name = "Item" THEN msg.class := Objects.String; msg.s := "Outliner"; msg.res := 0
					ELSIF msg.name = "Mode" THEN msg.class := Objects.Int; msg.i := pen.mode; msg.res := 0
					ELSE LeoPens.WidePenAttr(pen, msg)
					END
				ELSIF msg.id = Objects.set THEN
					IF msg.name = "Mode" THEN
						IF (msg.class = Objects.Int) & (outlined <= msg.i) & (msg.i <= right) THEN
							pen.mode := SHORT(SHORT(msg.i)); msg.res := 0
						END
					ELSE
						LeoPens.WidePenAttr(pen, msg)
					END
				END
			END
		ELSIF msg IS Objects.LinkMsg THEN
			WITH msg: Objects.LinkMsg DO
				IF msg.id = Objects.enum THEN
					msg.Enum("Base")
				ELSIF msg.id = Objects.get THEN
					IF msg.name = "Base" THEN msg.obj := pen.base; msg.res := 0 END
				ELSIF msg.id = Objects.set THEN
					IF msg.name = "Base" THEN
						IF (msg.obj # NIL) & (msg.obj IS LeoPens.Pen) THEN
							pen.base := msg.obj(LeoPens.Pen); msg.res := 0;
							pen.zeroDistOnly := pen.base.zeroDistOnly OR pen.base.needDist
						END
					END
				END
			END
		ELSIF msg IS Objects.CopyMsg THEN
			WITH msg: Objects.CopyMsg DO
				IF msg.stamp # pen.stamp THEN
					NEW(copy); pen.dlink := copy; pen.stamp := msg.stamp;
					CopyOutliner(msg, pen, copy)
				END;
				msg.obj := pen.dlink
			END
		ELSIF msg IS Objects.BindMsg THEN
			pen.base.handle(pen.base, msg);
			LeoPens.Handle(pen, msg)
		ELSIF msg IS Objects.FileMsg THEN
			WITH msg: Objects.FileMsg DO
				IF msg.id = Objects.store THEN
					Files.WriteNum(msg.R, 1);
					Gadgets.WriteRef(msg.R, pen.lib, pen.base);
					LeoPens.WriteWidePen(pen, msg.R);
					Files.Write(msg.R, pen.mode)
				ELSIF msg.id = Objects.load THEN
					Files.ReadNum(msg.R, ver);
					Gadgets.ReadRef(msg.R, pen.lib, obj);
					IF (obj = NIL) OR ~(obj IS LeoPens.Pen) THEN obj := Gadgets.CreateObject("LeoPens.NewStroker") END;
					pen.base := obj(LeoPens.Pen);
					pen.zeroDistOnly := pen.base.zeroDistOnly OR pen.base.needDist;
					LeoPens.ReadWidePen(pen, msg.R);
					Files.Read(msg.R, pen.mode)
				END
			END
		ELSE
			LeoPens.Handle(pen, msg)
		END
	END HandleOutliner;

	PROCEDURE InitOutliner* (pen: Outliner; base: LeoPens.Pen; width: FLOAT32; mode: SIGNED8);
	BEGIN
		ASSERT(base # NIL, 100);
		ASSERT((outlined <= mode) & (mode <= right), 101);
		pen.handle := HandleOutliner; pen.do := OutlinerMethods;
		pen.destructive := TRUE; pen.needDist := FALSE; pen.zeroDistOnly := base.zeroDistOnly OR base.needDist;
		pen.base := base; pen.mode := mode;
		pen.width := ABS(width); pen.limit := 5; pen.capstyle := Gfx.DefaultCap; pen.joinstyle := Gfx.DefaultJoin
	END InitOutliner;

	PROCEDURE NewOutliner*;
		VAR pen: Outliner;
	BEGIN
		NEW(pen); InitOutliner(pen, LeoPens.Default, 10, outlined);
		Objects.NewObj := pen
	END NewOutliner;

	PROCEDURE DrawOutline (pen: Outliner; w: FLOAT32; path: GfxPaths.Path);
		VAR base: LeoPens.Pen; s: GfxPaths.Scanner; sx, sy, dx0, dy0, dx1, dy1: FLOAT32;
	BEGIN
		base := pen.base;
		GfxPaths.Open(s, path, 0);
		WHILE s.elem = GfxPaths.Enter DO
			sx := s.x; sy := s.y;
			IF (s.dx = 0) & (s.dy = 0) THEN dx0 := 0; dy0 := 0
			ELSE Gfx.GetNormVector(s.dx, s.dy, 1, dx0, dy0)
			END;
			GfxPaths.Scan(s);
			IF s.elem = GfxPaths.Line THEN
				Gfx.GetNormVector(s.x - sx, s.y - sy, 1, dx1, dy1);
				Enter(pen, w, sx, sy, dx0, dy0, dx1, dy1, 0);
				sx := s.x; sy := s.y;
				GfxPaths.Scan(s);
				WHILE s.elem = GfxPaths.Line DO
					dx0 := dx1; dy0 := dy1;
					Gfx.GetNormVector(s.x - sx, s.y - sy, 1, dx1, dy1);
					Join(pen, w, sx, sy, dx0, dy0, dx1, dy1, 0, 0);
					sx := s.x; sy := s.y;
					GfxPaths.Scan(s)
				END;
				IF s.elem = GfxPaths.Exit THEN
					IF (s.dx = 0) & (s.dy = 0) THEN dx0 := 0; dy0 := 0
					ELSE Gfx.GetNormVector(s.dx, s.dy, 1, dx0, dy0)
					END;
					Exit(pen, w, sx, sy, dx1, dy1, dx0, dy0, 0);
					GfxPaths.Scan(s)
				END
			END
		END
	END DrawOutline;

	PROCEDURE OutlinePath (pen: Outliner; ctxt: Gfx.Context);
		VAR inv: GfxMatrix.Matrix; path, tmp: GfxPaths.Path;
	BEGIN
		Gfx.Flatten(ctxt);
		GfxMatrix.Invert(ctxt.ctm, inv); GfxPaths.Apply(ctxt.path, inv);
		IF pen.base.destructive THEN LeoPens.GetTempPath(path); GfxPaths.Copy(ctxt.path, path)
		ELSE path := ctxt.path
		END;
		pen.base.do.begin(pen.base, ctxt);
		IF pen.mode IN {outlined, parallel, right} THEN
			DrawOutline(pen, 0.5*pen.width, path)
		END;
		IF pen.mode IN {inverted, parallel, left} THEN
			DrawOutline(pen, -0.5*pen.width, path)
		END;
		IF pen.mode = outlined THEN
			LeoPens.GetTempPath(tmp); GfxPaths.Reverse(path, tmp);
			DrawOutline(pen, 0.5*pen.width, tmp);
			LeoPens.ReleaseTempPath(tmp)
		ELSIF pen.mode = inverted THEN
			LeoPens.GetTempPath(tmp); GfxPaths.Reverse(path, tmp);
			DrawOutline(pen, -0.5*pen.width, tmp);
			LeoPens.ReleaseTempPath(tmp)
		END;
		pen.base.do.end(pen.base);
		IF pen.base.destructive THEN LeoPens.ReleaseTempPath(path) END
	END OutlinePath;

	PROCEDURE BeginOutliner (pen: LeoPens.Pen; ctxt: Gfx.Context);
	BEGIN
		LeoPens.Begin(pen, ctxt);
		Gfx.Begin(ctxt, {Gfx.Record})
	END BeginOutliner;

	PROCEDURE EndOutliner (pen: LeoPens.Pen);
	BEGIN
		Gfx.End(pen.ctxt);
		OutlinePath(pen(Outliner), pen.ctxt)
	END EndOutliner;

	PROCEDURE RenderOutliner (pen: LeoPens.Pen; ctxt: Gfx.Context; VAR bdist, edist: ARRAY OF FLOAT32; n: SIGNED32);
	BEGIN
		OutlinePath(pen(Outliner), ctxt)
	END RenderOutliner;

	PROCEDURE InitOutliners;
	BEGIN
		NEW(OutlinerMethods);
		OutlinerMethods.begin := BeginOutliner; OutlinerMethods.end := EndOutliner;
		OutlinerMethods.enter := LeoPens.Enter; OutlinerMethods.exit := LeoPens.Exit;
		OutlinerMethods.line := LeoPens.Line; OutlinerMethods.arc := LeoPens.Arc; OutlinerMethods.bezier := LeoPens.Bezier;
		OutlinerMethods.render := RenderOutliner
	END InitOutliners;


	(**--- Arrows ---**)

	PROCEDURE CopyArrow* (VAR msg: Objects.CopyMsg; from, to: Arrow);
	BEGIN
		CopyOutliner(msg, from, to);
		to.dir := from.dir; to.len := from.len; to.coff := from.coff; to.cdist := from.cdist
	END CopyArrow;

	PROCEDURE HandleArrow* (obj: Objects.Object; VAR msg: Objects.ObjMsg);
		VAR pen, copy: Arrow; ver: SIGNED32;
	BEGIN
		pen := obj(Arrow);
		IF msg IS LeoPens.UpdateMsg THEN
			IF msg(LeoPens.UpdateMsg).pen = pen.base THEN
				LeoPens.Update(pen)
			END
		ELSIF msg IS Objects.AttrMsg THEN
			WITH msg: Objects.AttrMsg DO
				IF msg.id = Objects.enum THEN
					msg.Enum("Direction"); msg.Enum("Length"); msg.Enum("CornerOffset"); msg.Enum("CornerDist");
					HandleOutliner(pen, msg)
				ELSIF msg.id = Objects.get THEN
					IF msg.name = "Gen" THEN msg.class := Objects.String; msg.s := "LeoOutliners.NewArrow"; msg.res := 0
					ELSIF msg.name = "Item" THEN msg.class := Objects.String; msg.s := "Arrow"; msg.res := 0
					ELSIF msg.name = "Direction" THEN msg.class := Objects.Int; msg.i := pen.dir; msg.res := 0
					ELSIF msg.name = "Length" THEN msg.class := Objects.Real; msg.x := pen.len; msg.res := 0
					ELSIF msg.name = "CornerOffset" THEN msg.class := Objects.Real; msg.x := pen.coff; msg.res := 0
					ELSIF msg.name = "CornerDist" THEN msg.class := Objects.Real; msg.x := pen.cdist; msg.res := 0
					ELSIF msg.name = "Border" THEN
						pen.base.handle(pen.base, msg);
						msg.x := msg.x + pen.cdist
					ELSE
						HandleOutliner(pen, msg)
					END
				ELSIF msg.id = Objects.set THEN
					IF msg.name = "Direction" THEN
						IF (msg.class = Objects.Int) & (forwards <= msg.i) & (msg.i <= backwards) THEN
							pen.dir := SHORT(SHORT(msg.i)); msg.res := 0
						END
					ELSIF msg.name = "Length" THEN
						IF msg.class = Objects.Real THEN pen.len := msg.x; msg.res := 0 END
					ELSIF msg.name = "CornerOffset" THEN
						IF msg.class = Objects.Real THEN pen.coff := msg.x; msg.res := 0 END
					ELSIF msg.name = "CornerDist" THEN
						IF msg.class = Objects.Real THEN pen.cdist := msg.x; msg.res := 0 END
					ELSE
						HandleOutliner(pen, msg)
					END
				END
			END
		ELSIF msg IS Objects.CopyMsg THEN
			WITH msg: Objects.CopyMsg DO
				IF msg.stamp # pen.stamp THEN
					NEW(copy); pen.dlink := copy; pen.stamp := msg.stamp;
					CopyArrow(msg, pen, copy)
				END;
				msg.obj := pen.dlink
			END
		ELSIF msg IS Objects.FileMsg THEN
			WITH msg: Objects.FileMsg DO
				HandleOutliner(pen, msg);
				IF msg.id = Objects.store THEN
					Files.WriteNum(msg.R, 1);
					Files.Write(msg.R, pen.dir);
					Files.WriteReal(msg.R, pen.len); Files.WriteReal(msg.R, pen.coff); Files.WriteReal(msg.R, pen.cdist)
				ELSIF msg.id = Objects.load THEN
					Files.ReadNum(msg.R, ver);
					Files.Read(msg.R, pen.dir);
					Files.ReadReal(msg.R, pen.len); Files.ReadReal(msg.R, pen.coff); Files.ReadReal(msg.R, pen.cdist)
				END
			END
		ELSE
			HandleOutliner(pen, msg)
		END
	END HandleArrow;

	PROCEDURE InitArrow* (pen: Arrow; base: LeoPens.Pen; dir, mode: SIGNED8; len, coff, cdist, w: FLOAT32);
	BEGIN
		ASSERT(base # NIL, 100);
		InitOutliner(pen, base, w, mode);
		pen.handle := HandleArrow; pen.do := ArrowMethods;
		pen.needDist := TRUE;
		pen.dir := dir; pen.len := len; pen.coff := coff; pen.cdist := cdist
	END InitArrow;

	PROCEDURE NewArrow*;
		VAR pen: Arrow;
	BEGIN
		NEW(pen); InitArrow(pen, LeoPens.Default, forwards, outlined, 10, 10, 5, 5);
		Objects.NewObj := pen
	END NewArrow;

	PROCEDURE DrawArrowSide (pen: Arrow; sign, split: FLOAT32; path: GfxPaths.Path);
		VAR
			base: LeoPens.Pen; clen, x0, y0, dx0, dy0, dx, dy, d, len, off0, tan, w, x1, y1, dx1, dy1, d1, off1, x, y: FLOAT32;
			s: GfxPaths.Scanner; n: SIGNED32;
	BEGIN
		base := pen.base;
		IF pen.len < pen.coff THEN clen := pen.len ELSE clen := pen.coff END;
		GfxPaths.Open(s, path, 0); n := 0;
		WHILE s.elem = GfxPaths.Enter DO
			x0 := s.x; y0 := s.y; Gfx.GetNormVector(s.dx, s.dy, 1, dx0, dy0);
			GfxPaths.Scan(s);
			IF s.elem = GfxPaths.Line THEN
				dx := s.x - x0; dy := s.y - y0; d := Math.sqrt(dx * dx + dy * dy); dx := dx/d; dy := dy/d;
				len := split * (pen.bdist[n] + pen.length[n] + pen.edist[n]) - pen.bdist[n];
				IF len > 0 THEN
					off0 := pen.bdist[n];
					IF off0 < clen THEN
						tan := pen.cdist/pen.coff; w := tan * off0 * sign
					ELSIF off0 < pen.len THEN
						tan := (0.5*pen.width - pen.cdist)/(pen.len - clen); w := (pen.cdist + tan * (off0 - clen)) * sign
					ELSE
						tan := 0; w := 0.5*pen.width * sign
					END
				ELSE
					off0 := pen.edist[n] + pen.length[n];
					IF off0 > pen.len THEN
						tan := 0; w := 0.5*pen.width * sign
					ELSIF off0 > clen THEN
						tan := (pen.cdist - 0.5*pen.width)/(pen.len - clen); w := (pen.cdist - tan * (off0 - clen)) * sign
					ELSE
						tan := -pen.cdist/pen.coff; w := -tan * off0 * sign
					END
				END;
				Enter(pen, w, x0, y0, dx0, dy0, dx, dy, tan);
				x1 := s.x; y1 := s.y; GfxPaths.Scan(s);

				LOOP
					IF s.elem = GfxPaths.Line THEN
						dx1 := s.x - x1; dy1 := s.y - y1; d1 := Math.sqrt(dx1 * dx1 + dy1 * dy1); dx1 := dx1/d1; dy1 := dy1/d1
					ELSIF s.elem = GfxPaths.Exit THEN
						Gfx.GetNormVector(s.dx, s.dy, 1, dx1, dy1)
					ELSE
						EXIT
					END;

					IF (len > 0) & (d <= len) THEN	(* backwards arrow *)
						off1 := off0 + d;
						IF (off0 < clen) & (clen <= off1) THEN
							w := pen.cdist * sign;
							x := x0 + (pen.coff - off0) * dx; y := y0 + (pen.coff - off0) * dy;
							base.do.line(base, x + w * dy, y - w * dx);
							IF off1 < pen.len THEN
								tan := (0.5*pen.width - pen.cdist)/(pen.len - clen); w := w - tan * (clen - off0) * sign
							END
						END;
						IF (off0 < pen.len) & (pen.len <= off1) THEN
							tan := 0; w := 0.5*pen.width * sign;
							x := x0 + (pen.len - off0) * dx; y := y0 + (pen.len - off0) * dy;
							base.do.line(base, x + w * dy, y - w * dx)
						END;
						w := w + tan * d * sign;
						IF s.elem = GfxPaths.Line THEN
							Join(pen, w, x1, y1, dx, dy, dx1, dy1, tan, tan)
						END

					ELSIF (len > 0) & (d > len) THEN	(* crosses boundary between arrow heads *)
						off1 := off0 + len;
						IF (off0 < clen) & (clen <= off1) THEN
							w := pen.cdist * sign;
							x := x0 + (pen.coff - off0) * dx; y := y0 + (pen.coff - off0) * dy;
							base.do.line(base, x + w * dy, y - w * dx);
							IF off1 < pen.len THEN
								tan := (0.5*pen.width - pen.cdist)/(pen.len - clen); w := w + tan * (off0 - clen) * sign
							END
						END;
						IF (off0 < pen.len) & (pen.len <= off1) THEN
							tan := 0; w := 0.5*pen.width * sign;
							x := x0 + (pen.len - off0) * dx; y := y0 + (pen.len - off0) * dy;
							base.do.line(base, x + w * dy, y - w * dx)
						END;
						x0 := x0 + len * dx; y0 := y0 + len * dy; w := w + tan * len * sign;
						Join(pen, w, x0, y0, dx, dy, dx, dy, tan, -tan);
						off0 := 0.5*(pen.bdist[n] + pen.length[n] + pen.edist[n]);
						d := d - len; len := 0;
						tan := -tan
					END;

					IF len <= 0 THEN	(* forward arrow *)
						off1 := off0 - d;
						IF (off0 > pen.len) & (pen.len >= off1) THEN
							x := x0 + (off0 - pen.len) * dx; y := y0 + (off0 - pen.len) * dy;
							base.do.line(base, x + w * dy, y - w * dx);
							IF off1 > clen THEN
								tan := (pen.cdist - 0.5*pen.width)/(pen.len - clen); w := w - tan * (off0 - pen.len) * sign
							END
						END;
						IF (off0 > clen) & (clen >= off1) THEN
							tan := -pen.cdist/pen.coff; w := pen.cdist * sign;
							x := x0 + (off0 - pen.coff) * dx; y := y0 + (off0 - pen.coff) * dy;
							base.do.line(base, x + w * dy, y - w * dx);
							w := w - tan * (off0 - pen.coff) * sign
						END;
						w := w + tan * d * sign;
						IF s.elem = GfxPaths.Line THEN
							Join(pen, w, x1, y1, dx, dy, dx1, dy1, tan, tan)
						END
					END;

					IF s.elem = GfxPaths.Exit THEN
						EXIT
					ELSE
						off0 := off1; len := len - d;
						x0 := x1; y0 := y1;
						dx := dx1; dy := dy1; d := d1;
						x1 := s.x; y1 := s.y; GfxPaths.Scan(s)
					END
				END;

				IF s.elem = GfxPaths.Exit THEN
					Exit(pen, w, x1, y1, dx, dy, dx1, dy1, tan);
					GfxPaths.Scan(s)
				END;

				INC(n)
			END
		END
	END DrawArrowSide;

	PROCEDURE DrawArrow (pen: Arrow; ctxt: Gfx.Context);
		VAR path, tmp: GfxPaths.Path; inv: GfxMatrix.Matrix; s: GfxPaths.Scanner; i, j: SIGNED32; x, y, len, dx, dy, t: FLOAT32;
	BEGIN
		Gfx.Flatten(ctxt);
		IF pen.base.destructive THEN LeoPens.GetTempPath(path); GfxPaths.Copy(ctxt.path, path)
		ELSE path := ctxt.path
		END;
		GfxMatrix.Invert(ctxt.ctm, inv); GfxPaths.Apply(path, inv);

		LeoPens.Append(pen.length, pen.n-1, 0);	(* set number of elements *)
		GfxPaths.Open(s, path, 0); i := 0;
		WHILE s.elem = GfxPaths.Enter DO
			x := s.x; y := s.y; len := 0;
			GfxPaths.Scan(s);
			WHILE s.elem = GfxPaths.Line DO
				dx := s.x - x; dy := s.y - y; len := len + Math.sqrt(dx * dx + dy * dy);
				x := s.x; y := s.y; GfxPaths.Scan(s)
			END;
			IF s.elem = GfxPaths.Exit THEN
				GfxPaths.Scan(s)
			END;
			LeoPens.Append(pen.length, i, len); INC(i)
		END;

		pen.base.do.begin(pen.base, ctxt);
		IF pen.mode IN {outlined, parallel, right} THEN
			DrawArrowSide(pen, 1, Split[pen.dir], path)
		END;
		IF pen.mode IN {inverted, parallel, left} THEN
			DrawArrowSide(pen, -1, Split[pen.dir], path)
		END;
		IF pen.mode IN {outlined, inverted} THEN
			LeoPens.GetTempPath(tmp); GfxPaths.Reverse(path, tmp);
			i := 0; j := pen.n-1;
			WHILE i <= j DO
				t := pen.bdist[i]; pen.bdist[i] := pen.edist[j]; pen.edist[j] := t;
				t := pen.edist[i]; pen.edist[i] := pen.bdist[j]; pen.bdist[j] := t;
				t := pen.length[i]; pen.length[i] := pen.length[j]; pen.length[j] := t;
				INC(i); DEC(j)
			END;
			IF pen.mode = outlined THEN
				DrawArrowSide(pen, 1, 1-Split[pen.dir], tmp)
			ELSE
				DrawArrowSide(pen, -1, 1-Split[pen.dir], tmp)
			END;
			LeoPens.ReleaseTempPath(tmp)
		END;
		pen.base.do.end(pen.base);
		IF pen.base.destructive THEN LeoPens.ReleaseTempPath(path) END
	END DrawArrow;

	PROCEDURE BeginArrow (pen: LeoPens.Pen; ctxt: Gfx.Context);
	BEGIN
		LeoPens.Begin(pen, ctxt);
		Gfx.Begin(ctxt, {Gfx.Record});
		pen(Arrow).n := 0
	END BeginArrow;

	PROCEDURE EndArrow (pen: LeoPens.Pen);
	BEGIN
		Gfx.End(pen.ctxt);
		DrawArrow(pen(Arrow), pen.ctxt);
		LeoPens.End(pen)
	END EndArrow;

	PROCEDURE EnterArrow (pen: LeoPens.Pen; x, y, dx, dy, blen: FLOAT32);
		VAR p: Arrow;
	BEGIN
		p := pen(Arrow);
		Gfx.Enter(p.ctxt, x, y, dx, dy);
		LeoPens.Append(p.bdist, p.n, blen)
	END EnterArrow;

	PROCEDURE ExitArrow (pen: LeoPens.Pen; dx, dy, elen: FLOAT32);
		VAR p: Arrow;
	BEGIN
		p := pen(Arrow);
		Gfx.Exit(p.ctxt, dx, dy);
		LeoPens.Append(p.edist, p.n, elen);
		INC(p.n)
	END ExitArrow;

	PROCEDURE RenderArrow (pen: LeoPens.Pen; ctxt: Gfx.Context; VAR blen, elen: ARRAY OF FLOAT32; n: SIGNED32);
		VAR p: Arrow;
	BEGIN
		p := pen(Arrow);
		p.n := n;
		WHILE n > 0 DO
			(* copy last distance first in order to reallocate arrays at most once *)
			DEC(n);
			LeoPens.Append(p.bdist, n, blen[n]);
			LeoPens.Append(p.edist, n, elen[n])
		END;
		DrawArrow(p, ctxt)
	END RenderArrow;

	PROCEDURE InitArrows;
	BEGIN
		NEW(ArrowMethods);
		ArrowMethods.begin := BeginArrow; ArrowMethods.end := EndArrow;
		ArrowMethods.enter := EnterArrow; ArrowMethods.exit := ExitArrow;
		ArrowMethods.line := LeoPens.Line; ArrowMethods.arc := LeoPens.Arc; ArrowMethods.bezier := LeoPens.Bezier;
		ArrowMethods.render := RenderArrow
	END InitArrows;


BEGIN
	InitOutliners; InitArrows;
	Split[forwards] := 0; Split[both] := 0.5; Split[backwards] := 1
END LeoOutliners.
