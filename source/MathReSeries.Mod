(* CAPO - Computational Analysis Platform for Oberon - by Alan Freed and Felix Friedrich. *)
(* Version 1, Update 2 *)

MODULE MathReSeries;   (** AUTHOR "adf"; PURPOSE "Procedures for computing real series"; *)

IMPORT NbrInt, NbrRe, DataErrors;

TYPE
	Coefficient* = OBJECT
	VAR
		(** The index of a coefficient to be determined - supplied by the calling function, e.g., PowerSeries. *)
		n-: NbrInt.Integer;
		(** The argument of the function being evaluated - supplied by the calling function, e.g., PowerSeries. *)
		x-: NbrRe.Real;
		(** The End Of Series - to be updated by Evaluate. *)
		eos*: BOOLEAN;
		(** The derived coefficinet - to be updated by Evaluate. *)
		coef*: NbrRe.Real;

		(** Abstract - must be extended. Used to evaluate coefficients in user-defined series. *)
		PROCEDURE Evaluate*;
		BEGIN
			DataErrors.Error( "This function is abstract. It must be extended." )
		END Evaluate;

	END Coefficient;

VAR
	epsilon: NbrRe.Real;

	(**                   a1(x)
		y = b0(x) + ----------
		                  b1(x) + a2(x)
		                              ----------
		                              b2(x) + a3(x)
		                                          --------
		                                          b3(x) + ...
	 *)
	PROCEDURE ContinuedFraction*( a, b: Coefficient;  x: NbrRe.Real ): NbrRe.Real;
	(* Based on an algorithm from: Lentz, W.J., Applied Optics, 15, 1976, 668-671. *)
	VAR convergedLast, convergedThis: BOOLEAN;  c, d, delta, f: NbrRe.Real;
	BEGIN
		(* Get the leading coefficient, b0. *)
		a.n := 0;  a.x := x;  a.eos := FALSE;  b.n := 0;  b.x := x;  b.eos := FALSE;  b.Evaluate;
		(* Initialize Lentz's recursive algorithm. *)
		IF b.coef = 0 THEN b.coef := 1/NbrRe.MaxNbr END;
		f := b.coef;  c := f;  d := 0;
		(* The recursive algorithm of Lentz. *)
		convergedThis := FALSE;
		REPEAT
			NbrInt.Inc( a.n );  a.Evaluate;  NbrInt.Inc( b.n );  b.Evaluate;  c := b.coef + a.coef * x / c;
			d := 1 / (b.coef + a.coef * x * d);  delta := c * d;  f := delta * f;  delta := 1 - delta;
			convergedLast := convergedThis;  convergedThis := NbrRe.Abs( delta ) < epsilon
		UNTIL (convergedLast & convergedThis) OR (a.eos OR b.eos);
		RETURN f
	END ContinuedFraction;

(** The lengths of the supplied arrays  a & b  must be the same. *)
	PROCEDURE TruncatedContinuedFraction*( a, b: ARRAY OF NbrRe.Real;  x: NbrRe.Real ): NbrRe.Real;
	VAR i, aLen, bLen: SIZE;  c, d, f: NbrRe.Real;
	BEGIN
		aLen := LEN( a );  bLen := LEN( b );
		IF aLen # bLen THEN DataErrors.Error( "Lengths of supplied arrays must be equal." );  f := 0;  RETURN f END;
		IF b[0] = 0 THEN b[0] := 1/NbrRe.MaxNbr END;
		f := b[0];  c := f;  d := 0;  i := 1;
		REPEAT c := b[i] + a[i] * x / c;  d := 1 / (b[i] + a[i] * x * d);  f := c * d * f;  INC( i ) UNTIL i = aLen;
		RETURN f
	END TruncatedContinuedFraction;

(** y = a0 + a1x + a2x2 + a3x3 + ... *)
	PROCEDURE PowerSeries*( a: Coefficient;  x: NbrRe.Real ): NbrRe.Real;
	VAR convergedLast, convergedThis: BOOLEAN;  sum, update, xx: NbrRe.Real;
	BEGIN
		a.x := x;  a.n := 0;  a.eos := FALSE;  a.Evaluate;  sum := a.coef;  xx := 1;  convergedThis := FALSE;
		REPEAT
			NbrInt.Inc( a.n );  a.Evaluate;  xx := x * xx;  update := a.coef * xx;  sum := sum + update;
			convergedLast := convergedThis;  convergedThis := NbrRe.Abs( update ) < (epsilon * NbrRe.Abs( sum ))
		UNTIL (convergedLast & convergedThis) OR a.eos;
		RETURN sum
	END PowerSeries;

	PROCEDURE TruncatedPowerSeries*( a: ARRAY OF NbrRe.Real;  x: NbrRe.Real ): NbrRe.Real;
	VAR i, len: SIZE;  prod: NbrRe.Real;
	BEGIN
		len := LEN( a );  prod := a[len - 1] * x;
		FOR i := len - 2 TO 1 BY -1 DO prod := (a[i] + prod) * x END;
		prod := a[0] + prod;  RETURN prod
	END TruncatedPowerSeries;

(**         a0 + a1x + a2x2 + a3x3 + ...
	 	y = --------------------
		    b0 + b1x + b2x2 + b3x3 + ...
	 *)
	PROCEDURE RationalFunction*( a, b: Coefficient;  x: NbrRe.Real ): NbrRe.Real;
	VAR denom, num, ratio: NbrRe.Real;
	BEGIN
		num := PowerSeries( a, x );  denom := PowerSeries( b, x );  ratio := num / denom;  RETURN ratio
	END RationalFunction;

	PROCEDURE TruncatedRationalFunction*( a, b: ARRAY OF NbrRe.Real;  x: NbrRe.Real ): NbrRe.Real;
	VAR denom, num, ratio: NbrRe.Real;
	BEGIN
		num := TruncatedPowerSeries( a, x );  denom := TruncatedPowerSeries( b, x );  ratio := num / denom;
		RETURN ratio
	END TruncatedRationalFunction;

BEGIN
	epsilon := 10 * NbrRe.Epsilon
END MathReSeries.
