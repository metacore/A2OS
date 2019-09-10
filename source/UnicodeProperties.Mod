MODULE UnicodeProperties; (** AUTHOR "gubsermi"; PURPOSE "Reading the Unicode.txt file and interpreting the properties"; *)

IMPORT
	Texts, Codecs, Files, Streams, KernelLog, Strings;

CONST
	NUL*	= 00H;
	EOT*	= 04H;
	LF*		= 0AH;
	CR*		= 0DH;
	SP*		= 20H;

	CacheDebugging = FALSE;


VAR
	error- : BOOLEAN;



TYPE
	(* Caches a result from the property files. Can be used for a string or a character value, but not both! *)
	CacheElement = OBJECT
	VAR
		next : CacheElement;
		key : Texts.Char32;
		sValue : ARRAY 256 OF CHAR;
		cValue : Texts.Char32;

		(* Initializes a CacheElement with a key and a value *)
		PROCEDURE &Init*(key : Texts.Char32; CONST sValue : ARRAY OF CHAR; cValue : Texts.Char32);
		BEGIN
			SELF.key := key;
			IF sValue[0] # CHR(0H) THEN
				Strings.Copy(sValue,0,LEN(sValue),SELF.sValue);
				SELF.cValue := -1;
			ELSE
				SELF.sValue[0] := CHR(0H);
				SELF.cValue := cValue;
			END;
		END Init;

	END CacheElement;


	(* The Property Cache uses a Hashmap of a specific size to cache either string or character properties. *)
	CharacterPropertyCache = OBJECT
	VAR
		internalCache : POINTER TO ARRAY OF CacheElement;
		cacheSize : SIZE;

		(* Initializes the hashmap with a specific size *)
		PROCEDURE &Init*(size : SIZE);
		BEGIN
			cacheSize := size;
			NEW(internalCache,cacheSize);
		END Init;

		(* Searches the cache for a specific key and returns the corresponding string entry *)
		PROCEDURE SLookup(char : Texts.Char32; VAR res : ARRAY OF CHAR);
		VAR
			bucket : SIZE;
			currentElement : CacheElement;
		BEGIN
			(* get the bucket where the element resides if available *)
			bucket := char MOD cacheSize;
			currentElement := internalCache[bucket];

			(* search the linked list for the entry *)
			WHILE currentElement # NIL DO
				IF currentElement.key = char THEN
					IF CacheDebugging THEN
						KernelLog.String("found: "); KernelLog.Hex(currentElement.key,4);
						KernelLog.String(" ("); KernelLog.String(currentElement.sValue);
						KernelLog.String(")"); KernelLog.Ln;
					END;
					Strings.Copy(currentElement.sValue,0,LEN(res),res);
					RETURN;
				ELSE
					currentElement := currentElement.next;
				END;
			END;

			(* clear the result if nothing was found. *)
			res := "";
		END SLookup;

		(* Searches the cache for a specific key and returns the corresponding character entry *)
		PROCEDURE CLookup(char : Texts.Char32) : Texts.Char32;
		VAR
			bucket : SIZE;
			currentElement : CacheElement;
		BEGIN
			(* get the bucket where the element resides if available *)
			bucket := char MOD cacheSize;
			currentElement := internalCache[bucket];

			(* search the linked list for the entry *)
			WHILE currentElement # NIL DO
				IF currentElement.key = char THEN
					IF CacheDebugging THEN
						KernelLog.String("found: "); KernelLog.Hex(currentElement.key,4);
						KernelLog.String(" ("); KernelLog.Hex(currentElement.cValue,4);
						KernelLog.String(")"); KernelLog.Ln;
					END;
					RETURN currentElement.cValue;
				ELSE
					currentElement := currentElement.next;
				END;
			END;

			(* return a 'fault code' if nothing was found *)
			RETURN -1
		END CLookup;


		(* Inserts a new string entry for a given key. *)
		PROCEDURE SInsert(char : Texts.Char32; CONST value : ARRAY OF CHAR);
		VAR
			newElement : CacheElement;
			bucket : SIZE;
		BEGIN
			NEW(newElement,char,value,-1);

			(* insert the new entry at the first position of the correct bucket *)
			bucket := char MOD cacheSize;
			newElement.next := internalCache[bucket];
			internalCache[bucket] := newElement;

			IF CacheDebugging THEN
				KernelLog.String("inserted: "); KernelLog.Hex(char,4);
				KernelLog.String(" (");
				KernelLog.String(value);
				KernelLog.String(")"); KernelLog.Ln;
			END;
		END SInsert;

		(* Inserts a new character entry for a given key. *)
		PROCEDURE CInsert(char : Texts.Char32; value : Texts.Char32);
		VAR
			newElement: CacheElement;
			bucket : SIZE;
			dummy : ARRAY 1 OF CHAR;
		BEGIN
			dummy[0] := CHR(0H);
			NEW(newElement,char,dummy,value);

			(* insert the new entry at the first position of the correct bucket *)
			bucket := char MOD cacheSize;
			newElement.next := internalCache[bucket];
			internalCache[bucket] := newElement;

			IF CacheDebugging THEN
				KernelLog.String("inserted: "); KernelLog.Hex(char,4);
				KernelLog.String(" ("); KernelLog.Hex(value,4);
				KernelLog.String(")"); KernelLog.Ln;
			END;
		END CInsert;

		(* Prints the whole cache to the console *)
		PROCEDURE Print;
		VAR
			i : SIZE;
			thisElement : CacheElement;
		BEGIN
			FOR i := 0 TO cacheSize - 1 DO
				thisElement := internalCache[i];
				KernelLog.Int(i,3); KernelLog.String(": ");
				WHILE thisElement # NIL DO
					KernelLog.Int(thisElement.key,4); KernelLog.String(" (");
					IF thisElement.cValue = -1 THEN KernelLog.String(thisElement.sValue) END;
					KernelLog.String(") -> ");
					thisElement := thisElement.next;
				END;
				KernelLog.Ln;
			END;
		END Print;

	END CharacterPropertyCache;

	(* A handy implementation for text file reading and analyzation. Basic functionality is provided. TxtReaders that
	    handle a specific text layout, should inherit this class and (re-)implement necessary procedures. *)
	TxtReader = OBJECT
	VAR
		filename : ARRAY 256 OF CHAR;
		text : Texts.Text;
		textReader : Texts.TextReader;
		startPos : SIZE;
		decoder : Codecs.TextDecoder;
		msg : ARRAY 512 OF CHAR;
		fullname : ARRAY 256 OF CHAR;
		file : Files.File;
		in: Streams.Reader;
		decoderRes : INTEGER;

		(* loads a file into a local Text and creates an associated TextReader *)
		PROCEDURE LoadTxtFile;
		BEGIN
			error := FALSE;
			COPY(filename, fullname);

			(* Check whether file exists and get its canonical name *)
			file := Files.Old(filename);
			IF (file # NIL) THEN
				file.GetName(fullname);
			ELSE
				file := Files.New(filename); (* to get path *)
				IF (file # NIL) THEN
					file.GetName(fullname);
					file := NIL;
				END;
			END;

			IF (file # NIL) THEN
				decoder := Codecs.GetTextDecoder("ISO8859-1");

				IF (decoder # NIL) THEN
					in := Codecs.OpenInputStream(fullname);
					IF in # NIL THEN
						decoder.Open(in, decoderRes);
						IF decoderRes = 0 THEN
							text := decoder.GetText();
							NEW(textReader,text);
						END;
					ELSE
						msg := "Can't open input stream on file "; Strings.Append(msg, fullname);
						KernelLog.String(msg);
						error := TRUE;
					END;
				ELSE
					msg := "No decoder for file "; Strings.Append(msg, fullname);
					Strings.Append(msg, " (Format: "); Strings.Append(msg, "ISO8859-1"); Strings.Append(msg, ")");
					KernelLog.String(msg);
					error := TRUE;
				END;
			ELSE
				msg := "file '"; Strings.Append(msg, fullname); Strings.Append(msg,"' not found.");
				KernelLog.String(msg);
				error := TRUE;
			END;
			FindStartPos;
		END LoadTxtFile;

		(* Abstract procedure to be overwritten by the children of TxtReader *)
		PROCEDURE FindStartPos;
		BEGIN
			HALT (999);
		END FindStartPos;

		(* Skips a whole line of the file *)
		PROCEDURE NextLine;
		VAR
			thisChar : Texts.Char32;
		BEGIN
			IF textReader = NIL THEN RETURN END;

			(* read the characters until the end of the line is reached *)
			REPEAT
				textReader.ReadCh(thisChar);
			UNTIL ((thisChar = LF) OR (thisChar = CR));
		END NextLine;

	END TxtReader;


TYPE

	(* TxtReader to read the UnicodeData.txt file. So far there's direct support for the bidi character type and the
	'mirrored' property. More explicit lookups can easily be added later on. *)
	UnicodeTxtReader*=OBJECT(TxtReader)
	VAR
		(* For each property that is explicitly needed, a cache is used. Whenever a new property is needed often,
		feel free to add another cache. *)
		charTypeCache, mirrorPropCache : CharacterPropertyCache;

		(* Loads the UnicodeData.txt into memory and creates the caches. *)
		PROCEDURE &Init*;
		BEGIN
			filename := "UnicodeData.txt";
			LoadTxtFile;
			NEW(charTypeCache,256);
			NEW(mirrorPropCache,256);
		END Init;

		(* The property file has no leading comments. Therefore there are no lines to be skipped *)
		PROCEDURE FindStartPos;
		BEGIN
			startPos := 0;
		END FindStartPos;


		(* Returns the bidirectional character type for a specific character *)
		PROCEDURE GetBidiCharacterType*(char : Texts.Char32; VAR res : Strings.String);
		VAR
			tempRes : ARRAY 16 OF CHAR;
		BEGIN

			(* firstly, the appropriate cache is searched for an entry of this character *)
			charTypeCache.SLookup(char,tempRes);

			(* if nothing was found the file is read and the result is added to the cache. *)
			IF tempRes = "" THEN
				GetProperty(char,4,res^);
				IF res^ = "" THEN
					res^ := "L";
					KernelLog.String("no character type has been found. Using 'L'"); KernelLog.Ln;
				END;
				charTypeCache.SInsert(char,res^);
			ELSE
				Strings.Copy(tempRes,0,LEN(tempRes),res^);
			END;
		END GetBidiCharacterType;

		(* Checks if a specific character has its 'mirrored' property set to 'yes' *)
		PROCEDURE IsMirroredChar*(char : Texts.Char32) : BOOLEAN;
		VAR
			res : ARRAY 16 OF CHAR;
		BEGIN

			(* firstly, the appropriate cache is searched for an entry of this character *)
			mirrorPropCache.SLookup(char,res);

			(* if nothing was found the file is read and the result is added to the cache. *)
			IF res = "" THEN
				GetProperty(char,9,res);
				mirrorPropCache.SInsert(char,res);
			END;

			RETURN res = "Y";
		END IsMirroredChar;

		(* Checks if the character type of a specific character is 'WS' *)
		PROCEDURE IsWhiteSpaceChar*(char : Texts.Char32) : BOOLEAN;
		VAR
			res : ARRAY 16 OF CHAR;
		BEGIN

			(* firstly, the appropriate cache is searched for an entry of this character *)
			charTypeCache.SLookup(char,res);

			(* if nothing was found the file is read and the result is added to the cache. *)
			IF res = "" THEN
				GetProperty(char,4,res);
				charTypeCache.SInsert(char,res);
			END;

			RETURN res = "WS";
		END IsWhiteSpaceChar;

		(* Gets the character's property at a certain position (0 being the character itself). *)
		PROCEDURE GetProperty*(char : Texts.Char32; pos : SIZE; VAR res : ARRAY OF CHAR);
		VAR
			thisChar, thisInt : Texts.Char32;
			i,j : SIGNED16;
			dummyVal : INTEGER;
		BEGIN
			text.AcquireRead;
			textReader.SetPosition(startPos);

			(* iterate through characters *)
			LOOP
				i := 0;
				(* iterate through properties *)
				LOOP
					j := 0;
					(* read the current property *)
					REPEAT
						textReader.ReadCh(thisChar);

						(* is end of file reached? *)
						IF (j = 0) & ((thisChar = EOT) OR (thisChar = NUL)) THEN
							res[j] := CHR(0H);
							text.ReleaseRead;
							RETURN;
						END;

						(* store the string if its the character's coded or the wanted property *)
						IF (i = pos) OR (i = 0) THEN
							res[j] := CHR(thisChar);
						END;
						INC(j);
					UNTIL (thisChar = ORD(';')) OR (thisChar = CR) OR (thisChar = LF);

					(* the property has been found *)
					IF (i = pos) THEN
						res[j-1] := CHR(0H);
						text.ReleaseRead;
						RETURN;
					(* the character's code has been found *)
					ELSIF (i = 0) THEN
						res[j-1] := CHR(0H);
						Strings.HexStrToInt(res,thisInt, dummyVal);

						(* carry on if the this was not the wanted character yet *)
						IF (thisInt < char) THEN
							EXIT;
						(* return if the wanted character has already been passed *)
						ELSIF (thisInt > char) THEN
							res[0] := CHR(0H);
							text.ReleaseRead;
							RETURN;
						END;
					(* return if the wanted property has already been passed *)
					ELSIF (i > pos) THEN
						res[0] := CHR(0H);
						text.ReleaseRead;
						RETURN;
					END;
					(* carry on if this was the last property of the line *)
					IF (thisChar = CR) OR (thisChar = LF) THEN
						EXIT;
					END;
					INC(i);
				END;
				NextLine;
			END;

			text.ReleaseRead;
		END GetProperty;

		(* Exported procedure to print the character type cache *)
		PROCEDURE PrintCharTypeCache*;
		BEGIN
			charTypeCache.Print;
		END PrintCharTypeCache;

	END UnicodeTxtReader;


TYPE

	(* TxtReader to read the BidiMirroring.txt file. *)
	BidiMirroringTxtReader*=OBJECT(TxtReader)
	VAR
		mirrorCache : CharacterPropertyCache;

		(* Loads the BidiMirroring.txt into memory *)
		PROCEDURE &Init*;
		BEGIN
			filename := "BidiMirroring.txt";
			LoadTxtFile;
			NEW(mirrorCache,256);
		END Init;


		(* Finds the start position of the relevant data. The mirroring file has a large comment at the beginning,
		so the scanner needs to be set to the first line of interest. *)
		PROCEDURE FindStartPos;
		VAR
			thisChar : SIGNED32;
		BEGIN
			thisChar := 0;
			text.AcquireRead;

			(* read the line's first character and skip the line if it's a '#' *)
			textReader.ReadCh(thisChar);
	 		WHILE (thisChar = ORD('#')) DO
	 			NextLine;
	 			textReader.ReadCh(thisChar);
	 		END;

			(* store the start position *)
	 		startPos := textReader.GetPosition();
	 		text.ReleaseRead;
		END FindStartPos;



		(* Reads the next source character. The procedure assumes the scanner to be at the beginning	of the line. *)
		PROCEDURE GetSourceChar() : Texts.Char32;
		VAR
			sourceString : ARRAY 7 OF CHAR;
			sourceInt, tempChar : Texts.Char32;
			i : SIGNED16;
			res : INTEGER;
		BEGIN
			sourceInt := -1;
			i := -1;

			(* read the characters that form the code for the source character *)
			REPEAT
				INC(i);
				textReader.ReadCh(tempChar);
				sourceString[i] := CHR(tempChar);
			UNTIL (tempChar = EOT) OR (tempChar = ORD('#')) OR (tempChar = ORD(';'));

			(* if the character was terminated by a ';' it is assumed to be valid and is converted into an integer *)
			IF (tempChar = ORD(';')) THEN
				sourceString[i] := CHR(0H);
				Strings.HexStrToInt(sourceString,sourceInt,res);
			END;

			RETURN sourceInt;
		END GetSourceChar;


		(* Reads the next target character. The procedure assumes the scanner to have already read the source character
		and to be now at the beginning of the target character's code. Additionally it assumes the text to be locked. *)
		PROCEDURE GetTargetChar() : Texts.Char32;
		VAR
			targetString : ARRAY 7 OF CHAR;
			targetInt, tempChar : Texts.Char32;
			i : SIGNED16;
			res : INTEGER;
		BEGIN
			targetInt := -1;
			i := -1;

			(* read the whitespace *)
			textReader.ReadCh(tempChar);

			(* read the characters that form the code for the target character *)
			REPEAT
				INC(i);
				textReader.ReadCh(tempChar);
				targetString[i] := CHR(tempChar);
			UNTIL (tempChar = EOT) OR (tempChar = ORD('#')) OR (tempChar = SP);

			(* terminate the result string and convert it into an integer *)
			targetString[i] := CHR(0H);
			Strings.HexStrToInt(targetString,targetInt,res);

			RETURN targetInt;
		END GetTargetChar;



		(* Searches the mirror file for a given character and returns its counterpart if found. *)
		PROCEDURE GetMirroredChar*(char : Texts.Char32) : Texts.Char32;
		VAR
			sChar : Texts.Char32;
		BEGIN

			(* look in the cache first *)
			sChar := mirrorCache.CLookup(char);
			IF sChar = -1 THEN
				text.AcquireRead;

				(* search the right source character *)
				textReader.SetPosition(startPos);
				REPEAT
					sChar := GetSourceChar();
					IF (sChar # char) THEN
						NextLine;
					END;
				UNTIL (sChar = char) OR (sChar = -1);	(* if the char is found or if the end of chars is reached, jump out of the loop *)

				(* return Null if the source character could not be found *)
				IF (sChar = -1) THEN
					text.ReleaseRead;
					RETURN 0;
				ELSE
					(* get the target character, store it in the cache and return it *)
					sChar := GetTargetChar();
					mirrorCache.CInsert(char,sChar);
					text.ReleaseRead;
					RETURN sChar;
				END;
			ELSE
				RETURN sChar;
			END;
		END GetMirroredChar;

	END BidiMirroringTxtReader;

END UnicodeProperties.



System.Free UnicodeProperties ~


UnicodeProperties.TestIsMirroredChar 00000028H ~


PC0.Compile UnicodeProperties.Mod ~
