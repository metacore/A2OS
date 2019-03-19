MODULE vyChiSquare IN Oberon;
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


(* 0.1 d1 *)
(*
**************  Comment  **************************************
Algorithm 299 ACM (1967),Vol10,No4
Version1.1
Computes the integral of the CHI-Square dist. from x to infinity.
Formal Parameters:
Input: n:integer,degree of freedom,
x:extended,positive lower integral bound.
Output: PFCHISQ:extended;
PFCHISQ=NaN(BADPROB) if an error is detected.
Bugs:  PFCHISQ=INF if an error is detected./// change to NaN
Implementation 1.0; ur
Implementation 1.1  NaN ,parametercontrol;ur
*)
IMPORT MathL IN A2;
CONST INF = MAX(LONGREAL);
TYPE extended = LONGREAL;   integer = LONGINT;

PROCEDURE SChiSq* (n: integer;  x: extended): extended;
	(* upper tail probaility *)
	VAR  hPFCHISQ: extended;
PROCEDURE Falleins (Exponent: integer;  intbound: extended): extended;
	VAR help: extended;
	(*  Algorithm 209 ACM (1963) Vol6; for abs(upperintbound)>=6 the tail will be cut of*)
PROCEDURE PFGaussACM209 (upperintbound: extended ): extended;
	VAR K: ARRAY 26 OF extended;
	y, z, w: extended;
	i: integer;
BEGIN(*Gauss*)
	IF ((upperintbound = - INF) OR (upperintbound = INF)) THEN z := 1
	ELSIF upperintbound = 0.0 THEN					z := 0.0
	ELSE			(*1*)
		y := ABS(upperintbound) / 2.0;
		IF y >= 3.0 THEN(*cut the tail*)		z := 1.0
		ELSE (*real approximation*)	(*2*)
			K[1] := 0.000124818987;
			K[2] := - 0.001075204047;
			K[3] := 0.005198775019;
			K[4] := - 0.019198292004;
			K[5] := 0.059054035642;
			K[6] := - 0.151968751364;
			K[7] := 0.319152932694;
			K[8] := - 0.531923007300;
			K[9] := 0.797884560593;
			K[10] := - 2.0;
			K[11] := - 0.000045255659;
			K[12] := 0.000152529290;
			K[13] := - 0.000019538132;
			K[14] := - 0.000676904986;
			K[15] := 0.001390604284;
			K[16] := - 0.000794620820;
			K[17] := - 0.002034254874;
			K[18] := 0.006549791214;
			K[19] := - 0.010557625006;
			K[20] := 0.011630447319;
			K[21] := - 0.009279453341;
			K[22] := 0.005353579108;
			K[23] := - 0.002141268741;
			K[24] := 0.000535310849;
			K[25] := 0.999936657524;
			IF y < 1.0 THEN				(*3*)
				w := y * y;
				z := K[1] * w + K[2];
				FOR i := 3 TO 9 DO	z := z * w + K[i]  	END;
				z := 2 * z * y;  				(*3*)
			ELSE
				(*4*)
				y := y + K[10];
				z := K[11] * y + K[12];
				FOR i := 13 TO 25 DO z := z * y + K[i] END
			END (* IF *);  (*4*)
		END;    (*1*)
		IF upperintbound > 0.0 THEN	RETURN (z + 1.0) / 2.0
		ELSE			RETURN (1.0 - z) / 2.0	END
	END   END  PFGaussACM209;  (*Gauss*)

BEGIN(*falleins*)
	help := - MathL.sqrt(intbound );
	IF ODD(Exponent) THEN RETURN 2.0 * PFGaussACM209(help)
	ELSE RETURN MathL.exp( - 0.5 * intbound) END;
END Falleins;  (*falleins*)

PROCEDURE Fallzwei (Exponent: integer;  intbound, startvalue: extended): extended;
CONST k = 0.572364942925;
	VAR   e, c, halfintbound, counter, countbound, helpFallzwei: extended;
BEGIN(*fallzwei*)
	IF ODD(Exponent) THEN
		e := k;  counter := 0.5;
	ELSE
		e := 0.0;  counter := 1.0;
	END;
	halfintbound := 0.5 * intbound;
	c := MathL.ln(halfintbound);
	countbound := 0.5 * (Exponent - 1);
	helpFallzwei := startvalue;
	WHILE counter <= countbound DO
		e := MathL.ln(counter) + e;
		helpFallzwei := MathL.exp(c * counter - halfintbound - e) + helpFallzwei;
		counter := counter + 1.0;
	END;  (*while*)
	RETURN helpFallzwei;
END Fallzwei;  (*fallzwei*)

PROCEDURE Falldrei (Exponent: integer;  intbound, startvalue: extended): extended;
CONST k = 0.564189583548;
	VAR   e, c, halfintbound, counter, countbound, helpFalldrei: extended;
BEGIN(*falldrei*)
	countbound := 0.5 * (Exponent - 1);
	IF ODD(Exponent) THEN
		e := k / MathL.sqrt(0.5 * intbound);  counter := 0.5;
	ELSE
		e := 1.0;  counter := 1.0;
	END;

	c := 0.0;
	helpFalldrei := startvalue;
	halfintbound := 0.5 * intbound;

	WHILE counter <= countbound DO
		e := e * halfintbound / counter;  c := c + e;
		counter := counter + 1.0;
	END;

	RETURN c * MathL.exp( - halfintbound) + helpFalldrei;

END Falldrei;  (*Falldrei*)

BEGIN(* PFCHISQ *)

	IF(( x < 0) OR (n < 1)) THEN (*PFCHISQ:=NaN(BADPROB)*)HALT(100)
	ELSIF x = 0 THEN RETURN 0
	ELSIF x = INF THEN RETURN 1
	ELSE
		hPFCHISQ := Falleins(n, x);
		IF ( n > 2 ) THEN
			IF ( MathL.exp( - 0.5 * x) < 1.0E-10 ) THEN hPFCHISQ := Fallzwei(n, x, hPFCHISQ)
			ELSE hPFCHISQ := Falldrei(n, x, hPFCHISQ);
			END;
			RETURN hPFCHISQ;
		END;
		RETURN hPFCHISQ;  (* fof 980513 *)
	END;
END SChiSq;  (*PFCHISQ*)

PROCEDURE PFChiSq* (n: integer;  x: extended): extended;
BEGIN RETURN 1 - SChiSq(n, x)
END PFChiSq;

PROCEDURE chs1* (bins: ARRAY OF LONGINT;  ebins: ARRAY OF LONGREAL;  nbins: LONGINT;
knstrn : LONGINT;  VAR df, chsq, prob: LONGREAL);
	(* routine ksone from Numerical Recipes*)
	VAR j: LONGINT;  temp: LONGREAL;
BEGIN
	df := nbins - 1 - knstrn;
	chsq := 0;
	FOR j := 1 TO nbins DO
		IF ebins[j - 1] <= 0 THEN HALT(101) END;
		temp := bins[j - 1] - ebins[j - 1];
		chsq := chsq + temp * temp / ebins[j - 1];
	END;
	prob := (PFChiSq(nbins - 1 - knstrn, chsq));
END chs1;

END vyChiSquare.
