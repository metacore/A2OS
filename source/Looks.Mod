MODULE Looks;	(** AUTHOR "ug"; PURPOSE "List of Looks - either skins or backdrops" *)

IMPORT
	Files, XMLScanner, XMLParser, XML, XMLObjects;


TYPE
	Look* = OBJECT
	VAR name-: ARRAY 80 OF CHAR;
		file-: ARRAY 160 OF CHAR;
	END Look;

	LookArray = POINTER TO ARRAY OF Look;

	(** Lockable Object List. *)
	LookList* = OBJECT
		VAR
			list : LookArray;
			count : SIGNED32;
			readLock : SIGNED32;

		PROCEDURE &New*;
		BEGIN NEW(list, 8); readLock := 0
		END New;

		(** return the number of objects in the list. If count is used for indexing elements (e.g. FOR - Loop) in a multi-process
			situation, the process calling the GetCount method should call Lock before GetCount and Unlock after the
			last use of an index based on GetCount *)
		PROCEDURE GetCount*():SIGNED32;
		BEGIN
			RETURN count
		END GetCount;

		PROCEDURE Grow;
		VAR old: LookArray;
				i : SIGNED32;
		BEGIN
			old := list;
			NEW(list, LEN(list)*2);
			FOR i := 0 TO count-1 DO list[i] := old[i] END
		END Grow;

		(** Add an object to the list. Add may block if number of calls to Lock is bigger than the number of calls to Unlock *)
		PROCEDURE Add*(x : Look);
		BEGIN {EXCLUSIVE}
			AWAIT(readLock = 0);
			IF count = LEN(list) THEN Grow END;
			list[count] := x;
			INC(count)
		END Add;

		(** return the index of an object. In a multi-process situation, the process calling the IndexOf method should
			call Lock before IndexOf and Unlock after the last use of an index based on IndexOf.
			If the object is not found, -1 is returned *)
		PROCEDURE IndexOf *(x: Look) : SIGNED32;
		VAR i : SIGNED32;
		BEGIN
			i := 0 ; WHILE i < count DO IF list[i] = x THEN RETURN i END; INC(i) END;
			RETURN -1
		END IndexOf;

		(** Remove an object from the list. Remove may block if number of calls to Lock is bigger than the number of calls to Unlock *)
		PROCEDURE Remove*(x : Look);
		VAR i : SIGNED32;
		BEGIN {EXCLUSIVE}
			AWAIT(readLock = 0);
			i:=0; WHILE (i<count) & (list[i]#x) DO INC(i) END;
			IF i<count THEN
				WHILE (i<count-1) DO list[i]:=list[i+1]; INC(i) END;
				DEC(count);
				list[count]:=NIL
			END
		END Remove;

		(** Removes all objects from the list. Clear may block if number of calls to Lock is bigger than the number of calls to Unlock *)
		PROCEDURE Clear*;
		VAR i : SIGNED32;
		BEGIN {EXCLUSIVE}
			AWAIT(readLock = 0);
			FOR i := 0 TO count - 1 DO list[i] := NIL END;
			count := 0
		END Clear;

		(** return an object based on an index. In a multi-process situation, GetItem is only safe in a locked region Lock / Unlock *)
		PROCEDURE GetItem*(i:SIGNED32) : Look;
		BEGIN
			ASSERT((i >= 0) & (i < count), 101);
			RETURN list[i]
		END GetItem;

		(** Lock prevents modifications to the list. All calls to Lock must be followed by a call to Unlock. Lock can be nested*)
		PROCEDURE Lock*;
		BEGIN {EXCLUSIVE}
			INC(readLock); ASSERT(readLock > 0)
		END Lock;

		(** Unlock removes one modification lock. All calls to Unlock must be preceeded by a call to Lock. *)
		PROCEDURE Unlock*;
		BEGIN {EXCLUSIVE}
			DEC(readLock); ASSERT(readLock >= 0)
		END Unlock;

	END LookList;


(** Load looks from a file *)
PROCEDURE LoadLooks* (CONST filename: ARRAY OF CHAR; VAR looks : LookList);
VAR
	f: Files.File; reader: Files.Reader;
	scanner: XMLScanner.Scanner; parser: XMLParser.Parser;
	xmlLooks : XML.Document; enum: XMLObjects.Enumerator;
	e : XML.Element; s : XML.String;
	p : ANY;
	l : Look;
BEGIN
	IF looks = NIL THEN
		NEW(looks)
	END;
	looks.Clear;
	xmlLooks := NIL;
	f := Files.Old (filename);
	IF f # NIL THEN
		NEW(reader, f, 0);
		NEW(scanner, reader);
		NEW(parser, scanner);
		xmlLooks := parser.Parse();
		IF xmlLooks # NIL THEN
			e := xmlLooks.GetRoot();
			enum := e.GetContents();
			WHILE enum.HasMoreElements() DO
				p := enum.GetNext();
				IF p IS XML.Element THEN
					e := p(XML.Element);
					s := e.GetName();
					IF (s # NIL) & (s^ = "Look") THEN
						NEW(l);
						(* read look name *)
						s := e.GetAttributeValue ("name");
						IF s # NIL THEN
							COPY (s^, l.name)
						END;
						(* read look file *)
						s := e.GetAttributeValue ("file");
						IF s # NIL THEN
							COPY(s^, l.file)
						END;
						looks.Add (l)
					END
				END
			END
		END
	END
END LoadLooks;


END Looks.
