MODULE EnetTiming;
(**
	AUTHOR: Alexey Morozov, HighDim GmbH, 2015
	PURPOSE: Ethernet networking stack, timing utilities
*)

IMPORT
	EnetEnvironment;
	
TYPE
	Time* = SIGNED64;

	(**
		Timer descriptor
	*)
	Timer* = RECORD
		startTime-: Time; (** starting time in timer counts *)
		interval-: Time; (** timer interval in timer counts *)
		expireTime-: Time; (** the time when timer will be expired *)
		isExpired-: BOOLEAN; (** TRUE if the timer is expired *)
	END;

VAR
	getTimeCounter*: PROCEDURE(): Time; (** pluggable time counter (forward counting direction) *)
	fromMicro*: PROCEDURE(us: Time): Time; (** plugable converter from microseconds to time counts *)
	fromMilli*: PROCEDURE(ms: Time): Time; (** plugable converter from milliseconds to time counts *)

	(**
		Set timer counting interval in microseconds
	*)
	PROCEDURE SetTimerMicro*(VAR timer: Timer; us: Time);
	BEGIN
		timer.interval := fromMicro(us);
		timer.isExpired := TRUE;
	END SetTimerMicro;

	(**
		Set timer counting interval in milliseconds
	*)
	PROCEDURE SetTimerMilli*(VAR timer: Timer; ms: Time);
	BEGIN
		timer.interval := fromMilli(ms);
		timer.isExpired := TRUE;
	END SetTimerMilli;

	(**
		Start a timer
	*)
	PROCEDURE StartTimer*(VAR timer: Timer);
	BEGIN
		timer.startTime := getTimeCounter();
		timer.expireTime := timer.startTime + timer.interval;
		timer.isExpired := FALSE;
	END StartTimer;

	(**
		Stop a timer
	*)
	PROCEDURE StopTimer*(VAR timer: Timer);
	BEGIN
		timer.isExpired := TRUE;
	END StopTimer;

	(** Returns TRUE if a given timer is expired *)
	PROCEDURE IsTimerExpired*(VAR timer: Timer): BOOLEAN;
	BEGIN
		IF ~timer.isExpired THEN
			timer.isExpired := getTimeCounter() - timer.expireTime >= 0;
			RETURN timer.isExpired;
		ELSE RETURN TRUE;
		END;
	END IsTimerExpired;

	(** Wait a specified number of microseconds *)
	PROCEDURE WaitMicro*(us: Time);
	VAR t: Time;
	BEGIN
		t := getTimeCounter() + fromMicro(us);
		WHILE getTimeCounter() - t < 0 DO END;
	END WaitMicro;

	(** Wait a specified number of milliseconds *)
	PROCEDURE WaitMilli*(ms: Time);
	VAR t: Time;
	BEGIN
		t := getTimeCounter() + fromMilli(ms);
		WHILE getTimeCounter() - t < 0 DO END;
	END WaitMilli;

BEGIN
	getTimeCounter := EnetEnvironment.GetTimeCounter;
	fromMicro := EnetEnvironment.FromMicro;
	fromMilli := EnetEnvironment.FromMilli;
END EnetTiming.
