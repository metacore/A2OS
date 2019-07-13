(* Aos, Copyright 2001, Pieter Muller, ETH Zurich *)

MODULE Example6;	(* pjm *)

(*
Readers and Writers scheduler.
Ref: C.A.R. Hoare, "Monitors: An Operating System Structuring Concept", CACM 17(10), 1974
*)

TYPE
	ReadersWritersScheduler* = OBJECT
		VAR busy: BOOLEAN; readers, writers: SIZE;

		PROCEDURE StartRead*;
		BEGIN {EXCLUSIVE}
			AWAIT(~busy & (writers = 0));	(* waiting writers have priority over readers *)
			INC(readers)
		END StartRead;

		PROCEDURE EndRead*;
		BEGIN {EXCLUSIVE}
			DEC(readers)
		END EndRead;

		PROCEDURE StartWrite*;
		BEGIN {EXCLUSIVE}
			INC(writers);
			AWAIT(~busy & (readers = 0));
			busy := TRUE
		END StartWrite;

		PROCEDURE EndWrite*;
		BEGIN {EXCLUSIVE}
			DEC(writers); busy := FALSE
		END EndWrite;

		PROCEDURE &Init*;
		BEGIN
			busy := FALSE; readers := 0; writers := 0
		END Init;

	END ReadersWritersScheduler;

END Example6.
