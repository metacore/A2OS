MODULE vyIntVec IN Oberon;   (** gs  **)
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



IMPORT Files, Objects, vyBase,  (*vyHost, *) vyHostTexts, vyinteger := vyInteger, vyLongintVec, vyName;

CONST
	idversion* = "vvyIntVec 0.0a4";   (* may be maintained or changed by tools *)
TYPE
	(* SIGNED16 *)
	index* = SIGNED32;  integer* = SIGNED16;

	tVector* = POINTER TO tVectorDesc;
	tVectorDesc* = RECORD (vyBase.tVectorDesc) END;
	tINTEGER* = POINTER TO tINTEGERDesc;
	tINTEGERDesc* = RECORD (vyBase.tDataDesc)
		i*: SIGNED16
	END;
	tMinMaxCache = POINTER TO tMinMaxCacheDesc;
	tMinMaxCacheDesc = RECORD (vyBase.tCacheDesc)
		min, max: integer;
		minpos, maxpos, nans: SIGNED32;   (*convenience. Valid if nans>=0 *)
	END;
	tMeanCache = POINTER TO tMeanCacheDesc;
	tMeanCacheDesc = RECORD (vyBase.tCacheDesc)
		mean, ssq: FLOAT64;   (* Valid if nans>=0 & ssq>=0 *)
		nans: SIGNED32
	END;

	tBuf* = POINTER TO tBufDesc;
	tBufDesc* = RECORD (vyBase.tBufDesc)
		data: POINTER TO ARRAY OF SIGNED16
	END;
	ArrayOp1Function* = PROCEDURE ( VAR arg: ARRAY OF SIGNED16 );
	ArrayOp2Function* = PROCEDURE ( VAR arg1, arg2: ARRAY OF SIGNED16 );

	(*
	tINTEGER128 = ARRAY 128 OF SIGNED16;    	(*generic small chunk *)
	tINTEGER128Chunk = POINTER TO tINTEGER128ChunkDesc;
	tINTEGER128ChunkDesc = RECORD (tBufDesc) data: tINTEGER128 END;
	tINTEGER1024 = ARRAY 1024 OF SIGNED16;    	(*for time series people*)
	tINTEGER1024Chunk = POINTER TO tINTEGER1024ChunkDesc;
	tINTEGER1024ChunkDesc = RECORD (tBufDesc) data: tINTEGER1024 END;
	tINTEGER8192 = ARRAY 8192 OF SIGNED16;    	(*for simulations*)
	tINTEGER8192Chunk = POINTER TO tINTEGER8192ChunkDesc;
	tINTEGER8192ChunkDesc = RECORD (tBufDesc) data: tINTEGER8192 END;
	*)

	(** Allocation *)

	(*
	PROCEDURE NewBufs (size: index): tBuf;
	VAR first, last: vyBase.tBuf;
	chunk: tBuf;
	PROCEDURE generic (ch: tBuf;     len: SIGNED32);
	BEGIN NEW(ch.data,len); ch.str := vyBase.dynintarray;
	vyBase.GenericCatBuf(ch, len, size, first, last);
	ch.mean := 0;     ch.ssq := invalSsq;     ch.min := MAX(SIGNED16);     ch.max := MIN(SIGNED16);
	ch.nans:=invalNrNans;
	END generic;

	BEGIN first := NIL;
	IF size = 0 THEN   NEW(chunk);generic(chunk, 128)
	ELSE
	WHILE size >= 8192 DO NEW(chunk);   generic(chunk, 8192)  END;
	WHILE size >= 1024 DO NEW(chunk);   generic(chunk, 1024)  END;
	WHILE size > 0 DO NEW(chunk);   generic(chunk, 128)   END
	END;
	RETURN first(tBuf)
	END NewBufs;

	PROCEDURE FlushBufCaches (buf:vyBase.tBuf);
	BEGIN
	WITH buf:tBuf DO buf.nans:=invalNrNans; buf.ssq:=invalSsq; END;
	buf.cache:=NIL;
	END FlushBufCaches;

	PROCEDURE FlushVecCaches (vec:vyBase.tVector);
	VAR buf: vyBase.tBuf;
	BEGIN buf:=vec.buf; WHILE buf#NIL DO
	FlushBufCaches(buf);
	buf:=buf.next END;
	END FlushVecCaches;

	PROCEDURE GenIntegerObject*;
	VAR o: tINTEGER;
	BEGIN NEW (o); o.handle := Handler; Objects.NewObj := o
	END GenIntegerObject;

	PROCEDURE NewIntegerObject* (i: SIGNED16): tINTEGER;
	VAR o: tINTEGER;
	BEGIN
	GenIntegerObject;
	o := Objects.NewObj(tINTEGER);
	o.i := i;
	o.type := vyHost.inttyp;
	o.storagetype := vyHost.inttyp;
	RETURN o
	END NewIntegerObject;
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

	PROCEDURE Store0( VAR R: Files.Rider;  o: tVector );
	(*! use vyLongreal Store*)

	VAR b: tBuf;  i: index;

	BEGIN
		Files.WriteLInt( R, o.nrData );  b := o.buf( tBuf );
		WHILE b # NIL DO
			IF b.usedentries > 0 THEN
				Files.WriteLInt( R, b.len );  Files.WriteLInt( R, b.usedentries );  i := 0;
				WHILE i < b.usedentries DO Files.WriteInt( R, b.data[i] );  INC( i ) END
			END;   (*IF*)
			IF b.next # NIL THEN b := b.next( tBuf ) ELSE b := NIL END
		END;   (*WHILE*)
		Files.WriteLInt( R, 0 )
	END Store0;

	PROCEDURE Store0INTEGER( VAR R: Files.Rider;  o: tINTEGER );

	BEGIN
		Files.WriteInt( R, o.i )
	END Store0INTEGER;

	PROCEDURE Load0( VAR R: Files.Rider;  o: tVector );

	VAR b: tBuf;  i, c: index;

	BEGIN
		Files.ReadLInt( R, c );  o.nrData := c;  Files.ReadLInt( R, c );
		WHILE c # 0 DO
			b := NewBufs( c );   (* removed -1 fof 020213 *)
			b.len := c;  Files.ReadLInt( R, c );  b.usedentries := c;  i := 0;
			WHILE i < c DO Files.ReadInt( R, b.data[i] );  INC( i ) END;
			vyBase.ApndChunks( b, o );  Files.ReadLInt( R, c )
		END  (*WHILE*)
	END Load0;

	PROCEDURE Load0INTEGER( VAR R: Files.Rider;  o: tINTEGER );

	BEGIN
		Files.ReadInt( R, o.i )
	END Load0INTEGER;

(** Vector allocation *)
	PROCEDURE HandleAttributes( o: tVector;  VAR M: Objects.AttrMsg );
	BEGIN
		IF M.id = Objects.get THEN
			IF M.name = "Gen" THEN COPY( 'vyIntVecVec.Gen', M.s );  M.class := Objects.String;  M.res := 0 ELSE vyBase.VectorHandler( o, M ) END
		ELSIF M.id = Objects.set THEN vyBase.VectorHandler( o, M )
		ELSE vyBase.VectorHandler( o, M )
		END
	END HandleAttributes;

	PROCEDURE HandleAttributesINTEGER( o: tINTEGER;  VAR M: Objects.AttrMsg );
	BEGIN
		IF M.id = Objects.get THEN
			IF M.name = "Gen" THEN COPY( 'vyIntVec.GenIntegerObject', M.s );  M.class := Objects.String;  M.res := 0
			ELSIF M.name = "i" THEN M.class := Objects.Int;  M.i := o.i;  M.res := 0
			ELSE vyBase.DataHandler( o, M )
			END
		ELSIF M.id = Objects.set THEN
			IF M.name = "i" THEN o.i := SHORT( M.i );  M.res := 0 ELSE vyBase.DataHandler( o, M ) END
		ELSIF M.id = Objects.enum THEN vyBase.DataHandler( o, M );  M.Enum( "i" )
		ELSE vyBase.DataHandler( o, M )
		END
	END HandleAttributesINTEGER;

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
		ELSIF o IS tINTEGER THEN
			WITH o: tINTEGER DO  (*! tINTEGER exists also in the Oberonsystem. tINTEGER should be dropped.*)
				IF M IS Objects.AttrMsg THEN
					WITH M: Objects.AttrMsg DO HandleAttributesINTEGER( o, M )
					END;
				ELSIF M IS Objects.FileMsg THEN
					WITH M: Objects.FileMsg DO
						IF M.id = Objects.load THEN Load0INTEGER( M.R, o );  vyBase.DataHandler( o, M )
						ELSIF M.id = Objects.store THEN Store0INTEGER( M.R, o );  vyBase.DataHandler( o, M )
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

	PROCEDURE GenIntegerObject*;

	VAR o: tINTEGER;

	BEGIN
		NEW( o );  o.handle := Handler;  Objects.NewObj := o
	END GenIntegerObject;

	PROCEDURE NewIntegerObject*( i: integer ): tINTEGER;

	VAR o: tINTEGER;

	BEGIN
		GenIntegerObject;  o := Objects.NewObj( tINTEGER );  o.i := i;  o.type := vyBase.inttyp;
		o.storagetype := vyBase.inttyp;  RETURN o
	END NewIntegerObject;

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
			vyinteger.MinMax( buf.usedentries, buf( tBuf ).data^, 0, mmCache.min, mmCache.minpos, mmCache.max,
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
			vyinteger.MeanSSq( buf.usedentries, buf( tBuf ).data^, 0, meanCache.mean, meanCache.ssq, meanCache.nans );
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

	PROCEDURE New*( size: index ): tVector;
	VAR v: tVector;
	BEGIN
		Gen;  v := Objects.NewObj( tVector );  vyBase.ApndChunks( NewBufs( size ), v );  vyBase.MarkUsed( size, v );  RETURN v
	END New;

	PROCEDURE NewConstVector*( size: SIGNED32;  val: integer ): vyBase.tVector;
	VAR v: vyBase.tVector;  buf: vyBase.tBuf;
	BEGIN
		v := New( size );  buf := v( tVector ).buf;
		WHILE buf # NIL DO vyinteger.Fill( buf.len, buf( tBuf ).data^, 0, val );  buf := buf.next END;
		RETURN v
	END NewConstVector;

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

	PROCEDURE NewIntegerArray*( sizes: ARRAY OF SIGNED32 ): vyBase.tVector;
	VAR v: tVector;  size: SIGNED32;
	BEGIN
		Gen;  v := Objects.NewObj( tVector );  vyBase.SetArrayLayout( sizes, v, size );
		vyBase.ApndChunks( NewBufs( size ), v );  RETURN v
	END NewIntegerArray;

	PROCEDURE NewAlikeVector*( model: vyBase.tVector ): vyBase.tVector;
	(*= Allocate a new vector with same structure as model *)
	VAR new: tVector;
	BEGIN
		ASSERT ( (model # NIL ) & (model IS tVector), 100 );
		new := New( model.nrData );  new.Layout := vyBase.CloneLayout( model );  RETURN new
	END NewAlikeVector;

	PROCEDURE Append*( x: SIGNED16;  v: vyBase.tVector );
	(* Add a data point to a chunk. Append new chunk if necessary *)
	(*! defensive programming *)
	VAR l: SIGNED32;  chunk: tBuf;
	BEGIN  (* find entry which is not full *)
		IF v.buf = NIL THEN v.buf := NewBufs( 1 ) END;
		chunk := v.buf( tBuf );
		l := chunk.len;   (*l:=LEN(chunk.data);*)
		WHILE (chunk.usedentries = l) & (chunk.next # NIL ) DO
			chunk := chunk.next( tBuf );  l := chunk.len (* l:=LEN(chunk.data);*)
		END;
		IF chunk.usedentries = l THEN chunk.next := NewBufs( l );  chunk := chunk.next( tBuf );  chunk.usedentries := 0 END;
		chunk.data[chunk.usedentries] := x;  INC( chunk.usedentries );  chunk.cache := NIL;
		(* update vector statistics *)
		INC( v.nrData )
	END Append;

	PROCEDURE GetMinMax*( v: vyBase.tVector;  VAR min, max: SIGNED16;  VAR nrNaNs: SIGNED32 );
	VAR buf: vyBase.tBuf;  mmCache: tMinMaxCache;  cache: vyBase.tCache;
	BEGIN
		min := MAX( integer );  max := MIN( integer );  buf := v.buf;  nrNaNs := 0;
		WITH v: tVector DO
			WHILE buf # NIL DO
				WITH buf: tBuf DO
					mmCache := NIL;  cache := buf.cache;
					WHILE (mmCache # NIL ) & (cache # NIL ) DO
						IF cache IS tMinMaxCache THEN mmCache := cache( tMinMaxCache ) ELSE cache := cache.nextcache END
					END;
					IF mmCache = NIL THEN mmCache := BufMinMax( buf ) END;
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

	VAR buf: vyBase.tBuf;  mmCache: tMeanCache;  MeanAdd, SsqAdd, Sum, SumAdd, temp, temp1: FLOAT64;  Count, CountAdd: SIGNED32;

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
				END;   (*WITH*)
				IF buf.next # NIL THEN buf := buf.next( tBuf ) ELSE buf := NIL END
			END  (* WHILE *)
		END  (*WITH*)
	END GetMeanSsq;

	PROCEDURE Get*( v: vyBase.tVector;  pos: SIGNED32 ): SIGNED16;
	VAR chunk: vyBase.tBuf;  loc: SIGNED32;
	BEGIN
		vyBase.Loc( pos, v, chunk, loc );
		ASSERT ( loc >= 0, 100 );
		ASSERT ( loc < chunk.usedentries, 101 );   (* added jb 11.11.00 *)
		RETURN chunk( tBuf ).data[loc]
	END Get;

	PROCEDURE Set*( val: SIGNED16;  v: vyBase.tVector;  pos: SIGNED32 );
	VAR chunk: vyBase.tBuf;  loc: SIGNED32;
	BEGIN
		IF pos >= v.nrData THEN vyBase.MarkUsed( pos + 1, v ) END;
		vyBase.Loc( pos, v, chunk, loc );
		ASSERT ( loc >= 0 );
		chunk( tBuf ).data[loc] := val;
		WITH chunk: tBuf DO chunk.data[loc] := val;  chunk.cache := NIL
		END
	END Set;

	PROCEDURE GetIndexed*( v: vyBase.tVector;  indexvec: vyBase.tVector;  pos: index ): integer;

	VAR chunk: vyBase.tBuf;  loc: index;

	BEGIN
		ASSERT ( v # NIL , 100 );
		ASSERT ( indexvec # NIL , 101 );
		WITH v: tVector DO vyBase.Loc( vyLongintVec.Get( indexvec( vyLongintVec.tVector ), pos ), v, chunk, loc );
			ASSERT ( loc >= 0 );
			ASSERT ( chunk # NIL );
			RETURN chunk( tBuf ).data[loc]
		END  (*WITH*)
	END GetIndexed;

	PROCEDURE SetIndexed*( xval: integer;  v: vyBase.tVector;  indexvec: vyBase.tVector;  pos: index );

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
		END  (*WITH*)
	END SetIndexed;

	PROCEDURE Fill*( v: vyBase.tVector;  val: SIGNED16;  offs, count: SIGNED32 );
	VAR i: SIGNED32;
	BEGIN
		FOR i := offs TO offs + count - 1 DO Set( val, v, i ) END
	END Fill;

	PROCEDURE NewFilledNamed*( count: SIGNED32;  val: SIGNED16;  name: ARRAY OF CHAR ): tVector;
	VAR v: tVector;
	BEGIN
		v := New( count );  Fill( v, val, 0, count );  vyName.Register( vyName.NameBase, v, name );  RETURN v
	END NewFilledNamed;
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

			vyinteger.Copy( piececount, srcchunk( tBuf ).data^, srcoffs, destchunk( tBuf ).data^, destoffs );
			offs := offs + piececount

		END;
		FlushVecCaches( dest );   (*! remove. keep consistent on per buffer basis *)
	END CopyData;

	PROCEDURE CopyToVec*( VAR A: ARRAY OF SIGNED16;  v: vyBase.tVector;  len: SIGNED32;  srcoffs, destoffs: SIGNED32 );
	VAR i, j, lim: SIGNED32;
	BEGIN
		ASSERT ( LEN( A ) <= v.nrData );
		(*	buf := v.buf(tBuf);
	WHILE buf # NIL DO bufold := buf;
	IF buf.next # NIL THEN buf := buf.next(tBuf)   ELSE buf := NIL END;
	bufold.next := NIL;   bufold := NIL
	END;
	v.buf := NewBufs(LEN(A)); *)
		i := srcoffs;  j := destoffs;  lim := srcoffs + len;
		WHILE i < lim DO Set( A[i], v, j );  INC( i );  INC( j ) END
	END CopyToVec;

	PROCEDURE CopyToArray*( v: vyBase.tVector;  VAR A: ARRAY OF SIGNED16 );
	VAR offs: SIGNED32;  buf: vyBase.tBuf;
	BEGIN
		offs := 0;
		ASSERT ( v # NIL , 101 );
		ASSERT ( LEN( A ) >= v.nrData, 100 );
		buf := v.buf( tBuf );
		WHILE buf # NIL DO
			IF buf.usedentries > 0 THEN vyBase.COPYI( buf( tBuf ).data^, 0, buf.usedentries, A, offs );  offs := offs + buf.usedentries END;
			buf := buf.next
		END  (* WHILE *)
	END CopyToArray;

	PROCEDURE DoArrayOp1*( v: vyBase.tVector;  op1: ArrayOp1Function );
	VAR v1: tVector;
		a: POINTER TO ARRAY OF SIGNED16;
	BEGIN
		ASSERT ( v IS tVector, 100 );
		IF v.buf.next = NIL THEN v1 := v( tVector );  op1( v1.buf( tBuf ).data^ )
		ELSE NEW( a, v.nrData );  CopyToArray( v, a^ );  op1( a^ );  CopyToVec( a^, v, v.nrData, 0, 0 )
		END;
		FlushVecCaches( v )
	END DoArrayOp1;

	PROCEDURE DoArrayOp2*( v1, v2: vyBase.tVector;  op2: ArrayOp2Function );
	(*!Hack*)

	VAR a, b: POINTER TO ARRAY OF SIGNED16;

	BEGIN
		ASSERT ( v1 IS tVector, 100 );
		ASSERT ( v2 IS tVector, 101 );
		NEW( a, v1.nrData );  NEW( b, v2.nrData );  CopyToArray( v1, a^ );  CopyToArray( v2, b^ );  op2( a^, b^ );
		CopyToVec( a^, v1, v1.nrData, 0, 0 );  CopyToVec( b^, v2, v2.nrData, 0, 0 );  FlushVecCaches( v1 );  FlushVecCaches( v2 )
	END DoArrayOp2;

(** Sorting *)

	PROCEDURE SortEachChunkINTEGER*( c: tBuf );
	BEGIN
		WHILE (c # NIL ) DO
			vyinteger.Sort( c.usedentries, c.data^, 0 );
			IF c.next = NIL THEN c := NIL ELSE c := c.next( tBuf ) END
		END
	END SortEachChunkINTEGER;

	PROCEDURE SortEachChunkINTEGERWId*( c: tBuf;  cid: vyLongintVec.tBuf );
	BEGIN
		WHILE (c # NIL ) DO
			vyinteger.SortIndexed( c.usedentries, c.data^, 0, cid( vyLongintVec.tBuf ).data^ );
			IF c.next = NIL THEN c := NIL ELSE c := c.next( tBuf );  cid := cid.next( vyLongintVec.tBuf ) END
		END
	END SortEachChunkINTEGERWId;

	PROCEDURE tcI( c: vyBase.tBuf ): tBuf;
	BEGIN
		IF c = NIL THEN RETURN NIL ELSE RETURN c( tBuf ) END
	END tcI;

	PROCEDURE MergeSortedChunkINTEGER( s1, s2: tBuf ): BOOLEAN;

	(* v0r0a1, Felix O. Friedrich 31.8.95 *)

	(* pc: For now the incoming chunks s1 & s2 MUST be sorted individually	 *)
	(* if the result does not get sorted (may only happen, if you offend precondition pc),
	MergeSortedChunkINTEGER returns FALSE otherwise TRUE *)
	(* d is really a NEW Chunk, i.e. memory is really allocated, be careful with iterative techinques,
	one could think of changing s1,s2 *)

	VAR i1, i2, length, i: SIGNED32;  c1, c2, d: tBuf;  done, c1ended, c2ended, c2used, sorted: BOOLEAN;  r1, r2, lastr: SIGNED16;  cinter: vyBase.tBuf;
		v, v1: tVector;

		PROCEDURE GetNextInteger( VAR c: tBuf;  VAR i: SIGNED32;  VAR r: SIGNED16 ): BOOLEAN;
		VAR ctemp: tBuf;
		BEGIN
			IF c = NIL THEN RETURN FALSE END;
			WHILE (i = c.usedentries) DO
				i := 0;  cinter := vyBase.NextBuf( c );  c := tcI( cinter );
				IF c = NIL THEN RETURN FALSE END
			END;
			ctemp := c;   (* hack to avoid warnings *)
			r := ctemp.data[i];  INC( i );
			IF i = c.usedentries THEN i := 0;  cinter := vyBase.NextBuf( c );  c := tcI( cinter ) END;
			RETURN TRUE
		END GetNextInteger;

		PROCEDURE store( r: SIGNED16 ): BOOLEAN;
		BEGIN
			v.buf := d;  Append( r, v );
			IF lastr <= r THEN lastr := r;  RETURN TRUE ELSE lastr := r;  RETURN FALSE END
		END store;

	BEGIN
		i1 := 0;  i2 := 0;  c1 := s1;  c2 := s2;  done := FALSE;  sorted := TRUE;
		length := vyBase.GetUsedEntries( c1 ) + vyBase.GetUsedEntries( c2 );  d := NewBufs( length );
		c1ended := ~GetNextInteger( c1, i1, r1 );  c2ended := ~GetNextInteger( c2, i2, r2 );  lastr := MIN( SIGNED16 );  NEW( v );
		REPEAT
			IF c1ended THEN
				IF c2ended THEN done := TRUE ELSE sorted := (store( r2 ) & sorted);  c2ended := ~GetNextInteger( c2, i2, r2 ) END
			ELSIF c2ended THEN sorted := (store( r1 ) & sorted);  c1ended := ~GetNextInteger( c1, i1, r1 )
			ELSE
				IF r1 <= r2 THEN sorted := (store( r1 ) & sorted);  c1ended := ~GetNextInteger( c1, i1, r1 )
				ELSE sorted := (store( r2 ) & sorted);  c2ended := ~GetNextInteger( c2, i2, r2 )
				END
			END
		UNTIL done;
		IF ~sorted THEN RETURN FALSE END;
		c1 := s1;  c2 := s2;  c2used := FALSE;
		WHILE (c1 # NIL ) DO
			(* c1.min := MAX(SIGNED16);   c1.max := MIN(SIGNED16); *)
			c1.cache := NIL;  c1.usedentries := 0;
			IF vyBase.NextBuf( c1 ) = NIL THEN
				IF ~c2used THEN c1.next := c2;  c2used := TRUE END
			END;
			cinter := vyBase.NextBuf( c1 );  c1 := tcI( cinter )
		END;
		c1 := s1;  i := 0;  NEW( v1 );
		WHILE (i < length) DO v.buf := c1;  v1.buf := d;  Append( Get( v1, i ), v );  INC( i ) END;
		RETURN TRUE
	END MergeSortedChunkINTEGER;

	PROCEDURE MergeSortedChunkINTEGERWId( s1, s2: tBuf;  s1id, s2id: vyLongintVec.tBuf ): BOOLEAN;

	(* v0r0a1, Felix O. Friedrich 31.8.95 *)

	(* pc: For now the incoming chunks s1 & s2 MUST be sorted individually	 *)
	(* if the result does not get sorted (may only happen, if you offend precondition pc),
	MergeSortedChunkINTEGER returns FALSE otherwise TRUE *)
	(* d is really a NEW Chunk, i.e. memory is really allocated, be careful with iterative techinques,
	one could think of changing s1,s2 *)

	VAR i1, i2, r1id, r2id, length, i: SIGNED32;  c1, c2, d: tBuf;  c1id, c2id, did: vyLongintVec.tBuf;
		done, c1ended, c2ended, c2used, sorted: BOOLEAN;  r1, r2, lastr: SIGNED16;  cinter: vyBase.tBuf;  v, v1: tVector;

		PROCEDURE GetNextInteger( VAR c: tBuf;  VAR cid: vyLongintVec.tBuf;  VAR i: SIGNED32;  VAR r: SIGNED16;  VAR rid: SIGNED32 ): BOOLEAN;
		VAR ctemp: tBuf;  ctempid: vyLongintVec.tBuf;
		BEGIN
			IF c = NIL THEN RETURN FALSE END;
			WHILE (i = c.usedentries) DO
				i := 0;  cinter := vyBase.NextBuf( c );  c := tcI( cinter );  cinter := vyBase.NextBuf( cid );
				cid := vyLongintVec.tcL( cinter );
				IF c = NIL THEN RETURN FALSE END
			END;
			ctemp := c;  ctempid := cid;   (* hack to avoid warnings *)
			r := ctemp.data[i];  rid := ctempid( vyLongintVec.tBuf ).data[i];  INC( i );
			IF i = c.usedentries THEN
				i := 0;  cinter := vyBase.NextBuf( c );  c := tcI( cinter );  cinter := vyBase.NextBuf( cid );
				cid := vyLongintVec.tcL( cinter )
			END;
			RETURN TRUE
		END GetNextInteger;

		PROCEDURE store( r: SIGNED16;  rid: SIGNED32 ): BOOLEAN;
		BEGIN
			v.buf := d;  Append( r, v );  v.buf := did;  vyLongintVec.Append( rid, v );
			IF lastr <= r THEN lastr := r;  RETURN TRUE ELSE lastr := r;  RETURN FALSE END
		END store;

	BEGIN
		i1 := 0;  i2 := 0;  c1 := s1;  c2 := s2;  c1id := s1id;  c2id := s2id;  done := FALSE;  sorted := TRUE;
		length := vyBase.GetUsedEntries( c1 ) + vyBase.GetUsedEntries( c2 );  d := NewBufs( length );
		did := vyLongintVec.NewBufs( length );  c1ended := ~GetNextInteger( c1, c1id, i1, r1, r1id );
		c2ended := ~GetNextInteger( c2, c2id, i2, r2, r2id );  lastr := MIN( SIGNED16 );  NEW( v );
		REPEAT
			IF c1ended THEN
				IF c2ended THEN done := TRUE
				ELSE sorted := (store( r2, r2id ) & sorted);  c2ended := ~GetNextInteger( c2, c2id, i2, r2, r2id )
				END
			ELSIF c2ended THEN sorted := (store( r1, r1id ) & sorted);  c1ended := ~GetNextInteger( c1, c1id, i1, r1, r1id )
			ELSE
				IF r1 <= r2 THEN sorted := (store( r1, r1id ) & sorted);  c1ended := ~GetNextInteger( c1, c1id, i1, r1, r1id )
				ELSE sorted := (store( r2, r2id ) & sorted);  c2ended := ~GetNextInteger( c2, c2id, i2, r2, r2id )
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
			cinter := vyBase.NextBuf( c1 );  c1 := tcI( cinter );  cinter := vyBase.NextBuf( c1id );  c1id := vyLongintVec.tcL( cinter )
		END;
		c1 := s1;  c1id := s1id;  i := 0;  NEW( v1 );
		WHILE (i < length) DO
			v.buf := c1;  v1.buf := d;  Append( Get( v1, i ), v );  v.buf := c1id;  v1.buf := did;
			vyLongintVec.Append( vyLongintVec.Get( v1, i ), v );  INC( i )
		END;
		RETURN TRUE
	END MergeSortedChunkINTEGERWId;

	PROCEDURE OrderedInteger( left, right: vyBase.tBuf ): BOOLEAN;
	VAR lmin, rmin: tMinMaxCache;
	BEGIN
		lmin := BufMinMax( left );  rmin := BufMinMax( right );  RETURN lmin.min <= rmin.min
	END OrderedInteger;

	PROCEDURE SortBuf*( VAR chunk: tBuf );

	(* v0r0a1, Felix O. Friedrich 31.8.95 *)

	(* This algorithm tries to get advantage of individually sorted chunks *)
	(* hard precondition (pc1): consistency of chunk.min and chunk.max ! *)
	(* weak precondition (pc2): get the chunks sorted individually before applying this algorithm,
	it will work if you don't, but it's slower then !*)

	(*	That's the way this algorithm works:
	1. Sort the queue of chunks by minimal value of each single chunk (-> pc1)
	2. Get various non-overlapping queues of chunks (i.e. chunk[i].max <= chunk[i+1].min)
	3. MergeSortedChunkINTEGER (non-overlapping queues) (-> pc2)
	4. IF 3.returns FALSE sort the chunks individually
	*)


	VAR root: vyBase.tBuf;

		cinter: vyBase.tBuf;

		PROCEDURE SortTheChunks( c: tBuf ): tBuf;
		(* get non-overlapping queues of chunks (c1,c2) and merge sorted afterwards, iterative *)
		(*	VAR ch1, ch2, tmp1, tmp2, tmp: tBuf;   sorted: BOOLEAN;
	BEGIN
	ch1 := c;   ch2 := NIL;   tmp1 := ch1;
	WHILE(tmp1.next # NIL) DO
	cinter := vyBase.NextBuf(tmp1.next);   tmp := tcI(cinter);
	IF tmp1.next(tBuf).min < tmp1.max THEN
	IF ch2 = NIL THEN
	ch2 := tmp1.next(tBuf);   tmp2 := ch2
	ELSE
	tmp2.next := tmp1.next;   tmp2 := tmp2.next(tBuf)
	END;
	tmp1.next := tmp
	ELSE;
	tmp1 := tmp1.next(tBuf)
	END
	END;
	IF ch2 = NIL THEN SortEachChunkINTEGER(ch1);   RETURN ch1 ELSIF tmp2 # NIL THEN  tmp2.next := NIL END;
	ch2 := SortTheChunks(ch2);
	sorted := (MergeSortedChunkINTEGER(ch1, ch2));
	ASSERT(sorted);
	RETURN ch1
	*)
		VAR ch1, ch2, tmp1, tmp2, tmp: tBuf;  sorted: BOOLEAN;  tnm, tm: tMinMaxCache;
		BEGIN
			ch1 := c;  ch2 := NIL;  tmp1 := ch1;
			WHILE (tmp1.next # NIL ) DO
				cinter := vyBase.NextBuf( tmp1.next );  tmp := tcI( cinter );  tnm := BufMinMax( tmp1.next );
				tm := BufMinMax( tmp1 );
				IF tnm.min < tm.max THEN
					IF ch2 = NIL THEN ch2 := tmp1.next( tBuf );  tmp2 := ch2 ELSE tmp2.next := tmp1.next;  tmp2 := tmp2.next( tBuf ) END;
					tmp1.next := tmp
				ELSE  tmp1 := tmp1.next( tBuf )
				END
			END;
			IF ch2 = NIL THEN SortEachChunkINTEGER( ch1 );  RETURN ch1
			ELSIF tmp2 # NIL THEN tmp2.next := NIL
			END;
			ch2 := SortTheChunks( ch2 );  sorted := (MergeSortedChunkINTEGER( ch1, ch2 ));
			ASSERT ( sorted );
			RETURN ch1

		END SortTheChunks;

	BEGIN
		(* Sort Chunks by minimum value , increasing *)
		root := chunk;  vyBase.SortBufferList( root, OrderedInteger );

		chunk := SortTheChunks( root( tBuf ) )
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
	3. MergeSortedChunkINTEGER (non-overlapping queues) (-> pc2)
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
				cinter := vyBase.NextBuf( tmp1.next );  tmp := tcI( cinter );  cinter := vyBase.NextBuf( tmp1id.next );
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
			IF ch2 = NIL THEN SortEachChunkINTEGERWId( ch1, ch1id );  cid := ch1id;  RETURN ch1
			ELSIF tmp2 # NIL THEN tmp2.next := NIL;  tmp2id.next := NIL
			END;
			ch2 := SortTheChunksWId( ch2, ch2id );  sorted := (MergeSortedChunkINTEGERWId( ch1, ch2, ch1id, ch2id ));
			ASSERT ( sorted );
			cid := ch1id;  RETURN ch1
		END SortTheChunksWId;

	BEGIN
	(*	(* Sort Chunks by minimum value , increasing *)
	root := chunk;   this := root;   rootid := chunkid;   thisid := rootid;
	IF this = NIL THEN RETURN END;
	WHILE (this # NIL) & (this.next # NIL) DO
	c2 := this.next(tBuf);   cinter := vyBase.NextBuf(vyBase.NextBuf(this));   c3 := tcI(cinter);   t1 := root;
	c2id := thisid.next(vyLongintVec.tBuf);   cinter := vyBase.NextBuf(vyBase.NextBuf(thisid));   c3id := vyLongintVec.tcL(cinter);   t1id := rootid;
	IF c2.min <= t1.min THEN
	c2.next := t1;   root := c2;   this.next := c3;   c2id.next := t1id;   rootid := c2id;   thisid.next := c3id
	ELSE
	LOOP
	cinter := vyBase.NextBuf(t1);   t2 := tcI(cinter);   cinter := vyBase.NextBuf(t1id);   t2id := vyLongintVec.tcL(cinter);
	IF c2.min < t2.min THEN
	c2.next := t2;   t1.next := c2;   this.next := c3;   c2id.next := t2id;   t1id.next := c2id;   thisid.next := c3id;   EXIT
	END;
	t1 := t2;   t1id := t2id;
	IF (t1 = this.next) THEN
	cinter := vyBase.NextBuf(this);   this := tcI(cinter);   cinter := vyBase.NextBuf(thisid);   thisid := vyLongintVec.tcL(cinter);   EXIT
	END
	END
	END
	END;
	chunk := SortTheChunksWId(root, rootid);
	chunkid := rootid*)
		(* Sort Chunks by minimum value , increasing *)
		root := chunk;  this := root;  rootid := chunkid;  thisid := rootid;
		IF this = NIL THEN RETURN END;
		WHILE (this # NIL ) & (this.next # NIL ) DO
			c2 := this.next( tBuf );  cinter := vyBase.NextBuf( vyBase.NextBuf( this ) );  c3 := tcI( cinter );  t1 := root;
			c2id := thisid.next( vyLongintVec.tBuf );  cinter := vyBase.NextBuf( vyBase.NextBuf( thisid ) );
			c3id := vyLongintVec.tcL( cinter );  t1id := rootid;  c2m := BufMinMax( c2 );  t1m := BufMinMax( t1 );
			IF c2m.min <= t1m.min THEN
				c2.next := t1;  root := c2;  this.next := c3;  c2id.next := t1id;  rootid := c2id;  thisid.next := c3id
			ELSE
				LOOP
					cinter := vyBase.NextBuf( t1 );  t2 := tcI( cinter );  cinter := vyBase.NextBuf( t1id );
					t2id := vyLongintVec.tcL( cinter );  c2m := BufMinMax( c2 );  t2m := BufMinMax( t2 );
					IF c2m.min < t2m.min THEN
						c2.next := t2;  t1.next := c2;  this.next := c3;  c2id.next := t2id;  t1id.next := c2id;  thisid.next := c3id;  EXIT
					END;
					t1 := t2;  t1id := t2id;
					IF (t1 = this.next) THEN
						cinter := vyBase.NextBuf( this );  this := tcI( cinter );  cinter := vyBase.NextBuf( thisid );
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
		tcx := v.buf( tBuf );  SortEachChunkINTEGER( tcx );
		IF chunk.next # NIL THEN
			SortBuf( tcx );
			v.buf := tcx (* fof , 970405 *)
		END
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
		ASSERT ( chunkid IS tBuf, 101 );
		tcx := v.buf( tBuf );   (* fof for Ob S3 Windows 960528*)
		tclid := WId.buf( vyLongintVec.tBuf );  SortEachChunkINTEGERWId( tcx, tclid );
		IF chunk.next # NIL THEN
			SortBufWId( tcx, tclid );
			v.buf := tcx;   (* fof 971006 *)
			WId.buf := tclid (* fof 971121 *)
		END
	END SortWId;

(*
PROCEDURE SSQ* (x, y: vyBase.tVector): FLOAT64;  (*vs 0.1d0 gs *)
(*! add error handling *)
VAR    xci, yci: tBuf;      s, mx, my : FLOAT64;
i, cur: SIGNED32;
BEGIN s := 0;   i := 0;   cur := 0;   mx := 0;   my := 0;   vyBase.GC(0, x, 0);   vyBase.GC(0, y, 0);
WITH
x:  tVector DO
xci := x.buf(tBuf);   yci := y.buf(tBuf);
ASSERT( x.nrData = y.nrData);
WHILE xci # NIL DO  IF xci.ssq<0 THEN FillBufMeanCache(xci) END;
mx := mx + (xci.mean - mx) / (cur + xci.usedentries) * xci.usedentries;
cur := cur + (cur + xci.usedentries);
xci := xci.next(tBuf)
END;
cur := 0;
WHILE yci # NIL DO IF yci.ssq<0 THEN FillBufMeanCache(yci) END;
my := my + (yci.mean - my) / (cur + yci.usedentries) * yci.usedentries;
cur := cur + (cur + yci.usedentries);
yci := yci.next(tBuf)
END;
xci := x.buf(tBuf);   yci := y.buf(tBuf);
WHILE i < x.nrData DO s := s + (Get(x, i) - mx) * (Get(y, i) - my);   INC(i)   END
END;
RETURN s
END SSQ;*)

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
	CONST defprec = 8;   (*! replace by data driven choice *)
	BEGIN
		WHILE chunk # NIL DO
			vyHostTexts.WriteIntTab( w, chunk.usedentries, chunk( tBuf ).data^, 0, defprec );  chunk := chunk.next
		END
	END WriteChunk;

	PROCEDURE Write*( VAR w: vyBase.TextsWriter;  v: vyBase.tData );
	BEGIN
		IF v IS vyBase.tVector THEN
			WITH v: vyBase.tVector DO WriteChunk( w, v.buf )
			END
		END
	END Write;

	PROCEDURE ChunkSummary*( VAR w: vyBase.TextsWriter;  chunk: vyBase.tBuf );
	CONST defprec = 8;   (*! replace by data driven choice *)
	BEGIN
		WHILE chunk # NIL DO
			vyHostTexts.SummaryInteger( w, chunk.usedentries, chunk( tBuf ).data^, defprec );  chunk := chunk.next
		END
	END ChunkSummary;

END vyIntVec.