MODULE vyRandu IN Oberon;
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



(***** RANDU number generator *****)
(* fof 980708 *)
(* changes:
30.11.00 by Johannes Becker - allow to load/store seed
30.3.00 by Johannes Becker - new version of vyRanBase *)
(*= This is an example of a generator with well known deficits. Do NOT use it in simulations. This generator should only be used to demonstrate what not to do. *)

IMPORT SYSTEM, vyRanBase, Objects;

CONST
	cModuleName = "vyRandu";  (* jb 30.11.00 *)
	idversion* = 'vyRandu 0.0d1';
	cut =  {2* MAX(SET) DIV 3};

TYPE
	Bits = vyRanBase.Bits;
	tRandom = vyRanBase.tRandom;
	(* tSeed = vyRanBase.tSeed          jb 30.11.00 - inlined, causes trap when compiling *)

VAR
	cuti : LONGINT;
	maxsi: LONGINT; 	(* maxs: SET; *)	(* jb 30.3.00 *)

PROCEDURE Add (VAR x: SET;     y: SET;       shift: LONGINT);
	VAR carry: BOOLEAN;     i: LONGINT;
BEGIN
	carry := FALSE;
	FOR i := MAX(SET) - shift TO 1 BY - 1 DO
		IF i IN x THEN
			IF (i + shift) IN y THEN
				IF carry THEN (* INCL(x,i) *)ELSE EXCL(x, i);     carry := TRUE   END
			ELSE
				IF carry THEN EXCL(x, i) ELSE (* INCL(x,i)*)END
			END
		ELSE
			IF (i + shift) IN y THEN
				IF carry THEN (* EXCL(x,i)*)ELSE INCL(x, i) END
			ELSE
				IF carry THEN INCL(x, i);     carry := FALSE ELSE EXCL(x, i) END
			END
		END
	END
END Add;

PROCEDURE TruncatedProd (x, y: LONGINT ): LONGINT;
	VAR ySET, ySET1, ySET2, ySET3 : SET;    ytemp, y1, y2, y3: LONGINT;
BEGIN
	ytemp := y;
	ySET := SYSTEM.VAL(SET, ytemp);
	y1 := ytemp MOD cuti;
	ytemp := ytemp  DIV cuti;
	y2 := ytemp MOD cuti;
	ytemp := ytemp  DIV cuti;
	IF y2 # 0 THEN
		y3 := ytemp MOD y2
	ELSE y3  := ytemp END;

	(* prod  res := y1*x+y2*x*cuti+y3*x*cuti*cuti *)
	y1 := y1 * x;
	y2 := y2 * x;
	y3 := y3 * x;
	ySET1 := SYSTEM.VAL(SET, y1);
	ySET2 := SYSTEM.VAL(SET, y2);
	ySET3 := SYSTEM.VAL(SET, y3);
	ySET := ySET1;
	Add(ySET, ySET2, MAX(SET) DIV 3 + 1);
	Add(ySET, ySET3, 2 * MAX(SET) DIV 3 + 2);
	RETURN SYSTEM.VAL(LONGINT, ySET)
END TruncatedProd;

PROCEDURE Randu* (VAR s: LONGINT);
	(*= One step of RANDU *)
CONST
	a = 65539;
BEGIN
	s := TruncatedProd(a, s)
END Randu;

PROCEDURE Next* (r: tRandom);
BEGIN Randu(r.seed(vyRanBase.tLongintSeed).val) END Next ;

PROCEDURE Max  (r: tRandom): Bits;
CONST (*a = 16807;*)	(*q = m DIV a;	r = m MOD a; scalefact=1.0D0/m;*)
BEGIN
	RETURN maxsi	(* jb 30.3.00 *)
END Max ;

PROCEDURE Get  (r: tRandom): Bits;
	VAR seed: LONGINT;
BEGIN	seed := r.seed(vyRanBase.tLongintSeed).val;    Randu(seed);    r.seed(vyRanBase.tLongintSeed).val := seed;
	RETURN seed
	(* better shift adjust: give preference to higher order bits *)
END Get ;

PROCEDURE GetUniform (r: tRandom): LONGREAL;
CONST (*a = 16807;*)	m = 2147483647;    	(*q = m DIV a;	r = m MOD a; *)scalefact = 1.0D0 / m;
	VAR seed: LONGINT;
BEGIN	 seed := r.seed(vyRanBase.tLongintSeed).val;    	Randu(seed);    r.seed(vyRanBase.tLongintSeed).val := seed;
	RETURN seed * scalefact
END GetUniform;

PROCEDURE GetL (r: tRandom;    top: LONGINT): LONGINT;
CONST (*a = 16807;	m = 2147483647; 	q = m DIV a;	r = m MOD a; scalefact=1.0D0/m;*)
	VAR seed: LONGINT;
BEGIN	 (* better break if top is out of range *)
	seed := r.seed(vyRanBase.tLongintSeed).val;    	Randu(seed);    r.seed(vyRanBase.tLongintSeed).val := seed;
	RETURN ((seed - 1) MOD top)
	(* better use higher order bits *)
END GetL;

PROCEDURE Reset (r: tRandom);
VAR
	seed: vyRanBase.tSeed;
BEGIN
	seed := r.seed;
	WITH seed: vyRanBase.tLongintSeed DO seed.val := vyRanBase.DefaultLongSeed () END
END Reset;

(*
PROCEDURE init (r: tRandom);
VAR seed: vyRanBase.tLongintSeed;
BEGIN NEW(seed); vyRanBase.FixDefaults(r); r.SevyRanBase.tLongintSeed(r, seed); r.seed(vyRanBase.tLongintSeed).val := vyRanBase.DefaultLongSeed()
END init;
*)

PROCEDURE HandleAttributes (obj: tRandom;   VAR M: Objects.AttrMsg);
BEGIN
	IF M.id = Objects.get THEN
		IF M.name = "Gen"THEN COPY("vyRandu.Alloc", M.s);   M.class := Objects.String;   M.res := 0
		ELSIF (M.name = "Value") OR (M.name = "Seed")  THEN M.i := obj.seed(vyRanBase.tLongintSeed).val;   M.class := Objects.Int;   M.res := 0
		ELSE vyRanBase.Handler(obj, M)
		END
	ELSIF M.id = Objects.set THEN
		IF (M.name = "Value") OR (M.name = "Seed") THEN
			IF M.class = Objects.Int THEN obj.seed(vyRanBase.tLongintSeed).val := M.i;   M.res := 0 END
		ELSE vyRanBase.Handler(obj, M)
		END
	ELSIF M.id = Objects.enum THEN
		M.Enum("Seed");   vyRanBase.Handler(obj, M)
	ELSE
		vyRanBase.Handler (obj, M) (* jb 30.3.00 *)
	END
END HandleAttributes;

(* no longer need - jb 30.11.00 *)
(*
PROCEDURE Store (obj: tRandom;  VAR M: Objects.FileMsg);
BEGIN
Files.WriteLInt(M.R, obj.seed(vyRanBase.tLongintSeed).val);
vyRanBase.Handler(obj, M)
END Store;

PROCEDURE Load (obj: tRandom;  VAR M: Objects.FileMsg);
BEGIN
Files.ReadLInt(M.R, obj.seed(vyRanBase.tLongintSeed).val);
vyRanBase.Handler(obj, M)
END Load;
*)

PROCEDURE Handler* (obj: Objects.Object;   VAR M: Objects.ObjMsg);
BEGIN
	WITH obj: tRandom DO
		IF M IS Objects.AttrMsg THEN
			WITH M: Objects.AttrMsg DO
				HandleAttributes(obj, M)
			END
		ELSE
			vyRanBase.Handler(obj, M)
		END
	END;   (*WITH obj:tRandom DO*)
END Handler;

PROCEDURE InitBasic (r: tRandom);
BEGIN
	r.id := 'RU Randu v0r0d01';      	r.shortid := 'RU';

	vyRanBase.SetDefaultProcs (r);

	r.Reset := Reset;
	r.GetRandom := Get;
	r.GetRandomL := GetL;
	r.GetRandomU := GetUniform;
	r.NextRandom := Next;
	r.Max := Max;

	r.handle := Handler;

	r.AllocSeed := vyRanBase.AllocLongintSeed
END InitBasic;

PROCEDURE Init (r: tRandom);
VAR
	seed: vyRanBase.tLongintSeed;
BEGIN
	InitBasic (r);
	NEW (seed);
	r.SetSeed (r, seed)
END Init;

(* added - jb 30.11.00 *)
PROCEDURE Alloc*;
VAR
	r: tRandom;
BEGIN
	NEW (r);  InitBasic (r);  Objects.NewObj := r
END Alloc;


PROCEDURE New*;
VAR
	r: tRandom;
BEGIN
	NEW (r);
	Init (r);
	r.Reset (r);
	Objects.NewObj := r
END New;

PROCEDURE Install*;
BEGIN
	New;
	vyRanBase.Install (Objects.NewObj (tRandom))
END Install;

PROCEDURE InitConst;
	VAR i: LONGINT;
	maxs: SET;
BEGIN
	cuti := SYSTEM.VAL(LONGINT, cut);
	maxs := {};
	FOR i := 1 TO MAX(SET) DO
		INCL(maxs, i)
	END;
	maxsi := SYSTEM.VAL (LONGINT, maxs)
END InitConst;


BEGIN
	InitConst();
END vyRandu.



System.Free vyRandu vyRanBase ~

vyRandu.Install ~
Voyager.Random 1000 ~

(* debugging versions *)

PROCEDURE Debug (a, b, c, d: SET);
	VAR i: LONGINT;
BEGIN
	vyOut.Ln();     vyOut.String("val");     vyOut.Ln();    FOR i := 0 TO 2 * MAX(SET) DIV 3 + 1 DO vyOut.String("#")   END;
	FOR i := 0 TO MAX(SET) DO
		IF i IN a THEN vyOut.String("+") ELSE vyOut.String("-") END
	END;
	vyOut.Ln();      FOR i := 0 TO 2 * MAX(SET) DIV 3 + 1 DO vyOut.String("#")   END;
	FOR i := 0 TO MAX(SET) DO
		IF i IN b THEN vyOut.String("+") ELSE vyOut.String("-") END
	END;
	vyOut.Ln();    FOR i := 0 TO MAX(SET) DIV 3 DO vyOut.String("#")   END;
	FOR i := 0 TO MAX(SET) DO
		IF i IN c THEN vyOut.String("+") ELSE vyOut.String("-") END
	END;
	vyOut.Ln();
	FOR i := 0 TO MAX(SET) DO
		IF i IN d THEN vyOut.String("+") ELSE vyOut.String("-") END
	END
END Debug;

PROCEDURE TruncatedProdD (x, y: LONGINT ): LONGINT;
	VAR ySET, ySET1, ySET2, ySET3, cut : SET;     i: LONGINT;     ytemp, y1, y2, y3, cuti: LONGINT;
BEGIN
	cut := {};
	INCL(cut, 2 * MAX(SET) DIV 3);
	cuti := SYSTEM.VAL(LONGINT, cut);      (*! to const *)
	ytemp := y;
	ySET := SYSTEM.VAL(SET, ytemp);
	y1 := ytemp MOD cuti;
	ytemp := ytemp  DIV cuti;
	y2 := ytemp MOD cuti;
	ytemp := ytemp  DIV cuti;
	IF y2 # 0 THEN
		y3 := ytemp MOD y2
	ELSE y3  := ytemp END;
	ySET1 := SYSTEM.VAL(SET, y1);
	ySET2 := SYSTEM.VAL(SET, y2);
	ySET3 := SYSTEM.VAL(SET, y3);

	(*
	ySET1 := {}; ySET2 := {}; ySET3 := {};
	FOR i := 0 TO MAX(SET) DIV 3-1  DO
	IF i IN ySET THEN INCL(ySET1,i) END;
	END;
	FOR i := MAX(SET) DIV 3  TO 2* MAX(SET) DIV 3-1 DO
	IF i IN ySET THEN INCL(ySET2,i-MAX(SET) DIV 3) END;
	END;
	FOR i := 2* MAX(SET) DIV 3 TO MAX(SET) DO
	IF i IN ySET THEN INCL(ySET3,i-2*MAX(SET) DIV 3) END;
	END;
	*)

	Debug(ySET, ySET1, ySET2, ySET3);
	ytemp := y1 + y2 * cuti + y3 * cuti * cuti;
	ASSERT(ytemp = y, 103);
	ySET := SYSTEM.VAL(SET, ytemp);
	Debug(ySET, ySET1, ySET2, ySET3);

	(* prod  res := y1*x+y2*x*cuti+y3*x*cuti*cuti *)

	y1 := y1 * x;
	y2 := y2 * x;
	y3 := y3 * x;

	ytemp := y1 + y2 * cuti + y3 * cuti * cuti;
	ytemp := y * x;     (*!!!! warum bleibt das Programm hier nicht stehen ???? *)(* overflow wird ins Vorzeichen geschrieben !*)
	ySET1 := SYSTEM.VAL(SET, y1);
	ySET2 := SYSTEM.VAL(SET, y2);
	ySET3 := SYSTEM.VAL(SET, y3);
	ySET := SYSTEM.VAL(SET, ytemp);
	Debug(ySET, ySET1, ySET2, ySET3);

	ySET1 := SYSTEM.VAL(SET, y1);
	ySET2 := SYSTEM.VAL(SET, y2);
	ySET3 := SYSTEM.VAL(SET, y3);
	ySET := ySET1;
	Add(ySET, ySET2, MAX(SET) DIV 3 + 1);
	Debug(ySET, ySET1, ySET2, ySET3);
	Add(ySET, ySET3, 2 * MAX(SET) DIV 3 + 2);
	Debug(ySET, ySET1, ySET2, ySET3);
	vyOut.Int(ytemp, 20);     vyOut.Int(SYSTEM.VAL(LONGINT, ySET), 20);
	ASSERT(ytemp = SYSTEM.VAL(LONGINT, ySET), 105);
	RETURN 0
END TruncatedProdD;

PROCEDURE Test*;
	VAR x, y, z, i: LONGINT;
BEGIN
	FOR i := 0 TO 0 DO
		y := vyRanBase.Random();
		z := TruncatedProdD (65539, y)
	END
END Test;

(* end debugging versions *)


