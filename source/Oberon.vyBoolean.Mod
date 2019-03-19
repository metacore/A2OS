MODULE vyBoolean IN Oberon;
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



(** boolean  arrays *)

IMPORT
	Files, vyBase;

CONST idversion* = ' v0r0a2';
	(* len parameters are passed as explicit parameters, to allow for incomplete buffers *)
	(*! This file should be optimized for any specific hardware *)


	(*= storage formats *)
	fmtany* = 0;   (*= never in stored format. fmtany in storage signals termination*)
	fmtend* = 0;  (*= termination*)
	fmtplain* = 1;
	fmtpacked* = 2;


	(** File storage *)

PROCEDURE Write* (VAR R: Files.Rider;  count: LONGINT;  VAR x: ARRAY OF BOOLEAN;  start: LONGINT);

BEGIN
	ASSERT(start >= 0, 100);  ASSERT(count >= 0, 101);
	ASSERT(start <= LEN(x) - count, 102);
	count := start + count;
	WHILE start < count DO Files.WriteBool(R, x[start]);  INC(start) END
END Write;

PROCEDURE Read* (VAR R: Files.Rider;  count: LONGINT;  VAR x: ARRAY OF BOOLEAN;  start: LONGINT);

BEGIN
	ASSERT(start >= 0, 100);  ASSERT(count >= 0, 101);
	ASSERT(start <= LEN(x) - count, 102);
	count := start + count;
	WHILE start < count DO Files.ReadBool(R, x[start]);  INC(start) END
END Read;

(*= Formatted write, eg. packed, sparse... *)
(*! add implementations *)
(*= file is a series of packages of structure
<formatkey>: LONGINT
0: terminate. No further information in this record
1: plain
2: repeat packing
<start><count> : LONGINT
<privat packing data>
*)
(*= packed format.
formatkey=1
count: total number of entries
<default>: real. Gaps between packages are filled with this value, eg. 0 or NaN
[<packcount>   <packstart>	<packval> ] terminates on packcount 0
*)
(*! check add implementations *)

PROCEDURE WriteFmt* (prefform: LONGINT;  VAR R: Files.Rider;  count: LONGINT;  VAR x: ARRAY OF BOOLEAN;  start: LONGINT);

	(*= prefform is the preferred storage format, but the internal algorithm may choose a different one *)

BEGIN
	(*! add implementations for non plain. form ignored so far *)
	Files.WriteLInt(R, fmtplain);
	Files.WriteLInt(R, start);
	Files.WriteLInt(R, count);
	Write(R, count, x, start);
	Files.WriteLInt(R, fmtend)
END WriteFmt;

PROCEDURE ReadFmt* (VAR form: LONGINT;  VAR R: Files.Rider;  count: LONGINT;  VAR x: ARRAY OF BOOLEAN;  start: LONGINT);

	VAR stop: LONGINT;

BEGIN
	(*! add implementations for non plain. form ignored so far *)
	Files.ReadLInt(R, form);
	Files.ReadLInt(R, start);
	Files.ReadLInt(R, count);
	Read(R, count, x, start);
	Files.ReadLInt(R, stop);
	ASSERT(stop = fmtend, 100)
END ReadFmt;

(** General adminstration **)

PROCEDURE Fill* (len: LONGINT;  VAR x: ARRAY OF BOOLEAN;  start: LONGINT; val: BOOLEAN);
BEGIN
	ASSERT(start >= 0, 100); ASSERT(len >= 0, 101);
	ASSERT(start <= LEN(x) - len, 102);
	len := start + len; (* used as top *)
	WHILE start < len DO x[start] := val;  INC(start) END
END Fill;

PROCEDURE FillPat* (count: LONGINT; VAR x: ARRAY OF BOOLEAN;  start, step: LONGINT; 	val: BOOLEAN);
BEGIN ASSERT(start >= 0, 100); ASSERT(count >= 0, 101);
	ASSERT(count * step <= LEN(x) - start, 102); 	ASSERT(step > 0, 103);
	count := start + count * step;  (* used as top *)
	WHILE start < count DO x[start] := val;  INC(start, step) END;
END FillPat;

PROCEDURE Copy* (len: LONGINT;
VAR src: ARRAY OF BOOLEAN; srcstart: LONGINT;
VAR dest: ARRAY OF BOOLEAN; deststart: LONGINT );
BEGIN
	ASSERT(len > 0, 100);
	ASSERT(srcstart <= LEN(src) - len, 101);
	ASSERT(deststart <= LEN(dest) - len, 102);
	vyBase.COPYB(src, srcstart, len, dest, deststart);
END Copy;

PROCEDURE CopyPat* (count: LONGINT; VAR src: ARRAY OF BOOLEAN; start, step: LONGINT; VAR dest: ARRAY OF BOOLEAN;  deststart, deststep: LONGINT);
	VAR i, j, top: LONGINT;
BEGIN
	ASSERT((start >= 0) & (deststart >= 0), 100); ASSERT(count >= 0, 101);
	ASSERT((step > 0) & (deststep > 0), 103);
	ASSERT((start + count * step <= LEN(src))
	 & (deststart + count * deststep <= LEN(dest)), 102);
	i := start; j := deststart; top := start + count * step;
	WHILE i < top DO dest[i] := src[i]; INC(i, step); INC(j, deststep) END;
END CopyPat;

PROCEDURE Count* (len: LONGINT;  VAR x: ARRAY OF BOOLEAN): LONGINT;
	VAR i: LONGINT;
BEGIN
	i := 0;
	WHILE i < len DO IF x[i] THEN INC(i) END;  END;
	RETURN i;
END Count;

(** Basic operators **)

PROCEDURE And* (VAR x, y: ARRAY OF BOOLEAN; VAR z: ARRAY OF BOOLEAN;  len: LONGINT); (*vs 0.1d0 gs *)
	VAR i: LONGINT;
BEGIN
	i := 0;  WHILE i < len DO z[i] := x[i] & y[i]; 	INC(i) END;
END And;

PROCEDURE Or* (VAR x, y: ARRAY OF BOOLEAN; VAR z: ARRAY OF BOOLEAN;  len: LONGINT); (*vs 0.1d0 gs *)
VAR i: LONGINT; BEGIN
	i := 0;  WHILE i < len DO z[i] := x[i] OR y[i]; 	INC(i) END;
END Or;

PROCEDURE XOr* (VAR x, y: ARRAY OF BOOLEAN; VAR z: ARRAY OF BOOLEAN;  len: LONGINT); (*vs 0.1d0 gs *)
	VAR i: LONGINT;
BEGIN
	i := 0;  WHILE i < len DO z[i] := (x[i] & ~y[i]) OR (~x[i] & y[i]); INC(i) END;
END XOr;

PROCEDURE Not* (VAR x: ARRAY OF BOOLEAN; VAR z: ARRAY OF BOOLEAN;  len: LONGINT); (*vs 0.1d0 gs *)
	VAR i: LONGINT;
BEGIN
	i := 0;  WHILE i < len DO z[i] := ~x[i]; 	INC(i) END;
END Not;

(** 2D matrix support **)

PROCEDURE Get2d* (VAR x: ARRAY OF BOOLEAN;  rows, row, column: LONGINT): BOOLEAN;
BEGIN
	ASSERT(rows >= row);
	RETURN x[row * rows + column]
END Get2d;

PROCEDURE Set2d* (VAR x: ARRAY OF BOOLEAN;  rows, row, column: LONGINT; val: BOOLEAN);
BEGIN
	ASSERT(rows >= row);
	x[row * rows + column] := val
END Set2d;

PROCEDURE Get2dM* (VAR x: ARRAY OF BOOLEAN;
rowoffset, coloffset, nrrows, nrcolumns: LONGINT; VAR dest: ARRAY OF ARRAY OF BOOLEAN);  (*vs 0.1d0 gs *)
	(*= copy a 1-dim array as nrrows,nrcolumns submatrix into dest *)
	VAR i, j, k: LONGINT;
BEGIN	k := 0;
	FOR i := rowoffset TO rowoffset + nrrows DO
		FOR j := coloffset TO coloffset + nrcolumns DO dest[i, j] := x[k];  INC(k);
		END;
	END;
END Get2dM;

PROCEDURE Set2dM* (VAR x: ARRAY OF BOOLEAN;
rowoffset, coloffset, nrrows, nrcolumns: LONGINT; VAR src: ARRAY OF ARRAY OF BOOLEAN);  (*vs 0.1d0 gs *)
	(*= set a 1-dim array as nrrows,nrcolumns submatrix from src *)
	VAR i, j, k: LONGINT;
BEGIN 	k := 0;
	FOR i := rowoffset TO rowoffset + nrrows DO
		FOR j := coloffset TO coloffset + nrcolumns DO x[k] := src[i, j];  INC(k);
		END;
	END;
END Set2dM;

(** 2D support - FORTRAN-like **)
PROCEDURE Get2dF* (VAR x: ARRAY OF BOOLEAN;  columns, row, column: LONGINT): BOOLEAN;
BEGIN
	ASSERT(columns >= column);
	RETURN x[row + column * columns]
END Get2dF;

PROCEDURE Set2dF* (VAR x: ARRAY OF BOOLEAN;  columns, row, column: LONGINT; val: BOOLEAN);
BEGIN
	ASSERT(columns >= column);
	x[row + column * columns] := val
END Set2dF;

END vyBoolean.