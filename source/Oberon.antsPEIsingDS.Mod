MODULE antsPEIsingDS IN Oberon;   (** fof  **)
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




IMPORT antsArrayObjects, Math := MathL IN A2, antsPEV, antsKernel, antsModels, antsCommands, vyCG := vyName, antsCaches,
	Files, Objects, vyHostStrings, vyRanBase, aM := antsMessages;

TYPE
	tModel* = POINTER TO tModelDesc;
	tModelDesc* = RECORD (antsModels.tModelDesc);
	(* a0  a[0] ,a1 a[1] ,a2 a[2] ,a3 a[3] ,a4 a[4] ,a5 a[5] ,b2 a[6] ,b4 a[7] ,b5 a[8] ,g0 a[9] ,g1 a[10] ,g2 a[11] ,d a[12] ,
		e  a[13] ,pen a[14] : FLOAT64; *)
		a: ARRAY 14 OF FLOAT64;

		(* Parameters:
		a[0] : No Edges  .
		a[1] : One Edge _
		a[2]: Two Edges with same direction --
		a[3]: Turn L
		a[4]: T
		a[5]: Crossing x
		a[6]: Parallel Edges ||
		a[7]: U Turn U
		a[8]: Box O
		a[9]: Pixelweight with edge
		a[10]:  Pixelweight without edge
		a[11]: General tendency of Pixels ("greyval tendency")
		a[12]: General tendency of Edges
		a[13]: Penalizing term
		*)

		cp, ce: antsCaches.FullCache
	END;
VAR
	GM: tModel;  depth: SIGNED16;

	PROCEDURE Open*( M: tModel );
	BEGIN
		M.cp := NIL;  M.ce := NIL;  M.synced := FALSE
	END Open;

	PROCEDURE dist( e1, e2: SIGNED16 ): FLOAT64;
	BEGIN
		RETURN -((e1 - e2) * (e1 - e2) / depth)
	END dist;

	PROCEDURE f1( e1, e2, e3, e4: SIGNED16 ): FLOAT64;
	(*
	| e4
	- e1   -e2
	| e3
	*)
	VAR sum: SIGNED16;
	BEGIN
		sum := e1 + e2 + e3 + e4;
		IF sum = 0 THEN RETURN GM.a[0]
		ELSIF sum = 1 THEN RETURN GM.a[1]
		ELSIF sum = 2 THEN
			IF e1 = e2 THEN RETURN GM.a[2] ELSE RETURN GM.a[3] END
		ELSIF sum = 3 THEN RETURN GM.a[4]
		ELSE RETURN GM.a[5]
		END
	END f1;

	PROCEDURE f2( e1, e2, e3, e4: SIGNED16 ): FLOAT64;
	(*
	- e4
	| e1          |e2
	- e3
	*)
	VAR sum: SIGNED16;
	BEGIN

		sum := e1 + e2 + e3 + e4;
		IF sum = 0 THEN RETURN GM.a[0]
		ELSIF sum = 1 THEN RETURN GM.a[1]
		ELSIF sum = 2 THEN
			IF e1 = e2 THEN RETURN GM.a[6] ELSE RETURN GM.a[3] END
		ELSIF sum = 3 THEN RETURN GM.a[7]
		ELSE RETURN GM.a[8]
		END
	END f2;

	PROCEDURE f3( e, p1, p2: SIGNED16 ): FLOAT64;
	(* p1 * |e * p2 *)
	BEGIN
		IF e = 1 THEN RETURN dist( p1, p2 ) * GM.a[9] ELSE RETURN dist( p1, p2 ) * GM.a[10] END
	END f3;

	PROCEDURE f4( p: SIGNED16 ): FLOAT64;
	BEGIN
		RETURN GM.a[11] * p
	END f4;

	PROCEDURE f5( e: SIGNED16 ): FLOAT64;
	BEGIN
		RETURN GM.a[12] * e
	END f5;

	PROCEDURE f6( p1, p2: SIGNED16 ): FLOAT64;
	BEGIN
		RETURN GM.a[13] * dist( p1, p2 )
	END f6;

	PROCEDURE UP( VAR a: ARRAY OF SIGNED16 ): FLOAT64;
	BEGIN
		RETURN f3( a[5], a[0], a[1] ) + f3( a[6], a[0], a[2] ) + f3( a[7], a[0], a[3] ) + f3( a[8], a[0], a[4] ) + f4( a[0] ) +
				    f6( a[0], a[9] )
	END UP;

	PROCEDURE EP( cooling: FLOAT64;  VAR a: ARRAY OF SIGNED16 ): FLOAT64;
	BEGIN
		RETURN Math.exp( cooling * UP( a ) );
	END EP;

	PROCEDURE DistriFromLocalChar( F: antsPEV.tField;  y, x: SIGNED32 );
	VAR po, p, p1, p2, p3, p4, e1, e2, e3, e4: SIGNED16;  nges, prob, rand: FLOAT64;
	BEGIN
		(* insert penalization to AOrig here *)
		po := F.Aorig.A[y, x];  antsPEV.EGetPNeighbours( F, y, x, p, p1, p2, p3, p4, e1, e2, e3, e4 );  nges := 0;
		FOR p := 0 TO SHORT( F.A.depth - 1 ) DO
			nges := nges + Math.exp( f3( e1, p, p1 ) + f3( e2, p, p2 ) + f3( e3, p, p3 ) + f3( e4, p, p4 ) + f4( p ) + f6( p, po ) );
		END;
		rand := vyRanBase.RandomU();  prob := 0;  p := 0;
		REPEAT
			prob :=
				prob + Math.exp( f3( e1, p, p1 ) + f3( e2, p, p2 ) + f3( e3, p, p3 ) + f3( e4, p, p4 ) + f4( p ) + f6( p, po ) ) / nges;
			INC( p );
		UNTIL prob >= rand;
		F.A.A[y, x] := p - 1;
	END DistriFromLocalChar;

	PROCEDURE FastestC( F: antsPEV.tField );
	VAR y, x, w, h, offset: SIGNED32;  p: SIGNED16;
		a: ARRAY 11 OF SIGNED16;
		rand: FLOAT64;  c: antsCaches.FullCache;  A, H, V, O: antsArrayObjects.tINTEGERArray;
	BEGIN
		c := GM.cp;  A := F.A.A;  V := F.Ev.A;  H := F.Eh.A;  O := F.Aorig.A;  w := F.w;  h := F.h;
		FOR y := 0 TO h - 1 DO
			FOR x := 0 TO w - 1 DO
			(* a[0] := 0; *)
				a[1] := A[y, (x - 1) MOD w];  a[2] := A[y, (x + 1) MOD w];  a[3] := A[(y - 1) MOD h, x];  a[4] := A[(y + 1) MOD h, x];
				a[5] := V[y, x];  a[6] := V[y, (x + 1) MOD w];  a[7] := H[y, x];  a[8] := H[(y + 1) MOD h, x];  a[9] := O[y, x];  p := 0;
				offset := c.Offset( a, 1 );  rand := vyRanBase.RandomU();
				WHILE c.values[offset + p] < rand DO INC( p );  END;
				A[y, x] := p;
			END;
		END;
	END FastestC;

	PROCEDURE UE( VAR a: ARRAY OF SIGNED16 ): FLOAT64;
	BEGIN
		RETURN f1( a[1], a[0], a[3], a[4] ) + f1( a[0], a[2], a[5], a[6] ) + f2( a[0], a[7], a[3], a[5] ) + f2( a[0], a[8], a[4], a[6] ) +
				    f3( a[0], a[9], a[10] ) + f5( a[0] );
	END UE;

	PROCEDURE EE( cooling: FLOAT64;  VAR a: ARRAY OF SIGNED16 ): FLOAT64;
	BEGIN
		RETURN Math.exp( cooling * UE( a ) );
	END EE;

	PROCEDURE DistriFromLocalCharE( F: antsPEV.tField;  y, x: SIGNED32 );
	VAR e, p1, p2, e1, e2, e3, e4, e5, e6, e7, e8: SIGNED16;  nges, ges, prob: FLOAT64;
	BEGIN
		antsPEV.EGetENeighboursH( F, y, x, e, p1, p2 );
		antsPEV.E2GetENeighboursH( F, y, x, e, e1, e2, e3, e4, e5, e6, e7, e8 );
		nges := f1( e1, 0, e3, e4 ) + f1( 0, e2, e5, e6 ) + f2( 0, e7, e3, e5 ) + f2( 0, e8, e4, e6 ) + f3( 0, p1, p2 ) + f5( 0 );
		ges := f1( e1, 1, e3, e4 ) + f1( 1, e2, e5, e6 ) + f2( 1, e7, e3, e5 ) + f2( 1, e8, e4, e6 ) + f3( 1, p1, p2 ) + f5( 1 );
		prob := Math.exp( ges );  prob := prob / (prob + Math.exp( nges ));
		IF vyRanBase.RandomU() < prob THEN F.Eh.A[y, x] := 1 ELSE F.Eh.A[y, x] := 0 END;

		antsPEV.EGetENeighboursV( F, y, x, e, p1, p2 );  antsPEV.E2GetENeighboursV( F, y, x, e, e1, e2, e3, e4, e5, e6, e7, e8 );
		nges := f1( e1, 0, e3, e4 ) + f1( 0, e2, e5, e6 ) + f2( 0, e7, e3, e5 ) + f2( 0, e8, e4, e6 ) + f3( 0, p1, p2 ) + f5( 0 );
		ges := f1( e1, 1, e3, e4 ) + f1( 1, e2, e5, e6 ) + f2( 1, e7, e3, e5 ) + f2( 1, e8, e4, e6 ) + f3( 1, p1, p2 ) + f5( 1 );
		prob := Math.exp( ges );  prob := prob / (prob + Math.exp( nges ));
		IF vyRanBase.RandomU() < prob THEN F.Ev.A[y, x] := 1 ELSE F.Ev.A[y, x] := 0 END;

	END DistriFromLocalCharE;

	PROCEDURE FastestEC( F: antsPEV.tField );
	VAR y, x, w, h, offset: SIGNED32;
		a: ARRAY 11 OF SIGNED16;
		c: antsCaches.FullCache;  A, H, V: antsArrayObjects.tINTEGERArray;
	BEGIN
		c := GM.ce;  A := F.A.A;  H := F.Eh.A;  V := F.Ev.A;  w := F.w;  h := F.h;
		FOR y := 0 TO h - 1 DO
			FOR x := 0 TO w - 1 DO
				a[1] := H[y, (x - 1) MOD w];  a[2] := H[y, (x + 1) MOD w];  a[3] := V[(y - 1) MOD h, x];  a[4] := V[y, x];
				a[5] := V[(y - 1) MOD h, (x + 1) MOD w];  a[6] := V[y, (x + 1) MOD w];  a[7] := H[(y - 1) MOD h, x];
				a[8] := H[(y + 1) MOD h, x];  a[9] := A[y, x];  a[10] := A[(y - 1) MOD F.h, x];  offset := c.Offset( a, 1 );
				IF vyRanBase.RandomU() < c.values[offset] THEN H[y, x] := 0 ELSE H[y, x] := 1 END;
				a[1] := V[(y - 1) MOD h, x];  a[2] := V[(y + 1) MOD h, x];  a[3] := H[y, (x - 1) MOD w];  a[4] := H[y, x];
				a[5] := H[(y + 1) MOD h, (x - 1) MOD w];  a[6] := H[(y + 1) MOD h, x];  a[7] := V[y, (x - 1) MOD w];
				a[8] := V[y, (x + 1) MOD w];  a[9] := A[y, x];  a[10] := A[y, (x - 1) MOD F.w];  offset := c.Offset( a, 1 );
				IF vyRanBase.RandomU() < c.values[offset] THEN V[y, x] := 0 ELSE V[y, x] := 1 END;
			END
		END;
	END FastestEC;

	PROCEDURE CreateCaches( m: tModel;  d: SIGNED16 );
	VAR A: ARRAY 11 OF SIGNED16;
		i: SIGNED16;  offset: SIGNED32;  c: antsCaches.FullCache;  s: FLOAT64;
	BEGIN
		FOR i := 0 TO 4 DO A[i] := d;  END;
		FOR i := 5 TO 8 DO A[i] := 2 END;
		A[9] := d;

		IF m.coolingTemp > 1.01 THEN c := antsCaches.Cuboid( 10, A, 10000 );
		ELSE c := antsCaches.Cuboid( 10, A, 1000000 );
		END;
		m.cp := c;
		IF c # NIL THEN
			aM.vS( "Computing Pixel-edge cache" );  offset := -1;
			WHILE (c.NextPoint( offset, A, 1 )) DO
				s := 0;  i := 0;
				WHILE (i < d) DO A[0] := i;  s := s + EP( m.coolingTemp, A );  c.values[i + offset] := s;  INC( i );  END;
				A[0] := 0;
				(* divide by normalizing constant *)
				i := 0;
				WHILE (i < d) DO c.values[offset + i] := c.values[offset + i] / s;  INC( i );  END;

			END;
			aM.vS( "done." );

		END;

		FOR i := 0 TO 8 DO A[i] := 2 END;
		FOR i := 9 TO 10 DO A[i] := d END;

		IF m.coolingTemp > 1.01 THEN c := antsCaches.Cuboid( 11, A, 10000 );
		ELSE c := antsCaches.Cuboid( 11, A, 1000000 );
		END;
		m.ce := c;
		IF c # NIL THEN
			aM.vS( "Computing Edge-Pixel-Cache" );  offset := -1;
			WHILE (c.NextPoint( offset, A, 1 )) DO
				s := 0;  i := 0;
				WHILE (i < 2) DO A[0] := i;  s := s + EE( m.coolingTemp, A );  c.values[i + offset] := s;  INC( i );  END;
				A[0] := 0;
				(* divide by normalizing constant *)
				i := 0;
				WHILE (i < 2) DO c.values[offset + i] := c.values[offset + i] / s;  INC( i );  END;

			END;
			aM.vS( "done." );
		END;
	END CreateCaches;

	PROCEDURE OneSweep*( s: antsKernel.Kernel );
	VAR F: antsPEV.tField;
	BEGIN
		GM := s.par( tModel );  F := s.A( antsPEV.tField );  depth := SHORT( F.A.depth );
		IF ~GM.synced THEN CreateCaches( GM, depth );  GM.synced := TRUE;  END;
		(* antsPEV.ForAllDo(F,F.V,DistriFromLocalCharV); *)
		IF F.A.depth <= 2 THEN
			(* vyHostTexts.Note(vyHostTexts.cWarning,"You use a binary picture, try using Ising model first !");  *)
		ELSE
		END;
		IF GM.ce # NIL THEN FastestEC( F );  ELSE antsPEV.ForAllDo( F, DistriFromLocalCharE );  END;
		IF GM.cp # NIL THEN FastestC( F );  ELSE antsPEV.ForAllDo( F, DistriFromLocalChar );  END;
		(* antsPEV.FieldHasChanged(F); *)
	END OneSweep;

	PROCEDURE Uniform*( s: antsKernel.Kernel );
	BEGIN
		antsPEV.DoUniform( s.A( antsPEV.tField ) );
	END Uniform;

	PROCEDURE WriteArray( VAR R: Files.Rider;  VAR A: ARRAY OF FLOAT64 );
	VAR i: SIGNED32;
	BEGIN
		Files.WriteLInt( R, LEN( A ) );  aM.dSISI( "Writing len at pos", LEN( A ), "  ", Files.Pos( R ) );
		FOR i := 0 TO LEN( A ) - 1 DO Files.WriteLReal( R, A[i] );  END;
	END WriteArray;

	PROCEDURE ReadArray( VAR R: Files.Rider;  VAR A: ARRAY OF FLOAT64 );
	VAR i, len: SIGNED32;
	BEGIN
		Files.ReadLInt( R, len );  aM.dSISI( "Reading len at pos", len, "   ", Files.Pos( R ) );
		FOR i := 0 TO len - 1 DO Files.ReadLReal( R, A[i] );  END;
	END ReadArray;

	PROCEDURE StoreM( VAR R: Files.Rider;  s: tModel );
	BEGIN
		Files.WriteInt( R, 0 );  WriteArray( R, s.a );
	END StoreM;

	PROCEDURE LoadM( VAR R: Files.Rider;  s: tModel );
	VAR version: SIGNED16;
	BEGIN
		Files.ReadInt( R, version );  ReadArray( R, s.a );
	END LoadM;

	PROCEDURE ArrayHandleAttribute( VAR M: Objects.AttrMsg;  prefix: ARRAY OF CHAR;  VAR array: ARRAY OF FLOAT64 ): BOOLEAN;
	VAR cur: ARRAY 64 OF CHAR;
		i: SIGNED32;  len: SIGNED32;
	BEGIN
		len := LEN( array );
		IF M.id = Objects.enum THEN
			FOR i := 0 TO len - 1 DO
				COPY( prefix, cur );  vyHostStrings.Append( cur, "[" );  vyHostStrings.AppendInt( i, 1, cur );  vyHostStrings.Append( cur, "]" );
				M.Enum( cur );
			END;
			RETURN TRUE;
		ELSIF M.id = Objects.get THEN
			FOR i := 0 TO len - 1 DO
				COPY( prefix, cur );  vyHostStrings.Append( cur, "[" );  vyHostStrings.AppendInt( i, 1, cur );  vyHostStrings.Append( cur, "]" );
				IF vyHostStrings.Equal( M.name, cur ) THEN M.y := array[i];  M.class := Objects.LongReal;  M.res := 0;  RETURN TRUE END;
			END;
		ELSIF M.id = Objects.set THEN
			FOR i := 0 TO len - 1 DO
				COPY( prefix, cur );  vyHostStrings.Append( cur, "[" );  vyHostStrings.AppendInt( i, 1, cur );  vyHostStrings.Append( cur, "]" );
				IF vyHostStrings.Equal( M.name, cur ) THEN
					IF M.class = Objects.LongReal THEN array[i] := M.y;  M.res := 0;  RETURN TRUE
					ELSIF M.class = Objects.Real THEN array[i] := M.x;  M.res := 0;  RETURN TRUE
					END;
				END;
			END;

		END;
		RETURN FALSE;
	END ArrayHandleAttribute;

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
					IF M.id = Objects.enum THEN
						IF ArrayHandleAttribute( M, "array", o.a ) THEN END;
						antsModels.Handler( o, M )
					ELSIF M.id = Objects.get THEN
						IF M.name = "Gen" THEN COPY( 'antsPEIsingDS.Gen', M.s );  M.class := Objects.String;  M.res := 0;  RETURN
						ELSIF ArrayHandleAttribute( M, "array", o.a ) THEN
						ELSE antsModels.Handler( o, M )
						END
					ELSIF M.id = Objects.set THEN
						IF ArrayHandleAttribute( M, "array", o.a ) THEN o.synced := FALSE ELSE antsModels.Handler( o, M ) END;
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
		END;   (* tVector*)
	END Handler;

	PROCEDURE OpenModel*( M: tModel;  name: vyCG.tNameArray );
	BEGIN
		antsModels.Open( M );  Open( M );  M.handle := Handler;  vyCG.RegisterNamed( M, name );
	END OpenModel;

	PROCEDURE Gen*;
	VAR M: tModel;
	BEGIN
		aM.cmd;  NEW( M );  M.handle := Handler;  Objects.NewObj := M;  M.synced := FALSE;
	END Gen;

	PROCEDURE NewModel*;
	VAR l: antsCommands.tScanList;  name: vyCG.tNameArray;  M: tModel;
		a: ARRAY 14 OF FLOAT64;
		i: SIGNED32;
	BEGIN
		l := antsCommands.ScanFromPar( "name= NAME a0=FLOAT32 a1=FLOAT32 a2=FLOAT32 a3=FLOAT32 a4=FLOAT32 a5=FLOAT32 b2=FLOAT32 b4=FLOAT32 b5=FLOAT32 g1=FLOAT32 g2=FLOAT32 d=FLOAT32 e=FLOAT32 pen=FLOAT32" );
		IF antsCommands.ExpectNameFromKeyword( l, "name", name ) & antsCommands.ExpectRealFromKeyword( l, "a0", a[0] ) &
		    antsCommands.ExpectRealFromKeyword( l, "a1", a[1] ) & antsCommands.ExpectRealFromKeyword( l, "a2", a[2] ) &
		    antsCommands.ExpectRealFromKeyword( l, "a3", a[3] ) & antsCommands.ExpectRealFromKeyword( l, "a4", a[4] ) &
		    antsCommands.ExpectRealFromKeyword( l, "a5", a[5] ) & antsCommands.ExpectRealFromKeyword( l, "b2", a[6] ) &
		    antsCommands.ExpectRealFromKeyword( l, "b4", a[7] ) & antsCommands.ExpectRealFromKeyword( l, "b5", a[8] ) &
		    antsCommands.ExpectRealFromKeyword( l, "g1", a[9] ) & antsCommands.ExpectRealFromKeyword( l, "g2", a[10] ) &
		    antsCommands.ExpectRealFromKeyword( l, "d", a[11] ) & antsCommands.ExpectRealFromKeyword( l, "e", a[12] ) &
		    antsCommands.ExpectRealFromKeyword( l, "pen", a[13] ) THEN
			NEW( M );
			FOR i := 0 TO 13 DO M.a[i] := a[i] END;
			OpenModel( M, name );
		END;
	END NewModel;

BEGIN
	aM.launch;
END antsPEIsingDS.

System.Free antsPEIsingDS ~
antsPEIsingDS.NewModel testmodel 0 1 2 3 4 5 6 7 8 9 10 11 12 13 14  ~
antsObjects.WriteAttributes testmodel ~

(* Parameters:
a[0] : No Edges  .
a[1] : One Edge _
a[2]: Two Edges with same direction --
a[3]: Turn L
a[4]: T
a[5]: Crossing x
a[6]: Parallel Edges ||
a[7]: U Turn U
a[8]: Box O
a[9]: Pixelweight with edge
a[10]:  Pixelweight without edge
a[11]: General tendency of Pixels ("greyval tendency")
a[12]: General tendency of Edges
a[13]: Penalizing term
*)

fofAutomatic.Do
Voyager.OpenLog temp.log ~
antsArrayPictures.Load testpict "ants/picts/zebra2.GIF"~
antsViews.Show testpict ~
antsArrayPictures.ToArray  testarray testpict 5 ~
antsPEV.NewField > from testarray > name Field ~
antsArrayPictures.New testpict2 FieldA ~
antsViews.Show testpict2 ~
antsArrayViews.Show > name FieldEh > hEdges > add~
antsArrayViews.Show > name FieldEv > vEdges > add~
antsPEIsingDS.NewModel   Model   2 1 3 1 - 2 - 4 - 4 - 7 - 6 - 1 1 0 0.2 15 ~
antsKernel.Define > name Sampler ~
antsKernel.AttachModel > sampler Sampler > model Model ~
antsKernel.AttachArray > sampler Sampler > array Field ~
antsMC.New chain ~
antsMC.Add chain Sampler ~
antsObjects.WriteAttributes Model
antsObjects.WriteAttributes Sampler ~
antsArrayObjects.Copy > name FieldEv > to MeanArray1 ~
antsArrayViews.Show > name MeanArray1 > vEdges~
antsMeanArray.New mean1 src = FieldEv dest = MeanArray1 ~
antsArrayObjects.Copy > name FieldEh > to MeanArray2 ~
antsArrayViews.Show > name MeanArray2 > hEdges > add ~
antsMeanArray.New mean2 src = FieldEh dest = MeanArray2 ~

~~

antsMC.Jump chain 0 ~
antsMC.Forward chain 1 10 ~
(Define Array, Edges and Vertices)
fofAutomatic.Do
antsArrayObjects.New > name Array > w 100 > h 100 > depth 5~
antsPEV.NewField > from Array > name Field ~
~
fofAutomatic.Do
antsViews.Show > name FieldA ~
antsViews.Show > name FieldEh > hor on ~
antsViews.Show > name FieldEv > ver on ~
antsViews.Show > name FieldV > ver on > hor on ~
~
fofAutomatic.Do
antsPEV.ShowField > name Field ~
~
Voyager.Show Sampler as antsObjectView ~


(* a0: Keine Kanten, a1: eine Kante, a2 : zwei Kanten, gleiche Richtung, a3: Ecke, a4: T, a5: Kreuz *)
(* a0: Keine Kanten, a1: eine Kante, b2: Parallele Kanten, a3: Ecke, b4: C, b5: Kasten *)
g0: gesamtGewichtung Pixel
g1: mit kante
g2: ohne Kante
d: generelle Tendenz zu Pixel
e: generelle Tendenz zu Kanten
pen: Penalisierungsterm
 * )

fofAutomatic.Do
antsPEIsingDS.NewModel  > name Model  > a0 2 > a1 1 > a2 3 > a3 0 > a4 - 1 > a5 - 1 > b2 - 7 > b4 - 1  > b5  0 > g0 2.8 > g1 - 0.2 > g2 1 > d 0  > e 0 > pen 0~
antsGibbs.DefineGibbsSampler > name Sampler > presteps 0 > steps 1 > noinit ~
antsGibbs.AttachModel > model Model > sampler Sampler ~
antsGibbs.AttachArray > array Field > sampler Sampler ~
antsGibbs.Step > sampler Sampler > times 10 ~

~




fofAutomatic.Do
antsPictArray.LoadPictureObject > name Array > filename "ants/picts/Ratbertbw.GIF" > type GIF~
antsDiscreteFields.ArrayToPict > name Array > depth 2~
antsViews.Show > name Array ~
antsDiscreteFields.AddNoise > name Array > var 1 ~
antsPEV.NewField > from Array > name Field ~
antsPEV.ShowField > name Field ~
antsPEIsingBS.NewModel  > name Model  > a0 1 > a1 0.2 > a2 3 > a3 0.5 > a4 0.1 > a5 0.001 > b2 0.0001 > b4 0.001  > b5  1 > g0 2.8 > g1 0 > g2 1 > d 0.2   > penalize 0.2 ~
antsGibbs.Attach > model Model > array Field ~
antsGibbs.DefineGibbsSampler > name Sampler2 > model Model > presteps 0 > steps 1 > noinit ~
antsGibbs.Step > sampler Sampler2 > times 10 ~
~
ants / antsArrayPictures.Mod
ants / antsViews.Mod