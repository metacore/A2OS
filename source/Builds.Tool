## initial remarks / caveats
	TextUtilities imports WMGraphics, 
	WMGraphics can block when WMDefaultFont is not loaded. Make sure to link WMDefaultFont into images requiring WMGraphics that should work without module loading
	Modules that must be loaded during startup must be linked before IOShell / Bootconsole, respectively

WIN32G -- 32-bit windows a2 using generic object files
=================================

	## Compile all files ##
		Release.Build -b WinAosNewObjectFile ~
	
	## Link A2.exe (bootconsole for graphical OS) ##
		StaticLinker.Link --fileFormat=PE32 --fileName=A2.exe --extension=GofW --displacement=401000H  
			Runtime Trace Kernel32 Machine Heaps Modules Objects Kernel KernelLog Streams Commands Files WinFS Clock Dates Reals Strings Diagnostics BitSets StringPool ObjectFile GenericLinker Reflection  GenericLoader  BootConsole ~		

	## Command line shell including compiler (and linker) ##
		StaticLinker.Link  --fileFormat=PE32CUI --fileName=oberon.exe --extension=GofW --displacement=401000H 
			Runtime Trace Kernel32 Machine Heaps Modules Objects Kernel KernelLog Streams Commands Files  WinFS Clock Dates Reals Strings Diagnostics BitSets StringPool ObjectFile GenericLinker Reflection GenericLoader WinTrace 
			StdIO  Traps RelativeFileSystem SystemTools FSTools StdIOShell Shell StaticLinker Compiler FoxOberonFrontend FoxARMBackend FoxAMDBackend ~

LINUX32G -- 32 bit linux a2 using generic object files
================================

	Release.Build -b Linux32G ~
	
	## X11 bootconsole ##
		StaticLinker.Link -p=Linux32G Runtime Trace Glue Unix Machine Heaps Modules Objects Kernel KernelLog  Streams Commands Pipes StdIO TrapWriters Reflection Traps Files UnixFiles Clock Dates Reals Strings Diagnostics BitSets StringPool ObjectFile GenericLinker   GenericLoader  BootConsole ~
	
	## Command line shell including compiler (and linker) ##
		StaticLinker.Link -p=Linux32G 
			Runtime Trace Glue Unix Machine Heaps Modules Objects Kernel KernelLog  Streams Commands Pipes StdIO 
			TrapWriters Reflection Traps Files UnixFiles Clock Dates Reals Strings Diagnostics BitSets StringPool ObjectFile GenericLinker   GenericLoader  SystemTools StdIOShell 
			Shell StaticLinker Compiler FoxOberonFrontend FoxARMBackend FoxAMDBackend ~


Win64G -- work in progress
================

SystemTools.DoCommands 

Compiler.Compile -b=AMD --bits=64 --objectFile=Generic --newObjectFile  --symbolFile=Textual  --objectFileExtension=.GofWw --symbolFileExtension=.SymWw 
	--traceModule=Trace
	AMD64.Runtime.Mod Trace.Mod Generic.Win64.Kernel32.Mod Win64.Machine.Mod Heaps.Mod Generic.Modules.Mod 
	Win64.Objects.Mod Win32.Kernel.Mod ~

StaticLinker.Link --fileFormat=PE64CUI --fileName=A264.exe --extension=GofWw --displacement=401000H  
	Runtime Trace Kernel32 
	Heaps Modules Objects Kernel ~

FSTools.CloseFiles A264.exe  ~
~

	KernelLog Streams Commands Files WinFS Clock Dates Reals Strings Diagnostics BitSets StringPool ObjectFile GenericLinker Reflection  GenericLoader  BootConsole ~
	~

