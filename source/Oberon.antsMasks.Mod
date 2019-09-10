MODULE antsMasks IN Oberon;   (** fof  **)
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




IMPORT vyBase, antsArrayObjects,aM := antsMessages;

	(* increase shift speed for masks *)

	(* new idea: enum visible areas by SIGNED16 values. *)

CONST MAXSIZE = 256;
TYPE
	Mask* = OBJECT (* POINTER TO MaskDesc;
	MaskDesc* = RECORD (vyBase.ObjDesc) *) (vyBase.Object)
		(* probably not needed:
		matrix = POINTER TO ARRAY OF ARRAY OF SIGNED16;
		*)
		VAR
		enum-: ARRAY MAXSIZE OF ARRAY 2 OF SIGNED16;
		contained: ARRAY MAXSIZE OF BOOLEAN;

		(* that increases computing time, better avoid, ASSERT all numbers contained when checking consistency ! *)
		enumsize-: SIGNED16;
		posy-, posx-: SIGNED16;  (* mask position *)
		on-: antsArrayObjects.tINTEGERObject;
		Ax*, Ay*, Aw*, Ah*: SIGNED32;
		onA: antsArrayObjects.tINTEGERArray;

		(* visible: POINTER TO ARRAY OF ARRAY OF BOOLEAN;
		visx,visy: POINTER TO ARRAY OF SIGNED16; vislen-: SIGNED16;
		A: antsArrayObjects.tArray; wrong idea: Arrays do not belong to masks but masks belong to arrays -> define slot in Array ?
		*)
		(* size: SIGNED16; limit: SIGNED16;  *)
		(* aw,ah,cx,cy: SIGNED16; *)(* array characteristics , not needed*)

PROCEDURE (*m: Mask*) mask* (A: vyBase.Object);
BEGIN
	SELF.on := A(antsArrayObjects.tINTEGERObject);
	SELF.onA := SELF.on.A;
	SELF.Ax := 0;  SELF.Ay := 0;  SELF.Aw := SELF.on.w;  SELF.Ah := SELF.on.h
END mask;

PROCEDURE (*m: Mask*) vals* (VAR val: ARRAY OF SIGNED16;  offset: SIGNED32 );
	VAR i: SIGNED32;
BEGIN
	FOR i := 0 TO SELF.enumsize - 1 DO
		val[offset + i] := SELF.onA[(SELF.enum[i, 0] + SELF.posy) MOD SELF.Ah, (SELF.enum[i, 1] + SELF.posx) MOD SELF.Aw]
	END
END vals;


PROCEDURE (*m: Mask*) vis* (y, x: SIGNED16): BOOLEAN;
	VAR i: SIGNED16;
BEGIN
	FOR i := 0 TO SELF.enumsize - 1 DO
		IF (SELF.contained[i]) & (SELF.enum[i, 0] = y) & (SELF.enum[i, 1] = x) THEN RETURN TRUE END
	END;
	RETURN FALSE
END vis;

(*
PROCEDURE addvis (m: Mask; y,x: SIGNED16);
BEGIN
SELF.visy[SELF.vislen] := y; SELF.visx[SELF.vislen] := x; INC(SELF.vislen);
END addvis;
*)


PROCEDURE (*m: Mask*) add* ( y, x: SIGNED16;  pos: SIGNED16);
BEGIN
	Doadd(SELF, y, x, pos)
END add;

(*
PROCEDURE  (*m: Mask*) val* (VAR y,x: SIGNED16): SIGNED16; (* replace by val procedure in Array ?? *)
BEGIN
HALT (101);
(*
RETURN SELF.A[(SELF.cy+y) MOD SELF.ah,(SELF.cx+x) MOD SELF.aw];
*)
END val;

PROCEDURE  (*m: Mask*) baseNPos* (VAR base,offset: SIGNED32);
VAR i:SIGNED16; size: SIGNED32;
BEGIN
(*
i := 1;  size := 1;
WHILE i<SELF.vislen DO
size := size * base;
(* INC(offset,size*SELF.A[SELF.wrappedvy[i],SELF.wrappedvx[i]]); *)
INC(offset,size*SELF.A[(SELF.cy+SELF.visy[i]) MOD SELF.ah,(SELF.cx+SELF.visx[i]) MOD SELF.aw]);
INC(i);
END;
*)
END baseNPos;


PROCEDURE  (*m: Mask*) setval* (val: SIGNED16;  y,x: SIGNED16);
BEGIN
HALT(102);
(*
ASSERT(SELF.vis(y,x),101);
SELF.A[(SELF.cy+y) MOD SELF.ah,(SELF.cx+x) MOD SELF.aw]:= val;
*)
END setval;

PROCEDURE (*m: Mask*) setvals* (VAR A: ARRAY OF SIGNED16);
VAR i: SIGNED16;
BEGIN
HALT(103);
(*
i := 0; WHILE i < SELF.vislen DO SELF.setval(A[i],SELF.visy[i],SELF.visx[i]);  INC(i); END;
*)
END setvals;


PROCEDURE (*m: Mask*) vals* (VAR A: ARRAY OF SIGNED16);
VAR i: SIGNED32;
BEGIN
i := 0; WHILE i < SELF.vislen DO A[i] := SELF.val(SELF.visy[i],SELF.visx[i]); INC(i); END;
END vals;
*)

PROCEDURE (*m: Mask*) init*;
	VAR i: SIGNED16;
BEGIN
	SELF.enumsize := 0;
	FOR i := 0 TO MAXSIZE - 1 DO
		SELF.contained[i] := FALSE
	END;
	SELF.add(0, 0, 0)
	(*
	IF SELF.visible = NIL THEN NEW(SELF.visible,(2*size+1),(2*size+1)) ELSIF SELF.size = size THEN (* noop *) ELSE HALT(100) END;
	SELF.size := size;
	SELF.limit := 2*SELF.size+1;
	FOR i := 0 TO SELF.limit-1 DO
	FOR j := 0 TO SELF.limit-1 DO
	SELF.visible[i,j] := FALSE
	END;
	END;
	NEW(SELF.visx,(2+size+1)*(2*size+1)); NEW(SELF.visy,(2*size+1)*(2*size+1));
	SELF.vislen := 0;
	SELF.add(0,0);
	*)
END init;
(*
PROCEDURE (*m: Mask*) applyTo* (o: vyBase.Object);
BEGIN
HALT(104);
(*
SELF.A := o(antsArrayObjects.tObject).A;
SELF.aw := SHORT(o(antsArrayObjects.tObject).w);
SELF.ah := SHORT(o(antsArrayObjects.tObject).h);
*)
END applyTo;
*)
PROCEDURE (*m: Mask*) moveTo* (VAR y, x: SIGNED16);
BEGIN	SELF.posy := y;  SELF.posx := x
END moveTo;

PROCEDURE (*m: Mask*) valsAt* (VAR y, x: SIGNED16;  VAR val: ARRAY OF SIGNED16;  offset: SIGNED32 );
	VAR i: SIGNED32;
BEGIN
	FOR i := 0 TO SELF.enumsize - 1 DO
		val[offset + i] := SELF.onA[(SELF.enum[i, 0] + y) MOD SELF.Ah, (SELF.enum[i, 1] + x) MOD SELF.Aw]
	END
END valsAt;
	END Mask;

PROCEDURE Doadd (m: Mask;  y, x: SIGNED16;  pos: SIGNED16);
BEGIN
	IF m.contained[pos] THEN HALT(101)
	ELSIF m.vis(y, x) THEN HALT(102)
	ELSE
		INC(m.enumsize);  ASSERT(pos < m.enumsize);
		m.contained[pos] := TRUE;
		m.enum[pos, 0] := y;  m.enum[pos, 1] := x
	END
	(*
	IF ~m.visible[y+m.size,x+m.size] THEN
	m.visible[y+m.size,x+m.size] := TRUE;
	addvis(m,y,x);
	END;
	*)
END Doadd;



BEGIN
	aM.launch;
END antsMasks.

antsMasks.Test ~
