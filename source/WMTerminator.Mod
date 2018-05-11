MODULE WMTerminator;  (** AUTHOR "GF"; PURPOSE "terminate A2"; *)

IMPORT Modules, WMDialogs, Commands, Kernel;

CONST
	Ok = WMDialogs.ResOk;
	Abort = WMDialogs.ResAbort;	

PROCEDURE Shutdown*;
VAR res: LONGINT;  msg: ARRAY 128 OF CHAR;
	t: Kernel.Timer;
BEGIN 
	NEW( t );
	IF  WMDialogs.Message( 1, "A2 terminator", "  Are you sure you want to stop A2 execution ?", {Ok, Abort} ) = Ok THEN
		Commands.Call( "WMTerminator.Do", {}, res, msg );
		
		(* in case the termination handler (Modules.Shutdown) hangs, retry!*)
		t.Sleep( 1000 );
		Commands.Call( "WMTerminator.Do", {}, res, msg );
	END;
END Shutdown;

PROCEDURE Do*;
BEGIN
	Modules.Shutdown( Modules.PowerDown );
END Do;

END WMTerminator.