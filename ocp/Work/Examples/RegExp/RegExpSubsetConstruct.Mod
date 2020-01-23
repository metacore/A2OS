MODULE RegExpSubsetConstruct; (** AUTHOR "Yaroslav Romanchenko (SAGE)"; PURPOSE "Subset construction algorithm implementation"; *)

(*
// This code is in the public domain - feel free to do anything you
// wish with it.
//
// Eli Bendersky (spur4444@yahoo.com)
//
*)

IMPORT
	Generics,
	RegExpMaps, RegExpNFA, RegExpDFA;

	PROCEDURE EpsClosure*(nfa: RegExpNFA.NFA; lstStates: Generics.LongintVector): Generics.LongintVector;
	VAR
		lstEpsClosure, lstUnchecked: Generics.LongintVector;
		i, iFrom, iTo, posDummy: LONGINT;
	BEGIN
		NEW(lstEpsClosure, {});
		NEW(lstUnchecked, {});
		FOR i := 0 TO lstStates.Count() - 1 DO
			posDummy := lstEpsClosure.Add(lstStates.Get(i));
			posDummy := lstUnchecked.Add(lstStates.Get(i))
		END;

		lstEpsClosure.SetSorted(TRUE);

		WHILE ~lstUnchecked.IsEmpty() DO
			i := lstUnchecked.Count() - 1;
			iFrom := lstUnchecked.Get(i);
			lstUnchecked.Remove(i);
			FOR iTo := 0 TO nfa.nSize - 1 DO
				IF (nfa.aTable[iFrom, iTo].iType = RegExpNFA.NODE_TYPE_EPS) &
					(lstEpsClosure.IndexOf(iTo) = -1)
				THEN
					posDummy := lstEpsClosure.Add(iTo);
					posDummy := lstUnchecked.Add(iTo)
				END
			END
		END;
		RETURN lstEpsClosure
	END EpsClosure;

	PROCEDURE Move*(nfa: RegExpNFA.NFA; lstStates: Generics.LongintVector; iData: LONGINT): Generics.LongintVector;
	VAR
		lstResult: Generics.LongintVector;
 		i, iFrom, iTo, posDummy: LONGINT;
	BEGIN
		NEW(lstResult, {});
		FOR i := 0 TO lstStates.Count() - 1 DO
			iFrom := lstStates.Get(i);
			FOR iTo := 0 TO nfa.nSize - 1 DO
				IF (nfa.aTable[iFrom, iTo].iType = RegExpNFA.NODE_TYPE_DATA) &
					(nfa.aTable[iFrom, iTo].iData = iData)
				THEN
					posDummy := lstResult.Add(iTo)
				END
			END
		END;

		lstResult.SetSorted(TRUE);

		RETURN lstResult
	END Move;

	PROCEDURE SubsetConstruct*(nfa: RegExpNFA.NFA): RegExpDFA.DFA;
	VAR
		dfa: RegExpDFA.DFA;
		trans: RegExpMaps.Transition;
		lstlstMarked, lstlstUnmarked: Generics.LongintVectorVector;
		mapDFAStateNum: RegExpMaps.DFAStateNumMap;
		lstNFAInitial, lstFirst, lstAState, lstNext: Generics.LongintVector;
		iNewState, iInput, posDummy: LONGINT;

		PROCEDURE gen_new_state(): LONGINT;
		BEGIN
			INC(iNewState);
			RETURN iNewState
		END gen_new_state;

	BEGIN
		NEW(dfa);
		NEW(lstNFAInitial, {});
		NEW(lstlstMarked, {lstlstMarked.SORTED});
		NEW(lstlstUnmarked, {lstlstUnmarked.SORTED});
		NEW(mapDFAStateNum);
		iNewState := 0;
		posDummy := lstNFAInitial.Add(nfa.iInitial);
		lstFirst := EpsClosure(nfa, lstNFAInitial);
		posDummy := lstlstUnmarked.Add(lstFirst);
		dfa.iInitial := gen_new_state();
		mapDFAStateNum.Insert(lstFirst, dfa.iInitial);
		WHILE ~lstlstUnmarked.IsEmpty() DO
			lstAState := lstlstUnmarked.Get(0);
			lstlstUnmarked.Remove(0);
			posDummy := lstlstMarked.Add(lstAState);
			IF lstAState.IndexOf(nfa.iFinal) # -1 THEN
				IF mapDFAStateNum.Contains(lstAState) THEN
					posDummy := dfa.lstFinal.Add(mapDFAStateNum.Get(lstAState).iState)
				END
			END;
			FOR iInput := 0 TO nfa.lstInputs.Count() - 1 DO
				lstNext := EpsClosure(nfa,
					Move(nfa, lstAState, nfa.lstInputs.Get(iInput)));
				IF ((lstlstUnmarked.IndexOf(lstNext) = -1) &
					(lstlstMarked.IndexOf(lstNext) = -1))
				THEN
					posDummy := lstlstUnmarked.Add(lstNext);
					mapDFAStateNum.Insert(lstNext, gen_new_state())
				END;
				IF mapDFAStateNum.Contains(lstAState) THEN
					trans := RegExpMaps.NewTransition(
						mapDFAStateNum.Get(lstAState).iState,
						nfa.lstInputs.Get(iInput));
					IF mapDFAStateNum.Contains(lstNext) & ~dfa.mapTransition.Contains(trans) THEN
						dfa.mapTransition.Insert(trans,
							mapDFAStateNum.Get(lstNext).iState)
					END
				END
			END
		END;
		dfa.nStates := mapDFAStateNum.Count();

		dfa.lstFinal.SetSorted(TRUE);

		RETURN dfa
	END SubsetConstruct;

END RegExpSubsetConstruct.

