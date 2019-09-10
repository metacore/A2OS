(* Aos, Copyright 2001, Pieter Muller, ETH Zurich *)

MODULE JavaLocks;	(* pjm *)

(*
Java-like locks for Aos.
The timeout case is very ugly, because handling external events is currently difficult.
Ref: The Java Language Specification, section 17.13-17.14
*)

IMPORT Objects;

TYPE
	JavaLock* = OBJECT
		VAR
			depth, in, out: SIGNED32;
			locker: ANY;

		PROCEDURE Lock*;
		VAR me: ANY;
		BEGIN {EXCLUSIVE}
			me := Objects.ActiveObject();
			AWAIT((locker = NIL) OR (locker = me));
			INC(depth);
			locker := me
		END Lock;

		PROCEDURE Unlock*;
		BEGIN {EXCLUSIVE}
			ASSERT(locker = Objects.ActiveObject());
			DEC(depth);
			IF depth = 0 THEN locker := NIL END
		END Unlock;

		PROCEDURE Wait*;
		VAR ticket, mydepth: SIGNED32; me: ANY;
		BEGIN {EXCLUSIVE}
			me := Objects.ActiveObject();
			ASSERT(locker = me);
			mydepth := depth; depth := 0; locker := NIL;
			ticket := in; INC(in);
			AWAIT((ticket - out < 0) & (locker = NIL));
			depth := mydepth; locker := me
		END Wait;

		PROCEDURE WaitTime*(ms: SIGNED32);
		VAR ticket, mydepth: SIGNED32; me: ANY; sleeper: Sleeper;
		BEGIN {EXCLUSIVE}
			me := Objects.ActiveObject();
			ASSERT(locker = me);
			mydepth := depth; depth := 0; locker := NIL;
			ticket := in; INC(in);
			NEW(sleeper, SELF, ms);	(* allocate a sleeper for the current thread *)
			AWAIT((sleeper.done OR (ticket - out < 0)) & (locker = NIL));
			sleeper.Stop;
			depth := mydepth; locker := me
		END WaitTime;

		PROCEDURE Notify*;
		BEGIN {EXCLUSIVE}
			ASSERT(locker = Objects.ActiveObject());
			IF out # in THEN INC(out) END
		END Notify;

		PROCEDURE NotifyAll*;
		BEGIN {EXCLUSIVE}
			ASSERT(locker = Objects.ActiveObject());
			out := in
		END NotifyAll;

		PROCEDURE Wakeup;
		BEGIN {EXCLUSIVE}
		END Wakeup;

		PROCEDURE &Init*;
		BEGIN
			depth := 0; locker := NIL; in := 0; out := 0
		END Init;

	END JavaLock;

TYPE
	Sleeper = OBJECT 	(* to do: simplify this *)
		VAR lock: JavaLock; done: BOOLEAN; timer: Objects.Timer;

		PROCEDURE HandleTimeout;
		BEGIN {EXCLUSIVE}
			IF lock # NIL THEN done := TRUE; lock.Wakeup END
		END HandleTimeout;

		PROCEDURE Stop;
		BEGIN {EXCLUSIVE}
			lock := NIL; Objects.CancelTimeout(timer)
		END Stop;

		PROCEDURE &Start*(lock: JavaLock; ms: SIGNED32);
		BEGIN
			NEW(timer);
			SELF.lock := lock; done := FALSE;
			Objects.SetTimeout(timer, SELF.HandleTimeout, ms)
		END Start;

	END Sleeper;

END JavaLocks.
