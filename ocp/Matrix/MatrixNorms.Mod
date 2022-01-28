MODULE MatrixNorms;   (**  AUTHOR "Patrick Hunziker"; PURPOSE "Norms, Determinant, Trace"  **)
 (** Norms for vectors and matrices. Cave: the "euclidian norm" is used by some for the L2 norm, by others for the J2 norm . Some inspiration from Al Freed's Oberon libraries *)
(** Version 12.3.2008 *)
IMPORT MathL, MatrixBase;

CONST HighConditionNumber*= 2000;

TYPE
	Datatype = MatrixBase.Datatype;
	Vector= MatrixBase.Vector;
	Matrix = MatrixBase.Matrix;

	(** Vector Norms *)
	PROCEDURE l2*(CONST v:Vector):Datatype;
	BEGIN
		RETURN MathL.sqrt(v +*v)
	END l2;


(** Matrix Norms *)

	(** Maximum column-sum matrix norm*)
	PROCEDURE L1*( CONST A: Matrix ): Datatype;
	VAR col: SIZE;  norm: Datatype;
	BEGIN
		norm := 0;
		FOR col := 0 TO LEN( A, 1 ) - 1 DO norm := MAX( norm, SUM( ABS( A[.. , col] ) ) );  END;
		RETURN norm;
		(*future version depending on vectorial SUM(M,i) notation*)
		(* RETURN MAX(SUM(ABS(A),1)) *)
	END L1;

(** 'natural norm' = spectal matrix norm
The spectral norm of a matrix A is the largest singular value of A or the square root of the largest eigenvalue of the positive-semidefinite matrix AA* .
Its computation can be expensive. *)
	PROCEDURE L2*( CONST A: Matrix ): Datatype;
	VAR col: SIGNED32;  norm: Datatype;
	BEGIN
		HALT( 100 );   (*not yet implemented*)
		(* to compute the largest eigenvalue, the SVD algorithm or the Householder transform can be used for example. Because only a single eigenvalue is needed, the latter may be cheaper*)
		RETURN 0;
	END L2;

(** Frobenius matrix norm: ||A||F =  V tr(ATA).  Note: ||Ax||2 # ||A||F ||x||2 *)
	PROCEDURE J2*( CONST A: Matrix ): Datatype;
	BEGIN
		RETURN MathL.sqrt( A +* A ) (*???*)
	END J2;

(** The maximum row-sum matrix norm. *)
	PROCEDURE LInf*( CONST A: Matrix ): Datatype;
	VAR row: SIZE;  norm: Datatype;
	BEGIN
		norm := 0;
		FOR row := 0 TO LEN( A, 0 ) - 1 DO norm := MAX( norm, SUM( ABS( A[row] ) ) );  END;
		RETURN norm
		(*future version depending on vectorial SUM(M,i) notation*)
		(* RETURN MAX(SUM(ABS(A),0)) *)
	END LInf;

(** The matrix trace, tr x. *)
	PROCEDURE Trace*( CONST A: Matrix ): Datatype;
	VAR sum: Datatype;  i: SIZE;
	BEGIN
		ASSERT ( LEN( A, 0 ) = LEN( A, 1 ) );
		sum := 0;
		FOR i := 0 TO LEN( A, 0 ) - 1 DO sum := sum + A[i, i] END;
		RETURN sum
	END Trace;

	(** The matrix rank  *)
	PROCEDURE Rank*( CONST A: Matrix ): SIGNED32;
	VAR sum: Datatype;  i: SIGNED32;
	BEGIN
		HALT(100);
		RETURN 0
	END Rank;

(** The matrix determinant, |A|. *)
	PROCEDURE Det*(VAR A: Matrix ): Datatype;   (*todo: this procedure changes A, probable not desirable most of the time -> rewrite *)
	VAR i, j, k: SIZE;  c, det, max: Datatype;
	BEGIN
		ASSERT ( LEN( A, 0 ) = LEN( A, 1 ) );
		(* Compute the determinant. *)
		CASE LEN( A, 0 ) OF
		| 1:   RETURN A[0, 0]
		| 2:   RETURN A[0, 0] * A[1, 1] - A[1, 0] * A[0, 1]
		| 3:   RETURN (A[1, 1] * A[2, 2] - A[2, 1] * A[1, 2]) * A[0, 0]
							    - (A[1, 0] * A[2, 2] - A[2, 0] * A[1, 2]) * A[0, 1]
							    + (A[1, 0] * A[2, 1] - A[2, 0] * A[1, 1]) * A[0, 2]
		ELSE
			max := MAX( ABS( A ) );
			IF max = 0 THEN RETURN 0 END;
			A := A / max;   (* Normalize matrix. *)
			FOR k := 0 TO LEN( A, 0 ) - 2 DO  (* Triangularize matrix. *)
				IF A[k, k] # 0 THEN
					FOR i := k + 1 TO LEN( A, 0 ) - 1 DO
						c := A[i, k] / A[k, k];
						A[i, k + 1..] := A[i, k + 1..] - c * A[k, k + 1..];  A[i, k] := c
					END
				ELSE
					RETURN 0;   (* Singular matrix. *)
				END
			END;
			(* Evaluate the determinant. *)
			det := 1;
			FOR k := 0 TO LEN( A, 0 ) - 1 DO det := det * max * A[k, k] END
		END;
		RETURN det
	END Det;

	(** compute condition number from eigenvalues *)
	PROCEDURE ConditionNumber*( CONST eigenvalues: ARRAY [?] OF Datatype ): Datatype;   (* see to be improved*)
	VAR max, min: FLOAT64;  i: SIZE;
	BEGIN
		IF DIM(eigenvalues)=1 THEN (*eigenvalues stored in vector*)
			max:=ABS(eigenvalues[0]); min:=max;
			FOR i := 1 TO LEN( eigenvalues ,0) - 1 DO
				IF ABS(eigenvalues[i]) > max THEN max := ABS(eigenvalues[i])
				ELSIF ABS(eigenvalues[i]) < min THEN min := ABS(eigenvalues[i])
				END;
			END;
		ELSE (*eigenvalues in diagonal matrix*)
			max := ABS(eigenvalues[0, 0]);  min := max;
			FOR i := 1 TO LEN( eigenvalues,0 ) - 1 DO
				IF ABS(eigenvalues[i, i]) > max THEN max := ABS(eigenvalues[i, i])
				ELSIF ABS(eigenvalues[i, i]) < min THEN min := ABS(eigenvalues[i, i])
				END;
			END;
		END;
		(*IF threshold * max < min THEN RETURN max / min *)
		IF max < HighConditionNumber * min THEN RETURN max / min (*to do: choose better value if min=0*)
		ELSE RETURN HighConditionNumber (*Reals.Ten(310) *)  (* forces IEEE code  '+INF' *)
		END;
	END ConditionNumber;

	(*
	(** The condition number |A|*|A-1|  quantifies how well-posed (small condition number) a problem is.
	It's computation is dependent on the norm which is applied ; if no inverse is at hand, its computation can be expensive*)
	PROCEDURE ConditionNumber*(CONST A: Matrix;
														norm: PROCEDURE (CONST A:Matrix): Datatype;
														invert: PROCEDURE (CONST A:Matrix):Matrix;
														): Datatype;
	BEGIN
		RETURN norm(A)*norm(invert(A));
	END ConditionNumber
*)
END MatrixNorms.

OFormatter.Format *
PC.Compile \s *
