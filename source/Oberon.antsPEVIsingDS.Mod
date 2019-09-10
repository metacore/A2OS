MODULE antsPEVIsingDS IN Oberon;   (** fof  **)
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




IMPORT antsArrayObjects, Math := MathL IN A2, aM := antsMessages, antsPEV, antsKernel, antsModels, antsCommands,
	vyCG := vyName, antsCaches, Files, Objects, vyHostStrings, vyRanBase;

TYPE
	tModel* = POINTER TO tModelDesc;
	tModelDesc* = RECORD (antsModels.tModelDesc);
	(* a0  a[0] ,a1 a[1] ,a2 a[2] ,a3 a[3] ,a4 a[4] ,a5 a[5] ,b2 a[6] ,b4 a[7] ,b5 a[8] ,g0 a[9] ,g1 a[10] ,g2 a[11] ,d a[12] ,
		e  a[13] ,pen a[14] : FLOAT64; *)
		a: ARRAY 15 OF FLOAT64;

		(* Parameters:
		a[0] : Edge when no vertice
		a[1] : Edge when one vertice
		a[2]: Edge when two vertices
		a[3]:  Vertice when no edge
		a[4]: Vertice when one edge
		a[5]: Vertice when two edes --
		a[6]: Vertice when L
		a[7]: Vertice when three edges
		a[8]: Vertice when four edges
		a[9]: Pixelweight with edge
		a[10]: Pixelweight without edge
		a[11]: General tendency of Pixels ("greyval tendency")
		a[12]:  General tendency of Edges
		a[13]: General tendency of Vertices
		a[14]: Penalizing term
		*)

		cp, ce, cv: antsCaches.FullCache
	END;
VAR
	GM: tModel;  depth: SIGNED16;

	PROCEDURE Open*( M: tModel );
	BEGIN
		M.cp := NIL;  M.ce := NIL;  M.synced := FALSE
	END Open;

	PROCEDURE dist( e1, e2: SIGNED16 ): FLOAT32;
	BEGIN
		RETURN -((e1 - e2) * (e1 - e2) / depth / depth)
	END dist;

	PROCEDURE dist2( e1, e2: SIGNED16 ): FLOAT32;
	BEGIN
		IF e1 = e2 THEN RETURN 1 ELSE RETURN -1 END;
	END dist2;

	PROCEDURE f1( e, v1, v2: SIGNED16 ): FLOAT64;
	(*		+v1
	| e
	+v2
	*)
	VAR sum: SIGNED16;
	BEGIN
		sum := v1 + v2;
		IF e = 0 THEN
			CASE sum OF
			0:     RETURN -GM.a[0]
			| 1:   RETURN -GM.a[1]
			| 2:   RETURN -GM.a[2]
			END
		ELSE
			CASE sum OF
			0:     RETURN GM.a[0]
			| 1:   RETURN GM.a[1]
			| 2:   RETURN GM.a[2]
			END
		END
	END f1;

	PROCEDURE f2( v, e1, e2, e3, e4: SIGNED16 ): FLOAT64;
	(*
	| e1
	-e2 +v -e3
	| e2
	*)
	VAR sum: SIGNED16;
	BEGIN
		sum := e1 + e2 + e3 + e4;
		IF v = 0 THEN
			CASE sum OF
			0:     RETURN -GM.a[3]
			| 1:   RETURN -GM.a[4]
			| 2:   IF e1 = e2 THEN RETURN -GM.a[5] ELSE RETURN -GM.a[6] END;
			| 3:   RETURN -GM.a[7]
			| 4:   RETURN -GM.a[8]
			END
		ELSE
			CASE sum OF
			0:     RETURN GM.a[3]
			| 1:   RETURN GM.a[4]
			| 2:   IF e1 = e2 THEN RETURN GM.a[5] ELSE RETURN GM.a[6] END;
			| 3:   RETURN GM.a[7]
			| 4:   RETURN GM.a[8]
			END
		END
	END f2;

	PROCEDURE f3( e, p1, p2: SIGNED16 ): FLOAT64;
	(* p1 * |e * p2 *)
	BEGIN
		IF e = 1 THEN RETURN dist2( p1, p2 ) * GM.a[9] ELSE RETURN dist2( p1, p2 ) * GM.a[10] END
	END f3;

	PROCEDURE f4( p: SIGNED16 ): FLOAT64;
	BEGIN
		RETURN GM.a[11] * p
	END f4;

	PROCEDURE f5( e: SIGNED16 ): FLOAT64;
	BEGIN
		RETURN GM.a[12] * e
	END f5;

	PROCEDURE f6( v: SIGNED16 ): FLOAT64;
	BEGIN
		RETURN GM.a[13] * v
	END f6;

	PROCEDURE f7( p1, p2: SIGNED16 ): FLOAT64;
	BEGIN
		RETURN GM.a[14] * dist( p1, p2 )
	END f7;

	PROCEDURE UP( VAR a: ARRAY OF SIGNED16 ): FLOAT64;
	BEGIN
		RETURN f3( a[5], a[0], a[1] ) + f3( a[6], a[0], a[2] ) + f3( a[7], a[0], a[3] ) + f3( a[8], a[0], a[4] ) + f4( a[0] ) +
				    f7( a[0], a[9] )
	END UP;

	PROCEDURE EP( VAR a: ARRAY OF SIGNED16 ): FLOAT64;
	BEGIN
		RETURN Math.exp( UP( a ) )
	END EP;

	PROCEDURE DistriFromLocalChar( F: antsPEV.tField;  y, x: SIGNED32 );
	VAR po, p, p1, p2, p3, p4, e1, e2, e3, e4: SIGNED16;  nges, prob, rand: FLOAT64;
	BEGIN
		(* insert penalization to AOrig here *)
		po := F.Aorig.A[y, x];  antsPEV.EGetPNeighbours( F, y, x, p, p1, p2, p3, p4, e1, e2, e3, e4 );  nges := 0;
		FOR p := 0 TO SHORT( F.A.depth - 1 ) DO
			nges := nges + Math.exp( f3( e1, p, p1 ) + f3( e2, p, p2 ) + f3( e3, p, p3 ) + f3( e4, p, p4 ) + f4( p ) + f7( p, po ) )
		END;
		rand := vyRanBase.RandomU();  prob := 0;  p := 0;
		REPEAT
			prob :=
				prob + Math.exp( f3( e1, p, p1 ) + f3( e2, p, p2 ) + f3( e3, p, p3 ) + f3( e4, p, p4 ) + f4( p ) + f7( p, po ) ) / nges;
			INC( p )
		UNTIL prob >= rand;
		F.A.A[y, x] := p - 1
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
				WHILE c.values[offset + p] < rand DO INC( p ) END;
				A[y, x] := p
			END
		END
	END FastestC;

	PROCEDURE UE( VAR a: ARRAY OF SIGNED16 ): FLOAT64;
	BEGIN
		RETURN f1( a[0], a[1], a[2] ) + f3( a[0], a[3], a[4] ) + f5( a[0] )
	END UE;

	PROCEDURE EE( VAR a: ARRAY OF SIGNED16 ): FLOAT64;
	BEGIN
		RETURN Math.exp( UE( a ) )
	END EE;

	PROCEDURE DistriFromLocalCharE( F: antsPEV.tField;  y, x: SIGNED32 );
	VAR e, p1, p2, v1, v2: SIGNED16;  nges, ges, prob: FLOAT64;
	BEGIN
		antsPEV.EVGetENeighboursH( F, y, x, e, p1, p2, v1, v2 );  e := 0;  nges := f1( e, v1, v2 ) + f3( e, p1, p2 ) + f5( e );  e := 1;
		ges := f1( e, v1, v2 ) + f3( e, p1, p2 ) + f5( e );  prob := Math.exp( ges );  prob := prob / (prob + Math.exp( nges ));
		IF vyRanBase.RandomU() < prob THEN F.Eh.A[y, x] := 1 ELSE F.Eh.A[y, x] := 0 END;
		antsPEV.EVGetENeighboursV( F, y, x, e, p1, p2, v1, v2 );  e := 0;  nges := f1( e, v1, v2 ) + f3( e, p1, p2 ) + f5( e );  e := 1;
		ges := f1( e, v1, v2 ) + f3( e, p1, p2 ) + f5( e );  prob := Math.exp( ges );  prob := prob / (prob + Math.exp( nges ));
		IF vyRanBase.RandomU() < prob THEN F.Ev.A[y, x] := 1 ELSE F.Ev.A[y, x] := 0 END
	END DistriFromLocalCharE;

	PROCEDURE FastestEC( F: antsPEV.tField );
	VAR y, x, w, h, offset: SIGNED32;
		a: ARRAY 11 OF SIGNED16;
		c: antsCaches.FullCache;  A, H, V, VV: antsArrayObjects.tINTEGERArray;
	BEGIN
		c := GM.ce;  A := F.A.A;  H := F.Eh.A;  V := F.Ev.A;  VV := F.V.A;  w := F.w;  h := F.h;
		FOR y := 0 TO h - 1 DO
			FOR x := 0 TO w - 1 DO
				a[1] := VV[y, (x)];  a[2] := VV[y, (x + 1) MOD w];  a[3] := A[(y - 1) MOD h, x];  a[4] := A[y, x];
				offset := c.Offset( a, 1 );
				IF vyRanBase.RandomU() < c.values[offset] THEN H[y, x] := 0 ELSE H[y, x] := 1 END;
				a[1] := VV[y, (x)];  a[2] := VV[(y + 1) MOD h, x];  a[3] := A[(y), (x - 1) MOD w];  a[4] := A[y, x];
				offset := c.Offset( a, 1 );
				IF vyRanBase.RandomU() < c.values[offset] THEN V[y, x] := 0 ELSE V[y, x] := 1 END
			END
		END
	END FastestEC;


(****)

	PROCEDURE UV( VAR a: ARRAY OF SIGNED16 ): FLOAT64;
	BEGIN
		RETURN f2( a[0], a[1], a[2], a[3], a[4] ) + f6( a[0] )
	END UV;

	PROCEDURE EV( VAR a: ARRAY OF SIGNED16 ): FLOAT64;
	BEGIN
		RETURN Math.exp( UV( a ) )
	END EV;

	PROCEDURE DistriFromLocalCharV( F: antsPEV.tField;  y, x: SIGNED32 );
	VAR e1, e2, e3, e4, v: SIGNED16;  nges, ges, prob: FLOAT64;
	BEGIN
		antsPEV.EVGetVNeighbours( F, y, x, v, e1, e2, e3, e4 );  v := 0;  nges := f2( v, e1, e2, e3, e4 ) + f6( v );  v := 1;
		ges := f2( v, e1, e2, e3, e4 ) + f6( v );  prob := Math.exp( ges );  prob := prob / (prob + Math.exp( nges ));
		IF vyRanBase.RandomU() < prob THEN F.V.A[y, x] := 1 ELSE F.V.A[y, x] := 0 END
	END DistriFromLocalCharV;

	PROCEDURE FastestVC( F: antsPEV.tField );
	VAR y, x, w, h, offset: SIGNED32;
		a: ARRAY 11 OF SIGNED16;
		c: antsCaches.FullCache;  A, H, V, VV: antsArrayObjects.tINTEGERArray;
	BEGIN
		c := GM.cv;  A := F.A.A;  H := F.Eh.A;  V := F.Ev.A;  VV := F.V.A;  w := F.w;  h := F.h;
		FOR y := 0 TO h - 1 DO
			FOR x := 0 TO w - 1 DO
				a[1] := V[y, (x)];  a[2] := V[(y - 1) MOD h, x];  a[3] := H[(y), (x - 1) MOD w];  a[4] := H[y, x];
				offset := c.Offset( a, 1 );
				IF vyRanBase.RandomU() < c.values[offset] THEN VV[y, x] := 0 ELSE VV[y, x] := 1 END
			END
		END
	END FastestVC;

	PROCEDURE CreateCaches( m: tModel;  d: SIGNED16 );
	VAR A: ARRAY 11 OF SIGNED16;
		i: SIGNED16;  offset: SIGNED32;  c: antsCaches.FullCache;  s: FLOAT64;
	BEGIN
		FOR i := 0 TO 4 DO A[i] := d END;
		FOR i := 5 TO 8 DO A[i] := 2 END;
		A[9] := d;

		c := antsCaches.Cuboid( 10, A, 1000000 );  m.cp := c;
		IF c # NIL THEN
			aM.vS( "Computing Pixel-edge cache" );  offset := -1;
			WHILE (c.NextPoint( offset, A, 1 )) DO
				s := 0;  i := 0;
				WHILE (i < d) DO A[0] := i;  s := s + EP( A );  c.values[i + offset] := s;  INC( i ) END;
				A[0] := 0;
				(* divide by normalizing constant *)
				i := 0;
				WHILE (i < d) DO c.values[offset + i] := c.values[offset + i] / s;  INC( i ) END

			END;
			aM.vS( "done." );

		END;

		FOR i := 0 TO 2 DO A[i] := 2 END;
		FOR i := 3 TO 4 DO A[i] := d END;

		c := antsCaches.Cuboid( 5, A, 1000000 );  m.ce := c;
		IF c # NIL THEN
			aM.vS( "Computing Edge-Pixel-Cache" );  offset := -1;
			WHILE (c.NextPoint( offset, A, 1 )) DO
				s := 0;  i := 0;
				WHILE (i < 2) DO A[0] := i;  s := s + EE( A );  c.values[i + offset] := s;  INC( i ) END;
				A[0] := 0;
				(* divide by normalizing constant *)
				i := 0;
				WHILE (i < 2) DO c.values[offset + i] := c.values[offset + i] / s;  INC( i ) END
			END;
			aM.vS( "done." );
		END;

		FOR i := 0 TO 4 DO A[i] := 2 END;
		c := antsCaches.Cuboid( 5, A, 1000000 );  m.cv := c;
		IF c # NIL THEN
			aM.vS( "Computing Vertice-Pixel-Cache" );  offset := -1;
			WHILE (c.NextPoint( offset, A, 1 )) DO
				s := 0;  i := 0;
				WHILE (i < 2) DO A[0] := i;  s := s + EV( A );  c.values[i + offset] := s;  INC( i ) END;
				A[0] := 0;
				(* divide by normalizing constant *)
				i := 0;
				WHILE (i < 2) DO c.values[offset + i] := c.values[offset + i] / s;  INC( i ) END
			END;
			aM.vS( "done." );
		END

	END CreateCaches;

	PROCEDURE OneSweep*( s: antsKernel.Kernel );
	VAR F: antsPEV.tField;
	BEGIN
		GM := s.par( tModel );  F := s.A( antsPEV.tField );  depth := SHORT( F.A.depth );
		IF ~GM.synced THEN CreateCaches( GM, depth );  GM.synced := TRUE END;
		(* antsPEV.ForAllDo(F,F.V,DistriFromLocalCharV); *)
		IF F.A.depth <= 2 THEN
			(* vyHostTexts.Note(vyHostTexts.cWarning,"You use a binary picture, try using Ising model first !");  *)
		ELSE
		END;
		IF GM.cv # NIL THEN FastestVC( F ) ELSE antsPEV.ForAllDo( F, DistriFromLocalCharV ) END;
		IF GM.ce # NIL THEN FastestEC( F ) ELSE antsPEV.ForAllDo( F, DistriFromLocalCharE ) END;
		IF GM.cp # NIL THEN FastestC( F ) ELSE antsPEV.ForAllDo( F, DistriFromLocalChar ) END;
		antsPEV.FieldHasChanged( F )
	END OneSweep;

	PROCEDURE Uniform*( s: antsKernel.Kernel );
	BEGIN
		antsPEV.DoUniform( s.A( antsPEV.tField ) )
	END Uniform;

	PROCEDURE WriteArray( VAR R: Files.Rider;  VAR A: ARRAY OF FLOAT64 );
	VAR i: SIGNED32;
	BEGIN
		Files.WriteLInt( R, LEN( A ) );  aM.launch;
		FOR i := 0 TO LEN( A ) - 1 DO Files.WriteLReal( R, A[i] ) END
	END WriteArray;

	PROCEDURE ReadArray( VAR R: Files.Rider;  VAR A: ARRAY OF FLOAT64 );
	VAR i, len: SIGNED32;
	BEGIN
		Files.ReadLInt( R, len );
		FOR i := 0 TO len - 1 DO Files.ReadLReal( R, A[i] ) END
	END ReadArray;

	PROCEDURE StoreM( VAR R: Files.Rider;  s: tModel );
	BEGIN
		Files.WriteInt( R, 0 );  WriteArray( R, s.a )
	END StoreM;

	PROCEDURE LoadM( VAR R: Files.Rider;  s: tModel );
	VAR version: SIGNED16;
	BEGIN
		Files.ReadInt( R, version );  ReadArray( R, s.a )
	END LoadM;

	PROCEDURE ArrayHandleAttribute( VAR M: Objects.AttrMsg;  prefix: ARRAY OF CHAR;  VAR array: ARRAY OF FLOAT64 ): BOOLEAN;
	VAR cur: ARRAY 64 OF CHAR;
		i: SIGNED32;  len: SIGNED32;
	BEGIN
		len := LEN( array );
		IF M.id = Objects.enum THEN
			FOR i := 0 TO len - 1 DO
				COPY( prefix, cur );  vyHostStrings.Append( cur, "[" );  vyHostStrings.AppendInt( i, 1, cur );  vyHostStrings.Append( cur, "]" );
				M.Enum( cur )
			END;
			RETURN TRUE
		ELSIF M.id = Objects.get THEN
			FOR i := 0 TO len - 1 DO
				COPY( prefix, cur );  vyHostStrings.Append( cur, "[" );  vyHostStrings.AppendInt( i, 1, cur );  vyHostStrings.Append( cur, "]" );
				IF vyHostStrings.Equal( M.name, cur ) THEN M.y := array[i];  M.class := Objects.LongReal;  M.res := 0;  RETURN TRUE END
			END
		ELSIF M.id = Objects.set THEN
			FOR i := 0 TO len - 1 DO
				COPY( prefix, cur );  vyHostStrings.Append( cur, "[" );  vyHostStrings.AppendInt( i, 1, cur );  vyHostStrings.Append( cur, "]" );
				IF vyHostStrings.Equal( M.name, cur ) THEN
					IF M.class = Objects.LongReal THEN array[i] := M.y;  M.res := 0;  RETURN TRUE
					ELSIF M.class = Objects.Real THEN array[i] := M.x;  M.res := 0;  RETURN TRUE
					END
				END
			END

		END;
		RETURN FALSE
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
						IF M.name = "Gen" THEN COPY( 'antsPEVIsingDS.Gen', M.s );  M.class := Objects.String;  M.res := 0;  RETURN
						ELSIF ArrayHandleAttribute( M, "array", o.a ) THEN
						ELSE antsModels.Handler( o, M )
						END
					ELSIF M.id = Objects.set THEN
						IF ArrayHandleAttribute( M, "array", o.a ) THEN o.synced := FALSE ELSE antsModels.Handler( o, M ) END
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
		END  (* tVector*)
	END Handler;

	PROCEDURE OpenModel*( M: tModel;  name: vyCG.tNameArray );
	BEGIN
		antsModels.Open( M );  Open( M );  M.handle := Handler;  vyCG.RegisterNamed( M, name )
	END OpenModel;

	PROCEDURE Gen*;
	VAR M: tModel;
	BEGIN
		aM.cmd;  NEW( M );  M.handle := Handler;  Objects.NewObj := M;  M.synced := FALSE
	END Gen;

	PROCEDURE NewModel*;
	VAR l: antsCommands.tScanList;  name: vyCG.tNameArray;  M: tModel;
		a: ARRAY 15 OF FLOAT64;
		i: SIGNED32;
	BEGIN
		l := antsCommands.ScanFromPar( "name= NAME a0=FLOAT32 a1=FLOAT32 a2=FLOAT32 a3=FLOAT32 a4=FLOAT32 a5=FLOAT32 a6=FLOAT32 a7=FLOAT32 a8=FLOAT32 a9=FLOAT32 a10=FLOAT32 a11=FLOAT32 a12=FLOAT32 a13=FLOAT32 a14=FLOAT32" );
		IF antsCommands.ExpectNameFromKeyword( l, "name", name ) & antsCommands.ExpectRealFromKeyword( l, "a0", a[0] ) &
		    antsCommands.ExpectRealFromKeyword( l, "a1", a[1] ) & antsCommands.ExpectRealFromKeyword( l, "a2", a[2] ) &
		    antsCommands.ExpectRealFromKeyword( l, "a3", a[3] ) & antsCommands.ExpectRealFromKeyword( l, "a4", a[4] ) &
		    antsCommands.ExpectRealFromKeyword( l, "a5", a[5] ) & antsCommands.ExpectRealFromKeyword( l, "a6", a[6] ) &
		    antsCommands.ExpectRealFromKeyword( l, "a7", a[7] ) & antsCommands.ExpectRealFromKeyword( l, "a8", a[8] ) &
		    antsCommands.ExpectRealFromKeyword( l, "a9", a[9] ) & antsCommands.ExpectRealFromKeyword( l, "a10", a[10] ) &
		    antsCommands.ExpectRealFromKeyword( l, "a11", a[11] ) & antsCommands.ExpectRealFromKeyword( l, "a12", a[12] ) &
		    antsCommands.ExpectRealFromKeyword( l, "a13", a[13] ) & antsCommands.ExpectRealFromKeyword( l, "a14", a[14] ) THEN
			NEW( M );
			FOR i := 0 TO 14 DO M.a[i] := a[i] END;
			OpenModel( M, name )
		END
	END NewModel;

BEGIN
	aM.launch;
END antsPEVIsingDS.

System.Free antsPEVIsingDS ~
antsPEIsingDS.NewModel testmodel 0 1 2 3 4 5 6 7 8 9 10 11 12 13 14  ~
antsObjects.WriteAttributes testmodel ~
(* Parameters:
a[0] : Edge when no vertice
a[1] : Edge when one vertice
a[2]: Edge when two vertices
a[3]:  Vertice when no edge
a[4]: Vertice when one edge
a[5]: Vertice when two edes --
a[6]: Vertice when L
a[7]: Vertice when three edges
a[8]: Vertice when four edges
a[9]: Pixelweight with edge
a[10]: Pixelweight without edge
a[11]: General tendency of Pixels ("greyval tendency")
a[12]:  General tendency of Edges
a[13]: General tendency of Vertices
a[14]: Penalizing term
*)

fofAutomatic.Do
Voyager.OpenLog temp.log ~
antsPEV.NewField > from myArray > name Field ~
antsArrayPictures.New testpict FieldA ~
antsViews.Show testpict ~
antsArrayViews.Show > name FieldEh > hEdges > add~
antsArrayViews.Show > name FieldEv > vEdges > add~
antsArrayViews.Show > name FieldV > Vertices > add~
antsPEVIsingDS.NewModel   Model   -1 0 1 -1 0 1 0 -1 -1 1 0 0 0 0 0 ~
antsKernel.Define > name Sampler ~
antsKernel.AttachModel > sampler Sampler > model Model ~
antsKernel.AttachArray > sampler Sampler > array Field ~
antsMC.New chain ~
antsMC.Add chain Sampler ~
antsObjects.WriteAttributes Model
~
antsObjects.WriteAttributes Sampler
antsMC.Jump chain 0 ~
antsArrayObjects.Copy myArray FieldA ~
antsMC.Forward chain 1 1  ~
(Define Array, Edges and Vertices)
