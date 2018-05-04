MODULE Runtime;
VAR
	kernelModule-: ARRAY 32 OF ADDRESS;
	modules-: LONGINT;

	PROCEDURE InsertModule*(a: ADDRESS): BOOLEAN;
	BEGIN
		kernelModule[modules] := a;
		INC(modules);
		RETURN TRUE
	END InsertModule;
END Runtime.