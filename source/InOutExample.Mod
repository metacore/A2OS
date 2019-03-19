MODULE InOutExample; (** AUTHOR "FOF"; PURPOSE "simple demo of simple in and out"; *)

IMPORT In, Out, Commands, Streams;

(* thread safe when executed in isolated commands context, e.g. in PET
	this does NOT imply that several commands in the same context would not produce unpredictable results.
 *)
PROCEDURE Hello*;
VAR name: ARRAY 32 OF CHAR;
BEGIN
	IF In.String(name) THEN
		Out.String("Hello "); Out.String(name); Out.Ln;
	ELSE
		Out.String("Hello World!"); Out.Ln;
	END;
END Hello;

PROCEDURE Number*;
VAR r: LONGREAL; name: ARRAY 32 OF CHAR;
BEGIN
	IF In.String(name) & In.Real(r) THEN
		Out.String(name); Out.String(" = "); Out.Float(r); Out.Ln;
		Out.String(name); Out.String(" = "); Out.Float(r,20); Out.Ln;
		Out.String(name); Out.String(" = "); Out.Float(r,20,15,-1); Out.Ln;
	END;
END Number;


END InOutExample.

System.Free InOutExample In Out  ~

InOutExample.Hello Oberon ~
InOutExample.Hello ~
InOutExample.Number pi 	3.14159265358979323846E0;
~

