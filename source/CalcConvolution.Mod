(* CAPO - Computational Analysis Platform for Oberon - by Alan Freed and Felix Friedrich. *)
(* Version 1, Update 2 *)

MODULE CalcConvolution;   (** AUTHOR "adf"; PURPOSE "Accurate computation of a convolution integral"; *)

(* Based on Algorithm 2 in: Diethelm, K. and Freed, A.D., "An Efficient Algorithm for the Evaluation of
	Convolution Integrals."  In review.  The level of effort required by this algorithm is O(N ln N).  *)

IMPORT NbrInt, NbrRe, DataErrors, MathInt, MathRe, CalcFn;

	PROCEDURE LogP( p, x: NbrRe.Real ): NbrRe.Real;
	BEGIN
		RETURN MathRe.Ln( x ) / MathRe.Ln( p )
	END LogP;

	(** Returns the smallest dimension (number of rows) of the solution array returned in  Solve  that is allowed. *)
	PROCEDURE GetArrayDimension*( x, t: NbrRe.Real;  n: NbrInt.Integer ): NbrInt.Integer;
	BEGIN
		RETURN NbrRe.Ceiling( n * x / t ) + 1
	END GetArrayDimension;

	(** Solves the convolution integral  y =  x0x k(x-u) f(u,x) du.
	The input parameters are:
		k	is a univariate kernel function, which must be positive and decay monotonically,
			and  k(0) = %  is allowed,
		f	is a bivariate forcing function,
		x	is the upper limit of integration, the lower limit is set to zero,  x > 0,
		t	is the characteristic time affiliated with kernel  k,  t > 0,
		n	is the number of integration steps applied to each interval of characteristic length  t, n > 3,
		p	is a parameter that balances speed (smaller values) against accuracy (larger values)
			with typical values ranging between 4 and 6,  p > 1.
	The return parameter is:
		soln	is an array of dimension  hn*x/ti + 1 4 2  or greater containing pairs  {xi , yi}  where:
			xi = i*x/J,  yi =  x0xi k(xi- u) f(u,xi) du,  i = 0,1, 2, ..., J,  J = hn*x/ti.
	*)
	PROCEDURE Solve*( k: CalcFn.ReArg;  f: CalcFn.Re2Arg;  x, t: NbrRe.Real;  n, p: NbrInt.Integer;
						   VAR soln: ARRAY OF ARRAY OF NbrRe.Real );
	VAR i, j, l, s, z, gamma, iBar, jj, mu, power, sigma: NbrInt.Integer;  h, prod, sum, xi: NbrRe.Real;
		kernel: POINTER TO ARRAY OF ARRAY OF NbrRe.Real;
		laplaceArray: ARRAY 5 OF NbrRe.Real;
		laplaceMatrix: ARRAY 8, 8 OF NbrRe.Real;
	BEGIN
		IF k # NIL THEN
			IF f # NIL THEN
				IF x > 0 THEN
					IF t > 0 THEN
						IF LEN( soln, 0 ) > NbrRe.Ceiling( n * x / t ) THEN
							IF LEN( soln, 1 ) > 1 THEN
								IF n < 4 THEN n := 4 END;
								IF p < 2 THEN p := 2 END;
								(* Initialize variables. *)
								h := t / n;  mu := NbrInt.Max( 1, NbrRe.Ceiling( LogP( p, x / t ) ) );
								(* Create the table of required kernel values. *)
								NEW( kernel, mu + 1, p * n + 1 );
								FOR i := 1 TO p * n DO kernel[1, i] := k( h * (i - 0.5) ) END;
								FOR j := 2 TO mu DO
									FOR i := 1 TO (p - 1) * n DO kernel[j, i] := k( (t + h * (i - 0.5)) * MathInt.Power( p, j - 1 ) ) END
								END;
								(* Determine the weights of Laplace quadrature when there are 4, 5, 6 or 7 nodes. *)
								FOR j := 4 TO 7 DO
									FOR i := 1 TO j DO laplaceMatrix[i, j] := 1 END;
									laplaceMatrix[1, j] := laplaceMatrix[1, j] + 703 / 5760;
									laplaceMatrix[2, j] := laplaceMatrix[2, j] - 463 / 1920;
									laplaceMatrix[3, j] := laplaceMatrix[3, j] + 101 / 640;
									laplaceMatrix[4, j] := laplaceMatrix[4, j] - 223 / 5760;
									laplaceMatrix[j, j] := laplaceMatrix[j, j] + 703 / 5760;
									laplaceMatrix[j - 1, j] := laplaceMatrix[j - 1, j] - 463 / 1920;
									laplaceMatrix[j - 2, j] := laplaceMatrix[j - 2, j] + 101 / 640;
									laplaceMatrix[j - 3, j] := laplaceMatrix[j - 3, j] - 223 / 5760;
								END;
								(* Determine the weight of Laplace quadrature when there are 8 or more nodes. *)
								laplaceArray[1] := 1 + 703 / 5760;  laplaceArray[2] := 1 - 463 / 1920;
								laplaceArray[3] := 1 + 101 / 640;  laplaceArray[4] := 1 - 223 / 5760;
								(* The main part of the algorithm. *)
								jj := NbrRe.Ceiling( x / h );  soln[0, 0] := 0;  soln[0, 1] := 0;
								(* Solve at the grid points in sub-interval  [0,  p*t]. *)
								IF mu = 1 THEN iBar := jj ELSE iBar := p * n END;
								FOR i := 1 TO NbrInt.Min( 3, iBar ) DO
								(* MacLaurin approximation for  x0xi k(xi- u) f(u,xi) du. *)
									xi := i * h;  soln[i, 0] := xi;
									soln[i, 1] :=
										i * h *
										(13 * (k( 7 * xi / 8 ) * f( xi / 8, xi ) + k( xi / 8 ) * f( 7 * xi / 8, xi )) +
										  11 * (k( 5 * xi / 8 ) * f( 3 * xi / 8, xi ) + k( 3 * xi / 8 ) * f( 5 * xi / 8, xi ))) / 48
								END;
								FOR i := 4 TO NbrInt.Min( 7, iBar ) DO
								(* Laplace approximation for  x0xi k(xi- u) f(u,xi) du. *)
									xi := i * h;  soln[i, 0] := xi;  soln[i, 1] := 0;
									FOR j := 1 TO i DO
										prod := laplaceMatrix[j, i] * kernel[1, j] * f( (i - j + 0.5) * h, xi );  soln[i, 1] := soln[i, 1] + prod
									END;
									soln[i, 1] := h * soln[i, 1]
								END;
								FOR i := 8 TO iBar DO
								(* Continue with Laplace approximation for  x0xi k(xi- u) f(u,xi) du. *)
									xi := i * h;  soln[i, 0] := xi;  soln[i, 1] := 0;
									FOR j := 1 TO 4 DO
										prod := laplaceArray[j] * kernel[1, j] * f( (i - j + 0.5) * h, xi );  soln[i, 1] := soln[i, 1] + prod
									END;
									FOR j := 5 TO i - 4 DO prod := kernel[1, j] * f( (i - j + 0.5) * h, xi );  soln[i, 1] := soln[i, 1] + prod END;
									FOR j := i - 3 TO i DO
										prod := laplaceArray[i + 1 - j] * kernel[1, j] * f( (i - j + 0.5) * h, xi );
										soln[i, 1] := soln[i, 1] + prod
									END;
									soln[i, 1] := h * soln[i, 1]
								END;
								(* Solve at the remaining grid points. *)
								FOR i := iBar + 1 TO jj DO
								(* Determine the contribution from  x0pst k(xi- u) f(u,xi) du. *)
									xi := i * h;  soln[i, 0] := xi;  soln[i, 1] := 0;
									FOR j := 1 TO 4 DO
										prod := laplaceArray[j] * kernel[1, j] * f( (i - j + 0.5) * h, xi );  soln[i, 1] := soln[i, 1] + prod
									END;
									FOR j := 5 TO p * n - 4 DO
										prod := kernel[1, j] * f( (i - j + 0.5) * h, xi );  soln[i, 1] := soln[i, 1] + prod
									END;
									FOR j := p * n - 3 TO p * n DO
										prod := laplaceArray[p * n + 1 - j] * kernel[1, j] * f( (i - j + 0.5) * h, xi );
										soln[i, 1] := soln[i, 1] + prod
									END;
									sigma := NbrRe.Ceiling( LogP( p, i / n ) ) - 1;
									FOR s := 1 TO sigma - 1 DO
										sum := 0;  power := MathInt.Power( p, s );
										FOR j := 1 TO 4 DO
											sum := sum + laplaceArray[j] * kernel[s + 1, j] * f( xi - (t + h * (j - 0.5)) * power, xi )
										END;
										FOR j := 5 TO n * (p - 1) - 4 DO
											sum := sum + kernel[s + 1, j] * f( xi - (t + h * (j - 0.5)) * power, xi )
										END;
										FOR j := n * (p - 1) - 3 TO n * (p - 1) DO
											sum :=
												sum +
												laplaceArray[n * (p - 1) + 1 - j] * kernel[s + 1, j] * f( xi - (t + h * (j - 0.5)) * power, xi )
										END;
										soln[i, 1] := soln[i, 1] + power * sum
									END;
									soln[i, 1] := h * soln[i, 1];
									(* Add to this the contribution from  xpstXi k(xi- u) f(u,xi) du. *)
									power := MathInt.Power( p, sigma );  l := i - n * power;
									IF l < 4 * power THEN
										(* Use a MacLaurin approximation. *)
										soln[i, 1] :=
											soln[i, 1] +
											l * h *
						  (13 * (k( (i - l / 8) * h ) * f( l * h / 8, xi ) + k( (i - 7 * l / 8) * h ) * f( 7 * l * h / 8, xi )) +
						    11 * (k( (i - 3 * l / 8) * h ) * f( 3 * l * h / 8, xi ) + k( (i - 5 * l / 8) * h ) * f( 5 * l * h / 8, xi ))) / 48
									ELSE
										(* Use a Laplace approximation for  xpstXps(n+g) k(xi- u) f(u,xi) du. *)
										sum := 0;  gamma := NbrRe.Floor( l / power );
										IF gamma < 8 THEN
											FOR j := 1 TO gamma DO
												sum :=
													sum +
													laplaceMatrix[j, gamma] * kernel[sigma + 1, j] * f( xi - (t + h * (j - 0.5)) * power, xi )
											END;
											soln[i, 1] := soln[i, 1] + h * power * sum
										ELSE
											FOR j := 1 TO 4 DO
												sum :=
													sum + laplaceArray[j] * kernel[sigma + 1, j] * f( xi - (t + h * (j - 0.5)) * power, xi )
											END;
											FOR j := 5 TO gamma - 4 DO
												sum := sum + kernel[sigma + 1, j] * f( xi - (t + h * (j - 0.5)) * power, xi )
											END;
											FOR j := gamma - 3 TO gamma DO
												sum :=
													sum +
													laplaceArray[gamma + 1 - j] * kernel[sigma + 1, j] *
										  f( xi - (t + h * (j - 0.5)) * power, xi )
											END;
											soln[i, 1] := soln[i, 1] + h * power * sum
										END;
										(* Use a MacLaurin approximation for  xXps(n+g)Xi k(xi- u) f(u,xi) du. *)
										z := i - power * (n + gamma);
										soln[i, 1] :=
											soln[i, 1] +
											h * z *
						  (13 * (k( (i - z / 8) * h ) * f( z * h / 8, xi ) + k( (i - 7 * z / 8) * h ) * f( 7 * z * h / 8, xi )) +
						    11 * (k( (i - 3 * z / 8) * h ) * f( 3 * z * h / 8, xi ) + k( (i - 5 * z / 8) * h ) * f( 5 * z * h / 8, xi ))) / 48
									END
								END
							ELSE DataErrors.Error( "The second dimension of the solution array must be at least 2." )
							END
						ELSE DataErrors.IntError( LEN( soln, 0 )(NbrInt.Integer), "The solution array is too short." )
						END
					ELSE DataErrors.ReError( t, "The characteristic time is required to be positive." )
					END
				ELSE DataErrors.ReError( x, "The upper limit of integration is required to be positive." )
				END
			ELSE DataErrors.Error( "The supplied forcing function was NIL." )
			END
		ELSE DataErrors.Error( "The supplied kernel function was NIL." )
		END
	END Solve;

END CalcConvolution.
