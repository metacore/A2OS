(* ETH Oberon, Copyright 2001 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

MODULE ColorDriver IN Oberon; (** portable *)
IMPORT Display;

TYPE
	ColorMsg* = RECORD (Display.FrameMsg)
		col*: SIGNED16
	END;

VAR Color: SIGNED16;

PROCEDURE NextCol*;
VAR M: ColorMsg;
BEGIN
	Color := (Color + 1) MOD 4;
	M.F := NIL; M.col := Color; Display.Broadcast(M)
END NextCol;

BEGIN Color := 1
END ColorDriver.

ColorDriver.NextCol

The color could also be controlled by a background task by replacing the ColorDriver module by:

MODULE ColorDriver;
IMPORT Display, Input, Modules, Oberon;
TYPE
	ColorMsg* = RECORD (Display.FrameMsg)
		col*: SIGNED16
	END;
VAR Color: SIGNED16; task : Oberon.Task;

PROCEDURE ColorTask(me: Oberon.Task);
VAR M: ColorMsg;
BEGIN
	Color := (Color + 1) MOD 4;
	M.F := NIL; M.col := Color; Display.Broadcast(M);
	me.time := Input.Time() + Input.TimeUnit * 3
END ColorTask;

PROCEDURE Cleanup;
BEGIN
	Oberon.Remove(task)
END Cleanup;

BEGIN
	Color := 1;
	NEW(task); task.handle := ColorTask; task.safe := TRUE; task.time := Oberon.Time(); Oberon.Install(task);
	Modules.InstallTermHandler(Cleanup)
END ColorDriver.
