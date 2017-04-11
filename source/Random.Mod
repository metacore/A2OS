(* Aos, Copyright 2001, Pieter Muller, ETH Zurich *)

MODULE Random; (** AUTHOR "ecarter/bsm/pjm"; PURPOSE "Pseudo-random number generator"; *)

(* Based on the ADA version by Everett F. Carter Jr., ported to Aos by Ben Smith-Mannschott. *)

IMPORT SYSTEM, Math;

CONST
	max       = 2147483647;
	msbit     = 40000000H;
	allbits   = 7FFFFFFFH;
	halfrange = 20000000H;
	step      = 7;

TYPE
		(** A pseudo-random number generator.  This object is not reentrant. *)
	Generator* = OBJECT
		VAR
			buffer: ARRAY 250 OF SET;
			index: LONGINT;
			Z: LONGINT;	(* seed for Rand() *)

		PROCEDURE Rand(): LONGINT;
			(* for Init. Same as used by RandomNumbers *)
			CONST a = 16807; q = 127773; r = 2836;
			VAR t: LONGINT;
		BEGIN
			t := a * (Z MOD q) - r * (Z DIV q);
			IF t > 0 THEN Z := t ELSE Z := t + max END;
			RETURN Z;
		END Rand;

		(** Set the seed. *)

		PROCEDURE InitSeed*(seed: LONGINT);
			VAR
				k, i: LONGINT;
				mask, msb: LONGINT;
		BEGIN
			Z := seed; index := 0;
			FOR i := 0 TO 249 DO
				buffer[i] := SYSTEM.VAL(SET, Rand())
			END;
			FOR i := 0 TO 249 DO
				IF Rand() > halfrange THEN
					buffer[i] := buffer[i] + SYSTEM.VAL(SET,msbit);
				END;
			END;
			msb := msbit; mask := allbits;
			FOR i := 0 TO 30 DO
				k := step * i + 3;
				buffer[k] := buffer[k] * SYSTEM.VAL(SET,mask);
				buffer[k] := buffer[k] + SYSTEM.VAL(SET, msb);
				msb := msb DIV 2;
				mask := mask DIV 2;
			END;
		END InitSeed;

		(** The default seed is 1. *)
		PROCEDURE & Init*;
		BEGIN
			InitSeed(1)
		END Init;

		(** Return a pseudo-random 32-bit integer. *)

		PROCEDURE Integer*(): LONGINT;
			VAR newRand, j: LONGINT;
		BEGIN
			IF index >= 147 THEN j := index - 147 ELSE j := index + 103 END;
			buffer[index] := buffer[index] / buffer[j];
			newRand := SYSTEM.VAL(LONGINT, buffer[index]);
			IF index >= 249 THEN index := 0 ELSE INC(index) END;
			RETURN newRand
		END Integer;

		(** Return a pseudo-random number from 0..sides-1. *)

		PROCEDURE Dice*(sides: LONGINT): LONGINT;
		BEGIN
			RETURN Integer() MOD sides;
		END Dice;

		(** Return a pseudo-random real number, uniformly distributed. *)

		PROCEDURE Uniform*(): REAL;
		BEGIN
			RETURN Integer() / allbits;
		END Uniform;

		(** Return a pseudo-random real number, exponentially distributed. *)

		PROCEDURE Exp*(mu: REAL): REAL;
		BEGIN
			RETURN -Math.ln(Uniform())/mu
		END Exp;
		
		PROCEDURE Gaussian*(): REAL; (*generates a normal distribution with mean 0, variance 1 using the Box-Muller Transform*)
		VAR
			x1,x2,w,y1,y2: REAL;
		BEGIN
			REPEAT
				x1:=2.0*Uniform()-1;
				x2:=2.0*Uniform()-1;
				w:=x1*x1+x2*x2;
			UNTIL w<1;
			w:=Math.sqrt( (-2.0* Math.ln(w) ) /w);
			y1:=x1*w;
			(*y2:=x2*w*)
			RETURN y1;
		END Gaussian;

	END Generator;

TYPE
		(** This is a protected wrapper for the Generator object.  It synchronizes concurrent calls and is therefore slower. *)
	Sequence* = OBJECT
		VAR r: Generator;

		PROCEDURE InitSeed*(seed: LONGINT);
		BEGIN {EXCLUSIVE}
			r.InitSeed(seed)
		END InitSeed;

		PROCEDURE &Init*;
		BEGIN
			NEW(r)
		END Init;

		PROCEDURE Integer*(): LONGINT;
		BEGIN {EXCLUSIVE}
			RETURN r.Integer()
		END Integer;

		PROCEDURE Dice*(sides: LONGINT): LONGINT;
		BEGIN {EXCLUSIVE}
			RETURN r.Dice(sides)
		END Dice;

		PROCEDURE Uniform*(): REAL;
		BEGIN {EXCLUSIVE}
			RETURN r.Uniform()
		END Uniform;

		PROCEDURE Exp*(mu: REAL): REAL;
		BEGIN {EXCLUSIVE}
			RETURN r.Exp(mu)
		END Exp;

	END Sequence;

END Random.

(*
   from the ADA version:
   (c) Copyright 1997 Everett F. Carter Jr.   Permission is
   granted by the author to use this software for any
   application provided this copyright notice is preserved.

   The algorithm was originally described by
   Kirkpatrick, S., and E. Stoll, 1981;
       A Very Fast Shift-Register Sequence Random Number Generator,
       Journal of Computational Physics, V. 40. pp. 517-526

   Performance:

   Its period is 2^249. This implementation is about 25% faster than
   RandomNumbers.Uniform().  It also offers direct generation of
   integers which is even faster (2x on PowerPC) and especially
   good for FPU-challenged machines like the Shark NCs.
 *)
