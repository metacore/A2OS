MODULE MatrixOptim;
(**
Methods for 1- and N-dimensional function minimization.
*)
(** Oberon Version (c) Patrick Hunziker, 2003-2006  *)

(**  References:
  0) Pascal Unit "OPTIM.PAS 2.0', (c) J.Debord, August 2000)
  1) 'Numerical Recipes' by Press et al.
  2) D. W. MARQUARDT, J. Soc. Indust. Appl. Math., 1963, 11, 431-441
  3) J. A. NELDER & R. MEAD, Comput. J., 1964, 7, 308-313
  4) R. O'NEILL, Appl. Statist., 1971, 20, 338-345
 *)

IMPORT MathL, MatrixBase, MatrixStandardSolvers;

CONST
	(** procedure results *)
	OK* = MatrixBase.OK;   (* No error *)
	SING* = MatrixBase.SINGULAR;   (* Singular hessian matrix *)
	BIGLAMBDA* = -1;   (* Too high Marquardt's parameter *)
	NONCONV* = MatrixBase.NONCONVERGENCE;   (* Non-convergence *)

	GOLD = 1.61803398874989484821;   (* Golden Mean = (1 + Sqrt(5))/2 *)
	CGOLD = 0.38196601125010515179;   (* 2 - GOLD *)

TYPE
	Real* = FLOAT64;
	Vector* = ARRAY [ * ] OF Real;
	Matrix* = ARRAY [ * , * ] OF Real;

	(** Function of one variable *)
	TFunc* = PROCEDURE {DELEGATE} ( X: Real ): Real;

	(** Function of several variables *)
	TFuncNVar* = PROCEDURE ( CONST X: Vector ): Real;

	(** Procedure to compute gradient vector *)
	TGradient* = PROCEDURE ( Func: TFuncNVar;  VAR X: Vector;  VAR G: Vector );

	(** Procedure to compute gradient vector and hessian matrix *)
	THessGrad* = PROCEDURE ( Func: TFuncNVar;  VAR X: Vector;  VAR G: Vector;  VAR H: Matrix );

 	(** Function of several variables *)
	OFunc* = OBJECT
			VAR
				X, DeltaX: Vector;
				Func: TFuncNVar;
			PROCEDURE & Init* (Func:TFuncNVar; VAR X,DeltaX: Vector);
			BEGIN
				SELF.X:=X; SELF.DeltaX:=DeltaX; (*to do: shallow copy for speed*)
				SELF.Func:=Func;
			END Init;
			PROCEDURE F1dim*(R:Real):Real;
			BEGIN
				RETURN Func(X+ R * DeltaX)
			END F1dim;
		END OFunc;

CONST
	WriteLog = FALSE;   (* Write iteration info to System.Log *)

VAR
	Eps: Real;   (* Fractional increment for numer. derivation *)


	PROCEDURE swap( VAR a, b: Real );
	VAR c: Real;
	BEGIN
		c := a;  a := b;  b := c
	END swap;

	PROCEDURE Max( a, b: Real ): Real;
	BEGIN
		IF a > b THEN RETURN a ELSE RETURN b END
	END Max;



(* ----------------------------------------------------------------------
  Given two points (A, B) this PROCEDURE finds a triplet (A, B, C)
  such that:

  1) A < B < C
  2) A, B, C are within the golden ratio
  3) Func(B) < Func(A) and Func(B) < Func(C).

  The corresponding function values are returned in Fa, Fb, Fc
  ---------------------------------------------------------------------- *)
	PROCEDURE MinBrack( Func: TFunc;  VAR A, B, C, Fa, Fb, Fc: Real );
	BEGIN
		IF A > B THEN swap( A, B ) END;
		Fa := Func( A );  Fb := Func( B );
		IF Fb > Fa THEN swap( A, B );  swap( Fa, Fb );  END;
		C := B + GOLD * (B - A);  Fc := Func( C );
		WHILE Fc < Fb DO A := B;  B := C;  Fa := Fb;  Fb := Fc;  C := B + GOLD * (B - A);  Fc := Func( C );  END;
		IF A > C THEN swap( A, C );  swap( Fa, Fc );  END;
	END MinBrack;


(** ----------------------------------------------------------------------
  Performs a golden search for the minimum of function Func
  ----------------------------------------------------------------------
  Input parameters  : Func    = objective function
                      A, B    = two points near the minimum
                      MaxIter = maximum number of iterations
                      Tol     = required precision (should not be less than the square root of the machine precision)
  ----------------------------------------------------------------------
  Output parameters : Xmin, Ymin = coordinates of minimum
  ----------------------------------------------------------------------
  Possible results  : OK
                      NONCONV
  ---------------------------------------------------------------------- *)

	PROCEDURE GoldSearch*( Func: TFunc;  A, B: Real;  MaxIter: SIGNED32;  Tol: Real;  VAR Xmin, Ymin: Real ): SIGNED32;
	VAR C, Fa, Fb, Fc, F1, F2, MinTol, X0, X1, X2, X3: Real;  Iter: SIGNED32;
	(*
		PROCEDURE minBrack( VAR A, B, C, Fa, Fb, Fc: Real );
		BEGIN
			IF A > B THEN swap( A, B ) END;
			Fa := Func( A );  Fb := Func( B );
			IF Fb > Fa THEN swap( A, B );  swap( Fa, Fb );  END;
			C := B + GOLD * (B - A);  Fc := Func( C );
			WHILE Fc < Fb DO A := B;  B := C;  Fa := Fb;  Fb := Fc;  C := B + GOLD * (B - A);  Fc := Func( C );  END;
			IF A > C THEN swap( A, C );  swap( Fa, Fc );  END;
		END minBrack;
	*)
	BEGIN
		MinTol := MathL.sqrt( MatrixBase.EPS );
		IF Tol < MinTol THEN Tol := MinTol END;
		(*minBrack( A, B, C, Fa, Fb, Fc );  *)
		MinBrack( Func, A, B, C, Fa, Fb, Fc );
		X0 := A;  X3 := C;
		IF (C - B) > (B - A) THEN X1 := B;  X2 := B + CGOLD * (C - B);  F1 := Fb;  F2 := Func( X2 );
		ELSE X1 := B - CGOLD * (B - A);  X2 := B;  F1 := Func( X1 );  F2 := Fb;
		END;
		Iter := 0;
		WHILE (Iter <= MaxIter) & (ABS( X3 - X0 ) > Tol * (ABS( X1 ) + ABS( X2 ))) DO
			IF F2 < F1 THEN X0 := X1;  X1 := X2;  F1 := F2;  X2 := X1 + CGOLD * (X3 - X1);  F2 := Func( X2 );  INC( Iter );
			ELSE X3 := X2;  X2 := X1;  F2 := F1;  X1 := X2 - CGOLD * (X2 - X0);  F1 := Func( X1 );  INC( Iter );
			END;
		END;
		IF F1 < F2 THEN Xmin := X1;  Ymin := F1;  ELSE Xmin := X2;  Ymin := F2;  END;
		IF Iter > MaxIter THEN RETURN NONCONV ELSE RETURN OK END;
	END GoldSearch;

(** ----------------------------------------------------------------------
  Minimization of a function of several variables by the simplex method of Nelder and Mead
  ----------------------------------------------------------------------
  Input parameters  :
  	Func    = objective function
      X       = initial minimum coordinates
      MaxIter = maximum number of iterations
      Tol     = required precision
  ----------------------------------------------------------------------
  Output parameters :
  	X     = refined minimum coordinates  Fmin = function value at minimum
  ----------------------------------------------------------------------
  Possible results :
  	OK
      NONCONV
  ---------------------------------------------------------------------- *)
	PROCEDURE Simplex*( Func: TFuncNVar;  VAR X: Vector;  MaxIter: SIGNED32;  Tol: Real;  VAR Fmin: Real ): SIGNED32;
	CONST Step = 1.50;   (* Step used to construct the initial simplex *)
	VAR P: Matrix;   (* Simplex coordinates *)
		F: Vector;   (* Function values *)
		Pbar: Vector;   (* Centroid coordinates *)
		Pstar, P2star: Vector;   (* New vertices *)
		Ystar, Y2star: Real;   (* New function values *)
		F0: Real;   (* Function value at minimum *)
		N: SIZE;   (* Number of parameters *)
		M: SIZE;   (* Index of last vertex *)
		L, H: SIZE;   (* Vertices with lowest & highest F values *)
		I, J: SIZE;   (* Loop variables *)
		Iter: SIZE;   (* Iteration count *)
		Corr, MaxCorr: Real;   (* Corrections *)
		Sum: Real;  Flag: BOOLEAN;  i: SIGNED32;  Ubound: SIZE;

		PROCEDURE UpdateSimplex( Y: Real;  CONST Q: Vector );   (* Update "worst" vertex & function value *)
		VAR i: SIGNED32;
		BEGIN
			F[H] := Y;  P[H, .. ] := Q[.. ];
		END UpdateSimplex;

	BEGIN
		Ubound := LEN( X,0 ) - 1;  N := Ubound - 0 + 1;  M := (1 + Ubound);

		NEW( P, M + 1, Ubound + 1 );  NEW( F, M + 1 );  NEW( Pbar, Ubound + 1 );  NEW( Pstar, Ubound + 1 );  NEW( P2star, Ubound + 1 );

		Iter := 1;  F0 := MAX( Real );

		(* Construct initial simplex *)
		FOR I := 0 TO M DO P[I, .. ] := X;  END;

		FOR I := 0 TO Ubound DO P[I, I] := P[I, I] * Step END;

		(* Evaluate function at each vertex *)
		FOR I := 0 TO M DO F[I] := Func( P[I] ) END;

		REPEAT
			(* Find vertices (L,H) having the lowest & highest function values, i.e. "best" & "worst" vertices *)
			L := 0;  H := 0;
			FOR I := (1 + 0) TO M DO
				IF F[I] < F[L] THEN L := I
				ELSIF F[I] > F[H] THEN H := I
				END
			END;
			IF F[L] < F0 THEN F0 := F[L] END;

			(* Find centroid of points other than P(H) *)
			FOR J := 0 TO Ubound DO
				Sum := 0.0;
				FOR I := 0 TO M DO
					IF I # H THEN Sum := Sum + P[I, J] END;  (* improve *)
				END;
				Pbar[J] := Sum / N;
			END;

			(* Reflect worst vertex through centroid *)
			Pstar[.. ] := 2 * Pbar[.. ];
			Pstar[.. ] := Pstar[.. ] - P[H, .. ];
			Ystar := Func( Pstar );

			(* If reflection successful, try extension *)
			IF Ystar < F[L] THEN
				P2star[.. ] := 3 * Pstar[.. ];  (*cave hidden temp memory allocation*)
				P2star[.. ] := P2star[.. ] - 2 * Pbar[.. ];
				Y2star := Func( P2star );

				(* Retain extension or contraction *)
				IF Y2star < F[L] THEN UpdateSimplex( Y2star, P2star ) ELSE UpdateSimplex( Ystar, Pstar );  END
			ELSE
				I := 0;  Flag := FALSE;
				REPEAT
					IF (I # H) & (F[I] > Ystar) THEN Flag := TRUE END;
					INC( I );
				UNTIL Flag OR (I > M);
				IF Flag THEN UpdateSimplex( Ystar, Pstar )
				ELSE
					(* Contraction on the reflection side of the centroid *)
					IF Ystar <= F[H] THEN UpdateSimplex( Ystar, Pstar ) END;

					(* Contraction on the opposite side of the centroid *)
					P2star[.. ] := P[H, .. ] + Pbar[.. ];
					P2star := 0.5 * P2star;
					Y2star := Func( P2star );
					IF Y2star <= F[H] THEN UpdateSimplex( Y2star, P2star )
							ELSE  (* Contract whole simplex *)
						FOR I := 0 TO M DO
							P[I, .. ] := P[I, .. ] + P[L, .. ];
							P[I, .. ] := 0.5 * P[I, .. ];
						END;
					END;
				END;
			END;

			(* Test convergence *)
			MaxCorr := 0.0;
			FOR J := 0 TO Ubound DO
				Corr := ABS( P[H, J] - P[L, J] );
				IF Corr > MaxCorr THEN MaxCorr := Corr END;
			END;
			INC( Iter );
		UNTIL (MaxCorr < Tol) OR (Iter > MaxIter);

		X := P[L, .. ];  Fmin := F[L];

		IF Iter > MaxIter THEN RETURN NONCONV
		ELSE RETURN OK;
		END;
	END Simplex;

(** ----------------------------------------------------------------------
  Minimizes function Func from point X in the direction specified by
  DeltaX
  ----------------------------------------------------------------------
  Input parameters  : Func    = objective function
                      X       = initial minimum coordinates
                      DeltaX  = direction in which minimum is searched
                      Lbound,
                      Ubound  = indices of first and last variables
                      MaxIter = maximum number of iterations
                      Tol     = required precision
  ----------------------------------------------------------------------
  Output parameters : X     = refined minimum coordinates
                      Fmin = function value at minimum
  ----------------------------------------------------------------------
  Possible results  : OK
                      NONCONV
  ---------------------------------------------------------------------- *)
	PROCEDURE LinMin*( Func: TFuncNVar;  VAR X, DeltaX: Vector;  MaxIter: SIGNED32;  Tol: Real;  VAR Fmin: Real ): SIGNED32;  (*! quite inaccurate*)
	VAR I, ErrCode: SIGNED32;  R: Real;  ofunc:OFunc;
	BEGIN
		(* Initialize function object *)
    	NEW(ofunc,Func,X,DeltaX);
		(* Perform golden search *)
		ErrCode := GoldSearch( ofunc.F1dim,  0.0D0, 1.0D0, MaxIter, Tol, R, Fmin );
		(* Update variables *)
		IF ErrCode = OK THEN X := X + R * DeltaX;  END;

		RETURN ErrCode;
	END LinMin;

	PROCEDURE LinMin2( oFunc: OFunc; VAR X, DeltaX: Vector;  MaxIter: SIGNED32;  Tol: Real;  VAR Fmin: Real ): SIGNED32;
	VAR I, ErrCode: SIGNED32;  R: Real;
	BEGIN
		oFunc.Init(oFunc.Func, X,DeltaX); (*still too much copy overhead ... here*)
		(* Perform golden search *)
		ErrCode := GoldSearch( oFunc.F1dim,  0.0D0, 1.0D0, MaxIter, Tol, R, Fmin );
		IF ErrCode = OK THEN X := X + R * DeltaX;  END;
		(* Update variables *)
		RETURN ErrCode;
	END LinMin2;

(**
 Computes the gradient vector of a function of several variables by numerical differentiation
    Input parameters  :
  	Func    = function of several variables
      X       = vector of variables
      bound  = index of last variable
  Output parameter  :
  	G       = gradient vector
 *)
	PROCEDURE NumGradient*( Func: TFuncNVar;  VAR X: Vector;  VAR G: Vector );
	VAR Temp, Delta, Fplus, Fminus: Real;  I: SIZE;
	BEGIN
		FOR I := 0 TO LEN( X,0 ) - 1 DO
			Temp := X[I];
			IF Temp # 0.0 THEN Delta := Eps * ABS( Temp ) ELSE Delta := Eps END;
			X[I] := Temp - Delta;  Fminus := Func( X );
			X[I] := Temp + Delta;  Fplus := Func( X );
			G[I] := (Fplus - Fminus) / (2.0 * Delta);
			X[I] := Temp;
		END;
	END NumGradient;

(**
  Computes gradient vector & hessian matrix by numerical differentiation
   Input parameters  : as in NumGradient
   Output parameters : G = gradient vector
                      H = hessian matrix
  *)
	PROCEDURE NumHessGrad*( Func: TFuncNVar;  VAR X: Vector;  VAR G: Vector;  VAR H: Matrix );
	VAR Delta, Xminus, Xplus, Fminus, Fplus: Vector;  Temp1, Temp2, F, F2plus: Real;  I, J: SIZE;  Ubound: SIZE;
	BEGIN
		Ubound := LEN( X,0 ) - 1;
		NEW( Delta, Ubound + 1 );   (* Increments   *)
		NEW( Xminus, Ubound + 1 );   (* X - Delta    *)
		NEW( Xplus, Ubound + 1 );   (* X + Delta    *)
		NEW( Fminus, Ubound + 1 );   (* F(X - Delta) *)
		NEW( Fplus, Ubound + 1 );   (* F(X + Delta) *)

		F := Func( X );

		FOR I := 0 TO Ubound DO
			IF X[I] # 0.0 THEN Delta[I] := Eps * ABS( X[I] ) ELSE Delta[I] :=Eps;  END;
		END;

		Xplus := X + Delta;
		Xminus := X - Delta;

		FOR I := 0 TO Ubound DO
			Temp1 := X[I];
			X[I] := Xminus[I];  Fminus[I] := Func( X );
			X[I] := Xplus[I];  Fplus[I] := Func( X );
			X[I] := Temp1;
		END;

		G := (Fplus - Fminus) ./ (2.0 * Delta);
		FOR I := 0 TO Ubound DO
			H[I, I] := (Fplus[I] + Fminus[I] - 2.0 * F) / (Delta[I] * Delta[I]);
		END;

		FOR I := 0 TO (-1 + Ubound) DO
			Temp1 := X[I];  X[I] := Xplus[I];
			FOR J := (1 + I) TO Ubound DO
				Temp2 := X[J];
				X[J] := Xplus[J];
				F2plus := Func( X );
				H[I, J] := (F2plus - Fplus[I] - Fplus[J] + F) / (Delta[I] * Delta[J]);
				H[J, I] := H[I, J];
				X[J] := Temp2;
			END;
			X[I] := Temp1;
		END;

	END NumHessGrad;

	PROCEDURE ParamConv( CONST OldX, X: Vector;  Tol: Real ): BOOLEAN;
	(*   Check for convergence on parameters *)
	VAR I: SIZE;  Conv: BOOLEAN;  Ubound: SIZE;
	BEGIN
		Ubound := LEN( X,0 ) - 1;  I := 0;  Conv := TRUE;
		REPEAT Conv := Conv & (ABS( X[I] - OldX[I] ) < Max( Tol, Tol * ABS( OldX[I] ) ));  INC( I );  UNTIL (Conv = FALSE ) OR (I > Ubound);
		RETURN Conv;
	END ParamConv;


(** ----------------------------------------------------------------------
  Minimization of a function of several variables by Marquardt's method
  ----------------------------------------------------------------------
  Input parameters  : Func     = objective function
                      HessGrad = PROCEDURE to compute gradient & hessian
                      X        = initial minimum coordinates
                      MaxIter  = maximum number of iterations
                      Tol      = required precision
  ----------------------------------------------------------------------
  Output parameters : X     = refined minimum coordinates
                      Fmin = function value at minimum
                      Hinv = inverse hessian matrix
  ----------------------------------------------------------------------
  Possible results  : OK
                      SING
                      BIGLAMBDA
                      NONCONV
  ---------------------------------------------------------------------- *) (* to do: eliminate redundant object createin in LinMin called from Marquardt *)
	PROCEDURE Marquardt*( Func: TFuncNVar;  HessGrad: THessGrad;  VAR X: Vector;  MaxIter: SIGNED32;  Tol: Real;  VAR Fmin: Real;
											    VAR Hinv: Matrix ): SIGNED32;
	CONST LAMBDA0 = 1.0E-2;   (* Initial lambda value *)
		LAMBDAMAX = 1.0E+3;   (* Highest lambda value *)
		FTOL = 1.0E-10;   (* Tolerance on function decrease *)
	VAR Lambda,
		Lambda1: Real;   (* Marquardt's lambda *)
		I: SIZE;   (* Loop variable *)
		OldX: Vector;   (* Old parameters *)
		G: Vector;   (* Gradient vector *)
		H: Matrix;   (* Hessian matrix *)
		A: Matrix;   (* Modified Hessian matrix *)
		DeltaX: Vector;   (* New search direction *)
		F1: Real;   (* New minimum *)
		LambdaOk: BOOLEAN;   (* Successful Lambda decrease *)
		Conv: BOOLEAN;   (* Convergence reached *)
		Done: BOOLEAN;   (* Iterations DOne *)
		Iter: SIGNED32;   (* Iteration count *)
		ErrCode: SIGNED32;   (* Error code *)
		Ubound: SIGNED32;
		ofunc:OFunc;
		GaussJordan: MatrixStandardSolvers.GaussJordan;

(*
		PROCEDURE f1dim*(r:Real):Real;
		VAR f:Real;
			BEGIN
				RETURN Func(X+ r * DeltaX);
			END f1dim;

		PROCEDURE linMin*( MaxIter: SIGNED32;  Tol: Real;  VAR Fmin: Real ): SIGNED32;
		VAR I, ErrCode: SIGNED32;  R: Real;
		BEGIN
			(* Perform golden search *)
			ErrCode := GoldSearch( f1dim,  0.0D0, 1.0D0, MaxIter, Tol, R, Fmin );
			(* Update variables *)
			IF ErrCode = OK THEN X := X + R * DeltaX;  END;
			RETURN ErrCode;
		END linMin;
*)
	BEGIN
		ErrCode := -99;
		Lambda := LAMBDA0;  ErrCode := OK;

		NEW(GaussJordan, A);

		NEW( OldX, LEN(X,0) );  NEW( G, LEN(X,0) );  NEW( H, LEN(X,0), LEN(X,0) );  NEW( A, LEN(X,0)-1, LEN(X,0) );
		NEW( DeltaX, LEN(X,0) );
		Fmin := Func( X );   (* Initial function value *)
		NEW(ofunc,Func,X,DeltaX);

		Iter := 1;  Conv := FALSE;  Done := FALSE;


		REPEAT

			(* Save current parameters *)
			OldX := X;

			(* Compute Gradient & Hessian *)
			HessGrad( Func, X, G, H );
			A := H;

			(* Change sign of gradient *)
			G := -G;

			IF Conv THEN  (* Newton-Raphson iteration *)
				(*!ErrCode := MatrixSolvers.GaussJordan( A, G, Hinv, DeltaX );  *)
				GaussJordan.Init(A);
				DeltaX:=GaussJordan.Solve(G);
				ErrCode := GaussJordan.res;

				IF ErrCode = OK THEN
					X := OldX + DeltaX
				END;
				Done := TRUE;
			ELSE  (* Marquardt iteration *)
				REPEAT
					(* Multiply each diagonal term of H by (1 + Lambda) *)
					Lambda1 := 1.0 + Lambda;
					FOR I := 0 TO LEN(X,0) - 1 DO A[I, I] := Lambda1 * H[I, I] END;

					(*!ErrCode := MatrixSolvers.GaussJordan( A, G, Hinv, DeltaX );  *)
					GaussJordan.Init(A);
					DeltaX:=GaussJordan.Solve(G);
					ErrCode := GaussJordan.res;

					IF ErrCode = OK THEN
					(* Initialize parameters *)
						X := OldX;

						(* Minimize in the direction specified by DeltaX *)
						(*ErrCode := LinMin( Func, X, DeltaX, 100, 0.01 * 1.0D0, F1 ); *) (*object creation overhead ...*)
						ErrCode := LinMin2( ofunc, X, DeltaX, 100, 0.01 * 1.0D0, F1 );
						(*ErrCode := linMin( 100, 0.01 * 1.0D0, F1 );*) (*desirable no-overhead solution but runtime trap*)

						(* Check that the function has decreased. Otherwise
                  increase Lambda, without exceeding LAMBDAMAX *)
						LambdaOk := (F1 - Fmin) < Fmin * FTOL;
						IF ~LambdaOk THEN Lambda := 10.0 * Lambda END;
						IF Lambda > LAMBDAMAX THEN ErrCode := BIGLAMBDA END;
					END;
				UNTIL LambdaOk OR (ErrCode # OK);

				(* Check FOR convergence *)
				Conv := ParamConv( OldX, X, Tol );

				(* Prepare next iteration *)
				Lambda := 0.1 * Lambda;  Fmin := F1;
			END;

			INC( Iter );
			IF Iter > MaxIter THEN ErrCode := NONCONV END;
		UNTIL Done OR (ErrCode # OK);

		(*! 2011*) Hinv:=GaussJordan.Ainv;
		RETURN ErrCode;
	END Marquardt;


(** ----------------------------------------------------------------------
  Minimization of a function of several variables by the
  Broyden-Fletcher-Goldfarb-Shanno method
  ----------------------------------------------------------------------
  Parameters : Gradient = PROCEDURE to compute gradient vector
               Other parameters as in Marquardt
  ----------------------------------------------------------------------
  Possible results : OK
                     NONCONV
  ---------------------------------------------------------------------- *)
	PROCEDURE BFGS*( Func: TFuncNVar;  Gradient: TGradient;  VAR X: Vector;  MaxIter: SIGNED32;  Tol: Real;  VAR Fmin: Real;
									  VAR Hinv: Matrix ): SIGNED32;
	VAR I: SIZE; J, Iter, ErrCode: SIGNED32;  DeltaXmax, Gmax, P1, P2, R1, R2: Real;
		OldX, DeltaX, dX, G, OldG, dG, HdG, R1dX, R2HdG, U, P2U: Vector;  Conv: BOOLEAN;  one: Real;
		(*ofunc:OFunc;*)
	BEGIN
		one := 1;

		NEW( OldX, LEN( X,0 ) );  NEW( DeltaX, LEN( X,0 ) );  NEW( dX, LEN( X,0 ) );  NEW( G, LEN( X,0 ) );  NEW( OldG, LEN( X,0 ) );
		NEW( dG, LEN( X,0 ) );  NEW( HdG, LEN( X,0 ) );  NEW( R1dX, LEN( X,0 ) );  NEW( R2HdG, LEN( X,0 ) );  NEW( U, LEN( X,0 ) );
		NEW( P2U, LEN( X,0 ) );
		(*NEW(ofunc,Func,X,DeltaX);*)

		Iter := 0;  Conv := FALSE;

		(* Initialize function *)
		Fmin := Func( X );

		(* Initialize inverse hessian to unit matrix *)
		Hinv:=0;
		FOR I := 0 TO LEN( X,0 ) - 1 DO Hinv[I, I] := 1.0; END;

		(* Initialize gradient *)
		Gradient( Func, X, G );
		Gmax := MaxAbsV( G );

		(* Initialize search direction *)
		IF Gmax > MatrixBase.EPS THEN
				DeltaX := -G;
		ELSE Conv := TRUE;   (* Quit IF gradient is already small *)
		END;

		WHILE (~Conv) & (Iter < MaxIter) DO

			(* Normalize search direction TO avoid excessive displacements *)
			DeltaXmax := MaxAbsV( DeltaX );
			IF DeltaXmax > 1.0 THEN DeltaX := DeltaX / DeltaXmax;  END;

			(* Save old parameters & gradient *)
			OldX := X;  OldG := G;

			(* Minimize along the direction specified by DeltaX *)
			ErrCode := LinMin( Func, X, DeltaX, 100, 0.01 * one, Fmin );
			(*ofunc.Init(Func,X,DeltaX);	ErrCode := LinMin( ofunc.F1dim, X, DeltaX, 100, 0.01 * 1.0D0, Fmin );*)

			(* Compute new gradient *)
			Gradient( Func, X, G );

			(* Compute differences between two successive estimations of parameter vector & gradient vector *)
			dX := X - OldX;  dG := G - OldG;

			(* Multiply by inverse hessian *)
			HdG := Hinv * dG;

			(* Scalar products in denominator of BFGS formula *)
			P1 := dX +* dG;  P2 := dG +* HdG;

			IF (P1 = 0.0) OR (P2 = 0.0) THEN Conv := TRUE
			ELSE
				(* Inverses of scalar products *)
				R1 := 1.0 / P1;  R2 := 1.0 / P2;

				(* Compute BFGS correction terms *)
				R1dX := R1 * dX;  R2HdG := R2 * HdG;  U := R1dX - R2HdG;  P2U := P2 * U;

				(* Update inverse hessian *)
				Hinv := Hinv + R1dX ** dX; (*do it stepwise to avoid temp memory allocation*)
				Hinv := Hinv - R2HdG ** HdG;
				Hinv := Hinv + P2U ** U;

				(* Update search direction *)
				DeltaX := Hinv * G;

				(* Test convergence & update iteration count *)
				Conv := ParamConv( OldX, X, Tol );  INC( Iter );
			END;
		END;

		IF Iter > MaxIter THEN RETURN NONCONV
		ELSE RETURN OK;
		END;
	END BFGS;

	PROCEDURE power( base, exponent: Real ): Real;
	BEGIN
		IF ABS( base ) < Eps THEN RETURN 0 ELSE RETURN MathL.exp( exponent * MathL.ln( base ) );  END;
	END power;

	PROCEDURE MaxAbsV( CONST m: Vector ): Real;  (*to do: more generic approach*)
	BEGIN
		RETURN MAX(MAX(m),-MIN(m)) ; (*non-copying ABS(MAX(m))*)
	END MaxAbsV;


BEGIN
	Eps := power( MatrixBase.EPS, 0.333D0 );
END MatrixOptim.


fofPC.Compile \s *
pc=234
MatrixBase.EPS
