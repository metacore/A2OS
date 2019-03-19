MODULE vyColorPalettes IN Oberon;   (** fof , module from ANTS, ported to voyager**)
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


(* (c) Felix Friedrich *)

IMPORT Colors, vyBase, Objects, Gadgets, Files, Images;

TYPE
	Palette* = POINTER TO PaletteDesc;
	PaletteDesc* = RECORD (vyBase.ObjDesc)
		col-: ARRAY 256 OF Colors.Color;
		dcol-: ARRAY 256 OF LONGINT;   (* Cache for Display *)
		icol-: ARRAY 256 OF Images.Pixel;   (* Cache for Images *)
		used*: INTEGER;
		first*, last*: INTEGER
	END;
	NewColMsg* = RECORD (Objects.ObjMsg)
		pal*: Palette
	END;
	GetColMsg* = RECORD (Objects.ObjMsg)
		pal*: Palette
	END;

VAR
	standard1*, standard2*, current*: Palette;  index: Colors.Index;   (* current needed for Plot Routines to be called by Oberon.Call *)

	PROCEDURE PHandleFileMsg( obj: Palette;  VAR msg: Objects.FileMsg );
	VAR objsub: Objects.Object;  i: INTEGER;  r, g, b: REAL;  version: INTEGER;
	BEGIN
		IF msg.id = Objects.store THEN
			Files.WriteInt( msg.R, 0 );   (* version id *)
			vyBase.objecthandle( obj, msg );  Files.WriteInt( msg.R, obj.used );
			FOR i := 0 TO obj.used - 1 DO Gadgets.WriteRef( msg.R, obj.lib, obj.col[i] ) END;
			Files.WriteInt( msg.R, obj.first );  Files.WriteInt( msg.R, obj.last )
		ELSIF msg.id = Objects.load THEN
			Files.ReadInt( msg.R, version );  vyBase.objecthandle( obj, msg );  Files.ReadInt( msg.R, obj.used );
			FOR i := 0 TO obj.used - 1 DO
				Gadgets.ReadRef( msg.R, obj.lib, objsub );
				WITH objsub: Colors.Color DO
					obj.col[i] := objsub;  Colors.GetDisplay( obj.col[i], obj.dcol[i] );  Colors.GetRGB( obj.col[i], r, g, b );
					Images.SetRGB( obj.icol[i], SHORT( ENTIER( r * 255 + 0.5 ) ), SHORT( ENTIER( g * 255 + 0.5 ) ), SHORT( ENTIER( b * 255 + 0.5 ) ) );
				END;
			END;
			Files.ReadInt( msg.R, obj.first );  Files.ReadInt( msg.R, obj.last );
		ELSE vyBase.objecthandle( obj, msg )
		END
	END PHandleFileMsg;

	PROCEDURE PHandleAttributes( obj: Palette;  VAR M: Objects.AttrMsg );
	BEGIN
		IF M.id = Objects.enum THEN M.Enum( "Gen" );  M.Enum( "first" );  M.Enum( "last" );  vyBase.objecthandle( obj, M )
		ELSIF M.id = Objects.get THEN
			IF M.name = "Gen" THEN COPY( 'vyColorPalettes.PNew', M.s );  M.class := Objects.String;  M.res := 0
			ELSIF M.name = "first" THEN M.i := obj.first;  M.class := Objects.Int;  M.res := 0;
			ELSIF M.name = "last" THEN M.i := obj.last;  M.class := Objects.Int;  M.res := 0;
			ELSE vyBase.objecthandle( obj, M )
			END
		ELSIF M.id = Objects.set THEN
			IF M.name = "first" THEN
				IF M.class = Objects.Int THEN
					IF (0 <= M.i) & (M.i <= 255) THEN obj.first := SHORT( M.i );  M.res := 0;  vyBase.Update( obj );  END;
				END;
			ELSIF M.name = "last" THEN
				IF M.class = Objects.Int THEN
					IF (0 <= M.i) & (M.i <= 255) THEN obj.last := SHORT( M.i );  M.res := 0;  vyBase.Update( obj );  END;
				END;
			ELSE vyBase.objecthandle( obj, M );
			END;
		ELSE vyBase.objecthandle( obj, M )
		END
	END PHandleAttributes;

	PROCEDURE PHandler*( obj: Objects.Object;  VAR msg: Objects.ObjMsg );
	VAR i: INTEGER;
	BEGIN
		WITH obj: Palette DO
			IF msg IS vyBase.UpdateMessage THEN
				WITH msg: vyBase.UpdateMessage DO vyBase.objecthandle( obj, msg );
				END;
			ELSIF msg IS Objects.AttrMsg THEN
				WITH msg: Objects.AttrMsg DO PHandleAttributes( obj, msg );
				END;
			ELSIF msg IS Objects.FileMsg THEN
				WITH msg: Objects.FileMsg DO PHandleFileMsg( obj, msg )
				END;
			ELSIF msg IS Objects.LinkMsg THEN
				WITH msg: Objects.LinkMsg DO vyBase.objecthandle( obj, msg );
				END;
			ELSIF msg IS Objects.BindMsg THEN
				WITH msg: Objects.BindMsg DO
					vyBase.objecthandle( obj, msg );
					FOR i := 0 TO obj.used - 1 DO Gadgets.BindObj( obj.col[i], msg.lib );  END;
				END;
			ELSE vyBase.objecthandle( obj, msg )
			END
		END
	END PHandler;

	PROCEDURE PNew*;
	VAR p: Palette;
	BEGIN
		NEW( p );  p.handle := PHandler;  Objects.NewObj := p;
	END PNew;

	PROCEDURE SetCol*( p: Palette;  index: INTEGER;  col: LONGINT );
	VAR r, g, b: REAL;
	BEGIN
		IF index < p.used THEN
			p.dcol[index] := col;  Colors.SetDisplay( p.col[index], col );  Colors.GetRGB( p.col[index], r, g, b );
			Images.SetRGB( p.icol[index], SHORT( ENTIER( r * 255 + 0.5 ) ), SHORT( ENTIER( g * 255 + 0.5 ) ), SHORT( ENTIER( b * 255 + 0.5 ) ) );  vyBase.Update( p );
		END;
	END SetCol;

	PROCEDURE GetRGBI( c: Colors.Color;  VAR r, g, b: INTEGER );
	VAR rr, gr, br: REAL;
	BEGIN
		Colors.GetRGB( c, rr, gr, br );  r := SHORT( ENTIER( rr * 255 + 0.5 ) );  g := SHORT( ENTIER( gr * 255 + 0.5 ) );  b := SHORT( ENTIER( br * 255 + 0.5 ) );
	END GetRGBI;

	PROCEDURE RGBPath*( p: Palette;  first, last: INTEGER;  r1, g1, b1, r2, g2, b2: REAL );
	VAR r, g, b: REAL;  i: INTEGER;
	BEGIN
		FOR i := first TO last DO
			r := r1 + (r2 - r1) * (i - first) / (last - first);  g := g1 + (g2 - g1) * (i - first) / (last - first);
			b := b1 + (b2 - b1) * (i - first) / (last - first);  Colors.SetRGB( p.col[i], r, g, b );
			Colors.GetDisplay( p.col[i], p.dcol[i] );
			Images.SetRGB( p.icol[i], SHORT( ENTIER( r * 255 + 0.5 ) ), SHORT( ENTIER( g * 255 + 0.5 ) ), SHORT( ENTIER( b * 255 + 0.5 ) ) );
		END;
		vyBase.Update( p );
	END RGBPath;

	PROCEDURE ShiftPath*( p: Palette;  tofirst, tolast: INTEGER );
	VAR r, g, b: REAL;  i: INTEGER;  r1, r2, g1, g2, b1, b2: REAL;
	BEGIN
		Colors.GetRGB( p.col[p.first], r1, g1, b1 );  Colors.GetRGB( p.col[p.last], r2, g2, b2 );  p.first := tofirst;  p.last := tolast;
		FOR i := p.first TO p.last DO
			r := r1 + (r2 - r1) * (i - p.first) / (p.last - p.first);  g := g1 + (g2 - g1) * (i - p.first) / (p.last - p.first);
			b := b1 + (b2 - b1) * (i - p.first) / (p.last - p.first);  Colors.SetRGB( p.col[i], r, g, b );
			Colors.GetDisplay( p.col[i], p.dcol[i] );
			Images.SetRGB( p.icol[i], SHORT( ENTIER( r * 255 + 0.5 ) ), SHORT( ENTIER( g * 255 + 0.5 ) ), SHORT( ENTIER( b * 255 + 0.5 ) ) );
		END;
	END ShiftPath;

	PROCEDURE PathFromTo*( from, to: Palette );
	VAR this, i: INTEGER;  r, g, b: REAL;  dcol: LONGINT;
	BEGIN
		FOR i := to.first TO to.last DO
			this := SHORT( ENTIER( from.first + (i - to.first) / (to.last - to.first) * (from.last - from.first) + 0.5 ) );
			Colors.GetRGB( from.col[this], r, g, b );  Colors.SetRGB( to.col[i], r, g, b );  Colors.GetDisplay( from.col[this], dcol );
			to.dcol[i] := dcol;  Images.SetRGB( to.icol[i], SHORT( ENTIER( r * 255 + 0.5 ) ), SHORT( ENTIER( g * 255 + 0.5 ) ), SHORT( ENTIER( b * 255 + 0.5 ) ) );
		END;
		vyBase.Update( to );
	END PathFromTo;

	PROCEDURE DefaultPath*( p: Palette );
	BEGIN
		PathFromTo( standard1, p );
	END DefaultPath;

	PROCEDURE DefaultPath2*( p: Palette );
	BEGIN
		PathFromTo( standard2, p );
	END DefaultPath2;

	PROCEDURE CopyPalette*( from, to: Palette );
	BEGIN
		to.col := from.col;  to.dcol := from.dcol;  to.icol := from.icol;  to.used := from.used;  to.first := from.first;
		to.last := from.last;
	END CopyPalette;

	PROCEDURE InitConversion*( depth: LONGINT;  VAR p: Palette );
	VAR i: INTEGER;
		r, g, b: ARRAY 256 OF INTEGER;
	BEGIN
		NEW( p );  InitPalette( p );  p.first := 0;  p.last := SHORT( depth - 1 );  DefaultPath( p );
		FOR i := 0 TO p.last DO GetRGBI( p.col[i], r[i], g[i], b[i] );  END;
		Colors.MakeIndex( index, 8, p.last + 1, r, g, b );   (* fof, changed Bits from 4 to 8 *)
	END InitConversion;

	PROCEDURE Convert*( r, g, b: INTEGER ): LONGINT;
	BEGIN
		RETURN Colors.Match( index, 8, r, g, b );
	END Convert;

	PROCEDURE InitPalette*( p: Palette );
	VAR i: INTEGER;  r, g, b: REAL;
	BEGIN
		p.handle := PHandler;
		FOR i := 0 TO 255 DO
			NEW( p.col[i] );  Colors.InitHSV( p.col[i], i / 255 * 1 / 360 * 225, 1, 1 );  Colors.GetDisplay( p.col[i], p.dcol[i] );
			Colors.GetRGB( p.col[i], r, g, b );
			Images.SetRGBA( p.icol[i], SHORT( ENTIER( r * 255 + 0.5 ) ), SHORT( ENTIER( g * 255 + 0.5 ) ), SHORT( ENTIER( b * 255 + 0.5 ) ), 255 );
		END;
		p.used := 256;  p.last := 255;  p.first := 0;
	END InitPalette;

BEGIN
	NEW( standard1 );  InitPalette( standard1 );  RGBPath( standard1, 0, 255, 0, 0, 0, 1, 1, 1 );  NEW( standard2 );
	InitPalette( standard2 );
END vyColorPalettes.
