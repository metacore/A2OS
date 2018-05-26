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
		DB 07FH, 'ELF', 2, 1, 1, 0
		DD 0, 0
		DW 02, 62
		DD 01
		DQ entry + base; program entry point
		DQ elfheadersize
		DQ 0
		DD 0
		DW elfheadersize
		DW 38H
		DW 3 ; #program header table entries
		DW 0
		DW 0
		DW 0

		elfheadersize:

		; program header
		DD 1
		DD 07
		DQ 0
		DQ base; 
		DQ base; 
		DQ @last - base; segment size (file)
		DQ @last - base; segment size (memory)
		DQ 1000H; alignment
		
		; interpreter header
		DD 3
		DD 4H
		DQ interpretername; interpreter name offset
		DQ interpretername + base; interpreter name 
		DQ interpretername + base; interpreter name
		DQ interpretername_end - interpretername ; interpreter name length
		DQ interpretername_end - interpretername ; interpreter name length
		DQ 1H

		; dynamic header
		DD 02H
		DD 06H
		DQ dynamicsection 
		DQ dynamicsection + base
		DQ dynamicsection + base
		DQ dynamicsection_end - dynamicsection ; size of dynamic section
		DQ dynamicsection_end - dynamicsection ; size of dynamic section
		DQ 08H

		dynamicsection:
		DQ 05H, base + stringtable
		DQ 06H, symboltablebegin + base
		DQ 07H, dlsymrelocation + base
		DQ 08H, dlsymrelocation_end-dlsymrelocation ; size (relocationtable)
		DQ 09H, 18H
		DQ 0AH, stringtable_end - stringtable; size (stringtable)
		DQ 0BH, 18H
		
		DQ 01H, libname - stringtable; position of libname
		DQ 0H, 0H ; sentinel
		dynamicsection_end:		
		
	 	dlsymrelocation:
		DQ @dlsym
		DD 01H
		DD 01H ; index of the symbol
		DQ 0H
		dlsymrelocation_end:

		stringtable:
		DB 0H ; sentinel

		libname:
		DB 'libdl.so.2', 0
		
		dlsymname:
		DB 'dlsym', 0
		
		
		stringtable_end:
		
		ALIGN 8
		symboltablebegin:
		DD	0;
		DB	0
		DB	0
		DW 0
		DQ	0
		DQ	0
		
		; dlsym symbol
		DD dlsymname - stringtable; position of dlsymname
		DB	12H ; info: global + function
		DB 0
		DW	0
		DQ	0
		DQ	0

		interpretername:
		DB '/lib64/ld-linux-x86-64.so.2', 0
		interpretername_end:

		ALIGN 8

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
		MOV EAX, 1
		MOV RDI, [RSP + 16]
		LEA RSI, [RSP + 8]
		MOV RDX, 1
		SYSCALL
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
			argc at rsp
			argv at rsp+8
			0 at rsp+8+argc*8
			env at rsp+8+argc*8+8      =   (2+argc)<<3 + rsp*)
		CODE{SYSTEM.AMD64}
			MOV RAX, [RSP]
			MOV argc, RAX
			LEA RAX, [RSP+8]
			MOV argv, RAX
			MOV RAX, [RSP]
			ADD RAX, 2
			SHL RAX, 3
			ADD RAX, RSP
			MOV environ, RAX
		END;
		Init;
	END Init0;

END Glue.



SystemTools.FreeDownTo FoxIntermediateBackend ~

SystemTools.DoCommands
	Compiler.Compile -p=Linux32
		Runtime.Mod Trace.Mod Linux.I386.Glue.Mod Linux.I386.Unix.Mod Unix.I386.Machine.Mod Heaps.Mod  Modules.Mod 
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
VAR str, msg: ARRAY 256 OF CHAR;  res: LONGINT;
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
