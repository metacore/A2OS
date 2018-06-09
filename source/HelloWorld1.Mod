MODULE HelloWorld1;

IMPORT
	KernelLog;

PROCEDURE Do*;
BEGIN
	KernelLog.String("Hello World"); KernelLog.Ln;
END Do;


END HelloWorld1.

System.Free HelloWorld1 ~

HelloWorld1.Do ~