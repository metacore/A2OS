(* Minimal ELF header for self contained Solaris x86 Oberon programs *)
(* Copyright (c) Felix Friedrich, ETH Zürich *)

MODULE Glue; 

IMPORT SYSTEM, Trace;

CONST 
(*	base* = 08050000H;		for true elf core *)
	base* = 08070000H;	(*  used by A2Loader,  see 'A2Loader.elf  -h' *)
	debug* = {};
	NL = 0AX;
VAR
	last-: RECORD END; (* empty variable linked to end of kernel *)
	
	baseAdr*: ADDRESS;
	endAdr*: ADDRESS;
	
	dlsym-	: PROCEDURE {C} ( handle: ADDRESS; name: ADDRESS ): ADDRESS;
	dlopen-	: PROCEDURE {C} ( pathname: ADDRESS; mode: LONGINT ): ADDRESS;
	dlclose-	: PROCEDURE {C} ( handle: ADDRESS );
	write		: PROCEDURE {C} ( fd: LONGINT; buf: ADDRESS; n: SIZE ): LONGINT;
	exit-		: PROCEDURE {C} ( status: LONGINT );

	stackBottom-	: ADDRESS;	(* of main thread *)

	libc: ADDRESS;
	
	argc-: WORD; 
	argv-: ADDRESS;
	environ-: ADDRESS;


(*? the relocation of "dlsym/dlopen" doesn't work	*)
(*==================
	
	PROCEDURE {INITIAL, NOPAF} EntryPoint;
	CODE
		; ELF header
		DB 07FH, 'ELF', 1, 1, 1, 6, 1, 0, 0, 0
		DD 0
		DW 02, 03	; executable, I386
		DD 01
		DD entry + base	;program entry point
		DD elfheadersize
		DD 0
		DD 0
		DW elfheadersize
		DW 20H
		DW 3 		;program header table entries
		DW 0
		DW 0
		DW 0

	elfheadersize:

		; interpreter header, must precede any loadable segment!! 
		DD 3
		DD interpretername; interpreter name offset
		DD interpretername + base; interpreter name 
		DD interpretername + base; interpreter name
		DD interpretername_end - interpretername ; interpreter name length
		DD interpretername_end - interpretername ; interpreter name length
		DD 4H
		DD 1H

		; program header
		DD 1
		DD 0
		DD base; 
		DD base; 
		DD @last - base; segment size (file)
		DD @last - base; segment size (memory)
		DD 07
		DD 1000H; alignment
		
		; dynamic header
		DD 02H
		DD dynamicsection 
		DD dynamicsection + base
		DD dynamicsection + base
		DD dynamicsection_end - dynamicsection ; size of dynamic section
		DD dynamicsection_end - dynamicsection ; size of dynamic section
		DD 06H
		DD 04H

	dynamicsection: 			; manantory in solaris: 0, 4-11, 17-19
		DD 04H, hashtable + base								;DT_HASH
		DD 05H, stringtable + base							;DT_STRTAB
		DD 06H, symboltable + base							;DT_SYMTAB
		DD 07H, relocationtable + base						;DT_RELA
		DD 08H, relocationtable_end - relocationtable	;DT_RELASZ, size of relocationtable
		DD 09H, 0CH													;DT_RELAENT, size of relocation entry
		DD 0AH, stringtable_end - stringtable				;DT_STRSZ, size of stringtable
		DD 0BH, 10H													;DT_SYMENT, size of symboltable entry
		
		DD 11H, relocationtable + base						;DT_REL
		DD 12H, relocationtable_end - relocationtable	;DT_RELSZ
		DD 13H, 0CH													;DT_RELENT
		
		DD 01H, libdl - stringtable						;DT_NEEDED, pos. of libdl
		DD 01H, libc - stringtable						;DT_NEEDED, pos. of libc
		DD 0H, 0H 	;sentinel
	dynamicsection_end:		
		
	relocationtable:
		DD @dlsym
		DB 01H				;relocation type
		DB 01H, 00H, 00H	;index of the symbol
		DD 0H
		DD @dlopen
		DB 01H				;relocation type
		DB 01H, 00H, 00H	;index of the symbol
		DD 0H
	relocationtable_end:

	stringtable:
		DB 0H ; sentinel
	libdl:
		DB '/lib/libdl.so.1', 0
	libc:
		DB '/lib/libc.so.1', 0
	dlsymname:
		DB 'dlsym', 0
	dlopenname:
		DB 'dlopen', 0
	stringtable_end:
		
		ALIGN 4
	hashtable:
		DD 2		; nbucket
		DD 2		; nchain
		DD 1		; bucket[0]
		DD 2		; bucket[1]
		DD 1		; chain[0]
		DD 2		; chain[1]
		
	symboltable:
		DD	0
		DD	0
		DD	0
		DB	0
		DB	0
		DW 0
		
		;dlsym symbol
		DD dlsymname - stringtable	; st_name, position of dlsymname
		DD	0									; st_value
		DD	0									; st_size
		DB	12H 								; st_info, global + function
		DB 0									; st_other
		DW 0									; st_shndx: default

		;dlopen symbol
		DD dlopenname - stringtable	; st_name, position of dlopenname
		DD	0									; st_value
		DD	0									; st_size
		DB	12H 								; st_info, global + function
		DB 0									; st_other
		DW 0									; st_shndx: default

	interpretername:
		DB '/lib/ld.so.1', 0
	interpretername_end:

		ALIGN 4

	entry:
	END EntryPoint;			======*)


	PROCEDURE {INITIAL, NOPAF} EntryPoint;		(* header needed by A2Loader *)
	CODE
		DB 'Solaris32G.core', 0
		DD 0
		DD 0
		DD 0
		DD 0
		DD base
		DD @Init0
		DD @dlopen
		DD @dlsym
		DD @argc
		DD @argv
	END EntryPoint;		
	
 	PROCEDURE Char ( c: CHAR );
	VAR r: LONGINT;
	BEGIN
		r := write( 1, ADDRESSOF( c ), 1 );
	END Char;

 	PROCEDURE Dlsym*( handle: ADDRESS; CONST name: ARRAY OF CHAR; adr: ADDRESS );
	VAR val: ADDRESS;
	BEGIN
		val := dlsym( handle, ADDRESSOF( name[0] ) );
		SYSTEM.PUT32( adr, val );	
	END Dlsym;
	
	
	PROCEDURE Init;
	VAR i: LONGINT;
		libdl: ADDRESS;
	BEGIN
		baseAdr := ADDRESSOF( EntryPoint );
		endAdr := ADDRESSOF( last );
		
		Trace.Init;
		Trace.Char := Char;
		
		stackBottom := ADDRESSOF( i ) + 2*SIZEOF( ADDRESS );

	(*	Dlsym( 0, "dlopen" , ADDRESSOF ( dlopen ) );	*)
		libdl := dlopen( ADDRESSOF( "/lib/libdl.so.1" ), 2 );
		Dlsym( libdl, "dlclose", ADDRESSOF ( dlclose ) );
		libc := dlopen( ADDRESSOF( "/lib/libc.so.1" ), 2 );	
		Dlsym( libc, "write", ADDRESSOF ( write ) );
		Dlsym( libc, "exit", ADDRESSOF ( exit ) );
	END Init;
	
	PROCEDURE {INITIAL, NOPAF} Init0;
	BEGIN
	(*? same layout in Solaris ?? *)
	(*	(*initial stack layout:
			argc at esp
			argv at esp+4
			0 at esp+4+argc*4
			env at esp+4+argc*4+4      =   (2+argc)<<2 + esp
		*)
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
		END;	*)
		Init;
	END Init0;
	
	PROCEDURE Initialize*;
	BEGIN
		(* nothing, only for compatibility *)
	END Initialize;
	

END Glue.




 Building the SolarisA2 Generic elf binary:

Compiler.Compile -p=Linux32G
		Runtime.Mod Trace.Mod 
		Generic.Solaris.I386.Glue.Mod  Generic.Solaris.I386.Unix.Mod  Generic.Unix.I386.Machine.Mod	
		Heaps.Mod  Generic.Modules.Mod  Generic.Solaris.Objects.Mod  Unix.Kernel.Mod
		KernelLog.Mod  Streams.Mod  Pipes.Mod  Commands.Mod  TrapWriters.Mod  Generic.Reflection.Mod	
		Unix.StdIO.Mod  Generic.Unix.Traps.Mod  UTF8Strings.Mod  Files.Mod  Unix.UnixFiles.Mod
		RelativeFileSystem.Mod  StringPool.Mod  BitSets.Mod  ObjectFile.Mod  
		I386.Reals.Mod  Unix.Clock.Mod  Dates.Mod  Strings.Mod  Diagnostics.Mod 
		GenericLinker.Mod  GenericLoader.Mod  Unix.BootConsole.Mod 
		
		ElfBinary.Mod 
		~
		
		
	(* the correct displacement is shown by  'A2Loader.elf  -h'  *)
StaticLinker.Link 
	--fileFormat=Raw --fileName=Solaris32G.core --extension=.GofU --displacement=08070000H
		Runtime Trace Glue 
		Unix  Machine  Heaps Modules  Objects  Kernel  KernelLog 
		Streams  Pipes  Commands  StdIO  TrapWriters  Traps 
		Files  UnixFiles  Clock  Dates  Reals  Strings  Diagnostics 
		BitSets  StringPool  GenericLinker  Reflection  GenericLoader
		BootConsole
		~

 
 Build 'SolarisA2' by concatenating 'A2Loader.elf' (C) and 'Solaris32G.core' (Oberon).	
 
 ElfBinary.Build  Solaris32G.core -> SolarisA2 ~
