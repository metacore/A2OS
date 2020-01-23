MODULE StatisticsCombinatorics; (** AUTHOR "Patrick Hunziker 2017"; PURPOSE "Library of tools for combinatorics"; *)

IMPORT Random (*, Commands, MatrixUtilities*);

(*Fisher Yates Algorithm: Random Permutation*)
PROCEDURE Permutation*(N:SIGNED32): ARRAY[*] OF SIGNED32;
VAR i, n:SIGNED32; series: ARRAY [*] OF SIGNED32;
BEGIN
	IF LEN(RESULT,0)#N THEN NEW(RESULT,N) END;
	IF LEN(series,0)#N THEN NEW(series,N) END;
	FOR i:=0 TO N-1 DO series[i]:=i END;
	FOR i:=N-1 TO 1 BY -1 DO
		n:=sequence.Dice(i+1);
		RESULT[i]:=series[n];
		series[n]:=series[i];
	END;
	RESULT[0]:=series[0];
	RETURN RESULT
END Permutation;

(*in-place random permutation*)
PROCEDURE Permute*(VAR A: ARRAY[*] OF SIGNED32);
VAR i: SIZE; j, n:SIGNED32;
BEGIN
	FOR i:=LEN(A,0)-1 TO 1 BY -1 DO
		n:=sequence.Dice((i+1)(SIGNED32));
		j:=A[i];
		A[i]:=A[n];
		A[n]:=j;
	END;
END Permute;

VAR sequence: Random.Sequence;
(*
PROCEDURE Test*(context:Commands.Context);
VAR n:SIGNED32; p:ARRAY [*] OF SIGNED32;
BEGIN
	IF context.arg.GetInteger(n,FALSE) THEN
	p:=Permutation(n);
	MatrixUtilities.Out(p);
	Permute(p);
	MatrixUtilities.Out(p);
	END;
END Test;*)

BEGIN
	NEW(sequence);
END StatisticsCombinatorics.


