(* ETH Oberon, Copyright 2001 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

MODULE GfxRegions; (** portable *)	(* eos  *)
(** AUTHOR "eos"; PURPOSE "Arbitrarily shaped two_dimensional regions"; *)

	(*
		17.2.97 - eliminated rectangle type, added shift offsets, made enumerator extensible
		2.5.97 - prevent dropouts when validating
		17.7.97 - fixed bug in Validate (trying to copy filler spans if data was reallocated)
		17.7.97 - eliminated size field
		12.3.98 - eliminated shifted operations, fixed Shift to treat boundary cases correctly
		5.5.98 - fixed bug in Intersect (wrong index into arg region)
	*)

	CONST
		(** mode for reducing regions to non_overlapping areas **)
		Winding* = 0;	(** non_zero winding rule **)
		EvenOdd* = 1;	(** exclusive_or rule **)

		(** interval of valid region coordinates (UBound - LBound is still representable within INTEGER **)
		UBound* = MAX(INTEGER) DIV 2;
		LBound* = MIN(INTEGER) DIV 2;

		BlockSize = 512;	(* size increment for region data blocks *)
		Enter = 1; Exit = -1;	(* direction of bounding curve at scanline intersection *)
		FirstSlice = 2;	(* index of first slice *)
		Bottom = MIN(INTEGER); Top = MAX(INTEGER);	(* sentinel values *)


	TYPE
		RegionData = POINTER TO ARRAY OF LONGINT;

		(** regions of arbitrary shape **)
		(*
			Implementation notes:

			Regions are managed by slicing them horizontally. For each scanline y, a set of spans on the scanline defines which
			parts of the scanline are part of the region. The spans are defined through the x_coordinates of their end points.
			Every point on a scanline has a direction attribute, which specifies whether the point starts a span (Enter) or ends
			one (Exit), allowing spans to nest or overlap.

			The x_ and y_coordinates of a point along with its direction are encoded into a LONGINT. The chosen encoding
			weights the y_coordinate most, followed by the x_coordinate and the direction of an intersection. Visiting all
			encoded points in ascending order therefore traverses all spans of the region from the bottom left corner to the
			top right corner.

			In order to save space, identical slices adjacent to each other are stored only once. The bottommost scanline of
			an identical sequence of scanlines serves as a representant for the whole sequence; all others are eliminated.
			This means that if no points exist for a certain y_coordinate, the spans of the corresponding scanline are identical
			to those of the one below it. As a consequence, scanlines that are completely outside the region need an empty
			filler span to distinguish them from eliminated scanlines. A filler span consists of two points located at UBound,
			one entering the region and the other leaving it.

			Most operations modifying regions append new points in ascending order to the sequence of existing points and
			then merge the two sequences again. If points cannot be appended in order, the whole set of points has to be
			sorted before any other operation can be executed. Doing this immediately after the sequence of points has been
			invalidated can decrease performance significantly if a lot of invalidating operations are issued in sequence, as is
			typically the case with AddPoint. This is why regions have a valid flag, indicating whether encoded points are sorted
			or not. Invalidating operations only have to set valid to FALSE, other operations will eventually validate the region
			again, at the same time eliminating multiple points and overlapping spans.
		*)
		
		
		Region* = OBJECT
		VAR
			llx*, lly*, urx*, ury*: INTEGER;	(** bounding box **)
			mode*: INTEGER;	(** mode for reducing region to non_overlapping areas (Winding/EvenOdd) **)
			valid: BOOLEAN;	(* flag if points in data array are consistent (i.e. sorted & compacted) *)
			data: RegionData;	(* points defining region boundary *)
			points: LONGINT;	(* number of data points actually used *)

			
	(**--- Region Construction ---**)

			(** make region empty **)
			PROCEDURE Clear* ();
			BEGIN
				SELF.llx := UBound; SELF.lly := UBound;
				SELF.urx := LBound; SELF.ury := LBound;
				SELF.valid := TRUE;
				SELF.points := 0
			END Clear;

			(** set region mode **)
			PROCEDURE SetMode* (mode: INTEGER);
			BEGIN
				SELF.mode := mode
			END SetMode;

			(** initialize region **)
			PROCEDURE Init* (mode: INTEGER);
			BEGIN
				SELF.mode := mode;
				(* SELF.data := NIL; *)
				SELF.Clear()
			END Init;

			(** make region rectangular **)
			PROCEDURE SetToRect* (llx, lly, urx, ury: INTEGER);
			BEGIN
				IF RectEmpty(llx, lly, urx, ury) THEN
					SELF.Clear()
				ELSE
					ClipRect(llx, lly, urx, ury, LBound, LBound, UBound, UBound);
					SELF.llx := llx; SELF.lly := lly; SELF.urx := urx; SELF.ury := ury;
					SELF.valid := TRUE;
					SELF.points := 0
				END
			END SetToRect;

			(** shift region **)
			PROCEDURE Shift* (dx, dy: INTEGER);
				VAR rdata: RegionData; rn: LONGINT; ru, rv, rdir: INTEGER;
			BEGIN
				IF (dx # 0) OR (dy # 0) THEN
					INC(SELF.llx, dx); INC(SELF.lly, dy); INC(SELF.urx, dx); INC(SELF.ury, dy);
					IF SELF.points > 0 THEN
						rdata := SELF.data; rn := FirstSlice;
						Decode(rdata[rn], ru, rv, rdir);
						WHILE rv < Top DO
							IF (ru <= LBound) OR (ru + dx <= LBound) THEN ru := LBound
							ELSIF (ru >= UBound) OR (ru + dx >= UBound) THEN ru := UBound
							ELSE INC(ru, dx)
							END;
							IF (dy < 0) & (rv < Bottom - dy) THEN rv := Bottom
							ELSIF (dy > 0) & (rv > Top - dy) THEN rv := Top
							ELSE INC(rv, dy)
							END;
							Encode(rdata[rn], ru, rv, rdir);
							INC(rn);
							Decode(rdata[rn], ru, rv, rdir)
						END
					END
				END
			END Shift;

			(** copy region **)
			PROCEDURE Copy* (to: Region);
			BEGIN
				to.mode := SELF.mode;
				SELF.CopyData(to)
			END Copy;

			(** add second region to first **)
			PROCEDURE Add* (arg: Region);
				VAR rdata, adata: RegionData; points, aslice, an, rn, rslice: LONGINT; au, av, adir, ru, rv, rdir, top, ry, ay, y: INTEGER;
			BEGIN
				IF ~RectEmpty(arg.llx, arg.lly, arg.urx, arg.ury) THEN
					IF RectEmpty(SELF.llx, SELF.lly, SELF.urx, SELF.ury) THEN
						arg.CopyData(SELF)
					ELSIF arg.IsRect() & SELF.RectInside(arg.llx, arg.lly, arg.urx, arg.ury) THEN
						(* do nothing *)
					ELSIF SELF.IsRect() & arg.RectInside(SELF.llx, SELF.lly, SELF.urx, SELF.ury) THEN
						arg.CopyData(SELF)
					ELSE
						SELF.Validate(); arg.Validate();
						SELF.MakeData(); arg.MakeData();
						rdata := SELF.data; adata := arg.data;
						points := SELF.points;

						IF arg.lly < SELF.lly THEN
							(* copy scanlines below SELF *)
							arg.FindUpper(SELF.lly, aslice);
							an := FirstSlice;
							WHILE an < aslice DO
								Decode(adata[an], au, av, adir);
								SELF.Append(au, av, adir);
								INC(an)
							END;
							rn := FirstSlice;
							arg.FindLower(SELF.lly, an)
						ELSE
							SELF.FindLower(arg.lly, rn);
							an := FirstSlice
						END;

						Decode(rdata[rn], ru, rv, rdir);
						Decode(adata[an], au, av, adir);
						rslice := rn; aslice := an;
						top := MIN(SELF.ury, arg.ury);

						WHILE (av < top) OR (rv < top) DO
							(* merge slices *)
							ry := rv; ay := av; y := MAX(ry, ay);
							REPEAT
								IF (av > ay) OR (rv = ry) & (ru <= au) THEN
									IF rv # y THEN	(* do not duplicate points *)
										SELF.Append(ru, y, rdir)
									END;
									INC(rn);
									Decode(rdata[rn], ru, rv, rdir)
								ELSE
									SELF.Append(au, y, adir);
									INC(an);
									Decode(adata[an], au, av, adir)
								END
							UNTIL (rv > ry) & (av > ay);

							(* advance to next slice *)
							IF rv < av THEN
								an := aslice; rslice := rn;
								Decode(adata[an], au, av, adir)
							ELSIF av < rv THEN
								rn := rslice; aslice := an;
								Decode(rdata[rn], ru, rv, rdir)
							ELSE
								rslice := rn; aslice := an
							END
						END;

						(* copy slices above SELF *)
						IF arg.ury > SELF.ury THEN
							REPEAT
								SELF.Append(au, av, adir);
								INC(an);
								Decode(adata[an], au, av, adir)
							UNTIL av = Top
						END;

						SELF.Merge(points);
						IncludeRect(SELF.llx, SELF.lly, SELF.urx, SELF.ury, arg.llx, arg.lly, arg.urx, arg.ury)
					END
				END
			END Add;

			(** add rectangle to region **)
			PROCEDURE AddRect* (llx, lly, urx, ury: INTEGER);
				VAR reg: Region;
			BEGIN{EXCLUSIVE}
				reg.SetToRect(llx, lly, urx, ury);
				SELF.Add(reg)
			END AddRect;

			(** subtract second region from first **)
			PROCEDURE Subtract* (arg: Region);
				VAR rdata, adata: RegionData; points, rn, an, rslice, aslice: LONGINT; ru, rv, rdir, au, av, adir, top, ry, ay, y: INTEGER;
			BEGIN
				IF ~RectEmpty(arg.llx, arg.lly, arg.urx, arg.ury) THEN
					IF RectEmpty(SELF.llx, SELF.lly, SELF.urx, SELF.ury) OR SELF.RegionInside(arg) THEN
						SELF.Clear()
					ELSIF RectsIntersect(SELF.llx, SELF.lly, SELF.urx, SELF.ury, arg.llx, arg.lly, arg.urx, arg.ury) THEN
						SELF.Validate(); arg.Validate();
						SELF.MakeData(); arg.MakeData();
						rdata := SELF.data; adata := arg.data;
						points := SELF.points;
						IF SELF.lly <= arg.lly THEN
							SELF.FindLower(arg.lly, rn);
							an := FirstSlice
						ELSE
							rn := FirstSlice;
							arg.FindLower(SELF.lly, an)
						END;
						Decode(rdata[rn], ru, rv, rdir);
						Decode(adata[an], au, av, adir);

						rslice := rn; aslice := an;
						top := MIN(SELF.ury, arg.ury);
						WHILE (rv < top) OR (av < top) DO
							(* merge slices *)
							ry := rv; ay := av; y := MAX(ry, ay);
							REPEAT
								IF (av > ay) OR (rv = ry) & (ru <= au) THEN
									IF rv # y THEN	(* do not duplicate points *)
										SELF.Append(ru, y, rdir)
									END;
									INC(rn);
									Decode(rdata[rn], ru, rv, rdir)
								ELSE
									SELF.Append(au, y, -adir);
									INC(an);
									Decode(adata[an], au, av, adir)
								END
							UNTIL (rv > ry) & (av > ay);

							(* advance to next slice *)
							IF rv < av THEN
								an := aslice; rslice := rn;
								Decode(adata[an], au, av, adir)
							ELSIF av < rv THEN
								rn := rslice; aslice := an;
								Decode(rdata[rn], ru, rv, rdir)
							ELSE
								rslice := rn; aslice := an
							END
						END;

						SELF.Merge(points);
						SELF.CalcRect()
					END
				END
			END Subtract;

			(** subtract rectangle from region **)
			PROCEDURE SubtractRect* (llx, lly, urx, ury: INTEGER);
				VAR reg: Region;
			BEGIN{EXCLUSIVE}
				reg.SetToRect(llx, lly, urx, ury);
				SELF.Subtract(reg)
			END SubtractRect;

		(** intersect first region with second region **)
		PROCEDURE Intersect* (arg: Region);
			VAR rdata, adata: RegionData; points, rn, an, rslice, aslice: LONGINT; ru, rv, rdir, au, av, adir, ry, ay, y: INTEGER;
		BEGIN
			IF ~RectsIntersect(SELF.llx, SELF.lly, SELF.urx, SELF.ury, arg.llx, arg.lly, arg.urx, arg.ury) THEN
				SELF.Clear()

			ELSIF ~arg.RectInside(SELF.llx, SELF.lly, SELF.urx, SELF.ury) THEN
				SELF.Validate(); arg.Validate();
				SELF.MakeData(); arg.MakeData();
				rdata := SELF.data; adata := arg.data;
				points := SELF.points;

				(* cut off slices above arg *)
				IF SELF.ury > arg.ury THEN
					SELF.FindUpper(arg.ury, points);
					Encode(rdata[points], UBound, arg.ury, Enter); INC(points);
					Encode(rdata[points], UBound, arg.ury, Exit); INC(points);
					Encode(rdata[points], UBound, Top, Exit); INC(points);
					SELF.points := points
				END;

				(* delete slices below arg *)
				IF SELF.lly < arg.lly THEN
					SELF.FindLower(arg.lly, rn);
					IF rn > FirstSlice THEN
						points := FirstSlice;
						WHILE rn < SELF.points DO
							rdata[points] := rdata[rn];
							INC(points); INC(rn)
						END;
						SELF.points := points
					END;

					rn := FirstSlice;
					Decode(rdata[rn], ru, rv, rdir);
					ry := rv;
					REPEAT
						Encode(rdata[rn], ru, arg.lly, rdir);
						INC(rn);
						Decode(rdata[rn], ru, rv, rdir)
					UNTIL rv > ry;

					rn := FirstSlice; an := FirstSlice
				ELSE
					rn := FirstSlice;
					arg.FindLower(SELF.lly, an)
				END;

				Decode(rdata[rn], ru, rv, rdir);
				Decode(adata[an], au, av, adir);
				rslice := rn; aslice := an;

				WHILE rv < SELF.ury DO
					(* merge intersecting slices *)
					ry := rv; ay := av; y := MAX(ry, ay);
					SELF.Append(LBound, y, Exit);
					REPEAT
						IF (av > ay) OR (rv = ry) & (ru <= au) THEN
							IF rv # y THEN	(* do not duplicate existing points *)
								SELF.Append(ru, y, rdir)
							END;
							INC(rn);
							Decode(rdata[rn], ru, rv, rdir)
						ELSE
							SELF.Append(au, y, adir);
							INC(an);
							Decode(adata[an], au, av, adir)
						END
					UNTIL (rv > ry) & (av > ay);
					SELF.Append(UBound, y, Enter);

					(* advance to next slice *)
					IF rv < av THEN
						an := aslice; rslice := rn;
						Decode(adata[an], au, av, adir)
					ELSIF av < rv THEN
						rn := rslice; aslice := an;
						Decode(rdata[rn], ru, rv, rdir)
					ELSE
						rslice := rn; aslice := an
					END
				END;

				SELF.Merge(points);
				SELF.CalcRect()
			END
		END Intersect;

			(** intersect region with rectangle **)
			PROCEDURE IntersectRect* (llx, lly, urx, ury: INTEGER);
				VAR reg: Region;
			BEGIN{EXCLUSIVE}
				reg.SetToRect(llx, lly, urx, ury);
				SELF.Intersect(reg)
			END IntersectRect;

			(** invert region **)
			PROCEDURE Invert* ();
				VAR data: RegionData; points, n: LONGINT; u, v, dir, y: INTEGER;
			BEGIN
				IF RectEmpty(SELF.llx, SELF.lly, SELF.urx, SELF.ury) THEN
					SELF.SetToRect(LBound, LBound, UBound, UBound)
				ELSE
					SELF.Validate();
					SELF.MakeData();
					data := SELF.data;
					points := SELF.points;
					n := FirstSlice;
					Decode(data[n], u, v, dir);

					IF SELF.lly > LBound THEN
						SELF.Append(LBound, LBound, Enter);
						SELF.Append(UBound, LBound, Exit)
					END;

					REPEAT
						y := v;
						SELF.Append(LBound, y, Enter);
						REPEAT
							Encode(data[n], u, y, -dir);
							INC(n);
							Decode(data[n], u, y, dir)
						UNTIL v > y;
						SELF.Append(UBound, y, Exit)
					UNTIL v >= UBound;

					IF y < UBound THEN
						SELF.Append(LBound, y, Enter);
						SELF.Append(UBound, y, Exit)
					END;

					SELF.Merge(points);
					SELF.CalcRect()
				END
			END Invert;

			(**
				In addition to creating rectangular regions and using Boolean operations to combine several regions, a region
				can also be built by tracing its outline with AddPoint. In order to allow the correct handling of self_intersecting
				contours, a direction parameter is needed which indicates whether the curve is going up (dy = 1) or down
				(dy = -1) at the given point.

				When performing Boolean operations upon regions or when building regions from self_intersecting contours,
				it is possible that some areas in the resulting region get "covered" more than once. Since most query operations
				reduce regions to non_overlapping areas, a rule which decides whether a point is inside a region or not is needed.
				Imagine a ray originating at such a point and counting every intersection of the ray with the boundary curve of the
				region as +1 if the curve crosses the ray from right to left and as -1 otherwise.
					- for mode Winding (the default), a point is inside the region if the resulting sum is non_zero
					- for mode EvenOdd, a point is inside the region if the resulting sum is odd

				Behaviour of all region queries and region operations is undefined for contours which are not closed.
			**)

			(** add a scanline intersection to a region **)
			PROCEDURE AddPoint* (x, y, dy: INTEGER);
			BEGIN
				IF (dy # 0) & (y >= LBound) & (y <= UBound) THEN
					IF x < LBound THEN x := LBound
					ELSIF x > UBound THEN x := UBound
					END;
					SELF.MakeData();
					IncludePoint(SELF.llx, SELF.lly, SELF.urx, SELF.ury, x, y);
					SELF.Append(x, y + (-dy) DIV 2, dy);	(* dy = -1 => y, dy = 1 => y - 1 *)
					SELF.valid := FALSE
				END
			END AddPoint;
			
		(**--- Region Queries ---**)

			(** return whether region is empty **)
			PROCEDURE Empty* (): BOOLEAN;
			BEGIN
				RETURN (SELF.llx >= SELF.urx) OR (SELF.lly >= SELF.ury)
			END Empty;

			(** return whether (non_empty) region is rectangular **)
			PROCEDURE IsRect* (): BOOLEAN;
			BEGIN
				SELF.Validate();
				RETURN SELF.points = 0
			END IsRect;

			(** return whether point is inside (non_empty) region **)
			PROCEDURE PointInside* (x, y: INTEGER): BOOLEAN;
				VAR data: RegionData; n: LONGINT; u, v, dir: INTEGER;
			BEGIN
				IF ~PointInRect(x, y, SELF.llx, SELF.lly, SELF.urx, SELF.ury) THEN	(* point not even within region rectangle *)
					RETURN FALSE
				ELSIF SELF.IsRect() THEN	(* region is rectangular *)
					RETURN TRUE
				END;

				(* find span containing point *)
				data := SELF.data;
				SELF.FindLower(y, n);
				Decode(data[n], u, v, dir);
				WHILE u < x DO
					INC(n);
					Decode(data[n], u, v, dir)
				END;
				RETURN (u = x) & (dir = Enter) OR (u > x) & (dir = Exit)
			END PointInside;

			(** return whether (non_empty) rectangle is completely inside (non_empty) region **)
			PROCEDURE RectInside* (llx, lly, urx, ury: INTEGER): BOOLEAN;
				VAR data: RegionData; n: LONGINT; u, v, dir, y: INTEGER;
			BEGIN
				IF ~RectInRect(llx, lly, urx, ury, SELF.llx, SELF.lly, SELF.urx, SELF.ury) THEN	(* not even within bounding rectangle *)
					RETURN FALSE
				ELSIF SELF.IsRect() THEN	(* region is rectangular *)
					RETURN TRUE
				END;

				data := SELF.data;
				SELF.FindLower(lly, n);
				Decode(data[n], u, v, dir);
				REPEAT
					y := v;
					WHILE (v = y) & (u <= llx) DO
						INC(n);
						Decode(data[n], u, v, dir)
					END;
					IF (v > y) OR (u < urx) OR (dir = Enter) THEN	(* rectangle not covered by span *)
						RETURN FALSE
					END;

					(* skip to next line *)
					WHILE v = y DO
						INC(n);
						Decode(data[n], u, v, dir)
					END
				UNTIL v >= ury;

				RETURN TRUE	(* rectangle is fully covered by spans *)
			END RectInside;

			(** return whether (non_empty) rectangle overlaps (non_empty) region **)
			PROCEDURE RectOverlaps* (llx, lly, urx, ury: INTEGER): BOOLEAN;
				VAR data: RegionData; n: LONGINT; u, v, dir, y: INTEGER;
			BEGIN
				IF ~RectsIntersect(llx, lly, urx, ury, SELF.llx, SELF.lly, SELF.urx, SELF.ury) THEN
					RETURN FALSE	(* rect does not even intersect region rectangle *)
				ELSIF SELF.IsRect() THEN	(* region is rectangular *)
					RETURN TRUE
				END;

				ClipRect(llx, lly, urx, ury, SELF.llx, SELF.lly, SELF.urx, SELF.ury);
				data := SELF.data;
				SELF.FindLower(lly, n);
				Decode(data[n], u, v, dir);
				REPEAT
					y := v;
					WHILE (v = y) & (u <= llx) DO
						INC(n);
						Decode(data[n], u, v, dir)
					END;
					IF (v = y) & ((u < urx) OR (dir = Exit)) THEN
						RETURN TRUE
					END;

					(* skip to next line *)
					WHILE v = y DO
						INC(n);
						Decode(data[n], u, v, dir)
					END
				UNTIL v >= ury;

				RETURN FALSE	(* rectangle does not intersect any span *)
			END RectOverlaps;

			(** return whether region is completely within another region **)
			PROCEDURE RegionInside* (outer: Region): BOOLEAN;
				VAR idata, odata: RegionData; in, on, is, os: LONGINT; iu, iv, idir, ou, ov, odir, iy, oy: INTEGER;
			BEGIN
				IF ~RectInRect(SELF.llx, SELF.lly, SELF.urx, SELF.ury, outer.llx, outer.lly, outer.urx, outer.ury) THEN
					RETURN FALSE	(* SELF rect not even within outer rect *)
				ELSIF outer.IsRect() THEN
					RETURN TRUE	(* outer region fully covers SELF region *)
				ELSIF SELF.IsRect() THEN
					RETURN outer.RectInside(SELF.llx, SELF.lly, SELF.urx, SELF.ury)
				END;

				idata := SELF.data; odata := outer.data;
				in := FirstSlice;
				outer.FindLower(SELF.lly, on);
				Decode(idata[in], iu, iv, idir);
				Decode(odata[on], ou, ov, odir);
				is := in; os := on;
				REPEAT
					iy := iv; oy := ov;

					(* skip empty slices *)
					WHILE (iv = iy) & (iu = UBound) DO
						INC(in);
						Decode(idata[in], iu, iv, idir)
					END;

					(* compare slices *)
					WHILE (iv = iy) OR (ov = oy) DO
						IF (ov > oy) OR (iv = iy) & (idir = Exit) & (odir = Enter) THEN
							RETURN FALSE
						END;
						IF (iv > iy) OR (ou <= iu) THEN
							INC(on);
							Decode(odata[on], ou, ov, odir)
						ELSE
							INC(in);
							Decode(idata[in], iu, iv, idir)
						END
					END;

					(* reset to begin of slice if not on same line *)
					IF iv > ov THEN
						in := is; os := on;
						Decode(idata[in], iu, iv, idir)
					ELSIF ov > iv THEN
						on := os; is := in;
						Decode(odata[on], ou, ov, odir)
					ELSE
						is := in; os := on
					END
				UNTIL iv = SELF.ury;

				RETURN TRUE	(* all spans were covered by enclosing region *)
			END RegionInside;

			(** return whether two regions intersect each other **)
			PROCEDURE RegionOverlaps* (arg: Region): BOOLEAN;
				VAR rdata, adata: RegionData; bot, top, ru, rv, rdir, au, av, adir, ry, ay: INTEGER; rn, an, rs, as: LONGINT;
			BEGIN
				IF ~RectsIntersect(SELF.llx, SELF.lly, SELF.urx, SELF.ury, arg.llx, arg.lly, arg.urx, arg.ury) THEN
					RETURN FALSE	(* rect does not even intersect arg's bounding box *)
				ELSIF SELF.IsRect() THEN
					RETURN arg.RectOverlaps(SELF.llx, SELF.lly, SELF.urx, SELF.ury)
				ELSIF arg.IsRect() THEN
					RETURN SELF.RectOverlaps(arg.llx, arg.lly, arg.urx, arg.ury)
				END;

				rdata := SELF.data; adata := arg.data;
				bot := MAX(SELF.lly, arg.lly);
				top := MIN(SELF.ury, arg.ury);
				SELF.FindLower(bot, rn);
				arg.FindLower(bot, an);
				Decode(rdata[rn], ru, rv, rdir);
				Decode(adata[an], au, av, adir);
				rs := rn; as := an;
				REPEAT
					ry := rv; ay := av;

					(* compare slices *)
					WHILE (rv = ry) OR (av = ay) DO
						IF (rv = ry) & (av = ay) & (rdir = Exit) & (adir = Exit) THEN
							RETURN TRUE
						END;
						IF (av > ay) OR (rv = ry) & (ru <= au) THEN
							INC(rn);
							Decode(rdata[rn], ru, rv, rdir)
						ELSE
							INC(an);
							Decode(adata[an], au, av, adir)
						END
					END;

					(* reset to begin of line if not on same line *)
					IF rv > av THEN
						rn := rs; as := an;
						Decode(rdata[rn], ru, rv, rdir)
					ELSIF av > rv THEN
						an := as; rs := rn;
						Decode(adata[an], au, av, adir)
					ELSE
						rs := rn; as := an
					END
				UNTIL (rv = top) OR (av = top);

				RETURN FALSE	(* no pair of spans intersected *)
			END RegionOverlaps;

			(** enumerate region within rectangle **)
			PROCEDURE Enumerate* (llx, lly, urx, ury: INTEGER; enum: Enumerator; VAR edata: EnumData);
			BEGIN
				IF RectsIntersect(SELF.llx, SELF.lly, SELF.urx, SELF.ury, llx, lly, urx, ury) THEN
					ClipRect(llx, lly, urx, ury, SELF.llx, SELF.lly, SELF.urx, SELF.ury);
					IF ~RectEmpty(llx, lly, urx, ury) THEN
						IF SELF.IsRect() THEN
							enum(llx, lly, urx, ury, edata)
						ELSE
							SELF.Enum(llx, lly, urx, ury, enum, edata, Enter)
						END
					END
				END
			END Enumerate;

			(** enumerate parts of rectangle not within region **)
			PROCEDURE EnumerateInv* (llx, lly, urx, ury: INTEGER; enum: Enumerator; VAR edata: EnumData);
			BEGIN
				IF RectsIntersect(SELF.llx, SELF.lly, SELF.urx, SELF.ury, llx, lly, urx, ury) THEN
					IF SELF.IsRect() & RectInRect(SELF.llx, SELF.lly, SELF.urx, SELF.ury, llx, lly, urx, ury) THEN
						IF lly < SELF.lly THEN enum(llx, lly, urx, SELF.lly, edata) END;
						IF llx < SELF.llx THEN enum(llx, SELF.lly, SELF.llx, SELF.ury, edata) END;
						IF urx > SELF.urx THEN enum(SELF.urx, SELF.lly, urx, SELF.ury, edata) END;
						IF ury > SELF.ury THEN enum(llx, SELF.ury, urx, ury, edata) END
					ELSE
						SELF.Enum(llx, lly, urx, ury, enum, edata, Exit)
					END
				ELSE
					enum(llx, lly, urx, ury, edata)
				END
			END EnumerateInv;
	
		(*--- Auxiliary Routines For Managing Regions ---*)			

			(* append point to region data *)
			PROCEDURE Append (u, v, dir: INTEGER);
				VAR size: LONGINT; data: RegionData;
			BEGIN
				IF SELF.data = NIL THEN
					NEW(SELF.data, BlockSize)
				ELSIF SELF.points >= LEN(SELF.data^) THEN	(* grow data array *)
					size := LEN(SELF.data^) + BlockSize;
					NEW(data, size);
					CopyPoints(SELF.data, data, SELF.points);
					SELF.data := data
				END;
				Encode(SELF.data[SELF.points], u, v, dir);
				INC(SELF.points)
			END Append;

			(* copy region data *)
			PROCEDURE CopyData (dst: Region);
				VAR size: LONGINT;
			BEGIN
				IF SELF.points > 0 THEN
					IF (dst.data = NIL) OR (LEN(dst.data^) < SELF.points) THEN
						size := SELF.points + (-SELF.points) MOD BlockSize;	(* round up to multiple of BlockSize *)
						NEW(dst.data, size)
					END;
					CopyPoints(SELF.data, dst.data, SELF.points)
				END;
				dst.points := SELF.points;
				dst.llx := SELF.llx; dst.lly := SELF.lly;
				dst.urx := SELF.urx; dst.ury := SELF.ury;
				dst.valid := SELF.valid
			END CopyData;

			(* re_calculate bounding box of (valid!) region *)
			PROCEDURE CalcRect ();
				VAR data: RegionData; n: LONGINT; u, v, dir, x: INTEGER;
			BEGIN
				ASSERT(SELF.valid);
				IF SELF.points > 0 THEN
					data := SELF.data;
					n := FirstSlice;
					Decode(data[n], u, v, dir);
					SELF.llx := u; SELF.urx := u; SELF.lly := v;
					REPEAT
						SELF.ury := v; x := u;
						REPEAT
							IF (dir = Enter) & (u < SELF.llx) THEN
								SELF.llx := u; x := u
							ELSIF (dir = Exit) & (u > SELF.urx) & (u > x) THEN	(* last term excludes filler spans *)
								SELF.urx := u
							END;
							INC(n);
							Decode(data[n], u, v, dir)
						UNTIL v > SELF.ury;
					UNTIL v = Top
				END
			END CalcRect;

			(* eliminate duplicate slices *)
			PROCEDURE Compact (src: RegionData);
				VAR rslice, dslice, sn, rn, dn: LONGINT; dst: RegionData; su, sv, sdir, ru, rv, rdir, sy, ry: INTEGER;
			BEGIN
				rslice := 0;	(* start of current reference slice is the bottom sentinel slice *)
				dslice := FirstSlice;	(* start of current destination slice *)
				sn := FirstSlice;	(* current reading position *)
				dst := SELF.data;
				Decode(src[sn], su, sv, sdir);

				REPEAT
					(* compare next source slice to current reference slice *)
					rn := rslice; dn := dslice;
					Decode(dst[rn], ru, rv, rdir);
					sy := sv; ry := rv;
					WHILE (sv = sy) & (rv = ry) & (su = ru) & (sdir = rdir) DO	(* copy while slices are equal *)
						dst[dn] := src[sn];
						INC(dn); INC(sn); INC(rn);
						Decode(src[sn], su, sv, sdir);
						Decode(dst[rn], ru, rv, rdir)
					END;

					IF (sv = sy) OR (rv = ry) THEN	(* slices are different => copy rest of source slice to destination *)
						WHILE sv = sy DO
							dst[dn] := src[sn];
							INC(dn); INC(sn);
							Decode(src[sn], su, sv, sdir)
						END;

						(* the slice just written becomes the new reference slice *)
						rslice := dslice;
						dslice := dn
					END
				UNTIL sv = Top;

				IF dn = 6 THEN	(* region contains only one rectangle *)
					Decode(dst[FirstSlice], SELF.llx, SELF.lly, rdir);
					Decode(dst[FirstSlice + 1], SELF.urx, SELF.lly, rdir);
					Decode(dst[FirstSlice + 2], ru, SELF.ury, rdir);
					SELF.points := 0
				ELSE
					Encode(dst[dn], UBound, Top, Exit);
					SELF.points := dn + 1
				END
			END Compact;

			(* merge two runs of data points *)
			PROCEDURE Merge (split: LONGINT);
				VAR data: RegionData; n, N, m, M, p, tmp: LONGINT; nu, nv, ndir, mu, mv, mdir, sum, u, v, inc, nsum: INTEGER;
					Data: RegionData;	(* temporary region data for merging *)
					DataSize: LONGINT;	(* number of points allocated for Data *)				
			BEGIN{EXCLUSIVE}
				data := SELF.data;
				n := 0; N := split;
				Decode(data[n], nu, nv, ndir);
				m := split; M := SELF.points;
				Decode(data[m], mu, mv, mdir);
				p := 0;
				SELF.Append(UBound, Top, Exit);	(* sentinel for upper part *)

				IF DataSize <= M THEN	(* reallocate temporary buffer *)
					DataSize := M - M MOD BlockSize + BlockSize;
					NEW(Data, DataSize)
				END;

				WHILE (n < N) & (m < M) DO
					tmp := p;
					v := MIN(nv, mv);

					(* eliminate overlapping spans before copying them *)
					sum := 0;
					REPEAT
						(* get next point *)
						IF (nv < mv) OR (nv = mv) & (nu <= mu) THEN
							u := nu; inc := ndir;
							INC(n);
							Decode(data[n], nu, nv, ndir)
						ELSE
							u := mu; inc := mdir;
							INC(m);
							Decode(data[m], mu, mv, mdir)
						END;

						(* accumulate directions of coincident points *)
						WHILE (nv = v) & (nu = u) DO
							INC(inc, ndir); INC(n);
							Decode(data[n], nu, nv, ndir)
						END;
						WHILE (mv = v) & (mu = u) DO
							INC(inc, mdir); INC(m);
							Decode(data[m], mu, mv, mdir)
						END;

						IF inc # 0 THEN	(* append point to merged data *)
							nsum := sum + inc;
							IF SELF.mode = Winding THEN
								IF (sum <= 0) & (nsum > 0) THEN
									Encode(Data[p], u, v, Enter); INC(p)
								ELSIF (sum > 0) & (nsum <= 0) THEN
									Encode(Data[p], u, v, Exit); INC(p)
								END
							ELSIF (SELF.mode = EvenOdd) & ((sum > 0) & ODD(sum) # (nsum > 0) & ODD(nsum)) THEN
								IF ODD(sum) THEN
									Encode(Data[p], u, v, Exit)
								ELSE
									Encode(Data[p], u, v, Enter)
								END;
								INC(p)
							END;
							sum := nsum
						END
					UNTIL (nv > v) & (mv > v);

					IF p = tmp THEN	(* line is empty => append filler slice *)
						Encode(Data[p], UBound, v, Enter); INC(p);
						Encode(Data[p], UBound, v, Exit); INC(p)
					END
				END;

				(* copy remaining points *)
				WHILE n < N DO
					Data[p] := data[n];
					INC(p); INC(n)
				END;
				WHILE m < M DO
					Data[p] := data[m];
					INC(p); INC(m)
				END;

				(* copy merged data back and eliminate duplicate scanlines *)
				SELF.Compact(Data)
			END Merge;

			(* bring region data into consistent state *)
			PROCEDURE Validate ();
				VAR data: RegionData; points, rn, wn, tmp: LONGINT; u, v, dir, y, sum, x, inc: INTEGER;
			BEGIN
				IF ~SELF.valid THEN
					data := SELF.data;
					SafeQuickSort(data^,0,SELF.points-1);
					points := SELF.points;
					rn := FirstSlice; wn := FirstSlice;	(* read and write position *)
					Decode(data[rn], u, v, dir);

					REPEAT
						tmp := wn;
						y := v;
						sum := 0;
						REPEAT
							(* accumulate directions of coincident points *)
							x := u; inc := 0;
							REPEAT
								INC(inc, dir); INC(rn);
								Decode(data[rn], u, v, dir)
							UNTIL (v > y) OR (u > x);

							IF x < UBound THEN
								IF SELF.mode = Winding THEN
									IF sum = 0 THEN
										Encode(data[wn], x, y, Enter); INC(wn);
										INC(x)	(* prevent dropouts *)
									END;
									INC(sum, inc);
									IF sum = 0 THEN
										Encode(data[wn], x, y, Exit); INC(wn)
									END
								ELSIF SELF.mode = EvenOdd THEN
									IF ~ODD(sum) THEN
										Encode(data[wn], x, y, Enter); INC(wn);
										INC(x)	(* prevent dropouts *)
									END;
									INC(sum, inc);
									IF ~ODD(sum) THEN
										Encode(data[wn], x, y, Exit); INC(wn)
									END
								END
							END
						UNTIL v > y;

						IF wn = tmp THEN	(* insert filler span if all slices have been eliminated *)
							Encode(data[wn], UBound, y, Enter); INC(wn);
							Encode(data[wn], UBound, y, Exit); INC(wn)
						ELSIF v > y + 1 THEN	(* add filler slice for disconnected regions *)
							INC(y);
							SELF.Append(UBound, y, Enter);
							SELF.Append(UBound, y, Exit)
						END
					UNTIL v = Top;

					Encode(data[wn], UBound, Top, Exit); INC(wn);
					IF SELF.points > points THEN	(* added filler slices => must merge *)
						IF wn < points THEN	(* some points have been discarded => move filler slices *)
							rn := points; points := wn;
							REPEAT
								IF (wn < LEN(data)) & (rn < LEN(SELF.data)) THEN
									data[wn] := SELF.data[rn];	(* data may have been reallocated! *)
								END;
								INC(wn); INC(rn)
							UNTIL rn = SELF.points;
							SELF.data := data;
							SELF.points := wn
						END;
						SELF.Merge(points)
					ELSE	(* points are still sorted *)
						SELF.points := wn;
						SELF.Compact(SELF.data)
					END;
					SELF.valid := TRUE
				END
			END Validate;

			(* find first point on line y or higher *)
			PROCEDURE FindUpper (y: INTEGER; VAR n: LONGINT);
				VAR item, i, j, m: LONGINT;
			BEGIN
				item := ASH(LONG(y), 16);	(* leftmost possible point on line y *)
				i := 0; j := SELF.points;
				WHILE i + 1 < j DO
					m := (i + j) DIV 2;
					IF SELF.data[m] < item THEN
						i := m
					ELSE
						j := m
					END
				END;
				n := j
			END FindUpper;

			(* find first point on line y or lower *)
			PROCEDURE FindLower (y: INTEGER; VAR n: LONGINT);
				VAR v: INTEGER;
			BEGIN
				SELF.FindUpper(y, n);
				v := INTEGER(ASH(SELF.data[n], -16));
				IF v > y THEN	(* => find leftmost point on lower slice *)
					DEC(n);
					y := INTEGER(ASH(SELF.data[n], -16));
					REPEAT
						DEC(n)
					UNTIL (n < 0) OR (ASH(SELF.data[n], -16) < y);
					INC(n)
				END
			END FindLower;

			(* enumerate (inverted) region within rectangle *)
			PROCEDURE Enum (llx, lly, urx, ury: INTEGER; enum: Enumerator; VAR edata: EnumData; enter: INTEGER);
				VAR data: RegionData; n, lo, hi: LONGINT; u, v, dir, y, top, x: INTEGER;
			BEGIN
				SELF.Validate();
				ClipRect(llx, lly, urx, ury, LBound, LBound, UBound, UBound);
				data := SELF.data;
				SELF.FindLower(lly, n);
				Decode(data[n], u, v, dir);
				y := lly;

				REPEAT
					(* calculate height of slice *)
					lo := n;
					REPEAT
						INC(n);
						IF u < llx THEN
							lo := n
						END;
						Decode(data[n], u, v, dir)
					UNTIL v > y;
					hi := n;
					top := MIN(v, ury);

					(* enumerate spans of current slice *)
					n := lo;
					Decode(data[n], u, v, dir);
					x := llx;
					WHILE (v <= y) & ((u < urx) OR (dir # enter)) DO
						IF u > x THEN
							IF dir = enter THEN
								x := u
							ELSE
								enum(x, y, MIN(u, urx), top, edata)
							END
						END;
						INC(n);
						Decode(data[n], u, v, dir)
					END;

					IF n < hi THEN
						n := hi;
						Decode(data[n], u, v, dir)
					END;
					y := v
				UNTIL v >= ury
			END Enum;

			(* create data points for rectangular region *)
			PROCEDURE MakeData ();
			BEGIN
				IF SELF.points = 0 THEN
					SELF.Append(UBound, Bottom, Enter);
					SELF.Append(UBound, Bottom, Exit);
					IF (SELF.llx <= SELF.urx) & (SELF.lly <= SELF.ury) THEN
						SELF.Append(SELF.llx, SELF.lly, Enter);
						SELF.Append(SELF.urx, SELF.lly, Exit);
						SELF.Append(UBound, SELF.ury, Enter);
						SELF.Append(UBound, SELF.ury, Exit)
					END;
					SELF.Append(UBound, Top, Enter)
				END
			END MakeData;

		END Region;

		(** region enumeration **)
		EnumData* = RECORD END;
		Enumerator* = PROCEDURE (llx, lly, urx, ury: INTEGER; VAR edata: EnumData);

	(**--- Rectangles ---**)

	(** make rectangle large enough to include a point **)
	PROCEDURE IncludePoint* (VAR llx, lly, urx, ury: INTEGER; x, y: INTEGER);
	BEGIN
		IF x < llx THEN llx := x END;
		IF x > urx THEN urx := x END;
		IF y < lly THEN lly := y END;
		IF y > ury THEN ury := y END
	END IncludePoint;

	(** make rectangle large enough to include other rectangle **)
	PROCEDURE IncludeRect* (VAR llx, lly, urx, ury: INTEGER; illx, illy, iurx, iury: INTEGER);
	BEGIN
		IF illx < llx THEN llx := illx END;
		IF iurx > urx THEN urx := iurx END;
		IF illy < lly THEN lly := illy END;
		IF iury > ury THEN ury := iury END
	END IncludeRect;

	(** shrink rectangle to area within other rectangle **)
	PROCEDURE ClipRect* (VAR llx, lly, urx, ury: INTEGER; cllx, clly, curx, cury: INTEGER);
	BEGIN
		IF cllx > llx THEN llx := cllx END;
		IF curx < urx THEN urx := curx END;
		IF clly > lly THEN lly := clly END;
		IF cury < ury THEN ury := cury END
	END ClipRect;

	(** return whether rectangle is empty **)
	PROCEDURE RectEmpty* (llx, lly, urx, ury: INTEGER): BOOLEAN;
	BEGIN
		RETURN (llx >= urx) OR (lly >= ury)
	END RectEmpty;

	(** return whether (non_empty) rectangle is completely inside other rectangle **)
	PROCEDURE RectInRect* (llx, lly, urx, ury, illx, illy, iurx, iury: INTEGER): BOOLEAN;
	BEGIN
		RETURN (llx >= illx) & (urx <= iurx) & (lly >= illy) & (ury <= iury)
	END RectInRect;

	(** return whether (non_empty) rectangle intersects other rectangle **)
	PROCEDURE RectsIntersect* (llx, lly, urx, ury, illx, illy, iurx, iury: INTEGER): BOOLEAN;
	BEGIN
		RETURN (llx < iurx) & (urx > illx) & (lly < iury) & (ury > illy)
	END RectsIntersect;

	(** return whether rectangle contains point **)
	PROCEDURE PointInRect* (x, y: INTEGER; llx, lly, urx, ury: INTEGER): BOOLEAN;
	BEGIN
		RETURN (x >= llx) & (x < urx) & (y >= lly) & (y < ury)
	END PointInRect;


	(*--- Auxiliary Routines For Managing Regions ---*)

	(* encode point coordinates and curve direction into a LONGINT *)
	PROCEDURE Encode (VAR item: LONGINT; u, v, dir: LONGINT);
	BEGIN
		item := ASH(v, 16) + ASH((u + 4000H) MOD 8000H, 1) + ASH(1 + dir, -1)
	END Encode;

	(* restore point coordinates and curve direction from an encoded LONGINT *)
	PROCEDURE Decode (item: LONGINT; VAR u, v, dir: INTEGER);
	BEGIN
		v := INTEGER(ASH(item, -16));
		u := INTEGER(ASH(item, -1) MOD 8000H - 4000H);
		dir := INTEGER(ASH(item MOD 2, 1) - 1)
	END Decode;

	(* copy points between region data blocks *)
	PROCEDURE CopyPoints (src, dst: RegionData; points: LONGINT);
		VAR i: LONGINT;
	BEGIN
		i := 0;
		WHILE (i < points) & (i < LEN(dst)) & (i < LEN(src)) DO
			dst[i] := src[i];
			INC(i)
		END
	END CopyPoints;

	(* quick sort with limited recursion guarantee *)
	PROCEDURE SafeQuickSort(VAR data: ARRAY OF LONGINT; lo, hi: LONGINT);
	CONST limit = 8;
	VAR i, x, j, t, shortLo, shortHi, longLo, longHi: LONGINT;
	BEGIN
		WHILE (hi > lo) DO
			IF hi - lo < limit THEN	(* use straight insertion for less than limit entries... *)
				i := lo + 1;
				WHILE i <= hi DO
					x := data[i];
					j := i;
					WHILE (j > lo) & (x < data[j - 1]) DO
						data[j] := data[j - 1];
						DEC(j)
					END;
					data[j] := x;
					INC(i)
				END;
				hi := lo; (* termination! *)
			ELSE
				i := lo; j := hi;
				x := data[(lo + hi) DIV 2];
				REPEAT
					WHILE data[i] < x DO INC(i) END;
					WHILE data[j] > x DO DEC(j) END;
					IF i <= j THEN
						t := data[i]; data[i] := data[j]; data[j] := t;
						INC(i); DEC(j)
					END
				UNTIL i > j;
				IF (j - lo) < (hi - i) THEN (* generalized interval [lo,j] is smaller than interval [hi, i] *)
					shortLo := lo; shortHi := j;
					longLo := i; longHi := hi;
				ELSE
					longLo := lo; longHi := j;
					shortLo := i; shortHi := hi;
				END;
				IF (shortLo < shortHi) THEN 
					SafeQuickSort(data, shortLo, shortHi);
				END;
				(* now: tail recursion, call of: SortRange(data, longLo, longHi) *)
				lo := longLo; hi := longHi;
			END
		END;
	END SafeQuickSort;

	(**--- Region Queries ---**)

	(** return whether region is empty **)
	PROCEDURE Empty* (reg: Region): BOOLEAN;
	BEGIN
		RETURN reg.Empty();
	END Empty;

	(** return whether (non_empty) region is rectangular **)
	PROCEDURE IsRect* (reg: Region): BOOLEAN;
	BEGIN
		RETURN reg.IsRect();
	END IsRect;

	(** return whether point is inside (non_empty) region **)
	PROCEDURE PointInside* (x, y: INTEGER; reg: Region): BOOLEAN;
	BEGIN
		RETURN reg.PointInside(x, y);
	END PointInside;

	(** return whether (non_empty) rectangle is completely inside (non_empty) region **)
	PROCEDURE RectInside* (llx, lly, urx, ury: INTEGER; reg: Region): BOOLEAN;
	BEGIN
		RETURN reg.RectInside(llx, lly, urx, ury);
	END RectInside;

	(** return whether (non_empty) rectangle overlaps (non_empty) region **)
	PROCEDURE RectOverlaps* (llx, lly, urx, ury: INTEGER; reg: Region): BOOLEAN;
	BEGIN
		RETURN reg.RectOverlaps(llx, lly, urx, ury);
	END RectOverlaps;

	(** return whether region is completely within another region **)
	PROCEDURE RegionInside* (inner, outer: Region): BOOLEAN;
	BEGIN
		RETURN inner.RegionInside(outer);
	END RegionInside;

	(** return whether two regions intersect each other **)
	PROCEDURE RegionOverlaps* (reg, arg: Region): BOOLEAN;
	BEGIN
		RETURN reg.RegionOverlaps(arg);
	END RegionOverlaps;

	(** enumerate region within rectangle **)
	PROCEDURE Enumerate* (reg: Region; llx, lly, urx, ury: INTEGER; enum: Enumerator; VAR edata: EnumData);
	BEGIN
		reg.Enumerate(llx, lly, urx, ury, enum, edata);
	END Enumerate;

	(** enumerate parts of rectangle not within region **)
	PROCEDURE EnumerateInv* (reg: Region; llx, lly, urx, ury: INTEGER; enum: Enumerator; VAR edata: EnumData);
	BEGIN
		reg.EnumerateInv(llx, lly, urx, ury, enum, edata);
	END EnumerateInv;

	(**--- Region Construction ---**)

	(** make region empty **)
	PROCEDURE Clear* (reg: Region);
	BEGIN
		reg.Clear();
	END Clear;

	(** set region mode **)
	PROCEDURE SetMode* (reg: Region; mode: INTEGER);
	BEGIN
		reg.SetMode(mode);
	END SetMode;

	(** initialize region **)
	PROCEDURE Init* (reg: Region; mode: INTEGER);
	BEGIN
		reg.Init(mode);
	END Init;

	(** make region rectangular **)
	PROCEDURE SetToRect* (reg: Region; llx, lly, urx, ury: INTEGER);
	BEGIN
		reg.SetToRect(llx, lly, urx, ury);
	END SetToRect;

	(** shift region **)
	PROCEDURE Shift* (reg: Region; dx, dy: INTEGER);
	BEGIN
		reg.Shift(dx, dy);
	END Shift;

	(** copy region **)
	PROCEDURE Copy* (from, to: Region);
	BEGIN
		from.Copy(to);
	END Copy;

	(** add second region to first **)
	PROCEDURE Add* (reg, arg: Region);
	BEGIN
		reg.Add(arg);
	END Add;

	(** add rectangle to region **)
	PROCEDURE AddRect* (reg: Region; llx, lly, urx, ury: INTEGER);
	BEGIN
		reg.AddRect(llx, lly, urx, ury);
	END AddRect;

	(** subtract second region from first **)
	PROCEDURE Subtract* (reg, arg: Region);
	BEGIN
		reg.Subtract(arg);
	END Subtract;

	(** subtract rectangle from region **)
	PROCEDURE SubtractRect* (reg: Region; llx, lly, urx, ury: INTEGER);
	BEGIN
		reg.SubtractRect(llx, lly, urx, ury);
	END SubtractRect;

	(** intersect first region with second region **)
	PROCEDURE Intersect* (reg, arg: Region);
	BEGIN
		reg.Intersect(arg);
	END Intersect;

	(** intersect region with rectangle **)
	PROCEDURE IntersectRect* (reg: Region; llx, lly, urx, ury: INTEGER);
	BEGIN
		reg.IntersectRect(llx, lly, urx, ury);
	END IntersectRect;

	(** invert region **)
	PROCEDURE Invert* (reg: Region);
	BEGIN
		reg.Invert();
	END Invert;

	(** add a scanline intersection to a region **)
	PROCEDURE AddPoint* (reg: Region; x, y, dy: INTEGER);
	BEGIN
		reg.AddPoint(x, y, dy);
	END AddPoint;

END GfxRegions.
