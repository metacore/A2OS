MODULE antsMDimMDiscreteIsingS IN Oberon;   (** fof  **)
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



IMPORT antsObjects, antsMatrixPar, Objects, Files, Gadgets, antsNeighbourhoods, vyRectangles, aM := antsMessages,
	antsArrayObjects, Math := MathL IN A2, antsKernel, antsModels, antsCommands, vyName, vyBase, vyRanBase;

TYPE
	array = antsNeighbourhoods.pars;

	tModel* = POINTER TO tModelDesc;
	tModelDesc* = RECORD (antsModels.tModelDesc);
		dim-: SIGNED32;
		n*: antsNeighbourhoods.Neighbours;
		f: antsMatrixPar.Matrix;
		l: antsMatrixPar.Matrix;
		synchroneus: BOOLEAN
	END;

	PROCEDURE StoreM( VAR R: Files.Rider;  s: tModel );
	BEGIN
		Files.WriteInt( R, 1 );  Files.WriteLInt( R, s.dim );  Gadgets.WriteRef( R, s.lib, s.n );  Gadgets.WriteRef( R, s.lib, s.f );
		Gadgets.WriteRef( R, s.lib, s.l )
	END StoreM;

	PROCEDURE LoadM( VAR R: Files.Rider;  s: tModel );
	VAR objsub: Objects.Object;  version: SIGNED16;
	BEGIN
		Files.ReadInt( R, version );  Files.ReadLInt( R, s.dim );  Gadgets.ReadRef( R, s.lib, objsub );
		IF objsub # NIL THEN s.n := objsub( antsNeighbourhoods.Neighbours ) END;
		Gadgets.ReadRef( R, s.lib, objsub );
		IF objsub # NIL THEN s.f := objsub( antsMatrixPar.Matrix ) END;
		IF version > 0 THEN
			Gadgets.ReadRef( R, s.lib, objsub );
			IF objsub # NIL THEN s.f := objsub( antsMatrixPar.Matrix ) END
		ELSE s.l := antsMatrixPar.DoNew( 1, 1 )
		END
	END LoadM;


(*! implement cache, general: speed up *)

	PROCEDURE Local( o, c: antsArrayObjects.tINTEGERObject;  dim: SIGNED32;  par: array;  x, y: SIGNED32;  M: tModel;  s: antsKernel.Kernel );
	VAR theta: FLOAT64;  f: antsMatrixPar.Matrix;  ran, u, z: FLOAT64;  count: SIGNED16;

		PROCEDURE U( y, x, val: SIGNED32 ): FLOAT64;
		VAR i: SIGNED32;
		BEGIN
			theta := 0;
			FOR i := 1 TO M.n.clen - 1 DO
				theta := theta - o.depth * M.n.cpar[i] * M.f.par[val, o.A[(y + M.n.cy[i]) MOD o.h, (x + M.n.cx[i]) MOD o.w]]
			END;
			theta := theta - o.depth * M.n.cpar[0] * M.l.par[val, 0];  RETURN theta
		END U;

	(*
PROCEDURE Penalize (y, x, val: SIGNED32): FLOAT64;
BEGIN
IF s.Aorig # NIL THEN
RETURN - par[0] * o.depth * (val - s.Aorig(antsArrayObjects.tObject).A[y, x]) * (val - s.Aorig(antsArrayObjects.tObject).A[y, x])
ELSE RETURN 0 END
END Penalize;
*)


	BEGIN

		f := M.f;  z := 0;
		FOR count := 0 TO SHORT( o.depth - 1 ) DO z := z + Math.exp( M.coolingTemp * (U( y, x, count ) (* + Penalize(y, x, count) *) ) ) END;
		ran := vyRanBase.RandomU();  u := 0;  count := 0;
		u := Math.exp( M.coolingTemp * (U( y, x, count ) (* + Penalize(y, x, count) *) ) ) / z;
		WHILE ran > u DO INC( count );  u := u + Math.exp( M.coolingTemp * (U( y, x, count ) (* + Penalize(y, x, count)*) ) ) / z END;

		c.A[(y) MOD o.h, (x) MOD o.w] := count
	END Local;

	PROCEDURE Sync( m: tModel;  depth: SIGNED32 );
	BEGIN
		IF (m.f.dimx # depth) OR (m.f.dimy # depth) THEN antsMatrixPar.ChangeDim( m.f, SHORT( depth ), SHORT( depth ) ) END;
		IF (m.l.dimy # depth) OR (m.l.dimx # 1) THEN antsMatrixPar.ChangeDim( m.l, SHORT( depth ), 1 ) END
	END Sync;

	PROCEDURE OneSweep*( s: antsKernel.Kernel );
	VAR A, Cache: antsArrayObjects.tINTEGERObject;  par: array;  model: tModel;  dim, x, y: SIGNED32;  x0, y0, w0, h0: SIGNED16;

	BEGIN
		A := s.A( antsArrayObjects.tINTEGERObject );  model := s.par( tModel );  x0 := 0;  y0 := 0;  w0 := SHORT( A.w - 1 );
		h0 := SHORT( A.h - 1 );
		IF model.region # NIL THEN
			vyRectangles.RectIntersection( x0, y0, w0, h0, model.region.x, model.region.y, model.region.w - 1,
															   model.region.h - 1 )
		END;
		par := model.n.par;
		IF (model.n.dim - 1 # model.dim) THEN
			model.dim := model.n.dim - 1;  model.synced := FALSE
			(* insert sync here when optimized*) END;
		IF (model.MCache # NIL ) & (model.MCache.len[0] # A.depth) THEN model.synced := FALSE END;
		IF ~model.synced THEN Sync( model, A.depth ) END;
		dim := model.dim;
		IF model.synchroneus THEN Cache := antsArrayObjects.NewINTEGERObject( A.w, A.h, A.depth ) ELSE Cache := A END;
		IF (model.MCache = NIL ) THEN
			FOR y := y0 TO y0 + h0 DO
				FOR x := x0 TO x0 + w0 DO
					Local( A, Cache, dim, par, x, y, model, s );
					IF model.hotupdate THEN vyBase.Update( A ) END
				END
			END
		ELSE
			(*
		FOR y := y0 TO y0+h0 DO
		FOR x := x0 TO x0+w0 DO
		CLocal(A, Cache, dim, par, x, y, model, s)
		END
		END;
		*)
		END;
		IF model.synchroneus THEN
			FOR y := y0 TO y0 + h0 DO
				FOR x := x0 TO x0 + w0 DO A.A[y, x] := Cache.A[y, x] END
			END

		END
	END OneSweep;

	PROCEDURE Uniform*( s: antsKernel.Kernel );
	BEGIN
		antsArrayObjects.UniformO( s.A( antsArrayObjects.tObject ) )
	END Uniform;

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
					IF M.id = Objects.enum THEN M.Enum( "Gen" );  M.Enum( "dim" );  M.Enum( "synchroneus" );  antsModels.Handler( o, M )
					ELSIF M.id = Objects.get THEN
						IF M.name = "Gen" THEN COPY( 'antsMDimMDiscreteIsingS.Gen', M.s );  M.class := Objects.String;  M.res := 0;  RETURN
						ELSIF M.name = "dim" THEN M.i := o.dim;  M.class := Objects.Int;  M.res := 0
						ELSIF M.name = "synchroneus" THEN M.b := o.synchroneus;  M.class := Objects.Bool;  M.res := 0
						ELSE antsModels.Handler( o, M )
						END
					ELSIF M.id = Objects.set THEN
						IF M.name = "synchroneus" THEN
							IF M.class = Objects.Bool THEN o.synchroneus := M.b;  M.res := 0 END
						ELSE antsModels.Handler( o, M )
						END
					ELSE antsModels.Handler( o, M )
					END;
				END;
			ELSIF M IS Objects.LinkMsg THEN
				WITH M: Objects.LinkMsg DO
					IF M.id = Objects.enum THEN M.Enum( "dist" );  M.Enum( "weights" );  antsModels.Handler( o, M )
					ELSIF M.id = Objects.get THEN
						IF M.name = "weights" THEN M.obj := o.n;  M.res := 0;  RETURN
						ELSIF M.name = "dist" THEN M.obj := o.f;  M.res := 0;  RETURN
						ELSE antsModels.Handler( o, M )
						END
					ELSE antsModels.Handler( o, M )
					END;
				END;
			ELSIF M IS Objects.FileMsg THEN
				WITH M: Objects.FileMsg DO
					IF M.id = Objects.load THEN antsModels.Handler( o, M );  LoadM( M.R, o );  o.synced := FALSE
					ELSIF M.id = Objects.store THEN antsModels.Handler( o, M );  StoreM( M.R, o )
					END;
				END;
			ELSIF M IS Objects.BindMsg THEN
				WITH M: Objects.BindMsg DO
					IF M.lib # o.lib THEN
						vyBase.objecthandle( o, M );  Gadgets.BindObj( o.f, M.lib );
						IF o.f # NIL THEN
							IF o.f.handle # NIL THEN o.f.handle( o.f, M ) END
						END;
						Gadgets.BindObj( o.n, M.lib );
						IF o.n # NIL THEN
							IF o.n.handle # NIL THEN o.n.handle( o.n, M ) END
						END
					END
				END;
			ELSE antsModels.Handler( o, M )
			END
		END  (* tVector*)
	END Handler;

	PROCEDURE OpenModel*( M: tModel;  n: antsNeighbourhoods.Neighbours;  f, l: antsMatrixPar.Matrix;  name: ARRAY OF CHAR );
	BEGIN
		M.dim := n.dim - 1;  M.n := n;  vyName.RegisterNamed( M, name );  M.handle := Handler;  M.f := f;  M.l := l;
		vyBase.Subscribe( f, M );  vyBase.Subscribe( l, M );

		vyBase.Subscribe( M.n, M );  antsModels.Open( M )

	END OpenModel;

	PROCEDURE Gen*;
	VAR m: tModel;
	BEGIN
		aM.cmd;  NEW( m );  m.handle := Handler;  Objects.NewObj := m;  m.synced := FALSE;  m.synchroneus := FALSE;
		antsObjects.Register( m )
	END Gen;

	PROCEDURE NewModel*;
	VAR l: antsCommands.tScanList;  name: vyName.tNameArray;  M: tModel;  obj: vyBase.Object;  f, l1: vyBase.Object;
		n: antsNeighbourhoods.Neighbours;
	BEGIN
		l := antsCommands.ScanFromPar( "name=NAME par=OBJ paired=OBJ single=OBJ" );
		IF antsCommands.ExpectNameFromKeyword( l, "name", name ) & antsCommands.ExpectObjectFromKeyword( l, "par", obj ) &
		    antsCommands.ExpectObjectFromKeyword( l, "paired", f ) & antsCommands.ExpectObjectFromKeyword( l, "single", l1 ) THEN

			n := obj( antsNeighbourhoods.Neighbours );  Gen;  M := Objects.NewObj( tModel );
			OpenModel( M, n, f( antsMatrixPar.Matrix ), l1( antsMatrixPar.Matrix ), name )
		END
	END NewModel;

BEGIN
	aM.launch;
END antsMDimMDiscreteIsingS.

System.Free antsMDimMDiscreteIsingS ~

fofAutomatic.Do
antsArrayObjects.New testarray 100 100 3  ~
antsArrayPictures.New testpict testarray ~
Voyager.Show testpict as antsPictureViews ~
antsMatrixPar.New testmatrix ~
antsMatrixPar.New testmatrix2 ~
antsNeighbourhoods.New > name parameter > size 2 > isotropic ~
antsInteractivePar.Show > name parameter    ~
antsMatrixParView.Show > name testmatrix   ~
antsMatrixParView.Show > name testmatrix2   ~
antsMDimMDiscreteIsingS.NewModel > name Model > par parameter  > paired testmatrix > single testmatrix2 ~
antsKernel.Define > name Sampler ~
antsKernel.AttachModel > sampler Sampler > model Model ~
antsKernel.AttachArray > sampler Sampler > array testarray ~
antsMC.New chain ~
antsMC.Add chain Sampler ~
~
fofAutomatic.Do > interactive
antsMC.Forward chain  1 1 ~
~
antsMC.Init chain ~

~
Optimizing history: (8sec) = > (6sec)

antsObjects.WriteAttributes testmatrix ~
antsObjects.WriteAttributes parameter ~
antsObjects.WriteAttributes Model ~

