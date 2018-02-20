MODULE XMLObjects; (** AUTHOR "swalthert"; PURPOSE "XML collections and enumerators"; *)

IMPORT
	Strings;


TYPE
	String = Strings.String;

	Collection* = OBJECT

		PROCEDURE GetNumberOfElements*(): LONGINT;
		BEGIN
			RETURN 0
		END GetNumberOfElements;

		PROCEDURE GetEnumerator*(): Enumerator;
		BEGIN
			RETURN NIL
		END GetEnumerator;

		PROCEDURE Add*(p: ANY);
		END Add;

		PROCEDURE Remove*(p: ANY);
		END Remove;

	END Collection;

	ListElem = OBJECT
	VAR
		elem: ANY;
		next: ListElem;

		PROCEDURE &Init*(elem : ANY);
		BEGIN
			SELF.elem := elem;
			next := NIL;
		END Init;

	END ListElem;

	List* = OBJECT (Collection)
	VAR
		first, last: ListElem;
		nofElems: LONGINT;

		PROCEDURE & Init*;
		BEGIN
			nofElems := 0
		END Init;

		PROCEDURE GetNumberOfElements*(): LONGINT;
		BEGIN
			RETURN nofElems
		END GetNumberOfElements;

		PROCEDURE GetEnumerator*(): Enumerator;
		VAR le: ListEnumerator;
		BEGIN
			NEW(le, SELF);
			RETURN le
		END GetEnumerator;

		PROCEDURE Add*(p: ANY);
		VAR newListElem: ListElem;
		BEGIN {EXCLUSIVE}
			IF p # NIL THEN
				NEW(newListElem, p);
				IF last = NIL THEN
					first := newListElem;
					last := newListElem
				ELSE
					last.next := newListElem;
					last := last.next
				END;
				INC(nofElems)
			END
		END Add;

		PROCEDURE Remove*(p: ANY);
		VAR le: ListElem;
		BEGIN {EXCLUSIVE}
			IF (p # NIL) & (first # NIL) THEN
				IF first.elem = p THEN
					first := first.next; DEC(nofElems)
				ELSE
					le := first;
					WHILE (le.next # NIL) & (le.next.elem # p) DO
						le := le.next
					END;
					IF le.next # NIL THEN (* le.next.elem = o *)
						le.next := le.next.next; DEC(nofElems)
					END
				END
			END
		END Remove;

	END List;

	PTRArray* = POINTER TO ARRAY OF ANY;

	ArrayCollection* = OBJECT (Collection)
	VAR
		elems: PTRArray;
		nofElems: LONGINT;

		PROCEDURE  &Init*;
		BEGIN
			nofElems := 0;
			NEW(elems, 1)
		END Init;

		PROCEDURE GetNumberOfElements*(): LONGINT;
		BEGIN
			RETURN nofElems
		END GetNumberOfElements;

		PROCEDURE GetEnumerator*(): Enumerator;
		VAR ace: ArrayEnumerator;
		BEGIN
			NEW(ace, elems);
			RETURN ace
		END GetEnumerator;

		PROCEDURE Grow;
		VAR i: LONGINT; oldElems: PTRArray;
		BEGIN
			oldElems := elems;
			NEW(elems, 2 * LEN(elems));
			FOR i := 0 TO nofElems - 1 DO
				elems[i] := oldElems[i]
			END
		END Grow;

		PROCEDURE Add*(p: ANY);
		BEGIN {EXCLUSIVE}
			IF p # NIL THEN
				IF nofElems = LEN(elems) THEN Grow() END;
				elems[nofElems] := p;
				INC(nofElems)
			END
		END Add;

		PROCEDURE Remove*(p: ANY);
		VAR i: LONGINT;
		BEGIN {EXCLUSIVE}
			i := 0;
			WHILE (i < nofElems) & (elems[i] # p) DO
				INC(i)
			END;
			IF i < nofElems THEN
				WHILE (i < nofElems - 1) DO
					elems[i] := elems[i + 1]; INC(i)
				END;
				DEC(nofElems); elems[nofElems] := NIL
			END
		END Remove;

		PROCEDURE GetElement*(i: LONGINT): ANY;
		BEGIN
			IF (0 <= i) & (i < nofElems) THEN RETURN elems[i]
			ELSE RETURN NIL
			END
		END GetElement;

		PROCEDURE Invert*(ptr1, ptr2: ANY): BOOLEAN;
           	VAR pos1, pos2, i: LONGINT; ptr: ANY;
       	BEGIN {EXCLUSIVE}
           		i := 0;  pos1 := -1;  pos2 := -1;
          		 WHILE (i < nofElems) & ((pos1 < 0) OR (pos2 < 0)) DO
              		 IF elems[i] = ptr1 THEN  pos1 := i  END;
              		 IF elems[i] = ptr2 THEN  pos2 := i  END;
              		 INC(i)
          		 END;
           		IF (pos1 >= 0) & (pos2 >= 0) & (pos1 # pos2)  THEN
               		ptr := elems[pos1];  elems[pos1] := elems[pos2];  elems[pos2] := ptr;
               		RETURN TRUE
           		END;
           		RETURN FALSE
       	END Invert;

		PROCEDURE GetElementPos*(ptr: ANY): LONGINT;
           	VAR i: LONGINT;
		BEGIN
          		 WHILE i < nofElems DO
              		 IF elems[i] = ptr THEN  RETURN i END;
              		 INC(i)
          		 END;
          		 RETURN -1
		END GetElementPos;

		PROCEDURE MoveUp*(ptr: ANY;  i: LONGINT): BOOLEAN;
           	VAR p: ANY;
       	BEGIN {EXCLUSIVE}
           		IF ptr # NIL THEN  i := GetElementPos(ptr)  END;
           		IF (i > 0) & (i < nofElems)  THEN
               		p := elems[i];  elems[i] := elems[i-1];  elems[i-1] := p;
               		RETURN TRUE
           		END;
           		RETURN FALSE
       	END MoveUp;

		PROCEDURE MoveDown*(ptr: ANY;  i: LONGINT): BOOLEAN;
           	VAR p: ANY;
       	BEGIN {EXCLUSIVE}
           		IF ptr # NIL THEN  i := GetElementPos(ptr)  END;
           		IF (i >=0) & (i < nofElems-1)  THEN
               		p := elems[i];  elems[i] := elems[i+1];  elems[i+1] := p;
               		RETURN TRUE
           		END;
           		RETURN FALSE
       	END MoveDown;

	END ArrayCollection;

	Enumerator* = OBJECT

		PROCEDURE HasMoreElements*(): BOOLEAN;
		BEGIN
			RETURN FALSE
		END HasMoreElements;

		PROCEDURE GetNext*(): ANY;
		BEGIN
			RETURN NIL
		END GetNext;

		PROCEDURE Reset*;
		END Reset;

	END Enumerator;

	ListEnumerator* = OBJECT (Enumerator)
	VAR
		coll: List;
		current: ListElem;

		PROCEDURE & Init*(list: List);
		BEGIN
			coll := list;
			current := list.first
		END Init;

		PROCEDURE HasMoreElements*(): BOOLEAN;
		BEGIN
			RETURN current # NIL
		END HasMoreElements;

		PROCEDURE GetNext*(): ANY;
		VAR p: ANY;
		BEGIN
			IF HasMoreElements() THEN p := current.elem; current := current.next; ELSE p := NIL; END;
			RETURN p
		END GetNext;

		PROCEDURE Reset*;
		BEGIN
			Init(coll)
		END Reset;

	END ListEnumerator;

	ArrayEnumerator* = OBJECT (Enumerator)
	VAR
		array: PTRArray;
		current: LONGINT;

		PROCEDURE & Init*(array: PTRArray);
		BEGIN
			SELF.array := array;
			current := 0
		END Init;

		PROCEDURE HasMoreElements*(): BOOLEAN;
		BEGIN
			RETURN (current < LEN(array)) & (array[current] # NIL)
		END HasMoreElements;

		PROCEDURE GetNext*(): ANY;
		VAR p: ANY;
		BEGIN
			IF HasMoreElements() THEN
				p := array[current]; INC(current);
			ELSE
				p := NIL;
			END;
			RETURN p
		END GetNext;

		PROCEDURE Reset*;
		BEGIN
			Init(array)
		END Reset;

	END ArrayEnumerator;

	Dictionary* = OBJECT

		PROCEDURE GetNumberOfElements*(): LONGINT;
		BEGIN
			RETURN 0
		END GetNumberOfElements;

		PROCEDURE Get*(key: ARRAY OF CHAR): ANY;
		END Get;

		PROCEDURE GetEnumerator*(): Enumerator;
		BEGIN
			RETURN NIL
		END GetEnumerator;

		PROCEDURE Add*(key: ARRAY OF CHAR; p: ANY);
		END Add;

		PROCEDURE Remove*(key: ARRAY OF CHAR);
		END Remove;

	END Dictionary;

	StringArray = POINTER TO ARRAY OF String;

	ArrayDict* = OBJECT (Dictionary)
	VAR
		nofElems: LONGINT;
		keys: StringArray;
		elems: PTRArray;

		PROCEDURE & Init*;
		BEGIN
			nofElems := 0;
			NEW(keys, 16);
			NEW(elems, 16)
		END Init;

		PROCEDURE GetNumberOfElements*(): LONGINT;
		BEGIN
			RETURN nofElems
		END GetNumberOfElements;

		PROCEDURE Get*(key: ARRAY OF CHAR): ANY;
		VAR i: LONGINT;
		BEGIN
			i := 0;
			WHILE (i < nofElems) & (keys[i]^ # key) DO
				INC(i)
			END;
			IF i < nofElems THEN RETURN elems[i]
			ELSE RETURN NIL
			END
		END Get;

		PROCEDURE GetEnumerator*(): Enumerator;
		VAR ace: ArrayEnumerator;
		BEGIN
			NEW(ace, elems);
			RETURN ace
		END GetEnumerator;

		PROCEDURE Grow;
		VAR i: LONGINT; oldKeys: StringArray; oldElems: PTRArray;
		BEGIN
			oldKeys := keys; oldElems := elems;
			NEW(keys, 2 * LEN(keys)); NEW(elems, 2 * LEN(elems));
			FOR i := 0 TO nofElems - 1 DO
				keys[i] := oldKeys[i]; elems[i] := oldElems[i]
			END
		END Grow;

		PROCEDURE Add*(key: ARRAY OF CHAR; p: ANY);
		BEGIN {EXCLUSIVE}
			IF Get(key) = NIL THEN
				IF nofElems = LEN(elems) THEN Grow() END;
				NEW(keys[nofElems], StringLength(key) + 1); COPY(key, keys[nofElems]^);
				elems[nofElems] := p;
				INC(nofElems)
			END
		END Add;

		PROCEDURE Remove*(key: ARRAY OF CHAR);
		VAR i: LONGINT;
		BEGIN {EXCLUSIVE}
			i := 0;
			WHILE (i < nofElems) & (keys[i]^ # key) DO
				INC(i)
			END;
			IF i < nofElems THEN
				WHILE (i < nofElems - 1) DO
					elems[i] := elems[i + 1];
					keys[i] := keys[i + 1];
					INC(i)
				END;
				DEC(nofElems); keys[nofElems] := NIL; elems[nofElems] := NIL
			END
		END Remove;

	END ArrayDict;

PROCEDURE StringLength(CONST string: ARRAY OF CHAR): LONGINT;
VAR i, l: LONGINT;
BEGIN
	i := 0; l := LEN(string);
	WHILE (i < l) & (string[i] # 0X) DO
		INC(i)
	END;
	RETURN i
END StringLength;

END XMLObjects.