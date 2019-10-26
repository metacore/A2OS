MODULE StdIO;	(** AUTHOR gf;  PURPOSE "Unix standard IO and argument channels *)

(* Commands.Context for programs running outside Aos *)

IMPORT S := SYSTEM, Modules, Commands, Streams, Pipes, WinTrace, Kernel32;

CONST
	Echo* = FALSE;
TYPE
	String=POINTER TO ARRAY OF CHAR;
VAR
	env-: Commands.Context;

	hin-, hout-, herr-: Kernel32.HANDLE;
	stdInDecoupler: Pipes.ReadDecoupler;


PROCEDURE Args(): String;
VAR size, pos: SIZE; i,j: SIGNED32; str: String;
	cmdLine {UNTRACED}: POINTER {UNSAFE} TO ARRAY MAX(SIZE) OF CHAR;
BEGIN
	cmdLine := Kernel32.GetCommandLine();
	pos := 0;
	WHILE cmdLine[pos] # 0X DO
		INC(pos);
	END;
	size := pos + 1;
	NEW(str, size);
	pos := 0;
	WHILE cmdLine[pos] # 0X DO
		str[pos] := cmdLine[pos];
		INC(pos);
	END;
	str[pos] := 0X;
	RETURN str;
END Args;

PROCEDURE Cleanup;
BEGIN
	env.error.Update;
	env.out.Update
END Cleanup;

PROCEDURE Setup;
VAR
	arg: Streams.StringReader;
	stdin: Streams.Reader;
	stdout: Streams.Writer;
	errout: Streams.Writer;
	str: String;
BEGIN
	WinTrace.OpenConsole;
	str := Args();
	NEW( arg, LEN(str) ); arg.Set(str^);
	NEW(stdInDecoupler, WinTrace.Receive);
	NEW( stdin, stdInDecoupler.Receive, 1024 );
	NEW( stdout, WinTrace.Send, 1024 );
	NEW( errout, WinTrace.SendError, 512 );
	NEW( env, stdin, arg, stdout, errout, NIL );
	Modules.InstallTermHandler( Cleanup )
END Setup

BEGIN
	Setup
END  StdIO.

System.DoCommands

	Compiler.Compile  -b=AMD --bits=32 --objectFileExtension=.Gox --symbolFileExtension=.Syx --mergeSections
		I386.Builtins.Mod Trace.Mod Windows.I386.Kernel32.Mod Windows.I386.Machine.Mod Heaps.Mod
		Modules.Mod Windows.I386.Objects.Mod Windows.Kernel.Mod KernelLog.Mod Streams.Mod Commands.Mod
		I386.Reals.Mod Reflection.Mod Locks.Mod Windows.Clock.Mod Files.Mod Dates.Mod Strings.Mod

		Windows.WinTrace.Mod Windows.WinFS.Mod

		Diagnostics.Mod StringPool.Mod BitSets.Mod ObjectFile.Mod
		GenericLinker.Mod Loader.Mod Options.Mod Debugging.Mod

		Windows.StdIO.Mod 		Pipes.Mod Shell.Mod TestStdIO.Mod



		~


	Linker.Link --fileFormat=PE32CUI --fileName=fox.exe --extension=Gox --displacement=401000H
		Builtins Trace Kernel32 Machine Heaps Modules Objects Kernel KernelLog Streams Commands Files
		WinFS Clock Dates Reals Strings Diagnostics BitSets StringPool ObjectFile GenericLinker Reflection Loader
		WinTrace StdIO Pipes Shell TestStdIO ~

		FSTools.CloseFiles fox.exe ~

	~

