MODULE Snow; (** AUTHOR "TF"; PURPOSE "Let it snow"; *)

IMPORT
	Modules, Commands, WMWindowManager, WMGraphics, Kernel, Random;

CONST
	DefaultNofFlakes = 20;

	Idle = 0;
	Running = 1;
	Terminating = 2;
	Terminated = 3;

VAR
	state : LONGINT;

PROCEDURE Snow*(context : Commands.Context); (** [nofFlakes] ~ *)
VAR
	flakes : POINTER TO ARRAY OF WMWindowManager.BufferWindow;
	flakePos : POINTER TO ARRAY OF RECORD x, y : LONGINT END;
	nofFlakes, i, j : LONGINT;
	f, f1, f2 : WMGraphics.Image;
	timer : Kernel.Timer;
	random : Random.Generator;
BEGIN
	BEGIN {EXCLUSIVE}
		IF (state # Idle) THEN
			RETURN;
		ELSE
			state := Running;
		END;
	END;
	IF ~context.arg.GetInteger(nofFlakes, FALSE) OR (nofFlakes <= 0) THEN
		nofFlakes := DefaultNofFlakes;
	END;
	NEW(flakes, nofFlakes);
	NEW(flakePos, nofFlakes);
	NEW(random); random.InitSeed(Kernel.GetTicks());
	NEW(timer);
	f1 := WMGraphics.LoadImage("xmas04.tar://Flake1.png", TRUE);
	f2 := WMGraphics.LoadImage("xmas04.tar://Flake2.png", TRUE);
	FOR i := 0 TO nofFlakes - 1 DO
		flakePos[i].x := random.Dice(1280);
		flakePos[i].y := -random.Dice(1000);
		IF random.Dice(2) = 1 THEN f := f1 ELSE f := f2 END;
		NEW(flakes[i], f.width, f.height, TRUE);
		flakes[i].pointerThreshold := 255;
		flakes[i].canvas.DrawImage(0, 0, f, WMGraphics.ModeCopy)
	END;

	FOR i := 0 TO nofFlakes - 1 DO
		WMWindowManager.ExtAddWindow(flakes[i], flakePos[i].x, flakePos[i].y, {WMWindowManager.FlagStayOnTop});
	END;

	j := 0;
	LOOP
		INC(j);
		IF (state # Running) OR (j >= 12000) THEN EXIT; END;
		i := 0;
		LOOP
			flakePos[i].x := flakePos[i].x + random.Dice(5)-2;
			INC(flakePos[i].y);
			IF random.Dice(2) = 1 THEN INC(flakePos[i].y) END;
			IF (flakePos[i].y > 1024) & (j < 10000) THEN flakePos[i].y := -64 - random.Dice(10) END;
			flakes[i].manager.SetWindowPos(flakes[i], flakePos[i].x, flakePos[i].y);
			INC(i);
			IF (state # Running) OR (i >= nofFlakes) THEN EXIT; END;
		END;
		IF (state = Running) THEN timer.Sleep(10); END;
	END;

	FOR i := 0 TO nofFlakes - 1 DO
		flakes[i].manager.Remove(flakes[i]);
	END;
	BEGIN {EXCLUSIVE}
		IF (state = Running) THEN
			state := Idle;
		ELSE
			state := Terminated;
		END;
	END;
END Snow;

PROCEDURE Cleanup;
BEGIN {EXCLUSIVE}
	IF (state = Running) THEN
		state := Terminating;
		AWAIT(state = Terminated);
	END;
END Cleanup;

BEGIN
	state := Idle;
	Modules.InstallTermHandler(Cleanup);
END Snow.Snow

System.Free Snow ~
