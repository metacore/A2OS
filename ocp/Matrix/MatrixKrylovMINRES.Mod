(**
	DESCRIPTION:
		Minimum Residual solver of linear systems of equations

	AUTHOR:
		Alexey Morozov


	MINRES is attractive when the system matrix is symmetric and indefinite.
	In the symmetric positive definite case CG is the preferred method.
	The usage of 3 term recurrence relations (within Lanczos recurrence)
	makes MINRES very vulnerable for rounding errors. It has been shown in
	literature that rounding errors are propogated to the approximate solution
	with a factor proportional to the square of the condition number of the matrix,
	whereas in GMRES these errors depend only on the condition number itself.
	Therefore one should be careful with MINRES for ill-conditioned systems.
	If storage is not a problem then GMRES should be preferred for ill-conditioned
	systems; if it is a problem then one might consider usage of SYMMLQ. SYMMLQ,
	however may converge a good deal slower than MINRES for ill-conditioned systems.



**)
MODULE KrylovMINRES;

IMPORT MatrixBase, Math := MathL, Streams, KernelLog;

TYPE
	Datatype = MatrixBase.Datatype;
	Matrix= MatrixBase.Matrix;
	Vector= MatrixBase.Vector;

	MatrixToVectorProc* = PROCEDURE {DELEGATE} ( CONST X: Vector; VAR Y: Vector);

	Solver* = OBJECT (MatrixBase.Solver)
	VAR
		tolerance*: Datatype;   (* tolerance of solution accuracy *)
		nMaxIterations*, nIterations-: SIZE;   (* maximum number of iterations and number of done iterations *)
		tracer*: Streams.Writer;

		sysMatrix: Matrix;   (* copy of system matrix *)
		tiny: Datatype;

		q, q_1, tmp, w_1, w_2: Vector;

		PROCEDURE & Init( CONST A: Matrix );
		BEGIN
			handleError := MatrixBase.HandleError;  res := MatrixBase.OK;

			(* parameters by default *)
			tolerance := 1 / 1000000;   (* tolerance of solution residual *)
			nMaxIterations := 30;   (* maximum number of iterations *)

			tiny := 10 * MatrixBase.EPS;

			IF LEN( A ) = 0 THEN RETURN;
			END;
			IF LEN( A, 0 ) # LEN( A, 1 ) THEN
				res := MatrixBase.NOTSQUARE;  handleError( res, 'MINRES: matrix is not square!' );  RETURN;
			END;

			sysMatrix := A;

			ReallocateIfNecessary(LEN( A, 0 ));
		END Init;

		PROCEDURE ReallocateIfNecessary(problemSize: SIZE);
		BEGIN
			(* allocate arrays for further needs *)
			IF LEN( q, 0 ) # problemSize THEN
				NEW( q, problemSize );  NEW( q_1, problemSize );  NEW( tmp, problemSize );
				NEW( w_1, problemSize );  NEW( w_2, problemSize );
			END;
			(* initial guess/solution *)
			IF LEN( x, 0 ) # problemSize THEN
				NEW( x, problemSize );
			END;
		END ReallocateIfNecessary;

		PROCEDURE Solve*( CONST b: Vector ): Vector;
		BEGIN
			IF LEN( b, 0 ) # LEN( sysMatrix, 0 ) THEN
				res := MatrixBase.SIZEMISMATCH;  handleError( res, 'MINRES: matrix-vector size missmatch!' );  RETURN x;
			END;

			(* solve system *)
			RETURN MINRES( sysMatrix, b, x, tolerance, nMaxIterations );
		END Solve;

		PROCEDURE SolveNoCopy*( VAR A: Matrix; CONST b: Vector ): Vector;
		BEGIN
			IF LEN( A ) = 0 THEN RETURN x;  END;
			IF LEN( A, 0 ) # LEN( A, 1 ) THEN
				res := MatrixBase.NOTSQUARE;  handleError( res, 'MINRES: matrix is not square!' );  RETURN x;
			END;
			IF LEN( b, 0 ) # LEN( A, 0 ) THEN
				res := MatrixBase.SIZEMISMATCH;  handleError( res, 'MINRES: matrix-vector size missmatch!' );  RETURN x;
			END;

			ReallocateIfNecessary(LEN( b, 0 ));

			RETURN MINRES( A, b, x, tolerance, nMaxIterations );
		END SolveNoCopy;

		PROCEDURE SolveProcBased*( matrixToVector: MatrixToVectorProc; CONST b: Vector ): Vector;
		BEGIN
			IF matrixToVector = NIL THEN
				res := MatrixBase.NILPROC;  handleError( res, 'MINRES: invalid Matrix to Vector procedure pointer!' );  RETURN x;
			END;

			ReallocateIfNecessary(LEN( b, 0 ));

			RETURN MINRESProcBased( matrixToVector, b, x, tolerance, nMaxIterations );
		END SolveProcBased;

		PROCEDURE MINRES(
									CONST A: Matrix;
									CONST b: Vector;
									VAR x: Vector;
									tolerance: Datatype;
									nMaxIterations: SIZE
									): Vector;
		VAR
			a, alpha, beta, beta_1, c, c_1, d0, d1, d2, eta, s, s_1: Datatype;
			residnrm: Datatype;
		BEGIN
			beta_1 := 0;  q_1 := 0;  c := 1;  c_1 := 0;  s := 0;  s_1 := 0;
			w_1 := 0;  w_2 := 0;

			(* initial value of residual and its L2-norm *)
			q := A * x;  q := b - q;  beta := sqrt( q +* q );
			q := (1.0 / beta) * q;  eta := beta;

			residnrm := beta;   (* initial value of residual norm *)

			nIterations := 0;
			WHILE (nIterations < nMaxIterations) & (residnrm > tolerance) DO
				(* Lanczos recursion to obtaine next Krylov vector qi from orthnormal set Q = [q0;q1...qk] *)
				tmp := A * q;
				(* i-th element of main diagonal of Hessenberg matrix Hk = Qk'*A*Qk *)
				alpha := q +* tmp;
				(* new vector on the base of previous *)
				tmp := tmp - beta * q_1;  q_1 := q;  q := tmp - alpha * q;

				(* compute beta for next column of Hessinberg matrix *)
				beta := sqrt( q +* q );
				q := (1 / beta) * q;   (* normalize next Krylov vector *)

				(* current element on main diagonal of T (tridiagonal) matrix with
			   account of previous Givens rotations *)
				a := c * alpha - s * c_1 * beta_1;

				(* main diagonal element of current T column after previous rotation *)
				d0 := sqrt( a * a + beta * beta );
				d1 := s * alpha + c * c_1 * beta_1;   (* first updiagonal element of current T column *)
				d2 := s_1 * beta_1;   (* second updiagonal element of current T column *)

				(* remember previous Givens rotator *)
				c_1 := c;  s_1 := s;
				(* compute current Givens rotator *)
				c := a / d0;  s := beta / d0;

				(* update solution on the base of 3 last Krylov vectors *)
				tmp := (q_1 - d2 * w_2 - d1 * w_1) / d0;  x := x + c * eta * tmp;
				eta := -s * eta;

				(* remember last 2 updating items *)
				w_2 := w_1;  w_1 := tmp;

				(* additional check for stopping *)
				IF beta / beta_1 <= tiny THEN
					IF tracer # NIL THEN
						tracer.String( 'Premature exit due to very small value of current Krylov vector!' );  tracer.Ln;  tracer.Update;
					END;
					RETURN x;
				END;

				(* remember current beta as old *)
				beta_1 := beta;

				(* update residual *)
				residnrm := residnrm * ABS( s );

				IF tracer # NIL THEN
					tracer.String( 'iteration ' );  tracer.Int( nIterations, 0 );
					tracer.String( ':' );  tracer.String( ' res norm = ' );
					tracer.FloatFix( residnrm, 16, 16, 0 );  tracer.Ln;
					tracer.Update();
				END;

				INC( nIterations );
			END;

			RETURN x;
		END MINRES;

		PROCEDURE MINRESProcBased(
												matrixToVector: MatrixToVectorProc;
												CONST b: Vector;
												VAR x: Vector;
												tolerance: Datatype;
												nMaxIterations: SIZE
												): Vector;
		VAR
			a, alpha, beta, beta_1, c, c_1, d0, d1, d2, eta, s, s_1: Datatype;
			residnrm: Datatype;
		BEGIN
			beta_1 := 0;  q_1 := 0;  c := 1;  c_1 := 0;  s := 0;  s_1 := 0;
			w_1 := 0;  w_2 := 0;

			(* initial value of residual and its L2-norm *)
			matrixToVector( x, q );  q := b - q;  beta := sqrt( q +* q );
			q := (1 / beta) * q;  eta := beta;

			residnrm := beta;   (* initial value of residual norm *)

			nIterations := 0;
			WHILE (nIterations < nMaxIterations) & (residnrm > tolerance) DO
				(* Lanczos recursion to obtaine next Krylov vector qi from orthnormal set Q = [q0;q1...qk] *)
				matrixToVector( q, tmp );
				(* i-th element of main diagonal of Hessenberg matrix Hk = Qk'*A*Qk *)
				alpha := q +* tmp;
				(* new vector on the base of previous *)
				tmp := tmp - beta * q_1;  q_1 := q;  q := tmp - alpha * q;

				(* compute beta for next column of Hessinberg matrix *)
				beta := sqrt( q +* q );
				q := (1 / beta) * q;   (* normalize next Krylov vector *)

				(* current element on main diagonal of T (tridiagonal) matrix with
			   account of previous Givens rotations *)
				a := c * alpha - s * c_1 * beta_1;

				(* main diagonal element of current T column after previous rotation *)
				d0 := sqrt( a * a + beta * beta );
				d1 := s * alpha + c * c_1 * beta_1;   (* first updiagonal element of current T column *)
				d2 := s_1 * beta_1;   (* second updiagonal element of current T column *)

				(* remember previous Givens rotator *)
				c_1 := c;  s_1 := s;
				(* compute current Givens rotator *)
				c := a / d0;  s := beta / d0;

				(* update solution on the base of 3 last Krylov vectors *)
				tmp := (q_1 - d2 * w_2 - d1 * w_1) / d0;  x := x + c * eta * tmp;
				eta := -s * eta;

				(* remember last 2 updating items *)
				w_2 := w_1;  w_1 := tmp;

				(* additional check for stopping *)
				IF beta / beta_1 <= tiny THEN
					IF tracer # NIL THEN
						tracer.String( 'Premature exit due to very small value of current Krylov vector!' );  tracer.Ln;  tracer.Update();
					END;
					RETURN x;
				END;

				(* remember current beta as old *)
				beta_1 := beta;

				(* update residual *)
				residnrm := residnrm * ABS( s );

				IF tracer # NIL THEN
					tracer.String( 'iteration ' );  tracer.Int( nIterations, 0 );
					tracer.String( ':' );  tracer.String( ' res norm = ' );
					tracer.FloatFix( residnrm, 16, 16, 0 );  tracer.Ln;
					tracer.Update();
				END;

				INC( nIterations );
			END;

			RETURN x;
		END MINRESProcBased;

	END Solver;

	PROCEDURE CreateSolver*( ): MatrixBase.Solver;   (*FactoryProcedure*)
	VAR minres: Solver; dummy:Matrix;
	BEGIN
		NEW(minres,dummy); RETURN minres;
	END CreateSolver;

	PROCEDURE Solve*( VAR A: Matrix;  CONST b: Vector ): Vector;   (*direct procedural solving; simplest use, but when using repeatedly, running into internal allocation overhead *)
	VAR minres:Solver; dummy:Matrix;
	BEGIN
		NEW(minres,dummy); RETURN minres.SolveNoCopy(A,b);
	END Solve;

	PROCEDURE sqrt( x: Datatype ): Datatype;
	BEGIN
		RETURN Datatype(Math.sqrt(x));
	END sqrt;

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

BEGIN
END KrylovMINRES.

System.FreeDownTo KrylovMINRES ~

