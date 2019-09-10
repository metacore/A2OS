(**
	AUTHOR: Alexey Morozov, HighDim GmbH, 2018
	PURPOSE: A2 clock with a plugable RTC get/set interface
*)

(* Aos, Copyright 2001, Pieter Muller, ETH Zurich *)

MODULE Clock;

TYPE

	(*
		Function for getting time from an RTC device

		second: seconds \in [0,59]
		minute: minutes \in [0,59]
		hour: hours \in [0,23]
		day: days \in [1,31]
		month: months \in [1,12]
		year: the actual year minus 1900
	*)
	GetRtcTimeFunc = PROCEDURE{DELEGATE}(VAR second, minute, hour, day, month: SIGNED8; VAR year: SIGNED16): BOOLEAN;

	(*
		Function for setting up time on an RTC device

		second: seconds \in [0,59]
		minute: minutes \in [0,59]
		hour: hours \in [0,23]
		day: days \in [1,31]
		month: months \in [1,12]
		year: the actual year minus 1900
	*)
	SetRtcTimeFunc =PROCEDURE{DELEGATE}(second, minute, hour, day, month: SIGNED8; year: SIGNED16): BOOLEAN;

VAR
	getRtcTime: GetRtcTimeFunc;
	setRtcTime: SetRtcTimeFunc;

	tz*: SIGNED32;	(** system time zone offset in minutes (from -720 to 720) *)
	starttime*, startdate*: SIGNED32;	(** time this module was loaded (usually boot time) *)

(** Return the current time and date in Oberon format. *)

PROCEDURE Get*(VAR time, date: SIGNED32);
VAR
	second, minute, hour, day, month: SIGNED8;
	year: SIGNED16;
BEGIN{EXCLUSIVE}
	IF getRtcTime # NIL THEN
		IF getRtcTime(second, minute, hour, day, month, year) THEN
			time := SIGNED32(hour)*4096 + SIGNED32(minute)*64 + second;
			date := SIGNED32(year)*512 + SIGNED32(month)*32 + day;
			RETURN;
		END;
	END;
	time := 0;
	date := 0;
END Get;

(** Set the current time and date in Oberon format. *)

PROCEDURE Set*(time, date: SIGNED32);
VAR
	second, minute, hour, day, month: SIGNED8;
	year: SIGNED16;
BEGIN{EXCLUSIVE}
	IF setRtcTime # NIL THEN
		second := SIGNED8(time MOD 64);
		minute := SIGNED8(time DIV 64 MOD 64);
		hour := SIGNED8(time DIV 4096 MOD 32);
		day := SIGNED8(date MOD 32);
		month := SIGNED8(date DIV 32 MOD 16);
		year := SIGNED16(date DIV 512);
		IF setRtcTime(second, minute, hour, day, month, year) THEN
		END;
	END;
END Set;

PROCEDURE Install*(get: GetRtcTimeFunc; set: SetRtcTimeFunc);
BEGIN
	BEGIN{EXCLUSIVE}
		getRtcTime := get;
		setRtcTime := set;
	END;
	Get(starttime, startdate);
END Install;

BEGIN
	tz := 2*60;	(* fixme: configurable *)
END Clock.

(*
23.08.1999	pjm	Split from Aos.Kernel
*)

(**
Notes

The time and date are that of the real-time clock of the system, which may be set to universal time, or to some local time zone.

The tz variable indicates the system time zone offset from universal time in minutes.  It may be updated at any time due to daylight savings time.  E.g. MET DST is 2 * 60 = 120.

The time and date are each represented in an encoded SIGNED32.

Converting from year, month, day, hour, minute, second to time, date:
	time := hour*4096 + minute*64 + second;
	date := (year-1900)*512 + month*32 + day;

Converting from time to hour, minute, second:
	hour := time DIV 4096 MOD 32;
	minute := time DIV 64 MOD 64;
	second := time MOD 64;

Converting from date to year, month, day:
	year = 1900+date DIV 512;
	month = date DIV 32 MOD 16;
	day = date MOD 32;

All years in the current millenium can be represented.  The 1900 offset is a historical artefact from the Oberon system.

Time and date values (respectively) can be compared with the normal Oberon operators <, <=, =, >=, >, #.  Overflow at midnight has to be handled separately.
*)
