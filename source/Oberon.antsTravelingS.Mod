MODULE antsTravelingS IN Oberon;   (** fof   **)
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
	antsVectors, vyLongrealVec, antsSecurity, Math := MathL IN A2, vyRandom, aM := antsMessages;

TYPE
	tModel* = POINTER TO tModelDesc;
	tModelDesc* = RECORD (antsModels.tModelDesc)
	(*Pars*)
		cooling: antsFunctions.Function;
		curlen, curtemp: FLOAT64;
	END;

CONST
	version* = 0;  moduleName = "antsTravelingS.Gen";
VAR

	PROCEDURE StoreM( VAR R: Files.Rider;  o: tModel );
	BEGIN
		Files.WriteInt( R, version );
		(*Store*)
		Gadgets.WriteRef( R, o.lib, o.cooling );  Files.WriteLReal( R, o.curlen );  Files.WriteLReal( R, o.curtemp );
	END StoreM;

	PROCEDURE LoadM( VAR R: Files.Rider;  o: tModel );
	VAR version: SIGNED16;  ref: Objects.Object;
	BEGIN
		Files.ReadInt( R, version );
		(*Load*)
		Gadgets.ReadRef( R, o.lib, ref );
		IF ref # NIL THEN o.cooling := ref( antsFunctions.Function ) END;
		Files.ReadLReal( R, o.curlen );  Files.ReadLReal( R, o.curtemp );
	END LoadM;

	PROCEDURE Length( vx, vy: vyLongrealVec.tVector ): FLOAT64;
	VAR i: SIGNED32;  len: FLOAT64;  x0, x1, y0, y1: FLOAT64;
	BEGIN
		len := 0;  x0 := vyLongrealVec.Get( vx, 0 );  y0 := vyLongrealVec.Get( vy, 0 );
		FOR i := 1 TO vyLongrealVec.Len( vx ) - 1 DO
			x1 := vyLongrealVec.Get( vx, i );  y1 := vyLongrealVec.Get( vy, i );
			len := len + Math.sqrt( (x1 - x0) * (x1 - x0) + (y1 - y0) * (y1 - y0) );  x0 := x1;  y0 := y1;
		END;
		x1 := vyLongrealVec.Get( vx, 0 );  y1 := vyLongrealVec.Get( vy, 0 );
		len := len + Math.sqrt( (x1 - x0) * (x1 - x0) + (y1 - y0) * (y1 - y0) );  RETURN len;
	END Length;

	PROCEDURE Swap( vx, vy: vyLongrealVec.tVector;  a, b: SIGNED32 );
	VAR xa, xb, ya, yb: FLOAT64;
	BEGIN
		IF a = b THEN RETURN END;
		xa := vyLongrealVec.Get( vx, a );  xb := vyLongrealVec.Get( vx, b );  vyLongrealVec.Set( xa, vx, b );
		vyLongrealVec.Set( xb, vx, a );

		ya := vyLongrealVec.Get( vy, a );  yb := vyLongrealVec.Get( vy, b );  vyLongrealVec.Set( ya, vy, b );
		vyLongrealVec.Set( yb, vy, a );
	END Swap;

	PROCEDURE OneSweep( s: antsKernel.Kernel;  pos: SIGNED32 );
	VAR o: tModel;  O: vyBase.Object;  container: antsVectors.Container;  vx, vy, lenvec: vyBase.tVector;  temp: FLOAT64;
		len, ran1, ran2: SIGNED32;  len1, len2: FLOAT64;
	BEGIN
		o := s.par( tModel );  temp := o.cooling.get( o.cooling, pos );  o.curtemp := temp;  O := s.A;
		IF (O # NIL ) & (O IS antsVectors.Container) THEN container := O( antsVectors.Container ) ELSE antsSecurity.Halt( "No Container" );  END;
		vx := antsVectors.GetVector( container, 0 );  vy := antsVectors.GetVector( container, 1 );
		lenvec := antsVectors.GetVector( container, 2 );
		WITH vx: vyLongrealVec.tVector DO
			WITH vy: vyLongrealVec.tVector DO
				len := vyLongrealVec.Len( vx );  len1 := Length( vx, vy );  ran1 := ENTIER( vyRandom.Uniform() * len );
				ran2 := ENTIER( vyRandom.Uniform() * len );  Swap( vx, vy, ran1, ran2 );  len2 := Length( vx, vy );
				IF len2 <= len1 THEN
					o.curlen := len2;   (* accept *)
				ELSE
					IF vyRandom.Uniform() <= Math.exp( temp * (len1 - len2) ) THEN
						o.curlen := len2;   (* still accept *)
					ELSE
						Swap( vx, vy, ran1, ran2 );  o.curlen := len1 (* go back *)
					END;
				END;
				IF lenvec # NIL THEN vyLongrealVec.Append( o.curlen, lenvec( vyLongrealVec.tVector ) );  END;
			END;   (*WITH*)
		END;   (*WITH*)
	END OneSweep;

	PROCEDURE Init( s: antsKernel.Kernel );
	VAR o: tModel;  O: vyBase.Object;  container: antsVectors.Container;  vx, vy, lenvec: vyBase.tVector;  temp: FLOAT64;
	BEGIN
		o := s.par( tModel );  temp := o.cooling.get( o.cooling, 0 );  o.curtemp := temp;  O := s.A;
		IF (O # NIL ) & (O IS antsVectors.Container) THEN container := O( antsVectors.Container ) ELSE antsSecurity.Halt( "No Container" );  END;
		vx := antsVectors.GetVector( container, 0 );  vy := antsVectors.GetVector( container, 1 );
		lenvec := antsVectors.GetVector( container, 2 );
		WITH vx: vyLongrealVec.tVector DO
			WITH vy: vyLongrealVec.tVector DO o.curlen := Length( vx, vy );
			END;
		END;
		IF lenvec # NIL THEN
			vyLongrealVec.SetLen( lenvec( vyLongrealVec.tVector ), 0 );
			vyLongrealVec.Append( o.curlen, lenvec( vyLongrealVec.tVector ) );
		END;
		vyBase.Update( o );
	END Init;

	PROCEDURE HandleAttributes( o: tModel;  VAR msg: Objects.AttrMsg );
	BEGIN
		IF msg.id = Objects.enum THEN
			(*AttrEnum*)
			msg.Enum( "currentLen" );  msg.Enum( "currentTemp" );  antsModels.Handler( o, msg )
		ELSIF msg.id = Objects.get THEN
			IF msg.name = "Gen" THEN COPY( moduleName, msg.s );  msg.class := Objects.String;  msg.res := 0;  RETURN
			ELSIF msg.name = "dummy" THEN
			ELSIF msg.name = "currentLen" THEN msg.class := Objects.LongReal;  msg.y := o.curlen;  msg.res := 0;  RETURN
			ELSIF msg.name = "currentTemp" THEN
				msg.class := Objects.LongReal;  msg.y := o.curtemp;  msg.res := 0;  RETURN

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
			msg.Enum( "cooling" );  antsModels.Handler( o, msg )
		ELSIF msg.id = Objects.get THEN
			IF msg.name = "dummy" THEN
				(*LinkGet*)
			ELSIF msg.name = "cooling" THEN msg.obj := o.cooling;  msg.res := 0;  RETURN;
			ELSE antsModels.Handler( o, msg )
			END
		ELSIF msg.id = Objects.set THEN
			IF msg.name = "dummy" THEN
				(*LinkSet*)
			ELSIF msg.name = "cooling" THEN o.cooling := msg.obj( antsFunctions.Function );  msg.res := 0;  RETURN;
			ELSE antsModels.Handler( o, msg )
			END
		ELSE antsModels.Handler( o, msg )
		END
	END HandleLinks;

	PROCEDURE HandleBind( o: tModel;  VAR msg: Objects.BindMsg );
	BEGIN
		(*Bind*)
		antsObjects.Bind( o.cooling, msg );
	END HandleBind;

	PROCEDURE Handler*( o: Objects.Object;  VAR msg: Objects.ObjMsg );
	BEGIN
		WITH o: tModel DO
			IF msg IS antsKernel.samplingMsg THEN
				WITH msg: antsKernel.samplingMsg DO
					OneSweep( msg.dlink( antsKernel.Kernel ), msg.pos );  antsModels.Handler( o, msg );
				END;
			ELSIF msg IS antsKernel.Init THEN
				WITH msg: antsKernel.Init DO Init( msg.dlink( antsKernel.Kernel ) );
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

	PROCEDURE OpenModel*( msg: tModel;  name: vyName.tNameArray;  cooling: antsFunctions.Function );
	BEGIN
		msg.cooling := cooling;  vyName.RegisterNamed( msg, name )
	END OpenModel;

	PROCEDURE NewPars( o: tModel );
	(* BEGIN NEW(o.par,1); NEW(o.parNames,1);
	o.par[0] := 0; o.parNames[0] := "parName" *)
	END NewPars;

	PROCEDURE Gen*;
	VAR o: tModel;
	BEGIN
		NEW( o );  o.handle := Handler;  antsObjects.Register( o );  NewPars( o );  Objects.NewObj := o
	END Gen;

	PROCEDURE DoNewModel*( name: vyName.tNameArray;  cooling: antsFunctions.Function ): tModel;
	VAR o: tModel;
	BEGIN
		Gen;  o := Objects.NewObj( tModel );  antsModels.Open( o );  OpenModel( o, name, cooling );  RETURN o
	END DoNewModel;

	PROCEDURE NewModel*;
	VAR l: antsCommands.tScanList;  name: vyName.tNameArray;  o: tModel;  function: vyBase.Object;
	BEGIN
		l := antsCommands.ScanFromPar( "name=NAME function=OBJECT" );
		IF antsCommands.ExpectNameFromKeyword( l, "name", name ) & antsCommands.ExpectObjectFromKeyword( l, "function", function ) THEN
			o := DoNewModel( name, function( antsFunctions.Function ) );
		END
	END NewModel;

	PROCEDURE MakeCircle*;
	VAR vx, vy: vyBase.Object;  i, len: SIGNED32;
	BEGIN
		antsCommands.InitScan( "vx=OBJ vy=OBJ [len=INT]" );
		IF antsCommands.ExpectObject( "vx", vx ) & antsCommands.ExpectObject( "vy", vy ) THEN
			WITH vx: vyLongrealVec.tVector DO
				WITH vy: vyLongrealVec.tVector DO
					IF antsCommands.GetNumber( "len", len ) THEN vyLongrealVec.SetLen( vx, len );  vyLongrealVec.SetLen( vy, len );
					ELSE len := vyLongrealVec.Len( vx );
					END;
					FOR i := 0 TO len - 1 DO
						vyLongrealVec.Set( Math.sin( 2 * Math.pi * i / len ), vx, i );
						vyLongrealVec.Set( Math.cos( 2 * Math.pi * i / len ), vy, i );
					END;
					vyBase.Update( vx );
				END;
			END;
		END;
	END MakeCircle;

	PROCEDURE MakeRandom*;
	VAR vx, vy: vyBase.Object;  i, len: SIGNED32;  ran1, ran2: FLOAT64;
	BEGIN
		antsCommands.InitScan( "vx=OBJ vy=OBJ [len=INT]" );
		IF antsCommands.ExpectObject( "vx", vx ) & antsCommands.ExpectObject( "vy", vy ) THEN
			WITH vx: vyLongrealVec.tVector DO
				WITH vy: vyLongrealVec.tVector DO
					len := vyLongrealVec.Len( vx );
					IF antsCommands.GetNumber( "len", len ) THEN vyLongrealVec.SetLen( vx, len );  vyLongrealVec.SetLen( vy, len );
					ELSE len := vyLongrealVec.Len( vx );
					END;
					FOR i := 0 TO len - 1 DO
						ran1 := -1 + 2 * vyRandom.Uniform();  ran2 := -1 + 2 * vyRandom.Uniform();
						vyLongrealVec.Set( ran1, vx, i );  vyLongrealVec.Set( ran2, vy, i );
					END;
					vyBase.Update( vx );
				END;
			END;
		END;

	END MakeRandom;

	PROCEDURE Mix*;
	VAR vx, vy: vyBase.Object;  i, len, ran1, ran2: SIGNED32;
	BEGIN
		antsCommands.InitScan( "vx=OBJ vy=OBJ" );
		IF antsCommands.ExpectObject( "vx", vx ) & antsCommands.ExpectObject( "vy", vy ) THEN
			WITH vx: vyLongrealVec.tVector DO
				WITH vy: vyLongrealVec.tVector DO
					len := vyLongrealVec.Len( vx );
					FOR i := 0 TO len - 1 DO ran1 := ENTIER( vyRandom.Uniform() * len );  ran2 := ENTIER( vyRandom.Uniform() * len );

						Swap( vx, vy, ran1, ran2 );
					END;
					vyBase.Update( vx );
				END;
			END;
		END;
	END Mix;

END antsTravelingS.

System.Free antsTravelingS ~

fofAutomatic.Do
antsFctVector.NewVec vx 50 ~
antsFctVector.NewVec vy 50 ~
antsVecOpt.AddUniformNoise vx vx 1~
antsVecOpt.AddUniformNoise vy vy 1~
antsTravelingS.MakeCircle vx vy
antsTravelingS.Mix vx vy
Voyager.Show vx vy as antsPointPlot2 ~
Voyager.Show vx vy as Charts ~
antsVectors.New container ~
antsVectors.Add container vx
antsVectors.Add container vy
antsKernel.Define Sampler ~
antsKernel.AttachArray Sampler container~
antsFunctions.Define function
antsFunctions.Set function "1"
antsTravelingS.NewModel Model function
antsKernel.AttachModel Sampler Model
antsMC.New Chain
antsMC.ApplyNoInit Chain Sampler
antsMC.Add Chain Sampler
antsObjects.WriteAttribute Model currentLen~
antsObjects.WriteAttribute function Mapping ~
antsObjects.WriteAttribute Model currentTemp ~
~

fofAutomatic.Do >interactive >secure
antsMC.Forward Chain 1 1 ~
~
fofAutomatic.Stop
antsMC.Init Chain ~
antsMC.Forward Chain 1 1 ~
 Voyager.Show vx as antsPointPlot ~
 Voyager.Show vy as antsPointPlot ~
~


