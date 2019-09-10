(* ETH Oberon, Copyright 2001 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

(* SavePoints
	Jaco Geldenhuys, jaco@cs.sun.ac.za

	See MakePoints.Mod for the input file format.
*)

MODULE SavePoints IN Oberon;

IMPORT Out, In, Modules, SaveScreen, Display, Display3, M := Math IN A2, RandomNumbers, Files, Texts, Oberon, Input;

CONST
	versionString = "SavePoints 1.3.2000 / jaco";
	Tag = 9ABH;
	Version = 3;
	Dist = 10.0;
	ScaleX = 0.8;
	ScaleY = 0.9;
	MinVar = -3 * M.pi; MaxVar = 3 * M.pi;
	MinPeak = (1.5 * M.pi / 180.0);
	MaxPeak = (3.5 * M.pi / 180.0);
	MinDelta = (0.02 * M.pi / 180.0);
	Filename = "SavePoints.Data";
	Time = FALSE;

	(* configurable parameters *)
	minThick = 1;	maxThick = 5;	defThick = 3;
	minDura = 2;	maxDura = 60;	defDura = 20;
	minMorph = 10;	maxMorph = 90;	defMorph = 80;
	minFrames = 1;	maxFrames = 30;	defFrames = 20;

	(* figure attributes *)
	nomorph = 0;

TYPE
	IntPoint = RECORD x, y, z: SIGNED16 END;
	Point = RECORD x, y, z: FLOAT32 END;
	Figure = POINTER TO ARRAY OF Point;
	Control = ARRAY 3 OF Point;
	Rotor = RECORD from, to, curr, peak: FLOAT32 END;
	Colour = RECORD r, g, b: SIGNED16 END;

VAR
	(* info about figures: *)
	numfig: SIGNED16;	(* number of figures *)
	numpoint: SIGNED16;	(* number of points *)
	figure: POINTER TO ARRAY OF ARRAY OF IntPoint;	(* figures known to the system *)
	move: POINTER TO ARRAY OF ARRAY OF SIGNED16;	(* movement between figures *)
	timefactor: POINTER TO ARRAY OF FLOAT32;	(* fraction of time each figure uses *)
	attributes: POINTER TO ARRAY OF SET;	(* figure attributes *)
	maxint, minint, max, min, factor: FLOAT32;	(* details about figure data file needed for figure conversion *)

	(* active info: *)
	curfig: SIGNED16;	(* nr of current figure *)
	actv, curr, next: Figure;	(* active/current/next set of points *)
	control: Control;	(* control points *)
	rx, ry, rz: Rotor;	(* rotation controls *)
	morphoff: BOOLEAN;	(* do we morph from the current figure to the next *)
	timefac: FLOAT32;	(* time factor for current figure *)
	time: FLOAT32;	(* phase timer *)
	step: FLOAT32;	(* phase timer increment *)

	(* active colour info: *)
	coltime: SIGNED16;	(* colour timer *)
	curcol: SIGNED16;	(* current colour of figure *)

	(* configurable parameters: *)
	thick: SIGNED16;	(* how thick are the dots *)
	dura: SIGNED16;	(* how long is a phase (in seconds) *)
	morph: SIGNED16;	(* at what point in the phase do we morph (in %) *)
	frames: SIGNED16;	(* how many frames per second do we display *)

	W, H: SIGNED16;	(* dimensions of display area *)
	mypal, yourpal: ARRAY 256 OF Colour;	(* RGB index of colours *)
	avoid: ARRAY 8 OF SET;	(* which colours to avoid using *)
	numcol: SIGNED16;	(* number of colours available *)
	BG: SIGNED16;	(* colour used to undraw points *)
	mask: Display3.Mask;
	w: Texts.Writer;

(* convert an IntFigure to a Figure *)
PROCEDURE Int2Fig(i: SIGNED16; VAR f: Figure);
VAR p: SIGNED16;
BEGIN
	FOR p := 0 TO numpoint - 1 DO
		f[p].x := min + factor * (figure[i, p].x - minint);
		f[p].y := min + factor * (figure[i, p].y - minint);
		f[p].z := min + factor * (figure[i, p].z - minint)
	END
END Int2Fig;

(* read data from file.  see MakePoints.Mod *)
PROCEDURE ReadData;
VAR F: Files.File; R: Files.Rider; tag, version, f, p: SIGNED16;
BEGIN
	Out.String("reading "); Out.String(Filename);
	F := Files.Old(Filename);
	IF F # NIL THEN
		Files.Set(R, F, 0);
		Files.ReadInt(R, tag);
		Files.ReadInt(R, version);
		IF tag # Tag THEN
			 Out.Ln; Out.String("Data file has wrong format")
		ELSIF version # Version THEN
			Out.Ln; Out.String("Data file has old format")
		ELSE
			Files.ReadInt(R, numpoint);
			Files.ReadInt(R, numfig);
			Files.ReadReal(R, max);
			Files.ReadReal(R, min);
			maxint := MAX(SIGNED16) - 2; minint := -maxint;
			factor := (max - min) / (maxint - minint);
			NEW(figure, numfig, numpoint);
			NEW(move, numfig, numpoint);
			NEW(timefactor, numfig);
			NEW(attributes, numfig);
			FOR f := 0 TO numfig - 1 DO
				Files.ReadSet(R, attributes[f]);
				Files.ReadReal(R, timefactor[f]);
				FOR p := 0 TO numpoint - 1 DO
					Files.ReadInt(R, figure[f, p].x);
					Files.ReadInt(R, figure[f, p].y);
					Files.ReadInt(R, figure[f, p].z)
				END;
				FOR p := 0 TO numpoint - 1 DO Files.ReadInt(R, move[f, p]) END
			END;
			Files.Close(F);
			Out.String(" figs="); Out.Int(numfig, 0);
			Out.String(" pts="); Out.Int(numpoint, 0)
		END
	ELSE
		Out.Ln; Out.String("Cannot open data file")
	END;
	Out.Ln
END ReadData;

(* initialise a rotor *)
PROCEDURE InitRotor(VAR r: Rotor; f, t, p: FLOAT32);
BEGIN
	r.from := f; r.to := t; r.curr := r.from; r.peak := p
END InitRotor;

(* get a palette from the system *)
PROCEDURE GetPal(VAR pal: ARRAY OF Colour);
VAR k: SIGNED16;
BEGIN
	FOR k := 0 TO 255 DO Display.GetColor(k, pal[k].r, pal[k].g, pal[k].b) END
END GetPal;

(* set the system palette *)
PROCEDURE SetPal(VAR pal: ARRAY OF Colour);
VAR k: SIGNED16;
BEGIN
	IF numcol < 256 THEN RETURN END;
	FOR k := 0 TO 255 DO
		IF ~((k MOD 32) IN avoid[k DIV 32]) THEN
			Display.SetColor(k, pal[k].r, pal[k].g, pal[k].b)
		END
	END
END SetPal;

(* clear the bitset that indicates which colours to avoid *)
PROCEDURE ClearAvoid;
VAR k: SIGNED16;
BEGIN
	FOR k := 0 TO 7 DO avoid[k] := {} END
END ClearAvoid;

(* convert from HSV to RGB.  0 < H < 360, 0 < S,V < 1, 0 < R, G, B < 256  *)
PROCEDURE HSV2RGB(H, S, V: FLOAT32; VAR R, G, B: SIGNED16);
VAR f, p, q, t, r, g, b: FLOAT32; i: SIGNED32;
BEGIN
	IF S = 0 THEN r := V; g := V; b := V
	ELSE
		IF H = 360 THEN H := 0 END;
		H := H / 60; i := ENTIER(H);
		f := H - i; p := V * (1 - S);
		q := V * (1 - (S * f)); t := V * (1 - S * (1 - f));
		CASE i OF
		| 0: r := V; g := t; b := p
		| 1: r := q; g := V; b := p
		| 2: r := p; g := V; b := t
		| 3: r := p; g := q; b := V
		| 4: r := t; g := p; b := V
		| 5: r := V; g := p; b := q
		END
	END;
	R := SHORT(ENTIER(255 * r));
	G := SHORT(ENTIER(255 * g));
	B := SHORT(ENTIER(255 * b))
END HSV2RGB;

(* setup the palette *)
PROCEDURE InitColour;
VAR k, n, count: SIGNED16;
BEGIN
	numcol := SIGNED16(ASH(1, Display.Depth(0)));
	IF (numcol = 2) OR (numcol = 16) THEN
		ClearAvoid;
		BG := Display.FG
	ELSE ASSERT(numcol = 256);
		count := 256;
		FOR k := 0 TO 255 DO
			IF (k MOD 32) IN avoid[k DIV 32] THEN DEC(count) END
		END;
		BG := 0;
		WHILE (BG MOD 32) IN avoid[BG DIV 32] DO INC(BG) END;
		mypal[BG].r := 0;
		mypal[BG].g := 0;
		mypal[BG].b := 0;
		DEC(count); n := 0;
		FOR k := 1 TO 255 DO
			IF ~((k MOD 32) IN avoid[k DIV 32]) THEN
				INC(n);
				HSV2RGB(n * 360.0 / count, 1.0, 1.0, mypal[k].r, mypal[k].g, mypal[k].b)
			END
		END
	END;
	curcol := 0;
	WHILE (curcol = BG) OR ((curcol MOD 32) IN avoid[curcol DIV 32]) DO INC(curcol) END
END InitColour;

(* initialise the figures, movement and pointset *)
PROCEDURE InitVars;
BEGIN
	W := Display.Width DIV 2; H := Display.Height DIV 2;
	ClearAvoid; InitColour;
	NEW(actv, numpoint); NEW(curr, numpoint); NEW(next, numpoint);
	Int2Fig(1 MOD numfig, next); Int2Fig(0, actv); Int2Fig(0, curr);
	control[0].x := 1; control[0].y := 0; control[0].z := 0;
	control[1].x := 0; control[1].y := 1; control[1].z := 0;
	control[2].x := 0; control[2].y := 0; control[2].z := 1;
	curfig := 0;
	coltime := 0;
	timefac := timefactor[0];
	morphoff := nomorph IN attributes[0];
	time := 0.0;
	InitRotor(rx, 0.0, M.pi, MinPeak);
	InitRotor(ry, 0.0, M.pi, MinPeak);
	InitRotor(rz, 0.0, M.pi, MinPeak)
END InitVars;

(* rotate the two coordinates x, y with the given factors c, s *)
PROCEDURE Rotate(c, s: FLOAT32; VAR x, y: FLOAT32);
VAR t: FLOAT32;
BEGIN
	t := x * s + y * c;
	x := x * c - y * s;
	y := t
END Rotate;

(* draw the point in the given colour *)
PROCEDURE Draw(VAR p: Point; c: SIGNED16);
VAR d: FLOAT32; x0, y0, x1, y1: SIGNED16;
BEGIN
	d := Dist / (p.z + Dist);
	x0 := SHORT(ENTIER(W + ScaleX * W * d * p.x));
	y0 := SHORT(ENTIER(H + ScaleY * H * d * p.y));
	FOR y1 := 0 TO thick - 1 DO
		FOR x1 := 0 TO thick - 1 DO
			Display3.Dot(mask, c, x0 + x1, y0 + y1, Display3.replace)
		END
	END
END Draw;

(* position the figure according to the control points.  this is the trickest procedure in the program.
	in short, there are three control points that rotate with the figure.  this procedure uses those
	points to figure out the current orientation and rotates the figure accordingly. *)
PROCEDURE Position(VAR F: Figure);
VAR lortnoc: Control; cos, sin: FLOAT32; k, p: SIGNED16; a: ARRAY 4 OF FLOAT32;
	todo: ARRAY 7 OF BOOLEAN;
BEGIN
	(* assume we have to do nothing *)
	FOR k := 0 TO 6 DO todo[k] := FALSE END;
	(* now figure out what we have to do *)
	lortnoc := control;
	IF lortnoc[1].x # 0.0 THEN
		a[0] := M.arctan(lortnoc[1].z / lortnoc[1].x);
		cos := M.cos(a[0]); sin := M.sin(a[0]);
		FOR p := 0 TO 2 DO Rotate(cos, sin, lortnoc[p].z, lortnoc[p].x) END;
		todo[0] := TRUE
	END;
	IF lortnoc[2].z # 0.0 THEN
		a[1] := M.pi + M.arctan(lortnoc[2].y / lortnoc[2].z);
		cos := M.cos(a[1]); sin := M.sin(a[1]);
		FOR p := 0 TO 2 DO Rotate(cos, sin, lortnoc[p].y, lortnoc[p].z) END;
		todo[1] := TRUE
	END;
	IF lortnoc[1].x # 0.0 THEN
		a[2] := M.arctan(lortnoc[1].z / lortnoc[1].x);
		cos := M.cos(a[2]); sin := M.sin(a[2]);
		FOR p := 0 TO 2 DO Rotate(cos, sin, lortnoc[p].z, lortnoc[p].x) END;
		todo[2] := TRUE
	END;
	IF lortnoc[0].x # 0.0 THEN
		a[3] := -M.arctan(lortnoc[0].y / lortnoc[0].x);
		cos := M.cos(a[3]); sin := M.sin(a[3]);
		FOR p := 0 TO 2 DO Rotate(cos, sin, lortnoc[p].x, lortnoc[p].y) END;
		todo[3] := TRUE
	END;
	IF (lortnoc[1].y < 0.0) & (lortnoc[2].z < 0.0) THEN todo[4] := TRUE END;
	IF (lortnoc[0].x < 0.0) & (lortnoc[2].z < 0.0) THEN todo[5] := TRUE END;
	IF (lortnoc[0].x < 0.0) & (lortnoc[1].y < 0.0) THEN todo[6] := TRUE END;
	(* now do it *)
	IF todo[6] THEN
		FOR p := 0 TO numpoint - 1 DO F[p].x := -F[p].x; F[p].y := -F[p].y END
	END;
	IF todo[5] THEN
		FOR p := 0 TO numpoint - 1 DO F[p].x := -F[p].x; F[p].z := -F[p].z END
	END;
	IF todo[4] THEN
		FOR p := 0 TO numpoint - 1 DO F[p].y := -F[p].y; F[p].z := -F[p].z END
	END;
	IF todo[3] THEN
		cos := M.cos(-a[3]); sin := M.sin(-a[3]);
		FOR p := 0 TO numpoint - 1 DO Rotate(cos, sin, F[p].x, F[p].y) END
	END;
	IF todo[2] THEN
		cos := M.cos(-a[2]); sin := M.sin(-a[2]);
		FOR p := 0 TO numpoint - 1 DO Rotate(cos, sin, F[p].z, F[p].x) END
	END;
	IF todo[1] THEN
		cos := M.cos(-a[1]); sin := M.sin(-a[1]);
		FOR p := 0 TO numpoint - 1 DO Rotate(cos, sin, F[p].y, F[p].z) END
	END;
	IF todo[0] THEN
		cos := M.cos(-a[0]); sin := M.sin(-a[0]);
		FOR p := 0 TO numpoint - 1 DO Rotate(cos, sin, F[p].z, F[p].x) END
	END
END Position;

(* start the screensaver *)
PROCEDURE Start;
BEGIN
	GetPal(yourpal);
	SetPal(mypal);
	SaveScreen.SetFrameRate(frames);
	Display.ReplConst(BG, Display.Left, Display.Bottom, Display.Width, Display.Height, Display.replace)
END Start;

(* update the rotation controller r *)
PROCEDURE UpdateRotor(VAR r: Rotor; VAR a: FLOAT32);
VAR v, w, maxpeak: FLOAT32;
BEGIN
	IF ((r.from > r.to) & (r.curr < r.to)) OR (r.curr > r.to) THEN
		r.from := r.to;
		WHILE ABS(r.to - r.from) < 0.0001  DO
			r.to := RandomNumbers.Uniform() * (MaxVar - MinVar) + MinVar + r.from
		END;
		r.curr := r.from; maxpeak := MaxPeak;
		IF ABS(r.to - r.from) > M.pi THEN maxpeak := 2.5 * maxpeak END;
		r.peak := RandomNumbers.Uniform() * (maxpeak - MinPeak) + MinPeak
	END;
	v := 1.0 / (r.to - r.from) * (r.curr - r.from);
	w := 4.0 * (MinDelta - r.peak);
	a := (w * v) * (v - 1.0) + MinDelta;
	IF r.from > r.to THEN a := -a END;
	r.curr := r.curr + a
END UpdateRotor;

(* rotate the figure, draw the points *)
PROCEDURE Step;
VAR pro, orp, a, cx, sx, cy, sy, cz, sz: FLOAT32; p, q, g: SIGNED16; ticks: SIGNED32;
BEGIN
	IF Time THEN ticks := Oberon.Time() END;
	(* update the rotation *)
	UpdateRotor(rx, a); cx := M.cos(a); sx := M.sin(a);
	UpdateRotor(ry, a); cy := M.cos(a); sy := M.sin(a);
	UpdateRotor(rz, a); cz := M.cos(a); sz := M.sin(a);
	(* rotate the contol points *)
	FOR p := 0 TO 2 DO
		Rotate(cz, sz, control[p].x, control[p].y);
		Rotate(cx, sx, control[p].y, control[p].z);
		Rotate(cy, sy, control[p].z, control[p].x)
	END;
	(* rotate the figure *)
	FOR p := 0 TO numpoint - 1 DO
		Rotate(cz, sz, curr[p].x, curr[p].y);
		Rotate(cx, sx, curr[p].y, curr[p].z);
		Rotate(cy, sy, curr[p].z, curr[p].x);
		Rotate(cz, sz, next[p].x, next[p].y);
		Rotate(cx, sx, next[p].y, next[p].z);
		Rotate(cy, sy, next[p].z, next[p].x)
	END;
	(* calculate the mixing proportion *)
	IF (time / timefac <= morph) OR morphoff THEN pro := 0.0
	ELSE pro := (time / timefac - morph) / (100.0 - morph)
	END;
	orp := 1 - pro;
	(* undraw, update & redraw the active points *)
	g := (curfig + 1) MOD numfig;
	FOR p := 0 TO numpoint - 1 DO
		q := move[g, p];
		Draw(actv[p], BG);
		actv[p].x := next[q].x * pro + curr[p].x * orp;
		actv[p].y := next[q].y * pro + curr[p].y * orp;
		actv[p].z := next[q].z * pro + curr[p].z * orp;
		Draw(actv[p], curcol)
	END;
	(* update the phase timer, check if time for next figure *)
	time := time + step;
	IF time / timefac > 100.0 THEN
		curfig := g;
		FOR p := 0 TO numpoint - 1 DO curr[p] := next[p] END;
		Int2Fig((g + 1) MOD numfig, next);
		Position(next);
		timefac := timefactor[curfig];
		morphoff := nomorph IN attributes[curfig];
		time := 0.0;
		IF numcol < 256 THEN
			REPEAT
				curcol := (curcol + 1) MOD numcol
			UNTIL (curcol # BG) & ~((curcol MOD 32) IN avoid[curcol DIV 32])
		END
	END;
	(* update the drawing colour *)
	INC(coltime);
	IF (numcol >= 256) & (2*coltime >= frames) THEN
		REPEAT
			curcol := (curcol + 1) MOD numcol
		UNTIL (curcol # BG) & ~((curcol MOD 32) IN avoid[curcol DIV 32])
	END;
	IF coltime >= frames THEN coltime := 0 END;
	IF Time THEN
		ticks := Oberon.Time() - ticks;
		Texts.WriteInt(w,ticks, 0); Texts.WriteString(w, " ticks = ");
		ticks := (ticks * 100) DIV Input.TimeUnit;
		Texts.WriteInt(w, ticks DIV 100, 0); Texts.Write(w, ".");
		Texts.WriteInt(w, ticks MOD 100, 0); Texts.WriteString(w, " sec");
		Texts.WriteLn(w); Texts.Append(Oberon.Log, w.buf)
	END
END Step;

(* stop the screensaver *)
PROCEDURE Stop;
BEGIN SetPal(yourpal)
END Stop;

(* install the screensaver *)
PROCEDURE Install*;
VAR name: ARRAY 32 OF CHAR; n: SIGNED16;
BEGIN In.Open;
	LOOP
		In.Name(name); IF ~In.Done THEN EXIT END;
		In.Int(n); IF ~In.Done THEN EXIT END;
		IF (name = "thick") THEN
			thick := SaveScreen.Limit(minThick, n, maxThick);
		ELSIF (name = "dura") THEN
			dura := SaveScreen.Limit(minDura, n, maxDura)
		ELSIF (name = "morph") THEN
			morph := SaveScreen.Limit(minMorph, n, maxMorph)
		ELSIF (name = "frames") THEN
			frames := SaveScreen.Limit(minFrames, n, maxFrames)
		ELSIF (name = "avoid") THEN
			IF (n >= 0) & (n <= 255) THEN INCL(avoid[n DIV 32], n MOD 32) END
		END
	END;
	step := 100.0 / (dura * frames);
	InitColour;
	SaveScreen.InstallFader(Start, Step, Stop)
END Install;

(* remove the screensaver *)
PROCEDURE Remove;
BEGIN SaveScreen.RemoveFader(Start, Step, Stop)
END Remove;

(* display the current configuration *)
PROCEDURE Configuration*;
BEGIN
	Out.String("SavePoints: "); Out.Ln;
	Out.String("    thick "); Out.Int(thick, 0); Out.Ln;
	Out.String("    dura "); Out.Int(dura, 0); Out.Ln;
	Out.String("    morph "); Out.Int(morph, 0); Out.Ln;
	Out.String("    frames "); Out.Int(frames, 0); Out.Ln
END Configuration;

(* install the default behaviour *)
PROCEDURE InstallDefault*;
BEGIN
	thick := defThick;
	dura := defDura;
	morph := defMorph;
	frames := defFrames;
	step := 100.0 / (dura * frames)
END InstallDefault;

BEGIN
	Texts.OpenWriter(w);
	Modules.InstallTermHandler(Remove);
	NEW(mask); Display3.Open(mask);
	Display3.Add(mask, 0, 0, Display.Width, Display.Height);
	Out.String(versionString); Out.Ln;
	InstallDefault; ReadData; InitVars
END SavePoints.
