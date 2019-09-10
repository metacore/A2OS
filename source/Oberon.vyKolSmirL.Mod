MODULE vyKolSmirL IN Oberon; 	(** gs  **)
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


(* FLOAT64 version, jb 26.10.00 *)
IMPORT MathL IN A2; (* := Math , jb 26.10.00 *)
TYPE
	real = FLOAT64;  (* jb, 26.10.00 *)

	Function* = PROCEDURE (x: real): real;

PROCEDURE probks* (alam: real): real;
	(* procedure probks from numerical recipes *)
CONST eps1 = 0.001;  eps2 = 1.D-08;
	VAR j: SIGNED32;  a2, fac, sum, term, termbf: real;
BEGIN
	fac := 2;  sum := 0;  termbf := 0;
	a2 := - 2 * alam * alam;
	FOR j := 1 TO 100 DO
		term := fac * MathL.exp(a2 * j * j);
		sum := sum + term;
		IF (ABS(term) <= eps1 * termbf ) OR (ABS(term) <= eps2 * sum ) THEN RETURN sum END;
		fac := - fac;
		termbf := ABS(term)
	END;
	RETURN 1;
END probks;

PROCEDURE Max (x1, x2: real): real;
BEGIN
	IF x1 > x2 THEN RETURN x1 ELSE RETURN x2 END;
END Max;

PROCEDURE KS1* (data: ARRAY OF real;  n: SIGNED32;  func: Function;  VAR d, prob: real );
	(* procedure ksone from numerical recipes *)
	VAR j: SIGNED32;
	f0, fn, ff, en, dt: real;
BEGIN
	f0 := 0;
	en := n;
	d := 0;
	FOR j := 1 TO n DO
		fn := j / en;
		ff := func(data[j - 1]);
		dt := Max(ABS(f0 - ff), ABS(fn - ff));
		IF (dt > d) THEN d := dt END;
		f0 := fn;
	END;
	prob := probks(MathL.sqrt(en) * d);
END KS1;

(* jb 1.11.00 *)
PROCEDURE KS1Id* (data: ARRAY OF real;  n: SIGNED32;  VAR d, prob: real);
	(*= KS1 with func = Id, to improve performance *)
VAR
	j: SIGNED32;
	fn, ff, en, dt: real;
BEGIN
	en := n;
	d := 0;
	fn := 0;
	j := 0;
	WHILE j < n DO
		ff := data [j];

		dt := ABS (fn - ff);  IF dt > d THEN d := dt END;
		INC (j);  fn := j / en;
		dt := ABS (fn - ff);  IF dt > d THEN d := dt END
	END;
	prob := probks (MathL.sqrt (en) * d);
END KS1Id;

PROCEDURE KS2* (data1: ARRAY OF real;  n1: SIGNED32;  data2: ARRAY OF real;  n2: SIGNED32;  VAR d, prob: real);
	(* procedure kstwo from numerical recipes *)
	VAR j1, j2: SIGNED32;
	en1, en2, fn1, fn2, dt, d1, d2: real;
BEGIN
	j1 := 1;  j2 := 1;
	fn1 := 0;  fn2 := 0;
	en1 := n1;  en2 := n2;
	d := 0;
	WHILE (j1 < n1) & (j2 < n2) DO
		d1 := data1[j1];  d2 := data2[j2];
		IF d1 <= d2 THEN
			fn1 := j1 / en1;  INC(j1);
		END;
		IF d2 <= d1 THEN
			fn2 := j2 / en2;  INC(j2);
		END;
		dt := ABS(fn2 - fn1);
		IF dt > d THEN d := dt END;
	END;
	prob := probks(MathL.sqrt(en1 * en2 / (en1 + en2)) * d)

END KS2;


END vyKolSmirL.
