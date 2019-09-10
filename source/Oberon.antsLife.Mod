MODULE antsLife IN Oberon;   (** fof  **)
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




IMPORT antsObjects, Objects, Files, antsArrayObjects, antsKernel, antsModels, antsCommands, vyName, Links, aM := antsMessages;

TYPE

	tModel* = POINTER TO tModelDesc;
	tModelDesc* = RECORD (antsModels.tModelDesc);
		synchroneus: BOOLEAN
	END;

	PROCEDURE StoreM( VAR R: Files.Rider;  s: tModel );
	BEGIN
		Files.WriteInt( R, 0 )
	END StoreM;

	PROCEDURE LoadM( VAR R: Files.Rider;  s: tModel );
	VAR version: SIGNED16;
	BEGIN
		Files.ReadInt( R, version )
	END LoadM;

	PROCEDURE OneSweep( s: antsKernel.Kernel );
	VAR x, y, maxx, maxy: SIGNED32;  A: antsArrayObjects.tINTEGERArray;  ym, yp, xm, xp, config: SIGNED32;  model: tModel;
		AO: antsArrayObjects.tINTEGERObject;  tempA: antsArrayObjects.tINTEGERObject;  orig: Objects.Object;

		PROCEDURE DistriFromLocalChar;
		BEGIN
			config := 0;
			IF A[ym, x] = 1 THEN INC( config, 1 ) END;
			IF A[y, xm] = 1 THEN INC( config, 1 ) END;
			IF A[yp, x] = 1 THEN INC( config, 1 ) END;
			IF A[y, xp] = 1 THEN INC( config, 1 ) END;
			IF A[ym, xm] = 1 THEN INC( config, 1 ) END;
			IF A[ym, xp] = 1 THEN INC( config, 1 ) END;
			IF A[yp, xm] = 1 THEN INC( config, 1 ) END;
			IF A[yp, xp] = 1 THEN INC( config, 1 ) END;
			IF config = 3 THEN tempA.A[y, x] := 1
			ELSIF config = 2 THEN tempA.A[y, x] := A[y, x]
			ELSE tempA.A[y, x] := 0
			END
		END DistriFromLocalChar;

		PROCEDURE CorrectBorder;
		BEGIN
			IF x = 0 THEN xm := maxx ELSE xm := x - 1 END;
			IF x = maxx THEN xp := 0 ELSE xp := x + 1 END;
			IF y = maxy THEN yp := 0 ELSE yp := y + 1 END;
			IF y = 0 THEN ym := maxy ELSE ym := y - 1 END
		END CorrectBorder;

		PROCEDURE SimpleBorder;
		BEGIN
			xm := x - 1;  xp := x + 1;  ym := y - 1;  yp := y + 1
		END SimpleBorder;

	BEGIN
		model := s.par( tModel );  AO := s.A( antsArrayObjects.tINTEGERObject );
		IF model.synchroneus THEN Links.GetLink( AO, "orig", orig );  tempA := orig( antsArrayObjects.tINTEGERObject )
		ELSE tempA := s.A( antsArrayObjects.tINTEGERObject )
		END;
		maxx := AO.w - 1;  maxy := AO.h - 1;  A := AO.A;  y := 0;
		FOR x := 0 TO maxx DO CorrectBorder();  DistriFromLocalChar() END;
		FOR y := 1 TO maxy - 1 DO
			x := 0;  CorrectBorder();  DistriFromLocalChar();
			FOR x := 1 TO maxx - 1 DO SimpleBorder();  DistriFromLocalChar() END;
			x := maxx;  CorrectBorder();  DistriFromLocalChar()
		END;
		y := maxy;
		FOR x := 0 TO maxx DO CorrectBorder();  DistriFromLocalChar() END;
		IF model.synchroneus THEN
			FOR x := 0 TO maxx DO
				FOR y := 0 TO maxy DO A[y, x] := tempA.A[y, x] END
			END
		END
	END OneSweep;

	PROCEDURE Uniform( s: antsKernel.Kernel );
	BEGIN
		antsArrayObjects.UniformO( s.A( antsArrayObjects.tINTEGERObject ) );
		s.A( antsArrayObjects.tINTEGERObject ).Cache := NIL
	END Uniform;

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
					IF M.id = Objects.enum THEN M.Enum( "synchroneus" );  antsModels.Handler( o, M )
					ELSIF M.id = Objects.get THEN
						IF M.name = "Gen" THEN COPY( 'antsantsLife.Gen', M.s );  M.class := Objects.String;  M.res := 0;  RETURN
						ELSIF M.name = "synchroneus" THEN M.class := Objects.Bool;  M.b := o.synchroneus;  M.res := 0;  RETURN
						ELSE antsModels.Handler( o, M )
						END
					ELSIF M.id = Objects.set THEN
						IF M.name = "synchroneus" THEN
							IF M.class = Objects.Bool THEN o.synchroneus := M.b;  M.res := 0 END
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

	PROCEDURE OpenModel*( M: tModel;  name: vyName.tNameArray;  beta, h: FLOAT64 );
	BEGIN
		IF M.handle # NIL THEN M.handle := Handler END;
		vyName.RegisterNamed( M, name )
	END OpenModel;

	PROCEDURE Gen*;
	VAR m: tModel;
	BEGIN
		aM.cmd;  NEW( m );  m.handle := Handler;  Objects.NewObj := m;  antsObjects.Register( m );  m.synchroneus := TRUE
	END Gen;

	PROCEDURE NewModel*;
	VAR l: antsCommands.tScanList;  name: vyName.tNameArray;  M: tModel;  beta, h: FLOAT64;
	BEGIN
		l := antsCommands.ScanFromPar( "name=NAME" );
		IF antsCommands.ExpectNameFromKeyword( l, "name", name ) THEN
			Gen;  M := Objects.NewObj( tModel );  antsModels.Open( M );  OpenModel( M, name, beta, h )
		END
	END NewModel;

BEGIN
	aM.launch;
END antsLife.

System.Free antsLife antsModels~

fofAutomatic.Do
antsArrayObjects.New testarray 200 200 2 ~
antsArrayPictures.New testpict testarray ~
Voyager.Show testpict as antsPictureViews ~
antsLife.NewModel > name Model   ~
antsKernel.Define > name Sampler ~
antsKernel.AttachModel > sampler Sampler > model Model ~
antsKernel.AttachArray > sampler Sampler > array testarray ~
antsMC.New chain ~
antsMC.Add chain Sampler ~
antsObjects.WriteAttribute Model synchroneus FALSE ~




antsToolbox.FrameToGIF Film ~
antsMC.Init chain ~
fofAutomatic.Do > interactive
antsMC.Forward chain 1 1 ~
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

(* old:
MODULE antsLife; 	(** fof  **)
(* Sample from nearest neighbour non isotropic conditional distribution  *)

IMPORT antsPictArray,Math:=MathL,antsDiscreteFields,Oberon,antsGibbs,vyRandom;

TYPE

tModel* = POINTER TO tModelDesc ;
tModelDesc* = RECORD (antsGibbs.tParameterDesc);
MA: POINTER TO ARRAY OF ARRAY OF SIGNED16;
END;



PROCEDURE OneSweep* (s: antsGibbs.tSampler);
VAR  x,y,maxx,maxy: SIGNED32 ;    A: antsPictArray.tArray;  model: tModel;
xm,xp,ym,yp: SIGNED32;  config: SIGNED32;  AO: antsPictArray.tObject;

PROCEDURE DistriFromLocalChar ();
BEGIN
config := 0;
IF A[ym,x] = 1 THEN INC(config,1) END;
IF A[y,xm] = 1 THEN INC(config,1) END;
IF A[yp,x] = 1 THEN INC(config,1) END;
IF A[y,xp] = 1 THEN INC(config,1) END;
IF A[ym,xm] = 1 THEN INC(config,1) END;
IF A[ym,xp] = 1 THEN INC(config,1) END;
IF A[yp,xm] = 1 THEN INC(config,1) END;
IF A[yp,xp] = 1 THEN INC(config,1) END;
IF config = 3 THEN model.MA[y,x] := 1
ELSIF config = 2 THEN model.MA[y,x] := A[y,x];
ELSE model.MA[y,x] := -1 END;
END DistriFromLocalChar;

PROCEDURE CorrectBorder ();
BEGIN
IF x = 0 THEN xm := maxx ELSE xm := x-1;  END;
IF x= maxx THEN xp := 0 ELSE xp := x+1 END;
IF y = maxy THEN yp := 0 ELSE yp := y+1 END;
IF y = 0 THEN ym := maxy ELSE ym := y-1 END;
END CorrectBorder;

PROCEDURE SimpleBorder ();
BEGIN
xm := x-1;  xp := x+1;  ym := y-1;  yp := y+1;
END SimpleBorder;


BEGIN
model := s.par(tModel);  AO := s.A(antsPictArray.tObject);
maxx := AO.w-1;  maxy := AO.h-1;   A:= AO.A;
y := 0;
FOR x := 0 TO maxx  DO
CorrectBorder();
DistriFromLocalChar()
END;
FOR y := 1 TO maxy-1 DO
x := 0;
CorrectBorder();
DistriFromLocalChar();
FOR x := 1 TO maxx-1 DO
SimpleBorder();
DistriFromLocalChar();
END;
x := maxx;
CorrectBorder();
DistriFromLocalChar();
END;
y := maxy;
FOR x := 0 TO maxx DO
CorrectBorder();
DistriFromLocalChar()
END;
FOR x := 0 TO maxx DO
FOR y := 0 TO maxy DO
A[y,x] := model.MA[y,x];
END;
END;
END OneSweep;

PROCEDURE Uniform* (s: antsGibbs.tSampler);
BEGIN
antsDiscreteFields.DoUniform(s.A(antsPictArray.tObject));
END Uniform;


BEGIN
END antsLife.
*)