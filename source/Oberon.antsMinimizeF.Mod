MODULE antsMinimizeF IN Oberon;
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




(*= some minimizing algorithms for 2 dimensional functions , amoeba comes from numerical recipes.
minimization of some n dimensional function
restricted to 2 dimensions.
Downhill is a fast minimizing algorithm that MAY converge to some minimum,
e.g. if function projected to canonical base is convex
used for some presteps only
*)

(*
Multidimensional minimization of the function func(x)
where x[ndim] is a vector in ndim dimensions, by the downhill
simplex method of Nelder and Mead.  The matrix P[ndim+1][ndim]
is input. Its ndim+1 rows are ndim-dimensional vectors which are the
vertices of the starting simplex.
Also input is the vector Y[ndim+1], whose components must be pre-
initialized to the values of func evaluated at the ndim+1 vertices (rows)
of P; and ftol the fractional convergence tolerance to be achieved in the
function value (n.b.!).  On output, P and Y will have been reset to ndim+1
new points all within ftol of a minimum function value, and nfunc gives
the number of function evaluations taken.
*)

CONST range = 30;
TYPE
	Function = PROCEDURE (a: ARRAY OF FLOAT64): FLOAT64;
	Function2 =  PROCEDURE (beta, h: FLOAT64): FLOAT64;
	VAR exceeded*: BOOLEAN;

	PROCEDURE AmoTry (		VAR P: 			ARRAY OF ARRAY OF FLOAT64;
	VAR Y: 			ARRAY OF FLOAT64;
	VAR sum: 		ARRAY OF FLOAT64;
	ndim,
	ihi: 		SIGNED32;
	func: 	 Function;
	VAR nfunc: 	SIGNED32;
fac: 		FLOAT64): 	 FLOAT64;
	(*     Extrapolates by a factor FAC through the face of the simplex across from the high point, tries it, and replaces the high point
	if the new point is better.   *)
VAR
	j : SIGNED32;
	fac1, fac2, ytry: FLOAT64;
	(* PTRY: POINTER TO ARRAY OF FLOAT64; *)
	PTRY: ARRAY 2 OF FLOAT64;
BEGIN
	(* NEW(PTRY,ndim);  *)(* dim is assumed to be 2 *)
	fac1 := (1.0 - fac) / ndim;
	fac2 := fac1 - fac;
	FOR j := 0 TO ndim - 1 DO
		PTRY[j] := sum[j] * fac1 - P[ihi, j] * fac2
	END;
	ytry := func(PTRY);      (* Evaluate the function at the trial point. *)
	INC(nfunc, 1);
	IF ytry < Y[ihi] THEN (* If it's better than the highest, then replace
		the highest. *)
		Y[ihi] := ytry;
		FOR j := 0 TO ndim - 1 DO
			sum[j] := sum[j] + PTRY[j] - P[ihi, j];
			P[ihi, j] := PTRY[j]
		END
	END;
	RETURN ytry
	(* ELSE
	(* NRIO.Error("AmoTry", "Not enough memory."); *) HALT (101);
	END;*)
END AmoTry;

PROCEDURE swap* (VAR y1, y2: FLOAT64);
	VAR temp: FLOAT64;
BEGIN
	temp := y1;     y1 := y2;     y2 := temp
END swap;

PROCEDURE swapv* (VAR y1, y2: ARRAY OF FLOAT64);
	VAR i: SIGNED32;
BEGIN
	FOR i := 0 TO LEN(y1) - 1 DO
		swap(y1[i], y2[i])
	END
END swapv;


PROCEDURE Amoeba* (		VAR P: 		 ARRAY OF ARRAY OF FLOAT64;
VAR Y: 		 ARRAY OF FLOAT64;
ndim: 	SIGNED32;
ftol: 	FLOAT64;
func: 	Function;
VAR nfunc: SIGNED32);
CONST
	nfuncmax = 5000;      (* The maximum allowed
	number of function evaluations, and three parameters
	defining the expansions and contractions. *)
	alpha = 1.0;
	beta = 0.5;
	gamma = 2.0;
	VAR t1, t2: FLOAT64;
	mpts, nY, j, inhi, ilo, ihi, i : SIGNED32;
	ytry, ysave, sum, rtol: FLOAT64;
	(*  PSUM: POINTER TO ARRAY OF FLOAT64;*)
	PSUM: ARRAY 2 OF FLOAT64;      (* dim assumed to be 2 *)

BEGIN
	exceeded := FALSE;
	mpts := LEN(P);      	nY := LEN(Y);
	ASSERT (nY = mpts) ;
	nfunc := 0;
	FOR j := 0 TO ndim - 1 DO
		sum := 0.0;
		FOR i := 0 TO mpts - 1 DO
			sum := sum + P[i, j]
		END;
		PSUM[j] := sum
	END;
	LOOP
		ilo := 0;      (* First we must determine which point is the
		highest (worst), next-highest, and lowest (best), *)
		(* ihi; highest point
		inhi: next highest point
		ilo: lowest point *)
		IF Y[0] > Y[1] THEN
			ihi := 0;
			inhi := 1
		ELSE
			ihi := 1;
			inhi := 0
		END;
		FOR i := 0 TO mpts - 1 DO (* by looping over the points in the simplex. *)
			IF Y[i] <= Y[ilo] THEN
				ilo := i
			END;
			IF Y[i] > Y[ihi] THEN
				inhi := ihi;
				ihi := i
			ELSIF Y[i] > Y[inhi] THEN
				IF i # ihi THEN
					inhi := i
				END
			END
		END;
		(*
		Compute the fractional range from highest to lowest.
		*)
		(* rtol := 2.0*(ABS(Y[ihi]-Y[ilo]))/(ABS(Y[ihi])+ABS(Y[ilo]));   (* orig ! *)*)
		rtol := ABS(P[ilo, 1] - P[ihi, 1]) + ABS(P[ilo, 0] - P[ihi, 0]);    (* bad idea, fof *)

		IF rtol < ftol THEN
			(*
			Return if satisfactory.
			*)
			(* NRVect.DisposeVector(PSUM);*)
			swap(Y[0], Y[ilo]);
			swapv(P[0], P[ilo]);
			RETURN
		END;
		IF nfunc >= nfuncmax THEN
			(* NRIO.Error("Amoeba", "Too many iterations"); *)
			(* vyTexts.Note(vyTexts.cWarning,"Amoeba: precision not reached"); *)
			exceeded := TRUE;
			swap(Y[0], Y[ilo]);
			swapv(P[0], P[ilo]);
			RETURN
		END;
		(*
		Begin a new iteration. First extrapolate by a factor alpha through
		the face of the simplex across from the high point, i.e., reflect the
		simplex from the high point.
		*)
		ytry := AmoTry(P, Y, PSUM, ndim, ihi, func, nfunc, - alpha);
		IF ytry <= Y[ilo] THEN
			(*
			Gives a result better than the best
			point, so try an additional extrapolation by a factor gamma.
			*)
			ytry := AmoTry(P, Y, PSUM, ndim, ihi, func, nfunc, gamma)
		ELSIF ytry >= Y[inhi] THEN
			(*
			The reflected point is worse than the second-highest, so
			look for an intermediate lower point,
			i.e., do a one-dimensional contraction.
			*)
			ysave := Y[ihi];
			ytry := AmoTry(P, Y, PSUM, ndim, ihi, func, nfunc, beta);
			IF ytry >= ysave THEN (* Can't seem to get rid of that high point.
				Better contract around the lowest (best) point. *)
				FOR i := 0 TO mpts - 1 DO
					IF i # ilo THEN
						FOR j := 0 TO ndim - 1 DO
							t1 := P[i, j];  t2 := P[ilo, j];
							PSUM[j] := 0.5 * (t1 + t2);
							P[i, j] := PSUM[j]
						END;
						Y[i] := func(PSUM)
					END
				END;
				INC(nfunc, ndim);      (* Keep track of function evaluations. *)
				FOR j := 0 TO ndim - 1 DO (* Recompute PSUM. *)
					sum := 0.0;
					FOR i := 0 TO mpts - 1 DO
						sum := sum + P[i, j]     (* vyTexts.WriteRealFix(vyTexts.w,P[i,j],5,5,0);   *)
					END;
					(* vyTexts.InsertLog(vyTexts.w.buf);   *)
					PSUM[j] := sum
				END

			END
			(* FOR j := 0 TO ndim-1 DO (* Recompute PSUM. *)
			(* vyTexts.MsgSI("j = ",j);   *)
			FOR i := 0 TO mpts-1 DO
			vyTexts.WriteRealFix(vyTexts.w,P[i,j],5,5,0);
			END;
			vyTexts.InsertLog(vyTexts.w.buf);
			END
			vyTexts.WriteRealFix(vyTexts.w,P[ilo,0],5,5,0); vyTexts.InsertLog(vyTexts.w.buf);*)
		END
	END      (* Go back for the test of doneness and the next iteration. *)
END Amoeba;

PROCEDURE Downhill* (func: Function2;   VAR beta, h: FLOAT64;   prec: FLOAT64  );
CONST initdist = 5;    fact = 0.5;
	VAR sbeta, sh : FLOAT64;   nb, nh : ARRAY 8 OF  FLOAT64;   val, temp, dist: FLOAT64;   sf: BOOLEAN;   fval, i, count: SIGNED32;
BEGIN
	exceeded := FALSE;
	count := 0;
	sbeta := beta;   sh := h;
	dist := initdist;

	LOOP
		nb[0] := sbeta - dist;   nh[0] := sh - dist;
		nb[1] := sbeta - dist;   nh[1] := sh;
		nb[2] := sbeta - dist;   nh[2] := sh + dist;
		nb[3] := sbeta ;   nh[3] := sh - dist;
		nb[4] := sbeta ;   nh[4] := sh + dist;
		nb[5] := sbeta + dist;   nh[5] := sh - dist;
		nb[6] := sbeta + dist;   nh[6] := sh;
		nb[7] := sbeta + dist;   nh[7] := sh + dist;

		val := func(sbeta, sh);   sf := FALSE;
		FOR i := 0 TO 7 DO
			temp := func(nb[i], nh[i]);
			IF temp < val THEN val := temp;   sf := TRUE;   fval := i   END
		END;
		IF sf THEN
			(* IF vyRandom.Uniform() <0.3 THEN
			fval := SHORT(ENTIER(vyRandom.Uniform()*8));
			END; *)
			sbeta := nb[fval];   sh := nh[fval];
			IF dist < prec THEN beta := sbeta;   h := sh;   RETURN END;
			IF (ABS(sbeta) > range) OR (ABS(sh) > range) THEN
				beta := range;   h := range;
				(* vyTexts.Note(vyTexts.cWarning,"RangeCheck"); *)exceeded := TRUE;   RETURN
			END
		ELSE dist := dist * fact
		END;
		INC(count);
		IF count > 1000 THEN beta := sbeta;   h := sh;    exceeded := TRUE;   RETURN    END
	END
END Downhill;


END antsMinimizeF.

