(* Minimal ELF header for self contained linux Oberon programs *)
(* Copyright (c) Felix Friedrich, ETH Zürich *)

MODULE Glue; 

IMPORT SYSTEM, Trace;

CONST 
	base* = 08048000H;
	debug* = {};
VAR
	last-: RECORD END; (* empty variable linked to end of kernel *)
	
	baseAdr*: ADDRESS;
	endAdr*: ADDRESS;
	
	dlsym-	: PROCEDURE {C} ( handle: ADDRESS; name: ADDRESS): ADDRESS;
	dlopen-	: PROCEDURE {C} ( pathname: ADDRESS; mode: LONGINT ): ADDRESS;
	dlclose-	: PROCEDURE {C} ( handle: ADDRESS );
	exit-		: PROCEDURE {C} (status: LONGINT);

	stackBottom-	: ADDRESS;	(* of main thread *)


	argc-: WORD; 
	argv-: ADDRESS;
	environ-: ADDRESS;

	PROCEDURE {INITIAL, NOPAF} EntryPoint;
	CODE
		; ELF header
		DB 07FH, 'ELF', 1, 1, 1, 0
		DD 0, 0
		DW 02, 03
		DD 01
		DD entry + base; program entry point
		DD elfheadersize
		DD 0
		DD 0
		DW elfheadersize
		DW 20H
		DW 3 ; #program header table entries
		DW 0
		DW 0
		DW 0

		elfheadersize:

		; program header
		DD 1
		DD 0
		DD base; 
		DD base; 
		DD @last - base; segment size (file)
		DD @last - base; segment size (memory)
		DD 07
		DD 1000H; alignment
		
		; interpreter header
		DD 3
		DD interpretername; interpreter name offset
		DD interpretername + base; interpreter name 
		DD interpretername + base; interpreter name
		DD interpretername_end - interpretername ; interpreter name length
		DD interpretername_end - interpretername ; interpreter name length
		DD 4H
		DD 1H

		; dynamic header
		DD 02H
		DD dynamicsection 
		DD dynamicsection + base
		DD dynamicsection + base
		DD dynamicsection_end - dynamicsection ; size of dynamic section
		DD dynamicsection_end - dynamicsection ; size of dynamic section
		DD 06H
		DD 04H

		dynamicsection:
		DD 05H, base + stringtable
		DD 06H, symboltablebegin + base
		DD 07H, dlsymrelocation + base
		DD 08H, dlsymrelocation_end-dlsymrelocation ; size (relocationtable)
		DD 09H, 0CH
		DD 0AH, stringtable_end - stringtable; size (stringtable)
		DD 0BH, 10H
		
		DD 01H, libname - stringtable; position of libname
		DD 0H, 0H ; sentinel
		dynamicsection_end:		
		
	 	dlsymrelocation:
		DD @dlsym
		DB 01H
		DB 01H, 00H, 00H; index of the symbol
		DD 0H
		dlsymrelocation_end:

		stringtable:
		DB 0H ; sentinel

		libname:
		DB 'libdl.so.2', 0
		
		dlsymname:
		DB 'dlsym', 0
		
		
		stringtable_end:
		
		ALIGN 4
		symboltablebegin:
		DD	0;
		DD	0
		DD	0
		DB	0
		DB	0
		DW 0
		
		; dlsym symbol
		DD dlsymname - stringtable; position of dlsymname
		DD	0
		DD	0
		DB	12H ; info: global + function
		DB 0
		DW	0

		interpretername:
		DB '/lib/ld-linux.so.2', 0
		interpretername_end:

		ALIGN 4

		entry:
	END EntryPoint;

	(*
	PROCEDURE {FINAL} ExitPoint;
	BEGIN
		Trace.String("exiting"); Trace.Ln;
		exit(0);
	END ExitPoint;
	*)

	PROCEDURE {NOPAF} putc*(file: ADDRESS; c: CHAR);
	CODE
		MOV EAX, 4
		MOV EBX, [ESP + 8]
		LEA ECX, [ESP + 4]
		MOV EDX, 1
		INT 80H
		RET
	END putc;

	PROCEDURE Dlsym*(handle: ADDRESS; CONST name: ARRAY OF CHAR; adr: ADDRESS);
	VAR val: ADDRESS;
	BEGIN
		val := dlsym(handle, ADDRESS OF name[0]);
		SYSTEM.PUT(adr, val);
	END Dlsym;

	PROCEDURE Char(c: CHAR);
	BEGIN
		putc(1, c);
	END Char;
 
	PROCEDURE Init;
	VAR i: ADDRESS;
	BEGIN
		baseAdr := ADDRESS OF EntryPoint;
		endAdr := ADDRESS OF last;
		
		Trace.Init;
		Trace.Char := Char;
		
		stackBottom := ADDRESSOF( i ) + 2*SIZEOF(ADDRESS);
		ASSERT(dlsym # NIL);
		Dlsym(0,"dlopen", ADDRESS OF dlopen);
		ASSERT(dlopen # NIL); 
		Dlsym( 0, "dlclose", ADDRESS OF dlclose);
		ASSERT(dlclose # NIL); 
		Dlsym(0,"exit", ADDRESS OF exit);
		ASSERT(exit # NIL);
	END Init;
	
	PROCEDURE {INITIAL,NOPAF} Init0;
	BEGIN
		(*initial stack layout:
			argc at esp
			argv at esp+4
			0 at esp+4+argc*4
			env at esp+4+argc*4+4      =   (2+argc)<<2 + esp*)
		CODE{SYSTEM.i386}
			MOV EAX, [ESP]
			MOV argc, EAX
			LEA EAX, [ESP+4]
			MOV argv, EAX
			MOV EAX, [ESP]
			ADD EAX, 2
			SHL EAX, 2
			ADD EAX, ESP
			MOV environ, EAX
		END;
		Init;
	END Init0;

END Glue.



SystemTools.FreeDownTo FoxIntermediateBackend ~

SystemTools.DoCommands
	Compiler.Compile -p=Linux32
		I386.Runtime.Mod Trace.Mod Linux.I386.Glue.Mod Linux.I386.Unix.Mod Unix.I386.Machine.Mod Heaps.Mod  Modules.Mod 
		Unix.Objects.Mod 
		Unix.Kernel.Mod KernelLog.Mod Plugins.Mod Streams.Mod 
		Pipes.Mod Commands.Mod I386.Reals.Mod Reflection.Mod TrapWriters.Mod CRC.Mod SystemVersion.Mod 
		Unix.StdIO.Mod Unix.Traps.Mod Locks.Mod Unix.Clock.Mod Disks.Mod Files.Mod Dates.Mod Strings.Mod 
		UTF8Strings.Mod FileTrapWriter.Mod Caches.Mod DiskVolumes.Mod OldDiskVolumes.Mod RAMVolumes.Mod 
		DiskFS.Mod OldDiskFS.Mod OberonFS.Mod FATVolumes.Mod FATFiles.Mod ISO9660Volumes.Mod 
		ISO9660Files.Mod Unix.UnixFiles.Mod RelativeFileSystem.Mod BitSets.Mod StringPool.Mod DIagnostics.Mod 
		ObjectFile.Mod GenericLinker.Mod Loader.Mod Unix.BootConsole.Mod 
	~

	Linker.Link --fileFormat=Raw --fileName=simple_elf --extension=.GofU --displacement=08048000H
		Runtime Trace Glue Unix Machine Heaps Modules Objects Kernel KernelLog 
Streams Commands StdIO TrapWriters Traps 
Files UnixFiles Clock Dates Reals Strings Diagnostics 
BitSets StringPool ObjectFile GenericLinker Reflection  Loader  
BootConsole 
 ~

	FSTools.CloseFiles simple_elf ~
~ 

MODULE Test;

IMPORT StdIO, Commands, Streams, Modules;

PROCEDURE Execute(context: Commands.Context);
VAR str, msg: ARRAY 256 OF CHAR;  res: WORD;
BEGIN
	IF ~context.arg.GetString(str) THEN RETURN END;
	IF ~context.arg.GetString(str) THEN 
		context.out.String("no command"); context.out.Ln;
		RETURN
	END;
	Commands.Activate(str, context, {Commands.Wait}, res, msg);
END Execute;

BEGIN
	Execute(StdIO.env);
	Modules.Shutdown(1);
END Test.
