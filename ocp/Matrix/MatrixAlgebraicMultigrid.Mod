MODULE MatrixAlgebraicMultigrid;    (**  AUTHOR "Patrick Hunziker"; PURPOSE "Algebraci Multigrid Solver for linear equations";  **)
IMPORT Base:=MatrixBase, MatrixStandardSolvers,  Util:=MatrixUtilities, Out;
(*Version 12.3.08*)
(*todo: add error codes*)

CONST
	OK = Base.OK;
	DefaultLevels=3;
	Vcycle* = 1;
	Wcycle* = 2;
	DefaultGamma=Vcycle;
	DefaultOmega=0.5;

TYPE
	Datatype*=Base.Datatype;
	Matrix*=Base.Matrix;
	Vector*=Base.Vector;
	MatrixOperator*= PROCEDURE (CONST A:Matrix):Matrix;
	VectorOperator*= PROCEDURE (CONST v:Vector):Vector;
	Smoother*=PROCEDURE (CONST A: Matrix; CONST b:Vector; VAR x:Vector; omega: Datatype);

	Solver* = OBJECT (Base.Solver);
	VAR
		(*directSolve*: DirectSolver;*) (*does not compile *)
		smooth*:Smoother;
		restrictMatrix*,prolongMatrix*: MatrixOperator; (*passing procedure to this variable does not yet work*)
		restrictVector*,prolongVector*: VectorOperator;
		A: Matrix;
		b: Vector;
		coarse:Solver;
		level, gamma:SIGNED16;
		presmooth,postsmooth:SIGNED16;
		omega:FLOAT32;

		PROCEDURE & Init*( CONST A: Base.Matrix );   (*Can be called with zero length matrix to generate generic kind of solver; can be initialized with matrix later*)
		BEGIN
			handleError := Base.HandleError;   (*default error handler*)
			res := OK;   (**)
			SELF.A:=A;
			IF LEN(A)>0 THEN NEW(x,LEN(A,1)); END;
			(*
			restrictMatrix:=restrictM; prolongMatrix:=prolongM; restrictVector:=restrictV; prolongVector;=prolongV; (*TO DO: this does not compile yet ...*)
			*)
			level:=DefaultLevels;
			gamma:=DefaultGamma;
			omega:=DefaultOmega;
			(*directSolve:=MatrixStandardSolvers.SolveLU;*)
			(*smooth:=MatrixIterativeSolvers.GaussSeidelSORStep;*)
			smooth:=GaussSeidelSORStep;
			presmooth:=4;
			postsmooth:=4;
		END Init;

		PROCEDURE Solve*( CONST b: Vector ): Vector;  (* generic parameterless solving *)
		BEGIN
			RETURN SolveNoCopy(A,b);
		END Solve;

		PROCEDURE SolveNoCopy*( VAR M:Matrix; CONST b: Vector ): Vector;  (* generic solving, no internal copy of system matrix*)
		VAR B:Matrix; i,j:SIGNED32;
		BEGIN
			IF level = 0 THEN
					B:=M; (*hack because direct solver is LU solver which may change A *)
					x:=MatrixStandardSolvers.SolveLU(B,b);  (*full precision solving in innermost loop*)
			ELSE
				IF LEN(x)=0 THEN NEW(x,LEN(M,1)) END;
				IF coarse=NIL THEN
					NEW (coarse, restrictM(M));
					coarse.smooth:=smooth;
					coarse.gamma:=gamma;
					coarse.omega:=omega;
					coarse.presmooth:=presmooth;
					coarse.postsmooth:=postsmooth;
					coarse.level:=level-1;
						END;
				FOR i := 0 TO presmooth - 1 DO smooth( M, b, x, omega );  END;
				coarse.b := restrictV( b - M * x ); coarse.x:=0;
				FOR j := 0 TO gamma - 1 DO coarse.x:=coarse.Solve(coarse.b); END;
				x := x+ prolongV( coarse.x );  res:=coarse.res;
				FOR i := 0 TO postsmooth - 1 DO smooth( M, b, x, omega );  END;
			END;
			IF (res#OK) & (handleError # NIL ) THEN handleError( res, "no convergence" ) END;
			RETURN x;
		END SolveNoCopy;

		(*
		PROCEDURE SolveMultiple*( B: Matrix ): Matrix;  (* example of specific implementation for multiple right hand sides A*X=B    *)
		VAR X: Matrix;
		BEGIN
			RETURN X;
		END SolveMultipleRHS;
		*)

	END Solver;

	PROCEDURE restrictM(CONST A:Matrix):Matrix;
	BEGIN
		RETURN Util.InterpolateMDown2( A );
	END restrictM;

	PROCEDURE prolongM(CONST A:Matrix):Matrix;
	BEGIN
		RETURN Util.InterpolateMUp2( A );
	END prolongM;

	PROCEDURE restrictV(CONST v:Vector):Vector;
	BEGIN
		RETURN Util.InterpolateVDown2( v );
	END restrictV;

	PROCEDURE prolongV(CONST v:Vector):Vector;
	BEGIN
		RETURN Util.InterpolateVUp2( v );
	END prolongV;

	(*one repeat of Gauss-SeidelSOR, can be used as smoother, e.g. in algebraic multigrid, is an excerpt from MatrixIterativeSolvers.Mod; use library call in future implementation *)
	PROCEDURE GaussSeidelSORStep( CONST A: Matrix;  CONST b: Vector;  VAR x: Vector;  omega: Datatype );
	VAR s: Datatype;  i, n: SIZE;
	BEGIN
		ASSERT ( LEN( A, 0 ) = LEN( b ) );
		ASSERT ( LEN( A, 1 ) = LEN( x ) );
		FOR i := 0 TO LEN( A, 1 ) - 1 DO s := A[i] +* x - A[i, i] * x[i];  x[i] := (1 - omega) * x[i] + omega * (b[i] - s) / A[i, i];  END;
	END GaussSeidelSORStep;


	PROCEDURE CreateSolver*( ): Base.Solver;   (*FactoryProcedure*)
	VAR amg: Solver; dummy:Matrix;
	BEGIN
		NEW(amg,dummy); RETURN amg;
	END CreateSolver;

	PROCEDURE Solve*( VAR A: Matrix;  CONST b: Vector ): Vector;   (*direct procedural solving; simplest use, but when using repeatedly, running into internal allocation overhead *)
	VAR amg:Solver; dummy:Matrix;
	BEGIN
		NEW(amg,dummy); RETURN amg.SolveNoCopy(A,b);
	END Solve;


	(*PROCEDURE {TEST} Test*; (*!to be worked out*)
	CONST TestThreshold = 0.001;
	VAR A: Matrix;  b, x, e: Vector;  error:Datatype;
	BEGIN
		A := [[3, 1, 1, 0], [1, 5, 2, 1], [2, 1, 6, 2], [1, 2, 3, 7]];  b := [1, 2, 3, 2];  (* Gauss Seidel and Jacobi require diagonally dominant matrices for guaranteed convergence *)
		x := Solve( A, b );
		e := A*x-b; error:= e+*e;
		ASSERT(error < TestThreshold, 201);
	END Test;*)

PROCEDURE Test1*;
VAR b,c: Vector;
BEGIN
	b:=[1,2,4,6,8,9,10,11];
	c:=restrictV(b);
	Out.String("b:"); Util.OutVector(c);
	b:=prolongV(c);
	Out.String("b:"); Util.OutVector(b);
END Test1;

(*
PROCEDURE {TEST} Test*;(*! to be worked out in more detail*)
CONST TestThreshold=0.0001;
VAR b,c,d, e: Vector; error:Datatype;
BEGIN
	b:=[1,2,4,6,8,9,10,11];
	c:=restrictV(b);
	d:=prolongV(c);
	e:=d-b;
	error:=e+*e;
	ASSERT(error<TestThreshold,200);
END Test;
*)


END MatrixAlgebraicMultigrid.
(*---------------------------------------------------*)
MatrixAlgebraicMultigrid.Test1
(*
MODULE MatrixDummyClient;
IMPORT Base:=MatrixBase;
TYPE Datatype=Base.Datatype;
		Vector=Base.Vector;
		Matrix=Base.Matrix;

	PROCEDURE DoProcedure;
	VAR A: Matrix;  b, x: Vector;
	BEGIN
		x := MatrixDummy.SolveXY( A, b );
	END DoProcedure;

	PROCEDURE DoObject;
	VAR A: Matrix;  b, c, d, x: Vector;  solver: Base.Solver;
	BEGIN
		solver := CreateXYSolver( A );  x := solver.Solve( b );  x := solver.Solve( c );
		solver.Init( B );  x := solver.Solve( d );
	END DoObject;

	PROCEDURE DoObjectExplicitErrorHandling;
	VAR A: Matrix;  b, c, d, x: Vector;  solver: Base.Solver;
	BEGIN
		solver := CreateXYSolver( A );  x := solver.Solve( b );
		IF solver.res = NOCONVERGENCE THEN  (*do something about it*) END;
	END DoObjectExplicitErrorHandling;

	PROCEDURE DoSpecificObject;
	VAR xySolver: XYSolver;
	BEGIN
		NEW( xySolver, A );  xySolver.SpecificActivities();  x := xySolver.Solve( b );
	END DoSpecificObject;


END MatrixDummyClient.
*)
