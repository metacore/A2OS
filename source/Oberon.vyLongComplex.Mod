MODULE vyLongComplex IN Oberon;
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


(* setting individual components may lead to consistency problems and is discouraged *)
IMPORT M := MathL IN A2;
TYPE real = FLOAT64;

TYPE Complex* = OBJECT (* POINTER TO ComplexDesc;
	ComplexDesc* = RECORD *)
	VAR
		polarvalid, cartvalid, cartfirst: BOOLEAN;
		re, im, rho, phi: real  (* default: 0<= phi < 2pi *);
		PROCEDURE (*z: Complex*) GetC* (VAR re, im: real);
BEGIN
	IF ~SELF.cartvalid THEN
		SELF.re := SELF.rho * M.cos(SELF.phi);  SELF.im := SELF.rho * M.sin(SELF.phi);  SELF.cartvalid := TRUE
	END;
	re := SELF.re;  im := SELF.im
END GetC;

PROCEDURE (*z: Complex*) SetC* ( re, im: real);
BEGIN SELF.cartfirst := TRUE;  SELF.cartvalid := TRUE;  SELF.polarvalid := FALSE;  SELF.re := re;  SELF.im := im	END SetC;

PROCEDURE (*z: Complex*) GetPolar* (VAR rho, phi: real);
BEGIN
	IF ~SELF.polarvalid THEN
		SELF.rho := M.sqrt(SELF.re * SELF.re + SELF.im * SELF.im);
		IF SELF.re = 0 THEN
			IF SELF.im < 0 THEN SELF.phi := M.pi / 2 + M.pi ELSIF  SELF.im > 0  THEN SELF.phi := M.pi / 2 ELSE SELF.phi := 0 END;
		ELSE SELF.phi := M.arctan(SELF.im / SELF.re);  IF SELF.re < 0 THEN SELF.phi := SELF.phi + M.pi END;  END;
		SELF.polarvalid := TRUE;
	END;
	rho := SELF.rho;  phi := SELF.phi;
END GetPolar;

PROCEDURE (*z: Complex*) SetPolar* (rho, phi: real);
BEGIN SELF.cartfirst := FALSE;  SELF.polarvalid := TRUE; SELF.cartvalid := FALSE;  SELF.rho := rho;  SELF.phi := phi END SetPolar;


	END Complex;
	(*
	PROCEDURE (z:Complex) GetI ():real;
	BEGIN HALT(100);			END GetI;

	PROCEDURE (z:Complex) GetR ():real;
	BEGIN HALT(100);			END GetR;

	PROCEDURE (z:Complex) SetI (im:real);
	BEGIN HALT(100);			END SetI;

	PROCEDURE (z:Complex) SetR (re:real);
	BEGIN HALT(100);			END SetR;

	PROCEDURE (z:Complex) GetRho ():real;
	BEGIN HALT(100);			END GetRho;

	PROCEDURE (z:Complex) GetPhi ():real;
	BEGIN HALT(100);			END GetPhi;

	PROCEDURE (z:Complex) SetRho (rho:real);
	BEGIN HALT(100);			END SetRho;

	PROCEDURE (z:Complex) SetPhi (phi:real);
	BEGIN HALT(100);			END SetPhi;
	*)


END vyLongComplex.