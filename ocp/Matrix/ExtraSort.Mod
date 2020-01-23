MODULE ExtraSort;
(*
	DESCRIPTION:
		Library of sorting algorithms

	AUTHOR:
		Alexey Morozov
*)

TYPE
	(*
		DESCRIPTION:
			Quick sort for SIGNED32 data
		INPUTS:
			x[var] - array to sort
	*)
	PROCEDURE QuickSortLI*( VAR x: ARRAY [ * ] OF SIGNED32);

		PROCEDURE QSort( VAR x: ARRAY [ * ] OF SIGNED32; l, r: SIZE );
		VAR m: SIZE;
		BEGIN
			WHILE l < r DO
				(* quickly sort short lists *)
				IF r - l <= 50 THEN InsertionSortLI( x, l, r );  RETURN;  END;

				m := PartitionLI( x, l, r );

				(* eliminate tail recursion and *)
				(* sort the smallest partition first *)
				(* to minimize stack requirements    *)
				IF m - l <= r - m THEN QSort( x, l, m );  l := m + 1;  ELSE

					QSort( x, m + 1, r );  r := m;
				END;
			END;
		END QSort;

	BEGIN
		QSort(x , 0, LEN( x,0 ) - 1 );
	END QuickSortLI;

	(*
		DESCRIPTION:
			Quick sort for SIGNED32 data
		INPUTS:
			x[var] - array to sort
			ind[var] - sorting indices
	*)
	PROCEDURE QuickSortExLI*( VAR x: ARRAY [ * ] OF SIGNED32;  VAR ind: ARRAY [ * ] OF SIZE );
	VAR i: SIZE;

		PROCEDURE QSort( VAR x: ARRAY [ * ] OF SIGNED32;  VAR ind: ARRAY [ * ] OF SIZE;  l, r: SIZE );
		VAR m: SIZE;
		BEGIN
			WHILE l < r DO
				(* quickly sort short lists *)
				IF r - l <= 50 THEN InsertionSortExLI( x, ind, l, r );  RETURN;  END;

				m := PartitionExLI( x, ind, l, r );

				(* eliminate tail recursion and *)
				(* sort the smallest partition first *)
				(* to minimize stack requirements    *)
				IF m - l <= r - m THEN QSort( x, ind, l, m );  l := m + 1;  ELSE

					QSort( x, ind, m + 1, r );  r := m;
				END;
			END;
		END QSort;

	BEGIN
		IF LEN( ind ,0) < LEN( x,0 ) THEN NEW( ind, LEN( x,0 ) );  END;
		FOR i := 0 TO LEN( x,0 ) - 1 DO ind[i] := i;  END;
		QSort(x , ind, 0, LEN( x,0 ) - 1 );
	END QuickSortExLI;

	(*
		DESCRIPTION:
			Quick sort for FLOAT32 data
		INPUTS:
			x[var] - array to sort
	*)
	PROCEDURE QuickSortR*( VAR x: ARRAY [ * ] OF FLOAT32);

		PROCEDURE QSort( VAR x: ARRAY [ * ] OF FLOAT32; l, r: SIZE );
		VAR m: SIZE;
		BEGIN
			WHILE l < r DO
				(* quickly sort short lists *)
				IF r - l <= 50 THEN InsertionSortR( x, l, r );  RETURN;  END;

				m := PartitionR( x, l, r );

				(* eliminate tail recursion and *)
				(* sort the smallest partition first *)
				(* to minimize stack requirements    *)
				IF m - l <= r - m THEN QSort( x, l, m );  l := m + 1;  ELSE

					QSort( x, m + 1, r );  r := m;
				END;
			END;
		END QSort;

	BEGIN
		QSort( x, 0, LEN( x,0 ) - 1 );
	END QuickSortR;


	(*
		DESCRIPTION:
			Quick sort for FLOAT32 data
		INPUTS:
			x[var] - array to sort
			ind[var] - sorting indices
	*)
	PROCEDURE QuickSortExR*( VAR x: ARRAY [ * ] OF FLOAT32;  VAR ind: ARRAY [ * ] OF SIZE );
	VAR i: SIZE;

		PROCEDURE QSort( VAR x: ARRAY [ * ] OF FLOAT32;  VAR ind: ARRAY [ * ] OF SIZE;  l, r: SIZE );
		VAR m: SIZE;
		BEGIN
			WHILE l < r DO
				(* quickly sort short lists *)
				IF r - l <= 50 THEN InsertionSortExR( x, ind, l, r );  RETURN;  END;

				m := PartitionExR( x, ind, l, r );

				(* eliminate tail recursion and *)
				(* sort the smallest partition first *)
				(* to minimize stack requirements    *)
				IF m - l <= r - m THEN QSort( x, ind, l, m );  l := m + 1;  ELSE

					QSort( x, ind, m + 1, r );  r := m;
				END;
			END;
		END QSort;

	BEGIN
		IF LEN( ind,0 ) < LEN( x,0 ) THEN NEW( ind, LEN( x,0 ) );  END;
		FOR i := 0 TO LEN( x,0 ) - 1 DO ind[i] := i;  END;
		QSort( x, ind, 0, LEN( x,0 ) - 1 );
	END QuickSortExR;

	(*
		DESCRIPTION:
			Quick sort for FLOAT64 data
		INPUTS:
			x[var] - array to sort
	*)
	PROCEDURE QuickSortLR*( VAR x: ARRAY [ * ] OF FLOAT64);

		PROCEDURE QSort( VAR x: ARRAY [ * ] OF FLOAT64; l, r: SIZE );
		VAR m: SIZE;
		BEGIN
			WHILE l < r DO
				(* quickly sort short lists *)
				IF r - l <= 50 THEN InsertionSortLR( x, l, r );  RETURN;  END;

				m := PartitionLR( x, l, r );

				(* eliminate tail recursion and *)
				(* sort the smallest partition first *)
				(* to minimize stack requirements    *)
				IF m - l <= r - m THEN QSort( x, l, m );  l := m + 1;  ELSE

					QSort( x, m + 1, r );  r := m;
				END;
			END;
		END QSort;

	BEGIN
		QSort( x, 0, LEN( x,0 ) - 1 );
	END QuickSortLR;

	(*
		DESCRIPTION:
			Quick sort for FLOAT64 data
		INPUTS:
			x[var] - array to sort
			ind[var] - sorting indices
	*)
	PROCEDURE QuickSortExLR*( VAR x: ARRAY [ * ] OF FLOAT64;  VAR ind: ARRAY [ * ] OF SIZE );
	VAR i: SIZE;

		PROCEDURE QSort( VAR x: ARRAY [ * ] OF FLOAT64;  VAR ind: ARRAY [ * ] OF SIZE;  l, r: SIZE );
		VAR m: SIZE;
		BEGIN
			WHILE l < r DO
				(* quickly sort short lists *)
				IF r - l <= 50 THEN InsertionSortExLR( x, ind, l, r );  RETURN;  END;

				m := PartitionExLR( x, ind, l, r );

				(* eliminate tail recursion and *)
				(* sort the smallest partition first *)
				(* to minimize stack requirements    *)
				IF m - l <= r - m THEN QSort( x, ind, l, m );  l := m + 1;  ELSE

					QSort( x, ind, m + 1, r );  r := m;
				END;
			END;
		END QSort;

	BEGIN
		IF LEN( ind,0 ) < LEN( x,0 ) THEN NEW( ind, LEN( x,0 ) );  END;
		FOR i := 0 TO LEN( x,0 ) - 1 DO ind[i] := i;  END;
		QSort( x, ind, 0, LEN( x,0 ) - 1 );
	END QuickSortExLR;

	(*
		procedures for internal use
	*)

	PROCEDURE InsertionSortLI( VAR x: ARRAY [ * ] OF SIGNED32; l, r: SIZE );
	VAR t: SIGNED32;  i, j: SIZE;
	BEGIN
		FOR i := l + 1 TO r DO
			t := x[i];

			(* shift down until insertion point found *)
			j := i - 1;
			WHILE (j >= 0) & (x[j] > t) DO

				x[j + 1] := x[j];  DEC( j );
			END;

			(* insert *)
			x[j + 1] := t;
		END;
	END InsertionSortLI;

	PROCEDURE InsertionSortExLI( VAR x: ARRAY [ * ] OF SIGNED32;  VAR ind: ARRAY [ * ] OF SIZE;  l, r: SIZE );
	VAR t: SIGNED32;  i, j, k: SIZE;
	BEGIN
		FOR i := l + 1 TO r DO
			t := x[i];  k := ind[i];

			(* shift down until insertion point found *)
			j := i - 1;
			WHILE (j >= 0) & (x[j] > t) DO

				x[j + 1] := x[j];  ind[j + 1] := ind[j];  DEC( j );
			END;

			(* insert *)
			x[j + 1] := t;  ind[j + 1] := k;
		END;
	END InsertionSortExLI;

	PROCEDURE InsertionSortR( VAR x: ARRAY [ * ] OF FLOAT32;  l, r: SIZE );
	VAR t: FLOAT32;  i, j: SIZE;
	BEGIN
		FOR i := l + 1 TO r DO
			t := x[i];

			(* shift down until insertion point found *)
			j := i - 1;
			WHILE (j >= 0) & (x[j] > t) DO

				x[j + 1] := x[j];  DEC( j );
			END;

			(* insert *)
			x[j + 1] := t;
		END;
	END InsertionSortR;

	PROCEDURE InsertionSortExR( VAR x: ARRAY [ * ] OF FLOAT32;  VAR ind: ARRAY [ * ] OF SIZE;  l, r: SIZE );
	VAR t: FLOAT32;  i, j, k: SIZE;
	BEGIN
		FOR i := l + 1 TO r DO
			t := x[i];  k := ind[i];

			(* shift down until insertion point found *)
			j := i - 1;
			WHILE (j >= 0) & (x[j] > t) DO

				x[j + 1] := x[j];  ind[j + 1] := ind[j];  DEC( j );
			END;

			(* insert *)
			x[j + 1] := t;  ind[j + 1] := k;
		END;
	END InsertionSortExR;

	PROCEDURE InsertionSortLR( VAR x: ARRAY [ * ] OF FLOAT64;  l, r: SIZE );
	VAR t: FLOAT64;  i, j: SIZE;
	BEGIN
		FOR i := l + 1 TO r DO
			t := x[i];

			(* shift down until insertion point found *)
			j := i - 1;
			WHILE (j >= 0) & (x[j] > t) DO

				x[j + 1] := x[j]; DEC( j );
			END;

			(* insert *)
			x[j + 1] := t;
		END;
	END InsertionSortLR;

	PROCEDURE InsertionSortExLR( VAR x: ARRAY [ * ] OF FLOAT64;  VAR ind: ARRAY [ * ] OF SIZE;  l, r: SIZE );
	VAR t: FLOAT64;  i, j, k: SIZE;
	BEGIN
		FOR i := l + 1 TO r DO
			t := x[i];  k := ind[i];

			(* shift down until insertion point found *)
			j := i - 1;
			WHILE (j >= 0) & (x[j] > t) DO

				x[j + 1] := x[j];  ind[j + 1] := ind[j];  DEC( j );
			END;

			(* insert *)
			x[j + 1] := t;  ind[j + 1] := k;
		END;
	END InsertionSortExLR;

	PROCEDURE PartitionLI( VAR x: ARRAY [ * ] OF SIGNED32;  l, r: SIZE ): SIZE;
	VAR pivot, t: SIGNED32;  i, j: SIZE;
	BEGIN
		pivot := x[(l + r) DIV 2];
		(* work from both ends, swapping to keep   *)
		(* values less than pivot to the left, and *)
		(* values greater than pivot to the right  *)
		i := l - 1;  j := r + 1;
		LOOP
			REPEAT DEC( j );  UNTIL (x[j] <= pivot);
			REPEAT INC( i );  UNTIL x[i] >= pivot;

			IF i >= j THEN EXIT;
			END;

			(* swap *)
			t := x[i];  x[i] := x[j];  x[j] := t;
		END;

		RETURN j;
	END PartitionLI;

	PROCEDURE PartitionExLI( VAR x: ARRAY [ * ] OF SIGNED32;  VAR ind: ARRAY [ * ] OF SIZE;  l, r: SIZE ): SIZE;
	VAR pivot, t: SIGNED32;  i, j, k: SIZE;
	BEGIN
		pivot := x[(l + r) DIV 2];
		(* work from both ends, swapping to keep   *)
		(* values less than pivot to the left, and *)
		(* values greater than pivot to the right  *)
		i := l - 1;  j := r + 1;
		LOOP
			REPEAT DEC( j );  UNTIL (x[j] <= pivot);
			REPEAT INC( i );  UNTIL x[i] >= pivot;

			IF i >= j THEN EXIT;
			END;

			(* swap *)
			t := x[i];  x[i] := x[j];  x[j] := t;

			k := ind[i];  ind[i] := ind[j];  ind[j] := k;
		END;

		RETURN j;
	END PartitionExLI;

	PROCEDURE PartitionR( VAR x: ARRAY [ * ] OF FLOAT32;  l, r: SIZE ): SIZE;
	VAR pivot, t: FLOAT32;  i, j: SIZE;
	BEGIN
		pivot := x[(l + r) DIV 2];
		(* work from both ends, swapping to keep   *)
		(* values less than pivot to the left, and *)
		(* values greater than pivot to the right  *)
		i := l - 1;  j := r + 1;
		LOOP
			REPEAT DEC( j );  UNTIL (x[j] <= pivot);
			REPEAT INC( i );  UNTIL x[i] >= pivot;

			IF i >= j THEN EXIT;
			END;

			(* swap *)
			t := x[i];  x[i] := x[j];  x[j] := t;
		END;

		RETURN j;
	END PartitionR;

	PROCEDURE PartitionExR( VAR x: ARRAY [ * ] OF FLOAT32;  VAR ind: ARRAY [ * ] OF SIZE;  l, r: SIZE ): SIZE;
	VAR pivot, t: FLOAT32;  i, j, k: SIZE;
	BEGIN
		pivot := x[(l + r) DIV 2];
		(* work from both ends, swapping to keep   *)
		(* values less than pivot to the left, and *)
		(* values greater than pivot to the right  *)
		i := l - 1;  j := r + 1;
		LOOP
			REPEAT DEC( j );  UNTIL (x[j] <= pivot);
			REPEAT INC( i );  UNTIL x[i] >= pivot;

			IF i >= j THEN EXIT;
			END;

			(* swap *)
			t := x[i];  x[i] := x[j];  x[j] := t;

			k := ind[i];  ind[i] := ind[j];  ind[j] := k;
		END;

		RETURN j;
	END PartitionExR;

	PROCEDURE PartitionLR( VAR x: ARRAY [ * ] OF FLOAT64;  l, r: SIZE ): SIZE;
	VAR pivot, t: FLOAT64;  i, j: SIZE;
	BEGIN
		pivot := x[(l + r) DIV 2];
		(* work from both ends, swapping to keep   *)
		(* values less than pivot to the left, and *)
		(* values greater than pivot to the right  *)
		i := l - 1;  j := r + 1;
		LOOP
			REPEAT DEC( j );  UNTIL (x[j] <= pivot);
			REPEAT INC( i );  UNTIL x[i] >= pivot;

			IF i >= j THEN EXIT;
			END;

			(* swap *)
			t := x[i];  x[i] := x[j];  x[j] := t;
		END;

		RETURN j;
	END PartitionLR;

	PROCEDURE PartitionExLR( VAR x: ARRAY [ * ] OF FLOAT64;  VAR ind: ARRAY [ * ] OF SIZE;  l, r: SIZE ): SIZE;
	VAR pivot, t: FLOAT64;  i, j, k: SIZE;
	BEGIN
		pivot := x[(l + r) DIV 2];
		(* work from both ends, swapping to keep   *)
		(* values less than pivot to the left, and *)
		(* values greater than pivot to the right  *)
		i := l - 1;  j := r + 1;
		LOOP
			REPEAT DEC( j );  UNTIL (x[j] <= pivot);
			REPEAT INC( i );  UNTIL x[i] >= pivot;

			IF i >= j THEN EXIT;
			END;

			(* swap *)
			t := x[i];  x[i] := x[j];  x[j] := t;

			k := ind[i];  ind[i] := ind[j];  ind[j] := k;
		END;

		RETURN j;
	END PartitionExLR;

	PROCEDURE QuickSortI*( CONST x: ARRAY [ * ] OF SIGNED16;  VAR ind: ARRAY [ * ] OF SIZE );
	BEGIN
		HALT(100);
	END QuickSortI;

END ExtraSort.
