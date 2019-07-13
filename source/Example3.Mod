(* Aos, Copyright 2001, Pieter Muller, ETH Zurich *)

MODULE Example3;	(* pjm *)

(*
Alarm clock.
Ref: C.A.R. Hoare, "Monitors: An Operating System Structuring Concept", CACM 17(10), 1974
*)

TYPE
	Clock* = OBJECT
		VAR now: SIZE;

		PROCEDURE Delay*(n: SIZE);
		VAR then: SIZE;
		BEGIN {EXCLUSIVE}
			then := now + n;
			AWAIT(then - now >= 0)
		END Delay;

		PROCEDURE Tick*;
		BEGIN {EXCLUSIVE}
			INC(now)
		END Tick;

		PROCEDURE &Init*;
		BEGIN
			now := 0
		END Init;

	END Clock;

END Example3.
