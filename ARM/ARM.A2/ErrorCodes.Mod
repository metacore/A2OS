MODULE ErrorCodes;
(**
	AUTHOR: Alexey Morozov and Timothee Martiel, HighDim GmbH, 2015
	PURPOSE: generic error management runtime
*)

IMPORT
	Modules;

CONST
	ErrorCodeRangeSize* = 4096;
	MaxNumModules* = 128;

	Ok* = 0;

	(** New line types *)
	LnCRLF* = 0;
	LnCR* = 1;
	LnLF* = 2;

	LnType* = LnCRLF;

TYPE
	Module = POINTER TO RECORD
		name: Modules.Name;
		errorBase: SIGNED32;
	END;

VAR
	modules: ARRAY MaxNumModules OF Module;
	numModules: SIGNED32;
	ln: ARRAY 3 OF CHAR;

	acquire*, release*: PROCEDURE{DELEGATE}(); (** plugable locks for thread-safety if required *)

	(**
		Register a module by name and get its corresponding error base
	*)
	PROCEDURE RegisterModule*(CONST modName: ARRAY OF CHAR; VAR errorBase: SIGNED32);
	VAR mod: Module;
	BEGIN
		IF acquire # NIL THEN acquire; END;

		mod := modules[numModules];
		IF mod = NIL THEN NEW(mod); END;
		COPY(modName,mod.name);
		IF numModules > 0 THEN
			errorBase := mod.errorBase+ErrorCodeRangeSize;
		ELSE errorBase := 0;
		END;
		mod.errorBase := errorBase;
		modules[numModules] := mod;
		INC(numModules);

		IF release # NIL THEN release; END;
	END RegisterModule;

	(**
		Unregister a module by its name
	*)
	PROCEDURE UnregisterModule*(CONST modName: ARRAY OF CHAR);
	VAR i: SIGNED32;
	BEGIN
		IF acquire # NIL THEN acquire; END;

		i := 0;
		WHILE (i < numModules) & (modules[i].name # modName) DO INC(i); END;
		IF i < numModules THEN
			FOR i := i TO numModules-2 DO modules[i] := modules[i+1]; END;
			DEC(numModules);
		END;

		IF release # NIL THEN release; END;
	END UnregisterModule;

	(**
		Get error code for the module at the specified level
	*)
	PROCEDURE Get*(error: SIGNED32; level: SIGNED32; VAR modName: ARRAY OF CHAR; VAR modError: SIGNED32);
	BEGIN
		modError := (error DIV (level*ErrorCodeRangeSize))  MOD ErrorCodeRangeSize;
		COPY(modules[level].name,modName);
	END Get;

	(**
		Get the error base for a module with a given name

		Returns -1 in case if the module was not found in the list of registered modules
	*)
	PROCEDURE GetErrorBase*(CONST modName: ARRAY OF CHAR): SIGNED32;
	VAR i, errorBase: SIGNED32;
	BEGIN
		IF acquire # NIL THEN acquire; END;

		i := 0;
		WHILE (i < numModules) & (modules[i].name # modName) DO INC(i); END;
		IF i < numModules THEN
			errorBase := modules[i].errorBase;
		ELSE errorBase := -1;
		END;

		IF release # NIL THEN release; END;

		RETURN errorBase;
	END GetErrorBase;

	(*
		Get a string representation of an integer (in decimal format)
	*)
	PROCEDURE IntToStr(x: SIGNED64; VAR str: ARRAY OF CHAR);
	VAR
		i, j: SIGNED32;
		ch: CHAR;
	BEGIN
		IF x < 0 THEN
			IF x = MIN(SIGNED64) THEN
				str := "-9223372036854775808";
				RETURN;
			ELSE
				str[0] := "-";
				i := 1;
				x := -x;
			END;
		END;
		REPEAT
			str[i] := CHR((x MOD 10)+48);
			x := x DIV 10;
			INC(i);
		UNTIL x = 0;
		(* reverse the output string *)
		DEC(i);
		FOR j := 0 TO (i DIV 2) BY 1 DO
			ch := str[j];
			str[j] := str[i-j];
			str[i-j] := ch;
		END;
	END IntToStr;

	(**
		Produce trace-back error printout

		errorOnly: TRUE for printing only errors
	*)
	PROCEDURE TraceBack*(error: SIGNED32; errorOnly: BOOLEAN; tracer: PROCEDURE{DELEGATE}(CONST str: ARRAY OF CHAR));
	VAR
		level, modError: SIGNED32;
		str: ARRAY 32 OF CHAR;
	BEGIN
		IF acquire # NIL THEN acquire; END;

		FOR level := 0 TO numModules-1 DO
			modError := error  MOD ErrorCodeRangeSize;
			IF (modError # Ok) OR ~errorOnly THEN
				tracer(modules[level].name);
				tracer(": "); IntToStr(modError,str); tracer(str);
				tracer(ln);
			END;
			error := error DIV ErrorCodeRangeSize;
		END;

		IF release # NIL THEN release; END;
	END TraceBack;

BEGIN
	numModules := 0;
	CASE LnType OF
		|LnCRLF: ln[0] := 0DX; ln[1] := 0AX; ln[2] := 0X;
		|LnCR: ln[0] := 0DX;  ln[1] := 0X;
		|LnLF: ln[0] := 0AX;  ln[1] := 0X;
	END;
END ErrorCodes.
