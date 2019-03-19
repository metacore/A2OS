(* CAPO - Computational Analysis Platform for Oberon - by Alan Freed and Felix Friedrich. *)
(* Version 1, Update 2 *)

MODULE MathMitLef;   (** AUTHOR "adf"; PURPOSE "Mittag-Leffler function"; *)

(** The Mittag-Leffler function is the characteristic solution to fractional-order differential equations,
	like the exponential function is the characteristic solution to ordinary differential equations. *)

IMPORT NbrInt, NbrRe, NbrCplx, DataErrors, MathRe, MathGamma, MathCplx, MathCplxSeries, CalcGauss;

VAR
	maxIterations: NbrInt.Integer;  storeAlpha, storeBeta, tolerance: NbrRe.Real;
	yk: ARRAY 2 OF NbrRe.Real;
	yp: ARRAY 3 OF NbrRe.Real;

TYPE
	MitLef = OBJECT (MathCplxSeries.Coefficient)
		(* Series solution for the Mittag-Leffler function.  Only apply this as a solution around 0. *)

		PROCEDURE Evaluate*;
		VAR x: NbrRe.Real;
		BEGIN
			x := storeBeta + n * storeAlpha;
			IF GammaIsSingularAt( x ) THEN coef := 0 ELSE coef := 1 / MathGamma.Fn( x ) END;
			IF n = maxIterations THEN eos := TRUE;  DataErrors.ReWarning( x, "Did not converge -  timed out." ) END
		END Evaluate;

	END MitLef;

	AsympMitLef = OBJECT (MathCplxSeries.Coefficient)
		(* Series solution for the Mittag-Leffler function.  Only apply this as a solution for large x. *)

		PROCEDURE Evaluate*;
		VAR x: NbrRe.Real;
		BEGIN
			x := storeBeta - n * storeAlpha;
			IF GammaIsSingularAt( x ) THEN coef := 0 ELSE coef := 1 / MathGamma.Fn( x ) END;
			IF n = maxIterations THEN eos := TRUE;  DataErrors.ReWarning( x, "Did not converge -  timed out." ) END
		END Evaluate;

	END AsympMitLef;

	DMitLef = OBJECT (MathCplxSeries.Coefficient)
		(* Series solution for the derivative of the Mittag-Leffler function.  Only apply this as a solution around 0. *)

		PROCEDURE Evaluate*;
		VAR x: NbrRe.Real;
		BEGIN
			x := (1 + n) * storeAlpha + storeBeta;
			IF GammaIsSingularAt( x ) THEN coef := 0 ELSE coef := (1 + n) / MathGamma.Fn( x ) END;
			IF n = maxIterations THEN eos := TRUE;  DataErrors.ReWarning( x, "Did not converge -  timed out." ) END
		END Evaluate;

	END DMitLef;

	PROCEDURE K( x: NbrRe.Real;  z: NbrCplx.Complex ): NbrCplx.Complex;
	(* Use the mappings:  x , c,  yk[0] , a,  yk[1] , b,  z , z.  *)
	VAR coef1, coef2, r1: NbrRe.Real;  answer, denom, numer: NbrCplx.Complex;
	BEGIN
		coef1 := MathRe.Power( x, (1 - yk[1]) / yk[0] ) / (NbrRe.Pi * yk[0]);
		coef2 := MathRe.Exp( -MathRe.Power( x, 1 / yk[0] ) );  r1 := NbrRe.Pi * (1 - yk[1]);
		numer := x * MathRe.Sin( r1 ) - z * MathRe.Sin( r1 + NbrRe.Pi * yk[0] );
		denom := x * x - 2 * x * z * MathRe.Cos( NbrRe.Pi * yk[0] ) + z * z;  answer := coef1 * coef2 * numer / denom;
		RETURN answer
	END K;

	PROCEDURE P( x: NbrRe.Real;  z: NbrCplx.Complex ): NbrCplx.Complex;
	(* Use the mappings:  x , f,  yp[0] , a,  yp[1] , b,  yp[2] , e,  z , z. *)
	VAR coef1, coef2, r1: NbrRe.Real;  answer, denom, numer: NbrCplx.Complex;
	BEGIN
		coef1 := MathRe.Power( yp[2], 1 + (1 - yp[1]) / yp[0] ) / (2 * NbrRe.Pi * yp[0]);
		coef2 := MathRe.Exp( MathRe.Power( yp[2], 1 / yp[0] ) * MathRe.Cos( x / yp[0] ) );
		r1 := x * (1 + (1 - yp[1]) / yp[0]) + MathRe.Power( yp[2], 1 / yp[0] ) * MathRe.Sin( x / yp[0] );
		numer := MathRe.Cos( r1 ) + NbrCplx.I * MathRe.Sin( r1 );  denom := yp[2] * MathCplx.Exp( NbrCplx.I * x ) - z;
		answer := coef1 * coef2 * numer / denom;  RETURN answer
	END P;

	PROCEDURE GammaIsSingularAt( x: NbrRe.Real ): BOOLEAN;
	BEGIN
		IF x > 0 THEN RETURN FALSE
		ELSIF x < 0 THEN
			IF x = NbrRe.Int( x ) + 1 THEN RETURN TRUE ELSE RETURN FALSE END
		ELSE RETURN TRUE
		END
	END GammaIsSingularAt;

(** The Mittag-Leffler function,  Ea,b(z) = ek=0% zk/G(ak+b), a, b N R, a > 0,  z N C.  *)
	PROCEDURE Fn*( alpha, beta, x: NbrRe.Real ): NbrRe.Real;
	VAR abs, answer, arg: NbrRe.Real;  ml, z: NbrCplx.Complex;
	BEGIN
		z := x;  ml := CplxFn( alpha, beta, z );  abs := NbrCplx.Abs( ml );  arg := NbrCplx.Arg( ml );
		IF (arg < tolerance) & (-tolerance < arg) THEN answer := abs
		ELSIF (arg > NbrRe.Pi - tolerance) OR (arg < -NbrRe.Pi + tolerance) THEN answer := -abs
		ELSE DataErrors.Error( "The result is complex.  Use CplxFn instead." )
		END;
		RETURN answer
	END Fn;

	PROCEDURE CplxFn*( alpha, beta: NbrRe.Real;  z: NbrCplx.Complex ): NbrCplx.Complex;
	VAR i1, i2, k, k0, res: NbrInt.Integer;  a, absZ, argZ, b, r1, r2, x0: NbrRe.Real;
		answer, c1, c2: NbrCplx.Complex;  ml: MitLef;  aml: AsympMitLef;
	BEGIN
		(* Implements the algorithm of R. Gorenflo, I. Loutchko and Yu. Luchko, "Computation of the Mittag-Leffler
			function  Ea,b(z)  and its derivatives," Fractional Calculus and Applied Analysis, 5 (2002), 491-518.. *)
		alpha := NbrRe.Abs( alpha );  absZ := NbrCplx.Abs( z );  argZ := NbrCplx.Arg( z );
		IF absZ < 1 / NbrRe.MaxNbr THEN
			IF GammaIsSingularAt( beta ) THEN answer := 0 ELSE answer := 1 / MathGamma.Fn( beta ) END
		ELSIF (alpha = 1) & (beta = 1) THEN
			answer := MathCplx.Exp( z )
		ELSIF 1 < alpha THEN
			k0 := NbrRe.Floor( alpha ) + 1;  c1 := (2 * NbrRe.Pi / k0) * NbrCplx.I;  r1 := 1 / k0;  r2 := alpha / k0;  answer := 0;
			FOR k := 0 TO k0 - 1 DO
				c2 := MathCplx.RealPower( z, r1 ) * MathCplx.Exp( c1 * k );  answer := answer + CplxFn( r2, beta, c2 )
			END;
			answer := answer / k0
		ELSE
			IF absZ < 0.9 THEN BEGIN {EXCLUSIVE}
					storeAlpha := alpha;  storeBeta := beta;  i1 := NbrRe.Ceiling( (1 - beta) / alpha );
					i2 := NbrRe.Ceiling( MathRe.Ln( NbrRe.Epsilon * (1 - absZ) ) / MathRe.Ln( absZ ) );
					maxIterations := NbrInt.Max( i1, i2 );  NEW( ml );  answer := MathCplxSeries.PowerSeries( ml, z ) END
			ELSIF absZ < NbrRe.Floor( 10 + 5 * alpha ) THEN
				IF beta >= 0 THEN
					r1 := 1;  x0 := NbrRe.Max( r1, 2 * absZ );
					x0 := NbrRe.Max( x0, MathRe.Power( -MathRe.Ln( NbrRe.Epsilon * NbrRe.Pi / 6 ), alpha ) )
				ELSE
					r1 := NbrRe.Abs( beta );  r2 := MathRe.Power( 1 + r1, alpha );  x0 := NbrRe.Max( r2, 2 * absZ );
					r2 := 6 * (2 + r1) * MathRe.Power( 2 * r1, r1 );
					x0 := NbrRe.Max( x0, MathRe.Power( -2 * MathRe.Ln( NbrRe.Epsilon * NbrRe.Pi / r2 ), alpha ) )
				END;
				IF (NbrRe.Abs( argZ ) > alpha * NbrRe.Pi) &
					(NbrRe.Abs(NbrRe.Abs( argZ ) - alpha * NbrRe.Pi) > NbrRe.Epsilon) THEN
					IF beta < 1 + alpha THEN
						BEGIN {EXCLUSIVE}
							a := 0;  b := x0;  yk[0] := alpha;  yk[1] := beta;
							answer := CalcGauss.SolveCplx( K, a, b, z, CalcGauss.Medium, tolerance, res ) END;
						IF res # CalcGauss.OKay THEN
							IF res = CalcGauss.MaxSubDivReached THEN
								DataErrors.Warning( "Maximum subdivisions reached when integrating K." )
							ELSIF res = CalcGauss.RoundoffError THEN
								DataErrors.Warning( "Excessive roundoff error occurred when integrating K." )
							ELSIF res = CalcGauss.RoughIntegrand THEN
								DataErrors.Warning( "A rough integrand encountered when integrating K." )
							ELSE DataErrors.Error( "Unknown error originating from CalcGauss.SolveCplx." )
							END
						END
					ELSE
						BEGIN {EXCLUSIVE}
							a := 1;  b := x0;  yk[0] := alpha;  yk[1] := beta;
							answer := CalcGauss.SolveCplx( K, a, b, z, CalcGauss.Medium, tolerance, res ) END;
						IF res # CalcGauss.OKay THEN
							IF res = CalcGauss.MaxSubDivReached THEN
								DataErrors.Warning( "Maximum subdivisions reached when integrating K." )
							ELSIF res = CalcGauss.RoundoffError THEN
								DataErrors.Warning( "Excessive roundoff error occurred when integrating K." )
							ELSIF res = CalcGauss.RoughIntegrand THEN
								DataErrors.Warning( "A rough integrand encountered when integrating K." )
							ELSE DataErrors.Error( "Unknown error originating from CalcGauss.SolveCplx." )
							END
						END;  BEGIN {EXCLUSIVE}
							a := -alpha * NbrRe.Pi;  b := -a;  yp[0] := alpha;  yp[1] := beta;  yp[2] := 1;
							answer := answer + CalcGauss.SolveCplx( P, a, b, z, CalcGauss.Fine, tolerance, res ) END;
						IF res # CalcGauss.OKay THEN
							IF res = CalcGauss.MaxSubDivReached THEN
								DataErrors.Warning( "Maximum subdivisions reached when integrating P." )
							ELSIF res = CalcGauss.RoundoffError THEN
								DataErrors.Warning( "Excessive roundoff error occurred when integrating P." )
							ELSIF res = CalcGauss.RoughIntegrand THEN
								DataErrors.Warning( "A rough integrand encountered when integrating P." )
							ELSE DataErrors.Error( "Unknown error originating from CalcGauss.SolveCplx." )
							END
						END
					END
				ELSIF (NbrRe.Abs( argZ ) < alpha * NbrRe.Pi) &
					(NbrRe.Abs(NbrRe.Abs( argZ ) - alpha * NbrRe.Pi) > NbrRe.Epsilon) THEN
					IF beta < 1 + alpha THEN
						BEGIN {EXCLUSIVE}
							a := 0;  b := x0;  yk[0] := alpha;  yk[1] := beta;
							answer := CalcGauss.SolveCplx( K, a, b, z, CalcGauss.Medium, tolerance, res ) END;
						IF res # CalcGauss.OKay THEN
							IF res = CalcGauss.MaxSubDivReached THEN
								DataErrors.Warning( "Maximum subdivisions reached when integrating K." )
							ELSIF res = CalcGauss.RoundoffError THEN
								DataErrors.Warning( "Excessive roundoff error occurred when integrating K." )
							ELSIF res = CalcGauss.RoughIntegrand THEN
								DataErrors.Warning( "A rough integrand encountered when integrating K." )
							ELSE DataErrors.Error( "Unknown error originating from CalcGauss.SolveCplx." )
							END
						END
					ELSE
						BEGIN {EXCLUSIVE}
							a := absZ / 2;  b := x0;  yk[0] := alpha;  yk[1] := beta;
							answer := CalcGauss.SolveCplx( K, a, b, z, CalcGauss.Medium, tolerance, res ) END;
						IF res # CalcGauss.OKay THEN
							IF res = CalcGauss.MaxSubDivReached THEN
								DataErrors.Warning( "Maximum subdivisions reached when integrating K." )
							ELSIF res = CalcGauss.RoundoffError THEN
								DataErrors.Warning( "Excessive roundoff error occurred when integrating K." )
							ELSIF res = CalcGauss.RoughIntegrand THEN
								DataErrors.Warning( "A rough integrand encountered when integrating K." )
							ELSE DataErrors.Error( "Unknown error originating from CalcGauss.SolveCplx." )
							END
						END;  BEGIN {EXCLUSIVE}
							a := -alpha * NbrRe.Pi;  b := -a;  yp[0] := alpha;  yp[1] := beta;  yp[2] := absZ / 2;
							answer := answer + CalcGauss.SolveCplx( P, a, b, z, CalcGauss.Fine, tolerance, res ) END;
						IF res # CalcGauss.OKay THEN
							IF res = CalcGauss.MaxSubDivReached THEN
								DataErrors.Warning( "Maximum subdivisions reached when integrating P." )
							ELSIF res = CalcGauss.RoundoffError THEN
								DataErrors.Warning( "Excessive roundoff error occurred when integrating P." )
							ELSIF res = CalcGauss.RoughIntegrand THEN
								DataErrors.Warning( "A rough integrand encountered when integrating P." )
							ELSE DataErrors.Error( "Unknown error originating from CalcGauss.SolveCplx." )
							END
						END
					END;
					answer :=
						answer +
							MathCplx.RealPower( z, (1 - beta) / alpha ) *
								MathCplx.Exp( MathCplx.RealPower( z, 1 / alpha ) ) / alpha
				ELSE
					BEGIN {EXCLUSIVE}
						a := (absZ + 1) / 2;  b := x0;  yk[0] := alpha;  yk[1] := beta;
						answer := CalcGauss.SolveCplx( K, a, b, z, CalcGauss.Medium, tolerance, res ) END;
					IF res # CalcGauss.OKay THEN
						IF res = CalcGauss.MaxSubDivReached THEN
							DataErrors.Warning( "Maximum subdivisions reached when integrating K." )
						ELSIF res = CalcGauss.RoundoffError THEN
							DataErrors.Warning( "Excessive roundoff error occurred when integrating K." )
						ELSIF res = CalcGauss.RoughIntegrand THEN
							DataErrors.Warning( "A rough integrand encountered when integrating K." )
						ELSE DataErrors.Error( "Unknown error originating from CalcGauss.SolveCplx." )
						END
					END;  BEGIN {EXCLUSIVE}
						a := -alpha * NbrRe.Pi;  b := -a;  yp[0] := alpha;  yp[1] := beta;  yp[2] := (absZ + 1) / 2;
						answer := answer + CalcGauss.SolveCplx( P, a, b, z, CalcGauss.Fine, tolerance, res ) END;
					IF res # CalcGauss.OKay THEN
						IF res = CalcGauss.MaxSubDivReached THEN
							DataErrors.Warning( "Maximum subdivisions reached when integrating P." )
						ELSIF res = CalcGauss.RoundoffError THEN
							DataErrors.Warning( "Excessive roundoff error occurred when integrating P." )
						ELSIF res = CalcGauss.RoughIntegrand THEN
							DataErrors.Warning( "A rough integrand encountered when integrating P." )
						ELSE DataErrors.Error( "Unknown error originating from CalcGauss.SolveCplx." )
						END
					END
				END
			ELSE  (* absZ > NbrRe.Floor( 10 + 5*alpha ) *)
				IF argZ < 3 * alpha * NbrRe.Pi / 4 THEN
					answer :=
						MathCplx.RealPower( z, (1 - beta) / alpha ) *
							MathCplx.Exp( MathCplx.RealPower( z, 1 / alpha ) ) / alpha
				ELSE answer := 0
				END;  BEGIN {EXCLUSIVE}
					storeAlpha := alpha;  storeBeta := beta;
					(* Factor of 2 put in for 32-bit precision - needed to assure convergence. *)
					maxIterations := 2 * NbrRe.Floor( -MathRe.Ln( NbrRe.Epsilon ) / MathRe.Ln( absZ ) );  NEW( aml );
					answer := answer - MathCplxSeries.PowerSeries( aml, 1 / z );
					(* Remove the zeroth term from the sum, because the actual starts at one. *)
					IF ~GammaIsSingularAt( beta ) THEN answer := answer + 1 / MathGamma.Fn( beta ) END END
			END
		END;
		RETURN answer
	END CplxFn;

(** The derivative of the Mittag-Leffler function,  dEa,b(z)/dz = ek=0% (1+k)zk/G(a(1+k)+b).  *)
	PROCEDURE DFn*( alpha, beta, x: NbrRe.Real ): NbrRe.Real;
	VAR abs, answer, arg: NbrRe.Real;  dml, z: NbrCplx.Complex;
	BEGIN
		z := x;  dml := DCplxFn( alpha, beta, z );  abs := NbrCplx.Abs( dml );  arg := NbrCplx.Arg( dml );
		IF (arg < tolerance) & (-tolerance < arg) THEN answer := abs
		ELSIF (arg > NbrRe.Pi - tolerance) OR (arg < -NbrRe.Pi + tolerance) THEN answer := -abs
		ELSE DataErrors.Error( "The result is complex.  Use DCplxFn instead." )
		END;
		RETURN answer
	END DFn;

	PROCEDURE DCplxFn*( alpha, beta: NbrRe.Real;  z: NbrCplx.Complex ): NbrCplx.Complex;
	VAR answer: NbrCplx.Complex;  absZ, d, k, k1, omega: NbrRe.Real;  k0: NbrInt.Integer;  dml: DMitLef;
	BEGIN
		alpha := NbrRe.Abs( alpha );  absZ := NbrCplx.Abs( z );
		IF absZ < 1 / NbrRe.MaxNbr THEN
			IF GammaIsSingularAt( alpha + beta ) THEN answer := 0 ELSE answer := 1 / MathGamma.Fn( alpha + beta ) END
		ELSIF absZ < 0.9 THEN
			IF alpha > 1 THEN k1 := 1 + (2 - alpha - beta) / (alpha - 1)
			ELSE
				d := 1 + alpha * (alpha - 4 * beta + 6);  k := 1 + (3 - alpha - beta) / alpha;
				IF d <= 1 THEN k1 := k
				ELSE
					omega := alpha + beta - 1.5;
					k1 := NbrRe.Max( k, 1 + (1 - 2 * omega * alpha + MathRe.Sqrt( d )) / (2 * alpha * alpha) )
				END
			END;  BEGIN {EXCLUSIVE}
				k0 := NbrRe.Ceiling( NbrRe.Max( k1, MathRe.Ln( NbrRe.Epsilon * (1 - absZ) ) ) / MathRe.Ln( absZ ) );
				maxIterations := k0;  storeAlpha := alpha;  storeBeta := beta;  NEW( dml );
				answer := MathCplxSeries.PowerSeries( dml, z ) END
		ELSE
			answer := CplxFn( alpha, beta - 1, z );
			IF beta # 1 THEN answer := answer - (beta - 1) * CplxFn( alpha, beta, z ) END;
			answer := answer / (alpha * z)
		END;
		RETURN answer
	END DCplxFn;

BEGIN
	tolerance := MathRe.Sqrt( NbrRe.Epsilon )
END MathMitLef.