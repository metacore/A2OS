MODULE vyRanParksMiller IN Oberon;
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
(* this module may be used as a sample implementation of new random number generators *)

(*! Add explicit range checks *)

(* jb 5.5.01 by Johannes Becker - procedure ParksMiller inlined, GetV added, support for seed version check added *)
(* jb 7.3.01 by Johannes Becker - Reset added, SumPSqr, GetNew added *)
(* jb 11.1.01, 30.11.00 by Johannes Becker - changes in vyRanBase, allow to load/store seeds *)
(* jb 30.3.00 by Johannes Becker - new version of vyRanBase *)

IMPORT vyRanBase, Objects;

CONST
	idversion* = 'vyRanParksMiller 0.0a5';

	a = 16807;   (*=  = 7^5 *)
	m = 2147483647;   (*= = 2^31 -1 *)
	q = m DIV a;  r = m MOD a;

TYPE
	Bits = vyRanBase.Bits;
	tRandom = vyRanBase.tRandom;

VAR
	(* usedval: SIGNED32;   infosaved: BOOLEAN;  (* infosaved is indicator if seed of RandomBase has beenm saved *) *)



	(** Sample implementation:  Portable random number generator - Parks and Miller,
	but using naive read-out functions *)

PROCEDURE ParksMiller* (VAR s: SIGNED32);
	(*= One step of Parks & Miller portable random number generator.
	This is considered the minimal standard random number generator. *)
BEGIN
	s := a * (s MOD q) - r * (s DIV q);
	IF s < 0 THEN s := s + m END (* Parks & Miller *)
END ParksMiller;

PROCEDURE Next* (r: tRandom);
BEGIN ParksMiller(r.seed(vyRanBase.tLongintSeed).val) END Next;

PROCEDURE Max (r: tRandom): Bits;
BEGIN RETURN m - 1 END Max;

PROCEDURE Get (gen: tRandom): Bits;
VAR
	s: SIGNED32;
BEGIN
	s := gen.seed(vyRanBase.tLongintSeed).val;

	s := a * (s MOD q) - r * (s DIV q);
	IF s < 0 THEN s := s + m END;  (* Parks & Miller *)

	gen.seed(vyRanBase.tLongintSeed).val := s;
	RETURN s
	(* better shift adjust: give preference to higher order bits *)
END Get;

PROCEDURE GetV (gen: tRandom;  count: SIGNED32;  VAR nrs: ARRAY OF Bits;  start: SIGNED32);
VAR
	s: SIGNED32;  i: SIGNED32;
BEGIN
	s := gen.seed(vyRanBase.tLongintSeed).val;
	FOR i := start TO start + count - 1 DO
		s := a * (s MOD q) - r * (s DIV q);
		IF s < 0 THEN s := s + m END;  (* Parks & Miller *)

		nrs [i] := s
	END;
	gen.seed (vyRanBase.tLongintSeed).val := s
	(* better shift adjust: give preference to higher order bits *)
END GetV;

PROCEDURE GetUniform (gen: tRandom): FLOAT64;
CONST
	scalefact = 1.0D0 / m;
VAR
	s: SIGNED32;
BEGIN
	s := gen.seed(vyRanBase.tLongintSeed).val;

	s := a * (s MOD q) - r * (s DIV q);
	IF s < 0 THEN s := s + m END;  (* Parks & Miller *)

	gen.seed(vyRanBase.tLongintSeed).val := s;
	RETURN s * scalefact
END GetUniform;

PROCEDURE RandomUVX (gen: tRandom;  count: SIGNED32;  VAR nrs: ARRAY OF FLOAT64;  start: SIGNED32);
CONST
	scalefact = 1.0D0 / m;
VAR
	s: SIGNED32;  i: SIGNED32;
BEGIN
	s := gen.seed(vyRanBase.tLongintSeed).val;
	FOR i := start TO start + count - 1 DO
		s := a * (s MOD q) - r * (s DIV q);
		IF s < 0 THEN s := s + m END;  (* Parks & Miller *)

		nrs[i] := s * scalefact
	END;
	gen.seed(vyRanBase.tLongintSeed).val := s
END RandomUVX;

PROCEDURE RandomUV (gen: tRandom;  count: SIGNED32;  VAR nrs: ARRAY OF FLOAT32;  start: SIGNED32);
CONST
	scalefact = 1.0D0 / m;
VAR
	s: SIGNED32;  i: SIGNED32;
BEGIN
	s := gen.seed(vyRanBase.tLongintSeed).val;
	FOR i := start TO start + count - 1 DO
		s := a * (s MOD q) - r * (s DIV q);
		IF s < 0 THEN s := s + m END;  (* Parks & Miller *)

		nrs[i] := SHORT (s * scalefact)
	END;
	gen.seed (vyRanBase.tLongintSeed).val := s
END RandomUV;

PROCEDURE GetL (gen: tRandom;     top: SIGNED32): SIGNED32;
VAR
	s: SIGNED32;
BEGIN	 (* better break if top is out of range *)
	IF top <= 0 THEN top := m END; 	(* jb 6.3.01 *)
	s := gen.seed(vyRanBase.tLongintSeed).val;

	s := a * (s MOD q) - r * (s DIV q);
	IF s < 0 THEN s := s + m END;  (* Parks & Miller *)

	gen.seed(vyRanBase.tLongintSeed).val := s;
	RETURN ((s - 1) MOD top)
	(* better use higher order bits *)
END GetL;

PROCEDURE RandomLV (r: tRandom;  top, count: SIGNED32;  VAR nrs: ARRAY OF SIGNED32;  start: SIGNED32);
CONST (*a = 16807;*)	(*q = m DIV a;	r = m MOD a; *)
	VAR seed: SIGNED32;  i: SIGNED32;
BEGIN
	seed := r.seed(vyRanBase.tLongintSeed).val;
	FOR i := start TO start + count - 1 DO
		ParksMiller(seed);
		nrs[i] := ((seed - 1) MOD top)
	END;
	r.seed(vyRanBase.tLongintSeed).val := seed

END RandomLV;


PROCEDURE Reset (r: tRandom); 	(* jb 6.3.01 *)
VAR
	v: SIGNED32;
BEGIN
	v := vyRanBase.DefaultLongSeed ();
	IF v < 0 THEN DEC (v, MIN (SIGNED32)) END;
	v := v MOD m;  IF v = 0 THEN v := 1 END;
	r.seed (vyRanBase.tLongintSeed).val := v
END Reset;

PROCEDURE SumPSqr* (gen: tRandom;  top: SIGNED32): FLOAT64;
CONST
	N = m - 1;
VAR
	k, t: FLOAT64;
BEGIN
	IF (top <= 0) OR (top >= m - 1) THEN RETURN 1 / top END;

	t := N DIV top;
	k := N - t * top;
	RETURN (k * (t + 1) / N + t) / N
END SumPSqr;



(** Creat and initalize a sample instance: Parks& Miller.  **)
(*
PROCEDURE init (r: tRandom);
VAR seed: vyRanBase.tLongintSeed;
BEGIN NEW(seed);  r.SetSeed(r, seed);  r.seed(vyRanBase.tLongintSeed).val := vyRanBase.DefaultLongSeed()
END init;
*)

(*
PROCEDURE TestInit (r: tRandom);
VAR seed: vyRanBase.tLongintSeed;
BEGIN
NEW(seed); r.SetSeed(r,seed); r.seed(vyRanBase.tLongintSeed).val := usedval
END TestInit;
*)
PROCEDURE HandleAttributes (obj: tRandom;  VAR M: Objects.AttrMsg);
BEGIN
	IF M.id = Objects.get THEN
		IF M.name = "Gen"THEN COPY("vyRanParksMiller.Alloc", M.s);  M.class := Objects.String;  M.res := 0
		ELSIF (M.name = "Value") OR (M.name = "Seed")
			THEN M.i := obj.seed(vyRanBase.tLongintSeed).val;  M.class := Objects.Int;  M.res := 0
		ELSE vyRanBase.Handler(obj, M)
		END
	ELSIF M.id = Objects.set THEN
		IF (M.name = "Value") OR (M.name = "Seed") THEN
			IF M.class = Objects.Int THEN obj.seed(vyRanBase.tLongintSeed).val := M.i;  M.res := 0 END
		ELSE vyRanBase.Handler(obj, M)
		END
	ELSIF M.id = Objects.enum THEN
		M.Enum("Seed");  vyRanBase.Handler(obj, M)
	END
END HandleAttributes;

PROCEDURE Handler* (obj: Objects.Object;  VAR M: Objects.ObjMsg);
BEGIN
	WITH obj: tRandom DO
		IF M IS Objects.AttrMsg THEN
			WITH M: Objects.AttrMsg DO
				HandleAttributes(obj, M)
			END
		ELSE
			vyRanBase.Handler(obj, M)
		END
	END; (*WITH obj:tRandom DO*)
END Handler;

PROCEDURE InitBasic (r: tRandom);
BEGIN
	r.id := 'PIO v 1.0d1dummy naive Parks&Miller';     r.shortid := 'PM';
	r.seedVersion := vyRanBase.cLongintSeedVersion;

	vyRanBase.SetDefaultProcs (r);

	r.SumPSqr := SumPSqr;
	r.Reset := Reset;
	r.GetRandom := Get;
	r.GetRandomL := GetL;
	r.GetRandomU := GetUniform;

	r.GetRandomBitV := GetV;
	r.GetRandomUVX := RandomUVX;
	r.GetRandomUV := RandomUV;
	r.GetRandomLV := RandomLV;


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

	NEW(seed);
	r.SetSeed(r, seed)
END Init;

(* added - jb 30.11.00 *)
PROCEDURE Alloc*;
VAR
	r: tRandom;
BEGIN
	NEW (r);  InitBasic (r);  Objects.NewObj := r
END Alloc;


PROCEDURE GetNew* (): tRandom;
VAR
	r: tRandom;
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

(* for debugging:
PROCEDURE SaveInfo*;
BEGIN
usedval := vyRanBase.RandomGenerator.seed(vyRanBase.tLongintSeed).val;   infosaved := TRUE;
END SaveInfo;
*)

(* BEGIN	infosaved := FALSE;  *)
END vyRanParksMiller.

System.Free  vyRanParksMiller vyRanBase ~

vyRanParksParksMiller.Install ~

Voyager.Random 200 ~
Voyager.Show @ ~
