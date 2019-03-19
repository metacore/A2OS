(* ShowP einfügen, Handler einfügen, LinkMsg versorgen *)


MODULE antsMDimEstimator IN Oberon;   (** fof  **)
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




IMPORT antsObjects, vyGraphBase, vyPort, vyLongrealVec, vyDisplay2d, antsInteractivePar, antsNeighbourhoods,
	vyHostStrings, antsArrayObjects, MathL IN A2, antsCommands, vyBase, antsDirSet, vyHostTexts, vyName, vyLinks, Objects, Files,
	Gadgets, antsSecurity, aM := antsMessages;

TYPE

	Estimator = POINTER TO EstimatorDesc;
	EstimatorDesc = RECORD (vyBase.ObjDesc)
		lowdim, highdim: LONGINT;
		Isotropic: vyLinks.Link;   (*antsNeighbourhoods.Neighbours will be Inserted in this queue*)
		NonIsotropic: vyLinks.Link;
		nisoAIC, isoAIC: vyBase.tVector;
		nisoAICMin, isoAICMin: INTEGER;
		nisoAICMinTotal, isoAICMinTotal: BOOLEAN;
		current: INTEGER
	END;

VAR
	tempO: antsArrayObjects.tINTEGERObject;  tempDim: LONGINT;  tx-, ty-, tw-, th-: LONGINT;
	temptable: POINTER TO ARRAY OF ARRAY OF LONGINT;
	n: antsNeighbourhoods.Neighbours;

	PROCEDURE tabelize( o: antsArrayObjects.tINTEGERObject;  dim: LONGINT );
	VAR x, y, i, j, k: LONGINT;  pos: LONGINT;  px, py: LONGINT;  val: LONGINT; xx,yy: LONGINT;
	BEGIN
		IF (temptable = NIL ) OR (LEN( temptable^ ) # tw * th) OR (LEN( temptable[0] ) # dim + 1) THEN NEW( temptable, tw * th, dim + 1 ) END;
		FOR x := tx TO tx + tw - 1 DO
			FOR y := ty TO ty + th - 1 DO
				pos := (x - tx) * th + (y - ty);
				FOR k := 0 TO dim DO temptable[pos, k] := 0 END;
				FOR i := 0 TO dim DO
					FOR j := 0 TO n.count[i] - 1 DO
						px := n.x[i, j];  py := (n.y[i, j]);
						xx := (x + px) MOD o.w; yy := (y + py) MOD o.h;
						val := temptable[pos, i] + (2 * o.A[yy,xx] - 1);
						temptable[pos, i] := val;
					END;
				END;
			END;
		END;
	END tabelize;

	PROCEDURE Calc( pos: LONGINT;  dim: LONGINT;  par: ARRAY OF LONGREAL ): LONGREAL;
	VAR theta: LONGREAL;  k: LONGINT;
	BEGIN
		theta := 0;
		FOR k := 1 TO dim DO theta := theta + par[k] * temptable[pos, k];  END;
		theta := theta + par[0];  RETURN -(theta * temptable[pos, 0]) + MathL.ln( MathL.exp( theta ) + MathL.exp( -theta ) );
	END Calc;

	PROCEDURE IsingPMLE( o: antsArrayObjects.tObject;  dim: LONGINT;  par: ARRAY OF LONGREAL ): LONGREAL;
	VAR pos: LONGINT;  ret: LONGREAL;
	BEGIN
		ret := 0;
		FOR pos := 0 TO (tw * th) - 1 DO ret := ret + Calc( pos, dim, par );  END;
		RETURN ret;
	END IsingPMLE;

	PROCEDURE func( VAR Par: ARRAY OF LONGREAL ): LONGREAL;
	BEGIN
		IF antsSecurity.CheckDisplay( TRUE ) THEN END;
		RETURN IsingPMLE( tempO, tempDim, Par ) / (tempO.w * tempO.h);
	END func;

	PROCEDURE StoreF( VAR R: Files.Rider;  s: Estimator );
	BEGIN
		Files.WriteInt( R, 0 );  Files.WriteLInt( R, s.lowdim );  Files.WriteLInt( R, s.highdim );
		vyLinks.StoreLinks( R, s.lib, s.Isotropic );  vyLinks.StoreLinks( R, s.lib, s.NonIsotropic );
		Gadgets.WriteRef( R, s.lib, s.nisoAIC );  Gadgets.WriteRef( R, s.lib, s.isoAIC );  Files.WriteInt( R, s.nisoAICMin );
		Files.WriteInt( R, s.isoAICMin );  Files.WriteBool( R, s.nisoAICMinTotal );  Files.WriteBool( R, s.isoAICMinTotal );
	END StoreF;

	PROCEDURE LoadF( VAR R: Files.Rider;  s: Estimator );
	VAR objsub: Objects.Object;  version: INTEGER;
	BEGIN
		Files.ReadInt( R, version );  Files.ReadLInt( R, s.lowdim );  Files.ReadLInt( R, s.highdim );
		vyLinks.LoadLinks( R, s.lib, s.Isotropic );  vyLinks.LoadLinks( R, s.lib, s.NonIsotropic );

		Gadgets.ReadRef( R, s.lib, objsub );
		IF objsub # NIL THEN s.nisoAIC := objsub( vyBase.tVector ) END;
		Gadgets.ReadRef( R, s.lib, objsub );
		IF objsub # NIL THEN s.isoAIC := objsub( vyBase.tVector ) END;
		Files.ReadInt( R, s.nisoAICMin );  Files.ReadInt( R, s.isoAICMin );  Files.ReadBool( R, s.nisoAICMinTotal );
		Files.ReadBool( R, s.isoAICMinTotal );

	END LoadF;

	PROCEDURE Bind( o: Objects.Object;  VAR M: Objects.BindMsg );
	BEGIN
		IF (o # NIL ) & (M.lib # o.lib) THEN
			Gadgets.BindObj( o, M.lib );
			IF o.handle # NIL THEN o.handle( o, M ) END;
		END;
	END Bind;

	PROCEDURE HandleLinkMsg( l: vyLinks.Link;  name: ARRAY OF CHAR;  VAR M: Objects.LinkMsg );
	VAR lname: ARRAY 256 OF CHAR;
		i: LONGINT;
	BEGIN
		IF M.id = Objects.enum THEN
			i := 1;
			WHILE l # NIL DO vyLinks.SeqName( name, ":", i, lname );  M.Enum( lname );  l := l.link;  INC( i );  END;
		ELSIF M.id = Objects.get THEN
			vyLinks.NameToSeq( M.name, ":", lname, i );
			IF lname = name THEN
				WHILE i > 1 DO l := l.link;  DEC( i );  END;
				M.obj := l.obj;  M.res := 0;
			END;
		END;
	END HandleLinkMsg;

	PROCEDURE Handler*( o: Objects.Object;  VAR M: Objects.ObjMsg );
	BEGIN
		WITH o: Estimator DO
			IF M IS Objects.AttrMsg THEN
				WITH M: Objects.AttrMsg DO
					IF M.id = Objects.enum THEN
						M.Enum( "Gen" );  M.Enum( "lowdim" );  M.Enum( "highdim" );  M.Enum( "MinIsotropicOrder" );  M.Enum( "MinNonIsotropicOrder" );  M.Enum( "MinIsIsotropic" );  M.Enum( "MinIsNonIsotropic" );  M.Enum( "current" );
						vyBase.objecthandle( o, M );
					ELSIF M.id = Objects.get THEN
						IF M.name = "Gen" THEN COPY( 'antsMDimEstimator.Gen', M.s );  M.class := Objects.String;  M.res := 0;  RETURN;
						ELSIF M.name = "lowdim" THEN M.class := Objects.Int;  M.i := o.lowdim;  M.res := 0;  RETURN
						ELSIF M.name = "highdim" THEN M.class := Objects.Int;  M.i := o.highdim;  M.res := 0;  RETURN
						ELSIF M.name = "MinIsotropicOrder" THEN M.class := Objects.Int;  M.i := o.isoAICMin;  M.res := 0;  RETURN
						ELSIF M.name = "MinNonIsotropicOrder" THEN M.class := Objects.Int;  M.i := o.nisoAICMin;  M.res := 0;  RETURN
						ELSIF M.name = "MinIsIsotropic" THEN M.class := Objects.Bool;  M.b := o.isoAICMinTotal;  M.res := 0;  RETURN
						ELSIF M.name = "MinIsNonIsotropic" THEN M.class := Objects.Bool;  M.b := o.nisoAICMinTotal;  M.res := 0;  RETURN
						ELSIF M.name = "current" THEN M.class := Objects.Int;  M.i := o.current;  M.res := 0;  RETURN;
						ELSE vyBase.objecthandle( o, M );
						END;
					ELSE vyBase.objecthandle( o, M );
					END;
				END;
			ELSIF M IS Objects.LinkMsg THEN
				WITH M: Objects.LinkMsg DO
					IF M.id = Objects.enum THEN
						M.Enum( "AICIsotropic" );  M.Enum( "AICnonIsotropic" );  HandleLinkMsg( o.Isotropic, "IsotropicN", M );  HandleLinkMsg( o.NonIsotropic, "NonIsotropicN", M );
					ELSIF M.id = Objects.get THEN
						HandleLinkMsg( o.Isotropic, "IsotropicN", M );  HandleLinkMsg( o.NonIsotropic, "NonIsotropicN", M );
						IF M.name = "AICIsotropic" THEN M.obj := o.isoAIC;  M.res := 0;  RETURN
						ELSIF M.name = "AICnonIsotropic" THEN M.obj := o.nisoAIC;  M.res := 0;  RETURN
						ELSE vyBase.objecthandle( o, M );
						END;
					ELSE vyBase.objecthandle( o, M );
					END;

				END;
			ELSIF M IS Objects.FileMsg THEN
				WITH M: Objects.FileMsg DO
					IF M.id = Objects.load THEN vyBase.objecthandle( o, M );  LoadF( M.R, o );
					ELSIF M.id = Objects.store THEN vyBase.objecthandle( o, M );  StoreF( M.R, o );
					END;
				END;
			ELSIF M IS Objects.BindMsg THEN
				WITH M: Objects.BindMsg DO
					IF M.lib # o.lib THEN
						vyBase.objecthandle( o, M );  vyLinks.BindLinks( o.Isotropic, M );  vyLinks.BindLinks( o.NonIsotropic, M );
						Bind( o.nisoAIC, M );  Bind( o.isoAIC, M );
					END;
				END;
			ELSE vyBase.objecthandle( o, M );
			END;
		END;   (* tVector*)
	END Handler;

	PROCEDURE Gen*;
	VAR e: Estimator;
	BEGIN
		NEW( e );  e.handle := Handler;  Objects.NewObj := e;  antsObjects.Register( e );  e.nisoAICMin := 0;  e.isoAICMin := 0;
		e.nisoAICMinTotal := FALSE;  e.isoAICMinTotal := FALSE;  e.current := 0;
	END Gen;

	PROCEDURE NewEstimator*;
	VAR l: antsCommands.tScanList;  lowdim, highdim: LONGINT;  name, name2: vyName.tNameArray;
		n: antsNeighbourhoods.Neighbours;  i: LONGINT;  e: Estimator;  dim: LONGINT;
	BEGIN
		l := antsCommands.ScanFromPar( "name=NAME lowestdim=INT highestdim=INT " );
		IF antsCommands.ExpectNameFromKeyword( l, "name", name ) & antsCommands.ExpectNumberFromKeyword( l, "lowestdim", lowdim ) &
		    antsCommands.ExpectNumberFromKeyword( l, "highestdim", highdim ) THEN
			Gen;  e := Objects.NewObj( Estimator );  e.lowdim := lowdim;  e.highdim := highdim;  dim := lowdim;
			WHILE dim <= highdim DO
				n := antsNeighbourhoods.NewL2( dim, TRUE );  NEW( n.par, n.dim );
				FOR i := 0 TO n.dim - 1 DO n.par[i] := 0 END;
				vyLinks.InsertObj( e.Isotropic, n );  n := antsNeighbourhoods.NewL2( dim, FALSE );  NEW( n.par, n.dim );
				FOR i := 0 TO n.dim - 1 DO n.par[i] := 0 END;
				vyLinks.InsertObj( e.NonIsotropic, n );  INC( dim );
			END;
			vyName.RegisterNamed( e, name );  name2 := name;  vyHostStrings.Append( name2, "AicIsoVec" );
			e.isoAIC := vyLongrealVec.New( 0 );  vyName.RegisterNamed( e.isoAIC, name2 );  name2 := name;
			vyHostStrings.Append( name2, "AicNonIsoVec" );  e.nisoAIC := vyLongrealVec.New( 0 );
			vyName.RegisterNamed( e.nisoAIC, name2 );
		END;
	END NewEstimator;

	PROCEDURE Estimate*;
	VAR l: antsCommands.tScanList;  obj, obj1: vyBase.Object;  ni, nn, lastni, lastnn: antsNeighbourhoods.Neighbours;  j: LONGINT;
		listi, listn: vyLinks.Link;  e: Estimator;  dim: LONGINT;  init: BOOLEAN;  fret, fret2: LONGREAL;  miniso, minniso: LONGREAL;
	BEGIN
		l := antsCommands.ScanFromPar( "name=NAME from=OBJ [>init] " );
		IF antsCommands.ExpectObjectFromKeyword( l, "name", obj ) & antsCommands.ExpectObjectFromKeyword( l, "from", obj1 ) THEN
			init := antsCommands.FindKeyword( l, "init" );  e := obj( Estimator );  tempO := obj1( antsArrayObjects.tINTEGERObject );
			IF tempO.depth > 2 THEN aM.eS( "antsMDimEstimator: Sorry, can only estimate binary (extended) Ising models" );  RETURN END;
			dim := e.lowdim;  listi := e.Isotropic;  listn := e.NonIsotropic;  tx := 0;  ty := 0;  tw := tempO.w;  th := tempO.h;

			n := antsNeighbourhoods.NewL2( e.highdim, TRUE );  tabelize( tempO, e.highdim - 1 );  dim := e.lowdim;
			miniso := MAX( LONGREAL );
			WHILE (listi # NIL ) DO
				e.current := SHORT( dim );  aM.vSI( "dim", dim );  ni := listi.obj( antsNeighbourhoods.Neighbours );
				(****)
				tempDim := dim - 1;  j := dim - 1;
				WHILE j < tempDim DO ni.par[j] := lastni.par[j];  INC( j );  END;
				antsDirSet.EasyMinimize( ni.par^, fret, 1 / (10 * tempO.w * tempO.h), func, init );  vyBase.Update( ni );
				Gadgets.Update( e );  fret2 := fret + dim / (tw * th);  vyLongrealVec.Append( fret2, e.isoAIC );
				IF fret2 < miniso THEN miniso := fret2;  e.isoAICMin := SHORT( dim ) END;
				lastni := ni;  listi := listi.link;  INC( dim );
			END;

			n := antsNeighbourhoods.NewL2( e.highdim, FALSE );  tabelize( tempO, e.highdim - 1 );  dim := e.lowdim;
			minniso := MAX( LONGREAL );
			WHILE (listn # NIL ) DO
				e.current := SHORT( dim );  aM.vSI( "dim", dim );  nn := listn.obj( antsNeighbourhoods.Neighbours );
				(****)
				tempDim := dim - 1;  j := dim - 1;
				WHILE j < tempDim DO nn.par[j] := lastnn.par[j];  INC( j );  END;
				antsDirSet.EasyMinimize( nn.par^, fret, 1 / (10 * tempO.w * tempO.h), func, init );  vyBase.Update( nn );
				Gadgets.Update( e );  fret2 := fret + dim / (tw * th);
				IF fret2 < minniso THEN minniso := fret2;  e.nisoAICMin := SHORT( dim ) END;
				vyLongrealVec.Append( fret2, e.nisoAIC );  lastnn := nn;  listn := listn.link;  INC( dim );
			END;
			IF miniso < minniso THEN e.isoAICMinTotal := TRUE;  e.nisoAICMinTotal := FALSE;
			ELSE e.nisoAICMinTotal := TRUE;  e.isoAICMinTotal := FALSE;
			END;
			e.current := 0;  Gadgets.Update( e );
		END;
	END Estimate;

	PROCEDURE DoShow( e: Estimator );
	VAR ni, nn: antsNeighbourhoods.Neighbours;  listi, listn: vyLinks.Link;  dim: LONGINT;  mindim, maxdim: LONGINT;
		port1, port2: vyPort.Frame;  picture: vyPort.Picture;  c: vyDisplay2d.tCoordinate2d;  w, h: INTEGER;  fact: LONGREAL;  width: INTEGER;
	BEGIN
		w := SHORT( e.highdim - e.lowdim + 1 );  h := 1;  width := vyHostTexts.GetCurWidth();
		IF width = 0 THEN width := 200 END;
		fact := width / w;  w := SHORT( ENTIER( w * fact ) );  h := SHORT( ENTIER( h * fact ) );
		IF h > 100 THEN fact := 100 / h;  w := SHORT( ENTIER( w * fact ) );  h := SHORT( ENTIER( h * fact ) );  END;
		port1 := vyPort.InsertNewFrame( w, h );  port2 := vyPort.InsertNewFrame( w, h );  listi := e.Isotropic;
		listn := e.NonIsotropic;  maxdim := e.highdim;  dim := e.lowdim;  mindim := dim;
		WHILE (listi # NIL ) & (listn # NIL ) DO
			ni := listi.obj( antsNeighbourhoods.Neighbours );  nn := listn.obj( antsNeighbourhoods.Neighbours );
			c := vyDisplay2d.NewC2d( -1.2, -1.2, 2.4, 2.4 );

			picture := vyPort.NewP( c );  picture.backGround := vyGraphBase.dgrey;
			vyPort.AddPicture( port1, picture, (dim - mindim) / (maxdim - mindim + 1), 0, 1 / (maxdim - mindim + 1), 1 );
			vyPort.AddLayer( picture, antsInteractivePar.NewLayer( ni ) );  c := vyDisplay2d.NewC2d( -1.2, -1.2, 2.4, 2.4 );
			picture := vyPort.NewP( c );  picture.backGround := vyGraphBase.dgrey;
			vyPort.AddPicture( port2, picture, (dim - mindim) / (maxdim - mindim + 1), 0, 1 / (maxdim - mindim + 1), 1 );
			vyPort.AddLayer( picture, antsInteractivePar.NewLayer( nn ) );  listi := listi.link;  listn := listn.link;  INC( dim );
		END;
	END DoShow;

	PROCEDURE Show*;
	VAR l: antsCommands.tScanList;  obj: vyBase.Object;
	BEGIN
		l := antsCommands.ScanFromPar( "name=OBJ" );
		IF antsCommands.ExpectObjectFromKeyword( l, "name", obj ) THEN DoShow( obj( Estimator ) ) END;
	END Show;

	PROCEDURE ShowP*;
	VAR data: Objects.Object;
	BEGIN
		data := vyBase.NextParObj();
		WHILE (data # NIL ) DO DoShow( data( Estimator ) );  data := vyBase.NextParObj();  END;
	END ShowP;

BEGIN
	aM.launch;
END antsMDimEstimator.
antsMDimEstimator.Estimate > from Array > dim 20 > nonisotropic ~~
antsBinaryFields.NewArray > name Array > size 10 10 ~


(* parameter coding:
isotropic:

0
1	2
3	4	5
6	7	8	11
9	10 	12 	13	17
14  	15 	16	18
19

nonisotropic:

17
9	12
4	10 	16	18
0	2	6	14
1    	3	8
5	7   	11
*)						13  	15

antsMDimEstimator.NewEstimator > name myEst > lowestdim 2 > highestdim 8 ~
antsMDimEstimator.NewEstimator > name myEst > lowestdim 2 > highestdim 2 ~
antsMDimEstimator.Show > name myEst ~
antsMDimEstimator.Estimate > name myEst > from Array ~

Voyager.Show myEstAicNonIsoVec as LinePlot~
Voyager.Show myEst as antsObjectView ~

Voyager.WriteData myEstAicNonIsoVec ~

Voyager.Show  UPM533B881E
as LinePlot ~

fofAutomatic.Do
System.Time
antsDiscreteFields.NewArray > name Array > size 50 50 > depth 2~
antsBinaryIsingS.NewModel > name Model  > h 0.0 > beta 0.3 ~
antsGibbs.DefineGibbsSampler > name Sampler > presteps 0 > steps 10  > cooling logarithmic~
antsGibbs.AttachModel > sampler Sampler > model Model ~
antsGibbs.AttachArray > sampler Sampler > array Array ~
~
Voyager.Show Sampler as antsObjectView ~
~
antsGibbs.Step > sampler Sampler > times 10 ~

Voyager.Show Array as antsViews ~

Voyager.Show Array as antsViews ~

System.Free antsMDimEstimator antsInteractivePar ~

