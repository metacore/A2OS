MODULE vyRanSupr IN Oberon;
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


(*= Super-Duper generator,
based on a Fortran algorithm from the "Diehard" package by G. Marsaglia
*)
(* changed:
jb 5.5.01 - support for seed version check added
jb 7.3.01 - minor changes
jb 11.1.01, 30.11.00 - new vyRanBase, allow to load/store seed *)
(* created: 28.3.00 by Johannes Becker *)

IMPORT S := SYSTEM, Objects, Files, vyRanBase;

CONST
	cModuleName = "vyRanSupr";  cSeedVersion = 0;

	sysMaxUnsigned = vyRanBase.sysMaxUnsigned;

TYPE
	tSeed = OBJECT  (* POINTER TO tSeedDesc;
	tSeedDesc = RECORD (vyRanBase.tSeedDesc)*)
	(vyRanBase.tSeed)
	VAR x, y: LONGINT;
		add: BOOLEAN;
		n: LONGINT;

		PROCEDURE  (*VAR seed: tSeedDesc*) Store*( VAR r: Files.Rider );
		BEGIN
			Files.WriteLInt( r, SELF.x );  Files.WriteLInt( r, SELF.y );  Files.WriteBool( r, SELF.add );  Files.WriteLInt( r, SELF.n )
		END Store;

		PROCEDURE  (*VAR seed: tSeedDesc*) Load*( VAR r: Files.Rider;  seedVersion: INTEGER );
		BEGIN
			IF seedVersion # cSeedVersion THEN HALT( 100 ) END;
			Files.ReadLInt( r, SELF.x );  Files.ReadLInt( r, SELF.y );  Files.ReadBool( r, SELF.add );  Files.ReadLInt( r, SELF.n )
		END Load;

	END tSeed;

	tRandom = vyRanBase.tRandom;  Bits = vyRanBase.Bits;

VAR
	seedAdd: BOOLEAN;

	(* added - jb 29.11.00 *)
	PROCEDURE AllocSeed*( ): vyRanBase.tSeed;
	VAR seed: tSeed;
	BEGIN
		NEW( seed );  RETURN seed
	END AllocSeed;

	PROCEDURE NextSeed( seed: tSeed );
	CONST c5 = 20H;  c13 = 2000H;  c17 = 20000H;
	VAR x, y: LONGINT;
	BEGIN
		x := seed.x;  y := seed.y;

		x := 69069 * x + 1;
		y := S.VAL( LONGINT, S.VAL( SET, y ) / S.VAL( SET, y * c13 ) );   (* y := xor (y, lshift (y, 13)) *)
		y := S.VAL( LONGINT, S.VAL( SET, y ) / S.VAL( SET, y * c17 ) );  y := S.VAL( LONGINT, S.VAL( SET, y ) / S.VAL( SET, y * c5 ) );
		IF seed.add THEN seed.n := x + y ELSE seed.n := S.VAL( LONGINT, S.VAL( SET, x ) / S.VAL( SET, y ) ) END;

		seed.x := x;  seed.y := y
	END NextSeed;

	PROCEDURE Next( r: tRandom );
	VAR seed: vyRanBase.tSeed;
	BEGIN
		seed := r.seed;
		WITH seed: tSeed DO NextSeed( seed )
		END
	END Next;

	PROCEDURE Max( r: tRandom ): Bits;
	BEGIN
		RETURN sysMaxUnsigned
	END Max;

	PROCEDURE Get( r: tRandom ): Bits;
	VAR seed: vyRanBase.tSeed;
	BEGIN
		seed := r.seed;
		WITH seed: tSeed DO NextSeed( seed );  RETURN seed.n
		END
	END Get;

	PROCEDURE GetUniform( r: tRandom ): LONGREAL;
	CONST posScalefact = 0.5 / MAX( LONGINT );  negScalefact = 0.5 / MIN( LONGINT );
	VAR seed: vyRanBase.tSeed;
	BEGIN
		seed := r.seed;
		WITH seed: tSeed DO
			NextSeed( seed );
			IF seed.n >= 0 THEN RETURN seed.n * posScalefact + 0.5 ELSE RETURN seed.n * negScalefact END
		END
	END GetUniform;

	PROCEDURE GetL( r: tRandom;  top: LONGINT ): LONGINT;
	VAR seed: vyRanBase.tSeed;  z: LONGINT;
	BEGIN
		seed := r.seed;
		WITH seed: tSeed DO
			NextSeed( seed );  z := seed.n;
			IF z < 0 THEN DEC( z, MIN( LONGINT ) ) END;
			IF top <= 0 THEN RETURN z ELSE RETURN z MOD top END
		END
	END GetL;

	PROCEDURE Reset( r: tRandom );
	VAR x, y: LONGINT;  seed: vyRanBase.tSeed;
	BEGIN
		seed := r.seed;
		WITH seed: tSeed DO
			x := vyRanBase.DefaultLongSeed();  y := vyRanBase.DefaultLongSeed();
			IF y = 0 THEN y := 1 END;
			IF seed.add THEN seed.n := x + y ELSE seed.n := S.VAL( LONGINT, S.VAL( SET, x ) / S.VAL( SET, y ) ) END;
			seed.x := x;  seed.y := y
		END
	END Reset;

	PROCEDURE HandleAttributes( obj: tRandom;  VAR M: Objects.AttrMsg );
	BEGIN
		CASE M.id OF
		Objects.get:
				IF M.name = "Gen" THEN COPY( "vyRanSupr.Alloc", M.s );  M.class := Objects.String;  M.res := 0
				ELSIF M.name = "Value" THEN
					M.i := obj.seed( tSeed ).n;  M.class := Objects.Int;  M.res := 0 (*??? konsistent machen *)
				ELSIF M.name = "SeedX" THEN M.i := obj.seed( tSeed ).x;  M.class := Objects.Int;  M.res := 0
				ELSIF M.name = "SeedY" THEN M.i := obj.seed( tSeed ).y;  M.class := Objects.Int;  M.res := 0
				ELSE vyRanBase.Handler( obj, M )
				END

		| Objects.set:
				IF M.name = "SeedX" THEN
					(*??? Wertebereich überprüfen? *)
					IF M.class = Objects.Int THEN obj.seed( tSeed ).x := M.i;  M.res := 0 END
				ELSIF M.name = "SeedY" THEN
					(*??? Wertebereich überprüfen? *)
					IF M.class = Objects.Int THEN obj.seed( tSeed ).y := M.i;  M.res := 0 END
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
				WITH M: Objects.AttrMsg DO HandleAttributes( obj, M )
				END;
			ELSE vyRanBase.Handler( obj, M )
			END
		END
	END Handler;

	PROCEDURE InitBasic( r: tRandom );
	BEGIN
		r.id := 'Super-Duper ';  r.shortid := 'Supr';  r.seedVersion := cSeedVersion;

		vyRanBase.SetDefaultProcs( r );

		r.SumPSqr := vyRanBase.DefaultSumPSqr;  r.Reset := Reset;  r.GetRandom := Get;  r.GetRandomL := GetL;
		r.GetRandomU := GetUniform;  r.NextRandom := Next;  r.Max := Max;

		r.handle := Handler;

		r.AllocSeed := AllocSeed
	END InitBasic;

	PROCEDURE Init( r: tRandom );
	VAR seed: tSeed;
	BEGIN
		InitBasic( r );  NEW( seed );  seed.add := seedAdd;  r.SetSeed( r, seed )
	END Init;

(* added - jb 30.11.00 *)
	PROCEDURE Alloc*;
	VAR r: tRandom;
	BEGIN
		NEW( r );  InitBasic( r );  Objects.NewObj := r
	END Alloc;

	PROCEDURE GetNew*( ): tRandom;
	(* call SetAdd first to say which generator to be created *)
	VAR r: tRandom;
	BEGIN
		NEW( r );  Init( r );  r.Reset( r );  RETURN r
	END GetNew;

	PROCEDURE New*;
	(* call SetAdd first to say which generator to be created *)
	BEGIN
		Objects.NewObj := GetNew()
	END New;

	PROCEDURE Install*;
	(* call SetAdd first to say which generator to be created *)
	BEGIN
		vyRanBase.Install( GetNew() )
	END Install;

BEGIN
	ASSERT ( SIZEOF( SET ) >= SIZEOF( LONGINT ), 101 );
	seedAdd := TRUE
END vyRanSupr.