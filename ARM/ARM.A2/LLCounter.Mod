(** Simple test module for low-level locks *)
MODULE LLCounter;

IMPORT SYSTEM, Machine, Objects, Trace;

CONST
	Count = 4000000;

TYPE
	Writer = OBJECT
	VAR
		c: SIGNED32;
	BEGIN {ACTIVE}
		FOR c := 1 TO Count DO
			Increment
		END;
		Lock;
		Trace.String("Writer "); Trace.Address(SYSTEM.VAL(ADDRESS, SELF)); Trace.String(" finished. i = "); Trace.Int(i, 0);
		Trace.String(". c = "); Trace.Int(c, 0); Trace.Ln;
		Unlock
	END Writer;

	Reader = OBJECT
	BEGIN {ACTIVE}
		LOOP Read END
	END Reader;

	Printer = OBJECT
	VAR
		id, count: SIGNED32;

		PROCEDURE & Init(i: SIGNED32);
		BEGIN
			id := i
		END Init;

		PROCEDURE Print;
		BEGIN
			Lock;
			Trace.String("Printer: Inside a critical section. id = "); Trace.Int(id, 0); Trace.Ln;
			Unlock
		END Print;

	BEGIN {ACTIVE}
		(*FOR count := 0 TO 1000 DO*)
		LOOP
			Print
		END
	END Printer;

	IndependentWriter = OBJECT
	VAR
		i, c, id: SIGNED32;
		lock: BOOLEAN;
		padding: ARRAY 30 OF CHAR;

		PROCEDURE & Init(id: SIGNED32);
		BEGIN
			SELF.id := id
		END Init;

	BEGIN {ACTIVE}
		(*LOOP*)
		(*FOR c := 1 TO Count DO*)
		WHILE i < Count DO
			(*Lock;*)
			(*Machine.AcquireSpin(lock);*)
			INC(i);
			(*Machine.ReleaseSpin(lock)*)
			(*Unlock*)
			Test(ADDRESSOF(Bad), 0);
			Test(ADDRESSOF(Bad), 0)
		END;
		(*Lock;*)
		Trace.Int(id, 0); Trace.String(". i = "); Trace.Int(i, 0); Trace.Ln;
		(*Unlock*)
	END IndependentWriter;

	IndependentWriter2 = OBJECT
	VAR
		i, c, id, d: SIGNED32;
		lock: BOOLEAN;
		padding: ARRAY 30 OF CHAR;

		PROCEDURE & Init(id: SIGNED32);
		BEGIN
			SELF.id := id
		END Init;

	BEGIN {ACTIVE}
		FOR c := 1 TO Count DIV 10 DO
			FOR d := 1 TO 10 DO
				Lock;
				(*Machine.AcquireSpin(lock);*)
				INC(i);
				(*Machine.ReleaseSpin(lock)*)
				Unlock
			END;
			Objects.Yield
		END;
		(*Lock;*)
		Trace.Int(id, 0); Trace.String(". i = "); Trace.Int(i, 0); Trace.Ln;
		(*Unlock*)
	END IndependentWriter2;

	Buffer = ARRAY 1024 * 1024 OF CHAR;

VAR
	i: SIGNED32;
	lock: RECORD
		padding: ARRAY 31 OF CHAR;
		lock: BOOLEAN;
	END;
	w1, w2, w3, w4: Writer;
	r: Reader;
	p1, p2, p3, p4: Printer;
	iw1, iw2: IndependentWriter;
	iw21, iw22: IndependentWriter2;

	PROCEDURE Lock;
	BEGIN
		Machine.DisableInterrupts;
		(*Machine.AcquireSpin(lock.lock);*)
		(*Machine.Acquire(Machine.KernelLog)*)
	END Lock;
	
	PROCEDURE Unlock;
	BEGIN
		(*Machine.Release(Machine.KernelLog);*)
		(*Machine.ReleaseSpin(lock.lock);*)
		Machine.EnableInterrupts
	END Unlock;

	PROCEDURE Test(a, b: ADDRESS);
	BEGIN
		Test2(a, b)
	END Test;

	PROCEDURE Test2(a, b: ADDRESS);
	END Test2;

	PROCEDURE Bad;
		VAR
			bp, sp: ADDRESS;
	BEGIN
		Machine.DisableInterrupts;
		Trace.StringLn("BAD BOY");
		LOOP END
	END Bad;

	PROCEDURE Increment;
	VAR j: SIGNED32;
	BEGIN
		Lock;
		INC(i);
		Unlock
		(*; FOR j := 0 TO 10000 DO END*)
	END Increment;

	PROCEDURE Read;
	BEGIN
		Lock;
		Trace.String("i: "); Trace.Int(i, 0); Trace.Ln;
		Unlock
	END Read;

BEGIN
	Trace.StringLn("=== Begin Test ===");
	NEW(w1);
	NEW(w2);
	(*NEW(w3);
	NEW(w4);
	NEW(w1);
	NEW(w2);
	NEW(w3);
	NEW(w4);*)
	(*NEW(r);*)
	(*NEW(p1, 1);
	NEW(p2, 2);
	NEW(p3, 3);
	NEW(p4, 4);*)
	(*NEW(iw1, 1);
	NEW(iw2, 2)*)
	(*NEW(iw21, 1);
	NEW(iw22, 2)*)
END LLCounter.
