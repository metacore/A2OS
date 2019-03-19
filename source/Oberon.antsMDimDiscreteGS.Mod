MODULE antsMDimDiscreteGS IN Oberon;   (** fof  **)
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



IMPORT antsObjects, antsFunctions, Objects, Files, Gadgets, antsNeighbourhoods, antsRegions, antsArrayObjects,
	Math := MathL IN A2, antsKernel, antsModels, antsCommands, vyName, vyBase, antsCaches, vyRanBase, Links, antsGlobals, aM := antsMessages;

TYPE
	intArray = POINTER TO ARRAY OF INTEGER;
	realArray = POINTER TO ARRAY OF LONGREAL;

	tModel* = POINTER TO tModelDesc;
	tModelDesc* = RECORD (antsModels.tModelDesc);
		dim-: LONGINT;
		n*: antsNeighbourhoods.Neighbours;
		interactionF: antsFunctions.FunctionXd;
		current: realArray;   (* to cache neighbours, temp! *)
		currentR: realArray (* to cache energy, temp! *)
	END;

	PROCEDURE StoreM( VAR R: Files.Rider;  s: tModel );
	BEGIN
		Files.WriteInt( R, 0 );  Files.WriteLInt( R, s.dim );  Gadgets.WriteRef( R, s.lib, s.n );
		Gadgets.WriteRef( R, s.lib, s.interactionF )
	END StoreM;

	PROCEDURE LoadM( VAR R: Files.Rider;  s: tModel );
	VAR objsub: Objects.Object;  version: INTEGER;
	BEGIN
		Files.ReadInt( R, version );  Files.ReadLInt( R, s.dim );  Gadgets.ReadRef( R, s.lib, objsub );
		IF objsub # NIL THEN s.n := objsub( antsNeighbourhoods.Neighbours ) END;
		Gadgets.ReadRef( R, s.lib, objsub );
		IF objsub # NIL THEN s.interactionF := objsub( antsFunctions.FunctionXd ) END
	END LoadM;

	PROCEDURE U( VAR values: ARRAY OF LONGREAL;  M: tModel ): LONGREAL;
	VAR theta: LONGREAL;
	BEGIN
		antsGlobals.globalParameters := M.n.cpar;  theta := -M.interactionF.get( M.interactionF, values );  RETURN theta
	END U;

	PROCEDURE GetNeighbourValues( o, orig: antsArrayObjects.tINTEGERObject;  n: antsNeighbourhoods.Neighbours;  y, x: LONGINT;
														  VAR values: ARRAY OF LONGREAL );
	VAR i: LONGINT;
	BEGIN
		FOR i := 0 TO n.clen - 1 DO values[i] := o.A[(y + n.cy[i]) MOD o.h, (x + n.cx[i]) MOD o.w] END;
		IF orig # NIL THEN values[i] := orig.A[y, x] END
	END GetNeighbourValues;

	PROCEDURE MakeCaches( m: tModel;  depth: LONGINT;  data: BOOLEAN );
	BEGIN
		IF (m.currentR = NIL ) OR (LEN( m.currentR ) < depth) THEN NEW( m.currentR, depth ) END;
		IF (m.current = NIL ) OR (LEN( m.current ) < m.n.clen + 1) THEN NEW( m.current, m.n.clen + 1 ) END  (* +1 corresponds to data term *)
	END MakeCaches;

	PROCEDURE Sync( m: tModel;  depth: LONGINT );
	VAR i: INTEGER;  c: antsCaches.FullCache;
		cv: POINTER TO ARRAY OF INTEGER;
		cvr: POINTER TO ARRAY OF LONGREAL;
		offset: LONGINT;  s: LONGREAL;
	BEGIN

		IF m.n.clen = 1 THEN m.MCache := NIL;  RETURN
		END;   (* bugfix for 1dim cache, doesnot work ! *)

		m.MCache := antsCaches.Cube( m.n.clen, SHORT( depth ), m.maxCacheSize );   (*  020319 *)

		IF m.MCache # NIL THEN
			c := m.MCache;
			NEW( cv, c.d );   (* m.n.clen+1);   (* +1 020319 *) *)
			NEW( cvr, c.d );  offset := -1;
			WHILE (c.NextPoint( offset, cv^, 1 )) DO
				FOR i := 0 TO SHORT( c.d - 1 ) DO cvr[i] := cv[i] END;
				s := 0;
				(* write values of exp(..) to array *)
				i := 0;
				WHILE (i < depth) DO
					cv[0] := i;  cvr[0] := i;  s := s + Math.exp( m.coolingTemp * U( cvr^, m ) );  c.values[i + offset] := s;  INC( i )
				END;
				cv[0] := 0;
				(* divide by normalizing constant *)
				i := 0;
				WHILE (i < depth) DO c.values[offset + i] := c.values[offset + i] / s;  INC( i ) END
			END
		END
	END Sync;

	PROCEDURE OneSweep*( M: antsKernel.samplingMsg );
	VAR A, Orig: antsArrayObjects.tINTEGERObject;  model: tModel;  dim, x, y, w, h: LONGINT;  x0, y0, w0, h0: LONGINT;  orig: Objects.Object;
		count: INTEGER;  uv: realArray;  nb: realArray;  z, cooling, ran: LONGREAL;  max: INTEGER;  cpos, nclen: LONGINT;  cache: antsCaches.FullCache;
		cx, cy: antsNeighbourhoods.Index;  i: LONGINT;  pars: antsNeighbourhoods.pars;  theta: LONGREAL;  position, posi: LONGINT;  s: antsKernel.Kernel;
		visit: antsKernel.visitingScheme;  parallel: BOOLEAN;  destA, srcA: antsArrayObjects.tINTEGERArray;  nbi: intArray;
	BEGIN
		s := M.dlink( antsKernel.Kernel );  visit := s.visit;  parallel := s.parallel;

		A := s.A( antsArrayObjects.tINTEGERObject );  srcA := A.A;  w := A.w;  h := A.h;  model := s.par( tModel );
		antsModels.SetMaxCache( model, s.cacheSize );
		antsRegions.Get( model.region, A, x0, y0, w0, h0 );   (* DEC(w0);    DEC(h0);   w0 := w0+x0; h0 := h0+y0;  *)
		Links.GetLink( A, "orig", orig );
		IF orig # NIL THEN Orig := orig( antsArrayObjects.tINTEGERObject ) ELSE Orig := NIL END;
		MakeCaches( model, A.depth, Orig # NIL );

		IF (model.n.dim - 1 # model.dim) THEN model.dim := model.n.dim - 1;  model.synced := FALSE
		END;
		IF (model.MCache # NIL ) & (model.MCache.len[0] # A.depth) THEN model.synced := FALSE END;
		IF ~model.synced THEN Sync( model, A.depth ) END;
		dim := model.dim;
		IF parallel THEN destA := antsArrayObjects.NewINTEGERArray( A.w, A.h ) ELSE destA := srcA END;

		uv := model.currentR;  nb := model.current;  cooling := model.coolingTemp;  max := SHORT( A.depth - 1 );
		nclen := model.n.clen - 1;  cx := model.n.cx;  cy := model.n.cy;  pars := model.n.cpar;

		cache := model.MCache;

		IF (cache = NIL ) THEN
			FOR posi := 0 TO w0 * h0 - 1 DO
				position := visit( posi, w0 * h0 );  y := position DIV w0 + y0;  x := position MOD w0 + x0;

				FOR i := 0 TO nclen DO nb[i] := srcA[(y + cy[i]) MOD h, (x + cx[i]) MOD w] END;
				IF Orig # NIL THEN nb[i] := Orig.A[y, x] END;

				z := 0;
				FOR count := 0 TO max DO
					nb[0] := count;  theta := U( nb^, model );  z := z + Math.exp( cooling * theta );  uv[count] := z
				END;

				ran := vyRanBase.RandomU() * z;  count := 0;
				WHILE ran > uv[count] DO INC( count ) END;
				destA[y, x] := count;
				(* ---------- end local -----------*)
				(*
			END
			END;
			*)
			END;
		ELSE
			NEW( nbi, LEN( nb ) );
			FOR posi := 0 TO w0 * h0 - 1 DO
				position := visit( posi, w0 * h0 );  y := position DIV w0 + y0;  x := position MOD w0 + x0;
				(*
			FOR y := y0 TO h0 DO
			FOR x := x0 TO w0 DO
			*)
				(* this would typically be an INLINE procedure *)
				(* ---------- begin clocal ---------*)
				(*
			GetNeighbourValues(A,Orig,model.n,y,x,nb^);
			*)
				FOR i := 0 TO nclen DO nbi[i] := srcA[(y + cy[i]) MOD h, (x + cx[i]) MOD w] END;
				IF Orig # NIL THEN nbi[i] := Orig.A[y, x] END;

				nbi[0] := 0;  ran := vyRanBase.RandomU();  count := 0;  cpos := cache.Offset( nbi^, 1 );
				WHILE ran > cache.values[cpos] DO INC( count );  INC( cpos ) END;
				destA[y, x] := count;
				(* ---------- end clocal -----------*)
				(*
			END
			END;
			*)
			END;
		END;
		IF parallel THEN
			FOR y := y0 TO y0 + h0 - 1 DO
				FOR x := x0 TO x0 + w0 - 1 DO srcA[y, x] := destA[y, x] END
			END
		END;
	END OneSweep;

	PROCEDURE Metropolis( msg: antsKernel.samplingMsg );
	VAR A, Ao: antsArrayObjects.tINTEGERObject;  model: tModel;  dim: LONGINT;  x0, y0, w0, h0: LONGINT;  zvax, zvay, zva: LONGINT;  M: tModel;
		gen: vyRanBase.tRandom;  h, h1, h2, cooling: LONGREAL;  AA: antsArrayObjects.tINTEGERArray;  W, H, depth: LONGINT;
		orig: antsArrayObjects.tINTEGERObject;  obj: Objects.Object;  cv: realArray;  posi, position: LONGINT;

		s: antsKernel.Kernel;  visit: antsKernel.visitingScheme;  parallel: BOOLEAN;
	BEGIN
		s := msg.dlink( antsKernel.Kernel );  visit := s.visit;  parallel := s.parallel;

		A := s.A( antsArrayObjects.tINTEGERObject );  W := A.w;  H := A.h;  depth := A.depth;  Links.GetLink( A, "orig", obj );
		IF obj # NIL THEN orig := obj( antsArrayObjects.tINTEGERObject ) ELSE orig := NIL END;

		Ao := orig;  AA := A.A;
		(* AAo := Ao.A;           *)

		model := s.par( tModel );

		MakeCaches( model, A.depth, orig # NIL );

		M := model;  gen := vyRanBase.RandomGenerator;

		IF (model.n.dim - 1 # model.dim) THEN model.dim := model.n.dim - 1;  model.synced := FALSE
		END;
		IF ~model.synced THEN  (* Sync1(model) *) model.synced := TRUE END;

		cooling := model.coolingTemp;  dim := model.dim;
		antsRegions.Get( model.region, A, x0, y0, w0, h0 );   (* DEC(w0);    DEC(h0);   *)

		cv := M.current;

		(* FOR y := 0 TO w0*h0-1 DO *)

		FOR posi := 0 TO w0 * h0 - 1 DO
			position := visit( posi, w0 * h0 );  zvay := position DIV w0 + y0;  zvax := position MOD w0 + x0;

			zva := gen.GetRandomL( gen, A.depth );

			GetNeighbourValues( A, orig, M.n, zvay, zvax, cv^ );  h2 := U( cv^, model );  cv[0] := SHORT( zva );  h1 := U( cv^, model );

			h := cooling * (h1 - h2);

			IF h >= 0 THEN AA[zvay, zvax] := SHORT( zva )
			ELSE
				IF gen.GetRandomU( gen ) < Math.exp( h ) THEN AA[zvay, zvax] := SHORT( zva ) END
			END

		END

	END Metropolis;

	PROCEDURE Exchange( msg: antsKernel.samplingMsg );
	VAR A, Ao: antsArrayObjects.tINTEGERObject;  model: tModel;  dim: LONGINT;  x0, y0, w0, h0: LONGINT;  M: tModel;
		gen: vyRanBase.tRandom;  h, h1, h2, cooling: LONGREAL;  AA: antsArrayObjects.tINTEGERArray;  W, H, depth: LONGINT;
		orig: antsArrayObjects.tINTEGERObject;  obj: Objects.Object;  cv: realArray;  posi, position: LONGINT;
		zvax1, zvay1, zvax2, zvay2, zva1, zva2: LONGINT;  s: antsKernel.Kernel;  visit: antsKernel.visitingScheme;  parallel: BOOLEAN;
	BEGIN
		s := msg.dlink( antsKernel.Kernel );  visit := s.visit;  parallel := s.parallel;

		A := s.A( antsArrayObjects.tINTEGERObject );  W := A.w;  H := A.h;  depth := A.depth;  Links.GetLink( A, "orig", obj );
		IF obj # NIL THEN orig := obj( antsArrayObjects.tINTEGERObject ) ELSE orig := NIL END;

		Ao := orig;  AA := A.A;
		(* AAo := Ao.A;           *)

		model := s.par( tModel );

		MakeCaches( model, A.depth, orig # NIL );

		M := model;  gen := vyRanBase.RandomGenerator;

		IF (model.n.dim - 1 # model.dim) THEN model.dim := model.n.dim - 1;  model.synced := FALSE
		END;
		IF ~model.synced THEN  (* Sync1(model) *) model.synced := TRUE END;

		cooling := model.coolingTemp;  dim := model.dim;
		antsRegions.Get( model.region, A, x0, y0, w0, h0 );   (* DEC(w0);    DEC(h0);   *)

		cv := M.current;

		(* FOR y := 0 TO w0*h0-1 DO *)

		FOR posi := 0 TO w0 * h0 - 1 DO
			position := antsKernel.randomVisit( posi, w0 * h0 );  zvay1 := position DIV w0 + y0;  zvax1 := position MOD w0 + x0;
			position := antsKernel.randomVisit( posi, w0 * h0 );  zvay2 := position DIV w0 + y0;  zvax2 := position MOD w0 + x0;

			zva1 := AA[zvay1, zvax1];  zva2 := AA[zvay2, zvax2];

			GetNeighbourValues( A, orig, M.n, zvay1, zvax1, cv^ );  h2 := U( cv^, model );  cv[0] := SHORT( zva2 );
			h1 := U( cv^, model );

			GetNeighbourValues( A, orig, M.n, zvay2, zvax2, cv^ );  h2 := h2 + U( cv^, model );  cv[0] := SHORT( zva1 );
			h1 := h1 + U( cv^, model );

			h := cooling * (h1 - h2);

			IF h >= 0 THEN AA[zvay1, zvax1] := SHORT( zva2 );  AA[zvay2, zvax2] := SHORT( zva1 )
			ELSE
				IF gen.GetRandomU( gen ) < Math.exp( h ) THEN AA[zvay1, zvax1] := SHORT( zva2 );  AA[zvay2, zvax2] := SHORT( zva1 ) END
			END
		END

	END Exchange;

	PROCEDURE CopyOrig( s: antsKernel.Kernel );
	VAR A: antsArrayObjects.tINTEGERObject;  obj: Objects.Object;  orig: antsArrayObjects.tINTEGERObject;
	BEGIN
		A := s.A( antsArrayObjects.tINTEGERObject );  Links.GetLink( A, "orig", obj );
		IF obj # NIL THEN orig := obj( antsArrayObjects.tINTEGERObject ) ELSE orig := NIL END;
		IF orig = NIL THEN Uniform( s ) END;
		antsArrayObjects.CopyII( orig.A, A.A, 0, 0, A.w, A.h, 0, 0 )
	END CopyOrig;

	PROCEDURE Uniform*( s: antsKernel.Kernel );
	BEGIN
		antsArrayObjects.UniformO( s.A( antsArrayObjects.tObject ) )
	END Uniform;

	PROCEDURE Handler*( o: Objects.Object;  VAR msg: Objects.ObjMsg );
	BEGIN
		WITH o: tModel DO
			IF msg IS antsKernel.samplingMsg THEN
				WITH msg: antsKernel.samplingMsg DO
					antsModels.SetTemperature( o, msg.temp );
					IF msg.action = antsKernel.gibbsSampler THEN OneSweep( msg )
					ELSIF msg.action = antsKernel.metropolisSampler THEN Metropolis( msg )
					ELSIF msg.action = antsKernel.exchangeAlgorithm THEN Exchange( msg )
					END;
				END;
			ELSIF msg IS antsKernel.Init THEN
				WITH msg: antsKernel.Init DO
					IF msg.dlink( antsKernel.Kernel ).initwithorig THEN CopyOrig( msg.dlink( antsKernel.Kernel ) )
					ELSE Uniform( msg.dlink( antsKernel.Kernel ) )
					END;
					o.synced := FALSE;
				END;
			ELSIF msg IS Objects.AttrMsg THEN
				WITH msg: Objects.AttrMsg DO
					IF msg.id = Objects.enum THEN msg.Enum( "dim" );   (* msg.Enum("synchroneus");      *) antsModels.Handler( o, msg )
					ELSIF msg.id = Objects.get THEN
						IF msg.name = "Gen" THEN COPY( 'antsMDimDiscreteGS.Gen', msg.s );  msg.class := Objects.String;  msg.res := 0;  RETURN
						ELSIF msg.name = "dim" THEN
							msg.i := o.dim;  msg.class := Objects.Int;  msg.res := 0
							(* ELSIF msg.name = "synchroneus"THEN
					msg.b := o.synchroneus;           msg.class := Objects.Bool;           msg.res := 0;           *)
						ELSE antsModels.Handler( o, msg )
						END
					ELSIF msg.id = Objects.set THEN
						IF msg.name = "synchroneus" THEN
							(* IF msg.class= Objects.Bool THEN o.synchroneus := msg.b;           msg.res := 0;           END;     *)
						ELSE antsModels.Handler( o, msg )
						END
					ELSE antsModels.Handler( o, msg )
					END;
				END;
			ELSIF msg IS Objects.LinkMsg THEN
				WITH msg: Objects.LinkMsg DO
					IF msg.id = Objects.enum THEN msg.Enum( "distfunction" );  msg.Enum( "weights" );  msg.Enum( "interactionFunction" );  antsModels.Handler( o, msg )
					ELSIF msg.id = Objects.get THEN
						IF msg.name = "weights" THEN msg.obj := o.n;  msg.res := 0;  RETURN
						ELSIF msg.name = "interactionFunction" THEN msg.obj := o.interactionF;  msg.res := 0;  RETURN
						ELSE antsModels.Handler( o, msg )
						END
					ELSE antsModels.Handler( o, msg )
					END;
				END;
			ELSIF msg IS Objects.FileMsg THEN
				WITH msg: Objects.FileMsg DO
					IF msg.id = Objects.load THEN antsModels.Handler( o, msg );  LoadM( msg.R, o );  o.synced := FALSE
					ELSIF msg.id = Objects.store THEN antsModels.Handler( o, msg );  StoreM( msg.R, o )
					END;
				END;
			ELSIF msg IS Objects.BindMsg THEN
				WITH msg: Objects.BindMsg DO
					IF msg.lib # o.lib THEN
						vyBase.objecthandle( o, msg );  antsObjects.Bind( o.interactionF, msg );  antsObjects.Bind( o.n, msg )
					END
				END;
			ELSE antsModels.Handler( o, msg )
			END
		END  (* tVector*)
	END Handler;

	PROCEDURE OpenModel*( M: tModel;  n: antsNeighbourhoods.Neighbours;  if: antsFunctions.FunctionXd;
											   name: ARRAY OF CHAR );
	BEGIN
		M.dim := n.dim - 1;  M.n := n;  M.interactionF := if;  vyName.RegisterNamed( M, name );  M.handle := Handler;
		vyBase.Subscribe( if, M );  vyBase.Subscribe( M.n, M );  antsModels.Open( M )

	END OpenModel;

	PROCEDURE Gen*;
	VAR m: tModel;
	BEGIN
		aM.cmd;
		NEW( m );  m.handle := Handler;  Objects.NewObj := m;  m.synced := FALSE;   (* m.synchroneus := FALSE;          *)
		antsObjects.Register( m )
	END Gen;

	PROCEDURE NewModel*;
	VAR l: antsCommands.tScanList;  name: vyName.tNameArray;  M: tModel;  obj: vyBase.Object;  if: vyBase.Object;
		n: antsNeighbourhoods.Neighbours;
	BEGIN
		l := antsCommands.ScanFromPar( "name=NAME par=OBJ interactionFunction= OBJ" );
		IF antsCommands.ExpectNameFromKeyword( l, "name", name ) & antsCommands.ExpectObjectFromKeyword( l, "par", obj ) &
		    antsCommands.ExpectObjectFromKeyword( l, "interactionFunction", if ) THEN
			n := obj( antsNeighbourhoods.Neighbours );  Gen;  M := Objects.NewObj( tModel );
			OpenModel( M, n, if( antsFunctions.FunctionXd ), name )
		END
	END NewModel;

BEGIN
	aM.launch;
END antsMDimDiscreteGS.

System.Free antsMDimDiscreteGS ~

fofAutomatic.Do
antsArrayObjects.New testarray 100 100 32 ~
antsArrayPictures.New testpict testarray ~
Voyager.Show testpict as antsPictureViews ~
antsFunctions.DefineXd interactionFunction ~
antsFunctions.SetXd > name interactionFunction  > function  "ABS(X[0]-X[3])+ABS(X[0]-X[2])"~
antsNeighbourhoods.New > name parameter > size 5 > nonisotropic ~
antsInteractivePar.Show > name parameter    ~
antsObjects.WriteAttributes parameter ~
antsObjects.WriteAttributes interactionFunction ~
antsMDimDiscreteGS.NewModel  Model  parameter  interactionFunction  ~
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
ants / antsTemp.Mod


