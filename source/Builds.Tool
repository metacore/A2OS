## initial remarks / caveats
	TextUtilities imports WMGraphics,
	WMGraphics can block when WMDefaultFont is not loaded. Make sure to link WMDefaultFont into images requiring WMGraphics that should work without module loading
	Modules that must be loaded during startup must be linked before IOShell / Bootconsole, respectively

WIN32 -- 32-bit windows a2
=================================

	## Compile all files ##
		Release.Build --path=NewAos/ Win32~
	
	## Link A2.exe (bootconsole for graphical OS) ##
		Linker.Link --path=NewAos/ --fileFormat=PE32 --fileName=A2.exe --extension=GofW --displacement=401000H
			Builtins Trace Kernel32 Machine Heaps Modules Objects Kernel KernelLog Streams Commands Files WinFS Clock Dates Reals Strings Diagnostics BitSets StringPool ObjectFile GenericLinker Reflection Loader BootConsole ~		

	## command line shell
	Linker.Link --path=NewAos/ --fileFormat=PE32CUI --fileName=oberon.exe --extension=GofW --displacement=401000H
		Builtins Trace Kernel32 Machine Heaps Modules Objects Kernel KernelLog Streams Commands Files WinFS Clock Dates Reals Strings
		Diagnostics BitSets StringPool ObjectFile GenericLinker Reflection Loader WinTrace StdIO
		Traps RelativeFileSystem WMDefaultFont System StdIOShell ~

	## Command line shell including compiler (and linker) ##
		Linker.Link --path=NewAos/ --fileFormat=PE32CUI --fileName=oberon.exe --extension=GofW --displacement=401000H
			Builtins Trace Kernel32 Machine Heaps Modules Objects Kernel KernelLog Streams Commands Files WinFS Clock Dates Reals Strings Diagnostics BitSets StringPool ObjectFile GenericLinker Reflection Loader WinTrace
			StdIO Traps RelativeFileSystem System FSTools StdIOShell Shell Linker Compiler FoxOberonFrontend FoxARMBackend FoxAMDBackend ~

FSTools.CloseFiles oberon.exe ~

Compiler.Compile -p=Win32
I386.Builtins.Mod Trace.Mod Windows.I386.Kernel32.Mod Windows.I386.Machine.Mod Heaps.Mod
Modules.Mod Windows.I386.Objects.Mod Windows.Kernel.Mod KernelLog.Mod Plugins.Mod Streams.Mod Pipes.Mod
Commands.Mod In.Mod Out.Mod I386.Reals.Mod Reflection.Mod TrapWriters.Mod CRC.Mod
SystemVersion.Mod Windows.I386.Traps.Mod Windows.WinTrace.Mod Windows.StdIO.Mod Locks.Mod Windows.Clock.Mod
Disks.Mod Files.Mod Dates.Mod Strings.Mod UTF8Strings.Mod FileTrapWriter.Mod Caches.Mod
DiskVolumes.Mod OldDiskVolumes.Mod RAMVolumes.Mod DiskFS.Mod OldDiskFS.Mod OberonFS.Mod
FATVolumes.Mod FATFiles.Mod ISO9660Volumes.Mod ISO9660Files.Mod Windows.User32.Mod Windows.WinTrace.Mod
Windows.ODBC.Mod Windows.Shell32.Mod Windows.SQL.Mod Windows.WinFS.Mod RelativeFileSystem.Mod BitSets.Mod
Diagnostics.Mod StringPool.Mod ObjectFile.Mod GenericLinker.Mod Loader.Mod BootConsole.Mod
Shell.Mod StdIOShell.Mod ~

System.FreeDownTo FoxIntermediateBackend ~

WIN32DLL -- 32-bit windows a2 in a DLL (Example)
=================================

System.DoCommands

	Compiler.Compile --define=WIN,I386,SHAREDLIB -p=Win32 --traceModule=Trace --destPath=A2Dll/
		I386.Builtins.Mod Trace.Mod Windows.Kernel32.Mod Windows.Machine.Mod Heaps.Mod Modules.Mod
		Windows.Objects.Mod Windows.Kernel.Mod KernelLog.Mod
	~

	Compiler.Compile --define=WIN,I386,SHAREDLIB -p=Win32 --destPath=A2Dll/
		Streams.Mod Commands.Mod Files.Mod Windows.WinFS.Mod Windows.Clock.Mod Dates.Mod I386.Reals.Mod 
		Strings.Mod Diagnostics.Mod BitSets.Mod StringPool.Mod ObjectFIle.Mod GenericLinker.Mod Reflection.Mod 
		Loader.Mod CRC.Mod SystemVersion.Mod TrapWriters.Mod Windows.Traps.Mod FileTrapWriter.Mod Options.Mod 
		ProcessInfo0.Mod ProcessInfo.Mod Plugins.Mod System.Mod
	~
	
	FSTools.CreateFile -c -r A2Dll.Mod
		MODULE A2Dll;
		IMPORT Kernel;
		IMPORT SystemVersion;
			PROCEDURE {WINAPI} Test*(): SIGNED32;
			BEGIN
				RETURN SystemVersion.GetKernelCRC();
			END Test;
		END A2Dll.

		MODULE DllMainExit;
		IMPORT SYSTEM;
			PROCEDURE {CLOSING} Exit*;
			CODE{SYSTEM.i386}
				POP EDI
				POP ESI
				POP EBX
				POP EBP

				MOV EAX, 1
				RET 12
			END Exit;
		END DllMainExit.
	~
	
	Compiler.Compile --define=WIN,I386,SHAREDLIB -p=Win32 --destPath=A2Dll/
		A2Dll.Mod
	~
	
	Linker.Link
		--path=A2Dll/
		--fileFormat=DLL32
		--fileName=A2Dll.dll
		--extension=GofW
		--exports="A2Dll.Test=Test"
		--displacement=401000H
		--useAll
	
		Builtins Trace Kernel32 Machine Heaps Modules DllMainExit
		Objects Kernel KernelLog

		Streams Commands Files WinFS Clock Dates Reals 
		Strings Diagnostics BitSets StringPool ObjectFIle GenericLinker Reflection 
		Loader CRC SystemVersion TrapWriters Traps FileTrapWriter Options 
		ProcessInfo0 ProcessInfo Plugins System
		
		A2Dll
	~
~

LINUX32 -- 32 bit linux a2
================================

	Release.Build --path=NewAos/ Linux32 ~
	
	## X11 bootconsole ##
		Linker.Link -p=Linux32 --path=NewAos/
		Builtins Trace Glue Unix Machine Heaps Modules Objects Kernel
		KernelLog Streams Commands Pipes StdIO TrapWriters Reflection Traps Files UnixFiles Clock Dates
		Reals Strings Diagnostics BitSets StringPool ObjectFile GenericLinker Loader BootConsole ~
	
	## Command line shell including compiler (and linker) ##
		Linker.Link -p=Linux32 --path=NewAos/
			Builtins Trace Glue Unix Machine Heaps Modules Objects Kernel KernelLog Streams Commands Pipes StdIO
			TrapWriters Reflection Traps Files UnixFiles Clock Dates Reals Strings Diagnostics BitSets StringPool ObjectFile GenericLinker Loader System StdIOShell
			Shell ~ Linker Compiler FoxOberonFrontend FoxARMBackend FoxAMDBackend ~


LINUX64 -- 64 bit linux a2
================================

	Release.Build  --path=NewAos/ Linux64 ~
	
	## X11 bootconsole ##
		Linker.Link -p=Linux64 --path=NewAos/
		Builtins Trace Glue Unix Machine Heaps Modules Objects Kernel
		KernelLog Streams Commands Pipes StdIO TrapWriters Reflection Traps Files UnixFiles Clock Dates
		Reals Strings Diagnostics BitSets StringPool ObjectFile GenericLinker Loader BootConsole ~
	
	## Command line shell including compiler (and linker) ##
		Linker.Link -p=Linux64 --path=NewAos/
			Builtins Trace Glue Unix Machine Heaps Modules Objects Kernel KernelLog Streams Commands Pipes StdIO
			TrapWriters Reflection Traps Files UnixFiles Clock Dates Reals Strings Diagnostics BitSets StringPool ObjectFile GenericLinker Loader System StdIOShell
			Shell ~ Linker Compiler FoxOberonFrontend FoxARMBackend FoxAMDBackend ~


DARWIN32 -- 32 bit darwin a2
================================

	Release.Build -b --path=NewAos/ Darwin32 ~
	
	## X11 bootconsole ##
		Linker.Link -p=Darwin32 --path=./NewAos/
				Builtins Trace Glue Unix Machine Heaps Modules Objects Kernel KernelLog Streams Commands Pipes StdIO TrapWriters Reflection
				Traps Files UnixFiles Clock Dates Reals Strings Diagnostics BitSets StringPool ObjectFile GenericLinker Loader BootConsole ~
		UnixBinary.Build oberon.bin -> A2Core ~


SOLARIS32 -- 32 bit solaris a2
================================

	Release.Build -b --path=NewAos/ Solaris32 ~
	
	## X11 bootconsole ##
		Linker.Link -p=Solaris32 --path=./NewAos/
				Builtins Trace Glue Unix Machine Heaps Modules Objects Kernel KernelLog Streams Commands Pipes StdIO TrapWriters Reflection
				Traps Files UnixFiles Clock Dates Reals Strings Diagnostics BitSets StringPool ObjectFile GenericLinker Loader BootConsole ~
		UnixBinary.Build oberon.bin -> A2Core ~


WIN64 -- 64-bit windows a2
================
	
	Release.Build --path=NewAos/ Win64 ~

	Linker.Link --path=NewAos/ --fileFormat=PE64CUI --fileName=oberon.exe --extension=GofWw --displacement=401000H
		Builtins Trace Kernel32 Heaps Modules Objects Kernel KernelLog Streams Commands Files WinFS Clock Dates Reals Strings Diagnostics BitSets
		StringPool ObjectFile GenericLinker Reflection Loader Shell StdIOShell Traps System ~

	FSTools.CloseFiles oberon.exe ~
	~
	## Command line shell including compiler (and linker) ##
	Linker.Link --path=NewAos/ --fileFormat=PE64CUI --fileName=fox.exe --extension=GofWw --displacement=401000H
		Builtins Trace Kernel32 Heaps Modules Objects Kernel KernelLog Streams Commands Files WinFS Clock Dates Reals Strings Diagnostics BitSets
		StringPool ObjectFile GenericLinker Reflection Loader Shell StdIOShell Traps System
		Linker Compiler FoxOberonFrontend FoxARMBackend FoxAMDBackend ~	
	
-----

	System.DoCommands	
		FSTools.DeleteFiles -s NewAos/* ~
		Release.Build --build --path=NewAos/ Linux64 ~
		Linker.Link -p=Linux64 --path=NewAos/
			Builtins Trace Glue Unix Machine Heaps Modules Objects Kernel KernelLog Streams Commands Pipes StdIO
			TrapWriters Reflection Traps Files UnixFiles Clock Dates Reals Strings Diagnostics BitSets StringPool ObjectFile GenericLinker Loader System StdIOShell
			Shell ~
		FSTools.CopyFiles -oq NewAos/*.* => ../../Linux64/bin/*.* ~
		FSTools.CopyFiles -o oberon => ../../Linux64/oberon ~

		FSTools.DeleteFiles -s NewAos/* ~
		Release.Build --build --path=NewAos/ Linux32 ~
		Linker.Link -p=Linux32 --path=NewAos/
			Builtins Trace Glue Unix Machine Heaps Modules Objects Kernel KernelLog Streams Commands Pipes StdIO
			TrapWriters Reflection Traps Files UnixFiles Clock Dates Reals Strings Diagnostics BitSets StringPool ObjectFile GenericLinker Loader System StdIOShell
			Shell ~
		FSTools.CopyFiles -oq NewAos/*.* => ../../Linux32/bin/*.* ~
		FSTools.CopyFiles -o oberon => ../../Linux32/oberon ~

		FSTools.DeleteFiles -s NewAos/* ~
		Release.Build --build --path=NewAos/ Win32 ~
		Linker.Link --path=NewAos/ --fileFormat=PE32 --fileName=A2.exe --extension=GofW --displacement=401000H
			Builtins Trace Kernel32 Machine Heaps Modules Objects Kernel KernelLog Streams Commands Files WinFS Clock Dates Reals Strings Diagnostics BitSets StringPool
			ObjectFile GenericLinker Reflection Loader BootConsole ~		
		FSTools.CopyFiles -oq NewAos/*.* => ../../WinAos/obg/*.* ~
		FSTools.CopyFiles -o A2.exe => ../../WinAos/A2.exe ~

		FSTools.DeleteFiles -s NewAos/* ~
		Release.Build --build --path=NewAos/ Win32 ~
		Linker.Link --path=NewAos/ --fileFormat=PE32CUI --fileName=oberon.exe --extension=GofW --displacement=401000H
			Builtins Trace Kernel32 Heaps Modules Objects Kernel KernelLog Streams Commands Files WinFS Clock Dates Reals Strings Diagnostics BitSets
			StringPool ObjectFile GenericLinker Reflection Traps Loader Shell StdIOShell System ~
		FSTools.CopyFiles -oq NewAos/*.* => ../../Win32/bin/*.* ~
		FSTools.CopyFiles -o oberon.exe => ../../Win32/oberon.exe ~

		FSTools.DeleteFiles -s NewAos/* ~
		Release.Build --build --path=NewAos/ Win64 ~
		Linker.Link --path=NewAos/ --fileFormat=PE64CUI --fileName=oberon.exe --extension=GofWw --displacement=401000H
			Builtins Trace Kernel32 Heaps Modules Objects Kernel KernelLog Streams Commands Files WinFS Clock Dates Reals Strings Diagnostics BitSets
			StringPool ObjectFile GenericLinker Reflection Traps Loader Shell StdIOShell System ~
		FSTools.CopyFiles -oq NewAos/*.* => ../../Win64/bin/*.* ~
		FSTools.CopyFiles -o oberon.exe => ../../Win64/oberon.exe ~

		FSTools.DeleteFiles -s NewAos/* ~
		~ 
