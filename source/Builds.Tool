## initial remarks / caveats
	TextUtilities imports WMGraphics, 
	WMGraphics can block when WMDefaultFont is not loaded. Make sure to link WMDefaultFont into images requiring WMGraphics that should work without module loading
	Modules that must be loaded during startup must be linked before IOShell / Bootconsole, respectively

WIN32G -- 32-bit windows a2 using generic object files
=================================

	## Compile all files ##
		Release.Build WinAosNewObjectFile ~
	
	## Link A2.exe (bootconsole for graphical OS) ##
		StaticLinker.Link --fileFormat=PE32 --fileName=A2.exe --extension=GofW --displacement=401000H  
			Runtime Trace Kernel32 Machine Heaps Modules Objects Kernel KernelLog Streams Commands Files WinFS Clock Dates Reals Strings Diagnostics BitSets StringPool ObjectFile GenericLinker Reflection  GenericLoader  BootConsole ~		

	## command line shell 
	StaticLinker.Link  --fileFormat=PE32CUI --fileName=oberon.exe --extension=GofW --displacement=401000H 
		Runtime Trace Kernel32 Machine Heaps Modules Objects Kernel KernelLog Streams Commands Files  WinFS Clock Dates Reals Strings 
		Diagnostics BitSets StringPool ObjectFile GenericLinker Reflection GenericLoader WinTrace StdIO  
		Traps RelativeFileSystem WMDefaultFont SystemTools StdIOShell ~

	## Command line shell including compiler (and linker) ##
		StaticLinker.Link  --fileFormat=PE32CUI --fileName=oberon.exe --extension=GofW --displacement=401000H 
			Runtime Trace Kernel32 Machine Heaps Modules Objects Kernel KernelLog Streams Commands Files  WinFS Clock Dates Reals Strings Diagnostics BitSets StringPool ObjectFile GenericLinker Reflection GenericLoader WinTrace 
			StdIO  Traps RelativeFileSystem SystemTools FSTools StdIOShell Shell StaticLinker Compiler FoxOberonFrontend FoxARMBackend FoxAMDBackend ~

FSTools.CloseFiles oberon.exe ~

Compiler.Compile -p=Win32G
Runtime.Mod Trace.Mod Generic.Win32.Kernel32.Mod Win32.Machine.Mod Heaps.Mod 
Generic.Modules.Mod Win32.Objects.Mod Win32.Kernel.Mod KernelLog.Mod Plugins.Mod Streams.Mod Pipes.Mod 
Commands.Mod In.Mod Out.Mod I386.Reals.Mod Generic.Reflection.Mod TrapWriters.Mod CRC.Mod 
SystemVersion.Mod Win32.Traps.Mod Win32.WinTrace.Mod Win32.StdIO.Mod Locks.Mod Win32.Clock.Mod 
Disks.Mod Files.Mod Dates.Mod Strings.Mod UTF8Strings.Mod FileTrapWriter.Mod Caches.Mod 
DiskVolumes.Mod OldDiskVolumes.Mod RAMVolumes.Mod DiskFS.Mod OldDiskFS.Mod OberonFS.Mod 
FATVolumes.Mod FATFiles.Mod ISO9660Volumes.Mod ISO9660Files.Mod Win32.User32.Mod Win32.WinTrace.Mod 
Win32.ODBC.Mod Win32.Shell32.Mod Win32.SQL.Mod Win32.WinFS.Mod RelativeFileSystem.Mod BitSets.Mod 
Diagnostics.Mod StringPool.Mod ObjectFile.Mod GenericLinker.Mod GenericLoader.Mod BootConsole.Mod 
Shell.Mod StdIOShell.Mod ~

SystemTools.FreeDownTo FoxIntermediateBackend ~

LINUX32G -- 32 bit linux a2 using generic object files
================================

	Release.Build -b Linux32G ~
	
	## X11 bootconsole ##
		StaticLinker.Link -p=Linux32G Runtime Trace Glue Unix Machine Heaps Modules Objects Kernel 
		KernelLog  Streams Commands Pipes StdIO TrapWriters Reflection Traps Files UnixFiles Clock Dates 
		Reals Strings Diagnostics BitSets StringPool ObjectFile GenericLinker   GenericLoader  BootConsole ~
	
	## Command line shell including compiler (and linker) ##
		StaticLinker.Link -p=Linux32G 
			Runtime Trace Glue Unix Machine Heaps Modules Objects Kernel KernelLog  Streams Commands Pipes StdIO 
			TrapWriters Reflection Traps Files UnixFiles Clock Dates Reals Strings Diagnostics BitSets StringPool ObjectFile GenericLinker   GenericLoader  SystemTools StdIOShell 
			Shell StaticLinker Compiler FoxOberonFrontend FoxARMBackend FoxAMDBackend ~


DARWIN32G -- 32 bit darwin a2 using generic object files
================================

	Release.Build -b Darwin32G ~
	
	## X11 bootconsole ##
		StaticLinker.Link -p=Darwin32G  --path=./NewAos/
				Runtime Trace Glue Unix Machine Heaps Modules Objects Kernel KernelLog  Streams Commands Pipes StdIO TrapWriters Reflection 
				Traps Files UnixFiles Clock Dates Reals Strings Diagnostics BitSets StringPool ObjectFile GenericLinker   GenericLoader  BootConsole ~
		UnixBinary.Build  oberon.bin  ->  A2Core ~


SOLARIS32G -- 32 bit solaris a2 using generic object files
================================

	Release.Build -b Solaris32G ~
	
	## X11 bootconsole ##
		StaticLinker.Link -p=Solaris32G  --path=./NewAos/
				Runtime Trace Glue Unix Machine Heaps Modules Objects Kernel KernelLog  Streams Commands Pipes StdIO TrapWriters Reflection 
				Traps Files UnixFiles Clock Dates Reals Strings Diagnostics BitSets StringPool ObjectFile GenericLinker   GenericLoader  BootConsole ~
		UnixBinary.Build  oberon.bin  ->  A2Core ~


Win64G -- work in progress
================
	
	Release.Build WinAosG64 ~

	StaticLinker.Link --fileFormat=PE64CUI --fileName=oberon64.exe --extension=GofWw --displacement=401000H  
		Runtime Trace Kernel32 
		Heaps Modules Objects Kernel
		KernelLog Streams Commands Files WinFS Clock Dates Reals Strings Diagnostics BitSets 
		StringPool ObjectFile GenericLinker Reflection  GenericLoader Shell  StdIOShell Traps SystemTools ~

	FSTools.CloseFiles oberon64.exe  ~
	~
	