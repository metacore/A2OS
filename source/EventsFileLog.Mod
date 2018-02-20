MODULE EventsFileLog; (** AUTHOR "staubesv"; PURPOSE "Log system events to files"; *)
(**
 * Log system events to files
 *
 * History:
 *
 *	07.03.2007	First release (staubesv)
 *	31.07.2007	Added log file size limitation (staubesv)
 *)

IMPORT
	Modules, Commands, Files, Events, EventsUtils;

CONST

	DefaultLogFile = "AosEventLog.log";

	MaxLogFileSize = 1024 * 1024; (* Bytes, 1024 bytes space reserved *)

	Verbose = TRUE;

	(* System event classification *)
	Class = 1; 		(* Events *)
	Subclass = 1;	(* Logging *)

	ModuleName = "EventsFileLog";

TYPE

	EventLogger = OBJECT(Events.Sink);
	VAR
		file : Files.File;
		w : Files.Writer;
		currentFileSize, maxFileSize : LONGINT;
		warned : BOOLEAN;

		PROCEDURE Handle*(event : Events.Event);
		BEGIN
			IF currentFileSize < maxFileSize - 1024 THEN
				EventsUtils.ToStream(w, event);
				currentFileSize := file.Length();
			ELSIF ~warned THEN
				warned := TRUE;
				Events.AddEvent(ModuleName, Events.Warning, Class, Subclass, 0, "Event log file is full. Stop logging.", TRUE);
			END;
		END Handle;

		PROCEDURE &Init*(file : Files.File; append : BOOLEAN; maxFileSize : LONGINT);
		VAR ofs : LONGINT;
		BEGIN
			ASSERT(file # NIL);
			name := ModuleName;
			SELF.file := file;
			SELF.maxFileSize := maxFileSize;
			IF append THEN ofs := file.Length(); ELSE ofs := 0; END;
			currentFileSize := ofs;
			warned := FALSE;
			Files.OpenWriter(w, file, ofs);
		END Init;

	END EventLogger;

VAR
	eventLogger- : EventLogger;

PROCEDURE OpenFile(CONST filename : ARRAY OF CHAR; append : BOOLEAN) : Files.File;
VAR file : Files.File;
BEGIN
	IF append THEN
		file := Files.Old(filename);
	ELSE
		file := Files.New(filename);
		Files.Register(file);
	END;
	RETURN file;
END OpenFile;

PROCEDURE Start*(context : Commands.Context); (** [-append] [-max] [filename] ~ *)
VAR
	filename : ARRAY 256 OF CHAR; append : BOOLEAN;
	file : Files.File;
BEGIN {EXCLUSIVE}
	context.arg.SkipWhitespace;
	context.arg.String(filename);
	IF filename[0] = "-" THEN
		IF filename = "-append" THEN
			append := TRUE;
			context.arg.SkipWhitespace;
			context.arg.String(filename);
		ELSE
			context.out.String("Unexpected parameter"); context.out.Ln;
			RETURN;
		END;
	END;
	IF eventLogger = NIL THEN
		IF filename = "" THEN filename := DefaultLogFile; END;
		file := OpenFile(filename, append);
		IF file # NIL THEN
			NEW(eventLogger, file, append, MaxLogFileSize);
			Events.Register(eventLogger);
			Events.AddEvent(ModuleName, Events.Information, Class, Subclass, 0, "Started file log event logger", Verbose);
			context.out.String("Logging system events to file "); context.out.String(filename); context.out.Ln;
		ELSE
		END;
	ELSE
		context.out.String("Logger is already running."); context.out.Ln;
	END;
END Start;

PROCEDURE Stop*(context : Commands.Context); (** ~ *)
BEGIN {EXCLUSIVE}
	IF eventLogger # NIL THEN
		Events.Unregister(eventLogger); eventLogger := NIL;
		Events.AddEvent(ModuleName, Events.Information, Class, Subclass, 0, "Stopped file log event logger", Verbose);
		context.out.String("Logger stopped."); context.out.Ln;
	ELSE
		context.out.String("Logger is not running."); context.out.Ln;
	END;
END Stop;

PROCEDURE Cleanup;
BEGIN
	IF eventLogger # NIL THEN
		Events.AddEvent(ModuleName, Events.Information, Class, Subclass, 0, "File log event logger shut down", Verbose);
		Events.Unregister(eventLogger); eventLogger := NIL;
	END;
END Cleanup;

BEGIN
	Modules.InstallTermHandler(Cleanup);
END EventsFileLog.

EventsFileLog.Start ~
EventsFileLog.Stop ~

EventsFileLog.Start -append ~

SystemTools.Free EventsFileLog ~
