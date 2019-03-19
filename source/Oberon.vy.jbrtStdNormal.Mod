MODULE jbrtStdNormal IN Oberon;
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


IMPORT vyBase, M := MathL IN A2;

TYPE
	Real = vyBase.Real;

VAR
	v: ARRAY 15 OF Real;

PROCEDURE Phi* (x: Real): Real;
VAR
	cPhi, absx, z, h, a, b, pwr, sum: Real;
	i, j: LONGINT;
BEGIN
	IF x < - 7 THEN RETURN 0 ELSIF x > 7 THEN RETURN 1 END;
	absx := ABS (x);
	j := ENTIER (absx + 0.5);
	(* IF j > 14 THEN j := 14 END;		(* j := min(j,14) *)	*)
	z := j;
	h := absx - z;
	a := v [j];
	b := z * a - 1.0;
	pwr := 1.0;
	sum := a + h * b;
	FOR i := 2 TO 24 - j BY 2 DO		(* do 2 i=2,24-j,2 *)
		a := (a + z * b) / i;
		b := (b + z * a) / (i + 1);
		pwr := pwr * h * h;
		sum := sum + pwr * (a + h * b)
	END; 		(* 2 *)
	cPhi := sum * M.exp (* dexp *)(- 0.5 * x * x - 0.918938533204672D0);
	IF x >= 0 THEN RETURN 1.0 - cPhi ELSE RETURN cPhi END
END Phi;

BEGIN
	v [0] := 1.253314137315500D0;
	v [1] := 0.6556795424187985D0;
	v [2] := 0.4213692292880545D0;
	v [3] := 0.3045902987101033D0;
	v [4] := 0.2366523829135607D0;
	v [5] := 0.1928081047153158D0;
	v [6] := 0.1623776608968675D0;
	v [7] := 0.1401041834530502D0;
	v [8] := 0.1231319632579329D0;
	v [9] := 0.1097872825783083D0;
	v [10] := 0.9902859647173193D-1;
	v [11] := 0.9017567550106468D-1;
	v [12] := 0.8276628650136917D-1;
	v [13] := 0.764757610162485D-1;
	v [14] := 0.7106958053885211D-1;
END jbrtStdNormal.