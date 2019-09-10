(* Aos, Copyright 2001, Pieter Muller, ETH Zurich *)

MODULE Clock;   (** AUTHOR "pjm"; PURPOSE "Real-time clock driver"; *)

IMPORT Unix;

VAR
	tz*: SIGNED32;   (** system time zone offset in minutes (from -720 to 720) *)
	starttime*, startdate*: SIGNED32;	(** time this module was loaded (usually boot time) *)

	(** Return the current time and date in Oberon format. *)
	PROCEDURE Get*( VAR time, date: SIGNED32 );
	VAR tv: Unix.Timeval;  tz: Unix.Timezone;  t: Unix.TmPtr;  ret: SIGNED32;
	BEGIN
		ret := Unix.gettimeofday( tv, tz );
		t := Unix.localtime( tv );
		time := t.sec + ASH( t.min, 6 ) + ASH( t.hour, 12 );
		date := t.mday + ASH( t.mon + 1, 5 ) + ASH( t.year, 9 );
	END Get;

	(** Set the current time and date in Oberon format. *)
	PROCEDURE Set*( time, date: SIGNED32 );
		(* dummy,  time and date are controlled by the host systen *)
	END Set;


	PROCEDURE Init;
	VAR utv: Unix.Timeval;  utz: Unix.Timezone;  ret: SIGNED32;
	BEGIN
		ret := Unix.gettimeofday( utv, utz );
		tz := utz.minuteswest;
		Get( starttime, startdate )
	END Init;

BEGIN
	Init
END Clock.



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
