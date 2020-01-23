MODULE GenericsUse; (** AUTHOR ""; PURPOSE ""; *)

IMPORT
	Commands, SIZE_Containers := G(SIZE, L);
	
PROCEDURE TestQueue(context: Commands.Context);
VAR
	queue: SIZE_Containers.Queue;
	i: SIZE;
BEGIN
	NEW(queue);
	FOR i := 0 TO 63 DO queue.Push(i) END;
	context.out.String("Popping sequentally added natural numbers from Queue (LIFO stack):"); context.out.Ln;
	WHILE queue.Pop(i) DO
		context.out.Int(i, 0); context.out.Char(20X)
	END;
	context.out.Ln
END TestQueue;

PROCEDURE TestDEQue(context: Commands.Context);
VAR
	deque: SIZE_Containers.DEQue;
	i: SIZE;
BEGIN
	NEW(deque);
	FOR i := 0 TO 63 DO deque.Push(i) END;
	context.out.String("Popping sequentally added natural numbers from DEQue (FIFO stack):"); context.out.Ln;
	WHILE deque.Pop(i) DO
		context.out.Int(i, 0); context.out.Char(20X)
	END;
	context.out.Ln
END TestDEQue;

PROCEDURE TestVector(context: Commands.Context);
VAR
	vector: SIZE_Containers.Vector;
	i, value: SIZE;
BEGIN
	NEW(vector);
	FOR i := 0 TO 63 DO IGNORE vector.Add(i) END;
	context.out.String("List sequentally added natural numbers from Vector:"); context.out.Ln;
	FOR i := 0 TO vector.Count() - 1 DO
		vector.Get(i, value);
		context.out.Int(value, 0); context.out.Char(20X)
	END;
	context.out.Ln;
	context.out.String("Index of 15 in Vector: "); context.out.Int(vector.IndexOf(15), 0); context.out.Ln;
	context.out.String("Index of 32 in Vector: "); context.out.Int(vector.IndexOf(32), 0); context.out.Ln;
END TestVector;

PROCEDURE Do*(context: Commands.Context);
BEGIN
	TestQueue(context);
	TestDEQue(context);
	TestVector(context)
END Do;

PROCEDURE L(l, r: SIZE): BOOLEAN;
BEGIN
	RETURN l < r
END L;

BEGIN

END GenericsUse.

GenericsUse.Do ~
System.Free GenericsUse ~