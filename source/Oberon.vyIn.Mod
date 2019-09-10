MODULE vyIn IN Oberon;
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



(* adapted from In. Copyright (c) ETH Zürich, 1989-95 / mr, nw 22.5.93*)
IMPORT   vyScanners, vyParser;

CONST idversion* = "vyIn v0r0a2";

	VAR Done*: BOOLEAN;
	S: vyScanners.Scanner;
	(*
	PROCEDURE Dump*;
	BEGIN	vyScanners.Dump(w,S)	END Dump;
	*)
PROCEDURE Open*;
	VAR i: SIGNED16;
BEGIN 	vyScanners.NewSScanner(S); 	vyScanners.OpenParScanner(S);
	i := vyScanners.NextToken(S);  Done := TRUE;  (*Dump;*)
END Open;

PROCEDURE Char* (VAR ch: CHAR);
BEGIN	IF Done THEN ch := S.ch;  Done := ~S.eot;  vyScanners.Ch(S) END
END Char;

PROCEDURE LongInt* (VAR i: SIGNED32);
BEGIN	IF Done THEN Done := vyParser.Number(S, i) END
END LongInt;

PROCEDURE Int* (VAR i: SIGNED16);
	VAR l: SIGNED32;
BEGIN	IF Done THEN LongInt(l);  i := SHORT(l) END
END Int;

PROCEDURE Real* (VAR x: FLOAT32);
BEGIN	IF Done THEN Done := vyParser.Real(S, x) END
END Real;

PROCEDURE LongReal* (VAR y: FLOAT64);
	(*! add proper LongReal support *)
	VAR x: FLOAT32;
BEGIN	IF Done THEN Real(x);  y := x END
END LongReal;

PROCEDURE Name* (VAR name: ARRAY OF CHAR);
BEGIN	IF Done THEN Done := vyParser.Name(S, name) END END Name;

PROCEDURE String* (VAR str: ARRAY OF CHAR);
	(*! add proper String support *)
BEGIN	IF Done THEN Name(str) END
END String;

BEGIN Done := FALSE;  (* Texts.Open(w,'vyIn Dump')*)
END vyIn.