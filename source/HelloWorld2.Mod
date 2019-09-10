MODULE HelloWorld2;

IMPORT
	Commands;

PROCEDURE HelloStream*(context : Commands.Context);
VAR i : SIGNED32;
BEGIN
	context.out.String("Hello World");
	FOR i := 0 TO 9 DO
		context.out.Int(i, 0)
	END;
	context.out.Ln;
END HelloStream;


END HelloWorld2.

System.Free HelloWorld2 ~

HelloWorld2.HelloStream ~