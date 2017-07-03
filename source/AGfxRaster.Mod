(* ETH Oberon, Copyright 2001 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

MODULE GfxRaster; (** portable *)	(* eos  *)
(** AUTHOR "eos"; PURPOSE "Gfx contexts rendering on abstract raster devices"; *)

	(*
		(probably only interesting for extensions rendering to concrete devices)
	*)

	(*
		12.2.98 - eliminated offset parameter from subpath begin
		12.2.98 - fixed bug with path not being allocated for mode=Clip in BeginPath
		12.2.98 - fixed bug with ASSERT being executed before rc was assigned in RestoreClip
		17.2.98 - implemented RenderPath
		24.2.98 - adaption to new cap and join styles
		27.2.98 - fixed bug with filled paths (didn't update (u, v) in context)
		6.4.98 - fixed bug in RenderPath (didn't alloc and init pathReg for thick lines)
		6.4.98 - fixed bug with thick lines (didn't treat (hx, hy) = (0, 0) correctly)
		8.4.98 - made filled regions more robust regarding open boundary curves
		8.4.98 - fixed bug in BeginSubpath (didn't set rc.u and rc.v for mode = {Record})
		15.4.98 - fixed clipState (now only updated while stroking, removed OutIn state, added InOut state)
		15.4.98 - improved autoclose logic for filled paths (now only connects open subpaths)
		18.9.98 - minor changes to comply with new GfxMaps, GfxFonts and Gfx interfaces
		21.9.98 - implemented special cases for circles and axis-aligned ellipses
		10.3.99 - new dash pattern
		1.4.99 - bugfix in Rect: incorrect use of GfxRegions.AddPoint when mode included Clip
		13.5.99 - remodeled cap and join styles
		[26.5.99 - use 300 dpi metrics in Show (taken out again 14.7.99)]
		25.8.99 - replace GfxMaps by GfxImages
		8.10.99 - added Close functionality
		26.10.99 - removed auto-close logic for regions
		7.12.99 - fixed bug in AddCircle and AddEllipse (must add enter/exit points on different scanlines)
		13.02.2000 - new get/set clip methods
		18.02.2000 - fixed typo in HairCircle
		04.04.2000 - fixed bug in Arc: didn't set (u, v) when recording
	*)

	IMPORT
		Math, GfxMatrix, GfxImages, GfxPaths, GfxRegions, GfxFonts, Gfx;


	CONST
		In* = 0; Out* = 1; InOut* = 2;	(** clip states **)


	TYPE
		(** region based clip areas **)
		ClipArea* = POINTER TO ClipAreaDesc;
		ClipAreaDesc* = RECORD (Gfx.ClipAreaDesc)
			reg*: GfxRegions.Region;	(** corresponding region **)
		END;

		(** abstract raster context **)
		Context* = OBJECT(Gfx.Context)
		VAR
			clipReg*: GfxRegions.Region;	(** region inside clip path **)
			col*: Gfx.Color;	(** current color **)
			pat*: Gfx.Pattern;	(** current pattern **)
			clipState*: SHORTINT;	(* current clip state (In, Out, InOut) *)
			useRegion, lateStroke: BOOLEAN;	(* flags for path operations *)
			cp: GfxPaths.Path;	(* current path if lateStroke is set *)
			pathReg: GfxRegions.Region;	(* region surrounded by current path *)
			plx, ply, prx, puy: INTEGER;	(* rectangle around last point *)
			border: INTEGER;	(* safety border in proportion to style limit around points *)
			devWidth: REAL;	(* half the line width in device space *)
			u, v: REAL;	(* current position in device space *)
			su, sv: REAL;	(* position of first point for thick lines *)
			du, dv: REAL;	(* current direction for thick lines *)
			tu, tv: REAL;	(* point on thick line perpendicular to current inner join vertex *)
			px, py: LONGINT;	(* current pixel position *)
			fu, fv: REAL;	(* current outline position for filled areas *)
			offset: REAL;	(* current offset *)
			deferred: BOOLEAN;	(* indicates that no cap/join has been drawn for start of thick line yet *)
			u0, v0, u1, v1: REAL;	(* endpoints of first thick line of current subpath *)

			(** initialize raster context **)
			PROCEDURE InitRaster* ();
			BEGIN
				Init();
				IF SELF.clipReg = NIL THEN
					NEW(SELF.clipReg); SELF.clipReg.Init(GfxRegions.Winding);
				ELSE
					SELF.clipReg.Init(GfxRegions.Winding)
				END;
			END InitRaster;

			PROCEDURE SetColPat* (col: Gfx.Color; pat: Gfx.Pattern);
			BEGIN
				SELF.col := col; SELF.pat := pat
			END SetColPat;

			PROCEDURE{ABSTRACT} FillDot* (x, y: LONGINT);	(** current dot procedure **)
			END FillDot;

			PROCEDURE{ABSTRACT} FillRect* (lx, ly, rx, uy: LONGINT);	(** current rect procedure **)
			END FillRect;

			(** clipping **)
			PROCEDURE ResetClip* ();
			BEGIN
				SELF.clipReg.Clear()
			END ResetClip;

			PROCEDURE GetClipRect* (VAR llx, lly, urx, ury: REAL);
				VAR inv: GfxMatrix.Matrix; reg: GfxRegions.Region;
			BEGIN
				GfxMatrix.Invert(SELF.ctm, inv);
				reg := SELF.clipReg;
				GfxMatrix.ApplyToRect(inv, reg.llx, reg.lly, reg.urx, reg.ury, llx, lly, urx, ury)
			END GetClipRect;

			PROCEDURE GetClip* (): Gfx.ClipArea;
				VAR clip: ClipArea;
			BEGIN
				NEW(clip); NEW(clip.reg); SELF.clipReg.Copy(clip.reg);
				RETURN clip
			END GetClip;

			PROCEDURE SetClip* (clip: Gfx.ClipArea);
			BEGIN
				ASSERT(clip IS ClipArea, 100);
				clip(ClipArea).reg.Copy(SELF.clipReg)
			END SetClip;

			(** current path **)
			PROCEDURE Begin* (mode: SET);
			BEGIN
				SELF.mode := mode * {Gfx.Record..Gfx.EvenOdd};
				SELF.cam := SELF.ctm;	(* preserve current transformation for attributes *)
				IF Gfx.Record IN SELF.mode THEN
					IF SELF.path = NIL THEN NEW(SELF.path) END;
					SELF.path.Clear()
				END;
				SELF.useRegion := {Gfx.Clip, Gfx.Fill} * SELF.mode # {};
				SELF.lateStroke := SELF.useRegion & (Gfx.Stroke IN SELF.mode);
				SELF.deferred := FALSE;
				IF SELF.lateStroke THEN
					IF SELF.cp = NIL THEN NEW(SELF.cp) END;
					SELF.cp.Clear()
				END;
				IF Gfx.Stroke IN SELF.mode THEN
					SELF.StrokePrepare()
				END;
				IF SELF.useRegion OR (Gfx.Stroke IN SELF.mode) & (SELF.devWidth > 0.75) THEN
					IF SELF.pathReg = NIL THEN NEW(SELF.pathReg) END;
					IF Gfx.EvenOdd IN SELF.mode THEN
						SELF.pathReg.Init(GfxRegions.EvenOdd)
					ELSE
						SELF.pathReg.Init(GfxRegions.Winding)
					END
				END;
			END Begin;

			PROCEDURE End* ( );
				VAR data: PathData;
			BEGIN
				IF Gfx.Clip IN SELF.mode THEN
					SELF.clipReg.Intersect(SELF.pathReg)
				END;
				IF Gfx.Fill IN SELF.mode THEN
					SELF.pathReg.Intersect(SELF.clipReg);
					IF ~SELF.pathReg.Empty() THEN
						SELF.clipState := In;
						SELF.SetColPat(SELF.fillCol, SELF.fillPat);
						SELF.FillRegion()
					END
				END;
				IF SELF.lateStroke THEN
					SELF.SetColPat(SELF.strokeCol, SELF.strokePat);
					data.context := SELF;
					SELF.cp.Enumerate(StrokePathElem, data)
				END
			END End;

			PROCEDURE Enter* (x, y, dx, dy: REAL);
				VAR u, v, du, dv: REAL;
			BEGIN
				GfxMatrix.Apply(SELF.ctm, x, y, u, v);
				GfxMatrix.ApplyToVector(SELF.ctm, dx, dy, du, dv);
				IF Gfx.Record IN SELF.mode THEN
					SELF.path.AddEnter(u, v, du, dv)
				END;
				IF SELF.lateStroke THEN
					SELF.cp.AddEnter(u, v, du, dv)
				END;
				IF SELF.useRegion THEN
					SELF.EnterLine(u, v);
					SELF.u := u; SELF.v := v
				ELSIF Gfx.Stroke IN SELF.mode THEN
					SELF.StrokeEnter(u, v, du, dv)
				ELSE
					SELF.u := u; SELF.v := v
				END;
				IF (dx = 0) & (dy = 0) THEN
					SELF.deferred := TRUE;
					SELF.u0 := u; SELF.v0 := v
				END;
				SELF.cpx := x; SELF.cpy := y
			END Enter;

			PROCEDURE Exit* (dx, dy: REAL);
				VAR du, dv: REAL;
			BEGIN
				GfxMatrix.ApplyToVector(SELF.ctm, dx, dy, du, dv);
				IF Gfx.Record IN SELF.mode THEN
					SELF.path.AddExit(du, dv)
				END;
				IF SELF.lateStroke THEN
					SELF.cp.AddExit(du, dv)
				END;
				IF ~SELF.useRegion & (Gfx.Stroke IN SELF.mode) THEN
					SELF.StrokeExit(du, dv)
				END;
				SELF.deferred := FALSE
			END Exit;

			PROCEDURE Close* ();
				CONST eps = 0.001;
			BEGIN
				IF ~SELF.deferred THEN
					Exit(0, 0)
				ELSE
					IF (ABS(SELF.u - SELF.u0) > eps) OR (ABS(SELF.v - SELF.v0) > eps) THEN
						IF Gfx.Record IN SELF.mode THEN
							SELF.path.AddLine(SELF.u0, SELF.v0)
						END;
						IF SELF.lateStroke THEN
							SELF.cp.AddLine(SELF.u0, SELF.v0)
						END;
						IF SELF.useRegion THEN
							SELF.AddLine(SELF.u0, SELF.v0)
						ELSIF Gfx.Stroke IN SELF.mode THEN
							SELF.StrokeLineTo(SELF.u0, SELF.v0)
						END
					END;
					IF Gfx.Record IN SELF.mode THEN
						SELF.path.AddExit(0, 0);
						SELF.path.Close()
					END;
					IF SELF.lateStroke THEN
						SELF.cp.AddExit(0, 0);
						SELF.cp.Close()
					END;
					IF ~SELF.useRegion & (Gfx.Stroke IN SELF.mode) THEN
						SELF.StrokeClose()
					END;
					SELF.deferred := FALSE
				END
			END Close;

			PROCEDURE Line* (x, y: REAL);
				VAR u, v: REAL;
			BEGIN
				GfxMatrix.Apply(SELF.ctm, x, y, u, v);
				IF (u # SELF.u) OR (v # SELF.v) THEN
					IF Gfx.Record IN SELF.mode THEN
						SELF.path.AddLine(u, v)
					END;
					IF SELF.lateStroke THEN
						SELF.cp.AddLine(u, v)
					END;
					IF SELF.useRegion THEN
						SELF.AddLine(u, v);
						SELF.u := u; SELF.v := v
					ELSIF Gfx.Stroke IN SELF.mode THEN
						SELF.StrokeLineTo(u, v)
					ELSE
						SELF.u := u; SELF.v := v
					END;
					SELF.cpx := x; SELF.cpy := y
				END
			END Line;

			PROCEDURE Arc* (x, y, x0, y0, x1, y1, x2, y2: REAL);
				VAR u, v, u0, v0, u1, v1, u2, v2, ru, rv: REAL; data: PathData;
			BEGIN
				GfxMatrix.Apply(SELF.ctm, x, y, u, v);
				GfxMatrix.Apply(SELF.ctm, x0, y0, u0, v0);
				GfxMatrix.Apply(SELF.ctm, x1, y1, u1, v1);
				GfxMatrix.Apply(SELF.ctm, x2, y2, u2, v2);
				IF Gfx.Record IN SELF.mode THEN
					SELF.path.AddArc(u, v, u0, v0, u1, v1, u2, v2)
				END;
				IF SELF.lateStroke THEN
					SELF.cp.AddArc(u, v, u0, v0, u1, v1, u2, v2)
				END;
				IF SELF.useRegion THEN
					IF IsEllipse(u0, v0, u1, v1, u2, v2, SELF.u, SELF.v, u, v, SELF.flatness, ru, rv) THEN
						IF ABS(ABS(ru) - ABS(rv)) < SELF.flatness THEN
							IF ru * rv > 0 THEN
								SELF.AddCircle(ENTIER(u0), ENTIER(v0), ENTIER(ABS(ru) + 0.5))
							ELSE
								SELF.AddCircle(ENTIER(u0), ENTIER(v0), -ENTIER(ABS(ru) + 0.5))
							END
						ELSE
							SELF.AddEllipse(ENTIER(u0), ENTIER(v0), ENTIER(ru+0.5), ENTIER(rv+0.5))
						END
					ELSE
						data.context := SELF(Context); data.x := SELF.u; data.y := SELF.v;
						GfxPaths.EnumArc(u0, v0, u1, v1, u2, v2, u, v, SELF.flatness, AddPathElem, data);
						SELF.u := u; SELF.v := v
					END
				ELSIF Gfx.Stroke IN SELF.mode THEN
					IF (SELF.dashPatLen = 0) & (SELF.devWidth <= 0.75) &
						IsEllipse(u0, v0, u1, v1, u2, v2, SELF.u, SELF.v, u, v, SELF.flatness, ru, rv)
					THEN
						IF ABS(ABS(ru) - ABS(rv)) < SELF.flatness THEN
							IF ru * rv > 0 THEN
								SELF.HairCircle(ENTIER(u0), ENTIER(v0), ENTIER(ABS(ru) + 0.5))
							ELSE
								SELF.HairCircle(ENTIER(u0), ENTIER(v0), -ENTIER(ABS(ru) + 0.5))
							END
						ELSE
							SELF.HairEllipse(ENTIER(u0), ENTIER(v0), ENTIER(ABS(ru) + 0.5), ENTIER(ABS(rv) + 0.5))
						END
					ELSE
						data.context := SELF; data.x := SELF.u; data.y := SELF.v;
						GfxPaths.EnumArc(u0, v0, u1, v1, u2, v2, u, v, SELF.flatness, StrokePathElem, data)
					END
				ELSE
					SELF.u := u; SELF.v := v
				END;
				SELF.cpx := x; SELF.cpy := y
			END Arc;

			PROCEDURE Bezier* (x, y, x1, y1, x2, y2: REAL);
				VAR u, v, u1, v1, u2, v2: REAL; data: PathData;
			BEGIN
				GfxMatrix.Apply(SELF.ctm, x, y, u, v);
				GfxMatrix.Apply(SELF.ctm, x1, y1, u1, v1);
				GfxMatrix.Apply(SELF.ctm, x2, y2, u2, v2);
				IF Gfx.Record IN SELF.mode THEN
					SELF.path.AddBezier(u, v, u1, v1, u2, v2)
				END;
				IF SELF.lateStroke THEN
					SELF.cp.AddBezier(u, v, u1, v1, u2, v2)
				END;
				IF SELF.useRegion THEN
					data.context := SELF(Context); data.x := SELF.u; data.y := SELF.v;
					GfxPaths.EnumBezier(u1, v1, u2, v2, u, v, SELF.flatness, AddPathElem, data);
					SELF.u := u; SELF.v := v
				ELSIF Gfx.Stroke IN SELF.mode THEN
					data.context := SELF(Context); data.x := SELF.u; data.y := SELF.v;
					GfxPaths.EnumBezier(u1, v1, u2, v2, u, v, SELF.flatness, StrokePathElem, data)
				END;
				SELF.cpx := x; SELF.cpy := y
			END Bezier;

			PROCEDURE Show* (x, y: REAL; VAR str: ARRAY OF CHAR);
				VAR
					mat: GfxMatrix.Matrix; font: GfxFonts.Font; u, v, bu, bv, du, dv: REAL;
					i: LONGINT; img: GfxImages.Image; data: PathData;
					TmpPath: GfxPaths.Path;	(* was global: cost of making it local? *)
					filter: GfxImages.Filter;
			BEGIN
				GfxMatrix.Concat(SELF.font.mat, SELF.ctm, mat);
				font := GfxFonts.Open(SELF.font.name, SELF.font.ptsize, mat);
				GfxMatrix.Apply(SELF.ctm, x, y, u, v);
				IF (SELF.mode * {Gfx.Record..Gfx.EvenOdd} = {Gfx.Fill}) & (SELF.fillPat = NIL) THEN
					mat := SELF.ctm; SELF.ctm := GfxMatrix.Identity;
					SELF.SetColPat(SELF.fillCol, SELF.fillPat);
					i := 0; GfxImages.InitNoFilter(filter);
					WHILE str[i] # 0X DO
						GfxFonts.GetMap(font, str[i], bu, bv, du, dv, img);
						IF img # NIL THEN
							SELF.Image(u + bu, v + bv, img, filter)
						END;
						u := u + du; v := v + dv;
						INC(i)
					END;
					SELF.ctm := mat
				ELSE
					NEW(TmpPath);
					i := 0;
					WHILE str[i] # 0X DO
						GfxFonts.GetOutline(font, str[i], u, v, TmpPath);
						GfxFonts.GetWidth(font, str[i], du, dv);
						u := u + du; v := v + dv;
						IF Gfx.Record IN SELF.mode THEN
							SELF.path.Append(TmpPath)
						END;
						IF SELF.lateStroke THEN
							SELF.cp.Append(TmpPath)
						END;
						IF SELF.useRegion THEN
							data.context := SELF;
							TmpPath.Enumerate(AddPathElem, data);
							SELF.u := SELF.fu; SELF.v := SELF.fv
						ELSIF Gfx.Stroke IN SELF.mode THEN
							data.context := SELF;
							TmpPath.Enumerate(StrokePathElem, data)
						END;
						INC(i)
					END
				END;
				GfxMatrix.Solve(SELF.ctm, u, v, SELF.cpx, SELF.cpy)
			END Show;

			PROCEDURE Render* (mode: SET);
				VAR data: PathData;
			BEGIN
				IF mode * {Gfx.Clip, Gfx.Fill} # {} THEN
					IF SELF.pathReg = NIL THEN NEW(SELF.pathReg) END;
					IF Gfx.EvenOdd IN mode THEN
						SELF.pathReg.Init(GfxRegions.EvenOdd)
					ELSE
						SELF.pathReg.Init(GfxRegions.Winding)
					END;
					data.context := SELF;
					SELF.path.Enumerate(AddPathElem, data);
					SELF.pathReg.Intersect(SELF.clipReg);
					IF Gfx.Clip IN mode THEN
						SELF.pathReg.Copy(SELF.clipReg)
					END;
					IF Gfx.Fill IN mode THEN
						SELF.clipState := In;
						SELF.SetColPat(SELF.fillCol, SELF.fillPat);
						SELF.FillRegion()
					END
				END;
				IF Gfx.Stroke IN mode THEN
					SELF.cam := SELF.ctm;
					SELF.StrokePrepare();
					IF SELF.devWidth > 0.75 THEN
						IF SELF.pathReg = NIL THEN NEW(SELF.pathReg) END;
						IF Gfx.EvenOdd IN SELF.mode THEN
							SELF.pathReg.Init(GfxRegions.EvenOdd)
						ELSE
							SELF.pathReg.Init(GfxRegions.Winding)
						END
					END;
					data.context := SELF;
					SELF.path.Enumerate(StrokePathElem, data)
				END
			END Render;

			(** painting operators (potential for optimization) **)
			PROCEDURE Rect* (x0, y0, x1, y1: REAL);
				VAR u0, v0, u1, v1, t: REAL; enter, exit, llx, lly, urx, ury: INTEGER;
			BEGIN
				IF ~(Gfx.Record IN SELF.mode) & ~GfxMatrix.Rotated(SELF.ctm) THEN
					GfxMatrix.Apply(SELF.ctm, x0, y0, u0, v0);
					GfxMatrix.Apply(SELF.ctm, x1, y1, u1, v1);
					enter := -1; exit := 1;
					IF u0 > u1 THEN t := u0; u0 := u1; u1 := t END;
					IF v0 > v1 THEN t := v0; v0 := v1; v1 := t; enter := -enter; exit := -exit END;
					IF SELF.lateStroke THEN
						SELF.cp.AddRect(u0, v0, u1, v1)
					END;
					IF SELF.useRegion THEN
						llx := SHORT(ENTIER(u0 + 0.5)); lly := SHORT(ENTIER(v0 + 0.5));
						urx := SHORT(ENTIER(u1 + 0.5)); ury := SHORT(ENTIER(v1 + 0.5));
						IF Gfx.Clip IN SELF.mode THEN
							WHILE lly < ury DO
								SELF.pathReg.AddPoint(llx, lly, enter);
								INC(lly);
								SELF.pathReg.AddPoint(urx, lly, exit)
							END
						ELSIF SELF.clipReg.RectOverlaps(llx, lly, urx, ury) THEN
							IF SELF.clipReg.RectInside(llx, lly, urx, ury) THEN SELF.clipState := In
							ELSE SELF.clipState := InOut
							END;
							SELF.SetColPat(SELF.fillCol, SELF.fillPat);
							SELF.FillRect(llx, lly, urx, ury)
						END
					ELSIF Gfx.Stroke IN SELF.mode THEN
						IF (SELF.dashPatLen > 0) OR (SELF.devWidth > 0.75) THEN
							SELF.StrokeEnter(u0, v0, 0, v0 - v1);
							SELF.StrokeLineTo(u1, v0); SELF.StrokeLineTo(u1, v1); SELF.StrokeLineTo(u0, v1); SELF.StrokeLineTo(u0, v0);
							SELF.StrokeExit(u1 - u0, 0)
						ELSE
							llx := SHORT(ENTIER(u0)); lly := SHORT(ENTIER(v0));
							urx := SHORT(ENTIER(u1)); ury := SHORT(ENTIER(v1));
							IF SELF.clipReg.RectOverlaps(llx, lly, urx, ury) THEN
								IF SELF.clipReg.RectInside(llx, lly, urx, ury) THEN SELF.clipState := In
								ELSE SELF.clipState := InOut
								END;
								SELF.FillRect(llx, lly, urx, lly+1); SELF.FillRect(urx, lly, urx+1, ury+1);
								SELF.FillRect(llx, ury, urx, ury+1); SELF.FillRect(llx, lly+1, llx+1, ury)
							END
						END
					END
				ELSE
					Gfx.DefRect(SELF, x0, y0, x1, y1)
				END
			END Rect;

			PROCEDURE Ellipse* (x, y, rx, ry: REAL);
				VAR u, v, ru, rv: REAL; data: PathData;
			BEGIN
				IF ~(Gfx.Record IN SELF.mode) & ~GfxMatrix.Rotated(SELF.ctm) THEN
					GfxMatrix.Apply(SELF.ctm, x, y, u, v);
					GfxMatrix.ApplyToVector(SELF.ctm, rx, ry, ru, rv);
					IF SELF.lateStroke THEN
						SELF.cp.AddEnter(u + ru, v, 0, rv);
						SELF.cp.AddArc(u + ru, v, u, v, u + ru, v, u, v + rv);
						SELF.cp.AddExit(0, rv)
					END;
					IF SELF.useRegion THEN
						IF ABS(ABS(ru) - ABS(rv)) < SELF.flatness THEN
							IF ru * rv > 0 THEN SELF.AddCircle(ENTIER(u), ENTIER(v), ENTIER(ABS(ru) + 0.5))
							ELSE SELF.AddCircle(ENTIER(u), ENTIER(v), -ENTIER(ABS(rv) + 0.5))
							END
						ELSE
							SELF.AddEllipse(ENTIER(u), ENTIER(v), ENTIER(ru + 0.5), ENTIER(rv + 0.5))
						END
					ELSIF Gfx.Stroke IN SELF.mode THEN
						IF (SELF.dashPatLen = 0) & (SELF.devWidth <= 0.75) THEN
							IF ABS(ABS(ru) - ABS(rv)) < SELF.flatness THEN
								IF ru * rv > 0 THEN SELF.HairCircle(ENTIER(u), ENTIER(v), ENTIER(ABS(ru) + 0.5))
								ELSE SELF.HairCircle(ENTIER(u), ENTIER(v), -ENTIER(ABS(ru) + 0.5))
								END
							ELSE
								SELF.HairEllipse(ENTIER(u), ENTIER(v), ENTIER(ru + 0.5), ENTIER(rv + 0.5))
							END
						ELSE
							SELF.StrokeEnter(u + ru, v, 0, rv);
							data.context := SELF; data.x := SELF.u; data.y := SELF.v;
							GfxPaths.EnumArc(u, v, u + ru, v, u, v + rv, u + ru, v, SELF.flatness, StrokePathElem, data);
							SELF.StrokeExit(0, rv)
						END
					END
				ELSE
					Gfx.DefEllipse(SELF, x, y, rx, ry)
				END
			END Ellipse;

			(**--- Clipping ---**)

			PROCEDURE InitClipState (x, y: INTEGER);
			BEGIN
				SELF.plx := x - SELF.border; SELF.ply := y - SELF.border;
				SELF.prx := x + SELF.border; SELF.puy := y + SELF.border;
				IF SELF.clipReg.RectInside(SELF.plx, SELF.ply, SELF.prx, SELF.puy) THEN
					SELF.clipState := In
				ELSIF SELF.clipReg.RectOverlaps(SELF.plx, SELF.ply, SELF.prx, SELF.puy) THEN
					SELF.clipState := InOut
				ELSE
					SELF.clipState := Out
				END
			END InitClipState;

			PROCEDURE UpdateClipState (x, y: INTEGER);
				VAR plx, ply, prx, puy: INTEGER;
			BEGIN
				plx := x - SELF.border; ply := y - SELF.border; prx := x + SELF.border; puy := y + SELF.border;
				GfxRegions.IncludeRect(SELF.plx, SELF.ply, SELF.prx, SELF.puy, plx, ply, prx, puy);
				IF SELF.clipReg.RectInside(SELF.plx, SELF.ply, SELF.prx, SELF.puy) THEN
					SELF.clipState := In
				ELSIF SELF.clipReg.RectOverlaps(SELF.plx, SELF.ply, SELF.prx, SELF.puy) THEN
					SELF.clipState := InOut
				ELSE
					SELF.clipState := Out
				END;
				SELF.plx := plx; SELF.ply := ply; SELF.prx := prx; SELF.puy := puy
			END UpdateClipState;


			(*--- Hairlines ---*)

			PROCEDURE HairLineEnter (u, v: REAL);
			BEGIN
				SELF.u := u; SELF.v := v;
				SELF.px := ENTIER(u); SELF.py := ENTIER(v);
				SELF.InitClipState(SHORT(SELF.px), SHORT(SELF.py));
				SELF.FillDot(SELF.px, SELF.py)
			END HairLineEnter;

			PROCEDURE HairLineTo (u, v: REAL);
				VAR px, py, xstep, ystep, steps: LONGINT; du, dv, eu, ev, e: REAL;
			BEGIN
				px := ENTIER(u); py := ENTIER(v);
				SELF.UpdateClipState(SHORT(px), SHORT(py));
				IF px = SELF.px THEN	(* horizontal line *)
					IF py > SELF.py THEN SELF.FillRect(px, SELF.py + 1, px + 1, py + 1)
					ELSIF py < SELF.py THEN SELF.FillRect(px, py, px + 1, SELF.py)
					END;
					SELF.py := py
				ELSIF py = SELF.py THEN	(* vertical line *)
					IF px > SELF.px THEN SELF.FillRect(SELF.px + 1, py, px + 1, py + 1)
					ELSE SELF.FillRect(px, py, SELF.px, py + 1)
					END;
					SELF.px := px
				ELSE
					du := u - SELF.u; dv := v - SELF.v;

					(* bring parameters into first quadrant *)
					IF du >= 0 THEN xstep := 1; eu := SELF.u - (SELF.px + 0.5)
					ELSE xstep := -1; du := -du; eu := SELF.px + 0.5 - SELF.u
					END;
					IF dv >= 0 THEN ystep := 1; ev := SELF.v - (SELF.py + 0.5)
					ELSE ystep := -1; dv := -dv; ev := SELF.py + 0.5 - SELF.v
					END;

					IF du >= dv THEN	(* x-dominant case *)
						e := du * ev - dv * eu + dv - 0.5*du;
						steps := ABS(px - SELF.px);
						WHILE steps > 0 DO
							IF (e >= 0) & ((e > 0) OR (ystep <= 0)) THEN
								INC(SELF.py, ystep); e := e - du
							END;
							INC(SELF.px, xstep); e := e + dv;
							SELF.FillDot(SELF.px, SELF.py);
							DEC(steps)
						END
					ELSE	(* y-dominant case *)
						e := dv * eu - du * ev + du - 0.5*dv;
						steps := ABS(py - SELF.py);
						WHILE steps > 0 DO
							IF (e >= 0) & ((e > 0) OR (xstep <= 0)) THEN
								INC(SELF.px, xstep); e := e - dv
							END;
							INC(SELF.py, ystep); e := e + du;
							SELF.FillDot(SELF.px, SELF.py);
							DEC(steps)
						END
					END
				END;
				SELF.u := u; SELF.v := v
			END HairLineTo;

			PROCEDURE HairCircle (mx, my, r: LONGINT);
				VAR llx, lly, urx, ury: INTEGER; x, y, d, de, dse: LONGINT;
			BEGIN
				llx := SHORT(mx - r); lly := SHORT(my - r); urx := SHORT(mx + r + 1); ury := SHORT(my + r + 1);
				IF SELF.clipReg.RectOverlaps(llx, lly, urx, ury) THEN
					IF SELF.clipReg.RectInside(llx, lly, urx, ury) THEN SELF.clipState := In
					ELSE SELF.clipState := InOut
					END;
					x := 0; y := r; d := 1-r; de := 3; dse := -2*r + 5;
					SELF.FillDot(mx, my + y); SELF.FillDot(mx, my - y); SELF.FillDot(mx + y, my); SELF.FillDot(mx - y, my);
					WHILE y > x DO
						IF d < 0 THEN
							INC(d, de); INC(de, 2); INC(dse, 2); INC(x)
						ELSE
							INC(d, dse); INC(de, 2); INC(dse, 4); INC(x); DEC(y)
						END;
						SELF.FillDot(mx + x, my + y); SELF.FillDot(mx + y, my + x);
						SELF.FillDot(mx + x, my - y); SELF.FillDot(mx - y, my + x);
						SELF.FillDot(mx - x, my - y); SELF.FillDot(mx - y, my - x);
						SELF.FillDot(mx - x, my + y); SELF.FillDot(mx + y, my - x)
					END
				END
			END HairCircle;

			PROCEDURE HairEllipse (mx, my, rx, ry: LONGINT);
				VAR llx, lly, urx, ury: INTEGER; x, y, aa, bb, da, db, dy, dx, d: LONGINT;
			BEGIN
				llx := SHORT(mx - rx); lly := SHORT(my - ry); urx := SHORT(mx + rx + 1); ury := SHORT(my + ry + 1);
				IF SELF.clipReg.RectOverlaps(llx, lly, urx, ury) THEN
					IF SELF.clipReg.RectInside(llx, lly, urx, ury) THEN SELF.clipState := In
					ELSE SELF.clipState := InOut
					END;
					x := rx; y := 0;
					aa := rx * rx; bb := ry * ry;
					da := -8*aa; db := -8*bb;
					dy := -4*aa; dx := -db * (x-1);
					d := bb * (4*x - 1);
					WHILE db * x < da * y DO
						SELF.FillDot(mx + x, my + y); SELF.FillDot(mx + x, my - y);
						SELF.FillDot(mx - x, my + y); SELF.FillDot(mx - x, my - y);
						INC(d, dy); INC(dy, da); INC(y);
						IF d < 0 THEN
							INC(d, dx); INC(dx, db); DEC(x)
						END
					END;
					dx := 4 * bb * (2*x - 1); dy := da * (y+1);
					d := d - bb * (4*x - 1) - aa * (4*y + 1);
					WHILE x >= 0 DO
						SELF.FillDot(mx + x, my + y); SELF.FillDot(mx + x, my - y);
						SELF.FillDot(mx - x, my + y); SELF.FillDot(mx - x, my - y);
						INC(d, dx); INC(dx, db); DEC(x);
						IF d >= 0 THEN
							INC(d, dy); INC(dy, da); INC(y)
						END
					END
				END
			END HairEllipse;

			(*--- Filled Areas ---*)

			PROCEDURE EnterLine (u, v: REAL);
			BEGIN
				SELF.fu := u; SELF.fv := v;
				SELF.px := ENTIER(u + 0.5); SELF.py := ENTIER(v + 0.5);
			END EnterLine;

			PROCEDURE AddLine (u, v: REAL);
				VAR px, py, x, y, xstep, ystep, steps: LONGINT; du, dv, eu, ev, e: REAL;
			BEGIN
				px := ENTIER(u + 0.5); py := ENTIER(v + 0.5);
				x := SELF.px; y := SELF.py;
				IF py = y THEN	(* horizontal line => ignore *)
					SELF.px := px
				ELSE
					du := u - SELF.fu; dv := v - SELF.fv;
					IF du >= 0 THEN xstep := 1; eu := SELF.fu - x
					ELSE xstep := -1; du := -du; eu := x - SELF.fu
					END;
					IF dv >= 0 THEN ystep := 1; ev := SELF.fv - y
					ELSE ystep := -1; dv := -dv; ev := y - SELF.fv
					END;
					e := du * ev - dv * eu + 0.5 * (dv - du);
					steps := ABS(px - x) + ABS(py - y);
					WHILE steps > 0 DO
						IF (e >= 0) & ((e > 0) OR (xstep <= 0)) THEN
							INC(y, ystep); e := e - du;
							SELF.pathReg.AddPoint(SHORT(x), SHORT(y), SHORT(ystep))
						ELSE
							INC(x, xstep); e := e + dv
							(* don't have to insert point here because regions are sliced horizontally *)
						END;
						DEC(steps)
					END;
					SELF.px := px; SELF.py := py
				END;
				SELF.fu := u; SELF.fv := v
			END AddLine;

			PROCEDURE AddCircle (mx, my, r: LONGINT);
				VAR x, y, d, de, ds, sgn: LONGINT;
			BEGIN
				x := 0; y := r; d := 1-r; de := 3; ds := -2*r + 2;
				IF r > 0 THEN sgn := 1 ELSE sgn := -1 END;
				WHILE y > x DO
					REPEAT
						INC(d, de); INC(de, 2); INC(x, sgn)
					UNTIL d >= 0;
					SELF.pathReg.AddPoint(SHORT(mx - x), SHORT(my + y), 1);
					SELF.pathReg.AddPoint(SHORT(mx + x), SHORT(my - y), -1);
					INC(d, ds); INC(ds, 2); DEC(y);
					SELF.pathReg.AddPoint(SHORT(mx + x), SHORT(my + y), -1);
					SELF.pathReg.AddPoint(SHORT(mx - x), SHORT(my - y), 1)
				END;
				WHILE y > 0 DO
					IF d <= 0 THEN
						INC(d, de); INC(de, 2); INC(x, sgn)
					END;
					SELF.pathReg.AddPoint(SHORT(mx - x), SHORT(my + y), 1);
					SELF.pathReg.AddPoint(SHORT(mx + x), SHORT(my - y), -1);
					INC(d, ds); INC(ds, 2); DEC(y);
					SELF.pathReg.AddPoint(SHORT(mx + x), SHORT(my + y), -1);
					SELF.pathReg.AddPoint(SHORT(mx - x), SHORT(my - y), 1)
				END
			END AddCircle;

			PROCEDURE AddEllipse (mx, my, rx, ry: LONGINT);
				VAR x, y, aa, bb, da, db, dy, dx, d, sgn: LONGINT;
			BEGIN
				x := ABS(rx); y := 0;
				aa := rx * rx; bb := ry * ry;
				da := -8*aa; db := -8*bb;
				dy := -4*aa; dx := -db * (x-1);
				d := bb * (4*x - 1);
				IF rx * ry > 0 THEN sgn := 1
				ELSE x := -x; sgn := -1
				END;
				WHILE db * x * sgn < da * y DO
					SELF.pathReg.AddPoint(SHORT(mx + x), SHORT(my + y), -1);
					SELF.pathReg.AddPoint(SHORT(mx - x), SHORT(my - y), 1);
					INC(y);
					SELF.pathReg.AddPoint(SHORT(mx - x), SHORT(my + y), 1);
					SELF.pathReg.AddPoint(SHORT(mx + x), SHORT(my - y), -1);
					IF d < 0 THEN
						INC(d, dx); INC(dx, db); DEC(x, sgn)
					END;
					INC(d, dy); INC(dy, da)
				END;
				dx := 4 * bb * (2*ABS(x) - 1); dy := da * (y+1);
				d := d - bb * (4*ABS(x) - 1) - aa * (4*y + 1);
				WHILE x * sgn > 0 DO
					SELF.pathReg.AddPoint(SHORT(mx + x), SHORT(my + y), -1);
					SELF.pathReg.AddPoint(SHORT(mx - x), SHORT(my - y), 1);
					INC(y);
					SELF.pathReg.AddPoint(SHORT(mx - x), SHORT(my + y), 1);
					SELF.pathReg.AddPoint(SHORT(mx + x), SHORT(my - y), -1);
					REPEAT
						INC(d, dx); INC(dx, db); DEC(x, sgn)
					UNTIL d >= 0;
					INC(d, dy); INC(dy, da)
				END
			END AddEllipse;

			PROCEDURE FillRegion ();
				VAR data: RegData; reg: GfxRegions.Region;
			BEGIN
				reg := SELF.pathReg;
				IF ~reg.Empty() THEN
					data.context := SELF;
					reg.Enumerate(reg.llx, reg.lly, reg.urx, reg.ury, EnumRegion, data)
				END
			END FillRegion;

			(*--- Thick Lines ---*)

			PROCEDURE StrokeHalfJoin (cu, cv, u, v, du, dv, hu, hv: REAL; part: LONGINT);
				VAR limit, bu, bv, t: REAL; data: PathData;
			BEGIN
				IF (hu # 0) OR (hv # 0) THEN
					IF du * hv > dv * hu THEN
						du := -du; dv := -dv; part := 1 - part	(* turn right turns into left turns *)
					END;
					limit := SELF.devWidth * SELF.styleLimit;
					IF part = 0 THEN
						IF (SELF.joinStyle = Gfx.BevelJoin) OR (SELF.joinStyle = Gfx.MiterJoin) & (hu * hu + hv * hv > limit * limit) THEN
							GfxPaths.IntersectLines(cu, cv, hu, hv, cu + dv, cv - du, -hv, hu, bu, bv);
							SELF.EnterLine(bu, bv); SELF.AddLine(cu + dv, cv - du)
						ELSIF SELF.joinStyle = Gfx.MiterJoin THEN
							bu := cu + hu; bv := cv + hv; SELF.EnterLine(bu, bv); SELF.AddLine(cu + dv, cv - du)
						ELSIF SELF.joinStyle = Gfx.RoundJoin THEN
							t := Math.sqrt((du * du + dv * dv)/(hu * hu + hv * hv));
							bu := cu + t * hu; bv := cv + t * hv; SELF.EnterLine(bu, bv);
							data.context := SELF; data.x := SELF.fu; data.y := SELF.fv;
							GfxPaths.EnumArc(cu, cv, cu - du, cv - dv, cu + dv, cv - du, cu + dv, cv - du, SELF.flatness, AddPathElem, data)
						ELSE
							bu := cu + dv; bv := cv - du;
							SELF.EnterLine(bu, bv)
						END;
						SELF.AddLine(u + dv, v - du); SELF.AddLine(u - dv, v + du); SELF.AddLine(cu, cv); SELF.AddLine(bu, bv)
					ELSE (* part = 1 *)
						SELF.EnterLine(cu, cv); SELF.AddLine(u - dv, v + du); SELF.AddLine(u + dv, v - du); SELF.AddLine(cu + dv, cv - du);
						IF (SELF.joinStyle = Gfx.BevelJoin) OR (SELF.joinStyle = Gfx.MiterJoin) & (hu * hu + hv * hv > limit * limit) THEN
							GfxPaths.IntersectLines(cu, cv, hu, hv, cu + dv, cv - du, -hv, hu, bu, bv);
							SELF.AddLine(bu, bv)
						ELSIF SELF.joinStyle = Gfx.MiterJoin THEN
							SELF.AddLine(cu + hu, cv + hv)
						ELSIF SELF.joinStyle = Gfx.RoundJoin THEN
							t := Math.sqrt((du * du + dv * dv)/(hu * hu + hv * hv));
							data.context := SELF; data.x := SELF.fu; data.y := SELF.fv;
							GfxPaths.EnumArc(cu, cv, cu - du, cv - dv, cu + dv, cv - du, cu + t * hu, cv + t * hv, SELF.flatness, AddPathElem, data)
						END;
						SELF.AddLine(cu, cv)
					END
				END
			END StrokeHalfJoin;

			PROCEDURE StrokeFullJoin (su, sv, cu, cv, eu, ev, idu, idv, odu, odv, hu, hv: REAL);
				VAR t, limit: REAL; data: PathData;
			BEGIN
				IF (hu # 0) OR (hv # 0) THEN
					IF idu * odv < idv * odu THEN	(* turn right turns into left turns *)
						t := idu; idu := -odu; odu := -t;
						t := idv; idv := -odv; odv := -t;
						t := su; su := eu; eu := t;
						t := sv; sv := ev; ev := t
					END;
					limit := SELF.devWidth * SELF.styleLimit;
					SELF.EnterLine(su - idv, sv + idu); SELF.AddLine(su + idv, sv - idu); SELF.AddLine(cu + idv, cv - idu);
					IF (SELF.joinStyle = Gfx.BevelJoin) OR (SELF.joinStyle = Gfx.MiterJoin) & (hu * hu + hv * hv > limit * limit) THEN
						SELF.AddLine(cu + odv, cv - odu)
					ELSIF SELF.joinStyle = Gfx.MiterJoin THEN
						SELF.AddLine(cu + hu, cv + hv)
					ELSIF SELF.joinStyle = Gfx.RoundJoin THEN
						data.context := SELF; data.x := SELF.fu; data.y := SELF.fv;
						GfxPaths.EnumArc(cu, cv, cu + idv, cv - idu, cu + idu, cv + idv, cu + odv, cv - odu, SELF.flatness, AddPathElem, data)
					ELSE
						SELF.AddLine(cu, cv); SELF.AddLine(cu + odv, cv - odu)
					END;
					SELF.AddLine(eu + odv, ev - odu); SELF.AddLine(eu - odv, ev + odu); SELF.AddLine(su - idv, sv + idu)
				END
			END StrokeFullJoin;

			PROCEDURE StrokeCap (u, v, du, dv: REAL);
				VAR data: PathData;
			BEGIN
				IF SELF.capStyle = Gfx.RoundCap THEN
					SELF.EnterLine(u - dv, v + du);
					data.context := SELF; data.x := SELF.fu; data.y := SELF.fv;
					GfxPaths.EnumArc(u, v, u - dv, v + du, u - du, v - dv, u + dv, v - du, SELF.flatness, AddPathElem, data);
					SELF.AddLine(u - dv, v + du)
				ELSIF SELF.capStyle = Gfx.SquareCap THEN
					SELF.EnterLine(u - dv, v + du);
					SELF.AddLine(u - du - dv, v - dv + du); SELF.AddLine(u - du + dv, v - dv - du); SELF.AddLine(u + dv, v - du);
					SELF.AddLine(u - dv, v + du)
				END
			END StrokeCap;

			PROCEDURE ThickVerticalLine (lu, v0, v1: REAL);
				VAR left, right, bot, top: LONGINT;
			BEGIN
				IF v0 < v1 THEN
					left := ENTIER(lu + 0.5); right := left + ENTIER(2*SELF.devWidth + 0.5);
					bot := ENTIER(v0 + 0.5); top := ENTIER(v1 + 0.5)
				ELSE
					right := ENTIER(lu + 0.5); left := right - ENTIER(2*SELF.devWidth + 0.5);
					bot := ENTIER(v1 + 0.5); top := ENTIER(v0 + 0.5)
				END;
				SELF.FillRect(SHORT(left), SHORT(bot), SHORT(right), SHORT(top))
			END ThickVerticalLine;

			PROCEDURE ThickHorizontalLine (rv, u0, u1: REAL);
				VAR left, right, bot, top: LONGINT;
			BEGIN
				IF u0 < u1 THEN
					left := ENTIER(u0 + 0.5); right := ENTIER(u1 + 0.5);
					bot := ENTIER(rv + 0.5); top := bot + ENTIER(2*SELF.devWidth + 0.5)
				ELSE
					left := ENTIER(u1 + 0.5); right := ENTIER(u0 + 0.5);
					top := ENTIER(rv + 0.5); bot := top - ENTIER(2*SELF.devWidth + 0.5)
				END;
				SELF.FillRect(SHORT(left), SHORT(bot), SHORT(right), SHORT(top))
			END ThickHorizontalLine;

			PROCEDURE ThickLine (su, sv, eu, ev, du, dv: REAL);
			BEGIN
				IF ABS(eu - su) < 0.5 THEN
					SELF.ThickVerticalLine(su - dv, sv, ev)
				ELSIF ABS(ev - sv) < 0.5 THEN
					SELF.ThickHorizontalLine(sv - du, su, eu)
				ELSE
					SELF.EnterLine(su - dv, sv + du);
					SELF.AddLine(su + dv, sv - du); SELF.AddLine(eu + dv, ev - du);
					SELF.AddLine(eu - dv, ev + du); SELF.AddLine(su - dv, sv + du)
				END
			END ThickLine;

			PROCEDURE ThickEnter (u, v, idu, idv: REAL);
			BEGIN
				SELF.su := u; SELF.sv := v;
				SELF.u := u; SELF.v := v;
				SELF.du := idu; SELF.dv := idv;
				SELF.InitClipState(SHORT(ENTIER(u)), SHORT(ENTIER(v)))
			END ThickEnter;

			PROCEDURE ThickLineTo (u, v: REAL);
				VAR cu, cv, idu, idv, odu, odv, hu, hv, tu, tv: REAL;
			BEGIN
				cu := SELF.u; cv := SELF.v;
				idu := SELF.du; idv := SELF.dv;
				Gfx.GetNormVector(u - cu, v - cv, SELF.devWidth, odu, odv);
				IF (cu = SELF.su) & (cv = SELF.sv) THEN	(* first call *)
					IF SELF.deferred THEN	(* defer rendering of starting cap in case path is later closed *)
						SELF.u1 := u; SELF.v1 := v;	(* remember direction of first line *)
						SELF.tu := cu; SELF.tv := cv
					ELSE	(* render initial joint *)
						Gfx.GetNormVector(idu, idv, SELF.devWidth, idu, idv);
						Gfx.GetHalfAxisVector(idu, idv, odu, odv, hu, hv);
						IF (hu = 0) & (hv = 0) THEN
							SELF.tu := cu; SELF.tv := cv
						ELSE
							TrimJoinLength(cu, cv, 0.5*(cu + u), 0.5*(cv + v), odu, odv, hu, hv, SELF.tu, SELF.tv);
							SELF.StrokeHalfJoin(cu, cv, SELF.tu, SELF.tv, odu, odv, hu, hv, 0)
						END
					END
				ELSE
					SELF.UpdateClipState(SHORT(ENTIER(cu)), SHORT(ENTIER(cv)));
					Gfx.GetHalfAxisVector(idu, idv, odu, odv, hu, hv);
					IF (hu = 0) & (hv = 0) THEN
						tu := cu; tv := cv
					ELSE
						TrimJoinLength(cu, cv, SELF.tu, SELF.tv, -idu, -idv, hu, hv, tu, tv)
					END;
					IF (tu - SELF.tu) * idu + (tv - SELF.tv) * idv > 0 THEN
						SELF.ThickLine(SELF.tu, SELF.tv, tu, tv, idu, idv)
					END;
					IF (hu = 0) & (hv = 0) THEN
						SELF.tu := cu; SELF.tv := cv
					ELSE
						TrimJoinLength(cu, cv, 0.5*(cu + u), 0.5*(cv + v), odu, odv, hu, hv, SELF.tu, SELF.tv);
						SELF.StrokeFullJoin(tu, tv, cu, cv, SELF.tu, SELF.tv, idu, idv, odu, odv, hu, hv)
					END
				END;
				SELF.su := cu; SELF.sv := cv;
				SELF.u := u; SELF.v := v;
				SELF.du := odu; SELF.dv := odv
			END ThickLineTo;

			PROCEDURE ThickExit (odu, odv: REAL);
				VAR cu, cv, idu, idv, hu, hv, tu, tv: REAL;
			BEGIN
				cu := SELF.u; cv := SELF.v;
				IF (cu # SELF.su) OR (cv # SELF.sv) THEN	(* at least one thick line was rendered *)
					idu := SELF.du; idv := SELF.dv;
					SELF.UpdateClipState(SHORT(ENTIER(cu)), SHORT(ENTIER(cv)));
					IF (odu = 0) & (odv = 0) THEN
						SELF.ThickLine(SELF.tu, SELF.tv, cu, cv, idu, idv);
						SELF.StrokeCap(cu, cv, -idu, -idv)
					ELSE
						Gfx.GetNormVector(odu, odv, SELF.devWidth, odu, odv);
						Gfx.GetHalfAxisVector(idu, idv, odu, odv, hu, hv);
						IF (hu = 0) & (hv = 0) THEN
							tu := cu; tv := cv
						ELSE
							TrimJoinLength(cu, cv, SELF.tu, SELF.tv, -idu, -idv, hu, hv, tu, tv)
						END;
						IF (tu - SELF.tu) * idu + (tv - SELF.tv) * idv > 0 THEN
							SELF.ThickLine(SELF.tu, SELF.tv, tu, tv, idu, idv)
						END;
						IF (hu # 0) OR (hv # 0) THEN
							SELF.StrokeHalfJoin(cu, cv, tu, tv, idu, idv, hu, hv, 1)
						END
					END;
					IF SELF.deferred THEN	(* render cap at start pos *)
						SELF.InitClipState(SHORT(ENTIER(SELF.u0)), SHORT(ENTIER(SELF.v0)));
						Gfx.GetNormVector(SELF.u1 - SELF.u0, SELF.v1 - SELF.v0, SELF.devWidth, odu, odv);
						SELF.StrokeCap(SELF.u0, SELF.v0, odu, odv)
					END
				END
			END ThickExit;

			PROCEDURE ThickClose ();
				VAR cu, cv, idu, idv, odu, odv, hu, hv, tu, tv, eu, ev: REAL;
			BEGIN
				cu := SELF.u; cv := SELF.v; idu := SELF.du; idv := SELF.dv;
				SELF.UpdateClipState(SHORT(ENTIER(cu)), SHORT(ENTIER(cv)));
				Gfx.GetNormVector(SELF.u1 - SELF.u0, SELF.v1 - SELF.v0, SELF.devWidth, odu, odv);
				Gfx.GetHalfAxisVector(idu, idv, odu, odv, hu, hv);
				IF (hu = 0) & (hv = 0) THEN
					tu := cu; tv := cv
				ELSE
					TrimJoinLength(cu, cv, SELF.tu, SELF.tv, -idu, -idv, hu, hv, tu, tv)
				END;
				IF (tu - SELF.tu) * idu + (tv - SELF.tv) * idv > 0 THEN
					SELF.ThickLine(SELF.tu, SELF.tv, tu, tv, idu, idv)
				END;
				IF (hu # 0) OR (hv # 0) THEN
					TrimJoinLength(cu, cv, 0.5*(cu + SELF.u1), 0.5*(cv + SELF.v1), odu, odv, hu, hv, eu, ev);
					SELF.StrokeFullJoin(tu, tv, cu, cv, eu, ev, idu, idv, odu, odv, hu, hv)
				END
			END ThickClose;


			(*--- Dashed Lines ---*)

			PROCEDURE DashEnter (su, sv, idu, idv: REAL);
				VAR beg, end, next: REAL; index: LONGINT;
			BEGIN
				SELF.offset := 0;
				Gfx.GetDashOffsets(SELF, 0, beg, end, next, index);
				IF end > 0 THEN
					IF SELF.devWidth <= 0.75 THEN SELF.HairLineEnter(su, sv)
					ELSE SELF.ThickEnter(su, sv, idu, idv)
					END
				ELSE
					SELF.u := su; SELF.v := sv
				END
			END DashEnter;

			PROCEDURE DashLineTo (u, v: REAL);
				VAR
					cu, cv, du, dv, len, cos, sin, wdu, wdv, offset, beg, end, next, dash, tu, tv, u1, v1: REAL;
					index: LONGINT; deferred: BOOLEAN;
			BEGIN
				cu := SELF.u; cv := SELF.v;
				du := u - cu; dv := v - cv;
				len := Math.sqrt(du * du + dv * dv);
				cos := du/len; sin := dv/len;
				wdu := SELF.devWidth * cos; wdv := SELF.devWidth * sin;
				offset := SELF.offset; SELF.offset := offset + len;
				Gfx.GetDashOffsets(SELF, offset, beg, end, next, index);
				IF offset < end THEN	(* inside dash *)
					IF end <= SELF.offset THEN	(* finish current dash *)
						len := end - offset;
						IF SELF.devWidth <= 0.75 THEN
							SELF.HairLineTo(cu + len * cos, cv + len * sin)
						ELSE
							SELF.ThickLineTo(cu + len * cos, cv + len * sin);	(* sets u1/v1 if first line in subpath *)
							deferred := SELF.deferred; SELF.deferred := FALSE;
							SELF.ThickExit(0, 0);
							SELF.deferred := deferred
						END
					ELSIF SELF.devWidth <= 0.75 THEN
						SELF.HairLineTo(u, v)
					ELSE
						SELF.ThickLineTo(u, v)
					END
				END;
				beg := offset;
				LOOP
					len := next - beg;
					cu := cu + len * cos; cv := cv + len * sin;
					beg := next;
					GfxMatrix.ApplyToDist(SELF.cam, SELF.dashPatOn[index], dash);
					end := beg + dash;
					GfxMatrix.ApplyToDist(SELF.cam, SELF.dashPatOff[index], dash);
					next := end + dash;
					index := (index+1) MOD SELF.dashPatLen;
					IF end > SELF.offset THEN EXIT END;
					len := end - beg;
					IF SELF.devWidth <= 0.75 THEN
						SELF.HairLineEnter(cu, cv);
						SELF.HairLineTo(cu + len * cos, cv + len * sin)
					ELSE
						SELF.StrokeCap(cu, cv, wdu, wdv);
						SELF.InitClipState(SHORT(ENTIER(cu)), SHORT(ENTIER(cv)));
						tu := cu + len * cos; tv := cv + len * sin;
						SELF.UpdateClipState(SHORT(ENTIER(tu)), SHORT(ENTIER(tv)));
						SELF.ThickLine(cu, cv, tu, tv, wdu, wdv);
						SELF.StrokeCap(tu, tv, -wdu, -wdv)
					END
				END;
				IF beg <= SELF.offset THEN	(* begin next dash *)
					IF SELF.devWidth <= 0.75 THEN
						SELF.HairLineEnter(cu, cv);
						SELF.HairLineTo(u, v)
					ELSE
						u1 := SELF.u1; v1 := SELF.v1;
						SELF.StrokeCap(cu, cv, wdu, wdv);
						SELF.ThickEnter(cu, cv, 0, 0);
						SELF.ThickLineTo(u, v);
						SELF.u1 := u1; SELF.v1 := v1	(* restore original point *)
					END
				ELSE
					SELF.u := u; SELF.v := v
				END
			END DashLineTo;

			PROCEDURE DashExit (odu, odv: REAL);
				VAR beg, end, next: REAL; index: LONGINT;
			BEGIN
				IF SELF.devWidth > 0.75 THEN
					Gfx.GetDashOffsets(SELF, SELF.offset, beg, end, next, index);
					IF (beg < SELF.offset) & (SELF.offset < end) THEN
						SELF.ThickExit(odu, odv)
					END
				END
			END DashExit;

			PROCEDURE DashClose ();
				VAR beg, end, next: REAL; index: LONGINT;
			BEGIN
				IF SELF.deferred & (SELF.devWidth > 0.75) THEN
					Gfx.GetDashOffsets(SELF, SELF.offset, beg, end, next, index);
					IF (beg < SELF.offset) & (SELF.offset < end) THEN
						SELF.ThickClose()
					END
				END
			END DashClose;


			(*--- Stroking ---*)

			PROCEDURE StrokePrepare ();
			BEGIN
				GfxMatrix.ApplyToDist(SELF.cam, 0.5*SELF.lineWidth, SELF.devWidth);
				IF SELF.devWidth <= 0.75 THEN
					SELF.border := 1
				ELSE
					SELF.border := -SHORT(ENTIER(-SELF.devWidth * SELF.styleLimit));
				END;
				SELF.SetColPat(SELF.strokeCol, SELF.strokePat)
			END StrokePrepare;

			PROCEDURE StrokeEnter (u, v, du, dv: REAL);
			BEGIN
				IF SELF.devWidth > 0.75 THEN
					SELF.pathReg.Clear()
				END;
				IF SELF.dashPatLen > 0 THEN
					SELF.DashEnter(u, v, du, dv)
				ELSIF SELF.devWidth <= 0.75 THEN
					SELF.HairLineEnter(u, v)
				ELSE
					SELF.ThickEnter(u, v, du, dv)
				END
			END StrokeEnter;

			PROCEDURE StrokeLineTo (u, v: REAL);
			BEGIN
				IF SELF.dashPatLen > 0 THEN
					SELF.DashLineTo(u, v)
				ELSIF SELF.devWidth <= 0.75 THEN
					SELF.HairLineTo(u, v)
				ELSE
					SELF.ThickLineTo(u, v)
				END
			END StrokeLineTo;

			PROCEDURE StrokeExit (du, dv: REAL);
			BEGIN
				IF SELF.dashPatLen > 0 THEN
					SELF.DashExit(du, dv)
				ELSIF SELF.devWidth > 0.75 THEN
					SELF.ThickExit(du, dv)
				END;
				IF SELF.devWidth > 0.75 THEN
					SELF.pathReg.Intersect(SELF.clipReg);
					IF ~SELF.pathReg.Empty() THEN
						SELF.clipState := In;
						SELF.FillRegion()
					END
				END
			END StrokeExit;

			PROCEDURE StrokeClose ();
			BEGIN
				IF SELF.dashPatLen > 0 THEN
					SELF.DashClose()
				ELSIF SELF.devWidth > 0.75 THEN
					SELF.ThickClose()
				END;
				IF SELF.devWidth > 0.75 THEN
					SELF.pathReg.Intersect(SELF.clipReg);
					IF ~SELF.pathReg.Empty() THEN
						SELF.clipState := In;
						SELF.FillRegion()
					END
				END
			END StrokeClose;

		END Context;

		(* path data for filling paths *)
		PathData = RECORD (GfxPaths.EnumData)
			context: Context;
		END;

		RegData = RECORD (GfxRegions.EnumData)
			context: Context;
		END;


	(**--- Ellipse Test ---**)

	(** return if arc parameter describe axis-aligned ellipse and, if so, the radii in x and y direction **)
	PROCEDURE IsEllipse* (x0, y0, x1, y1, x2, y2, sx, sy, ex, ey, flatness: REAL; VAR rx, ry: REAL): BOOLEAN;
		CONST eps = 0.01;
		VAR x, y: REAL;
	BEGIN
		IF (ABS(x1 - x0) < eps) & (ABS(y2 - y0) < eps) THEN
			rx := x0 - x2; ry := y0 - y1
		ELSIF (ABS(x2 - x0) < eps) & (ABS(y1 - y0) < eps) THEN
			rx := x1 - x0; ry := y2 - y0
		ELSE
			RETURN FALSE
		END;
		flatness := 0.25*flatness;
		IF (ABS(rx - ENTIER(rx + 0.5)) < flatness) & (ABS(ry - ENTIER(ry + 0.5)) < flatness) &
			(ABS(x0 - 0.5 - ENTIER(x0)) < flatness) & (ABS(y0 - 0.5 - ENTIER(y0)) < flatness) &
			(ABS(sx - ex) < eps) & (ABS(sy - ey) < eps)
		THEN
			GfxPaths.ProjectToEllipse(rx, 0, 0, ry, sx, sy, x, y);
			RETURN (ABS(sx - x) < eps) & (ABS(sy - y) < eps)
		ELSE
			RETURN FALSE
		END
	END IsEllipse;

	(**--- Clipping ---**)

	PROCEDURE ResetClip* (ctxt: Gfx.Context);
	BEGIN
		ctxt.ResetClip();
	END ResetClip;

	PROCEDURE GetClipRect* (ctxt: Gfx.Context; VAR llx, lly, urx, ury: REAL);
	BEGIN
		ctxt.GetClipRect(llx, lly, urx, ury);
	END GetClipRect;

	PROCEDURE GetClip* (ctxt: Gfx.Context): Gfx.ClipArea;
	BEGIN
		RETURN ctxt.GetClip()
	END GetClip;

	PROCEDURE SetClip* (ctxt: Gfx.Context; clip: Gfx.ClipArea);
	BEGIN
		ctxt.SetClip(clip);
	END SetClip;

	PROCEDURE EnumRegion (lx, ly, rx, uy: INTEGER; VAR data: GfxRegions.EnumData);
		VAR rc: Context;
	BEGIN
		rc := data(RegData).context;
		rc.FillRect(lx, ly, rx, uy)
	END EnumRegion;

	PROCEDURE AddPathElem (VAR data: GfxPaths.EnumData);
		VAR rc: Context; x, y: REAL;
	BEGIN
		rc := data(PathData).context;
		CASE data.elem OF
		| GfxPaths.Enter:
			rc.EnterLine(data.x, data.y)
		| GfxPaths.Line:
			rc.AddLine(data.x, data.y)
		| GfxPaths.Arc:
			IF IsEllipse(data.x0, data.y0, data.x1, data.y1, data.x2, data.y2, data.x, data.y, rc.u, rc.v, rc.flatness, x, y) THEN
				IF ABS(ABS(x) - ABS(y)) < rc.flatness THEN
					IF x * y > 0 THEN
						rc.AddCircle(ENTIER(data.x0), ENTIER(data.y0), ENTIER(ABS(x) + 0.5))
					ELSE
						rc.AddCircle(ENTIER(data.x0), ENTIER(data.y0), -ENTIER(ABS(x) + 0.5))
					END
				ELSE
					rc.AddEllipse(ENTIER(data.x0), ENTIER(data.y0), ENTIER(x+0.5), ENTIER(y+0.5))
				END
			ELSE
				x := data.x; y := data.y;
				data.x := rc.fu; data.y := rc.fv;
				GfxPaths.EnumArc(data.x0, data.y0, data.x1, data.y1, data.x2, data.y2, x, y, rc.flatness, AddPathElem, data)
			END
		| GfxPaths.Bezier:
			x := data.x; y := data.y;
			data.x := rc.fu; data.y := rc.fv;
			GfxPaths.EnumBezier(data.x1, data.y1, data.x2, data.y2, x, y, rc.flatness, AddPathElem, data)
		| GfxPaths.Exit:
		END
	END AddPathElem;

	PROCEDURE TrimJoinLength (cu, cv, u, v, du, dv, hu, hv: REAL; VAR tu, tv: REAL);
	BEGIN
		IF (u - cu + hu) * du + (v - cv + hv) * dv < 0 THEN	(* joint is longer than allowed *)
			tu := u; tv := v
		ELSIF du * hv > dv * hu THEN	(* right turn *)
			tu := cu - hu - dv; tv := cv - hv + du
		ELSE
			tu := cu - hu + dv; tv := cv - hv - du
		END
	END TrimJoinLength;

	PROCEDURE StrokePathElem (VAR data: GfxPaths.EnumData);
		VAR rc: Context; x, y: REAL;
	BEGIN
		rc := data(PathData).context;
		CASE data.elem OF
		| GfxPaths.Enter:
			rc.StrokeEnter(data.x, data.y, data.dx, data.dy)
		| GfxPaths.Line:
			IF (data.x # rc.u) OR (data.y # rc.v) THEN
				rc.StrokeLineTo(data.x, data.y)
			END
		| GfxPaths.Arc:
			IF (rc.dashPatLen = 0) & (rc.devWidth <= 0.75) &
				IsEllipse(data.x0, data.y0, data.x1, data.y1, data.x2, data.y2, data.x, data.y, rc.u, rc.v, rc.flatness, x, y)
			THEN
				IF ABS(ABS(x) - ABS(y)) < rc.flatness THEN
					IF x * y > 0 THEN
						rc.HairCircle(ENTIER(data.x0), ENTIER(data.y0), ENTIER(ABS(x) + 0.5))
					ELSE
						rc.HairCircle(ENTIER(data.x0), ENTIER(data.y0), -ENTIER(ABS(x) + 0.5))
					END
				ELSE
					rc.HairEllipse(ENTIER(data.x0), ENTIER(data.y0), ENTIER(ABS(x) + 0.5), ENTIER(ABS(y) + 0.5))
				END
			ELSE
				x := data.x; y := data.y;
				data.x := rc.u; data.y := rc.v;
				GfxPaths.EnumArc(data.x0, data.y0, data.x1, data.y1, data.x2, data.y2, x, y, rc.flatness, StrokePathElem, data)
			END
		| GfxPaths.Bezier:
			x := data.x; y := data.y;
			data.x := rc.u; data.y := rc.v;
			GfxPaths.EnumBezier(data.x1, data.y1, data.x2, data.y2, x, y, rc.flatness, StrokePathElem, data)
		| GfxPaths.Exit:
			rc.StrokeExit(data.dx, data.dy)
		END
	END StrokePathElem;

	(**--- Path Methods ---**)

	PROCEDURE Begin* (ctxt: Gfx.Context; mode: SET);
	BEGIN
		ctxt.Begin(mode);
	END Begin;

	PROCEDURE End* (ctxt: Gfx.Context);
	BEGIN
		ctxt.End();
	END End;

	PROCEDURE Enter* (ctxt: Gfx.Context; x, y, dx, dy: REAL);
	BEGIN
		ctxt.Enter(x, y, dx, dy);
	END Enter;

	PROCEDURE Exit* (ctxt: Gfx.Context; dx, dy: REAL);
	BEGIN
		ctxt.Exit(dx, dy);
	END Exit;

	PROCEDURE Close* (ctxt: Gfx.Context);
	BEGIN
		ctxt.Close();
	END Close;

	PROCEDURE Line* (ctxt: Gfx.Context; x, y: REAL);
	BEGIN
		ctxt.Line(x, y);
	END Line;

	PROCEDURE Arc* (ctxt: Gfx.Context; x, y, x0, y0, x1, y1, x2, y2: REAL);
	BEGIN
		ctxt.Arc(x, y, x0, y0, x1, y1, x2, y2);
	END Arc;

	PROCEDURE Bezier* (ctxt: Gfx.Context; x, y, x1, y1, x2, y2: REAL);
	BEGIN
		ctxt.Bezier(x, y, x1, y1, x2, y2);
	END Bezier;

	PROCEDURE Show* (ctxt: Gfx.Context; x, y: REAL; VAR str: ARRAY OF CHAR);
	BEGIN
		ctxt.Show(x, y, str);
	END Show;

	PROCEDURE Render* (ctxt: Gfx.Context; mode: SET);
	BEGIN
		ctxt.Render(mode);
	END Render;

	PROCEDURE Rect* (ctxt: Gfx.Context; x0, y0, x1, y1: REAL);
	BEGIN
		ctxt.Rect(x0, y0, x1, y1);
	END Rect;

	PROCEDURE Ellipse* (ctxt: Gfx.Context; x, y, rx, ry: REAL);
	BEGIN
		ctxt.Ellipse(x, y, rx, ry);
	END Ellipse;


	(**--- Raster Contexts ---**)

	PROCEDURE SetColPat* (rc: Context; col: Gfx.Color; pat: Gfx.Pattern);
	BEGIN
		rc.SetColPat(col, pat);
	END SetColPat;

	(** initialize raster context **)
	PROCEDURE InitContext* (rc: Context);
	BEGIN
		rc.InitRaster();
	END InitContext;

END GfxRaster.
