MODULE vyRanCombo IN Oberon;
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


(*= Combo
x [n] := x [n-1] * x[n-2], added to MWC z := 30903 * and (z, 65535) + shift (z,-16)
based on a Fortran algorithm from the "Diehard" package by G. Marsaglia
*)
(* created: 12.3.00 by Johannes Becker *)
(* changed:
5.5.01 by Johannes Becker - support for seed version check added
6.3.01 by Johannes Becker - minor changes
2.3.01 by Johannes Becker - bug fixed by using non-portable SYSTEM procedures instead of DIV and MOD now
11.1.01, 30.11.00 by Johannes Becker- allow to load/store seed, changes in vyRanBase
28.3.00 by Johannes Becker - new version of vyRanBase
*)

IMPORT vyRanBase, Files, Objects, S := SYSTEM;

CONST
	cModuleName = "vyRanCombo";  cSeedVersion = 0;

	sysBitsTypeSize = vyRanBase.sysBitsTypeSize;  sysMaxUnsigned = vyRanBase.sysMaxUnsigned;
	sysMaskSecondHalf = vyRanBase.sysMaskSecondHalf;  sysSHR = vyRanBase.sysSHR;

	mwcParam = 30903;

TYPE
	tRandom = vyRanBase.tRandom;
	tSeed = OBJECT  (* POINTER TO tSeedDesc;
	tSeedDesc = RECORD (vyRanBase.tSeedDesc)*)
	(vyRanBase.tSeed)
	VAR x, y, z: LONGINT;

		PROCEDURE  (*VAR seed: tSeedDesc*) Store*( VAR r: Files.Rider );
		BEGIN
			Files.WriteLInt( r, SELF.x );  Files.WriteLInt( r, SELF.y );  Files.WriteLInt( r, SELF.z )
		END Store;

		PROCEDURE  (*VAR seed: tSeedDesc*) Load*( VAR r: Files.Rider;  seedVersion: INTEGER );
		BEGIN
			IF seedVersion # cSeedVersion THEN HALT( 100 ) END;
			Files.ReadLInt( r, SELF.x );  Files.ReadLInt( r, SELF.y );  Files.ReadLInt( r, SELF.z )
		END Load;

	END tSeed;

	Bits = vyRanBase.Bits;

	(* added - jb 29.11.00 *)
	PROCEDURE AllocSeed*( ): vyRanBase.tSeed;
	VAR seed: tSeed;
	BEGIN
		NEW( seed );  RETURN seed
	END AllocSeed;

	PROCEDURE Combo*( VAR x, y, z: LONGINT ): LONGINT;
	VAR v: LONGINT;
	BEGIN
		v := x * y;  x := y;  y := v;
		z := mwcParam * S.VAL( Bits, S.VAL( SET, z ) * S.VAL( SET, sysMaskSecondHalf ) ) + LSH( z, sysBitsTypeSize DIV 2 * sysSHR );
		RETURN y + z
	END Combo;

	PROCEDURE Next( r: tRandom );
	VAR seed: vyRanBase.tSeed;  dummy: LONGINT;
	BEGIN
		seed := r.seed;
		WITH seed: tSeed DO dummy := Combo( seed.x, seed.y, seed.z )
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
		WITH seed: tSeed DO RETURN Combo( seed.x, seed.y, seed.z )
		END
	END Get;

	PROCEDURE GetUniform( r: tRandom ): LONGREAL;
	CONST posScalefact = 0.5 / MAX( LONGINT );  negScalefact = 0.5 / MIN( LONGINT );
	VAR seed: vyRanBase.tSeed;  n: LONGINT;
	BEGIN
		seed := r.seed;
		WITH seed: tSeed DO
			n := Combo( seed.x, seed.y, seed.z );
			IF n >= 0 THEN RETURN n * posScalefact + 0.5 ELSE RETURN n * negScalefact END
		END
	END GetUniform;

	PROCEDURE GetL( r: tRandom;  top: LONGINT ): LONGINT;
	VAR seed: vyRanBase.tSeed;  n: LONGINT;
	BEGIN
		seed := r.seed;
		WITH seed: tSeed DO
			n := Combo( seed.x, seed.y, seed.z );
			IF n < 0 THEN DEC( n, MIN( LONGINT ) ) END;
			IF top <= 0 THEN RETURN n ELSE RETURN n MOD top END
		END
	END GetL;

	PROCEDURE Reset( r: tRandom );
	VAR seed: vyRanBase.tSeed;  tmp: LONGINT;
	BEGIN
		seed := r.seed;
		WITH seed: tSeed DO
			tmp := 2 * vyRanBase.DefaultLongSeed() + 1;  seed.x := 3 * tmp * tmp;
			seed.y := 2 * vyRanBase.DefaultLongSeed() + 1;  seed.z := vyRanBase.DefaultLongSeed();
			IF seed.z = 0 THEN INC( seed.z ) END  (* jb 2.3.01 *)
		END
	END Reset;

	PROCEDURE HandleAttributes( obj: tRandom;  VAR M: Objects.AttrMsg );
	VAR seed: vyRanBase.tSeed;
	BEGIN
		CASE M.id OF
		Objects.get:
				IF M.name = "Gen" THEN COPY( "vyRanCombo.Alloc", M.s );  M.class := Objects.String;  M.res := 0
				ELSIF M.name = "Value" THEN
					seed := obj.seed;
					WITH seed: tSeed DO M.i := seed.y + seed.z
					END;
					M.class := Objects.Int;  M.res := 0
				ELSIF M.name = "SeedX" THEN M.i := obj.seed( tSeed ).x;  M.class := Objects.Int;  M.res := 0
				ELSIF M.name = "SeedY" THEN M.i := obj.seed( tSeed ).y;  M.class := Objects.Int;  M.res := 0
				ELSIF M.name = "SeedZ" THEN M.i := obj.seed( tSeed ).z;  M.class := Objects.Int;  M.res := 0
				ELSE vyRanBase.Handler( obj, M )
				END

		| Objects.set:
				IF M.name = "SeedX" THEN
					(*??? Wertebereich überprüfen? *)
					IF M.class = Objects.Int THEN obj.seed( tSeed ).x := M.i;  M.res := 0 END
				ELSIF M.name = "SeedY" THEN
					(*??? Wertebereich überprüfen? *)
					IF M.class = Objects.Int THEN obj.seed( tSeed ).y := M.i;  M.res := 0 END
				ELSIF M.name = "SeedZ" THEN
					(*??? Wertebereich überprüfen? *)
					IF M.class = Objects.Int THEN obj.seed( tSeed ).z := M.i;  M.res := 0 END
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
		r.id := 'v0.0a1 Combo';  r.shortid := 'Combo';  r.seedVersion := cSeedVersion;

		vyRanBase.SetDefaultProcs( r );

		r.SumPSqr := vyRanBase.DefaultSumPSqr;  r.Reset := Reset;  r.GetRandom := Get;  r.GetRandomL := GetL;
		r.GetRandomU := GetUniform;  r.NextRandom := Next;  r.Max := Max;

		r.handle := Handler;

		r.AllocSeed := AllocSeed
	END InitBasic;

	PROCEDURE Init( r: tRandom );
	VAR seed: tSeed;
	BEGIN
		InitBasic( r );  NEW( seed );  r.SetSeed( r, seed )
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

	PROCEDURE DoAsserts;
	VAR tmp: LONGINT;
	BEGIN
		ASSERT ( SIZEOF( SET ) = sysBitsTypeSize, 100 );
		tmp := -1;
		ASSERT ( LSH( tmp, sysSHR ) > 0, 101 )
	END DoAsserts;

BEGIN
	DoAsserts
END vyRanCombo.

System.Free  RandomCombo vyRanBase ~

RandomCombo.Install ~
Gadgets.Insert SetFrame vyRanBase.Deposit ~
vyRanBase.NextRandom ~

