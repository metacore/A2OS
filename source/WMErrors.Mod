MODULE WMErrors; (** AUTHOR "staubesv"; PURPOSE "Error message dialogs"; *)

IMPORT
	Commands, Strings, Errors, WMDialogs;

CONST
	ErrorDialogTitle = "Error";

	ShowModuleName = TRUE;
	ShowErrorCode = TRUE;
	MaxErrorTextLength = 512;

PROCEDURE Show*(errorCode : INTEGER);
VAR
	errorMessage : Errors.ErrorMessage;
	text : ARRAY MaxErrorTextLength OF CHAR;
	number : ARRAY 16 OF CHAR;
BEGIN
	errorMessage := Errors.GetErrorMessage(errorCode);
	COPY(errorMessage.text^, text);
	IF ShowModuleName OR ShowErrorCode THEN
		Strings.Append(text, " (");
		IF ShowModuleName THEN
			Strings.Append(text, errorMessage.moduleName);
			IF ShowErrorCode THEN Strings.Append(text, ":"); END;
		END;
		IF ShowErrorCode THEN
			Strings.IntToStr(errorCode, number); Strings.Append(text, number);
		END;
		Strings.Append(text, ")");
	END;
	WMDialogs.Information(ErrorDialogTitle, text);
END Show;

PROCEDURE ShowMessage*(CONST message : ARRAY OF CHAR);
BEGIN
	WMDialogs.Information(ErrorDialogTitle, message);
END ShowMessage;

PROCEDURE Test*(context : Commands.Context);
VAR errorCode : SIGNED32;
BEGIN
	IF context.arg.GetInteger(errorCode, FALSE) THEN
		Show(errorCode);
	ELSE
		context.result := Commands.CommandParseError;
	END;
END Test;

END WMErrors.

WMErrors.Test 1505 ~

System.Free WMErrors ~
