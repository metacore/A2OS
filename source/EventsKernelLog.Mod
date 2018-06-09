MODULE EventsKernelLog; (** AUTHOR "staubesv"; PURPOSE "Log system events to kernel log"; *)
(**
 * Log system events to kernel log
 *
 * History:
 *
 *	07.03.2007	First release (staubesv)
 *)

IMPORT
	KernelLog, Modules, Events, EventsUtils, Streams;

CONST
	Verbose = TRUE;

	(* System event classification (AosEventClasses.XML) *)
	Class = 1;		(* Events *)
	Subclass = 2;	(* Logging *)

	ModuleName = "EventsKernelLog";

TYPE

	EventLogger = OBJECT(Events.Sink);
	VAR w : Streams.Writer;

		PROCEDURE Handle*(event : Events.Event);
		BEGIN
			EventsUtils.ToStream(w, event);
		END Handle;

		PROCEDURE &Init*;
		BEGIN
			name := ModuleName;
			NEW(w, KernelLog.Send, 1024);
		END Init;

	END EventLogger;

VAR
	eventLogger- : EventLogger;

PROCEDURE Install*;
END Install;

PROCEDURE Cleanup;
BEGIN
	Events.AddEvent(ModuleName, Events.Information, Class, Subclass, 0, "Kernel log event logger shut down", Verbose);
	Events.Unregister(eventLogger);
END Cleanup;

BEGIN
	Modules.InstallTermHandler(Cleanup);
	NEW(eventLogger);
	Events.Register(eventLogger);
	Events.AddEvent(ModuleName, Events.Information, Class, Subclass, 0, "Started kernel log event logger", Verbose);
END EventsKernelLog.

EventsKernelLog.Install ~		System.Free EventsKernelLog ~
