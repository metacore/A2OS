(* ETH Oberon, Copyright 2001 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

(*
SaveDecay: A Sample fader for SaveScreen.
1999.11.05 - Ben Smith-Mannschott
	- initial release
*)

MODULE SaveDecay IN Oberon;

	IMPORT Out, Modules, SaveScreen, Display;
	CONST
		versionString = "SaveDecay 1999.11.05";

	VAR
		depth: ARRAY 1280 OF SIGNED16;

	PROCEDURE Start;
		VAR i: SIGNED16;
	BEGIN
		SaveScreen.SetFrameRate(30);
		FOR i := 0 TO Display.Width - 1 DO
			depth[i] := Display.Height
		END;
	END Start;

	PROCEDURE Step;
		VAR
			i, x: SIGNED16;
	BEGIN
		FOR i := 1 TO 128  DO
			x := SaveScreen.Rand(Display.Width);
			DEC(depth[x]);
			IF depth[x] < 0 THEN depth[x] := 0 END;
			Display.Dot(Display.FG, x, depth[x], Display.replace);
		END;
	END Step;

	PROCEDURE Stop;
	END Stop;

	PROCEDURE Install*;
	BEGIN
		SaveScreen.InstallFader(Start, Step, Stop);
	END Install;

	PROCEDURE Remove;
	BEGIN
		SaveScreen.RemoveFader(Start, Step, Stop);
	END Remove;

BEGIN
	Modules.InstallTermHandler(Remove);
	Out.String(versionString); Out.Ln;
END SaveDecay.Install