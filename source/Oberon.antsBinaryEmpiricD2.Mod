MODULE antsBinaryEmpiricD2 IN Oberon; 	(** JM  **)
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



IMPORT vyBase, antsArrayObjects, antsEmpiricD, Objects, aM := antsMessages ;
CONST
	(* StateSpaceCard = 2;
	Neighbours = 4;
	MaxSum = (StateSpaceCard*Neighbours+1);  *)
	size1 = 256-1;  (* = 2^8 *)
	size2 = 16-1;  (* =  2^4 *)
	(* idee:
	* *				v1 v2
	* + + *		v0 x0 x1 v3
	* + + * 		v7 x2 x3 v4
	* *				 v6 v5
	*)

TYPE
	Index = SIGNED32;
	States = SIGNED32;
	(* Sums = ARRAY  (MaxSum+1) OF States;
	StatesAndSums = ARRAY StateSpaceCard OF Sums; *)

	EmpiricalDistribution* = POINTER TO EDDesc;   (* empirical Distribution of a binary state space model *)
	EDDesc = RECORD (antsEmpiricD.EDDesc)
		Mn: ARRAY size1 + 1 OF SIGNED32;
		Rn: ARRAY  size2 + 1 OF ARRAY size1 + 1 OF SIGNED32
		(*	Fn: ARRAY 4 OF ARRAY 64 OF SIGNED32;*)
	END;

	tParameter* = POINTER TO tParameterDesc;
	tParameterDesc* = RECORD (antsEmpiricD.tParameterDesc)
	END;

	tEDGenerator* = POINTER TO tEDGeneratorDesc;
	tEDGeneratorDesc = RECORD (vyBase.ObjDesc)
		par: tParameter;
		gen: PROCEDURE (g: tEDGenerator);
	END;

	VAR debug: BOOLEAN;

PROCEDURE InitED (E: EmpiricalDistribution);
	VAR i, j: SIGNED32;
BEGIN
	FOR i := 0 TO size1 DO
		E.Mn[i] := 0;
		FOR j := 0 TO size2 DO
			E.Rn[j, i] := 0
			(* E.Fn[i,j] := 0; *)
		END
	END
END InitED;

PROCEDURE R* (E: EmpiricalDistribution;   x, v: Index): States;
BEGIN
	RETURN E.Rn[x, v]
	(* RETURN E.xv[(x+1) DIV 2, v+4];  *)
END R;

PROCEDURE M* (E: EmpiricalDistribution;   v: Index): States;
BEGIN
	RETURN E.Mn[v]
	(*	RETURN E.v[v+4];  *)
END M;

PROCEDURE F* (E: EmpiricalDistribution;   x, v: Index): FLOAT64;
BEGIN
	IF E.Mn[v] = 0 THEN RETURN 0 ELSE RETURN E.Rn[x, v] / E.Mn[v] END
	(* 	nv := M(E,v);
	IF nv # 0 THEN RETURN R(E,x,v) / nv ELSE RETURN 0 END;  *)
END F;


PROCEDURE EmpiricalDistribute (VAR E: EmpiricalDistribution;   A: antsArrayObjects.tINTEGERArray;   Sx, Sy, Sw, Sh: SIGNED32);
	VAR x, y: SIGNED32 ;   xt, vt: Index;
BEGIN
	IF E = NIL THEN NEW(E) END;
	InitED(E);
	FOR y := Sy TO Sy + Sh DO
		FOR x := Sx TO Sx + Sw DO
			vt := 0;  xt := 0;
			IF A[y, x - 1] = 1 THEN INC(vt, 1)  END;
			IF  A[y - 1, x] = 1 THEN INC(vt, 2) END;
			IF A[y - 1, x + 1] = 1 THEN INC(vt, 4) END;
			IF A[y, x + 2] = 1 THEN INC(vt, 8) END;
			IF A[y + 1, x + 2] = 1 THEN INC(vt, 16) END;
			IF A[y + 2, x + 1] = 1 THEN INC(vt, 32) END;
			IF A[y + 2, x] = 1 THEN INC(vt, 64) END;
			IF A[y + 1, x - 1] = 1 THEN INC(vt, 128) END;

			IF A[y, x] = 1 THEN INC(xt, 1) END;
			IF A[y, x + 1] = 1 THEN INC(xt, 2) END;
			IF A[y + 1, x + 1] = 1 THEN INC(xt, 4) END;
			IF A[y + 1, x] = 1 THEN INC(xt, 8) END;

			INC(E.Mn[vt]);   INC(E.Rn[xt, vt])
		END
	END
END EmpiricalDistribute;


PROCEDURE GenerateED (g: tEDGenerator);
	VAR par: tParameter;   ed: EmpiricalDistribution;
BEGIN
	par := g.par;
	ed := par.ED(EmpiricalDistribution);
	EmpiricalDistribute (ed, par.A.A, 1, 1, par.A.w - 4, par.A.h - 4);
	(* EmpiricalDistributeC(par.CEDo(EmpiricalDistribution),par.CEDe(EmpiricalDistribution),
	par.A.A, 1,1,par.A.w-4,par.A.h-4); *)
	par.x := 1;  par.y := 1;  par.w := par.A.w - 4;  par.h := par.A.h - 4
END GenerateED;


PROCEDURE Handler* (obj: Objects.Object;    VAR msg: Objects.ObjMsg);
BEGIN
	WITH obj: tEDGenerator DO
		(*WITH msg:  antsTypes.tNewValMsg DO
		obj.par.A := msg.val(antsArrayObjects.tObject);
		obj.gen(obj);
		IF debug THEN WriteED(obj.par.ED(EmpiricalDistribution)) END;
		ELSE
		END;
		*)
	END
END Handler;

PROCEDURE Open* (gen: tEDGenerator;  from: vyBase.Object);
	VAR ED: EmpiricalDistribution;
BEGIN
	NEW(gen.par);
	NEW(ED);  gen.par.ED := ED;
	NEW(ED);  gen.par.CEDo := ED;
	NEW(ED);  gen.par.CEDe := ED;
	vyBase.Subscribe(from, gen);
	gen.handle := Handler;
	gen.gen := GenerateED
END Open;
PROCEDURE DebugOn*;
BEGIN debug := TRUE
END DebugOn;

PROCEDURE DebugOff*;
BEGIN debug := FALSE END DebugOff;

BEGIN aM.launch; debug := FALSE;
END antsBinaryEmpiricD2.
