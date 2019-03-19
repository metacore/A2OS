 MODULE antsDirSet IN Oberon;
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



IMPORT Math := MathL IN A2;
	(*= Dir set from numerical recipes, minimizing algorithm for n-dimensional functions originally,
	for better performance and saving memory restricted to 2 dimensions, this may change in future  *)
	(*! take care with pointer / var pars !!! *)
	(* EXPORT QUALIFIED Powell, LinMin, F1Dim; *)

	(*
	Minimization of a function vFunc of n variables.
	Input consists of an initial starting point P[n]; an initial matrix XI[n, n]
	whose columns contain the initial set of directions (usually the n unit
	vectors); and ftol, the fractional tolerance in the function value such that
	failure to decrease by more than this amount on one iteration signals
	doneness.  On output, P is set to the best point found, XI is the
	then-current direction set, fret is the returned function value at P, and
	iter is the number of iterations taken. The routine LinMin is used.
	*)
	(*
	Given an n dimensional point P[n] and an n dimensional direction XI[n],
	moves and resets P to where the function func(P) takes on a minimum along
	the direction XI from P, and replaces XI by the actual vector displacement
	that P was moved.  Also returns as fret the value of func at the returned
	location P. This is actually all accomplished by calling the routines
	MnBrak and Brent.
	*)
	(*
	Must accompany LinMin.
	*)

TYPE VectorFunction* = PROCEDURE (VAR A: ARRAY OF LONGREAL): LONGREAL;
	Func = PROCEDURE (x: LONGREAL): LONGREAL;

	(* Vector*= POINTER TO ARRAY OF LONGREAL;
	Matrix*= POINTER TO ARRAY OF ARRAY OF LONGREAL; *)
	(* Vector*= ARRAY dim OF LONGREAL;
	Matrix*=ARRAY dim OF ARRAY dim OF LONGREAL;
	PtrToReals=  Vector;
	PtrToLines = Matrix;  *)
VAR
	tempXI: POINTER TO ARRAY OF ARRAY OF LONGREAL;
	PT, PTT, XIT: POINTER TO ARRAY OF LONGREAL;  (* Vector *)
	XT: POINTER TO ARRAY OF LONGREAL;  (* Vector *)


	LinMinPCom, LinMinXCom: POINTER TO ARRAY OF LONGREAL;
	rcheck*: BOOLEAN;
	(*	linMinPCom, linMinXCom: ARRAY dim OF LONGREAL; *)
	VFunc: VectorFunction;
	(* ---------- Brent ----------*)

	(*
	Given a function func, and given a bracketing triplet of
	abscissas ax, bx, cx (such that bx is between ax and cx, and func(bx)
	is less than both func(ax) and func(cx)), this routine isolates the
	minimum to a fractional precision of about tol using Brent's method.
	The abscissa of the minimum is returned as xmin, and the minimum function
	value is returned as the returned function value.
	*)


	PROCEDURE Brent* (		ax, bx, cx: 	LONGREAL;
	func: 				Func;
	tol: 				 LONGREAL;
VAR xmin: LONGREAL): LONGREAL;
CONST
	itmax = 100;  (* Maximum allowed number of iterations; golden ratio; and
	a small number which protects against trying to achieve
	fractional accuracy for a minimum that happens to be exactly
	zero. *)
	cgold = 0.3819660;
	zeps = 1.0E-10;
VAR
	a, b, d, e, etemp: LONGREAL;
	fu, fv, fw, fx: LONGREAL;
	iter: INTEGER;
	p, q, r, tol1, tol2: LONGREAL;
	u, v, w, x, xm: LONGREAL;

PROCEDURE sign (a, b: LONGREAL): LONGREAL;
BEGIN
	IF b >= 0.0 THEN RETURN ABS(a)
	ELSE RETURN - ABS(a)
	END
END sign;

BEGIN
	IF ax < cx THEN a := ax ELSE a := cx END;  (* a and b must be in ascending
	order. The input abscissas
	need not be. *)
	IF ax > cx THEN b := ax ELSE b := cx END;
	v := bx;  (* Initializations... *)
	w := v;
	x := v;
	e := 0.0;  (* This will be the distance moved on the step before last. *)
	fx := func(x);  IF rcheck THEN RETURN 0 END;
	fv := fx;
	fw := fx;
	FOR iter := 1 TO itmax DO (* Main program loop. *)
		xm := 0.5 * (a + b);
		tol1 := tol * ABS(x) + zeps;
		tol2 := 2.0 * tol1;
		IF ABS(x - xm) <= tol2 - 0.5 * (b - a) THEN
			(*
			Test for done here.
			*)
			xmin := x;
			RETURN fx
		END;
		IF ABS(e) > tol1 THEN (* Construct a trial parabolic fit. *)
			r := (x - w) * (fx - fv);
			q := (x - v) * (fx - fw);
			p := (x - v) * q - (x - w) * r;
			q := 2.0 * (q - r);
			IF q > 0.0 THEN
				p := (- p)
			END;
			q := ABS(q);
			etemp := e;
			e := d;
			IF (ABS(p) >= ABS(0.5 * q * etemp)) OR (p <= q * (a - x)) OR (p >= q * (b - x)) THEN
				(*
				The above conditions determine the acceptability of the
				parabolic fit. Here we take a golden section step into
				the larger of the two segments.
				*)
				IF x >= xm THEN
					e := a - x
				ELSE
					e := b - x
				END;
				d := cgold * e
			ELSE
				d := p / q;  (* Take the parabolic step. *)
				u := x + d;
				IF (u - a < tol2) OR (b - u < tol2) THEN
					d := sign(tol1, xm - x)
				END
			END
		ELSE
			IF x >= xm THEN (* We arrive here for a golden section step, which we
				take into the larger of the two segments. *)
				e := a - x
			ELSE
				e := b - x
			END;
			d := cgold * (* Take the golden section step. *)e
		END;
		IF ABS(d) >= tol1 THEN (* Arrive here with d computed either from
			parabolic fit, or else from golden section. *)
			u := x + d
		ELSE
			u := x + sign(tol1, d)
		END;
		fu := func(u);  IF rcheck THEN RETURN 0 END; (* The one function evaluation per iteration. *)
		IF fu <= fx THEN (* Now we have to decide what to do with our function
			evaluation. Housekeeping follows: *)
			IF u >= x THEN
				a := x
			ELSE
				b := x
			END;
			v := w;
			fv := fw;
			w := x;
			fw := fx;
			x := u;
			fx := fu
		ELSE
			IF u < x THEN
				a := u
			ELSE
				b := u
			END;
			IF (fu <= fw) OR (w = x) THEN
				v := w;
				fv := fw;
				w := u;
				fw := fu
			ELSIF (fu <= fv) OR (v = x) OR (v = w) THEN
				v := u;
				fv := fu
			END
		END(* Done with housekeeping. Back for another iteration. *)
	END;
	(* NRIO.Error("Brent", "Too many iterations"); *)
	xmin := x;  (* Arrive here ready to exit with best values. *)
	RETURN fx
END Brent;
(* ---------- golden ---------*)
(* EXPORT QUALIFIED Golden, MnBrak; *)

(*
Given a function func, and given a bracketing triplet of abscissas ax,
bx, cx (such that bx is between ax and cx, and func(bx) is less than both
func(ax) and func(cx)), this routine performs a golden section search for
the minimum, isolating it to a fractional precision of about tol.
The abscissa of the minimum is returned as xmin, and the minimum
function value is returned as the returned function value.
*)
(*
Given a function func, and given distinct initial points ax and bx,
this routine searches in the downhill direction (defined by the function
as evaluated at the initial points) and returns new points ax, bx,
cx which bracket a minimum of the function. Also returned are
the function values at the three points, fa, fb, and fc.
*)



PROCEDURE Golden* (		ax, bx, cx: LONGREAL;
func: 			 Func;
tol: 				LONGREAL;
VAR xmin: 			 LONGREAL): LONGREAL;
CONST
	r = 0.61803399;
VAR
	f1, f2, c: LONGREAL;
	x0, x1, x2, x3, golden: LONGREAL;
BEGIN
	c := 1.0 - r;
	x0 := ax;  (* At any given time we will keep track of
	four points, x0, x1, x2, x3. *)
	x3 := cx;
	IF ABS(cx - bx) > ABS(bx - ax) THEN
		(*
		Make x0 to x1 the smaller segment,
		*)
		x1 := bx;
		x2 := bx + c * (cx - bx)
		(*
		and fill in the new point to be tried.
		*)
	ELSE
		x2 := bx;
		x1 := bx - c * (bx - ax)
	END;
	f1 := func(x1);  IF rcheck THEN RETURN 0 END;  (* The initial function evaluations.  Note that
	we never need to evaluate the function at the original endpoints. *)
	f2 := func(x2);  IF rcheck THEN RETURN 0 END;
	WHILE ABS(x3 - x0) > tol * (ABS(x1) + ABS(x2)) DO
		(*
		Keep returning here.
		*)
		IF f2 < f1 THEN (* One possible outcome, *)
			x0 := x1;
			(*
			its housekeeping,
			*)
			x1 := x2;
			x2 := r * x1 + c * x3;
			f1 := f2;
			f2 := func(x2); IF rcheck THEN RETURN 0 END
			(*
			and a new function evaluation.
			*)
		ELSE
			(*
			The other outcome,
			*)
			x3 := x2;
			x2 := x1;
			x1 := r * x2 + c * x0;
			f2 := f1;
			f1 := func(x1); IF rcheck THEN RETURN 0 END
			(*
			and its new function evaluation.
			*)
		END
	END;
	(*
	Back to see if we are done.
	*)
	IF f1 < f2 THEN (* We are done.  Output the best of the
		two current values. *)
		golden := f1;
		xmin := x1
	ELSE
		golden := f2;
		xmin := x2
	END;
	RETURN golden
END Golden;

PROCEDURE MnBrak* (VAR ax, bx, cx, fa, fb, fc: LONGREAL;
func: Func);
CONST
	gold = 1.618034;  maxit = 1000;
	(*
	Default ratio for magnifying successive intervals.
	*)
	glimit = 100.0;
	(*
	Maximum magnification allowed for a parabolic-fit step.
	*)
	tiny = 1.0E-20;
VAR
	ulim, u, r, q, fu, dum: LONGREAL;
	count: LONGINT;
BEGIN
	fa := func(ax);  IF rcheck THEN RETURN END;
	fb := func(bx);  IF rcheck THEN RETURN END;
	IF fb > fa THEN (* Switch roles of ax and bx so that
		we can go downhill in the direction from ax to bx. *)
		dum := ax;
		ax := bx;
		bx := dum;
		dum := fb;
		fb := fa;
		fa := dum
	END;
	cx := bx + gold * (bx - ax);
	(*
	First guess for cx.
	*)
	fc := func(cx);   count := 0;  IF rcheck THEN RETURN END;
	WHILE fb >= fc DO (* Keep returning
		here until we bracket. *)
		INC(count);  IF count > maxit THEN rcheck := TRUE;  RETURN END;
		r := (bx - ax) * (fb - fc);  (* Compute U by parabolic extrapolation from ax,
		bx, cx. tiny is used to prevent any possible
		division by zero. *)
		q := (bx - cx) * (fb - fa);
		IF ABS(q - r) > tiny THEN
			dum := ABS(q - r)
		ELSE
			dum := tiny
		END;
		IF q - r < 0.0 THEN
			dum := (- dum)
		END;
		u := bx - ((bx - cx) * q - (bx - ax) * r) / (2.0 * dum);
		ulim := bx + glimit * (cx - bx);
		(*
		We won't go farther than this. Now to test various possibilities:
		*)
		IF (bx - u) * (u - cx) > 0.0 THEN (* Parabolic U is
			between bx and cx: try it. *)
			fu := func(u);  IF rcheck THEN RETURN END;
			IF fu < fc THEN (* Got a minimum between bx and cx. *)
				ax := bx;
				fa := fb;
				bx := u;
				fb := fu;
				RETURN (* (Exit). *)
			ELSIF fu > fb THEN (* Got a minimum between between ax and U. *)
				cx := u;
				fc := fu;
				RETURN (* (Exit). *)
			END;
			u := cx + gold * (cx - bx);  (* Parabolic fit was no use.
			Use default magnification. *)
			fu := func(u)
		ELSIF (cx - u) * (u - ulim) > 0.0 THEN (* Parabolic fit is between cx
			and its allowed limit. *)
			fu := func(u);  IF rcheck THEN RETURN END;
			IF fu < fc THEN
				bx := cx;
				cx := u;
				u := cx + gold * (cx - bx);
				fb := fc;
				fc := fu;
				fu := func(u)
			END
		ELSIF (u - ulim) * (ulim - cx) >= 0.0 THEN
			u := ulim;  (* Limit parabolic U to maximum allowed value. *)
			fu := func(u); IF rcheck THEN RETURN END;
		ELSE (* Reject parabolic U, use default magnification. *)
			u := cx + gold * (cx - bx);
			fu := func(u); IF rcheck THEN RETURN END;
		END;
		ax := bx;  (* Eliminate oldest point and continue. *)
		bx := cx;
		cx := u;
		fa := fb;
		fb := fc;
		fc := fu
	END;
END MnBrak;


(* PROCEDURE GetVectorAttr (P: Vector;VAR n: LONGINT; VAR p: PtrToReals);
BEGIN
p := P; n := LEN(P^);
END GetVectorAttr;

PROCEDURE GetMatrixAttr (P: Matrix; VAR n,m: LONGINT; VAR p:PtrToLines );
BEGIN
p := P; n := LEN(P^); m:= LEN(P[0]);
END GetMatrixAttr;

PROCEDURE CreateVector ( n: LONGINT; VAR P: Vector; VAR p: PtrToReals);
BEGIN
NEW(P,n); p := P;
END CreateVector; *)(* for n dimension *)

PROCEDURE F1Dim* (x: LONGREAL;   VAR  LinMinPCom,
LinMinXCom: ARRAY OF LONGREAL ;   fnc: VectorFunction): LONGREAL;
VAR
	j, linMinNCom: LONGINT;
	(* Define the global variables. *)
	f1dim: LONGREAL;
BEGIN
	(* GetVectorAttr(LinMinPCom, linMinNCom, linMinPCom);*)
	linMinNCom := LEN(LinMinXCom);
	IF (XT = NIL) OR (LEN(XT^) # linMinNCom) THEN NEW(XT, linMinNCom) END;
	(* GetVectorAttr(LinMinXCom, n, linMinXCom); *)
	(*
	CreateVector(linMinNCom, XT, XT);
	*)
	(* IF XT # NilVector THEN *)
	FOR j := 0 TO linMinNCom - 1 DO
		XT[j] := LinMinPCom[j] + x * LinMinXCom[j]
	END;
	f1dim := fnc(XT^);   IF rcheck THEN RETURN f1dim END;
	(* IF XT # NilVector THEN DisposeVector(XT); END;*)
	RETURN f1dim;
	(* ELSE
	HALT(100); (* NRIO.Error("F1Dim", "Not enough memory.");*)
	RETURN 0.0;
	END;*)
END F1Dim;

PROCEDURE func (x: LONGREAL): LONGREAL;
BEGIN
	(*
	Called by Brent and MnBrak.
	*)
	RETURN F1Dim(x, LinMinPCom^, LinMinXCom^, VFunc);
END func;

PROCEDURE LinMin* (VAR P, XI: ARRAY OF LONGREAL;   VAR fret: LONGREAL;   vf: VectorFunction);
CONST
	tol = 1.0E-4;   (* tol is passed to Brent. *)
VAR
	j, n, nXI: LONGINT;
	xx, xmin, fx, fb, fa, bx, ax: LONGREAL;   t1, t2: LONGREAL;
	(* p, xi: PtrToReals;*)
BEGIN
	(* GetVectorAttr(P, n, p);*)
	n := LEN(P);
	(* GetVectorAttr(XI, nXI, xi); *)
	nXI := LEN(P);

	IF (LinMinPCom = NIL) OR (LEN(LinMinPCom^) # n) THEN NEW(LinMinPCom, n) END;
	IF (LinMinXCom = NIL) OR (LEN(LinMinXCom^) # n) THEN NEW(LinMinXCom, n) END;

	(* CreateVector(n, LinMinPCom, linMinPCom);
	CreateVector(n, LinMinXCom, linMinXCom);*)
	(* IF (LinMinPCom # NilVector) & (LinMinXCom # NilVector) THEN *)
	VFunc := vf;
	IF n = nXI THEN
		FOR j := 0 TO n - 1 DO
			LinMinPCom[j] := P[j];
			LinMinXCom[j] := XI[j]
		END;
		ax := 0.0;   (* Initial guess for brackets. *)
		xx := 1.0;
		MnBrak(ax, xx, bx, fa, fx, fb, func);   IF rcheck THEN RETURN END;
		fret := Brent(ax, xx, bx, func, tol, xmin);   IF rcheck THEN RETURN END;
		FOR j := 0 TO n - 1 DO (* Construct the vector results to return. *)
			XI[j] := xmin * XI[j];
			t1 := P[j];  t2 := XI[j];
			P[j] := t1 + t2;
		END;
	ELSE
		(* NRIO.Error("LinMin", "Inproper input data."); *)
		HALT(103);
	END;
	(* ELSE
	(* NRIO.Error("LinMin", "Not enough memory.");*)
	HALT(104);
	END;*)
	(*	IF LinMinPCom # NilVector THEN DisposeVector(LinMinPCom) END;
	IF LinMinXCom # NilVector THEN DisposeVector(LinMinXCom) END;*)
END LinMin;

PROCEDURE Powell* (	VAR	P: 		ARRAY OF LONGREAL;
VAR  XI: 	ARRAY OF ARRAY OF LONGREAL ;
ftol: LONGREAL;
VAR iter: LONGINT;
VAR fret: LONGREAL;
fncP: VectorFunction;  range: LONGREAL);
CONST
	itmax = 200;   (* Maximum allowed iterations. *)
VAR
	j, ibig, i, n : LONGINT;
	t, fptt, fp, del: LONGREAL;
	(* p, pt, ptt, xit: PtrToReals;  *)
	(* xi: PtrToLines; *)
BEGIN
	n := LEN(P);
	IF (PT = NIL) OR (LEN(PT^) # n) THEN NEW(PT, n) END;
	IF (PTT = NIL) OR (LEN(PTT^) # n) THEN NEW(PTT, n) END;
	IF (XIT = NIL) OR (LEN(XIT^) # n) THEN NEW(XIT, n) END;

	fret := fncP(P);
	FOR j := 0 TO n - 1 DO PT[j] := P[j] END;   (* Save the initial point. *)
	iter := 0;
	LOOP
		INC(iter, 1);
		fp := fret;
		ibig := 0;
		del := 0.0;   (* Will be the biggest function decrease. *)
		FOR i := 0 TO n - 1 DO (* In each iteration, loop over all directions in the
			set. *)
			FOR j := 0 TO n - 1 DO XIT[j] := XI[j, i] END;   (* Copy the direction, *)
			fptt := fret;
			LinMin(P, XIT^, fret, fncP);   IF rcheck THEN RETURN END; (* minimize along it, *)
			IF ABS(fptt - fret) > del THEN (* and record it
				if it is the largest decrease so far. *)
				del := ABS(fptt - fret);
				ibig := i
			END
		END;
		IF 2.0 * ABS(fp - fret) <= ftol * (ABS(fp) + ABS(fret)) THEN (* Termination criterion. *)
			(* IF XIT # NilVector THEN DisposeVector(XIT); END;
			IF PTT # NilVector THEN DisposeVector(PTT); END;
			IF PT # NilVector THEN DisposeVector(PT); END;*)
			RETURN;
		END;
		IF iter = itmax THEN (* NRIO.Error("Powell", "Too many interation"); *)HALT(105) END;
		FOR j := 0 TO n - 1 DO (* Construct the extrapolated point and the
			average direction moved.  Then save the old starting point. *)
			PTT[j] := 2.0 * P[j] - PT[j];
			XIT[j] := P[j] - PT[j];
			PT[j] := P[j]
		END;
		fptt := fncP(PTT^);   (* Function value at extrapolated point. *)
		IF fptt < fp THEN
			t := 2.0 * (fp - 2.0 * fret + fptt) * ((fp - fret - del) * (fp - fret - del)) - del * ((fp - fptt) * (fp - fptt));
			IF t < 0.0 THEN
				LinMin(P, XIT^, fret, fncP);   IF rcheck THEN RETURN END; (* Move to the minimum of the
				new direction, *)
				FOR j := 0 TO n - 1 DO
					XI[j, ibig] := XIT[j](* and save the new direction. *)
				END
			END
		END(* Back for another iteration. *)
	END;
	(* 	IF XIT # NilVector THEN DisposeVector(XIT); END;
	IF PTT # NilVector THEN DisposeVector(PTT); END;
	IF PT # NilVector THEN DisposeVector(PT); END;*)
END Powell;

PROCEDURE EasyMinimize* (VAR P: ARRAY OF LONGREAL;  VAR fret: LONGREAL;  ftol: LONGREAL;   fncP: VectorFunction;  init: BOOLEAN);
CONST range = 100000;
	VAR n: LONGINT;  iter: LONGINT;  i, j: LONGINT;   tol: LONGREAL;
BEGIN
	n := LEN(P);
	IF (tempXI = NIL) OR (LEN(tempXI^) # n)
		THEN
		NEW(tempXI, n, n);
	END;
	FOR i := 0 TO n - 1 DO
		IF init THEN
			P[i] := 0;
		END;
		FOR j := 0 TO n - 1 DO
			IF i = j THEN tempXI[i, j] := 1 ELSE tempXI[i, j] := 0 END;
		END;
	END;
	tol := ftol;
	REPEAT
		rcheck := FALSE;
		Powell(P, tempXI^, tol, iter, fret, fncP, range);
		tol := tol * 10;
		IF tol > 100000 THEN HALT(200) END;
	UNTIL ~rcheck ;
	(* vyOut.LongReal(tol,10);  *)
END EasyMinimize;



PROCEDURE mfncP ( VAR P: ARRAY OF LONGREAL): LONGREAL;
	VAR ret: LONGREAL; i: LONGINT;
BEGIN
	ret := 1;
	FOR i := 0 TO LEN(P) - 1 DO
		ret := (ret * Math.exp((P[i] - i) * (P[i] - i)) );
	END;
	RETURN ret;
END mfncP;

(*
PROCEDURE Test*;
	VAR P: ARRAY 10 OF LONGREAL;  f: LONGREAL;  i: LONGINT;
BEGIN
	EasyMinimize(P, f, 0.00001, mfncP, TRUE);
	vyOut.LongReal(f, 10);
	FOR i := 0 TO LEN(P) - 1 DO
		vyOut.LongReal(P[i], 10);
	END;
	IF rcheck THEN vyOut.String("CHECK") END;
END Test;
*)


END antsDirSet.


antsDirSet.Test ~
