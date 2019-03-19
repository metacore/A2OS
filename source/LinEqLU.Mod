(* CAPO - Computational Analysis Platform for Oberon - by Alan Freed and Felix Friedrich. *)
(* Version 1, Update 2 *)

MODULE LinEqLU;   (** AUTHOR "adf"; PURPOSE "LU matrix decomposition with total pivoting"; *)

IMPORT Int := NbrInt, Nbr := NbrRe, Vec := VecRe, Mtx := MtxRe, Errors := DataErrors, LinEq := LinEqRe;

TYPE
	(** For solving moderate sized linear systems of equations, even if the rank is less than the dimension. *)
	Solver* = OBJECT (LinEq.Solver)
	VAR rank, dim: LONGINT;
		mtxMag: Nbr.Real;
		colPivot, rowPivot: POINTER TO ARRAY OF LONGINT;
		lu: Mtx.Matrix;

		PROCEDURE Decompose;
		VAR i, j, k: LONGINT;  abs, adjustment, factor, maxCell, ratio: Nbr.Real;
		BEGIN
			dim := lu.rows;  NEW( colPivot, dim - 1 );  NEW( rowPivot, dim - 1 );
			(* Perform total pivoting. *)
			FOR k := 0 TO dim - 2 DO
				maxCell := 0;
				FOR j := k TO dim - 1 DO
					FOR i := k TO dim - 1 DO
						abs := ABS( lu.Get( i, j ) );
						IF abs > maxCell THEN maxCell := abs;  rowPivot[k] := i;  colPivot[k] := j END
					END
				END;
				IF rowPivot[k] # k THEN lu.SwapRows( rowPivot[k], k ) END;
				IF colPivot[k] # k THEN lu.SwapColumns( colPivot[k], k ) END
			END;
			(* LU decomposition of the pivoted matrix. *)
			FOR k := 0 TO dim - 2 DO
				IF lu.Get( k, k ) # 0 THEN
					rank := k + 1;
					FOR i := rank TO dim - 1 DO
						ratio := lu.Get( i, k ) / lu.Get( k, k );
						FOR j := rank TO dim - 1 DO
							adjustment := ratio * lu.Get( k, j );  factor := lu.Get( i, j ) - adjustment;  lu.Set( i, j, factor )
						END;
						lu.Set( i, k, ratio )
					END
				ELSE
					(* rank # dim; therefore, only factored dominant submatrix of dimension rank. *)
					RETURN
				END
			END;
			IF lu.Get( dim - 1, dim - 1 ) # 0 THEN rank := dim END
		END Decompose;

	(** Requires NEW to pass matrix A as a parameter when creating a solver object. *)
		PROCEDURE & Initialize*( VAR A: Mtx.Matrix );
		BEGIN
			IF A # NIL THEN lu := A.Copy();  LinEq.NormalizeMatrix( lu, mtxMag );  Decompose
			ELSE Errors.Error( "A NIL matrix was supplied." )
			END
		END Initialize;

	(** Solves  Ax = b  for  x  given  b. *)
		PROCEDURE Solve*( VAR b: Vec.Vector ): Vec.Vector;
		VAR i, k: LONGINT;  adjustment, factor, mag, ratio, zero: Nbr.Real;  x: Vec.Vector;
		BEGIN
			IF b # NIL THEN
				IF dim = b.lenx THEN
					x := b.Copy();  LinEq.NormalizeVector( x, mag );
					(* Exchange rows in the working vector. *)
					FOR i := 0 TO dim - 2 DO
						IF rowPivot[i] # i THEN x.Swap( rowPivot[i], i ) END
					END;
					(* Forward substitution. *)
					FOR k := 0 TO rank - 2 DO
						FOR i := k + 1 TO rank - 1 DO
							adjustment := lu.Get( i, k ) * x.Get( k );  factor := x.Get( i ) - adjustment;  x.Set( i, factor )
						END
					END;
					(* Backward substitution. *)
					FOR k := rank - 1 TO 1 BY -1 DO
						ratio := x.Get( k ) / lu.Get( k, k );  x.Set( k, ratio );
						FOR i := 0 TO k - 1 DO
							adjustment := lu.Get( i, k ) * x.Get( k );  factor := x.Get( i ) - adjustment;  x.Set( i, factor )
						END
					END;
					ratio := x.Get( 0 ) / lu.Get( 0, 0 );  x.Set( 0, ratio );
					(* Place zeros in the solution vector at positions rank to dim-1. *)
					zero := 0;
					FOR i := rank TO dim - 1 DO x.Set( i, zero ) END;
					(* Remove the pivoting. *)
					FOR i := dim - 2 TO 0 BY -1 DO
						IF colPivot[i] # i THEN x.Swap( colPivot[i], i ) END
					END;
					(* Renormalize the solution. *)
					x.Multiply( mag / mtxMag )
				ELSE x := NIL;  Errors.Error( "Incompatible dimension for vector b." )
				END
			ELSE x := NIL;  Errors.Error( "A NIL right-hand-side vector was supplied." )
			END;
			RETURN x
		END Solve;

	(** Returns the rank of matrix  A, which can be less than its size. *)
		PROCEDURE Rank*( ): Int.Integer;
		VAR r: Int.Integer;
		BEGIN
			r := rank;  RETURN r
		END Rank;

	END Solver;

	(** Computes the inverse of a square matrix A and returns A-1 if it exists; otherwise, it returns NIL. *)
	PROCEDURE Invert*( VAR A: Mtx.Matrix ): Mtx.Matrix;
	VAR i, k: LONGINT;  zero, one: Nbr.Real;  unit, soln: Vec.Vector;  inverse: Mtx.Matrix;  vecArray: Vec.Array;
		mtxArray: Mtx.Array;  lu: Solver;
	BEGIN
		inverse := NIL;
		IF A # NIL THEN
			IF A.rows = A.cols THEN
				NEW( lu, A );
				IF lu.rank = lu.dim THEN
					NEW( vecArray, lu.dim );  zero := 0;  one := 1;
					FOR i := 0 TO lu.dim - 1 DO vecArray[i] := 0 END;
					unit := vecArray^;  NEW( mtxArray, lu.dim, lu.dim );
					FOR k := 0 TO lu.dim - 1 DO
						unit.Set( k, one );  soln := lu.Solve( unit );  unit.Set( k, zero );
						FOR i := 0 TO lu.dim - 1 DO mtxArray[i, k] := soln.Get( i ) END
					END;
					inverse := mtxArray^;
				ELSE Errors.Error( "The matrix is singular." )
				END
			ELSE Errors.Error( "The matrix is not square; it's inverse can't be found." )
			END
		ELSE Errors.Error( "A NIL matrix was supplied." )
		END;
		RETURN inverse
	END Invert;

END LinEqLU.