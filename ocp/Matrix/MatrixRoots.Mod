MODULE MatrixRoots; (** AUTHOR "PH"; PURPOSE "compute square root etc of matrices"; *)
(*computing the square root of matrices. see wikipedia: "Square root of a matrix" *)

IMPORT MatrixBase, MatrixUtilities, MatrixStandardSolvers;

CONST threshold=0.0001;

TYPE
	Datatype=MatrixBase.Datatype;
	Matrix=MatrixBase.Matrix;


(*altgorithms: searching square root of A ; i.e. A power(1/2)

- by diagonalization:
D = Vinv * A * V (*diagonalize using V created from n Eigenvectros as columns*)
now, A = V * D * Vinv
sqrt(A) = V* sqrt(D) * Vinv

- by calculating the Jordan normal form, followed by a series expansion, similar to the approach used for matrix logarithm

- by Denman-Beavers square root iteration
*)

(** input: matrix A; output: R = sqrt(A), and its inverse Rinv *)
PROCEDURE SquareRoot*(CONST A: Matrix; VAR R, Rinv:Matrix); (*implemented using Denman-Beavers*)
VAR tmpR: Matrix; Inv:MatrixStandardSolvers.LU; i:SIGNED32;
BEGIN
	R:=A;
	IF (LEN(Rinv,0)#LEN(A,0)) OR (LEN(Rinv,1)#LEN(A,1))THEN NEW(Rinv,LEN(A,0),LEN(A,1)); END;
	MatrixUtilities.Identity(Rinv);
	NEW(Inv,Rinv);
	i:=0;
	REPEAT
		Inv.Init(Rinv);
		tmpR:=R+Inv.Inverse(); tmpR:=tmpR/2;
		Inv.Init(R);
		Rinv:=Rinv+Inv.Inverse(); Rinv:=Rinv/2;
		R:=tmpR;
		INC(i);
	UNTIL (sumofsquares(R*R-A) < threshold) OR (i>30) ; (*To do: better/cheaper termination criteria*)
	RETURN
END SquareRoot;

PROCEDURE sumofsquares(CONST A:Matrix):Datatype;
BEGIN
	RETURN A +* A
END sumofsquares;

PROCEDURE {TEST} Test*;
CONST TestThreshold=0.0001;
VAR A,R,Rinv, E: Matrix; error:Datatype;
BEGIN
	A:=[[6,2,3,1],[1,5,2,2],[1,2,7,4],[2,2,3,8]];
	SquareRoot(A,R,Rinv);
	(*MatrixUtilities.OutMatrix(A);
	MatrixUtilities.OutMatrix(R);
	MatrixUtilities.OutMatrix(R*R);*)
	E:=R*R-A;
	error:=E+*E;
	ASSERT( error < TestThreshold, 201);
END Test;



END MatrixRoots.

MatrixRoots.Test
SystemTools.Free MatrixRoots ~
