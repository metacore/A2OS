(* Aos, Copyright 2001, Pieter Muller, ETH Zurich *)

MODULE Beep; (** AUTHOR "pjm"; PURPOSE "PC speaker driver"; *)

IMPORT X11, Displays, XDisplay, Plugins;

VAR
	disp: XDisplay.Display;

	PROCEDURE Beep*( hz: WORD );
	BEGIN
		X11.Bell( disp.xdisp, 100 )
	END Beep;

	PROCEDURE GetDisplay;
	VAR p: Plugins.Plugin;
	BEGIN
		p := Displays.registry.Await( "XDisplay" );
		disp := p(XDisplay.Display)
	END GetDisplay;

BEGIN
	GetDisplay
END Beep.
