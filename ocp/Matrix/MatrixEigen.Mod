MODULE MatrixEigen;   (**  AUTHOR "Patrick Hunziker"; PURPOSE "";  **)

IMPORT Math := MathL, MatrixBase, MatrixPolynomEq, MatrixStandardSolvers, MatrixSVD, MatrixUtilities, Out:=KernelLog;

TYPE
	Datatype = MatrixBase.Datatype;  Matrix = MatrixBase.Matrix;  Vector = MatrixBase.Vector;

CONST

	PROCEDURE sqr( x: Datatype ): Datatype;
	BEGIN
		RETURN x * x;
	END sqr;

	PROCEDURE Eigenvalue22*( CONST A: Matrix ): Vector;   (*limitation: real case; add check for entry conditions*)
	VAR L: Vector;  l0, l1: Datatype;
	BEGIN
		ASSERT( (LEN( A ) = 2) & (LEN( A, 1 ) = 2), 100 );  NEW( L, 2 );  l0 := (A[0, 0] + A[1, 1]) / 2 + Math.sqrt( sqr( A[0, 0] + A[1, 1] ) / 4 + A[0, 1] * A[1, 0] - A[0, 0] * A[1, 1] );
		l1 := (A[0, 0] + A[1, 1]) / 2 - Math.sqrt( sqr( A[0, 0] + A[1, 1] ) / 4 + A[0, 1] * A[1, 0] - A[0, 0] * A[1, 1] );
		IF ABS( l0 ) > ABS( l1 ) THEN L[0] := l0;  L[1] := l1 ELSE L[0] := l1;  L[1] := l0 END;
		RETURN L
	END Eigenvalue22;
(*
	PROCEDURE eigenvalue33*(a11,a12,a13,a21,a22,a23,a31,a32,a33:Datatype):Vector;
	VAR detA: Datatype;
	BEGIN
		detA := a11 * a22 * a33 + a12 * a23 * a31 + a13 * a21 * a32 - a11 * a23 * a32 - a12 * a21 * a33 - a13 * a31 * a22;
		RETURN MatrixPolynomEq.Cubic( -(a11 + a22 + a33),
															   +(a11 * a22 + a22 * a33 + a11 * a33 - a12 * a21 - a13 * a31 - a23 * a32),
															   -detA );
	END eigenvalue33;
*)
	PROCEDURE Eigenvalue33*( CONST A: Matrix ): Vector;   (*limitation: real case; add check for entry conditions*)
	VAR a, b, c, d, e, f, g, h, i, detA: Datatype;
	BEGIN
		ASSERT( (LEN( A ) = 3) & (LEN( A, 1 ) = 3), 100 );  a := A[0, 0];  b := A[0, 1];  c := A[0, 2];  d := A[1, 0];  e := A[1, 1];  f := A[1, 2];  g := A[2, 0];  h := A[2, 1];  i := A[2, 2];
		detA := a * e * i + b * f * g + c * d * h - a * f * h - b * d * i - c * g * e;  RETURN MatrixPolynomEq.Cubic( -(a + e + i), +(a * e + e * i + a * i - b * d - c * g - f * h),
		-detA );   (* sign changed: impact ?? *)
	END Eigenvalue33;

	PROCEDURE Eigenvalue44*( CONST A: Matrix ): Vector;
	  (*not yet implemented. base on MatrixPolynomialEq.Mod - solution of quartic equation*)
	END Eigenvalue44;

	PROCEDURE Eigenvalues*( CONST A: Matrix ): Vector;
	BEGIN
		IF (LEN( A, 0 ) = 1) & (LEN( A, 1 ) = 1) THEN HALT( 100 )
		ELSIF (LEN( A, 0 ) = 2) & (LEN( A, 1 ) <= 2) THEN RETURN Eigenvalue22( A )
		ELSIF (LEN( A, 0 ) = 3) & (LEN( A, 1 ) <= 3) THEN RETURN Eigenvalue33( A )
			(*ELSIF (LEN(A,0) = 4) & (LEN(A,1) <= 4) THEN RETURN Eigenvalue44(A)*)  (*To Do: use direct solving of quartic equation for 4*4 matrix instead of iterative solution *)
		ELSE
			RETURN QREigen( A );   (*SLOW because not yet optimized*)
		END;
	END Eigenvalues;

	PROCEDURE QREigen( CONST A0: Matrix ): Vector;   (*QR method with shift, see below. This implementation is by far not optimal (improve convergence analysis, use householder)*)
	VAR A, M: Matrix;  s: Datatype;  i, j: SIZE;  qr: MatrixStandardSolvers.QR;  dummy: ARRAY [ * , * ] OF Datatype;
		res: Vector;
	BEGIN
		A := A0;  NEW( qr, dummy );
		FOR j := 0 TO 10 * LEN( A, 0 ) DO
			NEW( M, LEN( A, 0 ), LEN( A, 1 ) );  s := A[LEN( A, 0 ) - 1, LEN( A, 0 ) - 1];
			FOR i := 0 TO LEN( A,0 ) - 1 DO M[i, i] := s;  END;
			qr.Init( A - M );  A := qr.R * qr.Q + M;
		END;
		NEW( res, LEN( A, 0 ) );
		FOR i := 0 TO LEN( A, 0 ) - 1 DO res[i] := A[i, i];  END;
		RETURN res;
	END QREigen;

(* work in progress- not to be used

(* see http://math.fullerton.edu/mathews/n2003/QRMethodMod.html and Wikipedia: QR algorithm
 The [Graphics:Images/QRmethodMod_gr_90.gif] method works much faster on special matrices, preferably:
        (i)   symmetric  tri-diagonal,
        (ii)  Hessenberg matrices,
        (iii) symmetric  band matrices.  *)

	PROCEDURE DropEigenvalue(CONST A:Matrix):Matrix;
	CONST threshold=0.0001;
	VAR i:SIGNED32; v:Vector; B:Matrix; max:SIGNED32;
	BEGIN
		i:=0;
		max:=LEN(A)-1;
		LOOP
			IF i>=LEN(A) THEN EXIT END;
			v:=A[i]; v[i]:=0;
			IF v +* v < threshold THEN
				Out.String("Eigenvalue removed from line: "); Out.Int(i,5); Out.String("  "); MatrixUtilities.OutVector(A[i]);
				NEW(B, LEN(A,0)-1, LEN(A,1)-1);

				IF i>0  THEN B[..i-1,..i-1]:=A[..i-1,..i-1]; END;
				IF (i>0)&(i<LEN(A,0)-1) THEN
					B[..i-1,i..max-1]:=A[..i-1,i+1..max];
					B[i..max-1,..i-1]:=A[i+1..max,..i-1];
				END;
				IF i<LEN(A,0)-1 THEN B[i..max-1,i..max-1]:=A[i+1..max,i+1..max]; END;
				EXIT
			ELSE B:=A;
			END;
			INC(i);
		END;
		RETURN B
	END DropEigenvalue;

	PROCEDURE QREigen (CONST A: Matrix);
	(* works for real symmetric matrices; still slow: eliminate one eigenvalue when it is found and reduce matrix size at each step*)
	(*to do: use householder reduction to hessenberg form or similar as first step*)
	VAR qr: MatrixStandardSolvers.QR; svd: MatrixSVD.Solver; dummy,A0, A1,Q,R: Matrix; k:SIGNED32; (*needs work*)
	BEGIN
		NEW(qr,dummy);
		A0:=A;
		R:=A0;
		WHILE k<10*LEN(A,0) DO
			IF k MOD 1 = 0 THEN MatrixUtilities.OutMatrix(A0); END;

			qr.Init(A0);
			A1:=qr.Q`* A0 * qr.Q;
			A0:=A1;

			(*
			(*how to reduce matrix size*)
			qr.Init(A0);
			A1:=qr.Q`* A0 * qr.Q;
			A0:=dummy; A0:=DropEigenvalue(A1); (* to add: bookkeeping of indices of Eigenvalues *)
			A1:=dummy; A1:=A0;
			*)

			(*
			R:=A0;
			MatrixTransforms.Householder(R);
			Q:= (compute from A and R);
			A1:=Q`*A0 * Q;
			A0:=A1;
			*)
			INC(k);
		END;
		NEW(svd,A);

		MatrixUtilities.OutMatrix(svd.u);
		MatrixUtilities.OutMatrix(svd.w);
		MatrixUtilities.OutMatrix(svd.vt);
		MatrixUtilities.OutMatrix(svd.u * svd.u`);
		MatrixUtilities.OutMatrix(svd.vt`  * svd.vt);
	END QREigen;
*)
	PROCEDURE {TEST} Test*;
	CONST TestThreshold=0.0001;
	VAR svd: MatrixSVD.Solver;  A: Matrix; eigen:Vector; error: Datatype;
	BEGIN
		A := [[4, 1, 3, -2], [1, -2, 4, 1], [3, 4, 1, 2], [-2, 1, 2, 3]];  
		NEW( svd, A );
		eigen:=QREigen(A);
		error:=SUM(ABS(svd.w))-SUM(ABS(eigen));
		ASSERT( error < TestThreshold, 201); (*eigenvalues may differ in sign and ordering ..*) (*! was correct in 12/2017*)
	END Test;

	PROCEDURE Test1*;
	VAR svd: MatrixSVD.Solver;  A: Matrix;
	BEGIN
		A := [[4, 1, 3, -2], [1, -2, 4, 1], [3, 4, 1, 2], [-2, 1, 2, 3]];  Out.String( "Eigenvalues by QR method : " );  Out.Ln;  
		MatrixUtilities.OutVector( QREigen( A ) );  Out.Ln;

		Out.String( "Singular Values by SVD (differ in sign from eigenvalues for symmetric pos definite matrices): " );  Out.Ln;

		NEW( svd, A );

		MatrixUtilities.OutMatrix( svd.w );  Out.String( "Orthogonality check of u * ut in SVD: " );  Out.Ln;  
		MatrixUtilities.OutMatrix( svd.u * svd.u` );

	END Test1;

END MatrixEigen.

System.Free MatrixEigen.Test1 ~
fofPC.Compile \s * ~
fofPC.Compile \f * ~
OFormatter.Format *

For symmetric and Hermitian matrices, the eigenvalues and singular values are closely related.
A nonnegative eigenvalue,  is also a singularvalue.
The correspo nding vectors are equal to each other, u = v = x.
A negative eigenvalue, lambda < 0, must reverse its sign to become a singular value, |s|.
One of the corresponding singular vectors is the negative of the other.


Eigenvalue from QR decomposition: (souce: Matlab eigs.pdf )
The QR algorithm is based on repeated use of the QR factorization that we
described in Chapter 5, Least Squares. The letter \Q" denotes orthogonal and uni-
tary matrices and the letter \R" denotes right, or upper, triangular matrices. The
qr function in Matlab factors any matrix, real or complex, square or rectangular,
into the product of a matrix Q with orthonormal columns and matrix R that is
nonzero only its upper, or right, triangle.
Using the qr function, a simple variant of the QR algorithm, known as the
single-shift algorithm, can be expressed as a Matlab one-liner. Let A be any square
matrix. Start with
n = size(A,1)
I = eye(n,n)
Then one step of the single-shift QR iteration is given by
s = A(n,n); [Q,R] = qr(A - s*I); A = R*Q + s*I
If you enter this on one line, you can use the up arrow key to iterate. The
quantity s is the shift; it accelerates convergence. The QR factorization makes the
matrix triangular:
A - sI = QR:
Then the reverse-order multiplication RQ restores the eigenvalues because
RQ + sI = QT (A - sI)Q + sI = QT AQ;
so the new A is orthogonally similar to the original A. Each iteration erectively
transfers some \mass" from the lower to the upper triangle while preserving the
eigenvalues. As the iterations are repeated, the matrix often approaches an upper
triangular matrix with the eigenvalues conveniently displayed on the diagonal.

However, this is not very efficient; better it is, to do first a Householder reduction (leads to a hessenberg matrix) and then proceed (see wikipedia)
