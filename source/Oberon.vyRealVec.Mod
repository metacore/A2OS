MODULE vyRealVec IN Oberon;   (*=     gs **)
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



IMPORT Files, Objects, Texts, vyBase, vyName, vyHostTexts, vyreal := vyReal, vyLongintVec;

CONST
	idversion* = "vyRealVec 0.0a4";   (* may be maintained or changed by tools *)
TYPE
	index* = SIGNED32;

	(* FLOAT32 *)  (* preferred chunk sizes: 128, 1024, 8192 *)
	real* = FLOAT32;   (* technical convenience, to avoid duplicate code for FLOAT32 and FLOAT64 *)

	Real = vyBase.Real;

	tVector* = POINTER TO tVectorDesc;
	tVectorDesc* = RECORD (vyBase.tVectorDesc) END;

	tREAL* = POINTER TO tREALDesc;
	tREALDesc* = RECORD (vyBase.tDataDesc)
		x*: real
	END;

	tMinMaxCache* = POINTER TO tMinMaxCacheDesc;
	tMinMaxCacheDesc* = RECORD (vyBase.tCacheDesc)
		min-, max-: real;
		minpos, maxpos, nans: SIGNED32;   (*convenience. Valid if nans>=0 *)
	END;

	tMeanCache* = POINTER TO tMeanCacheDesc;
	tMeanCacheDesc* = RECORD (vyBase.tCacheDesc)
		mean-, ssq-: FLOAT64;   (* Valid if nans>=0 & ssq>=0 *)
		nans-: SIGNED32
	END;

	tBuf* = POINTER TO tBufDesc;
	tBufDesc* = RECORD (vyBase.tBufDesc)
		data-: POINTER TO ARRAY OF real
	END;

	Op1Function* = PROCEDURE ( x: real ): real;
	ArrayOp1Function* = PROCEDURE ( VAR arg: ARRAY OF real );
	ArrayOp2Function* = PROCEDURE ( VAR arg1, arg2: ARRAY OF real );

	tMatrixChunk* = POINTER TO tMatrixChunkDesc;
	tMatrixChunkDesc* = RECORD
		row-, col-: index;
		data: vyBase.tVector
	END;

	tChunkedMatrix* = POINTER TO tChunkedMatrixDesc;
	tChunkedMatrixDesc* = RECORD (vyBase.ObjDesc)
		buf*: tMatrixChunk
	END;

VAR
	globallongreal: FLOAT64;   (* sneak global. handle with care! *)

	(** Defs from vyTypes2 *)
	(*= vyTypes is defunct. Migrate to OPT type system *)

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

(*
PROCEDURE NewBufs (size: index): tBuf;
VAR first, last: vyBase.tBuf;
chunk: tBuf;
PROCEDURE generic (ch: tBuf;     len: index);
BEGIN 	NEW(ch.data, len);   ch.str := vyBase.dynrealarray;
vyBase.GenericCatBuf(ch, len, size, first, last);
ch.mean := 0;      ch.ssq := invalSsq;      ch.min := MAX(real);      ch.max := MIN(real);
ch.nans := invalNrNans
END generic;

BEGIN first := NIL;
IF size = 0 THEN   NEW(chunk);  generic(chunk, 128)
ELSE
WHILE size >= 8192 DO NEW(chunk);     generic(chunk, 8192)  END;
WHILE size >= 1024 DO NEW(chunk);     generic(chunk, 1024)  END;
WHILE size > 0 DO NEW(chunk);     generic(chunk, 128)   END
END;
RETURN first(tBuf)
END NewBufs;
*)
	PROCEDURE NewBufs( size: index ): tBuf;
	VAR first, last: vyBase.tBuf;  chunk: tBuf;

		PROCEDURE generic( ch: tBuf;  len: SIGNED32 );
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

	(*
PROCEDURE FlushBufCaches (buf: vyBase.tBuf);
BEGIN
WITH buf: tBuf DO buf.nans := invalNrNans;  buf.ssq := invalSsq  END;
buf.cache := NIL
END FlushBufCaches;
*)
(*
PROCEDURE FlushVecCaches (vec: vyBase.tVector);
VAR buf: vyBase.tBuf;
BEGIN buf := vec.buf;  WHILE buf # NIL DO
FlushBufCaches(buf);
buf := buf.next END
END FlushVecCaches;

PROCEDURE FillBufMinCache (buf: vyBase.tBuf);
BEGIN IF buf # NIL THEN WITH buf: tBuf DO
vyreal.MinMax(buf.usedentries, buf(tBuf).data^, 0, buf.min, buf.minpos, buf.max, buf.maxpos, buf.nans)
END
END
END FillBufMinCache;

PROCEDURE FillBufMeanCache (buf: vyBase.tBuf);
VAR nans: SIGNED32;
BEGIN (* propagate nan handling *)
IF buf # NIL THEN WITH buf: tBuf DO
vyreal.MeanSSq(buf.usedentries, buf(tBuf).data^, 0, buf.mean, buf.ssq, nans)
END
END
END FillBufMeanCache;
*)

	PROCEDURE SetNrData( vec: tVector;  size: index );
	(* risky buffer reallocation. New buffer contents is undefined. *)
	BEGIN
		IF vec.nrData = size THEN RETURN END;
		vec.buf := NIL;  vec.nrData := 0;  vyBase.ApndChunks( NewBufs( size ), vec );  vec.nrData := size
	END SetNrData;

	PROCEDURE Store0( VAR R: Files.Rider;  o: tVector );
	(*! use vyReal Store*)
	VAR b: tBuf;  i: index;
	BEGIN
		Files.WriteLInt( R, o.nrData );  b := o.buf( tBuf );
		WHILE b # NIL DO
			IF b.usedentries > 0 THEN
				Files.WriteLInt( R, b.len );  Files.WriteLInt( R, b.usedentries );  i := 0;
				WHILE i < b.usedentries DO Files.WriteReal( R, b.data[i] );  INC( i ) END
			END;
			IF b.next # NIL THEN b := b.next( tBuf ) ELSE b := NIL END
		END;
		Files.WriteLInt( R, 0 )
	END Store0;

	PROCEDURE Store0REAL( VAR R: Files.Rider;  o: tREAL );
	BEGIN
		Files.WriteReal( R, o.x )
	END Store0REAL;

	PROCEDURE Store0ChunkedMatrix( VAR R: Files.Rider;  o: tChunkedMatrix );

	BEGIN
		Files.WriteLInt( R, o.buf.row );  Files.WriteLInt( R, o.buf.col )
	END Store0ChunkedMatrix;

	PROCEDURE Load0( VAR R: Files.Rider;  o: tVector );
	VAR b: tBuf;  i: index;  c: SIGNED32;
	BEGIN
		Files.ReadLInt( R, c );  o.nrData := c;  Files.ReadLInt( R, c );
		WHILE c # 0 DO
			b := NewBufs( c );   (* removed -1 fof 020213 *)
			b.len := c;  Files.ReadLInt( R, c );  b.usedentries := c;  i := 0;
			WHILE i < c DO Files.ReadReal( R, b.data[i] );  INC( i ) END;
			vyBase.ApndChunks( b, o );  Files.ReadLInt( R, c )
		END
	END Load0;

	PROCEDURE Load0REAL( VAR R: Files.Rider;  o: tREAL );
	BEGIN
		Files.ReadReal( R, o.x )
	END Load0REAL;

	PROCEDURE Load0ChunkedMatrix( VAR R: Files.Rider;  o: tChunkedMatrix );

	BEGIN
		IF o.buf = NIL THEN NEW( o.buf ) END;
		Files.ReadLInt( R, o.buf.row );  Files.ReadLInt( R, o.buf.col )
	END Load0ChunkedMatrix;

	PROCEDURE HandleAttributes( o: tVector;  VAR M: Objects.AttrMsg );
	BEGIN
		IF M.id = Objects.get THEN
			IF M.name = "Gen" THEN COPY( 'vyRealVec.Gen', M.s );  M.class := Objects.String;  M.res := 0 ELSE vyBase.VectorHandler( o, M ) END
		ELSIF M.id = Objects.set THEN vyBase.VectorHandler( o, M )
		ELSIF M.id = Objects.enum THEN vyBase.VectorHandler( o, M )
		ELSE vyBase.VectorHandler( o, M )
		END
	END HandleAttributes;

	PROCEDURE HandleAttributesChunkedMatrix( o: tChunkedMatrix;  VAR M: Objects.AttrMsg );
	BEGIN
		IF M.id = Objects.get THEN
			IF M.name = "Gen" THEN COPY( 'vyRealVec.GenMatrix', M.s );  M.class := Objects.String;  M.res := 0 ELSE vyBase.ObjectHandler( o, M ) END
		ELSIF M.id = Objects.set THEN vyBase.ObjectHandler( o, M )
		ELSIF M.id = Objects.enum THEN vyBase.ObjectHandler( o, M )
		ELSE vyBase.ObjectHandler( o, M )
		END
	END HandleAttributesChunkedMatrix;

	PROCEDURE HandleAttributesREAL( o: tREAL;  VAR M: Objects.AttrMsg );
	BEGIN
		IF M.id = Objects.get THEN
			IF M.name = "Gen" THEN COPY( 'vyRealVec.GenRealObject', M.s );  M.class := Objects.String;  M.res := 0
			ELSIF M.name = "x" THEN M.class := Objects.Real;  M.x := o.x;  M.res := 0
			ELSE vyBase.DataHandler( o, M )
			END
		ELSIF M.id = Objects.set THEN
			IF M.name = "x" THEN
				IF M.class = Objects.LongReal THEN o.x := SHORT( M.y );  M.res := 0
				ELSIF M.class = Objects.Real THEN o.x := M.x;  M.res := 0
				ELSE vyBase.DataHandler( o, M )
				END
			ELSE vyBase.DataHandler( o, M )
			END
		ELSIF M.id = Objects.enum THEN vyBase.DataHandler( o, M );  M.Enum( "x" )
		ELSE vyBase.DataHandler( o, M )
		END
	END HandleAttributesREAL;

	PROCEDURE REALHandler*( o: Objects.Object;  VAR M: Objects.ObjMsg );
	BEGIN
		WITH o: tREAL DO  (*! tREAL exists also in the Oberonsystem. tREAL should be dropped.*)
			IF M IS Objects.AttrMsg THEN
				WITH M: Objects.AttrMsg DO HandleAttributesREAL( o, M )
				END;
			ELSIF M IS Objects.FileMsg THEN
				WITH M: Objects.FileMsg DO
					IF M.id = Objects.load THEN Load0REAL( M.R, o );  vyBase.DataHandler( o, M )
					ELSIF M.id = Objects.store THEN Store0REAL( M.R, o );  vyBase.DataHandler( o, M )
					ELSE vyBase.DataHandler( o, M )
					END  (*IF*)
				END;
			ELSE vyBase.DataHandler( o, M )
			END  (* WITH Msg*)
		END
	END REALHandler;

	PROCEDURE MatrixHandler*( o: Objects.Object;  VAR M: Objects.ObjMsg );
	BEGIN
		WITH o: tChunkedMatrix DO
			IF M IS Objects.AttrMsg THEN
				WITH M: Objects.AttrMsg DO HandleAttributesChunkedMatrix( o, M )
				END;
			ELSIF M IS Objects.FileMsg THEN
				WITH M: Objects.FileMsg DO
					IF M.id = Objects.load THEN
						Load0ChunkedMatrix( M.R, o );
						IF o.buf.data = NIL THEN Gen;  o.buf.data := Objects.NewObj( tVector ) END;
						o.buf.data.handle( o.buf.data, M );  vyBase.ObjectHandler( o, M )
					ELSIF M.id = Objects.store THEN
						Store0ChunkedMatrix( M.R, o );  o.buf.data.handle( o.buf.data, M );  vyBase.ObjectHandler( o, M )
					ELSE vyBase.ObjectHandler( o, M )
					END  (*IF*)
				END;
			ELSE vyBase.ObjectHandler( o, M )
			END  (* WITH*)
		END  (* WITH*)

	END MatrixHandler;

	PROCEDURE Handler*( o: Objects.Object;  VAR M: Objects.ObjMsg );
	VAR copy: tVector;
	BEGIN
		WITH o: tVector DO
			IF M IS Objects.AttrMsg THEN
				WITH M: Objects.AttrMsg DO HandleAttributes( o, M )
				END;
			ELSIF M IS Objects.CopyMsg THEN
				WITH M: Objects.CopyMsg DO  (* fof 020712 *)
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
			END  (* WITH M*)
		END  (* WITH*)
	END Handler;

	PROCEDURE Gen*;
	VAR v: tVector;
	BEGIN
		NEW( v );  v.handle := Handler;  Objects.NewObj := v
	END Gen;

	PROCEDURE GenRealObject*;
	VAR o: tREAL;
	BEGIN
		NEW( o );  o.handle := REALHandler;  Objects.NewObj := o
	END GenRealObject;

	PROCEDURE GenMatrix*;
	VAR o: tChunkedMatrix;
	BEGIN
		NEW( o );  o.handle := MatrixHandler;  Objects.NewObj := o
	END GenMatrix;

	PROCEDURE NewRealObject*( x: real ): tREAL;
	VAR o: tREAL;
	BEGIN
		GenRealObject;  o := Objects.NewObj( tREAL );  o.x := x;  o.type := vyBase.realtyp;  o.storagetype := vyBase.realtyp;
		RETURN o
	END NewRealObject;

	(** Vector allocation *)
(*! set to nil if buffer cannot be allocated *)
	PROCEDURE New*( size: index ): tVector;
	(*= create a new vector, and mark size *)
	VAR v: tVector;
	BEGIN
		Gen;  v := Objects.NewObj( tVector );  vyBase.ApndChunks( NewBufs( size ), v );  vyBase.MarkUsed( size, v );  RETURN v
	END New;

	PROCEDURE GC*( vec: vyBase.tVector );
	(*= rearrange internal storage, if possible *)
	END GC;

	PROCEDURE Allocate*( vec: vyBase.tVector;  size: index );
	(*=  allocate memory for a vector. Do not change information.
	To reduce size, use SetLen first to trim length
	*)
	VAR l, freetrail: SIGNED32;
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

	PROCEDURE Len*( vec: vyBase.tVector ): SIGNED32;
	(*= get total vector length *)
	BEGIN
		IF vec = NIL THEN RETURN 0 ELSE RETURN vec.nrData END
	END Len;

	PROCEDURE NewRealMatrix*( rows, columns: index ): tVector;

	VAR v: tVector;

	BEGIN
		Gen;  v := Objects.NewObj( tVector );  vyBase.ApndChunks( NewBufs( rows * columns ), v );
		v.Layout := vyBase.MatrixLayout( rows, columns );  RETURN v
	END NewRealMatrix;

	PROCEDURE NewRealArray*( sizes: ARRAY OF index ): vyBase.tVector;

	VAR v: tVector;  size: index;

	BEGIN
		Gen;  v := Objects.NewObj( tVector );  vyBase.SetArrayLayout( sizes, v, size );
		vyBase.ApndChunks( NewBufs( size ), v );  RETURN v
	END NewRealArray;

	PROCEDURE NewAlikeVector*( model: vyBase.tVector ): vyBase.tVector;
	(*= Allocate a new vector with same structure as model *)
	VAR new: tVector;
	BEGIN
		ASSERT ( (model # NIL ) & (model IS tVector), 100 );
		new := New( model.nrData );  new.Layout := vyBase.CloneLayout( model );  RETURN new
	END NewAlikeVector;

	PROCEDURE Append*( xx: FLOAT64;  v: vyBase.tVector );
	(*= Add a data point to a chunk. Append new chunk if necessary *)
	(*! defensive programming *)
	VAR l: index;  chunk: tBuf;  x: FLOAT32;
	BEGIN  (* find entry which is not full *)
		ASSERT ( (xx >= MIN( real )) & (xx <= MAX( real )), 100 );
		x := SHORT( xx );
		IF v.buf = NIL THEN v.buf := NewBufs( 1 ) END;
		chunk := v.buf( tBuf );
		l := chunk.len;   (*l:=LEN(chunk.data);*)
		WHILE (chunk.usedentries = l) & (chunk.next # NIL ) DO
			chunk := chunk.next( tBuf );  l := chunk.len (* l:=LEN(chunk.data);*)
		END;
		IF chunk.usedentries = l THEN chunk.next := NewBufs( l );  chunk := chunk.next( tBuf );  chunk.usedentries := 0 END;
		chunk.data[chunk.usedentries] := x;  INC( chunk.usedentries );
		chunk.cache := NIL;   (* FlushBufCaches(chunk); *)
		INC( v.nrData )
	END Append;

	PROCEDURE Get*( v: vyBase.tVector;  pos: index ): real;
	VAR chunk: vyBase.tBuf;  loc: index;
	BEGIN
		vyBase.Loc( pos, v, chunk, loc );
		ASSERT ( loc >= 0, 100 );
		ASSERT ( (loc < chunk.usedentries), 101 );   (* added jb 11.11.00 *)
		RETURN chunk( tBuf ).data[loc]
	END Get;

	PROCEDURE Set*( xval: FLOAT64;  v: vyBase.tVector;  pos: index );
	VAR chunk: vyBase.tBuf;  loc: index;
	BEGIN
		ASSERT ( pos < v.nrData, 102 );
		WITH v: tVector DO
			ASSERT ( v # NIL , 100 );
			ASSERT ( (xval >= MIN( real )) & (xval <= MAX( real )), 101 );
			(*	IF pos >= v.nrData THEN  vyBase.MarkUsed(pos + 1, v) END; *)
			vyBase.Loc( pos, v, chunk, loc );
			ASSERT ( loc >= 0, 103 );
			WITH chunk: tBuf DO
				chunk.data[loc] := SHORT( xval );  chunk.cache := NIL
				(* FlushBufCaches(chunk) *)
			END
		END
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

	PROCEDURE SetIndexed*( xval: FLOAT64;  v: vyBase.tVector;  indexvec: vyBase.tVector;  pos: index );
	VAR chunk: vyBase.tBuf;  loc: index;  val: real;
	BEGIN
		WITH v: tVector DO
			ASSERT ( v # NIL , 100 );
			ASSERT ( indexvec # NIL , 101 );
			ASSERT ( (xval >= MIN( real )) & (xval <= MAX( real )), 101 );
			val := SHORT( xval );
			ASSERT ( pos < v.nrData, 102 );   (*IF pos >= v.nrData THEN  vyBase.MarkUsed(pos + 1, v) END;*)
			vyBase.Loc( vyLongintVec.Get( indexvec( vyLongintVec.tVector ), pos ), v, chunk, loc );
			ASSERT ( loc >= 0 );
			WITH chunk: tBuf DO
				chunk.data[loc] := val;  chunk.cache := NIL
				(*
			FlushBufCaches(chunk)
			*)
			END
		END
	END SetIndexed;

(** Copy *)
	PROCEDURE CopyData*( (*IN*) src,  (*OUT*) dest: vyBase.tVector );
	(*= copy the data section of a vector. Force dest to same len as src *)
	VAR srcchunk, destchunk: vyBase.tBuf;  oldcount, piececount, count, offs, srcoffs, destoffs: SIGNED32;

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

(** Enquiry routines *)
	PROCEDURE GetMinMax*( v: vyBase.tVector;  VAR min, max: FLOAT64;  VAR nrNaNs: SIGNED32 );
	(*! check handling of 0 len vectors! *)
	(*? should this return MIN/MAX(FLOAT64) on eror? *)
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

	PROCEDURE GetMeanSsq*( v: vyBase.tVector;  VAR Mean, Ssq: FLOAT64;  VAR nrNaNs: SIGNED32 );
	(*! check handling of 0 len vectors! *)
	VAR buf: vyBase.tBuf;  mmCache: tMeanCache;  Sum, temp, temp1: FLOAT64;  SsqAdd, MeanAdd, SumAdd: FLOAT64;  Count, CountAdd: SIGNED32;
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

	PROCEDURE CopyToVec*( VAR A: ARRAY OF real;  v: vyBase.tVector;  len: index;  srcoffs, destoffs: index );
	VAR i, j, lim: index;
	BEGIN
		ASSERT ( LEN( A ) >= v.nrData );
		(*	buf := v.buf(tBuf);WHILE buf # NIL DO bufold := buf;
	IF buf.next # NIL THEN buf := buf.next(tBuf) ELSE buf := NIL END;
	bufold.next := NIL;    bufold := NIL
	END;
	v.buf := NewBufs(LEN(A)); *)
		(*! fof temporary removed, repair deleting of buffers.
	needs to use vyBase.ApndChunks gs *)

		i := srcoffs;  j := destoffs;  lim := srcoffs + len;
		WHILE i < lim DO Set( A[i], v, j );  INC( i );  INC( j ) END;
		FlushVecCaches( v )
	END CopyToVec;

	PROCEDURE CopyToArray*( v: vyBase.tVector;  VAR A: ARRAY OF real );
	VAR offs: index;  buf: vyBase.tBuf;
	BEGIN
		offs := 0;
		ASSERT ( v # NIL , 101 );
		ASSERT ( LEN( A ) >= v.nrData, 100 );
		buf := v.buf( tBuf );
		WHILE buf # NIL DO
			IF buf.usedentries > 0 THEN vyBase.COPYR( buf( tBuf ).data^, 0, buf.usedentries, A, offs );  offs := offs + buf.usedentries END;
			buf := buf.next
		END  (* WHILE *)
	END CopyToArray;
(** Generic operations *)

	PROCEDURE DoArrayOp1*( v: vyBase.tVector;  op1: ArrayOp1Function );
	VAR v1: tVector;
		a: POINTER TO ARRAY OF FLOAT32;
	BEGIN
		ASSERT ( v IS tVector, 100 );
		IF v.buf.next = NIL THEN v1 := v( tVector );  op1( v1.buf( tBuf ).data^ )
		ELSE NEW( a, v.nrData );  CopyToArray( v, a^ );  op1( a^ );  CopyToVec( a^, v, v.nrData, 0, 0 )
		END;
		FlushVecCaches( v )
	END DoArrayOp1;

	PROCEDURE DoArrayOp2*( v1, v2: vyBase.tVector;  op2: ArrayOp2Function );
	(*!Hack*)
	VAR a, b: POINTER TO ARRAY OF FLOAT32;
	BEGIN
		ASSERT ( v1 IS tVector, 100 );
		ASSERT ( v2 IS tVector, 101 );
		NEW( a, v1.nrData );  NEW( b, v2.nrData );  CopyToArray( v1, a^ );  CopyToArray( v2, b^ );  op2( a^, b^ );
		CopyToVec( a^, v1, v1.nrData, 0, 0 );  CopyToVec( b^, v2, v2.nrData, 0, 0 );  FlushVecCaches( v1 );  FlushVecCaches( v2 )
	END DoArrayOp2;


(** Sorting *)
	PROCEDURE SortEachChunkREAL*( c: tBuf );
	(* sort each real chunk in a list *)
	BEGIN
		WHILE (c # NIL ) DO
			vyreal.Sort( c.usedentries, c.data^, 0 );
			IF c.next = NIL THEN c := NIL ELSE c := c.next( tBuf ) END
		END
	END SortEachChunkREAL;

	PROCEDURE SortEachChunkREALWId*( c: tBuf;  cid: vyLongintVec.tBuf );
	BEGIN
		WHILE (c # NIL ) DO
			vyreal.SortIndexed( c.usedentries, c.data^, 0, cid( vyLongintVec.tBuf ).data^ );
			IF c.next = NIL THEN c := NIL ELSE c := c.next( tBuf );  cid := cid.next( vyLongintVec.tBuf ) END
		END
	END SortEachChunkREALWId;

	PROCEDURE tcR( c: vyBase.tBuf ): tBuf;
	BEGIN
		IF c = NIL THEN RETURN NIL ELSE RETURN c( tBuf ) END
	END tcR;

	PROCEDURE MergeSortedChunkREALWId( s1, s2: tBuf;  s1id, s2id: vyLongintVec.tBuf ): BOOLEAN;

	(* v0r0a1, Felix O. Friedrich 31.8.95 *)

	(* pc: For now the incoming chunks s1 & s2 MUST be sorted individually	 *)
	(* if the result does not get sorted (may only happen, if you offend precondition pc),
	MergeSortedChunkREAL returns FALSE otherwise TRUE *)
	(* d is really a NEW Chunk, i.e. memory is really allocated, be careful with iterative techinques,
	one could think of changing s1,s2 *)

	VAR i1, i2, r1id, r2id, length, i: index;  c1, c2, d: tBuf;  c1id, c2id, did: vyLongintVec.tBuf;
		done, c1ended, c2ended, c2used, sorted: BOOLEAN;  r1, r2, lastr: real;  cinter: vyBase.tBuf;  v, v1: tVector;

		PROCEDURE GetNextReal( VAR c: tBuf;  VAR cid: vyLongintVec.tBuf;  VAR i: index;  VAR r: real;  VAR rid: index ): BOOLEAN;
		VAR ctemp: tBuf;  ctempid: vyLongintVec.tBuf;
		BEGIN
			IF c = NIL THEN RETURN FALSE END;
			WHILE (i = c.usedentries) DO
				i := 0;  cinter := vyBase.NextBuf( c );  c := tcR( cinter );  cinter := vyBase.NextBuf( cid );
				cid := vyLongintVec.tcL( cinter );
				IF c = NIL THEN RETURN FALSE END
			END;
			ctemp := c;  ctempid := cid;   (* hack to avoid warnings *)
			r := ctemp.data[i];  rid := ctempid( vyLongintVec.tBuf ).data[i];  INC( i );
			IF i = c.usedentries THEN
				i := 0;  cinter := vyBase.NextBuf( c );  c := tcR( cinter );  cinter := vyBase.NextBuf( cid );
				cid := vyLongintVec.tcL( cinter )
			END;
			RETURN TRUE
		END GetNextReal;

		PROCEDURE store( r: real;  rid: index ): BOOLEAN;
		BEGIN
			v.buf := d;  Append( r, v );  v.buf := did;  vyLongintVec.Append( rid, v );
			IF lastr <= r THEN lastr := r;  RETURN TRUE ELSE lastr := r;  RETURN FALSE END
		END store;

	BEGIN
		i1 := 0;  i2 := 0;  c1 := s1;  c2 := s2;  c1id := s1id;  c2id := s2id;  done := FALSE;  sorted := TRUE;
		length := vyBase.GetUsedEntries( c1 ) + vyBase.GetUsedEntries( c2 );  d := NewBufs( length );
		did := vyLongintVec.NewBufs( length );  c1ended := ~GetNextReal( c1, c1id, i1, r1, r1id );
		c2ended := ~GetNextReal( c2, c2id, i2, r2, r2id );  lastr := MIN( real );  NEW( v );
		REPEAT
			IF c1ended THEN
				IF c2ended THEN done := TRUE
				ELSE sorted := (store( r2, r2id ) & sorted);  c2ended := ~GetNextReal( c2, c2id, i2, r2, r2id )
				END
			ELSIF c2ended THEN sorted := (store( r1, r1id ) & sorted);  c1ended := ~GetNextReal( c1, c1id, i1, r1, r1id )
			ELSE
				IF r1 <= r2 THEN sorted := (store( r1, r1id ) & sorted);  c1ended := ~GetNextReal( c1, c1id, i1, r1, r1id )
				ELSE sorted := (store( r2, r2id ) & sorted);  c2ended := ~GetNextReal( c2, c2id, i2, r2, r2id )
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
			cinter := vyBase.NextBuf( c1 );  c1 := tcR( cinter );  cinter := vyBase.NextBuf( c1id );
			c1id := vyLongintVec.tcL( cinter )
		END;
		c1 := s1;  c1id := s1id;  i := 0;  NEW( v1 );
		WHILE (i < length) DO
			v.buf := c1;  v1.buf := d;  Append( Get( v1, i ), v );  v.buf := c1id;  v1.buf := did;
			vyLongintVec.Append( vyLongintVec.Get( v1, i ), v );  INC( i )
		END;
		RETURN TRUE
	END MergeSortedChunkREALWId;

	PROCEDURE OrderedReal( left, right: vyBase.tBuf ): BOOLEAN;
	(*BEGIN

RETURN (left(tBuf).min <= right(tBuf).min) *)
	VAR lmin, rmin: tMinMaxCache;
	BEGIN
		lmin := BufMinMax( left );  rmin := BufMinMax( right );  RETURN lmin.min <= rmin.min

	END OrderedReal;

	PROCEDURE MergeSortedChunkREAL( s1, s2: tBuf ): BOOLEAN;
	(* merges two sorted chunks *)

	(* v0r0a1, Felix O. Friedrich 31.8.95 *)

	(* pc: For now the incoming chunks s1 & s2 MUST be sorted individually	 *)
	(* if the result does not get sorted (may only happen, if you offend precondition pc),
	MergeSortedChunkREAL returns FALSE otherwise TRUE *)
	(* d is really a NEW Chunk, i.e. memory is really allocated, be careful with iterative techinques,
	one could think of changing s1,s2 *)

	VAR i1, i2, length, i: index;  done, c1ended, c2ended, c2used, sorted: BOOLEAN;  r1, r2, lastr: real;  c1, c2, d: tBuf;
		cinter: vyBase.tBuf;  v, v1: tVector;

		PROCEDURE GetNextReal( VAR c: tBuf;  VAR i: index;  VAR r: real ): BOOLEAN;
		(* get next real value from chunk c, applying that procedure repeatedly to a chunk C will
	return all real values of that chunk consecutively including all following chunks in a chain.
	If reached the end : return false otherwise return true *)
		(* same as : r := Get( " the Vector that begins with c " , i); INC(i); IF i = length (Vector) THEN RETURN FALSE *)

		VAR ctemp: tBuf;
		BEGIN
			IF c = NIL THEN RETURN FALSE END;
			WHILE (i = c.usedentries) DO
				i := 0;  cinter := vyBase.NextBuf( c );  c := tcR( cinter );
				IF c = NIL THEN RETURN FALSE END
			END;
			ctemp := c;   (* hack to avoid warnings *)
			r := ctemp.data[i];  INC( i );
			IF i = c.usedentries THEN
				i := 0;  cinter := vyBase.NextBuf( c );  c := tcR( cinter )
				(* c:=cinter(tBuf); *)

			END;
			RETURN TRUE
		END GetNextReal;

		PROCEDURE store( r: real ): BOOLEAN;
		(* append r to Vector v, RETURN TRUE if v remains sorted ELSE RETURN FALSE *)
		BEGIN
			v.buf := d;  Append( r, v );
			IF lastr <= r THEN lastr := r;  RETURN TRUE ELSE lastr := r;  RETURN FALSE END
		END store;

	BEGIN
		i1 := 0;  i2 := 0;  c1 := s1;  c2 := s2;  done := FALSE;  sorted := TRUE;
		length := vyBase.GetUsedEntries( c1 ) + vyBase.GetUsedEntries( c2 );
		d := NewBufs( length );   (* very old , to be changed to v := NewBufsVector(0);*)

		(* merge s1 and s2 into new Vector v *)
		c1ended := ~GetNextReal( c1, i1, r1 );  c2ended := ~GetNextReal( c2, i2, r2 );  lastr := MIN( real );  NEW( v );
		REPEAT
			IF c1ended THEN
				IF c2ended THEN done := TRUE ELSE sorted := (store( r2 ) & sorted);  c2ended := ~GetNextReal( c2, i2, r2 ) END
			ELSIF c2ended THEN sorted := (store( r1 ) & sorted);  c1ended := ~GetNextReal( c1, i1, r1 )
			ELSE
				IF r1 <= r2 THEN sorted := (store( r1 ) & sorted);  c1ended := ~GetNextReal( c1, i1, r1 )
				ELSE sorted := (store( r2 ) & sorted);  c2ended := ~GetNextReal( c2, i2, r2 )
				END
			END
		UNTIL done;
		IF ~sorted THEN RETURN FALSE END;

		(* restore the values in v to s1 and s2 *)
		c1 := s1;  c2 := s2;  c2used := FALSE;
		WHILE (c1 # NIL ) DO
			c1.cache := NIL;
			(*
		c1.min := MAX(real);     c1.max := MIN(real);
		*)
			c1.usedentries := 0;
			IF vyBase.NextBuf( c1 ) = NIL THEN
				IF ~c2used THEN c1.next := c2;  c2used := TRUE END
			END;
			cinter := vyBase.NextBuf( c1 );  c1 := tcR( cinter )
		END;

		(* not necessary any more : *)
		c1 := s1;  i := 0;  NEW( v1 );
		WHILE (i < length) DO v.buf := c1;  v1.buf := d;  Append( Get( v1, i ), v );  INC( i ) END;
		RETURN TRUE
	END MergeSortedChunkREAL;
	(*
PROCEDURE MergeSortedChunkREALWId (s1, s2: tBuf;   s1id, s2id: tBuf): BOOLEAN ;

(* v0r0a1, Felix O. Friedrich 31.8.95 *)

(* pc: For now the incoming chunks s1 & s2 MUST be sorted individually	 *)
(* if the result does not get sorted (may only happen, if you offend precondition pc),
MergeSortedChunkREAL returns FALSE otherwise TRUE *)
(* d is really a NEW Chunk, i.e. memory is really allocated, be careful with iterative techinques,
one could think of changing s1,s2 *)

VAR i1, i2, r1id, r2id, length, i: index;
c1, c2, d: tBuf;
c1id, c2id, did: tBuf;
done, c1ended, c2ended, c2used, sorted: BOOLEAN;
r1, r2, lastr: real;
cinter: vyBase.tBuf;
v, v1: tVector;

PROCEDURE GetNextReal (VAR c: tBuf;  VAR cid: tBuf;   VAR i: index;   VAR r: real;   VAR rid: index): BOOLEAN ;
VAR ctemp: tBuf;   ctempid: tBuf;
BEGIN
IF c = NIL THEN RETURN FALSE END;
WHILE(i = c.usedentries) DO
i := 0;   cinter := vyBase.NextBuf(c);   c := tcR(cinter);   cinter := vyBase.NextBuf(cid);   cid := tcL(cinter);
IF c = NIL THEN RETURN FALSE END
END;   ctemp := c;   ctempid := cid;  (* hack to avoid warnings *)
WITH
ctemp: tREAL128Chunk DO r := ctemp.data[i];   rid := ctempid(tindex128Chunk).data[i];
|ctemp: tREAL1024Chunk DO r := ctemp.data[i];   rid := ctempid(tindex1024Chunk).data[i];
|ctemp:   tREAL8192Chunk DO r := ctemp.data[i];   rid := ctempid(tindex8192Chunk).data[i]
ELSE RETURN FALSE
END;
INC(i);
IF i = c.usedentries THEN i := 0;   cinter := vyBase.NextBuf(c);   c := tcR(cinter);   cinter := vyBase.NextBuf(cid);   cid := tcL(cinter)
END;
RETURN TRUE
END GetNextReal;

PROCEDURE store (r: real;  rid: index): BOOLEAN ;
BEGIN v.buf := d;   Append(r, v);
v.buf := did;   Append(rid, v);
IF lastr <=  r THEN lastr := r;   RETURN TRUE ELSE lastr := r;   RETURN FALSE END
END store;

BEGIN
i1 := 0;   i2 := 0;
c1 := s1;   c2 := s2;   c1id := s1id;   c2id := s2id;
done := FALSE;   sorted := TRUE;
length := vyBase.GetUsedEntries(c1) + vyBase.GetUsedEntries(c2);
d := NewBufs(length);   did := vyLongintVec.NewLongint(length);
c1ended := ~GetNextReal(c1, c1id, i1, r1, r1id);
c2ended := ~GetNextReal(c2, c2id, i2, r2, r2id);
lastr := MIN(real);
NEW(v);
REPEAT
IF c1ended THEN
IF c2ended THEN done := TRUE
ELSE
sorted := (store(r2, r2id) & sorted);   c2ended := ~GetNextReal(c2, c2id, i2, r2, r2id)
END
ELSIF c2ended THEN
sorted := (store(r1, r1id) & sorted);   c1ended := ~GetNextReal(c1, c1id, i1, r1, r1id)
ELSE
IF r1 <= r2 THEN
sorted := (store(r1, r1id) & sorted);   c1ended := ~GetNextReal(c1, c1id, i1, r1, r1id)
ELSE
sorted := (store(r2, r2id) & sorted);   c2ended := ~GetNextReal(c2, c2id, i2, r2, r2id)
END
END
UNTIL done;
IF ~sorted THEN RETURN FALSE END;
c1 := s1;   c2 := s2;   c1id := s1id;   c2id := s2id;
c2used := FALSE;
WHILE(c1 # NIL) DO
c1.min := MAX(real);   c1.max := MIN(real);
c1.usedentries := 0;
c1id.usedentries := 0; (* fof 971124 *)
IF vyBase.NextBuf(c1) = NIL THEN
IF ~c2used THEN
c1.next := c2;   c1id.next := c2id;
c2used := TRUE
END
END;
cinter := vyBase.NextBuf(c1);   c1 := tcR(cinter);   cinter := vyBase.NextBuf(c1id);   c1id := tcL(cinter)
END;
c1 := s1;   c1id := s1id;
i := 0;
NEW(v1);
WHILE(i < length) DO
v.buf := c1;   v1.buf := d;   Append(Get(v1, i), v);
v.buf := c1id;   v1.buf := did;   Append(VGetL(v1, i), v);
INC(i)
END;
RETURN TRUE
END MergeSortedChunkREALWId;
*)
(*
PROCEDURE SortBuf* (VAR chunk: tBuf) ;
(*! chunk is REALLY set !!!!!! *)
(* v0r0a1, Felix O. Friedrich 31.8.95 *)

(* This algorithm tries to get advantage of individually sorted chunks *)
(* hard precondition (pc1): consistency of chunk.min and chunk.max ! *)
(* weak precondition (pc2): get the chunks sorted individually before applying this algorithm,
it will work if you don't, but it's slower then !*)

(*	That's the way this algorithm works:
1. Sort the queue of chunks by minimal value of each single chunk (-> pc1)
2. Get various non-overlapping queues of chunks (i.e. chunk[i].max <= chunk[i+1].min)
3. MergeSortedChunkREAL (non-overlapping queues) (-> pc2)
4. IF 3.returns FALSE sort the chunks individually
*)


VAR root: vyBase.tBuf;

PROCEDURE SortTheChunks (c: tBuf): tBuf ;
(* get non-overlapping queues of chunks (c1,c2) and merge sorted afterwards, iterative *)
VAR
sorted: BOOLEAN;
previousc, thisc, nextc: tBuf;
nonoverlapc, overlapc: tBuf;
lastoverlapc: tBuf;

(* hard precondition: c # NIL *)
BEGIN
nonoverlapc := c;     overlapc := NIL;
previousc := c;
thisc := tcR(previousc.next);
WHILE (thisc # NIL) DO
nextc := tcR(thisc.next);
IF thisc.min < previousc.max THEN (* two succeeding chunks overlap *)
IF overlapc = NIL THEN
lastoverlapc := thisc;     overlapc := thisc   (* new overlapping queue of chunks *)
ELSE
lastoverlapc.next := thisc;     lastoverlapc := thisc   (* append overlapping chunk this to overlap *)
END;
previousc.next := nextc   (* leave out the overlapping chunk *)
ELSE
previousc := tcR(vyBase.NextBuf(previousc))
END;
thisc := tcR(vyBase.NextBuf(previousc))
END;
IF overlapc = NIL THEN RETURN nonoverlapc
ELSIF lastoverlapc # NIL THEN lastoverlapc.next := NIL
END;
overlapc := SortTheChunks(overlapc);
sorted := MergeSortedChunkREAL(nonoverlapc, overlapc);
ASSERT(sorted);
RETURN nonoverlapc
END SortTheChunks;

BEGIN
(* Sort Chunks by minimum value , increasing *)
root := chunk;
vyBase.SortBufferList(root, OrderedReal);
ASSERT(root IS tBuf);
(* find and merge overlapping chunks *)
chunk := SortTheChunks(root(tBuf))
END SortBuf;

PROCEDURE SortBufWId* (VAR chunk: tBuf;     VAR chunkid: vyLongintVec.tBuf) ;

(* v0r0a1, Felix O. Friedrich 31.8.95 *)

(* This algorithm tries to get advantage of individually sorted chunks *)
(* hard precondition (pc1): consistency of chunk.min and chunk.max ! *)
(* weak precondition (pc2): get the chunks sorted individually before applying this algorithm,
it will work if you don't, but it's slower then !*)

(*	That's the way this algorithm works:
1. Sort the queue of chunks by minimal value of each single chunk (-> pc1)
2. Get various non-overlapping queues of chunks (i.e. chunk[i].max <= chunk[i+1].min)
3. MergeSortedChunkREAL (non-overlapping queues) (-> pc2)
4. IF 3.returns FALSE sort the chunks individually
*)


VAR this, root, c2, c3, t1, t2: tBuf;
rootid, thisid, c2id, c3id, t1id, t2id: vyLongintVec.tBuf;
cinter: vyBase.tBuf;

PROCEDURE SortTheChunksWId (c: tBuf;     VAR cid: vyLongintVec.tBuf): tBuf ;
(* get non-overlapping queues of chunks (c1,c2) and merge sorted afterwards, iterative *)
VAR ch1, ch2, tmp1, tmp2, tmp: tBuf;     sorted: BOOLEAN;
ch1id, ch2id, tmp1id, tmp2id, tmpid: vyLongintVec.tBuf;
BEGIN
ch1 := c;     ch2 := NIL;     tmp1 := ch1;     ch1id := cid;     ch2id := NIL;     tmp1id := ch1id;
WHILE(tmp1.next # NIL) DO
cinter := vyBase.NextBuf(tmp1.next);     tmp :=  tcR(cinter);
cinter := vyBase.NextBuf(tmp1id.next);     tmpid := vyLongintVec.tcL(cinter);
IF tmp1.next(tBuf).min < tmp1.max THEN
IF ch2 = NIL THEN
ch2 := tmp1.next(tBuf);     tmp2 := ch2;     ch2id := tmp1id.next(vyLongintVec.tBuf);     tmp2id := ch2id
ELSE
tmp2.next := tmp1.next;     tmp2 := tmp2.next(tBuf);
tmp2id.next := tmp1id.next;     tmp2id := tmp2id.next(vyLongintVec.tBuf)
END;
tmp1.next := tmp;     tmp1id.next := tmpid
ELSE;
tmp1 := tmp1.next(tBuf);     tmp1id := tmp1id.next(vyLongintVec.tBuf)
END
END;
IF ch2 = NIL THEN
SortEachChunkREALWId(ch1, ch1id);     cid := ch1id;     RETURN ch1
ELSIF tmp2 # NIL THEN
tmp2.next := NIL;     tmp2id.next := NIL
END;
ch2 := SortTheChunksWId(ch2, ch2id);
sorted := (MergeSortedChunkREALWId(ch1, ch2, ch1id, ch2id));
ASSERT(sorted);
cid := ch1id;
RETURN ch1
END SortTheChunksWId;

BEGIN
(* Sort Chunks by minimum value , increasing *)
root := chunk;     this := root;     rootid := chunkid;     thisid := rootid;
IF this = NIL THEN RETURN END;
WHILE (this # NIL) & (this.next # NIL) DO
c2 := this.next(tBuf);     cinter := vyBase.NextBuf(vyBase.NextBuf(this));     c3 :=  tcR(cinter);     t1 := root;
c2id := thisid.next(vyLongintVec.tBuf);     cinter := vyBase.NextBuf(vyBase.NextBuf(thisid));     c3id := vyLongintVec.tcL(cinter);     t1id := rootid;
IF c2.min <= t1.min THEN
c2.next := t1;     root := c2;     this.next := c3;     c2id.next := t1id;     rootid := c2id;     thisid.next := c3id
ELSE
LOOP
cinter := vyBase.NextBuf(t1);     t2 :=  tcR(cinter);     cinter := vyBase.NextBuf(t1id);     t2id := vyLongintVec.tcL(cinter);
IF c2.min < t2.min THEN
c2.next := t2;     t1.next := c2;     this.next := c3;     c2id.next := t2id;     t1id.next := c2id;     thisid.next := c3id;     EXIT
END;
t1 := t2;     t1id := t2id;
IF (t1 = this.next) THEN
cinter := vyBase.NextBuf(this);     this :=  tcR(cinter);     cinter := vyBase.NextBuf(thisid);     thisid := vyLongintVec.tcL(cinter);     EXIT
END
END
END
END;
chunk := SortTheChunksWId(root, rootid);
chunkid := rootid
END SortBufWId;
*)
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
				cinter := vyBase.NextBuf( tmp1.next );  tmp := tcR( cinter );  tnm := BufMinMax( tmp1.next );
				tm := BufMinMax( tmp1 );
				IF tnm.min < tm.max THEN
					IF ch2 = NIL THEN ch2 := tmp1.next( tBuf );  tmp2 := ch2 ELSE tmp2.next := tmp1.next;  tmp2 := tmp2.next( tBuf ) END;
					tmp1.next := tmp
				ELSE  tmp1 := tmp1.next( tBuf )
				END
			END;
			IF ch2 = NIL THEN SortEachChunkREAL( ch1 );  RETURN ch1
			ELSIF tmp2 # NIL THEN tmp2.next := NIL
			END;
			ch2 := SortTheChunks( ch2 );  sorted := (MergeSortedChunkREAL( ch1, ch2 ));
			ASSERT ( sorted );
			RETURN ch1
		END SortTheChunks;

	BEGIN
		(* Sort Chunks by minimum value , increasing *)
		root := chunk;  vyBase.SortBufferList( root, OrderedReal );  chunk := SortTheChunks( root( tBuf ) )
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
				cinter := vyBase.NextBuf( tmp1.next );  tmp := tcR( cinter );  cinter := vyBase.NextBuf( tmp1id.next );
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
			IF ch2 = NIL THEN SortEachChunkREALWId( ch1, ch1id );  cid := ch1id;  RETURN ch1
			ELSIF tmp2 # NIL THEN tmp2.next := NIL;  tmp2id.next := NIL
			END;
			ch2 := SortTheChunksWId( ch2, ch2id );  sorted := (MergeSortedChunkREALWId( ch1, ch2, ch1id, ch2id ));
			ASSERT ( sorted );
			cid := ch1id;  RETURN ch1
		END SortTheChunksWId;

	BEGIN
		(* Sort Chunks by minimum value , increasing *)
		root := chunk;  this := root;  rootid := chunkid;  thisid := rootid;
		IF this = NIL THEN RETURN END;
		WHILE (this # NIL ) & (this.next # NIL ) DO
			c2 := this.next( tBuf );  cinter := vyBase.NextBuf( vyBase.NextBuf( this ) );  c3 := tcR( cinter );  t1 := root;
			c2id := thisid.next( vyLongintVec.tBuf );  cinter := vyBase.NextBuf( vyBase.NextBuf( thisid ) );
			c3id := vyLongintVec.tcL( cinter );  t1id := rootid;  c2m := BufMinMax( c2 );  t1m := BufMinMax( t1 );
			IF c2m.min <= t1m.min THEN
				c2.next := t1;  root := c2;  this.next := c3;  c2id.next := t1id;  rootid := c2id;  thisid.next := c3id
			ELSE
				LOOP
					cinter := vyBase.NextBuf( t1 );  t2 := tcR( cinter );  cinter := vyBase.NextBuf( t1id );
					t2id := vyLongintVec.tcL( cinter );  c2m := BufMinMax( c2 );  t2m := BufMinMax( t2 );
					IF c2m.min < t2m.min THEN
						c2.next := t2;  t1.next := c2;  this.next := c3;  c2id.next := t2id;  t1id.next := c2id;  thisid.next := c3id;  EXIT
					END;
					t1 := t2;  t1id := t2id;
					IF (t1 = this.next) THEN
						cinter := vyBase.NextBuf( this );  this := tcR( cinter );  cinter := vyBase.NextBuf( thisid );
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
		tcx := v.buf( tBuf );  SortEachChunkREAL( tcx );
		IF chunk.next # NIL THEN SortBuf( tcx );  v.buf := tcx (* fof , 970405 *) END
	END Sort;

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
		tclid := WId.buf( vyLongintVec.tBuf );  SortEachChunkREALWId( tcx, tclid );
		IF chunk.next # NIL THEN SortBufWId( tcx, tclid );  v.buf := tcx;   (* fof 971006 *) WId.buf := tclid (* fof 971121 *) END
	END SortWId;

(** Misc *)

	PROCEDURE Fill*( v: vyBase.tVector;  val: real;  offs, count: index );
	(*= Fill vector with constant val *)
	(*! if a full buffer is set: set cache *)
	VAR i: index;
	BEGIN
		FOR i := offs TO offs + count - 1 DO Set( val, v, i ) END
	END Fill;

	PROCEDURE NewFilledNamed*( count: SIGNED32;  val: real;  name: ARRAY OF CHAR ): tVector;
	VAR v: tVector;
	BEGIN
		v := New( count );  Fill( v, val, 0, count );  vyName.Register( vyName.NameBase, v, name );  RETURN v
	END NewFilledNamed;

(*
PROCEDURE SSQ* (x, y: vyBase.tVector): FLOAT64;
(*= Return centered sum of squares *)
(*! add error handling *)
VAR xcr, ycr: tBuf;         s, mx, my : FLOAT64;
i, cur: index;
BEGIN s := 0;     i := 0;     cur := 0;     mx := 0;     my := 0;     vyBase.GC(0, x, 0);     vyBase.GC(0, y, 0);
WITH
x: tVector DO
xcr := x.buf(tBuf);     ycr := y.buf(tBuf);
ASSERT( x.nrData = y.nrData);
WHILE xcr # NIL DO	IF xcr.ssq < 0 THEN FillBufMeanCache(xcr) END;
(* Computation of the mean of vector x *)
mx := mx + (xcr.mean - mx) / (cur + xcr.usedentries) * xcr.usedentries;
cur := cur + (cur + xcr.usedentries);
xcr := xcr.next(tBuf)
END;
cur := 0;
WHILE ycr # NIL DO  IF ycr.ssq < 0 THEN FillBufMeanCache(ycr) END;
(* Computation of the mean of vector y *)
my := my + (ycr.mean - my) / (cur + ycr.usedentries) * ycr.usedentries;
cur := cur + (cur + ycr.usedentries);
ycr := ycr.next(tBuf)
END;
xcr := x.buf(tBuf);     ycr := y.buf(tBuf);
WHILE i < x.nrData DO s := s + (Get(x, i) - mx) * (Get(y, i) - my);     INC(i)    END
END;
RETURN s
END SSQ;
*)
	PROCEDURE SSQ*( x, y: vyBase.tVector ): FLOAT64;
	(*= Return centered sum of squares *)
	(*! add error handling *)
	VAR xcx, ycx: tBuf;  s, mx, my: FLOAT64;  i, cur: index;  xcxmean, ycxmean: tMeanCache;
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
			vyHostTexts.WriteRealTab( w, chunk.usedentries, chunk( tBuf ).data^, 0, defprec );  chunk := chunk.next
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
			(*! optimize vector access for speed *)
				FOR i := 0 TO regressor.nrData - 1 DO Set( Function( Get( regressor, i ) ), new, i ) END
			END
		END
	END EvaluateCaseWise;

	PROCEDURE Scale*( new, x: vyBase.tData;  offs, fact: real );
	(*= Returns a new data variable, of same structure as regressor, with values  offs+x*fact*)
	VAR i: index;
	BEGIN
		(*! include more general model types, in particular multivariate regressors and responses *)
		ASSERT ( x IS tVector, 100 );
		ASSERT ( new IS tVector, 101 );
		WITH new: tVector DO
			WITH x: tVector DO
				SetLen( new, x.nrData );
				(*! optimize vector access for speed *)
				FOR i := 0 TO x.nrData - 1 DO Set( offs + Get( x, i ) * fact, new, i ) END
			END
		END
	END Scale;

	PROCEDURE Sub*( new, x, y: vyBase.tData );
	(*= Returns a new data variable, of same structure as regressor, with values x-y *)
	VAR i: index;
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
					FOR i := 0 TO x.nrData - 1 DO Set( Get( x, i ) - Get( y, i ), new, i ) END
				END
			END
		END
	END Sub;

	PROCEDURE Add*( new, x, y: vyBase.tData );
	(*= Returns a new data variable, of same structure as regressor, with values x+y *)
	VAR i: index;
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
					FOR i := 0 TO x.nrData - 1 DO Set( Get( x, i ) + Get( y, i ), new, i ) END
				END
			END
		END
	END Add;

	PROCEDURE Mult*( new, x, y: vyBase.tData );
	(*= Sets new data to len of x y, of same structure as regressor, with values x*y *)

	VAR bufnew, bufx, bufy: tBuf;  i, inew, ix, iy: index;  temp1, temp2: real;

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
							IF bufnew.next # NIL THEN bufnew := bufnew.next( tBuf );  bufnew.cache := NIL ELSE bufnew := NIL
								END;   (*IF*)
							inew := 0
						END;   (*WHILE*)
						WHILE ix >= bufx.usedentries DO
							IF bufx.next # NIL THEN bufx := bufx.next( tBuf ) ELSE bufx := NIL END;
							ix := 0
						END;   (*WHILE*)
						WHILE iy >= bufy.usedentries DO
							IF bufy.next # NIL THEN bufy := bufy.next( tBuf ) ELSE bufy := NIL END;
							iy := 0
						END;   (*WHILE*)
						(*
					bufnew.data[inew]:=bufx.data[ix]*bufy.data[iy]; *)
						temp1 := bufx.data[ix];  temp2 := bufy.data[iy];
						bufnew.data[inew] := temp1 * temp2;   (*fof simplified expression due to "not enough registers"*)
						INC( inew );  INC( ix );  INC( iy )
					END  (*i*)
				END  (*WITH*)
			END  (*WITH*)
		END  (*WITH*)
	END Mult;

	PROCEDURE Div*( new, x, y: vyBase.tData );
	(*= Sets new data to len of x y, of same structure as regressor, with values x/y *)

	VAR bufnew, bufx, bufy: tBuf;  i, inew, ix, iy: index;  temp1, temp2: real;

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
							IF bufnew.next # NIL THEN bufnew := bufnew.next( tBuf );  bufnew.cache := NIL ELSE bufnew := NIL
								END;   (*IF*)
							inew := 0
						END;   (*WHILE*)
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
					END  (*i*)
				END  (*WITH*)
			END  (*WITH*)
		END  (*WITH*)
	END Div;

(** Norms and  distances *)
	PROCEDURE Norm1*( v: vyBase.tVector ): FLOAT64;
	VAR chunk: tBuf;  norm: FLOAT64;
	BEGIN
		IF v = NIL THEN RETURN 0 END;
		ASSERT ( v IS tVector, 100 );
		chunk := v.buf( tBuf );  norm := 0;
		WHILE chunk # NIL DO
			norm := norm + vyreal.Norm1( chunk.usedentries, chunk.data^, 0 );
			IF (chunk.next # NIL ) THEN chunk := chunk.next( tBuf ) ELSE RETURN norm END
		END
	END Norm1;

	PROCEDURE Norm2Sq*( v: vyBase.tVector ): FLOAT64;
	VAR norm: FLOAT64;  chunk: tBuf;
	BEGIN
		IF v = NIL THEN RETURN 0 END;
		ASSERT ( v IS tVector, 100 );
		chunk := v.buf( tBuf );  norm := 0;
		WHILE chunk # NIL DO
			norm := norm + vyreal.Norm2Sq( chunk.usedentries, chunk.data^, 0 );
			IF (chunk.next # NIL ) THEN chunk := chunk.next( tBuf ) ELSE RETURN norm END
		END
	END Norm2Sq;

	PROCEDURE NormSup*( v: vyBase.tVector ): FLOAT64;
	VAR min, max: FLOAT64;  nrNaNs: SIGNED32;
	BEGIN
		IF v = NIL THEN RETURN 0 END;
		ASSERT ( v IS tVector, 100 );
		GetMinMax( v, min, max, nrNaNs );
		IF min < -max THEN RETURN -min ELSE RETURN max END
	END NormSup;

	PROCEDURE adddist1( VAR piececount: SIGNED32;  VAR srcchunk: vyBase.tBuf;  VAR srcloc: SIGNED32;  VAR destchunk: vyBase.tBuf;  VAR destloc: SIGNED32 );
	BEGIN
		globallongreal :=
			globallongreal + vyreal.Dist1( piececount, srcchunk( tBuf ).data^, srcloc, destchunk( tBuf ).data^, destloc )
	END adddist1;

	PROCEDURE Dist1*( v, w: vyBase.tVector ): FLOAT64;
	BEGIN
		IF (v = NIL ) & (w = NIL ) THEN RETURN 0 END;
		ASSERT ( (v IS tVector) & (w IS tVector), 100 );
		globallongreal := 0;  vyBase.DoToAllPieces( v, w, adddist1 );  RETURN globallongreal
	END Dist1;

	PROCEDURE adddist2( VAR piececount: SIGNED32;  VAR srcchunk: vyBase.tBuf;  VAR srcloc: SIGNED32;  VAR destchunk: vyBase.tBuf;  VAR destloc: SIGNED32 );
	BEGIN
		globallongreal :=
			globallongreal + vyreal.Dist2Sq( piececount, srcchunk( tBuf ).data^, srcloc, destchunk( tBuf ).data^, destloc )
	END adddist2;

	PROCEDURE Dist2Sq*( v, w: vyBase.tVector ): FLOAT64;
	BEGIN
		IF (v = NIL ) & (w = NIL ) THEN RETURN 0 END;
		ASSERT ( (v IS tVector) & (w IS tVector), 100 );
		globallongreal := 0;  vyBase.DoToAllPieces( v, w, adddist2 );  RETURN globallongreal
	END Dist2Sq;

	PROCEDURE adddistsup( VAR piececount: SIGNED32;  VAR srcchunk: vyBase.tBuf;  VAR srcloc: SIGNED32;  VAR destchunk: vyBase.tBuf;
										  VAR destloc: SIGNED32 );
	VAR temp: FLOAT64;
	BEGIN
		temp := vyreal.Dist1( piececount, srcchunk( tBuf ).data^, srcloc, destchunk( tBuf ).data^, destloc );
		IF temp > globallongreal THEN globallongreal := temp END
	END adddistsup;

	PROCEDURE DistSup*( v, w: vyBase.tVector ): FLOAT64;
	BEGIN
		IF (v = NIL ) & (w = NIL ) THEN RETURN 0 END;
		ASSERT ( (v IS tVector) & (w IS tVector), 100 );
		globallongreal := 0;  vyBase.DoToAllPieces( v, w, adddistsup );  RETURN globallongreal
	END DistSup;

	(** Defs from vyTypes2 *)
(*= vyTypes2 type system is defunct. Migrate to OPT type system *)

(** help routines *)
	PROCEDURE GetIndex( m: tMatrixChunk;  r, c: index ): index;
	BEGIN
		RETURN r * (m.col) + c
	END GetIndex;

	PROCEDURE COPYMatrix( sm, dm: tMatrixChunk );
	VAR i, j: index;
	BEGIN
		FOR i := 1 TO sm.row DO
			FOR j := 1 TO sm.col DO WriteMatrix( dm, i - 1, j - 1, ReadMatrix( sm, i - 1, j - 1 ) ) END
		END;
		dm.row := sm.row;  dm.col := sm.col
	END COPYMatrix;

(** read / write routines *)
	PROCEDURE WriteMatrix*( m: tMatrixChunk;  row, col: index;  r: Real );
	BEGIN
		Set( r, m.data, GetIndex( m, row, col ) )
	END WriteMatrix;

	PROCEDURE ReadMatrix*( m: tMatrixChunk;  row, col: index ): Real;
	BEGIN
		RETURN Get( m.data, GetIndex( m, row, col ) )
	END ReadMatrix;

	PROCEDURE ReadCol*( m: tMatrixChunk;  col: index ): vyBase.tVector;
	VAR x: vyBase.tVector;  i: index;
	BEGIN
		x := New( m.row );
		ASSERT ( x # NIL );
		FOR i := 0 TO m.row - 1 DO Set( ReadMatrix( m, i, col ), x, i ) END;
		RETURN x
	END ReadCol;

	PROCEDURE ReadRow*( m: tMatrixChunk;  row: index ): vyBase.tVector;
	VAR x: vyBase.tVector;  i: index;
	BEGIN
		x := New( m.col );
		ASSERT ( x # NIL );
		FOR i := 0 TO m.col - 1 DO Set( ReadMatrix( m, row, i ), x, i ) END;
		RETURN x
	END ReadRow;

	PROCEDURE MeasureMatrix*( m: tMatrixChunk;  VAR min, max: real );
	(** vs 0.0d0 *)  (* md  28.08.95 18:05:03 *)
	VAR i, j: index;  x: real;
	BEGIN
		min := Get( m.data, GetIndex( m, 0, 0 ) );  max := min;
		FOR i := 0 TO m.row - 1 DO
			FOR j := 0 TO m.col - 1 DO
				x := Get( m.data, GetIndex( m, i, j ) );
				IF x < min THEN min := x END;
				IF x > max THEN max := x END
			END
		END
	END MeasureMatrix;


(** generation *)
	PROCEDURE NEWMatrix*( row, col: index ): tMatrixChunk;
	VAR chunk: vyBase.tVector;  m: tMatrixChunk;
	BEGIN
		chunk := New( row * col );  NEW( m );  m.data := chunk;  m.row := row;  m.col := col;  RETURN m
	END NEWMatrix;

	PROCEDURE GenMatrixObject*;
	VAR o: tChunkedMatrix;
	BEGIN
		NEW( o );  o.handle := MatrixHandler;  Objects.NewObj := o
	END GenMatrixObject;

	PROCEDURE NewMatrixObject*( m: tMatrixChunk ): tChunkedMatrix;
	VAR o: tChunkedMatrix;
	BEGIN
		GenMatrixObject;  o := Objects.NewObj( tChunkedMatrix );  o.buf := m;  RETURN o
	END NewMatrixObject;

(** resize *)
	PROCEDURE AddRows*( m: tMatrixChunk;  count: index );
	VAR chunk: vyBase.tVector;  mNew: tMatrixChunk;
	BEGIN
		chunk := New( (m.row + count) * m.col );  NEW( mNew );  mNew.data := chunk;  mNew.row := m.row + count;
		mNew.col := m.col;  COPYMatrix( m, mNew );  m.data := mNew.data;  m.row := m.row + count
	END AddRows;

	PROCEDURE AddColums*( m: tMatrixChunk;  count: index );
	VAR chunk: vyBase.tVector;  mNew: tMatrixChunk;
	BEGIN
		chunk := New( m.row * (m.col + count) );  NEW( mNew );  mNew.data := chunk;  mNew.row := m.row;
		mNew.col := m.col + count;  COPYMatrix( m, mNew );  m.data := mNew.data;  m.col := m.col + count
	END AddColums;

	PROCEDURE CheckREALMatrix*( m: tMatrixChunk;  row, col: index );
	(*= compares the dimension of the matrix m with row and col
	if m hasn't the dimension row*col, it will be resized without effecting the entries(?)*)
	BEGIN
		ASSERT ( m # NIL );
		IF m.row < row THEN AddRows( m, row - m.row ) END;
		IF m.col < col THEN AddColums( m, col - m.col ) END;
		m.row := row;  m.col := col
	END CheckREALMatrix;

(** dumps *)
	PROCEDURE DumpRow*( m: tMatrixChunk;  i: index );
	VAR j: index;
	BEGIN
		FOR j := 1 TO m.col DO
			vyHostTexts.WriteRealFix( vyHostTexts.w, SHORT( ReadMatrix( m, i, j - 1 ) ), 2, 5, 3 );  Texts.WriteString( vyHostTexts.w, "  " )
		END;
		Texts.WriteLn( vyHostTexts.w );  vyHostTexts.InsertLog( vyHostTexts.w.buf )
	END DumpRow;

	PROCEDURE DumpColum*( m: tMatrixChunk;  j: index );
	VAR i: index;
	BEGIN
		FOR i := 1 TO m.row DO
			vyHostTexts.WriteRealFix( vyHostTexts.w, SHORT( ReadMatrix( m, i, j ) ), 2, 5, 3 );  Texts.WriteString( vyHostTexts.w, "  " );
			Texts.WriteLn( vyHostTexts.w )
		END;
		Texts.WriteLn( vyHostTexts.w );  vyHostTexts.InsertLog( vyHostTexts.w.buf )
	END DumpColum;

	PROCEDURE DumpMatrix*( m: tMatrixChunk );
	VAR i: index;
	BEGIN
		FOR i := 1 TO m.row DO
			Texts.WriteInt( vyHostTexts.w, i - 1, 3 );  Texts.WriteString( vyHostTexts.w, ")   " );  DumpRow( m, i - 1 )
		END
	END DumpMatrix;

	PROCEDURE Dump*( v: vyBase.tVector );
	BEGIN
		ASSERT ( (v # NIL ) & (v IS tVector), 100 );
		vyHostTexts.WriteTableStyle( vyHostTexts.w );  Write( vyHostTexts.w, v );
		(* vyHostTexts.Show('vyRealVec.Dump',vyHostTexts.w); *)  (*! refunc,fof 980427 for O/F *)
		vyHostTexts.WritePrevStyle( vyHostTexts.w )
	END Dump;

	(*END  vyRealVec.*)

(*- - - - - - - - - - - - - - - - - - - - - - -
test routines
- - - - - - - - - - - - - - - - - - - - - - - *)
	PROCEDURE Test1*;
	CONST row = 8;  col = 7;
	VAR m: tMatrixChunk;  i, j: index;
	BEGIN
		m := NEWMatrix( row, col );
		FOR i := 1 TO row DO
			FOR j := 1 TO col DO WriteMatrix( m, i - 1, j - 1, (i) * 10 + j ) END
		END;
		vyHostTexts.Msg( "" );  DumpMatrix( m );  AddColums( m, 2 );
		FOR i := 1 TO row DO WriteMatrix( m, i - 1, col, i - 1 ) END;
		vyHostTexts.Msg( "add 2 columns an and set the first of them to the row index" );  DumpMatrix( m );  AddRows( m, 2 );  vyHostTexts.Msg( "add 2 rows " );  DumpMatrix( m )
	END Test1;   (* System.Free vyRealVec* ~ vyRealVec.Test1 *)

	PROCEDURE Test2*;
	CONST row = 32;  col = 0;
	VAR m: tMatrixChunk;  i, j: index;
	BEGIN
		m := NEWMatrix( row, col );
		FOR i := 1 TO row DO
			FOR j := 1 TO col DO WriteMatrix( m, i - 1, j - 1, (i) * 10 + j ) END
		END;
		vyHostTexts.Msg( "" );  DumpMatrix( m );  CheckREALMatrix( m, row, 4 );  vyHostTexts.Msg( "CheckMatrix (m, row, 4) " );  DumpMatrix( m )
	END Test2;   (* System.Free vyRealVec* ~ vyRealVec.Test2 *)

	PROCEDURE TestFill*;
	VAR v: tVector;
	BEGIN
		v := New( 127 );  Fill( v, 127, 0, 127 );  Dump( v );  v := New( 129 );  Fill( v, 129, 0, 129 );  Dump( v )
	END TestFill;
	(* System.Free vyRealVec* ~ vyRealVec.TestFill *)
(*
PROCEDURE ChunkSummary* (VAR w: vyBase.TextsWriter;     buf: vyBase.tBuf);
CONST defprec = 10;      (*! replace by data driven choice *)
BEGIN
WHILE buf # NIL DO WITH buf:tBuf DO
vyHostTexts.WriteInt(w,buf.len);vyHostTexts.WriteInt(w,buf.usedentries);
vyHostTexts.WriteReal(w,buf.min);vyHostTexts.WriteReal(w,buf.max);
vyHostTexts.WriteInt(w,buf.nans);
vyHostTexts.WriteReal(w,buf.mean);vyHostTexts.WriteReal(w,buf.ssq)

(*
vyHostTexts.SummaryReal(w, buf.usedentries, buf(tBuf).data^, defprec);    *) END;		buf := buf.next
END
END ChunkSummary;
*)
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

END vyRealVec.