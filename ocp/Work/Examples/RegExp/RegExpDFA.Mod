MODULE RegExpDFA; (** AUTHOR "Yaroslav Romanchenko (SAGE)"; PURPOSE "Deterministic Finite Automaton (DFA) class"; *)

(*
// This code is in the public domain - feel free to do anything you
// wish with it.
//
// Eli Bendersky (spur4444@yahoo.com)
//
*)

IMPORT
	Commands,

	Generics,

	RegExpMaps;

TYPE

	DFA* = OBJECT
	VAR
		(** transition map, list of final states and the start state *)
		mapTransition-: RegExpMaps.TransitionMap;
		iInitial*, nStates*: LONGINT;
		lstFinal-: Generics.LongintVector;

		PROCEDURE &New*;
		BEGIN
			NEW(mapTransition);
			NEW(lstFinal, {})
		END New;

		PROCEDURE Show*(context: Commands.Context);
		VAR
			i: LONGINT;
			itemTransitionMap: RegExpMaps.TransitionMapItem;
		BEGIN
			context.out.Ln;
			context.out.String("DFA start state: ");
			context.out.Int(iInitial, 0);
			context.out.Ln;
			context.out.String("DFA states: ");
			context.out.Int(nStates, 0);
			context.out.Ln;
			context.out.String("DFA final state(s): ");
			FOR i := 0 TO lstFinal.Count() - 1 DO
				context.out.Int(lstFinal.Get(i), 0);
				context.out.Char(' ')
			END;
			context.out.Ln;
			mapTransition.Iterator().Reset;
			WHILE mapTransition.Iterator().GetNext(itemTransitionMap) DO
				context.out.String("Trans[");
				context.out.Int(itemTransitionMap.trans.iState, 0);
				context.out.String(", '");
				context.out.Char(CHR(itemTransitionMap.trans.iData));
				context.out.String("'] = ");
				context.out.Int(itemTransitionMap.iState, 0);
				context.out.Ln
			END
		END Show;

		PROCEDURE Simulate*(aInput: ARRAY OF CHAR; iInput: LONGINT; VAR iNext: LONGINT): BOOLEAN;
		VAR
			iCurState: LONGINT;
			bLoop: BOOLEAN;
			trans: RegExpMaps.Transition;
		BEGIN
			iCurState := iInitial;
			bLoop := TRUE;
			WHILE (iInput < LEN(aInput)) & (aInput[iInput] # 0X) & bLoop DO
				trans := RegExpMaps.NewTransition(iCurState, ORD(aInput[iInput]));
				IF mapTransition.Contains(trans) THEN
					iCurState := mapTransition.Get(trans).iState;
					bLoop := lstFinal.IndexOf(iCurState) = -1;
					INC(iInput)
				ELSE
					bLoop := FALSE
				END
			END;
			iNext := iInput;
			RETURN lstFinal.IndexOf(iCurState) # -1
		END Simulate;

	END DFA;

END RegExpDFA.
