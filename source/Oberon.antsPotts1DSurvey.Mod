MODULE antsPotts1DSurvey IN Oberon;

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
(c) Angela Kempe, 2002
(c) Felix Friedrich, 2002
*)

(* this module is in an experimental state *)

(*
Project "Simulations" (Testing different model selection criteria)
Subject: - generating signals
- generating noise
- adding noise to the signal (generating data)
- applying model selection criteria (AIC, BIC) to find best "reconstruction" of the signal
- scanning of gamma to find the reconstruction of the longest interval

Authors:

Angela Kempe
Felix Friedrich


First date: March 12, 2001
Last date: August 2, 2002
*)

(* ported to Oberon 010315 ak & fof *)


IMPORT Math := MathL IN A2, vyLongreal, vyLongrealVec, vyBase, antsCommands, Input, vyName, Display3, vyLinks, vyPort,
	aM := antsMessages, vyHostStrings, antsReadWrite, Objects, antsSecurity, Texts, vyHostTexts, Gadgets, Attributes,
	antsBellman, antsArrays, antsVecOpt;

CONST
	cMedian* = 0;  cMean* = 1;  cHampel* = 2;  cSaegezahn* = 3;  cHuber* = 4;  cAbs* = 0;  cLog* = 1;  cGaussML* = 0;
	cLaplaceML* = 1;  cUnbiased* = 2;

TYPE

	StatisticObj* = POINTER TO StatisticObjDesc;   (*! implement Handler, Store and Load Procedures etc *)
	StatisticObjDesc* = RECORD (vyBase.ObjDesc)
		s*: antsBellman.Statistic;
		(* temporary Objects follow: *)
		data*, XAIC, XAICEst, XAICC, XSchwarz, XSchwarzEst, XSchwarzCor, XVarDiff, Xresiduals: antsArrays.X1d;
		Bellman*, Xstern*: antsArrays.X2d;
		rstern*: antsArrays.I2d;
		gamma*: antsArrays.X1d;
		jumps*: antsArrays.I1d;
		InterLength*: antsArrays.I2d;
		aiciOpt*, aicEstOpt*, aiccOpt*, schwarzOpt*, schwarzEstOpt*, schwarzCorOpt*, scanningOpt*, scanningLogOpt*, scanningVarOpt*, VarDiffOpt*, KneeCheckOpt*, MultiResOpt*, LongestRunOpt*: LONGINT;
		mad*: LONGREAL;
		reko*: antsArrays.X1d;   (*for fixed gamma*)
	END;

	ArrayFunction = PROCEDURE ( VAR f: ARRAY OF LONGREAL;  i: LONGINT ): LONGREAL;

VAR
	globalS: antsBellman.Statistic;  globalG: LONGREAL;

	(* *****************************************************************************)

	PROCEDURE Sprungzaehler*;
	VAR obj: vyBase.Object;  sprungzahl: LONGINT;

	BEGIN
		antsCommands.InitScan( "data=OBJ" );
		IF antsCommands.ExpectObject( "data", obj ) THEN DoSprungzaehler( obj, sprungzahl );  aM.SI( "Sprungzahl:", sprungzahl ) ELSE RETURN END;

	END Sprungzaehler;

	PROCEDURE DoSprungzaehler*( obj: vyBase.Object;  VAR sprungzahl: LONGINT );
	VAR i, n: LONGINT;
	BEGIN
		sprungzahl := 0;  n := vyLongrealVec.Len( obj( vyLongrealVec.tVector ) );

		FOR i := 0 TO n - 2 DO
			IF vyLongrealVec.Get( obj( vyLongrealVec.tVector ), i ) # vyLongrealVec.Get( obj( vyLongrealVec.tVector ), i + 1 ) THEN
				sprungzahl := sprungzahl + 1
			END;
		END;

	END DoSprungzaehler;

(* *****************************************************************************)

	PROCEDURE SsqFct( k, n: LONGINT ): LONGREAL;
	BEGIN
		RETURN globalS.s[k, n]
	END SsqFct;

	PROCEDURE SsqFctGamma( k, n: LONGINT ): LONGREAL;
	BEGIN
		RETURN globalS.s[k, n] + globalG;
	END SsqFctGamma;

	PROCEDURE BellmanFunction( VAR Bellman: antsArrays.X2d;  VAR rstern: antsArrays.I2d;  s: antsBellman.Statistic );
	BEGIN
		globalS := s;  antsBellman.BellmanMatrix( rstern, Bellman, s.N, SsqFct )
	END BellmanFunction;

	PROCEDURE getMean( k, n: LONGINT ): LONGREAL;
	BEGIN
		RETURN globalS.m[k, n]
	END getMean;

	PROCEDURE Parti( rstern: antsArrays.I2d;  VAR Xstern: antsArrays.X2d;  s: antsBellman.Statistic );
	BEGIN
		globalS := s;  antsBellman.PartitionMatrix( rstern, Xstern, getMean )
	END Parti;

(*Procedure finding the minimium and minimum position of a vector*)
	PROCEDURE Minimize( VAR this: ARRAY OF LONGREAL;  VAR kmin: LONGINT );
	VAR min: LONGREAL;
	BEGIN
		min := vyLongreal.Min( LEN( this ), this, 0, kmin );
		IF kmin < 0 THEN kmin := 0;  aM.eS( "Warning: Minimize with no valid return value, temporarily fixed." );  END;
	END Minimize;

	(*Model Selection Criteria***)

	(*
we use the loglikelihood function
-N/2 ln(2 pi) - N/2 ln(sigmaqu) - 1/(2 sigmaqu) * Bellman^[k - 1][N - 1]
for one time series assuming that data are independent and normal distributed in each of the k groups
*)

	(*
Akaikes' Information Criterion: To get the order k minimize
AIC(k) = - loglikelihood function(k) + k
= N/2 ln(2 pi) + N/2 ln(sigmaqu) + 1/(2 sigmaqu) * Bellman^[k - 1][N - 1] + k
*)
 (*The produre called Akaike does NOT realize Akaike's Information Criterion, the penalty for the number of jumps is arbitrary*)

	PROCEDURE Akaike( Bellman: antsArrays.X2d;  VAR Vals: antsArrays.X1d;  sigmaqu: LONGREAL );
	VAR k, N: LONGINT;
	BEGIN
		N := LEN( Bellman^ );
		IF (Vals = NIL ) OR (LEN( Vals ) # N) THEN NEW( Vals, N ) END;
		FOR k := 1 TO N DO Vals^[k - 1] := 0.5 * (1 / sigmaqu) * Bellman^[k - 1][N - 1] + k * N END
	END Akaike;

(*
This is indeed a realization of Akaike's Information Criterion (AIC) if the variance sigmaqu is known, it reduces to
AIC(k) = 1/(2 sigmaqu) * Bellman^[k - 1][N - 1] + k
*)
	PROCEDURE AkaikeIndependent( Bellman: antsArrays.X2d;  VAR Vals: antsArrays.X1d;  sigmaqu: LONGREAL );
	VAR k, N: LONGINT;
	BEGIN
		N := LEN( Bellman^ );
		IF (Vals = NIL ) OR (LEN( Vals ) # N) THEN NEW( Vals, N ) END;
		FOR k := 1 TO N DO Vals^[k - 1] := 0.5 * (1 / sigmaqu) * Bellman^[k - 1][N - 1] + k END
	END AkaikeIndependent;

(*
If the variance is not known we take the estimated variance (maximum likelihood estimator)
sigmaqu = 1/N Bellman[k-1][N-1] and AIC becomes
AIC(k) = N/2 * ln(Bellman[k-1][N-1]) + k
*)
	PROCEDURE AkaikeIndependentEst( Bellman: antsArrays.X2d;  VAR Vals: antsArrays.X1d );
	VAR k, N: LONGINT;
	BEGIN
		N := LEN( Bellman^ );
		IF (Vals = NIL ) OR (LEN( Vals ) # N) THEN NEW( Vals, N ) END;
		FOR k := 1 TO N DO
			Vals^[k - 1] := 0.5 * N * Math.ln( Bellman^[k - 1][N - 1] ) + k;
			IF Bellman^[k - 1][N - 1] = 0 THEN Vals^[k - 1] := MAX( LONGREAL ) END  (* undefined *)
		END
	END AkaikeIndependentEst;

(*
Corrected version of AIC for short time series when the parameter mu and the also the variance sigmaqu have to be estimated.
AICC(k) = N/2 ln(sigmaqu) + (N(N+k))/(2(N-k-2))
*)
	PROCEDURE AkaikeCor( Bellman: antsArrays.X2d;  VAR Vals: antsArrays.X1d );
	VAR k, N: LONGINT;
	BEGIN
		N := LEN( Bellman^ );
		IF (Vals = NIL ) OR (LEN( Vals ) # N - 2) THEN NEW( Vals, N - 2 ) END;
		FOR k := 1 TO (N - 3) DO Vals^[k - 1] := 0.5 * N * Math.ln( Bellman^[k - 1][N - 1] ) + 0.5 * N * (N + k) / (N - k - 2) END
		(* valid only for k < N-2 *)
	END AkaikeCor;

	(*
Schwarz' Information Criterion: To get the order k minimize
SIC(k) = - loglikelihood function(k) + k/2 ln(N)
= N/2 ln(2 pi) + N/2 ln(sigmaqu) + 1/(2 sigmaqu) * Bellman^[k - 1][N - 1] + k/2 ln(N)
under the assumption that data are independent and normal distributed in each of the k groups
*)
	 (*CAUTION: The sample length (or what is interpreted as sample length) is the argument of the logarithm in the last term*)
(*
If the variance is assumed to be known we get
SIC(k) = 1/(2 sigmaqu) * Bellman^[k - 1][N - 1] + k/2 ln(N)
*)
	PROCEDURE SchwarzIndependent( Bellman: antsArrays.X2d;  VAR Vals: antsArrays.X1d;  sigmaqu: LONGREAL );
	VAR k, N: LONGINT;
	BEGIN
		N := LEN( Bellman^ );
		IF (Vals = NIL ) OR (LEN( Vals ) # N) THEN NEW( Vals, N ) END;
		FOR k := 1 TO N DO Vals^[k - 1] := 0.5 * (1 / sigmaqu) * Bellman^[k - 1][N - 1] + k / 2 * Math.ln( N ) END
	END SchwarzIndependent;

(*
If we use the maximum likelihood estimator for the variance sigmaqu we arrive at
SIC(k) = N/2 ln(Bellman[k-1][N-1]) + k/2 ln(N)
*)
	PROCEDURE SchwarzIndependentEst( Bellman: antsArrays.X2d;  VAR Vals: antsArrays.X1d );
	VAR k, N: LONGINT;
	BEGIN
		N := LEN( Bellman^ );
		IF (Vals = NIL ) OR (LEN( Vals ) # N) THEN NEW( Vals, N ) END;
		FOR k := 1 TO N DO
			Vals^[k - 1] := 0.5 * N * Math.ln( Bellman^[k - 1][N - 1] ) + k / 2 * Math.ln( N );
			IF Bellman^[k - 1][N - 1] = 0 THEN Vals^[k - 1] := MAX( LONGREAL ) END  (* undefined *)
		END
	END SchwarzIndependentEst;

	(*
A corrected version of Schwarz' Information Criterion if we have one time series with estimated variance sigmaqu
(see also the derivation of Cavanaugh)
SICC(k) = (N-k-2)/2 ln(2 pi sigmaqu) - 1/2 sum_(l=1)^k ln(|I_l|)
*)
(*? Vals^[k - 1] := (N - k - 1)  ... ? *)

	PROCEDURE SchwarzCor( Bellman: antsArrays.X2d;  InterLength: antsArrays.I2d;  VAR Vals: antsArrays.X1d );
	VAR k, N, l: LONGINT;  lnsum: antsArrays.X1d;
	BEGIN
		N := LEN( Bellman^ );
		IF (Vals = NIL ) OR (LEN( Vals ) # N) THEN NEW( Vals, N ) END;
		IF (lnsum = NIL ) OR (LEN( lnsum ) # N) THEN NEW( lnsum, N ) END;
		FOR k := 1 TO N DO
			lnsum^[k - 1] := 0;
			FOR l := 1 TO k DO lnsum^[k - 1] := lnsum^[k - 1] + Math.ln( InterLength[l - 1][k - 1] ) END
		END;
		FOR k := 1 TO N DO Vals^[k - 1] := (N - k - 2) * Math.ln( 2 * 3.14 * 1 / N * Bellman^[k - 1][N - 1] ) + lnsum^[k - 1] END
	END SchwarzCor;

	PROCEDURE MaxPosArrayFunction( VAR f: ARRAY OF LONGREAL;  VAR values: antsArrays.X1d;  p: ArrayFunction;  value: LONGREAL ): LONGINT;
	VAR i, maxpos: LONGINT;
	BEGIN
		NEW( values, LEN( f ) - 1 );
		FOR i := 0 TO LEN( f ) - 2 DO  (*! caution: we only take n-1 elements *)
			values[i] := p( f, i )
		END;
		value := vyLongreal.Max( LEN( f ) - 1, values^, 0, maxpos );  RETURN maxpos + 1
	END MaxPosArrayFunction;

	PROCEDURE ARatio( VAR f: ARRAY OF LONGREAL;  i: LONGINT ): LONGREAL;
	BEGIN
		IF i = LEN( f ) - 1 THEN RETURN MIN( LONGREAL ) ELSE RETURN f[i] / f[i + 1] END
	END ARatio;

	(* Achtung, zu Testzwecken!!!!!!!!!!!!!!!!!!!!!!!!!!*********************************)
(*
(*mit anderer Funktion als der Identität oder dem Logarithmus*)
PROCEDURE ALen(VAR f: ARRAY OF LONGREAL; i: LONGINT): LONGREAL;
BEGIN
	IF i = LEN(f) - 1 THEN RETURN MIN(LONGREAL)
	ELSE
		RETURN ABS(Math.sqrt(f[i]) - Math.sqrt(f[i + 1]))/Math.sqrt(f[i]*f[i+1])
	END
END ALen;
*)

	PROCEDURE ALen( VAR f: ARRAY OF LONGREAL;  i: LONGINT ): LONGREAL;
	BEGIN
		IF i = LEN( f ) - 1 THEN RETURN MIN( LONGREAL ) ELSE RETURN ABS( f[i] - f[i + 1] ) END
	END ALen;

	PROCEDURE MaxLenPos( VAR f: ARRAY OF LONGREAL;  p: ArrayFunction ): LONGINT;
	VAR values: antsArrays.X1d;  value: LONGREAL;
	BEGIN
		RETURN MaxPosArrayFunction( f, values, p, value )
	END MaxLenPos;

(*
Finding the highest gain in the variance comparing the difference of two subsequent variance estimators
in the gamma-scanning
(depending on type maximum likelihood estimator or the common unbiased variance estimator 1/(N-1) \sum_{i=1}^N (y_i - \bar{y} )^2 is taken)
*)
	PROCEDURE VarianceGain( type: INTEGER;  data: antsArrays.X1d;  Xstern: antsArrays.X2d;  jumps: antsArrays.I1d;  VAR kstern: LONGINT );
	VAR k, N: LONGINT;  jumpN: LONGINT;  Vals: antsArrays.X1d;  diff: LONGREAL;  b: LONGREAL;
	BEGIN
		jumpN := LEN( jumps^ );  NEW( Vals, jumpN );  b := EstimatedVariance( Xstern^[jumps^[0]], data^, type );
		diff := b - EstimatedVariance( Xstern^[jumps^[1]], data^, type );  Vals^[0] := diff;  kstern := jumps^[1];  k := 1;
		WHILE (jumps^[k] # 0) DO
			b := EstimatedVariance( Xstern^[jumps^[k]], data^, type );
			Vals^[jumps^[k]] := b - EstimatedVariance( Xstern^[jumps^[k + 1]], data^, type );
			IF Vals^[jumps^[k]] > diff THEN diff := Vals^[jumps^[k]];  kstern := jumps^[k + 1] END;
			INC( k )
		END
	END VarianceGain;

(*
estimator for the variance (depending on type maximum likelihood estimator or an unbiased estimator) of y if x is assumed to be the real signal
*)
	PROCEDURE EstimatedVariance*( VAR x, y: ARRAY OF LONGREAL;  type: INTEGER ): LONGREAL;
	BEGIN
		IF type = cGaussML THEN RETURN vyLongreal.Dist2Sq( LEN( x ), x, 0, y, 0 ) / LEN( x )
		ELSIF type = cLaplaceML THEN
			RETURN 2 * (vyLongreal.Dist1( LEN( x ), x, 0, y, 0 ) / LEN( x )) * (vyLongreal.Dist1( LEN( x ), x, 0, y, 0 ) / LEN( x ))
		ELSE RETURN vyLongreal.Dist2Sq( LEN( x ), x, 0, y, 0 ) / (LEN( x ) - 1)
		END
	END EstimatedVariance;

(*
The estimated variances (depending on type the maximum likelihood estimator or an unbiased estimator is taken)
for the reconstructions in the gamma-scanning
*)
	PROCEDURE VarianceEstimatorScanning( type: INTEGER;  data: antsArrays.X1d;  Xstern: antsArrays.X2d;  jumps: antsArrays.I1d;
																	  gamma: antsArrays.X1d;  gammalen: LONGINT;  VAR Vals: antsArrays.X1d );
	VAR k: LONGINT;
	BEGIN
		IF (Vals = NIL ) OR (LEN( Vals ) # gammalen) THEN NEW( Vals, gammalen ) END;
		FOR k := 1 TO gammalen DO Vals[k - 1] := EstimatedVariance( Xstern^[jumps^[k - 1]], data^, type ) END
	END VarianceEstimatorScanning;

(*
Depending on type the unbiased estimator 1/(N-1) sum_{i=1}^N (y_i - bar{y} )^2 or the maximum likelihood estimator for the variance is taken
for every number of intervals and check for which number of intervals this estimator is closest to the given variance
*)
	PROCEDURE VarianceTest( type: INTEGER;  data: antsArrays.X1d;  Xstern: antsArrays.X2d;  VAR Vals: antsArrays.X1d;  variance: LONGREAL );
	VAR k, N: LONGINT;
	BEGIN
		N := LEN( data^ );
		IF (Vals = NIL ) OR (LEN( Vals ) # N) THEN NEW( Vals, N ) END;
		FOR k := 1 TO N DO Vals^[k - 1] := ABS( EstimatedVariance( Xstern^[k - 1], data^, type ) - variance ) END
	END VarianceTest;

(*
Depending on type the unbiased estimator 1/(N-1) sum_{i=1}^N (y_i - bar{y} )^2 or the maximum likelihood estimator for the variance is taken
only for number of intervals appearing in the scanning
and check for which number of intervals this estimator is closest to the given variance
*)
	PROCEDURE VarianceTestScanning( type: INTEGER;  data: antsArrays.X1d;  Xstern: antsArrays.X2d;  jumps: antsArrays.I1d;
															 VAR Vals: antsArrays.X1d;  variance: LONGREAL );
	VAR k, jumpN: LONGINT;
	BEGIN
		jumpN := LEN( jumps^ );
		IF (Vals = NIL ) OR (LEN( Vals ) # jumpN) THEN NEW( Vals, jumpN ) END;
		FOR k := 1 TO jumpN DO Vals^[k - 1] := ABS( EstimatedVariance( Xstern^[jumps^[k - 1]], data^, type ) - variance ) END
	END VarianceTestScanning;

(*
We compute the second differences for the variance estimator N*Bellman[k-1][N-1] .
*)
	PROCEDURE SecondDiff( Bellman: antsArrays.X2d;  VAR Vals: antsArrays.X1d );
	VAR k, N: LONGINT;
	BEGIN
		N := LEN( Bellman^ );
		IF (Vals = NIL ) OR (LEN( Vals ) # N) THEN NEW( Vals, N ) END;
		FOR k := 2 TO N - 1 DO Vals^[k - 1] := -N * (Bellman^[k - 2][N - 1] - 2 * Bellman^[k - 1][N - 1] + Bellman^[k][N - 1]) END
	END SecondDiff;

(*
Compute multiresolution coefficients
*)
	PROCEDURE MultiCoefficients( y: ARRAY OF LONGREAL;  Xstern: ARRAY OF LONGREAL;  VAR Coeff: antsArrays.X2d );
	VAR cumsum: antsArrays.X1d;  i, j, N: LONGINT;
	BEGIN
		N := LEN( y );

		IF (cumsum = NIL ) OR (LEN( cumsum ) # N) THEN NEW( cumsum, N )
		END;
		IF (Coeff = NIL ) OR (LEN( Coeff ) # N) THEN NEW( Coeff, N, N ) END;

		cumsum^[0] := y[0] - Xstern[0];

		FOR i := 2 TO N DO cumsum^[i - 1] := cumsum^[i - 2] + y[i - 1] - Xstern[i - 1] END;

		FOR j := 1 TO N DO Coeff^[0][j - 1] := cumsum^[j - 1] / Math.sqrt( j ) END;

		FOR j := 1 TO N DO
			FOR i := 2 TO j DO Coeff^[i - 1][j - 1] := (cumsum^[j - 1] - cumsum^[i - 2]) / Math.sqrt( j - i + 1 ) END
		END
	END MultiCoefficients;

(*
The median absolute deviation is defined as
MAD(z) = median(z_i - median(z))
*)
	PROCEDURE MAD*( y: vyLongrealVec.tVector ): LONGREAL;
	VAR N, i: LONGINT;  val: LONGREAL;  z: vyLongrealVec.tVector;  mad: LONGREAL;  len: LONGINT;  median: LONGREAL;
	BEGIN
		N := vyLongrealVec.Len( y( vyLongrealVec.tVector ) );  len := N - 1;  z := vyLongrealVec.New( len );

		FOR i := 1 TO len DO
			val := (vyLongrealVec.Get( y, i ) - vyLongrealVec.Get( y, i - 1 )) / Math.sqrt( 2 );  vyLongrealVec.Set( val, z, i - 1 )
		END;

		median := vyLongrealVec.GetMedian( z );

		FOR i := 1 TO len DO val := ABS( vyLongrealVec.Get( z, i - 1 ) - median );  vyLongrealVec.Set( val, z, i - 1 ) END;

		mad := vyLongrealVec.GetMedian( z );

		RETURN mad
	END MAD;

(*
Using MAD estimator for the variance and the Davies/Kovac criterion for the wavelet coefficients
*)
	PROCEDURE MultiResCheck( data: ARRAY OF LONGREAL;  mad: LONGREAL;  Xstern: antsArrays.X2d;  jumps: antsArrays.I1d;  factor: LONGREAL;
												 VAR ksterndl: LONGINT );
	VAR const: LONGREAL;  N: LONGINT;  xsterndl: antsArrays.X1d;  i, j, k: LONGINT;  toobig: BOOLEAN;  kstern: INTEGER;  Coeff: antsArrays.X2d;  estimatedsigma: LONGREAL;

	BEGIN
		N := LEN( Xstern );

		IF (xsterndl = NIL ) OR (LEN( xsterndl ) # N) THEN NEW( xsterndl, N )
		END;

		const := Math.sqrt( factor * Math.ln( N ) );   (* factor = 2 is what usually is used, factor = 2.5 is suggested in Davies/Kovac *)

		(* wenn da der log zur Basis zwei stehen sollte....
	const := Math.sqrt( factor * Math.ln( N )/Math.ln(2) );  (* factor = 2 is what usually is used, factor = 2.5 is suggested in Davies/Kovac *)
	*)

		estimatedsigma := mad * 1.4826;

		i := 0;  toobig := TRUE;

		WHILE (toobig = TRUE ) & (i < N) DO

			kstern := jumps^[i];

			FOR k := 1 TO N DO xsterndl^[k - 1] := Xstern^[kstern][k - 1] END;

			(*Computation of the multiresolution coefficents*)
			MultiCoefficients( data, xsterndl^, Coeff );

			toobig := FALSE;
			(*
		If one of the coefficients is bigger than the bound, then we set toobig equal to TRUE and kstern equal to the the number of jumps jumps[i]
		and pass to the next number of jumps
		*)

			j := 1;
			WHILE ((j <= N) & ~toobig) DO
				k := 1;
				WHILE ((k <= j) & ~toobig) DO
					IF (ABS( Coeff^[k - 1][j - 1] ) > (estimatedsigma * const)) THEN
						toobig := TRUE;  ksterndl := jumps^[i + 1] (*geändert am 28.10.03!!!! von jumps[i]!!!!*)
					END;
					INC( k )
				END;
				INC( j )
			END;
			INC( i )

		END;   (*of WHILE*)

	END MultiResCheck;

	PROCEDURE LongestRunCheck( data: ARRAY OF LONGREAL;  mad: LONGREAL;  Xstern: antsArrays.X2d;  jumps: antsArrays.I1d;  VAR kstern: LONGINT );
	VAR const: LONGINT;  N: LONGINT;  residuals: antsArrays.X1d;
		(* j, k: LONGINT; *)
		maxrun: LONGINT;  toobig: BOOLEAN;  i, j, k: LONGINT;
	BEGIN
		N := LEN( Xstern );

		IF (residuals = NIL ) OR (LEN( residuals ) # N) THEN NEW( residuals, N )
		END;

		const := ENTIER( Math.ln( N ) / Math.ln( 2 ) - 1.47 ) + 1;

		i := 0;  toobig := TRUE;

		WHILE toobig = TRUE DO

			k := jumps^[i];

			FOR j := 1 TO N DO residuals^[j - 1] := Xstern^[k][j - 1] - data[j - 1] END;

			(*looking for the longest run*)

			maxrun := MaxRun( residuals^ );

			toobig := FALSE;
			(*
		If for i the longest run is bigger than the bound const, then we set toobig equal to TRUE and ksterndl equal to the the number of jumps jumps[i]
		and pass to the next number of jumps
		*)


			IF maxrun > const THEN
				toobig := TRUE;
				kstern := jumps^[i + 1];   (***!!!!geändert am 28.10.03 von jumps[i]!!!***)
			END;
			INC( i )

		END;   (*of WHILE*)

	END LongestRunCheck;

(*
Procedure to compare MAD of data and height of jump in reconstruction
*)
	PROCEDURE LargestJump( reconstruction: vyBase.Object;  VAR maxjump: LONGREAL );
	VAR N: LONGINT;  rec: antsArrays.X1d;  maxpos: LONGINT;
	BEGIN
		N := vyLongrealVec.Len( reconstruction( vyLongrealVec.tVector ) );
		IF (rec = NIL ) OR (LEN( rec ) # N) THEN NEW( rec, N ) END;
		vyLongrealVec.CopyToArray( reconstruction( vyLongrealVec.tVector ), rec^ );  maxpos := MaxLenPos( rec^, ALen );
		maxjump := rec[maxpos]
	END LargestJump;

	PROCEDURE LargestJumpPos*( reconstruction: vyBase.Object;  VAR maxjump: LONGREAL;  VAR maxpos: LONGINT );
	VAR N: LONGINT;  rec: antsArrays.X1d;
	BEGIN
		N := vyLongrealVec.Len( reconstruction( vyLongrealVec.tVector ) );
		IF (rec = NIL ) OR (LEN( rec ) # N) THEN NEW( rec, N ) END;
		vyLongrealVec.CopyToArray( reconstruction( vyLongrealVec.tVector ), rec^ );  maxpos := MaxLenPos( rec^, ALen );
		maxjump := rec[maxpos]
	END LargestJumpPos;

	PROCEDURE CreateStatistics*( VAR s: StatisticObj;  degraded: vyBase.Object;  type: LONGINT );
	VAR N: LONGINT;  outputMAD: Objects.Object;
	BEGIN
		ASSERT ( (degraded # NIL ) & (degraded IS vyLongrealVec.tVector), 109 );
		N := vyLongrealVec.Len( degraded( vyLongrealVec.tVector ) );

		IF s = NIL THEN NEW( s )
		END;
		IF (s.data = NIL ) OR (LEN( s.data ) # N) THEN NEW( s.data, N ) END;
		vyLongrealVec.CopyToArray( degraded( vyLongrealVec.tVector ), s.data^ );

		antsBellman.InitStatistic1d( s.s, N );
		IF type = cMedian THEN antsBellman.ComputeMedianStat1d( s.data^, s.s )
		ELSIF type = cMean THEN antsBellman.ComputeMeanStat1d( s.data^, s.s )
		ELSIF type = cHampel THEN antsBellman.ComputeHampelStat1d( s.data^, s.s )
		ELSIF type = cSaegezahn THEN antsBellman.ComputeSaegezahnStat1d( s.data^, s.s )
		ELSIF type = cHuber THEN antsBellman.ComputeHuberStat1d( s.data^, s.s )
		END;

		BellmanFunction( s.Bellman, s.rstern, s.s );  Parti( s.rstern, s.Xstern, s.s );
		antsBellman.IntervalLenMatrix( s.rstern, s.InterLength );

		s.mad := MAD( degraded( vyLongrealVec.tVector ) );

		(*writing this value in a text field in the panel***)
		outputMAD := Gadgets.FindObj( Gadgets.context, "outputMAD" );
		IF outputMAD # NIL THEN
			Attributes.SetLongReal( outputMAD, "Value", s.mad );  Attributes.SetInt( outputMAD, "Color", 1 );  Gadgets.Update( outputMAD )
		END
	END CreateStatistics;

	PROCEDURE CreateScaledStatisticsGamma*( VAR s: StatisticObj;  degraded: vyBase.Object;  gamma: LONGREAL );
	VAR N, j, k: LONGINT;  rstern: antsArrays.I1d;  bellman, reko: antsArrays.X1d;
	BEGIN
		ASSERT ( (degraded # NIL ) & (degraded IS vyLongrealVec.tVector), 109 );
		N := vyLongrealVec.Len( degraded( vyLongrealVec.tVector ) );

		IF (s.data = NIL ) OR (LEN( s.data ) # N) THEN NEW( s.data, N )
		END;
		vyLongrealVec.CopyToArray( degraded( vyLongrealVec.tVector ), s.data^ );

		antsBellman.InitStatistic1d( s.s, N );  antsBellman.ComputeMeanStat1d( s.data^, s.s );

		globalS := s.s;
		FOR k := 0 TO N - 1 DO
			FOR j := 0 TO N - 1 DO globalS.s[k, j] := 1 / N * globalS.s[k, j];  END;
		END;
		s.s := globalS;

		(*hier soll s.jumps den Vektor der argmin darstellen und s.gamma den Vektor der Minimalwerte!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!*)
		(* und s.reko ist Vektor für Rekonstruktion bei festem gamma*)
		globalG := gamma;  antsBellman.Bellman( s.jumps, s.gamma, SHORT( N ), 0, MAX( LONGINT ), SsqFctGamma, -globalG );
		antsBellman.Partition( s.jumps, s.reko, getMean );

	END CreateScaledStatisticsGamma;

	PROCEDURE LineToVec*( VAR line: ARRAY OF LONGREAL;  vec: vyBase.Object );
	VAR msg: vyPort.AdjustCoordMsg;
	BEGIN
		vyLongrealVec.CopyToVec( line, vec( vyLongrealVec.tVector ), LEN( line ), 0, 0 );  vyBase.Update( vec );
		vyBase.ForUsersHandle( vec, msg )
	END LineToVec;

	PROCEDURE GetColumn*( VAR A: ARRAY OF ARRAY OF LONGREAL;  column: LONGINT;  VAR col: ARRAY OF LONGREAL );
	VAR i: LONGINT;
	BEGIN
		FOR i := 1 TO LEN( A ) DO col[i - 1] := A[i - 1][column] END
	END GetColumn;

	PROCEDURE GetColumnVec*( VAR A: ARRAY OF ARRAY OF LONGREAL;  column: LONGINT;  VAR vec: vyBase.Object );
	VAR col: antsArrays.X1d;
	BEGIN
		GetColumn( A, column, col^ );  LineToVec( col^, vec )
	END GetColumnVec;

	PROCEDURE AppendValue*( value: LONGREAL;  vec: vyBase.Object );
	BEGIN
		IF vec # NIL THEN
			IF vec IS vyLongrealVec.tVector THEN
				WITH vec: vyLongrealVec.tVector DO vyLongrealVec.Append( value, vec );  vyBase.Update( vec )
				END;
			ELSE
			END
		END
	END AppendValue;

	PROCEDURE ViewVector*( vec: vyLongrealVec.tVector;  as: ARRAY OF CHAR );
	VAR link: vyLinks.Link;
	BEGIN
		link := NIL;  vyLinks.InsertObj( link, vec );  vyBase.Show( link, 1, as )
	END ViewVector;

	PROCEDURE ViewArray*( VAR a: ARRAY OF LONGREAL;  as, name: ARRAY OF CHAR );
	VAR vec: vyLongrealVec.tVector;  link: vyLinks.Link;
	BEGIN
		vec := vyLongrealVec.New( LEN( a ) );  vyLongrealVec.CopyToVec( a, vec, LEN( a ), 0, 0 );  link := NIL;
		vyLinks.InsertObj( link, vec );  vyName.RegisterNamed( vec, name );  vyBase.Show( link, 1, as )
	END ViewArray;

	PROCEDURE DoViewScannings( degraded: vyBase.Object;  statistic: StatisticObj );
	VAR N, i, jumpN: LONGINT;  intervals: antsArrays.X1d;  index: antsArrays.L1d;  maxquot: LONGREAL;  maxquotpos: LONGINT;
		name: ARRAY 64 OF CHAR;
		type: INTEGER;
	BEGIN
		vyHostTexts.DoOpenLog( "antsViewScannings.Text" );  vyHostTexts.SetCaret;  ViewVector( degraded( vyLongrealVec.tVector ), "antsPointPlot" );

		WITH statistic: StatisticObj DO N := LEN( statistic.Xstern );  jumpN := LEN( statistic.jumps );

			NEW( intervals, LEN( statistic.gamma ) );  NEW( index, LEN( statistic.gamma ) );  intervals[0] := 0;  index[0] := 0;
			FOR i := 1 TO LEN( statistic.gamma ) - 1 DO intervals[i] := -statistic.gamma[i - 1] + statistic.gamma[i];  index[i] := i END;

			IF antsCommands.Find( "sort" ) THEN vyLongreal.SortIndexed( LEN( intervals ), intervals^, 0, index^ )
			END;

			maxquot := 0;
			FOR i := 0 TO LEN( statistic.gamma ) - 2 DO
				aM.vSR( "quotient", intervals[i] / intervals[i + 1] );
				IF intervals[i] / intervals[i + 1] > maxquot THEN maxquot := intervals[i] / intervals[i + 1];  maxquotpos := i END
			END;

			i := 0;
			WHILE (statistic.jumps[index[i]] # 0) OR (i = 0) DO

				type := cUnbiased;

				aM.vS( "Taking an unbiased estimator for the variance" );  aM.vSR( "estimated variance", EstimatedVariance( statistic.Xstern[statistic.jumps[index[i]]], statistic.data^, type ) );

				IF i > 0 THEN
					aM.vSI( "gamma of ", i );  aM.vSR( "is", statistic.gamma[i] );  aM.vS( "" );  aM.vSI( "nr:", i );
					aM.vSRSR( "interval: ", statistic.gamma[i], " --", statistic.gamma[i - 1] );  aM.vS( "" )
				ELSE aM.vSI( "gamma of ", i );  aM.vSR( "is", statistic.gamma[i] );  aM.vS( "" );  aM.vSI( "nr:", i );  aM.vSR( "first interval: infinity --", statistic.gamma[i] );  aM.vS( "" )
				END;

				name := "Scanning:";  vyHostStrings.AppendInt( index[i], 2, name );
				ViewArray( statistic.Xstern[statistic.jumps[index[i]]], "vyLinePlot", name );

				(*
			IF i = maxquotpos THEN
				vyPort.focusPicture.backGround := Display3.red;  vyPort.RedrawFocusPict
			END;
			IF i - 1 = maxquotpos THEN
				vyPort.focusPicture.backGround := Display3.green;  vyPort.RedrawFocusPict
			END;
			*)

				INC( i )
			END;

			ViewArray( intervals^, "vyLinePlot", "IntervalLen" )
		END
	END DoViewScannings;

	PROCEDURE ViewScannings*;
	VAR sobj, degraded: vyBase.Object;  statistic: StatisticObj;
	BEGIN
		antsCommands.InitScan( "data=OBJ statistic=OBJ [>sort]" );

		(* standard header for all procedures of this kind ****)
		IF antsCommands.ExpectObject( "data", degraded ) & antsCommands.ExpectObject( "statistic", sobj ) THEN ELSE RETURN END;

		(* body ******)
		statistic := sobj( StatisticObj );  antsBellman.gammaScanning( statistic.Bellman, statistic.jumps, statistic.gamma );
		DoViewScannings( degraded, statistic )
	END ViewScannings;

	PROCEDURE MakeStatistic*;
	VAR statistic: StatisticObj;  obj, degraded: vyBase.Object;
		statisticName: ARRAY 64 OF CHAR;
	BEGIN
		antsCommands.InitScan( "data=OBJ statisticName=NAME (>median|>mean)" );
		IF antsCommands.ExpectObject( "data", degraded ) & antsCommands.ExpectName( "statisticName", statisticName ) THEN

			obj := vyName.FindObj( statisticName );
			IF obj = NIL THEN NEW( statistic );  vyName.RegisterNamed( statistic, statisticName ) ELSE statistic := obj( StatisticObj ) END;

			IF antsCommands.Find( "median" ) THEN CreateStatistics( statistic, degraded, cMedian );  aM.S( "creating median statistic" )
			ELSIF antsCommands.Find( "mean" ) THEN CreateStatistics( statistic, degraded, cMean );  aM.S( "creating mean statistic" )
			ELSIF antsCommands.Find( "hampel" ) THEN CreateStatistics( statistic, degraded, cHampel );  aM.S( "creating hampel statistic" )
			ELSIF antsCommands.Find( "saegezahn" ) THEN CreateStatistics( statistic, degraded, cSaegezahn );  aM.S( "creating Saegezahn statistic" )
			ELSIF antsCommands.Expect( "huber" ) THEN CreateStatistics( statistic, degraded, cHuber );  aM.S( "creating huber statistic" )
			END
		END
	END MakeStatistic;

	PROCEDURE Header*( VAR statistic: StatisticObj;  VAR vec: vyBase.Object ): BOOLEAN;
	VAR name: ARRAY 64 OF CHAR;
		sobj: vyBase.Object;
	BEGIN
		antsCommands.InitScan( "statistic=OBJ (vec=OBJ | (vec=NAME >create) ) [ML [data=OBJ | (>Gauss | >Laplace) ] ] " );
		IF antsCommands.ExpectObject( "statistic", sobj ) & antsCommands.GetObject( "vec", vec ) THEN
			statistic := sobj( StatisticObj );  RETURN TRUE
		ELSIF antsCommands.ExpectName( "vec", name ) & antsCommands.Find( "create" ) THEN
			vec := vyLongrealVec.New( LEN( sobj( StatisticObj ).data ) );  vyName.RegisterNamed( vec, name );
			statistic := sobj( StatisticObj );  RETURN TRUE
		ELSE RETURN FALSE
		END
	END Header;

	PROCEDURE MLOrNot( VAR type: INTEGER );
	VAR obj: vyBase.Object;
		kindofnoise: ARRAY 64 OF CHAR;
	BEGIN
		IF antsCommands.Find( "ML" ) THEN
			IF antsCommands.GetObject( "data", obj ) & (Attributes.FindAttr( antsVecOpt.cNoisedByName, obj.attr ) # NIL ) THEN
				Attributes.GetString( obj, antsVecOpt.cNoisedByName, kindofnoise );  aM.vSS( "Kind of noise: ", kindofnoise );
				IF kindofnoise = antsVecOpt.cGauss THEN type := cGaussML;  aM.S( "computing ML estimator for Gaussian noise" )
				ELSIF kindofnoise = antsVecOpt.cLaplace THEN type := cLaplaceML;  aM.S( "computing ML estimator for Laplace noise" )
				ELSE aM.eS( "no maximum likelihood estimator for this kind of noise prepared" );  aM.S( "" );  aM.S( "taking unbiased variance estimator" );  type := cUnbiased
				END
			ELSE
				IF antsCommands.Find( "Gauss" ) THEN type := cGaussML;  aM.S( "computing ML estimator for Gaussian noise" )
				ELSIF antsCommands.Find( "Laplace" ) THEN type := cLaplaceML;  aM.S( "computing ML estimator for Laplace noise" )
				ELSE aM.eS( "no information about noise, assuming Gaussian noise" );  type := cGaussML
				END
			END
		ELSE type := cUnbiased;  aM.S( "taking unbiased variance estimator" )
		END
	END MLOrNot;

	PROCEDURE DoAIC*( statistic: StatisticObj;  VAR vec: vyBase.Object;  variance: LONGREAL );
	BEGIN
		AkaikeIndependent( statistic.Bellman, statistic.XAIC, variance );  Minimize( statistic.XAIC^, statistic.aiciOpt );
		LineToVec( statistic.Xstern[statistic.aiciOpt], vec )
	END DoAIC;

	PROCEDURE MakeAIC*;
	VAR statistic: StatisticObj;  vec, statvec: vyBase.Object;  bool: BOOLEAN;  variance: LONGREAL;
	BEGIN
		IF ~Header( statistic, vec ) THEN RETURN END;
		(*additional parameters ***)
		IF ~antsCommands.ExpectReal( "variance", variance ) THEN RETURN END;
		bool := antsCommands.GetObject( "statvec", statvec );  DoAIC( statistic, vec, variance );
		AppendValue( statistic.aiciOpt, statvec )
	END MakeAIC;

	PROCEDURE DoAICEst*( statistic: StatisticObj;  vec: vyBase.Object );
	BEGIN
		AkaikeIndependentEst( statistic.Bellman, statistic.XAICEst );  Minimize( statistic.XAICEst^, statistic.aicEstOpt );
		LineToVec( statistic.Xstern[statistic.aicEstOpt], vec )
	END DoAICEst;

	PROCEDURE MakeAICEst*;
	VAR statistic: StatisticObj;  vec, statvec: vyBase.Object;  bool: BOOLEAN;
	BEGIN
		IF ~Header( statistic, vec ) THEN RETURN END;

		bool := antsCommands.GetObject( "statvec", statvec );  DoAICEst( statistic, vec );  AppendValue( statistic.aicEstOpt, statvec )
	END MakeAICEst;

	PROCEDURE DoAICC*( statistic: StatisticObj;  vec: vyBase.Object );
	BEGIN
		AkaikeCor( statistic.Bellman, statistic.XAICC );  Minimize( statistic.XAICC^, statistic.aiccOpt );
		LineToVec( statistic.Xstern[statistic.aiccOpt], vec )
	END DoAICC;

	PROCEDURE MakeAICC*;
	VAR statistic: StatisticObj;  vec, statvec: vyBase.Object;  bool: BOOLEAN;
	BEGIN
		IF ~Header( statistic, vec ) THEN RETURN END;

		bool := antsCommands.GetObject( "statvec", statvec );  DoAICC( statistic, vec );  AppendValue( statistic.aiccOpt, statvec )
	END MakeAICC;

	PROCEDURE DoSIC*( statistic: StatisticObj;  vec: vyBase.Object;  variance: LONGREAL );
	BEGIN
		SchwarzIndependent( statistic.Bellman, statistic.XSchwarz, variance );
		Minimize( statistic.XSchwarz^, statistic.schwarzOpt );  LineToVec( statistic.Xstern[statistic.schwarzOpt], vec )
	END DoSIC;

	PROCEDURE MakeSIC*;
	VAR statistic: StatisticObj;  vec, statvec: vyBase.Object;  bool: BOOLEAN;  variance: LONGREAL;
	BEGIN
		IF ~Header( statistic, vec ) THEN RETURN END;

		(*additional parameters ***)
		IF ~antsCommands.ExpectReal( "variance", variance ) THEN RETURN END;

		bool := antsCommands.GetObject( "statvec", statvec );  DoSIC( statistic, vec, variance );
		AppendValue( statistic.schwarzOpt, statvec )
	END MakeSIC;

	PROCEDURE DoSICEst*( statistic: StatisticObj;  vec: vyBase.Object );
	BEGIN
		SchwarzIndependentEst( statistic.Bellman, statistic.XSchwarzEst );
		Minimize( statistic.XSchwarzEst^, statistic.schwarzEstOpt );  LineToVec( statistic.Xstern[statistic.schwarzEstOpt], vec )
	END DoSICEst;

	PROCEDURE MakeSICEst*;
	VAR statistic: StatisticObj;  vec, statvec: vyBase.Object;  bool: BOOLEAN;
	BEGIN
		IF ~Header( statistic, vec ) THEN RETURN END;

		bool := antsCommands.GetObject( "statvec", statvec );  DoSICEst( statistic, vec );
		AppendValue( statistic.schwarzEstOpt, statvec )
	END MakeSICEst;

	PROCEDURE DoSICC*( statistic: StatisticObj;  vec: vyBase.Object );
	BEGIN
		SchwarzCor( statistic.Bellman, statistic.InterLength, statistic.XSchwarzCor );
		Minimize( statistic.XSchwarzCor^, statistic.schwarzCorOpt );  LineToVec( statistic.Xstern[statistic.schwarzCorOpt], vec )
	END DoSICC;

	PROCEDURE MakeSICC*;
	VAR statistic: StatisticObj;  vec, statvec: vyBase.Object;  bool: BOOLEAN;
	BEGIN
		IF ~Header( statistic, vec ) THEN RETURN END;

		bool := antsCommands.GetObject( "statvec", statvec );  DoSICC( statistic, vec );  AppendValue( statistic.schwarzCorOpt, statvec )
	END MakeSICC;

	PROCEDURE DoMaxInterval*( statistic: StatisticObj;  vec: vyBase.Object );
	BEGIN
		antsBellman.gammaScanning( statistic.Bellman, statistic.jumps, statistic.gamma );
		statistic.scanningOpt := statistic.jumps[MaxLenPos( statistic.gamma^, ALen )];
		LineToVec( statistic.Xstern[statistic.scanningOpt], vec )
	END DoMaxInterval;

	PROCEDURE MakeMaxInterval*;
	VAR statistic: StatisticObj;  vec, statvec: vyBase.Object;  bool: BOOLEAN;  MaxJump: LONGREAL;  outputMaxJump: Objects.Object;
	BEGIN
		IF ~Header( statistic, vec ) THEN RETURN END;

		bool := antsCommands.GetObject( "statvec", statvec );  DoMaxInterval( statistic, vec );

		IF antsCommands.Find( "compare" ) THEN
			LargestJump( vec, MaxJump );
			(*writing in a text field in a panel***)
			outputMaxJump := Gadgets.FindObj( Gadgets.context, "outputMaxJump" );
			IF outputMaxJump # NIL THEN
				Attributes.SetLongReal( outputMaxJump, "Value", MaxJump );  Gadgets.Update( outputMaxJump )
			END
		END
	END MakeMaxInterval;

	PROCEDURE DoMaxIntervalLog*( statistic: StatisticObj;  vec: vyBase.Object );
	BEGIN
		antsBellman.gammaScanning( statistic.Bellman, statistic.jumps, statistic.gamma );
		statistic.scanningLogOpt := statistic.jumps[MaxLenPos( statistic.gamma^, ARatio )];
		LineToVec( statistic.Xstern[statistic.scanningLogOpt], vec )
	END DoMaxIntervalLog;

	PROCEDURE MakeMaxIntervalLog*;
	VAR statistic: StatisticObj;  vec, statvec: vyBase.Object;  bool: BOOLEAN;
	BEGIN
		IF ~Header( statistic, vec ) THEN RETURN END;

		(* body ******)
		bool := antsCommands.GetObject( "statvec", statvec );  DoMaxIntervalLog( statistic, vec );
		(*
	(* **************Einschub zu Testzwecken*********************************)
	(*number of gamma-intervals*)
	lengamma := antsArrays.FindFirstX( statistic.gamma^, 0 );
	aM.SI( "number gammas in the scanning:   ",lengamma);
	aM.SI( "chosen number:   ",statistic.scanningLogOpt);
	(*******************************************************************)
	*)
		AppendValue( statistic.scanningLogOpt, statvec )
	END MakeMaxIntervalLog;

	PROCEDURE DoVarianceGain*( statistic: StatisticObj;  vec: vyBase.Object;  type: INTEGER );
	BEGIN
		antsBellman.gammaScanning( statistic.Bellman, statistic.jumps, statistic.gamma );
		VarianceGain( type, statistic.data, statistic.Xstern, statistic.jumps, statistic.scanningVarOpt );
		LineToVec( statistic.Xstern[statistic.scanningVarOpt], vec )
	END DoVarianceGain;

	PROCEDURE MakeVarianceGain*;
	VAR statistic: StatisticObj;  vec, statvec, obj: vyBase.Object;  bool: BOOLEAN;  type: INTEGER;
	BEGIN
		IF ~Header( statistic, vec ) THEN RETURN END;

		(*asking for the kind of variance estimator to be taken*)
		MLOrNot( type );

		bool := antsCommands.GetObject( "statvec", statvec );  DoVarianceGain( statistic, vec, type );
		AppendValue( statistic.scanningVarOpt, statvec )
	END MakeVarianceGain;

	PROCEDURE DoVarianceTest*( statistic: StatisticObj;  vec: vyBase.Object;  variance: LONGREAL;  type: INTEGER );
	BEGIN
		VarianceTest( type, statistic.data, statistic.Xstern, statistic.XVarDiff, variance );
		Minimize( statistic.XVarDiff^, statistic.VarDiffOpt );  LineToVec( statistic.Xstern[statistic.VarDiffOpt], vec )
	END DoVarianceTest;

	PROCEDURE MakeVarianceTest*;
	VAR statistic: StatisticObj;  vec, statvec, obj: vyBase.Object;  bool: BOOLEAN;  variance: LONGREAL;  type: INTEGER;
	BEGIN
		IF ~Header( statistic, vec ) THEN RETURN END;

		(*additional parameters ***)
		IF ~antsCommands.ExpectReal( "variance", variance ) THEN RETURN END;

		(*asking for the kind of variance estimator to be taken*)
		MLOrNot( type );

		bool := antsCommands.GetObject( "statvec", statvec );  DoVarianceTest( statistic, vec, variance, type );
		AppendValue( statistic.VarDiffOpt, statvec )
	END MakeVarianceTest;

	PROCEDURE DoVarianceTestScanning*( statistic: StatisticObj;  vec: vyBase.Object;  variance: LONGREAL;  type: INTEGER );
	BEGIN
		VarianceTestScanning( type, statistic.data, statistic.Xstern, statistic.jumps, statistic.XVarDiff, variance );
		Minimize( statistic.XVarDiff^, statistic.VarDiffOpt );  LineToVec( statistic.Xstern[statistic.VarDiffOpt], vec )
	END DoVarianceTestScanning;

	PROCEDURE MakeVarianceTestScanning*;
	VAR statistic: StatisticObj;  vec, statvec, obj: vyBase.Object;  bool: BOOLEAN;  variance: LONGREAL;  type: INTEGER;
	BEGIN
		IF ~Header( statistic, vec ) THEN RETURN END;

		(*additional parameters ***)
		IF ~antsCommands.ExpectReal( "variance", variance ) THEN RETURN END;

		(*asking for the kind of variance estimator to be taken*)
		MLOrNot( type );

		bool := antsCommands.GetObject( "statvec", statvec );  DoVarianceTestScanning( statistic, vec, variance, type );
		AppendValue( statistic.VarDiffOpt, statvec )
	END MakeVarianceTestScanning;

	PROCEDURE DoKneeCheck*( statistic: StatisticObj;  vec: vyBase.Object );
	BEGIN
		KneeCheck( statistic.Bellman, statistic.Xresiduals );  Minimize( statistic.Xresiduals^, statistic.KneeCheckOpt );
		LineToVec( statistic.Xstern[statistic.KneeCheckOpt], vec )
	END DoKneeCheck;

	PROCEDURE MakeKneeCheck*;
	VAR statistic: StatisticObj;  vec, statvec: vyBase.Object;  bool: BOOLEAN;
	BEGIN
		IF ~Header( statistic, vec ) THEN RETURN END;

		bool := antsCommands.GetObject( "statvec", statvec );  DoKneeCheck( statistic, vec );
		AppendValue( statistic.KneeCheckOpt, statvec )
	END MakeKneeCheck;

	PROCEDURE DoMultiCoeff*( statistic: StatisticObj;  vec: vyBase.Object;  factor: LONGREAL );
	VAR ksterndl: LONGINT;
	BEGIN
		antsBellman.gammaScanning( statistic.Bellman, statistic.jumps, statistic.gamma );
		MultiResCheck( statistic.data^, statistic.mad, statistic.Xstern, statistic.jumps, factor, ksterndl );
		statistic.MultiResOpt := statistic.jumps[ksterndl];  LineToVec( statistic.Xstern[statistic.MultiResOpt], vec )
	END DoMultiCoeff;

	PROCEDURE MakeMultiCoeff*;
	VAR statistic: StatisticObj;  vec, statvec: vyBase.Object;  bool: BOOLEAN;  factor: LONGREAL;  ksterndl: LONGINT;
	BEGIN
		IF ~Header( statistic, vec ) THEN RETURN END;

		(*additional parameters ***)
		IF ~antsCommands.ExpectReal( "factor", factor ) THEN RETURN END;

		bool := antsCommands.GetObject( "statvec", statvec );  DoMultiCoeff( statistic, vec, factor );
		AppendValue( statistic.aicEstOpt, statvec )
	END MakeMultiCoeff;

	PROCEDURE DoLongestRun*( statistic: StatisticObj;  vec: vyBase.Object );
	VAR kstern: LONGINT;
	BEGIN
		antsBellman.gammaScanning( statistic.Bellman, statistic.jumps, statistic.gamma );
		LongestRunCheck( statistic.data^, statistic.mad, statistic.Xstern, statistic.jumps, kstern );
		statistic.LongestRunOpt := kstern;  LineToVec( statistic.Xstern[statistic.LongestRunOpt], vec );
	END DoLongestRun;

	PROCEDURE MakeLongestRun*;
	VAR statistic: StatisticObj;  vec, statvec: vyBase.Object;  bool: BOOLEAN;
		(* factor: LONGREAL; *)
		kstern: LONGINT;
	BEGIN
		IF ~Header( statistic, vec ) THEN RETURN END;

		bool := antsCommands.GetObject( "statvec", statvec );  DoLongestRun( statistic, vec );
		AppendValue( statistic.aicEstOpt, statvec )
	END MakeLongestRun;

	PROCEDURE DoIterativePotts*( input: vyBase.Object;  vec, res: vyLongrealVec.tVector;  type: INTEGER;  factor: LONGREAL );
	VAR i, N, j, k: LONGINT;  alarm: LONGINT;
		(* ch: CHAR; *)
		msg: vyPort.AdjustCoordMsg;
		(* NumOfJumps: LONGINT;
	lastval: LONGREAL; *)
		statistic: StatisticObj;  toobig: BOOLEAN;  estimatedsigma, const: LONGREAL;  mad: LONGREAL;  vecArray, inputArray: antsArrays.X1d;
		Coeff: antsArrays.X2d;  degraded: vyBase.Object;
	BEGIN
		alarm := 0;

		N := vyLongrealVec.Len( input( vyLongrealVec.tVector ) );

		degraded := vyLongrealVec.New( N );
		(******** *to keep original data***********, degraded will be changed***************)
		vyLongrealVec.CopyData( input( vyLongrealVec.tVector ), degraded( vyLongrealVec.tVector ) );
		IF (inputArray = NIL ) OR (LEN( inputArray ) # N) THEN NEW( inputArray, N ) END;
		vyLongrealVec.CopyToArray( input( vyLongrealVec.tVector ), inputArray^ );
		(***************************************************************************)

		IF (vecArray = NIL ) OR (LEN( vecArray ) # N) THEN NEW( vecArray, N ) END;

		(*WHILE (ch # "x") DO*)

		const := Math.sqrt( factor * Math.ln( N ) );   (* factor = 2 is what usually is used, factor = 2.5 is suggested in Davies/Kovac *)

		toobig := TRUE;

		WHILE toobig = TRUE DO

			NEW( statistic );

			statistic.s := NIL;  statistic.rstern := NIL;  statistic.Xstern := NIL;  statistic.Bellman := NIL;

			CreateStatistics( statistic, degraded, type );

			(*N := LEN( statistic.data );*)

			antsBellman.gammaScanning( statistic.Bellman, statistic.jumps, statistic.gamma );

			statistic.scanningOpt := statistic.jumps[MaxLenPos( statistic.gamma^, ALen )];
			LineToVec( statistic.Xstern[statistic.scanningOpt], res );

			vyLongrealVec.Add( vec, vec, res );  vyBase.Update( vec );  vyBase.ForUsersHandle( vec, msg );
			vyLongrealVec.CopyToArray( vec, vecArray^ );

			FOR i := 0 TO N - 1 DO statistic.data^[i] := inputArray^[i] - vecArray^[i] END;
			vyLongrealVec.CopyToVec( statistic.data^, degraded( vyLongrealVec.tVector ), N, 0, 0 );

			(*Computation of the multiresolution coefficents*)

			mad := MAD( input( vyLongrealVec.tVector ) );

			MultiCoefficients( inputArray^, vecArray^, Coeff );

			toobig := FALSE;
			(*
		If one of the coefficients is bigger than the bound, then we set toobig equal to TRUE and kstern equal to the the number of jumps jumps[i]
		and pass to the next number of jumps
		*)

			estimatedsigma := mad * 1.4826;

			j := 1;
			WHILE ((j <= N) & ~toobig) DO
				k := 1;
				WHILE ((k <= j) & ~toobig) DO
					IF (ABS( Coeff^[k - 1][j - 1] ) > (estimatedsigma * const)) THEN
						toobig := TRUE;   (* ksterndl := jumps^[i] *)
					END;
					INC( k )
				END;
				INC( j )
			END;

			INC( alarm );
			IF alarm > 100 THEN RETURN END

		END  (*of WHILE*)

	END DoIterativePotts;

	PROCEDURE MakeIterativePotts*;
	VAR degraded: vyBase.Object;  vec, res: vyBase.Object;
		vecname, resname: ARRAY 64 OF CHAR;
		type: INTEGER;  factor: LONGREAL;
	BEGIN
		antsCommands.InitScan( "data=OBJ (vec=OBJ | (vec=NAME res=NAME |create))" );
		IF antsCommands.ExpectObject( "data", degraded ) & antsCommands.GetObject( "vec", vec ) & antsCommands.GetObject( "res", res ) THEN
		ELSIF antsCommands.ExpectName( "vec", vecname ) & antsCommands.ExpectName( "res", resname ) & antsCommands.Find( "create" ) THEN
			IF vec = NIL THEN
				vec := vyLongrealVec.New( vyLongrealVec.Len( degraded( vyLongrealVec.tVector ) ) );
				vyName.RegisterNamed( vec, vecname );
			END;
			IF res = NIL THEN
				res := vyLongrealVec.New( vyLongrealVec.Len( degraded( vyLongrealVec.tVector ) ) );
				vyName.RegisterNamed( res, resname )
			END;
		ELSE RETURN
		END;

		IF antsCommands.Find( "median" ) THEN type := cMedian
		ELSIF antsCommands.Expect( "mean" ) THEN type := cMean
		END;

		vyLongrealVec.Fill( vec( vyLongrealVec.tVector ), 0, 0, vyLongrealVec.Len( degraded( vyLongrealVec.tVector ) ) );

		(*additional parameters ***)
		IF ~antsCommands.ExpectReal( "factor", factor ) THEN RETURN END;

		DoIterativePotts( degraded, vec( vyLongrealVec.tVector ), res( vyLongrealVec.tVector ), type, factor );

	END MakeIterativePotts;


(*
To plot the estimated variances only for reconstruction which appear in the gamma-scanning
*)
	PROCEDURE VarianceCurve*;
	VAR statistic: StatisticObj;  sobj, obj: vyBase.Object;  curve: vyBase.Object;
		name: ARRAY 64 OF CHAR;
		VarEstOnly: antsArrays.X1d;  gammalen: LONGINT;  type: INTEGER;
	BEGIN
		antsCommands.InitScan( "statistic=OBJ (curve=OBJ | (curve=NAME >create) )" );

		IF antsCommands.ExpectObject( "statistic", sobj ) THEN
			statistic := sobj( StatisticObj );  antsBellman.gammaScanning( statistic.Bellman, statistic.jumps, statistic.gamma )
		ELSE RETURN
		END;

		gammalen := antsArrays.FindFirstX( sobj( StatisticObj ).gamma^, 0 );  aM.SI( "Number of gamma-intervals in scanning = ", gammalen );

		IF antsCommands.GetObject( "curve", curve ) THEN vyLongrealVec.SetLen( curve( vyLongrealVec.tVector ), gammalen )
		ELSIF antsCommands.ExpectName( "curve", name ) & antsCommands.Find( "create" ) THEN
			curve := vyLongrealVec.New( gammalen );  vyName.RegisterNamed( curve, name )
		ELSE RETURN
		END;

		(*asking for the kind of variance estimator to be taken*)
		MLOrNot( type );

		VarianceEstimatorScanning( type, statistic.data, statistic.Xstern, statistic.jumps, statistic.gamma, gammalen,
													   VarEstOnly );
		LineToVec( VarEstOnly^, curve )
	END VarianceCurve;

	PROCEDURE Integrate*;
	VAR obj1, obj2: vyBase.Object;
	BEGIN
		antsCommands.InitScan( "degraded=OBJ integrated=OBJ" );
		IF antsCommands.ExpectObject( "degraded", obj1 ) & antsCommands.ExpectObject( "integrated", obj2 ) THEN
			antsVecOpt.PartialSums( obj1( vyBase.tVector ), obj2( vyBase.tVector ) )
		END
	END Integrate;

	PROCEDURE MakeModiMatrix*;
	VAR slicename, matrixname: ARRAY 64 OF CHAR;
		dimx, dimy: LONGINT;  Matrix: antsArrays.X2d;  columns: LONGINT;  from, to: LONGINT;  type: INTEGER;  offset: LONGINT;  R: antsReadWrite.Rider;
	BEGIN
		antsCommands.InitScan( "slice=STR nx=INT ny=INT matrix=STR [from=INT to=INT] [offset=INT] (>median|>mean)" );

		IF antsCommands.ExpectString( "slice", slicename ) &  (*one slice of the brain data*)
		antsCommands.ExpectNumber( "nx", dimx ) & antsCommands.ExpectNumber( "ny", dimy ) &  (*dimensions*)
		antsCommands.ExpectString( "matrix", matrixname ) (*matrix with the number of modi for the time series of each pixel*)
		THEN
			antsSecurity.SetProgress( 0 );
			IF ~R.Old( slicename ) THEN RETURN END;
			R.ReadType;  R.ReadX2d( Matrix );  columns := LEN( Matrix[0] );  R.Close
		ELSE RETURN
		END;

		IF ~(antsCommands.GetNumber( "from", from ) & antsCommands.GetNumber( "to", to )) THEN
			from := 5;  to := 13;  aM.S( "Minimum and maximum length of a plateau set to 5 resp 13" )
			(*the minimum resp maximum length of a plateau when it should be counted as a mode*)
		ELSE RETURN
		END;

		(*for the brain data the offset should be 3 *)
		IF ~antsCommands.GetNumber( "offset", offset ) THEN offset := 0;  aM.S( "no offset" ) ELSE aM.vSI( "offset= ", offset ) END;

		IF antsCommands.Find( "median" ) THEN type := cMedian
		ELSIF antsCommands.Find( "mean" ) THEN type := cMean
		ELSIF antsCommands.Find( "hampel" ) THEN type := cHampel
		ELSIF antsCommands.Find( "saegezahn" ) THEN type := cSaegezahn
		ELSIF antsCommands.Expect( "huber" ) THEN type := cHuber
		END;

		DoModiMatrix( columns, offset, dimx, dimy, Matrix, type, from, to, matrixname )
	END MakeModiMatrix;

	PROCEDURE DoModiMatrix( columns, offset: LONGINT;  dimx, dimy: LONGINT;  Matrix: antsArrays.X2d;  type: INTEGER;  from, to: LONGINT;
											   matrixname: ARRAY OF CHAR );
	VAR pixeldata: vyLongrealVec.tVector;  nx, ny, t, rownum: LONGINT;  statistic: StatisticObj;  vec: vyBase.Object;  modi: LONGINT;
		OrderMatrix: antsArrays.I2d;  R: antsReadWrite.Rider;
	BEGIN
		NEW( OrderMatrix, dimx, dimy );  pixeldata := vyLongrealVec.New( columns - offset );

		FOR nx := 0 TO dimx - 1 DO
			aM.SI( "nx", nx );  aM.S( "" );

			FOR ny := 0 TO dimy - 1 DO

				rownum := nx * dimy + ny;

				(* reading in time series of pixel (ny,nx) *)
				FOR t := offset TO columns - 1 DO vyLongrealVec.Set( Matrix[rownum, t], pixeldata, t - offset ) END;

				NEW( statistic );  statistic.s := NIL;  statistic.rstern := NIL;  statistic.Xstern := NIL;  statistic.Bellman := NIL;

				CreateStatistics( statistic, pixeldata, type );

				antsBellman.gammaScanning( statistic.Bellman, statistic.jumps, statistic.gamma );
				statistic.scanningOpt := statistic.jumps[MaxLenPos( statistic.gamma^, ALen )];
				vec := vyLongrealVec.New( LEN( statistic.data ) );  LineToVec( statistic.Xstern[statistic.scanningOpt], vec );
				modi := antsArrays.CountModi( vec( vyLongrealVec.tVector ), from, to );

				(* number of modi of pixel (ny,nx) *)
				OrderMatrix[nx][ny] := SHORT( modi )
			END
		END;
		R.ForceNew( matrixname );
		R.SetAscii;   (* remove if binary preferred *)
		R.WriteType;  R.WriteI2d( OrderMatrix );  R.Close
	END DoModiMatrix;

	PROCEDURE DoRecursiveScanning( degraded: vyBase.Object;  vec, res: vyLongrealVec.tVector;  type: INTEGER );
	VAR i, N: LONGINT;  alarm: LONGINT;  ch: CHAR;  msg: vyPort.AdjustCoordMsg;  NumOfJumps: LONGINT;  lastval: LONGREAL;  statistic: StatisticObj;
	BEGIN
		alarm := 0;  Input.Read( ch );

		WHILE (ch # "x") DO

			NEW( statistic );  statistic.s := NIL;  statistic.rstern := NIL;  statistic.Xstern := NIL;  statistic.Bellman := NIL;

			CreateStatistics( statistic, degraded, type );

			N := LEN( statistic.data );

			antsBellman.gammaScanning( statistic.Bellman, statistic.jumps, statistic.gamma );

			statistic.scanningOpt := statistic.jumps[MaxLenPos( statistic.gamma^, ALen )];
			LineToVec( statistic.Xstern[statistic.scanningOpt], res );

			vyLongrealVec.Add( vec, vec, res );  vyBase.Update( vec );  vyBase.ForUsersHandle( vec, msg );

			lastval := vyLongrealVec.Get( vec, 0 );  NumOfJumps := 0;
			FOR i := 1 TO N - 1 DO
				IF lastval # vyLongrealVec.Get( vec, i ) THEN lastval := vyLongrealVec.Get( vec, i );  INC( NumOfJumps ) END
			END;

			aM.vSI( "NumOfJumps curent:", NumOfJumps );  aM.vSR( "last Gamma value:", statistic.gamma[0] );  aM.vS( "****************************" );

			FOR i := 0 TO N - 1 DO statistic.data[i] := statistic.data[i] - statistic.Xstern[statistic.scanningOpt][i] END;
			vyLongrealVec.CopyToVec( statistic.data^, degraded( vyLongrealVec.tVector ), N, 0, 0 );

			Input.Read( ch );  INC( alarm );
			IF alarm > 100 THEN RETURN END
		END
	END DoRecursiveScanning;

	PROCEDURE sgn*( x: LONGREAL ): INTEGER;
	VAR number: INTEGER;
	BEGIN
		IF x > 0 THEN number := 1
		ELSIF x < 0 THEN number := -1
		ELSE number := 0
		END;
		RETURN number;
	END sgn;

	PROCEDURE MaxRun( x: ARRAY OF LONGREAL ): LONGINT;
	VAR i, N: LONGINT;  runlength: LONGINT;  last, this: INTEGER;  startpoint: LONGINT;  len: LONGINT;
	CONST invalid = -1;
	BEGIN
		N := LEN( x );  runlength := 1;  len := 1;  last := sgn( x[0] );
		FOR i := 1 TO N - 1 DO
			this := sgn( x[i] );
			IF this = last THEN INC( len ) ELSE
				IF len > runlength THEN runlength := len END;
				len := 1;
			END;
			last := this;
		END;
		RETURN runlength;
	END MaxRun;

	PROCEDURE RecursiveScanning*;
	VAR degraded: vyBase.Object;  vec, res: vyBase.Object;
		vecname, resname: ARRAY 64 OF CHAR;
		type: INTEGER;
	BEGIN
		antsCommands.InitScan( "data=OBJ (vec=OBJ | (vec=NAME res=NAME |create))" );
		IF antsCommands.ExpectObject( "data", degraded ) & antsCommands.GetObject( "vec", vec ) & antsCommands.GetObject( "res", res ) THEN
		ELSIF antsCommands.GetName( "vec", vecname ) & antsCommands.GetName( "res", resname ) & antsCommands.Find( "create" ) THEN
			IF vec = NIL THEN
				vec := vyLongrealVec.New( vyLongrealVec.Len( degraded( vyLongrealVec.tVector ) ) );
				vyName.RegisterNamed( vec, vecname );
			END;
			IF res = NIL THEN
				res := vyLongrealVec.New( vyLongrealVec.Len( degraded( vyLongrealVec.tVector ) ) );
				vyName.RegisterNamed( res, resname )
			END
		ELSE RETURN
		END;

		IF antsCommands.Find( "median" ) THEN type := cMedian
		ELSIF antsCommands.Find( "mean" ) THEN type := cMean
		ELSIF antsCommands.Find( "hampel" ) THEN type := cHampel
		ELSIF antsCommands.Find( "saegezahn" ) THEN type := cSaegezahn
		ELSIF antsCommands.Expect( "huber" ) THEN type := cHuber
		END;

		vyLongrealVec.Fill( vec( vyLongrealVec.tVector ), 0, 0, vyLongrealVec.Len( degraded( vyLongrealVec.tVector ) ) );

		vyHostTexts.DoOpenLog( "Recursive Scanning" );  vyHostTexts.SetCaret;  ViewVector( degraded( vyLongrealVec.tVector ), "antsPointPlot" );
		ViewVector( vec( vyLongrealVec.tVector ), "LinePlot" );  ViewVector( res( vyLongrealVec.tVector ), "LinePlot" );

		DoRecursiveScanning( degraded, vec( vyLongrealVec.tVector ), res( vyLongrealVec.tVector ), type )
	END RecursiveScanning;

	PROCEDURE EmpiricalVariance*;
	VAR obj1: vyBase.Object;  variance: LONGREAL;
		(*N, *) n: LONGINT;  vv2, vv: vyLongrealVec.tVector;
		varname, gammaname: ARRAY 64 OF CHAR;
		type, type2: INTEGER;
	BEGIN
		antsCommands.InitScan( "data=OBJ var=REAL samples=INT varvec=NAME gammavec=NAME (>median|>mean) [>abs|>log]" );
		IF antsCommands.ExpectObject( "data", obj1 ) & antsCommands.ExpectReal( "var", variance ) &
		    antsCommands.ExpectNumber( "samples", n ) & antsCommands.ExpectName( "varvec", varname ) &
		    antsCommands.ExpectName( "gammavec", gammaname ) THEN
			(* N := vyLongrealVec.Len( obj1( vyLongrealVec.tVector ) ); *)
			vv2 := vyLongrealVec.New( 0 );  vyName.RegisterNamed( vv2, varname );  vv := vyLongrealVec.New( 0 );
			vyName.RegisterNamed( vv, gammaname )
		ELSE RETURN
		END;

		IF antsCommands.Find( "median" ) THEN type := cMedian
		ELSIF antsCommands.Find( "mean" ) THEN type := cMean
		ELSIF antsCommands.Find( "hampel" ) THEN type := cHampel
		ELSIF antsCommands.Find( "saegezahn" ) THEN type := cSaegezahn
		ELSIF antsCommands.Expect( "huber" ) THEN type := cHuber
		END;

		IF antsCommands.Find( "abs" ) THEN type2 := cAbs
		ELSIF antsCommands.Find( "log" ) THEN type2 := cLog
		ELSE type2 := cAbs
		END;

		DoEmpiricalVariance( obj1, variance, n, type, type2, vv2, vv )
	END EmpiricalVariance;

	PROCEDURE DoEmpiricalVariance( obj1: vyBase.Object;  variance: LONGREAL;  n: LONGINT;  type, type2: INTEGER;  vv2, vv: vyLongrealVec.tVector );
	VAR i, m, N: LONGINT;  statistic: StatisticObj;  gammalen: LONGINT;  obj2: vyBase.Object;
	BEGIN
		N := vyLongrealVec.Len( obj1( vyLongrealVec.tVector ) );  obj2 := vyLongrealVec.New( N );
		FOR i := 1 TO n DO
		(* Out.Int(i, 5); Out.Ln(); *)
			aM.SI( " ", i );  aM.S( "" );  antsVecOpt.DoAddGaussNoise( obj1( vyBase.tVector ), obj2( vyBase.tVector ), 0, variance );

			NEW( statistic );  statistic.s := NIL;  statistic.rstern := NIL;  statistic.Xstern := NIL;  statistic.Bellman := NIL;

			CreateStatistics( statistic, obj2, type );

			antsBellman.gammaScanning( statistic.Bellman, statistic.jumps, statistic.gamma );

			(*append the estimated variance for the largest gamma-interval*)
			IF type2 = cAbs THEN
				statistic.scanningOpt := statistic.jumps[MaxLenPos( statistic.gamma^, ALen )];
				vyLongrealVec.Append( 1 / LEN( statistic.data ) * statistic.Bellman[statistic.scanningOpt][LEN( statistic.data ) - 1], vv2 )
			ELSE
				statistic.scanningLogOpt := statistic.jumps[MaxLenPos( statistic.gamma^, ARatio )];
				vyLongrealVec.Append( 1 / LEN( statistic.data ) * statistic.Bellman[statistic.scanningLogOpt][LEN( statistic.data ) - 1],
													   vv2 )
			END;
			(*
		(*append the estimated variance for the largest gamma-interval*)
		vyLongrealVec.Append( 1 / LEN(statistic.data) * statistic.Bellman[statistic.scanningOpt][LEN(statistic.data) - 1] , vv2 );
		*)

			gammalen := antsArrays.FindFirstX( statistic.gamma^, 0 );
			(* collect all gamma-values in vv *)
			FOR m := 0 TO gammalen - 1 DO vyLongrealVec.Append( statistic.gamma[m], vv ) END;
			(* collect only the first gamma in vv *)
			(* vyLongrealVec.Append( statistic.gamma[0], vv ); *)
		END;
		aM.S( "okay" )
	END DoEmpiricalVariance;
(****)
	PROCEDURE DoConsistencySimulation( obj1: vyBase.Object;  variance: LONGREAL;  n: LONGINT;  gamma: LONGREAL;
																  heightvec, posvec: vyLongrealVec.tVector );
	VAR i, j, k, N: LONGINT;  statistic: StatisticObj;  obj2: vyBase.Object;  rstern: antsArrays.I1d;  rek: antsArrays.X1d;
		bellman: antsArrays.X1d;  maxjump: LONGREAL;  maxpos: LONGINT;  vec2: vyBase.Object;
		(*stat: antsBellman.Statistic;*)
	BEGIN
		(*vyHostTexts.DoOpenLog("ViewReko"); vyHostTexts.SetCaret;*)

		N := vyLongrealVec.Len( obj1( vyLongrealVec.tVector ) );  obj2 := vyLongrealVec.New( N );  aM.SI( "length of data=", N );
		FOR i := 1 TO n DO
			aM.SI( " ", i );  aM.S( "" );  antsVecOpt.DoAddGaussNoise( obj1( vyBase.tVector ), obj2( vyBase.tVector ), 0, variance );
			(*ViewVector(obj2(vyLongrealVec.tVector),"antsPointPlot");*)

			NEW( statistic );
			statistic.s := NIL;   (* statistic.rstern := NIL; statistic.Xstern := NIL; statistic.Bellman := NIL; *)
			statistic.jumps := NIL;  statistic.gamma := NIL;  statistic.reko := NIL;

			CreateScaledStatisticsGamma( statistic, obj2, gamma );
			(*ViewArray(statistic.reko^,"vyLinePlot","reko");*)

			vec2 := obj2( vyLongrealVec.tVector );  vyLongrealVec.SetLen( vec2( vyLongrealVec.tVector ), N );
			vyLongrealVec.CopyToVec( statistic.reko^, vec2( vyLongrealVec.tVector ), N, 0, 0 );  vyBase.Update( vec2 );
			(*ViewVector(vec2(vyLongrealVec.tVector),"LinePlot");*)

			LargestJumpPos( vec2, maxjump, maxpos );

			(***************)

			(*append maxjump to vector heightvec*)
			vyLongrealVec.Append( maxjump, heightvec );

			vyLongrealVec.Append( maxpos, posvec );


			(* **********
		IF type2 = cAbs THEN
		 statistic.scanningOpt := statistic.jumps[MaxLenPos(statistic.gamma^, ALen)];
		 vyLongrealVec.Append( 1 / LEN(statistic.data) * statistic.Bellman[statistic.scanningOpt][LEN(statistic.data) - 1] , vv2 )
		ELSE
		 statistic.scanningLogOpt := statistic.jumps[MaxLenPos(statistic.gamma^, ARatio)];
		 vyLongrealVec.Append( 1 / LEN(statistic.data) * statistic.Bellman[statistic.scanningLogOpt][LEN(statistic.data) - 1] , vv2 )
		END;
	(*
		(*append the estimated variance for the largest gamma-interval*)
		vyLongrealVec.Append( 1 / LEN(statistic.data) * statistic.Bellman[statistic.scanningOpt][LEN(statistic.data) - 1] , vv2 );
	*)

		gammalen := antsArrays.FindFirstX( statistic.gamma^, 0 );
		(* collect all gamma-values in vv *)
		FOR m := 0 TO gammalen - 1 DO vyLongrealVec.Append( statistic.gamma[m], vv ) END;
		(* collect only the first gamma in vv *)
		(* vyLongrealVec.Append( statistic.gamma[0], vv ); *)
*************)
		END;
		aM.S( "okay" )
	END DoConsistencySimulation;
(* *******************Simulation für fixiertes Gamma**********************************************************)
	PROCEDURE ConsistencySimulation*;
	VAR obj1: vyBase.Object;  variance: LONGREAL;  n: LONGINT;  heightvec, posvec: vyLongrealVec.tVector;
		heightname, positionname: ARRAY 64 OF CHAR;
		gamma: LONGREAL;
	BEGIN
		antsCommands.InitScan( "data=OBJ var=REAL gamma=REAL samples=INT heightvec=NAME positionvec=NAME" );
		IF antsCommands.ExpectObject( "data", obj1 ) & antsCommands.ExpectReal( "var", variance ) &
		    antsCommands.ExpectReal( "gamma", gamma ) & antsCommands.ExpectNumber( "samples", n ) &
		    antsCommands.ExpectName( "heightvec", heightname ) & antsCommands.ExpectName( "positionvec", positionname ) THEN
			(* N := vyLongrealVec.Len( obj1( vyLongrealVec.tVector ) ); *)
			heightvec := vyLongrealVec.New( 0 );  vyName.RegisterNamed( heightvec, heightname );
			posvec := vyLongrealVec.New( 0 );  vyName.RegisterNamed( posvec, positionname )
		ELSE RETURN
		END;
		aM.SI( "n=", n );  DoConsistencySimulation( obj1, variance, n, gamma, heightvec, posvec )
	END ConsistencySimulation;

	PROCEDURE EmpiricalGamma*;
	VAR obj1, obj2: vyBase.Object;  variance: LONGREAL;  N, n: LONGINT;  vv1, vv2, vv3: vyLongrealVec.tVector;  type, type2: INTEGER;
		gammavecname, numbervecname, partivecname: ARRAY 64 OF CHAR;
		this, old: Texts.Text;
	BEGIN
		antsCommands.InitScan( "signal=OBJ var=REAL samples=INT gammavec=NAME [numbervec=NAME] [lengthvec=NAME] (>median|>mean) (>abs|>log) [>silent]" );
		IF antsCommands.ExpectObject( "signal", obj1 ) & antsCommands.ExpectReal( "var", variance ) &
		    antsCommands.ExpectNumber( "samples", n ) & antsCommands.ExpectName( "gammavec", gammavecname ) THEN
			IF antsCommands.GetName( "numbervec", numbervecname ) THEN
				vv1 := vyLongrealVec.New( 0 );  vyName.RegisterNamed( vv1, numbervecname )
			ELSE numbervecname := ""
			END;
			IF antsCommands.GetName( "lengthvec", partivecname ) THEN
				vv3 := vyLongrealVec.New( 0 );  vyName.RegisterNamed( vv3, partivecname )
			ELSE partivecname := ""
			END;
			vv2 := vyLongrealVec.New( 0 );  vyName.RegisterNamed( vv2, gammavecname );
			N := vyLongrealVec.Len( obj1( vyLongrealVec.tVector ) );  aM.SI( "length of data: ", N );  obj2 := vyLongrealVec.New( N )
		ELSE RETURN
		END;

		IF antsCommands.Find( "median" ) THEN type := cMedian
		ELSIF antsCommands.Find( "mean" ) THEN type := cMean
		ELSIF antsCommands.Find( "hampel" ) THEN type := cHampel
		ELSIF antsCommands.Find( "saegezahn" ) THEN type := cSaegezahn
		ELSIF antsCommands.Expect( "huber" ) THEN type := cHuber
		END;

		IF antsCommands.Find( "abs" ) THEN type2 := cAbs
		ELSIF antsCommands.Expect( "log" ) THEN type2 := cLog
		END;

		IF antsCommands.Find( "silent" ) THEN NEW( this );  Texts.Open( this, "mylog" );  old := vyHostTexts.Log;  vyHostTexts.Log := this
		END;

		DoEmpiricalGamma( obj1, obj2, variance, n, type, type2, vv2, gammavecname, vv1, numbervecname, vv3,
										   partivecname );

		IF antsCommands.Find( "silent" ) THEN vyHostTexts.Log := old
		END
	END EmpiricalGamma;

(*
This procedure takes the signal and adds Gaussian Noise with mean zero and variance var.
Then it computes the statistic and and does the gamma-scanning. From the gamma-vector it computes the ratio/difference of two subsequent gammas
and write this into lens. From this vector the mean and the sum of squares are computed. The largest gamma is written into gamma0vector.
This whole procedure is repeated with the signal n times. The gamma_vector could then plotted as histogram to get an idea of the distribution of gamma0.
*)
	PROCEDURE DoEmpiricalGamma( obj1, obj2: vyBase.Object;  variance: LONGREAL;  n: LONGINT;  type, type2: INTEGER;  vv2: vyLongrealVec.tVector;
													    vecname: ARRAY OF CHAR;  intervalnumbervec: vyLongrealVec.tVector;
													    numbervecname: ARRAY OF CHAR;  partivec: vyLongrealVec.tVector;  partivecname: ARRAY OF CHAR );
	VAR i, j: LONGINT;  statistic: StatisticObj;  mean, ssq, median: LONGREAL;  maxjump: LONGREAL;  lens: antsArrays.X1d;  nrNaNs: LONGINT;  maxjumpPos: LONGINT;
		gammalen: LONGINT;  gammaneu: antsArrays.X1d;  vv2array, partiarray, numberarray: antsArrays.X1d;
		R: antsReadWrite.Rider;  min, max: LONGREAL;  N: LONGINT;
	BEGIN
		N := vyLongrealVec.Len( obj1( vyBase.tVector ) );
		FOR i := 1 TO n DO  (* Out.Int( i, 5 ); Out.Ln(); *)
			aM.SI( " ", i );  aM.S( "" );  antsVecOpt.DoAddGaussNoise( obj1( vyBase.tVector ), obj2( vyBase.tVector ), 0, variance );

			NEW( statistic );  statistic.s := NIL;  statistic.rstern := NIL;  statistic.Xstern := NIL;  statistic.Bellman := NIL;

			CreateStatistics( statistic, obj2, type );

			antsBellman.gammaScanning( statistic.Bellman, statistic.jumps, statistic.gamma );

			IF type2 = cAbs THEN
				gammalen := antsArrays.FindFirstX( statistic.gamma^, 0 ) + 1;  NEW( gammaneu, gammalen );
				FOR j := 0 TO gammalen - 1 DO gammaneu^[j] := statistic.gamma^[j] END;
				maxjumpPos := MaxPosArrayFunction( gammaneu^, lens, ALen, maxjump )
			ELSIF type2 = cLog THEN
				gammalen := antsArrays.FindFirstX( statistic.gamma^, 0 );  NEW( gammaneu, gammalen );
				FOR j := 0 TO gammalen - 1 DO gammaneu^[j] := statistic.gamma^[j] END;
				maxjumpPos := MaxPosArrayFunction( gammaneu^, lens, ARatio, maxjump )
			END;

			vyLongreal.MeanSSq( LEN( lens ), lens^, 0, mean, ssq, nrNaNs );

			median := antsArrays.Median1dX( lens^, LEN( lens ) );

			IF type2 = cAbs THEN aM.vSR( "mean difference:", mean );  aM.vS( "" );  aM.vSR( "median of the differences:", median );  aM.vS( "" )
			ELSIF type2 = cLog THEN aM.vSR( "mean ratio:", mean );  aM.vS( "" )
			END;

			statistic.scanningOpt := statistic.jumps[maxjumpPos];

			aM.vSI( "number of intervals in scanning:", statistic.scanningOpt + 1 );

			(*The lengths of the intervals in the optimal partition *)
			IF partivec # NIL THEN
				FOR j := 0 TO statistic.scanningOpt DO
					vyLongrealVec.Append( statistic.InterLength[j][statistic.scanningOpt], partivec )
				END
			END;

			vyLongrealVec.Append( 1 / N * statistic.gamma^[0], vv2 );  aM.vSR( "largest gamma", statistic.gamma^[0] );  aM.vS( "" );

			(*To get an idea how the number of intervals in the optimal partition behaves with increasing length N of data*)
			IF intervalnumbervec # NIL THEN vyLongrealVec.Append( statistic.scanningOpt + 1, intervalnumbervec ) END

		END;

		(* mean of gamma_0 *)
		vyLongrealVec.GetMeanSsq( vv2, mean, ssq, nrNaNs );  aM.SR( "empirical mean of gamma_0: ", mean );  aM.S( "" );  aM.SR( "empirical variance of gamma_0: ", ssq / (LEN( statistic.data ) - 1) );

		(*
	(*"Estimate" the support of the gamma0-distribution by taking minimum and maximum of the gamma0 *)
	vyLongrealVec.GetMinMax (vv2,min, max,nrNaNs);
	aM.vSI("support bei N= ", LEN(statistic.data)); aM.vSR(" ",max-min);
	*)

		(** To save the resulting gamma0-vector in a file**)

		IF ((vv2 # NIL ) & (vecname # "")) THEN
			IF (vv2array = NIL ) OR (LEN( vv2array ) # vyLongrealVec.Len( vv2( vyLongrealVec.tVector ) )) THEN
				NEW( vv2array, vyLongrealVec.Len( vv2( vyLongrealVec.tVector ) ) )
			END;
			vyLongrealVec.CopyToArray( vv2( vyLongrealVec.tVector ), vv2array^ );  R.ForceNew( vecname );
			R.SetAscii;   (* remove if binary preferred *)
			R.WriteType;  R.WriteX1d( vv2array );  R.Close
		END;

		(** To save the resulting interlength-vector in a file**)
		IF (partivec # NIL ) & (partivecname # "") THEN
			IF (partiarray = NIL ) OR (LEN( partiarray ) # vyLongrealVec.Len( partivec( vyLongrealVec.tVector ) )) THEN
				NEW( partiarray, vyLongrealVec.Len( partivec( vyLongrealVec.tVector ) ) )
			END;
			vyLongrealVec.CopyToArray( partivec( vyLongrealVec.tVector ), partiarray^ );  R.ForceNew( partivecname );
			R.SetAscii;   (* remove if binary preferred *)
			R.WriteType;  R.WriteX1d( partiarray );  R.Close
		END;

		(** To save the resulting number-vector in a file**)
		IF (intervalnumbervec # NIL ) & (numbervecname # "") THEN
			IF (numberarray = NIL ) OR (LEN( numberarray ) # vyLongrealVec.Len( intervalnumbervec( vyLongrealVec.tVector ) )) THEN
				NEW( numberarray, vyLongrealVec.Len( intervalnumbervec( vyLongrealVec.tVector ) ) )
			END;
			vyLongrealVec.CopyToArray( intervalnumbervec( vyLongrealVec.tVector ), numberarray^ );
			R.ForceNew( numbervecname );
			R.SetAscii;   (* remove if binary preferred *)
			R.WriteType;  R.WriteX1d( numberarray );  R.Close
		END;

		aM.S( "okay" )

	END DoEmpiricalGamma;

	PROCEDURE UpdateMSSQ( val: LONGREAL;  at: LONGINT;  VAR mean, var: LONGREAL );
	VAR diff: LONGREAL;
	BEGIN
		diff := val - mean;  mean := mean + diff / at;  var := var + diff * (val - mean)
	END UpdateMSSQ;

(*
Survey of different properties of the gamma values in the scanning
*)
	PROCEDURE DoGammaStatistics( from, to, step, n, jumps1: LONGINT;  variance: LONGREAL;  type: INTEGER );
	VAR minmean, maxmean, meanmean, minvar, maxvar, meanvar, MeanLenMean, MeanLenVar, max2mean, max2var: LONGREAL;
		i, j, k: LONGINT;  statistic: StatisticObj;  lengamma: LONGINT;  truejumpInter: LONGINT;  IntervalLen, TrueIntervalLen: LONGREAL;
		min, max, max2, mean, Ratio, MeanLen: LONGREAL;  MaxInt, Max2Int: LONGREAL;
		minmeanvec, maxmeanvec, meanmeanvec, minvarvec, maxvarvec, meanvarvec, MeanLenMeanvec, MeanLenVarvec, max2meanvec, max2varvec: vyLongrealVec.tVector;
		len: LONGINT;  obj: vyBase.Object;  datavec: vyLongrealVec.tVector;
	BEGIN
		(*generation of vectors*)
		minmeanvec := vyLongrealVec.New( 0 );  maxmeanvec := vyLongrealVec.New( 0 );
		meanmeanvec := vyLongrealVec.New( 0 );  minvarvec := vyLongrealVec.New( 0 );
		maxvarvec := vyLongrealVec.New( 0 );  meanvarvec := vyLongrealVec.New( 0 );
		MeanLenMeanvec := vyLongrealVec.New( 0 );  MeanLenVarvec := vyLongrealVec.New( 0 );
		max2varvec := vyLongrealVec.New( 0 );  max2meanvec := vyLongrealVec.New( 0 );

		vyName.RegisterNamed( minmeanvec, "min" );  vyName.RegisterNamed( maxmeanvec, "max" );
		vyName.RegisterNamed( minvarvec, "minVar" );  vyName.RegisterNamed( maxvarvec, "maxVar" );
		vyName.RegisterNamed( meanmeanvec, "mean" );  vyName.RegisterNamed( meanvarvec, "meanVar" );
		vyName.RegisterNamed( MeanLenMeanvec, "len" );  vyName.RegisterNamed( MeanLenVarvec, "lenVar" );
		vyName.RegisterNamed( max2meanvec, "max2" );  vyName.RegisterNamed( max2varvec, "max2Var" );

		len := from;

		obj := vyName.FindObj( "data" );
		IF (obj = NIL ) THEN datavec := vyLongrealVec.New( 0 );  vyName.RegisterNamed( datavec, "data" )
		ELSE datavec := obj( vyLongrealVec.tVector );  vyLongrealVec.SetLen( datavec, 0 )
		END;

		(* increasing length of the signal *)
		WHILE (len <= to) DO
			aM.SI( "Step: ", len );

			(* init statistics for the gamma-intervals*)
			minmean := 0;  maxmean := 0;  meanmean := 0;  minvar := 0;  maxvar := 0;  meanvar := 0;  MeanLenMean := 0;
			MeanLenVar := 0;  max2var := 0;  max2mean := 0;


			(* n samples of the signal*)
			FOR j := 1 TO n DO

			(* generation of a signal with jumps1 jumps *)
				FOR i := 0 TO len - 1 DO
					IF vyLongrealVec.Len( datavec ) < (i + 1) THEN vyLongrealVec.Append( 0, datavec ) END;
					(*
				IF ENTIER(i/len*(jumps1+1)) MOD 2 = 0 THEN vyLongrealVec.Set(0,datavec,i) ELSE vyLongrealVec.Set(1,datavec,i)
				END;
				*)
					IF jumps1 = 0 THEN
						vyLongrealVec.Set( 0, datavec, i ) (*null signal*)
					ELSE
						vyLongrealVec.Set( ENTIER( i / len * (jumps1 + 1) ), datavec, i ) (*jumps of height 1 (staircase upwards)*)
					END
					(*
				IF i<len DIV 2 THEN
				vyLongrealVec.Set(0,datavec,i)
				ELSE
				vyLongrealVec.Set(1,datavec,i)
				END;
				*)
				END;

				(* noise signal*)
				antsVecOpt.DoAddGaussNoise( datavec, datavec, 0, variance );  vyBase.Update( datavec );

				NEW( statistic );  statistic.s := NIL;  statistic.rstern := NIL;  statistic.Xstern := NIL;  statistic.Bellman := NIL;

				CreateStatistics( statistic, datavec, type );

				antsBellman.gammaScanning( statistic.Bellman, statistic.jumps, statistic.gamma );
				statistic.scanningOpt := statistic.jumps[MaxLenPos( statistic.gamma^, ALen )];

				(*number of gamma-intervals*)
				lengamma := antsArrays.FindFirstX( statistic.gamma^, 0 );

				truejumpInter := -1;
				(* Computation of the statistics of the gamma-intervals for this sample *)
				FOR k := 0 TO lengamma DO
					IF statistic.jumps[k] = jumps1 THEN truejumpInter := k END
				END;

				IF truejumpInter = -1 THEN aM.vS( "true number of jumps not in scanning" )
				ELSE
					(*length of the gamma-interval with the true number of jumps*)
					TrueIntervalLen := statistic.gamma[truejumpInter - 1] - statistic.gamma[truejumpInter];  min := MAX( LONGREAL );
					max := MIN( LONGREAL );  mean := 0;  MaxInt := MIN( LONGREAL );  Max2Int := MIN( LONGREAL );
					FOR k := 0 TO lengamma - 1 DO
						IntervalLen := statistic.gamma[k] - statistic.gamma[k + 1];
						IF IntervalLen > MaxInt THEN
							IF MaxInt > Max2Int THEN Max2Int := MaxInt END;
							MaxInt := IntervalLen
						END;
						IF (IntervalLen > Max2Int) & (IntervalLen < MaxInt) THEN Max2Int := IntervalLen END;
						Ratio := TrueIntervalLen / IntervalLen;  mean := mean + 1 / Ratio;
						IF Ratio < min THEN min := Ratio END
						(* IF Ratio>max THEN max := Ratio END; *)
					END;
					max2 := Max2Int / MaxInt;  max := MaxInt / statistic.gamma[0];  mean := mean / lengamma;
					MeanLen := statistic.gamma[0] / lengamma;

					UpdateMSSQ( mean, j, meanmean, meanvar );  UpdateMSSQ( min, j, minmean, minvar );
					UpdateMSSQ( max, j, maxmean, maxvar );  UpdateMSSQ( MeanLen, j, MeanLenMean, MeanLenVar );
					UpdateMSSQ( max2, j, max2mean, max2var )
				END

			END;

			vyLongrealVec.Append( meanmean, meanmeanvec );  vyLongrealVec.Append( meanvar / n, meanvarvec );
			vyLongrealVec.Append( minmean, minmeanvec );  vyLongrealVec.Append( minvar / n, minvarvec );
			vyLongrealVec.Append( maxmean, maxmeanvec );  vyLongrealVec.Append( maxvar / n, maxvarvec );
			vyLongrealVec.Append( MeanLenMean, MeanLenMeanvec );
			vyLongrealVec.Append( MeanLenVar / n, MeanLenVarvec );  vyLongrealVec.Append( max2mean, max2meanvec );
			vyLongrealVec.Append( max2var / n, max2varvec );

			len := len + step
		END
	END DoGammaStatistics;

	PROCEDURE GammaStatistics*;
	VAR n: LONGINT;  variance: LONGREAL;  jumps1: LONGINT;  from, to, step: LONGINT;  type: INTEGER;
	BEGIN
		antsCommands.InitScan( "samples=INT var=REAL jumps=INT (>median|>mean) [from=INT to=INT step=INT]" );
		IF antsCommands.ExpectNumber( "samples", n ) & antsCommands.ExpectReal( "var", variance ) &
		    antsCommands.ExpectNumber( "jumps", jumps1 ) THEN
		ELSE RETURN
		END;

		IF antsCommands.Find( "median" ) THEN type := cMedian
		ELSIF antsCommands.Find( "mean" ) THEN type := cMean
		ELSIF antsCommands.Find( "hampel" ) THEN type := cHampel
		ELSIF antsCommands.Find( "saegezahn" ) THEN type := cSaegezahn
		ELSIF antsCommands.Expect( "huber" ) THEN type := cHuber
		END;

		IF antsCommands.GetNumber( "from", from ) & antsCommands.GetNumber( "to", to ) & antsCommands.GetNumber( "step", step ) THEN
			ASSERT ( step > 0 ) (* IF ~(step>0) THEN System.Trap() *)
		ELSE from := 0;  to := 100;  step := 10
		END;

		DoGammaStatistics( from, to, step, n, jumps1, variance, type )
	END GammaStatistics;
(*
(*
Survey of the reconstruction for fixed gamma for increasing length of the signal
*)
PROCEDURE DoFixedGammaStatistics (from, to, step, n, jumps1: LONGINT ; variance: LONGREAL; type: INTEGER );
VAR (*minmean, maxmean, meanmean, minvar, maxvar, meanvar, MeanLenMean, MeanLenVar, max2mean, max2var: LONGREAL; *)
i, j, k: LONGINT;
statistic: StatisticObj;
(*lengamma: LONGINT;
truejumpInter: LONGINT;
IntervalLen, TrueIntervalLen: LONGREAL;
min, max, max2, mean, Ratio, MeanLen: LONGREAL;
MaxInt, Max2Int: LONGREAL;
minmeanvec, maxmeanvec, meanmeanvec, minvarvec, maxvarvec, meanvarvec, MeanLenMeanvec, MeanLenVarvec,
max2meanvec, max2varvec: vyLongrealVec.tVector; *)
len: LONGINT;
obj: vyBase.Object;
datavec: vyLongrealVec.tVector;
BEGIN
len := from;
obj := vyName.FindObj( "data");
IF (obj = NIL ) THEN
datavec := vyLongrealVec.New( 0 ); vyName.RegisterNamed( datavec, "data")
ELSE datavec := obj( vyLongrealVec.tVector ); vyLongrealVec.SetLen( datavec, 0 )
END;

(* increasing length of the signal *)
WHILE (len <= to) DO
aM.SI( "Step: ", len );
(* n samples of the signal*)
FOR j := 1 TO n DO

(* generation of a signal with jumps1 jumps *)
FOR i := 0 TO len - 1 DO
IF vyLongrealVec.Len( datavec ) < (i + 1) THEN vyLongrealVec.Append( 0, datavec ) END;
(*
IF ENTIER(i/len*(jumps1+1)) MOD 2 = 0 THEN vyLongrealVec.Set(0,datavec,i) ELSE vyLongrealVec.Set(1,datavec,i)
END;
*)
IF jumps1=0 THEN vyLongrealVec.Set(0,datavec, i) (*null signal*)
ELSE
vyLongrealVec.Set( ENTIER( i / len * (jumps1 + 1) ), datavec, i ) (*jumps of height 1 (staircase upwards)*)
(*
IF i<len DIV 2 THEN
vyLongrealVec.Set(0,datavec,i)
ELSE
vyLongrealVec.Set(1,datavec,i)
END;
*)
END;
END;

(* noise signal*)
antsVecOpt.DoAddGaussNoise( datavec, datavec, 0, variance ); vyBase.Update( datavec );

(**************************)
(*aus PottsToVec*)
N := vyLongrealVec.Len(datavec);
NEW(data, N);
vyLongrealVec.CopyToArray(datavec, data^);

antsBellman.InitStatistic1d(globalS,N);

antsBellman.ComputeMeanStat1d(data^,globalS);

(* globalGamma := gamma; *)
antsBellman.Bellman(rstern, bellman, SHORT(N), 0, MAX(LONGINT), Function1d, - globalGamma);

antsBellman.Partition(rstern,data,statMean);

vyLongrealVec.SetLen(vec2, N);
vyLongrealVec.CopyToVec(data^, vec2, N, 0, 0);
vyBase.Update(vec1);
vyBase.Update(vec2);
(**************************)

END;
len := len + step
END
END DoFixedGammaStatistics;
*)


	PROCEDURE Regression( y: vyLongrealVec.tVector;  start, end: LONGINT;  VAR a, b, residuum: LONGREAL );
	VAR number, i: LONGINT;  sumsimple, sumwith, sumsquare: LONGREAL;
	BEGIN
		number := end - start + 1;

		sumsimple := 0;
		FOR i := 1 TO number DO sumsimple := sumsimple + vyLongrealVec.Get( y, i - 1 + (start - 1) ) END;
		sumwith := 0;
		FOR i := 1 TO number DO sumwith := sumwith + i * vyLongrealVec.Get( y, i - 1 + (start - 1) ) END;
		sumsquare := 0;
		FOR i := 1 TO number DO
			sumsquare := sumsquare + vyLongrealVec.Get( y, i - 1 + (start - 1) ) * vyLongrealVec.Get( y, i - 1 + (start - 1) )
		END;

		b := 12 / (number * (number + 1) * (number - 1)) * sumwith - 6 / (number * (number - 1)) * sumsimple;

		a := 1 / number * sumsimple - b / 2 * (number + 1);

		residuum := sumsquare - a * sumsimple + b * sumwith

	END Regression;

(*
procedure to compute the sum of squares for the regression with two linear regression curves
*)
	PROCEDURE SumofResiduals( y: vyLongrealVec.tVector;  knee: LONGINT;  VAR totalresi: LONGREAL );
	VAR N: LONGINT;  start, end: LONGINT;  a1, b1, a2, b2, resi1, resi2: LONGREAL;

	BEGIN
		N := vyLongrealVec.Len( y( vyLongrealVec.tVector ) );

		(* first linear regreesion with the first knee points**********)
		start := 1;  end := knee;  Regression( y, start, end, a1, b1, resi1 );


		(* second linear regression with the last N-knee +1 points**************)
		start := knee;  end := N;  Regression( y, start, end, a2, b2, resi2 );

		(*sum of the residuals **************************************)
		totalresi := resi1 + resi2

	END SumofResiduals;

(*
This procedure stores the residuals for an approximation to the time series by two linear fits with break point at k
*)
	PROCEDURE KneeCheck( Bellman: antsArrays.X2d;  VAR Vals: antsArrays.X1d );
	VAR k, N: LONGINT;  totalresi, a1, a2, b1, b2, resi1, resi2: LONGREAL;  BellmanVec: vyBase.Object;  Column: antsArrays.X1d;
	BEGIN
		N := LEN( Bellman^ );
		IF (Vals = NIL ) OR (LEN( Vals ) # N) THEN NEW( Vals, N ) END;
		IF (Column = NIL ) OR (LEN( Column ) # N) THEN NEW( Column, N ) END;
		BellmanVec := vyLongrealVec.New( N );

		GetColumn( Bellman^, N - 1, Column^ );
		vyLongrealVec.CopyToVec( Column^, BellmanVec( vyLongrealVec.tVector ), N, 0, 0 );

		Regression( BellmanVec( vyLongrealVec.tVector ), 1, N, a1, b1, resi1 );  Vals^[0] := resi1;
		Regression( BellmanVec( vyLongrealVec.tVector ), 1, N, a2, b2, resi2 );  Vals^[N - 1] := resi2;

		FOR k := 2 TO N - 1 DO SumofResiduals( BellmanVec( vyLongrealVec.tVector ), k, totalresi );  Vals^[k - 1] := totalresi END
	END KneeCheck;

(* **********************************************************************************************************************)

BEGIN
	aM.launch;
END antsPotts1DSurvey.




