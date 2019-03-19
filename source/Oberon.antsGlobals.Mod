MODULE antsGlobals IN Oberon;  	(** fof  **)
(* Copyright notice:

This file is part of AntsInFields
Copyright (C) 1997-2002, Felix Friedrich

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
Report any problems as soon as possible to ants@AntsInFields.de
*)





(* exchange point for global variables, still unused *)

IMPORT Objects, antsPortability,aM := antsMessages,vyHostStrings;

TYPE

	Parameters* = POINTER TO ARRAY OF LONGREAL;
	ParameterNames* = POINTER TO ARRAY OF ARRAY 64 OF CHAR;


	Name = ARRAY 256 OF CHAR;

	List = POINTER TO ListDesc;
	ListDesc = RECORD
		object: Objects.Object;
		name: Name;
		prev, next: List
	END;

VAR
	globals, last: List;   current*: Objects.Object;
	globalParameters*: Parameters;
	debug*: BOOLEAN;

PROCEDURE ParameterHandleAttribute*(VAR M: Objects.AttrMsg;  VAR p: Parameters;  VAR pn: ParameterNames): BOOLEAN;
	VAR cur: ARRAY 64 OF CHAR;  i: LONGINT;  len: LONGINT;
BEGIN
	IF p = NIL THEN RETURN FALSE END;
	len := LEN(p);
	IF (pn = NIL) OR (len # LEN(pn)) THEN
		NEW(pn, len);
		FOR i := 0 TO len - 1 DO
			COPY("par[", cur);
			vyHostStrings.AppendInt(i, 1, cur);  vyHostStrings.Append(cur, "]");
			COPY(cur, pn[i])
		END
	END;
	IF M.id = Objects.enum THEN
		FOR i := 0 TO len - 1 DO
			M.Enum(pn[i])
		END;
		RETURN TRUE
	ELSIF M.id = Objects.get THEN
		FOR i := 0 TO len - 1 DO
			IF vyHostStrings.Equal(M.name, pn[i]) THEN
				M.y := p[i];  M.class := Objects.LongReal;  M.res := 0;  RETURN TRUE
			END
		END
	ELSIF M.id = Objects.set THEN
		FOR i := 0 TO len - 1 DO
			IF vyHostStrings.Equal(M.name, pn[i]) THEN
				IF M.class = Objects.LongReal  THEN
					p[i] := M.y;  M.res := 0;  RETURN TRUE
				ELSIF M.class = Objects.Real THEN
					p[i] := M.x  ;  M.res := 0;  RETURN TRUE
				ELSIF M.class = Objects.Int THEN
					p[i] := M.i  ;  M.res := 0;  RETURN TRUE
				END
			END
		END
	END;
	RETURN FALSE
END ParameterHandleAttribute;


PROCEDURE Insert (VAR l: List;   VAR name: ARRAY OF CHAR;   object: Objects.Object);
BEGIN
	IF l = NIL THEN NEW(l);   COPY(name, l.name);   l.object := object;    last := l
	ELSIF l.name > name THEN Insert(l.prev, name, object)
	ELSIF l.name < name THEN Insert(l.next, name, object)
	ELSE  l.object := object;    last := l
	END
END Insert;

PROCEDURE Set* ( object: Objects.Object;   name: ARRAY OF CHAR);
BEGIN
	Insert(globals, name, object)
END Set;

PROCEDURE Remove* (name: ARRAY OF CHAR);
BEGIN
	Insert(globals, name, NIL)
END Remove;

PROCEDURE Get* (name: ARRAY OF CHAR): Objects.Object;
	VAR l: List;
BEGIN
	IF last # NIL THEN IF last.name = name THEN current := last.object;   RETURN last.object END END;
	l := globals;
	WHILE(l # NIL) DO
		IF name < l.name THEN l := l.prev
		ELSIF name > l.name THEN l := l.next
		ELSE current := last.object;   RETURN l.object
		END
	END;
	aM.eSS("Warning: antsGlobals could not find ",name);
	aM.eS("Global Objects:");
	Dump;
	RETURN NIL
END Get;

PROCEDURE GetCur* (name: ARRAY OF CHAR);
BEGIN
	current := Get(name)
END GetCur;


PROCEDURE Init*;   (* removes all global objects *)
BEGIN
	globals := NIL
END Init;

 PROCEDURE DumpOne (VAR l: List);
	VAR t: antsPortability.Type;
BEGIN
	IF l = NIL THEN RETURN END;
	DumpOne(l.prev)  ;
	IF l.object # NIL THEN t := antsPortability.TypesTypeOf(l.object);   aM.SSS(l.name,"::",t.name)
	ELSE aM.SSS(l.name,"::","NIL")
	END;
	DumpOne(l.next)
END DumpOne;



PROCEDURE Dump*;
	VAR l: List;
BEGIN
	l := globals;
	DumpOne(l)
END Dump;

(*
PROCEDURE Test*;
VAR obj: Objects.Object;
BEGIN
Set("test1",NIL);
Set("abc",NIL);
Set("zzz",NIL);
Set("pop",NIL);
Set("zzzz",NIL);
Set("pop",NIL);
NEW(obj);
Set("abc",obj);
Set("aaaa",obj);
Dump;
END Test;
*)


BEGIN
	debug := FALSE;
	aM.launch; Init;

END antsGlobals.
antsGlobals.Test ~
