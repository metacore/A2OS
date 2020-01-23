MODULE MatrixBase;  (**  AUTHOR "Patrick Hunziker"; PURPOSE "Base Types for Oberon 'Matrix' Library based on Felix Friedrichs enhanced compiler for arrays.";  **)

IMPORT KernelLog,Streams;

CONST
	OK* = 0;
	SINGULAR* = 1;
	NONCONVERGENCE* = 2;
	NOTPOSDEFINITE* = 3;
	NOTSQUARE* = 4;
	SIZEMISMATCH* = 5;
	NOTIMPLEMENTED* = 6;
	NILPROC* = 8;
	ERROR*=7; (** undefined error *)

TYPE
	Datatype* = FLOAT64;
	Complex*=COMPLEX64;

	Tensor* = ARRAY [?] OF Datatype;
	Hypercube* = ARRAY [*,*,*,*] OF Datatype;
	Volume* = ARRAY [*,*,*] OF Datatype;
	Matrix* = ARRAY [*,*] OF Datatype;
	Vector* = ARRAY [*] OF Datatype;
	ErrorHandler* = PROCEDURE ( code: SIGNED32; CONST text: ARRAY OF CHAR );

	(** Matrix solvers are Objects suited for matrix decomposition and solving in two steps:
	NEW(solver,A) or solver.Init(A) performs allocation and matrix decomposition;
	solver.Solve(b) solves for a particular right hand side.
	This two-step approach allows reuse of memory and avoiding reallocation when multiple problems have to be solved.
	Alternatively, a one-step solution of a linear system can be done by using the  x:=SolveXY(A,b) procedure call *)

	Solver* = OBJECT  (** generic template*)
	VAR res*: SIGNED32;
		handleError*: ErrorHandler;
		x*: Vector;   (** solution vector; can be initialized with approximate solution*)

		PROCEDURE & Init*( CONST A: Matrix );   (** Can be called with zero length matrix to generate generic kind of solver; involves copying of A which remains unchanged; can be initialized with matrix later*)
		BEGIN
			handleError := HandleError;   (*default error handler*)
			res := OK;
			IF LEN( A, 0 ) > 0 THEN
			(*alloc if not yet fitting datastructures available*)
				(*decompose*)
				HALT( 100 );   (* specific implementation needed for &Init() *)
			END;
		END Init;

		PROCEDURE Solve*( CONST b: Vector ): Vector;   (** generic parameterless solving *)
		BEGIN
			HALT( 100 );   (* specific implementation needed for Solve() *)
			IF (res # OK) & (handleError # NIL ) THEN handleError( res, "no convergence" ) END;
			RETURN x;
		END Solve;

		PROCEDURE SolveNoCopy*( VAR A: Matrix;  CONST b: Vector ): Vector;   (** generic parameterless solving; A may in this case be modified in the process *)
		BEGIN
			HALT( 100 );   (* specific implementation needed for Solve() *)
			IF (res # OK) & (handleError # NIL ) THEN handleError( res, "no convergence" ) END;
			RETURN x;
		END SolveNoCopy;

	END Solver;

VAR
	EPS-: FLOAT64;

	PROCEDURE SolveGeneric*( VAR A: Matrix;  CONST b: Vector ): Vector;   (** example of procedural interface to solvers *)
	END SolveGeneric;

	PROCEDURE CreateGenericSolver*( VAR A: Matrix ): Solver;   (** Example of factory procedure*)
	VAR solver: Solver;
	BEGIN
		NEW( solver, A );  RETURN solver;
	END CreateGenericSolver;

	PROCEDURE HandleError*( code: SIGNED32;  CONST text: ARRAY OF CHAR );   (* default error handler *)
	BEGIN
		KernelLog.Enter;  KernelLog.String( "Matrix error " );  KernelLog.Int( code, 6 );  KernelLog.String( ": " );
		KernelLog.String( text );  KernelLog.Ln;  KernelLog.Exit;
	END HandleError;

	PROCEDURE ComputeEps( ): FLOAT32;   (*binary: last mantissa of FLOAT32 number*)
	VAR x, y: FLOAT32;
	BEGIN
		x := 1;
		LOOP
			y := 1 + x;
			IF y = 1 THEN RETURN 2 * x END;
			x := x / 2;
		END;
	END ComputeEps;

	PROCEDURE ComputeEpsL( ): FLOAT64;   (*binary: last mantissa of FLOAT64 number*)
	VAR x, y: FLOAT64;
	BEGIN
		x := 1;
		LOOP
			y := 1 + x;
			IF y = 1 THEN RETURN 2 * x END;
			x := x / 2;
		END;
	END ComputeEpsL;

	PROCEDURE WriteLVector*(W:Streams.Writer; CONST v:Vector);
	VAR i:SIZE;
	BEGIN
		FOR i:=0 TO LEN(v,0)-1 DO
			W.RawLReal(v[i]);
		END;
		W.Update;
	END WriteLVector;

	PROCEDURE WriteLMatrix*(W:Streams.Writer; CONST m:Matrix);
	VAR i:SIZE;
	BEGIN
		FOR i:=0 TO LEN(m,0)-1 DO
			WriteLVector(W,m[i])
		END;
		W.Update;
	END WriteLMatrix;




	PROCEDURE ReadLVector*(R:Streams.Reader; VAR v:Vector);
	VAR i:SIZE;
	BEGIN
		FOR i:=0 TO LEN(v,0)-1 DO
			R.RawLReal(v[i]);
		END;
	END ReadLVector;

	PROCEDURE ReadLMatrix*(R:Streams.Reader; VAR m:Matrix);
	VAR i:SIZE;
	BEGIN
		FOR i:=0 TO LEN(m,0)-1 DO
			ReadLVector(R,m[i])
		END;
	END ReadLMatrix;

	BEGIN
	IF SIZEOF( Datatype ) = 4 THEN EPS := ComputeEps() ELSE EPS := ComputeEpsL();  END;
END MatrixBase.


fofPC.Compile  \s *
OFormatter.Format *
SystemTools.Free  MatrixStandardSolvers MatrixBase ~
SystemTools.FreeDownTo MatrixBase~

MatrixBase.Test~