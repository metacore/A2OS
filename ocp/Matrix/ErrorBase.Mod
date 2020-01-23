MODULE ErrorBase;
(*
	DESCRIPTION:
		Errors and warnings handling

	AUTHOR:
		Alexey Morozov
*)

IMPORT
	Out:=KernelLog;

TYPE
	ERRSTR* = ARRAY 256 OF CHAR;
	WARNSTR* = ARRAY 256 OF CHAR;

	(*
		Error handler procedure
			errLocation - location of error occurence
			errText - text describing an error
	*)
	ErrorHandler* = PROCEDURE{DELEGATE}(CONST errLocation, errText: ARRAY OF CHAR);

	(*
		Warning handler procedure
			warnLocation - location of warning occurence
			warnText - text describing an warning
	*)
	WarningHandler* = PROCEDURE{DELEGATE}(CONST warnLocation, warnText: ARRAY OF CHAR);

VAR
	(* exported error handler *)
	Error-: ErrorHandler;
	Warning-: WarningHandler;

	(*/////////////////////////////////////////////////
		DESCRIPTION:
			Default error handler
		INPUT:
			errLocation - location of error occurence
			errText - text describing the error
	/////////////////////////////////////////////////*)
	PROCEDURE HandleErrorDefault(CONST errLocation, errText: ARRAY OF CHAR);
	BEGIN
		Out.Enter;
		Out.String('Error in ');
		Out.String(errLocation); Out.String('-> ');
		Out.String(errText); Out.Ln;
		Out.Exit;
		HALT(100);
	END HandleErrorDefault;

	(*/////////////////////////////////////////////////
		DESCRIPTION:
			Default warning handler
		INPUT:
			warnLocation - location of warning occurence
			warnText - text describing the warning
	/////////////////////////////////////////////////*)
	PROCEDURE HandleWarningDefault(CONST warnLocation, warnText: ARRAY OF CHAR);
	BEGIN
		Out.Enter;
		Out.String('Warning in ');
		Out.String(warnLocation); Out.String('-> ');
		Out.String(warnText); Out.Ln;
		Out.Exit;
	END HandleWarningDefault;

	(*/////////////////////////////////////////////////
		DESCRIPTION:
			Setup of a new error handler
		INPUT:
			handler - pointer to a new procedure
	/////////////////////////////////////////////////*)
	PROCEDURE SetErrorHandler*(handler: ErrorHandler);
	BEGIN{EXCLUSIVE}
		IF handler # NIL THEN
			Error := handler;
		ELSE
			HandleErrorDefault('ErrorBase.SetErrorHandler','specified error handler is NIL!');
		END;
	END SetErrorHandler;

	(*/////////////////////////////////////////////////
		DESCRIPTION:
			Setup of a new warning handler
		INPUT:
			handler - pointer to a new procedure
	/////////////////////////////////////////////////*)
	PROCEDURE SetWarningHandler*(handler: WarningHandler);
	BEGIN{EXCLUSIVE}
		IF handler # NIL THEN
			Warning := handler;
		ELSE
			Error('ErrorBase.SetWarningHandler','specified warning handler is NIL!');
		END;
	END SetWarningHandler;

BEGIN
	Error := HandleErrorDefault;
	Warning := HandleWarningDefault;
END ErrorBase. 