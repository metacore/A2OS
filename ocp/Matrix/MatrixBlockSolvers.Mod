MODULE MatrixBlockSolvers; (*author: Patrick Hunziker, 22.3.2008; purpose: "Block Solvers for linear systems of equations"*)
IMPORT
		Base:=MatrixBase, Util:=MatrixUtilities, MatrixStandardSolvers, Out:=KernelLog, SYSTEM, Kernel, Objects,
		ComputeObjects:=MatrixComputeObjects, MatrixActive (*, Vectors*);

CONST MINBLOCKSIZE = 32;


TYPE Matrix=Base.Matrix;
		Vector=Base.Vector;

(**  see http://www.maths.man.ac.uk/~nareport/narep207.pdf/demmel95block.pdf*)
(** A=LU; diagonal blocks are square
A= [[A11,A12],[A21,A22]]=[[I,0],[L21,I]] * [[A11,A12][0,S]] i.e.

A = [A11,A12]  = [  I , 0] 	* [A11,A12]
	[A21,A22]     [L21,I]	   [  0  ,  S  ]


S = Schur Complement = A22-A21 * A11inv * A12
to be applied recursively

specifically:
1) U11:=A11; U12 := A12
2) Solve L21*A11 = A21 for L21
	-either using Gauss Elimination with partial pivoting or
	-or compute A11inv explicitely, so that step 2 becomes a matrix multiplication and Ux=y is solved entirely by matrix vector multziplication
3) S := A22 - L21 * A12 (Schur complement)
4) Compute LU factorisation of S recursively

given the block factorisation of A, the solution to a system Ax=b can be obtained by solving Lx=y by forward
substitution since L is triangular, and solving Ux=y by block back substitution.

*)
(*precondition: square*)
(* abstract implementation
PROCEDURE LU(CONST A:Matrix);
 VAR A11,A12,A21,L21,S, A11inv, Res: Matrix;
BEGIN
	A11inv:=Invert(A11);
	L21:= A21*A11inv;
	S := A22 - L21 * A12;
	LU(S); (*recursion*)
END LU;
*)

TYPE LU* = OBJECT
VAR A11inv, L21, U12, S: Matrix;
	x:Vector;
	rows1:SIZE;
	quadsolver: LU; (*for recursion in solving S*)
	lu,luS: MatrixStandardSolvers.LU; (*for inverting A11 and solving S in last recursion*)
	direct:BOOLEAN;

(*precondition: Matrix A (N*N) *)
PROCEDURE & Init*(VAR A:Matrix; blocksize:SIGNED32);
VAR U11: Matrix; (*u11,u11inv: ARRAY [4,4] OF Vectors.Datatype;*)
BEGIN;
	IF LEN(A,0)=0 THEN rows1:=0; RETURN
	ELSIF LEN(A,0)<16 THEN NEW(lu,A); direct:=TRUE;  RETURN;
	ELSE direct:=FALSE;
	END;;
	rows1:=MIN(blocksize, LEN(A,0) DIV 2) ;

	U11:=A[..rows1-1,..rows1-1];	(*using original data structure of A here instead of copying leads to less data coherence and slower performance*)
	U12:=A[..rows1-1,rows1..];
	L21:=A[rows1..,..rows1-1];
	S:=A[rows1..,rows1..];

	NEW(x,LEN(A,0));

	(*IF LEN(U11,0)=4 THEN u11:=SHORT(U11); IF Vectors.Invert(u11,u11inv) THEN A11inv:=u11inv END;
	ELSE*)
	IF lu=NIL THEN NEW(lu, U11); ELSE lu.Init(U11) END;
	A11inv:=lu.Inverse();

	L21:= L21 * A11inv;
	S:=S-L21 *  U12;
	IF blocksize < 16 THEN
		quadsolver:=NIL;NEW(luS,S);
	ELSIF LEN(S,0) > 1.3 * blocksize THEN
		IF quadsolver=NIL THEN NEW(quadsolver,S, blocksize); ELSE quadsolver.Init(S,blocksize) END; (*might reuse in child ?? *)
	ELSE
		quadsolver:=NIL;
		NEW(luS,S);
	END;
END Init;

PROCEDURE Solve*(CONST b: Vector): Vector;
 VAR b1,b2, y: Vector;

BEGIN
	IF rows1=0 THEN RETURN b1
	ELSIF direct THEN RETURN lu.Solve(b)
	END;
	IF LEN(y)#LEN(b) THEN NEW(y,LEN(b)); END;
			(*  ** Solve L*(Ux)=b; i.e. Ly=b) ** *)
		(*ForwardSubstitute L11*)
	y[..rows1-1]:=b[..rows1-1];	(* L11 is identity transform*)

		(*ForwardSubstitute L21, L22*)
	b2:= b[rows1..] - L21 * y[..rows1-1]; (*L21*)
	y[rows1..] := b2; (*L22 is an identity matrix*)

			(*  ** then, solve Ux=y 	by backward substitution ** *)
		(* Solve U22*)
	IF quadsolver#NIL THEN 	x[rows1..] := quadsolver.Solve( y[rows1..] );
	ELSE 					x[rows1..] := luS.Solve(y[rows1..] );
	END;

		(*eliminate U12*)
	y[..rows1-1]:= y[..rows1-1] - U12 * x[rows1..];

		(*and solve U11*)
	x[..rows1-1]:=A11inv * y[..rows1-1];
	RETURN x;
END Solve;

END LU;

(* experiment with fixed size 4x4 subblocks *)
(*
TYPE LUB* = OBJECT
VAR A11inv: Vectors.Matrix4x4;
	L21, U12, S: Matrix;
	x:Vector;
	rows1:SIGNED32;
	quadsolver: LU; (*for recursion in solving S*)
	lu,luS: MatrixStandardSolvers.LU; (*for inverting A11 and solving S in last recursion*)
	direct:BOOLEAN;

(*precondition: Matrix A (N*N) *)
PROCEDURE & Init*(VAR A:Matrix; blocksize:SIGNED32);
VAR U11: Vectors.Matrix4x4;
BEGIN;
	IF LEN(A,0)=0 THEN rows1:=0; RETURN
	ELSIF LEN(A,0)<16 THEN NEW(lu,A); direct:=TRUE;  RETURN;
	ELSE direct:=FALSE;
	END;;
	(*rows1:=MIN(blocksize, LEN(A,0) DIV 2) ;*)
	rows1:=4;

	U11:=A[..rows1-1,..rows1-1];	(*using original data structure of A here instead of copying leads to less data coherence and slower performance*)
	U12:=A[..rows1-1,rows1..];
	L21:=A[rows1..,..rows1-1];
	S:=A[rows1..,rows1..];

	NEW(x,LEN(A,0));

	(*IF lu=NIL THEN NEW(lu, U11); ELSE lu.Init(U11) END;
	A11inv:=lu.Inverse();*)
	IF Vectors.Invert(U11, A11inv) THEN END;
	L21:= L21 * A11inv;
	S:=S-L21 *  U12;
	IF blocksize < 16 THEN
		quadsolver:=NIL;NEW(luS,S);
	ELSIF LEN(S,0) > 1.3 * blocksize THEN
		IF quadsolver=NIL THEN NEW(quadsolver,S, blocksize); ELSE quadsolver.Init(S,blocksize) END; (*might reuse in child ?? *)
	ELSE
		quadsolver:=NIL;
		NEW(luS,S);
	END;
END Init;

PROCEDURE Solve*(CONST b: Vector): Vector;
 VAR b1,b2, y: Vector;

BEGIN
	IF rows1=0 THEN RETURN b1
	ELSIF direct THEN RETURN lu.Solve(b)
	END;
	IF LEN(y)#LEN(b) THEN NEW(y,LEN(b)); END;
			(*  ** Solve L*(Ux)=b; i.e. Ly=b) ** *)
		(*ForwardSubstitute L11*)
	y[..rows1-1]:=b[..rows1-1];	(* L11 is identity transform*)

		(*ForwardSubstitute L21, L22*)
	b2:= b[rows1..] - L21 * y[..rows1-1]; (*L21*)
	y[rows1..] := b2; (*L22 is an identity matrix*)

			(*  ** then, solve Ux=y 	by backward substitution ** *)
		(* Solve U22*)
	IF quadsolver#NIL THEN 	x[rows1..] := quadsolver.Solve( y[rows1..] );
	ELSE 					x[rows1..] := luS.Solve(y[rows1..] );
	END;

		(*eliminate U12*)
	y[..rows1-1]:= y[..rows1-1] - U12 * x[rows1..];

		(*and solve U11*)
	x[..rows1-1]:=A11inv * y[..rows1-1];
	RETURN x;
END Solve;

END LUB;
 *)


(*three level approach for more prioritized active objects*)
(* basic form
A = [A11,A12]  = [  I , 0] 	* [A11,A12]
	[A21,A22]     [L21,I]	   [  0  ,  S  ]
with 	L21:= A21*A11inv;
		S := A22 - L21 * A12;

but now do additional subdivision in view of sequential processing with more compute objects:
A = [A11,A12,A13]  = [  I , 0 ,  0 ] 	* [A11, A12, A13 ]
	[A21,A22,A23]     [L21, I , 0 ]		   [  0  ,  S22, S23 ]
	[A31,A32,A33]     [L31, 0 , I ]		   [  0  ,  S32, S33 ]

		A11inv := Invert(A11); (*needed first *)

with  	[L21] :=	[A21] * 	A11inv
		[L31]	[A31]

	i.e.  [L21] :=	[A21] * 	A11inv (*needed for next recursion*)
		[L31] :=	[A31] *	A11inv

then	[S22, S23] :=	[A22, A23]	-	[L21] * 	[A12,A13]
		[S32, S33]		[A32, A33]		[L31]

	i.e.  [S22] := A22 - [L21]*[A12]; (*needed for next recursion*)
		[S23] := A23 - [L21]*[A13];
		[S32] := A32 - [L31]*[A12];
		[S33] := A33 - [L31]*[A13];


		(*In the general case:
		Anm = Ln0*U0m + ?nm => ?nm = Anm - Ln0*U0m
		*)

Algorithm:
	get A11;
	A11inv := Invert(A11);
	get A21;
	L21 := A21 * A11inv;
	get A12;
	get A22;
	S22 := A22 - L21*A12;
		=> Start Recursion - push S22 as (recursion's A11)
	get A31;
	L31 := A31 * A11inv;
	get A32;
	S32 := A32 - L31*A12; - push S32 as recursion's ALL (*could be further split*)
	get A13;
	get A23;
	S23 := A23 - L21*A13; - push S23 as recursion's AUR (*could be further split*)
	get A33;
	S33 := A33 - L31*A13; - push S33 as recursion's ALR(*could be further split*)

Pseudocode:
Algorithm:
*)

TYPE  LUAgent*= OBJECT
	VAR
		A11, A12, A13, A11inv, L21, S22, S23, S32, S33, L31: Matrix;
		UL, UR, LL, LR, dummy: Matrix; (*cave: double bookkeeping ... *)
		gotA11, gotA21, gotA12, gotA13, gotA22, gotA23, gotA31,gotA32,gotA33, A11invdone, L21done, S22done, L31done,
		S32done, S23done, S33done, childdone, done: BOOLEAN;
		MulSub22, MulSub23, MulSub32, MulSub33: ComputeObjects.MulSub; (*ComputeObjects.MulSub2*)
		Mul21,Mul31:ComputeObjects.Mul;
		blu: LUAgent; (* child *)
		lu: MatrixStandardSolvers.LU;
		datasize, blocksize:SIZE;
		x,y: Vector;
		id, recursionlevel:SIGNED32;
		notify:Notifier;
		direct:BOOLEAN;
		priority:SIGNED32; (*experimental -not fully implemented*)

	PROCEDURE & Init*(datasize,blocksize:SIZE; notify:Notifier; prio: SIGNED32);
	BEGIN {EXCLUSIVE}
		id:=ident; INC(ident);
		priority:=MIN(Objects.High,MAX(prio,Objects.Low));
		Objects.SetPriority(priority);
		done:=FALSE;
		gotA11 := FALSE;  gotA12 := FALSE; gotA13 := FALSE;
		gotA21 := FALSE;  gotA21 := FALSE;  gotA23 := FALSE;
		gotA31 := FALSE; gotA32 := FALSE; gotA33 := FALSE;
		A11invdone := FALSE;
		L21done := FALSE;  L31done:= FALSE;
		S22done := FALSE;
		S32done := FALSE; S23done:=FALSE; S33done:=FALSE;
		IF blocksize<datasize THEN SELF.blocksize:=blocksize; ELSE SELF.blocksize:=datasize END;
		SELF.datasize:=datasize;
		IF lu=NIL THEN NEW(lu,dummy) END;
		SELF.notify:=notify;
		NEW(x,datasize);
		NEW(y, datasize);
	END Init;

	PROCEDURE Set*(VAR A:Matrix); (*blocking interface for surrounding linear code*)
		BEGIN
			IF LEN(A,0)<= blocksize THEN
				datasize:=LEN(A,0); blocksize:=datasize; NEW(x,datasize); direct:=TRUE; lu.Init(A);
				BEGIN {EXCLUSIVE} done:=TRUE END;
				IF notify#NIL THEN notify END;
			ELSE
				SetUL(A[..blocksize-1,..blocksize-1]);
				SetUR(A[..blocksize-1,blocksize..]);
				SetLL(A[blocksize..,..blocksize-1]);
				SetLR(A[blocksize..,blocksize..]);
				BEGIN {EXCLUSIVE} AWAIT(done) END;
			END;
		END Set;
	PROCEDURE SetUL(VAR UL: Matrix); (* nonblocking interfaces; if used in linear code, make shure that process is terminated before using results*)
		BEGIN
			SELF.UL:=ALIAS OF UL; SELF.A11:=ALIAS OF UL;
			BEGIN {EXCLUSIVE} gotA11 :=TRUE END
		END SetUL;
	PROCEDURE SetUR(VAR UR: Matrix); BEGIN SELF.UR:=ALIAS OF UR; A12:=ALIAS OF UR[..,..blocksize-1]; A13 := ALIAS OF UR[..,blocksize..]; BEGIN {EXCLUSIVE} gotA12 :=TRUE; gotA13 := TRUE;  END END SetUR;
	PROCEDURE SetLL(VAR LL: Matrix); BEGIN SELF.LL:=ALIAS OF LL; L21:=ALIAS OF LL[..blocksize-1,..]; L31:=ALIAS OF LL[blocksize..,..]; BEGIN {EXCLUSIVE} gotA21 :=TRUE; gotA31 :=TRUE;  END END SetLL;
	PROCEDURE SetLR(VAR LR: Matrix);
		BEGIN
			SELF.LR:=ALIAS OF LR;
			S22:=ALIAS OF LR[..blocksize-1,..blocksize-1];
			S23:=ALIAS OF LR[..blocksize-1,blocksize..];
			S32:=ALIAS OF LR[blocksize.., ..blocksize-1];
			S33:=ALIAS OF LR[blocksize.., blocksize..];
			BEGIN {EXCLUSIVE} gotA22 :=TRUE; gotA23 :=TRUE; gotA32 :=TRUE; gotA33 :=TRUE;  END
		END SetLR;

	PROCEDURE S22Done; BEGIN {EXCLUSIVE} S22done:=TRUE;  (*Out.String("S22-"); Out.Int(recursionlevel,0);Out.Ln;*) END S22Done;
	PROCEDURE S32Done; BEGIN {EXCLUSIVE} S32done:=TRUE;  (*Out.String("S32-"); Out.Int(recursionlevel,0);Out.Ln;*)  END S32Done;
	PROCEDURE S23Done; BEGIN {EXCLUSIVE} S23done:=TRUE;  (*Out.String("S23-"); Out.Int(recursionlevel,0);Out.Ln;*)  END S23Done;
	PROCEDURE S33Done; BEGIN {EXCLUSIVE} S33done:=TRUE;  (*Out.String("S33-"); Out.Int(recursionlevel,0);Out.Ln;*)  END S33Done;
	PROCEDURE L21Done; BEGIN {EXCLUSIVE} L21done:=TRUE;  (*Out.String("L21-"); Out.Int(recursionlevel,0);Out.Ln;*)  END L21Done;
	PROCEDURE L31Done; BEGIN {EXCLUSIVE} L31done:=TRUE;  (*Out.String("L31-"); Out.Int(recursionlevel,0);Out.Ln;*)  END L31Done;
	PROCEDURE ChildDone; BEGIN {EXCLUSIVE} childdone:=TRUE END ChildDone;

	PROCEDURE Solve*(CONST b: Vector): Vector;
	 VAR b2: Vector;
	BEGIN
		IF direct THEN RETURN lu.Solve(b) END;
				(*  ** Solve L*(Ux)=b; i.e. Ly=b) ** *)
		y[..blocksize-1]:=b[..blocksize-1];							(*ForwardSubstitute L11; L11 is identity transform *)
		b2:= b[blocksize..] - LL * y[..blocksize-1]; (*L21*) 			(*ForwardSubstitute L21, L22*)
		y[blocksize..] := b2;  										(*L22 is an identity matrix*)
				(*  ** then, solve Ux=y 	by backward substitution ** *)
		IF blu#NIL THEN x[blocksize..] := blu.Solve( y[blocksize..] ); (* Solve U22*)
		ELSE x[blocksize..] := lu.Solve(y[blocksize..] );
		END;
		y[..blocksize-1]:= y[..blocksize-1] - UR * x[blocksize..];  	(*eliminate U12*)
		x[..blocksize-1]:=A11inv * y[..blocksize-1];  				(*and solve U11*)
		RETURN x;
	END Solve;

	(**ACTIVE BODY VARIANT WITH 3 priority levels *)
	BEGIN {ACTIVE}
		IF direct THEN RETURN END;

		BEGIN{EXCLUSIVE } AWAIT(gotA11); END;
		lu.Init(A11);
		A11inv := lu.Inverse();

		BEGIN{EXCLUSIVE } A11invdone:=TRUE; AWAIT(gotA21 & A11invdone); END;
		NEW(Mul21, L21, A11inv, L21, L21Done, Objects.Normal);  		(*L21 := L21 * A11inv; *)

		BEGIN{EXCLUSIVE } AWAIT(gotA31 & A11invdone); END;
		NEW(Mul31, L31, A11inv, L31, L31Done, Objects.Low);  		(* L31 := L31 * A11inv;*)

		BEGIN{EXCLUSIVE } AWAIT(gotA12 & gotA22 & L21done); END;
		NEW(MulSub22,L21,A12,S22, S22Done, Objects.Normal);	 		(*S22 := S22 - L21*A12; *)

		BEGIN{EXCLUSIVE } AWAIT(S22done);END;
		IF datasize-blocksize > blocksize+MINBLOCKSIZE  THEN  			(*start recursion, push S22 as (recursion's A11) *)
			NEW(blu, datasize-blocksize, blocksize, ChildDone, Objects.High);
			blu.recursionlevel:=recursionlevel+1;
			blu.SetUL(S22);
		END;

		BEGIN{EXCLUSIVE } AWAIT(gotA12 & gotA32 & L31done); END;
		NEW(MulSub32, L31,A12,S32, S32Done, Objects.Low);	 	(*S32 :=S32-L31*A12 *)

		BEGIN{EXCLUSIVE } AWAIT(gotA13 & gotA23 & L21done); END;
		NEW(MulSub23, L21,A13,S23, S23Done, Objects.Low);		 (*S23 :=S23-L21*A13 *)

		BEGIN{EXCLUSIVE } AWAIT(gotA13 & gotA33 & L31done); END;
		NEW(MulSub33, L31,A13,S33, S33Done, Objects.Low);		 (*S33 :=S33-L31*A13 *)

		IF blu#NIL THEN
			BEGIN{EXCLUSIVE } AWAIT( S32done); END;
			blu.SetLL(S32);

			BEGIN{EXCLUSIVE } AWAIT( S23done); END;
			blu.SetUR(S23);

			BEGIN{EXCLUSIVE } AWAIT( S33done); END;
			blu.SetLR(S33);
		ELSE
			BEGIN{EXCLUSIVE } AWAIT(S23done &  S32done & S33done); END;
			lu.Init(LR);
			ChildDone;
		END;

		BEGIN{EXCLUSIVE } AWAIT( childdone) ; done:=TRUE END;
		IF notify#NIL THEN notify END;
	END LUAgent;

(** Block matrix inversion is of particular advantage if A is diagonal and SchurComplement is a small matrix, because only those two need inversion. *)
TYPE Inverse* = OBJECT
VAR A11inv, L21, U12, A21, S: Matrix;
	x:Vector;
	rows1:SIGNED32;
	quadsolver: LU; (*for recursion in solving S*)
	lu,luS: MatrixStandardSolvers.LU; (*for inverting A11 and solving S in last recursion*)
	direct:BOOLEAN;
	priority: SIGNED32;

(*
(*
Block Inversion of Matrix - see http://en.wikipedia.org/wiki/Invertible_matrix
algorithm:
M=[[A,B],[C,D]] : divide matrix into blocks A,B,C,D with A,D square
SchurComplement := (D-C*Ainv*B)
E:=C*Ainv;
SI:= Inv(SchurComplement);
Inv(M):=
[[Ainv+Ainv*B*SI*E, 	-Ainv*B*SI ],
 [ -SI*E, 				SI]]
*)

(*precondition: Matrix A (N*N) *)
PROCEDURE & Init(VAR A:Matrix; blocksize:SIGNED32);
VAR U11, dummy: Matrix;
BEGIN;
	IF LEN(A,0)=0 THEN rows1:=0; RETURN
	ELSIF LEN(A,0)<16 THEN NEW(lu,A); direct:=TRUE;  RETURN;
	ELSE direct:=FALSE;
	END;;
	rows1:=MIN(blocksize, LEN(A,0) DIV 2) ;

	U11:=A[..rows1-1,..rows1-1];	(*using original data structure with ZEROCOPY of A here instead of copying leads to less data coherence and slower performance*)
	U12:=A[..rows1-1,rows1..];
	L21:=A[rows1..,..rows1-1];
	S:=A[rows1..,rows1..];

	NEW(x,LEN(A,0));

	IF lu=NIL THEN NEW(lu, U11); ELSE lu.Init(U11) END;
	A11inv:=lu.Inverse();
	L21:= L21 * A11inv;
	S:=S-L21 *  U12;
	IF blocksize < 16 THEN
		quadsolver:=NIL;NEW(luS,S);
	ELSIF LEN(S,0) > 1.3 * blocksize THEN
		IF quadsolver=NIL THEN NEW(quadsolver,S, blocksize); ELSE quadsolver.Init(S,blocksize) END; (*might reuse in child ?? *)
	ELSE
		quadsolver:=NIL;
		NEW(luS,S);
	END;
END Init;
*)
(*
PROCEDURE Solve*(CONST b: Vector): Vector;
 VAR b1,b2, y: Vector;

BEGIN
	IF rows1=0 THEN RETURN b1
	ELSIF direct THEN RETURN lu.Solve(b)
	END;
	IF LEN(y)#LEN(b) THEN NEW(y,LEN(b)); END;
			(*  ** Solve L*(Ux)=b; i.e. Ly=b) ** *)
		(*ForwardSubstitute L11*)
	y[..rows1-1]:=b[..rows1-1];	(* L11 is identity transform*)

		(*ForwardSubstitute L21, L22*)
	b2:= b[rows1..] - L21 * y[..rows1-1]; (*L21*)
	y[rows1..] := b2; (*L22 is an identity matrix*)

			(*  ** then, solve Ux=y 	by backward substitution ** *)
		(* Solve U22*)
	IF quadsolver#NIL THEN x[rows1..] := quadsolver.Solve( y[rows1..] );
	ELSE x[rows1..] := luS.Solve(y[rows1..] );
	END;

		(*eliminate U12*)
	y[..rows1-1]:= y[..rows1-1] - U12 * x[rows1..];

		(*and solve U11*)
	x[..rows1-1]:=A11inv * y[..rows1-1];
	RETURN x;
END Solve;
*)

END Inverse;


 (*! this version does not yet work - there is some synchronization problem left - where should we wait ? *)
TYPE LUActive*= OBJECT
	VAR
		A11, A12, A13, A11inv, L21, S22, S23, S32, S33, L31: MatrixActive.Matrix;
		UL, UR, LL, LR, dummy, s22: Matrix; (*cave: double bookkeeping ... *)
		blu: LUActive; (* child *)
		lu: MatrixStandardSolvers.LU;
		datasize, blocksize:SIZE;
		x,y: Vector;
		id:SIGNED32;
		filling:SET;
		notify:Notifier;
		done, childdone, direct, initialized:BOOLEAN;
		priority:SIGNED32; (*experimental -not fully implemented*)

	PROCEDURE & Init(datasize, blocksize:SIZE; notify:Notifier; prio: SIGNED32);  (* only first quadrant is expected to be ready*)
	VAR a11: Matrix;
	BEGIN
		id:=ident; INC(ident);
		SELF.blocksize:=MIN(blocksize,datasize);
		SELF.datasize:=datasize;
		priority:=MIN(Objects.High,MAX(prio,Objects.Low));
		Objects.SetPriority(priority);
		SELF.notify:=notify;
		NEW(x,datasize);
		NEW(y, datasize);
END Init;

	PROCEDURE Initialize*;
	BEGIN {EXCLUSIVE}
		initialized:=TRUE;
	END Initialize;

	PROCEDURE Done*;
	BEGIN {EXCLUSIVE}
		done:=TRUE
	END Done;

	PROCEDURE FillQuadrant(q:SIGNED32);
	BEGIN {EXCLUSIVE}
		INCL(filling, q);
	END FillQuadrant;

	PROCEDURE Set(VAR A:Matrix); (*blocking interface for surrounding linear code*)
		BEGIN
			datasize:=LEN(A,0);
			IF datasize<= blocksize THEN
				blocksize:=datasize;
				direct:=TRUE;
				NEW(lu,A);
				Done;
				IF notify#NIL THEN notify END;
			ELSE
				SELF.UL:= A[..blocksize-1,..blocksize-1]; NEW(lu,SELF.UL); FillQuadrant(0);
				SELF.UR:= A[..blocksize-1,blocksize..]; A12:=SELF.UR[..,..blocksize-1]; A13:=SELF.UR[..,blocksize..]; FillQuadrant(1);
				SELF.LL:=  A[blocksize..,..blocksize-1]; L21:=SELF.LL[..blocksize-1,..]; L31:=SELF.LL[blocksize..,..]; FillQuadrant(2);
				SELF.LR:= A[blocksize..,blocksize..]; S22:=SELF.LR[..blocksize-1,..blocksize-1]; S23:=SELF.LR[..blocksize-1,blocksize..];
												S32:=SELF.LR[blocksize.., ..blocksize-1]; S33:=SELF.LR[blocksize.., blocksize..];FillQuadrant(3);
				datasize:=LEN(A,0);
				A12.WaitReadable; A13.WaitReadable; L21.WaitReadable; L31.WaitReadable; S22.WaitReadable; S23.WaitReadable; S32.WaitReadable; S33.WaitReadable;
				BEGIN {EXCLUSIVE} AWAIT(done) END; (*blocking interface for surrounding linear code*)
				IF notify#NIL THEN notify END;
			END;
		END Set;

	PROCEDURE SetUL(VAR UL: MatrixActive.Matrix); (* nonblocking interfaces; if used in linear code, make shure that process is terminated before using results*)
		BEGIN
			SELF.UL:=UL; (* implies synchronization *)
			NEW(lu,SELF.UL);
			A11:=UL;
			FillQuadrant(0);
		END SetUL;
	PROCEDURE SetUR(VAR UR: MatrixActive.Matrix);
		BEGIN
			SELF.UR:=UR; (* implies synchronization *)
			A12:=SELF.UR[..,..blocksize-1];
			A13:=SELF.UR[..,blocksize..];
			FillQuadrant(1)
		END SetUR;
	PROCEDURE SetLL(VAR LL: MatrixActive.Matrix);
		BEGIN
			SELF.LL:= LL; (* implies synchronization *)
			L21:=SELF.LL[..blocksize-1,..];
			L31:=SELF.LL[blocksize..,..];
			FillQuadrant(2);
		END SetLL;
	PROCEDURE SetLR(VAR LR: MatrixActive.Matrix);
		BEGIN
			SELF.LR:=LR; (* implies synchronization *)
			S22:=SELF.LR[..blocksize-1,..blocksize-1];
			S23:=SELF.LR[..blocksize-1,blocksize..];
			S32:=SELF.LR[blocksize.., ..blocksize-1];
			S33:=SELF.LR[blocksize.., blocksize..];
			FillQuadrant(3);
		END SetLR;
	PROCEDURE ChildDone; BEGIN {EXCLUSIVE} childdone:=TRUE END ChildDone;

	PROCEDURE Solve*(CONST b: Vector): Vector; (*! to do: ssecond half of result vector is still wrong ...*)
	 VAR b2: Vector;
	BEGIN
		IF direct THEN RETURN lu.Solve(b)
		ELSE 		(*  ** Solve L*(Ux)=b; i.e. Ly=b) ** *)
			y[..blocksize-1]:=b[..blocksize-1];							(*ForwardSubstitute L11; L11 is identity transform *)
			b2:= b[blocksize..] - LL * y[..blocksize-1]; (*L21*) 			(*ForwardSubstitute L21, L22*)
			y[blocksize..] := b2;  										(*L22 is an identity matrix*)
					(*  ** then, solve Ux=y 	by backward substitution ** *)
			IF blu#NIL THEN x[blocksize..] := blu.Solve( y[blocksize..] ); (* Solve U22*)
			ELSE 			 x[blocksize..] := lu.Solve(y[blocksize..] );
			END;
			y[..blocksize-1]:= y[..blocksize-1] - UR * x[blocksize..];  	(*eliminate U12*)
			x[..blocksize-1]:=A11inv.data * y[..blocksize-1];  			(*and solve U11*)
			RETURN x;
		END;
	END Solve;

	(*active object with priorities*)
	BEGIN {ACTIVE}
		IF direct THEN RETURN END;

		BEGIN{EXCLUSIVE} AWAIT(0 IN filling) END;
		A11inv := lu.Inverse();

		BEGIN{EXCLUSIVE} AWAIT(filling={0,1,2,3}) END;

		(* a number of the following statements can be processed in parallel *)
		L21 := L21 * A11inv;
		L31 := L31 * A11inv;
		S22 := S22 - L21*A12; (*here, S22 would be ready for recursion, could move IF statement up from below*)

		S32 :=S32-L31*A12;
		S23 :=S23-L21*A13;
		S33 :=S33-L31*A13; (*lower priority*)

		IF datasize-blocksize > blocksize+MINBLOCKSIZE  THEN  	(*start recursion, push S22 as recursion's A11 *)
			NEW(blu, datasize-blocksize, blocksize, ChildDone, Objects.High);
			blu.SetUL(S22);
			blu.SetLL(S32);	(* assignment implies synchronization *)
			blu.SetUR(S23);
			blu.SetLR(S33);
		ELSE
			LR[..blocksize-1,..blocksize-1]:=S22; (* assignment implies synchronization *)
			LR[..blocksize-1,blocksize..]:=S23;
			LR[blocksize.., ..blocksize-1]:=S32;
			LR[blocksize.., blocksize..]:=S33;
			S22.WaitReadable; S23.WaitReadable; S32.WaitReadable; S33.WaitReadable; (*! hack - eliminate *)
			lu.Init(LR);
			ChildDone;
		END;
		BEGIN{EXCLUSIVE } AWAIT( childdone) END;
		IF notify#NIL THEN notify END;
		Done;
	END LUActive;


TYPE Notifier = PROCEDURE {DELEGATE};

VAR ident: SIGNED32;



PROCEDURE {TEST} Test*;
CONST TestTolerance=0.0001;
VAR A, A0, B, Inv: Matrix; b,x,e: Vector; error:Base.Datatype; lu:MatrixStandardSolvers.LU;
BEGIN
	A:=Util.RandomMatrix(100,100, Util.DiagDominant);
	B:=Util.RandomMatrix(1,100, Util.Uniform); b:=B[0];
	A0:=A;
	NEW(lu,A);
	x:=lu.Solve(b);
	e:=A*x-b;
	ASSERT(e+*e < TestTolerance, 201);
	
	Inv:=lu.Inverse();
	B:=A*Inv;
	error:=SUM(ABS(B))-LEN(B,0);
	ASSERT(ABS(error)<TestTolerance, 202);
	
	(*! TBD: test LU Agen*)
END Test;

(*
PROCEDURE TestB*;
VAR A, A0, B, Inv: Matrix; b,x: Vector; lu: LUB;
BEGIN
	A:=Util.RandomMatrix(10,10, Util.DiagDominant);
	B:=Util.RandomMatrix(1,10, Util.Uniform); b:=B[0];
	A0:=A;
	NEW(lu,A,64);
	x:=lu.Solve(b);
	Out.String("A: "); Util.OutMatrix(A); Out.Ln;
	Out.String("b: "); Util.OutVector(b); Out.Ln;
	Out.String("A*x -b: "); Util.OutFloat((A*x-b)+*(A*x-b),12,5,0); Out.Ln;
END TestB;

*)

PROCEDURE Test0*;
VAR A, A0, B, Inv: Matrix; b,x: Vector; lu:MatrixStandardSolvers.LU;timer:Kernel.MilliTimer; t:SIGNED32;
BEGIN
	A:=Util.RandomMatrix(1024,1024, Util.DiagDominant);
	B:=Util.RandomMatrix(1,1024, Util.Uniform); b:=B[0];
	A0:=A;
	Kernel.SetTimer(timer,0);
	NEW(lu,A);
	t:=Kernel.Elapsed(timer);
	x:=lu.Solve(b);
	Out.String("A*x -b: "); Util.OutFloat((A*x-b)+*(A*x-b),12,5,0); Out.Ln;
	Out.Int(t,6); Out.String(" ms"); Out.Ln;
END Test0;

PROCEDURE Test1*;
VAR A, A0,B: Matrix; b,x: Vector; blu: LU; timer:Kernel.MilliTimer; t:SIGNED32;
BEGIN
	A:=Util.RandomMatrix(1024,1024, Util.DiagDominant);
	B:=Util.RandomMatrix(1,1024, Util.Uniform); b:=B[0];
	A0:=A;
	Kernel.SetTimer(timer,0);
	NEW(blu,A,4); (* 64*)
	t:=Kernel.Elapsed(timer);
	x:=blu.Solve(b);
	Out.String("A: "); Util.OutFloat(A0+*A0,12,5,0); Out.Ln;
	Out.String("b: "); Util.OutFloat(b+*b,12,5,0); Out.Ln;
	Out.String("x: "); Util.OutFloat(x+*x,12,5,0); Out.Ln;
	Out.String("A*x -b: "); Util.OutFloat((A0*x-b)+*(A0*x-b),12,5,0); Out.Ln;
	Out.Int(t,6); Out.String(" ms"); Out.Ln;
END Test1;

PROCEDURE Test2*;
CONST size=1024;
VAR A, A0,A1,B: Matrix; b,b1,x,x1: Vector; blu: LUAgent; lu:LU; timer:Kernel.MilliTimer; t:SIGNED32;
BEGIN
	A:=Util.RandomMatrix(size,size, Util.DiagDominant);
	B:=Util.RandomMatrix(1,size, Util.Uniform); b:=B[0]; b1:=b;
	Util.OutVector(b);
	A0:=A;
	A1:=A;
	Kernel.SetTimer(timer,0);
	NEW(blu,size,64,NIL,Objects.High);
	blu.Set(A);
	t:=Kernel.Elapsed(timer);
	x:=blu.Solve(b);

	NEW(lu,A1,64);
	x1:=lu.Solve(b1);

	Out.String("A: "); Util.OutFloat(A0+*A0,12,5,0); Out.Ln;	(*Util.OutMatrix(A0); *)Out.Ln;
	Out.String("b: "); Util.OutFloat(b+*b,12,5,0); Out.Ln;	(*Util.OutVector(b); *) Out.Ln;
	Out.String("x: "); Util.OutFloat(x+*x,12,5,0); Out.Ln;	(*Util.OutVector(x);*) Out.Ln;
	Out.String("A*x -b: "); Util.OutFloat((A0*x-b)+*(A0*x-b),12,5,0); Out.Ln; Util.OutVector(A0*x-b); Out.Ln;
	Out.String("A1*x1 -b1: "); Util.OutFloat((A1*x1-b1)+*(A1*x1-b1),12,5,0); Out.Ln; Util.OutVector(A1*x1-b1); Out.Ln;
	Out.Int(t,6); Out.String(" ms"); Out.Ln;
END Test2;



PROCEDURE Test3*;
CONST size=128;
VAR A, A0,A1,B: Matrix; b,b1,x,x1: Vector; blu: LUActive; lu:LU; timer:Kernel.MilliTimer; t:SIGNED32;
	A2: MatrixActive.Matrix;
BEGIN
	A:=Util.RandomMatrix(size,size, Util.DiagDominant);
	B:=Util.RandomMatrix(1,size, Util.Uniform); b:=B[0]; b1:=b;
	Util.OutVector(b);
	A0:=A;
	A1:=A;
	A2:=A;
	Kernel.SetTimer(timer,0);
	Out.String("Active.");
	NEW(blu,LEN(A0,0), 64,NIL,Objects.High);
	Out.String(", ");
	blu.Set(A);
	Out.String(";");
	t:=Kernel.Elapsed(timer);
	x:=blu.Solve(b);
	Out.String("."); Out.Ln;;

	Out.String("A: "); Util.OutFloat(A0+*A0,12,5,0); Out.Ln;	(*Util.OutMatrix(A0); *)Out.Ln;
	Out.String("b: "); Util.OutFloat(b+*b,12,5,0); Out.Ln;	(*Util.OutVector(b); *) Out.Ln;
	Out.String("x: "); Util.OutFloat(x+*x,12,5,0); Out.Ln;	(*Util.OutVector(x);*) Out.Ln;
	Out.String("A*x -b: "); Util.OutFloat((A0*x-b)+*(A0*x-b),12,5,0); Out.Ln; Util.OutVector(A0*x-b); Out.Ln;

	NEW(lu,A1,64);
	x1:=lu.Solve(b1);
	Out.String("A1*x1-b1:"); Util.OutFloat((A1*x1-b1)+*(A1*x1-b1),12,5,0); Out.Ln; Util.OutVector(A1*x1-b1); Out.Ln;
	Out.Int(t,6); Out.String(" ms"); Out.Ln;
END Test3;


PROCEDURE TestLUAgent*;
VAR A, A0, B, Inv: Matrix; b,x: Vector; lu:MatrixStandardSolvers.LU; blu:LUAgent; timer:Kernel.MilliTimer; t:SIGNED32;
BEGIN
	A:=Util.RandomMatrix(200,200, Util.DiagDominant);
	B:=Util.RandomMatrix(1,200, Util.Uniform); b:=B[0];
	A0:=A;
	NEW(blu,200, 64,NIL, Objects.High);
	blu.SetUL(A[..63,..63]);
	blu.SetUR(A[..63,64..]);
	blu.SetLL(A[64..,..63]);
	blu.SetLR(A[64..,64..]);
END TestLUAgent;

PROCEDURE {TEST} TestLUAgent0*;
CONST size=1024;
	TestThreshold=0.0001;
VAR A, A0,B: Matrix; b,x,e: Vector; blu: LUAgent; error:Base.Datatype;
BEGIN
	ComputeObjects.cumulobjects:=0;
	A:=Util.RandomMatrix(size,size, Util.DiagDominant);
	B:=Util.RandomMatrix(1,size, Util.Uniform); b:=B[0];
	A0:=A;
	NEW(blu,size, 256, NIL, Objects.High);
	A0:=A;
	blu.Set(A0); (*A0 will be modified as side effect*)
	x:=blu.Solve(b);
	e:=A*x-b;
	error:=e+*e;
	ASSERT(error < TestThreshold,201);
END TestLUAgent0;

PROCEDURE TestLUAgent1*;
CONST size=1024;
VAR A, A0,B: Matrix; b,x: Vector; blu: LUAgent; t:SIGNED32; timer: Kernel.MilliTimer;
BEGIN
	ComputeObjects.cumulobjects:=0;
	A:=Util.RandomMatrix(size,size, Util.DiagDominant);
	B:=Util.RandomMatrix(1,size, Util.Uniform); b:=B[0];
	A0:=A;
	NEW(blu,size, 256, NIL, Objects.High);
	Kernel.SetTimer(timer,0);
	blu.Set(A);
		t:=Kernel.Elapsed(timer);
	x:=blu.Solve(b);
	Out.String("A: "); Util.OutFloat(A0+*A0,12,5,0); Out.Ln;
	Out.String("b: "); Util.OutFloat(b+*b,12,5,0); Out.Ln;
	Out.String("A*x -b: "); Util.OutFloat((A0*x-b)+*(A0*x-b),12,5,0); Out.Ln;
	Out.Int(t,6); Out.String(" ms"); Out.Ln;
	Out.String("computeobjects: "); Out.Int(ComputeObjects.cumulobjects,6); Out.Ln;
END TestLUAgent1;

END MatrixBlockSolvers.

LinpackBenchmark.Test ~

MatrixBlockSolvers.Test ~
MatrixBlockSolvers.TestB ~
MatrixBlockSolvers.Test0 ~
MatrixBlockSolvers.Test1 ~
MatrixBlockSolvers.Test2 ~
MatrixBlockSolvers.Test3 ~
MatrixBlockSolvers.TestLUAgent ~
MatrixBlockSolvers.TestLUAgent0 ~
MatrixBlockSolvers.TestLUAgent1 ~

Compiler.Compile
Matrix/MatrixBase.Mod
Matrix/MatrixUtilities.Mod
Matrix/MatrixStandardSolvers.Mod
Matrix/MatrixComputeObjects.Mod
Matrix/MatrixActive.Mod
~

SystemTools.Free LinpackBenchmark MatrixBlockSolvers MatrixComputeObjects MatrixUtilities MatrixActive~
Kerne l.GC ~
SystemTools.FreeDownTo  MatrixActive ~



(* basic form
A = [A11,A12]  = [  I , 0] 	* [A11,A12]
	[A21,A22]     [L21,I]	   [  0  ,  S  ]
with 	L21:= A21*A11inv
		S := A22 - L21 * A12;

generalized form
A = [A11, A12, .., A1n]  = [  I , 0 , ..,  0 ] 		* 	[A11, A12, A1.., A1n ]
	[A21, A22, .., A2n]     [L21, I , ..,  0 ]		   	[  0  ,  S22, S2.., S2n ]
	[A..1, A..2, .., A..n]     [L..1, .. , I, .. ]		   	[  0  ,  S..2, S..,  S..n ]
	[An1, An2, .., Ann]     [Ln1, 0 , .. , I ]		   	[  0  ,  Sn2, Sn.., Snn ]

	A11inv := Invert(A11); (*needed first *)

with  	[L21] :=	[A21] * 	A11inv
		[L31]	[A31]

	i.e.  [L21] :=	[A21] * 	A11inv (*needed for next recursion*)
		[Ln1] :=	[An1] *	A11inv

then	[S22, S23] :=	[A22, A23]	-	[L21] * 	[A12,A13]
		[S32, S33]		[A32, A33]		[L31]

	i.e.  [S22] := A22 - [L21]*[A12]; (*needed for next recursion*)
		[Smn] := Amn - [Lm1]*[A1n];
		[Snm] := Anm - [Ln1]*[A1m];
		[Snn] := Ann - [Ln1]*[A1n];


Algorithm:
	get A11;
	A11inv := Invert(A11);
	get A21;
	L21 := A21 * A11inv;
	get A12;
	get A22;
	S22 := A22 - L21*A12;
		=> Start Recursion - push S22 as (recursion's A11)
	get A31;
	L31 := A31 * A11inv;
	get A32;
	S32 := A32 - L31*A12; - push S32 as recursion's ALL (*could be further split*)
	get A13;
	get A23;
	S23 := A23 - L21*A13; - push S23 as recursion's AUR (*could be further split*)
	get A33;
	S33 := A33 - L31*A13; - push S33 as recursion's ALR(*could be further split*)

Pseudocode:
Algorithm:
*)
