(* ETH Oberon, Copyright 2001 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

(* SaveLife, Conway's Game of Life implemented for SaveScreen
2000.05.30 - 1.0 - inital release
2000.06.09 - 1.5b1 - test release
	- coloring parameter removed (temporarily)
	- faded transition between generations
	- faster screen redraw through the use of a display list
2000.06.13 - 1.5 - release
	- you can specify rgb values for live cells (lonely, normal, crowded) they are specified
	   as long integers, following the parameter. The most readable way to specify them is
	   as a hexadecmimal LONGINT, for example: normal 9A9B9CH where R=9AH, G=9BH,
	   blue=9CH.
*)

MODULE SaveLife IN Oberon;	(* bsm - 2000.05.30 *)

IMPORT
	SYSTEM,	(* SYSTEM.MOVE, ADDRESSOF *)
	In, Out, Display, Pictures, SaveScreen, Math IN A2,
	Oberon, (* Collect *)
	Input, (* Time, TimeUnit *)
	Modules; (* InstallTermHandler *)

CONST
	(* limits for configurable parameters *)
	minCellWidth = 1;	maxCellWidth = 32;	defCellWidth = 8;
	minCellHeight = 1;	maxCellHeight = 32;	defCellHeight = 8;
	minFrameRate = 1;	maxFrameRate = 30;	defFrameRate = 15;
	minFadeSteps = 2;	maxFadeSteps = 26;	defFadeSteps = 8;
	defMvalue = 0.78;
	defTiming = FALSE;

	(* coloring modes *)
	minColoring = 0;	maxColoring = 2;	defColoring = 1;
	blackAndWhiteColoring = 0;
	predictiveColoring = 1;
	resurrectiveColoring = 2;

	(* offscreen modes *)
	minOffscreen = 0; maxOffscreen = 2; defOffscreen = 1;
	neverOffscreen = 0;
	autoOffscreen = 1;
	alwaysOffscreen = 2;

	(* states *)
	makeList = 0;
	drawList = 1;
	update = 2;
	generate = 3;

	(* neighbor offsets for south, north and other directions are variables *)
	ww = -1;	(* offset for western neighbor *)
	ee = 1;	(* offset for easter neighbor *)

	(* when nrGensUnchanged exceeds this, randomize *)
	nrGensUnchangedLimit = 100;
	nrGensUnchangedTolerance = 2;

	(* proportion (0..1) of cells randomized for both initial creation of the
		world, and kickstarting when it has become dormant *)
	creationProportion = 0.12;
	kickstartProportion = 0.05;

	(* for DrawGeneration's parameter all *)
	quick = FALSE;
	all = TRUE;

	(* pseudo colors -- pseudo colors are numbers between 0 and N representing the
		different graphical states that a cell can have.  They can be used as an index to
		a table to retrieve a real color *)
	pseudoDead = 0;
	pseudoCrowded = 1;
	pseudoLonely = 2;
	pseudoNormal = 3;
	numPseudos = 4;

TYPE
	RGB = ARRAY 3 OF INTEGER;
	Fader = ARRAY maxFadeSteps OF INTEGER;
	Generation = POINTER TO ARRAY OF SHORTINT;
	DisplayList = POINTER TO DisplayListDesc;
	DisplayListDesc = RECORD
		next: DisplayList;
		x, y: INTEGER;	(* position *)
		c: Fader;	(* color table indexes *)
	END;

VAR
	savedCmap: ARRAY 256 OF RGB;

	cellWidth, cellHeight: INTEGER;	(* in pixels, of cells drawn to screen *)

	screenWidth, screenHeight: INTEGER;	(* in pixels from Display.Width, Display.Height *)
	xOffset, yOffset: INTEGER;	(* for centering the display incase cellX doesn't divide screenX evenly *)
	cols, rows: INTEGER;	(* # cells across and down on the screen *)

	(* offsets to neighbors in 6 of the  8 directions, east and west are constants *)
	nw, nn, ne : LONGINT;	(* north-west, north, north-east *)
	sw, ss, se: LONGINT;	(* south-west, south, south-east *)

	g0: Generation;	(* the current generation *)
	g1: Generation;	(* a copy of the previous generation *)
	n0: Generation;	(* the neighbor counts for the current generation *)
	n1: Generation;	(* neighbor counts for previous generation *)
	dlist: DisplayList;	(* points to first element of display list *)
	dlistEnd: DisplayList;	(* points to one beyond end, that is first free element *)

	(* offscreen drawing *)
	offscreen: Pictures.Picture;

	(* simulation control *)
	state: INTEGER;	(* generate | drawList | makeList | update *)
	step: INTEGER;	(* drawing step, for fading in/out cells *)
	generations: LONGINT;	(* nr of complete generations simulated so far *)
	times: ARRAY 4 OF LONGINT;	(* time required for generate, draw, update. unit: Input.TimeUnit *)
	timeStarted: LONGINT;	(* time at which Start was last called, unit Input.TimeUnit() *)

	(* kickstart *)
	nrCellsChanged: LONGINT;	(* number of cells changed relative to prev generation *)
	nrGensUnchanged: LONGINT;	(* number of continuous generations seeing no change in nrCellsChanged *)
	nrCellsChangedLimit: LONGINT;	(* randomize when nrCellsChanged < nrCellsChangedLimit*)

	timing: BOOLEAN;	(* should timing information be printed out when fader stops? *)
	frameRate: INTEGER;
	offscreenMode: INTEGER;	(* 0=never; 1=auto; 2=always *)

	(* lookup tables for liveness and color: [ liveness (0 or 1),  nr neighbors (0..8) ] *)
	alive: ARRAY 2, 9 OF SHORTINT;
	toPseudo: ARRAY 2, 9 OF SHORTINT;	(* map [liveness,neighborCount] to pseudo *)

	pseudoToRGBColor: ARRAY numPseudos OF RGB;	(* map pseudo-color to RGB Color *)
	faderTable: ARRAY numPseudos, numPseudos OF Fader;
	curFadeSteps: INTEGER;
	m: REAL; (* with value m [0..1], screen brightness appears at 50%, see CreateMonochromeFade *)


	PROCEDURE SetRGB(VAR color: RGB; n: LONGINT);
	BEGIN ASSERT( (0 <= n) & (n <= 0FFFFFFH), 101);
		color[2] := SHORT(n MOD 256);
		color[1] := INTEGER(ASH(n, -8) MOD 256);
		color[0] := INTEGER(ASH(n, -16));
	END SetRGB;

	(*------------ Color Map Mangling --------------*)

	PROCEDURE SaveCMap;
	VAR c: INTEGER;
	BEGIN
		FOR c := 0 TO 255 DO
			Display.GetColor(c, savedCmap[c,0], savedCmap[c,1], savedCmap[c,2])
		END;
	END SaveCMap;


	PROCEDURE RestoreCMap;
	VAR c: INTEGER;
	BEGIN
		FOR c := 0 TO 255 DO
			Display.SetColor(c, savedCmap[c,0], savedCmap[c,1], savedCmap[c,2])
		END
	END RestoreCMap;


	PROCEDURE CustomizeCMap;
	CONST cmapBase = 16;	(* first writable value of color map *)
	VAR base: INTEGER;	(* first free color map entry, changes as colormap is filled *)

		PROCEDURE MakeFader(from, to: (* pseudo *) INTEGER);
		TYPE
			MonochromeFade = ARRAY maxFadeSteps OF REAL;
		VAR
			F, T: RGB;
			fade: ARRAY 3 OF MonochromeFade;
			i: INTEGER;
			r, g, b: INTEGER;

			PROCEDURE CreateMonochromeFade(fromValue, toValue: REAL; VAR f: MonochromeFade);
			VAR
				i: INTEGER;
				fromBrite, toBrite: REAL;
				dBrite: REAL;

				PROCEDURE Reverse(VAR f: MonochromeFade);
				VAR i: INTEGER; t: REAL;
				BEGIN
					FOR i := 0 TO curFadeSteps DIV 2 - 1 DO
						t := f[i]; f[i] := f[curFadeSteps-1-i]; f[curFadeSteps-1-i] := t;
					END;
				END Reverse;

				(*
				Brightness is precieved brightness, on a scale of 0.0 to 1.0, while
				value is the actual color channel setting (usually represented as an integer
				between 0 and 255) scaled to the range 0.0 to 1.0.

				The parameter m is declared as a global variable. The graph above is for the
				default value, that of the author's display, m=0.78.
				*)

				PROCEDURE BrightnessToValue(b: REAL): REAL;	(* polynomial v(b) *)
				BEGIN
					RETURN (2 - m*4) * b * b + (m*4 - 1) * b;
				END BrightnessToValue;

				PROCEDURE ValueToBrightness(v: REAL): REAL; 	(* function b(v) *)
				CONST eps = 0.00001;
				BEGIN
					IF (ABS(m-0.5)<eps) (* special case to avoid divide by zero *)
						THEN RETURN v
						ELSE RETURN (4*m - 1 - Math.sqrt( m*16*m - m*8 + 1 + 8*v - m*16*v)) / (m*8 - 4);
					END;
				END ValueToBrightness;

			BEGIN (* CreateMonochromeFade *)
				IF fromValue > toValue THEN
					CreateMonochromeFade(toValue, fromValue, f);
					Reverse(f)
				ELSE
					fromBrite := ValueToBrightness(fromValue);
					toBrite := ValueToBrightness(toValue);
					dBrite := (toBrite - fromBrite) / curFadeSteps;
					FOR i := 1 TO curFadeSteps - 2 DO
						f[i] := BrightnessToValue(fromBrite + i * dBrite)
					END;
					f[0] := fromValue;
					f[curFadeSteps-1] := toValue;
				END;
			END CreateMonochromeFade;

		BEGIN (* MakeFader *)
			F := pseudoToRGBColor[from];
			T := pseudoToRGBColor[to];
			FOR i := 0 TO 2 DO CreateMonochromeFade(F[i]/255, T[i]/255, fade[i]) END;
			FOR i := 0 TO curFadeSteps - 1 DO
				r := SHORT(ENTIER(fade[0][i] * 255 + 0.5));
				g := SHORT(ENTIER(fade[1][i] * 255 + 0.5));
				b := SHORT(ENTIER(fade[2][i] * 255 + 0.5));
				Display.SetColor(base, r, g, b);
				faderTable[from, to][i] := base;
				faderTable[to, from][curFadeSteps-1-i] := base;
				INC(base)
			END;
		END MakeFader;

	BEGIN (* CustomizeCMap *)
		base := cmapBase;
		MakeFader(pseudoNormal, pseudoLonely); (* a normal cell becomes lonely *)
		MakeFader(pseudoNormal, pseudoCrowded);
		MakeFader(pseudoLonely, pseudoDead);
		MakeFader(pseudoCrowded, pseudoDead);
		MakeFader(pseudoDead, pseudoNormal);
	END CustomizeCMap;


	PROCEDURE MakeDisplayList(all: BOOLEAN);
	VAR r, c: INTEGER; oldColor, newColor: INTEGER; i: LONGINT;
	BEGIN
		dlistEnd := dlist;
		i := cols+2;
		FOR r := 0 TO rows-1 DO
			FOR c := 0 TO cols-1 DO
				INC(i);
				oldColor := toPseudo[g1[i],n1[i]];
				newColor := toPseudo[g0[i],n0[i]];
				IF all OR (newColor # oldColor)  THEN
					dlistEnd.x := c*cellWidth+xOffset;
					dlistEnd.y := r*cellHeight+yOffset;
					dlistEnd.c := faderTable[oldColor, newColor];
					IF dlistEnd.next = NIL THEN NEW(dlistEnd.next) END;
					dlistEnd := dlistEnd.next;
				END;
			END;
			INC(i, 2);
		END
	END MakeDisplayList;


	PROCEDURE DrawDisplayList(step: INTEGER);

		PROCEDURE DrawOffscreen(step: INTEGER);
		VAR d: DisplayList;
		BEGIN
			d := dlist;
			WHILE d # dlistEnd DO
				Pictures.ReplConst(offscreen, d.c[step], d.x, d.y, cellWidth, cellHeight, Display.replace);
				d := d.next;
			END;
		END DrawOffscreen;

		PROCEDURE DrawOnscreen(step: INTEGER);
		VAR d: DisplayList;
		BEGIN
			d := dlist;
			WHILE d # dlistEnd DO
				Display.ReplConst(d.c[step], d.x, d.y, cellWidth, cellHeight, Display.replace);
				d := d.next;
			END;
		END DrawOnscreen;

	BEGIN
		IF offscreen = NIL THEN
			DrawOnscreen(step)
		ELSE
			DrawOffscreen(step)
		END;
	END DrawDisplayList;


	PROCEDURE UpdateDisplay;
	BEGIN
		IF offscreen # NIL THEN
			Pictures.DisplayBlock(
				offscreen, 0, 0, offscreen.width, offscreen.height,
				Display.Left, Display.Bottom, Display.replace)
		END;
	END UpdateDisplay;


	PROCEDURE CopyGeneration(src, dst: Generation);
	BEGIN
		SYSTEM.MOVE(ADDRESSOF(src[0]), ADDRESSOF(dst[0]), LEN(dst^));
	END CopyGeneration;


	PROCEDURE ClearGeneration(g: Generation);
	VAR i: SIZE;
	BEGIN
		FOR i := 0 TO LEN(g^)-1 DO g[i] := 0 END;
	END ClearGeneration;


	PROCEDURE Randomize(proportion: REAL);
	CONST range = 10000;
	VAR
		r,c: INTEGER;
		i: LONGINT;
		limit: INTEGER;
	BEGIN
		ASSERT( (0.0 <= proportion) & (proportion <= 1.0), 101);
		limit := SHORT(ENTIER(range*proportion));
		i := cols+2;
		FOR r := 0 TO rows-1 DO
			FOR c := 0 TO cols-1 DO
				INC(i);
				IF SaveScreen.Rand(range) < limit THEN
					g0[i] := ABS(g0[i]-1);
				END;
			END;
			INC(i,2);
		END;
	END Randomize;


	PROCEDURE RecomputeNeighbors;
	VAR
		i: LONGINT;
		r, c: INTEGER;
		(* neighbor sum for g0[i] *)
		sum: SHORTINT;
	BEGIN
		i := cols + 2;
		FOR r := 1 TO rows  DO
			FOR c := 1 TO cols  DO
				INC(i);
				sum := g0[i+nw];
				INC(sum, g0[i+nn]);
				INC(sum, g0[i+ne]);
				INC(sum, g0[i+ww]);
				INC(sum, g0[i+ee]);
				INC(sum, g0[i+sw]);
				INC(sum, g0[i+ss]);
				INC(sum, g0[i+se]);
				n0[i] := sum;
			END;
			INC(i, 2);
		END;
	END RecomputeNeighbors;


	PROCEDURE Setup;	(* cellWidth, cellHeight must have legal values *)

		PROCEDURE ComputeGeometry;
		BEGIN
			screenWidth := Display.Width;
			screenHeight := Display.Height;
			xOffset := (screenWidth MOD cellWidth) DIV 2;
			yOffset := (screenHeight MOD cellHeight) DIV 2;
			cols := screenWidth DIV cellWidth;
			rows := screenHeight DIV cellHeight;
		END ComputeGeometry;

		PROCEDURE ComputeNeighborOffsets;
		BEGIN
			nw := -(cols+3); nn := -(cols+2); ne := -(cols+1);
			sw := (cols+1); ss := (cols+2); se := (cols+3);
		END ComputeNeighborOffsets;

		PROCEDURE CreateGenerations;
		VAR len: LONGINT;
		BEGIN
			len := LONG(cols+2)*(rows+2);
			NEW(g0, len);
			NEW(g1, len);
			NEW(n0, len);
			NEW(n1, len);
			ClearGeneration(g0);
			CopyGeneration(g0, g1);
			CopyGeneration(g0, n0);
			CopyGeneration(g0, n1);
			Randomize(creationProportion);
			RecomputeNeighbors;
		END CreateGenerations;

		PROCEDURE CreateOffscreen;
		BEGIN
			IF offscreenMode # neverOffscreen THEN
				NEW(offscreen);
				IF offscreen # NIL THEN
					Pictures.Create(offscreen, screenWidth, screenHeight, 8);
					IF (offscreen.width # 0) & (offscreen.height # 0) & (offscreen.depth # 0) THEN
						Pictures.ReplConst(offscreen, 15,  0, 0, screenWidth, screenHeight, Display.replace);
					ELSE (* not enough memory for offscreen buffer *)
						offscreen := NIL;
					END;
				END;
			ELSE (* offscreenMode = neverOffscreen *)
				offscreen := NIL
			END;
		END CreateOffscreen;

		PROCEDURE CreateDisplayList;
		BEGIN
			NEW(dlist);
			dlistEnd := dlist;
		END CreateDisplayList;

		PROCEDURE ClearKickstartValues;
		BEGIN
			nrCellsChanged := 0;
			nrCellsChangedLimit := ENTIER(LONG(rows)*cols*0.005);
			nrGensUnchanged := 0;
			(* nrGensUnchangedLimit is CONST *)
		END ClearKickstartValues;

	BEGIN
		ComputeGeometry;
		ComputeNeighborOffsets;
		CreateGenerations;
		CreateOffscreen;
		CreateDisplayList;
		ClearKickstartValues;
	END Setup;


	PROCEDURE Generate;
	VAR
		r,c: INTEGER;
		a: SHORTINT;
		i: LONGINT;
		t: Generation;
		nr: LONGINT;	(* number of cells changed *)
	BEGIN
		nr := 0;
		CopyGeneration(n0, n1); (* n1 is our working copy of n0 *)
		CopyGeneration(g0, g1); (* g1 is a "backup" of g0, used to optimize redraw *)
		i := cols+2;
		FOR r := 1 TO rows  DO
			FOR c := 1 TO cols  DO
				INC(i);
				a := alive[ g0[i], n0[i] ];
				IF (a # g0[i]) THEN
					INC(nr);
					g0[i] := a;
					a := a+a-1; (* 0 -> -1; 1 -> +1 *)
					INC(n1[i+nw], a);
					INC(n1[i+nn], a);
					INC(n1[i+ne], a);
					INC(n1[i+ww], a);
					INC(n1[i+ee], a);
					INC(n1[i+sw], a);
					INC(n1[i+ss], a);
					INC(n1[i+se], a);
				END; (* if a # g0[i] *)
			END; (* for c *)
			INC(i,2);
		END; (* for r *)
		t := n0; n0 := n1; n1 := t;	(* swap: n1 is now of previous generation *)
		IF (ABS(nrCellsChanged-nr) <= nrGensUnchangedTolerance) THEN
			INC(nrGensUnchanged)
		ELSE
			nrGensUnchanged := 0
		END;
		nrCellsChanged := nr;
	END Generate;


	(*-------------- calibration -----------------------*)

	(*
	with the help of this procedure, one can determine the appropriate m value for the current
	display a checkered black and white screen and a solid grey screen can be displayed.  You can
	toggle between them using the space bar. The grey screen can be darkened with the "d" key and
	lightened with the "L" key.  When both the checkerboard screen and the grey screen appear
	equally bright, hit "Q" to quit. The system log will contain the "m" value appropriate for your
	display.  This can be used in the configuration string to SaveLife.Install.
	*)

	PROCEDURE Calibrate*;
	VAR ch: CHAR; showingPat: BOOLEAN; level: INTEGER;

		PROCEDURE BWPattern;
		BEGIN
			Display.ReplPattern(Display.FG, Display.grey2,
				Display.Left, Display.Bottom, Display.Width, Display.Height,
				Display.replace);
		END BWPattern;

		PROCEDURE GreyLevel(level: INTEGER);
		BEGIN
			ASSERT( (0 <= level) & (level <= 255), 101);
			Display.SetColor(255, level, level, level);
			Display.ReplConst(255,
				Display.Left, Display.Bottom, Display.Width, Display.Height,
				Display.replace);
		END GreyLevel;

	BEGIN (* Calibrate *)
		level := 128;
		BWPattern; showingPat := TRUE;
		LOOP
			IF Input.Available() > 0 THEN
				Input.Read(ch);
				CASE ch OF
				| " ":
					IF showingPat THEN GreyLevel(level) ELSE BWPattern END;
					showingPat := ~showingPat;
				| "D", "d":
					IF level > 0 THEN DEC(level) END;
					GreyLevel(level);
					showingPat := FALSE;
				| "L", "l":
					IF level < 255 THEN INC(level) END;
					GreyLevel(level);
					showingPat := FALSE;
				| "`", "Q", "X", "q", "x", "~":
					Out.String("The calibration value for SaveLife.Install is "); Out.Ln;
					Out.String("    m ");
					Out.Real(level/255, 10);
					Out.Ln;
					EXIT
				END;
			END;
		END;
	END Calibrate;



	(*------------- screen saver procedures -------------*)


	PROCEDURE Start;
	BEGIN
		SaveCMap;
		CustomizeCMap;
		timeStarted := Input.Time();
		SaveScreen.SetFrameRate(frameRate);
		Display.ReplConst(15, Display.Left, Display.Bottom,
			Display.Width, Display.Height, Display.replace);
		Setup;
		state := makeList;
		generations := 0;
		times[0] := 0; times[1] := 0; times[2] := 0; times[3] := 0;
	END Start;


	PROCEDURE Step;
	VAR ostate: INTEGER; t: LONGINT;
	BEGIN
		ostate := state;
		t := Input.Time();
		CASE state OF
		| makeList:
			MakeDisplayList(quick);
			state := drawList;
			step := 0;	(* ready step counter for state drawList *)
		| drawList:
			DrawDisplayList(step);
			state := update;
		| update:
			UpdateDisplay;
			INC(step);
			IF step = curFadeSteps THEN
				state := generate
			ELSE
				state := drawList
			END;
		| generate:
			Generate;
			(* revoke offscreen drawing if it is too slow *)
			IF (offscreenMode # alwaysOffscreen) &
				(offscreen#NIL) & (times[drawList] < times[update]) THEN
				offscreen := NIL;
				times[0] := 0; times[1] := 0; times[2] := 0
			END;
			(* kickstart the world if it appears to have gone dormant *)
			IF (nrGensUnchanged > nrGensUnchangedLimit) OR
				(nrCellsChanged < nrCellsChangedLimit) THEN
				Randomize(kickstartProportion); RecomputeNeighbors
			END;
			INC(generations);
			state := makeList;
		END;
		t := Input.Time() - t;
		INC(times[ostate], t);
	END Step;


	PROCEDURE Stop;
	VAR timeTaken: LONGINT;
		PROCEDURE PerGen(ticks: LONGINT): LONGINT;	(* milliseconds *)
		BEGIN RETURN ENTIER(((ticks/generations)/Input.TimeUnit)*1000)
		END PerGen;
	BEGIN
		Display.ReplConst(15, Display.Left, Display.Bottom,
			Display.Width, Display.Height, Display.replace);
		RestoreCMap;
		timeTaken := Input.Time() - timeStarted;
		IF g0 # NIL THEN
			offscreen := NIL;
			g0 := NIL;
			n0 := NIL;
			n1 := NIL;
			g1 := NIL;
			dlist := NIL;
			dlistEnd := NIL;
			Oberon.Collect;
			IF timing THEN
				Out.String("Times:"); Out.Ln;
				Out.String("  makeList: "); Out.Int(PerGen(times[makeList]), 8); Out.String(" ms/g "); Out.Ln;
				Out.String("  drawList: "); Out.Int(PerGen(times[drawList]), 8); Out.String(" ms/g "); Out.Ln;
				Out.String("  update:    "); Out.Int(PerGen(times[update]), 8); Out.String(" ms/g "); Out.Ln;
				Out.String("  generate: "); Out.Int( PerGen(times[generate]), 8); Out.String(" ms/g "); Out.Ln;
				Out.String("  total:        "); Out.Int(PerGen(times[0]+times[1]+times[2]+times[3]),8); Out.String(" ms/g "); Out.Ln;
			END;
		END;
	END Stop;


	PROCEDURE Install*;
	VAR r: REAL; n: INTEGER; name: ARRAY 64 OF CHAR; color: LONGINT;
	BEGIN
		SaveScreen.InstallFader(Start, Step, Stop);

		timing := defTiming;
		cellWidth := defCellWidth;
		cellHeight := defCellHeight;
		frameRate := defFrameRate;
		m := defMvalue;
		curFadeSteps := defFadeSteps;
		offscreenMode := autoOffscreen;
		SetRGB(pseudoToRGBColor[pseudoDead], 0000000H);
		SetRGB(pseudoToRGBColor[pseudoCrowded], 0FFFF00H);
		SetRGB(pseudoToRGBColor[pseudoLonely], 000FFFFH);
		SetRGB(pseudoToRGBColor[pseudoNormal], 0E0E0E0H);

		In.Open;
		WHILE In.Done DO
			In.Name(name);
			IF (name = "w") OR (name="W") THEN
				In.Int(n);
				IF In.Done THEN cellWidth := SaveScreen.Limit(minCellWidth, n, maxCellWidth) END
			ELSIF (name = "h") OR (name = "H") THEN
				In.Int(n);
				IF In.Done THEN cellHeight := SaveScreen.Limit(minCellHeight, n, maxCellHeight) END
			ELSIF (name = "timing") THEN
				timing := TRUE;
			ELSIF (name = "frameRate") THEN
				In.Int(n);
				IF In.Done THEN frameRate := SaveScreen.Limit(minFrameRate, n, maxFrameRate) END;
			ELSIF (name = "m") THEN
				In.Real(r);
				IF In.Done & (r >= 0) & (r <= 1) THEN m := r END
			ELSIF (name = "steps") THEN
				In.Int(n);
				IF In.Done THEN curFadeSteps := SaveScreen.Limit(minFadeSteps, n, maxFadeSteps) END;
			ELSIF (name = "offscreen") THEN
				In.Int(n);
				IF In.Done THEN offscreenMode := SaveScreen.Limit(minOffscreen, n, maxOffscreen) END;
			ELSIF (name = "crowded") THEN
				In.LongInt(color);
				IF In.Done THEN SetRGB(pseudoToRGBColor[pseudoCrowded], color) END;
			ELSIF (name = "lonely") THEN
				In.LongInt(color);
				IF In.Done THEN SetRGB(pseudoToRGBColor[pseudoLonely], color) END;
			ELSIF (name = "normal") THEN
				In.LongInt(color);
				IF In.Done THEN SetRGB(pseudoToRGBColor[pseudoNormal], color) END;
			END;
		END;
	END Install;


	PROCEDURE Configuration*;
	BEGIN
		Out.String("SaveLife: "); Out.Ln;
		Out.String("   w "); Out.Int(cellWidth,0); Out.Ln;
		Out.String("   h "); Out.Int(cellHeight, 0); Out.Ln;
		Out.String("   frameRate "); Out.Int(frameRate, 0); Out.Ln;
		Out.String("   m "); Out.Real(m, 12); Out.Ln;
		Out.String("   steps "); Out.Int(curFadeSteps, 0); Out.Ln;
		Out.String("   offscreen "); Out.Int(offscreenMode, 0); Out.Ln;
		Out.String("   timing ");
		IF timing THEN Out.String("(is on)") ELSE Out.String("(is off)") END;
		Out.Ln;
	END Configuration;


	PROCEDURE Remove;
	BEGIN
		SaveScreen.RemoveFader(Start, Step, Stop);
	END Remove;


BEGIN
	Modules.InstallTermHandler(Remove);
	alive[0,0] := 0;	alive[0,1] := 0;	alive[0,2] := 0;
	alive[0,3] := 1;	alive[0,4] := 0;	alive[0,5] := 0;
	alive[0,6] := 0;	alive[0,7] := 0;	alive[0,8] := 0;
	alive[1,0] := 0;	alive[1,1] := 0;	alive[1,2] := 1;
	alive[1,3] := 1;	alive[1,4] := 0;	alive[1,5] := 0;
	alive[1,6] := 0;	alive[1,7] := 0;	alive[1,8] := 0;

	toPseudo[0,0] := pseudoDead;	toPseudo[0,1] := pseudoDead;	toPseudo[0,2] := pseudoDead;
	toPseudo[0,3] := pseudoDead;	toPseudo[0,4] := pseudoDead;	toPseudo[0,5] := pseudoDead;
	toPseudo[0,6] := pseudoDead;	toPseudo[0,7] := pseudoDead;	toPseudo[0,8] := pseudoDead;
	toPseudo[1,0] := pseudoLonely;	toPseudo[1,1] := pseudoLonely;	toPseudo[1,2] := pseudoNormal;
	toPseudo[1,3] := pseudoNormal;	toPseudo[1,4] := pseudoCrowded;	toPseudo[1,5] := pseudoCrowded;
	toPseudo[1,6] := pseudoCrowded;	toPseudo[1,7] := pseudoCrowded;	toPseudo[1,8] := pseudoCrowded;
END SaveLife.

System.Free SaveLife ~

SaveLife.Install h 2 w 2  timing offscreen 0 ~
SaveLife.Install h 1 w 1  timing frameRate 30 ~
SaveLife.Install h 4 w 4  timing frameRate  30 offscreen 0 steps 8 m 0.78 ~
SaveLife.Install h 8 w 8  timing frameRate 30 crowded 000FFFFH normal 0FF00FFH lonely 0FFFF00H ~
SaveLife.Install h 8 w 8  timing frameRate 30 crowded 0FF0000H normal 000FF00H lonely 00000FFH ~
SaveLife.Install h 8 w 8  timing frameRate 30 crowded 0FF0000H normal 000FF00H lonely 00000FFH ~
SaveLife.Install h 2 w 2  timing frameRate 30 ~
SaveLife.Configuration
SaveScreen.Run

SaveLife.Text
