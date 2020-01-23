MODULE MatrixTransforms;   (**  AUTHOR "Patrick Hunziker"; PURPOSE "MatrixTransformations and decompositions";  **)
(*or should this be named "Matrix Factorization, http://fsmat.at/~bkabelka/math/numerik/num1/22.htm (Pseudocode) and contain Gauss, LU, LR, Householder, QR, Choletzky*)

IMPORT MathL, MatrixBase (*, KernelLog, Util:=MatrixUtilities*) ;

TYPE
	Datatype* = MatrixBase.Datatype;
	Vector* = MatrixBase.Vector;
	Matrix* = MatrixBase.Matrix;

	(** The Symmetric Matrix Decomposition:  A = S1 + S2  *)
	(** S1 = (A + AT)/2 *)
	PROCEDURE SymmetricPart*( CONST A: Matrix ): Matrix;
	BEGIN
		ASSERT( LEN( A, 0 ) = LEN( A, 1 ) );  RETURN (A + A`) / 2
	END SymmetricPart;

(** S2 = (A - AT)/2 *)
	PROCEDURE SkewPart*( CONST A: Matrix ): Matrix;
	BEGIN
		ASSERT( LEN( A, 0 ) = LEN( A, 1 ) );  RETURN (A - A`) / 2
	END SkewPart;

		(** Gaussian elimination algorithm  with row pivoting; expects square matrix, transforms it into upper triangular matrix *)
	PROCEDURE Gauss*( VAR A: Matrix );   (*in-place transformation*)
	VAR i, j, k, m, n, u, maxi: SIZE;  val, max: FLOAT64; Ai, tRow: Vector;

		PROCEDURE SwapRows( I, K: SIZE );
		BEGIN
			tRow := A[I];  A[I] := A[K];  A[K] := tRow;
		END SwapRows;

	BEGIN
		m := LEN( A, 0 );  n := LEN( A, 1 );  i := 0;  j := 0;
		WHILE (i < m ) & (j < n) DO
			max := A[i, j];   (*Find pivot in column j, starting in row i*)
			maxi := i;
			FOR k := i + 1 TO m - 1 DO
				val := A[k, j];
				IF ABS( val ) > ABS( max ) THEN max := val;  maxi := k END;
			END;
			IF ABS(max) >= MatrixBase.EPS THEN
				SwapRows( i, maxi );
				A[i] := A[i] / max;
				(*IF i<m-1 THEN *)
				A[i+1..] := A[i+1..] - A[i+1.., j] ** A[i];
				(*END;*)
				INC( i );
			END;
			INC( j );
		END;
	END Gauss;
(*
	(** Gaussian elimination algorithm  with row pivoting; expects augmented matrix (last column containing right hand side) resulting in A now having a reduced row echelon form *)
	PROCEDURE GaussAugmented*( VAR A: Matrix );   (*in-place transformation*) (* tested ??*)
	VAR i, j, k, m, n, u, maxi: SIGNED32;  val, max: FLOAT64; Ai, tRow: Vector;

		PROCEDURE SwapRows( I, K: SIGNED32 );
		VAR J: SIGNED32;
		BEGIN
			tRow := A[I];  A[I] := A[K];  A[K] := tRow;
		END SwapRows;

	BEGIN
		m := LEN( A, 0 );  n := LEN( A, 1 );  i := 0;  j := 0;
		WHILE (i < m ) & (j < n) DO
			max := A[i, j];   (*Find pivot in column j, starting in row i*)
			maxi := i;
			FOR k := i + 1 TO m - 1 DO
				val := A[k, j];
				IF ABS( val ) > ABS( max ) THEN max := val;  maxi := k END;
			END;
			IF ABS(max) >= MatrixBase.EPS THEN  (*or eps ?*)
				SwapRows( i, maxi );
				A[i] := A[i] / max;
				(*FOR u := 0 TO m - 1 DO
					IF u # i THEN A[u] := A - A[i] * A[u, j];  END;
				END;*)
				Ai:=A[i];
				A := A - A[.., j] ** A[i];
				A[i]:=Ai;
				INC( i );
			END;
			INC( j );
		END;
	END GaussAugmented;
*)
(*
			(** produce upper Hessenberg Matrix (zeros below first subdiagonal) using Gaussian elimination algorithm  with row pivoting; expects square matrix*)
	PROCEDURE Hessenberg*( VAR A: Matrix );   (*in-place transformation*)  (*NOT FINISHED - currently just Gauss Elimination - NOT TESTED*)
	VAR i, j, k, m, n, u, maxi: SIGNED32;  val, max: FLOAT64; Ai, tRow: Vector;

		PROCEDURE SwapRows( I, K: SIGNED32 );
		VAR J: SIGNED32;
		BEGIN
			tRow := A[I];  A[I] := A[K];  A[K] := tRow;
		END SwapRows;

	BEGIN
		m := LEN( A, 0 );  n := LEN( A, 1 );  i := 0;  j := 0;
		WHILE (i < m ) & (j < n) DO
			max := A[i, j];   (*Find pivot in column j, starting in row i*)
			maxi := i;
			FOR k := i + 1 TO m - 1 DO
				val := A[k, j];
				IF ABS( val ) > ABS( max ) THEN max := val;  maxi := k END;
			END;
			IF ABS(max) >= MatrixBase.EPS THEN
				SwapRows( i, maxi );
				A[i] := A[i] / max;
				A[i+1..] := A[i+1..] - A[i+1.., j] ** A[i] ;
				INC( i );
			END;
			INC( j );
		END;
	END Hessenberg;
*)
	(** stabilized Gram-Schmidt process yielding orthogonal (column) vectors from a set of  linearly independent vectors.
Gram-Schmidt is less stable then Householder, but yields  orthogonalized rows early on (after n iteration for vector n). Cost is 2*k*n*n FLOPS.
Householder is more stable but yields results only at the end *)
(** n < 0 implies 'all' *)

	PROCEDURE GramSchmidt*( VAR A: Matrix;  n: SIZE );   (*tested - OK*)
	VAR j, i, k: SIZE;  ss: FLOAT64;
	BEGIN
		IF n < 0 THEN n := LEN( A,0 ) END;
		FOR j := 0 TO n - 1 DO
			FOR i := 0 TO j - 1 DO
				A[j] := A[j] - (A[j] +* A[i] * A[i]);   (*remove component in direction Ai*)
			END;
			A[j] := A[j] / MathL.sqrt( A[j] +* A[j] );  (* todo: see MatrixSolvers.QRDecomp for how to catch a nonpositive result here*)
		END;
	END GramSchmidt;

(*QR by modified Gram Schmidt algorithm, avoids the numerical loss of orthogonality with the classical approach.
input: A; output: Q packed in A; upper diagonal R*)
	PROCEDURE QRGramSchmidt*( VAR A, R: Matrix;  n: SIZE );   (*tested - OK*)
	VAR j, i, k: SIZE;  r: FLOAT64;
	BEGIN
	(*ASSERT(sizes are correct)*)  (*to do*)
		R := 0;
		IF n < 0 THEN n := LEN( A,0 ) END;
		FOR i := 0 TO n - 1 DO
			R[i, i] := MathL.sqrt( A[i] +* A[i] );   (* todo: see MatrixSolvers.QRDecomp for how to catch a nonpositive result here*)
			A[i] := A[i] / R[i, i];
			FOR j := i + 1 TO n - 1 DO  (*to do: this can be rewritten using matrix multiplications - however, there is some strange size mismatch error when doing that*)
				R[i, j] := A[j] +* A[i];
				A[j] := A[j] - R[i, j] * A[i];
			END;
		END;
	END QRGramSchmidt;

	PROCEDURE House( CONST x: Vector;  n: SIZE ): Vector;
	VAR v: Vector;
	BEGIN
		NEW( v, LEN( x,0 ) );
		v[0] := x[0] + sign( x[0] ) * MathL.sqrt( x +* x );   (*  *)
		v[1..] := x[1..];  v := v / MathL.sqrt( v +* v );  RETURN v
	END House;

	(**
The Householder transformation in 3-dimensional space is the reflection of a vector in a plane.
In general Euclidean space it is a linear transformation that describes a reflection in a hyperplane (containing the origin).
The Householder transformation is usable for QR decomposition; only the upper diagonal R is returned; Q can be retrieved from the procedure below if ever needed.
For solving rectangular systems, Householder QR is considerably more stable than LU, but only a little more expensive. it is used for the Matlab \ operator *)
(*Precondition: rectangular matrix; Postcondition: A contains R, the upper diagonal matrix; Q is equal to ... *)
	PROCEDURE Householder*( VAR A: Matrix );
	VAR k, m, n: SIZE;  v, v1: Vector;
	BEGIN
		m := LEN( A, 0 );  n := LEN( A, 1 );
		FOR k := 0 TO MIN( m - 1, n ) - 1 DO
			NEW( v, m - k );  (* could be done in-place *)
			v := House( A[k..m - 1, k], m - k );
			A[k..m - 1, k..n - 1] := A[k..m - 1, k..n - 1] - 2 * v ** (v * A[k..m - 1, k..n - 1]); (* remove temp memory allocations*)
		END;
	END Householder;

	(*how to extract least squares from the algorithm:
compute residual:
	d:=QT[m..n-1] * b;
*)

	(*
add backsubstitution to householder:
	FOR k:=0 TO n-1 DO
		b[k..m-1]:=b[k..m-1] - 2 v(v` * b[k..m-1])
	END;
*)

(* ???? not yet correct...
	(* how to extract Q from the algorithm *)
	PROCEDURE HouseholderQ* (VAR A: Matrix);
	VAR x: ARRAY [*] OF FLOAT64; k, m, n: SIGNED32;
	BEGIN
		m:=LEN(A,0); n:=LEN(A,1);
		NEW(x,n); x:=1;
		FOR k:=n-1 TO 0 BY -1 DO
			x[k..m]:=x[k..m] -2 * vk * (vk` * x[k..m])
		END;
	END HouseholderQ;
*)

	PROCEDURE sign( x: FLOAT64 ): FLOAT64;
	BEGIN
		IF x > 0 THEN RETURN 1
		ELSIF x < 0 THEN RETURN -1
		ELSIF x = 0 THEN RETURN 0
		ELSE  (*NaN ?*) HALT( 100 );
		END;
	END sign;

	(** Givens rotation G*A with the Givens matrix G=[[c,s],[-s,c]] on the matrix A introduces a zero and modifies only two rows of the matrix.
The Givens rotation is [[c,s],[-s,c]]*[[a],[b]]=[[r],[0]]  ; here the constraints 'numerical stability' and r>=0 are used; see http://en.wikipedia.org/wiki/Givens_rotation
A full Givens Rotation Matrix with rotation theta, where c=cos(theta) and s=sin(theta), looks like
[1	 0	0	0	0]
[0	 c	s	0	0]
[0	-s	c	0	0]
[0	 0	0	1	0]
[0	 0	0	0	1]
*)
(** parameters: 'ab' contains the 2 entries: A[row-1..row,col] of the target matrix; the givens rotation will set these elements to [r,0] *)
	PROCEDURE GivensMatrix*( CONST ab: Vector; VAR G: Matrix );   (**tested - OK*)
	VAR u, t: FLOAT64;  a, b: FLOAT64;  c, s, r: FLOAT64;
	BEGIN
		a := ab[0];  b := ab[1];
		IF b = 0 THEN
			IF a > 0 THEN c := 1 ELSE c := -1 END;
			s := 0;  r := ABS( a )
		ELSIF a = 0 THEN
			c := 0;
			IF b > 0 THEN s := 1 ELSE s := -1 END;
			r := ABS( b )
		ELSIF ABS( b ) > ABS( a ) THEN
			t := a / b;
			IF b > 0 THEN u := MathL.sqrt( 1 + t * t ) ELSE u := -MathL.sqrt( 1 + t * t ) END;
			s := 1 / u;  c := s * t;  r := b * u
		ELSE
			t := b / a;
			IF a > 0 THEN u := MathL.sqrt( 1 + t * t ) ELSE u := -MathL.sqrt( 1 + t * t ) END;
			c := 1 / u;  s := c * t;  r := a * u;
		END;
		G[0, 0] := c;  G[0, 1] := s;  G[1, 0] := -s;  G[1, 1] := c;
	END GivensMatrix;

(** applies Givens Rotation GA to set element i,j of Matrix A to zero *)
	PROCEDURE GivensRotation*( VAR A: Matrix;  i, j: SIGNED32 );
	VAR c, s, r: FLOAT64;  B: Matrix;
		G: ARRAY [ 2, 2] OF FLOAT64;
	BEGIN
		GivensMatrix( A[i - 1..i, j], G );
		(*A[i-1..i]:= G * A[i-1..i];*)  (*here is a logical/compiler implementation problem: overwriting of second line; upon debugginf of compiler, variable B should be redundant*)
		B := G * A[i - 1..i];  A[i - 1..i] := B;
	END GivensRotation;

PROCEDURE {TEST} DoGaussElim*;
VAR A: MatrixBase.Matrix; 
BEGIN
	A:=[[1,2,3,4],[4,3,3,1],[1,2,4,3],[2,2,2,3]];
	(*KernelLog.String("before "); KernelLog.Ln; Util.OutMatrix(A);*)
	Gauss(A);
	(*KernelLog.String("after "); KernelLog.Ln;	Util.OutMatrix(A);*)
	ASSERT(TRUE,200); (*! correctness not yet tested here, only runtime behaviour *)
END DoGaussElim;

END MatrixTransforms.

MatrixTransforms.DoGaussElim
SystemTools.Free MatrixTransforms ~

fofPC.Compile \s *
OFormatter.Format *

TYPE Householder = OBJECT
			VAR a,r,q: Matrix
			PROCEDURE & Init* (VAR A, R: Matrix);
			BEGIN
				IF A is R then in-place transformation
				ELSE COPY A -> R; then in-place transformation of R
			END Init;

			PROCEDURE Q():Matrix;
				compute Q from R and A if the A is different from R (otherwise A will at this point contain R)
			END Q;

		END Householder;
