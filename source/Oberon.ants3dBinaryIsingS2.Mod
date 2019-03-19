MODULE ants3dBinaryIsingS2 IN Oberon;   (** fof  **)
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




IMPORT antsCommands, antsObjects, Objects, Files, Math := MathL IN A2, antsKernel, antsModels, vyName, Gadgets, antsCaches,
	Links, antsArrays, ants3dArrayObjects, aM := antsMessages;

TYPE
	RandomArray = POINTER TO ARRAY OF LONGREAL;

	tModel* = POINTER TO tModelDesc;
	tModelDesc* = RECORD (antsModels.tModelDesc);
	(* h-, beta-,penalty-: LONGREAL; *)
		ccool: LONGREAL;
		ran: RandomArray
	END;

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
		IF version < 1 THEN Files.ReadLReal( R, s.par[0] );  Files.ReadLReal( R, s.par[1] );  Files.ReadLReal( R, s.par[2] ) END
	END LoadM;

	PROCEDURE U( m: tModel;  a: ARRAY OF INTEGER ): LONGREAL;
	VAR theta: LONGREAL;  sum: LONGREAL;  i: LONGINT;
	BEGIN
		sum := 0;
		FOR i := 0 TO 7 DO
			a[i] := 2 * a[i] - 1 (* conversion from {0,1} to {-1,1} *)
		END;

		IF m.par[2] > 0 THEN  (* penalizing term, for multiplicative channel noise with par apar[2] *)
			IF a[7] # a[0] THEN theta := Math.ln( m.par[2] ) ELSE theta := Math.ln( 1 - m.par[2] ) END;
			(*! think: why times 2 ?? *)
		ELSE theta := 0
		END;

		sum := a[1] + a[2] + a[3] + a[4] + a[5] + a[6];   (* nearest neighbours *)

		theta := theta + a[0] * (m.par[0] + m.par[1] * sum);  RETURN theta
	END U;

	PROCEDURE Cache( m: tModel );
	VAR cv: ARRAY 8 OF INTEGER;
		c: antsCaches.FullCache;  offset: LONGINT;  s: LONGREAL;  i: INTEGER;
	BEGIN
		m.MCache := antsCaches.Cube( 8, 2, m.maxCacheSize );  m.ccool := m.coolingTemp;  c := m.MCache;  offset := -1;
		WHILE (c.NextPoint( offset, cv, 1 )) DO
			s := 0;
			(* write values of exp(..) to array *)
			i := 0;
			WHILE (i < 2) DO cv[0] := i;  s := s + Math.exp( m.coolingTemp * U( m, cv ) );  c.values[i + offset] := s;  INC( i ) END;
			cv[0] := 0;
			(* divide by normalizing constant *)
			i := 0;
			WHILE (i < 2) DO c.values[offset + i] := c.values[offset + i] / s;  INC( i ) END
		END
	END Cache;

	PROCEDURE CheckCaches( model: tModel );
	BEGIN
		IF model.ccool # model.coolingTemp THEN model.synced := FALSE END;
		IF ~model.synced THEN Cache( model );  model.synced := TRUE END

	END CheckCaches;

	PROCEDURE OneSweep( s: antsKernel.Kernel );
	VAR x, y, w, h, maxx, maxy: LONGINT;  A, AOrig: ants3dArrayObjects.tArray;  model: tModel;  AO: ants3dArrayObjects.tObject;
		Random: RandomArray;  ran: LONGREAL;  cpos: LONGINT;  u: LONGREAL;  orig: Objects.Object;  l, maxl, ll: LONGINT;
		a: ARRAY 8 OF INTEGER;
		scaletemp: BOOLEAN;
	BEGIN
		scaletemp := (s.makeTemperature # antsKernel.constScheme);  model := s.par( tModel );
		AO := s.A( ants3dArrayObjects.tObject );
		IF scaletemp THEN
			antsModels.SetTemperature( model, Math.sqrt( 2 * model.coolingTemp / Math.ln( AO.w * AO.h * AO.d ) ) );   (*! das ist eine schweinerei ! *)
			Gadgets.Update( model )
		END;
		Links.GetLink( AO, "orig", orig );
		IF orig # NIL THEN AOrig := orig( ants3dArrayObjects.tObject ).A ELSE AOrig := AO.A END;

		CheckCaches( model );

		IF (model.ran = NIL ) OR (LEN( model.ran ) < AO.w) THEN
			NEW( model.ran, AO.w ) (* random array, held in model to prevent from multiple allocation. *)
		END;
		Random := model.ran;

		(* antsArrayObjects.UniformR(AO.w,AO.h);
	Random := antsArrayObjects.RandomR;  *)
		w := AO.w;  h := AO.h;  maxl := AO.d - 1;  ll := maxl + 1;  maxx := w - 1;  maxy := h - 1;  A := AO.A;
		FOR l := 0 TO maxl DO
		(* antsArrayObjects.UniformR(AO.w,AO.h);    *)
			FOR y := 0 TO maxy DO
				antsArrays.Uniform1dX( Random^, 0, LEN( Random ), 1 );
				(* adr := ADDRESSOF(Random[y,0]);*)
				FOR x := 0 TO maxx DO
					ran := Random[x];
					(* SYSTEM.GET(adr,ran); INC(adr,step);*)
					a[1] := A[l, y, (x - 1) MOD w];  a[2] := A[l, y, (x + 1) MOD w];  a[3] := A[l, (y - 1) MOD h, x];
					a[4] := A[l, (y + 1) MOD h, x];  a[5] := A[(l + 1) MOD ll, y, x];  a[6] := A[(l - 1) MOD ll, y, x];  a[7] := AOrig[l, y, x];
					cpos := model.MCache.Offset( a, 1 );  u := model.MCache.values[cpos];
					IF ran < u THEN A[l, y, x] := 0 ELSE A[l, y, x] := 1 END
				END
			END
		END

	END OneSweep;

	PROCEDURE Uniform( s: antsKernel.Kernel );
	BEGIN
		ants3dArrayObjects.UniformO( s.A( ants3dArrayObjects.tObject ) )
		(* s.A(ants3dArrayObjects.tObject).ACache := NIL; *)
	END Uniform;

	PROCEDURE CopyOrig( s: antsKernel.Kernel );
	VAR A: ants3dArrayObjects.tObject;  obj: Objects.Object;  orig: ants3dArrayObjects.tObject;
	BEGIN
		A := s.A( ants3dArrayObjects.tObject );  Links.GetLink( A, "orig", obj );
		IF obj # NIL THEN orig := obj( ants3dArrayObjects.tObject ) ELSE orig := NIL END;
		IF orig = NIL THEN Uniform( s ) ELSE ants3dArrayObjects.CopyArray( orig.A, A.A, 0, 0, 0, A.w, A.h, A.d, 0, 0, 0 ) END;
	END CopyOrig;

	PROCEDURE Handler*( o: Objects.Object;  VAR M: Objects.ObjMsg );
	BEGIN
		WITH o: tModel DO
			IF M IS antsKernel.samplingMsg THEN
				WITH M: antsKernel.samplingMsg DO
					antsModels.SetTemperature( o, M.temp );  OneSweep( M.dlink( antsKernel.Kernel ) );
				END;
			ELSIF M IS antsKernel.Init THEN
				WITH M: antsKernel.Init DO
					IF M.dlink( antsKernel.Kernel ).initwithorig THEN CopyOrig( M.dlink( antsKernel.Kernel ) )
					ELSE Uniform( M.dlink( antsKernel.Kernel ) );
					END;
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
						IF M.name = "Gen" THEN COPY( 'ants3dBinaryIsingS2.Gen', M.s );  M.class := Objects.String;  M.res := 0;  RETURN ELSE antsModels.Handler( o, M ) END
					ELSIF M.id = Objects.set THEN antsModels.Handler( o, M )
					ELSE antsModels.Handler( o, M )
					END
				END;
			ELSE antsModels.Handler( o, M )
			END
		END  (* tVector*)
	END Handler;

	PROCEDURE OpenModel*( M: tModel;  name: vyName.tNameArray;  beta, h, penalty: LONGREAL );
	BEGIN
		antsModels.Open( M );  M.par[0] := h;  M.par[1] := beta;  M.par[2] := penalty;
		IF M.handle # NIL THEN M.handle := Handler END;
		vyName.RegisterNamed( M, name )
	END OpenModel;

	PROCEDURE Gen*;
	VAR m: tModel;
	BEGIN
		aM.cmd;  NEW( m );  m.handle := Handler;  Objects.NewObj := m;  antsObjects.Register( m );
		antsModels.SetMaxCache( m, 10000 );  NEW( m.par, 3 );  NEW( m.parNames, 3 );  m.parNames[0] := "h";  m.parNames[1] := "beta";
		m.parNames[2] := "pen"
	END Gen;

	PROCEDURE NewModel*;
	VAR l: antsCommands.tScanList;  name: vyName.tNameArray;  M: tModel;  beta, h, pen: LONGREAL;
	BEGIN
		l := antsCommands.ScanFromPar( "name=NAME beta=REAL h=REAL penalty=REAL" );
		IF antsCommands.ExpectNameFromKeyword( l, "name", name ) & antsCommands.ExpectRealFromKeyword( l, "beta", beta ) &
		    antsCommands.ExpectRealFromKeyword( l, "h", h ) & antsCommands.ExpectRealFromKeyword( l, "penalty", pen ) THEN
			Gen;  M := Objects.NewObj( tModel );  OpenModel( M, name, beta, h, pen )
		END
	END NewModel;

BEGIN
	aM.launch;
END ants3dBinaryIsingS2.

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