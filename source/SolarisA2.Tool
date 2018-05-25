
Building the SolarisA2 Generic elf binary:

Compiler.Compile 
	-p=Linux32G  --destPath=NewAos/
		Runtime.Mod Trace.Mod 
		Generic.Solaris.I386.Glue.Mod  Generic.Solaris.I386.Unix.Mod  Generic.Unix.I386.Machine.Mod	
		Heaps.Mod  Generic.Modules.Mod  Generic.Unix.Objects.Mod  Unix.Kernel.Mod
		KernelLog.Mod  Streams.Mod  Pipes.Mod  Commands.Mod  TrapWriters.Mod  Generic.Reflection.Mod	
		Unix.StdIO.Mod  Generic.Unix.Traps.Mod  UTF8Strings.Mod  Files.Mod  Unix.UnixFiles.Mod
		RelativeFileSystem.Mod  StringPool.Mod  BitSets.Mod  ObjectFile.Mod  
		I386.Reals.Mod  Unix.Clock.Mod  Dates.Mod  Strings.Mod  Diagnostics.Mod 
		GenericLinker.Mod  Loader.Mod  Unix.BootConsole.Mod 
		
		ElfBinary.Mod 
		~
		
		
	(* the correct displacement is shown by  'A2Loader.elf  -h'  *)
Linker.Link  
	-p=Solaris32G --path=NewAos/
		Runtime Trace Glue 
		Unix  Machine  Heaps Modules  Objects  Kernel  KernelLog 
		Streams  Pipes  Commands  StdIO  TrapWriters  Traps 
		Files  UnixFiles  Clock  Dates  Reals  Strings  Diagnostics 
		BitSets  StringPool  GenericLinker  Reflection  Loader
		BootConsole
		~

 
 Build 'SolarisA2' by concatenating 'A2Loader.elf' (C) and 'Solaris32G.core' (Oberon).	
 
 ElfBinary.Build Solaris32G.core -> SolarisA2 ~
 
 Release.Tool
 
 CompileCommand.Tool
 
 
 
 
	