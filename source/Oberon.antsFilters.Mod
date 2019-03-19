MODULE antsFilters IN Oberon;   (** fof  **)
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




IMPORT antsFunctions, antsCommands, vyBase, Objects, antsSecurity, antsArrayObjects, vyName, antsPlots,
	antsNeighbourhoods, Math := MathL IN A2, vyRandom, vyLongreal, Files, Gadgets, antsObjects, antsToolbox, Attributes, Strings,
	vyInteger, aM := antsMessages;

TYPE

	tFilter* = POINTER TO tFilterDesc;
	tFilterDesc* = RECORD (vyBase.ObjDesc);
		weights: antsNeighbourhoods.Neighbours;
		fct: antsFunctions.Function;
		(* size: LONGINT; *)  (* is dim of Nieghbourhood *)
		type: INTEGER (* mean or median *)
	END;

CONST
	mean = 0;  median = 1;  inf = 2;  sup = 3;

	PROCEDURE HandleFileMsg( obj: tFilter;  VAR msg: Objects.FileMsg );
	VAR objsub: Objects.Object;  version: INTEGER;
	BEGIN
		IF msg.id = Objects.load THEN
			Files.ReadInt( msg.R, version );  vyBase.objecthandle( obj, msg );  Files.ReadInt( msg.R, obj.type );
			Gadgets.ReadRef( msg.R, obj.lib, objsub );
			IF objsub # NIL THEN obj.weights := objsub( antsNeighbourhoods.Neighbours ) ELSE obj.weights := NIL END;
			Gadgets.ReadRef( msg.R, obj.lib, objsub );
			IF objsub # NIL THEN obj.fct := objsub( antsFunctions.Function ) ELSE obj.fct := NIL END
		ELSIF msg.id = Objects.store THEN
			Files.WriteInt( msg.R, 0 );  vyBase.objecthandle( obj, msg );  Files.WriteInt( msg.R, obj.type );
			Gadgets.WriteRef( msg.R, obj.lib, obj.weights );  Gadgets.WriteRef( msg.R, obj.lib, obj.fct )
		ELSE vyBase.objecthandle( obj, msg )
		END
	END HandleFileMsg;

	PROCEDURE HandleLinks( obj: tFilter;  VAR msg: Objects.LinkMsg );
	BEGIN
		IF msg.id = Objects.enum THEN msg.Enum( "weights" );  msg.Enum( "function" );  vyBase.objecthandle( obj, msg )
		ELSIF msg.id = Objects.get THEN
			IF msg.name = "weights" THEN msg.obj := obj.weights;  msg.res := 0
			ELSIF msg.name = "function" THEN msg.obj := obj.fct;  msg.res := 0
			ELSE vyBase.objecthandle( obj, msg )
			END
		ELSE vyBase.objecthandle( obj, msg )
		END
	END HandleLinks;

	PROCEDURE HandleAttributes( obj: tFilter;  VAR msg: Objects.AttrMsg );
	BEGIN
		IF msg.id = Objects.enum THEN msg.Enum( "type" );  vyBase.objecthandle( obj, msg )
		ELSIF msg.id = Objects.get THEN
			IF msg.name = "Gen" THEN msg.s := "antsFilters.Gen";  msg.class := Objects.String;  msg.res := 0
			ELSIF msg.name = "type" THEN
				IF obj.type = median THEN msg.s := "median";  msg.class := Objects.String;  msg.res := 0
				ELSIF obj.type = mean THEN msg.s := "mean";  msg.class := Objects.String;  msg.res := 0
				ELSIF obj.type = inf THEN msg.s := "inf";  msg.class := Objects.String;  msg.res := 0
				ELSIF obj.type = sup THEN msg.s := "sup";  msg.class := Objects.String;  msg.res := 0

				END
			ELSE vyBase.objecthandle( obj, msg )
			END
		ELSIF msg.id = Objects.set THEN
			IF msg.name = "type" THEN
				IF msg.class = Objects.String THEN
					IF msg.s = "median" THEN obj.type := median;  msg.res := 0;  WeightsToMedian( obj );  vyBase.Update( obj );
					ELSIF msg.s = "inf" THEN obj.type := inf;  msg.res := 0;  WeightsToMedian( obj );  vyBase.Update( obj );
					ELSIF msg.s = "sup" THEN obj.type := sup;  msg.res := 0;  WeightsToMedian( obj );  vyBase.Update( obj );
					ELSIF msg.s = "mean" THEN obj.type := mean;  msg.res := 0;  vyBase.Update( obj );
					END
				END
			ELSE vyBase.objecthandle( obj, msg )
			END
		ELSE vyBase.objecthandle( obj, msg )
		END

	END HandleAttributes;

	PROCEDURE Handler*( obj: Objects.Object;  VAR msg: Objects.ObjMsg );
	BEGIN
		WITH obj: tFilter DO
			IF msg IS Objects.AttrMsg THEN
				WITH msg: Objects.AttrMsg DO HandleAttributes( obj, msg )
				END;
			ELSIF msg IS Objects.FileMsg THEN
				WITH msg: Objects.FileMsg DO HandleFileMsg( obj, msg )
				END;
			ELSIF msg IS Objects.LinkMsg THEN
				WITH msg: Objects.LinkMsg DO HandleLinks( obj, msg )
				END;
			ELSIF msg IS Objects.BindMsg THEN
				WITH msg: Objects.BindMsg DO
					IF obj.lib # msg.lib THEN
						vyBase.objecthandle( obj, msg );  antsObjects.Bind( obj.weights, msg );  antsObjects.Bind( obj.fct, msg )
					END
				END;
			ELSE vyBase.objecthandle( obj, msg )
			END
		END
	END Handler;

	PROCEDURE Gen*;
	VAR f: tFilter;
	BEGIN
		NEW( f );  f.handle := Handler;  f.type := mean;  Objects.NewObj := f
	END Gen;

	PROCEDURE New*;
	VAR obj: vyBase.Object;  f: tFilter;
		name: ARRAY 256 OF CHAR;
	BEGIN
		antsCommands.InitScan( "name=NAME weights=OBJ [>median] [function=OBJ] # Create new filter with weights (antsNeighbourhoods.Neighbours) <weights>" );
		IF antsCommands.ExpectName( "name", name ) & antsCommands.ExpectObject( "weights", obj ) THEN
			Gen;  f := Objects.NewObj( tFilter );  vyName.RegisterNamed( f, name );
			f.weights := obj( antsNeighbourhoods.Neighbours );  vyBase.Subscribe( f.weights, f );
			IF antsCommands.Find( "median" ) THEN f.type := median;  aM.S( "Installed a median filter" ) END;
			IF antsCommands.GetObject( "function", obj ) THEN f.fct := obj( antsFunctions.Function );  vyBase.Subscribe( f.fct, f ) END
		END
	END New;

	PROCEDURE ksmallest( VAR a: ARRAY OF LONGREAL;  n, k: LONGINT ): LONGREAL;
	(* algorithm of Nikolaus Wirth *)
	VAR i, j, l, m: LONGINT;  x: LONGREAL;

		PROCEDURE swap( VAR x, y: LONGREAL );
		VAR z: LONGREAL;
		BEGIN
			z := x;  x := y;  y := z
		END swap;

	BEGIN
		l := 0;  m := n - 1;
		WHILE (l < m) DO
			x := a[k];  i := l;  j := m;
			REPEAT
				WHILE (a[i] < x) DO INC( i ) END;
				WHILE (x < a[j]) DO DEC( j ) END;
				IF i <= j THEN swap( a[i], a[j] );  INC( i );  DEC( j ) END
			UNTIL i > j;
			IF j < k THEN l := i END;
			IF k < i THEN m := j END
		END;
		RETURN a[k]
	END ksmallest;

	PROCEDURE Median( VAR a: ARRAY OF LONGREAL;  n: LONGINT ): LONGREAL;
	BEGIN
		RETURN ksmallest( a, n, n DIV 2 )
	END Median;

	PROCEDURE WeightsToMedian( filter: tFilter );
	VAR i: LONGINT;
	BEGIN
		FOR i := 0 TO (filter.weights.dim - 1) DO
			IF filter.weights.par[i] > 0 THEN filter.weights.par[i] := 1 ELSE filter.weights.par[i] := 0 END
		END;
		antsNeighbourhoods.FillCache( filter.weights );  vyBase.Update( filter.weights )
	END WeightsToMedian;

	PROCEDURE ApplyFilter( A: antsArrayObjects.tINTEGERArray;  VAR res: antsArrayObjects.tINTEGERArray;  filter: tFilter );
	VAR W, H: LONGINT;  weight, weights, value: LONGREAL;  wx, wy, y, x, count, len: LONGINT;
		a: POINTER TO ARRAY OF LONGREAL;
	BEGIN
		W := LEN( A[0] );  H := LEN( A );  NEW( res, H, W );
		IF filter.type = mean THEN

			FOR y := 0 TO H - 1 DO
				FOR x := 0 TO W - 1 DO
					weights := 0;  value := 0;
					FOR count := 0 TO filter.weights.clen - 1 DO
						wy := (filter.weights.cy[count] + y);  wx := (filter.weights.cx[count] + x);
						IF (wx >= 0) & (wx < W) & (wy >= 0) & (wy < H) THEN
							weight := filter.weights.cpar[count];  weights := weights + ABS( weight );
							value := value + weight * A[wy, wx]
						END
					END;
					res[y, x] := SHORT( ENTIER( value / weights + 0.5 ) )
				END
			END

		ELSIF (filter.type = median) OR (filter.type = inf) OR (filter.type = sup) THEN WeightsToMedian( filter );
			(* do that for intuitive reasons, only on / off allowed *)

			NEW( a, filter.weights.clen );
			FOR y := 0 TO H - 1 DO
				FOR x := 0 TO W - 1 DO
					len := 0;
					FOR count := 0 TO filter.weights.clen - 1 DO
						wy := (filter.weights.cy[count] + y);  wx := (filter.weights.cx[count] + x);
						IF (wx >= 0) & (wx < W) & (wy >= 0) & (wy < H) THEN
							weight := filter.weights.cpar[count];   (* what is a weighted median ?? *)
							IF weight > 0 THEN a[len] := A[wy, wx];  INC( len ) END
							(*
						weight := filter.weights.cpar[count];
						weights := weights+weight;
						value := value + weight * A[wy,wx];
						*)
						END
					END;
					IF filter.type = median THEN res[y, x] := SHORT( ENTIER( Median( a^, len ) + 0.5 ) )
					ELSIF filter.type = inf THEN res[y, x] := SHORT( ENTIER( ksmallest( a^, len, 0 ) + 0.5 ) )
					ELSIF filter.type = sup THEN res[y, x] := SHORT( ENTIER( ksmallest( a^, len, len - 1 ) + 0.5 ) )
					END
				END
			END

		END

	END ApplyFilter;

(*bestimmt den min und max Eintrag in der Matrix S (und deren Position)*)
	PROCEDURE MinMax( VAR S: ARRAY OF ARRAY OF INTEGER;  VAR min, max: INTEGER );
	VAR h, i, minpos, currentminpos, maxpos, currentmaxpos, na: LONGINT;  currentmax, currentmin: INTEGER;
	BEGIN
		h := LEN( S );  min := MAX( INTEGER );  max := MIN( INTEGER );
		FOR i := 0 TO h - 1 DO
			vyInteger.MinMax( LEN( S[i] ), S[i], 0, currentmin, currentminpos, currentmax, currentmaxpos, na );
			IF currentmin < min THEN min := currentmin;  minpos := currentminpos END;
			IF currentmax > max THEN max := currentmax;  maxpos := currentmaxpos END
		END
	END MinMax;

	PROCEDURE Rescale*( A: antsArrayObjects.tINTEGERArray;  VAR depth: LONGINT );
	VAR min, max: INTEGER;  y, x: LONGINT;
	BEGIN
		MinMax( A^, min, max );
		IF (min >= 0) & (max < depth) THEN RETURN END;
		FOR y := 0 TO LEN( A ) - 1 DO
			FOR x := 0 TO LEN( A[0] ) - 1 DO A[y, x] := A[y, x] - min END
		END;
		depth := max - min + 1
	END Rescale;

	PROCEDURE ApplyFilters( A: antsArrayObjects.tINTEGERArray;  VAR res: antsArrayObjects.tINTEGERArray;  filter: tFilter;
										    VAR depth: LONGINT;  VAR name: ARRAY OF CHAR );
	VAR filtername: ARRAY 256 OF CHAR;
	BEGIN
		IF antsCommands.GetName( "", filtername ) THEN
			REPEAT
				Attributes.SetString( filter, "type", filtername );  Strings.Append( name, filtername );  Strings.Append( name, "," );
				ApplyFilter( A, res, filter );
				(*
			antsArrayObjects.CopyIR(res, A, 0, 0, LEN(res[0]), LEN(res), 0, 0)
			*)
			UNTIL ~antsCommands.GetName( "", filtername );
			Gadgets.Update( filter )
		ELSE ApplyFilter( A, res, filter );  Attributes.GetString( filter, "type", filtername );  Strings.Append( name, filtername )
		END;
		Rescale( res, depth )
	END ApplyFilters;

	PROCEDURE Apply*;
	VAR obj, array: vyBase.Object;  A: antsArrayObjects.tLONGREALArray;  res: antsArrayObjects.tINTEGERArray;
		name, type: ARRAY 256 OF CHAR;
		depth: LONGINT;
	BEGIN
		antsCommands.InitScan( "filter=OBJ [type=STR] [array=OBJ]" );
		IF antsCommands.ExpectObject( "filter", obj ) THEN
			Attributes.GetString( obj, "type", type );
			name := "filtered image:";   (* Strings.Append(name,type); *)

			IF antsCommands.GetObject( "array", array ) & (array IS antsArrayObjects.tINTEGERObject) THEN ELSE
				IF array # NIL THEN DEC( antsCommands.lastScanned.spos ) END;
				array := antsToolbox.InteractiveGetArray()
			END;

			IF array # NIL THEN
				IF array IS antsArrayObjects.tINTEGERObject THEN
					WITH array: antsArrayObjects.tINTEGERObject DO
					(*
				antsArrayObjects.CopyIR(array.A, A, 0, 0, array.w, array.h, 0, 0);
				*)
						depth := array.depth;
						ApplyFilters( array.A, res, obj( tFilter ), depth, name );   (* A -> array *)
						aM.dSI( "depth = ", depth );  antsPlots.ShowArray( antsArrayObjects.IntObj( res, depth ), type, FALSE , FALSE );
						IF depth # array.depth THEN Strings.Append( name, "(rescaled !)" ) END;
						antsToolbox.NameOpened( name )
					END;
				ELSE antsSecurity.Halt( "antsArrayObjects.tINTEGERObject expected" )
				END

			END
		END
	END Apply;

	PROCEDURE Constant*;
	VAR obj: vyBase.Object;  weights: antsNeighbourhoods.Neighbours;  i: LONGINT;
	BEGIN
		IF antsCommands.ExpectObject( "weights", obj ) THEN
			weights := obj( antsNeighbourhoods.Neighbours );
			FOR i := 0 TO weights.dim - 1 DO weights.par[i] := 1 END;
			antsNeighbourhoods.FillCache( weights );  vyBase.Update( weights )
		END
	END Constant;

	PROCEDURE DoApplyFunction( f: tFilter );
	VAR xd, yd: LONGINT;  i: LONGINT;
	BEGIN
		IF f.fct = NIL THEN antsSecurity.Halt( "No function defined" ) END;
		FOR i := 0 TO f.weights.dim - 1 DO
			dist( f.weights, i, xd, yd );  f.weights.par[i] := f.fct.get( f.fct, Math.sqrt( (xd * xd) + (yd * yd) ) );
		END;
		antsNeighbourhoods.FillCache( f.weights );  vyBase.Update( f.weights );
	END DoApplyFunction;

	PROCEDURE ApplyFunction*;
	VAR obj: vyBase.Object;
	BEGIN
		antsCommands.InitScan( "filter=OBJ" );
		IF antsCommands.ExpectObject( "filter", obj ) THEN
			IF obj IS tFilter THEN
				WITH obj: tFilter DO DoApplyFunction( obj );
				END;
			ELSE antsSecurity.Halt( "obj IS no tFilter" );
			END;
		END;
	END ApplyFunction;

	PROCEDURE dist( n: antsNeighbourhoods.Neighbours;  pos: LONGINT;  VAR xd, yd: LONGINT );
	BEGIN
		xd := n.x[pos, 0];  yd := n.y[pos, 0];
	END dist;

	PROCEDURE Inverse*;
	VAR obj: vyBase.Object;  weights: antsNeighbourhoods.Neighbours;  i: LONGINT;  xd, yd: LONGINT;
	BEGIN
		antsCommands.InitScan( "weights=OBJ # Set weights according to their inverse distance" );
		IF antsCommands.ExpectObject( "weights", obj ) THEN
			weights := obj( antsNeighbourhoods.Neighbours );
			FOR i := 0 TO weights.dim - 1 DO
				dist( weights, i, xd, yd );  weights.par[i] := 1 / (1 + Math.sqrt( (xd * xd) + (yd * yd) ));
			END;
			antsNeighbourhoods.FillCache( weights );  vyBase.Update( weights );
		END;
	END Inverse;


(*
PROCEDURE TestMedian*;
	VAR i: LONGINT;   a: POINTER TO ARRAY OF LONGREAL;
BEGIN
	NEW(a, 1001);
	FOR i := 0 TO 1000 DO
		a[i] := vyRandom.Uniform();
		Out.Ln;   Out.LongReal(a[i], 20);
	END;
	Out.Ln;   Out.String("median: ");   Out.LongReal(Median(a^, 1000), 20);
	Out.Ln;   Out.String("smallest:");   Out.LongReal(ksmallest(a^, 1000, 0), 20);
	Out.Ln;   Out.String("largest:");   Out.LongReal(ksmallest(a^, 1000, 999), 20);
	vyLongreal.Sort(1001, a^, 0);
	Out.Ln;   Out.String("median:");   Out.LongReal(a[500], 20);
END TestMedian;
*)

BEGIN
	aM.launch;
END antsFilters.

System.Free antsFilters ~

Desktops.OpenWinDoc Caracas3a.Panel ~

fofAutomatic.Do
antsFunctions.Define function ~
antsFunctions.Set function "1/(1+ABS(x))"
antsNeighbourhoods.New weights  5 > isotropic ~
antsFilters.Constant weights ~
Voyager.Show weights as antsInteractivePar ~
antsFilters.New myfilter  weights function ~
antsFilters.ApplyFunction myfilter ~
antsFilters.Apply myfilter f3Array ~
~
antsFilters.ApplyFunction
antsObjects.WriteAttribute weights dim ~
antsFilters.Constant weights ~
antsFilters.Inverse weights ~
antsFilters.Apply

fofAutomatic.Do
antsNeighbourhoods.New weights  2  > isotropic ~
antsFilters.Constant weights ~
Voyager.Show weights as antsInteractivePar ~
antsFilters.New myfilter  weights > median~
antsFilters.Apply myfilter f3Array ~
~
antsFilters.TestMedian ~



Voyager.Show function as antsFctEdit ~


Voyager.Show myfilter as antsLinkView ~


Desktops.OpenWinDoc ants / antsFilters.Panel

antsObjects.WriteAttributes myfilter ~
