(* Aos, Copyright 2001, Pieter Muller, ETH Zurich *)

MODULE Example8;	(* pjm *)

(* Semaphores for Aos. *)

TYPE
	Semaphore* = OBJECT
		VAR s: WORD;

		PROCEDURE V*;
		BEGIN {EXCLUSIVE} s := s+1 END V;

		PROCEDURE P*;
		BEGIN {EXCLUSIVE} AWAIT(s > 0); s := s-1 END P;

		PROCEDURE &Init*(s: INTEGER);
		BEGIN SELF.s := s END Init;

	END Semaphore;

END Example8.
