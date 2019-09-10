(* Aos, Copyright 2001, Pieter Muller, ETH Zurich *)

MODULE Example8;	(* pjm *)

(* Semaphores for Aos. *)

TYPE
	Semaphore* = OBJECT
		VAR s: INTEGER;

		PROCEDURE V*;
		BEGIN {EXCLUSIVE} s := s+1 END V;

		PROCEDURE P*;
		BEGIN {EXCLUSIVE} AWAIT(s > 0); s := s-1 END P;

		PROCEDURE &Init*(s: SIGNED16);
		BEGIN SELF.s := s END Init;

	END Semaphore;

END Example8.
