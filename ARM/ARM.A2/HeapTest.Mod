MODULE HeapTest;
	IMPORT Machine, Commands;

	PROCEDURE Alloc *;
	VAR
		dummy: POINTER TO ARRAY OF CHAR;
	BEGIN
		NEW(dummy, 1024)
	END Alloc;

	PROCEDURE Free * (context: Commands.Context);
	VAR
		total, low, high: SIGNED32;
	BEGIN
		Machine.GetFreeK(total, low, high);
		context.out.String("Free memory:");
		context.out.Ln;
		context.out.String("	total:	"); context.out.Int(total, 0); context.out.String(" kB"); context.out.Ln;
		context.out.String("	low:	"); context.out.Int(low, 0); context.out.String(" kB"); context.out.Ln;
		context.out.String("	high:	"); context.out.Int(high, 0); context.out.String(" kB"); context.out.Ln;
		context.out.Update
	END Free;
END HeapTest.