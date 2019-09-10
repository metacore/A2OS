MODULE antsComet IN Oberon;   (** fof  **)
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




IMPORT antsObjects, Files, antsKernel, antsArrayObjects, antsModels, antsCommands, vyName, Objects, vyRanBase,
	vyRandom, vyBase, vyLongrealVec, Gadgets, aM := antsMessages;

TYPE
	LRA = POINTER TO ARRAY OF FLOAT64;

	tModel* = POINTER TO tModelDesc;
	tModelDesc* = RECORD (antsModels.tModelDesc)
		pointsx, pointsy, mass: LRA;
		points: SIGNED32;
		vertmassv: vyBase.tVector
	END;

VAR  (* localCache: tConstNeighbourCache;  *)
	localModel: tModel;

	PROCEDURE StoreM( VAR R: Files.Rider;  s: tModel );
	VAR i: SIGNED32;
	BEGIN
		Files.WriteInt( R, 3 );  Files.WriteLInt( R, s.points );
		FOR i := 0 TO s.points - 1 DO
			Files.WriteLReal( R, s.pointsx[i] );  Files.WriteLReal( R, s.pointsy[i] );  Files.WriteLReal( R, s.mass[i] )
		END;
		Gadgets.WriteRef( R, s.lib, s.vertmassv )
	END StoreM;

	PROCEDURE LoadM( VAR R: Files.Rider;  s: tModel );
	VAR version: SIGNED16;  i: SIGNED32;  ref: Objects.Object;
	BEGIN
		Files.ReadInt( R, version );  Files.ReadLInt( R, s.points );  NEW( s.pointsx, s.points );  NEW( s.pointsy, s.points );
		NEW( s.mass, s.points );
		FOR i := 0 TO s.points - 1 DO
			Files.ReadLReal( R, s.pointsx[i] );  Files.ReadLReal( R, s.pointsy[i] );  Files.ReadLReal( R, s.mass[i] )
		END;
		IF version < 3 THEN NewPars( s ) ELSE Gadgets.ReadRef( R, s.lib, ref );  s.vertmassv := ref( vyBase.tVector ) END

	END LoadM;

	PROCEDURE Range( x, y, w, h: SIGNED32 ): BOOLEAN;
	BEGIN
		IF (x < 0) OR (y < 0) OR (x >= w) OR (y >= h) THEN RETURN FALSE ELSE RETURN TRUE END
	END Range;

	PROCEDURE OneSweep( s: antsKernel.Kernel );
	VAR w, h: SIGNED32;  A: antsArrayObjects.tINTEGERArray;  model: tModel;  AO: antsArrayObjects.tINTEGERObject;  i: SIGNED32;  x, y: FLOAT64;
		xi, yi: SIGNED16;  xa, ya, mass: LRA;  dr: FLOAT64;  K1, K: FLOAT64;  nuM, variance: FLOAT64;  vv: SIGNED16;

		PROCEDURE drift( mass: FLOAT64 ): FLOAT64;
		BEGIN

			RETURN 1 / (K1 + mass * nuM / K)
		END drift;

	BEGIN
		model := s.par( tModel );  AO := s.A( antsArrayObjects.tINTEGERObject );  A := AO.A;  w := AO.w;  h := AO.h;
		variance := model.par[9];  xa := model.pointsx;  ya := model.pointsy;  mass := model.mass;  nuM := model.par[0];
		K1 := model.par[1];  K := model.par[2];
		IF (model.vertmassv.nrData # AO.w) THEN vyLongrealVec.SetLen( model.vertmassv, AO.w ) END;
		vyLongrealVec.Fill( model.vertmassv, 0, 0, AO.w );

		antsArrayObjects.FillIntArray( 0, A, 0, 0, w, h );
		FOR i := 0 TO model.points - 1 DO
			dr := drift( mass[i] ) / 100;
			x := xa[i] + vyRandom.Gauss( dr, variance * 1 / (1 + mass[i]) );   (* variance restricted to [0,1)*)
			y := ya[i] + vyRandom.Gauss( 0, variance * 1 / (1 + mass[i]) );  xa[i] := x;  ya[i] := y;  xi := SHORT( ENTIER( x ) );  yi := SHORT( ENTIER( y ) );
			IF Range( xi, yi, w, h ) THEN
				(* INC(A[yi, xi], SHORT(ENTIER(mass[i]))); *)
				vyLongrealVec.Set( vyLongrealVec.Get( model.vertmassv, xi ) + mass[i], model.vertmassv, xi );
				vv := A[yi, xi];
				IF mass[i] > vv THEN A[yi, xi] := SHORT( ENTIER( mass[i] ) ) END;
				IF A[yi, xi] > 254 THEN A[yi, xi] := 254 END
			END
		END
	END OneSweep;

	PROCEDURE Uniform( s: antsKernel.Kernel );
	VAR i: SIGNED32;  model: tModel;  A: antsArrayObjects.tINTEGERObject;  gen: vyRanBase.tRandom;  xi, yi: SIGNED16;  x, y: FLOAT64;
		minmass, maxmass, meanmass: FLOAT64;  vv: SIGNED16;
	BEGIN
				minmass := MAX( FLOAT64 );  maxmass := MIN( FLOAT64 );  meanmass := 0;  gen := vyRanBase.RandomGenerator;  model := s.par( tModel );
		A := s.A( antsArrayObjects.tINTEGERObject );  antsArrayObjects.FillIntArray( 0, A.A, 0, 0, A.w, A.h );
		IF model.vertmassv.nrData # A.w THEN vyLongrealVec.SetLen( model.vertmassv, A.w ) END;
		vyLongrealVec.Fill( model.vertmassv, 0, 0, A.w );

		FOR i := 0 TO model.points - 1 DO
			x := -10000;  y := -10000;
			WHILE ((x - model.par[3]) * (x - model.par[3]) + (y - model.par[4]) * (y - model.par[4]) > model.par[5] * model.par[5]) DO  (* acceptence rejection sampling in circle *)
				x := model.par[3] + model.par[5] * (1 - 2 * gen.GetRandomU( gen ));
				y := model.par[4] + model.par[5] * (1 - 2 * gen.GetRandomU( gen ));
			END;
			model.pointsx[i] := x;  model.pointsy[i] := y;  model.mass[i] := vyRandom.Exp( model.par[0] );  xi := SHORT( ENTIER( x ) );
			yi := SHORT( ENTIER( y ) );
					IF Range( xi, yi, A.w, A.h ) THEN
				(* INC(A.A[yi, xi], SHORT(ENTIER(model.mass[i])));   (* range check !! *)*)
				vyLongrealVec.Set( vyLongrealVec.Get( model.vertmassv, xi ) + model.mass[i], model.vertmassv, xi );
				vyLongrealVec.Set( vyLongrealVec.Get( model.vertmassv, xi ) + model.mass[i], model.vertmassv, xi );
				vv := A.A[yi, xi];
				IF model.mass[i] > vv THEN
					 A.A[yi, xi] := SHORT( ENTIER( model.mass[i] ) );
					END;

				IF A.A[yi, xi] > 254 THEN A.A[yi, xi] := 254 END
				(*IF A.A[yi, xi] > 255 THEN A.A[yi, xi] := 255 END;*)
			END;
			IF model.mass[i] < minmass THEN minmass := model.mass[i] END;
			IF model.mass[i] > maxmass THEN maxmass := model.mass[i] END;
			meanmass := meanmass + model.mass[i];

		END;
		meanmass := meanmass / model.points;  model.par[6] := minmass;  model.par[7] := meanmass;
		model.par[8] := maxmass;  vyBase.Update( model );

	END Uniform;

	PROCEDURE Min( a, b: SIGNED32 ): SIGNED32;
	BEGIN
		IF a < b THEN RETURN a ELSE RETURN b END;
	END Min;

	PROCEDURE ChangePoints( m: tModel;  points: SIGNED32 ): BOOLEAN;
	VAR x, y, mass: LRA;  i: SIGNED32;
	BEGIN
		IF m.points = points THEN RETURN TRUE
		ELSIF m.points <= 0 THEN RETURN FALSE
		ELSE
			x := m.pointsx;  y := m.pointsy;  mass := m.mass;  NEW( m.pointsx, points );  NEW( m.pointsy, points );  NEW( m.mass, points );
			FOR i := 0 TO Min( m.points, points ) - 1 DO m.pointsx[i] := x[i];  m.pointsy[i] := y[i];  m.mass[i] := mass[i];  END;
			FOR i := Min( m.points, points ) TO points - 1 DO
				m.pointsx[i] := m.par[3];  m.pointsy[i] := m.par[4];  m.mass[i] := vyRandom.Exp( 1 / m.par[0] );
			END;
			m.points := points;  RETURN TRUE;
		END;
	END ChangePoints;

	PROCEDURE Handler*( o: Objects.Object;  VAR M: Objects.ObjMsg );
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
					IF M.id = Objects.enum THEN M.Enum( "Particles" );  antsModels.Handler( o, M )
					ELSIF M.id = Objects.get THEN
						IF M.name = "Gen" THEN COPY( 'antsComet.Gen', M.s );  M.class := Objects.String;  M.res := 0;  RETURN
						ELSIF M.name = "Particles" THEN M.i := o.points;  M.class := Objects.Int;  M.res := 0;  RETURN;
						ELSE antsModels.Handler( o, M )
						END
					ELSIF M.id = Objects.set THEN
						IF M.name = "Particles" THEN
							IF M.class = Objects.Int THEN
								IF ChangePoints( o, M.i ) THEN M.res := 0;  RETURN END;
							END;
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
			ELSIF M IS Objects.BindMsg THEN
				WITH M: Objects.BindMsg DO antsObjects.Bind( o.vertmassv, M );  antsModels.Handler( o, M );
				END;
			ELSE antsModels.Handler( o, M )
			END
		END;   (* tVector*)
	END Handler;

	PROCEDURE OpenModel*( M: tModel;  name: vyName.tNameArray;  points: SIGNED32 );
	BEGIN
		vyName.RegisterNamed( M, name );  M.points := points;  NEW( M.pointsx, points );  NEW( M.pointsy, points );
		NEW( M.mass, points );
	END OpenModel;

	PROCEDURE NewPars( m: tModel );
	BEGIN
		NEW( m.par, 10 );  NEW( m.parNames, 10 );  m.parNames[0] := "mass";  m.par[0] := 200;  m.parNames[1] := "dspeedx";  m.par[1] := 20;
		m.parNames[2] := "dspeedy";  m.par[2] := 8;  m.parNames[3] := "cellx";  m.par[3] := 30;  m.parNames[4] := "celly";  m.par[4] := 50;
		m.parNames[5] := "cellsize";  m.par[5] := 20;  m.parNames[6] := "minmass";  m.par[6] := 0;  m.parNames[7] := "meanmass";  m.par[7] := 0;
		m.parNames[8] := "maxmass";  m.par[8] := 0;  m.parNames[9] := "dummy";  m.par[9] := 0;
	END NewPars;

	PROCEDURE Gen*;
	VAR m: tModel;
	BEGIN
		aM.cmd;  NEW( m );  m.handle := Handler;  Objects.NewObj := m;  antsObjects.Register( m );  NewPars( m );
		Objects.NewObj := m;  m.vertmassv := vyLongrealVec.New( 1 );  vyName.RegisterNamed( m.vertmassv, "vertmassv" );
		Objects.NewObj := m;
	END Gen;

	PROCEDURE NewModel*;
	VAR l: antsCommands.tScanList;  name: vyName.tNameArray;  M: tModel;  points: SIGNED32;
	BEGIN
		l := antsCommands.ScanFromPar( "name= NAME points=INT" );
		IF antsCommands.ExpectNameFromKeyword( l, "name", name ) & antsCommands.ExpectNumberFromKeyword( l, "points", points ) THEN
			Gen;  M := Objects.NewObj( tModel );  antsModels.Open( M );  OpenModel( M, name, points );
		END
	END NewModel;

BEGIN
	aM.launch;  NEW( localModel );
END antsComet.

System.Free antsComet ~

fofAutomatic.Do
antsArrayObjects.New testarray 200 100 256 ~
antsArrayPictures.New testpict testarray ~
Voyager.Show testpict as antsPictureViews ~
antsComet.NewModel > name Model > points 5000 ~
antsKernel.Define > name Sampler ~
antsKernel.AttachModel > sampler Sampler > model Model ~
antsKernel.AttachArray > sampler Sampler > array testarray ~
antsMC.New chain ~
antsMC.Add chain Sampler ~
antsObjects.WriteAttributes Model ~
~
antsObjects.WriteAttributes chain ~
ants / antsComet.Panel1

antsMC.Init chain ~
fofAutomatic.Do > interactive
antsMC.Forward chain  1 1 ~
~
ants / antsPictureFilm.Mod
Voyager.Show vertmassv as LinePlot ~
vyBase.Subscribe(Sampler, vertmassv);