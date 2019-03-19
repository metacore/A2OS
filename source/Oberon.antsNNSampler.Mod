MODULE antsNNSampler IN Oberon;   (** fof   **)
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




IMPORT antsObjects, Files, antsKernel, antsModels, antsCommands, vyName, Objects, vyBase, Gadgets, antsFunctions,
	antsArrayObjects, antsSecurity, vyRanBase, vyRandom, Math := MathL IN A2, Links, antsArrays, aM := antsMessages;

TYPE
	tModel* = POINTER TO tModelDesc;
	tModelDesc* = RECORD (antsModels.tModelDesc)
	(*Pars*)
		datafct: antsFunctions.Function;
		ud, u: POINTER TO ARRAY OF ARRAY OF LONGREAL;
		fct: antsFunctions.Function
	END;

CONST
	version* = 0;  moduleName = "antsNNSampler.Gen";
VAR

	PROCEDURE StoreM( VAR R: Files.Rider;  o: tModel );
	BEGIN
		Files.WriteInt( R, version );
		(*Store*)
		Gadgets.WriteRef( R, o.lib, o.datafct );  Gadgets.WriteRef( R, o.lib, o.fct )
	END StoreM;

	PROCEDURE LoadM( VAR R: Files.Rider;  o: tModel );
	VAR version: INTEGER;  ref: Objects.Object;
	BEGIN
		Files.ReadInt( R, version );
		(*Load*)
		Gadgets.ReadRef( R, o.lib, ref );
		IF ref # NIL THEN o.datafct := ref( antsFunctions.Function ) END;
		Gadgets.ReadRef( R, o.lib, ref );
		IF ref # NIL THEN o.fct := ref( antsFunctions.Function ) END
	END LoadM;

	PROCEDURE Metropolis( s: antsKernel.Kernel );
	VAR o: tModel;
		(*
	AO: antsArrayObjects.tObject;
	A: antsArrayObjects.tArray
	*)
		A: antsArrayObjects.tINTEGERObject;  Ao: antsArrayObjects.tINTEGERObject;
		AA, AAo: antsArrayObjects.tINTEGERArray;  y, W, H: LONGINT;  ran: LONGREAL;  depth: LONGINT;  n1, n2, n3, n4, nd, nh: INTEGER;  h, h1, h2, cooling: LONGREAL;
		gen: vyRanBase.tRandom;  zvax, zvay, zva: LONGINT;  orig: Objects.Object;

	BEGIN

		o := s.par( tModel );  cooling := o.coolingTemp;  A := s.A( antsArrayObjects.tINTEGERObject );
		Links.GetLink( A, "orig", orig );  Ao := orig( antsArrayObjects.tINTEGERObject );
		IF Ao.depth # A.depth THEN antsSecurity.Halt( "depth of ORIG and ARRAY differ" ) END;
		IF ~o.synced THEN Sync( o, A.depth );  o.synced := TRUE END;
		H := A.h;  W := A.w;  depth := A.depth;  AA := A.A;  AAo := Ao.A;  gen := vyRanBase.RandomGenerator;
		FOR y := 0 TO (W * H) - 1 DO
			ran := vyRandom.Uniform();  zvax := gen.GetRandomL( gen, W );  zvay := gen.GetRandomL( gen, H );
			zva := gen.GetRandomL( gen, depth - 1 );  n1 := AA[zvay, (zvax - 1) MOD W];  n2 := AA[zvay, (zvax + 1) MOD W];
			n3 := AA[(zvay - 1) MOD H, zvax];  n4 := AA[(zvay + 1) MOD H, zvax];  nd := AAo[zvay, zvax];  nh := AA[zvay, zvax];

			h1 := o.u[zva, n1] + o.u[zva, n2] + o.u[zva, n3] + o.u[zva, n4] + o.ud[zva, nd];
			h2 := o.u[nh, n1] + o.u[nh, n2] + o.u[nh, n3] + o.u[nh, n4] + o.ud[nh, nd];  h := cooling * (h1 - h2);
			IF h >= 0 THEN AA[zvay, zvax] := SHORT( zva );  ELSE
				IF gen.GetRandomU( gen ) < Math.exp( h ) THEN AA[zvay, zvax] := SHORT( zva );  END;
			END;
		END;
		(*
	AO := O(antsArrayObjects.tObject);
	A := AO.A;
	*)
		(* insert one sweep proc here *)
	END Metropolis;

	PROCEDURE OneSweep( s: antsKernel.Kernel );
	VAR o: tModel;
		(*
	AO: antsArrayObjects.tObject;
	A: antsArrayObjects.tArray
	*)
		A: antsArrayObjects.tINTEGERObject;  Ao: antsArrayObjects.tINTEGERObject;
		AA, AAo: antsArrayObjects.tINTEGERArray;  y, x, W, H: LONGINT;  ran, this, z: LONGREAL;  depth, i: LONGINT;  n1, n2, n3, n4, nd: INTEGER;
		orig: Objects.Object;
	BEGIN
		o := s.par( tModel );  A := s.A( antsArrayObjects.tINTEGERObject );  Links.GetLink( A, "orig", orig );
		IF orig # NIL THEN Ao := orig( antsArrayObjects.tINTEGERObject );  ELSE Ao := NIL END;
		IF Ao.depth # A.depth THEN antsSecurity.Halt( "depth of ORIG and ARRAY differ" ) END;
		IF ~o.synced THEN Sync( o, A.depth );  o.synced := TRUE END;
		H := A.h;  W := A.w;  depth := A.depth;  AA := A.A;  AAo := Ao.A;

		FOR y := 0 TO H - 1 DO
			FOR x := 0 TO W - 1 DO
			(* gibbs sampler for testing first *)
				ran := vyRandom.Uniform();  z := 0;
				FOR i := 0 TO depth - 1 DO
					n1 := AA[y, (x - 1) MOD W];  n2 := AA[y, (x + 1) MOD W];  n3 := AA[(y - 1) MOD H, x];
					n4 := AA[(y + 1) MOD H, x];  nd := AAo[y, x];
					z := z + Math.exp( o.u[i, n1] + o.u[i, n2] + o.u[i, n3] + o.u[i, n4] + o.ud[i, nd] );
				END;
				i := 0;  ran := ran * z;  this := Math.exp( o.u[i, n1] + o.u[i, n2] + o.u[i, n3] + o.u[i, n4] + o.ud[i, nd] );
				WHILE (ran > this) DO INC( i );  this := this + Math.exp( o.u[i, n1] + o.u[i, n2] + o.u[i, n3] + o.u[i, n4] + o.ud[i, nd] ) END;
				AA[y, x] := SHORT( i );
			END;
		END;
		(*
	AO := O(antsArrayObjects.tObject);
	A := AO.A;
	*)
		(* insert one sweep proc here *)

	END OneSweep;

	PROCEDURE Sync( m: tModel;  depth: LONGINT );
	VAR y, x: LONGINT;
	BEGIN
		IF (m.u = NIL ) OR (LEN( m.u ) # depth) THEN NEW( m.u, depth, depth );  NEW( m.ud, depth, depth );  END;
		FOR y := 0 TO depth - 1 DO
			FOR x := 0 TO depth - 1 DO
				m.u[y, x] := -m.fct.get( m.fct, ABS( y - x ) / (depth - 1) );
				m.ud[y, x] := -m.datafct.get( m.datafct, ABS( y - x ) / (depth - 1) );
			END;
		END;
	END Sync;

	PROCEDURE Init( s: antsKernel.Kernel );
	VAR A: antsArrayObjects.tINTEGERObject;  AL: antsArrayObjects.tLONGINTArray;

	BEGIN
		A := s.A( antsArrayObjects.tINTEGERObject );
		(* Ao := s.Aorig(antsArrayObjects.tINTEGERObject);
	antsArrayObjects.CopyObject(Ao,A); *)
		AL := antsArrayObjects.NewLONGINTArray( A.w, A.h );  antsArrays.Uniform2dL( AL^, A.depth - 1, 0, 0, A.w, A.h );
		antsArrayObjects.CopyLI( AL, A.A, 0, 0, A.w, A.h, 0, 0 );
	END Init;

	PROCEDURE HandleAttributes( o: tModel;  VAR msg: Objects.AttrMsg );
	BEGIN
		IF msg.id = Objects.enum THEN
			(*AttrEnum*)
			antsModels.Handler( o, msg )
		ELSIF msg.id = Objects.get THEN
			IF msg.name = "Gen" THEN COPY( moduleName, msg.s );  msg.class := Objects.String;  msg.res := 0;  RETURN
			ELSIF msg.name = "dummy" THEN
				(*AttrGet*)
			ELSE antsModels.Handler( o, msg )
			END
		ELSIF msg.id = Objects.set THEN
			IF msg.name = "dummy" THEN
				(*AttrSet*)
			ELSE antsModels.Handler( o, msg )
			END
		ELSE antsModels.Handler( o, msg )
		END
	END HandleAttributes;

	PROCEDURE HandleLinks( o: tModel;  VAR msg: Objects.LinkMsg );
	BEGIN
		IF msg.id = Objects.enum THEN
			(*LinkEnum*)
			msg.Enum( "datafct" );  msg.Enum( "fct" );  antsModels.Handler( o, msg )
		ELSIF msg.id = Objects.get THEN
			IF msg.name = "dummy" THEN
				(*LinkGet*)
			ELSIF msg.name = "datafct" THEN msg.obj := o.datafct;  msg.res := 0;  RETURN;
			ELSIF msg.name = "fct" THEN msg.obj := o.fct;  msg.res := 0;  RETURN;
			ELSE antsModels.Handler( o, msg )
			END
		ELSIF msg.id = Objects.set THEN
			IF msg.name = "dummy" THEN
				(*LinkSet*)
			ELSIF msg.name = "datafct" THEN o.datafct := msg.obj( antsFunctions.Function );  msg.res := 0;  RETURN;
			ELSIF msg.name = "fct" THEN o.fct := msg.obj( antsFunctions.Function );  msg.res := 0;  RETURN;
			ELSE antsModels.Handler( o, msg )
			END
		ELSE antsModels.Handler( o, msg )
		END
	END HandleLinks;

	PROCEDURE HandleBind( o: tModel;  VAR msg: Objects.BindMsg );
	BEGIN
		(*Bind*)
		antsObjects.Bind( o.datafct, msg );  antsObjects.Bind( o.fct, msg );
	END HandleBind;

	PROCEDURE Handler*( o: Objects.Object;  VAR msg: Objects.ObjMsg );
	BEGIN
		WITH o: tModel DO
			IF msg IS antsKernel.samplingMsg THEN
				WITH msg: antsKernel.samplingMsg DO
					antsModels.SetTemperature( o, msg.temp );
					IF msg.action = antsKernel.gibbsSampler THEN OneSweep( msg.dlink( antsKernel.Kernel ) );
					ELSIF msg.action = antsKernel.metropolisSampler THEN Metropolis( msg.dlink( antsKernel.Kernel ) );
					END;
				END;
			ELSIF msg IS antsKernel.Init THEN
				WITH msg: antsKernel.Init DO Init( msg.dlink( antsKernel.Kernel ) );  o.synced := FALSE
				END;
			ELSIF msg IS vyBase.UpdateMessage THEN
				WITH msg: vyBase.UpdateMessage DO vyBase.Update( o );  Gadgets.Update( o );
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
			ELSE antsModels.Handler( o, msg )
			END
		END  (* tVector*)
	END Handler;

	PROCEDURE OpenModel*( msg: tModel;  name: vyName.tNameArray );
	BEGIN
		vyName.RegisterNamed( msg, name )
	END OpenModel;

	PROCEDURE NewPars( o: tModel );
	(*  BEGIN 	NEW(o.par,1); NEW(o.parNames,1);
	o.par[0] := 0; o.parNames[0] := "parName" *)
	END NewPars;

	PROCEDURE Gen*;
	VAR o: tModel;
	BEGIN
		aM.cmd;  NEW( o );  o.handle := Handler;  antsObjects.Register( o );  NewPars( o );  Objects.NewObj := o
	END Gen;

	PROCEDURE DoNewModel*( name: vyName.tNameArray ): tModel;
	VAR o: tModel;
	BEGIN
		Gen;  o := Objects.NewObj( tModel );  antsModels.Open( o );  OpenModel( o, name );  RETURN o
	END DoNewModel;

	PROCEDURE NewModel*;
	VAR name: vyName.tNameArray;  o: tModel;  obj1, obj2: vyBase.Object;
	BEGIN
		antsCommands.InitScan( "name=NAME fct=OBJ datafct=OBJ" );
		IF antsCommands.ExpectName( "name", name ) & antsCommands.ExpectObject( "fct", obj1 ) &
		    antsCommands.ExpectObject( "datafct", obj2 ) THEN
			o := DoNewModel( name );  o.fct := obj1( antsFunctions.Function );  o.datafct := obj2( antsFunctions.Function );
			vyBase.Subscribe( o.datafct, o );  vyBase.Subscribe( o.fct, o );
		END
	END NewModel;

BEGIN
	aM.launch;
END antsNNSampler.

Desktops.OpenWinDoc Caracas3a.Panel ~

System.Free antsNNSampler ~


fofAutomatic.Do
antsFunctions.Define datafunction ~
antsFunctions.Define function ~
antsFunctions.Set function "potts(2)";
antsFunctions.Set datafunction "x*x*100":
antsNNSampler.NewModel testmodel function datafunction ~
antsKernel.Define > name katrinKernel ~
antsKernel.AttachModel > sampler katrinKernel > model testmodel ~
antsKernel.AttachArray > sampler katrinKernel > array f3ArrayO ~
antsMC.New katrinChain ~
antsMC.Add katrinChain katrinKernel ~
~
antsMC.Init katrinChain ~
fofAutomatic.Do > interactive > secure
antsMC.Forward katrinChain 10 10 ~
~


antsObjects.WriteAttribute katrinKernel cooling ~
antsObjects.WriteAttributes katrinKernel ~
antsObjects.WriteAttributes testmodel ~
antsObjects.WriteAttributes katrinChain~

Voyager.Show testmodel as antsDependency ~


ants / src / antsMC.Mod


