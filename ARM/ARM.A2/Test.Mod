MODULE Test;

IMPORT Trace, Machine;

CONST
	Count = 1000;

TYPE
	Counter = OBJECT
	VAR
		i: LONGINT;

		PROCEDURE Inc;
		BEGIN {EXCLUSIVE}
			INC(i);
			Trace.String("Machine: "); Trace.Int(Machine.ID(), 0); Trace.Ln
		END Inc;

		PROCEDURE Report;
		BEGIN {EXCLUSIVE}
			Trace.String("Finished: ");
			Trace.Int(i, 0);
			Trace.String(" ");
			Trace.Int(Machine.ID(), 0);
			Trace.Ln
		END Report;
	END Counter;

	Thread = OBJECT
	VAR
		c: Counter;
		i, n: LONGINT;

		PROCEDURE & Init (counter: Counter; iterations: LONGINT);
		BEGIN
			c := counter;
			n := iterations
		END Init;

	BEGIN {ACTIVE}
		FOR i := 1 TO n DO
			c.Inc
		END;
		c.Report
	END Thread;

VAR
	c: Counter;
	t: Thread;

BEGIN
	NEW(c);
	NEW(t, c, Count);
	(*NEW(c);*)
	NEW(t, c, Count)
END Test.