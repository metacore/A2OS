MODULE TVChannels;	(** AUTHOR "oljeger@student.ethz.ch"; PURPOSE "List of TV channels *)

IMPORT
	Files, XMLScanner, XMLParser, XML, XMLObjects, Dates, Strings, Clock;

CONST
	ChannelFile* = "TVChannels.XML";
	MaxAge = 180;	(* minutes *)	(* Maximum age for teletext data to be treated as "recent" *)

TYPE
	TVChannel* = OBJECT
		VAR
			name*: ARRAY 33 OF CHAR;
			freq*: SIGNED32;
			hasTeletext*: BOOLEAN;
			cachingTime*: Dates.DateTime;

		PROCEDURE &Init*;
		BEGIN
			hasTeletext := TRUE
		END Init;

		(** Does the current channel have "recent" teletext data? (see MaxAge) *)
		PROCEDURE HasRecentData*() : BOOLEAN;
		VAR
			dNow, tNow, dCache, tCache, hmNow, hmCache: SIGNED32;
		BEGIN
			IF ~Dates.ValidDateTime(cachingTime) THEN
				RETURN FALSE
			END;
			Clock.Get(tNow, dNow);
			Dates.DateTimeToOberon(cachingTime, dCache, tCache);
			(* Date must be identical *)
			IF dNow # dCache THEN
				RETURN FALSE
			END;
			hmNow := tNow DIV 64;
			hmCache := tCache DIV 64;
			RETURN hmCache > (hmNow - MaxAge);
		END HasRecentData;
	END TVChannel;

	ChannelArray = POINTER TO ARRAY OF TVChannel;

	(** Lockable Object List. *)
	ChannelList* = OBJECT
		VAR
			list : ChannelArray;
			count : SIZE;
			readLock : SIZE;

		PROCEDURE &New*;
		BEGIN NEW(list, 8); readLock := 0
		END New;

		(** return the number of objects in the list. If count is used for indexing elements (e.g. FOR - Loop) in a multi-process
			situation, the process calling the GetCount method should call Lock before GetCount and Unlock after the
			last use of an index based on GetCount *)
		PROCEDURE GetCount*():SIZE;
		BEGIN
			RETURN count
		END GetCount;

		PROCEDURE Grow;
		VAR old: ChannelArray;
				i : SIZE;
		BEGIN
			old := list;
			NEW(list, LEN(list)*2);
			FOR i := 0 TO count-1 DO list[i] := old[i] END
		END Grow;

		(** Add an object to the list. Add may block if number of calls to Lock is bigger than the number of calls to Unlock *)
		PROCEDURE Add*(x : TVChannel);
		BEGIN {EXCLUSIVE}
			AWAIT(readLock = 0);
			IF count = LEN(list) THEN Grow END;
			list[count] := x;
			INC(count)
		END Add;

		(** return the index of an object. In a multi-process situation, the process calling the IndexOf method should
			call Lock before IndexOf and Unlock after the last use of an index based on IndexOf.
			If the object is not found, -1 is returned *)
		PROCEDURE IndexOf *(x: TVChannel) : SIZE;
		VAR i : SIZE;
		BEGIN
			i := 0 ; WHILE i < count DO IF list[i] = x THEN RETURN i END; INC(i) END;
			RETURN -1
		END IndexOf;

		(** Remove an object from the list. Remove may block if number of calls to Lock is bigger than the number of calls to Unlock *)
		PROCEDURE Remove*(x : TVChannel);
		VAR i : SIZE;
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
		VAR i : SIZE;
		BEGIN {EXCLUSIVE}
			AWAIT(readLock = 0);
			FOR i := 0 TO count - 1 DO list[i] := NIL END;
			count := 0
		END Clear;

		(** return an object based on an index. In a multi-process situation, GetItem is only safe in a locked region Lock / Unlock *)
		PROCEDURE GetItem*(i: SIZE) : TVChannel;
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
	END ChannelList;

VAR
	(** Globally accessible list that contains all available channel names together with their frequency *)
	channels*: ChannelList;

(** Load TV channels from a file *)
PROCEDURE LoadChannelTable* (filename: ARRAY OF CHAR);
VAR
	f: Files.File; reader: Files.Reader;
	scanner: XMLScanner.Scanner; parser: XMLParser.Parser;
	xmlChannels : XML.Document; enum: XMLObjects.Enumerator;
	e : XML.Element; s : XML.String;
	p : ANY;
	ch : TVChannel;
BEGIN
	IF channels = NIL THEN
		NEW(channels)
	END;
	channels.Clear;
	xmlChannels := NIL;
	f := Files.Old (filename);
	IF f # NIL THEN
		NEW(reader, f, 0);
		NEW(scanner, reader);
		NEW(parser, scanner);
		xmlChannels := parser.Parse();
		IF xmlChannels # NIL THEN
			e := xmlChannels.GetRoot();
			enum := e.GetContents();
			WHILE enum.HasMoreElements() DO
				p := enum.GetNext();
				IF p IS XML.Element THEN
					e := p(XML.Element);
					s := e.GetName();
					IF (s # NIL) & (s^ = "Channel") THEN
						NEW(ch);
						(* read channel name *)
						s := e.GetAttributeValue ("name");
						IF s # NIL THEN
							COPY (s^, ch.name)
						END;
						(* read TV frequency *)
						s := e.GetAttributeValue ("freq");
						IF s # NIL THEN
							Strings.StrToInt (s^, ch.freq)
						END;
						(* read optional teletext attribute *)
						s := e.GetAttributeValue ("teletext");
						IF (s # NIL) & (s^ = "false") THEN
							ch.hasTeletext := FALSE
						END;
						channels.Add (ch)
					END
				END
			END
		END
	END
END LoadChannelTable;

BEGIN
	NEW(channels);
	LoadChannelTable(ChannelFile)
END TVChannels.
