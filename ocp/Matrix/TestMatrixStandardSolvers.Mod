MODULE TestMatrixStandardSolvers; (** AUTHOR ""; PURPOSE ""; *)

IMPORT Base:=MatrixBase, Solvers:=MatrixStandardSolvers, MatrixTransforms, Util:= MatrixUtilities, Out:=KernelLog;

PROCEDURE DoQR*;
VAR QR: Solvers.QR; A:Base.Matrix; b,x:Base.Vector;
BEGIN
	A:=[[1,2,3,4],[4,3,3,1],[1,2,4,3],[2,2,2,3]]; b:=[2,3,4,5];

	NEW(QR,A);
	x:=QR.Solve(b);

	(*x:=MatrixSolvers.SolveQR(A,b,res);*)

	Out.String("b:"); Out.Ln;
	Util.OutVector(b); Out.Ln;

	Out.String("x:"); Out.Ln;
	Util.OutVector(x);Out.Ln;

	Out.String("A:"); Out.Ln;
	Util.OutMatrix(A);Out.Ln;


	Out.String("A*x"); Out.Ln;
	Util.OutVector(A * x); Out.Ln;

	Out.String("Q*R"); Out.Ln;
	Util.OutMatrix(QR.Q*QR.R); Out.Ln;

	Out.String("orthogonality of Q: by checking Q*Q`"); Out.Ln;
	Util.OutMatrix(QR.Q*QR.Q`);Out.Ln;

	Out.String("upper diagonal R"); Out.Ln;
	Util.OutMatrix(QR.R); Out.Ln;
END DoQR;

PROCEDURE DoGaussJordan*;
VAR GJ: Solvers.GaussJordan; A:Base.Matrix; b,x:Base.Vector;
BEGIN
	A:=[[1,2,3,4],[4,3,3,1],[1,2,4,3],[2,2,2,3]]; b:=[2,3,4,5];

	NEW(GJ,A);
	x:=GJ.Solve(b);

	Out.String("b:"); Out.Ln;
	Util.OutVector(b); Out.Ln;

	Out.String("x:"); Out.Ln;
	Util.OutVector(x);Out.Ln;

	Out.String("A:"); Out.Ln;
	Util.OutMatrix(A);Out.Ln;

	Out.String("A*Ainv"); Out.Ln;
	Util.OutMatrix(A * GJ.Ainv); Out.Ln;

	Out.String("A*x"); Out.Ln;
	Util.OutVector(A * x); Out.Ln;
END DoGaussJordan;

PROCEDURE DoLU*;
VAR LU: Solvers.LU; A:Base.Matrix; b,x:Base.Vector;
BEGIN
	A:=[[1,2,3,4],[4,3,3,1],[1,2,4,3],[2,2,2,3]]; b:=[2,3,4,5];

	NEW(LU,A);
	x:=LU.Solve(b);

	Out.String("b:"); Out.Ln;
	Util.OutVector(b); Out.Ln;

	Out.String("x:"); Out.Ln;
	Util.OutVector(x);Out.Ln;

	Out.String("A:"); Out.Ln;
	Util.OutMatrix(A);Out.Ln;

	Out.String("A*Ainv"); Out.Ln;
	Util.OutMatrix(A * LU.Inverse()); Out.Ln;

	Out.String("A*x"); Out.Ln;
	Util.OutVector(A * x); Out.Ln;
END DoLU;


PROCEDURE DoGauss*;
VAR G: Solvers.Gauss; A:Base.Matrix; b,x:Base.Vector;
BEGIN
	A:=[[1,2,3,4],[4,3,3,1],[1,2,4,3],[2,2,2,3]]; b:=[2,3,4,5];

	NEW(G,A);
	x:=G.Solve(b);

	Out.String("b:"); Out.Ln;
	Util.OutVector(b); Out.Ln;

	Out.String("x:"); Out.Ln;
	Util.OutVector(x);Out.Ln;

	Out.String("A:"); Out.Ln;
	Util.OutMatrix(A);Out.Ln;

	Out.String("A*x"); Out.Ln;
	Util.OutVector(A * x); Out.Ln;
END DoGauss;

PROCEDURE DoCholesky*;
VAR C: Solvers.Cholesky; A:Base.Matrix; b:Base.Vector;
BEGIN
	A:=[[1,2,3,4],[4,3,3,1],[1,2,4,3],[2,2,2,3]]; b:=[2,3,4,5]; (*NOT POSITIVE DEFINITE*)
	(* TRY NOW WITH POSITIVE DEFINITE MATRIX !! *)

	NEW(C,A);

	Out.String("L:"); Out.Ln;
	Util.OutMatrix(C.L);Out.Ln;

	Out.String("L*C.L`"); Out.Ln;
	Util.OutMatrix(C.L * C.L`); Out.Ln;
END DoCholesky;
(*
PROCEDURE DoGaussAugmented*;
VAR A,B: Base.Matrix; v:Base.Vector; res,i,j:SIGNED32;
BEGIN
	A:=[[1,2,3,4,2],[4,3,3,1,3],[1,2,4,3,4],[2,2,2,3,5]];;
	Util.OutMatrix(A);
	MatrixTransforms.GaussAugmented(A);
	Util.OutMatrix(A);
END DoGaussAugmented;*)


PROCEDURE DoGaussElim*;
VAR A: Base.Matrix;
BEGIN
	A:=[[1,2,3,4],[4,3,3,1],[1,2,4,3],[2,2,2,3]];
	Util.OutMatrix(A);
	MatrixTransforms.Gauss(A);
	Util.OutMatrix(A);
END DoGaussElim;

(*
PROCEDURE DoQR2*;
VAR A,B,Ainv:Matrix; b,x:Vector; res:SIGNED32; index: IntVector;
BEGIN
	A:=[[1,2,3,4],[4,3,3,1],[1,2,4,3],[2,2,2,3]]; b:=[2,3,4,5];
	B:=A;

	x:=MatrixSolvers.QR(A,b,res);

	Out.Int(res,6);Out.Ln;
	out(b); Out.Ln;
	out(x);Out.Ln;
	out(index); Out.Ln;
	outM(B);Out.Ln;
	out(B*x); Out.Ln;
END DoQR2;
*)
PROCEDURE {TEST}Test*;
VAR LU: Solvers.LU; QR:Solvers.QR; G: Solvers.Gauss; GJ: Solvers.GaussJordan; A:Base.Matrix; b,x,e:Base.Vector; error:REAL;
BEGIN
	A:=[[1,2,3,4],[4,3,3,1],[1,2,4,3],[2,2,2,3]]; b:=[2,3,4,5];
	NEW(LU,A);
	x:=LU.Solve(b);
	e:=A*x-b;
	error:=e+*e;
	ASSERT(error<0.0001, 201);
	
	A:=[[1,2,3,4],[4,3,3,1],[1,2,4,3],[2,2,2,3]]; b:=[2,3,4,5];
	NEW(QR,A); (*! needs repair. Same code had correct results with Compiler 2017*)
	x:=QR.Solve(b);
	e:=A*x-b;
	error:=e+*e;
	ASSERT(error<0.0001, 202); (*note: was correct with older releases, is now defunct with current release, without library change*)

	A:=[[1,2,3,4],[4,3,3,1],[1,2,4,3],[2,2,2,3]]; b:=[2,3,4,5];
	NEW(G,A);
	x:=G.Solve(b);
	e:=A*x-b;
	error:=e+*e;
	ASSERT(error<0.0001, 203); (*note: was correct with older releases, is now defunct with current release, without library change*)

	A:=[[1,2,3,4],[4,3,3,1],[1,2,4,3],[2,2,2,3]]; b:=[2,3,4,5];
	NEW(GJ,A);
	x:=GJ.Solve(b);
	e:=A*x-b;
	error:=e+*e;
	ASSERT(error<0.0001, 204); (*note: was correct with older releases, is now defunct with current release, without library change*)
END Test;

END TestMatrixStandardSolvers.

SystemTools.Free
TestMatrixStandardSolvers
MatrixStandardSolvers
MatrixTransforms~
TestMatrixStandardSolvers.DoLU
TestMatrixStandardSolvers.DoQR
TestMatrixStandardSolvers.DoGaussJordan
TestMatrixStandardSolvers.DoGauss
TestMatrixStandardSolvers.DoGaussAugmented~
TestMatrixStandardSolvers.DoGaussElim~
TestMatrixStandardSolvers.DoCholesky
TestMatrixStandardSolvers.Test
MatrixStandardSolvers MatrixUtilities~
