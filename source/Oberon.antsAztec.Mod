MODULE antsAztec IN Oberon;   (** fof  **)
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




IMPORT antsObjects, Objects, Files, antsArrayObjects, antsKernel, antsModels, vyRandom, antsCommands, vyName, Gadgets, aM := antsMessages;

TYPE

	tModel* = POINTER TO tModelDesc;
	tModelDesc* = RECORD (antsModels.tModelDesc);
		horprob: LONGREAL
	END;

	PROCEDURE StoreM( VAR R: Files.Rider;  s: tModel );
	BEGIN
		Files.WriteInt( R, 1 );  Files.WriteLReal( R, s.horprob )
	END StoreM;

	PROCEDURE LoadM( VAR R: Files.Rider;  s: tModel );
	VAR version: INTEGER;
	BEGIN
		Files.ReadInt( R, version );
		IF version > 0 THEN Files.ReadLReal( R, s.horprob ) ELSE s.horprob := 0.5 END
	END LoadM;

	PROCEDURE OneSweep( s: antsKernel.Kernel );
	VAR x, y: INTEGER;  model: tModel;  AO: antsArrayObjects.tINTEGERObject;  copy: antsArrayObjects.tINTEGERArray;

		PROCEDURE movestep( A: antsArrayObjects.tINTEGERObject;  y, x: INTEGER ): INTEGER;
		BEGIN
			IF (A.A[y, (x + 1) MOD A.w] = 3) & (A.A[y, x] # 1) THEN RETURN 3
			ELSIF (A.A[y, (x - 1) MOD A.w] = 1) & (A.A[y, x] # 3) THEN RETURN 1
			ELSIF (A.A[(y + 1) MOD A.h, (x) MOD A.w] = 4) & (A.A[y, x] # 2) THEN RETURN 4
			ELSIF (A.A[(y - 1) MOD A.h, (x) MOD A.w] = 2) & (A.A[y, x] # 4) THEN RETURN 2
			ELSIF A.A[y, x] = 0 THEN
				IF (A.A[y, (x + 1) MOD A.w] + A.A[(y + 1) MOD A.h, (x) MOD A.w] + A.A[(y - 1) MOD A.h, (x) MOD A.w] +
					 A.A[y, (x - 1) MOD A.w] # 0) THEN
					RETURN 5
				ELSE RETURN 0
				END
			ELSE RETURN 5
			END
		END movestep;

	BEGIN
		model := s.par( tModel );  AO := s.A( antsArrayObjects.tINTEGERObject );
		copy := antsArrayObjects.NewINTEGERArray( AO.w, AO.h );

		FOR y := 0 TO SHORT( AO.h - 1 ) DO
			FOR x := 0 TO SHORT( AO.w - 1 ) DO copy[y, x] := movestep( AO, y, x ) END
		END;

		FOR y := 0 TO SHORT( AO.h - 1 ) DO
			FOR x := 0 TO SHORT( AO.w - 1 ) DO AO.A[y, x] := copy[y, x] END
		END;

		FOR y := 0 TO SHORT( AO.h - 1 ) DO
			FOR x := 0 TO SHORT( AO.w - 1 ) DO
				IF AO.A[y, x] = 5 THEN
					IF vyRandom.Uniform() > model.horprob THEN
						AO.A[y, x] := 4;  AO.A[y, (x + 1) MOD AO.w] := 4;  AO.A[(y + 1) MOD AO.h, x] := 2;
						AO.A[(y + 1) MOD AO.h, (x + 1) MOD AO.w] := 2
					ELSE
						AO.A[y, x] := 3;  AO.A[y, (x + 1) MOD AO.w] := 1;  AO.A[(y + 1) MOD AO.h, x] := 3;
						AO.A[(y + 1) MOD AO.h, (x + 1) MOD AO.w] := 1
					END
				END
			END
		END
	END OneSweep;

	PROCEDURE Uniform( s: antsKernel.Kernel );
	VAR x, y: LONGINT;  model: tModel;  AO: antsArrayObjects.tINTEGERObject;  O: antsArrayObjects.tObject;
	BEGIN
		model := s.par( tModel );  AO := s.A( antsArrayObjects.tINTEGERObject );  O:= AO; O := 0;

		x := AO.w DIV 2;  y := AO.h DIV 2;
		AO.A[y, x - 1] := 2;  AO.A[y, x] := 2;  AO.A[y - 1, x] := 4;  AO.A[y - 1, x - 1] := 4
	END Uniform;

	PROCEDURE Handler*( o: Objects.Object;  VAR M: Objects.ObjMsg );
	BEGIN
		WITH o: tModel DO
			IF M IS antsKernel.samplingMsg THEN
				WITH M: antsKernel.samplingMsg DO OneSweep( M.dlink( antsKernel.Kernel ) );
				END;
			ELSIF M IS antsKernel.Init THEN
				WITH M: antsKernel.Init DO Uniform( M.dlink( antsKernel.Kernel ) );
				END;
			ELSIF M IS Objects.FileMsg THEN
				WITH M: Objects.FileMsg DO
					IF M.id = Objects.load THEN antsModels.Handler( o, M );  LoadM( M.R, o )
					ELSIF M.id = Objects.store THEN antsModels.Handler( o, M );  StoreM( M.R, o )
					END;
				END;
			ELSIF M IS Objects.AttrMsg THEN
				WITH M: Objects.AttrMsg DO
					IF M.id = Objects.enum THEN M.Enum( "hprobability" );  M.Enum( "vprobability" );  antsModels.Handler( o, M )
					ELSIF M.id = Objects.get THEN
						IF M.name = "Gen" THEN COPY( 'antsAztec.Gen', M.s );  M.class := Objects.String;  M.res := 0;  RETURN
						ELSIF M.name = "hprobability" THEN M.y := o.horprob;  M.class := Objects.LongReal;  M.res := 0;  RETURN
						ELSIF M.name = "vprobability" THEN M.y := 1 - o.horprob;  M.class := Objects.LongReal;  M.res := 0;  RETURN
						ELSE antsModels.Handler( o, M )
						END

					ELSIF M.id = Objects.set THEN
						IF M.name = "hprobability" THEN
							IF M.class = Objects.LongReal THEN o.horprob := M.y;  M.res := 0;  Gadgets.Update( o );  RETURN END
						ELSIF M.name = "vprobability" THEN
							IF M.class = Objects.LongReal THEN o.horprob := 1 - M.y;  M.res := 0;  Gadgets.Update( o );  RETURN END
						ELSE antsModels.Handler( o, M )
						END
					ELSE antsModels.Handler( o, M )
					END

				END;
			ELSE antsModels.Handler( o, M )
			END
		END  (* tVector*)
	END Handler;

	PROCEDURE OpenModel*( M: tModel;  name: vyName.tNameArray );
	BEGIN
		IF M.handle # NIL THEN M.handle := Handler END;
		vyName.RegisterNamed( M, name )
	END OpenModel;

	PROCEDURE Gen*;
	VAR m: tModel;
	BEGIN
		NEW( m );  m.handle := Handler;  Objects.NewObj := m;  m.horprob := 0.5;  antsObjects.Register( m )
	END Gen;

	PROCEDURE NewModel*;
	VAR l: antsCommands.tScanList;  name: vyName.tNameArray;  M: tModel;
	BEGIN
		l := antsCommands.ScanFromPar( "name=NAME" );
		IF antsCommands.ExpectNameFromKeyword( l, "name", name ) THEN
			Gen;  M := Objects.NewObj( tModel );  antsModels.Open( M );  OpenModel( M, name )
		END
	END NewModel;

BEGIN
	aM.launch;
END antsAztec.

System.Free antsAztec~

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


fofAutomatic.Do
antsArrayObjects.New testarray 400 400 6 ~
antsArrayPictures.New testpict testarray ~
Voyager.Show testpict as antsPictureViews ~
antsAztec.NewModel  > name Model  ~
antsKernel.Define > name Sampler ~
antsKernel.AttachModel > sampler Sampler > model Model ~
antsKernel.AttachArray > sampler Sampler > array testarray ~
antsMC.New chain ~
antsMC.Add chain Sampler ~

~

antsMC.Init chain ~
fofAutomatic.Do > interactive
antsMC.Forward chain 1 1 ~
~

antsMC.Jump chain 0 ~

