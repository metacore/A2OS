MODULE MatrixProjections;   (**  AUTHOR "Patrick Hunziker"; PURPOSE "Projection of vectors, speces and data on vectors and subspaces";  **)

IMPORT MatrixBase, MatrixSVD, Util:= MatrixUtilities, MathL;

TYPE
	Datatype = MatrixBase.Datatype;
	Matrix = MatrixBase.Matrix;
	Vector = MatrixBase.Vector;

CONST
	(* orthogonal projection of vector a on vector b, resulting in a vector in direction of b *)
	PROCEDURE ProjectVector*(CONST a,b: Vector):Vector;
	VAR a1:Datatype; b0:Vector;
	BEGIN
		b0:= b / MathL.sqrt(b+*b); (*unit vector*)
		a1:=a+*b0; (*|a|*)
		RETURN a1*b0
	END ProjectVector;

	(* orthogonal projection of a number of row vectors a on a vector b, resulting in a number of row vectors in direction of b *)
	PROCEDURE ProjectVectorsOnVector*(CONST a:Matrix; CONST b: Vector):Matrix;
	VAR a1:Vector; b0:Vector;
	BEGIN
		b0:= b / MathL.sqrt(b+*b); (*unit vector*)
		a1:=a*b0; (*  *)
		RETURN a1**b0
	END ProjectVectorsOnVector;

	(*change of basis of data A (row vectors) to new basis V(column vectors are basis vectors of new basis. Result is expressed in new basis*)
	PROCEDURE ChangeOfBasis*(CONST A:Matrix; CONST V: Matrix):Matrix;
	BEGIN
		RETURN V * A
	END ChangeOfBasis;


	(* project a matrix from data(row vectors of A) to a subspace defined by a matrix V, whereby the column vectors define the subspace. Result still expressed in same basis. *)
	PROCEDURE ProjectVectorsOnSubspace*(CONST X:Matrix; CONST V: Matrix; OrthonormalV:BOOLEAN):Matrix;
	VAR W: Matrix;
		BEGIN
		(* projection of vector x on subspace V(spanned by orthonormal column vectors)
			Px->v	=  V * VT * x
		i.e. in program code:
			RETURN (V*V`) * x
		how to handle matrix A with data as row vectors instead of vector x? Just by doing left instead of right multiply, because A*A` is symmetric
		*)
		IF OrthonormalV THEN	(*to do: runtime check ?*)
			RETURN X * (V*V`) (* is ? identical to (V*V`)* xi    because V*VT is symmetric, and input rows of X  need to appear in output rows, while dimensionality appears in input/output columns*)
		ELSE
			(*RETURN V * Inv(V*V`) * V * xi 		*)(*correct result for single vector*)
			(*
			W:=V * Inv(V*V`) * V;
			RETURN X * W`; (*?? is this correct?*)
			*)
			HALT(200); (*implementation unfinished*)
		END;
		(*postcondition: RESULT contains sample vectors in rows, in new subspace *)
	END ProjectVectorsOnSubspace;

	(*remove variability of data in direction given by vector; is related to projection to subspace*)
	PROCEDURE EliminateDimension*(CONST a:Matrix; CONST b: Vector):Matrix;
	VAR invb: Vector; a1, residual: Matrix; i:SIGNED32;
	BEGIN
		a1:=ProjectVectorsOnVector(a,b);
		residual := a-a1;
		RETURN residual
	END EliminateDimension;

	(* analytical geometry.
	a plane is defined by u and v;
	compute projection of x on u, and of x on u, and add the two components to yield the projection*)
	PROCEDURE ProjectPointOnPlane(CONST x,u,v: Vector):Vector;
	END ProjectPointOnPlane;

	(*projection on nonorthogonal subspace:
	1) Gram-Schmidt orthogonalization, then
	2) orthogonal projection
	*)

	(*
	using homogenous coordinates, each orthogonal projection can be represented as a simple matrix vector product
	*)


	PROCEDURE Test*;
	VAR a,b,c:Vector; A,B,C: Matrix;
	BEGIN
		a:=[3,2]; b:=[1,0]; Util.OutVector(ProjectVector(a,b));
		a:=[3,2]; b:=[0,1]; Util.OutVector(ProjectVector(a,b));
		a:=[3,2]; b:=[1,1]; Util.OutVector(ProjectVector(a,b));
		a:=[3,2]; b:=[2,-3]; Util.OutVector(ProjectVector(a,b));

		A:=[[3,2],[3,0],[0,2],[2,-3]];
		b:=[2,-3];
		Util.OutMatrix(ProjectVectorsOnVector(A,b));

		B:=EliminateDimension(A,b);
		Util.OutMatrix(B);

		Util.OutMatrix(ProjectVectorsOnVector(B,b));
	END Test;



END MatrixProjections.

SystemTools.Free MatrixProjections~
MatrixProjections.Test ~
fofPC.Compile \s * ~
fofPC.Compile \f * ~
OFormatter.Format *

