(* Minimal ELF header for self contained linux Oberon programs *)
(* Copyright (c) Felix Friedrich, ETH Zürich *)
(* Extracted in parts from Florian Negele's Eigen Compiler Suite *)

MODULE ElfHeader; 

IMPORT SYSTEM, Trace;

VAR
	empty-: RECORD END; (* empty variable linked to end of kernel *)

	dlsym-	: PROCEDURE {C} ( handle: ADDRESS; name: ADDRESS): ADDRESS;
	dlopen-	: PROCEDURE {C} ( pathname: ADDRESS; mode: LONGINT ): ADDRESS;
	dlclose-	: PROCEDURE {C} ( handle: ADDRESS );

	PROCEDURE {INITIAL, NOPAF} EntryPoint;
	CONST base = 08048000H;
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
		DD @empty - base; segment size (file)
		DD @empty - base; segment size (memory)
		DD 07
		DD 1000H; alignment
		
		; interpreter header
		DD 3
		DD interpretername; interpreter name offset
		DD interpretername + base; interpreter name 
		DD interpretername + base; interpreter name
		DD 13H ; interpreter name length
		DD 13H ; interpreter name length
		DD 4H
		DD 1H

		; dynamic header
		DD 02H
		DD dynamicsection 
		DD dynamicsection + base
		DD dynamicsection + base
		DD 40H ; size of dynamic section
		DD 40H ; size of dynamic section
		DD 06H
		DD 04H

		dynamicsection:
		DD 05H, base + stringtable
		DD 06H, symboltablebegin + base
		DD 07H, dlsymrelocation + base
		DD 08H, stringtable-dlsymrelocation ; size (relocationtable)
		DD 09H, 0CH
		DD 0AH, endstringtable - stringtable; size (stringtable)
		DD 0BH, 10H
		
		DD 01H, libname - stringtable; position of libname
		DD 0H, 0H ; sentinel

	 	dlsymrelocation:
		DD @dlsym
		DB 01H
		DB 01H, 00H, 00H; index of the symbol
		DD 0H

		stringtable:
		DB 0H ; sentinel

		libname:
		DB 'libdl.so.2', 0
		
		dlsymname:
		DB 'dlsym', 0
		
		endstringtable:
		
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
		DB	12H
		DB 0
		DW	0

		interpretername:
		DB '/lib/ld-linux.so.2', 0

		ALIGN 4

		entry:
	END EntryPoint;


	PROCEDURE {NOPAF} putc*(file: ADDRESS; c: CHAR);
	CODE
		PUSH ECX
		MOV EAX, 4
		MOV EBX, [ESP + 12]
		LEA ECX, [ESP+8]	
		MOV EDX, 1
		INT 80H
		POP ECX
		JNE fail
		MOV EAX, [ESP + 4]
		RET
		fail:
		MOV EAX, -1
		RET
	END putc;

	PROCEDURE Dlsym*(handle: ADDRESS; CONST name: ARRAY OF CHAR; adr: ADDRESS);
	VAR val: ADDRESS;
	BEGIN
		val := dlsym(handle, ADDRESS OF name[0]);
		SYSTEM.PUT32(adr, val);
	END Dlsym;

	PROCEDURE Char(c: CHAR);
	BEGIN
		putc(1, c);
	END Char;
 
	PROCEDURE Init;
	BEGIN
		Trace.Char := Char;
		Dlsym(0,"dlopen", ADDRESS OF dlopen);
		ASSERT(dlopen # NIL); 
		Dlsym( 0, "dlclose", ADDRESS OF dlclose);
		ASSERT(dlclose # NIL); 
	END Init;

BEGIN
	Init;
	Trace.String("ElfHeader loaded");
END ElfHeader.

SystemTools.DoCommands
	Compiler.Compile -b=AMD --objectFile=Generic --symbolFile=Textual --objectFileExtension=.GofU --symbolFileExtension=.SymU
		Runtime.Mod Trace.Mod Linux.I386.ElfHeader.Mod  ~ 

	StaticLinker.Link --fileFormat=Raw --fileName=simple_elf --extension=.GofU --displacement=08048000H
		Runtime Trace ElfHeader
		~ 

