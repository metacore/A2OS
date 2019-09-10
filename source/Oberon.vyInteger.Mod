MODULE vyInteger IN Oberon;
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



IMPORT
	Files, vyBase;

CONST idversion* = ' v0r0a3';
	(*= start and len parameters are passed as explicit parameters, to allow for incomplete buffers, or simulated higher dim arrays. *)
	(* strategies: pre-check array bounds *)
	(*? limit counts at 0 or 1 ? 0 may need exception anyhow, so 1 is ok *)
	(* Assertion models: single array
	(len:SIGNED32; VAR x: ARRAY OF FLOAT64; start: SIGNED32; .....)
	ASSERT(start>=0,100);ASSERT(len>=0,101);
	ASSERT(start<=LEN(x)-len,102);

	single array with step size
	(len:SIGNED32; VAR x: ARRAY OF FLOAT64; start, step: SIGNED32; .....)
	ASSERT(start>=0,100);ASSERT(len>=0,101);
	ASSERT(start+len<=LEN(x),102);	ASSERT(step>0,103);

	*)

	(*= storage formats *)
	fmtany* = 0;   (*= never in stored format. fmtany in storage signals termination*)
	fmtend* = 0;  (*= termination*)
	fmtplain* = 1;
	fmtpacked* = 2;

TYPE
	int = SIGNED16;  (* technical convenience, to avoid triplicate code for  intger types  *)
	index = SIGNED32;

	(** File storage *)

PROCEDURE Write* (VAR R: Files.Rider;  count: index;  VAR x: ARRAY OF int;  start: index);

BEGIN
	ASSERT(start >= 0, 100);  ASSERT(count >= 0, 101);
	ASSERT(start <= LEN(x) - count, 102);
	count := start + count;
	WHILE start < count DO Files.WriteInt(R, x[start]);  INC(start) END
END Write;

PROCEDURE Read* (VAR R: Files.Rider;  count: index;  VAR x: ARRAY OF int;  start: index);

BEGIN
	ASSERT(start >= 0, 100);  ASSERT(count >= 0, 101);
	ASSERT(start <= LEN(x) - count, 102);
	count := start + count;
	WHILE start < count DO Files.ReadInt(R, x[start]);  INC(start) END
END Read;

(*= Formatted write, eg. packed, sparse... *)
(*! add implementations *)
(*= file is a series of packages of structure
<formatkey>: SIGNED32
0: terminate. No further information in this record
1: plain
2: repeat packing
<start><count> : SIGNED32
<privat packing data>
*)
(*= packed format.
formatkey=1
count: total number of entries
<default>: real. Gaps between packages are filled with this value, eg. 0 or NaN
[<packcount>   <packstart>	<packval> ] terminates on packcount 0
*)
(*! check add implementations *)

PROCEDURE WriteFmt* (prefform: SIGNED32;  VAR R: Files.Rider;  count: index;  VAR x: ARRAY OF int;  start: index);

	(*= prefform is the preferred storage format, but the internal algorithm may choose a different one *)

BEGIN
	(*! add implementations for non plain. form ignored so far *)
	Files.WriteLInt(R, fmtplain);
	Files.WriteLInt(R, start);
	Files.WriteLInt(R, count);
	Write(R, count, x, start);
	Files.WriteLInt(R, fmtend)
END WriteFmt;

PROCEDURE ReadFmt* (VAR form: SIGNED32;  VAR R: Files.Rider;  count: index;  VAR x: ARRAY OF int;  start: index);

	VAR stop: SIGNED32;

BEGIN
	(*! add implementations for non plain. form ignored so far *)
	Files.ReadLInt(R, form);
	Files.ReadLInt(R, start);
	Files.ReadLInt(R, count);
	Read(R, count, x, start);
	Files.ReadLInt(R, stop);
	ASSERT(stop = fmtend, 100)
END ReadFmt;

(** Basic **)
PROCEDURE Fill* (len: SIGNED32; VAR x: ARRAY OF SIGNED16;  start: SIGNED32; val: SIGNED16);
BEGIN
	ASSERT(start >= 0, 100); ASSERT(len >= 0, 101);
	ASSERT(start <= LEN(x) - len, 102);
	len := start + len; (* used as top *)
	WHILE start < len DO x[start] := val;  INC(start) END
END Fill;

PROCEDURE FillPat* (count: SIGNED32; VAR x: ARRAY OF SIGNED16;  start, step: SIGNED32;
val: SIGNED16);
BEGIN ASSERT(start >= 0, 100); ASSERT(count >= 0, 101);
	ASSERT(count * step <= LEN(x) - start, 102); 	ASSERT(step > 0, 103);
	count := start + count * step;  (* used as top *)
	WHILE start < count DO x[start] := val;  INC(start, step) END;
END FillPat;

PROCEDURE Copy* (len: SIGNED32;
VAR src: ARRAY OF SIGNED16; srcstart: SIGNED32;
VAR dest: ARRAY OF SIGNED16; deststart: SIGNED32 );
	(*= The array src isn't changed *)
BEGIN
	ASSERT(len > 0, 100);
	ASSERT(srcstart <= LEN(src) - len, 101);
	ASSERT(deststart <= LEN(dest) - len, 102);
	vyBase.COPYI(src, srcstart, len, dest, deststart);
END Copy;

PROCEDURE CopyPat* (count: SIGNED32; VAR src: ARRAY OF SIGNED16; start, step: SIGNED32; VAR dest: ARRAY OF SIGNED16;  deststart, deststep: SIGNED32);
	(*= The array src isn't changed *)
	VAR i, j, top: SIGNED32;
BEGIN
	ASSERT((start >= 0) & (deststart >= 0), 100); ASSERT(count >= 0, 101);
	ASSERT((step > 0) & (deststep > 0), 103);
	ASSERT((start + count * step <= LEN(src))
	 & (deststart + count * deststep <= LEN(dest)), 102);
	i := start; j := deststart; top := start + count * step;
	WHILE i < top DO dest[j] := src[i]; INC(i, step); INC(j, deststep) END;
END CopyPat;

PROCEDURE Min* (len: SIGNED32; VAR x: ARRAY OF SIGNED16; start: SIGNED32; VAR minpos: SIGNED32): SIGNED16;
	(*= The array x isn't changed *)
	VAR min: SIGNED16;
BEGIN
	ASSERT(start >= 0, 100); ASSERT(len >= 0, 101);
	ASSERT(start <= LEN(x) - len, 102);
	min := MAX(SIGNED16); minpos := - 1;  len := start + len;
	WHILE start < len DO
		IF x[start] < min THEN min := x[start];  minpos := start END;
	INC(start) END;
	RETURN min;
END Min;

PROCEDURE Max* (len: SIGNED32; VAR x: ARRAY OF SIGNED16;  start: SIGNED32;  VAR maxpos: SIGNED32): SIGNED16;
	(*= The array x isn't changed *)
	VAR max: SIGNED16;
BEGIN
	ASSERT(start >= 0, 100); ASSERT(len >= 0, 101);
	ASSERT(start <= LEN(x) - len, 102);
	max := MIN(SIGNED16); maxpos := - 1; len := start + len;
	WHILE start < len DO
		IF x[start] > max THEN max := x[start]; maxpos := start END;
	INC(start) END;
	RETURN max;
END Max;

PROCEDURE MinMax* (len: SIGNED32; VAR x: ARRAY OF SIGNED16;  start: SIGNED32;
VAR min: SIGNED16;  VAR minpos: SIGNED32;  VAR max: SIGNED16;  VAR maxpos: SIGNED32; VAR nans: SIGNED32);
BEGIN
	ASSERT(start >= 0, 100); ASSERT(len >= 0, 101);
	ASSERT(start <= LEN(x) - len, 102);
	nans := 0;  (*! not yet implemented *)
	IF ODD(len) THEN
		max := x[start]; min := max; minpos := start;  maxpos := start;
		len := len + start;  INC(start);
	ELSE	max := MIN(SIGNED16); min := MAX(SIGNED16);
		minpos := - 1; maxpos := - 1; len := len + start;
	END;
	WHILE start < len DO
		IF x[start] > x[start + 1] THEN
			IF x[start] > max THEN max := x[start]; maxpos := start END;
			INC(start);
			IF x[start] < min THEN min := x[start]; minpos := start END;
		ELSE
			IF x[start] < min THEN min := x[start]; minpos := start END;
			INC(start);
			IF x[start] > max THEN max := x[start]; maxpos := start END;
		END;
	INC(start) END;
END MinMax;

(* test site to look for high speed low count exchanges *)
PROCEDURE sort5* (VAR data: ARRAY OF SIGNED16;  start: SIGNED32);
	(*= Procedure only for test functions *)
BEGIN
	Sort(5, data, start);
END sort5;

PROCEDURE Sort5* (VAR data: ARRAY OF SIGNED16;  start: SIGNED32);
BEGIN
	ASSERT(start >= 0, 100);
	ASSERT(start <= LEN(data) - 5, 102);
	sort5(data, start);
END Sort5;

PROCEDURE Sort* (count: SIGNED32;  VAR x: ARRAY OF SIGNED16; start: SIGNED32); (** vs 0.1d0 gs *)
	(** Quicksort ist used for normal sorting *)
PROCEDURE LocSort (lo, hi: SIGNED32); (* Quicksort *)
	VAR i, j, m: SIGNED32; temp: SIGNED16;
BEGIN
	IF lo < hi THEN i := lo;  j := hi;  m := (lo + hi) DIV 2;
		REPEAT
			WHILE (x[i] < x[m]) DO INC(i) END;
			WHILE (x[ m] < x[ j]) DO DEC(j) END;
			IF i <= j THEN
				IF m = i THEN m := j ELSIF m = j THEN m := i END;
				temp := x[i]; x[i] := x[j]; x[j] := temp; (*Swap(data, i, j); *)
				(* 970919 fof inserted temp for windows compatibilty (~"too many registers")*)
				INC(i);  DEC(j)
			END
		UNTIL i > j;
		LocSort(lo, j);  LocSort(i, hi)
	END
END LocSort;
BEGIN
	ASSERT(count >= 0, 100); ASSERT(start >= 0, 101);  	ASSERT(start + count <= LEN(x), 102);
	IF count < 2 THEN RETURN END;
	LocSort(start, start + count - 1);
END Sort;

(*? Is it useful to have two general sorting algorithms? *)
PROCEDURE MergeSort* (count: SIGNED32;  VAR x: ARRAY OF SIGNED16; start: SIGNED32); (* Natural Mergesort for normal sorting *)
	(* 	Contact	M. Fuchs <fuchs@statlab.uni-heidelberg.de> *)
PROCEDURE NMerge (lo, hi: SIGNED32); (* Natural Mergesort *)
PROCEDURE Merge (l, m, r: SIGNED32); 	(* Mixing the preorderd Runs *)
	VAR hx : POINTER TO ARRAY OF SIGNED16; 	(* Arrays to store the datas temporary *)
	h, i, j, k : SIGNED32;
BEGIN
	NEW(hx, r - l + 1); 	(*Allocation of store *)
	i := l;  j := m + 1;  k := 0;
	WHILE (i <= m) & (j <= r) DO
		IF x[i] <= x[j] THEN
			hx[k] := x[i]; 	(* store in the temporary array *)
			INC(i)
		ELSE
			hx[k] := x[j]; 	(* store in the temporary array *)
			INC(j)
		END;
		INC(k);
	END;
	IF i > m THEN
		FOR h := j TO r DO
			hx[k + h - j] := x[h]; 	(* store the rest of the nonempty run in the temporary array *)
		END
	ELSE
		FOR h := i TO m DO
			hx[k + h - i] := x[h]; 	(* store the rest of the nonempty run in the temporary array *)
		END
	END;
	FOR h := l TO r DO
		x[h] := hx[h - l]; 	(* restore the sorted run *)
	END
END Merge;

PROCEDURE NMS (l, r: SIGNED32); 	(* Searching of preorderd runs and merge them *)
	VAR rr, ll, mm: SIGNED32;
BEGIN
	REPEAT
		rr := l - 1;
		WHILE rr < r DO
			ll := rr + 1;  mm := ll;
			WHILE ((mm < r) & (x[mm] <= x[mm + 1])) DO (* determination of the left run *)
				INC(mm)
			END;
			IF mm < r THEN
				rr := mm + 1;
				WHILE ((rr < r) & (x[rr] <= x[rr + 1])) DO (* determination of the next run *)
					INC(rr)
				END;
				Merge(ll, mm, rr)	(* Mix the preorderd runs *)
			ELSE
				rr := mm
			END
		END
	UNTIL ll = l
END NMS;
BEGIN
	NMS(lo, hi);
END NMerge;
BEGIN
	ASSERT(count >= 0, 100); ASSERT(start >= 0, 101);  	ASSERT(start + count <= LEN(x), 102);
	IF count < 2 THEN RETURN END;
	NMerge(start, start + count - 1)
END MergeSort;


PROCEDURE SortIndexed* (count: SIGNED32;  VAR data: ARRAY OF SIGNED16; start: SIGNED32; VAR index: ARRAY OF SIGNED32);
	(** Natural Mergesort is used for indexed sorting *)
	(* 	Contact	M. Fuchs <fuchs@statlab.uni-heidelberg.de> *)
PROCEDURE NMergeIndexed (lo, hi: SIGNED32); (* Natural Mergesort *)
PROCEDURE MergeIndexed (l, m, r: SIGNED32); 	(* Mixing the preorderd Runs *)
	VAR hdata : POINTER TO ARRAY OF SIGNED16;
	hindex : POINTER TO ARRAY OF SIGNED32; 	(* Arrays to store the datas temporary *)
	h, i, j, k : SIGNED32;
BEGIN
	NEW(hdata, r - l + 1);  NEW(hindex, r - l + 1); 	(*Allocation of store *)
	i := l;  j := m + 1;  k := 0;
	WHILE (i <= m) & (j <= r) DO
		IF data[i] <= data[j] THEN
			hdata[k] := data[i];  hindex[k] := index[i];  (* store in the temporary array *)
			INC(i)
		ELSE
			hdata[k] := data[j];  hindex[k] := index[j];  (* store in the temporary array *)
			INC(j)
		END;
		INC(k);
	END;
	IF i > m THEN
		FOR h := j TO r DO
			hdata[k + h - j] := data[h];  hindex[k + h - j] := index[h]; 	(* store the rest of the nonempty run in the temporary array *)
		END
	ELSE
		FOR h := i TO m DO
			hdata[k + h - i] := data[h];  hindex[k + h - i] := index[h]; 	(* store the rest of the nonempty run in the temporary array *)
		END
	END;
	FOR h := l TO r DO
		data[h] := hdata[h - l];  index[h] := hindex[h - l]; 	(* restore the sorted run *)
	END
END MergeIndexed;

PROCEDURE NMSIndexed (l, r: SIGNED32); 	(* Searching of preorderd runs and merge them *)
	VAR rr, ll, mm: SIGNED32;
BEGIN
	REPEAT
		rr := l - 1;
		WHILE rr < r DO
			ll := rr + 1;  mm := ll;
			WHILE ((mm < r) & (data[mm] <= data[mm + 1])) DO (* determination of the left run *)
				INC(mm)
			END;
			IF mm < r THEN
				rr := mm + 1;
				WHILE ((rr < r) & (data[rr] <= data[rr + 1])) DO (* determination of the next run *)
					INC(rr)
				END;
				MergeIndexed(ll, mm, rr)	(* Mix the preorderd runs *)
			ELSE
				rr := mm
			END
		END
	UNTIL ll = l
END NMSIndexed;
BEGIN
	NMSIndexed(lo, hi);
END NMergeIndexed;
BEGIN
	ASSERT(count >= 0, 100); ASSERT(start >= 0, 101);  ASSERT(start + count <= LEN(data), 102);
	ASSERT(LEN(index) = LEN(data), 103);
	IF count < 2 THEN RETURN END;
	NMergeIndexed(start, start + count - 1)
END SortIndexed;

(*! add procedure based sorts if necessary *)


PROCEDURE Order* (count: index;  x: ARRAY OF int;  start: index;  ith: index): int;

PROCEDURE LocSort (lo, hi: index;  order: index): int;
	(* Quicksort *)

VAR
	i, j, m, k: index;
	temp: int;

BEGIN
	IF lo >= hi THEN RETURN x[lo] END;
	(*! partititon. return by randomized partition lo hi *)
	IF lo < hi THEN i := lo;  j := hi;  m := (lo + hi) DIV 2;
		REPEAT
			WHILE (x[i] < x[m]) DO INC(i) END;
			WHILE (x[m] < x[j]) DO DEC(j) END;
			IF i <= j THEN
				IF m = i THEN m := j ELSIF m = j THEN m := i END;
				temp := x[i];  x[i] := x[j];  x[j] := temp;  (*Swap(data, i, j); *)
				(* 970919 fof inserted temp for windows compatibilty (~"too many registers")*)
				INC(i);  DEC(j)
			END
		UNTIL i > j;
		(* end randomized partition *)
		IF j < lo THEN INC(j) END;  	(*	Gruss von Lutz 20.3.96	*)
		k := j - lo + 1;
		IF order <= k THEN RETURN LocSort(lo, j, order)
		ELSE
			RETURN LocSort(j + 1, hi, order - k)
		END
	END
END LocSort;

BEGIN
	(*Corman et al. Algorithms., 10.2 *)
	ASSERT(count >= 0, 100);
	ASSERT(start >= 0, 101);
	ASSERT(start + count <= LEN(x), 102);
	IF count < 2 THEN RETURN x[start] END; 	(*	Gruss von Lutz 20.3.96	*)
	RETURN LocSort(start, start + count - 1, ith)
END Order;

PROCEDURE Summary* (len: SIGNED32; VAR x: ARRAY OF SIGNED16;
start: SIGNED32;  VAR min, max: SIGNED16; VAR mean, ssq: FLOAT64); (** vs 0.1d0 gs *)
	(*= The array x isn't changed *)
	(* One pass summary *)
	VAR i, top: SIGNED32; Xdiff: FLOAT64; xx: SIGNED16;
BEGIN
	min := MAX(SIGNED16);  max := MIN(SIGNED16);  mean := 0;  ssq := 0;
	i := start; top := start + len;
	WHILE i < top DO xx := x[i];
		IF xx > max THEN max := xx END;
		IF xx < min THEN min := xx END;
		(* Provisional means *)
		Xdiff := xx - mean;  mean := mean + Xdiff / (i + 1 - start);
		ssq := ssq + Xdiff * (xx - mean);
	INC(i) END;
END Summary;

PROCEDURE MeanSSq* (len: SIGNED32;  VAR x: ARRAY OF int;  start: SIGNED32;  VAR mean, ssq: FLOAT64; VAR nans: SIGNED32);
	VAR i, top: SIGNED32;  Xdiff: FLOAT64;  xx: int;
BEGIN
	nans := 0;  (*! not yet supported *)
	mean := 0;  ssq := 0;
	i := start;  top := start + len;
	WHILE i < top DO xx := x[i];
		(* Provisional means *)
		Xdiff := xx - mean;
		mean := mean + Xdiff / (i + 1 - start);
		ssq := ssq + Xdiff * (xx - mean);
	INC(i) END
END MeanSSq;

(** Predeclared functions *)
PROCEDURE Abs* (len: SIGNED32;  VAR x: ARRAY OF SIGNED16; start: SIGNED32);
	VAR i, top: SIGNED32;
BEGIN ASSERT(start >= 0, 100); ASSERT(len >= 0, 101);
	ASSERT(start + len <= LEN(x), 102);
	i := start;  top := start + len;
	WHILE i < top DO x[i] := ABS(x[i]); INC(i) END;
END Abs;

(** Vector-Scalar operations *)
PROCEDURE AddConst* (len: SIGNED32;  VAR x: ARRAY OF SIGNED16; start: SIGNED32; 	y: SIGNED16);
	VAR i, top: SIGNED32;
BEGIN ASSERT(start >= 0, 100); ASSERT(len >= 0, 101);
	ASSERT(start + len <= LEN(x), 102);
	i := start;  top := start + len;
	WHILE i < top DO x[i] := x[i] + y; INC(i) END;
END AddConst;

PROCEDURE AddConstPat* (count: index;  VAR x: ARRAY OF int;  start, step: index;  y: int);
	(*! test this procedure *)
	(*! klären, ob ASSERT 102 als bedingung nicht start+count*step<=LEN(x) braucht (so wie in CopyPat bzw. FillPat) *)

VAR
	i, top: index;

BEGIN
	ASSERT(start >= 0, 100);  ASSERT(count >= 0, 101);
	ASSERT(start + (count - 1) * step + 1 <= LEN(x), 102);
	ASSERT(step > 0, 103);
	i := start;  top := start + count * step;
	WHILE i < top DO x[i] := x[i] + y;  INC(i, step) END
END AddConstPat;

PROCEDURE SubConst* (len: SIGNED32;  VAR x: ARRAY OF SIGNED16; start: SIGNED32; 	y: SIGNED16);
BEGIN
	AddConst(len, x, start, (- 1) * y)
END SubConst;

PROCEDURE SubConstPat* (count: index;  VAR x: ARRAY OF int;  start, step: index;  y: int);

BEGIN
	AddConstPat(count, x, start, step, - y)
END SubConstPat;

PROCEDURE MulConst* (len: SIGNED32;  VAR x: ARRAY OF SIGNED16;  start: SIGNED32;  y: SIGNED16 );
	VAR i, top: SIGNED32;
BEGIN ASSERT(start >= 0, 100); ASSERT(len >= 0, 101);
	ASSERT(start + len <= LEN(x), 102);
	i := start;  top := start + len;
	WHILE i < top DO x[i] := x[i] * y; INC(i) END;
END MulConst;

PROCEDURE MulConstPat* (count: index;  VAR x: ARRAY OF int;  start, step: index;  fact: int);
	(*! ASSERT 102 klären, siehe AddConstPat *)
	(*! test this procedure *)

VAR
	i, top: index;

BEGIN
	ASSERT(start >= 0, 100);  ASSERT(count >= 0, 101);
	ASSERT(start + (count - 1) * step + 1 <= LEN(x), 102);
	ASSERT(step > 0, 103);
	i := start;  top := start + count * step;
	WHILE i < top DO x[i] := x[i] * fact;  INC(i, step) END
END MulConstPat;

PROCEDURE DivConst* (len: SIGNED32;  VAR x: ARRAY OF SIGNED16;  start: SIGNED32;  y: SIGNED16 );
	VAR i, top: SIGNED32;
BEGIN ASSERT(start >= 0, 100); ASSERT(len >= 0, 101);
	ASSERT(start + len <= LEN(x), 102);
	i := start;  top := start + len;
	WHILE i < top DO x[i] := x[i] DIV y; INC(i) END;
END DivConst;

PROCEDURE DivConstPat* (count: index;  VAR x: ARRAY OF int;  start, step: index;  y: int);

VAR
	i, top: index;

BEGIN
	ASSERT(start >= 0, 100);  ASSERT(count >= 0, 101);
	ASSERT(start + (count - 1) * step + 1 <= LEN(x), 102);
	ASSERT(step > 0, 103);
	i := start;  top := start + count * step;
	WHILE i < top DO x[i] := x[i] DIV y;  INC(i, step) END;
END DivConstPat;

PROCEDURE ModConst* (len: SIGNED32;  VAR x: ARRAY OF SIGNED16;  start: SIGNED32;  y: SIGNED16 );
	VAR i, top: SIGNED32;
BEGIN ASSERT(start >= 0, 100); ASSERT(len >= 0, 101);
	ASSERT(start + len <= LEN(x), 102);
	i := start;  top := start + len;
	WHILE i < top DO x[i] := x[i] MOD y; INC(i) END;
END ModConst;

PROCEDURE ModConstPat* (count: index;  VAR x: ARRAY OF int;  start, step: index;  y: int);

VAR
	i, top: index;

BEGIN
	ASSERT(start >= 0, 100);  ASSERT(count >= 0, 101);
	ASSERT(start + (count - 1) * step + 1 <= LEN(x), 102);
	ASSERT(step > 0, 103);
	i := start;  top := start + count * step;
	WHILE i < top DO x[i] := x[i] MOD y;  INC(i, step) END;
END ModConstPat;

(** Vector-Vector operations, assuming equivalent vectors. Interface may change!!! *)
PROCEDURE Add* (VAR x, y: ARRAY OF SIGNED16; VAR z: ARRAY OF SIGNED16;  len: SIGNED32 );
	(*= The arrays x and y aren't changed *)
	VAR i: SIGNED32;  temp: SIGNED16;
BEGIN
	i := 0;  WHILE i < len DO temp := x[i] + y[i]; z[i] := temp;  INC(i) END;
	(* 970919 fof inserted temp for windows compatibilty (~"too many registers")*)
END Add;

PROCEDURE Sub* (VAR x, y: ARRAY OF SIGNED16; VAR z: ARRAY OF SIGNED16;  len: SIGNED32 );
	(*= The arrays x and y aren't changed *)
	VAR i: SIGNED32;  temp: SIGNED16;
BEGIN
	i := 0;  WHILE i < len DO temp := x[i] - y[i]; z[i] := temp; INC(i) END;
	(* 970919 fof inserted temp for windows compatibilty (~"too many registers")*)
END Sub;

PROCEDURE Mul* (VAR x, y: ARRAY OF SIGNED16; VAR z: ARRAY OF SIGNED16;  len: SIGNED32 );
	(*= The arrays x and y aren't changed *)
	VAR i: SIGNED32;  temp: SIGNED16;
BEGIN
	i := 0;  WHILE i < len DO temp := x[i] * y[i] ;  z[i] := temp; INC(i) END;
	(* 970919 fof inserted temp for windows compatibilty (~"too many registers")*)
END Mul;

PROCEDURE Div* (VAR x, y: ARRAY OF SIGNED16; VAR z: ARRAY OF SIGNED16;  len: SIGNED32 );
	(*= The arrays x and y aren't changed *)
	VAR i: SIGNED32;  temp: SIGNED16;
BEGIN
	i := 0;  WHILE i < len DO temp := x[i] DIV y[i];  z[i] := temp; INC(i) END;
	(* 970919 fof inserted temp for windows compatibilty (~"too many registers")*)
END Div;

PROCEDURE SSQxy* (VAR x, y: ARRAY OF SIGNED16;
mx, my: FLOAT64;
len: SIGNED32): FLOAT64; (** vs 0.1d0 gs *)
	(*= The arrays x and y aren't changed *)
	VAR i: SIGNED32; s: FLOAT64;
BEGIN
	s := 0; i := 0;  WHILE i < len DO s := s + (x[i] - mx) * (y[i] - my);  INC(i);  END;
	RETURN s;
END SSQxy;

(* 2D support *)
PROCEDURE Get2d* (VAR x: ARRAY OF SIGNED16;  rows, row, column: SIGNED32): SIGNED16;
	(*= The array x isn't changed *)
BEGIN
	ASSERT(rows >= row);
	RETURN x[row * rows + column]
END Get2d;

PROCEDURE Set2d* (VAR x: ARRAY OF SIGNED16;  rows, row, column: SIGNED32; val: SIGNED16);
BEGIN
	ASSERT(rows >= row);
	x[row * rows + column] := val
END Set2d;

PROCEDURE Get2dM* (VAR x: ARRAY OF SIGNED16;
rowoffset, coloffset, nrrows, nrcolumns: SIGNED32; VAR dest: ARRAY OF ARRAY OF SIGNED16);  (*vs 0.1d0 gs *)
	(*= copy a 1-dim array as nrrows,nrcolumns submatrix into dest, while the array x isn't changed *)
	VAR i, j, k: SIGNED32;
BEGIN	k := 0;
	FOR i := rowoffset TO rowoffset + nrrows DO
		FOR j := coloffset TO coloffset + nrcolumns DO dest[i, j] := x[k];  INC(k);
		END;
	END;
END Get2dM;

PROCEDURE Set2dM* (VAR x: ARRAY OF SIGNED16;
rowoffset, coloffset, nrrows, nrcolumns: SIGNED32; VAR src: ARRAY OF ARRAY OF SIGNED16);  (*vs 0.1d0 gs *)
	(*= set a 1-dim array as nrrows,nrcolumns submatrix from src, while the array src isn't changed *)
	VAR i, j, k: SIGNED32;
BEGIN 	k := 0;
	FOR i := rowoffset TO rowoffset + nrrows DO
		FOR j := coloffset TO coloffset + nrcolumns DO x[k] := src[i, j];  INC(k);
		END;
	END;
END Set2dM;

(*? 2D support - FORTRAN-like. Are these needed ?*)
PROCEDURE Get2dF* (VAR x: ARRAY OF SIGNED16;  columns, row, column: SIGNED32): SIGNED16;
	(*= The array x isn't changed *)
BEGIN
	ASSERT(columns >= column);
	RETURN x[row + column * columns]
END Get2dF;

PROCEDURE Set2dF* (VAR x: ARRAY OF SIGNED16;  columns, row, column: SIGNED32; val: SIGNED16);
BEGIN
	ASSERT(columns >= column);
	x[row + column * columns] := val
END Set2dF;

PROCEDURE SkalProd* (len: SIGNED32;  VAR x: ARRAY OF SIGNED16;  xstart: SIGNED32; VAR y: ARRAY OF SIGNED16;  ystart: SIGNED32): SIGNED32;
	(*! replace by BLAS1.SDOT*)
	(*=  scalar product <x,y> *)
	(*= The arrays x and y aren't changed*)
	VAR prod: SIGNED32;
BEGIN
	ASSERT(xstart >= 0, 100); ASSERT(ystart >= 0, 101); ASSERT(len >= 0, 102);
	ASSERT(xstart + len <= LEN(x), 103); ASSERT(ystart + len <= LEN(y), 104);
	prod := 0;
	WHILE len > 0 DO prod := prod + x[xstart] * y[ystart];  INC(xstart); INC(ystart); DEC(len) END;
	RETURN prod;
END SkalProd;

PROCEDURE SkalProdPat* (count: index;  VAR x: ARRAY OF int;  xstart, xstep: index;  VAR y: ARRAY OF int;  ystart, ystep: index): index;
	(*! replace by BLAS1.SDOT*)
	(*=  scalar product <x,y> *)
	(*= The arrays x and y aren't changed*)

VAR
	prod: index;

BEGIN
	ASSERT(xstart >= 0, 100);  ASSERT(ystart >= 0, 101);  ASSERT(count >= 0, 102);
	ASSERT(xstep > 0, 103);  ASSERT(ystep > 0, 104);
	ASSERT(xstart + (count - 1) * xstep + 1 <= LEN(x), 105);
	ASSERT(ystart + (count - 1) * ystep + 1 <= LEN(y), 106);
	prod := 0;
	WHILE count > 0 DO
		prod := prod + x[xstart] * y[ystart];
		INC(xstart, xstep);
		INC(ystart, ystep);
		DEC(count)
	END;  (* WHILE *)
	RETURN prod
END SkalProdPat;

PROCEDURE Norm2Sq* (len: SIGNED32;  VAR x: ARRAY OF SIGNED16;  xstart: SIGNED32): SIGNED32;
	(*! replace by BLAS1.SNORM2*)
	(*= Square of L2-Norm of x *)
	(*= The arrays x isn't changed*)
	VAR prod: SIGNED32;
BEGIN
	ASSERT(xstart >= 0, 100); ASSERT(len >= 0, 101);
	ASSERT(xstart + len <= LEN(x), 102);
	prod := 0;
	WHILE len > 0 DO prod := prod + x[xstart] * x[xstart];  INC(xstart); DEC(len) END;
	RETURN prod;
END Norm2Sq;

PROCEDURE Norm2SqPat* (count: index;  VAR x: ARRAY OF int;  xstart, xstep: index): index;
	(*! replace by BLAS1.SNORM2*)
	(*= Square of L2-Norm of x *)
	(*= The arrays x isn't changed*)

VAR
	prod: index;

BEGIN
	ASSERT(xstart >= 0, 100);  ASSERT(count >= 0, 101);  ASSERT(xstep > 0, 103);
	ASSERT(xstart + (count - 1) * xstep + 1 <= LEN(x), 102);
	prod := 0;
	WHILE count > 0 DO prod := prod + x[xstart] * x[xstart];  INC(xstart, xstep);  DEC(count) END;
	RETURN prod
END Norm2SqPat;

PROCEDURE Dist2Sq* (len: SIGNED32;  VAR x: ARRAY OF SIGNED16;  xstart: SIGNED32; VAR y: ARRAY OF SIGNED16;  ystart: SIGNED32): SIGNED32;
	(*! replace by BLAS1.SNORM2 modified*)
	(*= Square of L2-Norm of x-y *)
	(*= The arrays x and y aren't changed*)
	VAR prod: SIGNED32; delta: SIGNED32;
BEGIN
	ASSERT(xstart >= 0, 100); ASSERT(ystart >= 0, 101); ASSERT(len >= 0, 102);
	ASSERT(xstart + len <= LEN(x), 103); ASSERT(ystart + len <= LEN(y), 104);
	prod := 0;
	WHILE len > 0 DO delta := x[xstart] - y[ystart];
	prod := prod + delta * delta;  INC(xstart); INC(ystart); DEC(len) END;
	RETURN prod;
END Dist2Sq;

PROCEDURE Dist2SqPat* (count: index;  VAR x: ARRAY OF int;  xstart, xstep: index;  VAR y: ARRAY OF int;  ystart, ystep: index): index;
	(*! replace by BLAS1.SNORM2 modified*)
	(*= Square of L2-Norm of x-y *)
	(*= The arrays x and y aren't changed*)

VAR
	delta, prod: index;

BEGIN
	ASSERT(xstart >= 0, 100);  ASSERT(ystart >= 0, 101);  ASSERT(count >= 0, 102);
	ASSERT(xstart + (count - 1) * xstep + 1 <= LEN(x), 103);
	ASSERT(ystart + (count - 1) * ystep + 1 <= LEN(y), 104);
	ASSERT(xstep > 0, 105);  ASSERT(ystep > 0, 106);
	prod := 0;
	WHILE count > 0 DO
		delta := x[xstart] - y[ystart];
		prod := prod + delta * delta;
		INC(xstart, xstep);
		INC(ystart, ystep);
		DEC(count)
	END;  (* WHILE *)
	RETURN prod
END Dist2SqPat;

PROCEDURE Norm1* (len: index;  VAR (*IN*)x: ARRAY OF int;  xstart: index): index;
	(*= L1-Norm of x *)

VAR
	prod, top: index;

BEGIN
	ASSERT(xstart >= 0, 100);  ASSERT(len >= 0, 101);
	top := xstart + len;
	ASSERT(top <= LEN(x), 102);
	prod := 0;
	WHILE top > xstart DO prod := prod + ABS(x[xstart]);  INC(xstart) END;
	RETURN prod
END Norm1;

PROCEDURE Norm1Pat* (count: index;  VAR (*IN*)x: ARRAY OF int;  xstart, xstep: index): index;
	(*= L1-Norm of x *)

VAR
	prod, top: index;

BEGIN
	ASSERT(xstart >= 0, 100);  ASSERT(count >= 0, 101);  ASSERT(xstep > 0, 102);
	top := xstart + (count - 1) * xstep + 1;
	ASSERT(top <= LEN(x), 103);
	prod := 0;
	WHILE top > xstart DO prod := prod + ABS(x[xstart]);  INC(xstart, xstep) END;
	RETURN prod
END Norm1Pat;

PROCEDURE Dist1* (len: index;  VAR (*IN*)x: ARRAY OF int;  xstart: index;  VAR (*IN*)y: ARRAY OF int;  ystart: index): index;
	(*= L1-Norm of x-y *)

VAR
	dist, top: index;

BEGIN
	ASSERT(xstart >= 0, 100);  ASSERT(ystart >= 0, 101);  ASSERT(len >= 0, 102);
	top := xstart + len;
	ASSERT(top <= LEN(x), 103);  ASSERT(ystart + len <= LEN(y), 104);
	dist := 0;
	WHILE top > xstart DO dist := dist + ABS(x[xstart] - y[ystart]);  INC(xstart);  INC(ystart) END;
	RETURN dist
END Dist1;

PROCEDURE Dist1Pat* (count: index;  VAR (*IN*)x: ARRAY OF int;  xstart, xstep: index;  VAR (*IN*)y: ARRAY OF int;  ystart, ystep: index): index;
	(*= L1-Norm of x-y *)
	(* cw 2.9.98 *)

VAR
	dist, top: index;

BEGIN
	ASSERT(xstart >= 0, 100);  ASSERT(ystart >= 0, 101);  ASSERT(count >= 0, 102);
	ASSERT(xstep > 0, 103);  ASSERT(ystep > 0, 104);
	top := xstart + (count - 1) * xstep + 1;
	ASSERT(top <= LEN(x), 105);  ASSERT(ystart + (count - 1) * ystep + 1 <= LEN(y), 104);
	dist := 0;
	WHILE top > xstart DO dist := dist + ABS(x[xstart] - y[ystart]);  INC(xstart, xstep);  INC(ystart, ystep) END;
	RETURN dist
END Dist1Pat;

PROCEDURE NormSup* (len: index;  VAR (*IN*)x: ARRAY OF int;  xstart: index;  VAR mindist: int): int;
	(*! Find out, if ASSERT- trap codes may be changed (102 -> 101; 103 -> 102)*)
	(*= supNorm of x; min absolute dist is reported as additional result *)

VAR
	dist, maxdist: int;
	top: index;

BEGIN
	ASSERT(xstart >= 0, 100);  ASSERT(len >= 0, 102);
	top := xstart + len;
	ASSERT(top <= LEN(x), 103);
	maxdist := 0;  mindist := MAX(int);
	WHILE top > xstart DO
		dist := ABS(x[xstart]);
		IF dist < mindist THEN mindist := dist END;
		IF dist > maxdist THEN maxdist := dist END;
		INC(xstart)
	END;  (*WHILE*)
	RETURN maxdist
END NormSup;

PROCEDURE NormSupPat* (count: index;  VAR (*IN*)x: ARRAY OF int;  xstart, xstep: index;  VAR mindist: int): int;
	(*= supNorm of x; min absolute dist is reported as additional result *)
	(* cw 2.9.98 *)

VAR
	dist, maxdist: int;
	top: index;

BEGIN
	ASSERT(xstart >= 0, 100); 	ASSERT(count >= 0, 101); 	ASSERT(xstep > 0, 102);
	top := xstart + (count - 1) * xstep + 1;
	ASSERT(top <= LEN(x), 103);
	maxdist := 0;  mindist := MAX(int);
	WHILE top > xstart DO
		dist := ABS(x[xstart]);
		IF dist < mindist THEN mindist := dist END;
		IF dist > maxdist THEN maxdist := dist END;
		INC(xstart, xstep)
	END;  (*WHILE*)
	RETURN maxdist
END NormSupPat;

PROCEDURE DistSup* (len: index;  VAR (*IN*)x: ARRAY OF int;  xstart: index;  VAR (*IN*)y: ARRAY OF int;  ystart: index;  VAR mindist: index): index;
	(*= supNorm of x-y; min absolute dist is reported as additional result *)

VAR
	dist, maxdist, top: index;

BEGIN
	ASSERT(xstart >= 0, 100);  ASSERT(ystart >= 0, 101);  ASSERT(len >= 0, 102);
	top := xstart + len;
	ASSERT(top <= LEN(x), 103);  ASSERT(ystart + len <= LEN(y), 104);
	maxdist := 0;  mindist := MAX(index);
	WHILE top > xstart  DO
		dist := ABS(x[xstart] - y[ystart]);
		IF dist < mindist THEN mindist := dist END;
		IF dist > maxdist THEN maxdist := dist END;
		INC(xstart);  INC(ystart)
	END;  (*WHILE*)
	RETURN maxdist
END DistSup;

PROCEDURE DistSupPat* (count: index;  VAR (*IN*)x: ARRAY OF int;  xstart, xstep: index;  VAR (*IN*)y: ARRAY OF int;  ystart, ystep: index;  VAR mindist: index): index;
	(*= supNorm of x-y; min absolute dist is reported as additional result *)
	(* cw 2.9.98 *)

VAR
	dist, maxdist, top: index;

BEGIN
	ASSERT(xstart >= 0, 100);  ASSERT(ystart >= 0, 101);  ASSERT(count >= 0, 102);
	ASSERT(xstep > 0, 103);  ASSERT(ystep > 0, 104);
	top := xstart + (count - 1) * xstep + 1;
	ASSERT(top <= LEN(x), 105);  ASSERT(ystart + (count - 1) * ystep + 1 <= LEN(y), 104);
	maxdist := 0;  mindist := MAX(index);
	WHILE top > xstart DO
		dist := ABS(x[xstart] - y[ystart]);
		IF dist < mindist THEN mindist := dist END;
		IF dist > maxdist THEN maxdist := dist END;
		INC(xstart, xstep);  INC(ystart, ystep)
	END;  (*WHILE*)
	RETURN maxdist
END DistSupPat;

PROCEDURE Short* (len: index;  VAR x: ARRAY OF int;  start: index;  VAR result: ARRAY OF SIGNED8);
	(*=  result[ ]:=SHORT(x[ ]) *)
	VAR end: index;
BEGIN
	ASSERT(start >= 0, 100); ASSERT(len >= 0, 101);
	IF len = 0 THEN RETURN END;
	end := start + len;
	WHILE start < end DO result[start] := SHORT(x[start]);  INC(start) END
END Short;

PROCEDURE Long* (len: index;  VAR x: ARRAY OF SIGNED8;  start: index;  VAR result: ARRAY OF int);
	(*=  result[ ]:=LONG(x[ ]) *)
	VAR end: index;
BEGIN
	ASSERT(start >= 0, 100); ASSERT(len >= 0, 101);
	IF len = 0 THEN RETURN END;
	end := start + len;
	WHILE start < end DO result[start] := x[start];  INC(start) END
END Long;

PROCEDURE Convolution* (len, start: index;  VAR src, dest, kernel: ARRAY OF SIGNED16;  kernelw: index);
	(* RAW convolution: 0 based Kernel,  blurred upper bound in dest  *)
	VAR i, j: index;  temp: SIGNED16;
BEGIN
	FOR i := 0 TO len + kernelw - 1 DO dest[i] := 0 END;
	FOR i := start TO start + len - 1 DO (* src *)
		FOR j := 0 TO kernelw - 1 DO temp := dest[i + j];  temp := temp + src[i] * kernel[j];  dest[i + j] :=  temp;
		END;
	END;
END Convolution;


END vyInteger.