MODULE vyRanKiss IN Oberon;
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


(*= Kiss random generator
based on a Fortran algorithm from the "Diehard" package by G. Marsaglia
*)
(* created: 7.3.01 by Johannes Becker *)
(* changed:
5.5.01 by Johannes Becker - support for seed version check added
*)

IMPORT vyRanBase, Files, Objects, S := SYSTEM;

CONST
	cSeedVersion = 0;

	sysMaxUnsigned = vyRanBase.sysMaxUnsigned;  sysSHL = vyRanBase.sysSHL;  sysSHR = vyRanBase.sysSHR;

TYPE
	Bits = vyRanBase.Bits;

	tSeed = OBJECT  (* POINTER TO tSeedDesc;
	tSeedDesc = RECORD (vyRanBase.tSeedDesc)*)
	(vyRanBase.tSeed)
	VAR x, y, z, w, carry: SIGNED32;

		PROCEDURE  (*VAR seed: tSeedDesc*) Store*( VAR r: Files.Rider );
		BEGIN
			Files.WriteLInt( r, SELF.x );  Files.WriteLInt( r, SELF.y );  Files.WriteLInt( r, SELF.z );  Files.WriteLInt( r, SELF.w );
			Files.WriteLInt( r, SELF.carry )
		END Store;

		PROCEDURE  (*VAR seed: tSeedDesc*) Load*( VAR r: Files.Rider;  seedVersion: SIGNED16 );
		BEGIN
			IF seedVersion # cSeedVersion THEN HALT( 100 ) END;
			Files.ReadLInt( r, SELF.x );  Files.ReadLInt( r, SELF.y );  Files.ReadLInt( r, SELF.z );  Files.ReadLInt( r, SELF.w );
			Files.ReadLInt( r, SELF.carry )
		END Load;

	END tSeed;

	PROCEDURE AllocSeed*( ): vyRanBase.tSeed;
	VAR seed: tSeed;
	BEGIN
		NEW( seed );  RETURN seed
	END AllocSeed;

	PROCEDURE Kiss( VAR x, y, z, w, carry: Bits;  count: SIGNED32;  VAR nrs: ARRAY OF Bits;  start: SIGNED32 );
	VAR j: SIGNED32;  k, m: Bits;
	BEGIN
		FOR j := start TO start + count - 1 DO
			x := 69069 * x + 1;  y := S.VAL( Bits, S.VAL( SET, y ) / S.VAL( SET, LSH( y, sysSHL * 13 ) ) );
			y := S.VAL( Bits, S.VAL( SET, y ) / S.VAL( SET, LSH( y, sysSHR * 17 ) ) );
			y := S.VAL( Bits, S.VAL( SET, y ) / S.VAL( SET, LSH( y, sysSHL * 5 ) ) );
			k := LSH( z, sysSHR * 2 ) + LSH( w, sysSHR * 3 ) + LSH( carry, sysSHR * 2 );  m := w + w + z + carry;  z := w;
			w := m;  carry := LSH( k, sysSHR * 30 );

			nrs[j] := x + y + w
		END
	END Kiss;

	PROCEDURE Next( r: vyRanBase.tRandom );
	VAR seed: vyRanBase.tSeed;
		dummy: ARRAY 1 OF Bits;
	BEGIN
		seed := r.seed;
		WITH seed: tSeed DO Kiss( seed.x, seed.y, seed.z, seed.w, seed.carry, 1, dummy, 0 )
		END
	END Next;

	PROCEDURE Max( r: vyRanBase.tRandom ): Bits;
	BEGIN
		RETURN sysMaxUnsigned
	END Max;

	PROCEDURE Get( r: vyRanBase.tRandom ): Bits;
	VAR seed: vyRanBase.tSeed;
		dummy: ARRAY 1 OF Bits;
	BEGIN
		seed := r.seed;
		WITH seed: tSeed DO Kiss( seed.x, seed.y, seed.z, seed.w, seed.carry, 1, dummy, 0 )
		END;
		RETURN dummy[0]
	END Get;

	PROCEDURE GetV( r: vyRanBase.tRandom;  count: SIGNED32;  VAR nrs: ARRAY OF Bits;  start: SIGNED32 );
	VAR seed: vyRanBase.tSeed;
	BEGIN
		seed := r.seed;
		WITH seed: tSeed DO Kiss( seed.x, seed.y, seed.z, seed.w, seed.carry, count, nrs, start )
		END
	END GetV;

	PROCEDURE GetUniform( r: vyRanBase.tRandom ): FLOAT64;
	CONST posScalefact = 0.5 / MAX( SIGNED32 );  negScalefact = 0.5 / MIN( SIGNED32 );
	VAR seed: vyRanBase.tSeed;  n: SIGNED32;
		dummy: ARRAY 1 OF Bits;
	BEGIN
		seed := r.seed;
		WITH seed: tSeed DO
			Kiss( seed.x, seed.y, seed.z, seed.w, seed.carry, 1, dummy, 0 );  n := dummy[0];
			IF n >= 0 THEN RETURN n * posScalefact + 0.5 ELSE RETURN n * negScalefact END
		END
	END GetUniform;

	PROCEDURE GetL( r: vyRanBase.tRandom;  top: SIGNED32 ): SIGNED32;
	VAR seed: vyRanBase.tSeed;  n: SIGNED32;
		dummy: ARRAY 1 OF Bits;
	BEGIN
		seed := r.seed;
		WITH seed: tSeed DO
			Kiss( seed.x, seed.y, seed.z, seed.w, seed.carry, 1, dummy, 0 );  n := dummy[0];
			IF n < 0 THEN DEC( n, MIN( SIGNED32 ) ) END;
			IF top <= 0 THEN RETURN n ELSE RETURN n MOD top END
		END
	END GetL;

	PROCEDURE Reset( r: vyRanBase.tRandom );
	VAR seed: vyRanBase.tSeed;
	BEGIN
		seed := r.seed;
		WITH seed: tSeed DO
			seed.x := vyRanBase.DefaultLongSeed();
			IF seed.x = 0 THEN seed.x := 1 END;
			seed.y := vyRanBase.DefaultLongSeed();
			IF seed.y = 0 THEN seed.y := 1 END;
			seed.z := vyRanBase.DefaultLongSeed();
			IF seed.z = 0 THEN seed.z := 1 END;
			seed.w := vyRanBase.DefaultLongSeed();
			IF seed.w = 0 THEN seed.w := 1 END;
			seed.carry := 0
		END
	END Reset;

	PROCEDURE HandleAttributes( obj: vyRanBase.tRandom;  VAR M: Objects.AttrMsg );
	VAR seed: vyRanBase.tSeed;
	BEGIN
		CASE M.id OF
		Objects.get:
				IF M.name = "Gen" THEN COPY( "vyRanKiss.Alloc", M.s );  M.class := Objects.String;  M.res := 0
				ELSIF M.name = "Value" THEN
					seed := obj.seed;
					WITH seed: tSeed DO M.i := seed.x + seed.y + seed.w
					END;
					M.class := Objects.Int;  M.res := 0
				ELSIF M.name = "SeedX" THEN M.i := obj.seed( tSeed ).x;  M.class := Objects.Int;  M.res := 0
				ELSIF M.name = "SeedY" THEN M.i := obj.seed( tSeed ).y;  M.class := Objects.Int;  M.res := 0
				ELSIF M.name = "SeedZ" THEN M.i := obj.seed( tSeed ).z;  M.class := Objects.Int;  M.res := 0
				ELSIF M.name = "SeedW" THEN M.i := obj.seed( tSeed ).w;  M.class := Objects.Int;  M.res := 0
				ELSIF M.name = "SeedCarry" THEN M.i := obj.seed( tSeed ).carry;  M.class := Objects.Int;  M.res := 0
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
				ELSIF M.name = "SeedW" THEN
					(*??? Wertebereich überprüfen? *)
					IF M.class = Objects.Int THEN obj.seed( tSeed ).w := M.i;  M.res := 0 END
				ELSIF M.name = "SeedCarry" THEN
					(*??? Wertebereich überprüfen? *)
					IF M.class = Objects.Int THEN obj.seed( tSeed ).carry := M.i;  M.res := 0 END
				ELSE vyRanBase.Handler( obj, M )
				END

		| Objects.enum:
				M.Enum( "Seed" );  vyRanBase.Handler( obj, M )
		ELSE vyRanBase.Handler( obj, M )
		END
	END HandleAttributes;

	PROCEDURE Handler*( obj: Objects.Object;  VAR M: Objects.ObjMsg );
	BEGIN
		WITH obj: vyRanBase.tRandom DO
			IF M IS Objects.AttrMsg THEN
				WITH M: Objects.AttrMsg DO HandleAttributes( obj, M )
				END;
			ELSE vyRanBase.Handler( obj, M )
			END
		END
	END Handler;

	PROCEDURE InitBasic( r: vyRanBase.tRandom );
	BEGIN
		r.id := 'v0.0a1 Kiss';  r.shortid := 'Kiss';  r.seedVersion := cSeedVersion;

		vyRanBase.SetDefaultProcs( r );

		r.SumPSqr := vyRanBase.DefaultSumPSqr;  r.Reset := Reset;  r.GetRandom := Get;  r.GetRandomL := GetL;
		r.GetRandomU := GetUniform;  r.NextRandom := Next;  r.Max := Max;  r.GetRandomBitV := GetV;

		r.handle := Handler;

		r.AllocSeed := AllocSeed
	END InitBasic;

	PROCEDURE Init( r: vyRanBase.tRandom );
	VAR seed: tSeed;
	BEGIN
		InitBasic( r );  NEW( seed );  r.SetSeed( r, seed )
	END Init;

	PROCEDURE Alloc*;
	VAR r: vyRanBase.tRandom;
	BEGIN
		NEW( r );  InitBasic( r );  Objects.NewObj := r
	END Alloc;

	PROCEDURE GetNew*( ): vyRanBase.tRandom;
	VAR r: vyRanBase.tRandom;
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
	VAR bits: Bits;
	BEGIN
		(* assert that rightshift is the same as DIV 2 *)
		bits := 2;  bits := LSH( bits, sysSHR );
		ASSERT ( bits = 1, 100 );

		(* assert that shift is unsigned *)
		bits := MIN( Bits );  bits := LSH( bits, sysSHR );
		ASSERT ( bits > 0, 101 );
		bits := LSH( bits, sysSHL );
		ASSERT ( bits < 0, 102 );

		ASSERT ( SIZEOF( SIGNED32 ) = 4, 103 );
		ASSERT ( SIZEOF( SET ) = 4, 104 )
	END DoAsserts;

BEGIN
	DoAsserts
END vyRanKiss.

