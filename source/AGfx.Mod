(* ETH Oberon, Copyright 2001 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

MODULE Gfx; (** portable *)	(* eos  *)
(** AUTHOR "eos"; PURPOSE "High-level, device independent 2D-graphics"; *)

	(*
		11.2.98 - changed behaviour of GetOutline if current line width is zero: calculates dashed path instead of outline (eos)
		11.2.98 - eliminated offset parameter from subpath begin since it can be simulated by modifying the dash phase
		16.2.98 - DrawPath now accepts current path
		17.2.98 - ...but only if Record is not included in mode
		17.2.98 - added RenderPath
		19.2.98 - simplified cap and join styles to procedures
		19.2.98 - eliminated clip path (was not correct, anyway), introduced GetClipRect instead
		6.3.98 - fixed bug in GetDashOutline (started last dash twice even if fully drawn)
		18.9.98 - several changes: renaming, added stroke pattern and rect/ellipse methods, text is now part of path model,
			standard colors
		9.12.98 - adaptation to new GfxMaps
		10.3.99 - separate dash pattern into on/off arrays
		13.5.99 - remodeled cap and join styles
		13.5.99 - eliminated 'erase'
		2.6.99 - bugfix in GetStrokeOutline and GetDashOutline (forgot to consume GfxPaths.Exit after subpath)
		8.6.99 - made GetPolyOutline automatically close open subpaths
		25.8.99 - use GfxImages instead of GfxMaps
		6.10.99 - save and restore graphics state, MoveTo and Close
		13.02.2000 - added ClipArea, replaced SaveClip/RestoreClip by GetClip/SetClip, fine-grained SaveState semantics
		26.02.2000 - allow font change within path
		27.02.2000 - added DrawArc
		29.03.2000 - made default flatness 1/2
		25.05.2000 - no longer imports Texts and Oberon
		12.06.2001 - made tmpPath and dashPath ctxt fields to allow concurrency
	*)

	IMPORT
		Math, GfxMatrix, GfxImages, GfxPaths, GfxFonts;


	CONST
		Version* = "Gfx 2.0/eos 25.05.2000";

		Record* = 0; Fill* = 1; Clip* = 2; Stroke* = 3; EvenOdd* = 4;	(** drawing mode elements **)
		InPath* = 5; InSubpath* = 6;	(** context state **)
		MaxDashPatSize* = 8;	(** maximal number of dash entries **)
		NoJoin* = 0; MiterJoin* = 1; BevelJoin* = 2; RoundJoin* = 3;	(** join styles **)
		NoCap* = 0; ButtCap* = 1; SquareCap* = 2; RoundCap* = 3;	(** cap styles **)

		(** state elements **)
		fillColPat* = 0; strokeColPat* = 1; lineWidth* = 2; dashPat* = 3; capStyle* = 4; joinStyle* = 5; styleLimit* = 6;
		flatness* = 7; font* = 8; ctm* = 9; clip* = 10;
		strokeAttr* = {strokeColPat..styleLimit};
		attr* = {fillColPat..font}; all* = attr + {ctm, clip};


	TYPE

		(** color type **)
		Color* = RECORD
			r*, g*, b*, a*: INTEGER;
		END;

		(** fill patterns **)
		Pattern* = POINTER TO PatternDesc;
		PatternDesc* = RECORD
			img*: GfxImages.Image;	(** replicated image map **)
			px*, py*: REAL;	(** pinpoint coordinates **)
		END;

		(** line join and cap styles **)
		JoinStyle* = SHORTINT;
		CapStyle* = SHORTINT;

		(** abstract clip areas **)
		ClipArea* = POINTER TO ClipAreaDesc;
		ClipAreaDesc* = RECORD END;

		(** graphics context **)
		Context* = OBJECT { ABSTRACT }
		VAR
			mode*: SET;	(** current drawing mode **)
			path*: GfxPaths.Path;	(** current path in device coordinates (updated only if mode contains the 'Record' flag) **)
			cpx*, cpy*: REAL;	(** current point in user coordinates **)
			ctm*: GfxMatrix.Matrix;	(** current transformation matrix **)
			cam*: GfxMatrix.Matrix;	(** current attribute matrix (frozen ctm while inside path) **)
			strokeCol*, fillCol*: Color;	(** current stroke and fill color **)
			strokePat*, fillPat*: Pattern;	(** current stroke and fill pattern **)
			lineWidth*: REAL;	(** current line width **)
			dashPatOn*, dashPatOff*: ARRAY MaxDashPatSize OF REAL;	(** line dash array **)
			dashPatLen*: LONGINT;	(** number of valid elements in dash arrays **)
			dashPhase*: REAL;	(** offset for first dash **)
			dashPeriod*: REAL;	(** sum of dash element lengths **)
			capStyle*: CapStyle;	(** line cap style **)
			joinStyle*: JoinStyle;	(** line join style **)
			styleLimit*: REAL;	(** determines area that may be rendered to by styles **)
			flatness*: REAL;	(** current flatness tolerance (in device coordinates) **)
			font*: GfxFonts.Font;	(** current font **)
			dashPath: GfxPaths.Path;	(* path for temporarily storing dashes *)
			tmpPath: GfxPaths.Path;

			(** initialize context values to defaults **)
			PROCEDURE InitContext* ();
			BEGIN
				SELF.ctm := GfxMatrix.Identity; SELF.cam := SELF.ctm;
				SELF.strokeCol := Black; SELF.strokePat := NIL;
				SELF.fillCol := Black; SELF.fillPat := NIL;
				SELF.lineWidth := 1;
				SELF.dashPatLen := 0; SELF.dashPhase := 0; SELF.dashPeriod := 0;
				SELF.capStyle := DefaultCap; SELF.joinStyle := DefaultJoin; SELF.styleLimit := 5;
				SELF.mode := {};
				SELF.path := NIL;
				SELF.cpx := 0; SELF.cpy := 0;
				SELF.flatness := 0.5;
				SELF.font := GfxFonts.Default;
				IF SELF.tmpPath = NIL THEN
					NEW(SELF.tmpPath);
				END;
				IF SELF.dashPath = NIL THEN
					NEW(SELF.dashPath)
				END;
			END InitContext;

			(** reset context to default values **)
			PROCEDURE Reset*();
			BEGIN
				SELF.InitContext();
				SELF.ResetClip();
				SELF.ResetCTM()
			END Reset;

		(**--- Coordinate System ---**)

			(** reset current transformation matrix **)
			PROCEDURE{ABSTRACT} ResetCTM*(); END ResetCTM;

			(** set current transformation matrix **)
			PROCEDURE SetCTM*(VAR mat: GfxMatrix.Matrix);
			BEGIN
				SELF.ctm := mat;
			END SetCTM;

			(** translate coordinate system **)
			PROCEDURE Translate*(dx, dy: REAL);
			BEGIN
				GfxMatrix.Translate(SELF.ctm, dx, dy, SELF.ctm);
			END Translate;

			(** scale coordinate system at origin **)
			PROCEDURE Scale*(sx, sy: REAL);
			BEGIN
				GfxMatrix.Scale(SELF.ctm, sx, sy, SELF.ctm);
			END Scale;

			(** scale coordinate system at specified point **)
			PROCEDURE ScaleAt* (sx, sy, x, y: REAL);
			BEGIN
				SELF.Translate(x, y);
				SELF.Scale(sx, sy);
				SELF.Translate(-x, -y)
			END ScaleAt;

			(** rotate coordinate system at origin **)
			PROCEDURE Rotate*(sin, cos: REAL);
			BEGIN
				GfxMatrix.Rotate(SELF.ctm, sin, cos, SELF.ctm);
			END Rotate;

			(** rotate coordinate system at specified point **)
			PROCEDURE RotateAt* (sin, cos, x, y: REAL);
			BEGIN
				SELF.Translate(x, y);
				SELF.Rotate(sin, cos);
				SELF.Translate(-x, -y)
			END RotateAt;

			(** concat transformation matrix to CTM **)
			PROCEDURE Concat*(VAR mat: GfxMatrix.Matrix);
			BEGIN
				GfxMatrix.Concat(mat, SELF.ctm, SELF.ctm);
			END Concat;

		(**--- Clipping ---**)

			(** reset clip path **)
			PROCEDURE{ABSTRACT} ResetClip*(); END ResetClip;

			(** get bounding box of clipping path in user coordinates **)
			PROCEDURE{ABSTRACT} GetClipRect*(VAR llx, lly, urx, ury: REAL); END GetClipRect;

			(** get current clipping area **)
			PROCEDURE{ABSTRACT} GetClip*(): ClipArea; END GetClip;

			(** restore saved clipping path **)
			PROCEDURE{ABSTRACT} SetClip*(clip: ClipArea); END SetClip;

		(**--- Graphics State ---**)

			(** set stroke color **)
			PROCEDURE SetStrokeColor*(color: Color);
			BEGIN
				ASSERT(~(InPath IN SELF.mode), 100);
				SELF.strokeCol := color;
			END SetStrokeColor;

			(** set stroke pattern (NIL = solid) **)
			PROCEDURE SetStrokePattern*(pat: Pattern);
			BEGIN
				ASSERT(~(InPath IN SELF.mode), 100);
				SELF.strokePat := pat
			END SetStrokePattern;

			(** set fill color **)
			PROCEDURE SetFillColor*(color: Color);
			BEGIN
				ASSERT(~(InPath IN SELF.mode), 100);
				SELF.fillCol := color;
			END SetFillColor;

			(** set fill pattern (NIL = solid) **)
			PROCEDURE SetFillPattern*(pat: Pattern);
			BEGIN
				ASSERT(~(InPath IN SELF.mode), 100);
				SELF.fillPat := pat
			END SetFillPattern;

			(** set line width **)
			PROCEDURE SetLineWidth*(width: REAL);
			BEGIN
				ASSERT(~(InPath IN SELF.mode), 100);
				ASSERT(width >= 0.0, 101);
				SELF.lineWidth := width
			END SetLineWidth;

			(** set dash pattern **)
			PROCEDURE SetDashPattern*(VAR on, off: ARRAY OF REAL; len: LONGINT; phase: REAL);
			BEGIN
				ASSERT(~(InPath IN SELF.mode), 100);
				ASSERT((len <= LEN(on)) & (len <= LEN(off)), 101);
				SELF.SetDashArray(on, off, len);
				SELF.dashPhase := phase
			END SetDashPattern;

			(** copy values from parameter, and calculate dash period **)
			PROCEDURE SetDashArray* (VAR on, off: ARRAY OF REAL; len: LONGINT);
			BEGIN
				SELF.dashPatLen := len;
				SELF.dashPeriod := 0;
				IF len > 0 THEN
					REPEAT
						DEC(len);
						SELF.dashPatOn[len] := on[len]; SELF.dashPatOff[len] := off[len];
						SELF.dashPeriod := SELF.dashPeriod + on[len] + off[len]
					UNTIL len = 0
				END;
				ASSERT((SELF.dashPatLen = 0) OR (SELF.dashPeriod # 0), 120)
			END SetDashArray;

			(** set line cap style **)
			PROCEDURE SetCapStyle*(style: CapStyle);
			BEGIN
				ASSERT(~(InPath IN SELF.mode), 100);
				ASSERT((NoCap <= style) & (style <= RoundCap), 101);
				SELF.capStyle := style
			END SetCapStyle;

			(** set line join style **)
			PROCEDURE SetJoinStyle*(style: JoinStyle);
			BEGIN
				ASSERT(~(InPath IN SELF.mode), 100);
				ASSERT((NoJoin <= style) & (style <= RoundJoin), 101);
				SELF.joinStyle := style
			END SetJoinStyle;

			(** set style border factor **)
			PROCEDURE SetStyleLimit*(limit: REAL);
			BEGIN
				ASSERT(~(InPath IN SELF.mode), 100);
				SELF.styleLimit := limit
			END SetStyleLimit;

			(** set flatness parameter **)
			PROCEDURE SetFlatness*(flatness: REAL);
			BEGIN
				SELF.flatness := flatness
			END SetFlatness;

			(** set current font **)
			PROCEDURE SetFont*(font: GfxFonts.Font);
			BEGIN
				ASSERT(font # NIL, 100);
				SELF.font := font
			END SetFont;

			(** set current font using name and size **)
			PROCEDURE SetFontName* (fontname: ARRAY OF CHAR; size: INTEGER);
				VAR font: GfxFonts.Font;
			BEGIN
				font := GfxFonts.OpenSize(fontname, size);
				IF font = NIL THEN font := GfxFonts.Default END;
				SELF.SetFont(font)
			END SetFontName;

			(** calculate distance that current point would move if given string were rendered **)
			PROCEDURE GetStringWidth*(VAR str: ARRAY OF CHAR; VAR dx, dy: REAL);
			BEGIN
				GfxFonts.GetStringWidth(SELF.font, str, dx, dy)
			END GetStringWidth;

		(**--- Current Path ---**)

			(** start new path **)
			PROCEDURE Begin* (mode: SET);
			BEGIN
				ASSERT(~(InPath IN SELF.mode), 100);
				SELF.DoBegin(mode);
				INCL(SELF.mode, InPath)
			END Begin;

			(** exit current subpath (if open) and end current path **)
			PROCEDURE End* ();
			BEGIN
				ASSERT(InPath IN SELF.mode, 100);
				IF InSubpath IN SELF.mode THEN SELF.DoExit(0, 0) END;
				SELF.DoEnd();
				EXCL(SELF.mode, InPath)
			END End;

			(** end current subpath (if open) and begin new subpath **)
			PROCEDURE MoveTo* (x, y: REAL);
			BEGIN
				ASSERT(InPath IN SELF.mode, 100);
				IF InSubpath IN SELF.mode THEN SELF.DoExit(0, 0) END;
				SELF.DoEnter(x, y, 0, 0);
				INCL(SELF.mode, InSubpath)
			END MoveTo;

			(** start subpath at inner point **)
			PROCEDURE Enter* (x, y, dx, dy: REAL);
			BEGIN
				ASSERT(InPath IN SELF.mode, 100);
				IF InSubpath IN SELF.mode THEN SELF.DoExit(0, 0) END;
				SELF.DoEnter(x, y, dx, dy);
				INCL(SELF.mode, InSubpath)
			END Enter;

			(** end subpath at inner point **)
			PROCEDURE Exit* (dx, dy: REAL);
			BEGIN
				ASSERT(InSubpath IN SELF.mode, 100);
				SELF.DoExit(dx, dy);
				EXCL(SELF.mode, InSubpath)
			END Exit;

			(** close current subpath **)
			PROCEDURE Close* ();
			BEGIN
				ASSERT(InSubpath IN SELF.mode, 100);
				SELF.DoClose();
				EXCL(SELF.mode, InSubpath)
			END Close;

			(** append line to current path **)
			PROCEDURE LineTo* (x, y: REAL);
			BEGIN
				ASSERT(InSubpath IN SELF.mode, 100);
				SELF.DoLine(x, y)
			END LineTo;

			(** append arc to current path **)
			PROCEDURE ArcTo* (x, y, x0, y0, x1, y1, x2, y2: REAL);
			BEGIN
				ASSERT(InSubpath IN SELF.mode, 100);
				SELF.DoArc(x, y, x0, y0, x1, y1, x2, y2)
			END ArcTo;

			(** append cubic bezier to current path **)
			PROCEDURE BezierTo* (x, y, x1, y1, x2, y2: REAL);
			BEGIN
				ASSERT(InSubpath IN SELF.mode, 100);
				SELF.DoBezier(x, y, x1, y1, x2, y2)
			END BezierTo;
	
			(** append character outlines to current path at given point; advance current point to position after last character **)
			PROCEDURE ShowAt* (x, y: REAL; str: ARRAY OF CHAR);
			BEGIN
				ASSERT(InPath IN SELF.mode, 100);
				IF InSubpath IN SELF.mode THEN SELF.DoExit(0, 0) END;
				SELF.DoShow(x, y, str)
			END ShowAt;
			
			(** append character outlines to current path at current point; advance current point to position after last character **)
			PROCEDURE Show* (str: ARRAY OF CHAR);
			BEGIN
				ASSERT(InPath IN SELF.mode, 100);
				IF InSubpath IN SELF.mode THEN SELF.DoExit(0, 0) END;
				SELF.DoShow(SELF.cpx, SELF.cpy, str)
			END Show;

		(**--- Path Flattening ---**)

			(** replace arcs and beziers in current path by approximation using straight lines **)
			PROCEDURE Flatten*();
			BEGIN
				ASSERT(~(InPath IN SELF.mode), 100);
				SELF.GetFlattenedPath(SELF.tmpPath);
				SELF.tmpPath.CopyTo(SELF.path);
				SELF.tmpPath.Clear()
			END Flatten;

			(** store flattened current path in given path  **)
			PROCEDURE GetFlattenedPath* (path: GfxPaths.Path);
				VAR data: PathData;
			BEGIN
				ASSERT(SELF.path # path, 100);
				path.Clear();
				data.path := path;
				SELF.path.EnumFlattened(SELF.flatness, EnumPathElem, data)
			END GetFlattenedPath;

		(**--- Cap Styles ---**)

			PROCEDURE EnterCapStyle* (x, y, dx, dy: REAL; path: GfxPaths.Path);
			BEGIN
				IF SELF.capStyle = ButtCap THEN
					path.AddEnter(x, y, dy, -dx);
					path.AddLine(x + dy, y - dx)
				ELSIF SELF.capStyle = SquareCap THEN
					path.AddEnter(x - dx, y - dy, dy, -dx);
					path.AddLine(x - dx + dy, y - dy - dx);
					path.AddLine(x + dy, y - dx)
				ELSIF SELF.capStyle = RoundCap THEN
					path.AddEnter(x - dx, y - dy, dy, -dx);
					path.AddArc(x + dy, y - dx, x, y, x - dx, y - dy, x + dy, y - dx)
				ELSE
					path.AddEnter(x + dy, y - dx, 0, 0)
				END
			END EnterCapStyle;

			PROCEDURE AddCapStyle* (x, y, dx, dy: REAL; path: GfxPaths.Path);
			BEGIN
				IF SELF.capStyle = ButtCap THEN
					path.AddLine(x + dy, y - dx)
				ELSIF SELF.capStyle = SquareCap THEN
					path.AddLine(x - dx - dy, y - dy + dx);
					path.AddLine(x - dx + dy, y - dy - dx);
					path.AddLine(x + dy, y - dx)
				ELSIF SELF.capStyle = RoundCap THEN
					path.AddArc(x + dy, y - dx, x, y, x - dy, y + dx, x - dx, y - dy)
				ELSE
					path.AddExit(0, 0);
					path.AddEnter(x + dy, y - dx, 0, 0)
				END
			END AddCapStyle;

			PROCEDURE ExitCapStyle* (x, y, dx, dy: REAL; path: GfxPaths.Path);
			BEGIN
				IF SELF.capStyle = ButtCap THEN
					path.AddLine(x, y);
					path.AddExit(dy, -dx)
				ELSIF SELF.capStyle = SquareCap THEN
					path.AddLine(x - dx - dy, y - dy + dx);
					path.AddLine(x - dx, y - dy);
					path.AddExit(dy, -dx)
				ELSIF SELF.capStyle = RoundCap THEN
					path.AddArc(x - dx, y - dy, x, y, x - dy, y + dx, x - dx, y - dy);
					path.AddExit(dy, -dx)
				ELSE
					path.AddExit(0, 0)
				END
			END ExitCapStyle;

		(**--- Join Styles ---**)

			(** return if half axis vector (in device coordinates) exceeds style limit **)
			PROCEDURE ExceedsLimit* (hx, hy: REAL): BOOLEAN;
				VAR limit: REAL;
			BEGIN
				GfxMatrix.ApplyToDist(SELF.cam, 0.5*SELF.lineWidth * SELF.styleLimit, limit);
				RETURN hx * hx + hy * hy > limit * limit
			END ExceedsLimit;

			PROCEDURE EnterJoinStyle* (x, y, idx, idy, hx, hy, odx, ody: REAL; path: GfxPaths.Path);
				VAR ix, iy, t: REAL;
			BEGIN
				IF (SELF.joinStyle = BevelJoin) OR (SELF.joinStyle = MiterJoin) & SELF.ExceedsLimit(hx, hy) THEN
					GfxPaths.IntersectLines(x, y, hx, hy, x + ody, y - odx, -hy, hx, ix, iy);
					path.AddEnter(ix, iy, -hy, hx);
					path.AddLine(x + ody, y - odx)
				ELSIF SELF.joinStyle = MiterJoin THEN
					path.AddEnter(x + hx, y + hy, idx, idy);
					path.AddLine(x + ody, y - odx)
				ELSIF SELF.joinStyle = RoundJoin THEN
					t := Math.sqrt((odx * odx + ody * ody)/(hx * hx + hy * hy));
					path.AddEnter(x + t * hx, y + t * hy, -hy, hx);
					path.AddArc(x + ody, y - odx, x, y, x - odx, y - ody, x + ody, y - odx)
				ELSE
					path.AddEnter(x + ody, y - odx, 0, 0)
				END
			END EnterJoinStyle;

			PROCEDURE AddJoinStyle* (x, y, idx, idy, hx, hy, odx, ody: REAL; path: GfxPaths.Path);
			BEGIN
				IF (SELF.joinStyle = BevelJoin) OR (SELF.joinStyle = MiterJoin) & SELF.ExceedsLimit(hx, hy) THEN
					path.AddLine(x + ody, y - odx)
				ELSIF SELF.joinStyle = MiterJoin THEN
					path.AddLine(x + hx, y + hy);
					path.AddLine(x + ody, y - odx)
				ELSIF SELF.joinStyle = RoundJoin THEN
					path.AddArc(x + ody, y - odx, x, y, x - odx, y - ody, x + ody, y - odx)
				ELSE
					path.AddExit(0, 0);
					path.AddEnter(x + ody, y - odx, 0, 0)
				END
			END AddJoinStyle;

			PROCEDURE ExitJoinStyle* (x, y, idx, idy, hx, hy, odx, ody: REAL; path: GfxPaths.Path);
				VAR ix, iy, t: REAL;
			BEGIN
				IF (SELF.joinStyle = BevelJoin) OR (SELF.joinStyle = MiterJoin) & SELF.ExceedsLimit(hx, hy) THEN
					GfxPaths.IntersectLines(x, y, hx, hy, x + idy, y - idx, -hy, hx, ix, iy);
					path.AddLine(ix, iy);
					path.AddExit(-hy, hx)
				ELSIF SELF.joinStyle = MiterJoin THEN
					path.AddLine(x + hx, y + hy);
					path.AddExit(odx, ody)
				ELSIF SELF.joinStyle = RoundJoin THEN
					t := Math.sqrt((odx * odx + ody * ody)/(hx * hx + hy * hy));
					path.AddArc(x + t * hx, y + t * hy, x, y, x - idx, y - idy, x + idy, y - idx);
					path.AddExit(-hy, hx)
				ELSE
					path.AddExit(0, 0)
				END
			END ExitJoinStyle;

		(**--- Path Outline ---**)

			(** replace current path by outline of area which would be drawn to if the path were stroked **)
			PROCEDURE Outline*();
			BEGIN
				ASSERT(~(InPath IN SELF.mode), 100);
				SELF.GetOutline(SELF.tmpPath);
				SELF.tmpPath.CopyTo(SELF.path);
				SELF.tmpPath.Clear()
			END Outline;

			PROCEDURE AddEnterJoinStyle (x, y, hx, hy, odx, ody: REAL; path: GfxPaths.Path);
				VAR ix, iy, t: REAL;
			BEGIN
				IF (SELF.joinStyle = BevelJoin) OR (SELF.joinStyle = MiterJoin) & SELF.ExceedsLimit(hx, hy) THEN
					GfxPaths.IntersectLines(x, y, hx, hy, x + ody, y - odx, -hy, hx, ix, iy);
					path.AddLine(ix, iy); path.AddLine(x + ody, y - odx)
				ELSIF SELF.joinStyle = MiterJoin THEN
					path.AddLine(x + hx, y + hy); path.AddLine(x + ody, y - odx)
				ELSIF SELF.joinStyle = RoundJoin THEN
					t := Math.sqrt((odx * odx + ody * ody)/(hx * hx + hy * hy));
					path.AddLine(x + t * hx, y + t * hy);
					path.AddArc(x + ody, y - odx, x, y, x - odx, y - ody, x + ody, y - odx)
				ELSE
					path.AddLine(x + ody, y - odx)
				END
			END AddEnterJoinStyle;

			PROCEDURE AddExitJoinStyle (x, y, idx, idy, hx, hy: REAL; path: GfxPaths.Path);
				VAR ix, iy, t: REAL;
			BEGIN
				IF (SELF.joinStyle = BevelJoin) OR (SELF.joinStyle = MiterJoin) & SELF.ExceedsLimit(hx, hy) THEN
					GfxPaths.IntersectLines(x, y, hx, hy, x + idy, y - idx, -hy, hx, ix, iy);
					path.AddLine(ix, iy)
				ELSIF SELF.joinStyle = MiterJoin THEN
					path.AddLine(x + hx, y + hy)
				ELSIF SELF.joinStyle = RoundJoin THEN
					t := Math.sqrt((idx * idx + idy * idy)/(hx * hx + hy * hy));
					path.AddArc(x + t * hx, y + t * hy, x, y, x - idx, y - idy, x + idy, y - idx)
				END;
				path.AddLine(x - hx, y - hy)
			END AddExitJoinStyle;

			PROCEDURE GetPolyOutline (VAR x, y: ARRAY OF REAL; n: LONGINT; dxi, dyi, dxo, dyo: REAL; dst: GfxPaths.Path);
				VAR closed: BOOLEAN; width, odx, ody, idx, idy, hx, hy: REAL; i, j: LONGINT;
			BEGIN
				closed := (x[n] = x[0]) & (y[n] = y[0]);
				GfxMatrix.ApplyToDist(SELF.cam, 0.5*SELF.lineWidth, width);
				GetNormVector(x[1] - x[0], y[1] - y[0], width, odx, ody);
				IF (dxi = 0) & (dyi = 0) THEN
					SELF.EnterCapStyle(x[0], y[0], odx, ody, dst)
				ELSE
					GetNormVector(dxi, dyi, width, idx, idy);
					GetHalfAxisVector(idx, idy, odx, ody, hx, hy);
					IF (hx = 0) & (hy = 0) THEN	(* collinear vectors *)
						IF closed THEN
							dst.AddEnter(x[0] + ody, y[0] - odx, dxi, dyi)
						ELSE
							dst.AddEnter(x[0] - ody, y[0] + odx, ody, -odx);
							dst.AddLine(x[0] + ody, y[0] - odx)
						END
					ELSIF idx * ody > idy * odx THEN	(* starts with left turn *)
						IF closed THEN
							SELF.EnterJoinStyle(x[0], y[0], idx, idy, hx, hy, odx, ody, dst)
						ELSE
							dst.AddEnter(x[0] - hx, y[0] - hy, ody, -odx);
							SELF.AddEnterJoinStyle(x[0], y[0], hx, hy, odx, ody, dst)
						END
					ELSE
						IF closed THEN
							dst.AddEnter(x[0] - hx, y[0] - hy, dxi, dyi)
						ELSE
							dst.AddEnter(x[0] + hx, y[0] + hy, -hx, -hy);
							dst.AddLine(x[0] - hx, y[0] - hy)
						END
					END
				END;

				i := 1; j := 2;
				WHILE j <= n DO
					idx := odx; idy := ody;
					GetNormVector(x[j] - x[i], y[j] - y[i], width, odx, ody);
					GetHalfAxisVector(idx, idy, odx, ody, hx, hy);
					IF (hx = 0) & (hy = 0) THEN	(* collinear vectors *)
						dst.AddLine(x[i] + idy, y[i] - idx)
					ELSIF idx * ody > idy * odx THEN	(* left turn => outer join *)
						dst.AddLine(x[i] + idy, y[i] - idx);
						SELF.AddJoinStyle(x[i], y[i], idx, idy, hx, hy, odx, ody, dst)
					ELSE	(* right turn => inner join *)
						dst.AddLine(x[i] - hx, y[i] - hy)
					END;
					i := j; INC(j)
				END;

				idx := odx; idy := ody;
				IF (dxo = 0) & (dyo = 0) THEN
					dst.AddLine(x[n] + ody, y[n] - odx);
					SELF.AddCapStyle(x[n], y[n], -odx, -ody, dst)
				ELSE
					dst.AddLine(x[n] + idy, y[n] - idx);
					GetNormVector(dxo, dyo, width, odx, ody);
					GetHalfAxisVector(idx, idy, odx, ody, hx, hy);
					IF (hx = 0) & (hy = 0) THEN	(* collinear vectors *)
						IF closed THEN
							dst.AddExit(odx, ody);
							dst.AddEnter(x[n] - idy, y[n] + idx, -dxo, -dyo)
						ELSE
							dst.AddLine(x[n] - idy, y[n] + idx)
						END
					ELSIF idx * ody > idy * odx THEN	(* ends in left turn *)
						IF closed THEN
							SELF.ExitJoinStyle(x[n], y[n], idx, idy, hx, hy, odx, ody, dst);
							dst.AddEnter(x[n] - hx, y[n] - hy, -dxo, -dyo)
						ELSE
							SELF.AddExitJoinStyle(x[n], y[n], idx, idy, hx, hy, dst)
						END
					ELSE
						dst.AddLine(x[n] - hx, y[n] - hy);
						IF closed THEN
							dst.AddExit(dxo, dyo);
							SELF.EnterJoinStyle(x[n], y[n], -odx, -ody, -hx, -hy, -idx, -idy, dst)
						ELSE
							SELF.AddEnterJoinStyle(x[n], y[n], -hx, -hy, -idx, -idy, dst)
						END
					END
				END;

				odx := -idx; ody := -idy;
				i := n-1; j := n-2;
				WHILE j >= 0 DO
					idx := odx; idy := ody;
					GetNormVector(x[j] - x[i], y[j] - y[i], width, odx, ody);
					GetHalfAxisVector(idx, idy, odx, ody, hx, hy);
					IF (hx = 0) & (hy = 0) THEN	(* collinear vectors *)
						dst.AddLine(x[i] + idy, y[i] - idx)
					ELSIF idx * ody > idy * odx THEN	(* left turn => outer join *)
						dst.AddLine(x[i] + idy, y[i] - idx);
						SELF.AddJoinStyle(x[i], y[i], idx, idy, hx, hy, odx, ody, dst)
					ELSE	(* right turn => inner join *)
						dst.AddLine(x[i] - hx, y[i] - hy)
					END;
					i := j; DEC(j)
				END;

				IF (dxi = 0) & (dyi = 0) THEN
					dst.AddLine(x[0] + ody, y[0] - odx);
					SELF.ExitCapStyle(x[0], y[0], -odx, -ody, dst)
				ELSE
					idx := odx; idy := ody;
					GetNormVector(-dxi, -dyi, width, odx, ody);
					GetHalfAxisVector(idx, idy, odx, ody, hx, hy);
					dst.AddLine(x[0] + idy, y[0] - idx);
					IF (hx = 0) & (hy = 0) THEN	(* collinear vectors *)
						IF closed THEN
							dst.AddExit(-dxi, -dyi)
						ELSE
							dst.AddExit(-idy, idx)
						END
					ELSIF idx * ody > idy * odx THEN	(* left turn *)
						IF closed THEN
							SELF.ExitJoinStyle(x[0], y[0], idx, idy, hx, hy, odx, ody, dst)
						ELSE
							SELF.AddExitJoinStyle(x[0], y[0], idx, idy, hx, hy, dst);
							dst.AddExit(-idx, -idy)
						END
					ELSE
						dst.AddLine(x[0] - hx, y[0] - hy);
						IF closed THEN
							dst.AddExit(-dxi, -dyi)
						ELSE
							dst.AddExit(hx, hy)
						END
					END
				END
			END GetPolyOutline;

			PROCEDURE GetStrokeOutline (VAR scan: GfxPaths.Scanner; dst: GfxPaths.Path);
				CONST last = 127;
				VAR x, y: ARRAY last+1 OF REAL; dxi, dyi, dxo, dyo: REAL; n: LONGINT;
			BEGIN
				ASSERT(scan.elem = GfxPaths.Enter);
				x[0] := scan.x; y[0] := scan.y; dxi := scan.dx; dyi := scan.dy;
				scan.Scan(); n := 0;
				WHILE scan.elem = GfxPaths.Line DO
					IF n < last THEN
						INC(n); x[n] := scan.x; y[n] := scan.y
					ELSE
						dxo := scan.x - x[n]; dyo := scan.y - y[n];
						SELF.GetPolyOutline(x, y, n, dxi, dyi, dxo, dyo, dst);
						dxi := x[n] - x[n-1]; dyi := y[n] - y[n-1];
						x[0] := x[n]; y[0] := y[n];
						x[1] := scan.x; y[1] := scan.y;
						n := 1
					END;
					scan.Scan()
				END;
				IF n > 0 THEN
					SELF.GetPolyOutline(x, y, n, dxi, dyi, scan.dx, scan.dy, dst)
				END;
				scan.Scan()
			END GetStrokeOutline;

			(** get offset values and pattern index of visible and invisible dash part at start of subpath (in device space) **)
			PROCEDURE GetDashOffsets* (offset: REAL; VAR beg, end, next: REAL; VAR idx: LONGINT);
				VAR phase, period, len: REAL;
			BEGIN
				idx := 0;
				GfxMatrix.ApplyToDist(SELF.cam, SELF.dashPhase, phase);
				GfxMatrix.ApplyToDist(SELF.cam, SELF.dashPeriod, period);
				beg := ENTIER((phase + offset)/period) * period - phase;	(* offset - period < beg <= offset *)
				LOOP
					GfxMatrix.ApplyToDist(SELF.cam, SELF.dashPatOn[idx], len);
					end := beg + len;
					GfxMatrix.ApplyToDist(SELF.cam, SELF.dashPatOff[idx], len);
					next := end + len;
					idx := (idx+1) MOD SELF.dashPatLen;
					IF next > offset THEN EXIT END;
					beg := next
				END
			END GetDashOffsets;

			PROCEDURE GetDashOutline (VAR scan: GfxPaths.Scanner; dst: GfxPaths.Path);
				VAR
					width, cx, cy, dx, dy, beg, end, next, offset, len, cos, sin, wdx, wdy, endOff, dash, nx, ny: REAL;
					index: LONGINT; dscan: GfxPaths.Scanner;
			BEGIN
				GfxMatrix.ApplyToDist(SELF.cam, 0.5*SELF.lineWidth, width);
				ASSERT(scan.elem = GfxPaths.Enter);
				cx := scan.x; cy := scan.y; dx := scan.dx; dy := scan.dy;
				scan.Scan();
				SELF.GetDashOffsets(0, beg, end, next, index);
				IF 0 < end THEN	(* starts within dash *)
					IF width = 0 THEN
						dst.AddEnter(cx, cy, dx, dy)
					ELSE
						SELF.dashPath.Clear();
						SELF.dashPath.AddEnter(cx, cy, dx, dy)
					END
				END;
				offset := 0;
				WHILE scan.elem = GfxPaths.Line DO
					dx := scan.x - cx; dy := scan.y - cy;
					len := Math.sqrt(dx * dx + dy * dy);
					cos := dx/len; sin := dy/len;
					endOff := offset + len;
					IF offset < end THEN	(* begin of line is within dash *)
						IF end <= endOff THEN	(* end of current dash comes before end of line => finish current dash *)
							len := end - offset;
							IF width = 0 THEN
								dst.AddLine(cx + len * cos, cy + len * sin);
								dst.AddExit(0, 0)
							ELSE
								SELF.dashPath.AddLine(cx + len * cos, cy + len * sin);
								SELF.dashPath.AddExit(0, 0);
								dscan.Open(SELF.dashPath, 0);
								SELF.GetStrokeOutline(dscan, dst)
							END
						ELSIF width = 0 THEN	(* continue current dash to end of line *)
							dst.AddLine(scan.x, scan.y)
						ELSE
							SELF.dashPath.AddLine(scan.x, scan.y)
						END
					END;
					IF next < endOff THEN	(* next dash starts before end of line => draw complete dashes *)
						wdx := width * cos; wdy := width * sin;
						beg := offset;
						REPEAT
							len := next - beg;
							cx := cx + len * cos; cy := cy + len * sin;
							beg := next;
							GfxMatrix.ApplyToDist(SELF.cam, SELF.dashPatOn[index], dash);
							end := beg + dash;
							GfxMatrix.ApplyToDist(SELF.cam, SELF.dashPatOff[index], dash);
							next := end + dash;
							index := (index+1) MOD SELF.dashPatLen;
							IF end <= endOff THEN	(* next dash can be fully drawn *)
								len := end - beg;
								nx := cx + len * cos; ny := cy + len * sin;
								IF width = 0 THEN
									dst.AddEnter(cx, cy, 0, 0);
									dst.AddLine(nx, ny);
									dst.AddExit(0, 0)
								ELSE
									SELF.EnterCapStyle(cx, cy, wdx, wdy, dst);
									dst.AddLine(nx + wdy, ny - wdx);
									SELF.AddCapStyle(nx, ny, -wdx, -wdy, dst);
									dst.AddLine(cx - wdy, cy + wdx);
									SELF.ExitCapStyle(cx, cy, wdx, wdy, dst)
								END
							END
						UNTIL next >= endOff;
						IF endOff < end THEN	(* next dash not complete => hasn't been started yet *)
							IF width = 0 THEN
								dst.AddEnter(cx, cy, 0, 0);
								dst.AddLine(scan.x, scan.y)
							ELSE
								SELF.dashPath.Clear();
								SELF.dashPath.AddEnter(cx, cy, 0, 0);
								SELF.dashPath.AddLine(scan.x, scan.y)
							END
						END
					END;
					cx := scan.x; cy := scan.y; offset := endOff;
					scan.Scan()
				END;
				ASSERT(scan.elem = GfxPaths.Exit);
				IF offset < end THEN	(* currently within dash => end properly *)
					IF width = 0 THEN
						dst.AddExit(scan.dx, scan.dy)
					ELSE
						SELF.dashPath.AddExit(scan.dx, scan.dy);
						dscan.Open(SELF.dashPath, 0);
						SELF.GetStrokeOutline(dscan, dst)
					END
				END;
				scan.Scan()
			END GetDashOutline;

			(** store outline/dashes of current path in specified path **)
			PROCEDURE GetOutline* (dst: GfxPaths.Path);
				VAR scan: GfxPaths.Scanner;
			BEGIN
				ASSERT(dst # SELF.path, 100);
				SELF.Flatten();
				dst.Clear();
				scan.Open(SELF.path, 0);
				WHILE scan.elem = GfxPaths.Enter DO
					IF SELF.dashPatLen > 0 THEN
						SELF.GetDashOutline(scan, dst)
					ELSE
						SELF.GetStrokeOutline(scan, dst)
					END
				END
			END GetOutline;

		(**--- Drawing Operations ---**)

			(** draw current path in requested mode **)
			PROCEDURE Render* (mode: SET);
			BEGIN
				ASSERT(~(InPath IN SELF.mode), 100);
				EXCL(mode, Record);
				IF mode # {} THEN
					SELF.DoRender(mode)
				END
			END Render;

			(** draw given path in requested mode **)
			PROCEDURE DrawPath* (path: GfxPaths.Path; mode: SET);
				VAR scan: GfxPaths.Scanner;
			BEGIN
				ASSERT(~(InPath IN SELF.mode), 100);
				IF path = SELF.path THEN
					EXCL(mode, Record);
					IF mode # {} THEN
						SELF.DoRender(mode)
					END;
				ELSE
					SELF.DoBegin(mode);
					scan.Open(path, 0);
					WHILE scan.elem # GfxPaths.Stop DO
						CASE scan.elem OF
						| GfxPaths.Enter: SELF.DoEnter(scan.x, scan.y, scan.dx, scan.dy)
						| GfxPaths.Line: SELF.DoLine(scan.x, scan.y);
						| GfxPaths.Arc: SELF.DoArc(scan.x, scan.y, scan.x0, scan.y0, scan.x1, scan.y1, scan.x2, scan.y2)
						| GfxPaths.Bezier: SELF.DoBezier(scan.x, scan.y, scan.x1, scan.y1, scan.x2, scan.y2)
						| GfxPaths.Exit: SELF.DoExit(scan.dx, scan.dy)
						END;
						scan.Scan();
					END;
					SELF.DoEnd()
				END
			END DrawPath;

			(** draw line in requested mode **)
			PROCEDURE DrawLine* (x0, y0, x1, y1: REAL; mode: SET);
			BEGIN
				IF (x0=x1)&(y0=y1) THEN RETURN END; (*optimization PH 2012*)
				ASSERT(~(InPath IN SELF.mode), 100);
				ASSERT(mode * {Fill, Clip, EvenOdd} = {}, 101);
				SELF.DoBegin(mode);
				SELF.DoEnter(x0, y0, 0, 0);
				SELF.DoLine(x1, y1);
				SELF.DoExit(0, 0);
				SELF.DoEnd()
			END DrawLine;

			(** draw arc in requested mode (start and end angle in radians; negative radius for clockwise arc) **)
			PROCEDURE DrawArc* (x, y, r, start, end: REAL; mode: SET);
				VAR x1, y1, x2, y2: REAL;
			BEGIN
				ASSERT(~(InPath IN SELF.mode), 100);
				ASSERT(mode * {Fill, Clip, EvenOdd} = {}, 101);
				IF r > 0 THEN x1 := x + r; y1 := y; x2 := x; y2 := y + r
				ELSIF r < 0 THEN r := -r; x1 := x; y1 := y + r; x2 := x + r; y2 := y
				ELSE RETURN
				END;
				SELF.DoBegin(mode);
				SELF.DoEnter(x + r * Math.cos(start), y + r * Math.sin(start), 0, 0);
				SELF.DoArc(x + r * Math.cos(end), y + r * Math.sin(end), x, y, x1, y1, x2, y2);
				SELF.DoEnd()
			END DrawArc;

			(** draw rectangle in requested mode **)
			PROCEDURE DrawRect* (x0, y0, x1, y1: REAL; mode: SET);
			BEGIN
				ASSERT(~(InPath IN SELF.mode), 100);
				SELF.DoBegin(mode);
				SELF.DoRect(x0, y0, x1, y1);
				SELF.DoEnd()
			END DrawRect;

			(** draw circle in requested mode (clockwise if r > 0, counterclockwise if r < 0) **)
			PROCEDURE DrawCircle* (x, y, r: REAL; mode: SET);
			BEGIN
				ASSERT(~(InPath IN SELF.mode), 100);
				SELF.DoBegin(mode);
				SELF.DoEllipse(x, y, r, ABS(r));
				SELF.DoEnd()
			END DrawCircle;

			(** draw ellipse in requested mode (clockwise if rx*ry > 0, counterclockwise if rx*ry < 0) **)
			PROCEDURE DrawEllipse* (x, y, rx, ry: REAL; mode: SET);
			BEGIN
				ASSERT(~(InPath IN SELF.mode), 100);
				SELF.DoBegin(mode);
				SELF.DoEllipse(x, y, rx, ry);
				SELF.DoEnd()
			END DrawEllipse;

			(** draw string at given coordinates and move current point to string end **)
			PROCEDURE DrawStringAt* (x, y: REAL; str: ARRAY OF CHAR);
			BEGIN
				ASSERT(~(InPath IN SELF.mode), 100);
				SELF.DoBegin({Fill});
				SELF.DoShow(x, y, str);
				SELF.DoEnd()
			END DrawStringAt;

			(** draw string at current point and move current point to string end **)
			PROCEDURE DrawString* (str: ARRAY OF CHAR);
			BEGIN
				ASSERT(~(InPath IN SELF.mode), 100);
				SELF.DoBegin({Fill});
				SELF.DoShow(SELF.cpx, SELF.cpy, str);
				SELF.DoEnd()
			END DrawString;

		(** images and patterns **)

			(** draw image at given point **)
			PROCEDURE DrawImageAt* (x, y: REAL; img: GfxImages.Image; VAR filter: GfxImages.Filter);
			BEGIN
				SELF.DrawImage(x, y, img, filter)
			END DrawImageAt;

			PROCEDURE{ABSTRACT} DrawImage*(x, y: REAL; img: GfxImages.Image; VAR filter: GfxImages.Filter); END DrawImage;

			PROCEDURE NewPattern*(img: GfxImages.Image; px, py: REAL): Pattern;
				VAR pat: Pattern;
			BEGIN
				NEW(pat); pat.img := img; pat.px := px; pat.py := py;
				RETURN pat
			END NewPattern;

		(**--- Implementation ---**)
			(** draw current path in requested mode **)
			PROCEDURE{ABSTRACT} DoRender*(mode: SET); END DoRender;

			(** start new path **)
			PROCEDURE{ABSTRACT} DoBegin*(mode: SET); END DoBegin;

			(** exit current subpath (if open) and end current path **)
			PROCEDURE{ABSTRACT} DoEnd*(); END DoEnd;

			(** start subpath at inner point **)
			PROCEDURE{ABSTRACT} DoEnter*(x, y, dx, dy: REAL); END DoEnter;

			(** end subpath at inner point **)
			PROCEDURE{ABSTRACT} DoExit*(dx, dy: REAL); END DoExit;

			(** close current subpath **)
			PROCEDURE{ABSTRACT} DoClose*(); END DoClose;

			(** append line to current path **)
			PROCEDURE{ABSTRACT} DoLine*(x, y: REAL); END DoLine;

			(** append arc to current path **)
			PROCEDURE{ABSTRACT} DoArc*(x, y, x0, y0, x1, y1, x2, y2: REAL); END DoArc;

			(** append cubic bezier to current path **)
			PROCEDURE{ABSTRACT} DoBezier*(x, y, x1, y1, x2, y2: REAL); END DoBezier;

			(** append character outlines to current path at current point; advance current point to position after last character **)
			PROCEDURE{ABSTRACT} DoShow*(x, y: REAL; VAR str: ARRAY OF CHAR); END DoShow;

			(** painting operators (potential for optimization) **)
			PROCEDURE{ABSTRACT} DoRect*(x0, y0, x1, y1: REAL); (* default implementation *)
			BEGIN
				SELF.DoEnter(x0, y0, 0, y0 - y1);
				SELF.DoLine(x1, y0); SELF.DoLine(x1, y1); SELF.DoLine(x0, y1); SELF.DoLine(x0, y0);
				SELF.DoExit(x1 - x0, 0)
			END DoRect;

			PROCEDURE{ABSTRACT} DoEllipse*(x, y, rx, ry: REAL); (* default implementation *)
				VAR xr: REAL;
			BEGIN
				xr := x + rx;
				IF xr # x THEN
					SELF.DoEnter(xr, y, 0, ry);
					SELF.DoArc(xr, y, x, y, xr, y, x, y + ry);
					SELF.DoExit(0, ry)
				END
			END DoEllipse;

		END Context;

		(** graphics state **)
		State* = RECORD
			saved: SET;
			strokeCol, fillCol: Color; strokePat, fillPat: Pattern;
			lineWidth: REAL;
			dashPatOn, dashPatOff: ARRAY MaxDashPatSize OF REAL;
			dashPatLen: LONGINT; dashPhase: REAL;
			capStyle: CapStyle; joinStyle: JoinStyle; styleLimit: REAL;
			flatness: REAL;
			font: GfxFonts.Font;
			ctm: GfxMatrix.Matrix;
			clip: ClipArea;
		END;

		PathData = RECORD (GfxPaths.EnumData)
			path: GfxPaths.Path;
		END;


	VAR
		Black*, White*, Red*, Green*, Blue*, Cyan*, Magenta*, Yellow*, LGrey*, MGrey*, DGrey*: Color;	(** standard colors **)
		DefaultCap*: CapStyle;	(** default line cap style (initially butt caps) **)
		DefaultJoin*: JoinStyle;	(** default line join style (initially miter joins) **)


	(**--- Contexts ---**)

	(** reset context to default values **)
	PROCEDURE Reset* (ctxt: Context);
	BEGIN
		ctxt.Reset()
	END Reset;

	(** initialize context values to defaults **)
	PROCEDURE Init* (ctxt: Context);
	BEGIN
		ctxt.InitContext();
	END Init;

	(** save and restore graphics state **)
	PROCEDURE Save* (ctxt: Context; elems: SET; VAR state: State);
		VAR i: LONGINT;
	BEGIN
		state.saved := elems;
		state.strokeCol := ctxt.strokeCol; state.strokePat := ctxt.strokePat;
		state.fillCol := ctxt.fillCol; state.fillPat := ctxt.fillPat;
		state.lineWidth := ctxt.lineWidth;
		IF dashPat IN elems THEN
			state.dashPatLen := ctxt.dashPatLen; state.dashPhase := ctxt.dashPhase;
			i := 0;
			WHILE i < ctxt.dashPatLen DO
				state.dashPatOn[i] := ctxt.dashPatOn[i]; state.dashPatOff[i] := ctxt.dashPatOff[i]; INC(i)
			END
		END;
		state.capStyle := ctxt.capStyle; state.joinStyle := ctxt.joinStyle; state.styleLimit := ctxt.styleLimit;
		state.flatness := ctxt.flatness;
		state.font := ctxt.font;
		IF ctm IN elems THEN
			state.ctm := ctxt.ctm
		END;
		IF clip IN elems THEN
			state.clip := ctxt.GetClip()
		END
	END Save;

	PROCEDURE Restore* (ctxt: Context; state: State);
	BEGIN
		ASSERT(~(InPath IN ctxt.mode), 100);
		IF strokeColPat IN state.saved THEN
			ctxt.SetStrokeColor(state.strokeCol);
			ctxt.SetStrokePattern(state.strokePat)
		END;
		IF fillColPat IN state.saved THEN
			ctxt.SetFillColor(state.fillCol);
			ctxt.SetFillPattern(state.fillPat)
		END;
		IF lineWidth IN state.saved THEN
			ctxt.SetLineWidth(state.lineWidth)
		END;
		IF dashPat IN state.saved THEN
			ctxt.SetDashPattern(state.dashPatOn, state.dashPatOff, state.dashPatLen, state.dashPhase)
		END;
		IF capStyle IN state.saved THEN
			ctxt.SetCapStyle(state.capStyle)
		END;
		IF joinStyle IN state.saved THEN
			ctxt.SetJoinStyle(state.joinStyle)
		END;
		IF styleLimit IN state.saved THEN
			ctxt.SetStyleLimit(state.styleLimit)
		END;
		IF flatness IN state.saved THEN
			ctxt.SetFlatness(state.flatness)
		END;
		IF font IN state.saved THEN
			ctxt.SetFont(state.font)
		END;
		IF ctm IN state.saved THEN
			ctxt.SetCTM(state.ctm)
		END;
		IF clip IN state.saved THEN
			ctxt.SetClip(state.clip)
		END
	END Restore;

	(**--- Coordinate System ---**)

	(** reset current transformation matrix **)
	PROCEDURE ResetCTM* (ctxt: Context);
	BEGIN
		ctxt.ResetCTM()
	END ResetCTM;

	(** set current transformation matrix **)
	PROCEDURE SetCTM* (ctxt: Context; VAR mat: GfxMatrix.Matrix);
	BEGIN
		ctxt.SetCTM(mat)
	END SetCTM;

	(** translate coordinate system **)
	PROCEDURE Translate* (ctxt: Context; dx, dy: REAL);
	BEGIN
		ctxt.Translate(dx, dy)
	END Translate;

	(** scale coordinate system at origin **)
	PROCEDURE Scale* (ctxt: Context; sx, sy: REAL);
	BEGIN
		ctxt.Scale(sx, sy)
	END Scale;

	(** scale coordinate system at specified point **)
	PROCEDURE ScaleAt* (ctxt: Context; sx, sy, x, y: REAL);
	BEGIN
		ctxt.ScaleAt(sx, sy, x, y);
	END ScaleAt;

	(** rotate coordinate system at origin **)
	PROCEDURE Rotate* (ctxt: Context; sin, cos: REAL);
	BEGIN
		ctxt.Rotate(sin, cos)
	END Rotate;

	(** rotate coordinate system at specified point **)
	PROCEDURE RotateAt* (ctxt: Context; sin, cos, x, y: REAL);
	BEGIN
		ctxt.RotateAt(sin, cos, x, y);
	END RotateAt;

	(** concat transformation matrix to CTM **)
	PROCEDURE Concat* (ctxt: Context; VAR mat: GfxMatrix.Matrix);
	BEGIN
		ctxt.Concat(mat)
	END Concat;


	(**--- Clipping ---**)

	(** reset clip path **)
	PROCEDURE ResetClip* (ctxt: Context);
	BEGIN
		ctxt.ResetClip()
	END ResetClip;

	(** get bounding box of clipping path in user coordinates **)
	PROCEDURE GetClipRect* (ctxt: Context; VAR llx, lly, urx, ury: REAL);
	BEGIN
		ctxt.GetClipRect(llx, lly, urx, ury)
	END GetClipRect;

	(** get current clipping area **)
	PROCEDURE GetClip* (ctxt: Context): ClipArea;
	BEGIN
		RETURN ctxt.GetClip()
	END GetClip;

	(** restore saved clipping path **)
	PROCEDURE SetClip* (ctxt: Context; clip: ClipArea);
	BEGIN
		ctxt.SetClip(clip)
	END SetClip;


	(**--- Graphics State ---**)

	(** set stroke color **)
	PROCEDURE SetStrokeColor* (ctxt: Context; color: Color);
	BEGIN
		ctxt.SetStrokeColor(color)
	END SetStrokeColor;

	(** set stroke pattern (NIL = solid) **)
	PROCEDURE SetStrokePattern* (ctxt: Context; pat: Pattern);
	BEGIN
		ctxt.SetStrokePattern(pat)
	END SetStrokePattern;

	(** set fill color **)
	PROCEDURE SetFillColor* (ctxt: Context; color: Color);
	BEGIN
		ctxt.SetFillColor(color)
	END SetFillColor;

	(** set fill pattern (NIL = solid) **)
	PROCEDURE SetFillPattern* (ctxt: Context; pat: Pattern);
	BEGIN
		ctxt.SetFillPattern(pat)
	END SetFillPattern;

	(** set line width **)
	PROCEDURE SetLineWidth* (ctxt: Context; width: REAL);
	BEGIN
		ctxt.SetLineWidth(width)
	END SetLineWidth;

	(** set dash pattern **)
	PROCEDURE SetDashPattern* (ctxt: Context; VAR on, off: ARRAY OF REAL; len: LONGINT; phase: REAL);
	BEGIN
		ctxt.SetDashPattern(on, off, len, phase)
	END SetDashPattern;

	(** copy values from parameter, and calculate dash period **)
	PROCEDURE SetDashArray* (ctxt: Context; VAR on, off: ARRAY OF REAL; len: LONGINT);
	BEGIN
		ctxt.SetDashArray(on, off, len);
	END SetDashArray;

	(** set line cap style **)
	PROCEDURE SetCapStyle* (ctxt: Context; style: CapStyle);
	BEGIN
		ctxt.SetCapStyle(style)
	END SetCapStyle;

	(** set line join style **)
	PROCEDURE SetJoinStyle* (ctxt: Context; style: JoinStyle);
	BEGIN
		ctxt.SetJoinStyle(style)
	END SetJoinStyle;

	(** set style border factor **)
	PROCEDURE SetStyleLimit* (ctxt: Context; limit: REAL);
	BEGIN
		ctxt.SetStyleLimit(limit)
	END SetStyleLimit;

	(** set flatness parameter **)
	PROCEDURE SetFlatness* (ctxt: Context; flatness: REAL);
	BEGIN
		ctxt.SetFlatness(flatness)
	END SetFlatness;

	(** set current font **)
	PROCEDURE SetFont* (ctxt: Context; font: GfxFonts.Font);
	BEGIN
		ctxt.SetFont(font)
	END SetFont;

	(** set current font using name and size **)
	PROCEDURE SetFontName* (ctxt: Context; fontname: ARRAY OF CHAR; size: INTEGER);
	BEGIN
		ctxt.SetFontName(fontname, size);
	END SetFontName;

	(** calculate distance that current point would move if given string were rendered **)
	PROCEDURE GetStringWidth* (ctxt: Context; str: ARRAY OF CHAR; VAR dx, dy: REAL);
	BEGIN
		ctxt.GetStringWidth(str, dx, dy)
	END GetStringWidth;


	(**--- Current Path ---**)

	(** start new path **)
	PROCEDURE Begin* (ctxt: Context; mode: SET);
	BEGIN
		ctxt.Begin(mode);
	END Begin;

	(** exit current subpath (if open) and end current path **)
	PROCEDURE End* (ctxt: Context);
	BEGIN
		ctxt.End();
	END End;

	(** end current subpath (if open) and begin new subpath **)
	PROCEDURE MoveTo* (ctxt: Context; x, y: REAL);
	BEGIN
		ctxt.MoveTo(x, y);
	END MoveTo;

	(** start subpath at inner point **)
	PROCEDURE Enter* (ctxt: Context; x, y, dx, dy: REAL);
	BEGIN
		ctxt.Enter(x, y, dx, dy);
	END Enter;

	(** end subpath at inner point **)
	PROCEDURE Exit* (ctxt: Context; dx, dy: REAL);
	BEGIN
		ctxt.Exit(dx, dy);
	END Exit;

	(** close current subpath **)
	PROCEDURE Close* (ctxt: Context);
	BEGIN
		ctxt.Close();
	END Close;

	(** append line to current path **)
	PROCEDURE LineTo* (ctxt: Context; x, y: REAL);
	BEGIN
		ctxt.LineTo(x, y);
	END LineTo;

	(** append arc to current path **)
	PROCEDURE ArcTo* (ctxt: Context; x, y, x0, y0, x1, y1, x2, y2: REAL);
	BEGIN
		ctxt.ArcTo(x, y, x0, y0, x1, y1, x2, y2);
	END ArcTo;

	(** append cubic bezier to current path **)
	PROCEDURE BezierTo* (ctxt: Context; x, y, x1, y1, x2, y2: REAL);
	BEGIN
		ctxt.BezierTo(x, y, x1, y1, x2, y2);
	END BezierTo;

	(** append character outlines to current path at given point; advance current point to position after last character **)
	PROCEDURE ShowAt* (ctxt: Context; x, y: REAL; str: ARRAY OF CHAR);
	BEGIN
		ctxt.ShowAt(x, y, str);
	END ShowAt;

	(** append character outlines to current path at current point; advance current point to position after last character **)
	PROCEDURE Show* (ctxt: Context; str: ARRAY OF CHAR);
	BEGIN
		ctxt.Show(str);
	END Show;


	(**--- Path Flattening ---**)

	(** replace arcs and beziers in current path by approximation using straight lines **)
	PROCEDURE Flatten* (ctxt: Context);
	BEGIN
		ctxt.Flatten()
	END Flatten;

	PROCEDURE EnumPathElem (VAR data: GfxPaths.EnumData);
	BEGIN
		WITH data: PathData DO
			CASE data.elem OF
			| GfxPaths.Enter: data.path.AddEnter(data.x, data.y, data.dx, data.dy)
			| GfxPaths.Line: data.path.AddLine(data.x, data.y)
			| GfxPaths.Exit: data.path.AddExit(data.dx, data.dy)
			END
		END
	END EnumPathElem;

	(** store flattened current path in given path  **)
	PROCEDURE GetFlattenedPath* (ctxt: Context; path: GfxPaths.Path);
	BEGIN
		ctxt.GetFlattenedPath(path);
	END GetFlattenedPath;


	(**--- Cap Styles ---**)

	PROCEDURE EnterCapStyle* (ctxt: Context; x, y, dx, dy: REAL; path: GfxPaths.Path);
	BEGIN
		ctxt.EnterCapStyle(x, y, dx, dy, path);
	END EnterCapStyle;

	PROCEDURE AddCapStyle* (ctxt: Context; x, y, dx, dy: REAL; path: GfxPaths.Path);
	BEGIN
		ctxt.AddCapStyle(x, y, dx, dy, path);
	END AddCapStyle;

	PROCEDURE ExitCapStyle* (ctxt: Context; x, y, dx, dy: REAL; path: GfxPaths.Path);
	BEGIN
		ctxt.ExitCapStyle(x, y, dx, dy, path);
	END ExitCapStyle;


	(**--- Join Styles ---**)

	(** return if half axis vector (in device coordinates) exceeds style limit **)
	PROCEDURE ExceedsLimit* (ctxt: Context; hx, hy: REAL): BOOLEAN;
	BEGIN
		RETURN ctxt.ExceedsLimit(hx, hy);
	END ExceedsLimit;

	PROCEDURE EnterJoinStyle* (ctxt: Context; x, y, idx, idy, hx, hy, odx, ody: REAL; path: GfxPaths.Path);
	BEGIN
		ctxt.EnterJoinStyle(x, y, idx, idy, hx, hy, odx, ody, path);
	END EnterJoinStyle;

	PROCEDURE AddJoinStyle* (ctxt: Context; x, y, idx, idy, hx, hy, odx, ody: REAL; path: GfxPaths.Path);
	BEGIN
		ctxt.AddJoinStyle(x, y, idx, idy, hx, hy, odx, ody, path);
	END AddJoinStyle;

	PROCEDURE ExitJoinStyle* (ctxt: Context; x, y, idx, idy, hx, hy, odx, ody: REAL; path: GfxPaths.Path);
	BEGIN
		ctxt.ExitJoinStyle(x, y, idx, idy, hx, hy, odx, ody, path);
	END ExitJoinStyle;


	(**--- Path Outline ---**)

	(** replace current path by outline of area which would be drawn to if the path were stroked **)
	PROCEDURE Outline* (ctxt: Context);
	BEGIN
		ctxt.Outline()
	END Outline;

	(** return vector scaled to given length **)
	PROCEDURE GetNormVector* (x, y, len: REAL; VAR nx, ny: REAL);
		VAR t: REAL;
	BEGIN
		t := len/Math.sqrt(x * x + y * y);
		nx := t * x; ny := t * y
	END GetNormVector;

	(** return vector to outer corner of two joining vectors whose lengths correspond to line width **)
	PROCEDURE GetHalfAxisVector* (idx, idy, odx, ody: REAL; VAR hx, hy: REAL);
		VAR cprod, t: REAL;
	BEGIN
		cprod := idx * ody - idy * odx;
		IF ABS(cprod) < 1.0E-3 THEN
			hx := 0; hy := 0
		ELSE	(* intersect outer border lines to find half axis vector *)
			t := ((idy - ody) * ody + (idx - odx) * odx)/cprod;
			IF cprod > 0 THEN	(* left turn *)
				hx := idy - t * idx; hy := -(idx + t * idy)
			ELSE	(* right turn *)
				hx := t * idx - idy; hy := idx + t * idy
			END
		END
	END GetHalfAxisVector;

	(** get offset values and pattern index of visible and invisible dash part at start of subpath (in device space) **)
	PROCEDURE GetDashOffsets* (ctxt: Context; offset: REAL; VAR beg, end, next: REAL; VAR idx: LONGINT);
	BEGIN
		ctxt.GetDashOffsets(offset, beg, end, next, idx);
	END GetDashOffsets;

	(** store outline/dashes of current path in specified path **)
	PROCEDURE GetOutline* (ctxt: Context; dst: GfxPaths.Path);
	BEGIN
		ctxt.GetOutline(dst);
	END GetOutline;


	(**--- Drawing Operations ---**)

	(** draw current path in requested mode **)
	PROCEDURE Render* (ctxt: Context; mode: SET);
	BEGIN
		ASSERT(~(InPath IN ctxt.mode), 100);
		EXCL(mode, Record);
		IF mode # {} THEN
			ctxt.DoRender(mode)
		END
	END Render;

	(** draw given path in requested mode **)
	PROCEDURE DrawPath* (ctxt: Context; path: GfxPaths.Path; mode: SET);
	BEGIN
		ctxt.DrawPath(path, mode);
	END DrawPath;

	(** draw line in requested mode **)
	PROCEDURE DrawLine* (ctxt: Context; x0, y0, x1, y1: REAL; mode: SET);
	BEGIN
		ctxt.DrawLine(x0, y0, x1, y1, mode);
	END DrawLine;

	(** draw arc in requested mode (start and end angle in radians; negative radius for clockwise arc) **)
	PROCEDURE DrawArc* (ctxt: Context; x, y, r, start, end: REAL; mode: SET);
	BEGIN
		ctxt.DrawArc(x, y, r, start, end, mode);
	END DrawArc;

	(** draw rectangle in requested mode **)
	PROCEDURE DrawRect* (ctxt: Context; x0, y0, x1, y1: REAL; mode: SET);
	BEGIN
		ctxt.DrawRect(x0, y0, x1, y1, mode);
	END DrawRect;

	(** draw circle in requested mode (clockwise if r > 0, counterclockwise if r < 0) **)
	PROCEDURE DrawCircle* (ctxt: Context; x, y, r: REAL; mode: SET);
	BEGIN
		ctxt.DrawCircle(x, y, r, mode);
	END DrawCircle;

	(** draw ellipse in requested mode (clockwise if rx*ry > 0, counterclockwise if rx*ry < 0) **)
	PROCEDURE DrawEllipse* (ctxt: Context; x, y, rx, ry: REAL; mode: SET);
	BEGIN
		ctxt.DrawEllipse(x, y, rx, ry, mode);
	END DrawEllipse;

	(** draw string at given coordinates and move current point to string end **)
	PROCEDURE DrawStringAt* (ctxt: Context; x, y: REAL; str: ARRAY OF CHAR);
	BEGIN
		ctxt.DrawStringAt(x, y, str);
	END DrawStringAt;

	(** draw string at current point and move current point to string end **)
	PROCEDURE DrawString* (ctxt: Context; str: ARRAY OF CHAR);
	BEGIN
		ctxt.DrawString(str);
	END DrawString;


	(**--- Images and Patterns ---**)

	(** draw image at given point **)
	PROCEDURE DrawImageAt* (ctxt: Context; x, y: REAL; img: GfxImages.Image; VAR filter: GfxImages.Filter);
	BEGIN
		ctxt.DrawImage(x, y, img, filter)
	END DrawImageAt;

	(** return new pattern **)
	PROCEDURE NewPattern* (ctxt: Context; img: GfxImages.Image; px, py: REAL): Pattern;
	BEGIN
		RETURN ctxt.NewPattern(img, px, py)
	END NewPattern;

	(*--- Initialization of Standard Colors ---*)

	PROCEDURE InitColors;
		PROCEDURE init (VAR col: Color; r, g, b: INTEGER);
		BEGIN
			col.r := r; col.g := g; col.b := b; col.a := 255
		END init;
	BEGIN
		init(Black, 0, 0, 0); init(White, 255, 255, 255); init(Red, 255, 0, 0); init(Green, 0, 255, 0); init(Blue, 0, 0, 255);
		init(Cyan, 0, 255, 255); init(Magenta, 255, 0, 255); init(Yellow, 255, 255, 0);
		init(LGrey, 192, 192, 192); init(MGrey, 160, 160, 160); init(DGrey, 128, 128, 128)
	END InitColors;


BEGIN
	InitColors;
	DefaultCap := ButtCap; DefaultJoin := MiterJoin
END Gfx.
