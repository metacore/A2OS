(* ETH Oberon, Copyright 2001 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

MODULE Dates IN Oberon;	(** portable *) (* PS  *)

IMPORT Oberon, Texts;

CONST
	minute* = 60; hour* = 60*minute; day* = 24*hour; week*= 7* day;
	zeroY = 1900;
	firstY* = 1901;

VAR
	TimeDiff*: SIGNED32;	(** local difference to universal time in minutes *)
	A : ARRAY 13 OF SIGNED16;
	T : ARRAY 365 OF SIGNED8;

(** Returns TRUE if year is a leap year *)
PROCEDURE IsLeapYear* (year: SIGNED16): BOOLEAN;
BEGIN RETURN (year MOD 4 = 0) & (~(year MOD 100 = 0) OR (year MOD 400 = 0))
END IsLeapYear;

PROCEDURE LastDay (year, month: SIGNED16): SIGNED16;
BEGIN
	IF (month < 8) & ODD(month) OR (month > 7) & ~ODD(month) THEN RETURN 31
	ELSIF month = 2 THEN
		IF IsLeapYear(year) THEN RETURN 29 ELSE RETURN 28 END
	ELSE RETURN 30
	END
END LastDay;

(** Returns the number of days since 1.1.[firstY] *)
PROCEDURE NumberOfDays* (date: SIGNED32): SIGNED32;
VAR num: SIGNED32; y, m: SIGNED16;
BEGIN
	y := SHORT(date DIV 512) + zeroY - firstY;
	m := SHORT(date DIV 32) MOD 16;
	num := LONG(y) * 365 + y DIV 4 + A[(m - 1) MOD 12] + (date MOD 32) - 1;
	IF IsLeapYear(firstY + y) & (m > 2) THEN INC(num) END;
	RETURN num
END NumberOfDays;

(** Returns the date 1.1.[firstY] + days *)
PROCEDURE NumberOfDaysToDate* (days: SIGNED32): SIGNED32;
VAR M, m, y, d: SIGNED32;
BEGIN
	IF (days + 307) MOD 1461 = 0 THEN d := 2 ELSE d := 1 END;
	days := days - (days + 307) DIV 1461; y := firstY + days DIV 365;
	IF firstY > y THEN y := zeroY; m := 1; d := 1
	ELSE M := days MOD 365; m := T[M]; d := M - A[m - 1] + d
	END;
	RETURN ASH(ASH(y-zeroY, 4) + m, 5) + d
END NumberOfDaysToDate;


(** Converts year, month and day into an Oberon date *)
PROCEDURE ToDate* (year, month, day: SIGNED16): SIGNED32;
VAR d: SIGNED16;
BEGIN
	month := 1 + (month - 1) MOD 12;
	d := LastDay(year, month); day := 1 + (day - 1) MOD d;
	RETURN ASH(ASH(year-zeroY, 4) + month, 5) + day
END ToDate;

(** Converts hour, min and sec into an Oberon time *)
PROCEDURE ToTime* (hour, min, sec: SIGNED16): SIGNED32;
BEGIN RETURN ((LONG(hour) MOD 24)*64 + (min MOD 60))*64 + (sec MOD 60)
END ToTime;


(** Extracts year, month and day of an Oberon date *)
PROCEDURE ToYMD* (date: SIGNED32; VAR year, month, day: SIGNED16);
BEGIN
	year := SHORT(date DIV 512) + zeroY;
	month := SHORT((date DIV 32) MOD 16); day := SHORT(date MOD 32)
END ToYMD;

(** Extracts hour, min and sec of an Oberon time *)
PROCEDURE ToHMS* (time: SIGNED32; VAR hour, min, sec: SIGNED16);
BEGIN
	hour := SHORT(time DIV 4096); min := SHORT((time DIV 64) MOD 64); sec := SHORT(time MOD 64)
END ToHMS;

(** Returns weekday from date, where 0 is monday *)
PROCEDURE DayOfWeek* (date: SIGNED32): SIGNED16;
VAR num: SIGNED32;
BEGIN
	num := NumberOfDays(date);
	RETURN SHORT((num+1) MOD 7)
END DayOfWeek;

(** Returns number of days in a month *)
PROCEDURE DaysOfMonth* (date: SIGNED32): SIGNED16;	(* returns last day in month *)
VAR year, month: SIGNED32;
BEGIN
	month := (date DIV 32) MOD 16; year := (date DIV 512) + zeroY;
	RETURN LastDay(SHORT(year), SHORT(month))
END DaysOfMonth;


(** Following three procedures are used to add/subtract a certain amount of days/month/years. *)
PROCEDURE AddYear* (date: SIGNED32; years: SIGNED16): SIGNED32;
VAR y, m, d: SIGNED16;
BEGIN
	ToYMD(date, y, m, d);
	IF firstY <= y + years THEN
		IF IsLeapYear(y) & (m = 2) & (d = 29) & ~IsLeapYear(y + years) THEN d := 28 END;
		date := ToDate(y + years, m, d)
	END;
	RETURN date
END AddYear;

PROCEDURE AddMonth* (date: SIGNED32; months: SIGNED16): SIGNED32;
VAR y, m, d: SIGNED16;
BEGIN
	ToYMD(date, y, m, d); INC(m, months - 1);
	y :=  y + m DIV 12;
	IF firstY <= y THEN
		m := m MOD 12 + 1;
		IF m =2 THEN
			IF (d > 29) & IsLeapYear(y) THEN d := 29
			ELSIF (d > 28) & ~ IsLeapYear(y) THEN d := 28
			END
		ELSIF (d > 30) & ((m < 8) & ~ODD(m) OR (m > 7) & ODD(m)) THEN d := 30
		END;
		date := ToDate(y, m, d)
	END;
	RETURN date
END AddMonth;

PROCEDURE AddDay* (date: SIGNED32; days: SIGNED16): SIGNED32;
VAR num: SIGNED32;
BEGIN num := NumberOfDays(date); num := num + days; RETURN NumberOfDaysToDate(num)
END AddDay;


(** Following three procedures are used to add/subtract a certain amount of time. *)
PROCEDURE AddHour* (time: SIGNED32; hour: SIGNED16): SIGNED32;
VAR s, m, h: SIGNED16;
BEGIN ToHMS(time, h, m, s); RETURN ToTime((h + hour) MOD 24, m, s)
END AddHour;

PROCEDURE AddMinute* (time: SIGNED32; min: SIGNED16): SIGNED32;
VAR s, m, h: SIGNED16;
BEGIN
	ToHMS(time, h, m, s); INC(m, min);
	IF (m < 0) OR (m >= 60) THEN h := (h + m DIV 60) MOD 24; m := m MOD 60 END;
	RETURN ToTime(h, m, s)
END AddMinute;

PROCEDURE AddSecond* (time: SIGNED32; sec: SIGNED16): SIGNED32;
VAR s, m, h: SIGNED16;
BEGIN
	ToHMS(time, h, m, s); INC(s, sec);
	IF (s < 0) OR (s >= 60) THEN
		INC(m, s DIV 60); s := s MOD 60;
		IF (m < 0) OR (m >= 60) THEN h := (h + m DIV 60) MOD 24; m := m MOD 60 END
	END;
	RETURN ToTime(h, m, s)
END AddSecond;

(** Following procedure adds/subtracts a certain amount seconds to time/date. *)
PROCEDURE AddTime* (VAR time, date: SIGNED32; sec: SIGNED32);
VAR h, m, s: SIGNED32; ss, mm, hh: SIGNED16;
BEGIN
	ToHMS(time, hh, mm, ss); s := sec + ss; h := hh; m := mm;
	IF (s < 0) OR (s >= 60) THEN
		m := s DIV 60 + mm; s := s MOD 60;
		IF (m < 0) OR (m >= 60) THEN
			h := m DIV 60 + hh; m := m MOD 60;
			IF (h < 0) OR (h >= 24) THEN
				date := AddDay(date, SHORT(h DIV 24)); h := h MOD 24
			END
		END
	END;
	time := ToTime(SHORT(h), SHORT(m), SHORT(s))
END AddTime;

PROCEDURE Init;
	VAR
		diff: ARRAY 8 OF CHAR;
		S: Texts.Scanner;
		i, j: SIGNED32;
BEGIN
	A[0] := 0; A[1] := 31; A[2] := 59; A[3] := 90; A[4] := 120; A[5] := 151; A[6] := 181;
	A[7] := 212; A[8] := 243; A[9] :=  273; A[10] := 304; A[11] := 334; A[12] := 365;
	i := 0; j := 0;
	WHILE i < 12 DO WHILE j < A[i+1] DO  T[j] := SHORT(SHORT(i + 1)); INC(j) END; INC(i) END;
	Oberon.OpenScanner(S, "System.TimeDiff");
	TimeDiff := 0;
	IF S.class = Texts.String THEN
		COPY(S.s, diff);
		i := 0; j := 1;
		IF diff[i] = "+" THEN
			INC(i)
		ELSIF diff[i] = "-" THEN
			INC(i); j := -1
		END;
		WHILE (diff[i] >= "0") & (diff[i] <= "9") DO
			TimeDiff := 10*TimeDiff+ORD(diff[i])-ORD("0");
			INC(i)
		END;
		TimeDiff := (TimeDiff DIV 100)*60 + (TimeDiff MOD 100);
		TimeDiff := j*TimeDiff
	END
END Init;

BEGIN
	Init()
END Dates.