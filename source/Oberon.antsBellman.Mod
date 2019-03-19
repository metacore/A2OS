MODULE antsBellman IN Oberon;   	(** fof,ak,kw   **)
(* this module provides mechanisms to solve a minimization problem of some special kind,
(see PROCEDURE Bellman), in particular used to apply a Potts model to some 1d Data *)

(* Copyright notice:

This file is part of AntsInFields
Copyright (C) 1997-2002, Felix Friedrich

This library is free software; you can redistribute it and/or
modify it under the terms of the GNU Lesser General Public
License as published by the Free Software Foundation; either
version 2.1 of the License, or (at your option) any later version.

This library is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
Lesser General Public License for more details.

You should have received a copy of the GNU Lesser General Public
License along with this library; if not, write to the Free Software
Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

Copy of the GNU Lesser General Public License can be found in the file COPYING.TXT
Report any problems as soon as possible to ants@AntsInFields.de
*)



IMPORT antsArrays, vyLongreal, aM := antsMessages;

TYPE
	Function* = PROCEDURE (k, n: LONGINT): LONGREAL;

	Statistic* = POINTER TO StatisticDesc;
	StatisticDesc* = RECORD
		type*: INTEGER;    (* median, mean *)
		m*, s*: antsArrays.X2d;    (* m= mean, s=ssq for type = cMean; m=median, s=sumabs for type = cMedian*)
		n*, N*: LONGINT;             (* N: Size of Data , n: Number of current Observation *)
		(*
		in case of 1d Data:
		mean[l][k] = mean of Data in the interval [l,l+k-1]
		ssq[l][k] = ssq of Data in interval[l,l+k-1]
		N = LEN(mean)
		...
		in case of 2d Data: (type = cMean2d)
		mean[l,k] = sum of Data in region[(0,0),..., (l-1,k-1)] (rectangle), means of arbitrary rectangles calculated by a procedure
		ssq[l,k] = ssq of Data in region ..
		caution: in 2d-case  LEN(mean) = N+1 ! .
		*)
	END;

CONST
	cInval* = -1;   cMean1d* = 0;   cMedian* = 1;   cMean2d* = 2; cHampel* = 3;  cSaegezahn* = 4;  cHuber* = 5;

PROCEDURE Max (i, j: LONGINT): LONGINT;
BEGIN
IF i > j THEN RETURN i ELSE RETURN j END
END Max;

PROCEDURE Min (i, j: LONGINT): LONGINT;
BEGIN
IF i < j THEN RETURN i ELSE RETURN j END
END Min;

	(*! für Katrin Modul: Indexverschiebung in der Statistik! *)
PROCEDURE Step (VAR argmin: ARRAY OF INTEGER;     VAR min: ARRAY OF LONGREAL;      n, minw, maxw : LONGINT;     p: Function);
VAR i, minpos: LONGINT;     minv, current: LONGREAL;         from, to: LONGINT;
BEGIN
	minv := MAX(LONGREAL);     from := Max(0, n - maxw);     to := Min(n - 1, n - minw);
	FOR i := from TO to DO  (*Bestimmen des Min fuer die jeweilige Partiton*)
		current :=  min[i] + p(i, n - 1);
		IF current < minv THEN  minv := current;     minpos := i  END
	END;
	min[n] := minv;
	argmin[n] := SHORT(minpos)
END Step;

PROCEDURE Bellman* (VAR argmin: antsArrays.I1d;      VAR min: antsArrays.X1d;     N, minw, maxw: LONGINT;     p: Function;     initvalue: LONGREAL);
VAR i: LONGINT;
	(* Bellman calculates the min and the argmin of a function
	h:  R^n -> R,
	that satisfies  min{h(a1, ... , an); a1,...,an in R } = min {min{h(a1, ... , ak); a1,...,ak in R }+ p(ak+1,...,an); k < n}
	mins are stored in ARRAY min,
	argmins k (for the outer minimization on the right side min{... , k<n} ) for each n are stored in ARRAY argmin,
	argmins of the left side min{...,a1,...,an N !} can be reconstructed from these k
	precondition: min[i] = 0 R i as initialization
	minw,maxw : restriction  minw # |{k+1,...,n}| # maxw
	*)
BEGIN
	IF (min = NIL) OR (LEN(min) # N + 1) THEN
		NEW(min, N + 1);                               NEW(argmin, N + 1)
	END;
	argmin[0] := MIN(INTEGER);    argmin[1] := 0;
	min[0] := initvalue;     min[1] := 0;
	FOR i := 2 TO (N - 1) DO (* vorsicht: Index-Verschiebung durch den Startwert der Bellman-Fkt *)
		min[i] := 0;
		Step(argmin^, min^, i, minw, maxw, p)
	END;
	Step(argmin^, min^, N, 0, maxw, p)   (* fill last points *)
END Bellman;

PROCEDURE BellmanMatrix* ( VAR argmin: antsArrays.I2d;    VAR min:  antsArrays.X2d;     N: LONGINT;    p: Function );
VAR n, k, r : LONGINT;             mini, H, ssq: LONGREAL;             rsterndl: INTEGER;
BEGIN
	IF (min = NIL ) OR (LEN( min ) # N) THEN NEW( min, N, N ) END;
	(* min[k,l] = Fehler bei k+1 Intervallen und l+1 Punkten,
	klar: wir rechnen nur für k<=l
	min[0,0] = 1 Intervall, 1 Datenpunkt
	min[N-1,N-1] = N Intervalle, N Datenpunkte
	*)

	IF (argmin = NIL ) OR (LEN( argmin ) # N) THEN NEW( argmin, N, N ) END;

	FOR n := 1 TO N DO  (* Statistic(data, 1, n, mean, ssq);     *)
		(* ssq := s.Ssq[0, n - 1];  *)ssq := p(0, n - 1);            min^[0][n - 1] := ssq
	END;              (* case k=1 *)
	min^[1][1] := 0;              (* case k=2, n=2 *)
	argmin^[1][1] := 1;
	FOR n := 3 TO N DO
		FOR k := 2 TO n DO
			(*ssq := s.Ssq[n - 1, n - 1];          mini := min^[k - 2][n - 2] + ssq;
			rsterndl := SHORT( n - 1 );
			*)
			(* mini := MAX(LONGREAL); *)
			ssq := p(n-1, n - 1);  (* ist das nicht = 0 ?  in Spezialfällen mit Sicherheit aber nicht in voller Allgemeinheit.*)
			mini := min^[k - 2][n-2] +ssq;
			rsterndl := SHORT( n - 1 );
			FOR r := n - 2 TO k - 1 BY - 1 DO
				(* ssq := s.Ssq[r, n - 1]; *)
				ssq := p(r, n - 1);           H := min^[k - 2][r - 1] + ssq;
				IF H < mini THEN mini := H;             rsterndl := SHORT( r ) END
			END;
			min^[k - 1][n - 1] := mini;             argmin^[k - 1][n - 1] := rsterndl
		END
	END
END BellmanMatrix;

PROCEDURE PartitionMatrix* (argmin: antsArrays.I2d;   VAR result: antsArrays.X2d;   p: Function);
VAR k, l, N: LONGINT;            start, stop: INTEGER;            mean: LONGREAL;
BEGIN
	N := LEN(argmin);
	IF (result = NIL) OR (LEN(result) # N) THEN NEW(result, N, N) END;

	FOR k := 1 TO N DO  (* num of intervals in the minimizing partition *)
		stop := SHORT( N );
		FOR l := 0 TO k - 2 DO
			start := (argmin^[k - l - 1][stop - 1]) + 1;
			mean := p(start - 1, stop - 1);
			vyLongreal.Fill(stop - start + 1, result[k - 1], start - 1, mean);
			(*
			FOR i := start TO stop DO result^[k - 1][i - 1] := mean END;
			*)
			stop := start - 1
		END;
		(* Statistic(data, 1, stop, mean, ssq); *)
		IF stop > 0 THEN
			mean := p(0, stop - 1);
			(*!? stop = 0 möglich ?? *)
			vyLongreal.Fill(stop, result[k - 1], 0, mean)
			(*
			FOR i := 1 TO stop DO result^[k - 1][i - 1] := mean END
			*)
		END
	END
END PartitionMatrix;

PROCEDURE IntervalLenMatrix* (argmin: antsArrays.I2d;   VAR result: antsArrays.I2d);
VAR k, l, N: LONGINT;            start, stop: INTEGER;
	(* writes the length of intervals consecutive in result, first row of result corresponds to one interval, last row to N intervals *)
BEGIN
	N := LEN(argmin);
	IF (result = NIL) OR (LEN(result) # N) THEN NEW(result, N, N) END;
	FOR k := 1 TO N DO  (* num of intervals in the minimizing partition *)
		stop := SHORT( N );
		FOR l := 0 TO k - 2 DO
			start := (argmin^[k - l - 1][stop - 1]) + 1;
			result[k -  l - 1] [k - 1] := stop - start + 1;
			stop := start - 1
		END;
		(* Statistic(data, 1, stop, mean, ssq); *)
		IF stop > 0 THEN
			(*!? stop = 0 möglich ?? *)
			result[0][k - 1] := stop
		END
	END
END IntervalLenMatrix;

PROCEDURE InterVarMatrix* ( rstern: antsArrays.I2d;               s: Statistic;               VAR intVar: antsArrays.X2d );
	(** compute the unbiased  variance estimator for every interval in the minimizing partiton*)
VAR k, l, N: LONGINT;               start, stop: INTEGER;               length: LONGINT;
BEGIN
	N := s.N;
	IF (intVar = NIL ) OR (LEN( intVar ) # N) THEN NEW( intVar, N, N ) END;
	FOR k := 1 TO N DO  (* num of intervals in the minimizing partition *)
		stop := SHORT( N );
		FOR l := 0 TO k - 2 DO
			start := (rstern^[k - l - 1][stop - 1]) + 1;               length := stop - start + 1;
			intVar[k - 1 - l][k - 1] := 1 / (length - 1) * s.s[start - 1][stop - 1];               stop := start - 1
		END;
		(* Statistic(data, 1, stop, mean, ssq); *)
		IF stop > 0 THEN
			(*!? stop = 0 möglich ?? *)
			length := stop;               intVar[0][k - 1] := 1 / (stop - 1) * s.s[0][stop - 1]
		END
	END
END InterVarMatrix;

PROCEDURE IntervalLen* (argmin: antsArrays.I1d;   VAR result: antsArrays.I1d);
VAR N, k, next, pos: LONGINT;
	(* writes the length of intervals consecutive in result, end signalized by value 0 *)
BEGIN
	N := LEN(argmin);
	IF (result = NIL) OR (LEN(result) # N) THEN NEW(result, N) END;
	k := N;    pos := 0;
	WHILE(k  >  0) DO
		next := argmin[k];
		result[pos] := SHORT(k - next);   INC(pos);
		k := next
	END;
	result[pos] := 0
END IntervalLen;

PROCEDURE Partition* (argmin: antsArrays.I1d;   VAR result: antsArrays.X1d;   p: Function);
VAR N, k, next: LONGINT;
BEGIN
	N := LEN(argmin)-1;
	IF (result = NIL) OR (LEN(result) # N) THEN NEW(result, N) END;
	k := N;
	WHILE(k  >  0) DO
		next := argmin[k];
		vyLongreal.Fill(k - next, result^, next, p(next, k - 1));
		k := next
	END
END Partition;

PROCEDURE InitStatistic1d* (VAR statistic: Statistic;   N: LONGINT);
VAR i: LONGINT;
BEGIN
	IF statistic = NIL THEN NEW(statistic) END;
	IF (statistic.m = NIL ) OR (statistic.N # N) THEN
		NEW( statistic.m, N, N );            NEW( statistic.s, N, N );            statistic.N := N
	END;
	statistic.n := 0;
	FOR i := 0 TO N - 1 DO
		vyLongreal.Fill( N - i, statistic.m[i], i, 0 );             (* Init of upper triangle only *)
		vyLongreal.Fill( N - i, statistic.s[i], i, 0 ) (* Init of upper triangle only *)
	END;
	statistic.type := cInval
END InitStatistic1d;

PROCEDURE InitStatistic2d* (VAR statistic: Statistic;   N, M: LONGINT);
VAR i: LONGINT;
BEGIN
	IF statistic = NIL THEN NEW(statistic) END;
	IF (statistic.m = NIL ) OR (statistic.N # N) OR (LEN(statistic.m[0]) # M) THEN
		NEW( statistic.m, N, M );            NEW( statistic.s, N, M );            statistic.N := N
	END;
	statistic.n := 0;
	FOR i := 0 TO N - 1 DO
		vyLongreal.Fill( M , statistic.m[i], 0, 0 );
		vyLongreal.Fill( M, statistic.s[i], 0, 0 )
	END;
	statistic.type := cInval
END InitStatistic2d;

PROCEDURE ComputeMeanStat1d* (VAR A: ARRAY OF LONGREAL;   VAR s: Statistic);
VAR i, j, n, nm1, len, N: LONGINT;            factor, provmean, provssq, diff, x: LONGREAL;            ssq, mean: antsArrays.X2d;
BEGIN
	IF s = NIL THEN InitStatistic1d( s, LEN( A ) ) END;
	IF s.type = cInval THEN s.type := cMean1d END;
	ASSERT(s.type = cMean1d, 104);

	INC( s.n );            ssq := s.s;            mean := s.m;            n := s.n;            nm1 := n - 1;            factor := nm1 / n;
	N := s.N;
	FOR j := 0 TO N - 1 DO
		i := j;            len := 1;            provssq := 0;            provmean := 0;
		WHILE (i >= 0) DO
			x := A[i];            diff := (x - provmean);            provmean := provmean + diff / len;
			provssq := provssq + diff * (x - provmean);
			(* hier haben wir also: Mittelwert und Varianz an der Stelle i *)
			mean[i, j] := mean[i, j] * factor + provmean / n;            ssq[i, j] := ssq[i, j] + provssq;            DEC( i );
			INC( len )
		END
	END
END ComputeMeanStat1d;

PROCEDURE median ( y: ARRAY OF LONGREAL;            start, ende: LONGINT ): LONGREAL;
VAR len: LONGINT;
	yneu: POINTER TO ARRAY OF LONGREAL;
BEGIN
	len := ende - start + 1;            NEW( yneu, len );            vyLongreal.Copy( len, y, start, yneu^, 0 );
	RETURN antsArrays.Median1dX(yneu^, len)
END median;

PROCEDURE ComputeMedianStat1d* (VAR A: ARRAY OF LONGREAL;   VAR s: Statistic);
VAR i, j, n, nm1, t: LONGINT;            factor, sum, m: LONGREAL;            sabs, med: antsArrays.X2d;
BEGIN
	InitStatistic1d( s, LEN( A ) );
	IF s.type = cInval THEN s.type := cMedian END;
	ASSERT(s.type = cMedian, 104);
	INC( s.n );           sabs := s.s;            med := s.m;            n := s.n;            nm1 := n - 1;            factor := nm1 / n;
	ASSERT( s.n < 2, 105 );   (* does not work as update step, updating impossible without more information *)
	FOR j := 1 TO s.N DO
		FOR i := 1 TO j DO
			m := median( A, i - 1, j - 1 );            med[i - 1, j - 1] := m;
			(*! funktioniert nur für stat.n=1 richtig, d.h. im ersten update-schritt *)
			sum := 0;
			FOR t := i TO j DO sum := sum + ABS( A[t - 1] - med[i - 1, j - 1] ) END;
			sabs[i - 1, j - 1] :=  sum;
			(*! funktioniert nur für stat.n=1 richtig, d.h. im ersten update-schritt *)
			(* wie macht  man das iterativ ??*)
		END
	END
END ComputeMedianStat1d;

PROCEDURE ComputeHampelStat1d* (VAR A: ARRAY OF LONGREAL;   VAR s: Statistic);

VAR i, j, d, m, f, n, N, len1, len2: LONGINT;
	x, y, t1, t2, fail1, fail2, tmin, failmin, prtrmean1,prtrmean2, prtrssq1, prtrssq2, diff1, diff2: LONGREAL;
	trssq, trmean: antsArrays.X2d;
	sortedArray: antsArrays.X1d;
	I: antsArrays.L1d;
	ok1, ok2, first: BOOLEAN;

BEGIN

	IF s = NIL THEN InitStatistic1d( s, LEN( A ) ) END;
	IF s.type = cInval THEN s.type := cHampel END;
	ASSERT(s.type = cHampel, 104);

	INC(s.n); 	trssq := s.s; 	trmean := s.m; 	n := s.n; 	N := s.N;
	ASSERT( s.n < 2, 105 );

	FOR j := 0 TO N - 1 DO
		i := j;

		WHILE (i >= 0) DO
			sortedArray := CreateSortedArray(A, i, j);
			first := TRUE;

			FOR d := 0 TO j-i DO
				len1 := 1; 	prtrssq1 := 0; 	prtrmean1 := 0;
				NEW(I, 4);
				m := d;
				I^[0] := m;

				WHILE (m < LEN(sortedArray)) & ((sortedArray[m] - sortedArray[d]) <= 2) DO
					x := sortedArray[m];            diff1 := (x - prtrmean1);            prtrmean1 := prtrmean1 + diff1 / len1;
					prtrssq1 := prtrssq1 + diff1 * (x - prtrmean1);
					INC(len1);
					INC(m);
				END;

				I^[1] := m - 1;
				t1 := prtrmean1;
				fail1 := prtrssq1 + (j - i + 1) - (len1 - 1);
				len2 := 1; 	prtrssq2 := 0; 	prtrmean2 := 0;
				m := d;
				I^[3] := m;

				WHILE (m >= 0) & ((sortedArray[d] - sortedArray[m]) <= 2) DO
					y := sortedArray[m];            diff2 := (y - prtrmean2);            prtrmean2 := prtrmean2 + diff2 / len2;
					prtrssq2 := prtrssq2 + diff2 * (y - prtrmean2);
					INC(len2);
					DEC(m);
				END;

				I^[2] := m + 1;
				t2 := prtrmean2;
				fail2 := prtrssq2 + (j - i + 1) - (len2 - 1);
				ok1 := TRUE;
				ok2 := TRUE;

				FOR f := 0 TO 1 DO
					IF ABS(sortedArray[ I^[f] ] - t1) > 1 THEN
						ok1 := FALSE;
					END
				END;

				FOR f := 2 TO 3 DO
					IF ABS(sortedArray[ I^[f] ] - t2) > 1 THEN
						ok2 := FALSE;
					END
				END;

				IF (I^[0] > 0) & (ABS(sortedArray[ I^[0] - 1 ] - t1) <= 1) THEN
					ok1 := FALSE;
				END;

				IF (I^[2] > 0) & (ABS(sortedArray[ I^[2] - 1 ] - t2) <= 1) THEN
					ok2 := FALSE;
				END;

				IF ((I^[1] + 1) < LEN(sortedArray)) & (ABS(sortedArray[ I^[1] + 1 ] - t1) <= 1) THEN
					ok1 := FALSE;
				END;

				IF ((I^[3] + 1) < LEN(sortedArray)) & (ABS(sortedArray[ I^[3] + 1 ] - t2) <= 1) THEN
					ok2 := FALSE;
				END;

				IF ok1 = TRUE THEN

					IF first = TRUE THEN
						first := FALSE;
						tmin := t1;
						failmin := fail1;
					END;

					IF fail1 < failmin THEN
						tmin := t1;
						failmin := fail1;
					END;
				END;

				IF ok2 = TRUE THEN

					IF first = TRUE THEN
						first := FALSE;
						tmin := t2;
						failmin := fail2;
					END;

					IF fail2 < failmin THEN
						tmin := t2;
						failmin := fail2;
					END;
				END;

			END;

			trmean[i, j] := tmin;
			trssq[i, j] := failmin;
			DEC(i)

		END
	END

END ComputeHampelStat1d;

PROCEDURE ComputeSaegezahnStat1d* (VAR A: ARRAY OF LONGREAL;   VAR s: Statistic);

VAR i, j, d, m, f, k, n, N: LONGINT;
	t1, t2, fail, tmin, failmin: LONGREAL;
	trsum, trmed: antsArrays.X2d;
	sortedArray: antsArrays.X1d;
	I: antsArrays.L1d;
	ok1, ok2, first: BOOLEAN;

BEGIN

	IF s = NIL THEN InitStatistic1d( s, LEN( A ) ) END;
	IF s.type = cInval THEN s.type := cSaegezahn END;
	ASSERT(s.type = cSaegezahn, 104);

	INC(s.n); 	trsum := s.s; 	trmed := s.m; 	n := s.n; 	N := s.N;
	ASSERT( s.n < 2, 105 );

	FOR j := 0 TO N - 1 DO
		i := j;

		WHILE (i >= 0) DO
			sortedArray := CreateSortedArray(A, i, j);
			first := TRUE;

			FOR d := 0 TO j-i DO
				NEW(I, 4);
				m := d;
				I^[0] := m;

				WHILE (m < LEN(sortedArray)) & ((sortedArray[m] - sortedArray[d]) <= 2) DO
					INC(m);
				END;

				I^[1] := m - 1;
				m := d;
				I^[3] := m;

				WHILE (m >= 0) & ((sortedArray[d] - sortedArray[m]) <= 2) DO
					DEC(m);
				END;

				I^[2] := m + 1;

				t1 := median(sortedArray^, I^[0], I^[1]);
				t2 := median(sortedArray^, I^[2], I^[3]);
				ok1 := TRUE;
				ok2 := TRUE;

				FOR f := 0 TO 1 DO
					IF ABS(sortedArray[ I^[f] ] - t1) > 1 THEN
						ok1 := FALSE;
					END
				END;

				FOR f := 2 TO 3 DO
					IF ABS(sortedArray[ I^[f] ] - t2) > 1 THEN
						ok2 := FALSE;
					END
				END;

				IF (I^[0] > 0) & (ABS(sortedArray[ I^[0] - 1 ] - t1) <= 1) THEN
					ok1 := FALSE;
				END;

				IF (I^[2] > 0) & (ABS(sortedArray[ I^[2] - 1 ] - t2) <= 1) THEN
					ok2 := FALSE;
				END;

				IF ((I^[1] + 1) < LEN(sortedArray)) & (ABS(sortedArray[ I^[1] + 1 ] - t1) <= 1) THEN
					ok1 := FALSE;
				END;

				IF ((I^[3] + 1) < LEN(sortedArray)) & (ABS(sortedArray[ I^[3] + 1 ] - t2) <= 1) THEN
					ok2 := FALSE;
				END;

				IF ok1 = TRUE THEN
					fail := 0;

					FOR k := I^[0] TO I^[1] DO
						fail := fail + ABS(sortedArray[k] - t1);
					END;

					fail := fail + (j - i) - (I^[1] - I^[0]);

					IF first = TRUE THEN
						first := FALSE;
						tmin := t1;
						failmin := fail;
					END;

					IF fail < failmin THEN
						tmin := t1;
						failmin := fail;
					END;
				END;

				IF ok2 = TRUE THEN
					fail := 0;

					FOR k := I^[2] TO I^[3] DO
						fail := fail + ABS(sortedArray[k] - t2);
					END;

					fail := fail + (j - i) - (I^[3] - I^[2]);

					IF first = TRUE THEN
						first := FALSE;
						tmin := t2;
						failmin := fail;
					END;

					IF fail < failmin THEN
						tmin := t2;
						failmin := fail;
					END;
				END;

			END;

			trmed[i, j] := tmin;
			trsum[i, j] := failmin;
			DEC(i)

		END
	END

END ComputeSaegezahnStat1d;

PROCEDURE ComputeHuberStat1d* (VAR A: ARRAY OF LONGREAL;   VAR s: Statistic);

VAR i, j, d, m, f, h, k, n, N, len1, len2: LONGINT;
	x, y, t1, t2, fail, tmin, failmin, prtrmeanmed1, prtrmeanmed2, prtrssqsum1, prtrssqsum2: LONGREAL;
	trssqsum, trmeanmed: antsArrays.X2d;
	sortedArray: antsArrays.X1d;
	I: antsArrays.L1d;
	ok1, ok2, first: BOOLEAN;

BEGIN

	IF s = NIL THEN InitStatistic1d( s, LEN( A ) ) END;
	IF s.type = cInval THEN s.type := cHuber END;
	ASSERT(s.type = cHuber, 104);

	INC(s.n); 	trssqsum := s.s; 	trmeanmed := s.m; 	n := s.n; 	N := s.N;
	ASSERT( s.n < 2, 105 );

	FOR j := 0 TO N - 1 DO
		i := j;

		WHILE (i >= 0) DO
			sortedArray := CreateSortedArray(A, i, j);
			first := TRUE;

			FOR d := 0 TO j-i DO
				len1 := 1; 	prtrssqsum1 := 0; 	prtrmeanmed1 := 0;
				NEW(I, 4);
				m := d;
				I^[0] := m;

				WHILE (m < LEN(sortedArray)) & ((sortedArray[m] - sortedArray[d]) <= 2) DO
					x := sortedArray[m]; 	prtrmeanmed1 := prtrmeanmed1 + x;
					prtrssqsum1 := prtrssqsum1 + (x * x);
					INC(len1);
					INC(m);
				END;

				I^[1] := m - 1;
				t1 := (prtrmeanmed1 - (I^[0]) + (j - i - I^[1])) / (len1 - 1);
				len2 := 1; 	prtrssqsum2 := 0; 	prtrmeanmed2 := 0;
				m := d;
				I^[3] := m;

				WHILE (m >= 0) & ((sortedArray[d] - sortedArray[m]) <= 2) DO
					y := sortedArray[m]; 	prtrmeanmed2 := prtrmeanmed2 + y;
					prtrssqsum2 := prtrssqsum2 + (y * y);
					INC(len2);
					DEC(m);
				END;

				I^[2] := m + 1;
				ok1 := TRUE;
				ok2 := TRUE;

				FOR f := 0 TO 1 DO
					IF ABS(sortedArray[ I^[f] ] - t1) > 1 THEN
						ok1 := FALSE;
					END
				END;

				FOR f := 2 TO 3 DO
					IF ABS(sortedArray[ I^[f] ] - t2) > 1 THEN
						ok2 := FALSE;
					END
				END;

				IF ((I^[0] - 1) > -1) & (ABS(sortedArray[ I^[0] - 1 ] - t1) <= 1) THEN
					ok1 := FALSE;
				END;

				IF ((I^[2] - 1) > -1) & (ABS(sortedArray[ I^[2] - 1 ] - t2) <= 1) THEN
					ok2 := FALSE;
				END;

				IF ((I^[1] + 1) < LEN(sortedArray)) & (ABS(sortedArray[ I^[1] + 1 ] - t1) <= 1) THEN
					ok1 := FALSE;
				END;

				IF ((I^[3] + 1) < LEN(sortedArray)) & (ABS(sortedArray[ I^[3] + 1 ] - t2) <= 1) THEN
					ok2 := FALSE;
				END;

				IF ok1 = TRUE THEN

					IF I^[0] > 1 THEN
						FOR h := 0 TO I^[0] - 1 DO
							prtrssqsum1 := prtrssqsum1 - (2*sortedArray[h]);
						END;
					END;

					IF (I^[1] + 2) < LEN(sortedArray) THEN
						FOR k := I^[1] + 1 TO j - i DO
							prtrssqsum1 := prtrssqsum1 + (2*sortedArray[k]);
						END;
					END;

					fail := prtrssqsum1 - (I^[0] + j - i - I^[1]) - ((len1 - 1) * (t1 * t1)) + (2*((I^[0] + I^[1] + i - j) * t1));

					IF first = TRUE THEN
						first := FALSE;
						tmin := t1;
						failmin := fail;
					END;

					IF fail < failmin THEN
						tmin := t1;
						failmin := fail;
					END;
				END;

				IF ok2 = TRUE THEN

					IF I^[2] > 1 THEN
						FOR h := 0 TO I^[2] - 1 DO
							prtrssqsum2 := prtrssqsum2 - (2*sortedArray[h]);
						END;
					END;

					IF (I^[3] + 2) < LEN(sortedArray) THEN
						FOR k := I^[3] + 1 TO j - i DO
							prtrssqsum2 := prtrssqsum2 + (2*sortedArray[k]);
						END;
					END;

					fail := prtrssqsum2 - (I^[2] + j - i - I^[3]) - ((len2 - 1) * (t2 * t2)) + (2*((I^[2] + I^[3] + i - j) * t2));

					IF first = TRUE THEN
						first := FALSE;
						tmin := t2;
						failmin := fail;
					END;

					IF fail < failmin THEN
						tmin := t2;
						failmin := fail;
					END;
				END;

			END;

			trmeanmed[i, j] := tmin;
			trssqsum[i, j] := failmin;
			DEC(i);
		END
	END

END ComputeHuberStat1d;

(*
PROCEDURE ComputeHampelStat1d* (VAR A: ARRAY OF LONGREAL;  VAR s: Statistic);

	VAR i, j, d, m, f, n, N, ok, len, first: LONGINT;
			x, t, fail, tmin, failmin, prtrmean, prtrssq, diff: LONGREAL;
			trssq, trmean: antsArrays.X2d;
			sortedArray: antsArrays.X1d;
			I: antsArrays.L1d;

BEGIN

	IF s = NIL THEN InitStatistic1d( s, LEN( A ) ) END;
	IF s.type = cInval THEN s.type := cHampel END;
	ASSERT(s.type = cHampel, 104);

	INC(s.n);	trssq := s.s;	trmean := s.m;	n := s.n;	N := s.N;
	ASSERT( s.n < 2, 105 );

	FOR j := 0 TO N - 1 DO
		i := j;

		WHILE (i >= 0) DO
			sortedArray := CreateSortedArray(A, i, j);
			first := 0;

			FOR d := 0 TO j-i DO
				len := 1;	prtrssq := 0;	prtrmean := 0;
				NEW(I, 2);
				m := d;
				I^[0] := m;

				WHILE (m < LEN(sortedArray)) & ((sortedArray[m] - sortedArray[d]) <= 1.4142) DO
					x := sortedArray[m];           diff := (x - prtrmean);           prtrmean := prtrmean + diff / len;
					prtrssq := prtrssq + diff * (x - prtrmean);
					INC(len);
					INC(m);
				END;

				I^[1] := m - 1;
				t := prtrmean;
				fail := prtrssq + (j - i + 1) - (len - 1);
				ok := 1;

				FOR f := 0 TO 1 DO
					IF ABS(sortedArray[ I^[f] ] - t) > 1 THEN
						ok := 0;
					END
				END;

				IF (I^[0] > 0) & (ABS(sortedArray[ I^[0] - 1 ] - t) <= 1) THEN
					ok := 0;
				END;

				IF ((I^[1] + 1) < LEN(sortedArray)) & (ABS(sortedArray[ I^[1] + 1 ] - t) <= 1) THEN
					ok := 0;
				END;

				IF ok = 1 THEN

					IF first = 0 THEN
						first := 1;
						tmin := t;
						failmin := fail;
					END;

					IF fail < failmin THEN
						tmin := t;
						failmin := fail;
					END;
				END
			END;

			trmean[i, j] := tmin;
			trssq[i, j] := failmin;
			DEC(i)

		END
	END

END ComputeHampelStat1d;

PROCEDURE ComputeSaegezahnStat1d* (VAR A: ARRAY OF LONGREAL;  VAR s: Statistic);

	VAR i, j, d, m, f, k, n, N, ok, first: LONGINT;
			t, fail, tmin, failmin: LONGREAL;
			trsum, trmed: antsArrays.X2d;
			sortedArray: antsArrays.X1d;
			I: antsArrays.L1d;

BEGIN

	IF s = NIL THEN InitStatistic1d( s, LEN( A ) ) END;
	IF s.type = cInval THEN s.type := cSaegezahn END;
	ASSERT(s.type = cSaegezahn, 104);

	INC(s.n);	trsum := s.s;	trmed := s.m;	n := s.n;	N := s.N;
	ASSERT( s.n < 2, 105 );

	FOR j := 0 TO N - 1 DO
		i := j;

		WHILE (i >= 0) DO
			sortedArray := CreateSortedArray(A, i, j);
			first := 0;

			FOR d := 0 TO j-i DO
				NEW(I, 2);
				m := d;
				I^[0] := m;

				WHILE (m < LEN(sortedArray)) & ((sortedArray[m] - sortedArray[d]) <= 1) DO
					INC(m);
				END;

				I^[1] := m - 1;
				t := median(sortedArray^, I^[0], I^[1]);
				ok := 1;

				FOR f := 0 TO 1 DO
					IF ABS(sortedArray[ I^[f] ] - t) > 1 THEN
						ok := 0;
					END
				END;

				IF (I^[0] > 0) & (ABS(sortedArray[ I^[0] - 1 ] - t) <= 1) THEN
					ok := 0;
				END;

				IF ((I^[1] + 1) < LEN(sortedArray)) & (ABS(sortedArray[ I^[1] + 1 ] - t) <= 1) THEN
					ok := 0;
				END;

				IF ok = 1 THEN
					fail := 0;

					FOR k := I^[0] TO I^[1] DO
						fail := fail + ABS(sortedArray[k] - t);
					END;

					fail := fail + (j - i) - (I^[1] - I^[0]);

					IF first = 0 THEN
						first := 1;
						tmin := t;
						failmin := fail;
					END;

					IF fail < failmin THEN
						tmin := t;
						failmin := fail;
					END;
				END
			END;

			trmed[i, j] := tmin;
			trsum[i, j] := failmin;
			DEC(i)

		END
	END

END ComputeSaegezahnStat1d;

PROCEDURE ComputeHuberStat1d* (VAR A: ARRAY OF LONGREAL;  VAR s: Statistic);

	VAR i, j, d, m, f, h, k, n, N, ok, len, first: LONGINT;
			x, t, fail, tmin, failmin, prtrmeanmed, prtrssqsum, diff: LONGREAL;
			trssqsum, trmeanmed: antsArrays.X2d;
			sortedArray: antsArrays.X1d;
			I: antsArrays.L1d;

BEGIN

	IF s = NIL THEN InitStatistic1d( s, LEN( A ) ) END;
	IF s.type = cInval THEN s.type := cHuber END;
	ASSERT(s.type = cHuber, 104);

	INC(s.n);	trssqsum := s.s;	trmeanmed := s.m;	n := s.n;	N := s.N;
	ASSERT( s.n < 2, 105 );

	FOR j := 0 TO N - 1 DO
		i := j;

		WHILE (i >= 0) DO
			sortedArray := CreateSortedArray(A, i, j);
			first := 0;

			FOR d := 0 TO j-i DO
				len := 1;	prtrssqsum := 0;	prtrmeanmed := 0;
				NEW(I, 2);
				m := d;
				I^[0] := m;

				WHILE (m < LEN(sortedArray)) & ((sortedArray[m] - sortedArray[d]) <= 2) DO
					x := sortedArray[m];	prtrmeanmed := prtrmeanmed + x;
					prtrssqsum := prtrssqsum + (x * x);
					INC(len);
					INC(m);
				END;

				I^[1] := m - 1;
				t := (prtrmeanmed - (I^[0]) + (j - i - I^[1])) / (len - 1);
				ok := 1;

				FOR f := 0 TO 1 DO
					IF ABS(sortedArray[ I^[f] ] - t) > 1 THEN
						ok := 0;
					END
				END;

				IF ((I^[0] - 1) > -1) & (ABS(sortedArray[ I^[0] - 1 ] - t) <= 1) THEN
					ok := 0;
				END;

				IF ((I^[1] + 1) < LEN(sortedArray)) & (ABS(sortedArray[ I^[1] + 1 ] - t) <= 1) THEN
					ok := 0;
				END;

				IF ok = 1 THEN

					IF I^[0] > 1 THEN
						FOR h := 0 TO I^[0] - 1 DO
							prtrssqsum := prtrssqsum - sortedArray[h];
						END;
					END;

					IF (I^[1] + 2) < LEN(sortedArray) THEN
						FOR k := I^[1] + 1 TO j - i DO
							prtrssqsum := prtrssqsum + sortedArray[k];
						END;
					END;

					fail := prtrssqsum - ((len - 1) * (t * t)) + ((I^[0] + I^[1] + i - j) * t);

					IF first = 0 THEN
						first := 1;
						tmin := t;
						failmin := fail;
					END;

					IF fail < failmin THEN
						tmin := t;
						failmin := fail;
					END;
				END
			END;

			trmeanmed[i, j] := tmin;
			trssqsum[i, j] := failmin;
			DEC(i);
		END
	END

END ComputeHuberStat1d;
*)

PROCEDURE CreateSortedArray(y: ARRAY OF LONGREAL;  start, ende: LONGINT): antsArrays.X1d;
VAR len: LONGINT;  yneu: antsArrays.X1d;

BEGIN
	len := ende - start + 1;
	NEW(yneu, len);

	vyLongreal.Copy(len, y, start, yneu^, 0);
	vyLongreal.Sort(len, yneu^, 0);

	RETURN yneu;

END CreateSortedArray;

PROCEDURE ComputeMeanStat2d* (VAR A: ARRAY OF ARRAY OF LONGREAL;   VAR s: Statistic);
VAR i, j, h, w: LONGINT;
BEGIN
	h := LEN(A);   w := LEN(A[0]);
	InitStatistic2d(s, h + 1, w + 1);
	IF s.type = cInval THEN s.type := cMean2d END;
	ASSERT(s.type = cMean2d, 104);

	(* Quadrieren jedes Elementes von Aorig in AkumSq *)
	FOR i := 1 TO h DO
		FOR j := 1 TO w DO
			s.s[i, j] := A[i - 1, j - 1] * A[i - 1, j - 1]
		END
	END;
	vyLongreal.Copy(w, A[0], 0, s.m[1], 1);                 (* kopieren der 1.Zeile (=0) von Aorig in die erste Zeile (=1) von Akum*)
	(* Aufaddieren von Zeile i-1 auf Zeile i von Zeile 2 bis h = Anzahl der Zeilen*)
	FOR i := 2 TO h DO
		vyLongreal.Copy(w, A[i - 1], 0, s.m[i], 1 );
		vyLongreal.Add(s.m[i - 1], s.m[i], s.m[i], w + 1);
		vyLongreal.Add(s.s[i - 1], s.s[i], s.s[i], w + 1)
	END;
	(*Aufaddieren der Spalten*)
	FOR i := 2 TO w DO
		FOR j :=  0 TO h DO
			s.m[j, i] := s.m[j, i - 1] + s.m[j, i];
			s.s[j, i] := s.s[j, i - 1] + s.s[j, i]
		END
	END
END ComputeMeanStat2d;

PROCEDURE GetMean1d* (s: Statistic;   from, to: LONGINT): LONGREAL;
BEGIN
	ASSERT(s.type = cMean1d);
	RETURN s.m[from, to]
END GetMean1d;

PROCEDURE GetMedian1d* (s: Statistic;   from, to: LONGINT): LONGREAL;
BEGIN
	ASSERT(s.type = cMedian);
	RETURN s.m[from, to]
END GetMedian1d;

PROCEDURE GetSsq1d* (s: Statistic;   from, to: LONGINT): LONGREAL;
BEGIN
	ASSERT(s.type = cMean1d);
	RETURN s.s[from, to]
END GetSsq1d;

PROCEDURE GetSAbs1d* (s: Statistic;   from, to: LONGINT): LONGREAL;
BEGIN
	ASSERT(s.type = cMedian);
	RETURN s.s[from, to]
END GetSAbs1d;

PROCEDURE GetMean2d* (s: Statistic;   	fromx, fromy, tox, toy: LONGINT): LONGREAL;
VAR factor, mean: LONGREAL;    Akum: antsArrays.X2d;
BEGIN
	Akum := s.m;
	ASSERT(s.type = cMean2d);
	INC(tox);      		INC(toy);
	factor := (tox - fromx) * (toy - fromy);
	mean := (Akum[toy, tox] -  Akum[fromy, tox] -  Akum[toy, fromx] + Akum[fromy, fromx]) / factor;
	RETURN mean
END GetMean2d;

PROCEDURE GetSsq2d* (s: Statistic;   	fromx, fromy, tox, toy: LONGINT): LONGREAL;
VAR Sum, SumSq, L, factor: LONGREAL;    Akum, AkumSq: antsArrays.X2d;
BEGIN
	Akum := s.m;   AkumSq := s.s;
	INC(tox);      		INC(toy);      		factor := ( tox - fromx) * (toy - fromy);
	SumSq := AkumSq[toy, tox] -  AkumSq[fromy, tox] -  AkumSq[toy, fromx] + AkumSq[fromy, fromx];
	Sum :=  Akum[toy, tox] -  Akum[fromy, tox] -  Akum[toy, fromx] + Akum[fromy, fromx];
	L := Sum * Sum;
	RETURN SumSq - L / factor
END GetSsq2d;


PROCEDURE gammaScanning* ( min: antsArrays.X2d;             VAR jumps: antsArrays.I1d;             VAR gamma: antsArrays.X1d );
VAR N: LONGINT;             n, nn, m: LONGINT;             h, s: LONGREAL;
BEGIN
	N := LEN( min );
	IF (jumps = NIL ) OR (LEN( jumps ) # N) THEN NEW( jumps, N ) END;
	IF (gamma = NIL ) OR (LEN( gamma ) # N) THEN NEW( gamma, N ) END;
	FOR n := 0 TO N - 1 DO jumps[n] := 0;             gamma[n] := 0          END;
	m := 0;
	FOR n := 1 TO N - 1 DO
		h := min[n, N - 1];
		IF h < min[jumps[m], N - 1] THEN
			nn := m;             s := (min[jumps[nn], N - 1] - h) / (n - jumps[nn]);
			WHILE (nn >= 0) & (s > gamma[nn]) DO
				DEC( nn );             DEC( m );
				IF nn >= 0 THEN s := (min[jumps[nn], N - 1] - h) / (n - jumps[nn])          END
			END;
			INC( m );             INC( nn );             gamma[m] := (min[jumps[nn], N - 1] - h) / (n - jumps[nn]);
			INC( m );             gamma[m] := 0;
			jumps[m] := SHORT( n )
		END
	END
	(*	aM.SR("largest gamma: ",gamma[0]); *)
END gammaScanning;

BEGIN aM.launch;
END antsBellman.

System.Free katrin angieAIC antsBellman ~


fofAutomatic.Do
antsFctVector.NewVec data2 100~
antsFctVector.NewVec noise data2~
antsFctVector.NewVec integrated 100~
antsFctVector.NewVec VarianceCurve data2~
antsFctVector.NewVec LeastSquaresError data2~
antsFctVector.NewVec LeastSquaresSum data2~
Voyager.OpenLog neuer ~
antsFunctions.Define NewFunction2 ~
antsFunctions.Set NewFunction2 "IF x>0.5 THEN y := 2 ELSE y := 2*sin(2*x*pi) END"~
antsFctEdit.Show NewFunction2 from = 0 to = 1 by = 0.01 ~
antsMessages.LineFeed
antsObjects.WriteAttributes NewFunction2~
antsFctVector.New connect NewFunction2 data2 ~
Voyager.Show data2 as LinePlot~
Voyager.Show data2 as antsPointPlot~
antsMessages.LineFeed
~
fofAutomatic.Do
antsVecOpt.AddGaussNoise  data2   noise  var = 0.2~
Voyager.Show noise as antsPointPlot ~
angieAIC.Test degraded = noise var = 0.1~
Voyager.Show maxintOld as LinePlot ~
~

