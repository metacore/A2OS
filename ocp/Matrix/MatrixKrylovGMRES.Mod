(**
	DESCRIPTION:
		Generalized Minimum Residual solver of linear systems of equations
	AUTHOR: Alexey Morozov

**)
MODULE KrylovGMRES;

IMPORT MatrixBase, Math := MathL, Streams, KernelLog;

TYPE
	Datatype = MatrixBase.Datatype;
	Matrix = MatrixBase.Matrix;
	Vector = MatrixBase.Vector;

	MatrixToVectorProc* = PROCEDURE {DELEGATE} ( CONST X: Vector; VAR Y: Vector );

	Solver* = OBJECT (MatrixBase.Solver)
	VAR Tolerance*: Datatype;   (* tolerance of solution accuracy *)
		nMaxIterations*, nIterations-: SIGNED32;   (* maximum number of iterations and number of done iterations *)
		nRestart*: SIZE;   (* GMRES will restart every nRestart iterations *)
		(* Total number of iterations = nMaxIterations*nRestart *)
		SysMatrix: Matrix;   (* copy of system matrix *)
		Tracer*: Streams.Writer;
		Tiny: Datatype;

		q: Matrix;
		h: POINTER TO ARRAY OF POINTER TO ARRAY OF Datatype;
		b1: Vector;
		c, s: Vector;
		y, t: Vector;

		PROCEDURE & Init( CONST A: Matrix );
		VAR i: SIZE;
		BEGIN
			handleError := MatrixBase.HandleError;  res := MatrixBase.OK;

			(* parameters by default *)
			Tolerance := 1.0 / 1000000.0;   (* tolerance of solution residual *)
			nMaxIterations := 10;   (* maximum number of iterations *)

			Tiny := 10.0 * MatrixBase.EPS;

			IF LEN( A ) = 0 THEN NEW( h, 0 );  RETURN;
			END;
			IF LEN( A, 0 ) # LEN( A, 1 ) THEN
				res := MatrixBase.NOTSQUARE;  handleError( res, 'MINRES: matrix is not square!' );  RETURN;
			END;

			SysMatrix := A;  nRestart := LEN( A,0 );

			(* allocate arrays for further needs *)
			NEW( q, nRestart + 1, LEN( A,0 ) );  NEW( y, LEN( A,0 ) );  NEW( t, LEN( A,0 ) );
			NEW( h, nRestart );
			FOR i := 0 TO nRestart - 1 DO NEW( h[i], i + 1 );  END;
			NEW( b1, nRestart );  NEW( c, nRestart );  NEW( s, nRestart );

			(* initial guess/solution *)
			NEW( x, LEN( A,0 ) );
		END Init;

		PROCEDURE Solve*( CONST b: Vector ): Vector;
		VAR i: SIZE;
		BEGIN
			IF LEN( b, 0 ) # LEN( SysMatrix, 0 ) THEN
				res := MatrixBase.SIZEMISMATCH;  handleError( res, 'MINRES: matrix-vector size missmatch!' );  RETURN x;
			END;

			(* if necessary reallocate all arrays *)
			IF nRestart + 1 > LEN( q, 0 ) THEN
				NEW( q, nRestart + 1, LEN( b,0 ) );  NEW( y, LEN( b,0 ) );  NEW( t, LEN( b,0 ) );
				NEW( h, nRestart );
				FOR i := 0 TO nRestart - 1 DO NEW( h[i], i + 1 );  END;
				NEW( b1, nRestart );  NEW( c, nRestart );  NEW( s, nRestart );
			END;

			(* solve system *)
			RETURN GMRES( SysMatrix, b, x, Tolerance, nMaxIterations, nRestart );
		END Solve;

		PROCEDURE SolveNoCopy*( VAR A: Matrix;CONST b: Vector ): Vector;
		VAR i: SIZE;
		BEGIN
			IF LEN( A ) = 0 THEN RETURN x;  END;
			IF LEN( A, 0 ) # LEN( A, 1 ) THEN
				res := MatrixBase.NOTSQUARE;  handleError( res, 'MINRES: matrix is not square!' );  RETURN x;
			END;
			IF LEN( b, 0 ) # LEN( A, 0 ) THEN
				res := MatrixBase.SIZEMISMATCH;  handleError( res, 'MINRES: matrix-vector size missmatch!' );  RETURN x;
			END;

			(* if necessary reallocate all arrays *)
			IF LEN( b, 0 ) > LEN( x, 0 ) THEN
				NEW( x, LEN( b,0 ) );
				x := 0;   (* did NEW do it before or not?! *)
			END;
			IF nRestart = 0 THEN nRestart := LEN( b,0 ); END;
			IF nRestart + 1 > LEN( q, 0 ) THEN
				NEW( q, nRestart + 1, LEN( b,0 ) );  NEW( y, LEN( b,0 ) );  NEW( t, LEN( b,0 ) );
				NEW( h, nRestart );
				FOR i := 0 TO nRestart - 1 DO NEW( h[i], i + 1 );  END;
				NEW( b1, nRestart );  NEW( c, nRestart );  NEW( s, nRestart );
			END;

			(* solve system *)
			RETURN GMRES( A, b, x, Tolerance, nMaxIterations, nRestart );
		END SolveNoCopy;

		PROCEDURE SolveProcBased*( MatrixToVector: MatrixToVectorProc;
								   CONST b: Vector ): Vector;
		VAR i: SIZE;
		BEGIN
			IF MatrixToVector = NIL THEN
				(*res := (*MatrixBase.NILPROC*);*)  handleError( res, 'MINRES: invalid Matrix to Vector procedure pointer!' );  RETURN x;
			END;

			(* if necessary - reallocate all arrays *)
			IF LEN( b, 0 ) > LEN( x, 0 ) THEN
				NEW( x, LEN( b,0 ) );  x := 0;   (* did NEW do it before or not?! *)
			END;
			IF nRestart = 0 THEN nRestart := LEN( b,0 ); END;
			IF nRestart + 1 > LEN( q, 0 ) THEN
				NEW( q, nRestart + 1, LEN( b,0 ) );  NEW( y, LEN( b,0 ) );  NEW( t, LEN( b,0 ) );
				NEW( h, nRestart );
				FOR i := 0 TO nRestart - 1 DO NEW( h[i], i + 1 );  END;
				NEW( b1, nRestart );  NEW( c, nRestart );  NEW( s, nRestart );
			END;

			(* solve system *)
			RETURN GMRESProcBased( MatrixToVector, b, x, Tolerance, nMaxIterations,
								   nRestart );
		END SolveProcBased;

		PROCEDURE GMRES( CONST A: Matrix;  CONST b: Vector;
						 VAR x: Vector;  Tolerance: Datatype;
						 nMaxIterations: SIGNED32;  nRestart: SIZE ): Vector;
		VAR k, m, p: SIGNED32;  hk_k1, gamma, d, residnrm: Datatype;  bRestart: BOOLEAN;
		BEGIN
			nIterations := 0;  residnrm := 1;
			WHILE (nIterations < nMaxIterations) & (residnrm > Tolerance) DO
				(* initialize next outer loop *)
				q[0] := A * x;  q[0] := b - q[0];
				b1[0] := Math.sqrt( q[0] +* q[0] );  q[0] := (1 / b1[0]) * q[0];

				k := 0;  bRestart := FALSE;
				WHILE (k < nRestart) & (~bRestart) DO
					(*
					determine new Krylov vector on the base of
					Arnoldi orthogonalization algorithm
					*)
					q[k + 1] := A * q[k];
					FOR m := 0 TO k DO
						h[k, m] := q[k + 1] +* q[m];  y := h[k, m] * q[m];
						t := q[k + 1] - y;  q[k + 1] := t;
						(*
						q[k + 1] := q[k + 1] - h[k, m] * q[m];
						*)
					END;
					(* subdiagonal h[k,k+1] element of Hessenberg matrix H = q'*A*q *)
					hk_k1 := Math.sqrt( q[k + 1] +* q[k + 1] );

					(* account previous Given rotations *)
					FOR m := 1 TO k DO
						gamma := c[m - 1] * h[k, m - 1] + s[m - 1] * h[k, m];
						h[k, m] := -s[m - 1] * h[k, m - 1] + c[m - 1] * h[k, m];
						h[k, m - 1] := gamma;
					END;

					(* new Given rotator to annihilate h[k,k+1] *)
					d := Math.sqrt( h[k, k] * h[k, k] + hk_k1 * hk_k1 );
					c[k] := h[k, k] / d;  s[k] := hk_k1 / d;
					h[k, k] := c[k] * h[k, k] + s[k] * hk_k1;

					(* update unit rhs vectors b1 = ||r0||e1 according to current rotation *)
					IF k + 1 < nRestart THEN
						b1[k + 1] := -s[k] * b1[k];  residnrm := ABS( b1[k + 1] );
					ELSE residnrm := ABS( -s[k] * b1[k] );
					END;
					b1[k] := c[k] * b1[k];

					(* check for premature resetting *)
					IF ABS( hk_k1 ) > Tiny THEN q[k + 1] := q[k + 1] / hk_k1;
					ELSE
						bRestart := TRUE;
						IF Tracer # NIL THEN
							Tracer.String( 'Premature resetting!' );  Tracer.Ln;  Tracer.Update();
						END;
					END;

					IF Tracer # NIL THEN
						Tracer.String( 'iteration ' );  Tracer.Int( nIterations, 0 );
						Tracer.String( '(' );  Tracer.Int( k, 0 );  Tracer.String( ')' );
						Tracer.String( 'res norm = ' );  Tracer.FloatFix( residnrm, 16, 16, 0 );
						Tracer.Ln;  Tracer.String( 'h[k,k+1] = ' );
						Tracer.FloatFix( hk_k1, 16, 16, 0 );  Tracer.Ln;
						Tracer.Update();
					END;

					INC( k );
				END;

				DEC( k );
				(* update solution and restart algorithm *)
				b1[k] := b1[k] / h[k, k];
				FOR m := k - 1 TO 0 BY -1 DO
					d := 0;
					FOR p := m + 1 TO k DO d := d + h[p, m] * b1[p];  END;
					b1[m] := (b1[m] - d) / h[m, m];
				END;
				FOR m := 0 TO k DO x := x + b1[m] * q[m];  END;

				INC( nIterations );
			END;

			RETURN x;
		END GMRES;

		PROCEDURE GMRESProcBased( MatrixToVector: MatrixToVectorProc;
								  CONST b: Vector;
								  VAR x: Vector;  Tolerance: Datatype;
								  nMaxIterations: SIGNED32;  nRestart: SIZE ): Vector;
		VAR k, m, p: SIGNED32;  hk_k1, gamma, d, residnrm: Datatype;  bRestart: BOOLEAN;
		BEGIN
			nIterations := 0;  residnrm := 1;
			WHILE (nIterations < nMaxIterations) & (residnrm > Tolerance) DO
				(* initialize next outer loop *)
				MatrixToVector( x, q[0] );  q[0] := b - q[0];
				b1[0] := Math.sqrt( q[0] +* q[0] );  q[0] := q[0] / b1[0];  k := 0;
				bRestart := FALSE;
				WHILE (k < nRestart) & (~bRestart) DO
					(*
				determine new Krylov vector on the base of
				Arnoldi orthogonalization algorithm
				*)
					MatrixToVector( q[k], q[k + 1] );
					FOR m := 0 TO k DO
						h[k, m] := q[k + 1] +* q[m];  y := h[k, m] * q[m];
						t := q[k + 1] - y;  q[k + 1] := t;
						(*
						q[k + 1] := q[k + 1] - h[k, m] * q[m];
						*)
					END;
					(* subdiagonal h[k,k+1] element of Hessenberg matrix H = q'*A*q *)
					hk_k1 := Math.sqrt( q[k + 1] +* q[k + 1] );
					(* account previous Given rotations *)
					FOR m := 1 TO k DO
						gamma := c[m - 1] * h[k, m - 1] + s[m - 1] * h[k, m];
						h[k, m] := -s[m - 1] * h[k, m - 1] + c[m - 1] * h[k, m];
						h[k, m - 1] := gamma;
					END;
					(* new Given rotator to annihilate h[k,k+1] *)
					d := Math.sqrt( h[k, k] * h[k, k] + hk_k1 * hk_k1 );
					c[k] := h[k, k] / d;  s[k] := hk_k1 / d;
					h[k, k] := c[k] * h[k, k] + s[k] * hk_k1;

					(* update unit rhs vectors b1 = ||r0||e1 according to current rotation *)
					IF k + 1 < nRestart THEN
						b1[k + 1] := -s[k] * b1[k];  residnrm := ABS( b1[k + 1] );
					ELSE residnrm := ABS( -s[k] * b1[k] );
					END;
					b1[k] := c[k] * b1[k];

					(* check for premature resetting *)
					IF ABS( hk_k1 ) > Tiny THEN q[k + 1] := q[k + 1] / hk_k1;
					ELSE
						bRestart := TRUE;
						IF Tracer # NIL THEN
							Tracer.String( 'Premature resetting!' );  Tracer.Ln;  Tracer.Update();
						END;
					END;

					IF Tracer # NIL THEN
						Tracer.String( 'iteration ' );  Tracer.Int( nIterations, 0 );
						Tracer.String( '(' );  Tracer.Int( k, 0 );  Tracer.String( '): ' );
						Tracer.String( 'res norm = ' );  Tracer.FloatFix( residnrm, 16, 16, 0 );
						Tracer.Ln;  Tracer.String( 'h[k,k+1] = ' );
						Tracer.FloatFix( hk_k1, 16, 16, 0 );  Tracer.Ln;
						Tracer.Update();
					END;

					INC( k );
				END;

				DEC( k );
				(* update solution and restart algorithm *)
				b1[k] := b1[k] / h[k, k];
				FOR m := k - 1 TO 0 BY -1 DO
					d := 0;
					FOR p := m + 1 TO k DO d := d + h[p, m] * b1[p];  END;
					b1[m] := (b1[m] - d) / h[m, m];
				END;
				FOR m := 0 TO k DO x := x + b1[m] * q[m];  END;

				INC( nIterations );
			END;
			RETURN x;
		END GMRESProcBased;

	END Solver;


	PROCEDURE CreateSolver*( ): MatrixBase.Solver;   (*FactoryProcedure*)
	VAR gmres: Solver; dummy:Matrix;
	BEGIN
		NEW(gmres,dummy); RETURN gmres;
	END CreateSolver;

	PROCEDURE Solve*( VAR A: Matrix;  CONST b: Vector ): Vector;   (*direct procedural solving; simplest use, but when using repeatedly, running into internal allocation overhead *)
	VAR gmres:Solver; dummy:Matrix;
	BEGIN
		NEW(gmres,dummy); RETURN gmres.SolveNoCopy(A,b);
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

END KrylovGMRES.

System.FreeDownTo KrylovGMRES ~