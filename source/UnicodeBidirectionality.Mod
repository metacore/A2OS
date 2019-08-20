MODULE UnicodeBidirectionality;	(** AUTHOR "gubsermi"; PURPOSE "Implementation of the Unicode Bidirectionality Algorithm"; *)

IMPORT
	Codecs, Files, Streams, KernelLog, Texts, Commands, UnicodeProperties, Strings;

CONST
	DOSNeutral			= 0;
	DOSRightToLeft			= 1;
	DOSLeftToRight			= 2;
	NeutralType				= 0;
	EuropeanNumber 		= 1;
	ArabicNumber			= 2;
	LeftStrongType			= 3;

	CharacterDebugging	= FALSE;
	CacheDebugging		= FALSE;

	WeakTypes1*			= 0;
	WeakTypes2*			= 1;
	EuropeanNumberAdj*	= 2;
	ArabicNumberAdj*		= 3;
	NeutralTypes*			= 4;
	SameDirection*			= 5;


	initialCachePoolSize		= 10000;
	initialCacheElementSize	= 1000;

TYPE
	IntegerArray = POINTER TO ARRAY OF SIZE;

	CharArray = POINTER TO ARRAY OF Texts.Char32;

	TextReaderArray = POINTER TO ARRAY OF Texts.TextReader;

	BoolArray = POINTER TO ARRAY OF BOOLEAN;

	PosArray = POINTER TO RECORD
		array : POINTER TO ARRAY OF SIZE;
		size : SIZE;
		next : PosArray;
	END;

	PosArrays = POINTER TO ARRAY OF PosArray;

		(* simple stack for integers with some default stack functions *)
	IntegerStack = OBJECT
	VAR
		top : SIZE;
		internalStack : IntegerArray;
		internalStackSize : SIZE;

		(* initializes the stack with a certain size *)
		PROCEDURE &Init*(size : SIZE);
		BEGIN
			NEW(internalStack,size);
			top := 0;
			internalStackSize := size;
		END Init;

		(* pushes a new element on top of the stack *)
		PROCEDURE Push(i : SIZE);
		VAR
			tempStack : IntegerArray;
			j : SIZE;
		BEGIN
			(* if the internal stack is full it needs to be resized *)
			IF (top >= internalStackSize) THEN
				(* 1.5 times the originial stack size is sufficient, since the old size
					should've been a best estimate *)
				internalStackSize := ENTIER(top*1.5);

				(* create and fill the new stack *)
				NEW(tempStack,internalStackSize);
				FOR j := 0 TO top - 1 DO
					tempStack[j] := internalStack[j];
				END;
				internalStack := tempStack;
			END;

			internalStack[top] := i;
			INC(top);
		END Push;

		(* returns the top element of the stack and removes it *)
		PROCEDURE Pop() : SIZE;
		BEGIN
			IF (top = 0) THEN
				RETURN -1;
			ELSE
				DEC(top);
				RETURN internalStack[top];
			END;
		END Pop;

		(* returns the top element of the stack without removing it *)
		PROCEDURE Top() : SIZE;
		BEGIN
			IF (top = 0) THEN
				RETURN -1;
			ELSE
				RETURN internalStack[top-1];
			END;
		END Top;

		(* remove all elements from the stack *)
		PROCEDURE Purge;
		BEGIN
			top := 0;
		END Purge;

		(* returns the current number of elements on the stack *)
		PROCEDURE Size() : SIZE;
		BEGIN
			RETURN top;
		END Size;

	END IntegerStack;


	PosArrayPool = RECORD
		first, last : PosArray;
	END;

	StringElement = RECORD
		element : Strings.String;
		used : BOOLEAN;
	END;

	IntegerStackElement = RECORD
		element : IntegerStack;
		used : BOOLEAN;
	END;

	UStringElement = RECORD
		element : Texts.PUCS32String;
		used : BOOLEAN;
	END;

	(* The Array Memory Manager uses several variable pools to minimize reallocation of heap memory *)
	ArrayMemoryManager = OBJECT
	VAR
		posArrayPool : PosArrayPool;
		stringPool : ARRAY initialCachePoolSize OF StringElement;
		integerStackPool : ARRAY 10 OF IntegerStackElement;
		uStringPool : ARRAY 10 OF UStringElement;

		PROCEDURE &Init*;
		VAR
			i : SIZE;
			newPosArray: PosArray;
		BEGIN

			(* fill the position array pool *)
			NEW(posArrayPool.last);
			NEW(posArrayPool.last.array,initialCacheElementSize);
			posArrayPool.last.size := 0;
			posArrayPool.first := posArrayPool.last;
			FOR i := 1 TO initialCachePoolSize - 1 DO
				NEW(newPosArray);
				NEW(newPosArray.array,initialCacheElementSize);
				newPosArray.size := 0;
				posArrayPool.last.next := newPosArray;
				posArrayPool.last := newPosArray;
			END;

			(* fill the string pool *)
			FOR i:= 0 TO initialCachePoolSize - 1 DO
				NEW(stringPool[i].element,16);
			END;

			(* fill the one-character-string pool *)
			FOR i := 0 TO 9 DO
				NEW(integerStackPool[i].element,100);
				NEW(uStringPool[i].element,2);
			END;
		END Init;

		(* Allocates a new textreader array if necessary *)
		PROCEDURE NewTextReaderArray(VAR trArray : TextReaderArray; size : SIZE);
		BEGIN
			IF trArray = NIL THEN
				NEW(trArray,MAX(initialCacheElementSize,2*size));
			ELSIF LEN(trArray) < size THEN
				NEW(trArray,2*size);
			END;
		END NewTextReaderArray;

		(* Gets a previously allocated integer stack from the pool if available *)
		PROCEDURE NewIntegerStack(VAR stack : IntegerStack; size : SIZE);
		VAR
			i : SIZE;
		BEGIN
			FOR i := 0 TO 9 DO
				IF ~integerStackPool[i].used THEN
					IF integerStackPool[i].element.internalStackSize < size THEN
						NEW(integerStackPool[i].element,size);
					END;
					stack := integerStackPool[i].element;
					integerStackPool[i].used := TRUE;
					RETURN;
				END;
			END;
			NEW(stack,size);
		END NewIntegerStack;

		(* Puts the integer stack back to the pool *)
		PROCEDURE FreeIntegerStack(stack : IntegerStack);
		VAR
			i : SIZE;
		BEGIN
			FOR i := 0 TO 9 DO
				IF stack = integerStackPool[i].element THEN
					integerStackPool[i].used := FALSE;
					RETURN;
				END;
			END;
		END FreeIntegerStack;

		(* Allocates a new boolean array if necessary *)
		PROCEDURE NewBoolArray(VAR bArray : BoolArray; size : SIZE);
		BEGIN
			IF bArray = NIL THEN
				NEW(bArray,MAX(initialCacheElementSize,2*size));
			ELSIF LEN(bArray) < size THEN
				NEW(bArray,2*size);
			END;
		END NewBoolArray;

		(* Allocates a new array for position arrays if necessary *)
		PROCEDURE NewPosArrays(VAR pArrays : PosArrays; size : SIZE);
		BEGIN
			IF pArrays = NIL THEN
				NEW(pArrays,MAX(initialCacheElementSize,2*size));
			ELSIF LEN(pArrays) < size THEN
				NEW(pArrays,2*size);
			END;
		END NewPosArrays;

		(* Gets a previously allocated position array from the pool if available *)
		PROCEDURE NewPosArray(VAR pArray : PosArray; size : SIZE);
		VAR
			thisPosArray, lastPosArray : PosArray;
		BEGIN
			(* if pArray is already a usable position array, use it *)
			IF (pArray # NIL) & (pArray # NIL) & (LEN(pArray.array) >= size) THEN
				pArray.size := size;
				RETURN;
			END;

			(* pool is empty *)
			IF posArrayPool.first = NIL THEN
				NEW(pArray);
				NEW(pArray.array,MAX(initialCacheElementSize,2*size));
				pArray.size := size;
				RETURN;
			END;

			(* the first position array is ok *)
			thisPosArray := posArrayPool.first;
			IF LEN(thisPosArray.array) >= size THEN
				pArray := thisPosArray;
				pArray.size := size;
				posArrayPool.first := pArray.next;
				pArray.next := NIL;
				RETURN;
			END;


			(* search the pool for a valid position array *)
			lastPosArray := thisPosArray;
			thisPosArray := thisPosArray.next;
			WHILE thisPosArray # NIL DO
				IF LEN(thisPosArray.array) >= size THEN
					pArray := thisPosArray;
					pArray.size := size;
					lastPosArray.next := thisPosArray.next;
					pArray.next := NIL;
					RETURN;
				END;
				lastPosArray := thisPosArray;
				thisPosArray := thisPosArray.next;
			END;

			(* if no position array was found, resize the first one and use it *)
			pArray := posArrayPool.first;
			NEW(pArray.array,MAX(initialCacheElementSize,2*size));
			pArray.size := size;
			posArrayPool.first := pArray.next;
			pArray.next := NIL;
		END NewPosArray;

		(* Allocates a new integer array if necessary *)
		PROCEDURE NewIntegerArray(VAR iArray : IntegerArray; size : SIZE);
		BEGIN
			IF iArray = NIL THEN
				NEW(iArray,MAX(initialCacheElementSize,2*size));
			ELSIF LEN(iArray) < size THEN
				NEW(iArray,2*size);
			END;
		END NewIntegerArray;

		(* Allocates a new string array if necessary *)
		PROCEDURE NewStringArray(VAR sArray : Strings.StringArray; size : SIZE);
		BEGIN
			IF sArray = NIL THEN
				NEW(sArray,MAX(initialCacheElementSize,2*size));
			ELSIF LEN(sArray) < size THEN
				NEW(sArray,2*size);
			END;
		END NewStringArray;

		(* Allocates a new character array if necessary *)
		PROCEDURE NewCharArray(VAR cArray : CharArray; size : SIZE);
		BEGIN
			IF cArray = NIL THEN
				NEW(cArray,MAX(initialCacheElementSize,2*size));
			ELSIF LEN(cArray) < size THEN
				NEW(cArray,2*size);
			END;
		END NewCharArray;

		(* Allocates a new character type if necessary *)
		PROCEDURE NewCharacterType(VAR charType : Strings.String);
		BEGIN
			IF charType = NIL THEN
				NEW(charType,16);
			END;
		END NewCharacterType;

		(* Gets a previously allocated string from the pool if available *)
		PROCEDURE NewString(VAR string : Strings.String);
		VAR
			i : SIZE;
		BEGIN
			FOR i := 0 TO initialCachePoolSize - 1 DO
				IF ~stringPool[i].used THEN
					string := stringPool[i].element;
					stringPool[i].used := TRUE;
					RETURN;
				END;
			END;
			NEW(string,256);
		END NewString;

		(* Puts the string back to the pool *)
		PROCEDURE FreeString(string : Strings.String);
		VAR
			i : SIZE;
		BEGIN
			FOR i := 0 TO initialCachePoolSize - 1 DO
				IF string = stringPool[i].element THEN
					stringPool[i].used := FALSE;
					RETURN;
				END;
			END;
		END FreeString;

		(* Gets a previously allocated one-character-string from the pool if available *)
		PROCEDURE NewUString(VAR string : Texts.PUCS32String);
		VAR
			i : SIZE;
		BEGIN
			FOR i := 0 TO 9 DO
				IF ~uStringPool[i].used THEN
					string := uStringPool[i].element;
					uStringPool[i].used := TRUE;
					RETURN;
				END;
			END;
			NEW(string,2);
		END NewUString;

		(* Puts the one-character-string back to the pool *)
		PROCEDURE FreeUString(string : Texts.PUCS32String);
		VAR
			i : SIZE;
		BEGIN
			FOR i := 0 TO 9 DO
				IF string = uStringPool[i].element THEN
					uStringPool[i].used := FALSE;
					RETURN;
				END;
			END;
		END FreeUString;
	END ArrayMemoryManager;


	(* Desribes the different version of a line in the text. Since a line (or paragraph) can be splitted by word-wrapping,
	for each possible start of a line, the according property needs to be present. *)
	LineElement = OBJECT
	VAR
		next : LineElement;
		id : SIZE;
		pos : SIZE;
		lineLength : SIZE;
		paragraphEmbeddingLevel : SIZE;

		textReaders : TextReaderArray;
		dirty : BoolArray;
		posArrays, reversePosArrays : PosArrays;

		characterEmbeddingLevels : IntegerArray;
		originalCharacterTypes : Strings.StringArray;
		characterTypes : Strings.StringArray;
		characters : CharArray;

		(* Initializes a LineElement *)
		PROCEDURE &Init*;
		BEGIN
			next := NIL;
			id := -1;
			pos := -1;
			lineLength := -1;
			paragraphEmbeddingLevel := -1;
		END Init;

		(* clears the whole LineElement, except identification parts *)
		PROCEDURE Clear;
		BEGIN
			lineLength := 0;
			paragraphEmbeddingLevel := -1;
			textReaders := NIL;
			dirty := NIL;
			posArrays := NIL;
			reversePosArrays := NIL;
			characterEmbeddingLevels := NIL;
			originalCharacterTypes := NIL;
			characterTypes := NIL;
			characters := NIL;
		END Clear;

	END LineElement;





	(* The Line Cache supports the fast recovery of previously computed data belonging to a certain line in the text.
	Elements are identified by their start position. *)
	LineCache = OBJECT
	VAR
		first : LineElement;

		(* initializes and empty list *)
		PROCEDURE &Init*;
		BEGIN
			first := NIL;
		END Init;

		(* Inserts a line with a certain start position into the cache. The lines in the cache are sorted by their start position. *)
		PROCEDURE InsertLine(pos : SIZE);
		VAR
			thisElement, lastElement, newElement : LineElement;
		BEGIN

			(* Look for the appropriate position *)
			thisElement := first;
			WHILE (thisElement # NIL) & (thisElement.pos < pos) DO
				lastElement := thisElement;
				thisElement := thisElement.next;
			END;

			(* the new element belongs to the end of the list *)
			IF thisElement = NIL THEN
				NEW(newElement);
				newElement.pos := pos;

				(* if the list was empty before, this has changed now *)
				IF first = NIL THEN
					first := newElement;
				ELSE
					lastElement.next := newElement;
				END;
			(* the line is already in the list *)
			ELSIF thisElement.pos = pos THEN
				(* maybe insert some stuff later *)

			(* Insert the new element at the correct position inside the list. Since the first line will always be the first line in
			the text (it might change, but it'll always be the first line), the case where the new element will be the new first
			element of the list needs not to be taken care of! *)
			ELSE
				NEW(newElement);
				newElement.pos := pos;
				newElement.next := thisElement;
				lastElement.next := newElement;
			END;

			IF CacheDebugging THEN
				KernelLog.Ln; KernelLog.String("line inserted (");
				KernelLog.Int(pos,4); KernelLog.String(")"); KernelLog.Ln;
			END;
		END InsertLine;



		(* gets the start position of the next line or the start position of the same line if the line is actually
		the last one in the text. *)
		PROCEDURE GetNextPos(pos : SIZE) : SIZE;
		VAR
			thisElement : LineElement;
		BEGIN

			(* find the current line *)
			thisElement := first;
			FindElement(pos,thisElement);

			(* no appropriate element has been found *)
			IF (thisElement = NIL) OR (thisElement.pos > pos) THEN
				RETURN -1;
			ELSE
				(* return the according start position *)
				IF thisElement.next # NIL THEN
					RETURN thisElement.next.pos;
				ELSE
					RETURN thisElement.pos;
				END;
			END;
		END GetNextPos;

		(* removes a certain line - identified by its start position - from the cache *)
		PROCEDURE RemoveLine(pos : SIZE);
		VAR
			thisElement, lastElement : LineElement;
		BEGIN
			(* get the element to be deleted *)
			thisElement := first;
			WHILE (thisElement # NIL) & (thisElement.pos < pos) DO
				lastElement := thisElement;
				thisElement := thisElement.next;
			END;

			(* if the element has been found it can be removed *)
			IF (thisElement # NIL) & (thisElement.pos = pos) THEN
				IF thisElement = first THEN
					first := thisElement.next;
				ELSE
					lastElement.next := thisElement.next;
				END;
			END;

			IF CacheDebugging THEN
				KernelLog.Ln; KernelLog.String("line removed(");
				KernelLog.Int(pos,4); KernelLog.String(")"); KernelLog.Ln;
			END;
		END RemoveLine;

		(* changes all positions starting from a certain position by a certain value *)
		PROCEDURE ChangePos(startPos, changeValue : SIZE);
		VAR
			thisElement : LineElement;
		BEGIN
			(* get the first element to be changed *)
			thisElement := first;
			FindElement(startPos,thisElement);
			thisElement := thisElement.next;

			(* change all following elements *)
			WHILE thisElement # NIL DO
				INC(thisElement.pos,changeValue);
				thisElement := thisElement.next;
			END;
		END ChangePos;

		(* finds the line a certain position belongs to *)
		PROCEDURE FindElement(pos : SIZE; VAR thisElement : LineElement);
		VAR
			nextElement : LineElement;
		BEGIN
			(* search the list until the line is found *)
			nextElement := first;
			WHILE (nextElement # NIL) & (nextElement.pos <= pos) DO
				thisElement := nextElement;
				nextElement := nextElement.next;
			END;
		END FindElement;

		(* Prints the important information of the cache. Easily extensible if desired. *)
		PROCEDURE PrintCache;
		VAR
			thisElement : LineElement;
			i : INTEGER;
		BEGIN
			thisElement := first;
			i := 0;
			KernelLog.Ln;
			KernelLog.String("pos    pel    last         len"); KernelLog.Ln;
			KernelLog.String("===================="); KernelLog.Ln;
			WHILE thisElement # NIL DO
				KernelLog.Int(thisElement.pos,4); KernelLog.String(":  ");
				KernelLog.Int(thisElement.paragraphEmbeddingLevel,2); KernelLog.String("   ");
				IF thisElement.characters # NIL THEN
					KernelLog.Hex(thisElement.characters[LEN(thisElement.characters)-1],4);
				ELSE
					KernelLog.String("-:-:-");
				END;
				KernelLog.Int(thisElement.lineLength,4);
				KernelLog.Ln;
				thisElement := thisElement.next;
				INC(i);
			END;
			KernelLog.String("cache size: "); KernelLog.Int(i,3); KernelLog.String(" lines"); KernelLog.Ln;
			KernelLog.Ln;
		END PrintCache;

	END LineCache;


	(* The Segment Cache supports the fast recovery of previously computed data belonging to a certain segment in the text.
	Elements are identified by their id number. The Segment Cache is not ordered.*)
	SegmentCache = OBJECT
	VAR
		first, last : LineElement;
		nextId : SIZE;

		PROCEDURE &Init*;
		BEGIN
			first := NIL;
			last := NIL;
			nextId := 0;
		END Init;

		(* Inserts a segment with a certain start and end position into the cache. The next free id is assigned to the element. *)
		PROCEDURE InsertSegment(start, end : SIZE) : SIZE;
		VAR
			thisElement, newElement : LineElement;
		BEGIN
			NEW(newElement);
			newElement.pos := start;
			newElement.lineLength := end - start + 1;
			newElement.id := nextId;
			INC(nextId);

			IF first = NIL THEN
				first := newElement;
				last := newElement;
				RETURN nextId;
			END;

			thisElement := first;

			WHILE thisElement # last DO
				thisElement := thisElement.next;
			END;

			thisElement.next := newElement;
			last := newElement;
			RETURN nextId;
		END InsertSegment;

		(* removes a certain segment - identified by its id - from the cache *)
		PROCEDURE RemoveSegment(id : SIZE);
		VAR
			thisElement : LineElement;
		BEGIN
			IF first = NIL THEN
				RETURN;
			ELSIF first.id = id THEN
				IF first = last THEN
					first := NIL;
					last := NIL;
					RETURN;
				ELSE
					first := first.next;
					RETURN;
				END;
			END;

			thisElement := first;

			WHILE thisElement.next # last DO
				IF thisElement.next.id = id THEN
					thisElement.next := thisElement.next.next;
					RETURN;
				END;
				thisElement := thisElement.next;
			END;

			IF last.id = id THEN
				last := thisElement;
			END;
		END RemoveSegment;

		(* changes the start position of a certain element by a certain value *)
		PROCEDURE ChangePos(id, changeValue : SIZE);
		VAR
			thisElement : LineElement;
		BEGIN
			thisElement := first;

			WHILE thisElement # last DO
				IF thisElement.id = id THEN
					INC(thisElement.pos,changeValue);
					RETURN;
				END;
			END;

			IF last.id = id THEN
				INC(thisElement.pos,changeValue);
			END;
		END ChangePos;

		(* finds the segment identified by a certain id *)
		PROCEDURE FindElement(id : SIZE; VAR thisElement : LineElement);
		BEGIN
			thisElement := first;

			WHILE thisElement # last DO
				IF thisElement.id = id THEN
					RETURN;
				END;
				thisElement := thisElement.next;
			END;

			IF last.id = id THEN
				RETURN;
			END;

			thisElement := NIL;
		END FindElement;


		(* Prints the important information of the cache. Easily extensible if desired. *)
		PROCEDURE PrintCache;
		VAR
			thisElement : LineElement;
			i : INTEGER;
		BEGIN
			thisElement := first;
			i := 0;
			KernelLog.Ln;
			KernelLog.String("id    pel    last         pos     len"); KernelLog.Ln;
			KernelLog.String("===================="); KernelLog.Ln;
			WHILE thisElement # NIL DO
				KernelLog.Int(thisElement.id,4); KernelLog.String(": ");
				KernelLog.Int(thisElement.pos,4); KernelLog.String("     ");
				KernelLog.Int(thisElement.paragraphEmbeddingLevel,2); KernelLog.String("   ");
				IF thisElement.characters # NIL THEN
					KernelLog.Hex(thisElement.characters[LEN(thisElement.characters)-1],4);
				ELSE
					KernelLog.String("-:-:-");
				END;
				KernelLog.Int(thisElement.lineLength,4);
				KernelLog.Ln;
				thisElement := thisElement.next;
				INC(i);
			END;
			KernelLog.String("cache size: "); KernelLog.Int(i,3); KernelLog.String(" lines"); KernelLog.Ln;
			KernelLog.Ln;
		END PrintCache;

	END SegmentCache;



	(* This is the core of the Bidirectional formatting of a utf-text. *)
	BidiFormatter*=OBJECT
	VAR
		amm : ArrayMemoryManager;
		textReader : Texts.TextReader;
		unicodePropertyReader: UnicodeProperties.UnicodeTxtReader;
		mirrorPropertyReader: UnicodeProperties.BidiMirroringTxtReader;
		reformatted : BOOLEAN;
		lineCache: LineCache;
		segmentCache : SegmentCache;
		trueTextLength : SIZE;
		HL1* : HigherLevelProtocol1;
		HL2* : HigherLevelProtocol2;
		HL3* : HigherLevelProtocol3;
		HL4* : BOOLEAN;
		HL5* : HigherLevelProtocol5;
		HL6* : HigherLevelProtocol6;

		(* Initializes the Bidi Formatter for a given text. Additionally, two property readers are set up. *)
		PROCEDURE &Init*(text : Texts.Text);
		BEGIN
			NEW(amm);
			NEW(textReader,text);
			trueTextLength := text.GetLength();
			textReader.SetDirection(1);
			NEW(unicodePropertyReader);
			NEW(mirrorPropertyReader);
			reformatted := FALSE;
			HL4 := FALSE;
		END Init;

		(* Implements the first steps of the bidirectionality algorithm. The text is analyzed and the character types are
		reapplied. After reformatting, the text is ready for word-wrapping and later for reordering. *)
		PROCEDURE ReformatText*;
		VAR
			thisPos, nextPos : SIZE;
			char : Texts.Char32;
		BEGIN
			(* do nothing if the text is not utf formatted *)
			IF ~textReader.text.isUTF THEN
				RETURN;
			END;

			(* The text length needs to be remembered to detect fake 'changed' messages *)
			trueTextLength := textReader.text.GetLength();

			IF CharacterDebugging THEN KernelLog.String("reformatting text..."); KernelLog.Ln; END;

			(* initialize the line cache and - if used - the segment cache *)
			nextPos := 0;
			NEW(lineCache);
			IF HL4 THEN
				NEW(segmentCache);
			END;

			(* P1. cut the text into paragraphs (lines) and reformat them *)
			REPEAT
				thisPos := nextPos;
				lineCache.InsertLine(thisPos);
				FindEndOfParagraph(thisPos,nextPos);
				ReformatParagraph(thisPos);
			UNTIL (nextPos >= textReader.text.GetLength()) OR (thisPos = nextPos);

			(* if the last character is a LF, a last (empty) line needs to be inserted *)
			textReader.SetDirection(1);
			textReader.SetPosition(textReader.text.GetLength()-1);
			textReader.ReadCh(char);
			IF char = UnicodeProperties.LF THEN
				lineCache.InsertLine(textReader.text.GetLength());
			END;


			IF CacheDebugging THEN
				KernelLog.Ln;
				unicodePropertyReader.PrintCharTypeCache;
			END;

			IF CharacterDebugging THEN
				KernelLog.Ln; KernelLog.String("...reformatting done! Text length: ");
				KernelLog.Int(textReader.text.GetLength(),4); KernelLog.Ln;
			END;

			IF CacheDebugging THEN
				lineCache.PrintCache;
				IF segmentCache # NIL THEN
					segmentCache.PrintCache;
				END;
			END;

			reformatted := TRUE;
		END ReformatText;

		(* Applies the steps introduced ReformatText to some few affected lines. This is used for faster on-the-fly
		reformatting. When a character is inserted or deleted, only the current line and the line before (in some
		cases) need reformatting. *)
		PROCEDURE ReformatTextFrom*(pos, changed : SIZE);
		VAR
			char : Texts.Char32;
		BEGIN
			(* do nothing if the text is not utf formatted *)
			IF ~textReader.text.isUTF THEN
				RETURN;
			END;

			(* check if there has really been a change (yes, there are some fake messages around!). if there really
				was a change, the start positions in the cache need to be changed. *)
			IF trueTextLength = textReader.text.GetLength() THEN
				changed := 0;

			(* whole text is reloaded/deleted *)
			ELSE
				lineCache.ChangePos(pos, changed);
				trueTextLength := textReader.text.GetLength();
			END;

			IF CharacterDebugging THEN
				KernelLog.String("reformatting text at position "); KernelLog.Int(pos,4);
				KernelLog.String("..."); KernelLog.Ln;
			END;

			textReader.SetDirection(1);
			textReader.SetPosition(pos);
			textReader.ReadCh(char);
			(* if a line feed has been inserted a new line is created in the cache and both lines are reformatted *)
			IF (changed > 0) & (char = UnicodeProperties.LF) THEN
				lineCache.InsertLine(pos+1);
				ReformatParagraph(pos);
				ReformatParagraph(pos+1);
			(* if one or more characters have been deleted the current line needs reformatting. Additionally, all
			cache entries that represent lines, which aren't whole lines anymore are deleted. *)
			ELSIF changed < 0 THEN
				SweepCache;
				ReformatParagraph(pos);
			(* default case: simple non-linefeed character insertion *)
			ELSE
				ReformatParagraph(pos);
			END;

			IF CharacterDebugging THEN
				KernelLog.Ln; KernelLog.String("...reformatting done! Text length: ");
				KernelLog.Int(textReader.text.GetLength(),4); KernelLog.Ln;
			END;

			IF CacheDebugging THEN
				lineCache.PrintCache;
				IF segmentCache # NIL THEN
					segmentCache.PrintCache;
				END;
			END;

		END ReformatTextFrom;


		(* performs the reformatting steps from the algorithm line-wise *)
		PROCEDURE ReformatParagraph(pos : SIZE);
		VAR
			cacheElement : LineElement;
			start, end : SIZE;
		BEGIN
			(* find the previously created cache entry for the current line *)
			lineCache.FindElement(pos,cacheElement);

			(* scan the text for the start and end position of the line *)
			FindStartOfParagraph(pos,start);
			FindEndOfParagraph(pos,end);

			IF CharacterDebugging THEN
				KernelLog.Ln; KernelLog.Ln;
				KernelLog.String("paragraph ("); KernelLog.Int(start,3); KernelLog.String(",");
				KernelLog.Int(end-1,3); KernelLog.String(") found.");
			END;

			ReformatClause(start,end,cacheElement);

		END ReformatParagraph;

		(* HL4. performs the reformatting steps from the algorithm for a single segment *)
		PROCEDURE ReformatSegment*(start, end : SIZE) : SIZE;
		VAR
			thisId : SIZE;
			cacheElement : LineElement;
		BEGIN
			IF ~textReader.text.isUTF OR ~HL4 OR (segmentCache = NIL) THEN
				RETURN -1;
			END;

			(* insert a new entry into the cache *)
			thisId := segmentCache.InsertSegment(start,end);
			segmentCache.FindElement(thisId,cacheElement);

			(* reformat the segment *)
			ReformatClause(start,end+1,cacheElement);

			RETURN thisId;
		END ReformatSegment;

		(* HL4. removes a certain segment from the cache *)
		PROCEDURE RemoveSegment*(id : SIZE);
		BEGIN
			IF ~textReader.text.isUTF OR ~HL4 OR (segmentCache = NIL) THEN
				RETURN;
			END;

			segmentCache.RemoveSegment(id);
		END RemoveSegment;

		(* HL4. changes the start position of a certain segment *)
		PROCEDURE ChangeSegmentPos*(id, changeValue : SIZE);
		BEGIN
			IF ~textReader.text.isUTF OR ~HL4 OR (segmentCache = NIL) THEN
				RETURN;
			END;

			segmentCache.ChangePos(id,changeValue);
		END ChangeSegmentPos;

		(* reformats a part of the text (either a single line or a predefined segment *)
		PROCEDURE ReformatClause(start, end : SIZE; VAR cacheElement : LineElement);
		VAR
			charType : Strings.String;
			i : SIZE;
		BEGIN
			amm.NewString(charType);


			(* if HL1 is undefined, compute the paragraph embedding level and assign it otherwise *)
			IF HL1 = NIL THEN
				(* P2. determine the first strong character type *)
				FindFirstStrongCharacter(start,end,charType);

				(* P3. assign the paragraph embedding level *)
				IF charType = NIL THEN
					IF CharacterDebugging THEN KernelLog.String(" (Empty paragraph)"); END;
					cacheElement.Clear;
					amm.FreeString(charType);
					RETURN;
				ELSIF charType^ = "L" THEN
					cacheElement.paragraphEmbeddingLevel := 0;
				ELSE
					cacheElement.paragraphEmbeddingLevel := 1;
				END;
			ELSE
				cacheElement.paragraphEmbeddingLevel := HL1(textReader,start,end);
			END;
			amm.FreeString(charType);

			IF CharacterDebugging THEN
				KernelLog.String(" Embedding Level: "); KernelLog.Int(cacheElement.paragraphEmbeddingLevel,2); KernelLog.Ln;
				PrintOriginalTypedParagraph(start,end);
				PrintCodedParagraph(start,end);
				KernelLog.Ln; KernelLog.String("Applying explicit levels...");
			END;

			(* step through the different parts of the algorithm *)

			ApplyExplicitLevels(start,end,cacheElement);


			IF CharacterDebugging THEN
				PrintCurrentTypedParagraph(start,end);
				PrintLeveledParagraph(start,end);
				KernelLog.Ln; KernelLog.String("Resolving weak types...");
			END;


			ResolveWeakTypes(cacheElement);

			IF CharacterDebugging THEN
				PrintCurrentTypedParagraph(start,end);
				KernelLog.Ln; KernelLog.String("Resolving neutral types...");
			END;


			ResolveNeutralTypes(cacheElement);

			IF CharacterDebugging THEN
				PrintCurrentTypedParagraph(start,end);
				KernelLog.Ln; KernelLog.String("Resolving implicit levels...");
			END;


			ResolveImplicitLevels(cacheElement);

			IF CharacterDebugging THEN
				PrintLeveledParagraph(start,end);
			END;

			(* mark the whole line as dirty so it needs further processing for reordering *)
			FOR i := 0 TO LEN(cacheElement.dirty) - 1 DO
				cacheElement.dirty[i] := TRUE;
			END;
		END ReformatClause;

		(* Scans the text and applies the explicit embedding level of each character *)
		PROCEDURE ApplyExplicitLevels(start, end : SIZE; VAR cacheElement : LineElement);
		VAR
			embeddingLevels : IntegerStack;
			dummyEmbeddingLevel : SIZE;
			overrideStati : IntegerStack;
			dummyOverrideStatus : SIZE;
			char : Texts.Char32;
			charType : Strings.String;
			nextLevel : SIZE;
			i : SIZE;
			lineLength : SIZE;
			surplusLevels : LONGINT;
			hlCharacterType  : Strings.String;
			hlEmbeddingLevel : LONGINT;
		BEGIN
			char := 0H;
			nextLevel := 0;
			i := 0;
			surplusLevels := 0;

			(* create several arrays for the cache *)
			lineLength := end-start;
			amm.NewIntegerArray(cacheElement.characterEmbeddingLevels,lineLength);
			amm.NewStringArray(cacheElement.characterTypes,lineLength);
			amm.NewStringArray(cacheElement.originalCharacterTypes,lineLength);
			amm.NewCharArray(cacheElement.characters,lineLength);

			(* create temporary stacks for the algorithm *)
			amm.NewIntegerStack(embeddingLevels, 62);
			amm.NewIntegerStack(overrideStati,2*lineLength);

			(* X1. set the current level to the paragraph embedding level *)
			embeddingLevels.Push(cacheElement.paragraphEmbeddingLevel);
			overrideStati.Push(DOSNeutral);

			(* step through the whole line and apply an embedding level to each character. The comment-codes
			mark the according step in the official algorithm. *)
			textReader.SetDirection(1);
			textReader.SetPosition(start);
			amm.NewString(charType);
			amm.NewString(hlCharacterType);

			WHILE (textReader.GetPosition() < end) DO
				textReader.ReadCh(char);
				unicodePropertyReader.GetBidiCharacterType(char,charType);
				(* perform a normal step if HL3 is undefined for this position or perform the algorithm of the HL3 *)
				IF (HL3 = NIL) OR
					~HL3(cacheElement.characters,cacheElement.characterEmbeddingLevels,cacheElement.originalCharacterTypes,cacheElement.characterTypes,
							char,charType,hlCharacterType,hlEmbeddingLevel) THEN
					(* X2 *)
					IF charType^ = "RLE" THEN
						GetNextOddEmbeddingLevel(embeddingLevels.Top(), nextLevel);
						IF (embeddingLevels.Top() # nextLevel) THEN
							embeddingLevels.Push(nextLevel);
							overrideStati.Push(DOSNeutral);
						ELSE
							INC(surplusLevels);
						END;
						cacheElement.characterTypes[i] := Strings.NewString("BN");
					(* X3 *)
					ELSIF charType^ = "LRE" THEN
						GetNextEvenEmbeddingLevel(embeddingLevels.Top(), nextLevel);
						IF (embeddingLevels.Top() # nextLevel) THEN
							embeddingLevels.Push(nextLevel);
							overrideStati.Push(DOSNeutral);
						ELSE
							INC(surplusLevels);
						END;
						cacheElement.characterTypes[i] := Strings.NewString("BN");
					(* X4 *)
					ELSIF charType^ = "RLO" THEN
						GetNextOddEmbeddingLevel(embeddingLevels.Top(), nextLevel);
						IF (embeddingLevels.Top() # nextLevel) THEN
							embeddingLevels.Push(nextLevel);
							overrideStati.Push(DOSRightToLeft);
						ELSE
							INC(surplusLevels);
						END;
						cacheElement.characterTypes[i] := Strings.NewString("BN");
					(* X5 *)
					ELSIF charType^ = "LRO" THEN
						GetNextEvenEmbeddingLevel(embeddingLevels.Top(), nextLevel);
						IF (embeddingLevels.Top() # nextLevel) THEN
							embeddingLevels.Push(nextLevel);
							overrideStati.Push(DOSLeftToRight);
						ELSE
							INC(surplusLevels);
						END;
						cacheElement.characterTypes[i] := Strings.NewString("BN");
					(* X7 *)
					ELSIF charType^ = "PDF" THEN
						IF surplusLevels > 0 THEN
							DEC(surplusLevels);
						ELSE
							dummyEmbeddingLevel := embeddingLevels.Pop();
							IF (embeddingLevels.Size() < 1) THEN
								embeddingLevels.Push(dummyEmbeddingLevel);
							END;

							dummyOverrideStatus := overrideStati.Pop();
							IF (overrideStati.Size() < 1) THEN
								overrideStati.Push(dummyOverrideStatus);
							END;
						END;

						cacheElement.characterTypes[i] := Strings.NewString("BN");
					(* X6 *)
					ELSE
						(* check the previously gathered information and change the character types accordingly *)
						IF (overrideStati.Top() = DOSNeutral) THEN
							amm.NewCharacterType(cacheElement.characterTypes[i]);
							Strings.Copy(charType^,0,LEN(charType),cacheElement.characterTypes[i]^);
						ELSIF (overrideStati.Top() = DOSLeftToRight) THEN
							cacheElement.characterTypes[i] := Strings.NewString("L");
						ELSIF (overrideStati.Top() = DOSRightToLeft) THEN
							cacheElement.characterTypes[i] := Strings.NewString("R");
						END;
					END;

					cacheElement.characterEmbeddingLevels[i] := embeddingLevels.Top();
				ELSE
					amm.NewCharacterType(cacheElement.characterTypes[i]);
					Strings.Copy(hlCharacterType^,0,LEN(hlCharacterType),cacheElement.characterTypes[i]^);
					cacheElement.characterEmbeddingLevels[i] := hlEmbeddingLevel;
				END;

				amm.NewCharacterType(cacheElement.originalCharacterTypes[i]);
				Strings.Copy(charType^,0,LEN(charType),cacheElement.originalCharacterTypes[i]^);
				cacheElement.characters[i] := char;
				INC(i);
			END;
			amm.FreeString(hlCharacterType);
			amm.FreeString(charType);
			amm.FreeIntegerStack(embeddingLevels);
			amm.FreeIntegerStack(overrideStati);

			(* Note, that X8 needs not to be done explicitly since paragraphs are concidered individually. X9 is ignored
				and therefore special rules apply further on. *)

			(* apply the gathered information to the cache entry *)
			cacheElement.lineLength := lineLength;
			amm.NewBoolArray(cacheElement.dirty,lineLength);
			amm.NewTextReaderArray(cacheElement.textReaders,lineLength);
			amm.NewPosArrays(cacheElement.posArrays,lineLength);
			amm.NewPosArrays(cacheElement.reversePosArrays,lineLength);
		END ApplyExplicitLevels;

		(* Scans through the text and resolves all weak types *)
		PROCEDURE ResolveWeakTypes(VAR cacheElement : LineElement);
		VAR
			i, nextI, pos : SIZE;
			state, ENstate : LONGINT;
			passedBNs : IntegerStack;
			charType : Strings.String;
			lastCharType : Strings.String;
			lastStrongType : LONGINT;
			newLevel : BOOLEAN;
			dummyBool : BOOLEAN;
			dummyInt : LONGINT;
		BEGIN
			lastStrongType := NeutralType;
			newLevel := FALSE;
			amm.NewString(lastCharType);
			GetBorderOfRunCharacterType(cacheElement.characterEmbeddingLevels[0],cacheElement.paragraphEmbeddingLevel,lastCharType);

			(* W1. - W3. Non-spacing marks, European numbers, pt. I and Arabic numbers *)
			FOR i := 0 TO cacheElement.lineLength - 1 DO

				(* HL5. provide artificial context if necessary *)
				IF HL5 # NIL THEN
					dummyBool := HL5(cacheElement,i,lastCharType,lastStrongType,dummyInt,WeakTypes1);
				END;


				(* W1. *)
				IF cacheElement.characterTypes[i]^ = "NSM" THEN
					Strings.Copy(lastCharType^,0,MIN(LEN(cacheElement.characterTypes[i]),LEN(lastCharType)),cacheElement.characterTypes[i]^);
				END;

				(* border of two runs *)
				IF (i < cacheElement.lineLength - 1) & (cacheElement.characterEmbeddingLevels[i] # cacheElement.characterEmbeddingLevels[i+1]) THEN
					GetBorderOfRunCharacterType(cacheElement.characterEmbeddingLevels[i],cacheElement.characterEmbeddingLevels[i+1],lastCharType);
					lastStrongType := NeutralType;
					newLevel := TRUE;
				END;

				(* W3. *)
				IF cacheElement.characterTypes[i]^ = "AL" THEN
					IF ~newLevel THEN
						lastCharType^ := "R";
						lastStrongType := ArabicNumber;
					END;
					cacheElement.characterTypes[i]^ := "R";

				(* remember strong type for W2 *)
				ELSIF IsStrongCharacterType(cacheElement.characterTypes[i]) & ~newLevel THEN
					Strings.Copy(cacheElement.characterTypes[i]^,0,MIN(LEN(cacheElement.characterTypes[i]),LEN(lastCharType)),lastCharType^);
					lastStrongType := NeutralType;

				(* W2. remember the new type for W1 *)
				ELSIF cacheElement.characterTypes[i]^ = "EN" THEN
					(* set AN/EN explicitly if HL2 is defined *)
					IF HL2 = NIL THEN
						IF lastStrongType = ArabicNumber THEN
							cacheElement.characterTypes[i]^ := "AN";
							lastCharType^ := "AN";
						END;
					ELSE
						charType := HL2(cacheElement,i,lastStrongType);
						Strings.Copy(charType^,0,MIN(LEN(cacheElement.characterTypes[i]),LEN(charType)),cacheElement.characterTypes[i]^);
						Strings.Copy(charType^,0,MIN(LEN(lastCharType),LEN(charType)),lastCharType^);
					END;

				(* remember character type for W1, exept for BN *)
				ELSIF cacheElement.characterTypes[i]^ # "BN" THEN
					Strings.Copy(cacheElement.characterTypes[i]^,0,MIN(LEN(cacheElement.characterTypes[i]),LEN(lastCharType)),lastCharType^);
				END;
				newLevel := FALSE;
			END;


			(* W4. - W7. Separators, Terminators and European Numbers, pt. II *)
			(* start with a neutral state and a European Number state according to the first run's sor *)
			state := NeutralType;
			GetBorderOfRunCharacterType(cacheElement.characterEmbeddingLevels[0],cacheElement.paragraphEmbeddingLevel,lastCharType);
			IF lastCharType^ = "L" THEN
				ENstate := LeftStrongType;
			ELSE
				ENstate := NeutralType;
			END;

			(* the stack is used to gather Boundary Neutrals on the way the may be changed according to a following character *)
			amm.NewIntegerStack(passedBNs,cacheElement.lineLength);
			nextI := 0;
			FOR i := 0 TO cacheElement.lineLength - 1 DO

				(* HL5. provide artificial context if necessary *)
				IF HL5 # NIL THEN
					dummyBool := HL5(cacheElement,i,lastCharType,state,ENstate,WeakTypes2);
				END;

				(* W7. & remember state for W4 and W5 *)
				IF cacheElement.characterTypes[i]^ = "EN" THEN
					IF ENstate = LeftStrongType THEN
						cacheElement.characterTypes[i]^ := "L";
					END;
					state := EuropeanNumber;
					passedBNs.Purge;

				(* remember state for W4 *)
				ELSIF cacheElement.characterTypes[i]^ = "AN" THEN
				 	state := ArabicNumber;
				 	passedBNs.Purge;

				(* push a BN onto the BN stack *)
				ELSIF cacheElement.characterTypes[i]^ = "BN" THEN
					passedBNs.Push(i);

				(* W4. European Separator *)
				ELSIF cacheElement.characterTypes[i]^ = "ES" THEN

					(* if the last character was a European Number, apply some changes *)
					IF state = EuropeanNumber THEN

						(* if the next character (ignoring BNs) is a European Number, the character may be changed *)
						IF IsEuropeanNumberAdjacent(i+1,FALSE,cacheElement,nextI,state,ENstate) THEN

							(* W7 *)
							IF ENstate = LeftStrongType THEN
								cacheElement.characterTypes[i]^ := "L";
							ELSE
								cacheElement.characterTypes[i]^ := "EN";
							END;

						(* or turned to Other Neutral otherwise *)
						ELSE
							cacheElement.characterTypes[i]^ := "ON";
						END;
						i := nextI;

					(* or turn the character to Other Neutral otherwise *)
					ELSE
						cacheElement.characterTypes[i]^ := "ON";
					END;

					(* all BNs since the last 'real' character turn to Other Neutral *)
					LOOP
						pos := passedBNs.Pop();
						IF pos < 0 THEN
							EXIT;
						ELSE
							cacheElement.characterTypes[pos]^ := "ON";
						END;
					END;

				(* W4.  Common Separator *)
				ELSIF cacheElement.characterTypes[i]^ = "CS" THEN

					(* if the last character was a European Number, apply some changes *)
					IF state = EuropeanNumber THEN

						(* if the next character (ignoring BNs) is a European Number, the character may be changed *)
						IF IsEuropeanNumberAdjacent(i+1,FALSE,cacheElement,nextI,state,ENstate) THEN

							(* W7 *)
							IF ENstate = LeftStrongType THEN
								cacheElement.characterTypes[i]^ := "L";
							ELSE
								cacheElement.characterTypes[i]^ := "EN";
							END;

						(* or turned to Other Neutral otherwise *)
						ELSE
							cacheElement.characterTypes[i]^ := "ON";
						END;
						i := nextI;

					(* if the last character was an Arabic Number, apply some changes *)
					ELSIF state = ArabicNumber THEN

						(* if the next character (ignoring BNs) is an Arabic Number, the character may be changed to AN *)
						IF IsArabicNumberAdjacent(i+1,cacheElement,nextI,state,ENstate) THEN
							cacheElement.characterTypes[i]^ := "AN";

						(* or to ON otherwise *)
						ELSE
							cacheElement.characterTypes[i]^ := "ON";
						END;
						i := nextI;

					(* if the last character was neither a European nor an Arabic Number, the character becomes ON *)
					ELSE (* state = NeutralType *)
						cacheElement.characterTypes[i]^ := "ON";
					END;

					(* all BNs since the last 'real' character turn to Other Neutral *)
					LOOP
						pos := passedBNs.Pop();
						IF pos < 0 THEN
							EXIT;
						ELSE
							cacheElement.characterTypes[pos]^ := "ON";
						END;
					END;

				(* W5. *)
				ELSIF cacheElement.characterTypes[i]^ = "ET" THEN

					(* if the last character was a European Number, apply some changes *)
					IF state = EuropeanNumber THEN

						(* W7 *)
						IF ENstate = LeftStrongType THEN
							cacheElement.characterTypes[i]^ := "L";

							(* all BNs since the last 'real' character turn to L *)
							LOOP
								pos := passedBNs.Pop();
								IF pos < 0 THEN
									EXIT;
								ELSE
									cacheElement.characterTypes[pos]^ := "L";
								END;
							END;
						ELSE
							cacheElement.characterTypes[i]^ := "EN";

							(* all BNs since the last 'real' character turn to EN *)
							LOOP
								pos := passedBNs.Pop();
								IF pos < 0 THEN
									EXIT;
								ELSE
									cacheElement.characterTypes[pos]^ := "EN";
								END;
							END;
						END;

					(* look for the character following the sequence of ETs and BNs *)
					ELSE
						(* if it is a European Number, apply some changes *)
						IF IsEuropeanNumberAdjacent(i+1,TRUE,cacheElement,nextI,state,ENstate) THEN

							(* W7 *)
							IF ENstate = LeftStrongType THEN

								(* all BNs since the last 'real' character turn to L *)
								cacheElement.characterTypes[i]^ := "L";
								LOOP
									pos := passedBNs.Pop();
									IF pos < 0 THEN
										EXIT;
									ELSE
										cacheElement.characterTypes[pos]^ := "L";
									END;
								END;
							ELSE
								cacheElement.characterTypes[i]^ := "EN";

								(* all BNs since the last 'real' character turn to EN *)
								LOOP
									pos := passedBNs.Pop();
									IF pos < 0 THEN
										EXIT;
									ELSE
										cacheElement.characterTypes[pos]^ := "EN";
									END;
								END;
							END;

						(* or change them to Other Neutral otherwise *)
						ELSE
							cacheElement.characterTypes[i]^ := "ON";

							(* all BNs since the last 'real' character turn to ON *)
							LOOP
								pos := passedBNs.Pop();
								IF pos < 0 THEN
									EXIT;
								ELSE
									cacheElement.characterTypes[pos]^ := "ON";
								END;
							END;
						END;
						i := nextI;
					END;

				(* otherwise inspect the character and change the states accordingly *)
				ELSE
					IF cacheElement.characterTypes[i]^ = "L" THEN
						ENstate := LeftStrongType;
					ELSIF cacheElement.characterTypes[i]^ = "R" THEN
						ENstate := NeutralType;
					END;
					state := NeutralType;
					passedBNs.Purge;
				END;

				(* border of two runs *)
				IF (i < cacheElement.lineLength - 1) & (cacheElement.characterEmbeddingLevels[i] # cacheElement.characterEmbeddingLevels[i+1]) THEN
					amm.NewString(charType);
					GetBorderOfRunCharacterType(cacheElement.characterEmbeddingLevels[i],cacheElement.characterEmbeddingLevels[i+1],charType);
					IF charType^ = "L" THEN
						ENstate := LeftStrongType;
					ELSE
						ENstate := NeutralType;
					END;
					amm.FreeString(charType);
				END;
			END;
			amm.FreeString(lastCharType);
			amm.FreeIntegerStack(passedBNs);
		END ResolveWeakTypes;

		(* Scan through the text and resolve neutral types *)
		PROCEDURE ResolveNeutralTypes(VAR cacheElement : LineElement);
		VAR
			i : SIZE;
			directionalType, hlCharacterType : Strings.String;
			dummyInt : LONGINT;
		BEGIN

			amm.NewString(directionalType);
			amm.NewString(hlCharacterType);

			(* iterate through all characters of the paragraph *)
			FOR i := 0 TO cacheElement.lineLength - 1 DO

				(* if the character has a Neutral type, apply some changes *)
				IF (IsNeutralCharacterType(cacheElement.characterTypes[i])) THEN

					(* compute the directional type of the last character, consider borders of run, consider HL5 if necessary *)
					IF (HL5 # NIL) & HL5(cacheElement,i,hlCharacterType,dummyInt,dummyInt,NeutralTypes) THEN
						Strings.Copy(hlCharacterType^,0,LEN(hlCharacterType),directionalType^);
					ELSIF (i = 0) THEN
						GetFinalDirectionalType(cacheElement.characterTypes[i],cacheElement.characterEmbeddingLevels[i],cacheElement.paragraphEmbeddingLevel,directionalType);
					ELSE
						GetFinalDirectionalType(cacheElement.characterTypes[i],cacheElement.characterEmbeddingLevels[i],cacheElement.characterEmbeddingLevels[i-1],directionalType);
					END;

					(* N1. & N2.  if the next non-Neutral character has the same directional type change the whole sequence of Neutrals to that type *)
					IF (HasSameDirectionalType(directionalType,i+1,cacheElement)) THEN
						WHILE (i < cacheElement.lineLength) & (IsNeutralCharacterType(cacheElement.characterTypes[i])) DO
							Strings.Copy(directionalType^,0,LEN(directionalType),cacheElement.characterTypes[i]^);
							INC(i);
						END;

					(* or change it to the embedding level otherwise *)
					ELSE
						WHILE (i < cacheElement.lineLength) & (IsNeutralCharacterType(cacheElement.characterTypes[i])) DO
							GetBorderOfRunCharacterType(cacheElement.characterEmbeddingLevels[i],cacheElement.characterEmbeddingLevels[i]-1,cacheElement.characterTypes[i]);
							INC(i);
						END;
					END;
				END;
			END;

			amm.FreeString(directionalType);
			amm.FreeString(hlCharacterType);
		END ResolveNeutralTypes;


		(* Scan through the text and resolve implicit levels *)
		PROCEDURE ResolveImplicitLevels(VAR cacheElement : LineElement);
		VAR
			i : SIZE;
		BEGIN

			(* iterate through all characters of the paragraph *)
			FOR i := 0 TO cacheElement.lineLength - 1 DO

				(* I2. if the current embedding level is odd increase the level of all L, EN and AN characters by 1 *)
				IF (ODD(cacheElement.characterEmbeddingLevels[i])) THEN
					IF (cacheElement.characterTypes[i]^ = "L") OR (cacheElement.characterTypes[i]^ = "EN") OR (cacheElement.characterTypes[i]^ = "AN") THEN
						INC(cacheElement.characterEmbeddingLevels[i]);
					END;

				(* I1. increase all R characters by 1 and all AN and EN characters by 2 otherwise *)
				ELSE
					IF cacheElement.characterTypes[i]^ = "R" THEN
						INC(cacheElement.characterEmbeddingLevels[i]);
					ELSIF (cacheElement.characterTypes[i]^ = "AN") OR (cacheElement.characterTypes[i]^ = "EN") THEN
						INC(cacheElement.characterEmbeddingLevels[i],2);
					END;
				END;
			END;

		END ResolveImplicitLevels;

		(* Reorder an already reformatted line. The line is not necessarily the same line that has been reformatted before
			but a whole part of it. *)
		PROCEDURE ReorderLine*(start, length : SIZE) : Texts.TextReader;
		VAR
			cacheElement : LineElement;
		BEGIN

			(* if the text has not been reformatted yet or isn't even formatted in UTF, do nothing *)
			IF ~reformatted OR ~textReader.text.isUTF THEN
				RETURN NIL;
			END;

			(* get the cache entry by the start position of the line *)
			lineCache.FindElement(start,cacheElement);

			(* reorder the line *)
			RETURN ReorderClause(cacheElement,start,length);
		END ReorderLine;

		(* Reorder an already reformatted segment. *)
		PROCEDURE ReorderSegment*(id : SIZE) : Texts.TextReader;
		VAR
			cacheElement : LineElement;
		BEGIN
			IF ~reformatted OR ~textReader.text.isUTF OR ~HL4 OR (segmentCache = NIL) THEN
				RETURN NIL;
			END;

			(* get the cache entry by the id of the segment *)
			segmentCache.FindElement(id,cacheElement);

			(* reorder the segment *)
			RETURN ReorderClause(cacheElement,cacheElement.pos,cacheElement.lineLength);
		END ReorderSegment;

		(* Reorders a part of the text (either a single line or a predefined segment *)
		PROCEDURE ReorderClause(VAR cacheElement : LineElement; start, length : SIZE) : Texts.TextReader;
		VAR
			bidiTextReader : Texts.TextReader;
			reorderedText : Texts.Text;
			posArray, reversePosArray : PosArray;
			i, newPos : SIZE;
			relStart: SIZE;
			maxLevel, minLevel : SIZE;
			oneCharString : Texts.PUCS32String;
			lastChar : Strings.String;
		BEGIN

			relStart := start - cacheElement.pos;

			(* if the paragraph is empty, nothing is to be done *)
			IF cacheElement.paragraphEmbeddingLevel = -1 THEN
				RETURN NIL;
			END;

			IF relStart >= cacheElement.lineLength THEN
				RETURN NIL;
			END;

			(* if this line has already been reordered, use the cached, reordered line *)
			IF ~cacheElement.dirty[relStart]  THEN
				RETURN cacheElement.textReaders[relStart];
			END;

			(* the length of the text cannot be longer than the actual line *)
			length := MIN(length,cacheElement.lineLength-relStart);

			IF CharacterDebugging THEN
				KernelLog.Ln;
				KernelLog.String("Reordering line ("); KernelLog.Int(start,4); KernelLog.String(",");
				KernelLog.Int(start+length-1,4); KernelLog.String(")..."); KernelLog.Ln;
			END;

			IF CharacterDebugging THEN PrintLineEmbeddingLevels(cacheElement.characterEmbeddingLevels); END;

			(* L1. Reset trailing whitespaces to the paragraph embedding level *)
			i := length - 1;
			LOOP
				IF (i < relStart) OR ~IsNeutralCharacterType(cacheElement.originalCharacterTypes[i]) THEN
					EXIT;
				ELSE
					cacheElement.characterEmbeddingLevels[i] := cacheElement.paragraphEmbeddingLevel;
					DEC(i);
				END;
			END;

			(* L2. Reordering *)
			maxLevel := GetHighestLevel(relStart,length,cacheElement.characterEmbeddingLevels^);
			minLevel := GetLowestOddLevel(relStart,length,cacheElement.characterEmbeddingLevels^);

			lastChar := cacheElement.originalCharacterTypes[relStart+length-1];


			(* fill the position array with its 'normal' positions *)
			IF lastChar^ = "B" THEN
				amm.NewPosArray(cacheElement.posArrays[relStart],length);
				posArray := cacheElement.posArrays[relStart];
				FillPositionArray(relStart,posArray.array^);

			(* iterate through all levels from the highest to the lowest, odd level *)
				FOR i := maxLevel TO minLevel BY - 1 DO
					ReorderSubstrings(relStart,i,maxLevel,cacheElement.characterEmbeddingLevels^,posArray,lastChar);
				END;

				(* fill the reverse position array *)
				amm.NewPosArray(cacheElement.reversePosArrays[relStart],length);
				reversePosArray := cacheElement.reversePosArrays[relStart];
			ELSE
				amm.NewPosArray(cacheElement.posArrays[relStart],length+1);
				posArray := cacheElement.posArrays[relStart];
				FillPositionArray(relStart,posArray.array^);

				(* iterate through all levels from the highest to the lowest, odd level *)
				FOR i := maxLevel TO minLevel BY - 1 DO
					ReorderSubstrings(relStart,i,maxLevel,cacheElement.characterEmbeddingLevels^,posArray,Strings.NewString("B"));
				END;

				(* fill the reverse position array *)
				amm.NewPosArray(cacheElement.reversePosArrays[relStart],length+1);
				reversePosArray := cacheElement.reversePosArrays[relStart];
			END;


			FOR i := 0 TO posArray.size - 1 DO
				reversePosArray.array[posArray.array[i] - relStart] := i;
			END;

			IF CharacterDebugging THEN PrintLineEmbeddingLevels(cacheElement.characterEmbeddingLevels); END;


			(* L4. Mirroring *)
			NEW(reorderedText);
			amm.NewUString(oneCharString);
			oneCharString[1] := 0H;

			(* read the characters from the cache and write them to a special text *)
			reorderedText.AcquireWrite;
			FOR i := 0 TO length - 1 DO
				newPos := posArray.array[i];
				oneCharString[0] := cacheElement.characters[newPos];

				(* use the mirrored character if necessary *)
				MirrorCharacter(oneCharString[0],cacheElement.characterEmbeddingLevels[newPos]);
				reorderedText.InsertUCS32(i,oneCharString^);
			END;
			reorderedText.ReleaseWrite;

			(* store the new text in a special text reader *)
			NEW(bidiTextReader,reorderedText);

			IF CharacterDebugging THEN
				KernelLog.Ln; KernelLog.String("Printing line reordered positions::"); KernelLog.Ln;
				FOR i := 0 TO posArray.size - 1 DO
					KernelLog.Int(posArray.array[i],3); KernelLog.String(" ");
				END;
				KernelLog.Ln;

				reorderedText.AcquireRead;
				PrintCodedLine(bidiTextReader,0,length);
				reorderedText.ReleaseRead;
				KernelLog.Ln; KernelLog.String("...reordering done! Text length: "); KernelLog.Int(length,4); KernelLog.Ln;
			END;

			(* mark this line not-dirty and put the gathered information to the cache *)
			cacheElement.dirty[relStart] := FALSE;
			cacheElement.textReaders[relStart] := bidiTextReader;

			amm.FreeUString(oneCharString);
			(* return the special text renderer with the reordered text *)
			RETURN bidiTextReader;
		END ReorderClause;


		(* Returns the position in the reordered text given its internal position and the start position of its line *)
		PROCEDURE GetDisplayPosition*(pos, lineStart : SIZE) : SIZE;
		VAR
			relPos, relLineStart : SIZE;
			cacheElement : LineElement;
			posArray : PosArray;
		BEGIN

			(* if the text has not been reformatted yet or isn't even formatted in UTF, do nothing *)
			IF ~reformatted OR ~textReader.text.isUTF THEN
				RETURN pos;
			END;

			(* avoid circling at line 0 *)
			IF pos < 0 THEN
				pos := 0
			END;

			(* get the cache entry and return the normal position if anything that's needed is not stored properly *)
			lineCache.FindElement(pos,cacheElement);
			IF (cacheElement = NIL) OR (cacheElement.reversePosArrays = NIL) OR (cacheElement.pos + cacheElement.lineLength <= pos) THEN
				RETURN pos;
			END;

			(* compute the relative position of the line start and the relative position inside the line *)
			relLineStart := lineStart - cacheElement.pos;
			relPos := pos - lineStart;

			(* get the appropriate reverse position array and return the bidi position if available *)
			posArray := cacheElement.reversePosArrays[relLineStart];

			IF posArray = NIL THEN
				RETURN pos;
			ELSE
				RETURN posArray.array[relPos] + lineStart;
			END;
		END GetDisplayPosition;

		(* Returns the internal position given its display position and the start position of its line *)
		PROCEDURE GetInternalPosition*(pos, lineStart : SIZE) : SIZE;
		VAR
			relPos, relLineStart : SIZE;
			cacheElement : LineElement;
			posArray : PosArray;
		BEGIN

			(* if the text has not been reformatted yet or isn't even formatted in UTF, do nothing *)
			IF ~reformatted OR ~textReader.text.isUTF THEN
				RETURN pos;
			END;

			(* get the cache entry and return the normal position if anything that's needed is not stored properly *)
			lineCache.FindElement(pos,cacheElement);
			IF (cacheElement = NIL) OR (cacheElement.posArrays = NIL) THEN
				RETURN pos;
			END;

			(* compute the relative position of the line start and the relative position inside the line *)
			relLineStart := lineStart - cacheElement.pos;
			relPos := pos - lineStart;

			(* get the appropriate position array and return the bidi position if available *)
			posArray := cacheElement.posArrays[relLineStart];

			IF posArray = NIL THEN
				RETURN pos
			ELSE
				IF relPos < posArray.size THEN

					RETURN posArray.array[relPos] + cacheElement.pos;
				ELSE

					RETURN posArray.array[posArray.size-1] + cacheElement.pos;
				END;
			END;
		END GetInternalPosition;

		(* Returns the characters implicit level *)
		PROCEDURE GetImplicitLevel*(pos : SIZE) : SIZE;
		VAR
			relPos : SIZE;
			cacheElement : LineElement;
		BEGIN

			(* if the text has not been reformatted yet or isn't even formatted in UTF, do nothing *)
			IF ~reformatted OR ~textReader.text.isUTF THEN
				RETURN 0;
			END;

			(* get the cache entry and return the normal position if anything that's needed is not stored properly *)
			lineCache.FindElement(pos,cacheElement);
			IF (cacheElement = NIL) OR (cacheElement.characterEmbeddingLevels = NIL) THEN

				RETURN MAX(0,cacheElement.paragraphEmbeddingLevel);
			END;

			IF cacheElement.pos + cacheElement.lineLength <= pos THEN
				RETURN cacheElement.characterEmbeddingLevels[cacheElement.lineLength-1];
			END;

			(* compute the relative position of the line start and the relative position inside the line *)
			relPos := pos - cacheElement.pos;

			(* get the appropriate position array and return the implicit level *)
			RETURN cacheElement.characterEmbeddingLevels[relPos];
		END GetImplicitLevel;

		(* Gets the embedding level of the pargraph the character is a part of *)
		PROCEDURE GetParagraphEmbeddingLevel*(pos : SIZE) : SIZE;
		VAR
			cacheElement : LineElement;
		BEGIN

			(* if the text has not been reformatted yet or isn't even formatted in UTF, do nothing *)
			IF ~reformatted OR ~textReader.text.isUTF THEN
				RETURN 0;
			END;

			(* get the cache entry and return the normal position if anything that's needed is not stored properly *)
			lineCache.FindElement(pos,cacheElement);
			IF (cacheElement = NIL) OR (cacheElement.paragraphEmbeddingLevel = -1) THEN
				RETURN 0;
			END;

			(* return the paragraph embedding level *)
			RETURN cacheElement.paragraphEmbeddingLevel;
		END GetParagraphEmbeddingLevel;




		(* Returns the cached text reader of a line if available *)
		PROCEDURE ReadyTextReader*(start : SIZE; VAR isFirst : BOOLEAN) : Texts.TextReader;
		VAR
			cacheElement : LineElement;
			relStart : SIZE;
		BEGIN

			(* if the text has not been reformatted yet or isn't even formatted in UTF, do nothing *)
			IF (~reformatted) OR ~textReader.text.isUTF THEN
				RETURN NIL;
			END;

			(* get the cache entry and the relative start position of the line inside the paragraph *)
			lineCache.FindElement(start,cacheElement);
			relStart := start - cacheElement.pos;

			(* if the paragraph is empty, nothing is to be done *)
			IF cacheElement.paragraphEmbeddingLevel = -1 THEN
				RETURN NIL;
			END;

			(* don't access the cache line if it's not the correct one *)
			IF relStart >= cacheElement.lineLength THEN
				RETURN NIL;
			END;

			(* if the line is not dirty, check if it is the first possible line in the paragraph and return the text reader *)
			IF ~cacheElement.dirty[relStart]  THEN
				isFirst := (relStart = 0);
				RETURN cacheElement.textReaders[relStart];
			END;

			RETURN NIL;
		END ReadyTextReader;

		(* Sets the a text reader to the cache at a certain position. This is only for contextually analyzed text readers! *)
		PROCEDURE SetReadyTextReader*(start : SIZE; textReader : Texts.TextReader);
		VAR
			cacheElement : LineElement;
			relStart : SIZE;
		BEGIN
			(* if the text has not been reformatted yet or isn't even formatted in UTF, do nothing *)
			IF (~reformatted) OR ~textReader.text.isUTF THEN
				RETURN;
			END;

			(* get the cache entry and the relative start position of the line inside the paragraph *)
			lineCache.FindElement(start,cacheElement);
			relStart := start - cacheElement.pos;

			(* don't access the cache line if it's not the correct one *)
			IF relStart >= cacheElement.lineLength THEN
				RETURN;
			END;

			cacheElement.textReaders[relStart] := textReader;
		END SetReadyTextReader;


		(* Checks if the given position is the last one of its line *)
		PROCEDURE IsLastCharacterInLine*(pos : SIZE) : BOOLEAN;
		VAR
			cacheElement : LineElement;
		BEGIN
			lineCache.FindElement(pos,cacheElement);

			RETURN pos = cacheElement.pos + cacheElement.lineLength - 1;
		END IsLastCharacterInLine;


		(* Finds the end of a paragraph. Since this procedure can be called before any reformatting, the cache can't be used *)
		PROCEDURE FindEndOfParagraph(pos : SIZE; VAR end : SIZE);
		VAR
			char : Texts.Char32;
			charType : Strings.String;
			textLength : SIZE;
		BEGIN

			(* initialize the text reader and some necessary variables *)
			char := 0H;
			textLength := textReader.text.GetLength();
			amm.NewString(charType);
			textReader.SetDirection(1);
			textReader.SetPosition(pos);

			(* scan through the text until a paragraph separator or the end of the text is reached *)
			REPEAT
				textReader.ReadCh(char);
				unicodePropertyReader.GetBidiCharacterType(char,charType);
			UNTIL (charType^ = "B") OR (char = UnicodeProperties.EOT) OR (textReader.GetPosition() >= textLength);

			end := textReader.GetPosition();
			amm.FreeString(charType);
		END FindEndOfParagraph;


		(* Finds the start of a paragraph. Since this procedure can be called before any reformatting, the cache can't be used *)
		PROCEDURE FindStartOfParagraph(pos : SIZE; VAR start : SIZE);
		VAR
			char : Texts.Char32;
			charType : Strings.String;
		BEGIN

			(* initialize the text reader *)
			textReader.SetPosition(pos-1);
			textReader.SetDirection(-1);
			amm.NewString(charType);

			(* scan through the text until a paragraph separator or the start of the text is reached *)
			REPEAT
				textReader.ReadCh(char);
				unicodePropertyReader.GetBidiCharacterType(char,charType);
			UNTIL (charType^ = "B") OR (textReader.GetPosition() <= 0);

			(* prepare the correct start position for each case *)
			IF charType^ # "B" THEN
				start := 0;
			ELSE
				start := textReader.GetPosition() + 2;
			END;
			amm.FreeString(charType);
		END FindStartOfParagraph;


		(* Mirrors a character if the rules allow it. A character is only mirrored if the current embedding level is odd
			and the 'mirrored' property of the character is true. Consider HL6 if necessary. *)
		PROCEDURE MirrorCharacter(VAR originalChar : Texts.Char32; embeddingLevel : SIZE);
		BEGIN
			IF ODD(embeddingLevel) & unicodePropertyReader.IsMirroredChar(originalChar) THEN
				originalChar := mirrorPropertyReader.GetMirroredChar(originalChar);
			ELSIF ODD(embeddingLevel) & (HL6 # NIL) THEN
				originalChar := HL6(originalChar);
			END;
		END MirrorCharacter;


		(* Reverts all substrings between the minimum and the maximum level *)
		PROCEDURE ReorderSubstrings(globalStart, fromLevel, toLevel : SIZE; CONST levels : ARRAY OF SIZE; VAR posArray : PosArray; lastCharType : Strings.String);
		VAR
			i, start, end : SIZE;
		BEGIN

			(* shortcut for arrays of length 1 *)
			IF posArray.size = 1 THEN
				RETURN;
			END;

			(* compute the correct end *)
			IF lastCharType^ = "B" THEN
				end := posArray.size - 2;
			ELSE
				end := posArray.size - 1;
			END;

			(* iterate through the characters of the line *)
			FOR i := globalStart TO globalStart + end DO

				(* if the current level is higher than the minimum level, start the substring to be reverted here *)
				IF (levels[i] >= fromLevel) THEN
					start := i;

					(* look for an appropriate end of the substring *)
					REPEAT
						INC(i);
					UNTIL (i > globalStart + end) OR (levels[i] < fromLevel);

					(* revert the substring *)
					IF posArray.size > (i - globalStart) THEN
						SwapSubstring(start-globalStart,i-start-1,posArray.array^);
					END;
				END;
			END;
		END ReorderSubstrings;


		(* Revert the substring marked by its start position and its length *)
		PROCEDURE SwapSubstring(start, end: SIZE; VAR posArray : ARRAY OF SIZE);
		VAR
			i : SIZE;
		BEGIN
			FOR i := 0 TO (end+1) DIV 2 - 1 DO
				SwapPositions(start+i,start+end-i,posArray);
			END;
		END SwapSubstring;

		(* Swap two entries in the position array *)
		PROCEDURE SwapPositions(pos1, pos2 : SIZE; VAR posArray : ARRAY OF SIZE);
		VAR
			temp : SIZE;
		BEGIN
			temp := posArray[pos1];
			posArray[pos1] := posArray[pos2];
			posArray[pos2] := temp;
		END SwapPositions;

		(* Fill a line's position array with its real positions *)
		PROCEDURE FillPositionArray(start : SIZE; VAR posArray : ARRAY OF SIZE);
		VAR
			i : SIZE;
		BEGIN
			FOR i := 0 TO LEN(posArray) - 1 DO
				posArray[i] := start + i;
			END;
		END FillPositionArray;

		(* Look through a level array and find its maximum entry *)
		PROCEDURE GetHighestLevel(start, length : SIZE; CONST levels : ARRAY OF SIZE) : SIZE;
		VAR
			i, max: SIZE;
		BEGIN
			max := 0;
			FOR i := start TO start+length - 1 DO
				IF i > LEN(levels) - 1 THEN
					RETURN max;
				END;

				IF (levels[i] > max) THEN
					max := levels[i];
				END;
			END;
			RETURN max;
		END GetHighestLevel;

		(* Look through a level array and find its minimum odd entry *)
		PROCEDURE GetLowestOddLevel(start, length : SIZE; CONST levels : ARRAY OF SIZE) : SIZE;
		VAR
			i, min: SIZE;
		BEGIN
			min := 61;
			FOR i := start TO start + length - 1 DO
				IF i > LEN(levels) - 1 THEN
					RETURN min;
				END;

				IF (levels[i] < min) & ODD(levels[i]) THEN
					min := levels[i];
				END;
			END;
			RETURN min;
		END GetLowestOddLevel;



		(* Computes the next even level which is not higher than 60 *)
		PROCEDURE GetNextEvenEmbeddingLevel(thisLevel : SIZE; VAR nextLevel : SIZE);
		BEGIN
			IF thisLevel > 59 THEN
				nextLevel := thisLevel;
				RETURN;
			END;

			IF (ODD(thisLevel)) THEN
				nextLevel := thisLevel + 1;
			ELSE
				nextLevel := thisLevel + 2;
			END;
		END GetNextEvenEmbeddingLevel;

		(* Computes the next odd level which is not higher than 61 *)
		PROCEDURE GetNextOddEmbeddingLevel(thisLevel : SIZE; VAR nextLevel : SIZE);
		BEGIN
			IF thisLevel > 60 THEN
				nextLevel := thisLevel;
				RETURN;
			END;

			IF (ODD(thisLevel)) THEN
				nextLevel := thisLevel + 2;
			ELSE
				nextLevel := thisLevel + 1;
			END;
		END GetNextOddEmbeddingLevel;


		(* Returns the character type of the higher of two levels *)
		PROCEDURE GetBorderOfRunCharacterType(thisLevel, otherLevel : SIZE; VAR result : Strings.String);
		BEGIN
			IF (ODD(MAX(thisLevel,otherLevel))) THEN
				result^ := "R";
			ELSE
				result^ := "L";
			END;
		END GetBorderOfRunCharacterType;

		(* Checks if the next non-separator/non-terminator is a European Number *)
		PROCEDURE IsEuropeanNumberAdjacent(pos : SIZE; terminators : BOOLEAN; VAR cacheElement : LineElement; VAR max : SIZE; VAR state : LONGINT; VAR ENstate : LONGINT) : BOOLEAN;
		VAR
			ENstateBefore : LONGINT;
			hlThisCharacterType : Strings.String;
		BEGIN
			amm.NewString(hlThisCharacterType);

			(* remember the current state *)
			ENstateBefore := ENstate;

			(* HL5 - consider artificial context *)
			IF (HL5 # NIL) & HL5(cacheElement,pos,hlThisCharacterType,state,ENstate,EuropeanNumberAdj) THEN
				IF hlThisCharacterType^ = "EN" THEN

					(* remember the state and the current position *)
					max := pos;
					amm.FreeString(hlThisCharacterType);
					RETURN TRUE;
				END;
			END;
			amm.FreeString(hlThisCharacterType);

			(* if the position is invalid, return false *)
			IF (pos < 0) OR (pos >= cacheElement.lineLength) THEN
				RETURN FALSE;

			(* if the current character is a European number return true *)
			ELSIF cacheElement.characterTypes[pos]^ = "EN" THEN

				(* W7 *)
				IF ENstate = LeftStrongType THEN
					cacheElement.characterTypes[pos]^ := "L";
				END;

				(* remember the state and the current position *)
				max := pos;
				state := EuropeanNumber;
				RETURN TRUE;

			(* if the scanned sequence consists of terminators/BNs and the next character is a terminator too, look further *)
			ELSIF terminators & ((cacheElement.characterTypes[pos]^ = "ET") OR (cacheElement.characterTypes[pos]^ = "BN")) THEN

				(* if the character following the current sequence is a European Number, return true *)
				IF IsEuropeanNumberAdjacent(pos + 1,terminators,cacheElement,max,state,ENstate) THEN

					(* W7 - according to the remembered state *)
					IF ENstateBefore = LeftStrongType THEN
						cacheElement.characterTypes[pos]^ := "L";
					ELSE
						cacheElement.characterTypes[pos]^ := "EN";
					END;
					RETURN TRUE;

				(* or change it to Other Neutral otherwise *)
				ELSE
					cacheElement.characterTypes[pos]^ := "ON";
					RETURN FALSE;
				END;

			(* if the scanned sequence consists of separators and the next character is a BN look further *)
			ELSIF ~terminators & (cacheElement.characterTypes[pos]^ = "BN") THEN

				(* change the BN to Other Neutral *)
				cacheElement.characterTypes[pos]^ := "ON";
				RETURN IsEuropeanNumberAdjacent(pos + 1,terminators,cacheElement,max,state,ENstate);

			(* if the scanned sequence consisits of separators and the next character is not a BN and not a European Number, return false *)
			ELSE
				(* remember the current position and the current state *)
				max := pos;
				IF cacheElement.characterTypes[pos]^ = "AN" THEN
					state := ArabicNumber;
				ELSE
					state := NeutralType;
					IF cacheElement.characterTypes[pos]^ = "L" THEN
						ENstate := LeftStrongType;
					END;
				END;
				RETURN FALSE;
			END;
		END IsEuropeanNumberAdjacent;

		(* Checks if the next non-separator is an Arabic Number *)
		PROCEDURE IsArabicNumberAdjacent(pos : SIZE; VAR cacheElement : LineElement; VAR max : SIZE; VAR state : LONGINT; VAR ENstate : LONGINT) : BOOLEAN;
		VAR
			hlThisCharacterType : Strings.String;
		BEGIN
			amm.NewString(hlThisCharacterType);

			(* HL5 - consider artificial context *)
			IF (HL5 # NIL) & HL5(cacheElement,pos,hlThisCharacterType,state,ENstate,ArabicNumberAdj) THEN
				IF hlThisCharacterType^ = "AN" THEN

					(* remember the current position *)
					max := pos;
					amm.FreeString(hlThisCharacterType);
					RETURN TRUE;
				END;
			END;
			amm.FreeString(hlThisCharacterType);

			(* if the position is invalid, return false *)
			IF (pos < 0) OR (pos >= cacheElement.lineLength) THEN
				RETURN FALSE;

			(* if the current character is an Arabic Number, remember the state and return true *)
			ELSIF cacheElement.characterTypes[pos]^ = "AN" THEN
				state := ArabicNumber;
				max := pos;
				RETURN TRUE;

			(* if the current character is a Boundary Neutral, change it to Other Neutral and look further *)
			ELSIF cacheElement.characterTypes[pos]^ = "BN" THEN
				cacheElement.characterTypes[pos]^ := "ON";
				RETURN IsArabicNumberAdjacent(pos + 1,cacheElement,max,state,ENstate);

			(* in any other case remember the state and return false *)
			ELSE
				IF cacheElement.characterTypes[pos]^ = "EN" THEN

					(* W7 *)
					IF ENstate = LeftStrongType THEN
						cacheElement.characterTypes[pos]^ := "L";
					END;
					state := EuropeanNumber;
				ELSE
					IF cacheElement.characterTypes[pos]^ = "L" THEN
						ENstate := LeftStrongType;
					ELSIF cacheElement.characterTypes[pos]^ = "R" THEN
						ENstate := NeutralType;
					END;
					state := NeutralType;
				END;
				max := pos;
				RETURN FALSE;
			END;
		END IsArabicNumberAdjacent;


		(* Finds the first strong character from 'start' on without using the cache *)
		PROCEDURE FindFirstStrongCharacter(start, end : SIZE; VAR charType : Strings.String);
		VAR
			char : Texts.Char32;
			strongCharFound : BOOLEAN;
		BEGIN

			(* initialize the text reader and some auxiliary variables *)
			char := 0H;
			strongCharFound := FALSE;
			textReader.SetPosition(start);
			textReader.SetDirection(1);

			(* scan through the text until a strong character is found or the end of the paragraph is reached *)
			REPEAT
				textReader.ReadCh(char);
				strongCharFound := IsStrongCharacter(char,charType);
			UNTIL (strongCharFound) OR (textReader.GetPosition() >= end);

			(* if no character was found nullify the result *)
			IF ~strongCharFound THEN
				charType := NIL;
			END;
		END FindFirstStrongCharacter;


		(* Checks if a certain character has a Strong type and remembers that type *)
		PROCEDURE IsStrongCharacter(CONST char : Texts.Char32; VAR charType : Strings.String) : BOOLEAN;
		BEGIN
			unicodePropertyReader.GetBidiCharacterType(char,charType);
			RETURN IsStrongCharacterType(charType);
		END IsStrongCharacter;

		(* Checks if a certain character type is defined as Strong (L, AL or R) *)
		PROCEDURE IsStrongCharacterType(CONST charType : Strings.String) : BOOLEAN;
		BEGIN
			RETURN (charType^ = "L") OR (charType^ = "AL") OR (charType^ = "R");
		END IsStrongCharacterType;

		(* Checks if a ceratin character type is defined as Neutral (B, S, WS, ON or BN *)
		PROCEDURE IsNeutralCharacterType(CONST charType : Strings.String) : BOOLEAN;
		BEGIN
			RETURN (charType^ = "B") OR (charType^ = "S") OR (charType^ = "WS") OR (charType^ = "ON") OR (charType^ = "BN");
		END IsNeutralCharacterType;

		(* Returns the directional type considering borders of a run *)
		PROCEDURE GetFinalDirectionalType(charType : Strings.String; thisLevel, otherLevel : SIZE; VAR result : Strings.String);
		BEGIN

			(* if the current position is at a border run determine the sor *)
			IF (thisLevel # otherLevel) THEN
				GetBorderOfRunCharacterType(thisLevel,otherLevel,result);
				RETURN;

			(* or return the character type otherwise *)
			ELSIF charType^ = "L" THEN
				result^ := "L";
			ELSE
				result^ := "R";
			END;
		END GetFinalDirectionalType;


		(* Compares a directional type with the one of its non-Neutral successor *)
		PROCEDURE HasSameDirectionalType(charType : Strings.String; thisPos : SIZE; cacheElement : LineElement) : BOOLEAN;
		VAR
			hlThisCharacterType : Strings.String;
			dummyInt : LONGINT;
			dummyCharType : Strings.String;
			result : BOOLEAN;
		BEGIN
			amm.NewString(hlThisCharacterType);

			(* HL5 - consider artificial context *)
			IF (HL5 # NIL) & HL5(cacheElement,thisPos,hlThisCharacterType,dummyInt,dummyInt,SameDirection) THEN
				amm.FreeString(hlThisCharacterType);
				RETURN charType^ = hlThisCharacterType^;
			END;
			amm.FreeString(hlThisCharacterType);

			amm.NewString(dummyCharType);

			(* compare with the type of the paragraph embedding level at the end of the paragraph *)
			IF (thisPos = cacheElement.lineLength) THEN
				GetBorderOfRunCharacterType(cacheElement.characterEmbeddingLevels[thisPos-1],cacheElement.paragraphEmbeddingLevel,dummyCharType);
				result := charType = dummyCharType;
				amm.FreeString(dummyCharType);
				RETURN result;
			(* compare with the type of the sor at the beginning of a run *)
			ELSIF (cacheElement.characterEmbeddingLevels[thisPos-1] # cacheElement.characterEmbeddingLevels[thisPos]) THEN
				GetBorderOfRunCharacterType(cacheElement.characterEmbeddingLevels[thisPos-1],cacheElement.characterEmbeddingLevels[thisPos],dummyCharType);
				result := charType = dummyCharType;
				amm.FreeString(dummyCharType);
				RETURN result;
			(* compare with the next character if this one is Neutral *)
			ELSIF (IsNeutralCharacterType(cacheElement.characterTypes[thisPos])) THEN
				amm.FreeString(dummyCharType);
				RETURN HasSameDirectionalType(charType,thisPos+1,cacheElement);

			(* compare with this character *)
			ELSE
				GetFinalDirectionalType(cacheElement.characterTypes[thisPos-1],cacheElement.characterEmbeddingLevels[thisPos-1],cacheElement.characterEmbeddingLevels[thisPos],dummyCharType);
				result := charType = dummyCharType;
				amm.FreeString(dummyCharType);
				RETURN result;
			END;
		END HasSameDirectionalType;


		(* Scans the line cache for invalid lines and removes them *)
		PROCEDURE SweepCache;
		VAR
			thisPos, lastPos : SIZE;
			char : Texts.Char32;
			charType : Strings.String;
		BEGIN

			(* initialization: the first line doesn't need to be checked, since it can't be invalid under these terms *)
			lastPos := 0;
			amm.NewString(charType);

			LOOP
				(* get the next line *)
				thisPos := lineCache.GetNextPos(lastPos);

				(* exit if this was the last line or something unforeseen happens *)
				IF (thisPos = lastPos) OR (thisPos < 0) THEN EXIT END;

				(* read the last character of the last line *)
				textReader.SetPosition(thisPos-1);
				textReader.ReadCh(char);

				(* check the character type *)
				unicodePropertyReader.GetBidiCharacterType(char,charType);

				(* if the line is invalid, e.g. the last line doesn't end with a paragraph separator, remove it from the cache *)
				IF charType^ # "B" THEN
					lineCache.RemoveLine(thisPos);
				ELSE
					lastPos := thisPos;
				END;
			END;
			amm.FreeString(charType);
		END SweepCache;


		(* Print the whole text's original character types *)
		PROCEDURE PrintOriginalTypedText*;
		BEGIN
			PrintOriginalTypedParagraph(0,textReader.text.GetLength()-1);
		END PrintOriginalTypedText;


		(* Print a certain paragraph's original character types *)
		PROCEDURE PrintOriginalTypedParagraph(start,end : SIZE);
		VAR
			char : Texts.Char32;
			charType : Strings.String;
		BEGIN
			IF textReader.text = NIL THEN
				RETURN;
			END;

			amm.NewString(charType);
			KernelLog.Ln;
			KernelLog.String("Printing original character types:"); KernelLog.Ln;
			textReader.SetDirection(1);
			textReader.SetPosition(start);
			WHILE (textReader.GetPosition() < end) DO
				textReader.ReadCh(char);
				unicodePropertyReader.GetBidiCharacterType(char,charType);
				KernelLog.String(charType^); KernelLog.String(" ");
			END;
			KernelLog.Ln;
			amm.FreeString(charType);
		END PrintOriginalTypedParagraph;


		(* Print the whole text's character types after reformatting *)
		PROCEDURE PrintCurrentTypedText*;
		BEGIN
			PrintCurrentTypedParagraph(0,textReader.text.GetLength()-1);
		END PrintCurrentTypedText;


		(* Print a certain paragraph's character types after reformatting *)
		PROCEDURE PrintCurrentTypedParagraph(start, end : SIZE);
		VAR
			i : SIZE;
			type: Strings.String;
			cacheElement : LineElement;
		BEGIN
			lineCache.FindElement(start,cacheElement);

			KernelLog.Ln;
			KernelLog.String("Printing current character types:"); KernelLog.Ln;
			FOR i := 0 TO cacheElement.lineLength - 1 DO
				type := cacheElement.characterTypes[i];
				KernelLog.String(type^); KernelLog.String(" ");
			END;
			KernelLog.Ln;
		END PrintCurrentTypedParagraph;

		(* Print the whole text's character utf-codes *)
		PROCEDURE PrintCodedText*;
		BEGIN
			PrintCodedParagraph(0,textReader.text.GetLength()-1);
		END PrintCodedText;


		(* Print a certain paragraph's character utf-codes *)
		PROCEDURE PrintCodedParagraph(start, end : SIZE);
		VAR
			char : Texts.Char32;
		BEGIN
			IF textReader.text = NIL THEN
				RETURN;
			END;

			KernelLog.Ln;
			KernelLog.String("Printing character codes:"); KernelLog.Ln;
			textReader.SetDirection(1);
			textReader.SetPosition(start);
			WHILE (textReader.GetPosition() < end) DO
				textReader.ReadCh(char);
				KernelLog.Hex(char,9); KernelLog.String(" ");
			END;
			KernelLog.Ln;
		END PrintCodedParagraph;

		(* Print a certain line's character utf-codes *)
		PROCEDURE PrintCodedLine(textReader : Texts.TextReader; start, end : SIZE);
		VAR
			char : Texts.Char32;
		BEGIN
			IF textReader.text = NIL THEN
				RETURN;
			END;

			textReader.SetDirection(1);
			textReader.SetPosition(start);

			KernelLog.Ln;
			KernelLog.String("Printing line character codes:"); KernelLog.Ln;
			WHILE (textReader.GetPosition() < end) DO
				textReader.ReadCh(char);
				KernelLog.Hex(char,9); KernelLog.String(" ");
			END;
			KernelLog.Ln;
		END PrintCodedLine;

		(* Print the whole text's character embedding levels *)
		PROCEDURE PrintLeveledText*;
		BEGIN
			PrintLeveledParagraph(0,textReader.text.GetLength()-1);
		END PrintLeveledText;

		(* Print a certain paragraph's character embedding levels *)
		PROCEDURE PrintLeveledParagraph(start, end : SIZE);
		VAR
			i : SIZE;
			cacheElement : LineElement;
		BEGIN
			lineCache.FindElement(start,cacheElement);

			KernelLog.Ln;
			KernelLog.String("Printing resolved levels:"); KernelLog.Ln;
			FOR i := 0 TO cacheElement.lineLength - 1 DO
				KernelLog.Int(cacheElement.characterEmbeddingLevels[i],2); KernelLog.String(" ");
			END;
			KernelLog.Ln;
		END PrintLeveledParagraph;


		(* Print a certain line's character embedding levels *)
		PROCEDURE PrintLineEmbeddingLevels(CONST levels : IntegerArray);
		VAR
			i : SIZE;
		BEGIN
			KernelLog.Ln;
			KernelLog.String("Printing line levels:"); KernelLog.Ln;
			FOR i := 0 TO LEN(levels) - 1 DO
				KernelLog.Int(levels[i],2); KernelLog.String(" ");
			END;
			KernelLog.Ln;
		END PrintLineEmbeddingLevels;

	END BidiFormatter;


	(* The following procedure type declarations are used to define Higher Level Protocols. According to the Bidi-Algorithm
		they have a predefined tasks. If they are assigned by a client object, they are used automatically and the original
		algorithm is ignored if desired. It is important that the implementor of these functions knows exactly what he or her
		is doing because the behaviour of the algorithm is undefined if these functions do not what they're supposed to.
		For a better understanding the definitions of the original algorithms are quoted here. HL4 is not activated by setting
		the corresponding function but by setting the boolean value to true. *)

	(* HL1. Override P3, and set the paragraph level explicitly.
		The function has reading access to the whole text and gets the start and end position of the clause of interest. It returns
		the paragraph embedding level for this clause. *)
	HigherLevelProtocol1* = PROCEDURE(textReader : Texts.TextReader; start, end : SIZE) : LONGINT;

	(* HL2. Override W2, and set EN or AN explicitly.
		The function gets access to the whole cache line, the current position and the last strong type. It computes the character
		type for the character at the given position. *)
	HigherLevelProtocol2* = PROCEDURE(cacheLine : LineElement; pos: SIZE; lastStrongType : LONGINT) : Strings.String;

	(* HL3. Emulate directional overrides or embedding codes.
		The function gets access to the characters, previously computed embedding levels, original and newly computed character
		types of the whole clause, the current character and its character type. It redefines the character type and the embedding
		level, which will be assigned to the cache afterwards. If it returns false, the algorithm is performed normally for this character. *)
	HigherLevelProtocol3* = PROCEDURE(characters : CharArray; embeddingLevels : IntegerArray; originalTypes, types : Strings.StringArray;
							char : Texts.Char32; charType : Strings.String; VAR hlCharacterType : Strings.String;
							VAR hlEmbeddingLevel : LONGINT) : BOOLEAN;

	(* HL5. Provide artificial context.
		The function gets access to the whole cache line, the current position, the character type of the current character and
		the position in the algorithm where the function is called. It defines the current state and ENstate on which the algorithm
		will operate further on. If it returns false, the algorithm is performed normally for this character. *)
	HigherLevelProtocol5* = PROCEDURE(cacheElement : LineElement; pos : SIZE; VAR thisCharacterType : Strings.String;
							VAR state, ENstate : LONGINT; placeOfVenue : LONGINT) : BOOLEAN;

	(* HL6. Additional mirroring.
		The function gets the character that needs to be mirrored and returns the target, mirrored character. *)
	HigherLevelProtocol6* = PROCEDURE(originalChar : Texts.Char32) : Texts.Char32;


VAR
	showUnicodeControlCharacters* : BOOLEAN;


(* Exchanges non-printable control characters to a hardcoded printable sign. The list can easily be changed and extended. *)
PROCEDURE GetDisplayCharacter*(VAR char : Texts.Char32);
BEGIN
	IF ~showUnicodeControlCharacters THEN
		RETURN;
	END;

	(* LRM *)
	IF char = 200EH THEN
		char := 21BEH;
	(* RLM *)
	ELSIF char = 200FH THEN
		char := 21BFH;
	(* LRE *)
	ELSIF char = 202AH THEN
		char := 2308H;
	(* RLE *)
	ELSIF char = 202BH THEN
		char := 2309H;
	(* LRO *)
	ELSIF char = 202DH THEN
		char := 250DH;
	(* RLO *)
	ELSIF char = 202EH THEN
		char := 2511H;
	(* PDF *)
	ELSIF char = 202CH THEN
		char := 252FH;
	END;
END GetDisplayCharacter;





PROCEDURE TestReformatting*(context : Commands.Context);
VAR
	filename, fullname: ARRAY 256 OF CHAR;
	msg : ARRAY 512 OF CHAR;
	file : Files.File;
	decoder : Codecs.TextDecoder;
	in : Streams.Reader;
	decoderRes : WORD;
	text : Texts.Text;
	error : BOOLEAN;
	bidiFormatter : BidiFormatter;
	textReader : Texts.TextReader;

BEGIN
	error := FALSE;
	context.arg.SkipWhitespace; context.arg.String(filename);

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
		decoder := Codecs.GetTextDecoder("UTF-8");

		IF (decoder # NIL) THEN
			in := Codecs.OpenInputStream(fullname);
			IF in # NIL THEN
				decoder.Open(in, decoderRes);
				IF decoderRes = 0 THEN
					text := decoder.GetText();
				END;
			ELSE
				msg := "Can't open input stream on file "; Strings.Append(msg, fullname);
				KernelLog.String(msg);
				error := TRUE;
			END;
		ELSE
			msg := "No decoder for file "; Strings.Append(msg, fullname);
			Strings.Append(msg, " (Format: "); Strings.Append(msg, "UTF_8"); Strings.Append(msg, ")");
			KernelLog.String(msg);
			error := TRUE;
		END;
	ELSE
		msg := "file '"; Strings.Append(msg, fullname); Strings.Append(msg,"' not found.");
		KernelLog.String(msg);
		error := TRUE;
	END;

	IF ~error THEN
		KernelLog.String("file successfully read."); KernelLog.Ln;
		text.AcquireRead;
		NEW(bidiFormatter,text);
		bidiFormatter.ReformatText;
		textReader := bidiFormatter.ReorderLine(452,48);
		text.ReleaseRead;
	END;
END TestReformatting;

BEGIN
	showUnicodeControlCharacters := FALSE;
END UnicodeBidirectionality.

System.Free UnicodeProperties ~
System.Free UnicodeBidirectionality ~



UnicodeBidirectionality.TestReformatting "BidiTestData.txt"~

