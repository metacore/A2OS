(* CAPO - Computational Analysis Platform for Oberon - by Alan Freed and Felix Friedrich. *)
(* Version 1, Update 2 *)

MODULE LinEqCholesky;   (** AUTHOR "adf"; PURPOSE "LLT matrix decomposition"; *)

IMPORT Nbr := NbrRe, Vec := VecRe, Mtx := MtxRe, Errors := DataErrors, Math := MathRe, LinEq := LinEqRe;

TYPE
	(** For solving moderate sized linear systems of equations where the matrix is symmetric positive definite. *)
	Solver* = OBJECT (LinEq.Solver)
	VAR dim: LONGINT;
		mtxMag: Nbr.Real;
		lMtx: POINTER TO ARRAY OF POINTER TO ARRAY OF Nbr.Real;

		PROCEDURE Decompose( VAR a: Mtx.Matrix );
		VAR i, j, k: LONGINT;  adjustment, sum: Nbr.Real;
		BEGIN
			(* Cholesky decomposition of the normalized matrix  a. *)
			FOR k := 0 TO dim - 1 DO
				FOR i := 0 TO k - 1 DO
					sum := a.Get( k, i );
					FOR j := 0 TO i - 1 DO adjustment := lMtx[i, j] * lMtx[k, j];  sum := sum - adjustment END;
					lMtx[k, i] := sum / lMtx[i, i]
				END;
				sum := a.Get( k, k );
				FOR i := 0 TO k - 1 DO adjustment := lMtx[k, i] * lMtx[k, i];  sum := sum - adjustment END;
				IF sum > 0 THEN lMtx[k, k] := Math.Sqrt( sum )
				ELSE Errors.Error( "The supplied matrix was not positive definite." )
				END
			END
		END Decompose;

	(** Requires NEW to pass matrix A as a parameter when creating a solver object. *)
		PROCEDURE & Initialize*( VAR A: Mtx.Matrix );
		VAR i: LONGINT;  a: Mtx.Matrix;
		BEGIN
			IF A # NIL THEN
				IF A.rows = A.cols THEN
					a := A.Copy();  dim := A.cols;  LinEq.NormalizeMatrix( a, mtxMag );  NEW( lMtx, dim );
					FOR i := 0 TO dim - 1 DO NEW( lMtx[i], i + 1 ) END;
					Decompose( a );  a := NIL
				ELSE Errors.Error( "The supplied matrix was not square." )
				END
			ELSE Errors.Error( "A NIL matrix was supplied." )
			END
		END Initialize;

	(** Solves  Ax = b  for  x  given  b. *)
		PROCEDURE Solve*( VAR b: Vec.Vector ): Vec.Vector;
		VAR i, k: LONGINT;  adjustment, coef, mag, sum: Nbr.Real;  x: Vec.Vector;
		BEGIN
			IF b # NIL THEN
				IF dim = b.lenx THEN
					x := b.Copy();  LinEq.NormalizeVector( x, mag );
					(* Forward substitution.  Solves  L y = b  for  y  *)
					FOR i := 0 TO dim - 1 DO
						sum := x.Get( i );
						FOR k := 0 TO i - 1 DO adjustment := lMtx[i, k] * x.Get( k );  sum := sum - adjustment END;
						coef := sum / lMtx[i, i];  x.Set( i, coef )
					END;
					(* Backward substitution.  Solves  LTx = y  for  x  *)
					FOR i := dim - 1 TO 0 BY -1 DO
						sum := x.Get( i );
						FOR k := i + 1 TO dim - 1 DO adjustment := lMtx[k, i] * x.Get( k );  sum := sum - adjustment END;
						coef := sum / lMtx[i, i];  x.Set( i, coef )
					END;
					(* Renormalize the solution. *)
					x.Multiply( mag / mtxMag )
				ELSE x := NIL;  Errors.Error( "Incompatible dimension for vector b." )
				END
			ELSE x := NIL;  Errors.Error( "A NIL right-hand-side vector was supplied." )
			END;
			RETURN x
		END Solve;

	END Solver;


	(** Computes the inverse of matrix A and returns A-1 if it exists; otherwise, it returns NIL. *)
	PROCEDURE Invert*( VAR A: Mtx.Matrix ): Mtx.Matrix;
	VAR i, j, k: LONGINT;  adjustment, sum: Nbr.Real;  inverse: Mtx.Matrix;
		lMtxInv: POINTER TO ARRAY OF POINTER TO ARRAY OF Nbr.Real;
		llt: Solver;
	BEGIN
		inverse := NIL;
		IF A # NIL THEN
			IF A.rows = A.cols THEN
				NEW( llt, A );
				(* Invert the Cholesky decomposition matrix  L  to get  L-1. *)
				NEW( lMtxInv, llt.dim );
				FOR i := 0 TO llt.dim - 1 DO NEW( lMtxInv[i], i + 1 ) END;
				FOR i := 0 TO llt.dim - 1 DO
					lMtxInv[i, i] := 1 / llt.lMtx[i, i];
					FOR j := i + 1 TO llt.dim - 1 DO
						sum := 0;
						FOR k := i TO j - 1 DO adjustment := llt.lMtx[j, k] * lMtxInv[k, i];  sum := sum - adjustment END;
						lMtxInv[j, i] := sum / llt.lMtx[j, j]
					END
				END;
				(* Acquire the inverse, i.e.,  A-1 = L-TL-1. *)
				NEW( inverse, 0, llt.dim, 0, llt.dim );
				FOR i := 0 TO llt.dim - 1 DO
					FOR j := 0 TO i DO
						sum := 0;
						FOR k := i TO llt.dim - 1 DO adjustment := lMtxInv[k, i] * lMtxInv[k, j];  sum := sum + adjustment END;
						inverse.Set( i, j, sum );
						IF i # j THEN inverse.Set( j, i, sum ) END
					END
				END;
				(* Renormalize the result. *)
				inverse.Divide( llt.mtxMag )
			ELSE Errors.Error( "The supplied matrix was not square." )
			END
		ELSE Errors.Error( "A NIL matrix was supplied." )
		END;
		RETURN inverse
	END Invert;

END LinEqCholesky.