MODULE EventsMemoryLog; (** AUTHOR "staubesv"; PURPOSE "Log system events in memory"; *)
(**
 * History:
 *
 *	14.03.2007	First release (staubesv)
 *)

IMPORT
	Modules, Events, EventsUtils;

CONST

	(* Logsize = MaxNofWrapper * EventsPerWrapper events *)
	MaxNofWrapper = 16;
	EventsPerWrapper = 256;

TYPE

	EventLogger = OBJECT(Events.Sink)
	VAR
		events : EventsUtils.EventContainer;

		PROCEDURE Handle*(event : Events.Event);
		BEGIN
			IF ~events.IsFull() THEN
				events.Handle(event);
			END;
		END Handle;

		PROCEDURE &Init*;
		BEGIN
			name := "EventLog";
			NEW(events, MaxNofWrapper, EventsPerWrapper);
		END Init;

	END EventLogger;

VAR
	eventLog- : EventLogger;

PROCEDURE GetEvents*() : EventsUtils.EventContainer;
BEGIN
	RETURN eventLog.events;
END GetEvents;

PROCEDURE Clear*;
BEGIN
	eventLog.events.Clear;
END Clear;

PROCEDURE Cleanup;
BEGIN
	Events.Unregister(eventLog);
END Cleanup;

BEGIN
	Modules.InstallTermHandler(Cleanup);
	NEW(eventLog);
	Events.Register(eventLog);
END EventsMemoryLog.
