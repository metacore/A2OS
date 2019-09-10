MODULE antsBinaryEmpiricD IN Oberon;   	(** JM  **)
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



IMPORT vyBase, antsArrayObjects, antsEmpiricD, antsCommands, vyCG := vyName, Objects, aM := antsMessages;
CONST
	StateSpaceCard = 2;
	Neighbours = 4;
	MaxSum = (StateSpaceCard*Neighbours + 1);
TYPE
	Index = SIGNED32;
	States = SIGNED32;
	Sums = ARRAY  (MaxSum + 1) OF States;
	StatesAndSums = ARRAY StateSpaceCard OF Sums;

	EmpiricalDistribution* = POINTER TO EDDesc;    (* empirical Distribution of a binary state space model *)
	EDDesc = RECORD (antsEmpiricD.EDDesc)
		v: Sums;     					(* v[k] = n/o points having k-4 = sum over neighbourvalues *)
		xv: StatesAndSums;    	(* xv[j,k] = n/o points with value j having k-4 = sum over neighbourvalues *)
	END;

	tParameter* = POINTER TO tParameterDesc;
	tParameterDesc* = RECORD (antsEmpiricD.tParameterDesc)
	END;

	tEDGenerator* = POINTER TO tEDGeneratorDesc;
	tEDGeneratorDesc = RECORD (vyBase.ObjDesc)
		par: tParameter;
		gen: PROCEDURE (g: tEDGenerator);
	END;


PROCEDURE InitED (E: EmpiricalDistribution);
	VAR i, j: SIGNED32;
BEGIN
	FOR i := 0 TO MaxSum DO
		E.v[i] := 0;
		FOR j := 0 TO StateSpaceCard - 1 DO
			E.xv[j, i] := 0;
		END;
	END;
END InitED;

PROCEDURE R* (E: EmpiricalDistribution;    x, v: Index): States;
BEGIN
	RETURN E.xv[(x + 1) DIV 2, v + 4];
END R;

PROCEDURE M* (E: EmpiricalDistribution;    v: Index): States;
BEGIN
	RETURN E.v[v + 4];
END M;

PROCEDURE F* (E: EmpiricalDistribution;    x, v: Index): FLOAT64;
	VAR nv: States;
BEGIN
	nv := M(E, v);
	IF nv # 0 THEN RETURN R(E, x, v) / nv ELSE RETURN 0 END;
END F;


PROCEDURE EmpiricalDistribute (VAR E: EmpiricalDistribution;    A: antsArrayObjects.tINTEGERArray;    Sx, Sy, Sw, Sh: SIGNED32);
	VAR x, y: SIGNED32 ;    xt, vt: Index;
BEGIN
	IF E = NIL THEN NEW(E) END;
	InitED(E);
	FOR y := Sy TO Sy + Sh DO
		FOR x := Sx TO Sx + Sw DO
			vt := A[y - 1, x] + A[y + 1, x] + A[y, x - 1] + A[y, x + 1] + 4;
			xt := (A[y, x] + 1) DIV 2;
			INC(E.xv[xt, vt]);    INC(E.v[vt]);
		END;
	END;
END EmpiricalDistribute;

PROCEDURE EmpiricalDistributeC (Eo, Ee: EmpiricalDistribution;    A: antsArrayObjects.tINTEGERArray;    Sx, Sy, Sw, Sh: SIGNED32);
	VAR x, y: SIGNED32 ;    xt, vt: Index;
BEGIN
	IF Eo = NIL THEN NEW(Eo) END;
	IF Ee = NIL THEN NEW(Ee) END;
	InitED(Eo);   InitED(Ee);
	FOR y := Sy TO Sy + Sh DO
		FOR x := Sx TO Sx + Sw DO
			vt := A[y - 1, x] + A[y + 1, x] + A[y, x - 1] + A[y, x + 1] + 4;
			xt := (A[y, x] + 1) DIV 2;
			IF ODD(x + y) THEN
				INC(Eo.xv[xt, vt]);    INC(Eo.v[vt]);
			ELSE
				INC(Ee.xv[xt, vt]);    INC(Ee.v[vt]);
			END;
		END;
	END;
END EmpiricalDistributeC;

PROCEDURE GenerateED (g: tEDGenerator);
	VAR par: tParameter;    ed: EmpiricalDistribution;
BEGIN
	par := g.par;
	ed := par.ED(EmpiricalDistribution);
	EmpiricalDistribute (ed, par.A.A, 1, 1, par.A.w - 3, par.A.h - 3 );
	EmpiricalDistributeC(par.CEDo(EmpiricalDistribution), par.CEDe(EmpiricalDistribution), par.A.A, 1, 1, par.A.w - 3, par.A.h - 3);
	par.x := 1;   par.y := 1;   par.w := par.A.w - 2;   par.h := par.A.h - 2;
END GenerateED;


PROCEDURE Handler* (obj: Objects.Object;     VAR msg: Objects.ObjMsg);
BEGIN
	WITH obj: tEDGenerator DO
		(*WITH msg:  antsTypes.tNewValMsg DO
		obj.par.A := msg.val(antsArrayObjects.tObject);
		obj.gen(obj);
		IF debug THEN WriteED(obj.par.ED(EmpiricalDistribution)) END;
		ELSE
		END;
		*)
	END;
END Handler;

PROCEDURE Open* (gen: tEDGenerator;   from: vyBase.Object);
	VAR ED: EmpiricalDistribution;
BEGIN
	NEW(gen.par);
	NEW(ED);   gen.par.ED := ED;
	NEW(ED);   gen.par.CEDo := ED;
	NEW(ED);   gen.par.CEDe := ED;
	vyBase.Subscribe(from, gen);
	gen.handle := Handler;
	gen.gen := GenerateED;
END Open;

PROCEDURE New*;
	VAR l: antsCommands.tScanList;     name: vyCG.tNameArray;   obj: vyBase.Object;
	gen: tEDGenerator;
BEGIN
	l := antsCommands.ScanFromPar("name=NAME from=OBJ");
	IF
		antsCommands.ExpectNameFromKeyword(l, "name", name) &
		antsCommands.ExpectObjectFromKeyword(l, "from", obj) THEN
		NEW(gen);   Open(gen, obj);
		vyCG.RegisterNamed(gen, name);
	END;
END New;


BEGIN  aM.launch;
END antsBinaryEmpiricD.
