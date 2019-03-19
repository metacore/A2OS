MODULE antsPottsSimDataStructure IN Oberon;
(* Dieses Modul stellt eine hierarchische Datenbank zur Verfügung. Natürlich ist bei dieser Implementierung
	nicht sehr viel Bewertung auf das Laufzeitverhalten eingegangen. *)

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


IMPORT vyBase, Objects, antsObjects, antsArrays, vyLongreal, antsSecurity;

TYPE
	(* Objekte, mit deren Hilfe die Datenbank aufgebaut wird. *)

	SetChain* = POINTER TO SetChainDesc;
	SetChainDesc* = RECORD (vyBase.ObjDesc)
		chain: POINTER TO ARRAY OF DataChain;
	END;

	DataChain* = POINTER TO DataChainDesc;
	DataChainDesc* = RECORD (vyBase.ObjDesc)
		name: POINTER TO ARRAY OF CHAR;
		dataChain: POINTER TO ARRAY OF Data;
	END;

	Data* = POINTER TO DataDesc;
	DataDesc* = RECORD (vyBase.ObjDesc)
		name: POINTER TO ARRAY OF CHAR;
		data: antsArrays.X1d;
		diffs: antsArrays.X1d;
		estimatedNoises: antsArrays.X1d;
		datarekoChain: POINTER TO ARRAY OF Reko;
		monotoneChain: POINTER TO ARRAY OF Monotone;
	END;

	Monotone* = POINTER TO MonotoneDesc;
	MonotoneDesc* = RECORD (vyBase.ObjDesc)
		name: POINTER TO ARRAY OF CHAR;
		monotone: antsArrays.X1d;
		degradedChain: POINTER TO ARRAY OF Degraded;
		noisenumbers: antsArrays.L1d;
	END;

	Degraded* = POINTER TO DegradedDesc;
	DegradedDesc* = RECORD (vyBase.ObjDesc)
		name: POINTER TO ARRAY OF CHAR;
		degraded: antsArrays.X1d;
		variance: LONGREAL;
		rekoChain: POINTER TO ARRAY OF Reko;
	END;

	Reko* = POINTER TO RekoDesc;
	RekoDesc* = RECORD (vyBase.ObjDesc)
		name: POINTER TO ARRAY OF CHAR;
		reko: antsArrays.X1d;
		results: antsArrays.X1d;
	END;

	(* Die folgenden Generierungsmethoden Gen# dienen nur dazu, dass die erzeugte Datenbank auch in Oberon
	gespeichert bleibt. *)

	PROCEDURE Gen0*;

	VAR m: SetChain;

	BEGIN
		NEW( m );  Objects.NewObj := m;  antsObjects.Register( m );
	END Gen0;

	PROCEDURE Gen1*;

	VAR m: DataChain;

	BEGIN
		NEW( m );  Objects.NewObj := m;  antsObjects.Register( m );
	END Gen1;

	PROCEDURE Gen2*;

	VAR m: Data;

	BEGIN
		NEW( m );  Objects.NewObj := m;  antsObjects.Register( m );
	END Gen2;

	PROCEDURE Gen3*;

	VAR m: Monotone;

	BEGIN
		NEW( m );  Objects.NewObj := m;  antsObjects.Register( m );
	END Gen3;

	PROCEDURE Gen4*;

	VAR m: Degraded;

	BEGIN
		NEW( m );  Objects.NewObj := m;  antsObjects.Register( m );
	END Gen4;

	PROCEDURE Gen5*;

	VAR m: Reko;

	BEGIN
		NEW( m );  Objects.NewObj := m;  antsObjects.Register( m );
	END Gen5;

(* Die folgenden Exist-Methoden funktionieren alle gleich: Es wird abgefragt, ob das jeweilige Objekt existiert.
	Wenn ja, wird ein TRUE zurückgegeben, wenn nicht, dann ein FALSE. *)

	PROCEDURE ExistChain*( set: SetChain ): BOOLEAN;

	BEGIN
		IF set = NIL THEN RETURN FALSE;  ELSE
			IF set.chain = NIL THEN RETURN FALSE;  ELSE RETURN TRUE;  END;
		END;
	END ExistChain;

	PROCEDURE ExistDataset*( set: SetChain;  dataChainname: ARRAY OF CHAR ): BOOLEAN;

	VAR i: LONGINT;

	BEGIN
		IF ~ExistChain( set ) THEN RETURN FALSE;  ELSE
			FOR i := 0 TO LEN( set.chain ) - 1 DO
				IF set.chain[i].name^ = dataChainname THEN RETURN TRUE;  END;
			END;
		END;

		RETURN FALSE;
	END ExistDataset;

	PROCEDURE ExistDataChain*( set: SetChain;  dataChainname: ARRAY OF CHAR ): BOOLEAN;

	VAR i: LONGINT;

	BEGIN
		IF ~ExistDataset( set, dataChainname ) THEN RETURN FALSE;  ELSE
			FOR i := 0 TO LEN( set.chain ) - 1 DO
				IF set.chain[i].name^ = dataChainname THEN
					IF set.chain[i].dataChain = NIL THEN RETURN FALSE;  ELSE RETURN TRUE;  END;
				END;
			END;
		END;
	END ExistDataChain;

	PROCEDURE ExistData*( set: SetChain;  dataChainname, dataname: ARRAY OF CHAR ): BOOLEAN;

	VAR i, j: LONGINT;

	BEGIN
		IF ~ExistDataChain( set, dataChainname ) THEN RETURN FALSE;  ELSE
			FOR i := 0 TO LEN( set.chain ) - 1 DO
				IF set.chain[i].name^ = dataChainname THEN
					FOR j := 0 TO LEN( set.chain[i].dataChain ) - 1 DO
						IF set.chain[i].dataChain[j].name^ = dataname THEN RETURN TRUE;  END;
					END;
				END;
			END;
		END;

		RETURN FALSE;
	END ExistData;

	PROCEDURE ExistDataRekoChain*( set: SetChain;  dataChainname, dataname: ARRAY OF CHAR ): BOOLEAN;

	VAR i, j: LONGINT;

	BEGIN
		IF ~ExistData( set, dataChainname, dataname ) THEN RETURN FALSE;  ELSE
			FOR i := 0 TO LEN( set.chain ) - 1 DO
				IF set.chain[i].name^ = dataChainname THEN
					FOR j := 0 TO LEN( set.chain[i].dataChain ) - 1 DO
						IF set.chain[i].dataChain[j].name^ = dataname THEN
							IF set.chain[i].dataChain[j].datarekoChain = NIL THEN RETURN FALSE;  ELSE RETURN TRUE;  END;
						END;
					END;
				END;
			END;
		END;
	END ExistDataRekoChain;

	PROCEDURE ExistDataReko*( set: SetChain;  dataChainname, dataname, datarekoname: ARRAY OF CHAR ): BOOLEAN;

	VAR i, j, k: LONGINT;

	BEGIN
		IF ~ExistDataRekoChain( set, dataChainname, dataname ) THEN RETURN FALSE;  ELSE
			FOR i := 0 TO LEN( set.chain ) - 1 DO
				IF set.chain[i].name^ = dataChainname THEN
					FOR j := 0 TO LEN( set.chain[i].dataChain ) - 1 DO
						IF set.chain[i].dataChain[j].name^ = dataname THEN
							FOR k := 0 TO LEN( set.chain[i].dataChain[j].datarekoChain ) - 1 DO
								IF set.chain[i].dataChain[j].datarekoChain[k].name^ = datarekoname THEN RETURN TRUE;  END;
							END;
						END;
					END;
				END;
			END;
		END;

		RETURN FALSE;
	END ExistDataReko;

	PROCEDURE ExistMonotoneChain*( set: SetChain;  dataChainname, dataname: ARRAY OF CHAR ): BOOLEAN;

	VAR i, j: LONGINT;

	BEGIN
		IF ~ExistData( set, dataChainname, dataname ) THEN RETURN FALSE;  ELSE
			FOR i := 0 TO LEN( set.chain ) - 1 DO
				IF set.chain[i].name^ = dataChainname THEN
					FOR j := 0 TO LEN( set.chain[i].dataChain ) - 1 DO
						IF set.chain[i].dataChain[j].name^ = dataname THEN
							IF set.chain[i].dataChain[j].monotoneChain = NIL THEN RETURN FALSE;  ELSE RETURN TRUE;  END;
						END;
					END;
				END;
			END;
		END;
	END ExistMonotoneChain;

	PROCEDURE ExistMonotone*( set: SetChain;  dataChainname, dataname, monotonename: ARRAY OF CHAR ): BOOLEAN;

	VAR i, j, k: LONGINT;

	BEGIN
		IF ~ExistMonotoneChain( set, dataChainname, dataname ) THEN RETURN FALSE;  ELSE
			FOR i := 0 TO LEN( set.chain ) - 1 DO
				IF set.chain[i].name^ = dataChainname THEN
					FOR j := 0 TO LEN( set.chain[i].dataChain ) - 1 DO
						IF set.chain[i].dataChain[j].name^ = dataname THEN
							FOR k := 0 TO LEN( set.chain[i].dataChain[j].monotoneChain ) - 1 DO
								IF set.chain[i].dataChain[j].monotoneChain[k].name^ = monotonename THEN RETURN TRUE;  END;
							END;
						END;
					END;
				END;
			END;
		END;

		RETURN FALSE;
	END ExistMonotone;

	PROCEDURE ExistDegradedChain*( set: SetChain;  dataChainname, dataname, monotonename: ARRAY OF CHAR ): BOOLEAN;

	VAR i, j, k: LONGINT;

	BEGIN
		IF ~ExistMonotone( set, dataChainname, dataname, monotonename ) THEN RETURN FALSE;  ELSE
			FOR i := 0 TO LEN( set.chain ) - 1 DO
				IF set.chain[i].name^ = dataChainname THEN
					FOR j := 0 TO LEN( set.chain[i].dataChain ) - 1 DO
						IF set.chain[i].dataChain[j].name^ = dataname THEN
							FOR k := 0 TO LEN( set.chain[i].dataChain[j].monotoneChain ) - 1 DO
								IF set.chain[i].dataChain[j].monotoneChain[k].name^ = monotonename THEN
									IF set.chain[i].dataChain[j].monotoneChain[k].degradedChain = NIL THEN RETURN FALSE;
									ELSE RETURN TRUE;
									END;
								END;
							END;
						END;
					END;
				END;
			END;
		END;
	END ExistDegradedChain;

	PROCEDURE ExistDegraded*( set: SetChain;  dataChainname, dataname, monotonename, degradedname: ARRAY OF CHAR ): BOOLEAN;

	VAR i, j, k, l: LONGINT;

	BEGIN
		IF ~ExistDegradedChain( set, dataChainname, dataname, monotonename ) THEN RETURN FALSE;  ELSE
			FOR i := 0 TO LEN( set.chain ) - 1 DO
				IF set.chain[i].name^ = dataChainname THEN
					FOR j := 0 TO LEN( set.chain[i].dataChain ) - 1 DO
						IF set.chain[i].dataChain[j].name^ = dataname THEN
							FOR k := 0 TO LEN( set.chain[i].dataChain[j].monotoneChain ) - 1 DO
								IF set.chain[i].dataChain[j].monotoneChain[k].name^ = monotonename THEN
									FOR l := 0 TO LEN( set.chain[i].dataChain[j].monotoneChain[k].degradedChain ) - 1 DO
										IF set.chain[i].dataChain[j].monotoneChain[k].degradedChain[l].name^ = degradedname THEN
											RETURN TRUE;
										END;
									END;
								END;
							END;
						END;
					END;
				END;
			END;
		END;

		RETURN FALSE;
	END ExistDegraded;

	PROCEDURE ExistRekoChain*( set: SetChain;  dataChainname, dataname, monotonename, degradedname: ARRAY OF CHAR ): BOOLEAN;

	VAR i, j, k, l: LONGINT;

	BEGIN
		IF ~ExistDegraded( set, dataChainname, dataname, monotonename, degradedname ) THEN RETURN FALSE;  ELSE
			FOR i := 0 TO LEN( set.chain ) - 1 DO
				IF set.chain[i].name^ = dataChainname THEN
					FOR j := 0 TO LEN( set.chain[i].dataChain ) - 1 DO
						IF set.chain[i].dataChain[j].name^ = dataname THEN
							FOR k := 0 TO LEN( set.chain[i].dataChain[j].monotoneChain ) - 1 DO
								IF set.chain[i].dataChain[j].monotoneChain[k].name^ = monotonename THEN
									FOR l := 0 TO LEN( set.chain[i].dataChain[j].monotoneChain[k].degradedChain ) - 1 DO
										IF set.chain[i].dataChain[j].monotoneChain[k].degradedChain[l].name^ = degradedname THEN
											IF set.chain[i].dataChain[j].monotoneChain[k].degradedChain[l].rekoChain = NIL THEN
												RETURN FALSE;
											ELSE RETURN TRUE;
											END;
										END;
									END;
								END;
							END;
						END;
					END;
				END;
			END;
		END;
	END ExistRekoChain;

	PROCEDURE ExistReko*( set: SetChain;
										   dataChainname, dataname, monotonename, degradedname, rekoname: ARRAY OF CHAR ): BOOLEAN;

	VAR i, j, k, l, m: LONGINT;

	BEGIN
		IF ~ExistRekoChain( set, dataChainname, dataname, monotonename, degradedname ) THEN RETURN FALSE;  ELSE
			FOR i := 0 TO LEN( set.chain ) - 1 DO
				IF set.chain[i].name^ = dataChainname THEN
					FOR j := 0 TO LEN( set.chain[i].dataChain ) - 1 DO
						IF set.chain[i].dataChain[j].name^ = dataname THEN
							FOR k := 0 TO LEN( set.chain[i].dataChain[j].monotoneChain ) - 1 DO
								IF set.chain[i].dataChain[j].monotoneChain[k].name^ = monotonename THEN
									FOR l := 0 TO LEN( set.chain[i].dataChain[j].monotoneChain[k].degradedChain ) - 1 DO
										IF set.chain[i].dataChain[j].monotoneChain[k].degradedChain[l].name^ = degradedname THEN
											FOR m := 0 TO LEN( set.chain[i].dataChain[j].monotoneChain[k].degradedChain[l].rekoChain ) - 1 DO
												IF set.chain[i].dataChain[j].monotoneChain[k].degradedChain[l].rekoChain[m].name^ =
												    rekoname THEN
													RETURN TRUE;
												END;
											END;
										END;
									END;
								END;
							END;
						END;
					END;
				END;
			END;
		END;

		RETURN FALSE;
	END ExistReko;

(* Die folgenden Get...Len-Methoden berechnen die Länge des jeweiligen Arrays in der Datenbank und geben diese zurück. *)

	PROCEDURE GetSetChainLen*( set: SetChain ): LONGINT;

	BEGIN
		IF ~ExistChain( set ) THEN RETURN -1;  ELSE RETURN LEN( set.chain );  END;
	END GetSetChainLen;

	PROCEDURE GetDataChainLen*( set: SetChain;  dataChainname: ARRAY OF CHAR ): LONGINT;

	VAR i: LONGINT;

	BEGIN
		IF ~ExistDataChain( set, dataChainname ) THEN RETURN -1;  ELSE
			FOR i := 0 TO LEN( set.chain ) - 1 DO
				IF set.chain[i].name^ = dataChainname THEN RETURN LEN( set.chain[i].dataChain );  END;
			END;
		END;
	END GetDataChainLen;

	PROCEDURE GetDataRekoChainLen*( set: SetChain;  dataChainname, dataname: ARRAY OF CHAR ): LONGINT;

	VAR i, j: LONGINT;

	BEGIN
		IF ~ExistDataRekoChain( set, dataChainname, dataname ) THEN RETURN -1;  ELSE
			FOR i := 0 TO LEN( set.chain ) - 1 DO
				IF set.chain[i].name^ = dataChainname THEN
					FOR j := 0 TO LEN( set.chain[i].dataChain ) - 1 DO
						IF set.chain[i].dataChain[j].name^ = dataname THEN RETURN LEN( set.chain[i].dataChain[j].datarekoChain );  END;
					END;
				END;
			END;
		END;
	END GetDataRekoChainLen;

	PROCEDURE GetMonotoneChainLen*( set: SetChain;  dataChainname, dataname: ARRAY OF CHAR ): LONGINT;

	VAR i, j: LONGINT;

	BEGIN
		IF ~ExistMonotoneChain( set, dataChainname, dataname ) THEN RETURN -1;  ELSE
			FOR i := 0 TO LEN( set.chain ) - 1 DO
				IF set.chain[i].name^ = dataChainname THEN
					FOR j := 0 TO LEN( set.chain[i].dataChain ) - 1 DO
						IF set.chain[i].dataChain[j].name^ = dataname THEN RETURN LEN( set.chain[i].dataChain[j].monotoneChain );  END;
					END;
				END;
			END;
		END;
	END GetMonotoneChainLen;

	PROCEDURE GetDegradedChainLen*( set: SetChain;  dataChainname, dataname, monotonename: ARRAY OF CHAR ): LONGINT;

	VAR i, j, k: LONGINT;

	BEGIN
		IF ~ExistDegradedChain( set, dataChainname, dataname, monotonename ) THEN RETURN -1;  ELSE
			FOR i := 0 TO LEN( set.chain ) - 1 DO
				IF set.chain[i].name^ = dataChainname THEN
					FOR j := 0 TO LEN( set.chain[i].dataChain ) - 1 DO
						IF set.chain[i].dataChain[j].name^ = dataname THEN
							FOR k := 0 TO LEN( set.chain[i].dataChain[j].monotoneChain ) - 1 DO
								IF set.chain[i].dataChain[j].monotoneChain[k].name^ = monotonename THEN
									RETURN LEN( set.chain[i].dataChain[j].monotoneChain[k].degradedChain );
								END;
							END;
						END;
					END;
				END;
			END;
		END;
	END GetDegradedChainLen;

	PROCEDURE GetRekoChainLen*( set: SetChain;  dataChainname, dataname, monotonename: ARRAY OF CHAR;
														 degradedname: ARRAY OF CHAR ): LONGINT;

	VAR i, j, k, l: LONGINT;

	BEGIN
		IF ~ExistRekoChain( set, dataChainname, dataname, monotonename, degradedname ) THEN RETURN -1;  ELSE
			FOR i := 0 TO LEN( set.chain ) - 1 DO
				IF set.chain[i].name^ = dataChainname THEN
					FOR j := 0 TO LEN( set.chain[i].dataChain ) - 1 DO
						IF set.chain[i].dataChain[j].name^ = dataname THEN
							FOR k := 0 TO LEN( set.chain[i].dataChain[j].monotoneChain ) - 1 DO
								IF set.chain[i].dataChain[j].monotoneChain[k].name^ = monotonename THEN
									FOR l := 0 TO LEN( set.chain[i].dataChain[j].monotoneChain[k].degradedChain ) - 1 DO
										IF set.chain[i].dataChain[j].monotoneChain[k].degradedChain[l].name^ = degradedname THEN
											RETURN LEN( set.chain[i].dataChain[j].monotoneChain[k].degradedChain[l].rekoChain );
										END;
									END;
								END;
							END;
						END;
					END;
				END;
			END;
		END;
	END GetRekoChainLen;

(* Im folgenden gibt es 2 Arten von Get-Methoden: Get...Name und Get... Erstere geben den Namen des Objekts an der
	Stelle ind im Array der Datenbank zurück. Letztere geben die Daten (data, datareko, monotone, reko, results) in
	den jeweiligen Objekten zurück. *)

	PROCEDURE GetDataSetName*( set: SetChain;  ind: LONGINT;  VAR a: ARRAY OF CHAR );

	VAR i: LONGINT;

	BEGIN
		IF ~ExistChain( set ) THEN antsSecurity.Halt( "No SetChain found !!!" );  ELSE
			IF (ind >= 0) & (ind < LEN( set.chain )) THEN
				FOR i := 0 TO LEN( set.chain[ind].name ) - 1 DO a[i] := set.chain[ind].name[i];  END;
			END;
		END;
	END GetDataSetName;

	PROCEDURE GetData*( set: SetChain;  dataChainname, dataname: ARRAY OF CHAR ): antsArrays.X1d;

	VAR i, j: LONGINT;

	BEGIN
		IF ~ExistData( set, dataChainname, dataname ) THEN antsSecurity.Halt( "No Data found !!!" );  ELSE
			FOR i := 0 TO LEN( set.chain ) - 1 DO
				IF set.chain[i].name^ = dataChainname THEN
					FOR j := 0 TO LEN( set.chain[i].dataChain ) - 1 DO
						IF set.chain[i].dataChain[j].name^ = dataname THEN RETURN set.chain[i].dataChain[j].data;  END;
					END;
				END;
			END;
		END;
	END GetData;

	PROCEDURE GetDataName*( set: SetChain;  dataChainname: ARRAY OF CHAR;  ind: LONGINT;  VAR a: ARRAY OF CHAR );

	VAR i, j: LONGINT;

	BEGIN
		IF ~ExistDataChain( set, dataChainname ) THEN antsSecurity.Halt( "No Data found !!!" );  ELSE
			FOR i := 0 TO LEN( set.chain ) - 1 DO
				IF set.chain[i].name^ = dataChainname THEN
					IF (ind >= 0) & (ind < LEN( set.chain[i].dataChain )) THEN
						FOR j := 0 TO LEN( set.chain[i].dataChain[ind].name ) - 1 DO a[j] := set.chain[i].dataChain[ind].name[j];  END;
					ELSE antsSecurity.Halt( "No Data found !!!" );
					END;
				END;
			END;
		END;
	END GetDataName;

	PROCEDURE GetDataReko*( set: SetChain;  dataChainname, dataname, datarekoname: ARRAY OF CHAR ): antsArrays.X1d;

	VAR i, j, k: LONGINT;

	BEGIN
		IF ~ExistDataReko( set, dataChainname, dataname, datarekoname ) THEN antsSecurity.Halt( "No Data found !!!" );  ELSE
			FOR i := 0 TO LEN( set.chain ) - 1 DO
				IF set.chain[i].name^ = dataChainname THEN
					FOR j := 0 TO LEN( set.chain[i].dataChain ) - 1 DO
						IF set.chain[i].dataChain[j].name^ = dataname THEN
							FOR k := 0 TO LEN( set.chain[i].dataChain[j].datarekoChain ) - 1 DO
								IF set.chain[i].dataChain[j].datarekoChain[k].name^ = datarekoname THEN
									RETURN set.chain[i].dataChain[j].datarekoChain[k].reko;
								END;
							END;
						END;
					END;
				END;
			END;
		END;
	END GetDataReko;

	PROCEDURE GetDataResults*( set: SetChain;  dataChainname, dataname, datarekoname: ARRAY OF CHAR ): antsArrays.X1d;

	VAR i, j, k: LONGINT;

	BEGIN
		IF ~ExistDataReko( set, dataChainname, dataname, datarekoname ) THEN antsSecurity.Halt( "No Data found !!!" );  ELSE
			FOR i := 0 TO LEN( set.chain ) - 1 DO
				IF set.chain[i].name^ = dataChainname THEN
					FOR j := 0 TO LEN( set.chain[i].dataChain ) - 1 DO
						IF set.chain[i].dataChain[j].name^ = dataname THEN
							FOR k := 0 TO LEN( set.chain[i].dataChain[j].datarekoChain ) - 1 DO
								IF set.chain[i].dataChain[j].datarekoChain[k].name^ = datarekoname THEN
									RETURN set.chain[i].dataChain[j].datarekoChain[k].results;
								END;
							END;
						END;
					END;
				END;
			END;
		END;
	END GetDataResults;

	PROCEDURE GetDataRekoName*( set: SetChain;  dataChainname, dataname: ARRAY OF CHAR;  ind: LONGINT;  VAR a: ARRAY OF CHAR );

	VAR i, j, k: LONGINT;

	BEGIN
		IF ~ExistDataRekoChain( set, dataChainname, dataname ) THEN antsSecurity.Halt( "No Data found !!!" );  ELSE
			FOR i := 0 TO LEN( set.chain ) - 1 DO
				IF set.chain[i].name^ = dataChainname THEN
					FOR j := 0 TO LEN( set.chain[i].dataChain ) - 1 DO
						IF set.chain[i].dataChain[j].name^ = dataname THEN
							IF (ind >= 0) & (ind < LEN( set.chain[i].dataChain[j].datarekoChain )) THEN
								FOR k := 0 TO LEN( set.chain[i].dataChain[j].datarekoChain[ind].name ) - 1 DO
									a[k] := set.chain[i].dataChain[j].datarekoChain[ind].name[k];
								END;
							ELSE antsSecurity.Halt( "No Data found !!!" );
							END;
						END;
					END;
				END;
			END;
		END;
	END GetDataRekoName;

	PROCEDURE GetMonotone*( set: SetChain;  dataChainname, dataname, monotonename: ARRAY OF CHAR ): antsArrays.X1d;

	VAR i, j, k: LONGINT;

	BEGIN
		IF ~ExistMonotone( set, dataChainname, dataname, monotonename ) THEN antsSecurity.Halt( "No Data found !!!" );  ELSE
			FOR i := 0 TO LEN( set.chain ) - 1 DO
				IF set.chain[i].name^ = dataChainname THEN
					FOR j := 0 TO LEN( set.chain[i].dataChain ) - 1 DO
						IF set.chain[i].dataChain[j].name^ = dataname THEN
							FOR k := 0 TO LEN( set.chain[i].dataChain[j].monotoneChain ) - 1 DO
								IF set.chain[i].dataChain[j].monotoneChain[k].name^ = monotonename THEN
									RETURN set.chain[i].dataChain[j].monotoneChain[k].monotone;
								END;
							END;
						END;
					END;
				END;
			END;
		END;
	END GetMonotone;

	PROCEDURE GetMonotoneName*( set: SetChain;  dataChainname, dataname: ARRAY OF CHAR;  ind: LONGINT;  VAR a: ARRAY OF CHAR );

	VAR i, j, k: LONGINT;

	BEGIN
		IF ~ExistMonotoneChain( set, dataChainname, dataname ) THEN antsSecurity.Halt( "No Data found !!!" );  ELSE
			FOR i := 0 TO LEN( set.chain ) - 1 DO
				IF set.chain[i].name^ = dataChainname THEN
					FOR j := 0 TO LEN( set.chain[i].dataChain ) - 1 DO
						IF set.chain[i].dataChain[j].name^ = dataname THEN
							IF (ind >= 0) & (ind < LEN( set.chain[i].dataChain[j].monotoneChain )) THEN
								FOR k := 0 TO LEN( set.chain[i].dataChain[j].monotoneChain[ind].name ) - 1 DO
									a[k] := set.chain[i].dataChain[j].monotoneChain[ind].name[k];
								END;
							ELSE antsSecurity.Halt( "No Data found !!!" );
							END;
						END;
					END;
				END;
			END;
		END;
	END GetMonotoneName;

	PROCEDURE GetDegraded*( set: SetChain;
												dataChainname, dataname, monotonename, degradedname: ARRAY OF CHAR ): antsArrays.X1d;

	VAR i, j, k, l: LONGINT;

	BEGIN
		IF ~ExistDegraded( set, dataChainname, dataname, monotonename, degradedname ) THEN antsSecurity.Halt( "No Data found !!!" );  ELSE
			FOR i := 0 TO LEN( set.chain ) - 1 DO
				IF set.chain[i].name^ = dataChainname THEN
					FOR j := 0 TO LEN( set.chain[i].dataChain ) - 1 DO
						IF set.chain[i].dataChain[j].name^ = dataname THEN
							FOR k := 0 TO LEN( set.chain[i].dataChain[j].monotoneChain ) - 1 DO
								IF set.chain[i].dataChain[j].monotoneChain[k].name^ = monotonename THEN
									FOR l := 0 TO LEN( set.chain[i].dataChain[j].monotoneChain[k].degradedChain ) - 1 DO
										IF set.chain[i].dataChain[j].monotoneChain[k].degradedChain[l].name^ = degradedname THEN
											RETURN set.chain[i].dataChain[j].monotoneChain[k].degradedChain[l].degraded;
										END;
									END;
								END;
							END;
						END;
					END;
				END;
			END;
		END;
	END GetDegraded;

	PROCEDURE GetDegradedName*( set: SetChain;  dataChainname, dataname, monotonename: ARRAY OF CHAR;  ind: LONGINT;
														  VAR a: ARRAY OF CHAR );

	VAR i, j, k, l: LONGINT;

	BEGIN
		IF ~ExistDegradedChain( set, dataChainname, dataname, monotonename ) THEN antsSecurity.Halt( "No Data found !!!" );  ELSE
			FOR i := 0 TO LEN( set.chain ) - 1 DO
				IF set.chain[i].name^ = dataChainname THEN
					FOR j := 0 TO LEN( set.chain[i].dataChain ) - 1 DO
						IF set.chain[i].dataChain[j].name^ = dataname THEN
							FOR k := 0 TO LEN( set.chain[i].dataChain[j].monotoneChain ) - 1 DO
								IF set.chain[i].dataChain[j].monotoneChain[k].name^ = monotonename THEN
									IF (ind >= 0) & (ind < LEN( set.chain[i].dataChain[j].monotoneChain[k].degradedChain )) THEN
										FOR l := 0 TO LEN( set.chain[i].dataChain[j].monotoneChain[k].degradedChain[ind].name ) - 1 DO
											a[l] := set.chain[i].dataChain[j].monotoneChain[k].degradedChain[ind].name[l];
										END;
									ELSE antsSecurity.Halt( "No Data found !!!" );
									END;
								END;
							END;
						END;
					END;
				END;
			END;
		END;
	END GetDegradedName;

	PROCEDURE GetReko*( set: SetChain;
										dataChainname, dataname, monotonename, degradedname, rekoname: ARRAY OF CHAR ): antsArrays.X1d;

	VAR i, j, k, l, m: LONGINT;

	BEGIN
		IF ~ExistReko( set, dataChainname, dataname, monotonename, degradedname, rekoname ) THEN
			antsSecurity.Halt( "No Data found !!!" );
		ELSE
			FOR i := 0 TO LEN( set.chain ) - 1 DO
				IF set.chain[i].name^ = dataChainname THEN
					FOR j := 0 TO LEN( set.chain[i].dataChain ) - 1 DO
						IF set.chain[i].dataChain[j].name^ = dataname THEN
							FOR k := 0 TO LEN( set.chain[i].dataChain[j].monotoneChain ) - 1 DO
								IF set.chain[i].dataChain[j].monotoneChain[k].name^ = monotonename THEN
									FOR l := 0 TO LEN( set.chain[i].dataChain[j].monotoneChain[k].degradedChain ) - 1 DO
										IF set.chain[i].dataChain[j].monotoneChain[k].degradedChain[l].name^ = degradedname THEN
											FOR m := 0 TO LEN( set.chain[i].dataChain[j].monotoneChain[k].degradedChain[l].rekoChain ) - 1 DO
												IF set.chain[i].dataChain[j].monotoneChain[k].degradedChain[l].rekoChain[m].name^ =
												    rekoname THEN
													RETURN set.chain[i].dataChain[j].monotoneChain[k].degradedChain[l].rekoChain[m].reko;
												END;
											END;
										END;
									END;
								END;
							END;
						END;
					END;
				END;
			END;
		END;
	END GetReko;

	PROCEDURE GetRekoName*( set: SetChain;  dataChainname, dataname, monotonename, degradedname: ARRAY OF CHAR;
												  ind: LONGINT;  VAR a: ARRAY OF CHAR );

	VAR i, j, k, l, m: LONGINT;

	BEGIN
		IF ~ExistRekoChain( set, dataChainname, dataname, monotonename, degradedname ) THEN antsSecurity.Halt( "No Data found !!!" );  ELSE
			FOR i := 0 TO LEN( set.chain ) - 1 DO
				IF set.chain[i].name^ = dataChainname THEN
					FOR j := 0 TO LEN( set.chain[i].dataChain ) - 1 DO
						IF set.chain[i].dataChain[j].name^ = dataname THEN
							FOR k := 0 TO LEN( set.chain[i].dataChain[j].monotoneChain ) - 1 DO
								IF set.chain[i].dataChain[j].monotoneChain[k].name^ = monotonename THEN
									FOR l := 0 TO LEN( set.chain[i].dataChain[j].monotoneChain[k].degradedChain ) - 1 DO
										IF set.chain[i].dataChain[j].monotoneChain[k].degradedChain[l].name^ = degradedname THEN
											IF (ind >= 0) & (ind < LEN( set.chain[i].dataChain[j].monotoneChain[k].degradedChain[l].rekoChain )) THEN
												FOR m := 0 TO LEN( set.chain[i].dataChain[j].monotoneChain[k].degradedChain[l].rekoChain[ind].name ) - 1 DO
													a[m] :=
														set.chain[i].dataChain[j].monotoneChain[k].degradedChain[l].rekoChain[ind].name[m];
												END;
											ELSE antsSecurity.Halt( "No Data found !!!" );
											END;
										END;
									END;
								END;
							END;
						END;
					END;
				END;
			END;
		END;
	END GetRekoName;

	PROCEDURE GetResults*( set: SetChain;
											dataChainname, dataname, monotonename, degradedname, rekoname: ARRAY OF CHAR ): antsArrays.X1d;

	VAR i, j, k, l, m: LONGINT;

	BEGIN
		IF ~ExistReko( set, dataChainname, dataname, monotonename, degradedname, rekoname ) THEN
			antsSecurity.Halt( "No Data found !!!" );
		ELSE
			FOR i := 0 TO LEN( set.chain ) - 1 DO
				IF set.chain[i].name^ = dataChainname THEN
					FOR j := 0 TO LEN( set.chain[i].dataChain ) - 1 DO
						IF set.chain[i].dataChain[j].name^ = dataname THEN
							FOR k := 0 TO LEN( set.chain[i].dataChain[j].monotoneChain ) - 1 DO
								IF set.chain[i].dataChain[j].monotoneChain[k].name^ = monotonename THEN
									FOR l := 0 TO LEN( set.chain[i].dataChain[j].monotoneChain[k].degradedChain ) - 1 DO
										IF set.chain[i].dataChain[j].monotoneChain[k].degradedChain[l].name^ = degradedname THEN
											FOR m := 0 TO LEN( set.chain[i].dataChain[j].monotoneChain[k].degradedChain[l].rekoChain ) - 1 DO
												IF set.chain[i].dataChain[j].monotoneChain[k].degradedChain[l].rekoChain[m].name^ =
												    rekoname THEN
													RETURN set.chain[i].dataChain[j].monotoneChain[k].degradedChain[l].rekoChain[m].results;
												END;
											END;
										END;
									END;
								END;
							END;
						END;
					END;
				END;
			END;
		END;
	END GetResults;

	PROCEDURE GetDiff*( set: SetChain;  dataChainname, dataname, mon: ARRAY OF CHAR ): LONGREAL;
	(* Gibt die Differenz zwischen dem grössten und kleinsten Element in Monotone zurück. *)

	VAR i, j: LONGINT;

	BEGIN
		IF ~ExistData( set, dataChainname, dataname ) THEN antsSecurity.Halt( "No Data found !!!" );  ELSE
			FOR i := 0 TO LEN( set.chain ) - 1 DO
				IF set.chain[i].name^ = dataChainname THEN
					FOR j := 0 TO LEN( set.chain[i].dataChain ) - 1 DO
						IF set.chain[i].dataChain[j].name^ = dataname THEN
							IF mon = "Mean" THEN RETURN set.chain[i].dataChain[j].diffs[0];
							ELSIF mon = "Median" THEN RETURN set.chain[i].dataChain[j].diffs[1];
							ELSIF mon = "Hampel" THEN RETURN set.chain[i].dataChain[j].diffs[2];
							ELSIF mon = "Saegezahn" THEN RETURN set.chain[i].dataChain[j].diffs[3];
							ELSIF mon = "Huber" THEN RETURN set.chain[i].dataChain[j].diffs[4];
							ELSE RETURN set.chain[i].dataChain[j].diffs[0];
							END;
						END;
					END;
				END;
			END;
		END;
	END GetDiff;

	PROCEDURE GetAllDiff*( set: SetChain;  dataChainname, dataname: ARRAY OF CHAR ): antsArrays.X1d;
	(* Gibt alle Differenzen wie in obiger Methode zurück. *)

	VAR i, j: LONGINT;

	BEGIN
		IF ~ExistData( set, dataChainname, dataname ) THEN antsSecurity.Halt( "No Data found !!!" );  ELSE
			FOR i := 0 TO LEN( set.chain ) - 1 DO
				IF set.chain[i].name^ = dataChainname THEN
					FOR j := 0 TO LEN( set.chain[i].dataChain ) - 1 DO
						IF set.chain[i].dataChain[j].name^ = dataname THEN RETURN set.chain[i].dataChain[j].diffs;  END;
					END;
				END;
			END;
		END;
	END GetAllDiff;

	PROCEDURE GetEN*( set: SetChain;  dataChainname, dataname, mon: ARRAY OF CHAR ): LONGREAL;
	(* Gibt die Estimated Noises zurück. *)

	VAR i, j: LONGINT;

	BEGIN
		IF ~ExistData( set, dataChainname, dataname ) THEN antsSecurity.Halt( "No Data found !!!" );  ELSE
			FOR i := 0 TO LEN( set.chain ) - 1 DO
				IF set.chain[i].name^ = dataChainname THEN
					FOR j := 0 TO LEN( set.chain[i].dataChain ) - 1 DO
						IF set.chain[i].dataChain[j].name^ = dataname THEN
							IF mon = "Mean" THEN RETURN set.chain[i].dataChain[j].estimatedNoises[0];
							ELSIF mon = "Median" THEN RETURN set.chain[i].dataChain[j].estimatedNoises[1];
							ELSIF mon = "Hampel" THEN RETURN set.chain[i].dataChain[j].estimatedNoises[2];
							ELSIF mon = "Saegezahn" THEN RETURN set.chain[i].dataChain[j].estimatedNoises[3];
							ELSIF mon = "Huber" THEN RETURN set.chain[i].dataChain[j].estimatedNoises[4];
							ELSE RETURN set.chain[i].dataChain[j].estimatedNoises[0];
							END;
						END;
					END;
				END;
			END;
		END;
	END GetEN;

	PROCEDURE GetAllEN*( set: SetChain;  dataChainname, dataname: ARRAY OF CHAR ): antsArrays.X1d;
	(* Gibt alle Estimated Noises zurück. *)

	VAR i, j: LONGINT;

	BEGIN
		IF ~ExistData( set, dataChainname, dataname ) THEN antsSecurity.Halt( "No Data found !!!" );  ELSE
			FOR i := 0 TO LEN( set.chain ) - 1 DO
				IF set.chain[i].name^ = dataChainname THEN
					FOR j := 0 TO LEN( set.chain[i].dataChain ) - 1 DO
						IF set.chain[i].dataChain[j].name^ = dataname THEN RETURN set.chain[i].dataChain[j].estimatedNoises;  END;
					END;
				END;
			END;
		END;
	END GetAllEN;

	PROCEDURE IncNoiseNumber*( set: SetChain;  dataChainname, dataname, monotonename: ARRAY OF CHAR;  type: ARRAY OF CHAR );
	(* Incrementiert die Anzahl einer bestimmten Noise-Art. Ist nur wegen der Namensgebung implementiert. *)

	VAR i, j, k: LONGINT;

	BEGIN
		IF ~ExistMonotone( set, dataChainname, dataname, monotonename ) THEN antsSecurity.Halt( "No Monotone in IncNoiseNumber !!!" );  ELSE
			FOR i := 0 TO LEN( set.chain ) - 1 DO
				IF set.chain[i].name^ = dataChainname THEN
					FOR j := 0 TO LEN( set.chain[i].dataChain ) - 1 DO
						IF set.chain[i].dataChain[j].name^ = dataname THEN
							FOR k := 0 TO LEN( set.chain[i].dataChain[j].monotoneChain ) - 1 DO
								IF set.chain[i].dataChain[j].monotoneChain[k].name^ = monotonename THEN
									IF type = "Gauss" THEN INC( set.chain[i].dataChain[j].monotoneChain[k].noisenumbers[0] );
									ELSIF type = "Laplace" THEN INC( set.chain[i].dataChain[j].monotoneChain[k].noisenumbers[1] );
									ELSIF type = "Exp" THEN INC( set.chain[i].dataChain[j].monotoneChain[k].noisenumbers[2] );
									ELSIF type = "Uniform" THEN INC( set.chain[i].dataChain[j].monotoneChain[k].noisenumbers[3] );
									ELSE antsSecurity.Halt( "Such noisetype doesnt exist !!!" );
									END;
								END;
							END;
						END;
					END;
				END;
			END;
		END;
	END IncNoiseNumber;

	PROCEDURE DecNoiseNumber*( set: SetChain;  dataChainname, dataname, monotonename: ARRAY OF CHAR;  type: ARRAY OF CHAR );
	(* Decrementiert die Anzahl einer bestimmten Noise-Art. Ist nur wegen der Namensgebung implementiert. *)

	VAR i, j, k: LONGINT;

	BEGIN
		IF ~ExistMonotone( set, dataChainname, dataname, monotonename ) THEN antsSecurity.Halt( "No Monotone in DecNoiseNumber !!!" );  ELSE
			FOR i := 0 TO LEN( set.chain ) - 1 DO
				IF set.chain[i].name^ = dataChainname THEN
					FOR j := 0 TO LEN( set.chain[i].dataChain ) - 1 DO
						IF set.chain[i].dataChain[j].name^ = dataname THEN
							FOR k := 0 TO LEN( set.chain[i].dataChain[j].monotoneChain ) - 1 DO
								IF set.chain[i].dataChain[j].monotoneChain[k].name^ = monotonename THEN
									IF type = "Gauss" THEN DEC( set.chain[i].dataChain[j].monotoneChain[k].noisenumbers[0] );
									ELSIF type = "Laplace" THEN DEC( set.chain[i].dataChain[j].monotoneChain[k].noisenumbers[1] );
									ELSIF type = "Exp" THEN DEC( set.chain[i].dataChain[j].monotoneChain[k].noisenumbers[2] );
									ELSIF type = "Uniform" THEN DEC( set.chain[i].dataChain[j].monotoneChain[k].noisenumbers[3] );
									ELSE antsSecurity.Halt( "Such noisetype doesnt exist !!!" );
									END;
								END;
							END;
						END;
					END;
				END;
			END;
		END;
	END DecNoiseNumber;

	PROCEDURE GetNoiseNumber*( set: SetChain;  dataChainname, dataname, monotonename: ARRAY OF CHAR;  type: ARRAY OF CHAR ): LONGINT;
	(* Gibt die Anzahl einer bestimmten Noise-Art zurück. Ist nur wegen der Namensgebung implementiert. *)

	VAR i, j, k: LONGINT;

	BEGIN
		IF ~ExistMonotone( set, dataChainname, dataname, monotonename ) THEN antsSecurity.Halt( "No such monotone in IncNoiseNumber !!!" );  ELSE
			FOR i := 0 TO LEN( set.chain ) - 1 DO
				IF set.chain[i].name^ = dataChainname THEN
					FOR j := 0 TO LEN( set.chain[i].dataChain ) - 1 DO
						IF set.chain[i].dataChain[j].name^ = dataname THEN
							FOR k := 0 TO LEN( set.chain[i].dataChain[j].monotoneChain ) - 1 DO
								IF set.chain[i].dataChain[j].monotoneChain[k].name^ = monotonename THEN
									IF type = "Gauss" THEN RETURN set.chain[i].dataChain[j].monotoneChain[k].noisenumbers[0];
									ELSIF type = "Laplace" THEN RETURN set.chain[i].dataChain[j].monotoneChain[k].noisenumbers[1];
									ELSIF type = "Exp" THEN RETURN set.chain[i].dataChain[j].monotoneChain[k].noisenumbers[2];
									ELSIF type = "Uniform" THEN RETURN set.chain[i].dataChain[j].monotoneChain[k].noisenumbers[3];
									ELSE antsSecurity.Halt( "Such noisetype doesnt exist !!!" );
									END;
								END;
							END;
						END;
					END;
				END;
			END;
		END;
	END GetNoiseNumber;

	PROCEDURE GetNoiseVariance*( set: SetChain;  dataChainname, dataname, monotonename, degradedname: ARRAY OF CHAR ): LONGREAL;
	(* Gibt die Varianz einer Verrauschung zurück. *)

	VAR i, j, k, l: LONGINT;

	BEGIN
		IF ~ExistDegraded( set, dataChainname, dataname, monotonename, degradedname ) THEN antsSecurity.Halt( "No such degraded in GetNoiseVariance !!!" );  ELSE
			FOR i := 0 TO LEN( set.chain ) - 1 DO
				IF set.chain[i].name^ = dataChainname THEN
					FOR j := 0 TO LEN( set.chain[i].dataChain ) - 1 DO
						IF set.chain[i].dataChain[j].name^ = dataname THEN
							FOR k := 0 TO LEN( set.chain[i].dataChain[j].monotoneChain ) - 1 DO
								IF set.chain[i].dataChain[j].monotoneChain[k].name^ = monotonename THEN
									FOR l := 0 TO LEN( set.chain[i].dataChain[j].monotoneChain[k].degradedChain ) - 1 DO
										IF set.chain[i].dataChain[j].monotoneChain[k].degradedChain[l].name^ = degradedname THEN
											RETURN set.chain[i].dataChain[j].monotoneChain[k].degradedChain[l].variance;
										END;
									END;
								END;
							END;
						END;
					END;
				END;
			END;
		END;
	END GetNoiseVariance;

(* Die nun folgenden New...-Methoden erzeugen die Objekte in der Datenbank.
	Sie setzen den Namen und schreiben die Daten in die jeweiligen Felder.
	Zu erwähnen ist noch, dass bei der Speicherung von Ausgangsdaten automatisch die Monotones berechnet
	und mitgespeichert werden. Dies musste so implementiert werden, um Fehlerquellen möglichst gering zu halten.*)

	PROCEDURE NewSetChain*( VAR set: SetChain );

	BEGIN
		Gen0;  set := Objects.NewObj( SetChain );
	END NewSetChain;

	PROCEDURE NewDataChain*( VAR set: SetChain;  name: ARRAY OF CHAR );

	VAR dummy: POINTER TO ARRAY OF DataChain;
		newdataChain: DataChain;  i, len: LONGINT;

	BEGIN
		IF set.chain = NIL THEN len := 0;  NEW( set.chain, 1 );
		ELSE
			len := LEN( set.chain );  NEW( dummy, len );

			FOR i := 0 TO len - 1 DO dummy[i] := set.chain[i];  END;

			NEW( set.chain, len + 1 );

			FOR i := 0 TO len - 1 DO set.chain[i] := dummy[i];  END;
		END;

		Gen1;  newdataChain := Objects.NewObj( DataChain );  set.chain[len] := newdataChain;
		NEW( set.chain[len].name, LEN( name ) );

		FOR i := 0 TO LEN( name ) - 1 DO set.chain[len].name[i] := name[i];  END;
	END NewDataChain;

	PROCEDURE NewData*( VAR set: SetChain;  dataChainname: ARRAY OF CHAR;  name: ARRAY OF CHAR;
										 data, diffs, estimatedNoises, meanM, medianM, hampelM, saegezahnM, huberM: antsArrays.X1d );

	VAR dummy: POINTER TO ARRAY OF Data;
		newdata: Data;  len, i, j: LONGINT;

	BEGIN
		FOR j := 0 TO LEN( set.chain ) - 1 DO
			IF set.chain[j].name^ = dataChainname THEN
				IF set.chain[j].dataChain = NIL THEN len := 0;  NEW( set.chain[j].dataChain, 1 );
				ELSE
					len := LEN( set.chain[j].dataChain );  NEW( dummy, len );

					FOR i := 0 TO len - 1 DO dummy[i] := set.chain[j].dataChain[i];  END;

					NEW( set.chain[j].dataChain, len + 1 );

					FOR i := 0 TO len - 1 DO set.chain[j].dataChain[i] := dummy[i];  END;
				END;

				Gen2;  newdata := Objects.NewObj( Data );  set.chain[j].dataChain[len] := newdata;
				NEW( set.chain[j].dataChain[len].name, LEN( name ) );  NEW( set.chain[j].dataChain[len].diffs, 5 );
				NEW( set.chain[j].dataChain[len].estimatedNoises, 5 );  NEW( set.chain[j].dataChain[len].data, LEN( data ) );

				FOR i := 0 TO LEN( name ) - 1 DO set.chain[j].dataChain[len].name[i] := name[i];  END;

				vyLongreal.Copy( LEN( data ), data^, 0, set.chain[j].dataChain[len].data^, 0 );
				vyLongreal.Copy( 5, diffs^, 0, set.chain[j].dataChain[len].diffs^, 0 );
				vyLongreal.Copy( 5, estimatedNoises^, 0, set.chain[j].dataChain[len].estimatedNoises^, 0 );
				NewMonotone( set, dataChainname, name, "MeanMonotone", meanM );
				NewMonotone( set, dataChainname, name, "MedianMonotone", medianM );
				NewMonotone( set, dataChainname, name, "HampelMonotone", hampelM );
				NewMonotone( set, dataChainname, name, "SaegezahnMonotone", saegezahnM );
				NewMonotone( set, dataChainname, name, "HuberMonotone", huberM );
			END;
		END;
	END NewData;

	PROCEDURE NewDataReko*( VAR set: SetChain;  dataChainname, dataname, name: ARRAY OF CHAR;
												  datareko, results: antsArrays.X1d );

	VAR dummy: POINTER TO ARRAY OF Reko;
		newdatareko: Reko;  len, i, j, k: LONGINT;

	BEGIN
		FOR k := 0 TO LEN( set.chain ) - 1 DO
			IF set.chain[k].name^ = dataChainname THEN
				FOR j := 0 TO LEN( set.chain[k].dataChain ) - 1 DO
					IF set.chain[k].dataChain[j].name^ = dataname THEN
						IF set.chain[k].dataChain[j].datarekoChain = NIL THEN
							len := 0;  NEW( set.chain[k].dataChain[j].datarekoChain, 1 );
						ELSE
							len := LEN( set.chain[k].dataChain[j].datarekoChain );  NEW( dummy, len );

							FOR i := 0 TO len - 1 DO dummy[i] := set.chain[k].dataChain[j].datarekoChain[i];  END;

							NEW( set.chain[k].dataChain[j].datarekoChain, len + 1 );

							FOR i := 0 TO len - 1 DO set.chain[k].dataChain[j].datarekoChain[i] := dummy[i];  END;
						END;

						Gen5;  newdatareko := Objects.NewObj( Reko );
						set.chain[k].dataChain[j].datarekoChain[len] := newdatareko;
						NEW( set.chain[k].dataChain[j].datarekoChain[len].name, LEN( name ) );

						FOR i := 0 TO LEN( name ) - 1 DO set.chain[k].dataChain[j].datarekoChain[len].name[i] := name[i];  END;

						NEW( set.chain[k].dataChain[j].datarekoChain[len].reko, LEN( datareko ) );
						NEW( set.chain[k].dataChain[j].datarekoChain[len].results, LEN( results ) );
						vyLongreal.Copy( LEN( datareko ), datareko^, 0, set.chain[k].dataChain[j].datarekoChain[len].reko^, 0 );
						vyLongreal.Copy( LEN( results ), results^, 0, set.chain[k].dataChain[j].datarekoChain[len].results^, 0 );
					END;
				END;
			END;
		END;
	END NewDataReko;

	PROCEDURE NewMonotone*( VAR set: SetChain;  dataChainname, dataname, name: ARRAY OF CHAR;
												    monotone: antsArrays.X1d );

	VAR dummy: POINTER TO ARRAY OF Monotone;
		newmonotone: Monotone;  len, i, j, k: LONGINT;

	BEGIN
		FOR k := 0 TO LEN( set.chain ) - 1 DO
			IF set.chain[k].name^ = dataChainname THEN
				FOR j := 0 TO LEN( set.chain[k].dataChain ) - 1 DO
					IF set.chain[k].dataChain[j].name^ = dataname THEN
						IF set.chain[k].dataChain[j].monotoneChain = NIL THEN
							len := 0;  NEW( set.chain[k].dataChain[j].monotoneChain, 1 );
						ELSE
							len := LEN( set.chain[k].dataChain[j].monotoneChain );  NEW( dummy, len );

							FOR i := 0 TO len - 1 DO dummy[i] := set.chain[k].dataChain[j].monotoneChain[i];  END;

							NEW( set.chain[k].dataChain[j].monotoneChain, len + 1 );

							FOR i := 0 TO len - 1 DO set.chain[k].dataChain[j].monotoneChain[i] := dummy[i];  END;
						END;

						Gen3;  newmonotone := Objects.NewObj( Monotone );
						set.chain[k].dataChain[j].monotoneChain[len] := newmonotone;
						NEW( set.chain[k].dataChain[j].monotoneChain[len].name, LEN( name ) );
						NEW( set.chain[k].dataChain[j].monotoneChain[len].monotone, LEN( monotone ) );
						NEW( set.chain[k].dataChain[j].monotoneChain[len].noisenumbers, 4 );

						FOR i := 0 TO LEN( name ) - 1 DO set.chain[k].dataChain[j].monotoneChain[len].name[i] := name[i];  END;

						vyLongreal.Copy( LEN( monotone ), monotone^, 0, set.chain[k].dataChain[j].monotoneChain[len].monotone^, 0 );
					END;
				END;
			END;
		END;
	END NewMonotone;

	PROCEDURE NewDegraded*( VAR set: SetChain;  dataChainname, dataname, monotonename, name: ARRAY OF CHAR;
												  degraded: antsArrays.X1d;  parameter: LONGREAL );

	VAR dummy: POINTER TO ARRAY OF Degraded;
		newdegraded: Degraded;  len, i, j, k, l: LONGINT;

	BEGIN
		FOR l := 0 TO LEN( set.chain ) - 1 DO
			IF set.chain[l].name^ = dataChainname THEN
				FOR j := 0 TO LEN( set.chain[l].dataChain ) - 1 DO
					IF set.chain[l].dataChain[j].name^ = dataname THEN
						FOR k := 0 TO LEN( set.chain[l].dataChain[j].monotoneChain ) - 1 DO
							IF set.chain[l].dataChain[j].monotoneChain[k].name^ = monotonename THEN
								IF set.chain[l].dataChain[j].monotoneChain[k].degradedChain = NIL THEN
									len := 0;  NEW( set.chain[l].dataChain[j].monotoneChain[k].degradedChain, 1 );
								ELSE
									len := LEN( set.chain[l].dataChain[j].monotoneChain[k].degradedChain );  NEW( dummy, len );

									FOR i := 0 TO len - 1 DO dummy[i] := set.chain[l].dataChain[j].monotoneChain[k].degradedChain[i];  END;

									NEW( set.chain[l].dataChain[j].monotoneChain[k].degradedChain, len + 1 );

									FOR i := 0 TO len - 1 DO set.chain[l].dataChain[j].monotoneChain[k].degradedChain[i] := dummy[i];  END;
								END;

								Gen4;  newdegraded := Objects.NewObj( Degraded );
								set.chain[l].dataChain[j].monotoneChain[k].degradedChain[len] := newdegraded;
								NEW( set.chain[l].dataChain[j].monotoneChain[k].degradedChain[len].name, LEN( name ) );

								FOR i := 0 TO LEN( name ) - 1 DO
									set.chain[l].dataChain[j].monotoneChain[k].degradedChain[len].name[i] := name[i];
								END;

								NEW( set.chain[l].dataChain[j].monotoneChain[k].degradedChain[len].degraded, LEN( degraded ) );
								vyLongreal.Copy( LEN( degraded ), degraded^, 0,
															 set.chain[l].dataChain[j].monotoneChain[k].degradedChain[len].degraded^, 0 );
								set.chain[l].dataChain[j].monotoneChain[k].degradedChain[len].variance := parameter;
							END;
						END;
					END;
				END;
			END;
		END;
	END NewDegraded;

	PROCEDURE NewReko*( VAR set: SetChain;  dataChainname, dataname, monotonename, degradedname: ARRAY OF CHAR;
										  name: ARRAY OF CHAR;  reko: antsArrays.X1d;  results: antsArrays.X1d );

	VAR dummy: POINTER TO ARRAY OF Reko;
		newreko: Reko;  len, i, j, k, l, m: LONGINT;

	BEGIN
		FOR m := 0 TO LEN( set.chain ) - 1 DO
			IF set.chain[m].name^ = dataChainname THEN
				FOR j := 0 TO LEN( set.chain[m].dataChain ) - 1 DO
					IF set.chain[m].dataChain[j].name^ = dataname THEN
						FOR k := 0 TO LEN( set.chain[m].dataChain[j].monotoneChain ) - 1 DO
							IF set.chain[m].dataChain[j].monotoneChain[k].name^ = monotonename THEN
								FOR l := 0 TO LEN( set.chain[m].dataChain[j].monotoneChain[k].degradedChain ) - 1 DO
									IF set.chain[m].dataChain[j].monotoneChain[k].degradedChain[l].name^ = degradedname THEN
										IF set.chain[m].dataChain[j].monotoneChain[k].degradedChain[l].rekoChain = NIL THEN
											len := 0;  NEW( set.chain[m].dataChain[j].monotoneChain[k].degradedChain[l].rekoChain, 1 );
										ELSE
											len := LEN( set.chain[m].dataChain[j].monotoneChain[k].degradedChain[l].rekoChain );
											NEW( dummy, len );

											FOR i := 0 TO len - 1 DO
												dummy[i] := set.chain[m].dataChain[j].monotoneChain[k].degradedChain[l].rekoChain[i];
											END;

											NEW( set.chain[m].dataChain[j].monotoneChain[k].degradedChain[l].rekoChain, len + 1 );

											FOR i := 0 TO len - 1 DO
												set.chain[m].dataChain[j].monotoneChain[k].degradedChain[l].rekoChain[i] := dummy[i];
											END;
										END;

										Gen5;  newreko := Objects.NewObj( Reko );
										set.chain[m].dataChain[j].monotoneChain[k].degradedChain[l].rekoChain[len] := newreko;
										NEW( set.chain[m].dataChain[j].monotoneChain[k].degradedChain[l].rekoChain[len].name, LEN( name ) );

										FOR i := 0 TO LEN( name ) - 1 DO
											set.chain[m].dataChain[j].monotoneChain[k].degradedChain[l].rekoChain[len].name[i] :=
												name[i];
										END;

										NEW( set.chain[m].dataChain[j].monotoneChain[k].degradedChain[l].rekoChain[len].reko, LEN( reko ) );
										vyLongreal.Copy( LEN( reko ), reko^, 0,
																	 set.chain[m].dataChain[j].monotoneChain[k].degradedChain[l].rekoChain[len].reko^,
																	 0 );

										NEW( set.chain[m].dataChain[j].monotoneChain[k].degradedChain[l].rekoChain[len].results, LEN( results ) );
										vyLongreal.Copy( LEN( results ), results^, 0,
																	 set.chain[m].dataChain[j].monotoneChain[k].degradedChain[l].rekoChain[len].results^,
																	 0 );
									END;
								END;
							END;
						END;
					END;
				END;
			END;
		END;
	END NewReko;

(* Im folgenden kommen noch die Delete...-Methoden. Diese sind dazu da, um Objekte aus der Datenbank löschen zu könenn. *)

	PROCEDURE DeleteDataset*( VAR set: SetChain;  dataChainname: ARRAY OF CHAR ): BOOLEAN;

	VAR dummy: SetChain;  i, j, k, this: LONGINT;

	BEGIN
		IF ~ExistDataset( set, dataChainname ) THEN RETURN FALSE;  ELSE
			IF LEN( set.chain ) = 1 THEN set.chain := NIL;  ELSE
				FOR i := 0 TO LEN( set.chain ) - 1 DO
					IF set.chain[i].name^ = dataChainname THEN this := i;  END;
				END;

				IF this # LEN( set.chain ) - 1 THEN
					FOR j := this TO LEN( set.chain ) - 2 DO set.chain[j] := set.chain[j + 1];  END;
				END;

				NewSetChain( dummy );  NEW( dummy.chain, LEN( set.chain ) - 1 );

				FOR k := 0 TO LEN( set.chain ) - 2 DO dummy.chain[k] := set.chain[k];  END;

				set := dummy;
			END;

			RETURN TRUE;
		END;
	END DeleteDataset;

	PROCEDURE DeleteData*( VAR set: SetChain;  dataChainname, dataname: ARRAY OF CHAR ): BOOLEAN;

	VAR dummy: POINTER TO ARRAY OF Data;
		i, j, k, this: LONGINT;  ok: BOOLEAN;

	BEGIN
		IF ~ExistData( set, dataChainname, dataname ) THEN RETURN FALSE;  ELSE
			FOR i := 0 TO LEN( set.chain ) - 1 DO
				IF set.chain[i].name^ = dataChainname THEN
					FOR j := 0 TO LEN( set.chain[i].dataChain ) - 1 DO
						IF set.chain[i].dataChain[j].name^ = dataname THEN
							IF LEN( set.chain[i].dataChain ) = 1 THEN ok := DeleteDataset( set, dataChainname );  RETURN ok;  ELSE this := j;  END;
						END;
					END;

					IF this # (LEN( set.chain[i].dataChain ) - 1) THEN
						FOR k := this TO LEN( set.chain[i].dataChain ) - 2 DO set.chain[i].dataChain[k] := set.chain[i].dataChain[k + 1];  END;
					END;

					NEW( dummy, LEN( set.chain[i].dataChain ) - 1 );

					FOR k := 0 TO LEN( set.chain[i].dataChain ) - 2 DO dummy[k] := set.chain[i].dataChain[k];  END;

					NEW( set.chain[i].dataChain, LEN( set.chain[i].dataChain ) - 1 );

					FOR k := 0 TO LEN( dummy ) - 1 DO set.chain[i].dataChain[k] := dummy[k];  END;
				END;
			END;

			RETURN TRUE;
		END;
	END DeleteData;

	PROCEDURE DeleteDataReko*( VAR set: SetChain;  dataChainname, dataname, datarekoname: ARRAY OF CHAR ): BOOLEAN;

	VAR dummy: POINTER TO ARRAY OF Reko;
		i, j, k, l, this: LONGINT;

	BEGIN
		IF ~ExistDataReko( set, dataChainname, dataname, datarekoname ) THEN RETURN FALSE;  ELSE
			FOR i := 0 TO LEN( set.chain ) - 1 DO
				IF set.chain[i].name^ = dataChainname THEN
					FOR j := 0 TO LEN( set.chain[i].dataChain ) - 1 DO
						IF set.chain[i].dataChain[j].name^ = dataname THEN
							FOR k := 0 TO LEN( set.chain[i].dataChain[j].datarekoChain ) - 1 DO
								IF set.chain[i].dataChain[j].datarekoChain[k].name^ = datarekoname THEN
									IF LEN( set.chain[i].dataChain[j].datarekoChain ) = 1 THEN
										set.chain[i].dataChain[j].datarekoChain := NIL;  RETURN TRUE;
									ELSE this := k;
									END;
								END;
							END;

							IF this # (LEN( set.chain[i].dataChain[j].datarekoChain ) - 1) THEN
								FOR l := this TO LEN( set.chain[i].dataChain[j].datarekoChain ) - 2 DO
									set.chain[i].dataChain[j].datarekoChain[l] := set.chain[i].dataChain[j].datarekoChain[l + 1];
								END;
							END;

							NEW( dummy, LEN( set.chain[i].dataChain[j].datarekoChain ) - 1 );

							FOR l := 0 TO LEN( set.chain[i].dataChain[j].datarekoChain ) - 2 DO
								dummy[l] := set.chain[i].dataChain[j].datarekoChain[l];
							END;

							NEW( set.chain[i].dataChain[j].datarekoChain, LEN( set.chain[i].dataChain[j].datarekoChain ) - 1 );

							FOR l := 0 TO LEN( dummy ) - 1 DO set.chain[i].dataChain[j].datarekoChain[l] := dummy[l];  END;
						END;
					END;
				END;
			END;

			RETURN TRUE;
		END;
	END DeleteDataReko;

	PROCEDURE DeleteMonotone*( VAR set: SetChain;  dataChainname, dataname, monotonename: ARRAY OF CHAR ): BOOLEAN;

	VAR dummy: POINTER TO ARRAY OF Monotone;
		i, j, k, l, this: LONGINT;

	BEGIN
		IF ~ExistMonotone( set, dataChainname, dataname, monotonename ) THEN RETURN FALSE;  ELSE
			FOR i := 0 TO LEN( set.chain ) - 1 DO
				IF set.chain[i].name^ = dataChainname THEN
					FOR j := 0 TO LEN( set.chain[i].dataChain ) - 1 DO
						IF set.chain[i].dataChain[j].name^ = dataname THEN
							FOR k := 0 TO LEN( set.chain[i].dataChain[j].monotoneChain ) - 1 DO
								IF set.chain[i].dataChain[j].monotoneChain[k].name^ = monotonename THEN
									IF LEN( set.chain[i].dataChain[j].monotoneChain ) = 1 THEN
										set.chain[i].dataChain[j].monotoneChain := NIL;  RETURN TRUE;
									ELSE this := k;
									END;
								END;
							END;

							IF this # (LEN( set.chain[i].dataChain[j].monotoneChain ) - 1) THEN
								FOR l := this TO LEN( set.chain[i].dataChain[j].monotoneChain ) - 2 DO
									set.chain[i].dataChain[j].monotoneChain[l] := set.chain[i].dataChain[j].monotoneChain[l + 1];
								END;
							END;

							NEW( dummy, LEN( set.chain[i].dataChain[j].monotoneChain ) - 1 );

							FOR l := 0 TO LEN( set.chain[i].dataChain[j].monotoneChain ) - 2 DO
								dummy[l] := set.chain[i].dataChain[j].monotoneChain[l];
							END;

							NEW( set.chain[i].dataChain[j].monotoneChain, LEN( set.chain[i].dataChain[j].monotoneChain ) - 1 );

							FOR l := 0 TO LEN( dummy ) - 1 DO set.chain[i].dataChain[j].monotoneChain[l] := dummy[l];  END;
						END;
					END;
				END;
			END;

			RETURN TRUE;
		END;
	END DeleteMonotone;

	PROCEDURE DeleteDegraded*( VAR set: SetChain;
													  dataChainname, dataname, monotonename, degradedname: ARRAY OF CHAR ): BOOLEAN;

	VAR dummy: POINTER TO ARRAY OF Degraded;
		i, j, k, l, m, this: LONGINT;

	BEGIN
		IF ~ExistDegraded( set, dataChainname, dataname, monotonename, degradedname ) THEN RETURN FALSE;  ELSE
			FOR i := 0 TO LEN( set.chain ) - 1 DO
				IF set.chain[i].name^ = dataChainname THEN
					FOR j := 0 TO LEN( set.chain[i].dataChain ) - 1 DO
						IF set.chain[i].dataChain[j].name^ = dataname THEN
							FOR k := 0 TO LEN( set.chain[i].dataChain[j].monotoneChain ) - 1 DO
								IF set.chain[i].dataChain[j].monotoneChain[k].name^ = monotonename THEN
									FOR l := 0 TO LEN( set.chain[i].dataChain[j].monotoneChain[k].degradedChain ) - 1 DO
										IF set.chain[i].dataChain[j].monotoneChain[k].degradedChain[l].name^ = degradedname THEN
											IF LEN( set.chain[i].dataChain[j].monotoneChain[k].degradedChain ) = 1 THEN
												set.chain[i].dataChain[j].monotoneChain[k].degradedChain := NIL;  RETURN TRUE;
											ELSE this := l;
											END;
										END;
									END;

									IF this # (LEN( set.chain[i].dataChain[j].monotoneChain[k].degradedChain ) - 1) THEN
										FOR m := this TO LEN( set.chain[i].dataChain[j].monotoneChain[k].degradedChain ) - 2 DO
											set.chain[i].dataChain[j].monotoneChain[k].degradedChain[m] :=
												set.chain[i].dataChain[j].monotoneChain[k].degradedChain[m + 1];
										END;
									END;

									NEW( dummy, LEN( set.chain[i].dataChain[j].monotoneChain[k].degradedChain ) - 1 );

									FOR m := 0 TO LEN( set.chain[i].dataChain[j].monotoneChain[k].degradedChain ) - 2 DO
										dummy[m] := set.chain[i].dataChain[j].monotoneChain[k].degradedChain[m];
									END;

									NEW( set.chain[i].dataChain[j].monotoneChain[k].degradedChain,
									   LEN( set.chain[i].dataChain[j].monotoneChain[k].degradedChain ) - 1 );

									FOR m := 0 TO LEN( dummy ) - 1 DO
										set.chain[i].dataChain[j].monotoneChain[k].degradedChain[m] := dummy[m];
									END;
								END;
							END;
						END;
					END;
				END;
			END;

			RETURN TRUE;
		END;
	END DeleteDegraded;

	PROCEDURE DeleteReko*( VAR set: SetChain;
											  dataChainname, dataname, monotonename, degradedname, rekoname: ARRAY OF CHAR ): BOOLEAN;

	VAR dummy: POINTER TO ARRAY OF Reko;
		i, j, k, l, m, n, this: LONGINT;

	BEGIN
		IF ~ExistReko( set, dataChainname, dataname, monotonename, degradedname, rekoname ) THEN RETURN FALSE;  ELSE
			FOR i := 0 TO LEN( set.chain ) - 1 DO
				IF set.chain[i].name^ = dataChainname THEN
					FOR j := 0 TO LEN( set.chain[i].dataChain ) - 1 DO
						IF set.chain[i].dataChain[j].name^ = dataname THEN
							FOR k := 0 TO LEN( set.chain[i].dataChain[j].monotoneChain ) - 1 DO
								IF set.chain[i].dataChain[j].monotoneChain[k].name^ = monotonename THEN
									FOR l := 0 TO LEN( set.chain[i].dataChain[j].monotoneChain[k].degradedChain ) - 1 DO
										IF set.chain[i].dataChain[j].monotoneChain[k].degradedChain[l].name^ = degradedname THEN
											FOR m := 0 TO LEN( set.chain[i].dataChain[j].monotoneChain[k].degradedChain[l].rekoChain ) - 1 DO
												IF set.chain[i].dataChain[j].monotoneChain[k].degradedChain[l].rekoChain[m].name^ =
												    rekoname THEN
													IF LEN( set.chain[i].dataChain[j].monotoneChain[k].degradedChain[l].rekoChain ) = 1 THEN
														set.chain[i].dataChain[j].monotoneChain[k].degradedChain[l].rekoChain := NIL;
														RETURN TRUE;
													ELSE this := m;
													END;
												END;
											END;

											IF this # (LEN( set.chain[i].dataChain[j].monotoneChain[k].degradedChain[l].rekoChain ) - 1) THEN
												FOR n := this TO LEN( set.chain[i].dataChain[j].monotoneChain[k].degradedChain[l].rekoChain ) - 2 DO
													set.chain[i].dataChain[j].monotoneChain[k].degradedChain[l].rekoChain[n] :=
														set.chain[i].dataChain[j].monotoneChain[k].degradedChain[l].rekoChain[n + 1];
												END;
											END;

											NEW( dummy, LEN( set.chain[i].dataChain[j].monotoneChain[k].degradedChain[l].rekoChain ) - 1 );

											FOR n := 0 TO LEN( set.chain[i].dataChain[j].monotoneChain[k].degradedChain[l].rekoChain ) - 2 DO
												dummy[n] := set.chain[i].dataChain[j].monotoneChain[k].degradedChain[l].rekoChain[n];
											END;

											NEW( set.chain[i].dataChain[j].monotoneChain[k].degradedChain[l].rekoChain,
											   LEN( set.chain[i].dataChain[j].monotoneChain[k].degradedChain[l].rekoChain ) - 1 );

											FOR n := 0 TO LEN( dummy ) - 1 DO
												set.chain[i].dataChain[j].monotoneChain[k].degradedChain[l].rekoChain[n] := dummy[n];
											END;
										END;
									END;
								END;
							END;
						END;
					END;
				END;
			END;

			RETURN TRUE;
		END;
	END DeleteReko;

END antsPottsSimDataStructure.
