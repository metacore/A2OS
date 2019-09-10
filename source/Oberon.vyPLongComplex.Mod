MODULE vyPLongComplex IN Oberon;
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


(*** Complex number arrays, Cartesian flavour, including linear algebra and matrices *)
(* Pairs of real arrays interpreted as real and imaginary part of complex numbers. *)
(*! add asserts *)
IMPORT realmath := MathL IN A2;
CONST idversion* = ' v0r0d1';
TYPE
	real = FLOAT64;  (* technical convenience, to avoid duplicate code for FLOAT32 and FLOAT64 *)
	index = SIGNED32;

	PROCEDURE CToPolar* (len: index;
VAR (*IN*)Re, Im: ARRAY OF real;  (*OUT*)rho, phi: ARRAY OF real; start: index);
	VAR i: index;
BEGIN
	FOR i := start TO start + len - 1 DO
		rho[i] := realmath.sqrt(Re[i] * Re[i] + Im[i] * Im[i]);
		IF Re[i] = 0 THEN
			IF Im[i] < 0 THEN phi[i] := realmath.pi / 2 + realmath.pi
			ELSIF  Im[i] > 0  THEN phi[i] := realmath.pi / 2 ELSE phi[i] := 0
			END
		ELSE phi[i] := realmath.arctan(Im[i] / Re[i]);  IF Re[i] < 0 THEN phi[i] := phi[i] + realmath.pi END  END
	END
END CToPolar;

END vyPLongComplex.
