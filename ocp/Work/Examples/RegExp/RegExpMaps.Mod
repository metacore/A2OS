MODULE RegExpMaps; (** AUTHOR "Yaroslav Romanchenko (SAGE)"; PURPOSE "Map container classes for use in RegExp engine"; *)

IMPORT
	Generics;

TYPE

	DFAStateNumMapItem* = RECORD(Generics.TreeItem)
		lstStates: Generics.LongintVector;
		iState-: LONGINT
	END;

	DFAStateNumMap* = OBJECT(Generics.Tree)
	VAR
		array: POINTER TO ARRAY OF DFAStateNumMapItem;

		PROCEDURE &New*;
		VAR
			pCompA, pCompB: POINTER TO DFAStateNumMapItem;
		BEGIN
			NEW(pCompA);
			NEW(pCompB);
			NewTree(SIZEOF(DFAStateNumMapItem), pCompA, pCompB, Less)
		END New;

		PROCEDURE ArrayConstruct(iArraySize: LONGINT; VAR pArray: ANY; VAR addrArray: ADDRESS);
		BEGIN
			NEW(array, iArraySize); pArray := array; addrArray := ADDRESSOF(array^[0])
		END ArrayConstruct;

		PROCEDURE Less(pA, pB: Generics.PItem): BOOLEAN;
		BEGIN
			RETURN Generics.CompareLongintVectors(pA^(DFAStateNumMapItem).lstStates,
				pB^(DFAStateNumMapItem).lstStates) < 0
		END Less;

		PROCEDURE Insert*(lstStates: Generics.LongintVector; iState: LONGINT);
		VAR
			item: DFAStateNumMapItem;
		BEGIN
			item.lstStates := lstStates;
			item.iState := iState;
			InsertInternal(item)
		END Insert;

		PROCEDURE Contains*(lstStates: Generics.LongintVector): BOOLEAN;
		VAR
			item: DFAStateNumMapItem;
		BEGIN
			item.lstStates := lstStates;
			RETURN ContainsInternal(item)
		END Contains;

		PROCEDURE Get*(lstStates: Generics.LongintVector): DFAStateNumMapItem;
		VAR
			item: DFAStateNumMapItem;
		BEGIN
			item.lstStates := lstStates;
			GetInternal(item);
			RETURN item
		END Get;

	END DFAStateNumMap;

	Transition* = RECORD
		iState-: LONGINT;
		iData-: LONGINT;
	END;

	TransitionMapItem* = RECORD(Generics.TreeItem)
		trans-: Transition;
		iState-: LONGINT;
	END;

	TransitionMap* = OBJECT(Generics.Tree)
	VAR
		array: POINTER TO ARRAY OF TransitionMapItem;

		PROCEDURE &New*;
		VAR
			pCompA, pCompB: POINTER TO TransitionMapItem;
		BEGIN
			NEW(pCompA);
			NEW(pCompB);
			NewTree(SIZEOF(TransitionMapItem), pCompA, pCompB, Less)
		END New;

		PROCEDURE ArrayConstruct(iArraySize: LONGINT; VAR pArray: ANY; VAR addrArray: ADDRESS);
		BEGIN
			NEW(array, iArraySize); pArray := array; addrArray := ADDRESSOF(array^[0])
		END ArrayConstruct;
		
		PROCEDURE Less(pA, pB: Generics.PItem): BOOLEAN;
		BEGIN
			RETURN (pA^(TransitionMapItem).trans.iState < pB^(TransitionMapItem).trans.iState) OR
				((pA^(TransitionMapItem).trans.iState = pB^(TransitionMapItem).trans.iState) &
					(pA^(TransitionMapItem).trans.iData < pB^(TransitionMapItem).trans.iData))
		END Less;

		(*PROCEDURE Compare(iLeft: LONGINT; VAR right: Vector.Value): LONGINT;
		VAR
			itemLeft, itemRight: TransitionMapValue;
		BEGIN
			itemLeft := array^[iLeft];
			itemRight := right(TransitionMapValue);
			IF itemLeft.trans.iState < itemRight.trans.iState THEN
				RETURN -1
			ELSIF itemLeft.trans.iState > itemRight.trans.iState THEN
				RETURN 1
			ELSE
				IF itemLeft.trans.iData < itemRight.trans.iData THEN
					RETURN -1
				ELSIF itemLeft.trans.iData > itemRight.trans.iData THEN
					RETURN 1
				ELSE
					RETURN 0
				END
			END
		END Compare;*)

		PROCEDURE Insert*(VAR trans: Transition; iState: LONGINT);
		VAR
			item: TransitionMapItem;
		BEGIN
			item.trans := trans;
			item.iState := iState;
			InsertInternal(item)
		END Insert;

		PROCEDURE Contains*(VAR trans: Transition): BOOLEAN;
		VAR
			item: TransitionMapItem;
		BEGIN
			item.trans := trans;
			RETURN ContainsInternal(item)
		END Contains;

		PROCEDURE Get*(VAR trans: Transition): TransitionMapItem;
		VAR
			item: TransitionMapItem;
		BEGIN
			item.trans := trans;
			GetInternal(item);
			RETURN item
		END Get;

	END TransitionMap;

	PROCEDURE NewTransition*(iState, iData: LONGINT): Transition;
	VAR
		x: Transition;
	BEGIN
		x.iState := iState;
		x.iData := iData;
		RETURN x
	END NewTransition;

END RegExpMaps.

