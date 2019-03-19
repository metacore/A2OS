MODULE antsRandomWalk IN Oberon;   (** fof   **)
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
	vyRandom, vyLinePlot, vyPort, vyDisplay2d, vyLinks, vyTexts := vyHostTexts, Attributes, Strings := vyHostStrings;

TYPE
	tModel* = POINTER TO tModelDesc;
	tModelDesc* = RECORD (antsModels.tModelDesc)
	(*Pars*)
		v2: vyBase.Object;
		v1: vyBase.Object;
		ph: LONGREAL;
		pv: LONGREAL;
	END;

CONST
	version* = 0;  moduleName = "antsRandomWalk.Gen";
VAR

	PROCEDURE StoreM( VAR R: Files.Rider;  o: tModel );
	BEGIN
		Files.WriteInt( R, version );
		(*Store*)
		Gadgets.WriteRef( R, o.lib, o.v2 );  Gadgets.WriteRef( R, o.lib, o.v1 );  Files.WriteLReal( R, o.ph );
		Files.WriteLReal( R, o.pv );
	END StoreM;

	PROCEDURE LoadM( VAR R: Files.Rider;  o: tModel );
	VAR version: INTEGER;  ref: Objects.Object;
	BEGIN
		Files.ReadInt( R, version );
		(*Load*)
		Gadgets.ReadRef( R, o.lib, ref );
		IF ref # NIL THEN o.v2 := ref( vyBase.Object ) END;
		Gadgets.ReadRef( R, o.lib, ref );
		IF ref # NIL THEN o.v1 := ref( vyBase.Object ) END;
		Files.ReadLReal( R, o.ph );  Files.ReadLReal( R, o.pv );
	END LoadM;

	PROCEDURE OneSweep( s: antsKernel.Kernel );
	VAR o: tModel;  O: vyBase.Object;  u1, u2, val1, val2, min, max: LONGREAL;  v1, v2: vyLongrealVec.tVector;
		(*
	AO: antsArrayObjects.tObject;
	A: antsArrayObjects.tArray
	*)
	BEGIN
		o := s.par( tModel );  O := s.A;  v1 := o.v1( vyLongrealVec.tVector );  v2 := o.v2( vyLongrealVec.tVector );
		(*
	AO := O(antsArrayObjects.tObject);
	A := AO.A;
	*)
		(* insert one sweep proc here *)
		u1 := vyRandom.Uniform();  u2 := vyRandom.Uniform();  val1 := vyLongrealVec.Get( v1, v1.nrData - 1 );
		val2 := vyLongrealVec.Get( v2, v2.nrData - 1 );

		IF (Attributes.FindAttr( "min", o.attr ) # NIL ) & (Attributes.FindAttr( "max", o.attr ) # NIL ) THEN
			Attributes.GetLongReal( o, "min", min );  Attributes.GetLongReal( o, "max", max );
			IF val1 < min THEN val1 := min END;
			IF val1 > max THEN val1 := max END;
		END;

		IF u1 < 0.25 THEN val1 := val1 + 1
		ELSIF u1 < 0.5 THEN val1 := val1 - 1
		ELSIF u1 < 0.75 THEN val2 := val2 + 1
		ELSE val2 := val2 - 1
		END;

		(*
	IF u2 < 0.5 THEN val2 := val2 +1 ELSE val2 := val2-1 END;
	*)
		vyLongrealVec.Append( val1, v1 );  vyLongrealVec.Append( val2, v2 );

		(*	vyBase.Update(v1); vyBase.Update(v2); *)


	END OneSweep;

	PROCEDURE Init( s: antsKernel.Kernel );
	VAR o: tModel;  O: vyBase.Object;
	BEGIN
		o := s.par( tModel );  vyLongrealVec.SetLen( o.v1( vyLongrealVec.tVector ), 1 );
		vyLongrealVec.SetLen( o.v2( vyLongrealVec.tVector ), 1 );  vyBase.Update( o.v1 );  vyBase.Update( o.v2 );
	END Init;

	PROCEDURE HandleAttributes( o: tModel;  VAR msg: Objects.AttrMsg );
	BEGIN
		IF msg.id = Objects.enum THEN
			(*AttrEnum*)
			msg.Enum( "ph" );  msg.Enum( "pv" );  antsModels.Handler( o, msg )
		ELSIF msg.id = Objects.get THEN
			IF msg.name = "Gen" THEN COPY( moduleName, msg.s );  msg.class := Objects.String;  msg.res := 0;  RETURN
			ELSIF msg.name = "dummy" THEN
				(*AttrGet*)
			ELSIF msg.name = "ph" THEN msg.y := o.ph;  msg.class := Objects.LongReal;  msg.res := 0;  RETURN;
			ELSIF msg.name = "pv" THEN msg.y := o.pv;  msg.class := Objects.LongReal;  msg.res := 0;  RETURN;
			ELSE antsModels.Handler( o, msg )
			END
		ELSIF msg.id = Objects.set THEN
			IF msg.name = "dummy" THEN
				(*AttrSet*)
			ELSIF msg.name = "ph" THEN
				IF msg.class = Objects.LongReal THEN o.ph := msg.y;  msg.res := 0;  RETURN END;
			ELSIF msg.name = "pv" THEN
				IF msg.class = Objects.LongReal THEN o.pv := msg.y;  msg.res := 0;  RETURN END;
			ELSE antsModels.Handler( o, msg )
			END
		ELSE antsModels.Handler( o, msg )
		END
	END HandleAttributes;

	PROCEDURE HandleLinks( o: tModel;  VAR msg: Objects.LinkMsg );
	BEGIN
		IF msg.id = Objects.enum THEN
			(*LinkEnum*)
			msg.Enum( "v2" );  msg.Enum( "v1" );  antsModels.Handler( o, msg )
		ELSIF msg.id = Objects.get THEN
			IF msg.name = "dummy" THEN
				(*LinkGet*)
			ELSIF msg.name = "v2" THEN msg.obj := o.v2;  msg.res := 0;  RETURN;
			ELSIF msg.name = "v1" THEN msg.obj := o.v1;  msg.res := 0;  RETURN;
			ELSE antsModels.Handler( o, msg )
			END
		ELSIF msg.id = Objects.set THEN
			IF msg.name = "dummy" THEN
				(*LinkSet*)
			ELSIF msg.name = "v2" THEN o.v2 := msg.obj( vyBase.Object );  msg.res := 0;  RETURN;
			ELSIF msg.name = "v1" THEN o.v1 := msg.obj( vyBase.Object );  msg.res := 0;  RETURN;
			ELSE antsModels.Handler( o, msg )
			END
		ELSE antsModels.Handler( o, msg )
		END
	END HandleLinks;

	PROCEDURE HandleBind( o: tModel;  VAR msg: Objects.BindMsg );
	BEGIN
		(*Bind*)
		antsObjects.Bind( o.v2, msg );  antsObjects.Bind( o.v1, msg );
	END HandleBind;

	PROCEDURE Handler*( o: Objects.Object;  VAR msg: Objects.ObjMsg );
	BEGIN
		WITH o: tModel DO
			IF msg IS antsKernel.samplingMsg THEN
				WITH msg: antsKernel.samplingMsg DO
					antsModels.SetTemperature( o, msg.temp );  OneSweep( msg.dlink( antsKernel.Kernel ) );
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
				WITH msg: vyBase.UpdateMessage DO
					vyBase.Update( o );   (* prevents from syncing in Models.Mod *)
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
		NEW( o );  o.handle := Handler;  antsObjects.Register( o );  NewPars( o );  Objects.NewObj := o
	END Gen;

	PROCEDURE DoNewModel*( name: vyName.tNameArray;  v1, v2: vyBase.tVector ): tModel;
	VAR o: tModel;
	BEGIN
		Gen;  o := Objects.NewObj( tModel );  antsModels.Open( o );  OpenModel( o, name );  o.v1 := v1;  o.v2 := v2;
		vyBase.Subscribe( o, v1 );  vyBase.Subscribe( o, v2 );  RETURN o
	END DoNewModel;

	PROCEDURE NewModel*;
	VAR l: antsCommands.tScanList;  name: vyName.tNameArray;  o: tModel;  v1, v2: vyBase.Object;
	BEGIN
		l := antsCommands.ScanFromPar( "name=NAME v1=OBJ v2=OBJ" );
		IF antsCommands.ExpectNameFromKeyword( l, "name", name ) & antsCommands.ExpectObjectFromKeyword( l, "v1", v1 ) &
		    antsCommands.ExpectObjectFromKeyword( l, "v2", v2 ) THEN
			o := DoNewModel( name, v1( vyBase.tVector ), v2( vyBase.tVector ) )
		END
	END NewModel;

	PROCEDURE Many1d*;
	VAR linePlot: vyLinePlot.tLayer;  pict: vyPort.Picture;  c: vyDisplay2d.tCoordinate2d;  nans: LONGINT;  r, ran: LONGREAL;
		v: vyLongrealVec.tVector;  i: LONGINT;  j: LONGINT;  hist0, hist1, hist2: vyLongrealVec.tVector;  link: vyLinks.Link;  obj: vyBase.Object;
		vname: ARRAY 256 OF CHAR;
		append: BOOLEAN;  len: LONGINT;
	BEGIN
		antsCommands.InitScan( "[len= INT] [>new]" );
		IF antsCommands.GetNumber( "len", len ) THEN ELSE len := 500 END;
		append := antsCommands.Find( "append" );

		NEW( c );  vyDisplay2d.OpenC2d( c, 0, 0, 300, 20 );  pict := vyPort.NewP( c );

		IF antsCommands.Find( "new" ) THEN
			hist0 := vyLongrealVec.New( 0 );  hist1 := vyLongrealVec.New( 0 );  hist2 := vyLongrealVec.New( 0 );
			vyName.RegisterNamed( hist0, "hist0" );  vyName.RegisterNamed( hist1, "hist1" );  vyName.RegisterNamed( hist2, "hist2" );
		ELSE
			obj := vyName.FindObj( "hist0" );  hist0 := obj( vyLongrealVec.tVector );  vyLongrealVec.SetLen( hist0, 0 );
			obj := vyName.FindObj( "hist1" );  hist1 := obj( vyLongrealVec.tVector );  vyLongrealVec.SetLen( hist1, 0 );
			obj := vyName.FindObj( "hist2" );  hist2 := obj( vyLongrealVec.tVector );  vyLongrealVec.SetLen( hist2, 0 );
		END;

		FOR i := 0 TO 100 DO
			vname := "vec";  Strings.AppendInt( i, 0, vname );

			IF antsCommands.Find( "new" ) THEN v := vyLongrealVec.New( 0 );  vyName.RegisterNamed( v, vname );
			ELSE
				obj := vyName.FindObj( vname );  v := obj( vyLongrealVec.tVector );
				IF ~append THEN vyLongrealVec.SetLen( v, 0 );  END;
			END;

			IF antsCommands.Find( "new" ) OR ~append THEN r := 0;  vyLongrealVec.Append( r, v );
			ELSE r := vyLongrealVec.Get( v, vyLongrealVec.Len( v ) - 1 )
			END;
			FOR j := 0 TO len DO
				ran := vyRandom.Uniform();
				IF (r > 19) THEN
					IF ran < 0.25 THEN r := 19 END;
				ELSIF r < -19 THEN
					IF ran < 0.25 THEN r := -19 END;
				ELSE
					IF ran < 0.25 THEN r := r - 1;
					ELSIF ran < 0.5 THEN r := r + 1;
					ELSE
					END;
				END;
				vyLongrealVec.Append( r, v );
			END;

			vyLongrealVec.Append( vyLongrealVec.Get( v, vyLongrealVec.Len( v ) DIV 3 ), hist0 );
			vyLongrealVec.Append( vyLongrealVec.Get( v, vyLongrealVec.Len( v ) DIV 3 * 2 ), hist1 );
			vyLongrealVec.Append( vyLongrealVec.Get( v, vyLongrealVec.Len( v ) - 1 ), hist2 );

			IF antsCommands.Find( "new" ) THEN
				vyLinePlot.Alloc;  linePlot := Objects.NewObj( vyLinePlot.tLayer );
				vyLinePlot.Open( linePlot, v, 0, 0, NIL , NIL , 0 );  linePlot.style.alpha := 100;  linePlot.style.pensize := 1;
				vyPort.AddLayer( pict, linePlot );
			END;

		END;
		IF antsCommands.Find( "new" ) THEN
			vyTexts.InsertGadget( pict );  vyLinks.InsertObj( link, hist0 );  vyLinks.InsertObj( link, hist1 );
			vyLinks.InsertObj( link, hist2 );  vyBase.Show( link, 3, "vyHistogram" );  Objects.NewObj := pict
		END;
		vyBase.Update( hist0 );  vyBase.Update( hist1 );  vyBase.Update( hist2 );  vyBase.Update( v );
	END Many1d;

END antsRandomWalk.
System.Free antsRandomWalk ~

vyHistogram.SetOffsetWidth 1 1 ~
fofAutomatic.Do
antsMC.New myChain ~
antsKernel.Define myKernel ~
antsMC.Add myChain myKernel ~
antsFctVector.NewVec v1 1 ~
antsFctVector.NewVec v2 1 ~
antsRandomWalk.NewModel myModel v1 v2 ~
antsKernel.AttachModel myKernel myModel ~
~

fofAutomatic.Do >interactive
antsMC.Forward myChain 1 1 ~
~
antsMC.Init myChain ~
~
Voyager.Show v1 v2 ~ Voyager.Show v1 v2 as Charts  ~
Voyager.Show v1 as Histogram ~

vyScale.Insert ~


Voyager.Show myChain as antsObjectView ~

fofAutomatic.Stop

Voyager.Show v1 as LinePlot ~

Voyager.Show v2 as LinePlot
fofAutomatic.Do >interactive >secure
antsRandomWalk.Many1d  >new len= 100~
~
antsRandomWalk.Many1d len= 1~
antsRandomWalk.Many1d len=1 >append ~
antsRandomWalk.Many1d  >new~

vyScale.Insert #

fofAutomatic.Stop

Desktops.OpenWinDoc lahtiRandomWalk.Panel ~

