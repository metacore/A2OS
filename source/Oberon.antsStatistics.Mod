MODULE antsStatistics IN Oberon;   (** fof  **)
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
(* fof: 19.08.2002, this module is unused now, very old. *)



IMPORT antsMessages, antsArrayObjects, antsCommands, vyBase, vyLongrealVec := vyRealVec, Math := MathL IN A2, antsDirSet, aM := antsMessages;

VAR
	v1, v2: vyBase.tVector;  t1d, t2d, ph1, ph2: FLOAT64;  wd, hd: SIGNED32;
	t1, t2: POINTER TO ARRAY OF FLOAT64;

	PROCEDURE bin( x: SIGNED16 ): SIGNED16;
	BEGIN
		RETURN 2 * x - 1
	END bin;

	PROCEDURE t1t2*;
	VAR l: antsCommands.tScanList;  obj: vyBase.Object;  x, y: SIGNED32;  t1, t2: FLOAT64;  b: BOOLEAN;
	BEGIN
		l := antsCommands.ScanFromPar( "from=OBJ" );  b := antsCommands.ExpectObjectFromKeyword( l, "from", obj );
		WITH obj: antsArrayObjects.tINTEGERObject DO
			t1 := 0;  t2 := 0;
			FOR y := 0 TO obj.h - 1 DO
				FOR x := 0 TO obj.w - 1 DO
					t1 := t1 + bin( obj.A[y, x] );  t2 := t2 + bin( obj.A[y, x] ) * bin( obj.A[(y - 1) MOD obj.h, x] );
					t2 := t2 + bin( obj.A[y, x] ) * bin( obj.A[(y + 1) MOD obj.h, x] );
					t2 := t2 + bin( obj.A[y, x] ) * bin( obj.A[y, (x - 1) MOD obj.w] );
					t2 := t2 + bin( obj.A[y, x] ) * bin( obj.A[y, (x + 1) MOD obj.w] )
				END
			END;
			antsMessages.SR( " ", t1 / obj.w / obj.h );  antsMessages.SR( " ", t2 / obj.w / obj.h );  antsMessages.S( "" );
			t1d := t1 / obj.w / obj.h;  t2d := t2 / obj.w / obj.h
		END
	END t1t2;

	PROCEDURE Max( x1, x2: FLOAT64 ): FLOAT64;
	BEGIN
		IF x1 > x2 THEN RETURN x1 ELSE RETURN x2 END
	END Max;

	PROCEDURE est( VAR A: ARRAY OF FLOAT64 ): FLOAT64;
	VAR i: SIGNED32;  dd: FLOAT64;  a1, a2: FLOAT64;  max, exp, val: FLOAT64;  len: SIGNED32;
	BEGIN
		a1 := A[0];  a2 := A[1];  len := vyLongrealVec.Len( v1 );
		ASSERT ( len > 0 );
		max := 0;
		FOR i := 0 TO len - 1 DO val := wd * hd * ((A[0] - ph1) * t1[i] + (A[1] - ph2) * t2[i]);  max := Max( max, val ) END;

		dd := 0;
		FOR i := 0 TO len - 1 DO
			val := wd * hd * ((A[0] - ph1) * t1[i] + (A[1] - ph2) * t2[i]);  exp := val - max;  dd := dd + Math.exp( exp )
		END;
		dd := dd / len;

		IF dd = 0 THEN RETURN -((A[0] - ph1) * t1d * wd * hd + (A[1] - ph2) * t2d * wd * hd - max)
		ELSE RETURN -((A[0] - ph1) * t1d * wd * hd + (A[1] - ph2) * t2d * wd * hd - max - Math.ln( dd ))
		END
	END est;

	PROCEDURE DefineValues*;
	VAR l: antsCommands.tScanList;  obj1, obj2: vyBase.Object;  i: SIGNED32;  b: BOOLEAN;
	BEGIN
		l := antsCommands.ScanFromPar( "t1=OBJ t2=OBJ t1d=FLOAT32 t2d=FLOAT32 wd=INT hd=INT ph1=FLOAT32 ph2=FLOAT32" );  b := antsCommands.ExpectObjectFromKeyword( l, "t1", obj1 );
		v1 := obj1( vyBase.tVector );  b := antsCommands.ExpectObjectFromKeyword( l, "t2", obj2 );  v2 := obj2( vyBase.tVector );
		b := antsCommands.ExpectRealFromKeyword( l, "t1d", t1d );  b := antsCommands.ExpectRealFromKeyword( l, "t2d", t2d );
		b := antsCommands.ExpectNumberFromKeyword( l, "wd", wd );  b := antsCommands.ExpectNumberFromKeyword( l, "hd", hd );
		b := antsCommands.ExpectRealFromKeyword( l, "ph1", ph1 );  b := antsCommands.ExpectRealFromKeyword( l, "ph2", ph2 );
		NEW( t1, vyLongrealVec.Len( v1 ) );  NEW( t2, vyLongrealVec.Len( v2 ) );
		FOR i := 0 TO vyLongrealVec.Len( v1 ) - 1 DO t1[i] := vyLongrealVec.Get( v1, i );  t2[i] := vyLongrealVec.Get( v2, i ) END
	END DefineValues;

	PROCEDURE Estimate*;
	VAR A: POINTER TO ARRAY OF FLOAT64;
		ret: FLOAT64;
	BEGIN
		NEW( A, 2 );

		A[0] := ph1;  A[1] := ph2;  antsDirSet.EasyMinimize( A^, ret, 1.0D-16, est, FALSE );  antsMessages.SR( "th1", A[0] );
		antsMessages.SR( "   th2", A[1] );  antsMessages.S( "" )
	END Estimate;

	PROCEDURE WriteOutInter*;
	VAR obj: vyBase.Object;  i, j,k : SIGNED32;  count, count2: SIGNED32;
	BEGIN
		antsCommands.InitScan( "name=OBJ" );
		IF antsCommands.ExpectObject( "name", obj ) THEN
			WITH obj: antsArrayObjects.tINTEGERObject DO
				count := 0;  count2 := 0;
				FOR j := 0 TO obj.h - 1 DO
					FOR i := 0 TO obj.w - 1 DO
						k := (j - 1) MOD obj.h;
						IF obj.A[j, i] = obj.A[k, i] THEN INC( count ) END;
						k := (i - 1) MOD obj.h;
						IF obj.A[j, i] = obj.A[j, k] THEN INC( count ) END;
						INC( count2, 2 )
					END
				END;
					antsMessages.SR( "", count / count2 )
			END
		END
	END WriteOutInter;


BEGIN
	aM.launch;
END antsStatistics.

fofAutomatic.Do
System.Time
antsDiscreteFields.NewArray > name Array > size 30 30 > depth 2~
antsViews.Show > name Array ~
antsBinaryIsingS.NewModel > name Model  > h 0.0 > beta 0.5 ~
antsGibbs.Attach > model Model > array Array ~
antsGibbs.DefineGibbsSampler > name Sampler > model Model > presteps 0 > steps 10 ~
antsGibbs.Step > sampler Sampler > times 10 ~
System.Time
~

fofAutomatic.Do > iter 30
antsGibbs.DefineGibbsSampler > name Sampler > model Model > presteps 500 > steps 50 ~
antsGibbs.Step > sampler Sampler > times 1 ~
antsStatistics.t1t2 > from Array ~
~

SET CARET !!

Voyager.ReadTable
t1 t2
8.4444445E - 01        3.2622223E + 00
7.9777777E - 01        3.2977779E + 00
 - 9.1111112E - 01        3.5022223E + 00
 - 9.5555556E - 01        3.7155557E + 00
 - 9.4666666E - 01        3.6177778E + 00
 - 9.0888888E - 01        3.4044445E + 00
9.4000000E - 01        3.6533334E + 00
8.9777780E - 01        3.4755557E + 00
 - 8.8444442E - 01        3.3955555E + 00
 - 9.3555558E - 01        3.5822222E + 00
9.4666666E - 01        3.6533334E + 00
 - 8.8222224E - 01        3.3599999E + 00
9.2000002E - 01        3.5200000E + 00
 - 9.3111110E - 01        3.5555556E + 00
 - 8.6222219E - 01        3.2888889E + 00
 - 9.4222224E - 01        3.6977777E + 00
8.8000000E - 01        3.3155556E + 00
 - 8.8222224E - 01        3.4044445E + 00
 - 9.0222222E - 01        3.5022223E + 00
 - 9.4000000E - 01        3.6088889E + 00
 - 9.4000000E - 01        3.5644445E + 00
9.3111110E - 01        3.5288889E + 00
8.8666666E - 01        3.3866668E + 00
9.4222224E - 01        3.6088889E + 00
 - 8.9999998E - 01        3.4844444E + 00
 - 8.9111114E - 01        3.4133334E + 00
 - 9.2666668E - 01        3.5288889E + 00
9.2444444E - 01        3.5200000E + 00
 - 9.0444446E - 01        3.3777778E + 00
9.0666670E - 01        3.4755557E + 00
~


Voyager.Show  t1 t2 ~
vyScale.Insert
antsStatistics.DefineValues > t1 t1 > t2 t2 > t1d 1.1555555E - 01  > t2d  1.5200000E + 00  > wd 1210 > hd 1210  > ph1 0 > ph2 0.2 ~
antsStatistics.Estimate ~

fofAutomatic.Do > iter 5
antsGibbs.DefineGibbsSampler > name Sampler > model Model > presteps 300 > steps 50 ~
antsGibbs.Step > sampler Sampler > times 1 ~
antsStatistics.DefineValues > t1 t1 > t2 t2 > t1d - 5.3333335E - 02  > t2d  1.4222223E + 00  > wd 30 > hd 30  > ph1 0 > ph2 0.5 ~
antsStatistics.t1t2 > from Array ~
antsStatistics.Estimate ~
~
fofAutomatic.Do
antsBinaryIsingS.NewModel > name Model  > h 0.0 > beta 0.3
~
antsGibbs.Attach > model Model > array Array ~
antsGibbs.DefineGibbsSampler > name Sampler > model Model > presteps 0 > steps 10 ~
antsGibbs.Step > sampler Sampler > times 10 ~
antsStatistics.DefineValues > t1 t1 > t2 t2 > t1d 1.1555555E - 01  > t2d  1.5200000E + 00  > wd 30 > hd 30  > ph1 0 > ph2 0.5 ~
antsStatistics.t1t2 > from Array ~
antsStatistics.Estimate ~
antsMDimEstimator.Estimate > from Array > dim 2 > to 2  > x 0 > y 0 > w 100000 > h 100000   ~
~
