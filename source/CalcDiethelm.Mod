(* CAPO - Computational Analysis Platform for Oberon - by Alan Freed and Felix Friedrich. *)
(* Version 1, Update 2 *)

MODULE CalcDiethelm;   (** AUTHOR "adf"; PURPOSE "Diethelm's algorithms for the fractional calculus"; *)

IMPORT NbrRe, DataErrors, MathRe, MathGamma, CalcFn, CalcD1;

(**  Arguments of differ-integration are:
		f(x)		the function being differ-integrated,
		x		the argument of f, also the upper limit of differ-integration,
		order	(> 0)  the fractional order of differ-integration, i.e., a,
		tol		the requested and achieved error tolerances.

	Arguments for fractional-order differential equations are:
		y		the dependent variable, i.e., the function whose solution is being sought,
		y0		the vector of initial conditions
					if  0  < a <= 1 then y0[0] =  y(0+)
					if  1 < a < 2 then y0[0] =  y(0+) and y0[1] =  y'(0+),
		f(x,y)	the forcing function, i.e., the right-hand side of the differential equation,
		x		the independent variable,
		order	(0 < order < 2)  the fractional order of differentiation, i.e., a,
		tol		the requested and achieved error tolerances.
	*)

TYPE
	Romberg = OBJECT
	VAR index: SIGNED32;
		error, soln: NbrRe.Real;
		factors: POINTER TO ARRAY OF NbrRe.Real;
		tableau: ARRAY 8 OF POINTER TO ARRAY OF NbrRe.Real;

		PROCEDURE & Initialize*;
		VAR i: SIGNED32;
		BEGIN
			index := -1;  error := 0;  soln := 0;  NEW( factors, 8 );
			FOR i := 0 TO 7 DO NEW( tableau[i], i + 1 ) END
		END Initialize;

		PROCEDURE Update( newSolution: NbrRe.Real );
		(* Insert a new row into the Romberg tableau and perform Richardson extrapolation on that row.
			If the tableau is full, then ratchet the first column up one row, throwing away the first entry,
			insert the newSolution into the last row, and perform Richardon extrapolation over the entire tablueau.  *)
		VAR i: SIGNED32;

			PROCEDURE RichardsonExtrapolation;
			VAR k: SIGNED32;  term: NbrRe.Real;
			BEGIN
				FOR k := 1 TO index DO
					term := tableau[index - 1, k - 1];  term := term - factors[k - 1] * tableau[index, k - 1];
					term := term / (1 - factors[k - 1]);  tableau[index, k] := term
				END
			END RichardsonExtrapolation;

		BEGIN
			IF index < 7 THEN
				(* The tableau is not full yet.  Add another row.  Build this row of the tableau. *)
				INC( index );  tableau[index, 0] := newSolution;
				IF index > 0 THEN RichardsonExtrapolation END
			ELSE
				(* The tableau is full.  Ratchet back the rows.  Insert the newSolution.  And rebuild the entire tableau. *)
				FOR i := 0 TO 6 DO tableau[i, 0] := tableau[i + 1, 0] END;
				tableau[7, 0] := newSolution;  index := 0;
				FOR i := 1 TO 7 DO INC( index );  RichardsonExtrapolation END
			END;
			(* Update the error. *)
			IF index < 2 THEN error := NbrRe.MaxNbr
			ELSE
				(* Compute an absolute error. *)
				error := NbrRe.Abs( tableau[index, index - 1] - tableau[index - 1, index - 1] );
				IF NbrRe.Abs( tableau[index, index] ) > 1 THEN
					(* Compute its reletive error. *)
					error := NbrRe.Abs( error / tableau[index, index] )
				END
			END;
			(* Assign the enhanced solution. *)
			soln := tableau[index, index]
		END Update;

	END Romberg;

VAR
	minTol, maxTol: NbrRe.Real;

	PROCEDURE CreateDiffFactors( alpha: NbrRe.Real;  x: Romberg );
	(* Create the factors, i.e., 2^(r[k]), for Richardson extrapolation for differentiation.
		To be called after UpdateAWeights.  *)
	BEGIN
		IF alpha < 1 THEN
			x.factors[0] := MathRe.Power( 2, 2 - alpha );  x.factors[1] := 4;
			x.factors[2] := MathRe.Power( 2, 3 - alpha );  x.factors[3] := MathRe.Power( 2, 4 - alpha );
			x.factors[4] := 16;  x.factors[5] := MathRe.Power( 2, 5 - alpha );
			x.factors[6] := MathRe.Power( 2, 6 - alpha );  x.factors[7] := 64
		ELSE
			(* These are guesses as to what they probably are.  Their actual values have not yet been derived. *)
			x.factors[0] := MathRe.Power( 2, 2 - alpha );  x.factors[1] := MathRe.Power( 2, 3 - alpha );
			x.factors[2] := 4;  x.factors[3] := MathRe.Power( 2, 4 - alpha );
			x.factors[4] := MathRe.Power( 2, 5 - alpha );  x.factors[5] := 16;
			x.factors[6] := MathRe.Power( 2, 6 - alpha );  x.factors[7] := MathRe.Power( 2, 7 - alpha )
		END
	END CreateDiffFactors;

	PROCEDURE CreateIntFactors( alpha: NbrRe.Real;  x: Romberg );
	(* Create the factors, i.e., 2^(r[k]), for Richardson extrapolation for integration.
		To be called after UpdateCWeights.  *)
	BEGIN
		IF alpha < 1 THEN
			x.factors[0] := 4;  x.factors[1] := MathRe.Power( 2, 2 + alpha );  x.factors[2] := 8;
			x.factors[3] := MathRe.Power( 2, 3 + alpha );  x.factors[4] := 16;
			x.factors[5] := MathRe.Power( 2, 4 + alpha );  x.factors[6] := 32;
			x.factors[7] := MathRe.Power( 2, 5 + alpha )
		ELSIF alpha < 2 THEN
			x.factors[0] := 4;  x.factors[1] := 8;  x.factors[2] := MathRe.Power( 2, 2 + alpha );  x.factors[3] := 16;
			x.factors[4] := MathRe.Power( 2, 3 + alpha );  x.factors[5] := 32;
			x.factors[6] := MathRe.Power( 2, 4 + alpha );  x.factors[7] := 64
		ELSIF alpha < 3 THEN
			x.factors[0] := 4;  x.factors[1] := 8;  x.factors[2] := 16;  x.factors[3] := MathRe.Power( 2, 2 + alpha );
			x.factors[4] := 32;  x.factors[5] := MathRe.Power( 2, 3 + alpha );  x.factors[6] := 64;
			x.factors[7] := MathRe.Power( 2, 4 + alpha )
		ELSIF alpha < 4 THEN
			x.factors[0] := 4;  x.factors[1] := 8;  x.factors[2] := 16;  x.factors[3] := 32;
			x.factors[4] := MathRe.Power( 2, 2 + alpha );  x.factors[5] := 64;
			x.factors[6] := MathRe.Power( 2, 3 + alpha );  x.factors[7] := 128
		ELSIF alpha < 5 THEN
			x.factors[0] := 4;  x.factors[1] := 8;  x.factors[2] := 16;  x.factors[3] := 32;  x.factors[4] := 64;
			x.factors[5] := MathRe.Power( 2, 2 + alpha );  x.factors[6] := 128;
			x.factors[7] := MathRe.Power( 2, 3 + alpha )
		ELSIF alpha < 6 THEN
			x.factors[0] := 4;  x.factors[1] := 8;  x.factors[2] := 16;  x.factors[3] := 32;  x.factors[4] := 64;
			x.factors[5] := 128;  x.factors[6] := MathRe.Power( 2, 2 + alpha );  x.factors[7] := 256
		ELSIF alpha < 7 THEN
			x.factors[0] := 4;  x.factors[1] := 8;  x.factors[2] := 16;  x.factors[3] := 32;  x.factors[4] := 64;
			x.factors[5] := 128;  x.factors[6] := 256;  x.factors[7] := MathRe.Power( 2, 2 + alpha )
		ELSE
			x.factors[0] := 4;  x.factors[1] := 8;  x.factors[2] := 16;  x.factors[3] := 32;  x.factors[4] := 64;
			x.factors[5] := 128;  x.factors[6] := 256;  x.factors[7] := 512
		END
	END CreateIntFactors;

	PROCEDURE CreateDiffEqnFactors( alpha: NbrRe.Real;  x: Romberg );
	(* Create the factors, i.e., 2^(r[k]), for Richardson extrapolation for differential equations.
		To be called after UpdateBWeights and UpdateCWeights.  *)
	BEGIN
		IF alpha < 1 THEN
			x.factors[0] := MathRe.Power( 2, 1 + alpha );  x.factors[1] := 4;
			x.factors[2] := MathRe.Power( 2, 2 + alpha );  x.factors[3] := MathRe.Power( 2, 3 + alpha );
			x.factors[4] := 16;  x.factors[5] := MathRe.Power( 2, 4 + alpha );
			x.factors[6] := MathRe.Power( 2, 5 + alpha );  x.factors[7] := 64
		ELSE
			x.factors[0] := 4;  x.factors[1] := MathRe.Power( 2, 1 + alpha );
			x.factors[2] := MathRe.Power( 2, 2 + alpha );  x.factors[3] := 16;
			x.factors[4] := MathRe.Power( 2, 3 + alpha );  x.factors[5] := MathRe.Power( 2, 4 + alpha );
			x.factors[6] := 64;  x.factors[7] := MathRe.Power( 2, 5 + alpha )
		END
	END CreateDiffEqnFactors;

	PROCEDURE VerifyTolerance( VAR tol: NbrRe.Real );
	BEGIN
		tol := NbrRe.Abs( tol );
		IF tol < minTol THEN tol := minTol ELSIF tol > maxTol THEN tol := maxTol ELSE (* tol is okay *) END
	END VerifyTolerance;

	(** Computes a Riemann-Liouville fractional-order integral.
		Iaf(x) = (1/G(a)) x0x (x-y)a-1 f(y) dy,  where  0 < a.  *)
	PROCEDURE SolveI*( f: CalcFn.ReArg;  x, order: NbrRe.Real;  VAR tol: NbrRe.Real ): NbrRe.Real;
	VAR i, n: SIZE;  firstWeight, gamma, h, solution: NbrRe.Real;
		cWeights, fn, save: POINTER TO ARRAY OF NbrRe.Real;  pWeights: ARRAY 3 OF NbrRe.Real;
		romberg: Romberg;

		PROCEDURE UpdateCWeights;
		VAR len, newLen: SIZE;  m: NbrRe.Real;
		BEGIN
			m := 1 + order;
			IF cWeights = NIL THEN
				NEW( cWeights, 5 );
				pWeights[0] := MathRe.Power( 2, m );
				pWeights[1] := MathRe.Power( 3, m );
				pWeights[2] := MathRe.Power( 4, m );
				cWeights[0] := 1;
				cWeights[1] := pWeights[0] - 2;
				cWeights[2] := pWeights[1] - 2 * pWeights[0] + 1;
				cWeights[3] := pWeights[2] - 2 * pWeights[1] + pWeights[0];
				pWeights[0] := pWeights[1];
				pWeights[1] := pWeights[2];
				pWeights[2] := MathRe.Power( 5, m );
				cWeights[4] := pWeights[2] - 2 * pWeights[1] + pWeights[0];
				firstWeight := (m / 4 - 1 ) * pWeights[1] + pWeights[0]
			ELSE
				save := cWeights;  len := LEN( cWeights^ );  cWeights := NIL;
				newLen := 2 * (len - 1) + 1;  NEW( cWeights, newLen );
				FOR i := 0 TO len - 1 DO cWeights[i] := save[i] END;
				FOR i := len TO newLen - 1 DO
					pWeights[0] := pWeights[1];
					pWeights[1] := pWeights[2];
					pWeights[2] := MathRe.Power( i + 1, m );
					cWeights[i] := pWeights[2] - 2 * pWeights[1] + pWeights[0]
				END;
				firstWeight := (m / (newLen - 1) - 1) * pWeights[1] + pWeights[0]
			END
		END UpdateCWeights;

	BEGIN
		IF order > 0 THEN
			NEW( romberg );  VerifyTolerance( tol );
			IF x < 0 THEN solution := -SolveI( f, -x, order, tol )
			ELSIF x = 0 THEN solution := 0
			ELSE  (* integrate *)
				CreateIntFactors( order, romberg );  gamma := MathGamma.Fn( 2 + order );
				(* The algorithmic loop. *)
				REPEAT
					UpdateCWeights;  n := LEN( cWeights^ ) - 1;  h := x / n;
					(* Function evaluations over the history. *)
					IF n = 4 THEN
						NEW( fn, 5 );
						FOR i := 0 TO n DO fn[i] := f( h * i ) END
					ELSE
						save := fn;  fn := NIL;  NEW( fn, n + 1 );
						FOR i := 0 TO n BY 2 DO fn[i] := save[i DIV 2] END;
						FOR i := 1 TO n-1 BY 2 DO fn[i] := f( h * i ) END;
					END;
					(* The quadrature algorithm. *)
					solution := firstWeight * fn[0];
					FOR i := 1 TO n DO solution := solution + cWeights[n - i] * fn[i] END;
					romberg.Update( MathRe.Power( h, order ) * solution / gamma )
				UNTIL romberg.error < tol;
				solution := romberg.soln;  tol := romberg.error
			END
		ELSE solution := 0;  DataErrors.ReError( order, "The requested order of integration is not allowed." )
		END;
		RETURN solution
	END SolveI;

	(** Computes a Caputo fractional-order derivative.
		D*af(x) = IaDnf(x) = (1/G(n-a)) x0x (x-y)n-1-a [dnf(y)/dyn] dy,  f(k)(0+) = f0[k],  where  0 < a < 2, a # 1. *)
	PROCEDURE SolveD*( f: CalcFn.ReArg;  x, order: NbrRe.Real;  VAR tol: NbrRe.Real ): NbrRe.Real;
	VAR i, n: SIZE;  df0, f0, gamma, h, lastWeight, solution: NbrRe.Real;
		aWeights, fn, save: POINTER TO ARRAY OF NbrRe.Real;  mWeights: ARRAY 3 OF NbrRe.Real;
		romberg: Romberg;

		PROCEDURE UpdateAWeights;
		VAR len, newLen: SIZE;  m: NbrRe.Real;
		BEGIN
			m := 1 - order;
			IF aWeights = NIL THEN
				NEW( aWeights, 5 );
				mWeights[0] := MathRe.Power( 2, m );
				mWeights[1] := MathRe.Power( 3, m );
				mWeights[2] := MathRe.Power( 4, m );
				aWeights[0] := 1;
				aWeights[1] := mWeights[0] - 2;
				aWeights[2] := mWeights[1] - 2 * mWeights[0] + 1;
				aWeights[3] := mWeights[2] - 2 * mWeights[1] + mWeights[0];
				mWeights[0] := mWeights[1];
				mWeights[1] := mWeights[2];
				mWeights[2] := MathRe.Power( 5, m );
				aWeights[4] := mWeights[2] - 2 * mWeights[1] + mWeights[0];
				lastWeight := (m / 4 - 1) * mWeights[1] + mWeights[0]
			ELSE
				save := aWeights;  len := LEN( aWeights^ );  aWeights := NIL;
				newLen := 2 * (len - 1) + 1;  NEW( aWeights, newLen );
				FOR i := 0 TO len - 1 DO aWeights[i] := save[i] END;
				FOR i := len TO newLen - 1 DO
					mWeights[0] := mWeights[1];
					mWeights[1] := mWeights[2];
					mWeights[2] := MathRe.Power( i + 1, m );
					aWeights[i] := mWeights[2] - 2 * mWeights[1] + mWeights[0]
				END;
				lastWeight := (m / (newLen - 1) - 1) * mWeights[1] + mWeights[0]
			END
		END UpdateAWeights;

	BEGIN
		IF ((0 < order) & (order # 1) & (order < 2)) THEN
			NEW( romberg );  VerifyTolerance( tol );
			IF x < 0 THEN solution := -SolveD( f, -x, order, tol )
			ELSIF x = 0 THEN solution := 0
			ELSE  (* differentiate *)
				CreateDiffFactors( order, romberg );  gamma := MathGamma.Fn( 2 - order );
				(* Account for the initial conditions. *)
				f0 := f( NbrRe.Epsilon * x );
				IF order > 1 THEN df0 := CalcD1.Solve( f, 0, CalcD1.Forward ) ELSE df0 := 0 END;
				(* The algorithmic loop. *)
				REPEAT
					UpdateAWeights;  n := LEN( aWeights^ ) - 1;  h := x / n;  solution := 0;
					(* Function evaluations over the history. *)
					IF n = 4 THEN
						NEW( fn, 5 );
						FOR i := 0 TO n DO fn[i] := f( h * (n - i) ) END
					ELSE
						save := fn;  fn := NIL;  NEW( fn, n + 1 );
						FOR i := 0 TO n BY 2 DO fn[i] := save[i DIV 2] END;
						FOR i := 1 TO n-1 BY 2 DO fn[i] := f( h * (n - i) ) END;
					END;
					(* The quadrature algorithm. *)
					FOR i := 0 TO n - 1 DO
						solution := solution + aWeights[i] * (fn[i] - f0 - h * (n - i) * df0)
					END;
					solution := solution + lastWeight * (fn[n] - f0);
					romberg.Update( solution / (gamma * MathRe.Power( h, order )) )
				UNTIL romberg.error < tol;
				solution := romberg.soln;  tol := romberg.error
			END
		ELSE solution := 0;  DataErrors.ReError( order, "The requested order of differentiation is not allowed." )
		END;
		RETURN solution
	END SolveD;

	(** Solves a fractional-order differential equation of the Caputo type.
		D*ay(x) = f(x,y(x)),  y(k)(0+) = y0[k],  where  0  < a < 2. *)
	PROCEDURE SolveFODE*( f: CalcFn.Re2Arg;  y0: ARRAY OF NbrRe.Real;  x, order: NbrRe.Real;
							VAR tol: NbrRe.Real ): NbrRe.Real;
	VAR i, k, n: SIZE;  cCoef, pCoef, cSum, pSum, firstWeight, fn, gamma1, gamma2, h,
		h2alpha, initialCondition, p, predictor, solution: NbrRe.Real;
		bWeights, cWeights, save, y: POINTER TO ARRAY OF NbrRe.Real;
		weights: ARRAY 2 OF NbrRe.Real;  pWeights: ARRAY 3 OF NbrRe.Real;
		romberg: Romberg;

		PROCEDURE UpdateBWeights;
		VAR len, newLen: SIZE;  m: NbrRe.Real;
		BEGIN
			m := order;
			IF bWeights = NIL THEN
				NEW( bWeights, 5 );
				weights[0] := MathRe.Power( 2, m );
				weights[1] := MathRe.Power( 3, m );
				bWeights[0] := 0;
				bWeights[1] := 1;
				bWeights[2] := weights[0] - 1;
				bWeights[3] := weights[1] - weights[0];
				weights[0] := weights[1];
				weights[1] := MathRe.Power( 4, m );
				bWeights[4] := weights[1] - weights[0]
			ELSE
				save := bWeights;  len := LEN( bWeights^ );  bWeights := NIL;
				newLen := 2 * (len - 1) + 1;  NEW( bWeights, newLen );
				FOR i := 0 TO len - 1 DO bWeights[i] := save[i] END;
				FOR i := len TO newLen - 1 DO
					weights[0] := weights[1];
					weights[1] := MathRe.Power( i, m );
					bWeights[i] := weights[1] - weights[0]
				END
			END
		END UpdateBWeights;

		PROCEDURE UpdateCWeights;
		VAR len, newLen: SIZE;  m: NbrRe.Real;
		BEGIN
			m := 1 + order;
			IF cWeights = NIL THEN
				NEW( cWeights, 5 );
				pWeights[0] := MathRe.Power( 2, m );
				pWeights[1] := MathRe.Power( 3, m );
				pWeights[2] := MathRe.Power( 4, m );
				cWeights[0] := 1;
				cWeights[1] := pWeights[0] - 2;
				cWeights[2] := pWeights[1] - 2 * pWeights[0] + 1;
				cWeights[3] := pWeights[2] - 2 * pWeights[1] + pWeights[0];
				pWeights[0] := pWeights[1];
				pWeights[1] := pWeights[2];
				pWeights[2] := MathRe.Power( 5, m );
				cWeights[4] := pWeights[2] - 2 * pWeights[1] + pWeights[0]
			ELSE
				save := cWeights;  len := LEN( cWeights^ );  cWeights := NIL;
				newLen := 2 * (len - 1) + 1;  NEW( cWeights, newLen );
				FOR i := 0 TO len - 1 DO cWeights[i] := save[i] END;
				FOR i := len TO newLen - 1 DO
					pWeights[0] := pWeights[1];
					pWeights[1] := pWeights[2];
					pWeights[2] := MathRe.Power( i + 1, m );
					cWeights[i] := pWeights[2] - 2 * pWeights[1] + pWeights[0]
				END
			END
		END UpdateCWeights;

	BEGIN
		IF ((0 < order) & (order < 2)) THEN
			NEW( romberg );  VerifyTolerance( tol );
			IF order <= 1 THEN
				IF LEN( y0 ) < 1 THEN
					DataErrors.Error( "Initial-condition vector is of insufficient length." ); RETURN 0
				END
			ELSE
				IF LEN( y0 ) < 2 THEN
					DataErrors.Error( "Initial-condition vector is of insufficient length." ); RETURN 0
				END
			END;
			IF x < 0 THEN solution := -SolveFODE( f, y0, -x, order, tol )
			ELSIF x = 0 THEN solution := y0[0]
			ELSE  (* solve *)
				CreateDiffEqnFactors( order, romberg );  p := 1 + order;
				gamma1 := MathGamma.Fn( p );  gamma2 := MathGamma.Fn( 1 + p );
				(* The algorithmic loop. *)
				REPEAT
					UpdateBWeights;  UpdateCWeights;  n := LEN( cWeights^ ) - 1;
					h := x / n;  h2alpha := MathRe.Power( h, order );
					pCoef := h2alpha / gamma1;  cCoef := h2alpha / gamma2;
					y := NIL;  NEW( y, n + 1 );  y[0] := y0[0];
					FOR i := 1 TO n DO
						(* Integrate along the solution path to get y(i*h) for i = 1...n. *)
						initialCondition := y0[0];  firstWeight := (p / i - 1) * MathRe.Power( i, p );
						IF order > 1 THEN initialCondition := initialCondition + i * h * y0[1]  END;
						IF i > 1 THEN firstWeight := firstWeight + MathRe.Power( i - 1, p ) END;
						fn := f( 0, y[0] );  pSum := bWeights[i] * fn;  cSum := firstWeight * fn;
						FOR k := 1 TO i - 1 DO
							fn := f( k * h, y[k] );
							pSum := pSum + bWeights[i - k] * fn;  cSum := cSum + cWeights[i - k] * fn
						END;
						predictor := initialCondition + pCoef * pSum;
						y[i] := initialCondition + cCoef * (cSum + cWeights[0]* f( i * h, predictor ))
					END;
					romberg.Update( y[n] )
				UNTIL romberg.error < tol;
				solution := romberg.soln;  tol := romberg.error
			END
		ELSE solution := 0;  DataErrors.ReError( order, "The requested order of differentiation is not allowed." )
		END;
		RETURN solution
	END SolveFODE;

BEGIN
	minTol := MathRe.Sqrt( NbrRe.Epsilon );  maxTol := 0.1
END CalcDiethelm.
