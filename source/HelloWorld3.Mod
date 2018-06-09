MODULE HelloWorld3;

IMPORT
	WMDialogs;

PROCEDURE Hello*;
VAR name : ARRAY 32 OF CHAR;
BEGIN
	IF WMDialogs.QueryString("What is your name ?", name) = WMDialogs.ResOk THEN
		WMDialogs.Information("Hello", name);
	ELSE
		WMDialogs.Information("Arrgh", "You need to press Ok otherwise it is aborted");
	END;
END Hello;


END HelloWorld3.

System.Free HelloWorld2 ~

HelloWorld3.Hello ~