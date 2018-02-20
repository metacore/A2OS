(* Aos, Copyright 2001, Pieter Muller, ETH Zurich *)

MODULE OberonInput;	(* pjm *)
(** AUTHOR "pjm"; PURPOSE "Oberon for Aos standalone input driver"; *)

IMPORT KernelLog, Modules, Inputs, Plugins, Displays;

CONST
	BufSize = 32;

TYPE
	DefaultInput = OBJECT (Inputs.OberonInput)
		VAR
			keyboard: KeyboardObj;
			mouse: MouseObj;

		PROCEDURE Mouse*(VAR x, y: INTEGER; VAR keys:SET);
		BEGIN
			mouse.Mouse(x, y, keys)
		END Mouse;

		PROCEDURE Read*(VAR ch: CHAR; VAR break: BOOLEAN);
		BEGIN
			keyboard.Read(ch, break)
		END Read;

		PROCEDURE Available*(VAR num: INTEGER; VAR break: BOOLEAN);
		BEGIN
			keyboard.Available(num, break)
		END Available;

		PROCEDURE KeyState*(VAR k: SET);
		BEGIN
			keyboard.KeyState(k)
		END KeyState;

	END DefaultInput;

TYPE
	KeyboardObj = OBJECT (Inputs.Sink)
		VAR
			input: Inputs.OberonInput;

			head, tail: LONGINT;
			keys: SET;
			break: BOOLEAN;
			buf: ARRAY BufSize OF CHAR;

		PROCEDURE Handle*(VAR msg: Inputs.Message);
		BEGIN {EXCLUSIVE}
			WITH msg: Inputs.KeyboardMsg DO
				keys := {};
				IF msg.flags * Inputs.Shift # {} THEN INCL(keys, Inputs.SHIFT) END;
				IF msg.flags * Inputs.Ctrl # {} THEN INCL(keys, Inputs.CTRL) END;
				IF msg.flags * Inputs.Alt # {} THEN INCL(keys, Inputs.ALT) END;
				IF msg.ch # 0X THEN
					IF (tail+1) MOD BufSize # head THEN
						buf[tail] := msg.ch; tail := (tail+1) MOD BufSize
					END;
					IF input # NIL THEN input.timer.Wakeup END
				ELSIF msg.keysym = Inputs.KsBreak THEN	(* Break *)
					break := TRUE;
					IF input # NIL THEN input.timer.Wakeup END
				ELSE
					(* skip *)
					(* fixme: wake up when key state changed? *)
				END
			END
		END Handle;

		PROCEDURE Read(VAR ch: CHAR; VAR b: BOOLEAN);
		BEGIN {EXCLUSIVE}
			AWAIT(head # tail);
			ch := buf[head]; head := (head+1) MOD BufSize;
			b := break; break := FALSE
		END Read;

		PROCEDURE Available(VAR num: INTEGER; VAR b: BOOLEAN);
		BEGIN {EXCLUSIVE}
			num := SHORT((tail-head) MOD BufSize);
			b := break; break := FALSE
		END Available;

		PROCEDURE KeyState(VAR k: SET);
		BEGIN {EXCLUSIVE}
			k := keys
		END KeyState;

		PROCEDURE &Init*;
		BEGIN
			head := 0; tail := 0; keys := {}; break := FALSE;
			Inputs.keyboard.Register(SELF)
		END Init;

	END KeyboardObj;

TYPE
	MouseObj = OBJECT (Inputs.Sink)
		VAR
			input: Inputs.OberonInput;
			curKeys: SET;
			curX, curY: INTEGER;

		PROCEDURE Handle*(VAR msg: Inputs.Message);
		BEGIN {EXCLUSIVE}
			WITH msg: Inputs.PointerMsg DO
				curKeys := {};
				IF 0 IN msg.keys THEN INCL(curKeys, 2) END;
				IF 1 IN msg.keys THEN INCL(curKeys, 1) END;
				IF 2 IN msg.keys THEN INCL(curKeys, 0) END;
				curX := SHORT(msg.x); curY := SHORT(msg.y)
			END;
			IF input # NIL THEN input.timer.Wakeup END
		END Handle;

		PROCEDURE Mouse(VAR x, y: INTEGER; VAR keys: SET);
		BEGIN {EXCLUSIVE}
			keys := curKeys; x := curX; y := curY
		END Mouse;

		PROCEDURE &Init*;
		BEGIN
			Inputs.pointer.Register(SELF)
		END Init;

	END MouseObj;

VAR
	default: DefaultInput;

PROCEDURE Install*;
VAR res: LONGINT; p: Plugins.Plugin; d: Displays.Display;
BEGIN
	IF default = NIL THEN
		p := Displays.registry.Get("");	(* get first display *)
		IF p # NIL THEN	(* set mouse limits to first physical display (assuming we will use it) *)
			d := p(Displays.Display);
			Inputs.main.SetLimits(d.width, d.height, 0)
		ELSE
			KernelLog.Enter;
			KernelLog.String("Display driver must be installed before OberonInput");
			KernelLog.Exit
		END;
		NEW(default);
		NEW(default.keyboard);
		NEW(default.mouse);
		default.keyboard.input := default; default.mouse.input := default;
		default.desc := "Default Input device";
		Inputs.oberonInput.Add(default, res);
		ASSERT(res = 0)
	END
END Install;

PROCEDURE Remove*;
BEGIN
	IF default # NIL THEN Inputs.oberonInput.Remove(default); default := NIL END;
END Remove;

PROCEDURE SwitchToWM*;
VAR m: Inputs.KeyboardMsg;
BEGIN
	IF default # NIL THEN
			(* send magic key to Oberon (assume Oberon.Loop will read it) *)
		m.ch := 0FEX; m.flags := {}; m.keysym := Inputs.KsNil;
		default.keyboard.Handle(m)
	END
END SwitchToWM;

PROCEDURE Cleanup;
BEGIN
	Remove;
END Cleanup;

BEGIN
	Modules.InstallTermHandler(Cleanup);
	default := NIL; Install
END OberonInput.
