MODULE Display;

IMPORT Commands;

PROCEDURE Install*;
VAR msg: ARRAY 256 OF CHAR; res: WORD;
BEGIN
	Commands.Call("XDisplay.Install", {Commands.Wait}, res, msg);
	Commands.Call("KbdMouse.Init", {Commands.Wait}, res, msg);
END Install;

END Display.

