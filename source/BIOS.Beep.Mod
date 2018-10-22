(* Aos, Copyright 2001, Pieter Muller, ETH Zurich *)

MODULE Beep; (** AUTHOR "pjm"; PURPOSE "PC speaker driver"; *)

IMPORT SYSTEM,Machine;

CONST
	Rate = 1193180;	(* timer clock is 1.19318 MHz *)

(** Sound the PC speaker continuously at the specified frequency.  Use 0 to switch off the sound.  Not sharable. *)

PROCEDURE Beep*(hz: WORD);
VAR s: SET;
BEGIN {EXCLUSIVE}
		(* stop counter *)
	Machine.Portin8(61H, SYSTEM.VAL(CHAR, s));
	Machine.Portout8(61H, CHR(SYSTEM.VAL(WORD, s - {0,1})));
	IF hz > 0 THEN
		hz := Rate DIV hz;
			(* init counter for hz *)
		Machine.Portout8(43H, 0B6X);	(* timer 2, 16-bit, mode 3, binary *)
		Machine.Portout8(42H, CHR(hz MOD 100H));
		Machine.Portout8(42H, CHR(hz DIV 100H));
			(* start counter *)
		Machine.Portin8(61H, SYSTEM.VAL(CHAR, s));
		Machine.Portout8(61H, SYSTEM.VAL(CHAR, s + {0,1}))
	END
END Beep;

END Beep.
