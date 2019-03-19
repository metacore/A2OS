MODULE vyFiles IN Oberon; 	(** gs  **)
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


IMPORT Files;
CONST idtag = 0;
	(** Read **)

	PROCEDURE ReadArrayDesc* (VAR R: Files.Rider;  VAR type, version, dims: LONGINT;
VAR (*OUT*)len: POINTER TO ARRAY OF LONGINT);
	(* type and version are free for user semantics *)
	VAR mytag, i: LONGINT;
BEGIN
	Files.ReadLInt(R, mytag);  (*! check version *)
	Files.ReadLInt(R, type); 	Files.ReadLInt(R, version);  Files.ReadLInt(R, dims);
	NEW(len, dims); FOR i := 0 TO dims - 1 DO Files.ReadLInt(R, len[i]) END
END ReadArrayDesc;

PROCEDURE ReadInt* (VAR R: Files.Rider;  VAR (*OUT*)x: ARRAY OF INTEGER;  start, count: LONGINT);
	VAR i: LONGINT;
BEGIN	FOR i := start TO count DO Files.ReadInt(R, x[i]) END
END ReadInt;

PROCEDURE ReadLInt* (VAR R: Files.Rider;  VAR (*OUT*)x: ARRAY OF LONGINT;  start, count: LONGINT);
	VAR i: LONGINT;
BEGIN	FOR i := start TO count DO Files.ReadLInt(R, x[i]) END
END ReadLInt;

PROCEDURE ReadSet* (VAR R: Files.Rider;  VAR (*OUT*)x: ARRAY OF SET;  start, count: LONGINT);
	VAR i: LONGINT;
BEGIN	FOR i := start TO count DO Files.ReadSet(R, x[i]) END
END ReadSet;

PROCEDURE ReadBool* (VAR R: Files.Rider;  VAR (*OUT*)x: ARRAY OF BOOLEAN;  start, count: LONGINT);
	VAR i: LONGINT;
BEGIN	FOR i := start TO count DO Files.ReadBool(R, x[i]) END
END ReadBool;

PROCEDURE ReadReal* (VAR R: Files.Rider;  VAR (*OUT*)x: ARRAY OF REAL;  start, count: LONGINT);
	VAR i: LONGINT;
BEGIN	FOR i := start TO count DO Files.ReadReal(R, x[i]) END
END ReadReal;

PROCEDURE ReadLReal* (VAR R: Files.Rider;  VAR (*OUT*)x: ARRAY OF LONGREAL;  start, count: LONGINT);
	VAR i: LONGINT;
BEGIN	FOR i := start TO count DO Files.ReadLReal(R, x[i]) END
END ReadLReal;

PROCEDURE ReadString* (VAR R: Files.Rider;  VAR (*OUT*)x: ARRAY OF ARRAY OF CHAR;  start, count: LONGINT);
	VAR i: LONGINT;
BEGIN	FOR i := start TO count DO Files.ReadString(R, x[i]) END
END ReadString;

PROCEDURE ReadNum* (VAR R: Files.Rider;  VAR (*OUT*)x: ARRAY OF LONGINT;  start, count: LONGINT);
	VAR i: LONGINT;
BEGIN	FOR i := start TO count DO Files.ReadNum(R, x[i]) END
END ReadNum;

(** Write **)
PROCEDURE WriteArrayDesc* (VAR R: Files.Rider;  VAR type, version, dims: LONGINT;
VAR (*OUT*)len: POINTER TO ARRAY OF LONGINT);
	(* type and version are free for user semantics *)
	VAR i: LONGINT;
BEGIN
	Files.WriteLInt(R, idtag);  (*! check version *)
	Files.WriteLInt(R, type); 	Files.WriteLInt(R, version);  Files.WriteLInt(R, dims);
	NEW(len, dims); FOR i := 0 TO dims - 1 DO Files.WriteLInt(R, len[i]) END
END WriteArrayDesc;

PROCEDURE WriteInt* (VAR R: Files.Rider;  VAR (*OUT*)x: ARRAY OF INTEGER;  start, count: LONGINT);
	VAR i: LONGINT;
BEGIN	FOR i := start TO count DO Files.WriteInt(R, x[i]) END
END WriteInt;

PROCEDURE WriteLInt* (VAR R: Files.Rider;  VAR (*OUT*)x: ARRAY OF LONGINT;  start, count: LONGINT);
	VAR i: LONGINT;
BEGIN	FOR i := start TO count DO Files.WriteLInt(R, x[i]) END
END WriteLInt;

PROCEDURE WriteSet* (VAR R: Files.Rider;  VAR (*OUT*)x: ARRAY OF SET;  start, count: LONGINT);
	VAR i: LONGINT;
BEGIN	FOR i := start TO count DO Files.WriteSet(R, x[i]) END
END WriteSet;

PROCEDURE WriteBool* (VAR R: Files.Rider;  VAR (*OUT*)x: ARRAY OF BOOLEAN;  start, count: LONGINT);
	VAR i: LONGINT;
BEGIN	FOR i := start TO count DO Files.WriteBool(R, x[i]) END
END WriteBool;

PROCEDURE WriteReal* (VAR R: Files.Rider;  VAR (*OUT*)x: ARRAY OF REAL;  start, count: LONGINT);
	VAR i: LONGINT;
BEGIN	FOR i := start TO count DO Files.WriteReal(R, x[i]) END
END WriteReal;

PROCEDURE WriteLReal* (VAR R: Files.Rider;  VAR (*OUT*)x: ARRAY OF LONGREAL;  start, count: LONGINT);
	VAR i: LONGINT;
BEGIN	FOR i := start TO count DO Files.WriteLReal(R, x[i]) END
END WriteLReal;

PROCEDURE WriteString* (VAR R: Files.Rider;  VAR (*OUT*)x: ARRAY OF ARRAY OF CHAR;  start, count: LONGINT);
	VAR i: LONGINT;
BEGIN	FOR i := start TO count DO Files.WriteString(R, x[i]) END
END WriteString;

PROCEDURE WriteNum* (VAR R: Files.Rider;  VAR (*OUT*)x: ARRAY OF LONGINT;  start, count: LONGINT);
	VAR i: LONGINT;
BEGIN	FOR i := start TO count DO Files.WriteNum(R, x[i]) END
END WriteNum;

END vyFiles.
