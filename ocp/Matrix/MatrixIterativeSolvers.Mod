MODULE MatrixIterativeSolvers;   (**  AUTHOR "Patrick Hunziker"; PURPOSE "Iterative Methods to solve linear equations";  **)
(** Solves Matrix Equation Ax=b  by iterative methods (Gauss-Seidel; Gauss-Seidel with successive overrelaxation; Jacobi);
	Gauss-Seidel and Jacobi methods converge  in diagonally dominant matrices where A[i,i]>SUM(A[i,not i]); may also converge in other cases *)
IMPORT MathL, Base := MatrixBase, (*the latter used only for testing*) Strings, Kernel, Out := KernelLog;

TYPE
	Datatype* = Base.Datatype;  Matrix* = Base.Matrix;  Vector* = Base.Vector;

CONST
	DefaultMaxIterations* = 50;
	DefaultThreshold* = 1.0E-3;
	DefaultOmega* = 1.3; (*for Gauss Seidel SOR method*)

TYPE
	IterativeSolver* = OBJECT (Base.Solver)
		VAR A-: Matrix;
			residual*: Vector;
			maxIterations*,  iteration*: SIGNED32;
			threshold*: Datatype;
			Norm*: PROCEDURE {DELEGATE} ( CONST v: Vector ): Datatype;   (** method to compute residual *)

		PROCEDURE & Init*( CONST A: Matrix );   (** Can be called with zero length matrix to generate generic kind of solver; can be initialized with matrix later*)
		BEGIN
			handleError := Base.HandleError;   (*default error handler*)
			res := Base.OK;  maxIterations := DefaultMaxIterations;  threshold := DefaultThreshold;  Norm := L2;
			iteration:=0;
			IF LEN( A ) # LEN( A, 1 ) THEN res := Base.NOTSQUARE;  handleError( res, "iterative Solver: matrix not square" );   END;
			SELF.A:=ALIAS OF A;  (* use built-in ZEROCOPY procedure if available *)
			IF LEN( x ) # LEN( A, 1 ) THEN NEW( x, LEN( A, 1 ) );  ELSE x := 0;  END;
			NEW( residual, LEN( A, 0 ) );
		END Init;

		PROCEDURE Step*( CONST b: Vector;  VAR x: Vector );   (*compute single step of iteration, e.g. as a smoother*)
		END Step;

	END IterativeSolver;

	(** Gauss Seidel is more memory-conservative than the Jacobi method; however, interim results in (i) loop depend on each other, so outer loop parallelisation is problematic*)
	(*note that the sweep direction may have an important effect on convergence speed: http://www.cfd-online.com/Wiki/Gauss-Seidel_method; this is not yet used in this implementation *)
TYPE
	GaussSeidel* = OBJECT (IterativeSolver)
		PROCEDURE Solve*( CONST b: Vector ): Vector;
		VAR i: SIZE;  r: Datatype;
		BEGIN
			IF LEN( A, 0 ) # LEN( b ) THEN res := Base.SIZEMISMATCH;  handleError( res, "GaussSeidel: matrix / vector size mismatch" );  RETURN x END;
			iteration := 0;
			residual := b - A * x;
			LOOP
				IF Norm( residual ) <= threshold THEN RETURN x
				ELSIF iteration >= maxIterations THEN res := Base.NONCONVERGENCE;  handleError( res, "GaussSeidel: Nonconvergence" );  RETURN x
				END;
				FOR i := 0 TO LEN( x,0 ) - 1 DO
					r := b[i] - A[i] +* x;  x[i] := x[i] + r / A[i, i];
					residual[i] := r;   (* cheap approximate residual for convergence measurement*)
				END;
				INC( iteration );
				(*residual := b - A * x;*)  (* more accurate residual: but more expensive than above*)
			END;
		END Solve;

		PROCEDURE Step*( CONST b: Vector;  VAR x: Vector );   (*compute single step of GaussSeidel, e.g. as a smoother*)
		VAR i: SIZE;  r: Datatype;
		BEGIN
			FOR i := 0 TO LEN( x,0 ) - 1 DO r := b[i] - A[i] +* x;  x[i] := x[i] + r / A[i, i];  END;
		END Step;
	END GaussSeidel;

	(** Gauss Seidel with successive overrelaxation. Choose [0 < omega < 2] ;
	For omega=1, this corresponds to Gauss Seidel; omega>1 speeds some problems up (less stable); omega<1 damps/stabilizes divergent/oscillating behaviour (but is slower) *)
TYPE
	GaussSeidelSOR* = OBJECT (IterativeSolver)
		VAR omega*: Datatype;

		PROCEDURE & Init*( CONST A: Matrix );
		BEGIN
			Init^( A );  omega := DefaultOmega;  x := InvDiag( A );
		END Init;

		PROCEDURE Solve*( CONST b: Vector ): Vector;
		VAR r: Datatype;  i: SIZE;
		BEGIN
			IF LEN( A, 0 ) # LEN( b ) THEN res := Base.SIZEMISMATCH;  handleError( res, "GaussSeidelSOR: matrix / vector size mismatch" );  RETURN x END;
			iteration := 0;  residual := b - A * x;
			LOOP
				IF Norm( residual ) <= threshold THEN RETURN x
				ELSIF iteration >= maxIterations THEN res := Base.NONCONVERGENCE; handleError( res, "GaussSeidel-SOR: Nonconvergence" );  RETURN x
				END;
				FOR i := 0 TO LEN( x,0 ) - 1 DO
					r := b[i] - A[i] +* x;
					x[i] := (1 - omega) * x[i] + omega * (r / A[i, i] + x[i]);
					residual[i] := r;   (*???? cheap approximate residual*)
				END;
				INC( iteration );
				(*residual:= b-A*x;*)  (*accurate, but costly residual*)
			END;
		END Solve;

		PROCEDURE Step*( CONST b: Vector;  VAR x: Vector );   (*compute single step of GaussSeidelSOR, e.g. as a smoother*)
		VAR i: SIZE;  r: Datatype;
		BEGIN
			FOR i := 0 TO LEN( x,0 ) - 1 DO r := b[i] - A[i] +* x;  x[i] := (1 - omega) * x[i] + omega * (r / A[i, i] + x[i]);  END;
		END Step;
	END GaussSeidelSOR;

	(** Jacobi algorithm converges usually slower than Gauss Seidel, but parallelisation is easier. uses somewhat more memory than Gauss-Seidel*)
TYPE
	Jacobi* = OBJECT (IterativeSolver)
	VAR iDA: Vector;

		PROCEDURE & Init*( CONST A: Matrix );
		BEGIN
			Init^( A );  iDA := InvDiag( A );
		END Init;

		PROCEDURE Solve*( CONST b: Vector ): Vector;
		BEGIN
			iteration := 0;
			IF LEN( A, 0 ) # LEN( b ) THEN res := Base.SIZEMISMATCH;  handleError( res, "Jacobi: matrix / vector size mismatch" );  RETURN x END;
			LOOP
				residual := A * x;
				residual := b - residual;
				IF Norm( residual ) < threshold THEN RETURN x
				ELSIF iteration >= maxIterations THEN res := Base.NONCONVERGENCE; handleError( res, "Jacobi: Nonconvergence" );  RETURN x
				END;
				x := x + residual .* iDA;
				INC(iteration);
			END;
		END Solve;

		PROCEDURE Step*( CONST b: Vector;  VAR x: Vector );   (*compute single step of Jacobi, e.g. as a smoother*)
		BEGIN
			residual := A * x;  residual := b - residual;  x := x + residual .* iDA;
		END Step;
	END Jacobi;

	(** Conjugate Gradient method: for square, symmetric, positive definite matrices *)
	(* see en.wikipedia.org/wiki/Conjugate_Gradient *)
TYPE
	ConjugateGradient* = OBJECT (IterativeSolver)
	VAR p, Ap: Vector;
		a, rTr, rTr2: Datatype;

		PROCEDURE Solve*( CONST b: Vector ): Vector;
		BEGIN
			IF LEN( A, 0 ) # LEN( b ) THEN res := Base.SIZEMISMATCH;  handleError( res, "Jacobi: matrix / vector size mismatch" );  RETURN x END;
			IF LEN( p ) # LEN( b ) THEN NEW( p, LEN( b,0 ) ) ELSE p := 0 END;
			iteration := 0;
			residual := b - A * x;
			rTr := residual +* residual;  rTr2 := rTr;
			LOOP
				IF Norm( residual ) < threshold THEN RETURN x
				ELSIF iteration >= maxIterations THEN res := Base.NONCONVERGENCE;  handleError( res, "ConjugateGradient: Nonconvergence" ); RETURN x
				END;
				p := (rTr / rTr2) * p + residual;
				Ap := A * p;  a := rTr / (p +* Ap);
				x := x + a * p;
				residual := residual - a * Ap;
				INC( iteration );  rTr2 := rTr;  rTr := residual +* residual;
			END;
		END Solve;
	END ConjugateGradient;

	(* TO DO: implement BiConjugateGradient (*extension of conjugate gradient method for nonsymmetric matrices, see wikipedia *)	*)

	(** simple procedural interfaces to solvers; *)

	PROCEDURE SolveGaussSeidel*( VAR A: Matrix;  CONST b: Vector;  threshold: Datatype ): Vector;
	VAR gs: GaussSeidel;
	BEGIN
		NEW( gs, A );  gs.threshold := threshold;  RETURN gs.Solve( b );
	END SolveGaussSeidel;

	PROCEDURE SolveGaussSeidelSOR*( VAR A: Matrix;  CONST b: Vector;  threshold, omega: Datatype ): Vector;
	VAR gss: GaussSeidelSOR;
	BEGIN
		NEW( gss, A );  gss.threshold := threshold;  gss.omega := omega;  RETURN gss.Solve( b );
	END SolveGaussSeidelSOR;

	PROCEDURE SolveJacobi*( VAR A: Matrix;  CONST b: Vector;  threshold: Datatype ): Vector;
	VAR j: Jacobi;
	BEGIN
		NEW( j, A );  j.threshold := threshold;  RETURN j.Solve( b );
	END SolveJacobi;

	PROCEDURE SolveConjugateGradient*( VAR A: Matrix;  CONST b: Vector;  threshold: Datatype ): Vector;
	VAR cg: ConjugateGradient;
	BEGIN
		NEW( cg, A );  cg.threshold := threshold;  RETURN cg.Solve( b );
	END SolveConjugateGradient;

(** Factory procedures*)

	PROCEDURE CreateGaussSeidel*( VAR A: Matrix ): Base.Solver;   (** Example of factory procedure*)
	VAR gs: GaussSeidel;
	BEGIN
		NEW( gs, A );  RETURN gs;
	END CreateGaussSeidel;

	PROCEDURE CreateGaussSeidelSOR*( VAR A: Matrix ): Base.Solver;
	VAR gss: GaussSeidelSOR;
	BEGIN
		NEW( gss, A );  RETURN gss;
	END CreateGaussSeidelSOR;

	PROCEDURE CreateJacobi*( VAR A: Matrix ): Base.Solver;
	VAR j: Jacobi;
	BEGIN
		NEW( j, A );  RETURN j;
	END CreateJacobi;

	PROCEDURE CreateConjugateGradient*( VAR A: Matrix ): Base.Solver;
	VAR cg: ConjugateGradient;
	BEGIN
		NEW( cg, A );  RETURN cg;
	END CreateConjugateGradient;

(* helper procedures*)

	PROCEDURE L2( CONST m: Vector ): Datatype;
	BEGIN
		RETURN MathL.sqrt( m +* m )
	END L2;

	PROCEDURE InvDiag( CONST M: Matrix ): Vector;
	VAR x: Vector;  i: SIZE;  a: Datatype;
	BEGIN
		NEW( x, MAX( LEN( M, 0 ), LEN( M, 1 ) ) );
		FOR i := 0 TO LEN( x,0 ) - 1 DO
			a := M[i, i];
			IF ABS( a ) > Base.EPS THEN x[i] := 1 / a ELSE x[i] := 0 END;
		END;
		RETURN x
	END InvDiag;

	PROCEDURE Log( CONST m: Matrix );
	VAR i, j: SIZE;
	BEGIN
		IF LEN( m ) = 0 THEN Out.String( "zero size matrix" );  Out.Ln;  RETURN;  END;
		FOR j := 0 TO LEN( m, 0 ) - 1 DO
			FOR i := 0 TO LEN( m, 1 ) - 1 DO OutFloat( m[j, i] );  END;
			Out.Ln;
		END;
		Out.Ln;
	END Log;

	PROCEDURE LogV( CONST m: Vector );
	VAR i: SIZE;
	BEGIN
		IF LEN( m ) = 0 THEN Out.String( "zero size matrix" );  Out.Ln;  RETURN;  END;
		FOR i := 0 TO LEN( m,0 ) - 1 DO OutFloat( m[i] );  END;
		Out.Ln;
	END LogV;


	PROCEDURE OutFloat( x: FLOAT64 );
	VAR s: ARRAY 64 OF CHAR;
	BEGIN
		Strings.FloatToStr( x, 6, 6, 0, s );  Out.String( s );
	END OutFloat;

	PROCEDURE DummyHandler( i:SIGNED32; s: ARRAY OF CHAR );
	BEGIN
	END DummyHandler;


	PROCEDURE {TEST} Test*;
	CONST TestThreshold = 0.001;
	VAR A: Matrix;  b, x, e: Vector;  i: SIGNED32; error:Datatype; timer: Kernel.MilliTimer;  gs: GaussSeidel; gss: GaussSeidelSOR; j: Jacobi; cg: ConjugateGradient;
	BEGIN
		A := [[3, 1, 1, 0], [1, 5, 2, 1], [2, 1, 6, 2], [1, 2, 3, 7]];  b := [1, 2, 3, 2];  (* Gauss Seidel and Jacobi require diagonally dominant matrices for guaranteed convergence *)
		x := SolveGaussSeidel( A, b, DefaultThreshold );
		e := A*x-b; error:= e+*e;
		ASSERT(error < TestThreshold, 201);

		NEW(gs,A); 
		x := gs.Solve( b ); 
		e := A*x-b; error:= e+*e;
		ASSERT(error < TestThreshold, 202);

		x := SolveGaussSeidelSOR( A, b, DefaultThreshold, 1.3 );
		e := A*x-b; error:= e+*e;
		ASSERT(error < TestThreshold, 203);

		NEW(gss,A); 
		x := gss.Solve( b ); 
		e := A*x-b; error:= e+*e;
		ASSERT(error < TestThreshold, 204);

		x := SolveJacobi( A, b, DefaultThreshold );
		e := A*x-b; error:= e+*e;
		ASSERT(error < TestThreshold, 205);

		NEW(j,A);
		x := j.Solve( b ); 
		e := A*x-b; error:= e+*e;
		ASSERT(error < TestThreshold, 206);

		A := [[5, -1, -2, -3], [-1, 5, 4, 2], [-2, 4, 5, 1], [-3, 2, 1, 5]];   (* CG requires symmetric, positive definite matrix *)
		b := [1, 2, 3, 4];
		x := SolveConjugateGradient( A, b, DefaultThreshold );
		e := A*x-b; error:= e+*e;
		ASSERT(error < TestThreshold, 207);

		NEW(cg,A); 
		x := cg.Solve( b );
		e := A*x-b; error:= e+*e;
		ASSERT(error < TestThreshold, 208);
	END Test;

	PROCEDURE Test1*;
	VAR A: Matrix;  b, x: Vector;  i: SIGNED32;  timer: Kernel.MilliTimer;  gs: GaussSeidel; gss: GaussSeidelSOR; j: Jacobi; cg: ConjugateGradient;
	BEGIN
		A := [[3, 1, 1, 0], [1, 5, 2, 1], [2, 1, 6, 2], [1, 2, 3, 7]];  b := [1, 2, 3, 2];  (* Gauss Seidel and Jacobi require diagonally dominant matrices for guaranteed convergence *)

		Out.String( "============GaussSeidel==============" );  Out.Ln;  Kernel.SetTimer(timer,0);
		FOR i := 0 TO 10000 DO x := SolveGaussSeidel( A, b, DefaultThreshold );  END;
		Out.String( "Gauss Seidel Procedure" );  Out.Int(Kernel.Elapsed(timer),6);
		Out.String( "ms" );  Out.Ln;  Out.String( "A" );  Log( A );  Out.String( "b" );  Out.Ln;  LogV( b );  Out.Ln;  Out.String( "x" );  Out.Ln;  LogV( x );  Out.Ln;
		Out.String( "Ax-b" );  Out.Ln;  LogV( A * x - b );  Out.Ln;  Out.String( "error: " );  OutFloat( L2( A * x - b ) );  Out.Ln;

		Out.String( "============GaussSeidel Solver==============" );  Out.Ln;
		NEW(gs,A); Kernel.SetTimer(timer,0);
		FOR i := 0 TO 10000 DO  x := gs.Solve( b ); gs.x:=0; (*reset for testing*) END;
		Out.String( "Gauss Seidel Solver" );  Out.Int(Kernel.Elapsed(timer),6);
		Out.String( "ms" );  Out.Ln;  Out.String( "A" );  Log( A );  Out.String( "b" );  Out.Ln;  LogV( b );  Out.Ln;  Out.String( "x" );  Out.Ln;  LogV( x );  Out.Ln;
		Out.String( "Ax-b" );  Out.Ln;  LogV( A * x - b );  Out.Ln;  Out.String( "error: " );  OutFloat( L2( A * x - b ) );  Out.Ln;
		Out.String("iterations: "); Out.Int(gs.iteration,6);Out.Ln;

		Out.String( "============GaussSeidelSOR Procedure==============" );  Out.Ln;  Kernel.SetTimer(timer,0);
		FOR i := 0 TO 10000 DO x := SolveGaussSeidelSOR( A, b, DefaultThreshold, 1.3 );  END;
		Out.String( "Gauss Seidel SOR Procedure" ); Out.Int(Kernel.Elapsed(timer),6);
		Out.String( "ms" );  Out.Ln;  Out.String( "A" );  Log( A );  Out.String( "b" );  Out.Ln;  LogV( b );  Out.Ln;  Out.String( "x" );  Out.Ln;  LogV( x );  Out.Ln;
		Out.String( "Ax-b" );  Out.Ln;  LogV( A * x - b );  Out.String( "error: " );  OutFloat( L2( A * x - b ) );  Out.Ln;

		Out.String( "============GaussSeidelSOR Solver Object==============" );  Out.Ln;
		NEW(gss,A); Kernel.SetTimer(timer,0);
		FOR i := 0 TO 10000 DO x := gss.Solve( b ); gss.x:=0; (*reset for testing*)  END;
		Out.String( "Gauss Seidel Solver" );  Out.Int(Kernel.Elapsed(timer),6);
		Out.String( "ms" );  Out.Ln;  Out.String( "A" );  Log( A );  Out.String( "b" );  Out.Ln;  LogV( b );  Out.Ln;  Out.String( "x" );  Out.Ln;  LogV( x );  Out.Ln;
		Out.String( "Ax-b" );  Out.Ln;  LogV( A * x - b );  Out.Ln;  Out.String( "error: " );  OutFloat( L2( A * x - b ) );  Out.Ln;
		Out.String("iterations: "); Out.Int(gss.iteration,6);Out.Ln;

		Out.String( "============Jacobi==============" );  Out.Ln;  Kernel.SetTimer(timer,0);
		FOR i := 0 TO 10000 DO x := SolveJacobi( A, b, DefaultThreshold );  END;
		Out.String( "Jacobi Procedure" ); Out.Int(Kernel.Elapsed(timer),6);
		Out.String( "ms" );  Out.Ln;  Out.String( "A" );  Log( A );  Out.String( "b" );  Out.Ln;  LogV( b );  Out.Ln;  Out.String( "x" );  Out.Ln;  LogV( x );  Out.Ln;
		Out.String( "Ax-b" );  Out.Ln;  LogV( A * x - b );  Out.String( "error: " );  OutFloat( L2( A * x - b ) );  Out.Ln;

		Out.String( "============Jacobi Solver Object==============" );  Out.Ln;
		NEW(j,A); Kernel.SetTimer(timer,0);
		FOR i := 0 TO 10000 DO x := j.Solve( b ); j.x:=0;  (*reset for testing*) END;
		Out.String( "Jacobi Solver" );  Out.Int(Kernel.Elapsed(timer),6);
		Out.String( "ms" );  Out.Ln;  Out.String( "A" );  Log( A );  Out.String( "b" );  Out.Ln;  LogV( b );  Out.Ln;  Out.String( "x" );  Out.Ln;  LogV( x );  Out.Ln;
		Out.String( "Ax-b" );  Out.Ln;  LogV( A * x - b );  Out.Ln;  Out.String( "error: " );  OutFloat( L2( A * x - b ) );  Out.Ln;
		Out.String("iterations: "); Out.Int(j.iteration,6);Out.Ln;

		Out.String( "============Conjugate Gradient==============" );  Out.Ln;
		A := [[5, -1, -2, -3], [-1, 5, 4, 2], [-2, 4, 5, 1], [-3, 2, 1, 5]];   (* CG requires symmetric, positive definite matrix *)
		b := [1, 2, 3, 4];
		Kernel.SetTimer(timer,0);
		FOR i := 0 TO 10000 DO x := SolveConjugateGradient( A, b, DefaultThreshold );  END;
		Out.String( "Conjugate Gradient Procedure" ); Out.Int(Kernel.Elapsed(timer),6);
		Out.String( "ms" );  Out.Ln;  Out.String( "A" );  Log( A );  Out.String( "b" );  Out.Ln;  LogV( b );  Out.Ln;  Out.String( "x" );  Out.Ln;  LogV( x );  Out.Ln;
		Out.String( "Ax-b" );  Out.Ln;  LogV( A * x - b );  Out.String( "error: " );  OutFloat( L2( A * x - b ) );  Out.Ln;

		Out.String( "============Conjugate Gradient Solver Object==============" );  Out.Ln;
		NEW(cg,A); Kernel.SetTimer(timer,0);
		FOR i := 0 TO 10000 DO x := cg.Solve( b ); cg.x:=0; (*reset for testing*)   END;
		Out.String( "Conjugate Gradient Solver Object" );  Out.Int(Kernel.Elapsed(timer),6);
		Out.String( "ms" );  Out.Ln;  Out.String( "A" );  Log( A );  Out.String( "b" );  Out.Ln;  LogV( b );  Out.Ln;  Out.String( "x" );  Out.Ln;  LogV( x );  Out.Ln;
		Out.String( "Ax-b" );  Out.Ln;  LogV( A * x - b );  Out.Ln;  Out.String( "error: " );  OutFloat( L2( A * x - b ) );  Out.Ln;
		Out.String("iterations: "); Out.Int(cg.iteration,6);Out.Ln;
	END Test1;

END MatrixIterativeSolvers.

MatrixIterativeSolvers.Test
----------------------------
fofPC.Compile \Ws *
fofPC.Compile \f *
SystemTools.FreeDownTo MatrixIterativeSolvers ~
OFormatter.Format *
----------------------------
Ref:
en.wikipedia.org/wiki/Gauss-Seidel_method
en.wikipedia.org/wiki/Gauss-Seidel_SOR_method
en.wikipedia.org/wiki/Jacobi_method

