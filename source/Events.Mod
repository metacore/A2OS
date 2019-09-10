MODULE Events; (** AUTHOR "staubesv"; PURPOSE "System events interface"; *)
(**
 * Simple framework for system event logging.
 *
 * The main purpose of this framework is to enable simple event logging. Although it would be possible to use it as a kind
 * of general event system, the user is discouraged in doing so.
 *
 * Notes:
 *	- This module is considered to be really low-level. Don't import any other modules
 *	- The definition of event classes/subclasses/codes is done on higher level (see Events.XML)
 *
 * History:
 *
 *	06.03.2007	First release (staubesv)
 *)

IMPORT
	KernelLog, Modules, Clock;

CONST

	(** Event types. All other numbers are considered to be of an unknown type *)
	Unknown* = -1;
	Undefined* = 0;
	Information* = 1;
	Warning* = 2;
	Error* = 3;
	Critical* = 4;
	Alert* = 5;
	Failure* = 6;

	(** Event classes, subclasses and codes are supposed to be defined at higher levels (see AosEventClasses.XML) *)

	(* Event Dispatcher states *)
	Running = 1;
	Terminating = 2;
	Terminated = 3;

	QueueSize= 256; (* event records *)

	ModuleName = "Events";

	Verbose = TRUE;

	(* If set to TRUE, all events are first displayed on kernel log (blocking) before inserted into the event queue *)
	Debug = FALSE;

TYPE

	(** Must not contain any quote characters *)
	Name* = Modules.Name;
	Message* = ARRAY 468 OF CHAR;

	Event* = RECORD
		originator* : Name;	(** name of module that generated event *)
		type*, class*, subclass*, code* : SIGNED8;
		message* : Message;
		date*, time* : SIGNED32; (* when enqueued in event queue *)
	END;

TYPE

	Sink* = OBJECT
	VAR
		name* : Name;

		next : Sink;
		filters : Filter;

		PROCEDURE AddFilter*(filter : Filter);
		BEGIN {EXCLUSIVE}
			IF filters = NIL THEN
				filters := filter;
			ELSE
				filter.next := filters;
				filters := filter;
			END;
		END AddFilter;

		PROCEDURE RemoveFilter*(filter : Filter);
		VAR f : Filter;
		BEGIN {EXCLUSIVE}
			IF filters = filter THEN
				filters := filters.next;
			ELSE
				f := filters; WHILE(f.next # NIL) & (f.next # filter) DO f := f.next; END;
				IF f.next # NIL THEN
					f.next := f.next.next;
				END;
			END;
		END RemoveFilter;

		PROCEDURE HandleInternal(event : Event);
		VAR f : Filter; discard : BOOLEAN;
		BEGIN
			f := filters; WHILE ((f # NIL) & ~discard) DO f.Filter(event, discard); END;
			IF ~discard THEN
				Handle(event);
			END;
		END HandleInternal;

		PROCEDURE Handle*(event : Event); (* abstract *)
		BEGIN HALT(301); END Handle;

	END Sink;

TYPE

	FilterO* = OBJECT
	VAR
		next : FilterO;

		PROCEDURE Filter*(event : Event; VAR discard : BOOLEAN); (* abstract *)
		BEGIN HALT(301); END Filter;

	END FilterO;

	Filter*= FilterO;

TYPE

	EventQueue = OBJECT
	VAR
		size : SIGNED32;
		head, len: SIGNED32;
		ringbuffer : POINTER TO ARRAY OF Event;
		running : BOOLEAN;

		PROCEDURE Enqueue(event : Event) : BOOLEAN;
		BEGIN {EXCLUSIVE}
			IF ~IsFull() THEN
				Clock.Get(event.time, event.date); (* not sure whether this is too expensive *)
				ringbuffer[(head + len) MOD size] := event;
				INC(len);
				RETURN TRUE;
			ELSE
				(* discard event *)
				RETURN FALSE;
			END;
		END Enqueue;

		PROCEDURE Dequeue(VAR event : Event);
		BEGIN {EXCLUSIVE}
			AWAIT(len > 0);
			event := ringbuffer[head];
			head := (head + 1) MOD size;
			DEC(len);
		END Dequeue;

		PROCEDURE IsFull() : BOOLEAN;
		BEGIN
			RETURN len = QueueSize;
		END IsFull;

		PROCEDURE IsEmpty() : BOOLEAN;
		BEGIN {EXCLUSIVE}
			RETURN len = 0;
		END IsEmpty;

		PROCEDURE AwaitEvents;
		BEGIN {EXCLUSIVE}
			AWAIT((len > 0) OR (~running));
		END AwaitEvents;

		PROCEDURE Stop;
		BEGIN {EXCLUSIVE}
			running := FALSE;
		END Stop;

		PROCEDURE &Init*(size : SIGNED32);
		BEGIN
			running := TRUE;
			head := 0; len := 0;
			SELF.size := size;
			NEW(ringbuffer, size);
		END Init;

	END EventQueue;

TYPE

	EventDispatcher = OBJECT
	VAR
		state : SIGNED32;
		queue : EventQueue;
		sinks : Sink;

		PROCEDURE Register(sink : Sink);
		BEGIN {EXCLUSIVE}
			ASSERT(sink # NIL);
			sink.next := sinks.next;
			sinks.next := sink;
			INC(NnofListeners);
		END Register;

		PROCEDURE Unregister(sink : Sink);
		VAR s : Sink;
		BEGIN {EXCLUSIVE}
			s := sinks; WHILE (s.next # NIL) & (s.next # sink) DO s := s.next; END;
			IF s.next # NIL THEN
				s.next := s.next.next;
				DEC(NnofListeners);
			END;
		END Unregister;

		PROCEDURE Dispatch(event : Event);
		VAR sink : Sink;
		BEGIN {EXCLUSIVE}
			sink := sinks.next;
			IF sink # NIL THEN
				WHILE (sink # NIL) DO
					sink.HandleInternal(event);
					sink := sink.next;
				END;
				INC(NnofEventsHandled);
			ELSE
				INC(NnofEventsNotHandled);
			END;
		END Dispatch;

		PROCEDURE DispatchEvents;
		VAR event : Event;
		BEGIN
			WHILE (state = Running) & ~queue.IsEmpty() DO
				queue.Dequeue(event);
				Dispatch(event);
			END;
		END DispatchEvents;

		PROCEDURE Stop;
		BEGIN
			BEGIN {EXCLUSIVE} state := Terminating; END;
			queue.Stop;
			BEGIN {EXCLUSIVE} AWAIT(state = Terminated); END;
		END Stop;

		PROCEDURE &Init*;
		BEGIN
			NEW(sinks); (* head of list *)
			NEW(queue, QueueSize);
			state := Running;
		END Init;

	BEGIN {ACTIVE}
		WHILE state = Running DO
			DispatchEvents;
			queue.AwaitEvents();
		END;
		BEGIN {EXCLUSIVE} state := Terminated; END;
	END EventDispatcher;

VAR
	dispatcher : EventDispatcher;

	(* statistics *)
	NnofEvents-, NnofDiscarded-, NnofEventsHandled-, NnofEventsNotHandled-,
	NnofUnknown-, NnofUndefined-,
	NnofInformation-, NnofWarning-, NnofError-, NnofCritical-, NnofFailure-,
	NnofListeners- : SIGNED32;

(** Register an event sink at the event dispatcher *)
PROCEDURE Register*(sink : Sink);
BEGIN {EXCLUSIVE}
	ASSERT(sink # NIL);
	dispatcher.Register(sink);
	INC(NnofListeners);
END Register;

(** Unregister an event sink at the event dispatcher *)
PROCEDURE Unregister*(sink : Sink);
BEGIN {EXCLUSIVE}
	ASSERT(sink # NIL);
	dispatcher.Unregister(sink);
	DEC(NnofListeners);
END Unregister;

(** Add an event record to the event queue. If showOnKernenLog is TRUE, a simplified representation
	of the event (originator + ": " + message) is displayed on the kernel log.
	This operation is non-blocking if showOnKernelLog is FALSE, blocking otherwise *)
PROCEDURE Add*(event : Event; showOnKernelLog : BOOLEAN);
VAR discarded : BOOLEAN;
BEGIN
	IF Debug OR showOnKernelLog THEN
		ShowOnKernelLog(event); (* blocking!!! *)
	END;
	discarded := ~dispatcher.queue.Enqueue(event);
	UpdateStats(event, discarded);
END Add;

(** Generate an new event record and add it to the event queue. If showOnKernenLog is TRUE, a simplified representation
	of the event (originator + ": " + message) is displayed on the kernel log.
	This operation is non-blocking if showOnKernelLog is FALSE, blocking otherwise *)
PROCEDURE AddEvent*(CONST originator : Name; type, class, subclass, code : SIGNED8; CONST message : Message; showOnKernelLog : BOOLEAN);
BEGIN
	Add(NewEvent(originator, type, class, subclass, code, message), showOnKernelLog)
END AddEvent;

(** Generate an new event record *)
PROCEDURE NewEvent*(CONST originator : Name; type, class, subclass, code : SIGNED8; CONST message : Message) : Event;
VAR event : Event;
BEGIN
	event.originator := originator;
	event.type := type;
	event.class := class;
	event.subclass := subclass;
	event.code := code;
	event.message := message;
	RETURN event;
END NewEvent;

PROCEDURE ShowOnKernelLog(event : Event);
BEGIN
	KernelLog.Enter; KernelLog.String(event.originator); KernelLog.String(": "); KernelLog.String(event.message); KernelLog.Exit;
END ShowOnKernelLog;

PROCEDURE UpdateStats(event : Event; discarded : BOOLEAN);
BEGIN {EXCLUSIVE}
	INC(NnofEvents);
	IF discarded THEN
		INC(NnofDiscarded);
	ELSE
		CASE event.type OF
			|Undefined: INC(NnofUndefined);
			|Information: INC(NnofInformation);
			|Warning : INC(NnofWarning);
			|Error: INC(NnofError);
			|Critical: INC(NnofCritical);
			|Failure: INC(NnofFailure);
		ELSE
			INC(NnofUnknown);
		END;
	END;
END UpdateStats;

PROCEDURE ClearStats*; (** ~ *)
BEGIN {EXCLUSIVE}
	NnofEvents := 0; NnofDiscarded := 0;
	NnofUnknown := 0; NnofUndefined := 0;
	NnofInformation := 0; NnofWarning := 0;  NnofError := 0; NnofCritical := 0; NnofFailure := 0;
END ClearStats;

(** Start the event dispatcher *)
PROCEDURE Install*; (** ~ *)
END Install;

PROCEDURE Cleanup;
BEGIN
	dispatcher.Stop;
	IF Verbose THEN KernelLog.Enter; KernelLog.String(ModuleName); KernelLog.String(": System event log shut down."); KernelLog.Exit; END;
END Cleanup;

BEGIN
	NEW(dispatcher);
	Modules.InstallTermHandler(Cleanup);
	IF Verbose THEN KernelLog.Enter; KernelLog.String(ModuleName); KernelLog.String(": System event log started."); KernelLog.Exit; END;
END Events.

PC.Compile \s
	Events.Mod EventsUtils.Mod EventsMemoryLog.Mod EventsKernelLog.Mod EventsFileLog.Mod WMEventLog.Mod
~

System.Free
	EventsKernelLog  WMEventLog EventsFileLog EventsMemoryLog EventsUtils Events
~

Events.Install ~

EventsKernelLog.Install ~

EventsFileLog.Start test.log ~	EventsFileLog.Stop ~

EventsMemoryLog.Install ~

WMEventLog.Open ~
WMEventLog.OpenFile test.log ~

EventsUtils.GenerateEvent Tester  6 0 0 0 "This is a test event" ~

