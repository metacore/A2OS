(* Aos, Copyright 2001, Pieter Muller, ETH Zurich *)

MODULE Beep; (** AUTHOR "pjm"; PURPOSE "PC speaker driver"; *)

IMPORT X11, Displays, XDisplay, Plugins, Machine;

VAR
	disp: XDisplay.Display;

	PROCEDURE Beep*( hz: INTEGER );
	BEGIN
		Machine.Acquire(Machine.X11);
		IF disp = NIL THEN GetDisplay END;
		X11.Bell( disp.xdisp, 100 );
		Machine.Release(Machine.X11);
	END Beep;

	PROCEDURE GetDisplay;
	VAR p: Plugins.Plugin;
	BEGIN
		p := Displays.registry.Await( "XDisplay" );
		disp := p(XDisplay.Display)
	END GetDisplay;

END Beep.
