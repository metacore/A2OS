(**
	AUTHOR: Alexey Morozov
	PURPOSE: Dynamic library tools for Unix platforms
*)
MODULE HostLibs;

IMPORT
	Unix;

TYPE
	LibHandle* = ADDRESS; (** dynamic library handle type *)

CONST
	NilLibHandle* = NIL; (** invalid library handle *)
	
(*
	dlopen flags
	
	#define RTLD_LAZY     0x0001
	#define RTLD_NOW      0x0002
	#define RTLD_GLOBAL   0x0100
	#define RTLD_LOCAL    0x0000
	#define RTLD_NOSHARE  0x1000
	#define RTLD_EXE      0x2000
	#define RTLD_SCRIPT   0x4000
*)

	(**
		Load a dynamic library

		fileName: library file name
		lib: returned loaded library handle; NilLibHandle in case of an error

		Return: TRUE in case of success
	*)
	PROCEDURE LoadLibrary*(CONST fileName: ARRAY OF CHAR; VAR lib: LibHandle): BOOLEAN;
	BEGIN
		lib := Unix.Dlopen(fileName, 0x0002);
		RETURN (lib # NilLibHandle);
	FINALLY
		RETURN FALSE;
	END LoadLibrary;

	(**
		Free a previously loaded dynamic library

		lib: library handle
		
		Return: TRUE in case of success
	*)
	PROCEDURE FreeLibrary*(CONST lib: LibHandle): BOOLEAN;
	BEGIN
		Unix.Dlclose(lib);
		RETURN TRUE;
	FINALLY
		RETURN FALSE;
	END FreeLibrary;

	(**
		Get a procedure from a loaded dynamic library

		lib: library handle
		name: name of the procedure
		procAddr: address of the destination procedure pointer (e.g. ADDRESSOF(procedureVariable))

		Return: TRUE in case of success
	*)
	PROCEDURE GetProcedure*(CONST lib: LibHandle; CONST name: ARRAY OF CHAR; CONST procAddr: ADDRESS): BOOLEAN;
	VAR addr: ADDRESS;
	BEGIN
		ASSERT(procAddr # NIL);
		Unix.Dlsym(lib,name,procAddr);
		SYSTEM.GET(procAddr,addr);
		RETURN addr # NIL;
	FINALLY
		RETURN FALSE;
	END GetProcedure;

END HostLibs.
