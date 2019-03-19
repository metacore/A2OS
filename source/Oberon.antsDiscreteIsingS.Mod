MODULE antsDiscreteIsingS IN Oberon;   (** fof  **)
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




IMPORT antsObjects, Files, vyBase, Math := MathL IN A2, antsKernel, antsArrays, antsArrayObjects, antsModels, antsCommands,
	vyName, Objects, aM := antsMessages;

TYPE
	nb = POINTER TO ARRAY OF ARRAY OF ARRAY OF ARRAY OF LONGREAL;
	pb = POINTER TO ARRAY OF ARRAY OF ARRAY OF ARRAY OF ARRAY OF LONGREAL;


	(* unused, old idea, realized in antsCaches in more generality
	tCachedU = POINTER TO ARRAY OF LONGREAL;
	tConstNeighbourCache* = POINTER TO RECORD
	Z: LONGREAL;
	U: tCachedU;
	E: LONGREAL
	END;
	*)

	RandomArray = POINTER TO ARRAY OF LONGREAL;

	tModel* = POINTER TO tModelDesc;
	tModelDesc* = RECORD (antsModels.tModelDesc)
		h-, beta-: LONGREAL;
		ch, cbeta: LONGREAL;
		Z: nb;
		U, P, Cdf: pb;
		card: LONGINT;
		dist: vyName.tNameArray;
		ran: RandomArray
	END;

VAR  (* localCache: tConstNeighbourCache;  *)
	localModel: tModel;

	PROCEDURE U( m: tModel;  x, v1, v2, v3, v4: LONGINT ): LONGREAL;
	VAR a: LONGINT;
	BEGIN
		IF m.dist = "L1" THEN a := ABS( x - v1 ) + ABS( x - v2 ) + ABS( x - v3 ) + ABS( x - v4 )
		ELSIF m.dist = "L2" THEN a := (x - v1) * (x - v1) + (x - v2) * (x - v2) + (x - v3) * (x - v3) + (x - v4) * (x - v4)
		ELSIF m.dist = "L0" THEN
			a := 0;
			IF x # v1 THEN INC( a ) END;
			IF x # v2 THEN INC( a ) END;
			IF x # v3 THEN INC( a ) END;
			IF x # v4 THEN INC( a ) END
		END;
		RETURN Math.exp( m.coolingTemp * (m.ch * x - m.cbeta * a) )
	END U;

	PROCEDURE Z( m: tModel;  v1, v2, v3, v4: LONGINT ): LONGREAL;
	VAR x: LONGINT;  z: LONGREAL;
	BEGIN
		z := 0;
		FOR x := 0 TO m.card - 1 DO z := z + U( m, x, v1, v2, v3, v4 ) END;
		RETURN z
	END Z;

(*
PROCEDURE FillCache* (VAR c: tConstNeighbourCache;   beta, h: LONGREAL;   d: LONGINT;   v1, v2, v3, v4: LONGINT);
VAR x: LONGINT;   r: LONGREAL;
BEGIN
localModel.beta := beta;   localModel.h := h;   localModel.card := d;
IF c = NIL THEN NEW(c) END;
IF (c.U = NIL) OR (LEN(c.U^) # d) THEN
NEW(c.U, d)
END;
c.Z := 0;   c.E := 0;
FOR x := 0 TO d - 1 DO
r := U(localModel, x, v1, v2, v3, v4);
c.U[x] := r;
c.Z := c.Z + r;
c.E := c.E + r * x
END;
c.E := c.E / c.Z
END FillCache;

PROCEDURE CachedU* (c: tConstNeighbourCache;   x: LONGINT): LONGREAL;
BEGIN	RETURN c.U[x] END CachedU;

PROCEDURE CachedZ* (c: tConstNeighbourCache): LONGREAL;
BEGIN	RETURN c.Z END CachedZ;

PROCEDURE CachedP* (c: tConstNeighbourCache;   x: LONGINT): LONGREAL;
BEGIN	RETURN c.U[x] / c.Z END CachedP;

PROCEDURE CachedE* (c: tConstNeighbourCache): LONGREAL;
BEGIN	RETURN c.E
END CachedE;
*)

	PROCEDURE CalcP( M: tModel );
	VAR x, v1, v2, v3, v4: LONGINT;  card: LONGINT;  p: LONGREAL;  t1, t2: LONGREAL;
	BEGIN
		card := M.card;  DEC( card );
		FOR v1 := 0 TO card DO
			FOR v2 := 0 TO card DO
				FOR v3 := 0 TO card DO
					FOR v4 := 0 TO card DO
						M.Z[v1, v2, v3, v4] := Z( M, v1, v2, v3, v4 );  p := 0;
						FOR x := 0 TO card DO
							M.U[x, v1, v2, v3, v4] := U( M, x, v1, v2, v3, v4 );  t1 := M.U[x, v1, v2, v3, v4];  t2 := M.Z[v1, v2, v3, v4];
							M.P[x, v1, v2, v3, v4] := t1 / t2;  p := p + M.P[x, v1, v2, v3, v4];  M.Cdf[x, v1, v2, v3, v4] := p
						END
					END
				END
			END
		END
	END CalcP;

	PROCEDURE SetPars( M: tModel );
	BEGIN
		M.cbeta := M.beta * 2;  M.ch := M.h * 2
	END SetPars;

	PROCEDURE NewDepth( M: tModel;  card: LONGINT );
	BEGIN
		IF M.card # card THEN
			M.card := card;  NEW( M.Z, card, card, card, card );  NEW( M.P, card, card, card, card, card );
			NEW( M.U, card, card, card, card, card );  NEW( M.Cdf, card, card, card, card, card );  SetPars( M );  CalcP( M )
		END
	END NewDepth;

	PROCEDURE Open*( M: tModel;  beta, h: LONGREAL );
	BEGIN
		M.h := h;  M.beta := beta;  M.card := 0
	END Open;

	PROCEDURE StoreM( VAR R: Files.Rider;  s: tModel );
	BEGIN
		Files.WriteInt( R, 0 );  Files.WriteLReal( R, s.h );  Files.WriteLReal( R, s.beta );  Files.WriteLInt( R, s.card );
		Files.WriteString( R, s.dist )
	END StoreM;

	PROCEDURE LoadM( VAR R: Files.Rider;  s: tModel );
	VAR card: LONGINT;  version: INTEGER;
	BEGIN
		Files.ReadInt( R, version );  Files.ReadLReal( R, s.h );  Files.ReadLReal( R, s.beta );  Files.ReadLInt( R, card );
		Files.ReadString( R, s.dist );  s.card := 0;  Open( s, s.beta, s.h );  NewDepth( s, s.card )
	END LoadM;

	PROCEDURE CheckDepth( s: antsKernel.Kernel );
	VAR AO: antsArrayObjects.tINTEGERObject;
	BEGIN
		AO := s.A( antsArrayObjects.tINTEGERObject );
		IF s.par( tModel ).card # AO.depth THEN NewDepth( s.par( tModel ), AO.depth ) END
	END CheckDepth;

	PROCEDURE OneSweep( s: antsKernel.Kernel );
	VAR x, y, w, h: LONGINT;  A: antsArrayObjects.tINTEGERArray;  model: tModel;  p: RandomArray;  xv: INTEGER;  v1, v2, v3, v4: LONGINT;  cdf: LONGREAL;
		AO: antsArrayObjects.tINTEGERObject;  t1, t2, t3, t4: LONGINT;  ran: LONGREAL;  d: INTEGER;

		PROCEDURE DistriFromLocalChar( VAR x, y: LONGINT );
		BEGIN
			v1 := A[y, (x - 1) MOD w];  v2 := A[(y - 1) MOD h, x];  v3 := A[y, (x + 1) MOD w];  v4 := A[(y + 1) MOD h, x];
			ran := p[x];  xv := 0;  cdf := model.Cdf[xv, v1, v2, v3, v4];

			WHILE (cdf < ran) & (xv < d) DO INC( xv );  cdf := model.Cdf[xv, v1, v2, v3, v4]
			END;

			A[y, x] := xv
		END DistriFromLocalChar;

	BEGIN
		model := s.par( tModel );
		IF ~model.synced THEN SetPars( model );  CalcP( model );  model.synced := TRUE END;
		CheckDepth( s );  AO := s.A( antsArrayObjects.tINTEGERObject );  w := AO.w;  h := AO.h;  A := AO.A;
		d := SHORT( (AO.depth - 1) );
		(*
	antsArrayObjects.UniformR(w,h);
	p := antsArrayObjects.RandomR;
	*)
		IF (model.ran = NIL ) OR (LEN( model.ran ) # AO.w) THEN NEW( model.ran, AO.w ) END;
		p := model.ran;

		y := 0;  antsArrays.Uniform1dX( p^, 0, LEN( p ), 1 );
		FOR x := 0 TO w - 1 DO DistriFromLocalChar( x, y ) END;
		FOR y := 1 TO h - 2 DO
			x := 0;  antsArrays.Uniform1dX( p^, 0, LEN( p ), 1 );  DistriFromLocalChar( x, y );
			FOR x := 1 TO w - 2 DO
			(* vt := ul[x]+ll[x]+tl[x-1]+tl[x+1]; *)
				t1 := A[y, x - 1];  t2 := A[y, x + 1];  t3 := A[y + 1, x];  t4 := A[y - 1, x];  xv := 0;  cdf := model.Cdf[xv, t1, t2, t3, t4];
				ran := p[x];

				WHILE (cdf < ran) & (xv < d) DO INC( xv );  cdf := model.Cdf[xv, t1, t2, t3, t4]
				END;

				A[y, x] := xv
			END;
			x := w - 1;  DistriFromLocalChar( x, y )
		END;
		y := h - 1;  antsArrays.Uniform1dX( p^, 0, LEN( p ), 1 );
		FOR x := 0 TO w - 1 DO DistriFromLocalChar( x, y ) END

	END OneSweep;

	PROCEDURE Uniform( s: antsKernel.Kernel );
	BEGIN
		antsArrayObjects.UniformO( s.A( antsArrayObjects.tObject ) )
	END Uniform;

	PROCEDURE Handler*( o: Objects.Object;  VAR M: Objects.ObjMsg );
	BEGIN
		WITH o: tModel DO
			IF M IS antsKernel.samplingMsg THEN
				WITH M: antsKernel.samplingMsg DO
					antsModels.SetTemperature( o, M.temp );  OneSweep( M.dlink( antsKernel.Kernel ) );
					antsModels.Handler( o, M );
				END;
			ELSIF M IS antsKernel.Init THEN
				WITH M: antsKernel.Init DO Uniform( M.dlink( antsKernel.Kernel ) );  o.synced := FALSE;  antsModels.Handler( o, M );
				END;
			ELSIF M IS Objects.AttrMsg THEN
				WITH M: Objects.AttrMsg DO

					IF M.id = Objects.enum THEN M.Enum( "beta" );  M.Enum( "h" );  M.Enum( "dist" );  antsModels.Handler( o, M )
					ELSIF M.id = Objects.get THEN
						IF M.name = "Gen" THEN COPY( 'antsDiscreteIsingS.Gen', M.s );  M.class := Objects.String;  M.res := 0;  RETURN
						ELSIF M.name = "beta" THEN M.class := Objects.LongReal;  M.y := o.beta;  M.res := 0;  RETURN
						ELSIF M.name = "h" THEN M.class := Objects.LongReal;  M.y := o.h;  M.res := 0;  RETURN
						ELSIF M.name = "dist" THEN M.class := Objects.String;  COPY( o.dist, M.s );  M.res := 0
						ELSE antsModels.Handler( o, M )
						END
					ELSIF M.id = Objects.set THEN
						IF M.name = "beta" THEN
							IF M.class = Objects.LongReal THEN
								o.beta := M.y;  o.synced := FALSE;  M.res := 0;  vyBase.Update( o );  RETURN
							END
						ELSIF M.name = "h" THEN
							IF M.class = Objects.LongReal THEN o.h := M.y;  o.synced := FALSE;  M.res := 0;  vyBase.Update( o );  RETURN END
						ELSIF M.name = "dist" THEN
							IF M.class = Objects.String THEN
								IF (M.s = "L1") OR (M.s = "L2") OR (M.s = "L0") THEN COPY( M.s, o.dist );  M.res := 0;  o.synced := FALSE END
							END
						ELSE antsModels.Handler( o, M )
						END
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

	PROCEDURE OpenModel*( M: tModel;  name: vyName.tNameArray;  beta, h: LONGREAL );
	BEGIN
		Open( M, beta, h );  vyName.RegisterNamed( M, name )
	END OpenModel;

	PROCEDURE Gen*;
	VAR m: tModel;
	BEGIN
		aM.cmd;  NEW( m );  m.handle := Handler;  Objects.NewObj := m;  m.dist := "L1";  antsObjects.Register( m )
	END Gen;

	PROCEDURE NewModel*;
	VAR l: antsCommands.tScanList;  name: vyName.tNameArray;  M: tModel;  beta, h: LONGREAL;
	BEGIN
		l := antsCommands.ScanFromPar( "name=NAME beta=REAL h=REAL" );
		IF antsCommands.ExpectNameFromKeyword( l, "name", name ) & antsCommands.ExpectRealFromKeyword( l, "beta", beta ) &
		    antsCommands.ExpectRealFromKeyword( l, "h", h ) THEN
			Gen;  M := Objects.NewObj( tModel );  antsModels.Open( M );  OpenModel( M, name, beta, h )
		END
	END NewModel;

BEGIN
	aM.launch;  NEW( localModel );
END antsDiscreteIsingS.

System.Free antsDiscreteIsingS ~

fofAutomatic.Do
Voyager.OpenLog test.temp ~
antsArrayObjects.New testarray 100 100 16 ~
antsArrayPictures.New testpict testarray ~
Voyager.Show testpict as antsPictureViews ~
antsDiscreteIsingS.NewModel > name Model  > h 0.0 > beta 0.2~
antsKernel.Define > name Sampler ~
antsKernel.AttachModel > sampler Sampler > model Model ~
antsKernel.AttachArray > sampler Sampler > array testarray ~
antsMC.New chain ~
antsMC.Add chain Sampler ~
antsArrayObjects.Copy testarray testarray2   ~
antsArrayPictures.New testpict2 testarray2 ~
Voyager.Show testpict2 as antsPictureViews ~
antsKernel.Define > name Sampler2 ~
antsKernel.AttachModel > sampler Sampler2 > model Model ~
antsKernel.AttachArray > sampler Sampler2 > array testarray2 ~
antsMC.Add chain Sampler2 ~
antsMC.ApplyConstInit chain Sampler const = 0 max = 1 ~
antsMC.ApplyConstInit chain Sampler2 const = 1 max = 1 ~
~
fofAutomatic.Do
System.Time
antsMC.Forward chain  1 10 ~
System.Time ~
~

