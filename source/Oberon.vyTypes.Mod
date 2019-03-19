MODULE vyTypes IN Oberon;   (*=vs  gs  26.10.94/.../mf 30.7.96/gs 20.10.98 *)
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



(*** Basic Voyager data types and memory management. *)
(*=Identification and bookkeeping should be in module VoyagerBase;
memory management and handling in this module.
VoyagerBase should be very stable. This module may take extensions.
*)
(*= matrix oriented data types (including vectors) *)
(* Matrices and vectors may be stored in an internal format. For quick and dirty implementations,
they can be expanded to a conventional matrix. This may consume additional time and lead to
space restrictions. For real life implementations, algorithms should be adapted to partitioned matrices *)

(*! support missing data and mixed types *)
(*! extend chunked model to allow for attributed data (missing, censored,... *)
(*! support all elementary operations for chunked data *)
(*! remove array type restricted method to lower levels *)
(*! check copy routines for completeness *)
(*! support x -> ax+b for all vectors *)
(*? conventions: <input>action<output> ..to be discussed
types for input and output are
V vector
M Matrix
B BOOLEAN
S SHORTINT
I INTEGER
L LONGINT
R REAL
X LONGREAL
*)
(*! move merge routines to type specific bases *)
IMPORT Texts, vyHostTexts, vyHost, vyBase, vyLongintVec, vyBooleanVec, vyIntVec, vyRealVec, vyLongrealVec;

CONST
	(*= Voyager specific constants *)
	idversion* = "vyTypes 0.0a3";   (* may be maintained or changed by tools *)
	(*	c2p15=32768;	(* 2 ^ 15 32K for 1 byte elementary type *)
	c2p13=8192;	(* 2 ^ 13 32K for 4 byte elementary type *)	*)
	(* chunk types *)
	cBOOLEAN* = 1;   (*cSHORT=2; cINTEGER=3; cLONGINT=4;*) cREAL* = 5;   (*cLONGREAL=6;*)
	cUNDEF* = -1;
	(* chunk modes. used in format *)
	(*	cDATA=1; (* immediate data *) *)
	(*! chunk access status. more status bits to be defined *)
	cBadType* = 1;   (* operation not defined or implemented for this type *)
	cBadLen* = 2;   (* length not matching for this type *)
	cOK* = {};

TYPE

	Struct* = vyBase.OPTStruct;
	(*= Structure identification is copied from the Oberon O2 compiler. The work for Voyager could be drastically simplified if
	we had something like an Oberon interpreter, extended to ARRAYS and other more complex structures *)
	(*	tStatus = SET;
	(*	tFormat= SET;
	tType=INTEGER;*)

	(*= abstract voyager data types *)
	tData* = POINTER TO tDataDesc;
	tDataDesc* = RECORD (vyBase.ObjDesc)
	status-:tStatus;
	END;*)
	(*	tStatus = vyBase.tStatus; not used *)

	(* abstract buffer types *)
	(*	The size of a data set may or may not be kown at the beginning of an analysis. To allow analysis with a variable sized data set, a chunked array structure is used. A chunk maps to an elementary 	array. Chunks are linked in a list. All chunks in a list should be of same base type.
	Variable sized data sets could be implemented using open arrays. Since some Oberon implementations do not support open arrays (e.g. MacOberon 4.04) or have implementation specific size 	restrictions (e.g. 32K for MacOberon 4.04) on arrays, a chunked model can serve as a work-around for these implementation restrictions.
	Is it possible to add a slot for data of generic base type ? For now, the base type has to be identified before accessing information like LEN etc. As a kludge, we keep a private copy of the len 	information. *)
	(*	tChunk= POINTER TO tChunkDesc;
	tChunkDesc = RECORD (tBufDesc)
	len:LONGINT; (* Nr of entries allocated to a chunk. aka  LEN.  *)
	usedentries:LONGINT; (* Nr of used entries in a chunk. >=0  *)
	next:tChunk
	END;
	*)

	(*= type specific voyager data types *)
	(* Objects with small data buffer should be avoided because of overhead - try imbedding in fields of records. We do not keep any short variants.
	Buffers are provided in various sizes to allow economic memory management *)
	(*! In Oberon-2, use dynamic arrays *)

	tShortintVector* = vyBase.tVector;
	(* Set *)
	tSetVector* = vyBase.tVector;

	(** Enquiry routines.  *)

	PROCEDURE NumForm*( data: vyBase.tData ): SHORTINT;
	(*= structure form from SInt=4 to LReal=8 if  data can be read as a numeric vector; undef=0 else *)
	BEGIN
		(*! adapt to struct based identification *)
		IF (data = NIL ) OR (~(data IS vyBase.tVector)) THEN RETURN vyBase.cUndef END;
		IF data IS vyIntVec.tVector THEN
			WITH data: vyIntVec.tVector DO RETURN vyBase.cInt
			END;
		ELSIF data IS vyLongintVec.tVector THEN
			WITH data: vyLongintVec.tVector DO RETURN vyBase.cLInt
			END;
		ELSIF data IS vyRealVec.tVector THEN
			WITH data: vyRealVec.tVector DO RETURN vyBase.cReal
			END;
		ELSIF data IS vyLongrealVec.tVector THEN
			WITH data: vyLongrealVec.tVector DO RETURN vyBase.cLReal
			END;
		ELSE RETURN vyBase.cUndef
		END
	END NumForm;

	PROCEDURE NrNaNs*( data: vyBase.tData ): LONGINT;
	(*= structure form from SInt=4 to LReal=8 if  data can be read as a numeric vector; undef=0 else *)
	BEGIN
		IF NumForm( data ) = 0 THEN RETURN MAX( LONGINT ) END;
		(*! not yet implemented*)
	END NrNaNs;

	(** Buffer allocation *)
	(*! add support for other types whenever requested *)
	(*! simplify for Oberon-2 *)

	(** Objects allocation *)
	(*= may be replaced by a generic variable in a subsequent release *)

(** General support *)
	PROCEDURE Dummy( NotYetImplemented: BOOLEAN );
	BEGIN
		ASSERT ( NotYetImplemented = FALSE )
	END Dummy;

	PROCEDURE Write*( VAR w: vyBase.TextsWriter;  v: vyBase.tData );
	BEGIN
		IF v IS vyLongrealVec.tVector THEN
			WITH v: vyLongrealVec.tVector DO vyLongrealVec.Write( w, v )
			END;
		ELSIF v IS vyBooleanVec.tVector THEN
			WITH v: vyBooleanVec.tVector DO vyBooleanVec.Write( w, v )
			END;
		ELSIF v IS vyRealVec.tVector THEN
			WITH v: vyRealVec.tVector DO vyRealVec.Write( w, v )
			END;
		ELSIF v IS vyIntVec.tVector THEN
			WITH v: vyIntVec.tVector DO vyIntVec.Write( w, v )
			END;
		ELSE HALT( 100 )
		END
	END Write;

	PROCEDURE Outline*( VAR w: vyBase.TextsWriter;  v: vyBase.tData );
	BEGIN
		Write( w, v ) (*! reduce to extremals and sample entries*)
	END Outline;

	PROCEDURE ChunkSummary( VAR w: vyBase.TextsWriter;  chunk: vyBase.tBuf );
	(*!  get type neutral implementation*)
	(* 	BEGIN
	WHILE chunk # NIL DO
	WITH chunk: tBOOL128Chunk DO vyHostTexts.SummaryBool(w, chunk.usedentries, chunk.data);
	| chunk: tBOOL1024Chunk DO vyHostTexts.SummaryBool(w, chunk.usedentries, chunk.data);
	| chunk: tBOOL8192Chunk DO vyHostTexts.SummaryBool(w, chunk.usedentries, chunk.data);
	| chunk: tREAL128Chunk DO vyHostTexts.SummaryReal(w, chunk.usedentries, chunk.data, defprec);
	| chunk: tREAL1024Chunk DO vyHostTexts.SummaryReal(w, chunk.usedentries, chunk.data, defprec);
	| chunk: tREAL8192Chunk DO vyHostTexts.SummaryReal(w, chunk.usedentries, chunk.data, defprec);
	| chunk: tLONGINT128Chunk DO vyHostTexts.SummaryLongint(w, chunk.usedentries, chunk.data, defprec);
	| chunk: tLONGINT1024Chunk DO vyHostTexts.SummaryLongint(w, chunk.usedentries, chunk.data, defprec);
	| chunk: tLONGINT8192Chunk DO vyHostTexts.SummaryLongint(w, chunk.usedentries, chunk.data, defprec)
	ELSE
	END;
	chunk := chunk.next
	END
	*)
	END ChunkSummary;

	(** Append a data value to a vector *)

	(* Procedure not used
PROCEDURE CollectReal (chunk: tBuf);
BEGIN
IF (chunk#NIL) & (chunk.usedentries<chunk.len) & (chunk.next#NIL) THEN
(*			WITH buf : tREAL128Chunk DO
vyBase.COPYR(buf.data,0,buf.usedentries,A,offs);
| buf : tREAL1024Chunk DO
vyBase.COPYR(buf.data,0,buf.usedentries,A,offs);
| buf : tREAL8192Chunk DO
vyBase.COPYR(buf.data,0,buf.usedentries,A,offs);
*)
END;
END CollectReal;
*)
	(** Read/set from/to vector *)
(*= Use cenversion if a save and reliable implementation is possible *)

	PROCEDURE VGetR*( v: vyBase.tVector;  pos: LONGINT ): REAL;
	BEGIN
		ASSERT ( v # NIL , 100 );
		IF v IS vyIntVec.tVector THEN
			WITH v: vyIntVec.tVector DO RETURN vyIntVec.Get( v, pos )
			END;
		ELSIF v IS vyLongintVec.tVector THEN
			WITH v: vyLongintVec.tVector DO RETURN vyLongintVec.Get( v, pos )
			END;
		ELSIF v IS vyRealVec.tVector THEN
			WITH v: vyRealVec.tVector DO RETURN vyRealVec.Get( v, pos )
			END;
		ELSIF v IS vyLongrealVec.tVector THEN
			WITH v: vyLongrealVec.tVector DO RETURN SHORT( vyLongrealVec.Get( v, pos ) )
			END;
		ELSE HALT( 100 )
		END  (* WITH *)
	END VGetR;

	PROCEDURE GetValueR*( v: vyBase.tData ): REAL;   (* fof 0202 *)
	BEGIN
		IF v IS vyIntVec.tINTEGER THEN
			WITH v: vyIntVec.tINTEGER DO RETURN v.i
			END;
		ELSIF v IS vyLongintVec.tLONGINT THEN
			WITH v: vyLongintVec.tLONGINT DO RETURN v.i
			END;
		ELSIF v IS vyRealVec.tREAL THEN
			WITH v: vyRealVec.tREAL DO RETURN v.x
			END;
		ELSIF v IS vyLongrealVec.tLONGREAL THEN
			WITH v: vyLongrealVec.tLONGREAL DO RETURN SHORT( v.x )
			END;
		END
	END GetValueR;


(** Sorting *)

	PROCEDURE Sort*( VAR v: vyBase.tVector );   (*vs 0.1d1 fof , 970405*)
	(*! check for sorting algorithms. Quicksort within chunks, merge between ? *)
	(*! sort for boolean needed ? *)
	(*! incorrect. does not work for mixied vectors. To correct!!! *)
	VAR chunk: vyBase.tBuf;  tcr: vyRealVec.tBuf;  tcx: vyLongrealVec.tBuf;  tcl: vyLongintVec.tBuf;  tci: vyIntVec.tBuf;
	BEGIN
		IF (v = NIL ) OR (v.buf = NIL ) THEN RETURN END;
		chunk := v.buf;   (* hack to avoid error messages *)
		IF (chunk.next # NIL ) & ~(chunk IS vyRealVec.tBuf) & ~(chunk IS vyLongrealVec.tBuf) & ~(chunk IS vyIntVec.tBuf) &
		    ~(chunk IS vyLongintVec.tBuf) THEN
			Dummy( TRUE )
		END;
		IF (chunk IS vyRealVec.tBuf) THEN
			tcr := v.buf( vyRealVec.tBuf );   (* fof for Ob S3 Windows 960528*)
			vyRealVec.SortEachChunkREAL( tcr );
			IF chunk.next # NIL THEN
				vyRealVec.SortBuf( tcr );
				v.buf := tcr (* fof , 970405 *)
			END
		ELSIF (chunk IS vyLongrealVec.tBuf) THEN
			tcx := v.buf( vyLongrealVec.tBuf );   (* fof for Ob S3 Windows 960528*)
			vyLongrealVec.SortEachChunkLONGREAL( tcx );
			IF chunk.next # NIL THEN
				vyLongrealVec.SortBuf( tcx );
				v.buf := tcx (* fof , 970405 *)
			END
		ELSIF (chunk IS vyLongintVec.tBuf) THEN
			tcl := v.buf( vyLongintVec.tBuf );   (* fof for Ob S3 Windows 960528*)
			vyLongintVec.SortEachChunkLONGINT( tcl );
			IF chunk.next # NIL THEN
				vyLongintVec.SortBuf( tcl );
				v.buf := tcl (* fof , 970405 *)
			END
		ELSIF (chunk IS vyIntVec.tBuf) THEN
			tci := v.buf( vyIntVec.tBuf );   (* fof for Ob S3 Windows 960528*)
			vyIntVec.SortEachChunkINTEGER( tci );
			IF chunk.next # NIL THEN
				vyIntVec.SortBuf( tci );
				v.buf := tci (* fof , 970405 *)
			END
		ELSE v.status := v.status + {cBadType}
		END
	END Sort;

	PROCEDURE SortById*( VAR v: vyBase.tVector;  VAR WId: vyBase.tVector );
	(*= Sorts a longint chunk by a longint chunk *)
	(*! sort and generate a vector of id keys *)
	(*! check. misnomer ? *)
	VAR chunk, chunkid: vyBase.tBuf;  tcI, tcIid: vyLongintVec.tBuf;
	BEGIN
		IF (v = NIL ) OR (v.buf = NIL ) OR (WId = NIL ) OR (WId.buf = NIL ) THEN RETURN END;
		ASSERT ( v.nrData = WId.nrData );
		chunk := v.buf;   (* hack to avoid error messages *)
		chunkid := WId.buf;
		IF (chunk.next # NIL ) & ~(chunkid IS vyLongintVec.tBuf) & ~(chunk IS vyLongintVec.tBuf) THEN Dummy( TRUE ) END;
		IF (chunk IS vyLongintVec.tBuf) THEN
			tcI := v.buf( vyLongintVec.tBuf );   (* fof for Ob S3 Windows 960528*)
			tcIid := WId.buf( vyLongintVec.tBuf );  vyLongintVec.SortEachChunkLONGINTWId( tcIid, tcI );
			IF chunk.next # NIL THEN vyLongintVec.SortBufWId( tcIid, tcI ) END
		ELSE v.status := v.status + {cBadType}
		END
	END SortById;

	PROCEDURE SortWId*( VAR v: vyBase.tVector;  VAR WId: vyBase.tVector );
	(*= Index must be a longint chunk *)
	(* ! rearrange a vector by id keys *)
	VAR chunk, chunkid: vyBase.tBuf;  tcr: vyRealVec.tBuf;  tcx: vyLongrealVec.tBuf;  tci: vyIntVec.tBuf;  tcl: vyLongintVec.tBuf;
		tclid: vyLongintVec.tBuf;
	BEGIN
		IF (v = NIL ) OR (v.buf = NIL ) OR (WId = NIL ) OR (WId.buf = NIL ) THEN RETURN END;
		ASSERT ( v.nrData = WId.nrData );
		chunk := v.buf;   (* hack to avoid error messages *)
		chunkid := WId.buf;
		IF (chunk.next # NIL ) & ~(chunk IS vyRealVec.tBuf) & ~(chunk IS vyLongrealVec.tBuf) & ~(chunk IS vyIntVec.tBuf) &
		    ~(chunk IS vyLongintVec.tBuf) & ~(chunkid IS vyLongintVec.tBuf) THEN
			Dummy( TRUE )
		END;
		IF (chunk IS vyRealVec.tBuf) THEN
			tcr := v.buf( vyRealVec.tBuf );   (* fof for Ob S3 Windows 960528*)
			tclid := WId.buf( vyLongintVec.tBuf );  vyRealVec.SortEachChunkREALWId( tcr, tclid );
			IF chunk.next # NIL THEN
				vyRealVec.SortBufWId( tcr, tclid );
				v.buf := tcr;   (* fof 971006 *)
				WId.buf := tclid (* fof 971121 *)
			END
		ELSIF (chunk IS vyLongrealVec.tBuf) THEN
			tcx := v.buf( vyLongrealVec.tBuf );   (* fof for Ob S3 Windows 960528*)
			tclid := WId.buf( vyLongintVec.tBuf );  vyLongrealVec.SortEachChunkLONGREALWId( tcx, tclid );
			IF chunk.next # NIL THEN
				vyLongrealVec.SortBufWId( tcx, tclid );
				v.buf := tcx;   (* fof 971006 *)
				WId.buf := tclid (* fof 971121 *)
			END
		ELSIF (chunk IS vyIntVec.tBuf) THEN
			tci := v.buf( vyIntVec.tBuf );   (* fof for Ob S3 Windows 960528*)
			tclid := WId.buf( vyLongintVec.tBuf );  vyIntVec.SortEachChunkINTEGERWId( tci, tclid );
			IF chunk.next # NIL THEN
				vyIntVec.SortBufWId( tci, tclid );
				v.buf := tci;   (* fof 971006 *)
				WId.buf := tclid (* fof 971121 *)
			END
		ELSIF (chunk IS vyLongintVec.tBuf) THEN
			tcl := v.buf( vyLongintVec.tBuf );   (* fof for Ob S3 Windows 960528*)
			tclid := WId.buf( vyLongintVec.tBuf );  vyLongintVec.SortEachChunkLONGINTWId( tcl, tclid );
			IF chunk.next # NIL THEN
				vyLongintVec.SortBufWId( tcl, tclid );
				v.buf := tcl;   (* fof 971006 *)
				WId.buf := tclid (* fof 971121 *)
			END
		ELSE v.status := v.status + {cBadType}
		END
	END SortWId;

	(* fof sort end *)

	(** Vector allocation *)
	(*! set to nil if buffer cannot be allocated *)

	(* Procedure not used
PROCEDURE GrowIntegerVector (v:vyIntVec.tVector;size:LONGINT);
BEGIN	 vyBase.ApndChunks(NEWINTEGER(size),v);
END GrowIntegerVector;
*)
	(** Matrix=2d array allocation *)
	(** array allocation *)

(** Additional vector routines *)
	PROCEDURE SSQ*( x, y: vyBase.tVector ): LONGREAL;   (*vs 0.1d0 gs *)
	(*! add error handling *)
	BEGIN
		vyBase.GC( 0, x, 0 );  vyBase.GC( 0, y, 0 );
		IF x IS vyRealVec.tVector THEN
			WITH x: vyRealVec.tVector DO RETURN vyRealVec.SSQ( x, y )
			END;
		ELSIF x IS vyLongrealVec.tVector THEN
			WITH x: vyLongrealVec.tVector DO RETURN vyLongrealVec.SSQ( x, y )
			END;
		ELSIF x IS vyIntVec.tVector THEN
			WITH x: vyIntVec.tVector DO RETURN vyIntVec.SSQ( x, y )
			END;
		ELSIF x IS vyLongintVec.tVector THEN
			WITH x: vyLongintVec.tVector DO RETURN vyLongintVec.SSQ( x, y )
			END;
		ELSE
		END
	END SSQ;

	(** 2d support *)
	(*
PROCEDURE GetIndex* (m: tMatrix; r, c: LONGINT): LONGINT;
BEGIN RETURN r*(m.LEN1) + c
END GetIndex;
(*! untested routines for new interface *)
(*! add more routines whenever needed *)
(* try to avoid elementwise routines; use iterators if possible *)
*)
(** Minimum and maximum *)

	PROCEDURE VGetMinMax*( v: vyBase.tVector;  VAR min, max: LONGREAL;  VAR nrNaNs: LONGINT );
	VAR imin, imax: INTEGER;  lmin, lmax: LONGINT;
	BEGIN
		IF v = NIL THEN min := MIN( LONGREAL );  max := MAX( LONGREAL );  nrNaNs := 0;  RETURN END;
		(*! check and propagate to other types *)
		IF v IS vyLongrealVec.tVector THEN
			WITH v: vyLongrealVec.tVector DO vyLongrealVec.GetMinMax( v, min, max, nrNaNs );
			END;
		ELSIF v IS vyIntVec.tVector THEN
			WITH v: vyIntVec.tVector DO vyIntVec.GetMinMax( v, imin, imax, nrNaNs );  min := (imin);  max := (imax)
			END;
		ELSIF v IS vyLongintVec.tVector THEN
			WITH v: vyLongintVec.tVector DO vyLongintVec.GetMinMax( v, lmin, lmax, nrNaNs );  min := (lmin);  max := (lmax)
			END;
		ELSIF v IS vyRealVec.tVector THEN
			WITH v: vyRealVec.tVector DO vyRealVec.GetMinMax( v, min, max, nrNaNs )
			END;
		END
	END VGetMinMax;

	PROCEDURE VGetMinMaxR*( v: vyBase.tVector;  VAR rmin, rmax: REAL;  VAR nrNaNs: LONGINT );
	(*! check. if ok: move this model to other variants *)
	VAR xmin, xmax: LONGREAL;  imin, imax: INTEGER;  lmin, lmax: LONGINT;
	BEGIN
		xmin := MAX( LONGREAL );  xmax := MIN( LONGREAL );  nrNaNs := 0;
		ASSERT ( v # NIL , 100 );
		IF v IS vyLongrealVec.tVector THEN
			WITH v: vyLongrealVec.tVector DO vyLongrealVec.GetMinMax( v, xmin, xmax, nrNaNs );
			END;
		ELSIF v IS vyIntVec.tVector THEN
			WITH v: vyIntVec.tVector DO vyIntVec.GetMinMax( v, imin, imax, nrNaNs );  xmin := (imin);  xmax := (imax)
			END;
		ELSIF v IS vyLongintVec.tVector THEN
			WITH v: vyLongintVec.tVector DO vyLongintVec.GetMinMax( v, lmin, lmax, nrNaNs );  xmin := (lmin);  xmax := (lmax)
			END;
		ELSIF v IS vyRealVec.tVector THEN
			WITH v: vyRealVec.tVector DO vyRealVec.GetMinMax( v, xmin, xmax, nrNaNs )
			END;
		END;
		ASSERT ( (xmin >= MIN( REAL )) & (xmax <= MAX( REAL )), 101 );
		rmin := SHORT( xmin );  rmax := SHORT( xmax )
	END VGetMinMaxR;

	PROCEDURE VGetMinMaxX*( v: vyBase.tVector;  VAR min, max: LONGREAL;  VAR nrNaNs: LONGINT );
	VAR imin, imax: INTEGER;  lmin, lmax: LONGINT;  rmin, rmax: LONGREAL;
	BEGIN
		min := MAX( LONGREAL );  max := MIN( LONGREAL );  nrNaNs := 0;
		IF v IS vyLongrealVec.tVector THEN
			WITH v: vyLongrealVec.tVector DO vyLongrealVec.GetMinMax( v, min, max, nrNaNs );
			END;
		ELSIF v IS vyIntVec.tVector THEN
			WITH v: vyIntVec.tVector DO vyIntVec.GetMinMax( v, imin, imax, nrNaNs );  min := (imin);  max := (imax)
			END;
		ELSIF v IS vyLongintVec.tVector THEN
			WITH v: vyLongintVec.tVector DO vyLongintVec.GetMinMax( v, lmin, lmax, nrNaNs );  min := (lmin);  max := (lmax)
			END;
		ELSIF v IS vyRealVec.tVector THEN
			WITH v: vyRealVec.tVector DO vyRealVec.GetMinMax( v, rmin, rmax, nrNaNs );  min := rmin;  max := rmax
			END;
		END
	END VGetMinMaxX;

(** Dyadic operators *)
	PROCEDURE Sub*( x, y: vyBase.tVector;  diff: vyBase.tVector );
	VAR i: LONGINT;  chx: vyBase.tBuf;
	BEGIN
		IF (x.nrData) # (y.nrData) THEN diff.status := diff.status + {cBadLen} ELSE
			IF diff = NIL THEN NEW( diff ) END;
			i := 0;  chx := x.buf;
			WHILE (i < x.nrData) DO
				IF chx IS vyRealVec.tBuf THEN
					WITH chx: vyRealVec.tBuf DO vyRealVec.Append( vyRealVec.Get( x, i ) - vyRealVec.Get( y, i ), diff )
					END;
				ELSIF chx IS vyLongrealVec.tBuf THEN
					WITH chx: vyLongrealVec.tBuf DO
						vyLongrealVec.Append( vyLongrealVec.Get( x, i ) - vyLongrealVec.Get( y, i ), diff )
					END;
				ELSIF chx IS vyIntVec.tBuf THEN
					WITH chx: vyIntVec.tBuf DO vyIntVec.Append( vyIntVec.Get( x, i ) - vyIntVec.Get( y, i ), diff )
					END;
				ELSIF chx IS vyLongintVec.tBuf THEN
					WITH chx: vyLongintVec.tBuf DO vyLongintVec.Append( vyLongintVec.Get( x, i ) - vyLongintVec.Get( y, i ), diff )
					END;
				ELSE diff.status := diff.status + {cBadType}
				END;
				INC( i )
			END
		END
	END Sub;

	(*! interfaces may change to allow for sub matrices/vector parts *)
	(*! vectors may grow on the fly *)
	(*! additional vector information needs update *)
	(*PROCEDURE MCopyR* (v:tMatrix; VAR A:ARRAY OF ARRAY OF REAL);
VAR i,j:LONGINT;
BEGIN 	FOR i:=0 TO LEN(A,0) DO
FOR j:=0 TO LEN(A,1) DO
A[i,j]:=VGetR(v,GetIndex(v,i,j)); (*! use SYSTEM.COPYR to speed up *)
END;
END;
END MCopyR;

PROCEDURE RCopyM* (VAR A:ARRAY OF ARRAY OF REAL;v:tMatrix);
VAR i,j:LONGINT;
BEGIN
FOR i:=0 TO LEN(A,0) DO
FOR j:=0 TO LEN(A,1) DO
RSetV(A[i,j],v,GetIndex(v,i,j)); (*! use SYSTEM.COPYR to speed up *)
END;
END;
END RCopyM;
*)
(** Monadic operators and assignment *)

	PROCEDURE Copy*( src: vyBase.tData;  VAR dest: vyBase.tData );
	(*! only REAL vector so far -make full copy for any data type *)
	(*! dest must exist so far *)
	(*! speed up *)
	BEGIN
		ASSERT ( src IS vyBase.tVector );
		WITH src: vyBase.tVector DO
			IF dest = NIL THEN

				IF src IS vyRealVec.tVector THEN
					WITH src: vyRealVec.tVector DO
						dest := vyRealVec.New( src.nrData );  vyRealVec.CopyData( src, dest( vyRealVec.tVector ) );
					END;
				ELSIF src IS vyLongrealVec.tVector THEN
					WITH src: vyLongrealVec.tVector DO
						dest := vyLongrealVec.New( src.nrData );  vyLongrealVec.CopyData( src, dest( vyLongrealVec.tVector ) );
					END;
				ELSIF src IS vyIntVec.tVector THEN
					WITH src: vyIntVec.tVector DO
						dest := vyIntVec.New( src.nrData );  vyIntVec.CopyData( src, dest( vyIntVec.tVector ) );
					END;
				ELSIF src IS vyLongintVec.tVector THEN
					WITH src: vyLongintVec.tVector DO
						dest := vyLongintVec.New( src.nrData );  vyLongintVec.CopyData( src, dest( vyLongintVec.tVector ) );
					END;
				ELSIF src IS vyBooleanVec.tVector THEN
					WITH src: vyBooleanVec.tVector DO
						dest := vyBooleanVec.New( src.nrData );  vyBooleanVec.CopyData( src, dest( vyBooleanVec.tVector ) )
					END;
				END
			ELSE vyBase.Clear( dest )
			END
		END
	END Copy;

	(** Fill routines *)

	(*
PROCEDURE VectorType* (v: vyBase.tVector): INTEGER;
BEGIN
IF  v = NIL THEN RETURN cUNDEF END;
IF v.buf IS vyRealVec.tBuf THEN RETURN cREAL END;
IF v.buf IS tBuf THEN RETURN cBOOLEAN  END;
RETURN cUNDEF
END VectorType;
*)
(** Enquiry *)
	PROCEDURE SameLayout( a, b: vyBase.tVector ): BOOLEAN;
	VAR i: INTEGER;
	BEGIN
		IF (a.Layout = NIL ) & (b.Layout = NIL ) THEN RETURN TRUE
		ELSIF a.Layout.dim # b.Layout.dim THEN RETURN FALSE
		ELSIF (a.Layout IS vyBase.tArray) & (b.Layout IS vyBase.tArray) THEN
			i := 0;
			WHILE (i < vyHost.maxdims) & (i < a.Layout.dim) DO
				IF a.Layout( vyBase.tArray ).lens[i] # b.Layout( vyBase.tArray ).lens[i] THEN RETURN FALSE
				ELSIF a.Layout( vyBase.tArray ).lens[i] = 0 THEN RETURN TRUE
				ELSE INC( i )
				END
			END;   (* WHILE *)
			RETURN TRUE
		ELSE RETURN FALSE
		END
	END SameLayout;

	PROCEDURE SameType*( VAR a, b: vyBase.tData ): BOOLEAN;
	(*! should check for vector base types *)
	BEGIN
		IF (a IS vyBase.tVector) & (b IS vyBase.tVector) THEN
			IF (a( vyBase.tVector ).nrData # b( vyBase.tVector ).nrData) THEN RETURN FALSE
			ELSIF SameLayout( a( vyBase.tVector ), b( vyBase.tVector ) ) THEN RETURN TRUE
			ELSE RETURN FALSE
			END;   (*? all checked ?*)
		ELSIF (a IS vyBooleanVec.tBOOLEAN) & (b IS vyBooleanVec.tBOOLEAN) THEN RETURN TRUE
		ELSIF (a IS vyLongintVec.tLONGINT) & (b IS vyLongintVec.tLONGINT) THEN RETURN TRUE
		ELSIF (a IS vyLongrealVec.tLONGREAL) & (b IS vyLongrealVec.tLONGREAL) THEN RETURN TRUE
		ELSIF (a IS vyIntVec.tINTEGER) & (b IS vyIntVec.tINTEGER) THEN RETURN TRUE
		ELSIF (a IS vyRealVec.tREAL) & (b IS vyRealVec.tREAL) THEN RETURN TRUE
		ELSE RETURN FALSE
		END
	END SameType;

	PROCEDURE Compatible*( VAR a, b: vyBase.tData ): BOOLEAN;
	(*! define relaxed rules for compatibility *)
	BEGIN
		RETURN SameType( a, b )
	END Compatible;

	PROCEDURE Summary*( VAR w: vyBase.TextsWriter;  v: vyBase.tData );
	VAR i: LONGINT;  min, max: LONGREAL;  nrNaNs: LONGINT;
	BEGIN
		IF v IS vyBase.tVector THEN
			IF v IS vyBase.tVector THEN
				WITH v: vyBase.tVector DO
					Texts.WriteString( w, ' Summary for vector. nrData=' );  Texts.WriteInt( w, v.nrData, 0 );  VGetMinMax( v, min, max, nrNaNs );
					Texts.WriteString( w, ' Min=' );  vyHostTexts.WReal( w, min, 12 );  Texts.WriteString( w, ' Max=' );
					vyHostTexts.WReal( w, max, 12 );
					IF nrNaNs > 0 THEN Texts.WriteString( w, ' NaNs=' );  Texts.WriteInt( w, nrNaNs, 12 ) END;
					IF v.Layout # NIL THEN
						IF v.Layout IS vyBase.tArray THEN
							Texts.WriteString( w, ' [' );
							FOR i := 0 TO v.Layout.dim - 2 DO Texts.WriteInt( w, v.Layout( vyBase.tArray ).lens[i], 0 );  Texts.Write( w, ',' ) END;
							Texts.WriteInt( w, v.Layout( vyBase.tArray ).lens[v.Layout.dim - 1], 0 );  Texts.Write( w, ']' )
						ELSE Texts.WriteString( w, ' dim=' );  Texts.WriteInt( w, v.Layout.dim, 0 )
						END;
						IF v.Layout.transposed THEN Texts.WriteString( w, ' stored in transposed form' ) END
					END;
					Texts.WriteLn( w );
					(*! replace by global summary *)
					Texts.WriteString( w, 'Summaries by chunk:' );  Texts.WriteLn( w );  ChunkSummary( w, v.buf )
				END;
			ELSE Write( w, v )
			END
		END
	END Summary;

	PROCEDURE DebugSummary*( v: vyBase.tData );
	VAR c: vyBase.tBuf;  v1: vyBase.tData;
	BEGIN
		Texts.WriteString( vyHostTexts.w, "DebugSummary " );
		IF v IS vyBase.tVector THEN
			v1 := v;
			WITH v1: vyBase.tVector DO
				Texts.WriteString( vyHostTexts.w, " is vector. nrData:" );  Texts.WriteInt( vyHostTexts.w, v1( vyBase.tVector ).nrData, 0 );
				Summary( vyHostTexts.w, v1( vyBase.tVector ) );
				IF (v1.buf # NIL ) (* & ((v1.buf IS vyRealVec.tBuf) OR (v1.buf IS tBuf) OR (v1.buf IS tBuf)
				OR (v1.buf IS vyLongintVec.tBuf) OR (v1.buf IS tBuf))*)
				THEN
					c := v1.buf;
					WHILE c # NIL DO
						Texts.WriteString( vyHostTexts.w, 'len:' );  Texts.WriteInt( vyHostTexts.w, c.len, 0 );
						Texts.WriteString( vyHostTexts.w, ' used:' );  Texts.WriteInt( vyHostTexts.w, c.usedentries, 0 );
						IF c IS vyBooleanVec.tBuf THEN
							WITH c: vyBooleanVec.tBuf DO vyBooleanVec.ChunkSummary( vyHostTexts.w, c )
							END;
						ELSIF c IS vyIntVec.tBuf THEN
							WITH c: vyIntVec.tBuf DO vyIntVec.ChunkSummary( vyHostTexts.w, c )
							END;
						ELSIF c IS vyLongintVec.tBuf THEN
							WITH c: vyLongintVec.tBuf DO vyLongintVec.ChunkSummary( vyHostTexts.w, c )
							END;
						ELSIF c IS vyRealVec.tBuf THEN
							WITH c: vyRealVec.tBuf DO vyRealVec.ChunkSummary( vyHostTexts.w, c )
							END;
						ELSIF c IS vyLongrealVec.tBuf THEN
							WITH c: vyLongrealVec.tBuf DO vyLongrealVec.ChunkSummary( vyHostTexts.w, c )
							END;
						ELSE
						END;
						Texts.WriteLn( vyHostTexts.w );  c := c.next
					END
				END
			END
		END;
		vyHostTexts.InsertLog( vyHostTexts.w.buf )
	END DebugSummary;

	PROCEDURE DebugWrite*( v: vyBase.tData );
	BEGIN
		Texts.WriteString( vyHostTexts.w, "DebugWrite " );
		IF v IS vyBase.tVector THEN Write( vyHostTexts.w, v( vyBase.tVector ) ) END;
		vyHostTexts.InsertLog( vyHostTexts.w.buf )
	END DebugWrite;

(** Conversion *)
	PROCEDURE Short*( from: vyBase.tData ): vyBase.tData;
	(*! speedup: use chunk structure *)
	VAR fromv, v: vyBase.tVector;  i: LONGINT;  len: LONGINT;
	BEGIN
		ASSERT ( from # NIL , 100 );
		ASSERT ( (from IS vyBase.tVector), 101 );
		len := vyBase.Len( from, 0 );  fromv := from( vyBase.tVector );
		IF from IS vyLongrealVec.tVector (*from.type.basetype=lrltyp*) THEN
			v := vyRealVec.New( len );
			FOR i := 0 TO len - 1 DO vyRealVec.Set( SHORT( vyLongrealVec.Get( fromv, i ) ), v, i ) END;
			RETURN v
		ELSIF from IS vyLongintVec.tVector (*from.type.basetype=linttyp*) THEN
			v := vyIntVec.New( len );
			FOR i := 0 TO len - 1 DO vyIntVec.Set( SHORT( vyLongintVec.Get( fromv, i ) ), v, i ) END;
			RETURN v
			(*	ELSIF from.type.basetype=inttyp THEN *)  (*! SHORTINT not yet supported *)
		ELSE RETURN NIL
		END
	END Short;

	PROCEDURE Entier*( from: vyBase.tData;  offs, factor: LONGREAL ): vyBase.tData;
	(*= offs and factor are included to allow some scaling *)
	(*! speedup: use chunk structure *)
	VAR fromv, v: vyBase.tVector;  i: LONGINT;  len: LONGINT;
	BEGIN
		ASSERT ( from # NIL , 100 );
		ASSERT ( (from IS vyBase.tVector), 101 );
		len := vyBase.Len( from, 0 );  fromv := from( vyBase.tVector );
		IF from IS vyLongrealVec.tVector (*from.type.basetype=lrltyp*) THEN
			v := vyLongintVec.New( len );
			FOR i := 0 TO len - 1 DO vyLongintVec.Set( ENTIER( vyLongrealVec.Get( fromv, i ) * factor + offs ), v, i ) END;
			RETURN v
		ELSIF from IS vyRealVec.tVector (*from.type.basetype=linttyp*) THEN
			v := vyLongintVec.New( len );
			FOR i := 0 TO len - 1 DO vyLongintVec.Set( ENTIER( vyRealVec.Get( fromv, i ) * factor + offs ), v, i ) END;
			RETURN v
			(*	ELSIF from.type.basetype=inttyp THEN *)  (*! SHORTINT not yet supported *)
		ELSE RETURN NIL
		END
	END Entier;

	PROCEDURE CvtReal*( src: vyBase.tData ): vyBase.tData;
	(*= Convert any src to REAL, if safe and reliable *)
	VAR temp: vyBase.tData;  i: LONGINT;  len: LONGINT;  from, v: vyBase.tVector;
	BEGIN
		ASSERT ( (src # NIL ), 100 );
		ASSERT ( (src IS vyBase.tVector), 101 );
		temp := NIL;  len := vyBase.Len( src, 0 );  from := src( vyBase.tVector );

		IF from IS vyRealVec.tVector THEN Copy( from, temp );  RETURN temp
		ELSIF from IS vyLongrealVec.tVector THEN RETURN Short( from )
		ELSIF from IS vyLongintVec.tVector THEN
			v := vyRealVec.New( len );
			FOR i := 0 TO len - 1 DO vyRealVec.Set( SHORT( vyLongintVec.Get( from, i ) ), v, i ) END;
			RETURN v
		ELSIF from IS vyIntVec.tVector THEN
			v := vyRealVec.New( len );
			FOR i := 0 TO len - 1 DO vyRealVec.Set( SHORT( vyIntVec.Get( from, i ) ), v, i ) END;
			RETURN v
		ELSE HALT( 102 )
		END
	END CvtReal;

END vyTypes.