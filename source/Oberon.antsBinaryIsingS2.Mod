MODULE antsBinaryIsingS2 IN Oberon;   (** fof  **)
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




IMPORT antsObjects, Objects, Files, antsArrayObjects, Math := MathL IN A2, antsKernel, antsModels, antsCommands, vyName,
	Gadgets, antsCaches, Links, Attributes, antsArrays, aM := antsMessages;

TYPE
	RandomArray = POINTER TO ARRAY OF LONGREAL;

	tModel* = POINTER TO tModelDesc;
	tModelDesc* = RECORD (antsModels.tModelDesc);
	(* h-, beta-,penalty-: LONGREAL; *)
		ccool: LONGREAL;
		ran: RandomArray
	END;

	PROCEDURE Open*( M: tModel );
	BEGIN
		M.synced := FALSE;  Gadgets.Update( M )
	END Open;

	PROCEDURE StoreM( VAR R: Files.Rider;  s: tModel );
	BEGIN
		Files.WriteInt( R, 1 )
		(*
	Files.WriteLReal(R, s.h); Files.WriteLReal(R, s.beta);  Files.WriteLReal(R, s.penalty);
	*)
	END StoreM;

	PROCEDURE LoadM( VAR R: Files.Rider;  s: tModel );
	VAR version: INTEGER;
	BEGIN
		Files.ReadInt( R, version );
		IF version < 1 THEN Files.ReadLReal( R, s.par[0] );  Files.ReadLReal( R, s.par[1] );  Files.ReadLReal( R, s.par[2] ) END;
		Open( s )
	END LoadM;

	PROCEDURE U( m: tModel;  a: ARRAY OF INTEGER ): LONGREAL;
	VAR theta: LONGREAL;  sum: LONGREAL;
	BEGIN
		theta := 0;
		IF m.par[2] > 0 THEN
			theta := theta + 1 / 2 * Math.ln( (1 - m.par[2]) / (m.par[2]) ) * (2 * a[5] - 1) * (2 * a[0] - 1);
			(*
		IF a[5] # a[0] THEN theta := theta-Math.ln(m.par[2]) ELSE theta := theta-Math.ln(1- m.par[2]) END;
		*)
			(*! think: why times 2 ?? *)
		END;
		sum := (2 * a[1] - 1) + (2 * a[2] - 1) + (2 * a[3] - 1) + (2 * a[4] - 1);
		theta := theta + m.par[0] * (2 * a[0] - 1) + m.par[1] * (2 * a[0] - 1) * sum;  RETURN theta;
	END U;

	PROCEDURE Cache( m: tModel );
	VAR cv: ARRAY 6 OF INTEGER;
		c: antsCaches.FullCache;  offset: LONGINT;  s: LONGREAL;  i: INTEGER;
	BEGIN
		m.MCache := antsCaches.Cube( 6, 2, m.maxCacheSize );  m.ccool := m.coolingTemp;  c := m.MCache;  offset := -1;
		WHILE (c.NextPoint( offset, cv, 1 )) DO
			s := 0;
			(* write values of exp(..) to array *)
			i := 0;
			WHILE (i < 2) DO cv[0] := i;  s := s + Math.exp( m.coolingTemp * U( m, cv ) );  c.values[i + offset] := s;  INC( i );  END;
			cv[0] := 0;
			(* divide by normalizing constant *)
			i := 0;
			WHILE (i < 2) DO c.values[offset + i] := c.values[offset + i] / s;  INC( i );  END;
		END;
	END Cache;

	PROCEDURE OneSweep( s: antsKernel.Kernel );
	VAR x, y, w, h, maxx, maxy: LONGINT;  A, AOrig: antsArrayObjects.tINTEGERArray;  model: tModel;
		AO: antsArrayObjects.tINTEGERObject;  Random: RandomArray;  ran: LONGREAL;  cpos: LONGINT;  u: LONGREAL;  orig: Objects.Object;
		checkerboard: BOOLEAN;
		a: ARRAY 6 OF INTEGER;
	BEGIN
		model := s.par( tModel );
		IF model.ccool # model.coolingTemp THEN model.synced := FALSE END;
		AO := s.A( antsArrayObjects.tINTEGERObject );  Links.GetLink( AO, "orig", orig );
		AOrig := orig( antsArrayObjects.tINTEGERObject ).A;
		IF ~model.synced THEN Open( model );  Cache( model );  model.synced := TRUE;  END;
		IF (model.ran = NIL ) OR (LEN( model.ran ) # AO.w) THEN NEW( model.ran, AO.w );  END;

		Random := model.ran;
		(*
	antsArrayObjects.UniformR(AO.w,AO.h);
	Random := antsArrayObjects.RandomR;
	*)

		w := AO.w;  h := AO.h;  maxx := w - 1;  maxy := h - 1;  A := AO.A;  checkerboard := FALSE;
		Attributes.GetBool( model, "checkerboard", checkerboard );  aM.dSc( checkerboard, "checkerboard" );

		IF ~checkerboard THEN
			FOR y := 0 TO maxy DO
				antsArrays.Uniform1dX( Random^, 0, LEN( Random ), 1 );
				FOR x := 0 TO maxx DO
					ran := Random[x];  a[1] := A[y, (x - 1) MOD w];  a[2] := A[y, (x + 1) MOD w];  a[3] := A[(y - 1) MOD h, x];
					a[4] := A[(y + 1) MOD h, x];  a[5] := AOrig[y, x];  cpos := model.MCache.Offset( a, 1 );
					u := model.MCache.values[cpos];
					IF ran < u THEN A[y, x] := 0 ELSE A[y, x] := 1 END;
				END;
			END;
		ELSE
			FOR y := 0 TO maxy DO
				antsArrays.Uniform1dX( Random^, 0, LEN( Random ), 1 );
				FOR x := 0 TO maxx DO
					IF ((y + x) MOD 2) = 1 THEN
						ran := Random[x];  a[1] := A[y, (x - 1) MOD w];  a[2] := A[y, (x + 1) MOD w];  a[3] := A[(y - 1) MOD h, x];
						a[4] := A[(y + 1) MOD h, x];  a[5] := AOrig[y, x];  cpos := model.MCache.Offset( a, 1 );
						u := model.MCache.values[cpos];
						IF ran < u THEN A[y, x] := 0 ELSE A[y, x] := 1 END;
					END;
				END;
			END;
			FOR y := 0 TO maxy DO
				antsArrays.Uniform1dX( Random^, 0, LEN( Random ), 1 );
				FOR x := 0 TO maxx DO
					IF ((y + x) MOD 2) = 0 THEN
						ran := Random[x];  a[1] := A[y, (x - 1) MOD w];  a[2] := A[y, (x + 1) MOD w];  a[3] := A[(y - 1) MOD h, x];
						a[4] := A[(y + 1) MOD h, x];  a[5] := AOrig[y, x];  cpos := model.MCache.Offset( a, 1 );
						u := model.MCache.values[cpos];
						IF ran < u THEN A[y, x] := 0 ELSE A[y, x] := 1 END;
					END;
				END;
			END;

		END;

	END OneSweep;

(*
PROCEDURE Uniform (s: antsKernel.Kernel);
BEGIN antsArrayObjects.UniformO(s.A(antsArrayObjects.tObject));
s.A(antsArrayObjects.tINTEGERObject).Cache := NIL;
END Uniform;
*)
	PROCEDURE Handler*( o: Objects.Object;  VAR M: Objects.ObjMsg );
	BEGIN
		WITH o: tModel DO
			IF M IS antsKernel.samplingMsg THEN
				WITH M: antsKernel.samplingMsg DO
					antsModels.SetTemperature( o, M.temp );  OneSweep( M.dlink( antsKernel.Kernel ) );
					(* | M: antsKernel.Init DO
			Uniform(M.dlink(antsKernel.Kernel)); *)
				END;
			ELSIF M IS Objects.FileMsg THEN
				WITH M: Objects.FileMsg DO
					IF M.id = Objects.load THEN antsModels.Handler( o, M );  LoadM( M.R, o )
					ELSIF M.id = Objects.store THEN antsModels.Handler( o, M );  StoreM( M.R, o )
					END;
				END;
			ELSIF M IS Objects.AttrMsg THEN
				WITH M: Objects.AttrMsg DO
					IF M.id = Objects.enum THEN antsModels.Handler( o, M )
					ELSIF M.id = Objects.get THEN
						IF M.name = "Gen" THEN COPY( 'antsBinaryIsingS2.Gen', M.s );  M.class := Objects.String;  M.res := 0;  RETURN ELSE antsModels.Handler( o, M ) END
					ELSIF M.id = Objects.set THEN antsModels.Handler( o, M )
					ELSE antsModels.Handler( o, M )
					END
				END;
			ELSE antsModels.Handler( o, M )
			END
		END;   (* tVector*)
	END Handler;

	PROCEDURE OpenModel*( M: tModel;  name: vyName.tNameArray;  beta, h, penalty: LONGREAL );
	BEGIN
		M.par[0] := h;  M.par[1] := beta;  M.par[2] := penalty;  Open( M );
		IF M.handle # NIL THEN M.handle := Handler END;
		vyName.RegisterNamed( M, name )
	END OpenModel;

	PROCEDURE Gen*;
	VAR m: tModel;
	BEGIN
		aM.cmd;  NEW( m );  m.handle := Handler;  Objects.NewObj := m;  antsObjects.Register( m );
		antsModels.SetMaxCache( m, 10000 );  NEW( m.par, 3 );  NEW( m.parNames, 3 );  m.parNames[0] := "h";  m.parNames[1] := "beta";
		m.parNames[2] := "pen";
	END Gen;

	PROCEDURE NewModel*;
	VAR l: antsCommands.tScanList;  name: vyName.tNameArray;  M: tModel;  beta, h, pen: LONGREAL;
	BEGIN
		l := antsCommands.ScanFromPar( "name=NAME beta=REAL h=REAL penalty=REAL" );
		IF antsCommands.ExpectNameFromKeyword( l, "name", name ) & antsCommands.ExpectRealFromKeyword( l, "beta", beta ) &
		    antsCommands.ExpectRealFromKeyword( l, "h", h ) & antsCommands.ExpectRealFromKeyword( l, "penalty", pen ) THEN
			Gen;  M := Objects.NewObj( tModel );  antsModels.Open( M );  OpenModel( M, name, beta, h, pen )
		END
	END NewModel;

BEGIN
	aM.launch;
END antsBinaryIsingS2.

System.Free antsBinaryIsingS antsModels~

fofAutomatic.Do
antsArrayObjects.New testarray 100 100 2 ~
antsArrayPictures.New testpict testarray ~
Voyager.Show testpict as antsPictureViews ~
antsBinaryIsingS.NewModel > name Model  > h 0.0 > beta 0.6 ~
antsKernel.Define > name Sampler ~
antsKernel.AttachModel > sampler Sampler > model Model ~
antsKernel.AttachArray > sampler Sampler > array testarray ~
antsMC.New chain ~
antsMC.Add chain Sampler ~
~

antsToolbox.FrameToGIF Film ~
fofAutomatic.Do > interactive
antsMC.Forward chain 10 20 ~
antsToolbox.FrameToGIF Film > old ~
~

Voyager.Show Sampler as antsObjectView ~
antsMC.Jump chain - 1 ~
antsMC.Init chain ~
antsMC.Repeat chain 2 ~

antsObjects.WriteAttributes chain ~
antsObjects.WriteAttributes Sampler ~
antsObjects.WriteAttributes Model ~
ants / antsMC.Mod

antsMC.WriteSeeds chain ~
antsMC.ApplyConstInit chain Sampler2 const = 1 max = 1 ~


"Exact Sampling"

fofAutomatic.Do
antsArrayObjects.New testarray 100 100 2 ~
antsArrayPictures.New testpict testarray ~
Voyager.Show testpict as antsPictureViews ~
antsBinaryIsingS.NewModel > name Model  > h 0.0 > beta 0.6 ~
antsKernel.Define > name Sampler ~
antsKernel.AttachModel > sampler Sampler > model Model ~
antsKernel.AttachArray > sampler Sampler > array testarray ~
antsMC.New chain ~
antsMC.Add chain Sampler ~
antsArrayObjects.New testarray 100 100 2 ~
antsArrayPictures.New testpict testarray ~
Voyager.Show testpict as antsPictureViews ~
antsKernel.Define > name Sampler2 ~
antsKernel.AttachModel > sampler Sampler2 > model Model ~
antsKernel.AttachArray > sampler Sampler2 > array testarray ~
antsMC.Add chain Sampler2 ~
antsMC.ApplyConstInit chain Sampler const = 0 max = 1 ~
antsMC.ApplyConstInit chain Sampler2 const = 1 max = 1 ~
~