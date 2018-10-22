(* Aos, Copyright 2001, Pieter Muller, ETH Zurich *)

MODULE Beep;   (** AUTHOR "pjm"; PURPOSE "PC speaker driver"; *)

IMPORT Kernel32, Kernel(* , KernelLog*) ;

CONST

	(** Sound the PC speaker continuously at the specified frequency.  Use 0 to switch off the sound.  Not sharable. *)
TYPE
	Beeper = OBJECT
	VAR hz: WORD;
		beep: BOOLEAN;

		PROCEDURE & Init*;
		BEGIN
			(*KernelLog.String("Beep:Beeper.Init"); KernelLog.Ln;*)
			beep := FALSE;
		END Init;

		PROCEDURE On( hz: WORD );
		BEGIN {EXCLUSIVE}
			SELF.hz := hz;  beep := TRUE;
		END On;

		PROCEDURE Off;
		BEGIN {EXCLUSIVE}
			beep := FALSE;
		END Off;

		PROCEDURE Beep;
		VAR retBOOL: Kernel32.BOOL;								(* Dan 09.11.05 *)
		BEGIN
			(*KernelLog.String("Beeper.Beep"); KernelLog.Ln;  *)
			LOOP
				WHILE (beep) DO  retBOOL :=Kernel32.Beep( hz, 50 );  END;
				BEGIN {EXCLUSIVE}
					AWAIT( beep );
				END;
			END;
		END Beep;

	BEGIN {ACTIVE}
					(*KernelLog.String("Beep:Beeper.Active"); KernelLog.Ln; *)  Beep();
	END Beeper;

VAR
	beep: Beeper;

	PROCEDURE Beep*( hz: WORD );
	VAR s: SET;
	BEGIN
		IF (hz # 0) THEN
			IF beep = NIL THEN NEW( beep ) END;
			beep.On( hz )
		ELSE
			IF beep # NIL THEN beep.Off();  END;
		END;
	END Beep;

	PROCEDURE Test*;
	VAR timer: Kernel.Timer;
	BEGIN
		NEW(timer);
		Beep( 2000 ); timer.Sleep(1000); Beep(0);
	END Test;

	PROCEDURE TestOn*;
	BEGIN
		Beep( 2000 );
	END TestOn;

	PROCEDURE TestOff*;
	BEGIN
		Beep( 0 );
	END TestOff;

END Beep.

System.Free Beep ~

Beep.TimerTest
Beep.Test
Beep.TestOn
Beep.TestOff
~


