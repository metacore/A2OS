(**
	AUTHOR: Alexey Morozov
	PURPOSE: Dynamic library tools for Windows platforms
*)
MODULE HostLibs;

IMPORT
	SYSTEM, Kernel32, Files;

TYPE
	LibHandle* = Kernel32.HANDLE; (** dynamic library handle type *)

CONST
	NilLibHandle* = Kernel32.NULL; (** invalid library handle *)

	DONT_RESOLVE_DLL_REFERENCES = 0;
	LOAD_LIBRARY_AS_DATAFILE = 1;
	(* reserved for internal LOAD_PACKAGED_LIBRARY = 2; *)
	LOAD_WITH_ALTERED_SEARCH_PATH = 3;
	LOAD_IGNORE_CODE_AUTHZ_LEVEL = 4;
	LOAD_LIBRARY_AS_IMAGE_RESOURCE = 5;
	LOAD_LIBRARY_AS_DATAFILE_EXCLUSIVE = 6;
	LOAD_LIBRARY_REQUIRE_SIGNED_TARGET = 7;
	LOAD_LIBRARY_SEARCH_DLL_LOAD_DIR = 8;
	LOAD_LIBRARY_SEARCH_APPLICATION_DIR = 9;
	LOAD_LIBRARY_SEARCH_USER_DIRS = 10;
	LOAD_LIBRARY_SEARCH_SYSTEM32 = 11;
	LOAD_LIBRARY_SEARCH_DEFAULT_DIRS = 12;
	LOAD_LIBRARY_SAFE_CURRENT_DIRS = 13;
	LOAD_LIBRARY_SEARCH_SYSTEM32_NO_FORWARDER = 14;

	(**
		Load a dynamic library

		fileName: library file name
		lib: returned loaded library handle; NilLibHandle in case of an error

		Return: TRUE in case of success
	*)
	PROCEDURE LoadLibrary*(CONST fileName: ARRAY OF CHAR; VAR lib: LibHandle): BOOLEAN;
	CONST
		LoadLibraryExFlags = {LOAD_LIBRARY_SEARCH_DLL_LOAD_DIR, LOAD_LIBRARY_SEARCH_DEFAULT_DIRS};
	VAR
		err: SIGNED32;
		fullName: Files.FileName;
		flags: SET;
		i: SIZE;
	BEGIN
		IF Files.Exists(fileName, fullName, flags) THEN
			WHILE fullName[i] # 0X DO
				IF fullName[i] = "/" THEN fullName[i] := "\"; END;
				INC(i);
			END;
			lib := Kernel32.LoadLibraryEx(fullName, NIL, LoadLibraryExFlags);
			IF lib = NilLibHandle THEN
				err := Kernel32.GetLastError();
				TRACE(fullName, err);
			END;
		ELSE (*! can happen when the library path is not specified *)
			lib := Kernel32.LoadLibrary(fileName);
			IF lib = NilLibHandle THEN
				err := Kernel32.GetLastError();
				TRACE(fileName, err);
			END;
		END;
		RETURN lib # NilLibHandle;
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

System.FreeDownTo HostLibs ~
