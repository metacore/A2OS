MODULE Clock;  	(** fof , adaption of interface of Aos modules Clock to windows version **)
(* ETH Oberon, Copyright 2003 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

(*
history
first version (windows): 01.04.2003, fof.

todo

*)

IMPORT Kernel32;
VAR	tz*: SIGNED32;	(** system time zone offset in minutes (from -720 to 720) *)
	starttime*, startdate*: SIGNED32;	(** time this module was loaded (usually boot time) *)

	(** Get time (t) and date (d).
	day = d MOD 32, month = d DIV 32 MOD 16, year = 1900+d DIV 512,
	hour = t DIV 4096 MOD 32, minute = t DIV 64 MOD 64, second = t MOD 64 *)

PROCEDURE Get* (VAR t, d: SIGNED32);
	VAR st: Kernel32.SystemTime;
BEGIN
	t := 0;  d := 0;
	Kernel32.GetLocalTime(st);
	d := st.wYear - 1900;  d := ASH(d, 4);
	d := d + st.wMonth;  d := ASH(d, 5);
	d := d + st.wDay;
	t := st.wHour;  t := ASH(t, 6);
	t := t + st.wMinute;  t := ASH(t, 6);
	t := t + st.wSecond
END Get;

(** Set time (t) and date (d). *)
PROCEDURE Set* (t, d: SIGNED32);
	VAR st: Kernel32.SystemTime;retBOOL: Kernel32.BOOL;								(* Dan 09.11.05 *)
BEGIN
	st.wDay := SHORT(d MOD 20H);  d := ASH(d, - 5);
	st.wMonth := SHORT(d MOD 10H);  d := ASH(d, - 4);
	st.wYear := SHORT(d MOD 80H) + 1900;
	st.wMilliseconds := 0;
	st.wSecond := SHORT(t MOD 40H);  t := ASH(t, - 6);
	st.wMinute := SHORT(t MOD 40H);  t := ASH(t, - 6);
	st.wHour := SHORT(t MOD 20H);
	retBOOL := Kernel32.SetLocalTime(st)
END Set;

(* Get and Set taken from Module Oberon, (C) Copyright ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich *)
BEGIN
Get(starttime,startdate)
END Clock.
