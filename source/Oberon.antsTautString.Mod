MODULE antsTautString IN Oberon;
(* Implementierung der TautString-Methode. *)
(* Copyright notice:

This file is part of AntsInFields
Copyright (C) 1997-2002, Felix Friedrich

This library is free software; you can redistribute it and/or
modify it under the terms of the GNU Lesser General Public
License as published by the Free Software Foundation; either
version 2.1 of the License, or (at your option) any later version.

This library is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
Lesser General Public License for more details.

You should have received a copy of the GNU Lesser General Public
License along with this library; if not, write to the Free Software
Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA

Copy of the GNU Lesser General Public License can be found in the file COPYING.TXT
Report any problems as soon as possible to ants@AntsInFields.de
*)


(**
Stefan Brandt, 2003
Alexandra Hutzenthaler, 2003
*)

IMPORT aC := antsCommands, aA := antsArrays, antsSecurity, vyBase, vyLongreal, vyLongrealVec, vyName, math := MathL IN A2, antsTautStringTree;

TYPE
	Statistic* = POINTER TO StatisticDesc;
	StatisticDesc* = RECORD (vyBase.ObjDesc)
		data*, reko*: aA.X1d;
		n*: SIGNED32;
	END;

	PROCEDURE tautstring( VAR fdist: ARRAY OF FLOAT64;  VAR t: ARRAY OF FLOAT64;  VAR lower: ARRAY OF FLOAT64;  VAR upper: ARRAY OF FLOAT64;
									   VAR y1: FLOAT64;  VAR yn: FLOAT64;  n: SIGNED32;  VAR string: ARRAY OF FLOAT64;  VAR knotsind: ARRAY OF SIGNED32;
									   VAR knotst: ARRAY OF FLOAT64;  VAR knotsy: ARRAY OF FLOAT64;  VAR nknots: SIGNED32 );

	VAR newmaxderiv, newminderiv, maxderiv, minderiv, usualvalue: FLOAT64;  actind, minind, maxind, i, j, lastbound, lastsign, nmax: SIGNED32;  knotssign: aA.L1d;

	BEGIN
		NEW( knotssign, n );  nmax := 0;  lastbound := 0;  knotssign[0] := lastbound;  knotsind[0] := 1;  knotsy[0] := y1;  knotst[0] := t[0];  nknots := 1;  actind := 2;
		maxind := 1;  minind := 1;  maxderiv := MAX( FLOAT64 );  minderiv := MIN( FLOAT64 );

		WHILE (actind <= n) DO
			IF (actind < n) THEN
				newmaxderiv := (upper[actind - 1] - knotsy[nknots - 1]) / (t[actind - 1] - knotst[nknots - 1]);
				newminderiv := (lower[actind - 1] - knotsy[nknots - 1]) / (t[actind - 1] - knotst[nknots - 1]);
			ELSE
				IF (lastbound = 1) THEN yn := upper[n - 1];
				ELSIF (lastbound = -1) THEN yn := lower[n - 1];
				END;

				newmaxderiv := (yn - knotsy[nknots - 1]) / (t[actind - 1] - knotst[nknots - 1]);
				newminderiv := (yn - knotsy[nknots - 1]) / (t[actind - 1] - knotst[nknots - 1]);
			END;

			IF (newminderiv > maxderiv) THEN
				IF (lastbound = 0) THEN knotsind[0] := 1;  knotst[0] := t[0];  knotssign[0] := 1;  knotsy[0] := upper[0];  minind := 1;  maxind := 1;  ELSE
					IF (lastbound = -1) THEN INC( nmax );  END;

					knotssign[nknots] := 1;  knotsind[nknots] := maxind;  knotsy[nknots] := upper[maxind - 1];  knotst[nknots] := t[maxind - 1];  INC( nknots );
				END;

				actind := maxind;  lastbound := 1;  maxderiv := MAX( FLOAT64 );  minderiv := MIN( FLOAT64 );
			ELSE
				IF (newmaxderiv < minderiv) THEN
					IF (lastbound = 0) THEN knotsind[0] := 1;  knotssign[0] := -1;  knotsy[0] := lower[0];  knotst[0] := t[0];  minind := 1;  maxind := 1;  ELSE
						IF (lastbound = -1) THEN INC( nmax );  END;

						knotsind[nknots] := minind;  knotssign[nknots] := -1;  knotsy[nknots] := lower[minind - 1];  knotst[nknots] := t[minind - 1];  INC( nknots )
					END;

					actind := minind;  lastbound := -1;  maxderiv := MAX( FLOAT64 );  minderiv := MIN( FLOAT64 );
				ELSE
					IF (newmaxderiv < maxderiv) THEN maxderiv := newmaxderiv;  maxind := actind;  END;

					IF (newminderiv > minderiv) THEN minderiv := newminderiv;  minind := actind;
					END;

					IF (actind = n) THEN
						IF (lastbound # 0) THEN knotsind[nknots] := actind;  knotsy[nknots] := yn;  knotst[nknots] := t[actind - 1];  knotssign[nknots] := lastsign;  INC( nknots );
						ELSE lastbound := -1;  knotsind[0] := 1;  knotssign[0] := -1;  knotsy[0] := lower[0];  knotst[0] := t[0];  actind := 1;  minind := 1;  maxind := 1;
						END;
					END;
				END;
			END;

			INC( actind )
		END;

		FOR i := 0 TO nknots - 2 DO
			IF (knotssign[i] = knotssign[i + 1]) THEN
				FOR j := knotsind[i] TO knotsind[i + 1] - 1 DO string[j - 1] := (knotsy[i + 1] - knotsy[i]) / (knotst[i + 1] - knotst[i]);  END
			ELSE
				usualvalue := (fdist[knotsind[i + 1] - 1] - fdist[knotsind[i] - 1]) / (knotst[i + 1] - knotst[i]);

				FOR j := knotsind[i] TO knotsind[i + 1] - 1 DO string[j - 1] := usualvalue;  END;
			END;
		END;

	END tautstring;

	PROCEDURE multiwdwr( y: ARRAY OF FLOAT64;  n: SIGNED32;  thresh: FLOAT64;  squeezing: ARRAY OF CHAR ): aA.L1d;

	VAR z: aA.L1d;

	BEGIN
		IF (squeezing # "local") & (squeezing # "global") THEN antsSecurity.Halt( "Squeezing must be local or global !!!" );  END;

		NEW( z, n );  antsTautStringTree.Init( z^, n, y, thresh, squeezing );

		RETURN z;
	END multiwdwr;

	PROCEDURE MakeStatistic*;
	(* Zum direkten Aufrufen der Methode. Mit CreateTautString wird der TautString berechnet.
	Gespeichert wird er in statistic.reko und dann auf den Vector vec kopiert. *)

	VAR statistic: Statistic;  degraded, vec: vyBase.Object;
		statisticName, name, squeezing: ARRAY 64 OF CHAR;
		thr, squfac: FLOAT64;

	BEGIN
		aC.InitScan( "data=OBJ statisticName=STRING vec=STRING thr=FLOAT64 squeezingfactor=FLOAT64 squeezing=STRING" );

		IF aC.ExpectObject( "data", degraded ) & aC.ExpectName( "statisticName", statisticName ) & aC.GetName( "vec", name ) & aC.ExpectReal( "thr", thr ) &
		    aC.ExpectReal( "squeezingfactor", squfac ) & aC.ExpectString( "squeezing", squeezing ) THEN

			IF (squeezing # "local") & (squeezing # "global") THEN antsSecurity.Halt( "Squeezing must be local or global !!!" );
			END;

			NEW( statistic );  vyName.RegisterNamed( statistic, statisticName );  CreateTautString( statistic, degraded, thr, squfac, squeezing );
			vec := vyLongrealVec.New( LEN( statistic.reko ) );  vyName.RegisterNamed( vec, name );
			vyLongrealVec.CopyToVec( statistic.reko^, vec( vyLongrealVec.tVector ), LEN( statistic.reko ), 0, 0 );  vyBase.Update( vec );
		END;
	END MakeStatistic;

	PROCEDURE CreateTautString*( VAR s: Statistic;  degraded: vyBase.Object;  thr: FLOAT64;  squfac: FLOAT64;  squeezing: ARRAY OF CHAR );
	(* Mit dieser Methode wird die Berechnung gestartet, die Felder des Objekts Statistic werden initialisiert. *)

	VAR n, i: SIGNED32;

	BEGIN
		n := vyLongrealVec.Len( degraded( vyLongrealVec.tVector ) );  NEW( s.data, n );  NEW( s.reko, n );  s.n := n;
		vyLongrealVec.CopyToArray( degraded( vyLongrealVec.tVector ), s.data^ );  vyLongrealVec.CopyToArray( degraded( vyLongrealVec.tVector ), s.reko^ );
		GetTautString( s.reko^, s, thr, squfac, squeezing );
	END CreateTautString;

	PROCEDURE GetTautString*( data: ARRAY OF FLOAT64;  VAR s: Statistic;  thr: FLOAT64;  squfac: FLOAT64;  squeezing: ARRAY OF CHAR );
	(* Eigentliche Methode zur Berechnung des TautString. *)

	VAR dataSum, dataSumX, eps, upper, lower, residuals, string, knotst, knotsy: aA.X1d;  ind, ind2, knotsind: aA.L1d;  dist, sigma, mean, sum, sqthr: FLOAT64;
		i, nknots: SIGNED32;

	BEGIN
		NEW( dataSum, s.n + 1 );  dataSum := cumsum( data );  NEW( dataSumX, s.n + 1 );  dataSumX := MakeXInterval( LEN( dataSum ) );
		dist := 0.5 * (Max( dataSum^ ) - Min( dataSum^ ));  sigma := Mad( data );  NEW( eps, s.n + 1 );  NEW( lower, s.n + 1 );  NEW( upper, s.n + 1 );

		FOR i := 0 TO s.n DO eps[i] := dist;  lower[i] := dataSum[i] - dist;  upper[i] := dataSum[i] + dist;  END;

		NEW( residuals, s.n );  NEW( string, s.n );  NEW( knotsind, s.n + 1 );  NEW( knotst, s.n + 1 );  NEW( knotsy, s.n + 1 );  NEW( ind, s.n );  NEW( ind2, s.n + 1 );

		LOOP
			DoGetTautString( dataSumX^, dataSum^, lower^, upper^, dataSum[0], dataSum[s.n], string^, knotsind^, knotst^, knotsy^, nknots, s );

			FOR i := 0 TO s.n - 1 DO residuals[i] := data[i] - string[i];  END;

			mean := Mean( residuals^ );

			FOR i := 0 TO s.n - 1 DO residuals[i] := residuals[i] - mean;  END;

			sqthr := math.sqrt( thr * math.ln( s.n ) * sigma );  ind := multiwdwr( residuals^, s.n, sqthr, squeezing );  sum := 0;

			FOR i := 0 TO s.n - 1 DO sum := sum + ind[i];  END;

			IF (sum = 0) THEN EXIT;
			END;

			FOR i := 1 TO s.n - 1 DO ind2[i] := ind[i] + ind[i - 1];  END;

			ind2[0] := ind[0];  ind2[s.n] := ind[s.n - 1];

			FOR i := 0 TO s.n DO
				IF (ind2[i] > 0) THEN eps[i] := eps[i] * squfac;  END;
			END;

			FOR i := 0 TO s.n DO lower[i] := dataSum[i] - eps[i];  upper[i] := dataSum[i] + eps[i];  END;
		END;

		vyLongreal.Copy( LEN( string^ ), string^, 0, s.reko^, 0 );
	END GetTautString;

	PROCEDURE DoGetTautString( VAR fdistx: ARRAY OF FLOAT64;  VAR fdist: ARRAY OF FLOAT64;  VAR lower: ARRAY OF FLOAT64;  VAR upper: ARRAY OF FLOAT64;
												   start: FLOAT64;  ende: FLOAT64;  VAR string: ARRAY OF FLOAT64;  VAR knotsind: ARRAY OF SIGNED32;
												   VAR knotst: ARRAY OF FLOAT64;  VAR knotsy: ARRAY OF FLOAT64;  VAR nknots: SIGNED32;  VAR s: Statistic );
	(* Methode zur Neuberechnung des TautStrings. Wird in der Schleife von GetTautString aufgerufen.
	Falls das Minimum der oberen Schranke noch zu weit von Maximum der unteren Schranke entfernt ist,
	wird der TautString neu berechnet. *)

	VAR i: SIGNED32;

	BEGIN
		IF (ABS( Min( upper ) - Max( lower ) ) < (1 / 100000000)) THEN
			FOR i := 0 TO s.n - 1 DO string[i] := Min( upper );  END;
		ELSE tautstring( fdist, fdistx, lower, upper, start, ende, s.n + 1, string, knotsind, knotst, knotsy, nknots );
		END

	END DoGetTautString;

	PROCEDURE Mad*( y: ARRAY OF FLOAT64 ): FLOAT64;
	(* Berechnung des MAD der Zahlen in y. *)

	VAR i, len: SIGNED32;  med, mad: FLOAT64;  z: aA.X1d;

	BEGIN
		len := LEN( y ) - 1;  NEW( z, len );

		FOR i := 1 TO len DO z[i - 1] := (y[i] - y[i - 1]) / math.sqrt( 2 );  END;

		med := Median( z^ );

		FOR i := 0 TO len - 1 DO z[i] := ABS( z[i] - med );  END;

		mad := Median( z^ ) * 1.4826;

		RETURN mad;
	END Mad;

	PROCEDURE Median( y: ARRAY OF FLOAT64 ): FLOAT64;
	(* Berechnung des Medians der Zahlen in y. *)

	VAR len: SIGNED32;

	BEGIN
		len := LEN( y );  RETURN aA.Median1dX( y, len );
	END Median;

	PROCEDURE Mean( y: ARRAY OF FLOAT64 ): FLOAT64;
	(* Berechnung des Durchschnitts der Zahlen in y. *)

	VAR len, i, length: SIGNED32;  x, diff, mean: FLOAT64;

	BEGIN
		len := LEN( y );  length := 1;  mean := 0;

		FOR i := 0 TO len - 1 DO x := y[i];  diff := (x - mean);  mean := mean + diff / length;  INC( length );  END;

		RETURN mean;
	END Mean;

	PROCEDURE cumsum( y: ARRAY OF FLOAT64 ): aA.X1d;
	(* Berechnet eine kumulierte Summe.
	In z[n] steht der Ausdruck Summe von 0 bis n-1 über y geteilt durch Länge von y. *)

	VAR len, i: SIGNED32;  z: aA.X1d;

	BEGIN
		len := LEN( y );  NEW( z, len + 1 );  z[0] := 0;

		FOR i := 1 TO len DO z[i] := z[i - 1] + (y[i - 1] / len);  END;

		RETURN z;
	END cumsum;

	PROCEDURE MakeXInterval( len: SIGNED32 ): aA.X1d;
	(* Erzeugung von äquidistanten Abständen der Anzahl len auf dem Intervall [0;1]. *)

	VAR ret: aA.X1d;  i: SIGNED32;

	BEGIN
		NEW( ret, len );

		FOR i := 0 TO len - 1 DO ret[i] := i / (len - 1);  END;

		RETURN ret;
	END MakeXInterval;

	PROCEDURE Min*( x: ARRAY OF FLOAT64 ): FLOAT64;
	(* Berechnet das Minimum der Einträge in x. *)

	VAR min: FLOAT64;  i, len: SIGNED32;

	BEGIN
		min := MAX( FLOAT64 );  len := LEN( x ) - 1;

		FOR i := 0 TO len DO
			IF x[i] < min THEN min := x[i];  END;
		END;

		RETURN min;
	END Min;

	PROCEDURE Max*( x: ARRAY OF FLOAT64 ): FLOAT64;
	(* Berechnet das Maximum der Einträge in x. *)

	VAR max: FLOAT64;  i, len: SIGNED32;

	BEGIN
		max := MIN( FLOAT64 );  len := LEN( x ) - 1;

		FOR i := 0 TO len DO
			IF x[i] > max THEN max := x[i];  END;
		END;

		RETURN max
	END Max;

END antsTautString.