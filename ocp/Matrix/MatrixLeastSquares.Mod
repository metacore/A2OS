MODULE MatrixLeastSquares;   (**  AUTHOR "Patrick Hunziker"; PURPOSE "compute least squares solution from linear system of equation";  **)

IMPORT MatrixBase, MatrixStandardSolvers, MatrixSVD, MatrixUtilities, KernelLog;

TYPE
	Matrix = MatrixBase.Matrix;  Vector = MatrixBase.Vector;


	LeastSquares* = OBJECT (MatrixBase.Solver) (* generic approach, dispatches fitting solver, *)
	VAR qr: LeastSquaresQR;
		svd: LeastSquaresSVD;

		PROCEDURE & Init*( CONST A: Matrix );
		BEGIN
			IF LEN(A,0)=0 THEN (*wait*)
			ELSIF LEN(A,0)>LEN(A,1) THEN NEW(qr,A)  (* inefficient reallocation*)
			ELSE NEW(svd,A)  (* inefficient reallocation*)
			END;
		END Init;

		PROCEDURE Solve*( CONST b: Vector ): Vector;
		BEGIN
			IF qr#NIL THEN RETURN qr.Solve(b)
			ELSIF svd#NIL THEN RETURN svd.Solve(b)
			ELSE HALT(200)
			END;
		END Solve;
		(*
		PROCEDURE SolveMultiple*(CONST B:Matrix):Matrix;
		BEGIN
			IF qr#NIL THEN RETURN qr.SolveMultiple(B) (* Not yet implemented in MatrixStandardSolvers.Mod *)
			ELSIF svd#NIL THEN RETURN svd.SolveMultiple(B) (* Not yet implemented in MatrixSVD.Mod *)
			ELSE HALT(200);
			END;
		END SolveMultiple;
		*)

	END LeastSquares;

	(** Least Squares based on QR - prefer this in overdetermined systems; works in square and overdetermined systems *)
	(* based on
		Ax=b
		QRx=b
		Rx=Q`b => solve this using any standard solver
	*)
	LeastSquaresQR* = OBJECT (MatrixBase.Solver)
	VAR qr*: MatrixStandardSolvers.QR;   (*might be exchanged by other algorithms for QR decomposition*)
		solver*: MatrixStandardSolvers.QR;   (*can be exchanged by other solver for linear systems*)

		PROCEDURE & Init*( CONST A: Matrix );
		BEGIN
			(*to do: check size admissibility *)
			IF qr = NIL THEN NEW( qr, A ) ELSE qr.Init( A ) END;
			IF solver = NIL THEN NEW( solver, qr.R );  ELSE solver.Init( qr.R ) END;
		END Init;

		PROCEDURE Solve*( CONST b: Vector ): Vector;
		VAR b1: Vector;
		BEGIN
			b1 := qr.Q` * b;
			RETURN solver.Solve( b1 )
		END Solve;
(*
		PROCEDURE SolveMultiple*( CONST B:Matrix): Matrix;
		VAR B1: Matrix;
		BEGIN
			B1 := qr.Q` * B;
			RETURN solver.SolveMultiple( B1 )		(* Not yet implemented in MatrixStandardSolvers.Mod *)
		END SolveMultiple;
*)
	END LeastSquaresQR;

	(** Least Squares based on SVD - prefer this in underdetermined systems; works in under/overdetermined and square systems and works in ill-conditioned systems *)
	(*
Ax=b
U W V x=b;
Vi  Wi Ui U W V x = Vi  Wi Ui b;
x = Vi  Wi Ui b;
*)
TYPE
	LeastSquaresSVD* = OBJECT (MatrixBase.Solver)
	VAR svd: MatrixSVD.Solver;

		PROCEDURE & Init*( CONST A: Matrix );
		BEGIN
			NEW( svd, A );
		END Init;

		PROCEDURE Solve*( CONST b: Vector ): Vector;
		VAR b1: Vector;
		BEGIN
			b1 := svd.vt * svd.w * svd.u` * b;  (*to do: avoid temporary memory allocation here*)
			RETURN b1
		END Solve;
(*
		PROCEDURE SolveMultiple*( CONST B:Matrix): Matrix;
		VAR B1: Matrix;
		BEGIN
			B1 := svd.vt * svd.w * svd.u` * B;
			RETURN solver.SolveMultiple( B1 ) (* Not yet implemented in MatrixStandardSolvers.Mod *)
		END SolveMultiple;
*)
	END LeastSquaresSVD;

(* Markovsky; Overview of total least-squares methods. Signal Processing 2007; 87,2283-2302*)
(** Total leasts squares are tricky in that they do not always have a unique solution or a solution at all, and in some situations the results given by the algorithm are not the true TLS solution. See
IVETA HNETYNKOVA, MARTIN PLESINGER, DIANA MARIA SIMA, ZDENIK STRAKO,SABINE VAN HUFFEL: THE TOTAL LEAST SQUARES PROBLEM IN AX . B: A NEW CLASSIFICATION WITH THE RELATIONSHIP TO THE CLASSICAL WORKS *)
TYPE TotalLeastSquares* = OBJECT  (MatrixBase.Solver) (* tested for Vector b and single-column A; not yet tested for Matrix B and multicolumn A*)
		VAR A:Matrix;
			dC-, C-:Matrix; (* correction matrix dC, matrix approximation C *)
			svd-: MatrixSVD.Solver;
			lu:MatrixStandardSolvers.LU;

		PROCEDURE &Init*(CONST A: Matrix);
		BEGIN
			SELF.A:=A;
		END Init;

		PROCEDURE Solve*(CONST b:Vector):Vector;
		VAR B,X: Matrix;
		BEGIN
			NEW(B,LEN(b,0),1);
			B[..,0]:=b;
			X:=SolveMultiple(B);
			RETURN X[..,0]
		END Solve;

		(* see Signal Processing 87 (2007) 2283-2302. Overview of total least-squares methods. Ivan Markovsky,Sabine Van Huffel *)
		PROCEDURE SolveMultiple*(CONST B:Matrix):Matrix;
		VAR M,V,diag,tmp,V22inv: Matrix;
			m,n,d: SIZE;
		BEGIN
			m:=LEN(A,0); n:=LEN(A,1); d:=LEN(B,1);
			ASSERT(LEN(A,0)=LEN(B,0));
			NEW(M, m, n+d);
			M[..,..n-1]:=A;
			M[..,n..]:=B;
			NEW(svd, M);
			V:=svd.vt`;  (*v is a unitary matrix, i.e. the inverse equals the complex conjugate; or for real matrix, the transpose equals the inverse *)

			IF svd.res=MatrixBase.OK  THEN
				NEW(lu, V[n..,n..]);
				V22inv:= lu.Inverse();

				(*optional*)
				(*
				(* compute TLS correction matrix dC*)
				NEW(diag, LEN(svd.w,0), LEN(svd.w,1));
				diag[n..,n..]:=svd.w[n..,n..];
				dC:=-svd.u* (diag*svd.vt);
				(*compute approximation C*)
				diag:=0; diag[..n-1,..n-1]:=svd.w[..n-1,..n-1];
				C:=svd.u*(diag*svd.vt);
				*)

				res:=MatrixBase.OK;
				RETURN - V[..n-1, n..] * V22inv;
			ELSE
				res:=MatrixBase.SINGULAR;
				RETURN RESULT (* no change *)
			END;
		END SolveMultiple;
	END TotalLeastSquares;

	(*to be done*)
	(*
	PROCEDURE CreateLeastSquares*( ): MatrixBase.Solver;   (*FactoryProcedure*)
	END CreateLeastSquares;
	*)

	PROCEDURE CreateLeastSquaresQR*( ): MatrixBase.Solver;   (*FactoryProcedure*)
	VAR lsqr: LeastSquaresQR;  dummy: Matrix;
	BEGIN
		NEW( lsqr, dummy );  RETURN lsqr;
	END CreateLeastSquaresQR;

	PROCEDURE CreateLeastSquaresSVD*( ): MatrixBase.Solver;   (*FactoryProcedure*) (*! replace by SVD*)
	VAR (*svd: LeastSquaresSVD; *) svd: LeastSquaresQR;   dummy: Matrix;
	BEGIN
		HALT(199);
		NEW( svd, dummy );  RETURN svd;
	END CreateLeastSquaresSVD;

	PROCEDURE CreateTotalLeastSquares*( ): MatrixBase.Solver;   (*FactoryProcedure*)
	VAR tls: TotalLeastSquares;  dummy: Matrix;
	BEGIN
		NEW( tls, dummy );  RETURN tls;
	END CreateTotalLeastSquares;

	PROCEDURE SolveLeastSquares*( VAR A: Matrix;  CONST b: Vector ): Vector;   (*direct procedural solving; simplest use, but when using repeatedly, running into internal allocation overhead *)
	VAR lsqr: LeastSquares;
	BEGIN
		NEW( lsqr, A );  RETURN lsqr.Solve( b );
	END SolveLeastSquares;

	PROCEDURE SolveLeastSquaresQR*( VAR A: Matrix;  CONST b: Vector ): Vector;   (*direct procedural solving; simplest use, but when using repeatedly, running into internal allocation overhead *)
	VAR lsqr: LeastSquaresQR;
	BEGIN
		NEW( lsqr, A );  RETURN lsqr.Solve( b );
	END SolveLeastSquaresQR;

	PROCEDURE SolveLeastSquaresSVD*( VAR A: Matrix;  CONST b: Vector ): Vector;   (*direct procedural solving; simplest use, but when using repeatedly, running into internal allocation overhead *)
	VAR svd: LeastSquaresSVD;
	BEGIN
		NEW( svd, A );  RETURN svd.Solve( b );
	END SolveLeastSquaresSVD;

	PROCEDURE SolveTotalLeastSquares*( VAR A: Matrix;  CONST b: Vector ): Vector;   (*direct procedural solving; simplest use, but when using repeatedly, running into internal allocation overhead *)
	VAR tls: TotalLeastSquares;
	BEGIN
		NEW( tls, A );  RETURN tls.Solve( b );
	END SolveTotalLeastSquares;

	(** how to use *)
	PROCEDURE TestQR*;  (*to be removed later*)
	VAR A: Matrix;  b, x: Vector;  lsqr: LeastSquaresQR;
	BEGIN
		(*A := [[1, 4, 2, 3, 1], [0, 2, 4, 4, 3], [5, 4, 3, 2, 4], [1, 1, 4, 2, 3], [2, 1, 1, 3, 2], [4, 2, 3, 1, 2]];
		b := [1, 2, 3, 4, 5, 6];  *)
		A:= [[1,4,2,3,1],
			[0,2,4,4,3],
			[5,4,3,2,4],
			[1,1,4,2,3],
			[2,1,1,3,2]];
		b:=[1,2,3,4,5];
		NEW( lsqr, A );
		x := lsqr.Solve( b );
		MatrixUtilities.OutVector( x );
		MatrixUtilities.OutVector( A * x );
		MatrixUtilities.OutVector( A * x - b);
	END TestQR;

	PROCEDURE TestSVD*;  (*to be removed later*)
	VAR A: Matrix;  b, x: Vector;  lssvd: MatrixSVD.Solver; (* lssvd: LeastSquaresSVD;  *)
	BEGIN
	(*A:= [[1,4,2,3,1],	(*underdetermined system m<n *)
				[0,2,4,4,3],
				[5,4,3,2,4],
				[1,1,4,2,3]
			];
		b:=[1,2,3,4(*,5,6*)];
		*)
		(*A:= [[1,4,2,3,1],	(*overdetermined system m>n*)
				[0,2,4,4,3],
				[5,4,3,2,4],
				[1,1,4,2,3],
				[2,1,1,3,2],
				[4,2,3,1,2]
			];
		b:=[1,2,3,4,5,6];
		*)
		A := [[1, 4, 2, 3, 1], [0, 2, 4, 4, 3], [5, 4, 3, 2, 4], [1, 1, 4, 2, 3], [0, 0, 0, 0, 0]];  (*ill-posed square system *)
		b := [1, 2, 3, 4, 0];
		NEW( lssvd, A );
		x := lssvd.Solve( b );
		MatrixUtilities.OutVector( x );
		MatrixUtilities.OutVector( A * x );
		MatrixUtilities.OutVector( A * x -b);
	END TestSVD;

	PROCEDURE TestTLS*;  (*to be removed later*)
	VAR A,B,X,M: Matrix;  b,c, x: Vector; s: FLOAT64;  tls: TotalLeastSquares;
	BEGIN
		A:=[[0],
			[1.1],
			[1.9],
			[3.05],
			[4]];
		b:=[0,1,2,3,4];

		(*A:= [[1,4,2,3,1],
			[0,2,4,4,3],
			[5,4,3,2,4],
			[1,1,4,2,3],
			[2,1,1,3,2]];
		b:=[1,2,3,4,5];
		*)

		(*
		A := [[1, 4, 2, 3, 1], [0, 2, 4, 4, 3], [5, 4, 3, 2, 4], [1, 1, 4, 2, 3], [0, 0, 0, 0, 0]];  (*ill-posed square system *)
		b := [1, 2, 3, 4, 0];
		*)
		NEW( tls, A );
		x := tls.Solve( b );
		KernelLog.String("TLS Vector result: "); KernelLog.Int(tls.res,0); KernelLog.Ln;
		MatrixUtilities.OutVector( x );
		MatrixUtilities.OutVector( A * x );
		MatrixUtilities.OutVector( A * x -b);
		MatrixUtilities.OutVector([( A * x -b)+*( A * x -b)]);


		(*A:=[[0,0.1],
			[1.1,1.05],
			[1.9, 2.1],
			[3.05, 3.0],
			[4,4.1]];  *)(* I have not yet understood the behaviour in this case*)
		A:=[[0],
			[1.1],
			[1.9],
			[3.05],
			[4]];
		B:=[[0],[1],[2],[3],[4]];

		NEW( tls, A );
		X := tls.SolveMultiple( B );
		KernelLog.String("TLS Matrix result: "); KernelLog.Int(tls.res,0); KernelLog.Ln;
		MatrixUtilities.OutMatrix( X );
		MatrixUtilities.OutMatrix( A * X );
		MatrixUtilities.OutVector([ (A * X -B)+*( A * X -B)]);
	END TestTLS;


END MatrixLeastSquares.

SystemTools.FreeDownTo MatrixLeastSquares MatrixStandardSolvers~
MatrixLeastSquares.TestQR
MatrixLeastSquares.TestSVD
MatrixLeastSquares.TestTLS


==================================
Algorithms for Least Squares Computations:
----------------------------------

QR for least squares computation:
using QR:
	Ax=b is an overdetermined system	 with A[m,n], x[n], b[m];  and m>n

	A=QR is the QR decomposition		with Q[m,n] and R[n,n]; Q is orthonormal and R is upper diagonal

	QRx=b follows from above
	QTQRx =QTb	follows from above
	Rx=QTb 	remains and can be solved using standard techniques to get a least squares solution in x

SVD for least squares computation in an underdetermined system


Krylov Solvers for least squares computation


Total least squares computation







PROCEDURE Householder

add backsubstitution to householder:
	FOR k:=0 TO n-1 DO
		b[k..m-1]:=b[k..m-1] - 2 v(v` * b[k..m-1])
	END;

compute residual:
	d:=QT[m..n-1] * b;


	(*-------------using QR ----------*)



END MatrixLeastSquares.

