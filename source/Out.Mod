MODULE Out; (** AUTHOR "FOF"; PURPOSE "Simple console output, for educational purposes"; *)

(* threadsafe as far as commands don't share the same context *)

IMPORT Commands, Streams;

PROCEDURE GetWriter*(): Streams.Writer;
BEGIN
	RETURN Commands.GetContext().out;
END GetWriter;

PROCEDURE String*(CONST s: ARRAY OF CHAR);
BEGIN
	Commands.GetContext().out.String(s);
END String;

PROCEDURE Char*(c: CHAR);
BEGIN
	Commands.GetContext().out.Char(c);
END Char;

PROCEDURE Ln*();
BEGIN
	Commands.GetContext().out.Ln();
END Ln;

PROCEDURE Set*(s: SET);
BEGIN
	Commands.GetContext().out.Set(s);
END Set;

PROCEDURE Int*(i: HUGEINT; n = 1: WORD);
BEGIN
	Commands.GetContext().out.Int(i,n);
END Int;

PROCEDURE Hex*(i: HUGEINT; n = -16: WORD);
BEGIN
	Commands.GetContext().out.Hex(i,n);
END Hex;

PROCEDURE Address*(a: ADDRESS);
BEGIN
	Commands.GetContext().out.Address(a);
END Address;

PROCEDURE Float*(x: LONGREAL; n = 4, f= 3, d=0: WORD);
BEGIN
	Commands.GetContext().out.FloatFix(x,n,f,d);
END Float;

PROCEDURE Update*;
BEGIN
	Commands.GetContext().out.Update();
END Update;



END Out.

System.Free Out ~
Out.Hello


