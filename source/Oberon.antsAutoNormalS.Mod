MODULE antsAutoNormalS IN Oberon;   (** fof  **)
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



IMPORT antsObjects, Objects, Files, Gadgets, antsNeighbourhoods, antsRegions, vyRandom, aM := antsMessages,
	antsArrayObjects, antsKernel, antsModels, antsCommands, vyName, vyBase, Links, antsSecurity;

TYPE
	intArray = POINTER TO ARRAY OF SIGNED16;

	tModel* = POINTER TO tModelDesc;
	tModelDesc* = RECORD (antsModels.tModelDesc);
		dim-: SIGNED32;
		mu, sigmasq: FLOAT64;
		n*: antsNeighbourhoods.Neighbours;
		current: intArray (* to cache neighbours, temp! *)
	END;
VAR

	PROCEDURE StoreM( VAR R: Files.Rider;  s: tModel );
	BEGIN
		Files.WriteInt( R, 0 );  Files.WriteLInt( R, s.dim );  Gadgets.WriteRef( R, s.lib, s.n );  Files.WriteLReal( R, s.mu );
		Files.WriteLReal( R, s.sigmasq )
	END StoreM;

	PROCEDURE LoadM( VAR R: Files.Rider;  s: tModel );
	VAR objsub: Objects.Object;  version: SIGNED16;
	BEGIN
		Files.ReadInt( R, version );  Files.ReadLInt( R, s.dim );  Gadgets.ReadRef( R, s.lib, objsub );
		IF objsub # NIL THEN s.n := objsub( antsNeighbourhoods.Neighbours ) END;
		Files.ReadLReal( R, s.mu );  Files.ReadLReal( R, s.sigmasq )
	END LoadM;

	PROCEDURE MakeCaches( m: tModel );
	BEGIN
		IF (m.current = NIL ) OR (LEN( m.current ) < m.n.clen + 1) THEN NEW( m.current, m.n.clen + 1 ) END  (* +1 corresponds to data term *)
	END MakeCaches;

	(* Potential Function U : *)
(* values: Values in neighbourhood, v[0] is central pixel *)



	PROCEDURE Sync( m: tModel;  depth: SIGNED32 );
	BEGIN
		m.synced := TRUE
	END Sync;

	PROCEDURE OneSweep*( s: antsKernel.Kernel;  visit: antsKernel.visitingScheme );
	VAR A, Orig: antsArrayObjects.tINTEGERObject;  AA: antsArrayObjects.tINTEGERArray;  model: tModel;  dim, x, y, w, h: SIGNED32;
		x0, y0, w0, h0: SIGNED32;  orig: Objects.Object;  count: SIGNED16;  nb: intArray;  cooling: FLOAT64;  max: SIGNED16;  nclen: SIGNED32;
		cx, cy: antsNeighbourhoods.Index;  i: SIGNED32;  pars: antsNeighbourhoods.pars;  theta: FLOAT64;  position, posi: SIGNED32;  mu, sigmasq: FLOAT64;
	BEGIN
		A := s.A( antsArrayObjects.tINTEGERObject );  AA := A.A;  w := A.w;  h := A.h;  model := s.par( tModel );
		antsRegions.Get( model.region, A, x0, y0, w0, h0 );   (* DEC(w0);    DEC(h0);   w0 := w0+x0; h0 := h0+y0;  *)
		Links.GetLink( A, "orig", orig );
		IF orig # NIL THEN Orig := orig( antsArrayObjects.tINTEGERObject ) ELSE Orig := NIL END;
		MakeCaches( model );

		IF (model.n.dim - 1 # model.dim) THEN model.dim := model.n.dim - 1;  model.synced := FALSE
		END;
		IF ~model.synced THEN Sync( model, A.depth ) END;
		dim := model.dim;

		mu := model.mu;  sigmasq := model.sigmasq;  nb := model.current;  cooling := model.coolingTemp;
		max := SHORT( A.depth - 1 );  nclen := model.n.clen - 1;  cx := model.n.cx;  cy := model.n.cy;  pars := model.n.cpar;

		FOR posi := 0 TO w0 * h0 - 1 DO
			position := visit( posi, w0 * h0 );  y := position DIV w0 + y0;  x := position MOD w0 + x0;

			(* this would typically be an INLINE procedure *)
			(* ---------- begin local -----------*)
			(* GetNeighbourValues(A,Orig,model.n,y,x,nb^);*)
			FOR i := 0 TO nclen DO nb[i] := AA[(y + cy[i]) MOD h, (x + cx[i]) MOD w] END;
			(*  end GetNeighbourValues *)

			theta := mu;
			FOR i := 1 TO nclen DO theta := theta + 2 * pars[i] * (nb[i] / (A.depth - 1) - mu) END;

			theta := theta + vyRandom.Gauss( 0, sigmasq );

			count := SHORT( ENTIER( theta * (A.depth - 1) + 0.5 ) );
			IF count >= A.depth THEN count := SHORT( A.depth - 1 )
			ELSIF count < 0 THEN count := 0
			END;

			AA[y, x] := count
			(* ---------- end local -----------*)
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
					antsModels.SetTemperature( o, M.temp );
					antsModels.SetMaxCache( o, M.dlink( antsKernel.Kernel ).cacheSize );
					IF M.action = antsKernel.gibbsSampler THEN
						OneSweep( M.dlink( antsKernel.Kernel ), M.dlink( antsKernel.Kernel ).visit )
					ELSE antsSecurity.Halt( "AutoNormal: Sorry, only Gibbs Sampler implemented, change Kernel!" )
					END;
				END;
			ELSIF M IS antsKernel.Init THEN
				WITH M: antsKernel.Init DO Uniform( M.dlink( antsKernel.Kernel ) );  o.synced := FALSE;
				END;
			ELSIF M IS Objects.AttrMsg THEN
				WITH M: Objects.AttrMsg DO
					IF M.id = Objects.enum THEN M.Enum( "Gen" );  M.Enum( "dim" );  M.Enum( "mu" );  M.Enum( "sigmasq" );  antsModels.Handler( o, M )
					ELSIF M.id = Objects.get THEN
						IF M.name = "Gen" THEN COPY( 'antsAutoNormalS.Gen', M.s );  M.class := Objects.String;  M.res := 0;  RETURN
						ELSIF M.name = "dim" THEN M.i := o.dim;  M.class := Objects.Int;  M.res := 0
						ELSIF M.name = "mu" THEN M.y := o.mu;  M.class := Objects.LongReal;  M.res := 0
						ELSIF M.name = "sigmasq" THEN M.y := o.sigmasq;  M.class := Objects.LongReal;  M.res := 0

						ELSE antsModels.Handler( o, M )
						END

					ELSIF M.id = Objects.set THEN
						IF M.name = "mu" THEN
							IF M.class = Objects.LongReal THEN o.mu := M.y;  M.res := 0;  Gadgets.Update( o ) END
						ELSIF M.name = "sigmasq" THEN
							IF M.class = Objects.LongReal THEN o.sigmasq := M.y;  M.res := 0;  Gadgets.Update( o ) END
						ELSE antsModels.Handler( o, M )
						END
					ELSE antsModels.Handler( o, M )
					END;
				END;
			ELSIF M IS Objects.LinkMsg THEN
				WITH M: Objects.LinkMsg DO
					IF M.id = Objects.enum THEN M.Enum( "distfunction" );  M.Enum( "weights" );  M.Enum( "datafunction" );  antsModels.Handler( o, M )
					ELSIF M.id = Objects.get THEN
						IF M.name = "weights" THEN M.obj := o.n;  M.res := 0;  RETURN

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
						vyBase.objecthandle( o, M );  Gadgets.BindObj( o.n, M.lib );
						IF o.n # NIL THEN
							IF o.n.handle # NIL THEN o.n.handle( o.n, M ) END
						END
					END
				END;
			ELSE antsModels.Handler( o, M )
			END
		END  (* tVector*)
	END Handler;

	PROCEDURE OpenModel*( M: tModel;  n: antsNeighbourhoods.Neighbours;  name: ARRAY OF CHAR );
	BEGIN
		M.dim := n.dim - 1;  M.n := n;  vyName.RegisterNamed( M, name );  M.handle := Handler;

		vyBase.Subscribe( M.n, M );  antsModels.Open( M )

	END OpenModel;

	PROCEDURE Gen*;
	VAR m: tModel;
	BEGIN
		aM.cmd;  NEW( m );  m.handle := Handler;  Objects.NewObj := m;  m.synced := FALSE;  antsObjects.Register( m )
	END Gen;

	PROCEDURE NewModel*;
	VAR l: antsCommands.tScanList;  name: vyName.tNameArray;  M: tModel;  obj: vyBase.Object;
		n: antsNeighbourhoods.Neighbours;
	BEGIN
		l := antsCommands.ScanFromPar( "name=NAME par=OBJ" );
		IF antsCommands.ExpectNameFromKeyword( l, "name", name ) & antsCommands.ExpectObjectFromKeyword( l, "par", obj ) THEN
			n := obj( antsNeighbourhoods.Neighbours );  Gen;  M := Objects.NewObj( tModel );  OpenModel( M, n, name )
		END
	END NewModel;

BEGIN
	aM.launch;
END antsAutoNormalS.

System.Free antsAutoNormalS ~

antsObjects.WriteAttributes Model cooling ~
antsObjects.WriteAttributes testarray ~

antsObjects.WriteAttributes Model ~



fofAutomatic.Do
antsArrayObjects.New testarray 100 100 30000 ~
antsArrayPictures16.New testpict testarray ~
Voyager.Show testpict as antsPictureViews ~
antsNeighbourhoods.New > name parameter > size 5 > nonisotropic ~
antsInteractivePar.Show > name parameter    ~
antsObjects.SetAttribute LAYER max 0.4~
antsObjects.WriteAttributes parameter ~
antsAutoNormalS.NewModel > name Model > par parameter  > function testf  ~
antsKernel.Define > name Sampler ~
antsKernel.AttachModel > sampler Sampler > model Model ~
antsKernel.AttachArray > sampler Sampler > array testarray ~
antsMC.New chain ~
antsMC.Add chain Sampler ~
~

antsMC.Init chain ~

fofAutomatic.Do > interactive > secure
antsMC.Forward chain  1 1 ~
~
Optimizing history: (8sec) = > (6sec)
(* PROCEDURE U (y, x, val: SIGNED32): FLOAT64;
BEGIN
theta := 0;
FOR i := 0 TO M.dim DO
k := i;
FOR j := 0 TO M.n.count[i] - 1 DO
IF k = 0 THEN
(* theta := theta - o.depth* par[k]*)
ELSE
theta := theta - o.depth * M.n.par[k] * f.get(f, o.A[(y + M.n.y[i, j]) MOD o.h, (x + M.n.x[i, j]) MOD o.w] - val)
(* torus *)
END
END
END;
RETURN theta
END U;
*)
(*PROCEDURE Local (o: antsArrayObjects.tObject;   dim: SIGNED32;   par: array;    x, y: SIGNED32;   M: tModel;
s: antsKernel.Kernel);
VAR theta: FLOAT64;   k: SIGNED32;   f: antsFunctions.Function;   ran, u, z: FLOAT64;   count: SIGNED16;

PROCEDURE U (y, x, val: SIGNED32): FLOAT64;
VAR i: SIGNED32;
BEGIN
theta := 0;
FOR i := 1 TO M.n.clen-1 DO
theta := theta - o.depth * M.n.cpar[i] *
M.fcache[ABS(o.A[(y + M.n.cy[i]) MOD o.h, (x + M.n.cx[i]) MOD o.w] - val)]
END;
RETURN theta
END U;

PROCEDURE Penalize (y, x, val: SIGNED32): FLOAT64;
BEGIN
IF s.Aorig # NIL THEN
RETURN - par[0] * o.depth * (val - s.Aorig(antsArrayObjects.tObject).A[y, x]) * (val - s.Aorig(antsArrayObjects.tObject).A[y, x])
ELSE RETURN 0 END
END Penalize;



BEGIN

f := M.f;   z := 0;
FOR count := 0 TO SHORT(o.depth - 1) DO
z := z + Math.exp(M.coolingTemp * (U(y, x, count) + Penalize(y, x, count)))
END;
ran := antsRandom.GetU();
u := 0;   count := 0;   u := Math.exp(M.coolingTemp * (U(y, x, count) + Penalize(y, x, count))) / z;
WHILE ran > u DO
INC(count);
u := u + Math.exp(M.coolingTemp * (U(y, x, count) + Penalize(y, x, count))) / z
END;

o.A[(y) MOD o.h, (x) MOD o.w] := count
END Local;
*)
