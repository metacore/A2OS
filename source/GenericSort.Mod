MODULE GenericSort; (** AUTHOR "Luc Blaeser"; PURPOSE "Generic Sort Functionality" *)
TYPE
	GenericArray* = POINTER TO ARRAY OF ANY;
	(** has to return true iff obj1 occurs before obj2 *)
	GenericCompareFunct* = PROCEDURE {DELEGATE} (obj1, obj2: ANY): BOOLEAN;

PROCEDURE QuickSort*(VAR genArray: GenericArray; compFunc: GenericCompareFunct);
BEGIN
	QuickSortRec(genArray, compFunc, 0, LEN(genArray)-1)
END QuickSort;

PROCEDURE QuickSortRec(VAR genArray: GenericArray; comp: GenericCompareFunct; lo, hi: SIZE);
VAR i, j: SIZE; x, t: ANY;
BEGIN
	i := lo; j := hi;
	x := genArray[(lo+hi) DIV 2];

	WHILE (i <= j) DO
		WHILE (comp(genArray[i], x)) DO INC(i) END;
		WHILE (comp(x, genArray[j])) DO DEC(j) END;
		IF (i <= j) THEN
			t := genArray[i]; genArray[i] := genArray[j]; genArray[j] := t;
			INC(i); DEC(j)
		END
	END;

	IF (lo < j) THEN QuickSortRec(genArray, comp, lo, j) END;
	IF (i < hi) THEN QuickSortRec(genArray, comp, i, hi) END
END QuickSortRec;

END GenericSort.
