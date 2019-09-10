MODULE ants1dCup IN Oberon;   (** fof   **)
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




IMPORT antsObjects, Files, antsKernel, antsModels, antsCommands, vyName, Objects, vyBase, Gadgets, vyLongrealVec, Links,
	vyRandom, Math := MathL IN A2, vyRanBase, aM := antsMessages, Attributes;

TYPE
	tModel* = POINTER TO tModelDesc;
	tModelDesc* = RECORD (antsModels.tModelDesc)
	(*Pars*)
		alpha: FLOAT64;
		lambda: FLOAT64
	END;

CONST
	version* = 0;  moduleName = "ants1dCup.Gen";
VAR

	PROCEDURE StoreM( VAR R: Files.Rider;  o: tModel );
	BEGIN
		Files.WriteInt( R, version );
		(*Store*)
		Files.WriteLReal( R, o.alpha );  Files.WriteLReal( R, o.lambda )
	END StoreM;

	PROCEDURE LoadM( VAR R: Files.Rider;  o: tModel );
	VAR version: SIGNED16;
	BEGIN
		Files.ReadInt( R, version );
		(*Load*)
		Files.ReadLReal( R, o.alpha );  Files.ReadLReal( R, o.lambda )
	END LoadM;

	PROCEDURE OneSweep( s: antsKernel.Kernel;  metropolis: BOOLEAN );
	VAR o: tModel;  O: vyBase.Object;  v, ov: vyLongrealVec.tVector;  orig: Objects.Object;  last, this, next, thiso, new: FLOAT64;
		i, j, len: SIGNED32;  alpha, lambda: FLOAT64;  gen: vyRanBase.tRandom;

		(*
	AO: antsArrayObjects.tObject;
	A: antsArrayObjects.tArray
	*)

		PROCEDURE min( a, b: FLOAT64 ): FLOAT64;
		BEGIN
			IF a < b THEN RETURN a ELSE RETURN b END
		END min;

		PROCEDURE Sample;
		VAR ran, h1, h2: FLOAT64;
		BEGIN
			ran := this + vyRandom.Gauss( 0, 1 / (o.coolingTemp + 1) );
			h1 :=
				(thiso - this) * (thiso - this) +
				min( lambda * lambda * ((this - last) * (this - last) + (this - next) * (this - next)), alpha );
			h2 :=
				(thiso - ran) * (thiso - ran) +
				min( lambda * lambda * ((last - ran) * (last - ran) + (ran - next) * (ran - next)), alpha );
			IF h1 > h2 THEN new := ran ELSE
				IF Math.exp( o.coolingTemp * (h1 - h2) ) > vyRandom.Uniform() THEN new := ran;  ELSE new := this;  END;
			END;
		END Sample;

		PROCEDURE GibbsSample;
		CONST from = -0.5;  to = 1.5;  steps = 200;
		VAR stepsize: FLOAT64;  cur, sum, val, ran: FLOAT64;
		BEGIN
			stepsize := (to - from) / steps;  cur := from;  sum := 0;

			WHILE (cur < to + stepsize / 10) DO
				sum :=
					sum +
					Math.exp( -o.coolingTemp *
									  ((thiso - cur) * (thiso - cur) + min( lambda * lambda * ((last - cur) * (last - cur) + (cur - next) * (cur - next)), alpha )) );
				cur := cur + stepsize;
			END;

			ran := vyRandom.Uniform() * sum;  val := 0;  cur := from;
			WHILE (val < ran) DO
				val :=
					val +
					Math.exp( -o.coolingTemp *
									  ((thiso - cur) * (thiso - cur) + min( lambda * lambda * ((last - cur) * (last - cur) + (cur - next) * (cur - next)), alpha )) );
				cur := cur + stepsize;
			END;
			new := cur - stepsize;
		END GibbsSample;

	BEGIN
		o := s.par( tModel );  O := s.A;  alpha := o.alpha;  lambda := o.lambda;  Links.GetLink( O, "orig", orig );
		v := O( vyLongrealVec.tVector );  ov := orig( vyLongrealVec.tVector );  len := vyLongrealVec.Len( v );
		gen := vyRanBase.RandomGenerator;

		FOR j := 0 TO len DO i := gen.GetRandomL( gen, len );

			thiso := vyLongrealVec.Get( ov, i );  this := vyLongrealVec.Get( v, i );
			IF i = 0 THEN last := this ELSE last := vyLongrealVec.Get( v, i - 1 ) END;
			IF i < len - 1 THEN next := vyLongrealVec.Get( v, i + 1 ) ELSE next := this END;

			IF metropolis THEN Sample()
			ELSE GibbsSample();
			END;
			vyLongrealVec.Set( new, v, i );

		END;



		(*
	AO := O(antsArrayObjects.tObject);
	A := AO.A;
	*)
		(* insert one sweep proc here *)
	END OneSweep;

	PROCEDURE Init( s: antsKernel.Kernel );
	VAR o: tModel;  O: vyBase.Object;  v, ov: vyLongrealVec.tVector;  orig: Objects.Object;
	BEGIN
		o := s.par( tModel );  O := s.A;  Links.GetLink( O, "orig", orig );  v := O( vyLongrealVec.tVector );
		ov := orig( vyLongrealVec.tVector );  vyLongrealVec.CopyData( ov, v );  vyBase.Update( v );

	END Init;

	PROCEDURE HandleAttributes( o: tModel;  VAR msg: Objects.AttrMsg );
	VAR width: FLOAT64;  b: BOOLEAN;
	BEGIN
		IF msg.id = Objects.enum THEN
			(*AttrEnum*)
			msg.Enum( "alpha" );  msg.Enum( "lambda" );  msg.Enum( "height" );  msg.Enum( "width" );  antsModels.Handler( o, msg )
		ELSIF msg.id = Objects.get THEN
			IF msg.name = "Gen" THEN COPY( moduleName, msg.s );  msg.class := Objects.String;  msg.res := 0;  RETURN
			ELSIF msg.name = "dummy" THEN
				(*AttrGet*)
			ELSIF (msg.name = "alpha") OR (msg.name = "height") THEN msg.y := o.alpha;  msg.class := Objects.LongReal;  msg.res := 0;  RETURN;
			ELSIF msg.name = "lambda" THEN msg.y := o.lambda;  msg.class := Objects.LongReal;  msg.res := 0;  RETURN;
			ELSIF msg.name = "width" THEN
				msg.y := Math.sqrt( o.alpha ) / o.lambda;  msg.class := Objects.LongReal;  msg.res := 0;  RETURN;
			ELSE antsModels.Handler( o, msg )
			END
		ELSIF msg.id = Objects.set THEN
			IF msg.name = "dummy" THEN
				(*AttrSet*)
			ELSIF (msg.name = "alpha") THEN
				IF msg.class = Objects.LongReal THEN o.alpha := msg.y;  msg.res := 0;  Gadgets.Update( o );  RETURN END;
			ELSIF msg.name = "lambda" THEN
				IF msg.class = Objects.LongReal THEN o.lambda := msg.y;  msg.res := 0;  Gadgets.Update( o );  RETURN END;
			ELSIF msg.name = "width" THEN
				IF msg.class = Objects.LongReal THEN
					o.lambda := Math.sqrt( o.alpha ) / msg.y;  msg.res := 0;  Gadgets.Update( o );  RETURN
				END;
			ELSIF msg.name = "height" THEN
				IF msg.class = Objects.LongReal THEN
					Attributes.GetBool( o, "protect", b );
					IF b = TRUE THEN
						IF msg.y > 10 THEN msg.y := 10
						ELSIF msg.y < 0.01 THEN msg.y := 0.01
						END;
					END;

					width := Math.sqrt( o.alpha ) / o.lambda;  o.alpha := msg.y;  o.lambda := Math.sqrt( o.alpha ) / width;
					Gadgets.Update( o );  RETURN
				END;
			ELSE antsModels.Handler( o, msg )
			END
		ELSE antsModels.Handler( o, msg )
		END
	END HandleAttributes;

	PROCEDURE HandleLinks( o: tModel;  VAR msg: Objects.LinkMsg );
	BEGIN
		IF msg.id = Objects.enum THEN
			(*LinkEnum*)
			antsModels.Handler( o, msg )
		ELSIF msg.id = Objects.get THEN
			IF msg.name = "dummy" THEN
				(*LinkGet*)
			ELSE antsModels.Handler( o, msg )
			END
		ELSIF msg.id = Objects.set THEN
			IF msg.name = "dummy" THEN
				(*LinkSet*)
			ELSE antsModels.Handler( o, msg )
			END
		ELSE antsModels.Handler( o, msg )
		END
	END HandleLinks;

	PROCEDURE HandleBind( o: tModel;  VAR msg: Objects.BindMsg );
		(*Bind*)
	END HandleBind;

	PROCEDURE Handler*( o: Objects.Object;  VAR msg: Objects.ObjMsg );
	BEGIN
		WITH o: tModel DO
			IF msg IS antsKernel.samplingMsg THEN
				WITH msg: antsKernel.samplingMsg DO
					antsModels.SetTemperature( o, msg.temp );
					OneSweep( msg.dlink( antsKernel.Kernel ), msg.action = antsKernel.metropolisSampler );
					antsModels.Handler( o, msg );
				END;
			ELSIF msg IS antsKernel.Init THEN
				WITH msg: antsKernel.Init DO
					Init( msg.dlink( antsKernel.Kernel ) );  o.synced := FALSE;  antsModels.Handler( o, msg );
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
	(* BEGIN NEW(o.par,1); NEW(o.parNames,1);
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
	VAR name: vyName.tNameArray;  o: tModel;
	BEGIN
		antsCommands.InitScan( "name=NAME ~#create new cupSampler, important attributes: alpha,lambda" );
		IF antsCommands.ExpectName( "name", name ) THEN o := DoNewModel( name );  o.alpha := 1;  o.lambda := 1;  END
	END NewModel;

BEGIN
	aM.launch;
END ants1dCup.


fofAutomatic.Do
ants1dCup.NewModel > name Model ~
antsKernel.Define > name Kernel ~
antsKernel.AttachModel > sampler Kernel > model Model ~
antsKernel.AttachArray > sampler Kernel > array  restauration~
antsObjects.SetLnk restauration noise orig ~
antsMC.New Chain ~
antsMC.Add Chain Kernel ~
~
antsObjects.WriteAttributes Model ~
antsObjects.WriteAttributes Kernel ~



System.Free ants1dCup ~

antsMC.Init Chain ~
fofAutomatic.Do > interactive > secure
antsMC.Forward Chain 1 1 ~
~
