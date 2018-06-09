MODULE WMPerfMonAlertsUtils; (** AUTHOR "staubesv"; PURPOSE "Alert signaling"; *)
(**
 * History:
 *
 *	07.03.2007	First release (staubesv)
 *)

IMPORT
	Modules, Kernel, Commands, Beep;

CONST

	None* = 0;
	Information* = 1;
	Error* = 2;
	Critical* = 3;

	(* Beeper states *)
	Waiting = 0;
	SignalInformation = 1;
	SignalError = 2;
	SignalCritical = 3;
	Terminating = 8;
	Terminated = 9;

	FrequencyInformation = 1000;
	FrequencyError = 2000;
	FrequencyCritical = 3000;

	IntervalInformation = 10000;
	IntervalError = 5000;
	IntervalCritical = 500;

TYPE

	Beeper = OBJECT
	VAR
		state : LONGINT;
		hz, intervall : LONGINT;
		timer : Kernel.Timer;

		PROCEDURE Signal(type : LONGINT);
		BEGIN {EXCLUSIVE}
			IF type = None THEN
				state := Waiting;
			ELSE
				IF type > state THEN state := type; END;
			END;
			CASE state OF
				|SignalInformation: hz := FrequencyInformation; intervall := IntervalInformation;
				|SignalError: hz := FrequencyError; intervall := IntervalError;
				|SignalCritical: hz := FrequencyCritical; intervall := IntervalCritical;
			ELSE
				hz := 0;
			END;
			timer.Wakeup;
		END Signal;

		PROCEDURE Stop;
		BEGIN
			Beep.Beep(0);
			BEGIN {EXCLUSIVE} state := Terminating; END;
			timer.Wakeup; timer.Wakeup;
			BEGIN {EXCLUSIVE} AWAIT(state = Terminated); END;
		END Stop;

		PROCEDURE &Init*;
		BEGIN
			state := Waiting;
			NEW(timer);
		END Init;

	BEGIN {ACTIVE}
		WHILE state # Terminating DO
			BEGIN {EXCLUSIVE} AWAIT(state # Waiting); END;
			IF state # Terminating THEN
				Beep.Beep(hz);
				timer.Sleep(intervall DIV 2);
				Beep.Beep(0);
				IF state # Terminating THEN timer.Sleep(intervall DIV 2); END;
			END;
		END;
		BEGIN {EXCLUSIVE} state := Terminated; END;
	END Beeper;

VAR
	beeper : Beeper;

PROCEDURE Signal*(type : LONGINT);
BEGIN {EXCLUSIVE}
	IF beeper = NIL THEN NEW(beeper); END;
	beeper.Signal(type);
END Signal;

PROCEDURE SignalCmd*(context : Commands.Context);
VAR nbr : LONGINT;
BEGIN
	IF context.arg.GetInteger(nbr, FALSE) THEN
		Signal(nbr);
	ELSE
		context.result := Commands.CommandParseError;
	END;
END SignalCmd;

PROCEDURE Cleanup;
BEGIN
	IF beeper # NIL THEN beeper.Stop; beeper := NIL; END;
END Cleanup;

BEGIN
	Modules.InstallTermHandler(Cleanup);
END WMPerfMonAlertsUtils.

WMPerfMonAlertsUtils.SignalCmd 0 ~	System.Free WMPerfMonAlertsUtils ~
WMPerfMonAlertsUtils.SignalCmd 1 ~
WMPerfMonAlertsUtils.SignalCmd 2 ~
WMPerfMonAlertsUtils.SignalCmd 3 ~
