MODULE FoxArrayBaseOptimized;   (**  AUTHOR "fof"; PURPOSE "";  **)

IMPORT SYSTEM, ArrayBase := FoxArrayBase, Machine, KernelLog, Commands ;

CONST

	L2CacheSize = 512 * 1024;   (* L1CacheSize = 16 * 1024;  *)

	(* parameters for blocking matrix multiplication *)
	L1BlockN = 5;   (* L1 block size -> nr of columns in a block that can be processed using L1 chache *)
	L2BARatio = 1;
	L0BlockKR = 4;   (* L0 block size -> nr of elements that can be processed at once for type REAL *)
	L1MaxBlockKR = 336;   (* L1CacheSize/SIZEOF(REAL)/2/6*)
	L2BlockSize = 81920;
	L0BlockKX = 2;   (* L0 block size -> nr of elements that can be processed at once for type LONGREAL *)
	L1MaxBlockKX = 256;   (* > L1CacheSize/SIZEOF(LONGREAL)/2/6*)


	(*
	DefaultL2CacheSize = 81920;
	L2SizeR = L2CacheSize DIV 8;  MaxBlockKR = 336; (* ca L1CacheSize/SIZEOF(REAL)/2/6*)   (* nr of elements that can be processed using L2 cache *)
	L2SizeX = L2CacheSize DIV 8;  MaxBlockKX = 256;  (* bit more than L1CacheSize/SIZEL(LONGREAL)/2/6*) (* nr of elements that can be processed using L2 cache *)
*)



	debug = FALSE;  parallel = TRUE;  SSE = TRUE;

	MaxCachePoolSize = 0 (* disabled *)  (*  646*1024*1024  *)  (* enabled *) ;
	maxProcesses = 32;

	cMatMulDynamic* = -1;  cMatMulScalarProduct* = 0;
	cMatMulNaive* = 1;  cMatMulTransposed* = 2;
	cMatMulStride* = 3;  cMatMulBlocked* = 4;

VAR
	cBlockSize*: LONGINT;  nrProcesses*: LONGINT;
	lastUsedBlockSize*: SIZE;

	allocT-, copyT-, zeroT-, compT-: HUGEINT;

TYPE
	Cache = POINTER TO RECORD
		p: ANY;
		adr: ADDRESS; size: SIZE;
		prev, next: Cache;
	END;
	CachePool = OBJECT
	(*! provide heuristics for overal size *)
	VAR first, last: Cache;

		PROCEDURE & Init*;
		BEGIN
			NEW( first );  first.size := 0;   (* sentinel *)
			NEW( last );  last.size := MAX( SIZE );   (* sentinel *)
			first.next := last;  first.prev := NIL; last.prev := first;  last.next := NIL;
		END Init;

		PROCEDURE Acquire( size: SIZE ): Cache;
		VAR c: Cache;  t: HUGEINT;
		BEGIN {EXCLUSIVE}
			IF size = 0 THEN RETURN first END;
			Tic( t );
			c := last;
			WHILE (c.prev.size >= size) DO
				c := c.prev;
			END;
			IF c = last THEN
				NEW( c );  SYSTEM.NEW( c.p, size + 16 );
				c.adr := Align( c.p , 16 );
				c.size := size;
			ELSE
				c.prev.next := c.next;
				c.next.prev := c.prev;
				c.prev := NIL;  c.next := NIL;
			END;
			Toc( t, allocT );  RETURN c;
		END Acquire;

		PROCEDURE Release( c: Cache );
		VAR t: Cache;
		BEGIN {EXCLUSIVE}
			IF (c=first) OR (c=NIL) THEN RETURN END;
			ASSERT(c.size > 0);
			IF c.size > MaxCachePoolSize THEN RETURN END;
			t := first;
			WHILE (t.size <= c.size) DO t := t.next;  END;
			c.prev := t.prev;  c.next := t;  t.prev := c;  c.prev.next := c;
		END Release;

	END CachePool;

	ComputationObj = OBJECT
	VAR done: BOOLEAN;

		PROCEDURE & Init*;
		BEGIN
			done := FALSE;
		END Init;

		PROCEDURE Compute;   (*abstract*)
		END Compute;

		PROCEDURE Wait;
		BEGIN {EXCLUSIVE}
			AWAIT( done );
		END Wait;

	BEGIN {ACTIVE, EXCLUSIVE}
		Compute;  done := TRUE;
	END ComputationObj;

	MatMulHObjR = OBJECT (ComputationObj)
	VAR MatrixA, MatrixB, MatrixC: ADDRESS; Stride, IncC, StrideC, RowsA, RowsB, Cols: SIZE;
		add: BOOLEAN;

		PROCEDURE & InitR*( MatrixA, MatrixB, MatrixC: ADDRESS; Stride, IncC, StrideC, RowsA, RowsB, Cols: SIZE;
										  add: BOOLEAN );
		BEGIN
			Init;  SELF.MatrixA := MatrixA;  SELF.MatrixB := MatrixB;
			SELF.MatrixC := MatrixC;  SELF.Stride := Stride;
			SELF.IncC := IncC;  SELF.StrideC := StrideC;
			SELF.RowsA := RowsA;  SELF.RowsB := RowsB;
			SELF.Cols := Cols;  SELF.add := add;
		END InitR;

		PROCEDURE Compute;
		BEGIN
			MatMulHBlockR( MatrixA, MatrixB, MatrixC, Stride, IncC,
									  StrideC, RowsA, RowsB, Cols, add );
		END Compute;

	END MatMulHObjR;

	MatMulHObjX = OBJECT (ComputationObj)
	VAR MatrixA, MatrixB, MatrixC: ADDRESS; Stride, IncC, StrideC, RowsA, RowsB, Cols: SIZE;
		add: BOOLEAN;

		PROCEDURE & InitX*( MatrixA, MatrixB, MatrixC: ADDRESS; Stride, IncC, StrideC, RowsA, RowsB, Cols: SIZE;
										  add: BOOLEAN );
		BEGIN
			Init;  SELF.MatrixA := MatrixA;  SELF.MatrixB := MatrixB;
			SELF.MatrixC := MatrixC;  SELF.Stride := Stride;
			SELF.IncC := IncC;  SELF.StrideC := StrideC;
			SELF.RowsA := RowsA;  SELF.RowsB := RowsB;
			SELF.Cols := Cols;  SELF.add := add;
		END InitX;

		PROCEDURE Compute;
		BEGIN
			MatMulHBlockX( MatrixA, MatrixB, MatrixC, Stride, IncC,
									 StrideC, RowsA, RowsB, Cols, add );
		END Compute;

	END MatMulHObjX;

	MultiplyObjectR = OBJECT (ComputationObj);
	VAR adrA, adrB: ADDRESS; C, M, N, K, IncC, StrideC, L2BlockM, L2BlockN, L2BlockK:SIZE;
		start, finished: BOOLEAN;

		PROCEDURE & InitR*( adrA, adrB: ADDRESS; C, M, N, K, IncC, StrideC, L2BlockM, L2BlockN, L2BlockK: SIZE );
		BEGIN
			Init;  start := FALSE;  finished := FALSE;
			SELF.adrA := adrA;  SELF.adrB := adrB;  SELF.C := C;
			SELF.M := M;  SELF.N := N;  SELF.K := K;
			SELF.IncC := IncC;  SELF.StrideC := StrideC;
			SELF.L2BlockM := L2BlockM;
			SELF.L2BlockN := L2BlockN;
			SELF.L2BlockK := L2BlockK;
		END InitR;

		PROCEDURE Compute;
		BEGIN
			L3BlockR( adrA, adrB, C, M, N, K, IncC, StrideC, L2BlockM,
							L2BlockN, L2BlockK );
		END Compute;

	END MultiplyObjectR;

	MultiplyObjectX = OBJECT (ComputationObj);
	VAR adrA, adrB:ADDRESS; C, M, N, K, IncC, StrideC, L2BlockM, L2BlockN, L2BlockK: SIZE;
		start, finished: BOOLEAN;

		PROCEDURE & InitX*( adrA, adrB: ADDRESS; C, M, N, K, IncC, StrideC, L2BlockM, L2BlockN, L2BlockK: SIZE );
		BEGIN
			Init;  start := FALSE;  finished := FALSE;
			SELF.adrA := adrA;  SELF.adrB := adrB;  SELF.C := C;
			SELF.M := M;  SELF.N := N;  SELF.K := K;
			SELF.IncC := IncC;  SELF.StrideC := StrideC;
			SELF.L2BlockM := L2BlockM;
			SELF.L2BlockN := L2BlockN;
			SELF.L2BlockK := L2BlockK;
		END InitX;

		PROCEDURE Compute;
		BEGIN
			L3BlockX( adrA, adrB, C, M, N, K, IncC, StrideC, L2BlockM,
						    L2BlockN, L2BlockK );
		END Compute;

	END MultiplyObjectX;
VAR
	(* ran: Random.Generator;   (* testing *)*)
	cachePool: CachePool;

	(***********  Part 0: assembler routines ***************)



	PROCEDURE -L1Block1XA( adrA, adrB, adrC: ADDRESS; K: SIZE );
	CODE {SYSTEM.AMD64, SYSTEM.FPU}
		MOV	RAX, [RSP+K]	;  RAX IS counter
		MOV	RDX, [RSP+adrC]
		MOV	RCX, [RSP+adrB]	;  RCX IS POINTER TO data OF matrix B
		MOV	RBX, [RSP+adrA]	;  RBX IS POINTER TO data OF matrix A
		FLD	QWORD [RDX]	;  S.GET(dadr, x)
		loop8:
		CMP	RAX, 8
		JL	loop1
		FLD	QWORD[RBX]	;  S.GET(ladr, x)
		ADD	RBX, 8	;  INC(ladr, incl)
		FLD	QWORD[RCX]	;  S.GET(ladr, y)
		ADD	RCX, 8	;  INC(radr, incr)
		FMULP	;  x := x*y
		FADDP	;  z := z+x
		FLD	QWORD[RBX]	;  S.GET(ladr, x)
		ADD	RBX, 8	;  INC(ladr, incl)
		FLD	QWORD[RCX]	;  S.GET(ladr, y)
		ADD	RCX, 8	;  INC(radr, incr)
		FMULP	;  x := x*y
		FADDP	;  z := z+x
		FLD	QWORD[RBX]	;  S.GET(ladr, x)
		ADD	RBX, 8	;  INC(ladr, incl)
		FLD	QWORD[RCX]	;  S.GET(ladr, y)
		ADD	RCX, 8	;  INC(radr, incr)
		FMULP	;  x := x*y
		FADDP	;  z := z+x
		FLD	QWORD[RBX]	;  S.GET(ladr, x)
		ADD	RBX, 8	;  INC(ladr, incl)
		FLD	QWORD[RCX]	;  S.GET(ladr, y)
		ADD	RCX, 8	;  INC(radr, incr)
		FMULP	;  x := x*y
		FADDP	;  z := z+x
		FLD	QWORD[RBX]	;  S.GET(ladr, x)
		ADD	RBX, 8	;  INC(ladr, incl)
		FLD	QWORD[RCX]	;  S.GET(ladr, y)
		ADD	RCX, 8	;  INC(radr, incr)
		FMULP	;  x := x*y
		FADDP	;  z := z+x
		FLD	QWORD[RBX]	;  S.GET(ladr, x)
		ADD	RBX, 8	;  INC(ladr, incl)
		FLD	QWORD[RCX]	;  S.GET(ladr, y)
		ADD	RCX, 8	;  INC(radr, incr)
		FMULP	;  x := x*y
		FADDP	;  z := z+x
		FLD	QWORD[RBX]	;  S.GET(ladr, x)
		ADD	RBX, 8	;  INC(ladr, incl)
		FLD	QWORD[RCX]	;  S.GET(ladr, y)
		ADD	RCX, 8	;  INC(radr, incr)
		FMULP	;  x := x*y
		FADDP	;  z := z+x
		FLD	QWORD[RBX]	;  S.GET(ladr, x)
		ADD	RBX, 8	;  INC(ladr, incl)
		FLD	QWORD[RCX]	;  S.GET(ladr, y)
		ADD	RCX, 8	;  INC(radr, incr)
		FMULP	;  x := x*y
		FADDP	;  z := z+x
		SUB	RAX, 8	;  DEC(len)
		JMP	loop8	;
		loop1:
		CMP	RAX, 0	;  WHILE len > 0 DO
		JLE	endL
		FLD	QWORD[RBX]	;  S.GET(ladr, x)
		ADD	RBX, 8	;  INC(ladr, incl)
		FLD	QWORD[RCX]	;  S.GET(ladr, y)
		ADD	RCX, 8	;  INC(radr, incr)
		FMULP	;  x := x*y
		FADDP	;  z := z+x
		DEC	RAX	;  DEC(len)
		JMP	loop1	;
		endL:
		FSTP	QWORD[RDX]	;  S.PUT(dadr, x)
		FWAIT	;
		ADD	RSP, 32	;
	END L1Block1XA;

	PROCEDURE -L1Block1XSSE( adrA, adrB, adrC: ADDRESS; K: SIZE );
	(*
		matrixA, matrixB must be stored in special format
		K>0 guaranteed
	*)
	CODE {SYSTEM.AMD64, SYSTEM.SSE2}
		MOV	RBX, [RSP+adrA]	;  RBX IS POINTER TO data OF matrix A
		MOV	RCX, [RSP+adrB]	;  RCX IS POINTER TO data OF matrix B
		MOV	RDX, [RSP+K]	;  RDX IS counter
		XORPD	XMM2, XMM2	;
		kLoop8: ;
		CMP	RDX, 8	;
		JL	kLoop2	;
		MOVAPD	XMM7, [RBX]	;
		MOVAPD	XMM0, [RCX]	;
		ADD	RCX, 16	;
		ADD	RBX, 16	;
		MOVAPD	XMM6, [RBX]	;
		MOVAPD	XMM1, [RCX]	;
		ADD	RCX, 16	;
		ADD	RBX, 16	;
		MULPD	XMM0, XMM7	;
		ADDPD	XMM2, XMM0	;
		MOVAPD	XMM5, [RBX]	;
		MOVAPD	XMM3, [RCX]	;
		ADD	RCX, 16	;
		ADD	RBX, 16	;
		MULPD	XMM1, XMM6	;
		ADDPD	XMM2, XMM1	;
		MOVAPD	XMM7, [RBX]	;
		MOVAPD	XMM0, [RCX]	;
		ADD	RCX, 16	;
		ADD	RBX, 16	;
		MULPD	XMM3, XMM5	;
		ADDPD	XMM2, XMM3	;
		MULPD	XMM0, XMM7	;
		ADDPD	XMM2, XMM0	;
		SUB	RDX, 8	;
		JMP	kLoop8	;
		kLoop2: ;
		CMP	RDX, 0	;
		JLE	horizontalAdd	;
		MOVAPD	XMM7, [RBX]	;
		MOVAPD	XMM0, [RCX]	;
		ADD	RCX, 16	;
		ADD	RBX, 16	;
		MULPD	XMM0, XMM7	;
		ADDPD	XMM2, XMM0	;
		SUB	RDX, 2
		JMP	kLoop2	;
		horizontalAdd:
		MOV	RDI, [RSP+adrC]	;
		MOVAPD	XMM1, XMM2	;
		SHUFPD	XMM1, XMM1, 1	;  low bits < -high bits
		ADDPD	XMM2, XMM1	;
		ADDSD	XMM2, [RDI]	;
		MOVSD	[RDI], XMM2	;
		endL:
		ADD	RSP, 32	;
	END L1Block1XSSE;

	PROCEDURE -L1Block5XSSE( adrA, adrB, adrC: ADDRESS; IncC, K: SIZE );
	(*
		matrixA and matrix B are stored in special format !
		K > 0 is guaranteed
	*)
	CODE {SYSTEM.AMD64, SYSTEM.SSE2}
		MOV	RBX, [RSP+adrA]	;  RBX IS POINTER TO data OF matrix A
		MOV	RCX, [RSP+adrB]	;  RCX IS POINTER TO data OF matrix B
		MOV	RDX, [RSP+K]	;  RDX IS counter
		XORPD	XMM2, XMM2	;
		XORPD	XMM3, XMM3	;
		XORPD	XMM4, XMM4	;
		XORPD	XMM5, XMM5	;
		XORPD	XMM6, XMM6	;
		kLoop8: ;
		CMP	RDX, 8	;
		JL	kLoop2
		;   (*-- 0 -- *) ;
		MOVAPD	XMM7, [RBX]	;  get 4 elements OF A
		ADD	RBX, 16	;
		MOVAPD	XMM0, [RCX]	;  get 4 elements OF B
		ADD	RCX, 16	;
		MOVAPD	XMM1, [RCX]	;  get 4 elements OF B
		ADD	RCX, 16	;
		MULPD	XMM0, XMM7	;
		ADDPD	XMM2, XMM0	;
		MOVAPD	XMM0, [RCX]	;
		ADD	RCX, 16	;
		MULPD	XMM1, XMM7	;
		ADDPD	XMM3, XMM1	;
		MOVAPD	XMM1, [RCX]	;
		ADD	RCX, 16	;
		MULPD	XMM0, XMM7	;
		ADDPD	XMM4, XMM0	;
		MOVAPD	XMM0, [RCX]	;
		ADD	RCX, 16	;
		MULPD	XMM1, XMM7	;
		ADDPD	XMM5, XMM1	;
		MOVAPD	XMM1, [RCX]	;
		ADD	RCX, 16	;
		MULPD	XMM0, XMM7	;
		ADDPD	XMM6, XMM0
		;   (*-- 2 -- *) ;
		MOVAPD	XMM7, [RBX]	;
		ADD	RBX, 16	;
		MOVAPD	XMM0, [RCX]	;
		ADD	RCX, 16	;
		MULPD	XMM1, XMM7	;
		ADDPD	XMM2, XMM1	;
		MOVAPD	XMM1, [RCX]	;
		ADD	RCX, 16	;
		MULPD	XMM0, XMM7	;
		ADDPD	XMM3, XMM0	;
		MOVAPD	XMM0, [RCX]	;
		ADD	RCX, 16	;
		MULPD	XMM1, XMM7	;
		ADDPD	XMM4, XMM1	;
		MOVAPD	XMM1, [RCX]	;
		ADD	RCX, 16	;
		MULPD	XMM0, XMM7	;
		ADDPD	XMM5, XMM0	;
		MOVAPD	XMM0, [RCX]	;
		ADD	RCX, 16	;
		MULPD	XMM1, XMM7	;
		ADDPD	XMM6, XMM1
		;   (*-- 4 -- *) ;
		MOVAPD	XMM7, [RBX]	;
		ADD	RBX, 16	;
		MOVAPD	XMM1, [RCX]	;
		ADD	RCX, 16	;
		MULPD	XMM0, XMM7	;
		ADDPD	XMM2, XMM0	;
		MOVAPD	XMM0, [RCX]	;
		ADD	RCX, 16	;
		MULPD	XMM1, XMM7	;
		ADDPD	XMM3, XMM1	;
		MOVAPD	XMM1, [RCX]	;
		ADD	RCX, 16	;
		MULPD	XMM0, XMM7	;
		ADDPD	XMM4, XMM0	;
		MOVAPD	XMM0, [RCX]	;
		ADD	RCX, 16	;
		MULPD	XMM1, XMM7	;
		ADDPD	XMM5, XMM1	;
		MOVAPD	XMM1, [RCX]	;
		ADD	RCX, 16	;
		MULPD	XMM0, XMM7	;
		ADDPD	XMM6, XMM0
		;   (*-- 6 -- *) ;
		MOVAPD	XMM7, [RBX]	;
		ADD	RBX, 16	;
		MOVAPD	XMM0, [RCX]	;
		ADD	RCX, 16	;
		MULPD	XMM1, XMM7	;
		ADDPD	XMM2, XMM1	;
		MOVAPD	XMM1, [RCX]	;
		ADD	RCX, 16	;
		MULPD	XMM0, XMM7	;
		ADDPD	XMM3, XMM0	;
		MOVAPD	XMM0, [RCX]	;
		ADD	RCX, 16	;
		MULPD	XMM1, XMM7	;
		ADDPD	XMM4, XMM1	;
		MOVAPD	XMM1, [RCX]	;
		ADD	RCX, 16	;
		MULPD	XMM0, XMM7	;
		ADDPD	XMM5, XMM0	;
		MULPD	XMM1, XMM7	;
		ADDPD	XMM6, XMM1	;
		SUB	RDX, 8
		JMP	kLoop8	;
		kLoop2: ;
		CMP	RDX, 0	;
		JLE	horizontalAdd	;
		MOVAPD	XMM7, [RBX]	;
		ADD	RBX, 16	;
		MOVAPD	XMM0, [RCX]	;
		ADD	RCX, 16	;
		MOVAPD	XMM1, [RCX]	;
		ADD	RCX, 16	;
		MULPD	XMM0, XMM7	;
		ADDPD	XMM2, XMM0	;
		MOVAPD	XMM0, [RCX]	;
		ADD	RCX, 16	;
		MULPD	XMM1, XMM7	;
		ADDPD	XMM3, XMM1	;
		MOVAPD	XMM1, [RCX]	;
		ADD	RCX, 16	;
		MULPD	XMM0, XMM7	;
		ADDPD	XMM4, XMM0	;
		MOVAPD	XMM0, [RCX]	;
		ADD	RCX, 16	;
		MULPD	XMM1, XMM7	;
		ADDPD	XMM5, XMM1	;
		MULPD	XMM0, XMM7	;
		ADDPD	XMM6, XMM0	;
		SUB	RDX, 2
		JMP	kLoop2	;
		horizontalAdd: ;  add and store
		MOV	RDI, [RSP+adrC]	;
		MOV	RAX, [RSP+IncC]	;
		MOVAPD	XMM1, XMM2	;
		SHUFPD	XMM1, XMM1, 1	;  low bits < -high bits
		ADDPD	XMM2, XMM1	;
		ADDSD	XMM2, [RDI]	;
		MOVSD	[RDI], XMM2	;
		ADD	RDI, RAX	;
		MOVAPD	XMM1, XMM3	;
		SHUFPD	XMM1, XMM1, 1	;  low bits < -high bits
		ADDPD	XMM3, XMM1	;
		ADDSD	XMM3, [RDI]	;
		MOVSD	[RDI], XMM3	;
		ADD	RDI, RAX	;
		MOVAPD	XMM1, XMM4	;
		SHUFPD	XMM1, XMM1, 1	;  low bits < -high bits
		ADDPD	XMM4, XMM1	;
		ADDSD	XMM4, [RDI]	;
		MOVSD	[RDI], XMM4	;
		ADD	RDI, RAX	;
		MOVAPD	XMM1, XMM5	;
		SHUFPD	XMM1, XMM1, 1	;  low bits < -high bits
		ADDPD	XMM5, XMM1	;
		ADDSD	XMM5, [RDI]	;
		MOVSD	[RDI], XMM5	;
		ADD	RDI, RAX	;
		MOVAPD	XMM1, XMM6	;
		SHUFPD	XMM1, XMM1, 1	;  low bits < -high bits
		ADDPD	XMM6, XMM1	;
		ADDSD	XMM6, [RDI]	;
		MOVSD	[RDI], XMM6	;
		endL:
		ADD	RSP, 40	;
	END L1Block5XSSE;

	PROCEDURE -L1Block1RA( adrA, adrB, adrC: ADDRESS; K: SIZE );
	CODE {SYSTEM.AMD64, SYSTEM.FPU}
		MOV	RAX, [RSP+K]	;  RAX IS counter
		MOV	RDX, [RSP+adrC]
		MOV	RCX, [RSP+adrB]	;  RCX IS POINTER TO data OF matrix B
		MOV	RBX, [RSP+adrA]	;  RBX IS POINTER TO data OF matrix A
		FLD	DWORD [RDX]	;  S.GET(dadr, x)
		loop16:
		CMP	RAX, 16
		JL	loop1
		FLD	DWORD[RBX]	;  S.GET(ladr, x)
		ADD	RBX, 4	;  INC(ladr, incl)
		FLD	DWORD[RCX]	;  S.GET(ladr, y)
		ADD	RCX, 4	;  INC(radr, incr)
		FMULP	;  x := x*y
		FADDP	;  z := z+x
		FLD	DWORD[RBX]	;  S.GET(ladr, x)
		ADD	RBX, 4	;  INC(ladr, incl)
		FLD	DWORD[RCX]	;  S.GET(ladr, y)
		ADD	RCX, 4	;  INC(radr, incr)
		FMULP	;  x := x*y
		FADDP	;  z := z+x
		FLD	DWORD[RBX]	;  S.GET(ladr, x)
		ADD	RBX, 4	;  INC(ladr, incl)
		FLD	DWORD[RCX]	;  S.GET(ladr, y)
		ADD	RCX, 4	;  INC(radr, incr)
		FMULP	;  x := x*y
		FADDP	;  z := z+x
		FLD	DWORD[RBX]	;  S.GET(ladr, x)
		ADD	RBX, 4	;  INC(ladr, incl)
		FLD	DWORD[RCX]	;  S.GET(ladr, y)
		ADD	RCX, 4	;  INC(radr, incr)
		FMULP	;  x := x*y
		FADDP	;  z := z+x
		FLD	DWORD[RBX]	;  S.GET(ladr, x)
		ADD	RBX, 4	;  INC(ladr, incl)
		FLD	DWORD[RCX]	;  S.GET(ladr, y)
		ADD	RCX, 4	;  INC(radr, incr)
		FMULP	;  x := x*y
		FADDP	;  z := z+x
		FLD	DWORD[RBX]	;  S.GET(ladr, x)
		ADD	RBX, 4	;  INC(ladr, incl)
		FLD	DWORD[RCX]	;  S.GET(ladr, y)
		ADD	RCX, 4	;  INC(radr, incr)
		FMULP	;  x := x*y
		FADDP	;  z := z+x
		FLD	DWORD[RBX]	;  S.GET(ladr, x)
		ADD	RBX, 4	;  INC(ladr, incl)
		FLD	DWORD[RCX]	;  S.GET(ladr, y)
		ADD	RCX, 4	;  INC(radr, incr)
		FMULP	;  x := x*y
		FADDP	;  z := z+x
		FLD	DWORD[RBX]	;  S.GET(ladr, x)
		ADD	RBX, 4	;  INC(ladr, incl)
		FLD	DWORD[RCX]	;  S.GET(ladr, y)
		ADD	RCX, 4	;  INC(radr, incr)
		FMULP	;  x := x*y
		FADDP	;  z := z+x
		FLD	DWORD[RBX]	;  S.GET(ladr, x)
		ADD	RBX, 4	;  INC(ladr, incl)
		FLD	DWORD[RCX]	;  S.GET(ladr, y)
		ADD	RCX, 4	;  INC(radr, incr)
		FMULP	;  x := x*y
		FADDP	;  z := z+x
		FLD	DWORD[RBX]	;  S.GET(ladr, x)
		ADD	RBX, 4	;  INC(ladr, incl)
		FLD	DWORD[RCX]	;  S.GET(ladr, y)
		ADD	RCX, 4	;  INC(radr, incr)
		FMULP	;  x := x*y
		FADDP	;  z := z+x
		FLD	DWORD[RBX]	;  S.GET(ladr, x)
		ADD	RBX, 4	;  INC(ladr, incl)
		FLD	DWORD[RCX]	;  S.GET(ladr, y)
		ADD	RCX, 4	;  INC(radr, incr)
		FMULP	;  x := x*y
		FADDP	;  z := z+x
		FLD	DWORD[RBX]	;  S.GET(ladr, x)
		ADD	RBX, 4	;  INC(ladr, incl)
		FLD	DWORD[RCX]	;  S.GET(ladr, y)
		ADD	RCX, 4	;  INC(radr, incr)
		FMULP	;  x := x*y
		FADDP	;  z := z+x
		FLD	DWORD[RBX]	;  S.GET(ladr, x)
		ADD	RBX, 4	;  INC(ladr, incl)
		FLD	DWORD[RCX]	;  S.GET(ladr, y)
		ADD	RCX, 4	;  INC(radr, incr)
		FMULP	;  x := x*y
		FADDP	;  z := z+x
		FLD	DWORD[RBX]	;  S.GET(ladr, x)
		ADD	RBX, 4	;  INC(ladr, incl)
		FLD	DWORD[RCX]	;  S.GET(ladr, y)
		ADD	RCX, 4	;  INC(radr, incr)
		FMULP	;  x := x*y
		FADDP	;  z := z+x
		FLD	DWORD[RBX]	;  S.GET(ladr, x)
		ADD	RBX, 4	;  INC(ladr, incl)
		FLD	DWORD[RCX]	;  S.GET(ladr, y)
		ADD	RCX, 4	;  INC(radr, incr)
		FMULP	;  x := x*y
		FADDP	;  z := z+x
		FLD	DWORD[RBX]	;  S.GET(ladr, x)
		ADD	RBX, 4	;  INC(ladr, incl)
		FLD	DWORD[RCX]	;  S.GET(ladr, y)
		ADD	RCX, 4	;  INC(radr, incr)
		FMULP	;  x := x*y
		FADDP	;  z := z+x
		SUB	RAX, 16	;  DEC(len)
		JMP	loop16	;
		loop1:
		CMP	RAX, 0	;  WHILE len > 0 DO
		JLE	endL
		FLD	DWORD[RBX]	;  S.GET(ladr, x)
		ADD	RBX, 4	;  INC(ladr, incl)
		FLD	DWORD[RCX]	;  S.GET(ladr, y)
		ADD	RCX, 4	;  INC(radr, incr)
		FMULP	;  x := x*y
		FADDP	;  z := z+x
		DEC	RAX	;  DEC(len)
		JMP	loop1	;
		endL:
		FSTP	DWORD[RDX]	;  S.PUT(dadr, x)
		FWAIT	;
		ADD	RSP, 32	;
	END L1Block1RA;

	PROCEDURE -L1Block1RSSE( adrA, adrB, adrC: ADDRESS; K: SIZE );
	(*
		matrixA, matrixB must be stored in special format
		K>0 guaranteed
	*)
	CODE {SYSTEM.AMD64, SYSTEM.SSE}
		MOV	RBX, [RSP+adrA]	;  RBX IS POINTER TO data OF matrix A
		MOV	RCX, [RSP+adrB]	;  RCX IS POINTER TO data OF matrix B
		MOV	RDX, [RSP+K]	;  RDX IS counter
		XORPS	XMM2, XMM2	;
		kLoop16: ;
		CMP	RDX, 16	;
		JL	kLoop4	;
		MOVAPS	XMM7, [RBX]	;
		MOVAPS	XMM0, [RCX]	;
		ADD	RCX, 16	;
		ADD	RBX, 16	;
		MOVAPS	XMM6, [RBX]	;
		MOVAPS	XMM1, [RCX]	;
		ADD	RCX, 16	;
		ADD	RBX, 16	;
		MULPS	XMM0, XMM7	;
		ADDPS	XMM2, XMM0	;
		MOVAPS	XMM5, [RBX]	;
		MOVAPS	XMM3, [RCX]	;
		ADD	RCX, 16	;
		ADD	RBX, 16	;
		MULPS	XMM1, XMM6	;
		ADDPS	XMM2, XMM1	;
		MOVAPS	XMM7, [RBX]	;
		MOVAPS	XMM0, [RCX]	;
		ADD	RCX, 16	;
		ADD	RBX, 16	;
		MULPS	XMM3, XMM5	;
		ADDPS	XMM2, XMM3	;
		MULPS	XMM0, XMM7	;
		ADDPS	XMM2, XMM0	;
		SUB	RDX, 16	;
		JMP	kLoop16	;
		kLoop4: ;
		CMP	RDX, 0	;
		JLE	horizontalAdd	;
		MOVAPS	XMM7, [RBX]	;
		MOVAPS	XMM0, [RCX]	;
		ADD	RCX, 16	;
		ADD	RBX, 16	;
		MULPS	XMM0, XMM7	;
		ADDPS	XMM2, XMM0	;
		SUB	RDX, 4
		JMP	kLoop4	;
		horizontalAdd:
		MOV	RDI, [RSP+adrC]	;
		MOVLHPS	XMM1, XMM2	;
		ADDPS	XMM1, XMM2	;
		SHUFPS	XMM2, XMM1, 48	;
		ADDPS	XMM2, XMM1	;
		MOVHLPS	XMM2, XMM2	;
		ADDSS	XMM2, [RDI]	;
		MOVSS	[RDI], XMM2	;
		endL:
		ADD	RSP, 32	;
	END L1Block1RSSE;

	PROCEDURE -L1Block5RSSE( adrA, adrB, adrC: ADDRESS; IncC, K: SIZE );
	(*
		matrixA and matrix B are stored in special format !
		K > 0 is guaranteed
	*)
	CODE {SYSTEM.AMD64, SYSTEM.SSE}
		MOV	RBX, [RSP+adrA]	;  RBX IS POINTER TO data OF matrix A
		MOV	RCX, [RSP+adrB]	;  RCX IS POINTER TO data OF matrix B
		MOV	RDX, [RSP+K]	;  RDX IS counter
		XORPS	XMM2, XMM2	;
		XORPS	XMM3, XMM3	;
		XORPS	XMM4, XMM4	;
		XORPS	XMM5, XMM5	;
		XORPS	XMM6, XMM6	;
		kLoop16: ;
		CMP	RDX, 16	;
		JL	kLoop4	;   (*-- 0 -- *)
		MOVAPS	XMM7, [RBX]	;  get 4 elements OF A
		ADD	RBX, 16	;
		MOVAPS	XMM0, [RCX]	;  get 4 elements OF B
		ADD	RCX, 16	;
		MOVAPS	XMM1, [RCX]	;  get 4 elements OF B
		ADD	RCX, 16	;
		MULPS	XMM0, XMM7	;
		ADDPS	XMM2, XMM0	;
		MOVAPS	XMM0, [RCX]	;
		ADD	RCX, 16	;
		MULPS	XMM1, XMM7	;
		ADDPS	XMM3, XMM1	;
		MOVAPS	XMM1, [RCX]	;
		ADD	RCX, 16	;
		MULPS	XMM0, XMM7	;
		ADDPS	XMM4, XMM0	;
		MOVAPS	XMM0, [RCX]	;
		ADD	RCX, 16	;
		MULPS	XMM1, XMM7	;
		ADDPS	XMM5, XMM1	;
		MOVAPS	XMM1, [RCX]	;
		ADD	RCX, 16	;
		MULPS	XMM0, XMM7	;
		ADDPS	XMM6, XMM0
		;   (*-- 4 -- *) ;
		MOVAPS	XMM7, [RBX]	;
		ADD	RBX, 16	;
		MOVAPS	XMM0, [RCX]	;
		ADD	RCX, 16	;
		MULPS	XMM1, XMM7	;
		ADDPS	XMM2, XMM1	;
		MOVAPS	XMM1, [RCX]	;
		ADD	RCX, 16	;
		MULPS	XMM0, XMM7	;
		ADDPS	XMM3, XMM0	;
		MOVAPS	XMM0, [RCX]	;
		ADD	RCX, 16	;
		MULPS	XMM1, XMM7	;
		ADDPS	XMM4, XMM1	;
		MOVAPS	XMM1, [RCX]	;
		ADD	RCX, 16	;
		MULPS	XMM0, XMM7	;
		ADDPS	XMM5, XMM0	;
		MOVAPS	XMM0, [RCX]	;
		ADD	RCX, 16	;
		MULPS	XMM1, XMM7	;
		ADDPS	XMM6, XMM1
		;   (*-- 8 -- *) ;
		MOVAPS	XMM7, [RBX]	;
		ADD	RBX, 16	;
		MOVAPS	XMM1, [RCX]	;
		ADD	RCX, 16	;
		MULPS	XMM0, XMM7	;
		ADDPS	XMM2, XMM0	;
		MOVAPS	XMM0, [RCX]	;
		ADD	RCX, 16	;
		MULPS	XMM1, XMM7	;
		ADDPS	XMM3, XMM1	;
		MOVAPS	XMM1, [RCX]	;
		ADD	RCX, 16	;
		MULPS	XMM0, XMM7	;
		ADDPS	XMM4, XMM0	;
		MOVAPS	XMM0, [RCX]	;
		ADD	RCX, 16	;
		MULPS	XMM1, XMM7	;
		ADDPS	XMM5, XMM1	;
		MOVAPS	XMM1, [RCX]	;
		ADD	RCX, 16	;
		MULPS	XMM0, XMM7	;
		ADDPS	XMM6, XMM0
		;   (*-- 12 -- *) ;
		MOVAPS	XMM7, [RBX]	;
		ADD	RBX, 16	;
		MOVAPS	XMM0, [RCX]	;
		ADD	RCX, 16	;
		MULPS	XMM1, XMM7	;
		ADDPS	XMM2, XMM1	;
		MOVAPS	XMM1, [RCX]	;
		ADD	RCX, 16	;
		MULPS	XMM0, XMM7	;
		ADDPS	XMM3, XMM0	;
		MOVAPS	XMM0, [RCX]	;
		ADD	RCX, 16	;
		MULPS	XMM1, XMM7	;
		ADDPS	XMM4, XMM1	;
		MOVAPS	XMM1, [RCX]	;
		ADD	RCX, 16	;
		MULPS	XMM0, XMM7	;
		ADDPS	XMM5, XMM0	;
		MULPS	XMM1, XMM7	;
		ADDPS	XMM6, XMM1	;
		SUB	RDX, 16
		JMP	kLoop16	;
		kLoop4: ;
		CMP	RDX, 0	;
		JLE	horizontalAdd	;
		MOVAPS	XMM7, [RBX]	;
		ADD	RBX, 16	;
		MOVAPS	XMM0, [RCX]	;
		ADD	RCX, 16	;
		MOVAPS	XMM1, [RCX]	;
		ADD	RCX, 16	;
		MULPS	XMM0, XMM7	;
		ADDPS	XMM2, XMM0	;
		MOVAPS	XMM0, [RCX]	;
		ADD	RCX, 16	;
		MULPS	XMM1, XMM7	;
		ADDPS	XMM3, XMM1	;
		MOVAPS	XMM1, [RCX]	;
		ADD	RCX, 16	;
		MULPS	XMM0, XMM7	;
		ADDPS	XMM4, XMM0	;
		MOVAPS	XMM0, [RCX]	;
		ADD	RCX, 16	;
		MULPS	XMM1, XMM7	;
		ADDPS	XMM5, XMM1	;
		MULPS	XMM0, XMM7	;
		ADDPS	XMM6, XMM0	;
		SUB	RDX, 4
		JMP	kLoop4	;
		horizontalAdd: ;  add and store
		MOV	RDI, [RSP+adrC]	;
		MOV	RAX, [RSP+IncC]	;
		MOVLHPS	XMM1, XMM2	;
		ADDPS	XMM1, XMM2	;
		SHUFPS	XMM2, XMM1, 48	;
		ADDPS	XMM2, XMM1	;
		MOVHLPS	XMM2, XMM2	;
		ADDSS	XMM2, [RDI]	;
		MOVSS	[RDI], XMM2	;
		ADD	RDI, RAX	;
		MOVLHPS	XMM1, XMM3	;
		ADDPS	XMM1, XMM3	;
		SHUFPS	XMM3, XMM1, 48	;
		ADDPS	XMM3, XMM1	;
		MOVHLPS	XMM3, XMM3	;
		ADDSS	XMM3, [RDI]	;
		MOVSS	[RDI], XMM3	;
		ADD	RDI, RAX	;
		MOVLHPS	XMM1, XMM4	;
		ADDPS	XMM1, XMM4	;
		SHUFPS	XMM4, XMM1, 48	;
		ADDPS	XMM4, XMM1	;
		MOVHLPS	XMM4, XMM4	;
		ADDSS	XMM4, [RDI]	;
		MOVSS	[RDI], XMM4	;
		ADD	RDI, RAX	;
		MOVLHPS	XMM1, XMM5	;
		ADDPS	XMM1, XMM5	;
		SHUFPS	XMM5, XMM1, 48	;
		ADDPS	XMM5, XMM1	;
		MOVHLPS	XMM5, XMM5	;
		ADDSS	XMM5, [RDI]	;
		MOVSS	[RDI], XMM5	;
		ADD	RDI, RAX	;
		MOVLHPS	XMM1, XMM6	;
		ADDPS	XMM1, XMM6	;
		SHUFPS	XMM6, XMM1, 48	;
		ADDPS	XMM6, XMM1	;
		MOVHLPS	XMM6, XMM6	;
		ADDSS	XMM6, [RDI]	;
		MOVSS	[RDI], XMM6	;
		endL:
		ADD	RSP, 40	;
	END L1Block5RSSE;

	PROCEDURE -Align4( adr: ADDRESS ): ADDRESS;
	CODE {SYSTEM.AMD64}
		MOV	RAX, [RSP+adr]	;
		NEG	RAX	;
		AND	RAX, 3H	;
		ADD	RAX, [RSP+adr]	;
		ADD	RSP, 8
	END Align4;

	PROCEDURE -Align2( adr: ADDRESS ): ADDRESS;
	CODE {SYSTEM.AMD64}
		MOV	RAX, [RSP+adr]	;
		NEG	RAX	;
		AND	RAX, 1H	;
		ADD	RAX, [RSP+adr]	;
		ADD	RSP, 8
	END Align2;

	PROCEDURE -ZeroR( adr: ADDRESS;  count: SIZE );
	(** For 32 bit types *)
	CODE {SYSTEM.AMD64}
		MOV	RDI, [RSP+adr]	;  address OF dest index
		MOV	RCX, [RSP+count]	;  counter
		MOV	RAX, 0	;  value
		CLD	;  incremental
		REP	;
		STOSD	;
		ADD	RSP, 16	;
	END ZeroR;

	PROCEDURE -ZeroX( adr: ADDRESS;  count: SIZE );
	(** For 64 bit types *)
	CODE {SYSTEM.AMD64}
		MOV	RDI, [RSP+adr]	;  address OF dest index
		MOV	RCX, [RSP+count]	;  counter
		SHL	RCX, 1	;
		MOV	RAX, 0	;  value
		CLD	;  incremental
		REP	;
		STOSD	;
		ADD	RSP, 16	;
	END ZeroX;

	PROCEDURE -ZeroRI( adr: SIZE; inc, count: SIZE );
	(** For 32 bit types *)
	CODE {SYSTEM.AMD64}
		MOV	RDI, [RSP+adr]	;  address OF dest index
		MOV	RBX, [RSP+inc]	;
		MOV	RCX, [RSP+count]	;  counter
		CMP	RBX, 4	;
		JE	fastzero	;
		MOV	RAX, 0	;
		loopL:
		CMP	RCX, 0	;
		JLE	endL	;
		MOV	[RDI], RAX	;
		ADD	RDI, RBX	;
		DEC	RCX	;
		JMP	loopL	;
		fastzero:
		MOV	RAX, 0	;  value
		CLD	;  incremental
		REP	;
		STOSD	;
		endL:
		ADD	RSP, 24	;
	END ZeroRI;

	PROCEDURE -ZeroXI( adr: ADDRESS; inc, count: SIZE );
	(** For 32 bit types *)
	CODE {SYSTEM.AMD64}
		MOV	RDI, [RSP+adr]	;  address OF dest index
		MOV	RBX, [RSP+inc]	;
		MOV	RCX, [RSP+count]	;  counter
		MOV	RAX, 0	;
		CMP	RBX, 8	;
		JE	fastzero	;
		loopL:
		CMP	RCX, 0	;
		JLE	endL	;
		MOV	[RDI], RAX	;
		MOV	[RDI+4], RAX	;
		ADD	RDI, RBX	;
		DEC	RCX	;
		JMP	loopL	;
		fastzero:
		SHL	RCX, 1	;
		CLD	;  incremental
		REP	;
		STOSD	;
		endL:
		ADD	RSP, 24	;
	END ZeroXI;

	PROCEDURE -MovR( from, to0, frominc, count: SIZE );
	CODE {SYSTEM.AMD64}
		MOV	RDI, [RSP+to0]	;  TO
		MOV	RSI, [RSP+from]	;  from
		MOV	RCX, [RSP+count]	;  count
		MOV	RBX, [RSP+frominc]	;  inc
		CMP	RBX, 4	;
		JE	fastmove	;
		loopL:
		CMP	RCX, 0	;
		JLE	endL	;
		MOV	RAX, [RSI]	;
		MOV	[RDI], RAX	;
		ADD	RSI, RBX	;
		ADD	RDI, 4	;
		DEC	RCX	;
		JMP	loopL	;
		fastmove:
		CLD	;  incremental
		REP	;
		MOVSD	;  move rest IN one byte steps
		endL:
		ADD	RSP, 32	;
	END MovR;

	PROCEDURE -MovX( from, to0: ADDRESS; frominc, count:SIZE );
	CODE {SYSTEM.AMD64}
		MOV	RDI, [RSP+to0]	;  TO
		MOV	RSI, [RSP+from]	;  from
		MOV	RCX, [RSP+count]	;  count
		MOV	RBX, [RSP+frominc]	;  inc
		CMP	RBX, 8	;
		JE	fastmove	;
		loopL:
		CMP	RCX, 0	;
		JLE	endL	;
		MOV	RAX, [RSI]	;
		MOV	[RDI], RAX	;
		MOV	RAX, [RSI+4]	;
		MOV	[RDI+4], RAX	;
		ADD	RSI, RBX	;
		ADD	RDI, 8	;
		DEC	RCX	;
		JMP	loopL	;
		fastmove:
		SHL	RCX, 1	;
		CLD	;  incremental
		REP	;
		MOVSD	;  move rest IN one byte steps
		endL:
		ADD	RSP, 32	;
	END MovX;

	PROCEDURE -MovR5( src: ADDRESS; inc, stride: SIZE; dest: ADDRESS; count: SIZE);
	CODE {SYSTEM.AMD64}
		MOV	RSI, [RSP+src]	;  src
		MOV	RBX, [RSP+inc]	;  inc
		MOV	RCX, [RSP+stride]	;  stride
		MOV	RDI, [RSP+dest]	;  dest
		loopL:
		MOV	RAX, [RSP+count]	;  count
		CMP	RAX, 0	;
		JLE	endL	;
		SUB	RAX, 4	;
		MOV	[RSP+count], RAX	;
		MOV	RDX, RSI	;
		MOV	RAX, [RDX]	;
		MOV	[RDI], RAX	;
		ADD	RDX, RBX	;
		MOV	RAX, [RDX]	;
		MOV	[RDI+16], RAX	;
		ADD	RDX, RBX	;
		MOV	RAX, [RDX]	;
		MOV	[RDI+32], RAX	;
		ADD	RDX, RBX	;
		MOV	RAX, [RDX]	;
		MOV	[RDI+48], RAX	;
		ADD	RDX, RBX	;
		MOV	RAX, [RDX]	;
		MOV	[RDI+64], RAX	;
		ADD	RSI, RCX	;
		ADD	RDI, 4	;
		MOV	RDX, RSI	;
		MOV	RAX, [RDX]	;
		MOV	[RDI], RAX	;
		ADD	RDX, RBX	;
		MOV	RAX, [RDX]	;
		MOV	[RDI+16], RAX	;
		ADD	RDX, RBX	;
		MOV	RAX, [RDX]	;
		MOV	[RDI+32], RAX	;
		ADD	RDX, RBX	;
		MOV	RAX, [RDX]	;
		MOV	[RDI+48], RAX	;
		ADD	RDX, RBX	;
		MOV	RAX, [RDX]	;
		MOV	[RDI+64], RAX	;
		ADD	RSI, RCX	;
		ADD	RDI, 4	;
		MOV	RDX, RSI	;
		MOV	RAX, [RDX]	;
		MOV	[RDI], RAX	;
		ADD	RDX, RBX	;
		MOV	RAX, [RDX]	;
		MOV	[RDI+16], RAX	;
		ADD	RDX, RBX	;
		MOV	RAX, [RDX]	;
		MOV	[RDI+32], RAX	;
		ADD	RDX, RBX	;
		MOV	RAX, [RDX]	;
		MOV	[RDI+48], RAX	;
		ADD	RDX, RBX	;
		MOV	RAX, [RDX]	;
		MOV	[RDI+64], RAX	;
		ADD	RSI, RCX	;
		ADD	RDI, 4	;
		MOV	RDX, RSI	;
		MOV	RAX, [RDX]	;
		MOV	[RDI], RAX	;
		ADD	RDX, RBX	;
		MOV	RAX, [RDX]	;
		MOV	[RDI+16], RAX	;
		ADD	RDX, RBX	;
		MOV	RAX, [RDX]	;
		MOV	[RDI+32], RAX	;
		ADD	RDX, RBX	;
		MOV	RAX, [RDX]	;
		MOV	[RDI+48], RAX	;
		ADD	RDX, RBX	;
		MOV	RAX, [RDX]	;
		MOV	[RDI+64], RAX	;
		ADD	RSI, RCX	;
		ADD	RDI, 4	;
		ADD	RDI, 64	;
		JMP	loopL	;
		endL:
		ADD	RSP, 40	;
	END MovR5;

(* *)
	PROCEDURE AddAXAXLoopA( ladr, radr, dadr: ADDRESS; linc, rinc, dinc, len: SIZE );
	CODE {SYSTEM.AMD64, SYSTEM.FPU}
		MOV	RAX, [RBP+len]	;
		MOV	RBX, [RBP+ladr]	;
		MOV	RCX, [RBP+radr]	;
		MOV	RDX, [RBP+dadr]	;
		start:
		CMP	RAX, 0	;
		JLE	endL	;
		FLD	QWORD [RBX]	;
		ADD	RBX, [RBP+linc]	;
		FLD	QWORD [RCX]	;
		ADD	RCX, [RBP+rinc]	;
		FADDP	;
		FSTP	QWORD [RDX]	;
		ADD	RDX, [RBP+dinc]	;
		DEC	RAX	;
		JMP	start	;
		endL:
		FWAIT	;
	END AddAXAXLoopA;

	PROCEDURE AddARARLoopA( ladr, radr, dadr: ADDRESS; linc, rinc, dinc, len: SIZE );
	CODE {SYSTEM.AMD64, SYSTEM.FPU}
		MOV	RAX, [RBP+len]	;
		MOV	RBX, [RBP+ladr]	;
		MOV	RCX, [RBP+radr]	;
		MOV	RDX, [RBP+dadr]	;
		start:
		CMP	RAX, 0	;
		JLE	endL	;
		FLD	DWORD [RBX]	;
		ADD	RBX, [RBP+linc]	;
		FLD	DWORD [RCX]	;
		ADD	RCX, [RBP+rinc]	;
		FADDP	;
		FSTP	DWORD [RDX]	;
		ADD	RDX, [RBP+dinc]	;
		DEC	RAX	;
		JMP	start	;
		endL:
		FWAIT	;
	END AddARARLoopA;

	PROCEDURE AddAXAXLoopSSE( ladr, radr, dadr: ADDRESS; linc, rinc, dinc, len: SIZE );
	CODE {SYSTEM.AMD64, SYSTEM.SSE2}
		MOV	RAX, [RBP+len]	;
		CMP	RAX, 0	;
		JLE	endL	;  nothing TO be done, RAX > 0 guaranteed from here on
		MOV	RBX, [RBP+ladr]	;
		MOV	RCX, [RBP+radr]	;
		MOV	RDX, [RBP+dadr]	;
		;  check IF data are contiguous IN memory
		CMP	[RBP+linc], 8	;  check left FOR contiunuity
		JNE	single	;  not continuous- > simplest method
		CMP	[RBP+rinc], 8	;  check right FOR contiunuity
		JNE	single	;  not continuous- > simplest method
		CMP	[RBP+dinc], 8	;  check destination FOR contiunuity
		JNE	single	;  not continuous- > simplest method
		;  check FOR alignment
		MOV	RSI, RBX	;
		AND	RSI, 7	;  ladr MOD 8
		CMP	RSI, 0	;  = 0- > 64 Bit alignment
		JNE	unaligned	;  not 64 bit aligned
		MOV	RSI, RCX	;
		AND	RSI, 7	;  radr MOD 8
		CMP	RSI, 0	;  = 0- > 64 Bit alignment
		JNE	unaligned	;  not 64 bit aligned
		MOV	RSI, RDX	;
		AND	RSI, 7	;  dadr MOD 8
		CMP	RSI, 0	;  = 0- > 64 Bit alignment
		JNE	unaligned	;  not 64 bit aligned
		MOV	RSI, RBX	;
		AND	RSI, 8	;  16 byte alignment
		MOV	RDI, RCX	;
		AND	RDI, 8	;  16 byte alignment
		CMP	RSI, RDI	;
		JNE	unaligned	;  different 16 byte = 128 bit alignment OF ladr and radr
		MOV	RDI, RDX	;
		AND	RDI, 8	;  16 byte alignment
		CMP	RSI, RDI	;
		JNE	unaligned	;  different 16 byte = 128 bit alignment OF dadr and radr
		CMP	RSI, 8	;
		JNE	aligned	;  lad, radr and dadr already 128 bit aligned
		;  one single element processing TO achieve 128 bt alignment
		MOVSD	XMM1, [RBX]	;
		MOVSD	XMM0, [RCX]	;
		ADDSD	XMM0, XMM1	;
		MOVSD	[RDX], XMM0	;
		ADD	RBX, 8	;  now RBX IS 16 byte aligned
		ADD	RCX, 8	;  now RDX IS 16 byte aligned	;
		ADD	RDX, 8	;  now RDX IS 16 byte aligned	;
		DEC	RAX	;  one element has been processed
		aligned:
		aligned8:
		CMP	RAX, 8	;
		JL	aligned2	;  len < 4- > EXIT TO singlepieces
		MOVAPD	XMM0, [RBX]	;
		MOVAPD	XMM1, [RBX+16]	;
		MOVAPD	XMM2, [RBX+32]	;
		MOVAPD	XMM3, [RBX+48]	;
		ADD	RBX, 64	;
		MOVAPD	XMM4, [RCX]	;
		MOVAPD	XMM5, [RCX+16]	;
		MOVAPD	XMM6, [RCX+32]	;
		MOVAPD	XMM7, [RCX+48]	;
		ADD	RCX, 64	;
		ADDPD	XMM0, XMM4	;
		ADDPD	XMM1, XMM5	;
		ADDPD	XMM2, XMM6	;
		ADDPD	XMM3, XMM7	;
		MOVAPD	[RDX], XMM0	;
		MOVAPD	[RDX+16], XMM1	;
		MOVAPD	[RDX+32], XMM2	;
		MOVAPD	[RDX+48], XMM3	;
		ADD	RDX, 64	;
		SUB	RAX, 8	;
		JMP	aligned8	;
		;  LOOP FOR 2 pieces aligned
		aligned2: ;
		CMP	RAX, 2	;
		JL	singlepieces	;  len < 2- > EXIT TO singlepieces
		MOVAPD	XMM0, [RBX]	;
		ADD	RBX, 16	;
		MOVAPD	XMM1, [RCX]	;
		ADD	RCX, 16	;
		ADDPD	XMM0, XMM1	;
		MOVAPD	[RDX], XMM0	;
		ADD	RDX, 16	;
		SUB	RAX, 2	;
		JMP	aligned2	;
		;  LOOP FOR 8 unaligned pieces(14 pieces not better!)
		unaligned: ;
		unaligned8: ;
		CMP	RAX, 8	;
		JL	unaligned2	;  len < 4- > EXIT TO singlepieces
		MOVUPD	XMM0, [RBX]	;
		MOVUPD	XMM1, [RBX+16]	;
		MOVUPD	XMM2, [RBX+32]	;
		MOVUPD	XMM3, [RBX+48]	;
		ADD	RBX, 64	;
		MOVUPD	XMM4, [RCX]	;
		MOVUPD	XMM5, [RCX+16]	;
		MOVUPD	XMM6, [RCX+32]	;
		MOVUPD	XMM7, [RCX+48]	;
		ADD	RCX, 64	;
		ADDPD	XMM0, XMM4	;
		ADDPD	XMM1, XMM5	;
		ADDPD	XMM2, XMM6	;
		ADDPD	XMM3, XMM7	;
		MOVUPD	[RDX], XMM0	;
		MOVUPD	[RDX+16], XMM1	;
		MOVUPD	[RDX+32], XMM2	;
		MOVUPD	[RDX+48], XMM3	;
		ADD	RDX, 64	;
		SUB	RAX, 8	;
		JMP	unaligned8	;
		;  LOOP FOR 2 pieces aligned
		unaligned2: ;
		CMP	RAX, 2	;
		JL	singlepieces	;  len < 2- > EXIT TO singlepieces
		MOVUPD	XMM0, [RBX]	;
		ADD	RBX, 16	;
		MOVUPD	XMM1, [RCX]	;
		ADD	RCX, 16	;
		ADDPD	XMM0, XMM1	;
		MOVUPD	[RDX], XMM0	;
		ADD	RDX, 16	;
		SUB	RAX, 2	;
		JMP	unaligned2	;
		;  one piece left OR non-contiguous data
		single:
		singlepieces: ;
		CMP	RAX, 0	;
		JLE	endL	;  len <= 0- > EXIT
		MOVSD	XMM0, [RBX]
		ADD	RBX, [RBP+linc]	;  INC(ladr, incl)
		MOVSD	XMM1, [RCX]
		ADD	RCX, [RBP+rinc]	;  INC(ladr, incl)
		ADDSD	XMM0, XMM1	;
		MOVSD	[RDX], XMM0
		ADD	RDX, [RBP+dinc]	;  INC(radr, incr)
		DEC	RAX	;  DEC(len)
		JMP	singlepieces	;
		endL:
	END AddAXAXLoopSSE;

	PROCEDURE AddARARLoopSSE( ladr, radr, dadr: ADDRESS; linc, rinc, dinc, len: SIZE );
	CODE {SYSTEM.AMD64, SYSTEM.SSE2}
		MOV	RAX, [RBP+len]	;
		CMP	RAX, 0	;
		JLE	endL	;  nothing TO be done, RAX > 0 guaranteed from here on
		MOV	RBX, [RBP+ladr]	;
		MOV	RCX, [RBP+radr]	;
		MOV	RDX, [RBP+dadr]	;
		;  check IF data are contiguous IN memory
		CMP	[RBP+linc], 4	;  check left FOR contiunuity
		JNE	single	;  not continuous- > simplest method
		CMP	[RBP+rinc], 4	;  check right FOR contiunuity
		JNE	single	;  not continuous- > simplest method
		CMP	[RBP+dinc], 4	;  check destination FOR contiunuity
		JNE	single	;  not continuous- > simplest method
		;  check FOR alignment
		MOV	RSI, RBX	;
		AND	RSI, 3	;  ladr MOD 4
		CMP	RSI, 0	;  = 0- > 32 Bit alignment
		JNE	unaligned	;  not 32 bit aligned
		MOV	RSI, RCX	;
		AND	RSI, 3	;  radr MOD 4
		CMP	RSI, 0	;  = 0- > 32 Bit alignment
		JNE	unaligned	;  not 32 bit aligned
		MOV	RSI, RDX	;
		AND	RSI, 3	;  dadr MOD 4
		CMP	RSI, 0	;  = 0- > 32 Bit alignment
		JNE	unaligned	;  not 32 bit aligned
		MOV	RSI, RBX	;
		AND	RSI, 8+4	;  16 byte alignment?
		MOV	RDI, RCX	;
		AND	RDI, 8+4	;  16 byte alignment?
		CMP	RSI, RDI	;
		JNE	unaligned	;  different 16 byte = 128 bit alignment OF ladr and radr
		MOV	RDI, RDX	;
		AND	RDI, 8+4	;  16 byte alignment
		CMP	RSI, RDI	;
		JNE	unaligned	;  different 16 byte = 128 bit alignment OF dadr and radr
		CMP	RSI, 0	;
		JE	aligned	;  already aligned
		align:
		;  one single element processing UNTIL 128 bt alignment achieved
		MOVSS	XMM1, [RBX]	;
		MOVSS	XMM0, [RCX]	;
		ADDSS	XMM0, XMM1	;
		MOVSS	[RDX], XMM0	;
		ADD	RBX, 4	;
		ADD	RCX, 4	;
		ADD	RDX, 4	;
		DEC	RAX	;  one element has been processed	;
		CMP	RAX, 0	;  all elements already processed?
		JLE	single	;
		MOV	RSI, RBX	;
		AND	RSI, 8+4	;
		CMP	RSI, 0	;
		JNE	align	;
		aligned:
		aligned16:
		CMP	RAX, 16	;
		JL	aligned4	;  len < 16- > EXIT TO singlepieces
		MOVAPS	XMM0, [RBX]	;
		MOVAPS	XMM1, [RBX+16]	;
		MOVAPS	XMM2, [RBX+32]	;
		MOVAPS	XMM3, [RBX+48]	;
		ADD	RBX, 64	;
		MOVAPS	XMM4, [RCX]	;
		MOVAPS	XMM5, [RCX+16]	;
		MOVAPS	XMM6, [RCX+32]	;
		MOVAPS	XMM7, [RCX+48]	;
		ADD	RCX, 64	;
		ADDPS	XMM0, XMM4	;
		ADDPS	XMM1, XMM5	;
		ADDPS	XMM2, XMM6	;
		ADDPS	XMM3, XMM7	;
		MOVAPS	[RDX], XMM0	;
		MOVAPS	[RDX+16], XMM1	;
		MOVAPS	[RDX+32], XMM2	;
		MOVAPS	[RDX+48], XMM3	;
		ADD	RDX, 64	;
		SUB	RAX, 16	;
		JMP	aligned16	;
		;  LOOP FOR 2 pieces aligned
		aligned4: ;
		CMP	RAX, 4	;
		JL	singlepieces	;  len < 2- > EXIT TO singlepieces
		MOVAPS	XMM0, [RBX]	;
		ADD	RBX, 16	;
		MOVAPS	XMM1, [RCX]	;
		ADD	RCX, 16	;
		ADDPS	XMM0, XMM1	;
		MOVAPS	[RDX], XMM0	;
		ADD	RDX, 16	;
		SUB	RAX, 4	;
		JMP	aligned4	;
		;  LOOP FOR 8 unaligned pieces(14 pieces not better!)
		unaligned: ;
		unaligned16: ;
		CMP	RAX, 16	;
		JL	unaligned4	;  len < 4- > EXIT TO singlepieces
		MOVUPS	XMM0, [RBX]	;
		MOVUPS	XMM1, [RBX+16]	;
		MOVUPS	XMM2, [RBX+32]	;
		MOVUPS	XMM3, [RBX+48]	;
		ADD	RBX, 64	;
		MOVUPS	XMM4, [RCX]	;
		MOVUPS	XMM5, [RCX+16]	;
		MOVUPS	XMM6, [RCX+32]	;
		MOVUPS	XMM7, [RCX+48]	;
		ADD	RCX, 64	;
		ADDPS	XMM0, XMM4	;
		ADDPS	XMM1, XMM5	;
		ADDPS	XMM2, XMM6	;
		ADDPS	XMM3, XMM7	;
		MOVUPS	[RDX], XMM0	;
		MOVUPS	[RDX+16], XMM1	;
		MOVUPS	[RDX+32], XMM2	;
		MOVUPS	[RDX+48], XMM3	;
		ADD	RDX, 64	;
		SUB	RAX, 16	;
		JMP	unaligned16	;
		;  LOOP FOR 2 pieces aligned
		unaligned4: ;
		CMP	RAX, 4	;
		JL	singlepieces	;  len < 2- > EXIT TO singlepieces
		MOVUPS	XMM0, [RBX]	;
		ADD	RBX, 16	;
		MOVUPS	XMM1, [RCX]	;
		ADD	RCX, 16	;
		ADDPS	XMM0, XMM1	;
		MOVUPS	[RDX], XMM0	;
		ADD	RDX, 16	;
		SUB	RAX, 4	;
		JMP	unaligned4	;
		;  one piece left OR non-contiguous data
		single:
		singlepieces: ;
		CMP	RAX, 0	;
		JLE	endL	;  len <= 0- > EXIT
		MOVSS	XMM0, [RBX]
		ADD	RBX, [RBP+linc]	;  INC(ladr, incl)
		MOVSS	XMM1, [RCX]
		ADD	RCX, [RBP+rinc]	;  INC(ladr, incl)
		ADDSS	XMM0, XMM1	;
		MOVSS	[RDX], XMM0
		ADD	RDX, [RBP+dinc]	;  INC(radr, incr)
		DEC	RAX	;  DEC(len)
		JMP	singlepieces	;
		endL:
	END AddARARLoopSSE;

	PROCEDURE SPAXAXLoopA( ladr, radr, dadr: ADDRESS; linc, rinc, len: SIZE );
	CODE {SYSTEM.AMD64, SYSTEM.FPU}
		MOV	RAX, [RBP+len]	;  eax := len
		MOV	RBX, [RBP+ladr]	;  ebx := ladr
		MOV	RCX, [RBP+radr]	;  ecx := radr
		MOV	RDX, [RBP+dadr]	;  edx := dadr
		FLD	QWORD [RDX]	;  S.GET(dadr, x)
		start:
		CMP	RAX, 0	;  WHILE len > 0 DO
		JLE	endL
		FLD	QWORD [RBX]	;  S.GET(ladr, x)
		ADD	RBX, [RBP+linc]	;  INC(ladr, incl)
		FLD	QWORD [RCX]	;  S.GET(ladr, y)
		FMULP	;  x := x*y
		ADD	RCX, [RBP+rinc]	;  INC(radr, incr)
		FADDP	;  z := z+x
		DEC	RAX	;  DEC(len)
		JMP	start	;
		endL:
		FSTP	QWORD [RDX]	;  S.PUT(dadr, x)
		FWAIT	;
	END SPAXAXLoopA;

	PROCEDURE SPARARLoopA( ladr, radr, dadr: ADDRESS; linc, rinc, len: SIZE );
	CODE {SYSTEM.AMD64, SYSTEM.FPU}
		MOV	RAX, [RBP+len]	;  eax := len
		MOV	RBX, [RBP+ladr]	;  ebx := ladr
		MOV	RCX, [RBP+radr]	;  ecx := radr
		MOV	RDX, [RBP+dadr]	;  edx := dadr
		FLD	DWORD [RDX]	;  S.GET(dadr, x)
		start:
		CMP	RAX, 0	;  WHILE len > 0 DO
		JLE	endL
		FLD	DWORD [RBX]	;  S.GET(ladr, x)
		ADD	RBX, [RBP+linc]	;  INC(ladr, incl)
		FLD	DWORD [RCX]	;  S.GET(ladr, y)
		FMULP	;  x := x*y
		ADD	RCX, [RBP+rinc]	;  INC(radr, incr)
		FADDP	;  z := z+x
		DEC	RAX	;  DEC(len)
		JMP	start	;
		endL:
		FSTP	DWORD [RDX]	;  S.PUT(dadr, x)
		FWAIT	;
	END SPARARLoopA;

(* sse version of scalar product *)
	PROCEDURE SPAXAXLoopSSE( ladr, radr, dadr: ADDRESS; linc, rinc, len: SIZE );
	CODE {SYSTEM.AMD64, SYSTEM.SSE2}
		;  register initialization
		MOV	RAX, [RBP+len]	;  RAX reserverd FOR length
		CMP	RAX, 0	;
		JLE	endL	;  nothing TO be done, RAX > 0 guaranteed from here on
		MOV	RBX, [RBP+ladr]	;  RBX reserved FOR ladr
		MOV	RCX, [RBP+radr]	;  RCX reserved FOR radr
		MOV	RDX, [RBP+dadr]	;  RDX reserved FOR dadr
		XORPD	XMM0, XMM0	;
		MOVSD	XMM0, [RDX]	;  destination- > low bytes OF xmm0
		CMP	[RBP+linc], 8	;  check left FOR contiunuity
		JNE	single	;  not continuous- > simplest method
		CMP	[RBP+rinc], 8	;  check dest FOR continuity
		JNE	single	;  not continuous- > simplest method
		;  check FOR alignment
		MOV	RSI, RBX	;
		AND	RSI, 7	;  ladr MOD 8
		CMP	RSI, 0	;  RCX = 0- > 64 Bit alignment
		JNE	unaligned	;  not 64 bit aligned
		MOV	RSI, RCX	;
		AND	RSI, 7	;  radr MOD 8
		CMP	RSI, 0	;  = 0- > 64 Bit alignment
		JNE	unaligned	;  not 64 bit aligned
		MOV	RSI, RBX	;
		AND	RSI, 8	;  16 byte alignment
		MOV	RDI, RCX	;
		AND	RDI, 8	;  16 byte alignment
		CMP	RSI, RDI	;
		JNE	unaligned	;  different 16 byte = 128 bit alignment OF ladr and dadr
		CMP	RSI, 8	;
		JNE	aligned	;  ladr and dadr already 128 bit aligned
		;  one single element processing TO achieve 128 bt alignment
		MOVSD	XMM1, [RBX]	;
		MOVSD	XMM2, [RCX]	;
		MULSD	XMM1, XMM2	;
		ADDSD	XMM0, XMM1	;
		ADD	RBX, 8	;  now RBX IS 16 byte aligned
		ADD	RCX, 8	;  now RDX IS 16 byte aligned	;
		DEC	RAX	;  one element has been processed
		;  LOOP FOR 4 pieces aligned
		aligned:
		aligned6:
		CMP	RAX, 6	;
		JL	aligned2	;  len < 4- > EXIT TO singlepieces
		MOVAPD	XMM1, [RBX]	;
		MOVAPD	XMM2, [RBX+16]	;
		MOVAPD	XMM3, [RBX+32]	;
		MOVAPD	XMM4, [RCX]	;
		MOVAPD	XMM5, [RCX+16]	;
		MOVAPD	XMM6, [RCX+32]	;
		MULPD	XMM1, XMM4	;
		ADDPD	XMM0, XMM1	;
		MULPD	XMM2, XMM5	;
		ADDPD	XMM0, XMM2	;
		MULPD	XMM3, XMM6	;
		ADDPD	XMM0, XMM3	;
		ADD	RBX, 48	;
		ADD	RCX, 48	;
		SUB	RAX, 6	;
		JMP	aligned6	;
		;  LOOP FOR 2 pieces aligned
		aligned2:
		CMP	RAX, 2	;
		JL	horizontaladd	;  ;  len < 4- > EXIT TO singlepieces
		MOVAPD	XMM1, [RBX]	;
		MOVAPD	XMM2, [RCX]	;
		MULPD	XMM1, XMM2	;
		ADDPD	XMM0, XMM1	;
		ADD	RBX, 16	;
		ADD	RCX, 16	;
		SUB	RAX, 2	;
		JMP	aligned2	;
		unaligned:
		unaligned6:
		CMP	RAX, 6	;
		JL	unaligned2	;  len < 4- > EXIT TO singlepieces
		MOVUPD	XMM1, [RBX]	;
		MOVUPD	XMM2, [RBX+16]	;
		MOVUPD	XMM3, [RBX+32]	;
		MOVUPD	XMM4, [RCX]	;
		MOVUPD	XMM5, [RCX+16]	;
		MOVUPD	XMM6, [RCX+32]	;
		MULPD	XMM1, XMM4	;
		ADDPD	XMM0, XMM1	;
		MULPD	XMM2, XMM5	;
		ADDPD	XMM0, XMM2	;
		MULPD	XMM3, XMM6	;
		ADDPD	XMM0, XMM3	;
		ADD	RBX, 48	;
		ADD	RCX, 48	;
		SUB	RAX, 6	;
		JMP	unaligned6	;
		;  LOOP FOR 2 pieces aligned
		unaligned2:
		CMP	RAX, 2	;
		JL	horizontaladd	;  ;  len < 4- > EXIT TO singlepieces
		MOVUPD	XMM1, [RBX]	;
		MOVUPD	XMM2, [RCX]	;
		MULPD	XMM1, XMM2	;
		ADDPD	XMM0, XMM1	;
		ADD	RBX, 16	;
		ADD	RCX, 16	;
		SUB	RAX, 2	;
		JMP	unaligned2	;
		horizontaladd: ;
		MOVAPD	XMM1, XMM0	;
		SHUFPD	XMM1, XMM1, 1	;  low bits < -high bits
		ADDPD	XMM0, XMM1	;
		JMP	singlepieces	;
		single:
		singlepieces: ;
		CMP	RAX, 0	;
		JLE	store	;  len <= 0- > EXIT
		MOVSD	XMM1, [RBX]
		MOVSD	XMM2, [RCX]
		MULSD	XMM1, XMM2
		ADDSD	XMM0, XMM1
		ADD	RBX, [RBP+linc]	;  INC(ladr, incl)
		ADD	RCX, [RBP+rinc]	;  INC(radr, incr)
		DEC	RAX	;  DEC(len)
		JMP	singlepieces	;
		store:
		MOVSD	[RDX], XMM0	;
		endL:
	END SPAXAXLoopSSE;

(* sse version of scalar product *)
	PROCEDURE SPARARLoopSSE( ladr, radr, dadr: ADDRESS; linc, rinc, len: SIZE );
	CODE {SYSTEM.AMD64, SYSTEM.SSE}
		;  register initialization
		MOV	RAX, [RBP+len]	;  RAX reserverd FOR length
		CMP	RAX, 0	;
		JLE	endL	;  nothing TO be done, RAX > 0 guaranteed from here on
		MOV	RBX, [RBP+ladr]	;  RBX reserved FOR ladr
		MOV	RCX, [RBP+radr]	;  RCX reserved FOR radr
		MOV	RDX, [RBP+dadr]	;  RDX reserved FOR dadr
		XORPS	XMM0, XMM0	;
		MOVSS	XMM0, [RDX]	;  destination- > low bytes OF xmm0
		CMP	[RBP+linc], 4	;  check left FOR contiunuity
		JNE	single	;  not continuous- > simplest method
		CMP	[RBP+rinc], 4	;  check dest FOR continuity
		JNE	single	;  not continuous- > simplest method
		;  check FOR alignment
		MOV	RSI, RBX	;
		AND	RSI, 3	;  ladr MOD 4
		CMP	RSI, 0	;  RCX = 0- > 32 Bit alignment
		JNE	unaligned	;  not 32 bit aligned
		MOV	RSI, RCX	;
		AND	RSI, 3	;  radr MOD 4
		CMP	RSI, 0	;  = 0- > 32 Bit alignment
		JNE	unaligned	;  not 32 bit aligned
		MOV	RSI, RBX	;
		AND	RSI, 8+4	;  16 byte alignment
		MOV	RDI, RCX	;
		AND	RDI, 8+4	;  16 byte alignment
		CMP	RSI, RDI	;
		JNE	unaligned	;  different 16 byte = 128 bit alignment OF ladr and dadr
		CMP	RSI, 0	;
		JE	aligned	;  already aligned
		align:
		;  one single element processing UNTIL 128 bt alignment achieved
		MOVSS	XMM1, [RBX]	;
		MOVSS	XMM2, [RCX]	;
		MULSS	XMM1, XMM2	;
		ADDSS	XMM0, XMM1	;
		ADD	RBX, 4	;
		ADD	RCX, 4	;
		DEC	RAX	;  one element has been processed	;
		CMP	RAX, 0	;  all elements already processed?
		JLE	single	;
		MOV	RSI, RBX	;
		AND	RSI, 8+4	;
		CMP	RSI, 0	;
		JNE	align	;
		aligned:
		aligned12:
		CMP	RAX, 12	;
		JL	aligned4	;  len < 4- > EXIT TO singlepieces
		MOVAPS	XMM1, [RBX]	;
		MOVAPS	XMM2, [RBX+16]	;
		MOVAPS	XMM3, [RBX+32]	;
		MOVAPS	XMM4, [RCX]	;
		MOVAPS	XMM5, [RCX+16]	;
		MOVAPS	XMM6, [RCX+32]	;
		MULPS	XMM1, XMM4	;
		ADDPS	XMM0, XMM1	;
		MULPS	XMM2, XMM5	;
		ADDPS	XMM0, XMM2	;
		MULPS	XMM3, XMM6	;
		ADDPS	XMM0, XMM3	;
		ADD	RBX, 48	;
		ADD	RCX, 48	;
		SUB	RAX, 12	;
		JMP	aligned12	;
		;  LOOP FOR 2 pieces aligned
		aligned4:
		CMP	RAX, 4	;
		JL	horizontaladd	;  ;  len < 4- > EXIT TO singlepieces
		MOVAPS	XMM1, [RBX]	;
		MOVAPS	XMM2, [RCX]	;
		MULPS	XMM1, XMM2	;
		ADDPS	XMM0, XMM1	;
		ADD	RBX, 16	;
		ADD	RCX, 16	;
		SUB	RAX, 4	;
		JMP	aligned4	;
		unaligned:
		unaligned12:
		CMP	RAX, 12	;
		JL	unaligned4	;  len < 4- > EXIT TO singlepieces
		MOVUPS	XMM1, [RBX]	;
		MOVUPS	XMM2, [RBX+16]	;
		MOVUPS	XMM3, [RBX+32]	;
		MOVUPS	XMM4, [RCX]	;
		MOVUPS	XMM5, [RCX+16]	;
		MOVUPS	XMM6, [RCX+32]	;
		MULPS	XMM1, XMM4	;
		ADDPS	XMM0, XMM1	;
		MULPS	XMM2, XMM5	;
		ADDPS	XMM0, XMM2	;
		MULPS	XMM3, XMM6	;
		ADDPS	XMM0, XMM3	;
		ADD	RBX, 48	;
		ADD	RCX, 48	;
		SUB	RAX, 12	;
		JMP	unaligned12	;
		;  LOOP FOR 2 pieces aligned
		unaligned4:
		CMP	RAX, 4	;
		JL	horizontaladd	;  ;  len < 4- > EXIT TO singlepieces
		MOVUPS	XMM1, [RBX]	;
		MOVUPS	XMM2, [RCX]	;
		MULPS	XMM1, XMM2	;
		ADDPS	XMM0, XMM1	;
		ADD	RBX, 16	;
		ADD	RCX, 16	;
		SUB	RAX, 4	;
		JMP	unaligned4	;
		horizontaladd: ;
		MOVAPS	XMM1, XMM0	;
		; 1*0 (* dest 0 -> dest 0 *) +4*1 (* dest 1 -> dest 1 *) +16*0 (* src 0 -> dest 2 *) +64*1 (* src 1 -> dest 3 *)
		SHUFPS	XMM1, XMM1, 1*0 +4*1 +16*0 +64*1
		ADDPS	XMM1, XMM0	;
		MOVAPS	XMM0, XMM1
		SHUFPS	XMM0, XMM0, 16*3	;  src 3- > dest 2
		ADDPS	XMM0, XMM1	;
		SHUFPS	XMM0, XMM0, 1*2	;  dest 2- > dest 0
		JMP	singlepieces	;
		single:
		singlepieces: ;
		CMP	RAX, 0	;
		JLE	store	;  len <= 0- > EXIT
		MOVSS	XMM1, [RBX]
		MOVSS	XMM2, [RCX]
		MULSS	XMM1, XMM2
		ADDSS	XMM0, XMM1
		ADD	RBX, [RBP+linc]	;  INC(ladr, incl)
		ADD	RCX, [RBP+rinc]	;  INC(radr, incr)
		DEC	RAX	;  DEC(len)
		JMP	singlepieces	;
		store:
		MOVSS	[RDX], XMM0	;
		endL:
	END SPARARLoopSSE;

	PROCEDURE MulAXSXLoopA( ladr, radr, dadr: ADDRESS; linc, dinc, len: SIZE );
	CODE {SYSTEM.AMD64, SYSTEM.FPU}
		MOV	RAX, [RBP+len]	;  eax := len
		MOV	RBX, [RBP+ladr]	;  ebx := ladr
		MOV	RCX, [RBP+radr]	;  ecx := radr
		MOV	RDX, [RBP+dadr]	;  edx := dadr
		start:
		CMP	RAX, 0	;  WHILE len > 0 DO
		JLE	endL
		FLD	QWORD [RBX]	;  S.GET(ladr, x)
		ADD	RBX, [RBP+linc]	;  INC(ladr, incl)
		FLD	QWORD [RCX]	;  S.GET(ladr, y)
		FMULP	;  x := x*y
		FSTP	QWORD [RDX]
		ADD	RDX, [RBP+dinc]	;  INC(radr, incr)
		DEC	RAX	;  DEC(len)
		JMP	start	;
		endL:
		FWAIT	;
	END MulAXSXLoopA;

	PROCEDURE MulARSRLoopA( ladr, radr, dadr: ADDRESS; linc, dinc, len: SIZE );
	CODE {SYSTEM.AMD64, SYSTEM.FPU}
		MOV	RAX, [RBP+len]	;  eax := len
		MOV	RBX, [RBP+ladr]	;  ebx := ladr
		MOV	RCX, [RBP+radr]	;  ecx := radr
		MOV	RDX, [RBP+dadr]	;  edx := dadr
		start:
		CMP	RAX, 0	;  WHILE len > 0 DO
		JLE	endL
		FLD	DWORD [RBX]	;  S.GET(ladr, x)
		ADD	RBX, [RBP+linc]	;  INC(ladr, incl)
		FLD	DWORD [RCX]	;  S.GET(ladr, y)
		FMULP	;  x := x*y
		FSTP	DWORD [RDX]
		ADD	RDX, [RBP+dinc]	;  INC(radr, incr)
		DEC	RAX	;  DEC(len)
		JMP	start	;
		endL:
		FWAIT	;
	END MulARSRLoopA;

	PROCEDURE IncMulAXSXLoopA( ladr, radr, dadr: ADDRESS; linc, dinc, len: SIZE );
	CODE {SYSTEM.AMD64, SYSTEM.FPU}
		MOV	RAX, [RBP+len]	;  eax := len
		MOV	RBX, [RBP+ladr]	;  ebx := ladr
		MOV	RCX, [RBP+radr]	;  ecx := radr
		MOV	RDX, [RBP+dadr]	;  edx := dadr
		start:
		CMP	RAX, 0	;  WHILE len > 0 DO
		JLE	endL
		FLD	QWORD [RBX]	;  S.GET(ladr, x)
		ADD	RBX, [RBP+linc]	;  INC(ladr, incl)
		FLD	QWORD [RCX]	;  S.GET(ladr, y)
		FMULP	;  x := x*y
		FLD	QWORD [RDX+8]	;
		FADDP	;
		FSTP	QWORD [RDX]
		ADD	RDX, [RBP+dinc]	;  INC(radr, incr)
		DEC	RAX	;  DEC(len)
		JMP	start	;
		endL:
		FWAIT	;
	END IncMulAXSXLoopA;

	PROCEDURE IncMulARSRLoopA( ladr, radr, dadr: ADDRESS; linc, dinc, len: SIZE );
	CODE {SYSTEM.AMD64, SYSTEM.FPU}
		MOV	RAX, [RBP+len]	;  eax := len
		MOV	RBX, [RBP+ladr]	;  ebx := ladr
		MOV	RCX, [RBP+radr]	;  ecx := radr
		MOV	RDX, [RBP+dadr]	;  edx := dadr
		start:
		CMP	RAX, 0	;  WHILE len > 0 DO
		JLE	endL
		FLD	DWORD [RBX]	;  S.GET(ladr, x)
		ADD	RBX, [RBP+linc]	;  INC(ladr, incl)
		FLD	DWORD [RCX]	;  S.GET(ladr, y)
		FMULP	;  x := x*y
		FLD	DWORD [RDX+8]	;
		FADDP	;
		FSTP	DWORD [RDX]
		ADD	RDX, [RBP+dinc]	;  INC(radr, incr)
		DEC	RAX	;  DEC(len)
		JMP	start	;
		endL:
		FWAIT	;
	END IncMulARSRLoopA;

	PROCEDURE MulAXSXLoopSSE( ladr, radr, dadr: ADDRESS; linc, dinc, len: SIZE );
	(* simple version, does not yet check for alignment, no parallel executions yet: use full 8 registers! *)
	(*
		1.) check for same alignment of ladr and dadr (ladr MOD 128 = dadr MOD 128)
		2.) process starting unaligned data ( using single instructions)
		3.) process aligned data
		4.) process remaining unaligned data (using single instructions)
	*)
	CODE {SYSTEM.AMD64, SYSTEM.SSE2}
		;  register initialization
		MOV	RAX, [RBP+len]	;  RAX reserverd FOR length
		CMP	RAX, 0	;
		JLE	endL	;  nothing TO be done, RAX > 0 guaranteed from here on
		MOV	RBX, [RBP+ladr]	;  RBX reserved FOR ladr
		MOV	RDX, [RBP+dadr]	;  RDX reserved FOR dadr
		MOV	RCX, [RBP+radr]	;
		MOVSD	XMM0, [RCX]	;
		SHUFPD	XMM0, XMM0, 0	;  high bits := low bits
		;  check IF data are contiguous IN memory
		CMP	[RBP+linc], 8	;  check left FOR contiunuity
		JNE	single	;  not continuous- > simplest method
		CMP	[RBP+dinc], 8	;  check dest FOR continuity
		JNE	single	;  not continuous- > simplest method
		;  check FOR alignment
		MOV	RCX, RBX	;
		AND	RCX, 7	;  ladr MOD 8
		CMP	RCX, 0	;  RCX = 0- > 64 Bit alignment
		JNE	unaligned	;  not 64 bit aligned
		MOV	RCX, RDX	;
		AND	RCX, 7	;  dadr MOD 8
		CMP	RCX, 0	;  RCX = 0- > 64 Bit alignment
		JNE	unaligned	;  not 64 bit aligned
		MOV	RSI, RBX	;
		AND	RSI, 8	;  16 byte alignment
		MOV	RDI, RDX	;
		AND	RDI, 8	;  16 byte alignment
		CMP	RSI, RDI	;
		JNE	unaligned	;  different 16 byte = 128 bit alignment OF ladr and dadr
		CMP	RSI, 8	;
		JNE	aligned	;  ladr and dadr already 128 bit aligned
		;  one single element processing TO achieve 128 bt alignment
		MOVSD	XMM1, [RBX]	;
		MULSD	XMM1, XMM0	;
		MOVSD	[RDX], XMM1	;
		ADD	RBX, 8	;  now RBX IS 16 byte aligned
		ADD	RDX, 8	;  now RDX IS 16 byte aligned	;
		DEC	RAX	;  one element has been processed
		;  LOOP FOR 8 pieces aligned(no better performance with 14 pieces!)
		aligned:
		aligned8:
		CMP	RAX, 8	;
		JL	aligned2	;  len < 4- > EXIT TO singlepieces
		MOVAPD	XMM1, [RBX]	;
		MOVAPD	XMM2, [RBX+16]	;
		MOVAPD	XMM3, [RBX+32]	;
		MOVAPD	XMM4, [RBX+48]	;
		ADD	RBX, 64	;
		MULPD	XMM1, XMM0	;
		MULPD	XMM2, XMM0	;
		MULPD	XMM3, XMM0	;
		MULPD	XMM4, XMM0	;
		MOVAPD	[RDX], XMM1	;
		MOVAPD	[RDX+16], XMM2	;
		MOVAPD	[RDX+32], XMM3	;
		MOVAPD	[RDX+48], XMM4	;
		ADD	RDX, 64	;
		SUB	RAX, 8	;
		JMP	aligned8	;
		;  LOOP FOR 2 pieces aligned
		aligned2: ;
		CMP	RAX, 2	;
		JL	singlepieces	;  len < 2- > EXIT TO singlepieces
		MOVAPD	XMM1, [RBX]	;
		ADD	RBX, 16	;
		MULPD	XMM1, XMM0	;
		MOVAPD	[RDX], XMM1	;
		ADD	RDX, 16	;
		SUB	RAX, 2	;
		JMP	aligned2	;
		;  LOOP FOR 8 unaligned pieces(14 pieces not better!)
		unaligned: ;
		unaligned8: ;
		CMP	RAX, 8	;
		JL	unaligned2	;  len < 12- > EXIT
		MOVUPD	XMM1, [RBX]	;
		MOVUPD	XMM2, [RBX+16]	;
		MOVUPD	XMM3, [RBX+32]	;
		MOVUPD	XMM4, [RBX+48]	;
		ADD	RBX, 64
		MULPD	XMM1, XMM0	;
		MULPD	XMM2, XMM0	;
		MULPD	XMM3, XMM0	;
		MULPD	XMM4, XMM0	;
		MOVUPD	[RDX], XMM1	;
		MOVUPD	[RDX+16], XMM2	;
		MOVUPD	[RDX+32], XMM3	;
		MOVUPD	[RDX+48], XMM4	;
		ADD	RDX, 64	;
		SUB	RAX, 8	;
		JMP	unaligned8	;
		;  LOOP FOR 2 pieces unaligned
		unaligned2: ;
		CMP	RAX, 2	;
		JL	singlepieces	;  len < 2- > EXIT
		MOVUPD	XMM1, [RBX]	;
		ADD	RBX, 16	;
		MULPD	XMM1, XMM0	;
		MOVUPD	[RDX], XMM1	;
		ADD	RDX, 16	;
		SUB	RAX, 2	;
		JMP	unaligned2	;
		;  one piece left OR non-contiguous data
		single:
		singlepieces: ;
		CMP	RAX, 0	;
		JLE	endL	;  len <= 0- > EXIT
		MOVSD	XMM1, [RBX]
		ADD	RBX, [RBP+linc]	;  INC(ladr, incl)
		MULSD	XMM1, XMM0
		MOVSD	[RDX], XMM1
		ADD	RDX, [RBP+dinc]	;  INC(radr, incr)
		DEC	RAX	;  DEC(len)
		JMP	singlepieces	;
		endL:
	END MulAXSXLoopSSE;

	PROCEDURE MulARSRLoopSSE( ladr, radr, dadr: ADDRESS; linc, dinc, len: SIZE );
	(* simple version, does not yet check for alignment, no parallel executions yet: use full 8 registers! *)
	(*
		1.) check for same alignment of ladr and dadr (ladr MOD 128 = dadr MOD 128)
		2.) process starting unaligned data ( using single instructions)
		3.) process aligned data
		4.) process remaining unaligned data (using single instructions)
	*)
	CODE {SYSTEM.AMD64, SYSTEM.SSE}
		;  register initialization
		MOV	RAX, [RBP+len]	;  RAX reserverd FOR length
		CMP	RAX, 0	;
		JLE	endL	;  nothing TO be done, RAX > 0 guaranteed from here on
		MOV	RBX, [RBP+ladr]	;  RBX reserved FOR ladr
		MOV	RDX, [RBP+dadr]	;  RDX reserved FOR dadr
		MOV	RCX, [RBP+radr]	;
		MOVSS	XMM0, [RCX]	;
		SHUFPS	XMM0, XMM0, 0	;  all positions now carrie same value
		;  check IF data are contiguous IN memory
		CMP	[RBP+linc], 4	;  check left FOR contiunuity
		JNE	single	;  not continuous- > simplest method
		CMP	[RBP+dinc], 4	;  check dest FOR continuity
		JNE	single	;  not continuous- > simplest method
		;  check FOR alignment
		MOV	RCX, RBX	;
		AND	RCX, 3	;  ladr MOD 4
		CMP	RCX, 0	;  RCX = 0- > 32 Bit alignment
		JNE	unaligned	;  not 32 bit aligned
		MOV	RCX, RDX	;
		AND	RCX, 3	;  dadr MOD 4
		CMP	RCX, 0	;  RCX = 0- > 32 Bit alignment
		JNE	unaligned	;  not 64 bit aligned
		MOV	RSI, RBX	;
		AND	RSI, 8+4	;  16 byte alignment
		MOV	RDI, RDX	;
		AND	RDI, 8+4	;  16 byte alignment
		CMP	RSI, RDI	;
		JNE	unaligned	;  different 16 byte = 128 bit alignment OF ladr and dadr
		CMP	RSI, 0	;
		JE	aligned	;  already aligned
		align:
		;  one single element processing UNTIL 128 bt alignment achieved
		MOVSS	XMM1, [RBX]	;
		MULSS	XMM1, XMM0	;
		MOVSS	[RDX], XMM1	;
		ADD	RBX, 4	;
		ADD	RDX, 4	;
		DEC	RAX	;  one element has been processed	;
		CMP	RAX, 0	;  all elements already processed?
		JLE	single
		MOV	RSI, RBX	;
		AND	RSI, 8+4	;
		CMP	RSI, 0	;
		JNE	align	;
		aligned:
		aligned16:
		CMP	RAX, 16	;
		JL	aligned4	;  len < 4- > EXIT TO singlepieces
		MOVAPS	XMM1, [RBX]	;
		MOVAPS	XMM2, [RBX+16]	;
		MOVAPS	XMM3, [RBX+32]	;
		MOVAPS	XMM4, [RBX+48]	;
		ADD	RBX, 64	;
		MULPS	XMM1, XMM0	;
		MULPS	XMM2, XMM0	;
		MULPS	XMM3, XMM0	;
		MULPS	XMM4, XMM0	;
		MOVAPS	[RDX], XMM1	;
		MOVAPS	[RDX+16], XMM2	;
		MOVAPS	[RDX+32], XMM3	;
		MOVAPS	[RDX+48], XMM4	;
		ADD	RDX, 64	;
		SUB	RAX, 16	;
		JMP	aligned16	;
		;  LOOP FOR 2 pieces aligned
		aligned4: ;
		CMP	RAX, 4	;
		JL	singlepieces	;  len < 2- > EXIT TO singlepieces
		MOVAPS	XMM1, [RBX]	;
		ADD	RBX, 16	;
		MULPS	XMM1, XMM0	;
		MOVAPS	[RDX], XMM1	;
		ADD	RDX, 16	;
		SUB	RAX, 4	;
		JMP	aligned4	;
		;  LOOP FOR 16 unaligned pieces(20 pieces not better!)
		unaligned: ;
		unaligned16: ;
		CMP	RAX, 16	;
		JL	unaligned4	;  len < 12- > EXIT
		MOVUPS	XMM1, [RBX]	;
		MOVUPS	XMM2, [RBX+16]	;
		MOVUPS	XMM3, [RBX+32]	;
		MOVUPS	XMM4, [RBX+48]	;
		ADD	RBX, 64
		MULPS	XMM1, XMM0	;
		MULPS	XMM2, XMM0	;
		MULPS	XMM3, XMM0	;
		MULPS	XMM4, XMM0	;
		MOVUPS	[RDX], XMM1	;
		MOVUPS	[RDX+16], XMM2	;
		MOVUPS	[RDX+32], XMM3	;
		MOVUPS	[RDX+48], XMM4	;
		ADD	RDX, 64	;
		SUB	RAX, 16	;
		JMP	unaligned16	;
		;  LOOP FOR 2 pieces unaligned
		unaligned4: ;
		CMP	RAX, 4	;
		JL	singlepieces	;  len < 2- > EXIT
		MOVUPS	XMM1, [RBX]	;
		ADD	RBX, 16	;
		MULPS	XMM1, XMM0	;
		MOVUPS	[RDX], XMM1	;
		ADD	RDX, 16	;
		SUB	RAX, 4	;
		JMP	unaligned4	;
		;  one piece left OR non-contiguous data
		single:
		singlepieces: ;
		CMP	RAX, 0	;
		JLE	endL	;  len <= 0- > EXIT
		MOVSS	XMM1, [RBX]
		ADD	RBX, [RBP+linc]	;  INC(ladr, incl)
		MULSS	XMM1, XMM0
		MOVSS	[RDX], XMM1
		ADD	RDX, [RBP+dinc]	;  INC(radr, incr)
		DEC	RAX	;  DEC(len)
		JMP	singlepieces	;
		endL:
	END MulARSRLoopSSE;

	PROCEDURE IncMulAXSXLoopSSE( ladr, radr, dadr: ADDRESS; linc, dinc, len: SIZE );
	(* simple version, does not yet check for alignment, no parallel executions yet: use full 8 registers! *)
	(*
		1.) check for same alignment of ladr and dadr (ladr MOD 128 = dadr MOD 128)
		2.) process starting unaligned data ( using single instructions)
		3.) process aligned data
		4.) process remaining unaligned data (using single instructions)
	*)
	CODE {SYSTEM.AMD64, SYSTEM.SSE2}
		;  register initialization
		MOV	RAX, [RBP+len]	;  RAX reserverd FOR length
		CMP	RAX, 0	;
		JLE	endL	;  nothing TO be done, RAX > 0 guaranteed from here on
		MOV	RBX, [RBP+ladr]	;  RBX reserved FOR ladr
		MOV	RDX, [RBP+dadr]	;  RDX reserved FOR dadr
		MOV	RCX, [RBP+radr]	;
		MOVSD	XMM0, [RCX]	;
		SHUFPD	XMM0, XMM0, 0	;  high bits := low bits
		;  check IF data are contiguous IN memory
		CMP	[RBP+linc], 8	;  check left FOR contiunuity
		JNE	single	;  not continuous- > simplest method
		CMP	[RBP+dinc], 8	;  check dest FOR continuity
		JNE	single	;  not continuous- > simplest method
		;  check FOR alignment
		MOV	RCX, RBX	;
		AND	RCX, 7	;  ladr MOD 8
		CMP	RCX, 0	;  RCX = 0- > 64 Bit alignment
		JNE	unaligned	;  not 64 bit aligned
		MOV	RCX, RDX	;
		AND	RCX, 7	;  dadr MOD 8
		CMP	RCX, 0	;  RCX = 0- > 64 Bit alignment
		JNE	unaligned	;  not 64 bit aligned
		MOV	RSI, RBX	;
		AND	RSI, 8	;  16 byte alignment
		MOV	RDI, RDX	;
		AND	RDI, 8	;  16 byte alignment
		CMP	RSI, RDI	;
		JNE	unaligned	;  different 16 byte = 128 bit alignment OF ladr and dadr
		CMP	RSI, 8	;
		JNE	aligned	;  ladr and dadr already 128 bit aligned
		;  one single element processing TO achieve 128 bt alignment
		MOVSD	XMM1, [RBX]	;
		MULSD	XMM1, XMM0	;
		MOVSD	XMM2, [RDX]	;
		ADDSD	XMM1, XMM2	;
		MOVSD	[RDX], XMM1	;
		ADD	RBX, 8	;  now RBX IS 16 byte aligned
		ADD	RDX, 8	;  now RDX IS 16 byte aligned	;
		DEC	RAX	;  one element has been processed
		;  LOOP FOR 8 pieces aligned(no better performance with 14 pieces!)
		aligned:
		aligned8:
		CMP	RAX, 8	;
		JL	aligned2	;  len < 4- > EXIT TO singlepieces
		MOVAPD	XMM1, [RBX]	;
		MOVAPD	XMM2, [RBX+16]	;
		MOVAPD	XMM3, [RBX+32]	;
		MOVAPD	XMM4, [RBX+48]	;
		ADD	RBX, 64	;
		MULPD	XMM1, XMM0	;
		MULPD	XMM2, XMM0	;
		MULPD	XMM3, XMM0	;
		MULPD	XMM4, XMM0	;
		MOVAPD	XMM5, [RDX]	;
		ADDPD	XMM1, XMM5
		MOVAPD	[RDX], XMM1	;
		MOVAPD	XMM6, [RDX+16]	;
		ADDPD	XMM2, XMM6
		MOVAPD	[RDX+16], XMM2	;
		MOVAPD	XMM7, [RDX+32]	;
		ADDPD	XMM3, XMM7
		MOVAPD	[RDX+32], XMM3	;
		MOVAPD	XMM5, [RDX+48]	;
		ADDPD	XMM4, XMM5
		MOVAPD	[RDX+48], XMM4	;
		ADD	RDX, 64	;
		SUB	RAX, 8	;
		JMP	aligned8	;
		;  LOOP FOR 2 pieces aligned
		aligned2: ;
		CMP	RAX, 2	;
		JL	singlepieces	;  len < 2- > EXIT TO singlepieces
		MOVAPD	XMM1, [RBX]	;
		ADD	RBX, 16	;
		MULPD	XMM1, XMM0	;
		MOVAPD	XMM2, [RDX]	;
		ADDPD	XMM1, XMM2
		MOVAPD	[RDX], XMM1	;
		ADD	RDX, 16	;
		SUB	RAX, 2	;
		JMP	aligned2	;
		;  LOOP FOR 8 unaligned pieces(14 pieces not better!)
		unaligned: ;
		unaligned8: ;
		CMP	RAX, 8	;
		JL	unaligned2	;  len < 12- > EXIT
		MOVUPD	XMM1, [RBX]	;
		MOVUPD	XMM2, [RBX+16]	;
		MOVUPD	XMM3, [RBX+32]	;
		MOVUPD	XMM4, [RBX+48]	;
		ADD	RBX, 64
		MULPD	XMM1, XMM0	;
		MULPD	XMM2, XMM0	;
		MULPD	XMM3, XMM0	;
		MULPD	XMM4, XMM0	;
		MOVUPD	XMM5, [RDX]	;
		ADDPD	XMM1, XMM5
		MOVUPD	[RDX], XMM1	;
		MOVUPD	XMM6, [RDX+16]	;
		ADDPD	XMM2, XMM6
		MOVUPD	[RDX+16], XMM2	;
		MOVUPD	XMM7, [RDX+32]	;
		ADDPD	XMM3, XMM7
		MOVUPD	[RDX+32], XMM3	;
		MOVUPD	XMM5, [RDX+48]	;
		ADDPD	XMM4, XMM5
		MOVUPD	[RDX+48], XMM4	;
		ADD	RDX, 64	;
		SUB	RAX, 8	;
		JMP	unaligned8	;
		;  LOOP FOR 2 pieces unaligned
		unaligned2: ;
		CMP	RAX, 2	;
		JL	singlepieces	;  len < 2- > EXIT
		MOVUPD	XMM1, [RBX]	;
		ADD	RBX, 16	;
		MULPD	XMM1, XMM0	;
		MOVUPD	XMM2, [RDX]	;
		ADDPD	XMM1, XMM2
		MOVUPD	[RDX], XMM1	;
		ADD	RDX, 16	;
		SUB	RAX, 2	;
		JMP	unaligned2	;
		;  one piece left OR non-contiguous data
		single:
		singlepieces: ;
		CMP	RAX, 0	;
		JLE	endL	;  len <= 0- > EXIT
		MOVSD	XMM1, [RBX]
		ADD	RBX, [RBP+linc]	;  INC(ladr, incl)
		MULSD	XMM1, XMM0
		MOVSD	XMM2, [RDX]	;
		ADDSD	XMM1, XMM2
		MOVSD	[RDX], XMM1
		ADD	RDX, [RBP+dinc]	;  INC(radr, incr)
		DEC	RAX	;  DEC(len)
		JMP	singlepieces	;
		endL:
	END IncMulAXSXLoopSSE;

	PROCEDURE IncMulARSRLoopSSE( ladr, radr, dadr: ADDRESS; linc, dinc, len: SIZE );
	(* simple version, does not yet check for alignment, no parallel executions yet: use full 8 registers! *)
	(*
		1.) check for same alignment of ladr and dadr (ladr MOD 128 = dadr MOD 128)
		2.) process starting unaligned data ( using single instructions)
		3.) process aligned data
		4.) process remaining unaligned data (using single instructions)
	*)
	CODE {SYSTEM.AMD64, SYSTEM.SSE}
		;  register initialization
		MOV	RAX, [RBP+len]	;  RAX reserverd FOR length
		CMP	RAX, 0	;
		JLE	endL	;  nothing TO be done, RAX > 0 guaranteed from here on
		MOV	RBX, [RBP+ladr]	;  RBX reserved FOR ladr
		MOV	RDX, [RBP+dadr]	;  RDX reserved FOR dadr
		MOV	RCX, [RBP+radr]	;
		MOVSS	XMM0, [RCX]	;
		SHUFPS	XMM0, XMM0, 0	;  all positions now carrie same value
		;  check IF data are contiguous IN memory
		CMP	[RBP+linc], 4	;  check left FOR contiunuity
		JNE	single	;  not continuous- > simplest method
		CMP	[RBP+dinc], 4	;  check dest FOR continuity
		JNE	single	;  not continuous- > simplest method
		;  check FOR alignment
		MOV	RCX, RBX	;
		AND	RCX, 3	;  ladr MOD 4
		CMP	RCX, 0	;  RCX = 0- > 32 Bit alignment
		JNE	unaligned	;  not 32 bit aligned
		MOV	RCX, RDX	;
		AND	RCX, 3	;  dadr MOD 4
		CMP	RCX, 0	;  RCX = 0- > 32 Bit alignment
		JNE	unaligned	;  not 64 bit aligned
		MOV	RSI, RBX	;
		AND	RSI, 8+4	;  16 byte alignment
		MOV	RDI, RDX	;
		AND	RDI, 8+4	;  16 byte alignment
		CMP	RSI, RDI	;
		JNE	unaligned	;  different 16 byte = 128 bit alignment OF ladr and dadr
		CMP	RSI, 0	;
		JE	aligned	;  already aligned
		align:
		;  one single element processing UNTIL 128 bt alignment achieved
		MOVSS	XMM1, [RBX]	;
		MULSS	XMM1, XMM0	;
		MOVSS	XMM2, [RDX]	;
		ADDSS	XMM1, XMM2	;
		MOVSS	[RDX], XMM1	;
		ADD	RBX, 4	;
		ADD	RDX, 4	;
		DEC	RAX	;  one element has been processed	;
		CMP	RAX, 0	;  all elements already processed?
		JLE	single
		MOV	RSI, RBX	;
		AND	RSI, 8+4	;
		CMP	RSI, 0	;
		JNE	align	;
		aligned:
		aligned16:
		CMP	RAX, 16	;
		JL	aligned4	;  len < 4- > EXIT TO singlepieces
		MOVAPS	XMM1, [RBX]	;
		MOVAPS	XMM2, [RBX+16]	;
		MOVAPS	XMM3, [RBX+32]	;
		MOVAPS	XMM4, [RBX+48]	;
		ADD	RBX, 64	;
		MULPS	XMM1, XMM0	;
		MULPS	XMM2, XMM0	;
		MULPS	XMM3, XMM0	;
		MULPS	XMM4, XMM0	;
		MOVAPS	XMM5, [RDX]	;
		ADDPS	XMM1, XMM5	;
		MOVAPS	[RDX], XMM1	;
		MOVAPS	XMM6, [RDX+16]	;
		ADDPS	XMM2, XMM6	;
		MOVAPS	[RDX+16], XMM2	;
		MOVAPS	XMM7, [RDX+32]	;
		ADDPS	XMM3, XMM7	;
		MOVAPS	[RDX+32], XMM3	;
		MOVAPS	XMM5, [RDX+48]	;
		ADDPS	XMM4, XMM5	;
		MOVAPS	[RDX+48], XMM4	;
		ADD	RDX, 64	;
		SUB	RAX, 16	;
		JMP	aligned16	;
		;  LOOP FOR 2 pieces aligned
		aligned4: ;
		CMP	RAX, 4	;
		JL	singlepieces	;  len < 2- > EXIT TO singlepieces
		MOVAPS	XMM1, [RBX]	;
		ADD	RBX, 16	;
		MULPS	XMM1, XMM0	;
		MOVAPS	XMM2, [RDX]	;
		ADDPS	XMM1, XMM2	;
		MOVAPS	[RDX], XMM1	;
		ADD	RDX, 16	;
		SUB	RAX, 4	;
		JMP	aligned4	;
		;  LOOP FOR 16 unaligned pieces(20 pieces not better!)
		unaligned: ;
		unaligned16: ;
		CMP	RAX, 16	;
		JL	unaligned4	;  len < 12- > EXIT
		MOVUPS	XMM1, [RBX]	;
		MOVUPS	XMM2, [RBX+16]	;
		MOVUPS	XMM3, [RBX+32]	;
		MOVUPS	XMM4, [RBX+48]	;
		ADD	RBX, 64
		MULPS	XMM1, XMM0	;
		MULPS	XMM2, XMM0	;
		MULPS	XMM3, XMM0	;
		MULPS	XMM4, XMM0	;
		MOVUPS	XMM5, [RDX]	;
		ADDPS	XMM1, XMM5	;
		MOVUPS	[RDX], XMM1	;
		MOVUPS	XMM6, [RDX+16]	;
		ADDPS	XMM2, XMM6	;
		MOVUPS	[RDX+16], XMM2	;
		MOVUPS	XMM7, [RDX+32]	;
		ADDPS	XMM3, XMM7	;
		MOVUPS	[RDX+32], XMM3	;
		MOVUPS	XMM5, [RDX+48]	;
		ADDPS	XMM4, XMM5	;
		MOVUPS	[RDX+48], XMM4	;
		ADD	RDX, 64	;
		SUB	RAX, 16	;
		JMP	unaligned16	;
		;  LOOP FOR 2 pieces unaligned
		unaligned4: ;
		CMP	RAX, 4	;
		JL	singlepieces	;  len < 2- > EXIT
		MOVUPS	XMM1, [RBX]	;
		ADD	RBX, 16	;
		MULPS	XMM1, XMM0	;
		MOVUPS	XMM2, [RDX]	;
		ADDPS	XMM1, XMM2	;
		MOVUPS	[RDX], XMM1	;
		ADD	RDX, 16	;
		SUB	RAX, 4	;
		JMP	unaligned4	;
		;  one piece left OR non-contiguous data
		single:
		singlepieces: ;
		CMP	RAX, 0	;
		JLE	endL	;  len <= 0- > EXIT
		MOVSS	XMM1, [RBX]
		ADD	RBX, [RBP+linc]	;  INC(ladr, incl)
		MULSS	XMM1, XMM0
		MOVSS	XMM2, [RDX]	;
		ADDSS	XMM1, XMM2	;
		MOVSS	[RDX], XMM1
		ADD	RDX, [RBP+dinc]	;  INC(radr, incr)
		DEC	RAX	;  DEC(len)
		JMP	singlepieces	;
		endL:
	END IncMulARSRLoopSSE;

	(*
	PROCEDURE AlignedSPXSSE5( ladr, radr, dadr, stride, incd, len: LONGINT );
	CODE {SYSTEM.AMD64, SYSTEM.SSE2}
		;  ;  register initialization
		MOV	RDX, [RBP+dadr]	;  RDX reserved for dadr
		MOV	RBX, [RBP+ladr]	;  RBX reserved for ladr
		MOV	RSI, [RBP+radr]	;  RSI reserved for radr
		MOV	RAX, [RBP+len]	;  RAX reserverd for length
		MOV	RCX, [RBP+stride]	;  RCX reserved for stride
		XORPD	XMM2, XMM2	;
		XORPD	XMM3, XMM3	;
		XORPD	XMM4, XMM4	;
		XORPD	XMM5, XMM5	;
		XORPD	XMM6, XMM6	;
		XOR	RDI, RDI	;
		aligned4:
		CMP	RAX, 4	;
		JL	aligned2	;  ;  len < 4- > exit to singlepieces
		MOV	RSI, [RBP+radr]	;
		ADD	RSI, RDI	;
		MOVAPD	XMM7, [RBX]	;
		MOVAPD	XMM0, [RSI]	;
		ADD	RSI, RCX	;
		MOVAPD	XMM1, [RSI]	;
		MULPD	XMM0, XMM7	;
		ADDPD	XMM2, XMM0	;
		ADD	RSI, RCX	;
		MOVAPD	XMM0, [RSI]	;
		MULPD	XMM1, XMM7	;
		ADDPD	XMM3, XMM1	;
		ADD	RSI, RCX	;
		MOVAPD	XMM1, [RSI]	;
		MULPD	XMM0, XMM7	;
		ADDPD	XMM4, XMM0	;
		ADD	RSI, RCX	;
		MOVAPD	XMM0, [RSI]	;
		MULPD	XMM1, XMM7	;
		ADDPD	XMM5, XMM1	;
		MULPD	XMM0, XMM7	;
		ADDPD	XMM6, XMM0	;
		ADD	RBX, 16	;
		ADD	RDI, 16	;
		MOV	RSI, [RBP+radr]	;
		ADD	RSI, RDI	;
		MOVAPD	XMM7, [RBX]	;
		MOVAPD	XMM0, [RSI]	;
		ADD	RSI, RCX	;
		MOVAPD	XMM1, [RSI]	;
		MULPD	XMM0, XMM7	;
		ADDPD	XMM2, XMM0	;
		ADD	RSI, RCX	;
		MOVAPD	XMM0, [RSI]	;
		MULPD	XMM1, XMM7	;
		ADDPD	XMM3, XMM1	;
		ADD	RSI, RCX	;
		MOVAPD	XMM1, [RSI]	;
		MULPD	XMM0, XMM7	;
		ADDPD	XMM4, XMM0	;
		ADD	RSI, RCX	;
		MOVAPD	XMM0, [RSI]	;
		MULPD	XMM1, XMM7	;
		ADDPD	XMM5, XMM1	;
		MULPD	XMM0, XMM7	;
		ADDPD	XMM6, XMM0	;
		ADD	RBX, 16	;
		ADD	RDI, 16	;
		SUB	RAX, 4	;
		JMP	aligned4	;
		aligned2:
		CMP	RAX, 2	;
		JL	horizontaladd	;  ;  len < 4- > exit to singlepieces
		MOV	RSI, [RBP+radr]	;
		ADD	RSI, RDI	;
		MOVAPD	XMM7, [RBX]	;
		MOVAPD	XMM0, [RSI]	;
		ADD	RSI, RCX	;
		MOVAPD	XMM1, [RSI]	;
		MULPD	XMM0, XMM7	;
		ADDPD	XMM2, XMM0	;
		ADD	RSI, RCX	;
		MOVAPD	XMM0, [RSI]	;
		MULPD	XMM1, XMM7	;
		ADDPD	XMM3, XMM1	;
		ADD	RSI, RCX	;
		MOVAPD	XMM1, [RSI]	;
		MULPD	XMM0, XMM7	;
		ADDPD	XMM4, XMM0	;
		ADD	RSI, RCX	;
		MOVAPD	XMM0, [RSI]	;
		MULPD	XMM1, XMM7	;
		ADDPD	XMM5, XMM1	;
		MULPD	XMM0, XMM7	;
		ADDPD	XMM6, XMM0	;
		ADD	RBX, 16	;
		ADD	RDI, 16	;
		SUB	RAX, 2	;
		JMP	aligned2	;
		horizontaladd: ;
		MOVAPD	XMM1, XMM2	;
		SHUFPD	XMM1, XMM1, 1	;  low bits < -high bits
		ADDPD	XMM2, XMM1	;
		MOVAPD	XMM1, XMM3	;
		SHUFPD	XMM1, XMM1, 1	;  low bits < -high bits
		ADDPD	XMM3, XMM1	;
		MOVAPD	XMM1, XMM4	;
		SHUFPD	XMM1, XMM1, 1	;  low bits < -high bits
		ADDPD	XMM4, XMM1	;
		MOVAPD	XMM1, XMM5	;
		SHUFPD	XMM1, XMM1, 1	;  low bits < -high bits
		ADDPD	XMM5, XMM1	;
		MOVAPD	XMM1, XMM6	;
		SHUFPD	XMM1, XMM1, 1	;  low bits < -high bits
		ADDPD	XMM6, XMM1	;
		singlepieces: ;
		CMP	RAX, 0	;
		JLE	store	;  len <= 0- > exit
		MOV	RSI, [RBP+radr]	;
		MOVSD	XMM7, [RBX]	;
		MOVSD	XMM0, [RSI+RDI]	;
		ADD	RSI, RCX	;
		MOVSD	XMM1, [RSI+RDI]	;
		MULSD	XMM0, XMM7	;
		ADDSD	XMM2, XMM0	;
		ADD	RSI, RCX	;
		MOVSD	XMM0, [RSI+RDI]	;
		MULSD	XMM1, XMM7	;
		ADDSD	XMM3, XMM1	;
		ADD	RSI, RCX	;
		MOVSD	XMM1, [RSI+RDI]	;
		MULSD	XMM0, XMM7	;
		ADDSD	XMM4, XMM0	;
		ADD	RSI, RCX	;
		MOVSD	XMM1, [RSI+RDI]	;
		MULSD	XMM0, XMM7	;
		ADDSD	XMM4, XMM0	;
		ADD	RSI, RCX	;
		MOVSD	XMM0, [RSI+RDI]	;
		MULSD	XMM1, XMM7	;
		ADDSD	XMM5, XMM1	;
		MULSD	XMM0, XMM7	;
		ADDSD	XMM6, XMM0	;
		ADD	RBX, 4 (* INC(ladr,incl) *)
		ADD	RDI, 4 (* INC(radr,incr) *)
		DEC	RAX	;  DEC(len)
		JMP	singlepieces	;
		store:
		MOVSD	[RDX], XMM2	;
		ADD	RDX, [RBP+incd]	;
		MOVSD	[RDX], XMM3	;
		ADD	RDX, [RBP+incd]	;
		MOVSD	[RDX], XMM4	;
		ADD	RDX, [RBP+incd]	;
		MOVSD	[RDX], XMM5	;
		ADD	RDX, [RBP+incd]	;
		MOVSD	[RDX], XMM6	;
		end:
	END AlignedSPXSSE5;
*)


(* sse version of scalar product *)
	PROCEDURE AlignedSPXSSE( ladr, radr, dadr: ADDRESS; len: SIZE;
													 add: BOOLEAN );
	CODE {SYSTEM.AMD64, SYSTEM.SSE2}
		;  register initialization
		MOV	RAX, [RBP+len]	;  RAX reserverd FOR length
		MOV	RBX, [RBP+ladr]	;  RBX reserved FOR ladr
		MOV	RCX, [RBP+radr]	;  RCX reserved FOR radr
		MOV	RDX, [RBP+dadr]	;  RDX reserved FOR dadr
		XORPD	XMM0, XMM0	;
		CMP	[RBP+add], 0	;  add?
		JE	aligned8	;  no add
		MOVSD	XMM0, [RDX]	;
		aligned8:
		CMP	RAX, 8	;
		JL	aligned2	;  len < 4- > EXIT TO singlepieces
		MOVAPD	XMM1, [RBX]	;
		MOVAPD	XMM2, [RBX+16]	;
		MOVAPD	XMM3, [RBX+32]	;
		MOVAPD	XMM4, [RCX]	;
		MOVAPD	XMM5, [RCX+16]	;
		MOVAPD	XMM6, [RCX+32]	;
		MULPD	XMM1, XMM4	;
		ADDPD	XMM0, XMM1	;
		MULPD	XMM2, XMM5	;
		ADDPD	XMM0, XMM2	;
		MULPD	XMM3, XMM6	;
		ADDPD	XMM0, XMM3	;
		MOVAPD	XMM7, [RBX+48]	;
		MOVAPD	XMM1, [RCX+48]	;
		MULPD	XMM1, XMM7	;
		ADDPD	XMM0, XMM1	;
		ADD	RBX, 64	;
		ADD	RCX, 64	;
		SUB	RAX, 8	;
		JMP	aligned8	;
		;  LOOP FOR 2 pieces aligned
		aligned4:
		CMP	RAX, 4	;
		JL	aligned2	;  ;  len < 4- > EXIT TO singlepieces
		MOVAPD	XMM1, [RBX]	;
		MOVAPD	XMM2, [RCX]	;
		MOVAPD	XMM3, [RBX+16]	;
		MOVAPD	XMM4, [RCX+16]	;
		MULPD	XMM1, XMM2	;
		ADDPD	XMM0, XMM1	;
		MULPD	XMM3, XMM4	;
		ADDPD	XMM0, XMM3	;
		ADD	RBX, 32	;
		ADD	RCX, 32	;
		SUB	RAX, 4	;
		JMP	aligned4	;
		aligned2:
		CMP	RAX, 2	;
		JL	horizontaladd	;  ;  len < 4- > EXIT TO singlepieces
		MOVAPD	XMM1, [RBX]	;
		MOVAPD	XMM2, [RCX]	;
		MULPD	XMM1, XMM2	;
		ADDPD	XMM0, XMM1	;
		ADD	RBX, 16	;
		ADD	RCX, 16	;
		SUB	RAX, 2	;
		JMP	aligned2	;
		horizontaladd: ;
		MOVAPD	XMM1, XMM0	;
		SHUFPD	XMM1, XMM1, 1	;  low bits < -high bits
		ADDPD	XMM0, XMM1	;
		singlepieces: ;
		CMP	RAX, 0	;
		JLE	store	;  len <= 0- > EXIT
		MOVSD	XMM1, [RBX]
		MOVSD	XMM2, [RCX]
		MULSD	XMM1, XMM2
		ADDSD	XMM0, XMM1
		ADD	RBX, 8	;  INC(ladr, incl)
		ADD	RCX, 8	;  INC(radr, incr)
		DEC	RAX	;  DEC(len)
		JMP	singlepieces	;
		store:
		MOVSD	[RDX], XMM0	;
		endL:
	END AlignedSPXSSE;

(*
	PROCEDURE AlignedSPRSSE5( ladr, radr, dadr, stride, incd, len: LONGINT );
	CODE {SYSTEM.AMD64, SYSTEM.SSE}
		;  register initialization
		MOV	RDX, [RBP+dadr]	;  RDX reserved for dadr
		MOV	RBX, [RBP+ladr]	;  RBX reserved for ladr
		MOV	RSI, [RBP+radr]	;  RCX reserved for radr
		MOV	RAX, [RBP+len]	;  RAX reserverd for length
		MOV	RCX, [RBP+stride]	;
		XORPS	XMM2, XMM2	;
		XORPS	XMM3, XMM3	;
		XORPS	XMM4, XMM4	;
		XORPS	XMM5, XMM5	;
		XORPS	XMM6, XMM6	;
		XOR	RDI, RDI	;
		aligned8:
		CMP	RAX, 8	;
		JL	aligned4	;  ;  len < 4- > exit to singlepieces
		PREFETCH0	24[RBX]	;
		;  PREFETCH0[RSI]	;
		MOV	RSI, [RBP+radr]	;
		ADD	RSI, RDI	;
		MOVAPS	XMM7, [RBX]	;
		MOVAPS	XMM0, [RSI]	;
		ADD	RSI, RCX	;
		MOVAPS	XMM1, [RSI]	;
		MULPS	XMM0, XMM7	;
		ADDPS	XMM2, XMM0	;
		ADD	RSI, RCX	;
		MOVAPS	XMM0, [RSI]	;
		MULPS	XMM1, XMM7	;
		ADDPS	XMM3, XMM1	;
		ADD	RSI, RCX	;
		MOVAPS	XMM1, [RSI]	;
		MULPS	XMM0, XMM7	;
		ADDPS	XMM4, XMM0	;
		ADD	RSI, RCX	;
		MOVAPS	XMM0, [RSI]	;
		MULPS	XMM1, XMM7	;
		ADDPS	XMM5, XMM1	;
		MULPS	XMM0, XMM7	;
		ADDPS	XMM6, XMM0	;
		ADD	RBX, 16	;
		ADD	RDI, 16	;
		MOV	RSI, [RBP+radr]	;
		ADD	RSI, RDI	;
		MOVAPS	XMM7, [RBX]	;
		MOVAPS	XMM0, [RSI]	;
		ADD	RSI, RCX	;
		MOVAPS	XMM1, [RSI]	;
		MULPS	XMM0, XMM7	;
		ADDPS	XMM2, XMM0	;
		ADD	RSI, RCX	;
		MOVAPS	XMM0, [RSI]	;
		MULPS	XMM1, XMM7	;
		ADDPS	XMM3, XMM1	;
		ADD	RSI, RCX	;
		MOVAPS	XMM1, [RSI]	;
		MULPS	XMM0, XMM7	;
		ADDPS	XMM4, XMM0	;
		ADD	RSI, RCX	;
		MOVAPS	XMM0, [RSI]	;
		MULPS	XMM1, XMM7	;
		ADDPS	XMM5, XMM1	;
		MULPS	XMM0, XMM7	;
		ADDPS	XMM6, XMM0	;
		ADD	RBX, 16	;
		ADD	RDI, 16	;
		SUB	RAX, 8	;
		JMP	aligned8	;
		aligned4:
		CMP	RAX, 4	;
		JL	horizontaladd	;  ;  len < 4- > exit to singlepieces
		MOV	RSI, [RBP+radr]	;
		ADD	RSI, RDI	;
		MOVAPS	XMM7, [RBX]	;
		MOVAPS	XMM0, [RSI]	;
		ADD	RSI, RCX	;
		MOVAPS	XMM1, [RSI]	;
		MULPS	XMM0, XMM7	;
		ADDPS	XMM2, XMM0	;
		ADD	RSI, RCX	;
		MOVAPS	XMM0, [RSI]	;
		MULPS	XMM1, XMM7	;
		ADDPS	XMM3, XMM1	;
		ADD	RSI, RCX	;
		MOVAPS	XMM1, [RSI]	;
		MULPS	XMM0, XMM7	;
		ADDPS	XMM4, XMM0	;
		ADD	RSI, RCX	;
		MOVAPS	XMM0, [RSI]	;
		MULPS	XMM1, XMM7	;
		ADDPS	XMM5, XMM1	;
		MULPS	XMM0, XMM7	;
		ADDPS	XMM6, XMM0	;
		ADD	RBX, 16	;
		ADD	RDI, 16	;
		SUB	RAX, 4	;
		JMP	aligned4	;
		horizontaladd: ;
		MOVLHPS	XMM1, XMM2	;
		ADDPS	XMM1, XMM2	;
		SHUFPS	XMM2, XMM1, 48	;
		ADDPS	XMM2, XMM1	;
		MOVHLPS	XMM2, XMM2	;
		MOVLHPS	XMM1, XMM3	;
		ADDPS	XMM1, XMM3	;
		SHUFPS	XMM3, XMM1, 48	;
		ADDPS	XMM3, XMM1	;
		MOVHLPS	XMM3, XMM3	;
		MOVLHPS	XMM1, XMM4	;
		ADDPS	XMM1, XMM4	;
		SHUFPS	XMM4, XMM1, 48	;
		ADDPS	XMM4, XMM1	;
		MOVHLPS	XMM4, XMM4	;
		MOVLHPS	XMM1, XMM5	;
		ADDPS	XMM1, XMM5	;
		SHUFPS	XMM5, XMM1, 48	;
		ADDPS	XMM5, XMM1	;
		MOVHLPS	XMM5, XMM5	;
		MOVLHPS	XMM1, XMM6	;
		ADDPS	XMM1, XMM6	;
		SHUFPS	XMM6, XMM1, 48	;
		ADDPS	XMM6, XMM1	;
		MOVHLPS	XMM6, XMM6	;
		singlepieces: ;
		CMP	RAX, 0	;
		JLE	store	;  len <= 0- > exit
		MOV	RSI, [RBP+radr]	;
		MOVSS	XMM7, [RBX]	;
		MOVSS	XMM0, [RSI+RDI]	;
		ADD	RSI, RCX	;
		MOVSS	XMM1, [RSI+RDI]	;
		MULSS	XMM0, XMM7	;
		ADDSS	XMM2, XMM0	;
		ADD	RSI, RCX	;
		MOVSS	XMM0, [RSI+RDI]	;
		MULSS	XMM1, XMM7	;
		ADDSS	XMM3, XMM1	;
		ADD	RSI, RCX	;
		MOVSS	XMM1, [RSI+RDI]	;
		MULSS	XMM0, XMM7	;
		ADDSS	XMM4, XMM0	;
		ADD	RSI, RCX	;
		MOVSS	XMM0, [RSI+RDI]	;
		MULSS	XMM1, XMM7	;
		ADDSS	XMM5, XMM1	;
		MULSS	XMM0, XMM7	;
		ADDSS	XMM6, XMM0	;
		ADD	RBX, 4 (* INC(ladr,incl) *)
		ADD	RDI, 4 (* INC(radr,incr) *)
		DEC	RAX	;  DEC(len)
		JMP	singlepieces	;
		store:
		MOVSS	[RDX], XMM2	;
		ADD	RDX, [RBP+incd]	;
		MOVSS	[RDX], XMM3	;
		ADD	RDX, [RBP+incd]	;
		MOVSS	[RDX], XMM4	;
		ADD	RDX, [RBP+incd]	;
		MOVSS	[RDX], XMM5	;
		ADD	RDX, [RBP+incd]	;
		MOVSS	[RDX], XMM6	;
		end:
	END AlignedSPRSSE5;
*)

	PROCEDURE AlignedSPRSSE( ladr, radr, dadr: ADDRESS; len: SIZE;
													 add: BOOLEAN );
	CODE {SYSTEM.AMD64, SYSTEM.SSE}
		;  register initialization
		MOV	RDX, [RBP+dadr]	;  RDX reserved FOR dadr
		MOV	RBX, [RBP+ladr]	;  RBX reserved FOR ladr
		MOV	RCX, [RBP+radr]	;  RCX reserved FOR radr
		MOV	RAX, [RBP+len]	;  RAX reserverd FOR length
		XORPS	XMM0, XMM0	;
		CMP	 [RBP+add], 0	;  add?
		JE	aligned16	;  no add
		MOVSS	XMM0, [RDX]	;
		aligned16:
		CMP	RAX, 16	;
		JL	aligned8	;  len < 4- > EXIT TO singlepieces
		MOVAPS	XMM1, [RBX]	;
		MOVAPS	XMM4, [RCX]	;
		MOVAPS	XMM2, [RBX+16]	;
		MOVAPS	XMM5, [RCX+16]	;
		MULPS	XMM1, XMM4	;
		ADDPS	XMM0, XMM1	;
		MOVAPS	XMM3, [RBX+32]	;
		MOVAPS	XMM6, [RCX+32]	;
		MULPS	XMM2, XMM5	;
		ADDPS	XMM0, XMM2	;
		MOVAPS	XMM7, [RBX+48]	;
		MOVAPS	XMM1, [RCX+48]	;
		MULPS	XMM3, XMM6	;
		ADDPS	XMM0, XMM3	;
		MULPS	XMM1, XMM7	;
		ADDPS	XMM0, XMM1	;
		ADD	RBX, 64	;
		ADD	RCX, 64	;
		SUB	RAX, 16	;
		JMP	aligned16	;
		;  LOOP FOR 8 pieces aligned
		aligned8:
		CMP	RAX, 8	;
		JL	aligned4	;  ;  len < 4- > EXIT TO singlepieces
		MOVAPS	XMM1, [RBX]	;
		MOVAPS	XMM4, [RCX]	;
		MOVAPS	XMM2, [RBX+16]	;
		MOVAPS	XMM5, [RCX+16]	;
		MULPS	XMM1, XMM4	;
		ADDPS	XMM0, XMM1	;
		MULPS	XMM2, XMM5	;
		ADDPS	XMM0, XMM2	;
		ADD	RBX, 32	;
		ADD	RCX, 32	;
		SUB	RAX, 8	;
		JMP	aligned8	;
		aligned4:
		CMP	RAX, 4	;
		JL	horizontaladd	;  ;  len < 4- > EXIT TO singlepieces
		MOVAPS	XMM1, [RBX]	;
		MOVAPS	XMM2, [RCX]	;
		MULPS	XMM1, XMM2	;
		ADDPS	XMM0, XMM1	;
		ADD	RBX, 16	;
		ADD	RCX, 16	;
		SUB	RAX, 4	;
		JMP	aligned4	;
		horizontaladd: ;
		MOVAPS	XMM1, XMM0	;
		; 1*0 (* dest 0 -> dest 0 *) + 4*1 (* dest 1 -> dest 1 *) +16*0 (* src 0 -> dest 2 *) +64*1 (* src 1 -> dest 3 *) ;
		SHUFPS	XMM1, XMM1, 1*0 +4*1 +16*0 +64*1
		ADDPS	XMM1, XMM0	;
		MOVAPS	XMM0, XMM1
		SHUFPS	XMM0, XMM0, 16*3	;  src 3- > dest 2
		ADDPS	XMM0, XMM1	;
		SHUFPS	XMM0, XMM0, 1*2	;  dest 2- > dest 0
		singlepieces: ;
		CMP	RAX, 0	;
		JLE	store	;  len <= 0- > EXIT
		MOVSS	XMM1, [RBX]
		MOVSS	XMM2, [RCX]
		MULSS	XMM1, XMM2
		ADDSS	XMM0, XMM1
		ADD	RBX, 4	;  INC(ladr, incl)
		ADD	RCX, 4	;  INC(radr, incr)
		DEC	RAX	;  DEC(len)
		JMP	singlepieces	;
		store:
		MOVSS	[RDX], XMM0	;
		endL:
	END AlignedSPRSSE;
(*
(* sse version of scalar product *)
	PROCEDURE AlignedSPRSSE( ladr, radr, dadr, rows, stride, dinc, len: LONGINT );
	CODE {SYSTEM.AMD64, SYSTEM.SSE2}
		;  register initialization
		MOV	RDI, [RBP+radr]	;  radr start
		MOV	RDX, [RBP+dadr]	;  RDX reserved for dadr
		MOV	RSI, [RBP+rows]	;  outer loop counter
		outerloop:
		CMP	RSI, 0	;
		JLE	end	;
		MOV	RBX, [RBP+ladr]	;  RBX reserved for ladr
		MOV	RCX, RDI	;  RCX reserved for radr

		MOV	RAX, [RBP+len]	;  RAX reserverd for length
		XORPS	XMM0, XMM0	;
		aligned16:
		CMP	RAX, 16	;
		JL	aligned8	;  len < 4- > exit to singlepieces
		MOVAPS	XMM1, [RBX]	;
		MOVAPS	XMM2, [RBX+16]	;
		MOVAPS	XMM3, [RBX+32]	;
		MOVAPS	XMM4, [RCX]	;
		MOVAPS	XMM5, [RCX+16]	;
		MOVAPS	XMM6, [RCX+32]	;
		MULPS	XMM1, XMM4	;
		ADDPS	XMM0, XMM1	;
		MULPS	XMM2, XMM5	;
		ADDPS	XMM0, XMM2	;
		MULPS	XMM3, XMM6	;
		ADDPS	XMM0, XMM3	;
		MOVAPS	XMM7, [RBX+48]	;
		MOVAPS	XMM1, [RCX+48]	;
		MULPS	XMM1, XMM7	;
		ADDPS	XMM0, XMM1	;
		ADD	RBX, 64	;
		ADD	RCX, 64	;
		SUB	RAX, 16	;
		JMP	aligned16	;
		;  loop for 8 pieces aligned
		aligned8:
		CMP	RAX, 8	;
		JL	aligned4	;  ;  len < 4- > exit to singlepieces
		MOVAPS	XMM1, [RBX]	;
		MOVAPS	XMM2, [RBX+16]	;
		MOVAPS	XMM4, [RCX]	;
		MOVAPS	XMM5, [RCX+16]	;
		MULPS	XMM1, XMM4	;
		ADDPS	XMM0, XMM1	;
		MULPS	XMM2, XMM5	;
		ADDPS	XMM0, XMM2	;
		ADD	RBX, 32	;
		ADD	RCX, 32	;
		SUB	RAX, 8	;
		JMP	aligned8	;
		aligned4:
		CMP	RAX, 4	;
		JL	horizontaladd	;  ;  len < 4- > exit to singlepieces
		MOVAPS	XMM1, [RBX]	;
		MOVAPS	XMM2, [RCX]	;
		MULPS	XMM1, XMM2	;
		ADDPS	XMM0, XMM1	;
		ADD	RBX, 16	;
		ADD	RCX, 16	;
		SUB	RAX, 4	;
		JMP	aligned4	;
		horizontaladd: ;
		MOVAPS	XMM1, XMM0	;
		SHUFPS	XMM1, XMM1, 1*0 (* dest 0 -> dest 0 *) +4*1 (* dest 1 -> dest 1 *) +16*0 (* src 0 -> dest 2 *) +64*1 (* src 1 -> dest 3 *) ;
		ADDPS	XMM1, XMM0	;
		MOVAPS	XMM0, XMM1
		SHUFPS	XMM0, XMM0, 16*3	;   (*  src 3-> dest 2  *)
		ADDPS	XMM0, XMM1	;
		SHUFPS	XMM0, XMM0, 1*2	;   (* dest 2 ->  dest 0 *)
		singlepieces: ;
		CMP	RAX, 0	;
		JLE	store	;  len <= 0- > exit
		MOVSS	XMM1, [RBX]
		MOVSS	XMM2, [RCX]
		MULSS	XMM1, XMM2
		ADDSS	XMM0, XMM1
		ADD	RBX, 4 (* INC(ladr,incl) *)
		ADD	RCX, 4 (* INC(radr,incr) *)
		DEC	RAX	;  DEC(len)
		JMP	singlepieces	;
		store:
		MOVSS	[RDX], XMM0	;
		ADD	RDX, [RBP+dinc]	;
		ADD	RDI, [RBP+stride]	;
		DEC	RSI	;
		JMP	outerloop	;
		end:
	END AlignedSPRSSE;
*)

	PROCEDURE Copy4( ladr, dadr: ADDRESS; linc, dinc, len: SIZE);
	CODE {SYSTEM.AMD64}
		MOV	RSI, [RBP+ladr]	;  RCX := ladr
		MOV	RDI, [RBP+dadr]	;  RDX := dadr
		MOV	RCX, [RBP+len]	;  RBX := len
		MOV	RAX, [RBP+linc]	;
		CMP	RAX, 4	;
		JNE	loopL	;
		MOV	RAX, [RBP+dinc]	;
		CMP	RAX, 4	;
		JNE	loopL	;
		fastmove:
		CLD	;  incremental
		REP	;
		MOVSD	;  move rest IN one byte steps
		JMP	endL	;
		loopL:
				CMP	RCX, 0	;
		JLE	endL	;  WHILE RCX > 0 DO
		MOV	EAX, [RSI]	;  RAX := SYSTEM.GET32(RSI)
		MOV	[RDI], EAX	;  SYSTEM.PUT32(RDI, RAX))
		ADD	RSI, [RBP+linc]	;  INC(RSI, linc)
		ADD	RDI, [RBP+dinc]	;  INC(RDI, rinc)
		DEC	RCX	;  DEC(RCX)
		JMP	loopL
		endL:
	END Copy4;

	PROCEDURE Copy8( ladr, dadr: ADDRESS; linc, dinc, len: SIZE );
	CODE {SYSTEM.AMD64}
		MOV	RSI, [RBP+ladr]	;  RCX := ladr
		MOV	RDI, [RBP+dadr]	;  RDX := dadr
		MOV	RCX, [RBP+len]	;  RBX := len
		MOV	RAX, [RBP+linc]	;
		CMP	RAX, 8	;
		JNE	loopL	;
		MOV	RAX, [RBP+dinc]	;
		CMP	RAX, 8	;
		JNE	loopL	;
		fastmove:
		SHL	RCX, 1	;
		CLD	;  incremental
		REP	;
		MOVSD	;  move rest IN one byte steps
		JMP	endL	;
		loopL:
		CMP	RCX, 0	;
		JLE	endL	;  WHILE RBX > 0 DO
		MOV	RAX, [RSI]	;  RAX := SYSTEM.GET64(RCX)
		MOV	[RDI], RAX	;  SYSTEM.PUT64(RDX, RAX))
		ADD	RSI, [RBP+linc]	;  INC(RCX, linc)
		ADD	RDI, [RBP+dinc]	;  INC(RDX, rinc)
		DEC	RCX	;  DEC(RBX)
		JMP	loopL
		endL:
	END Copy8;

	PROCEDURE Transpose4A( ladr, dadr: ADDRESS; lstride, linc, dstride, dinc, rows, cols: SIZE );
	CODE {SYSTEM.AMD64}
		startrows:
		MOV	RAX, [RBP+rows]	;
		startouter:
		CMP	RAX, 0	;
		JLE	endL	;
		MOV	RSI, [RBP+ladr]	;
		MOV	RDI, [RBP+dadr]	;
		MOV	RBX, [RBP+linc]	;
		MOV	RCX,  [RBP+dstride]	;
		MOV	RAX,  [RBP+cols]	;
		startinner:
		CMP	RAX, 0	;
		JLE	endinner	;
		MOV	RDX, [RSI]	;
		MOV	[RDI], RDX	;
		ADD	RSI, RBX	;
		ADD	RDI, RCX	;
		DEC	RAX	;
		JMP	startinner	;
		endinner:
		MOV	RSI, [RBP+ladr]	;
		ADD	RSI, [RBP+lstride]	;
		MOV	[RBP+ladr], RSI
		MOV	RDI, [RBP+dadr]	;
		ADD	RDI, [RBP+dinc]	;
		MOV	[RBP+dadr], RDI	;
		MOV	RAX, [RBP+rows]	;
		DEC	RAX	;
		MOV	[RBP+rows], RAX	;
		JMP	startouter	;
		endL:
	END Transpose4A;

	PROCEDURE Transpose4( ladr, dadr: ADDRESS; lstride, linc, dstride, dinc, rows, cols: SIZE );
	VAR l, d, c: SIZE;  BlockSize: SIZE;
	BEGIN
		BlockSize :=
			MIN( L2BlockSize DIV lstride, L2BlockSize DIV lstride );
		BlockSize := MIN( BlockSize, L2BlockSize DIV linc );
		BlockSize := MIN( BlockSize, L2BlockSize DIV dinc );
		BlockSize := MAX( 8, BlockSize );
		(* KernelLog.String("Blocksize = "); KernelLog.Int(BlockSize,10); KernelLog.Ln; *)
		WHILE (rows >= BlockSize) DO
			c := cols;  l := ladr;  d := dadr;
			WHILE (c >= BlockSize) DO
				Transpose4A( l, d, lstride, linc, dstride, dinc, BlockSize,
									 BlockSize );
				DEC( c, BlockSize );  INC( l, BlockSize * linc );
				INC( d, BlockSize * dstride );
			END;
			IF c > 0 THEN
				Transpose4A( l, d, lstride, linc, dstride, dinc, BlockSize, c );
			END;
			DEC( rows, BlockSize );  INC( ladr, BlockSize * lstride );
			INC( dadr, BlockSize * dinc );
		END;
		IF (rows > 0) THEN
			c := cols;  l := ladr;  d := dadr;
			WHILE (c >= BlockSize) DO
				Transpose4A( l, d, lstride, linc, dstride, dinc, rows,
									 BlockSize );
				DEC( c, BlockSize );  INC( l, BlockSize * linc );
				INC( d, BlockSize * dstride );
			END;
			IF c > 0 THEN
				Transpose4A( l, d, lstride, linc, dstride, dinc, rows, c );
			END;
		END;
	END Transpose4;

	PROCEDURE Transpose8( ladr, dadr: ADDRESS; lstride, linc, dstride, dinc, rows, cols: SIZE );
	VAR l, d, c: SIZE;  BlockSize: SIZE;
	BEGIN
		BlockSize :=
			MIN( L2BlockSize DIV lstride, L2BlockSize DIV lstride );
		BlockSize := MIN( BlockSize, L2BlockSize DIV linc );
		BlockSize := MIN( BlockSize, L2BlockSize DIV dinc );
		BlockSize := MAX( 8, BlockSize );

		(* KernelLog.String("Blocksize = "); KernelLog.Int(BlockSize,10); KernelLog.Ln; *)
		WHILE (rows >= BlockSize) DO
			c := cols;  l := ladr;  d := dadr;
			WHILE (c >= BlockSize) DO
				Transpose8A( l, d, lstride, linc, dstride, dinc, BlockSize,
									 BlockSize );
				DEC( c, BlockSize );  INC( l, BlockSize * linc );
				INC( d, BlockSize * dstride );
			END;
			IF c > 0 THEN
				Transpose8A( l, d, lstride, linc, dstride, dinc, BlockSize, c );
			END;
			DEC( rows, BlockSize );  INC( ladr, lstride * BlockSize );
			INC( dadr, dinc * BlockSize );
		END;
		IF (rows > 0) THEN
			c := cols;  l := ladr;  d := dadr;
			WHILE (c >= BlockSize) DO
				Transpose8A( l, d, lstride, linc, dstride, dinc, rows,
									 BlockSize );
				DEC( c, BlockSize );  INC( l, BlockSize * linc );
				INC( d, BlockSize * dstride );
			END;
			IF c > 0 THEN
				Transpose8A( l, d, lstride, linc, dstride, dinc, rows, c );
			END;
		END;
	END Transpose8;

	PROCEDURE Transpose8A( ladr, dadr: ADDRESS; lstride, linc, dstride, dinc, rows, cols: SIZE );
	CODE {SYSTEM.AMD64}
		startrows:
		MOV	RAX, [RBP+rows]	;
		startouter:
		CMP	RAX, 0	;
		JLE	endL	;
		MOV	RSI, [RBP+ladr]	;
		MOV	RDI, [RBP+dadr]	;
		MOV	RBX, [RBP+linc]	;
		MOV	RCX,  [RBP+dstride]	;
		MOV	RAX,  [RBP+cols]	;
		startinner:
		CMP	RAX, 0	;
		JLE	endinner	;
		MOV	RDX, [RSI]	;
		MOV	[RDI], RDX	;
		MOV	RDX, [RSI+4]	;
		MOV	[RDI+4], RDX	;
		ADD	RSI, RBX	;
		ADD	RDI, RCX	;
		DEC	RAX	;
		JMP	startinner	;
		endinner:
		MOV	RSI, [RBP+ladr]	;
		ADD	RSI, [RBP+lstride]	;
		MOV	[RBP+ladr], RSI
		MOV	RDI, [RBP+dadr]	;
		ADD	RDI, [RBP+dinc]	;
		MOV	[RBP+dadr], RDI	;
		MOV	RAX, [RBP+rows]	;
		DEC	RAX	;
		MOV	[RBP+rows], RAX	;
		JMP	startouter	;
		endL:
	END Transpose8A;

	PROCEDURE SSEMul24BlockR( VAR CbFirst: SIZE;
													  StrideA, StrideB, StrideC, Ca, Ra, Cb, Rb: SIZE; matrixA, matrixB, matrixC: ADDRESS;
													  add: BOOLEAN );
	CODE {SYSTEM.AMD64, SYSTEM.SSE}
		MatrixOfResultsSetup:
		MOV	RCX, 0	;  counter FOR rows IN A-Ra
		RowOfResultsLoop:
		MOV	RBX, 0	;  counter FOR columns IN B-Cb
		DotProductSetup:
		MOV	RSI,  [RBP+matrixA]	;  matrixA
		MOV	RDI,  [RBP+matrixB]	;  matrixB
		LEA	RDI, [RDI+RBX*4]	;  current position IN matrixB
		XORPS	XMM2, XMM2
		XORPS	XMM3, XMM3
		XORPS	XMM4, XMM4
		XORPS	XMM5, XMM5
		XORPS	XMM6, XMM6
		XORPS	XMM7, XMM7
		MOV	RAX, 0	;
		MOV	AL, [RBP+add]	;
		CMP	AL, 0	;  add?
		JE	DotProductLoop	;
		MOV	RAX, [RBP+matrixC]	;  matrixC
		LEA	RAX, [RAX+RBX*4]	;  adjust POINTER horizontally TO correct batch OF 24
		MOVUPS	XMM2, [RAX]
		MOVUPS	XMM3, [RAX+16]
		MOVUPS	XMM4, [RAX+32]
		MOVUPS	XMM5, [RAX+48]
		MOVUPS	XMM6, [RAX+64]
		MOVUPS	XMM7, [RAX+80]
		MOV	RAX, 0
		DotProductLoop:
		MOV	RDX, [RSI+RAX*4]
		SHL	RDX, 1
		CMP	RDX, 0
		JE	SparseEntryEscape
		MOVSS	XMM0, [RSI+RAX*4]
		SHUFPS	XMM0, XMM0, 0H
		MOVUPS	XMM1, [RDI]
		MULPS	XMM1, XMM0
		ADDPS	XMM2, XMM1
		MOVUPS	XMM1, [RDI+16]
		MULPS	XMM1, XMM0
		ADDPS	XMM3, XMM1
		MOVUPS	XMM1, [RDI+32]
		MULPS	XMM1, XMM0
		ADDPS	XMM4, XMM1
		MOVUPS	XMM1, [RDI+48]
		MULPS	XMM1, XMM0
		ADDPS	XMM5, XMM1
		MOVUPS	XMM1, [RDI+64]
		MULPS	XMM1, XMM0
		ADDPS	XMM6, XMM1
		MOVUPS	XMM1, [RDI+80]
		MULPS	XMM1, XMM0
		ADDPS	XMM7, XMM1
		SparseEntryEscape:
		ADD	RDI, [RBP+StrideB]	;  StrideB
		INC	RAX
		CMP	RAX, [RBP+Ca]	;  Ca, could also compare TO Rb since they must be equal
		JL	DotProductLoop
		;  endL DopProductLoop
		MOV	RAX, [RBP+matrixC]	;  matrixC
		LEA	RAX, [RAX+RBX*4]	;  adjust POINTER horizontally TO correct batch OF 24
		MOVUPS	[RAX], XMM2
		MOVUPS	[RAX+16], XMM3
		MOVUPS	[RAX+32], XMM4
		MOVUPS	[RAX+48], XMM5
		MOVUPS	[RAX+64], XMM6
		MOVUPS	[RAX+80], XMM7
		ADD	RBX, 24	;  move over TO next batch OF 24
		MOV	RDX, RBX
		ADD	RDX, 24
		CMP	RDX, [RBP+Cb]	;  Cb, check TO see IF row IS complete
		JLE	DotProductSetup
		;  endL RowOfResultsLoop
		MOV	RAX,  [RBP+matrixA]	;  matrixA
		ADD	RAX, [RBP+StrideA]	;  StrideA
		MOV	 [RBP+matrixA], RAX	;  matrixA
		MOV	RAX, [RBP+matrixC]	;  matrixC
		ADD	RAX, [RBP+StrideC]	;  StrideC
		MOV	[RBP+matrixC], RAX	;  matrixC
		INC	RCX
		CMP	RCX, [RBP+Ra]	;  Ra
		JL	RowOfResultsLoop
		Done:
		MOV	RAX, [RBP+CbFirst]	;  CbFirst
		MOV	[RAX], RBX	;
	END SSEMul24BlockR;


(*! might be better to make a 10Block operation and utilize 2 registers for temporary calculations, see article abaout Emmerald*)

	PROCEDURE SSEMul12BlockX( VAR CbFirst: SIZE;
													  StrideA, StrideB, StrideC, Ca, Ra, Cb, Rb: SIZE; matrixA, matrixB, matrixC :ADDRESS;
													  add: BOOLEAN );
	CODE {SYSTEM.AMD64, SYSTEM.SSE2}
		MatrixOfResultsSetup:
		MOV	RCX, 0	;  counter FOR rows IN A-Ra
		RowOfResultsLoop:
		MOV	RBX, 0	;  counter FOR columns IN B-Cb
		DotProductSetup:
		MOV	RSI,  [RBP+matrixA]	;  matrixA
		MOV	RDI,  [RBP+matrixB]	;  matrixB
		LEA	RDI, [RDI+RBX*8]
		XORPD	XMM2, XMM2
		XORPD	XMM3, XMM3
		XORPD	XMM4, XMM4
		XORPD	XMM5, XMM5
		XORPD	XMM6, XMM6
		XORPD	XMM7, XMM7
		MOV	RAX, 0	;
		MOV	AL, [RBP+add]	;
		CMP	AL, 0	;  add?
		JE	DotProductLoop	;
		MOV	RAX, [RBP+matrixC]	;  matrixC
		LEA	RAX, [RAX+RBX*8]	;  adjust POINTER horizontally TO correct batch OF 12
		MOVUPD	XMM2, [RAX]
		MOVUPD	XMM3, [RAX+16]
		MOVUPD	XMM4, [RAX+32]
		MOVUPD	XMM5, [RAX+48]
		MOVUPD	XMM6, [RAX+64]
		MOVUPD	XMM7, [RAX+80]
		MOV	RAX, 0
		DotProductLoop:
		;  MOV RDX, [RSI+RAX*8]
		;  SHL RDX, 1
		;  CMP RDX, 0
		;  JE SparseEntryEscape
		MOVSD	XMM0, [RSI+RAX*8]
		SHUFPD	XMM0, XMM0, 0H
		MOVUPD	XMM1, [RDI]
		MULPD	XMM1, XMM0
		ADDPD	XMM2, XMM1
		MOVUPD	XMM1, [RDI+16]
		MULPD	XMM1, XMM0
		ADDPD	XMM3, XMM1
		MOVUPD	XMM1, [RDI+32]
		MULPD	XMM1, XMM0
		ADDPD	XMM4, XMM1
		MOVUPD	XMM1, [RDI+48]
		MULPD	XMM1, XMM0
		ADDPD	XMM5, XMM1
		MOVUPD	XMM1, [RDI+64]
		MULPD	XMM1, XMM0
		ADDPD	XMM6, XMM1
		MOVUPD	XMM1, [RDI+80]
		MULPD	XMM1, XMM0
		ADDPD	XMM7, XMM1
		SparseEntryEscape:
		ADD	RDI, [RBP+StrideB]	;  StrideB
		INC	RAX
		CMP	RAX, [RBP+Ca]	;  Ca, could also compare TO Rb since they must be equal
		JL	DotProductLoop ; endL DopProductLoop
		MOV		RAX	, [RBP+matrixC]	;  matrixC
		LEA	RAX, [RAX+RBX*8]	;  adjust POINTER horizontally TO correct batch OF 24
		MOVUPD	[RAX], XMM2
		MOVUPD	[RAX+16], XMM3
		MOVUPD	[RAX+32], XMM4
		MOVUPD	[RAX+48], XMM5
		MOVUPD	[RAX+64], XMM6
		MOVUPD	[RAX+80], XMM7
		ADD	RBX, 12	;  move over TO next batch OF 12
		MOV	RDX, RBX
		ADD	RDX, 12
		CMP	RDX, [RBP+Cb]	;  Cb, check TO see IF row IS complete
		JLE	DotProductSetup ; end RowOfResultsLoop
		MOV RAX	,  [RBP+matrixA]	;  matrixA
		ADD	RAX, [RBP+StrideA]	;  StrideA
		MOV	 [RBP+matrixA], RAX	;  matrixA
		MOV	RAX, [RBP+matrixC]	;  matrixC
		ADD	RAX, [RBP+StrideC]	;  StrideC
		MOV	[RBP+matrixC], RAX	;  matrixC
		INC	RCX
		CMP	RCX, [RBP+Ra]	;  Ra
		JL	RowOfResultsLoop
		Done:
		MOV	RAX, [RBP+CbFirst]	;  CbFirst
		MOV	[RAX], RBX	;
	END SSEMul12BlockX;

	PROCEDURE SSEMul16BlockR( StrideA, StrideB, StrideC, Ca, Ra, CbFrom: SIZE; matrixA, matrixB, matrixC: ADDRESS;
													  add: BOOLEAN );
	CODE {SYSTEM.AMD64, SYSTEM.SSE}
		MOV	RCX, 0	;  counter FOR rows IN A-Ra
		DotProductSetup:
		MOV	RSI,  [RBP+matrixA]	;  matrixA
		MOV	RDI,  [RBP+matrixB]	;  matrixB
		MOV	RDX, [RBP+CbFrom]	;  CbFrom
		LEA	RDI, [RDI+RDX*4]
		XORPS	XMM2, XMM2
		XORPS	XMM3, XMM3
		XORPS	XMM4, XMM4
		XORPS	XMM5, XMM5
		MOV	RAX, 0	;
		MOV	AL, [RBP+add]	;
		CMP	AL, 0	;  add?
		JE	DotProductLoop	;
		MOV	RAX, [RBP+matrixC]	;  matrixC
		LEA	RAX, [RAX+RDX*4]	;  adjust POINTER horizontally
		MOVUPS	XMM2, [RAX]
		MOVUPS	XMM3, [RAX+16]
		MOVUPS	XMM4, [RAX+32]
		MOVUPS	XMM5, [RAX+48]
		MOV	RAX, 0
		DotProductLoop:
		MOV	RDX, [RSI+RAX*4]
		SHL	RDX, 1
		CMP	RDX, 0
		JE	SparseEntryEscape
		MOVSS	XMM0, [RSI+RAX*4]
		SHUFPS	XMM0, XMM0, 0H
		MOVUPS	XMM1, [RDI]
		MULPS	XMM1, XMM0
		ADDPS	XMM2, XMM1
		MOVUPS	XMM1, [RDI+16]
		MULPS	XMM1, XMM0
		ADDPS	XMM3, XMM1
		MOVUPS	XMM1, [RDI+32]
		MULPS	XMM1, XMM0
		ADDPS	XMM4, XMM1
		MOVUPS	XMM1, [RDI+48]
		MULPS	XMM1, XMM0
		ADDPS	XMM5, XMM1
		SparseEntryEscape:
		ADD	RDI, [RBP+StrideB]	;  StrideB
		INC	RAX
		CMP	RAX, [RBP+Ca]	;  Ca
		JL	DotProductLoop ; end DotProductLoop
		MOV RAX	, [RBP+matrixC]	;  matrixC
		MOV RDX, [RBP+CbFrom]	;  CbFirst
		LEA	RAX, [RAX+RDX*4]	;  adjust POINTER horizontally TO correct batch OF 12
		MOVUPS	[RAX], XMM2
		MOVUPS	[RAX+16], XMM3
		MOVUPS	[RAX+32], XMM4
		MOVUPS	[RAX+48], XMM5
		MOV	RAX,  [RBP+matrixA]	;  matrixA
		ADD	RAX, [RBP+StrideA]	;  StrideA
		MOV	 [RBP+matrixA], RAX	;  matrixA
		MOV	RAX, [RBP+matrixC]	;  matrixC
		ADD	RAX, [RBP+StrideC]	;  StrideC
		MOV	[RBP+matrixC], RAX	;  matrixC
		INC	RCX
		CMP	RCX, [RBP+Ra]	;  Ra
		JL	DotProductSetup	;
	END SSEMul16BlockR;

	PROCEDURE SSEMul8BlockX( StrideA, StrideB, StrideC, Ca, Ra, CbFrom: SIZE; matrixA, matrixB, matrixC: ADDRESS;
													add: BOOLEAN );
	CODE {SYSTEM.AMD64, SYSTEM.SSE2}
		MOV	RCX, 0	;  counter FOR rows IN A-Ra
		DotProductSetup:
		MOV	RSI,  [RBP+matrixA]	;  matrixA
		MOV	RDI,  [RBP+matrixB]	;  matrixB
		MOV	RDX, [RBP+CbFrom]	;  CbFrom
		LEA	RDI, [RDI+RDX*8]
		XORPD	XMM2, XMM2
		XORPD	XMM3, XMM3
		XORPD	XMM4, XMM4
		XORPD	XMM5, XMM5
		MOV	RAX, 0	;
		MOV	AL, [RBP+add]	;
		CMP	AL, 0	;  add?
		JE	DotProductLoop	;
		MOV	RAX, [RBP+matrixC]	;  matrixC
		LEA	RAX, [RAX+RDX*8]	;  adjust POINTER horizontally TO correct batch OF 24
		MOVUPD	XMM2, [RAX]
		MOVUPD	XMM3, [RAX+16]
		MOVUPD	XMM4, [RAX+32]
		MOVUPD	XMM5, [RAX+48]
		MOV	RAX, 0
		DotProductLoop:
		;  MOV RDX, [RSI+RAX*8]
		;  SHL RDX, 1
		;  CMP RDX, 0
		;  JE SparseEntryEscape
		MOVSD	XMM0, [RSI+RAX*8]
		SHUFPD	XMM0, XMM0, 0H
		MOVUPD	XMM1, [RDI]
		MULPD	XMM1, XMM0
		ADDPD	XMM2, XMM1
		MOVUPD	XMM1, [RDI+16]
		MULPD	XMM1, XMM0
		ADDPD	XMM3, XMM1
		MOVUPD	XMM1, [RDI+32]
		MULPD	XMM1, XMM0
		ADDPD	XMM4, XMM1
		MOVUPD	XMM1, [RDI+48]
		MULPD	XMM1, XMM0
		ADDPD	XMM5, XMM1
		SparseEntryEscape:
		ADD	RDI, [RBP+StrideB]	;  StrideB
		INC	RAX
		CMP	RAX, [RBP+Ca]	;  Ca
		JL	DotProductLoop ; end DotProductLoop
		MOV RAX	, [RBP+matrixC]	;  matrixC
		MOV	RDX, [RBP+CbFrom]	;  CbFirst
		LEA	RAX, [RAX+RDX*8]	;  adjust POINTER horizontally TO correct batch OF 12
		MOVUPD	[RAX], XMM2
		MOVUPD	[RAX+16], XMM3
		MOVUPD	[RAX+32], XMM4
		MOVUPD	[RAX+48], XMM5
		MOV	RAX,  [RBP+matrixA]	;  matrixA
		ADD	RAX, [RBP+StrideA]	;  StrideA
		MOV	 [RBP+matrixA], RAX	;  matrixA
		MOV	RAX, [RBP+matrixC]	;  matrixC
		ADD	RAX, [RBP+StrideC]	;  StrideC
		MOV	[RBP+matrixC], RAX	;  matrixC
		INC	RCX
		CMP	RCX, [RBP+Ra]	;  Ra
		JL	DotProductSetup	;
	END SSEMul8BlockX;

	PROCEDURE SSEMul8BlockR( StrideA, StrideB, StrideC, Ca, Ra, CbFrom: SIZE; matrixA, matrixB, matrixC: ADDRESS;
													add: BOOLEAN );
	CODE {SYSTEM.AMD64, SYSTEM.SSE}
		MOV	RCX, 0	;  counter FOR rows IN A-Ra
		DotProductSetup:
		MOV	RSI,  [RBP+matrixA]	;  matrixA
		MOV	RDI,  [RBP+matrixB]	;  matrixB
		MOV	RDX, [RBP+CbFrom]	;  CbFrom
		LEA	RDI, [RDI+RDX*4]
		XORPS	XMM2, XMM2
		XORPS	XMM3, XMM3
		MOV	RAX, 0	;
		MOV	AL, [RBP+add]	;
		CMP	AL, 0	;  add?
		JE	DotProductLoop	;
		MOV	RAX, [RBP+matrixC]	;  matrixC
		LEA	RAX, [RAX+RDX*4]	;  adjust POINTER horizontally TO correct batch OF 8
		MOVUPS	XMM2, [RAX]
		MOVUPS	XMM3, [RAX+16]
		MOV	RAX, 0
		DotProductLoop:
		MOV	RDX, [RSI+RAX*4]
		SHL	RDX, 1
		CMP	RDX, 0
		JE	SparseEntryEscape
		MOVSS	XMM0, [RSI+RAX*4]
		SHUFPS	XMM0, XMM0, 0H
		MOVUPS	XMM1, [RDI]
		MULPS	XMM1, XMM0
		ADDPS	XMM2, XMM1
		MOVUPS	XMM1, [RDI+16]
		MULPS	XMM1, XMM0
		ADDPS	XMM3, XMM1
		SparseEntryEscape:
		ADD	RDI, [RBP+StrideB]	;  StrideB
		INC	RAX
		CMP	RAX, [RBP+Ca]	;  Ca
		JL	DotProductLoop ; end DotProductLoop
		MOV RAX	, [RBP+matrixC]	;  matrixC
		MOV	RDX, [RBP+CbFrom]	;  CbFrom
		LEA	RAX, [RAX+RDX*4]	;  adjust POINTER horizontally TO correct batch OF 8
		MOVUPS	[RAX], XMM2
		MOVUPS	[RAX+16], XMM3
		MOV	RAX,  [RBP+matrixA]	;  matrixA
		ADD	RAX, [RBP+StrideA]	;  StrideA
		MOV	 [RBP+matrixA], RAX	;  matrixA
		MOV	RAX, [RBP+matrixC]	;  matrixC
		ADD	RAX, [RBP+StrideC]	;  StrideC
		MOV	[RBP+matrixC], RAX	;  matrixC
		INC	RCX
		CMP	RCX, [RBP+Ra]	;  Ra
		JL	DotProductSetup	;
	END SSEMul8BlockR;

	PROCEDURE SSEMul4BlockX( StrideA, StrideB, StrideC, Ca, Ra, CbFrom: SIZE; matrixA, matrixB, matrixC: ADDRESS;
													add: BOOLEAN );
	CODE {SYSTEM.AMD64, SYSTEM.SSE2}
		MOV	RCX, 0	;  counter FOR rows IN A-Ra
		DotProductSetup:
		MOV	RAX, 0	;  cols IN A
		MOV	RSI,  [RBP+matrixA]	;  matrixA
		MOV	RDI,  [RBP+matrixB]	;  matrixB
		MOV	RDX, [RBP+CbFrom]	;  CbFrom
		LEA	RDI, [RDI+RDX*8]
		XORPS	XMM2, XMM2
		XORPS	XMM3, XMM3
		MOV	RAX, 0	;
		MOV	AL, [RBP+add]	;
		CMP	AL, 0	;  add?
		JE	DotProductLoop	;
		MOV	RAX, [RBP+matrixC]	;  matrixC
		LEA	RAX, [RAX+RDX*8]	;  adjust POINTER horizontally TO correct batch OF 8
		MOVUPD	XMM2, [RAX]
		MOVUPD	XMM3, [RAX+16]
		MOV	RAX, 0
		DotProductLoop:
		;  MOV RDX, [RSI+RAX*8]
		;  SHL RDX, 1
		;  CMP RDX, 0
		;  JE SparseEntryEscape
		MOVSD	XMM0, [RSI+RAX*8]
		SHUFPD	XMM0, XMM0, 0H
		MOVUPD	XMM1, [RDI]
		MULPD	XMM1, XMM0
		ADDPD	XMM2, XMM1
		MOVUPD	XMM1, [RDI+16]
		MULPD	XMM1, XMM0
		ADDPD	XMM3, XMM1
		SparseEntryEscape:
		ADD	RDI, [RBP+StrideB]	;  StrideB
		INC	RAX
		CMP	RAX, [RBP+Ca]	;  Ca
		JL	DotProductLoop ; end DotProductLoop
		MOV RAX	, [RBP+matrixC]	;  matrixC
		MOV	RDX, [RBP+CbFrom]	;  CbFrom
		LEA	RAX, [RAX+RDX*8]	;  adjust POINTER horizontally TO correct batch OF 8
		MOVUPD	[RAX], XMM2
		MOVUPD	[RAX+16], XMM3
		MOV	RAX,  [RBP+matrixA]	;  matrixA
		ADD	RAX, [RBP+StrideA]	;  StrideA
		MOV	 [RBP+matrixA], RAX	;  matrixA
		MOV	RAX, [RBP+matrixC]	;  matrixC
		ADD	RAX, [RBP+StrideC]	;  StrideC
		MOV	[RBP+matrixC], RAX	;  matrixC
		INC	RCX
		CMP	RCX, [RBP+Ra]	;  Ra
		JL	DotProductSetup	;
	END SSEMul4BlockX;

	PROCEDURE SSEMul4BlockR( StrideA, StrideB, StrideC, Ca, Ra, CbFrom: SIZE; matrixA, matrixB, matrixC: ADDRESS;
													add: BOOLEAN );
	CODE {SYSTEM.AMD64, SYSTEM.SSE}
		MOV	RCX, 0	;  counter FOR rows IN A-Ra
		DotProductSetup:
		MOV	RAX, 0	;  cols IN A
		MOV	RSI,  [RBP+matrixA]	;  matrixA
		MOV	RDI,  [RBP+matrixB]	;  matrixB
		MOV	RDX, [RBP+CbFrom]	;  CbFrom
		LEA	RDI, [RDI+RDX*4]
		XORPS	XMM2, XMM2
		MOV	RAX, 0	;
		MOV	AL, [RBP+add]	;
		CMP	AL, 0	;  add?
		JE	DotProductLoop	;
		MOV	RAX, [RBP+matrixC]	;  matrixC
		LEA	RAX, [RAX+RDX*4]	;  adjust POINTER horizontally TO correct batch OF 4
		MOVUPS	XMM2, [RAX]
		MOV	RAX, 0
		DotProductLoop:
		MOV	RDX, [RSI+RAX*4]
		SHL	RDX, 1
		CMP	RDX, 0
		JE	SparseEntryEscape
		MOVSS	XMM0, [RSI+RAX*4]
		SHUFPS	XMM0, XMM0, 0H
		MOVUPS	XMM1, [RDI]
		MULPS	XMM1, XMM0
		ADDPS	XMM2, XMM1
		SparseEntryEscape:
		ADD	RDI, [RBP+StrideB]	;  StrideB
		INC	RAX
		CMP	RAX, [RBP+Ca]	;  Ca
		JL	DotProductLoop ; end DopProductLoop
		MOV RAX, [RBP+matrixC]	;  matrixC
		MOV	RDX, [RBP+CbFrom]	;  CbFrom
		LEA	RAX, [RAX+RDX*4]	;  adjust POINTER horizontally TO correct batch OF 4
		MOVUPS	[RAX], XMM2
		MOV	RAX,  [RBP+matrixA]	;  matrixA
		ADD	RAX, [RBP+StrideA]	;  StrideA
		MOV	 [RBP+matrixA], RAX	;  matrixA
		MOV	RAX, [RBP+matrixC]	;  matrixC
		ADD	RAX, [RBP+StrideC]	;  StrideC
		MOV	[RBP+matrixC], RAX	;  matrixC
		INC	RCX
		CMP	RCX, [RBP+Ra]	;  Ra
		JL	DotProductSetup	;
	END SSEMul4BlockR;

	PROCEDURE SSEMul2BlockX( StrideA, StrideB, StrideC, Ca, Ra, CbFrom: SIZE; matrixA, matrixB, matrixC: ADDRESS;
													add: BOOLEAN );
	CODE {SYSTEM.AMD64, SYSTEM.SSE2}
		MOV	RCX, 0	;  counter FOR rows IN A-Ra
		DotProductSetup:
		MOV	RAX, 0	;  cols IN A
		MOV	RSI,  [RBP+matrixA]	;  matrixA
		MOV	RDI,  [RBP+matrixB]	;  matrixB
		MOV	RDX, [RBP+CbFrom]	;  CbFrom
		LEA	RDI, [RDI+RDX*8]
		XORPD	XMM2, XMM2
		MOV	RAX, 0	;
		MOV	AL, [RBP+add]	;
		CMP	AL, 0	;  add?
		JE	DotProductLoop	;
		MOV	RAX, [RBP+matrixC]	;  matrixC
		LEA	RAX, [RAX+RDX*8]	;  adjust POINTER horizontally TO correct batch OF 8
		MOVUPD	XMM2, [RAX]
		MOV	RAX, 0
		DotProductLoop:
		;  MOV RDX, [RSI+RAX*4]	;
		;  SHL RDX, 1	;
		;  CMP RDX, 0
		;  JE SparseEntryEscape
		MOVSD	XMM0, [RSI+RAX*8]
		SHUFPD	XMM0, XMM0, 0H
		MOVUPD	XMM1, [RDI]
		MULPD	XMM1, XMM0
		ADDPD	XMM2, XMM1
		SparseEntryEscape:
		ADD	RDI, [RBP+StrideB]	;  StrideB
		INC	RAX
		CMP	RAX, [RBP+Ca]	;  Ca
		JL	DotProductLoop ; end DotProductLoop
		MOV RAX	, [RBP+matrixC]	;  matrixC
		MOV	RDX, [RBP+CbFrom]	;  CbFrom
		LEA	RAX, [RAX+RDX*8]	;  adjust POINTER horizontally TO correct batch OF 8
		MOVUPD	[RAX], XMM2
		MOV	RAX,  [RBP+matrixA]	;  matrixA
		ADD	RAX, [RBP+StrideA]	;  StrideA
		MOV	 [RBP+matrixA], RAX	;  matrixA
		MOV	RAX, [RBP+matrixC]	;  matrixC
		ADD	RAX, [RBP+StrideC]	;  StrideC
		MOV	[RBP+matrixC], RAX	;  matrixC
		INC	RCX
		CMP	RCX, [RBP+Ra]	;  Ra
		JL	DotProductSetup	;
	END SSEMul2BlockX;



(******  blocking matrix multiplication with copy of data ******)

	PROCEDURE MagicBlockR( M, N, K: SIZE;
											    VAR L2BlockM, L2BlockN, L2BlockK: SIZE );
	BEGIN

		K := (K DIV L0BlockKR) * L0BlockKR;
		N := (N DIV L1BlockN) * L1BlockN;
		IF M = 0 THEN M := 1 END;
		IF N = 0 THEN N := 1 END;
		IF K = 0 THEN K := 1 END;

		L2BlockK :=
			K DIV ((K + L1MaxBlockKR - 1) DIV L1MaxBlockKR);
		(* Round up to next multiple of 16 *)
		L2BlockK := L2BlockK + (-L2BlockK) MOD 16;

		L2BlockN :=
			L2BlockSize DIV SIZEOF( REAL ) DIV
			(L2BlockK * (L2BARatio + 1));
		IF L2BlockN > N THEN L2BlockN := N
		ELSIF L2BlockN < 1 THEN L2BlockN := 1;
		END;

		L2BlockM :=
			(L2BlockSize DIV SIZEOF( REAL ) - L2BlockN * L2BlockK) DIV
						    L2BlockK;
		(* Round up to next multiple of 5 *)
		IF L2BlockM > M THEN L2BlockM := M
		ELSIF L2BlockM < 1 THEN L2BlockM := 1
		END;
		L2BlockN := L2BlockN + (-L2BlockN) MOD L1BlockN;

	END MagicBlockR;

	PROCEDURE MagicBlockX( M, N, K: SIZE;
											    VAR L2BlockM, L2BlockN, L2BlockK:SIZE );
	BEGIN
		K := (K DIV L0BlockKX) * L0BlockKX;
		N := (N DIV L1BlockN) * L1BlockN;
		IF M = 0 THEN M := 1 END;
		IF N = 0 THEN N := 1 END;
		IF K = 0 THEN K := 1 END;

		L2BlockK :=
			K DIV ((K + L1MaxBlockKX - 1) DIV L1MaxBlockKX);
		(* Round up to next multiple of 16 *)
		L2BlockK := L2BlockK + (-L2BlockK) MOD 16;

		L2BlockN :=
			L2BlockSize DIV SIZEOF( LONGREAL ) DIV
			(L2BlockK * (L2BARatio + 1));
		IF L2BlockN > N THEN L2BlockN := N END;

		L2BlockM :=
			(L2BlockSize DIV SIZEOF( LONGREAL ) - L2BlockN * L2BlockK) DIV
						    L2BlockK;
		(* Round up to next multiple of 5 *)
		IF L2BlockM > M THEN L2BlockM := M
		ELSIF L2BlockM < 1 THEN L2BlockM := 1
		END;
		L2BlockN := L2BlockN + (-L2BlockN) MOD L1BlockN;

	END MagicBlockX;

(*

	PROCEDURE L1Block1X( adrA, adrB, adrC, K: LONGINT );   (* condition: K MOD 4 = 0 *)
	VAR reg: ARRAY 8 OF ARRAY 2 OF LONGREAL;

		PROCEDURE null( i: LONGINT );
		BEGIN
			reg[i, 0] := 0;  reg[i, 1] := 0;
		END null;

		PROCEDURE get1( adr, i: LONGINT );
		BEGIN
			SYSTEM.GET( adr, reg[i, 0] );
			IF debug THEN KernelLog.String( "get 1: " );  KernelLog.Int( ENTIER( reg[i, 0] + 0.5 ), 5 );  KernelLog.Ln;  END;

		END get1;

		PROCEDURE get2( adr, i: LONGINT );
		BEGIN
			SYSTEM.GET( adr, reg[i, 0] );  SYSTEM.GET( adr + 8, reg[i, 1] );
			IF debug THEN
				KernelLog.String( "get 2: " );  KernelLog.Int( ENTIER( reg[i, 0] + 0.5 ), 5 );
				KernelLog.Int( ENTIER( reg[i, 1] + 0.5 ), 5 );  KernelLog.Ln;
			END;

		END get2;

		PROCEDURE mul2( i, j: LONGINT );
		BEGIN
			reg[i, 0] := reg[i, 0] * reg[j, 0];  reg[i, 1] := reg[i, 1] * reg[j, 1];
		END mul2;

		PROCEDURE add2( i, j: LONGINT );
		BEGIN
			reg[i, 0] := reg[i, 0] + reg[j, 0];  reg[i, 1] := reg[i, 1] + reg[j, 1];
		END add2;

		PROCEDURE put1( adr, i: LONGINT );
		BEGIN
			SYSTEM.PUT( adr, reg[i, 0] );
		END put1;

		PROCEDURE horadd( i: LONGINT );
		BEGIN
			reg[i, 0] := reg[i, 0] + reg[i, 1];
		END horadd;

	BEGIN
		IF debug THEN KernelLog.String( "L1Block1" );  KernelLog.Ln;  END;
		null( 2 );  get1( adrC, 2 );
		WHILE (K > 0) DO  (* padding guaranteed *)
			get2( adrA, 7 );  get2( adrB, 0 );  mul2( 0, 7 );  add2( 2, 0 );  INC( adrB, 16 );
			INC( adrA, 16 );  DEC( K, 2 );
		END;
		horadd( 2 );  put1( adrC, 2 );
	END L1Block1X;

	PROCEDURE L1Block5X( adrA, adrB, adrC, IncC, K: LONGINT );   (* condition: K MOD 4 = 0 *)
	VAR reg: ARRAY 8 OF ARRAY 2 OF LONGREAL;

		PROCEDURE null( i: LONGINT );
		BEGIN
			reg[i, 0] := 0;  reg[i, 1] := 0;
		END null;

		PROCEDURE get1( adr, i: LONGINT );
		BEGIN
			SYSTEM.GET( adr, reg[i, 0] );
			IF debug THEN KernelLog.String( "get 1: " );  KernelLog.Int( ENTIER( reg[i, 0] + 0.5 ), 5 );  KernelLog.Ln;  END;
		END get1;

		PROCEDURE get2( adr, i: LONGINT );
		BEGIN
			SYSTEM.GET( adr, reg[i, 0] );  SYSTEM.GET( adr + 8, reg[i, 1] );
			IF debug THEN
				KernelLog.String( "get 2: " );  KernelLog.Int( ENTIER( reg[i, 0] + 0.5 ), 5 );
				KernelLog.Int( ENTIER( reg[i, 1] + 0.5 ), 5 );  KernelLog.Ln;
			END;
		END get2;

		PROCEDURE mul2( i, j: LONGINT );
		BEGIN
			reg[i, 0] := reg[i, 0] * reg[j, 0];  reg[i, 1] := reg[i, 1] * reg[j, 1];
		END mul2;

		PROCEDURE add2( i, j: LONGINT );
		BEGIN
			reg[i, 0] := reg[i, 0] + reg[j, 0];  reg[i, 1] := reg[i, 1] + reg[j, 1];
		END add2;

		PROCEDURE put1( adr, i: LONGINT );
		BEGIN
			SYSTEM.PUT( adr, reg[i, 0] );
		END put1;

		PROCEDURE horadd( i: LONGINT );
		BEGIN
			reg[i, 0] := reg[i, 0] + reg[i, 1];
		END horadd;

	BEGIN
		IF debug THEN KernelLog.String( "L1Block5" );  KernelLog.Ln;  END;
		null( 2 );  null( 3 );  null( 4 );  null( 5 );  null( 6 );  get1( adrC, 2 );
		get1( adrC + IncC, 3 );  get1( adrC + 2 * IncC, 4 );  get1( adrC + 3 * IncC, 5 );
		get1( adrC + 4 * IncC, 6 );

		WHILE (K > 0) DO  (* padding guaranteed *)
			get2( adrA, 7 );  get2( adrB, 0 );  mul2( 0, 7 );  add2( 2, 0 );
			get2( adrB + 16, 0 );  mul2( 0, 7 );  add2( 3, 0 );  get2( adrB + 32, 0 );
			mul2( 0, 7 );  add2( 4, 0 );  get2( adrB + 48, 0 );  mul2( 0, 7 );
			add2( 5, 0 );  get2( adrB + 64, 0 );  mul2( 0, 7 );  add2( 6, 0 );  INC( adrB, 80 );
			INC( adrA, 16 );  DEC( K, 2 );
		END;
		horadd( 2 );  horadd( 3 );  horadd( 4 );  horadd( 5 );  horadd( 6 );
		put1( adrC, 2 );  put1( adrC + IncC, 3 );  put1( adrC + 2 * IncC, 4 );
		put1( adrC + 3 * IncC, 5 );  put1( adrC + 4 * IncC, 6 );
	END L1Block5X;

	PROCEDURE L1Block1R( adrA, adrB, adrC, K: LONGINT );   (* condition: K MOD 4 = 0 *)
	VAR reg: ARRAY 8 OF ARRAY 4 OF REAL;

		PROCEDURE null( i: LONGINT );
		BEGIN
			reg[i, 0] := 0;  reg[i, 1] := 0;  reg[i, 2] := 0;  reg[i, 3] := 0;
		END null;

		PROCEDURE get1( adr, i: LONGINT );
		BEGIN
			SYSTEM.GET( adr, reg[i, 0] );
			IF debug THEN KernelLog.String( "get 1: " );  KernelLog.Int( ENTIER( reg[i, 0] + 0.5 ), 5 );  KernelLog.Ln;  END;

		END get1;

		PROCEDURE get4( adr, i: LONGINT );
		BEGIN
			SYSTEM.GET( adr, reg[i, 0] );  SYSTEM.GET( adr + 4, reg[i, 1] );
			SYSTEM.GET( adr + 8, reg[i, 2] );  SYSTEM.GET( adr + 12, reg[i, 3] );
			IF debug THEN
				KernelLog.String( "get 4: " );  KernelLog.Int( ENTIER( reg[i, 0] + 0.5 ), 5 );
				KernelLog.Int( ENTIER( reg[i, 1] + 0.5 ), 5 );  KernelLog.Int( ENTIER( reg[i, 2] + 0.5 ), 5 );
				KernelLog.Int( ENTIER( reg[i, 3] + 0.5 ), 5 );  KernelLog.Ln;
			END;

		END get4;

		PROCEDURE mul4( i, j: LONGINT );
		BEGIN
			reg[i, 0] := reg[i, 0] * reg[j, 0];  reg[i, 1] := reg[i, 1] * reg[j, 1];
			reg[i, 2] := reg[i, 2] * reg[j, 2];  reg[i, 3] := reg[i, 3] * reg[j, 3];
		END mul4;

		PROCEDURE add4( i, j: LONGINT );
		BEGIN
			reg[i, 0] := reg[i, 0] + reg[j, 0];  reg[i, 1] := reg[i, 1] + reg[j, 1];
			reg[i, 2] := reg[i, 2] + reg[j, 2];  reg[i, 3] := reg[i, 3] + reg[j, 3];
		END add4;

		PROCEDURE put1( adr, i: LONGINT );
		BEGIN
			SYSTEM.PUT( adr, reg[i, 0] );
		END put1;

		PROCEDURE horadd( i: LONGINT );
		BEGIN
			reg[i, 0] := reg[i, 0] + reg[i, 1] + reg[i, 2] + reg[i, 3];
		END horadd;

	BEGIN
		IF debug THEN KernelLog.String( "L1Block1" );  KernelLog.Ln;  END;
		null( 2 );  get1( adrC, 2 );
		WHILE (K > 0) DO  (* padding guaranteed *)
			get4( adrA, 7 );  get4( adrB, 0 );  mul4( 0, 7 );  add4( 2, 0 );  INC( adrB, 16 );
			INC( adrA, 16 );  DEC( K, 4 );
		END;
		horadd( 2 );  put1( adrC, 2 );
	END L1Block1R;

	PROCEDURE L1Block5R( adrA, adrB, adrC, IncC, K: LONGINT );   (* condition: K MOD 4 = 0 *)
	VAR reg: ARRAY 8 OF ARRAY 4 OF REAL;

		PROCEDURE null( i: LONGINT );
		BEGIN
			reg[i, 0] := 0;  reg[i, 1] := 0;  reg[i, 2] := 0;  reg[i, 3] := 0;
		END null;

		PROCEDURE get1( adr, i: LONGINT );
		BEGIN
			SYSTEM.GET( adr, reg[i, 0] );
			IF debug THEN KernelLog.String( "get 1: " );  KernelLog.Int( ENTIER( reg[i, 0] + 0.5 ), 5 );  KernelLog.Ln;  END;
		END get1;

		PROCEDURE get4( adr, i: LONGINT );
		BEGIN
			SYSTEM.GET( adr, reg[i, 0] );  SYSTEM.GET( adr + 4, reg[i, 1] );
			SYSTEM.GET( adr + 8, reg[i, 2] );  SYSTEM.GET( adr + 12, reg[i, 3] );
			IF debug THEN
				KernelLog.String( "get 4: " );  KernelLog.Int( ENTIER( reg[i, 0] + 0.5 ), 5 );
				KernelLog.Int( ENTIER( reg[i, 1] + 0.5 ), 5 );  KernelLog.Int( ENTIER( reg[i, 2] + 0.5 ), 5 );
				KernelLog.Int( ENTIER( reg[i, 3] + 0.5 ), 5 );  KernelLog.Ln;
			END;
		END get4;

		PROCEDURE mul4( i, j: LONGINT );
		BEGIN
			reg[i, 0] := reg[i, 0] * reg[j, 0];  reg[i, 1] := reg[i, 1] * reg[j, 1];
			reg[i, 2] := reg[i, 2] * reg[j, 2];  reg[i, 3] := reg[i, 3] * reg[j, 3];
		END mul4;

		PROCEDURE add4( i, j: LONGINT );
		BEGIN
			reg[i, 0] := reg[i, 0] + reg[j, 0];  reg[i, 1] := reg[i, 1] + reg[j, 1];
			reg[i, 2] := reg[i, 2] + reg[j, 2];  reg[i, 3] := reg[i, 3] + reg[j, 3];
		END add4;

		PROCEDURE put1( adr, i: LONGINT );
		BEGIN
			SYSTEM.PUT( adr, reg[i, 0] );
		END put1;

		PROCEDURE horadd( i: LONGINT );
		BEGIN
			reg[i, 0] := reg[i, 0] + reg[i, 1] + reg[i, 2] + reg[i, 3];
		END horadd;

	BEGIN
		IF debug THEN KernelLog.String( "L1Block5" );  KernelLog.Ln;  END;
		null( 2 );  null( 3 );  null( 4 );  null( 5 );  null( 6 );  get1( adrC, 2 );
		get1( adrC + IncC, 3 );  get1( adrC + 2 * IncC, 4 );  get1( adrC + 3 * IncC, 5 );
		get1( adrC + 4 * IncC, 6 );

		WHILE (K > 0) DO  (* padding guaranteed *)
			get4( adrA, 7 );  get4( adrB, 0 );  mul4( 0, 7 );  add4( 2, 0 );
			get4( adrB + 16, 0 );  mul4( 0, 7 );  add4( 3, 0 );  get4( adrB + 32, 0 );
			mul4( 0, 7 );  add4( 4, 0 );  get4( adrB + 48, 0 );  mul4( 0, 7 );
			add4( 5, 0 );  get4( adrB + 64, 0 );  mul4( 0, 7 );  add4( 6, 0 );  INC( adrB, 80 );
			INC( adrA, 16 );  DEC( K, 4 );
		END;
		horadd( 2 );  horadd( 3 );  horadd( 4 );  horadd( 5 );  horadd( 6 );
		put1( adrC, 2 );  put1( adrC + IncC, 3 );  put1( adrC + 2 * IncC, 4 );
		put1( adrC + 3 * IncC, 5 );  put1( adrC + 4 * IncC, 6 );
	END L1Block5R;
*)


	PROCEDURE DispCR( adrM: ADDRESS;
									   inc, stride, M, N: SIZE );
	VAR i, j: SIZE; adr: ADDRESS;  val: REAL;
	BEGIN
		FOR i := 0 TO M - 1 DO
			adr := adrM + i * stride;
			FOR j := 0 TO N - 1 DO
				SYSTEM.GET( adr, val );
				KernelLog.Int( ENTIER( val + 0.5 ), 5 );  INC( adr, inc );
			END;
			KernelLog.Ln;
		END;
	END DispCR;

	PROCEDURE DispCX( adrM: ADDRESS;
									   inc, stride, M, N: SIZE );
	VAR i, j: SIZE; adr: ADDRESS;  val: LONGREAL;
	BEGIN
		FOR i := 0 TO M - 1 DO
			adr := adrM + i * stride;
			FOR j := 0 TO N - 1 DO
				SYSTEM.GET( adr, val );
				KernelLog.Int( ENTIER( val + 0.5 ), 5 );  INC( adr, inc );
			END;
			KernelLog.Ln;
		END;
	END DispCX;

	PROCEDURE L3BlockX( matrixA, matrixB, matrixC: ADDRESS;
										  M, N, K, incC, strideC, L2BlockM, L2BlockN, L2BlockK: SIZE );
	(*
				  K										N
			***			N					*****
		M ***		******	->   	*****   M
			***     K ******			   *****
			***		******			   *****

			A     *         B              ->       C
	*)
	VAR m, n, k, a1, b1: SIZE; adrA, adrB, adrC: ADDRESS;
		KAligned: SIZE;
	CONST Size = SIZEOF( LONGREAL );

		PROCEDURE L2Block( matrixA, matrixB, matrixC: ADDRESS; M, N, K: SIZE );
		(* M,N and K arbitrary ! *)
		VAR adrA, adrB, adrC: ADDRESS;  aadrA, aadrB: ADDRESS;
			m, k, KAligned: SIZE;
		BEGIN
			KAligned := Align2( K ) * 8;

			IF debug THEN ASSERT( M > 0 );  ASSERT( K > 0 );
			END;

			adrB := matrixB;
			WHILE (N >= L1BlockN) DO
				IF debug THEN KernelLog.String( "LoopL2N" );  KernelLog.Ln END;
				adrC := matrixC;  adrA := matrixA;  m := M;
				WHILE (m > 0) DO
					IF debug THEN KernelLog.String( "LoopL2M" );  KernelLog.Ln END;
					IF SSE THEN
						L1Block5XSSE( adrA, adrB, adrC, incC, K );   (* L1 Block *)
					ELSE
						aadrA := adrA;  aadrB := adrB;  k := K;
						WHILE (k > 0) DO
							L1Block1XA( aadrA, aadrB, adrC, 2 );
							L1Block1XA( aadrA, aadrB + 16, adrC + incC, 2 );
							L1Block1XA( aadrA, aadrB + 32, adrC + 2 * incC,
											    2 );
							L1Block1XA( aadrA, aadrB + 48, adrC + 3 * incC,
											    2 );
							L1Block1XA( aadrA, aadrB + 64, adrC + 4 * incC,
											    2 );
							DEC( k, 2 );  INC( aadrA, 16 );
							INC( aadrB, 16 * L1BlockN );
						END;
					END;
					IF debug THEN
						DispCX( matrixC, incC, strideC, M, N );
					END;
					INC( adrA, KAligned );  INC( adrC, strideC );
					DEC( m );
				END;
				INC( matrixC, L1BlockN * incC );
				INC( adrB, L1BlockN * KAligned );  DEC( N, L1BlockN );
			END;
			WHILE (N > 0) DO
				IF debug THEN KernelLog.String( "LoopL2N rest" );  KernelLog.Ln END;
				adrC := matrixC;  adrA := matrixA;  m := M;
				WHILE (m > 0) DO
					IF debug THEN KernelLog.String( "LoopL2M" );  KernelLog.Ln END;
					IF SSE THEN
						L1Block1XSSE( adrA, adrB, adrC, K );   (* L1 Block *)
					ELSE L1Block1XA( adrA, adrB, adrC, K );
					END;
					IF debug THEN
						DispCX( matrixC, incC, strideC, M, N );
					END;
					INC( adrA, KAligned );  INC( adrC, strideC );
					DEC( m );
				END;
				INC( matrixC, incC );  INC( adrB, KAligned );  DEC( N );
			END;
		END L2Block;

	BEGIN
		KAligned := Align2( K ) * 8;
		ASSERT( L2BlockK MOD 2 = 0 );
		IF SSE THEN ASSERT( L2BlockN MOD L1BlockN = 0 );  END;

		m := M;  n := N;  k := K;  a1 := matrixA;  adrA := matrixA;
		b1 := matrixB;  adrB := matrixB;  adrC := matrixC;

		WHILE (n >= L2BlockN) DO
			IF debug THEN KernelLog.String( "LoopL3N" );  KernelLog.Ln END;
			a1 := matrixA;  adrC := matrixC;  m := M;
			WHILE (m >= L2BlockM) DO
				IF debug THEN KernelLog.String( "LoopL3M" );  KernelLog.Ln END;
				adrA := a1;  adrB := b1;  k := K;
				(* core: do matching level 2 cache Blocks   *)
				WHILE (k >= L2BlockK) DO
					IF debug THEN KernelLog.String( "LoopL3K" );  KernelLog.Ln END;
					L2Block( adrA, adrB, adrC, L2BlockM, L2BlockN,
								  L2BlockK );
					INC( adrA, L2BlockK * L2BlockM * Size );
					INC( adrB, L2BlockK * L2BlockN * Size );   (* no padding required *)
					DEC( k, L2BlockK );
				END;
				(* core: do rest of k *)
				IF k > 0 THEN
					L2Block( adrA, adrB, adrC, L2BlockM, L2BlockN, k );
				END;
				INC( a1, KAligned * L2BlockM );
				INC( adrC, L2BlockM * strideC );  DEC( m, L2BlockM );
			END;
			IF m > 0 THEN
				(* clean up M *)
				adrA := a1;  adrB := b1;  k := K;
				WHILE (k >= L2BlockK) DO
					IF debug THEN KernelLog.String( "LoopL3K rest" );  KernelLog.Ln END;
					L2Block( adrA, adrB, adrC, m, L2BlockN, L2BlockK );
					INC( adrA, L2BlockK * Size * m );
					INC( adrB, L2BlockK * L2BlockN * Size );
					DEC( k, L2BlockK );
				END;
				IF debug THEN KernelLog.String( "LoopL3K rest k" );  KernelLog.Ln END;
				IF k > 0 THEN
					L2Block( adrA, adrB, adrC, m, L2BlockN, k );
				END;
			END;
			INC( b1, L2BlockN * KAligned );
			INC( matrixC, L2BlockN * incC );  DEC( n, L2BlockN );
		END;

		IF (n = 0) THEN RETURN
		END;

		a1 := matrixA;  adrC := matrixC;  m := M;
		WHILE (m >= L2BlockM) DO
			IF debug THEN KernelLog.String( "LoopL3M rest" );  KernelLog.Ln END;
			adrA := a1;  adrB := b1;  k := K;
			WHILE (k >= L2BlockK) DO
				IF debug THEN KernelLog.String( "LoopL3K rest" );  KernelLog.Ln END;
				L2Block( adrA, adrB, adrC, L2BlockM, n, L2BlockK );
				INC( adrA, L2BlockM * L2BlockK * Size );
				INC( adrB, L2BlockK * n * Size );  DEC( k, L2BlockK );
			END;
			IF k > 0 THEN
				L2Block( adrA, adrB, adrC, L2BlockM, n, k );
			END;
			INC( a1, L2BlockM * KAligned );
			INC( adrC, L2BlockM * strideC );  DEC( m, L2BlockM );
		END;

		IF (m = 0) THEN RETURN
		END;

		adrA := a1;  adrB := b1;  k := K;
		WHILE (k >= L2BlockK) DO
			IF debug THEN KernelLog.String( "LoopL3K rest" );  KernelLog.Ln END;
			L2Block( adrA, adrB, adrC, m, n, L2BlockK );
			INC( adrA, L2BlockK * m * Size );
			INC( adrB, L2BlockK * n * Size );  DEC( k, L2BlockK );
		END;

		IF k > 0 THEN L2Block( adrA, adrB, adrC, m, n, k );
		END;
	END L3BlockX;

	PROCEDURE L3BlockR( matrixA, matrixB, matrixC: ADDRESS;
										  M, N, K, incC, strideC, L2BlockM, L2BlockN, L2BlockK: SIZE );
	(*
				  K										N
			***			N					*****
		M ***		******	->   	*****   M
			***     K ******			   *****
			***		******			   *****

			A     *         B              ->       C
	*)
	VAR m, n, k, a1, b1: SIZE; adrA, adrB, adrC: ADDRESS;
		KAligned: SIZE;
	CONST Size = SIZEOF( REAL );

		PROCEDURE L2Block( matrixA, matrixB, matrixC: ADDRESS; M, N, K: SIZE );
		(* M,N and K arbitrary ! *)
		VAR adrA, adrB, adrC: ADDRESS;  aadrA, aadrB: ADDRESS;
			m, KAligned, k: SIZE;
		BEGIN
			KAligned := Align4( K ) * 4;

			IF debug THEN ASSERT( M > 0 );  ASSERT( K > 0 );
			END;

			adrB := matrixB;
			WHILE (N >= L1BlockN) DO
				IF debug THEN KernelLog.String( "LoopL2N" );  KernelLog.Ln END;
				adrC := matrixC;  adrA := matrixA;  m := M;
				WHILE (m > 0) DO
					IF debug THEN KernelLog.String( "LoopL2M" );  KernelLog.Ln END;
					IF SSE THEN
						L1Block5RSSE( adrA, adrB, adrC, incC, K );   (* L1 Block *)
					ELSE
						aadrA := adrA;  aadrB := adrB;  k := K;
						WHILE (k > 0) DO
							L1Block1RA( aadrA, aadrB, adrC, 4 );
							L1Block1RA( aadrA, aadrB + 16, adrC + incC, 4 );
							L1Block1RA( aadrA, aadrB + 32, adrC + 2 * incC,
												4 );
							L1Block1RA( aadrA, aadrB + 48, adrC + 3 * incC,
												4 );
							L1Block1RA( aadrA, aadrB + 64, adrC + 4 * incC,
												4 );
							DEC( k, 4 );  INC( aadrA, 16 );
							INC( aadrB, 16 * L1BlockN );
						END;
					END;
					IF debug THEN
						DispCR( matrixC, incC, strideC, M, N );
					END;
					INC( adrA, KAligned );  INC( adrC, strideC );
					DEC( m );
				END;
				INC( matrixC, L1BlockN * incC );
				INC( adrB, L1BlockN * KAligned );  DEC( N, L1BlockN );
			END;
			WHILE (N > 0) DO
				IF debug THEN KernelLog.String( "LoopL2N rest" );  KernelLog.Ln END;
				adrC := matrixC;  adrA := matrixA;  m := M;
				WHILE (m > 0) DO
					IF debug THEN KernelLog.String( "LoopL2M" );  KernelLog.Ln END;
					IF SSE THEN
						L1Block1RSSE( adrA, adrB, adrC, K );   (* L1 Block *)
					ELSE L1Block1RA( adrA, adrB, adrC, K );
					END;
					IF debug THEN
						DispCR( matrixC, incC, strideC, M, N );
					END;
					INC( adrA, KAligned );  INC( adrC, strideC );
					DEC( m );
				END;
				INC( matrixC, incC );  INC( adrB, KAligned );  DEC( N );
			END;
		END L2Block;

	BEGIN
		KAligned := Align4( K ) * 4;
		ASSERT( L2BlockK MOD 4 = 0 );
		IF SSE THEN ASSERT( L2BlockN MOD L1BlockN = 0 );  END;

		m := M;  n := N;  k := K;  a1 := matrixA;  adrA := matrixA;
		b1 := matrixB;  adrB := matrixB;  adrC := matrixC;

		WHILE (n >= L2BlockN) DO
			IF debug THEN KernelLog.String( "LoopL3N" );  KernelLog.Ln END;
			a1 := matrixA;  adrC := matrixC;  m := M;
			WHILE (m >= L2BlockM) DO
				IF debug THEN KernelLog.String( "LoopL3M" );  KernelLog.Ln END;
				adrA := a1;  adrB := b1;  k := K;
				(* core: do matching level 2 cache Blocks   *)
				WHILE (k >= L2BlockK) DO
					IF debug THEN KernelLog.String( "LoopL3K" );  KernelLog.Ln END;
					L2Block( adrA, adrB, adrC, L2BlockM, L2BlockN,
								  L2BlockK );
					INC( adrA, L2BlockK * L2BlockM * Size );
					INC( adrB, L2BlockK * L2BlockN * Size );   (* no padding required *)
					DEC( k, L2BlockK );
				END;
				(* core: do rest of k *)
				IF k > 0 THEN
					L2Block( adrA, adrB, adrC, L2BlockM, L2BlockN, k );
				END;
				INC( a1, KAligned * L2BlockM );
				INC( adrC, L2BlockM * strideC );  DEC( m, L2BlockM );
			END;
			IF m > 0 THEN
				(* clean up M *)
				adrA := a1;  adrB := b1;  k := K;
				WHILE (k >= L2BlockK) DO
					IF debug THEN KernelLog.String( "LoopL3K rest" );  KernelLog.Ln END;
					L2Block( adrA, adrB, adrC, m, L2BlockN, L2BlockK );
					INC( adrA, L2BlockK * Size * m );
					INC( adrB, L2BlockK * L2BlockN * Size );
					DEC( k, L2BlockK );
				END;
				IF debug THEN KernelLog.String( "LoopL3K rest k" );  KernelLog.Ln END;
				IF k > 0 THEN
					L2Block( adrA, adrB, adrC, m, L2BlockN, k );
				END;
			END;
			INC( b1, L2BlockN * KAligned );
			INC( matrixC, L2BlockN * incC );  DEC( n, L2BlockN );
		END;

		IF (n = 0) THEN RETURN
		END;

		a1 := matrixA;  adrC := matrixC;  m := M;
		WHILE (m >= L2BlockM) DO
			IF debug THEN KernelLog.String( "LoopL3M rest" );  KernelLog.Ln END;
			adrA := a1;  adrB := b1;  k := K;
			WHILE (k >= L2BlockK) DO
				IF debug THEN KernelLog.String( "LoopL3K rest" );  KernelLog.Ln END;
				L2Block( adrA, adrB, adrC, L2BlockM, n, L2BlockK );
				INC( adrA, L2BlockM * L2BlockK * Size );
				INC( adrB, L2BlockK * n * Size );  DEC( k, L2BlockK );
			END;
			IF k > 0 THEN
				L2Block( adrA, adrB, adrC, L2BlockM, n, k );
			END;
			INC( a1, L2BlockM * KAligned );
			INC( adrC, L2BlockM * strideC );  DEC( m, L2BlockM );
		END;

		IF (m = 0) THEN RETURN
		END;

		adrA := a1;  adrB := b1;  k := K;
		WHILE (k >= L2BlockK) DO
			IF debug THEN KernelLog.String( "LoopL3K rest" );  KernelLog.Ln END;
			L2Block( adrA, adrB, adrC, m, n, L2BlockK );
			INC( adrA, L2BlockK * m * Size );
			INC( adrB, L2BlockK * n * Size );  DEC( k, L2BlockK );
		END;

		IF k > 0 THEN L2Block( adrA, adrB, adrC, m, n, k );
		END;
	END L3BlockR;

	PROCEDURE Align( adr: ADDRESS;  align: SIZE ): ADDRESS;
	BEGIN
		RETURN adr + (-adr) MOD align;   (* 128 bit = 16 byte alignment *)
	END Align;

	PROCEDURE CopyAX( matrixA, dest: ADDRESS;
									    IncA, StrideA: SIZE;
									    K, M, L2BlockK, L2BlockM: SIZE );
	VAR m, k: SIZE; adrA: ADDRESS;  t: HUGEINT;

		PROCEDURE CopyMK( matrixA: ADDRESS; M, K: SIZE );
		VAR rest: SIZE;
		BEGIN
			IF debug THEN
				KernelLog.String( "CopyMK:" );  KernelLog.Int( M, 10 );  KernelLog.Int( K, 10 );
				KernelLog.Ln;
			END;
			rest := (-K) MOD 2;
			WHILE (M > 0) DO
				MovX( matrixA, dest, IncA, K );  INC( dest, K * 8 );
				IF rest # 0 THEN
					ZeroX( dest, rest );  INC( dest, 8 * rest );
				END;
				INC( matrixA, StrideA );  DEC( M );
			END;
		END CopyMK;

	BEGIN
		Tic( t );  m := M;
		WHILE (m >= L2BlockM) DO
			k := K;  adrA := matrixA;
			WHILE (k >= L2BlockK) DO
				CopyMK( adrA, L2BlockM, L2BlockK );
				INC( adrA, L2BlockK * IncA );  DEC( k, L2BlockK );
			END;
			IF k > 0 THEN CopyMK( adrA, L2BlockM, k );  END;
			INC( matrixA, L2BlockM * StrideA );  DEC( m, L2BlockM );
		END;
		adrA := matrixA;  k := K;
		WHILE (k >= L2BlockK) DO
			CopyMK( adrA, m, L2BlockK );
			INC( adrA, L2BlockK * IncA );  DEC( k, L2BlockK );
		END;
		IF k > 0 THEN CopyMK( adrA, m, k );  END;
		Toc( t, copyT );
	END CopyAX;

	PROCEDURE CopyAR( matrixA, dest: ADDRESS;
									    IncA, StrideA: SIZE;
									    K, M, L2BlockK, L2BlockM: SIZE );
	VAR m, k: SIZE; adrA: ADDRESS;  t: HUGEINT;

		PROCEDURE CopyMK( matrixA: ADDRESS; M, K: SIZE );
		VAR rest: SIZE;
		BEGIN
			rest := (-K) MOD 4;
			WHILE (M > 0) DO
				MovR( matrixA, dest, IncA, K );  INC( dest, K * 4 );
				IF rest # 0 THEN
					ZeroR( dest, rest );  INC( dest, 4 * rest );
				END;
				INC( matrixA, StrideA );  DEC( M );
			END;
		END CopyMK;

	BEGIN
		Tic( t );  m := M;
		WHILE (m >= L2BlockM) DO
			k := K;  adrA := matrixA;
			WHILE (k >= L2BlockK) DO
				CopyMK( adrA, L2BlockM, L2BlockK );
				INC( adrA, L2BlockK * IncA );  DEC( k, L2BlockK );
			END;
			IF k > 0 THEN CopyMK( adrA, L2BlockM, k );  END;
			INC( matrixA, L2BlockM * StrideA );  DEC( m, L2BlockM );
		END;
		adrA := matrixA;  k := K;
		WHILE (k >= L2BlockK) DO
			CopyMK( adrA, m, L2BlockK );
			INC( adrA, L2BlockK * IncA );  DEC( k, L2BlockK );
		END;
		IF k > 0 THEN CopyMK( adrA, m, k );  END;
		Toc( t, copyT );
	END CopyAR;

	PROCEDURE CopyBX( matrixB, dest: ADDRESS;
									    IncB, StrideB: SIZE;
									    N, K, L2BlockN, L2BlockK: SIZE );
	VAR n, k: SIZE;  adrB: ADDRESS;  t: HUGEINT;

		PROCEDURE Copy5x2k( matrixB: ADDRESS; k: SIZE );
		VAR i: SIZE; adrB: ADDRESS; rest: SIZE;
		BEGIN
			rest := (-k) MOD 2;
			WHILE (k >= 2) DO  (* store 5x4 Block in line *)
				adrB := matrixB;
				FOR i := 1 TO L1BlockN DO
					MovX( adrB, dest, StrideB, 2 );  INC( dest, 16 );
					INC( adrB, IncB );
				END;
				INC( matrixB, 2 * StrideB );  DEC( k, 2 );
			END;
			IF k > 0 THEN
				adrB := matrixB;
				FOR i := 1 TO L1BlockN DO
					MovX( adrB, dest, StrideB, k );  INC( dest, 8 * k );
					IF rest # 0 THEN
						ZeroX( dest, rest );  INC( dest, rest * 8 );
					END;
					INC( adrB, IncB );
				END;
			END;
		END Copy5x2k;

		PROCEDURE Copy1( matrixB: ADDRESS; K, N:SIZE );
		VAR n, rest: SIZE;
		BEGIN
			rest := (-K) MOD 2;
			IF debug THEN
				KernelLog.String( ">>Copy1" );  KernelLog.Int( K, 10 );  KernelLog.Int( N, 10 );  KernelLog.Ln;
			END;
			n := N;
			WHILE (n >= L1BlockN) DO  (* store Kx5 Blocks as one line *)
				Copy5x2k( matrixB, K );
				IF debug THEN ASSERT( dest MOD 16 = 0 );  END;
				INC( matrixB, L1BlockN * IncB );  DEC( n, L1BlockN );
			END;

			IF debug THEN KernelLog.String( "Copy1, n=" );  KernelLog.Int( n, 10 );  KernelLog.Ln;
			END;
			WHILE (n > 0) DO  (* store remaining rectangle in separate lines *)
				MovX( matrixB, dest, StrideB, K );  INC( dest, K * 8 );
				ZeroR( dest, rest );  INC( dest, rest * 8 );
				INC( matrixB, IncB );  DEC( n );
			END;
		END Copy1;

	BEGIN
		Tic( t );  ASSERT( L2BlockN MOD L1BlockN = 0 );
		ASSERT( L2BlockK MOD 2 = 0 );  n := N;
		WHILE (n >= L2BlockN) DO
			k := K;  adrB := matrixB;
			WHILE (k >= L2BlockK) DO
				Copy1( adrB, L2BlockK, L2BlockN );
				INC( adrB, L2BlockK * StrideB );  DEC( k, L2BlockK );
			END;
			IF k > 0 THEN Copy1( adrB, k, L2BlockN ) END;
			INC( matrixB, L2BlockN * IncB );  DEC( n, L2BlockN );
		END;

		IF (n = 0) THEN RETURN
		END;

		k := K;  adrB := matrixB;
		WHILE (k >= L2BlockK) DO
			Copy1( adrB, L2BlockK, n );
			INC( adrB, L2BlockK * StrideB );  DEC( k, L2BlockK );
		END;
		Copy1( adrB, k, n );  Toc( t, copyT );
	END CopyBX;

	PROCEDURE CopyBR( matrixB, dest: ADDRESS;
									    IncB, StrideB: SIZE;
									    N, K, L2BlockN, L2BlockK: SIZE );
	VAR n, k: SIZE;  adrB: ADDRESS;  t: HUGEINT;

		PROCEDURE Copy5x4k( matrixB: ADDRESS; k: SIZE );
		VAR i: SIZE;  adrB: ADDRESS;  rest, k4: SIZE;
		BEGIN
			k4 := k - k MOD 4;  rest := (-k) MOD 4;

			IF k4 > 0 THEN
				MovR5( matrixB, IncB, StrideB, dest, k4 );
				INC( matrixB, k4 * StrideB );  INC( dest, k4 * 80 DIV 4 );
				DEC( k, k4 );
			END;
			(*
			WHILE (k >= 4) DO  (* store 5x4 Block in line *)

				adrB := matrixB;


				FOR i := 1 TO L1BlockN DO
					MovR( adrB, dest, StrideB, 4 );  INC( dest, 16 );  INC( adrB, IncB );
				END;

				INC( matrixB, 4 * StrideB );  DEC( k, 4 );
			END;
			*)

			IF k > 0 THEN
				adrB := matrixB;
				FOR i := 1 TO L1BlockN DO
					MovR( adrB, dest, StrideB, k );  INC( dest, 4 * k );
					IF rest # 0 THEN
						ZeroR( dest, rest );  INC( dest, rest * 4 );
					END;
					INC( adrB, IncB );
				END;
			END;
		END Copy5x4k;

		PROCEDURE Copy1( matrixB: ADDRESS; K, N:SIZE );
		VAR n, rest: SIZE;
		BEGIN
			rest := (-K) MOD 4;
			IF debug THEN
				KernelLog.String( ">>Copy1" );  KernelLog.Int( K, 10 );  KernelLog.Int( N, 10 );  KernelLog.Ln;
			END;
			n := N;
			WHILE (n >= L1BlockN) DO  (* store Kx5 Blocks as one line *)
				Copy5x4k( matrixB, K );
				IF debug THEN ASSERT( dest MOD 16 = 0 );  END;
				INC( matrixB, L1BlockN * IncB );  DEC( n, L1BlockN );
			END;

			WHILE (n > 0) DO  (* store remaining rectangle in separate lines *)
				MovR( matrixB, dest, StrideB, K );  INC( dest, K * 4 );
				ZeroR( dest, rest );  INC( dest, rest * 4 );
				INC( matrixB, IncB );  DEC( n );
			END;
		END Copy1;

	BEGIN
		Tic( t );  ASSERT( L2BlockN MOD L1BlockN = 0 );
		ASSERT( L2BlockK MOD 4 = 0 );  n := N;
		WHILE (n >= L2BlockN) DO
			k := K;  adrB := matrixB;
			WHILE (k >= L2BlockK) DO
				Copy1( adrB, L2BlockK, L2BlockN );
				INC( adrB, L2BlockK * StrideB );  DEC( k, L2BlockK );
			END;
			IF k > 0 THEN Copy1( adrB, k, L2BlockN ) END;
			INC( matrixB, L2BlockN * IncB );  DEC( n, L2BlockN );
		END;

		IF (n = 0) THEN RETURN
		END;

		k := K;  adrB := matrixB;
		WHILE (k >= L2BlockK) DO
			Copy1( adrB, L2BlockK, n );
			INC( adrB, L2BlockK * StrideB );  DEC( k, L2BlockK );
		END;
		Copy1( adrB, k, n );  Toc( t, copyT );
	END CopyBR;

(*
	PROCEDURE FillMR( VAR A: ARRAY [ .. , .. ] OF REAL );
	VAR i, j: LONGINT;
	BEGIN
		FOR i := 0 TO LEN( A, 0 ) - 1 DO
			FOR j := 0 TO LEN( A, 1 ) - 1 DO
				A[i, j] := ran.Dice( 10 );
				IF debug THEN A[i, j] := 10 * i + j;  END;
			END;
		END;
	END FillMR;

	PROCEDURE DispMR( VAR A: ARRAY [ .. , .. ] OF REAL );
	VAR i, j: LONGINT;
	BEGIN
		FOR i := 0 TO LEN( A, 0 ) - 1 DO
			FOR j := 0 TO LEN( A, 1 ) - 1 DO KernelLog.Int( ENTIER( A[i, j] + 0.5 ), 5 );  END;
			KernelLog.Ln;
		END;
	END DispMR;

	PROCEDURE FillMX( VAR A: ARRAY [ .. , .. ] OF LONGREAL );
	VAR i, j: LONGINT;
	BEGIN
		FOR i := 0 TO LEN( A, 0 ) - 1 DO
			FOR j := 0 TO LEN( A, 1 ) - 1 DO
				A[i, j] := ran.Dice( 10 );
				IF debug THEN A[i, j] := 10 * i + j;  END;
			END;
		END;
	END FillMX;

	PROCEDURE DispMX( VAR A: ARRAY [ .. , .. ] OF LONGREAL );
	VAR i, j: LONGINT;
	BEGIN
		FOR i := 0 TO LEN( A, 0 ) - 1 DO
			FOR j := 0 TO LEN( A, 1 ) - 1 DO KernelLog.Int( ENTIER( A[i, j] + 0.5 ), 5 );  END;
			KernelLog.Ln;
		END;
	END DispMX;
	*)

	PROCEDURE Tic( VAR t: HUGEINT );
	BEGIN
		t := Machine.GetTimer();
	END Tic;

	PROCEDURE Toc( VAR t, addto: HUGEINT );
	BEGIN
		INC( addto, Machine.GetTimer() - t );  t := Machine.GetTimer();
	END Toc;

	PROCEDURE MultiplyX( A, B, C: ADDRESS;
			 M, N, K, L2BlockM, L2BlockN, L2BlockK:SIZE;
										  IncA, StrideA, IncB, StrideB, IncC, StrideC: SIZE;
										  add: BOOLEAN );
	VAR lenA, lenB: SIZE; adrA, adrB, adrC: ADDRESS;  m: SIZE;
		M1, M2, i: SIZE;  val: LONGREAL;  t: HUGEINT;
		inc: SIZE;
		obj: POINTER TO ARRAY OF MultiplyObjectX;
		cache: Cache;
	BEGIN
		NEW(obj,nrProcesses+1);
		lenA := M * Align2( K ) * 8;  lenB := N * Align2( K ) * 8;
		cache := cachePool.Acquire( lenA + lenB );
		adrA := cache.adr;  adrB := adrA + lenA;
		CopyAX( A, adrA, IncA, StrideA, K, M, L2BlockK, L2BlockM );
		CopyBX( B, adrB, IncB, StrideB, N, K, L2BlockN, L2BlockK );
		Tic( t );  m := M;  adrC := C;
		IF ~add THEN
			WHILE (m > 0) DO
				ZeroXI( adrC, IncC, N );  INC( adrC, StrideC );  DEC( m );
			END;
		END;
		Toc( t, zeroT );
		IF debug THEN
			KernelLog.String( "copy of A: " );  KernelLog.Ln;
			FOR i := 0 TO M * Align2( K ) - 1 DO
				SYSTEM.GET( adrA + i * 8, val );
				KernelLog.Int( ENTIER( val + 0.5 ), 5 );  KernelLog.Ln;
			END;
		END;
		IF debug THEN
			KernelLog.String( "copy of B: " );  KernelLog.Ln;
			FOR i := 0 TO N * Align2( K ) - 1 DO
				SYSTEM.GET( adrB + i * 8, val );
				KernelLog.Int( ENTIER( val + 0.5 ), 5 );  KernelLog.Ln;
			END;
		END;

		IF parallel & (M > L2BlockM) THEN
			inc := Align( M DIV nrProcesses, L2BlockM );  M1 := 0;
			i := 0;
			WHILE (M1 < M) DO
				M2 := M1 + inc;
				IF M2 > M THEN M2 := M END;
				NEW( obj[i], adrA + M1 * Align2( K ) * 8, adrB,
						  C + StrideC * M1, M2 - M1, N, K, IncC, StrideC,
						  L2BlockM, L2BlockN, L2BlockK );
				M1 := M2;  INC( i );
			END;
			WHILE (i > 0) DO DEC( i );  obj[i].Wait;  END;

		ELSE
			L3BlockX( adrA, adrB, C, M, N, K, IncC, StrideC, L2BlockM,
						    L2BlockN, L2BlockK );

		END;
		Toc( t, compT );  cachePool.Release( cache );
	END MultiplyX;

	PROCEDURE MultiplyR( A, B, C: ADDRESS;
				 M, N, K, L2BlockM, L2BlockN, L2BlockK: SIZE;
										  IncA, StrideA, IncB, StrideB, IncC, StrideC: SIZE;
										  add: BOOLEAN );
	VAR lenA, lenB: SIZE; adrA, adrB, adrC: ADDRESS;  m: SIZE;
		M1, M2, i: SIZE;  val: REAL;  inc: SIZE;
		obj: POINTER TO ARRAY OF MultiplyObjectR;
		t: HUGEINT;  cache: Cache;
	BEGIN
		NEW(obj,nrProcesses+1);
		lenA := M * Align4( K ) * 4;  lenB := N * Align4( K ) * 4;
		cache := cachePool.Acquire( lenA + lenB );
		adrA := cache.adr;  adrB := adrA + lenA;
		CopyAR( A, adrA, IncA, StrideA, K, M, L2BlockK, L2BlockM );
		CopyBR( B, adrB, IncB, StrideB, N, K, L2BlockN, L2BlockK );
		Tic( t );  m := M;  adrC := C;
		IF ~add THEN
			WHILE (m > 0) DO
				ZeroRI( adrC, IncC, N );  INC( adrC, StrideC );
				DEC( m );
			END;
		END;
		Toc( t, zeroT );
		IF debug THEN
			KernelLog.String( "copy of A: " );  KernelLog.Ln;
			FOR i := 0 TO M * Align4( K ) - 1 DO
				SYSTEM.GET( adrA + i * 4, val );
				KernelLog.Int( ENTIER( val + 0.5 ), 5 );  KernelLog.Ln;
			END;
		END;
		IF debug THEN
			KernelLog.String( "copy of B: " );  KernelLog.Ln;
			FOR i := 0 TO N * Align4( K ) - 1 DO
				SYSTEM.GET( adrB + i * 4, val );
				KernelLog.Int( ENTIER( val + 0.5 ), 5 );  KernelLog.Ln;
			END;
		END;
		IF parallel & (M > L2BlockM) THEN
			inc := Align( M DIV nrProcesses, L2BlockM );  M1 := 0;
			i := 0;
			WHILE (M1 < M) DO
				M2 := M1 + inc;
				IF M2 > M THEN M2 := M END;
				NEW( obj[i], adrA + M1 * Align4( K ) * 4, adrB,
						  C + StrideC * M1, M2 - M1, N, K, IncC, StrideC,
						  L2BlockM, L2BlockN, L2BlockK );
				M1 := M2;  INC( i );
			END;
			WHILE (i > 0) DO DEC( i );  obj[i].Wait;  END;

		ELSE
			L3BlockR( adrA, adrB, C, M, N, K, IncC, StrideC, L2BlockM,
							L2BlockN, L2BlockK );
		END;
		Toc( t, compT );  cachePool.Release( cache );
	END MultiplyR;

(*


	PROCEDURE DoTestX( M, N, K, L2BlockM, L2BlockN, L2BlockK: LONGINT;  check: BOOLEAN;  iter: LONGINT );
	VAR  (* A, B, C, D: ARRAY [ .. , .. ] OF REAL;  *)
		A, B, C, D: ARRAY [ .. , .. ] OF LONGREAL;
		p, q: ANY;  l1, l2: LONGINT;  adrA, adrB, len, lenA, lenB: LONGINT;
		matrixA, matrixB, matrixC: LONGINT;  i: LONGINT;  val: LONGREAL;  atime, time: LONGINT;
	BEGIN
		KernelLog.String( "LONGREAL" );  KernelLog.Ln;  KernelLog.String( "M=" );  KernelLog.Int( M, 0 );  KernelLog.Ln;
		KernelLog.String( "N=" );  KernelLog.Int( N, 0 );  KernelLog.Ln;  KernelLog.String( "K=" );  KernelLog.Int( K, 0 );
		KernelLog.Ln;  KernelLog.String( "L2BlockM=" );  KernelLog.Int( L2BlockM, 0 );  KernelLog.Ln;  KernelLog.String( "L2BlockN=" );
		KernelLog.Int( L2BlockN, 0 );  KernelLog.Ln;  KernelLog.String( "L2BlockK=" );  KernelLog.Int( L2BlockK, 0 );
		KernelLog.Ln;  NEW( A, M, K );  NEW( B, K, N );  NEW( C, M, N );  FillMX( A );  FillMX( B );

		IF debug THEN DispMX( A );  KernelLog.String( "*" );  KernelLog.Ln;  DispMX( B );
		END;

		atime := Input.Time();   (* C := 0;  *)
		WHILE (iter > 0) DO
			MultiplyX( ADDRESSOF( A[0, 0] ), ADDRESSOF( B[0, 0] ),
							  ADDRESSOF( C[0, 0] ), M, N, K, L2BlockM, L2BlockN, L2BlockK,
			(*
						    8,
						    LEN( A, 1 ) * 8, 8, LEN( B, 1 ) * 8, 8, LEN( C, 1 ) * 8
							*)

			SYSTEM.INCR( A, 1 ), SYSTEM.INCR( A, 0 ), SYSTEM.INCR( B, 1 ),
							  SYSTEM.INCR( B, 0 ), SYSTEM.INCR( C, 1 ), SYSTEM.INCR( C, 0 )

			);
			DEC( iter );
		END;
		atime := Input.Time() - atime;  KernelLog.String( "overall time: " );  KernelLog.Int( atime, 10 );  KernelLog.Ln;

		IF debug THEN
			DispMX( A );  KernelLog.String( " * " );  KernelLog.Ln;  DispMX( B );  KernelLog.String( " = " );
			KernelLog.Ln;  DispMX( C );  KernelLog.String( " ------------" );  KernelLog.Ln;
		END;

		IF check THEN
			(*
			NEW(D,M,N);
			MatMulAXAXNaiive(ADDRESSOF( A[0, 0] ), ADDRESSOF( B[0, 0] ),
							  ADDRESSOF( D[0, 0] ), M, N, K, SYSTEM.INCR( A, 1 ), SYSTEM.INCR( A, 0 ), SYSTEM.INCR( B, 1 ),
							  SYSTEM.INCR( B, 0 ), SYSTEM.INCR( D, 1 ), SYSTEM.INCR( D, 0 ));
				*)

			D := A * B;
			ASSERT ( ENTIER( D + 0.5 ) = ENTIER( C + 0.5 ) );
		END;

	END DoTestX;

	PROCEDURE DoTestR( M, N, K, L2BlockM, L2BlockN, L2BlockK: LONGINT;  check: BOOLEAN;  iter: LONGINT );
	VAR  (* A, B, C, D: ARRAY [ .. , .. ] OF REAL;  *)
		A, B, C, D: ARRAY [ .. , .. ] OF REAL;
		p, q: ANY;  l1, l2: LONGINT;  adrA, adrB, len, lenA, lenB: LONGINT;
		matrixA, matrixB, matrixC: LONGINT;  i: LONGINT;  val: REAL;  atime, time: LONGINT;
	BEGIN
		KernelLog.String( "REAL" );  KernelLog.Ln;  KernelLog.String( "M=" );  KernelLog.Int( M, 0 );  KernelLog.Ln;
		KernelLog.String( "N=" );  KernelLog.Int( N, 0 );  KernelLog.Ln;  KernelLog.String( "K=" );  KernelLog.Int( K, 0 );
		KernelLog.Ln;  KernelLog.String( "L2BlockM=" );  KernelLog.Int( L2BlockM, 0 );  KernelLog.Ln;  KernelLog.String( "L2BlockN=" );
		KernelLog.Int( L2BlockN, 0 );  KernelLog.Ln;  KernelLog.String( "L2BlockK=" );  KernelLog.Int( L2BlockK, 0 );
		KernelLog.Ln;  NEW( A, M, K );  NEW( B, K, N );  NEW( C, M, N );  FillMR( A );  FillMR( B );

		IF debug THEN DispMR( A );  KernelLog.String( "*" );  KernelLog.Ln;  DispMR( B );
		END;

		atime := Input.Time();   (* C := 0;  *)
		FOR i := 1 TO iter DO
			MultiplyR( ADDRESSOF( A[0, 0] ), ADDRESSOF( B[0, 0] ),
							  ADDRESSOF( C[0, 0] ), M, N, K, L2BlockM, L2BlockN, L2BlockK,
			(* 4,
						    LEN( A, 1 ) * 4, 4, LEN( B, 1 ) * 4, 4, LEN( C, 1 ) * 4 *)


			SYSTEM.INCR( A, 1 ), SYSTEM.INCR( A, 0 ), SYSTEM.INCR( B, 1 ),
							  SYSTEM.INCR( B, 0 ), SYSTEM.INCR( C, 1 ), SYSTEM.INCR( C, 0 )

			);
		END;
		atime := Input.Time() - atime;  KernelLog.String( "overall time: " );  KernelLog.Int( atime, 10 );  KernelLog.Ln;

		IF debug THEN
			DispMR( A );  KernelLog.String( " * " );  KernelLog.Ln;  DispMR( B );  KernelLog.String( " = " );
			KernelLog.Ln;  DispMR( C );  KernelLog.String( " ------------" );  KernelLog.Ln;
		END;

		IF check THEN
			(*
			NEW(D,M,N);
			MatMulARARNaiive(ADDRESSOF( A[0, 0] ), ADDRESSOF( B[0, 0] ),
							  ADDRESSOF( D[0, 0] ), M, N, K, SYSTEM.INCR( A, 1 ), SYSTEM.INCR( A, 0 ), SYSTEM.INCR( B, 1 ),
							  SYSTEM.INCR( B, 0 ), SYSTEM.INCR( D, 1 ), SYSTEM.INCR( D, 0 ));
			*)
			D := A * B;
			ASSERT ( ENTIER( D + 0.5 ) = ENTIER( C + 0.5 ) );
		END;

	END DoTestR;

	PROCEDURE RandTestR*;
	VAR iter, i, time: LONGINT;
		MinM, MaxM, MinN, MaxN, MinK, MaxK, M, N, K, BM, BN, BK: LONGINT;

		PROCEDURE Ran( Min, Max: LONGINT ): LONGINT;
		BEGIN
			IF Min = Max THEN RETURN Min
			ELSE RETURN ran.Dice( Max - Min ) + Min
			END;
		END Ran;

	BEGIN
		In.Open();  In.LongInt( iter );

		In.LongInt( MinM );  In.LongInt( MaxM );  In.LongInt( MinN );
		In.LongInt( MaxN );  In.LongInt( MinK );  In.LongInt( MaxK );

		FOR i := 1 TO iter DO KernelLog.Int( i, 10 );  KernelLog.Ln;  DEC( iter );

			M := Ran( MinM, MaxM );  N := Ran( MinN, MaxN );
			K := Ran( MinK, MaxK );
			IF N < 5 THEN N := 5 END;
			IF K < 4 THEN K := 4 END;
			BM := ran.Dice( M ) + 1;  BN := ran.Dice( N ) + 1;  BK := ran.Dice( K ) + 1;
			BN := Align( BN, 5 );
			IF BN > N THEN DEC( BN, 5 ) END;
			BK := Align( BK, 4 );
			IF BK > K THEN DEC( BK, 4 ) END;

			DoTestR( M, N, K, BM, BN, BK, TRUE , 1 );
		END;

	END RandTestR;

	PROCEDURE RandTestX*;
	VAR iter, i, time: LONGINT;
		MinM, MaxM, MinN, MaxN, MinK, MaxK, M, N, K, BM, BN, BK: LONGINT;

		PROCEDURE Ran( Min, Max: LONGINT ): LONGINT;
		BEGIN
			IF Min = Max THEN RETURN Min
			ELSE RETURN ran.Dice( Max - Min ) + Min
			END;
		END Ran;

	BEGIN
		In.Open();  In.LongInt( iter );

		In.LongInt( MinM );  In.LongInt( MaxM );  In.LongInt( MinN );
		In.LongInt( MaxN );  In.LongInt( MinK );  In.LongInt( MaxK );

		FOR i := 1 TO iter DO KernelLog.Int( i, 10 );  KernelLog.Ln;  DEC( iter );

			M := Ran( MinM, MaxM );  N := Ran( MinN, MaxN );
			K := Ran( MinK, MaxK );
			IF N < 5 THEN N := 5 END;
			IF K < 4 THEN K := 4 END;
			BM := ran.Dice( M ) + 1;  BN := ran.Dice( N ) + 1;  BK := ran.Dice( K ) + 1;
			BN := Align( BN, 5 );
			IF BN > N THEN DEC( BN, 5 ) END;
			BK := Align( BK, 4 );
			IF BK > K THEN DEC( BK, 4 ) END;

			DoTestX( M, N, K, BM, BN, BK, TRUE , 1 );
		END;

	END RandTestX;
	*)

	(*
	PROCEDURE Times*;
	VAR all: HUGEINT;
	BEGIN
		all := allocT + copyT + zeroT + compT;  KernelLog.String( "alloc=" );
		KernelLog.LongRealFix( allocT / 1000000, 0, 20 );  KernelLog.String( "[" );
		KernelLog.Int( ENTIER( 100 * allocT / all + 0.5 ), 5 );  KernelLog.String( "%]" );
		KernelLog.Ln;  KernelLog.String( "copy=" );
		KernelLog.LongRealFix( copyT / 1000000, 0, 20 );  KernelLog.String( "[" );
		KernelLog.Int( ENTIER( 100 * copyT / all + 0.5 ), 5 );  KernelLog.String( "%]" );
		KernelLog.Ln;  KernelLog.String( "zero=" );
		KernelLog.LongRealFix( zeroT / 1000000, 0, 20 );  KernelLog.String( "[" );
		KernelLog.Int( ENTIER( 100 * zeroT / all + 0.5 ), 5 );  KernelLog.String( "%]" );
		KernelLog.Ln;  KernelLog.String( "comp=" );
		KernelLog.LongRealFix( compT / 1000000, 0, 20 );  KernelLog.String( "[" );
		KernelLog.Int( ENTIER( 100 * compT / all + 0.5 ), 5 );  KernelLog.String( "%]" );
		KernelLog.Ln;
	END Times;
	*)
	(*

	PROCEDURE TestRMM*;
	VAR M, N, K, L2BlockM, L2BlockN, L2BlockK: LONGINT;  matrixA, matrixB, matrixC: LONGINT;
		check, iter: LONGINT;
	BEGIN
		In.Open;  In.LongInt( M );  In.LongInt( N );  In.LongInt( K );
		In.LongInt( L2BlockM );  In.LongInt( L2BlockN );  In.LongInt( L2BlockK );
		In.LongInt( iter );  In.LongInt( check );

		IF L2BlockM = 0 THEN
			MagicBlockR( M DIV nrProcesses, N, K, L2BlockM, L2BlockN, L2BlockK );
		END;
		DoTestR( M, N, K, L2BlockM, L2BlockN, L2BlockK, check = 1, iter );  Times();
	END TestRMM;

	PROCEDURE TestXMM*;
	VAR M, N, K, L2BlockM, L2BlockN, L2BlockK: LONGINT;  matrixA, matrixB, matrixC: LONGINT;
		iter, check: LONGINT;
	BEGIN
		In.Open;  In.LongInt( M );  In.LongInt( N );  In.LongInt( K );
		In.LongInt( L2BlockM );  In.LongInt( L2BlockN );  In.LongInt( L2BlockK );
		In.LongInt( iter );  In.LongInt( check );
		IF L2BlockM = 0 THEN
			MagicBlockX( M DIV nrProcesses, N, K, L2BlockM, L2BlockN, L2BlockK );
		END;
		DoTestX( M, N, K, L2BlockM, L2BlockN, L2BlockK, check = 1, iter );  Times();
	END TestXMM;
	*)
(******  matrix multiplication using fast scalar product ******)

	PROCEDURE MatMulAXAXLoopA( ladr, radr, dadr: ADDRESS; linc, rinc, len: SIZE );
	BEGIN
		SYSTEM.PUT( dadr, 0.0D0 );   (* initialization of scalar product to 0 *)
		SPAXAXLoopA( ladr, radr, dadr, linc, rinc, len );   (* apply scalar product *)
	END MatMulAXAXLoopA;

	PROCEDURE MatMulAXAXLoopSSE( ladr, radr, dadr: ADDRESS; linc, rinc, len: SIZE );
	BEGIN
		SYSTEM.PUT( dadr, 0.0D0 );   (* initialization of scalar product to 0 *)
		SPAXAXLoopSSE( ladr, radr, dadr, linc, rinc, len );   (* apply scalar product *)
	END MatMulAXAXLoopSSE;

	PROCEDURE MatMulARARLoopA( ladr, radr, dadr: ADDRESS; linc, rinc, len: SIZE );
	BEGIN
		SYSTEM.PUT( dadr, 0.0E0 );   (* initialization of scalar product to 0 *)
		SPARARLoopA( ladr, radr, dadr, linc, rinc, len );   (* apply scalar product *)
	END MatMulARARLoopA;

	PROCEDURE MatMulARARLoopSSE( ladr, radr, dadr: ADDRESS; linc, rinc, len: SIZE );
	BEGIN
		SYSTEM.PUT( dadr, 0.0E0 );   (* initialization of scalar product to 0 *)
		SPARARLoopSSE( ladr, radr, dadr, linc, rinc, len );   (* apply scalar product *)
	END MatMulARARLoopSSE;

	PROCEDURE MatMulIncAXAXLoopA( ladr, radr, dadr: ADDRESS; linc, rinc, len: SIZE );
	BEGIN
		SPAXAXLoopA( ladr, radr, dadr, linc, rinc, len );   (* apply scalar product *)
	END MatMulIncAXAXLoopA;

	PROCEDURE MatMulIncAXAXLoopSSE( ladr, radr, dadr: ADDRESS; linc, rinc, len: SIZE );
	BEGIN
		SPAXAXLoopSSE( ladr, radr, dadr, linc, rinc, len );   (* apply scalar product *)
	END MatMulIncAXAXLoopSSE;

	PROCEDURE MatMulIncARARLoopA( ladr, radr, dadr: ADDRESS; linc, rinc, len: SIZE );
	BEGIN
		SPARARLoopA( ladr, radr, dadr, linc, rinc, len );   (* apply scalar product *)
	END MatMulIncARARLoopA;

	PROCEDURE MatMulIncARARLoopSSE( ladr, radr, dadr: ADDRESS; linc, rinc, len: SIZE );
	BEGIN
		SPARARLoopSSE( ladr, radr, dadr, linc, rinc, len );   (* apply scalar product *)
	END MatMulIncARARLoopSSE;



(****** matrix multiplication over rows with transposition of B *)

	PROCEDURE MatMulHBlockR( MatrixA, MatrixB, MatrixC: ADDRESS;
	  (*inc=4*) Stride, IncC, StrideC, RowsA, RowsB, Cols: SIZE;
												    add: BOOLEAN );
	VAR fromA, toA, fromB, toB: SIZE; BlockSize: SIZE;
		(*
		computation of C[i,j] = Sum{k=0..Cols-1} A[i,k]*B[j,k], i.e. A*B`
	*)

		PROCEDURE Block( fromA, toA, fromB, toB: SIZE );
		VAR i, j: SIZE;  adrA, adrB, adrC: ADDRESS;
		BEGIN
			FOR i := fromA TO toA - 1 DO
				adrA := MatrixA + i * Stride;
				FOR j := fromB TO toB - 1 DO
					adrB := MatrixB + j * Stride;
					adrC := MatrixC + i * StrideC + j * IncC;
					AlignedSPRSSE( adrA, adrB, adrC, Cols, add );
				END;
			END;
		END Block;

	BEGIN
		IF cBlockSize = 0 THEN
			BlockSize := L2CacheSize DIV Stride DIV 4;
		ELSE BlockSize := cBlockSize;
		END;
		lastUsedBlockSize := BlockSize;

		fromA := 0;
		REPEAT
			toA := fromA + BlockSize;
			IF toA > RowsA THEN toA := RowsA END;
			fromB := 0;
			REPEAT
				toB := fromB + BlockSize;
				IF toB > RowsB THEN toB := RowsB END;
				Block( fromA, toA, fromB, toB );  fromB := toB;
			UNTIL toB = RowsB;
			fromA := toA;
		UNTIL toA = RowsA;

	END MatMulHBlockR;

	PROCEDURE MatMulHBlockX( MatrixA, MatrixB, MatrixC: ADDRESS;
		  (*inc=4*) Stride, IncC, StrideC, RowsA, RowsB, Cols: SIZE;
												    add: BOOLEAN );
	VAR fromA, toA, fromB, toB: SIZE; BlockSize: SIZE;
		(*
		computation of C[i,j] = Sum{k=0..Cols-1} A[i,k]*B[j,k], i.e. A*B`
	*)
		PROCEDURE Block( fromA, toA, fromB, toB: SIZE );
		VAR adrA, adrB, adrC: ADDRESS; i, j: SIZE;
		BEGIN
			FOR i := fromA TO toA - 1 DO
				adrA := MatrixA + i * Stride;
				FOR j := fromB TO toB - 1 DO
					adrB := MatrixB + j * Stride;
					adrC := MatrixC + i * StrideC + j * IncC;
					AlignedSPXSSE( adrA, adrB, adrC, Cols, add );
				END;
			END;
		END Block;

	BEGIN
		IF cBlockSize = 0 THEN
			BlockSize := L2CacheSize DIV Stride DIV 8;
		ELSE BlockSize := cBlockSize;
		END;
		lastUsedBlockSize := BlockSize;

		fromA := 0;
		REPEAT
			toA := fromA + BlockSize;
			IF toA > RowsA THEN toA := RowsA END;
			fromB := 0;
			REPEAT
				toB := fromB + BlockSize;
				IF toB > RowsB THEN toB := RowsB END;
				Block( fromA, toA, fromB, toB );  fromB := toB;
			UNTIL toB = RowsB;
			fromA := toA;
		UNTIL toA = RowsA;

	END MatMulHBlockX;

	PROCEDURE CopyDataR( src, dest: ADDRESS; incSrc, strideSrc, incDest, strideDest, rows, cols:SIZE );   (*! optimize *)
	VAR i: SIZE;  t: HUGEINT;
	BEGIN
		Tic( t );
		FOR i := 0 TO rows - 1 DO
			Copy4( src, dest, incSrc, incDest, cols );
			INC( src, strideSrc );  INC( dest, strideDest );
		END;
		Toc( t, copyT );
	END CopyDataR;

	PROCEDURE CopyDataX( src, dest: ADDRESS; incSrc, strideSrc, incDest, strideDest, rows, cols:SIZE );   (*! optimize *)
	VAR i: SIZE;  t: HUGEINT;
	BEGIN
		Tic( t );
		FOR i := 0 TO rows - 1 DO
			Copy8( src, dest, incSrc, incDest, cols );
			INC( src, strideSrc );  INC( dest, strideDest );
		END;
		Toc( t, copyT );
	END CopyDataX;

	PROCEDURE MatMulARARTransposed( matrixA, matrixB, matrixC: ADDRESS;
		 IncA, StrideA, IncB, StrideB, IncC, StrideC, RowsA, ColsA, RowsB, ColsB: SIZE;
																  add: BOOLEAN ): BOOLEAN;
	VAR stride: SIZE; adrB, adrC: ADDRESS;
		proc: POINTER TO ARRAY OF MatMulHObjR;
		from, to0, i: SIZE;  cacheA, cacheB: Cache;
		t: HUGEINT;

	BEGIN
		NEW(proc,nrProcesses);
		ASSERT( ColsA = RowsB );

		(* allocate 128 bit = 16 byte aligned matrix *)
		stride := Align( ColsA * SIZEOF( REAL ), 16 );

		IF (IncA # SIZEOF( REAL )) OR (StrideA # stride) OR
			(matrixA MOD 16 # 0) THEN
			cacheA := cachePool.Acquire( stride * RowsA );
			CopyDataR( matrixA, cacheA.adr, IncA, StrideA,
							   SIZEOF( REAL ), stride, RowsA, ColsA );   (* copy to array *)
			matrixA := cacheA.adr;
		ELSE cacheA := NIL;
		END;

		IF (StrideB # SIZEOF( REAL )) OR (IncB # stride) OR
			(matrixB MOD 16 # 0) THEN
			cacheB := cachePool.Acquire( stride * ColsB );
			CopyDataR( matrixB, cacheB.adr, StrideB, IncB,
							   SIZEOF( REAL ), stride, ColsB, RowsB );   (* copy to transposed array *)
			matrixB := cacheB.adr;
		ELSE cacheB := NIL;
		END;
		Tic( t );
		(*! needs decision rule if to split by rows or columns *)
		IF nrProcesses > 1 THEN
			from := 0;
			FOR i := 0 TO nrProcesses - 1 DO
			(*
				to := RowsA * (i + 1) DIV nrProcesses;  adrA := matrixA + from * stride;
				adrC := matrixC + from * StrideC;
				*)
				to0 := ColsB * (i + 1) DIV nrProcesses;   (*! move to rows ? *)
				adrB := matrixB + from * stride;
				adrC := matrixC + from * IncC;
				NEW( proc[i], matrixA, adrB, adrC, stride, IncC, StrideC,
						  RowsA, to0 - from, RowsB, add );
				from := to0;
			END;
			FOR i := 0 TO nrProcesses - 1 DO proc[i].Wait();  END;
		ELSE
			MatMulHBlockR( matrixA, matrixB, matrixC, stride, IncC,
									  StrideC, RowsA, ColsB, RowsB, add );
		END;
		Toc( t, compT );  cachePool.Release( cacheA );
		cachePool.Release( cacheB );  RETURN TRUE;
	END MatMulARARTransposed;

	PROCEDURE MatMulAXAXTransposed( matrixA, matrixB, matrixC: ADDRESS;
		 IncA, StrideA, IncB, StrideB, IncC, StrideC, RowsA, ColsA, RowsB, ColsB: SIZE;
																  add: BOOLEAN ): BOOLEAN;
	VAR stride: SIZE; adrB, adrC: ADDRESS;
		proc: POINTER TO ARRAY OF MatMulHObjX;
		from, to0, i: SIZE;  cacheA, cacheB: Cache;
		t: HUGEINT;
	BEGIN
		NEW(proc,nrProcesses);
		ASSERT( ColsA = RowsB );

		stride := Align( ColsA * SIZEOF( LONGREAL ), 16 );

		IF (IncA # SIZEOF( LONGREAL )) OR (StrideA # stride) OR
			(matrixA MOD 16 # 0) THEN
			cacheA := cachePool.Acquire( stride * RowsA );
			CopyDataX( matrixA, cacheA.adr, IncA, StrideA,
							  SIZEOF( LONGREAL ), stride, RowsA, ColsA );   (* copy to array *)
			matrixA := cacheA.adr;
		ELSE cacheA := NIL;
		END;

		IF (StrideB # SIZEOF( LONGREAL )) OR (IncB # stride) OR
			(matrixB MOD 16 # 0) THEN
			cacheB := cachePool.Acquire( stride * ColsB );
			CopyDataX( matrixB, cacheB.adr, StrideB, IncB,
							  SIZEOF( LONGREAL ), stride, ColsB, RowsB );   (* copy to transposed array *)
			matrixB := cacheB.adr;
		ELSE cacheB := NIL;
		END;

		Tic( t );

		IF nrProcesses > 1 THEN
			from := 0;
			FOR i := 0 TO nrProcesses - 1 DO
				to0 := ColsB * (i + 1) DIV nrProcesses;   (*! move to rows ? *)
				adrB := matrixB + from * stride;
				adrC := matrixC + from * IncC;
				NEW( proc[i], matrixA, adrB, adrC, stride, IncC, StrideC,
						  RowsA, to0 - from, RowsB, add );
				from := to0;
			END;
			FOR i := 0 TO nrProcesses - 1 DO proc[i].Wait();  END;
		ELSE
			MatMulHBlockX( matrixA, matrixB, matrixC, stride, IncC,
									 StrideC, RowsA, ColsB, RowsB, add );
		END;
		Toc( t, compT );  cachePool.Release( cacheA );
		cachePool.Release( cacheB );  RETURN TRUE;
	END MatMulAXAXTransposed;





(******  strided matrix multiplication with restrictions to increments ******)

	PROCEDURE MatMulARARSSEStride( matrixA, matrixB, matrixC: ADDRESS;
		 IncA, StrideA, IncB, StrideB, IncC, StrideC, RowsA, ColsA, RowsB, ColsB: SIZE;
															    add: BOOLEAN ): BOOLEAN;
	VAR sum: REAL;  CbFrom, i, j, k: SIZE;  valA, valB: REAL;
		adrA, adrB, adrC: ADDRESS;
		cacheA, cacheB, cacheC: Cache;
		matrixCO, StrideCO, IncCO: SIZE;  t: HUGEINT;
		(*VAR fromA, toA: LONGINT;  *)
	BEGIN
		IF (IncA # SIZEOF( REAL )) THEN
			cacheA :=
				cachePool.Acquire( RowsA * ColsA * SIZEOF( REAL ) );
			CopyDataR( matrixA, cacheA.adr, IncA, StrideA,
							   SIZEOF( REAL ), SIZEOF( REAL ) * ColsA, RowsA,
							   ColsA );
			matrixA := cacheA.adr;  IncA := SIZEOF( REAL );
			StrideA := SIZEOF( REAL ) * ColsA;
		END;
		IF (IncB # SIZEOF( REAL )) THEN
			cacheB :=
				cachePool.Acquire( RowsB * ColsB * SIZEOF( REAL ) );
			CopyDataR( matrixB, cacheB.adr, IncB, StrideB,
							   SIZEOF( REAL ), SIZEOF( REAL ) * ColsB, RowsB,
							   ColsB );
			matrixB := cacheB.adr;  IncB := SIZEOF( REAL );
			StrideB := SIZEOF( REAL ) * ColsB;
		END;
		IF (IncC # SIZEOF( REAL )) THEN
			cacheC :=
				cachePool.Acquire( RowsA * ColsB * SIZEOF( REAL ) );
			CopyDataR( matrixC, cacheC.adr, IncC, StrideC,
							   SIZEOF( REAL ), SIZEOF( REAL ) * ColsB, RowsA,
							   ColsB );
			matrixCO := matrixC;  StrideCO := StrideC;
			IncCO := IncC;  matrixC := cacheC.adr;
			IncC := SIZEOF( REAL );  StrideC := SIZEOF( REAL ) * ColsB;
		END;

		Tic( t );

		CbFrom := 0;
		IF ColsB >= 24 THEN
			SSEMul24BlockR( CbFrom, StrideA, StrideB, StrideC,
										ColsA, RowsA, ColsB, RowsB, matrixA,
										matrixB, matrixC, add );
		END;
		IF ColsB - CbFrom >= 16 THEN
			SSEMul16BlockR( StrideA, StrideB, StrideC, ColsA, RowsA,
										CbFrom, matrixA, matrixB, matrixC, add );
			INC( CbFrom, 16 );
		END;
		IF ColsB - CbFrom >= 8 THEN
			SSEMul8BlockR( StrideA, StrideB, StrideC, ColsA, RowsA,
									   CbFrom, matrixA, matrixB, matrixC, add );
			INC( CbFrom, 8 );
		END;
		IF ColsB - CbFrom >= 4 THEN
			SSEMul4BlockR( StrideA, StrideB, StrideC, ColsA, RowsA,
									   CbFrom, matrixA, matrixB, matrixC, add );
			INC( CbFrom, 4 );
		END;

		IF ColsB - CbFrom > 0 THEN
			(* do it in Oberon *)
			FOR i := 0 TO RowsA - 1 DO
				adrC := matrixC + i * StrideC + CbFrom * IncC;
				FOR j := CbFrom TO ColsB - 1 DO
					adrA := matrixA + i * StrideA;
					adrB := matrixB + j * IncB;

					IF add THEN SYSTEM.GET( adrC, sum )
					ELSE sum := 0
					END;
					FOR k := 0 TO RowsB - 1 DO
						SYSTEM.GET( adrA, valA );
						SYSTEM.GET( adrB, valB );
						sum := sum +  (* A[i, k] * B[k, j] *) valA * valB;
						INC( adrA, IncA );  INC( adrB, StrideB );
					END;
					SYSTEM.PUT( adrC, sum );  INC( adrC, IncC );
					(* C[i, j] := sum;  *)
				END;
			END;
		END;
		Toc( t, compT );

		IF cacheC # NIL THEN
			CopyDataR( matrixC, matrixCO, IncC, StrideC, IncCO,
							   StrideCO, RowsA, ColsB );
		END;

		cachePool.Release( cacheA );
		cachePool.Release( cacheB );
		cachePool.Release( cacheC );

		RETURN TRUE;
	END MatMulARARSSEStride;

	PROCEDURE MatMulAXAXSSEStride( matrixA, matrixB, matrixC: ADDRESS;
		 IncA, StrideA, IncB, StrideB, IncC, StrideC, RowsA, ColsA, RowsB, ColsB: SIZE;
															    add: BOOLEAN ): BOOLEAN;
	VAR sum: LONGREAL;  CbFrom, i, j, k: SIZE;
		valA, valB: LONGREAL;  adrA, adrB, adrC: ADDRESS;
		cacheA, cacheB, cacheC: Cache;
		matrixCO, StrideCO, IncCO:SIZE;  t: HUGEINT;
	BEGIN
		IF (IncA # SIZEOF( LONGREAL )) THEN
			cacheA :=
				cachePool.Acquire( RowsA * ColsA * SIZEOF( LONGREAL ) );
			CopyDataX( matrixA, cacheA.adr, IncA, StrideA,
							  SIZEOF( LONGREAL ),
							  SIZEOF( LONGREAL ) * ColsA, RowsA, ColsA );
			matrixA := cacheA.adr;
			StrideA := SIZEOF( LONGREAL ) * ColsA;
			IncA := SIZEOF( LONGREAL );
		END;
		IF (IncB # SIZEOF( LONGREAL )) THEN
			cacheB :=
				cachePool.Acquire( RowsB * ColsB * SIZEOF( LONGREAL ) );
			CopyDataX( matrixB, cacheB.adr, IncB, StrideB,
							  SIZEOF( LONGREAL ),
							  SIZEOF( LONGREAL ) * ColsB, RowsB, ColsB );
			matrixB := cacheB.adr;
			StrideB := SIZEOF( LONGREAL ) * ColsB;
			IncB := SIZEOF( LONGREAL );
		END;
		IF (IncC # SIZEOF( LONGREAL )) THEN
			cacheC :=
				cachePool.Acquire( RowsA * ColsB * SIZEOF( LONGREAL ) );
			CopyDataX( matrixC, cacheC.adr, IncC, StrideC,
							  SIZEOF( LONGREAL ),
							  SIZEOF( LONGREAL ) * ColsB, RowsA, ColsB );
			matrixCO := matrixC;  StrideCO := StrideC;
			IncCO := IncC;  StrideC := SIZEOF( LONGREAL ) * ColsB;
			IncC := SIZEOF( LONGREAL );  matrixC := cacheC.adr;
		END;

		Tic( t );

		CbFrom := 0;
		IF ColsB >= 12 THEN
			SSEMul12BlockX( CbFrom, StrideA, StrideB, StrideC,
									    ColsA, RowsA, ColsB, RowsB, matrixA,
									    matrixB, matrixC, add );
		END;
		IF ColsB - CbFrom >= 8 THEN
			SSEMul8BlockX( StrideA, StrideB, StrideC, ColsA, RowsA,
									  CbFrom, matrixA, matrixB, matrixC, add );
			INC( CbFrom, 8 );
		END;
		IF ColsB - CbFrom >= 4 THEN
			SSEMul4BlockX( StrideA, StrideB, StrideC, ColsA, RowsA,
									  CbFrom, matrixA, matrixB, matrixC, add );
			INC( CbFrom, 4 );
		END;
		IF ColsB - CbFrom >= 2 THEN
			SSEMul2BlockX( StrideA, StrideB, StrideC, ColsA, RowsA,
									  CbFrom, matrixA, matrixB, matrixC, add );
			INC( CbFrom, 2 );
		END;

		IF ColsB - CbFrom > 0 THEN
			(* do it in Oberon *)
			FOR i := 0 TO RowsA - 1 DO
				adrC := matrixC + i * StrideC + CbFrom * IncC;
				FOR j := CbFrom TO ColsB - 1 DO
					adrA := matrixA + i * StrideA;
					adrB := matrixB + j * IncB;

					IF add THEN SYSTEM.GET( adrC, sum )
					ELSE sum := 0
					END;
					FOR k := 0 TO RowsB - 1 DO
						SYSTEM.GET( adrA, valA );
						SYSTEM.GET( adrB, valB );
						sum := sum +  (* A[i, k] * B[k, j] *) valA * valB;
						INC( adrA, IncA );  INC( adrB, StrideB );
					END;
					SYSTEM.PUT( adrC, sum );  INC( adrC, IncC );
					(* C[i, j] := sum;  *)
				END;
			END;
		END;

		Toc( t, compT );

		IF cacheC # NIL THEN
			CopyDataX( matrixC, matrixCO, IncC, StrideC, IncCO,
							  StrideCO, RowsA, ColsB );
		END;

		cachePool.Release( cacheA );
		cachePool.Release( cacheB );
		cachePool.Release( cacheC );

		RETURN TRUE;
	END MatMulAXAXSSEStride;


(******  naiive Oberon matrix multiplication ******)

	PROCEDURE MatMulARARNaiive( matrixA, matrixB, matrixC: ADDRESS;
		 IncA, StrideA, IncB, StrideB, IncC, StrideC, M, N, K: SIZE;
														  add: BOOLEAN );
	(*
		A is M x K  matrix, M=rows (A); K=cols(A);
		B is K x N matrix;  K=rows(B); N = cols(B);
		C is M x N matrix; M=rows(C); N=cols(C);
	*)
	VAR adrA, adrB, innerB, adrC: ADDRESS;  i, j, k: SIZE;
		val1, val2, sum: REAL;  t: HUGEINT;
	BEGIN
		Tic( t );
		FOR i := 1 TO M DO
			adrC := matrixC;  adrB := matrixB;
			FOR j := 1 TO N DO
				adrA := matrixA;  innerB := adrB;
				IF add THEN SYSTEM.GET( adrC, sum ) ELSE sum := 0 END;
				FOR k := 1 TO K DO
					SYSTEM.GET( adrA, val1 );
					SYSTEM.GET( innerB, val2 );
					sum := sum + val1 * val2;  INC( adrA, IncA );
					INC( innerB, StrideB );
				END;
				SYSTEM.PUT( adrC, sum );  INC( adrB, IncB );
				INC( adrC, IncC );
			END;
			INC( matrixA, StrideA );  INC( matrixC, StrideC );
		END;
		Toc( t, compT );
	END MatMulARARNaiive;

	PROCEDURE MatMulAXAXNaiive( matrixA, matrixB, matrixC: ADDRESS;
		IncA, StrideA, IncB, StrideB, IncC, StrideC, M, N, K: SIZE;
														  add: BOOLEAN );
	(*
		A is M x K  matrix, M=rows (A); K=cols(A);
		B is K x N matrix;  K=rows(B); N = cols(B);
		C is M x N matrix; M=rows(C); N=cols(C);
	*)
	VAR adrA, adrB, innerB, adrC:  ADDRESS; i, j, k: SIZE;
		val1, val2, sum: LONGREAL;  t: HUGEINT;
	BEGIN
		Tic( t );
		FOR i := 1 TO M DO
			adrC := matrixC;  adrB := matrixB;
			FOR j := 1 TO N DO
				adrA := matrixA;  innerB := adrB;
				IF add THEN SYSTEM.GET( adrC, sum ) ELSE sum := 0 END;
				FOR k := 1 TO K DO
					SYSTEM.GET( adrA, val1 );
					SYSTEM.GET( innerB, val2 );
					sum := sum + val1 * val2;  INC( adrA, IncA );
					INC( innerB, StrideB );
				END;
				SYSTEM.PUT( adrC, sum );  INC( adrB, IncB );
				INC( adrC, IncC );
			END;
			INC( matrixA, StrideA );  INC( matrixC, StrideC );
		END;
		Toc( t, compT );
	END MatMulAXAXNaiive;


(*
	PROCEDURE Toggle( VAR A, B: LONGINT );
	VAR temp: LONGINT;
	BEGIN
		temp := A;  A := B;  B := temp;
	END Toggle;

	PROCEDURE Transpose( VAR matrixA, matrixB, matrixC, IncA, StrideA, IncB, StrideB, IncC, StrideC, M, N, K: LONGINT );
	(*
		prepare computation of C=A*B via C = (B` * A`)`
	*)
	BEGIN
		Toggle( matrixA, matrixB );  Toggle( IncA, StrideB );  Toggle( StrideA, IncB );
		Toggle( IncC, StrideC );  Toggle( M, N );
	END Transpose;
*)


	(*
	*)

	PROCEDURE BestMethod( M, N, K: SIZE ): LONGINT;
	BEGIN
		IF M = 1 THEN
			IF N < 32 THEN RETURN cMatMulScalarProduct
			ELSIF N < 256 THEN
				IF K < 256 THEN RETURN cMatMulScalarProduct
				ELSE RETURN cMatMulStride
				END;
			ELSE RETURN cMatMulStride
			END;
		ELSIF N = 1 THEN
			IF (M > 1024) & (K > 1024) THEN
				RETURN cMatMulTransposed
			ELSE RETURN cMatMulScalarProduct
			END;
		ELSIF K = 1 THEN
			IF N < 32 THEN
				IF M < 256 THEN RETURN cMatMulNaive
				ELSE RETURN cMatMulStride
				END;
			ELSIF N < 256 THEN
				IF M < 32 THEN RETURN cMatMulNaive
				ELSE RETURN cMatMulStride
				END;
			ELSE RETURN cMatMulStride
			END;
		ELSIF M < 32 THEN
			IF N < 32 THEN RETURN cMatMulScalarProduct
			ELSIF N < 256 THEN
				IF K < 32 THEN RETURN cMatMulScalarProduct
				ELSE RETURN cMatMulStride
				END;
			ELSE RETURN cMatMulStride
			END;
		ELSIF M < 256 THEN
			IF N < 32 THEN
				IF K < 32 THEN RETURN cMatMulScalarProduct
				ELSE RETURN cMatMulStride
				END;
			ELSE
				IF K < 256 THEN RETURN cMatMulStride
				ELSE RETURN cMatMulBlocked
				END;
			END;
		ELSE
			IF N < 32 THEN RETURN cMatMulStride ELSE
				IF K < 256 THEN RETURN cMatMulStride
				ELSE RETURN cMatMulBlocked
				END;
			END;
		END;
		RETURN cMatMulStride;
	END BestMethod;

	(*
		    (N)		             (K)       	       (N)
	   	 CCCCCC           	AAAAA      		BBBBB
		 CCCCCC           	AAAAA           	BBBBB
	(M) CCCCCC =    (M) 	AAAAA *   (K) 	BBBBB
		 CCCCCC          	AAAAA          	BBBBB
		 CCCCCC           	AAAAA           	BBBBB
	*)

	PROCEDURE MatMulR( matrixA, matrixB, matrixC: ADDRESS;
		 IncA, StrideA, IncB, StrideB, IncC, StrideC, RowsA, ColsA, RowsB, ColsB: SIZE ): BOOLEAN;
	(*! heuristics for choice of different methods needs improvement *)
	(*! transpose if superior*)
	(*! provide special variant for small [up to 4x4] matrices *)
	VAR M, N, K: SIZE;
	BEGIN
		ASSERT( ColsA = RowsB );

		M := RowsA;  N := ColsB;  K := ColsA;
		CASE BestMethod( M, N, K ) OF
		| cMatMulScalarProduct:
				RETURN FALSE;
		| cMatMulNaive:
				RETURN MatMulRNaive( matrixA, matrixB, matrixC, IncA,
													 StrideA, IncB, StrideB, IncC,
													 StrideC, RowsA, ColsA, RowsB,
													 ColsB );
		| cMatMulTransposed:
				RETURN MatMulARARTransposed( matrixA, matrixB,
																	 matrixC, IncA,
																	 StrideA, IncB,
																	 StrideB, IncC,
																	 StrideC, RowsA,
																	 ColsA, RowsB,
																	 ColsB, FALSE );
		| cMatMulStride:
				RETURN MatMulARARSSEStride( matrixA, matrixB,
																   matrixC, IncA, StrideA,
																   IncB, StrideB, IncC,
																   StrideC, RowsA,
																   ColsA, RowsB, ColsB,
																   FALSE );

		| cMatMulBlocked:
				RETURN MatMulARARBlocked( matrixA, matrixB,
															    matrixC, IncA, StrideA,
															    IncB, StrideB, IncC,
															    StrideC, RowsA, ColsA,
															    RowsB, ColsB, FALSE );
		ELSE
			RETURN FALSE  (* use scalar product for each row and column *)
		END;
	END MatMulR;

	PROCEDURE MatMulX( matrixA, matrixB, matrixC: ADDRESS; 
		IncA, StrideA, IncB, StrideB, IncC, StrideC, RowsA, ColsA, RowsB, ColsB: SIZE ): BOOLEAN;
	VAR M, N, K: SIZE;
	BEGIN
		ASSERT( ColsA = RowsB );  M := RowsA;  N := ColsB;
		K := ColsA;
		(*
		KernelLog.String("MatMulX, M,N,K = "); KernelLog.Int(M,10); KernelLog.Int(N,10); KernelLog.Int(K,10); KernelLog.Ln;
		KernelLog.String("Method= "); KernelLog.Int( BestMethod(M,N,K),10); KernelLog.Ln;
		*)
		CASE BestMethod( M, N, K ) OF
		| cMatMulScalarProduct:
				RETURN FALSE;
		| cMatMulNaive:
				RETURN MatMulXNaive( matrixA, matrixB, matrixC, IncA,
													 StrideA, IncB, StrideB, IncC,
													 StrideC, RowsA, ColsA, RowsB,
													 ColsB );
		| cMatMulTransposed:
				RETURN MatMulAXAXTransposed( matrixA, matrixB,
																    matrixC, IncA,
																    StrideA, IncB, StrideB,
																    IncC, StrideC, RowsA,
																    ColsA, RowsB, ColsB,
																    FALSE );
		| cMatMulStride:
				RETURN MatMulAXAXSSEStride( matrixA, matrixB,
																  matrixC, IncA, StrideA,
																  IncB, StrideB, IncC,
																  StrideC, RowsA, ColsA,
																  RowsB, ColsB,
																  FALSE );

		| cMatMulBlocked:
				RETURN MatMulAXAXBlocked( matrixA, matrixB,
															   matrixC, IncA, StrideA,
															   IncB, StrideB, IncC,
															   StrideC, RowsA, ColsA,
															   RowsB, ColsB, FALSE );
		ELSE
			RETURN FALSE  (* use scalar product for each row and column *)
		END;
	END MatMulX;

	PROCEDURE MatMulIncR( matrixA, matrixB, matrixC: ADDRESS;
		 IncA, StrideA, IncB, StrideB, IncC, StrideC, RowsA, ColsA, RowsB, ColsB: SIZE ): BOOLEAN;
	(*! heuristics for choice of different methods needs improvement *)
	(*! transpose if superior*)
	(*! provide special variant for small [up to 4x4] matrices *)
	VAR M, N, K: SIZE;
	BEGIN
		ASSERT( ColsA = RowsB );  M := RowsA;  N := ColsB;
		K := ColsA;
		CASE BestMethod( M, N, K ) OF
		| cMatMulScalarProduct:
				RETURN FALSE;
		| cMatMulNaive:
				RETURN MatMulIncRNaive( matrixA, matrixB, matrixC,
														 IncA, StrideA, IncB, StrideB,
														 IncC, StrideC, RowsA, ColsA,
														 RowsB, ColsB );
		| cMatMulTransposed:
				RETURN MatMulARARTransposed( matrixA, matrixB,
																	 matrixC, IncA,
																	 StrideA, IncB,
																	 StrideB, IncC,
																	 StrideC, RowsA,
																	 ColsA, RowsB,
																	 ColsB, TRUE );
		| cMatMulStride:
				RETURN MatMulARARSSEStride( matrixA, matrixB,
																   matrixC, IncA, StrideA,
																   IncB, StrideB, IncC,
																   StrideC, RowsA,
																   ColsA, RowsB, ColsB,
																   TRUE );

		| cMatMulBlocked:
				RETURN MatMulARARBlocked( matrixA, matrixB,
															    matrixC, IncA, StrideA,
															    IncB, StrideB, IncC,
															    StrideC, RowsA, ColsA,
															    RowsB, ColsB, TRUE );
		ELSE
			RETURN FALSE  (* use scalar product for each row and column *)
		END;
	END MatMulIncR;

	PROCEDURE MatMulIncX( matrixA, matrixB, matrixC: ADDRESS;
		 IncA, StrideA, IncB, StrideB, IncC, StrideC, RowsA, ColsA, RowsB, ColsB: SIZE ): BOOLEAN;
	VAR M, N, K: SIZE;
	BEGIN
		ASSERT( ColsA = RowsB );  M := RowsA;  N := ColsB;
		K := ColsA;
		CASE BestMethod( M, N, K ) OF
		| cMatMulScalarProduct:
				RETURN FALSE;
		| cMatMulNaive:
				RETURN MatMulIncXNaive( matrixA, matrixB, matrixC,
														 IncA, StrideA, IncB, StrideB,
														 IncC, StrideC, RowsA, ColsA,
														 RowsB, ColsB );
		| cMatMulTransposed:
				RETURN MatMulAXAXTransposed( matrixA, matrixB,
																    matrixC, IncA,
																    StrideA, IncB, StrideB,
																    IncC, StrideC, RowsA,
																    ColsA, RowsB, ColsB,
																    TRUE );
		| cMatMulStride:
				RETURN MatMulAXAXSSEStride( matrixA, matrixB,
																  matrixC, IncA, StrideA,
																  IncB, StrideB, IncC,
																  StrideC, RowsA, ColsA,
																  RowsB, ColsB, TRUE );

		| cMatMulBlocked:
				RETURN MatMulAXAXBlocked( matrixA, matrixB,
															   matrixC, IncA, StrideA,
															   IncB, StrideB, IncC,
															   StrideC, RowsA, ColsA,
															   RowsB, ColsB, TRUE );
		ELSE
			RETURN FALSE  (* use scalar product for each row and column *)
		END;
	END MatMulIncX;

	PROCEDURE MatMulARARBlocked( matrixA, matrixB, matrixC: ADDRESS; 
		IncA, StrideA, IncB, StrideB, IncC, StrideC, RowsA, ColsA, RowsB, ColsB: SIZE;
															 add: BOOLEAN ): BOOLEAN;
	VAR M, N, K, L2M, L2N, L2K: SIZE;
	BEGIN
		ASSERT( ColsA = RowsB );  M := RowsA;  N := ColsB;
		K := ColsA;  MagicBlockR( M, N, K, L2M, L2N, L2K );
		(*
		MatMulARARNaiive( matrixA, matrixB, matrixC, IncA, StrideA, IncB, StrideB,
										   IncC, StrideC, RowsA, ColsB, ColsA );
		*)
		MultiplyR( matrixA, matrixB, matrixC, RowsA, ColsB, ColsA,
					    L2M, L2N, L2K, IncA, StrideA, IncB, StrideB, IncC,
					    StrideC, add );

		RETURN TRUE;
	END MatMulARARBlocked;

	PROCEDURE MatMulAXAXBlocked( matrixA, matrixB, matrixC: ADDRESS;
		 IncA, StrideA, IncB, StrideB, IncC, StrideC, RowsA, ColsA, RowsB, ColsB: SIZE;
															 add: BOOLEAN ): BOOLEAN;
	VAR M, N, K, L2M, L2N, L2K: SIZE;
	BEGIN
		ASSERT( ColsA = RowsB );  M := RowsA;  N := ColsB;
		K := ColsA;  MagicBlockX( M, N, K, L2M, L2N, L2K );

		(*
		MatMulARARNaiive( matrixA, matrixB, matrixC, IncA, StrideA, IncB, StrideB,
										   IncC, StrideC, RowsA, ColsB, ColsA );
		*)

		MultiplyX( matrixA, matrixB, matrixC, RowsA, ColsB, ColsA,
					   L2M, L2N, L2K, IncA, StrideA, IncB, StrideB, IncC,
					   StrideC, add );

		RETURN TRUE;
	END MatMulAXAXBlocked;

	PROCEDURE MatMulRNaive( matrixA, matrixB, matrixC: ADDRESS;
		 IncA, StrideA, IncB, StrideB, IncC, StrideC, RowsA, ColsA, RowsB, ColsB: SIZE ): BOOLEAN;
	BEGIN
		MatMulARARNaiive( matrixA, matrixB, matrixC, IncA, StrideA,
									   IncB, StrideB, IncC, StrideC, RowsA,
									   ColsB, ColsA, FALSE );
		RETURN TRUE;
	END MatMulRNaive;

	PROCEDURE MatMulXNaive( matrixA, matrixB, matrixC: ADDRESS;
	 IncA, StrideA, IncB, StrideB, IncC, StrideC, RowsA, ColsA, RowsB, ColsB: SIZE ): BOOLEAN;
	BEGIN
		MatMulAXAXNaiive( matrixA, matrixB, matrixC, IncA, StrideA,
									  IncB, StrideB, IncC, StrideC, RowsA,
									  ColsB, ColsA, FALSE );
		RETURN TRUE;
	END MatMulXNaive;

	PROCEDURE MatMulIncRNaive( matrixA, matrixB, matrixC: ADDRESS;
	 IncA, StrideA, IncB, StrideB, IncC, StrideC, RowsA, ColsA, RowsB, ColsB: SIZE ): BOOLEAN;
	BEGIN
		MatMulARARNaiive( matrixA, matrixB, matrixC, IncA, StrideA,
									   IncB, StrideB, IncC, StrideC, RowsA,
									   ColsB, ColsA, TRUE );
		RETURN TRUE;
	END MatMulIncRNaive;

	PROCEDURE MatMulIncXNaive( matrixA, matrixB, matrixC: ADDRESS;
		 IncA, StrideA, IncB, StrideB, IncC, StrideC, RowsA, ColsA, RowsB, ColsB: SIZE ): BOOLEAN;
	BEGIN
		MatMulAXAXNaiive( matrixA, matrixB, matrixC, IncA, StrideA,
									  IncB, StrideB, IncC, StrideC, RowsA,
									  ColsB, ColsA, TRUE );
		RETURN TRUE;
	END MatMulIncXNaive;

	PROCEDURE MatMulXTransposed( matrixA, matrixB, matrixC: ADDRESS;
	 IncA, StrideA, IncB, StrideB, IncC, StrideC, RowsA, ColsA, RowsB, ColsB: SIZE ): BOOLEAN;
	BEGIN
		RETURN MatMulAXAXTransposed( matrixA, matrixB, matrixC,
														    IncA, StrideA, IncB,
														    StrideB, IncC, StrideC,
														    RowsA, ColsA, RowsB,
														    ColsB, FALSE );
	END MatMulXTransposed;

	PROCEDURE MatMulIncXTransposed( matrixA, matrixB, matrixC: ADDRESS;
	 IncA, StrideA, IncB, StrideB, IncC, StrideC, RowsA, ColsA, RowsB, ColsB: SIZE ): BOOLEAN;
	BEGIN
		RETURN MatMulAXAXTransposed( matrixA, matrixB, matrixC,
														    IncA, StrideA, IncB,
														    StrideB, IncC, StrideC,
														    RowsA, ColsA, RowsB,
														    ColsB, TRUE )
	END MatMulIncXTransposed;

	PROCEDURE MatMulRTransposed( matrixA, matrixB, matrixC: ADDRESS;
	 IncA, StrideA, IncB, StrideB, IncC, StrideC, RowsA, ColsA, RowsB, ColsB: SIZE ): BOOLEAN;
	BEGIN
		RETURN MatMulARARTransposed( matrixA, matrixB, matrixC,
															 IncA, StrideA, IncB,
															 StrideB, IncC, StrideC,
															 RowsA, ColsA, RowsB,
															 ColsB, FALSE );
	END MatMulRTransposed;

	PROCEDURE MatMulIncRTransposed( matrixA, matrixB, matrixC: ADDRESS;
	 IncA, StrideA, IncB, StrideB, IncC, StrideC, RowsA, ColsA, RowsB, ColsB: SIZE ): BOOLEAN;
	BEGIN
		RETURN MatMulARARTransposed( matrixA, matrixB, matrixC,
															 IncA, StrideA, IncB,
															 StrideB, IncC, StrideC,
															 RowsA, ColsA, RowsB,
															 ColsB, TRUE )
	END MatMulIncRTransposed;

	PROCEDURE MatMulXSSEStride( matrixA, matrixB, matrixC: ADDRESS; 
		IncA, StrideA, IncB, StrideB, IncC, StrideC, RowsA, ColsA, RowsB, ColsB: SIZE ): BOOLEAN;
	BEGIN
		RETURN MatMulAXAXSSEStride( matrixA, matrixB, matrixC,
														  IncA, StrideA, IncB, StrideB,
														  IncC, StrideC, RowsA,
														  ColsA, RowsB, ColsB,
														  FALSE );
	END MatMulXSSEStride;

	PROCEDURE MatMulIncXSSEStride( matrixA, matrixB, matrixC: ADDRESS;
	 IncA, StrideA, IncB, StrideB, IncC, StrideC, RowsA, ColsA, RowsB, ColsB: SIZE ): BOOLEAN;
	BEGIN
		RETURN MatMulAXAXSSEStride( matrixA, matrixB, matrixC,
														  IncA, StrideA, IncB, StrideB,
														  IncC, StrideC, RowsA,
														  ColsA, RowsB, ColsB,
														  TRUE );
	END MatMulIncXSSEStride;

	PROCEDURE MatMulRSSEStride( matrixA, matrixB, matrixC: ADDRESS;
		 IncA, StrideA, IncB, StrideB, IncC, StrideC, RowsA, ColsA, RowsB, ColsB: SIZE ): BOOLEAN;
	BEGIN
		RETURN MatMulARARSSEStride( matrixA, matrixB, matrixC,
														   IncA, StrideA, IncB, StrideB,
														   IncC, StrideC, RowsA,
														   ColsA, RowsB, ColsB,
														   FALSE );
	END MatMulRSSEStride;

	PROCEDURE MatMulIncRSSEStride( matrixA, matrixB, matrixC: ADDRESS;
		IncA, StrideA, IncB, StrideB, IncC, StrideC, RowsA, ColsA, RowsB, ColsB: SIZE ): BOOLEAN;
	BEGIN
		RETURN MatMulARARSSEStride( matrixA, matrixB, matrixC,
														   IncA, StrideA, IncB, StrideB,
														   IncC, StrideC, RowsA,
														   ColsA, RowsB, ColsB,
														   TRUE )
	END MatMulIncRSSEStride;

	PROCEDURE MatMulRBlocked( matrixA, matrixB, matrixC: ADDRESS;
		 IncA, StrideA, IncB, StrideB, IncC, StrideC, RowsA, ColsA, RowsB, ColsB: SIZE ): BOOLEAN;
	BEGIN
		RETURN MatMulARARBlocked( matrixA, matrixB, matrixC,
													    IncA, StrideA, IncB, StrideB,
													    IncC, StrideC, RowsA, ColsA,
													    RowsB, ColsB, FALSE )
	END MatMulRBlocked;

	PROCEDURE MatMulIncRBlocked( matrixA, matrixB, matrixC: ADDRESS;
		 IncA, StrideA, IncB, StrideB, IncC, StrideC, RowsA, ColsA, RowsB, ColsB: SIZE ): BOOLEAN;
	BEGIN
		RETURN MatMulARARBlocked( matrixA, matrixB, matrixC,
													    IncA, StrideA, IncB, StrideB,
													    IncC, StrideC, RowsA, ColsA,
													    RowsB, ColsB, TRUE )
	END MatMulIncRBlocked;

	PROCEDURE MatMulXBlocked( matrixA, matrixB, matrixC: ADDRESS;
	 IncA, StrideA, IncB, StrideB, IncC, StrideC, RowsA, ColsA, RowsB, ColsB: SIZE ): BOOLEAN;
	BEGIN
		RETURN MatMulAXAXBlocked( matrixA, matrixB, matrixC,
													   IncA, StrideA, IncB, StrideB,
													   IncC, StrideC, RowsA, ColsA,
													   RowsB, ColsB, FALSE )
	END MatMulXBlocked;

	PROCEDURE MatMulIncXBlocked( matrixA, matrixB, matrixC: ADDRESS;
		 IncA, StrideA, IncB, StrideB, IncC, StrideC, RowsA, ColsA, RowsB, ColsB: SIZE ): BOOLEAN;
	BEGIN
		RETURN MatMulAXAXBlocked( matrixA, matrixB, matrixC,
													   IncA, StrideA, IncB, StrideB,
													   IncC, StrideC, RowsA, ColsA,
													   RowsB, ColsB, TRUE )
	END MatMulIncXBlocked;

	PROCEDURE SetMatMulMethod*( i: LONGINT );
	BEGIN
			KernelLog.String("ArrayBaseOptimized, method = ");
		IF i = cMatMulDynamic THEN
			KernelLog.String("dynamic.");
			ArrayBase.matMulIncR := MatMulIncR;
			ArrayBase.matMulIncX := MatMulIncX;
			ArrayBase.matMulR := MatMulR;
			ArrayBase.matMulX := MatMulX;
		ELSIF i = cMatMulScalarProduct THEN
			KernelLog.String("scalarproduct.");
			ArrayBase.matMulIncR := NIL;
			ArrayBase.matMulIncX := NIL;
			ArrayBase.matMulR := NIL;  ArrayBase.matMulX := NIL;
		ELSIF i = cMatMulNaive THEN
			KernelLog.String("naiive.");
			ArrayBase.matMulR := MatMulRNaive;
			ArrayBase.matMulX := MatMulXNaive;
			ArrayBase.matMulIncR := MatMulIncRNaive;
			ArrayBase.matMulIncX := MatMulIncXNaive;
		ELSIF i = cMatMulTransposed THEN
			KernelLog.String("transposed.");
			ArrayBase.matMulR := MatMulRTransposed;
			ArrayBase.matMulX := MatMulXTransposed;   (* KernelLog.String( "transposed" );  KernelLog.Ln;  *)
			ArrayBase.matMulIncR := MatMulIncRTransposed;
			ArrayBase.matMulIncX := MatMulIncXTransposed;   (* KernelLog.String( "transposed" );  KernelLog.Ln;  *)
		ELSIF i = cMatMulStride THEN
			KernelLog.String("stride.");
			ArrayBase.matMulR := MatMulRSSEStride;
			ArrayBase.matMulX := MatMulXSSEStride;   (*  KernelLog.String( "stride" );  KernelLog.Ln;  *)
			ArrayBase.matMulIncR := MatMulIncRSSEStride;
			ArrayBase.matMulIncX := MatMulIncXSSEStride;   (*  KernelLog.String( "stride" );  KernelLog.Ln;  *)
		ELSIF i = cMatMulBlocked THEN
			KernelLog.String("blocked.");
			ArrayBase.matMulR := MatMulRBlocked;
			ArrayBase.matMulX := MatMulXBlocked;   (* KernelLog.String( "blocked" );  KernelLog.Ln;  *)
			ArrayBase.matMulIncR := MatMulIncRBlocked;
			ArrayBase.matMulIncX := MatMulIncXBlocked;   (* KernelLog.String( "blocked" );  KernelLog.Ln;  *)
		END;
		KernelLog.Ln;
	END SetMatMulMethod;

	(* optimizations for small arrays (Alexey Morozov) *)
	(* assumes that all arrays do not overlap *)
	(* FIXME: use MOVAPS when Felix fixes problems with alignment!!! *)
	PROCEDURE MatMulR2x2(dadr, ladr, radr: ADDRESS);
	CODE{SYSTEM.AMD64, SYSTEM.SSE2}
		MOV RBX, [RBP+radr] ; RBX := ADDR(right)
		MOV RAX, [RBP+ladr] ; RAX := ADDR(left)
		MOV RCX, [RBP+dadr] ; RCX := ADDR(dest)

		MOVUPS XMM0, [RAX] ; [a00,a01,a10,a11]
		MOVUPS XMM1, [RBX] ; [b00,b01,b10,b11]

		MOVAPS XMM2, XMM1
		SHUFPS XMM2, XMM1, 204 ; XMM2 := [b00,b11,b00,b11]
		MULPS XMM2, XMM0

		SHUFPS XMM0, XMM0, 177 ; XMM0 := [a01,a00,a11,a10]
		SHUFPS XMM1, XMM1, 102 ; XMM1 := [b10,b01,b10,b01]
		MULPS XMM1, XMM0

		ADDPS XMM1, XMM2

		MOVUPS [RCX], XMM1
	END MatMulR2x2;

	(* based on weighted sum of rows (Alexey Morozov) *)
	(* FIXME: use MOVAPS when Felix fixes problems with alignment!!! *)
	PROCEDURE MatMulR3x3(dadr, ladr, radr: ADDRESS);
	CODE{SYSTEM.AMD64, SYSTEM.SSE2}
		MOV RBX, [RBP+radr] ; RBX := ADDR(right)
		MOV RAX, [RBP+ladr] ; RAX := ADDR(left)
		MOV RCX, [RBP+dadr] ; RCX := ADDR(dest)

		MOVUPS XMM0, [RBX] ; XMM0 := [b00,b01,b02,-]
		MOVUPS XMM1, [RBX+12] ; XMM1 := [b10,b11,b12,-]

		; last element is out of range, is it still OK?
		MOVUPS XMM2, [RBX+24] ; XMM2 := [b20,b21,b22,-]
		;MOVLPS XMM2, [RBX+24]
		;MOVSS XMM3, [RBX+32]
		;MOVLHPS XMM2, XMM3

		MOVSS XMM3, [RAX]
		SHUFPS XMM3, XMM3, 0; XMM3 := [a00,a00,a00,-]

		MOVAPS XMM4, XMM0
		MULPS XMM4, XMM3

		MOVSS XMM3, [RAX+4]
		SHUFPS XMM3, XMM3, 0; XMM3 := [a01,a01,a01,-]

		MULPS XMM3, XMM1
		ADDPS XMM4, XMM3

		MOVSS XMM3, [RAX+8]
		SHUFPS XMM3, XMM3, 0; XMM3 := [a02,a02,a02,-]

		MULPS XMM3, XMM2
		ADDPS XMM4, XMM3

		MOVUPS [RCX], XMM4

		;***************************************************;

		MOVSS XMM3, [RAX+12]
		SHUFPS XMM3, XMM3, 0; XMM3 := [a10,a10,a10,-]

		MOVAPS XMM4, XMM0
		MULPS XMM4, XMM3

		MOVSS XMM3, [RAX+16]
		SHUFPS XMM3, XMM3, 0; XMM3 := [a11,a11,a11,-]

		MULPS XMM3, XMM1
		ADDPS XMM4, XMM3

		MOVSS XMM3, [RAX+20]
		SHUFPS XMM3, XMM3, 0; XMM3 := [a12,a12,a12,-]

		MULPS XMM3, XMM2
		ADDPS XMM4, XMM3

		MOVUPS [RCX+12], XMM4

		;***************************************************;

		MOVSS XMM3, [RAX+24]
		SHUFPS XMM3, XMM3, 0; XMM3 := [a20,a20,a20,-]

		MOVAPS XMM4, XMM0
		MULPS XMM4, XMM3

		MOVSS XMM3, [RAX+28]
		SHUFPS XMM3, XMM3, 0; XMM3 := [a21,a21,a21,-]

		MULPS XMM3, XMM1
		ADDPS XMM4, XMM3

		MOVSS XMM3, [RAX+32]
		SHUFPS XMM3, XMM3, 0; XMM3 := [a22,a22,a22,-]

		MULPS XMM3, XMM2
		ADDPS XMM4, XMM3

		;MOVUPS [RCX+24], XMM4
		MOVLPS [RCX+24], XMM4
		MOVHLPS XMM4, XMM4
		MOVSS [RCX+32], XMM4
	END MatMulR3x3;

	(* based on Strassen algorithm (Alexey Morozov) *)
	(* FIXME: use MOVAPS when Felix fixes issues with alignment!!! *)
	PROCEDURE MatMulR4x4(dadr, ladr, radr: ADDRESS);
	CODE{SYSTEM.AMD64, SYSTEM.SSE2}
		MOV RBX, [RBP+radr] ; RBX := ADDR(right)
		MOV RAX, [RBP+ladr] ; RAX := ADDR(left)
		MOV RCX, [RBP+dadr] ; RCX := ADDR(dest)

		; load A00
		MOVLPS XMM0, [RAX] ; XMM0 := [a00,a01,-,-]
		MOVHPS XMM0, [RAX+16] ; XMM0 := [a00,a01,a10,a11]

		; load A01
		MOVLPS XMM1, [RAX+8] ; XMM1 := [a02,a03,-,-]
		MOVHPS XMM1, [RAX+24] ; XMM1 := [a02,a03,a12,a13]

		; load B00
		MOVLPS XMM2, [RBX] ; XMM2 := [b00,b01,-,-]
		MOVHPS XMM2, [RBX+16] ; XMM2 := [b00,b01,b10,b11]

		; load B01
		MOVLPS XMM3, [RBX+8] ; XMM3 := [a02,a03,-,-]
		MOVHPS XMM3, [RBX+24] ; XMM3 := [a02,a03,a12,a13]

		; load B10
		MOVLPS XMM4, [RBX+32] ; XMM4 := [b20,b21,-,-]
		MOVHPS XMM4, [RBX+48] ; XMM4 := [b20,b21,b30,b31]

		; load B11
		MOVLPS XMM5, [RBX+40] ; XMM5 := [b22,b23,-,-]
		MOVHPS XMM5, [RBX+56] ; XMM5 := [b22,b23,b32,b33]

		;****************************************************;

		; multiply A00(D)*B00(E)	(use MatMulR2x2 code)

		MOVAPS XMM6, XMM2
		SHUFPS XMM6, XMM6, 204 ; XMM6 := [e00,e11,e00,e11]
		MULPS XMM6, XMM0

		SHUFPS XMM0, XMM0, 177 ; XMM0 := [d01,d00,d11,d10]
		MOVAPS XMM7, XMM2
		SHUFPS XMM7, XMM7, 102 ; XMM7 := [e10,e01,e10,e01]
		MULPS XMM7, XMM0

		ADDPS XMM7, XMM6

		; multiply A01(D)*B10(E)

		MOVAPS XMM0, XMM4
		SHUFPS XMM0, XMM0, 204 ; XMM0 := [e00,e11,e00,e11]
		MULPS XMM0, XMM1

		SHUFPS XMM1, XMM1, 177 ; XMM1 := [d01,d00,d11,d10]
		MOVAPS XMM6, XMM4
		SHUFPS XMM6, XMM6, 102 ; XMM6 := [e10,e01,e10,e01]
		MULPS XMM6, XMM1

		ADDPS XMM6, XMM0
		ADDPS XMM7, XMM6

		MOVLPS [RCX], XMM7
		MOVHPS [RCX+16], XMM7


		;****************************************************;

		; load A00
		MOVLPS XMM0, [RAX] ; XMM0 := [a00,a01,-,-]
		MOVHPS XMM0, [RAX+16] ; XMM0 := [a00,a01,a10,a11]

		; load A01
		MOVLPS XMM1, [RAX+8] ; XMM1 := [a02,a03,-,-]
		MOVHPS XMM1, [RAX+24] ; XMM1 := [a02,a03,a12,a13]

		; multiply A00(D)*B01(E)	(use MatMulR2x2 code)

		MOVAPS XMM6, XMM3
		SHUFPS XMM6, XMM6, 204 ; XMM6 := [e00,e11,e00,e11]
		MULPS XMM6, XMM0

		SHUFPS XMM0, XMM0, 177 ; XMM0 := [d01,d00,d11,d10]
		MOVAPS XMM7, XMM3
		SHUFPS XMM7, XMM7, 102 ; XMM7 := [e10,e01,e10,e01]
		MULPS XMM7, XMM0

		ADDPS XMM7, XMM6

		; multiply A01(D)*B11(E)

		MOVAPS XMM0, XMM5
		SHUFPS XMM0, XMM0, 204 ; XMM0 := [e00,e11,e00,e11]
		MULPS XMM0, XMM1

		SHUFPS XMM1, XMM1, 177 ; XMM1 := [d01,d00,d11,d10]
		MOVAPS XMM6, XMM5
		SHUFPS XMM6, XMM6, 102 ; XMM6 := [e10,e01,e10,e01]
		MULPS XMM6, XMM1

		ADDPS XMM6, XMM0
		ADDPS XMM7, XMM6

		MOVLPS [RCX+8], XMM7
		MOVHPS [RCX+24], XMM7

		;****************************************************;

		; load A10
		MOVLPS XMM0, [RAX+32] ; XMM0 := [a20,a21,-,-]
		MOVHPS XMM0, [RAX+48] ; XMM0 := [a20,a21,a30,a31]

		; load A11
		MOVLPS XMM1, [RAX+40] ; XMM1 := [a22,a23,-,-]
		MOVHPS XMM1, [RAX+56] ; XMM1 := [a22,a23,a32,a33]

		; multiply A10(D)*B00(E)	(use MatMulR2x2 code)

		MOVAPS XMM6, XMM2
		SHUFPS XMM6, XMM6, 204 ; XMM6 := [e00,e11,e00,e11]
		MULPS XMM6, XMM0

		SHUFPS XMM0, XMM0, 177 ; XMM0 := [d01,d00,d11,d10]
		MOVAPS XMM7, XMM2
		SHUFPS XMM7, XMM7, 102 ; XMM7 := [e10,e01,e10,e01]
		MULPS XMM7, XMM0

		ADDPS XMM7, XMM6

		; multiply A11(D)*B10(E)

		MOVAPS XMM0, XMM4
		SHUFPS XMM0, XMM0, 204 ; XMM0 := [e00,e11,e00,e11]
		MULPS XMM0, XMM1

		SHUFPS XMM1, XMM1, 177 ; XMM1 := [d01,d00,d11,d10]
		MOVAPS XMM6, XMM4
		SHUFPS XMM6, XMM6, 102 ; XMM6 := [e10,e01,e10,e01]
		MULPS XMM6, XMM1

		ADDPS XMM6, XMM0
		ADDPS XMM7, XMM6

		MOVLPS [RCX+32], XMM7
		MOVHPS [RCX+48], XMM7

		;****************************************************;

		; load A10
		MOVLPS XMM0, [RAX+32] ; XMM0 := [a20,a21,-,-]
		MOVHPS XMM0, [RAX+48] ; XMM0 := [a20,a21,a30,a31]

		; load A11
		MOVLPS XMM1, [RAX+40] ; XMM1 := [a22,a23,-,-]
		MOVHPS XMM1, [RAX+56] ; XMM1 := [a22,a23,a32,a33]

		; multiply A10(D)*B01(E)	(use MatMulR2x2 code)

		MOVAPS XMM6, XMM3
		SHUFPS XMM6, XMM6, 204 ; XMM6 := [e00,e11,e00,e11]
		MULPS XMM6, XMM0

		SHUFPS XMM0, XMM0, 177 ; XMM0 := [d01,d00,d11,d10]
		MOVAPS XMM7, XMM3
		SHUFPS XMM7, XMM7, 102 ; XMM7 := [e10,e01,e10,e01]
		MULPS XMM7, XMM0

		ADDPS XMM7, XMM6

		; multiply A11(D)*B11(E)

		MOVAPS XMM0, XMM5
		SHUFPS XMM0, XMM0, 204 ; XMM0 := [e00,e11,e00,e11]
		MULPS XMM0, XMM1

		SHUFPS XMM1, XMM1, 177 ; XMM1 := [d01,d00,d11,d10]
		MOVAPS XMM6, XMM5
		SHUFPS XMM6, XMM6, 102 ; XMM6 := [e10,e01,e10,e01]
		MULPS XMM6, XMM1

		ADDPS XMM6, XMM0
		ADDPS XMM7, XMM6

		MOVLPS [RCX+40], XMM7
		MOVHPS [RCX+56], XMM7

	END MatMulR4x4;

	(* FIXME: use MOVAPS when Felix fixes issues with alignment!!! *)
	(* FIXME: speed it up when horizontal add is available!!! *)
	PROCEDURE MatVecMulR2x2(dadr, ladr, radr: ADDRESS);
	CODE{SYSTEM.AMD64, SYSTEM.SSE2}
		MOV RBX, [RBP+radr] ; RBX := ADDR(right)
		MOV RAX, [RBP+ladr] ; RAX := ADDR(left)
		MOV RCX, [RBP+dadr] ; RCX := ADDR(dest)

		; load the whole matrix
		MOVUPS XMM0, [RAX] ; XMM0 := [a00,a01,a10,a11]

		MOVLPS XMM1, [RBX] ; XMM1 := [b00,b01,-,-]
		MOVLHPS XMM1, XMM1 ; XMM1 := [b00,b10,b00,b10]

		MULPS XMM0, XMM1 ; XMM0 := [a00*b00,a01*b10,a10*b00,a11*b10]

		MOVAPS XMM1, XMM0
		SHUFPS XMM0, XMM0, 8; XMM0 := [a00*b00,a10*b00,-,-]
		SHUFPS XMM1, XMM1, 13; XMM1 := [a01*b10,a11*b10,-,-]
		ADDPS XMM0, XMM1

		MOVLPS [RCX], XMM0
	END MatVecMulR2x2;
	
	(* PH *)
	(* to do: use MOVAPS when Felix fixes issues with alignment *)
	PROCEDURE MatVecMulR4x4(dadr, ladr, radr: ADDRESS);
	CODE{SYSTEM.AMD64, SYSTEM.SSE3}
		MOV RBX, [RBP+radr] ; RBX := ADDR(right)
		MOV RAX, [RBP+ladr] ; RAX := ADDR(left)
		MOV RCX, [RBP+dadr] ; RCX := ADDR(dest)

		MOVUPS XMM0, [RBX] ; XMM0 := [b0,b1,b2,b3]
		MOVUPS XMM1, [RAX] ; XMM1 := [a00,a01,a02,a03]
		MOVUPS XMM2, [RAX+16] ; XMM2 := [a10,a11,a12,a13]
		MOVUPS XMM3, [RAX+32] ; XMM3 := [a20,a21,a22,a23]
		MOVUPS XMM4, [RAX+48] ; XMM4 := [a30,a31,a32,a33]
		MULPS XMM1, XMM0 
		MULPS XMM2, XMM0 
		HADDPS XMM1, XMM2	; adjacent pairs are horizontally  added  
		
		MULPS XMM3, XMM0 
		MULPS XMM4, XMM0 
		HADDPS XMM3, XMM4	; adjacent pairs are horizontally  added  
		
		HADDPS XMM1, XMM3	; adjacent pairs are horizontally  added 
		MOVUPS [RCX], XMM1
	END MatVecMulR4x4;

	PROCEDURE InstallMatMul*(context: Commands.Context);
	VAR type: LONGINT;  string: ARRAY 32 OF CHAR;
	BEGIN
		context.arg.String(string);
		IF string = "dynamic" THEN
			type := cMatMulDynamic;
		ELSIF string = "scalarproduct" THEN
			type := cMatMulScalarProduct
		ELSIF string = "naive" THEN
			type := cMatMulNaive
		ELSIF string = "transposed" THEN
			type := cMatMulTransposed
		ELSIF string = "stride" THEN
			type := cMatMulStride
		ELSIF string ="blocked" THEN
			type := cMatMulBlocked
		ELSE
			KernelLog.String("unknown method: "); KernelLog.String(string); KernelLog.Ln;
			type := cMatMulDynamic;
		END;
		SetMatMulMethod( type );
	END InstallMatMul;


	PROCEDURE InstallAsm*;
	BEGIN
		KernelLog.String( "ASM " );
		ArrayBase.loopSPAXAX := SPAXAXLoopA;
		ArrayBase.loopSPARAR := SPARARLoopA;
		ArrayBase.loopAddAXAX := AddAXAXLoopA;
		ArrayBase.loopAddARAR := AddARARLoopA;
		ArrayBase.loopMatMulAXAX := MatMulAXAXLoopA;
		ArrayBase.loopMatMulARAR := MatMulARARLoopA;
		ArrayBase.loopMulAXSX := MulAXSXLoopA;
		ArrayBase.loopIncMulAXSX := IncMulAXSXLoopA;
		ArrayBase.loopMulARSR := MulARSRLoopA;
		ArrayBase.loopIncMulARSR := IncMulARSRLoopA;
		ArrayBase.loopMatMulIncAXAX := MatMulIncAXAXLoopA;
		ArrayBase.loopMatMulIncARAR := MatMulIncARARLoopA;
		ArrayBase.transpose4 := Transpose4;
		ArrayBase.transpose8 := Transpose8;
	END InstallAsm;

	PROCEDURE InstallSSE*;
	BEGIN
		IF Machine.SSESupport THEN
			KernelLog.String( "SSE " );
			ArrayBase.loopSPARAR := SPARARLoopSSE;
			ArrayBase.loopAddARAR := AddARARLoopSSE;
			ArrayBase.loopMulARSR := MulARSRLoopSSE;
			ArrayBase.loopIncMulARSR := IncMulARSRLoopSSE;
			ArrayBase.loopMatMulARAR := MatMulARARLoopSSE;
			ArrayBase.matMulR := MatMulR;
			ArrayBase.loopMatMulIncARAR := MatMulIncARARLoopSSE;
			ArrayBase.matMulIncR := MatMulIncR;

			(* optimizations for small matrices (Alexey Morozov) *)
			ArrayBase.matMulR2x2 := MatMulR2x2;
			ArrayBase.matMulR3x3 := MatMulR3x3;
			ArrayBase.matMulR4x4 := MatMulR4x4;

			ArrayBase.matVecMulR2x2 := MatVecMulR2x2;

		END;
	END InstallSSE;

	PROCEDURE InstallSSE2*;   (* extra for testing, will be merged with Install in later versions *)
	BEGIN
		IF Machine.SSE2Support THEN
			KernelLog.String( "SSE2 " );
			ArrayBase.loopSPAXAX := SPAXAXLoopSSE;
			ArrayBase.loopAddAXAX := AddAXAXLoopSSE;
			ArrayBase.loopMulAXSX := MulAXSXLoopSSE;
			ArrayBase.loopIncMulAXSX := IncMulAXSXLoopSSE;
			ArrayBase.loopMatMulAXAX := MatMulAXAXLoopSSE;
			ArrayBase.matMulX := MatMulX;
			ArrayBase.loopMatMulIncAXAX :=
				MatMulIncAXAXLoopSSE;
			ArrayBase.matMulIncX := MatMulIncX;
		END;
	END InstallSSE2;

	(*! to do: at current, this only works for Win, not for native because SSE3Support is not yet implemented in BIOS.I386.Machine.Mod*)
	PROCEDURE InstallSSE3*;   (* extra for testing, will be merged with Install in later versions *)
	BEGIN
		IF Machine.SSE3Support THEN
			KernelLog.String( "SSE3 " );
			(* optimizations for small matrices  *)
			ArrayBase.matVecMulR4x4 := MatVecMulR4x4;
		END;
	END InstallSSE3;
	
	PROCEDURE Install*;
	BEGIN
		KernelLog.String( "ArrayBaseOptimized: installing runtime library optimizations:" );
		InstallAsm;  InstallSSE;  InstallSSE2; InstallSSE3;
		KernelLog.String( " done." );  KernelLog.Ln;
	END Install;

	PROCEDURE SetParameters*( context: Commands.Context );
	BEGIN
		context.arg.SkipWhitespace; context.arg.Int(cBlockSize,TRUE);
		context.arg.SkipWhitespace; context.arg.Int(nrProcesses,TRUE);
		IF nrProcesses > maxProcesses THEN
			nrProcesses := maxProcesses
		ELSIF nrProcesses = 0 THEN nrProcesses := LONGINT (Machine.NumberOfProcessors());
		END;
		KernelLog.String( "BlockSize=" );  KernelLog.Int( cBlockSize, 0 );
		KernelLog.String( ", NrProcesses = " );  KernelLog.Int( nrProcesses, 0 );  KernelLog.Ln;
	END SetParameters;

BEGIN
	cBlockSize := 0;   (* automatic *)
	nrProcesses := LONGINT (Machine.NumberOfProcessors());   (* automatic *)

	allocT := 0;  copyT := 0;  compT := 0;
	NEW( cachePool );

END FoxArrayBaseOptimized.

System.Free ArrayBaseOptimized ~

ArrayBaseOptimized.Install ~
ArrayBaseOptimized.InstallSSE2 ~
ArrayBaseOptimized.InstallSSE ~
ArrayBaseOptimized.InstallAsm ~

ArrayBaseOptimized.InstallMatMul dynamic ~
ArrayBaseOptimized.InstallMatMul scalarproduct ~
ArrayBaseOptimized.InstallMatMul transposed ~
ArrayBaseOptimized.InstallMatMul naive ~
ArrayBaseOptimized.InstallMatMul stride ~
ArrayBaseOptimized.InstallMatMul blocked ~

ArrayBaseOptimized.SetParameters  0 1    ~ (* BlockSize, NrProcesses *)


