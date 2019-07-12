(* CAPO - Computational Analysis Platform for Oberon - by Alan Freed and Felix Friedrich. *)
(* Version 1, Update 2 *)

MODULE MathCplxSeries;   (** AUTHOR "adf"; PURPOSE "Procedures for computing complex series"; *)

IMPORT NbrInt, NbrRe, NbrCplx, DataErrors;

TYPE
	Coefficient* = OBJECT
	VAR
		(** The index of a coefficient to be determined - supplied by the calling function, e.g., PowerSeries. *)
		n-: NbrInt.Integer;
		(** The argument of the function being evaluated - supplied by the calling function, e.g., PowerSeries. *)
		z-: NbrCplx.Complex;
		(** The End Of Series - to be updated by Evaluate. *)
		eos*: BOOLEAN;
		(** The derived coefficinet - to be updated by Evaluate. *)
		coef*: NbrCplx.Complex;

		(** Abstract - must be extended. Used to evaluate coefficients in user-defined series. *)
		PROCEDURE Evaluate*;
		BEGIN
			DataErrors.Error( "This function is abstract. It must be extended." )
		END Evaluate;

	END Coefficient;

VAR
	epsilon: NbrRe.Real;

	(**                   a1(z)
		y = b0(z) + ----------
		                  b1(z) + a2(z)
		                              ----------
		                              b2(z) + a3(z)
		                                          --------
		                                          b3(z) + ...
	 *)
	PROCEDURE ContinuedFraction*( a, b: Coefficient;  z: NbrCplx.Complex ): NbrCplx.Complex;
	(* Based on an algorithm from: Lentz, W.J., Applied Optics, 15, 1976, 668-671. *)
	VAR convergedLast, convergedThis: BOOLEAN;  c, d, delta, f: NbrCplx.Complex;
	BEGIN
		(* Get the leading coefficient, b0. *)
		a.n := 0;  a.z := z;  a.eos := FALSE;  b.n := 0;  b.z := z;  b.eos := FALSE;  b.Evaluate;
		(* Initialize Lentz's recursive algorithm. *)
		IF b.coef = 0 THEN b.coef := 1/NbrRe.MaxNbr END;
		f := b.coef;  c := f;  d := 0;
		(* The recursive algorithm of Lentz. *)
		convergedThis := FALSE;
		REPEAT
			NbrInt.Inc( a.n );  a.Evaluate;  NbrInt.Inc( b.n );  b.Evaluate;  c := b.coef + a.coef * z / c;
			d := 1 / (b.coef + a.coef * z * d);  delta := c * d;  f := delta * f;  convergedLast := convergedThis;
			convergedThis := NbrRe.Abs( 1 - NbrCplx.Abs( delta ) ) < epsilon
		UNTIL (convergedLast & convergedThis) OR (a.eos OR b.eos);
		RETURN f
	END ContinuedFraction;

(** The lengths of the supplied arrays  a & b  must be the same. *)
	PROCEDURE TruncatedContinuedFraction*( a, b: ARRAY OF NbrRe.Real;  z: NbrCplx.Complex ): NbrCplx.Complex;
	VAR i, aLen, bLen: SIZE;  c, d, f: NbrCplx.Complex;
	BEGIN
		aLen := LEN( a );  bLen := LEN( b );
		IF aLen # bLen THEN
			DataErrors.Error( "Lengths of supplied arrays must be equal." );  f := 0;  RETURN f END;
		IF b[0] = 0 THEN b[0] := 1/NbrRe.MaxNbr END;
		f := b[0];  c := f;  d := 0;  i := 1;
		REPEAT c := b[i] + a[i] * z / c;  d := 1 / (b[i] + a[i] * z * d);  f := c * d * f;  INC( i ) UNTIL i = aLen;
		RETURN f
	END TruncatedContinuedFraction;

(** y = a0 + a1z + a2z2 + a3z3 + ... *)
	PROCEDURE PowerSeries*( a: Coefficient;  z: NbrCplx.Complex ): NbrCplx.Complex;
	VAR convergedLast, convergedThis: BOOLEAN;  sum, update, zz: NbrCplx.Complex;
	BEGIN
		a.z := z;  a.n := 0;  a.eos := FALSE;  a.Evaluate;  sum := a.coef;  zz := 1;  convergedThis := FALSE;
		REPEAT
			NbrInt.Inc( a.n );  a.Evaluate;  zz := z * zz;  update := a.coef * zz;  sum := sum + update;
			convergedLast := convergedThis;  convergedThis := NbrCplx.Abs( update ) < (epsilon * NbrCplx.Abs( sum ))
		UNTIL (convergedLast & convergedThis) OR a.eos;
		RETURN sum
	END PowerSeries;

	PROCEDURE TruncatedPowerSeries*( a: ARRAY OF NbrRe.Real;  z: NbrCplx.Complex ): NbrCplx.Complex;
	VAR i, len: SIZE;  prod: NbrCplx.Complex;
	BEGIN
		len := LEN( a );  prod := a[len - 1] * z;
		FOR i := len - 2 TO 1 BY -1 DO prod := (a[i] + prod) * z END;
		prod := a[0] + prod;  RETURN prod
	END TruncatedPowerSeries;

(**         a0 + a1z + a2z2 + a3z3 + ...
	 	y = --------------------
		    b0 + b1z + b2z2 + b3z3 + ...
	 *)
	PROCEDURE RationalFunction*( a, b: Coefficient;  z: NbrCplx.Complex ): NbrCplx.Complex;
	VAR denom, num, ratio: NbrCplx.Complex;
	BEGIN
		num := PowerSeries( a, z );  denom := PowerSeries( b, z );  ratio := num / denom;  RETURN ratio
	END RationalFunction;

	PROCEDURE TruncatedRationalFunction*( a, b: ARRAY OF NbrRe.Real;  z: NbrCplx.Complex ): NbrCplx.Complex;
	VAR denom, num, ratio: NbrCplx.Complex;
	BEGIN
		num := TruncatedPowerSeries( a, z );  denom := TruncatedPowerSeries( b, z );  ratio := num / denom;
		RETURN ratio
	END TruncatedRationalFunction;

BEGIN
	epsilon := 10 * NbrRe.Epsilon
END MathCplxSeries.
