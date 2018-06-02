MODULE EventsUtils; (** AUTHOR "staubesv"; PURPOSE "System events utilities"; *)
(**
 * History:
 *
 *	07.03.2007	First release (staubesv)
 *)

IMPORT
	Commands, Events, Streams, Files, Dates, Strings;

CONST

	(** Result codes for system event operations *)
	Ok* = 0;
	Error* = 1;
	Uncomplete* = 3;

	EOF = 4;

	DateTimeFormat = "dd.mm.yyyy hh:nn:ss"; (* don't change or adapt DateTimeFromStream *)

TYPE

	EventWrapper* = POINTER TO RECORD
		nextIndex- : LONGINT; (* index of next free place in events array *)
		events- : POINTER TO ARRAY OF Events.Event;
		next- : EventWrapper;
	END;

TYPE

	EventContainer* = OBJECT(Events.Sink)
	VAR
		nofWrappers, nofEvents : LONGINT;

		(* stamps *)
		lastCleared, lastAdded : LONGINT;

		events, current : EventWrapper;
		maxNofWrappers, eventsPerWrapper : LONGINT;

		(* for polling *)
		PROCEDURE GetStamp*() : LONGINT;
		BEGIN
			RETURN lastAdded;
		END GetStamp;

		PROCEDURE GetEvents*(VAR nofEvents : LONGINT; VAR full : BOOLEAN; VAR lastCleared : LONGINT) : EventWrapper;
		BEGIN {EXCLUSIVE}
			nofEvents := SELF.nofEvents;
			full := nofEvents = maxNofWrappers * eventsPerWrapper;
			lastCleared := SELF.lastCleared;
			RETURN events;
		END GetEvents;

		PROCEDURE IsFull*() : BOOLEAN;
		BEGIN {EXCLUSIVE}
			RETURN nofEvents = maxNofWrappers * eventsPerWrapper;
		END IsFull;

		PROCEDURE Clear*;
		BEGIN {EXCLUSIVE}
			events.next := NIL; events.nextIndex := 0;
			current := events;
			nofWrappers := 1; nofEvents := 0;
			INC(lastCleared); INC(lastAdded);
		END Clear;

		(** Returns the maximum number of event records this container can hold *)
		PROCEDURE GetSize*() : LONGINT;
		BEGIN
			RETURN maxNofWrappers * eventsPerWrapper;
		END GetSize;

		PROCEDURE Handle*(event : Events.Event);
		VAR wrapper : EventWrapper;
		BEGIN {EXCLUSIVE}
			IF nofEvents = maxNofWrappers * eventsPerWrapper THEN RETURN; END;

			IF (current.nextIndex >= LEN(current.events)) THEN
				NEW(wrapper); NEW(wrapper.events, eventsPerWrapper); wrapper.nextIndex := 0;
				current.next := wrapper;
				current := wrapper;
				INC(nofWrappers);
			END;

			current.events[current.nextIndex] := event;
			INC(current.nextIndex);
			INC(nofEvents);
			INC(lastAdded);
		END Handle;

		PROCEDURE &Init*(maxNofWrappers, eventsPerWrapper : LONGINT);
		BEGIN
			SELF.maxNofWrappers := maxNofWrappers;
			SELF.eventsPerWrapper:= eventsPerWrapper;
			NEW(events); NEW(events.events, eventsPerWrapper); events.nextIndex := 0;
			current := events;
			nofWrappers := 1; nofEvents := 0;
		END Init;

	END EventContainer;

PROCEDURE LoadFromFile*(CONST filename : ARRAY OF CHAR; VAR events : EventContainer; VAR msg : ARRAY OF CHAR; VAR res : WORD);
VAR file : Files.File; r : Files.Reader; event : Events.Event; nofEvents : LONGINT;
BEGIN
	file := Files.Old(filename);
	IF file # NIL THEN
		Files.OpenReader(r, file, 0);
		NEW(events, 1024, 1024);
		nofEvents := 0;
		WHILE (r.Available() > 0) & (r.res = Streams.Ok) DO
			FromStream(r, event, msg, res);
			IF (res = Ok) THEN
				INC(nofEvents);
				events.Handle(event);
			ELSIF (res = EOF) THEN
				(* all done *)
			ELSE
				IF (nofEvents = 0) THEN
					res := Error;
				ELSE
					res := Uncomplete;
				END;
				RETURN;
			END;
		END;
		res := Ok;
	ELSE
		msg := "File not found"; res := Error;
	END;
END LoadFromFile;

PROCEDURE StoreToFile*(CONST filename : ARRAY OF CHAR; events : EventContainer; VAR msg : ARRAY OF CHAR; VAR res : WORD);
VAR
	file : Files.File; w : Files.Writer; wrapper : EventWrapper;
	nofEvents, lastCleared, i, idx : LONGINT; full : BOOLEAN;
BEGIN
	file := Files.New(filename);
	IF file # NIL THEN
		Files.OpenWriter(w, file, 0);
		wrapper := events.GetEvents(nofEvents, full, lastCleared);
		IF nofEvents > 0 THEN
			i := 0;
			WHILE (i < nofEvents) DO
				IF i >= LEN(wrapper.events) THEN wrapper := wrapper.next; END;
				idx := i MOD LEN(wrapper.events);
				ToStream(w, wrapper.events[idx]);
				INC(i);
			END;
			Files.Register(file);
			res := Ok;
		ELSE
			msg := "Number of events must be greater than zero"; res := Error;
		END;
	ELSE
		msg := "Could not create file"; res := Error;
	END;
END StoreToFile;

PROCEDURE ToStream*(w : Streams.Writer; event : Events.Event);
VAR dt : Dates.DateTime; str : ARRAY 64 OF CHAR;
BEGIN
	ASSERT(w # NIL);
	dt := Dates.OberonToDateTime(event.date, event.time);
	Strings.FormatDateTime(DateTimeFormat, dt, str);
	w.String(str); w.String(" ");
	GetTypeString(event.type, str); w.String(str); w.String(" ");
	w.String('"'); w.String(event.originator); w.String('"');
	w.String(" ["); w.Int(event.class, 0); w.String(","); w.Int(event.subclass, 0); w.String(","); w.Int(event.code, 0); w.String('] "');
	w.String(event.message); w.String('"'); w.Ln;
	w.Update;
END ToStream;

PROCEDURE FromStream*(r : Streams.Reader; VAR event : Events.Event; VAR msg : ARRAY OF CHAR; VAR res : WORD);
VAR dt : Dates.DateTime; str : Events.Message; ch : CHAR; class, subclass, code : LONGINT;

	PROCEDURE IsValid(value : LONGINT) : BOOLEAN;
	BEGIN
		RETURN (0 <= value) & (value <= MAX(SHORTINT));
	END IsValid;

BEGIN
	ASSERT(r # NIL);
	res := Error;
	r.SkipWhitespace;
	IF r.Available() = 0 THEN res := EOF; RETURN; END;
	(* date & time *)
	IF ~DateTimeFromStream(r, dt) THEN
		ch := r.Peek();
		IF r.res = Streams.EOF THEN res := Ok; RETURN;
		ELSE
			msg := "Could not read datetime string"; RETURN;
		END;
	END;
	Dates.DateTimeToOberon(dt, event.date, event.time);
	(* type *)
	r.SkipWhitespace; r.String(str); IF (r.res # Streams.Ok) THEN msg := "Could not read type string"; RETURN; END;
	event.type := GetType(str);
	(* originator *)
	r.SkipWhitespace; r.String(event.originator); IF (r.res # Streams.Ok) THEN msg := "Could not read originator string"; RETURN; END;
	(* class, subclass & code *)
	r.SkipWhitespace;
	r.Char(ch); IF (r.res # Streams.Ok) OR (ch # "[") THEN msg := "Expected opening bracket"; RETURN; END;
	r.Int(class, FALSE); IF (r.res # Streams.Ok) THEN	msg := "Could not parse event class"; RETURN; END;
	r.Char(ch); IF (r.res # Streams.Ok) OR (ch # ",") THEN msg := "Expected ,"; RETURN; END;
	r.Int(subclass, FALSE); IF (r.res # Streams.Ok) THEN msg := "Could not parse event subclass"; RETURN; END;
	r.Char(ch); IF (r.res # Streams.Ok) OR (ch # ",") THEN msg := "Expected ,"; RETURN; END;
	r.Int(code, FALSE); IF (r.res # Streams.Ok) THEN msg := "Could not parse event code"; RETURN; END;
	r.Char(ch); IF (r.res # Streams.Ok) OR (ch # "]") THEN msg := "Expected closing bracket"; RETURN; END;
	(* check validity of class/subclass/code *)
	IF ~IsValid(class) THEN msg := "Class must be in [0, 127]"; RETURN; END;
	IF ~IsValid(subclass) THEN msg := "Subclass must be in [0, 127]"; RETURN; END;
	IF ~IsValid(code) THEN msg := "Code must be in [0, 127]"; RETURN; END;
	event.class := SHORT(SHORT(class));
	event.subclass := SHORT(SHORT(subclass));
	event.code := SHORT(SHORT(code));
	(* message *)
	r.SkipWhitespace; r.String(event.message);
	IF (r.res # Streams.EOF) & (~r.EOLN()) THEN msg := "Expected end of line"; RETURN; END;
	res := Ok;
END FromStream;

PROCEDURE DateTimeFromStream(r : Streams.Reader; VAR dt : Dates.DateTime) : BOOLEAN;
VAR ch : CHAR;
BEGIN
	ASSERT(r # NIL);
	r.SkipWhitespace;
	r.Int(dt.day, FALSE);
	r.Char(ch); IF (r.res # Streams.Ok) OR (ch # ".") THEN RETURN FALSE; END;
	r.Int(dt.month, FALSE);
	r.Char(ch); IF (r.res # Streams.Ok) OR (ch # ".") THEN RETURN FALSE; END;
	r.Int(dt.year, FALSE);
	r.Char(ch); IF (r.res # Streams.Ok) OR (ch # " ") THEN RETURN FALSE; END;
	r.Int(dt.hour, FALSE);
	r.Char(ch); IF (r.res # Streams.Ok) OR (ch # ":") THEN RETURN FALSE; END;
	r.Int(dt.minute, FALSE);
	r.Char(ch); IF (r.res # Streams.Ok) OR (ch # ":") THEN RETURN FALSE; END;
	r.Int(dt.second, FALSE);
	IF (r.res # Streams.Ok) THEN RETURN FALSE; END;
	RETURN Dates.ValidDateTime(dt);
END DateTimeFromStream;

PROCEDURE GetTypeString*(type : LONGINT; VAR string: ARRAY OF CHAR);
VAR nbr : ARRAY 16 OF CHAR;
BEGIN
	CASE type OF
		|Events.Unknown: string := "Unknown";
		|Events.Undefined: string := "Undefined";
		|Events.Information: string := "Information";
		|Events.Warning: string := "Warning";
		|Events.Error: string := "Error";
		|Events.Critical: string := "Critical";
		|Events.Alert: string := "Alert";
		|Events.Failure: string := "Failure";
	ELSE
		string := "Unknown ("; Strings.IntToStr(type, nbr); Strings.Append(string, nbr); Strings.Append(string, ")");
	END;
END GetTypeString;

PROCEDURE GetType*(CONST string : ARRAY OF CHAR) : SHORTINT;
VAR type : SHORTINT;
BEGIN
	IF string = "Unknown" THEN type := Events.Unknown;
	ELSIF string = "Undefined" THEN type := Events.Undefined;
	ELSIF string = "Information" THEN type := Events.Information;
	ELSIF string = "Warning" THEN type := Events.Warning;
	ELSIF string = "Error" THEN type := Events.Error;
	ELSIF string = "Critical" THEN type := Events.Critical;
	ELSIF string = "Alert" THEN type := Events.Alert;
	ELSIF string = "Failure" THEN type := Events.Failure;
	ELSE
		type := Events.Unknown;
	END;
	RETURN type;
END GetType;

PROCEDURE GenerateEvent*(context : Commands.Context); (** originator type class subclass code message ~ *)
VAR event : Events.Event; value : LONGINT;
BEGIN
	context.arg.SkipWhitespace; context.arg.String(event.originator);
	context.arg.SkipWhitespace; context.arg.Int(value, FALSE); event.type := SHORT(SHORT(value));
	context.arg.SkipWhitespace; context.arg.Int(value, FALSE); event.class := SHORT(SHORT(value));
	context.arg.SkipWhitespace; context.arg.Int(value, FALSE); event.subclass := SHORT(SHORT(value));
	context.arg.SkipWhitespace; context.arg.Int(value, FALSE); event.code := SHORT(SHORT(value));
	context.arg.SkipWhitespace; context.arg.String(event.message);
	Events.Add(event, FALSE);
END GenerateEvent;

END EventsUtils.

