(**  AUTHOR "BohdanT"; PURPOSE "Debugger base";  **)
MODULE Debugger;
IMPORT SYSTEM, Kernel32, Objects, Modules, Reflection, KernelLog, DebuggerBase;
CONST
	Trace = FALSE;

TYPE
	DebugHandler* = PROCEDURE {DELEGATE} ( VAR int: Kernel32.Context;  VAR exc: Kernel32.ExceptionRecord;  VAR handled: BOOLEAN );
VAR
	debughandler:DebugHandler;
	exceptionhandler: Objects.ExceptionHandler; (*Save system handler here*)
VAR
	brkPnt*:BPList;
TYPE	
	BPList* = OBJECT(DebuggerBase.BPList)
	VAR
		list*,
		tmp*:DebuggerBase.BrkPnt;
		PROCEDURE &Init*;
		BEGIN
			Init^;
		END Init;
		
		PROCEDURE SetBrk*(bp:DebuggerBase.BrkPnt);
		BEGIN
			IF active THEN
(*				KernelLog.String("active"); KernelLog.Ln; *)
				SYSTEM.GET(bp.adr, bp.c);
				SYSTEM.PUT(bp.adr, 0CCX);
			END
		END SetBrk;

		PROCEDURE ClrBrk*(bp:DebuggerBase.BrkPnt);
		BEGIN
(*				KernelLog.String("clear "); KernelLog.Ln; *)
				SYSTEM.PUT(bp.adr, bp.c);
		END ClrBrk;
	END BPList;

PROCEDURE FindEIPByModulePC*(CONST modn:ARRAY OF CHAR;PC:LONGINT):LONGINT;
VAR
	m : Modules.Module; 
BEGIN
	m := Modules.root;
	WHILE (m # NIL) & (m.name # modn) DO m := m.next END;
	IF m # NIL THEN
	   RETURN PC+SYSTEM.ADR(m.code[0]);
        ELSE
          RETURN -1;
        END;
END FindEIPByModulePC;

PROCEDURE NewObjectFile*(refs: Modules.Bytes): BOOLEAN;
BEGIN
	RETURN (refs # NIL) & (LEN(refs) >0) & (refs[0]=0FFX);
END NewObjectFile;


(* Debbuger exception handler. *)
PROCEDURE Exception( VAR int: Kernel32.Context;  VAR exc: Kernel32.ExceptionRecord;  VAR handled: BOOLEAN );
BEGIN  (* interrupts off *)
		handled := FALSE;
		IF Trace THEN KernelLog.String("Debug exception handler! "); KernelLog.Ln; END;
		IF debughandler#NIL THEN
			debughandler(int,exc,handled);
			IF Trace THEN KernelLog.String("user complit! "); KernelLog.Ln; END;
		END;
		IF (~handled)&(exceptionhandler#NIL) THEN
			IF Trace THEN KernelLog.String("do system! "); KernelLog.Ln; END;
			exceptionhandler(int,exc,handled);
		END;
FINALLY
		(* if trap occurs in this procedure, then go on working right here *)
(*		KernelLog.String("Houston, we have a problem!"); KernelLog.Ln; *)
END Exception;

PROCEDURE Install*;
VAR
	adr:ADDRESS;
BEGIN
	HALT(18);
(*! TODO	GetProcedure('Traps', 'Exception',adr);*)
	exceptionhandler:=SYSTEM.VAL(Objects.ExceptionHandler,adr);
	Objects.InstallExceptionHandler( Exception );
END Install;

(** *)
PROCEDURE InstallDbgHandler*(hndlr:DebugHandler);
BEGIN
	debughandler:=hndlr;
	Install();
END InstallDbgHandler;

PROCEDURE RemoveDbgHandler*();
BEGIN
	debughandler:=NIL;
END RemoveDbgHandler;

(** Termination handler. Removes the window from the display space when the module is unloaded. *)
PROCEDURE Cleanup;	(* K *)
BEGIN
		IF exceptionhandler#NIL THEN
			Objects.InstallExceptionHandler( exceptionhandler );
			KernelLog.String( "Traps: TrapHandler Restored!" );  KernelLog.Ln;
		ELSE
			KernelLog.String( "Not need to restore traps handler !" );  KernelLog.Ln;
		END;
END Cleanup;

BEGIN
	Modules.InstallTermHandler(Cleanup);
	NEW(brkPnt);
END Debugger.


DebuggerBase.Install~
SystemTools.Free  DebuggerBase ~