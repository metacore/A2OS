MODULE antsBinaryIsingS IN Oberon;   (** fof  **)
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




IMPORT antsObjects, Objects, Files, vyHostTexts, antsArrayObjects, Math := MathL IN A2, antsKernel, antsModels, antsRandom,
	antsCommands, vyName, vyBase, Gadgets, antsArrays, Links, aM := antsMessages;

TYPE
	ProbVec = ARRAY 5 OF LONGINT;
	RandomArray = POINTER TO ARRAY OF LONGINT;

	tModel* = POINTER TO tModelDesc;
	tModelDesc* = RECORD (antsModels.tModelDesc);
		h-, beta-: LONGREAL;
		Prob-: ProbVec;
		ran: RandomArray
	END;

	PROCEDURE Open*( M: tModel;  beta, h: LONGREAL;  cool: LONGREAL );
	VAR i: LONGINT;
	BEGIN
		M.h := h;  M.beta := beta;
		FOR i := 0 TO 4 DO
			M.Prob[i] :=
				ENTIER( (Math.exp( cool * (beta * (i - 2) * 2 + h) ) / (Math.exp( cool * (beta * (i - 2) * 2 + h) ) + Math.exp( cool * (-beta * (i - 2) * 2 - h) ))) *
				   antsRandom.max() )
		END;
		M.synced := TRUE;  Gadgets.Update( M )
	END Open;

	PROCEDURE StoreM( VAR R: Files.Rider;  s: tModel );
	BEGIN
		Files.WriteInt( R, 0 );  Files.WriteLReal( R, s.h );  Files.WriteLReal( R, s.beta )
	END StoreM;

	PROCEDURE LoadM( VAR R: Files.Rider;  s: tModel );
	VAR version: INTEGER;
	BEGIN
		Files.ReadInt( R, version );  Files.ReadLReal( R, s.h );  Files.ReadLReal( R, s.beta );  Open( s, s.beta, s.h, s.coolingTemp )
	END LoadM;

	PROCEDURE OneSweep( s: antsKernel.Kernel );
	VAR x, y, w, h, maxx, maxy: LONGINT;  A: antsArrayObjects.tINTEGERArray;  model: tModel;
		AO: antsArrayObjects.tINTEGERObject;  nsums: antsArrayObjects.tINTEGERArray;  prob: ProbVec;
		Random: RandomArray;  ran: LONGINT;

		PROCEDURE Cache( ): antsArrayObjects.tINTEGERArray;
		VAR x, y: LONGINT;
		BEGIN
			IF AO.Cache = NIL THEN
				AO.Cache := antsArrayObjects.NewINTEGERArray( AO.w, AO.h );  nsums := AO.Cache;
				FOR y := 0 TO maxy DO
					FOR x := 0 TO maxx DO
						nsums[y, x] := 0;  nsums[y, x] := nsums[y, x] + A[(y - 1) MOD h, x];
						nsums[y, x] := nsums[y, x] + A[(y + 1) MOD h, x];  nsums[y, x] := nsums[y, x] + A[y, (x + 1) MOD w];
						nsums[y, x] := nsums[y, x] + A[y, (x - 1) MOD w];
						IF nsums[y, x] < 0 THEN
							vyHostTexts.MsgSISI( "A ", A[(y - 1) MOD h, x], "B ", A[(y + 1) MOD h, x] );
							vyHostTexts.MsgSISI( "C ", A[y, (x + 1) MOD w], "D ", A[y, (x - 1) MOD w] )
						END;
						ASSERT ( nsums[y, x] >= 0 )
					END
				END
			END;
			RETURN AO.Cache
		END Cache;

		PROCEDURE Border;
		BEGIN
			IF Random[x] < prob[nsums[y, x]] THEN
				IF A[y, x] = 0 THEN
					A[y, x] := 1;  INC( nsums[(y - 1) MOD h, x] );  INC( nsums[(y + 1) MOD h, x] );  INC( nsums[y, (x + 1) MOD w] );
					INC( nsums[y, (x - 1) MOD w] )
				END
			ELSE
				IF A[y, x] = 1 THEN
					A[y, x] := 0;  DEC( nsums[(y - 1) MOD h, x] );  DEC( nsums[(y + 1) MOD h, x] );  DEC( nsums[y, (x + 1) MOD w] );
					DEC( nsums[y, (x - 1) MOD w] )
				END
			END
		END Border;

		PROCEDURE Inside;
		BEGIN
			IF ran < prob[nsums[y, x]] THEN
				IF A[y, x] = 0 THEN
					A[y, x] := 1;  INC( nsums[(y - 1), x] );  INC( nsums[(y + 1), x] );  INC( nsums[y, (x + 1)] );  INC( nsums[y, (x - 1)] )
				END
			ELSE
				IF A[y, x] = 1 THEN
					A[y, x] := 0;  DEC( nsums[(y - 1), x] );  DEC( nsums[(y + 1), x] );  DEC( nsums[y, (x + 1)] );  DEC( nsums[y, (x - 1)] )
				END
			END

		END Inside;

	BEGIN
		model := s.par( tModel );  AO := s.A( antsArrayObjects.tINTEGERObject );
		IF ~model.synced THEN Open( model, model.beta, model.h, model.coolingTemp );  AO.Cache := NIL END;
		IF (model.ran = NIL ) OR (LEN( model.ran ) # AO.w) THEN NEW( model.ran, AO.w ) END;
		Random := model.ran;


		(* antsArrayObjects.UniformL(AO.w,AO.h,antsRandom.max()); Random := antsArrayObjects.RandomL; *)
		(*
	IF AO.depth # 2 THEN s.fatalerror := TRUE;  s.errormsg := "antsBinaryIsingS: can only sample from Arrays with depth = 2";  RETURN END;
	*)
		w := AO.w;  h := AO.h;  maxx := w - 1;  maxy := h - 1;  A := AO.A;  prob := model.Prob;  nsums := Cache();  y := 0;
		antsArrays.Uniform1dL( Random^, 0, LEN( Random ), antsRandom.max() );
		FOR x := 0 TO maxx DO Border() END;

		FOR y := 1 TO maxy - 1 DO
			x := 0;  Border();  antsArrays.Uniform1dL( Random^, 0, LEN( Random ), antsRandom.max() );
			FOR x := 1 TO maxx - 1 DO
				ran := Random[x];
				(*
			SYSTEM.GET(adr,ran); INC(adr,step);
			*)
				Inside()
			END;
			x := maxx;  Border()
		END;
		y := maxy;  antsArrays.Uniform1dL( Random^, 0, LEN( Random ), antsRandom.max() );
		FOR x := 0 TO maxx DO Border() END

	END OneSweep;

	PROCEDURE Uniform( s: antsKernel.Kernel );
	BEGIN
		antsArrayObjects.UniformO( s.A( antsArrayObjects.tObject ) );  s.A( antsArrayObjects.tINTEGERObject ).Cache := NIL
	END Uniform;

	PROCEDURE CopyOrig( s: antsKernel.Kernel );
	VAR A: antsArrayObjects.tINTEGERObject;  obj: Objects.Object;  orig: antsArrayObjects.tINTEGERObject;
	BEGIN
		A := s.A( antsArrayObjects.tINTEGERObject );  Links.GetLink( A, "orig", obj );
		IF obj # NIL THEN orig := obj( antsArrayObjects.tINTEGERObject ) ELSE orig := NIL END;
		IF orig = NIL THEN Uniform( s ) ELSE antsArrayObjects.CopyII( orig.A, A.A, 0, 0, A.w, A.h, 0, 0 ) END;
		s.A( antsArrayObjects.tINTEGERObject ).Cache := NIL
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
					IF M.id = Objects.enum THEN M.Enum( "beta" );  M.Enum( "h" );  antsModels.Handler( o, M )
					ELSIF M.id = Objects.get THEN
						IF M.name = "Gen" THEN COPY( 'antsBinaryIsingS.Gen', M.s );  M.class := Objects.String;  M.res := 0;  RETURN
						ELSIF M.name = "beta" THEN M.class := Objects.LongReal;  M.y := o.beta;  M.res := 0;  RETURN
						ELSIF M.name = "h" THEN M.class := Objects.LongReal;  M.y := o.h;  M.res := 0;  RETURN
						ELSE antsModels.Handler( o, M )
						END

					ELSIF M.id = Objects.set THEN
						IF M.name = "beta" THEN
							IF M.class = Objects.LongReal THEN
								o.beta := M.y;  o.synced := FALSE;  M.res := 0;  vyBase.Update( o );  RETURN
							END
						ELSIF M.name = "h" THEN
							IF M.class = Objects.LongReal THEN o.h := M.y;  o.synced := FALSE;  M.res := 0;  vyBase.Update( o );  RETURN END
						ELSE antsModels.Handler( o, M )
						END
					ELSE antsModels.Handler( o, M )
					END

				END;
			ELSE antsModels.Handler( o, M )
			END
		END  (* tVector*)
	END Handler;

	PROCEDURE OpenModel*( M: tModel;  name: vyName.tNameArray;  beta, h: LONGREAL );
	BEGIN
		Open( M, beta, h, 1 );
		IF M.handle # NIL THEN M.handle := Handler END;
		vyName.RegisterNamed( M, name )
	END OpenModel;

	PROCEDURE Gen*;
	VAR m: tModel;
	BEGIN
		aM.cmd;  NEW( m );  m.handle := Handler;  Objects.NewObj := m;  antsObjects.Register( m )
	END Gen;

	PROCEDURE NewModel*;
	VAR l: antsCommands.tScanList;  name: vyName.tNameArray;  M: tModel;  beta, h: LONGREAL;
	BEGIN
		l := antsCommands.ScanFromPar( "name=NAME beta=REAL h=REAL" );
		IF antsCommands.ExpectNameFromKeyword( l, "name", name ) & antsCommands.ExpectRealFromKeyword( l, "beta", beta ) &
		    antsCommands.ExpectRealFromKeyword( l, "h", h ) THEN
			Gen;  M := Objects.NewObj( tModel );  antsModels.Open( M );  OpenModel( M, name, beta, h )
		END
	END NewModel;

BEGIN
	aM.launch;
END antsBinaryIsingS.

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