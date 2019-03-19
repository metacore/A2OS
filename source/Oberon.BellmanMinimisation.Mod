MODULE BellmanMinimisation IN Oberon;   (**  AUTHOR "fof"; PURPOSE "";  **)
(* This module provides mechanisms to minimise the Potts functional: gamma * |jumps| + (1-gamma) * distancefunction,  with gamma in [0,1], see PROCEDURE FindBestPartition. The aim is a piecewise constant representation of the data.
Currently, you can choose between five distancefunctions, belonging to the five objects L2, L1, Hampel, Saegezahn ["sawtooth"] and Huber, particulars there.  *)

IMPORT antsArrays, vyLongrealVec, vyBase, vyName, antsCommands, aM := antsMessages, vyLongreal, vyLongintVec, Oberon,
	MathL IN A2, Math IN A2, vyRandom, vyPort, antsReadWrite, Out, antsArrayObjects;

TYPE
	DistanceFunction* = PROCEDURE {DELEGATE} ( l, r: LONGINT ): LONGREAL;
	ApproximationFunction* = PROCEDURE {DELEGATE} ( l, r, pos: LONGINT ): LONGREAL;
	MultiresFunction* = PROCEDURE {DELEGATE} ( l, r: LONGINT ): BOOLEAN;
	GetLine = PROCEDURE {DELEGATE} ( x: LONGREAL;  VAR a, b: LONGREAL );
	ArrayR = POINTER TO ARRAY OF LONGREAL;
	ArrayR2 = POINTER TO ARRAY OF ARRAY OF LONGREAL;
	ArrayI = POINTER TO ARRAY OF LONGINT;

TYPE

	Intersection* = OBJECT
	VAR x-, aL-, bL-, aR-, bR-: LONGREAL;
		next*: Intersection;
	END Intersection;

	List = OBJECT
	VAR first, last: Intersection;

		PROCEDURE Append( x, aL, bL, aR, bR: LONGREAL );
		BEGIN
			aM.vSR( "append: ", x );
			IF first = NIL THEN NEW( first );  last := first;  ELSE NEW( last.next );  last := last.next;  END;
			last.x := x;  last.bL := bL;  last.aL := aL;  last.bR := bR;  last.aR := aR;   (* aM.SR( "Add intersection at ", x )*) ;
		END Append;

	END List;

	BaseObject = OBJECT (vyBase.Object)
	VAR len: LONGINT;
		factor: LONGREAL;   (* length of data vector*)
		data: vyLongrealVec.tVector;

		PROCEDURE Preparation( data: vyLongrealVec.tVector );
		BEGIN
			aM.eS( "Implement method Object.Preparation !! " );  HALT( 100 );
		END Preparation;

		PROCEDURE Distance( l, r: LONGINT ): LONGREAL;
		BEGIN
			aM.eS( "Implement method Object.Distance !! " );  HALT( 100 );
		END Distance;

		PROCEDURE Value( l, r, pos: LONGINT ): LONGREAL;
		BEGIN
			aM.eS( "Implement method Object.Value !!" );  HALT( 100 );
		END Value;

		PROCEDURE Multires( l, r: LONGINT ): BOOLEAN;
		BEGIN
			aM.eS( "Implement method Object.Multires !!" );  HALT( 100 );
		END Multires;

		PROCEDURE & Init;  (*factor is used in Multires*)
		BEGIN
			factor := 2.5;
		END Init;

	END BaseObject;

	LineFinder = OBJECT
	VAR
		n: LONGINT;
		d: DistanceFunction;
		iter, iterationlimit: LONGINT;

		PROCEDURE & Init( n: LONGINT;  d: DistanceFunction );
		BEGIN
			SELF.n := n;  SELF.d := d;  iter := 0;  iterationlimit := 2 * n;   (* heuristic *)
		END Init;

		PROCEDURE GetPottsLine( gamma: LONGREAL;  VAR a, b: LONGREAL );
		VAR p: ArrayI;  r, l: LONGINT;
		BEGIN
			INC( iter );
			IF iter > iterationlimit THEN HALT( 100 ) END;   (* iteration limit exceeded, nr of lines cannot exceed nr of data ! *)

			p := FindBestPartition( n, gamma, d );  r := n;  l := p[r];  a := 0;  b := 0;
			WHILE (r > 0) DO a := a + 1;  b := b + d( l + 1 - 1, r - 1 );  r := l;  l := p[r];  END;
			(* now a contains number of segments of the partition and b contains distance to data *)
			a := a (* - 1*)  - b;
			(* because we consider the functional gamma -> gamma * |P| + (1-gamma) * dist *)
		END GetPottsLine;

	END LineFinder;

	L2Object = OBJECT (BaseObject)
	VAR
		M, S, approx: ArrayR;

		PROCEDURE Value( l, r, pos: LONGINT ): LONGREAL;
		(* You can calculate the sum from position l to position r simply by subtracting
		 the value of M  (see PROCEDURE Preparation) at r from the value at l-1 and the mean of the interval [l,r] by dividing through the length of the interval*)
		VAR m: LONGREAL;
		BEGIN
			m := M[r];
			IF l > 0 THEN m := m - M[l - 1] END;
			RETURN m / (r - l + 1);
		END Value;

		PROCEDURE Distance( l, r: LONGINT ): LONGREAL;
		(* Returns the sum of squares in an interval [l,r].
		You get the used formula by multiplying out the underlying formula
		"sum[from l to r] (data[i]- mean[l,r]) ^2" :
		The first term (sum[from l to r] (data[i]^2 )) is S[r] - S[l-1],
		the middle term (2*sum[from l to r] (data[i])* mean[l,r]) is 2*(M[r]-M[l-1])*mean[l,r],
		and the last term (sum[from l to r] (mean[l,r]^2)) is (r-l-1)*mean[l,r]^2,
		and simplifying this using the formula for the mean given in PROCEDURE Value.
		*)
		VAR s, m: LONGREAL;
		BEGIN
			s := S[r];  m := M[r];
			IF l > 0 THEN s := s - S[l - 1];  m := m - M[l - 1] END;
			RETURN s - (m * m) / (r - l + 1);
		END Distance;

		PROCEDURE Preparation( data: vyLongrealVec.tVector );
		(*stores the sum of the data points from position 0 to i at position i in array M, and the sum of squares of the data points from position 0 to i at position i in array S *)
		VAR i: LONGINT;  m, s, val: LONGREAL;
		BEGIN
			SELF.data := data;  len := vyLongrealVec.Len( data );  NEW( M, len );  NEW( S, len );  m := 0;  s := 0;
			FOR i := 0 TO len - 1 DO val := vyLongrealVec.Get( data, i );  m := m + val;  s := s + val * val;  M[i] := m;  S[i] := s;  END;
		END Preparation;

		PROCEDURE Multires( l, r: LONGINT ): BOOLEAN;
		VAR i: LONGINT;  ok: BOOLEAN;  datavec: vyLongrealVec.tVector;
		BEGIN
			NEW( approx, r - l + 1 );  datavec := vyLongrealVec.New( r - l + 1 );
			FOR i := 0 TO r - l DO approx[i] := Value( l, r, 0 ) END;
			FOR i := l TO r DO vyLongrealVec.Set( vyLongrealVec.Get( data, i ), datavec, i - l ) END;
			ok := MultiResCheck( datavec, approx, factor );  RETURN ok;
		END Multires;

	END L2Object;

	L1Object = OBJECT (BaseObject)
	VAR M, D: ArrayR2;
		approx: ArrayR;
		temp: ArrayR;

		PROCEDURE Value( l, r, pos: LONGINT ): LONGREAL;
		BEGIN
			RETURN M[l, r]
		END Value;

		PROCEDURE Distance( l, r: LONGINT ): LONGREAL;
		BEGIN
			RETURN D[l, r]
		END Distance;

		PROCEDURE Preparation( data: vyLongrealVec.tVector );
		(*stores the median of the interval i to j of the data points in Matrix M at position [i,j],
		and the L1-distances from every data point in [i,j] to the median in [i,j] in D[i,j] *)
		VAR i, j, t: LONGINT;  sum, m: LONGREAL;  array: ArrayR;
		BEGIN
			SELF.data := data;  len := vyLongrealVec.Len( data );  NEW( M, len, len );  NEW( D, len, len );  NEW( array, len );
			vyLongrealVec.CopyToArray( data, array^ );  NEW( temp, len );

			FOR j := 0 TO len - 1 DO
				FOR i := 0 TO j DO m := median( array^, temp^, i, j );  M[i, j] := m;

					sum := 0;
					FOR t := i TO j DO sum := sum + ABS( array[t] - M[i, j] ) END;
					D[i, j] := sum;

				END;
			END;
		END Preparation;

		PROCEDURE Multires( l, r: LONGINT ): BOOLEAN;
		VAR i: LONGINT;  ok: BOOLEAN;  datavec: vyLongrealVec.tVector;
		BEGIN
			NEW( approx, r - l + 1 );  datavec := vyLongrealVec.New( r - l + 1 );
			FOR i := 0 TO r - l DO approx[i] := Value( l, r, 0 ) END;
			FOR i := l TO r DO vyLongrealVec.Set( vyLongrealVec.Get( data, i ), datavec, i - l ) END;
			ok := MultiResCheck( datavec, approx, factor );  RETURN ok;
		END Multires;

	END L1Object;

	HampelObject = OBJECT (BaseObject)
	VAR V, D: ArrayR2;
		approx: ArrayR;
		temp: ArrayR;
		c: LONGREAL;   (*c = intervalwidth*)

		PROCEDURE & Initialize;
		BEGIN
			c := 1;
		END Initialize;

		PROCEDURE Value( l, r, pos: LONGINT ): LONGREAL;
		BEGIN
			RETURN V[l, r]
		END Value;

		PROCEDURE Distance( l, r: LONGINT ): LONGREAL;
		BEGIN
			RETURN D[l, r]
		END Distance;

		PROCEDURE Preparation*( data: vyLongrealVec.tVector );
		(*Computes the Hampel function, which punishes deviations < |c| with the L2-Distance and deviations >=|c| with the constant value c*c; c is a constant. If you don't choose c in PROCEDURE NewHampelObject,
		it's set to 1, see PROCEDURE & Initialize*)

		VAR i, j, d, m, N, len1, len2: LONGINT;  t1, t2, fail1, fail2, tmin, failmin, prtrmean1, prtrmean2, prtrssq1, prtrssq2: LONGREAL;
			A, sortedArray, sums, ssqs: ArrayR;  ok1, ok2: BOOLEAN;
			interval1upper, interval1lower, interval2upper, interval2lower, intervallen: LONGINT;  left, right: LONGINT;
		BEGIN
			SELF.data := data;  len := vyLongrealVec.Len( data );  NEW( V, len, len );  NEW( D, len, len );  NEW( A, len );
			vyLongrealVec.CopyToArray( data, A^ );  NEW( temp, len );  N := len;  NEW( sortedArray, N );  NEW( sums, N );  NEW( ssqs, N );

			(* 1st Step (= 1. Loop): Splitting the data in every possible interval from i to j (i is decreased at the very end) *)
			FOR j := 0 TO N - 1 DO
				i := j;

				WHILE (i >= 0) DO
					intervallen := j - i + 1;   (*length of the array*)
					(* 2nd step: Sorting the array according to size of the data values and creating the sum-of-the-values-array and sum-of -the-SSQs-array *)
					CreateSortedArray( A^, i, j, sortedArray );   (* boundaries of the sorted array are 0 and j-i *)
					CreateSums( sortedArray^, intervallen, sums );  CreateSsqs( sortedArray^, intervallen, ssqs );

					failmin := MAX( LONGREAL );

					(* 3rd step: going through the sorted array, testing, if d is a lower or upper
					boundary of a valid interval.
					Thereto, we have to explicitly search for a lower and upper point starting at d. *)
					FOR d := 0 TO j - i DO

					(* 4th step: Counting the number of points in the interval d+2c (equivalent to len1). Thereto the following algorithm is
						looking for the point, which is the upper one of the interval. It is working with nested intervals , to save
						time. *)
					(*interval1: upper interval *)
						interval1lower := d;  t1 := sortedArray[d];  left := d;  right := j - i;
						IF ((sortedArray[right] - t1) <= 2 * c) THEN left := right;  ELSE
							WHILE (right - left > 1) DO
								m := (right + left) DIV 2;
								IF ((sortedArray[m] - t1) <= 2 * c) THEN left := m ELSE right := m END;
							END;
						END;
						interval1upper := left;

						len1 := interval1upper - interval1lower + 1;

						(*5th step:  Calculating the mean of interval 1*)
						prtrmean1 := sums[interval1upper];  prtrssq1 := ssqs[interval1upper];
						IF interval1lower > 0 THEN
							prtrmean1 := prtrmean1 - sums[interval1lower - 1];  prtrssq1 := prtrssq1 - ssqs[interval1lower - 1];
						END;
						prtrmean1 := prtrmean1 / len1;  t1 := prtrmean1;

						(*6th & 7th step: Doing 4th and 5th step for interval 2 (lower interval) as well*)
						interval2upper := d;  t2 := sortedArray[d];  left := 0;  right := d;
						IF ((t2 - sortedArray[left]) <= 2 * c) THEN right := left;  ELSE
							WHILE (right - left > 1) DO
								m := (right + left) DIV 2;
								IF ((t2 - sortedArray[m]) <= 2 * c) THEN right := m ELSE left := m END;
							END;
						END;
						interval2lower := right;

						len2 := interval2upper - interval2lower + 1;

						prtrmean2 := sums[interval2upper];  prtrssq2 := ssqs[interval2upper];
						IF interval2lower > 0 THEN
							prtrmean2 := prtrmean2 - sums[interval2lower - 1];  prtrssq2 := prtrssq2 - ssqs[interval2lower - 1];
						END;
						prtrmean2 := prtrmean2 / len2;  t2 := prtrmean2;

						ok1 := TRUE;  ok2 := TRUE;

						(*8th step: Checking for interval 1 if the interval t1 +- c and the interval [interval1lower, interval1upper] contain same data points, by checking the two conditions:
						1.: Is data in the interval?
						2.: Are values outside the boundaries in the interval?
						If 1. is true and 2. false, ok1 remains true. *)
						IF (ABS( sortedArray[interval1lower] - t1 ) > c) OR (ABS( sortedArray[interval1upper] - t1 ) > c) OR
						    ((interval1lower > 0) & (ABS( sortedArray[interval1lower - 1] - t1 ) <= c)) OR
						    ((interval1upper + 1 < intervallen) & (ABS( sortedArray[interval1upper + 1] - t1 ) <= c)) THEN
							ok1 := FALSE
						END;

						(*9th step: Executing 8th step for interval 2*)
						IF (ABS( sortedArray[interval2lower] - t2 ) > c) OR (ABS( sortedArray[interval2upper] - t2 ) > c) OR
						    ((interval2lower > 0) & (ABS( sortedArray[interval2lower - 1] - t2 ) <= c)) OR
						    ((interval2upper + 1 < intervallen) & (ABS( sortedArray[interval2upper + 1] - t2 ) <= c)) THEN
							ok2 := FALSE
						END;

						(* 10th step: If interval has passed validity check: Calculating the minimum of the SSQ (fail) (according to the formula in Christine Porzelius' Praktikumsbericht section "Abstandsfunktionen" subsection "Hampel")
						and taking the mean belonging to it*)
						IF ok1 = TRUE THEN
							prtrssq1 := prtrssq1 - prtrmean1 * prtrmean1 * len1;  fail1 := prtrssq1 + c * c * ((j - i + 1) - (len1));
							IF fail1 < failmin THEN tmin := t1;  failmin := fail1;  END;
						END;

						IF ok2 = TRUE THEN
							prtrssq2 := prtrssq2 - prtrmean2 * prtrmean2 * len2;  fail2 := prtrssq2 + c * c * ((j - i + 1) - (len2));
							IF fail2 < failmin THEN tmin := t2;  failmin := fail2;  END;
						END;
					END;
					V[i, j] := tmin;  D[i, j] := failmin;  DEC( i )

				END
			END
		END Preparation;

		PROCEDURE Multires( l, r: LONGINT ): BOOLEAN;
		VAR i: LONGINT;  ok: BOOLEAN;  datavec: vyLongrealVec.tVector;
		BEGIN
			NEW( approx, r - l + 1 );  datavec := vyLongrealVec.New( r - l + 1 );
			FOR i := 0 TO r - l DO approx[i] := Value( l, r, 0 ) END;
			FOR i := l TO r DO vyLongrealVec.Set( vyLongrealVec.Get( data, i ), datavec, i - l ) END;
			ok := MultiResCheck( datavec, approx, factor );  RETURN ok;
		END Multires;

	END HampelObject;

	SaegezahnObject = OBJECT (BaseObject)
	VAR V, D: ArrayR2;
		approx: ArrayR;
		temp: ArrayR;
		c: LONGREAL;   (*c = intervalwidth*)

		PROCEDURE & Initialize;
		BEGIN
			c := 1;
		END Initialize;

		PROCEDURE Value( l, r, pos: LONGINT ): LONGREAL;
		BEGIN
			RETURN V[l, r]
		END Value;

		PROCEDURE Distance( l, r: LONGINT ): LONGREAL;
		BEGIN
			RETURN D[l, r]
		END Distance;

		PROCEDURE Preparation*( data: vyLongrealVec.tVector );
		(*like hampel, but the deviations < |c| are punished with the  L1-distance instead of the L2-distance. The deviations >= |c| are punished with the constant value c. The Median minimises the error.
		If you don't choose c in PROCEDURE NewSaegezahnObject, it's set to 1, see PROCEDURE & Initialize*)

		VAR i, j, k, d, m, N: LONGINT;  t1, t2, fail, tmin, failmin: LONGREAL;  A, sortedArray: ArrayR;  ok1, ok2: BOOLEAN;
			interval1upper, interval1lower, interval2upper, interval2lower, intervallen, idist, left, right: LONGINT;
		BEGIN
			SELF.data := data;  len := vyLongrealVec.Len( data );  NEW( V, len, len );  NEW( D, len, len );  NEW( A, len );
			vyLongrealVec.CopyToArray( data, A^ );  NEW( temp, len );  N := len;  NEW( sortedArray, N );

			(* 1st Step (= 1. Loop): Splitting the data in every possible interval from i to j (i is decreased at the very end) *)
			FOR j := 0 TO N - 1 DO
				i := j;

				WHILE (i >= 0) DO
					intervallen := j - i + 1;   (*length of the array*)
					(* 2nd step: Sorting the array according to size of the data values *)
					CreateSortedArray( A^, i, j, sortedArray );   (* boundaries of the sorted array are 0 und j-i *)

					failmin := MAX( LONGREAL );

					(* 3rd step: going through the sorted array, testing, if d is a lower or upper
					boundary of a valid interval.
					Thereto, we have to explicitly search for a lower and upper point starting at d. *)
					FOR d := 0 TO j - i DO

					(* 4th step: Counting the number of points in the interval d+2c (equivalent to len1). Thereto the following algorithm is
						looking for the point, which is the upper one of the interval. It is working with nested intervals, to save
						time.
						 *)
					(*interval1: upper interval *)
						interval1lower := d;  t1 := sortedArray[d];  left := d;  right := j - i;
						IF ((sortedArray[right] - t1) <= 2 * c) THEN left := right;  ELSE
							WHILE (right - left > 1) DO
								m := (right + left) DIV 2;
								IF ((sortedArray[m] - t1) <= 2 * c) THEN left := m ELSE right := m END;
							END;
						END;
						interval1upper := left;

						(*5th step: Doing step 4 for interval 2 ( lower interval) *)
						interval2upper := d;  t2 := sortedArray[d];  left := 0;  right := d;
						IF ((t2 - sortedArray[left]) <= 2 * c) THEN right := left;  ELSE
							WHILE (right - left > 1) DO
								m := (right + left) DIV 2;
								IF ((t2 - sortedArray[m]) <= 2 * c) THEN right := m ELSE left := m END;
							END;
						END;
						interval2lower := right;


						(*6th step: Calculating the median for interval 1 and 2: *)

						IF ODD( interval1upper + interval1lower ) THEN
							t1 :=
								(sortedArray[(interval1upper + interval1lower + 1) DIV 2] +
								  sortedArray[(interval1upper + interval1lower) DIV 2]) / 2
						ELSE
							t1 := sortedArray[(interval1upper + interval1lower) DIV 2];   (* median *)
						END;

						IF ODD( interval2upper + interval2lower ) THEN
							t2 :=
								(sortedArray[(interval2upper + interval2lower + 1) DIV 2] +
								  sortedArray[(interval2upper + interval2lower) DIV 2]) / 2
						ELSE
							t2 := sortedArray[(interval2upper + interval2lower) DIV 2];   (* median *)
						END;

						(*
						t1 := median(sortedArray^,temp^,interval1lower,interval1upper);
						t2 := median(sortedArray^,temp^,interval2lower,interval2upper);
						*)


						ok1 := TRUE;  ok2 := TRUE;

						(*7th step: Checking for interval 1 if the interval t1 +- c and the interval [interval1lower, interval1upper] are equal, by checking the two conditions:
						1.: Is data in the interval ?
						2.: Are values outside the boundaries in the interval?
						If 1. is true and 2. false, ok1 remains true. *)

						IF (ABS( sortedArray[interval1lower] - t1 ) > c) OR (ABS( sortedArray[interval1upper] - t1 ) > c) OR
						    ((interval1lower > 0) & (ABS( sortedArray[interval1lower - 1] - t1 ) <= c)) OR
						    ((interval1upper + 1 < intervallen) & (ABS( sortedArray[interval1upper + 1] - t1 ) <= c)) THEN
							ok1 := FALSE
						END;

						(*8th step: Executing 8th step for interval 2*)
						IF (ABS( sortedArray[interval2lower] - t2 ) > c) OR (ABS( sortedArray[interval2upper] - t2 ) > c) OR
						    ((interval2lower > 0) & (ABS( sortedArray[interval2lower - 1] - t2 ) <= c)) OR
						    ((interval2upper + 1 < intervallen) & (ABS( sortedArray[interval2upper + 1] - t2 ) <= c)) THEN
							ok2 := FALSE
						END;

						(* 9th step: If interval has passed validity check: Calculating the minimum of the SSQ (fail) (according to the formula in Christine Porzelius' Praktikumsbericht section "Abstandsfunktionen", subsection "Sägezahn")
						and taking the median belonging to it*)
						IF ok1 = TRUE THEN
							fail := ABS( c ) * ((j - i) - (interval1upper - interval1lower));  k := interval1lower;
							WHILE (fail < failmin) & (k <= interval1upper) DO fail := fail + ABS( sortedArray[k] - t1 );  INC( k );  END;
							IF fail < failmin THEN tmin := t1;  failmin := fail;  END;
						END;

						IF ok2 = TRUE THEN
							fail := ABS( c ) * ((j - i) - (interval2upper - interval2lower));  k := interval2lower;
							WHILE (fail < failmin) & (k <= interval2upper) DO fail := fail + ABS( sortedArray[k] - t2 );  INC( k );  END;
							IF fail < failmin THEN tmin := t2;  failmin := fail;  END;
						END;

					END;

					V[i, j] := tmin;  D[i, j] := failmin;  DEC( i )

				END
			END

		END Preparation;

		PROCEDURE Multires( l, r: LONGINT ): BOOLEAN;
		VAR i: LONGINT;  ok: BOOLEAN;  datavec: vyLongrealVec.tVector;
		BEGIN
			NEW( approx, r - l + 1 );  datavec := vyLongrealVec.New( r - l + 1 );
			FOR i := 0 TO r - l DO approx[i] := Value( l, r, 0 ) END;
			FOR i := l TO r DO vyLongrealVec.Set( vyLongrealVec.Get( data, i ), datavec, i - l ) END;
			ok := MultiResCheck( datavec, approx, factor );  RETURN ok;
		END Multires;

	END SaegezahnObject;

	HuberObject = OBJECT (BaseObject)
	VAR V, D: ArrayR2;
		approx: ArrayR;
		temp: ArrayR;
		c: LONGREAL;

		PROCEDURE & Initialize;
		BEGIN
			c := 1;
		END Initialize;   (*c = intervalwidth*)


		PROCEDURE Value( l, r, pos: LONGINT ): LONGREAL;
		BEGIN
			RETURN V[l, r]
		END Value;

		PROCEDURE Distance( l, r: LONGINT ): LONGREAL;
		BEGIN
			RETURN D[l, r]
		END Distance;

		PROCEDURE Preparation*( data: vyLongrealVec.tVector );
		(*Deviations < |c| are punished with the L2-distance, deviations >= |c| only with L1-distance. If you don't choose c in PROCEDURE NewHuberObject,
		it's set to 1, see PROCEDURE & Initialize*)

		VAR i, j, d, m, N, len1, len2: LONGINT;  t1, t2, fail, tmin, failmin, prtrmeanmed1, prtrmeanmed2, prtrssqsum1, prtrssqsum2: LONGREAL;
			A, sortedArray, sums, ssqs: ArrayR;  ok1, ok2: BOOLEAN;
			interval1upper, interval1lower, interval2upper, interval2lower, intervallen: LONGINT;  left, right: LONGINT;
		BEGIN
			SELF.data := data;  len := vyLongrealVec.Len( data );  NEW( V, len, len );  NEW( D, len, len );  NEW( A, len );
			vyLongrealVec.CopyToArray( data, A^ );  NEW( temp, len );  N := len;  NEW( sortedArray, N );  NEW( sums, N );  NEW( ssqs, N );

			(* 1st Step (= 1. Loop): Splitting the data in every possible interval from i to j (i is decreased at the very end) *)
			FOR j := 0 TO N - 1 DO
				i := j;

				WHILE (i >= 0) DO
					intervallen := j - i + 1;   (*length of the array*)

					(* 2nd step: Sorting the array according to size of the data values and creating the sum-of-the-values-array and sum-of -SSQs-array *)
					CreateSortedArray( A^, i, j, sortedArray );   (* boundaries of the sorted array are 0 und j-i *)
					CreateSums( sortedArray^, intervallen, sums );  CreateSsqs( sortedArray^, intervallen, ssqs );

					failmin := MAX( LONGREAL );

					(* 3rd step: going through the sorted array, testing, if d is a lower or upper
					boundary of a valid interval.
					Thereto, we have to explicitly search for a lower and upper point starting at d. *)
					FOR d := 0 TO j - i DO

					(* 4th step: Counting the number of points in the interval d+2c (equivalent to len1). Thereto the following algorithm is
						looking for the point, which is the upper one of the interval. It is working with nested intervals, to save
						time.
						 *)
					(*interval1: upper interval *)
						interval1lower := d;  t1 := sortedArray[d];

						left := d;  right := j - i;
						IF ((sortedArray[right] - t1) <= 2 * c) THEN left := right;  ELSE
							WHILE (right - left > 1) DO
								m := (right + left) DIV 2;
								IF ((sortedArray[m] - t1) <= 2 * c) THEN left := m ELSE right := m END;
							END;
						END;
						interval1upper := left;  len1 := interval1upper - interval1lower + 1;

						(*5th step: Calculating the mean for interval 1*)
						prtrmeanmed1 := sums[interval1upper];  prtrssqsum1 := ssqs[interval1upper];
						IF interval1lower > 0 THEN
							prtrmeanmed1 := prtrmeanmed1 - sums[interval1lower - 1];
							prtrssqsum1 := prtrssqsum1 - ssqs[interval1lower - 1];
						END;

						(*6th step: Calculating the minimiser of the Huber function, according to the formula in Christine Porzelius' Praktikumsbericht section "Abstandsfunktionen", subsection "Huber"*)
						ASSERT ( len1 > 0, 1003 );
						t1 := (prtrmeanmed1 + c * interval1lower - c * (j - i - interval1upper)) / (len1);

						(*7th, 8th and 9th step: Doing 4th, 5th and 6th step for interval 2 (lower interval) as well*)
						interval2upper := d;  t2 := sortedArray[d];  left := 0;  right := d;
						IF ((t2 - sortedArray[left]) <= 2 * c) THEN right := left;  ELSE
							WHILE (right - left > 1) DO
								m := (right + left) DIV 2;
								IF ((t2 - sortedArray[m]) <= 2 * c) THEN right := m ELSE left := m END;
							END;
						END;
						interval2lower := right;

						len2 := interval2upper - interval2lower + 1;

						prtrmeanmed2 := sums[interval2upper];  prtrssqsum2 := ssqs[interval2upper];
						IF interval2lower > 0 THEN
							prtrmeanmed2 := prtrmeanmed2 - sums[interval2lower - 1];
							prtrssqsum2 := prtrssqsum2 - ssqs[interval2lower - 1];
						END;
						ASSERT ( len2 > 0, 1004 );
						t2 := (prtrmeanmed2 + c * interval2lower - c * (j - i - interval2upper)) / (len2);

						ok1 := TRUE;  ok2 := TRUE;

						(*10th step: Checking for interval 1 if the interval t1 +- c and the interval [interval1lower, interval1upper] are equal, by checking the two conditions:
						1.: Is data in the interval ?
						2.: Are values outside the boundaries in the interval?
						If 1. is true and 2. false, ok1 remains true. *)
						IF (ABS( sortedArray[interval1lower] - t1 ) > c) OR (ABS( sortedArray[interval1upper] - t1 ) > c) OR
						    ((interval1lower > 0) & (ABS( sortedArray[interval1lower - 1] - t1 ) <= c)) OR
						    (((interval1upper + 1) < intervallen) & (ABS( sortedArray[interval1upper + 1] - t1 ) <= c)) THEN
							ok1 := FALSE;
						END;

						(*11th step: Executing 10th step for interval 2*)
						IF (ABS( sortedArray[interval2lower] - t2 ) > c) OR (ABS( sortedArray[interval2upper] - t2 ) > c) OR
						    ((interval2lower > 0) & (ABS( sortedArray[interval2lower - 1] - t2 ) <= c)) OR
						    (((interval2upper + 1) < intervallen) & (ABS( sortedArray[interval2upper + 1] - t2 ) <= c)) THEN
							ok2 := FALSE;
						END;

						(* 12th step: If If interval has passed validity check: Calculating the minimum of the SSQ (fail) (according to the (corrected!!!) formula in Christine Porzelius' Praktikumsbericht section "Abstandsfunktionen", subsection "Huber"
						and taking the minimiser belonging to it*)
						IF ok1 = TRUE THEN

							(*preparation*)
							IF interval1lower > 0 THEN
								prtrssqsum1 := prtrssqsum1 - 2 * c * sums[interval1lower - 1];   (* last term: calculating the sum of values from 0 to interval1lower-1 *)
							END;

							IF (interval1upper + 1) < intervallen THEN
								prtrssqsum1 := prtrssqsum1 + 2 * c * (sums[j - i] - sums[interval1upper]);   (* last term: calculating the sum of values from interval1upper+1 to LEN(sortedArray)-1 *)
							END;

							fail :=
								prtrssqsum1 - 2 * prtrmeanmed1 * t1 + ((len1) * (t1 * t1)) +
								c * (interval1lower * (2 * t1 - c) - (j - i - interval1upper) * (2 * t1 + c));
							ASSERT ( fail >= 0, 1005 );
							IF fail < failmin THEN tmin := t1;  failmin := fail;  END;
						END;

						IF ok2 = TRUE THEN

							(*preparation*)
							IF interval2lower > 0 THEN
								prtrssqsum2 := prtrssqsum2 - 2 * c * sums[interval2lower - 1];   (* last term: calculating the sum of values from 0 to interval2lower-1 *)
							END;
							IF (interval2upper + 1) < intervallen THEN
								prtrssqsum2 := prtrssqsum2 + 2 * c * (sums[j - i] - sums[interval2upper]);   (*last term: calculating the sum of values from 0 to interval2upper+1 to LEN(sortedArray)-1 *)
							END;

							fail :=
								prtrssqsum2 - 2 * prtrmeanmed2 * t2 + ((len2) * (t2 * t2)) +
								c * (interval2lower * (2 * t2 - c) - (j - i - interval2upper) * (2 * t2 + c));
							ASSERT ( fail >= 0, 1005 );
							IF fail < failmin THEN tmin := t2;  failmin := fail;  END;
						END;

					END;

					ASSERT ( failmin >= 0, 1002 );

					V[i, j] := tmin;  D[i, j] := failmin;  DEC( i );
				END
			END

		END Preparation;

		PROCEDURE Multires( l, r: LONGINT ): BOOLEAN;
		VAR i: LONGINT;  ok: BOOLEAN;  datavec: vyLongrealVec.tVector;
		BEGIN
			NEW( approx, r - l + 1 );  datavec := vyLongrealVec.New( r - l + 1 );
			FOR i := 0 TO r - l DO approx[i] := Value( l, r, 0 ) END;
			FOR i := l TO r DO vyLongrealVec.Set( vyLongrealVec.Get( data, i ), datavec, i - l ) END;
			ok := MultiResCheck( datavec, approx, factor );  RETURN ok;
		END Multires;

	END HuberObject;

VAR

	PROCEDURE FindBestPartition*( n: LONGINT;  gamma: LONGREAL;  d: DistanceFunction ): ArrayI;
	(*delivers the best partition by going through the data from left to right and calculating stepwise the minimum of the Bellman function.
	It uses B(r) = min B(l-1) + gamma + (1- gamma)* d[l,r], see "Complexity Penalised M-Estimation: Fast Computation", Lemma 1, with term (1-gamma) as correction, since we use a variant of
	the functional there.
	In other words: at a point r you know the best partition until r-1. The best partition at r consists of the minimiser of a best partition at l-1 together with the new interval [l,r].
	 *)
	VAR l, r: LONGINT;  B: ArrayR;  p: ArrayI;  b: LONGREAL;
	BEGIN
		NEW( B, n + 1 );  NEW( p, n + 1 );  B[0] := -gamma;   (*by defintion*)
		p[0] := -1;   (* p[0] is redundant, needed for consistency with offset of B *)
		FOR r := 1 TO n DO
			B[r] := MAX( LONGREAL );   (**)
			FOR l := 1 TO r DO
				b := B[l - 1] + gamma + (1 - gamma) * d( l - 1, r - 1 );   (* -1 at d(.,.)  for offset correction, Oberon
				arrays start at zero *)
				IF b <= B[r] THEN B[r] := b;  p[r] := l - 1;  END;
			END;
		END;
		RETURN p;
	END FindBestPartition;

	PROCEDURE FindBestMRPartition*( n: LONGINT;  mr: MultiresFunction ): ArrayI;   (*as FindBestPartition but the Multiresolution Criterion has to be fulfilled for every interval*)
	VAR l, r: LONGINT;  B: ArrayR;  p: ArrayI;  b: LONGREAL;  ok: BOOLEAN;
	BEGIN
		NEW( B, n + 1 );  NEW( p, n + 1 );  B[0] := -1;   (*by defintion*)
		p[0] := -1;   (* p[0] is redundant, needed for consistency with offset of B *)
		FOR r := 1 TO n DO
			B[r] := MAX( LONGREAL );   (**)
			FOR l := 1 TO r DO
				b := B[l - 1] + 1;   (* -1 at d(.,.)  for offset correction, Oberon
				arrays start at zero *)
				IF (b <= B[r]) & mr( l - 1, r - 1 ) THEN B[r] := b;  p[r] := l - 1;  END;   (* -1 at mr(.,.)  for offset correction, Oberon
				arrays start at zero *)
			END;
		END;
		RETURN p;

	END FindBestMRPartition;

	PROCEDURE SegmentationFromPartition*( VAR p: ARRAY OF LONGINT;  mu: ApproximationFunction ): ArrayR;
	(*complements the partition found with PROCEDURE FindBestPartition by the values on intervals and delivers a segmentation*)
	VAR n: LONGINT;  y: ArrayR;  l, r, t: LONGINT;
	BEGIN
		n := LEN( p ) - 1;  NEW( y, n );  r := n;
		l := p[r];   (*because LEN(p)=n+1*)
		WHILE l > -1 DO
			FOR t := l + 1 TO r DO
				y[t - 1] := mu( l + 1 - 1, r - 1, t - 1 );   (* -1 at mu (.,.,.) for offset correction, Oberon arrays start at zero *)
			END;
			r := l;  l := p[r];
		END;
		RETURN y;
	END SegmentationFromPartition;

	PROCEDURE Minimisation*( n: LONGINT;  gamma: LONGREAL;  d: DistanceFunction;  mu: ApproximationFunction ): ArrayR;
	VAR y: ArrayR;  p: ArrayI;
	BEGIN
		p := FindBestPartition( n, gamma, d );  y := SegmentationFromPartition( p^, mu );  RETURN y;
	END Minimisation;

	PROCEDURE MinimisationMR*( n: LONGINT;  mr: MultiresFunction;  mu: ApproximationFunction ): ArrayR;
	VAR y: ArrayR;  p: ArrayI;
	BEGIN
		p := FindBestMRPartition( n, mr );  y := SegmentationFromPartition( p^, mu );  RETURN y;
	END MinimisationMR;

	PROCEDURE CreateSortedArray( VAR y: ARRAY OF LONGREAL;  start, ende: LONGINT;  VAR yneu: ArrayR );
	VAR len: LONGINT;

	BEGIN
		len := ende - start + 1;
		IF (yneu = NIL ) OR (LEN( yneu ) < len) THEN NEW( yneu, len );  END;

		vyLongreal.Copy( len, y, start, yneu^, 0 );  vyLongreal.Sort( len, yneu^, 0 );
	END CreateSortedArray;

	PROCEDURE CreateSums( VAR y: ARRAY OF LONGREAL;  len: LONGINT;  VAR yneu: ArrayR );
	(*creates an array in which the sum of the data points from 0 to i is stored at position i*)
	VAR val: LONGREAL;  i: LONGINT;
	BEGIN
		IF (yneu = NIL ) OR (LEN( yneu ) < len) THEN NEW( yneu, len );  END;
		val := 0;
		FOR i := 0 TO len - 1 DO val := val + y[i];  yneu[i] := val;  END;

	END CreateSums;

	PROCEDURE CreateSsqs( VAR y: ARRAY OF LONGREAL;  len: LONGINT;  VAR yneu: ArrayR );
	(*creates an array in which the sum of squares of the data points from 0 to i is stored at position i*)

	VAR val, valsq: LONGREAL;  i: LONGINT;
	BEGIN
		IF (yneu = NIL ) OR (LEN( yneu ) < len) THEN NEW( yneu, len );  END;

		valsq := 0;
		FOR i := 0 TO len - 1 DO val := y[i];  valsq := valsq + val * val;  yneu[i] := valsq;  END;
	END CreateSsqs;

	PROCEDURE median( VAR y: ARRAY OF LONGREAL;  VAR temp: ARRAY OF LONGREAL;  start, ende: LONGINT ): LONGREAL;
	VAR len: LONGINT;
	BEGIN
		len := ende - start + 1;  vyLongreal.Copy( len, y, start, temp, 0 );  RETURN antsArrays.Median1dX( temp, len );
	END median;

	PROCEDURE StartTiming( VAR time: LONGINT );
	BEGIN
		time := Oberon.Time();
	END StartTiming;

	PROCEDURE StopTiming( s: ARRAY OF CHAR;  VAR time: LONGINT );
	BEGIN
		aM.vSI( s, Oberon.Time() - time );
	END StopTiming;

	PROCEDURE NewL2Object*;
	VAR in: vyLongrealVec.tVector;  obj: vyBase.Object;
		objname: ARRAY 256 OF CHAR;
		time: LONGINT;  o: L2Object;
	BEGIN
		antsCommands.InitScan( "in=OBJECT object=NAME" );
		IF antsCommands.ExpectObject( "in", obj ) & antsCommands.ExpectName( "object", objname ) THEN
			StartTiming( time );  in := obj( vyLongrealVec.tVector );  obj := vyName.FindObj( objname );
			IF (obj = NIL ) OR (~(obj IS L2Object)) THEN NEW( o );  vyName.RegisterNamed( o, objname );  aM.SS( "Object neu registriert unter: ", objname );
			ELSE o := obj( L2Object );
			END;
			o.Preparation( in );  StopTiming( "L2 Time ", time );
		END;
	END NewL2Object;

	PROCEDURE NewL1Object*;
	VAR in: vyLongrealVec.tVector;  obj: vyBase.Object;
		objname: ARRAY 256 OF CHAR;
		time: LONGINT;  o: L1Object;
	BEGIN
		antsCommands.InitScan( "in=OBJECT object=NAME" );
		IF antsCommands.ExpectObject( "in", obj ) & antsCommands.ExpectName( "object", objname ) THEN
			StartTiming( time );  in := obj( vyLongrealVec.tVector );  obj := vyName.FindObj( objname );
			IF (obj = NIL ) OR (~(obj IS L1Object)) THEN NEW( o );  vyName.RegisterNamed( o, objname );  aM.SS( "Object neu registriert unter: ", objname );
			ELSE o := obj( L1Object );
			END;
			o.Preparation( in );  StopTiming( "L1 Time ", time );
		END;
	END NewL1Object;

	PROCEDURE NewHampelObject*;
	VAR in: vyLongrealVec.tVector;  obj: vyBase.Object;
		objname: ARRAY 256 OF CHAR;
		o: HampelObject;  c: LONGREAL;  time: LONGINT;
	BEGIN
		antsCommands.InitScan( "in=OBJECT object=NAME" );
		IF antsCommands.ExpectObject( "in", obj ) & antsCommands.ExpectName( "object", objname ) THEN
			StartTiming( time );  in := obj( vyLongrealVec.tVector );  obj := vyName.FindObj( objname );
			IF (obj = NIL ) OR (~(obj IS HampelObject)) THEN NEW( o );  vyName.RegisterNamed( o, objname );  aM.SS( "Object neu registriert unter: ", objname );
			ELSE o := obj( HampelObject );
			END;
			IF antsCommands.GetReal( "c", c ) THEN o.c := c;  ELSE o.c := FindConstant( in );  END;
			aM.SR( "Using Hampel with width = ", o.c );  o.Preparation( in );  StopTiming( "Hampel Time ", time );
		END;
	END NewHampelObject;

	PROCEDURE NewSaegezahnObject*;
	VAR in: vyLongrealVec.tVector;  obj: vyBase.Object;
		objname: ARRAY 256 OF CHAR;
		o: SaegezahnObject;  c: LONGREAL;  time: LONGINT;
	BEGIN
		antsCommands.InitScan( "in=OBJECT object=NAME" );
		IF antsCommands.ExpectObject( "in", obj ) & antsCommands.ExpectName( "object", objname ) THEN
			StartTiming( time );  in := obj( vyLongrealVec.tVector );  obj := vyName.FindObj( objname );
			IF (obj = NIL ) OR (~(obj IS SaegezahnObject)) THEN
				NEW( o );  vyName.RegisterNamed( o, objname );  aM.SS( "Object neu registriert unter: ", objname );
			ELSE o := obj( SaegezahnObject );
			END;
			IF antsCommands.GetReal( "c", c ) THEN o.c := c;  ELSE o.c := FindConstant( in );  END;
			aM.SR( "Using Saegezahn with width = ", o.c );

			o.Preparation( in );  StopTiming( "Saegezahn Time ", time );
		END;
	END NewSaegezahnObject;

	PROCEDURE NewHuberObject*;
	VAR in: vyLongrealVec.tVector;  obj: vyBase.Object;
		objname: ARRAY 256 OF CHAR;
		o: HuberObject;  c: LONGREAL;  time: LONGINT;
	BEGIN
		antsCommands.InitScan( "in=OBJECT object=NAME" );
		IF antsCommands.ExpectObject( "in", obj ) & antsCommands.ExpectName( "object", objname ) THEN
			StartTiming( time );  in := obj( vyLongrealVec.tVector );  obj := vyName.FindObj( objname );
			IF (obj = NIL ) OR (~(obj IS HuberObject)) THEN NEW( o );  vyName.RegisterNamed( o, objname );  aM.SS( "Object neu registriert unter: ", objname );
			ELSE o := obj( HuberObject );
			END;
			IF antsCommands.GetReal( "c", c ) THEN o.c := c;  ELSE o.c := FindConstant( in );  END;
			aM.SR( "Using Huber with width = ", o.c );

			o.Preparation( in );  StopTiming( "Huber Time ", time );
		END;
	END NewHuberObject;

	PROCEDURE Minimise*;
	VAR in: BaseObject;  out: vyLongrealVec.tVector;  obj: vyBase.Object;  len: LONGINT;
		outname: ARRAY 256 OF CHAR;
		gamma: LONGREAL;  outarray: ArrayR;
	BEGIN
		antsCommands.InitScan( "in=OBJECT gamma=REAL out=OBJECT|NAME" );
		IF antsCommands.ExpectObject( "in", obj ) & antsCommands.ExpectReal( "gamma", gamma ) &
		    antsCommands.ExpectName( "out", outname ) THEN
			IF (gamma < 0) OR (gamma > 1) THEN aM.S( "Gamma muss im Intervall [0,1] liegen, aber ich mach trotzdem weiter." );  END;
			IF obj IS BaseObject THEN in := obj( BaseObject );  ELSE aM.S( "Object is of incompatible type" );  RETURN;  END;
			len := in.len;
			(* aM.SI("Len = ",len); *)

			obj := vyName.FindObj( outname );
			IF obj = NIL THEN out := vyLongrealVec.New( len );  vyName.RegisterNamed( out, outname );  aM.SS( "Vektor neu registriert unter: ", outname );
			ELSE out := obj( vyLongrealVec.tVector );  vyLongrealVec.SetLen( out, len );
			END;
			outarray := Minimisation( len, gamma, in.Distance, in.Value );  aM.dSR( "gamma= ", gamma );

			vyLongrealVec.CopyToVec( outarray^, out, len, 0, 0 );  vyBase.Update( out );
		END;
	END Minimise;

	PROCEDURE MinimiseMR*;   (*Another possibility to get a partition according to the multiresolution criterion. The functional is not used, no gamma is needed.*)
	VAR in: BaseObject;  out: vyLongrealVec.tVector;  obj: vyBase.Object;  len: LONGINT;
		outname: ARRAY 256 OF CHAR;
		factor: LONGREAL;  outarray: ArrayR;
	BEGIN
		antsCommands.InitScan( "in=OBJECT  out=OBJECT|NAME" );
		IF antsCommands.ExpectObject( "in", obj ) & antsCommands.ExpectName( "out", outname ) THEN
			IF obj IS BaseObject THEN in := obj( BaseObject );  ELSE aM.S( "Object is of incompatible type" );  RETURN;  END;
			len := in.len;
			(* aM.SI("Len = ",len); *)

			IF (~antsCommands.Find( "factor" )) OR (~antsCommands.ExpectReal( "factor", factor )) THEN factor := 2.5 END;

			obj := vyName.FindObj( outname );
			IF obj = NIL THEN out := vyLongrealVec.New( len );  vyName.RegisterNamed( out, outname );  aM.SS( "Vektor neu registriert unter: ", outname );
			ELSE out := obj( vyLongrealVec.tVector );  vyLongrealVec.SetLen( out, len );
			END;
			in.factor := factor;

			outarray := MinimisationMR( len, in.Multires, in.Value );  vyLongrealVec.CopyToVec( outarray^, out, len, 0, 0 );
			vyBase.Update( out );
		END;
	END MinimiseMR;

	PROCEDURE MinimiseScale*;
	VAR in: BaseObject;  out: vyLongrealVec.tVector;  obj: vyBase.Object;  len, i: LONGINT;
		outname: ARRAY 256 OF CHAR;
		gamma: LONGREAL;  outarray: ArrayR;  a, b: LONGREAL;  line: LineFinder;
	BEGIN
		antsCommands.InitScan( "in=OBJECT  out=OBJECT|NAME" );
		IF antsCommands.ExpectObject( "in", obj ) & antsCommands.ExpectName( "out", outname ) THEN
			IF obj IS BaseObject THEN in := obj( BaseObject );  ELSE aM.S( "Object is of incompatible type" );  RETURN;  END;
			len := in.len;
			(* aM.SI("Len = ",len); *)

			out := VectToName( outname, 1001 );

			NEW( line, len, in.Distance );  line.iterationlimit := 10000;

			FOR i := 0 TO 1000 DO line.GetPottsLine( i / 1000, a, b );  vyLongrealVec.Set( i / 1000 * a + b, out, i );

			END;

			vyBase.Update( out );
		END;

	END MinimiseScale;


(*
	PROCEDURE Test*;
	VAR in, out: vyLongrealVec.tVector;  obj: vyBase.Object;  len: LONGINT;
		outname: ARRAY 256 OF CHAR;
		gamma: LONGREAL;  outarray: ArrayR;  o: L2Object;
	BEGIN
		antsCommands.InitScan( "in=OBJECT gamma=REAL out=OBJECT|NAME" );
		IF antsCommands.ExpectObject( "in", obj ) & antsCommands.ExpectReal( "gamma", gamma ) &
		    antsCommands.ExpectName( "out", outname ) THEN
			IF (gamma < 0) OR (gamma > 1) THEN aM.S( "Gamma muss im Intervall [0,1] liegen." );  RETURN END;
			(*
		    IF (gamma=1) THEN
		    	gamma := MAX(LONGREAL)/2;  (* "infinity" *)
		     ELSE
		    	gamma:=gamma/(1-gamma);
			END;
			*)
			in := obj( vyLongrealVec.tVector );  len := vyLongrealVec.Len( in );
			(* aM.SI("Len = ",len); *)

			obj := vyName.FindObj( outname );
			IF obj = NIL THEN out := vyLongrealVec.New( len );  vyName.RegisterNamed( out, outname );  aM.SS( "Vektor neu registriert unter: ", outname );
			ELSE out := obj( vyLongrealVec.tVector );  vyLongrealVec.SetLen( out, len );
			END;

			NEW( o );  o.Preparation( in );  outarray := o.Minimize( gamma );  vyLongrealVec.CopyToVec( outarray^, out, len, 0, 0 );
			vyBase.Update( out );
		END;
	END Test;
	*)

	PROCEDURE NewSinVector*;
	VAR name: ARRAY 256 OF CHAR;
		vec: vyLongrealVec.tVector;  len, period, i: LONGINT;  val: LONGREAL;  obj: vyBase.Object;
	BEGIN
		antsCommands.InitScan( "" );
		IF antsCommands.ExpectName( "name", name ) & antsCommands.ExpectNumber( "len", len ) &
		    antsCommands.ExpectNumber( "period", period ) THEN
			obj := vyName.FindObj( name );
			IF (obj = NIL ) OR (~(obj IS vyLongrealVec.tVector)) THEN
				vec := vyLongrealVec.New( len );  vyName.RegisterNamed( vec, name );
			ELSE vec := obj( vyLongrealVec.tVector );  vyLongrealVec.SetLen( vec( vyLongrealVec.tVector ), len );
			END;
			FOR i := 0 TO len - 1 DO val := MathL.sin( i / period * 2 * MathL.pi );  vyLongrealVec.Set( val, vec, i );  END;
			vyBase.Update( vec );
		END;
	END NewSinVector;

	PROCEDURE AddGaussNoise*;
	VAR sname, dname: ARRAY 256 OF CHAR;
		svec, dvec: vyLongrealVec.tVector;  len, period, i: LONGINT;  val, var: LONGREAL;  obj: vyBase.Object;
	BEGIN
		antsCommands.InitScan( "" );
		IF antsCommands.ExpectName( "src", sname ) & antsCommands.ExpectName( "dest", dname ) &
		    antsCommands.ExpectReal( "var", var ) THEN
			obj := vyName.FindObj( sname );
			IF (obj = NIL ) OR (~(obj IS vyLongrealVec.tVector)) THEN RETURN ELSE svec := obj( vyLongrealVec.tVector );  END;
			len := vyLongrealVec.Len( svec );

			obj := vyName.FindObj( dname );
			IF (obj = NIL ) OR (~(obj IS vyLongrealVec.tVector)) THEN
				dvec := vyLongrealVec.New( len );  vyName.RegisterNamed( dvec, dname );
			ELSE dvec := obj( vyLongrealVec.tVector );  vyLongrealVec.SetLen( dvec( vyLongrealVec.tVector ), len );
			END;

			FOR i := 0 TO len - 1 DO
				val := vyLongrealVec.Get( svec, i ) + vyRandom.Gauss( 0, var );  vyLongrealVec.Set( val, dvec, i );
			END;
			vyBase.Update( dvec );
		END;

	END AddGaussNoise;

	PROCEDURE BuildGammaList( aL, bL, aR, bR: LONGREAL;  getLine: GetLine;  VAR lst: List );
	VAR x, am, bM: LONGREAL;
	CONST epsilon = 0.00000001;
	BEGIN

		IF aL = aR THEN HALT( 100 )
		END;
		x := (bR - bL) / (aL - aR);   (* intersection point of the lines given by bL,aL and bR,aR *)


		getLine( x, am, bM );

		IF (aL = am) OR (aR = am) OR (ABS( (bM + x * am) - (bL + x * aL) ) < epsilon) THEN  (* no line beyond this line *)
			lst.Append( x, aL, bL, aR, bR );
		ELSE  (* recursion for right and left lines *)
			BuildGammaList( aL, bL, am, bM, getLine, lst );  BuildGammaList( am, bM, aR, bR, getLine, lst );
		END;
	END BuildGammaList;

	PROCEDURE GammaShooting*( left, right: LONGREAL;  getLine: GetLine ): List;   (*for explanation see "Complexity Penalised M-Estimation: Fast Computation", chapter 4 *)
	VAR lst: List;  bL, aL, bR, aR: LONGREAL;
	BEGIN
		NEW( lst );  getLine( left, aL, bL );  lst.Append( left, MIN( LONGREAL ), MIN( LONGREAL ), aL, bL );  getLine( right, aR, bR );
		IF aR # aL THEN BuildGammaList( aL, bL, aR, bR, getLine, lst );  END;
		IF lst.last.x # right THEN lst.Append( right, aR, bR, MAX( LONGREAL ), MAX( LONGREAL ) );  END;
		IF (lst.first.next # NIL ) & (lst.first.next.x = lst.first.x) THEN lst.first := lst.first.next;  END;
		RETURN lst;
	END GammaShooting;

	PROCEDURE GammaList*;
	VAR in: BaseObject;  out: vyLongrealVec.tVector;  obj: vyBase.Object;  len: LONGINT;
		outname: ARRAY 256 OF CHAR;
		gamma: LONGREAL;  outarray: ArrayR;  linefinder: LineFinder;  lst: List;  intersection: Intersection;
	BEGIN
		antsCommands.InitScan( "in=OBJECT  out=OBJECT|NAME " );
		IF antsCommands.ExpectObject( "in", obj ) & antsCommands.ExpectName( "out", outname ) THEN
			IF (gamma < 0) OR (gamma > 1) THEN aM.S( "Gamma muss im Intervall [0,1] liegen." );  RETURN END;
			IF obj IS BaseObject THEN in := obj( BaseObject );  ELSE aM.S( "Object is of incompatible type" );  RETURN;  END;
			len := in.len;
			(* aM.SI("Len = ",len); *)

			obj := vyName.FindObj( outname );
			IF obj = NIL THEN out := vyLongrealVec.New( 0 );  vyName.RegisterNamed( out, outname );  aM.SS( "Vektor neu registriert unter: ", outname );
			ELSE out := obj( vyLongrealVec.tVector );  vyLongrealVec.SetLen( out, 0 );
			END;
			NEW( linefinder, len, in.Distance );

			lst := GammaShooting( 0, 1, linefinder.GetPottsLine );  intersection := lst.first;
			WHILE (intersection # NIL ) DO vyLongrealVec.Append( intersection.x, out );  intersection := intersection.next;  END;

			vyBase.Update( out );
		END;
	END GammaList;

	PROCEDURE DoSetReal*( name: ARRAY OF CHAR;  number: LONGREAL );
	VAR obj: vyBase.Object;  numobj: vyLongrealVec.tLONGREAL;
	BEGIN
		obj := vyName.FindObj( name );
		IF (obj = NIL ) OR (~(obj IS vyLongrealVec.tLONGREAL)) THEN
			numobj := vyLongrealVec.NewLongrealObject( number );  vyName.RegisterNamed( numobj, name );
		ELSE numobj := obj( vyLongrealVec.tLONGREAL );  numobj.x := number;
		END;
	END DoSetReal;

	PROCEDURE DoSetInt*( name: ARRAY OF CHAR;  number: LONGINT );
	VAR obj: vyBase.Object;  numobj: vyLongintVec.tLONGINT;
	BEGIN
		obj := vyName.FindObj( name );
		IF (obj = NIL ) OR (~(obj IS vyLongintVec.tLONGINT)) THEN
			numobj := vyLongintVec.NewLongintObject( number );  vyName.RegisterNamed( numobj, name );
		ELSE numobj := obj( vyLongintVec.tLONGINT );  numobj.i := number;
		END;
	END DoSetInt;

	PROCEDURE VectToName( name: ARRAY OF CHAR;  len: LONGINT ): vyLongrealVec.tVector;
	VAR vec: vyLongrealVec.tVector;  obj: vyBase.Object;
	BEGIN
		obj := vyName.FindObj( name );
		IF (obj = NIL ) OR (~(obj IS vyLongrealVec.tVector)) THEN
			vec := vyLongrealVec.New( len );  vyName.RegisterNamed( vec, name );
		ELSE vec := obj( vyLongrealVec.tVector );  vyLongrealVec.SetLen( vec, len );
		END;
		RETURN vec;
	END VectToName;

	PROCEDURE Test2*;
	BEGIN
		DoSetReal( "myNumber", 0.5 );
	END Test2;

	PROCEDURE FindLongestInterval*;   (*searching for the longest gamma-interval*)
	VAR in: vyLongrealVec.tVector;  gamma: LONGREAL;  obj: vyBase.Object;
		gammaname: ARRAY 256 OF CHAR;
		len, i, longesti: LONGINT;  diff, longest: LONGREAL;
	BEGIN
		antsCommands.InitScan( "in=OBJECT gamma=OBJECT/NAME" );
		IF antsCommands.ExpectObject( "in", obj ) & antsCommands.ExpectName( "gamma", gammaname ) THEN

			IF obj IS vyLongrealVec.tVector THEN in := obj( vyLongrealVec.tVector );
			ELSE aM.S( "Object is of incompatible type" );  RETURN;
			END;
			len := vyLongrealVec.Len( in );

			longest := 0;
			FOR i := 1 TO len - 1 DO
				diff := vyLongrealVec.Get( in, i ) - vyLongrealVec.Get( in, i - 1 );
				IF diff > longest THEN longest := diff;  longesti := i END;
			END;
			gamma := (vyLongrealVec.Get( in, longesti ) + vyLongrealVec.Get( in, longesti - 1 )) / 2;
			DoSetReal( gammaname, gamma );   (* aM.SR( "Der Mittelpunkt des längsten Intervalls ist ", gamma );  *)
		END;
	END FindLongestInterval;

	PROCEDURE FindLastMonotone*;   (*searching for the last interval, which returns, by going through the intervals from right to left, a monotone approximation*)
	VAR in: vyLongrealVec.tVector;  gamma: LONGREAL;  obj, ob: vyBase.Object;  myobject: BaseObject;
		gammaname: ARRAY 256 OF CHAR;
		len, len2, r, i: LONGINT;  lastmonotone, diff: LONGREAL;  ok: BOOLEAN;  y: ArrayR;  p: ArrayI;
	BEGIN
		antsCommands.InitScan( "myobject=OBJECT in=OBJECT gamma=OBJECT/NAME" );
		IF antsCommands.ExpectObject( "myobject", ob ) & antsCommands.ExpectObject( "in", obj ) &
		    antsCommands.ExpectName( "gamma", gammaname ) THEN

			IF obj IS vyLongrealVec.tVector THEN in := obj( vyLongrealVec.tVector );
			ELSE aM.S( "Object is of incompatible type" );  RETURN;
			END;
			IF ob IS BaseObject THEN myobject := ob( BaseObject );  ELSE aM.S( "Object is of incompatible type" );  RETURN;  END;

			len := vyLongrealVec.Len( in );
			ASSERT ( len > 1 );

			lastmonotone := vyLongrealVec.Get( in, len - 1 );

			DEC( len );

			WHILE len > 0 DO gamma := (vyLongrealVec.Get( in, len ) + vyLongrealVec.Get( in, len - 1 )) / 2;

				p := FindBestPartition( myobject.len, gamma, myobject.Distance );
				y := SegmentationFromPartition( p^, myobject.Value );  len2 := LEN( y );  ok := TRUE;

				FOR r := 1 TO len2 - 1 DO
					diff := y[r] - y[r - 1];
					IF diff > 0 THEN ok := FALSE;  END;
				END;
				IF ok = TRUE THEN lastmonotone := gamma END;
				DEC( len )
			END;
			gamma := lastmonotone;  DoSetReal( gammaname, gamma );   (*aM.SR( "Der Mittelpunkt des letzten monotonen Intervalls ist ", gamma );  *)
		END;
	END FindLastMonotone;

	PROCEDURE ToInfScale*;
	VAR in, out: vyLongrealVec.tVector;  obj: vyBase.Object;  len, i: LONGINT;
		outname: ARRAY 256 OF CHAR;
		val: LONGREAL;
	BEGIN
		antsCommands.InitScan( "in=OBJECT  out=OBJECT" );
		IF antsCommands.ExpectObject( "in", obj ) & (antsCommands.ExpectName( "out", outname )) THEN
			in := obj( vyLongrealVec.tVector );  len := vyLongrealVec.Len( in );  out := VectToName( outname, len - 1 );
			FOR i := 0 TO len - 2 DO val := vyLongrealVec.Get( in, i );  val := val / (1 - val);  vyLongrealVec.Set( val, out, i );  END;
		END;

	END ToInfScale;

	PROCEDURE To01Scale*;
	VAR in: LONGREAL;
		out: ARRAY 256 OF CHAR;
	BEGIN
		antsCommands.InitScan( "in=REAL  out=NAME" );
		IF antsCommands.ExpectReal( "in", in ) & antsCommands.ExpectName( "out", out ) THEN
			DoSetReal( out, in / (1 + in) );  aM.SR( "out=", in / (1 + in) );
		END;
	END To01Scale;

	PROCEDURE MAD*( y: vyLongrealVec.tVector ): LONGREAL;
	(*
The median absolute deviation is defined as
MAD(y) = median(ABS(y[i] - median(y)))
*)
	(*! hieß in antsPotts1DSurveyVS Realmad*)
	VAR N, i: LONGINT;  val: LONGREAL;  z: vyLongrealVec.tVector;  mad: LONGREAL;  median: LONGREAL;
	BEGIN
		N := vyLongrealVec.Len( y( vyLongrealVec.tVector ) );

		median := vyLongrealVec.GetMedian( y );

		z := vyLongrealVec.New( N );

		FOR i := 0 TO N - 1 DO val := ABS( vyLongrealVec.Get( y, i ) - median );  vyLongrealVec.Set( val, z, i ) END;

		mad := vyLongrealVec.GetMedian( z );

		RETURN mad

	END MAD;

	PROCEDURE FindConstant*( y: vyLongrealVec.tVector ): LONGREAL;
	VAR constant: LONGREAL;
	BEGIN
		constant := 1 / NormSInv( 0.75 ) * MAD( y );   (*The normalised mad is a robust estimator for the variance of normal distribution. NormSInv(0.75) =~ 0.67448974*)
		(*aM.SR( "Die Konstante c ist ", constant )*) ;
		RETURN constant;   (* 1/qnorm(3/4*)
	END FindConstant;

	PROCEDURE NormSInv*( p: LONGREAL ): LONGREAL;
	VAR a, b, c, d: ARRAY 6 OF LONGREAL;
		q, r: LONGREAL;
	CONST plow = 0.02425;  phigh = 1 - plow;
	BEGIN
		a[0] := -3.969683028665376D+01;  a[1] := 2.209460984245205D+02;  a[2] := -2.759285104469687D+02;
		a[3] := 1.383577518672690D+02;  a[4] := -3.066479806614716D+01;  a[5] := 2.506628277459239D+00;

		b[0] := -5.447609879822406D+01;  b[1] := 1.615858368580409D+02;  b[2] := -1.556989798598866D+02;
		b[3] := 6.680131188771972D+01;  b[4] := -1.328068155288572D+01;

		c[0] := -7.78489400243029D-03;  c[1] := -3.223964580411365D-01;  c[2] := -2.400758277161838D+00;
		c[3] := -2.549732539343734D+00;  c[4] := 4.374664141464968D+00;  c[5] := 2.938163982698783D+00;

		d[0] := 7.784695709041462D-03;  d[1] := 3.224671290700398D-01;  d[2] := 2.445134137142996D+00;
		d[3] := 3.754408661907416D+00;

		IF (p < plow) THEN
			q := MathL.sqrt( -2 * MathL.ln( p ) );
			RETURN (((((c[0] * q + c[1]) * q + c[2]) * q + c[3]) * q + c[4]) * q + c[5]) /
					    ((((d[0] * q + d[1]) * q + d[2]) * q + d[3]) * q + 1);
		END;

		(* Rational approximation for upper region:*)
		IF (phigh < p) THEN
			q := MathL.sqrt( -2 * MathL.ln( 1 - p ) );
			RETURN -(((((c[0] * q + c[1]) * q + c[2]) * q + c[3]) * q + c[4]) * q + c[5]) /
					    ((((d[0] * q + d[1]) * q + d[2]) * q + d[3]) * q + 1);
		END;

		(* Rational approximation for central region:*)
		q := p - 0.5;  r := q * q;
		RETURN (((((a[0] * r + a[1]) * r + a[2]) * r + a[3]) * r + a[4]) * r + a[5]) * q /
				    (((((b[0] * r + b[1]) * r + b[2]) * r + b[3]) * r + b[4]) * r + 1);
	END NormSInv;

	PROCEDURE ReadRow*;
	VAR l: antsCommands.tScanList;
		str: ARRAY 64 OF CHAR;
		data: vyBase.Object;  row, col, len: LONGINT;
		dataname: ARRAY 64 OF CHAR;
		R: antsReadWrite.Rider;  msg: vyPort.AdjustCoordMsg;
	BEGIN
		antsCommands.InitScan( "filename=STR data=NAME (>row|>col) [>ignoreNL]" );
		NEW(R);
		IF antsCommands.ExpectString( "filename", str ) & antsCommands.ExpectName( "data", dataname ) THEN
			IF ~antsCommands.GetNumber( "row", row ) THEN row := -1 END;
			IF ~antsCommands.GetNumber( "col", col ) THEN col := -1 END;
			IF (row = -1) & (col = -1) THEN aM.eS( " please provide a row or col" );  RETURN END;
			data := vyName.FindObj( dataname );
			IF (data = NIL ) OR (~(data IS vyLongrealVec.tVector)) THEN
				data := vyLongrealVec.New( 0 );  vyName.RegisterNamed( data, dataname )
			END;
			WITH data: vyLongrealVec.tVector DO
				len := 0;
				IF ~R.Old( str ) THEN aM.eSS( "antsReadWrite: Can not open ", str );  RETURN END;
				IF antsCommands.FindKeyword( l, "ignoreNL" ) THEN R.ignoreNL := TRUE END;
				R.ReadType;
				IF row # -1 THEN aM.SI( "antsReadWrite:reading row", row );  R.ReadRowX( data, row )
				ELSIF col # -1 THEN R.ReadColX( data, col )
				END;
				R.Close;
				IF data # NIL THEN aM.vSI( "antsReadWrite:Read File, len of data : ", vyLongrealVec.Len( data ) ) ELSE aM.eS( "antsReadWrite:Problems reading, check filename, row/column (index: 0..len-1)" ) END;
				vyBase.Update( data );  vyBase.ForUsersHandle( data, msg );
			END
		END
	END ReadRow;

	PROCEDURE Read*;
	VAR str: ARRAY 64 OF CHAR;
		rownr, colnr, i, nr: LONGINT;  min, max, rowmin, rowmax: LONGREAL;
		dataname: ARRAY 64 OF CHAR;
		R: antsReadWrite.Rider;  msg: vyPort.AdjustCoordMsg;  data: antsArrayObjects.tLONGREALObject;  x, y: LONGINT;  val: LONGREAL;
		obj: vyBase.Object;

	BEGIN
		antsCommands.InitScan( "filename=STR data=NAME min = OBJECT/NAME max = OBJECT/NAME [>ignoreNL]" );
		IF antsCommands.ExpectString( "filename", str ) & antsCommands.ExpectName( "data", dataname ) THEN
			NEW(R);
			IF ~R.Old( str ) THEN aM.eSS( "antsReadWrite: Can not open ", str );  RETURN
			END;
			R.ReadType;   (* *)
			R.ScanMatrix( rownr, colnr );
			IF (rownr = 0) OR (colnr = 0) THEN aM.eSS( "antsReadWrite: Error in ", str );  RETURN END;

			obj := vyName.FindObj( dataname );
			IF (obj # NIL ) & (obj IS antsArrayObjects.tLONGREALObject) THEN
				data := obj( antsArrayObjects.tLONGREALObject );  antsArrayObjects.ChangeSize( data, colnr, rownr );
			ELSE
				data := antsArrayObjects.NewLONGREALObject( colnr, rownr, 1 );  vyName.RegisterNamed( data, dataname );
			END;

			R.SetPos( 0 );  R.ReadMatrixX( data.A^ );

			IF antsCommands.Find( "normalize" ) THEN
				antsArrays.MinMax2dX( data.A^, min, max );  aM.SRSR( "normalizing to min=", min, "max=", max );
				FOR y := 0 TO rownr - 1 DO
					FOR x := 0 TO colnr - 1 DO val := data.A[y, x];  data.A[y, x] := (val - min) / (max - min);  END;
				END;
				R.Close;

			END;
		END;

	END Read;

	PROCEDURE GetRow*;
	VAR str: ARRAY 64 OF CHAR;
		obj: vyBase.Object;  row: LONGINT;  data: antsArrayObjects.tLONGREALObject;
		vecname: ARRAY 256 OF CHAR;
		vec: vyLongrealVec.tVector;

	BEGIN
		antsCommands.InitScan( "data=OBJECT row=NUMBER out=OBJECT" );
		IF antsCommands.ExpectObject( "data", obj ) & antsCommands.ExpectNumber( "row", row ) &
		    antsCommands.ExpectName( "out", vecname ) THEN
			IF (obj # NIL ) & (obj IS antsArrayObjects.tLONGREALObject) THEN
				data := obj( antsArrayObjects.tLONGREALObject );
			ELSE aM.eS( "please provide data !" );
			END;

			vec := VectToName( vecname, data.w );  vyLongrealVec.CopyToVec( data.A[row], vec, data.w, 0, 0 );
			vyBase.Update( vec );

		END;

	END GetRow;


(*
PROCEDURE NormalisationMinMax*;
	VAR in, vec, out: vyLongrealVec.tVector;  rownr, colnr, i, j: LONGINT;  obj: vyBase.Object;  min, max, val: LONGREAL;  nr: LONGINT;
		outname: ARRAY 256 OF CHAR;
		msg: vyPort.AdjustCoordMsg;

	BEGIN
		antsCommands.InitScan( "in=OBJECT  out=OBJECT min=LONGREAL max=LONGREAL" );
		IF antsCommands.ExpectObject( "in", obj ) & (antsCommands.ExpectName( "out", outname ))  & antsCommands.ExpectReal("min", min) & antsCommands.ExpectReal("min", min) THEN
			in := obj( vyLongrealVec.tArray ); antsReadWrite.ScanMatrix(rownr, colnr) ;

			FOR j:= 0 TO rownr -1 DO
					vec:= antsReadWrite.ReadRowX( in, j )	;
			FOR i := 0 TO col - 1 DO
				val :=vyLongrealVec.Get ( vec, i );  val := (val - min) / (max - min);  vyLongrealVec.Set( val, out, i );
			END;
		antsReadWrite.ReadRowX( in, j ):= vec;
		END;
		  vyBase.ForUsersHandle( out, msg );
		END;

END NormalisationMinMax;
*)

	PROCEDURE Normalisation*;
	VAR in, sort, out: vyLongrealVec.tVector;  len, i: LONGINT;  obj: vyBase.Object;  min, max, val: LONGREAL;  nr: LONGINT;
		outname: ARRAY 256 OF CHAR;
		msg: vyPort.AdjustCoordMsg;
	BEGIN
		antsCommands.InitScan( "in=OBJECT  out=OBJECT" );
		IF antsCommands.ExpectObject( "in", obj ) & (antsCommands.ExpectName( "out", outname )) THEN
			in := obj( vyLongrealVec.tVector );  len := vyLongrealVec.Len( in );  out := VectToName( outname, len );

			vyLongrealVec.GetMinMax( in, min, max, nr );

			FOR i := 0 TO len - 1 DO
				val := vyLongrealVec.Get( in, i );  val := (val - min) / (max - min);  vyLongrealVec.Set( val, out, i );
			END;
			vyBase.Update( out );  vyBase.ForUsersHandle( out, msg );
		END;
	END Normalisation;

	PROCEDURE Append*;
	VAR in: vyLongrealVec.tVector;  len, i: LONGINT;  obj: vyBase.Object;  val: LONGREAL;
	BEGIN
		antsCommands.InitScan( "in=OBJECT  val=Real" );
		IF antsCommands.ExpectObject( "in", obj ) & (antsCommands.ExpectReal( "val", val )) THEN
			in := obj( vyLongrealVec.tVector );  vyLongrealVec.Append( val, in );  vyBase.Update( in );
		END;
	END Append;

	PROCEDURE AppendSprungpunkt*;
	VAR in: vyLongrealVec.tVector;  len, i: LONGINT;  obj: vyBase.Object;  val: LONGREAL;
	BEGIN
		antsCommands.InitScan( "in=OBJECT  val=Real" );
		IF antsCommands.ExpectObject( "in", obj ) & (antsCommands.ExpectReal( "val", val )) THEN
			in := obj( vyLongrealVec.tVector );
			IF val < 28 THEN vyLongrealVec.Append( val, in );  vyBase.Update( in );  END;   (*if there are no jumps, position of jumps is by default length of data vector, see GetPosJump *)
		END;
	END AppendSprungpunkt;

	PROCEDURE NewVector*;
	VAR i, k, len: LONGINT;  value: LONGREAL;  vec: vyLongrealVec.tVector;  obj: vyBase.Object;
		name: ARRAY 256 OF CHAR;
	BEGIN
		antsCommands.InitScan( "name=NAME  [>create]" );
		IF antsCommands.ExpectName( "name", name ) THEN
			obj := vyName.FindObj( name );
			IF (obj = NIL ) OR antsCommands.Find( "create" ) THEN
				vec := vyLongrealVec.New( len );  vyName.RegisterNamed( vec, name );  aM.SS( "Vektor neu registriert unter: ", name );
			ELSE vec := obj( vyLongrealVec.tVector );  vyLongrealVec.SetLen( vec, 0 );
			END;
			vyBase.Update( vec );
		END;
	END NewVector;

	PROCEDURE SetReal;
	VAR real: LONGREAL;
		name: ARRAY 256 OF CHAR;
	BEGIN
		antsCommands.InitScan( "name=NAME  real=REAL" );
		IF antsCommands.ExpectName( "name", name ) & antsCommands.ExpectReal( "real", real ) THEN DoSetReal( name, real );  END;
	END SetReal;

	PROCEDURE AddReal*;
	VAR r1, r2: LONGREAL;
		name: ARRAY 256 OF CHAR;
	BEGIN
		antsCommands.InitScan( "name=NAME  r1=REAL r2=REAL" );
		IF antsCommands.ExpectName( "name", name ) & antsCommands.ExpectReal( "r1", r1 ) & antsCommands.ExpectReal( "r2", r2 ) THEN
			DoSetReal( name, r1 + r2 );
		END;
	END AddReal;

	PROCEDURE SetInt*;
	VAR int: LONGINT;
		name: ARRAY 256 OF CHAR;
	BEGIN
		antsCommands.InitScan( "name=NAME  int=NUMBER" );
		IF antsCommands.ExpectName( "name", name ) & antsCommands.ExpectNumber( "int", int ) THEN DoSetInt( name, int );  END;
	END SetInt;

	PROCEDURE AddInt*;
	VAR i1, i2: LONGINT;
		name: ARRAY 256 OF CHAR;
	BEGIN
		antsCommands.InitScan( "name=NAME  i1=NUMBER i2=NUMBER" );
		IF antsCommands.ExpectName( "name", name ) & antsCommands.ExpectNumber( "i1", i1 ) & antsCommands.ExpectNumber( "i2", i2 ) THEN
			DoSetInt( name, i1 + i2 );
		END;
	END AddInt;

	PROCEDURE JumpFunction*;   (*creates a function with |jumps|+1 plateaus of the same length and decreasing jumps of hight 1*)
	VAR i, k, len, jumps: LONGINT;  value: LONGREAL;  vec: vyLongrealVec.tVector;  obj: vyBase.Object;  val: LONGREAL;
		name: ARRAY 256 OF CHAR;
		factor: LONGREAL;
	BEGIN
		antsCommands.InitScan( "name=NAME len=NUMBER jumps=NUMBER" );
		IF antsCommands.ExpectName( "name", name ) & antsCommands.ExpectNumber( "len", len ) &
		    antsCommands.ExpectNumber( "jumps", jumps ) THEN

			vec := VectToName( name, len );

			factor := 1;
			IF antsCommands.GetReal( "factor", factor ) THEN END;

			FOR i := 0 TO len - 1 DO
				IF jumps = 0 THEN val := 0;  ELSE val := jumps * (factor * (1 - (jumps + 1) * i DIV len / (jumps)));  END;
				vyLongrealVec.Set( val, vec, i );
			END;
			vyBase.Update( vec );

		END;

	END JumpFunction;

	PROCEDURE GetNrJumps( gamma: LONGREAL;  obj: BaseObject ): LONGINT;
	VAR p: ArrayI;  r, l: LONGINT;  a: LONGINT;
	BEGIN
		p := FindBestPartition( obj.len, gamma, obj.Distance );  r := obj.len;  l := p[r];  a := 0;
		WHILE (r > 0) DO a := a + 1;  r := l;  l := p[r];  END;
		RETURN a - 1;
	END GetNrJumps;

	PROCEDURE GetPosJump( gamma: LONGREAL;  obj: BaseObject ): LONGINT;  (*searches for the position of the first jump*)
	VAR p: ArrayI;  y: ArrayR;  len, r, position: LONGINT;  ok: BOOLEAN;  diff: LONGREAL;
	BEGIN
		p := FindBestPartition( obj.len, gamma, obj.Distance );  y := SegmentationFromPartition( p^, obj.Value );  len := LEN( y );
		ok := TRUE;  r := 1;  position := len - 1;
		WHILE (ok) & (r < len) DO
			diff := y[r] - y[r - 1];
			IF diff # 0 THEN ok := FALSE;  position := r;  END;   (* Note: In case of no jumps, position of the jump is set to len - 1*)
			INC( r );
		END;
		RETURN position;
	END GetPosJump;

	PROCEDURE GetPos1Jump( gamma: LONGREAL;  obj: BaseObject ): LONGINT;  (*searches for the position of the jump, if there is only one jump*)
	VAR p: ArrayI;  y: ArrayR;  len, r, position,number: LONGINT;  ok: BOOLEAN;  diff: LONGREAL;
	BEGIN
		p := FindBestPartition( obj.len, gamma, obj.Distance );  y := SegmentationFromPartition( p^, obj.Value );  len := LEN( y );
		ok := TRUE;  r := 1;  position := len - 1;
		 number:=GetNrJumps(gamma,obj);
		 IF number=1 THEN
		WHILE (ok) & (r < len) DO
			diff := y[r] - y[r - 1];
			IF diff # 0 THEN ok := FALSE;  position := r;  END;   (* Note: In case of no or more than one jumps, position of the jump is set to len - 1*)
			INC( r );
		END;
		END;
		RETURN position;
	END GetPos1Jump;


	PROCEDURE FindNrJumps*;
	VAR in: BaseObject;  gamma: LONGREAL;  obj: vyBase.Object;
		jname: ARRAY 256 OF CHAR;
		jumps: LONGINT;  diff, longest: LONGREAL;
	BEGIN
		antsCommands.InitScan( "in=OBJECT gamma=LONGREAL jumps=OBJECT|NAME" );
		IF antsCommands.ExpectObject( "in", obj ) & antsCommands.ExpectReal( "gamma", gamma ) &
		    antsCommands.ExpectName( "jumps", jname ) THEN
			in := obj( BaseObject );  jumps := GetNrJumps( gamma, in );    aM.SI( "Jumps=", jumps ) ;
			DoSetReal( jname, jumps );
		END;
	END FindNrJumps;

	PROCEDURE FindPosJump*;   (*Find the point where approximation has FIRST jump*)
	VAR in: BaseObject;  gamma: LONGREAL;  obj: vyBase.Object;
		pname: ARRAY 256 OF CHAR;
		position: LONGINT;

	BEGIN
		antsCommands.InitScan( "in=OBJECT gamma=LONGREAL position=OBJECT|NAME" );
		IF antsCommands.ExpectObject( "in", obj ) & antsCommands.ExpectReal( "gamma", gamma ) &
		    antsCommands.ExpectName( "position", pname ) THEN
			in := obj( BaseObject );  position := GetPosJump( gamma, in );  (*aM.SI( "Position=", position )*);  DoSetReal( pname, position );
		END;
	END FindPosJump;

	PROCEDURE FindPos1Jump*;   (*Find the point where approximation has jump, if it has exactly one jump*)
	VAR in: BaseObject;  gamma: LONGREAL;  obj: vyBase.Object;
		pname: ARRAY 256 OF CHAR;
		position: LONGINT;

	BEGIN
		antsCommands.InitScan( "in=OBJECT gamma=LONGREAL position=OBJECT|NAME" );
		IF antsCommands.ExpectObject( "in", obj ) & antsCommands.ExpectReal( "gamma", gamma ) &
		    antsCommands.ExpectName( "position", pname ) THEN
			in := obj( BaseObject );  position := GetPos1Jump( gamma, in );  aM.SI( "Position=", position );  DoSetReal( pname, position );
		END;
	END FindPos1Jump;


	PROCEDURE MultiCoefficients( y: vyLongrealVec.tVector;  approx: ArrayR ): antsArrays.X2d;   (*Computes multiresolution coefficients*)
	VAR cumsum: antsArrays.X1d;  i, j, N: LONGINT;  Coeff: antsArrays.X2d;
	BEGIN
		N := vyLongrealVec.Len( y );

		IF (cumsum = NIL ) OR (LEN( cumsum ) # N) THEN NEW( cumsum, N )
		END;
		IF (Coeff = NIL ) OR (LEN( Coeff ) # N) THEN NEW( Coeff, N, N ) END;

		(*preparation: the sums from 0 to i of (data - approximation) are stored in cumsum at postion i*)
		cumsum^[0] := vyLongrealVec.Get( y, 0 ) - approx[0];
		FOR i := 2 TO N DO cumsum^[i - 1] := cumsum^[i - 2] + vyLongrealVec.Get( y, i - 1 ) - approx[i - 1] END;

		(*matrix Coeff contains the multiresolution coefficients w(i,j) at position i-1, j-1*)
		FOR j := 1 TO N DO Coeff[0][j - 1] := cumsum^[j - 1] / MathL.sqrt( j ) END;   (* since i is 1: j-1+1=j*)
		FOR j := 1 TO N DO
			FOR i := 2 TO j DO Coeff[i - 1][j - 1] := (cumsum^[j - 1] - cumsum^[i - 2]) / MathL.sqrt( j - i + 1 ) END
		END;
		RETURN Coeff;
	END MultiCoefficients;

	PROCEDURE MultiResCheck( data: vyLongrealVec.tVector;  approx: ArrayR;  factor: LONGREAL ): BOOLEAN;
	VAR N, len: LONGINT;  i, j, k: LONGINT;  ok, toobig: BOOLEAN;  Coeff: antsArrays.X2d;  cond, val, median: LONGREAL;  z: vyLongrealVec.tVector;

	BEGIN
		N := LEN( approx );
		(*computes the required median*)
		z := vyLongrealVec.New( N );  len := vyLongrealVec.Len( data );
		FOR i := 1 TO len - 1 DO
			val := ABS( (vyLongrealVec.Get( data, i ) - vyLongrealVec.Get( data, i - 1 )) );  vyLongrealVec.Set( val, z, i - 1 )
		END;
		median := vyLongrealVec.GetMedian( z );

		(*multiresolution condition value*)
		cond := MathL.sqrt( factor * MathL.ln( N ) ) * median * (1.4826 / MathL.sqrt( 2 ));

		(*Computation of the multiresolution coefficents, i. e. w(i,j)*)
		Coeff := MultiCoefficients( data, approx );

		toobig := FALSE;

		(*checking, if the multiresolution condition is fulfilled for every w(i,j)*)
		j := 1;
		WHILE ((j <= N) & ~toobig) DO
			k := 1;
			WHILE ((k <= j) & ~toobig) DO
				IF (ABS( Coeff^[k - 1][j - 1] ) > cond) THEN toobig := TRUE;  END;
				INC( k )
			END;
			INC( j )
		END;
		RETURN ~toobig;

	END MultiResCheck;

	PROCEDURE ArrayFromObject( v: vyBase.Object ): ArrayR;
	VAR a: ArrayR;
	BEGIN
		IF v IS vyLongrealVec.tVector THEN
			WITH v: vyLongrealVec.tVector DO NEW( a, vyLongrealVec.Len( v ) );  vyLongrealVec.CopyToArray( v, a^ );
			END;
		END;
		RETURN a;
	END ArrayFromObject;

	PROCEDURE FindMultiresolution*;   (*for the used formulas see Angela Kempe's dissertation p. 83*)  (*Davies and Kovac suggest to choose parameter tau (here called factor) between 2 and 2.5.
	The default is 2.25*)
	VAR in, data: vyLongrealVec.tVector;  gamma, bestgamma, factor: LONGREAL;  obj, ob, obje: vyBase.Object;  myobject: BaseObject;
		y: ArrayR;  p: ArrayI;

		gammaname: ARRAY 256 OF CHAR;
		len, i, longesti: LONGINT;  diff, longest: LONGREAL;  ok: BOOLEAN;
	BEGIN
		antsCommands.InitScan( "data=OBJECT myobject=OBJECT in=OBJECT gamma=OBJECT/NAME [>factor])" );
		IF antsCommands.ExpectObject( "data", obje ) & antsCommands.ExpectObject( "myobject", ob ) &
		    antsCommands.ExpectObject( "in", obj ) & antsCommands.ExpectName( "gamma", gammaname ) THEN
			IF obje IS vyLongrealVec.tVector THEN data := obje( vyLongrealVec.tVector );  ELSE aM.S( "Kann Daten nicht finden" );  RETURN;  END;
			IF obj IS vyLongrealVec.tVector THEN in := obj( vyLongrealVec.tVector );  ELSE aM.S( "Object is of incompatible type" );  RETURN;  END;
			IF ob IS BaseObject THEN myobject := ob( BaseObject );  ELSE aM.S( "Object is of incompatible type" );  RETURN;  END;
			IF ~antsCommands.GetReal( "factor", factor ) THEN factor := 2.25 END;

			len := vyLongrealVec.Len( in );
			ASSERT ( len > 1 );
			bestgamma := 0;  DEC( len );  ok := FALSE;

			(*This checks starting with the rightmost interval for every center of a gamma-interval, i.e. for every number of jumps which is taken, if the multiresolutin criterion is fulfilled. It stops as soon as it is fulfilled once ang takes this gamma*)
			WHILE (~ok) & (len > 0) DO
				gamma := (vyLongrealVec.Get( in, len ) + vyLongrealVec.Get( in, len - 1 )) / 2;
				p := FindBestPartition( myobject.len, gamma, myobject.Distance );
				y := SegmentationFromPartition( p^, myobject.Value );  ok := MultiResCheck( data, y, factor );
				IF ok THEN bestgamma := gamma;  END;
				DEC( len )
			END;
			DoSetReal( gammaname, bestgamma );   (*aM.SR( "Das größte Gamma, das das Multiresolutionskriterium erfüllt, ist ", bestgamma );  *)
		END;
	END FindMultiresolution;

	PROCEDURE DiffVec*;   (*Calculates the difference of two vectors element by element. At the time it is specialised to the cDNA-Data, to use it generally delete the pink part.*)
	VAR in1, in2, out: vyLongrealVec.tVector;  len1, len2, i: LONGINT;
		outname: ARRAY 256 OF CHAR;
		obj, ob: vyBase.Object;  val: LONGREAL;
	BEGIN
		antsCommands.InitScan( "in1=OBJECT in2=OBJECT out=OBJECT" );
		IF antsCommands.ExpectObject( "in1", obj ) & antsCommands.ExpectObject( "in2", ob ) &
		    (antsCommands.ExpectName( "out", outname )) THEN
			in1 := obj( vyLongrealVec.tVector );  in2 := ob( vyLongrealVec.tVector );  len1 := vyLongrealVec.Len( in1 );
			len2 := vyLongrealVec.Len( in2 );
			IF len1 # len2 THEN aM.S( "Vektoren müssen die gleiche Länge haben!" );  RETURN;  END;
			out := VectToName( outname, len1 );
			FOR i := 0 TO len1 - 1 DO
				IF ((vyLongrealVec.Get( in1, i ) = 28) & (vyLongrealVec.Get( in2, i ) # 28)) OR
				    ((vyLongrealVec.Get( in1, i ) # 28) & (vyLongrealVec.Get( in2, i ) = 28)) THEN
					vyLongrealVec.Set( 30, out, i );   (*If there are no jumps, position of jump is set to 28, see GetPosJump. To distinguish beetween big differences, the difference is set to 30*)
				ELSE val := ABS( vyLongrealVec.Get( in1, i ) - vyLongrealVec.Get( in2, i ) );  vyLongrealVec.Set( val, out, i );
				END;
			END;
			vyBase.Update( out );
		END;

	END DiffVec;

END BellmanMinimisation.

System.Free BellmanMinimisation ~





Gadgets.Insert ScrollbarsR.New ~


BellmanMinimisation.ReadRow "antsaddons/635.txt"  gendata row=1906  >ignoreNL ~
Voyager.Show approximation2 as antsPointPlot ~

vyScale.Insert ~
(*Knöpfe beziehen sich auf gendata!*)



BellmanMinimisation.JumpFunction name=truth len=29 jumps=1 factor=100  ~ (*Funktion bestimmen*)
BellmanMinimisation.AddGaussNoise truth data2 vari=5 ~
antsExpressions.Install ~

vyScale.Insert

BellmanMinimisation.Read "antsaddons/635.txt"  genmatrix >normalize~
BellmanMinimisation.GetRow genmatrix 2 gendata ~
Voyager.Show data  as antsPointPlot ~





