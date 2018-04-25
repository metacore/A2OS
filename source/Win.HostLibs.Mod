(**
	AUTHOR: Alexey Morozov
	PURPOSE: Dynamic library tools for Windows platforms
*)
MODULE HostLibs;

IMPORT
	SYSTEM, Kernel32;

TYPE
	LibHandle* = Kernel32.HANDLE; (** dynamic library handle type *)

CONST
	NilLibHandle* = Kernel32.NULL; (** invalid library handle *)

	(**
		Load a dynamic library

		fileName: library file name
		lib: returned loaded library handle; NilLibHandle in case of an error

		Return: TRUE in case of success
	*)
	PROCEDURE LoadLibrary*(CONST fileName: ARRAY OF CHAR; VAR lib: LibHandle): BOOLEAN;
	BEGIN
		lib := Kernel32.LoadLibrary(fileName);
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
		RETURN (Kernel32.FreeLibrary(lib) # 0);
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
		Kernel32.GetProcAddress(lib,name,addr);
		IF addr # NIL THEN
			SYSTEM.PUT(procAddr,addr);
			RETURN TRUE;
		END;
	FINALLY
		RETURN FALSE;
	END GetProcedure;

END HostLibs.
