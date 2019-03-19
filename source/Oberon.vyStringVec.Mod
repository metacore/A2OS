MODULE vyStringVec IN Oberon;   (*=     gs **)
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



(* strings, to be used as labels.
Maybe this should be text segments.
*)

IMPORT Files, Objects, vyBase,  (*vyHostTexts, *) vyLongintVec, vyName;

CONST
	idversion* = "vyStringVec 0.0d0";   (* may be maintained or changed by tools *)
	(*invalNrNans = -1;  	(* nan count to flag invalid min/max/nans for a buffer *)
	invalSsq = -1.0;    (* ssq value to flag mean/ssq as invalid *)*)
TYPE
	index* = LONGINT;

	(* REAL *)  (* preferred chunk sizes: 128, 1024, 8192 *)
	nameptr* = vyName.tName;   (* technical convenience, to avoid duplicate code for REAL and LONGREAL *)

	tVector* = POINTER TO tVectorDesc;
	tVectorDesc* = RECORD (vyBase.tVectorDesc) END;

	tBuf* = POINTER TO tBufDesc;
	tBufDesc = RECORD (vyBase.tBufDesc)
		data: POINTER TO ARRAY OF nameptr
	END;

	Op1Function* = PROCEDURE ( x: nameptr ): nameptr;
	ArrayOp1Function* = PROCEDURE ( VAR arg: ARRAY OF nameptr );
	ArrayOp2Function* = PROCEDURE ( VAR arg1, arg2: ARRAY OF nameptr );

	tMatrixChunk* = POINTER TO tMatrixChunkDesc;
	tMatrixChunkDesc = RECORD
		row-, col-: index
	END;
	tChunkedMatrix* = POINTER TO tChunkedMatrixDesc;
	tChunkedMatrixDesc* = RECORD (vyBase.ObjDesc)
		buf*: tMatrixChunk
	END;
	(*VAR globallongnameptr: LONGREAL;   (* sneak globel. handle with care! *)*)

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
BEGIN 	NEW(ch.data, len);   ch.str := vyBase.dynnameptrarray;
vyBase.GenericCatBuf(ch, len, size, first, last);
ch.mean := 0;      ch.ssq := invalSsq;      ch.min := MAX(nameptr);      ch.max := MIN(nameptr);
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

		PROCEDURE generic( ch: tBuf;  len: LONGINT );
		VAR i: index;
		BEGIN
			NEW( ch.data, len );
			FOR i := 0 TO len - 1 DO vyName.New;  ch.data[i] := Objects.NewObj( nameptr ) END;
			ch.str := vyBase.dynlrlarray;  ch.cache := NIL;  vyBase.GenericCatBuf( ch, len, size, first, last )
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
vynameptr.MinMax(buf.usedentries, buf(tBuf).data^, 0, buf.min, buf.minpos, buf.max, buf.maxpos, buf.nans)
END
END
END FillBufMinCache;

PROCEDURE FillBufMeanCache (buf: vyBase.tBuf);
VAR nans: LONGINT;
BEGIN (* propagate nan handling *)
IF buf # NIL THEN WITH buf: tBuf DO
vynameptr.MeanSSq(buf.usedentries, buf(tBuf).data^, 0, buf.mean, buf.ssq, nans)
END
END
END FillBufMeanCache;
*)

	(*PROCEDURE SetNrData (vec: tVector;   size: index);
(* risky buffer nameptrlocation. New buffer contents is undefined. *)
BEGIN
IF vec.nrData = size THEN RETURN END;
vec.buf := NIL;    vec.nrData := 0;
vyBase.ApndChunks(NewBufs(size), vec);
vec.nrData := size
END SetNrData; *)

	(** Vector allocation *)
(*! set to nil if buffer cannot be allocated *)
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

	PROCEDURE Store0( VAR R: Files.Rider;  o: tVector );
	(*! use vyLongreal Store*)

	VAR b: tBuf;  i: index;  M: Objects.FileMsg;

	BEGIN
		Files.WriteLInt( R, o.nrData );  b := o.buf( tBuf );  M.id := Objects.store;
		WHILE b # NIL DO
			IF b.usedentries > 0 THEN
				Files.WriteLInt( R, b.len );  Files.WriteLInt( R, b.usedentries );  i := 0;
				WHILE i < b.usedentries DO b.data[i].handle( b.data[i], M );  INC( i ) END
			END;   (*IF*)
			IF b.next # NIL THEN b := b.next( tBuf ) ELSE b := NIL END
		END;   (*WHILE*)
		Files.WriteLInt( R, 0 )
	END Store0;

	PROCEDURE Load0( VAR R: Files.Rider;  o: tVector );

	VAR b: tBuf;  i, c: index;  M: Objects.FileMsg;

	BEGIN
		Files.ReadLInt( R, c );  o.nrData := c;  Files.ReadLInt( R, c );  M.id := Objects.load;
		WHILE c # 0 DO
			b := NewBufs( c - 1 );  b.len := c;  Files.ReadLInt( R, c );  b.usedentries := c;  i := 0;
			WHILE i < c DO b.data[i].handle( b.data[i], M );  INC( i ) END;
			vyBase.ApndChunks( b, o );  Files.ReadLInt( R, c )
		END  (*WHILE*)
	END Load0;

(** Vector allocation *)
	PROCEDURE HandleAttributes( o: tVector;  VAR M: Objects.AttrMsg );
	BEGIN
		IF M.id = Objects.get THEN
			IF M.name = "Gen" THEN COPY( 'vyStringVec.Gen', M.s );  M.class := Objects.String;  M.res := 0 ELSE vyBase.VectorHandler( o, M ) END
		ELSIF M.id = Objects.set THEN vyBase.VectorHandler( o, M )
		ELSE vyBase.VectorHandler( o, M )
		END
	END HandleAttributes;

	PROCEDURE Handler*( o: Objects.Object;  VAR M: Objects.ObjMsg );

	BEGIN
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

	PROCEDURE NewAlikeVector*( model: vyBase.tVector ): vyBase.tVector;
	(*= Allocate a new vector with same structure as model *)
	VAR new: tVector;
	BEGIN
		ASSERT ( (model # NIL ) & (model IS tVector), 100 );
		new := New( model.nrData );  new.Layout := vyBase.CloneLayout( model );  RETURN new
	END NewAlikeVector;

	PROCEDURE NewStringMatrix*( rows, columns: index ): tVector;
	VAR v: tVector;
	BEGIN
		Gen;  v := Objects.NewObj( tVector );  vyBase.ApndChunks( NewBufs( rows * columns ), v );
		v.Layout := vyBase.MatrixLayout( rows, columns );  RETURN v
	END NewStringMatrix;

	PROCEDURE NewStringArray*( sizes: ARRAY OF index ): vyBase.tVector;
	VAR v: tVector;  size: index;
	BEGIN
		Gen;  v := Objects.NewObj( tVector );  vyBase.SetArrayLayout( sizes, v, size );
		vyBase.ApndChunks( NewBufs( size ), v );  RETURN v
	END NewStringArray;

	PROCEDURE Append*( xx: nameptr;  v: vyBase.tVector );
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
		chunk.data[chunk.usedentries] := xx;  INC( chunk.usedentries );
		chunk.cache := NIL;   (* FlushBufCaches(chunk); *)
		INC( v.nrData )
	END Append;

	PROCEDURE Get*( v: vyBase.tVector;  pos: index ): nameptr;
	VAR chunk: vyBase.tBuf;  loc: index;
	BEGIN
		vyBase.Loc( pos, v, chunk, loc );
		ASSERT ( loc >= 0, 100 );
		ASSERT ( loc < chunk.usedentries, 101 );   (* added jb 11.11.00 *)
		RETURN chunk( tBuf ).data[loc]
	END Get;

	PROCEDURE Set*( xval: nameptr;  v: vyBase.tVector;  pos: index );
	VAR chunk: vyBase.tBuf;  loc: index;
	BEGIN
		ASSERT ( pos < v.nrData, 102 );
		WITH v: tVector DO
			ASSERT ( v # NIL , 100 );

			(*	IF pos >= v.nrData THEN  vyBase.MarkUsed(pos + 1, v) END; *)
			vyBase.Loc( pos, v, chunk, loc );
			ASSERT ( loc >= 0, 103 );
			WITH chunk: tBuf DO
				chunk.data[loc] := xval;  chunk.cache := NIL
				(* FlushBufCaches(chunk) *)
			END
		END
	END Set;

	PROCEDURE GetIndexed*( v: vyBase.tVector;  indexvec: vyBase.tVector;  pos: index ): nameptr;
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

	PROCEDURE SetIndexed*( xval: nameptr;  v: vyBase.tVector;  indexvec: vyBase.tVector;  pos: index );
	VAR chunk: vyBase.tBuf;  loc: index;  val: nameptr;
	BEGIN
		WITH v: tVector DO
			ASSERT ( v # NIL , 100 );
			ASSERT ( indexvec # NIL , 101 );
			val := xval;
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

	PROCEDURE Fill*( v: vyBase.tVector;  val: nameptr;  offs, count: index );
	(*= Fill vector with constant val *)
	(*! if a full buffer is set: set cache *)
	VAR i: index;
	BEGIN
		FOR i := offs TO offs + count - 1 DO Set( val, v, i ) END
	END Fill;

	PROCEDURE NewFilledNamed*( count: LONGINT;  val: nameptr;  name: ARRAY OF CHAR ): tVector;
	VAR v: tVector;
	BEGIN
		v := New( count );  Fill( v, val, 0, count );  vyName.Register( vyName.NameBase, v, name );  RETURN v
	END NewFilledNamed;

	(*
PROCEDURE SSQ* (x, y: vyBase.tVector): LONGREAL;
(*= Return centered sum of squares *)
(*! add error handling *)
VAR xcr, ycr: tBuf;         s, mx, my : LONGREAL;
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


	(** help routines *)
	(*PROCEDURE GetIndex (m: tMatrixChunk;    r, c: index): index;
BEGIN RETURN r * (m.col) + c END GetIndex; *)


	(*END  vyRealVec.*)


	(* System.Free vyRealVec* ~ vyRealVec.TestFill *)
(*
PROCEDURE ChunkSummary* (VAR w: vyHostTexts.TextsWriter;     buf: vyBase.tBuf);
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

END vyStringVec.