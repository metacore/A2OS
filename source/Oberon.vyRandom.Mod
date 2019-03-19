MODULE vyRandom IN Oberon;
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



(** Random number Generation *)
(*= Includes support on array level *)
(* warning: this module will be changed to LONGREAL as a base type*)
(*!  support fully parametrized versions  *)
(*! support bernoulli variates *)
(* fixed: vector support needs VAR parameters *)
IMPORT	MathL IN A2, vyRanBase, vyRanParksMiller;
CONST
	idversion* = "Random v0.1d4";
	VAR  twopi: LONGREAL;

PROCEDURE Uniform* (): LONGREAL;
BEGIN RETURN (vyRanBase.RandomU()) END Uniform;

PROCEDURE UniformV* (count: LONGINT; VAR x: ARRAY OF LONGREAL;  start: LONGINT);
BEGIN vyRanBase.RandomUVX(count, x, start)  END UniformV;

PROCEDURE Exp* (mu: LONGREAL): LONGREAL;
BEGIN RETURN (- MathL.ln(Uniform()) / mu) END Exp;

PROCEDURE ExpV* (mu: LONGREAL; count: LONGINT; VAR  x: ARRAY OF LONGREAL;  start: LONGINT);
BEGIN
	vyRanBase.RandomUVX(count, x, start);
	count := count + start;
	WHILE start < count DO x[start] := - MathL.ln(x[start]) / mu; INC(start) END
END ExpV;

(*=
various random number generators on top of random
see B.D.Ripley: Computer Generation of Random Variables:
A tutorial. Int. Stat. Review 51(1983) 301-319
*)

PROCEDURE Cauchy* (): LONGREAL;
	VAR x: LONGREAL;
BEGIN
	x := MathL.pi * ( Uniform() - 0.5);
	RETURN (MathL.sin(x) / MathL.cos(x))
END Cauchy;

PROCEDURE CauchyV* (count: LONGINT; VAR x: ARRAY OF LONGREAL;  start: LONGINT);
	VAR temp: LONGREAL;
BEGIN
	vyRanBase.RandomUVX(count, x, start);
	count := count + start;
	WHILE start < count DO	 temp := MathL.pi * ( x[start] - 0.5);
		x[start] := (MathL.sin(temp) / MathL.cos(temp)); INC(start)
	END
END CauchyV;

(*=    RandomGauss: Standard normal distribution
The Box-Muller transformation is used
For a warning, see H.R. Naeve's note 'On Using the
Box-Muller transformation with multiplicative congruential
pseudo-random number generators, Appl. Statist. 22 (1973) 92-97
*)
PROCEDURE Gauss* (mu, sigmasq: LONGREAL): LONGREAL;
	(*= Gaussian random variate, mean mu, Var sigmasq *)
	VAR u1, u2: LONGREAL;
BEGIN
	u1 := Uniform();
	u2 := Uniform();
	RETURN ((MathL.sqrt(  - 2 * MathL.ln(u1)) * MathL.cos(twopi * u2))) * MathL.sqrt(sigmasq) + mu
END Gauss;

PROCEDURE GaussV* (mu, sigmasq: LONGREAL; count: LONGINT; VAR x: ARRAY OF LONGREAL;  start: LONGINT);
	(*= Gaussian random variates, mean mu, Var sigmasq *)
	VAR u1, u2: LONGREAL; stddev: LONGREAL;
BEGIN stddev := MathL.sqrt(sigmasq);
	IF ODD(count) THEN x[start] := Gauss(mu, sigmasq);  INC(start); DEC(count) END;
	vyRanBase.RandomUVX(count, x, start);
	count := count + start;
	WHILE start < count DO
		u1 := x[start];
		u2 := x[start + 1];
		x[start] := ((MathL.sqrt(  - 2 * MathL.ln(u1)) * MathL.cos(twopi * u2)) * stddev + mu);
		x[start + 1] := ((MathL.sqrt(  - 2 * MathL.ln(u1)) * MathL.sin(twopi * u2)) * stddev + mu);
		INC(start, 2)
	END
END GaussV;

(*=
RandomGausM: Standard normal distribution
The Marsaglia transformation is used
*)
PROCEDURE GaussM* (mu, sigmasq: LONGREAL): LONGREAL;
VAR
	v1, v2, w, c, x: LONGREAL;
BEGIN
	REPEAT
		v1 := 2 * Uniform() - 1;
		v2 := 2 * Uniform() - 1;
		w := v1 * v1 + v2 * v2
	UNTIL w <= 1;
	c := MathL.sqrt(  - 2 * MathL.ln(w) / w);
	x := c * v1;
	RETURN (x * MathL.sqrt(sigmasq) + mu);
	(* {RandomGaussM:=c*v2;} *)
	(*       {another independent variate} *)
END GaussM;

PROCEDURE GaussMV* (mu, sigmasq: LONGREAL; count: LONGINT; VAR gauss: ARRAY OF LONGREAL;  start: LONGINT);
VAR
	v1, v2, w, c: LONGREAL; stddev: LONGREAL;
BEGIN stddev := MathL.sqrt(sigmasq);
	count := count + start;
	WHILE start < count DO
		REPEAT
			v1 := 2 * Uniform() - 1;
			v2 := 2 * Uniform() - 1;
			w := v1 * v1 + v2 * v2;
		UNTIL w <= 1;
		c := MathL.sqrt(  - 2 * MathL.ln(w) / w);
		gauss[start] := c * v1 * stddev + mu;
		gauss[start + 1] := c * v2 * stddev + mu;
		INC(start, 2);
	END;
END GaussMV;

(*=    RandomWeibull: Weibulll distribution *)

PROCEDURE Weibull* (beta : LONGREAL) : LONGREAL;
BEGIN
	RETURN (MathL.exp(MathL.ln(  - MathL.ln(Uniform()) / beta)));
END Weibull;

PROCEDURE WeibullV* (beta : LONGREAL; count: LONGINT; VAR x: ARRAY OF LONGREAL;  start: LONGINT);
BEGIN
	vyRanBase.RandomUVX(count, x, start);
	count := count + start;
	WHILE start < count DO
		x[start] := (MathL.exp(MathL.ln(  - MathL.ln(x[start]) / beta))); INC(start)
	END;
END WeibullV;

(*=   RandomGumbel: Gumbel distribution *)

PROCEDURE Gumbel* (): LONGREAL;
BEGIN
	RETURN  (- MathL.ln(  - MathL.ln(Uniform())));
END Gumbel;

PROCEDURE GumbelV* (count: LONGINT; VAR x: ARRAY OF LONGREAL;  start: LONGINT);
BEGIN
	vyRanBase.RandomUVX(count, x, start);
	count := count + start;
	WHILE start < count DO
		x[start] :=  (- MathL.ln(  - MathL.ln(x[start]))); INC(start)
	END;
END GumbelV;

PROCEDURE VonMises* (Kappa : LONGREAL) : LONGREAL;
	VAR        y: LONGREAL;
BEGIN
	REPEAT
		y := 2 * MathL.pi * Uniform();
	UNTIL Uniform() > MathL.exp(Kappa * MathL.cos(y) - 1);
	RETURN (y);
END VonMises;

PROCEDURE VonMisesV* (Kappa : LONGREAL; count: LONGINT; VAR x: ARRAY OF LONGREAL;  start: LONGINT);
	VAR        y: LONGREAL;
BEGIN
	count := count + start;
	WHILE start < count DO
		REPEAT
			y := twopi * Uniform();
		UNTIL Uniform() > MathL.exp(Kappa * MathL.cos(y) - 1);
		x[start] := (y);
		INC(start)
	END;
END VonMisesV;

BEGIN
	twopi := 2 * MathL.pi;
	IF vyRanBase.RandomGenerator = NIL THEN (* warning ?? *)
		vyRanParksMiller.Install;
	END;
END vyRandom.