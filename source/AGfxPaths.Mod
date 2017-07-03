(* ETH Oberon, Copyright 2001 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

MODULE GfxPaths; (** portable *)	(* eos  *)
(** AUTHOR "eos"; PURPOSE "Two_dimensional paths consisting of lines, arcs and bezier curves"; *)

	(*
		9.2.98 - made behaviour of EnumSpline similar to that of EnumArc and EnumBezier (produces no Enter/Exit)
		11.2.98 - eliminated offset parameter in Enter elements, optimized data structure (now always pair in CoordBlock)
		12.2.98 - added length functions
		18.3.98 - fixed bug in EnumQuery (kept wrong code for next line)
		13.5.98 - fixed bug in EnumBezier (wrong calculation; used x instead of y)
		15.9.98 - minor cleanup: removed position, Save/Restore, GetBBox; simplified scanner interface
		26.11.98 - added procedure Close
		26.1.99 - added procedure Split
		21.5.99 - fixed major bug in Reverse (no update of destination path fields)
		12.7.99 - fixed another bug in Reverse (wrong direction when reverting Exit element)
		12.7.99 - approximate arc with line if radius is smaller than flatness
		18.02.2000 - simpler initial step without sqrt in EnumArc
		18.02.2000 - more robust bezier code (deals with folded curves and cusps)
		27.02.2000 - fixed arc code for starting points that are not on the ellipse
		04.05.2000 - fixed solve; one execution path never set number of solutions (noticed by gf)
	*)

	IMPORT
		Math, GfxMatrix;


	CONST
		Stop* = 0; Enter* = 1; Line* = 2; Arc* = 3; Bezier* = 4; Exit* = 5;	(** path element types **)

		ElemBlockSize = 16;	(* base of number of path elements *)
		CoordBlockSize = 32;	(* base of number of path coordinates *)

		MaxSplinePoints* = 128;	(** maximal number of control points in a spline **)

		Left = 0; Right = 1; Bottom = 2; Top = 3;	(* clip codes *)


	TYPE
		(* internal path structures *)
		ElemBlock = POINTER TO ElemBlockDesc;
		ElemBlockDesc = RECORD
			next: ElemBlock;
			elem: ARRAY ElemBlockSize OF SHORTINT;
			coords: INTEGER;
		END;

		CoordBlock = POINTER TO CoordBlockDesc;
		CoordBlockDesc = RECORD
			next: CoordBlock;
			x, y: ARRAY CoordBlockSize OF REAL;
		END;

		(** path abstraction **)
		Path* = OBJECT
		VAR
			elems* := 0, coords* := 0: INTEGER;	(** number of elements/coordinate pairs in path **)
			firstEB := NIL, lastEB := NIL: ElemBlock;	(* path element types *)
			firstCB := NIL, lastCB := NIL: CoordBlock;	(* path element coordinates *)
			
			(** discard previous contents and start new path **)
			PROCEDURE Clear* ();
			BEGIN
				IF SELF.firstEB = NIL THEN NEW(SELF.firstEB) END;
				SELF.lastEB := SELF.firstEB; SELF.lastEB.next := NIL;
				IF SELF.firstCB = NIL THEN NEW(SELF.firstCB) END;
				SELF.lastCB := SELF.firstCB; SELF.lastCB.next := NIL;
				SELF.elems := 0; SELF.coords := 0;
				SELF.firstEB.coords := 0
			END Clear;
			
			(** append enter element **)
			PROCEDURE AddEnter* (x, y, dx, dy: REAL);
			BEGIN
				AddElem(SELF, Enter);
				AddCoord(SELF, dx, dy);
				AddCoord(SELF, x, y)
			END AddEnter;
			
			(** append line element **)
			PROCEDURE AddLine* (x, y: REAL);
			BEGIN
				AddElem(SELF, Line);
				AddCoord(SELF, x, y)
			END AddLine;

			(** append arc element **)
			PROCEDURE AddArc* (x, y, x0, y0, x1, y1, x2, y2: REAL);
			BEGIN
				AddElem(SELF, Arc);
				AddCoord(SELF, x0, y0);
				AddCoord(SELF, x1, y1);
				AddCoord(SELF, x2, y2);
				AddCoord(SELF, x, y)
			END AddArc;

			(** append bezier element **)
			PROCEDURE AddBezier* (x, y, x1, y1, x2, y2: REAL);
			BEGIN
				AddElem(SELF, Bezier);
				AddCoord(SELF, x1, y1);
				AddCoord(SELF, x2, y2);
				AddCoord(SELF, x, y)
			END AddBezier;

			(** append exit element **)
			PROCEDURE AddExit* (dx, dy: REAL);
			BEGIN
				AddElem(SELF, Exit);
				AddCoord(SELF, dx, dy)
			END AddExit;

			(** append subpath for axis-aligned rectangle **)
			PROCEDURE AddRect* (llx, lly, urx, ury: REAL);
			BEGIN
				SELF.AddEnter(llx, lly, 0, lly - ury);
				SELF.AddLine(urx, lly); SELF.AddLine(urx, ury); SELF.AddLine(llx, ury); SELF.AddLine(llx, lly);
				SELF.AddExit(urx - llx, 0)
			END AddRect;

			(** append one path path another **)
			PROCEDURE Append* (from: Path);
				VAR pos, epos, cpos, n: INTEGER; eb: ElemBlock; cb: CoordBlock; elem: SHORTINT;
			BEGIN
				pos := 0; epos := 0; cpos := 0; eb := from.firstEB; cb := from.firstCB;
				WHILE pos < from.elems DO
					IF epos = ElemBlockSize THEN
						eb := eb.next; epos := 0
					END;
					elem := eb.elem[epos]; INC(epos);
					AddElem(SELF, elem);
					n := Coords[elem];
					WHILE n > 0 DO
						IF cpos = CoordBlockSize THEN
							cb := cb.next; cpos := 0
						END;
						AddCoord(SELF, cb.x[cpos], cb.y[cpos]);
						INC(cpos); DEC(n)
					END;
					INC(pos)
				END
			END Append;

			(** enumerate path elements **)
			PROCEDURE Enumerate* (enum: Enumerator; VAR data: EnumData);
				VAR eb: ElemBlock; cb: CoordBlock; pos, epos, cpos: INTEGER;

				PROCEDURE get (VAR x, y: REAL);
				BEGIN
					IF cpos = CoordBlockSize THEN
						cb := cb.next; cpos := 0;
					END;
					x := cb.x[cpos]; y := cb.y[cpos]; INC(cpos);
				END get;

			BEGIN
				eb := SELF.firstEB; cb := SELF.firstCB;
				pos := 0; epos := 0; cpos := 0;
				WHILE pos < SELF.elems DO
					IF epos = ElemBlockSize THEN
						eb := eb.next; epos := 0;
					END;
					data.elem := eb.elem[epos];
					CASE data.elem OF
					| Enter: get(data.dx, data.dy); get(data.x, data.y);
					| Line: get(data.x, data.y);
					| Arc: get(data.x0, data.y0); get(data.x1, data.y1); get(data.x2, data.y2); get(data.x, data.y);
					| Bezier: get(data.x1, data.y1); get(data.x2, data.y2); get(data.x, data.y);
					| Exit: get(data.dx, data.dy);
					END;
					enum(data);
					INC(pos); INC(epos);
				END
			END Enumerate;

			(** enumerate flattened path, i.e. arcs and bezier curves will be approximated with lines **)
			PROCEDURE EnumFlattened* (flatness: REAL; enum: Enumerator; VAR data: EnumData);
				VAR eb: ElemBlock; cb: CoordBlock; pos, epos, cpos: INTEGER; x0, y0, x1, y1, x2, y2, x, y: REAL;

				PROCEDURE get (VAR x, y: REAL);
				BEGIN
					IF cpos = CoordBlockSize THEN
						cb := cb.next; cpos := 0;
					END;
					x := cb.x[cpos]; y := cb.y[cpos]; INC(cpos);
				END get;

			BEGIN
				eb := SELF.firstEB; cb := SELF.firstCB;
				pos := 0; epos := 0; cpos := 0;
				WHILE pos < SELF.elems DO
					IF epos = ElemBlockSize THEN
						eb := eb.next; epos := 0
					END;
					data.elem := eb.elem[epos];
					CASE data.elem OF
					| Enter:
						get(data.dx, data.dy); get(data.x, data.y);
						enum(data)
					| Line:
						get(data.x, data.y);
						enum(data)
					| Arc:
						get(x0, y0); get(x1, y1); get(x2, y2); get(x, y);
						EnumArc(x0, y0, x1, y1, x2, y2, x, y, flatness, enum, data)
					| Bezier:
						get(x1, y1); get(x2, y2); get(x, y);
						EnumBezier(x1, y1, x2, y2, x, y, flatness, enum, data);
						(* why this? data.elem := Line; data.x := x; data.y := y; enum(data) *)
					| Exit:
						get(data.dx, data.dy);
						enum(data);
					END;
					INC(pos); INC(epos)
				END
			END EnumFlattened;

			(** calculate path length **)
			PROCEDURE Length* (flatness: REAL): REAL;
				VAR data: LengthData;
			BEGIN
				data.len := 0;
				SELF.EnumFlattened(flatness, EnumLength, data);
				RETURN data.len
			END Length;

			(** return whether path is empty **)
			PROCEDURE Empty* (): BOOLEAN;
			BEGIN
				RETURN SELF.elems = 0
			END Empty;

			(** calculate bounding box of path **)
			PROCEDURE GetBox* (VAR llx, lly, urx, ury: REAL);
				VAR data: QueryData;
			BEGIN
				data.llx := MAX(REAL); data.lly := MAX(REAL); data.urx := MIN(REAL); data.ury := MIN(REAL);
				SELF.EnumFlattened(1, EnumBoxElem, data);
				llx := data.llx; lly := data.lly; urx := data.urx; ury := data.ury
			END GetBox;
			
			(**--- Path Operations ---**)

			(** put reversed source path into destination path; dst remains unchanged if src is empty **)
			PROCEDURE ReverseTo* (dst: Path);
				VAR
					elems, sepos, scpos, depos, dcpos: INTEGER; dstEB, nextEB, srcEB, eb: ElemBlock;
					dstCB, nextCB, srcCB: CoordBlock; dx, dy, x, y, x0, y0, x1, y1, x2, y2: REAL;

				PROCEDURE get (VAR x, y: REAL);
				BEGIN
					IF scpos = CoordBlockSize THEN
						srcCB := srcCB.next; scpos := 0
					END;
					x := srcCB.x[scpos]; y := srcCB.y[scpos]; INC(scpos)
				END get;

				PROCEDURE put (x, y: REAL);
					VAR cb: CoordBlock;
				BEGIN
					IF dcpos = 0 THEN
						IF nextCB # NIL THEN cb := nextCB; nextCB := cb.next
						ELSE NEW(cb)
						END;
						cb.next := dstCB; dstCB := cb;
						dcpos := CoordBlockSize
					END;
					DEC(dcpos); INC(dstEB.coords);
					dstCB.x[dcpos] := x; dstCB.y[dcpos] := y
				END put;

			BEGIN
				ASSERT(SELF # dst, 100);
				elems := SELF.elems;
				IF elems > 0 THEN
					IF dst.firstEB # NIL THEN dstEB := dst.firstEB; dstEB.coords := 0; nextEB := dstEB.next; dstEB.next := NIL
					ELSE NEW(dstEB); nextEB := NIL
					END;
					IF dst.firstCB # NIL THEN dstCB := dst.firstCB; nextCB := dstCB.next; dstCB.next := NIL
					ELSE NEW(dstCB); nextCB := NIL
					END;
					dst.lastEB := dstEB; dst.lastCB := dstCB;
					srcEB := SELF.firstEB; srcCB := SELF.firstCB;
					sepos := 0; scpos := 0;
					depos := (SELF.elems-1) MOD ElemBlockSize + 1; dcpos := (SELF.coords-1) MOD CoordBlockSize + 1;
					REPEAT
						(*
							store reverted path in dst:
								- segment end points become end points of their inverted successors
								- order of control points is reversed
								- directions are inverted
						*)
						IF sepos = ElemBlockSize THEN
							srcEB := srcEB.next; sepos := 0
						END;
						IF depos = 0 THEN
							IF nextEB # NIL THEN eb := nextEB; eb.coords := 0; nextEB := eb.next
							ELSE NEW(eb)
							END;
							eb.next := dstEB; dstEB := eb;
							depos := ElemBlockSize
						END;
						DEC(depos);
						CASE srcEB.elem[sepos] OF
						| Enter:
							dstEB.elem[depos] := Exit;
							get(dx, dy); get(x, y);
							put(-dx, -dy); put(x, y)
						| Line:
							dstEB.elem[depos] := Line;
							get(x, y);
							put(x, y)
						| Arc:
							dstEB.elem[depos] := Arc;
							get(x0, y0); get(x1, y1); get(x2, y2); get(x, y);
							put(x1, y1); put(x2, y2); put(x0, y0); put(x, y)
						| Bezier:
							dstEB.elem[depos] := Bezier;
							get(x1, y1); get(x2, y2); get(x, y);
							put(x1, y1); put(x2, y2); put(x, y)
						| Exit:
							dstEB.elem[depos] := Enter;
							get(dx, dy);
							put(-dx, -dy)
						END;
						INC(sepos); DEC(elems)
					UNTIL elems = 0;
					dst.firstEB := dstEB; dst.firstCB := dstCB;
					dst.elems := SELF.elems; dst.coords := SELF.coords
				END
			END ReverseTo;

			(** return copy of source path in destination path **)
			PROCEDURE CopyTo* (dst: Path);
				VAR srcEB, dstEB: ElemBlock; n: INTEGER; srcCB, dstCB: CoordBlock;
			BEGIN
				IF SELF # dst THEN
					IF dst.firstEB = NIL THEN NEW(dst.firstEB) END;
					srcEB := SELF.firstEB; dstEB := dst.firstEB;
					LOOP
						IF srcEB = SELF.lastEB THEN n := (SELF.elems-1) MOD ElemBlockSize + 1
						ELSE n := ElemBlockSize
						END;
						WHILE n > 0 DO
							DEC(n); dstEB.elem[n] := srcEB.elem[n]
						END;
						dstEB.coords := srcEB.coords;
						IF srcEB = SELF.lastEB THEN EXIT END;
						IF dstEB.next = NIL THEN NEW(dstEB.next) END;
						srcEB := srcEB.next; dstEB := dstEB.next
					END;
					dst.lastEB := dstEB; dstEB.next := NIL;

					IF dst.firstCB = NIL THEN NEW(dst.firstCB) END;
					srcCB := SELF.firstCB; dstCB := dst.firstCB;
					LOOP
						IF srcCB = SELF.lastCB THEN n := (SELF.coords-1) MOD CoordBlockSize + 1
						ELSE n := CoordBlockSize
						END;
						WHILE n > 0 DO
							DEC(n); dstCB.x[n] := srcCB.x[n]; dstCB.y[n] := srcCB.y[n]
						END;
						IF srcCB = SELF.lastCB THEN EXIT END;
						IF dstCB.next = NIL THEN NEW(dstCB.next) END;
						srcCB := srcCB.next; dstCB := dstCB.next
					END;
					dst.lastCB := dstCB; dstCB.next := NIL;
					dst.elems := SELF.elems; dst.coords := SELF.coords
				END
			END CopyTo;

			(** apply transformation to all coordinates in path **)
			PROCEDURE Apply* (VAR mat: GfxMatrix.Matrix);
				VAR eb: ElemBlock; cb: CoordBlock; pos, epos, cpos: INTEGER;

				PROCEDURE point (VAR b: CoordBlock; VAR idx: INTEGER);
				BEGIN
					IF idx = CoordBlockSize THEN
						b := b.next; idx := 0
					END;
					GfxMatrix.Apply(mat, b.x[idx], b.y[idx], b.x[idx], b.y[idx]);
					INC(idx)
				END point;

				PROCEDURE vector (VAR b: CoordBlock; VAR idx: INTEGER);
				BEGIN
					IF idx = CoordBlockSize THEN
						b := b.next; idx := 0
					END;
					GfxMatrix.ApplyToVector(mat, b.x[idx], b.y[idx], b.x[idx], b.y[idx]);
					INC(idx)
				END vector;

			BEGIN
				eb := SELF.firstEB; cb := SELF.firstCB;
				pos := 0; epos := 0; cpos := 0;
				WHILE pos < SELF.elems DO
					IF epos = ElemBlockSize THEN
						eb := eb.next; epos := 0
					END;
					CASE eb.elem[epos] OF
					| Enter: vector(cb, cpos); point(cb, cpos)
					| Line: point(cb, cpos)
					| Arc: point(cb, cpos); point(cb, cpos); point(cb, cpos); point(cb, cpos)
					| Bezier: point(cb, cpos); point(cb, cpos); point(cb, cpos)
					| Exit: vector(cb, cpos)
					END;
					INC(pos); INC(epos)
				END
			END Apply;

			(** try to close disconnected enter/exit points by modifying their direction vectors **)
			PROCEDURE Close* ();
				CONST
					eps = 0.001;

				VAR
					pos, epos, cpos, p, spos: INTEGER; eb: ElemBlock; cb, b, sb: CoordBlock; dx, dy, cx, cy, sx, sy, sdx, sdy, x, y, edx, edy: REAL;
					data: DirData;

				PROCEDURE get (VAR x, y: REAL);
				BEGIN
					IF cpos = CoordBlockSize THEN
						cb := cb.next; cpos := 0
					END;
					x := cb.x[cpos]; y := cb.y[cpos];
					INC(cpos)
				END get;

			BEGIN
				pos := 0; epos := 0; cpos := 0; eb := SELF.firstEB; cb := SELF.firstCB;
				WHILE pos < SELF.elems DO
					IF epos = ElemBlockSize THEN
						eb := eb.next; epos := 0
					END;
					CASE eb.elem[epos] OF
					| Enter:
						b := cb; p := cpos;
						get(dx, dy); get(cx, cy);
						IF (dx = 0) & (dy = 0) THEN
							sb := b; spos := p; sx := cx; sy := cy; sdx := 0; sdy := 0
						END
					| Line:
						get(x, y); dx := x - cx; dy := y - cy; cx := x; cy := y;
						IF (sdx = 0) & (sdy = 0) THEN
							sdx := dx; sdy := dy
						END
					| Arc:
						data.sdx := 0; data.sdy := 0; data.cx := cx; data.cy := cy; data.x := cx; data.y := cy;
						get(data.x0, data.y0); get(data.x1, data.y1); get(data.x2, data.y2); get(cx, cy);
						EnumArc(data.x0, data.y0, data.x1, data.y1, data.x2, data.y2, cx, cy, 1.0, GetDir, data);
						IF (sdx = 0) & (sdy = 0) THEN
							sdx := data.sdx; sdy := data.sdy
						END;
						dx := data.edx; dy := data.edy
					| Bezier:
						get(x, y);
						IF (sdx = 0) & (sdy = 0) THEN
							sdx := x - cx; sdy := y - cy
						END;
						get(x, y); get(cx, cy); dx := cx - x; dy := cy - y
					| Exit:
						b := cb; p := cpos;
						get(edx, edy);
						IF (edx = 0) & (edy = 0) & (ABS(x - sx) <= eps) & (ABS(y - sy) <= eps) THEN
							IF spos = CoordBlockSize THEN
								sb := sb.next; spos := 0
							END;
							sb.x[spos] := dx; sb.y[spos] := dy;
							IF p = CoordBlockSize THEN
								b := b.next; p := 0
							END;
							b.x[p] := sdx; b.y[p] := sdy
						END
					END;
					INC(pos); INC(epos)
				END
			END Close;
			
			(** split subpath in two at given offset (resulting subpaths may be flattened in the process) **)
			PROCEDURE Split* (offset: REAL; head, tail: Path);
				VAR data: SplitData;
			BEGIN
				IF offset <= 0 THEN
					SELF.CopyTo(tail); head.Clear()
				ELSIF offset >= SELF.Length(1) THEN
					SELF.CopyTo(head); tail.Clear()
				ELSE
					head.Clear(); tail.Clear();
					data.offset := offset; data.head := head; data.tail := tail;
					SELF.EnumFlattened(1, EnumSplit, data)
				END
			END Split;
			
			(** return projection of point onto path **)
			PROCEDURE ProjectTo* (x, y: REAL; VAR u, v: REAL);
				VAR data: ProjectData;
			BEGIN
				data.px := x; data.py := y; data.dist := MAX(REAL); data.rx := MAX(REAL); data.ry := MAX(REAL);
				SELF.EnumFlattened(1, EnumProject, data);
				u := data.rx; v := data.ry
			END ProjectTo;

			(**--- Path Queries ---**)

			(** return whether rectangle is completely inside (closed) path **)
			PROCEDURE InPath* (llx, lly, urx, ury: REAL; evenOdd: BOOLEAN): BOOLEAN;
				VAR data: QueryData;
			BEGIN
				data.thorough := TRUE; data.sum := 0; data.hit := FALSE; data.llx := llx; data.lly := lly; data.urx := urx; data.ury := ury;
				SELF.EnumFlattened(1, EnumQuery, data);
				RETURN data.hit OR evenOdd & ODD(ABS(data.sum) DIV 2) OR ~evenOdd & (data.sum # 0)
			END InPath;

			(** return whether rectangle intersects SELF **)
			PROCEDURE OnPath* (llx, lly, urx, ury: REAL): BOOLEAN;
				VAR data: QueryData;
			BEGIN
				data.thorough := FALSE; data.hit := FALSE; data.llx := llx; data.lly := lly; data.urx := urx; data.ury := ury;
				SELF.EnumFlattened(1, EnumQuery, data);
				RETURN data.hit
			END OnPath;

			
		END Path;

		(** path scanner **)
		(**
			Path scanners can be used to iterate over a path under client control. The scanner's elem field specifies what
			the current element is, whereas the remaining fields contain the parameters for that element. A Stop element
			indicates that the end of the path has been reached.
		**)
		Scanner* = RECORD
			path*: Path;	(** visited path **)
			pos*: INTEGER;	(** element position **)
			elem*: INTEGER;	(** current path element **)
			x*, y*: REAL;	(** current end coordinates **)
			dx*, dy*: REAL;	(** direction vector **)
			x0*, y0*, x1*, y1*, x2*, y2*: REAL;	(** additional control point coordinates **)
			curEB: ElemBlock;	(* current element block *)
			curCB: CoordBlock;	(* current coordinate block *)
			epos, cpos: INTEGER;	(* next element and coordinate position within current block *)
			
			
			(** open scanner on path and load parameters of element at given position **)
			PROCEDURE Open* (path: Path; pos: INTEGER);
			BEGIN
				SELF.path := path;
				SELF.curEB := path.firstEB; SELF.curCB := path.firstCB;
				SELF.pos := pos; SELF.epos := pos; SELF.cpos := 0;
				WHILE SELF.epos > ElemBlockSize DO
					DEC(SELF.epos, ElemBlockSize);
					INC(SELF.cpos, SELF.curEB.coords);
					SELF.curEB := SELF.curEB.next
				END;
				pos := 0;
				WHILE pos < SELF.epos DO
					SELF.cpos := SELF.cpos + Coords[SELF.curEB.elem[pos]]; INC(pos)
				END;
				WHILE SELF.cpos > CoordBlockSize DO
					DEC(SELF.cpos, CoordBlockSize);
					SELF.curCB := SELF.curCB.next
				END;
				IF SELF.pos = path.elems THEN
					SELF.elem := Stop
				ELSE
					IF SELF.epos = ElemBlockSize THEN	(* at end of current block *)
						SELF.curEB := SELF.curEB.next; SELF.epos := 0
					END;
					SELF.elem := SELF.curEB.elem[SELF.epos]; INC(SELF.epos);
					CASE SELF.elem OF
					| Enter: get(SELF.dx, SELF.dy); get(SELF.x, SELF.y)
					| Line: get(SELF.x, SELF.y)
					| Arc: get(SELF.x0, SELF.y0); get(SELF.x1, SELF.y1); get(SELF.x2, SELF.y2); get(SELF.x, SELF.y)
					| Bezier: get(SELF.x1, SELF.y1); get(SELF.x2, SELF.y2); get(SELF.x, SELF.y)
					| Exit: get(SELF.dx, SELF.dy)
					END
				END
			END Open;
			
			(** advance to next element and load its parameters **)
			PROCEDURE Scan* ();
			BEGIN
				IF SELF.pos < SELF.path.elems THEN
					INC(SELF.pos);
					IF SELF.pos = SELF.path.elems THEN
						SELF.elem := Stop
					ELSE
						IF SELF.epos = ElemBlockSize THEN	(* at end of current block *)
							SELF.curEB := SELF.curEB.next; SELF.epos := 0
						END;
						SELF.elem := SELF.curEB.elem[SELF.epos]; INC(SELF.epos);
						CASE SELF.elem OF
						| Enter: get(SELF.dx, SELF.dy); get(SELF.x, SELF.y)
						| Exit: get(SELF.dx, SELF.dy)
						| Line: get(SELF.x, SELF.y)
						| Arc: get(SELF.x0, SELF.y0); get(SELF.x1, SELF.y1); get(SELF.x2, SELF.y2); get(SELF.x, SELF.y)
						| Bezier: get(SELF.x1, SELF.y1); get(SELF.x2, SELF.y2); get(SELF.x, SELF.y)
						END
					END
				END
			END Scan;
	
			PROCEDURE get (VAR x, y: REAL);
			BEGIN
				IF SELF.cpos = CoordBlockSize THEN
					SELF.curCB := SELF.curCB.next; SELF.cpos := 0
				END;
				x := SELF.curCB.x[SELF.cpos]; y := SELF.curCB.y[SELF.cpos]; INC(SELF.cpos)
			END get;			
	
		END (* Scanner *);

		(** path enumeration **)
		EnumData* = RECORD
			elem*: INTEGER;	(** current path element **)
			x*, y*, dx*, dy*, x0*, y0*, x1*, y1*, x2*, y2*: REAL;	(** element parameters **)
		END;

		Enumerator* = PROCEDURE (VAR data: EnumData);

		ProjectData = RECORD (EnumData)
			px, py: REAL;	(* point coordinates *)
			rx, ry: REAL;	(* projection coordinates *)
			sx, sy: REAL;	(* previous coordinates *)
			dist: REAL;	(* distance of projection to original point *)
		END;

		QueryData = RECORD (EnumData)
			llx, lly, urx, ury: REAL;	(* query rectangle *)
			sx, sy: REAL;	(* previous coordinates *)
			code: SET;	(* clip code of previous point *)
			sum: LONGINT;	(* number of ray crossings for inside test *)
			hit, thorough: BOOLEAN;
		END;

		LengthData = RECORD (EnumData)
			sx, sy: REAL;	(* previous coordinates *)
			len: REAL;
		END;

		DirData = RECORD (EnumData)
			cx, cy: REAL;
			sdx, sdy: REAL;
			edx, edy: REAL;
		END;

		SplitData = RECORD (EnumData)
			head, tail: Path;
			offset: REAL;
			sx, sy: REAL;
			sdx, sdy: REAL
		END;


	(**
		A paths consists of any number of subpaths, where each subpath starts with a Enter element, followed by
		any number of curve elements, and terminated by an Exit element.

		Enter
			(x, y) is the starting point for the following curve element
			(dx, dy) is the tangent vector at the end of an adjacent subpath or (0, 0) if there is none

		Line
			(x, y) is the end point of the line and the starting point of any subsequent curve

		Arc
			(x, y) is the end point of the arc and the starting point of any subsequent curve (may coincide with the
					current point, resulting in a circle or ellipse)
			(x0, y0) is the center of the circle/ellipse this arc is part of
			(x1, y1) is the end point of the first half axis vector
			(x2, y2) is the end point of the first half axis vector (not necessarily perpendicular to the first HAV)

		Bezier
			(x, y) is the end point of the cubic bezier curve and the starting point of any subsequent curve
			(x1, y1) is the first control point of the cubic bezier curve
			(x1, y1) is the second control point of the cubic bezier curve

		Exit
			(dx, dy) is the tangent vector at the starting point of an adjacent subpath or (0, 0) if there is none
	**)


	VAR
		Coords: ARRAY Exit+1 OF SHORTINT;	(* number of coordinate pairs for each element type *)


	(**--- Path Construction ---**)

	PROCEDURE AddElem (path: Path; elem: SHORTINT);
		VAR elems: INTEGER; eb: ElemBlock;
	BEGIN
		elems := path.elems MOD ElemBlockSize;
		IF (elems = 0) & (path.elems > 0) THEN
			NEW(eb); path.lastEB.next := eb; path.lastEB := eb;
		END;
		path.lastEB.elem[elems] := elem;
		INC(path.elems)
	END AddElem;

	PROCEDURE AddCoord (path: Path; x, y: REAL);
		VAR coords: INTEGER; cb: CoordBlock;
	BEGIN
		coords := path.coords MOD CoordBlockSize;
		IF (coords = 0) & (path.coords > 0) THEN
			NEW(cb); path.lastCB.next := cb; path.lastCB := cb
		END;
		path.lastCB.x[coords] := x; path.lastCB.y[coords] := y;
		INC(path.coords); INC(path.lastEB.coords)
	END AddCoord;


	(**--- Enumerating (Flattened) Paths ---**)

	(**
		In addition to being scanned, path elements may also be enumerated. The advantage of enumerating path
		elements is that arcs and bezier curves can be enumerated as a sequence of lines approximating the original
		curve. Besides, natural splines can enumerated in terms of regular path elements.
	**)

	(** enumerate arc as a sequence of lines with maximal error 'flatness'; current point must be in (data.x, data.y) **)
	PROCEDURE EnumArc* (x0, y0, x1, y1, x2, y2, x, y, flatness: REAL; enum: Enumerator; VAR data: EnumData);
		CONST
			eps = 1.0E-3;
		VAR
			lx, ly, sense, xs, ys, xe, ye, dt, p2, tmp, p1, dx1, dx2, dy1, dy2, sx, sy, tx, ty, limit, dx, dy, tlen, ex, ey: REAL;
			positive: BOOLEAN;
	BEGIN
		(* algorithm: D. Fellner & C. Helmberg, Robust Rendering of General Ellipses and Elliptical Arcs, ACM TOG July 1993 *)
		data.elem := Line;
		x1 := x1 - x0; y1 := y1 - y0;
		x2 := x2 - x0; y2 := y2 - y0;
		IF ABS(x1 * y2 - y1 * x2) <= eps * ABS(x1 * x2 + y1 * y2) THEN	(* approximate with line *)
			data.x := x; data.y := y; enum(data);
			RETURN
		END;

		lx := ABS(x1) + ABS(x2); ly := ABS(y1) + ABS(y2);
		IF (lx <= ly) & (lx <= flatness) OR (ly <= lx) & (ly <= flatness) THEN	(* radius smaller than flatness *)
			data.x := x; data.y := y; enum(data);
			RETURN
		END;

		IF flatness < eps THEN flatness := eps END;
		IF x1 * y2 > y1 * x2 THEN sense := 1 ELSE sense := -1 END;
		xs := data.x - x0; ys := data.y - y0;
		xe := x - x0; ye := y - y0;
		IF lx >= ly THEN dt := flatness/lx
		ELSE dt := flatness/ly
		END;

		(* find first point on arc *)
		p2 := xs * y2 - ys * x2;
		IF ABS(p2) < eps THEN	(* (x2, y2) on start vector *)
			tmp := x1; x1 := x2; x2 := -tmp;
			tmp := y1; y1 := y2; y2 := -tmp;
			p1 := 0
		ELSE
			p1 := xs * y1 - ys * x1
		END;
		IF ABS(p1) < eps THEN	(* (x1, y1) on start vector *)
			IF xs * x1 + ys * y1 < -eps THEN	(* on opposite side of origin *)
				x1 := -x1; y1 := -y1;
				x2 := -x2; y2 := -y2
			END;
			IF ABS(x1 - xs) + ABS(y1 - ys) > flatness THEN
				data.x := x0 + x1; data.y := y0 + y1;
				enum(data)
			END;
			dx1 := 0; dx2 := 0; dy1 := 0; dy2 := 0
		ELSE	(* search start point on ellipse *)
			IF (p1 > 0) = (p2 > 0) THEN
				tmp := x1; x1 := x2; x2 := -tmp;
				tmp := y1; y1 := y2; y2 := -tmp;
				p1 := p2
			END;
			IF p1 * sense > 0 THEN
				x1 := -x1; y1 := -y1;
				x2 := -x2; y2 := -y2
			END;
			dx1 := 0; dx2 := 0; dy1 := 0; dy2 := 0;
			REPEAT
				tmp := dx1;
				dx1 := (x2 - 0.5 * dx2) * dt; dx2 := (x1 + 0.5 * tmp) * dt;
				x1 := x1 + dx1; x2 := x2 - dx2;
				tmp := dy1;
				dy1 := (y2 - 0.5 * dy2) * dt; dy2 := (y1 + 0.5 * tmp) * dt;
				y1 := y1 + dy1; y2 := y2 - dy2
			UNTIL (xs * y1 - ys * x1) * sense >= 0;
			data.x := x0 + x1; data.y := y0 + y1;
			enum(data)
		END;

		sx := x1; sy := y1;	(* start point of current line *)
		tx := 0; ty := 0;	(* (approximate) tangent vector at start point *)
		limit := flatness * flatness;
		positive := ((ye * x1 - xe * y1) * sense > 0);
		LOOP
			tmp := dx1;
			dx1 := (x2 - 0.5 * dx2) * dt; dx2 := (x1 + 0.5 * tmp) * dt;
			x1 := x1 + dx1; x2 := x2 - dx2;
			tmp := dy1;
			dy1 := (y2 - 0.5 * dy2) * dt; dy2 := (y1 + 0.5 * tmp) * dt;
			y1 := y1 + dy1; y2 := y2 - dy2;
			p1 := (ye * x1 - xe * y1) * sense;
			IF p1 > 0 THEN
				positive := TRUE
			ELSIF positive THEN
				EXIT
			END;
			dx := x1 - sx; dy := y1 - sy;
			IF (tx = 0) & (ty = 0) THEN	(* first point *)
				tx := dx; ty := dy; tlen := tx * tx + ty * ty
			ELSE
				tmp := dx * ty - dy * tx;
				IF (tmp * tmp)/tlen > limit THEN	(* distance from new point to tangent vector is greater than flatness *)
					sx := ex; sy := ey;
					data.x := x0 + sx; data.y := y0 + sy;
					enum(data);
					tx := dx; ty := dy; tlen := tx * tx + ty * ty
				END
			END;
			ex := x1; ey := y1
		END;
		data.x := x; data.y := y;
		enum(data)
	END EnumArc;

	(** enumerate bezier curve as a sequence of lines with maximal error 'flatness'; current point must be in (data.x, data.y) **)
	PROCEDURE EnumBezier* (x1, y1, x2, y2, x, y, flatness: REAL; enum: Enumerator; VAR data: EnumData);
		CONST eps = 1.0E-8;
		VAR f2, ax, bx, t, x01, x11, x12, x22, x23, y01, y11, y12, y22, y23: REAL;

		PROCEDURE subdiv (t, x0, x1, x2, x3: REAL; VAR a1, a2, m, b1, b2: REAL);
			VAR s, x12: REAL;
		BEGIN
			s := 1-t;
			a1 := s * x0 + t * x1; b2 := s * x2 + t * x3; x12 := s * x1 + t * x2;
			a2 := s * a1 + t * x12; b1 := s * x12 + t * b2;
			m := s * a2 + t * b1
		END subdiv;

		PROCEDURE draw (x1, y1, x2, y2, x, y: REAL);
			VAR x01, x11, x12, x22, x23, y01, y11, y12, y22, y23, dx, dy, ex, ey, cp: REAL;
		BEGIN
			subdiv(0.5, data.x, x1, x2, x, x01, x11, x12, x22, x23);
			subdiv(0.5, data.y, y1, y2, y, y01, y11, y12, y22, y23);
			dx := x12 - data.x; dy := y12 - data.y;
			ex := x - data.x; ey := y - data.y;
			cp := dx*ey - dy*ex;
			IF cp*cp <= f2 * (ex*ex + ey*ey) THEN	(* flat enough *)
				data.x := x; data.y := y; enum(data)
			ELSE
				draw(x01, y01, x11, y11, x12, y12);
				draw(x22, y22, x23, y23, x, y)
			END
		END draw;

		PROCEDURE solve (a, b, c: REAL; VAR t1, t2: REAL; VAR n: INTEGER);
			VAR d, e, t: REAL;
		BEGIN
			n := 0; d := b * b - a * c;
			IF d >= 0 THEN
				d := Math.sqrt(d); e := -b + d;
				IF (a * e > 0) & (ABS(e) < ABS(a)) THEN
					t1 := e/a; n := 1;
					e := -b - d;
					IF (d > 0) & (a * e > 0) & (ABS(e) < ABS(a)) THEN
						t2 := e/a; n := 2;
						IF t2 < t1 THEN t := t1; t1 := t2; t2 := t END
					END
				ELSE
					e := -b - d;
					IF (a * e > 0) & (ABS(e) < ABS(a)) THEN
						t1 := e/a; n := 1
					END
				END
			END;
			ASSERT((n = 0) OR (n = 1) & (0 < t1) & (t1 < 1) OR (n = 2) & (0 < t1) & (t1 < t2) & (t2 < 1))
		END solve;

		PROCEDURE norm2y (x1, y1, x2, y2, x, y: REAL);
			VAR t1, t2, x01, x11, x12, x22, x23, y01, y11, y12, y22, y23: REAL; n: INTEGER;
		BEGIN
			solve(y - data.y + 3*(y1 - y2), data.y - 2*y1 + y2, y1 - data.y, t1, t2, n);
			IF n = 0 THEN
				draw(x1, y1, x2, y2, x, y)
			ELSE
				subdiv(t1, data.x, x1, x2, x, x01, x11, x12, x22, x23);
				subdiv(t1, data.y, y1, y2, y, y01, y11, y12, y22, y23);
				draw(x01, y01, x11, y11, x12, y12);
				IF n = 2 THEN
					t2 := (t2 - t1)/(1-t1);
					subdiv(t2, data.x, x22, x23, x, x01, x11, x12, x22, x23);
					subdiv(t2, data.y, y22, y23, y, y01, y11, y12, y22, y23);
					draw(x01, y01, x11, y11, x12, y12)
				END;
				draw(x22, y22, x23, y23, x, y)
			END
		END norm2y;

		PROCEDURE norm2x (x1, y1, x2, y2, x, y: REAL);
			VAR t1, t2, x01, x11, x12, x22, x23, y01, y11, y12, y22, y23: REAL; n: INTEGER;
		BEGIN
			solve(x - data.x + 3*(x1 - x2), data.x - 2*x1 + x2, x1 - data.x, t1, t2, n);
			IF n = 0 THEN
				norm2y(x1, y1, x2, y2, x, y)
			ELSE
				subdiv(t1, data.x, x1, x2, x, x01, x11, x12, x22, x23);
				subdiv(t1, data.y, y1, y2, y, y01, y11, y12, y22, y23);
				norm2y(x01, y01, x11, y11, x12, y12);
				IF n = 2 THEN
					t2 := (t2 - t1)/(1-t1);
					subdiv(t2, data.x, x22, x23, x, x01, x11, x12, x22, x23);
					subdiv(t2, data.y, y22, y23, y, y01, y11, y12, y22, y23);
					norm2y(x01, y01, x11, y11, x12, y12)
				END;
				norm2y(x22, y22, x23, y23, x, y)
			END
		END norm2x;

		PROCEDURE norm1y (x1, y1, x2, y2, x, y: REAL);
			VAR ay, by, t, x01, x11, x12, x22, x23, y01, y11, y12, y22, y23: REAL;
		BEGIN
			ay := y - data.y + 3*(y1 - y2); by := data.y - 2*y1 + y2;
			IF (ay * by < 0) & (ABS(by) < ABS(ay)) THEN
				t := -by/ay;
				subdiv(t, data.x, x1, x2, x, x01, x11, x12, x22, x23);
				subdiv(t, data.y, y1, y2, y, y01, y11, y12, y22, y23);
				norm2x(x01, y01, x11, y11, x12, y12);
				norm2x(x22, y22, x23, y23, x, y)
			ELSE
				norm2x(x1, y1, x2, y2, x, y)
			END
		END norm1y;

	BEGIN
		data.elem := Line;
		f2 := flatness * flatness;
		IF f2 < eps THEN f2 := eps END;
		ax := x - data.x + 3*(x1 - x2); bx := data.x - 2*x1 + x2;
		IF (ax * bx < 0) & (ABS(bx) < ABS(ax)) THEN
			t := -bx/ax;
			subdiv(t, data.x, x1, x2, x, x01, x11, x12, x22, x23);
			subdiv(t, data.y, y1, y2, y, y01, y11, y12, y22, y23);
			norm1y(x01, y01, x11, y11, x12, y12);
			norm1y(x22, y22, x23, y23, x, y)
		ELSE
			norm1y(x1, y1, x2, y2, x, y)
		END
	END EnumBezier;

	(*
	 * The code for the spline evaluation has been adapted from Beat Stamm's Graphic module. It handles natural open
	 * and closed splines.
	 *)

	PROCEDURE SolveClosed (n: LONGINT; VAR x, y, d: ARRAY OF REAL);
		VAR hn, dn, d0, d1, t1, t2: REAL; a, b, c, u: ARRAY MaxSplinePoints OF REAL; i: LONGINT;
	BEGIN
		hn := 1/(x[n - 1] - x[n - 2]); dn := 3 * (y[n - 1] - y[n - 2]) * hn * hn;
		b[0] := 1/(x[1] - x[0]); a[0] := hn + 2*b[0]; c[0] := b[0];
		d0 := 3 * (y[1] - y[0]) * b[0] * b[0]; d[0] := dn + d0;
		u[0] := 1;
		i := 1;
		WHILE i < n - 2 DO
			b[i] := 1/(x[i + 1] - x[i]); a[i] := 2 * (c[i - 1] + b[i]); c[i] := b[i];
			d1 := 3 * (y[i + 1] - y[i]) * b[i] * b[i]; d[i] := d0 + d1; d0 := d1;
			u[i] := 0;
			INC(i)
		END;
		a[i] := 2 * b[i - 1] + hn; d[i] := dn + d0; u[i] := 1;

		i := 0;
		WHILE i < n - 2 DO
			c[i] := c[i]/a[i];
			a[i + 1] := a[i + 1] - c[i] * b[i];
			INC(i)
		END;
		i := 1;
		WHILE i < n - 1 DO
			t1 := c[i - 1];
			t2 := t1 * d[i - 1];
			d[i] := d[i] - t2;
			t2 := t1 * u[i - 1];
			u[i] := u[i] - t2;
			INC(i)
		END;
		d[n - 2] := d[n - 2]/a[n - 2];
		u[n - 2] := u[n - 2]/a[n - 2];
		i := n - 3;
		WHILE i >= 0 DO
			t1 := b[i] * d[i + 1];
			d[i] := (d[i] - t1)/a[i];
			t1 := b[i] * u[i + 1];
			u[i] := (u[i] - t1)/a[i];
			DEC(i)
		END;

		d0 := (d[0] + d[n - 2])/(u[0] + u[n - 2] + x[n - 1] - x[n - 2]);
		i := 0;
		WHILE i < n - 1 DO
			d[i] := d[i] - d0 * u[i];
			INC(i)
		END;
		d[n - 1] := d[0]
	END SolveClosed;

	PROCEDURE Solve (n: LONGINT; VAR x, y, d: ARRAY OF REAL);
		VAR a, b, c: ARRAY MaxSplinePoints OF REAL; d0, d1, t: REAL; i: LONGINT;
	BEGIN
		b[0] := 1/(x[1] - x[0]); a[0] := 2*b[0]; c[0] := b[0];
		d0 := 3 * (y[1] - y[0]) * b[0] * b[0]; d[0] := d0;
		i := 1;
		WHILE i < n - 1 DO
			b[i] := 1/(x[i + 1] - x[i]); a[i] := 2 * (c[i - 1] + b[i]); c[i] := b[i];
			d1 := 3 * (y[i + 1] - y[i]) * b[i] * b[i]; d[i] := d0 + d1; d0 := d1;
			INC(i)
		END;
		a[i] := 2 * b[i - 1]; d[i] := d0;

		i := 0;
		WHILE i < n - 1 DO
			c[i] := c[i]/a[i];
			a[i + 1] := a[i + 1] - c[i] * b[i];
			INC(i)
		END;
		i := 1;
		WHILE i < n DO
			t := c[i - 1] * d[i - 1];
			d[i] := d[i] - t;
			INC(i)
		END;
		d[n - 1] := d[n - 1]/a[n - 1];
		i := n - 2;
		WHILE i >= 0 DO
			t := b[i] * d[i + 1];
			d[i] := (d[i] - t)/a[i];
			DEC(i)
		END
	END Solve;

	(** enumerate natural spline as sequence of path elements; current point must be in (data.x, data.y) **)
	PROCEDURE EnumSpline* (VAR x, y: ARRAY OF REAL; n: LONGINT; closed: BOOLEAN; enum: Enumerator; VAR data: EnumData);
		VAR s, xp, yp: ARRAY MaxSplinePoints OF REAL; i: LONGINT; dx, dy, ds, ds2, bx, by, t: REAL;
	BEGIN
		ASSERT((n >= 2) & (n <= MaxSplinePoints));
		ASSERT(~closed OR (x[0] = x[n - 1]) & (y[0] = y[n - 1]));
		IF ~closed & (n = 2) THEN
			data.elem := Line; data.x := x[1]; data.y := y[1]; enum(data)
		ELSIF closed & (n = 3) THEN
			data.elem := Arc; data.x0 := 0.5*(x[0] + x[1]); data.y0 := 0.5*(y[0] + y[1]); data.x1 := x[0]; data.y1 := y[0];
			data.x2 := data.x0 + (data.y0 - data.y); data.y2 := data.y0 + (data.x - data.x0); enum(data)
		ELSE
			(* use arc length for parametrizing the spline *)
			s[0] := 0.0;
			i := 1;
			WHILE i < n DO
				dx := x[i] - x[i - 1]; dy := y[i] - y[i - 1];
				s[i] := s[i - 1] + Math.sqrt(dx * dx + dy * dy) + 0.01;	(* make sure s[i] > s[i - 1] *)
				INC(i)
			END;

			(* calculate derivatives *)
			IF closed THEN
				SolveClosed(n, s, x, xp);
				SolveClosed(n, s, y, yp)
			ELSE
				Solve(n, s, x, xp);
				Solve(n, s, y, yp)
			END;
			data.elem := Bezier;
			i := 1;
			WHILE i < n DO
				ds := 1.0/(s[i] - s[i - 1]); ds2 := ds * ds;
				dx := ds * (x[i] - x[i - 1]);
				dy := ds * (y[i] - y[i - 1]);
				bx := ds * (3*dx - 2*xp[i - 1] - xp[i]);
				by := ds * (3*dy - 2*yp[i - 1] - yp[i]);
				t := 1/ds;
				data.x1 := x[i - 1] + (1/3)*xp[i - 1]*t;
				data.y1 := y[i - 1] + (1/3)*yp[i - 1]*t;
				t := 1/ds2;
				data.x2 := 2*data.x1 - x[i - 1] + (1/3) * bx * t;
				data.y2 := 2*data.y1 - y[i - 1] + (1/3) * by * t;
				data.x := x[i]; data.y := y[i];
				enum(data);
				INC(i)
			END
		END
	END EnumSpline;


	(**--- Path Queries ---**)

	PROCEDURE Code (VAR data: QueryData; x, y: REAL): SET;
		VAR code: SET;
	BEGIN
		code := {};
		IF x < data.llx THEN INCL(code, Left)
		ELSIF x > data.urx THEN INCL(code, Right)
		END;
		IF y < data.lly THEN INCL(code, Bottom)
		ELSIF y > data.ury THEN INCL(code, Top)
		END;
		RETURN code
	END Code;

	PROCEDURE EnumQuery (VAR data: EnumData);
		VAR x, y: REAL; code, cc: SET;
	BEGIN
		(*
			The procedure uses a simplified version of the Cohen-Sutherland clipping algorithm. The endpoint of
			the current line is consecutively clipped against all sides of the rectangle until both points of the line
			are outside the rectangle with respect to one single rectangle border or until the clipped endpoint
			is inside the rectangle.
		*)
		WITH data: QueryData DO
			IF ~data.hit THEN
				IF data.elem = Enter THEN
					data.code := Code(data, data.x, data.y);
					IF data.code = {} THEN	(* point inside rectangle *)
						data.hit := TRUE
					ELSE
						data.sx := data.x; data.sy := data.y
					END
				ELSIF (data.elem = Line) & ((data.x # data.sx) OR (data.y # data.sy)) THEN
					x := data.x; y := data.y;
					LOOP
						code := Code(data, x, y);
						IF code = {} THEN	(* point inside rectangle *)
							data.hit := TRUE;
							EXIT
						END;
						cc := data.code * code;
						IF cc # {} THEN	(* no intersection with rectangle *)
							IF data.thorough THEN
								(*
									For every line crossing the rectangle's middle y coordinate, accumulate how often the rectangle's
									midpoint lies to the left/right of the line
								*)
								y := 0.5*(data.lly + data.ury);
								IF (data.sy <= y) & (y < data.y) OR (data.y <= y) & (y < data.sy) THEN
									x := 0.5*(data.llx + data.urx);
									IF (data.x - data.sx) * (y - data.sy) >= (data.y - data.sy) * (x - data.sx) THEN
										INC(data.sum)
									ELSE
										DEC(data.sum)
									END
								END
							END;
							data.code := Code(data, data.x, data.y); data.sx := data.x; data.sy := data.y;
							EXIT
						END;
						IF Left IN code THEN
							y := data.sy + (y - data.sy) * (data.llx - data.sx)/(x - data.sx);
							x := data.llx
						ELSIF Right IN code THEN
							y := data.sy + (y - data.sy) * (data.urx - data.sx)/(x - data.sx);
							x := data.urx
						ELSIF Bottom IN code THEN
							x := data.sx + (x - data.sx) * (data.lly - data.sy)/(y - data.sy);
							y := data.lly
						ELSE	(* Top IN code *)
							x := data.sx + (x - data.sx) * (data.ury - data.sy)/(y - data.sy);
							y := data.ury
						END
					END
				END
			END
		END
	END EnumQuery;

	PROCEDURE EnumBoxElem (VAR data: EnumData);
	BEGIN
		WITH data: QueryData DO
			IF data.elem IN {Enter, Line} THEN
				IF data.x < data.llx THEN data.llx := data.x END;
				IF data.x > data.urx THEN data.urx := data.x END;
				IF data.y < data.lly THEN data.lly := data.y END;
				IF data.y > data.ury THEN data.ury := data.y END
			END
		END
	END EnumBoxElem;

	(** calculate bounding box of path **)
	PROCEDURE GetBox* (path: Path; VAR llx, lly, urx, ury: REAL); (**DEPRECATED -- SVGRenderer *)
	BEGIN
		path.GetBox(llx, lly, urx, ury);
	END GetBox;

	(** calculate line length **)
	PROCEDURE LineLength* (x0, y0, x1, y1: REAL): REAL;
		VAR dx, dy: REAL;
	BEGIN
		dx := x1 - x0; dy := y1 - y0;
		RETURN Math.sqrt(dx * dx + dy * dy)
	END LineLength;

	PROCEDURE EnumLength (VAR data: EnumData);
		VAR dx, dy: REAL;
	BEGIN
		WITH data: LengthData DO
			IF data.elem = Line THEN
				dx := data.x - data.sx; dy := data.y - data.sy;
				data.len := data.len + Math.sqrt(dx * dx + dy * dy)
			END;
			data.sx := data.x; data.sy := data.y
		END
	END EnumLength;

	(** calculate arc length **)
	PROCEDURE ArcLength* (sx, sy, ex, ey, x0, y0, x1, y1, x2, y2, flatness: REAL): REAL;
		VAR data: LengthData;
	BEGIN
		data.x := sx; data.y := sy; data.sx := sx; data.sy := sy; data.len := 0;
		EnumArc(x0, y0, x1, y1, x2, y2, ex, ey, flatness, EnumLength, data);
		RETURN data.len
	END ArcLength;

	(** calculate bezier length **)
	PROCEDURE BezierLength* (x0, y0, x1, y1, x2, y2, x3, y3, flatness: REAL): REAL;
		VAR data: LengthData;
	BEGIN
		data.x := x0; data.y := y0; data.sx := x0; data.sy := y0; data.len := 0;
		EnumBezier(x1, y1, x2, y2, x3, y3, flatness, EnumLength, data);
		RETURN data.len
	END BezierLength;


	(**--- Path Operations ---**)

	(** apply transformation to all coordinates in path **)
	PROCEDURE Apply* (path: Path; VAR mat: GfxMatrix.Matrix); (**DEPRECATED -- Used in SVGRenderer *)
	BEGIN
		path.Apply(mat);
	END Apply;

	PROCEDURE GetDir (VAR data: EnumData);
	BEGIN
		WITH data: DirData DO
			IF (data.sdx = 0) & (data.sdy = 0) THEN
				data.sdx := data.x - data.cx; data.sdy := data.y - data.cy
			END;
			data.edx := data.x - data.cx; data.edy := data.y - data.cy;
			data.cx := data.x; data.cy := data.y
		END
	END GetDir;

	PROCEDURE EnumSplit (VAR data: EnumData);
		VAR dx, dy, d, s, sx, sy: REAL;
	BEGIN
		WITH data: SplitData DO
			CASE data.elem OF
			| Enter:
				IF data.offset > 0 THEN data.head.AddEnter(data.x, data.y, data.dx, data.dy)
				ELSE data.tail.AddEnter(data.x, data.y, data.dx, data.dy)
				END;
				data.sx := data.x; data.sy := data.y
			| Line:
				IF data.offset > 0 THEN	(* still appending to head *)
					dx := data.x - data.sx; dy := data.y - data.sy; d := Math.sqrt(dx * dx + dy * dy);
					IF d > 0 THEN
						IF d < data.offset THEN	(* doesn't reach split offset *)
							data.head.AddLine(data.x, data.y);
							data.offset := data.offset - d; data.sx := data.x; data.sy := data.y
						ELSIF d > data.offset THEN	(* split within line *)
							s := data.offset/d;
							sx := data.sx + s * dx; sy := data.sy + s * dy;
							data.head.AddLine(sx, sy); data.head.AddExit(dx, dy);	(* leave head... *)
							data.tail.AddEnter(sx, sy, dx, dy); data.tail.AddLine(data.x, data.y);	(* ...and enter tail *)
							data.offset := data.offset - d	(* now < 0 *)
						ELSE	(* d = offset: delay until next line/exit *)
							data.offset := 0; data.sx := data.x; data.sy := data.y; data.sdx := dx; data.sdy := dy
						END
					END
				ELSIF data.offset < 0 THEN	(* appending to tail *)
					data.tail.AddLine(data.x, data.y)
				ELSE	(* split point at previous line end point *)
					data.head.AddLine(data.sx, data.sy); data.head.AddExit(dx, dy);	(* leave head... *)
					data.tail.AddEnter(data.sx, data.sy, data.sdx, data.sdy);	(* ...and enter tail *)
					data.tail.AddLine(data.x, data.y);
					data.offset := -1
				END
			| Exit:
				IF data.offset > 0 THEN data.head.AddExit(data.dx, data.dy)
				ELSIF data.offset < 0 THEN data.tail.AddExit(data.dx, data.dy)
				ELSE data.head.AddLine(data.sx, data.sy); data.head.AddExit(data.dx, data.dy); data.offset := -1
				END
			END
		END
	END EnumSplit;

	(**--- Geometry Support ---**)

	(** compute intersection of two lines **)
	PROCEDURE IntersectLines* (x1, y1, dx1, dy1, x2, y2, dx2, dy2: REAL; VAR x, y: REAL);
		VAR d, t: REAL;
	BEGIN
		d := dx1 * dy2 - dy1 * dx2;
		t := (x2 - x1) * dy2 - (y2 - y1) * dx2;
		IF (ABS(d) >= 1) OR (ABS(d) * MAX(REAL) >= ABS(t)) THEN
			t := t/d;
			x := x1 + t * dx1; y := y1 + t * dy1
		ELSE
			x := 0.5*(x2 - x1); y := 0.5*(y2 - y1)
		END
	END IntersectLines;

	(** compute intersection(s) of line with circle; returns number of solutions in nsol **)
	PROCEDURE IntersectLineCircle* (sx, sy, tx, ty, mx, my, r: REAL; VAR x1, y1, x2, y2: REAL; VAR nsol: LONGINT);
		VAR dx, dy, cx, cy, a2, b, c, d, t: REAL;
	BEGIN
		dx := tx - sx; dy := ty - sy;
		cx := sx - mx; cy := sy - my;
		a2 := 2 * (dx * dx + dy * dy);
		b := 2 * (dx * cx + dy * cy);
		c := cx * cx + cy * cy - r * r;
		d := b * b - 2 * a2 * c;
		IF d < 0 THEN
			nsol := 0
		ELSE
			d := Math.sqrt(d);
			IF (d >= b) & (d - b <= a2) THEN
				t := (d - b)/a2;
				x1 := sx + t * dx; y1 := sy + t * dy;
				IF (b + d <= 0) & (b + d >= -a2) THEN
					t := (b + d)/a2;
					x2 := sx - t * dx; y2 := sy - t * dy;
					nsol := 2
				ELSE
					nsol := 1
				END
			ELSIF (b + d <= 0) & (b + d >= -a2) THEN
				t := (b + d)/a2;
				x2 := sx - t * dx; y2 := sy - t * dy;
				nsol := 1
			END
		END
	END IntersectLineCircle;

	(** return projection of point onto line **)
	PROCEDURE ProjectToLine* (px, py, qx, qy, x, y: REAL; VAR u, v: REAL);
		VAR vx, vy, vv, wx, wy, w, d: REAL;
	BEGIN
		vx := qx - px; vy := qy - py;
		vv := vx * vx + vy * vy;
		wx := x - px; wy := y - py;
		w := wx * vx + wy * vy;
		IF (vv >= 1) OR (vv * MAX(REAL) >= ABS(w)) THEN
			d := w/vv;
			u := px + d * vx; v := py + d * vy
		ELSE
			u := px; v := py
		END
	END ProjectToLine;

	(** return projection of point onto ellipse at origin **)
	PROCEDURE ProjectToEllipse* (ax, ay, bx, by, x, y: REAL; VAR u, v: REAL);
		VAR a, sina, cosa, b, shear, l: REAL;
	BEGIN
		IF ABS(ax * by - ay * bx) < 1.0E-10 THEN
			u := 0.0; v := 0.0
		ELSE	(* find parameters to rotate, shear and scale ellipse to unit circle *)
			a := Math.sqrt(ax * ax + ay * ay);
			sina := ay/a; cosa := ax/a;
			b := cosa * by - sina * bx;
			shear := (cosa * bx + sina * by)/b;
			v := cosa * y - sina * x;
			u := (cosa * x + sina * y - shear * v)/a;
			v := v/b;
			l := Math.sqrt(u * u + v * v);
			u := u/l; v := v/l;

			(* map u, v back to original coordinates *)
			y := v * b;
			x := u * a + shear * y;
			u := cosa * x - sina * y;
			v := sina * x + cosa * y
		END
	END ProjectToEllipse;

	PROCEDURE EnumProject (VAR data: EnumData);
		VAR x, y, dx, dy, d:REAL;
	BEGIN
		WITH data: ProjectData DO
			IF data.elem = Enter THEN
				data.sx := data.x; data.sy := data.y
			ELSIF data.elem = Line THEN
				ProjectToLine(data.sx, data.sy, data.x, data.y, data.px, data.py, x, y);
				dx := data.px - x; dy := data.py - y;
				d := dx * dx + dy * dy;
				IF d < data.dist THEN
					dx := data.x - data.sx; dy := data.y - data.sy;
					IF ((x - data.sx) * dx + (y - data.sy) * dy >= 0) & ((data.x - x) * dx + (data.y - y) * dy >= 0) THEN
						data.rx := x; data.ry := y; data.dist := d
					END
				END;
				data.sx := data.x; data.sy := data.y
			END
		END
	END EnumProject;

	(** return projection of point onto path **)
	PROCEDURE ProjectToPath* (path: Path; x, y: REAL; VAR u, v: REAL);
	BEGIN
		path.ProjectTo(x, y, u, v);
	END ProjectToPath;

BEGIN
	Coords[Enter] := 2; Coords[Line] := 1; Coords[Arc] := 4; Coords[Bezier] := 3; Coords[Exit] := 1
END GfxPaths.
