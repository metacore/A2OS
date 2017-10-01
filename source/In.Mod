MODULE In; (** AUTHOR "FOF"; PURPOSE "Simple argument parser for educational purposes"; *)

IMPORT Commands, Streams;

PROCEDURE GetArg*(): Streams.Reader;
BEGIN
	RETURN Commands.GetContext().arg;
END GetArg;

PROCEDURE Char*(VAR ch: CHAR): BOOLEAN;
BEGIN
	RETURN GetArg().GetChar(ch);
END Char;

PROCEDURE Int*(VAR i: LONGINT; hex = TRUE: BOOLEAN): BOOLEAN;
(* hex = TRUE means that hex numbers are allowed. A hex number must have the "H" postfix *)
BEGIN
	RETURN GetArg().GetInteger(i, hex);
END Int;

PROCEDURE Real*(VAR f: LONGREAL): BOOLEAN;
BEGIN
	RETURN GetArg().GetReal(f);
END Real;

PROCEDURE String*(VAR s: ARRAY OF CHAR): BOOLEAN;
BEGIN
	RETURN GetArg().GetString(s);
END String;

END In.


