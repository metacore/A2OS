(* ETH Oberon, Copyright 2001 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

(* MakePoints
	Jaco Geldenhuys, jaco@cs.sun.ac.za

	Compute figures, calculate movement (interpolation) points and write
	the data to a file with the following format:

		Data ::= Tag numpoints numfigs maxcoord mincoord { Figure }
		Tag ::= tag version release
		Figure ::= attributes timefactor Points Move
		Points ::= { coordx coordy coordz }
		Move ::= { destpoint }

		attributes is a SET
		maxcoord, mincoord, timefactor are FLOAT32
		all other numbers are INTEGERs

		Figure attributes: 0=no morph
*)

MODULE MakePoints IN Oberon;

IMPORT SYSTEM, M := Math IN A2, Files, Texts, Oberon, Fonts, Display, R := RandomNumbers;

CONST
	versionString = "MakePoints 1.3.2000 / jaco";
	Tag = 9ABH;
	Version = 3;
	MaxPoint = 350;
	MaxFig = 40;
	Filename = "SavePoints.Data";
	Verbose = FALSE;

	(* figure attributes *)
	nomorph = 0;

TYPE
	Point = RECORD x, y, z: FLOAT32 END;
	Figure = ARRAY MaxPoint OF Point;
	Movement = ARRAY MaxPoint OF SIGNED16;
	Pat = POINTER TO RECORD
		w, h: CHAR;
		pixmap: ARRAY 8192 OF CHAR
	END;

VAR
	figure: ARRAY MaxFig OF Figure;	(* figures known to the system *)
	move: ARRAY MaxFig OF Movement;	(* movement between figures *)
	timefactor: ARRAY MaxFig OF FLOAT32;
	attributes: ARRAY MaxFig OF SET;
	curfig, curpoint: SIGNED16;
	min, max: Point;
	w: Texts.Writer;

(* several output routines *)
PROCEDURE Rea(x: FLOAT64; n: SIGNED16);
BEGIN Texts.WriteLongRealFix(w, x, 0, n, 0); Texts.Append(Oberon.Log, w.buf)
END Rea;

PROCEDURE Str(CONST s: ARRAY OF CHAR);
BEGIN Texts.WriteString(w, s); Texts.Append(Oberon.Log, w.buf)
END Str;

PROCEDURE Ch(ch: CHAR);
BEGIN Texts.Write(w, ch); Texts.Append(Oberon.Log, w.buf)
END Ch;

PROCEDURE Ln;
BEGIN Texts.WriteLn(w); Texts.Append(Oberon.Log, w.buf)
END Ln;

PROCEDURE Int(x: SIGNED32; n: SIGNED16);
BEGIN Texts.WriteInt(w, x, n); Texts.Append(Oberon.Log, w.buf)
END Int;

(* prepare for creating another figure *)
PROCEDURE Prepare;
BEGIN
	ASSERT(curfig < MaxFig);
	IF Verbose THEN Ln END;
	min.x := MAX(FLOAT32); min.y := MAX(FLOAT32); min.z := MAX(FLOAT32);
	max.x := MIN(FLOAT32); max.y := MIN(FLOAT32); max.z := MIN(FLOAT32);
	IF ~Verbose & (curfig > 0) & (curfig MOD 20 = 0) THEN Ln; Ch(" ") END;
	Int(curfig, 0); Ch(" ");
	curpoint := 0;
	timefactor[curfig] := 1.0;
	attributes[curfig] := {}
END Prepare;

(* postpare for creating another figure *)
PROCEDURE Postpare;
VAR k: SIGNED16;
BEGIN
	IF Verbose THEN
		Str("pts="); Int(curpoint, 0);
		Str(" x="); Rea(min.x, 2); Str(".."); Rea(max.x, 2);
		Str(" y="); Rea(min.y, 2); Str(".."); Rea(max.y, 2);
		Str(" z="); Rea(min.z, 2); Str(".."); Rea(max.z, 2)
	END;
	k := 0;
	WHILE curpoint < MaxPoint DO
		figure[curfig, curpoint] := figure[curfig, k];
		INC(curpoint); INC(k)
	END;
	INC(curfig)
END Postpare;

(* retrieve a previous set point *)
PROCEDURE GetPoint(VAR p: Point; n: SIGNED16);
BEGIN
	ASSERT((n >= 0) & (n < curpoint));
	p := figure[curfig, n]
END GetPoint;

(* set the coordinates for a point *)
PROCEDURE SetPoint(VAR p: Point; x, y, z: FLOAT32);
BEGIN
	p.x := x; p.y := y; p.z := z
END SetPoint;

(* set the coordinates for the next point *)
PROCEDURE Set(x, y, z: FLOAT32);
BEGIN
	ASSERT((curpoint >= 0) & (curpoint < MaxPoint));
	IF Verbose THEN
		IF x < min.x THEN min.x := x END;
		IF y < min.y THEN min.y := y END;
		IF z < min.z THEN min.z := z END;
		IF x > max.x THEN max.x := x END;
		IF y > max.y THEN max.y := y END;
		IF z > max.z THEN max.z := z END
	END;
	SetPoint(figure[curfig, curpoint], x, y, z);
	INC(curpoint)
END Set;

(* change the current figure's timefactor *)
PROCEDURE SetTimeFactor(t: FLOAT32);
BEGIN
	timefactor[curfig] := t
END SetTimeFactor;

(* change the current figure's attributes *)
PROCEDURE SetAttributes(s: SET);
BEGIN
	attributes[curfig] := s
END SetAttributes;

(* interpolate between f and t using proportion p *)
PROCEDURE From(f, t, p: FLOAT32): FLOAT32;
BEGIN
	RETURN f * p + t * (1.0 - p)
END From;

(* rotate the two coordinates x, y with the given factors c, s *)
PROCEDURE Rotate(c, s: FLOAT32; VAR x, y: FLOAT32);
VAR t: FLOAT32;
BEGIN
	t := x * s + y * c;
	x := x * c - y * s;
	y := t
END Rotate;

(* calculate distance between two points *)
PROCEDURE DistanceSqr(p1, p2: Point): FLOAT32;
VAR dx, dy, dz: FLOAT32;
BEGIN
	dx := p1.x - p2.x; dy := p1.y - p2.y; dz := p1.z - p2.z;
	RETURN dx * dx + dy * dy + dz * dz
END DistanceSqr;

(* calculate movement between figures using a distance matrix.  this method uses O(MaxPoint^2) time
	and memory. unfort this method is slower and gives the same results as the other method!
PROCEDURE InitMovement;
VAR dist: POINTER TO ARRAY MaxPoint, MaxPoint OF FLOAT32; rowmin: POINTER TO ARRAY MaxPoint OF FLOAT32;
	cur, nxt, n, p, q, r, c: SIGNED16; min: FLOAT32;
BEGIN
	Str("interpolating: ");
	NEW(dist); NEW(rowmin);
	FOR cur := 0 TO curfig - 1 DO
		IF (cur > 0) & (cur MOD 20 = 0) THEN Ln END; Int(cur, 0); Ch(" ");
		nxt := (cur + curfig - 1) MOD curfig;
		(* setup the maxtrix *)
		FOR p := 0 TO MaxPoint - 1 DO
			rowmin[p] := MAX(FLOAT32);
			FOR q := 0 TO MaxPoint - 1 DO
				dist[p, q] := DistanceSqr(figure[cur, p], figure[nxt, q]);
				IF dist[p, q] < rowmin[p] THEN rowmin[p] := dist[p, q] END
			END
		END;
		(* now MaxPoint times find the minimum matrix element *)
		FOR n := 0 TO MaxPoint - 1 DO
			min := MAX(FLOAT32);
			FOR p := 0 TO MaxPoint - 1 DO
				IF rowmin[p] < min THEN
					FOR q := 0 TO MaxPoint - 1 DO
						IF dist[p, q] < min THEN min := dist[p, q]; r := p; c := q END
					END
				END
			END;
			move[cur, c] := r;
			rowmin[r] := MAX(FLOAT32);
			FOR p := 0 TO MaxPoint - 1 DO
				dist[r, p] := MAX(FLOAT32);
				IF dist[p, c] = rowmin[p] THEN
					dist[p, c] := MAX(FLOAT32);
					FOR q := 0 TO MaxPoint - 1 DO
						IF dist[p, q] < rowmin[p] THEN rowmin[p] := dist[p, q] END
					END
				ELSE dist[p, c] := MAX(FLOAT32)
				END
			END
		END
	END;
	Ln
END InitMovement;
*)

(* calculate movement between figures *)
PROCEDURE InitMovement;
VAR f, g, p, q, r: SIGNED16; d: FLOAT32; dist: ARRAY MaxPoint OF FLOAT32;
	 done, taken: ARRAY MaxPoint OF BOOLEAN; fav: ARRAY MaxPoint OF SIGNED16;
BEGIN
	Str("interpolating:");
	FOR f := 0 TO curfig - 1 DO
		IF Verbose OR (f > 0) & (f MOD 20 = 0) THEN Ln END;
		g := (f + curfig - 1) MOD curfig;
		IF ~(nomorph IN attributes[g]) THEN Ch(" "); Int(f, 0);
			FOR p := 0 TO MaxPoint - 1 DO
				done[p] := FALSE;
				taken[p] := FALSE
			END;
			(* calculate favourite points *)
			FOR p := 0 TO MaxPoint - 1 DO
				dist[p] := MAX(FLOAT32);
				FOR q := 0 TO MaxPoint - 1 DO
					d := DistanceSqr(figure[f, p], figure[g, q]);
					IF d < dist[p] THEN fav[p] := q; dist[p] := d END
				END
			END;
			(* calculate the movement array *)
			FOR p := 0 TO MaxPoint - 1 DO
				IF Verbose & (p MOD 10 = 0) THEN Ch(".") END;
				(* select the point closest to its favourite *)
				d := MAX(FLOAT32);
				FOR q := 0 TO MaxPoint - 1 DO
					IF (~done[q]) & (dist[q] < d) THEN d := dist[q]; r := q END
				END;
				(* allow it to move to its favourite *)
				move[f, fav[r]] := r;
				done[r] := TRUE;
				taken[fav[r]] := TRUE;
				(* recalculate distances that have changed *)
				FOR r := 0 TO MaxPoint - 1 DO
					IF (~done[r]) & taken[fav[r]] THEN
						dist[r] := MAX(FLOAT32);
						FOR q := 0 TO MaxPoint - 1 DO
							IF ~taken[q] THEN
								d := DistanceSqr(figure[f, r], figure[g, q]);
								IF d < dist[r] THEN fav[r] := q; dist[r] := d END
							END
						END
					END
				END
			END
		ELSE Ch("-"); Int(f, 0)
		END
	END;
	Ln
END InitMovement;

(* set up the sphere figure *)
PROCEDURE Sphere;
CONST radius = 0.8;
VAR a, b, cos, sin: FLOAT32;
BEGIN
	Set(radius, 0, 0); Set(-radius, 0, 0);
	Set(0, radius, 0); Set(0, -radius, 0);
	Set(0, 0, radius); Set(0, 0, -radius);
	a := 0.0;
	b := M.pi / ((MaxPoint - 6) DIV 6);
	WHILE a < M.pi - 0.01 DO
		cos := radius * M.cos(a + b / 2.0);
		sin := radius * M.sin(a + b / 2.0);
		Set(cos, sin, 0); Set(-cos, -sin, 0);
		Set(0, sin, cos); Set(0, -sin, -cos);
		Set(sin, 0, cos); Set(-sin, 0, -cos);
		a := a + b
	END
END Sphere;

(* set up the torus figure *)
PROCEDURE Torus;
CONST small = 7; large = MaxPoint DIV small; sradius = 0.09; lradius = 0.8;
VAR a, cos, sin: FLOAT32; k, m: SIGNED16; p: Point;
BEGIN
	FOR k := 0 TO small - 1 DO
		a := M.pi / (small / 2.0) * k;
		Set(sradius * M.cos(a), lradius + sradius * M.sin(a), 0)
	END;
	FOR k := 1 TO large - 1 DO
		cos := M.cos(M.pi / (large / 2.0) * k);
		sin := M.sin(M.pi / (large / 2.0) * k);
		FOR m := 0 TO small - 1 DO
			GetPoint(p, m);
			Set(p.x, p.y * cos - p.z * sin, p.y * sin + p.z * cos)
		END
	END
END Torus;

(* set up the cylinder figure *)
PROCEDURE Cylinder;
CONST radius = 0.3; left = -0.9; right = 0.9; size = 15; length = MaxPoint DIV size;
VAR a: FLOAT32; k, m: SIGNED16; p: Point;
BEGIN
	FOR k := 0 TO size - 1 DO
		a := M.pi / (size / 2.0) * k;
		Set(left, radius * M.sin(a), radius * M.cos(a))
	END;
	FOR k := 1 TO length - 1 DO
		a := 1.0 * k / (length - 1);
		FOR m := 0 TO size - 1 DO
			GetPoint(p, m);
			Set(From(left, right, a), p.y, p.z)
		END
	END
END Cylinder;

(* set up the cube figure *)
PROCEDURE Cube;
VAR w: FLOAT32; k, x, y, z: SIGNED16;
BEGIN
	k := 2; WHILE k*k*k < MaxPoint DO INC(k) END; DEC(k);
	w := k - 1.0;
	FOR x := 0 TO k-1 DO
		FOR y := 0 TO k-1 DO
			FOR z := 0 TO k-1 DO
				Set((x / w) - 0.5, (y / w) - 0.5, (z / w) - 0.5)
			END
		END
	END
END Cube;

(* set up the box figure *)
PROCEDURE Box;
CONST t = 0.507; u = 0.5;
VAR w, v: FLOAT32; m, n: SIGNED16;
BEGIN
	Set(t, t, t); Set(t, t, -t);
	Set(t, -t, t); Set(t, -t, -t);
	Set(-t, t, t); Set(-t, t, -t);
	Set(-t, -t, t); Set(-t, -t, -t);
	m := (MaxPoint - 8) DIV 12;
	w := -u / m;
	FOR n := 0 TO m - 1 DO
		v := 1.0 * n / m;
		Set(w + From(-u, u, v), u, u); Set(w + From(-u, u, v), u, -u);
		Set(w + From(-u, u, v), -u, u); Set(w + From(-u, u, v), -u, -u);
		Set(u, w + From(-u, u, v), u); Set(u, w + From(-u, u, v), -u);
		Set(-u, w + From(-u, u, v), u); Set(-u, w + From(-u, u, v), -u);
		Set(u, u, w + From(-u, u, v)); Set(u, -u, w + From(-u, u, v));
		Set(-u, u, w + From(-u, u, v)); Set(-u, -u, w + From(-u, u, v))
	END
END Box;

(* set up the spiral figure *)
PROCEDURE Spiral;
CONST spirals = 4; radius = 0.8;
VAR d, a, dd, aa: FLOAT32; k: SIGNED16;
BEGIN
	d := radius / MaxPoint;
	a := spirals * 2.0 * M.pi / MaxPoint;
	dd := 0.0; aa := 0;
	FOR k := 0 TO MaxPoint - 1 DO
		Set(dd * M.cos(aa), dd * M.sin(aa), radius / 2.0 - dd);
		dd := dd + d;
		aa := aa + a
	END
END Spiral;

(* set up the milky way galaxy figure *)
PROCEDURE Milky;
CONST Size = 0.6; Height = 0.1; Twist = 4 * M.pi; Var = 0.05;
	Centre = 0.15; CentreSize = 0.07 * Size; Earth = 0.06; EarthDist = 0.8 * Size; EarthSize = 0.08 * Size;
VAR k, m: SIGNED32; a, e: FLOAT32; p: Point;
BEGIN
	m := (ENTIER(MaxPoint * Centre));
	FOR k := 0 TO m - 1 DO
		SetPoint(p, R.Uniform() * CentreSize, 0, 0);
		a := M.pi * (R.Uniform() - 0.5); Rotate(M.cos(a), M.sin(a), p.x, p.y);
		a := M.pi * (R.Uniform() - 0.5); Rotate(M.cos(a), M.sin(a), p.y, p.z);
		a := M.pi * (R.Uniform() - 0.5); Rotate(M.cos(a), M.sin(a), p.z, p.x);
		Set(p.x, p.y, p.z)
	END;
	m := (ENTIER(MaxPoint * Earth)) DIV 3;
	FOR k := 0 TO m - 1 DO
		e := EarthSize * (k / (m - 1.0) - 0.5);
		Set(EarthDist + e, 0, 0);
		Set(EarthDist, e, 0);
		Set(EarthDist, 0, e)
	END;
	m := MaxPoint - curpoint;
	FOR k := 0 TO m - 1 DO
		e := R.Uniform();
		a := M.pi * From(0, Twist, e);
		p.x := Size * e + Var * R.Uniform();
		p.y := Var * R.Uniform();
		p.z := (1 - e) * (1 - e) * (0.5 * Height + Var * R.Uniform());
		IF R.Uniform() > 0.5 THEN p.z := -p.z END;
		Rotate(M.cos(a), M.sin(a), p.x, p.y);
		Set(p.x, p.y, p.z)
	END
END Milky;

(* set up the plane figure *)
PROCEDURE Plane;
CONST w = 1.4; h = 1.4;
VAR m, x, y: SIGNED16; v: FLOAT32;
BEGIN
	m := SHORT(ENTIER(M.sqrt(MaxPoint)));
	v := m - 1.0;
	FOR x := 0 TO m - 1 DO
		FOR y := 0 TO m - 1 DO
			Set((x / v) * w - w / 2.0, (y / v) * h - h / 2.0, 0)
		END
	END
END Plane;

(* set up the cone figure *)
PROCEDURE Eiffel;
CONST w = 3.0; h = 3.0; d = 2.8; b = 0.35;
VAR m, x, y: SIGNED16; xx, yy, a, v: FLOAT32;
BEGIN
	m := SHORT(ENTIER(M.sqrt(MaxPoint)));
	v := m - 1.0;
	FOR x := 0 TO m - 1 DO
		xx := From(-0.5, 0.5, x / v);
		FOR y := 0 TO m - 1 DO
			yy := From(-0.5, 0.5, y / v);
			a := M.sqrt(xx * xx + yy * yy);
			Set(a * xx * w * 0.5, a * yy * h * 0.5, d * (b - a))
		END
	END
END Eiffel;

(* set up the trigsurface figure *)
PROCEDURE TrigSurface;
CONST w = 1.4; h = 1.4; c = 0.15; b = 0.02;
VAR m, x, y: SIGNED16; u, v, p, q: FLOAT32;
BEGIN
	m := SHORT(ENTIER(M.sqrt(MaxPoint)));
	v := m - 1.0;
	u := 2.0 * m - 2.0;
	FOR x := 0 TO m - 1 DO
		FOR y := 0 TO m - 1 DO
			p := 0.5 * M.pi + 3 * M.pi * ((x + y) / u);
			q := 0.5 * M.pi + 3 * M.pi * ((x + v - y) / u);
			Set((x / v) * w - w / 2.0, (y / v) * h - h / 2.0, (M.cos(p) + M.cos(q)) * c + b)
		END
	END
END TrigSurface;

(* set up the mobius figure *)
PROCEDURE Mobius;
CONST band = 4; strips = MaxPoint DIV band; width = 0.3; radius = 1.5;
	from = M.pi * 0.15; to = M.pi * 0.85; range = to - from;
VAR m, n: SIGNED16; a, b, c, w, cos, sin: FLOAT32; p: ARRAY band OF Point;
BEGIN
	w := band - 1.0;
	b := 2.0 * M.pi / strips;
	a := 0;
	FOR m := 0 TO strips - 1 DO
		FOR n := 0 TO band - 1 DO
			SetPoint(p[n], From(-width / 2.0, width / 2.0, n / w), 0, 0)
		END;
		IF (a >= from) & (a <= to) THEN
			c := From(0, M.pi, (a - from) / range);
			cos := M.cos(c); sin := M.sin(c);
			FOR n := 0 TO band - 1 DO
				Rotate(cos, sin, p[n].z, p[n].x)
			END
		END;
		cos := M.cos(a); sin := M.sin(a);
		FOR n := 0 TO band - 1 DO
			p[n].z := p[n].z - radius / 2.0;
			Rotate(cos, sin, p[n].y, p[n].z);
			Set(p[n].x, p[n].y, p[n].z)
		END;
		a := a + b
	END
END Mobius;

(* set up the dumbbell figure *)
PROCEDURE Dumbbell;
CONST one = 27; half = (one - 1) DIV 2; two = MaxPoint DIV one; w = 0.8; h = 0.4;
	x0 = 0.0000; xa = 0.6250; xb = 0.7083; xc = 0.8750; xd = 1.000;
	y0 = 0.3333; ya = 0.2500; yb = 0.9000; yc = 0.9000; yd = 0.1667;
VAR m, n, na, nb, nc, nd: SIGNED16; v, cos, sin, d0, da, db, dc, dd: FLOAT32; p: Point;
BEGIN
	da := M.sqrt((xa - x0) * (xa - x0) + (ya - y0) * (ya - y0));
	db := M.sqrt((xb - xa) * (xb - xa) + (yb - ya) * (yb - ya));
	dc := M.sqrt((xc - xb) * (xc - xb) + (yc - yb) * (yc - yb));
	dd := M.sqrt((xd - xc) * (xd - xc) + (yd - yc) * (yd - yc));
	d0 := da + db + dc + dd;
	na := SHORT(ENTIER(half * da / d0 + 0.5));
	nb := SHORT(ENTIER(half * db / d0));
	(*-nc := SHORT(ENTIER(half * dc / d0));-*)
	nd := SHORT(ENTIER(half * dd / d0));
	nc := half - na - nb - nd;
	FOR n := 0 TO na - 1 DO v := n / (na - 1.0); Set(w * From(x0, xa, v), h * From(y0, ya, v), 0) END;
	FOR n := 0 TO nb - 1 DO v := n / (nb - 1.0); Set(w * From(xa, xb, v), h * From(ya, yb, v), 0) END;
	FOR n := 0 TO nc - 1 DO v := n / (nc - 1.0); Set(w * From(xb, xc, v), h * From(yb, yc, v), 0) END;
	FOR n := 0 TO nd - 1 DO v := n / (nd - 1.0); Set(w * From(xc, xd, v), h * From(yc, yd, v), 0) END;
	FOR n := 1 TO half - 1 DO
		GetPoint(p, half - n);
		Set(-p.x, p.y, p.z)
	END;
	FOR n := 1 TO two - 1 DO
		v := From(0, 2.0 * M.pi, n / (1.0 * two));
		cos := M.cos(v); sin := M.sin(v);
		FOR m := 0 TO one - 1 DO
			GetPoint(p, m);
			Rotate(cos, sin, p.y, p.z);
			Set(p.x, p.y, p.z)
		END
	END
END Dumbbell;

(* set up the small ball figure *)
PROCEDURE Ball1;
CONST radius = 0.6; pack = 0.25;
VAR n: SIGNED16; a, b, c, t, u, v, w: FLOAT32; p: Point;
BEGIN
	a := 0.001; b := M.pi * radius;
	WHILE b - a > 0.01 DO
		c := (a + b) / 2.0;
		t := c / radius; u := t; n := 2;
		WHILE u < M.pi DO
			n := n + SHORT(ENTIER(2.0 * M.pi * radius * M.sin(u) / (pack * c)));
			u := u + t
		END;
		IF n > MaxPoint - 2 THEN a := c ELSE b := c END
	END;
	c := b + b - a;
	Set(radius, 0, 0);
	Set(-radius, 0, 0);
	t := c / radius; u := t;
	WHILE u < M.pi DO
		v := (pack * c) / (radius * M.sin(u)); w := 0;
		WHILE w < 2.0 * M.pi DO
			SetPoint(p, radius * M.cos(u), 0, radius * M.sin(u));
			Rotate(M.cos(w), M.sin(w), p.y, p.z);
			Set(p.x, p.y, p.z);
			w := w + v
		END;
		u := u + t
	END
END Ball1;

(* set up the large ball figure *)
PROCEDURE Ball2;
CONST radius = 0.99; pack = 1.25;
VAR n: SIGNED16; a, b, c, t, u, v, w: FLOAT32; p: Point;
BEGIN
	a := 0.001; b := M.pi * radius;
	WHILE b - a > 0.01 DO
		c := (a + b) / 2.0;
		t := c / radius; u := t; n := 2;
		WHILE u < M.pi DO
			n := n + SHORT(ENTIER(2.0 * M.pi * radius * M.sin(u) / (pack * c)));
			u := u + t
		END;
		IF n > MaxPoint - 2 THEN a := c ELSE b := c END
	END;
	c := b + b - a;
	Set(0, radius, 0);
	Set(0, -radius, 0);
	t := c / radius; u := t;
	WHILE u < M.pi DO
		v := (pack * c) / (radius * M.sin(u)); w := 0;
		WHILE w < 2.0 * M.pi DO
			SetPoint(p, radius * M.sin(u), radius * M.cos(u), 0);
			Rotate(M.cos(w), M.sin(w), p.z, p.x);
			Set(p.x, p.y, p.z);
			w := w + v
		END;
		u := u + t
	END
END Ball2;

(* set up the cross figure *)
PROCEDURE Cross;
CONST width = 0.9; diam = 0.05;
VAR k, m: SIGNED16; v: FLOAT32;
BEGIN
	Set(width, 0, 0); Set(-width, 0, 0);
	Set(0, width, 0); Set(0, -width, 0);
	Set(0, 0, width); Set(0, 0, -width);
	m := (MaxPoint - 6) DIV 12;
	FOR k := 0 TO m - 1 DO
		v := k / (m - 1.0);
		Set(From(-width, width, v), diam, diam); Set(From(-width, width, v), diam, -diam);
		Set(From(-width, width, v), -diam, diam); Set(From(-width, width, v), -diam, -diam);
		Set(diam, From(-width, width, v), diam); Set(diam, From(-width, width, v), -diam);
		Set(-diam, From(-width, width, v), diam); Set(-diam, From(-width, width, v), -diam);
		Set(diam, diam, From(-width, width, v)); Set(diam, -diam, From(-width, width, v));
		Set(-diam, diam, From(-width, width, v)); Set(-diam, -diam, From(-width, width, v))
	END
END Cross;

(* set up the helix figure *)
PROCEDURE Helix;
CONST width = 1.1; breadth = 0.24; links = 11; acid = 7; twist = 1.7 * M.pi;
VAR m, n, y: SIGNED16; x, a, cos, sin, db: FLOAT32; p: Point;
BEGIN
	db := 2.0 * breadth / (acid + 1.0);
	FOR n := 1 TO links DO
		x := From(-width, width, n / (links + 1.0));
		a := From(0, twist, (x - width) / (2 * width));
		cos := M.cos(a); sin := M.sin(a);
		FOR y := 1 TO acid DO
			SetPoint(p, 0, y * db - breadth, 0);
			Rotate(cos, sin, p.y, p.z);
			p.x := x + 0.01; Set(p.x, p.y, p.z);
			p.x := x - 0.01; Set(p.x, p.y, p.z)
		END
	END;
	m := (MaxPoint -  links * 2 * acid) DIV 2;
	FOR n := 0 TO m - 1 DO
		x := From(-width, width, n / (m - 1.0));
		a := From(0, twist, (x - width) / (2 * width));
		cos := M.cos(a); sin := M.sin(a);
		SetPoint(p, x, breadth, 0);
		Rotate(cos, sin, p.y, p.z);
		Set(p.x, p.y, p.z);
		SetPoint(p, x, -breadth, 0);
		Rotate(cos, sin, p.y, p.z);
		Set(p.x, p.y, p.z)
	END
END Helix;

(* set up the key figure *)
PROCEDURE Key;
CONST crad = 0.38; cx = 0.4 + crad; clrad = 0.2;
VAR m, k: SIGNED16; from, to, angle, circlet, circ, dist, u, v, t, d, e: FLOAT32; q: ARRAY 13 OF Point;

	PROCEDURE Stack(x, y: FLOAT32);
	VAR i: SIGNED16;
	BEGIN
		FOR i := 0 TO 4 DO
			Set(x, y, From(-0.04, 0.04, i / 4.0))
		END
	END Stack;

BEGIN
	dist := 0.0;
	q[0].x := -0.4402; q[0].y := -0.1500;
	q[1].x := 0.2424; q[1].y := -0.1500; q[2].x := 0.9250; q[2].y := -0.1500;
	q[3].x := 1.0000; q[3].y := 0.0000; q[4].x := 0.9250; q[4].y := 0.1500;
	q[5].x := 0.7813; q[5].y := 0.2000; q[6].x := 0.7187; q[6].y := 0.0750;
	q[7].x := 0.6000; q[7].y := 0.2210; q[8].x := 0.4000; q[8].y := 0.0600;
	q[9].x := 0.1250; q[9].y := 0.2500; q[10].x := -0.1100; q[10].y := 0.0600;
	q[11].x := -0.2000; q[11].y := 0.1500; q[12].x := -0.4402; q[12].y := 0.1500;
	FOR k := 1 TO 12 DO
		u := q[k].x - q[k - 1].x;
		v := q[k].y - q[k - 1].y;
		q[k].z := M.sqrt(u * u + v * v);
		dist := dist + q[k].z
	END;
	from := M.arctan(0.15 / (crad - 0.0402)) / M.pi; to := 2 - from;
	circ := crad * (to - from) * M.pi;
	circlet := clrad * (2.0 * M.pi);
	dist := dist + circ + circlet;
	m := (MaxPoint - 81) DIV 2; d := dist / m;
	e := d * 0.5;
	Stack(q[0].x, q[0].y);
	FOR k := 1 TO 12 DO
		Stack(q[k].x, q[k].y);
		WHILE e < q[k].z DO
			t := From(0.0, 1.0, e / q[k].z);
			Set(From(q[k - 1].x, q[k].x, t), From(q[k - 1].y, q[k].y, t), 0.04);
			Set(From(q[k - 1].x, q[k].x, t), From(q[k - 1].y, q[k].y, t), -0.04);
			e := e + d
		END;
		e := e - q[k].z
	END;
	WHILE e < circ DO
		t := From(0.0, 1.0, e / circ);
		angle := From(M.pi * from, M.pi * to, t);
		u := crad * M.cos(angle) - cx; v := crad * M.sin(angle);
		Set(u, v, 0.04); Set(u, v, -0.04);
		e := e + d
	END;
	e := 0;
	WHILE e < circlet DO
		t := From(0.0, 1.0, e / circlet);
		angle := From(0, M.pi * 2.0, t);
		u := clrad * M.cos(angle) - cx; v := clrad * M.sin(angle);
		Set(u, v, 0.04); Set(u, v, -0.04);
		e := e + d
	END;
	Stack(-cx, -crad); Stack(-cx, crad); Stack(-(0.4 + 2 * crad), 0.0)
END Key;

(* set up the venus figure *)
PROCEDURE Venus;
CONST radius = 0.38; len = 0.6; width = 0.05; cross = 0.30;
VAR m, n: SIGNED16; dist, d, a, b: FLOAT32; p: Point;
BEGIN
	m := (MaxPoint - 3) DIV 3;
	dist := 2 * (M.pi * (2 * radius - width) + len + cross * 2);
	d := dist / m;
	a := d / radius; b := a * 0.5;
	WHILE b < 2 * M.pi DO
		Set(radius * M.sin(b), radius * (1.0 - M.cos(b)), 0);
		b := b + a
	END;
	a := d / (radius - width); b := a * 0.5;
	WHILE b < 2 * M.pi DO
		Set((radius - width) * M.sin(b), radius - (radius - width) * M.cos(b), 0);
		b := b + a
	END;
	b := d * 0.5;
	WHILE b < len DO
		b := b + d;
		Set(width * 0.5, d * 0.5 - b, 0); Set(-width * 0.5, d * 0.5 - b, 0)
	END;
	b := width * 0.5;
	WHILE b < cross DO
		Set(b, width * 0.5 - len * 0.566, 0);
		Set(b, -width * 0.5 - len * 0.566, 0);
		Set(-b, width * 0.5 - len * 0.566, 0);
		Set(-b, -width * 0.5 - len * 0.566, 0);
		b := b + d
	END;
	FOR n := 0 TO m - 1 DO
		GetPoint(p, n);
		p.z := width * 0.5; Set(p.x, p.y, p.z);
		p.z := -width * 0.5; Set(p.x, p.y, p.z)
	END;
	WHILE curpoint < MaxPoint DO Set(0, -len, 0) END
END Venus;

(* set up the mars figure *)
PROCEDURE Mars;
CONST radius = 0.38; len = 0.6; width = 0.05; arrow = 0.30; angle = 0.23 * M.pi;
VAR k, m, n: SIGNED16; cos, sin, dist, d, a, b: FLOAT32; p: Point; pp: ARRAY (MaxPoint DIV 3) OF Point;
BEGIN
	m := (MaxPoint - 3) DIV 3;
	dist := 2 * (M.pi * (2 * radius - width) + len + arrow * 2);
	d := dist / m;
	a := d / radius; b := a * 0.5;
	WHILE b < 2 * M.pi DO
		Set(radius * M.sin(b), radius * (1.0 - M.cos(b)), 0);
		b := b + a
	END;
	a := d / (radius - width); b := a * 0.5;
	WHILE b < 2 * M.pi DO
		Set((radius - width) * M.sin(b), radius - (radius - width) * M.cos(b), 0);
		b := b + a
	END;
	b := d * 0.5;
	WHILE b < len DO
		b := b + d;
		Set(width * 0.5, d * 0.5 - b, 0); Set(-width * 0.5, d * 0.5 - b, 0)
	END;
	dist := b - d * 1.5;
	cos := M.cos(angle); sin := M.sin(angle);
	k := 0; b := width * 0.5;
	WHILE b < arrow DO
		SetPoint(pp[k], 0, b - width * 0.5, 0); Rotate(cos, sin, pp[k].x, pp[k].y); INC(k);
		SetPoint(pp[k], -width, b - width * 0.5, 0); Rotate(cos, sin, pp[k].x, pp[k].y); INC(k);
		b := b + d
	END;
	FOR n := 0 TO k - 1 DO
		IF pp[n].x <= 0 THEN
			pp[n].x := -pp[n].x + width * 0.5;
			pp[n].y := pp[n].y - dist;
			Set(pp[n].x, pp[n].y, pp[n].z);
			pp[n].x := -pp[n].x;
			Set(pp[n].x, pp[n].y, pp[n].z)
		END
	END;
	FOR n := 0 TO m - 1 DO
		GetPoint(p, n);
		p.z := width * 0.5; Set(p.x, p.y, p.z);
		p.z := -width * 0.5; Set(p.x, p.y, p.z)
	END;
	WHILE curpoint < MaxPoint DO Set(0, -len, 0) END
END Mars;

(* set up the text figure *)
PROCEDURE Text(CONST font, text: ARRAY OF CHAR);
CONST width = 1.8; maxheight = 1.6;
VAR m, n, p, dx, x, y, w, h, x0, count, totalw, totalh, pixels, max, min, dot, times: SIGNED16;
	pattern: Display.Pattern; pat: Pat; s: SET; adr: ADDRESS; len: SIGNED32; f: Fonts.Font;
	pixelw, pixeld, woff, hoff: FLOAT32;

	PROCEDURE Pixel(x, y: SIGNED16);
	VAR xx, yy: FLOAT32; g, h, i: SIGNED16;
	BEGIN
		xx := pixelw * x; yy := pixelw * y;
		FOR g := 0 TO pixels - 1 DO
			FOR h := 0 TO pixels - 1 DO
				FOR i := 0 TO times - 1 DO
					Set(xx + g * pixeld - woff, yy + h * pixeld - hoff, 0.02 * i);
				END
			END
		END;
		FOR g := 0 TO dot - 1 DO
			Set(xx + 0.5 * (pixelw - pixeld) - woff, yy + 0.5 * (pixelw - pixeld) - hoff, 0)
		END
	END Pixel;

BEGIN
	f := Fonts.This(font);
	IF f = NIL THEN f := Fonts.Default END;
	totalw := 0; count := 0; max := 0; min := 0;
	m := 0;
	WHILE text[m]# 0X DO
		Fonts.GetChar(f, text[m], dx, x, y, w, h, pattern); pat := SYSTEM.VAL(Pat, pattern);
		IF y < min THEN min := y END;
		IF y + h > max THEN max := y + h END;
		adr := ADDRESSOF(pat.pixmap[0]); len := (w+7) DIV 8;
		FOR n := 0 TO h - 1 DO
			SYSTEM.MOVE(adr, ADDRESSOF(s), len); INC(adr, len);
			FOR p := 0 TO w - 1 DO
				IF p IN s THEN INC(count) END
			END
		END;
		totalw := totalw + dx; INC(m)
	END;
	totalw := totalw - dx + x + w; totalh := max - min;
	pixelw := width / totalw;
	IF totalh * pixelw > maxheight THEN pixelw := maxheight / totalh END;
	woff := 0.5 * totalw * pixelw; hoff := 0.5 * totalh * pixelw;
	m := MaxPoint DIV count; pixels := SHORT(ENTIER(M.sqrt(m)));
	IF pixels = 0 THEN HALT(99) (* too many pixels: shorten string *) END;
	times := m DIV (pixels * pixels); dot := m - times * pixels * pixels;
	pixeld := pixelw / pixels;
	x0 := 0; m := 0;
	WHILE text[m]# 0X DO
		Fonts.GetChar(f, text[m], dx, x, y, w, h, pattern); pat := SYSTEM.VAL(Pat, pattern);
		adr := ADDRESSOF(pat.pixmap[0]); len := (w+7) DIV 8;
		FOR n := 0 TO h - 1 DO
			SYSTEM.MOVE(adr, ADDRESSOF(s), len); INC(adr, len);
			FOR p := 0 TO w - 1 DO
				IF p IN s THEN Pixel(x0 + x + p, y + n - min) END
			END
		END;
		x0 := x0 + dx; INC(m)
	END
END Text;

(* set up the pyramid figure *)
PROCEDURE Pyramid(n: SIGNED16);
CONST d = 0.15; h = 0.15;
VAR x, y, x0, y0: FLOAT32; k, p, q: SIGNED16;
BEGIN
	x := 0; y := n * h * 0.5;
	x0 := x; y0 := y;
	FOR k := 1 TO n DO
		IF (k > 1) THEN
			Set(x + d * 0.1667, x + d * 0.1667, y + h * 0.3333);
			Set(x + d * 0.3333, x + d * 0.3333, y + h * 0.6667);
			Set(x + d * 0.1667, x + d * (k - 1.1667), y + h * 0.3333);
			Set(x + d * 0.3333, x + d * (k - 1.3333), y + h * 0.6667);
			Set(x + d * (k - 1.1667), x + d * 0.1667, y + h * 0.3333);
			Set(x + d * (k - 1.3333), x + d * 0.3333, y + h * 0.6667);
			Set(x + d * (k - 1.1667), x + d * (k - 1.1667), y + h * 0.3333);
			Set(x + d * (k - 1.3333), x + d * (k - 1.3333), y + h * 0.6667)
		END;
		FOR p := 0 TO k - 1 DO
			FOR q := 0 TO k - 1 DO
				Set(x + q * d, x + p * d, y)
			END;
		END;
		x := x - d * 0.5; y := y - h
	END;
	y := y + h;
	FOR p := 1 TO k - 2 DO
		Set(x + d * (p - 0.1667), x + d * 0.5, y);
		Set(x + d * (p + 0.1667), x + d * 0.5, y);
		Set(x + d * 0.5, x + d * (p - 0.1667), y);
		Set(x + d * 0.5, x + d * (p + 0.1667), y);
		Set(x + d * (p - 0.1667), x + d * (k - 1.5), y);
		Set(x + d * (p + 0.1667), x + d * (k - 1.5), y);
		Set(x + d * (k - 1.5), x + d * (p - 0.1667), y);
		Set(x + d * (k - 1.5), x + d * (p + 0.1667), y)
	END;
	WHILE curpoint < MaxPoint DO Set(x0, x0, y0) END
END Pyramid;

(* set up the hypercube figure *)
PROCEDURE Hypercube;
CONST inner = 0.3; outer = 0.5;
VAR diag, dist, d, e, f: FLOAT32;
BEGIN
	Set(inner, inner, inner); Set(inner, inner, -inner);
	Set(inner, -inner, inner); Set(inner, -inner, -inner);
	Set(-inner, inner, inner); Set(-inner, inner, -inner);
	Set(-inner, -inner, inner); Set(-inner, -inner, -inner);
	Set(outer, outer, outer); Set(outer, outer, -outer);
	Set(outer, -outer, outer); Set(outer, -outer, -outer);
	Set(-outer, outer, outer); Set(-outer, outer, -outer);
	Set(-outer, -outer, outer); Set(-outer, -outer, -outer);
	diag := M.sqrt(3 * (outer - inner) * (outer - inner));
	dist := 24 * (outer + inner + 0.5 * diag);
	d := dist / (MaxPoint - 16);
	e := d - outer;
	WHILE e < outer DO
		Set(e, outer, outer); Set(e, outer, -outer); Set(e, -outer, outer); Set(e, -outer, -outer);
		Set(outer, e, outer); Set(outer, e, -outer); Set(-outer, e, outer); Set(-outer, e, -outer);
		Set(outer, outer, e); Set(outer, -outer, e); Set(-outer, outer, e); Set(-outer, -outer, e);
		e := e + d
	END;
	e := d - inner;
	WHILE e < inner DO
		Set(e, inner, inner); Set(e, inner, -inner); Set(e, -inner, inner); Set(e, -inner, -inner);
		Set(inner, e, inner); Set(inner, e, -inner); Set(-inner, e, inner); Set(-inner, e, -inner);
		Set(inner, inner, e); Set(inner, -inner, e); Set(-inner, inner, e); Set(-inner, -inner, e);
		e := e + d
	END;
	e := d;
	WHILE e < diag DO
		f := From(inner, outer, e / diag);
		Set(f, f, f); Set(f, f, -f); Set(f, -f, f); Set(f, -f, -f);
		Set(-f, f, f); Set(-f, f, -f); Set(-f, -f, f); Set(-f, -f, -f);
		e := e + d
	END
END Hypercube;

(* set up the mug figure *)
PROCEDURE Mug;
CONST bottom = 5; side = 12; ear = 3; dots = side + bottom - 1; dist = 0.09; earbend = 0.92;
	radius = bottom * dist; height = side * dist; earrad = ear * dist;
VAR p: ARRAY dots OF Point; k, n, rots: SIGNED16; a, b, cos, sin: FLOAT32;
BEGIN
	SetPoint(p[0], earrad, 0, -dist * 0.5); SetPoint(p[1], earrad + dist, 0, -dist * 0.5);
	SetPoint(p[2], earrad, 0, dist * 0.5); SetPoint(p[3], earrad + dist, 0, dist * 0.5);
	a := dist / (earbend * earrad); b := 0;
	FOR k := 0 TO 3 DO
		Set(p[k].x - dist * 0.5, earbend * p[k].y + radius + dist * 0.7, p[k].z)
	END;
	WHILE b < M.pi DO
		cos := M.cos(a); sin := M.sin(a);
		FOR k := 0 TO 3 DO
			Rotate(cos, sin, p[k].x, p[k].y);
			Set(p[k].x - dist * 0.5, earbend * p[k].y + radius + dist * 0.7, p[k].z)
		END;
		b := b + a
	END;
	FOR k := 0 TO side - 1 DO
		SetPoint(p[k], k * dist - height * 0.5, radius, 0)
	END;
	FOR k := 1 TO bottom - 1 DO
		SetPoint(p[side - 1 + k], -height * 0.5, k * dist,  0)
	END;
	rots := (MaxPoint - curpoint) DIV dots;
	cos := M.cos(2 * M.pi / rots); sin := M.sin(2 * M.pi / rots);
	FOR k := 0 TO rots - 1 DO
		FOR n := 0 TO dots - 1 DO
			Rotate(cos, sin, p[n].y, p[n].z);
			Set(p[n].x, p[n].y, p[n].z)
		END
	END
END Mug;

(* set up the eggs figure *)
PROCEDURE Eggs;
CONST N = 5; R = 7; W = 1.9; A = 0.12; B = 0.19; Q = MaxPoint DIV N; P = Q DIV R;
VAR p: ARRAY Q OF Point; k, m: SIGNED16; a, cos, sin: FLOAT32;
BEGIN
	a := M.pi / P;
	FOR m := 0 TO P - 1 DO
		SetPoint(p[m], A * M.sin(m * a + a / 2), B * M.cos(m * a + a / 2), 0)
	END;
	FOR k := 1 TO R - 1 DO
		cos := M.cos(k * 2 * M.pi / R); sin := M.sin(k * 2 * M.pi / R);
		FOR m := 0 TO P - 1 DO
			p[k * P + m] := p[m];
			Rotate(cos, sin, p[k * P + m].z, p[k * P + m].x)
		END
	END;
	FOR k := 0 TO N - 1 DO
		a := k / (N - 1.0);
		FOR m := 0 TO Q - 1 DO
			Set(p[m].x + From(-0.5 * W, 0.5 * W, a), p[m].y, p[m].z)
		END
	END
END Eggs;

(* set up the South African flag figure *)
PROCEDURE ZAFlag;
CONST b = 0; bb = 0.04; w = 1.7; wr = 2 / 3; tr = 18; hr = 3; xhr = 4; h = w * wr; xoff = -0.5 * w; yoff = -0.5 * h;
VAR t, tt, hh, h1, d3, d4, d5, dist, d: FLOAT32; xy1, xh1, xd1, xy2, xh2, xd2: FLOAT32;

	PROCEDURE Stripe(xfrom, xto, yfrom, yto, dst: FLOAT32);
	VAR e, x, y, z: FLOAT32;
	BEGIN e := 0;
		WHILE e < dst DO
			x := From(xfrom, xto, e / dst);
			y := From(yfrom, yto, e / dst);
			z := b * M.sin(x / w * 1.5 * M.pi);
			Set(xoff + x, yoff + y + z, z);
			e := e + d
		END
	END Stripe;

BEGIN
	hh := h / 2;
	t := h / tr; tt := t / 2;
	h1 := h / hr - tt;
	d3 := M.sqrt(2 * (h / hr + tt) * (h / hr + tt));
	d4 := M.sqrt(2 * (h / hr - tt) * (h / hr - tt));
	d5 := w - 2 * h / hr;
	xh1 := h / xhr - tt;
	xh2 := h / xhr + tt;
	xy1 := hh - xh1;
	xy2 := hh - xh2;
	xd1 := M.sqrt(2 * xy1 * xy1);
	xd2 := M.sqrt(2 * xy2 * xy2);
	dist := 2 * (h + w + xd1 + xd2 + d3 + d4 + 2 * d5);
	d := dist / (MaxPoint - 10);
	Stripe(0, 0, h, 0, h); Stripe(w, w, 0, h, h);
	Stripe(w, 0, 0, 0, w); Stripe(0, w, h, h, w);
	Stripe(0, xy1, xh1, hh, xd1); Stripe(0, xy1, h - xh1, hh, xd1);
	Stripe(0, xy2, xh2, hh, xd2); Stripe(0, xy2, h - xh2, hh, xd2);
	Stripe(w, h1 * 2, h1 - tt, h1 - tt, d5); Stripe(w, h1 * 2, h1 + tt, h1 + tt, d5);
	Stripe(w, h1 * 2, h - h1 - tt, h - h1 - tt, d5); Stripe(w, h1 * 2, h - h1 + tt, h - h1 + tt, d5);
	Stripe(h1 * 2, h1 + tt, h1 - tt, 0, d4); Stripe(h1 * 2, h1 + tt, h - h1 + tt, h, d4);
	Stripe(h1 * 2, h1 - tt, h1 + tt, 0, d3); Stripe(h1 * 2, h1 - tt, h - h1 - tt, h, d3)
END ZAFlag;

(* set up n components of the pc figure *)
PROCEDURE Component(n: SIGNED16);
CONST S = 0.8 / 3.5; Lines = 40;
VAR nlines, k: SIGNED16; dist, d, e, f: FLOAT32; src, dst: ARRAY Lines OF Point;
	limit, box, keyb, screen: SIGNED16;

	PROCEDURE Line(x0, y0, z0, x1, y1, z1: FLOAT32);
	BEGIN
		src[nlines].x := x0; src[nlines].y := y0; src[nlines].z := z0;
		dst[nlines].x := x1; dst[nlines].y := y1; dst[nlines].z := z1;
		INC(nlines)
	END Line;

	PROCEDURE Lineto(x, y, z: FLOAT32);
	BEGIN
		src[nlines] := dst[nlines - 1];
		dst[nlines].x := x; dst[nlines].y := y; dst[nlines].z := z;
		INC(nlines)
	END Lineto;

BEGIN
	nlines := 0;
	(* box *)
	Line(-2, -1, -2, 2, -1, -2); Lineto(2, 3, -2); Lineto(-2, 3, -2); Lineto(-2, -1, -2);
	Line(-2, -1, -1, 2, -1, -1); Lineto(2, 3, -1); Lineto(-2, 3, -1); Lineto(-2, -1, -1);
	Line(-2, -1, -2, -2, -1, -1); Line(  2, -1, -2,   2, -1, -1);
	Line(  2,   3, -2,   2,   3, -1); Line(-2,   3, -2, -2,   3, -1);
	box := nlines;
	(* keyboard *)
	Line(-2, -3.5, -2, 2, -3.5, -2); Lineto(2, -2, -2); Lineto(-2, -2, -2); Lineto(-2, -3.5, -2);
	Line(-2, -3.5, -1.75, 2, -3.5, -1.75); Lineto(2, -2, -1.5); Lineto(-2, -2, -1.5); Lineto(-2, -3.5, -1.75);
	Line(-2, -3.5, -2, -2, -3.5, -1.75); Line(2, -3.5, -2, 2, -3.5, -1.75);
	Line(2, -2, -2, 2, -2, -1.5); Line(-2, -2, -2, -2, -2, -1.5);
	keyb := nlines;
	(* screen *)
	Line(-2, -1, -0.5, 2, -1, -0.5); Lineto(1.25, 3, 0.2); Lineto(-1.25, 3, 0.2); Lineto(-2, -1, -0.5);
	Line(-2, -1, 3.5, 2, -1, 3.5); Lineto(1.25, 3, 2.8); Lineto(-1.25, 3, 2.8); Lineto(-2, -1, 3.5);
	Line(-2, -1, -0.5, -2, -1, 3.5); Line(2, -1, -0.5, 2, -1, 3.5);
	Line(1.25, 3, 0.2, 1.25, 3, 2.8); Line(-1.25, 3, 0.2, -1.25, 3, 2.8);
	Line(-1.5, -1, 0, 1.5, -1, 0); Lineto(1.5, -1, 3); Lineto(-1.5, -1, 3); Lineto(-1.5, -1, 0);
	screen := nlines;

	dist := 0;
	FOR k := 0 TO nlines - 1 DO dist := dist + M.sqrt(DistanceSqr(src[k], dst[k])) END;
	d := dist / (MaxPoint - nlines DIV 3 - 10);
	CASE n OF
	| 0: limit := box
	| 1: limit := keyb
	| 2: limit := screen
	ELSE limit := nlines
	END;
	FOR k := 0 TO limit - 1 DO
		e := d / 2; f := M.sqrt(DistanceSqr(src[k], dst[k]));
		WHILE e < f DO
			Set(S * From(src[k].x, dst[k].x, e / f), S * From(src[k].y, dst[k].y, e / f), S * From(src[k].z, dst[k].z, e / f));
			e := e + d
		END
	END;
	IF n > 2 THEN
		limit := (MaxPoint - curpoint) DIV 2;
		e := 2 * M.pi / limit;
		FOR k := 0 TO limit - 1 DO
			Set(S * (3 + 0.25 * M.cos(k * e)), S * (-2 + 0.5 * M.sin(k * e)), -S * 2);
			Set(S * (3 + 0.25 * M.cos(k * e)), S * (-2 + 0.5 * M.sin(k * e)), -S * 1.7)
		END
	END
END Component;

(* set up the PC figure *)
PROCEDURE PC;
BEGIN
	Component(0); SetTimeFactor(0.17); SetAttributes({nomorph}); Postpare; Prepare;
	Component(1); SetTimeFactor(0.17); SetAttributes({nomorph}); Postpare; Prepare;
	Component(2); SetTimeFactor(0.17); SetAttributes({nomorph}); Postpare; Prepare;
	Component(3)
END PC;

(* initialise a set of pyramid figures *)
PROCEDURE Pyramids;
BEGIN
	Pyramid(3); SetTimeFactor(0.25); Postpare; Prepare;
	Pyramid(5); SetTimeFactor(0.25); Postpare; Prepare;
	Pyramid(7); SetTimeFactor(0.6)
END Pyramids;

(* initialise several figures to form a countdown *)
PROCEDURE Countdown;
BEGIN
	Text("Oberon24.Scn.Fnt", "5"); SetTimeFactor(0.18); SetAttributes({nomorph}); Postpare; Prepare;
	Text("Oberon24.Scn.Fnt", "4"); SetTimeFactor(0.09); SetAttributes({nomorph}); Postpare; Prepare;
	Text("Oberon24.Scn.Fnt", "3"); SetTimeFactor(0.09); SetAttributes({nomorph}); Postpare; Prepare;
	Text("Oberon24.Scn.Fnt", "2"); SetTimeFactor(0.09); SetAttributes({nomorph}); Postpare; Prepare;
	Text("Oberon24.Scn.Fnt", "1"); SetTimeFactor(0.09)
END Countdown;

(* create a single figure, given its name *)
PROCEDURE MakeFigure(CONST s: ARRAY OF CHAR);
BEGIN
	Prepare;
	IF s = "countdown" THEN Countdown
	ELSIF s = "cube" THEN Cube
	ELSIF s = "pyramids" THEN Pyramids
	ELSIF s = "box" THEN Box
	ELSIF s = "hypercube" THEN Hypercube
	ELSIF s = "milky" THEN Milky
	ELSIF s = "plane" THEN Plane
	ELSIF s = "trigsurface" THEN TrigSurface
	ELSIF s = "eiffel" THEN Eiffel
	ELSIF s = "spiral" THEN Spiral
	ELSIF s = "sphere" THEN Sphere
	ELSIF s = "ball1" THEN Ball1
	ELSIF s = "ball2" THEN Ball2
	ELSIF s = "torus" THEN Torus
	ELSIF s = "cylinder" THEN Cylinder
	ELSIF s = "dumbbell" THEN Dumbbell
	ELSIF s = "pc" THEN PC
	ELSIF s = "mug" THEN Mug
	ELSIF s = "mobius" THEN Mobius
	ELSIF s = "cross" THEN Cross
	ELSIF s = "key" THEN Key
	ELSIF s = "venus" THEN Venus
	ELSIF s = "mars" THEN Mars
	ELSIF s = "eggs" THEN Eggs
	ELSIF s = "helix" THEN Helix
	ELSIF s = "zaflag" THEN ZAFlag
	ELSIF s = "oberon" THEN Text("Courier10.Scn.Fnt", "ETH Oberon")
	ELSIF s = "logo" THEN
		Text("Oberon10.Scn.Fnt", "SavePoints"); SetTimeFactor(0.5); SetAttributes({nomorph});
		Postpare; Prepare; Text("Courier10.Scn.Fnt", "jaco@cs.sun.ac.za"); SetTimeFactor(0.5)
	ELSE Text("Oberon20.Scn.Fnt", "??")
	END;
	Postpare
END MakeFigure;

(* initialise the figures, movement and pointset *)
PROCEDURE DefaultFigures;
BEGIN
	MakeFigure("oberon");
	MakeFigure("countdown"); MakeFigure("cube");
	MakeFigure("box"); MakeFigure("hypercube"); MakeFigure("plane");
	MakeFigure("trigsurface"); MakeFigure("spiral");
	MakeFigure("sphere"); MakeFigure("ball1"); MakeFigure("ball2");
	MakeFigure("torus"); MakeFigure("cylinder"); MakeFigure("dumbbell");
	MakeFigure("pc"); MakeFigure("mug"); MakeFigure("mobius");
	MakeFigure("cross"); MakeFigure("key"); MakeFigure("venus");
	MakeFigure("mars"); MakeFigure("eggs"); MakeFigure("helix");
	MakeFigure("logo")
END DefaultFigures;

(* write the generated figures to disk *)
PROCEDURE WriteData;
VAR f, p: SIGNED16; maxint, minint, max, min, factor: FLOAT32;
	F: Files.File; R: Files.Rider;
BEGIN
	Str("writing "); Str(Filename); Str("   ");
	max := MIN(FLOAT32); min := MAX(FLOAT32);
	FOR f := 0 TO curfig - 1 DO
		FOR p := 0 TO MaxPoint - 1 DO
			IF figure[f, p].x < min THEN min := figure[f, p].x END;
			IF figure[f, p].x > max THEN max := figure[f, p].x END;
			IF figure[f, p].y < min THEN min := figure[f, p].y END;
			IF figure[f, p].y > max THEN max := figure[f, p].y END;
			IF figure[f, p].z < min THEN min := figure[f, p].z END;
			IF figure[f, p].z > max THEN max := figure[f, p].z END
		END
	END;
	maxint := MAX(SIGNED16) - 2.0;
	minint := -maxint;
	factor := (maxint - minint) / (max - min);
	IF Verbose THEN
		Ln; Str("min="); Rea(min, 2); Str(" max="); Rea(max, 2);
		Ln; Str("factor="); Rea(factor, 2);
		Ln; Str("file length=")
	END;
	F := Files.New(Filename);
	IF F # NIL THEN
		Files.Set(R, F, 0);
		Files.WriteInt(R, Tag); Files.WriteInt(R, Version);
		Files.WriteInt(R, MaxPoint); Files.WriteInt(R, curfig);
		Files.WriteReal(R, max); Files.WriteReal(R, min);
		FOR f := 0 TO curfig - 1 DO
			Files.WriteSet(R, attributes[f]);
			Files.WriteReal(R, timefactor[f]);
			FOR p := 0 TO MaxPoint - 1 DO
				Files.WriteInt(R, SHORT(ENTIER(minint + factor * (figure[f, p].x - min))));
				Files.WriteInt(R, SHORT(ENTIER(minint + factor * (figure[f, p].y - min))));
				Files.WriteInt(R, SHORT(ENTIER(minint + factor * (figure[f, p].z - min))));
			END;
			FOR p := 0 TO MaxPoint - 1 DO
				Files.WriteInt(R, move[f, p])
			END
		END;
		Files.Register(F);
		Int(Files.Length(F), 0)
	END;
	Ln
END WriteData;

(* command to generate the default figures *)
PROCEDURE Write*;
VAR S: Texts.Scanner; font: ARRAY 64 OF CHAR;
BEGIN
	COPY("Courier10.Scn.Fnt", font);
	Str("building figures: "); curfig := 0;
	Texts.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos); Texts.Scan(S);
	WHILE S.class = Texts.Name DO
		IF S.s = "text" THEN Texts.Scan(S);
			IF S.class = Texts.String THEN
				Prepare; Text(font, S.s); Postpare
			END
		ELSIF S.s = "font" THEN Texts.Scan(S);
			IF S.class = Texts.String THEN COPY(S.s, font) END
		ELSE MakeFigure(S.s)
		END;
		Texts.Scan(S)
	END;
	IF curfig = 0 THEN DefaultFigures END; Ln;
	InitMovement;
	WriteData;
	Str("done"); Ln
END Write;

BEGIN
	Texts.OpenWriter(w);
	Str(versionString); Ln
END MakePoints.
