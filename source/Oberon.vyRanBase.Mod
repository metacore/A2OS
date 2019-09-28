MODULE vyRanBase IN Oberon;
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


(***** Abstract random number generators, and common implementations *****)

(*= This module gives the abstract definition for all random number generators used in Voyager.
It should not depend on other Voyager modules.
It should not assume any specific structure of the generator, nor any specific seed length.
To implement a new basic random number generator, use the module template at the end of
this file.
For more information on random number generators, see
B.D.Ripley: A Short Tutorial on Random Numbers. ISI Reviews (??yyyy??).
See also B.D.Ripley's home page at http://stats.ox.ac.uk
G. Marsaglia: A Current View of Random Number Generators. in: Proceedings of the
16th Symposium on the Interface, Atlanta 1984. Elsevier Press.
G. Marsaglia: Monky Tests for Random Number Generators. Computers & Mathematics
with Applications 9 (1993) 1-10
Both papers are included in the DIEHARD software distribution.
See also G. Marsaglia's home page on http://stat.fso.edu/~geo/
*)

(*! Add explicit range checks *)
 (*? Persistence model may need discussion. Should basic generators be document bound, or should we have system wide random number generators? *)

(* jb 5.5.01 version check when storing random generators *)
(* jb 6.3.01 SumPSqr added, GetRandomLExact added, reset mechanism changed, some constants added *)
(* jb 10.1.01 support for loading/storing seeds added *)
(* jb 27.3.00 return value of GetRandom, MAX and GetRandomBitV is Bits = SIGNED32 now *)
(* jb 21.2.00 major changes *)
(* gs 23.1.98 replace naive Parks&Miller by left-adjusted version. Naive version is kept as example. *)
(* gs 1.6.96 moved from 32 bit SIGNED32 to generic seed *)

IMPORT SYSTEM, Oberon, Objects, Gadgets, Files;

CONST
	cModuleName = "vyRanBase";  idversion* = 'vyRanBase 0.0a7';

	cBaseVersion* = 1;  cLongintSeedVersion* = 0;
	cMagic = "nmfsrg";   (* "New Mechansism For Storing Random Generators" *)

	ccbase = 100;

CONST
	(* system dependent constants, change when necessary *)
	sysBitsTypeSize* = 4;
	sysHalfBitsType* = 10000H;   (* = 2 ^ (SIZEOF(SIGNED32) * 8 / 2) *)
	sysMaskFirstHalf* = SIGNED32(0FFFF0000H);  sysMaskSecondHalf* = 0FFFFH;   (* mask first/second half of a SIGNED32 value *)
	sysMaxUnsigned* = SIGNED32(0FFFFFFFFH);   (* = 2 ^ (SIZEOF(SIGNED32) * 8) - 1 *)
	sysSHL* = 1;  sysSHR* = -1;   (* sign for left/right shift of a SIGNED32 value when using LSH *)

TYPE
	Bits* = SIGNED32;

	(*** The general type used as seed, and for task communcation ***)
	tMsg* = OBJECT
		PROCEDURE (* VAR seed: tSeedDesc*)Store*( VAR r: Files.Rider );
	BEGIN
		HALT( 100 )
	END Store;

	PROCEDURE (* VAR seed: tSeedDesc*)Load*( VAR r: Files.Rider;  seedVersion: SIGNED16 );
	(* if you do not store seeds without storing the whole generator, i. e. if you do not call seed.Store and
	seed.Load yourself, you do not have to worry about seed versions; otherwise the seed version code must be
	stored somewhere in the file and passed to this procedure as parameter seedVersion *)
	BEGIN
		HALT( 100 )
	END Load;
	PROCEDURE (* VAR seed: tSeedDesc*)Copy*( ): tSeed;   (* fof 020625 *)
	BEGIN
		HALT( 100 )
	END Copy;

	END tMsg; (*  POINTER TO tMsgDesc;  *)
	(* tMsgDesc* = RECORD END;  *)
	tSeed* = tMsg;
	(* tSeedDesc* = tMsgDesc; *)   (*= an abstract type is used to allow for various seed types *)
	(*? could this be replaced by a variant of Attribute? *)

	tShortIdStr* = ARRAY 8 OF CHAR;
	tIdStr* = ARRAY 64 OF CHAR;

	(*** The general type for random number generators ***)
	(*= a new random number generator should shield its internal structure,
	but allow as efficient access as possible. The minimum is to supply a SIGNED32 variant
	Random with values in 0..MAX, and a FLOAT64 variant normed to [0,1] *)

	tRandom* = POINTER TO tRandomNumberDesc;
	(*	tRandomFct*=PROCEDURE (gen:tRandom):;*)


	tRandomNumberDesc* = RECORD (Gadgets.ObjDesc)
		seedVersion*: SIGNED16;
		seed-: tSeed;
		(** This information should be supplied to allow identification **)
		shortid*: tShortIdStr;   (*= a short string to identify the generator in synthetic names *)
		id*: tIdStr;   (*= generator id *)

		(** These routines must be supplied for each basic generator **)
		(* Init replaced by Reset - jb 21.2.00 *)
		Reset*: PROCEDURE ( gen: tRandom );   (*= set default seed; reset other things when necessary *)

		(*= Read out functions. Supply best attempts for each generator *)
		GetRandom*: PROCEDURE ( gen: tRandom ): Bits;   (*= A bit pattern within [0, unsigned (MAX)] *)
		GetRandomU*: PROCEDURE ( gen: tRandom ): FLOAT64;   (*= U[0,1] *)
		NextRandom*: PROCEDURE ( gen: tRandom );   (*= advance random number generator. Status is kept in seed *)
		Max*: PROCEDURE ( gen: tRandom ): Bits;   (*= maximum value returned by GetRandom *)

		(*= Read out functions which can be savely kept to defaults. Replace, if this gives a speed advantage *)
		GetRandomBitV*: PROCEDURE ( gen: tRandom;  count: SIGNED32;  VAR nrs: ARRAY OF Bits;  start: SIGNED32 );   (*= A bit pattern *)
		(* jb28.3.00 - replaced by GetRandomBitV
		GetRandomV*: PROCEDURE (gen: tRandom; count: SIGNED32; VAR nrs: ARRAY OF SIGNED32; start: SIGNED32);	(*= A bit pattern, stored as SIGNED32 *)
		*)
		GetRandomUV*: PROCEDURE ( gen: tRandom;  count: SIGNED32;  VAR nrs: ARRAY OF FLOAT32;  start: SIGNED32 );   (*= U[0,1] *)
		GetRandomUVX*: PROCEDURE ( gen: tRandom;  count: SIGNED32;  VAR nrs: ARRAY OF FLOAT64;  start: SIGNED32 );   (*= U[0,1] *)

		(* the following procedures generate a random SIGNED32 within [0; top) *)
		(* if top <= 0 or top > min ( MAX (SIGNED32), unsigned (MAX ()) ), a non-negative random SIGNED32
		within [ 0; min ( MAX (SIGNED32), unsigned (MAX ()) ) ] is returned *)
		(* the results are calculated from a full range random value as "MOD top", so they normally will not be
		uniformly distributed, but the error seems to be very small [to avoid this problem see procedure GetRandomLExact below]
		- value of Herfindahl index as measure of concentration is returned by SumPSqr
		theoretical value of chi square test statistic is then given by unsigned (MAX ()) * (SumPSqr () * top - 1),
		unsigned (MAX ()) - 1 degrees of freedom *)
		(* jb 6.3.01 *)
		SumPSqr*: PROCEDURE ( gen: tRandom;  top: SIGNED32 ): FLOAT64;
		GetRandomL*: PROCEDURE ( gen: tRandom;  top: SIGNED32 ): SIGNED32;
		GetRandomLV*: PROCEDURE ( gen: tRandom;  top: SIGNED32;  count: SIGNED32;  VAR nrs: ARRAY OF SIGNED32;  start: SIGNED32 );

		(* deprecated *)
		GetRandomSet*: PROCEDURE ( gen: tRandom ): SET;
		MAXSet*: PROCEDURE ( gen: tRandom ): SET;

		(*= general purpose hook for extensions *)
		RandomHandler*: PROCEDURE ( r: tRandom;  VAR msg: tMsg );

		AllocSeed*: PROCEDURE ( ): tSeed;   (* jb10.1.01 *)

		(** These routines usually take some default **)
		GetSeed*: PROCEDURE ( gen: tRandom;  VAR s: tSeed );
		SetSeed*: PROCEDURE ( gen: tRandom;  s: tSeed );
		Name*: PROCEDURE ( r: tRandom;  pre: ARRAY OF CHAR;  VAR name: ARRAY OF CHAR );   (* return encoded seed and generator *)
	END;

	(*** Example ***)
	tLongintSeed* = OBJECT (* POINTER TO tLongintSeedDesc;
	tLongintSeedDesc* = RECORD*)   (tSeed)
	VAR
		val*: SIGNED32;

		PROCEDURE  (*VAR seed: tLongintSeedDesc*) Store*( VAR r: Files.Rider );
		BEGIN
			Files.WriteLInt( r, (*seed.*)val )
		END Store;

		PROCEDURE  (*VAR seed: tLongintSeedDesc*) Load*( VAR r: Files.Rider;  seedVersion: SIGNED16 );
		BEGIN
			IF seedVersion # cLongintSeedVersion THEN HALT( 100 ) END;
			Files.ReadLInt( r, (*seed.*)val )
		END Load;

		PROCEDURE  (*VAR seed: tLongintSeedDesc*) Copy*( ): tSeed;   (* fof 020625 *)
		VAR cp: tSeed;  copy: tLongintSeed;
		BEGIN
			cp := AllocLongintSeed();  copy := cp( tLongintSeed );
			copy^ := SELF^ (*seed*);   (* copy of content *)
			RETURN copy
		END Copy;

	END tLongintSeed;
	(*fof val not write-protected for access from outside this module *)

	(*tNameArray*= ARRAY 32 OF CHAR; 	(*= should be same as vyName.tNameArray *)*)

	(*** The global random number generator ***)
VAR
	RandomGenerator-: tRandom;  initSeed1, initSeed2, initSeed3: SIGNED32;

	(*** procedures to load/store seeds - jb 29.11.00 *** *)

	(* must be implemented in derived types  *)

	PROCEDURE WriteSeedVersion*( VAR r: Files.Rider;  seedVersion: SIGNED16 );   (* jb 5.5.01 *)
	BEGIN
		Files.WriteInt( r, seedVersion )
	END WriteSeedVersion;

	(*
	PROCEDURE ( VAR seed: tSeedDesc)Store*( VAR r: Files.Rider );
	BEGIN
		HALT( 100 )
	END Store;
	*)

	PROCEDURE ReadSeedVersion*( VAR r: Files.Rider;  VAR seedVersion: SIGNED16 );   (* jb 5.5.01 *)
	BEGIN
		Files.ReadInt( r, seedVersion )
	END ReadSeedVersion;

	(*
	PROCEDURE ( VAR seed: tSeedDesc)Load*( VAR r: Files.Rider;  seedVersion: SIGNED16 );
	(* if you do not store seeds without storing the whole generator, i. e. if you do not call seed.Store and
	seed.Load yourself, you do not have to worry about seed versions; otherwise the seed version code must be
	stored somewhere in the file and passed to this procedure as parameter seedVersion *)
	BEGIN
		HALT( 100 )
	END Load;

	PROCEDURE ( VAR seed: tSeedDesc)Copy*( ): tSeed;   (* fof 020625 *)
	BEGIN
		HALT( 100 )
	END Copy;
	*)


(*** Access routines ***)

	PROCEDURE RandomBits*( ): Bits;
	(*= return a random number from RandomGenerator *)
	BEGIN
		RETURN RandomGenerator.GetRandom( RandomGenerator )
	END RandomBits;

(* jb 28.3.00 - replaced by RandomBits
PROCEDURE Random* (): SIGNED32;
(*= return a random number from RandomGenerator *)
BEGIN RETURN RandomGenerator.GetRandomL(RandomGenerator, MAX(SIGNED32)) END Random;
*)

	PROCEDURE RandomU*( ): FLOAT64;
	(*= return a random number from RandomGenerator, transformed to U[0,1] *)
	BEGIN
		RETURN RandomGenerator.GetRandomU( RandomGenerator )
	END RandomU;

	PROCEDURE RandomName*( pre: ARRAY OF CHAR;  VAR name: ARRAY OF CHAR );
	(*= prefix and name of currently installed generator *)
	BEGIN
		RandomGenerator.Name( RandomGenerator, pre, name )
	END RandomName;

(** Vector access to current generator **)
	PROCEDURE RandomBitV*( count: SIGNED32;  VAR nrs: ARRAY OF Bits;  start: SIGNED32 );
	BEGIN
		RandomGenerator.GetRandomBitV( RandomGenerator, count, nrs, start )
	END RandomBitV;

(* jb 28.3.00 - replaced by RandomBitV
PROCEDURE RandomV* (count: SIGNED32; VAR nrs: ARRAY OF SIGNED32; start: SIGNED32);
(* VAR i: SIGNED32; *)
BEGIN
(* jb 12.3.00
FOR i := start TO start + count - 1 DO nrs[i] := RandomGenerator.GetRandomL(RandomGenerator, MAX(SIGNED32)) END
*)
RandomGenerator.GetRandomV (RandomGenerator, count, nrs, start)
END RandomV;
*)

	PROCEDURE RandomLV*( top: SIGNED32;  exact: BOOLEAN;  count: SIGNED32;  VAR nrs: ARRAY OF SIGNED32;  start: SIGNED32 );
	(* VAR i: SIGNED32; *)
	BEGIN
		(* jb 12.3.00
	FOR i := start TO start + count - 1 DO nrs[i] := RandomGenerator.GetRandomL(RandomGenerator, top) END
	*)
		RandomGenerator.GetRandomLV( RandomGenerator, top, count, nrs, start )
	END RandomLV;

	PROCEDURE RandomUV*( count: SIGNED32;  VAR nrs: ARRAY OF FLOAT32;  start: SIGNED32 );
	(* VAR i: SIGNED32; *)
	BEGIN
		(* jb 12.3.00
	FOR i := start TO start + count - 1 DO nrs[i] := SHORT(RandomGenerator.GetRandomU(RandomGenerator)) END
	*)
		RandomGenerator.GetRandomUV( RandomGenerator, count, nrs, start )
	END RandomUV;

	PROCEDURE RandomUVX*( count: SIGNED32;  VAR nrs: ARRAY OF FLOAT64;  start: SIGNED32 );
	(* VAR i: SIGNED32; *)
	BEGIN
		(* jb 12.3.00
	FOR i := start TO start + count - 1 DO nrs[i] := RandomGenerator.GetRandomU(RandomGenerator) END
	*)
		RandomGenerator.GetRandomUVX( RandomGenerator, count, nrs, start )
	END RandomUVX;



(* auxiliary procedures *)

	PROCEDURE GetRandomLExact*( gen: tRandom;  max, top, maxtries: SIGNED32 ): SIGNED32;
	(*= get a random value which is (theoretically) uniformly distributed within [0, top)

	pass the result of gen.MAX (gen) as parameter max

	full range of possible random values 0..max is divided into a maxium number of intervals
	of length top, then a random value is drawn; if it falls into one of these intervals
	a random value within [0, top) returned, according to the position of the random number in the
	interval, if not, another random number is drawn; if we were not successful within maxtries times, -1
	is returned
	*)
	VAR m1, m2, m3, max1, max2, max3, c, nTry, z: SIGNED32;
	BEGIN
		IF max < 0 THEN max2 := max1 - MIN( SIGNED32 );  max1 := MAX( SIGNED32 ) ELSE max2 := -1;  max1 := max END;
		c := max1 MOD top + 1;
		IF c = top THEN m1 := max1 ELSE m1 := max1 - c END;
		ASSERT ( (-1) MOD 3 = 2, 100 );   (* the cases max2 = -1 and max3 = -1
	must be handled separately when setting m2 and m3 *)
		IF max2 < 0 THEN
			c := -((-max2) MOD top) + 1;
		ELSE
			c := max2 MOD top + 1;
		END; 
		IF c = top THEN m2 := max2 ELSE m2 := max2 - c END;
		max3 := max1 - m1 + max2 - m2 - 1;  
		IF max3 < 0 THEN
			c := -((-max3) MOD top) + 1;
		ELSE
			c := max3 MOD top + 1;
		END; 
		IF c = top THEN m3 := max3 ELSE m3 := max3 - c END;

		nTry := 1;
		LOOP
			z := gen.GetRandom( gen );
			IF z >= 0 THEN
				IF z <= m1 THEN RETURN z MOD top END;
				z := z - m1 - 1
			ELSE
				DEC( z, MIN( SIGNED32 ) );
				IF z <= m2 THEN RETURN z MOD top END;
				z := z - m2 - 1 + max1 - m1
			END;

			IF z <= m3 THEN RETURN z MOD top
			END;

			IF nTry = maxtries THEN RETURN -1
			END;
			INC( nTry )
		END
	END GetRandomLExact;



	(* default routines which are set by SetDefaultProcs *)

(** These are the default routines for vector oriented usage **)

	PROCEDURE DefaultRandomBitV*( gen: tRandom;  count: SIGNED32;  VAR nrs: ARRAY OF Bits;  start: SIGNED32 );
	VAR i: SIGNED32;
	BEGIN
		FOR i := start TO start + count - 1 DO nrs[i] := gen.GetRandom( gen ) END
	END DefaultRandomBitV;

	(* jb 28.3.00 *)
(*
PROCEDURE DefaultRandomV* (gen: tRandom; count: SIGNED32; VAR nrs: ARRAY OF SIGNED32; start: SIGNED32);
VAR i: SIGNED32;
BEGIN
FOR i := start TO start + count - 1 DO nrs[i] := gen.GetRandomL(gen, MAX(SIGNED32)) END
END DefaultRandomV;
*)

	PROCEDURE DefaultRandomLV*( gen: tRandom;  top: SIGNED32;  count: SIGNED32;  VAR nrs: ARRAY OF SIGNED32;  start: SIGNED32 );
	VAR i: SIGNED32;
	BEGIN
		FOR i := start TO start + count - 1 DO nrs[i] := gen.GetRandomL( gen, top ) END
	END DefaultRandomLV;

	PROCEDURE DefaultRandomUV*( gen: tRandom;  count: SIGNED32;  VAR nrs: ARRAY OF FLOAT32;  start: SIGNED32 );
	VAR i: SIGNED32;
	BEGIN
		FOR i := start TO start + count - 1 DO nrs[i] := SHORT( gen.GetRandomU( gen ) ) END
	END DefaultRandomUV;

	PROCEDURE DefaultRandomUVX*( gen: tRandom;  count: SIGNED32;  VAR nrs: ARRAY OF FLOAT64;  start: SIGNED32 );
	VAR i: SIGNED32;
	BEGIN
		FOR i := start TO start + count - 1 DO nrs[i] := gen.GetRandomU( gen ) END
	END DefaultRandomUVX;

(* default routines which return SET, jb 28.3.00*)

	PROCEDURE DefaultGetSet*( gen: tRandom ): SET;
	BEGIN
		RETURN SYSTEM.VAL( SET, gen.GetRandom( gen ) )
	END DefaultGetSet;

	PROCEDURE DefaultMAXSet*( gen: tRandom ): SET;
	BEGIN
		RETURN SYSTEM.VAL( SET, gen.Max( gen ) )
	END DefaultMAXSet;

	PROCEDURE GetSeed( r: tRandom;  VAR s: tSeed );
	BEGIN
		s := r.seed
	END GetSeed;

	PROCEDURE SetSeed( r: tRandom;  s: tSeed );
	BEGIN
		r.seed := s
	END SetSeed;

	PROCEDURE DefaultName( r: tRandom;  pre: ARRAY OF CHAR;  VAR name: ARRAY OF CHAR );
	VAR i, j: SIGNED32;  x, y: SIGNED32;
	BEGIN
		j := 0;
		(*	vyHostTexts.MsgSS('shortid:',r.shortid);vyHostTexts.MsgSS(' pre:',pre);vyHostTexts.MsgSS(' name:',name); *)
		i := 0;
		WHILE pre[i] # 0X DO name[j] := pre[i];  INC( i );  INC( j ) END;
		i := 0;
		WHILE r.shortid[i] # 0X DO name[j] := r.shortid[i];  INC( i );  INC( j ) END;
		name[j] := 0X;
		(*>*	vyHostStrings.AppendHex(r.seed,name); -- expanded to avoid dependeny on Strings *)
		x := r.seed( tLongintSeed ).val;  i := j;  j := j + 8;  name[j] := 0X;
		REPEAT
			DEC( j );  y := x MOD 10H;
			IF y < 10 THEN name[j] := CHR( y + 30H ) ELSE name[j] := CHR( y + 37H ) END;
			x := x DIV 10H
		UNTIL j = i;
		(*<*	vyHostStrings.AppendHex(r.seed,name); -- expanded to avoid dependeny on Strings *)

		(*		vyHostTexts.MsgSS('shortid:',r.shortid);vyHostTexts.MsgSS(' pre:',pre);vyHostTexts.MsgSS(' name:',name); *)
	END DefaultName;

	PROCEDURE HandleAttributes( obj: tRandom;  VAR M: Objects.AttrMsg );
	BEGIN
		IF M.id = Objects.get THEN
			IF M.name = "ShortClass" THEN COPY( obj.shortid, M.s );  M.class := Objects.String;  M.res := 0
			ELSIF M.name = "Class" THEN COPY( obj.id, M.s );  M.class := Objects.String;  M.res := 0
			ELSE Gadgets.objecthandle( obj, M )
			END
			(*	ELSIF M.id = Objects.set THEN
		IF (M.name = "Value") OR (M.name="Seed") THEN
		IF M.class = Objects.Int THEN obj.seed(tSeed).val:= M.i; M.res := 0 END
		ELSE Gadgets.objecthandle(obj,M)
		END
		*)
		ELSIF M.id = Objects.enum THEN M.Enum( "ShortClass" );  M.Enum( "Class" );  Gadgets.objecthandle( obj, M )
		ELSE Gadgets.objecthandle( obj, M )
		END
	END HandleAttributes;

	PROCEDURE StoreVersionInformation( VAR r: Files.Rider;  shortid: tShortIdStr;  seedVersion: SIGNED16 );
	BEGIN
		Files.WriteString( r, cMagic );  Files.WriteString( r, shortid );  Files.WriteInt( r, cBaseVersion );
		Files.WriteInt( r, seedVersion )
	END StoreVersionInformation;

	PROCEDURE LoadVersionInformation( VAR r: Files.Rider;  VAR shortid: tShortIdStr;  VAR baseVersion, seedVersion: SIGNED16 );
	VAR dummy: tIdStr;
	BEGIN
		Files.ReadString( r, shortid );
		IF shortid = cMagic THEN Files.ReadString( r, shortid );  Files.ReadInt( r, baseVersion );  Files.ReadInt( r, seedVersion )
				ELSE  (* for compatibility with older versions of vyRanBase *)
			baseVersion := 0;  seedVersion := 0;
			Files.ReadString( r, dummy ) (* obj.id - no longer stored *)
		END
	END LoadVersionInformation;

(*
PROCEDURE Store (obj: tRandom; VAR M: Objects.FileMsg);
BEGIN
Files.WriteString(M.R,obj.shortid);
Files.WriteString(M.R,obj.id);
obj.seed.Store (M.R);
Gadgets.objecthandle(obj, M)
END Store;
*)

	PROCEDURE Store( obj: tRandom;  VAR M: Objects.FileMsg );
	BEGIN
		StoreVersionInformation( M.R, obj.shortid, obj.seedVersion );  obj.seed.Store( M.R );  Gadgets.objecthandle( obj, M )
	END Store;

	PROCEDURE Load( obj: tRandom;  VAR M: Objects.FileMsg );
	VAR shortid: tShortIdStr;  baseVersion, seedVersion: SIGNED16;  seed: tSeed;
	BEGIN
		LoadVersionInformation( M.R, shortid, baseVersion, seedVersion );
		IF shortid # obj.shortid THEN HALT( 100 ) END;
		IF (baseVersion < 0) OR (baseVersion > 1) THEN HALT( 101 ) END;
		seed := obj.AllocSeed();  seed.Load( M.R, seedVersion );  obj.seed := seed;  Gadgets.objecthandle( obj, M )
	END Load;

	PROCEDURE Handler*( obj: Objects.Object;  VAR M: Objects.ObjMsg );
	BEGIN
		WITH obj: tRandom DO
			IF M IS Objects.AttrMsg THEN
				WITH M: Objects.AttrMsg DO HandleAttributes( obj, M )
				END
			ELSIF M IS Objects.FileMsg THEN
				WITH M: Objects.FileMsg DO
					IF M.id = Objects.store THEN Store( obj, M )
					ELSIF M.id = Objects.load THEN Load( obj, M )
					END
				END

			ELSE Gadgets.objecthandle( obj, M )
			END
		END;   (*WITH obj:tRandom DO*)

	END Handler;

	PROCEDURE SetDefaultProcs*( gen: tRandom );   (* changed, jb 21.2.00 *)
	(*= install default access routines in random number generator
	call this first before installing your own procedures *)
	BEGIN
		gen.GetRandomBitV := DefaultRandomBitV;
		(* gen.GetRandomV := DefaultRandomV; *)  (* jb 28.3.00 *)
		gen.GetRandomLV := DefaultRandomLV;  gen.GetRandomUV := DefaultRandomUV;
		gen.GetRandomUVX := DefaultRandomUVX;

		gen.GetRandomSet := DefaultGetSet;  gen.MAXSet := DefaultMAXSet;

		gen.RandomHandler := NIL;

		gen.GetSeed := GetSeed;  gen.SetSeed := SetSeed;  gen.Name := DefaultName;

		gen.handle := Handler
	END SetDefaultProcs;


	(** Default implementations not set by SetDefaultProcs **)

(* jb 2.3.01 - Reset mechanism changed *)
	PROCEDURE Combo( VAR x, y, z: SIGNED32 ): SIGNED32;
	(*= One step of Combo random number generator. *)
	(*! only for DefaultLongSeed, Combo implemented in own Module vyRanCombo.Mod *)
	CONST mwcParam = 30903;
	VAR v: SIGNED32;
	BEGIN
		v := x * y;  x := y;  y := v;
		z :=
			mwcParam * Bits(SET(z ) * SET(sysMaskSecondHalf ) ) +
			LSH( z, sysBitsTypeSize DIV 2 * sysSHR );
		RETURN y + z
	END Combo;

	PROCEDURE SetInitSeeds;
	VAR res: INTEGER;  i: SIGNED16;
	BEGIN
		initSeed1 := Oberon.Time();  Oberon.GetClock( initSeed2, initSeed3 );
		FOR i := 1 TO 10 DO res := Combo( initSeed1, initSeed2, initSeed3 ) END
	END SetInitSeeds;

	PROCEDURE DefaultLongSeed*( ): SIGNED32;
	(*= return a seed, to be used with the Init procedure of the random number generator
	!!! use with care - this procedure gives a full SIGNED32, which may be negative or zero !!! *)
	BEGIN
		RETURN Combo( initSeed1, initSeed2, initSeed3 )
	END DefaultLongSeed;

	PROCEDURE DefaultLongintReset*( gen: tRandom );   (* jb 21.2.00 *)
	(* !!! use with care - this procedure gives a full SIGNED32, which may be negative or zero !!!
	if something different is needed, you have to create your one Reset procedure *)
	VAR seed: tSeed;
	BEGIN
		seed := gen.seed;
		WITH seed: tLongintSeed DO seed.val := DefaultLongSeed()
		END
	END DefaultLongintReset;

	PROCEDURE DefaultSumPSqr*( gen: tRandom;  top: SIGNED32 ): FLOAT64;
	(* default procedure if MAX () = sysMaxUnsigned *)
	CONST N = MAX( SIGNED32 );
	VAR k, t: FLOAT64;
	BEGIN
		IF top <= 0 THEN RETURN 1 / top END;

		t := N DIV top;  k := N - t * top;  RETURN (k * (t + 1) / N + t) / N
	END DefaultSumPSqr;




(* added - jb 29.11.00, changed - jb 10.1.01 *)
	PROCEDURE AllocLongintSeed*( ): tSeed;
	VAR seed: tLongintSeed;
	BEGIN
		NEW( seed );  RETURN seed
	END AllocLongintSeed;

(*
	PROCEDURE ( VAR seed: tLongintSeedDesc)Store*( VAR r: Files.Rider );
	BEGIN
		Files.WriteLInt( r, seed.val )
	END Store;

	PROCEDURE ( VAR seed: tLongintSeedDesc)Load*( VAR r: Files.Rider;  seedVersion: SIGNED16 );
	BEGIN
		IF seedVersion # cLongintSeedVersion THEN HALT( 100 ) END;
		Files.ReadLInt( r, seed.val )
	END Load;

	PROCEDURE ( VAR seed: tLongintSeedDesc)Copy*( ): tSeed;   (* fof 020625 *)
	VAR cp: tSeed;  copy: tLongintSeed;
	BEGIN
		cp := AllocLongintSeed();  copy := cp( tLongintSeed );
		copy^ := seed;   (* copy of content *)
		RETURN copy
	END Copy;
*)

	(* probably not necessary - jb 21.2.00 *)

(*

PROCEDURE FixDefaults* (generator: tRandom);
BEGIN
IF generator.GetRandomBitV = NIL THEN generator.GetRandomBitV := DefaultRandomBitV END;
IF generator.GetRandomV = NIL THEN generator.GetRandomV := DefaultRandomV END;
IF generator.GetRandomLV = NIL THEN generator.GetRandomLV := DefaultRandomLV END;
IF generator.GetRandomUV = NIL THEN generator.GetRandomUV := DefaultRandomUV END;
IF generator.GetRandomUVX = NIL THEN generator.GetRandomUVX := DefaultRandomUVX END;
IF generator.Name = NIL THEN generator.Name := DefaultName END;
IF generator.SetSeed = NIL THEN generator.SetSeed := SetSeed END;
IF generator.GetSeed = NIL THEN generator.GetSeed := GetSeed END
END FixDefaults;

*)

	PROCEDURE Install*( generator: tRandom );
	BEGIN
		ASSERT ( generator # NIL , 100 );
		(*! find a mechanism to check if generator has been inited *)
		(* ASSERT(generator.Init # NIL, 101); *)
		(* not needed - jb 21.2.00
	IF generator.GetRandomBitV = NIL THEN generator.GetRandomBitV := DefaultRandomBitV END;
	IF generator.GetRandomV = NIL THEN generator.GetRandomV := DefaultRandomV END;
	IF generator.GetRandomUV = NIL THEN generator.GetRandomUV := DefaultRandomUV END;
	IF generator.GetRandomUVX = NIL THEN generator.GetRandomUVX := DefaultRandomUVX END;
	IF generator.Name = NIL THEN generator.Name := DefaultName END;
	generator.SetSeed := SetSeed;
	generator.GetSeed := GetSeed;
	*)
		RandomGenerator := generator;   (* RandomGenerator.Init(RandomGenerator) *)
		(* RandomGenerator.Reset (RandomGenerator) *)
	END Install;

(* No Gen procedure for abstract generator *)
	PROCEDURE NewAbstractGenerator;
	BEGIN
		HALT( ccbase )
	END NewAbstractGenerator;

	PROCEDURE Deposit*;
	(*= Copy RandomGenerator to Objects.New, to allow access from Gadgets system *)
	BEGIN
		Objects.NewObj := RandomGenerator
	END Deposit;

	PROCEDURE NextRandom*;
	BEGIN
		IF RandomGenerator # NIL THEN
			RandomGenerator.NextRandom( RandomGenerator );  Gadgets.Update( RandomGenerator )
		END
	END NextRandom;

	PROCEDURE DoAsserts;
	VAR tmp: Bits;
	BEGIN
		ASSERT ( SIZEOF( SIGNED32 ) = sysBitsTypeSize, 100 );   (* jb 28.3.00 *)
		ASSERT ( sysMaxUnsigned = -1, 101 );   (* jb 10.1.01 *)
		ASSERT ( sysHalfBitsType = LSH( 80000000H, -((sysBitsTypeSize * 8) DIV 2) + 1 ), 102 );   (* jb 10.1.01 *)
		tmp := 1;
		ASSERT ( LSH( tmp, sysSHL ) = 2, 103 );   (* jb 2.3.01 *)
		tmp := -1;
		ASSERT ( LSH( tmp, sysSHR ) > 0, 104 );   (* jb 2.3.01 - assert shift is unsigned *)
		ASSERT ( SIZEOF( SET ) = SIZEOF( SIGNED32 ), 105 )
	END DoAsserts;

BEGIN
	DoAsserts;  RandomGenerator := NIL;
	SetInitSeeds (* jb 2.3.01 *)
END vyRanBase.


call these only after a random number generator has been installed, for example
vyRanSkeleton.Install ~

Gadgets.Insert SetFrame vyRanBase.Deposit ~
vyRanBase.NextRandom ~
