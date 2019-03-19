MODULE antsPottsSimulation IN Oberon;
(* Dieses Modul stellt die Schnittstelle der Datenbank mit dem Panel antsPottsSimulation.Panel dar.
	Die Methoden-Namen entsprechen den Buttons auf dem Panel. Die Berechnung wird in antsPottsSimAdministration
	durchgeführt. Die Update-Methoden werden dazu benutzt, um das Panel immer auf dem neuesten Stand zu halten. *)
(* Copyright notice:

This file is part of AntsInFields
Copyright (C) 1997-2002, Felix Friedrich

This library is free software; you can redistribute it and/or
modify it under the terms of the GNU Lesser General Public
License as published by the Free Software Foundation; either
version 2.1 of the License, or (at your option) any later version.

This library is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
Lesser General Public License for more details.

You should have received a copy of the GNU Lesser General Public
License along with this library; if not, write to the Free Software
Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA

Copy of the GNU Lesser General Public License can be found in the file COPYING.TXT
Report any problems as soon as possible to ants@AntsInFields.de
*)


(**
Stefan Brandt, 2003
Alexandra Hutzenthaler, 2003
*)

IMPORT vyBase, antsCommands, antsSecurity, antsPottsSimDataStructure, antsPottsSimAdministration, vyName, vyPort, vyLongrealVec, antsArrays, Objects, ListRiders,
	Attributes, Gadgets, Strings, Out, antsFiles, vyRealVec;

CONST
	TAB = Strings.Tab;

VAR
	set: antsPottsSimDataStructure.SetChain;
	actualDataSet: ARRAY 1024 OF CHAR;
	actualData: ARRAY 1024 OF CHAR;
	actualDataReko: ARRAY 1024 OF CHAR;
	actualMonotone: ARRAY 1024 OF CHAR;
	actualDegraded: ARRAY 1024 OF CHAR;
	actualReko: ARRAY 1024 OF CHAR;
	actualResults: ARRAY 1024 OF CHAR;
	mycont: Objects.Object;

	PROCEDURE ReadData*;

	VAR datavec, datarekovec, monotonevec, degradedvec, rekovec: vyBase.Object;
		file, dataChainname, dataname, monotonename: ARRAY 1024 OF CHAR;
		data, monotone, dummy: antsArrays.X1d;

	BEGIN
		antsCommands.InitScan( "inputfilename=STRING datasetname=STRING datavec=OBJ monotonevec=OBJ" );

		IF antsCommands.ExpectString( "inputfilename", file ) & antsCommands.ExpectString( "datasetname", dataChainname ) &
		    antsCommands.ExpectObject( "datavec", datavec ) & antsCommands.ExpectObject( "datarekovec", datarekovec ) &
		    antsCommands.ExpectObject( "monotonevec", monotonevec ) & antsCommands.ExpectObject( "degradedvec", degradedvec ) &
		    antsCommands.ExpectObject( "rekovec", rekovec ) THEN

			IF set = NIL THEN antsPottsSimDataStructure.NewSetChain( set );
			END;

			IF ~antsPottsSimDataStructure.ExistDataset( set, dataChainname ) THEN
				antsPottsSimDataStructure.NewDataChain( set, dataChainname );  COPY( dataChainname, actualDataSet );
			ELSE antsSecurity.Halt( "Datasetname already exists. Please choose another !!!" );
			END;

			antsPottsSimAdministration.DoReadData( set, dataChainname, file );  antsPottsSimDataStructure.GetDataName( set, dataChainname, 0, dataname );
			data := antsPottsSimDataStructure.GetData( set, dataChainname, dataname );
			antsPottsSimDataStructure.GetMonotoneName( set, dataChainname, dataname, 0, monotonename );
			monotone := antsPottsSimDataStructure.GetMonotone( set, dataChainname, dataname, monotonename );  COPY( dataname, actualData );
			COPY( monotonename, actualMonotone );  COPY( "", actualDataReko );  COPY( "", actualDegraded );  COPY( "", actualReko );  COPY( "", actualResults );
			NEW( dummy, 100 );  SetVec( datavec, data );  SetVec( datarekovec, dummy );  SetVec( monotonevec, monotone );  SetVec( degradedvec, dummy );
			SetVec( rekovec, dummy );  NEW( dummy, 6 );  SetDataRekoFields( dummy );  SetRekoFields( dummy );  SetNoiseField( 0 );
		END;

		UpdatePanel();
	END ReadData;

	PROCEDURE UpdatePanel*;

	VAR i: LONGINT;  R: ListRiders.Rider;  M: ListRiders.ConnectMsg;  list: Objects.Object;  textf: Objects.Object;  d: ListRiders.String;
		name: ARRAY 1024 OF CHAR;

	BEGIN
		list := Gadgets.FindObj( mycont, "DataSets" );

		IF list # NIL THEN
			M.R := NIL;  Objects.Stamp( M );  list.handle( list, M );
			IF M.R # NIL THEN
				R := M.R;
				WHILE ~R.eol DO R.do.DeleteLink( NIL , R ) END;
				R.do.Set( R, 0 );  NEW( d );

				IF antsPottsSimDataStructure.ExistChain( set ) THEN
					FOR i := 0 TO antsPottsSimDataStructure.GetSetChainLen( set ) - 1 DO
						antsPottsSimDataStructure.GetDataSetName( set, i, name );  COPY( name, d.s );  R.do.Write( R, d );  NEW( d );
					END;
				END;

				Gadgets.Update( list );  R := NIL;
			END;
		END;

		textf := Gadgets.FindObj( mycont, "ActDataSet" );

		IF textf # NIL THEN Attributes.SetString( textf, "Value", actualDataSet );  Gadgets.Update( textf );
		END;

		list := Gadgets.FindObj( mycont, "Datas" );

		IF list # NIL THEN
			M.R := NIL;  Objects.Stamp( M );  list.handle( list, M );
			IF M.R # NIL THEN
				R := M.R;
				WHILE ~R.eol DO R.do.DeleteLink( NIL , R ) END;
				R.do.Set( R, 0 );  NEW( d );

				IF antsPottsSimDataStructure.ExistDataChain( set, actualDataSet ) THEN
					FOR i := 0 TO antsPottsSimDataStructure.GetDataChainLen( set, actualDataSet ) - 1 DO
						antsPottsSimDataStructure.GetDataName( set, actualDataSet, i, name );  COPY( name, d.s );  R.do.Write( R, d );  NEW( d );
					END;
				END;

				Gadgets.Update( list );  R := NIL;
			END;
		END;

		textf := Gadgets.FindObj( mycont, "ActData" );

		IF textf # NIL THEN Attributes.SetString( textf, "Value", actualData );  Gadgets.Update( textf );
		END;

		list := Gadgets.FindObj( mycont, "Monotones" );

		IF list # NIL THEN
			M.R := NIL;  Objects.Stamp( M );  list.handle( list, M );
			IF M.R # NIL THEN
				R := M.R;
				WHILE ~R.eol DO R.do.DeleteLink( NIL , R ) END;
				R.do.Set( R, 0 );  NEW( d );

				IF antsPottsSimDataStructure.ExistMonotoneChain( set, actualDataSet, actualData ) THEN
					FOR i := 0 TO antsPottsSimDataStructure.GetMonotoneChainLen( set, actualDataSet, actualData ) - 1 DO
						antsPottsSimDataStructure.GetMonotoneName( set, actualDataSet, actualData, i, name );  COPY( name, d.s );  R.do.Write( R, d );  NEW( d );
					END;
				END;

				Gadgets.Update( list );  R := NIL;
			END;
		END;

		textf := Gadgets.FindObj( mycont, "ActMonotone" );

		IF textf # NIL THEN Attributes.SetString( textf, "Value", actualMonotone );  Gadgets.Update( textf );
		END;

		list := Gadgets.FindObj( mycont, "DataRekos" );

		IF list # NIL THEN
			M.R := NIL;  Objects.Stamp( M );  list.handle( list, M );
			IF M.R # NIL THEN
				R := M.R;
				WHILE ~R.eol DO R.do.DeleteLink( NIL , R ) END;
				R.do.Set( R, 0 );  NEW( d );

				IF antsPottsSimDataStructure.ExistDataRekoChain( set, actualDataSet, actualData ) THEN
					FOR i := 0 TO antsPottsSimDataStructure.GetDataRekoChainLen( set, actualDataSet, actualData ) - 1 DO
						antsPottsSimDataStructure.GetDataRekoName( set, actualDataSet, actualData, i, name );  COPY( name, d.s );  R.do.Write( R, d );  NEW( d );
					END;
				END;

				Gadgets.Update( list );  R := NIL;
			END;
		END;

		textf := Gadgets.FindObj( mycont, "ActDataReko" );

		IF textf # NIL THEN Attributes.SetString( textf, "Value", actualDataReko );  Gadgets.Update( textf );
		END;

		list := Gadgets.FindObj( mycont, "Degradeds" );

		IF list # NIL THEN
			M.R := NIL;  Objects.Stamp( M );  list.handle( list, M );
			IF M.R # NIL THEN
				R := M.R;
				WHILE ~R.eol DO R.do.DeleteLink( NIL , R ) END;
				R.do.Set( R, 0 );  NEW( d );

				IF antsPottsSimDataStructure.ExistDegradedChain( set, actualDataSet, actualData, actualMonotone ) THEN
					FOR i := 0 TO antsPottsSimDataStructure.GetDegradedChainLen( set, actualDataSet, actualData, actualMonotone ) - 1 DO
						antsPottsSimDataStructure.GetDegradedName( set, actualDataSet, actualData, actualMonotone, i, name );  COPY( name, d.s );  R.do.Write( R, d );
						NEW( d );
					END;
				END;

				Gadgets.Update( list );  R := NIL;
			END;
		END;

		textf := Gadgets.FindObj( mycont, "ActDegraded" );

		IF textf # NIL THEN Attributes.SetString( textf, "Value", actualDegraded );  Gadgets.Update( textf );
		END;

		list := Gadgets.FindObj( mycont, "Rekos" );

		IF list # NIL THEN
			M.R := NIL;  Objects.Stamp( M );  list.handle( list, M );
			IF M.R # NIL THEN
				R := M.R;
				WHILE ~R.eol DO R.do.DeleteLink( NIL , R ) END;
				R.do.Set( R, 0 );  NEW( d );

				IF antsPottsSimDataStructure.ExistRekoChain( set, actualDataSet, actualData, actualMonotone, actualDegraded ) THEN
					FOR i := 0 TO antsPottsSimDataStructure.GetRekoChainLen( set, actualDataSet, actualData, actualMonotone, actualDegraded ) - 1 DO
						antsPottsSimDataStructure.GetRekoName( set, actualDataSet, actualData, actualMonotone, actualDegraded, i, name );  COPY( name, d.s );
						R.do.Write( R, d );  NEW( d );
					END;
				END;

				Gadgets.Update( list );  R := NIL;
			END;
		END;

		textf := Gadgets.FindObj( mycont, "ActReko" );

		IF textf # NIL THEN Attributes.SetString( textf, "Value", actualReko );  Gadgets.Update( textf );
		END;
	END UpdatePanel;

	PROCEDURE SaveCont*;

	BEGIN
		mycont := Gadgets.context;
	END SaveCont;

	PROCEDURE DataRekoLoop*;

	VAR rekotype, gammatype, datarekoname: ARRAY 1024 OF CHAR;
		gamma: LONGREAL;  datareko, dataresults: antsArrays.X1d;  datarekovec: vyBase.Object;

	BEGIN
		antsCommands.InitScan( "rekotype=STRING gammatype=STRING gamma=LONGREAL datarekovec=OBJ" );

		IF antsCommands.ExpectString( "rekotype", rekotype ) & antsCommands.ExpectString( "gammatype", gammatype ) &
		    antsCommands.ExpectReal( "gamma", gamma ) & antsCommands.ExpectObject( "datarekovec", datarekovec ) THEN

			IF antsPottsSimDataStructure.ExistDataChain( set, actualDataSet ) THEN
				antsPottsSimAdministration.DoDataRekoLoop( set, actualDataSet, rekotype, gammatype, gamma, datarekoname );

				IF antsPottsSimDataStructure.ExistDataRekoChain( set, actualDataSet, actualData ) THEN
					datareko := antsPottsSimDataStructure.GetDataReko( set, actualDataSet, actualData, datarekoname );
					dataresults := antsPottsSimDataStructure.GetDataResults( set, actualDataSet, actualData, datarekoname );  COPY( datarekoname, actualDataReko );
					SetVec( datarekovec, datareko );  SetDataRekoFields( dataresults );
				END;
			END;
		END;

		UpdatePanel();
	END DataRekoLoop;

	PROCEDURE CreateData*;

	VAR function: vyName.tNameArray;  fct, datavec, datarekovec, monotonevec, degradedvec, rekovec: vyBase.Object;  datanumber: LONGINT;
		data, monotone, dummy: antsArrays.X1d;
		dataname, monotonename: ARRAY 1024 OF CHAR;

	BEGIN
		antsCommands.InitScan( "function=STRING datanumber=LONGINT datavec=OBJ fct=OBJ monotonevec=OBJ" );

		IF antsCommands.ExpectString( "function", function ) & antsCommands.ExpectNumber( "datanumber", datanumber ) &
		    antsCommands.ExpectObject( "datavec", datavec ) & antsCommands.ExpectObject( "fct", fct ) &
		    antsCommands.ExpectObject( "datarekovec", datarekovec ) & antsCommands.ExpectObject( "monotonevec", monotonevec ) &
		    antsCommands.ExpectObject( "degradedvec", degradedvec ) & antsCommands.ExpectObject( "rekovec", rekovec ) THEN

			IF set = NIL THEN antsPottsSimDataStructure.NewSetChain( set );
			END;

			IF ~antsPottsSimDataStructure.ExistDataset( set, "Functions" ) THEN antsPottsSimDataStructure.NewDataChain( set, "Functions" );
			END;

			vyLongrealVec.SetLen( datavec( vyLongrealVec.tVector ), datanumber );
			antsPottsSimAdministration.DoCreateData( set, function, datanumber, fct, datavec, dataname );  actualDataSet := "Functions";
			data := antsPottsSimDataStructure.GetData( set, actualDataSet, dataname );
			antsPottsSimDataStructure.GetMonotoneName( set, actualDataSet, dataname, 0, monotonename );
			monotone := antsPottsSimDataStructure.GetMonotone( set, actualDataSet, dataname, monotonename );  COPY( dataname, actualData );
			COPY( monotonename, actualMonotone );  COPY( "", actualDataReko );  COPY( "", actualDegraded );  COPY( "", actualReko );  COPY( "", actualResults );
			NEW( dummy, 100 );  SetVec( datavec, data );  SetVec( datarekovec, dummy );  SetVec( monotonevec, monotone );  SetVec( degradedvec, dummy );
			SetVec( rekovec, dummy );  NEW( dummy, 6 );  SetDataRekoFields( dummy );  SetRekoFields( dummy );  SetNoiseField( 0 );
		END;

		UpdatePanel();
	END CreateData;

	PROCEDURE UpdateDataset*;

	VAR datasetname: ARRAY 1024 OF CHAR;
		datavec, datarekovec, monotonevec, degradedvec, rekovec: vyBase.Object;

	BEGIN
		antsCommands.InitScan( "datasetname=STRING datavec=OBJ datarekovec=OBJ monotonevec=OBJ degradedvec=OBJ rekovec=OBJ" );

		IF antsCommands.ExpectString( "datasetname", datasetname ) & antsCommands.ExpectObject( "datavec", datavec ) &
		    antsCommands.ExpectObject( "datarekovec", datarekovec ) & antsCommands.ExpectObject( "monotonevec", monotonevec ) &
		    antsCommands.ExpectObject( "degradedvec", degradedvec ) & antsCommands.ExpectObject( "rekovec", rekovec ) THEN

			DoUpdateDataset( datasetname, datavec, datarekovec, monotonevec, degradedvec, rekovec );
		END;
	END UpdateDataset;

	PROCEDURE DoUpdateDataset*( datasetname: ARRAY OF CHAR;  VAR datavec: vyBase.Object;  VAR datarekovec: vyBase.Object;  VAR monotonevec: vyBase.Object;
													   VAR degradedvec: vyBase.Object;  VAR rekovec: vyBase.Object );

	VAR dataname: ARRAY 1024 OF CHAR;
		dummy: antsArrays.X1d;

	BEGIN
		COPY( datasetname, actualDataSet );

		IF antsPottsSimDataStructure.ExistDataChain( set, datasetname ) THEN
			antsPottsSimDataStructure.GetDataName( set, datasetname, 0, dataname );
			DoUpdateData( datasetname, dataname, datavec, datarekovec, monotonevec, degradedvec, rekovec );
		ELSE
			COPY( "", actualData );  COPY( "", actualDataReko );  COPY( "", actualMonotone );  COPY( "", actualDegraded );  COPY( "", actualReko );
			NEW( dummy, 100 );  SetVec( datavec, dummy );  SetVec( datarekovec, dummy );  SetVec( monotonevec, dummy );  SetVec( degradedvec, dummy );
			SetVec( rekovec, dummy );  NEW( dummy, 6 );  SetDataRekoFields( dummy );  SetRekoFields( dummy );  SetNoiseField( 0 );  UpdatePanel();
		END;
	END DoUpdateDataset;

	PROCEDURE UpdateData*;

	VAR datasetname, dataname: ARRAY 1024 OF CHAR;
		datavec, datarekovec, monotonevec, degradedvec, rekovec: vyBase.Object;

	BEGIN
		antsCommands.InitScan( "datasetname=STRING dataname=STRING datavec=OBJ datarekovec=OBJ monotonevec=OBJ degradedvec=OBJ rekovec=OBJ" );

		IF antsCommands.ExpectString( "datasetname", datasetname ) & antsCommands.ExpectString( "dataname", dataname ) &
		    antsCommands.ExpectObject( "datavec", datavec ) & antsCommands.ExpectObject( "datarekovec", datarekovec ) &
		    antsCommands.ExpectObject( "monotonevec", monotonevec ) & antsCommands.ExpectObject( "degradedvec", degradedvec ) &
		    antsCommands.ExpectObject( "rekovec", rekovec ) THEN

			DoUpdateData( datasetname, dataname, datavec, datarekovec, monotonevec, degradedvec, rekovec );
		END;
	END UpdateData;

	PROCEDURE DoUpdateData*( datasetname, dataname: ARRAY OF CHAR;  VAR datavec: vyBase.Object;  VAR datarekovec: vyBase.Object;
												 VAR monotonevec: vyBase.Object;  VAR degradedvec: vyBase.Object;  VAR rekovec: vyBase.Object );

	VAR datarekoname, monotonename: ARRAY 1024 OF CHAR;
		data, dummy: antsArrays.X1d;

	BEGIN
		IF antsPottsSimDataStructure.ExistData( set, datasetname, dataname ) THEN
			COPY( dataname, actualData );  data := antsPottsSimDataStructure.GetData( set, datasetname, dataname );  SetVec( datavec, data );

			IF antsPottsSimDataStructure.ExistDataRekoChain( set, datasetname, dataname ) THEN
				antsPottsSimDataStructure.GetDataRekoName( set, datasetname, dataname, 0, datarekoname );
				DoUpdateDataReko( datasetname, dataname, datarekoname, datarekovec );
			ELSE COPY( "", actualDataReko );  NEW( dummy, 100 );  SetVec( datarekovec, dummy );
			END;

			IF antsPottsSimDataStructure.ExistMonotoneChain( set, datasetname, dataname ) THEN
				antsPottsSimDataStructure.GetMonotoneName( set, datasetname, dataname, 0, monotonename );
				DoUpdateMonotone( datasetname, dataname, monotonename, monotonevec, degradedvec, rekovec );
			ELSE
				COPY( "", actualMonotone );  COPY( "", actualDegraded );  COPY( "", actualReko );  NEW( dummy, 100 );  SetVec( monotonevec, dummy );
				SetVec( degradedvec, dummy );  SetVec( rekovec, dummy );  NEW( dummy, 6 );  SetDataRekoFields( dummy );  SetRekoFields( dummy );
				SetNoiseField( 0 );  UpdatePanel();
			END;
		ELSE
			COPY( "", actualData );  COPY( "", actualMonotone );  COPY( "", actualDegraded );  COPY( "", actualReko );  NEW( dummy, 100 );
			SetVec( datavec, dummy );  SetVec( datarekovec, dummy );  SetVec( monotonevec, dummy );  SetVec( degradedvec, dummy );  SetVec( rekovec, dummy );
			NEW( dummy, 6 );  SetDataRekoFields( dummy );  SetRekoFields( dummy );  SetNoiseField( 0 );  UpdatePanel();
		END;
	END DoUpdateData;

	PROCEDURE UpdateDataReko*;

	VAR datasetname, dataname, datarekoname: ARRAY 1024 OF CHAR;
		datarekovec: vyBase.Object;

	BEGIN
		antsCommands.InitScan( "datasetname=STRING dataname=STRING datarekoname=STRING datarekovec=OBJ" );

		IF antsCommands.ExpectString( "datasetname", datasetname ) & antsCommands.ExpectString( "dataname", dataname ) &
		    antsCommands.ExpectString( "datarekoname", datarekoname ) & antsCommands.ExpectObject( "datarekovec", datarekovec ) THEN

			DoUpdateDataReko( datasetname, dataname, datarekoname, datarekovec );
		END;
	END UpdateDataReko;

	PROCEDURE DoUpdateDataReko*( datasetname, dataname, datarekoname: ARRAY OF CHAR;  VAR datarekovec: vyBase.Object );

	VAR datareko, dataresults, dummy: antsArrays.X1d;

	BEGIN
		IF antsPottsSimDataStructure.ExistDataReko( set, datasetname, dataname, datarekoname ) THEN
			COPY( datarekoname, actualDataReko );  datareko := antsPottsSimDataStructure.GetDataReko( set, datasetname, dataname, datarekoname );
			dataresults := antsPottsSimDataStructure.GetDataResults( set, datasetname, dataname, datarekoname );  SetVec( datarekovec, datareko );
			SetDataRekoFields( dataresults );
		ELSE COPY( "", actualDataReko );  NEW( dummy, 100 );  SetVec( datarekovec, dummy );  NEW( dummy, 6 );  SetDataRekoFields( dummy );
		END;
	END DoUpdateDataReko;

	PROCEDURE UpdateMonotone*;

	VAR datasetname, dataname, monotonename: ARRAY 1024 OF CHAR;
		monotonevec, degradedvec, rekovec: vyBase.Object;

	BEGIN
		antsCommands.InitScan( "datasetname=STRING dataname=STRING monotonename=STRING monotonevec=OBJ degradedvec=OBJ rekovec=OBJ" );

		IF antsCommands.ExpectString( "datasetname", datasetname ) & antsCommands.ExpectString( "dataname", dataname ) &
		    antsCommands.ExpectString( "monotonename", monotonename ) & antsCommands.ExpectObject( "monotonevec", monotonevec ) &
		    antsCommands.ExpectObject( "degradedvec", degradedvec ) & antsCommands.ExpectObject( "rekovec", rekovec ) THEN

			DoUpdateMonotone( datasetname, dataname, monotonename, monotonevec, degradedvec, rekovec );
		END;
	END UpdateMonotone;

	PROCEDURE DoUpdateMonotone*( datasetname, dataname, monotonename: ARRAY OF CHAR;  VAR monotonevec: vyBase.Object;  VAR degradedvec: vyBase.Object;
														  VAR rekovec: vyBase.Object );

	VAR degradedname: ARRAY 1024 OF CHAR;
		monotone, dummy: antsArrays.X1d;

	BEGIN
		IF antsPottsSimDataStructure.ExistMonotone( set, datasetname, dataname, monotonename ) THEN
			COPY( monotonename, actualMonotone );  monotone := antsPottsSimDataStructure.GetMonotone( set, datasetname, dataname, monotonename );
			SetVec( monotonevec, monotone );

			IF antsPottsSimDataStructure.ExistDegradedChain( set, datasetname, dataname, monotonename ) THEN
				antsPottsSimDataStructure.GetDegradedName( set, datasetname, dataname, monotonename, 0, degradedname );
				DoUpdateDegraded( datasetname, dataname, monotonename, degradedname, degradedvec, rekovec );
			ELSE
				COPY( "", actualDegraded );  COPY( "", actualReko );  NEW( dummy, 100 );  SetVec( degradedvec, dummy );  SetVec( rekovec, dummy );
				NEW( dummy, 6 );  SetRekoFields( dummy );  SetNoiseField( 0 );  UpdatePanel();
			END;
		ELSE
			COPY( "", actualMonotone );  COPY( "", actualDegraded );  COPY( "", actualReko );  NEW( dummy, 100 );  SetVec( monotonevec, dummy );
			SetVec( degradedvec, dummy );  SetVec( rekovec, dummy );  NEW( dummy, 6 );  SetRekoFields( dummy );  SetNoiseField( 0 );  UpdatePanel();
		END;
	END DoUpdateMonotone;

	PROCEDURE UpdateDegraded*;

	VAR datasetname, dataname, monotonename, degradedname: ARRAY 1024 OF CHAR;
		degradedvec, rekovec: vyBase.Object;

	BEGIN
		antsCommands.InitScan( "datasetname=STRING dataname=STRING monotonename=STRING degradedname=STRING degradedvec=OBJ rekovec=OBJ" );

		IF antsCommands.ExpectString( "datasetname", datasetname ) & antsCommands.ExpectString( "dataname", dataname ) &
		    antsCommands.ExpectString( "monotonename", monotonename ) & antsCommands.ExpectString( "degradedname", degradedname ) &
		    antsCommands.ExpectObject( "degradedvec", degradedvec ) & antsCommands.ExpectObject( "rekovec", rekovec ) THEN

			DoUpdateDegraded( datasetname, dataname, monotonename, degradedname, degradedvec, rekovec );
		END;
	END UpdateDegraded;

	PROCEDURE DoUpdateDegraded*( datasetname, dataname, monotonename, degradedname: ARRAY OF CHAR;  VAR degradedvec: vyBase.Object;
														 VAR rekovec: vyBase.Object );

	VAR rekoname: ARRAY 1024 OF CHAR;
		degraded, dummy: antsArrays.X1d;  var: LONGREAL;

	BEGIN
		IF antsPottsSimDataStructure.ExistDegraded( set, datasetname, dataname, monotonename, degradedname ) THEN
			COPY( degradedname, actualDegraded );
			degraded := antsPottsSimDataStructure.GetDegraded( set, datasetname, dataname, monotonename, degradedname );
			var := antsPottsSimDataStructure.GetNoiseVariance( set, datasetname, dataname, monotonename, degradedname );  SetVec( degradedvec, degraded );
			SetNoiseField( var );

			IF antsPottsSimDataStructure.ExistRekoChain( set, datasetname, dataname, monotonename, degradedname ) THEN
				antsPottsSimDataStructure.GetRekoName( set, datasetname, dataname, monotonename, degradedname, 0, rekoname );
				DoUpdateReko( datasetname, dataname, monotonename, degradedname, rekoname, rekovec );
			ELSE COPY( "", actualReko );  NEW( dummy, 100 );  SetVec( rekovec, dummy );  NEW( dummy, 6 );  SetRekoFields( dummy );  UpdatePanel();
			END;
		ELSE
			COPY( "", actualDegraded );  COPY( "", actualReko );  NEW( dummy, 100 );  SetVec( degradedvec, dummy );  SetVec( rekovec, dummy );  NEW( dummy, 6 );
			SetRekoFields( dummy );  SetNoiseField( 0 );  UpdatePanel();
		END;
	END DoUpdateDegraded;

	PROCEDURE UpdateReko*;

	VAR datasetname, dataname, monotonename, degradedname, rekoname: ARRAY 1024 OF CHAR;
		rekovec: vyBase.Object;

	BEGIN
		antsCommands.InitScan( "datasetname=STRING dataname=STRING monotonename=STRING rekoname=STRING rekovec=OBJ" );

		IF antsCommands.ExpectString( "datasetname", datasetname ) & antsCommands.ExpectString( "dataname", dataname ) &
		    antsCommands.ExpectString( "monotonename", monotonename ) & antsCommands.ExpectString( "degradedname", degradedname ) &
		    antsCommands.ExpectString( "rekoname", rekoname ) & antsCommands.ExpectObject( "rekovec", rekovec ) THEN

			DoUpdateReko( datasetname, dataname, monotonename, degradedname, rekoname, rekovec );
		END;
	END UpdateReko;

	PROCEDURE DoUpdateReko*( datasetname, dataname, monotonename, degradedname, rekoname: ARRAY OF CHAR;  VAR rekovec: vyBase.Object );

	VAR reko, results, dummy: antsArrays.X1d;

	BEGIN
		IF antsPottsSimDataStructure.ExistReko( set, datasetname, dataname, monotonename, degradedname, rekoname ) THEN
			COPY( rekoname, actualReko );  reko := antsPottsSimDataStructure.GetReko( set, datasetname, dataname, monotonename, degradedname, rekoname );
			results := antsPottsSimDataStructure.GetResults( set, datasetname, dataname, monotonename, degradedname, rekoname );  SetVec( rekovec, reko );
			SetRekoFields( results );
		ELSE COPY( "", actualReko );  NEW( dummy, 100 );  SetVec( rekovec, dummy );  NEW( dummy, 6 );  SetRekoFields( dummy );
		END;

		UpdatePanel();
	END DoUpdateReko;

	PROCEDURE NoiseLoop*;

	VAR meanM, medianM, hampelM, saegezahnM, huberM: ARRAY 1024 OF CHAR;
		gaussN, laplaceN, expN, uniformN, rekotype, gammatype, estimateNoise: ARRAY 1024 OF CHAR;
		noiseParameter, gamma, var: LONGREAL;  noiseNumber: LONGINT;  datarekovec, degradedvec, rekovec: vyBase.Object;
		datareko, dataresults, degraded, reko, results, dummy: antsArrays.X1d;
		datarekoname, degradedname, rekoname: ARRAY 1024 OF CHAR;

	BEGIN
		antsCommands.InitScan( "" );

		IF antsCommands.ExpectString( "meanMonotone", meanM ) & antsCommands.ExpectString( "medianMonotone", medianM ) &
		    antsCommands.ExpectString( "hampelMonotone", hampelM ) & antsCommands.ExpectString( "saegezahnMonotone", saegezahnM ) &
		    antsCommands.ExpectString( "huberMonotone", huberM ) & antsCommands.ExpectString( "gaussNoise", gaussN ) &
		    antsCommands.ExpectString( "laplaceNoise", laplaceN ) & antsCommands.ExpectString( "expNoise", expN ) &
		    antsCommands.ExpectString( "uniformNoise", uniformN ) & antsCommands.ExpectReal( "noiseParameter", noiseParameter ) &
		    antsCommands.ExpectNumber( "noiseNumber", noiseNumber ) & antsCommands.ExpectString( "estimateNoise", estimateNoise ) &
		    antsCommands.ExpectString( "RekoType", rekotype ) & antsCommands.ExpectString( "GammaType", gammatype ) &
		    antsCommands.ExpectReal( "gamma", gamma ) & antsCommands.ExpectObject( "datarekovec", datarekovec ) &
		    antsCommands.ExpectObject( "degradedvec", degradedvec ) & antsCommands.ExpectObject( "rekovec", rekovec ) THEN

			IF estimateNoise = "No" THEN
				IF noiseParameter <= 0 THEN antsSecurity.Halt( "Please choose a Noise-Variance > 0 !!!" );  END;
			END;

			IF (gaussN = "Yes") OR (laplaceN = "Yes") OR (expN = "Yes") OR (uniformN = "Yes") THEN
				IF noiseNumber <= 0 THEN antsSecurity.Halt( "Please choose a Number of Noise > 0 !!!" );  END;
			END;

			IF antsPottsSimDataStructure.ExistDataChain( set, actualDataSet ) THEN
				IF antsPottsSimDataStructure.GetDataChainLen( set, actualDataSet ) < 2 THEN
					IF estimateNoise = "Yes" THEN antsSecurity.Halt( "Estimate Noise is not executable. There must be at least two datas !!!" );  END;
				END;

				antsPottsSimAdministration.DoDataLoop( set, actualDataSet, meanM, medianM, hampelM, saegezahnM, huberM, gaussN, laplaceN, expN, uniformN,
																					noiseParameter, noiseNumber, rekotype, gammatype, gamma, estimateNoise );
			END;
		END;

		IF ~antsPottsSimDataStructure.ExistDataReko( set, actualDataSet, actualData, actualDataReko ) THEN
			IF antsPottsSimDataStructure.ExistDataRekoChain( set, actualDataSet, actualData ) THEN
				antsPottsSimDataStructure.GetDataRekoName( set, actualDataSet, actualData, 0, datarekoname );
				datareko := antsPottsSimDataStructure.GetDataReko( set, actualDataSet, actualData, datarekoname );
				dataresults := antsPottsSimDataStructure.GetDataResults( set, actualDataSet, actualData, datarekoname );  COPY( datarekoname, actualDataReko );
				SetVec( datarekovec, datareko );  SetDataRekoFields( dataresults );
			ELSE actualDataReko := "";  NEW( dummy, 100 );  SetVec( datarekovec, dummy );  NEW( dummy, 6 );  SetDataRekoFields( dummy );
			END;
		ELSE
			datareko := antsPottsSimDataStructure.GetDataReko( set, actualDataSet, actualData, actualDataReko );
			dataresults := antsPottsSimDataStructure.GetDataResults( set, actualDataSet, actualData, actualDataReko );  SetVec( datarekovec, datareko );
			SetDataRekoFields( dataresults );
		END;

		IF ~antsPottsSimDataStructure.ExistDegraded( set, actualDataSet, actualData, actualMonotone, actualDegraded ) THEN
			IF antsPottsSimDataStructure.ExistDegradedChain( set, actualDataSet, actualData, actualMonotone ) THEN
				antsPottsSimDataStructure.GetDegradedName( set, actualDataSet, actualData, actualMonotone, 0, degradedname );
				degraded := antsPottsSimDataStructure.GetDegraded( set, actualDataSet, actualData, actualMonotone, degradedname );
				var := antsPottsSimDataStructure.GetNoiseVariance( set, actualDataSet, actualData, actualMonotone, degradedname );
				COPY( degradedname, actualDegraded );  SetVec( degradedvec, degraded );  SetNoiseField( var );

				IF ~antsPottsSimDataStructure.ExistReko( set, actualDataSet, actualData, actualMonotone, actualDegraded, actualReko ) THEN
					IF antsPottsSimDataStructure.ExistRekoChain( set, actualDataSet, actualData, actualMonotone, actualDegraded ) THEN
						antsPottsSimDataStructure.GetRekoName( set, actualDataSet, actualData, actualMonotone, actualDegraded, 0, rekoname );
						reko := antsPottsSimDataStructure.GetReko( set, actualDataSet, actualData, actualMonotone, actualDegraded, rekoname );
						results := antsPottsSimDataStructure.GetResults( set, actualDataSet, actualData, actualMonotone, actualDegraded, rekoname );
						COPY( rekoname, actualReko );  SetVec( rekovec, reko );  SetRekoFields( results );
					ELSE actualReko := "";  NEW( dummy, 100 );  SetVec( rekovec, dummy );  NEW( dummy, 6 );  SetRekoFields( dummy );
					END;
				ELSE
					reko := antsPottsSimDataStructure.GetReko( set, actualDataSet, actualData, actualMonotone, actualDegraded, actualReko );
					results := antsPottsSimDataStructure.GetResults( set, actualDataSet, actualData, actualMonotone, actualDegraded, actualReko );
					SetVec( rekovec, reko );  SetRekoFields( results );
				END;
			ELSE
				actualDegraded := "";  NEW( dummy, 100 );  SetVec( degradedvec, dummy );  SetVec( rekovec, dummy );  NEW( dummy, 6 );  SetRekoFields( dummy );
				SetNoiseField( 0 );
			END;
		ELSE
			degraded := antsPottsSimDataStructure.GetDegraded( set, actualDataSet, actualData, actualMonotone, actualDegraded );
			var := antsPottsSimDataStructure.GetNoiseVariance( set, actualDataSet, actualData, actualMonotone, actualDegraded );  SetVec( degradedvec, degraded );
			SetNoiseField( var );
		END;

		UpdatePanel();
	END NoiseLoop;

	PROCEDURE RekoLoop*;

	VAR rekotype, gammatype, rekoname, datarekoname: ARRAY 1024 OF CHAR;
		gamma: LONGREAL;  rekovec, datarekovec: vyBase.Object;  reko, results, dummy, datareko, dataresults: antsArrays.X1d;

	BEGIN
		antsCommands.InitScan( "" );

		IF antsCommands.ExpectString( "RekoType", rekotype ) & antsCommands.ExpectString( "GammaType", gammatype ) &
		    antsCommands.ExpectReal( "gamma", gamma ) & antsCommands.ExpectObject( "rekovec", rekovec ) &
		    antsCommands.ExpectObject( "datarekovec", datarekovec ) THEN

			antsPottsSimAdministration.DoDataRekoLoop( set, actualDataSet, rekotype, gammatype, gamma, datarekoname );
			antsPottsSimAdministration.DoREKOLoop( set, actualDataSet, rekotype, gammatype, gamma );

			IF antsPottsSimDataStructure.ExistDataRekoChain( set, actualDataSet, actualData ) THEN
				datareko := antsPottsSimDataStructure.GetDataReko( set, actualDataSet, actualData, datarekoname );
				dataresults := antsPottsSimDataStructure.GetDataResults( set, actualDataSet, actualData, datarekoname );  COPY( datarekoname, actualDataReko );
				SetVec( datarekovec, datareko );  SetDataRekoFields( dataresults );
			END;

			IF antsPottsSimDataStructure.ExistRekoChain( set, actualDataSet, actualData, actualMonotone, actualDegraded ) THEN
				reko := antsPottsSimDataStructure.GetReko( set, actualDataSet, actualData, actualMonotone, actualDegraded, datarekoname );
				results := antsPottsSimDataStructure.GetResults( set, actualDataSet, actualData, actualMonotone, actualDegraded, datarekoname );
				COPY( datarekoname, actualReko );  SetVec( rekovec, reko );  SetRekoFields( results );
			ELSE NEW( dummy, 100 );  SetVec( rekovec, dummy );  NEW( dummy, 6 );  SetRekoFields( dummy );  actualReko := "";  Out.String( "HERE?" )
			END;
		END;

		UpdatePanel();
	END RekoLoop;

	PROCEDURE SetDataRekoFields*( dataresults: antsArrays.X1d );

	VAR textf: Objects.Object;

	BEGIN
		textf := Gadgets.FindObj( mycont, "Norm1DataReko" );

		IF textf # NIL THEN Attributes.SetLongReal( textf, "Value", dataresults[0] );  Gadgets.Update( textf );
		END;

		textf := Gadgets.FindObj( mycont, "Norm2DataReko" );

		IF textf # NIL THEN Attributes.SetLongReal( textf, "Value", dataresults[1] );  Gadgets.Update( textf );
		END;

		textf := Gadgets.FindObj( mycont, "Norm3DataReko" );

		IF textf # NIL THEN Attributes.SetLongReal( textf, "Value", dataresults[2] );  Gadgets.Update( textf );
		END;

		textf := Gadgets.FindObj( mycont, "MADDataReko" );

		IF textf # NIL THEN Attributes.SetLongReal( textf, "Value", dataresults[3] );  Gadgets.Update( textf );
		END;

		textf := Gadgets.FindObj( mycont, "GammaDataReko" );

		IF textf # NIL THEN Attributes.SetLongReal( textf, "Value", dataresults[4] );  Gadgets.Update( textf );
		END;

		textf := Gadgets.FindObj( mycont, "JumpNrDataReko" );

		IF textf # NIL THEN Attributes.SetLongReal( textf, "Value", dataresults[5] );  Gadgets.Update( textf );
		END;
	END SetDataRekoFields;

	PROCEDURE SetRekoFields*( results: antsArrays.X1d );

	VAR textf: Objects.Object;

	BEGIN
		textf := Gadgets.FindObj( mycont, "Norm1Reko" );

		IF textf # NIL THEN Attributes.SetLongReal( textf, "Value", results[0] );  Gadgets.Update( textf );
		END;

		textf := Gadgets.FindObj( mycont, "Norm2Reko" );

		IF textf # NIL THEN Attributes.SetLongReal( textf, "Value", results[1] );  Gadgets.Update( textf );
		END;

		textf := Gadgets.FindObj( mycont, "Norm3Reko" );

		IF textf # NIL THEN Attributes.SetLongReal( textf, "Value", results[2] );  Gadgets.Update( textf );
		END;

		textf := Gadgets.FindObj( mycont, "MADReko" );

		IF textf # NIL THEN Attributes.SetLongReal( textf, "Value", results[3] );  Gadgets.Update( textf );
		END;

		textf := Gadgets.FindObj( mycont, "GammaReko" );

		IF textf # NIL THEN Attributes.SetLongReal( textf, "Value", results[4] );  Gadgets.Update( textf );
		END;

		textf := Gadgets.FindObj( mycont, "JumpNrReko" );

		IF textf # NIL THEN Attributes.SetLongReal( textf, "Value", results[5] );  Gadgets.Update( textf );
		END;
	END SetRekoFields;

	PROCEDURE SetNoiseField*( var: LONGREAL );

	VAR textf: Objects.Object;

	BEGIN
		textf := Gadgets.FindObj( mycont, "NoiseVariance" );

		IF textf # NIL THEN Attributes.SetLongReal( textf, "Value", var );  Gadgets.Update( textf );
		END;
	END SetNoiseField;

	PROCEDURE SetVec*( VAR vector: vyBase.Object;  array: antsArrays.X1d );

	VAR msg: vyPort.AdjustCoordMsg;

	BEGIN
		WITH vector: vyLongrealVec.tVector DO
			vyLongrealVec.SetLen( vector, LEN( array ) );  vyLongrealVec.CopyToVec( array^, vector, LEN( array ), 0, 0 );  vyBase.Update( vector );
			vyBase.ForUsersHandle( vector, msg );
		END;
	END SetVec;

	PROCEDURE DelDataset*;

	VAR datavec, datarekovec, monotonevec, degradedvec, rekovec: vyBase.Object;

	BEGIN
		antsCommands.InitScan( "datasetname=STRING dataname=STRING datavec=OBJ datarekovec=OBJ monotonevec=OBJ degradedvec=OBJ rekovec=OBJ" );

		IF antsCommands.ExpectObject( "datavec", datavec ) & antsCommands.ExpectObject( "datarekovec", datarekovec ) &
		    antsCommands.ExpectObject( "monotonevec", monotonevec ) & antsCommands.ExpectObject( "degradedvec", degradedvec ) &
		    antsCommands.ExpectObject( "rekovec", rekovec ) THEN

			DoDelDataset( datavec, datarekovec, monotonevec, degradedvec, rekovec );
		END;
	END DelDataset;

	PROCEDURE DoDelDataset( VAR datavec: vyBase.Object;  VAR datarekovec: vyBase.Object;  VAR monotonevec: vyBase.Object;  VAR degradedvec: vyBase.Object;
											   VAR rekovec: vyBase.Object );

	VAR dataChainname, dataname, datarekoname, monotonename, degradedname, rekoname: ARRAY 1024 OF CHAR;
		data, datareko, monotone, degraded, reko, dummy, dataresults, results: antsArrays.X1d;  var: LONGREAL;

	BEGIN
		IF ~antsPottsSimDataStructure.DeleteDataset( set, actualDataSet ) THEN antsSecurity.Halt( "Error in deleting actual dataset !!!!" );  END;

		IF ~antsPottsSimDataStructure.ExistChain( set ) THEN
			COPY( "", actualDataSet );  COPY( "", actualData );  COPY( "", actualMonotone );  COPY( "", actualDataReko );  COPY( "", actualDegraded );
			COPY( "", actualReko );  COPY( "", actualResults );  NEW( dummy, 100 );  SetVec( datavec, dummy );  SetVec( datarekovec, dummy );
			SetVec( monotonevec, dummy );  SetVec( degradedvec, dummy );  SetVec( rekovec, dummy );  NEW( dummy, 6 );  SetDataRekoFields( dummy );
			SetRekoFields( dummy );  SetNoiseField( 0 );
		ELSE
			antsPottsSimDataStructure.GetDataSetName( set, 0, dataChainname );

			IF ~antsPottsSimDataStructure.ExistDataChain( set, dataChainname ) THEN
				COPY( dataChainname, actualDataSet );  COPY( "", actualData );  COPY( "", actualMonotone );  COPY( "", actualDataReko );  COPY( "", actualDegraded );
				COPY( "", actualReko );  COPY( "", actualResults );  NEW( dummy, 100 );  SetVec( datavec, dummy );  SetVec( datarekovec, dummy );
				SetVec( monotonevec, dummy );  SetVec( degradedvec, dummy );  SetVec( rekovec, dummy );  NEW( dummy, 6 );  SetDataRekoFields( dummy );
				SetRekoFields( dummy );  SetNoiseField( 0 );
			ELSE
				antsPottsSimDataStructure.GetDataName( set, dataChainname, 0, dataname );
				data := antsPottsSimDataStructure.GetData( set, dataChainname, dataname );

				IF ~antsPottsSimDataStructure.ExistDataRekoChain( set, dataChainname, dataname ) THEN
					COPY( "", actualDataReko );  NEW( dummy, 100 );  SetVec( datarekovec, dummy );  NEW( dummy, 6 );  SetDataRekoFields( dummy );
				ELSE
					antsPottsSimDataStructure.GetDataRekoName( set, dataChainname, dataname, 0, datarekoname );
					datareko := antsPottsSimDataStructure.GetDataReko( set, dataChainname, dataname, datarekoname );
					dataresults := antsPottsSimDataStructure.GetDataResults( set, dataChainname, dataname, datarekoname );  COPY( datarekoname, actualDataReko );
					SetVec( datarekovec, datareko );  SetDataRekoFields( dataresults );
				END;

				IF ~antsPottsSimDataStructure.ExistMonotoneChain( set, dataChainname, dataname ) THEN
					COPY( dataChainname, actualDataSet );  COPY( dataname, actualData );  COPY( "", actualMonotone );  COPY( "", actualDegraded );
					COPY( "", actualReko );  COPY( "", actualResults );  NEW( dummy, 100 );  SetVec( datavec, data );  SetVec( monotonevec, dummy );
					SetVec( degradedvec, dummy );  SetVec( rekovec, dummy );  NEW( dummy, 6 );  SetRekoFields( dummy );  SetNoiseField( 0 );
				ELSE
					antsPottsSimDataStructure.GetMonotoneName( set, dataChainname, dataname, 0, monotonename );
					monotone := antsPottsSimDataStructure.GetMonotone( set, dataChainname, dataname, monotonename );

					IF ~antsPottsSimDataStructure.ExistDegradedChain( set, dataChainname, dataname, monotonename ) THEN
						COPY( dataChainname, actualDataSet );  COPY( dataname, actualData );  COPY( monotonename, actualMonotone );  COPY( "", actualDegraded );
						COPY( "", actualReko );  COPY( "", actualResults );  NEW( dummy, 100 );  SetVec( datavec, data );  SetVec( monotonevec, monotone );
						SetVec( degradedvec, dummy );  SetVec( rekovec, dummy );  NEW( dummy, 6 );  SetRekoFields( dummy );  SetNoiseField( 0 );
					ELSE
						antsPottsSimDataStructure.GetDegradedName( set, dataChainname, dataname, monotonename, 0, degradedname );
						degraded := antsPottsSimDataStructure.GetDegraded( set, dataChainname, dataname, monotonename, degradedname );
						var := antsPottsSimDataStructure.GetNoiseVariance( set, dataChainname, dataname, monotonename, degradedname );

						IF ~antsPottsSimDataStructure.ExistRekoChain( set, dataChainname, dataname, monotonename, degradedname ) THEN
							COPY( dataChainname, actualDataSet );  COPY( dataname, actualData );  COPY( monotonename, actualMonotone );
							COPY( degradedname, actualDegraded );  COPY( "", actualReko );  COPY( "", actualResults );  NEW( dummy, 100 );  SetVec( datavec, data );
							SetVec( monotonevec, monotone );  SetVec( degradedvec, degraded );  SetVec( rekovec, dummy );  NEW( dummy, 6 );  SetRekoFields( dummy );
							SetNoiseField( var );
						ELSE
							antsPottsSimDataStructure.GetRekoName( set, dataChainname, dataname, monotonename, degradedname, 0, rekoname );
							reko := antsPottsSimDataStructure.GetReko( set, dataChainname, dataname, monotonename, degradedname, rekoname );
							results := antsPottsSimDataStructure.GetResults( set, dataChainname, dataname, monotonename, degradedname, rekoname );
							COPY( dataChainname, actualDataSet );  COPY( dataname, actualData );  COPY( monotonename, actualMonotone );
							COPY( degradedname, actualDegraded );  COPY( rekoname, actualReko );  COPY( "", actualResults );  SetVec( datavec, data );
							SetVec( monotonevec, monotone );  SetVec( degradedvec, degraded );  SetVec( rekovec, reko );  SetRekoFields( results );  SetNoiseField( var );
						END;
					END;
				END;
			END;
		END;

		UpdatePanel();
	END DoDelDataset;

	PROCEDURE DelData*;

	VAR datavec, datarekovec, monotonevec, degradedvec, rekovec: vyBase.Object;

	BEGIN
		antsCommands.InitScan( "datavec=OBJ datarekovec=OBJ monotonevec=OBJ degradedvec=OBJ rekovec=OBJ" );

		IF antsCommands.ExpectObject( "datavec", datavec ) & antsCommands.ExpectObject( "datarekovec", datarekovec ) &
		    antsCommands.ExpectObject( "monotonevec", monotonevec ) & antsCommands.ExpectObject( "degradedvec", degradedvec ) &
		    antsCommands.ExpectObject( "rekovec", rekovec ) THEN

			IF ~antsPottsSimDataStructure.DeleteData( set, actualDataSet, actualData ) THEN antsSecurity.Halt( "Error in deleting actual data !!!!" );
			END;

			DoUpdateDataset( actualDataSet, datavec, datarekovec, monotonevec, degradedvec, rekovec );  UpdatePanel();
		END;
	END DelData;

	PROCEDURE DelAllDegraded*;

	VAR len, i: LONGINT;
		dataname: ARRAY 1024 OF CHAR;
		datavec, datarekovec, monotonevec, degradedvec, rekovec: vyBase.Object;

	BEGIN
		antsCommands.InitScan( "datavec=OBJ datarekovec=OBJ monotonevec=OBJ degradedvec=OBJ rekovec=OBJ" );

		IF antsCommands.ExpectObject( "datavec", datavec ) & antsCommands.ExpectObject( "datarekovec", datarekovec ) &
		    antsCommands.ExpectObject( "monotonevec", monotonevec ) & antsCommands.ExpectObject( "degradedvec", degradedvec ) &
		    antsCommands.ExpectObject( "rekovec", rekovec ) THEN

			len := antsPottsSimDataStructure.GetDataChainLen( set, actualDataSet );

			FOR i := 0 TO len - 1 DO
				antsPottsSimDataStructure.GetDataName( set, actualDataSet, i, dataname );

				IF ~antsPottsSimDataStructure.DeleteDegraded( set, actualDataSet, dataname, actualMonotone, actualDegraded ) THEN
					antsSecurity.Halt( "Error in deleting actual degraded !!!!" );
				END;
			END;

			DoUpdateDataset( actualDataSet, datavec, datarekovec, monotonevec, degradedvec, rekovec );  UpdatePanel();
		END;
	END DelAllDegraded;

	PROCEDURE DelAllReko*;

	VAR len, i: LONGINT;
		degradedname: ARRAY 1024 OF CHAR;
		datavec, datarekovec, monotonevec, degradedvec, rekovec: vyBase.Object;

	BEGIN
		antsCommands.InitScan( "datavec=OBJ datarekovec=OBJ monotonevec=OBJ degradedvec=OBJ rekovec=OBJ" );

		IF antsCommands.ExpectObject( "datavec", datavec ) & antsCommands.ExpectObject( "datarekovec", datarekovec ) &
		    antsCommands.ExpectObject( "monotonevec", monotonevec ) & antsCommands.ExpectObject( "degradedvec", degradedvec ) &
		    antsCommands.ExpectObject( "rekovec", rekovec ) THEN

			len := antsPottsSimDataStructure.GetDegradedChainLen( set, actualDataSet, actualData, actualMonotone );

			FOR i := 0 TO len - 1 DO
				antsPottsSimDataStructure.GetDegradedName( set, actualDataSet, actualData, actualMonotone, i, degradedname );

				IF ~antsPottsSimDataStructure.DeleteReko( set, actualDataSet, actualData, actualMonotone, degradedname, actualReko ) THEN
					antsSecurity.Halt( "Error in deleting actual Reko !!!!" );
				END;
			END;

			DoUpdateDataset( actualDataSet, datavec, datarekovec, monotonevec, degradedvec, rekovec );  UpdatePanel();
		END;
	END DelAllReko;

	PROCEDURE CopyData*;

	VAR dataname, datarekoname, monotonename, degradedname, rekoname: ARRAY 1024 OF CHAR;
		data, datareko, degraded, reko, dataresults, results, diffs, estimatedNoises, meanM, medianM, hampelM, saegezahnM, huberM: antsArrays.X1d;
		i, j, k: LONGINT;  parameter: LONGREAL;

	BEGIN
		IF (set = NIL ) OR (actualDataSet = "") OR (actualData = "") THEN antsSecurity.Halt( "No data to copy !!!" );  ELSE
			IF ~antsPottsSimDataStructure.ExistDataChain( set, "Copys" ) THEN antsPottsSimDataStructure.NewDataChain( set, "Copys" );  END;

			dataname := "";  Strings.Append( dataname, actualDataSet );  Strings.Append( dataname, actualData );
			data := antsPottsSimDataStructure.GetData( set, actualDataSet, actualData );
			diffs := antsPottsSimDataStructure.GetAllDiff( set, actualDataSet, actualData );
			estimatedNoises := antsPottsSimDataStructure.GetAllEN( set, actualDataSet, actualData );
			meanM := antsPottsSimDataStructure.GetMonotone( set, actualDataSet, actualData, "MeanMonotone" );
			medianM := antsPottsSimDataStructure.GetMonotone( set, actualDataSet, actualData, "MedianMonotone" );
			hampelM := antsPottsSimDataStructure.GetMonotone( set, actualDataSet, actualData, "HampelMonotone" );
			saegezahnM := antsPottsSimDataStructure.GetMonotone( set, actualDataSet, actualData, "SaegezahnMonotone" );
			huberM := antsPottsSimDataStructure.GetMonotone( set, actualDataSet, actualData, "HuberMonotone" );
			antsPottsSimDataStructure.NewData( set, "Copys", dataname, data, diffs, estimatedNoises, meanM, medianM, hampelM, saegezahnM, huberM );

			IF antsPottsSimDataStructure.ExistDataRekoChain( set, actualDataSet, actualData ) THEN
				FOR i := 0 TO antsPottsSimDataStructure.GetDataRekoChainLen( set, actualDataSet, actualData ) - 1 DO
					antsPottsSimDataStructure.GetDataRekoName( set, actualDataSet, actualData, i, datarekoname );
					datareko := antsPottsSimDataStructure.GetDataReko( set, actualDataSet, actualData, datarekoname );
					dataresults := antsPottsSimDataStructure.GetDataResults( set, actualDataSet, actualData, datarekoname );
					antsPottsSimDataStructure.NewDataReko( set, "Copys", dataname, datarekoname, datareko, dataresults );
				END;
			ELSE datarekoname := "";
			END;

			FOR i := 0 TO 4 DO
				IF i = 0 THEN monotonename := "MeanMonotone";
				ELSIF i = 1 THEN monotonename := "MedianMonotone";
				ELSIF i = 2 THEN monotonename := "HampelMonotone";
				ELSIF i = 3 THEN monotonename := "SaegezahnMonotone";
				ELSIF i = 4 THEN monotonename := "HuberMonotone";
				END;

				IF antsPottsSimDataStructure.ExistDegradedChain( set, actualDataSet, actualData, monotonename ) THEN
					FOR j := 0 TO antsPottsSimDataStructure.GetDegradedChainLen( set, actualDataSet, actualData, monotonename ) - 1 DO
						antsPottsSimDataStructure.GetDegradedName( set, actualDataSet, actualData, monotonename, j, degradedname );
						degraded := antsPottsSimDataStructure.GetDegraded( set, actualDataSet, actualData, monotonename, degradedname );
						parameter := antsPottsSimDataStructure.GetNoiseVariance( set, actualDataSet, actualData, monotonename, degradedname );
						antsPottsSimDataStructure.NewDegraded( set, "Copys", dataname, monotonename, degradedname, degraded, parameter );

						IF antsPottsSimDataStructure.ExistRekoChain( set, actualDataSet, actualData, monotonename, degradedname ) THEN
							FOR k := 0 TO antsPottsSimDataStructure.GetRekoChainLen( set, actualDataSet, actualData, monotonename, degradedname ) - 1 DO
								antsPottsSimDataStructure.GetRekoName( set, actualDataSet, actualData, monotonename, degradedname, k, rekoname );
								reko := antsPottsSimDataStructure.GetReko( set, actualDataSet, actualData, monotonename, degradedname, rekoname );
								results := antsPottsSimDataStructure.GetResults( set, actualDataSet, actualData, monotonename, degradedname, rekoname );
								antsPottsSimDataStructure.NewReko( set, "Copys", dataname, monotonename, degradedname, rekoname, reko, results );
							END;
						ELSE rekoname := "";
						END;
					END;
				ELSE degradedname := "";
				END;
			END;
		END;

		actualDataSet := "Copys";  actualData := "";  Strings.Append( actualData, dataname );  actualDataReko := "";
		Strings.Append( actualDataReko, datarekoname );  actualMonotone := "";  Strings.Append( actualMonotone, monotonename );  actualDegraded := "";
		Strings.Append( actualDegraded, degradedname );  actualReko := "";  Strings.Append( actualReko, rekoname );  UpdatePanel();
	END CopyData;

(**PROCEDURE Output*;

BEGIN
	antsPottsSimAdministration.DoOutput();
END Output; **)


	PROCEDURE ShowAllDataRekoResults*;

	VAR RR: antsFiles.Rider;  i, k, l, j: LONGINT;
		outfile: ARRAY 1024 OF CHAR;
		actualData, actualDataSet: ARRAY 1024 OF CHAR;
		u, v, w, x, y, z: vyRealVec.tVector;  dataresults, data: antsArrays.X1d;
		m: ARRAY 1024 OF CHAR;
		s: antsArrays.X1d;

	BEGIN
		antsCommands.InitScan( "" );

		IF antsCommands.ExpectString( "actualData", actualData ) & antsCommands.ExpectString( "actualDataSet", actualDataSet ) THEN

			outfile := "Simulation/Ergebnisse/";  Strings.Append( outfile, "DataDataReko" );  Strings.Append( outfile, ".txt" );

			IF ~RR.Old( outfile ) THEN RR.ForceNew( outfile );
			ELSE RR.Close;
			END;

			RR.Set( 2 );  RR.WriteString( actualDataSet );  RR.WriteString( " - " );  RR.WriteString( actualData );  RR.WriteLn();  RR.WriteLn();

			RR.Write( TAB );  RR.Write( TAB );  RR.WriteString( "1-Norm" );  RR.Write( TAB );  RR.Write( TAB );  RR.Write( TAB );  RR.Write( TAB );  RR.Write( TAB );
			RR.Write( TAB );  RR.Write( TAB );  RR.WriteString( "2-Norm" );  RR.Write( TAB );  RR.Write( TAB );  RR.Write( TAB );  RR.Write( TAB );  RR.Write( TAB );
			RR.Write( TAB );  RR.Write( TAB );  RR.WriteString( "Inf-Norm" );  RR.Write( TAB );  RR.Write( TAB );  RR.Write( TAB );  RR.Write( TAB );  RR.Write( TAB );
			RR.Write( TAB );  RR.Write( TAB );  RR.WriteString( "MAD" );  RR.Write( TAB );  RR.Write( TAB );  RR.Write( TAB );  RR.Write( TAB );  RR.Write( TAB );
			RR.Write( TAB );  RR.Write( TAB );  RR.WriteString( "Gamma" );  RR.Write( TAB );  RR.Write( TAB );  RR.Write( TAB );  RR.Write( TAB );  RR.Write( TAB );
			RR.Write( TAB );  RR.Write( TAB );  RR.WriteString( "Jump-Nr" );  RR.WriteLn();  RR.WriteLn();

			IF antsPottsSimDataStructure.ExistDataChain( set, actualDataSet ) THEN
				data := antsPottsSimDataStructure.GetData( set, actualDataSet, actualData );

				FOR i := 0 TO antsPottsSimDataStructure.GetDataRekoChainLen( set, actualDataSet, actualData ) - 1 DO
					antsPottsSimDataStructure.GetDataRekoName( set, actualDataSet, actualData, i, m );
					s := antsPottsSimDataStructure.GetDataResults( set, actualDataSet, actualData, m );  u := vyRealVec.New( 0 );
					FOR j := 0 TO 5 DO vyRealVec.Append( s[j], u );  END;
					FOR k := 0 TO 5 DO RR.WriteReal( vyRealVec.Get( u, k ) );  RR.Write( TAB );  END;
					RR.WriteString( m );  RR.WriteLn();  RR.WriteLn();
				END;
			END;

			RR.Close;
		END;
	END ShowAllDataRekoResults;

	PROCEDURE ShowAllRekoResults*;

	VAR RR: antsFiles.Rider;  i, j, k, l, m, n: LONGINT;
		outfile: ARRAY 1024 OF CHAR;
		appendedName, actualData, actualDataSet: ARRAY 1024 OF CHAR;
		noiseVariance: LONGREAL;  x, y: vyRealVec.tVector;  dataresults, data: antsArrays.X1d;
		monotoneName, degradedName, rekoName: ARRAY 1024 OF CHAR;
		s, t, u: antsArrays.X1d;

	BEGIN
		antsCommands.InitScan( "" );

		IF antsCommands.ExpectString( "actualData", actualData ) & antsCommands.ExpectString( "actualDataSet", actualDataSet ) THEN

			outfile := "Simulation/Ergebnisse/";  Strings.Append( outfile, "RekoResults" );  Strings.Append( outfile, ".txt" );

			IF ~RR.Old( outfile ) THEN RR.ForceNew( outfile );
			ELSE RR.Close;
			END;

			RR.Set( 2 );  RR.WriteString( actualDataSet );  RR.WriteString( " - " );  RR.WriteString( actualData );  RR.WriteLn();  RR.WriteLn();
			FOR i := 0 TO antsPottsSimDataStructure.GetMonotoneChainLen( set, actualDataSet, actualData ) - 1 DO
				antsPottsSimDataStructure.GetMonotoneName( set, actualDataSet, actualData, i, monotoneName );  RR.WriteString( monotoneName );  RR.WriteLn();
				RR.WriteLn();

				RR.Write( TAB );  RR.Write( TAB );  RR.WriteString( "1-Norm" );  RR.Write( TAB );  RR.Write( TAB );  RR.Write( TAB );  RR.Write( TAB );  RR.Write( TAB );
				RR.Write( TAB );  RR.Write( TAB );  RR.WriteString( "2-Norm" );  RR.Write( TAB );  RR.Write( TAB );  RR.Write( TAB );  RR.Write( TAB );  RR.Write( TAB );
				RR.Write( TAB );  RR.Write( TAB );  RR.WriteString( "Inf-Norm" );  RR.Write( TAB );  RR.Write( TAB );  RR.Write( TAB );  RR.Write( TAB );
				RR.Write( TAB );  RR.Write( TAB );  RR.Write( TAB );  RR.WriteString( "MAD" );  RR.Write( TAB );  RR.Write( TAB );  RR.Write( TAB );  RR.Write( TAB );
				RR.Write( TAB );  RR.Write( TAB );  RR.Write( TAB );  RR.WriteString( "Gamma" );  RR.Write( TAB );  RR.Write( TAB );  RR.Write( TAB );  RR.Write( TAB );
				RR.Write( TAB );  RR.Write( TAB );  RR.Write( TAB );  RR.WriteString( "Jump-Nr" );  RR.WriteLn();  RR.WriteLn();

				FOR j := 0 TO antsPottsSimDataStructure.GetDegradedChainLen( set, actualDataSet, actualData, monotoneName ) - 1 DO
					antsPottsSimDataStructure.GetDegradedName( set, actualDataSet, actualData, monotoneName, j, degradedName );
					s := antsPottsSimDataStructure.GetDegraded( set, actualDataSet, actualData, monotoneName, degradedName );

					FOR l := 0 TO antsPottsSimDataStructure.GetRekoChainLen( set, actualDataSet, actualData, monotoneName, degradedName ) - 1 DO
						antsPottsSimDataStructure.GetRekoName( set, actualDataSet, actualData, monotoneName, degradedName, l, rekoName );
						t := antsPottsSimDataStructure.GetReko( set, actualDataSet, actualData, monotoneName, degradedName, rekoName );
						u := antsPottsSimDataStructure.GetResults( set, actualDataSet, actualData, monotoneName, degradedName, rekoName );
						noiseVariance := antsPottsSimDataStructure.GetNoiseVariance( set, actualDataSet, actualData, monotoneName, degradedName );

						y := vyRealVec.New( 0 );
						FOR m := 0 TO LEN( u ) - 1 DO vyRealVec.Append( u[m], y );  END;
						FOR n := 0 TO 5 DO RR.WriteReal( vyRealVec.Get( y, n ) );  RR.Write( TAB );  END;
						Strings.Append( appendedName, degradedName );  Strings.Append( appendedName, "  -  " );  Strings.Append( appendedName, rekoName );
						Strings.Append( appendedName, " - Var: " );  RR.WriteString( appendedName );  RR.WriteLReal( noiseVariance );  appendedName := "";
						RR.WriteLn();  RR.WriteLn();

					END;
				END;
			END;

			RR.Close;
		END;

	END ShowAllRekoResults;

	PROCEDURE OutDeb*;

	VAR a, b, c: ARRAY 1024 OF CHAR;

	BEGIN
		antsCommands.InitScan( "" );

		IF antsCommands.ExpectString( "a", a ) & antsCommands.ExpectString( "b", b ) & antsCommands.ExpectString( "c", c ) THEN

			Out.LongReal( antsPottsSimDataStructure.GetDiff( set, a, b, c ), 10 );  Out.Ln();  Out.LongReal( antsPottsSimDataStructure.GetEN( set, a, b, c ), 10 );
		END;
	END OutDeb;

BEGIN
	actualDataSet := "";  actualData := "";  actualDataReko := "";  actualMonotone := "";  actualDegraded := "";  actualReko := "";  actualResults := "";

END antsPottsSimulation.