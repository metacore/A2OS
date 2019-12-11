MODULE NextPrime;

VAR
	add, next: ARRAY 11 OF INTEGER;

	PROCEDURE Calc*( n: INTEGER ): INTEGER;
	VAR
		i, p, j: INTEGER;
	BEGIN 
		IF n < 2 THEN  RETURN 2;
		ELSIF n < 7 THEN
			i := 8;  p := n - 2;  n := 2;
		ELSE
			i := 0;  p := (n - 7) MOD 30;  n := 7 + (n - 7) DIV 30 * 30;
		END;
		j := 0;
		WHILE p >= j DO
			INC( j, add[i] );  i := next[i];
		END;
		INC( n, j );  p := 7;  j := 0;
		WHILE p * p <= n DO
			IF n MOD p = 0 THEN
				INC( n, add[i] );  i := next[i];  p := 7;  j := 0;
			ELSE
				INC( p, add[j] );  j := next[j];
			END;
		END;
		RETURN n;
	END Calc;

BEGIN 
	add[0] := 4;
	add[1] := 2;
	add[2] := 4;
	add[3] := 2;
	add[4] := 4;
	add[5] := 6;
	add[6] := 2;
	add[7] := 6;
	add[8] := 1;
	add[9] := 2;
	add[10] := 2;
	next[0] := 1;
	next[1] := 2;
	next[2] := 3;
	next[3] := 4;
	next[4] := 5;
	next[5] := 6;
	next[6] := 7;
	next[7] := 0;
	next[8] := 9;
	next[9] := 10;
	next[10] := 0;
END NextPrime.
	
