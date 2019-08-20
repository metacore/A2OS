(* Aos, Copyright 2001, Pieter Muller, ETH Zurich *)

MODULE Example2;	(* pjm *)

(*
Bounded buffer.
Ref: C.A.R. Hoare, "Monitors: An Operating System Structuring Concept", CACM 17(10), 1974
*)

TYPE
	Item* = OBJECT END Item;

	Buffer* = OBJECT
		VAR head, num: SIZE; buffer: POINTER TO ARRAY OF Item;

		PROCEDURE Append*(x: Item);
		BEGIN {EXCLUSIVE}
			AWAIT(num # LEN(buffer));
			buffer[(head+num) MOD LEN(buffer)] := x;
			INC(num)
		END Append;

		PROCEDURE Remove*(): Item;
		VAR x: Item;
		BEGIN {EXCLUSIVE}
			AWAIT(num # 0);
			x := buffer[head];
			head := (head+1) MOD LEN(buffer);
			DEC(num);
			RETURN x
		END Remove;

		PROCEDURE &Init*(n: SIZE);
		BEGIN
			head := 0; num := 0; NEW(buffer, n)
		END Init;

	END Buffer;

END Example2.
