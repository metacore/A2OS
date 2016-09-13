MODULE StdIOShell; (** AUTHOR ""; PURPOSE ""; *)

IMPORT StdIO, Commands, Streams, Modules, Objects, Shell;

PROCEDURE Execute(context: Commands.Context);
VAR str, msg: ARRAY 256 OF CHAR;  res: LONGINT; shell: Shell.Shell; 
BEGIN
	IF ~context.arg.GetString(str) THEN  
		context.out.String("Critical error: no arg"); 
		RETURN END;
	IF ~context.arg.GetString(str) THEN 
		NEW(shell, context.in, context.out, context.error, FALSE, ">"); 
		shell.AwaitDeath;
		RETURN
	END;
	IF str = "compile" THEN str := "Compiler.Compile"
	ELSIF str="link" THEN str := "StaticLinker.Link"
	ELSIF (str="i") OR (str = "interpreter") THEN str := "InterpreterShell.Start"
	END;

	Commands.Activate(str, context, {Commands.Wait}, res, msg);
	IF res # 0 THEN context.error.String(msg) END;
END Execute;

BEGIN
	Execute(StdIO.env);
	Modules.Shutdown(Modules.PowerDown);
END StdIOShell.


(** LINUX **)

SystemTools.DoCommands
	Compiler.Compile -p=Linux32G --traceModule=Trace
		Runtime.Mod Trace.Mod Generic.Linux.I386.Glue.Mod Generic.Linux.I386.Unix.Mod Generic.Unix.I386.Machine.Mod Heaps.Mod  Generic.Modules.Mod 
		Generic.Unix.Objects.Mod 
		Unix.Kernel.Mod KernelLog.Mod Plugins.Mod Streams.Mod 
		Pipes.Mod Commands.Mod I386.Reals.Mod Generic.Reflection.Mod TrapWriters.Mod CRC.Mod SystemVersion.Mod 
		Unix.StdIO.Mod Generic.Unix.Traps.Mod Locks.Mod Unix.Clock.Mod Disks.Mod Files.Mod Dates.Mod Strings.Mod 
		UTF8Strings.Mod FileTrapWriter.Mod Caches.Mod DiskVolumes.Mod OldDiskVolumes.Mod RAMVolumes.Mod 
		DiskFS.Mod OldDiskFS.Mod OberonFS.Mod FATVolumes.Mod FATFiles.Mod ISO9660Volumes.Mod 
		ISO9660Files.Mod Unix.UnixFiles.Mod RelativeFileSystem.Mod BitSets.Mod StringPool.Mod DIagnostics.Mod ObjectFile.Mod GenericLinker.Mod GenericLoader.Mod Unix.BootConsole.Mod 
		Pipes.Mod Shell.Mod StdIOShell.Mod  
		~

	StaticLinker.Link --fileFormat=Raw --fileName=oberon --extension=.GofU --displacement=08048000H
		Runtime Trace Glue Unix Machine Heaps Modules Objects Kernel KernelLog 
		Streams Commands StdIO TrapWriters Traps 
		Files UnixFiles Clock Dates Reals Strings Diagnostics 
		BitSets StringPool ObjectFile GenericLinker Reflection  GenericLoader  
		Pipes Shell StdIOShell
	~

	FSTools.CloseFiles oberon ~
~ 


(** WINDOWS **)
SystemTools.DoCommands

	Compiler.Compile  -p=Win32G
		Runtime.Mod Trace.Mod Generic.Win32.Kernel32.Mod Win32.Machine.Mod Heaps.Mod 
		Generic.Modules.Mod Win32.Objects.Mod Win32.Kernel.Mod KernelLog.Mod Streams.Mod Commands.Mod 
		I386.Reals.Mod Reflection.Mod Locks.Mod Win32.Clock.Mod Files.Mod Dates.Mod Strings.Mod 

		Diagnostics.Mod StringPool.Mod BitSets.Mod ObjectFile.Mod 
		GenericLinker.Mod GenericLoader.Mod Options.Mod Debugging.Mod
		
		Win32.WinTrace.Mod Win32.WinFS.Mod 
		Win32.StdIO.Mod Pipes.Mod Shell.Mod StdIOShell.Mod

		StaticLinker.Mod
		FoxBasic.Mod  FoxProgTools.Mod  FoxScanner.Mod FoxCSharpScanner.Mod FoxSyntaxTree.Mod FoxGlobal.Mod
		FoxActiveCells.Mod FoxHardware.Mod FoxFormats.Mod FoxPrintout.Mod
		FoxParser.Mod FoxCSharpParser.Mod  FoxSemanticChecker.Mod
		FoxBackend.Mod FoxSections.Mod 
		FoxFrontend.Mod FoxOberonFrontend.Mod FoxCSharpFrontend.Mod
		FoxCompiler.Mod FoxFingerPrinter.Mod  FoxInterfaceComparison.Mod FoxTextualSymbolFile.Mod FoxBinarySymbolFile.Mod
		FoxBinaryCode.Mod FoxIntermediateCode.Mod FoxIntermediateBackend.Mod FoxCodeGenerators.Mod
		FoxBinaryObjectFile.Mod FoxGenericObjectFile.Mod
		FoxAMD64InstructionSet.Mod FoxAMD64Assembler.Mod FoxAMDBackend.Mod
		FoxAssembler.Mod FoxIntermediateAssembler.Mod FoxDisassembler.Mod
		FoxARMInstructionSet.Mod FoxARMAssembler.Mod FoxARMBackend.Mod	FoxMinosObjectFile.Mod
		FoxIntermediateParser.Mod FoxIntermediateObjectFile.Mod FoxIntermediateLinker.Mod 
		FoxTRMInstructionSet.Mod FoxTRMAssembler.Mod FoxTRMBackend.Mod
		FoxInterpreterBackend.Mod FoxTranspilerBackend.Mod
		FoxDocumentationScanner.Mod FoxDocumentationTree.Mod FoxDocumentationPrinter.Mod FoxDocumentationHtml.Mod 
		FoxDocumentationParser.Mod FoxDocumentationBackend.Mod

		FoxProfiler.Mod
		~
	

	(* first lines can be replaced by Kernel.lib *) 

	StaticLinker.Link --fileFormat=PE32CUI --fileName=oberon.exe --extension=GofW --displacement=401000H
		Runtime Trace Kernel32 Machine Heaps Modules Objects Kernel KernelLog Streams Commands Files 
		WinFS Clock Dates Reals Strings Diagnostics BitSets StringPool ObjectFile GenericLinker Reflection GenericLoader
		WinTrace StdIO Pipes Shell StdIOShell
		
		Options Locks Debugging
		StaticLinker 
		FoxBasic  FoxProgTools  FoxScanner FoxSyntaxTree FoxGlobal
		FoxActiveCells FoxHardware FoxFormats FoxPrintout
		FoxParser  FoxSemanticChecker
		FoxBackend FoxSections 
		
		FoxFrontend FoxOberonFrontend 
		Compiler FoxFingerPrinter FoxInterfaceComparison FoxTextualSymbolFile FoxBinarySymbolFile
		FoxBinaryCode FoxIntermediateCode FoxIntermediateBackend FoxCodeGenerators
		FoxBinaryObjectFile FoxGenericObjectFile
		FoxAMD64InstructionSet FoxAMD64Assembler FoxAMDBackend

		
		FoxAssembler FoxIntermediateAssembler FoxDisassembler
		FoxARMInstructionSet FoxARMAssembler FoxARMBackend	

		FoxMinosObjectFile

		FoxIntermediateParser FoxIntermediateObjectFile FoxIntermediateLinker 
		FoxTRMInstructionSet FoxTRMAssembler FoxTRMBackend
		FoxInterpreterBackend FoxTranspilerBackend
		FoxDocumentationScanner FoxDocumentationTree FoxDocumentationPrinter FoxDocumentationHtml 
		FoxDocumentationParser FoxDocumentationBackend
		
		SystemTools
	~
	
	FSTools.CloseFiles oberon.exe ~
~


	FoxGenericObjectFile.MakeLibrary 
		Kernel.Lib Runtime.GofW Trace.GofW
		Kernel32.GofW Machine.GofW Heaps.GofW Modules.GofW Objects.GofW
		Kernel.GofW KernelLog.GofW Streams.GofW Commands.GofW Files.GofW 
		WinFS.GofW Clock.GofW Dates.GofW Reals.GofW Strings.GofW Diagnostics.GofW BitSets.GofW StringPool.GofW ObjectFile.GofW GenericLinker.GofW Reflection.GofW 
		GenericLoader.GofW
		WinTrace.GofW WinApplication.GofW
		~ 
	~
