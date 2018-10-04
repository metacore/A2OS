(* Copyright (c) 1994 - 2000 Emil J. Zeller *)

MODULE Registry IN Oberon; (** non-portable / source: Win32.Registry.Mod *)	(* ejz  *)
	IMPORT SYSTEM, Kernel32 IN A2, ADVAPI32 IN A2;

(** This module provides an interface to the Windows registry. To read Oberon configuration data stored in the registry use Oberon.OpenScanner and the commands System.Set and System.Get . *)

	CONST
		(** root keys *)
		ClassesRoot* = ADVAPI32.HKEYClassesRoot; CurrentUser* = ADVAPI32.HKEYCurrentUser;
		(** result codes *)
		Done* = 0; Failed* = 1; NotFound* = 2;

	TYPE
		PathEnumerator* = PROCEDURE (path: ARRAY OF CHAR);
		KeyValueEnumerator* = PROCEDURE (key, value: ARRAY OF CHAR);

	VAR
		oberonRoot*, (** root path for all Oberon settings *)
		oberonSystem*: ARRAY Kernel32.MaxPath OF CHAR; (** path for System settings *)
		res*: LONGINT; (** Done, Failed, NotFound *)
		stamp*: LONGINT; (** Time stamp of last modification to the registry. *)
		hFile: Kernel32.HANDLE; logfile: BOOLEAN;

	PROCEDURE Append(VAR to: ARRAY OF CHAR; this: ARRAY OF CHAR);
		VAR i, j, l: LONGINT;
	BEGIN
		i := 0; WHILE to[i] # 0X DO INC(i) END;
		l := LEN(to)-1; j := 0;
		WHILE (i < l) & (this[j] # 0X) DO
			to[i] := this[j]; INC(i); INC(j)
		END;
		to[i] := 0X
	END Append;

	PROCEDURE AppendCh(VAR to: ARRAY OF CHAR; this: CHAR);
		VAR i: LONGINT;
	BEGIN
		i := 0; WHILE to[i] # 0X DO INC(i) END;
		IF i < (LEN(to)-1) THEN
			to[i] := this; to[i+1] := 0X
		END
	END AppendCh;

	(** Get the full path to Oberon settings stored under key.
		Note: Oberon uses CurrentUser as root key. *)
	PROCEDURE OberonPath*(path: ARRAY OF CHAR; VAR fullPath: ARRAY OF CHAR);
	BEGIN
		COPY(oberonRoot, fullPath); AppendCh(fullPath, "\"); Append(fullPath, path)
	END OberonPath;

	(** Set a key/value pair, key = "" sets the default value for path. *)
	PROCEDURE SetKeyValue*(root: ADVAPI32.HKEY; path, key, value: ARRAY OF CHAR);
		VAR hKey: ADVAPI32.HKEY; i: LONGINT;
	BEGIN
		IF ADVAPI32.RegCreateKeyEx(root, path, 0, NIL, ADVAPI32.RegOptionNonVolatile, {ADVAPI32.KeySetValue, ADVAPI32.KeyCreateSubKey}, NIL, hKey, NIL) # ADVAPI32.Success THEN
			res := NotFound; RETURN
		END;
		i := 0; WHILE value[i] # 0X DO INC(i) END; INC(i);
		IF ADVAPI32.RegSetValueEx(hKey, key, 0, ADVAPI32.RegSZ, value, i) = ADVAPI32.Success THEN
			INC(stamp); res := Done
		ELSE
			res := Failed
		END;
		IGNORE ADVAPI32.RegCloseKey(hKey)
	END SetKeyValue;

	(** Retrieve the value stored under key. use key = "" to retrieve the default value for path. *)
	PROCEDURE GetKeyValue*(root: ADVAPI32.HKEY; path, key: ARRAY OF CHAR; VAR value: ARRAY OF CHAR);
		VAR hKey: ADVAPI32.HKEY; type, len, ret: LONGINT; buf: POINTER TO ARRAY OF CHAR;
	BEGIN
		IF ADVAPI32.RegOpenKeyEx(root, path, 0, {ADVAPI32.KeyQueryValue}, hKey) # ADVAPI32.Success THEN
			res := NotFound; RETURN
		END;
		len := LEN(value); type := ADVAPI32.RegNone;
		ret := ADVAPI32.RegQueryValueEx(hKey, key, NIL, type, value, len);
		IF (type # ADVAPI32.RegSZ) OR (ret # ADVAPI32.Success) THEN
			IF (type = ADVAPI32.RegSZ) & (ret = ADVAPI32.ErrorMoreData) THEN
				NEW(buf, len+1);
				IGNORE ADVAPI32.RegQueryValueEx(hKey, key, NIL, type, buf^, len);
				COPY(buf^, value); res := Done
			ELSE
				res := NotFound
			END
		ELSE
			res := Done
		END;
		IGNORE ADVAPI32.RegCloseKey(hKey)
	END GetKeyValue;

	(** Delete key and its value, key = "" deletes the default value for path. *)
	PROCEDURE DeleteKeyValue*(root: ADVAPI32.HKEY; path, key: ARRAY OF CHAR);
		VAR hKey: ADVAPI32.HKEY;
	BEGIN
		IF ADVAPI32.RegOpenKeyEx(root, path, 0, {ADVAPI32.KeySetValue}, hKey) # ADVAPI32.Success THEN
			res := NotFound; RETURN
		END;
		IF ADVAPI32.RegDeleteValue(hKey, key) = ADVAPI32.Success THEN
			INC(stamp); res := Done
		ELSE
			res := NotFound
		END;
		IGNORE ADVAPI32.RegCloseKey(hKey)
	END DeleteKeyValue;

	(** Recursive delete all sub-paths, keys and values in path.
		Note: be very careful when using this procedure!!! *)
	PROCEDURE DeletePath*(root: ADVAPI32.HKEY; path: ARRAY OF CHAR);
		VAR buffer: ARRAY Kernel32.MaxPath OF CHAR; hKey: ADVAPI32.HKEY; size: LONGINT;
	BEGIN
		IF ADVAPI32.RegOpenKeyEx(root, path, 0, ADVAPI32.KeyAllAccess, hKey) # ADVAPI32.Success THEN
			res := NotFound; RETURN
		END;
		size := Kernel32.MaxPath;
		WHILE ADVAPI32.RegEnumKeyEx(hKey, 0, buffer, size, NIL, NIL, NIL, NIL) = ADVAPI32.Success DO
			DeletePath(hKey, buffer);
			IF res # Done THEN
				IGNORE ADVAPI32.RegCloseKey(hKey); RETURN
			END;
			size := Kernel32.MaxPath
		END;
		IGNORE ADVAPI32.RegCloseKey(hKey);
		IF ADVAPI32.RegDeleteKey(root, path) = ADVAPI32.Success THEN
			INC(stamp); res := Done
		ELSE
			res := Failed
		END
	END DeletePath;

	(** Enumerate all sub-paths in path. *)
	PROCEDURE EnumeratePath*(root: ADVAPI32.HKEY; path: ARRAY OF CHAR; enum: PathEnumerator);
		VAR subPath: ARRAY Kernel32.MaxPath OF CHAR; hKey: ADVAPI32.HKEY; ret, i, size: LONGINT;
	BEGIN
		ret := ADVAPI32.RegOpenKeyEx(root, path, 0, {ADVAPI32.KeyEnumerateSubKeys}, hKey);
		IF ret # ADVAPI32.Success THEN
			res := NotFound; RETURN
		END;
		i := 0;
		WHILE ret = ADVAPI32.Success DO
			size := Kernel32.MaxPath;
			ret := ADVAPI32.RegEnumKeyEx(hKey, i, subPath, size, NIL, NIL, NIL, NIL);
			IF ret = ADVAPI32.Success THEN enum(subPath) END;
			INC(i)
		END;
		IGNORE ADVAPI32.RegCloseKey(hKey); res := Done
	END EnumeratePath;

	(** Enumerate all key/value pairs in path.*)
	PROCEDURE EnumerateKeyValue*(root: ADVAPI32.HKEY; path: ARRAY OF CHAR; enum: KeyValueEnumerator);
		VAR
			key, value: ARRAY Kernel32.MaxPath OF CHAR; hKey: ADVAPI32.HKEY;
			ret, i, type, kLen, vLen: LONGINT;
	BEGIN
		ret := ADVAPI32.RegOpenKeyEx(root, path, 0, {ADVAPI32.KeyQueryValue}, hKey);
		IF ret # ADVAPI32.Success THEN
			res := NotFound; RETURN
		END;
		i := 0;
		WHILE ret = ADVAPI32.Success DO
			kLen := Kernel32.MaxPath; vLen := Kernel32.MaxPath; type := ADVAPI32.RegNone;
			ret := ADVAPI32.RegEnumValue(hKey, i, key, kLen, NIL, type, value, vLen);
			IF (ret = ADVAPI32.Success) & (type = ADVAPI32.RegSZ) THEN enum(key, value) END;
			INC(i)
		END;
		IGNORE ADVAPI32.RegCloseKey(hKey); res := Done
	END EnumerateKeyValue;

	PROCEDURE OutputFileString(VAR str: ARRAY OF CHAR);
		VAR n: LONGINT; b: Kernel32.BOOL;
	BEGIN
		n := 0; WHILE str[n] # 0X DO INC(n) END;
		b := Kernel32.WriteFile(hFile, str, n, n, NIL);
		IF logfile THEN IGNORE Kernel32.FlushFileBuffers(hFile) END
	END OutputFileString;

	(*
	PROCEDURE InitConsole();
		VAR rect: Kernel32.SmallRect; file: ARRAY 260 OF CHAR; con: ARRAY 64 OF CHAR; i, j: LONGINT;
	BEGIN
		 Kernel32.OutputString := NIL;   logfile := FALSE; hFile := Kernel32.InvalidHandleValue;
		GetKeyValue(CurrentUser, oberonSystem, "Console", con);
		IF res = Done THEN
			IF con[0] = '"' THEN con[0] := con[1] END;
			IF CAP(con[0]) = "C" THEN (* console window *)
				con := "ETH Oberon - Console";
				Kernel32.AllocConsole(); Kernel32.SetConsoleTitle(con);
				hFile := Kernel32.GetStdHandle(Kernel32.STDOutput);
				Kernel32.SetConsoleScreenBufferSize(hFile, 80 + ASH(1024, 16));
				rect.top := 0; rect. left := 0; rect.bottom := 24; rect.right := 79;
				Kernel32.SetConsoleWindowInfo(hFile, Kernel32.True, rect)
			ELSIF CAP(con[0]) = "S" THEN (* standard output -> requires CUI*)
				hFile := Kernel32.GetStdHandle(Kernel32.STDOutput)
			ELSIF CAP(con[0]) = "F" THEN (* log file *)
				con := "Oberon.Log"; logfile := TRUE;
				Kernel32.GetModuleFileName(Kernel.hInstance, file, 260);
				i := 0; j := 0;
				WHILE file[i] # 0X DO
					IF file[i] = "\" THEN j := i+1 END;
					INC(i)
				END;
				file[j] := 0X; i := 0;
				WHILE con[i] # 0X DO
					file[j] := con[i]; INC(i); INC(j)
				END;
				file[j] := 0X;
				hFile := Kernel32.CreateFile(file, {Kernel32.GenericWrite}, {Kernel32.FileShareRead}, NIL, Kernel32.CreateAlways, {Kernel32.FileAttributeNormal}, Kernel32.NULL);
				i := 1;
				WHILE (i <= 9) & (hFile = Kernel32.InvalidHandleValue) DO
					file[j] := CHR(i+ORD("0")); file[j+11] := 0X;
					hFile := Kernel32.CreateFile(file, {Kernel32.GenericWrite}, {Kernel32.FileShareRead}, NIL, Kernel32.CreateAlways, {Kernel32.FileAttributeNormal}, Kernel32.NULL);
					INC(i)
				END
			END;
			IF hFile # Kernel32.InvalidHandleValue THEN
				Kernel32.OutputString := OutputFileString
			ELSIF (CAP(con[0]) # "N") & (Kernel32.OutputString = NIL) THEN (* debugger *)
				Kernel32.OutputString := Kernel32.OutputDebugString
			END
		ELSE
			Kernel32.OutputString := Kernel32.OutputDebugString
		END;
		Modules.InstallTermHandler(ShutdownConsole)
	END InitConsole;

	PROCEDURE ShutdownConsole();
	BEGIN
		IF logfile & (hFile # Kernel32.InvalidHandleValue) THEN
			Kernel32.CloseHandle(hFile); hFile := Kernel32.InvalidHandleValue
		END;
		Kernel32.OutputString := Kernel32.OutputDebugString
	END ShutdownConsole;
		*)

	PROCEDURE Init;
		VAR
			file, name, value, software, version: ARRAY Kernel32.MaxPath OF CHAR;
			buf: POINTER TO ARRAY OF SYSTEM.BYTE; adr: ADDRESS; len, i: LONGINT; ch: CHAR;
	BEGIN
		res := Done; stamp := 0;
		IGNORE Kernel32.GetModuleFileName(Kernel32.hInstance, file, Kernel32.MaxPath);
		len := ADVAPI32.GetFileVersionInfoSize(file, NIL);

		NEW(buf, len);

		IGNORE ADVAPI32.GetFileVersionInfo(file, 0, len, buf^);
		IGNORE ADVAPI32.VerQueryValue(buf^, "\StringFileInfo\040904e4\FileDescription", adr, len);
		IF len >= Kernel32.MaxPath THEN HALT(99) END;
		SYSTEM.MOVE(adr, ADDRESSOF(software), len);
		IGNORE ADVAPI32.VerQueryValue(buf^, "\StringFileInfo\040904e4\FileVersion", adr, len);
		IF len >= Kernel32.MaxPath THEN HALT(99) END;
		SYSTEM.MOVE(adr, ADDRESSOF(version), len);
		(* cmd  { "-" name [ "=" value ] } *)
		name := ""; i := 0;
		adr := Kernel32.GetCommandLine();

		REPEAT
			SYSTEM.GET(adr, ch); INC(adr);
			IF ch = "-" THEN
				value[i] := 0X; i := 0;
				IF name = "Registry" THEN COPY(value, version) END
			ELSIF ch = "=" THEN
				value[i] := 0X; i := 0; COPY(value, name)
			ELSIF ch > " " THEN
				value[i] := ch; INC(i)
			ELSE
				value[i] := 0X
			END
		UNTIL (ch = 0X) OR (i >= LEN(name)) ;
		IF (i > 0) & (name = "Registry") THEN
			value[i] := 0X; COPY(value, version)
		END;
		oberonRoot := "Software\"; Append(oberonRoot, software);
		AppendCh(oberonRoot, "\"); Append(oberonRoot, version);
		OberonPath("System", oberonSystem);
	END Init;

BEGIN
	Init(); (* InitConsole() *)
END Registry.
