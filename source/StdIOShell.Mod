MODULE StdIOShell; (** AUTHOR "Felix Friedrich"; PURPOSE "Command shell for standalone Oberon/A2 Applications"; *)

IMPORT StdIO, Commands, Modules, Trace;

CONST Verbose = FALSE;

PROCEDURE Activate(context: Commands.Context; CONST cmd: ARRAY OF CHAR): BOOLEAN;
VAR msg: ARRAY 256 OF CHAR;  res: LONGINT; 
BEGIN
	IF Verbose THEN 
		Trace.String("StdIOShell: Activate Command "); Trace.String(cmd); Trace.Ln; 
	END;
	Commands.Activate(cmd, context, {Commands.Wait}, res, msg);
	IF res # 0 THEN context.error.String(msg); context.error.Ln; RETURN FALSE END;
	RETURN TRUE;
END Activate;

PROCEDURE Execute(context: Commands.Context): BOOLEAN;
VAR str: ARRAY 256 OF CHAR;
BEGIN
	IF ~context.arg.GetString(str) THEN  
		context.out.String("Critical error: no arg"); 
		RETURN FALSE;
	END;
	IF ~context.arg.GetString(str) THEN 
		str := "Shell.Start";
	ELSIF (str = "compile") THEN str := "Compiler.Compile";
	ELSIF (str = "link") THEN str := "Linker.Link";
	ELSIF (str = "interpreter") OR (str = "i") THEN str := "InterpreterShell.Start";
	ELSIF (str = "execute") OR (str = "e") THEN str := "SystemTools.DoFile";
	ELSIF (str = "do") OR (str = "d") THEN str := "SystemTools.DoCommands";
	ELSIF (str = "run") OR (str = "r") THEN 
		IF ~Activate(context, "SystemTools.DoFile") THEN RETURN FALSE END;
		str := "Shell.Start";
	END;
	RETURN Activate(context, str);
END Execute;

TYPE 
	(* excute the shell and termination in separate thread with proper process data structure *)
	Executor=OBJECT
	VAR done := FALSE: BOOLEAN;
	VAR code := Modules.PowerDown: LONGINT;

		PROCEDURE Wait;
		BEGIN{EXCLUSIVE}
			AWAIT(done);
		END Wait;
		
	BEGIN{ACTIVE}
		IF Execute(StdIO.env) THEN code := Modules.Reboot END;
	FINALLY
		IF Verbose THEN
			Trace.String("StdIOShell: Exit"); Trace.Ln;
		END;
		Modules.Shutdown(code);
		done := TRUE
	END Executor;

VAR execute: Executor;

(* do not add commands here -- the module loader does not finish here and they will not become available *)
BEGIN	
	NEW(execute); (* execute shell and termination in separate thread *)
	execute.Wait; (* will actually never return *)
END StdIOShell.

Linking a command line shell:

Command line shell: (Windows):
Linker.Link  --fileFormat=PE32CUI --fileName=oberon.exe --extension=GofW --displacement=401000H Runtime Trace Kernel32 Machine Heaps Modules Objects Kernel KernelLog Streams Commands Files  WinFS Clock Dates Reals Strings Diagnostics BitSets StringPool ObjectFile GenericLinker Reflection Loader WinTrace StdIO  Traps RelativeFileSystem WMDefaultFont SystemTools Shell StdIOShell ~

Command line shell including compiler (and linker)
Linker.Link  --fileFormat=PE32CUI --fileName=oberon.exe --extension=GofW --displacement=401000H Runtime Trace Kernel32 Machine Heaps Modules Objects Kernel KernelLog Streams Commands Files  WinFS Clock Dates Reals Strings Diagnostics BitSets StringPool ObjectFile GenericLinker Reflection Loader WinTrace StdIO  Traps RelativeFileSystem SystemTools FSTools StdIOShell 
Shell Linker Compiler FoxOberonFrontend FoxARMBackend FoxAMDBackend
~


Command line shell: (Linux):
Linker.Link -p=Linux32 Runtime Trace Glue Unix Machine Heaps Modules Objects Kernel KernelLog  Streams Commands Pipes StdIO TrapWriters Reflection Traps Files UnixFiles Clock Dates Reals Strings Diagnostics BitSets StringPool ObjectFile GenericLinker   Loader Shell SystemTools StdIOShell ~

Command line shell including compiler (and linker)
Linker.Link -p=Linux32 Runtime Trace Glue Unix Machine Heaps Modules Objects Kernel KernelLog  Streams Commands Pipes StdIO TrapWriters Reflection Traps Files UnixFiles Clock Dates Reals Strings Diagnostics BitSets StringPool ObjectFile GenericLinker   Loader Shell SystemTools StdIOShell 
Linker Compiler FoxOberonFrontend FoxARMBackend FoxAMDBackend
~

