(**
	DESCRIPTION:
		Conjugate Gradient Squared solver of linear systems of equations

	AUTHOR:
		Alexey Morozov
**)
MODULE KrylovCGS;

IMPORT MatrixBase, Math := MathL, Streams, KernelLog;

TYPE
	Datatype = MatrixBase.Datatype;
	Vector = MatrixBase.Vector;
	Matrix = MatrixBase.Matrix;

	MatrixToVectorProc* = PROCEDURE {DELEGATE} ( CONST X: Vector; VAR Y: Vector );

	Solver* = OBJECT (MatrixBase.Solver)
	VAR
		tolerance*: Datatype;   (* tolerance of solution accuracy *)
		nMaxIterations*, nIterations-: SIZE;   (* maximum number of iterations and number of done iterations *)
		tracer*: Streams.Writer;

		sysMatrix: Matrix;   (* copy of system matrix *)
		tiny: Datatype;

		resid0, resid, p, q, u, v: Vector;

		PROCEDURE & Init*( CONST A: Matrix );
		BEGIN
			handleError := MatrixBase.HandleError;  res := MatrixBase.OK;

			(* parameters by default *)
			tolerance := 1 / 1000000;   (* tolerance of solution residual *)
			nMaxIterations := 30;   (* maximum number of iterations *)

			tiny := 10 * MatrixBase.EPS;

			IF LEN( A ) = 0 THEN RETURN;
			END;
			IF LEN( A, 0 ) # LEN( A, 1 ) THEN
				res := MatrixBase.NOTSQUARE;  handleError( res, 'KrylovCGS: matrix is not square!' );  RETURN;
			END;

			sysMatrix := A;

			ReallocateIfNecessary(LEN( A, 0 ));
		END Init;

		PROCEDURE ReallocateIfNecessary(problemSize: SIZE);
		BEGIN
			(* allocate arrays for further needs *)
			IF LEN( resid0, 0 ) # problemSize THEN
				NEW( resid0, problemSize );  NEW( resid, problemSize );  NEW( u, problemSize );
				NEW( v, problemSize );  NEW( p, problemSize );  NEW( q, problemSize );
			END;
			(* initial guess/solution *)
			IF LEN( x, 0 ) # problemSize THEN
				NEW( x, problemSize );
			END;
		END ReallocateIfNecessary;

		PROCEDURE Solve*( CONST b: Vector ): Vector;
		BEGIN
			IF LEN( b, 0 ) # LEN( sysMatrix, 0 ) THEN
				res := MatrixBase.SIZEMISMATCH;  handleError( res, 'KrylovCGS: matrix-vector size missmatch!' );  RETURN x;
			END;

			RETURN CGS( sysMatrix, b, x, tolerance, nMaxIterations );
		END Solve;

		PROCEDURE SolveNoCopy*( VAR A: Matrix;CONST b: Vector ): Vector;
		BEGIN
			IF LEN( A ) = 0 THEN RETURN x;  END;
			IF LEN( A, 0 ) # LEN( A, 1 ) THEN
				res := MatrixBase.NOTSQUARE;  handleError( res, 'KrylovCGS: matrix is not square!' );  RETURN x;
			END;
			IF LEN( b, 0 ) # LEN( A, 0 ) THEN
				res := MatrixBase.SIZEMISMATCH;  handleError( res, 'KrylovCGS: matrix-vector size missmatch!' );  RETURN x;
			END;

			ReallocateIfNecessary(LEN( b, 0 ));

			RETURN CGS( A, b, x, tolerance, nMaxIterations );
		END SolveNoCopy;

		PROCEDURE SolveProcBased*( matrixToVector: MatrixToVectorProc;CONST b: Vector ): Vector;
		BEGIN
			IF matrixToVector = NIL THEN
				res := MatrixBase.NILPROC;  handleError( res, 'KrylovCGS: invalid Matrix to Vector procedure pointer!' );  RETURN x;
			END;

			ReallocateIfNecessary(LEN( b, 0 ));

			RETURN CGSProcBased( matrixToVector, b, x, tolerance, nMaxIterations );
		END SolveProcBased;

		PROCEDURE CGS(
								CONST A: Matrix;
								CONST b: Vector;
								VAR x: Vector;
								tolerance: Datatype;
								nMaxIterations: SIZE
								): Vector;
		VAR alpha, beta, rho, rho_1, residnrm: Datatype;
		BEGIN
			resid0 := A * x;  resid0 := b - resid0;  resid := resid0;  beta := 0;
			residnrm := 1.0;
			nIterations := 0;
			WHILE (nIterations < nMaxIterations) & (residnrm > tolerance) DO
				rho_1 := rho;  rho := resid0 +* resid;
				IF ABS( rho ) <= tiny THEN
					IF tracer # NIL THEN
						tracer.String( 'Premature exit due to very small rho value!' );  tracer.Ln;  tracer.Update();  RETURN x;
					END;
				END;
				IF nIterations > 0 THEN
					beta := rho / rho_1;  u := resid + beta * q;
					p := u + beta * (q + beta * p);
				ELSE u := resid;  p := u;
				END;
				q := A * p;  alpha := rho / (resid0 +* q);  q := u - alpha * q;
				u := u + q;  x := x + alpha * u;
				v := A * u;
				resid := resid - alpha * v;
				residnrm := Datatype(Math.sqrt( resid +* resid ));
				IF tracer # NIL THEN
					tracer.String( 'iteration ' );  tracer.Int( nIterations, 0 );
					tracer.String( ':' );  tracer.String( ' res norm = ' );
					tracer.FloatFix( residnrm, 16, 16, 0 );  tracer.Ln;
					tracer.Update();
				END;
				INC( nIterations );
			END;
			RETURN x;
		END CGS;

		PROCEDURE CGSProcBased(
											matrixToVector: MatrixToVectorProc;
											CONST b: Vector;
											VAR x: Vector;  tolerance: Datatype;
											nMaxIterations: SIZE
											): Vector;
		VAR alpha, beta, rho, rho_1, residnrm: Datatype;
		BEGIN
			matrixToVector( x, resid0 );  resid0 := b - resid0;  resid := resid0;
			beta := 0;  residnrm := 1;

			nIterations := 0;
			WHILE (nIterations < nMaxIterations) & (residnrm > tolerance) DO
				rho_1 := rho;  rho := resid0 +* resid;

				IF ABS( rho ) <= tiny THEN
					IF tracer # NIL THEN
						tracer.String( 'Premature exit due to very small rho value!' );  tracer.Ln;  tracer.Update();  RETURN x;
					END;
				END;

				IF nIterations > 0 THEN
					beta := rho / rho_1;  u := resid + beta * q;
					p := u + beta * (q + beta * p);
				ELSE u := resid;  p := u;
				END;

				matrixToVector( p, q );  alpha := rho / (resid0 +* q);
				q := u - alpha * q;
				u := u + q;  x := x + alpha * u;
				matrixToVector( u, v );
				resid := resid - alpha * v;
				residnrm := Datatype(Math.sqrt( resid +* resid ));
				IF tracer # NIL THEN
					tracer.String( 'iteration ' );  tracer.Int( nIterations, 0 );
					tracer.String( ':' );  tracer.String( ' res norm = ' );
					tracer.FloatFix( residnrm, 16, 16, 0 );  tracer.Ln;
					tracer.Update();
				END;
				INC( nIterations );
			END;

			RETURN x;
		END CGSProcBased;

	END Solver;

	PROCEDURE CreateSolver*( ): MatrixBase.Solver;   (*FactoryProcedure*)
	VAR cgs: Solver; dummy:Matrix;
	BEGIN
		NEW(cgs,dummy); RETURN cgs;
	END CreateSolver;

	PROCEDURE Solve*( VAR A: Matrix;  CONST b: Vector ): Vector;   (*direct procedural solving; simplest use, but when using repeatedly, running into internal allocation overhead *)
	VAR cgs:Solver; dummy:Matrix;
	BEGIN
		NEW(cgs,dummy); RETURN cgs.SolveNoCopy(A,b);
	END Solve;

	PROCEDURE {TEST} Test*;
	CONST TestThreshold = 1 / 1000000;
	VAR
		s: Solver; A: Matrix;  b, x1, x2, e: Vector;  error:Datatype; log: Streams.Writer;
		procObj: ProcObj;
	TYPE
		ProcObj = OBJECT
		VAR A: Matrix;

			PROCEDURE &Init(CONST mtx: Matrix);
			BEGIN
				A := mtx;
			END Init;

			PROCEDURE Proc(CONST x: Vector; VAR y: Vector);
			BEGIN
				y := A * x;
			END Proc;
		END ProcObj;

	BEGIN
		A := [[5, -1, -2, -3], [-1, 5, 4, 2], [-2, 4, 5, 1], [-3, 2, 1, 5]];   (* symmetric, positive definite matrix *)
		b := [1, 2, 3, 4];

		Streams.OpenWriter(log, KernelLog.Send);

		NEW(s, A); s.tracer := log;

		x1 := s.Solve(b);
		e := A*x1-b; error:= (e+*e) / (b+*b);
		ASSERT(error < TestThreshold, 201);

		s.x := 0;
		x2 := s.SolveNoCopy( A, b );
		e := A*x2-b; error:= (e+*e) / (b+*b);
		ASSERT(x2 = x1, 201);

		s.x := 0;
		NEW(procObj, A);
		x2 := s.SolveProcBased( procObj.Proc, b );
		e := A*x2-b; error:= (e+*e) / (b+*b);
		ASSERT(x2 = x1, 201);

		x2 := Solve( A, b );
		e := A*x2-b; error:= (e+*e) / (b+*b);
		ASSERT(x2 = x1, 201);
	END Test;

END KrylovCGS.

System.FreeDownTo KrylovCGS ~