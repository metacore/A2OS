MODULE StartConsole; (** AUTHOR ""; PURPOSE ""; *)

IMPORT EFIGraphicalConsole, Machine, Trace;

VAR fbadr: ADDRESS; 
	
	PROCEDURE {INITIAL} First ;
	BEGIN
		Trace.String("first ? "); Trace.Ln; 
		Trace.Address(Machine.fbadr);  Trace.Ln;
		Machine.MapPhysical(Machine.fbadr, 	1024*768*4, fbadr); 
		Trace.Address(fbadr);  Trace.Ln;
		EFIGraphicalConsole.Init;
		EFIGraphicalConsole.SetupConsole(Machine.fbInfoPtr, fbadr);
	END First;
		
BEGIN
	(*EFIGraphicalConsole.SetupConsole(Machine.fbInfoPtr, Machine.fbadr);*)
END StartConsole.
