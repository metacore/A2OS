
MODULE Glue; (** AUTHOR "GF"; PURPOSE "Interface to OberonLoader"; *)

IMPORT SYSTEM, Trace;

CONST 
	debug* = {};
	
VAR
	last-: RECORD END; (* empty variable linked to end of kernel *)
	
	baseAdr*: ADDRESS;
	endAdr*: ADDRESS;
	
	dlsym-	: PROCEDURE {C} ( handle: ADDRESS; name: ADDRESS ): ADDRESS;
	dlopen-	: PROCEDURE {C} ( pathname: ADDRESS; mode: LONGINT ): ADDRESS;
	dlclose-	: PROCEDURE {C} ( handle: ADDRESS );

	stackBottom-	: ADDRESS;	(* of main thread *)
	
	argc-: WORD; 
	argv-: ADDRESS;
	environ-: ADDRESS;


	PROCEDURE {INITIAL, NOPAF} Header;		(* header needed by OberonLoader *)
	CODE
		DB 'Oberon32G.binary'
		DD 0
		DD 0
		DD 0				; size of statially linked binary	( filled in by static linker )
		DD 0				; #relocations if base = 0	( filled in by static linker )
		DD 08070000H 	; base 								( set 0 by static linker )
		DD @Init0		; Loader <-- Oberon 
		DD @dlopen		; Loader --> Oberon 
		DD @dlclose		; Loader --> Oberon 
		DD @dlsym		; Loader --> Oberon 
		DD @argc			; Loader --> Oberon 
		DD @argv			; Loader --> Oberon 
		DD @environ		; Loader --> Oberon 
	END Header;		
	
	PROCEDURE {NOPAF} putc*( file: ADDRESS; c: CHAR );
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
	
 	PROCEDURE Char ( c: CHAR );
	BEGIN
		putc( 1, c )
	END Char;


 	PROCEDURE Dlsym*( handle: ADDRESS; CONST name: ARRAY OF CHAR; adr: ADDRESS );
	VAR val: ADDRESS;
	BEGIN
		val := dlsym( handle, ADDRESSOF( name[0] ) );
		SYSTEM.PUT32( adr, val );	
	END Dlsym;
	
	
	PROCEDURE {INITIAL, NOPAF} Init0;
	VAR localvar: LONGINT;
	BEGIN
		baseAdr := ADDRESSOF( Header );
		endAdr := ADDRESSOF( last );
		
		Trace.Init;
		Trace.Char := Char;
		
		stackBottom := ADDRESSOF( localvar ) + 2*SIZEOF( ADDRESS );
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
		
		UnixBinary.Mod 
		~
		
	
StaticLinker.Link  -p=Solaris32G
		Runtime Trace Glue 
		Unix  Machine  Heaps Modules  Objects  Kernel  KernelLog 
		Streams  Pipes  Commands  StdIO  TrapWriters  Traps 
		Files  UnixFiles  Clock  Dates  Reals  Strings  Diagnostics 
		BitSets  StringPool  GenericLinker  Reflection  GenericLoader
		BootConsole
		~

 
 Build 'A2Core' by joining OberonLoader (C) and oberon.bin (Oberon).	
 
 UnixBinary.Build  oberon.bin -> A2Core ~
