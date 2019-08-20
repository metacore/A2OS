MODULE antsMDimDiscreteS IN Oberon;   (** fof  **)
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




IMPORT antsObjects, antsFunctions, Objects, Files, Gadgets, antsNeighbourhoods, antsRegions, aM := antsMessages,
	antsArrayObjects, Math := MathL IN A2, antsKernel, antsModels, antsCommands, vyName, vyBase, antsCaches, vyRanBase, Links;

TYPE
	intArray = POINTER TO ARRAY OF INTEGER;
	realArray = POINTER TO ARRAY OF LONGREAL;
	realArrayArray = POINTER TO ARRAY OF ARRAY OF LONGREAL;

	tModel* = POINTER TO tModelDesc;
	tModelDesc* = RECORD (antsModels.tModelDesc);
		dim-: LONGINT;
		n*: antsNeighbourhoods.Neighbours;
		externalF: antsFunctions.FunctionXd;
		interactionF: antsFunctions.FunctionXd;
		dataF: antsFunctions.FunctionXd;
		interactionFcache: realArrayArray;
		dataFcache: realArrayArray;
		externalFcache: realArray;
		current: intArray;   (* to cache neighbours, temp! *)
		currentR: realArray (* to cache energy, temp! *)
	END;

	PROCEDURE StoreM( VAR R: Files.Rider;  s: tModel );
	BEGIN
		Files.WriteInt( R, 0 );  Files.WriteLInt( R, s.dim );  Gadgets.WriteRef( R, s.lib, s.n );
		Gadgets.WriteRef( R, s.lib, s.externalF );  Gadgets.WriteRef( R, s.lib, s.interactionF );
		Gadgets.WriteRef( R, s.lib, s.dataF )
	END StoreM;

	PROCEDURE LoadM( VAR R: Files.Rider;  s: tModel );
	VAR objsub: Objects.Object;  version: INTEGER;
	BEGIN
		Files.ReadInt( R, version );  Files.ReadLInt( R, s.dim );  Gadgets.ReadRef( R, s.lib, objsub );
		IF objsub # NIL THEN s.n := objsub( antsNeighbourhoods.Neighbours ) END;
		Gadgets.ReadRef( R, s.lib, objsub );
		IF objsub # NIL THEN s.externalF := objsub( antsFunctions.FunctionXd ) END;
		Gadgets.ReadRef( R, s.lib, objsub );
		IF objsub # NIL THEN s.interactionF := objsub( antsFunctions.FunctionXd ) END;
		Gadgets.ReadRef( R, s.lib, objsub );
		IF objsub # NIL THEN s.dataF := objsub( antsFunctions.FunctionXd ) END
	END LoadM;

	PROCEDURE U( VAR values: ARRAY OF INTEGER;  M: tModel ): LONGREAL;
	VAR i: LONGINT;  theta: LONGREAL;  pars: antsNeighbourhoods.pars;  val: INTEGER;  interactionFcache: realArrayArray;
	BEGIN
		pars := M.n.cpar;  interactionFcache := M.interactionFcache;  val := values[0];

		theta := -pars[0] * M.externalFcache[val];   (* factor 2 for consistency with Ising Model *)
		FOR i := 1 TO M.n.clen - 1 DO
			theta := theta - 1 * pars[i] * interactionFcache[val, values[i]] (* factor 2 for consistency with Ising Model *)
		END;
		IF M.dataFcache # NIL THEN theta := theta - M.dataFcache[val, values[i]] END;
		RETURN theta
	END U;

	PROCEDURE GetNeighbourValues( o, orig: antsArrayObjects.tINTEGERObject;  n: antsNeighbourhoods.Neighbours;  y, x: LONGINT;
														  VAR values: ARRAY OF INTEGER );
	VAR i: LONGINT;
	BEGIN
		FOR i := 0 TO n.clen - 1 DO values[i] := o.A[(y + n.cy[i]) MOD o.h, (x + n.cx[i]) MOD o.w] END;
		IF orig # NIL THEN values[i] := orig.A[y, x] END
	END GetNeighbourValues;

	PROCEDURE PseudoLikPrepare*( o: antsArrayObjects.tINTEGERObject;  M: tModel;
														 VAR T: antsNeighbourhoods.NeighbourTable );
	VAR x0, y0, w0, h0: LONGINT;
	BEGIN
		antsRegions.Get( M.region, o, x0, y0, w0, h0 );
		T := antsNeighbourhoods.MakeNeighbourTable( o, x0, y0, w0, h0, M.n );  MakeCaches( M, o.depth, FALSE );  Sync1( M )
	END PseudoLikPrepare;

	PROCEDURE PseudoLik*( o: antsNeighbourhoods.NeighbourTable;  M: tModel;  AIC: BOOLEAN ): LONGREAL;
	VAR sum: LONGREAL;  u, z: LONGREAL;  len, i: LONGINT;  center: LONGINT;  count: INTEGER;  id: INTEGER;  clen: LONGINT;

		PROCEDURE U( VAR values: ARRAY OF LONGINT;  M: tModel ): LONGREAL;
		VAR i: LONGINT;  theta: LONGREAL;  pars: antsNeighbourhoods.pars;  val: LONGINT;  interactionFcache: realArrayArray;
		BEGIN
			pars := M.n.cpar;  interactionFcache := M.interactionFcache;  val := values[0];

			theta := -pars[0] * M.externalFcache[val];   (* factor 2 for consistency with Ising Model *)
			FOR i := 1 TO M.n.clen - 1 DO
				theta := theta - 1 * pars[i] * interactionFcache[val, values[i]] (* factor 2 for consistency with Ising Model *)
			END;
			IF M.dataFcache # NIL THEN theta := theta - M.dataFcache[val, values[i]] END;
			RETURN theta
		END U;

	BEGIN

		len := LEN( o[0] ) - 1;  id := INTEGER( LEN( M.interactionFcache ) - 1 );  clen := M.n.clen - 1;
		ASSERT ( len - 1 = clen );

		sum := 0;
		WHILE (o[i, len] > 0) DO
			u := U( o[i], M );  center := o[i, 0];  z := 0;
			FOR count := 0 TO id DO o[i, 0] := count;  z := z + Math.exp( U( o[i], M ) ) END;

			o[i, 0] := center;  sum := sum + o[i, len] * u - o[i, len] * Math.ln( z );  INC( i )
		END;

		IF AIC THEN sum := sum - M.dim
		END;

		RETURN sum / (len + 1)
	END PseudoLik;

	PROCEDURE Sync1( m: tModel );
	VAR i, j, max: LONGINT;
		a: ARRAY 3 OF LONGREAL;
	BEGIN
		max := LEN( m.externalFcache )(LONGINT) - 1;  a[2] := max;
		FOR i := 0 TO max DO
			a[0] := i;  m.externalFcache[i] := m.externalF.get( m.externalF, a );
			FOR j := 0 TO max DO
				a[1] := j;  m.interactionFcache[i, j] := m.interactionF.get( m.interactionF, a );
				IF (m.dataFcache # NIL ) THEN m.dataFcache[i, j] := m.dataF.get( m.dataF, a ) END
			END
		END;
		m.synced := TRUE
	END Sync1;

	PROCEDURE MakeCaches( m: tModel;  depth: LONGINT;  data: BOOLEAN );
	BEGIN
		IF (m.interactionFcache = NIL ) OR (LEN( m.interactionFcache ) # depth) THEN NEW( m.interactionFcache, depth, depth ) END;
		IF data & (m.dataF # NIL ) THEN
			IF (m.dataFcache = NIL ) OR (LEN( m.dataFcache ) # depth) THEN NEW( m.dataFcache, depth, depth ) END
		ELSE m.dataFcache := NIL
		END;
		IF (m.externalFcache = NIL ) OR (LEN( m.externalFcache ) # depth) THEN NEW( m.externalFcache, depth ) END;

		IF (m.currentR = NIL ) OR (LEN( m.currentR ) < depth) THEN NEW( m.currentR, depth )
		END;
		IF (m.current = NIL ) OR (LEN( m.current ) < m.n.clen + 1) THEN NEW( m.current, m.n.clen + 1 ) END  (* +1 corresponds to data term *)
	END MakeCaches;

	PROCEDURE Sync( m: tModel;  depth: LONGINT );
	VAR i: INTEGER;  c: antsCaches.FullCache;
		cv: POINTER TO ARRAY OF INTEGER;
		offset: LONGINT;  s: LONGREAL;
	BEGIN
		ASSERT ( m.interactionFcache # NIL );
		Sync1( m );

		IF m.n.clen = 1 THEN m.MCache := NIL;  RETURN
		END;   (* bugfix for 1dim cache, doesnot work ! *)

		IF m.dataFcache # NIL THEN
			m.MCache := antsCaches.Cube( m.n.clen + 1, SHORT( depth ), m.maxCacheSize );   (*+1  020319 *)
		ELSE
			m.MCache := antsCaches.Cube( m.n.clen, SHORT( depth ), m.maxCacheSize ) (*  020319 *)
		END;

		IF m.MCache # NIL THEN
			c := m.MCache;
			NEW( cv, c.d );   (* m.n.clen+1);   (* +1 020319 *) *)

			offset := -1;
			WHILE (c.NextPoint( offset, cv^, 1 )) DO
				s := 0;
				(* write values of exp(..) to array *)
				i := 0;
				WHILE (i < depth) DO cv[0] := i;  s := s + Math.exp( m.coolingTemp * U( cv^, m ) );  c.values[i + offset] := s;  INC( i ) END;
				cv[0] := 0;
				(* divide by normalizing constant *)
				i := 0;
				WHILE (i < depth) DO c.values[offset + i] := c.values[offset + i] / s;  INC( i ) END
			END
		END
	END Sync;

	PROCEDURE OneSweep*( M: antsKernel.samplingMsg );
	VAR A, Orig: antsArrayObjects.tINTEGERObject;  model: tModel;  dim, x, y, w, h: LONGINT;  x0, y0, w0, h0: LONGINT;  orig: Objects.Object;
		count: INTEGER;  uv: realArray;  nb: intArray;  z, cooling, ran: LONGREAL;  max: INTEGER;  cpos, nclen: LONGINT;  cache: antsCaches.FullCache;
		cx, cy: antsNeighbourhoods.Index;  i: LONGINT;  pars: antsNeighbourhoods.pars;  theta: LONGREAL;  position, posi: LONGINT;  s: antsKernel.Kernel;
		visit: antsKernel.visitingScheme;  parallel: BOOLEAN;  destA, srcA: antsArrayObjects.tINTEGERArray;  externalFcache: realArray;
		interactionFcache, dataFcache: realArrayArray;
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
		externalFcache := model.externalFcache;  interactionFcache := model.interactionFcache;
		dataFcache := model.dataFcache;

		cache := model.MCache;

		IF (cache = NIL ) THEN
			FOR posi := 0 TO w0 * h0 - 1 DO
				position := visit( posi, w0 * h0 );  y := position DIV w0 + y0;  x := position MOD w0 + x0;
				(*
			FOR y := y0 TO h0 DO
			FOR x := x0 TO w0 DO
			*)
				(* this would typically be an INLINE procedure *)
				(* ---------- begin local -----------*)
				(* GetNeighbourValues(A,Orig,model.n,y,x,nb^);*)
				FOR i := 0 TO nclen DO nb[i] := srcA[(y + cy[i]) MOD h, (x + cx[i]) MOD w] END;
				IF Orig # NIL THEN nb[i] := Orig.A[y, x] END;
				(*  end GetNeighbourValues *)

				z := 0;
				FOR count := 0 TO max DO
					nb[0] := count;

					(* ---- begin U(model,nb^) ---- *)
					theta := -pars[0] * externalFcache[nb[0]];
					FOR i := 1 TO nclen DO theta := theta - 1 * pars[i] * interactionFcache[nb[0], nb[i]] END;
					IF dataFcache # NIL THEN theta := theta - dataFcache[nb[0], nb[i]] END;
					(* ---- end U ----- *)

					z := z + Math.exp( cooling * theta );  uv[count] := z
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
				FOR i := 0 TO nclen DO nb[i] := srcA[(y + cy[i]) MOD h, (x + cx[i]) MOD w] END;
				IF Orig # NIL THEN nb[i] := Orig.A[y, x] END;

				nb[0] := 0;  ran := vyRanBase.RandomU();  count := 0;  cpos := cache.Offset( nb^, 1 );
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
		orig: antsArrayObjects.tINTEGERObject;  obj: Objects.Object;  cv: intArray;  posi, position: LONGINT;

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
		IF ~model.synced THEN Sync1( model ) END;

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
		orig: antsArrayObjects.tINTEGERObject;  obj: Objects.Object;  cv: intArray;  posi, position: LONGINT;
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
		IF ~model.synced THEN Sync1( model ) END;

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
						IF msg.name = "Gen" THEN COPY( 'antsMDimDiscreteS.Gen', msg.s );  msg.class := Objects.String;  msg.res := 0;  RETURN
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
					IF msg.id = Objects.enum THEN
						msg.Enum( "distfunction" );  msg.Enum( "weights" );  msg.Enum( "externalFunction" );  msg.Enum( "interactionFunction" );  msg.Enum( "dataFunction" );  antsModels.Handler( o, msg )
					ELSIF msg.id = Objects.get THEN
						IF msg.name = "weights" THEN msg.obj := o.n;  msg.res := 0;  RETURN
						ELSIF msg.name = "externalFunction" THEN msg.obj := o.externalF;  msg.res := 0;  RETURN
						ELSIF msg.name = "interactionFunction" THEN msg.obj := o.interactionF;  msg.res := 0;  RETURN
						ELSIF msg.name = "dataFunction" THEN msg.obj := o.dataF;  msg.res := 0;  RETURN
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
						vyBase.objecthandle( o, msg );  antsObjects.Bind( o.externalF, msg );
						antsObjects.Bind( o.interactionF, msg );  antsObjects.Bind( o.dataF, msg );  antsObjects.Bind( o.n, msg )
					END
				END;
			ELSE antsModels.Handler( o, msg )
			END
		END  (* tVector*)
	END Handler;

	PROCEDURE OpenModel*( M: tModel;  n: antsNeighbourhoods.Neighbours;  ef: antsFunctions.FunctionXd;
											   if: antsFunctions.FunctionXd;  name: ARRAY OF CHAR );
	BEGIN
		M.dim := n.dim - 1;  M.n := n;  M.externalF := ef;  M.interactionF := if;  vyName.RegisterNamed( M, name );
		M.handle := Handler;  vyBase.Subscribe( ef, M );  vyBase.Subscribe( if, M );  vyBase.Subscribe( M.n, M );
		antsModels.Open( M )

	END OpenModel;

	PROCEDURE Gen*;
	VAR m: tModel;
	BEGIN
		aM.cmd;
		NEW( m );  m.handle := Handler;  Objects.NewObj := m;  m.synced := FALSE;   (* m.synchroneus := FALSE;          *)
		antsObjects.Register( m )
	END Gen;

	PROCEDURE NewModel*;
	VAR l: antsCommands.tScanList;  name: vyName.tNameArray;  M: tModel;  obj: vyBase.Object;  ef, if: vyBase.Object;
		n: antsNeighbourhoods.Neighbours;
	BEGIN
		l := antsCommands.ScanFromPar( "name=NAME par=OBJ externalFunction=OBJ interactionfunction=OBJ" );
		IF antsCommands.ExpectNameFromKeyword( l, "name", name ) & antsCommands.ExpectObjectFromKeyword( l, "par", obj ) &
		    antsCommands.ExpectObjectFromKeyword( l, "externalFunction", ef ) & antsCommands.ExpectObjectFromKeyword( l, "interactionFunction", if ) THEN
			n := obj( antsNeighbourhoods.Neighbours );  Gen;  M := Objects.NewObj( tModel );
			OpenModel( M, n, ef( antsFunctions.FunctionXd ), if( antsFunctions.FunctionXd ), name )
		END
	END NewModel;

	PROCEDURE AttachDataF*;
	VAR f, obj: vyBase.Object;
	BEGIN
		antsCommands.InitScan( "name=OBJ function=OBJ" );
		IF antsCommands.ExpectObject( "name", obj ) & (antsCommands.ExpectObject( "function", f )) THEN
			WITH obj: tModel DO
				WITH f: antsFunctions.FunctionXd DO obj.dataF := f;  obj.synced := FALSE;  aM.S( "attached function" );  vyBase.Subscribe( f, obj )
				END
			END
		END
	END AttachDataF;

BEGIN
	aM.launch;
END antsMDimDiscreteS.

System.Free antsMDimDiscreteS ~

fofAutomatic.Do
antsArrayObjects.New testarray 100 100 4 ~
antsArrayPictures.New testpict testarray ~
Voyager.Show testpict as antsPictureViews ~
antsFunctions.DefineXd externalFunction ~
antsFunctions.DefineXd interactionFunction ~
antsFunctions.SetXd > name externalFunction  > function "x*x"~
antsFunctions.SetXd > name interactionFunction  > function "x0*x1"~
antsNeighbourhoods.New > name parameter > size 5 > nonisotropic ~
antsInteractivePar.Show > name parameter    ~
antsObjects.WriteAttributes parameter ~
antsObjects.WriteAttributes interactionFunction ~
antsObjects.WriteAttributes  externalFunction ~
antsMDimDiscreteS.NewModel  Model  parameter  externalFunction interactionFunction  ~
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

