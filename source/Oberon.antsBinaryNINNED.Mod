MODULE antsBinaryNINNED IN Oberon; 	(** JM  **)
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
TYPE
	Index = SIGNED32;

	NINNED* = ARRAY 2 OF ARRAY 16 OF SIGNED32;   (*= non isotropic nearest neighbour empirical distribution *)
	NINSSProb* = ARRAY 16 OF FLOAT64;  (*= probability vector for non isotropic nearest neighbour structures *)

	EmpiricalDistribution* = POINTER TO EDDesc;   (* empirical Distribution of a binary state space model *)
	EDDesc = RECORD (antsEmpiricD.EDDesc)
		val: NINNED
	END;

	tParameter* = POINTER TO tParameterDesc;
	tParameterDesc* = RECORD (antsEmpiricD.tParameterDesc)
	END;

	tEDGenerator* = POINTER TO tEDGeneratorDesc;
	tEDGeneratorDesc = RECORD (vyBase.ObjDesc)
		par: tParameter;
		gen: PROCEDURE (g: tEDGenerator);
	END;

	VAR   lastprob*: NINSSProb;  black*: FLOAT64;

PROCEDURE Prob* (E: EmpiricalDistribution;  conf: SIGNED32): FLOAT64;
	VAR s: SIGNED32;
BEGIN
	s := E.val[0, conf] + E.val[1, conf];
	IF s = 0 THEN RETURN - 1 ELSE
		RETURN E.val[1, conf] / s
	END
END Prob;

PROCEDURE ProbA* (E: EmpiricalDistribution;  VAR a: NINSSProb);
	VAR i: SIGNED32;  b, w: SIGNED32;
BEGIN b := 0;  w := 0;
	FOR i := 0 TO 15 DO
		a[i] := Prob(E, i);
		w := w + E.val[0, i];  b := b + E.val[1, i]
	END;
	black := b / (b + w)
END ProbA;


PROCEDURE InitED (E: EmpiricalDistribution);
	VAR i: SIGNED32;
BEGIN
	FOR i := 0 TO 15 DO
		E.val[0, i] := 0;
		E.val[1, i] := 0
	END
END InitED;


PROCEDURE EmpiricalDistribute (VAR E: EmpiricalDistribution;   A: antsArrayObjects.tINTEGERArray;   Sx, Sy, Sw, Sh: SIGNED32);
	VAR x, y: SIGNED32 ;   xt: Index;    conf: SIGNED32;
BEGIN
	IF E = NIL THEN NEW(E) END;
	InitED(E);
	FOR y := Sy TO Sy + Sh DO
		FOR x := Sx TO Sx + Sw DO
			conf := 0;
			IF A[y - 1, x] = 1 THEN INC(conf, 1) END;
			IF A[y, x - 1] = 1 THEN INC(conf, 2) END;
			IF A[y + 1, x] = 1 THEN INC(conf, 4) END;
			IF A[y, x + 1] = 1 THEN INC(conf, 8) END;
			xt := (A[y, x] + 1) DIV 2;
			INC(E.val[xt, conf])
		END
	END
END EmpiricalDistribute;

(* PROCEDURE EmpiricalDistributeC (Eo,Ee: EmpiricalDistribution;  A: antsArrayObjects.tINTEGERArray;  Sx,Sy,Sw,Sh: SIGNED32);
VAR x,y: SIGNED32 ;  xt,vt: Index;
BEGIN
IF Eo= NIL THEN NEW(Eo) END;
IF Ee=NIL THEN NEW(Ee) END;
InitED(Eo); InitED(Ee);
FOR y := Sy TO Sy+Sh DO
FOR x := Sx TO Sx+Sw DO
vt := A[y-1][x]+A[y+1][x]+A[y][x-1]+A[y][x+1]+4;
xt := (A[y][x]+1) DIV 2;
IF ODD(x+y) THEN
INC(Eo.xv[xt,vt]);  INC(Eo.v[vt]);
ELSE
INC(Ee.xv[xt,vt]);  INC(Ee.v[vt]);
END;
END;
END;
END EmpiricalDistributeC; *)

PROCEDURE GenerateED (g: tEDGenerator);
	VAR par: tParameter;   ed: EmpiricalDistribution;
BEGIN
	par := g.par;  ed := par.ED(EmpiricalDistribution);
	EmpiricalDistribute (ed, par.A.A, 1, 1, par.A.w - 3, par.A.h - 3 );
	ProbA(par.ED(EmpiricalDistribution), lastprob);
	(*		EmpiricalDistributeC(par.CEDo(EmpiricalDistribution),par.CEDe(EmpiricalDistribution), par.A.A, 1,1,par.A.w-3,par.A.h-3);
	*)
	par.x := 1;  par.y := 1;  par.w := par.A.w - 2;  par.h := par.A.h - 2
	(* msg.val := par;
	vyBase.ForUsersHandle(g,msg)*)
END GenerateED;

(*PROCEDURE GenerateED2 (g: tEDGenerator);
VAR par: tParameter; msg: antsTypes.tNewValMsg ; w: SIGNED32;
BEGIN
par := g.par;
FOR w := 1 TO par.A.w-2 DO
EmpiricalDistribute (par.ED(EmpiricalDistribution), par.A.A, 1,1,w,w );
EmpiricalDistributeC(par.CEDo(EmpiricalDistribution),par.CEDe(EmpiricalDistribution), par.A.A, 1,1,w,w);
par.x := 1; par.y := 1; par.w := w; par.h := w;
msg.val:= par;
vyBase.ForUsersHandle(g,msg)
END;
END GenerateED2;*)

PROCEDURE Handler* (obj: Objects.Object;    VAR msg: Objects.ObjMsg);
BEGIN
	WITH obj: tEDGenerator DO
		(*WITH msg:  antsTypes.tNewValMsg DO
		obj.par.A := msg.val(antsArrayObjects.tObject);
		obj.gen(obj);
		IF debug THEN WriteED(obj.par.ED(EmpiricalDistribution)) END;
		ELSE
		END; *)
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

BEGIN aM.launch;
END antsBinaryNINNED.
