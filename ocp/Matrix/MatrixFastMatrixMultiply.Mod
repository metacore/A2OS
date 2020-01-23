MODULE MatrixFastMatrixMultiply; (** AUTHOR "Patrick Hunziker"; PURPOSE "Fast Matrix Multplication algorithms for even size matrices"; *)
(* Performance: compiler version  20.3.08 on single CPU Pentium M:
	- for small matrices slower than compiler-delivered MatMul
	- performance break-even at matrix size 1024*1024
	- for larger matrices significantly faster than conventional matmul*)


(*literature: see wikipedia and http://www.sedulity.cn/Algorithms/book6/chap31.htm *)
(*Matrix Multiplication normally needs 2*N^3 operations; the strassen algorithm for
fast matrix multiplication when done recursively, has an operation count of 4* N^2.8 ;
i.e. it can be faster on large matrices (some claim, for matrix sizes>50).
The current implementation is faster than conventional matrix multiplication, implemented by Felix in the compiler,
only for matrices > 600*600 on single processor machines. Note that Strassen's algorithm is parallelizable on multicores..
*)

IMPORT MatrixBase, Kernel, AosOut:=KernelLog, Util:=MatrixUtilities;

TYPE Matrix=MatrixBase.Matrix;

(**
C:= A * B
expressed in submatrices:
r	s	=	a	b	*	e	f
t	u		c	d		g	h
*)
TYPE Strassen*=OBJECT
	VAR a,b,c,d,e,f,g,h, r,s,t,u, P1,P2,P3,P4,P5,P6,P7,P55,P66,P77: Matrix; rowsa,rowsb,colsa,colsb: SIZE;

	PROCEDURE Multiply*(CONST A,B:Matrix; VAR C:Matrix); (* less memory overhead, less readable*)

	BEGIN
		(*to do: assertions for matrix size: even; A fits to B *)

		rowsa := LEN(A,0) DIV 2;
		rowsb := LEN(B,0) DIV 2;
		colsa := LEN(A,1) DIV 2;
		colsb := LEN(B,1) DIV 2;
		IF (LEN(C,0)#LEN(A,0)) OR (LEN(C,1)#LEN(B,1)) THEN NEW(C, LEN(A,0), LEN(B,1)) END;

(*
		a:=A[..rowsa-1,..colsa-1];
		b:=A[..rowsa-1,colsa..];
		c:=A[rowsa..,..colsa-1];
		d:=A[rowsa..,colsa..];
		e:=B[..rowsb-1,..colsb-1];
		f:=B[..rowsb-1,colsb..];
		g:=B[rowsb..,..colsb-1];
		h:=B[rowsb..,colsb..];

		P1:= a*(f-h); (* Strassen's ingenious factorisation; might be split into multiple processes *)
		P2:= (a+b)*h;
		P3:= (c+d)*e;
		P4:= d * (g-e);
		P5:=(a+d)*(e+h);
		P6:=(b-d)*(g+h);
		P7:=(a-c)*(e+f);
*)

(*
		r:=P5 + P4 - P2 + P6;
		s:=P1 + P2;
		t:=P3 + P4;
		u:=P5 + P1 - P3 - P7;

		C[..rowsa-1,..colsb-1]:=r;
		C[..rowsa-1,colsb..]:= s;
		C[rowsa..,..colsb-1]:= t;
		C[rowsa..,colsb..]:= u;
*)

		P1:= A[..rowsa-1,..colsa-1]*(B[..rowsb-1,colsb..]-B[rowsb..,colsb..]); (*TO DO: simplify for elimination of temp memory use*)
		P2:= (A[..rowsa-1,..colsa-1]+A[..rowsa-1,colsa..])*B[rowsb..,colsb..];
		P3:= (A[rowsa..,..colsa-1]+A[rowsa..,colsa..])*B[..rowsb-1,..colsb-1];
		P4:= A[rowsa..,colsa..] * (B[rowsb..,..colsb-1]-B[..rowsb-1,..colsb-1]);
		P5:=(A[..rowsa-1,..colsa-1]+A[rowsa..,colsa..])*(B[..rowsb-1,..colsb-1]+B[rowsb..,colsb..]);
		(*P6:=(A[..rowsa-1,colsa..]-A[rowsa..,colsa..])*(B[rowsb..,..colsb-1]+B[rowsb..,colsb..]);*)
		C[..rowsa-1,..colsb-1]:=(A[..rowsa-1,colsa..]-A[rowsa..,colsa..])*(B[rowsb..,..colsb-1]+B[rowsb..,colsb..]); (*reduced temp mem*)
		(*P7:=(A[..rowsa-1,..colsa-1]-A[rowsa..,..colsa-1])*(B[..rowsb-1,..colsb-1]+B[..rowsb-1,colsb..]);*)
		C[rowsa..,colsb..]:= (A[rowsa..,..colsa-1]-A[..rowsa-1,..colsa-1])*(B[..rowsb-1,..colsb-1]+B[..rowsb-1,colsb..]); (*reduced temp mem*)


		C[..rowsa-1,..colsb-1]:=C[..rowsa-1,..colsb-1]+P5 + P4 - P2; (*reduced temp mem*)
		(*C[..rowsa-1,..colsb-1]:=P5 + P4 - P2 + P6;*) 	(* r *)
		C[..rowsa-1,colsb..]:= P1 + P2; 				(* s *)
		C[rowsa..,..colsb-1]:= P3 + P4;				(* t *)
		(*C[rowsa..,colsb..]:= P5 + P1 - P3 - P7;*)		(* u *)
		C[rowsa..,colsb..]:= C[rowsa..,colsb..] +P5 + P1 - P3; (*reduced temp mem*)

	END Multiply;

END Strassen;



PROCEDURE Test*;
CONST block=256; repeats = 3;
VAR i,n:SIGNED32; A,B,C, C1, dummy :Matrix; timer: Kernel.MilliTimer; r,t:SIGNED32; strassen:Strassen;
BEGIN
	(**)
	Kernel.SetTimer(timer,0);

	FOR i:=1 TO 10 DO
		AosOut.String("matmul (straight/Strassen): "); AosOut.Int(i*block,6);
		A:=Util.RandomMatrix(i*block,8*i*block, Util.Uniform);
		Kernel.GC;
		NEW(B,LEN(A,1), LEN(A,0));
		B:=A`;
		C:=A*B;
		Kernel.SetTimer(timer,0);
		n:=repeats DIV i DIV i+1;
		FOR r:=0 TO n-1 DO
			C:=A*B;
		END;
		t:=Kernel.Elapsed(timer);
		 AosOut.Int(t DIV n,10); AosOut.String(" | ");
	(*
		Kernel.SetTimer(timer,0);
		n:=repeats DIV i DIV i+1;
		FOR r:=0 TO n-1 DO
			C := C + A*B;
		END;
		t:=Kernel.Elapsed(timer);
		 AosOut.Int(t DIV n,10); AosOut.String(" | ");

		 Kernel.SetTimer(timer,0);
		n:=repeats DIV i DIV i+1;
		FOR r:=0 TO n-1 DO
			C := C - A*B;
		END;
		t:=Kernel.Elapsed(timer);
		 AosOut.Int(t DIV n,10); AosOut.String(" | ");
	*)
		NEW(strassen);
		Kernel.GC;
		C1:=A*B;
		strassen.Multiply(A,B,C1); (*make shure, all allocations are done*)

		Kernel.SetTimer(timer,0);
		FOR r:=0 TO n -1 DO
			strassen.Multiply(A,B,C1);
		END;
		t:=Kernel.Elapsed(timer);
		AosOut.Int(t DIV n,10);
		(* AosOut.String(" residual "); Util.OutFloat((C-C1)+*(C-C1),12,5,0);*)
		 AosOut.Ln;
		strassen:=NIL;
	END;
END Test;

PROCEDURE Test1*;
VAR A: Matrix;
BEGIN
	A:=[[0,1],[2,3]];
	A:=[[1,2,3],[4,5,6],[7,8,9]];
END Test1;


END MatrixFastMatrixMultiply.

MatrixFastMatrixMultiply.Test ~

MatrixFastMatrixMultiply.Test1 ~
S.Free MatrixFastMatrixMultiply ~
Kernel.GC

