(* Aos, Copyright 2001, Pieter Muller, ETH Zurich *)

MODULE Example5;	(* pjm *)

(*
Disk head scheduler.
Ref: C.A.R. Hoare, "Monitors: An Operating System Structuring Concept", CACM 17(10), 1974
*)

TYPE
	Entry = OBJECT
		VAR
			next: Entry;
			priority: WORD;
			turn: BOOLEAN;
	END Entry;

	PriorityScheduler = OBJECT
		VAR root: Entry;

		PROCEDURE Wait(priority: LONGINT);
		VAR n, p: Entry;
		BEGIN {EXCLUSIVE}
			p := NIL; n := root;
			WHILE (n # NIL) & (priority > n.priority) DO p := n; n := n.next END;
			NEW(n); n.priority := priority; n.turn := FALSE;
			IF p = NIL THEN n.next := root; root := n
			ELSE n.next := p.next; p.next := n
			END;
			AWAIT(n.turn)
		END Wait;

		PROCEDURE Signal;
		BEGIN {EXCLUSIVE}
			IF root # NIL THEN
				root.turn := TRUE; root := root.next
			END
		END Signal;

		PROCEDURE Waiting(): BOOLEAN;
		BEGIN {EXCLUSIVE}
			RETURN root # NIL
		END Waiting;

		PROCEDURE &Init*;
		BEGIN
			root := NIL
		END Init;

	END PriorityScheduler;

	DiskScheduler* = OBJECT
		VAR
			busy, up: BOOLEAN; pos: LONGINT;
			upsweep, downsweep: PriorityScheduler;

		PROCEDURE Request*(dest: LONGINT);
		BEGIN {EXCLUSIVE}
			IF busy THEN
				IF (pos < dest) OR (pos = dest) & up THEN
					upsweep.Wait(dest)
				ELSE
					downsweep.Wait(MAX(LONGINT)-dest)
				END
			END;
			busy := TRUE; pos := dest
		END Request;

		PROCEDURE Release*;
		BEGIN {EXCLUSIVE}
			busy := FALSE;
			IF up THEN
				IF upsweep.Waiting() THEN upsweep.Signal
				ELSE up := FALSE; downsweep.Signal
				END
			ELSE
				IF downsweep.Waiting() THEN downsweep.Signal
				ELSE up := TRUE; upsweep.Signal
				END
			END
		END Release;

		PROCEDURE &Init*;
		BEGIN
			busy := FALSE; up := TRUE; pos := 0;
			NEW(upsweep); NEW(downsweep)
		END Init;

	END DiskScheduler;

END Example5.
