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
	VAR Tolerance*: Datatype;   (* tolerance of solution accuracy *)
		nMaxIterations*, nIterations-: SIGNED32;   (* maximum number of iterations and number of done iterations *)
		SysMatrix: Matrix;   (* copy of system matrix *)
		Tracer*: Streams.Writer;
		Tiny: Datatype;

		resid0, resid, p, q, u, v: Vector;

		PROCEDURE & Init*( CONST A: Matrix );
		BEGIN
			handleError := MatrixBase.HandleError;  res := MatrixBase.OK;

			(* parameters by default *)
			Tolerance := 1.0 / 1000000.0;   (* tolerance of solution residual *)
			nMaxIterations := 30;   (* maximum number of iterations *)

			Tiny := 10.0 * MatrixBase.EPS;

			IF LEN( A ) = 0 THEN RETURN;
			END;
			IF LEN( A, 0 ) # LEN( A, 1 ) THEN
				res := MatrixBase.NOTSQUARE;  handleError( res, 'KrylovCGS: matrix is not square!' );  RETURN;
			END;

			SysMatrix := A;

			(* allocate arrays for further needs *)
			NEW( resid0, LEN( A,0 ) );  NEW( resid, LEN( A,0 ) );  NEW( u, LEN( A,0 ) );
			NEW( v, LEN( A,0 ) );  NEW( p, LEN( A,0 ) );  NEW( q, LEN( A,0 ) );

			(* initial guess/solution *)
			NEW( x, LEN( A,0 ) );
		END Init;

		PROCEDURE Solve*( CONST b: Vector ): Vector;
		BEGIN
			IF LEN( b, 0 ) # LEN( SysMatrix, 0 ) THEN
				res := MatrixBase.SIZEMISMATCH;  handleError( res, 'KrylovCGS: matrix-vector size missmatch!' );  RETURN x;
			END;

			(* solve system *)
			RETURN CGS( SysMatrix, b, x, Tolerance, nMaxIterations );
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

			(* if necessary reallocate all arrays *)
			IF LEN( b, 0 ) > LEN( x, 0 ) THEN
				NEW( x, LEN( b, 0 ) );
			END;
			IF LEN( b, 0 ) > LEN( resid0, 0 ) THEN
				NEW( resid0, LEN( b, 0 ) );  NEW( resid, LEN( b, 0 ) );  NEW( u, LEN( b, 0 ) );  NEW( v, LEN( b, 0 ) );
				NEW( p, LEN( b, 0 ) );  NEW( q, LEN( b, 0 ) );
			END;

			(* solve system *)
			RETURN CGS( A, b, x, Tolerance, nMaxIterations );
		END SolveNoCopy;

		PROCEDURE SolveProcBased*( MatrixToVector: MatrixToVectorProc;CONST b: Vector ): Vector;
		BEGIN
			IF MatrixToVector = NIL THEN
				res := MatrixBase.NILPROC;  handleError( res, 'KrylovCGS: invalid Matrix to Vector procedure pointer!' );  RETURN x;
			END;
			(* if necessary - reallocate all arrays *)
			IF LEN( b, 0 ) > LEN( x, 0 ) THEN
				NEW( x, LEN( b, 0 ) );
				x := 0;   (* implicit in NEW  *)
			END;
			IF LEN( b, 0 ) > LEN( resid0, 0 ) THEN
				NEW( resid0, LEN( b,0 ) );  NEW( resid, LEN( b,0 ) );
				NEW( u, LEN( b,0 ) );  NEW( v, LEN( b,0 ) );
				NEW( p, LEN( b,0 ) );  NEW( q, LEN( b,0 ) );
			END;
			(* solve system *)
			RETURN CGSProcBased( MatrixToVector, b, x, Tolerance, nMaxIterations );
		END SolveProcBased;

		PROCEDURE CGS( CONST A: Matrix;  CONST b: Vector;
					   VAR x: Vector;  Tolerance: Datatype;
					   nMaxIterations: SIGNED32 ): Vector;
		VAR alpha, beta, rho, rho_1, residnrm: Datatype;
		BEGIN
			resid0 := A * x;  resid0 := b - resid0;  resid := resid0;  beta := 0;
			residnrm := 1.0;
			nIterations := 0;
			WHILE (nIterations < nMaxIterations) & (residnrm > Tolerance) DO
				rho_1 := rho;  rho := resid0 +* resid;
				IF ABS( rho ) <= Tiny THEN
					IF Tracer # NIL THEN
						Tracer.String( 'Premature exit due to very small rho value!' );  Tracer.Ln;  Tracer.Update();  RETURN x;
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
				residnrm := Math.sqrt( resid +* resid );
				IF Tracer # NIL THEN
					Tracer.String( 'iteration ' );  Tracer.Int( nIterations, 0 );
					Tracer.String( ':' );  Tracer.String( ' res norm = ' );
					Tracer.FloatFix( residnrm, 16, 16, 0 );  Tracer.Ln;
					Tracer.Update();
				END;
				INC( nIterations );
			END;
			RETURN x;
		END CGS;

		PROCEDURE CGSProcBased( MatrixToVector: MatrixToVectorProc;
								CONST b: Vector;
								VAR x: Vector;  Tolerance: Datatype;
								nMaxIterations: SIGNED32 ): Vector;
		VAR
		VAR alpha, beta, rho, rho_1, residnrm: Datatype;
		BEGIN
			MatrixToVector( x, resid0 );  resid0 := b - resid0;  resid := resid0;
			beta := 0;  residnrm := 1.0;

			nIterations := 0;
			WHILE (nIterations < nMaxIterations) & (residnrm > Tolerance) DO
				rho_1 := rho;  rho := resid0 +* resid;

				IF ABS( rho ) <= Tiny THEN
					IF Tracer # NIL THEN
						Tracer.String( 'Premature exit due to very small rho value!' );  Tracer.Ln;  Tracer.Update();  RETURN x;
					END;
				END;

				IF nIterations > 0 THEN
					beta := rho / rho_1;  u := resid + beta * q;
					p := u + beta * (q + beta * p);
				ELSE u := resid;  p := u;
				END;

				MatrixToVector( p, q );  alpha := rho / (resid0 +* q);
				q := u - alpha * q;
				u := u + q;  x := x + alpha * u;
				MatrixToVector( u, v );
				resid := resid - alpha * v;
				residnrm := Math.sqrt( resid +* resid );
				IF Tracer # NIL THEN
					Tracer.String( 'iteration ' );  Tracer.Int( nIterations, 0 );
					Tracer.String( ':' );  Tracer.String( ' res norm = ' );
					Tracer.FloatFix( residnrm, 16, 16, 0 );  Tracer.Ln;
					Tracer.Update();
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
	CONST TestThreshold = 1.0 / 1000000.0;
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

		NEW(s, A); s.Tracer := log;

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