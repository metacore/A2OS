(* ETH Oberon, Copyright 2001 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

(*
SaveScreen: A simple, extensible screen saver.
New screensavers can be written by defining three procedures: Start, Step and Stop.

Version History
PR1 - 1999.10.31/01:20:20 - bpsm
1.0 - 1999.11.03/12:57 - bpsm
	- cursor is now hidden correctly.
	- termination handler now removes background task when module is freed
	- InstallDefault procedure added to restore the default fader.
	- Log output is now smart about placing newlines.
1.1 - 1999.11.05/19:46 - bpsm
	- mouseTolerance added. Mouse must move at least this far to be noticed.
	- Particles fader moved to a separate module
	- Default screen saver now just blanks the screen.
	- Rand added
	- Limit added
	- HandleFiller cleaned up.
1.1.1 - 1999.11.06/00:04 - bpsm
	- Screen is now redrawn explicitly after the fader has been stopped.
1.1.2 - 1999.11.12/16:45 - bpsm
	- TextFrames now redraw correctly on the Sharks (again).
	- Clicking the mouse on SaveScreen.Run no longer causes wierdness.
1.1.3 - 2000.03.29 - bpsm
	- hopefully final tweak of redraw behavior (thanks pieter!)
	- should handle timer rollover
	- screen saver engine retooled internally.
	- less verbose.
	- faders no longer continue to draw after a system TRAP
1.1.4 - 2000.04.03 - bpsm
	- automatic activation of screen saver on loading (req: pjm)
	- default wait time changed to 10 minutes (req: pjm)
*)


MODULE SaveScreen IN Oberon;

	IMPORT Modules, Objects, Texts, In,  Viewers, Oberon, Input, Display;

	TYPE
		FaderProc* = PROCEDURE;

	CONST
		defWaitTime = 10 * 60;	(* seconds *)
		defFrameRate = 20;	(* frames/second *)
		defWaitPeriod = 15;	(* seconds *)

		mouseTolerance = 3;
		versionString = "1.1.4 - 2000.04.03 - bpsm";

		(* states *)
		dormant = 0;	(* not watching mouse, screensaver will not activate automatically *)
		waiting = 1;	(* watching mouse, screensaver will activate when waitLimit is reached *)
		drawingD = 2;	(* screensaver is drawing the current fader, return to dormant if interrupted *)
		drawingW = 3;	(* screensaver is drawing, return to watching if interrupted. *)
		nostate = -1;

	(**)

	VAR
		W: Texts.Writer;
		seed: SIGNED32;	(* for the random number generator *)

		Start, Step, Stop: FaderProc;

		waitLimit: SIGNED32;	(* time at which the fader kicks in, unit: Input.TimeUnit *)
		waitTime, waitPeriod, drawPeriod: SIGNED32;	(* unit Input.TimeUnit *)
		oldMouseX, oldMouseY: SIGNED16;

		state: SIGNED16;
		task: Oberon.Task;
		filler: Viewers.Viewer;


(* Utilities *)

	PROCEDURE Msg(s: ARRAY OF CHAR);
		CONST return=0DX;
		VAR R: Texts.Reader; ch: CHAR;
	BEGIN
		Texts.OpenReader(R, Oberon.Log, Oberon.Log.len-1);
		Texts.Read(R, ch);
		IF ch # return THEN Texts.WriteLn(W) END;
		Texts.WriteString(W, "SaveScreen: ");
		Texts.WriteString(W, s);
		Texts.WriteLn(W);
		Texts.Append(Oberon.Log, W.buf);
	END Msg;

	PROCEDURE Rand*(range: SIGNED16): SIGNED16;
		CONST a = 16807; m = 2147483647; q = m DIV a; r = m MOD a;
		VAR g: SIGNED32;
	BEGIN
		g := a * (seed MOD q) - r * (seed DIV q);
		IF g > 0 THEN seed := g ELSE seed := g + m END;
		RETURN SHORT(seed MOD range);
	END Rand;

	PROCEDURE Limit*(min, val, max: SIGNED16): SIGNED16;
	BEGIN
		IF val < min THEN RETURN min
		ELSIF val > max THEN RETURN max
		ELSE RETURN val
		END;
	END Limit;


(* Engine/Statemachine  *)

(* Customized version of Oberon.HandleFiller (not exported)
	(1) I don't want my filler viewer to block the users access to the display in the case of a
		System Trap in a fader's code, so at the first sign of activity (mouse moved), I close myself
	(2) Drawing pointers and the mouse cursor is supressed. *)

	PROCEDURE HandleFiller(V: Objects.Object; VAR M: Objects.ObjMsg);
	BEGIN
		WITH V: Viewers.Viewer DO
			IF M IS Oberon.InputMsg THEN
				WITH M: Oberon.InputMsg DO
					IF M.id=Oberon.track THEN
						IF (ABS(M.X-oldMouseX) > mouseTolerance) & (ABS(M.Y-oldMouseY) > mouseTolerance) THEN
							ASSERT(state IN {drawingD, drawingW}, 111);
							IF (state = drawingD) THEN ChangeState(dormant) ELSE ChangeState(waiting) END;
						END;
					END
				END;
			ELSIF M IS Display.ControlMsg THEN
				WITH M: Display.ControlMsg DO
					IF (M.id=Display.restore)&(V.W > 0)&(V.H > 0) THEN
						Oberon.RemoveMarks(V.X, V.Y, V.W, V.H);
					END
				END
			ELSIF M IS Display.ModifyMsg THEN
				WITH M: Display.ModifyMsg DO
					IF (M.F=V)&(M.id=Display.extend) THEN
						Oberon.RemoveMarks(V.X, M.Y, V.W, V.Y-M.Y);
					END
				END
			END
		END
	END HandleFiller;


	PROCEDURE TaskHandler(task: Oberon.Task);
		VAR x, y: SIGNED16; keys: SET; now: SIGNED32;
	BEGIN
		now := Input.Time();
		CASE state OF
		| dormant:
			task.time := MAX(SIGNED32);
		| waiting:
			Input.Mouse(keys, x, y);
			IF (ABS(x - oldMouseX) > mouseTolerance) OR (ABS(y - oldMouseY) > mouseTolerance) THEN
				oldMouseX := x; oldMouseY := y;
				waitLimit := now + waitTime;
			END;
			IF (waitLimit - now) < 0 THEN
				ChangeState(drawingW);
			ELSE
				task.time := now + waitPeriod;
			END;
			| drawingD, drawingW:
			ASSERT(filler.state IN {1, 0}, 111);
			IF (filler.state = 1) & (Viewers.Next(filler) = filler) THEN
				Step; task.time := now + drawPeriod
			ELSIF state = drawingW THEN
				ChangeState(waiting)
			ELSIF state = drawingD THEN
				ChangeState(dormant)
			END;
		END;
	END TaskHandler;


	PROCEDURE ChangeState(newState: SIGNED16);
		VAR
			(* filler: Viewers.Viewer; *)
			keys: SET;
	BEGIN
		CASE newState OF
		| dormant: ASSERT(state IN {drawingD, waiting}, 111);
			IF state = drawingD THEN
				Stop;
				IF (filler.state = 1) & (Viewers.Next(filler) = filler) THEN Viewers.CloseTrack(filler.X) END;
			END;
			task.time := MAX(SIGNED32);
		| waiting: ASSERT(state IN {drawingW, dormant}, 112);
			IF state = drawingW THEN
				Stop;
				IF (filler.state = 1) & (Viewers.Next(filler) = filler) THEN Viewers.CloseTrack(filler.X) END;
			END;
			task.time := Input.Time() + waitPeriod;
			waitLimit := Input.Time() + waitTime;
		| drawingD, drawingW:
			ASSERT((state = dormant) & (newState = drawingD) OR (state = waiting) & (newState = drawingW), 113);
			Oberon.RemoveMarks(Display.Left, Display.Bottom, Display.Width, Display.Height);
			NEW(filler); filler.handle := HandleFiller;
			Viewers.OpenTrack(Display.Left, Display.Width, filler);
			task.time := Input.Time() + drawPeriod;
			Start;
			Input.Mouse(keys, oldMouseX, oldMouseY);	(* spoof mouse for drawingD *)
		END;
		state := newState;
	END ChangeState;


(* Default screen saver defined *)

	PROCEDURE StartDefault;
	BEGIN
		SetFrameRate(5);
		Display.ReplConst(Display.FG,
			Display.Left, Display.Bottom, Display.Width, Display.Height,
			Display.replace);
	END StartDefault;

	PROCEDURE StepDefault;
	END StepDefault;

	PROCEDURE StopDefault;
	END StopDefault;


(* Screen saver configuration calls & Commands *)

	PROCEDURE SetWaitTime* (seconds: SIGNED32);
		CONST day = 60 * 60 * 24;
	BEGIN
		IF seconds < 15 THEN seconds := 15
		ELSIF seconds > day THEN seconds := day
		END;
		waitTime := seconds * Input.TimeUnit;
	END SetWaitTime;

	PROCEDURE SetFrameRate* (framesPerSecond: SIGNED16);
	BEGIN
		IF framesPerSecond < 1 THEN framesPerSecond := 1
		ELSIF framesPerSecond > 30 THEN framesPerSecond := 30
		END;
		drawPeriod := Input.TimeUnit DIV framesPerSecond;
	END SetFrameRate;

	PROCEDURE InstallFader*(newStart, newStep, newStop: FaderProc);
	BEGIN
		ASSERT((newStart # NIL) & (newStep # NIL) & (newStop # NIL), 102);
		IF (state IN {drawingW, drawingD}) THEN
			Stop;
			newStart;
		END;
		Start := newStart;
		Step := newStep;
		Stop := newStop;
	END InstallFader;

	(* re-installs the default fader *)

	PROCEDURE InstallDefault*;
	BEGIN
		InstallFader(StartDefault, StepDefault, StopDefault);
	END InstallDefault;


	(* RemoveFader: If the start, step, stop is the currently installed fader, it will be removed
	and replaced with the default fader.  This should be once for each fader by
	the termination handler of a module providing faders. *)

	PROCEDURE RemoveFader*(start, step, stop: FaderProc);
	BEGIN
		IF (start = Start) & (step = Step) & (stop = Stop) THEN
			InstallDefault;
		END;
	END RemoveFader;


(* User commands *)

	PROCEDURE InstallTask;	(* [re]installs the background task *)
	BEGIN
		IF task = NIL THEN NEW(task) ELSE Oberon.Remove(task)  END;
		task.handle := TaskHandler;
		task.time := Input.Time();
		task.safe := FALSE;
		Oberon.Install(task);
		CASE state OF
		| drawingW: ChangeState(waiting);
		| drawingD: ChangeState(dormant);
		| waiting: (* do nothing *)
		| dormant: (* do nothing *)
		| nostate: state := waiting;
		END;
	END InstallTask;

	PROCEDURE Deactivate*;
	BEGIN
		IF (state IN {waiting, drawingD} )THEN
			ChangeState(dormant)
		ELSIF (state = drawingW) THEN
			ChangeState(waiting);
			ChangeState(dormant)
		END;
	END Deactivate;

	PROCEDURE Activate*;	(** minutesToWait:SIGNED16 *)
		VAR wait: SIGNED16;
	BEGIN
		InstallTask;	(* just in case our task has been killed by a TRAP *)
		In.Open; In.Int(wait);
		IF In.Done THEN SetWaitTime(LONG(wait)*60) ELSE SetWaitTime(30 * 60) END;
		IF (state IN {drawingW, dormant} )THEN
			ChangeState(waiting)
		ELSIF (state = drawingD) THEN
			ChangeState(dormant);
			ChangeState(waiting)
		END;
	END Activate;

	PROCEDURE Run*;
	BEGIN InstallTask;
		IF (state = dormant) THEN ChangeState(drawingD)
		ELSIF (state = waiting) THEN ChangeState(drawingW)
		END;
	END Run;

	PROCEDURE Cleanup;
	BEGIN
		Deactivate;
		Oberon.Remove(task);
		task := NIL;
	END Cleanup;


BEGIN
	state := nostate;
	Texts.OpenWriter(W);
	seed := Input.Time();
	SetWaitTime(defWaitTime);
	SetFrameRate(defFrameRate);
	waitPeriod := Input.TimeUnit * defWaitPeriod;
	InstallTask;
	InstallFader(StartDefault, StepDefault, StopDefault);
	Modules.InstallTermHandler(Cleanup);
	Msg(versionString);
END SaveScreen.

SaveScreen.Run
SaveScreen.Activate 1
SaveScreen.Deactivate
SaveParticles.Install frameRate 20 speed 6 origin 0 particleCount 256 ~
SaveParticles.Configuration
SaveTiles.Install

System.Free SaveParticles SaveTiles SaveScreen ~