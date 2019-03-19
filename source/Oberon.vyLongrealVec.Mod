MODULE vyLongrealVec IN Oberon;   (** gs   **)
(* Copyright notice:

This file is part of Voyager
Copyright (C) 1993-2002 Project Voyager, StatLab Heidelberg ; (C) 1993-2002 G. Sawitzki et al.

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
Report any problems as soon as possible to voyager@statlab.uni-heidelberg.de
*)



(*base model. Generate INTEGER, LONGINT, LONGREAL, BOOLEAN from this module
vy/src/common/vyBooleanVec.Mod
vy/src/common/vyIntVec.Mod
vy/src/common/vyLongintVec.Mod
vy/src/common/vyRealVec.Mod

COPY procedures are prepared in vyHost.Mod
*)

IMPORT Files, Objects, vyBase, vyHostTexts, vyName, vyLongintVec, vyreal := vyLongreal;

CONST
	idversion* = "vyLongrealVec 0.0a4";   (* may be maintained or changed by tools *)
	cBadType* = 1;   (* operation not defined or implemented for this type *)
	cBadLen* = 2;   (* length not matching for this type *)
	cOK* = {};

TYPE
	(* LONGREAL *)
	real* = LONGREAL;   (* technical convenience, to avoid duplicate code for REAL and LONGREAL *)
	index* = LONGINT;

	tVector* = POINTER TO tVectorDesc;
	tVectorDesc* = RECORD (vyBase.tVectorDesc) END;
	tLONGREAL* = POINTER TO tLONGREALDesc;
	tLONGREALDesc* = RECORD (vyBase.tDataDesc)
		x*: LONGREAL
	END;
	tMinMaxCache = POINTER TO tMinMaxCacheDesc;
	tMinMaxCacheDesc = RECORD (vyBase.tCacheDesc)
		min, max: real;
		minpos, maxpos, nans: LONGINT;   (*convenience. Valid if nans>=0 *)
	END;
	tMeanCache = POINTER TO tMeanCacheDesc;
	tMeanCacheDesc = RECORD (vyBase.tCacheDesc)
		mean, ssq: LONGREAL;   (* Valid if nans>=0 & ssq>=0 *)
		nans: LONGINT
	END;
	tBuf* = POINTER TO tBufDesc;
	tBufDesc* = RECORD (vyBase.tBufDesc)
		data: POINTER TO ARRAY OF real
	END;

	Op1Function* = PROCEDURE ( x: real ): real;
	ArrayOp1Function* = PROCEDURE ( VAR arg: ARRAY OF real );
	ArrayOp2Function* = PROCEDURE ( VAR arg1, arg2: ARRAY OF real );

	tMatrixChunk* = POINTER TO tMatrixChunkDesc;
	tMatrixChunkDesc* = RECORD
		row-, col-: index
	END;
	tChunkedMatrix* = POINTER TO tChunkedMatrixDesc;   (*! Wird nicht unterstützt*)
	tChunkedMatrixDesc* = RECORD (vyBase.ObjDesc)
		buf*: tMatrixChunk
	END;
VAR
	globallongreal: LONGREAL;   (* sneak globel. handle with care! *)

(** Prototypes *)
	PROCEDURE DoOp1*( v: vyBase.tVector;  function: Op1Function );
	VAR l: index;  chunk: tBuf;
	BEGIN
		IF v = NIL THEN RETURN END;
		ASSERT ( v IS tVector, 100 );
		chunk := v.buf( tBuf );
		WHILE chunk # NIL DO
			FOR l := 0 TO chunk.usedentries - 1 DO chunk.data[l] := function( chunk.data[l] ) END;
			IF (chunk.next # NIL ) THEN chunk := chunk.next( tBuf ) ELSE RETURN END
		END
	END DoOp1;

(** Allocation *)


	PROCEDURE NewBufs( size: index ): tBuf;
	VAR first, last: vyBase.tBuf;  chunk: tBuf;

		PROCEDURE generic( ch: tBuf;  len: LONGINT );
		BEGIN
			NEW( ch.data, len );  ch.str := vyBase.dynlrlarray;  ch.cache := NIL;  vyBase.GenericCatBuf( ch, len, size, first, last )
		END generic;

	BEGIN
		first := NIL;
		IF size = 0 THEN NEW( chunk );  generic( chunk, 128 ) ELSE
			WHILE size >= 8192 DO NEW( chunk );  generic( chunk, 8192 ) END;
			WHILE size >= 1024 DO NEW( chunk );  generic( chunk, 1024 ) END;
			WHILE size > 0 DO NEW( chunk );  generic( chunk, 128 ) END
		END;
		RETURN first( tBuf )
	END NewBufs;

	PROCEDURE FlushVecCaches( vec: vyBase.tVector );
	VAR buf: vyBase.tBuf;
	BEGIN
		buf := vec.buf;
		WHILE buf # NIL DO buf.cache := NIL;  buf := buf.next END
	END FlushVecCaches;

	PROCEDURE BufMinMax( buf: vyBase.tBuf ): tMinMaxCache;
	VAR mmCache: tMinMaxCache;  cache: vyBase.tCache;
		(*! check handling of 0 len vectors! *)
		PROCEDURE NewBufMinCache( buf: vyBase.tBuf ): tMinMaxCache;
		VAR mmCache: tMinMaxCache;
		BEGIN
			NEW( mmCache );  mmCache.nextcache := buf.cache;  buf.cache := mmCache;
			vyreal.MinMax( buf.usedentries, buf( tBuf ).data^, 0, mmCache.min, mmCache.minpos, mmCache.max,
									  mmCache.maxpos, mmCache.nans );
			RETURN mmCache
		END NewBufMinCache;

	BEGIN
		IF buf # NIL THEN
			IF buf IS tBuf THEN
				WITH buf: tBuf DO
					mmCache := NIL;  cache := buf.cache;
					WHILE (mmCache = NIL ) & (cache # NIL ) DO  (* changed from (mmCache#NIL) & (cache#NIL), fof 980615, mf 981015 *)
						IF cache IS tMinMaxCache THEN mmCache := cache( tMinMaxCache ) ELSE cache := cache.nextcache END
					END;
					IF mmCache = NIL THEN mmCache := NewBufMinCache( buf ) END;
					RETURN mmCache
				END;
			ELSE RETURN NIL
			END  (* WHILE *)
		ELSE RETURN NIL
		END
	END BufMinMax;

	PROCEDURE BufMean( buf: vyBase.tBuf ): tMeanCache;
	(*! check handling of 0 len vectors! *)
	VAR meanCache: tMeanCache;  cache: vyBase.tCache;

		PROCEDURE NewBufMeanCache( buf: vyBase.tBuf ): tMeanCache;
		VAR meanCache: tMeanCache;
		BEGIN
			NEW( meanCache );  meanCache.nextcache := buf.cache;  buf.cache := meanCache;
			vyreal.MeanSSq( buf.usedentries, buf( tBuf ).data^, 0, meanCache.mean, meanCache.ssq, meanCache.nans );
			RETURN meanCache
		END NewBufMeanCache;

	BEGIN
		IF buf # NIL THEN
			IF buf IS tBuf THEN
				WITH buf: tBuf DO
					meanCache := NIL;  cache := buf.cache;
					WHILE (meanCache = NIL ) & (cache # NIL ) DO  (* changed from (meanCache#NIL) & (cache#NIL), fof 980615, mf 981014 *)
						IF cache IS tMeanCache THEN meanCache := cache( tMeanCache ) ELSE cache := cache.nextcache END
					END;
					IF meanCache = NIL THEN meanCache := NewBufMeanCache( buf ) END;
					RETURN meanCache
				END;
			ELSE RETURN NIL
			END  (* WHILE *)
		ELSE RETURN NIL
		END
	END BufMean;

	PROCEDURE SetNrData( vec: tVector;  size: index );
	(* risky buffer reallocation. New buffer contents is undefined. *)
	BEGIN
		IF vec.nrData = size THEN RETURN END;
		vec.buf := NIL;  vec.nrData := 0;  vyBase.ApndChunks( NewBufs( size ), vec );  vec.nrData := size
	END SetNrData;

	PROCEDURE Store0( VAR R: Files.Rider;  o: tVector );
	(*! use vyLongreal Store*)

	VAR b: tBuf;  i: index;

	BEGIN
		Files.WriteLInt( R, o.nrData );
		IF o.buf # NIL THEN  (* fof 020625 *)
			b := o.buf( tBuf )
		ELSE b := NIL
		END;
		WHILE b # NIL DO
			IF b.usedentries > 0 THEN
				Files.WriteLInt( R, b.len );  Files.WriteLInt( R, b.usedentries );  i := 0;
				WHILE i < b.usedentries DO Files.WriteLReal( R, b.data[i] );  INC( i ) END
			END;   (*IF*)
			IF b.next # NIL THEN b := b.next( tBuf ) ELSE b := NIL END
		END;   (*WHILE*)
		Files.WriteLInt( R, 0 )
	END Store0;

	PROCEDURE Store0LONGREAL( VAR R: Files.Rider;  o: tLONGREAL );

	BEGIN
		Files.WriteLReal( R, o.x )
	END Store0LONGREAL;

	PROCEDURE Load0( VAR R: Files.Rider;  o: tVector );

	VAR b: tBuf;  i, c: index;

	BEGIN
		Files.ReadLInt( R, c );  o.nrData := c;  Files.ReadLInt( R, c );
		WHILE c # 0 DO
			b := NewBufs( c );   (* removed -1 fof 020213 *)
			b.len := c;  Files.ReadLInt( R, c );  b.usedentries := c;  i := 0;
			WHILE i < c DO Files.ReadLReal( R, b.data[i] );  INC( i ) END;
			vyBase.ApndChunks( b, o );  Files.ReadLInt( R, c )
		END  (*WHILE*)
	END Load0;

	PROCEDURE Load0LONGREAL( VAR R: Files.Rider;  o: tLONGREAL );

	BEGIN
		Files.ReadLReal( R, o.x )
	END Load0LONGREAL;

(** Vector allocation *)
	PROCEDURE HandleAttributes( o: tVector;  VAR M: Objects.AttrMsg );
	BEGIN
		IF M.id = Objects.get THEN
			IF M.name = "Gen" THEN COPY( 'vyLongrealVec.Gen', M.s );  M.class := Objects.String;  M.res := 0 ELSE vyBase.VectorHandler( o, M ) END
		ELSIF M.id = Objects.set THEN vyBase.VectorHandler( o, M )
		ELSE vyBase.VectorHandler( o, M )
		END
	END HandleAttributes;

	PROCEDURE HandleAttributesLONGREAL( o: tLONGREAL;  VAR M: Objects.AttrMsg );
	BEGIN
		IF M.id = Objects.get THEN
			IF M.name = "Gen" THEN COPY( 'vyLongrealVec.GenLongrealObject', M.s );  M.class := Objects.String;  M.res := 0
			ELSIF M.name = "y" THEN M.class := Objects.LongReal;  M.y := o.x;  M.res := 0
			ELSE vyBase.DataHandler( o, M )
			END
		ELSIF M.id = Objects.set THEN
			IF M.name = "y" THEN
				IF M.class = Objects.LongReal THEN o.x := M.y;  M.res := 0
				ELSIF M.class = Objects.Real THEN o.x := M.x;  M.res := 0
				ELSE vyBase.DataHandler( o, M )
				END
			ELSE vyBase.DataHandler( o, M )
			END
		ELSIF M.id = Objects.enum THEN vyBase.DataHandler( o, M );  M.Enum( "y" )
		ELSE vyBase.DataHandler( o, M )
		END
	END HandleAttributesLONGREAL;

	PROCEDURE Handler*( o: Objects.Object;  VAR M: Objects.ObjMsg );
	VAR copy: tVector;
	BEGIN
		IF o IS tVector THEN
			WITH o: tVector DO
				IF M IS Objects.AttrMsg THEN
					WITH M: Objects.AttrMsg DO HandleAttributes( o, M )
					END;
				ELSIF M IS Objects.CopyMsg THEN
					WITH M: Objects.CopyMsg DO  (* fof 0111 *)
						IF M.id = Objects.deep THEN
							IF M.stamp = o.stamp THEN M.obj := o.dlink
							ELSE o.stamp := M.stamp;  copy := New( Len( o ) );  o.dlink := copy;  CopyData( o, copy )
							END
						ELSE vyBase.VectorHandler( o, M )
						END;
					END;
				ELSIF M IS Objects.FileMsg THEN
					WITH M: Objects.FileMsg DO
						IF M.id = Objects.load THEN Load0( M.R, o );  vyBase.VectorHandler( o, M )
						ELSIF M.id = Objects.store THEN Store0( M.R, o );  vyBase.VectorHandler( o, M )
						ELSE vyBase.VectorHandler( o, M )
						END  (*IF*)
					END;
				ELSE vyBase.VectorHandler( o, M )
				END;   (*WITH*)
			END;
		ELSIF o IS tLONGREAL THEN
			WITH o: tLONGREAL DO  (*! tLONGREAL exists also in the Oberonsystem. tLONGREAL should be dropped.*)
				IF M IS Objects.AttrMsg THEN
					WITH M: Objects.AttrMsg DO HandleAttributesLONGREAL( o, M )
					END;
				ELSIF M IS Objects.FileMsg THEN
					WITH M: Objects.FileMsg DO
						IF M.id = Objects.load THEN Load0LONGREAL( M.R, o );  vyBase.DataHandler( o, M )
						ELSIF M.id = Objects.store THEN Store0LONGREAL( M.R, o );  vyBase.DataHandler( o, M )
						ELSE vyBase.DataHandler( o, M )
						END  (*IF*)
					END;
				ELSE vyBase.DataHandler( o, M )
				END  (* WITH*)
			END;
		END;   (* tVector*)
	END Handler;

(*! set to nil if buffer cannot be allocated *)
	PROCEDURE Gen*;
	VAR v: tVector;
	BEGIN
		NEW( v );  v.handle := Handler;  Objects.NewObj := v
	END Gen;

	PROCEDURE New*( size: index ): tVector;
	(*= create a new vector, and mark size *)
	VAR v: tVector;
	BEGIN
		Gen;  v := Objects.NewObj( tVector );  vyBase.ApndChunks( NewBufs( size ), v );  vyBase.MarkUsed( size, v );  RETURN v
	END New;

	PROCEDURE GenLongrealObject*;
	VAR o: tLONGREAL;
	BEGIN
		NEW( o );  o.handle := Handler;  Objects.NewObj := o
	END GenLongrealObject;

	PROCEDURE NewLongrealObject*( x: real ): tLONGREAL;
	VAR o: tLONGREAL;
	BEGIN
		GenLongrealObject;  o := Objects.NewObj( tLONGREAL );  o.x := x;  o.type := vyBase.lrltyp;
		o.storagetype := vyBase.lrltyp;  RETURN o
	END NewLongrealObject;

	PROCEDURE GC*( vec: vyBase.tVector );
	(*= rearrange internal storage, if possible *)
	END GC;

	PROCEDURE Allocate*( vec: vyBase.tVector;  size: index );
	(*=  allocate memory for a vector. Do not change information.
	To reduce size, use SetLen first to trim length
	*)
	VAR l, freetrail: LONGINT;
	VAR firstfree: vyBase.tBuf;
	BEGIN
		ASSERT ( size >= vec.nrData );
		GC( vec );  vyBase.FindAllocLen( vec, l, freetrail, firstfree );
		IF size > l THEN vyBase.ApndChunks( NewBufs( size - l ), vec ) END
	END Allocate;

	PROCEDURE SetLen*( vec: vyBase.tVector;  size: index );
	(*=set new vector len. Allocate new memory if necessary *)
	BEGIN
		IF size > vec.nrData THEN GC( vec );  Allocate( vec, size ) END;
		vyBase.MarkUsed( size, vec );  FlushVecCaches( vec )
	END SetLen;

	PROCEDURE Len*( vec: vyBase.tVector ): LONGINT;
	(*= get total vector length *)
	BEGIN
		IF vec = NIL THEN RETURN 0 ELSE RETURN vec.nrData END
	END Len;

(*! change names to NewMatrix etc. *)
	PROCEDURE NewLongrealMatrix*( rows, columns: LONGINT ): tVector;
	VAR v: tVector;
	BEGIN
		Gen;  v := Objects.NewObj( tVector );  vyBase.ApndChunks( NewBufs( rows * columns ), v );
		v.Layout := vyBase.MatrixLayout( rows, columns );  vyBase.MarkUsed( rows * columns, v );  RETURN v
	END NewLongrealMatrix;

	PROCEDURE NewLongrealArray*( sizes: ARRAY OF LONGINT ): tVector;
	VAR v: tVector;  size: index;
	BEGIN
		Gen;  v := Objects.NewObj( tVector );  vyBase.SetArrayLayout( sizes, v, size );
		vyBase.ApndChunks( NewBufs( size ), v );  vyBase.MarkUsed( size, v );  RETURN v
	END NewLongrealArray;

	PROCEDURE NewAlikeVector*( model: vyBase.tVector ): vyBase.tVector;
	(*= Allocate a new vector with same structure as model *)
	VAR new: tVector;
	BEGIN
		ASSERT ( (model # NIL ) & (model IS tVector), 100 );
		new := New( model.nrData );  new.Layout := vyBase.CloneLayout( model );  RETURN new
	END NewAlikeVector;

	PROCEDURE Append*( x: real;  v: vyBase.tVector );
	(*= Add a data point to a chunk. Append new chunk if necessary *)
	(*! defensive programming *)
	VAR l: index;  chunk: tBuf;
	BEGIN  (* find entry which is not full *)
		IF v.buf = NIL THEN v.buf := NewBufs( 1 ) END;
		chunk := v.buf( tBuf );
		l := chunk.len;   (*l:=LEN(chunk.data);*)
		WHILE (chunk.usedentries = l) & (chunk.next # NIL ) DO
			chunk := chunk.next( tBuf );  l := chunk.len (* l:=LEN(chunk.data);*)
		END;
		IF chunk.usedentries = l THEN chunk.next := NewBufs( l );  chunk := chunk.next( tBuf );  chunk.usedentries := 0 END;
		chunk.data[chunk.usedentries] := x;  INC( chunk.usedentries );  chunk.cache := NIL;  INC( v.nrData )
	END Append;

	PROCEDURE GetMinMax*( v: vyBase.tVector;  VAR min, max: real;  VAR nrNaNs: LONGINT );
	(*! check handling of 0 len vectors! *)
	VAR buf: vyBase.tBuf;  mmCache: tMinMaxCache;
	BEGIN
		min := MAX( real );  max := MIN( real );  buf := v.buf;  nrNaNs := 0;
		WITH v: tVector DO
			WHILE buf # NIL DO
				WITH buf: tBuf DO
				(*mmCache:=NIL;  cache:=buf.cache;
				WHILE (mmCache=NIL) & (cache#NIL) DO  (* changed from (mmCache#NIL) & (cache#NIL), fof 980615 *)
				IF cache IS tMinMaxCache THEN mmCache:=cache(tMinMaxCache)
				ELSE cache:=cache.nextcache
				END;
				END; *)
				(*mf 981015 search algorithm is already in BufMinMax*)
					mmCache := BufMinMax( buf );
					IF mmCache.min < min THEN min := mmCache.min END;
					IF mmCache.max > max THEN max := mmCache.max END;
					INC( nrNaNs, mmCache.nans )
				END;
				IF buf.next # NIL THEN buf := buf.next( tBuf ) ELSE buf := NIL END
			END  (* WHILE *)
		END
	END GetMinMax;

	PROCEDURE GetMeanSsq*( v: vyBase.tVector;  VAR Mean, Ssq: real;  VAR nrNaNs: LONGINT );
	(*! check handling of 0 len vectors! *)
	VAR buf: vyBase.tBuf;  mmCache: tMeanCache;  Sum, temp, temp1: real;  SsqAdd, MeanAdd, SumAdd: real;
		Count, CountAdd: LONGINT;
	BEGIN
		buf := v.buf;  nrNaNs := 0;  Ssq := 0.0;  Mean := 0.0;  Count := 0;  Sum := 0.0;
		WITH v: tVector DO
			WHILE buf # NIL DO
				WITH buf: tBuf DO
				(*mmCache:=NIL;  cache:=buf.cache;
				WHILE (mmCache=NIL) & (cache#NIL) DO  (* changed from (mmCache#NIL) & (cache#NIL), fof 980615 *)
				IF cache IS tMeanCache THEN mmCache:=cache(tMeanCache) (* Zeile nicht klar *)
				ELSE cache:=cache.nextcache
				END;
				END;
				mmCache:=FillBufMeanCache(buf);
				IF mmCache=NIL THEN mmCache:=FillBufMeanCache(buf)  END;    ist diese Zeile nicht redundant? *)
				(*mf 981015 search algorithm is already in BufMean *)
					mmCache := BufMean( buf );
					(*	Zur Berechnung von Mean und Ssq:
				Seien im Folgenden:
				Ssqn,Ssqm	=	Ssq eines Chunks mit n,m benutzten Einträgen
				Mn,Mm		 =	Mean der Chunks mit n,m Einträgen
				Ssq,M 	  =	entsprechende Grössen für den aus beiden Chunks zusammengesetzten Chunk
				S			   =	Summe der Quadrate aller Elemente des zusammengesetzten Chunks
				Es gilt:
				Ssq=S-(n+m)*M2
				=Ssqn+n*Mn2+Ssqm*Mm2-(n+m)*M2
				=Ssqn+Ssqm+n*Mn*Mn+m*Mm*Mm-(n+m)*M*M ;	(n+m)*M*M=(n*Mn+m*Mm)*M
				=Ssqn+Ssqm+n*Mn*(Mn-M)+m*Mm*(Mm-M)	*)
					SsqAdd := mmCache.ssq;  MeanAdd := mmCache.mean;  CountAdd := buf.usedentries;
					SumAdd := MeanAdd * CountAdd;  temp := Sum + SumAdd;  Count := Count + CountAdd;
					temp1 := temp / Count;  Ssq := Ssq + SsqAdd + Sum * (Mean - temp1) + SumAdd * (MeanAdd - temp1);
					Sum := temp;  Mean := temp1;  INC( nrNaNs, mmCache.nans )
				END;
				IF buf.next # NIL THEN buf := buf.next( tBuf ) ELSE buf := NIL END
			END  (* WHILE *)
		END
	END GetMeanSsq;

	PROCEDURE kSmallestX( VAR a: ARRAY OF LONGREAL;  n, k: LONGINT ): LONGREAL;
	(** caution: modifies a*)
	(* algorithm of Nikolaus Wirth *)
	VAR i, j, l, m: LONGINT;  x: LONGREAL;

		PROCEDURE swap( VAR x, y: LONGREAL );
		VAR z: LONGREAL;
		BEGIN
			z := x;  x := y;  y := z
		END swap;

	BEGIN
		l := 0;  m := n - 1;
		WHILE (l < m) DO
			x := a[k];  i := l;  j := m;
			REPEAT
				WHILE (a[i] < x) DO INC( i ) END;
				WHILE (x < a[j]) DO DEC( j ) END;
				IF i <= j THEN swap( a[i], a[j] );  INC( i );  DEC( j ) END
			UNTIL i > j;
			IF j < k THEN l := i END;
			IF k < i THEN m := j END
		END;
		RETURN a[k]
	END kSmallestX;

	PROCEDURE GetMedian*( v: vyBase.tVector ): LONGREAL;
	VAR a: POINTER TO ARRAY OF LONGREAL;
	BEGIN
		NEW( a, Len( v ) );  CopyToArray( v, a^ );

		IF ODD( LEN( a ) ) THEN RETURN kSmallestX( a^, LEN( a ), LEN( a ) DIV 2 )
		ELSE RETURN (kSmallestX( a^, LEN( a ), LEN( a ) DIV 2 - 1 ) + kSmallestX( a^, LEN( a ), LEN( a ) DIV 2 )) / 2
		END
	END GetMedian;

	PROCEDURE Get*( v: vyBase.tVector;  pos: index ): real;
	VAR chunk: vyBase.tBuf;  loc: index;
	BEGIN
		vyBase.Loc( pos, v, chunk, loc );
		ASSERT ( loc >= 0, 100 );
		ASSERT ( loc < chunk.usedentries, 101 );   (* added jb 11.11.00 *)
		RETURN chunk( tBuf ).data[loc]
	END Get;

	PROCEDURE Set*( val: LONGREAL;  v: vyBase.tVector;  pos: index );
	VAR chunk: vyBase.tBuf;  loc: index;
	BEGIN
		ASSERT ( pos < v.nrData );
		(*IF pos >= v.nrData THEN  vyBase.MarkUsed(pos + 1, v) END;*)  (*? require explicit length setting ?*)
		vyBase.Loc( pos, v, chunk, loc );
		ASSERT ( loc >= 0 );
		chunk( tBuf ).data[loc] := val;  chunk.cache := NIL
	END Set;

	PROCEDURE GetIndexed*( v: vyBase.tVector;  indexvec: vyBase.tVector;  pos: index ): real;
	VAR chunk: vyBase.tBuf;  loc: index;
	BEGIN
		ASSERT ( v # NIL , 100 );
		ASSERT ( indexvec # NIL , 101 );
		WITH v: tVector DO vyBase.Loc( vyLongintVec.Get( indexvec( vyLongintVec.tVector ), pos ), v, chunk, loc );
			ASSERT ( loc >= 0 );
			ASSERT ( chunk # NIL );
			RETURN chunk( tBuf ).data[loc]
		END
	END GetIndexed;

	PROCEDURE SetIndexed*( xval: LONGREAL;  v: vyBase.tVector;  indexvec: vyBase.tVector;  pos: index );
	VAR chunk: vyBase.tBuf;  loc: index;
	BEGIN
		WITH v: tVector DO
			ASSERT ( v # NIL , 100 );
			ASSERT ( indexvec # NIL , 101 );
			ASSERT ( pos < v.nrData, 102 );   (* IF pos >= v.nrData THEN  vyBase.MarkUsed(pos + 1, v) END; *)
			vyBase.Loc( vyLongintVec.Get( indexvec( vyLongintVec.tVector ), pos ), v, chunk, loc );
			ASSERT ( loc >= 0 );
			WITH chunk: tBuf DO chunk.data[loc] := xval
			END;
			chunk.cache := NIL
		END
	END SetIndexed;

(** Copy *)
	PROCEDURE CopyData*( (*IN*) src,  (*OUT*) dest: vyBase.tVector );
	(*= copy the data section of a vector. Force dest to same len as src *)
	VAR srcchunk, destchunk: vyBase.tBuf;  oldcount, piececount, count, offs, srcoffs, destoffs: LONGINT;

	BEGIN
		offs := 0;  count := src.nrData;
		WITH dest: tVector DO
			IF dest.nrData # count THEN  (*vyBase.MarkUsed(count,dest);*) SetNrData( dest, count ) END
		END;
		WHILE count > 0 DO
			oldcount := count;  vyBase.Piece( count, src, offs, dest, offs, piececount, srcchunk, srcoffs, destchunk, destoffs );
			ASSERT ( count < oldcount );
			(*	action(piececount, srcchunk, srcoffs, destchunk, destoffs) *)
			(*		vyHostTexts.MsgSI('copying ', piececount);
		vyHostTexts.MsgSISI('from ', srcoffs, ' to ', destoffs);
		vyHostTexts.MsgSISI('srclen ', srcchunk.len, ' destlen ', destchunk.len);
		vyHostTexts.MsgSISI('src used ', srcchunk.usedentries, ' dest used ', destchunk.usedentries); *)

			vyreal.Copy( piececount, srcchunk( tBuf ).data^, srcoffs, destchunk( tBuf ).data^, destoffs );  offs := offs + piececount

		END;
		FlushVecCaches( dest );   (*! remove. keep consistent on per buffer basis *)
	END CopyData;

	PROCEDURE CopyToVec*( VAR A: ARRAY OF real;  v: vyBase.tVector;  len: index;  srcoffs, destoffs: index );
	VAR buf: tBuf;  bbuf: vyBase.tBuf;  j, count: index;
	BEGIN
		ASSERT ( len <= v.nrData - destoffs );   (* cw 21.8.98 *)

		(*  	buf := v.buf(tBuf);WHILE buf # NIL DO bufold := buf;
	IF buf.next # NIL THEN buf := buf.next(tBuf)   ELSE buf := NIL END;
	bufold.next := NIL;   bufold := NIL
	END;

	v.buf := NewLongreal(LEN(A)); *)
		(*! fof temporary removed, repair deleting of buffers.
	needs to use vyBase.ApndChunks gs *)
		vyBase.Loc( destoffs, v, bbuf, j );  buf := bbuf( tBuf );

		WHILE len > 0 DO
			count := len;
			IF count > buf.usedentries - j THEN count := buf.usedentries - j END;
			vyBase.COPYX( A, srcoffs, count, buf.data^, j );  DEC( len, count );  INC( srcoffs, count );  INC( destoffs, count );
			vyBase.Loc( destoffs, v, bbuf, j );  buf := bbuf( tBuf )

		END;
		FlushVecCaches( v )
	END CopyToVec;

	PROCEDURE CopyToArray*( v: vyBase.tVector;  VAR A: ARRAY OF real );
	VAR offs, len: index;  buf: vyBase.tBuf;
	BEGIN
		offs := 0;  len := v.nrData;
		ASSERT ( v # NIL , 101 );
		ASSERT ( LEN( A ) >= v.nrData, 100 );
		buf := v.buf( tBuf );
		WHILE buf # NIL DO
			IF buf.usedentries > 0 THEN vyBase.COPYX( buf( tBuf ).data^, 0, buf.usedentries, A, offs );  offs := offs + buf.usedentries END;
			buf := buf.next
		END  (* WHILE *)
	END CopyToArray;

(** Generic operations *)

	PROCEDURE DoArrayOp1*( v: vyBase.tVector;  op1: ArrayOp1Function );
	VAR v1: tVector;
		a: POINTER TO ARRAY OF LONGREAL;
	BEGIN
		ASSERT ( v IS tVector, 100 );
		IF v.buf.next = NIL THEN v1 := v( tVector );  op1( v1.buf( tBuf ).data^ )
		ELSE NEW( a, v.nrData );  CopyToArray( v, a^ );  op1( a^ );  CopyToVec( a^, v, v.nrData, 0, 0 )
		END;
		FlushVecCaches( v )
	END DoArrayOp1;

	PROCEDURE DoArrayOp2*( v1, v2: vyBase.tVector;  op2: ArrayOp2Function );
	(*!Hack*)
	VAR a, b: POINTER TO ARRAY OF LONGREAL;
	BEGIN
		ASSERT ( v1 IS tVector, 100 );
		ASSERT ( v2 IS tVector, 101 );
		NEW( a, v1.nrData );  NEW( b, v2.nrData );  CopyToArray( v1, a^ );  CopyToArray( v2, b^ );  op2( a^, b^ );
		CopyToVec( a^, v1, v1.nrData, 0, 0 );  CopyToVec( b^, v2, v2.nrData, 0, 0 );  FlushVecCaches( v1 );  FlushVecCaches( v2 )
	END DoArrayOp2;

(** Sorting *)

	PROCEDURE SortEachChunkLONGREAL*( c: tBuf );
	BEGIN
		WHILE (c # NIL ) DO
			vyreal.Sort( c.usedentries, c.data^, 0 );
			IF c.next = NIL THEN c := NIL ELSE c := c.next( tBuf ) END
		END
	END SortEachChunkLONGREAL;

	PROCEDURE SortEachChunkLONGREALWId*( c: tBuf;  cid: vyLongintVec.tBuf );
	BEGIN
		WHILE (c # NIL ) DO
			vyreal.SortIndexed( c.usedentries, c.data^, 0, cid( vyLongintVec.tBuf ).data^ );
			IF c.next = NIL THEN c := NIL ELSE c := c.next( tBuf );  cid := cid.next( vyLongintVec.tBuf ) END
		END
	END SortEachChunkLONGREALWId;

	PROCEDURE tcX( c: vyBase.tBuf ): tBuf;
	BEGIN
		IF c = NIL THEN RETURN NIL ELSE RETURN c( tBuf ) END
	END tcX;

	PROCEDURE MergeSortedChunkLONGREAL( s1, s2: tBuf ): BOOLEAN;

	(* v0r0a1, Felix O. Friedrich 31.8.95 *)

	(* pc: For now the incoming chunks s1 & s2 MUST be sorted individually	 *)
	(* if the result does not get sorted (may only happen, if you offend precondition pc),
	MergeSortedChunkreal returns FALSE otherwise TRUE *)
	(* d is really a NEW Chunk, i.e. memory is really allocated, be careful with iterative techinques,
	one could think of changing s1,s2 *)

	VAR i1, i2, length, i: index;  c1, c2, d: tBuf;  done, c1ended, c2ended, c2used, sorted: BOOLEAN;  r1, r2, lastr: real;
		cinter: vyBase.tBuf;  v, v1: tVector;

		PROCEDURE GetNextLongreal( VAR c: tBuf;  VAR i: index;  VAR r: real ): BOOLEAN;
		VAR ctemp: tBuf;
		BEGIN
			IF c = NIL THEN RETURN FALSE END;
			WHILE (i = c.usedentries) DO
				i := 0;  cinter := vyBase.NextBuf( c );  c := tcX( cinter );
				IF c = NIL THEN RETURN FALSE END
			END;
			ctemp := c;   (* hack to avoid warnings *)
			r := ctemp.data[i];  INC( i );
			IF i = c.usedentries THEN i := 0;  cinter := vyBase.NextBuf( c );  c := tcX( cinter ) END;
			RETURN TRUE
		END GetNextLongreal;

		PROCEDURE store( r: real ): BOOLEAN;
		BEGIN
			v.buf := d;  Append( r, v );
			IF lastr <= r THEN lastr := r;  RETURN TRUE ELSE lastr := r;  RETURN FALSE END
		END store;

	BEGIN
		i1 := 0;  i2 := 0;  c1 := s1;  c2 := s2;  done := FALSE;  sorted := TRUE;
		length := vyBase.GetUsedEntries( c1 ) + vyBase.GetUsedEntries( c2 );  d := NewBufs( length );
		c1ended := ~GetNextLongreal( c1, i1, r1 );  c2ended := ~GetNextLongreal( c2, i2, r2 );  lastr := MIN( real );  NEW( v );
		REPEAT
			IF c1ended THEN
				IF c2ended THEN done := TRUE ELSE sorted := (store( r2 ) & sorted);  c2ended := ~GetNextLongreal( c2, i2, r2 ) END
			ELSIF c2ended THEN sorted := (store( r1 ) & sorted);  c1ended := ~GetNextLongreal( c1, i1, r1 )
			ELSE
				IF r1 <= r2 THEN sorted := (store( r1 ) & sorted);  c1ended := ~GetNextLongreal( c1, i1, r1 )
				ELSE sorted := (store( r2 ) & sorted);  c2ended := ~GetNextLongreal( c2, i2, r2 )
				END
			END
		UNTIL done;
		IF ~sorted THEN RETURN FALSE END;
		c1 := s1;  c2 := s2;  c2used := FALSE;
		WHILE (c1 # NIL ) DO
			c1.cache := NIL;  c1.usedentries := 0;
			IF vyBase.NextBuf( c1 ) = NIL THEN
				IF ~c2used THEN c1.next := c2;  c2used := TRUE END
			END;
			cinter := vyBase.NextBuf( c1 );  c1 := tcX( cinter )
		END;
		c1 := s1;  i := 0;  NEW( v1 );
		WHILE (i < length) DO v.buf := c1;  v1.buf := d;  Append( Get( v1, i ), v );  INC( i ) END;
		RETURN TRUE
	END MergeSortedChunkLONGREAL;

	PROCEDURE MergeSortedChunkLONGREALWId( s1, s2: tBuf;  s1id, s2id: vyLongintVec.tBuf ): BOOLEAN;

	(* v0r0a1, Felix O. Friedrich 31.8.95 *)

	(* pc: For now the incoming chunks s1 & s2 MUST be sorted individually	 *)
	(* if the result does not get sorted (may only happen, if you offend precondition pc),
	MergeSortedChunkreal returns FALSE otherwise TRUE *)
	(* d is really a NEW Chunk, i.e. memory is really allocated, be careful with iterative techinques,
	one could think of changing s1,s2 *)

	VAR i1, i2, r1id, r2id, length, i: index;  c1, c2, d: tBuf;  c1id, c2id, did: vyLongintVec.tBuf;
		done, c1ended, c2ended, c2used, sorted: BOOLEAN;  r1, r2, lastr: real;  cinter: vyBase.tBuf;  v, v1: tVector;

		PROCEDURE GetNextLongreal( VAR c: tBuf;  VAR cid: vyLongintVec.tBuf;  VAR i: index;  VAR r: real;  VAR rid: index ): BOOLEAN;
		VAR ctemp: tBuf;  ctempid: vyLongintVec.tBuf;
		BEGIN
			IF c = NIL THEN RETURN FALSE END;
			WHILE (i = c.usedentries) DO
				i := 0;  cinter := vyBase.NextBuf( c );  c := tcX( cinter );  cinter := vyBase.NextBuf( cid );
				cid := vyLongintVec.tcL( cinter );
				IF c = NIL THEN RETURN FALSE END
			END;
			ctemp := c;  ctempid := cid;   (* hack to avoid warnings *)
			r := ctemp.data[i];  rid := ctempid( vyLongintVec.tBuf ).data[i];  INC( i );
			IF i = c.usedentries THEN
				i := 0;  cinter := vyBase.NextBuf( c );  c := tcX( cinter );  cinter := vyBase.NextBuf( cid );
				cid := vyLongintVec.tcL( cinter )
			END;
			RETURN TRUE
		END GetNextLongreal;

		PROCEDURE store( r: real;  rid: index ): BOOLEAN;
		BEGIN
			v.buf := d;  Append( r, v );  v.buf := did;  vyLongintVec.Append( rid, v );
			IF lastr <= r THEN lastr := r;  RETURN TRUE ELSE lastr := r;  RETURN FALSE END
		END store;

	BEGIN
		i1 := 0;  i2 := 0;  c1 := s1;  c2 := s2;  c1id := s1id;  c2id := s2id;  done := FALSE;  sorted := TRUE;
		length := vyBase.GetUsedEntries( c1 ) + vyBase.GetUsedEntries( c2 );  d := NewBufs( length );
		did := vyLongintVec.NewBufs( length );  c1ended := ~GetNextLongreal( c1, c1id, i1, r1, r1id );
		c2ended := ~GetNextLongreal( c2, c2id, i2, r2, r2id );  lastr := MIN( real );  NEW( v );
		REPEAT
			IF c1ended THEN
				IF c2ended THEN done := TRUE
				ELSE sorted := (store( r2, r2id ) & sorted);  c2ended := ~GetNextLongreal( c2, c2id, i2, r2, r2id )
				END
			ELSIF c2ended THEN sorted := (store( r1, r1id ) & sorted);  c1ended := ~GetNextLongreal( c1, c1id, i1, r1, r1id )
			ELSE
				IF r1 <= r2 THEN sorted := (store( r1, r1id ) & sorted);  c1ended := ~GetNextLongreal( c1, c1id, i1, r1, r1id )
				ELSE sorted := (store( r2, r2id ) & sorted);  c2ended := ~GetNextLongreal( c2, c2id, i2, r2, r2id )
				END
			END
		UNTIL done;
		IF ~sorted THEN RETURN FALSE END;
		c1 := s1;  c2 := s2;  c1id := s1id;  c2id := s2id;  c2used := FALSE;
		WHILE (c1 # NIL ) DO
			c1.cache := NIL;  c1.usedentries := 0;
			c1id.usedentries := 0;   (* fof 971124 *)
			IF vyBase.NextBuf( c1 ) = NIL THEN
				IF ~c2used THEN c1.next := c2;  c1id.next := c2id;  c2used := TRUE END
			END;
			cinter := vyBase.NextBuf( c1 );  c1 := tcX( cinter );  cinter := vyBase.NextBuf( c1id );
			c1id := vyLongintVec.tcL( cinter )
		END;
		c1 := s1;  c1id := s1id;  i := 0;  NEW( v1 );
		WHILE (i < length) DO
			v.buf := c1;  v1.buf := d;  Append( Get( v1, i ), v );  v.buf := c1id;  v1.buf := did;
			vyLongintVec.Append( vyLongintVec.Get( v1, i ), v );  INC( i )
		END;
		RETURN TRUE
	END MergeSortedChunkLONGREALWId;

	PROCEDURE OrderedLongReal( left, right: vyBase.tBuf ): BOOLEAN;
	VAR lmin, rmin: tMinMaxCache;
	BEGIN
		lmin := BufMinMax( left );  rmin := BufMinMax( right );  RETURN lmin.min <= rmin.min
	END OrderedLongReal;

	PROCEDURE SortBuf*( VAR chunk: tBuf );

	(* v0r0a1, Felix O. Friedrich 31.8.95 *)

	(* This algorithm tries to get advantage of individually sorted chunks *)
	(* hard precondition (pc1): consistency of chunk.min and chunk.max ! *)
	(* weak precondition (pc2): get the chunks sorted individually before applying this algorithm,
	it will work if you don't, but it's slower then !*)

	(*	That's the way this algorithm works:
	1. Sort the queue of chunks by minimal value of each single chunk (-> pc1)
	2. Get various non-overlapping queues of chunks (i.e. chunk[i].max <= chunk[i+1].min)
	3. MergeSortedChunkreal (non-overlapping queues) (-> pc2)
	4. IF 3.returns FALSE sort the chunks individually
	*)


	VAR root: vyBase.tBuf;

		cinter: vyBase.tBuf;

		PROCEDURE SortTheChunks( c: tBuf ): tBuf;
		(* get non-overlapping queues of chunks (c1,c2) and merge sorted afterwards, iterative *)
		VAR ch1, ch2, tmp1, tmp2, tmp: tBuf;  sorted: BOOLEAN;  tnm, tm: tMinMaxCache;
		BEGIN
			ch1 := c;  ch2 := NIL;  tmp1 := ch1;
			WHILE (tmp1.next # NIL ) DO
				cinter := vyBase.NextBuf( tmp1.next );  tmp := tcX( cinter );  tnm := BufMinMax( tmp1.next );
				tm := BufMinMax( tmp1 );
				IF tnm.min < tm.max THEN
					IF ch2 = NIL THEN ch2 := tmp1.next( tBuf );  tmp2 := ch2 ELSE tmp2.next := tmp1.next;  tmp2 := tmp2.next( tBuf ) END;
					tmp1.next := tmp
				ELSE  tmp1 := tmp1.next( tBuf )
				END
			END;
			IF ch2 = NIL THEN SortEachChunkLONGREAL( ch1 );  RETURN ch1
			ELSIF tmp2 # NIL THEN tmp2.next := NIL
			END;
			ch2 := SortTheChunks( ch2 );  sorted := (MergeSortedChunkLONGREAL( ch1, ch2 ));
			ASSERT ( sorted );
			RETURN ch1
		END SortTheChunks;

	BEGIN
		(* Sort Chunks by minimum value , increasing *)
		root := chunk;  vyBase.SortBufferList( root, OrderedLongReal );  chunk := SortTheChunks( root( tBuf ) )
	END SortBuf;

	PROCEDURE SortBufWId*( VAR chunk: tBuf;  VAR chunkid: vyLongintVec.tBuf );

	(* v0r0a1, Felix O. Friedrich 31.8.95 *)

	(* This algorithm tries to get advantage of individually sorted chunks *)
	(* hard precondition (pc1): consistency of chunk.min and chunk.max ! *)
	(* weak precondition (pc2): get the chunks sorted individually before applying this algorithm,
	it will work if you don't, but it's slower then !*)

	(*	That's the way this algorithm works:
	1. Sort the queue of chunks by minimal value of each single chunk (-> pc1)
	2. Get various non-overlapping queues of chunks (i.e. chunk[i].max <= chunk[i+1].min)
	3. MergeSortedChunkreal (non-overlapping queues) (-> pc2)
	4. IF 3.returns FALSE sort the chunks individually
	*)


	VAR this, root, c2, c3, t1, t2: tBuf;  rootid, thisid, c2id, c3id, t1id, t2id: vyLongintVec.tBuf;  cinter: vyBase.tBuf;
		c2m, t1m, t2m: tMinMaxCache;

		PROCEDURE SortTheChunksWId( c: tBuf;  VAR cid: vyLongintVec.tBuf ): tBuf;
		(* get non-overlapping queues of chunks (c1,c2) and merge sorted afterwards, iterative *)
		VAR ch1, ch2, tmp1, tmp2, tmp: tBuf;  sorted: BOOLEAN;  ch1id, ch2id, tmp1id, tmp2id, tmpid: vyLongintVec.tBuf;
			tnm, tm: tMinMaxCache;
		BEGIN
			ch1 := c;  ch2 := NIL;  tmp1 := ch1;  ch1id := cid;  ch2id := NIL;  tmp1id := ch1id;
			WHILE (tmp1.next # NIL ) DO
				cinter := vyBase.NextBuf( tmp1.next );  tmp := tcX( cinter );  cinter := vyBase.NextBuf( tmp1id.next );
				tmpid := vyLongintVec.tcL( cinter );  tnm := BufMinMax( tmp1.next );  tm := BufMinMax( tmp1 );

				IF tnm.min < tm.max THEN
					IF ch2 = NIL THEN
						ch2 := tmp1.next( tBuf );  tmp2 := ch2;  ch2id := tmp1id.next( vyLongintVec.tBuf );  tmp2id := ch2id
					ELSE
						tmp2.next := tmp1.next;  tmp2 := tmp2.next( tBuf );  tmp2id.next := tmp1id.next;
						tmp2id := tmp2id.next( vyLongintVec.tBuf )
					END;
					tmp1.next := tmp;  tmp1id.next := tmpid
				ELSE  tmp1 := tmp1.next( tBuf );  tmp1id := tmp1id.next( vyLongintVec.tBuf )
				END
			END;
			IF ch2 = NIL THEN SortEachChunkLONGREALWId( ch1, ch1id );  cid := ch1id;  RETURN ch1
			ELSIF tmp2 # NIL THEN tmp2.next := NIL;  tmp2id.next := NIL
			END;
			ch2 := SortTheChunksWId( ch2, ch2id );  sorted := (MergeSortedChunkLONGREALWId( ch1, ch2, ch1id, ch2id ));
			ASSERT ( sorted );
			cid := ch1id;  RETURN ch1
		END SortTheChunksWId;

	BEGIN
		(* Sort Chunks by minimum value , increasing *)
		root := chunk;  this := root;  rootid := chunkid;  thisid := rootid;
		IF this = NIL THEN RETURN END;
		WHILE (this # NIL ) & (this.next # NIL ) DO
			c2 := this.next( tBuf );  cinter := vyBase.NextBuf( vyBase.NextBuf( this ) );  c3 := tcX( cinter );  t1 := root;
			c2id := thisid.next( vyLongintVec.tBuf );  cinter := vyBase.NextBuf( vyBase.NextBuf( thisid ) );
			c3id := vyLongintVec.tcL( cinter );  t1id := rootid;  c2m := BufMinMax( c2 );  t1m := BufMinMax( t1 );
			IF c2m.min <= t1m.min THEN
				c2.next := t1;  root := c2;  this.next := c3;  c2id.next := t1id;  rootid := c2id;  thisid.next := c3id
			ELSE
				LOOP
					cinter := vyBase.NextBuf( t1 );  t2 := tcX( cinter );  cinter := vyBase.NextBuf( t1id );
					t2id := vyLongintVec.tcL( cinter );  c2m := BufMinMax( c2 );  t2m := BufMinMax( t2 );
					IF c2m.min < t2m.min THEN
						c2.next := t2;  t1.next := c2;  this.next := c3;  c2id.next := t2id;  t1id.next := c2id;  thisid.next := c3id;  EXIT
					END;
					t1 := t2;  t1id := t2id;
					IF (t1 = this.next) THEN
						cinter := vyBase.NextBuf( this );  this := tcX( cinter );  cinter := vyBase.NextBuf( thisid );
						thisid := vyLongintVec.tcL( cinter );  EXIT
					END
				END
			END
		END;
		chunk := SortTheChunksWId( root, rootid );  chunkid := rootid
	END SortBufWId;

	PROCEDURE Sort*( VAR v: tVector );   (*vs 0.1d0 gs*)
	(*! check for sorting algorithms. Quicksort within chunks, merge between ? *)
	(*! sort for boolean needed ? *)
	(*! incorrect. does not work for mixied vectors. To correct!!! *)
	VAR chunk: vyBase.tBuf;  tcx: tBuf;
	BEGIN
		IF (v = NIL ) OR (v.buf = NIL ) THEN RETURN END;
		chunk := v.buf;   (* hack to avoid error messages *)
		ASSERT ( chunk IS tBuf, 100 );
		tcx := v.buf( tBuf );  SortEachChunkLONGREAL( tcx );
		IF chunk.next # NIL THEN
			SortBuf( tcx );
			v.buf := tcx (* fof , 970405 *)
		END
	END Sort;

	(*! Only useful for vyLongintVec because v is assumed to be an vyLongintVec.tVector.
PROCEDURE SortById* (VAR v: tVector;  VAR WId: vyBase.tVector);*)
(*	(*= Sorts a longint chunk by a longint chunk *)
(*! sort and generate a vector of id keys *)
(*! check. misnomer ? *)
VAR chunk, chunkid: vyBase.tBuf;
tcI, tcIid: vyLongintVec.tBuf;
BEGIN
IF (v = NIL) OR (v.buf = NIL) OR (WId = NIL) OR (WId.buf = NIL) THEN RETURN END;
ASSERT(v.nrData = WId.nrData,100);
chunk := v.buf;   (* hack to avoid error messages *)
chunkid := WId.buf;ASSERT(chunkid IS vyLongintVec.tBuf,101);
IF (chunk IS (vyLongintVec.tBuf) THEN
tcI := v.buf(vyLongintVec.tBuf);   (* fof for Ob S3 Windows 960528*)
tcIid := WId.buf(vyLongintVec.tBuf);
vyLongintVec.SortEachChunkLONGINTWId(tcIid, tcI);
IF chunk.next # NIL THEN
vyLongintVec.SortBufWId(tcIid, tcI)
END
ELSE v.status := v.status +{cBadType};
END
END SortById;*)

	PROCEDURE SortWId*( VAR v: vyBase.tVector;  VAR WId: vyBase.tVector );
	(*= Index must be a longint chunk *)
	(* ! rearrange a vector by id keys *)
	VAR chunk, chunkid: vyBase.tBuf;  tcx: tBuf;  tclid: vyLongintVec.tBuf;
	BEGIN
		IF (v = NIL ) OR (v.buf = NIL ) OR (WId = NIL ) OR (WId.buf = NIL ) THEN RETURN END;
		ASSERT ( v.nrData = WId.nrData, 100 );
		chunk := v.buf;   (* hack to avoid error messages *)
		chunkid := WId.buf;
		ASSERT ( chunkid IS vyLongintVec.tBuf, 101 );
		tcx := v.buf( tBuf );   (* fof for Ob S3 Windows 960528*)
		tclid := WId.buf( vyLongintVec.tBuf );  SortEachChunkLONGREALWId( tcx, tclid );
		IF chunk.next # NIL THEN
			SortBufWId( tcx, tclid );
			v.buf := tcx;   (* fof 971006 *)
			WId.buf := tclid (* fof 971121 *)
		END
	END SortWId;

(** Misc *)

	PROCEDURE Fill*( v: vyBase.tVector;  val: real;  offs, count: index );
	(*= Fill vector with constant val *)
	VAR i: index;
	BEGIN
		FOR i := offs TO offs + count - 1 DO Set( val, v, i ) END
	END Fill;

	PROCEDURE NewFilledNamed*( count: LONGINT;  val: real;  name: ARRAY OF CHAR ): tVector;
	VAR v: tVector;
	BEGIN
		v := New( count );  Fill( v, val, 0, count );  vyName.Register( vyName.NameBase, v, name );  RETURN v
	END NewFilledNamed;

	PROCEDURE SSQ*( x, y: vyBase.tVector ): LONGREAL;
	(*= Return centered sum of squares *)
	(*! add error handling *)
	VAR xcx, ycx: tBuf;  s, mx, my: LONGREAL;  i, cur: index;  xcxmean, ycxmean: tMeanCache;
	BEGIN
		s := 0;  i := 0;  cur := 0;  mx := 0;  my := 0;  vyBase.GC( 0, x, 0 );  vyBase.GC( 0, y, 0 );
		WITH x: tVector DO xcx := x.buf( tBuf );  ycx := y.buf( tBuf );
			ASSERT ( x.nrData = y.nrData );
			WHILE xcx # NIL DO
				xcxmean := BufMean( xcx );  mx := mx + (xcxmean.mean - mx) / (cur + xcx.usedentries) * xcx.usedentries;
				cur := cur + (cur + xcx.usedentries);
				IF xcx.next # NIL THEN xcx := xcx.next( tBuf ) ELSE xcx := NIL END
			END;
			cur := 0;
			WHILE ycx # NIL DO
				ycxmean := BufMean( ycx );  my := my + (ycxmean.mean - my) / (cur + ycx.usedentries) * ycx.usedentries;
				cur := cur + (cur + ycx.usedentries);
				IF ycx.next # NIL THEN ycx := ycx.next( tBuf ) ELSE ycx := NIL END
			END;
			xcx := x.buf( tBuf );  ycx := y.buf( tBuf );
			WHILE i < x.nrData DO s := s + (Get( x, i ) - mx) * (Get( y, i ) - my);  INC( i ) END
		END;
		RETURN s
	END SSQ;

	PROCEDURE WriteChunk( VAR w: vyBase.TextsWriter;  chunk: vyBase.tBuf );
	CONST defprec = 10;   (*! replace by data driven choice *)
	BEGIN
		WHILE chunk # NIL DO
			vyHostTexts.WriteLongRealTab( w, chunk.usedentries, chunk( tBuf ).data^, 0, defprec );  chunk := chunk.next
		END
	END WriteChunk;

	PROCEDURE Write*( VAR w: vyBase.TextsWriter;  v: vyBase.tData );
	BEGIN
		IF v IS vyBase.tVector THEN
			WITH v: vyBase.tVector DO WriteChunk( w, v.buf )
			END
		ELSE HALT( 100 )
			(*! add general write *)
		END
	END Write;

	(** Iterator support *)
	(*= Interface may change.*)
(*! consider reusing result objects *)
	PROCEDURE EvaluateCaseWise*( new: vyBase.tData;  regressor: vyBase.tData;  Function: Op1Function );
	(*= Returns a new data variable, of same structure as regressor, and applies Function by case *)
	VAR i: index;
	BEGIN
		(*! include more general model types, in particular multivariate regressors and responses *)
		ASSERT ( regressor IS tVector, 100 );
		ASSERT ( new IS tVector, 101 );
		WITH new: tVector DO
			WITH regressor: tVector DO
				SetLen( new, regressor.nrData );
				(*! optimize vector access for speed *)
				FOR i := 0 TO regressor.nrData - 1 DO Set( Function( Get( regressor, i ) ), new, i ) END
			END
		END
	END EvaluateCaseWise;

	PROCEDURE Scale*( new, x: vyBase.tData;  offs, fact: real );
	(*= Returns a new data variable, of same structure as regressor, with values  offs+x*fact*)
	VAR i: index;  bufnew, bufx: tBuf;  inew, ix: index;
	BEGIN
		(*! include more general model types, in particular multivariate regressors and responses *)
		ASSERT ( x IS tVector, 100 );
		ASSERT ( new IS tVector, 101 );
		WITH new: tVector DO
			WITH x: tVector DO
				SetLen( new, x.nrData );
				(*! optimize vector access for speed *)
				bufnew := new.buf( tBuf );  bufx := x.buf( tBuf );  inew := 0;  ix := 0;
				IF bufnew # NIL THEN bufnew.cache := NIL END;
				FOR i := 0 TO x.nrData - 1 DO  (*Set(offs + Get(x, i) * fact, new, i) *)
					WHILE inew >= bufnew.usedentries DO
						IF bufnew.next # NIL THEN bufnew := bufnew.next( tBuf );  bufnew.cache := NIL ELSE bufnew := NIL END;
						inew := 0
					END;
					WHILE ix >= bufx.usedentries DO
						IF bufx.next # NIL THEN bufx := bufx.next( tBuf ) ELSE bufx := NIL END;
						ix := 0
					END;

					bufnew.data[inew] := bufx.data[ix] * fact + offs;  INC( inew );  INC( ix )
				END
			END
		END
	END Scale;

	PROCEDURE Add*( new, x, y: vyBase.tData );
	(*= Sets new data to len of x y, of same structure as regressor, with values x+y *)
	VAR i: index;  bufnew, bufx, bufy: tBuf;  inew, ix, iy: index;
		temp1, temp2: LONGREAL;   (* messy hack: not enough registers in Intel *)
	BEGIN
		(*! include more general model types, in particular multivariate regressors and responses *)
		ASSERT ( x IS tVector, 100 );
		ASSERT ( x IS tVector, 101 );
		WITH new: tVector DO
			WITH x: tVector DO
				WITH y: tVector DO
					ASSERT ( x.nrData = y.nrData, 102 );
					SetLen( new, x.nrData );
					(*! optimize vector access for speed *)
					bufnew := new.buf( tBuf );  bufx := x.buf( tBuf );  bufy := y.buf( tBuf );  inew := 0;  ix := 0;  iy := 0;
					IF bufnew # NIL THEN bufnew.cache := NIL END;
					FOR i := 0 TO x.nrData - 1 DO
						WHILE inew >= bufnew.usedentries DO
							IF bufnew.next # NIL THEN bufnew := bufnew.next( tBuf );  bufnew.cache := NIL ELSE bufnew := NIL END;
							inew := 0
						END;
						WHILE ix >= bufx.usedentries DO
							IF bufx.next # NIL THEN bufx := bufx.next( tBuf ) ELSE bufx := NIL END;
							ix := 0
						END;
						WHILE iy >= bufy.usedentries DO
							IF bufy.next # NIL THEN bufy := bufy.next( tBuf ) ELSE bufy := NIL END;
							iy := 0
						END;
						(*
					bufnew.data[inew]:=bufx.data[ix]+bufy.data[iy]; *)
						temp1 := bufx.data[ix];  temp2 := bufy.data[iy];
						bufnew.data[inew] := temp1 + temp2;   (*fof simplified expression due to "not enough registers"*)
						INC( inew );  INC( ix );  INC( iy )
					END
				END
			END
		END
	END Add;

	PROCEDURE Sub*( new, x, y: vyBase.tData );
	(*= Sets new data to len of x y, of same structure as regressor, with values x-y *)
	VAR i: index;  bufnew, bufx, bufy: tBuf;  inew, ix, iy: index;  temp1, temp2: LONGREAL;
	BEGIN
		(*! include more general model types, in particular multivariate regressors and responses *)
		ASSERT ( x IS tVector, 100 );
		ASSERT ( x IS tVector, 101 );
		WITH new: tVector DO
			WITH x: tVector DO
				WITH y: tVector DO
					ASSERT ( x.nrData = y.nrData, 102 );
					SetLen( new, x.nrData );
					(*! optimize vector access for speed *)
					bufnew := new.buf( tBuf );  bufx := x.buf( tBuf );  bufy := y.buf( tBuf );  inew := 0;  ix := 0;  iy := 0;
					IF bufnew # NIL THEN bufnew.cache := NIL END;
					FOR i := 0 TO x.nrData - 1 DO
						WHILE inew >= bufnew.usedentries DO
							IF bufnew.next # NIL THEN bufnew := bufnew.next( tBuf );  bufnew.cache := NIL ELSE bufnew := NIL END;
							inew := 0
						END;
						WHILE ix >= bufx.usedentries DO
							IF bufx.next # NIL THEN bufx := bufx.next( tBuf ) ELSE bufx := NIL END;
							ix := 0
						END;
						WHILE iy >= bufy.usedentries DO
							IF bufy.next # NIL THEN bufy := bufy.next( tBuf ) ELSE bufy := NIL END;
							iy := 0
						END;

						(*bufnew.data[inew]:=bufx.data[ix]-bufy.data[iy]; *)
						temp1 := bufx.data[ix];  temp2 := bufy.data[iy];
						bufnew.data[inew] := temp1 - temp2;   (*fof simplified expression due to "not enough registers"*)

						INC( inew );  INC( ix );  INC( iy )
					END
				END
			END
		END
	END Sub;

(*
PROCEDURE Sub* (new, x, y: vyBase.tData );
(*= Returns a new data variable, of same structure as regressor, with values x-y *)
VAR i: index;
BEGIN
(*! include more general model types, in particular multivariate regressors and responses *)
ASSERT(x IS tVector, 100);   ASSERT(x IS tVector, 101);
WITH new: tVector DO	WITH x: tVector DO WITH y: tVector DO ASSERT(x.nrData = y.nrData, 102);
SetLen(new, x.nrData);
(*! optimize vector access for speed *)
FOR i := 0 TO x.nrData - 1 DO Set(Get(x, i) - Get(y, i), new, i) END
END END  END
END Sub;
*)

	PROCEDURE Mult*( new, x, y: vyBase.tData );
	(*= Sets new data to len of x y, of same structure as regressor, with values x*y *)
	VAR i: index;  bufnew, bufx, bufy: tBuf;  inew, ix, iy: index;  temp1, temp2: LONGREAL;
	BEGIN
		(*! include more general model types, in particular multivariate regressors and responses *)
		ASSERT ( x IS tVector, 100 );
		ASSERT ( x IS tVector, 101 );
		WITH new: tVector DO
			WITH x: tVector DO
				WITH y: tVector DO
					ASSERT ( x.nrData = y.nrData, 102 );
					SetLen( new, x.nrData );
					(*! optimize vector access for speed *)
					bufnew := new.buf( tBuf );  bufx := x.buf( tBuf );  bufy := y.buf( tBuf );  inew := 0;  ix := 0;  iy := 0;
					IF bufnew # NIL THEN bufnew.cache := NIL END;
					FOR i := 0 TO x.nrData - 1 DO
						WHILE inew >= bufnew.usedentries DO
							IF bufnew.next # NIL THEN bufnew := bufnew.next( tBuf );  bufnew.cache := NIL ELSE bufnew := NIL END;
							inew := 0
						END;
						WHILE ix >= bufx.usedentries DO
							IF bufx.next # NIL THEN bufx := bufx.next( tBuf ) ELSE bufx := NIL END;
							ix := 0
						END;
						WHILE iy >= bufy.usedentries DO
							IF bufy.next # NIL THEN bufy := bufy.next( tBuf ) ELSE bufy := NIL END;
							iy := 0
						END;
						(*
					bufnew.data[inew]:=bufx.data[ix]*bufy.data[iy]; *)
						temp1 := bufx.data[ix];  temp2 := bufy.data[iy];
						bufnew.data[inew] := temp1 * temp2;   (*fof simplified expression due to "not enough registers"*)

						INC( inew );  INC( ix );  INC( iy )
					END
				END
			END
		END
	END Mult;

	PROCEDURE Div*( new, x, y: vyBase.tData );
	(*= Sets new data to len of x y, of same structure as regressor, with values x/y *)
	VAR i: index;  bufnew, bufx, bufy: tBuf;  inew, ix, iy: index;  temp1, temp2: LONGREAL;
	BEGIN
		(*! include more general model types, in particular multivariate regressors and responses *)
		ASSERT ( x IS tVector, 100 );
		ASSERT ( x IS tVector, 101 );
		WITH new: tVector DO
			WITH x: tVector DO
				WITH y: tVector DO
					ASSERT ( x.nrData = y.nrData, 102 );
					SetLen( new, x.nrData );
					(*! optimize vector access for speed *)
					bufnew := new.buf( tBuf );  bufx := x.buf( tBuf );  bufy := y.buf( tBuf );  inew := 0;  ix := 0;  iy := 0;
					IF bufnew # NIL THEN bufnew.cache := NIL END;
					FOR i := 0 TO x.nrData - 1 DO
						WHILE inew >= bufnew.usedentries DO
							IF bufnew.next # NIL THEN bufnew := bufnew.next( tBuf );  bufnew.cache := NIL ELSE bufnew := NIL END;
							inew := 0
						END;
						WHILE ix >= bufx.usedentries DO
							IF bufx.next # NIL THEN bufx := bufx.next( tBuf ) ELSE bufx := NIL END;
							ix := 0
						END;
						WHILE iy >= bufy.usedentries DO
							IF bufy.next # NIL THEN bufy := bufy.next( tBuf ) ELSE bufy := NIL END;
							iy := 0
						END;

						(*bufnew.data[inew]:=bufx.data[ix]/bufy.data[iy]; *)
						temp1 := bufx.data[ix];  temp2 := bufy.data[iy];
						bufnew.data[inew] := temp1 / temp2;   (*fof simplified expression due to "not enough registers"*)

						INC( inew );  INC( ix );  INC( iy )
					END
				END
			END
		END
	END Div;

(** Norms and  distances *)
	PROCEDURE Norm1*( v: vyBase.tVector ): LONGREAL;
	VAR chunk: tBuf;  norm: LONGREAL;
	BEGIN
		IF v = NIL THEN RETURN 0 END;
		ASSERT ( v IS tVector, 100 );
		chunk := v.buf( tBuf );  norm := 0;
		WHILE chunk # NIL DO
			norm := norm + vyreal.Norm1( chunk.usedentries, chunk.data^, 0 );
			IF (chunk.next # NIL ) THEN chunk := chunk.next( tBuf ) ELSE RETURN norm END
		END
	END Norm1;

	PROCEDURE Norm2Sq*( v: vyBase.tVector ): LONGREAL;
	VAR norm: LONGREAL;  chunk: tBuf;
	BEGIN
		IF v = NIL THEN RETURN 0 END;
		ASSERT ( v IS tVector, 100 );
		chunk := v.buf( tBuf );  norm := 0;
		WHILE chunk # NIL DO
			norm := norm + vyreal.Norm2Sq( chunk.usedentries, chunk.data^, 0 );
			IF (chunk.next # NIL ) THEN chunk := chunk.next( tBuf ) ELSE RETURN norm END
		END
	END Norm2Sq;

	PROCEDURE NormSup*( v: vyBase.tVector ): LONGREAL;
	VAR min, max: LONGREAL;  nrNaNs: LONGINT;
	BEGIN
		IF v = NIL THEN RETURN 0 END;
		ASSERT ( v IS tVector, 100 );
		GetMinMax( v, min, max, nrNaNs );
		IF min < -max THEN RETURN -min ELSE RETURN max END
	END NormSup;

	PROCEDURE adddist1( VAR piececount: LONGINT;  VAR srcchunk: vyBase.tBuf;  VAR srcloc: LONGINT;  VAR destchunk: vyBase.tBuf;  VAR destloc: LONGINT );
	BEGIN
		globallongreal :=
			globallongreal + vyreal.Dist1( piececount, srcchunk( tBuf ).data^, srcloc, destchunk( tBuf ).data^, destloc )
	END adddist1;

	PROCEDURE Dist1*( v, w: vyBase.tVector ): LONGREAL;
	BEGIN
		IF (v = NIL ) & (w = NIL ) THEN RETURN 0 END;
		ASSERT ( (v IS tVector) & (w IS tVector), 100 );
		globallongreal := 0;  vyBase.DoToAllPieces( v, w, adddist1 );  RETURN globallongreal
	END Dist1;

	PROCEDURE adddist2( VAR piececount: LONGINT;  VAR srcchunk: vyBase.tBuf;  VAR srcloc: LONGINT;  VAR destchunk: vyBase.tBuf;  VAR destloc: LONGINT );
	BEGIN
		globallongreal :=
			globallongreal + vyreal.Dist2Sq( piececount, srcchunk( tBuf ).data^, srcloc, destchunk( tBuf ).data^, destloc )
	END adddist2;

	PROCEDURE Dist2Sq*( v, w: vyBase.tVector ): LONGREAL;
	BEGIN
		IF (v = NIL ) & (w = NIL ) THEN RETURN 0 END;
		ASSERT ( (v IS tVector) & (w IS tVector), 100 );
		globallongreal := 0;  vyBase.DoToAllPieces( v, w, adddist2 );  RETURN globallongreal
	END Dist2Sq;

	PROCEDURE adddistsup( VAR piececount: LONGINT;  VAR srcchunk: vyBase.tBuf;  VAR srcloc: LONGINT;  VAR destchunk: vyBase.tBuf;
										  VAR destloc: LONGINT );
	VAR temp: LONGREAL;
	BEGIN
		temp := vyreal.Dist1( piececount, srcchunk( tBuf ).data^, srcloc, destchunk( tBuf ).data^, destloc );
		IF temp > globallongreal THEN globallongreal := temp END
	END adddistsup;

	PROCEDURE DistSup*( v, w: vyBase.tVector ): LONGREAL;
	BEGIN
		IF (v = NIL ) & (w = NIL ) THEN RETURN 0 END;
		ASSERT ( (v IS tVector) & (w IS tVector), 100 );
		globallongreal := 0;  vyBase.DoToAllPieces( v, w, adddistsup );  RETURN globallongreal
	END DistSup;

	(** Defs from vyTypes2 *)
	(*= vyTypes2 type system is defunct. Migrate to OPT type system *)

(*! More matrix procedures are available in vyRealVec but till now not tested.*)

	PROCEDURE ChunkSummary*( VAR w: vyBase.TextsWriter;  buf: vyBase.tBuf );
	VAR mm: tMinMaxCache;  mean: tMeanCache;
	BEGIN
		WHILE buf # NIL DO
			WITH buf: tBuf DO
				mm := BufMinMax( buf );  mean := BufMean( buf );  vyHostTexts.WriteInt( w, buf.len );
				vyHostTexts.WriteInt( w, buf.usedentries );  vyHostTexts.WriteReal( w, mm.min );
				vyHostTexts.WriteReal( w, mm.max );  vyHostTexts.WriteInt( w, mm.nans );
				vyHostTexts.WriteReal( w, mean.mean );  vyHostTexts.WriteReal( w, mean.ssq )

				(*
		vyHostTexts.SummaryLongreal(w, buf.usedentries, buf(tBuf).data^, defprec);    *)
			END;
			buf := buf.next
		END
	END ChunkSummary;

END vyLongrealVec.
