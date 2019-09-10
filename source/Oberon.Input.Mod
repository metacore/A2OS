(* Aos, Copyright 2001, Pieter Muller, ETH Zurich *)

MODULE Input IN Oberon;	(** portable, except where noted *)
(** AUTHOR "pjm"; PURPOSE "Oberon for Aos input driver"; *)

(**
Module Input is responsible for event timing, mouse and keyboard input.
*)

IMPORT SYSTEM, KernelLog IN A2, Kernel IN A2, Plugins IN A2, Inputs IN A2, Display;

CONST
	TimeUnit* = 1000;	(** portable, but VAR on other ports *)	(** timer ticks per second (platform dependent). *)

	SHIFT* = 0;  CTRL* = 1;  ALT* = 2;	(** for KeyState *)

	Trace = FALSE;

VAR
	minX, minY, maxX, maxY: SIGNED32;
	input: Inputs.OberonInput;

(** Returns the number of keystrokes in the keyboard input buffer. *)
PROCEDURE Available*(): SIGNED16;
VAR num: SIGNED16; break: BOOLEAN;
BEGIN
	input.Available(num, break);
	IF break THEN Display.Update; SYSTEM.HALT(13) END;
	IF num = 0 THEN Display.Update END;
	RETURN num
END Available;

(** Reads the current mouse position x, y and the key state of the mouse buttons (also called keys). The mouse buttons are numbered from the right to the left as 0, 1, 2 (i.e. 1 is the middle mouse button). For example, when the left and middle
buttons are pressed, keys will be set to {1, 2}. *)
PROCEDURE Mouse*(VAR keys: SET; VAR x, y: SIGNED16);
BEGIN
	IF Trace THEN KernelLog.String("Mouse") END;
	IF x < minX THEN x := SHORT(minX) ELSIF x > maxX THEN x := SHORT(maxX) END;
	IF y < minY THEN y := SHORT(minY) ELSIF y > maxY THEN y := SHORT(maxY) END;

	input.Mouse(x, y, keys);
	Display.Update;

	y := (Display.Height - 1) - y;
	IF x >= Display.Width THEN x := Display.Width - 1 ELSIF x < 0 THEN x := 0 END;
	IF y >= Display.Height THEN y := Display.Height-1 ELSIF y < 0 THEN y := 0 END;
	IF Trace THEN KernelLog.Int(x, 5); KernelLog.Int(y, 5); KernelLog.Ln END
END Mouse;

(** Read a character from the keyboard buffer. Blocks if no character is available. *)
PROCEDURE Read*(VAR ch: CHAR);
VAR break: BOOLEAN;
BEGIN
	IF Trace THEN KernelLog.String("Read") END;
	input.Read(ch, break);
	Display.Update;
	IF break THEN SYSTEM.HALT(13) END;
	IF Trace THEN KernelLog.Int(ORD(ch), 4); KernelLog.Ln END
END Read;

(** Returns the elapsed number of ticks since Oberon startup. *)
PROCEDURE Time*(): SIGNED32;
BEGIN
	RETURN Kernel.GetTicks()
END  Time;

(** Return the state of the shift keys. *)
PROCEDURE KeyState*(VAR keys: SET);
BEGIN
	input.KeyState(keys);
	Display.Update
END KeyState;

(** Await - Wait delay TimeUnits or until next input event. *)

PROCEDURE Await*(delay: SIGNED32);
BEGIN
	IF Trace THEN KernelLog.String("Await") END;
	input.timer.Sleep(delay);
	IF Trace THEN KernelLog.Ln END
END Await;

(** Restricts the extent of the mouse coordinates returned by Mouse. *)
PROCEDURE SetMouseLimits*(x, y, w, h: SIGNED16);	(** non-portable *)
BEGIN
	y := Display.Height-1 - y;
	minX := x; minY := y; maxX := x+w; maxY := y+h
END SetMouseLimits;

PROCEDURE Init*(x: SIGNED32);
VAR p: Plugins.Plugin;
BEGIN
	IF x = 0BEH THEN	(* magic re-initialization *)
		p := Inputs.oberonInput.Await("Oberon")
	ELSE
		p := Inputs.oberonInput.Await("")
	END;
	input := p(Inputs.OberonInput)
END Init;

BEGIN
	ASSERT(Kernel.second = TimeUnit);	(* for Time() *)
	ASSERT((SHIFT = Inputs.SHIFT) & (CTRL = Inputs.CTRL) & (ALT = Inputs.ALT));
	Init(0);
	SetMouseLimits(0, 0, Display.Width, Display.Height)
END Input.

(** Remarks:

1. Keyboard character codes correspond to the ASCII character set.
Some other important codes are:

	F1, SETUP	0A4X
	F2, NEUTRALISE	0A5X
	F3, SCRL	0A6X	(used in Draw)
	F4, NOSCRL	0A7X	(used in Draw)
	UP ARROW	0C1X
	RIGHT ARROW	0C3X
	DOWN ARROW	0C2X
	LEFT ARROW	0C4X
	INSERT	0A0X
	DELETE	0A1X
	PAGE-UP	0A2X
	PAGE-DOWN	0A3X
	ä, Ä	131, 128
	ö, Ö	132, 129
	ü, Ü	133, 130
	ß	150

The module EditKeys allows you to determine the keyboard code of any key pressed.
For cross-platform portability, Oberon does not normally support all keys available
on your keyboard.
*)

(*
to do:
o serial mouse
o middle button emulation
o mouse key mapping
*)
