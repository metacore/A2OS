(* Aos, Copyright 2001, Pieter Muller, ETH Zurich *)

MODULE DisplayNull; (** AUTHOR "pjm"; PURPOSE "Null display driver"; *)

IMPORT Displays, KernelLog;

CONST
	Trace = TRUE;

TYPE
	Display* = OBJECT (Displays.Display)

		PROCEDURE &Init*;
		BEGIN
			width := 1024; height := 768; offscreen := 0;
			format := Displays.color565; unit := 10000
		END Init;

		PROCEDURE Transfer*(VAR buf: ARRAY OF CHAR; ofs, stride, x, y, w, h, op: LONGINT);
		END Transfer;

		PROCEDURE Fill*(col, x, y, w, h: LONGINT);
		END Fill;

		PROCEDURE Dot*(col, x, y: LONGINT);
		END Dot;

		PROCEDURE Mask*(VAR buf: ARRAY OF CHAR; bitofs, stride, fg, bg, x, y, w, h: LONGINT);
		END Mask;

		PROCEDURE Copy*(sx, sy, w, h, dx, dy: LONGINT);
		END Copy;

	END Display;

PROCEDURE Install*;
VAR d: Display; res: WORD;
BEGIN
	NEW(d); d.desc := "Null display driver";
	Displays.registry.Add(d, res);
	ASSERT(res = 0);
	IF Trace THEN
		KernelLog.Enter; KernelLog.String("Null display driver"); KernelLog.Exit
	END
END Install;

BEGIN
	Install
END DisplayNull.
