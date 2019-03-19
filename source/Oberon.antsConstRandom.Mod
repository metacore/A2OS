MODULE antsConstRandom IN Oberon;
(* Copyright notice:

This file is part of AntsInFields
Copyright (C) 1997-2002, Felix Friedrich

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
Report any problems as soon as possible to ants@AntsInFields.de
*)




IMPORT vyRanBase, Objects, Files, aM := antsMessages;

CONST
	idversion* = 'constRandom';
TYPE
	Bits = LONGINT;
	tRandom = POINTER TO tRandomDesc;
	tRandomDesc = RECORD (vyRanBase.tRandomNumberDesc)
		constval: LONGINT;
		max: LONGINT
	END;

	PROCEDURE Next( r: vyRanBase.tRandom );
	END Next;

	PROCEDURE Max( r: vyRanBase.tRandom ): LONGINT;
	BEGIN
		WITH r: tRandom DO RETURN r.max
		END
	END Max;

	PROCEDURE Get( r: vyRanBase.tRandom ): Bits;
	BEGIN
		WITH r: tRandom DO RETURN r.constval
		END
	END Get;

	PROCEDURE GetUniform( r: vyRanBase.tRandom ): LONGREAL;
	BEGIN
		WITH r: tRandom DO RETURN r.constval / r.max
		END
	END GetUniform;

	PROCEDURE RandomUVX( r: vyRanBase.tRandom;  count: LONGINT;  VAR nrs: ARRAY OF LONGREAL;  start: LONGINT );
	VAR i: LONGINT;
	BEGIN
		WITH r: tRandom DO
			FOR i := start TO start + count - 1 DO nrs[i] := r.constval / r.max END
		END
	END RandomUVX;

	PROCEDURE RandomUV( r: vyRanBase.tRandom;  count: LONGINT;  VAR nrs: ARRAY OF REAL;  start: LONGINT );
	VAR i: LONGINT;
	BEGIN
		WITH r: tRandom DO
			FOR i := start TO start + count - 1 DO nrs[i] := r.constval / r.max END
		END
	END RandomUV;

	PROCEDURE GetL( r: vyRanBase.tRandom;  top: LONGINT ): LONGINT;
	CONST  (*a = 16807;	m = 2147483647; 	q = m DIV a;	r = m MOD a; scalefact=1.0D0/m;*)
	BEGIN
		WITH r: tRandom DO RETURN (top - 1) * r.constval DIV r.max
		END
	END GetL;

	PROCEDURE RandomLV( r: vyRanBase.tRandom;  top, count: LONGINT;  VAR nrs: ARRAY OF LONGINT;  start: LONGINT );
	VAR i: LONGINT;
	BEGIN
		WITH r: tRandom DO
			FOR i := start TO start + count - 1 DO nrs[i] := (top - 1) * r.constval DIV r.max END
		END
	END RandomLV;

	PROCEDURE HandleAttributes( obj: tRandom;  VAR M: Objects.AttrMsg );
	BEGIN
		IF M.id = Objects.get THEN
			IF M.name = "Gen" THEN COPY( "antsConstRandom.Alloc", M.s );  M.class := Objects.String;  M.res := 0
			ELSIF (M.name = "Value") OR (M.name = "Seed") THEN
				M.i := obj.seed( vyRanBase.tLongintSeed ).val;  M.class := Objects.Int;  M.res := 0
			ELSE vyRanBase.Handler( obj, M )
			END
		ELSIF M.id = Objects.set THEN
			IF (M.name = "Value") OR (M.name = "Seed") THEN
				IF M.class = Objects.Int THEN obj.seed( vyRanBase.tLongintSeed ).val := M.i;  M.res := 0 END
			ELSE vyRanBase.Handler( obj, M )
			END
		ELSIF M.id = Objects.enum THEN M.Enum( "Seed" );  vyRanBase.Handler( obj, M )
		END
	END HandleAttributes;

	PROCEDURE HandleFileMsg( obj: tRandom;  VAR msg: Objects.FileMsg );
	VAR version: INTEGER;
	BEGIN
		IF msg.id = Objects.load THEN
			Files.ReadInt( msg.R, version );  vyRanBase.Handler( obj, msg );  Files.ReadLInt( msg.R, obj.max );
			Files.ReadLInt( msg.R, obj.constval )
		ELSIF msg.id = Objects.store THEN
			Files.WriteInt( msg.R, 0 );  vyRanBase.Handler( obj, msg );  Files.WriteLInt( msg.R, obj.max );
			Files.WriteLInt( msg.R, obj.constval )
		ELSE vyRanBase.Handler( obj, msg )
		END
	END HandleFileMsg;

	PROCEDURE Handler*( obj: Objects.Object;  VAR M: Objects.ObjMsg );
	BEGIN
		WITH obj: tRandom DO
			IF M IS Objects.AttrMsg THEN
				WITH M: Objects.AttrMsg DO HandleAttributes( obj, M )
				END;
			ELSIF M IS Objects.FileMsg THEN
				WITH M: Objects.FileMsg DO vyRanBase.Handler( obj, M );  HandleFileMsg( obj, M )
				END;
			ELSE vyRanBase.Handler( obj, M )
			END
		END;   (*WITH obj:tRandom DO*)
	END Handler;

	PROCEDURE InitBasic( r: tRandom );
	BEGIN
		r.id := 'PIO v 1.0d1dummy naive Parks&Miller';  r.shortid := 'PM';

		vyRanBase.SetDefaultProcs( r );

		r.Reset := vyRanBase.DefaultLongintReset;  r.GetRandom := Get;  r.GetRandomL := GetL;
		r.GetRandomU := GetUniform;

		r.GetRandomUVX := RandomUVX;  r.GetRandomUV := RandomUV;  r.GetRandomLV := RandomLV;

		r.NextRandom := Next;  r.Max := Max;

		r.handle := Handler;

		r.AllocSeed := vyRanBase.AllocLongintSeed
	END InitBasic;

	PROCEDURE Init( r: tRandom );
	VAR seed: vyRanBase.tLongintSeed;
	BEGIN
		InitBasic( r );

		NEW( seed );  r.SetSeed( r, seed )
	END Init;

(* added - jb 30.11.00 *)
	PROCEDURE Alloc*;
	VAR r: tRandom;
	BEGIN
		NEW( r );  InitBasic( r );  Objects.NewObj := r
	END Alloc;

	PROCEDURE New*( val, max: LONGINT ): tRandom;
	VAR r: tRandom;
	BEGIN
		NEW( r );  Init( r );  r.Reset( r );  r.max := max;  r.constval := val;  Objects.NewObj := r;  RETURN r
	END New;

	PROCEDURE Install*;
	VAR r: tRandom;
	BEGIN
		aM.cmd;  r := New( 0, 1 );  vyRanBase.Install( Objects.NewObj( tRandom ) )
	END Install;

(* for debugging:
PROCEDURE SaveInfo*;
BEGIN
usedval := vyRanBase.RandomGenerator.seed(vyRanBase.tLongintSeed).val;   infosaved := TRUE;
END SaveInfo;
*)

BEGIN
	aM.launch;
	(*	infosaved := FALSE;  *)
END antsConstRandom.

System.Free  vyRanParksMiller vyRanBase ~

vyRanParksParksMiller.Install ~

Voyager.Random 200 ~
Voyager.Show @ ~
