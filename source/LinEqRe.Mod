(* CAPO - Computational Analysis Platform for Oberon - by Alan Freed and Felix Friedrich. *)
(* Version 1, Update 2 *)

MODULE LinEqRe;   (** AUTHOR "adf"; PURPOSE "Low-level procedures for linear solvers"; *)

IMPORT Nbr := NbrRe, Vec := VecRe, Mtx := MtxRe, Errors := DataErrors;

TYPE
	(**  Definition type for numerical algorithms that solve the linear system of equations  Ax = b. *)
	Solver* = OBJECT
	VAR
		(** Requires NEW to pass matrix A as a parameter when creating a solver object. *)
		PROCEDURE & Initialize*( VAR A: Mtx.Matrix );
		END Initialize;

	(** Solves  Ax = b  for  x  given  b. *)
		PROCEDURE Solve*( VAR b: Vec.Vector ): Vec.Vector;
		END Solve;

	END Solver;

	(** Normalizes vector v so that  |v[i]| # 1 R i  with the normalizing factor being returned as  mag > 0. *)
	PROCEDURE NormalizeVector*( VAR v: Vec.Vector;  VAR mag: Nbr.Real );
	VAR i: SIGNED32;  abs, zero: Nbr.Real;
	BEGIN
		IF v # NIL THEN
			zero := 0;  mag := zero;
			(* Find the cell whose magnitude is the greatest and store its value. *)
			FOR i := 0 TO v.lenx - 1 DO
				abs := ABS( v.Get( i ) );
				IF abs > mag THEN mag := abs END
			END;
			IF mag > MIN( Nbr.Real ) THEN
				(* Normalize the vector by this maximum magnitude. *)
				v.Divide( mag );
				(* Filter out all cells whose entries are effectively zero. *)
				FOR i := 0 TO v.lenx - 1 DO
					IF ABS( v.Get( i ) ) < Nbr.Epsilon THEN v.Set( i, zero ) END
				END
			ELSE
				FOR i := 0 TO v.lenx - 1 DO v.Set( i, zero ) END
			END
		ELSE Errors.Error( "A NIL vector was passed as an argument." )
		END
	END NormalizeVector;

(** Normalizes matrix m so that  |m[i, j]| # 1 R i, j  with the normalizing factor being returned as  mag > 0. *)
	PROCEDURE NormalizeMatrix*( VAR m: Mtx.Matrix;  VAR mag: Nbr.Real );
	VAR i, j: SIGNED32;  abs, zero: Nbr.Real;
	BEGIN
		IF m # NIL THEN
			zero := 0;  mag := zero;
			(* Find the cell whose magnitude is the greatest and store its value. *)
			FOR i := 0 TO m.rows - 1 DO
				FOR j := 0 TO m.cols - 1 DO
					abs := ABS( m.Get( i, j ) );
					IF abs > mag THEN mag := abs END
				END
			END;
			IF mag > MIN( Nbr.Real ) THEN
				(* Normalize the matrix by this maximum magnitude. *)
				m.Divide( mag );
				(* Filter out all cells whose entries are effectively zero. *)
				FOR i := 0 TO m.rows - 1 DO
					FOR j := 0 TO m.cols - 1 DO
						IF ABS( m.Get( i, j ) ) < Nbr.Epsilon THEN m.Set( i, j, zero ) END
					END
				END
			ELSE
				FOR i := 0 TO m.rows - 1 DO
					FOR j := 0 TO m.cols - 1 DO m.Set( i, j, zero ) END
				END
			END
		ELSE Errors.Error( "A NIL matrix was passed as an argument." )
		END
	END NormalizeMatrix;

END LinEqRe.