MODULE antsProgRandomWalk IN Oberon;   (** fof   **)
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

IMPORT antsObjects, Files, antsKernel, antsModels, antsCommands, vyName, Objects, vyBase, Gadgets, vyLongrealVec,
	vyRandom, aM := antsMessages;

TYPE
	tModel* = POINTER TO tModelDesc;
	tModelDesc* = RECORD (antsModels.tModelDesc)
	(*Pars*)
		v3: vyBase.Object;
		v2: vyBase.Object;
		v1: vyBase.Object;
		modeltype: SIGNED16 (* 0: Linie, 1: Gitter, 2: Wabe *)
	END;

	function* = PROCEDURE ( VAR v1, v2, v3: FLOAT64 );

CONST
	version* = 1;  moduleName = "antsProgRandomWalk.Gen";  LinieC = 0;  GitterC = 1;  WabeC = 2;
VAR
	gitter*: function;

	PROCEDURE StoreM( VAR R: Files.Rider;  o: tModel );
	BEGIN
		Files.WriteInt( R, version );
		(*Store*)
		Gadgets.WriteRef( R, o.lib, o.v3 );  Gadgets.WriteRef( R, o.lib, o.v2 );  Gadgets.WriteRef( R, o.lib, o.v1 );
		Files.WriteInt( R, o.modeltype )
	END StoreM;

	PROCEDURE LoadM( VAR R: Files.Rider;  o: tModel );
	VAR version: SIGNED16;  ref: Objects.Object;
	BEGIN
		Files.ReadInt( R, version );
		(*Load*)
		Gadgets.ReadRef( R, o.lib, ref );
		IF ref # NIL THEN o.v3 := ref( vyBase.Object ) END;
		Gadgets.ReadRef( R, o.lib, ref );
		IF ref # NIL THEN o.v2 := ref( vyBase.Object ) END;
		Gadgets.ReadRef( R, o.lib, ref );
		IF ref # NIL THEN o.v1 := ref( vyBase.Object ) END;
		IF version > 0 THEN Files.ReadInt( R, o.modeltype ) END
	END LoadM;

	PROCEDURE Gitter( VAR val1, val2, val3: FLOAT64 );
(*
	VAR ran: FLOAT64;
	BEGIN
		ran := vyRandom.Uniform();
	IF ran <1/6 THEN
		val1 := val1 + 0.1
	ELSIF ran < 2/6 THEN
		val1 := val1 - 0.1
	ELSIF ran < 3/6 THEN
		val2 := val2 + 0.1
	ELSIF ran < 4/6 THEN
		val2 := val2 - 0.1
	ELSIF ran < 5/6 THEN
		val3 := val3-0.1;
	ELSE
		val3 := val3+0.1;
	END
	*)
	END Gitter;

(*
PROCEDURE Gitter3d (VAR ran, val1, val2,val3: FLOAT64);
BEGIN
	IF ran <1/6 THEN
		val1 := val1 + 0.1
	ELSIF ran < 2/6 THEN
		val1 := val1 - 0.1
	ELSIF ran < 3/6 THEN
		val2 := val2 + 0.1
	ELSIF ran < 4/6 THEN
		val2 := val2 - 0.1
	ELSIF ran < 5/6 THEN
		val3 := val3-0.1;
	ELSE
		val3 := val3+0.1;
	END
END Gitter3d;

PROCEDURE Linie (VAR ran, val1, val2: FLOAT64);
BEGIN
	IF ran < 0.5 THEN
		val1 := val1 + 1
	ELSE
		val1 := val1 - 1
	END
END Linie;

PROCEDURE Wabe (VAR ran, val1, val2: FLOAT64;  flag: BOOLEAN);
BEGIN
	IF flag THEN
		IF ran < 1 / 3 THEN
			val1 := val1 + 1
		ELSIF ran < 2 / 3 THEN
			val1 := val1 - 1;  val2 := val2 + 1
		ELSE
			val1 := val1 - 1;  val2 := val2 - 1
		END
	ELSE
		IF ran < 1 / 3 THEN
			val1 := val1 - 1
		ELSIF ran < 2 / 3 THEN
			val1 := val1 + 1;  val2 := val2 + 1
		ELSE
			val1 := val1 + 1;  val2 := val2 - 1
		END
	END
END Wabe;
*)


	PROCEDURE OneSweep( s: antsKernel.Kernel );
	VAR o: tModel;  v1, v2, v3: vyLongrealVec.tVector;  val1, val2, val3: FLOAT64;  ran: FLOAT64;
	BEGIN
		o := s.par( tModel );
		(* insert one sweep proc here *)
		v1 := o.v1( vyLongrealVec.tVector );  v2 := o.v2( vyLongrealVec.tVector );  v3 := o.v3( vyLongrealVec.tVector );

		val1 := vyLongrealVec.Get( v1, v1.nrData - 1 );  val2 := vyLongrealVec.Get( v2, v2.nrData - 1 );
		val3 := vyLongrealVec.Get( v3, v3.nrData - 1 );

		gitter( val1, val2, val3 );

		vyLongrealVec.Append( val1, v1 );  vyLongrealVec.Append( val2, v2 );  vyLongrealVec.Append( val3, v3 )

	END OneSweep;

	PROCEDURE Init( s: antsKernel.Kernel );
	VAR o: tModel;  v1, v2, v3: vyLongrealVec.tVector;
	BEGIN
		o := s.par( tModel );  v1 := o.v1( vyLongrealVec.tVector );  v2 := o.v2( vyLongrealVec.tVector );
		v3 := o.v3( vyLongrealVec.tVector );  vyLongrealVec.SetLen( v1, 1 );  vyLongrealVec.SetLen( v2, 1 );
		vyLongrealVec.SetLen( v3, 1 );  vyLongrealVec.Set( 0, v1, 0 );  vyLongrealVec.Set( 0, v2, 0 );
		vyLongrealVec.Set( 0, v3, 0 );  vyBase.Update( v1 );  vyBase.Update( v2 );  vyBase.Update( v3 );
	END Init;

	PROCEDURE HandleAttributes( o: tModel;  VAR msg: Objects.AttrMsg );
	BEGIN
		IF msg.id = Objects.enum THEN
			(*AttrEnum*)
			msg.Enum( "type" );  antsModels.Handler( o, msg )
		ELSIF msg.id = Objects.get THEN
			IF msg.name = "Gen" THEN COPY( moduleName, msg.s );  msg.class := Objects.String;  msg.res := 0;  RETURN
			ELSIF msg.name = "dummy" THEN
				(*AttrGet*)
			ELSIF msg.name = "type" THEN msg.class := Objects.Int;  msg.res := 0;  msg.i := o.modeltype;  RETURN
			ELSE antsModels.Handler( o, msg )
			END
		ELSIF msg.id = Objects.set THEN
			IF msg.name = "dummy" THEN
				(*AttrSet*)
			ELSIF msg.name = "type" THEN
				IF msg.class = Objects.Int THEN o.modeltype := SHORT( msg.i );  msg.res := 0;  RETURN END
			ELSE antsModels.Handler( o, msg )
			END
		ELSE antsModels.Handler( o, msg )
		END
	END HandleAttributes;

	PROCEDURE HandleLinks( o: tModel;  VAR msg: Objects.LinkMsg );
	BEGIN
		IF msg.id = Objects.enum THEN
			(*LinkEnum*)
			msg.Enum( "v3" );  msg.Enum( "v2" );  msg.Enum( "v1" );  antsModels.Handler( o, msg )
		ELSIF msg.id = Objects.get THEN
			IF msg.name = "dummy" THEN
				(*LinkGet*)
			ELSIF msg.name = "v3" THEN msg.obj := o.v3;  msg.res := 0;  RETURN
			ELSIF msg.name = "v2" THEN msg.obj := o.v2;  msg.res := 0;  RETURN
			ELSIF msg.name = "v1" THEN msg.obj := o.v1;  msg.res := 0;  RETURN
			ELSE antsModels.Handler( o, msg )
			END
		ELSIF msg.id = Objects.set THEN
			IF msg.name = "dummy" THEN
				(*LinkSet*)
			ELSIF msg.name = "v3" THEN o.v3 := msg.obj( vyBase.Object );  msg.res := 0;  RETURN
			ELSIF msg.name = "v2" THEN o.v2 := msg.obj( vyBase.Object );  msg.res := 0;  RETURN
			ELSIF msg.name = "v1" THEN o.v1 := msg.obj( vyBase.Object );  msg.res := 0;  RETURN
			ELSE antsModels.Handler( o, msg )
			END
		ELSE antsModels.Handler( o, msg )
		END
	END HandleLinks;

	PROCEDURE HandleBind( o: tModel;  VAR msg: Objects.BindMsg );
	BEGIN
		(*Bind*)
		antsObjects.Bind( o.v3, msg );  antsObjects.Bind( o.v2, msg );  antsObjects.Bind( o.v1, msg )
	END HandleBind;

	PROCEDURE Handler*( o: Objects.Object;  VAR msg: Objects.ObjMsg );
	BEGIN
		WITH o: tModel DO
			IF msg IS antsKernel.samplingMsg THEN
				WITH msg: antsKernel.samplingMsg DO
					antsModels.SetTemperature( o, msg.temp );  OneSweep( msg.dlink( antsKernel.Kernel ) );
				END;
			ELSIF msg IS antsKernel.Init THEN
				WITH msg: antsKernel.Init DO Init( msg.dlink( antsKernel.Kernel ) );  o.synced := FALSE
				END;
			ELSIF msg IS Objects.AttrMsg THEN
				WITH msg: Objects.AttrMsg DO HandleAttributes( o, msg );
				END;
			ELSIF msg IS Objects.LinkMsg THEN
				WITH msg: Objects.LinkMsg DO HandleLinks( o, msg );
				END;
			ELSIF msg IS Objects.FileMsg THEN
				WITH msg: Objects.FileMsg DO
					IF msg.id = Objects.load THEN antsModels.Handler( o, msg );  LoadM( msg.R, o )
					ELSIF msg.id = Objects.store THEN antsModels.Handler( o, msg );  StoreM( msg.R, o )
					END
				END;
			ELSIF msg IS Objects.BindMsg THEN
				WITH msg: Objects.BindMsg DO HandleBind( o, msg );  antsModels.Handler( o, msg )
				END;
			ELSIF msg IS vyBase.UpdateMessage THEN
				WITH msg: vyBase.UpdateMessage DO vyBase.Update( o )
				END;
			ELSE antsModels.Handler( o, msg )
			END
		END  (* tVector*)
	END Handler;

	PROCEDURE OpenModel*( msg: tModel;  name: vyName.tNameArray );
	BEGIN
		vyName.RegisterNamed( msg, name )
	END OpenModel;

	PROCEDURE NewPars( o: tModel );
	(* BEGIN NEW(o.par,1); NEW(o.parNames,1);
	o.par[0] := 0; o.parNames[0] := "parName" *)
	END NewPars;

	PROCEDURE Gen*;
	VAR o: tModel;
	BEGIN
		NEW( o );  o.handle := Handler;  antsObjects.Register( o );  NewPars( o );  Objects.NewObj := o;  o.modeltype := GitterC
	END Gen;

	PROCEDURE DoNewModel*( name: vyName.tNameArray;  o1, o2, o3: vyBase.Object ): tModel;
	VAR o: tModel;
	BEGIN
		Gen;  o := Objects.NewObj( tModel );  antsModels.Open( o );  OpenModel( o, name );  o.v1 := o1;  o.v2 := o2;
		o.v3 := o3;
		(*
	vyBase.Subscribe(o, o1);  vyBase.Subscribe(o, o2);vyBase.Subscribe(o, o3);
	*)
		(* wrong subscription: use antsKernel.Attach to Attach Vectors to KERNEL i/o Model *)
		RETURN o
	END DoNewModel;

	PROCEDURE NewModel*;
	VAR l: antsCommands.tScanList;  name: vyName.tNameArray;  o: tModel;  o1, o2, o3: vyBase.Object;
	BEGIN
		l := antsCommands.ScanFromPar( "name=NAME v1=OBJ v2=OBJ v3=OBJ" );
		IF antsCommands.ExpectNameFromKeyword( l, "name", name ) & antsCommands.ExpectObjectFromKeyword( l, "v1", o1 ) &
		    antsCommands.ExpectObjectFromKeyword( l, "v2", o2 ) & antsCommands.ExpectObjectFromKeyword( l, "v3", o3 ) THEN
			o := DoNewModel( name, o1, o2, o3 )
		END
	END NewModel;

BEGIN
	gitter := Gitter;
END antsProgRandomWalk.


 * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *

System.Free RandomWalk ~
System.Free TestTemplate RandomWalk ~


(** two dimensional model : **)

fofAutomatic.Do
antsMC.New myChain ~
antsKernel.Define myKernel ~
antsMC.Add myChain myKernel ~
antsFctVector.NewVec v1 1~
antsFctVector.NewVec v2 1~
RandomWalk.NewModel myModel v1 v2 ~
antsKernel.AttachModel myKernel myModel ~

Voyager.Show v2 v1 as Charts ~
vyGraphicCtl.SetC2d -100 -100 200 200 ~
vyScale.Insert ~
vyGrid.Insert 0 0 10000 10000 ~
Voyager.Show v2 v1~
antsObjects.SetAttribute LAYER ViewLastOnly TRUE ~
antsObjects.SetAttribute LAYER selectcol 1 ~
antsObjects.SetAttribute LAYER pensize 3 ~
vyGraphicCtl.SetC2d -100 -100 200 200 ~
vyScale.Insert ~
vyGrid.Insert 0 0 10000 10000 ~

antsMC.Init myChain ~
~

fofAutomatic.Do > interactive
antsMC.Forward myChain 1 1 ~
~
fofAutomatic.Do > interactive
antsMC.Forward myChain 1000 1 ~
~
antsObjects.SetAttribute myModel type 2 ~
~
antsObjects.WriteAttributes myModel ~
~

Voyager.Show v1 v2 ~



(** 3 dimensional model **)










fofAutomatic.Do
antsMC.New myChain ~
antsKernel.Define myKernel ~
antsMC.Add myChain myKernel ~
antsFctVector.NewVec v1 1~
antsFctVector.NewVec v2 1~
antsFctVector.NewVec v3 1~
antsProgRandomWalk.NewModel myModel v1 v2 v3~
antsKernel.AttachModel myKernel myModel ~
antsKernel.AttachArray myKernel v1 ~
antsKernel.AttachArray myKernel v2 ~
antsKernel.AttachArray myKernel v3 ~


vyOut.Ln
Voyager.Show v2 v1 as Charts ~
vyGraphicCtl.SetC2d -10 -10 20 20 ~
vyScale.Insert ~
vyGrid.Insert 0 0 10000 10000 ~
Voyager.Show v2 v1~
antsObjects.SetAttribute LAYER ViewLastOnly TRUE ~
antsObjects.SetAttribute LAYER selectcol 1 ~
antsObjects.SetAttribute LAYER pensize 3 ~
vyGraphicCtl.SetC2d -10 -10 20 20 ~
vyScale.Insert ~
vyGrid.Insert 0 0 10000 10000 ~

vyOut.Ln
Voyager.Show v3 v1 as Charts ~
vyGraphicCtl.SetC2d -10 -10 20 20 ~
vyScale.Insert ~
vyGrid.Insert 0 0 10000 10000 ~
Voyager.Show v3 v1~
antsObjects.SetAttribute LAYER ViewLastOnly TRUE ~
antsObjects.SetAttribute LAYER selectcol 1 ~
antsObjects.SetAttribute LAYER pensize 3 ~
vyGraphicCtl.SetC2d -10 -10 20 20 ~
vyScale.Insert ~
vyGrid.Insert 0 0 10000 10000 ~

vyOut.Ln
Voyager.Show v3 v2 as Charts ~
vyGraphicCtl.SetC2d -10 -10 20 20 ~
vyScale.Insert ~
vyGrid.Insert 0 0 10000 10000 ~
Voyager.Show v3 v2~
antsObjects.SetAttribute LAYER ViewLastOnly TRUE ~
antsObjects.SetAttribute LAYER selectcol 1 ~
antsObjects.SetAttribute LAYER pensize 3 ~
vyGraphicCtl.SetC2d -10 -10 20 20 ~
vyScale.Insert ~
vyGrid.Insert 0 0 10000 10000 ~
antsMC.Init myChain ~
~
vyOut.Ln
Voyager.Show v3 v2 v1 ~
antsMC.Init myChain ~
~
fofAutomatic.Do > interactive
antsMC.Forward myChain 1 1 ~
~
fofAutomatic.Do > interactive
antsMC.Forward myChain 1000 1 ~
~

Voyager.Show v2 v1 ~as Charts ~
vyScale.Insert ~
Voyager.Show v1 as LinePlot ~
Voyager.Show v2 as LinePlot ~
Voyager.Show v1 as Histogram ~


antsObjects.WriteAttributes myChain ~
vyGrid.Insert 0 0 10000 10000 ~

RandomWalk.Text


antsObjects.WriteAttribute myModel type~

vy/src/vyGraphicCtl.Mod
