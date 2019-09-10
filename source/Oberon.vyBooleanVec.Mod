MODULE vyBooleanVec IN Oberon;   (** gs  **)
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


(* jb 11.11.00 - additional ASSERT added in procedure Get *)

IMPORT Files, Objects, vyBase, vyBoolean, vyHostTexts, vyLongintVec, vyName;

CONST
	idversion* = "vyBooleanVec 0.0a3";   (* may be maintained or changed by tools *)
TYPE
	index* = SIGNED32;

	(* BOOLEAN *)
	tVector* = POINTER TO tVectorDesc;
	tVectorDesc* = RECORD (vyBase.tVectorDesc) END;
	tBOOLEAN* = POINTER TO tBOOLEANDesc;
	tBOOLEANDesc* = RECORD (vyBase.tDataDesc)
		b*: BOOLEAN
	END;
	tBuf* = POINTER TO tBufDesc;
	tBufDesc* = RECORD (vyBase.tBufDesc)
		data: POINTER TO ARRAY OF BOOLEAN
	END;
	(*	tBOOL128 = ARRAY 128 OF BOOLEAN;  	(*generic small chunk *)
	tBOOL128Chunk = POINTER TO tBOOL128ChunkDesc;
	tBOOL128ChunkDesc = RECORD (tBufDesc) data: tBOOL128 END;
	tBOOL1024 = ARRAY 1024 OF BOOLEAN;   (*for time series people*)
	tBOOL1024Chunk = POINTER TO tBOOL1024ChunkDesc;
	tBOOL1024ChunkDesc = RECORD (tBufDesc) data: tBOOL1024 END;
	tBOOL8192 = ARRAY 8192 OF BOOLEAN;  	(*for simulations*)
	tBOOL8192Chunk = POINTER TO tBOOL8192ChunkDesc;
	tBOOL8192ChunkDesc = RECORD (tBufDesc) data: tBOOL8192 END;
	*)
	PROCEDURE NewBufs( size: SIGNED32 ): tBuf;
	VAR first, last: vyBase.tBuf;  chunk: tBuf;

		PROCEDURE generic( ch: tBuf;  len: SIGNED32 );
		BEGIN
			NEW( ch.data, len );  ch.str := vyBase.dynboolarray;  vyBase.GenericCatBuf( ch, len, size, first, last )
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
		Files.WriteLInt( R, o.nrData );  b := o.buf( tBuf );
		WHILE b # NIL DO
			IF b.usedentries > 0 THEN
				Files.WriteLInt( R, b.len );  Files.WriteLInt( R, b.usedentries );  i := 0;
				WHILE i < b.usedentries DO Files.WriteBool( R, b.data[i] );  INC( i ) END
			END;   (*IF*)
			IF b.next # NIL THEN b := b.next( tBuf ) ELSE b := NIL END
		END;   (*WHILE*)
		Files.WriteLInt( R, 0 )
	END Store0;

	PROCEDURE Store0BOOLEAN( VAR R: Files.Rider;  o: tBOOLEAN );

	BEGIN
		Files.WriteBool( R, o.b )
	END Store0BOOLEAN;

	PROCEDURE Load0( VAR R: Files.Rider;  o: tVector );

	VAR b: tBuf;  i, c: index;

	BEGIN
		Files.ReadLInt( R, c );  o.nrData := c;  Files.ReadLInt( R, c );
		WHILE c # 0 DO
			b := NewBufs( c );   (* removed -1 fof 020213 *)

			b.len := c;  Files.ReadLInt( R, c );  b.usedentries := c;  i := 0;
			WHILE i < c DO Files.ReadBool( R, b.data[i] );  INC( i ) END;
			vyBase.ApndChunks( b, o );  Files.ReadLInt( R, c )
		END  (*WHILE*)
	END Load0;

	PROCEDURE Load0BOOLEAN( VAR R: Files.Rider;  o: tBOOLEAN );

	BEGIN
		Files.ReadBool( R, o.b )
	END Load0BOOLEAN;

(** Vector allocation *)
	PROCEDURE HandleAttributes( o: tVector;  VAR M: Objects.AttrMsg );
	BEGIN
		IF M.id = Objects.get THEN
			IF M.name = "Gen" THEN COPY( 'vyBooleanVec.Gen', M.s );  M.class := Objects.String;  M.res := 0 ELSE vyBase.VectorHandler( o, M ) END
		ELSIF M.id = Objects.set THEN vyBase.VectorHandler( o, M )
		ELSE vyBase.VectorHandler( o, M )
		END
	END HandleAttributes;

	PROCEDURE HandleAttributesBOOLEAN( o: tBOOLEAN;  VAR M: Objects.AttrMsg );
	BEGIN
		IF M.id = Objects.get THEN
			IF M.name = "Gen" THEN COPY( 'vyBooleanVec.GenBooleanObject', M.s );  M.class := Objects.String;  M.res := 0
			ELSIF M.name = "b" THEN M.class := Objects.Bool;  M.b := o.b;  M.res := 0
			ELSE vyBase.DataHandler( o, M )
			END
		ELSIF M.id = Objects.set THEN
			IF M.name = "b" THEN o.b := M.b;  M.res := 0 ELSE vyBase.DataHandler( o, M ) END
		ELSIF M.id = Objects.enum THEN vyBase.DataHandler( o, M );  M.Enum( "b" )
		ELSE vyBase.DataHandler( o, M )
		END
	END HandleAttributesBOOLEAN;

	PROCEDURE Handler*( o: Objects.Object;  VAR M: Objects.ObjMsg );

	BEGIN
		IF o IS tVector THEN
			WITH o: tVector DO
				IF M IS Objects.AttrMsg THEN
					WITH M: Objects.AttrMsg DO HandleAttributes( o, M )
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
		ELSIF o IS tBOOLEAN THEN
			WITH o: tBOOLEAN DO  (*! tBOOLEAN exists also in the Oberonsystem. tBOOLEAN should be dropped.*)
				IF M IS Objects.AttrMsg THEN
					WITH M: Objects.AttrMsg DO HandleAttributesBOOLEAN( o, M )
					END;
				ELSIF M IS Objects.FileMsg THEN
					WITH M: Objects.FileMsg DO
						IF M.id = Objects.load THEN Load0BOOLEAN( M.R, o );  vyBase.DataHandler( o, M )
						ELSIF M.id = Objects.store THEN Store0BOOLEAN( M.R, o );  vyBase.DataHandler( o, M )
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

	PROCEDURE New*( size: SIGNED32 ): tVector;

	VAR v: tVector;

	BEGIN
		Gen;  v := Objects.NewObj( tVector );  vyBase.ApndChunks( NewBufs( size ), v );  vyBase.MarkUsed( size, v );  RETURN v
	END New;

	PROCEDURE GenBooleanObject*;
	VAR o: tBOOLEAN;
	BEGIN
		NEW( o );  o.handle := Handler;  Objects.NewObj := o
	END GenBooleanObject;

	PROCEDURE NewBooleanObject*( b: BOOLEAN ): tBOOLEAN;
	VAR o: tBOOLEAN;
	BEGIN
		GenBooleanObject;  o := Objects.NewObj( tBOOLEAN );  o.b := b;  o.type := vyBase.booltyp;
		o.storagetype := vyBase.booltyp;  RETURN o
	END NewBooleanObject;

	PROCEDURE NewBooleanMatrix*( rows, columns: SIGNED32 ): vyBase.tVector;
	VAR v: tVector;
	BEGIN
		Gen;  v := Objects.NewObj( tVector );  vyBase.ApndChunks( NewBufs( rows * columns ), v );
		v.Layout := vyBase.MatrixLayout( rows, columns );  RETURN v (* fof: gs 2.7.96*)
	END NewBooleanMatrix;

	PROCEDURE NewBooleanArray*( sizes: ARRAY OF SIGNED32 ): vyBase.tVector;
	VAR v: tVector;  size: SIGNED32;
	BEGIN
		Gen;  v := Objects.NewObj( tVector );  vyBase.SetArrayLayout( sizes, v, size );
		vyBase.ApndChunks( NewBufs( size ), v );  RETURN v
	END NewBooleanArray;

	PROCEDURE NewAlikeVector*( model: vyBase.tVector ): vyBase.tVector;
	(*= Allocate a new vector with same structure as model *)
	VAR new: tVector;
	BEGIN
		ASSERT ( (model # NIL ) & (model IS tVector), 100 );
		new := New( model.nrData );  new.Layout := vyBase.CloneLayout( model );  RETURN new
	END NewAlikeVector;

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
		vyBase.MarkUsed( size, vec )
	END SetLen;

	PROCEDURE Len*( vec: tVector ): SIGNED32;
	BEGIN
		IF vec = NIL THEN RETURN 0 ELSE RETURN vec.nrData END
	END Len;

	PROCEDURE NewConstVector*( size: SIGNED32;  val: BOOLEAN ): vyBase.tVector;
	VAR v: tVector;  buf: vyBase.tBuf;
	BEGIN
		Gen;  v := Objects.NewObj( tVector );  vyBase.ApndChunks( NewBufs( size ), v );  vyBase.MarkUsed( size, v );
		buf := v.buf;
		WHILE buf # NIL DO
			vyBoolean.Fill( buf.len, buf( tBuf ).data^, 0, val );   (*FOR index:=0 TO buf.len-1 DO buf(tBuf).data[index]:=val END; *)
			buf := buf.next
		END;
		RETURN v
	END NewConstVector;

	PROCEDURE Append*( x: BOOLEAN;  v: vyBase.tVector );
	(*= Add a data point to a chunk. Append new chunk if necessary *)
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
		chunk.data[chunk.usedentries] := x;  INC( chunk.usedentries );
		(* update vector statistics *)
		INC( v.nrData )
	END Append;

	PROCEDURE Get*( v: vyBase.tVector;  i: SIGNED32 ): BOOLEAN;
	VAR chunk: vyBase.tBuf;  loc: SIGNED32;
	BEGIN
		vyBase.Loc( i, v, chunk, loc );
		ASSERT ( loc >= 0, 100 );
		ASSERT ( (loc < chunk.usedentries), 101 );   (* added jb 11.11.00 *)
		RETURN chunk( tBuf ).data[loc]
	END Get;

	PROCEDURE Set*( val: BOOLEAN;  v: vyBase.tVector;  pos: SIGNED32 );
	VAR chunk: vyBase.tBuf;  loc: SIGNED32;
	BEGIN
		IF pos >= v.nrData THEN vyBase.MarkUsed( pos + 1, v ) END;
		vyBase.Loc( pos, v, chunk, loc );
		ASSERT ( loc >= 0 );
		chunk( tBuf ).data[loc] := val
	END Set;

	PROCEDURE GetIndexed*( v: vyBase.tVector;  indexvec: vyBase.tVector;  pos: index ): BOOLEAN;

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

	PROCEDURE SetIndexed*( xval: BOOLEAN;  v: vyBase.tVector;  indexvec: vyBase.tVector;  pos: index );

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

	PROCEDURE CopyToArray*( v: vyBase.tVector;  VAR A: ARRAY OF BOOLEAN );
	VAR offs: SIGNED32;  buf: vyBase.tBuf;
	BEGIN
		offs := 0;
		ASSERT ( v # NIL , 101 );
		ASSERT ( LEN( A ) >= v.nrData, 100 );
		buf := v.buf( tBuf );
		WHILE buf # NIL DO
			IF buf.usedentries > 0 THEN vyBase.COPYB( buf( tBuf ).data^, 0, buf.usedentries, A, offs );  offs := offs + buf.usedentries END;
			buf := buf.next
		END  (* WHILE *)
	END CopyToArray;

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

			vyBoolean.Copy( piececount, srcchunk( tBuf ).data^, srcoffs, destchunk( tBuf ).data^, destoffs );
			offs := offs + piececount

		END;
		(*FlushVecCaches(dest);   *)  (*! remove. keep consistent on per buffer basis *)
	END CopyData;

	PROCEDURE CopyToVec*( VAR A: ARRAY OF BOOLEAN;  v: vyBase.tVector;  len: SIGNED32;  srcoffs, destoffs: SIGNED32 );
	VAR buf, bufold: tBuf;  i, j, lim: SIGNED32;
	BEGIN
		ASSERT ( LEN( A ) >= v.nrData );
		buf := v.buf( tBuf );
		WHILE buf # NIL DO
			bufold := buf;
			IF buf.next # NIL THEN buf := buf.next( tBuf ) ELSE buf := NIL END;
			bufold.next := NIL;  bufold := NIL
		END;
		v.buf := NewBufs( LEN( A ) );  i := srcoffs;  j := destoffs;  lim := srcoffs + len;
		WHILE i < lim DO Set( A[i], v, j );  INC( i );  INC( j ) END;
		(*! remove. keep consistent on per buffer basis *)
		(*	FOR i:=0 TO LEN(A)-1 DO Set(A[i],v,i) END; *)  (*! use SYSTEM.COPYB to speed up *)
	END CopyToVec;

	PROCEDURE Fill*( v: vyBase.tVector;  val: BOOLEAN;  offs, count: SIGNED32 );
	VAR i: SIGNED32;
	BEGIN
		FOR i := offs TO offs + count - 1 DO Set( val, v, i ) END
	END Fill;

	PROCEDURE NewFilledNamed*( count: SIGNED32;  val: BOOLEAN;  name: ARRAY OF CHAR ): tVector;
	VAR v: tVector;
	BEGIN
		v := New( count );  Fill( v, val, 0, count );  vyName.Register( vyName.NameBase, v, name );  RETURN v
	END NewFilledNamed;

(** Input/Output *)
	PROCEDURE WriteChunk*( VAR w: vyBase.TextsWriter;  chunk: vyBase.tBuf );
	BEGIN
		WHILE chunk # NIL DO vyHostTexts.WriteBoolTab( w, chunk.usedentries, chunk( tBuf ).data^, 0, 0 );  chunk := chunk.next END
	END WriteChunk;

	PROCEDURE Write*( VAR w: vyBase.TextsWriter;  v: vyBase.tData );
	BEGIN
		WITH v: vyBase.tVector DO WriteChunk( w, v.buf )
		END
	END Write;

	PROCEDURE ChunkSummary*( VAR w: vyBase.TextsWriter;  chunk: vyBase.tBuf );
	BEGIN
		WHILE chunk # NIL DO vyHostTexts.SummaryBool( w, chunk.usedentries, chunk( tBuf ).data^ );  chunk := chunk.next END
	END ChunkSummary;

END vyBooleanVec.
