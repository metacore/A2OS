MODULE SaveArt IN Oberon;	(* Jaco Geldenhuys *)

IMPORT Out, Display, Display3, RandomNumbers, In, SaveScreen, Modules;

CONST
	versionString = "SaveArt 15.3.2000 / jaco";
	MaxRect = 50;

	minProp = 2; maxProp = 99; defProp = 5;
	minLimit = 10; maxLimit = 200; defLimit = 50;
	minCol = 0; maxCol = 255;

TYPE
	Rect = RECORD
		x1, y1, x2, y2: SIGNED16
	END;

VAR
	W, H: SIGNED16;
	rect: ARRAY MaxRect OF Rect;
	count: SIGNED16;
	prop, limit: SIGNED16;
	cols: ARRAY 8 OF SET;
	col: SIGNED16;
	mask: Display3.Mask;

PROCEDURE Proportion(a, b: SIGNED16): SIGNED16;
VAR t: FLOAT32;
BEGIN
	t := ENTIER(1.5 + RandomNumbers.Uniform() * (prop - 2.0)) / (1.0 * prop);
	RETURN SHORT(ENTIER(a * t + b * (1 - t)))
END Proportion;

PROCEDURE Add(x1, y1, x2, y2: SIGNED16);
BEGIN
	IF count < MaxRect THEN
		rect[count].x1 := x1; rect[count].y1 := y1;
		rect[count].x2 := x2; rect[count].y2 := y2;
		INC(count)
	END
END Add;

PROCEDURE Select(VAR x1, y1, x2, y2: SIGNED16);
VAR x, y, n: SIGNED16;
BEGIN
	x := SHORT(ENTIER(RandomNumbers.Uniform() * W));
	y := SHORT(ENTIER(RandomNumbers.Uniform() * H));
	n := 0;
	WHILE (n < count) & ((rect[n].x1 > x) OR (x >= rect[n].x2) OR (rect[n].y1 > y) OR (y >= rect[n].y2)) DO
		INC(n)
	END;
	IF (n = count) THEN n := SHORT(ENTIER(RandomNumbers.Uniform() * count)) END;
	x1 := rect[n].x1; y1 := rect[n].y1;
	x2 := rect[n].x2; y2 := rect[n].y2;
	DEC(count);
	rect[n] := rect[count]
END Select;

PROCEDURE Reset;
BEGIN
	count := 0;
	Add(0, 0, W, H)
END Reset;

PROCEDURE Start;
BEGIN
	SaveScreen.SetFrameRate(4);
	Reset
END Start;

PROCEDURE Step;
VAR x, y, x1, y1, x2, y2: SIGNED16;
BEGIN
	IF count > 0 THEN
		Select(x1, y1, x2, y2);
		Display3.ReplConst(mask, col, x1, y1, x2 - x1, y2 - y1, Display.replace);
		REPEAT col := (col + 1) MOD 256 UNTIL (col MOD 32) IN cols[col DIV 32];
		x := Proportion(x1, x2); y := Proportion(y1, y2);
		IF (y - y1 >= limit) & (x - x1 >= limit) THEN Add(x1, y1, x, y) END;
		IF (y - y1 >= limit) & (x2 - x >= limit) THEN Add(x, y1, x2, y) END;
		IF (y2 - y >= limit) & (x - x1 >= limit) THEN Add(x1, y, x, y2) END;
		IF (y2 - y >= limit) & (x2 - x >= limit) THEN Add(x, y, x2, y2) END
	ELSE
		Reset
	END
END Step;

PROCEDURE Stop;
END Stop;

PROCEDURE Install*;
VAR name: ARRAY 32 OF CHAR; c, d, n: SIGNED16;
BEGIN
	FOR n := 0 TO 7 DO cols[n] := {} END;
	d := maxCol + 1; In.Open;
	LOOP
		In.Name(name); IF ~In.Done THEN EXIT END;
		In.Int(n); IF ~In.Done THEN EXIT END;
		IF (name = "col") THEN
			c := SaveScreen.Limit(minCol, n, maxCol);
			INCL(cols[c DIV 32], c MOD 32); d := c
		ELSIF (name = "to") THEN
			c := SaveScreen.Limit(minCol, n, maxCol);
			WHILE d <= c DO INCL(cols[d DIV 32], d MOD 32); INC(d) END;
			d := maxCol + 1
		ELSIF (name = "prop") THEN
			prop := SaveScreen.Limit(minProp, n, maxProp);
			d := maxCol + 1
		ELSIF (name = "limit") THEN
			limit := SaveScreen.Limit(minLimit, n, maxLimit);
			d := maxCol + 1
		END
	END;
	d := 0;
	FOR n := 0 TO 7 DO
		IF cols[n] # {} THEN INC(d) END
	END;
	IF d = 0 THEN
		FOR n := 0 TO 7 DO cols[n] := {0..31} END
	END;
	REPEAT col := (col + 1) MOD 256 UNTIL (col MOD 32) IN cols[col DIV 32];
	SaveScreen.InstallFader(Start, Step, Stop)
END Install;

PROCEDURE Remove;
BEGIN SaveScreen.RemoveFader(Start, Step, Stop)
END Remove;

PROCEDURE Configuration*;
VAR first: BOOLEAN; k, n: SIGNED16;
BEGIN
	Out.String("SaveArt: "); Out.Ln;
	Out.String("    prop "); Out.Int(prop, 0); Out.Ln;
	Out.String("    limit "); Out.Int(limit, 0); Out.Ln;
	Out.String("    cols {"); first := TRUE; n := 0;
	WHILE n < 256 DO
		IF (n MOD 32) IN cols[n DIV 32] THEN
			k := n + 1;
			WHILE (k < 256) & ((k MOD 32) IN cols[k DIV 32]) DO INC(k) END;
			DEC(k);
			IF ~first THEN Out.String(", ") ELSE first := FALSE END;
			Out.Int(n, 0);
			IF k = n + 1 THEN Out.String(", "); Out.Int(k, 0)
			ELSIF k # n THEN Out.String(".."); Out.Int(k, 0)
			END;
			n := k + 1
		ELSE INC(n)
		END
	END;
	Out.Char("}"); Out.Ln
END Configuration;

PROCEDURE InstallDefault*;
VAR k: SIGNED16;
BEGIN
	prop := defProp;
	limit := defLimit;
	FOR k := 0 TO 7 DO cols[k] := {0..31} END
END InstallDefault;

BEGIN
	W := Display.Width; H := Display.Height;
	Modules.InstallTermHandler(Remove);
	NEW(mask); Display3.Open(mask);
	Display3.Add(mask, 0, 0, Display.Width, Display.Height);
	Out.String(versionString); Out.Ln;
	InstallDefault
END SaveArt.

SaveArt.Install ~
SaveArt.Install col 1 to 14 col 16 to 224 limit 25 prop 90 ~
SaveArt.Install col 0 col 13 to 15 limit 15 prop 10 ~
SaveArt.Install col 16 to 31 col 224 to 239 limit 50 prop 4 ~
SaveArt.Configuration
SaveArt.InstallDefault
SaveScreen.Run
