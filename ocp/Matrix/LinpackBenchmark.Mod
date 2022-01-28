MODULE LinpackBenchmark;   (**  AUTHOR "Patrick Hunziker"; PURPOSE "";  **)

(**
Use LinpackBenchmark.Test to assess the performance of your current hardware/software setup for various basic linear algebra operations for various data sizes.
Also, the Linpack algorithm performance is measured:

a) using a simple linear approach on a single CPU
b) using block-decomposition of the matrix (potentially making use of multithreaded linear algebra operations like MatMul, behind the scences)
c) using active objects (multiple threads/active objects working on block-decomposed algorithm)

If your platform has a MathArrayBaseOptimized.Mod implementation, it will be used for accelerated linear algebra

*)


IMPORT Objects, MatrixBase, MatrixStandardSolvers, MatrixBlockSolvers, MatrixUtilities, Kernel, Out:=KernelLog, MathL, MatrixFastMatrixMultiply;

TYPE
	Matrix = MatrixBase.Matrix;
	Vector = MatrixBase.Vector;


	PROCEDURE Transpose*( VAR A: Matrix );   (*BLOCKED APPROACH; 	is currently very slow - how about blockwise data transfers ? *)
	VAR block: Matrix;  i,  r, c,  r4, c4, b4: SIZE;
	BEGIN
		r := LEN( A,0 );  c := LEN( A, 1 );  r4 := LEN( A,0 ) + 3 DIV 4;
		c4 := LEN( A, 1 ) + 3 DIV 4;  b4 := MAX( r4, c4 );

		NEW( block, b4, b4 );
		FOR i := 0 TO 15 DO (* incomplete implementation*)
			block := A[.. b4 - 1, .. b4 - 1];
			A[.. b4 - 1, .. b4 - 1] := block`;
		END;
	END Transpose;

	(* compare linpack based on several programming paradigms *)
	PROCEDURE Linpack( size: SIGNED32; details:BOOLEAN);
	VAR A, A1, A2, B, C, R, dummy: Matrix;  x, b, r: Vector;  a,c, c1:FLOAT64;
		timer: Kernel.MilliTimer;  t, t1, i, j: SIGNED32;  loops:SIGNED32; ops, flops: FLOAT64;
		residual, result: FLOAT64;
		lu: MatrixStandardSolvers.LU; blu: MatrixBlockSolvers.LU; bluA:MatrixBlockSolvers.LUAgent;
		Strassen: MatrixFastMatrixMultiply.Strassen;
	BEGIN
		IF size < 40 THEN loops := 4000
		ELSIF size < 100 THEN loops := 200
		ELSIF size < 400 THEN loops:= 10
		ELSE loops:=1
		END;
		A := MatrixUtilities.RandomMatrix( size, size, MatrixUtilities.DiagDominant );
		A1 := A;  A2 := A;  B := A;
		R := MatrixUtilities.RandomMatrix( 1, size, MatrixUtilities.Uniform );  b := R[0, .. ];
		x := b;

		(*------------LU ----------------------*)
		(* use LU decomposition & solving as in  original LINPACK Benchmarch *)
		Out.Ln;
		Out.String( "size " );  Out.Int( size, 0 );  Out.Ln;  Out.String( "LU                 " );

		A := A1;
		NEW(lu,dummy);
		lu.Init(A1); (*make shure that all allocations are done here...*)
		Kernel.GC;
		Kernel.SetTimer( timer, 0 );
		FOR i := 0 TO loops-1 DO
			lu.Init(A1);
			(*x:=lu.Solve(b);*)
		END;
		t := Kernel.Elapsed( timer );   (*in ms*)
		x:=lu.Solve(b);
		ops := 2 / 3 * size * size * size + size * size;   (* computational cost of LU decomposition is 2/3 n^3 + n^2 *)
		r := A1 * x - b;  residual := MathL.sqrt( r +* r );
		flops := ops / (t / 1000);   (*per second*)
		flops := flops * loops;
		Out.String( "; time, flops, residual: " );  Out.String( " " );  Out.Int( t, 6 );  Out.String( "ms  " );
		MatrixUtilities.OutFloat( flops / 1000000, 12, 1 ,0);  Out.String( " MFLOPs  " );
		MatrixUtilities.OutFloat( residual, 12,6 ,0);  Out.Ln;
		Out.String("      time total; time row-row multplications; time matrix-vector multiplications: ");
		Out.Int(lu.timetotal,10); Out.Int(lu.timeRowRowMul,10); Out.Int(lu.timeMatVecMul,10); Out.Ln;
		lu:=NIL;
		(*------------Block LU ----------------------*)
		(* use LU decomposition & solving as in  original LINPACK Benchmarch *)
		Out.String( "Block LU       (Block 128)    " );

		A := A1;
		NEW(blu,dummy,128);
		blu.Init(A1,128); (*make shure that all allocations are done here...*)
		Kernel.GC;
		Kernel.SetTimer( timer, 0 );
		FOR i := 0 TO loops-1 DO
			(*A1:=A;*)
			blu.Init(A1,128);
			(*x:=blu.Solve(b);*)
		END;
		t := Kernel.Elapsed( timer );   (*in ms*)
		x:=blu.Solve(b);
		ops := 2 / 3 * size * size * size + size * size;   (* computational cost of LU decomposition is 2/3 n^3 + n^2 *)
		r := A1 * x - b;  residual := MathL.sqrt( r +* r );
		flops := ops / (t / 1000);   (*per second*)
		flops := flops * loops;
		Out.String( "; time, flops, residual: " );  Out.String( " " );  Out.Int( t, 6 );  Out.String( "ms  " );
		MatrixUtilities.OutFloat( flops / 1000000, 12, 1 ,0);  Out.String( " MFLOPs  " );
		MatrixUtilities.OutFloat( residual, 12,6 ,0);  Out.Ln;

		(*------------Block LU ----------------------*)
		(* use LU decomposition & solving as in  original LINPACK Benchmarch *)
		Out.String( "Block LU      (Block 256)   " );

		A := A1;
		NEW(blu,dummy,256);
		blu.Init(A1,256); (*make shure that all allocations are done here...*)
		Kernel.GC;
		Kernel.SetTimer( timer, 0 );
		FOR i := 0 TO loops-1 DO
			(*A1:=A;*)
			blu.Init(A1,256);
			(*x:=blu.Solve(b);*)
		END;
		t := Kernel.Elapsed( timer );   (*in ms*)
		x:=blu.Solve(b);
		ops := 2 / 3 * size * size * size + size * size;   (* computational cost of LU decomposition is 2/3 n^3 + n^2 *)
		r := A1 * x - b;  residual := MathL.sqrt( r +* r );
		flops := ops / (t / 1000);   (*per second*)
		flops := flops * loops;
		Out.String( "; time, flops, residual: " );  Out.String( " " );  Out.Int( t, 6 );  Out.String( "ms  " );
		MatrixUtilities.OutFloat( flops / 1000000, 12, 1 ,0);  Out.String( " MFLOPs  " );
		MatrixUtilities.OutFloat( residual, 12,6 ,0);  Out.Ln;

		(*------------Block LU ----------------------*)
		(* use LU decomposition & solving as in  original LINPACK Benchmarch *)
		Out.String( "Block LU        (Block 512)    " );

		A := A1;
		NEW(blu,dummy,512);
		blu.Init(A1,512); (*make shure that all allocations are done here...*)
		Kernel.GC;
		Kernel.SetTimer( timer, 0 );
		FOR i := 0 TO loops-1 DO
			(*A1:=A;*)
			blu.Init(A1,512);
			(*x:=blu.Solve(b);*)
		END;
		t := Kernel.Elapsed( timer );   (*in ms*)
		x:=blu.Solve(b);
		blu:=NIL;
		ops := 2 / 3 * size * size * size + size * size;   (* computational cost of LU decomposition is 2/3 n^3 + n^2 *)
		r := A1 * x - b;  residual := MathL.sqrt( r +* r );
		flops := ops / (t / 1000);   (*per second*)
		flops := flops * loops;
		Out.String( "; time, flops, residual: " );  Out.String( " " );  Out.Int( t, 6 );  Out.String( "ms  " );
		MatrixUtilities.OutFloat( flops / 1000000, 12, 1 ,0);  Out.String( " MFLOPs  " );
		MatrixUtilities.OutFloat( residual, 12,6 ,0);  Out.Ln;

		(*------------Block LU Agent----------------------*)
		(* use LU decomposition & solving as in  original LINPACK Benchmarch *)
		IF LEN(A1,0)>128 THEN
			Out.String( "Block LU  Agents  (Block 128)    " );

			A := A1;
			Kernel.GC;
			NEW(bluA,LEN(A1,0),128,NIL, Objects.High);
			 (*make shure that all allocations are done here...*)
			Kernel.SetTimer( timer, 0 );
			FOR i := 0 TO 0 (*loops-1*) DO
				(*A1:=A;*)
				bluA.Set(A1);
				(*x:=bluA.Solve(b);*)
			END;
			t := Kernel.Elapsed( timer );   (*in ms*)
			x:=bluA.Solve(b);
			A1:=A;

			ops := 2 / 3 * size * size * size + size * size;   (* computational cost of LU decomposition is 2/3 n^3 + n^2 *)
			r := A1 * x - b;  residual := MathL.sqrt( r +* r );
			flops := ops / (t / 1000);   (*per second*)
			(*flops := flops * loops;*)
			Out.String( "; time, flops, residual: " );  Out.String( " " );  Out.Int( t, 6 );  Out.String( "ms  " );
			MatrixUtilities.OutFloat( flops / 1000000, 12, 1 ,0);  Out.String( " MFLOPs  " );
			MatrixUtilities.OutFloat( residual, 12,6 ,0);  Out.Ln;
		END;
		(*------------Block LU Agent----------------------*)
		(* use LU decomposition & solving as in  original LINPACK Benchmarch *)
		IF LEN(A1,0)>256 THEN
			Out.String( "Block LU  Agents  (Block 256)    " );

			A := A1;
			Kernel.GC;
			NEW(bluA,LEN(A1,0),256,NIL, Objects.High);
			 (*make shure that all allocations are done here...*)
			Kernel.SetTimer( timer, 0 );
			FOR i := 0 TO 0 (*loops-1*) DO
				(*A1:=A;*)
				bluA.Set(A1);
				(*x:=bluA.Solve(b);*)
			END;
			t := Kernel.Elapsed( timer );   (*in ms*)

			x:=bluA.Solve(b);
			A1:=A;
			ops := 2 / 3 * size * size * size + size * size;   (* computational cost of LU decomposition is 2/3 n^3 + n^2 *)
			r := A1 * x - b;  residual := MathL.sqrt( r +* r );
			flops := ops / (t / 1000);   (*per second*)
			(*flops := flops * loops;*)
			Out.String( "; time, flops, residual: " );  Out.String( " " );  Out.Int( t, 6 );  Out.String( "ms  " );
			MatrixUtilities.OutFloat( flops / 1000000, 12, 1 ,0);  Out.String( " MFLOPs  " );
			MatrixUtilities.OutFloat( residual, 12,6 ,0);  Out.Ln;
		END;
		(*------------Block LU Agent----------------------*)
		(* use LU decomposition & solving as in  original LINPACK Benchmarch *)
		IF LEN(A1,0)>512 THEN
			Out.String( "Block LU  Agents (Block 512)    " );

			A := A1;
			Kernel.GC;
			NEW(bluA,LEN(A1,0),512,NIL, Objects.High);
			 (*make shure that all allocations are done here...*)
			Kernel.SetTimer( timer, 0 );
			FOR i := 0 TO 0 (*loops-1*) DO
				(*A1:=A;*)
				bluA.Set(A1);
				(*x:=bluA.Solve(b);*)
			END;
			t := Kernel.Elapsed( timer );   (*in ms*)
			x:=bluA.Solve(b);
			A1:=A;

			bluA:=NIL;
			Kernel.GC;
			ops := 2 / 3 * size * size * size + size * size;   (* computational cost of LU decomposition is 2/3 n^3 + n^2 *)
			r := A1 * x - b;  residual := MathL.sqrt( r +* r );
			flops := ops / (t / 1000);   (*per second*)
			(*flops := flops * loops;*)
			Out.String( "; time, flops, residual: " );  Out.String( " " );  Out.Int( t, 6 );  Out.String( "ms  " );
			MatrixUtilities.OutFloat( flops / 1000000, 12, 1 ,0);  Out.String( " MFLOPs  " );
			MatrixUtilities.OutFloat( residual, 12,6 ,0);  Out.Ln;
		END;
		(*---------------- AssignVector -----------------*)
		IF details THEN
			Out.String( "Assign Vector         " );

			Kernel.SetTimer( timer, 0 );

			FOR i := 0 TO size * size - 1 DO b := x;  END;

			t := Kernel.Elapsed( timer );   (*in ms*)

			ops := 1.0 * size * size * size;   (*cost of matrix multiply; using k=2 *)
			flops := ops / (t / 1000);   (*per second*)
			Out.String( "; time, flops: " );  Out.String( " " );  Out.Int( t, 6 );  Out.String( "ms  " );
			MatrixUtilities.OutFloat( flops / 1000000, 12, 1 ,0);  Out.String( " 'MFLOPs'  " );  Out.Ln;


			(*---------------- AssignMatrix -----------------*)

			Out.String( "Assign Matrix         " );

			Kernel.SetTimer( timer, 0 );

			FOR i := 0 TO size - 1 DO A := A1;  END;

			t := Kernel.Elapsed( timer );   (*in ms*)

			ops := 1.0 * size * size * size;   (*cost of matrix multiply; using k=2 *)
			flops := ops / (t / 1000);   (*per second*)
			Out.String( "; time, flops: " );  Out.String( " " );  Out.Int( t, 6 );  Out.String( "ms  " );
			MatrixUtilities.OutFloat( flops / 1000000, 12, 1 ,0);  Out.String( " 'MFLOPs'  " );  Out.Ln;
					(*---------------- Scalar Operations -----------------*)

			Out.String( "Scalar operations         " );

			Kernel.SetTimer( timer, 0 );

			FOR i := 0 TO size*size*size DIV 10 - 1 DO c1 := c+c+c+c+c+c+c+c+c +c  ;  END;

			t := Kernel.Elapsed( timer );   (*in ms*)

			ops := 1.0 * size * size * size;   (* *)
			flops := ops / (t / 1000);   (*per second*)
			Out.String( "; time, flops: " );  Out.String( " " );  Out.Int( t, 6 );  Out.String( "ms  " );
			MatrixUtilities.OutFloat( flops / 1000000, 12, 1 ,0);  Out.String( " 'MFLOPs'  " );  Out.Ln;

				(*---------------- Loops -----------------*)

			Out.String( "Loops         " );

			Kernel.SetTimer( timer, 0 );

			FOR i := 0 TO size*size*size - 1 DO   END;

			t := Kernel.Elapsed( timer );   (*in ms*)

			ops := 1.0 * size * size * size;   (*cost of empty loop (implicit increment of loop counter, comparison, and jump)*)
			flops := ops / (t / 1000);   (*per second*)
			Out.String( "; time, flops: " );  Out.String( " " );  Out.Int( t, 6 );  Out.String( "ms  " );
			MatrixUtilities.OutFloat( flops / 1000000, 12, 1 ,0);  Out.String( " 'MFLOPs'  " );  Out.Ln;
		END;

		(*----------------MatMul------------------*)

		Out.String( "MatMul         " );
		Kernel.GC;
		Kernel.SetTimer( timer, 0 );
		B := A1 * A;
		t := Kernel.Elapsed( timer );   (*in ms*)

		ops := 2.0 * size * size * size;   (*cost of matrix multiply; using k=2 *)
		flops := ops / (t / 1000);   (*per second*)
		Out.String( "; time, flops: " );  Out.String( " " );  Out.Int( t, 6 );  Out.String( "ms  " );
		MatrixUtilities.OutFloat( flops / 1000000, 12, 1 ,0);  Out.String( " MFLOPs  " );  Out.Ln;

		(*----------------SGEMM------------------*)

		Out.String( "SGEMM         " );
		Kernel.GC;
		Kernel.SetTimer( timer, 0 );


		B := a *B + c * A1 * A;
		t := Kernel.Elapsed( timer );   (*in ms*)

		ops := 2.0 * size * size * size + 3 * size*size ;   (*cost of matrix multiply; using k=2 *)
		flops := ops / (t / 1000);   (*per second*)
		Out.String( "; time, flops: " );  Out.String( " " );  Out.Int( t, 6 );  Out.String( "ms  " );
		MatrixUtilities.OutFloat( flops / 1000000, 12, 1 ,0);  Out.String( " MFLOPs  " );  Out.Ln;

		(*----------------SGEMM------------------*)

		Out.String( "SGEMM variant 2        " );
		Kernel.GC;
		Kernel.SetTimer( timer, 0 );

		C:=A1 * A;
		C:=c*C;
		B:=a*B;
		B:=B+C;
		(*B := a *B + c * A1 * A;  *)
		t := Kernel.Elapsed( timer );   (*in ms*)

		ops := 2.0 * size * size * size + 3 * size*size ;   (*cost of matrix multiply; using k=2 *)
		flops := ops / (t / 1000);   (*per second*)
		Out.String( "; time, flops: " );  Out.String( " " );  Out.Int( t, 6 );  Out.String( "ms  " );
		MatrixUtilities.OutFloat( flops / 1000000, 12, 1 ,0);  Out.String( " MFLOPs  " );  Out.Ln;

		(*----------------Fast MatMul (Strassen')------------------*)

		Out.String( "MatMul (Strassen Algo) " );
		NEW(Strassen);
		Strassen.Multiply(A1,A,B);
		Kernel.GC;
		Kernel.SetTimer( timer, 0 );
		Strassen.Multiply(A1,A,B);
		t1 := Kernel.Elapsed( timer );   (*in ms*)

		Out.String( "; time: " );  Out.String( " " );  Out.Int( t1, 6 );  Out.String( "ms  " );
		Out.String( "speedup to MatMul  " ); MatrixUtilities.OutFloat( t/t1, 12, 2,0); Out.Ln;

IF details THEN
		(*----------------MatMul Transposed------------------*)

		Out.String( "MatMul   A*A`      " );

		Kernel.SetTimer( timer, 0 );  B := A * A`;
		t := Kernel.Elapsed( timer );   (*in ms*)

		ops := 2.0 * size * size * size;   (*cost of matrix multiply; using k=2 *)
		flops := ops / (t / 1000);   (*per second*)
		Out.String( "; time, flops: " );  Out.String( " " );  Out.Int( t, 6 );  Out.String( "ms  " );
		MatrixUtilities.OutFloat( flops / 1000000, 12, 1 ,0);  Out.String( " MFLOPs  " );  Out.Ln;

		(*----------------MatMul Transposed B------------------*)

		Out.String( "MatMul   A`*A      " );

		Kernel.SetTimer( timer, 0 );  B := A` * A;
		t := Kernel.Elapsed( timer );   (*in ms*)

		ops := 2.0 * size * size * size;   (*cost of matrix multiply; using k=2 *)
		flops := ops / (t / 1000);   (*per second*)
		Out.String( "; time, flops: " );  Out.String( " " );  Out.Int( t, 6 );  Out.String( "ms  " );
		MatrixUtilities.OutFloat( flops / 1000000, 12, 1 ,0);  Out.String( " MFLOPs  " );  Out.Ln;

		(*----------------MatMul Transposed C------------------*)

		Out.String( "MatMul   A`*A`      " );

		Kernel.SetTimer( timer, 0 );  B := A` * A`;
		t := Kernel.Elapsed( timer );   (*in ms*)

		ops := 2.0 * size * size * size;   (*cost of matrix multiply; using k=2 *)
		flops := ops / (t / 1000);   (*per second*)
		Out.String( "; time, flops: " );  Out.String( " " );  Out.Int( t, 6 );  Out.String( "ms  " );
		MatrixUtilities.OutFloat( flops / 1000000, 12, 1 ,0);  Out.String( " MFLOPs  " );  Out.Ln;


		(*-----------------InnerProduct-----------------*)
		Out.String( "InnerProd Matrix " );

		Kernel.SetTimer( timer, 0 );
		FOR i := 0 TO size - 1 DO result := A +* A;  END;

		t := Kernel.Elapsed( timer );   (*in ms*)

		ops := 2.0 * size * size * size;   (*cost of inner product *)
		flops := ops / (t / 1000);   (*per second*)
		Out.String( "; time, flops: " );  Out.String( " " );  Out.Int( t, 6 );  Out.String( "ms  " );
		MatrixUtilities.OutFloat( flops / 1000000, 12, 1 ,0);  Out.String( " MFLOPs  " );  Out.Ln;

		(*-----------------InnerProduct blockwise-----------------*)
		Out.String( "InnerProd Matrix blockwise" );

		Kernel.SetTimer( timer, 0 );
		FOR i := 0 TO size - 1 DO
			result := A[.. size DIV 4 - 1] +* A[.. size DIV 4 - 1];
			result :=
				result + A[size DIV 4..size DIV 2 - 1] +* A[size DIV 4..size DIV 2 - 1];
			result :=
				result +
				A[size DIV 2..3 * size DIV 4 - 1] +* A[size DIV 2..3 * size DIV 4 - 1];
			result := result + A[3 * size DIV 4..] +* A[3 * size DIV 4..];
		END;

		t := Kernel.Elapsed( timer );   (*in ms*)

		ops := 2.0 * size * size * size;   (*cost of inner product *)
		flops := ops / (t / 1000);   (*per second*)
		Out.String( "; time, flops: " );  Out.String( " " );  Out.Int( t, 6 );  Out.String( "ms  " );
		MatrixUtilities.OutFloat( flops / 1000000, 12, 1 ,0);  Out.String( " MFLOPs  " );  Out.Ln;


		(*-----------------InnerProduct-----------------*)
		Out.String( "InnerProd Vector " );

		Kernel.SetTimer( timer, 0 );
		FOR i := 0 TO size * size - 1 DO result := b +* b;  END;

		t := Kernel.Elapsed( timer );   (*in ms*)

		ops := 2.0 * size * size * size;   (*cost of inner product *)
		flops := ops / (t / 1000);   (*per second*)
		Out.String( "; time, flops: " );  Out.String( " " );  Out.Int( t, 6 );  Out.String( "ms  " );
		MatrixUtilities.OutFloat( flops / 1000000, 12, 1 ,0);  Out.String( " MFLOPs  " );  Out.Ln;
		(*-----------------InnerProduct-----------------*)
		Out.String( "InnerProd Vector part " );

		Kernel.SetTimer( timer, 0 );
		FOR i := 0 TO size * size - 1 DO result := b[1..size - 2] +* b[1..size - 2];  END;

		t := Kernel.Elapsed( timer );   (*in ms*)

		ops := 2.0 * size * size * (size - 2);   (*cost of inner product *)
		flops := ops / (t / 1000);   (*per second*)
		Out.String( "; time, flops: " );  Out.String( " " );  Out.Int( t, 6 );  Out.String( "ms  " );
		MatrixUtilities.OutFloat( flops / 1000000, 12, 1 ,0);  Out.String( " MFLOPs  " );  Out.Ln;


		(*-----------------InnerProduct Row-----------------*)
		Out.String( "InnerProd Row     " );

		Kernel.SetTimer( timer, 0 );
		FOR i := 0 TO size - 1 DO
			FOR j := 0 TO size - 1 DO result := A[j, .. ] +* A[j, .. ];  END;
		END;

		t := Kernel.Elapsed( timer );   (*in ms*)

		ops := 2.0 * size * size * size;   (*cost of inner product *)
		flops := ops / (t / 1000);   (*per second*)
		Out.String( "; time, flops: " );  Out.String( " " );  Out.Int( t, 6 );  Out.String( "ms  " );
		MatrixUtilities.OutFloat( flops / 1000000, 12, 1 ,0);  Out.String( " MFLOPs  " );  Out.Ln;


		(*-----------------InnerProduct Column-----------------*)
		Out.String( "InnerProd Column  " );

		Kernel.SetTimer( timer, 0 );
		FOR i := 0 TO size - 1 DO
			FOR j := 0 TO size - 1 DO result := A[.. , j] +* A[.. , j];  END;
		END;

		t := Kernel.Elapsed( timer );   (*in ms*)

		ops := 2.0 * size * size * size;   (*cost of inner product *)
		flops := ops / (t / 1000);   (*per second*)
		Out.String( "; time, flops: " );  Out.String( " " );  Out.Int( t, 6 );  Out.String( "ms  " );
		MatrixUtilities.OutFloat( flops / 1000000, 12, 1 ,0);  Out.String( " MFLOPs  " );  Out.Ln;

		(*----------------Transpose-----------------*)
		Out.String( "Transpose  " );

		Kernel.SetTimer( timer, 0 );
		FOR i := 0 TO size - 1 DO B := A`;  END;

		t := Kernel.Elapsed( timer );   (*in ms*)

		ops := 1.0 * size * size * size;   (*cost of inner product *)
		flops := ops / (t / 1000);   (*per second*)
		Out.String( "; time, flops: " );  Out.String( " " );  Out.Int( t, 6 );  Out.String( "ms  " );
		MatrixUtilities.OutFloat( flops / 1000000, 12, 1 ,0);  Out.String( " 'MFLOPs '  " );  Out.Ln;

		(*----------------Transpose-----------------*)
		Out.String( "TransposeExplicit  " );

		Kernel.SetTimer( timer, 0 );
		FOR i := 0 TO size - 1 DO TransposeExplicit(A);  END;

		t := Kernel.Elapsed( timer );   (*in ms*)

		ops := 1.0 * size * size * size;   (*cost of inner product *)
		flops := ops / (t / 1000);   (*per second*)
		Out.String( "; time, flops: " );  Out.String( " " );  Out.Int( t, 6 );  Out.String( "ms  " );
		MatrixUtilities.OutFloat( flops / 1000000, 12, 1 ,0);  Out.String( " 'MFLOPs '  " );  Out.Ln;

	END;
		(*----------------Transpose blockwise-----------------*)
		(*
	Out.String("Transpose blockwise ");

	Kernel.SetTimer(timer,0);
	FOR i:=0 TO size-1 DO
		Transpose(A);
	END;

	t:=Kernel.Elapsed(timer); (*in ms*)

	ops:= 1.0 * size * size * size; (*cost of inner product *)
	flops := ops /  (t/1000); (*per second*)
	Out.String("; time, flops: ");
	Out.String(" "); Out.Int(t,6); Out.String("ms  ");
	(flops/1000000,12,1); Out.String(" 'MFLOPs '  ");
	Out.Ln;
*)

		(*-----------------MatrixVectorProduct-----------------*)
		Out.String( "Matrix Vector Product  " );

		Kernel.SetTimer( timer, 0 );
		FOR i := 0 TO size - 1 DO r := A * b;  END;

		t := Kernel.Elapsed( timer );   (*in ms*)

		ops := 2.0 * size * size * size;
		flops := ops / (t / 1000);   (*per second*)
		Out.String( "; time, flops: " );  Out.String( " " );  Out.Int( t, 6 );  Out.String( "ms  " );
		MatrixUtilities.OutFloat( flops / 1000000, 12, 1 ,0);  Out.String( " MFLOPs  " );  Out.Ln;


		(*-----------------VectorMatrixProduct-----------------*)
		Out.String( "Vector Matrix Product  " );

		Kernel.SetTimer( timer, 0 );
		FOR i := 0 TO size - 1 DO r := b * A;  END;

		t := Kernel.Elapsed( timer );   (*in ms*)

		ops := 2.0 * size * size * size;
		flops := ops / (t / 1000);   (*per second*)
		Out.String( "; time, flops: " );  Out.String( " " );  Out.Int( t, 6 );  Out.String( "ms  " );
		MatrixUtilities.OutFloat( flops / 1000000, 12, 1 ,0);  Out.String( " MFLOPs  " );  Out.Ln;

 	IF details THEN
		(*-----------------Transposed VectorMatrixProduct-----------------*)
		Out.String( "Transposed Vector Matrix Product A`* v instead of v * A " );

		Kernel.SetTimer( timer, 0 );
		FOR i := 0 TO size - 1 DO r := A` * b;  END;

		t := Kernel.Elapsed( timer );   (*in ms*)

		ops := 2.0 * size * size * size;
		flops := ops / (t / 1000);   (*per second*)
		Out.String( "; time, flops: " );  Out.String( " " );  Out.Int( t, 6 );  Out.String( "ms  " );
		MatrixUtilities.OutFloat( flops / 1000000, 12, 1 ,0);  Out.String( " MFLOPs  " );  Out.Ln;

END;

		(*-----------------Inc Mul Matrix-----------------*)
		Out.String( "multiply-add (Matrix,Matrix,Matrix)  " );

		Kernel.SetTimer( timer, 0 );
		(*INCMUL(B,A,A1);*)
		B := B + A * A1;
		t := Kernel.Elapsed( timer );   (*in ms*)

		ops := 2.0 * size * size * size + size*size;
		flops := ops / (t / 1000);   (*per second*)
		Out.String( "; time, flops: " );  Out.String( " " );  Out.Int( t, 6 );  Out.String( "ms  " );
		MatrixUtilities.OutFloat( flops / 1000000, 12, 1 ,0);  Out.String( " MFLOPs  " );  Out.Ln;

		(*-----------------Dec Mul Matrix-----------------*)
		Out.String( "multiply-substract (Matrix,-Matrix,Matrix)  " );

		Kernel.SetTimer( timer, 0 );
		(*INCMUL(B,-A,A1);*)
		B := B - A * A1;

		t := Kernel.Elapsed( timer );   (*in ms*)

		ops := 2.0 * size * size * size + size*size;
		flops := ops / (t / 1000);   (*per second*)
		Out.String( "; time, flops: " );  Out.String( " " );  Out.Int( t, 6 );  Out.String( "ms  " );
		MatrixUtilities.OutFloat( flops / 1000000, 12, 1 ,0);  Out.String( " MFLOPs  " );  Out.Ln;





		(*-----------------Inc Mul Vector-Matrix-----------------*)
		Out.String( "multiply-add (Vector,Vector,Matrix)  " );

		Kernel.SetTimer( timer, 0 );
		FOR i := 0 TO size - 1 DO
		(*INCMUL(b,x,A1);*)
			b := b + x * A1;
		END;

		t := Kernel.Elapsed( timer );   (*in ms*)

		ops := 2.0 * size * size * size + size * size;
		flops := ops / (t / 1000);   (*per second*)
		Out.String( "; time, flops: " );  Out.String( " " );  Out.Int( t, 6 );  Out.String( "ms  " );
		MatrixUtilities.OutFloat( flops / 1000000, 12, 1 ,0);  Out.String( " MFLOPs  " );  Out.Ln;



		(*-----------------Inc Mul (Vector,Matrix,Vector) -----------------*)
		Out.String( "multiply-add (Vector,Matrix,Vector)  " );

		Kernel.SetTimer( timer, 0 );
		FOR i := 0 TO size - 1 DO
		(*INCMUL(b,A1,x);*)
			b := b + A1 * x
		END;

		t := Kernel.Elapsed( timer );   (*in ms*)

		ops := 2.0 * size * size * size + size * size;
		flops := ops / (t / 1000);   (*per second*)
		Out.String( "; time, flops: " );  Out.String( " " );  Out.Int( t, 6 );  Out.String( "ms  " );
		MatrixUtilities.OutFloat( flops / 1000000, 12, 1 ,0);  Out.String( " MFLOPs  " );  Out.Ln;

		(*-----------------Dec Mul (Vector,Matrix,Vector) -----------------*)
		Out.String( "multiply-subtract (Vector,Matrix,Vector)  " );

		Kernel.SetTimer( timer, 0 );
		FOR i := 0 TO size - 1 DO
		(*INCMUL(b,A1,x);*)
			b := b - A1 * x
		END;

		t := Kernel.Elapsed( timer );   (*in ms*)

		ops := 2.0 * size * size * size + size * size;
		flops := ops / (t / 1000);   (*per second*)
		Out.String( "; time, flops: " );  Out.String( " " );  Out.Int( t, 6 );  Out.String( "ms  " );
		MatrixUtilities.OutFloat( flops / 1000000, 12, 1 ,0);  Out.String( " MFLOPs  " );  Out.Ln;

(*-----------------Dec Mul (Vector,Vector,Matrix) -----------------*)
		Out.String( "multiply-subtract (Vector,Vector,Matrix)  " );

		Kernel.SetTimer( timer, 0 );
		FOR i := 0 TO size - 1 DO
		(*INCMUL(b,A1,x);*)
			b := b - x * A1
		END;

		t := Kernel.Elapsed( timer );   (*in ms*)

		ops := 2.0 * size * size * size + size * size;
		flops := ops / (t / 1000);   (*per second*)
		Out.String( "; time, flops: " );  Out.String( " " );  Out.Int( t, 6 );  Out.String( "ms  " );
		MatrixUtilities.OutFloat( flops / 1000000, 12, 1 ,0);  Out.String( " MFLOPs  " );  Out.Ln;

(*-----------------Inc Mul outer (Matrix,Vector,Vector) -----------------*)
	IF details THEN


		Out.String( "Inc Mul Outer (Matrix,Vector,Vector)  " );

		Kernel.SetTimer( timer, 0 );
		FOR i := 0 TO size - 1 DO
		(*INCMUL(b,A1,x);*)
			A := A + x ** x
		END;

		t := Kernel.Elapsed( timer );   (*in ms*)

		ops := 2.0 * size * size * size + size * size;
		flops := ops / (t / 1000);   (*per second*)
		Out.String( "; time, flops: " );  Out.String( " " );  Out.Int( t, 6 );  Out.String( "ms  " );
		MatrixUtilities.OutFloat( flops / 1000000, 12, 1 ,0);  Out.String( " MFLOPs  " );  Out.Ln;
(*
(*-----------------DecMul outer (Matrix,Vector,Vector) -----------------*)
		Out.String( "Dec Mul Outer (Matrix,Vector,Vector)  " );

		Kernel.SetTimer( timer, 0 );
		FOR i := 0 TO size - 1 DO
		(*INCMUL(b,A1,x);*)
			A := A -  x ** x
		END;

		t := Kernel.Elapsed( timer );   (*in ms*)

		ops := 2.0 * size * size * size + size * size;
		flops := ops / (t / 1000);   (*per second*)
		Out.String( "; time, flops: " );  Out.String( " " );  Out.Int( t, 6 );  Out.String( "ms  " );
		MatrixUtilities.OutFloat( flops / 1000000, 12, 1 ,0);  Out.String( " MFLOPs  " );  Out.Ln;
*)

		(*-----------------MultiplyAdd (Vector,Skalar,Vector) -----------------*)
		Out.String( "multiply-add (Vector,Skalar,Vector)  " );  c := 0.1;

		Kernel.SetTimer( timer, 0 );
		FOR i := 0 TO size * size - 1 DO
		(*INCMUL(b,A1,x);*)
			b := b + c * x
		END;

		t := Kernel.Elapsed( timer );   (*in ms*)

		ops := 1.0 * size * size * size  + size*size;
		flops := ops / (t / 1000);   (*per second*)
		Out.String( "; time, flops: " );  Out.String( " " );  Out.Int( t, 6 );  Out.String( "ms  " );
		MatrixUtilities.OutFloat( flops / 1000000, 12, 1 ,0);  Out.String( " MFLOPs  " );  Out.Ln;

		(*-----------------MultiplyAdd (Vector,Vector, Skalar) -----------------*)
		Out.String( "multiply-add (Vector,Vector, Skalar)  " );  c := 0.1;  Kernel.SetTimer( timer, 0 );
		FOR i := 0 TO size * size - 1 DO
		(*INCMUL(b,A1,x);*)
			b := b + x * c
		END;

		t := Kernel.Elapsed( timer );   (*in ms*)

		ops := 1.0*size * size * size + size*size;
		flops := ops / (t / 1000);   (*per second*)
		Out.String( "; time, flops: " );  Out.String( " " );  Out.Int( t, 6 );  Out.String( "ms  " );
		MatrixUtilities.OutFloat( flops / 1000000, 12, 1 ,0);  Out.String( " MFLOPs  " );  Out.Ln;

		(*-----------------Multiply(Vector, Skalar) -----------------*)
		Out.String( "multiply (Vector,Skalar)  " );  c := 0.1;  Kernel.SetTimer( timer, 0 );
		FOR i := 0 TO size * size - 1 DO
		(*INCMUL(b,A1,x);*)
			b := x * c
		END;

		t := Kernel.Elapsed( timer );   (*in ms*)

		ops := 1.0 * size * size * size;
		flops := ops / (t / 1000);   (*per second*)
		Out.String( "; time, flops: " );  Out.String( " " );  Out.Int( t, 6 );  Out.String( "ms  " );
		MatrixUtilities.OutFloat( flops / 1000000, 12, 1 ,0);  Out.String( " MFLOPs  " );  Out.Ln;

		(*-----------------Multiply  (Skalar,Matrix) -----------------*)
		Out.String( "multiply (Skalar,Matrix)  " );  c := 0.1;  Kernel.SetTimer( timer, 0 );
		FOR i := 0 TO size - 1 DO B := c * A END;

		t := Kernel.Elapsed( timer );   (*in ms*)

		ops := 1.0*size * size * size;
		flops := ops / (t / 1000);   (*per second*)
		Out.String( "; time, flops: " );  Out.String( " " );  Out.Int( t, 6 );  Out.String( "ms  " );
		MatrixUtilities.OutFloat( flops / 1000000, 12, 1 ,0);  Out.String( " MFLOPs  " );  Out.Ln;


		(*-----------------MultiplyAdd (Matrix,Skalar,Matrix) -----------------*)
		Out.String( "multiply-add (Matrix,Skalar,Matrix)  " );  c := 0.1;  Kernel.SetTimer( timer, 0 );
		FOR i := 0 TO size - 1 DO
		(*INCMUL(b,A1,x);*)
			B := B + c * A
		END;

		t := Kernel.Elapsed( timer );   (*in ms*)

		ops := 2.0 * size * size * size;
		flops := ops / (t / 1000);   (*per second*)
		Out.String( "; time, flops: " );  Out.String( " " );  Out.Int( t, 6 );  Out.String( "ms  " );
		MatrixUtilities.OutFloat( flops / 1000000, 12, 1 ,0);  Out.String( " MFLOPs  " );  Out.Ln;
	END;
		(*	Timing.Calibrate;  *)


	END Linpack;

	(* Linpack based on Block LU algorithms implemented with active objects *)
	PROCEDURE LinpackBlockLUA( size: SIGNED32; details:BOOLEAN);
	VAR A, A1,  R: Matrix;  x, b, r: Vector;
		timer: Kernel.MilliTimer;  t,t0,  t1, i, j: SIGNED32;  loops:SIGNED32; ops, flops0, flops, flops1: FLOAT64;
		residual: FLOAT64;
		lu: MatrixStandardSolvers.LU; blu: MatrixBlockSolvers.LU; bluA:MatrixBlockSolvers.LUAgent;
		blocksize:SIGNED32;
	BEGIN
		IF size < 40 THEN loops := 3000
		ELSIF size < 100 THEN loops := 500
		ELSIF size < 400 THEN loops:= 50
		ELSE loops:=1
		END;
		blocksize:=size DIV 16;
		FOR j:=0 TO 3 DO
			Out.Int(size,8); Out.Int(blocksize,8); Out.String("  ");
			A := MatrixUtilities.RandomMatrix( size, size, MatrixUtilities.DiagDominant );
			R := MatrixUtilities.RandomMatrix( 1, size, MatrixUtilities.Uniform );  b := R[0, .. ];
			x := b;
			(* use LU decomposition & solving as in  original LINPACK Benchmarch *)
			Out.String( " LU: {direct - Block - Block Agents}   " );

			Kernel.GC;
			A1:=A;
			NEW(lu,A1);
			Kernel.SetTimer( timer, 0 );
			FOR i := 0 TO 0 (*loops-1*) DO
				A1:=A;
				lu.Init(A1);
			END;
			t0 := Kernel.Elapsed( timer );   (*in ms*)
			x:=lu.Solve(b);

			Kernel.GC;


			A := MatrixUtilities.RandomMatrix( size, size, MatrixUtilities.DiagDominant );
			NEW(blu,A,blocksize);
			Kernel.SetTimer( timer, 0 );
			FOR i := 0 TO 0 (*loops-1*) DO
				(*A1:=A;*)
				blu.Init(A,blocksize);
				END;
			t := Kernel.Elapsed( timer );   (*in ms*)
			x:=blu.Solve(b);
			blu:=NIL;
			Kernel.GC;

			NEW(bluA,LEN(A,0),blocksize,NIL, Objects.High);
			 (*make shure that all allocations are done here...*)
			Kernel.SetTimer( timer, 0 );
			FOR i := 0 TO 0 (*loops-1*) DO
				(*A1:=A;*)
				bluA.Set(A);
				END;
			t1 := Kernel.Elapsed( timer );   (*in ms*)
			x:=bluA.Solve(b);
			bluA:=NIL;
			Kernel.GC;
			ops := 2 / 3 * size * size * size + size * size;   (* computational cost of LU decomposition is 2/3 n^3 + n^2 *)
			(*r := A1 * x - b;*)  residual := MathL.sqrt( r +* r );
			flops0 := ops / (t0 / 1000);
			flops := ops / (t / 1000);   (*per second*)
			flops1 := ops / (t1 / 1000);   (*per second*)
			(*flops := flops * loops;*)
			Out.String( "; time, flops, residual: " );  Out.String( " {" );  Out.Int( t0, 6 );   Out.Int( t, 6 );  Out.Int( t1, 6 ); Out.String( "} ms  {" );
			MatrixUtilities.OutFloat( flops0 / 1000000, 12, 1 ,0);
			MatrixUtilities.OutFloat( flops / 1000000, 12, 1 ,0);
			MatrixUtilities.OutFloat( flops1 / 1000000, 12, 1 ,0);  Out.String( "} MFLOPs  " );
			MatrixUtilities.OutFloat( residual, 12,6 ,0);
			IF ABS(residual)>0.0001 THEN Out.String(" block solvers are not unconditionally stable for small blocks..."); END;
			Out.Ln;
			blocksize:=2*blocksize;
		END;
	END LinpackBlockLUA;

	PROCEDURE Linpack1000d*;
	BEGIN
		Linpack( 1000, FALSE);
	END Linpack1000d;

PROCEDURE TransposeExplicit(VAR a: Matrix);
VAR
	b,c: Vector;
	i,j, len:SIZE;
	res:FLOAT64;
BEGIN
	NEW(b, LEN(a,1));
	FOR i:=0 TO LEN(a,0)-1 DO
		len:=LEN(a,1)-i-1;
		b[i+1..]:=a[i,i+1..];
		a[i,i+1..]:=a[i+1..,i];
		a[i+1..,i]:=b[i+1..]
	END;
END TransposeExplicit;


(** Test Performance of various linear algebra operations*)
	PROCEDURE Test*;
	BEGIN
		(*Linpack( 16 , TRUE); Linpack( 32 , TRUE);  Linpack( 64 , TRUE);  Linpack( 128, TRUE );  Linpack( 256, TRUE);  *)
		Linpack( 512 , TRUE);  Linpack( 1024, FALSE);
		Linpack(2048, FALSE);  (*Linpack(2560, FALSE);
		Linpack(3072, FALSE); Linpack(3584, FALSE);
		Linpack(4096, FALSE); *)
	END Test;

	(** compare performance of three approaches to LU decomposition: a) direct, b) block operators, and c) active objects performing block operations *)
	PROCEDURE TestLUA*;
	BEGIN
		LinpackBlockLUA(  64, TRUE);
		LinpackBlockLUA( 128, TRUE );  LinpackBlockLUA( 256, TRUE);  LinpackBlockLUA( 512 , TRUE);
		LinpackBlockLUA( 1024, FALSE);  LinpackBlockLUA(2048, FALSE); (*LinpackBlockLUA(4096, FALSE);*) (* LinpackBlockLUA(8192, FALSE); *) (*4096 is long-running, 8192 freezes*)
	END TestLUA;

	(** test performance of matrix multiplication as a function of (square) matrix size *)

	PROCEDURE TestMatMul*;
	CONST MaxSize = 2048;
	VAR size,iterations,t:SIGNED32;
		A,A1,B:Matrix;
		A2,A21,B2: ARRAY[2,2] OF FLOAT32;
		A3,A31,B3: ARRAY[3,3] OF FLOAT32;
		A4,A41,B4: ARRAY [4,4] OF FLOAT32;
		timer: Kernel.MilliTimer; ops,flops:FLOAT64;
	BEGIN
		size:=2;
		WHILE size<=MaxSize DO
			Out.String( "MatMul  size       " );  Out.Int(size,6);
			Kernel.GC;
			A:=MatrixUtilities.RandomMatrix( size,size, MatrixUtilities.Uniform); A1:=A; B:=A;
			 CASE size OF (*test operation on "hardwired" matrix size using static ARRAY OF FLOAT32 *)
				2:
					A2:=SHORT(A[0..1,0..1]); A21:=SHORT(A1[0..1,0..1]); B2:=SHORT(B[0..1,0..1]);
					Kernel.SetTimer( timer, 0 );
					FOR iterations:=0 TO  1024*1024 * 8  DIV size DIV size -1 DO
						B2 := A21 * A2;
					END;
				|3:
					A3:=SHORT(A[0..2,0..2]); A31:=SHORT(A1[0..2,0..2]); B3:=SHORT(B[0..2,0..2]);
					Kernel.SetTimer( timer, 0 );
					FOR iterations:=0 TO  1024*1024 * 8  DIV size DIV size-1 DO
						B3 := A31 * A3;
					END;
				|4:
					A4:=SHORT(A); A41:=SHORT(A1); B4:=SHORT(B);
					Kernel.SetTimer( timer, 0 );
					FOR iterations:=0 TO  1024*1024 * 8  DIV size DIV size -1 DO
						B4 := A41 * A4;
					END;
			ELSE
				Kernel.SetTimer( timer, 0 );
				FOR iterations:=0 TO  1024*1024 * 8  DIV size DIV size -1 DO
					B := A1 * A;
				END;
			END;
			t := Kernel.Elapsed( timer );   (*in ms*)
			ops := 2.0 * size * size * size * iterations;   (*cost of matrix multiply; using k=2 *)
			flops := ops / (t / 1000);   (*per second*)
			Out.String( "; iterations, time, flops: " ); Out.Int( iterations, 10 ); Out.String( " " );  Out.Int( t, 6 );  Out.String( "ms  " );
			MatrixUtilities.OutFloat( flops / 1000000, 12, 1 ,0);  Out.String( " MFLOPs  " );
			IF size IN {2,3,4} THEN Out.String(" for small arrays, currently performant on static ARRAY OF FLOAT32 size only; dynamic arrays and FLOAT64 arrays need work") END;
			Out.Ln;
			size:=size*2;
		END;
	END TestMatMul;


END LinpackBenchmark.

SystemTools.Free
LinpackBenchmark
MatrixBlockSolvers
MatrixComputeObjects
MatrixSolvers.Mod
MatrixStandardSolvers
MatrixNorms
MatrixUtilities
MatrixBase~
fofPC.Compile \W *
OFormatter.Format *

LinpackBenchmark.Test
LinpackBenchmark.TestLUA
LinpackBenchmark.TestMatMul

SystemTools.FreeDownTo MatrixBase~
SystemTools.CollectGarbage~

