MODULE antsEstimate IN Oberon;
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




IMPORT Files, Objects, antsObjects, vyBase, antsArrayObjects, antsCommands, vyName, Input, antsMDimDiscreteIsingS,
	antsRegions, Gadgets, antsDirSet, antsNeighbourhoods, antsToolbox, Oberon, aM := antsMessages, vyTracking;

TYPE

	tClass* = POINTER TO tClassDesc;
	tClassDesc* = RECORD (vyBase.ObjDesc)
		model: antsMDimDiscreteIsingS.tModel;
		done: BOOLEAN
	END;

VAR
	gM: antsMDimDiscreteIsingS.tModel;  gA: antsArrayObjects.tINTEGERObject;  gT: antsNeighbourhoods.NeighbourTable;
	lasttime: LONGINT;

	PROCEDURE Handler*( o: Objects.Object;  VAR M: Objects.ObjMsg );
	VAR version: INTEGER;  objsub: Objects.Object;
	BEGIN
		WITH o: tClass DO
			IF M IS Objects.AttrMsg THEN
				WITH M: Objects.AttrMsg DO
					IF M.id = Objects.enum THEN M.Enum( "Gen" );  M.Enum( "done" );  vyBase.objecthandle( o, M )
					ELSIF M.id = Objects.get THEN
						IF M.name = "Gen" THEN COPY( 'antsEstimate.Gen', M.s );  M.class := Objects.String;  M.res := 0;  RETURN
						ELSIF M.name = "done" THEN M.b := o.done;  M.class := Objects.Bool;  M.res := 0
						ELSE vyBase.objecthandle( o, M )
						END
					ELSIF M.id = Objects.set THEN vyBase.objecthandle( o, M )
					ELSE vyBase.objecthandle( o, M )
					END
				END;
			ELSIF M IS Objects.LinkMsg THEN
				WITH M: Objects.LinkMsg DO
					IF M.id = Objects.enum THEN M.Enum( "model" );  vyBase.objecthandle( o, M )
					ELSIF M.id = Objects.get THEN
						IF (M.name = "model") THEN M.obj := o.model;  M.res := 0 ELSE vyBase.objecthandle( o, M ) END
					ELSE vyBase.objecthandle( o, M )
					END;
				END;
			ELSIF M IS Objects.FileMsg THEN
				WITH M: Objects.FileMsg DO
					IF M.id = Objects.load THEN
						Files.ReadInt( M.R, version );  Gadgets.ReadRef( M.R, o.lib, objsub );
						IF objsub # NIL THEN o.model := objsub( antsMDimDiscreteIsingS.tModel ) ELSE o.model := NIL END;
						vyBase.objecthandle( o, M )
					ELSIF M.id = Objects.store THEN
						Files.WriteInt( M.R, 0 );  Gadgets.WriteRef( M.R, o.lib, o.model );  vyBase.objecthandle( o, M )
					END
				END;
			ELSIF M IS Objects.BindMsg THEN
				WITH M: Objects.BindMsg DO
					IF o.lib # M.lib THEN antsObjects.Bind( o.model, M );  vyBase.objecthandle( o, M ) END
				END;
			ELSE vyBase.objecthandle( o, M )
			END
		END  (* tVector*)
	END Handler;

	PROCEDURE Gen*;
	VAR m: tClass;
	BEGIN
		aM.cmd;  NEW( m );  m.handle := Handler;  Objects.NewObj := m;  antsObjects.Register( m );  m.done := FALSE
	END Gen;

	PROCEDURE New*;
	VAR l: antsCommands.tScanList;  name: vyName.tNameArray;  r: tClass;  obj: vyBase.Object;
	BEGIN
		l := antsCommands.ScanFromPar( "name=NAME model=OBJ" );
		IF antsCommands.ExpectNameFromKeyword( l, "name", name ) & antsCommands.ExpectObjectFromKeyword( l, "model", obj ) THEN
			Gen;  r := Objects.NewObj( tClass );
			WITH obj: antsMDimDiscreteIsingS.tModel DO r.model := obj
			END;
			vyName.RegisterNamed( r, name );  vyBase.Subscribe( r, r.model ) (* for getting stored only *)
		END
	END New;

	PROCEDURE func( VAR Par: ARRAY OF LONGREAL ): LONGREAL;
	VAR i, time: LONGINT;
	BEGIN
		FOR i := 0 TO LEN( Par ) - 1 DO gM.n.par[i] := Par[i] END;
		antsNeighbourhoods.FillCache( gM.n );  time := Oberon.Time();
		IF time - lasttime > Input.TimeUnit DIV 3 THEN lasttime := time;  vyBase.Update( gM.n ) END;
		RETURN -antsMDimDiscreteIsingS.PseudoLik( gT, gM, FALSE )
	END func;

(*
PROCEDURE EstimateOld*;
VAR A: antsArrayObjects.tINTEGERObject; m: antsMDimDiscreteIsingS.tModel; link: vyLinks.Link;  c: tClass; region: antsRegions.tRegion;
l: antsCommands.tScanList;   obj1,obj2: vyBase.Object; i: LONGINT;  len: LONGINT; fret: LONGREAL;
a: POINTER TO ARRAY OF LONGREAL;
BEGIN
l := antsCommands.ScanFromPar();
IF
antsCommands.ExpectObjectFromKeyword(l, "name",  obj1)
THEN
c := obj1(tClass);
m := c.model;
antsRegions.Gen; region := Objects.NewObj(antsRegions.tRegion);
antsRegions.DoSelectRegion(region);
IF ~region.valid  THEN RETURN END;
A := antsRegions.A;
IF A#NIL THEN
antsToolbox.StartDisplayHelp("Estimating, please wait.");
c.done := FALSE; Gadgets.Update(c);
gA := A; gM := m; gM.region := region;
NEW(a,LEN(m.n.par)-1);
FOR i := 0 TO LEN(a)-1 DO a[i] := m.n.par[i+1] END;
antsDirSet.EasyMinimize(a^,fret,0.01,func,FALSE);
gM.region := NIL;
vyBase.Update(m.n);
antsToolbox.EndDisplayHelp();
c.done := TRUE; Gadgets.Update(c);
END;
END;
END EstimateOld;
*)

	PROCEDURE Estimate*;
	VAR A: antsArrayObjects.tINTEGERObject;  m: antsMDimDiscreteIsingS.tModel;  c: tClass;  region: antsRegions.tRegion;
		l: antsCommands.tScanList;  obj1: vyBase.Object;  fret: LONGREAL;
		a: POINTER TO ARRAY OF LONGREAL;
	BEGIN
		l := antsCommands.ScanFromPar( "name=OBJ" );
		IF antsCommands.ExpectObjectFromKeyword( l, "name", obj1 ) THEN
			c := obj1( tClass );  m := c.model;  antsRegions.Gen;  region := Objects.NewObj( antsRegions.tRegion );
			antsToolbox.EndDisplayHelp();  antsRegions.DoSelectRegion( region );
			IF ~region.valid THEN RETURN END;
			A := antsRegions.A;
			IF A # NIL THEN
				vyTracking.HelpAt( 0, 0, "Estimating, please wait." );  c.done := FALSE;  Gadgets.Update( c );  gA := A;  gM := m;  gM.region := region;
				antsNeighbourhoods.FillCache( gM.n );

				NEW( a, LEN( m.n.par ) );
				(*
			FOR i := 0 TO LEN(a)-1 DO a[i] := m.n.par[i] END;
			*)
				lasttime := Oberon.Time();

				antsMDimDiscreteIsingS.PseudoLikPrepare( gA, gM, gT );  antsDirSet.EasyMinimize( a^, fret, 0.01, func, TRUE );
				gM.region := NIL;  vyBase.Update( m.n );  antsToolbox.EndDisplayHelp();  c.done := TRUE;  Gadgets.Update( c )
			END
		END
	END Estimate;

BEGIN
	aM.launch;
END antsEstimate.

System.Free antsEstimate ~

antsEstimate.New Estimator Model ~
antsEstimate.Estimate Model ~

fofAutomatic.Do
Voyager.OpenLog xxx ~
antsFunctions.Define > name f5Function > from - 12 > to 12 > step 1 > lower 0 > upper 1 ~
antsFunctions.Set > name f5Function > function "x*x"~ (lambda, gamma)
antsNeighbourhoods.New > name f5Neighbours > size 5 > nonisotropic ~
antsInteractivePar.Show > name f5Neighbours    ~
antsObjects.WriteAttributes f5Neighbours ~
antsMDimDiscreteIsingS.NewModel > name f5Model > par f5Neighbours  > function f5Function  ~
~
antsEstimate.New f5Estimator f5Model ~
antsEstimate.Estimate f5Estimator ~
~
