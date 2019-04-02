MODULE Attributes; (** AUTHOR "staubesv"; PURPOSE "Associate attributes with objects"; *)

CONST

	Invalid = -1;
	InitialAttributeArraySize = 16;

TYPE

	(** Attributes associated with <object> *)
	Attribute* = RECORD
		object : ANY;
		flags- : SET;
		data- : ANY;
	END;

	AttributeArray = POINTER TO ARRAY OF Attribute;

TYPE

	(**
		Manage relationship between objects and attributes. Objects are only
		stored if there are flags or data associated to it.

		Notes:
			- not thread-safe
			- no trick implementation only suited for small number of objects
			- if needed, objects can be pinned be the use of a flag dedicated to this purpose
	*)
	Attributes* = OBJECT
	VAR
		attributes : AttributeArray;
		nofAttributes : LONGINT;

		PROCEDURE &Init*; (* private *)
		BEGIN
			attributes := NIL;
			nofAttributes := 0;
		END Init;

		PROCEDURE ResizeArrayIfNecessary; (* private *)
		VAR newAttributes : AttributeArray; i : LONGINT;
		BEGIN
			IF (attributes = NIL) THEN
				ASSERT(nofAttributes = 0);
				NEW(attributes, InitialAttributeArraySize);
			ELSIF (nofAttributes >= LEN(attributes)) THEN
				NEW(newAttributes, 2 * LEN(attributes));
				FOR i := 0 TO nofAttributes - 1 DO newAttributes[i] := attributes[i]; END;
			END;
		END ResizeArrayIfNecessary;

		(* Add <object> to array *)
		PROCEDURE AddObject(object : ANY; flags : SET; data : ANY); (* private *)
		BEGIN
			(* caller must ensure to not add duplicate nodes! *)
			ASSERT((object # NIL) & ((flags # {}) OR (data # NIL)));
			ResizeArrayIfNecessary;
			attributes[nofAttributes].object := object;
			attributes[nofAttributes].flags := flags;
			attributes[nofAttributes].data := data;
			INC(nofAttributes);
		END AddObject;

		(*	Remove <object> from array. If hint is not <Invalid>, hint is the index of the object.
			<object> must be contained in array! *)
		PROCEDURE RemoveObject(object : ANY; hint : LONGINT); (* private *)
		VAR index, i : LONGINT;
		BEGIN
			ASSERT((object # NIL) & ((hint = Invalid) OR (attributes[hint].object = object)));
			index := hint;
			IF (index = Invalid) THEN index := GetIndexOf(object); END;
			ASSERT(index # Invalid);
			IF (index = nofAttributes - 1) THEN
				attributes[index].object := NIL;
				attributes[index].flags := {};
				attributes[index].data := NIL;
			ELSE
				ASSERT(attributes[nofAttributes-1].object = NIL);
				FOR i := index TO nofAttributes-2 DO
					attributes[i] := attributes[i + 1];
				END;
			END;
			DEC(nofAttributes);
		END RemoveObject;

		(* Return index of node, <Invalid> if not found *)
		PROCEDURE GetIndexOf(object : ANY) : LONGINT; (* private *)
		VAR index : LONGINT;
		BEGIN
			ASSERT(object # NIL);
			index := 0;
			WHILE (index < nofAttributes) & (attributes[index].object # object) DO INC(index); END;
			IF (index = nofAttributes) THEN index := Invalid; END;
			ASSERT((index = Invalid) OR ((0 <= index) & (index < nofAttributes) & (attributes[index].object = object)));
			RETURN index;
		END GetIndexOf;

		(** Get flags and data associated to object <object> *)
		PROCEDURE Get*(object : ANY) : Attribute;
		VAR attribute : Attribute; index : LONGINT;
		BEGIN
			ASSERT(object # NIL);
			index := GetIndexOf(object);
			IF (index # Invalid) THEN
				attribute := attributes[index];
			ELSE
				attribute.flags := {};
				attribute.data := NIL;
			END;
			RETURN attribute;
		END Get;

		(** Set flags and data associated to object <object> *)
		PROCEDURE Set*(object : ANY; flags : SET; data : ANY);
		VAR index : LONGINT;
		BEGIN
			ASSERT(object # NIL);
			index := GetIndexOf(object);
			IF (index # Invalid) THEN
				IF (flags # {}) OR (data # NIL) THEN
					attributes[index].flags := flags;
					attributes[index].data := data;
				ELSE
					RemoveObject(object, index);
				END;
			ELSIF (flags # {}) OR (data # NIL) THEN
				AddObject(object, flags, data);
			END;
		END Set;

		(** Get flags associated to object <object> *)
		PROCEDURE GetFlags*(object : ANY) : SET;
		VAR flags : SET; index : LONGINT;
		BEGIN
			ASSERT(object # NIL);
			flags := {};
			index := GetIndexOf(object);
			IF (index # Invalid) THEN flags := attributes[index].flags; END;
			RETURN flags;
		END GetFlags;

		(** Set flags associated to object <object> *)
		PROCEDURE SetFlags*(object : ANY; flags : SET);
		VAR index : LONGINT;
		BEGIN
			ASSERT(object # NIL);
			index := GetIndexOf(object);
			IF (index # Invalid) THEN
				IF (flags # {}) THEN
					attributes[index].flags := flags;
				ELSIF (attributes[index].data = NIL) THEN
					RemoveObject(object, index);
				END;
			ELSIF (flags # {}) THEN
				AddObject(object, flags, NIL);
			END;
		END SetFlags;

		(** Include a flag associated to object <object> *)
		PROCEDURE Include*(object : ANY; flag : LONGINT);
		VAR index : LONGINT;
		BEGIN
			ASSERT((object # NIL) & (0 <= flag) & (flag <= MAX(SET)));
			index := GetIndexOf(object);
			IF (index # Invalid) THEN
				INCL(attributes[index].flags, flag);
			ELSE
				AddObject(object, {flag}, NIL);
			END;
		END Include;

		(** Exclude a flag associated to <object> *)
		PROCEDURE Exclude*(object : ANY; flag : LONGINT);
		VAR index : LONGINT;
		BEGIN
			ASSERT((object # NIL) & (0 <= flag) & (flag <= MAX(SET)));
			index := GetIndexOf(object);
			IF (index # Invalid) THEN
				EXCL(attributes[index].flags, flag);
				IF (attributes[index].flags = {}) THEN RemoveObject(object, index); END;
			END;
		END Exclude;

		(** Get data associated to object <object> *)
		PROCEDURE GetData*(object : ANY) : ANY;
		VAR data : ANY; index : LONGINT;
		BEGIN
			ASSERT(object # NIL);
			data := NIL;
			index := GetIndexOf(object);
			IF (index # Invalid) THEN data := attributes[index].data; END;
			RETURN data;
		END GetData;

		(** Set data associated to object <object> *)
		PROCEDURE SetData*(object, data : ANY);
		VAR index : LONGINT;
		BEGIN
			ASSERT(object # NIL);
			index := GetIndexOf(object);
			IF (index # Invalid) THEN
				IF (data # NIL) THEN
					attributes[index].data := data;
				ELSIF (attributes[index].flags = {}) THEN
					RemoveObject(object, index);
				END;
			ELSE
				AddObject(object, {}, data);
			END;
		END SetData;

		(** Clear all flags / data *)
		PROCEDURE Clear*;
		BEGIN
			attributes := NIL;
			nofAttributes := 0;
		END Clear;

	END Attributes;

END Attributes.
