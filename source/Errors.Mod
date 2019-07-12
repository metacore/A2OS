MODULE Errors; (** AUTHOR "staubesv"; PURPOSE "Error message interface"; *)
(**
 * Interface to system-wide unique error codes. Can be used by application to retrieve textual representations
 * error codes.
 *
 * Notes:
 *	- only for use withhin applications
 *	- don't move this file to the system package, never use it from within modules in the system package
 *)

IMPORT
	Modules, Streams, Commands, Strings, Files;

CONST
	DefaultErrorMessageFile = "errors.txt";

	MaxLineLength = 256; (* Maximum length of line in error message file *)
	InitialCacheSize = 128;

	(* parser result codes *)
	Ok = 0;
	NotFound = 1;
	Error = 2;
	FileNotFound = 3;

	UnknownModule = "Unknown";

TYPE

	ErrorMessage* = RECORD
		code : LONGINT;
		moduleName- : Modules.Name;
		text- : Strings.String; (* is never NIL *)
	END;

	ErrorMessages = POINTER TO ARRAY OF ErrorMessage;

VAR
	cache : ErrorMessages;
	index : LONGINT;
	lastModuleName : Modules.Name;

PROCEDURE GetErrorString(errorCode : WORD) : Strings.String;
VAR message : ARRAY 128 OF CHAR; nbr : ARRAY 16 OF CHAR;
BEGIN
	message := "Unknown error, res: ";
	Strings.IntToStr(errorCode, nbr); Strings.Append(message, nbr);
	RETURN Strings.NewString(message);
END GetErrorString;

(** Get error message for the specified error number. If no message can be found, a generic error message is generated *)
PROCEDURE GetErrorMessage*(errorCode : WORD) : ErrorMessage;
VAR errorMessage : ErrorMessage; res : WORD;
BEGIN {EXCLUSIVE}
	res := -1;
	Get(errorCode, errorMessage, res);
	IF (res # Ok) THEN
		errorMessage.moduleName := UnknownModule;
		errorMessage.text := GetErrorString(errorCode);
	END;
	ASSERT(errorMessage.text # NIL);
	RETURN errorMessage;
END GetErrorMessage;

PROCEDURE ToStream*(errorCode : WORD; out : Streams.Writer);
VAR errorMessage : ErrorMessage;
BEGIN
	ASSERT(out # NIL);
	errorMessage := GetErrorMessage(errorCode);
	out.String(errorMessage.text^);
	out.String(" (");
	IF (errorMessage.moduleName # UnknownModule) THEN out.String(errorMessage.moduleName); out.String(":"); END;
	out.Int(errorCode, 0); out.String(")");
	out.Update;
END ToStream;

PROCEDURE ResizeCache;
VAR newCache : ErrorMessages; i : LONGINT;
BEGIN
	IF (cache # NIL) THEN
		NEW(newCache, 2*LEN(cache));
		FOR i := 0 TO LEN(cache)-1 DO newCache[i] := cache[i]; END;
	ELSE
		NEW(newCache, InitialCacheSize);
	END;
	cache := newCache;
END ResizeCache;

PROCEDURE Add(CONST errorMessage : ErrorMessage);
BEGIN
	IF (cache = NIL) OR (index >= LEN(cache)) THEN ResizeCache; END;
	cache[index] := errorMessage;
	INC(index);
END Add;

PROCEDURE Get(number : WORD; VAR errorMessage : ErrorMessage; VAR res : WORD);
VAR i : LONGINT;
BEGIN
	IF (cache # NIL) THEN
		i := 0; WHILE (i < index) & (cache[i].code # number) DO INC(i); END;
	ELSE
		i := MAX(LONGINT);
	END;
	IF (i < index) THEN
		errorMessage := cache[i]; res := Ok;
	ELSE
		res := NotFound;
	END;
END Get;

PROCEDURE ParseLine(reader : Streams.Reader; VAR errorMessage : ErrorMessage; VAR res : WORD);
VAR line : ARRAY MaxLineLength OF CHAR;
BEGIN
	IF reader.GetInteger(errorMessage.code, FALSE) THEN
		reader.SkipWhitespace;
		reader.Ln(line);
		IF (reader.res = Ok) THEN
			errorMessage.text := Strings.NewString(line);
		END;
	END;
	res := reader.res;
END ParseLine;

PROCEDURE ParseFile(CONST filename : Files.FileName; VAR res : WORD);
VAR file : Files.File; reader : Files.Reader; errorMessage : ErrorMessage; ch : CHAR;
BEGIN
	file := Files.Old(filename);
	IF (file # NIL) THEN
		res := Ok;
		Files.OpenReader(reader, file, 0);
		WHILE (res = Ok) & (reader.res # Streams.EOF) DO
			ch := reader.Peek();
			IF (ch # "#") THEN
				ParseLine(reader, errorMessage, res);
				IF (res = Ok) THEN
					IF (errorMessage.code MOD 100 # 0) THEN
						errorMessage.moduleName := lastModuleName;
						Add(errorMessage);
					ELSE
						COPY(errorMessage.text^, lastModuleName);
					END;
				END;
			ELSE
				reader.SkipLn; (* skip line comment *)
			END;
		END;
		IF (reader.res = Streams.Ok) OR (reader.res = Streams.EOF)  THEN res := Ok; ELSE res := Error; END;
	ELSE
		res := FileNotFound;
	END;
END ParseFile;

(**	Load and parse a error message file. *)
PROCEDURE Open*(context : Commands.Context); (** [filename] ~ *)
VAR filename : Files.FileName; res : WORD;
BEGIN {EXCLUSIVE}
	index := 0; cache := NIL;
	context.arg.SkipWhitespace; context.arg.String(filename);
	IF (filename = "") THEN COPY(DefaultErrorMessageFile, filename); END;
	context.out.String("Errors: Loading error messages from file "); context.out.String(filename);
	context.out.String(" ... "); context.out.Update;
	ParseFile(filename, res);
	IF (res = Ok) THEN
		context.out.Int(index, 0); context.out.String(" messages loaded.");
	ELSE
		context.out.String("failed, res: "); context.out.Int(res, 0);
	END;
	context.out.Ln;
END Open;

(** Show the error message for the optionally specified error number. If no number is specified,
	show all loaded error messages. This procedure is primarly for testing purposes. *)
PROCEDURE Show*(context : Commands.Context); (** [error number] ~ *)
CONST Tab = 09X;
VAR number, i : LONGINT; errorMessage : ErrorMessage;
BEGIN
	IF context.arg.GetInteger(number, FALSE) THEN
		errorMessage := GetErrorMessage(number);
		context.out.String("Error message for number "); context.out.Int(number, 0); context.out.String(": ");
		context.out.String("Module: "); context.out.String(errorMessage.moduleName);
		context.out.String(", Text: "); context.out.String(errorMessage.text^);
	ELSE
		context.out.String("Errors: ");
		IF (index > 0) THEN
			context.out.Int(index, 0); context.out.String(" error messages loaded: "); context.out.Ln;
			BEGIN {EXCLUSIVE}
				FOR i := 0 TO index-1 DO
					context.out.Int(cache[i].code, 0); context.out.Char(Tab);
					context.out.String(cache[i].text^);
					context.out.String(" ("); context.out.String(cache[i].moduleName); context.out.String(")");
					context.out.Ln;
				END;
			END;
		ELSE
			context.out.String("No error messages loaded.");
		END;
	END;
	context.out.Ln;
END Show;

BEGIN
	index := 0;
	lastModuleName := "";
END Errors.

Errors.Open ~

Errors.Show 1505~

Errors.Show~

System.Free Errors ~
