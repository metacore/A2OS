MODULE vyRanSkeleton IN Oberon;
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


(***** random number generator Parks&Miller *****)
(* this module may be used as a sample implementation of new random number generators.
Do not use this module in production. If you want to use the Parks&Miller generator, use
vyParksMiller which may have some speed improvements *)

(* jb 5.5.01 - support for seed version check added *)
(* jb 7.3.01 - Reset added, SumPSqr, GetNew added *)
(* jb 11.1.01, 30.11.00 - new vyRanBase, allow to load/store seed *)
(* jb 30.3.00 - new version of vyRanBase *)

(*! Add explicit range checks *)
IMPORT vyRanBase, Objects;

CONST idversion* = 'vyRanSkeleton 0.0a5';   cModuleName = "vyRanSkeleton";
TYPE
	(* inlined - causes compiler error "129  unsatisfied forward procedure", jb 5.5.01 *)
	(*	Bits = vyRanBase.Bits;	*)
	(*	tRandom= vyRanBase.tRandom;   *)
	(*	tSeed= vyRanBase.tLongintSeed;    *)

	(** Sample implementation:  Portable random number generator - Parks and Miller,
	but using naive read-out functions. This is a skeleton only. If you want to use the
	Parks and Miller, use vyRandParksMiller. *)

PROCEDURE ParksMiller* (VAR s: LONGINT);
	(*= One step of Parks & Miller portable random number generator.
	This is considered the minimal standard random number generator. *)
CONST
	a = 16807;    (*=  = 7^5 *)	m = 2147483647;    (*= = 2^31 -1 *)
	q = m DIV a;    	r = m MOD a;
BEGIN
	s := a * (s MOD q) - r * (s DIV q);
	IF s < 0 THEN s := s + m END (* Parks & Miller *)
END ParksMiller;

PROCEDURE Next* (r: vyRanBase.tRandom);
BEGIN ParksMiller(r.seed(vyRanBase.tLongintSeed).val) END Next;

PROCEDURE Max (r: vyRanBase.tRandom): vyRanBase.Bits;
CONST (*a = 16807;*)	m = 2147483647;      	(*q = m DIV a;	r = m MOD a; scalefact=1.0D0/m;*)
BEGIN RETURN m - 1 END Max;

PROCEDURE Get (r: vyRanBase.tRandom): vyRanBase.Bits;
BEGIN	Next(r);    RETURN r.seed(vyRanBase.tLongintSeed).val
	(* better shift adjust: give preference to higher order bits *)
END Get;

PROCEDURE GetUniform (r: vyRanBase.tRandom): LONGREAL;
CONST (*a = 16807;*)	m = 2147483647;      	(*q = m DIV a;	r = m MOD a; *)scalefact = 1.0D0 / m;
BEGIN	 Next(r);   	RETURN r.seed(vyRanBase.tLongintSeed).val * scalefact
END GetUniform;

PROCEDURE GetL (r: vyRanBase.tRandom;      top: LONGINT): LONGINT;
CONST (*a = 16807;	m = 2147483647; 	q = m DIV a;	r = m MOD a; scalefact=1.0D0/m;*)
	m = 2147483647;    (*= = 2^31 -1 *)
BEGIN	 (* better break if top is out of range *)
	IF top <= 0 THEN top := m END;  	(* jb 6.3.01 *)
	Next(r);   	RETURN ((r.seed(vyRanBase.tLongintSeed).val - 1) MOD top)	(* better use higher order bits *)
END GetL;

PROCEDURE Reset (r: vyRanBase.tRandom);  	(* jb 6.3.01 *)
CONST
	m = 2147483647;    (*= = 2^31 -1 *)
VAR
	v: LONGINT;
BEGIN
	v := vyRanBase.DefaultLongSeed ();
	IF v < 0 THEN DEC (v, MIN (LONGINT)) END;
	v := v MOD m;   IF v = 0 THEN v := 1 END;
	r.seed (vyRanBase.tLongintSeed).val := v
END Reset;

PROCEDURE SumPSqr* (gen: vyRanBase.tRandom;   top: LONGINT): LONGREAL;
CONST
	m = 2147483647;    (*= = 2^31 -1 *)
	N = m - 1;
VAR
	k, t: LONGREAL;
BEGIN
	IF (top <= 0) OR (top >= m - 1) THEN RETURN 1 / top END;

	t := N DIV top;
	k := N - t * top;
	RETURN (k * (t + 1) / N + t) / N
END SumPSqr;




(*	jb 23.2.00
(** Creat and initalize a sample instance: Parks& Miller.  **)
PROCEDURE init (r: tRandom);
VAR seed: tSeed;
BEGIN NEW(seed); r.SetSeed(r,seed);  r.seed(tSeed).val := vyRanBase.DefaultLongSeed();
END init;
*)

PROCEDURE HandleAttributes (obj: vyRanBase.tRandom;   VAR M: Objects.AttrMsg);
BEGIN
	IF M.id = Objects.get THEN
		IF M.name = "Gen"THEN
			COPY("vyRanSkeleton.Alloc", M.s);   M.class := Objects.String;   M.res := 0
		ELSIF (M.name = "Value") OR (M.name = "Seed")  THEN
			M.i := obj.seed(vyRanBase.tLongintSeed).val;   M.class := Objects.Int;   M.res := 0
		ELSE
			vyRanBase.Handler(obj, M)
		END
	ELSIF M.id = Objects.set THEN
		IF (M.name = "Value") OR (M.name = "Seed") THEN
			IF M.class = Objects.Int THEN obj.seed(vyRanBase.tLongintSeed).val := M.i;   M.res := 0 END
		ELSE
			vyRanBase.Handler(obj, M)
		END
	ELSIF M.id = Objects.enum THEN
		M.Enum("Seed");   vyRanBase.Handler(obj, M)
	ELSE
		vyRanBase.Handler (obj, M)	(* jb 23.2.00 *)
	END
END HandleAttributes;

PROCEDURE Handler* (obj: Objects.Object;   VAR M: Objects.ObjMsg);
BEGIN
	WITH obj: vyRanBase.tRandom DO
		IF M IS Objects.AttrMsg THEN
			WITH M: Objects.AttrMsg DO
				HandleAttributes(obj, M)
			END
		ELSE
			vyRanBase.Handler(obj, M)
		END
	END;  (*WITH obj:tRandom DO*)
END Handler;

PROCEDURE InitBasic (r: vyRanBase.tRandom);
BEGIN
	r.id := 'PIO v 1.0d1dummy naive Parks&Miller';      r.shortid := 'PMSkel';
	r.seedVersion := vyRanBase.cLongintSeedVersion;

	vyRanBase.SetDefaultProcs (r);

	r.SumPSqr := SumPSqr;
	r.Reset := Reset;
	r.GetRandom := Get;
	r.GetRandomL := GetL;
	r.GetRandomU := GetUniform;
	r.NextRandom := Next;
	r.Max := Max;

	r.handle := Handler;

	r.AllocSeed := vyRanBase.AllocLongintSeed
END InitBasic;

PROCEDURE Init (r: vyRanBase.tRandom);
VAR
	seed: vyRanBase.tLongintSeed;
BEGIN
	InitBasic (r);
	NEW(seed);
	r.SetSeed(r, seed)
END Init;

(* added - jb 29.11.00 *)
PROCEDURE Alloc*;
VAR
	r: vyRanBase.tRandom;
BEGIN
	NEW (r);   InitBasic (r);   Objects.NewObj := r
END Alloc;


PROCEDURE GetNew* (): vyRanBase.tRandom;
VAR
	r: vyRanBase.tRandom;
BEGIN
	NEW (r);
	Init (r);
	r.Reset (r);
	RETURN r
END GetNew;

PROCEDURE New*;
BEGIN
	Objects.NewObj :=  GetNew ()
END New;

PROCEDURE Install*;
BEGIN
	vyRanBase.Install (GetNew ())
END Install;

END vyRanSkeleton.

System.Free  vyRanSkeleton vyRanBase ~

vyRanSkeleton.Install ~
Gadgets.Insert SetFrame vyRanBase.Deposit ~
vyRanBase.NextRandom ~

Gadgets.Insert SetFrame vyRanSkeleton.New ~
Voyager.Random 200 ~
Voyager.Show @ ~
System.Free vyRanBase ~


