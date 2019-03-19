MODULE antsRandom IN Oberon;  	(** fof  **)
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
(* This is NOT the standard random number generator module for AntsInFields, this module is aimed as demonstration of simple random number
generators und corresponds mainly to its Panel antsRandom.Panel *)



IMPORT vyRanBase, vyRanParksMiller, vyRandom, antsCommands, vyBase, Objects, Attributes, antsObjects, Gadgets, vyLongrealVec, antsPortability,
	Math := MathL IN A2,  aM := antsMessages;

VAR
	default-: vyRanBase.tRandom;


	(*
	CONST
	MAX = 65000; (*! unsauber *)
	*)

	(*
	PROCEDURE GetSeed* (VAR nr: LONGINT);
	VAR seed: vyRanBase.tSeed;
	BEGIN
	vyRanBase.RandomGenerator.GetSeed(vyRanBase.RandomGenerator, seed);
	nr := seed(vyRanBase.tLongintSeed).val
	END GetSeed;

	PROCEDURE SetSeed* (nr: LONGINT);
	VAR seed: vyRanBase.tSeed;
	BEGIN
	vyRanBase.RandomGenerator.GetSeed(vyRanBase.RandomGenerator, seed);
	seed(vyRanBase.tLongintSeed).val := nr;
	vyRanBase.RandomGenerator.SetSeed(vyRanBase.RandomGenerator, seed)
	END SetSeed;
	*)


PROCEDURE max* (): LONGINT;
BEGIN
	RETURN vyRanBase.RandomGenerator.Max(vyRanBase.RandomGenerator)
END max;


PROCEDURE SetGen* (g: vyRanBase.tRandom);
BEGIN
	IF vyRanBase.RandomGenerator # g THEN vyRanBase.Install(g) END
END SetGen;

(*
PROCEDURE GetL* (): LONGINT;
BEGIN
RETURN vyRanBase.RandomBits();
(*
RETURN gen.GetRandom(vyRanBase.RandomGenerator)
*)
END GetL;

PROCEDURE GetU* (): LONGREAL;
BEGIN
RETURN vyRanBase.RandomU();
END GetU;
*)

(* returns random number with Laplace density 1 / (2 lambda) * exp (- (x-m) / lambda) *)
PROCEDURE Laplace* (mu, lambda: LONGREAL): LONGREAL;
	VAR ran: LONGREAL;
BEGIN
	ran := vyRandom.Exp(1 / lambda);
	IF vyRanBase.RandomU() < 0.5 THEN ran := mu - ran ELSE ran := mu + ran END;
	RETURN ran
END Laplace;

PROCEDURE Install*;
BEGIN
	vyRanParksMiller.Install();
	default := vyRanBase.RandomGenerator
END Install;

PROCEDURE LCG (a, b, c, seed: antsPortability.Hugeint): antsPortability.Hugeint;
BEGIN
	RETURN antsPortability.Modulus(antsPortability.Add(antsPortability.Multiply(a, seed) , b) , c);
END LCG;


PROCEDURE SetRandu*;
	VAR obj: vyBase.Object;
BEGIN
	antsCommands.InitScan("name=OBJ");
	IF antsCommands.ExpectObject("name", obj) THEN
		Attributes.SetLongReal(obj, "a", (65539));
		Attributes.SetLongReal(obj, "b", (0));
		Attributes.SetLongReal(obj, "c", (2147483648.0));
		Attributes.SetLongReal(obj, "seed", (1));
		Attributes.SetLongReal(obj, "u", 0);
		Gadgets.Update(obj);
	END;
END SetRandu;

PROCEDURE SetExA*;
	VAR obj: vyBase.Object;
BEGIN
	antsCommands.InitScan("name=OBJ");
	IF antsCommands.ExpectObject("name", obj) THEN
		Attributes.SetLongReal(obj, "a", (65));
		Attributes.SetLongReal(obj, "b", (1));
		Attributes.SetLongReal(obj, "c", (2048));
		Attributes.SetLongReal(obj, "seed", (0));
		Attributes.SetLongReal(obj, "u", 0);
		Gadgets.Update(obj);
	END;
END SetExA;

PROCEDURE SetExC*;
	VAR obj: vyBase.Object;
BEGIN
	antsCommands.InitScan("name=OBJ");
	IF antsCommands.ExpectObject("name", obj) THEN
		Attributes.SetLongReal(obj, "a", (1229));
		Attributes.SetLongReal(obj, "b", (1));
		Attributes.SetLongReal(obj, "c", (2048));
		Attributes.SetLongReal(obj, "seed", (0));
		Attributes.SetLongReal(obj, "u", 0);
		Gadgets.Update(obj);
	END;

END SetExC;

PROCEDURE SetExD*;
	VAR obj: vyBase.Object;
BEGIN
	antsCommands.InitScan("name=OBJ");
	IF antsCommands.ExpectObject("name", obj) THEN
		Attributes.SetLongReal(obj, "a", (43));
		Attributes.SetLongReal(obj, "b", (0));
		Attributes.SetLongReal(obj, "c", (2048));
		Attributes.SetLongReal(obj, "seed", (1));
		Attributes.SetLongReal(obj, "u", 0);
		Gadgets.Update(obj);
	END;
END SetExD;

PROCEDURE SetMarsaglia*;
	VAR obj: vyBase.Object;
BEGIN
	antsCommands.InitScan("name=OBJ");
	IF antsCommands.ExpectObject("name", obj) THEN
		Attributes.SetLongReal(obj, "a", (69069));
		Attributes.SetLongReal(obj, "b", (1));
		Attributes.SetLongReal(obj, "c", (4294967296.0));
		Attributes.SetLongReal(obj, "seed", (0));
		Attributes.SetLongReal(obj, "u", 0);
		Gadgets.Update(obj);
	END;
END SetMarsaglia;


PROCEDURE DoApplyRNG (obj: vyBase.Object;  VAR u: LONGREAL);
	VAR seed, a, b, c, es:antsPortability.Hugeint;  seedr, ar, br, cr: LONGREAL;
BEGIN
	Attributes.GetLongReal(obj, "a", ar);
	Attributes.GetLongReal(obj, "b", br);
	Attributes.GetLongReal(obj, "c", cr);
	Attributes.GetLongReal(obj, "seed", seedr);

	a := antsPortability.LRToHI(ar);
	b :=antsPortability.LRToHI(br);
	c := antsPortability.LRToHI(cr);
	seed := antsPortability.LRToHI(seedr);
	(*
	Attributes.GetInt(obj, "seedLow", es.low);
	Attributes.GetInt(obj, "seedHi", es.hi);
	*)
	IF ~antsPortability.Equal(es, seed) THEN aM.vSR("antsRandom:Warning: Seed changed!",seedr);   END;


	(*
	Attributes.SetInt(obj, "aLow", a.low);
	Attributes.SetInt(obj, "aHigh", a.hi);
	Attributes.SetInt(obj, "bLow", b.low);
	Attributes.SetInt(obj, "bHigh", b.hi);
	Attributes.SetInt(obj, "cLow", c.low);
	Attributes.SetInt(obj, "cHigh", c.hi);
	Attributes.SetInt(obj, "seedLow", seed.low);
	Attributes.SetInt(obj, "seedHigh", seed.hi);
	*)

	seed := LCG(a, b, c, seed) ;

	(*
	Attributes.SetInt(obj, "seedLow", seed.low);
	Attributes.SetInt(obj, "seedHigh", seed.hi);
	*)

	(*
	Attributes.SetInt(obj,"seedLow",seed.low);
	Attributes.SetInt(obj,"seedHigh",seed.hi);
	*)

	Attributes.SetLongReal(obj, "seed", antsPortability.HIToLR(seed));
	u := antsPortability.HIToLR(seed) / antsPortability.HIToLR(c);
	Attributes.SetLongReal(obj, "u", u);
	Gadgets.Update(obj);

END DoApplyRNG;


PROCEDURE ApplyRNG*;
	VAR u: LONGREAL;  obj, addv: vyBase.Object;  i, iter: LONGINT;  v: vyLongrealVec.tVector;
BEGIN
	antsCommands.InitScan("name=OBJ [addto=OBJ iter=INT]");
	IF antsCommands.ExpectObject("name", obj) THEN
		IF antsCommands.GetObject("addto", addv) THEN
			v := addv(vyLongrealVec.tVector);
			IF antsCommands.ExpectNumber("iter", iter) THEN
				FOR i := 1 TO iter DO
					DoApplyRNG(obj, u);
					vyLongrealVec.Append(u, v);
				END;
			END;
			vyBase.Update(v);
		ELSE
			DoApplyRNG(obj, u);
		END;
	END;
END ApplyRNG;

PROCEDURE DoBoxMuller (obj: vyBase.Object;  VAR n1, n2: LONGREAL);
VAR u1, u2: LONGREAL;  BEGIN
	DoApplyRNG(obj, u1); Attributes.SetLongReal(obj,"lastu",u1);
	DoApplyRNG(obj, u2);
	n1 := Math.sqrt( - 2 * Math.ln(u1)) * Math.cos(2 * Math.pi * u2);
	n2 := Math.sqrt( - 2 * Math.ln(u1)) * Math.sin(2 * Math.pi * u2);
	Attributes.SetLongReal(obj, "n1", n1);
	Attributes.SetLongReal(obj, "n2", n2);
END DoBoxMuller;


PROCEDURE ApplyBoxMuller*;
	VAR n1, n2: LONGREAL;  obj: vyBase.Object;   addv: vyBase.Object;  i, iter: LONGINT;  v: vyLongrealVec.tVector;
BEGIN
	antsCommands.InitScan("name=OBJ [addto=OBJ iter=INT]");
	IF antsCommands.ExpectObject("name", obj) THEN

		IF antsCommands.GetObject("addto", addv) THEN
			v := addv(vyLongrealVec.tVector);
			IF antsCommands.ExpectNumber("iter", iter) THEN
				FOR i := 1 TO iter DO
					DoBoxMuller(obj, n1, n2);
					vyLongrealVec.Append(n1, v);   vyLongrealVec.Append(n2, v);
				END;
			END;
			vyBase.Update(v);
		ELSE
			DoBoxMuller(obj, n1, n2);
		END;

	END;
END ApplyBoxMuller;

PROCEDURE DoPolarMethod (obj: vyBase.Object;  VAR n1, n2: LONGREAL);
	VAR u1, u2, v1, v2, w, d: LONGREAL;
BEGIN
	REPEAT
		DoApplyRNG(obj, u1);Attributes.SetLongReal(obj,"lastu",u1);
		DoApplyRNG(obj, u2);
		v1 := 2 * u1 - 1;
		v2 := 2 * u2 - 1;
		w := v1 * v1 + v2 * v2;
	UNTIL w <= 1;
	d := Math.sqrt( - 2 * Math.ln(w) / w);
	n1 := d * v1;  n2 := d * v2;
	Attributes.SetLongReal(obj, "n1", n1);
	Attributes.SetLongReal(obj, "n2", n2);

END DoPolarMethod;


PROCEDURE ApplyPolarMethod*;
	VAR n1, n2: LONGREAL;  obj: vyBase.Object;  addv: vyBase.Object;  i, iter: LONGINT;  v: vyLongrealVec.tVector;
BEGIN
	antsCommands.InitScan("name=OBJ [addto=OBJ iter=INT]");
	IF antsCommands.ExpectObject("name", obj) THEN
		IF antsCommands.GetObject("addto", addv) THEN
			v := addv(vyLongrealVec.tVector);
			IF antsCommands.ExpectNumber("iter", iter) THEN
				FOR i := 1 TO iter DO
					DoPolarMethod(obj, n1, n2);
					vyLongrealVec.Append(n1, v);   vyLongrealVec.Append(n2, v);
				END;
			END;
			vyBase.Update(v);
		ELSE
			DoPolarMethod(obj, n1, n2);
		END;
	END;
END ApplyPolarMethod;


PROCEDURE PowerH (this, power: LONGINT): antsPortability.Hugeint;
	VAR h: antsPortability.Hugeint;
BEGIN
	h := antsPortability.ONE;
	WHILE(power > 0) DO
		h := antsPortability.Multiply(h, antsPortability.LIToHI(this));
		DEC(power);
	END;
	RETURN h;
END PowerH;

PROCEDURE NewDynamicRNG*;
	(* creates simple vyBase Objects with some attributes needed for  simple random number generator
	persistency,consistency etc. all handled by vyBase, Gadgets and Objects
	*)
	(* this is a bad rng: RANDU *)
	VAR obj: Objects.Object;
	a, b, c, seed: antsPortability.Hugeint;
BEGIN
	antsObjects.NewEmptyObject;
	obj := Objects.NewObj;
	c := PowerH(2, 32);
	b := antsPortability.LIToHI(1);
	a := antsPortability.LIToHI(69069);
	seed := antsPortability.ONE;

	(*
	Attributes.SetInt(obj, "aLow", a.low);
	Attributes.SetInt(obj, "aHigh", a.hi);
	Attributes.SetInt(obj, "bLow", b.low);
	Attributes.SetInt(obj, "bHigh", b.hi);
	Attributes.SetInt(obj, "cLow", c.low);
	Attributes.SetInt(obj, "cHigh", c.hi);
	Attributes.SetInt(obj, "seedLow", seed.low);
	Attributes.SetInt(obj, "seedHigh", seed.hi);
	*)

	Attributes.SetLongReal(obj, "a", antsPortability.HIToLR(a));
	Attributes.SetLongReal(obj, "b", antsPortability.HIToLR(b));
	Attributes.SetLongReal(obj, "c", antsPortability.HIToLR(c));
	Attributes.SetLongReal(obj, "seed", antsPortability.HIToLR(seed));
	Attributes.SetLongReal(obj, "u", 0);
END NewDynamicRNG;

PROCEDURE Max(i1,i2: LONGINT): LONGINT;
BEGIN
	IF i1>i2 THEN RETURN i1 ELSE RETURN i2 END;
END Max;


PROCEDURE MakeShifted*;
	VAR o, o1, o2, o3: vyBase.Object;  v, v1, v2, v3: vyLongrealVec.tVector;  i: LONGINT;
BEGIN
	antsCommands.InitScan("vec=OBJ vec1=OBJ vec2=OBJ [vec3=OBJ]");
	IF antsCommands.ExpectObject("vec", o) &  antsCommands.ExpectObject("vec1", o1) & antsCommands.ExpectObject("vec2", o2) THEN
		v := o(vyLongrealVec.tVector);
		v1 := o1(vyLongrealVec.tVector);
		v2 := o2(vyLongrealVec.tVector);
		ASSERT((o # o1) & (o1 # o2) & (o2 # o));

		IF antsCommands.GetObject("vec3", o3) THEN
			v3 := o3(vyLongrealVec.tVector);

			vyLongrealVec.SetLen(v1, Max(vyLongrealVec.Len(v) - 2,0));
			vyLongrealVec.SetLen(v2, Max(vyLongrealVec.Len(v) - 2,0));
			vyLongrealVec.SetLen(v3, Max(vyLongrealVec.Len(v) - 2,0));

			FOR i := 2 TO vyLongrealVec.Len(v) - 1 DO
				vyLongrealVec.Set(vyLongrealVec.Get(v, i - 2), v1, i - 2);
				vyLongrealVec.Set(vyLongrealVec.Get(v, i - 1), v2, i - 2);
				vyLongrealVec.Set(vyLongrealVec.Get(v, i), v3, i - 2)
			END;
			vyBase.Update(v3);
		ELSE
			vyLongrealVec.SetLen(v1, Max(vyLongrealVec.Len(v) - 1,0));
			vyLongrealVec.SetLen(v2, Max(vyLongrealVec.Len(v) - 1,0));
			FOR i := 1 TO vyLongrealVec.Len(v) - 1 DO
				vyLongrealVec.Set(vyLongrealVec.Get(v, i - 1), v1, i - 1);
				vyLongrealVec.Set(vyLongrealVec.Get(v, i), v2, i - 1);
			END;
		END;
		vyBase.Update(v1);  vyBase.Update(v2);
	END;
END MakeShifted;

PROCEDURE MakePaired*;
	VAR o, o1, o2,o3: vyBase.Object;  v, v1, v2,v3: vyLongrealVec.tVector;  i: LONGINT;
BEGIN
	antsCommands.InitScan("vec=OBJ vec1=OBJ vec2=OBJ");
	IF antsCommands.ExpectObject("vec", o) &  antsCommands.ExpectObject("vec1", o1) & antsCommands.ExpectObject("vec2", o2) THEN
		IF antsCommands.GetObject("vec3",o3) THEN v3 := o3(vyLongrealVec.tVector) ELSE v3 := NIL END;
		v := o(vyLongrealVec.tVector);
		v1 := o1(vyLongrealVec.tVector);
		v2 := o2(vyLongrealVec.tVector);

		ASSERT((o # o1) & (o1 # o2) & (o2 # o));

		vyLongrealVec.SetLen(v1, vyLongrealVec.Len(v) DIV 2);
		vyLongrealVec.SetLen(v2, vyLongrealVec.Len(v) DIV 2);
		IF v3 # NIL THEN vyLongrealVec.SetLen(v3, vyLongrealVec.Len(v) DIV 2);  vyLongrealVec.Set(0, v3, 0);END;

		FOR i := 0 TO vyLongrealVec.Len(v) DIV 2 - 1  DO
			vyLongrealVec.Set(vyLongrealVec.Get(v, i * 2), v1, i);
			vyLongrealVec.Set(vyLongrealVec.Get(v, i * 2 + 1), v2, i);
			IF (v3 # NIL) & (i>0) THEN
				vyLongrealVec.Set(vyLongrealVec.Get(v, i * 2-1), v3, i);
			END;
		END;
		vyBase.Update(v1);  vyBase.Update(v2);
	END;
END MakePaired;




BEGIN aM.launch;
	Install();
END antsRandom.

System.Free antsRandom ~
fofAutomatic.Do
antsFctVector.NewVec testvec 0 ~
antsFctVector.NewVec v1 0 ~
antsFctVector.NewVec v2 0 ~
antsFctVector.NewVec v3 0 ~
~

antsFctVector.ClearVec testvec  ~

antsRandom.NewDynamicRNG test ~
antsObjects.WriteAttributes test ~
fofAutomatic.Do > iter 1000
antsRandom.ApplyRNG test ~
antsVecOpt.AppendValue test u testvec ~
~
antsRandom.MakeShifted testvec v1 v2 v3 ~
~


Voyager.Show testvec as LinePlot ~
Voyager.Show testvec ~
Voyager.Show v1 v3 ~
Voyager.Show  v1 v2 v3 ~







