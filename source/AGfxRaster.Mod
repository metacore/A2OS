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
		Context* = OBJECT (Gfx.Context)
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
(*				SELF.InitContext( );*)
				IF SELF.clipReg = NIL THEN
					NEW(SELF.clipReg);
				END;
				SELF.clipReg.Init(GfxRegions.Winding)
			END InitRaster;

			PROCEDURE SetColPat* (col: Gfx.Color; pat: Gfx.Pattern);
			BEGIN
				SELF.col := col; SELF.pat := pat
			END SetColPat;

		(**--- Coordinate System ---**)

			(** reset current transformation matrix **)
			PROCEDURE{ABSTRACT} ResetCTM*(); END ResetCTM;

		(**--- Clipping ---**)

			(** reset clip path **)
			PROCEDURE{ABSTRACT} ResetClip*();
			BEGIN
				SELF.clipReg.Clear()
			END ResetClip;

			(** get bounding box of clipping path in user coordinates **)
			PROCEDURE GetClipRect*(VAR llx, lly, urx, ury: REAL);
				VAR inv: GfxMatrix.Matrix; reg: GfxRegions.Region;
			BEGIN
				GfxMatrix.Invert(SELF.ctm, inv);
				reg := SELF.clipReg;
				GfxMatrix.ApplyToRect(inv, reg.llx, reg.lly, reg.urx, reg.ury, llx, lly, urx, ury)
			END GetClipRect;

			(** get current clipping area **)
			PROCEDURE GetClip*(): Gfx.ClipArea;
				VAR clip: ClipArea;
			BEGIN
				NEW(clip); NEW(clip.reg); SELF.clipReg.Copy(clip.reg);
				RETURN clip
			END GetClip;

			(** restore saved clipping path **)
			PROCEDURE SetClip*(clip: Gfx.ClipArea);
			BEGIN
				ASSERT(clip IS ClipArea, 100);
				clip(ClipArea).reg.Copy(SELF.clipReg)
			END SetClip;

		(**--- Current Path ---**)
			
			(** start new path **)
			PROCEDURE DoBegin*(mode: SET);
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
					StrokePrepare(SELF)
				END;
				IF SELF.useRegion OR (Gfx.Stroke IN SELF.mode) & (SELF.devWidth > 0.75) THEN
					IF SELF.pathReg = NIL THEN NEW(SELF.pathReg) END;
					IF Gfx.EvenOdd IN SELF.mode THEN
						SELF.pathReg.Init(GfxRegions.EvenOdd)
					ELSE
						SELF.pathReg.Init(GfxRegions.Winding)
					END
				END
			END DoBegin;

			(** exit current subpath (if open) and end current path **)
			PROCEDURE DoEnd*();
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
						FillRegion(SELF)
					END
				END;
				IF SELF.lateStroke THEN
					SELF.SetColPat(SELF.strokeCol, SELF.strokePat);
					data.context := SELF;
					SELF.cp.Enumerate(StrokePathElem, data)
				END
			END DoEnd;

			(** start subpath at inner point **)
			PROCEDURE DoEnter*(x, y, dx, dy: REAL);
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
					EnterLine(SELF, u, v);
					SELF.u := u; SELF.v := v
				ELSIF Gfx.Stroke IN SELF.mode THEN
					StrokeEnter(SELF, u, v, du, dv)
				ELSE
					SELF.u := u; SELF.v := v
				END;
				IF (dx = 0) & (dy = 0) THEN
					SELF.deferred := TRUE;
					SELF.u0 := u; SELF.v0 := v
				END;
				SELF.cpx := x; SELF.cpy := y
			END DoEnter;

			(** end subpath at inner point **)
			PROCEDURE DoExit*(dx, dy: REAL);
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
					StrokeExit(SELF, du, dv)
				END;
				SELF.deferred := FALSE
			END DoExit;

			(** close current subpath **)
			PROCEDURE DoClose*();
				CONST eps = 0.001;
			BEGIN
				IF ~SELF.deferred THEN
					SELF.DoExit(0, 0)
				ELSE
					IF (ABS(SELF.u - SELF.u0) > eps) OR (ABS(SELF.v - SELF.v0) > eps) THEN
						IF Gfx.Record IN SELF.mode THEN
							SELF.path.AddLine(SELF.u0, SELF.v0)
						END;
						IF SELF.lateStroke THEN
							SELF.cp.AddLine(SELF.u0, SELF.v0)
						END;
						IF SELF.useRegion THEN
							AddLine(SELF, SELF.u0, SELF.v0)
						ELSIF Gfx.Stroke IN SELF.mode THEN
							StrokeLineTo(SELF, SELF.u0, SELF.v0)
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
						StrokeClose(SELF)
					END;
					SELF.deferred := FALSE
				END
			END DoClose;

			(** append line to current path **)
			PROCEDURE DoLine*(x, y: REAL);
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
						AddLine(SELF, u, v);
						SELF.u := u; SELF.v := v
					ELSIF Gfx.Stroke IN SELF.mode THEN
						StrokeLineTo(SELF, u, v)
					ELSE
						SELF.u := u; SELF.v := v
					END;
					SELF.cpx := x; SELF.cpy := y
				END
			END DoLine;

			(** append arc to current path **)
			PROCEDURE DoArc*(x, y, x0, y0, x1, y1, x2, y2: REAL);
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
								AddCircle(SELF, ENTIER(u0), ENTIER(v0), ENTIER(ABS(ru) + 0.5))
							ELSE
								AddCircle(SELF, ENTIER(u0), ENTIER(v0), -ENTIER(ABS(ru) + 0.5))
							END
						ELSE
							AddEllipse(SELF, ENTIER(u0), ENTIER(v0), ENTIER(ru+0.5), ENTIER(rv+0.5))
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
								HairCircle(SELF, ENTIER(u0), ENTIER(v0), ENTIER(ABS(ru) + 0.5))
							ELSE
								HairCircle(SELF, ENTIER(u0), ENTIER(v0), -ENTIER(ABS(ru) + 0.5))
							END
						ELSE
							HairEllipse(SELF, ENTIER(u0), ENTIER(v0), ENTIER(ABS(ru) + 0.5), ENTIER(ABS(rv) + 0.5))
						END
					ELSE
						data.context := SELF; data.x := SELF.u; data.y := SELF.v;
						GfxPaths.EnumArc(u0, v0, u1, v1, u2, v2, u, v, SELF.flatness, StrokePathElem, data)
					END
				ELSE
					SELF.u := u; SELF.v := v
				END;
				SELF.cpx := x; SELF.cpy := y
			END DoArc;

			(** append cubic bezier to current path **)
			PROCEDURE DoBezier*(x, y, x1, y1, x2, y2: REAL);
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
			END DoBezier;

			(** painting operators (potential for optimization) **)
			PROCEDURE DoRect*(x0, y0, x1, y1: REAL);
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
							SELF.rect(llx, lly, urx, ury)
						END
					ELSIF Gfx.Stroke IN SELF.mode THEN
						IF (SELF.dashPatLen > 0) OR (SELF.devWidth > 0.75) THEN
							StrokeEnter(SELF, u0, v0, 0, v0 - v1);
							StrokeLineTo(SELF, u1, v0); StrokeLineTo(SELF, u1, v1); StrokeLineTo(SELF, u0, v1); StrokeLineTo(SELF, u0, v0);
							StrokeExit(SELF, u1 - u0, 0)
						ELSE
							llx := SHORT(ENTIER(u0)); lly := SHORT(ENTIER(v0));
							urx := SHORT(ENTIER(u1)); ury := SHORT(ENTIER(v1));
							IF SELF.clipReg.RectOverlaps(llx, lly, urx, ury) THEN
								IF SELF.clipReg.RectInside(llx, lly, urx, ury) THEN SELF.clipState := In
								ELSE SELF.clipState := InOut
								END;
								SELF.rect(llx, lly, urx, lly+1); SELF.rect(urx, lly, urx+1, ury+1);
								SELF.rect(llx, ury, urx, ury+1); SELF.rect(llx, lly+1, llx+1, ury)
							END
						END
					END
				ELSE
					SELF.DoRect^(x0, y0, x1, y1); (* default implementation *)
				END
			END DoRect;

			PROCEDURE DoEllipse*(x, y, rx, ry: REAL);
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
							IF ru * rv > 0 THEN AddCircle(SELF, ENTIER(u), ENTIER(v), ENTIER(ABS(ru) + 0.5))
							ELSE AddCircle(SELF, ENTIER(u), ENTIER(v), -ENTIER(ABS(rv) + 0.5))
							END
						ELSE
							AddEllipse(SELF, ENTIER(u), ENTIER(v), ENTIER(ru + 0.5), ENTIER(rv + 0.5))
						END
					ELSIF Gfx.Stroke IN SELF.mode THEN
						IF (SELF.dashPatLen = 0) & (SELF.devWidth <= 0.75) THEN
							IF ABS(ABS(ru) - ABS(rv)) < SELF.flatness THEN
								IF ru * rv > 0 THEN HairCircle(SELF, ENTIER(u), ENTIER(v), ENTIER(ABS(ru) + 0.5))
								ELSE HairCircle(SELF, ENTIER(u), ENTIER(v), -ENTIER(ABS(ru) + 0.5))
								END
							ELSE
								HairEllipse(SELF, ENTIER(u), ENTIER(v), ENTIER(ru + 0.5), ENTIER(rv + 0.5))
							END
						ELSE
							StrokeEnter(SELF, u + ru, v, 0, rv);
							data.context := SELF; data.x := SELF.u; data.y := SELF.v;
							GfxPaths.EnumArc(u, v, u + ru, v, u, v + rv, u + ru, v, SELF.flatness, StrokePathElem, data);
							StrokeExit(SELF, 0, rv)
						END
					END
				ELSE
					SELF.DoEllipse^(x, y, rx, ry)
				END
			END DoEllipse;

			(** append character outlines to current path at current point; advance current point to position after last character **)
			PROCEDURE DoShow*(x, y: REAL; VAR str: ARRAY OF CHAR);
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
							SELF.DrawImage(u + bu, v + bv, img, filter)
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
			END DoShow;

			PROCEDURE DoRender*(mode: SET);
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
						FillRegion(SELF)
					END
				END;
				IF Gfx.Stroke IN mode THEN
					SELF.cam := SELF.ctm;
					StrokePrepare(SELF);
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
			END DoRender;

			(** images and patterns **)
			PROCEDURE{ABSTRACT} DrawImage*(x, y: REAL; img: GfxImages.Image; VAR filter: GfxImages.Filter); END DrawImage;

			PROCEDURE{ABSTRACT} dot*(x, y: LONGINT); END dot; (** current dot procedure **)
			PROCEDURE{ABSTRACT} rect*(lx, ly, rx, uy: LONGINT); END rect; (** current rect procedure **)
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

	PROCEDURE InitClipState (rc: Context; x, y: INTEGER);
	BEGIN
		rc.plx := x - rc.border; rc.ply := y - rc.border;
		rc.prx := x + rc.border; rc.puy := y + rc.border;
		IF rc.clipReg.RectInside(rc.plx, rc.ply, rc.prx, rc.puy) THEN
			rc.clipState := In
		ELSIF rc.clipReg.RectOverlaps(rc.plx, rc.ply, rc.prx, rc.puy) THEN
			rc.clipState := InOut
		ELSE
			rc.clipState := Out
		END
	END InitClipState;

	PROCEDURE UpdateClipState (rc: Context; x, y: INTEGER);
		VAR plx, ply, prx, puy: INTEGER;
	BEGIN
		plx := x - rc.border; ply := y - rc.border; prx := x + rc.border; puy := y + rc.border;
		GfxRegions.IncludeRect(rc.plx, rc.ply, rc.prx, rc.puy, plx, ply, prx, puy);
		IF rc.clipReg.RectInside(rc.plx, rc.ply, rc.prx, rc.puy) THEN
			rc.clipState := In
		ELSIF rc.clipReg.RectOverlaps(rc.plx, rc.ply, rc.prx, rc.puy) THEN
			rc.clipState := InOut
		ELSE
			rc.clipState := Out
		END;
		rc.plx := plx; rc.ply := ply; rc.prx := prx; rc.puy := puy
	END UpdateClipState;


	(*--- Hairlines ---*)

	PROCEDURE HairLineEnter (rc: Context; u, v: REAL);
	BEGIN
		rc.u := u; rc.v := v;
		rc.px := ENTIER(u); rc.py := ENTIER(v);
		InitClipState(rc, SHORT(rc.px), SHORT(rc.py));
		rc.dot(rc.px, rc.py)
	END HairLineEnter;

	PROCEDURE HairLineTo (rc: Context; u, v: REAL);
		VAR px, py, xstep, ystep, steps: LONGINT; du, dv, eu, ev, e: REAL;
	BEGIN
		px := ENTIER(u); py := ENTIER(v);
		UpdateClipState(rc, SHORT(px), SHORT(py));
		IF px = rc.px THEN	(* horizontal line *)
			IF py > rc.py THEN rc.rect(px, rc.py + 1, px + 1, py + 1)
			ELSIF py < rc.py THEN rc.rect(px, py, px + 1, rc.py)
			END;
			rc.py := py
		ELSIF py = rc.py THEN	(* vertical line *)
			IF px > rc.px THEN rc.rect(rc.px + 1, py, px + 1, py + 1)
			ELSE rc.rect(px, py, rc.px, py + 1)
			END;
			rc.px := px
		ELSE
			du := u - rc.u; dv := v - rc.v;

			(* bring parameters into first quadrant *)
			IF du >= 0 THEN xstep := 1; eu := rc.u - (rc.px + 0.5)
			ELSE xstep := -1; du := -du; eu := rc.px + 0.5 - rc.u
			END;
			IF dv >= 0 THEN ystep := 1; ev := rc.v - (rc.py + 0.5)
			ELSE ystep := -1; dv := -dv; ev := rc.py + 0.5 - rc.v
			END;

			IF du >= dv THEN	(* x-dominant case *)
				e := du * ev - dv * eu + dv - 0.5*du;
				steps := ABS(px - rc.px);
				WHILE steps > 0 DO
					IF (e >= 0) & ((e > 0) OR (ystep <= 0)) THEN
						INC(rc.py, ystep); e := e - du
					END;
					INC(rc.px, xstep); e := e + dv;
					rc.dot(rc.px, rc.py);
					DEC(steps)
				END
			ELSE	(* y-dominant case *)
				e := dv * eu - du * ev + du - 0.5*dv;
				steps := ABS(py - rc.py);
				WHILE steps > 0 DO
					IF (e >= 0) & ((e > 0) OR (xstep <= 0)) THEN
						INC(rc.px, xstep); e := e - dv
					END;
					INC(rc.py, ystep); e := e + du;
					rc.dot(rc.px, rc.py);
					DEC(steps)
				END
			END
		END;
		rc.u := u; rc.v := v
	END HairLineTo;

	PROCEDURE HairCircle (rc: Context; mx, my, r: LONGINT);
		VAR llx, lly, urx, ury: INTEGER; x, y, d, de, dse: LONGINT;
	BEGIN
		llx := SHORT(mx - r); lly := SHORT(my - r); urx := SHORT(mx + r + 1); ury := SHORT(my + r + 1);
		IF rc.clipReg.RectOverlaps(llx, lly, urx, ury) THEN
			IF rc.clipReg.RectInside(llx, lly, urx, ury) THEN rc.clipState := In
			ELSE rc.clipState := InOut
			END;
			x := 0; y := r; d := 1-r; de := 3; dse := -2*r + 5;
			rc.dot(mx, my + y); rc.dot(mx, my - y); rc.dot(mx + y, my); rc.dot(mx - y, my);
			WHILE y > x DO
				IF d < 0 THEN
					INC(d, de); INC(de, 2); INC(dse, 2); INC(x)
				ELSE
					INC(d, dse); INC(de, 2); INC(dse, 4); INC(x); DEC(y)
				END;
				rc.dot(mx + x, my + y); rc.dot(mx + y, my + x);
				rc.dot(mx + x, my - y); rc.dot(mx - y, my + x);
				rc.dot(mx - x, my - y); rc.dot(mx - y, my - x);
				rc.dot(mx - x, my + y); rc.dot(mx + y, my - x)
			END
		END
	END HairCircle;

	PROCEDURE HairEllipse (rc: Context; mx, my, rx, ry: LONGINT);
		VAR llx, lly, urx, ury: INTEGER; x, y, aa, bb, da, db, dy, dx, d: LONGINT;
	BEGIN
		llx := SHORT(mx - rx); lly := SHORT(my - ry); urx := SHORT(mx + rx + 1); ury := SHORT(my + ry + 1);
		IF rc.clipReg.RectOverlaps(llx, lly, urx, ury) THEN
			IF rc.clipReg.RectInside(llx, lly, urx, ury) THEN rc.clipState := In
			ELSE rc.clipState := InOut
			END;
			x := rx; y := 0;
			aa := rx * rx; bb := ry * ry;
			da := -8*aa; db := -8*bb;
			dy := -4*aa; dx := -db * (x-1);
			d := bb * (4*x - 1);
			WHILE db * x < da * y DO
				rc.dot(mx + x, my + y); rc.dot(mx + x, my - y);
				rc.dot(mx - x, my + y); rc.dot(mx - x, my - y);
				INC(d, dy); INC(dy, da); INC(y);
				IF d < 0 THEN
					INC(d, dx); INC(dx, db); DEC(x)
				END
			END;
			dx := 4 * bb * (2*x - 1); dy := da * (y+1);
			d := d - bb * (4*x - 1) - aa * (4*y + 1);
			WHILE x >= 0 DO
				rc.dot(mx + x, my + y); rc.dot(mx + x, my - y);
				rc.dot(mx - x, my + y); rc.dot(mx - x, my - y);
				INC(d, dx); INC(dx, db); DEC(x);
				IF d >= 0 THEN
					INC(d, dy); INC(dy, da); INC(y)
				END
			END
		END
	END HairEllipse;


	(*--- Filled Areas ---*)

	PROCEDURE EnterLine (rc: Context; u, v: REAL);
	BEGIN
		rc.fu := u; rc.fv := v;
		rc.px := ENTIER(u + 0.5); rc.py := ENTIER(v + 0.5);
	END EnterLine;

	PROCEDURE AddLine (rc: Context; u, v: REAL);
		VAR px, py, x, y, xstep, ystep, steps: LONGINT; du, dv, eu, ev, e: REAL;
	BEGIN
		px := ENTIER(u + 0.5); py := ENTIER(v + 0.5);
		x := rc.px; y := rc.py;
		IF py = y THEN	(* horizontal line => ignore *)
			rc.px := px
		ELSE
			du := u - rc.fu; dv := v - rc.fv;
			IF du >= 0 THEN xstep := 1; eu := rc.fu - x
			ELSE xstep := -1; du := -du; eu := x - rc.fu
			END;
			IF dv >= 0 THEN ystep := 1; ev := rc.fv - y
			ELSE ystep := -1; dv := -dv; ev := y - rc.fv
			END;
			e := du * ev - dv * eu + 0.5 * (dv - du);
			steps := ABS(px - x) + ABS(py - y);
			WHILE steps > 0 DO
				IF (e >= 0) & ((e > 0) OR (xstep <= 0)) THEN
					INC(y, ystep); e := e - du;
					rc.pathReg.AddPoint(SHORT(x), SHORT(y), SHORT(ystep))
				ELSE
					INC(x, xstep); e := e + dv
					(* don't have to insert point here because regions are sliced horizontally *)
				END;
				DEC(steps)
			END;
			rc.px := px; rc.py := py
		END;
		rc.fu := u; rc.fv := v
	END AddLine;

	PROCEDURE AddCircle (rc: Context; mx, my, r: LONGINT);
		VAR x, y, d, de, ds, sgn: LONGINT;
	BEGIN
		x := 0; y := r; d := 1-r; de := 3; ds := -2*r + 2;
		IF r > 0 THEN sgn := 1 ELSE sgn := -1 END;
		WHILE y > x DO
			REPEAT
				INC(d, de); INC(de, 2); INC(x, sgn)
			UNTIL d >= 0;
			rc.pathReg.AddPoint(SHORT(mx - x), SHORT(my + y), 1);
			rc.pathReg.AddPoint(SHORT(mx + x), SHORT(my - y), -1);
			INC(d, ds); INC(ds, 2); DEC(y);
			rc.pathReg.AddPoint(SHORT(mx + x), SHORT(my + y), -1);
			rc.pathReg.AddPoint(SHORT(mx - x), SHORT(my - y), 1)
		END;
		WHILE y > 0 DO
			IF d <= 0 THEN
				INC(d, de); INC(de, 2); INC(x, sgn)
			END;
			rc.pathReg.AddPoint(SHORT(mx - x), SHORT(my + y), 1);
			rc.pathReg.AddPoint(SHORT(mx + x), SHORT(my - y), -1);
			INC(d, ds); INC(ds, 2); DEC(y);
			rc.pathReg.AddPoint(SHORT(mx + x), SHORT(my + y), -1);
			rc.pathReg.AddPoint(SHORT(mx - x), SHORT(my - y), 1)
		END
	END AddCircle;

	PROCEDURE AddEllipse (rc: Context; mx, my, rx, ry: LONGINT);
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
			rc.pathReg.AddPoint(SHORT(mx + x), SHORT(my + y), -1);
			rc.pathReg.AddPoint(SHORT(mx - x), SHORT(my - y), 1);
			INC(y);
			rc.pathReg.AddPoint(SHORT(mx - x), SHORT(my + y), 1);
			rc.pathReg.AddPoint(SHORT(mx + x), SHORT(my - y), -1);
			IF d < 0 THEN
				INC(d, dx); INC(dx, db); DEC(x, sgn)
			END;
			INC(d, dy); INC(dy, da)
		END;
		dx := 4 * bb * (2*ABS(x) - 1); dy := da * (y+1);
		d := d - bb * (4*ABS(x) - 1) - aa * (4*y + 1);
		WHILE x * sgn > 0 DO
			rc.pathReg.AddPoint(SHORT(mx + x), SHORT(my + y), -1);
			rc.pathReg.AddPoint(SHORT(mx - x), SHORT(my - y), 1);
			INC(y);
			rc.pathReg.AddPoint(SHORT(mx - x), SHORT(my + y), 1);
			rc.pathReg.AddPoint(SHORT(mx + x), SHORT(my - y), -1);
			REPEAT
				INC(d, dx); INC(dx, db); DEC(x, sgn)
			UNTIL d >= 0;
			INC(d, dy); INC(dy, da)
		END
	END AddEllipse;

	PROCEDURE EnumRegion (lx, ly, rx, uy: INTEGER; VAR data: GfxRegions.EnumData);
		VAR rc: Context;
	BEGIN
		rc := data(RegData).context;
		rc.rect(lx, ly, rx, uy)
	END EnumRegion;

	PROCEDURE FillRegion (rc: Context);
		VAR data: RegData; reg: GfxRegions.Region;
	BEGIN
		reg := rc.pathReg;
		IF ~reg.Empty() THEN
			data.context := rc;
			reg.Enumerate(reg.llx, reg.lly, reg.urx, reg.ury, EnumRegion, data)
		END
	END FillRegion;

	PROCEDURE AddPathElem (VAR data: GfxPaths.EnumData);
		VAR rc: Context; x, y: REAL;
	BEGIN
		rc := data(PathData).context;
		CASE data.elem OF
		| GfxPaths.Enter:
			EnterLine(rc, data.x, data.y)
		| GfxPaths.Line:
			AddLine(rc, data.x, data.y)
		| GfxPaths.Arc:
			IF IsEllipse(data.x0, data.y0, data.x1, data.y1, data.x2, data.y2, data.x, data.y, rc.u, rc.v, rc.flatness, x, y) THEN
				IF ABS(ABS(x) - ABS(y)) < rc.flatness THEN
					IF x * y > 0 THEN
						AddCircle(rc, ENTIER(data.x0), ENTIER(data.y0), ENTIER(ABS(x) + 0.5))
					ELSE
						AddCircle(rc, ENTIER(data.x0), ENTIER(data.y0), -ENTIER(ABS(x) + 0.5))
					END
				ELSE
					AddEllipse(rc, ENTIER(data.x0), ENTIER(data.y0), ENTIER(x+0.5), ENTIER(y+0.5))
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


	(*--- Thick Lines ---*)

	PROCEDURE StrokeHalfJoin (rc: Context; cu, cv, u, v, du, dv, hu, hv: REAL; part: LONGINT);
		VAR limit, bu, bv, t: REAL; data: PathData;
	BEGIN
		IF (hu # 0) OR (hv # 0) THEN
			IF du * hv > dv * hu THEN
				du := -du; dv := -dv; part := 1 - part	(* turn right turns into left turns *)
			END;
			limit := rc.devWidth * rc.styleLimit;
			IF part = 0 THEN
				IF (rc.joinStyle = Gfx.BevelJoin) OR (rc.joinStyle = Gfx.MiterJoin) & (hu * hu + hv * hv > limit * limit) THEN
					GfxPaths.IntersectLines(cu, cv, hu, hv, cu + dv, cv - du, -hv, hu, bu, bv);
					EnterLine(rc, bu, bv); AddLine(rc, cu + dv, cv - du)
				ELSIF rc.joinStyle = Gfx.MiterJoin THEN
					bu := cu + hu; bv := cv + hv; EnterLine(rc, bu, bv); AddLine(rc, cu + dv, cv - du)
				ELSIF rc.joinStyle = Gfx.RoundJoin THEN
					t := Math.sqrt((du * du + dv * dv)/(hu * hu + hv * hv));
					bu := cu + t * hu; bv := cv + t * hv; EnterLine(rc, bu, bv);
					data.context := rc; data.x := rc.fu; data.y := rc.fv;
					GfxPaths.EnumArc(cu, cv, cu - du, cv - dv, cu + dv, cv - du, cu + dv, cv - du, rc.flatness, AddPathElem, data)
				ELSE
					bu := cu + dv; bv := cv - du;
					EnterLine(rc, bu, bv)
				END;
				AddLine(rc, u + dv, v - du); AddLine(rc, u - dv, v + du); AddLine(rc, cu, cv); AddLine(rc, bu, bv)
			ELSE (* part = 1 *)
				EnterLine(rc, cu, cv); AddLine(rc, u - dv, v + du); AddLine(rc, u + dv, v - du); AddLine(rc, cu + dv, cv - du);
				IF (rc.joinStyle = Gfx.BevelJoin) OR (rc.joinStyle = Gfx.MiterJoin) & (hu * hu + hv * hv > limit * limit) THEN
					GfxPaths.IntersectLines(cu, cv, hu, hv, cu + dv, cv - du, -hv, hu, bu, bv);
					AddLine(rc, bu, bv)
				ELSIF rc.joinStyle = Gfx.MiterJoin THEN
					AddLine(rc, cu + hu, cv + hv)
				ELSIF rc.joinStyle = Gfx.RoundJoin THEN
					t := Math.sqrt((du * du + dv * dv)/(hu * hu + hv * hv));
					data.context := rc; data.x := rc.fu; data.y := rc.fv;
					GfxPaths.EnumArc(cu, cv, cu - du, cv - dv, cu + dv, cv - du, cu + t * hu, cv + t * hv, rc.flatness, AddPathElem, data)
				END;
				AddLine(rc, cu, cv)
			END
		END
	END StrokeHalfJoin;

	PROCEDURE StrokeFullJoin (rc: Context; su, sv, cu, cv, eu, ev, idu, idv, odu, odv, hu, hv: REAL);
		VAR t, limit: REAL; data: PathData;
	BEGIN
		IF (hu # 0) OR (hv # 0) THEN
			IF idu * odv < idv * odu THEN	(* turn right turns into left turns *)
				t := idu; idu := -odu; odu := -t;
				t := idv; idv := -odv; odv := -t;
				t := su; su := eu; eu := t;
				t := sv; sv := ev; ev := t
			END;
			limit := rc.devWidth * rc.styleLimit;
			EnterLine(rc, su - idv, sv + idu); AddLine(rc, su + idv, sv - idu); AddLine(rc, cu + idv, cv - idu);
			IF (rc.joinStyle = Gfx.BevelJoin) OR (rc.joinStyle = Gfx.MiterJoin) & (hu * hu + hv * hv > limit * limit) THEN
				AddLine(rc, cu + odv, cv - odu)
			ELSIF rc.joinStyle = Gfx.MiterJoin THEN
				AddLine(rc, cu + hu, cv + hv)
			ELSIF rc.joinStyle = Gfx.RoundJoin THEN
				data.context := rc; data.x := rc.fu; data.y := rc.fv;
				GfxPaths.EnumArc(cu, cv, cu + idv, cv - idu, cu + idu, cv + idv, cu + odv, cv - odu, rc.flatness, AddPathElem, data)
			ELSE
				AddLine(rc, cu, cv); AddLine(rc, cu + odv, cv - odu)
			END;
			AddLine(rc, eu + odv, ev - odu); AddLine(rc, eu - odv, ev + odu); AddLine(rc, su - idv, sv + idu)
		END
	END StrokeFullJoin;

	PROCEDURE StrokeCap (rc: Context; u, v, du, dv: REAL);
		VAR data: PathData;
	BEGIN
		IF rc.capStyle = Gfx.RoundCap THEN
			EnterLine(rc, u - dv, v + du);
			data.context := rc; data.x := rc.fu; data.y := rc.fv;
			GfxPaths.EnumArc(u, v, u - dv, v + du, u - du, v - dv, u + dv, v - du, rc.flatness, AddPathElem, data);
			AddLine(rc, u - dv, v + du)
		ELSIF rc.capStyle = Gfx.SquareCap THEN
			EnterLine(rc, u - dv, v + du);
			AddLine(rc, u - du - dv, v - dv + du); AddLine(rc, u - du + dv, v - dv - du); AddLine(rc, u + dv, v - du);
			AddLine(rc, u - dv, v + du)
		END
	END StrokeCap;

	PROCEDURE ThickVerticalLine (rc: Context; lu, v0, v1: REAL);
		VAR left, right, bot, top: LONGINT;
	BEGIN
		IF v0 < v1 THEN
			left := ENTIER(lu + 0.5); right := left + ENTIER(2*rc.devWidth + 0.5);
			bot := ENTIER(v0 + 0.5); top := ENTIER(v1 + 0.5)
		ELSE
			right := ENTIER(lu + 0.5); left := right - ENTIER(2*rc.devWidth + 0.5);
			bot := ENTIER(v1 + 0.5); top := ENTIER(v0 + 0.5)
		END;
		rc.rect(SHORT(left), SHORT(bot), SHORT(right), SHORT(top))
	END ThickVerticalLine;

	PROCEDURE ThickHorizontalLine (rc: Context; rv, u0, u1: REAL);
		VAR left, right, bot, top: LONGINT;
	BEGIN
		IF u0 < u1 THEN
			left := ENTIER(u0 + 0.5); right := ENTIER(u1 + 0.5);
			bot := ENTIER(rv + 0.5); top := bot + ENTIER(2*rc.devWidth + 0.5)
		ELSE
			left := ENTIER(u1 + 0.5); right := ENTIER(u0 + 0.5);
			top := ENTIER(rv + 0.5); bot := top - ENTIER(2*rc.devWidth + 0.5)
		END;
		rc.rect(SHORT(left), SHORT(bot), SHORT(right), SHORT(top))
	END ThickHorizontalLine;

	PROCEDURE ThickLine (rc: Context; su, sv, eu, ev, du, dv: REAL);
	BEGIN
		IF ABS(eu - su) < 0.5 THEN
			ThickVerticalLine(rc, su - dv, sv, ev)
		ELSIF ABS(ev - sv) < 0.5 THEN
			ThickHorizontalLine(rc, sv - du, su, eu)
		ELSE
			EnterLine(rc, su - dv, sv + du);
			AddLine(rc, su + dv, sv - du); AddLine(rc, eu + dv, ev - du);
			AddLine(rc, eu - dv, ev + du); AddLine(rc, su - dv, sv + du)
		END
	END ThickLine;

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

	PROCEDURE ThickEnter (rc: Context; u, v, idu, idv: REAL);
	BEGIN
		rc.su := u; rc.sv := v;
		rc.u := u; rc.v := v;
		rc.du := idu; rc.dv := idv;
		InitClipState(rc, SHORT(ENTIER(u)), SHORT(ENTIER(v)))
	END ThickEnter;

	PROCEDURE ThickLineTo (rc: Context; u, v: REAL);
		VAR cu, cv, idu, idv, odu, odv, hu, hv, tu, tv: REAL;
	BEGIN
		cu := rc.u; cv := rc.v;
		idu := rc.du; idv := rc.dv;
		Gfx.GetNormVector(u - cu, v - cv, rc.devWidth, odu, odv);
		IF (cu = rc.su) & (cv = rc.sv) THEN	(* first call *)
			IF rc.deferred THEN	(* defer rendering of starting cap in case path is later closed *)
				rc.u1 := u; rc.v1 := v;	(* remember direction of first line *)
				rc.tu := cu; rc.tv := cv
			ELSE	(* render initial joint *)
				Gfx.GetNormVector(idu, idv, rc.devWidth, idu, idv);
				Gfx.GetHalfAxisVector(idu, idv, odu, odv, hu, hv);
				IF (hu = 0) & (hv = 0) THEN
					rc.tu := cu; rc.tv := cv
				ELSE
					TrimJoinLength(cu, cv, 0.5*(cu + u), 0.5*(cv + v), odu, odv, hu, hv, rc.tu, rc.tv);
					StrokeHalfJoin(rc, cu, cv, rc.tu, rc.tv, odu, odv, hu, hv, 0)
				END
			END
		ELSE
			UpdateClipState(rc, SHORT(ENTIER(cu)), SHORT(ENTIER(cv)));
			Gfx.GetHalfAxisVector(idu, idv, odu, odv, hu, hv);
			IF (hu = 0) & (hv = 0) THEN
				tu := cu; tv := cv
			ELSE
				TrimJoinLength(cu, cv, rc.tu, rc.tv, -idu, -idv, hu, hv, tu, tv)
			END;
			IF (tu - rc.tu) * idu + (tv - rc.tv) * idv > 0 THEN
				ThickLine(rc, rc.tu, rc.tv, tu, tv, idu, idv)
			END;
			IF (hu = 0) & (hv = 0) THEN
				rc.tu := cu; rc.tv := cv
			ELSE
				TrimJoinLength(cu, cv, 0.5*(cu + u), 0.5*(cv + v), odu, odv, hu, hv, rc.tu, rc.tv);
				StrokeFullJoin(rc, tu, tv, cu, cv, rc.tu, rc.tv, idu, idv, odu, odv, hu, hv)
			END
		END;
		rc.su := cu; rc.sv := cv;
		rc.u := u; rc.v := v;
		rc.du := odu; rc.dv := odv
	END ThickLineTo;

	PROCEDURE ThickExit (rc: Context; odu, odv: REAL);
		VAR cu, cv, idu, idv, hu, hv, tu, tv: REAL;
	BEGIN
		cu := rc.u; cv := rc.v;
		IF (cu # rc.su) OR (cv # rc.sv) THEN	(* at least one thick line was rendered *)
			idu := rc.du; idv := rc.dv;
			UpdateClipState(rc, SHORT(ENTIER(cu)), SHORT(ENTIER(cv)));
			IF (odu = 0) & (odv = 0) THEN
				ThickLine(rc, rc.tu, rc.tv, cu, cv, idu, idv);
				StrokeCap(rc, cu, cv, -idu, -idv)
			ELSE
				Gfx.GetNormVector(odu, odv, rc.devWidth, odu, odv);
				Gfx.GetHalfAxisVector(idu, idv, odu, odv, hu, hv);
				IF (hu = 0) & (hv = 0) THEN
					tu := cu; tv := cv
				ELSE
					TrimJoinLength(cu, cv, rc.tu, rc.tv, -idu, -idv, hu, hv, tu, tv)
				END;
				IF (tu - rc.tu) * idu + (tv - rc.tv) * idv > 0 THEN
					ThickLine(rc, rc.tu, rc.tv, tu, tv, idu, idv)
				END;
				IF (hu # 0) OR (hv # 0) THEN
					StrokeHalfJoin(rc, cu, cv, tu, tv, idu, idv, hu, hv, 1)
				END
			END;
			IF rc.deferred THEN	(* render cap at start pos *)
				InitClipState(rc, SHORT(ENTIER(rc.u0)), SHORT(ENTIER(rc.v0)));
				Gfx.GetNormVector(rc.u1 - rc.u0, rc.v1 - rc.v0, rc.devWidth, odu, odv);
				StrokeCap(rc, rc.u0, rc.v0, odu, odv)
			END
		END
	END ThickExit;

	PROCEDURE ThickClose (rc: Context);
		VAR cu, cv, idu, idv, odu, odv, hu, hv, tu, tv, eu, ev: REAL;
	BEGIN
		cu := rc.u; cv := rc.v; idu := rc.du; idv := rc.dv;
		UpdateClipState(rc, SHORT(ENTIER(cu)), SHORT(ENTIER(cv)));
		Gfx.GetNormVector(rc.u1 - rc.u0, rc.v1 - rc.v0, rc.devWidth, odu, odv);
		Gfx.GetHalfAxisVector(idu, idv, odu, odv, hu, hv);
		IF (hu = 0) & (hv = 0) THEN
			tu := cu; tv := cv
		ELSE
			TrimJoinLength(cu, cv, rc.tu, rc.tv, -idu, -idv, hu, hv, tu, tv)
		END;
		IF (tu - rc.tu) * idu + (tv - rc.tv) * idv > 0 THEN
			ThickLine(rc, rc.tu, rc.tv, tu, tv, idu, idv)
		END;
		IF (hu # 0) OR (hv # 0) THEN
			TrimJoinLength(cu, cv, 0.5*(cu + rc.u1), 0.5*(cv + rc.v1), odu, odv, hu, hv, eu, ev);
			StrokeFullJoin(rc, tu, tv, cu, cv, eu, ev, idu, idv, odu, odv, hu, hv)
		END
	END ThickClose;


	(*--- Dashed Lines ---*)

	PROCEDURE DashEnter (rc: Context; su, sv, idu, idv: REAL);
		VAR beg, end, next: REAL; index: LONGINT;
	BEGIN
		rc.offset := 0;
		rc.GetDashOffsets(0, beg, end, next, index);
		IF end > 0 THEN
			IF rc.devWidth <= 0.75 THEN HairLineEnter(rc, su, sv)
			ELSE ThickEnter(rc, su, sv, idu, idv)
			END
		ELSE
			rc.u := su; rc.v := sv
		END
	END DashEnter;

	PROCEDURE DashLineTo (rc: Context; u, v: REAL);
		VAR
			cu, cv, du, dv, len, cos, sin, wdu, wdv, offset, beg, end, next, dash, tu, tv, u1, v1: REAL;
			index: LONGINT; deferred: BOOLEAN;
	BEGIN
		cu := rc.u; cv := rc.v;
		du := u - cu; dv := v - cv;
		len := Math.sqrt(du * du + dv * dv);
		cos := du/len; sin := dv/len;
		wdu := rc.devWidth * cos; wdv := rc.devWidth * sin;
		offset := rc.offset; rc.offset := offset + len;
		rc.GetDashOffsets(offset, beg, end, next, index);
		IF offset < end THEN	(* inside dash *)
			IF end <= rc.offset THEN	(* finish current dash *)
				len := end - offset;
				IF rc.devWidth <= 0.75 THEN
					HairLineTo(rc, cu + len * cos, cv + len * sin)
				ELSE
					ThickLineTo(rc, cu + len * cos, cv + len * sin);	(* sets u1/v1 if first line in subpath *)
					deferred := rc.deferred; rc.deferred := FALSE;
					ThickExit(rc, 0, 0);
					rc.deferred := deferred
				END
			ELSIF rc.devWidth <= 0.75 THEN
				HairLineTo(rc, u, v)
			ELSE
				ThickLineTo(rc, u, v)
			END
		END;
		beg := offset;
		LOOP
			len := next - beg;
			cu := cu + len * cos; cv := cv + len * sin;
			beg := next;
			GfxMatrix.ApplyToDist(rc.cam, rc.dashPatOn[index], dash);
			end := beg + dash;
			GfxMatrix.ApplyToDist(rc.cam, rc.dashPatOff[index], dash);
			next := end + dash;
			index := (index+1) MOD rc.dashPatLen;
			IF end > rc.offset THEN EXIT END;
			len := end - beg;
			IF rc.devWidth <= 0.75 THEN
				HairLineEnter(rc, cu, cv);
				HairLineTo(rc, cu + len * cos, cv + len * sin)
			ELSE
				StrokeCap(rc, cu, cv, wdu, wdv);
				InitClipState(rc, SHORT(ENTIER(cu)), SHORT(ENTIER(cv)));
				tu := cu + len * cos; tv := cv + len * sin;
				UpdateClipState(rc, SHORT(ENTIER(tu)), SHORT(ENTIER(tv)));
				ThickLine(rc, cu, cv, tu, tv, wdu, wdv);
				StrokeCap(rc, tu, tv, -wdu, -wdv)
			END
		END;
		IF beg <= rc.offset THEN	(* begin next dash *)
			IF rc.devWidth <= 0.75 THEN
				HairLineEnter(rc, cu, cv);
				HairLineTo(rc, u, v)
			ELSE
				u1 := rc.u1; v1 := rc.v1;
				StrokeCap(rc, cu, cv, wdu, wdv);
				ThickEnter(rc, cu, cv, 0, 0);
				ThickLineTo(rc, u, v);
				rc.u1 := u1; rc.v1 := v1	(* restore original point *)
			END
		ELSE
			rc.u := u; rc.v := v
		END
	END DashLineTo;

	PROCEDURE DashExit (rc: Context; odu, odv: REAL);
		VAR beg, end, next: REAL; index: LONGINT;
	BEGIN
		IF rc.devWidth > 0.75 THEN
			rc.GetDashOffsets(rc.offset, beg, end, next, index);
			IF (beg < rc.offset) & (rc.offset < end) THEN
				ThickExit(rc, odu, odv)
			END
		END
	END DashExit;

	PROCEDURE DashClose (rc: Context);
		VAR beg, end, next: REAL; index: LONGINT;
	BEGIN
		IF rc.deferred & (rc.devWidth > 0.75) THEN
			rc.GetDashOffsets(rc.offset, beg, end, next, index);
			IF (beg < rc.offset) & (rc.offset < end) THEN
				ThickClose(rc)
			END
		END
	END DashClose;


	(*--- Stroking ---*)

	PROCEDURE StrokePrepare (rc: Context);
	BEGIN
		GfxMatrix.ApplyToDist(rc.cam, 0.5*rc.lineWidth, rc.devWidth);
		IF rc.devWidth <= 0.75 THEN
			rc.border := 1
		ELSE
			rc.border := -SHORT(ENTIER(-rc.devWidth * rc.styleLimit));
		END;
		rc.SetColPat(rc.strokeCol, rc.strokePat)
	END StrokePrepare;

	PROCEDURE StrokeEnter (rc: Context; u, v, du, dv: REAL);
	BEGIN
		IF rc.devWidth > 0.75 THEN
			rc.pathReg.Clear()
		END;
		IF rc.dashPatLen > 0 THEN
			DashEnter(rc, u, v, du, dv)
		ELSIF rc.devWidth <= 0.75 THEN
			HairLineEnter(rc, u, v)
		ELSE
			ThickEnter(rc, u, v, du, dv)
		END
	END StrokeEnter;

	PROCEDURE StrokeLineTo (rc: Context; u, v: REAL);
	BEGIN
		IF rc.dashPatLen > 0 THEN
			DashLineTo(rc, u, v)
		ELSIF rc.devWidth <= 0.75 THEN
			HairLineTo(rc, u, v)
		ELSE
			ThickLineTo(rc, u, v)
		END
	END StrokeLineTo;

	PROCEDURE StrokeExit (rc: Context; du, dv: REAL);
	BEGIN
		IF rc.dashPatLen > 0 THEN
			DashExit(rc, du, dv)
		ELSIF rc.devWidth > 0.75 THEN
			ThickExit(rc, du, dv)
		END;
		IF rc.devWidth > 0.75 THEN
			rc.pathReg.Intersect(rc.clipReg);
			IF ~rc.pathReg.Empty() THEN
				rc.clipState := In;
				FillRegion(rc)
			END
		END
	END StrokeExit;

	PROCEDURE StrokeClose (rc: Context);
	BEGIN
		IF rc.dashPatLen > 0 THEN
			DashClose(rc)
		ELSIF rc.devWidth > 0.75 THEN
			ThickClose(rc)
		END;
		IF rc.devWidth > 0.75 THEN
			rc.pathReg.Intersect(rc.clipReg);
			IF ~rc.pathReg.Empty() THEN
				rc.clipState := In;
				FillRegion(rc)
			END
		END
	END StrokeClose;

	PROCEDURE StrokePathElem (VAR data: GfxPaths.EnumData);
		VAR rc: Context; x, y: REAL;
	BEGIN
		rc := data(PathData).context;
		CASE data.elem OF
		| GfxPaths.Enter:
			StrokeEnter(rc, data.x, data.y, data.dx, data.dy)
		| GfxPaths.Line:
			IF (data.x # rc.u) OR (data.y # rc.v) THEN
				StrokeLineTo(rc, data.x, data.y)
			END
		| GfxPaths.Arc:
			IF (rc.dashPatLen = 0) & (rc.devWidth <= 0.75) &
				IsEllipse(data.x0, data.y0, data.x1, data.y1, data.x2, data.y2, data.x, data.y, rc.u, rc.v, rc.flatness, x, y)
			THEN
				IF ABS(ABS(x) - ABS(y)) < rc.flatness THEN
					IF x * y > 0 THEN
						HairCircle(rc, ENTIER(data.x0), ENTIER(data.y0), ENTIER(ABS(x) + 0.5))
					ELSE
						HairCircle(rc, ENTIER(data.x0), ENTIER(data.y0), -ENTIER(ABS(x) + 0.5))
					END
				ELSE
					HairEllipse(rc, ENTIER(data.x0), ENTIER(data.y0), ENTIER(ABS(x) + 0.5), ENTIER(ABS(y) + 0.5))
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
			StrokeExit(rc, data.dx, data.dy)
		END
	END StrokePathElem;


	(**--- Raster Contexts ---**)

	(** initialize raster context **)
	PROCEDURE InitContext* (rc: Context);
	BEGIN
		rc.InitRaster();
	END InitContext;

END GfxRaster.
