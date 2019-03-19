MODULE vyRanMWC IN Oberon;
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


(*= 32 bit multiply with carry generator,
based on a Fortran algorithm from the "Diehard" package by G. Marsaglia
*)
(* created: 12.3.00 by Johannes Becker *)
(* changes:
5.5.01 by Johanees Becker - MOD in LongMultAdd replaced by SYSTEM procedures
support for seed version check added
7.3.01 by Johannes Becker - GetNew added
10.1.01 by Johannes Becker - some optimizations
30.11.00 by Johannes Becker - allow to load/store seed
28.3.00 by Johannes Becker - new version of vyRanBase
*)

IMPORT S := SYSTEM, Objects, Files, vyRanBase;

CONST
	cModuleName = "vyRanMWC";  cSeedVersion = 0;

	stdSeedA = 1791398085;   (*? probably there is a better one *)

	sysSHR = vyRanBase.sysSHR;

TYPE
	tSeed = OBJECT  (* POINTER TO tSeedDesc;
	tSeedDesc = RECORD (vyRanBase.tSeedDesc) *)
	(vyRanBase.tSeed)
	VAR x, c: LONGINT;
		a: LONGINT;
		checkPeriod: BOOLEAN;

		PROCEDURE  (*VAR seed: tSeedDesc*) Store*( VAR r: Files.Rider );
		BEGIN
			Files.WriteLInt( r, SELF.x );  Files.WriteLInt( r, SELF.c );  Files.WriteLInt( r, SELF.a )
		END Store;

		PROCEDURE  (*VAR seed: tSeedDesc*) Load*( VAR r: Files.Rider;  seedVersion: INTEGER );
		BEGIN
			IF seedVersion # cSeedVersion THEN HALT( 100 ) END;
			Files.ReadLInt( r, SELF.x );  Files.ReadLInt( r, SELF.c );  Files.ReadLInt( r, SELF.a )
		END Load;

	END tSeed;

	tRandom = vyRanBase.tRandom;  Bits = vyRanBase.Bits;

VAR
	seedA: LONGINT;  seedCheckPeriod: BOOLEAN;  useParam: BOOLEAN;


	(* added - jb 29.11.00 *)
	PROCEDURE AllocSeed*( ): vyRanBase.tSeed;
	VAR seed: tSeed;
	BEGIN
		NEW( seed );  RETURN seed
	END AllocSeed;

	(*
PROCEDURE (VAR seed: tSeedDesc) GetGenProc* (VAR MName, PName: ARRAY OF CHAR);
BEGIN
COPY (cModuleName, MName); COPY ("AllocSeed", PName)
END GetGenProc;
*)


(*
(* unsigned comparison - copied from module Mac.Crypt.Mod *)
PROCEDURE Less* (x, y: LONGINT): BOOLEAN;
VAR
a, b: LONGINT;
BEGIN
a := LSH(x, - 1);    b := LSH(y, - 1);
IF a - b = 0 THEN RETURN x MOD 2 < y MOD 2 ELSE RETURN a < b END
END Less;

(* multiplication - copied from module Mac.Crypt.Mod *)
PROCEDURE LongMult* (VAR high, low: LONGINT;    b, c: LONGINT);
(* high | low := b * c *)
VAR
bh, bl, ch, cl, u, t: LONGINT;
BEGIN
bh := LSH(b, - 16);    bl := b MOD 10000H;
ch := LSH(c, - 16);    cl := c MOD 10000H;

low := bl * cl;    t := ch * bl;    u := cl * bh;    high := bh * ch;

INC(t, u);    IF Less(t, u) THEN INC(high, 10000H) END;
u := t * 10000H;
INC(low, u);    IF Less(low, u) THEN INC(high) END;
INC(high, LSH(t, - 16))
END LongMult;

PROCEDURE LongInc* (VAR high, low: LONGINT;    c: LONGINT);
(* INC (high / low, c) *)
VAR
tmp: LONGINT;
BEGIN
tmp := low;
INC (low, c);    IF Less (low, tmp) THEN INC (high) END
END LongInc;
*)

	PROCEDURE LongMultAdd*( VAR high, low: LONGINT;  a, b, c: LONGINT );
	(* high / low := a * b + c *)
	(* see procedures LongMult and LongInc in module Mac.Crypt.Mod, most of the following
	is simply copied from there *)
	VAR ah, al, bh, bl, t, u, tmp, r: LONGINT;
	BEGIN
		ah := LSH( a, sysSHR * 16 );  al := S.VAL( LONGINT, S.VAL( SET, a ) * S.VAL( SET, vyRanBase.sysMaxUnsigned ) );
		bh := LSH( b, sysSHR * 16 );  bl := S.VAL( LONGINT, S.VAL( SET, b ) * S.VAL( SET, vyRanBase.sysMaxUnsigned ) );

		low := al * bl;  t := ah * bl;  u := al * bh;  high := ah * bh;

		INC( t, u );
		(* IF unsigned (t) < unsigned (u) THEN INC (high, 10000H) END *)
		r := LSH( t, -1 ) - LSH( u, -1 );
		IF ((r = 0) & (t MOD 2 < u MOD 2)) OR (r < 0) THEN INC( high, 10000H ) END;

		u := t * 10000H;  INC( low, u );
		(* IF unsigned (low) < unsigned (u) THEN INC (high) END *)
		r := LSH( low, -1 ) - LSH( u, -1 );
		IF ((r = 0) & (low MOD 2 < u MOD 2)) OR (r < 0) THEN INC( high ) END;
		INC( high, LSH( t, -16 ) );

		tmp := low;  INC( low, c );
		(* IF unsigned (low) < unsigned (tmp) THEN INC (high) END *)
		r := LSH( low, -1 ) - LSH( tmp, -1 );
		IF ((r = 0) & (low MOD 2 < tmp MOD 2)) OR (r < 0) THEN INC( high ) END
	END LongMultAdd;

	PROCEDURE MWC*( VAR x, c: LONGINT;  a: LONGINT );
	BEGIN
		LongMultAdd( c, x, a, x, c )
	END MWC;

	PROCEDURE Next( r: tRandom );
	VAR seed: vyRanBase.tSeed;
	BEGIN
		seed := r.seed;
		WITH seed: tSeed DO
			LongMultAdd( seed.c, seed.x, seed.a, seed.x, seed.c ) (* MWC (seed.x, seed.c, seed.a) *)
		END
	END Next;

	PROCEDURE Max( r: tRandom ): Bits;
	BEGIN
		RETURN vyRanBase.sysMaxUnsigned (* 0FFFFFFFFH *)
	END Max;

	PROCEDURE Get( r: tRandom ): Bits;
	VAR seed: vyRanBase.tSeed;
	BEGIN
		seed := r.seed;
		WITH seed: tSeed DO
			LongMultAdd( seed.c, seed.x, seed.a, seed.x, seed.c );   (* MWC (seed.x, seed.c, seed.a); *)
			RETURN seed.x
		END
	END Get;

	PROCEDURE GetV( r: tRandom;  count: LONGINT;  VAR nrs: ARRAY OF Bits;  start: LONGINT );
	VAR seed: vyRanBase.tSeed;  i: LONGINT;  x, a, c: LONGINT;
	BEGIN
		seed := r.seed;
		WITH seed: tSeed DO
			a := seed.a;  c := seed.c;  x := seed.x;
			FOR i := start TO start + count - 1 DO LongMultAdd( c, x, a, x, c );  nrs[i] := x END;
			seed.a := a;  seed.c := c;  seed.x := x
		END
	END GetV;

	PROCEDURE GetUniform( r: tRandom ): LONGREAL;
	CONST posScalefact = 0.5 / MAX( LONGINT );  negScalefact = 0.5 / MIN( LONGINT );
	VAR seed: vyRanBase.tSeed;
	BEGIN
		seed := r.seed;
		WITH seed: tSeed DO
			LongMultAdd( seed.c, seed.x, seed.a, seed.x, seed.c );   (* MWC (seed.x, seed.c, seed.a) *)
			IF seed.x >= 0 THEN RETURN seed.x * posScalefact + 0.5 ELSE RETURN seed.x * negScalefact END
		END
	END GetUniform;

	PROCEDURE GetL( r: tRandom;  top: LONGINT ): LONGINT;
	VAR seed: vyRanBase.tSeed;  x: LONGINT;
	BEGIN
		seed := r.seed;
		WITH seed: tSeed DO
			LongMultAdd( seed.c, seed.x, seed.a, seed.x, seed.c );   (* MWC (seed.x, seed.c, seed.a) *)
			x := seed.x;
			IF x < 0 THEN DEC( x, MIN( LONGINT ) ) END;
			IF top <= 0 THEN RETURN x ELSE RETURN x MOD top END
		END
	END GetL;

	PROCEDURE Reset( r: tRandom );
	VAR seed: vyRanBase.tSeed;  c, x: LONGINT;
	BEGIN
		seed := r.seed;
		WITH seed: tSeed DO
			seed.c := 0;  seed.x := vyRanBase.DefaultLongSeed();

			IF seed.checkPeriod THEN
				LOOP
					LongMultAdd( c, x, seed.a, seed.x, seed.c );   (* MWC (x, c, seed.a); *)
					IF (x # seed.x) OR (c # seed.c) THEN EXIT END;
					INC( seed.x )
				END
			END
		END
	END Reset;

	PROCEDURE HandleAttributes( obj: tRandom;  VAR M: Objects.AttrMsg );
	BEGIN
		CASE M.id OF
		Objects.get:
				IF M.name = "Gen" THEN
					(* jb 29.11.00 - Alloc instead of New *)
					COPY( "vyRanMWC.Alloc", M.s );  M.class := Objects.String;  M.res := 0
				ELSIF (M.name = "Value") OR (M.name = "Seed") OR (M.name = "SeedX") THEN
					M.i := obj.seed( tSeed ).x;  M.class := Objects.Int;  M.res := 0 (*??? konsistent machen *)
				ELSIF (M.name = "SeedC") THEN M.i := obj.seed( tSeed ).c;  M.class := Objects.Int;  M.res := 0
				ELSE vyRanBase.Handler( obj, M )
				END

		| Objects.set:
				IF (M.name = "Value") OR (M.name = "Seed") OR (M.name = "SeedX") THEN
					(*??? Wertebereich überprüfen? *)
					IF M.class = Objects.Int THEN obj.seed( tSeed ).x := M.i;  M.res := 0 END
				ELSIF M.name = "SeedC" THEN
					(*??? Wertebereich überprüfen? *)
					IF M.class = Objects.Int THEN obj.seed( tSeed ).c := M.i;  M.res := 0 END
				ELSE vyRanBase.Handler( obj, M )
				END

		| Objects.enum:
				M.Enum( "Seed" );  vyRanBase.Handler( obj, M )
		ELSE vyRanBase.Handler( obj, M )
		END
	END HandleAttributes;

	PROCEDURE Handler*( obj: Objects.Object;  VAR M: Objects.ObjMsg );
	BEGIN
		WITH obj: tRandom DO
			IF M IS Objects.AttrMsg THEN
				WITH M: Objects.AttrMsg DO
					HandleAttributes( obj, M )
					(* jb29.11.00 - don't handle file msg here *)
				END;
			ELSE vyRanBase.Handler( obj, M )
			END
		END
	END Handler;

	PROCEDURE InitBasic( r: tRandom );
	BEGIN
		r.id := 'v0.0a1 32bit Multiply with Carry';  r.shortid := 'MWC';  r.seedVersion := cSeedVersion;

		vyRanBase.SetDefaultProcs( r );

		r.SumPSqr := vyRanBase.DefaultSumPSqr;  r.Reset := Reset;  r.GetRandom := Get;  r.GetRandomL := GetL;
		(* r.GetRandomLExact := GetLExact; *)
		r.GetRandomU := GetUniform;  r.NextRandom := Next;  r.Max := Max;  r.GetRandomBitV := GetV;

		r.handle := Handler;

		r.AllocSeed := AllocSeed
	END InitBasic;

	PROCEDURE Init( r: tRandom );
	VAR seed: tSeed;
	BEGIN
		InitBasic( r );

		NEW( seed );
		IF useParam THEN seed.a := seedA;  seed.checkPeriod := seedCheckPeriod;  useParam := FALSE
		ELSE seed.a := stdSeedA;  seed.checkPeriod := TRUE
		END;
		r.SetSeed( r, seed )
	END Init;

(* added - jb 29.11.00 *)
	PROCEDURE Alloc*;
	VAR r: tRandom;
	BEGIN
		NEW( r );  InitBasic( r );  Objects.NewObj := r
	END Alloc;

	PROCEDURE GetNew*( ): tRandom;
	VAR r: tRandom;
	BEGIN
		NEW( r );  Init( r );  r.Reset( r );  RETURN r
	END GetNew;

	PROCEDURE New*;
	BEGIN
		Objects.NewObj := GetNew()
	END New;

	PROCEDURE Install*;
	BEGIN
		vyRanBase.Install( GetNew() )
	END Install;

	PROCEDURE SetParam*( a: LONGINT;  checkPeriod: BOOLEAN );
	BEGIN
		seedA := a;  seedCheckPeriod := checkPeriod;  useParam := TRUE
	END SetParam;

BEGIN
	ASSERT ( SIZEOF( LONGINT ) = 4, 100 );
	useParam := FALSE
END vyRanMWC.


System.Free  RandomMWC vyRanBase ~

RandomMWC.Install ~
Gadgets.Insert SetFrame vyRanBase.Deposit ~
vyRanBase.NextRandom ~

Gadgets.Insert SetFrame vyRanSkeleton.New ~
Voyager.Random 200 ~
Voyager.Show @ ~
System.Free vyRanBase ~
