MODULE UpTime; (** AUTHOR "staubesv"; PURPOSE "Up-Time Monitor"; *)

IMPORT
	KernelLog, Streams, Commands, Dates;

VAR
	startTime : Dates.DateTime;

PROCEDURE Get*(VAR days, hours, minutes, seconds : SIGNED32);
BEGIN
	Dates.TimeDifference(startTime, Dates.Now(), days, hours, minutes, seconds);
END Get;

PROCEDURE ToStream*(stream : Streams.Writer);
VAR days, hours, minutes, seconds : SIGNED32;
BEGIN
	ASSERT(stream # NIL);
	Get(days, hours, minutes, seconds);
	stream.Int(days, 0); stream.String(" days ");
	IF (hours < 10) THEN stream.Char("0"); END;
	stream.Int(hours, 0); stream.Char(":");
	IF (minutes < 10) THEN stream.Char("0"); END;
	stream.Int(minutes, 0); stream.Char(":");
	IF (seconds < 10) THEN stream.Char("0"); END;
	stream.Int(seconds, 0);
END ToStream;

PROCEDURE GetStartTime*() : Dates.DateTime;
BEGIN
	RETURN startTime;
END GetStartTime;

PROCEDURE Show*(context : Commands.Context);
BEGIN
	context.out.String("Uptime: "); ToStream(context.out); context.out.Ln;
END Show;

PROCEDURE Install*;
BEGIN
	KernelLog.String("Uptime monitor started."); KernelLog.Ln;
END Install;

BEGIN
	startTime := Dates.Now();
END UpTime.

System.Free UpTime ~

UpTime.Show ~
