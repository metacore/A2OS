MODULE antsVecOpt IN Oberon; 	(** fof  **)
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




IMPORT vyLongrealVec, antsCommands, vyBase, vyRandom, aM := antsMessages, Objects, antsArrays, Attributes;

CONST
          cNoisedByName*= "noised by";
          cGauss*="Gauss";
          cExp*="Exponential";
          cLaplace*="Laplace";
          cUni*="Uniform";
          clocpar*="location parameter";
          cscalepar*="scale parameter";

PROCEDURE DoAddConst* (data, result: vyBase.tVector;  const: FLOAT64);
	VAR i: SIGNED32;             val: FLOAT64;
BEGIN
	WITH data: vyLongrealVec.tVector DO
		WITH result: vyLongrealVec.tVector DO
			FOR i := 0 TO vyLongrealVec.Len( data ) - 1 DO
				val := vyLongrealVec.Get( data, i );             val := val + const;
				vyLongrealVec.Set( val, result, i )
			END
		END
	END
END DoAddConst;

PROCEDURE DoAddGaussNoise* (data, degraded: vyBase.tVector;  mu, sigmasq: FLOAT64);
	VAR i: SIGNED32;             val: FLOAT64;
BEGIN
	WITH data: vyLongrealVec.tVector DO
		WITH degraded: vyLongrealVec.tVector DO
			FOR i := 0 TO vyLongrealVec.Len( data ) - 1 DO
				val := vyLongrealVec.Get( data, i );             val := val + vyRandom.Gauss( mu, sigmasq );
				vyLongrealVec.Set( val, degraded, i )
			END
		END
	END
END DoAddGaussNoise;

PROCEDURE DoAddCauchyNoise* (data, degraded: vyBase.tVector);
	VAR i: SIGNED32;             val: FLOAT64;
BEGIN
	WITH data: vyLongrealVec.tVector DO
		WITH degraded: vyLongrealVec.tVector DO
			FOR i := 0 TO vyLongrealVec.Len( data ) - 1 DO
				val := vyLongrealVec.Get( data, i );     val := val + vyRandom.Cauchy();
				vyLongrealVec.Set( val, degraded, i )
			END
		END
	END
END DoAddCauchyNoise;

PROCEDURE DoAddLaplaceNoise* (data, degraded: vyBase.tVector;             mu: FLOAT64 ); (*! exchange mu by lambda ! *)
	VAR i: SIGNED32;             val: FLOAT64;
BEGIN
	WITH data: vyLongrealVec.tVector DO
		WITH degraded: vyLongrealVec.tVector DO
			FOR i := 0 TO vyLongrealVec.Len( data ) - 1 DO
				val := vyLongrealVec.Get( data, i );
				IF vyRandom.Uniform() < 0.5 THEN  val := val + vyRandom.Exp( mu ) ELSE val := val - vyRandom.Exp( mu ) END;
				vyLongrealVec.Set( val, degraded, i )
			END
		END
	END
END DoAddLaplaceNoise;

PROCEDURE DoAddExpNoise* (data, degraded: vyBase.tVector;             mu: FLOAT64 ); (*! exchange mu by lambda ! *)
	VAR i: SIGNED32;             val: FLOAT64;
BEGIN
	WITH data: vyLongrealVec.tVector DO
		WITH degraded: vyLongrealVec.tVector DO
			FOR i := 0 TO vyLongrealVec.Len( data ) - 1 DO
				val := vyLongrealVec.Get( data, i );             val := val + vyRandom.Exp( mu );
				vyLongrealVec.Set( val, degraded, i )
			END;
			vyBase.Update( degraded )
		END
	END
END DoAddExpNoise;

PROCEDURE DoAddUniformNoise* (data, degraded: vyBase.tVector;             len: FLOAT64 );
	VAR i: SIGNED32;             val: FLOAT64;
BEGIN
	WITH data: vyLongrealVec.tVector DO
		WITH degraded: vyLongrealVec.tVector DO
			FOR i := 0 TO vyLongrealVec.Len( data ) - 1 DO
				val := vyLongrealVec.Get( data, i );
				val := val + vyRandom.Uniform() * len;
				vyLongrealVec.Set( val, degraded, i )
			END
		END
	END
END DoAddUniformNoise;


PROCEDURE Copy*;
	VAR v1, v2: vyBase.Object;
BEGIN
	antsCommands.InitScan("src=OBJ dest=OBJ ");
	IF antsCommands.ExpectObject("src", v1) & (antsCommands.ExpectObject("dest", v2)) THEN
		WITH v1: vyLongrealVec.tVector DO
			WITH v2: vyLongrealVec.tVector DO
				vyLongrealVec.CopyData(v1, v2);  vyBase.Update(v2)
			END
		END
	END
END Copy;

PROCEDURE AddGaussNoise*;
	VAR v1, v2: vyBase.Object;  var,mean: FLOAT64;
BEGIN
	antsCommands.InitScan("src=OBJ dest=OBJ var=FLOAT32 [mean=FLOAT32] [>attributes]");
	IF antsCommands.ExpectObject("src", v1) & antsCommands.ExpectObject("dest", v2) & antsCommands.ExpectReal("var", var) THEN
		mean := 0; IF antsCommands.GetReal("mean",mean) THEN END;
		DoAddGaussNoise(v1(vyBase.tVector), v2(vyBase.tVector), mean, var);
		IF antsCommands.Find("attributes") THEN
		    Attributes.SetString(v2,cNoisedByName,cGauss);
		    Attributes.SetLongReal(v2,clocpar,mean);
		    Attributes.SetLongReal(v2,cscalepar,var);
		END;
		vyBase.Update(v2)
	END
END AddGaussNoise;

PROCEDURE AddExpNoise*;
	VAR v1, v2: vyBase.Object;  par: FLOAT64;
BEGIN
	antsCommands.InitScan("src=OBJ dest=OBJ lambda=FLOAT32 [>attributes]");
	IF antsCommands.ExpectObject("src", v1) & antsCommands.ExpectObject("dest", v2) & antsCommands.ExpectReal("mu", par) THEN
		DoAddExpNoise(v1(vyBase.tVector), v2(vyBase.tVector), par);
		IF antsCommands.Find("attributes") THEN
		    Attributes.SetString(v2,cNoisedByName,cLaplace);
		    Attributes.SetLongReal(v2,clocpar,par);
		END;
		vyBase.Update(v2)
	END
END AddExpNoise;

PROCEDURE AddLaplaceNoise*;
	VAR v1, v2: vyBase.Object;  par: FLOAT64;
BEGIN
	antsCommands.InitScan("src=OBJ dest=OBJ mu=FLOAT32 [>attributes]");
	IF antsCommands.ExpectObject("src", v1) & antsCommands.ExpectObject("dest", v2) & antsCommands.ExpectReal("mu", par) THEN
		DoAddLaplaceNoise(v1(vyBase.tVector), v2(vyBase.tVector), par);
		IF antsCommands.Find("attributes") THEN
		    Attributes.SetString(v2,cNoisedByName,cLaplace);
		    Attributes.SetLongReal(v2,clocpar,par);
		END;
		vyBase.Update(v2)
	END
END AddLaplaceNoise;

PROCEDURE AddUniformNoise*;
	VAR v1, v2: vyBase.Object;  par: FLOAT64;
BEGIN
	antsCommands.InitScan("src=OBJ dest=OBJ len=FLOAT32 [>attributes]");
	IF antsCommands.ExpectObject("src", v1) & antsCommands.ExpectObject("dest", v2) & antsCommands.ExpectReal("len", par) THEN
		DoAddUniformNoise(v1(vyBase.tVector), v2(vyBase.tVector), par);
		IF antsCommands.Find("attributes") THEN
		    Attributes.SetString(v2,cNoisedByName,cUni);
		    Attributes.SetLongReal(v2,clocpar,par);
		END;
		vyBase.Update(v2)
	END
END AddUniformNoise;

PROCEDURE AddConst*;
	VAR v1, v2: vyBase.Object;  var: FLOAT64;
BEGIN
	antsCommands.InitScan("src=OBJ dest=OBJ const=FLOAT32");
	IF antsCommands.ExpectObject("src", v1) & antsCommands.ExpectObject("dest", v2) & antsCommands.ExpectReal("const", var) THEN
		DoAddConst(v1(vyBase.tVector), v2(vyBase.tVector), var);
		vyBase.Update(v2)
	END
END AddConst;

PROCEDURE Mean (VAR a: ARRAY OF FLOAT64;   n: SIGNED32): FLOAT64;
	VAR sum: FLOAT64;  i: SIGNED32;
BEGIN
	sum := 0;
	FOR i := 0 TO n - 1 DO
		sum := sum + a[i]
	END;
	RETURN sum / n
END Mean;

PROCEDURE DoUMA (len: SIGNED32;   v: vyLongrealVec.tVector);
	VAR a, to: POINTER TO ARRAY OF FLOAT64;  i, j, mlen, vlen: SIGNED32;
BEGIN
	NEW(a, 2 * len + 1);   vlen := vyLongrealVec.Len(v);
	NEW(to, vlen);
	FOR i := 0 TO vlen - 1 DO
		mlen := 0;
		FOR j := - len TO len DO
			IF (i + j >= 0) & (i + j < vlen) THEN
				a[mlen] := vyLongrealVec.Get(v, j + i);
				INC(mlen)
			END
		END;
		to[i] := Mean(a^, mlen)
	END;
	vyLongrealVec.CopyToVec(to^, v, vlen, 0, 0)
END DoUMA;

PROCEDURE UniformMovingAverage*;
	VAR v1, v2: vyBase.Object;  i, iter, len: SIGNED32;
BEGIN
	antsCommands.InitScan("src=OBJ dest=OBJ len=INT iter=INT");
	IF antsCommands.ExpectObject("src", v1) & antsCommands.ExpectObject("dest", v2)  & antsCommands.ExpectNumber("len", len) &
	antsCommands.ExpectNumber("iter", iter) THEN
		WITH v1: vyLongrealVec.tVector DO
			WITH v2: vyLongrealVec.tVector DO
				vyLongrealVec.CopyData(v1, v2);
				FOR i := 1 TO iter DO DoUMA(len, v2) END;
				vyBase.Update(v2)
			END
		END
	END
END UniformMovingAverage;


(* Median Filter with cut data *)
PROCEDURE DoCutMedian* (len: SIGNED32;  v: vyLongrealVec.tVector);
	VAR a, to: POINTER TO ARRAY OF FLOAT64;  i, j, mlen, vlen: SIGNED32;
BEGIN
	NEW(a, 2 * len + 1);   vlen := vyLongrealVec.Len(v);
	NEW(to, vlen);
	FOR i := 0 TO vlen - 1 DO
		mlen := 0;
		FOR j := - len TO len DO
			IF (i + j >= 0) & (i + j < vlen) THEN
				a[mlen] := vyLongrealVec.Get(v, j + i);
				INC(mlen)
			END
		END;
		to[i] := antsArrays.Median1dX(a^, mlen)
	END;
	vyLongrealVec.CopyToVec(to^, v, vlen, 0, 0)
END DoCutMedian;

(**************************************************************************************)
(*realization of median filter of length len, data are tapered (mirrored) at the boundaries *)
PROCEDURE DoTaperedMedian* ( len: SIGNED32;  v: vyLongrealVec.tVector );
	VAR x: POINTER TO ARRAY OF FLOAT64;
	i, j, N: SIGNED32;
BEGIN
	NEW( x, len );             N := vyLongrealVec.Len( v( vyLongrealVec.tVector ) );
	FOR i := 0 TO len DIV 2 - 1 DO
		FOR j := 0 TO len - 1 DO x[j] := vyLongrealVec.Get( v, ABS( i + j - len DIV 2 ) )          END;
		vyLongrealVec.Set( antsArrays.Median1dX(x^, len), v, i )
	END;
	FOR i := len DIV 2 TO N - 1 - len DIV 2 DO
		FOR j := 0 TO len - 1 DO x[j] := vyLongrealVec.Get( v, i + j - len DIV 2 )          END;
		vyLongrealVec.Set( antsArrays.Median1dX(x^, len), v, i )
	END;
	FOR i := N - len DIV 2 TO N - 1 DO
		FOR j := 0 TO len - 1 DO x[j] := vyLongrealVec.Get( v, N - 1 - ABS( i + j - len DIV 2 - N - 1 ) )          END;
		vyLongrealVec.Set( antsArrays.Median1dX(x^, len), v, i )
	END
END DoTaperedMedian;

PROCEDURE MedianFilter*;
	VAR v1, v2: vyBase.Object;  i, iter, len: SIGNED32;
BEGIN
	antsCommands.InitScan("src=OBJ dest=OBJ len=INT iter=INT");
	IF antsCommands.ExpectObject("src", v1) & antsCommands.ExpectObject("dest", v2) & antsCommands.ExpectNumber("len", len) &
	antsCommands.ExpectNumber("iter", iter) THEN
		WITH v1: vyLongrealVec.tVector DO
			WITH v2: vyLongrealVec.tVector DO
				vyLongrealVec.CopyData(v1, v2);
				FOR i := 1 TO iter DO DoCutMedian(len, v2) END;
				vyBase.Update(v2)
			END
		END
	END
END MedianFilter;

PROCEDURE TaperedMedianFilter*;
	VAR v1, v2: vyBase.Object;  i, iter, len: SIGNED32;
BEGIN
	antsCommands.InitScan("src=OBJ dest=OBJ len=INT iter=INT");
	IF antsCommands.ExpectObject("src", v1) & antsCommands.ExpectObject("dest", v2) & antsCommands.ExpectNumber("len", len) & antsCommands.ExpectNumber("iter", iter) THEN
		WITH v1: vyLongrealVec.tVector DO
			WITH v2: vyLongrealVec.tVector DO
				vyLongrealVec.CopyData(v1, v2);
				FOR i := 1 TO iter DO DoTaperedMedian(len, v2) END;
				vyBase.Update(v2)
			END
		END
	END
END TaperedMedianFilter;


PROCEDURE AppendValue*;
	VAR v, obj: vyBase.Object;  name: ARRAY 256 OF CHAR;  msg: Objects.AttrMsg;
BEGIN
	antsCommands.InitScan("src=OBJ attribute=NAME dest=OBJ");
	IF antsCommands.ExpectObject("src", obj) & antsCommands.ExpectName("attribute", name) &
		antsCommands.ExpectObject("dest", v) THEN
		WITH v: vyLongrealVec.tVector DO
			msg.id := Objects.get;  COPY(name, msg.name);  msg.res := - 1;
			obj.handle(obj, msg);
			IF msg.res = 0 THEN
				IF msg.class = Objects.Int THEN
					vyLongrealVec.Append(msg.i, v)
				ELSIF msg.class = Objects.LongReal THEN
					vyLongrealVec.Append(msg.y, v)
				ELSIF msg.class = Objects.Real THEN
					vyLongrealVec.Append(msg.x, v)
				ELSE
					aM.eS("Wrong result class reported")
				END
			ELSE
				aM.eS("Message did not return anything, check spelling")
			END;
			vyBase.Update(v)
		END
	END
END AppendValue;
(******************************integrated process******************************************************************)
PROCEDURE PartialSums* ( y: vyBase.tVector;             yint: vyBase.tVector );
	VAR N, i: SIGNED32;             sum: FLOAT64;
BEGIN
	WITH y: vyLongrealVec.tVector DO
		WITH yint: vyLongrealVec.tVector DO
			N := vyLongrealVec.Len( y );             sum := 0;
			FOR i := 0 TO N - 1 DO
				sum := sum + vyLongrealVec.Get( y, i );
				vyLongrealVec.Set( 1 / (N + 1) * sum, yint, i )
			END;
			vyBase.Update( yint )
		END
	END
END PartialSums;
(**************************cumulative sum************************************************************************************)
PROCEDURE CumSum* ( y: vyBase.tVector;             ysum: vyBase.tVector );
	VAR N, l: SIGNED32;             sum: FLOAT64;
BEGIN
	WITH y: vyLongrealVec.tVector DO
		WITH ysum: vyLongrealVec.tVector DO
			N := vyLongrealVec.Len( y );             sum := 0;
			FOR l := 1 TO N DO
				sum := sum + vyLongrealVec.Get( y, l - 1 )  ;
				vyLongrealVec.Set( sum, ysum, l - 1 )
			END;
			vyBase.Update( ysum )
		END
	END
END CumSum;


BEGIN aM.launch;
END antsVecOpt.

antsVecOpt.Copy data noise ~
antsVecOpt.AddGaussNoise data noise 0.01 ~
antsVecOpt.AddExpNoise data noise 10 ~
antsVecOpt.AddLaplaceNoise data noise 0.2 ~
antsVecOpt.UniformMovingAverage noise restauration 5 50 ~
antsVecOpt.MedianFilter noise restauration 5 5 ~

antsVecOpe