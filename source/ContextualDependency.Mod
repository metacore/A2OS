MODULE ContextualDependency; (** AUTHOR "gubsermi"; PURPOSE "Resolve context dependency rules"; *)

IMPORT
	Files, KernelLog, Configuration, Texts, Strings,
	XML, XMLObjects, XMLParser, XMLScanner;

CONST
	RangeDebug = FALSE;

	(* XML Attribute and Tag names *)
	LanguageAttribute = "language";
	ValueAttribute = "value";
	BaseAttribute = "base";
	CodeAttribute = "code";
	RangeAttribute = "range";
	SizeAttribute = "size";
	OffsetAttribute = "offset";
	NegativeAttribute = "neg";
	LowAttribute = "low";
	HighAttribute = "high";
	RootTag = "LanguageContext";
	CharacterTag = "Character";
	PropertiesTag = "Properties";
	ContextTag = "Context";
	SecondleftTag = "secondleft";
	LeftTag = "left";
	RightTag = "right";
	SecondrightTag = "secondright";
	GenericLeftTag = "genericLeft";
	GenericRightTag = "genericRight";
	BeforeTag = "left";
	AfterTag = "right";
	ResultTag = "result";
	RangeTag = "Range";
	SizeTag = "Size";




TYPE

	(* A unicode string *)
	String = POINTER TO ARRAY OF Texts.Char32;

	(* A node in the range tree. If it represents an inner node of the range tree, it knows about its descendant's ranges.
		If it is a leaf node, the left and right bounds represent this node's range. *)
	RangeNode = POINTER TO RECORD

		(* the node's descendants *)
		leftNode, rightNode : RangeNode;

		(* the left descendants boundaries *)
		leftOuterBound, leftInnerBound : LONGINT;

		(* the right descendants boundaries *)
		rightInnerBound, rightOuterBound : LONGINT;

		(* depth of the subtree this node's the root of *)
		depth : LONGINT;

		(* the value of the node: a context analyzer of the node's range. NIL if the node's an inner node. *)
		target : RangedContextAnalyzer;
	END;

	(* The range tree guarantees fast access to the context analyzer of a character that lies in a certain range of
		characters. *)
	RangeTree = OBJECT
	VAR

		(* last is a link to the last accessed node, which helps to speed lookups up *)
		root, last : RangeNode;

		(* Creates a new node and inserts it into the range tree *)
		PROCEDURE AddRange(target : RangedContextAnalyzer);
		VAR
			newNode : RangeNode;
			dummyLeft, dummyRight : LONGINT;
		BEGIN
			NEW(newNode);
			newNode.leftInnerBound := target.rangeLow;
			newNode.leftOuterBound := target.rangeLow;
			newNode.rightInnerBound := target.rangeHigh;
			newNode.rightOuterBound := target.rangeHigh;
			newNode.target := target;
			newNode.depth := 1;
			dummyLeft := -1;
			dummyRight := -1;
			RecursiveAdd(newNode,root,dummyLeft,dummyRight);
		END AddRange;

		(* Recursively traverses the tree top-down and looks for an appropriate place to insert the new node *)
		PROCEDURE RecursiveAdd(newNode : RangeNode; VAR thisNode : RangeNode; VAR left, right : LONGINT);
		VAR
			newIntermediateNode : RangeNode;
		BEGIN
			(* thisNode is only root if the tree's empty (thisNode = root) *)
			IF thisNode = NIL THEN
				thisNode := newNode;
			ELSE
				(* thisNode is an inner node, so the tree has to be traversed further downwards *)
				IF thisNode.target = NIL THEN
					(* the new node wouldn't fit in the right subtree so the left subtree is traversed *)
					IF newNode.rightOuterBound < thisNode.rightInnerBound THEN
						RecursiveAdd(newNode,thisNode.leftNode,left,right);
						thisNode.leftOuterBound := left;
						thisNode.leftInnerBound := right;
						right := thisNode.rightOuterBound;

					(* the new node wouldn't fit in the left subtree so the right subtree is traversed *)
					ELSIF newNode.leftOuterBound > thisNode.leftInnerBound THEN
						RecursiveAdd(newNode,thisNode.rightNode,left,right);
						thisNode.rightOuterBound := right;
						thisNode.rightInnerBound := left;
						left := thisNode.leftOuterBound;
					END;
				ELSE
					(* a leaf node was found, therefore a new inner node is created and the new node and the
						leaf node are appended to this new inner node. *)
					NEW(newIntermediateNode);

					(* the new node is going to be the inner node's left descendant *)
					IF newNode.rightOuterBound < thisNode.leftOuterBound THEN
						newIntermediateNode.leftNode := newNode;
						newIntermediateNode.rightNode := thisNode;
						newIntermediateNode.leftOuterBound := newNode.leftOuterBound;
						newIntermediateNode.leftInnerBound := newNode.rightOuterBound;
						newIntermediateNode.rightOuterBound := thisNode.rightOuterBound;
						newIntermediateNode.rightInnerBound := thisNode.leftOuterBound;
						newIntermediateNode.depth := thisNode.depth + 1;
						thisNode := newIntermediateNode;

						(* the node's outer bounds are passed to the parent *)
						left := newIntermediateNode.leftOuterBound;
						right := newIntermediateNode.rightOuterBound;

					(* the new node is going to be the inner node's right descendant *)
					ELSIF newNode.leftOuterBound > thisNode.rightOuterBound THEN
						newIntermediateNode.leftNode := thisNode;
						newIntermediateNode.rightNode := newNode;
						newIntermediateNode.leftOuterBound := thisNode.leftOuterBound;
						newIntermediateNode.leftInnerBound := thisNode.rightOuterBound;
						newIntermediateNode.rightOuterBound := newNode.rightOuterBound;
						newIntermediateNode.rightInnerBound := newNode.leftOuterBound;
						newIntermediateNode.depth := thisNode.depth + 1;
						thisNode := newIntermediateNode;

						(* the node's outer bounds are passed to the parent *)
						left := newIntermediateNode.leftOuterBound;
						right := newIntermediateNode.rightOuterBound;

					(* overlapping ranges are not allowed, so nothing happens if the new range overlaps with the current leaf's range *)
					ELSE
						(* the leaf's outer bounds must be passed none-the-less so as not to override the parent's bounds *)
						left := thisNode.leftOuterBound;
						right := thisNode.rightOuterBound;
					END;
				END;
			END;
		END RecursiveAdd;

		(* Searches the range tree for a range that includes this position *)
		PROCEDURE Search(position : LONGINT) : RangedContextAnalyzer;
		BEGIN
			(* Check out the last accessed node first to avoid traversing the whole tree if possible *)
			IF last # NIL THEN
				IF (position >= last.leftOuterBound) & (position <= last.rightOuterBound) THEN
					RETURN last.target;
				END;
			END;

			(* Search the tree if the position was not in the last accessed node's range *)
			RETURN RecursiveSearch(position,root);
		END Search;

		(* Recursively searches the tree for a range that fits this position *)
		PROCEDURE RecursiveSearch(position : LONGINT; thisNode : RangeNode) : RangedContextAnalyzer;
		BEGIN

			(* if thisNode is NIL a fitting range wont be found in this tree *)
			IF thisNode = NIL THEN
				RETURN NIL

			(* thisNode is an inner node, so the appropriate subtree needs to be searched *)
			ELSIF thisNode.target = NIL THEN

				(* this position could be in the left subtree *)
				IF (position >= thisNode.leftOuterBound) & (position <= thisNode.leftInnerBound) THEN
					RETURN RecursiveSearch(position,thisNode.leftNode);

				(* this position could be in the right subtree *)
				ELSIF (position >= thisNode.rightInnerBound) & (position <= thisNode.rightOuterBound) THEN
					RETURN RecursiveSearch(position,thisNode.rightNode);

				(* this position cannot be in any subtree and therefore the search fails *)
				ELSE
					RETURN NIL;
				END;
			ELSE
				(* A leaf node is found and the position fits inside the node's range *)
				IF (position >= thisNode.leftOuterBound) & (position <= thisNode.rightOuterBound) THEN

					(* thisNode is 'cached' *)
					last := thisNode;

					RETURN thisNode.target;
				ELSE
					(* this position doesn't fit inside this node's range (shouldn't happen!) *)
					RETURN NIL;
				END;
			END;
		END RecursiveSearch;

		(* Balances the tree AVL-style. This means that the depth of the two subtrees of one node differ by 1 at most. *)
		PROCEDURE CompleteBalancing;
		VAR
			dummyInt : LONGINT;
		BEGIN
			dummyInt := RecursiveBalancing(root);
		END CompleteBalancing;

		(* Balances a subtree and returns the subtrees depth after balancing *)
		PROCEDURE RecursiveBalancing(VAR thisNode : RangeNode) : LONGINT;
		VAR
			leftDepth, rightDepth : LONGINT;
		BEGIN
			(* the tree is empty *)
			IF thisNode = NIL THEN
				RETURN 0;

			(* thisNode is an inner node *)
			ELSIF thisNode.target = NIL THEN

				(* as a first step the node's subtrees are balanced *)
				leftDepth := RecursiveBalancing(thisNode.leftNode);
				rightDepth := RecursiveBalancing(thisNode.rightNode);

				(* there are four different kinds of rotations which all consider this node's balance and one of its decendant's balance *)
				IF leftDepth > rightDepth + 1 THEN
					IF GetNodeDepth(thisNode.leftNode.leftNode) < GetNodeDepth(thisNode.leftNode.rightNode) THEN
						RotateLeft(thisNode.leftNode);
					END;
					RotateRight(thisNode);

					RETURN thisNode.depth;
				ELSIF leftDepth + 1 < rightDepth THEN
					IF GetNodeDepth(thisNode.rightNode.leftNode) > GetNodeDepth(thisNode.rightNode.rightNode) THEN
						RotateRight(thisNode.rightNode);
					END;
					RotateLeft(thisNode);
					RETURN thisNode.depth;

				(* if rotations need to be done thisNode's depth is passed back *)
				ELSE
					IF Strings.Max(leftDepth,rightDepth) = leftDepth THEN
						RETURN leftDepth + 1;
					ELSE
						RETURN rightDepth + 1;
					END;
				END;

			(* if this node's a leaf, no rotations need to be done so only the (constant) depth is passed back *)
			ELSE
				RETURN 1;
			END;
		END RecursiveBalancing;


		(* Rotate the current tree to the right *)
		PROCEDURE RotateRight(VAR thisNode : RangeNode);
		VAR
			tempNode : RangeNode;
		BEGIN
			tempNode := thisNode.leftNode.rightNode;
			thisNode.leftNode.rightNode := thisNode;
			thisNode := thisNode.leftNode;
			thisNode.rightNode.leftNode := tempNode;
			thisNode.rightNode.depth := Strings.Max(GetNodeDepth(thisNode.rightNode.leftNode),GetNodeDepth(thisNode.rightNode.rightNode)) + 1;
			thisNode.depth := Strings.Max(thisNode.leftNode.depth,thisNode.rightNode.depth) + 1;
		END RotateRight;

		(* Rotate the current tree to the left *)
		PROCEDURE RotateLeft(VAR thisNode : RangeNode);
		VAR
			tempNode : RangeNode;
		BEGIN
			tempNode := thisNode.rightNode.leftNode;
			thisNode.rightNode.leftNode := thisNode;
			thisNode := thisNode.rightNode;
			thisNode.leftNode.rightNode := tempNode;
			thisNode.leftNode.depth := Strings.Max(GetNodeDepth(thisNode.leftNode.leftNode),GetNodeDepth(thisNode.leftNode.rightNode)) + 1;
			thisNode.depth := Strings.Max(thisNode.leftNode.depth,thisNode.rightNode.depth) + 1;
		END RotateLeft;

		(* Auxiliary procedure that returns the node's depth while checking for the node's existence *)
		PROCEDURE GetNodeDepth(thisNode : RangeNode) : LONGINT;
		BEGIN
			IF thisNode = NIL THEN
				RETURN 0;
			ELSE
				RETURN thisNode.depth;
			END;
		END GetNodeDepth;

	END RangeTree;

	(* a range is defined by a lower and an upper bound and a validity flag. The validity flag defines if a character must or must not lie
		in the specified range *)
	Range = OBJECT
	VAR
		lowerBound : LONGINT;
		upperBound : LONGINT;
		valid : BOOLEAN;

		PROCEDURE &Init*;
		BEGIN
			lowerBound := -1;
			upperBound := -1;
			valid := TRUE;
		END Init;
	END Range;

	RangeArray = POINTER TO ARRAY OF Range;

	Ranges = POINTER TO RECORD
		posRanges : RangeArray;
		negRanges : RangeArray;
	END;

	(* Holds all kinds of possible contexts. The mode of the Ranged Context Analyzer defines which ranges are even considered. *)
	GenericContext = POINTER TO RECORD
		lastRanges, secondlastRanges : Ranges;
		nextRanges, secondnextRanges : Ranges;
		wholeLastRanges, wholeNextRanges : POINTER TO ARRAY OF Ranges;
		resultingChar : Texts.Char32;
	END;

	(* A container for storing a context tied to a certain character in the Context Cache *)
	ContextCacheElement = OBJECT
	VAR
		key : Texts.Char32;
		value : GenericContext;
		next : ContextCacheElement;

		PROCEDURE &Init*(key : Texts.Char32; value : GenericContext);
		BEGIN
			SELF.key := key;
			SELF.value := value;
			next := NIL;
		END Init;


	END ContextCacheElement;

	(* A hashmap that stores contexts tied to certain characters. This guarantees faster access than reading from the
		XML file, where the rules are stored originally. *)
	ContextCache = OBJECT
	VAR
		internalCache: POINTER TO ARRAY OF ContextCacheElement;
		cacheSize : LONGINT;
		nextElement : ContextCacheElement;

		(* creates an internal storage of a certain size *)
		PROCEDURE &Init*(hashMapSize : LONGINT);
		BEGIN
			cacheSize := hashMapSize;
			NEW(internalCache,cacheSize);
		END Init;

		(* Searches the cache for a specific key and returns the corresponding entry *)
		PROCEDURE Lookup(char : Texts.Char32; VAR done : BOOLEAN) : GenericContext;
		VAR
			bucket : LONGINT;
			currentElement : ContextCacheElement;
		BEGIN
			(* if there could be more entries of the last looked up element, the last search is continued *)
			IF ~done & (nextElement # NIL) THEN
				currentElement := nextElement;
			ELSE
				(* get the bucket where the element resides if available *)
				bucket := char MOD cacheSize;
				currentElement := internalCache[bucket];
			END;

			(* search the linked list for the entry *)
			WHILE currentElement # NIL DO
				IF currentElement.key = char THEN

					IF currentElement.next = NIL THEN
						done := TRUE;
						nextElement := NIL;
					ELSE
						done := FALSE;
						nextElement := currentElement.next;
					END;

					RETURN currentElement.value;
				ELSE
					currentElement := currentElement.next;
				END;
			END;

			done := TRUE;
			nextElement := NIL;
			RETURN NIL;
		END Lookup;


		(* Inserts a new string entry for a given key. *)
		PROCEDURE Insert(char : Texts.Char32; value : GenericContext);
		VAR
			newElement : ContextCacheElement;
			bucket : LONGINT;
		BEGIN
			NEW(newElement,char,value);

			(* insert the new entry at the first position of the correct bucket *)
			bucket := char MOD cacheSize;
			newElement.next := internalCache[bucket];
			internalCache[bucket] := newElement;
		END Insert;

	END ContextCache;

	(* A ranged context analyzer applies previously defined rules on a certain set of characters. The rules are defined in an XML-file and
		are loaded lazily into the object. *)
	RangedContextAnalyzer = OBJECT
	VAR
		language : XML.String;
		rangeLow, rangeHigh : LONGINT;
		closeContext, wideContext, wholeContext : BOOLEAN;
		contextCache : ContextCache;
		contextFile : XML.Document;

		(* Initializes the context analyzer for a certain range and a certain mode *)
		PROCEDURE &Init*(context : XML.Document; rangeLow, rangeHigh : LONGINT; language, mode : Strings.String);
		BEGIN
			NEW(contextCache,rangeHigh-rangeLow);
			contextFile := context;
			SELF.rangeLow := rangeLow;
			SELF.rangeHigh := rangeHigh;
			SELF.language := language;
			IF mode^ = "close" THEN
				SetCloseContext;
			ELSIF mode^ = "wide" THEN
				SetWideContext;
			ELSIF mode^ = "whole" THEN
				SetWholeContext;
			ELSE
				SetNoContext;
			END;
		END Init;

		(* Sets the context analyzer to only analyzing the proximity (one character off in each direction) of the affected character *)
		PROCEDURE SetCloseContext;
		BEGIN
			closeContext := TRUE;
			wideContext := FALSE;
			wholeContext := FALSE;
		END SetCloseContext;

		(* Sets the context analyzer to analyzing a wider context (two characters off in each direction) of the affected character.
			'Close Context' rules are still considered. *)
		PROCEDURE SetWideContext;
		BEGIN
			closeContext := FALSE;
			wideContext := TRUE;
			wholeContext := FALSE;
		END SetWideContext;

		(* Sets the context analyzer to analyzing the whole context (the whole line) of the affected character. 'Close Context' and
			'Wide Context' rules are neglected. *)
		PROCEDURE SetWholeContext;
		BEGIN
			closeContext := FALSE;
			wideContext := FALSE;
			wholeContext := TRUE;
		END SetWholeContext;

		(* Turns the context analyzer off. *)
		PROCEDURE SetNoContext;
		BEGIN
			closeContext := FALSE;
			wideContext := FALSE;
			wholeContext := FALSE;
		END SetNoContext;

		(* Analyzes the close context for a certain character and - if a certain rule applies - returns the result of that rule. *)
		PROCEDURE AnalyzeCloseContext(thisChar, lastChar, nextChar : Texts.Char32) : Texts.Char32;
		VAR
			done,contextFound,validContextFound : BOOLEAN;
			thisContext : GenericContext;
		BEGIN
			done := TRUE;
			contextFound := FALSE;
			validContextFound := FALSE;

			(* Firstly, search in the context cache for an already loaded rule, that applies for this character *)
			REPEAT
				IF RangeDebug THEN
					KernelLog.String("looking for "); KernelLog.Hex(thisChar,4); KernelLog.Ln;
				END;
				thisContext := contextCache.Lookup(thisChar,done);
				IF (thisContext # NIL) THEN
					IF RangeDebug THEN
						KernelLog.String("found a context..."); KernelLog.Ln;
					END;

					(* If a context was found for this character, check if it is valid *)
					IF CheckCloseContext(lastChar,nextChar,thisContext) THEN
						IF RangeDebug THEN
							KernelLog.String("... which is valid."); KernelLog.Ln;
						END;
						done := TRUE;
						validContextFound := TRUE;
					ELSE
						IF RangeDebug THEN
							KernelLog.String("... which is invalid."); KernelLog.Ln;
						END;
					END;
					contextFound := TRUE;
				END;
			UNTIL done;

			(* If no context was found in the cache, search the XML file for fitting contexts *)
			IF ~contextFound THEN
				IF RangeDebug THEN
					KernelLog.String("No contexts found. Getting contexts from XML file"); KernelLog.Ln;
				END;
				GetContextsFromXML(thisChar);
				RETURN AnalyzeCloseContext(thisChar,lastChar,nextChar);
			ELSE
				(* If no valid context was found, return the original character (no change) *)
				IF (thisContext = NIL) OR ~validContextFound THEN
					IF RangeDebug THEN
						KernelLog.String("No change done.."); KernelLog.Ln;
					END;
					RETURN thisChar;

				(* If a context rule applied on the current character's context, the resulting character is returned *)
				ELSE
					IF RangeDebug THEN
						KernelLog.String("replacing "); KernelLog.Hex(thisChar,4);
						KernelLog.String(" with "); KernelLog.Hex(thisContext.resultingChar,4);
						KernelLog.Ln;
					END;

					RETURN thisContext.resultingChar;
				END;
			END;
		END AnalyzeCloseContext;

		(* Analyzes the wide context for a certain character and - if a certain rule applies - returns the result of that rule. *)
		PROCEDURE AnalyzeWideContext(thisChar, secondlastChar, lastChar, nextChar, secondnextChar : Texts.Char32) : Texts.Char32;
		VAR
			done,contextFound,validContextFound : BOOLEAN;
			thisContext : GenericContext;
		BEGIN
			done := TRUE;
			contextFound := FALSE;
			validContextFound := FALSE;

			(* Firstly, search in the context cache for an already loaded rule, that applies for this character *)
			REPEAT
				thisContext := contextCache.Lookup(thisChar,done);
				IF (thisContext # NIL) THEN

					(* If a context was found for this character, check if it is valid *)
					IF CheckWideContext(secondlastChar,lastChar,nextChar,secondnextChar,thisContext) THEN
						done := TRUE;
						validContextFound := TRUE;
					END;
					contextFound := TRUE;
				END;
			UNTIL done;

			(* If no context was found in the cache, search the XML file for fitting contexts *)
			IF ~contextFound THEN
				GetContextsFromXML(thisChar);
				RETURN AnalyzeWideContext(thisChar,secondlastChar,lastChar,nextChar,secondnextChar);
			ELSE
				(* If no valid context was found, return the original character (no change) *)
				IF (thisContext = NIL) OR ~validContextFound THEN
					RETURN thisChar;
				(* If a context rule applied on the current character's context, the resulting character is returned *)
				ELSE
					RETURN thisContext.resultingChar;
				END;
			END;
		END AnalyzeWideContext;

		(* Analyzes the whole context for the character at a certain position and - if a certain rule applies - returns the result of that rule. *)
		PROCEDURE AnalyzeWholeContext(thisPos : LONGINT; line : String) : Texts.Char32;
		VAR
			thisChar : Texts.Char32;
			done,contextFound,validContextFound : BOOLEAN;
			thisContext : GenericContext;
		BEGIN
			(* If the position is invalid, the NULL character is returned *)
			IF (thisPos < 0) OR (thisPos > LEN(line) - 1) THEN
				RETURN 0H;
			ELSE
				thisChar := line[thisPos];
			END;

			done := TRUE;
			contextFound := FALSE;
			validContextFound := FALSE;

			(* Firstly, search in the context cache for an already loaded rule, that applies for this character *)
			REPEAT
				thisContext := contextCache.Lookup(thisChar,done);
				IF (thisContext # NIL) THEN
					(* If a context was found for this character, check if it is valid *)
					IF CheckWholeContext(thisPos,line,thisContext) THEN
						done := TRUE;
						validContextFound := TRUE;
					END;
					contextFound := TRUE;
				END;
			UNTIL done;

			(* If no context was found in the cache, search the XML file for fitting contexts *)
			IF ~contextFound THEN
				GetContextsFromXML(thisChar);
				RETURN AnalyzeWholeContext(thisPos,line);
			ELSE
				(* If no valid context was found, return the original character (no change) *)
				IF (thisContext = NIL) OR ~validContextFound THEN
					RETURN thisChar;
				(* If a context rule applied on the current character's context, the resulting character is returned *)
				ELSE
					RETURN thisContext.resultingChar;
				END;
			END;
		END AnalyzeWholeContext;

		(* Checks if for a given context, the last and the next character fit to any of its given ranges *)
		PROCEDURE CheckCloseContext(lastChar, nextChar : Texts.Char32; context : GenericContext) : BOOLEAN;
		BEGIN
			(* If there is no actual context, the (non-present) context rules are defined to apply *)
			IF context = NIL THEN RETURN TRUE END;

			RETURN RangeOK(lastChar,context.lastRanges) & RangeOK(nextChar,context.nextRanges);
		END CheckCloseContext;

		(* Checks if for a given context, the second last, the last, the next and the second next character fit to any of its given ranges *)
		PROCEDURE CheckWideContext(secondlastChar, lastChar, nextChar, secondnextChar : Texts.Char32; context : GenericContext) : BOOLEAN;
		BEGIN
			(* If there is no actual context, the (non-present) context rules are defined to apply *)
			IF context = NIL THEN RETURN TRUE END;

			RETURN RangeOK(secondlastChar,context.secondlastRanges) & RangeOK(lastChar,context.lastRanges) &
				RangeOK(nextChar,context.nextRanges) & RangeOK(secondnextChar,context.secondnextRanges);
		END CheckWideContext;

		(* Checks if for a given context if - for each position one or more ranges are defined - any of these ranges fit the specific character *)
		PROCEDURE CheckWholeContext(thisPos : LONGINT; line : String; context : GenericContext) : BOOLEAN;
		VAR
			i,j : LONGINT;
		BEGIN
			(* If there is no actual context, the (non-present) context rules are defined to apply *)
			IF context = NIL THEN RETURN TRUE END;

			(* If there is a context, but no rules are defined, the context is considered to be invalid *)
			IF (context.wholeLastRanges = NIL) & (context.wholeNextRanges = NIL) THEN
				RETURN FALSE;
			END;

			(* Iterate through all rules defined for the preceding characters and check if they apply *)
			IF (context.wholeLastRanges # NIL) & (thisPos > 0) THEN
				j := 0;
				i := thisPos - 1;
				WHILE (i >= 0) & (j < LEN(context.wholeLastRanges)) DO
					IF ~RangeOK(line[i],context.wholeLastRanges[j]) THEN
						RETURN FALSE;
					END;
					DEC(i);
					INC(j);
				END;
			END;

			(* Iterate through all rules defined for the succeeding characters and check if they apply *)
			IF (context.wholeNextRanges # NIL) &(thisPos < LEN(line) - 1) THEN
				j := 0;
				i := thisPos + 1;
				WHILE (i < LEN(line)) & (j < LEN(context.wholeNextRanges)) DO
					IF ~RangeOK(line[i],context.wholeNextRanges[j]) THEN
						RETURN FALSE;
					END;
					INC(i);
					INC(j);
				END;
			END;

			RETURN TRUE;
		END CheckWholeContext;

		(* Check if the given character is part of at least one of the passed ranges *)
		PROCEDURE RangeOK(thisChar : Texts.Char32; ranges : Ranges) : BOOLEAN;
		VAR
			i : LONGINT;
			rangeOK : BOOLEAN;
		BEGIN
			(* If no ranges have been passed, there's no restriction for this character, so the rule is defined to apply *)
			IF ranges = NIL THEN RETURN TRUE END;
			rangeOK := FALSE;

			IF ranges.posRanges # NIL THEN
				i := 0;
				LOOP

					IF i > LEN(ranges.posRanges) - 1 THEN
						IF i = 0 THEN
							rangeOK := TRUE;
						END;
						EXIT;
					END;

					(* if the character lies in the current range, the rule applies *)
					IF (ranges.posRanges[i].lowerBound <= thisChar) & (thisChar <= ranges.posRanges[i].upperBound) THEN
						rangeOK := TRUE;
						EXIT;
					END;

					INC(i);
				END;
			END;

			IF ~rangeOK THEN
				RETURN FALSE;
			ELSIF ranges.negRanges = NIL THEN
				RETURN TRUE;
			END;

			i := 0;
			LOOP
				IF i > LEN(ranges.negRanges) - 1 THEN
					RETURN TRUE;
				END;

				(* if the character lies in the current range, the rule applies *)
				IF (ranges.negRanges[i].lowerBound <= thisChar) & (thisChar <= ranges.negRanges[i].upperBound) THEN
					RETURN FALSE;
				END;

				INC(i);
			END;

			RETURN rangeOK;
		END RangeOK;

		(* Parses the XML file containing the rules for this Ranged Context Analyzer *)
		PROCEDURE GetContextsFromXML(thisChar : Texts.Char32);
		VAR
			newContext : GenericContext;
			beforeRanges, afterRanges : Ranges;

			root : XML.Element;
			tagName, languageAttribute, baseAttribute, rangeAttribute, offsetAttribute, negAttribute, resultAttribute, sizeAttribute : XML.String;
			charElements, contextElements, rangeElements, genericBeforeElements, genericAfterElements : XMLObjects.Enumerator;
			charElement, contextElement, rangeElement, genericBeforeElement, genericAfterElement : ANY;
			contextFound, validContext, charFound : BOOLEAN;
			charString : XML.String;
			charCode : Texts.Char32;
			res : WORD;
			base16, neg : BOOLEAN;
			genericRangeSize, offset : LONGINT;

		BEGIN
			res := 0;
			contextFound := FALSE;
			charFound := FALSE;
			validContext := FALSE;

			IF contextFile # NIL THEN

				root := contextFile.GetRoot();
				tagName := root.GetName();
				languageAttribute := root.GetAttributeValue(LanguageAttribute);

				(* Check if the language attribute is correct *)
				IF (tagName^ = RootTag) & (languageAttribute^ = language^) THEN

					(* Check if character codes are stored in hexadecimal format *)
					baseAttribute := root.GetAttributeValue(BaseAttribute);
					base16 := baseAttribute^ = "Hex";
					charElements := root.GetContents();

					(* iterate through the character tags to find rules for the given character *)
					WHILE ~charFound & charElements.HasMoreElements() DO
						charElement := charElements.GetNext();
						WITH charElement : XML.Element DO
							tagName := charElement.GetName();

							IF tagName^ = CharacterTag THEN

								(* get the target character *)
								charString := charElement.GetAttributeValue(CodeAttribute);
								IF base16 THEN
									Strings.HexStrToInt(charString^,charCode,res);
								ELSE
									Strings.StrToInt(charString^,charCode);
								END;

								(* load only the context rules for the currently considered character (lazy loading) *)
								IF (res >= 0) & (charCode = thisChar) THEN
									charFound := TRUE;
									IF RangeDebug THEN
										KernelLog.String("range for "); KernelLog.Hex(charCode,4); KernelLog.Ln;
									END;
									contextElements := charElement.GetContents();

									(* iterate through all context rules *)
									WHILE contextElements.HasMoreElements() DO
										contextElement := contextElements.GetNext();
										WITH contextElement : XML.Element DO
											tagName := contextElement.GetName();

											IF tagName^ = ContextTag THEN
												NEW(newContext);
												contextFound := FALSE;
												validContext := FALSE;
												rangeElements := contextElement.GetContents();
												IF RangeDebug THEN
													KernelLog.String("Insert ranges: "); KernelLog.Ln;
												END;

												(* iterate through all ranges of the context. Neglect the rules that do not apply
													to the current analyzer's mode *)
												WHILE rangeElements.HasMoreElements() DO
													rangeElement := rangeElements.GetNext();
													WITH rangeElement : XML.Element DO
														tagName := rangeElement.GetName();

														(* parse the ranges for the second last character *)
														IF (tagName^ = SecondleftTag) & wideContext THEN
															rangeAttribute := rangeElement.GetAttributeValue(RangeAttribute);
															negAttribute := rangeElement.GetAttributeValue(NegativeAttribute);
															IF (negAttribute = NIL) OR (negAttribute^ # "!") THEN
																neg := FALSE;
															ELSE
																neg := TRUE;
															END;
															ParseRangeString(rangeAttribute,base16,neg,newContext.secondlastRanges);
															validContext := TRUE;

														(* parse the ranges for the last character *)
														ELSIF (tagName^ = LeftTag) & (wideContext OR closeContext) THEN
															IF RangeDebug THEN KernelLog.String("last: ") END;
															rangeAttribute := rangeElement.GetAttributeValue(RangeAttribute);
															negAttribute := rangeElement.GetAttributeValue(NegativeAttribute);
															IF (negAttribute = NIL) OR (negAttribute^ # "!") THEN
																neg := FALSE;
															ELSE
																neg := TRUE;
															END;
															ParseRangeString(rangeAttribute,base16,neg,newContext.lastRanges);
															validContext := TRUE;

														(* parse the ranges for the next character *)
														ELSIF (tagName^ = RightTag) & (closeContext OR wideContext) THEN
															IF RangeDebug THEN KernelLog.String("next: ") END;
															rangeAttribute := rangeElement.GetAttributeValue(RangeAttribute);
															negAttribute := rangeElement.GetAttributeValue(NegativeAttribute);
															IF (negAttribute = NIL) OR (negAttribute^ # "!") THEN
																neg := FALSE;
															ELSE
																neg := TRUE;
															END;
															ParseRangeString(rangeAttribute,base16,neg,newContext.nextRanges);
															validContext := TRUE;

														(* parse the ranges for the second next character *)
														ELSIF (tagName^ = SecondrightTag) &  wideContext THEN
															rangeAttribute := rangeElement.GetAttributeValue(RangeAttribute);
															negAttribute := rangeElement.GetAttributeValue(NegativeAttribute);
															IF (negAttribute = NIL) OR (negAttribute^ # "!") THEN
																neg := FALSE;
															ELSE
																neg := TRUE;
															END;
															ParseRangeString(rangeAttribute,base16,neg,newContext.secondnextRanges);
															validContext := TRUE;

														(* get the ranges for all preceding characters *)
														ELSIF (tagName^ = GenericLeftTag) & wholeContext THEN

															(* get the distance of the farthest context rule *)
															sizeAttribute := rangeElement.GetAttributeValue(SizeAttribute);
															Strings.StrToInt(sizeAttribute^,genericRangeSize);
															NEW(newContext.wholeLastRanges,genericRangeSize);
															genericBeforeElements := rangeElement.GetContents();

															(* parse through all ranges *)
															WHILE genericBeforeElements.HasMoreElements() DO
																genericBeforeElement := genericBeforeElements.GetNext();
																WITH genericBeforeElement : XML.Element DO
																	tagName := genericBeforeElement.GetName();
																	IF tagName^ = BeforeTag THEN
																		rangeAttribute := genericBeforeElement.GetAttributeValue(RangeAttribute);
																		offsetAttribute := genericBeforeElement.GetAttributeValue(OffsetAttribute);
																		negAttribute := rangeElement.GetAttributeValue(NegativeAttribute);
																		IF (negAttribute = NIL) OR (negAttribute^ # "!") THEN
																			neg := FALSE;
																		ELSE
																			neg := TRUE;
																		END;
																		Strings.StrToInt(offsetAttribute^,offset);
																		IF offset < 1 THEN offset := 1; END;
																		NEW(beforeRanges);
																		ParseRangeString(rangeAttribute,base16,neg,beforeRanges);
																		newContext.wholeLastRanges[offset-1] := beforeRanges;
																	END;
																END;
															END;
															validContext := TRUE;

														(* get the ranges for all succeeding character *)
														ELSIF (tagName^ = GenericRightTag) & wholeContext THEN

															(* get the distance of the farthest context rule *)
															sizeAttribute := rangeElement.GetAttributeValue(SizeAttribute);
															Strings.StrToInt(sizeAttribute^,genericRangeSize);
															NEW(newContext.wholeNextRanges,genericRangeSize);
															genericAfterElements := rangeElement.GetContents();

															(* parse through all ranges *)
															WHILE genericAfterElements.HasMoreElements() DO
																genericAfterElement := genericAfterElements.GetNext();
																WITH genericAfterElement : XML.Element DO
																	tagName := genericAfterElement.GetName();
																	IF tagName^ = AfterTag THEN
																		rangeAttribute := genericAfterElement.GetAttributeValue(RangeAttribute);
																		offsetAttribute := genericAfterElement.GetAttributeValue(OffsetAttribute);
																		negAttribute := rangeElement.GetAttributeValue(NegativeAttribute);
																		IF (negAttribute = NIL) OR (negAttribute^ # "!") THEN
																			neg := FALSE;
																		ELSE
																			neg := TRUE;
																		END;
																		Strings.StrToInt(offsetAttribute^,offset);
																		IF offset < 1 THEN offset := 1; END;
																		NEW(afterRanges);
																		ParseRangeString(rangeAttribute,base16,neg,afterRanges);
																		newContext.wholeNextRanges[offset-1] := afterRanges;
																	END;
																END;
															END;
															validContext := TRUE;

														(* parse the tag specifying the resulting character *)
														ELSIF tagName^ = ResultTag THEN
															resultAttribute := rangeElement.GetAttributeValue(CodeAttribute);
															IF base16 THEN
																Strings.HexStrToInt(resultAttribute^,newContext.resultingChar,res);
															ELSE
																Strings.StrToInt(resultAttribute^,newContext.resultingChar);
															END;

															(* a Zero defines the Zero-Width Space, which is used to simulate
																the deletion of the target character *)
															IF newContext.resultingChar = 0 THEN
																newContext.resultingChar := 200BH;
															END;

															IF RangeDebug THEN
																KernelLog.String("resulting in: ");
																KernelLog.Hex(newContext.resultingChar,4);
																KernelLog.Ln;
															END;
														END;
													END;
												END;

												(* Insert the found context into the context cache *)
												IF validContext THEN
													contextCache.Insert(thisChar,newContext);
													contextFound := TRUE;
												END;
											END;
										END
									END;
								END;
							END;
						END;
					END;

					(* If no context was defined for this character, insert a reflexive context into the cache *)
					IF ~contextFound THEN
						IF RangeDebug THEN
							KernelLog.String("inserting reflexive context"); KernelLog.Ln;
						END;
						contextCache.Insert(thisChar,GetReflexiveContext(thisChar));
					END;
				END;
			END;
		END GetContextsFromXML;

		(* Parses a range string and puts the ranges into a range array *)
		PROCEDURE ParseRangeString(rangeString : XML.String; base16, neg : BOOLEAN; VAR ranges : Ranges);
		VAR
			numberOfRanges, i, j, k, res : LONGINT;
			tempString : XML.String;
			range : Range;
			theseRanges, oldRanges : RangeArray;
		BEGIN
			NEW(tempString,LEN(rangeString));

			IF LEN(rangeString) > 0 THEN
				(* If the first character is an 'X', any character is valid. Therefore the string needs no more parsing. *)
				IF rangeString[0] = "X" THEN
					IF RangeDebug THEN
						KernelLog.String("any character"); KernelLog.Ln;
					END;
					RETURN;
				END;
				numberOfRanges := 1;
			ELSE
				numberOfRanges := 0;
			END;

			(* Count the defined ranges in the string *)
			FOR i := 0 TO LEN(rangeString) - 1 DO
				IF rangeString[i] = ";" THEN
					INC(numberOfRanges);
				END;
			END;

			IF ranges = NIL THEN
				NEW(ranges);
			END;

			(* old ranges need to be memorized so as not to delete them in the end *)
			IF neg THEN
				oldRanges := ranges.negRanges;
			ELSE
				oldRanges := ranges.posRanges;
			END;

			(* old ranges are copied to the beginning of the new ranges *)
			IF oldRanges # NIL THEN
				NEW(theseRanges,numberOfRanges+LEN(oldRanges));
				FOR k := 0 TO LEN(oldRanges) - 1 DO
					theseRanges[k] := oldRanges[k];
				END;
			ELSE
				NEW(theseRanges,numberOfRanges);
				k := 0;
			END;

			NEW(range);
			j := 0; (*k := LEN(oldRanges);*)
			FOR i := 0 TO LEN(rangeString) - 1 DO

				(* Store the current character string *)
				tempString[j] := rangeString[i];

				(* If a '!' stands right before a range, the range is called invalid, which means that a certain character must not
					lie in the defined range *)
				IF rangeString[i] = "!" THEN
					IF i = 0 THEN
						range.valid := FALSE;
					ELSIF rangeString[i-1] = ";" THEN
						range.valid := FALSE;
					END;

				(* The '-' is the border between the lower and the upper bound of the range *)
				ELSIF rangeString[i] = "-" THEN
					tempString[j] := 0X;
					IF base16 THEN
						Strings.HexStrToInt(tempString^,range.lowerBound,res);
					ELSE
						Strings.StrToInt(tempString^,range.lowerBound);
					END;
					j := 0;

				(* The ';' marks the end of a range. *)
				ELSIF rangeString[i] = ";" THEN
					tempString[j] := 0X;

					(* 'O' defines the beginning of a line *)
					IF tempString^ = "O" THEN
						range.lowerBound := -1;
						range.upperBound := -1;
					ELSE
						IF base16 THEN
							Strings.HexStrToInt(tempString^,range.upperBound,res);
						ELSE
							Strings.StrToInt(tempString^,range.upperBound);
						END;

						(* if the no lower bound has been defined for this range, the range is defined of but one character *)
						IF range.lowerBound < 0 THEN
							range.lowerBound := range.upperBound;
						END;
					END;

					IF RangeDebug THEN
						KernelLog.String("["); KernelLog.Hex(range.lowerBound,4);
						KernelLog.String(","); KernelLog.Hex(range.upperBound,4);
						KernelLog.String("]");
						IF ~range.valid THEN KernelLog.String(" (!)") END;
						KernelLog.Ln;
					END;

					(* save the range and carry on with the next range in the string *)
					theseRanges[k] := range;
					NEW(range);
					INC(k);
					j := 0;
				ELSE
					INC(j);
				END;
			END;

			(* Since the last range need not to be delimited by a ';', it needs additional treatment after the string is parsed *)
			IF tempString^ = "O" THEN
				range.lowerBound := -1;
				range.upperBound := -1;
			ELSE
				IF base16 THEN
					Strings.HexStrToInt(tempString^,range.upperBound,res);
				ELSE
					Strings.StrToInt(tempString^,range.upperBound);
				END;
				IF range.lowerBound < 0 THEN
					range.lowerBound := range.upperBound;
				END;
			END;

			IF RangeDebug THEN
				KernelLog.String("["); KernelLog.Hex(range.lowerBound,4);
				KernelLog.String(","); KernelLog.Hex(range.upperBound,4);
				KernelLog.String("]");
				IF ~range.valid THEN KernelLog.String(" (!)") END;
				KernelLog.Ln;
			END;
			theseRanges[k] := range;

			IF neg THEN
				ranges.negRanges := theseRanges;
			ELSE
				ranges.posRanges := theseRanges;
			END;
		END ParseRangeString;

		(* Constructs a reflexive context, which means that the targetted character is not changed *)
		PROCEDURE GetReflexiveContext(thisChar : Texts.Char32) : GenericContext;
		VAR
			newContext : GenericContext;
		BEGIN
			NEW(newContext);
			newContext.resultingChar := thisChar;
			RETURN newContext;
		END GetReflexiveContext;

	END RangedContextAnalyzer;


	(* The Context Analyzer holds a tree of all Ranged Context Analyzers to guarantee a fast access to the correct context
		for each character. It is also responsible to actually parse a given line and delegate the analysis to the correct
		analyzer. *)
	ContextAnalyzer = OBJECT
	VAR

		(* Initializes the tree for the available Ranged Context Analyzers. *)
		PROCEDURE &Init*;
		BEGIN
			NEW(ranges);
		END Init;


		(* Parses a given line and analyzes it character-wise for defined context rules *)
		PROCEDURE AnalyzeLine(line : Texts.TextReader; start, end : LONGINT) : Texts.TextReader;
		VAR
			lineCache, newLine : String;
			ch,ch1,ch2,ch3,ch4 : Texts.Char32;
			i : LONGINT;
			analyzer : RangedContextAnalyzer;
			newText : Texts.Text;
			oneCharString : Texts.PUCS32String;
			newTextReader : Texts.TextReader;
		BEGIN

			(* Set default values for negative start and end positions *)
			line.text.AcquireRead;
			IF start < 0 THEN
				start := 0;
			END;
			IF end < 0 THEN
				end := line.text.GetLength() - 1;
			END;
			NEW(lineCache,end-start+1);
			NEW(newLine,end-start+1);
			line.SetPosition(start);
			line.SetDirection(1);
			i := 0;
			ch := 0;

			(* Put the whole line into a faster accessible array *)
			FOR i:= 0 TO LEN(lineCache) - 1 DO
				line.ReadCh(ch);
				lineCache[i] := ch;
			END;
			line.text.ReleaseRead;

			NEW(newText);
			NEW(oneCharString,2);
			oneCharString[1] := 0H;
			newText.AcquireWrite;

			(* Iterate through all characters of the line *)
			FOR i := 0 TO LEN(lineCache) - 1 DO

				(* gather the context of the character. Special treatment for the line's borders. *)
				IF i = 0 THEN
					ch1 := -1;
					ch2 := -1;
				ELSIF i = 1 THEN
					ch1 := -1;
					ch2 := lineCache[0];
				ELSE
					ch1 := lineCache[i-2];
					ch2 := lineCache[i-1];
				END;
				ch := lineCache[i];
				IF i = LEN(lineCache) - 1 THEN
					ch3 := -1;
					ch4 := -1;
				ELSIF i = LEN(lineCache) - 2 THEN
					ch3 := lineCache[i+1];
					ch4 := -1;
				ELSE
					ch3 := lineCache[i+1];
					ch4 := lineCache[i+2];
				END;

				(* Search the range tree for a suitable analyzer *)
				analyzer := ranges.Search(lineCache[i]);
				IF analyzer # NIL THEN
					IF RangeDebug THEN
						KernelLog.String("==> "); KernelLog.Hex(ch,4); KernelLog.Ln;
					END;

					(* Call the analyzer's correct procedure to analyze the character's context *)
					IF analyzer.closeContext THEN
						ch := analyzer.AnalyzeCloseContext(ch,ch2,ch3);
					ELSIF analyzer.wideContext THEN
						ch := analyzer.AnalyzeWideContext(ch,ch1,ch2,ch3,ch4);
					ELSIF analyzer.wholeContext THEN
						ch := analyzer.AnalyzeWholeContext(i,lineCache);
					END;
					IF RangeDebug THEN
						KernelLog.String("<== "); KernelLog.Hex(ch,4); KernelLog.Ln;
					END;
				END;

				(* Insert the new character into the resulting text *)
				oneCharString[0] := ch;
				newText.InsertUCS32(i,oneCharString^);
			END;

			newText.ReleaseWrite;

			(* store the new text in a special text reader *)
			NEW(newTextReader,newText);
			RETURN newTextReader;
		END AnalyzeLine;

	END ContextAnalyzer;

VAR
	contextAnalyzer : ContextAnalyzer;
	ranges : RangeTree;

(* Registers a certain set of context rules defined in an XML file. The new analyzer is stored in a range tree, that
	was created by the Context Analyzer, previously. *)
PROCEDURE RegisterRangedAnalyzer(language : Strings.String; contextFile : XML.Document);
VAR
	newAnalyzer : RangedContextAnalyzer;
	root : XML.Element;
	charElements, propertyElements : XMLObjects.Enumerator;
	charElement, propertyElement : ANY;

	tagName, languageAttribute, baseAttribute : XML.String;
	base16, propertyFound : BOOLEAN;

	rangeLow, rangeHigh, res : LONGINT;
	mode, tempRangeLow, tempRangeHigh : Strings.String;
BEGIN
	propertyFound := FALSE;
	IF (contextFile # NIL) & (ranges # NIL) THEN
		root := contextFile.GetRoot();
		tagName := root.GetName();
		languageAttribute := root.GetAttributeValue(LanguageAttribute);

		IF (tagName^ = RootTag) & (languageAttribute^ = language^) THEN
			baseAttribute := root.GetAttributeValue(BaseAttribute);
			base16 := baseAttribute^ = "Hex";
			charElements := root.GetContents();

			(* Look for the property tag *)
			WHILE ~propertyFound & charElements.HasMoreElements() DO
				charElement := charElements.GetNext();
				WITH charElement : XML.Element DO
					tagName := charElement.GetName();

					IF tagName^ = PropertiesTag THEN
						propertyElements := charElement.GetContents();

						(* Look through the properties *)
						WHILE propertyElements.HasMoreElements() DO
							propertyElement := propertyElements.GetNext();
							WITH propertyElement : XML.Element DO
								tagName := propertyElement.GetName();

								(* Store the range, that is affected by these rules *)
								IF tagName^ = RangeTag THEN
									tempRangeLow := propertyElement.GetAttributeValue(LowAttribute);
									tempRangeHigh := propertyElement.GetAttributeValue(HighAttribute);
									IF base16 THEN
										Strings.HexStrToInt(tempRangeLow^,rangeLow,res);
										Strings.HexStrToInt(tempRangeHigh^,rangeHigh,res);
									ELSE
										Strings.StrToInt(tempRangeLow^,rangeLow);
										Strings.StrToInt(tempRangeHigh^,rangeHigh);
									END;

								(* Get the range mode, that defines how big the considered contexts can be. *)
								ELSIF tagName^ = SizeTag THEN
									mode := propertyElement.GetAttributeValue(ValueAttribute);
								END;
							END;
						END;

						(* create a new Ranged Context Analyzer and append it to the tree *)
						NEW(newAnalyzer,contextFile,rangeLow,rangeHigh,language,mode);
						ranges.AddRange(newAnalyzer);
						propertyFound := TRUE;
					END;
				END;
			END;
		END;
	END;
END RegisterRangedAnalyzer;



(* Entry point for the outside world to analyze a line of text for context dependency *)
PROCEDURE AnalyzeLine*(line : Texts.TextReader; start, end : LONGINT) : Texts.TextReader;
BEGIN
	RETURN contextAnalyzer.AnalyzeLine(line,start,end);
END AnalyzeLine;




(* Prepares an XML file for further treatment *)
PROCEDURE InitRangedAnalyzer(CONST filename : ARRAY OF CHAR; VAR useThisContext : BOOLEAN; VAR context : XML.Document);
TYPE
	Trap = OBJECT
	VAR
		xmlError : BOOLEAN;
		filename: Files.FileName;

		PROCEDURE &InitTrap (CONST filename: ARRAY OF CHAR);
		BEGIN COPY (filename, SELF.filename); xmlError := FALSE;
		END InitTrap;

		PROCEDURE Handler(pos, line, row: LONGINT; CONST msg: ARRAY OF CHAR);
		BEGIN
			KernelLog.String("Error in ");
			KernelLog.String(filename);
			KernelLog.String(" at position ");
			KernelLog.String("pos= "); KernelLog.Int(pos, 0); KernelLog.String(" line= "); KernelLog.Int(line, 0); KernelLog.String(" row= "); KernelLog.Int(row, 0); KernelLog.Ln;
			xmlError := TRUE;
		END Handler;
	END Trap;

VAR
	file: Files.File;
	scanner: XMLScanner.Scanner;
	parser: XMLParser.Parser;
	reader: Files.Reader;
	trap: Trap;

BEGIN
	context := NIL;
	file := Files.Old(filename);
	IF file # NIL THEN
		NEW(reader, file, 0);
		NEW(scanner, reader);
		NEW(parser, scanner);
		NEW(trap, filename);
		parser.reportError := trap.Handler;
		context:= parser.Parse();
		IF ~trap.xmlError THEN
			context := NIL;
			useThisContext := TRUE;
		ELSE
			useThisContext := FALSE;
		END;
	ELSE
		KernelLog.String("Error opening ");
		KernelLog.String(filename);
		KernelLog.String(". File not found.");
		KernelLog.Ln;
		useThisContext := FALSE;
	END;
END InitRangedAnalyzer;



(* Searches the configuration file for available context dependency rule files and initializes the corresponding Ranged Context Analyzers *)
PROCEDURE LoadContextualDependencies;
VAR
	contextSection : XML.Element;
	rangePropertyElements : XMLObjects.Enumerator;
	rangePropertyElement : ANY;
	useNewContext : BOOLEAN;
	newContextFile : XML.Document;
	filenameAttribute, languageAttribute : Strings.String;
BEGIN
	contextSection := Configuration.GetSection("Context");
	IF (contextSection # NIL) THEN
		rangePropertyElements:= contextSection.GetContents();

		(* iterate through all available context properties *)
		WHILE rangePropertyElements.HasMoreElements() DO
			rangePropertyElement := rangePropertyElements.GetNext();
			WITH rangePropertyElement : XML.Element DO

				(* Get important properties from the file itself *)
				filenameAttribute := rangePropertyElement.GetAttributeValue("value");
				languageAttribute := rangePropertyElement.GetAttributeValue("name");
				InitRangedAnalyzer(filenameAttribute^,useNewContext,newContextFile);

				(* If the properties could correctly be gathered, the Ranged Context Analyzer is initialized and registered *)
				IF useNewContext THEN
					IF RangeDebug THEN
						KernelLog.String(filenameAttribute^); KernelLog.String(" loaded."); KernelLog.Ln;
					END;
					RegisterRangedAnalyzer(languageAttribute,newContextFile);
				END;
			END;
		END;

		ranges.CompleteBalancing;
	ELSE
		KernelLog.String("ContextDependecy: Could not load contextual dependecies (missing 'Context' section in configuration file).");
		KernelLog.Ln;
	END;
END LoadContextualDependencies;

(* Create Context Analyzer and load all available context dependency rules *)
BEGIN
	NEW(contextAnalyzer);
	LoadContextualDependencies;
END ContextualDependency.