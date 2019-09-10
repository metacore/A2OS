MODULE vyRan1 IN Oberon;   (** gs  **)
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


IMPORT SYSTEM, vyRanBase,  (* vyOut,*)  (* for debugging only *) Objects, Files;

	(*= This is an example of a generator with well known deficits. Do NOT use it in simulations. This generator should only be used to demonstrate what not to do. *)

	(* created by gs *)
(* changes:
	jb 11.1.01, 30.11.00 - new vyRanBase, allow to load/store seed
	jb 6.2.00 - new version of vyRanBase
	*)

CONST
	cModuleName = "vyRan1";  idversion* = 'vyRan1 v0r0d01';
	(*! needs proper reset and persistency support for all partial generators and hash table *)
	M1 = 259200;  IA1 = 7141;  IC1 = 54773;  RM1 = (1.0 / M1);  M2 = 134456;  IA2 = 8121;  IC2 = 28411;  RM2 = (1.0 / M2);
	M3 = 243000;  IA3 = 4561;  IC3 = 51349;

TYPE
	Bits = vyRanBase.Bits;

	tRandom = vyRanBase.tRandom;
	tSeed = OBJECT  (* POINTER TO tSeedDesc;
	tSeedDesc = RECORD*)
	(vyRanBase.tLongintSeed);
	VAR ix1, ix2, ix3: SIGNED32;
		r: ARRAY 98 OF FLOAT64;
		iff: SIGNED32;

		PROCEDURE  (*VAR seed: tSeedDesc*) Store*( VAR r: Files.Rider );
		VAR i: SIGNED16;
		BEGIN
			Files.WriteLInt( r, SELF.ix1 );  Files.WriteLInt( r, SELF.ix2 );  Files.WriteLInt( r, SELF.ix3 );
			FOR i := 0 TO 97 DO Files.WriteLReal( r, SELF.r[i] ) END;
			Files.WriteLInt( r, SELF.iff )
		END Store;

		PROCEDURE  (*VAR seed: tSeedDesc*) Load*( VAR r: Files.Rider;  seedVersion: SIGNED16 );
		VAR i: SIGNED16;
		BEGIN
			Files.ReadLInt( r, SELF.ix1 );  Files.ReadLInt( r, SELF.ix2 );  Files.ReadLInt( r, SELF.ix3 );
			FOR i := 0 TO 97 DO Files.ReadLReal( r, SELF.r[i] ) END;
			Files.ReadLInt( r, SELF.iff )
		END Load;

	END tSeed;

	(* added - jb 29.11.00 *)
	PROCEDURE AllocSeed*( ): vyRanBase.tSeed;
	VAR seed: tSeed;
	BEGIN
		NEW( seed );  RETURN seed
	END AllocSeed;

	PROCEDURE Ran1*( s: tSeed ): FLOAT64;
	VAR temp: FLOAT64;  j: SIGNED32;
	BEGIN
		IF (s.val < 0) OR (s.iff = 0) THEN
			s.iff := 1;  s.ix1 := (IC1 - (s.val)) MOD M1;  s.ix1 := (IA1 * s.ix1 + IC1) MOD M1;  s.ix2 := s.ix1 MOD M2;
			s.ix1 := (IA1 * s.ix1 + IC1) MOD M1;  s.ix3 := s.ix1 MOD M3;
			FOR j := 1 TO 97 DO
				s.ix1 := (IA1 * s.ix1 + IC1) MOD M1;  s.ix2 := (IA2 * s.ix2 + IC2) MOD M2;  s.r[j] := (s.ix1 + s.ix2 * RM2) * RM1
			END;
			s.val := 1
		END;
		s.ix1 := (IA1 * s.ix1 + IC1) MOD M1;  s.ix2 := (IA2 * s.ix2 + IC2) MOD M2;  s.ix3 := (IA3 * s.ix3 + IC3) MOD M3;
		j := 1 + ((97 * s.ix3) DIV M3);
		IF (j > 97) OR (j < 1) THEN HALT( 101 ) (* this cannot happen, hihi*) END;
		temp := s.r[j];  s.r[j] := (s.ix1 + s.ix2 * RM2) * RM1;  RETURN temp
	END Ran1;

	PROCEDURE Next*( r: tRandom );
	VAR temp: FLOAT64;
	BEGIN
		temp := Ran1( r.seed( tSeed ) )
	END Next;

	PROCEDURE Max( r: tRandom ): Bits;
	CONST  (*a = 16807;*)  (*q = m DIV a;	r = m MOD a; scalefact=1.0D0/m;*)
	BEGIN
		HALT( 101 )
	END Max;

	PROCEDURE Get( r: tRandom ): Bits;
	VAR temp: FLOAT64;
	BEGIN
		HALT( 103 );  temp := Ran1( r.seed( tSeed ) );  (*RETURN SYSTEM.VAL( Bits, temp )*)
		(* better shift adjust: give preference to higher order bits *)
	END Get;

	PROCEDURE GetUniform( r: tRandom ): FLOAT64;
	CONST  (*a = 16807;*)
	VAR temp: FLOAT64;
	BEGIN
		temp := Ran1( r.seed( tSeed ) );  RETURN temp
	END GetUniform;

	PROCEDURE GetL( r: tRandom;  top: SIGNED32 ): SIGNED32;
	CONST  (*a = 16807;	m = 2147483647; 	q = m DIV a;	r = m MOD a; scalefact=1.0D0/m;*)
	VAR seed: SIGNED32;  temp: FLOAT64;
	BEGIN  (* better break if top is out of range *)
		HALT( 102 );  temp := Ran1( r.seed( tSeed ) );  RETURN ((seed - 1) MOD top)
		(* better use higher order bits *)
	END GetL;

	PROCEDURE Reset( r: tRandom );
	VAR seed: tSeed;
	BEGIN
		NEW( seed );  seed.val := -vyRanBase.DefaultLongSeed();  seed.iff := 0;  r.SetSeed( r, seed )
	END Reset;

	PROCEDURE HandleAttributes( obj: tRandom;  VAR M: Objects.AttrMsg );
	BEGIN
		IF M.id = Objects.get THEN
			IF M.name = "Gen" THEN
				COPY( "vyRan1.Alloc", M.s );   (* jb 28.3.00, 30.11.00 *)
				M.class := Objects.String;  M.res := 0
			ELSIF (M.name = "Value") OR (M.name = "Seed") THEN M.i := obj.seed( tSeed ).val;  M.class := Objects.Int;  M.res := 0
			ELSIF (M.name = "Seed1") THEN M.i := obj.seed( tSeed ).ix1;  M.class := Objects.Int;  M.res := 0
			ELSIF (M.name = "Seed2") THEN M.i := obj.seed( tSeed ).ix2;  M.class := Objects.Int;  M.res := 0
			ELSIF (M.name = "Seed3") THEN M.i := obj.seed( tSeed ).ix3;  M.class := Objects.Int;  M.res := 0
			ELSE vyRanBase.Handler( obj, M )
			END
		ELSIF M.id = Objects.set THEN
			IF (M.name = "Value") OR (M.name = "Seed") THEN
				IF M.class = Objects.Int THEN obj.seed( tSeed ).val := M.i;  M.res := 0 END
			ELSIF (M.name = "Seed1") & (M.class = Objects.Int) THEN obj.seed( tSeed ).ix1 := M.i;  M.res := 0
			ELSIF (M.name = "Seed2") & (M.class = Objects.Int) THEN obj.seed( tSeed ).ix2 := M.i;  M.res := 0
			ELSIF (M.name = "Seed3") & (M.class = Objects.Int) THEN obj.seed( tSeed ).ix3 := M.i;  M.res := 0
			ELSE vyRanBase.Handler( obj, M )
			END
		ELSIF M.id = Objects.enum THEN M.Enum( "Seed1" );  M.Enum( "Seed2" );  M.Enum( "Seed3" );  vyRanBase.Handler( obj, M )
		ELSE
			vyRanBase.Handler( obj, M ) (* jb 28.3.00 *)
		END
	END HandleAttributes;

	(* jb 30.11.00 - no longer needed *)
(*
PROCEDURE Store (obj: tRandom; VAR M: Objects.FileMsg);
VAR i:SIGNED16;
BEGIN
Files.WriteLInt(M.R, obj.seed(tSeed).val);
Files.WriteLInt(M.R, obj.seed(tSeed).ix1);
Files.WriteLInt(M.R, obj.seed(tSeed).ix2);
Files.WriteLInt(M.R, obj.seed(tSeed).ix3);
FOR i:=0 TO 97 DO Files.WriteLReal(M.R,obj.seed(tSeed).r[i]) END;
Files.WriteLInt(M.R, obj.seed(tSeed).iff);
vyRanBase.Handler(obj, M)
END Store;

PROCEDURE Load (obj: tRandom; VAR M: Objects.FileMsg);
VAR i:SIGNED16;
BEGIN
Files.ReadLInt(M.R, obj.seed(tSeed).val);
Files.ReadLInt(M.R, obj.seed(tSeed).ix1);
Files.ReadLInt(M.R, obj.seed(tSeed).ix2);
Files.ReadLInt(M.R, obj.seed(tSeed).ix3);
FOR i:=0 TO 97 DO Files.ReadLReal(M.R,obj.seed(tSeed).r[i]) END;
Files.ReadLInt(M.R, obj.seed(tSeed).iff);
vyRanBase.Handler(obj, M)
END Load;
*)

	PROCEDURE Handler*( obj: Objects.Object;  VAR M: Objects.ObjMsg );   (* jb 28.3.00 *)
	BEGIN
		WITH obj: tRandom DO
			IF M IS Objects.AttrMsg THEN
				WITH M: Objects.AttrMsg DO HandleAttributes( obj, M )
				END;
			ELSE vyRanBase.Handler( obj, M )
			END
		END
	END Handler;

	PROCEDURE InitBasic( r: tRandom );
	BEGIN
		r.id := 'RU Randu v0r0d01';  r.shortid := 'R1';

		vyRanBase.SetDefaultProcs( r );

		r.Reset := Reset;  r.GetRandom := Get;  r.GetRandomL := GetL;  r.GetRandomU := GetUniform;  r.NextRandom := Next;
		r.Max := Max;

		r.handle := Handler;

		r.AllocSeed := AllocSeed
	END InitBasic;

	PROCEDURE Init( r: tRandom );
	VAR seed: tSeed;
	BEGIN
		InitBasic( r );  NEW( seed );  r.SetSeed( r, seed )
	END Init;

	(* jb 28.3.00
PROCEDURE init (r: tRandom);
VAR seed: tSeed;
BEGIN NEW(seed); vyRanBase.FixDefaults(r); seed.val := - vyRanBase.DefaultLongSeed(); seed.iff := 0; r.SetSeed(r, seed);
END init;
*)

(* added - jb 30.11.00 *)
	PROCEDURE Alloc*;
	VAR r: tRandom;
	BEGIN
		NEW( r );  InitBasic( r );  Objects.NewObj := r
	END Alloc;

	PROCEDURE New*;
	VAR r: tRandom;
	BEGIN
		NEW( r );  Init( r );  r.Reset( r );  Objects.NewObj := r
	END New;

	PROCEDURE Install*;
	BEGIN
		New;  vyRanBase.Install( Objects.NewObj( tRandom ) )
	END Install;

END vyRan1.

vyRan1.Install ~
Gadgets.Insert SetFrame vyRan1.New ~
Voyager.Random 100 ~
Voyager.Show @ ~