MODULE antsDiscreteEmpiricD IN Oberon; 	(** JM  **)
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



IMPORT vyBase, antsArrayObjects, antsEmpiricD , Objects, aM := antsMessages;
CONST
TYPE
	Index = SIGNED32;

	txv = POINTER TO ARRAY OF ARRAY OF ARRAY OF ARRAY OF ARRAY OF SIGNED32;
	tv = POINTER TO  ARRAY OF ARRAY OF ARRAY OF ARRAY OF SIGNED32 ;

	EmpiricalDistribution* = POINTER TO EDDesc;   (* empirical Distribution of an binary state space model *)
	EDDesc = RECORD (antsEmpiricD.EDDesc)
		card-: SIGNED32;
		xv: txv;
		v: tv
	END;

	tParameter* = POINTER TO tParameterDesc;
	tParameterDesc* = RECORD (antsEmpiricD.tParameterDesc)
		card: SIGNED32
	END;

	tEDGenerator* = POINTER TO tEDGeneratorDesc;
	tEDGeneratorDesc = RECORD (vyBase.ObjDesc)
		par: tParameter;
		gen: PROCEDURE (g: tEDGenerator);
	END;

	VAR debug: BOOLEAN;

PROCEDURE InitED (E: EmpiricalDistribution);
	VAR card: SIGNED32;  x, v1, v2, v3, v4: SIGNED32;
BEGIN
	card := E.card;  DEC(card);
	FOR v1 := 0 TO card DO
		FOR v2 := 0 TO card DO
			FOR v3 := 0 TO card DO
				FOR v4 := 0 TO card DO
					E.v[v1, v2, v3, v4] := 0;
					FOR x := 0 TO card DO
						E.xv[x, v1, v2, v3, v4] := 0
					END
				END
			END
		END
	END
END InitED;

PROCEDURE R* (E: EmpiricalDistribution;   x, v1, v2, v3, v4: SIGNED32): SIGNED32;
BEGIN
	(* INC(x); x := x DIV 2;INC(v,4);*)
	RETURN E.xv[x, v1, v2, v3, v4]
END R;

PROCEDURE M* (E: EmpiricalDistribution;   v1, v2, v3, v4: Index): SIGNED32;
BEGIN
	(* INC(v,4); *)
	RETURN E.v[v1, v2, v3, v4]
END M;

PROCEDURE F* (E: EmpiricalDistribution;   x, v1, v2, v3, v4: Index): FLOAT64;
	VAR nv: SIGNED32;
BEGIN
	nv := M(E, v1, v2, v3, v4);
	IF nv # 0 THEN RETURN R(E, x, v1, v2, v3, v4) / nv ELSE RETURN 0 END
END F;


PROCEDURE Sort4 (v1, v2, v3, v4: SIGNED32;  VAR e1, e2, e3, e4: SIGNED32);
BEGIN
	IF v1 < v2 THEN e1 := v1;  e2 := v2
	ELSE e1 := v2;  e2 := v1
	END;
	IF v3 < e1 THEN e3 := e2;  e2 := e1;  e1 := v3
	ELSIF v3 < e2 THEN e3 := e2;  e2 := v3
	ELSE e3 := v3
	END;
	IF v4 < e1 THEN e4 := e3;  e3 := e2;  e2 := e1;  e1 := v4
	ELSIF v4 < e2 THEN e4 := e3;  e3 := e2;  e2 := v4
	ELSIF v4 < e3 THEN e4 := e3;  e3 := v4
	ELSE e4 := v4
	END
END Sort4;

PROCEDURE EmpiricalDistributeS (VAR E: EmpiricalDistribution;   A: antsArrayObjects.tINTEGERArray;   Sx, Sy, Sw, Sh: SIGNED32);
	VAR x, y: SIGNED32 ;     e1, e2, e3, e4: SIGNED32;
	(* stores permuted v1,v2,v3,v4 in a sorted way *)
BEGIN
	IF E = NIL THEN NEW(E) END;
	InitED(E);
	FOR y := Sy TO Sy + Sh DO
		FOR x := Sx TO Sx + Sw DO
			Sort4(A[y - 1, x], A[y + 1, x], A[y, x - 1], A[y, x + 1], e1, e2, e3, e4);
			INC(E.xv[A[y, x], e1, e2, e3, e4]);
			INC(E.v[e1, e2, e3, e4])
		END
	END
END EmpiricalDistributeS;

PROCEDURE EmpiricalDistributeCS (Eo, Ee: EmpiricalDistribution;    A: antsArrayObjects.tINTEGERArray;   Sx, Sy, Sw, Sh: SIGNED32);
	VAR x, y: SIGNED32 ;      e1, e2, e3, e4: SIGNED32;
	(* stores permuted v1,v2,v3,v4 in a sorted way *)
BEGIN
	IF Eo = NIL THEN NEW(Eo) END;
	IF Ee = NIL THEN NEW(Ee) END;
	InitED(Eo);  InitED(Ee);
	FOR y := Sy TO Sy + Sh DO
		FOR x := Sx TO Sx + Sw DO
			Sort4(A[y - 1, x], A[y + 1, x], A[y, x - 1], A[y, x + 1], e1, e2, e3, e4);
			IF ODD(x + y) THEN
				INC(Eo.xv[A[y, x], e1, e2, e3, e4]);
				INC(Eo.v[e1, e2, e3, e4])
			ELSE
				INC(Ee.xv[A[y, x], e1, e2, e3, e4]);
				INC(Ee.v[e1, e2, e3, e4])
			END
		END
	END
END EmpiricalDistributeCS;

PROCEDURE GenerateED (g: tEDGenerator);
	VAR par: tParameter;   ed: EmpiricalDistribution;
BEGIN
	par := g.par;  ed := par.ED(EmpiricalDistribution);
	EmpiricalDistributeS(ed, par.A.A, 1, 1, par.A.w - 3, par.A.h - 3 );
	EmpiricalDistributeCS(par.CEDo(EmpiricalDistribution), par.CEDe(EmpiricalDistribution), par.A.A, 1, 1, par.A.w - 3, par.A.h - 3);
	par.x := 1;  par.y := 1;  par.w := par.A.w - 2;  par.h := par.A.h - 2
END GenerateED;



PROCEDURE Handler* (obj: Objects.Object;    VAR msg: Objects.ObjMsg);
BEGIN
	WITH obj: tEDGenerator DO
		(*WITH msg:  antsTypes.tNewValMsg DO
		obj.par.A := msg.val(antsArrayObjects.tObject);
		par := obj.par;
		IF par.card # par.A.depth THEN
		card :=par. A.depth;
		NEW(par.ED(EmpiricalDistribution).xv,card,card,card,card,card);
		NEW(par.ED(EmpiricalDistribution).v,card,card,card,card);
		NEW(par.CEDo(EmpiricalDistribution).xv,card,card,card,card,card);
		NEW(par.CEDo(EmpiricalDistribution).v,card,card,card,card);
		NEW(par.CEDe(EmpiricalDistribution).xv,card,card,card,card,card);
		NEW(par.CEDe(EmpiricalDistribution).v,card,card,card,card);
		END;
		obj.gen(obj);
		IF debug THEN WriteED(par.ED(EmpiricalDistribution)) END;
		ELSE
		END; *)
	END
END Handler;

PROCEDURE Open* (gen: tEDGenerator;  from: vyBase.Object);
	VAR par: tParameter;   E: EmpiricalDistribution;
BEGIN
	NEW(gen.par);
	par := gen.par;
	par.card := 0;
	NEW(E);  par.ED := E;
	NEW(E);  par.CEDo := E;
	NEW(E);  par.CEDe := E;
	vyBase.Subscribe(from, gen);
	gen.handle := Handler;
	gen.gen := GenerateED
END Open;

PROCEDURE DebugOn*;
BEGIN debug := TRUE
END DebugOn;

PROCEDURE DebugOff*;
BEGIN debug := FALSE
END DebugOff;


BEGIN aM.launch; debug := FALSE;
END antsDiscreteEmpiricD.
