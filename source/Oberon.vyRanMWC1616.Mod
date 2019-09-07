MODULE vyRanMWC1616 IN Oberon;   (** jb  **)
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


(*= a Multiply with Carry generator on pairs of 16 bits
based on a Fortran algorithm from the "Diehard" package by G. Marsaglia
*)
(* created: 12.3.00 by Johannes Becker *)
(* changes:
5.5.01 by Johannes Becker - support for seed version check added
7.3.01 by Johannes Becker - minor changes
2.3.01 by Johannes Becker - bug fixed by using non-portable SYSTEM procedures instead of DIV and MOD now
11.1.01, 30.11.00 by Johannes Becker - allow to load/store seed, changes in vyRanBase
28.3.00 by Johannes Becker - new version of vyRanBase
*)

IMPORT vyRanBase, Files, Objects, S := SYSTEM;

CONST
	cModuleName = "vyRanMWC1616";  cSeedVersion = 0;

	sysBitsTypeSize = vyRanBase.sysBitsTypeSize;  sysHalfBitsType = vyRanBase.sysHalfBitsType;
	sysMaxUnsigned = vyRanBase.sysMaxUnsigned;  sysMaskSecondHalf = vyRanBase.sysMaskSecondHalf;
	sysSHR = vyRanBase.sysSHR;

	stdSeedA = 18000;  stdSeedB = 30903;

TYPE
	tRandom = vyRanBase.tRandom;
	tSeed = OBJECT  (* POINTER TO tSeedDesc;
	tSeedDesc = RECORD (vyRanBase.tSeedDesc) *)
	(vyRanBase.tSeed)
	VAR a, b: LONGINT;
		x, y: LONGINT;
		checkPeriod: BOOLEAN;

		PROCEDURE  (*VAR seed: tSeedDesc*) Store*( VAR r: Files.Rider );
		BEGIN
			Files.WriteLInt( r, SELF.x );  Files.WriteLInt( r, SELF.y );  Files.WriteLInt( r, SELF.a );  Files.WriteLInt( r, SELF.b )
		END Store;

		PROCEDURE  (*VAR seed: tSeedDesc*) Load*( VAR r: Files.Rider;  seedVersion: INTEGER );
		BEGIN
			IF seedVersion # cSeedVersion THEN HALT( 100 ) END;
			Files.ReadLInt( r, SELF.x );  Files.ReadLInt( r, SELF.y );  Files.ReadLInt( r, SELF.a );  Files.ReadLInt( r, SELF.b )
		END Load;

	END tSeed;

	Bits = vyRanBase.Bits;

VAR
	useParam, seedCheckPeriod: BOOLEAN;  seedA, seedB: LONGINT;

	(* added - jb 29.11.00 *)
	PROCEDURE AllocSeed*( ): vyRanBase.tSeed;
	VAR seed: tSeed;
	BEGIN
		NEW( seed );  RETURN seed
	END AllocSeed;

	PROCEDURE Next( r: tRandom );
	VAR seed: vyRanBase.tSeed;
	BEGIN
		seed := r.seed;
		WITH seed: tSeed DO
			seed.x :=
				seed.a * S.VAL( Bits, S.VAL( SET, seed.x ) * SET( sysMaskSecondHalf ) ) +
				LSH( seed.x, sysBitsTypeSize DIV 2 * sysSHR );
			seed.y :=
				seed.b * S.VAL( Bits, S.VAL( SET, seed.y ) * SET( sysMaskSecondHalf ) ) +
				LSH( seed.y, sysBitsTypeSize DIV 2 * sysSHR )
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
		WITH seed: tSeed DO
			seed.x :=
				seed.a * S.VAL( Bits, S.VAL( SET, seed.x ) * SET(sysMaskSecondHalf ) ) +
				LSH( seed.x, sysBitsTypeSize DIV 2 * sysSHR );
			seed.y :=
				seed.b * S.VAL( Bits, S.VAL( SET, seed.y ) * SET(sysMaskSecondHalf ) ) +
				LSH( seed.y, sysBitsTypeSize DIV 2 * sysSHR );
			RETURN seed.x * sysHalfBitsType + LSH( seed.y, sysBitsTypeSize DIV 2 * sysSHR )
		END
	END Get;

	PROCEDURE GetUniform( r: tRandom ): LONGREAL;
	CONST posScalefact = 0.5 / MAX( LONGINT );  negScalefact = 0.5 / MIN( LONGINT );
	VAR seed: vyRanBase.tSeed;  n: LONGINT;
	BEGIN
		seed := r.seed;
		WITH seed: tSeed DO
			seed.x :=
				seed.a * S.VAL( Bits, S.VAL( SET, seed.x ) * SET( sysMaskSecondHalf ) ) +
				LSH( seed.x, sysBitsTypeSize DIV 2 * sysSHR );
			seed.y :=
				seed.b * S.VAL( Bits, S.VAL( SET, seed.y ) * SET( sysMaskSecondHalf ) ) +
				LSH( seed.y, sysBitsTypeSize DIV 2 * sysSHR );
			n := seed.x * sysHalfBitsType + LSH( seed.y, sysBitsTypeSize DIV 2 * sysSHR );
			IF n >= 0 THEN RETURN n * posScalefact + 0.5 ELSE RETURN n * negScalefact END
		END
	END GetUniform;

	PROCEDURE GetL( r: tRandom;  top: LONGINT ): LONGINT;
	VAR seed: vyRanBase.tSeed;  n: LONGINT;
	BEGIN
		seed := r.seed;
		WITH seed: tSeed DO
			seed.x :=
				seed.a * S.VAL( Bits, SET(seed.x ) * SET( sysMaskSecondHalf ) ) +
				LSH( seed.x, sysBitsTypeSize DIV 2 * sysSHR );
			seed.y :=
				seed.b * S.VAL( Bits, S.VAL( SET, seed.y ) * SET( sysMaskSecondHalf ) ) +
				LSH( seed.y, sysBitsTypeSize DIV 2 * sysSHR );
			n := seed.x * sysHalfBitsType + LSH( seed.y, sysBitsTypeSize DIV 2 * sysSHR );
			IF n < 0 THEN DEC( n, MIN( LONGINT ) ) END;
			IF top <= 0 THEN RETURN n ELSE RETURN n MOD top END
		END
	END GetL;

	PROCEDURE Reset( r: tRandom );
	VAR seed: vyRanBase.tSeed;  x, y: LONGINT;
	BEGIN
		seed := r.seed;
		WITH seed: tSeed DO
			seed.x := vyRanBase.DefaultLongSeed();  seed.y := vyRanBase.DefaultLongSeed();

			IF seed.checkPeriod THEN
				LOOP
					x :=
						seed.a * S.VAL( Bits, SET( seed.x ) * SET( sysMaskSecondHalf ) ) +
						LSH( seed.x, sysBitsTypeSize DIV 2 * sysSHR );
					IF x # seed.x THEN EXIT END;
					INC( seed.x )
				END;
				LOOP
					y :=
						seed.b * S.VAL( Bits, SET( seed.y ) * SET( sysMaskSecondHalf ) ) +
						LSH( seed.y, sysBitsTypeSize DIV 2 * sysSHR );
					IF y # seed.y THEN EXIT END;
					INC( seed.y )
				END
			END
		END
	END Reset;

	PROCEDURE HandleAttributes( obj: tRandom;  VAR M: Objects.AttrMsg );
	VAR seed: vyRanBase.tSeed;
	BEGIN
		CASE M.id OF
		Objects.get:
				IF M.name = "Gen" THEN COPY( "vyRanMWC1616.Alloc", M.s );  M.class := Objects.String;  M.res := 0
				ELSIF M.name = "Value" THEN
					seed := obj.seed;
					WITH seed: tSeed DO M.i := seed.x * sysHalfBitsType + (seed.y DIV sysHalfBitsType) MOD sysHalfBitsType
					END;
					M.class := Objects.Int;  M.res := 0
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
		r.id := 'v0.0a2 Multiply with Carry on pairs of 16 bits';  r.shortid := 'MWC1616';  r.seedVersion := 0;

		vyRanBase.SetDefaultProcs( r );

		r.SumPSqr := vyRanBase.DefaultSumPSqr;  r.Reset := Reset;  r.GetRandom := Get;  r.GetRandomL := GetL;
		r.GetRandomU := GetUniform;  r.NextRandom := Next;  r.Max := Max;

		r.handle := Handler;

		r.AllocSeed := AllocSeed
	END InitBasic;

	PROCEDURE Init( r: tRandom );
	VAR seed: tSeed;
	BEGIN
		InitBasic( r );  NEW( seed );
		IF useParam THEN seed.a := seedA;  seed.b := seedB;  seed.checkPeriod := seedCheckPeriod;  useParam := FALSE
		ELSE seed.a := stdSeedA;  seed.b := stdSeedB;  seed.checkPeriod := TRUE
		END;
		r.SetSeed( r, seed )
	END Init;

(* added - jb 30.11.00 *)
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

	PROCEDURE SetParam*( a, b: LONGINT;  checkPeriod: BOOLEAN );
	BEGIN
		seedA := a;  seedB := b;  seedCheckPeriod := checkPeriod;  useParam := TRUE
	END SetParam;

BEGIN
	ASSERT ( SIZEOF( LONGINT ) = sysBitsTypeSize, 100 );
	useParam := FALSE
END vyRanMWC1616.

System.Free  RandomMWC1616 vyRanBase ~

RandomMWC1616.Install ~
Gadgets.Insert SetFrame vyRanBase.Deposit ~
vyRanBase.NextRandom ~

