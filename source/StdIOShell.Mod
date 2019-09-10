MODULE StdIOShell; (** AUTHOR "Felix Friedrich"; PURPOSE "Command shell for standalone Oberon/A2 Applications"; *)

IMPORT StdIO, Commands, Modules, Trace;

CONST Verbose = FALSE;

PROCEDURE Activate(context: Commands.Context; CONST cmd: ARRAY OF CHAR): BOOLEAN;
VAR msg: ARRAY 256 OF CHAR;  res: INTEGER;
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
		context.error.String("Critical error: no arg"); context.error.Update;
		RETURN FALSE;
	END;
	IF ~context.arg.GetString(str) THEN
		IF StdIO.Echo THEN str := "Shell.StartEchoed" ELSE str := "Shell.Start" END;
	ELSIF (str = "compile") THEN str := "Compiler.Compile";
	ELSIF (str = "link") THEN str := "Linker.Link";
	ELSIF (str = "interpreter") OR (str = "i") THEN str := "InterpreterShell.Start";
	ELSIF (str = "execute") OR (str = "e") THEN str := "System.DoFile";
	ELSIF (str = "do") OR (str = "d") THEN str := "System.DoCommands";
	ELSIF (str = "run") OR (str = "r") THEN
		IF ~Activate(context, "System.DoFile") THEN RETURN FALSE END;
		str := "Shell.Start";
	END;
	RETURN Activate(context, str);
END Execute;

TYPE
	(* excute the shell and termination in separate thread with proper process data structure *)
	Executor=OBJECT
	VAR done := FALSE: BOOLEAN;
	VAR code := Modules.PowerDown: SIGNED32;

		PROCEDURE Wait;
		BEGIN{EXCLUSIVE}
			AWAIT(done);
		END Wait;

	BEGIN {ACTIVE, EXCLUSIVE}
		IF Execute(StdIO.env) THEN code := Modules.Reboot END;
	FINALLY
		done := TRUE;
	END Executor;

VAR execute: Executor;

(* do not add commands here -- the module loader does not finish here and they will not become available *)
BEGIN
	NEW(execute);
	execute.Wait;
	IF Verbose THEN Trace.String("StdIOShell: Exit"); Trace.Ln END;
	Modules.Shutdown(execute.code);
END StdIOShell.

Linking a command line shell:

Command line shell: (Windows):
Linker.Link  --fileFormat=PE32CUI --fileName=oberon.exe --extension=GofW --displacement=401000H Builtins Trace Kernel32 Machine Heaps Modules Objects Kernel KernelLog Streams Commands Files  WinFS Clock Dates Reals Strings Diagnostics BitSets StringPool ObjectFile GenericLinker Reflection Loader WinTrace StdIO  Traps RelativeFileSystem WMDefaultFont System Shell StdIOShell ~

Command line shell including compiler (and linker)
Linker.Link  --fileFormat=PE32CUI --fileName=oberon.exe --extension=GofW --displacement=401000H Builtins Trace Kernel32 Machine Heaps Modules Objects Kernel KernelLog Streams Commands Files  WinFS Clock Dates Reals Strings Diagnostics BitSets StringPool ObjectFile GenericLinker Reflection Loader WinTrace StdIO  Traps RelativeFileSystem System FSTools StdIOShell
Shell Linker Compiler FoxOberonFrontend FoxARMBackend FoxAMDBackend
~


Command line shell: (Linux):
Linker.Link -p=Linux32 Builtins Trace Glue Unix Machine Heaps Modules Objects Kernel KernelLog  Streams Commands Pipes StdIO TrapWriters Reflection Traps Files UnixFiles Clock Dates Reals Strings Diagnostics BitSets StringPool ObjectFile GenericLinker   Loader Shell System StdIOShell ~

Command line shell including compiler (and linker)
Linker.Link -p=Linux32 Builtins Trace Glue Unix Machine Heaps Modules Objects Kernel KernelLog  Streams Commands Pipes StdIO TrapWriters Reflection Traps Files UnixFiles Clock Dates Reals Strings Diagnostics BitSets StringPool ObjectFile GenericLinker   Loader Shell System StdIOShell
Linker Compiler FoxOberonFrontend FoxARMBackend FoxAMDBackend
~

