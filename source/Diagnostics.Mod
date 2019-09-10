MODULE Diagnostics; (** AUTHOR "staubesv"; PURPOSE "Generic diagnostics reporting facility"; *)

IMPORT Streams;

CONST
	(** Entry types *)
	TypeInformation* = 0;
	TypeWarning* = 1;
	TypeError* = 2;

	(** DiagnosticsList.ToStream mask argument *)
	All* = {TypeInformation, TypeWarning, TypeError};

TYPE

	Diagnostics* = OBJECT

		PROCEDURE Error*(CONST source : ARRAY OF CHAR; position : Streams.Position; CONST message : ARRAY OF CHAR);
		END Error;

		PROCEDURE Warning*(CONST source : ARRAY OF CHAR; position : Streams.Position; CONST message : ARRAY OF CHAR);
		END Warning;

		PROCEDURE Information*(CONST source : ARRAY OF CHAR; position : Streams.Position; CONST message : ARRAY OF CHAR);
		END Information;

	END Diagnostics;

TYPE

	Entry* = POINTER TO RECORD
		type*: INTEGER;
		source*: ARRAY 128 OF CHAR;
		position*: Streams.Position;
		message*: ARRAY 256 OF CHAR;
		next*: Entry;
	END;

	EntryArray* = POINTER TO ARRAY OF Entry;

	EnumProc* = PROCEDURE {DELEGATE} (e : Entry);

TYPE

	DiagnosticsList* = OBJECT(Diagnostics)
	VAR
		(* Intended for subclassing only *)
		entries- : Entry;

		nofErrors- : SIZE;
		nofWarnings- : SIZE;
		nofInformations- : SIZE;

		nofMessages- : SIZE;

		PROCEDURE Error*(CONST source : ARRAY OF CHAR; position : Streams.Position; CONST message : ARRAY OF CHAR);
		BEGIN {EXCLUSIVE}
			InsertSorted(TypeError, source, position, message, nofErrors)
		END Error;

		PROCEDURE Warning*(CONST source : ARRAY OF CHAR; position : Streams.Position; CONST message : ARRAY OF CHAR);
		BEGIN {EXCLUSIVE}
			InsertSorted(TypeWarning, source, position, message, nofWarnings);
		END Warning;

		PROCEDURE Information*(CONST source : ARRAY OF CHAR; position : Streams.Position; CONST message : ARRAY OF CHAR);
		BEGIN {EXCLUSIVE}
			InsertSorted(TypeInformation, source, position, message, nofInformations);
		END Information;

		PROCEDURE ToStream*(w : Streams.Writer; mask : SET);
		VAR entry : Entry;
		BEGIN {EXCLUSIVE}
			ASSERT(w # NIL);
			entry := entries;
			WHILE (entry # NIL) DO
				IF (entry.type IN mask) THEN
					Print (w, entry.source, entry.position, entry.type, entry.message);
				END;
				entry := entry.next;
			END;
		END ToStream;

		PROCEDURE &Reset*;
		BEGIN {EXCLUSIVE}
			entries := NIL;
			nofErrors := 0; nofWarnings := 0; nofInformations := 0;
			nofMessages := 0;
		END Reset;

		PROCEDURE ForAll*(proc : EnumProc);
		VAR e : Entry;
		BEGIN {EXCLUSIVE}
			ASSERT(proc # NIL);
			e := entries;
			WHILE (e # NIL) DO
				proc(e);
				e := e.next;
			END;
		END ForAll;

		PROCEDURE GetEntries*() : EntryArray;
		VAR e : Entry; result : EntryArray; nofEntries, i : SIZE;
		BEGIN {EXCLUSIVE}
			result := NIL;
			nofEntries := nofErrors + nofWarnings + nofInformations;
			IF (nofEntries > 0) THEN
				NEW(result, nofEntries);
				e := entries; i := 0;
				WHILE (e # NIL) DO
					result[i] := e; INC(i);
					e := e.next;
				END;
			END;
			RETURN result;
		END GetEntries;

		PROCEDURE InsertSorted(type: INTEGER; CONST source : ARRAY OF CHAR; position : Streams.Position; CONST message : ARRAY OF CHAR; VAR counter: SIZE);
		VAR prev, entry : Entry;
		BEGIN
			entry := entries; prev := NIL;
			WHILE (entry # NIL) & (entry.position <= position) DO prev := entry; entry := entry.next END;
			IF (entry = NIL) OR (entry.type # type) OR (entry.position # position) OR (entry.message # message) THEN
				INC(nofMessages); INC (counter);
				entry := NewEntry (type, source, position, message, entry);
				IF prev = NIL THEN entries := entry ELSE prev.next := entry END
			END
		END InsertSorted;

		PROCEDURE NewEntry*(type: INTEGER; CONST source : ARRAY OF CHAR; position : Streams.Position; CONST message : ARRAY OF CHAR; next: Entry) : Entry;
		VAR entry : Entry;
		BEGIN
			NEW(entry);
			entry.type := type;
			COPY (source, entry.source);
			entry.position := position;
			COPY (message, entry.message);
			entry.next := next;
			RETURN entry;
		END NewEntry;

	END DiagnosticsList;

TYPE

	StreamDiagnostics* = OBJECT (Diagnostics);
	VAR
		writer: Streams.Writer;

		PROCEDURE &Init *(w: Streams.Writer);
		BEGIN
			ASSERT(w # NIL);
			writer := w;
		END Init;

		PROCEDURE Error* (CONST source : ARRAY OF CHAR; position : Streams.Position; CONST message : ARRAY OF CHAR);
		BEGIN Print (writer, source, position, TypeError, message);
		END Error;

		PROCEDURE Warning* (CONST source : ARRAY OF CHAR; position : Streams.Position; CONST message : ARRAY OF CHAR);
		BEGIN Print (writer, source, position, TypeWarning, message);
		END Warning;

		PROCEDURE Information* (CONST source : ARRAY OF CHAR; position : Streams.Position; CONST message : ARRAY OF CHAR);
		BEGIN Print (writer, source, position, TypeInformation, message);
		END Information;

	END StreamDiagnostics;

PROCEDURE Print (w: Streams.Writer; CONST source : ARRAY OF CHAR; position: Streams.Position; type: INTEGER; CONST message: ARRAY OF CHAR);
BEGIN
	w.Char(9X);
	IF (source # "") THEN w.String (source); END;
	IF (position # Streams.Invalid) THEN w.Char ('@'); w.Int(position, 0); END;
	w.String(": ");
	IF (type = TypeWarning) THEN
		w.String("warning");
	ELSIF (type = TypeError) THEN
		w.String("error");
	END;
	IF (type # TypeInformation) THEN w.String(": ") END;
	w.String(message); w.Ln;
	w.Update;
END Print;

END Diagnostics.
