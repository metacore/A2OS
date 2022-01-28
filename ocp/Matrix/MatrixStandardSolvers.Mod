MODULE MatrixStandardSolvers;   (**  AUTHOR "Patrick Hunziker"; PURPOSE "Standard Matrix Solvers. Offers an object-oriented and a procedural interface";  **)
				(* TO DO: small matrices *)

IMPORT Base := MatrixBase, Math := MathL, Kernel;

CONST
	OK = Base.OK;
	SINGULAR = Base.SINGULAR;
	NONCONVERGENCE = Base.NONCONVERGENCE;
	NOTPOSDEFINITE = Base.NOTPOSDEFINITE;
	NOTSQUARE = Base.NOTSQUARE;
	SIZEMISMATCH = Base.SIZEMISMATCH;
	Tiny = 1.0E-20;

	NONE* = 0;
	PARTIAL* = 1;
	ROW* = 1;
	FULL*=2;


TYPE
	Datatype = Base.Datatype;
	Matrix = Base.Matrix;
	Vector = Base.Vector;
	IntVector = ARRAY [*] OF SIZE;

	(** LU is a standard direct solver for square linear systems of equations; it is related to Gauss elimination; this version uses row pivoting*)
	LU* = OBJECT (Base.Solver);
	VAR lu: Matrix;   (*if LU decomposition needs to be exported, think of its permutated state by Index *)
		pivot*:SIGNED32; (** switch off pivoting by setting this to NONE. default is FULL *)
		Index: ARRAY [*] OF SIZE;
		V: Vector;
		tRow: Vector;
		temp:Matrix;
		Ut, A1: Matrix; (*temp structures for special versions*)
		timetotal-, timeRowRowMul-, timeMatVecMul-: SIGNED32;
		timer: Kernel.MilliTimer;

		PROCEDURE & Init*( CONST A: Matrix );   (*initialize and - if LEN(A,0) > 0  -  decompose immediately *)
		BEGIN
			handleError := Base.HandleError;   (*default error handler*)
			pivot:=ROW;
			timetotal:=0; timeRowRowMul:=0; timeMatVecMul:=0;
			res := OK;   (* *)
			IF LEN( A, 0 ) = 0 THEN RETURN END;
			IF LEN( A,0 ) # LEN( A, 1 ) THEN res := NOTSQUARE;  handleError( res, "LU: matrix not square" );  RETURN END;
			lu := A;   (*copy overhead if LEN(A,0)>0; can be circumvented when directly using SolveNoCopy(), but the latter is less generic*)
			IF LEN(A,0)<300 THEN decompose( lu )
			ELSE (*decomposeSliced(lu)*)decomposeFastLarge(lu)
			END;
		END Init;

		(*decompose with row pivoting*)
		PROCEDURE decompose( VAR A: Matrix );
		VAR I, Imax, J: SIZE;  Pvt, T: Datatype;  Ubound: SIZE;
		BEGIN
			IF LEN( Index,0 ) # LEN( A,0 ) THEN NEW( Index, LEN( A,0 ) ) ELSE Index := 0;  END;   (*reset*)
			IF pivot#ROW THEN res:=Base.NOTIMPLEMENTED; handleError(res,"MatrixStandardSolvers.LU: this pivot version is not implemented"); RETURN END;
			IF LEN( V,0 ) # LEN( A,0 ) THEN NEW( V, LEN( A,0 ) ) ELSE V := 0;  END;
			IF LEN( tRow,0 ) # LEN( A,0 ) THEN NEW( tRow, LEN( A,0 ) ) ELSE tRow := 0;  END;
			Ubound := LEN( A,0 ) - 1;
			FOR I := 0 TO Ubound DO
				Pvt := 0.0;  Pvt := MaxAbsV( A[I]  );
				IF Pvt < Base.EPS THEN res := SINGULAR;  handleError( res, "LU: singular matrix " );  RETURN END;
				V[I] := 1.0 / Pvt;
			END;
			FOR J := 0 TO Ubound DO
				FOR I := 0 TO J - 1 DO
					A[I, J] := A[I, J] - A[I, 0..I-1] +* A[0..I-1, J]	(*U: row<col; L: row>=col*)
				END;
				A[J.., J] := A[J.., J] - A[J.., 0..J-1] * A[0..J-1, J] ;
				Pvt := 0;
				FOR I := J TO Ubound DO
					(*A[I, J] := A[I, J] - A[I, 0..J-1] +* A[0..J-1, J];*) (*is taken out of the inner loop above*)
					T := V[I] * ABS( A[I, J] );
					IF T > Pvt THEN Pvt := T;  Imax := I;  END;
				END;
				IF J # Imax THEN
					tRow := A[Imax];  A[Imax] := A[J];  A[J] := tRow;  V[Imax] := V[J];  (*full line exchange*)
				END;
				Index[J] := Imax;
				IF A[J, J] = 0.0 THEN A[J, J] := Tiny END;
				IF J # Ubound THEN
					T := 1.0 / A[J, J];  A[J + 1..Ubound, J] := A[J + 1..Ubound, J] * T;
				END;
			END;
			RETURN;
		END decompose;

		(*		(*decompose with row pivoting*)
		PROCEDURE decomposeNoRowFlip( VAR A: Matrix );
		VAR I, Imax, J: SIGNED32;  Pvt, T: Datatype;  Ubound: SIGNED32;
		BEGIN
			IF LEN( Index,0 ) # LEN( A,0 ) THEN NEW( Index, LEN( A , 0 ) ) ELSE Index := 0;  END;   (*reset*)
			IF pivot#ROW THEN res:=Base.NOTIMPLEMENTED; handleError(res,"MatrixStandardSolvers.LU: this pivot version is not implemented"); RETURN END;
			IF LEN( V , 0 ) # LEN( A,0 ) THEN NEW( V, LEN( A,0 ) ) ELSE V := 0;  END;
			IF LEN( tRow,0 ) # LEN( A,0 ) THEN NEW( tRow, LEN( A,0 ) ) ELSE tRow := 0;  END;
			Ubound := LEN( A,0 ) - 1;
			FOR I := 0 TO Ubound DO
				Pvt := 0.0;  Pvt := MaxAbsV( A[I]  );
				IF Pvt < Base.EPS THEN res := SINGULAR;  handleError( res, "LU: singular matrix " );  RETURN END;
				V[I] := 1.0 / Pvt;
			END;
			FOR J := 0 TO Ubound DO
				FOR I := 0 TO J - 1 DO
					A[I, J] := A[I, J] - A[I, 0..I-1] +* A[0..I-1, J]	(*U: row<col; L: row>=col*)
				END;
				A[J.., J] := A[J.., J] - A[J.., 0..J-1] * A[0..J-1, J] ;
				Pvt := 0;
				FOR I := J TO Ubound DO
					(*A[I, J] := A[I, J] - A[I, 0..J-1] +* A[0..J-1, J];*) (*is taken out of the inner loop above*)
					T := V[I] * ABS( A[I, J] );
					IF T > Pvt THEN Pvt := T;  Imax := I;  END;
				END;
				IF J # Imax THEN
					tRow := A[Imax];  A[Imax] := A[J];  A[J] := tRow;  V[Imax] := V[J];  (*full line exchange*)
				END;
				Index[J] := Imax;
				IF A[J, J] = 0.0 THEN A[J, J] := Tiny END;
				IF J # Ubound THEN
					T := 1.0 / A[J, J];  A[J + 1..Ubound, J] := A[J + 1..Ubound, J] * T;
				END;
			END;
			RETURN;
		END decomposeNoRowFlip;
		*)


		PROCEDURE decomposeNoPivot( VAR A: Matrix ); (* .. slow because of row accesses with excess cache misses and because outerproduct-add is so slow..*)
		VAR J: SIZE;
		BEGIN
			IF LEN( Index,0 ) # LEN( A,0 ) THEN NEW( Index, LEN( A,0 ) ) ELSE Index := 0;  END;   (*reset*)
			IF (LEN(temp,0)#LEN(A,0)) OR(LEN(temp,1)#LEN(A,1))THEN NEW(temp,LEN(A,0),LEN(A,1)); END;
			FOR J := 0 TO LEN( A,0 )-2 DO
				IF A[J,J] = 0 THEN res := SINGULAR;  handleError( res, "LU: singular matrix " );  RETURN END;
				A[J+1.., J] := (1/A[J,J]) * A[J+1.., J] ;
				A[J+1.., J+1..] := A[J+1.., J+1..]- A[J+1.., J] ** A[J, J+1..];
				(*temp[J+1.., J+1..]:=A[J+1.., J] ** A[J, J+1..];
				A[J+1.., J+1..] := A[J+1.., J+1..]- temp[J+1.., J+1..];*)
				Index[J]:=J; (*dummy index handling*)
			END;
			Index[J]:=J;
			RETURN ;
		END decomposeNoPivot;

		(*decompose with row pivoting. column-wise access is accelerated through duplicate, transpose matrix. however, slow transposition renders this slow, too *)
		PROCEDURE decomposeFastLarge( VAR A: Matrix ); (*tries to limit cache misses, at the expense of memory use*)
			VAR I, Imax, J: SIZE;  Pvt, T: Datatype;  Ubound: SIZE;  tRow, tRow2: Vector;

		BEGIN
			IF LEN( Index,0 ) # LEN( A,0 ) THEN NEW( Index, LEN( A,0 ) ) ELSE Index := 0;  END;   (*reset*)
			IF pivot#ROW THEN res:=Base.NOTIMPLEMENTED; handleError(res,"MatrixStandardSolvers.LU: this pivot version is not implemented"); RETURN END;
			IF LEN( V , 0 ) # LEN( A,0 ) THEN NEW( V, LEN( A,0 ) ) ELSE V := 0;  END;
			IF LEN( tRow,0 ) # LEN( A,0 ) THEN NEW( tRow, LEN( A,0 ) ) ELSE tRow := 0;  END;
			IF LEN( tRow2,0 ) # LEN( A,0 ) THEN NEW( tRow2, LEN( A,0 ) ) ELSE tRow := 0;  END;
			Ubound := LEN( A,0 ) - 1;
			Index := 0;   (*reset*)
			IF (LEN(Ut,0)#LEN(A,1)) OR (LEN(Ut,1)#LEN(A,0)) THEN NEW(Ut, LEN(A,1), LEN(A,0)); NEW(A1, LEN(A,0), LEN(A,1)); END;
			Kernel.SetTimer( timer, 0 );
			Ut:=A`; (* extract Ut for faster access to columns of A *)
			FOR I := 0 TO Ubound DO
				Pvt := 0.0;  Pvt := MaxAbsV( A[I] ) ;
				IF Pvt < Base.EPS THEN res := SINGULAR;  handleError( res, "LU: singular matrix " );  RETURN END;
				V[I] := 1.0 / Pvt;
			END;
			FOR J := 0 TO Ubound DO
				timeRowRowMul := timeRowRowMul - Kernel.Elapsed( timer );
				FOR I := 0 TO J - 1 DO
					Ut[J,I] := Ut[J,I] - A[I, 0..I-1] +* Ut[J, 0..I-1]	(*U: row<col; L: row>=col*) (* L==A is fast for row access; Ut is transposed for fast "column" access*)
				END;
				timeRowRowMul := timeRowRowMul + Kernel.Elapsed( timer );
				Pvt := 0.0;
				timeMatVecMul := timeMatVecMul - Kernel.Elapsed( timer );
				A[J.., J] := A[J.., J] - A[J.., 0..J-1] * Ut[J, 0..J-1];
				timeMatVecMul := timeMatVecMul + Kernel.Elapsed( timer );
				FOR I := J TO Ubound DO
					(*A[I, J] := A[I, J] - A[I, 0..J-1] +* Ut[J, 0..J-1];*)
					T := V[I] * ABS( A[I, J] );
					IF T > Pvt THEN Pvt := T;  Imax := I;  END;
				END;
				IF J # Imax THEN (*swap rows; there is a mini overhead due to the separation of lower and upper triangular matrix*)
					tRow[..Imax] := A[Imax,..Imax];  tRow[Imax+1..] := Ut[Imax+1..,Imax]; (* row swapping is more complicated because upper part of row from A is now in column of Ut*)
					tRow2[..J] := A[J,..J];  tRow2[J+1..] := Ut[J+1..,J];
					A[Imax,..Imax] := tRow2[..Imax]; Ut[Imax+1..,Imax]:=tRow2[Imax+1..];
					A[J,..J] := tRow[..J]; Ut[J+1..,J]:=tRow[J+1..];
					V[Imax] := V[J];  (*full line exchange*)
				END;
				Index[J] := Imax;
				IF ABS(A[J, J])<Tiny (* = 0.0 *) THEN A[J, J] := Tiny END;
				IF J # Ubound THEN
					T := 1.0 / A[J, J];  A[J + 1..Ubound, J] := A[J + 1..Ubound, J] * T;
				END;
			END;
			A1:=Ut`;
			FOR I:=0 TO Ubound-1 DO	(*pack U back into A*)
				A[I,I+1..]:=A1[I,I+1..];
			END;
			timetotal:=Kernel.Elapsed(timer);
			RETURN ;
		END decomposeFastLarge;

		(*decompose with row pivoting with partitioning of the data to avoid cache misses*)
		PROCEDURE decomposeSliced( VAR A: Matrix );
		VAR I, Imax, J: SIZE;  Pvt, T: Datatype;  Ubound: SIZE;
			j, jlen, jsize: SIZE; AS: Matrix;
		BEGIN
			IF LEN( Index,0 ) # LEN( A,0 ) THEN NEW( Index, LEN( A,0 ) ) ELSE Index := 0;  END;   (*reset*)
			IF pivot#ROW THEN res:=Base.NOTIMPLEMENTED; handleError(res,"MatrixStandardSolvers.LU: this pivot version is not implemented"); RETURN END;
			IF LEN( V , 0 ) # LEN( A , 0 ) THEN NEW( V, LEN( A,0 ) ) ELSE V := 0;  END;
			IF LEN( tRow,0 ) # LEN( A , 0 ) THEN NEW( tRow, LEN( A,0 ) ) ELSE tRow := 0;  END;
			Ubound := LEN( A,0 ) - 1;
			Kernel.SetTimer( timer, 0 );
			FOR I := 0 TO Ubound DO
				Pvt := 0.0;  Pvt := MaxAbsV( A[I]  );
				IF Pvt < Base.EPS THEN res := SINGULAR;  handleError( res, "LU: singular matrix " );  RETURN END;
				V[I] := 1.0 / Pvt;
			END;
			NEW(AS,LEN(A,0), 10);
			j:=0;jsize:=LEN(AS,1);
			FOR J := 0 TO Ubound DO
				timeRowRowMul := timeRowRowMul - Kernel.Elapsed( timer );
				(*slicewise handling - 2-3* faster but wrong result*)
				IF J MOD jsize =0 THEN
					j:=J;
					jlen:=MIN(jsize,Ubound+1-J);
					AS[..,0..jlen-1] := A[..,J..J+jlen-1];
				END;
				FOR I := 0 TO J - 1 DO
					AS[I, J-j] := AS[I, J-j] - A[I, 0..I-1] +* AS[0..I-1, J-j]	(*U: row<col; L: row>=col*)	(*wrong computation result*)
					(*A[I, J] := A[I, J] - A[I, 0..I-1] +* A[0..I-1, J]	(*U: row<col; L: row>=col*)*)
				END;
				IF J MOD jsize =0 THEN A[..,J..J+jlen-1]:= AS[..,0..jlen-1]; END;
				(*end slicewise handling*)
				timeRowRowMul := timeRowRowMul + Kernel.Elapsed( timer );
				timeMatVecMul := timeMatVecMul - Kernel.Elapsed( timer );
				A[J.., J] := A[J.., J] - A[J.., 0..J-1] * A[0..J-1, J] ;
				timeMatVecMul := timeMatVecMul + Kernel.Elapsed( timer );
				Pvt := 0;
				FOR I := J TO Ubound DO
					(*A[I, J] := A[I, J] - A[I, 0..J-1] +* A[0..J-1, J];*)
					T := V[I] * ABS( A[I, J] );
					IF T > Pvt THEN Pvt := T;  Imax := I;  END;
				END;
				IF J # Imax THEN
					tRow := A[Imax];  A[Imax] := A[J];  A[J] := tRow;  V[Imax] := V[J];  (*full line exchange*)
				END;
				Index[J] := Imax;
				IF A[J, J] = 0.0 THEN A[J, J] := Tiny END;
				IF J # Ubound THEN
					T := 1.0 / A[J, J];  A[J + 1..Ubound, J] := A[J + 1..Ubound, J] * T;
				END;
			END;
			RETURN;
		END decomposeSliced;


		PROCEDURE backsubstitute( VAR A: Matrix;  CONST b: Vector );
		VAR I, Ip, K: SIZE;  Sum: Datatype;  Ubound: SIZE;
		BEGIN
			IF LEN( x,0 ) # LEN( A, 1 ) THEN NEW( x, LEN( A, 1 ) ) END;
			Ubound := LEN( A,0 ) - 1;   (*TODO:check matrix dimensions*)
			K := -1;  x := b;
			FOR I := 0 TO Ubound DO
				Ip := Index[I];  Sum := x[Ip];  x[Ip] := x[I];
				IF K >= 0 THEN Sum := Sum - A[I, K..I - 1] +* x[K..I - 1];
				ELSIF Sum # 0.0 THEN K := I;
				END;
				x[I] := Sum;
			END;
			FOR I := Ubound TO 0 BY -1 DO
				Sum := x[I];
				IF I < Ubound THEN Sum := Sum - A[I, I + 1..] +* x[I + 1..];  END;
				x[I] := Sum / A[I, I];
			END;
		END backsubstitute;

		PROCEDURE backsubstituteMultiple( CONST A: Matrix;  CONST B: Matrix ):Matrix;
		VAR I, Ip, K: SIZE; Ubound: SIZE; VAR X:Matrix; Sum:Vector;
		BEGIN
			IF (LEN( X,0 ) # LEN( B, 1)) OR (LEN( X ,1) # LEN( B, 0 )) THEN NEW( X, LEN( B, 1 ), LEN(B,0) ) END;
			Ubound := LEN( A,0 ) - 1;   (*TODO:check matrix dimensions*)
			K := -1;  X := B`;
			FOR I := 0 TO Ubound DO
				Ip := Index[I];  Sum := X[Ip,..];  X[Ip,..] := X[I,..];
				IF K >= 0 THEN Sum := Sum - A[I, K..I - 1] * X[K..I - 1,..];
				ELSIF Sum+*Sum # 0.0 THEN K := I;
				END;
				X[I,..] := Sum;
			END;
			FOR I := Ubound TO 0 BY -1 DO
				Sum := X[I,..];
				IF I < Ubound THEN Sum := Sum - A[I, I + 1..] * X[I + 1..,..];  END;
				X[I,..] := Sum / A[I, I];
			END;
			RETURN X
		END backsubstituteMultiple;

		(*
		PROCEDURE Inverse*():Matrix;  (*OK*)
		VAR Identity:Matrix; i:SIGNED32;
		BEGIN
			NEW(Identity, LEN( lu, 0 ), LEN(lu,1));
			FOR i:=0 TO LEN(Identity,0)-1 DO Identity[i,i]:=1.0; END;
			RETURN backsubstituteMultiple(lu, Identity);
		END Inverse;
		*)

		PROCEDURE Inverse*():Matrix; (*to do:compute only once, and store inverse for later use, and have flag to show this *)
		VAR I, Ip, K: SIZE;  Ubound: SIZE; VAR X:Matrix; Sum, tmp:Vector;
		BEGIN
			IF (LEN( X,0 ) # LEN( lu, 1)) OR (LEN( X ,1) # LEN( lu, 0 )) THEN NEW( X, LEN( lu, 1 ), LEN(lu,0) ) ELSE X:=0; END;
			Ubound := LEN( lu,0 ) - 1;   (*TODO:check matrix dimensions*)
			K := -1;
			FOR I:=0 TO LEN(X,0)-1 DO X[I,I]:=1.0 END;
			FOR I := 0 TO Ubound DO
				Ip := Index[I];
				Sum := X[Ip,..];
				X[Ip,..] := X[I,..];
				IF K >= 0 THEN
					tmp:=lu[I, K..I - 1] * X[K..I - 1,..]; Sum:=Sum-tmp;
					(*Sum := Sum - lu[I, K..I - 1] * X[K..I - 1,..]; *) (*compiler should issue no-copy version*)
				ELSIF Sum+*Sum # 0.0 THEN K := I;
				END;
				X[I,..] := Sum;
			END;
			FOR I := Ubound TO 0 BY -1 DO
				Sum := X[I,..];
				IF I < Ubound THEN
					tmp:=lu[I, I + 1..] * X[I + 1..,..]; Sum:=Sum-tmp;
					(*Sum := Sum - lu[I, I + 1..] * X[I + 1..,..]; *) (*compiler should issue no-copy version*)
				END;
				X[I,..] := Sum / lu[I, I];
			END;
			RETURN X
		END Inverse;

		(*
		PROCEDURE Inverse():Matrix;
		VAR I, Ip, J, K: SIGNED32;  Sum: Datatype;  Ubound: SIGNED32; luInv:Matrix;
		BEGIN
			IF (LEN( luInv,0 ) # LEN( lu, 0)) OR (LEN( luInv ,1) # LEN( lu, 1 )) THEN NEW( luInv, LEN( lu, 0 ), LEN(lu,1) ) END;
			Ubound := LEN( lu ) - 1;   (*TODO:check matrix dimensions*)
			K := -1;  x := b;
			FOR I := 0 TO Ubound DO
				Ip := Index[I];  Sum := x[Ip];  x[Ip] := x[I];
				IF K >= 0 THEN Sum := Sum - lu[I, K..I - 1] +* x[K..I - 1];
				ELSIF Sum # 0.0 THEN K := I;
				END;
				x[I] := Sum;
			END;
			FOR I := Ubound TO 0 BY -1 DO
				Sum := x[I];
				IF I < Ubound THEN Sum := Sum - lu[I, I + 1..] +* x[I + 1..];  END;
				x[I] := Sum / lu[I, I];
			END;
		END Inverse;
		*)
		PROCEDURE SolveNoCopy*( VAR A: Matrix;  CONST b: Vector ): Vector;   (* no internal matrix copying overhead; Initialize with zero size matrix for this case.  note: the matrix A is altered in this case; *)
		BEGIN
			IF pivot=NONE THEN decomposeNoPivot( A );
			ELSIF LEN(A,0)<300 THEN decompose( A )
			ELSE decomposeFastLarge( A )
			END;
			backsubstitute( A, b );  RETURN x
		END SolveNoCopy;

		PROCEDURE Solve*( CONST b: Vector ): Vector;   (** Solver; needs solver initialized with matrix A  *)
		BEGIN
			IF  LEN(lu,0)=0 THEN HALT(100) END;
			backsubstitute( lu, b );  RETURN x
		END Solve;

		PROCEDURE SolveMultiple*( CONST B: Matrix ): Matrix;   (** Solver; needs solver initialized with matrix A  *)
		BEGIN
			IF  LEN(lu,0)=0 THEN HALT(100) END;
			RETURN backsubstituteMultiple( lu, B );
		END SolveMultiple;

	(*
		PROCEDURE SolveMultiple*( CONST B: Matrix ): Matrix;  (* example of specific implementation for multiple right hand sides A*X=B    *)
		VAR X: Matrix;
		BEGIN
			(* do it here*)
			RETURN X;
		END SolveMultiple;
*)
	END LU;

TYPE
	(** Gauss elimination is the historic root of solvers. The current implementation is slow *) (*to do: export the rearranged matrix *)
	(** Solve by Gaussian elimination algorithm  with row pivoting  *)
	Gauss* = OBJECT (Base.Solver)
	VAR
		A:Matrix; tRow: Vector;
		pivot* : SIGNED32;

		PROCEDURE & Init*( CONST A: Matrix );
		VAR
		BEGIN
			handleError := Base.HandleError;   (*default error handler*)
			pivot := ROW;
			res := OK;   (* *)
			IF LEN( A, 0 ) = 0 THEN RETURN END;
			IF LEN( A , 0 ) # LEN( A, 1 ) THEN res := NOTSQUARE;  handleError( res, "Gauss: matrix not square" );  RETURN END;
			SELF.A:=A;
		END Init;

		PROCEDURE Swap( VAR X, Y: Datatype );
		VAR Z: Datatype;
		BEGIN
			Z := X;  X := Y;  Y := Z
		END Swap;

		PROCEDURE SwapRows( I, K: SIZE );
		BEGIN
			tRow := A[I];  A[I] := A[K];  A[K] := tRow;
		END SwapRows;

	(** Solve by Gaussian elimination algorithm  with row pivoting *) (*currently 10-20 times slower than LU. to do: avoid  explicit copying of rows by using indexing approach as in LU ?*)
		PROCEDURE Solve*( CONST b:Vector): Vector;
			VAR 		i, j, k, m, n, maxi, u: SIZE;  val, max, Auj: Datatype;
			BEGIN
			IF LEN( x,0 ) # LEN( b,0 ) THEN NEW( x, LEN( b,0 ) ) ELSE x := 0;  END;
			IF pivot#ROW THEN res:=Base.NOTIMPLEMENTED; handleError(res,"MatrixStandardSolvers.Gauss: this pivot version is not implemented"); RETURN x END;
			IF LEN( tRow,0 ) # LEN( A , 0 ) THEN NEW( tRow, LEN( A,0 ) ) ELSE tRow := 0;  END;
			x:=b;
			m := LEN( A, 0 );  n := LEN( A, 1 );  i := 0;  j := 0;
			WHILE (i < m ) & (j < n) DO
				max := A[i, j];   (*Find pivot in column j, starting in row i*)
				maxi := i;
				FOR k := i + 1 TO m - 1 DO
					val := A[k, j];
					IF ABS( val ) > ABS( max ) THEN max := val;  maxi := k END;
				END;
				IF ABS(max) >= Base.EPS THEN
					SwapRows( i, maxi ); Swap(x[i], x[maxi]);
					A[i] := A[i] / max;  x[i]:= x[i]/max;
					(*
					FOR u := 0 TO m - 1 DO
						IF u # i THEN
							Auj:=A[u,j];
							x[u] := x[u] - x[i] * Auj;
							A[u] := A[u] - A[i] * Auj
						END;
					END;
					*)
					x[..i-1] := x[..i-1] - x[i] * A[..i-1,j]; 		(*läuft nur, falls Compiler A[5..4]:=1; als leeres Statement akzeptiert*)
					x[i+1..] := x[i+1..] - x[i] * A[i+1..,j];

					A[..i-1] := A[..i-1] - A[..i-1,j] ** A[i];
					A[i+1..] := A[i+1..] - A[i+1..,j] ** A[i];
					INC( i );
				END;
				INC( j );
			END;
			RETURN x
		END Solve;

		 (* no internal matrix copying overhead;  note: the matrix A is altered in this case; *)
		PROCEDURE SolveNoCopy*( VAR A: Matrix;  CONST b: Vector ): Vector;   (* no internal matrix copying overhead; Initialize with zero size matrix for this case.  note: the matrix A is altered in this case; *)
		BEGIN
			res := OK;
			SELF.A:= ALIAS OF A; (* this system function available only in newer compiler version *)
			RETURN Solve(b);
		END SolveNoCopy;

	END Gauss;

TYPE
	(** Decompose +/- Solve a linear system by the Gauss-Jordan algorithm , with full pivoting; using only the NEW(solver,A) or solver.Init(A) part, matrix inversion is performed;
	slower than Gauss, but suited for direct computation of the matrix inverse *)
	GaussJordan* = OBJECT (Base.Solver)
	VAR Ainv-: Matrix;
		tRow, tCol, Pivot: Vector;
		PRow, PCol: IntVector;
		Ubound: SIZE;
		pivot*:SIGNED32;

		PROCEDURE & Init*( CONST A: Matrix );
		VAR
		BEGIN
			handleError := Base.HandleError;   (*default error handler*)
			pivot := FULL;
			res := OK;   (* *)
			IF LEN( A, 0 ) = 0 THEN RETURN END;
			IF LEN( A , 0 ) # LEN( A, 1 ) THEN res := NOTSQUARE;  handleError( res, "Gauss-Jordan: matrix not square" );  RETURN END;   (*does this matter in Gauss-Jordan ?*)
			decompose( A );
		END Init;

		PROCEDURE Swap( VAR X, Y: Datatype );
		VAR Z: Datatype;
		BEGIN
			Z := X;  X := Y;  Y := Z
		END Swap;

		PROCEDURE SwapRows( I, K: SIZE );   (*local procedure to save temp memory*)
		BEGIN
			tRow := Ainv[I];  Ainv[I] := Ainv[K];  Ainv[K] := tRow;
		END SwapRows;

		PROCEDURE SwapCols( J, K: SIZE );
		BEGIN
			tCol := Ainv[.. , J];  Ainv[.. , J] := Ainv[.. , K];  Ainv[.. , K] := tCol;
		END SwapCols;

		PROCEDURE decompose( CONST A: Matrix );
		VAR I, J, K: SIZE;  Pvt, T: Datatype;
		BEGIN
			IF pivot#FULL THEN res:=Base.NOTIMPLEMENTED; handleError(res,"MatrixStandardSolvers.GaussJordan: this pivot version is not implemented"); RETURN END;
			Ubound := LEN( A, 1 ) - 1;
			IF LEN( PRow,0 ) # LEN( A, 0 ) THEN NEW( PRow, LEN( A, 0 ) );  NEW( tRow, LEN( PRow,0 ) );  END;
			IF LEN( PCol,0 ) # LEN( A, 1 ) THEN
				NEW( PCol, LEN( A[1],0 ) );  NEW( tCol, LEN( PCol,0 ) );  NEW( Pivot, LEN( A, 1 ) );
			END;
			Ainv := A;  K := 0;
			WHILE K <= Ubound DO
				Pvt := Ainv[K, K];  PRow[K] := K;  PCol[K] := K;   (* Search for largest pivot in submatrix Ainv[K..Ubound, K..Ubound] *)
				FOR I := K TO Ubound DO
					FOR J := K TO Ubound DO
						IF ABS( Ainv[I, J] ) > ABS( Pvt ) THEN
							Pvt := Ainv[I, J];  PRow[K] := I;  PCol[K] := J;
						END
					END;
				END;
				IF ABS( Pvt ) < Base.EPS THEN
					res := SINGULAR;  handleError( res, "Gauss-Jordan: singular matrix " );  RETURN  (* Pivot Too weak ==> quasi-singular matrix *)
				ELSE Pivot[K] := Pvt;
				END;
				IF PRow[K] # K THEN SwapRows( PRow[K], K ); END;   (* Exchange current row (K) with pivot row *)
				IF PCol[K] # K THEN SwapCols( PCol[K], K ) END;   (* Exchange current column (K) with pivot column *)
				Ainv[K, K] := 1.0;   (* Transform pivot row *)
				Ainv[K, .. ] := Ainv[K, .. ] / Pvt;
				FOR I := 0 TO Ubound DO  (* Transform other rows *)
					IF I # K THEN
						T := Ainv[I, K];  Ainv[I, K] := 0.0;
						Ainv[I, .. ] := Ainv[I, .. ] - T * Ainv[K, .. ];
					END
				END;
				INC( K );
			END;
			FOR I := Ubound TO 0 BY -1 DO  (* Rearrange inverse matrix *)
				IF PCol[I] # I THEN SwapRows( PCol[I], I )  END
			END;
			FOR J := Ubound TO 0 BY -1 DO
				IF PRow[J] # J THEN SwapCols( PRow[J], J ) END
			END;
			RETURN;
		END decompose;

		PROCEDURE backsubstitute( CONST B: Vector );
		BEGIN
			x:=Ainv*B;
		END backsubstitute;

		PROCEDURE Solve*( CONST b: Vector ): Vector;
		BEGIN
			IF LEN( b,0 ) # LEN( Ainv, 0 ) THEN res := SIZEMISMATCH;  handleError( res, "Gauss-Jordan: Size mismatch " );  RETURN x END;
			backsubstitute( b );  RETURN x;
		END Solve;

	END GaussJordan;

TYPE
	(** Cholesky decomposition for positive definite matrices; can be used to check for positive-definiteness *)
	Cholesky* = OBJECT (Base.Solver)
	VAR L-: Matrix;

		PROCEDURE & Init*( CONST A: Matrix );
		VAR I, J, K, Ubound: SIZE;  Sum: Datatype;
		BEGIN
			handleError := Base.HandleError;  res := OK;
			IF LEN( A , 0 ) = 0 THEN RETURN END;
			IF LEN( A , 0 ) # LEN( A, 1 ) THEN res := NOTSQUARE;  handleError( res, "Cholesky: matrix not square " );  RETURN END;
			IF (LEN( L,0 ) # LEN( A , 0 )) OR (LEN( L, 1 ) # LEN( A, 1 )) THEN NEW( L, LEN( A,0 ), LEN( A, 1 ) ) ELSE L := 0 END;
			Ubound := LEN( A,0 ) - 1;
			FOR K := 0 TO Ubound DO  (*decompose*)
				Sum := A[K, K];
				FOR J := 0 TO K - 1 DO Sum := Sum - Sqr( L[K, J] ) END;
				IF Sum <= 0.0 THEN res := NOTPOSDEFINITE;  handleError( res, "Cholesky: matrix not positive definite " );  RETURN END;
				L[K, K] := Math.sqrt( Sum );
				FOR I := K + 1 TO Ubound DO
					Sum := A[I, K] - L[I, .. K - 1] +* L[K, .. K - 1];  L[I, K] := Sum / L[K, K];
				END;
			END;
		END Init;

	END Cholesky;

TYPE
	(** QR decomposition and solver; A receives m*n matrix (m>=n).  returned is column-orthogonal matrix Q, and square, upper diagonal n*n matrix R; *)
	QR* = OBJECT (Base.Solver)
	VAR Q-, R-: Matrix;

		PROCEDURE & Init*( CONST A: Matrix );
		VAR
		BEGIN
			handleError := Base.HandleError;   (*default error handler*)
			res := OK;   (* *)
			IF LEN( A, 0 ) = 0 THEN RETURN END;
			IF LEN( A, 0 ) < LEN( A, 1 ) THEN res := SIZEMISMATCH;  handleError( res, "QR: size incompatiblity" );  RETURN END;
			Q := A;
			decompose;
		END Init;

		PROCEDURE decompose;
		VAR K: SIZE; Sum: Datatype;
		BEGIN
			IF (LEN( R, 0 ) # LEN( Q, 1 )) OR (LEN( R, 1 ) # LEN( Q, 1 )) THEN NEW( R, LEN( Q, 1 ), LEN( Q, 1 ) );  ELSE R := 0 END;
			FOR K := 0 TO LEN( Q, 1 ) - 1 DO
				Sum:=Q[..,K] +* Q[..,K];
				IF Sum = 0.0 THEN res := SINGULAR;  handleError( res, "QR: singular matrix " );  RETURN END;
				R[K, K] := Math.sqrt( Sum );
				Q[.. , K] := Q[.. , K] / R[K, K];
				R[K, K+1..] := Q[.. , K] * Q[.. , K+1..];
				Q[.., K+1..] := Q[.., K+1..] -Q[.., K] ** R[K, K+1..];
			END;
		END decompose;

		PROCEDURE backsubstitute( CONST b: Vector );
		VAR I, Ubound: SIZE;  Sum: Datatype;
		BEGIN
			Ubound := LEN( Q, 1 ) - 1;
			x := b*Q;
			x[Ubound] := x[Ubound] / R[Ubound, Ubound];
			FOR I := (Ubound - 1) TO 0 BY -1 DO
				Sum := R[I, I + 1..] +* x[I + 1..];
				x[I] := (x[I] - Sum) / R[I, I];
			END;
		END backsubstitute;

		PROCEDURE SolveNoCopy*( VAR A: Matrix;  CONST b: Vector ): Vector;   (** no internal matrix copying overhead; Initialize with zero size matrix for this case.  note: the matrix A is altered in this case; *)
		BEGIN
			Q := ALIAS OF A;
			decompose;  backsubstitute( b );  RETURN x
		END SolveNoCopy;

		PROCEDURE Solve*( CONST b: Vector ): Vector;
		BEGIN
			IF LEN(x,0)#LEN(Q,1) THEN NEW(x,LEN(Q,1)) ELSE x:=0 END;
			backsubstitute(b);
			RETURN x;
		END Solve;

		PROCEDURE SolveMultiple(CONST B: Matrix ): Matrix;
		VAR X:Matrix;
		BEGIN
			HALT(100); (* not yet implemented *)
			RETURN X
		END SolveMultiple;


	END QR;

	(* generic matrix solver for Ax=b;  choice of solver depends on geometry of data *)
	OPERATOR "\"*(CONST A:Matrix; CONST b:Vector):Vector;
	VAR qr:QR;
	BEGIN
		IF LEN(A,0)<LEN(A,1) THEN HALT(100); (* should be SVDSolve, or via QR decomposition of A` *)
		ELSE NEW(qr,A); RETURN qr.Solve(b)
		END;
	END "\";

	(*
	OPERATOR "\"*(CONST A:Matrix; CONST B:Matrix):Matrix;
	VAR qr: QR;
	BEGIN
		IF LEN(A,0)<LEN(A,1) THEN HALT(100); (* should be SVDSolve *)
		ELSIF LEN(A,0)=LEN(A,1) THEN
		ELSE NEW(qr,A); RETURN qr.SolveMultiple(B);
		END;
	END "\";
	*)

	(*-----*)
	PROCEDURE Sqr( x: Datatype ): Datatype;
	BEGIN
		RETURN x * x
	END Sqr;

	PROCEDURE sign( x: Datatype ): Datatype;
	BEGIN
		IF x > 0 THEN RETURN 1
		ELSIF x < 0 THEN RETURN -1
		ELSIF x = 0 THEN RETURN 0
		ELSE  (*NaN ?*) HALT( 100 );
		END;
	END sign;

	(*
	PROCEDURE ZEROCOPY( VAR A: Matrix ): Matrix;   (*dummy procedure in preparation of later compiler versions having a ZEROCOPY system procedure*)
	BEGIN
		RETURN A
	END ZEROCOPY;
	*)


	PROCEDURE MaxAbsV( CONST m: Vector ): Datatype;  (*to do: more generic approach*)

	BEGIN

		RETURN MAX(MAX(m),-MIN(m)) ; (*non-copying ABS(MAX(m))*)

	END MaxAbsV;


(*
	(* TO DO: implement fast small matrices*):
	(*to do: catch irregular cases like singular matrices*)
	PROCEDURE solve2x2(A:ARRAY [*,*] OF Datatype; b:ARRAY [*] OF Datatype);
	BEGIN
		x[0] := ((a11^-1)*(b1+(-1*a12/(a22-1*a21/a11*a12)*(b2-1*a21/a11*b1)))) ;
		x[1] := (((a22+(-1*a21/a11*a12))^-1)*(b2-1*a21/a11*b1));
	END solve2x2;

	PROCEDURE solve3x3(A:ARRAY [*,*] OF Datatype; b:ARRAY [*] OF Datatype);
	BEGIN
	END solve3x3;

	PROCEDURE solve4x4(A:ARRAY [*,*] OF Datatype; b:ARRAY [*] OF Datatype);
	BEGIN
	END solve4x4;
*)

(**-- Factory procedures and procedural interfaces for simple solving ---*)

	PROCEDURE CreateLU*( ): Base.Solver;   (*FactoryProcedure*)
	VAR lu: LU;  dummy: Matrix;
	BEGIN
		NEW( lu, dummy );  RETURN lu;
	END CreateLU;

	PROCEDURE SolveLU*( VAR A: Matrix;  CONST b: Vector ): Vector;   (*direct procedural solving; simplest use, but when using repeatedly, running into internal allocation overhead *)
	VAR lu: LU;  dummy: Matrix;
	BEGIN
		NEW( lu, dummy ); RETURN lu.SolveNoCopy( A, b );
	END SolveLU;

(*-----*)

	PROCEDURE CreateGauss*( ): Base.Solver;   (*FactoryProcedure*)
	VAR g: Gauss;  dummy: Matrix;
	BEGIN
		NEW( g, dummy );  RETURN g;
	END CreateGauss;

	PROCEDURE SolveGauss*( VAR A: Matrix;  CONST b: Vector ): Vector;   (*direct procedural solving; simplest use, but when using repeatedly, running into internal allocation overhead *)
	VAR g: Gauss;
	BEGIN
		NEW( g, A );  RETURN g.Solve( b );
	END SolveGauss;

	(*-----*)

	PROCEDURE CreateGaussJordan*( ): Base.Solver;   (*FactoryProcedure*)
	VAR gj: GaussJordan;  dummy: Matrix;
	BEGIN
		NEW( gj, dummy );  RETURN gj;
	END CreateGaussJordan;

	PROCEDURE SolveGaussJordan*( VAR A: Matrix;  CONST b: Vector ): Vector;   (*direct procedural solving; simplest use, but when using repeatedly, running into internal allocation overhead *)
	VAR gj: GaussJordan;
	BEGIN
		NEW( gj, A );  RETURN gj.Solve( b );
	END SolveGaussJordan;

	(*-----*)

	PROCEDURE CreateQR*( ): Base.Solver;   (*FactoryProcedure*)
	VAR qr: QR;  dummy: Matrix;
	BEGIN
		NEW( qr, dummy );  RETURN qr;
	END CreateQR;

	PROCEDURE SolveQR*( VAR A: Matrix;  CONST b: Vector ): Vector;   (*direct procedural solving; simplest use, but when using repeatedly, running into internal allocation overhead. Overwrites A ! *)
	VAR qr: QR;  dummy: Matrix;
	BEGIN
		NEW( qr, A );  RETURN qr.Solve( b );
	END SolveQR;


END MatrixStandardSolvers.
(*---------------------------------------------------*)

(*

MODULE MatrixDummyClient;
IMPORT Base:=MatrixBase;
TYPE Datatype=Base.Datatype;
		Vector=Base.Vector;
		Matrix=Base.Matrix;

	PROCEDURE DoProcedure;
	VAR A: Matrix;  b, x: Vector;
	BEGIN
		x := MatrixDummy.SolveXY( A, b );
	END DoProcedure;

	PROCEDURE DoObject;
	VAR A: Matrix;  b, c, d, x: Vector;  solver: Base.Solver;
	BEGIN
		solver := CreateXYSolver( A );  x := solver.Solve( b );  x := solver.Solve( c );
		solver.Init( B );  x := solver.Solve( d );
	END DoObject;

	PROCEDURE DoObjectExplicitErrorHandling;
	VAR A: Matrix;  b, c, d, x: Vector;  solver: Base.Solver;
	BEGIN
		solver := CreateXYSolver( A );  x := solver.Solve( b );
		IF solver.res = NOCONVERGENCE THEN  (*do something about it*) END;
	END DoObjectExplicitErrorHandling;

	PROCEDURE DoSpecificObject;
	VAR xySolver: XYSolver;
	BEGIN
		NEW( xySolver, A );  xySolver.SpecificActivities();  x := xySolver.Solve( b );
	END DoSpecificObject;



END MatrixDummyClient.

*)

OFormatter.Format *
fofPC.Compile \s *
PC.Compile \f *

