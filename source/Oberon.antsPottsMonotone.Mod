MODULE antsPottsMonotone IN Oberon;

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
Angela Kempe, 2003
*)


IMPORT Math := MathL IN A2, Out, vyLongreal, vyLongrealVec, vyBase, antsCommands, Input, vyName, Display3, vyLinks, vyPort, aM := antsMessages, vyHostStrings,
	antsReadWrite, Objects, antsSecurity, Texts, vyHostTexts, Gadgets, Attributes, antsBellman, antsArrays, antsVecOpt, antsPotts1DSurvey;

CONST
	cMedian* = 0;  cMean* = 1;  cAbs* = 0;  cLog* = 1;  cIncr* = 0;  cDecr* = 1;
TYPE

	ArrayFunction = PROCEDURE ( VAR f: ARRAY OF LONGREAL;  i: LONGINT ): LONGREAL;

	PROCEDURE MakeMonotoneRec*;
	VAR name: ARRAY 64 OF CHAR;
		obj, degraded: vyBase.Object;  type: INTEGER;  vec: vyLongrealVec.tVector;
	BEGIN
		antsCommands.InitScan( "data=OBJ (vec=OBJ ) | (vec=NAME >create)" );
		IF antsCommands.ExpectObject( "data", degraded ) & antsCommands.GetObject( "vec", obj ) THEN
			vec := obj( vyLongrealVec.tVector );  vyLongrealVec.SetLen( vec, 0 )
		ELSIF antsCommands.GetName( "vec", name ) & antsCommands.Find( "create" ) THEN vec := vyLongrealVec.New( 0 );  vyName.RegisterNamed( vec, name )
		ELSE RETURN
		END;

		IF antsCommands.Find( "median" ) THEN type := cMedian
		ELSIF antsCommands.Find( "mean" ) THEN type := cMean
		ELSE antsSecurity.Halt( "keyword >mean or >median expected" )
		END;

		DoMonotone( degraded, type, vec )

	END MakeMonotoneRec;

	PROCEDURE DoMonotone( degraded: vyBase.Object;  type: INTEGER;  VAR vec: vyLongrealVec.tVector );
	VAR N, i, j: LONGINT;  data: antsArrays.X1d;  pos: LONGINT;  multi: antsArrays.L1d;  start, end: LONGINT;  mean, ssq: LONGREAL;  nrNaNs: LONGINT;
		len: LONGINT;  interval: vyLongrealVec.tVector;
	BEGIN
		ASSERT ( (degraded # NIL ) & (degraded IS vyLongrealVec.tVector), 109 );
		N := vyLongrealVec.Len( degraded( vyLongrealVec.tVector ) );

		(*Eingabedaten werden in data kopiert, aus dem dann wieder herausgestrichen wird*)
		IF (data = NIL ) OR (LEN( data ) # N) THEN NEW( data, N ) END;
		vyLongrealVec.CopyToArray( degraded( vyLongrealVec.tVector ), data^ );

		IF (multi = NIL ) OR (LEN( multi ) # N) THEN NEW( multi, N )
		END;

		(*Initialisierung des Vielfachheiten-Vektors multi*)
		FOR i := 0 TO N - 1 DO multi^[i] := 1 END;

		len := LEN( data );  pos := 1;

		WHILE pos <= len - 1 DO
			IF pos > 0 THEN
				IF data^[pos - 1] < data^[pos] THEN
					start := 1;
					FOR i := 1 TO pos - 2 DO start := start + multi^[i - 1] END;
					end := start - 1 + multi^[pos - 1] + multi^[pos];
					IF (interval = NIL ) OR (vyLongrealVec.Len( interval ) # end - start + 1) THEN interval := vyLongrealVec.New( end - start + 1 ) END;
					FOR i := 0 TO end - start + 1 - 1 DO vyLongrealVec.Set( vyLongrealVec.Get( degraded( vyLongrealVec.tVector ), i ), interval, i ) END;
					IF type = cMedian THEN data^[pos] := vyLongrealVec.GetMedian( degraded( vyLongrealVec.tVector ) )
					ELSIF type = cMean THEN vyLongrealVec.GetMeanSsq( degraded( vyLongrealVec.tVector ), mean, ssq, nrNaNs );  data^[pos] := mean
					ELSE aM.S( "wrong type" )
					END;
					multi^[pos] := multi^[pos - 1] + multi^[pos];  DropX1d( data, pos - 1, data );  DropL1d( multi, pos - 1, multi );  pos := pos - 1;  len := LEN( data )
				ELSE pos := pos + 1
				END
			END

		END;   (*of WHILE*)




		(*Herausschreiben des Ergebnis-Vektor mittels data und multi*)

		FOR i := 0 TO LEN( multi ) - 1 DO
			FOR j := 1 TO multi^[i] DO vyLongrealVec.Append( data[i], vec ) END
		END
	END DoMonotone;

(*
this generates a new vector where the value at position is dropped out
*)
	PROCEDURE DropX1d*( vec: antsArrays.X1d;  position: LONGINT;  VAR new: antsArrays.X1d );
	VAR N, k: LONGINT;
	BEGIN
		(* N := vyLongrealVec.Len(vec); *)
		N := LEN( vec^ );  NEW( new, N - 1 );
		FOR k := 0 TO N - 1 DO
			IF k < position THEN
				new^[k] := vec^[k];   (*vyLongrealVec.Set(vyLongrealVec.Get(vec,k), new, k) *)
			ELSIF k > position THEN
				new^[k - 1] := vec^[k] (*vyLongrealVec.Set(vyLongrealVec.Get(vec,k), new, k-1) *)
			END
		END
	END DropX1d;

	PROCEDURE DropL1d*( vec: antsArrays.L1d;  position: LONGINT;  VAR new: antsArrays.L1d );
	VAR N, k: LONGINT;
	BEGIN
		(* N := vyLongrealVec.Len(vec); *)
		N := LEN( vec^ );  NEW( new, N - 1 );
		FOR k := 0 TO N - 1 DO
			IF k < position THEN
				new^[k] := vec^[k];   (*vyLongrealVec.Set(vyLongrealVec.Get(vec,k), new, k) *)
			ELSIF k > position THEN
				new^[k - 1] := vec^[k] (*vyLongrealVec.Set(vyLongrealVec.Get(vec,k), new, k-1) *)
			END
		END
	END DropL1d;

	PROCEDURE TestMonotone( VAR vector: ARRAY OF LONGREAL;  montype: INTEGER ): BOOLEAN;
	VAR i, N: LONGINT;  flag: BOOLEAN;
	BEGIN
		N := LEN( vector );  i := 0;  flag := TRUE;
		WHILE (i < N - 1) & (flag = TRUE ) DO
			IF ((montype = cDecr) & (vector[i] < vector[i + 1])) THEN flag := FALSE END;
			IF ((montype = cIncr) & (vector[i] > vector[i + 1])) THEN flag := FALSE END;
			INC( i )
		END;
		RETURN flag
	END TestMonotone;

	PROCEDURE MakeMatrix*( VAR Xstern: antsArrays.X2d;  VAR jumps: antsArrays.I1d;  VAR gamma: antsArrays.X1d;  VAR matrix: antsArrays.X2d );
	VAR N, jumpN, i: LONGINT;
	BEGIN
		N := LEN( Xstern^ );
		jumpN := antsArrays.FindFirstX( gamma^, 0 ) + 1;   (*! changed 031027 *)


		NEW( matrix, jumpN, N );  i := 0;
		(*
   WHILE (jumps^[i] # 0) OR (i = 0) DO
			vyLongreal.Copy(N, Xstern^[ jumps^[i] ], 0, matrix^[i], 0);
		    INC( i )
   END;
    *)
		FOR i := 0 TO jumpN - 1 DO vyLongreal.Copy( N, Xstern^[jumps^[i]], 0, matrix^[i], 0 );  END;

	END MakeMatrix;

	PROCEDURE LastMonotone*( VAR matrix: antsArrays.X2d;  montype: INTEGER;  VAR lastmon: antsArrays.X1d );
	VAR N, i, jumpN: LONGINT;
		(* flag : BOOLEAN;*)
	BEGIN
		N := LEN( matrix[0] );  jumpN := LEN( matrix );  NEW( lastmon, N );

		i := 0;
		WHILE (i < jumpN) & (TestMonotone( matrix[i], montype )) DO INC( i );  END;
		vyLongreal.Copy( N, matrix^[i - 1], 0, lastmon^, 0 );

		(*
     flag := TRUE;
     WHILE (i <= jumpN - 1) & (flag = TRUE) DO
        aM.SI("i=  ",i);
        vyLongreal.Copy(N, matrix^[i],0, lastmon^,0);
		IF TestMonotone(lastmon,montype)=TRUE THEN INC(i)
		ELSE flag := FALSE END;
	END;
	vyLongreal.Copy(N, matrix^[i-1],0, lastmon^,0);
	*)
	END LastMonotone;

	PROCEDURE FindLastMonotonePotts*;
	VAR statistic: antsPotts1DSurvey.StatisticObj;  degraded, vec: vyBase.Object;  matrix: antsArrays.X2d;  lastmon: antsArrays.X1d;
		name: ARRAY 64 OF CHAR;
		i: LONGINT;
	BEGIN
		antsCommands.InitScan( "data=OBJ" );

		IF antsCommands.ExpectObject( "data", degraded ) THEN
			NEW( statistic );  antsPotts1DSurvey.CreateStatistics( statistic, degraded, antsPotts1DSurvey.cMean );
			antsBellman.gammaScanning( statistic.Bellman, statistic.jumps, statistic.gamma );
			(*
         vec := vyLongrealVec.New(LEN(statistic.data)); vyName.RegisterNamed(vec, name);
        *)
			MakeMatrix( statistic.Xstern, statistic.jumps, statistic.gamma, matrix );  LastMonotone( matrix, cDecr, lastmon );
			IF antsCommands.GetObject( "vec", vec ) THEN
			ELSIF antsCommands.ExpectName( "vec", name ) THEN vec := vyLongrealVec.New( LEN( statistic.data ) );  vyName.RegisterNamed( vec, name );
			ELSE RETURN
			END;
			antsPotts1DSurvey.LineToVec( lastmon^, vec );
		END;
	END FindLastMonotonePotts;

	PROCEDURE FindLastMonotone*;
	VAR statistic: antsPotts1DSurvey.StatisticObj;  vec, statvec: vyBase.Object;  bool: BOOLEAN;  matrix: antsArrays.X2d;  lastmon: antsArrays.X1d;
		montype: INTEGER;
	BEGIN
		IF ~antsPotts1DSurvey.Header( statistic, vec ) THEN RETURN END;

		IF antsCommands.Find( "increase" ) THEN montype := cIncr
		ELSIF antsCommands.Expect( "decrease" ) THEN montype := cDecr
		END;

		bool := antsCommands.GetObject( "statvec", statvec );  antsBellman.gammaScanning( statistic.Bellman, statistic.jumps, statistic.gamma );
		(*
	 vec := vyLongrealVec.New(LEN(statistic.data)); vyName.RegisterNamed(vec, name);
	*)
		MakeMatrix( statistic.Xstern, statistic.jumps, statistic.gamma, matrix );  LastMonotone( matrix, montype, lastmon );
		antsPotts1DSurvey.LineToVec( lastmon^, vec );

		(*

	statistic.scanningOpt := statistic.jumps[MaxLenPos(statistic.gamma^, ALen)];
	LineToVec(statistic.Xstern[statistic.scanningOpt], vec); 		AppendValue(statistic.scanningOpt, statvec);

	IF antsCommands.Find("compare") THEN
		LargestJump( vec, MaxJump );
		(*writing in a text field in a panel***)
		outputMaxJump := Gadgets.FindObj( Gadgets.context, "outputMaxJump");
		IF outputMaxJump # NIL THEN
		    Attributes.SetLongReal( outputMaxJump, "Value", MaxJump );
		    Gadgets.Update(outputMaxJump);
		END;
	END
*)
	END FindLastMonotone;

	PROCEDURE ApproxMonotone*;
	VAR datain, dataout: ARRAY 64 OF CHAR;
		Matrix: antsArrays.X2d;  MatrixOut: antsArrays.X2d;  type: INTEGER;  R: antsReadWrite.Rider;
	BEGIN
		antsCommands.InitScan( "DataIn=STR  DataOut=STR (>median|>mean)" );

		IF antsCommands.ExpectString( "DataIn", datain ) & antsCommands.ExpectString( "DataOut", dataout ) THEN
			antsSecurity.SetProgress( 0 );
			IF ~R.Old( datain ) THEN RETURN END;
			R.ignoreNL := TRUE;
			(*     R.noExponent := TRUE;  *)
			R.ReadType;  R.ReadX2d( Matrix );  R.Close;
		ELSE RETURN
		END;

		IF antsCommands.Find( "median" ) THEN type := antsPotts1DSurvey.cMedian
		ELSIF antsCommands.Expect( "mean" ) THEN type := antsPotts1DSurvey.cMean
		END;

		DoApproxMonotonePotts( Matrix, type, MatrixOut );

		R.ForceNew( dataout );  R.noExponent := TRUE;
		R.SetAscii;   (* remove if binary preferred *)
		R.WriteType;  R.WriteX2d( MatrixOut );  R.Close;

	END ApproxMonotone;

	PROCEDURE DoApproxMonotonePotts( VAR Matrix: antsArrays.X2d;  type: INTEGER;  VAR MatrixOut: antsArrays.X2d );
	VAR i, j, rows, columns: LONGINT;  spotdata: vyLongrealVec.tVector;  statistic: antsPotts1DSurvey.StatisticObj;  ScanningMatrix: antsArrays.X2d;
		lastmon: antsArrays.X1d;
	BEGIN
		rows := LEN( Matrix );  columns := LEN( Matrix[0] );  NEW( MatrixOut, rows, columns );

		spotdata := vyLongrealVec.New( columns );

		FOR i := 0 TO rows - 1 DO
			aM.SI( " ", i );  aM.S( "" );

			FOR j := 0 TO columns - 1 DO vyLongrealVec.Set( Matrix[i, j], spotdata, j ) END;

			NEW( statistic );  statistic.s := NIL;  statistic.rstern := NIL;  statistic.Xstern := NIL;  statistic.Bellman := NIL;

			antsPotts1DSurvey.CreateStatistics( statistic, spotdata, type );  antsBellman.gammaScanning( statistic.Bellman, statistic.jumps, statistic.gamma );
			MakeMatrix( statistic.Xstern, statistic.jumps, statistic.gamma, ScanningMatrix );  LastMonotone( ScanningMatrix, cDecr, lastmon );
			vyLongreal.Copy( columns, lastmon^, 0, MatrixOut^[i], 0 );

		END;

	END DoApproxMonotonePotts;

END antsPottsMonotone.

System.Free Monotone ~
fofAutomatic.Do >secure
Monotone.ApproxMonotone DataIn=angie/A/635.txt DataOut=  angie/A/635mean.txt  >mean~
~~
~
fofAutomatic.Do >secure
Monotone.ApproxMonotone DataIn=angie/A/635.txt DataOut=angie/A/635median.txt  >median~
Monotone.ApproxMonotone DataIn=angie/A/532.txt DataOut=angie/A/532median.txt  >median~
Monotone.ApproxMonotone DataIn=angie/A/532.txt DataOut=angie/A/532mean.txt  >mean~
Monotone.FindLastMonotonePotts data=Datagen2 vec=lastmon~
Voyager.Show Datagen2 as antsPointPlot~
Voyager.Show lastmon as LinePlot~
~~
~

