MODULE antsGauss1dModel IN Oberon;   (** fof   **)
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



IMPORT antsObjects, Files, vyBase, antsKernel, antsModels, vyRanBase, antsCommands, vyName, Objects, antsVectors,
	vyLongrealVec, vyRandom, vyHostStrings, aM := antsMessages;

TYPE

	tModel* = POINTER TO tModelDesc;
	tModelDesc* = RECORD (antsModels.tModelDesc)
		a: ARRAY 6 OF LONGREAL
	END;
	(*
	a[0]: Fact1
	a[1]: Fact2
	a[2]; var1
	a[3]; var2
	a[4]: add1
	a[5]: add2
	*)


	PROCEDURE Open*( M: tModel;  a: ARRAY OF LONGREAL );
	VAR i: LONGINT;
	BEGIN
		FOR i := 0 TO 5 DO M.a[i] := a[i] END
	END Open;

	PROCEDURE StoreM( VAR R: Files.Rider;  s: tModel );
	VAR i: LONGINT;
	BEGIN
		Files.WriteInt( R, 0 );
		FOR i := 0 TO 5 DO Files.WriteLReal( R, s.a[i] ) END
	END StoreM;

	PROCEDURE LoadM( VAR R: Files.Rider;  s: tModel );
	VAR version: INTEGER;  i: LONGINT;
	BEGIN
		Files.ReadInt( R, version );
		FOR i := 0 TO 5 DO Files.ReadLReal( R, s.a[i] ) END
	END LoadM;

	PROCEDURE OneSweep( s: antsKernel.Kernel );
	VAR model: tModel;  ran: LONGREAL;  v1, v2: vyBase.tVector;  x, y: LONGREAL;

	BEGIN
		model := s.par( tModel );  v1 := antsVectors.GetVector( s.A( antsVectors.Container ), 0 );
		v2 := antsVectors.GetVector( s.A( antsVectors.Container ), 1 );
		WITH v1: vyLongrealVec.tVector DO
			WITH v2: vyLongrealVec.tVector DO
				x := vyLongrealVec.Get( v2, v2.nrData - 1 );  y := vyLongrealVec.Get( v1, v1.nrData - 1 );
				ran := model.a[0] * x + model.a[4] + vyRandom.GaussM( 0, model.a[2] / (model.coolingTemp + 1) );
				vyLongrealVec.Append( ran, v1 );
				ran := model.a[1] * ran + model.a[5] + vyRandom.GaussM( 0, model.a[3] / (model.coolingTemp + 1) );
				vyLongrealVec.Append( ran, v2 )
			END
		END
	END OneSweep;

	PROCEDURE Uniform( s: antsKernel.Kernel );
	VAR v1, v2: vyBase.tVector;  ran: LONGREAL;
	BEGIN
		v1 := antsVectors.GetVector( s.A( antsVectors.Container ), 0 );
		v2 := antsVectors.GetVector( s.A( antsVectors.Container ), 1 );  vyLongrealVec.SetLen( v1( vyLongrealVec.tVector ), 0 );
		vyLongrealVec.SetLen( v2( vyLongrealVec.tVector ), 0 );
		ran := 10 * vyRanBase.RandomGenerator.GetRandomU( vyRanBase.RandomGenerator );
		vyLongrealVec.Append( ran, v1( vyLongrealVec.tVector ) );
		ran := 10 * vyRanBase.RandomGenerator.GetRandomU( vyRanBase.RandomGenerator );
		vyLongrealVec.Append( ran, v2( vyLongrealVec.tVector ) )
	END Uniform;

	PROCEDURE ArrayHandleAttribute( VAR M: Objects.AttrMsg;  prefix: ARRAY OF CHAR;  VAR array: ARRAY OF LONGREAL ): BOOLEAN;
	VAR cur: ARRAY 64 OF CHAR;
		i: LONGINT;  len: LONGINT;
	BEGIN
		len := LEN( array );
		IF M.id = Objects.enum THEN
			FOR i := 0 TO len - 1 DO
				COPY( prefix, cur );  vyHostStrings.Append( cur, "[" );  vyHostStrings.AppendInt( i, 1, cur );  vyHostStrings.Append( cur, "]" );
				M.Enum( cur )
			END;
			RETURN TRUE
		ELSIF M.id = Objects.get THEN
			FOR i := 0 TO len - 1 DO
				COPY( prefix, cur );  vyHostStrings.Append( cur, "[" );  vyHostStrings.AppendInt( i, 1, cur );  vyHostStrings.Append( cur, "]" );
				IF vyHostStrings.Equal( M.name, cur ) THEN M.y := array[i];  M.class := Objects.LongReal;  M.res := 0;  RETURN TRUE END
			END
		ELSIF M.id = Objects.set THEN
			FOR i := 0 TO len - 1 DO
				COPY( prefix, cur );  vyHostStrings.Append( cur, "[" );  vyHostStrings.AppendInt( i, 1, cur );  vyHostStrings.Append( cur, "]" );
				IF vyHostStrings.Equal( M.name, cur ) THEN
					IF M.class = Objects.LongReal THEN array[i] := M.y;  M.res := 0;  RETURN TRUE
					ELSIF M.class = Objects.Real THEN array[i] := M.x;  M.res := 0;  RETURN TRUE
					END
				END
			END

		END;
		RETURN FALSE
	END ArrayHandleAttribute;

	PROCEDURE Handler*( o: Objects.Object;  VAR M: Objects.ObjMsg );
	VAR i: LONGINT;
	BEGIN
		WITH o: tModel DO
			IF M IS antsKernel.samplingMsg THEN
				WITH M: antsKernel.samplingMsg DO
					antsModels.SetTemperature( o, M.temp );  OneSweep( M.dlink( antsKernel.Kernel ) );
				END;
			ELSIF M IS antsKernel.Init THEN
				WITH M: antsKernel.Init DO Uniform( M.dlink( antsKernel.Kernel ) );  o.synced := FALSE;
				END;
			ELSIF M IS Objects.AttrMsg THEN
				WITH M: Objects.AttrMsg DO

					IF M.id = Objects.enum THEN
						IF ArrayHandleAttribute( M, "par", o.a ) THEN END;
						antsModels.Handler( o, M )
					ELSIF M.id = Objects.get THEN
						IF M.name = "Gen" THEN COPY( 'antsGauss1dModel.Gen', M.s );  M.class := Objects.String;  M.res := 0;  RETURN
						ELSIF ArrayHandleAttribute( M, "par", o.a ) THEN
						ELSE antsModels.Handler( o, M )
						END
					ELSIF M.id = Objects.set THEN
						IF ArrayHandleAttribute( M, "par", o.a ) THEN
							FOR i := 0 TO 5 DO aM.SRSR( "", i, " - ", o.a[i] ) END
						ELSE antsModels.Handler( o, M )
						END
					ELSE antsModels.Handler( o, M )
					END;
				END;
			ELSIF M IS Objects.FileMsg THEN
				WITH M: Objects.FileMsg DO
					IF M.id = Objects.load THEN antsModels.Handler( o, M );  LoadM( M.R, o )
					ELSIF M.id = Objects.store THEN antsModels.Handler( o, M );  StoreM( M.R, o )
					END
				END;
			ELSE antsModels.Handler( o, M )
			END
		END  (* tVector*)
	END Handler;

	PROCEDURE Gen*;
	VAR m: tModel;
	BEGIN
		aM.cmd;  NEW( m );  m.handle := Handler;  Objects.NewObj := m;  antsObjects.Register( m )
	END Gen;

	PROCEDURE NewModel*;
	VAR l: antsCommands.tScanList;  name: vyName.tNameArray;  M: tModel;
		a: ARRAY 6 OF LONGREAL;
	BEGIN
		l := antsCommands.ScanFromPar( "name=NAME f1=REAL f2=REAL v1=REAL v2=REAL add1=REAL add2=REAL" );
		IF antsCommands.ExpectNameFromKeyword( l, "name", name ) & antsCommands.ExpectRealFromKeyword( l, "f1", a[0] ) &
		    antsCommands.ExpectRealFromKeyword( l, "f2", a[1] ) & antsCommands.ExpectRealFromKeyword( l, "v1", a[2] ) &
		    antsCommands.ExpectRealFromKeyword( l, "v2", a[3] ) & antsCommands.ExpectRealFromKeyword( l, "add1", a[4] ) &
		    antsCommands.ExpectRealFromKeyword( l, "add2", a[5] ) THEN
			Gen;  M := Objects.NewObj( tModel );  antsModels.Open( M );  Open( M, a );  vyName.RegisterNamed( M, name )
		END
	END NewModel;

BEGIN
	aM.launch;
END antsGauss1dModel.

System.Free antsGauss1dModel ~

vyRanCombo.Install ~

ants / Freiberg6.Automatic

fofAutomatic.Do
antsFctVector.NewVec v1 1 ~
antsFctVector.NewVec v2 1 ~
antsVectors.New container ~
antsVectors.Add container v1 v2 ~
antsGauss1dModel.NewModel Model 0.2 0.2  1 1 0 0 ~
antsObjects.WriteAttributes Model
antsKernel.Define > name Sampler ~
antsKernel.AttachModel  Sampler  Model ~
antsKernel.AttachArray  Sampler  container ~
antsMC.New chain ~
antsMC.Add chain Sampler ~
antsMC.Forward chain  100 1 ~
Voyager.Show v1 v2  ~
~
fofAutomatic.Do > interactive
antsMC.Forward chain  10 1 ~
~
antsMC.Jump chain 0 ~
antsMC.Init chain ~
Voyager.Show v1  v2  as Charts~
vyScale.Insert

