(* ETH Oberon, Copyright 2001 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

(*
	SaveSwarm - 25.1.2000 Jaco Geldenhuys
	The swarm screen saver (by Bruno Essman) integrated into the SaveScreen
	system by (Ben Smith-Mannschott).
*)

MODULE SaveSwarm IN Oberon;

IMPORT Out, In, Modules, SaveScreen, Display, Display3, RandomNumbers;

CONST
	versionString = "SaveSwarm 25.1.2000";

	minSpeed = 1; maxSpeed = 10; defaultSpeed = 2;
	minSize = 2; maxSize = 1000; defaultSize = 100;
	minBorder = 0; maxBorder = 100; defaultBorder = 20;
	minCol = 0; maxCol = 256; defaultMincol = 40; defaultMaxcol = 48; defaultWaspcol = 0;
	minBacc = 1; maxBacc = 100; defaultBacc = 2;
	minBvel = 1; maxBvel = 100; defaultBvel = 12;
	minWacc = 1; maxWacc = 100; defaultWacc = 5;
	minWvel = 1; maxWvel = 100; defaultWvel = 10;

TYPE
	Bee = RECORD
		x, y: ARRAY 3 OF SIGNED16;	(* bee positions x[time], y[time] *)
		vx, vy: SIGNED16;	(* bee velocity *)
	END;
	BeeSwarm = POINTER TO ARRAY OF Bee;

	Swarm = RECORD
		X, Y, W, H: SIGNED16;
		speed, time: SIGNED16;	(* speed of swarm *)
		size: SIGNED16;	(* number of bees in swarm *)
		mincol, maxcol, col, colstep: SIGNED16;	(* display colors and update step for swarm *)
		waspcol: SIGNED16;	(* color of wasp *)
		wacc, wvel: SIGNED16;	(* maximum wasp acceleration and velocity *)
		border: SIGNED16;	(* minimum border for wasp *)
		wasp: Bee;	(* the wasp, special kind of bee *)
		bacc, bvel: SIGNED16;	(* maximum bee acceleration and velocity *)
		bees: BeeSwarm;	(* the swarm of bees *)
	END;

VAR
	swarm: Swarm;
	mask: Display3.Mask;
	speed, size, border, mincol, maxcol, waspcol, bacc, bvel, wacc, wvel: SIGNED16;

PROCEDURE RandomizeSwarm(VAR s: Swarm);
VAR i, startv: SIGNED16;
BEGIN
	s.wasp.x[0] := s.border+SHORT(ENTIER((s.W-(2*s.border))*RandomNumbers.Uniform())); s.wasp.x[1] := s.wasp.x[0];
	s.wasp.y[0] := s.border+SHORT(ENTIER((s.H-(2*s.border))*RandomNumbers.Uniform())); s.wasp.y[1] := s.wasp.y[0];
	s.wasp.vx := 0; s.wasp.vy := 0;  (* start velocity of wasp is zero *)
	startv := (7*s.bvel) DIV 12; IF startv = 0 THEN startv := 1 END; (* start velocity of bees is 7/12 of maximum velocity *)
	FOR i := 0 TO s.size-1 DO
		s.bees[i].x[0] := SHORT(ENTIER(s.W*RandomNumbers.Uniform())); s.bees[i].x[1] := s.bees[i].x[0];
		s.bees[i].y[0] := SHORT(ENTIER(s.H*RandomNumbers.Uniform())); s.bees[i].y[1] := s.bees[i].y[0];
		s.bees[i].vx := SHORT(ENTIER(startv*RandomNumbers.Uniform())-(startv DIV 2));
		s.bees[i].vy := SHORT(ENTIER(startv*RandomNumbers.Uniform())-(startv DIV 2))
	END
END RandomizeSwarm;

PROCEDURE InitSwarm(VAR s: Swarm; speed, size, width, height, border, mincol, maxcol, waspcol, bacc, bvel, wacc, wvel: SIGNED16);
BEGIN
	s.speed := speed; s.time := 0;
	s.size := size; NEW(s.bees, s.size);
	s.W := width; s.H := height; s.border := border;
	s.mincol := mincol; s.maxcol := maxcol; s.col := s.mincol; s.colstep := 1;
	s.waspcol := waspcol;
	s.wacc := wacc; s.wvel := wvel;
	s.bacc := bacc; s.bvel := bvel;
	RandomizeSwarm(s)
END InitSwarm;

PROCEDURE AgeSwarm (VAR s: Swarm; m: Display3.Mask; x, y: SIGNED16);
VAR i, dx, dy, dist, acc: SIGNED16; bees: BeeSwarm;
BEGIN
	(* handle wasp *)
	s.wasp.x[2] := s.wasp.x[1]; s.wasp.x[1] := s.wasp.x[0];  (* age coordinates... *)
	s.wasp.y[2] := s.wasp.y[1]; s.wasp.y[1] := s.wasp.y[0];
	acc := s.wacc;  (* accelerate... *)
	INC(s.wasp.vx, SHORT(ENTIER(acc*RandomNumbers.Uniform())-(acc DIV 2)));
	INC(s.wasp.vy, SHORT(ENTIER(acc*RandomNumbers.Uniform())-(acc DIV 2)));
	IF s.wasp.vx > s.wvel THEN s.wasp.vx := s.wvel END;  (* check speed limit... *)
	IF s.wasp.vx < -s.wvel THEN s.wasp.vx := -s.wvel END;
	IF s.wasp.vy > s.wvel THEN s.wasp.vy := s.wvel END;
	IF s.wasp.vy < -s.wvel THEN s.wasp.vy := -s.wvel END;
	INC(s.wasp.x[0], s.wasp.vx);  (* move... *)
	INC(s.wasp.y[0], s.wasp.vy);
	IF (s.wasp.x[0] < s.border) OR (s.wasp.x[0] > s.W-s.border) THEN  (* bounce checks... *)
		s.wasp.vx := -s.wasp.vx; INC(s.wasp.x[0], s.wasp.vx)
	END;
	IF (s.wasp.y[0] < s.border) OR (s.wasp.y[0] > s.H-s.border) THEN
		s.wasp.vy := -s.wasp.vy; INC(s.wasp.y[0], s.wasp.vy)
	END;

	(* don't let things settle down *)
	acc := (7*s.bvel) DIV 12; IF acc = 0 THEN acc := 1 END;  (* acceleration is 7/12 of maximum *)
	INC(s.bees[SHORT(ENTIER(s.size*RandomNumbers.Uniform()))].vx, SHORT(ENTIER(acc*RandomNumbers.Uniform())-(acc DIV 2)));
	INC(s.bees[SHORT(ENTIER(s.size*RandomNumbers.Uniform()))].vy, SHORT(ENTIER(acc*RandomNumbers.Uniform())-(acc DIV 2)));

	(* handle bees *)
	bees := s.bees;
	acc := s.bacc;
	FOR i := 0 TO s.size-1 DO
		bees[i].x[2] := bees[i].x[1]; bees[i].x[1] := bees[i].x[0];  (* age coordinates... *)
		bees[i].y[2] := bees[i].y[1]; bees[i].y[1] := bees[i].y[0];
		dx := s.wasp.x[1] - bees[i].x[1]; dy := s.wasp.y[1] - bees[i].y[1];  (* accelerate... *)
		dist := ABS(dx) + ABS(dy);  (* approx. *)
		IF dist = 0 THEN dist := 1 END;  (* always keep some distance *)
		INC(bees[i].vx, (dx*acc) DIV dist); INC(bees[i].vy, (dy*acc) DIV dist);
		IF bees[i].vx > s.bvel THEN bees[i].vx := s.bvel END;  (* check speed limit... *)
		IF bees[i].vx < -s.bvel THEN bees[i].vx := -s.bvel END;
		IF bees[i].vy > s.bvel THEN bees[i].vy := s.bvel END;
		IF bees[i].vy < -s.bvel THEN bees[i].vy := -s.bvel END;
		INC(bees[i].x[0], bees[i].vx);  (* move... *)
		INC(bees[i].y[0], bees[i].vy);
	END;

	(* draw swarm *)
	Display3.Line(m, Display3.FG, Display.solid, x+s.wasp.x[1], y+s.wasp.y[1], x+s.wasp.x[2], y+s.wasp.y[2], 1, Display3.replace);
	FOR i := 0 TO s.size-1 DO  (* paint old bee positions using black *)
		Display3.Line(m, Display3.FG, Display.solid, x+bees[i].x[1], y+bees[i].y[1], x+bees[i].x[2], y+bees[i].y[2], 1, Display3.replace)
	END;
	Display3.Line(m, s.waspcol, Display.solid, x+s.wasp.x[0], y+s.wasp.y[0], x+s.wasp.x[1], y+s.wasp.y[1], 1, Display3.replace);
	INC(s.col, s.colstep);  (* increase, or decrease current swarm color *)
	IF s.col > s.maxcol THEN s.col := s.maxcol; s.colstep := -1 ELSIF s.col < s.mincol THEN s.col := s.mincol; s.colstep := 1 END;
	FOR i := 0 TO s.size-1 DO  (* draw bees *)
		Display3.Line(m, s.col, Display.solid, x+bees[i].x[0], y+bees[i].y[0], x+bees[i].x[1], y+bees[i].y[1], 1, Display3.replace)
	END
END AgeSwarm;

PROCEDURE Start;
BEGIN
	SaveScreen.SetFrameRate(60);
	Display.ReplConst(Display.FG, Display.Left, Display.Bottom, Display.Width, Display.Height, Display.replace);
	InitSwarm(swarm, speed, size, Display.Width, Display.Height, border, mincol, maxcol, waspcol, bacc, bvel, wacc, wvel)
END Start;

PROCEDURE Step;
BEGIN
	AgeSwarm(swarm, mask, 0, 0)
END Step;

PROCEDURE Stop;
END Stop;

PROCEDURE Install*;
VAR name: ARRAY 32 OF CHAR; n: SIGNED16;
BEGIN In.Open;
	LOOP
		In.Name(name); IF ~In.Done THEN EXIT END;
		In.Int(n); IF ~In.Done THEN EXIT END;
		IF (name = "speed") THEN
			speed := SaveScreen.Limit(minSpeed, n, maxSpeed)
		ELSIF (name = "size") THEN
			size := SaveScreen.Limit(minSize, n, maxSize)
		ELSIF (name = "border") THEN
			border := SaveScreen.Limit(minBorder, n, maxBorder)
		ELSIF (name = "mincol") THEN
			mincol := SaveScreen.Limit(minCol, n, maxCol)
		ELSIF (name = "maxcol") THEN
			maxcol := SaveScreen.Limit(minCol, n, maxCol)
		ELSIF (name = "waspcol") THEN
			waspcol := SaveScreen.Limit(minCol, n, maxCol)
		ELSIF (name = "bacc") THEN
			bacc := SaveScreen.Limit(minBacc, n, maxBacc)
		ELSIF (name = "bvel") THEN
			bvel := SaveScreen.Limit(minBvel, n, maxBvel)
		ELSIF (name = "wacc") THEN
			wacc := SaveScreen.Limit(minWacc, n, maxWacc)
		ELSIF (name = "wvel") THEN
			wvel := SaveScreen.Limit(minWvel, n, maxWvel)
		END
	END;
	SaveScreen.InstallFader(Start, Step, Stop)
END Install;

PROCEDURE Configuration*;
BEGIN
	Out.String("SaveSwarm: "); Out.Ln;
	Out.String("    speed "); Out.Int(speed, 0); Out.Ln;
	Out.String("    size "); Out.Int(size, 0); Out.Ln;
	Out.String("    border "); Out.Int(border, 0); Out.Ln;
	Out.String("    mincol "); Out.Int(mincol, 0); Out.Ln;
	Out.String("    maxcol "); Out.Int(maxcol, 0); Out.Ln;
	Out.String("    waspcol "); Out.Int(waspcol, 0); Out.Ln;
	Out.String("    bacc "); Out.Int(bacc, 0); Out.Ln;
	Out.String("    bvel "); Out.Int(bvel, 0); Out.Ln;
	Out.String("    wacc "); Out.Int(wacc, 0); Out.Ln;
	Out.String("    wvel "); Out.Int(wvel, 0); Out.Ln
END Configuration;

PROCEDURE Remove;
BEGIN SaveScreen.RemoveFader(Start, Step, Stop)
END Remove;

PROCEDURE InstallDefault*;
BEGIN
	speed := defaultSpeed; size := defaultSize;
	border := defaultBorder;
	mincol := defaultMincol; maxcol := defaultMaxcol;
	waspcol := defaultWaspcol;
	bacc := defaultBacc; bvel := defaultBvel;
	wacc := defaultWacc; wvel := defaultWvel
END InstallDefault;

BEGIN
	Modules.InstallTermHandler(Remove);
	NEW(mask); Display3.Open(mask);
	Display3.Add(mask, 0, 0, Display.Width, Display.Height);
	InstallDefault;
	Out.String(versionString); Out.Ln
END SaveSwarm.

SaveSwarm.Install mincol 1 maxcol 1 waspcol 2 ~
SaveSwarm.Configuration
SaveScreen.Run
