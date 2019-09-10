MODULE antsPottsSimAdministration IN Oberon;

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


IMPORT antsArrays, vyBase, vyLongrealVec, antsVecOpt, antsPotts1DSurvey, antsTautString, antsSecurity, vyLongreal, antsBellman, antsPottsMonotone,
	antsReadWrite, antsPottsSimDataStructure, vyName, antsFunctions, Strings, MathL IN A2, Out;

CONST
	cMedian* = 0;  cMean* = 1;  cHampel* = 2;  cSaegezahn* = 3;  cHuber* = 4;  cTautString* = 5;

	cGauss* = 0;  cLaplace* = 1;  cExp* = 2;  cUniform* = 3;

	cAIC* = 0;  cAICEst* = 1;  cAICC* = 2;  cSIC* = 3;  cSICEst* = 4;  cSICC* = 5;  cMaxInterval* = 6;  cMaxIntervalLog* = 7;  cVarianceGain* = 8;
	cVarianceTest* = 9;  cKneeCheck* = 10;  cMultiCoeff* = 11;  cConstGamma* = 12;

	cEstimatedVariance* = 0;  cCountJumpsAtLoc* = 1;  cCountJumps* = 2;  cMAD* = 3;  cEstimatedL1Diff* = 4;  cEstimatedLUnendlDiff* = 5;

	cMedianMonotone* = 0;  cMeanMonotone* = 1;  cHampelMonotone* = 2;  cSaegezahnMonotone* = 3;  cHuberMonotone* = 4;

VAR
	globalStat: antsBellman.Statistic;  globalGamma: FLOAT64;

	PROCEDURE DoSetMonotone*( monotone: ARRAY OF CHAR ): SIGNED16;

	VAR type: SIGNED16;

	BEGIN
		IF monotone = "MeanMonotone" THEN type := cMedianMonotone;
		ELSIF monotone = "MedianMonotone" THEN type := cMeanMonotone;
		ELSIF monotone = "HampelMonotone" THEN type := cHampelMonotone;
		ELSIF monotone = "SaegezahnMonotone" THEN type := cSaegezahnMonotone;
		ELSIF monotone = "HuberMonotone" THEN type := cHuberMonotone;
		ELSE type := -1;
		END;

		RETURN type;
	END DoSetMonotone;

	PROCEDURE DoSetNoise*( noise: ARRAY OF CHAR ): SIGNED16;

	VAR type: SIGNED16;

	BEGIN
		IF noise = "Gauss" THEN type := cGauss;
		ELSIF noise = "Laplace" THEN type := cLaplace;
		ELSIF noise = "Exp" THEN type := cExp;
		ELSIF noise = "Uniform" THEN type := cUniform;
		ELSE type := -1;
		END;

		RETURN type;
	END DoSetNoise;

	PROCEDURE DoSetReko*( reko: ARRAY OF CHAR ): SIGNED16;

	VAR type: SIGNED16;

	BEGIN
		IF reko = "Mean" THEN type := cMean;
		ELSIF reko = "Median" THEN type := cMedian;
		ELSIF reko = "Huber" THEN type := cHuber;
		ELSIF reko = "Hampel" THEN type := cHampel;
		ELSIF reko = "Saegezahn" THEN type := cSaegezahn;
		ELSIF reko = "TautString" THEN type := cTautString;
		ELSE type := -1;
		END;

		RETURN type;
	END DoSetReko;

	PROCEDURE DoSetGamma*( gamma: ARRAY OF CHAR ): SIGNED16;

	VAR type: SIGNED16;

	BEGIN
		IF gamma = "AIC" THEN type := cAIC;
		ELSIF gamma = "AICEst" THEN type := cAICEst;
		ELSIF gamma = "AICC" THEN type := cAICC;
		ELSIF gamma = "SIC" THEN type := cSIC;
		ELSIF gamma = "SICEst" THEN type := cSICEst;
		ELSIF gamma = "SICC" THEN type := cSICC;
		ELSIF gamma = "MaxInterval" THEN type := cMaxInterval;
		ELSIF gamma = "MaxIntervalLog" THEN type := cMaxIntervalLog;
		ELSIF gamma = "VarianceGain" THEN type := cVarianceGain;
		ELSIF gamma = "VarianceTest" THEN type := cVarianceTest;
		ELSIF gamma = "KneeCheck" THEN type := cKneeCheck;
		ELSIF gamma = "MultiCoeff" THEN type := cMultiCoeff;
		ELSIF gamma = "ConstGamma" THEN type := cConstGamma;
		ELSE type := -1;
		END;

		RETURN type;
	END DoSetGamma;

	PROCEDURE DoReadData*( VAR set: antsPottsSimDataStructure.SetChain;  dataChainname, file: ARRAY OF CHAR );
	(* Einlesen von Daten. Monotones werden mitberechnet. *)

	VAR R: antsReadWrite.Rider;  rows, cols, i, k: SIGNED32;
		dataname, datacounter: ARRAY 1024 OF CHAR;
		dataarray, diffs, eN, meanM, medianM, hampelM, saegezahnM, huberM: antsArrays.X1d;  ok: BOOLEAN;  datavec: vyLongrealVec.tVector;

	BEGIN
		IF ~R.Old( file ) THEN ok := antsPottsSimDataStructure.DeleteDataset( set, dataChainname );  antsSecurity.Halt( "File not found !!!" );  END;

		R.ReadType;  R.ScanMatrix( rows, cols );  datavec := vyLongrealVec.New( cols );

		FOR i := 0 TO rows - 1 DO
			k := i + 1;  Strings.IntToStr( k, datacounter );  dataname := "Data";  Strings.Append( dataname, datacounter );  R.ReadRowX( datavec, 0 );

			IF datavec # NIL THEN
				NEW( dataarray, vyLongrealVec.Len( datavec ) );  vyLongrealVec.CopyToArray( datavec, dataarray^ );  NEW( diffs, 5 );  NEW( eN, 5 );
				DoMonotone( dataarray, meanM, "MeanMonotone" );  CalcDiffAndEN( dataarray, meanM, diffs[0], eN[0] );
				DoMonotone( dataarray, medianM, "MedianMonotone" );  CalcDiffAndEN( dataarray, medianM, diffs[1], eN[1] );
				DoMonotone( dataarray, hampelM, "HampelMonotone" );  CalcDiffAndEN( dataarray, hampelM, diffs[2], eN[2] );
				DoMonotone( dataarray, saegezahnM, "SaegezahnMonotone" );  CalcDiffAndEN( dataarray, saegezahnM, diffs[3], eN[3] );
				DoMonotone( dataarray, huberM, "HuberMonotone" );  CalcDiffAndEN( dataarray, huberM, diffs[4], eN[4] );
				antsPottsSimDataStructure.NewData( set, dataChainname, dataname, dataarray, diffs, eN, meanM, medianM, hampelM, saegezahnM, huberM );
			END;
		END;

		R.Close;
	END DoReadData;

	PROCEDURE DoMonotone*( x: antsArrays.X1d;  VAR y: antsArrays.X1d;  monotonetype: ARRAY OF CHAR );
	(* Berechnung der Monotones. *)

	VAR statistic: antsPotts1DSurvey.StatisticObj;  matrix: antsArrays.X2d;  type, len: SIGNED32;  vec1: vyBase.Object;

	BEGIN
		type := DoSetMonotone( monotonetype );  len := LEN( x );  vec1 := vyLongrealVec.New( len );
		vyLongrealVec.CopyToVec( x^, vec1( vyLongrealVec.tVector ), len, 0, 0 );  NEW( statistic );  antsPotts1DSurvey.CreateStatistics( statistic, vec1, type );
		antsBellman.gammaScanning( statistic.Bellman, statistic.jumps, statistic.gamma );
		antsPottsMonotone.MakeMatrix( statistic.Xstern, statistic.jumps, statistic.gamma, matrix );  NEW( y, len );
		antsPottsMonotone.LastMonotone( matrix, antsPottsMonotone.cDecr, y );
	END DoMonotone;

	PROCEDURE CalcDiffAndEN*( x: antsArrays.X1d;  y: antsArrays.X1d;  VAR diff: FLOAT64;  VAR eN: FLOAT64 );
	(* Berechnet die Differenz zwischen dem grössten und kleinsten Element. Estimated Noise wird mit dem MAD geschätzt. *)

	VAR dummy, i: SIGNED32;  z: antsArrays.X1d;

	BEGIN
		diff := Max( y, dummy ) - Min( y, dummy );  NEW( z, LEN( x ) );

		FOR i := 0 TO LEN( x ) - 1 DO z[i] := x[i] - y[i];  END;

		eN := Mad( z );
	END CalcDiffAndEN;

	PROCEDURE Mad( x: antsArrays.X1d ): FLOAT64;
	(* Berechnet den MAD. *)

	VAR len, i: SIGNED32;  y: antsArrays.X1d;  mad: FLOAT64;

	BEGIN
		len := LEN( x );  NEW( y, len - 1 );

		FOR i := 1 TO len - 1 DO y[i - 1] := (x[i] - x[i - 1]) / MathL.sqrt( 2 );  END;

		mad := antsArrays.Median1dX( y^, len - 1 );

		FOR i := 1 TO len - 1 DO y[i - 1] := ABS( y[i - 1] - mad );  END;

		mad := antsArrays.Median1dX( y^, len - 1 );  RETURN mad;
	END Mad;

	PROCEDURE Max*( x: antsArrays.X1d;  VAR m: SIGNED32 ): FLOAT64;
	(* Berechnet Maximum und gibt den Index mit zurück. *)

	VAR i: SIGNED32;  max: FLOAT64;

	BEGIN
		max := MIN( FLOAT64 );

		FOR i := 0 TO LEN( x ) - 1 DO
			IF x[i] > max THEN max := x[i];  m := i;  END;
		END;

		RETURN max;
	END Max;

	PROCEDURE Min*( x: antsArrays.X1d;  VAR m: SIGNED32 ): FLOAT64;
	(* Berechnet Minimum und gibt den Index mit zurück. *)

	VAR i: SIGNED32;  min: FLOAT64;

	BEGIN
		min := MAX( FLOAT64 );

		FOR i := 0 TO LEN( x ) - 1 DO
			IF x[i] < min THEN min := x[i];  m := i;  END;
		END;

		RETURN min;
	END Min;

	PROCEDURE SetName*( VAR one: ARRAY OF CHAR;  two: ARRAY OF CHAR );
	(* Kopiert Namen. *)

	VAR i: SIGNED32;

	BEGIN
		FOR i := 0 TO LEN( two ) - 1 DO one[i] := two[i];  END;
	END SetName;

	PROCEDURE DoCreateData*( VAR set: antsPottsSimDataStructure.SetChain;  function: vyName.tNameArray;  datanumber: SIGNED32;  fct: vyBase.Object;
											    VAR datavec: vyBase.Object;  VAR dataname: ARRAY OF CHAR );
	(* Kreiert Daten durch eine Funktion. *)

	VAR dataarray, diffs, eN, meanM, medianM, hampelM, saegezahnM, huberM: antsArrays.X1d;
		datacounter: ARRAY 1024 OF CHAR;

	BEGIN
		Strings.IntToStr( datanumber, datacounter );  Strings.Append( dataname, function );  Strings.Append( dataname, "WITH" );
		Strings.Append( dataname, datacounter );

		IF ~antsPottsSimDataStructure.ExistData( set, "Functions", dataname ) THEN
			WITH fct: antsFunctions.Function DO
				antsFunctions.DoSet( "", function, fct );  NEW( dataarray, vyLongrealVec.Len( datavec( vyLongrealVec.tVector ) ) );
				vyLongrealVec.CopyToArray( datavec( vyLongrealVec.tVector ), dataarray^ );
			END;

			NEW( diffs, 5 );  NEW( eN, 5 );  DoMonotone( dataarray, meanM, "MeanMonotone" );  CalcDiffAndEN( dataarray, meanM, diffs[0], eN[0] );
			DoMonotone( dataarray, medianM, "MedianMonotone" );  CalcDiffAndEN( dataarray, medianM, diffs[1], eN[1] );
			DoMonotone( dataarray, hampelM, "HampelMonotone" );  CalcDiffAndEN( dataarray, hampelM, diffs[2], eN[2] );
			DoMonotone( dataarray, saegezahnM, "SaegezahnMonotone" );  CalcDiffAndEN( dataarray, saegezahnM, diffs[3], eN[3] );
			DoMonotone( dataarray, huberM, "HuberMonotone" );  CalcDiffAndEN( dataarray, huberM, diffs[4], eN[4] );
			antsPottsSimDataStructure.NewData( set, "Functions", dataname, dataarray, diffs, eN, meanM, medianM, hampelM, saegezahnM, huberM );
		ELSE antsSecurity.Halt( "Data with this function and datanumber already exists. Please choose another function or datanumber !!!" );
		END;
	END DoCreateData;

	PROCEDURE DoDataRekoLoop*( VAR set: antsPottsSimDataStructure.SetChain;  dataChainname: ARRAY OF CHAR;  rekotype, gammatype: ARRAY OF CHAR;
													  gamma: FLOAT64;  VAR datarekoname: ARRAY OF CHAR );
	(* Berechnet zu allen Daten eines Datensatzes die Monotones. *)

	VAR i, len: SIGNED32;
		dataname, gammastr: ARRAY 1024 OF CHAR;
		data, datareko, results, eN: antsArrays.X1d;  var, actgamma: FLOAT64;  jumps: antsArrays.L1d;

	BEGIN
		len := antsPottsSimDataStructure.GetDataChainLen( set, dataChainname );  Strings.Append( datarekoname, rekotype );

		IF rekotype # "TautString" THEN
			Strings.Append( datarekoname, "WITH" );  Strings.Append( datarekoname, gammatype );

			IF gammatype = "ConstGamma" THEN
				Strings.Append( datarekoname, "AND" );  Strings.RealToStr( gamma, gammastr );  Strings.Append( datarekoname, gammastr );
			END;
		END;

		FOR i := 0 TO len - 1 DO
			antsPottsSimDataStructure.GetDataName( set, dataChainname, i, dataname );

			IF ~antsPottsSimDataStructure.ExistDataReko( set, dataChainname, dataname, datarekoname ) THEN
				data := antsPottsSimDataStructure.GetData( set, dataChainname, dataname );
				var := antsPottsSimDataStructure.GetEN( set, dataChainname, dataname, rekotype );
				eN := antsPottsSimDataStructure.GetAllEN( set, dataChainname, dataname );
				DoReko( data, datareko, jumps, rekotype, gammatype, var, gamma, actgamma );  DoResults( data, datareko, results, jumps, actgamma, eN, 2 );
				antsPottsSimDataStructure.NewDataReko( set, dataChainname, dataname, datarekoname, datareko, results );
			END;
		END;
	END DoDataRekoLoop;

	PROCEDURE DoDataReko*( VAR set: antsPottsSimDataStructure.SetChain;  dataChainname, dataname: ARRAY OF CHAR;  rekotype, gammatype: ARRAY OF CHAR;
											  gamma: FLOAT64 );
	(* Berechnet zu einem Datenvektor die Monotones. *)

	VAR datarekoname, gammastr: ARRAY 1024 OF CHAR;
		data, datareko, results, eN: antsArrays.X1d;  var, actgamma: FLOAT64;  jumps: antsArrays.L1d;

	BEGIN
		Strings.Append( datarekoname, rekotype );

		IF rekotype # "TautString" THEN
			Strings.Append( datarekoname, "WITH" );  Strings.Append( datarekoname, gammatype );

			IF gammatype = "ConstGamma" THEN
				Strings.Append( datarekoname, "AND" );  Strings.RealToStr( gamma, gammastr );  Strings.Append( datarekoname, gammastr );
			END;
		END;

		IF ~antsPottsSimDataStructure.ExistDataReko( set, dataChainname, dataname, datarekoname ) THEN
			data := antsPottsSimDataStructure.GetData( set, dataChainname, dataname );
			var := antsPottsSimDataStructure.GetEN( set, dataChainname, dataname, rekotype );
			eN := antsPottsSimDataStructure.GetAllEN( set, dataChainname, dataname );
			DoReko( data, datareko, jumps, rekotype, gammatype, var, gamma, actgamma );  DoResults( data, datareko, results, jumps, actgamma, eN, 2 );
			antsPottsSimDataStructure.NewDataReko( set, dataChainname, dataname, datarekoname, datareko, results );
		END;
	END DoDataReko;

	PROCEDURE DoReko*( x: antsArrays.X1d;  VAR y: antsArrays.X1d;  VAR jumps: antsArrays.L1d;  rekotype, gammatype: ARRAY OF CHAR;  var: FLOAT64;
									  gamma: FLOAT64;  VAR actgamma: FLOAT64 );
	(* Berechnet eine Datenrekonstruktion abhängig von rekotype und gammatype. *)

	VAR statistic1: antsPotts1DSurvey.StatisticObj;  statistic2: antsTautString.Statistic;  type1, type2: SIGNED16;  vec1, vec2: vyBase.Object;  len, i: SIGNED32;
		rstern: antsArrays.I1d;  bellman: antsArrays.X1d;

	BEGIN
		type1 := DoSetReko( rekotype );  type2 := DoSetGamma( gammatype );  len := LEN( x );  vec1 := vyLongrealVec.New( len );
		vyLongrealVec.CopyToVec( x^, vec1( vyLongrealVec.tVector ), len, 0, 0 );  vec2 := vyLongrealVec.New( len );  NEW( jumps, len );

		IF type1 = cTautString THEN
			NEW( statistic2 );  antsTautString.CreateTautString( statistic2, vec1, 2.5, 0.5, "local" );  NEW( y, LEN( statistic2.reko ) );
			vyLongreal.Copy( len, statistic2.reko^, 0, y^, 0 );  actgamma := 0;
		ELSE
			IF type2 = cConstGamma THEN
				NEW( globalStat );  antsBellman.InitStatistic1d( globalStat, len );

				IF type1 = cMedian THEN antsBellman.ComputeMedianStat1d( x^, globalStat );
				ELSIF type1 = cMean THEN antsBellman.ComputeMedianStat1d( x^, globalStat );
				ELSIF type1 = cHampel THEN antsBellman.ComputeHampelStat1d( x^, globalStat );
				ELSIF type1 = cSaegezahn THEN antsBellman.ComputeSaegezahnStat1d( x^, globalStat );
				ELSIF type1 = cHuber THEN antsBellman.ComputeHuberStat1d( x^, globalStat );
				END;

				globalGamma := gamma * 2 * Mad( x ) * Mad( x );
				antsBellman.Bellman( rstern, bellman, SHORT( len ), 0, MAX( SIGNED32 ), Function1d, -globalGamma );  NEW( y, len );
				antsBellman.Partition( rstern, y, statMean );  actgamma := gamma;
			ELSE
				NEW( statistic1 );  antsPotts1DSurvey.CreateStatistics( statistic1, vec1, type1 );

				IF type2 = cAIC THEN antsPotts1DSurvey.DoAIC( statistic1, vec2, var );
				ELSIF type2 = cAICEst THEN antsPotts1DSurvey.DoAICEst( statistic1, vec2 );
				ELSIF type2 = cAICC THEN antsPotts1DSurvey.DoAICC( statistic1, vec2 );
				ELSIF type2 = cSIC THEN antsPotts1DSurvey.DoSIC( statistic1, vec2, var );
				ELSIF type2 = cSICEst THEN antsPotts1DSurvey.DoSICEst( statistic1, vec2 );
				ELSIF type2 = cSICC THEN antsPotts1DSurvey.DoSICC( statistic1, vec2 );
				ELSIF type2 = cMaxInterval THEN antsPotts1DSurvey.DoMaxInterval( statistic1, vec2 );
				ELSIF type2 = cMaxIntervalLog THEN antsPotts1DSurvey.DoMaxIntervalLog( statistic1, vec2 );
				ELSIF type2 = cVarianceGain THEN antsPotts1DSurvey.DoVarianceGain( statistic1, vec2, SHORT( type1 ) - 1 );
				ELSIF type2 = cVarianceTest THEN antsPotts1DSurvey.DoVarianceTest( statistic1, vec2, var, SHORT( type1 ) - 1 );
				ELSIF type2 = cKneeCheck THEN antsPotts1DSurvey.DoKneeCheck( statistic1, vec2 );
				ELSIF type2 = cMultiCoeff THEN antsPotts1DSurvey.DoMultiCoeff( statistic1, vec2, 2.5 );
				ELSE antsSecurity.Halt( "Choosing Gamma not possible !!!" );
				END;

				NEW( y, vyLongrealVec.Len( vec2( vyLongrealVec.tVector ) ) );  vyLongrealVec.CopyToArray( vec2( vyLongrealVec.tVector ), y^ );
				actgamma := 0;   (* Hier fehlt noch Prozedur zum Zurückrechnen von gamma !!!!!!!!!!!! *)
			END;
		END;

		FOR i := 1 TO len - 1 DO
			IF y[i] # y[i - 1] THEN jumps[i] := 1;  ELSE jumps[i] := 0;  END;
		END;
	END DoReko;

	PROCEDURE statMean( k1, k2: SIGNED32 ): FLOAT64;

	BEGIN
		RETURN globalStat.m[k1, k2];
	END statMean;

	PROCEDURE Function1d( from, to: SIGNED32 ): FLOAT64;

	BEGIN
		RETURN globalStat.s[from, to] + globalGamma;
	END Function1d;

	PROCEDURE DoResults*( x, y: antsArrays.X1d;  VAR z: antsArrays.X1d;  jumps: antsArrays.L1d;  gamma: FLOAT64;  eN: antsArrays.X1d;  noisetype: SIGNED32 );
	(* Vergleicht 2 Daten und speichert Normen, MAD und Sprünge. *)

	VAR dummy, jumpsum: FLOAT64;  len, length, i: SIGNED32;  xyDiffArray: antsArrays.X1d;  xyDiff: vyLongrealVec.tVector;

	BEGIN
		jumpsum := 0;  NEW( xyDiffArray, LEN( x ) );  xyDiff := vyLongrealVec.New( LEN( x ) );

		FOR i := 0 TO LEN( x ) - 1 DO xyDiffArray[i] := x[i] - y[i];  END;

		vyLongrealVec.CopyToVec( xyDiffArray^, xyDiff, LEN( xyDiffArray ), 0, 0 );

		IF eN # NIL THEN length := 11;
		ELSE length := 6;
		END;

		len := length + LEN( jumps );  NEW( z, len );  z[0] := vyLongreal.Dist1( LEN( x ), x^, 0, y^, 0 );
		z[1] := antsPotts1DSurvey.EstimatedVariance( x^, y^, SHORT( noisetype ) );  z[2] := vyLongreal.DistSup( LEN( x ), x^, 0, y^, 0, dummy );
		z[3] := Mad( xyDiffArray );  z[4] := gamma;

		IF eN # NIL THEN z[6] := eN[0];  z[7] := eN[1];  z[8] := eN[2];  z[9] := eN[3];  z[10] := eN[4];
		END;

		FOR i := 0 TO LEN( jumps ) - 1 DO z[i + length] := jumps[i];  jumpsum := jumpsum + jumps[i];  END;

		z[5] := jumpsum;
	END DoResults;

	PROCEDURE DoAddNoise*( x: antsArrays.X1d;  VAR y: antsArrays.X1d;  parameter: FLOAT64;  noisetype: ARRAY OF CHAR );
	(* Verrauscht Daten. *)

	VAR type: SIGNED16;  vec1, vec2: vyBase.tVector;  len: SIGNED32;  par: FLOAT64;

	BEGIN
		type := DoSetNoise( noisetype );  len := LEN( x );  vec1 := vyLongrealVec.New( len );  vyLongrealVec.CopyToVec( x^, vec1, len, 0, 0 );
		vec2 := vyLongrealVec.New( len );

		IF type = cGauss THEN antsVecOpt.DoAddGaussNoise( vec1, vec2, 0, parameter );
		ELSIF type = cUniform THEN par := MathL.sqrt( 12 * parameter );  antsVecOpt.DoAddUniformNoise( vec1, vec2, par );
		ELSIF type = cLaplace THEN par := 1 / (MathL.sqrt( parameter ));  antsVecOpt.DoAddLaplaceNoise( vec1, vec2, par );
		ELSIF type = cExp THEN par := 1 / (MathL.sqrt( parameter ));  antsVecOpt.DoAddExpNoise( vec1, vec2, parameter );
		END;

		NEW( y, vyLongrealVec.Len( vec2 ) );  vyLongrealVec.CopyToArray( vec2, y^ );
	END DoAddNoise;

(* Die folgenden Methoden sind implementiert, um, von einem Datensatz ausgehend alles zu berechnen.
	Die Methode DoDataLoop ist nur der Vollständigkeit halber implementiert,
	da die Monotones eigentlich immer vorher schon berechnet sind. *)

	PROCEDURE DoDataLoop*( VAR set: antsPottsSimDataStructure.SetChain;  dataChainname: ARRAY OF CHAR;
											 meanM, medianM, hampelM, saegezahnM, huberM: ARRAY OF CHAR;  gaussN, laplaceN, expN, uniformN: ARRAY OF CHAR;
											 noiseParameter: FLOAT64;  noiseNumber: SIGNED32;  rekotype: ARRAY OF CHAR;  gammatype: ARRAY OF CHAR;  gamma: FLOAT64;
											 estimateNoise: ARRAY OF CHAR );

	VAR i, len: SIGNED32;
		dataname: ARRAY 1024 OF CHAR;

	BEGIN
		len := antsPottsSimDataStructure.GetDataChainLen( set, dataChainname );

		FOR i := 0 TO len - 1 DO
			antsPottsSimDataStructure.GetDataName( set, dataChainname, i, dataname );
			DoDataReko( set, dataChainname, dataname, rekotype, gammatype, gamma );
			DoMonotoneLoop( set, dataChainname, dataname, meanM, medianM, hampelM, saegezahnM, huberM, gaussN, laplaceN, expN, uniformN, noiseParameter,
										   noiseNumber, rekotype, gammatype, gamma, estimateNoise );
		END;
	END DoDataLoop;

	PROCEDURE DoMonotoneLoop*( VAR set: antsPottsSimDataStructure.SetChain;  dataChainname, dataname: ARRAY OF CHAR;
													  meanM, medianM, hampelM, saegezahnM, huberM: ARRAY OF CHAR;  gaussN, laplaceN, expN, uniformN: ARRAY OF CHAR;
													  noiseParameter: FLOAT64;  noiseNumber: SIGNED32;  rekotype: ARRAY OF CHAR;  gammatype: ARRAY OF CHAR;
													  gamma: FLOAT64;  estimateNoise: ARRAY OF CHAR );

	VAR monotonename: ARRAY 1024 OF CHAR;

	BEGIN
		IF meanM = "Yes" THEN
			monotonename := "MeanMonotone";
			DoDegradedLoop( set, dataChainname, dataname, monotonename, gaussN, laplaceN, expN, uniformN, noiseParameter, noiseNumber, rekotype, gammatype,
										   gamma, estimateNoise );
		END;

		IF medianM = "Yes" THEN
			monotonename := "MedianMonotone";
			DoDegradedLoop( set, dataChainname, dataname, monotonename, gaussN, laplaceN, expN, uniformN, noiseParameter, noiseNumber, rekotype, gammatype,
										   gamma, estimateNoise );
		END;

		IF hampelM = "Yes" THEN
			monotonename := "HampelMonotone";
			DoDegradedLoop( set, dataChainname, dataname, monotonename, gaussN, laplaceN, expN, uniformN, noiseParameter, noiseNumber, rekotype, gammatype,
										   gamma, estimateNoise );
		END;

		IF saegezahnM = "Yes" THEN
			monotonename := "SaegezahnMonotone";
			DoDegradedLoop( set, dataChainname, dataname, monotonename, gaussN, laplaceN, expN, uniformN, noiseParameter, noiseNumber, rekotype, gammatype,
										   gamma, estimateNoise );
		END;

		IF huberM = "Yes" THEN
			monotonename := "HuberMonotone";
			DoDegradedLoop( set, dataChainname, dataname, monotonename, gaussN, laplaceN, expN, uniformN, noiseParameter, noiseNumber, rekotype, gammatype,
										   gamma, estimateNoise );
		END;
	END DoMonotoneLoop;

	PROCEDURE DoDegradedLoop*( VAR set: antsPottsSimDataStructure.SetChain;  dataChainname, dataname, monotonename: ARRAY OF CHAR;
													 gaussN, laplaceN, expN, uniformN: ARRAY OF CHAR;  noiseParameter: FLOAT64;  noiseNumber: SIGNED32;
													 rekotype: ARRAY OF CHAR;  gammatype: ARRAY OF CHAR;  gamma: FLOAT64;  estimateNoise: ARRAY OF CHAR );

	VAR i, j, len, actGaussNumber: SIGNED32;  monotone, degraded, alldiffs, allENs: antsArrays.X1d;  parameter, actualDiff: FLOAT64;
		degradedname, actGaussString, actdataname: ARRAY 1024 OF CHAR;

	BEGIN
		monotone := antsPottsSimDataStructure.GetMonotone( set, dataChainname, dataname, monotonename );

		IF estimateNoise = "Yes" THEN
			len := antsPottsSimDataStructure.GetDataChainLen( set, dataChainname );  NEW( alldiffs, len - 1 );  NEW( allENs, len - 1 );  i := 0;  j := 0;

			WHILE i < len DO
				antsPottsSimDataStructure.GetDataName( set, dataChainname, i, actdataname );

				IF actdataname # dataname THEN
					alldiffs[j] := antsPottsSimDataStructure.GetDiff( set, dataChainname, actdataname, monotonename );
					allENs[j] := antsPottsSimDataStructure.GetEN( set, dataChainname, actdataname, monotonename );  INC( i );  INC( j );
				ELSE actualDiff := antsPottsSimDataStructure.GetDiff( set, dataChainname, actdataname, monotonename );  INC( i );
				END;
			END;

			parameter := CalcNearestNoiseP( alldiffs, allENs, actualDiff );
		ELSE parameter := noiseParameter;
		END;

		IF gaussN = "Yes" THEN
			FOR i := 0 TO noiseNumber - 1 DO
				degradedname := "Gauss";
				actGaussNumber := antsPottsSimDataStructure.GetNoiseNumber( set, dataChainname, dataname, monotonename, degradedname );
				actGaussNumber := actGaussNumber + 1;  Strings.IntToStr( actGaussNumber, actGaussString );  Strings.Append( degradedname, actGaussString );
				DoAddNoise( monotone, degraded, parameter, "Gauss" );
				antsPottsSimDataStructure.NewDegraded( set, dataChainname, dataname, monotonename, degradedname, degraded, parameter );
				antsPottsSimDataStructure.IncNoiseNumber( set, dataChainname, dataname, monotonename, "Gauss" );
				DoRekoLoop( set, dataChainname, dataname, monotonename, degradedname, rekotype, gammatype, gamma, parameter, 0 );
			END;
		END;

		IF laplaceN = "Yes" THEN
			FOR i := 0 TO noiseNumber - 1 DO
				degradedname := "Laplace";
				actGaussNumber := antsPottsSimDataStructure.GetNoiseNumber( set, dataChainname, dataname, monotonename, degradedname );
				actGaussNumber := actGaussNumber + 1;  Strings.IntToStr( actGaussNumber, actGaussString );  Strings.Append( degradedname, actGaussString );
				DoAddNoise( monotone, degraded, parameter, "Laplace" );
				antsPottsSimDataStructure.NewDegraded( set, dataChainname, dataname, monotonename, degradedname, degraded, parameter );
				antsPottsSimDataStructure.IncNoiseNumber( set, dataChainname, dataname, monotonename, "Laplace" );
				DoRekoLoop( set, dataChainname, dataname, monotonename, degradedname, rekotype, gammatype, gamma, parameter, 1 );
			END;
		END;

		IF expN = "Yes" THEN
			FOR i := 0 TO noiseNumber - 1 DO
				degradedname := "Exp";
				actGaussNumber := antsPottsSimDataStructure.GetNoiseNumber( set, dataChainname, dataname, monotonename, degradedname );
				actGaussNumber := actGaussNumber + 1;  Strings.IntToStr( actGaussNumber, actGaussString );  Strings.Append( degradedname, actGaussString );
				DoAddNoise( monotone, degraded, parameter, "Exp" );
				antsPottsSimDataStructure.NewDegraded( set, dataChainname, dataname, monotonename, degradedname, degraded, parameter );
				antsPottsSimDataStructure.IncNoiseNumber( set, dataChainname, dataname, monotonename, "Exp" );
				DoRekoLoop( set, dataChainname, dataname, monotonename, degradedname, rekotype, gammatype, gamma, parameter, 2 );
			END;
		END;

		IF uniformN = "Yes" THEN
			FOR i := 0 TO noiseNumber - 1 DO
				degradedname := "Uniform";
				actGaussNumber := antsPottsSimDataStructure.GetNoiseNumber( set, dataChainname, dataname, monotonename, degradedname );
				actGaussNumber := actGaussNumber + 1;  Strings.IntToStr( actGaussNumber, actGaussString );  Strings.Append( degradedname, actGaussString );
				DoAddNoise( monotone, degraded, parameter, "Uniform" );
				antsPottsSimDataStructure.NewDegraded( set, dataChainname, dataname, monotonename, degradedname, degraded, parameter );
				antsPottsSimDataStructure.IncNoiseNumber( set, dataChainname, dataname, monotonename, "Uniform" );
				DoRekoLoop( set, dataChainname, dataname, monotonename, degradedname, rekotype, gammatype, gamma, parameter, 2 );
			END;
		END;
	END DoDegradedLoop;

	PROCEDURE CalcNearestNoiseP*( x, y: antsArrays.X1d;  actualDiff: FLOAT64 ): FLOAT64;

	VAR len, i, mind: SIGNED32;  a, z: antsArrays.X1d;

	BEGIN
		len := LEN( x );

		IF len - 1 < 20 THEN NEW( z, 1 );  NEW( a, 1 );
		ELSIF len - 1 < 100 THEN NEW( z, 3 );  NEW( a, 3 );
		ELSIF len - 1 < 1000 THEN NEW( z, 5 );  NEW( a, 5 )
		ELSE NEW( z, 10 );  NEW( a, 10 );
		END;

		FOR i := 0 TO LEN( a ) - 1 DO a[i] := MAX( FLOAT64 );  END;

		FOR i := 0 TO len - 1 DO
			IF (ABS( x[i] - actualDiff ) < Max( a, mind )) THEN a[mind] := ABS( x[i] - actualDiff );  z[mind] := y[i];  END;
		END;

		RETURN Mean( z );
	END CalcNearestNoiseP;

	PROCEDURE Mean*( x: antsArrays.X1d ): FLOAT64;

	VAR mean: FLOAT64;  i: SIGNED32;

	BEGIN
		mean := 0;

		FOR i := 0 TO LEN( x ) - 1 DO mean := mean + x[i];  END;

		mean := mean / (LEN( x ));  RETURN mean;
	END Mean;

	PROCEDURE DoRekoLoop*( VAR set: antsPottsSimDataStructure.SetChain;  dataChainname, dataname, monotonename, degradedname: ARRAY OF CHAR;
											  rekotype: ARRAY OF CHAR;  gammatype: ARRAY OF CHAR;  gamma: FLOAT64;  var: FLOAT64;  rekotypenumb: SIGNED32 );

	VAR rekoname, actreko, gammastr: ARRAY 1024 OF CHAR;
		degraded, reko, results, datareko: antsArrays.X1d;  actgamma: FLOAT64;  jumps: antsArrays.L1d;

	BEGIN
		COPY( rekotype, actreko );  rekoname := actreko;

		IF rekotype # "TautString" THEN
			Strings.Append( rekoname, "WITH" );  Strings.Append( rekoname, gammatype );

			IF gammatype = "ConstGamma" THEN Strings.Append( rekoname, "AND" );  Strings.RealToStr( gamma, gammastr );  Strings.Append( rekoname, gammastr );
			END;
		END;

		IF ~antsPottsSimDataStructure.ExistReko( set, dataChainname, dataname, monotonename, degradedname, rekoname ) THEN
			datareko := antsPottsSimDataStructure.GetDataReko( set, dataChainname, dataname, rekoname );
			degraded := antsPottsSimDataStructure.GetDegraded( set, dataChainname, dataname, monotonename, degradedname );
			var := antsPottsSimDataStructure.GetEN( set, dataChainname, dataname, actreko );
			DoReko( degraded, reko, jumps, actreko, gammatype, var, gamma, actgamma );  DoResults( datareko, reko, results, jumps, actgamma, NIL , rekotypenumb );
			antsPottsSimDataStructure.NewReko( set, dataChainname, dataname, monotonename, degradedname, rekoname, reko, results );
		END;
	END DoRekoLoop;

	PROCEDURE DoREKOLoop*( VAR set: antsPottsSimDataStructure.SetChain;  dataChainname: ARRAY OF CHAR;  rekotype: ARRAY OF CHAR;  gammatype: ARRAY OF CHAR;
											   gamma: FLOAT64 );

	VAR i, j, k, l: SIGNED32;  rekotypenumb: SIGNED32;  var: FLOAT64;
		datasetname, dataname, monotonename, degradedname: ARRAY 1024 OF CHAR;

	BEGIN
		FOR i := 0 TO antsPottsSimDataStructure.GetSetChainLen( set ) - 1 DO
			antsPottsSimDataStructure.GetDataSetName( set, i, datasetname );

			IF datasetname = dataChainname THEN
				FOR j := 0 TO antsPottsSimDataStructure.GetDataChainLen( set, dataChainname ) - 1 DO
					antsPottsSimDataStructure.GetDataName( set, dataChainname, j, dataname );

					FOR k := 0 TO antsPottsSimDataStructure.GetMonotoneChainLen( set, dataChainname, dataname ) - 1 DO
						antsPottsSimDataStructure.GetMonotoneName( set, dataChainname, dataname, k, monotonename );

						IF antsPottsSimDataStructure.ExistDegradedChain( set, dataChainname, dataname, monotonename ) THEN
							FOR l := 0 TO antsPottsSimDataStructure.GetDegradedChainLen( set, dataChainname, dataname, monotonename ) - 1 DO
								antsPottsSimDataStructure.GetDegradedName( set, dataChainname, dataname, monotonename, l, degradedname );
								var := antsPottsSimDataStructure.GetNoiseVariance( set, dataChainname, dataname, monotonename, degradedname );
								rekotypenumb := DoSetReko( rekotype );
								DoRekoLoop( set, dataChainname, dataname, monotonename, degradedname, rekotype, gammatype, gamma, var, rekotypenumb );
							END;
						END;
					END;
				END;
			END;
		END;
	END DoREKOLoop;

(**  PROCEDURE DoOutput();

VAR RR: antsFiles.Rider;

BEGIN
	IF ~RR.Old() THEN
		RR.ForceNew();
	END;

	RR.Set(2);

	RR.Close;

	IF ~RR.Old() THEN
		RR.ForceNew();
	END;

	RR.Set(2);

	RR.Close;

	IF ~RR.Old() THEN
		RR.ForceNew();
	END;

	RR.Set(2);

	RR.Close;

	IF ~RR.Old() THEN
		RR.ForceNew();
	END;

	RR.Set(2);

	RR.Close;
END DoOutput; **)

END antsPottsSimAdministration.