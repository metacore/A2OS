(* ETH Oberon, Copyright 2001 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

MODULE LeoCaptions IN Oberon; (** portable **)	(* eos  *)

	(**
		Leonardo captions
	**)

	IMPORT
		Files, Display, Objects, Oberon, GfxMatrix, GfxPaths, GfxFonts, Gfx, Leonardo, LeoPens, LeoPaths;


	CONST
		consume* = 0; accept* = 1; release* = 2;	(** focus message **)

		full = 0; insert = 1; delete = 2; caret = 3;	(* update types *)
		BlockSize = 32;	(* block size for text allocations *)
		CursorLeft = 0C4X; CursorRight = 0C3X; BackSpace = 7FX; Delete = 0A1X; Home = 0A8X; End = 0A9X;


	TYPE
		Text = POINTER TO ARRAY OF CHAR;

		Caption* = POINTER TO CaptionDesc;
		CaptionDesc* = RECORD (Leonardo.ShapeDesc)
			text*: Text;	(** characters defining caption **)
			len*: SIGNED32;	(** number of characters in caption **)
			font*: GfxFonts.Font;	(** caption font (instanced at 300 dpi for calculating metrics) **)
			mat*: GfxMatrix.Matrix;	(** transform from font to local coordinates **)
			color*: Gfx.Color;	(** caption color **)
			width: FLOAT32;	(* advance width in figure space along baseline *)
			caret: SIGNED32;	(* logical caret position, negative if not holding focus *)
			update: SIGNED8;	(* kind of update *)
			from, to: SIGNED32;	(* update stretch *)
		END;

		(** message for managing the focus shape **)
		FocusMsg* = RECORD (Leonardo.LocalizedMsg)
			id*: SIGNED8;	(** consume/accept/release **)
			char*: CHAR;	(** character to consume **)
			res*: SIGNED16;	(** result for consume **)
			fx*, fy*: FLOAT32;	(** focus coordinates (in figure space) **)
			gdm*: GfxMatrix.Matrix;	(** transforms global to device coordinates **)
			shape*: Leonardo.Shape;	(** shape accepting the focus **)
		END;

		EditAction = POINTER TO EditActionDesc;
		EditActionDesc = RECORD (Leonardo.ActionDesc)
			cap: Caption;
			pos: SIGNED32;
			update: SIGNED8;
			char: CHAR;
		END;


	VAR
		FontMat, FontInv: GfxMatrix.Matrix;	(* font matrix for 300 dpi *)


	(**--- Focus Handling ---**)

	PROCEDURE Accept* (fig: Leonardo.Figure; x, y: FLOAT32; gdm: GfxMatrix.Matrix): Leonardo.Shape;
		VAR fm: FocusMsg;
	BEGIN
		fm.id := accept; fm.fx := x; fm.fy := y; fm.gdm := gdm; fm.shape := NIL; fig.handle(fig, fm);
		RETURN fm.shape
	END Accept;

	PROCEDURE Release* (fig: Leonardo.Figure; shape: Leonardo.Shape);
		VAR fm: FocusMsg;
	BEGIN
		fm.id := release;
		IF shape = NIL THEN fig.handle(fig, fm)
		ELSE fm.fig := fig; shape.handle(shape, fm)
		END
	END Release;

	PROCEDURE Consume* (fig: Leonardo.Figure; shape: Leonardo.Shape; ch: CHAR; VAR res: SIGNED16);
		VAR fm: FocusMsg;
	BEGIN
		fm.id := consume; fm.char := ch; fm.res := -1;
		IF shape = NIL THEN fig.handle(fig, fm)
		ELSE fm.fig := fig; shape.handle(shape, fm)
		END;
		res := fm.res
	END Consume;


	(**--- Captions ---**)

	PROCEDURE GetOffset (cap: Caption; len: SIGNED32; font: GfxFonts.Font; VAR x, y: FLOAT32);
		VAR ch: CHAR;
	BEGIN
		IF len > 0 THEN
			ch := cap.text[len]; cap.text[len] := 0X;
			GfxFonts.GetStringWidth(font, cap.text^, x, y);
			cap.text[len] := ch
		ELSE
			x := 0; y := 0
		END
	END GetOffset;

	PROCEDURE Set (cap: Caption; VAR text: ARRAY OF CHAR; len: SIGNED32);
		VAR size: SIGNED32;
	BEGIN
		size := len+1;	(* additional space for 0X *)
		IF (cap.text = NIL) OR (size > LEN(cap.text^)) THEN
			NEW(cap.text, -((-size) DIV BlockSize) * BlockSize)	(* rounds up to next multiple of BlockSize *)
		END;
		COPY(text, cap.text^); cap.len := len
	END Set;

	PROCEDURE CalcBox (cap: Caption; VAR mat: GfxMatrix.Matrix);
		VAR h: FLOAT32; m: GfxMatrix.Matrix;
	BEGIN
		GfxFonts.GetStringWidth(cap.font, cap.text^, cap.width, h);
		GfxMatrix.Concat(cap.mat, mat, m);
		GfxMatrix.ApplyToRect(m, 0, cap.font.ymin, cap.width, cap.font.ymax, cap.llx, cap.lly, cap.urx, cap.ury);
		IF ABS(cap.font.xmax) > ABS(cap.font.xmin) THEN GfxMatrix.ApplyToDist(m, ABS(cap.font.xmax), cap.bw)
		ELSE GfxMatrix.ApplyToDist(m, ABS(cap.font.xmin), cap.bw)
		END
	END CalcBox;

	PROCEDURE Validate (cap: Caption; VAR msg: Leonardo.ValidateMsg);
		VAR lgm: GfxMatrix.Matrix;

		PROCEDURE update (from, to: SIGNED32);
			VAR fx, y, tx, llx, lly, urx, ury: FLOAT32;
		BEGIN
			GetOffset(cap, from, cap.font, fx, y);
			IF to = from THEN tx := fx
			ELSE GetOffset(cap, to, cap.font, tx, y)
			END;
			(*
				The character metrics of screen and printer fonts are not always consistent because screen fonts metrics are
				sometimes corrected for aesthetic reasons. We assume a maximal error of 20% (e.g. lower case letters of
				Syntax10 are 7% denser on screen than on the printer).
			*)
			GfxMatrix.ApplyToRect(lgm, 0.8*fx, cap.font.ymin, 1.2*tx, cap.font.ymax, llx, lly, urx, ury);
			Leonardo.UpdateRect(msg.fig, llx, lly, urx, ury, cap.bw)
		END update;

	BEGIN
		IF cap.marked THEN
			GfxMatrix.Concat(cap.mat, msg.lgm, lgm);
			IF cap.update = full THEN
				Leonardo.UpdateShape(msg.fig, cap)
			ELSIF cap.update = delete THEN
				update(cap.from, cap.to)
			ELSIF (cap.update = caret) & (cap.from >= 0) THEN
				update(cap.from, cap.from)
			END;
			IF cap.update IN {full, insert, delete} THEN
				IF cap.sel THEN
					Leonardo.UpdateRect(msg.fig, cap.llx, cap.lly, cap.urx, cap.ury, cap.bw)
				END;
				CalcBox(cap, msg.lgm);
				IF cap.sel THEN
					Leonardo.UpdateRect(msg.fig, cap.llx, cap.lly, cap.urx, cap.ury, cap.bw)
				END
			END;
			IF cap.update = full THEN
				Leonardo.UpdateShape(msg.fig, cap)
			ELSIF cap.update = insert THEN
				update(cap.from, cap.to)
			ELSIF (cap.update = caret) & (cap.to >= 0) THEN
				update(cap.to, cap.to)
			END;
			cap.marked := FALSE; cap.cont.marked := TRUE; cap.update := full
		END
	END Validate;

	PROCEDURE Outline (cap: Caption; VAR msg: LeoPaths.RenderMsg);
		VAR pen: LeoPens.Pen; path: GfxPaths.Path; i: SIGNED32; x, y, dx, dy: FLOAT32; scan: GfxPaths.Scanner;
	BEGIN
		pen := msg.pen; NEW(path);
		i := 0; x := 0; y := 0;
		WHILE cap.text[i] # 0X DO
			GfxFonts.GetOutline(cap.font, cap.text[i], x, y, path);
			GfxPaths.Close(path);
			GfxPaths.Apply(path, cap.mat);
			GfxPaths.Open(scan, path, 0);
			WHILE scan.elem # GfxPaths.Stop DO
				CASE scan.elem OF
				| GfxPaths.Enter: pen.do.enter(pen, scan.x, scan.y, scan.dx, scan.dy, 0)
				| GfxPaths.Line: pen.do.line(pen, scan.x, scan.y)
				| GfxPaths.Arc: pen.do.arc(pen, scan.x, scan.y, scan.x0, scan.y0, scan.x1, scan.y1, scan.x2, scan.y2)
				| GfxPaths.Bezier: pen.do.bezier(pen, scan.x, scan.y, scan.x1, scan.y1, scan.x2, scan.y2)
				| GfxPaths.Exit: pen.do.exit(pen, scan.dx, scan.dy, 0)
				END;
				GfxPaths.Scan(scan)
			END;
			GfxFonts.GetWidth(cap.font, cap.text[i], dx, dy);
			x := x + dx; y := y + dy;
			INC(i)
		END
	END Outline;

	PROCEDURE Render (cap: Caption; VAR msg: Leonardo.RenderMsg);
		VAR llx, lly, urx, ury, cx, cy, lw: FLOAT32; ctm, lgm, m: GfxMatrix.Matrix; font: GfxFonts.Font; col: Gfx.Color;
	BEGIN
		IF (msg.id IN {Leonardo.active, Leonardo.passive, Leonardo.marksonly}) OR (msg.id = Leonardo.marked) & cap.marked THEN
			llx := cap.llx - cap.bw; lly := cap.lly - cap.bw; urx := cap.urx + cap.bw; ury := cap.ury + cap.bw;
			IF (llx < msg.urx) & (msg.llx < urx) & (lly < msg.ury) & (msg.lly < ury) THEN
				(* adjust context ctm and render caption text *)
				ctm := msg.ctxt.ctm;
				IF msg.id IN {Leonardo.active, Leonardo.passive, Leonardo.marked} THEN
					Gfx.Concat(msg.ctxt, cap.mat);
					font := msg.ctxt.font; Gfx.SetFont(msg.ctxt, cap.font);
					col := msg.ctxt.fillCol; Gfx.SetFillColor(msg.ctxt, cap.color);
					Gfx.DrawStringAt(msg.ctxt, 0, 0, cap.text^);
					Gfx.SetFillColor(msg.ctxt, col);
					Gfx.SetFont(msg.ctxt, font); Gfx.SetCTM(msg.ctxt, ctm)
				END;
				IF msg.id IN {Leonardo.active, Leonardo.marksonly} THEN
					IF cap.sel THEN	(* draw bounding box *)
						Gfx.Concat(msg.ctxt, cap.mat);
						lgm := msg.lgm; GfxMatrix.Concat(cap.mat, lgm, msg.lgm);
						Leonardo.DrawHandles(0, cap.font.ymin, cap.width, cap.font.ymax, msg);
						msg.lgm := lgm; Gfx.SetCTM(msg.ctxt, ctm)
					END;
					IF cap.caret >= 0 THEN
						GfxMatrix.Concat(FontMat, cap.mat, m); GfxMatrix.Concat(m, msg.ctxt.ctm, m);
						font := GfxFonts.Open(cap.font.name, cap.font.ptsize, m);
						IF font # NIL THEN	(* use device font for calculating caret position *)
							GetOffset(cap, cap.caret, font, cx, cy);
							Gfx.Concat(msg.ctxt, cap.mat);
							GfxMatrix.Solve(msg.ctxt.ctm, cx + msg.ctxt.ctm[2, 0], cy + msg.ctxt.ctm[2, 1], cx, cy)
						ELSE	(* use metrics font *)
							GetOffset(cap, cap.caret, cap.font, cx, cy);
							Gfx.Concat(msg.ctxt, cap.mat)
						END;
						col := msg.ctxt.strokeCol; Gfx.SetStrokeColor(msg.ctxt, Gfx.Black);
						lw := msg.ctxt.lineWidth; Gfx.SetLineWidth(msg.ctxt, 0);
						Gfx.DrawLine(msg.ctxt, cx, cap.font.ymin, cx, cap.font.ymax, {Gfx.Stroke});
						Gfx.SetLineWidth(msg.ctxt, lw); Gfx.SetStrokeColor(msg.ctxt, col); Gfx.SetCTM(msg.ctxt, ctm)
					END
				END
			END
		END
	END Render;

	PROCEDURE Locate (cap: Caption; VAR msg: Leonardo.LocateMsg);
		VAR mat, inv, lgm: GfxMatrix.Matrix; llx, lly, urx, ury: FLOAT32;
	BEGIN
		IF (msg.id = Leonardo.inside) & (msg.llx <= cap.llx) & (cap.urx <= msg.urx) & (msg.lly <= cap.lly) & (cap.ury <= msg.ury) THEN
			cap.slink := msg.res; msg.res := cap
		ELSIF (msg.llx < cap.urx) & (cap.llx < msg.urx) & (msg.lly < cap.ury) & (cap.lly < msg.ury) THEN
			GfxMatrix.Concat(cap.mat, msg.lgm, mat);
			IF msg.id = Leonardo.overlap THEN
				GfxMatrix.Invert(mat, inv);
				GfxMatrix.ApplyToRect(inv, msg.llx, msg.lly, msg.urx, msg.ury, llx, lly, urx, ury);
				IF (0 < urx) & (llx < cap.width) & (cap.font.ymin < ury) & (lly < cap.font.ymax) THEN
					cap.slink := msg.res; msg.res := cap
				END
			ELSIF msg.id = Leonardo.project THEN
				lgm := msg.lgm; msg.lgm := mat;
				Leonardo.ProjectToHandles(cap, 0, cap.font.ymin, cap.width, cap.font.ymax, msg);
				msg.lgm := lgm
				(*
					perhaps it would be better to align to the baseline on the left and right extremes of the caption as well
				*)
			END
		END
	END Locate;

	PROCEDURE Transform (cap: Caption; VAR msg: Leonardo.TransformMsg);
		VAR glmat, mat: GfxMatrix.Matrix;
	BEGIN
		IF (msg.id = Leonardo.apply) & cap.marked & (msg.stamp # cap.stamp) THEN
			cap.stamp := msg.stamp;
			GfxMatrix.Invert(msg.lgm, glmat);
			GfxMatrix.Concat(cap.mat, msg.lgm, mat);
			GfxMatrix.Concat(mat, msg.mat, mat);
			GfxMatrix.Concat(mat, glmat, mat);
			Leonardo.SetMatrix(msg.fig, cap, "M", mat)
		END
	END Transform;

	PROCEDURE DoEditAction (fig: Leonardo.Figure; a: Leonardo.Action);
		VAR act: EditAction; cap: Caption; i, j: SIGNED32;
	BEGIN
		act := a(EditAction); cap := act.cap;
		IF act.update = delete THEN	(* delete character *)
			i := act.pos; j := i+1;
			REPEAT
				cap.text[i] := cap.text[j]; i := j; INC(j)
			UNTIL j > cap.len;
			IF (0 <= cap.caret) & (cap.caret < act.pos) THEN cap.from := cap.caret; cap.to := cap.len
			ELSE cap.from := act.pos; cap.to := cap.len
			END;
			DEC(cap.len);
			cap.update := delete; cap.caret := act.pos;
			act.update := insert
		ELSE	(* insert character *)
			j := cap.len; i := j+1; cap.len := i;
			WHILE j >= act.pos DO
				cap.text[i] := cap.text[j]; i := j; DEC(j)
			END;
			cap.text[i] := act.char;
			IF (0 <= cap.caret) & (cap.caret <= act.pos) THEN cap.from := cap.caret; cap.to := cap.len
			ELSE cap.from := act.pos; cap.to := cap.len
			END;
			cap.update := insert; cap.caret := act.pos+1;
			act.update := delete
		END;
		cap.marked := TRUE; cap.sel := TRUE
	END DoEditAction;

	PROCEDURE AddCommand (fig: Leonardo.Figure; cap: Caption; update: SIGNED8; pos: SIGNED32; char: CHAR);
		VAR act: EditAction;
	BEGIN
		Leonardo.BeginCommand(fig);
		NEW(act); act.do := DoEditAction; act.undo := act.do;
		act.cap := cap; act.update := update; act.pos := pos; act.char := char;
		Leonardo.AddAction(fig, act);
		Leonardo.EndCommand(fig)
	END AddCommand;

	PROCEDURE Update (fig: Leonardo.Figure; cap: Caption; from, to: SIGNED32);
	BEGIN
		cap.marked := TRUE; cap.update := caret; cap.caret := to; cap.from := from; cap.to := to;
		Leonardo.Validate(fig)
	END Update;

	PROCEDURE Edit (fig: Leonardo.Figure; cap: Caption; ch: CHAR);
		VAR text: Text;
	BEGIN
		IF (ch = CursorRight) & (cap.caret < cap.len) THEN
			Update(fig, cap, cap.caret, cap.caret+1)
		ELSIF (ch = CursorLeft) & (cap.caret > 0) THEN
			Update(fig, cap, cap.caret, cap.caret-1)
		ELSIF (ch = Home) & (cap.caret > 0) THEN
			Update(fig, cap, cap.caret, 0)
		ELSIF (ch = End) & (cap.caret < cap.len) THEN
			Update(fig, cap, cap.caret, cap.len)
		ELSIF (ch = BackSpace) & (cap.caret > 0) THEN
			AddCommand(fig, cap, delete, cap.caret-1, cap.text[cap.caret])
		ELSIF (ch = Delete) & (cap.caret < cap.len) THEN
			AddCommand(fig, cap, delete, cap.caret, cap.text[cap.caret])
		ELSIF (" " <= ch) & (ch < 7FX) OR (80X <= ch) & (ch < 9AX) THEN
			IF cap.len MOD BlockSize = BlockSize-1 THEN	(* time to reallocate *)
				NEW(text, cap.len + 1 + BlockSize);
				COPY(cap.text^, text^);
				cap.text := text
			END;
			AddCommand(fig, cap, insert, cap.caret, ch)
		END
	END Edit;

	PROCEDURE Focus (cap: Caption; VAR msg: FocusMsg);
		VAR fx, fy, x0, x1, y, xm: FLOAT32; car, p0, p1, pm: SIGNED32; m, mm, inv: GfxMatrix.Matrix; font: GfxFonts.Font;
	BEGIN
		IF (msg.id = consume) & (cap.caret >= 0) THEN
			Edit(msg.fig, cap, msg.char); msg.res := 0
		ELSIF (msg.id = accept) & (cap.llx <= msg.fx) & (msg.fx <= cap.urx) & (cap.lly <= msg.fy) & (msg.fy <= cap.ury) THEN
			GfxMatrix.Concat(cap.mat, msg.lgm, m);
			GfxMatrix.Solve(m, msg.fx, msg.fy, fx, fy);	(* focus point in font coordinates *)
			IF (0 <= fx) & (fx <= cap.width) & (cap.font.ymin <= fy) & (fy <= cap.font.ymax) THEN
				GfxMatrix.Concat(m, msg.gdm, m); GfxMatrix.Concat(FontMat, m, mm);	(* maps font to device coordinates *)
				font := GfxFonts.Open(cap.font.name, cap.font.ptsize, mm);
				IF font # NIL THEN GfxMatrix.Invert(m, inv); inv[2, 0] := 0; inv[2, 1] := 0;
				ELSE font := cap.font; inv := GfxMatrix.Identity
				END;
				IF cap.caret < 0 THEN Oberon.Defocus END;
				IF cap.len = 0 THEN
					car := 0
				ELSE	(* binary search of caret position using device font *)
					p0 := 0; x0 := 0;
					p1 := cap.len;
					GetOffset(cap, p1, font, x1, y); GfxMatrix.Apply(inv, x1, y, x1, y);
					WHILE p0+1 < p1 DO
						pm := (p0 + p1) DIV 2;
						GetOffset(cap, pm, font, xm, y); GfxMatrix.Apply(inv, xm, y, xm, y);
						IF xm <= fx THEN p0 := pm; x0 := xm
						ELSE p1 := pm; x1 := xm
						END
					END;
					IF fx - x0 < x1 - fx THEN car := p0
					ELSE car := p1
					END
				END;
				IF car # cap.caret THEN	(* move caret *)
					Update(msg.fig, cap, cap.caret, car)
				END;
				msg.shape := cap
			END
		ELSIF (msg.id = release) & (cap.caret >= 0) THEN
			IF cap.len = 0 THEN	(* kill empty caption *)
				cap.slink := NIL; Leonardo.Delete(msg.fig, cap)
			ELSE
				Update(msg.fig, cap, cap.caret, -1)
			END
		END
	END Focus;

	PROCEDURE HandleAttr (cap: Caption; VAR msg: Objects.AttrMsg);
		VAR len: SIGNED32; font: GfxFonts.Font;
	BEGIN
		IF msg.id = Objects.enum THEN
			msg.Enum("Text"); msg.Enum("Font"); msg.Enum("Size");
			msg.Enum("Red"); msg.Enum("Green"); msg.Enum("Blue");
			msg.Enum("M00"); msg.Enum("M01"); msg.Enum("M10");
			msg.Enum("M11"); msg.Enum("M20"); msg.Enum("M21");
			Leonardo.HandleShape(cap, msg)
		ELSIF msg.id = Objects.get THEN
			IF msg.name = "Gen" THEN msg.class := Objects.String; msg.s := "LeoCaptions.New"; msg.res := 0
			ELSIF msg.name = "Item" THEN
				msg.class := Objects.String; msg.res := 0; msg.s[0] := 22X;
				len := 0; WHILE (len < LEN(msg.s)-3) & (cap.text[len] # 0X) DO msg.s[len+1] := cap.text[len]; INC(len) END;
				msg.s[len+1] := 22X; msg.s[len+2] := 0X
			ELSIF msg.name = "Text" THEN msg.class := Objects.String; COPY(cap.text^, msg.s); msg.res := 0
			ELSIF msg.name = "Font" THEN msg.class := Objects.String; COPY(cap.font.name, msg.s); msg.res := 0
			ELSIF msg.name = "Size" THEN msg.class := Objects.Int; msg.i := cap.font.ptsize; msg.res := 0
			ELSIF msg.name = "Red" THEN msg.class := Objects.Int; msg.i := cap.color.r; msg.res := 0
			ELSIF msg.name = "Green" THEN msg.class := Objects.Int; msg.i := cap.color.g; msg.res := 0
			ELSIF msg.name = "Blue" THEN msg.class := Objects.Int; msg.i := cap.color.b; msg.res := 0
			ELSIF msg.name = "M00" THEN msg.class := Objects.Real; msg.x := cap.mat[0, 0]; msg.res := 0
			ELSIF msg.name = "M01" THEN msg.class := Objects.Real; msg.x := cap.mat[0, 1]; msg.res := 0
			ELSIF msg.name = "M10" THEN msg.class := Objects.Real; msg.x := cap.mat[1, 0]; msg.res := 0
			ELSIF msg.name = "M11" THEN msg.class := Objects.Real; msg.x := cap.mat[1, 1]; msg.res := 0
			ELSIF msg.name = "M20" THEN msg.class := Objects.Real; msg.x := cap.mat[2, 0]; msg.res := 0
			ELSIF msg.name = "M21" THEN msg.class := Objects.Real; msg.x := cap.mat[2, 1]; msg.res := 0
			ELSE Leonardo.HandleShape(cap, msg)
			END
		ELSIF msg.id = Objects.set THEN
			IF msg.name = "Text" THEN
				IF msg.class = Objects.String THEN
					len := 0; WHILE msg.s[len] # 0X DO INC(len) END;
					Set(cap, msg.s, len); msg.res := 0
				END
			ELSIF msg.name = "Font" THEN
				IF msg.class = Objects.String THEN
					font := GfxFonts.Open(msg.s, cap.font.ptsize, FontMat);
					IF font # NIL THEN cap.font := font; msg.res := 0 END
				END
			ELSIF msg.name = "Size" THEN
				IF msg.class = Objects.Int THEN
					font := GfxFonts.Open(cap.font.name, SHORT(msg.i), FontMat);
					IF font # NIL THEN cap.font := font; msg.res := 0 END
				END
			ELSIF msg.name = "Red" THEN
				IF msg.class = Objects.Int THEN cap.color.r := SHORT(msg.i MOD 100H); msg.res := 0 END
			ELSIF msg.name = "Green" THEN
				IF msg.class = Objects.Int THEN cap.color.g := SHORT(msg.i MOD 100H); msg.res := 0 END
			ELSIF msg.name = "Blue" THEN
				IF msg.class = Objects.Int THEN cap.color.b := SHORT(msg.i MOD 100H); msg.res := 0 END
			ELSIF msg.name = "M00" THEN
				IF msg.class = Objects.Real THEN cap.mat[0, 0] := msg.x; msg.res := 0 END
			ELSIF msg.name = "M01" THEN
				IF msg.class = Objects.Real THEN cap.mat[0, 1] := msg.x; msg.res := 0 END
			ELSIF msg.name = "M10" THEN
				IF msg.class = Objects.Real THEN cap.mat[1, 0] := msg.x; msg.res := 0 END
			ELSIF msg.name = "M11" THEN
				IF msg.class = Objects.Real THEN cap.mat[1, 1] := msg.x; msg.res := 0 END
			ELSIF msg.name = "M20" THEN
				IF msg.class = Objects.Real THEN cap.mat[2, 0] := msg.x; msg.res := 0 END
			ELSIF msg.name = "M21" THEN
				IF msg.class = Objects.Real THEN cap.mat[2, 1] := msg.x; msg.res := 0 END
			ELSE
				Leonardo.HandleShape(cap, msg)
			END
		END
	END HandleAttr;

	PROCEDURE Copy* (VAR msg: Objects.CopyMsg; from, to: Caption);
	BEGIN
		Leonardo.CopyShape(msg, from, to);
		Set(to, from.text^, from.len);
		to.font := from.font; to.mat := from.mat; to.color := from.color;
		to.caret := -1; to.width := from.width
	END Copy;

	PROCEDURE Handle* (obj: Objects.Object; VAR msg: Objects.ObjMsg);
		VAR cap, copy: Caption; key, ptsize: SIGNED16; ver: SIGNED32; name: ARRAY 64 OF CHAR; ch: CHAR;
	BEGIN
		cap := obj(Caption);
		IF msg IS Leonardo.ShapeMsg THEN
			IF msg IS Leonardo.ControlMsg THEN
				WITH msg: Leonardo.ControlMsg DO
					IF (msg.id = Leonardo.delete) & cap.marked & (cap.caret >= 0) THEN
						cap.caret := -1	(* caption shouldn't have focus if recalled later by undo *)
					ELSE
						Leonardo.HandleShape(cap, msg)
					END
				END
			ELSIF msg IS Leonardo.ValidateMsg THEN
				Validate(cap, msg(Leonardo.ValidateMsg))
			ELSIF msg IS Leonardo.RenderMsg THEN
				Render(cap, msg(Leonardo.RenderMsg))
			ELSIF msg IS Leonardo.LocateMsg THEN
				Locate(cap, msg(Leonardo.LocateMsg))
			ELSIF msg IS Leonardo.TransformMsg THEN
				Transform(cap, msg(Leonardo.TransformMsg))
			ELSIF msg IS LeoPaths.ContourMsg THEN
				msg(LeoPaths.ContourMsg).done := TRUE
			ELSIF msg IS LeoPaths.RenderMsg THEN
				Outline(cap, msg(LeoPaths.RenderMsg))
			ELSIF msg IS FocusMsg THEN
				Focus(cap, msg(FocusMsg))
			ELSE
				Leonardo.HandleShape(cap, msg)
			END
		ELSIF msg IS Objects.AttrMsg THEN
			HandleAttr(cap, msg(Objects.AttrMsg))
		ELSIF msg IS Objects.CopyMsg THEN
			WITH msg: Objects.CopyMsg DO
				IF msg.stamp # cap.stamp THEN
					NEW(copy); cap.dlink := copy; cap.stamp := msg.stamp;
					Copy(msg, cap, copy)
				END;
				msg.obj := cap.dlink
			END
		ELSIF msg IS Objects.FileMsg THEN
			WITH msg: Objects.FileMsg DO
				Leonardo.HandleShape(cap, msg);
				IF msg.id = Objects.store THEN
					Files.WriteNum(msg.R, 2);
					Files.WriteNum(msg.R, cap.len);
					Files.WriteString(msg.R, cap.text^);
					Objects.GetKey(cap.lib.dict, cap.font.name, key);
					Files.WriteInt(msg.R, key);
					Files.WriteInt(msg.R, cap.font.ptsize);
					Files.Write(msg.R, CHR(cap.color.r)); Files.Write(msg.R, CHR(cap.color.g)); Files.Write(msg.R, CHR(cap.color.b));
					GfxMatrix.Write(msg.R, cap.mat)
				ELSIF msg.id = Objects.load THEN
					Files.ReadNum(msg.R, ver);
					Files.ReadNum(msg.R, cap.len);
					NEW(cap.text, -((-cap.len-1) DIV BlockSize) * BlockSize);
					Files.ReadString(msg.R, cap.text^);
					Files.ReadInt(msg.R, key);
					Objects.GetName(cap.lib.dict, key, name);
					Files.ReadInt(msg.R, ptsize);
					cap.font := GfxFonts.Open(name, ptsize, FontMat);
					Files.Read(msg.R, ch); cap.color.r := ORD(ch);
					Files.Read(msg.R, ch); cap.color.g := ORD(ch);
					Files.Read(msg.R, ch); cap.color.b := ORD(ch);
					GfxMatrix.Read(msg.R, cap.mat);
					IF ver = 1 THEN
						GfxMatrix.Concat(FontInv, cap.mat, cap.mat)
					END;
					CalcBox(cap, GfxMatrix.Identity)
				END
			END
		ELSE
			Leonardo.HandleShape(cap, msg)
		END
	END Handle;

	PROCEDURE Init* (cap: Caption; x, y: FLOAT32; text: ARRAY OF CHAR; font: GfxFonts.Font; col: Gfx.Color);
		VAR len: SIGNED32;
	BEGIN
		cap.handle := Handle;
		len := 0; WHILE text[len] # 0X DO INC(len) END;
		Set(cap, text, len);
		cap.font := GfxFonts.Open(font.name, font.ptsize, FontMat);
		IF cap.font # NIL THEN cap.mat := FontInv; cap.mat[2, 0] := x; cap.mat[2, 1] := y
		ELSE cap.font := font; GfxMatrix.Init(cap.mat, 1, 0, 0, 1, x, y)
		END;
		cap.color := col;
		cap.caret := -1; cap.update := full;
		CalcBox(cap, GfxMatrix.Identity)
	END Init;

	PROCEDURE New*;
		VAR cap: Caption;
	BEGIN
		NEW(cap); Init(cap, 0, 0, "", GfxFonts.Default, Gfx.Black);
		Objects.NewObj := cap
	END New;


BEGIN
	GfxMatrix.Init(FontMat, Display.Unit/(914400 DIV 300), 0, 0, Display.Unit/(914400 DIV 300), 0, 0);
	GfxMatrix.Init(FontInv, 1/FontMat[0, 0], 0, 0, 1/FontMat[1, 1], 0, 0)
END LeoCaptions.
