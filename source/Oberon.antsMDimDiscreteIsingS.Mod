MODULE antsMDimDiscreteIsingS IN Oberon;   (** fof  **)
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




IMPORT antsObjects, antsFunctions, Objects, Files, Gadgets, antsNeighbourhoods, antsRegions, Attributes,
	aM := antsMessages, antsArrayObjects, Math := MathL IN A2, antsKernel, antsModels, antsCommands, vyName, vyBase,
	antsCaches, vyRanBase, Links;

TYPE
	intArray = POINTER TO ARRAY OF SIGNED16;
	realArray = POINTER TO ARRAY OF FLOAT64;

	tModel* = POINTER TO tModelDesc;
	tModelDesc* = RECORD (antsModels.tModelDesc);
		dim-: SIGNED32;
		n*: antsNeighbourhoods.Neighbours;
		f: antsFunctions.Function;
		dataf: antsFunctions.Function;
		fcache: realArray;
		datafcache: realArray;
		(* synchroneus : BOOLEAN;          *)
		current: intArray;   (* to cache neighbours, temp! *)
		currentR: realArray (* to cache energy, temp! *)
	END;

	PROCEDURE StoreM( VAR R: Files.Rider;  s: tModel );
	BEGIN
		Files.WriteInt( R, 1 );  Files.WriteLInt( R, s.dim );  Gadgets.WriteRef( R, s.lib, s.n );  Gadgets.WriteRef( R, s.lib, s.f );
		Gadgets.WriteRef( R, s.lib, s.dataf )
	END StoreM;

	PROCEDURE LoadM( VAR R: Files.Rider;  s: tModel );
	VAR objsub: Objects.Object;  version: SIGNED16;
	BEGIN
		Files.ReadInt( R, version );  Files.ReadLInt( R, s.dim );  Gadgets.ReadRef( R, s.lib, objsub );
		IF objsub # NIL THEN s.n := objsub( antsNeighbourhoods.Neighbours ) END;
		Gadgets.ReadRef( R, s.lib, objsub );
		IF objsub # NIL THEN s.f := objsub( antsFunctions.Function ) END;
		IF version > 0 THEN
			Gadgets.ReadRef( R, s.lib, objsub );
			IF objsub # NIL THEN s.dataf := objsub( antsFunctions.Function ) END
		END
	END LoadM;

	(* Potential Function U : *)
(* values: Values in neighbourhood, v[0] is central pixel *)

	PROCEDURE U( VAR values: ARRAY OF SIGNED16;  M: tModel ): FLOAT64;
	VAR i: SIGNED32;  theta: FLOAT64;  pars: antsNeighbourhoods.pars;  fcache: realArray;
	BEGIN
		pars := M.n.cpar;  fcache := M.fcache;

		theta := 2 * pars[0] * values[0];   (* factor 2 for consistency with Ising Model *)
		FOR i := 1 TO M.n.clen - 1 DO
			theta := theta - 2 * pars[i] * fcache[ABS( values[i] - values[0] )] (* factor 2 for consistency with Ising Model *)
		END;
		IF M.datafcache # NIL THEN theta := theta - 2 * M.datafcache[ABS( values[i] - values[0] )] END;
		RETURN theta
	END U;

	PROCEDURE GetNeighbourValues( o, orig: antsArrayObjects.tINTEGERObject;  n: antsNeighbourhoods.Neighbours;  y, x: SIGNED32;
														  VAR values: ARRAY OF SIGNED16 );
	VAR i: SIGNED32;
	BEGIN
		FOR i := 0 TO n.clen - 1 DO values[i] := o.A[(y + n.cy[i]) MOD o.h, (x + n.cx[i]) MOD o.w] END;
		IF orig # NIL THEN values[i] := orig.A[y, x] END
	END GetNeighbourValues;

	PROCEDURE PseudoLikTab*( o: antsArrayObjects.tINTEGERObject;  M: tModel;  VAR values: ARRAY OF ARRAY OF FLOAT64 );
	VAR sum: FLOAT64;  x, y, x0, y0, w0, h0: SIGNED32;  f: antsFunctions.Function;  u, z: FLOAT64;  count: SIGNED16;  value: intArray;
	BEGIN
		antsRegions.Get( M.region, o, x0, y0, w0, h0 );  DEC( w0 );  DEC( h0 );  MakeCaches( M, o.depth, FALSE );  Sync1( M );
		value := M.current;

		sum := 0;  f := M.f;
		FOR y := y0 TO y0 + h0 DO
			FOR x := x0 TO x0 + w0 DO
				GetNeighbourValues( o, NIL , M.n, y, x, value^ );  u := Math.exp( U( value^, M ) );  z := 0;
				FOR count := 0 TO SHORT( o.depth - 1 ) DO value[0] := count;  z := z + Math.exp( U( value^, M ) ) END;
				values[y - y0, x - x0] := u / z
			END
		END
	END PseudoLikTab;

	PROCEDURE PseudoLikPrepare*( o: antsArrayObjects.tINTEGERObject;  M: tModel;
														 VAR T: antsNeighbourhoods.NeighbourTable );
	VAR x0, y0, w0, h0: SIGNED32;
	BEGIN
		antsRegions.Get( M.region, o, x0, y0, w0, h0 );
		T := antsNeighbourhoods.MakeNeighbourTable( o, x0, y0, w0, h0, M.n );  MakeCaches( M, o.depth, FALSE );  Sync1( M )
	END PseudoLikPrepare;

	PROCEDURE PseudoLik*( o: antsNeighbourhoods.NeighbourTable;  M: tModel;  AIC: BOOLEAN ): FLOAT64;
	VAR sum: FLOAT64;  u, z: FLOAT64;  len, i: SIGNED32;  center: SIGNED32;  count: SIGNED16;  id: SIGNED16;  fcache: realArray;  clen: SIGNED32;  pars: antsNeighbourhoods.pars;

		PROCEDURE U( VAR value: ARRAY OF SIGNED32 ): FLOAT64;
		VAR theta: FLOAT64;  i: SIGNED32;
		BEGIN

			theta := 2 * pars[0] * value[0];   (* factor 2 for consistency with Ising Model *)
			FOR i := 1 TO clen DO
				theta := theta - 2 * pars[i] * fcache[ABS( value[i] - value[0] )] (* factor 2 for consistency with Ising Model *)
			END;
			RETURN theta
		END U;

	BEGIN
		fcache := M.fcache;  pars := M.n.cpar;

		len := SIGNED32( LEN( o[0] ) - 1 );  id := SIGNED16( LEN( fcache ) - 1 );  clen := M.n.clen - 1;
		ASSERT ( len - 1 = clen );

		sum := 0;
		WHILE (o[i, len] > 0) DO
			u := U( o[i] );  center := o[i, 0];  z := 0;
			FOR count := 0 TO id DO o[i, 0] := count;  z := z + Math.exp( U( o[i] ) ) END;

			o[i, 0] := center;  sum := sum + o[i, len] * u - o[i, len] * Math.ln( z );  INC( i )
		END;

		IF AIC THEN sum := sum - M.dim
		END;

		RETURN sum / (len + 1)
	END PseudoLik;

(*
made inline
PROCEDURE Local (o,c,orig: antsArrayObjects.tINTEGERObject;      x, y: SIGNED32;       M: tModel);
VAR ran, u, z: FLOAT64;             count: SIGNED16;       vals: realArray;      values: intArray;
BEGIN
vals := M.currentR;
values := M.current;

GetNeighbourValues(o,orig,M.n,y,x,values^);

z := 0;
FOR count := 0 TO SHORT(o.depth - 1) DO
values[0] := count;
vals[count] := Math.exp(M.coolingTemp *U(values^,M));
z := z+vals[count];
END;

ran := vyRanBase.RandomU()*z;
count := 0;
u := vals[0];

WHILE ran > u DO
INC(count);
u := u + vals[count];
END;

c.A[(y) MOD o.h, (x) MOD o.w] := count
END Local;

PROCEDURE CLocal (o,c,orig: antsArrayObjects.tINTEGERObject;     x, y: SIGNED32;     M: tModel);
VAR    ran, u: FLOAT64;    count: SIGNED16;     cv: intArray;     cpos: SIGNED32;
BEGIN
cv := M.current;

GetNeighbourValues(o,orig,M.n,y,x,cv^);
cv[0] := 0;

ran := vyRanBase.RandomU();
u := 0;             count := 0;
cpos := M.MCache.Offset(cv^,1);
u := M.MCache.values[cpos];
WHILE ran > u DO
INC(count);           INC(cpos);
u := M.MCache.values[cpos];
END;
c.A[(y) MOD o.h, (x) MOD o.w] := count
END CLocal;
*)


	PROCEDURE Sync1( m: tModel );
	VAR i, max: SIGNED32;
	BEGIN
		max := LEN( m.fcache ) - 1;
		FOR i := 0 TO max DO m.fcache[i] := m.f.get( m.f, i / max ) END;
		IF (m.datafcache # NIL ) THEN
			FOR i := 0 TO max DO m.datafcache[i] := m.dataf.get( m.dataf, i / max ) END
		END;
		m.synced := TRUE
	END Sync1;

	PROCEDURE MakeCaches( m: tModel;  depth: SIGNED32;  data: BOOLEAN );
	BEGIN
		IF (m.fcache = NIL ) OR (LEN( m.fcache ) # depth) THEN NEW( m.fcache, depth ) END;
		IF data & (m.dataf # NIL ) THEN
			IF (m.datafcache = NIL ) OR (LEN( m.datafcache ) # depth) THEN NEW( m.datafcache, depth ) END
		ELSE m.datafcache := NIL
		END;
		IF (m.currentR = NIL ) OR (LEN( m.currentR ) < depth) THEN NEW( m.currentR, depth ) END;
		IF (m.current = NIL ) OR (LEN( m.current ) < m.n.clen + 1) THEN NEW( m.current, m.n.clen + 1 ) END  (* +1 corresponds to data term *)
	END MakeCaches;

	PROCEDURE Sync( m: tModel;  depth: SIGNED32 );
	VAR i: SIGNED16;  c: antsCaches.FullCache;
		cv: POINTER TO ARRAY OF SIGNED16;
		offset: SIGNED32;  s: FLOAT64;
	BEGIN
		ASSERT ( m.fcache # NIL );
		Sync1( m );

		IF m.n.clen = 1 THEN m.MCache := NIL;  RETURN
		END;   (* bugfix for 1dim cache, doesnot work ! *)

		IF m.datafcache # NIL THEN
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
	VAR A, Orig: antsArrayObjects.tINTEGERObject;  model: tModel;  dim, x, y, w, h: SIGNED32;  x0, y0, w0, h0: SIGNED32;  orig: Objects.Object;
		count: SIGNED16;  uv: realArray;  nb: intArray;  z, cooling, ran: FLOAT64;  max: SIGNED16;  cpos, nclen: SIGNED32;  cache: antsCaches.FullCache;
		cx, cy: antsNeighbourhoods.Index;  i: SIGNED32;  pars: antsNeighbourhoods.pars;  theta: FLOAT64;  fcache, datafcache: realArray;
		position, posi: SIGNED32;  s: antsKernel.Kernel;  visit: antsKernel.visitingScheme;  parallel: BOOLEAN;
		destA, srcA: antsArrayObjects.tINTEGERArray;
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
		nclen := model.n.clen - 1;  cx := model.n.cx;  cy := model.n.cy;  pars := model.n.cpar;  fcache := model.fcache;
		datafcache := model.datafcache;  cache := model.MCache;

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
					theta := 2 * pars[0] * nb[0];
					FOR i := 1 TO nclen DO theta := theta - 2 * pars[i] * fcache[ABS( nb[i] - nb[0] )] END;
					IF datafcache # NIL THEN theta := theta - 2 * datafcache[ABS( nb[i] - nb[0] )] END;
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
	VAR A, Ao: antsArrayObjects.tINTEGERObject;  model: tModel;  dim: SIGNED32;  x0, y0, w0, h0: SIGNED32;  zvax, zvay, zva: SIGNED32;  M: tModel;
		gen: vyRanBase.tRandom;  h, h1, h2, cooling: FLOAT64;  AA: antsArrayObjects.tINTEGERArray;  W, H, depth: SIGNED32;
		orig: antsArrayObjects.tINTEGERObject;  obj: Objects.Object;  cv: intArray;  posi, position: SIGNED32;  bool: BOOLEAN;  start, stop: SIGNED32;
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
		Attributes.GetBool( M, "halfSweeps", bool );
		IF bool THEN
			Attributes.GetBool( M, "firstHalf", bool );  Attributes.SetBool( M, "firstHalf", ~bool );
			IF bool THEN start := 0;  stop := w0 * h0 DIV 2 ELSE start := w0 * h0 DIV 2 + 1;  stop := w0 * h0 - 1;  END;
			bool := TRUE;
		ELSE start := 0;  stop := w0 * h0 - 1;  Attributes.SetBool( M, "halfSweeps", FALSE );
		END;
		FOR posi := start TO stop DO
			position := visit( posi, w0 * h0 );  zvay := position DIV w0 + y0;  zvax := position MOD w0 + x0;

			IF A.depth = 2 THEN zva := 1 - A.A[zvay, zvax]
			ELSE zva := gen.GetRandomL( gen, A.depth );
			END;

			GetNeighbourValues( A, orig, M.n, zvay, zvax, cv^ );  h2 := U( cv^, model );  cv[0] := SHORT( zva );  h1 := U( cv^, model );

			h := cooling * (h1 - h2);

			IF h >= 0 THEN AA[zvay, zvax] := SHORT( zva )
			ELSE
				IF gen.GetRandomU( gen ) < Math.exp( h ) THEN AA[zvay, zvax] := SHORT( zva ) END
			END

		END

	END Metropolis;

	PROCEDURE Exchange( msg: antsKernel.samplingMsg );
	VAR A, Ao: antsArrayObjects.tINTEGERObject;  model: tModel;  dim: SIGNED32;  x0, y0, w0, h0: SIGNED32;  M: tModel;
		gen: vyRanBase.tRandom;  h, h1, h2, cooling: FLOAT64;  AA: antsArrayObjects.tINTEGERArray;  W, H, depth: SIGNED32;
		orig: antsArrayObjects.tINTEGERObject;  obj: Objects.Object;  cv: intArray;  posi, position: SIGNED32;
		zvax1, zvay1, zvax2, zvay2, zva1, zva2: SIGNED32;  s: antsKernel.Kernel;  visit: antsKernel.visitingScheme;  parallel: BOOLEAN;
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
		IF orig = NIL THEN Uniform( s ) ELSE antsArrayObjects.CopyII( orig.A, A.A, 0, 0, A.w, A.h, 0, 0 ) END;
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
					IF msg.id = Objects.enum THEN
						msg.Enum( "Gen" );  msg.Enum( "dim" );   (* msg.Enum("synchroneus");      *) antsModels.Handler( o, msg )
					ELSIF msg.id = Objects.get THEN
						IF msg.name = "Gen" THEN COPY( 'antsMDimDiscreteIsingS.Gen', msg.s );  msg.class := Objects.String;  msg.res := 0;  RETURN
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
					IF msg.id = Objects.enum THEN msg.Enum( "distfunction" );  msg.Enum( "weights" );  msg.Enum( "datafunction" );  antsModels.Handler( o, msg )
					ELSIF msg.id = Objects.get THEN
						IF msg.name = "weights" THEN msg.obj := o.n;  msg.res := 0;  RETURN
						ELSIF msg.name = "distfunction" THEN msg.obj := o.f;  msg.res := 0;  RETURN
						ELSIF msg.name = "datafunction" THEN msg.obj := o.dataf;  msg.res := 0;  RETURN
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
						vyBase.objecthandle( o, msg );  Gadgets.BindObj( o.f, msg.lib );
						IF o.f # NIL THEN
							IF o.f.handle # NIL THEN o.f.handle( o.f, msg ) END
						END;
						Gadgets.BindObj( o.n, msg.lib );
						IF o.n # NIL THEN
							IF o.n.handle # NIL THEN o.n.handle( o.n, msg ) END
						END;
						IF o.dataf # NIL THEN
							Gadgets.BindObj( o.dataf, msg.lib );
							IF o.dataf.handle # NIL THEN o.dataf.handle( o.dataf, msg ) END
						END
					END
				END;
			ELSE antsModels.Handler( o, msg )
			END
		END  (* tVector*)
	END Handler;

	PROCEDURE OpenModel*( M: tModel;  n: antsNeighbourhoods.Neighbours;  f: antsFunctions.Function;  name: ARRAY OF CHAR );
	BEGIN
		M.dim := n.dim - 1;  M.n := n;  vyName.RegisterNamed( M, name );  M.handle := Handler;  M.f := f;
		vyBase.Subscribe( f, M );

		vyBase.Subscribe( M.n, M );  antsModels.Open( M )

	END OpenModel;

	PROCEDURE Gen*;
	VAR m: tModel;
	BEGIN
		aM.cmd;
		NEW( m );  m.handle := Handler;  Objects.NewObj := m;  m.synced := FALSE;   (* m.synchroneus := FALSE;          *)
		antsObjects.Register( m )
	END Gen;

	PROCEDURE NewModel*;
	VAR l: antsCommands.tScanList;  name: vyName.tNameArray;  M: tModel;  obj: vyBase.Object;  f: vyBase.Object;
		n: antsNeighbourhoods.Neighbours;
	BEGIN
		l := antsCommands.ScanFromPar( "name=NAME par=OBJ function=OBJ" );
		IF antsCommands.ExpectNameFromKeyword( l, "name", name ) & antsCommands.ExpectObjectFromKeyword( l, "par", obj ) &
		    antsCommands.ExpectObjectFromKeyword( l, "function", f ) THEN
			n := obj( antsNeighbourhoods.Neighbours );  Gen;  M := Objects.NewObj( tModel );
			OpenModel( M, n, f( antsFunctions.Function ), name )
		END
	END NewModel;

	PROCEDURE AttachDataF*;
	VAR f, obj: vyBase.Object;
	BEGIN
		antsCommands.InitScan( "name=OBJ function=OBJ" );
		IF antsCommands.ExpectObject( "name", obj ) & (antsCommands.ExpectObject( "function", f )) THEN
			WITH obj: tModel DO
				WITH f: antsFunctions.Function DO obj.dataf := f;  obj.synced := FALSE;  aM.S( "attached function" );  vyBase.Subscribe( f, obj )
				END
			END
		END
	END AttachDataF;

BEGIN
	aM.launch;
END antsMDimDiscreteIsingS.

System.Free antsMDimDiscreteIsingS ~

fofAutomatic.Do
antsArrayObjects.New testarray 100 100 4 ~
antsArrayPictures.New testpict testarray ~
Voyager.Show testpict as antsPictureViews ~
antsFunctions.Define > name testf > from - 12 > to 12 > step 1 > lower 0 > upper 1 ~
antsFunctions.Set > name testf > function "x*x"~ (lambda, gamma)
antsNeighbourhoods.New > name parameter > size 5 > nonisotropic ~
antsInteractivePar.Show > name parameter    ~
antsObjects.WriteAttributes parameter ~
antsMDimDiscreteIsingS.NewModel > name Model > par parameter  > function testf  ~
antsKernel.Define > name Sampler ~
antsKernel.AttachModel > sampler Sampler > model Model ~
antsKernel.AttachArray > sampler Sampler > array testarray ~
antsMC.New chain ~
antsMC.Add chain Sampler ~
~
fofAutomatic.Do > interactive
System.Time
antsMC.Forward chain  1 50 ~
System.Time ~
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
