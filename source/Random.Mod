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

	allbitsInv = 1 / FLOAT32(allbits);

TYPE
		(** A pseudo-random number generator.  This object is not reentrant. *)
	Generator* = OBJECT
		VAR
			buffer: ARRAY 250 OF SET32;
			index: SIGNED32;
			Z: SIGNED32;	(* seed for Rand() *)

		PROCEDURE Rand(): SIGNED32;
			(* for Init. Same as used by RandomNumbers *)
			CONST a = 16807; q = 127773; r = 2836;
			VAR t: SIGNED32;
		BEGIN
			t := a * (Z MOD q) - r * (Z DIV q);
			IF t > 0 THEN Z := t ELSE Z := t + max END;
			RETURN Z;
		END Rand;

		(** Set the seed. *)

		PROCEDURE InitSeed*(seed: SIGNED32);
			VAR
				k, i: SIGNED32;
				mask, msb: SIGNED32;
		BEGIN
			Z := seed; index := 0;
			FOR i := 0 TO 249 DO
				buffer[i] := SET32(Rand())
			END;
			FOR i := 0 TO 249 DO
				IF Rand() > halfrange THEN
					buffer[i] := buffer[i] + SET32(msbit);
				END;
			END;
			msb := msbit; mask := allbits;
			FOR i := 0 TO 30 DO
				k := step * i + 3;
				buffer[k] := buffer[k] * SET32(mask);
				buffer[k] := buffer[k] + SET32(msb);
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

		PROCEDURE Integer*(): SIGNED32;
			VAR newRand, j: SIGNED32;
		BEGIN
			IF index >= 147 THEN j := index - 147 ELSE j := index + 103 END;
			buffer[index] := buffer[index] / buffer[j];
			newRand := SYSTEM.VAL(SIGNED32, buffer[index]);
			IF index >= 249 THEN index := 0 ELSE INC(index) END;
			RETURN newRand
		END Integer;

		(** Return a pseudo-random number from 0..sides-1. *)

		PROCEDURE Dice*(sides: SIGNED32): SIGNED32;
		BEGIN
			RETURN Integer() MOD sides;
		END Dice;

		(** Return a pseudo-random real number, uniformly distributed. *)

		PROCEDURE Uniform*(): FLOAT32;
		BEGIN
			RETURN Integer() * allbitsInv;
		END Uniform;

		(** Return a pseudo-random real number, exponentially distributed. *)

		PROCEDURE Exp*(mu: FLOAT32): FLOAT32;
		BEGIN
			RETURN -Math.ln(Uniform())/mu
		END Exp;

		PROCEDURE Gaussian*(): FLOAT32; (*generates a normal distribution with mean 0, variance 1 using the Box-Muller Transform*)
		VAR
			x1,x2,w,y1: FLOAT32;
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

		PROCEDURE InitSeed*(seed: SIGNED32);
		BEGIN {EXCLUSIVE}
			r.InitSeed(seed)
		END InitSeed;

		PROCEDURE &Init*;
		BEGIN
			NEW(r)
		END Init;

		PROCEDURE Integer*(): SIGNED32;
		BEGIN {EXCLUSIVE}
			RETURN r.Integer()
		END Integer;

		PROCEDURE Dice*(sides: SIGNED32): SIGNED32;
		BEGIN {EXCLUSIVE}
			RETURN r.Dice(sides)
		END Dice;

		PROCEDURE Uniform*(): FLOAT32;
		BEGIN {EXCLUSIVE}
			RETURN r.Uniform()
		END Uniform;

		PROCEDURE Exp*(mu: FLOAT32): FLOAT32;
		BEGIN {EXCLUSIVE}
			RETURN r.Exp(mu)
		END Exp;

		PROCEDURE Gaussian*(): FLOAT32; (*generates a normal distribution with mean 0, variance 1 using the Box-Muller Transform*)
		BEGIN{EXCLUSIVE}
			RETURN r.Gaussian();
		END Gaussian;


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
