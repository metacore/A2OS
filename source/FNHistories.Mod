MODULE FNHistories; (** AUTHOR "Fabian Nart"; PURPOSE "Unbounded general-purpose history datastructure"; *)

IMPORT
	KernelLog;
TYPE
	HistoryItem = POINTER TO RECORD
		item : ANY;
		previous, next : HistoryItem
	END;

	History* = OBJECT
	VAR
		start, current : HistoryItem;

		PROCEDURE & Init*;
		BEGIN
			start := NIL;
			current := NIL
		END Init;

		(** return TRUE if no items have been inserted yet *)
		PROCEDURE IsEmpty*() : BOOLEAN;
		BEGIN
			RETURN current = NIL
		END IsEmpty;

		(** insert new item as current *)
		PROCEDURE Insert*(item : ANY);
		VAR new : HistoryItem;
		BEGIN
			NEW(new);
			new.item := item;
			new.previous := current;
			IF IsEmpty() THEN
				start := new;
			ELSE
				current.next := new;
			END;
			current := new
		END Insert;

		(** get current item in history or NIL if there is no current one *)
		PROCEDURE GetCurrent*() : ANY;
		BEGIN
			IF IsEmpty() THEN
				RETURN NIL
			ELSE
				RETURN current.item
			END
		END GetCurrent;

		(** turn history one step back. return FALSE if there is no previous item.*)
		PROCEDURE Back*() : BOOLEAN;
		BEGIN
			IF (current = NIL) OR (current.previous = NIL) THEN
				RETURN FALSE
			ELSE
				current := current.previous;
				RETURN TRUE
			END
		END Back;

		(** turn history back as many steps as necessairy to make item the current one. return FALSE if item cannot be found *)
		PROCEDURE BackTo*(item : ANY) : BOOLEAN;
		BEGIN
			WHILE current # NIL DO
				IF current.item = item THEN RETURN TRUE END;
				current := current.previous
			END;
			RETURN FALSE
		END BackTo;

		(** turn history one step forward. return FALSE if current item is the latest one *)
		PROCEDURE Forward*() : BOOLEAN;
		BEGIN
			IF (current = NIL) OR (current.next = NIL) THEN
				RETURN FALSE
			ELSE
				current := current.next;
				RETURN TRUE
			END
		END Forward;

		(** turn history forward as many steps as necessairy to make item the current one. return FALSE if item cannot be found *)
		PROCEDURE ForwardTo*(item : ANY) : BOOLEAN;
		BEGIN
			WHILE current # NIL DO
				IF current.item = item THEN RETURN TRUE END;
				current := current.next
			END;
			RETURN FALSE
		END ForwardTo;

		PROCEDURE Dump*;
		VAR i : SIGNED32;
			p : HistoryItem;
		BEGIN
			i := 0;
			p := current;
			WHILE p # NIL DO
				KernelLog.String("[");
				IF p.item = NIL THEN KernelLog.String("NIL") ELSE KernelLog.String("item") END;
				KernelLog.String("] --> ");
				p := p.previous;
				INC(i)
			END;
			KernelLog.String("start -- ");
			KernelLog.Int(i, 0); KernelLog.String(" items in the history"); KernelLog.Ln;
		END Dump;

	END History;
END FNHistories.
