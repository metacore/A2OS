MODULE TestMatrixOptim;

IMPORT Optim := MatrixOptim, Out:=KernelLog, Strings;

TYPE
	Float = FLOAT64;
	Matrix = Optim.Matrix;
	Vector = Optim.Vector;
	TFuncNVar = Optim.TFuncNVar;

	PROCEDURE f( X: Float ): Float;
	BEGIN
		RETURN (X - 0.5) * (X - 0.5) + 0.4
	END f;

	PROCEDURE fn( CONST X: Vector ): Float;
	BEGIN
		RETURN (X[0] - 0.3) * (X[0] - 0.3) + (X[1] - 0.4) * (X[1] - 0.4) + 0.5
	END fn;

	PROCEDURE OutFix( x: FLOAT64;  m, n: SIGNED16 );
	VAR str: ARRAY 32 OF CHAR;
	BEGIN
		Strings.FloatToStr(x, m, n, 0, str);
		Out.String(str);
	END OutFix;

	PROCEDURE Do*;
	VAR A, B, Tol, Xmin, Ymin: Float;  MaxIter, Res, time, i: SIGNED32;  X0, Dir, G: Vector;  Hinv: Matrix;
	BEGIN
		Out.Ln;  Out.String( "----- Test of different optimization algorithms ------ " );  Out.Ln;  A := -10;  B := 10;  MaxIter := 50;  Tol := 0.0001;
		Res := Optim.GoldSearch( f, A, B, MaxIter, Tol, Xmin, Ymin );  Out.String( "Golden Search:" );  Out.Ln;  Out.String( "Res, expected Xmin,Ymin: " );  Out.Int( Res, 6 );
		OutFix( 0.5, 5, 2 );  OutFix( 0.4, 5, 2 );  Out.Ln;  Out.String( "calculated Xmin, Ymin: " );  OutFix( Xmin, 10, 4 );
		OutFix( Ymin, 10, 4 );  Out.Ln;  Out.Ln;

		Out.String( "   --- N-dimensional function minimization, examples in 2D ---- " );  Out.Ln;  Out.Ln;

		Out.String( "Linear Minimization: " );  Out.Ln;  NEW( X0, 2 );  NEW( Dir, 2 );  (*time := Input.Time();  *)
		FOR i := 1 TO 1000 DO
			X0[0] := 10;  X0[1] := 10;  Dir[0] := -1;  Dir[1] := -1;  Res := Optim.LinMin( fn, X0, Dir, MaxIter, Tol, Ymin );
		END;
		Out.String( "Time [ms] for 1000 iterations: " );  (*Out.Int( Input.Time() - time, 6 );*)  Out.Ln;  Out.String( "Res, expected Ymin, minimum coordinates  " );  Out.Int( Res, 6 );  OutFix( 0.5, 5, 2 );
		OutFix( 0.3, 5, 2 );  OutFix( 0.4, 5, 2 );  Out.Ln;  Out.String( "calculated Ymin, min coordinates " );  OutFix( Ymin, 10, 4 );
		OutFix( X0[0], 10, 4 );  OutFix( X0[1], 10, 4 );  Out.Ln;  Out.Ln;

		Out.String( "Simplex: " );  Out.Ln;  NEW( X0, 2 );  (*time := Input.Time();  *)
		FOR i := 1 TO 1000 DO X0[0] := 10;  X0[1] := 10;  Res := Optim.Simplex( fn, X0, MaxIter, Tol, Ymin );  END;
		Out.String( "Time [ms] for 1000 iterations: " );  (*Out.Int( Input.Time() - time, 6 ); *) Out.Ln;  Out.String( "Res, expected Ymin, minimum coordinates  " );  Out.Int( Res, 6 );  OutFix( 0.5, 5, 2 );
		OutFix( 0.3, 5, 2 );  OutFix( 0.4, 5, 2 );  Out.Ln;  Out.String( "calculated Ymin, min coordinates " );  OutFix( Ymin, 10, 4 );
		OutFix( X0[0], 10, 4 );  OutFix( X0[1], 10, 4 );  Out.Ln;  Out.Ln;

		Out.String( "Marquardt:" );  Out.Ln;
		NEW( X0, 2 );  NEW( Hinv, 2, 2 ); (* time := Input.Time();  *)
		FOR i := 1 TO 1000 DO
			X0[0] := 10;  X0[1] := 10;  Res := Optim.Marquardt( fn, Optim.NumHessGrad, X0, MaxIter, Tol, Ymin, Hinv );
		END;
		Out.String( "Time [ms] for 1000 iterations: " );  (*Out.Int( Input.Time() - time, 6 ); *) Out.Ln;  Out.String( "Res, expected Ymin, minimum coordinates: " );  Out.Int( Res, 6 );  OutFix( 0.5, 5, 2 );
		OutFix( 0.3, 5, 2 );  OutFix( 0.4, 5, 2 );  Out.Ln;  Out.String( "calculated Ymin, min coordinates " );  OutFix( Ymin, 10, 4 );
		OutFix( X0[0], 10, 4 );  OutFix( X0[1], 10, 4 );  Out.Ln;  Out.String( "inverted Hessian Matrix: " );  Out.Ln;  OutFix( Hinv[0, 0], 10, 4 );
		OutFix( Hinv[0, 1], 10, 4 );  Out.Ln;  OutFix( Hinv[1, 0], 10, 4 );  OutFix( Hinv[1, 1], 10, 4 );  Out.Ln;  Out.Ln;

		Out.String( "BFGS:" );  Out.Ln;  NEW( X0, 2 );  NEW( Hinv, 2, 2 );  (*time := Input.Time();  *)
		FOR i := 1 TO 1000 DO
			X0[0] := 10;  X0[1] := 10;  Res := Optim.BFGS( fn, Optim.NumGradient, X0, MaxIter, Tol, Ymin, Hinv );
		END;
		Out.String( "Time [ms] for 1000 iterations: " );  (*Out.Int( Input.Time() - time, 6 ); *) Out.Ln;  Out.String( "Res, expected Ymin, minimum coordinates: " );  Out.Int( Res, 6 );  OutFix( 0.5, 5, 2 );
		OutFix( 0.3, 5, 2 );  OutFix( 0.4, 5, 2 );  Out.Ln;  Out.String( "calculated Ymin, min coordinates " );  OutFix( Ymin, 10, 4 );
		OutFix( X0[0], 10, 4 );  OutFix( X0[1], 10, 4 );  Out.Ln;  Out.String( "inverted Hessian Matrix: " );  Out.Ln;  OutFix( Hinv[0, 0], 10, 4 );
		OutFix( Hinv[0, 1], 10, 4 );  Out.Ln;  OutFix( Hinv[1, 0], 10, 4 );  OutFix( Hinv[1, 1], 10, 4 );  Out.Ln;  Out.Ln;

	END Do;


	PROCEDURE {TEST} Test*;
	CONST TestTolerance=0.001; LargeTolerance=0.1;
	VAR A, B, Tol, Xmin, Ymin: Float;  MaxIter, Res, time, i: SIGNED32;  X0, Dir, G: Vector;  Hinv: Matrix;
	BEGIN
		A := -10;  B := 10;  MaxIter := 50;  Tol := 0.0001;
		Res := Optim.GoldSearch( f, A, B, MaxIter, Tol, Xmin, Ymin );  
		ASSERT((ABS(Xmin-0.5)<TestTolerance) & (ABS(Ymin-0.4)<TestTolerance), 201);

		NEW( X0, 2 );  NEW( Dir, 2 );  X0[0] := 10;  X0[1] := 10;  Dir[0] := -1;  Dir[1] := -1;  
		Res := Optim.LinMin( fn, X0, Dir, MaxIter, Tol, Ymin );
		ASSERT((ABS(Ymin-0.5)<LargeTolerance) & (ABS(X0[0]-0.3)<LargeTolerance) & (ABS(X0[1]-0.4)<LargeTolerance), 202); (*! Quite inaccurate result ! *)

		NEW( X0, 2 ); X0[0] := 10;  X0[1] := 10;  
		Res := Optim.Simplex( fn, X0, MaxIter, Tol, Ymin );
		ASSERT((ABS(Ymin-0.5)<TestTolerance) & (ABS(X0[0]-0.3)<TestTolerance) & (ABS(X0[1]-0.4)<TestTolerance), 203);
		
		NEW( X0, 2 );  NEW( Hinv, 2, 2 ); X0[0] := 10;  X0[1] := 10;  
		Res := Optim.Marquardt( fn, Optim.NumHessGrad, X0, MaxIter, Tol, Ymin, Hinv );
		ASSERT((ABS(Ymin-0.5)<TestTolerance) & (ABS(X0[0]-0.3)<TestTolerance) & (ABS(X0[1]-0.4)<TestTolerance), 204);


		NEW( X0, 2 );  NEW( Hinv, 2, 2 ); X0[0] := 10;  X0[1] := 10;  
		Res := Optim.BFGS( fn, Optim.NumGradient, X0, MaxIter, Tol, Ymin, Hinv );
		ASSERT((ABS(Ymin-0.5)<TestTolerance) & (ABS(X0[0]-0.3)<TestTolerance) & (ABS(X0[1]-0.4)<TestTolerance), 205);
	END Test;

END TestMatrixOptim.

System.Free  TestMatrixOptim MatrixOptim~
TestMatrixOptim.Do

fofPC.Compile \s *
fofPC.Compile \f *
OFormatter.Format *