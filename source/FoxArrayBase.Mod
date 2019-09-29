MODULE FoxArrayBase; (* stubs for array base runtime - can only be compiled by oc compiler *)
(* (c) fof, fn, ETH Zürich, 2008 *)

(*! do  do: MAX(array,scalar) and MAX(array,array) for all datatypes*)

IMPORT SYSTEM, KernelLog, Heaps, Machine, MathL;

TYPE

	GenericUnaryAALoopS = PROCEDURE ( ladr, dadr: ADDRESS; linc, dinc, len: SIZE; op: PROCEDURE {DELEGATE} (x: SIGNED8): SIGNED8 );
	GenericUnaryAALoopI = PROCEDURE ( ladr, dadr: ADDRESS; linc, dinc, len: SIZE; op: PROCEDURE {DELEGATE} (x: SIGNED16): SIGNED16 );
	GenericUnaryAALoopL = PROCEDURE ( ladr, dadr: ADDRESS; linc, dinc, len: SIZE; op: PROCEDURE {DELEGATE} (x: SIGNED32): SIGNED32 );
	GenericUnaryAALoopH = PROCEDURE ( ladr, dadr: ADDRESS; linc, dinc, len: SIZE; op: PROCEDURE {DELEGATE} (x: SIGNED64): SIGNED64 );
	GenericUnaryAALoopR = PROCEDURE ( ladr, dadr: ADDRESS; linc, dinc, len: SIZE; op: PROCEDURE {DELEGATE} (x: FLOAT32): FLOAT32 );
	GenericUnaryAALoopX = PROCEDURE ( ladr, dadr: ADDRESS; linc, dinc, len: SIZE; op: PROCEDURE {DELEGATE} (x: FLOAT64): FLOAT64 );
	GenericUnaryAALoopZ = PROCEDURE ( ladr, dadr: ADDRESS; linc, dinc, len: SIZE; op: PROCEDURE {DELEGATE} (x: COMPLEX32): COMPLEX32 );
	GenericUnaryAALoopLZ = PROCEDURE ( ladr, dadr: ADDRESS; linc, dinc, len: SIZE; op: PROCEDURE {DELEGATE} (x: COMPLEX64): COMPLEX64 );
	UnaryAALoop = PROCEDURE ( ladr, dadr: ADDRESS; linc, dinc, len: SIZE );
	UnaryASLoop = PROCEDURE ( ladr, dadr: ADDRESS; linc, len: SIZE );
	UnarySALoop = PROCEDURE ( ladr, dadr: ADDRESS; dinc, len: SIZE );
	BinaryAAALoop = PROCEDURE ( ladr, radr, dadr: ADDRESS; linc, rinc, dinc, len: SIZE );
	BinaryASALoop = PROCEDURE ( ladr, radr, dadr: ADDRESS; linc, dinc, len: SIZE );
	BinaryAASLoop = PROCEDURE ( ladr, radr, dadr: ADDRESS; linc, rinc, len: SIZE );
	BinaryAABLoop = PROCEDURE ( ladr, radr: ADDRESS; linc, rinc, len: SIZE ): BOOLEAN;
	BinaryASBLoop = PROCEDURE ( ladr, radr: ADDRESS; linc, len: SIZE ): BOOLEAN;

	LenType = SIZE; (* should be SIZE but for legacy reasons we have to use this *)

CONST
	debug = FALSE;   (* warning: debug=true -> a lot of output is generated -> traps are not displayed in Oberon (Kernel overflow) *)
	statistics= FALSE;
	conservative=TRUE;

	ArrDataArrayOffset= 3*SIZEOF (ADDRESS) + ((-3)*SIZEOF (ADDRESS)) MOD Heaps.ArrayAlignment ; (* offset of data in array with pointers *)

	AddressSize=SIZEOF(ADDRESS);
	MathPtrOffset=0*AddressSize;
	MathAdrOffset=1*AddressSize;
	MathFlagsOffset=2*AddressSize;
	MathDimOffset=3*AddressSize;
	MathElementSizeOffset=4*AddressSize;
	MathLenOffset=5*AddressSize;
	MathIncrOffset=6*AddressSize;

	GeometryMismatch = 400;
	DimensionMismatch=401;
	AllocationForbidden=402;

	ArrayAlignment=16;

	TensorFlag = 0;  RangeFlag = 1;  TemporaryFlag = 2;

	down = 0;  up = 1;   (* memory copy modes *)

	(* flags for optimizations with small matricies and vectors (Alexey Morozov) *)
	SmallMatrixFlag = 3; (* flag for identification of a small matrix *)
	SmallVectorFlag = 3; (* flag for identification of a small vector *)
	Size2Flag = 4; (* size = 2 *)
	Size3Flag = 5; (* size = 3 *)
	Size4Flag = 6; (* size = 4 *)
	Size5Flag = 7; (* size = 5 *)
	Size6Flag = 8; (* size = 6 *)
	Size7Flag = 9; (* size = 7 *)
	Size8Flag = 10; (* size = 8 *)

	Mat2x2 = {SmallMatrixFlag,Size2Flag};
	Mat3x3 = {SmallMatrixFlag,Size3Flag};
	Mat4x4 = {SmallMatrixFlag,Size4Flag};
	Mat5x5 = {SmallMatrixFlag,Size5Flag};
	Mat6x6 = {SmallMatrixFlag,Size6Flag};
	Mat7x7 = {SmallMatrixFlag,Size7Flag};
	Mat8x8 = {SmallMatrixFlag,Size8Flag};

	Vec2 = {SmallVectorFlag,Size2Flag};
	Vec3 = {SmallVectorFlag,Size3Flag};
	Vec4 = {SmallVectorFlag,Size4Flag};
	Vec5 = {SmallVectorFlag,Size5Flag};
	Vec6 = {SmallVectorFlag,Size6Flag};
	Vec7 = {SmallVectorFlag,Size7Flag};
	Vec8 = {SmallVectorFlag,Size8Flag};

	MatVec2x2 = {SmallMatrixFlag,SmallVectorFlag,Size2Flag};
	MatVec3x3 = {SmallMatrixFlag,SmallVectorFlag,Size3Flag};
	MatVec4x4 = {SmallMatrixFlag,SmallVectorFlag,Size4Flag};
	MatVec5x5 = {SmallMatrixFlag,SmallVectorFlag,Size5Flag};
	MatVec6x6 = {SmallMatrixFlag,SmallVectorFlag,Size6Flag};
	MatVec7x7 = {SmallMatrixFlag,SmallVectorFlag,Size7Flag};
	MatVec8x8 = {SmallMatrixFlag,SmallVectorFlag,Size8Flag};

	SmallArrayMask = {SmallMatrixFlag,SmallVectorFlag,Size2Flag,Size3Flag,Size4Flag,Size5Flag,Size6Flag,Size7Flag,Size8Flag};

TYPE
	FastMatMul* = PROCEDURE ( matrixA, matrixB, matrixC: ADDRESS;  IncA, StrideA, IncB, StrideB, IncC, StrideC, RowsA, ColsA, RowsB, ColsB: SIZE ): BOOLEAN;
	TransposeP* = PROCEDURE ( ladr, dadr: ADDRESS; lstride, linc, dstride, dinc, rows, cols:SIZE );

	LenInc* = RECORD
		len*: SIZE;
		inc*: SIZE
	END;

	ArrayDescriptor*= RECORD
		ptr*: ANY;
		adr*: ADDRESS;
		flags*: SET;
		dim*: SIZE;
		elementSize*: SIZE;
	END;

	Tensor = POINTER TO ArrayDescriptor;

	UnsafeArray*= POINTER {UNSAFE,UNTRACED} TO RECORD(ArrayDescriptor)
		lens*: ARRAY 8 OF LenInc;
	END;

	UnsafeArrayT*= POINTER {UNSAFE} TO RECORD(ArrayDescriptor)
		lens*: ARRAY 8 OF LenInc;
	END;

	A0 = RECORD(ArrayDescriptor) END;
	A1 = RECORD(ArrayDescriptor) lens : ARRAY 1 OF LenInc; END;
	A2 = RECORD(ArrayDescriptor) lens : ARRAY 2 OF LenInc; END;
	A3 = RECORD(ArrayDescriptor) lens : ARRAY 3 OF LenInc; END;
	A4 = RECORD(ArrayDescriptor) lens : ARRAY 4 OF LenInc; END;
	A5 = RECORD(ArrayDescriptor) lens : ARRAY 5 OF LenInc; END;
	A6 = RECORD(ArrayDescriptor) lens : ARRAY 6 OF LenInc; END;
	A7 = RECORD(ArrayDescriptor) lens : ARRAY 7 OF LenInc; END;
	A8 = RECORD(ArrayDescriptor) lens : ARRAY 8 OF LenInc; END;

	T0 = POINTER TO A0;
	T1 = POINTER TO A1;
	T2 = POINTER TO A2;
	T3 = POINTER TO A3;
	T4 = POINTER TO A4;
	T5 = POINTER TO A5;
	T6 = POINTER TO A6;
	T7 = POINTER TO A7;
	T8 = POINTER TO A8;

	(* used for optimizations of MatMul with small sizes (Alexey Morozov) *)
	SmallMatMul* = PROCEDURE(dadr, ladr, radr: ADDRESS);

VAR
	temporary*:  T0;

	alloc*: SIGNED32;   (* statistics *)
	allocTemp*: SIGNED32;   (* statistics *)

	(* procedures that might be replaced by ASM methods *)
	loopSPAXAX*, loopSPARAR*: BinaryAASLoop;
	loopSPAZAZ, loopSPALZALZ: BinaryAASLoop;
	loopAddAXAX*, loopAddARAR*, loopAddAZAZ*, loopAddALZALZ*: BinaryAAALoop;
	loopSubAXAX*, loopSubARAR*, loopSubAZAZ*, loopSubALZALZ*: BinaryAAALoop;
	loopEMulAXAX*, loopEMulARAR*, loopEMulAZAZ*, loopEMulALZALZ*: BinaryAAALoop;
	loopMatMulAXAX*, loopMatMulARAR*: BinaryAASLoop;
	loopMatMulIncAXAX*, loopMatMulIncARAR*: BinaryAASLoop;
	loopMulAXSX*, loopMulARSR*, loopMulAZSZ*, loopMulALZSLZ*: BinaryASALoop;
	loopIncMulAXSX*, loopIncMulARSR*: BinaryASALoop;
	matMulX*, matMulR*: FastMatMul;  matMulIncX*, matMulIncR*: FastMatMul;
	transpose4*: TransposeP;  transpose8*: TransposeP;

	(* optimizations for small arrays (Alexey Morozov) *)
	matMulR2x2*: SmallMatMul;
	matMulR3x3*: SmallMatMul;
	matMulR4x4*: SmallMatMul;

	matVecMulR2x2*: SmallMatMul;
	matVecMulR3x3*: SmallMatMul;
	matVecMulR4x4*: SmallMatMul;

	matMulLR2x2*: SmallMatMul;
	matMulLR3x3*: SmallMatMul;
	matMulLR4x4*: SmallMatMul;

	matVecMulLR2x2*: SmallMatMul;
	matVecMulLR3x3*: SmallMatMul;
	matVecMulLR4x4*: SmallMatMul;

	(*
	TensorTypePool: ARRAY 32 OF TensorType;
	*)

	PROCEDURE SetDefaults*;   (* set standard procedures *)
	BEGIN
		KernelLog.String( "ArrayBase XXXXXXX: setting runtime library (semi-optimized) default methods." );  KernelLog.Ln;  loopSPAXAX := SPAXAXLoop;
		loopSPARAR := SPARARLoop;  loopAddAXAX := AddAXAXLoop;  loopSubAXAX := SubAXAXLoop; loopEMulAXAX := EMulAXAXLoop;
		loopSPAZAZ := SPAZAZLoop; loopSPALZALZ := SPALZALZLoop;
		loopAddARAR := AddARARLoop; loopSubARAR := SubARARLoop; loopEMulARAR := EMulARARLoop; loopMatMulAXAX := MatMulAXAXLoop;
		loopAddAZAZ := AddAZAZLoop; loopAddALZALZ := AddALZALZLoop; loopSubAZAZ := SubAZAZLoop; loopSubALZALZ := SubALZALZLoop;
		loopEMulAZAZ := EMulAZAZLoop; loopEMulALZALZ := EMulALZALZLoop;
		loopMatMulIncAXAX := MatMulIncAXAXLoop;
		loopMatMulARAR := MatMulARARLoop;  loopMulAXSX := MulAXSXLoop;
		loopIncMulAXSX := IncMulAXSXLoop;
		loopMatMulIncARAR := MatMulIncARARLoop;
		loopMulARSR := MulARSRLoop;  loopIncMulARSR := IncMulARSRLoop;
		matMulX := NIL;  matMulR := NIL;  matMulIncX := NIL;  matMulIncR := NIL;

		loopMulAZSZ := MulAZSZLoop;
		loopMulALZSLZ := MulALZSLZLoop;
	END SetDefaults;

	PROCEDURE Err(CONST s: ARRAY OF CHAR );
	BEGIN
		KernelLog.String( "Runtime Error: " );  KernelLog.String( s );  KernelLog.Ln;  HALT( 100 );
	END Err;

	(* get increment of dimension dim *)
	PROCEDURE GetIncr(base: UnsafeArray; dim: SIZE): SIZE;
	BEGIN{UNCHECKED}
		RETURN base.lens[dim].inc
	END GetIncr;

	(* set increment of dimension dim *)
	PROCEDURE PutInc(base: UnsafeArray; dim,val: SIZE);
	BEGIN{UNCHECKED}
		base.lens[dim].inc := val
	END PutInc;

	(* get length of dimension dim *)
	PROCEDURE GetLen(base: UnsafeArray; dim: SIZE): SIZE;
	BEGIN{UNCHECKED}
		RETURN base.lens[dim].len
	END GetLen;

	(* set length of dimension dim *)
	PROCEDURE PutLen(base: UnsafeArray; dim,val: SIZE);
	BEGIN{UNCHECKED}
		base.lens[dim].len := val
	END PutLen;

	(* get data address *)
	PROCEDURE GetAdr(base: UnsafeArray): ADDRESS;
	BEGIN
		RETURN base.adr;
	END GetAdr;

	(* set data address *)
	PROCEDURE PutAdr(base: UnsafeArray; value: ADDRESS);
	BEGIN
		base.adr := value
	END PutAdr;

	PROCEDURE Align(value: ADDRESS): ADDRESS;
	BEGIN RETURN value + (-value) MOD ArrayAlignment;
	END Align;

	(* get data base pointer (GC protection) *)
	PROCEDURE GetPtr(base: UnsafeArray): ANY;
	BEGIN
		RETURN base.ptr;
	END GetPtr;

	PROCEDURE SafePut(VAR dest: ANY; src: ANY);
	BEGIN
		dest := src;
	END SafePut;

	(* set data base pointer (GC protection) *)
	PROCEDURE PutPtr(CONST base: UnsafeArrayT; value: ANY);
	BEGIN
		SafePut(base.ptr,value);
	END PutPtr;

	PROCEDURE GetSize( base: UnsafeArray ): SIZE;
	BEGIN
		IF base = NIL THEN RETURN 0 ELSE RETURN base.elementSize END
	END GetSize;

	PROCEDURE PutSize( base: UnsafeArray;  val: SIZE );
	BEGIN
		base.elementSize := val
	END PutSize;

	PROCEDURE GetDim( base: UnsafeArray ): SIZE;
	BEGIN
		IF base = 0 THEN RETURN 0 ELSE RETURN base.dim END;
	END GetDim;

	PROCEDURE GetFlags( base: UnsafeArray ): SET;
	BEGIN
		IF base = 0 THEN RETURN {} ELSE RETURN base.flags END;
	END GetFlags;

	PROCEDURE PutDim( base: UnsafeArray;  dim: SIZE );
	BEGIN
		base.dim := dim
	END PutDim;

	PROCEDURE PutFlags( base: UnsafeArray;  flags: SET );
	BEGIN
		base.flags := flags
	END PutFlags;

(* report geometry of array passed via address s *)
	PROCEDURE Report(CONST name: ARRAY OF CHAR;  s: ADDRESS );
	VAR i: SIZE;  dim: SIZE;

		PROCEDURE Set( s: SET );
		VAR i: SIZE;  first: BOOLEAN;
		BEGIN
			KernelLog.String( "{" );  first := TRUE;
			FOR i := 31 TO 0 BY -1 DO
				IF i IN s THEN
					IF ~first THEN KernelLog.String( "," );  ELSE first := FALSE END;
					KernelLog.Int( i, 1 );
				END;
			END;
			KernelLog.String( "}" );
		END Set;

	BEGIN
		KernelLog.String( name );
		IF s = 0 THEN KernelLog.String( " : NIL " );  KernelLog.Ln;
		ELSE
			KernelLog.String( " at adr " );  KernelLog.Address( s );  KernelLog.String( "; ptr= " );
			KernelLog.Address( GetPtr( s ));  KernelLog.String( "; adr= " );
			KernelLog.Address( GetAdr( s ));  KernelLog.String( "; dim=" );
			KernelLog.Int( GetDim( s ), 1 );  KernelLog.String( "; flags=" );  Set( GetFlags( s ) );
			KernelLog.Ln;  dim := GetDim( s );
			IF dim > 32 THEN dim := 0 END;
			FOR i := 0 TO dim - 1 DO
				KernelLog.String( "dim (rev)=" );  KernelLog.Int( i, 1 );  KernelLog.String( ", len=" );
				KernelLog.Int( GetLen( s, i ), 1 );  KernelLog.String( ", inc=" );
				KernelLog.Int( GetIncr( s, i ), 1 );  KernelLog.Ln;
			END;
			(*
		FindPattern1( s, dim, ldim, len, inc );  KernelLog.String( "increment: " );
		KernelLog.Int( inc, 10 );  KernelLog.Ln;  KernelLog.String( "longest dim:" );  KernelLog.Int( ldim, 10 );
		KernelLog.Ln;  KernelLog.String( "len:" );  KernelLog.Int( len, 10 );  KernelLog.Ln;
		*)
		END;
	END Report;

	PROCEDURE GetArrayDesc( dim: SIZE ): Tensor;
	VAR (* t: TensorType;  *) ptr: Tensor;
		p0: T0;
		p1: T1; p2: T2; p3: T3; p4: T4; p5: T5; p6: T6; p7: T7; p8: T8;

	BEGIN
		CASE dim OF
		|0: NEW(p0); ptr := p0;
		|1:NEW(p1); ptr := p1;
		|2:NEW(p2); ptr := p2;
		|3:NEW(p3); ptr := p3;
		|4:NEW(p4); ptr := p4;
		|5:NEW(p5); ptr := p5;
		|6:NEW(p6); ptr := p6;
		|7:NEW(p7); ptr := p7;
		|8:NEW(p8); ptr := p8;
		ELSE
			HALT(200)
		END;
		ptr.dim := dim;
		ptr.flags := {TensorFlag};
		RETURN ptr;
	END GetArrayDesc;

	PROCEDURE EnsureArrayDesc*(dim: SIZE; VAR d: Tensor);
	BEGIN
		IF d = NIL THEN
			d := GetArrayDesc(dim);
		ELSIF d.dim # dim THEN
			IF ~(TensorFlag IN d.flags) &
				~(TemporaryFlag IN d.flags) THEN  (* no, not allowed*)
				HALT( 100 );
			END;
			d := GetArrayDesc(dim)
		(* ELSE keep as is *)
		END;
	END EnsureArrayDesc;

	PROCEDURE Halt( code: SIZE;  left, right, dest: ADDRESS );
	VAR reason: ARRAY 64 OF CHAR;
	BEGIN
		IF left # 0 THEN Report( "Source operand ", left ) END;
		IF right # 0 THEN Report( "Source operand 2 ", right ) END;
		IF dest # 0 THEN Report( "Dest operand ", dest ) END;

		IF code = GeometryMismatch THEN reason := "Geometry mismatch";
		ELSIF code = DimensionMismatch THEN reason := "Dimension mismatch";
		ELSIF code = AllocationForbidden THEN reason := "Allocation forbidden for dest";
		ELSE reason := "unknown";
		END;

		KernelLog.String( "ArrayBase Halt. Reason= " );  KernelLog.String( reason );  KernelLog.Ln;

		HALT( 400 );
	END Halt;

	(** patterns  ********************************************************************)

 (* find the largest block with a regular pattern of the form offset+{i*li: 0<=i<len}. d is dimension applying to the resulting loop *)

	PROCEDURE FindPattern1( left, dim: ADDRESS;  VAR d, len, linc: SIZE );
	BEGIN
		d := dim - 1;  len := GetLen( left, d );
		WHILE (len = 1) & (d > 0) DO DEC( d );  len := GetLen( left, d );
			END;   (* skip lower dimensions with len=1, in most cases d=0 *)
		linc := GetIncr( left, d );  DEC( d );
		WHILE (d >= 0) & (GetIncr( left, d ) = len * linc) DO
			len := len * GetLen( left, d );  DEC( d );
		END;   (* find dimension where pattern does not work any more *)
		INC( d );
		IF debug THEN
			KernelLog.String( "FindPattern1: " );  KernelLog.Int( len, 10 );  KernelLog.Int( linc, 10 );
			KernelLog.Ln;
		END;
	END FindPattern1;

(* find the largest block with a regular pattern of the form offset+{i*linc: 0<=i<len} for two arrays simultaneously. d is dimension applying to the resulting loop *)
	PROCEDURE FindPattern2( left, right: ADDRESS;  dim: SIZE;
												VAR d, len, linc, ri: SIZE );
	(* geometric precondition: lengths must coincide *)
	BEGIN
		d := dim - 1;  len := GetLen( left, d );  ASSERT( len = GetLen( right, d ) );
		WHILE (len = 1) & (d > 0) DO DEC( d );  len := GetLen( left, d );  END;
		linc := GetIncr( left, d );  ri := GetIncr( right, d );  DEC( d );
		WHILE (d >= 0) & (GetIncr( left, d ) = len * linc) & (GetIncr( right, d ) = len * ri) DO
			len := len * GetLen( left, d );  DEC( d );
		END;
		INC( d );
		IF debug THEN
			KernelLog.String( "FindPattern2: " );  KernelLog.Int( d, 10 );  KernelLog.Int( len, 10 );
			KernelLog.Int( linc, 10 );  KernelLog.Int( ri, 10 );  KernelLog.Ln;
		END;
	END FindPattern2;

(* find the largest block with a regular pattern of the form offset+{i*linc: 0<=i<len} for three arrays simultaneously. d is dimension applying to the resulting loop *)
	PROCEDURE FindPattern3( left, right, dest: ADDRESS;  dim: SIZE;
												VAR d, len, linc, ri, di: SIZE );
	(* geometric precondition: lengths must coincide *)
	BEGIN
		d := dim - 1;  len := GetLen( left, d );

		WHILE (len = 1) & (d > 0) DO DEC( d );  len := GetLen( left, d );
		END;
		linc := GetIncr( left, d );  ri := GetIncr( right, d );  di := GetIncr( dest, d );
		DEC( d );
		WHILE (d >= 0) & (GetIncr( left, d ) = len * linc) &
				(GetIncr( right, d ) = len * ri) & (GetIncr( dest, d ) = len * di) DO
			len := len * GetLen( left, d );  DEC( d );
		END;
		INC( d );
		IF debug THEN
			KernelLog.String( "FindPattern3: " );  KernelLog.Int( len, 10 );  KernelLog.Int( linc, 10 );
			KernelLog.Int( ri, 10 );  KernelLog.Int( di, 10 );  KernelLog.Ln;
		END;
	END FindPattern3;

	PROCEDURE Reverse( src: ADDRESS;  dim: SIZE );
	VAR d, sl, sr: SIZE;
	BEGIN
		d := 0;  sl := GetAdr( src );
		WHILE (d < dim) DO
			INC( sr, GetIncr( src, d ) * (GetLen( src, d ) - 1) );
			PutInc( src, d, -GetIncr( src, d ) );  INC( d );
		END;
		PutAdr( src, sl + sr );
	END Reverse;

(* check if forward copy may be performed *)
	PROCEDURE CopyUpCompatible( dest, src: ADDRESS;  VAR modes: SET );
	VAR d, sl, sr, dl, dr: SIZE;  dim: SIZE;
		(* precondition: len(src,i)=len(dest,i) *)
		(* for forward src -> dest copy compatibility src must not be overwritten before src is copied.
Sufficient (but not necessary) conditions:
	1.) no overlap: src right < dest left or src left > dest right  or
    2.) same geometry and src left >= dest left
    same geometry if ginc(s)=ginc(d) with
    ginc(s)=inc(s,0)*len(s,0)+inc(s,1)*len(s,1)+...
    ginc(d)=inc(d,0)*len(d,0)+inc(d,1)*len(d,1)+...
   *)
	BEGIN
		d := 0;  sl := GetAdr( src );  sr := sl;  dl := GetAdr( dest );  dr := dl;
		dim := GetDim( src );
		WHILE (d < dim) DO
			INC( sr, GetIncr( src, d ) * (GetLen( src, d ) - 1) );
			INC( dr, GetIncr( dest, d ) * (GetLen( dest, d ) - 1) );  INC( d );
		END;

		IF (sr < dl) OR (sl > dr) THEN  (* no overlap, both directions possible *)
		ELSIF ((sr - sl) = (dr - dl)) THEN
			IF (sl = dl) THEN  (* same memory region, both directions possible *)
			ELSIF (sl > dl) THEN
				EXCL( modes, down ) (* only copy up possible *)
			ELSE  (*sl < dl*)
				EXCL( modes, up ) (* only copy down possible *)
			END;
		ELSE
			modes := modes - {down, up};   (* neither nor *)
		END;
	END CopyUpCompatible;

	PROCEDURE AllocateTemp(dest: ADDRESS;  src: ADDRESS;
												Size: SIZE ): ANY;
	(* allocate a temporary block containing both descriptor and data *)
	BEGIN
		HALT(100);
		(*
		IF statistics THEN INC( allocTemp ) END;
		d := 0;  len := Size;  dim := GetDim( src );
		WHILE (d < dim) DO len := len * GetLen( src, d );  INC( d );  END;
		INC( len, 2 * dim * SIZEOF( SIZE ) + MathLenOffset );  SYSTEM.NEW( p, len );
		dest := SYSTEM.VAL( SIZE, p );
		PutAdr( dest, dest + dim * 2 * SIZEOF( SIZE ) + MathLenOffset );
		PutPtr( dest, dest );  PutDim( dest, dim );  len := Size;
		FOR i := 0 TO dim - 1 DO
			PutInc( dest, i, len );  PutLen( dest, i, GetLen( src, i ) );
			len := len * GetLen( src, i );
		END;
		(* Report("allocdest",dest,dim); *)
		RETURN p;
		*)
	END AllocateTemp;

	(*** procedures to traverse arrays and apply operators *)

	(** apply unary operator to array:  array SIGNED8 -> array SIGNED8 *)
	PROCEDURE ApplyGenericUnaryAAOpS(VAR dest: UnsafeArrayT; CONST left: UnsafeArrayT;  elementSize: SIZE; Loop: GenericUnaryAALoopS; op: PROCEDURE {DELEGATE} (x: SIGNED8): SIGNED8 );
		VAR loopd, looplen, loopli, loopdi: SIZE;  p: ANY;  glen: SIZE;
			origdest: ADDRESS;  modes: SET;
			dim: SIZE;

		PROCEDURE Traverse( dim: SIZE;  ladr, dadr: ADDRESS );
		VAR len: SIZE;  linc, dinc: SIZE;
		BEGIN
			IF dim = loopd THEN
				Loop( ladr, dadr, loopli, loopdi, looplen, op );
				IF conservative THEN INC( glen, looplen ) END;
			ELSE
				len := GetLen( left, dim );  linc := GetIncr( left, dim );
				dinc := GetIncr( dest, dim );  INC( dim );
				WHILE (len > 0) DO
					Traverse( dim, ladr, dadr );  INC( ladr, linc );  INC( dadr, dinc ); DEC( len );
				END;
			END;
		END Traverse;

	BEGIN
		dim := GetDim( left );
		origdest := 0;  modes := {up, down};
		(* allocate destination, if necessary *)
		IF ~AllocateSameT( dest, left, elementSize ) THEN
			CopyUpCompatible( dest, left, modes );
			IF up IN modes THEN  (* nothing to be done *)
			ELSIF down IN modes THEN Reverse( left, dim );  Reverse( dest, dim )
			ELSE origdest := dest;  p := AllocateTemp( dest, origdest, elementSize );
			END;
		END;

		IF debug THEN Report( "AA: left", left );  Report( "AA: dest", dest );  END;
		(* check pattern: longest piece that can be done with a loop *)
		FindPattern2( left, dest, dim, loopd, looplen, loopli, loopdi );
		Traverse( 0, left.adr, dest.adr);
		IF up IN modes THEN  (* nothing to be done *)
		ELSIF down IN modes THEN Reverse( left, dim );  Reverse( dest, dim )
		ELSE CopyContent( origdest, dest, elementSize );
		END;
	END ApplyGenericUnaryAAOpS;

	(** apply unary operator to array:  array SIGNED16 -> array SIGNED16 *)
	PROCEDURE ApplyGenericUnaryAAOpI(VAR dest: UnsafeArrayT; CONST left: UnsafeArrayT;  elementSize: SIZE; Loop: GenericUnaryAALoopI; op: PROCEDURE {DELEGATE}(x: SIGNED16): SIGNED16 );
		VAR loopd, looplen, loopli, loopdi: SIZE;  p: ANY;  glen: SIZE;
			origdest: ADDRESS;  modes: SET;
			dim: SIZE;

		PROCEDURE Traverse( dim: SIZE;  ladr, dadr: ADDRESS );
		VAR len: SIZE;  linc, dinc: SIZE;
		BEGIN
			IF dim = loopd THEN
				Loop( ladr, dadr, loopli, loopdi, looplen, op );
				IF conservative THEN INC( glen, looplen ) END;
			ELSE
				len := GetLen( left, dim );  linc := GetIncr( left, dim );
				dinc := GetIncr( dest, dim );  INC( dim );
				WHILE (len > 0) DO
					Traverse( dim, ladr, dadr );  INC( ladr, linc );  INC( dadr, dinc ); DEC( len );
				END;
			END;
		END Traverse;

	BEGIN
		dim := GetDim( left );
		origdest := 0;  modes := {up, down};
		(* allocate destination, if necessary *)
		IF ~AllocateSameT( dest, left, elementSize ) THEN
			CopyUpCompatible( dest, left, modes );
			IF up IN modes THEN  (* nothing to be done *)
			ELSIF down IN modes THEN Reverse( left, dim );  Reverse( dest, dim )
			ELSE origdest := dest;  p := AllocateTemp( dest, origdest, elementSize );
			END;
		END;

		IF debug THEN Report( "AA: left", left );  Report( "AA: dest", dest );  END;
		(* check pattern: longest piece that can be done with a loop *)
		FindPattern2( left, dest, dim, loopd, looplen, loopli, loopdi );
		Traverse( 0, left.adr, dest.adr);
		IF up IN modes THEN  (* nothing to be done *)
		ELSIF down IN modes THEN Reverse( left, dim );  Reverse( dest, dim )
		ELSE CopyContent( origdest, dest, elementSize );
		END;
	END ApplyGenericUnaryAAOpI;

	(** apply unary operator to array:  array SIZE -> array SIZE *)
	PROCEDURE ApplyGenericUnaryAAOpL(VAR dest: UnsafeArrayT; CONST left: UnsafeArrayT;  elementSize: SIZE; Loop: GenericUnaryAALoopL; op: PROCEDURE {DELEGATE}(x: SIGNED32): SIGNED32 );
		VAR loopd, looplen, loopli, loopdi: SIZE;  p: ANY;  glen: SIZE;
			origdest: ADDRESS;  modes: SET;
			dim: SIZE;

		PROCEDURE Traverse( dim: SIZE;  ladr, dadr: ADDRESS );
		VAR len: SIZE;  linc, dinc: SIZE;
		BEGIN
			IF dim = loopd THEN
				Loop( ladr, dadr, loopli, loopdi, looplen, op );
				IF conservative THEN INC( glen, looplen ) END;
			ELSE
				len := GetLen( left, dim );  linc := GetIncr( left, dim );
				dinc := GetIncr( dest, dim );  INC( dim );
				WHILE (len > 0) DO
					Traverse( dim, ladr, dadr );  INC( ladr, linc );  INC( dadr, dinc ); DEC( len );
				END;
			END;
		END Traverse;

	BEGIN
		dim := GetDim( left );
		origdest := 0;  modes := {up, down};
		(* allocate destination, if necessary *)
		IF ~AllocateSameT( dest, left, elementSize ) THEN
			CopyUpCompatible( dest, left, modes );
			IF up IN modes THEN  (* nothing to be done *)
			ELSIF down IN modes THEN Reverse( left, dim );  Reverse( dest, dim )
			ELSE origdest := dest;  p := AllocateTemp( dest, origdest, elementSize );
			END;
		END;

		IF debug THEN Report( "AA: left", left );  Report( "AA: dest", dest );  END;
		(* check pattern: longest piece that can be done with a loop *)
		FindPattern2( left, dest, dim, loopd, looplen, loopli, loopdi );
		Traverse( 0, left.adr, dest.adr);
		IF up IN modes THEN  (* nothing to be done *)
		ELSIF down IN modes THEN Reverse( left, dim );  Reverse( dest, dim )
		ELSE CopyContent( origdest, dest, elementSize );
		END;
	END ApplyGenericUnaryAAOpL;

	(** apply unary operator to array:  array SIGNED64 -> array SIGNED64 *)
	PROCEDURE ApplyGenericUnaryAAOpH(VAR dest: UnsafeArrayT; CONST left: UnsafeArrayT;  elementSize: SIZE; Loop: GenericUnaryAALoopH; op: PROCEDURE {DELEGATE}(x: SIGNED64): SIGNED64 );
		VAR loopd, looplen, loopli, loopdi: SIZE;  p: ANY;  glen: SIZE;
			origdest: ADDRESS;  modes: SET;
			dim: SIZE;

		PROCEDURE Traverse( dim: SIZE;  ladr, dadr: ADDRESS );
		VAR len: SIZE;  linc, dinc: SIZE;
		BEGIN
			IF dim = loopd THEN
				Loop( ladr, dadr, loopli, loopdi, looplen, op );
				IF conservative THEN INC( glen, looplen ) END;
			ELSE
				len := GetLen( left, dim );  linc := GetIncr( left, dim );
				dinc := GetIncr( dest, dim );  INC( dim );
				WHILE (len > 0) DO
					Traverse( dim, ladr, dadr );  INC( ladr, linc );  INC( dadr, dinc ); DEC( len );
				END;
			END;
		END Traverse;

	BEGIN
		dim := GetDim( left );
		origdest := 0;  modes := {up, down};
		(* allocate destination, if necessary *)
		IF ~AllocateSameT( dest, left, elementSize ) THEN
			CopyUpCompatible( dest, left, modes );
			IF up IN modes THEN  (* nothing to be done *)
			ELSIF down IN modes THEN Reverse( left, dim );  Reverse( dest, dim )
			ELSE origdest := dest;  p := AllocateTemp( dest, origdest, elementSize );
			END;
		END;

		IF debug THEN Report( "AA: left", left );  Report( "AA: dest", dest );  END;
		(* check pattern: longest piece that can be done with a loop *)
		FindPattern2( left, dest, dim, loopd, looplen, loopli, loopdi );
		Traverse( 0, left.adr, dest.adr);
		IF up IN modes THEN  (* nothing to be done *)
		ELSIF down IN modes THEN Reverse( left, dim );  Reverse( dest, dim )
		ELSE CopyContent( origdest, dest, elementSize );
		END;
	END ApplyGenericUnaryAAOpH;

	(** apply unary operator to array:  array FLOAT32 -> array FLOAT32 *)
	PROCEDURE ApplyGenericUnaryAAOpR(VAR dest: UnsafeArrayT; CONST left: UnsafeArrayT;  elementSize: SIZE; Loop: GenericUnaryAALoopR; op: PROCEDURE{DELEGATE}(x: FLOAT32): FLOAT32 );
		VAR loopd, looplen, loopli, loopdi: SIZE;  p: ANY;  glen: SIZE;
			origdest: ADDRESS;  modes: SET;
			dim: SIZE;

		PROCEDURE Traverse( dim: SIZE;  ladr, dadr: ADDRESS );
		VAR len: SIZE;  linc, dinc: SIZE;
		BEGIN
			IF dim = loopd THEN
				Loop( ladr, dadr, loopli, loopdi, looplen, op );
				IF conservative THEN INC( glen, looplen ) END;
			ELSE
				len := GetLen( left, dim );  linc := GetIncr( left, dim );
				dinc := GetIncr( dest, dim );  INC( dim );
				WHILE (len > 0) DO
					Traverse( dim, ladr, dadr );  INC( ladr, linc );  INC( dadr, dinc ); DEC( len );
				END;
			END;
		END Traverse;

	BEGIN
		dim := GetDim( left );
		origdest := 0;  modes := {up, down};
		(* allocate destination, if necessary *)
		IF ~AllocateSameT( dest, left, elementSize ) THEN
			CopyUpCompatible( dest, left, modes );
			IF up IN modes THEN  (* nothing to be done *)
			ELSIF down IN modes THEN Reverse( left, dim );  Reverse( dest, dim )
			ELSE origdest := dest;  p := AllocateTemp( dest, origdest, elementSize );
			END;
		END;

		IF debug THEN Report( "AA: left", left );  Report( "AA: dest", dest );  END;
		(* check pattern: longest piece that can be done with a loop *)
		FindPattern2( left, dest, dim, loopd, looplen, loopli, loopdi );
		Traverse( 0, left.adr, dest.adr);
		IF up IN modes THEN  (* nothing to be done *)
		ELSIF down IN modes THEN Reverse( left, dim );  Reverse( dest, dim )
		ELSE CopyContent( origdest, dest, elementSize );
		END;
	END ApplyGenericUnaryAAOpR;

	(** apply unary operator to array:  array FLOAT64 -> array FLOAT64 *)
	PROCEDURE ApplyGenericUnaryAAOpX(VAR dest: UnsafeArrayT; CONST left: UnsafeArrayT;  elementSize: SIZE; Loop: GenericUnaryAALoopX; op: PROCEDURE {DELEGATE} (x: FLOAT64): FLOAT64 );
		VAR loopd, looplen, loopli, loopdi: SIZE;  p: ANY;  glen: SIZE;
			origdest: ADDRESS;  modes: SET;
			dim: SIZE;

		PROCEDURE Traverse( dim: SIZE;  ladr, dadr: ADDRESS );
		VAR len: SIZE;  linc, dinc: SIZE;
		BEGIN
			IF dim = loopd THEN
				Loop( ladr, dadr, loopli, loopdi, looplen, op );
				IF conservative THEN INC( glen, looplen ) END;
			ELSE
				len := GetLen( left, dim );  linc := GetIncr( left, dim );
				dinc := GetIncr( dest, dim );  INC( dim );
				WHILE (len > 0) DO
					Traverse( dim, ladr, dadr );  INC( ladr, linc );  INC( dadr, dinc ); DEC( len );
				END;
			END;
		END Traverse;

	BEGIN
		dim := GetDim( left );
		origdest := 0;  modes := {up, down};
		(* allocate destination, if necessary *)
		IF ~AllocateSameT( dest, left, elementSize ) THEN
			CopyUpCompatible( dest, left, modes );
			IF up IN modes THEN  (* nothing to be done *)
			ELSIF down IN modes THEN Reverse( left, dim );  Reverse( dest, dim )
			ELSE origdest := dest;  p := AllocateTemp( dest, origdest, elementSize );
			END;
		END;

		IF debug THEN Report( "AA: left", left );  Report( "AA: dest", dest );  END;
		(* check pattern: longest piece that can be done with a loop *)
		FindPattern2( left, dest, dim, loopd, looplen, loopli, loopdi );
		Traverse( 0, left.adr, dest.adr);
		IF up IN modes THEN  (* nothing to be done *)
		ELSIF down IN modes THEN Reverse( left, dim );  Reverse( dest, dim )
		ELSE CopyContent( origdest, dest, elementSize );
		END;
	END ApplyGenericUnaryAAOpX;

	(** apply unary operator to array:  array COMPLEX32 -> array COMPLEX32 *)
	PROCEDURE ApplyGenericUnaryAAOpZ(VAR dest: UnsafeArrayT; CONST left: UnsafeArrayT;  elementSize: SIZE; Loop: GenericUnaryAALoopZ; op: PROCEDURE{DELEGATE}(x: COMPLEX32): COMPLEX32 );
		VAR loopd, looplen, loopli, loopdi: SIZE;  p: ANY;  glen: SIZE;
			origdest: ADDRESS;  modes: SET;
			dim: SIZE;

		PROCEDURE Traverse( dim: SIZE;  ladr, dadr: ADDRESS );
		VAR len: SIZE;  linc, dinc: SIZE;
		BEGIN
			IF dim = loopd THEN
				Loop( ladr, dadr, loopli, loopdi, looplen, op );
				IF conservative THEN INC( glen, looplen ) END;
			ELSE
				len := GetLen( left, dim );  linc := GetIncr( left, dim );
				dinc := GetIncr( dest, dim );  INC( dim );
				WHILE (len > 0) DO
					Traverse( dim, ladr, dadr );  INC( ladr, linc );  INC( dadr, dinc ); DEC( len );
				END;
			END;
		END Traverse;

	BEGIN
		dim := GetDim( left );
		origdest := 0;  modes := {up, down};
		(* allocate destination, if necessary *)
		IF ~AllocateSameT( dest, left, elementSize ) THEN
			CopyUpCompatible( dest, left, modes );
			IF up IN modes THEN  (* nothing to be done *)
			ELSIF down IN modes THEN Reverse( left, dim );  Reverse( dest, dim )
			ELSE origdest := dest;  p := AllocateTemp( dest, origdest, elementSize );
			END;
		END;

		IF debug THEN Report( "AA: left", left );  Report( "AA: dest", dest );  END;
		(* check pattern: longest piece that can be done with a loop *)
		FindPattern2( left, dest, dim, loopd, looplen, loopli, loopdi );
		Traverse( 0, left.adr, dest.adr);
		IF up IN modes THEN  (* nothing to be done *)
		ELSIF down IN modes THEN Reverse( left, dim );  Reverse( dest, dim )
		ELSE CopyContent( origdest, dest, elementSize );
		END;
	END ApplyGenericUnaryAAOpZ;

	(** apply unary operator to array:  array COMPLEX64 -> array COMPLEX64 *)
	PROCEDURE ApplyGenericUnaryAAOpLZ(VAR dest: UnsafeArrayT; CONST left: UnsafeArrayT;  elementSize: SIZE; Loop: GenericUnaryAALoopLZ; op: PROCEDURE{DELEGATE}(x: COMPLEX64): COMPLEX64 );
		VAR loopd, looplen, loopli, loopdi: SIZE;  p: ANY;  glen: SIZE;
			origdest: ADDRESS;  modes: SET;
			dim: SIZE;

		PROCEDURE Traverse( dim: SIZE;  ladr, dadr: ADDRESS );
		VAR len: SIZE;  linc, dinc: SIZE;
		BEGIN
			IF dim = loopd THEN
				Loop( ladr, dadr, loopli, loopdi, looplen, op );
				IF conservative THEN INC( glen, looplen ) END;
			ELSE
				len := GetLen( left, dim );  linc := GetIncr( left, dim );
				dinc := GetIncr( dest, dim );  INC( dim );
				WHILE (len > 0) DO
					Traverse( dim, ladr, dadr );  INC( ladr, linc );  INC( dadr, dinc ); DEC( len );
				END;
			END;
		END Traverse;

	BEGIN
		dim := GetDim( left );
		origdest := 0;  modes := {up, down};
		(* allocate destination, if necessary *)
		IF ~AllocateSameT( dest, left, elementSize ) THEN
			CopyUpCompatible( dest, left, modes );
			IF up IN modes THEN  (* nothing to be done *)
			ELSIF down IN modes THEN Reverse( left, dim );  Reverse( dest, dim )
			ELSE origdest := dest;  p := AllocateTemp( dest, origdest, elementSize );
			END;
		END;

		IF debug THEN Report( "AA: left", left );  Report( "AA: dest", dest );  END;
		(* check pattern: longest piece that can be done with a loop *)
		FindPattern2( left, dest, dim, loopd, looplen, loopli, loopdi );
		Traverse( 0, left.adr, dest.adr);
		IF up IN modes THEN  (* nothing to be done *)
		ELSIF down IN modes THEN Reverse( left, dim );  Reverse( dest, dim )
		ELSE CopyContent( origdest, dest, elementSize );
		END;
	END ApplyGenericUnaryAAOpLZ;

(** apply unary operator to array:  array -> array *)
	PROCEDURE ApplyUnaryAAOp*(VAR dest: UnsafeArrayT; CONST left: UnsafeArrayT; elementSize: SIZE;
														Loop: UnaryAALoop );
	VAR loopd, looplen, loopli, loopdi: SIZE;  p: ANY;  glen: SIZE;
		origdest: SIZE;  modes: SET;
		dim: SIZE;

		PROCEDURE Traverse( dim: SIZE;  ladr, dadr: ADDRESS );
		VAR len: SIZE;  linc, dinc: SIZE;
		BEGIN
			IF dim = loopd THEN
				Loop( ladr, dadr, loopli, loopdi, looplen );
				IF conservative THEN INC( glen, looplen ) END;
			ELSE
				len := GetLen( left, dim );  linc := GetIncr( left, dim );
				dinc := GetIncr( dest, dim );  INC( dim );
				WHILE (len > 0) DO
					Traverse( dim, ladr, dadr );  INC( ladr, linc );  INC( dadr, dinc );
					DEC( len );
				END;
			END;
		END Traverse;

	BEGIN
		dim := GetDim( left );

		origdest := 0;  modes := {up, down};
		(* allocate destination, if necessary *)
		IF ~AllocateSameT( dest, left, elementSize ) THEN
			CopyUpCompatible( dest, left, modes );
			IF up IN modes THEN  (* nothing to be done *)
			ELSIF down IN modes THEN Reverse( left, dim );  Reverse( dest, dim )
			ELSE origdest := dest;  p := AllocateTemp( dest, origdest, elementSize );
			END;
		END;
		(*
		(* allocate destination, if necessary *)
		IF GetAdr( dest ) = -1 THEN p := Allocate( left, dest, dim, elementSize )
		ELSIF CheckGeometry( left, dest, dim )
		END;
		*)
		IF debug THEN Report( "AA: left", left );  Report( "AA: dest", dest );  END;

		(* check pattern: longest piece that can be done with a loop *)
		FindPattern2( left, dest, dim, loopd, looplen, loopli, loopdi );
		Traverse( 0, GetAdr( left ), GetAdr( dest ) );
		IF up IN modes THEN  (* nothing to be done *)
		ELSIF down IN modes THEN Reverse( left, dim );  Reverse( dest, dim )
		ELSE CopyContent( origdest, dest, elementSize );
		END;
	END ApplyUnaryAAOp;

(** apply unary operator to array:  array -> scalar *)
	PROCEDURE ApplyUnaryASOp*( dest: ADDRESS; CONST left: UnsafeArrayT; Loop: UnaryASLoop );
	VAR loopd, looplen, loopli: SIZE;  glen: SIZE;
	VAR dim: SIZE;

		PROCEDURE Traverse( dim: SIZE;  ladr: ADDRESS );
		VAR len: SIZE;  linc: SIZE;
		BEGIN
			IF dim = loopd THEN
				Loop( ladr, dest, loopli, looplen );
				IF conservative THEN INC( glen, looplen ) END;
			ELSE
				len := GetLen( left, dim );  linc := GetIncr( left, dim );  INC( dim );
				WHILE (len > 0) DO Traverse( dim, ladr );  INC( ladr, linc );  DEC( len );  END;
			END;
		END Traverse;

	BEGIN
		dim := GetDim( left );
		IF debug THEN Report( "AS: left", left );  END;
		(* check pattern: longest piece that can be done with a loop *)
		IF conservative THEN glen := 0 END;
		FindPattern1( left, dim, loopd, looplen, loopli );  Traverse( 0, GetAdr( left ) );
		IF conservative THEN
			looplen := 1;
			WHILE (dim > 0) DO
				looplen := looplen * GetLen( left, dim - 1 );  DEC( dim );
			END;
			ASSERT( looplen = glen );
		END;
	END ApplyUnaryASOp;

(** apply unary operator to array:  scalar -> array *)
	PROCEDURE ApplyUnarySAOp*( VAR dest: UnsafeArrayT; right: ADDRESS;  Loop: UnarySALoop );
	VAR loopd, looplen, loopdi: SIZE;  glen: SIZE;
	VAR dim: SIZE;

		PROCEDURE Traverse( dim: SIZE;  dadr: ADDRESS );
		VAR len: SIZE;  dinc: SIZE;
		BEGIN
			IF dim = loopd THEN
				Loop( right, dadr, loopdi, looplen );
				IF conservative THEN INC( glen, looplen ) END;
			ELSE
				len := GetLen( dest, dim );  dinc := GetIncr( dest, dim );  INC( dim );
				WHILE (len > 0) DO Traverse( dim, dadr );  INC( dadr, dinc );  DEC( len );  END;
			END;
		END Traverse;

	BEGIN
		dim := GetDim( dest );
		IF debug THEN Report( "AS: dest", dest );  END;
		(* check pattern: longest piece that can be done with a loop *)
		IF conservative THEN glen := 0 END;
		FindPattern1( dest, dim, loopd, looplen, loopdi );  Traverse( 0, GetAdr( dest ) );
		IF conservative THEN
			looplen := 1;
			WHILE (dim > 0) DO
				looplen := looplen * GetLen( dest, dim - 1 );  DEC( dim );
			END;
			ASSERT( looplen = glen );
		END;
	END ApplyUnarySAOp;

(** apply binary operator : array x array -> array *)

	PROCEDURE ApplyBinaryAAAOp*( VAR dest: UnsafeArrayT; CONST left, right: UnsafeArrayT; elementSize: SIZE;
														Loop: BinaryAAALoop );
	VAR loopd, looplen, loopli, loopri, loopdi: SIZE;  p: ANY;  glen: SIZE;
		origdest: SIZE;  modes: SET;  dim: SIZE;

		PROCEDURE Traverse( dim: SIZE;  ladr, radr, dadr: ADDRESS );
		VAR len: SIZE;  linc, rinc, dinc: SIZE;
		BEGIN
			IF dim = loopd THEN
				Loop( ladr, radr, dadr, loopli, loopri, loopdi, looplen );
				IF conservative THEN INC( glen, looplen ) END;
			ELSE
				len := GetLen( left, dim );  linc := GetIncr( left, dim );
				rinc := GetIncr( right, dim );  dinc := GetIncr( dest, dim );  INC( dim );
				WHILE (len > 0) DO
					Traverse( dim, ladr, radr, dadr );  INC( ladr, linc );  INC( radr, rinc );
					INC( dadr, dinc );  DEC( len );
				END;
			END;
		END Traverse;

	BEGIN
		dim := GetDim( left );

		(* allocate destination, if necessary *)
		IF ~SameShape( left, right ) THEN
			Halt( GeometryMismatch, left, right, 0 )
		END;
		origdest := 0;  modes := {up, down};
		IF ~AllocateSameT( dest, left, elementSize ) THEN
			CopyUpCompatible( dest, left, modes );
			CopyUpCompatible( dest, right, modes );
			IF up IN modes THEN  (* nothing to be done *)
			ELSIF down IN modes THEN
				Reverse( left, dim );  Reverse( dest, dim );  Reverse( right, dim );
			ELSE
				origdest := dest;  p := AllocateTemp( dest, origdest, elementSize );   (* 1d field ? *)
			END;
		END;

		(* debugging *)
		IF debug THEN Report( "AAA:left", left );  Report( "AAA:right", right );  Report( "AAA:dest", dest );  END;
		(* check pattern: longest piece that can be done with a loop *)
		FindPattern3( left, right, dest, dim, loopd, looplen, loopli, loopri, loopdi );
		(*  run through dimensions  *)
		Traverse( 0, GetAdr( left ), GetAdr( right ), GetAdr( dest ) );
		IF up IN modes THEN  (* nothing to be done *)
		ELSIF down IN modes THEN
			Reverse( left, dim );  Reverse( dest, dim );  Reverse( right, dim );
		ELSE CopyContent( origdest, dest, elementSize );
		END;
	END ApplyBinaryAAAOp;

(** apply binary operator: array x scalar -> array *)

	PROCEDURE ApplyBinaryASAOp*( VAR dest: UnsafeArrayT; CONST left: UnsafeArrayT; right: ADDRESS;
														elementSize: SIZE;
														Loop: BinaryASALoop );
	VAR loopd, looplen, loopli, loopdi: SIZE;  glen: SIZE;
		origdest: SIZE;  modes: SET;  dim: SIZE;

		PROCEDURE Traverse( dim: SIZE;  ladr, dadr: ADDRESS );
		VAR len: SIZE;  linc, dinc: SIZE;
		BEGIN
			IF dim = loopd THEN
				Loop( ladr, right, dadr, loopli, loopdi, looplen );
				IF conservative THEN INC( glen, looplen ) END;
			ELSE
				len := GetLen( left, dim );  linc := GetIncr( left, dim );
				dinc := GetIncr( dest, dim );  INC( dim );
				WHILE (len > 0) DO
					Traverse( dim, ladr, dadr );  INC( ladr, linc );  INC( dadr, dinc );
					DEC( len );
				END;
			END;
		END Traverse;

	BEGIN
		dim := GetDim( left );
		(* allocate destination, if necessary *)
		origdest := 0;  modes := {up, down};

		IF ~AllocateSameT( dest, left, elementSize ) THEN
			CopyUpCompatible( dest, left, modes );
			IF up IN modes THEN  (* nothing to be done *)
			ELSIF down IN modes THEN Reverse( left, dim );  Reverse( dest, dim )
			ELSE origdest := dest;  HALT(100); (*p := AllocateTemp( dest, origdest, elementSize );*)
			END;
		END;
		(* debugging *)
		IF debug THEN Report( "ASA:left", left );  Report( "ASA:dest", dest );  END;
		(* check pattern: longest piece that can be done with a loop *)
		FindPattern2( left, dest, dim, loopd, looplen, loopli, loopdi );
		(*  run through dimensions  *)
		IF conservative THEN glen := 0 END;
		Traverse( 0, GetAdr( left ), GetAdr( dest ) );
		IF conservative THEN
			looplen := 1;
			WHILE (dim > 0) DO
				looplen := looplen * GetLen( left, dim - 1 );  DEC( dim );
			END;
			ASSERT( looplen = glen );
		END;
		IF up IN modes THEN  (* nothing to be done *)
		ELSIF down IN modes THEN Reverse( left, dim );  Reverse( dest, dim )
		ELSE CopyContent( origdest, dest, elementSize );
		END;
	END ApplyBinaryASAOp;

(** apply binary operator: array x array -> scalar *)

	PROCEDURE ApplyBinaryAASOp*( dest: ADDRESS; CONST left, right: UnsafeArrayT;  Loop: BinaryAASLoop );
	VAR loopd, looplen, loopli, loopri: SIZE;  glen: SIZE;
		dim: SIZE;

		PROCEDURE Traverse( dim: SIZE;  ladr, radr: ADDRESS );
		VAR len: SIZE;  linc, rinc: SIZE;
		BEGIN
			IF dim = loopd THEN
				Loop( ladr, radr, dest, loopli, loopri, looplen );
				IF conservative THEN INC( glen, looplen ) END;
			ELSE
				len := GetLen( left, dim );  linc := GetIncr( left, dim );
				rinc := GetIncr( right, dim );  INC( dim );
				WHILE (len > 0) DO
					Traverse( dim, ladr, radr );  INC( ladr, linc );  INC( radr, rinc );
					DEC( len );
				END;
			END;
		END Traverse;

	BEGIN
		dim := GetDim( left );
		(* check array lengths *)
		IF ~SameShape( left, right ) THEN
			Halt( GeometryMismatch, left, right, 0 )
		END;
		IF debug THEN Report( "AAS:left", left );  Report( "AAS:right", right );  END;
		(* check pattern: longest piece that can be done with a loop *)
		FindPattern2( left, right, dim, loopd, looplen, loopli, loopri );
		(*  run through dimensions  *)
		IF conservative THEN glen := 0 END;
		Traverse( 0, GetAdr( left ), GetAdr( right ) );
		IF conservative THEN
			looplen := 1;
			WHILE (dim > 0) DO
				looplen := looplen * GetLen( left, dim - 1 );  DEC( dim );
			END;
			ASSERT( looplen = glen );
		END;
	END ApplyBinaryAASOp;

(** special binary operator: array x array -> boolean *)

	PROCEDURE ApplyBinaryAABOp*( CONST left, right: UnsafeArrayT;
														Loop: BinaryAABLoop; geometryMismatchDefault: BOOLEAN ): BOOLEAN;
	VAR loopd, looplen, loopli, loopri: SIZE; dim: SIZE;

		PROCEDURE Traverse( dim: SIZE;  ladr, radr: ADDRESS ): BOOLEAN;
		VAR len: SIZE;  linc, rinc: SIZE;
		BEGIN
			IF dim = loopd THEN RETURN Loop( ladr, radr, loopli, loopri, looplen );
			ELSE
				len := GetLen( left, dim );  linc := GetIncr( left, dim );
				rinc := GetIncr( right, dim );  INC( dim );
				WHILE (len > 0) DO
					IF ~Traverse( dim, ladr, radr ) THEN RETURN FALSE END;
					INC( ladr, linc );  INC( radr, rinc );  DEC( len );
				END;
				RETURN TRUE;
			END;
		END Traverse;

	BEGIN
		dim := GetDim( left );
		(* check array lengths *)
		IF ~SameShape( left, right ) THEN
			RETURN geometryMismatchDefault
		END;
		(* is destination already allocated? (might be a temporary result) *)
		IF debug THEN Report( "AAB:left", left );  Report( "AAB:right", right );  END;
		(* check pattern: longest piece that can be done with a loop *)
		FindPattern2( left, right, dim, loopd, looplen, loopli, loopri );
		(*  run through dimensions  *)
		RETURN Traverse( 0, GetAdr( left ), GetAdr( right ) );
	END ApplyBinaryAABOp;

(** special binary operator: array x scalar -> boolean *)

	PROCEDURE ApplyBinaryASBOp( CONST left: UnsafeArrayT; right: ADDRESS;
														Loop: BinaryASBLoop ): BOOLEAN;
	VAR loopd, looplen, loopli: SIZE;  dim: SIZE;

		PROCEDURE Traverse( dim: SIZE;  ladr: ADDRESS ): BOOLEAN;
		VAR len: SIZE;  linc: SIZE;
		BEGIN
			IF dim = loopd THEN RETURN Loop( ladr, right, loopli, looplen );
			ELSE
				len := GetLen( left, dim );  linc := GetIncr( left, dim );  INC( dim );
				WHILE (len > 0) DO
					IF ~Traverse( dim, ladr ) THEN RETURN FALSE END;
					INC( ladr, linc );  DEC( len );
				END;
				RETURN TRUE;
			END;
		END Traverse;

	BEGIN
		dim := GetDim( left );
		IF debug THEN Report( "AAB:left", left );  END;
		(* check pattern: longest piece that can be done with a loop *)
		FindPattern1( left, dim, loopd, looplen, loopli );
		(*  run through dimensions  *)
		RETURN Traverse( 0, GetAdr( left ) );
	END ApplyBinaryASBOp;

	(**** operators *)

(*** copy *)
	PROCEDURE Copy4( ladr, dadr: ADDRESS; linc, dinc, len: SIZE );
	BEGIN
		WHILE len > 0 DO
			SYSTEM.PUT32(dadr, SYSTEM.GET32(ladr));
			INC(ladr, linc); INC(dadr, dinc); DEC(len);
		END;
	(*CODE {SYSTEM.i386}
		MOV	ECX, [EBP+ladr]	;  ECX := ladr
		MOV	EDX, [EBP+dadr]	;  EDX := dadr
		MOV	EBX, [EBP+len]	;  EBX := len
		start:
		CMP	EBX, 0	;
		JLE	end	;  WHILE EBX > 0 DO
		MOV	EAX, [ECX]	;  EAX := SYSTEM.GET32(ECX)
		MOV	[EDX], EAX	;  SYSTEM.PUT32(EDX, EAX))
		ADD	ECX, [EBP+linc]	;  INC(ECX, linc)
		ADD	EDX, [EBP+dinc]	;  INC(EDX, rinc)
		DEC	EBX	;  DEC(EBX)
		JMP	start
		end:*)
	END Copy4;

	PROCEDURE Copy2( ladr, dadr: ADDRESS; linc, dinc, len: SIZE );
	BEGIN
		WHILE len > 0 DO
			SYSTEM.PUT16(dadr, SYSTEM.GET16(ladr));
			INC(ladr, linc); INC(dadr, dinc); DEC(len);
		END;
	(*CODE {SYSTEM.i386}
		MOV	ECX, [EBP+ladr]	;  ECX := ladr
		MOV	EDX, [EBP+dadr]	;  EDX := dadr
		MOV	EBX, [EBP+len]	;  EBX := len
		start:
		CMP	EBX, 0	;
		JLE	end	;  WHILE EBX > 0 DO
		MOV	AX, [ECX]	;  EAX := SYSTEM.GET32(ECX)
		MOV	[EDX], AX	;  SYSTEM.PUT32(EDX, EAX))
		ADD	ECX, [EBP+linc]	;  INC(ECX, linc)
		ADD	EDX, [EBP+dinc]	;  INC(EDX, rinc)
		DEC	EBX	;  DEC(EBX)
		JMP	start
		end:*)
	END Copy2;

	PROCEDURE Copy1( ladr, dadr: ADDRESS; linc, dinc, len: SIZE );
	BEGIN
		WHILE len > 0 DO
			SYSTEM.PUT8(dadr, SYSTEM.GET8(ladr));
			INC(ladr, linc); INC(dadr, dinc); DEC(len);
		END;
	(*CODE {SYSTEM.i386}
		MOV	ECX, [EBP+ladr]	;  ECX := ladr
		MOV	EDX, [EBP+dadr]	;  EDX := dadr
		MOV	EBX, [EBP+len]	;  EBX := len
		start:
		CMP	EBX, 0	;
		JLE	end	;  WHILE EBX > 0 DO
		MOV	AL, [ECX]	;  EAX := SYSTEM.GET32(ECX)
		MOV	[EDX], AL	;  SYSTEM.PUT32(EDX, EAX))
		ADD	ECX, [EBP+linc]	;  INC(ECX, linc)
		ADD	EDX, [EBP+dinc]	;  INC(EDX, rinc)
		DEC	EBX	;  DEC(EBX)
		JMP	start
		end:*)
	END Copy1;

	PROCEDURE Copy8( ladr, dadr: ADDRESS; linc, dinc, len: SIZE );
	BEGIN
		WHILE len > 0 DO
			SYSTEM.PUT64(dadr, SYSTEM.GET64(ladr));
			INC(ladr, linc); INC(dadr, dinc); DEC(len);
		END;
	(*CODE {SYSTEM.i386}
		MOV	ECX, [EBP+ladr]	;  ECX := ladr
		MOV	EDX, [EBP+dadr]	;  EDX := dadr
		MOV	EBX, [EBP+len]	;  EBX := len
		start:
		CMP	EBX, 0	;
		JLE	end	;  WHILE EBX > 0 DO
		MOV	EAX, [ECX]	;  EAX := SYSTEM.GET32(ECX)
		MOV	[EDX], EAX	;  SYSTEM.PUT32(EDX, EAX))
		MOV	EAX, [ECX+4]	;  EAX := SYSTEM.GET32(ECX+4)
		MOV	[EDX+4], EAX	;  SYSTEM.PUT32(EDX+4, EAX))
		ADD	ECX, [EBP+linc]	;  INC(ECX, linc)
		ADD	EDX, [EBP+dinc]	;  INC(EDX, rinc)
		DEC	EBX	;  DEC(EBX)
		JMP	start
		end:*)
	END Copy8;

	PROCEDURE (*-*)MoveB*( srcadr, destadr, len: SIZE );
	BEGIN
		IF (len > 0)  THEN
			SYSTEM.MOVE(srcadr, destadr, len);
		ELSE
			len := -len;
			WHILE len > 0 DO
				SYSTEM.PUT8(destadr, SYSTEM.GET8(srcadr));
				DEC(srcadr); DEC(destadr); DEC(len);
			END;
		END;
	END MoveB;

	PROCEDURE CopyContent( dest, src: ADDRESS; elementSize: SIZE );   (**! optimize *)
	VAR loopd, looplen, loopli, loopdi: SIZE;  p: ANY;  glen: SIZE;
		origdest: ADDRESS;  modes: SET;  dim: SIZE;

		PROCEDURE Loop( ladr, dadr: ADDRESS; linc, dinc, len: SIZE );
		BEGIN
			IF (dinc = elementSize) & (linc = elementSize) THEN
				MoveB( ladr, dadr, len * elementSize );
			ELSIF (dinc = -elementSize) & (linc = -elementSize) THEN
				MoveB( ladr, dadr, - len * elementSize );
			ELSIF elementSize = 1 THEN
				Copy1( ladr, dadr, linc, dinc, len );
			ELSIF elementSize = 2 THEN
				Copy2( ladr, dadr, linc, dinc, len );
			ELSIF elementSize = 4 THEN
				Copy4( ladr, dadr, linc, dinc, len );
			ELSIF elementSize = 8 THEN
				Copy8( ladr, dadr, linc, dinc, len );
			ELSE  (* SYSTEM.MOVE is expensive ! *)
				WHILE (len > 0) DO
					SYSTEM.MOVE( ladr, dadr, elementSize );  DEC( len );  INC( ladr, linc );
					INC( dadr, dinc );
				END;
			END;
		END Loop;

		PROCEDURE Traverse( dim: SIZE;  ladr, dadr: ADDRESS );
		VAR len: SIZE;  linc, dinc: SIZE;
		BEGIN
			IF dim = loopd THEN
				Loop( ladr, dadr, loopli, loopdi, looplen );
				IF conservative THEN INC( glen, looplen ) END;
			ELSE
				len := GetLen( src, dim );  linc := GetIncr( src, dim );
				dinc := GetIncr( dest, dim );  INC( dim );
				WHILE (len > 0) DO
					Traverse( dim, ladr, dadr );  INC( ladr, linc );  INC( dadr, dinc );
					DEC( len );
				END;
			END;
		END Traverse;

	BEGIN
		dim := GetDim( src );

		origdest := 0;  modes := {up, down};   (* copy modes *)
		ASSERT( SameShape( src, dest ) );   (* must be ensured by caller *)

		CopyUpCompatible( dest, src, modes );
		IF up IN modes THEN  (* nothing to be done *)
		ELSIF down IN modes THEN  (* can only copy from top to bottom *)
			Reverse( src, dim );  Reverse( dest, dim )
		ELSE  (* can only copy via double buffer *)
			origdest := dest;  p := AllocateTemp( dest, origdest, elementSize );
		END;

		IF debug THEN Report( "AA: src", src );  Report( "AA: dest", dest );
		END;

		(* check pattern: longest piece that can be done with a loop *)
		FindPattern2( src, dest, dim, loopd, looplen, loopli, loopdi );

		Traverse( 0, GetAdr( src ), GetAdr( dest ) );

		IF up IN modes THEN  (* nothing to be done *)
		ELSIF down IN modes THEN Reverse( src, dim );  Reverse( dest, dim )
		ELSE CopyContent( origdest, dest, elementSize );
		END;
	END CopyContent;

	PROCEDURE AllocateSameT( VAR dest: UnsafeArrayT;  CONST src: UnsafeArrayT; elementsize: SIZE ): BOOLEAN;
	VAR data: ANY;  Size: SIZE;
		(* allocate a structure in dest compatible with src, if necessary. returns if allocation has taken place *)

		PROCEDURE NewData;
		VAR dim, len, size: SIZE;
		BEGIN
			dim := GetDim( src );  size := elementsize;
			PutDim( dest, dim );
			PutSize( dest, elementsize );
			WHILE (dim > 0) DO
				DEC( dim );  len := GetLen( src, dim );  PutLen( dest, dim, len );
				PutInc( dest, dim, size );  size := size * len;
			END;
			SYSTEM.NEW( data, size + ArrayAlignment);
			PutAdr( dest, Align(data));
			PutPtr( dest, data );
		END NewData;

	BEGIN
		IF dest # NIL THEN Size := GetSize( dest );  ASSERT ((Size=0) OR (Size = elementsize ));  END;
		IF debug THEN KernelLog.String( "Allocate same " );  Report( "allocation source", src );  Report( "allocation des", dest );  END;
		IF dest = NIL THEN  (* NIL pointer, guaranteed to be tensor *)
			dest := GetArrayDesc( GetDim( src ) );
			PutFlags(dest, {TensorFlag});
			NewData();
			RETURN TRUE;
		ELSIF GetDim( dest ) # GetDim( src ) THEN  (* different dimension *)
			(* check if re-allocation of descriptor is allowed *)
			IF ~(TensorFlag IN GetFlags( dest )) &
				~(TemporaryFlag IN GetFlags( dest )) THEN  (* no, not allowed*)
				HALT( 100 );
			END;
			dest := GetArrayDesc( GetDim( src ) );
			PutFlags(dest, {TensorFlag});
			NewData();
			RETURN TRUE;
		ELSIF (GetAdr( dest ) = 0) OR ~SameShape( dest, src ) THEN
			(* check if re-allocation of array data is allowed *)
			IF RangeFlag IN GetFlags( dest ) THEN  (* no! not allowed *)
				HALT( 100 );
			END;
			NewData();
			RETURN TRUE;
		ELSE  (* nothing to do *)
			RETURN FALSE;
		END;
	END AllocateSameT;

	PROCEDURE Assign*(VAR dest: ADDRESS; src: ADDRESS);
	VAR oldDest: ADDRESS;
	BEGIN
		IF (dest  # NIL) THEN
			IF (TensorFlag IN GetFlags( dest )) THEN (* old heap pointer overwritten *)
				oldDest := dest;
				#IF COOP THEN
					Heaps.Assign(dest, src);
				#ELSE
					Heaps.MarkPointer(src);
				#END
			ELSE
				(*
				Heaps.ResetMathArray(dest);
				*)
				dest := src;
			END;
		ELSE
(*			Heaps.Refer(src);*)
			dest := src;
		END;
	END Assign;

	PROCEDURE TempDescCopy( CONST src: UnsafeArrayT ): UnsafeArrayT;
	VAR dest: UnsafeArrayT; adr: ADDRESS;dim: SIZE;
	BEGIN
		dim := GetDim(src);
		dest := GetArrayDesc(dim);
		SYSTEM.MOVE( src, dest, dim * SIZEOF(LenInc) + MathLenOffset );
		dest.adr := NIL;
		SYSTEM.PUT(ADDRESS OF dest.ptr, NIL); (* no refcounting here ! *)
		PutFlags( dest, {} );
		RETURN dest;
	END TempDescCopy;

	(* used when arrays are passed by value *)
	PROCEDURE CopyArraySelf*( VAR dest: UnsafeArrayT; CONST src: UnsafeArrayT;  elementsize: SIZE );
	VAR p: UnsafeArrayT;
	BEGIN
		ASSERT( src = dest );
		p := TempDescCopy( dest ); (* copy and prepare dest to be copied over *)
		CopyArray( dest, p, elementsize );
	END CopyArraySelf;

	PROCEDURE CopyArray*( dest: UnsafeArray (* untraced! *);  CONST src: UnsafeArrayT; elementsize: SIZE );
	VAR srcdim, destdim: SIZE;
	BEGIN
		ASSERT(dest # NIL); (* only possible by compiler error *)
		IF GetDim( src ) # GetDim( dest ) THEN  (* not allowed but possible (tensor) *)
			srcdim := GetDim(src);
			destdim := GetDim(dest);
			(*
			Debugging.Stack("copy array");
			*)
			Report( "copy array source", src );  Report( "copy array dest", dest );
			HALT(100);
		ELSIF src = dest THEN  (* self copy *)
			CopyArraySelf( dest, src, elementsize );
		ELSE
			IF AllocateSameT( dest, src, elementsize ) THEN END;
			CopyContent( dest, src, elementsize )
		END;
	END CopyArray;

	PROCEDURE CopyTensorSelf*( VAR dest: UnsafeArrayT; CONST src: UnsafeArrayT; elementsize: SIZE );
	BEGIN
		dest := NIL;
		CopyTensor( dest, src, elementsize );
	END CopyTensorSelf;

	PROCEDURE CopyTensor*( VAR dest: UnsafeArrayT;  CONST src: UnsafeArrayT;
												elementsize: SIZE );
	BEGIN
		(* Report("dest",dest); Report("src",src); *)
		IF (src = NIL) THEN dest := NIL
		ELSIF (dest = NIL) OR ~(SameShape( dest, src )) OR (GetAdr( dest ) = 0) THEN
			IF AllocateSameT( dest, src, elementsize ) THEN END; (* includes check if allocation is allowed *)
			CopyContent( dest, src, elementsize );
		ELSIF dest = src THEN CopyTensorSelf( dest, src, elementsize );
		ELSE CopyContent( dest, src, elementsize )
		END;
	END CopyTensor;

	(* copy descriptor of src to that of dest. If not existent then create.*)
	PROCEDURE ShallowCopy*(VAR dest: UnsafeArrayT; CONST src: UnsafeArrayT);
	VAR ptr: ANY; flags: SET;

		PROCEDURE CopyDescriptor;
		BEGIN
			SafePut(dest.ptr, src.ptr);(* With refcount. GC! Must do before MOVE (NIL <- src.ptr), then copy redundant *)
			SYSTEM.MOVE( src , dest, MathLenOffset + SIZEOF(LenInc) *  GetDim( src ));
		END CopyDescriptor;

	BEGIN
		(*
			ShallowCopy is either called with a reference to a pointer in which case the dest pointer is safe
			or it is called with an array descriptor in which case a reallocation is forbidden. The pointer cannot escape.
		*)

		IF dest = 0 THEN  (* NIL pointer, guaranteed to be tensor *)
			dest := GetArrayDesc( GetDim( src ) );
			CopyDescriptor();
			PutFlags(dest, {TensorFlag});
		ELSIF GetDim( dest ) # GetDim( src ) THEN  (* different dimension *)
			flags := GetFlags(dest);
			(* check if re-allocation of descriptor is allowed *)
			IF ~(TensorFlag IN GetFlags( dest )) & ~(TemporaryFlag IN GetFlags( dest )) THEN  (* no, not allowed*)
				Halt(DimensionMismatch,src,0,dest);
			END;

			(* create a new descriptor!!! (added by Alexey) *)
			dest := GetArrayDesc( GetDim( src ) );
			CopyDescriptor();
			PutFlags(dest, flags);
		ELSE
			flags := GetFlags(dest);
			(* check if re-allocation of array data is allowed *)
			IF RangeFlag IN GetFlags( dest ) THEN  (* no! not allowed *)
				Halt(AllocationForbidden,src,0,dest);
			END;
			CopyDescriptor();
			PutFlags(dest, flags);
		END;
	END ShallowCopy;

(*
	PROCEDURE DescriptorCopy( src, dest: SIGNED32 );
	BEGIN
		IF debug THEN
			KernelLog.String( "DescriptorCopy from " );  KernelLog.Int( src, 1 );  KernelLog.String( " to " );
			KernelLog.Int( dest, 1 );  KernelLog.Ln;
		END;
		SYSTEM.MOVE( src, dest, 2*SIZEOF(ADDRESS) );   (* adr and ptr *)
		SYSTEM.MOVE( src + MathLenOffset, dest + MathLenOffset, SIZEOF(LenInc) *  GetDim( src ));   (* lens and increments *)
	END DescriptorCopy;
*)

	PROCEDURE ZeroCopy*(CONST src: ARRAY [?]; VAR dest: ARRAY {UNSAFE} [?]);
	BEGIN
		ShallowCopy(dest,src);
	END ZeroCopy;

	OPERATOR "ALIAS"*(CONST src: ARRAY [?]): ARRAY[?];
	BEGIN
		ZeroCopy(src, RESULT);
		RETURN RESULT
	END "ALIAS";

	PROCEDURE SameShape( l, r: ADDRESS ): BOOLEAN;
	VAR dim: SIZE;
	BEGIN
		dim := GetDim( l );
		IF dim # GetDim( r ) THEN RETURN FALSE END;
		WHILE (dim > 0) DO
			DEC( dim );
			IF GetLen( l, dim ) # GetLen( r, dim ) THEN RETURN FALSE END;
		END;
		RETURN TRUE;
	END SameShape;

	(*
	PROCEDURE ZeroCopyArray*( dest: ADDRESS;  src: ADDRESS; elementsize: SIGNED32 );
	(*
		called as ZeroCopy(A,B,Size) with enhanced arrays A,B
		check if deep copy can be avoided and if so then do a shallow copy
	*)
	BEGIN
		ASSERT( dest # 0 );   (* impossible *)
		IF GetDim( src ) # GetDim( dest ) THEN  (* not allowed but possible (tensor) *)
			HALT( 100 );
		ELSIF (RangeFlag IN GetFlags( src )) THEN
			(* must copy (and allocate) *)
			CopyArray( dest, src, elementsize );
		ELSIF (RangeFlag IN GetFlags( dest )) THEN  (* copy only allowed if shape matches *)
			IF ~SameShape( dest, src ) THEN HALT( 100 );
			ELSE CopyContent( dest, src, elementsize )
			END;
		ELSE DescriptorCopy( src, dest )
		END;
	END ZeroCopyArray;

	PROCEDURE ZeroCopyTensor*( VAR dest: ADDRESS;  src: ADDRESS; elementsize: SIGNED32 );
	(*
		called as ZeroCopy(A,B,Size) with A,B: ARRAY [?] OF ...
		check if deep copy can be avoided and if so then do a shallow copy
	*)
	BEGIN
		IF debug THEN
			KernelLog.String( "ZeroCopy2: " );  KernelLog.String( "ADDRESSOF(dest) " );  KernelLog.Int( ADDRESSOF( dest ), 10 );
			KernelLog.Ln;  KernelLog.String( "ADDRESSOF(src) " );  KernelLog.Int( ADDRESSOF( src ), 10 );  KernelLog.Ln;
			KernelLog.String( "dest " );  KernelLog.Int( dest, 10 );  KernelLog.Ln;  KernelLog.String( "src " );
			KernelLog.Int( src, 10 );  KernelLog.Ln;  KernelLog.String( "elementsize" );
			KernelLog.Int( elementsize, 10 );  KernelLog.Ln;
		END;

		IF (dest = 0) OR (TensorFlag IN GetFlags( dest )) THEN  (* descriptor allocation allowed *)
			IF (TensorFlag IN GetFlags( src )) THEN dest := src;
			ELSE
				CopyTensor( dest, src, elementsize );   (* allocate freshly *)
			END;
		ELSIF (RangeFlag IN GetFlags( src )) THEN
			(* must copy (and allocate) *)
			CopyTensor( dest, src, elementsize );
		ELSIF (RangeFlag IN GetFlags( dest )) THEN  (* descriptor copy forbidden *)
			IF SameShape( src, dest ) THEN CopyContent( dest, src, elementsize )
			ELSE
				HALT( 100 );   (* copy forbidden *)
			END;
		ELSIF GetDim( src ) = GetDim( dest ) THEN  (* descriptor copy allowed *)
			DescriptorCopy( src, dest );
		ELSE
			HALT( 100 );   (* different shapes: not allowed *)
		END;
	END ZeroCopyTensor;

	PROCEDURE ZeroCopy*( left, elementSize, dest, dim: SIGNED32 );   (**! optimize *)
	VAR i: SIGNED32;
	BEGIN
		IF GetPtr( dest ) = -1 THEN  (* zero copy forbidden, try data copy *)
			CopyContent( dest, left, elementSize )
		ELSE
			IF debug THEN
				KernelLog.String( "Zero Copy" );  KernelLog.Int( left, 10 );  KernelLog.Int( dest, 10 );
				KernelLog.Ln;
			END;
			PutPtr( dest, GetPtr( left ) );  PutAdr( dest, GetAdr( left ) );
			FOR i := 0 TO dim - 1 DO
				PutInc( dest, i, GetIncr( left, i ) );  PutLen( dest, i, GetLen( left, i ) );
			END;
		END;
	END ZeroCopy;
	*)
	(*** conversions ****)

(** SIGNED8 -> SIGNED16 *)
	PROCEDURE ConvertASAILoop( ladr, dadr: ADDRESS; linc, dinc, len: SIZE );
	BEGIN
		WHILE (len > 0) DO  (* SYSTEM.GET( ladr, lval );  dval := lval;  SYSTEM.PUT( dadr, dval ); *)
			SYSTEM.PUT16( dadr, SYSTEM.GET8( ladr ) );  INC( ladr, linc );  INC( dadr, dinc );
			DEC( len );
		END;
	END ConvertASAILoop;

	OPERATOR "@Convert"*(CONST src: ARRAY [ ? ] OF SIGNED8 ): ARRAY {UNSAFE} [?] OF SIGNED16;
	BEGIN
		ApplyUnaryAAOp( RESULT, src, SIZEOF( SIGNED16 ),ConvertASAILoop );
		RETURN RESULT
	END "@Convert";

	OPERATOR "LONG"*(CONST src: ARRAY [ ? ] OF SIGNED8 ): ARRAY {UNSAFE} [?] OF SIGNED16;
	BEGIN
		ApplyUnaryAAOp( RESULT, src, SIZEOF( SIGNED16 ),ConvertASAILoop );
		RETURN RESULT
	END "LONG";

(** SIGNED8 -> SIGNED32 *)
	PROCEDURE ConvertLoopSL( ladr, dadr: ADDRESS; linc, dinc, len: SIZE );
	BEGIN
		WHILE (len > 0) DO  (* SYSTEM.GET( ladr, lval );  dval := lval;  SYSTEM.PUT( dadr, dval ); *)
			SYSTEM.PUT32( dadr, SYSTEM.GET8( ladr ) );  INC( ladr, linc );  INC( dadr, dinc );
			DEC( len );
		END;
	END ConvertLoopSL;

	OPERATOR "@Convert"*(CONST src: ARRAY [ ? ] OF SIGNED8 ): ARRAY {UNSAFE} [?] OF SIGNED32;
	BEGIN
		ApplyUnaryAAOp(RESULT, src,SIZEOF( SIGNED32 ),ConvertLoopSL );
		RETURN RESULT
	END "@Convert";

(** SIGNED8 -> FLOAT32 *)
	PROCEDURE ConvertLoopSR( ladr, dadr: ADDRESS; linc, dinc, len: SIZE );
	VAR lval: SIGNED8;  dval: FLOAT32;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  dval := lval;  SYSTEM.PUT( dadr, dval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END ConvertLoopSR;

	OPERATOR "@Convert"*(CONST src: ARRAY [ ? ] OF SIGNED8 ): ARRAY {UNSAFE} [?] OF FLOAT32;
	BEGIN
		ApplyUnaryAAOp(RESULT, src,SIZEOF( FLOAT32 ), ConvertLoopSR );
		RETURN RESULT
	END "@Convert";

(** SIGNED8 -> FLOAT64 *)
	PROCEDURE ConvertLoopSX( ladr, dadr: ADDRESS; linc, dinc, len: SIZE );
	VAR lval: SIGNED8;  dval: FLOAT64;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  dval := lval;  SYSTEM.PUT( dadr, dval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END ConvertLoopSX;

	OPERATOR "@Convert"*(CONST src: ARRAY [ ? ] OF SIGNED8 ):  ARRAY {UNSAFE} [ ? ] OF FLOAT64;
	BEGIN
		ApplyUnaryAAOp(RESULT, src,SIZEOF( FLOAT64 ), ConvertLoopSX );
		RETURN RESULT
	END "@Convert";

(** SIGNED16 -> SIGNED8 (SHORT) *)
	PROCEDURE ConvertLoopIS( ladr, dadr: ADDRESS; linc, dinc, len: SIZE );
	VAR lval: SIGNED16;  dval: SIGNED8;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  dval := SHORT( lval );  SYSTEM.PUT( dadr, dval );
			INC( ladr, linc );  INC( dadr, dinc );  DEC( len );
		END;
	END ConvertLoopIS;

	OPERATOR "@Convert"*(CONST src: ARRAY [ ? ] OF SIGNED16 ): ARRAY {UNSAFE} [ ? ] OF SIGNED8;
	BEGIN
		ApplyUnaryAAOp(RESULT, src,SIZEOF( SIGNED8 ), ConvertLoopIS );
		RETURN RESULT
	END "@Convert";

	OPERATOR "SHORT"*(CONST src: ARRAY [ ? ] OF SIGNED16 ): ARRAY {UNSAFE} [ ? ] OF SIGNED8;
	BEGIN
		ApplyUnaryAAOp(RESULT, src,SIZEOF( SIGNED8 ), ConvertLoopIS );
		RETURN RESULT
	END "SHORT";

	(** SIGNED16 -> SIGNED32 *)

	PROCEDURE ConvertLoopIL( ladr, dadr: ADDRESS; linc, dinc, len: SIZE );
	BEGIN
		WHILE (len > 0) DO  (* SYSTEM.GET( ladr, lval );  dval := lval;  SYSTEM.PUT( dadr, dval );  *)
			SYSTEM.PUT32( dadr, SYSTEM.GET16( ladr ) );  INC( ladr, linc );  INC( dadr, dinc );
			DEC( len );
		END;
	END ConvertLoopIL;

	OPERATOR "@Convert"*(CONST src: ARRAY [ ? ] OF SIGNED16 ): ARRAY {UNSAFE} [ ? ] OF SIGNED32;
	BEGIN
		ApplyUnaryAAOp(RESULT, src,SIZEOF( SIGNED32 ), ConvertLoopIL );
		RETURN RESULT
	END "@Convert";

	OPERATOR "LONG"*(CONST src: ARRAY [ ? ] OF SIGNED16 ): ARRAY {UNSAFE} [ ? ] OF SIGNED32;
	BEGIN
		ApplyUnaryAAOp(RESULT, src,SIZEOF( SIGNED32 ), ConvertLoopIL );
		RETURN RESULT
	END "LONG";

(** SIGNED16 -> FLOAT32 *)
	PROCEDURE ConvertLoopIR( ladr, dadr: ADDRESS; linc, dinc, len: SIZE );
	VAR lval: SIGNED16;  dval: FLOAT32;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  dval := lval;  SYSTEM.PUT( dadr, dval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END ConvertLoopIR;

	OPERATOR "@Convert"*(CONST src: ARRAY [ ? ] OF SIGNED16 ):  ARRAY {UNSAFE} [ ? ] OF FLOAT32;
	BEGIN
		ApplyUnaryAAOp(RESULT, src,SIZEOF( FLOAT32 ), ConvertLoopIR );
		RETURN RESULT
	END "@Convert";

(** SIGNED16 -> FLOAT64 *)
	PROCEDURE ConvertLoopIX( ladr, dadr: ADDRESS; linc, dinc, len: SIZE );
	VAR lval: SIGNED16;  dval: FLOAT64;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  dval := lval;  SYSTEM.PUT( dadr, dval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END ConvertLoopIX;

	OPERATOR "@Convert"*(CONST src: ARRAY [ ? ] OF SIGNED16 ):  ARRAY {UNSAFE} [ ? ] OF FLOAT64;
	BEGIN
		ApplyUnaryAAOp(RESULT, src,SIZEOF( FLOAT64 ), ConvertLoopIX );
		RETURN RESULT
	END "@Convert";

(** SIGNED32 -> SIGNED16 (SHORT) *)
	PROCEDURE ConvertLoopLI( ladr, dadr: ADDRESS; linc, dinc, len: SIZE );
	VAR lval: SIGNED32;  dval: SIGNED16;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  dval := SHORT( lval );  SYSTEM.PUT( dadr, dval );
			INC( ladr, linc );  INC( dadr, dinc );  DEC( len );
		END;
	END ConvertLoopLI;

	OPERATOR "@Convert"*(CONST src: ARRAY [ ? ] OF SIGNED32 ): ARRAY {UNSAFE} [ ? ] OF SIGNED16;
	BEGIN
		ApplyUnaryAAOp(RESULT, src,SIZEOF( SIGNED16 ),ConvertLoopLI );
		RETURN RESULT
	END "@Convert";

	OPERATOR "SHORT"*(CONST src: ARRAY [ ? ] OF SIGNED32 ): ARRAY {UNSAFE} [ ? ] OF SIGNED16;
	BEGIN
		ApplyUnaryAAOp(RESULT, src,SIZEOF( SIGNED16 ),ConvertLoopLI );
		RETURN RESULT
	END "SHORT";

(** SIGNED32 -> FLOAT32 *)
	PROCEDURE ConvertLoopLR( ladr, dadr: ADDRESS; linc, dinc, len: SIZE );
	VAR lval: SIGNED32;  dval: FLOAT32;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  dval := lval;  SYSTEM.PUT( dadr, dval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END ConvertLoopLR;

	OPERATOR "@Convert"*(CONST src: ARRAY [ ? ] OF SIGNED32 ): ARRAY {UNSAFE} [ ? ] OF FLOAT32;
	BEGIN
		ApplyUnaryAAOp(RESULT, src,SIZEOF( FLOAT32 ), ConvertLoopLR );
		RETURN RESULT
	END "@Convert";

(** SIGNED32 -> FLOAT64 *)
	PROCEDURE ConvertLoopLX( ladr, dadr: ADDRESS; linc, dinc, len: SIZE );
	VAR lval: SIGNED32;  dval: FLOAT64;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  dval := lval;  SYSTEM.PUT( dadr, dval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END ConvertLoopLX;

	OPERATOR "@Convert"*(CONST src: ARRAY [ ? ] OF SIGNED32 ): ARRAY {UNSAFE} [ ? ] OF FLOAT64;
	BEGIN
		ApplyUnaryAAOp(RESULT, src,SIZEOF( FLOAT64 ), ConvertLoopLX );
		RETURN RESULT
	END "@Convert";

(** FLOAT32 -> SIGNED32 (ENTIER) *)
	PROCEDURE ConvertLoopRL( ladr, dadr: ADDRESS; linc, dinc, len: SIZE );
	VAR lval: FLOAT32;  dval: SIGNED32;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  dval := ENTIER( lval );  SYSTEM.PUT( dadr, dval );
			INC( ladr, linc );  INC( dadr, dinc );  DEC( len );
		END;
	END ConvertLoopRL;

	OPERATOR "@Convert"*(CONST src: ARRAY [ ? ] OF FLOAT32 ):  ARRAY {UNSAFE} [ ? ] OF SIGNED32;
	BEGIN
		ApplyUnaryAAOp(RESULT, src,SIZEOF( SIGNED32 ), ConvertLoopRL );
		RETURN RESULT
	END "@Convert";

	OPERATOR "ENTIER"*(CONST src: ARRAY [ ? ] OF FLOAT32 ):  ARRAY {UNSAFE} [ ? ] OF SIGNED32;
	BEGIN
		ApplyUnaryAAOp(RESULT, src,SIZEOF( SIGNED32 ), ConvertLoopRL );
		RETURN RESULT
	END "ENTIER";

(** FLOAT32 -> FLOAT64 *)
	PROCEDURE ConvertLoopRX( ladr, dadr: ADDRESS; linc, dinc, len: SIZE );
	VAR lval: FLOAT32;  dval: FLOAT64;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  dval := lval;  SYSTEM.PUT( dadr, dval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END ConvertLoopRX;

	OPERATOR "@Convert"*(CONST src: ARRAY [ ? ] OF FLOAT32 ):  ARRAY {UNSAFE} [ ? ] OF FLOAT64;
	BEGIN
		ApplyUnaryAAOp(RESULT, src,SIZEOF( FLOAT64 ), ConvertLoopRX );
		RETURN RESULT
	END "@Convert";

	OPERATOR "LONG"*(CONST src: ARRAY [ ? ] OF FLOAT32 ):  ARRAY {UNSAFE} [ ? ] OF FLOAT64;
	BEGIN
		ApplyUnaryAAOp(RESULT, src,SIZEOF( FLOAT64 ), ConvertLoopRX );
		RETURN RESULT
	END "LONG";

(** FLOAT64 -> FLOAT32 (SHORT) *)
	PROCEDURE ConvertLoopXR( ladr, dadr: ADDRESS; linc, dinc, len: SIZE );
	VAR lval: FLOAT64;  dval: FLOAT32;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  dval := SHORT( lval );  SYSTEM.PUT( dadr, dval );
			INC( ladr, linc );  INC( dadr, dinc );  DEC( len );
		END;
	END ConvertLoopXR;

	OPERATOR "@Convert"*(CONST src: ARRAY [ ? ] OF FLOAT64 ):  ARRAY {UNSAFE} [ ? ] OF FLOAT32;
	BEGIN
		ApplyUnaryAAOp(RESULT, src,SIZEOF( FLOAT32 ), ConvertLoopXR );
		RETURN RESULT
	END "@Convert";

	OPERATOR "SHORT"*(CONST src: ARRAY [ ? ] OF FLOAT64 ):  ARRAY {UNSAFE} [ ? ] OF FLOAT32;
	BEGIN
		ApplyUnaryAAOp(RESULT, src,SIZEOF( FLOAT32 ), ConvertLoopXR );
		RETURN RESULT
	END "SHORT";

(** FLOAT64 -> SIGNED32 (ENTIER) *)
	PROCEDURE ConvertLoopXL( ladr, dadr: ADDRESS; linc, dinc, len: SIZE );
	VAR lval: FLOAT64;  dval: SIGNED32;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  dval := ENTIER( lval );  SYSTEM.PUT( dadr, dval );
			INC( ladr, linc );  INC( dadr, dinc );  DEC( len );
		END;
	END ConvertLoopXL;

	OPERATOR "@Convert"*(CONST src: ARRAY [ ? ] OF FLOAT64 ):  ARRAY {UNSAFE} [ ? ] OF SIGNED32;
	BEGIN
		ApplyUnaryAAOp(RESULT, src,SIZEOF( SIGNED32 ),ConvertLoopXL );
		RETURN RESULT
	END "@Convert";

	OPERATOR "ENTIER"*(CONST src: ARRAY [ ? ] OF FLOAT64 ):  ARRAY {UNSAFE} [ ? ] OF SIGNED32;
	BEGIN
		ApplyUnaryAAOp(RESULT, src,SIZEOF( SIGNED32 ),ConvertLoopXL );
		RETURN RESULT
	END "ENTIER";

	(** SIZES **)

	PROCEDURE ConvertLoopLY( ladr, dadr: ADDRESS; linc, dinc, len: SIZE );
	VAR lval: SIGNED32;  dval: SIZE;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  dval := lval;  SYSTEM.PUT( dadr, dval );
			INC( ladr, linc );  INC( dadr, dinc );  DEC( len );
		END;
	END ConvertLoopLY;

	OPERATOR "@Convert"*(CONST src: ARRAY [ ? ] OF SIGNED32 ): ARRAY {UNSAFE} [ ? ] OF SIZE;
	BEGIN
		ApplyUnaryAAOp(RESULT, src,SIZEOF( SIZE ), ConvertLoopLY );
		RETURN RESULT
	END "@Convert";

	PROCEDURE ConvertLoopYZ( ladr, dadr: ADDRESS; linc, dinc, len: SIZE );
	VAR lval: SIZE;  dval: FLOAT64;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  dval := lval;  SYSTEM.PUT( dadr, dval );
			INC( ladr, linc );  INC( dadr, dinc );  DEC( len );
		END;
	END ConvertLoopYZ;

	OPERATOR "@Convert"*(CONST src: ARRAY [ ? ] OF SIZE ): ARRAY {UNSAFE} [ ? ] OF FLOAT64;
	BEGIN
		ApplyUnaryAAOp(RESULT, src,SIZEOF( FLOAT64 ), ConvertLoopYZ );
		RETURN RESULT
	END "@Convert";

	PROCEDURE ConvertLoopYR( ladr, dadr: ADDRESS; linc, dinc, len: SIZE );
	VAR lval: SIZE;  dval: FLOAT32;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  dval := lval;  SYSTEM.PUT( dadr, dval );
			INC( ladr, linc );  INC( dadr, dinc );  DEC( len );
		END;
	END ConvertLoopYR;

	OPERATOR "@Convert"*(CONST src: ARRAY [ ? ] OF SIZE ): ARRAY {UNSAFE} [ ? ] OF FLOAT32;
	BEGIN
		ApplyUnaryAAOp(RESULT, src,SIZEOF( FLOAT32 ), ConvertLoopYR );
		RETURN RESULT
	END "@Convert";

	(*** monadic not A -> ~A ********************************************************************)

(** BOOLEAN *)
	PROCEDURE NotLoopAB( ladr, dadr: ADDRESS; linc, dinc, len: SIZE );
	VAR lval: BOOLEAN;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.PUT( dadr, ~lval );  INC( ladr, linc );  INC( dadr, dinc );
			DEC( len );
		END;
	END NotLoopAB;

	OPERATOR "~"*(CONST src: ARRAY [ ? ] OF BOOLEAN): ARRAY {UNSAFE} [ ? ] OF BOOLEAN;
	BEGIN
		ApplyUnaryAAOp(RESULT, src,SIZEOF( BOOLEAN ), NotLoopAB );
		RETURN RESULT
	END "~";

	(*** monadic generic (A) -> -A  ********************************************************************)

(** SIGNED8 *)
	PROCEDURE GenericLoopS( ladr, dadr: ADDRESS; linc, dinc, len: SIZE; op: PROCEDURE {DELEGATE}(x: SIGNED8): SIGNED8 );
	VAR lval: SIGNED8;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.PUT( dadr, op(lval) );  INC( ladr, linc );  INC( dadr, dinc );
			DEC( len );
		END;
	END GenericLoopS;

(** SIGNED16 *)
	PROCEDURE GenericLoopI( ladr, dadr: ADDRESS; linc, dinc, len: SIZE; op: PROCEDURE {DELEGATE}(x: SIGNED16): SIGNED16 );
	VAR lval: SIGNED16;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.PUT( dadr, op(lval) );  INC( ladr, linc );  INC( dadr, dinc );
			DEC( len );
		END;
	END GenericLoopI;

(** SIGNED32 *)
	PROCEDURE GenericLoopL( ladr, dadr: ADDRESS; linc, dinc, len: SIZE; op: PROCEDURE {DELEGATE}(x: SIGNED32): SIGNED32 );
	VAR lval: SIGNED32;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.PUT( dadr, op(lval) );  INC( ladr, linc );  INC( dadr, dinc );
			DEC( len );
		END;
	END GenericLoopL;

(** SIGNED64 *)
	PROCEDURE GenericLoopH( ladr, dadr: ADDRESS; linc, dinc, len: SIZE; op: PROCEDURE {DELEGATE}(x: SIGNED64): SIGNED64 );
	VAR lval: SIGNED64;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.PUT( dadr, op(lval) );  INC( ladr, linc );  INC( dadr, dinc );
			DEC( len );
		END;
	END GenericLoopH;

(** FLOAT32 *)
	PROCEDURE GenericLoopR( ladr, dadr: ADDRESS; linc, dinc, len: SIZE; op: PROCEDURE {DELEGATE}(x: FLOAT32): FLOAT32 );
	VAR lval: FLOAT32;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.PUT( dadr, op(lval) );  INC( ladr, linc );  INC( dadr, dinc );
			DEC( len );
		END;
	END GenericLoopR;

(** FLOAT64 *)
	PROCEDURE GenericLoopX( ladr, dadr: ADDRESS; linc, dinc, len: SIZE; op: PROCEDURE {DELEGATE} (x: FLOAT64): FLOAT64 );
	VAR lval: FLOAT64;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.PUT( dadr, op(lval) );  INC( ladr, linc );  INC( dadr, dinc );
			DEC( len );
		END;
	END GenericLoopX;

(** COMPLEX32 *)
	PROCEDURE GenericLoopZ( ladr, dadr: ADDRESS; linc, dinc, len: SIZE; op: PROCEDURE {DELEGATE}(x: COMPLEX32): COMPLEX32 );
	VAR lval,dval: POINTER{UNSAFE,UNTRACED} TO RECORD val: COMPLEX32 END;
	BEGIN
		WHILE (len > 0) DO
			lval := ladr;
			dval := dadr;
			dval.val := op(lval.val);
			INC( ladr, linc );  INC( dadr, dinc );
			DEC( len );
		END;
	END GenericLoopZ;

(** COMPLEX64 *)
	PROCEDURE GenericLoopLZ( ladr, dadr: ADDRESS; linc, dinc, len: SIZE; op: PROCEDURE {DELEGATE} (x: COMPLEX64): COMPLEX64 );
	VAR lval,dval: POINTER{UNSAFE,UNTRACED} TO RECORD val: COMPLEX64 END;
	BEGIN
		WHILE (len > 0) DO
			lval := ladr;
			dval := dadr;
			dval.val := op (lval.val);
			INC( ladr, linc );  INC( dadr, dinc );
			DEC( len );
		END;
	END GenericLoopLZ;

	(*** monadic minus A -> -A  ********************************************************************)

(** SIGNED8 *)
	PROCEDURE MinusLoopS( ladr, dadr: ADDRESS; linc, dinc, len: SIZE );
	VAR lval: SIGNED8;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.PUT( dadr, -lval );  INC( ladr, linc );  INC( dadr, dinc );
			DEC( len );
		END;
	END MinusLoopS;

	OPERATOR "-"*(CONST src: ARRAY [ ? ] OF SIGNED8): ARRAY {UNSAFE} [ ? ] OF SIGNED8;
	BEGIN
		ApplyUnaryAAOp(RESULT, src,SIZEOF( SIGNED8 ), MinusLoopS );
		RETURN RESULT
	END "-";

(** SIGNED16 *)
	PROCEDURE MinusLoopI( ladr, dadr: ADDRESS; linc, dinc, len: SIZE );
	VAR lval: SIGNED16;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.PUT( dadr, -lval );  INC( ladr, linc );  INC( dadr, dinc );
			DEC( len );
		END;
	END MinusLoopI;

	OPERATOR "-"*(CONST src: ARRAY [ ? ] OF SIGNED16): ARRAY {UNSAFE} [ ? ] OF SIGNED16;
	BEGIN
		ApplyUnaryAAOp(RESULT, src,SIZEOF( SIGNED16 ), MinusLoopI );
		RETURN RESULT
	END "-";

(** SIGNED32 *)
	PROCEDURE MinusLoopL( ladr, dadr: ADDRESS; linc, dinc, len: SIZE );
	VAR lval: SIGNED32;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.PUT( dadr, -lval );  INC( ladr, linc );  INC( dadr, dinc );
			DEC( len );
		END;
	END MinusLoopL;

	OPERATOR "-"*(CONST src: ARRAY [ ? ] OF SIGNED32): ARRAY {UNSAFE} [ ? ] OF SIGNED32;
	BEGIN
		ApplyUnaryAAOp(RESULT, src,SIZEOF( SIGNED32 ), MinusLoopL );
		RETURN RESULT
	END "-";

(** SIZE *)
	PROCEDURE MinusLoopY( ladr, dadr: ADDRESS; linc, dinc, len: SIZE );
	VAR lval: SIZE;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.PUT( dadr, -lval );  INC( ladr, linc );  INC( dadr, dinc );
			DEC( len );
		END;
	END MinusLoopY;

	OPERATOR "-"*(CONST src: ARRAY [ ? ] OF SIZE): ARRAY {UNSAFE} [ ? ] OF SIZE;
	BEGIN
		ApplyUnaryAAOp(RESULT, src,SIZEOF( SIZE ), MinusLoopY );
		RETURN RESULT
	END "-";

(** FLOAT32 *)
	PROCEDURE MinusLoopR( ladr, dadr: ADDRESS; linc, dinc, len: SIZE );
	VAR lval: FLOAT32;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.PUT( dadr, -lval );  INC( ladr, linc );  INC( dadr, dinc );
			DEC( len );
		END;
	END MinusLoopR;

	OPERATOR "-"*(CONST src: ARRAY [ ? ] OF FLOAT32): ARRAY {UNSAFE} [ ? ] OF FLOAT32;
	BEGIN
		IF debug THEN KernelLog.String( "MinusAR" );  KernelLog.Ln;  END;
		ApplyUnaryAAOp(RESULT, src,SIZEOF( FLOAT32 ), MinusLoopR );
		RETURN RESULT
	END "-";

(** FLOAT64 *)
	PROCEDURE MinusLoopX( ladr, dadr: ADDRESS; linc, dinc, len: SIZE );
	VAR lval: FLOAT64;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.PUT( dadr, -lval );  INC( ladr, linc );  INC( dadr, dinc );
			DEC( len );
		END;
	END MinusLoopX;

	OPERATOR "-"*(CONST src: ARRAY [ ? ] OF FLOAT64): ARRAY {UNSAFE} [ ? ] OF FLOAT64;
	BEGIN
		ApplyUnaryAAOp(RESULT, src, SIZEOF( FLOAT64 ),
									MinusLoopX );
		RETURN RESULT
	END "-";

	(*** add array + array -> array  ********************************************************************)

(** SIGNED8 *)
	PROCEDURE AddASASLoop( ladr, radr, dadr: ADDRESS; linc, rinc, dinc, len: SIZE );
	VAR lval, rval: SIGNED8;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.PUT( dadr, lval + rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END AddASASLoop;

	OPERATOR "+"*(CONST left,right: ARRAY [?] OF SIGNED8): ARRAY {UNSAFE} [?] OF SIGNED8;
	BEGIN
		ApplyBinaryAAAOp( RESULT, left, right,
										SIZEOF( SIGNED8 ), AddASASLoop );
		RETURN RESULT
	END "+";

(** SIGNED16 *)
	PROCEDURE AddAIAILoop( ladr, radr, dadr: ADDRESS; linc, rinc, dinc, len: SIZE );
	VAR lval, rval: SIGNED16;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.PUT( dadr, lval + rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END AddAIAILoop;

	OPERATOR "+"*(CONST left,right: ARRAY [?] OF SIGNED16): ARRAY {UNSAFE} [?] OF SIGNED16;
	BEGIN
		ApplyBinaryAAAOp( RESULT, left, right,
										SIZEOF( SIGNED16 ), AddAIAILoop );
		RETURN RESULT
	END "+";

(** SIGNED32 *)
	PROCEDURE AddALALLoop( ladr, radr, dadr: ADDRESS; linc, rinc, dinc, len: SIZE );
	VAR lval, rval: SIGNED32;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.PUT( dadr, lval + rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END AddALALLoop;

	OPERATOR "+"*(CONST left,right: ARRAY [?] OF SIGNED32): ARRAY {UNSAFE} [?] OF SIGNED32;
	BEGIN
		ApplyBinaryAAAOp( RESULT, left, right,
										SIZEOF( SIGNED32 ), AddALALLoop );
		RETURN RESULT
	END "+";

(** FLOAT32 *)
	PROCEDURE AddARARLoop( ladr, radr, dadr: ADDRESS; linc, rinc, dinc, len: SIZE );
	VAR lval, rval: FLOAT32;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.PUT( dadr, lval + rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END AddARARLoop;

	OPERATOR "+"*(CONST left,right: ARRAY [?] OF FLOAT32): ARRAY {UNSAFE} [?] OF FLOAT32;
	BEGIN
		ApplyBinaryAAAOp( RESULT, left, right, SIZEOF( FLOAT32 ),
										loopAddARAR );
		RETURN RESULT
	END "+";

(** FLOAT64 *)
	PROCEDURE AddAXAXLoop( ladr, radr, dadr: ADDRESS; linc, rinc, dinc, len: SIZE );
	VAR lval, rval: FLOAT64;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.PUT( dadr, lval + rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END AddAXAXLoop;

	OPERATOR "+"*(CONST left,right: ARRAY [?] OF FLOAT64): ARRAY {UNSAFE} [?] OF FLOAT64;
	BEGIN
		ApplyBinaryAAAOp( RESULT, left, right,
										SIZEOF( FLOAT64 ), loopAddAXAX );
		RETURN RESULT
	END "+";

(** COMPLEX32 *)
	PROCEDURE AddAZAZLoop( ladr, radr, dadr: ADDRESS; linc, rinc, dinc, len: SIZE );
	VAR lval, rval: COMPLEX32;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.PUT( dadr, lval + rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END AddAZAZLoop;

	OPERATOR "+"*(CONST left,right: ARRAY [?] OF COMPLEX32): ARRAY {UNSAFE} [?] OF COMPLEX32;
	BEGIN
		ApplyBinaryAAAOp( RESULT, left, right,
										SIZEOF( COMPLEX32 ), loopAddAZAZ );
		RETURN RESULT
	END "+";

(** SIGNED64 *)
	PROCEDURE AddAHAHLoop( ladr, radr, dadr: ADDRESS; linc, rinc, dinc, len: SIZE );
	VAR lval, rval: SIGNED64;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.PUT( dadr, lval + rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END AddAHAHLoop;

	OPERATOR "+"*(CONST left,right: ARRAY [?] OF SIGNED64): ARRAY {UNSAFE} [?] OF SIGNED64;
	BEGIN
		ApplyBinaryAAAOp( RESULT, left, right,
										SIZEOF( SIGNED64 ), AddAHAHLoop);
		RETURN RESULT
	END "+";

(** SIZE *)
	PROCEDURE AddAYAYLoop( ladr, radr, dadr: ADDRESS; linc, rinc, dinc, len: SIZE );
	VAR lval, rval: SIZE;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.PUT( dadr, lval + rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END AddAYAYLoop;

	OPERATOR "+"*(CONST left,right: ARRAY [?] OF SIZE): ARRAY {UNSAFE} [?] OF SIZE;
	BEGIN
		ApplyBinaryAAAOp( RESULT, left, right,
										SIZEOF( SIZE ), AddAYAYLoop);
		RETURN RESULT
	END "+";

(** COMPLEX64 *)
	PROCEDURE AddALZALZLoop( ladr, radr, dadr: ADDRESS; linc, rinc, dinc, len: SIZE );
	VAR lvalRe, lvalIm, rvalRe, rvalIm: FLOAT64;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lvalRe ); SYSTEM.GET( ladr+SIZEOF(FLOAT64), lvalIm );
			SYSTEM.GET( radr, rvalRe ); SYSTEM.GET( radr+SIZEOF(FLOAT64), rvalIm );
			SYSTEM.PUT( dadr, lvalRe+rvalRe ); SYSTEM.PUT( dadr+SIZEOF(FLOAT64), lvalIm+rvalIm );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );
			DEC( len );
		END;
	END AddALZALZLoop;

	OPERATOR "+"*(CONST left,right: ARRAY [?] OF COMPLEX64): ARRAY {UNSAFE} [?] OF COMPLEX64;
	BEGIN
		ApplyBinaryAAAOp( RESULT, left, right,
										SIZEOF( COMPLEX64 ), loopAddALZALZ );
		RETURN RESULT
	END "+";

	(*** add array + scalar -> array and scalar + array -> array ********************************************************************)

(** SIGNED8 *)
	PROCEDURE AddASSSLoop( ladr, radr, dadr: ADDRESS; linc, dinc, len: SIZE );
	VAR lval, rval: SIGNED8;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.PUT( dadr, lval + rval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END AddASSSLoop;

	OPERATOR "+"*(CONST left: ARRAY [ ? ] OF SIGNED8; right: SIGNED8 ): ARRAY {UNSAFE} [ ? ] OF SIGNED8;
	BEGIN
		ApplyBinaryASAOp( RESULT , left, ADDRESSOF( right ),
										SIZEOF( SIGNED8 ), AddASSSLoop );
		RETURN RESULT
	END "+";

	OPERATOR "+"*(left: SIGNED8; CONST right: ARRAY [ ? ] OF SIGNED8): ARRAY {UNSAFE} [ ? ] OF SIGNED8;
	BEGIN
		ApplyBinaryASAOp( RESULT , right, ADDRESSOF( left ),
										SIZEOF( SIGNED8 ), AddASSSLoop );
		RETURN RESULT
	END "+";

(** SIGNED16 *)
	PROCEDURE AddAISILoop( ladr, radr, dadr: ADDRESS; linc, dinc, len: SIZE );
	VAR lval, rval: SIGNED16;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.PUT( dadr, lval + rval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END AddAISILoop;

	OPERATOR "+"*(CONST left: ARRAY [ ? ] OF SIGNED16; right: SIGNED16 ): ARRAY {UNSAFE} [ ? ] OF SIGNED16;
	BEGIN
		ApplyBinaryASAOp( RESULT , left, ADDRESSOF( right ),
										SIZEOF( SIGNED16 ), AddAISILoop );
		RETURN RESULT
	END "+";

	OPERATOR "+"*(left: SIGNED16; CONST right: ARRAY [ ? ] OF SIGNED16): ARRAY {UNSAFE} [ ? ] OF SIGNED16;
	BEGIN
		ApplyBinaryASAOp( RESULT , right, ADDRESSOF( left ),
										SIZEOF( SIGNED16 ), AddAISILoop );
		RETURN RESULT
	END "+";

(** SIGNED32 *)
	PROCEDURE AddALSLLoop( ladr, radr, dadr: ADDRESS; linc, dinc, len: SIZE );
	VAR lval, rval: SIGNED32;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.PUT( dadr, lval + rval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END AddALSLLoop;

	OPERATOR "+"*(CONST left: ARRAY [ ? ] OF SIGNED32; right: SIGNED32 ): ARRAY {UNSAFE} [ ? ] OF SIGNED32;
	BEGIN
		ApplyBinaryASAOp( RESULT , left, ADDRESSOF( right ),
										SIZEOF( SIGNED32 ), AddALSLLoop );
		RETURN RESULT
	END "+";

	OPERATOR "+"*(left: SIGNED32; CONST right: ARRAY [ ? ] OF SIGNED32): ARRAY {UNSAFE} [ ? ] OF SIGNED32;
	BEGIN
		ApplyBinaryASAOp( RESULT , right, ADDRESSOF( left ),
										SIZEOF( SIGNED32 ), AddALSLLoop );
		RETURN RESULT
	END "+";

(** FLOAT32 *)
	PROCEDURE AddARSRLoop( ladr, radr, dadr: ADDRESS; linc, dinc, len: SIZE );
	VAR lval, rval: FLOAT32;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.PUT( dadr, lval + rval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END AddARSRLoop;

	OPERATOR "+"*(CONST left: ARRAY [ ? ] OF FLOAT32; right: FLOAT32 ): ARRAY {UNSAFE} [ ? ] OF FLOAT32;
	BEGIN
		ApplyBinaryASAOp( RESULT , left, ADDRESSOF( right ), SIZEOF( FLOAT32 ),
										AddARSRLoop );
		RETURN RESULT
	END "+";

	OPERATOR "+"*(left: FLOAT32; CONST right: ARRAY [ ? ] OF FLOAT32): ARRAY {UNSAFE} [ ? ] OF FLOAT32;
	BEGIN
		ApplyBinaryASAOp( RESULT , right, ADDRESSOF( left ), SIZEOF( FLOAT32 ),
										AddARSRLoop );
		RETURN RESULT
	END "+";

(** FLOAT64 *)
	PROCEDURE AddAXSXLoop( ladr, radr, dadr: ADDRESS; linc, dinc, len: SIZE );
	VAR lval, rval: FLOAT64;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.PUT( dadr, lval + rval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END AddAXSXLoop;

	OPERATOR "+"*(CONST left: ARRAY [ ? ] OF FLOAT64; right: FLOAT64 ): ARRAY {UNSAFE} [ ? ] OF FLOAT64;
	BEGIN
		ApplyBinaryASAOp( RESULT , left, ADDRESSOF( right ),
										SIZEOF( FLOAT64 ), AddAXSXLoop );
		RETURN RESULT
	END "+";

	OPERATOR "+"*(left: FLOAT64; CONST right: ARRAY [ ? ] OF FLOAT64): ARRAY {UNSAFE} [ ? ] OF FLOAT64;
	BEGIN
		ApplyBinaryASAOp( RESULT , right, ADDRESSOF( left ),
										SIZEOF( FLOAT64 ), AddAXSXLoop );
		RETURN RESULT
	END "+";

(** COMPLEX32 *)
	PROCEDURE AddAZSZLoop( ladr, radr, dadr: ADDRESS; linc, dinc, len: SIZE );
	VAR lval, rval: COMPLEX32;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.PUT( dadr, lval + rval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END AddAZSZLoop;

	OPERATOR "+"*(CONST left: ARRAY [ ? ] OF COMPLEX32; right: COMPLEX32 ): ARRAY {UNSAFE} [ ? ] OF COMPLEX32;
	BEGIN
		ApplyBinaryASAOp( RESULT , left, ADDRESSOF( right ), SIZEOF( COMPLEX32 ),
										AddAZSZLoop );
		RETURN RESULT
	END "+";

	OPERATOR "+"*(left: COMPLEX32; CONST right: ARRAY [ ? ] OF COMPLEX32): ARRAY {UNSAFE} [ ? ] OF COMPLEX32;
	BEGIN
		ApplyBinaryASAOp( RESULT , right, ADDRESSOF( left ), SIZEOF( COMPLEX32 ),
										AddAZSZLoop );
		RETURN RESULT
	END "+";

(** SIGNED64 *)
	PROCEDURE AddAHSHLoop( ladr, radr, dadr: ADDRESS; linc, dinc, len: SIZE );
	VAR lval, rval: SIGNED64;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.PUT( dadr, lval + rval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END AddAHSHLoop;

	OPERATOR "+"*(CONST left: ARRAY [ ? ] OF SIGNED64; right: SIGNED64 ): ARRAY {UNSAFE} [ ? ] OF SIGNED64;
	BEGIN
		ApplyBinaryASAOp( RESULT , left, ADDRESSOF( right ), SIZEOF( SIGNED64 ),
										AddAHSHLoop );
		RETURN RESULT
	END "+";

	OPERATOR "+"*(left: SIGNED64; CONST right: ARRAY [ ? ] OF SIGNED64): ARRAY {UNSAFE} [ ? ] OF SIGNED64;
	BEGIN
		ApplyBinaryASAOp( RESULT , right, ADDRESSOF( left ), SIZEOF( SIGNED64 ),
										AddAHSHLoop );
		RETURN RESULT
	END "+";

(** SIZE  *)
	PROCEDURE AddAYSYLoop( ladr, radr, dadr: ADDRESS; linc, dinc, len: SIZE );
	VAR lval, rval: SIZE;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.PUT( dadr, lval + rval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END AddAYSYLoop;

	OPERATOR "+"*(CONST left: ARRAY [ ? ] OF SIZE; right: SIZE ): ARRAY {UNSAFE} [ ? ] OF SIZE;
	BEGIN
		ApplyBinaryASAOp( RESULT , left, ADDRESSOF( right ), SIZEOF( SIZE ),
										AddAYSYLoop );
		RETURN RESULT
	END "+";

	OPERATOR "+"*(left: SIZE; CONST right: ARRAY [ ? ] OF SIZE): ARRAY {UNSAFE} [ ? ] OF SIZE;
	BEGIN
		ApplyBinaryASAOp( RESULT , right, ADDRESSOF( left ), SIZEOF( SIZE ),
										AddAYSYLoop );
		RETURN RESULT
	END "+";

(** COMPLEX64 *)
	PROCEDURE AddALZSLZLoop( ladr, radr, dadr: ADDRESS; linc, dinc, len: SIZE );
	VAR lvalRe, lvalIm, rvalRe, rvalIm: FLOAT64;
	BEGIN
		SYSTEM.GET( radr, rvalRe ); SYSTEM.GET( radr+SIZEOF(FLOAT64), rvalIm );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lvalRe ); SYSTEM.GET( ladr+SIZEOF(FLOAT64), lvalIm );
			SYSTEM.PUT( dadr, lvalRe + rvalRe ); SYSTEM.PUT( dadr+SIZEOF(FLOAT64), lvalIm + rvalIm );
			INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END AddALZSLZLoop;

	OPERATOR "+"*(CONST left: ARRAY [ ? ] OF COMPLEX64; right: COMPLEX64 ): ARRAY {UNSAFE} [ ? ] OF COMPLEX64;
	BEGIN
		ApplyBinaryASAOp( RESULT , left, ADDRESSOF( right ), SIZEOF( COMPLEX64 ),
										AddALZSLZLoop );
		RETURN RESULT
	END "+";

	OPERATOR "+"*(left: COMPLEX64; CONST right: ARRAY [ ? ] OF COMPLEX64): ARRAY {UNSAFE} [ ? ] OF COMPLEX64;
	BEGIN
		ApplyBinaryASAOp( RESULT , right, ADDRESSOF( left ), SIZEOF( COMPLEX64 ),
										AddALZSLZLoop );
		RETURN RESULT
	END "+";

	(*** subtraction array - array -> array  ********************************************************************)

(** SIGNED8 *)
	PROCEDURE SubASASLoop( ladr, radr, dadr: ADDRESS; linc, rinc, dinc, len: SIZE );
	VAR lval, rval: SIGNED8;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.PUT( dadr, lval - rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END SubASASLoop;

	OPERATOR "-"*(CONST left,right: ARRAY [?] OF SIGNED8): ARRAY {UNSAFE} [?] OF SIGNED8;
	BEGIN
		ApplyBinaryAAAOp( RESULT, left, right,
										SIZEOF( SIGNED8 ), SubASASLoop );
		RETURN RESULT
	END "-";

(** SIGNED16 *)
	PROCEDURE SubAIAILoop( ladr, radr, dadr: ADDRESS; linc, rinc, dinc, len: SIZE );
	VAR lval, rval: SIGNED16;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.PUT( dadr, lval - rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END SubAIAILoop;

	OPERATOR "-"*(CONST left,right: ARRAY [?] OF SIGNED16): ARRAY {UNSAFE} [?] OF SIGNED16;
	BEGIN
		ApplyBinaryAAAOp( RESULT, left, right,
										SIZEOF( SIGNED16 ), SubAIAILoop );
		RETURN RESULT
	END "-";

(** SIGNED32 *)
	PROCEDURE SubALALLoop( ladr, radr, dadr: ADDRESS; linc, rinc, dinc, len: SIZE );
	VAR lval, rval: SIGNED32;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.PUT( dadr, lval - rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END SubALALLoop;

	OPERATOR "-"*(CONST left,right: ARRAY [?] OF SIGNED32): ARRAY {UNSAFE} [?] OF SIGNED32;
	BEGIN
		ApplyBinaryAAAOp( RESULT, left, right,
										SIZEOF( SIGNED32 ), SubALALLoop );
		RETURN RESULT
	END "-";

(** SIZE *)
	PROCEDURE SubAYAYLoop( ladr, radr, dadr: ADDRESS; linc, rinc, dinc, len: SIZE );
	VAR lval, rval: SIZE;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.PUT( dadr, lval - rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END SubAYAYLoop;

	OPERATOR "-"*(CONST left,right: ARRAY [?] OF SIZE): ARRAY {UNSAFE} [?] OF SIZE;
	BEGIN
		ApplyBinaryAAAOp( RESULT, left, right,
										SIZEOF( SIZE ), SubAYAYLoop );
		RETURN RESULT
	END "-";

(** FLOAT32 *)
	PROCEDURE SubARARLoop( ladr, radr, dadr: ADDRESS; linc, rinc, dinc, len: SIZE );
	VAR lval, rval: FLOAT32;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.PUT( dadr, lval - rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END SubARARLoop;

	OPERATOR "-"*(CONST left,right: ARRAY [?] OF FLOAT32): ARRAY {UNSAFE} [?] OF FLOAT32;
	BEGIN
		ApplyBinaryAAAOp( RESULT, left, right, SIZEOF( FLOAT32 ),
										loopSubARAR );
		RETURN RESULT
	END "-";

(** FLOAT64 *)
	PROCEDURE SubAXAXLoop( ladr, radr, dadr: ADDRESS; linc, rinc, dinc, len: SIZE );
	VAR lval, rval: FLOAT64;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.PUT( dadr, lval - rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END SubAXAXLoop;

	OPERATOR "-"*(CONST left,right: ARRAY [?] OF FLOAT64): ARRAY {UNSAFE} [?] OF FLOAT64;
	BEGIN
		ApplyBinaryAAAOp( RESULT, left, right,
										SIZEOF( FLOAT64 ), loopSubAXAX );
		RETURN RESULT
	END "-";

(** COMPLEX32 *)
	PROCEDURE SubAZAZLoop( ladr, radr, dadr: ADDRESS; linc, rinc, dinc, len: SIZE );
	VAR lval, rval: COMPLEX32;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.PUT( dadr, lval - rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END SubAZAZLoop;

	OPERATOR "-"*(CONST left,right: ARRAY [?] OF COMPLEX32): ARRAY {UNSAFE} [?] OF COMPLEX32;
	BEGIN
		ApplyBinaryAAAOp( RESULT, left, right,
										SIZEOF( COMPLEX32 ), loopSubAZAZ );
		RETURN RESULT
	END "-";

(** COMPLEX64 *)
	PROCEDURE SubALZALZLoop( ladr, radr, dadr: ADDRESS; linc, rinc, dinc, len: SIZE );
	VAR lvalRe, lvalIm, rvalRe, rvalIm: FLOAT64;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lvalRe ); SYSTEM.GET( ladr+SIZEOF(FLOAT64), lvalIm );
			SYSTEM.GET( radr, rvalRe ); SYSTEM.GET( radr+SIZEOF(FLOAT64), rvalIm );
			SYSTEM.PUT( dadr, lvalRe-rvalRe ); SYSTEM.PUT( dadr+SIZEOF(FLOAT64), lvalIm-rvalIm );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );
			DEC( len );
		END;
	END SubALZALZLoop;

	OPERATOR "-"*(CONST left,right: ARRAY [?] OF COMPLEX64): ARRAY {UNSAFE} [?] OF COMPLEX64;
	BEGIN
		ApplyBinaryAAAOp( RESULT, left, right,
										SIZEOF( COMPLEX64 ), loopSubALZALZ );
		RETURN RESULT
	END "-";

	(*** subtraction array-scalar -> array  ********************************************************************)

(** SIGNED8 *)
	OPERATOR "-"*(CONST left: ARRAY [ ? ] OF SIGNED8; right: SIGNED8 ): ARRAY {UNSAFE} [ ? ] OF SIGNED8;   (* a: left, b: right, c: dest *)
	BEGIN
		RESULT := left + (-right);
		RETURN RESULT
	END "-";

(** SIGNED16 *)
	OPERATOR "-"*(CONST left: ARRAY [ ? ] OF SIGNED16; right: SIGNED16 ): ARRAY {UNSAFE} [ ? ] OF SIGNED16;
	BEGIN
		RESULT := left + (-right);
		RETURN RESULT
	END "-";

(** SIGNED32 *)
	OPERATOR "-"*(CONST left: ARRAY [ ? ] OF SIGNED32; right: SIGNED32 ): ARRAY {UNSAFE} [ ? ] OF SIGNED32;
	BEGIN
		RESULT := left + (-right);
		RETURN RESULT
	END "-";

(** SIGNED32 *)
	OPERATOR "-"*(CONST left: ARRAY [ ? ] OF SIZE; right: SIZE ): ARRAY {UNSAFE} [ ? ] OF SIZE;
	BEGIN
		RESULT := left + (-right);
		RETURN RESULT
	END "-";

(** FLOAT32 *)
	OPERATOR "-"*(CONST left: ARRAY [ ? ] OF FLOAT32; right: FLOAT32 ): ARRAY {UNSAFE} [ ? ] OF FLOAT32;
	BEGIN
		RESULT := left + (-right);
		RETURN RESULT
	END "-";

(** FLOAT64 *)
	OPERATOR "-"*(CONST left: ARRAY [ ? ] OF FLOAT64; right: FLOAT64 ): ARRAY {UNSAFE} [ ? ] OF FLOAT64;
	BEGIN
		RESULT := left + (-right);
		RETURN RESULT
	END "-";

(** COMPLEX32 *)
	OPERATOR "-"*(CONST left: ARRAY [ ? ] OF COMPLEX32; right: COMPLEX32 ): ARRAY {UNSAFE} [ ? ] OF COMPLEX32;
	BEGIN
		RESULT := left + (-right);
		RETURN RESULT
	END "-";

(** COMPLEX64 *)
	OPERATOR "-"*(CONST left: ARRAY [ ? ] OF COMPLEX64; right: COMPLEX64 ): ARRAY {UNSAFE} [ ? ] OF COMPLEX64;
	BEGIN
		RESULT := left + (-right);
		RETURN RESULT
	END "-";

	(*** subtraction scalar-array -> array  ********************************************************************)

(** SIGNED8 *)
	PROCEDURE SubSSASLoop( ladr, radr, dadr: ADDRESS; linc, dinc, len: SIZE );
	VAR lval, rval, dval: SIGNED8;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  dval := rval - lval;  SYSTEM.PUT( dadr, dval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END SubSSASLoop;

	OPERATOR "-"*(left: SIGNED8; CONST right: ARRAY [ ? ] OF SIGNED8): ARRAY {UNSAFE} [ ? ] OF SIGNED8;
	BEGIN
		ApplyBinaryASAOp( RESULT , right, ADDRESSOF( left ),
										SIZEOF( SIGNED8 ), SubSSASLoop );
		RETURN RESULT
	END "-";

(** SIGNED16 *)
	PROCEDURE SubSIAILoop( ladr, radr, dadr: ADDRESS; linc, dinc, len: SIZE );
	VAR lval, rval, dval: SIGNED16;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  dval := rval - lval;  SYSTEM.PUT( dadr, dval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END SubSIAILoop;

	OPERATOR "-"*(left: SIGNED16; CONST right: ARRAY [ ? ] OF SIGNED16): ARRAY {UNSAFE} [ ? ] OF SIGNED16;
	BEGIN
		ApplyBinaryASAOp( RESULT, right, ADDRESSOF( left ),
										SIZEOF( SIGNED16 ), SubSIAILoop );
		RETURN RESULT
	END "-";

(** SIGNED32 *)
	PROCEDURE SubSLALLoop( ladr, radr, dadr: ADDRESS; linc, dinc, len: SIZE );
	VAR lval, rval, dval: SIGNED32;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  dval := rval - lval;  SYSTEM.PUT( dadr, dval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END SubSLALLoop;

	OPERATOR "-"*(left: SIGNED32; CONST right: ARRAY [ ? ] OF SIGNED32): ARRAY {UNSAFE} [ ? ] OF SIGNED32;
	BEGIN
		ApplyBinaryASAOp( RESULT , right, ADDRESSOF( left ),
										SIZEOF( SIGNED32 ), SubSLALLoop );
		RETURN RESULT
	END "-";

(** SIZE *)
	PROCEDURE SubSYAYLoop( ladr, radr, dadr: ADDRESS; linc, dinc, len: SIZE );
	VAR lval, rval, dval: SIZE;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  dval := rval - lval;  SYSTEM.PUT( dadr, dval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END SubSYAYLoop;

	OPERATOR "-"*(left: SIZE; CONST right: ARRAY [ ? ] OF SIZE): ARRAY {UNSAFE} [ ? ] OF SIZE;
	BEGIN
		ApplyBinaryASAOp( RESULT , right, ADDRESSOF( left ),
										SIZEOF( SIZE ), SubSYAYLoop );
		RETURN RESULT
	END "-";
(** FLOAT32 *)
	PROCEDURE SubSRARLoop( ladr, radr, dadr: ADDRESS; linc, dinc, len: SIZE );
	VAR lval, rval, dval: FLOAT32;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  dval := rval - lval;  SYSTEM.PUT( dadr, dval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END SubSRARLoop;

	OPERATOR "-"*(left: FLOAT32; CONST right: ARRAY [ ? ] OF FLOAT32): ARRAY {UNSAFE} [ ? ] OF FLOAT32;
	BEGIN
		ApplyBinaryASAOp( RESULT , right, ADDRESSOF( left ), SIZEOF( FLOAT32 ),
										SubSRARLoop );
		RETURN RESULT
	END "-";

(** FLOAT64 *)
	PROCEDURE SubSXAXLoop( ladr, radr, dadr: ADDRESS; linc, dinc, len: SIZE );
	VAR lval, rval, dval: FLOAT64;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  dval := rval - lval;  SYSTEM.PUT( dadr, dval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END SubSXAXLoop;

	OPERATOR "-"*(left: FLOAT64; CONST right: ARRAY [ ? ] OF FLOAT64): ARRAY {UNSAFE} [ ? ] OF FLOAT64;
	BEGIN
		ApplyBinaryASAOp( RESULT , right, ADDRESSOF( left ),
										SIZEOF( FLOAT64 ), SubSXAXLoop );
		RETURN RESULT
	END "-";

(** COMPLEX32 *)
	PROCEDURE SubSZAZLoop( ladr, radr, dadr: ADDRESS; linc, dinc, len: SIZE );
	VAR lval, rval, dval: COMPLEX32;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  dval := rval - lval;  SYSTEM.PUT( dadr, dval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END SubSZAZLoop;

	OPERATOR "-"*(left: COMPLEX32; CONST right: ARRAY [ ? ] OF COMPLEX32): ARRAY {UNSAFE} [ ? ] OF COMPLEX32;
	BEGIN
		ApplyBinaryASAOp( RESULT , right, ADDRESSOF( left ),
										SIZEOF( COMPLEX32 ), SubSZAZLoop );
		RETURN RESULT
	END "-";

(** COMPLEX64 *)
	PROCEDURE SubSLZALZLoop( ladr, radr, dadr: ADDRESS; linc, dinc, len: SIZE );
	VAR lvalRe, lvalIm, rvalRe, rvalIm: FLOAT64;
	BEGIN
		SYSTEM.GET( radr, rvalRe ); SYSTEM.GET( radr+SIZEOF(FLOAT64), rvalIm );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lvalRe ); SYSTEM.GET( ladr+SIZEOF(FLOAT64), lvalIm );
			SYSTEM.PUT( dadr, rvalRe-lvalRe ); SYSTEM.PUT( dadr+SIZEOF(FLOAT64), rvalIm-lvalIm );
			INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END SubSLZALZLoop;

	OPERATOR "-"*(left: COMPLEX64; CONST right: ARRAY [ ? ] OF COMPLEX64): ARRAY {UNSAFE} [ ? ] OF COMPLEX64;
	BEGIN
		ApplyBinaryASAOp( RESULT , right, ADDRESSOF( left ),
										SIZEOF( COMPLEX64 ), SubSLZALZLoop );
		RETURN RESULT
	END "-";

	(*** element-wise multiply array x array -> array  ********************************************************************)

(** SIGNED8 *)
	PROCEDURE EMulASASLoop( ladr, radr, dadr: ADDRESS; linc, rinc, dinc, len: SIZE );
	VAR lval, rval: SIGNED8;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.PUT( dadr, lval * rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END EMulASASLoop;

	OPERATOR ".*"*(CONST left,right: ARRAY [?] OF SIGNED8): ARRAY {UNSAFE} [?] OF SIGNED8;
	BEGIN
		ApplyBinaryAAAOp( RESULT, left, right,
										SIZEOF( SIGNED8 ), EMulASASLoop );
		RETURN RESULT
	END ".*";

(** SIGNED16 *)
	PROCEDURE EMulAIAILoop( ladr, radr, dadr: ADDRESS; linc, rinc, dinc, len: SIZE );
	VAR lval, rval: SIGNED16;  dval: SIGNED16;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  dval := lval * rval;
			SYSTEM.PUT( dadr, dval );  INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );
			DEC( len );
		END;
	END EMulAIAILoop;

	OPERATOR ".*"*(CONST left,right: ARRAY [?] OF SIGNED16): ARRAY {UNSAFE} [?] OF SIGNED16;
	BEGIN
		ApplyBinaryAAAOp( RESULT, left, right,
										SIZEOF( SIGNED16 ), EMulAIAILoop );
		RETURN RESULT
	END ".*";

(** SIGNED32 *)
	PROCEDURE EMulALALLoop( ladr, radr, dadr: ADDRESS; linc, rinc, dinc, len: SIZE );
	VAR lval, rval: SIGNED32;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.PUT( dadr, lval * rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END EMulALALLoop;

	OPERATOR ".*"*(CONST left,right: ARRAY [?] OF SIGNED32): ARRAY {UNSAFE} [?] OF SIGNED32;
	BEGIN
		ApplyBinaryAAAOp( RESULT, left, right,
										SIZEOF( SIGNED32 ), EMulALALLoop );
		RETURN RESULT
	END ".*";

(** FLOAT32 *)
	PROCEDURE EMulARARLoop( ladr, radr, dadr: ADDRESS; linc, rinc, dinc, len: SIZE );
	VAR lval, rval: FLOAT32;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.PUT( dadr, lval * rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END EMulARARLoop;

	OPERATOR ".*"*(CONST left,right: ARRAY [?] OF FLOAT32): ARRAY {UNSAFE} [?] OF FLOAT32;
	BEGIN
		ApplyBinaryAAAOp( RESULT, left, right, SIZEOF( FLOAT32 ),
										loopEMulARAR );
		RETURN RESULT
	END ".*";

(** FLOAT64 *)
	PROCEDURE EMulAXAXLoop( ladr, radr, dadr: ADDRESS; linc, rinc, dinc, len: SIZE );
	VAR lval, rval: FLOAT64;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.PUT( dadr, lval * rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END EMulAXAXLoop;

	OPERATOR ".*"*(CONST left,right: ARRAY [?] OF FLOAT64): ARRAY {UNSAFE} [?] OF FLOAT64;
	BEGIN
		ApplyBinaryAAAOp( RESULT, left, right,
										SIZEOF( FLOAT64 ), loopEMulAXAX );
		RETURN RESULT
	END ".*";

(** COMPLEX32 *)
	PROCEDURE EMulAZAZLoop( ladr, radr, dadr: ADDRESS; linc, rinc, dinc, len: SIZE );
	VAR lval, rval: COMPLEX32;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.PUT( dadr, lval * rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END EMulAZAZLoop;

	OPERATOR ".*"*(CONST left,right: ARRAY [?] OF COMPLEX32): ARRAY {UNSAFE} [?] OF COMPLEX32;
	BEGIN
		ApplyBinaryAAAOp( RESULT, left, right,
										SIZEOF( COMPLEX32 ), loopEMulAZAZ );
		RETURN RESULT
	END ".*";

(** COMPLEX64 *)
	PROCEDURE EMulALZALZLoop( ladr, radr, dadr: ADDRESS; linc, rinc, dinc, len: SIZE );
	VAR lvalRe, lvalIm, rvalRe, rvalIm: FLOAT64;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lvalRe ); SYSTEM.GET( ladr+SIZEOF(FLOAT64), lvalIm );
			SYSTEM.GET( radr, rvalRe ); SYSTEM.GET( radr+SIZEOF(FLOAT64), rvalIm );
			SYSTEM.PUT( dadr, lvalRe*rvalRe - lvalIm*rvalIm ); SYSTEM.PUT( dadr+SIZEOF(FLOAT64), lvalRe*rvalIm + lvalIm*rvalRe );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );
			DEC( len );
		END;
	END EMulALZALZLoop;

	OPERATOR ".*"*(CONST left,right: ARRAY [?] OF COMPLEX64): ARRAY {UNSAFE} [?] OF COMPLEX64;
	BEGIN
		ApplyBinaryAAAOp( RESULT, left, right,
										SIZEOF( COMPLEX64 ), loopEMulALZALZ );
		RETURN RESULT
	END ".*";

	(*** element-wise multiply and add array x array -> array  ********************************************************************)

(** SIGNED8 *)
	PROCEDURE EMulIncASASLoop( ladr, radr, dadr: ADDRESS; linc, rinc, dinc, len: SIZE );
	VAR lval, rval,dval: SIGNED8;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.GET(dadr,dval); SYSTEM.PUT( dadr, dval + lval * rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END EMulIncASASLoop;

	OPERATOR ".*+"*(CONST left,right: ARRAY [?] OF SIGNED8): ARRAY {UNSAFE} [?] OF SIGNED8;
	BEGIN
		ApplyBinaryAAAOp( RESULT, left, right,
										SIZEOF( SIGNED8 ), EMulIncASASLoop );
	END  ".*+";

(** SIGNED16 *)
	PROCEDURE EMulIncAIAILoop( ladr, radr, dadr: ADDRESS; linc, rinc, dinc, len: SIZE );
	VAR lval, rval,dval: SIGNED16;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );SYSTEM.GET(dadr,dval);  dval := dval + lval * rval;
			SYSTEM.PUT( dadr, dval );  INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );
			DEC( len );
		END;
	END EMulIncAIAILoop;

	OPERATOR ".*+"*(CONST left,right: ARRAY [?] OF SIGNED16): ARRAY {UNSAFE} [?] OF SIGNED16;
	BEGIN
		ApplyBinaryAAAOp( RESULT, left, right,
										SIZEOF( SIGNED16 ), EMulIncAIAILoop );
	END  ".*+";

(** SIGNED32 *)
	PROCEDURE EMulIncALALLoop( ladr, radr, dadr: ADDRESS; linc, rinc, dinc, len: SIZE );
	VAR lval, rval,dval: SIGNED32;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.GET(dadr,dval); SYSTEM.PUT( dadr, dval+ lval * rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END EMulIncALALLoop;

	OPERATOR ".*+"*(CONST left,right: ARRAY [?] OF SIGNED32): ARRAY {UNSAFE} [?] OF SIGNED32;
	BEGIN
		ApplyBinaryAAAOp( RESULT, left, right,
										SIZEOF( SIGNED32 ), EMulIncALALLoop );
	END  ".*+";

(** FLOAT32 *)
	PROCEDURE EMulIncARARLoop( ladr, radr, dadr: ADDRESS; linc, rinc, dinc, len: SIZE );
	VAR lval, rval,dval: FLOAT32;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.GET(dadr,dval);  SYSTEM.PUT( dadr, dval+  lval * rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END EMulIncARARLoop;

	OPERATOR ".*+"*(CONST left,right: ARRAY [?] OF FLOAT32): ARRAY {UNSAFE} [?] OF FLOAT32;
	BEGIN
		ApplyBinaryAAAOp( RESULT, left, right, SIZEOF( FLOAT32 ),
										EMulIncARARLoop );
	END  ".*+";

(** FLOAT64 *)
	PROCEDURE EMulIncAXAXLoop( ladr, radr, dadr: ADDRESS; linc, rinc, dinc, len: SIZE );
	VAR lval, rval,dval: FLOAT64;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval ); SYSTEM.GET(dadr,dval);  SYSTEM.PUT( dadr,dval+ lval * rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END EMulIncAXAXLoop;

	OPERATOR ".*+"*(CONST left,right: ARRAY [?] OF FLOAT64): ARRAY {UNSAFE} [?] OF FLOAT64;
	BEGIN
		ApplyBinaryAAAOp( RESULT, left, right,
										SIZEOF( FLOAT64 ), EMulIncAXAXLoop );
	END  ".*+";
	(*** multiply array x scalar -> array and scalar + array -> array ********************************************************************)

(** SIGNED8 *)
	PROCEDURE MulASSSLoop( ladr, radr, dadr: ADDRESS; linc, dinc, len: SIZE );
	VAR lval, rval: SIGNED8;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.PUT( dadr, lval * rval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END MulASSSLoop;

	OPERATOR "*"*(CONST left: ARRAY [ ? ] OF SIGNED8; right: SIGNED8 ): ARRAY {UNSAFE} [ ? ] OF SIGNED8;
	BEGIN
		ApplyBinaryASAOp( RESULT , left, ADDRESSOF( right ),
										SIZEOF( SIGNED8 ), MulASSSLoop );
		RETURN RESULT
	END "*";

	OPERATOR "*"*(left: SIGNED8; CONST right: ARRAY [ ? ] OF SIGNED8): ARRAY {UNSAFE} [ ? ] OF SIGNED8;
	BEGIN
		ApplyBinaryASAOp( RESULT , right, ADDRESSOF( left ),
										SIZEOF( SIGNED8 ), MulASSSLoop );
		RETURN RESULT
	END "*";

(** SIGNED16 *)
	PROCEDURE MulAISILoop( ladr, radr, dadr: ADDRESS; linc, dinc, len: SIZE );
	VAR lval, rval: SIGNED16;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.PUT( dadr, lval * rval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END MulAISILoop;

	OPERATOR "*"*(CONST left: ARRAY [ ? ] OF SIGNED16; right: SIGNED16 ): ARRAY {UNSAFE} [ ? ] OF SIGNED16;
	BEGIN
		ApplyBinaryASAOp( RESULT , left, ADDRESSOF( right ),
										SIZEOF( SIGNED16 ), MulAISILoop );
		RETURN RESULT
	END "*";

	OPERATOR "*"*(left: SIGNED16; CONST right: ARRAY [ ? ] OF SIGNED16): ARRAY {UNSAFE} [ ? ] OF SIGNED16;
	BEGIN
		ApplyBinaryASAOp( RESULT , right, ADDRESSOF( left ),
										SIZEOF( SIGNED16 ), MulAISILoop );
		RETURN RESULT
	END "*";

(** SIGNED32 *)
	PROCEDURE MulALSLLoop( ladr, radr, dadr: ADDRESS; linc, dinc, len: SIZE );
	VAR lval, rval: SIGNED32;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.PUT( dadr, lval * rval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END MulALSLLoop;

	OPERATOR "*"*(CONST left: ARRAY [ ? ] OF SIGNED32; right: SIGNED32 ): ARRAY {UNSAFE} [ ? ] OF SIGNED32;
	BEGIN
		ApplyBinaryASAOp( RESULT , left, ADDRESSOF( right ),
										SIZEOF( SIGNED32 ), MulALSLLoop );
		RETURN RESULT
	END "*";

	OPERATOR "*"*(left: SIGNED32; CONST right: ARRAY [ ? ] OF SIGNED32): ARRAY {UNSAFE} [ ? ] OF SIGNED32;
	BEGIN
		ApplyBinaryASAOp( RESULT , right, ADDRESSOF( left ),
										SIZEOF( SIGNED32 ), MulALSLLoop );
		RETURN RESULT
	END "*";

(** SIZE *)
	PROCEDURE MulAYSYLoop( ladr, radr, dadr: ADDRESS; linc, dinc, len: SIZE );
	VAR lval, rval: SIZE;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.PUT( dadr, lval * rval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END MulAYSYLoop;

	OPERATOR "*"*(CONST left: ARRAY [ ? ] OF SIZE; right: SIZE ): ARRAY {UNSAFE} [ ? ] OF SIZE;
	BEGIN
		ApplyBinaryASAOp( RESULT , left, ADDRESSOF( right ),
										SIZEOF( SIZE ), MulAYSYLoop );
		RETURN RESULT
	END "*";

	OPERATOR "*"*(left: SIZE; CONST right: ARRAY [ ? ] OF SIZE): ARRAY {UNSAFE} [ ? ] OF SIZE;
	BEGIN
		ApplyBinaryASAOp( RESULT , right, ADDRESSOF( left ),
										SIZEOF( SIZE ), MulAYSYLoop );
		RETURN RESULT
	END "*";

(** FLOAT32 *)
	PROCEDURE MulARSRLoop( ladr, radr, dadr: ADDRESS; linc, dinc, len: SIZE );
	VAR lval, rval: FLOAT32;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.PUT( dadr, lval * rval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END MulARSRLoop;

	OPERATOR "*"*(CONST left: ARRAY [ ? ] OF FLOAT32; right: FLOAT32 ): ARRAY {UNSAFE} [ ? ] OF FLOAT32;
	BEGIN
		ApplyBinaryASAOp( RESULT , left, ADDRESSOF( right ), SIZEOF( FLOAT32 ),
										loopMulARSR );
		RETURN RESULT
	END "*";

	OPERATOR "*"*(left: FLOAT32; CONST right: ARRAY [ ? ] OF FLOAT32): ARRAY {UNSAFE} [ ? ] OF FLOAT32;
	BEGIN
		ApplyBinaryASAOp( RESULT , right, ADDRESSOF( left ), SIZEOF( FLOAT32 ),
										loopMulARSR );
		RETURN RESULT
	END "*";

(** FLOAT64 *)
	PROCEDURE MulAXSXLoop( ladr, radr, dadr: ADDRESS; linc, dinc, len: SIZE );
	VAR lval, rval: FLOAT64;
	BEGIN
		IF debug THEN
			KernelLog.String( "MulAXSXLoop, ladr,radr,dadr,linc,dinc,len= " );  KernelLog.Int( ladr, 10 );  KernelLog.Int( radr, 10 );
			KernelLog.Int( dadr, 10 );  KernelLog.Int( linc, 10 );  KernelLog.Int( dinc, 10 );
			KernelLog.Int( len, 10 );  KernelLog.Ln;
		END;

		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.PUT( dadr, lval * rval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END MulAXSXLoop;

	OPERATOR "*"*(CONST left: ARRAY [ ? ] OF FLOAT64; right: FLOAT64 ): ARRAY {UNSAFE} [ ? ] OF FLOAT64;
	BEGIN
		ApplyBinaryASAOp( RESULT , left, ADDRESSOF( right ),
										SIZEOF( FLOAT64 ), loopMulAXSX );
		RETURN RESULT
	END "*";

	OPERATOR "*"*(left: FLOAT64; CONST right: ARRAY [ ? ] OF FLOAT64): ARRAY {UNSAFE} [ ? ] OF FLOAT64;
	BEGIN
		ApplyBinaryASAOp( RESULT , right, ADDRESSOF( left ),
										SIZEOF( FLOAT64 ), loopMulAXSX );
		RETURN RESULT
	END "*";

(** COMPLEX32 *)
	PROCEDURE MulAZSZLoop( ladr, radr, dadr: ADDRESS; linc, dinc, len: SIZE );
	VAR lval, rval: COMPLEX32;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.PUT( dadr, lval * rval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END MulAZSZLoop;

	OPERATOR "*"*(CONST left: ARRAY [ ? ] OF COMPLEX32; right: COMPLEX32 ): ARRAY {UNSAFE} [ ? ] OF COMPLEX32;
	BEGIN
		ApplyBinaryASAOp( RESULT , left, ADDRESSOF( right ), SIZEOF( COMPLEX32 ),
										loopMulAZSZ );
		RETURN RESULT
	END "*";

	OPERATOR "*"*(left: COMPLEX32; CONST right: ARRAY [ ? ] OF COMPLEX32): ARRAY {UNSAFE} [ ? ] OF COMPLEX32;
	BEGIN
		ApplyBinaryASAOp( RESULT , right, ADDRESSOF( left ), SIZEOF( COMPLEX32 ),
										loopMulAZSZ );
		RETURN RESULT
	END "*";

(** COMPLEX64 *)
	PROCEDURE MulALZSLZLoop( ladr, radr, dadr: ADDRESS; linc, dinc, len: SIZE );
	VAR lvalRe, lvalIm, rvalRe, rvalIm: FLOAT64;
	BEGIN
		SYSTEM.GET( radr, rvalRe ); SYSTEM.GET( radr+SIZEOF(FLOAT64), rvalIm );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lvalRe ); SYSTEM.GET( ladr+SIZEOF(FLOAT64), lvalIm );
			SYSTEM.PUT( dadr, lvalRe * rvalRe - lvalIm*rvalIm ); SYSTEM.PUT( dadr+SIZEOF(FLOAT64), lvalRe * rvalIm + lvalIm*rvalRe );
			INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END MulALZSLZLoop;

	OPERATOR "*"*(CONST left: ARRAY [ ? ] OF COMPLEX64; right: COMPLEX64 ): ARRAY {UNSAFE} [ ? ] OF COMPLEX64;
	BEGIN
		ApplyBinaryASAOp( RESULT , left, ADDRESSOF( right ), SIZEOF( COMPLEX64 ),
										loopMulALZSLZ );
		RETURN RESULT
	END "*";

	OPERATOR "*"*(left: COMPLEX64; CONST right: ARRAY [ ? ] OF COMPLEX64): ARRAY {UNSAFE} [ ? ] OF COMPLEX64;
	BEGIN
		ApplyBinaryASAOp( RESULT , right, ADDRESSOF( left ), SIZEOF( COMPLEX64 ),
										loopMulALZSLZ );
		RETURN RESULT
	END "*";

	(*** multiply and add array * scalar -> array and scalar *  array -> array ********************************************************************)

(** SIGNED8 *)
	PROCEDURE IncMulASSSLoop( ladr, radr, dadr: ADDRESS; linc, dinc, len: SIZE );
	VAR lval, rval, dval: SIGNED8;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( dadr, dval );  SYSTEM.PUT( dadr, dval + lval * rval );
			INC( ladr, linc );  INC( dadr, dinc );  DEC( len );
		END;
	END IncMulASSSLoop;

	OPERATOR "INCMUL"*(CONST left: ARRAY [ ? ] OF SIGNED8; right: SIGNED8 ): ARRAY {UNSAFE} [ ? ] OF SIGNED8;
	BEGIN
		ApplyBinaryASAOp( RESULT , left, ADDRESSOF( right ),
										SIZEOF( SIGNED8 ), IncMulASSSLoop );
	END "INCMUL";

	OPERATOR "INCMUL"*(left: SIGNED8; CONST right: ARRAY [ ? ] OF SIGNED8): ARRAY {UNSAFE} [ ? ] OF SIGNED8;
	BEGIN
		ApplyBinaryASAOp( RESULT , right, ADDRESSOF( left ),
										SIZEOF( SIGNED8 ), IncMulASSSLoop );
		RETURN RESULT
	END "INCMUL";

	OPERATOR "DECMUL"*(CONST left: ARRAY [ ? ] OF SIGNED8; right: SIGNED8 ): ARRAY {UNSAFE} [ ? ] OF SIGNED8;
	BEGIN
		RESULT := -RESULT;
		ApplyBinaryASAOp( RESULT , left, ADDRESSOF( right ),
										SIZEOF( SIGNED8 ), IncMulASSSLoop );
		RESULT := -RESULT;
		RETURN RESULT
	END "DECMUL";

	OPERATOR "DECMUL"*(left: SIGNED8; CONST right: ARRAY [ ? ] OF SIGNED8): ARRAY {UNSAFE} [ ? ] OF SIGNED8;
	BEGIN
		RESULT := -RESULT;
		ApplyBinaryASAOp( RESULT , right, ADDRESSOF( left ),
										SIZEOF( SIGNED8 ), IncMulASSSLoop );
		RESULT := -RESULT;
		RETURN RESULT
	END "DECMUL";

(** SIGNED16 *)
	PROCEDURE IncMulAISILoop( ladr, radr, dadr: ADDRESS; linc, dinc, len: SIZE );
	VAR lval, rval, dval: SIGNED16;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( dadr, dval );  SYSTEM.PUT( dadr, dval + lval * rval );
			INC( ladr, linc );  INC( dadr, dinc );  DEC( len );
		END;
	END IncMulAISILoop;

	OPERATOR "INCMUL"*(CONST left: ARRAY [ ? ] OF SIGNED16; right: SIGNED16 ): ARRAY {UNSAFE} [ ? ] OF SIGNED16;
	BEGIN
		ApplyBinaryASAOp( RESULT , left, ADDRESSOF( right ),
										SIZEOF( SIGNED16 ), IncMulAISILoop );
		RETURN RESULT
	END "INCMUL";

	OPERATOR "INCMUL"*(left: SIGNED16; CONST right: ARRAY [ ? ] OF SIGNED16): ARRAY {UNSAFE} [ ? ] OF SIGNED16;
	BEGIN
		ApplyBinaryASAOp( RESULT , right, ADDRESSOF( left ),
										SIZEOF( SIGNED16 ), IncMulAISILoop );
		RETURN RESULT
	END "INCMUL";

	OPERATOR "DECMUL"*(CONST left: ARRAY [ ? ] OF SIGNED16; right: SIGNED16 ): ARRAY {UNSAFE} [ ? ] OF SIGNED16;
	BEGIN
		RESULT := -RESULT;
		ApplyBinaryASAOp( RESULT , left, ADDRESSOF( right ),
										SIZEOF( SIGNED16 ), IncMulAISILoop );
		RESULT := -RESULT;
		RETURN RESULT
	END "DECMUL";

	OPERATOR "DECMUL"*(left: SIGNED16; CONST right: ARRAY [ ? ] OF SIGNED16): ARRAY {UNSAFE} [ ? ] OF SIGNED16;
	BEGIN
		RESULT := -RESULT;
		ApplyBinaryASAOp( RESULT , right, ADDRESSOF( left ),
										SIZEOF( SIGNED16 ), IncMulAISILoop );
		RESULT := -RESULT;
		RETURN RESULT
	END "DECMUL";

(** SIGNED32 *)
	PROCEDURE IncMulALSLLoop( ladr, radr, dadr: ADDRESS; linc, dinc, len: SIZE );
	VAR lval, rval, dval: SIGNED32;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( dadr, dval );  SYSTEM.PUT( dadr, dval + lval * rval );
			INC( ladr, linc );  INC( dadr, dinc );  DEC( len );
		END;
	END IncMulALSLLoop;

	OPERATOR "INCMUL"*(CONST left: ARRAY [ ? ] OF SIGNED32; right: SIGNED32 ): ARRAY {UNSAFE} [ ? ] OF SIGNED32;
	BEGIN
		ApplyBinaryASAOp( RESULT , left, ADDRESSOF( right ),
										SIZEOF( SIGNED32 ), IncMulALSLLoop );
		RETURN RESULT
	END "INCMUL";

	OPERATOR "INCMUL"*(left: SIGNED32; CONST right: ARRAY [ ? ] OF SIGNED32): ARRAY {UNSAFE} [ ? ] OF SIGNED32;
	BEGIN
		ApplyBinaryASAOp( RESULT , right, ADDRESSOF( left ),
										SIZEOF( SIGNED32 ), IncMulALSLLoop );
		RETURN RESULT
	END "INCMUL";

	OPERATOR "DECMUL"*(CONST left: ARRAY [ ? ] OF SIGNED32; right: SIGNED32 ): ARRAY {UNSAFE} [ ? ] OF SIGNED32;
	BEGIN
		RESULT := -RESULT;
		ApplyBinaryASAOp( RESULT , left, ADDRESSOF( right ),
										SIZEOF( SIGNED32 ), IncMulALSLLoop );
		RESULT := -RESULT;
		RETURN RESULT
	END "DECMUL";

	OPERATOR "DECMUL"*(left: SIGNED32; CONST right: ARRAY [ ? ] OF SIGNED32): ARRAY {UNSAFE} [ ? ] OF SIGNED32;
	BEGIN
		RESULT := -RESULT;
		ApplyBinaryASAOp( RESULT , right, ADDRESSOF( left ),
										SIZEOF( SIGNED32 ), IncMulALSLLoop );
		RESULT := -RESULT;
		RETURN RESULT
	END "DECMUL";

(** FLOAT32 *)
	PROCEDURE IncMulARSRLoop( ladr, radr, dadr: ADDRESS; linc, dinc, len: SIZE );
	VAR lval, rval, dval: FLOAT32;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( dadr, dval );  SYSTEM.PUT( dadr, dval + lval * rval );
			INC( ladr, linc );  INC( dadr, dinc );  DEC( len );
		END;
	END IncMulARSRLoop;

	OPERATOR "INCMUL"*(CONST left: ARRAY [ ? ] OF FLOAT32; right: FLOAT32 ): ARRAY {UNSAFE} [ ? ] OF FLOAT32;
	BEGIN
		ApplyBinaryASAOp( RESULT , left, ADDRESSOF( right ), SIZEOF( FLOAT32 ),
										loopIncMulARSR );
		RETURN RESULT
	END "INCMUL";

	OPERATOR "INCMUL"*(left: FLOAT32; CONST right: ARRAY [ ? ] OF FLOAT32): ARRAY {UNSAFE} [ ? ] OF FLOAT32;
	BEGIN
		ApplyBinaryASAOp( RESULT , right, ADDRESSOF( left ), SIZEOF( FLOAT32 ),
										loopIncMulARSR );
		RETURN RESULT
	END "INCMUL";

	OPERATOR "DECMUL"*(CONST left: ARRAY [ ? ] OF FLOAT32; right: FLOAT32 ): ARRAY {UNSAFE} [ ? ] OF FLOAT32;
	BEGIN
		RESULT := -RESULT;
		ApplyBinaryASAOp( RESULT , left, ADDRESSOF( right ), SIZEOF( FLOAT32 ),
										loopIncMulARSR );
		RESULT := -RESULT;
		RETURN RESULT
	END "DECMUL";

	OPERATOR "DECMUL"*(left: FLOAT32; CONST right: ARRAY [ ? ] OF FLOAT32): ARRAY {UNSAFE} [ ? ] OF FLOAT32;
	BEGIN
		RESULT := -RESULT;
		ApplyBinaryASAOp( RESULT , right, ADDRESSOF( left ), SIZEOF( FLOAT32 ),
										loopIncMulARSR );
		RESULT := -RESULT;
		RETURN RESULT
	END "DECMUL";

(** FLOAT64 *)
	PROCEDURE IncMulAXSXLoop( ladr, radr, dadr: ADDRESS; linc, dinc, len: SIZE );
	VAR lval, rval, dval: FLOAT64;
	BEGIN
		IF debug THEN
			KernelLog.String( "IncMulAXSXLoop, ladr,radr,dadr,linc,dinc,len= " );  KernelLog.Int( ladr, 10 );  KernelLog.Int( radr, 10 );
			KernelLog.Int( dadr, 10 );  KernelLog.Int( linc, 10 );  KernelLog.Int( dinc, 10 );
			KernelLog.Int( len, 10 );  KernelLog.Ln;
		END;

		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( dadr, dval );  SYSTEM.PUT( dadr, dval + lval * rval );
			INC( ladr, linc );  INC( dadr, dinc );  DEC( len );
		END;
	END IncMulAXSXLoop;

	OPERATOR "INCMUL"*(CONST left: ARRAY [ ? ] OF FLOAT64; right: FLOAT64 ): ARRAY {UNSAFE} [ ? ] OF FLOAT64;
	BEGIN
		ApplyBinaryASAOp( RESULT , left, ADDRESSOF( right ),
										SIZEOF( FLOAT64 ), loopIncMulAXSX );
		RETURN RESULT
	END "INCMUL";

	OPERATOR "INCMUL"*(left: FLOAT64; CONST right: ARRAY [ ? ] OF FLOAT64): ARRAY {UNSAFE} [ ? ] OF FLOAT64;
	BEGIN
		ApplyBinaryASAOp( RESULT , right, ADDRESSOF( left ),
										SIZEOF( FLOAT64 ), loopIncMulAXSX );
		RETURN RESULT
	END "INCMUL";

	OPERATOR "DECMUL"*(CONST left: ARRAY [ ? ] OF FLOAT64; right: FLOAT64 ): ARRAY {UNSAFE} [ ? ] OF FLOAT64;
	BEGIN
		RESULT := -RESULT;
		ApplyBinaryASAOp( RESULT , left, ADDRESSOF( right ),
										SIZEOF( FLOAT64 ), loopIncMulAXSX );
		RESULT := -RESULT;
		RETURN RESULT
	END "DECMUL";

	OPERATOR "DECMUL"*(left: FLOAT64; CONST right: ARRAY [ ? ] OF FLOAT64): ARRAY {UNSAFE} [ ? ] OF FLOAT64;
	BEGIN
		RESULT := -RESULT;
		ApplyBinaryASAOp( RESULT , right, ADDRESSOF( left ),
										SIZEOF( FLOAT64 ), loopIncMulAXSX );
		RESULT := -RESULT;
		RETURN RESULT
	END "DECMUL";

	(*** element-wise division array / array -> array  ********************************************************************)

(** SIGNED8 *)
	PROCEDURE EDivideASASLoop( ladr, radr, dadr: ADDRESS; linc, rinc, dinc, len: SIZE );
	VAR lval, rval: SIGNED8;  dval: FLOAT32;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  dval := lval / rval;
			SYSTEM.PUT( dadr, dval );  INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );
			DEC( len );
		END;
	END EDivideASASLoop;

	OPERATOR "./"*(CONST left,right: ARRAY [?] OF SIGNED8): ARRAY {UNSAFE} [?] OF FLOAT32;
	BEGIN
		ApplyBinaryAAAOp( RESULT, left, right, SIZEOF( FLOAT32 ),
										EDivideASASLoop );
		RETURN RESULT
	END "./";

(** SIGNED16 *)
	PROCEDURE EDivideAIAILoop( ladr, radr, dadr: ADDRESS; linc, rinc, dinc, len: SIZE );
	VAR lval, rval: SIGNED16;  dval: FLOAT32;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  dval := lval / rval;
			SYSTEM.PUT( dadr, dval );  INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );
			DEC( len );
		END;
	END EDivideAIAILoop;

	OPERATOR "./"*(CONST left,right: ARRAY [?] OF SIGNED16): ARRAY {UNSAFE} [?] OF FLOAT32;
	BEGIN
		ApplyBinaryAAAOp( RESULT, left, right, SIZEOF( FLOAT32 ),
										EDivideAIAILoop );
		RETURN RESULT
	END "./";

(** SIGNED32 *)
	PROCEDURE EDivideALALLoop( ladr, radr, dadr: ADDRESS; linc, rinc, dinc, len: SIZE );
	VAR lval, rval: SIGNED32;  dval: FLOAT32;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  dval := lval / rval;
			SYSTEM.PUT( dadr, dval );  INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );
			DEC( len );
		END;
	END EDivideALALLoop;

	OPERATOR "./"*(CONST left,right: ARRAY [?] OF SIGNED32): ARRAY {UNSAFE} [?] OF FLOAT32;
	BEGIN
		ApplyBinaryAAAOp( RESULT, left, right, SIZEOF( FLOAT32 ),
										EDivideALALLoop );
		RETURN RESULT
	END "./";

(** FLOAT32 *)
	PROCEDURE EDivideARARLoop( ladr, radr, dadr: ADDRESS; linc, rinc, dinc, len: SIZE );
	VAR lval, rval: FLOAT32;  dval: FLOAT32;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  dval := lval / rval;
			SYSTEM.PUT( dadr, dval );  INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );
			DEC( len );
		END;
	END EDivideARARLoop;

	OPERATOR "./"*(CONST left,right: ARRAY [?] OF FLOAT32): ARRAY {UNSAFE} [?] OF FLOAT32;
	BEGIN
		ApplyBinaryAAAOp( RESULT, left, right, SIZEOF( FLOAT32 ),
										EDivideARARLoop );
		RETURN RESULT
	END "./";

(** FLOAT64 *)
	PROCEDURE EDivideAXAXLoop( ladr, radr, dadr: ADDRESS; linc, rinc, dinc, len: SIZE );
	VAR lval, rval: FLOAT64;  dval: FLOAT64;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  dval := lval / rval;
			SYSTEM.PUT( dadr, dval );  INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );
			DEC( len );
		END;
	END EDivideAXAXLoop;

	OPERATOR "./"*(CONST left,right: ARRAY [?] OF FLOAT64): ARRAY {UNSAFE} [?] OF FLOAT64;
	BEGIN
		ApplyBinaryAAAOp( RESULT, left, right,
										SIZEOF( FLOAT64 ), EDivideAXAXLoop );
		RETURN RESULT
	END "./";

(** COMPLEX32 *)
	PROCEDURE EDivideAZAZLoop( ladr, radr, dadr: ADDRESS; linc, rinc, dinc, len: SIZE );
	VAR lval, rval: COMPLEX32;  dval: COMPLEX32;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  dval := lval / rval;
			SYSTEM.PUT( dadr, dval );  INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );
			DEC( len );
		END;
	END EDivideAZAZLoop;

	OPERATOR "./"*(CONST left,right: ARRAY [?] OF COMPLEX32): ARRAY {UNSAFE} [?] OF COMPLEX32;
	BEGIN
		ApplyBinaryAAAOp( RESULT, left, right,
										SIZEOF( COMPLEX32 ), EDivideAZAZLoop );
		RETURN RESULT
	END "./";

(** COMPLEX64 *)
	PROCEDURE EDivideALZALZLoop( ladr, radr, dadr: ADDRESS; linc, rinc, dinc, len: SIZE );
	VAR lvalRe, lvalIm, rvalRe, rvalIm: FLOAT64;  dvalRe, dvalIm: FLOAT64; v: FLOAT64;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lvalRe ); SYSTEM.GET( ladr+SIZEOF(FLOAT64), lvalIm );
			SYSTEM.GET( radr, rvalRe ); SYSTEM.GET( radr+SIZEOF(FLOAT64), rvalIm );
			IF rvalIm # 0.0D0 THEN
				v := 1.0D0/(rvalRe*rvalRe + rvalIm*rvalIm);
				dvalRe := v*(lvalRe*rvalRe+lvalIm*rvalIm);
				dvalIm := v*(lvalIm*rvalRe-lvalRe*rvalIm);
			ELSE
				dvalRe := lvalRe/rvalRe;
				dvalIm := lvalIm/rvalRe;
			END;
			SYSTEM.PUT( dadr, dvalRe ); SYSTEM.PUT( dadr+SIZEOF(FLOAT64), dvalIm );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );
			DEC( len );
		END;
	END EDivideALZALZLoop;

	OPERATOR "./"*(CONST left,right: ARRAY [?] OF COMPLEX64): ARRAY {UNSAFE} [?] OF COMPLEX64;
	BEGIN
		ApplyBinaryAAAOp( RESULT, left, right,
										SIZEOF( COMPLEX64 ), EDivideALZALZLoop );
		RETURN RESULT
	END "./";

	(*** division array / scalar -> array and scalar / array -> array ********************************************************************)

(** SIGNED8 *)
	PROCEDURE DivideASSSLoop( ladr, radr, dadr: ADDRESS; linc, dinc, len: SIZE );
	VAR lval, rval: SIGNED8;  dval: FLOAT32;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  dval := lval / rval;  SYSTEM.PUT( dadr, dval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END DivideASSSLoop;

	OPERATOR "/"*(CONST left: ARRAY [ ? ] OF SIGNED8; right: SIGNED8 ): ARRAY {UNSAFE} [ ? ] OF FLOAT32;
	BEGIN
		ApplyBinaryASAOp( RESULT , left, ADDRESSOF( right ), SIZEOF( FLOAT32 ),
										DivideASSSLoop );
		RETURN RESULT
	END "/";

	PROCEDURE DivideSSASLoop( ladr, radr, dadr: ADDRESS; linc, dinc, len: SIZE );
	VAR lval, rval: SIGNED8;  dval: FLOAT32;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  dval := rval / lval;  SYSTEM.PUT( dadr, dval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END DivideSSASLoop;

	OPERATOR "/"*(left: SIGNED8; CONST right: ARRAY [ ? ] OF SIGNED8): ARRAY {UNSAFE} [ ? ] OF FLOAT32;
	BEGIN
		ApplyBinaryASAOp( RESULT , right, ADDRESSOF( left ), SIZEOF( FLOAT32 ),
										DivideSSASLoop );
		RETURN RESULT
	END "/";

(** SIGNED16 *)
	PROCEDURE DivideAISILoop( ladr, radr, dadr: ADDRESS; linc, dinc, len: SIZE );
	VAR lval, rval: SIGNED16;  dval: FLOAT32;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  dval := lval / rval;  SYSTEM.PUT( dadr, dval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END DivideAISILoop;

	OPERATOR "/"*(CONST left: ARRAY [ ? ] OF SIGNED16; right: SIGNED16 ): ARRAY {UNSAFE} [ ? ] OF FLOAT32;
	BEGIN
		ApplyBinaryASAOp( RESULT , left, ADDRESSOF( right ), SIZEOF( FLOAT32 ),
										DivideAISILoop );
		RETURN RESULT
	END "/";

	PROCEDURE DivideSIAILoop( ladr, radr, dadr: ADDRESS; linc, dinc, len: SIZE );
	VAR lval, rval: SIGNED16;  dval: FLOAT32;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  dval := rval / lval;  SYSTEM.PUT( dadr, dval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END DivideSIAILoop;

	OPERATOR "/"*(left: SIGNED16; CONST right: ARRAY [ ? ] OF SIGNED16): ARRAY {UNSAFE} [ ? ] OF FLOAT32;
	BEGIN
		ApplyBinaryASAOp( RESULT , right, ADDRESSOF( left ), SIZEOF( FLOAT32 ),
										DivideSIAILoop );
		RETURN RESULT
	END "/";

(** SIGNED32 *)
	PROCEDURE DivideALSLLoop( ladr, radr, dadr: ADDRESS; linc, dinc, len: SIZE );
	VAR lval, rval: SIGNED32;  dval: FLOAT32;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  dval := lval / rval;  SYSTEM.PUT( dadr, dval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END DivideALSLLoop;

	OPERATOR "/"*(CONST left: ARRAY [ ? ] OF SIGNED32; right: SIGNED32 ): ARRAY {UNSAFE} [ ? ] OF FLOAT32;
	BEGIN
		ApplyBinaryASAOp( RESULT , left, ADDRESSOF( right ), SIZEOF( FLOAT32 ),
										DivideALSLLoop );
		RETURN RESULT
	END "/";

	PROCEDURE DivideSLALLoop( ladr, radr, dadr: ADDRESS; linc, dinc, len: SIZE );
	VAR lval, rval: SIGNED32;  dval: FLOAT32;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  dval := rval / lval;  SYSTEM.PUT( dadr, dval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END DivideSLALLoop;

	OPERATOR "/"*(left: SIGNED32; CONST right: ARRAY [ ? ] OF SIGNED32): ARRAY {UNSAFE} [ ? ] OF FLOAT32;
	BEGIN
		ApplyBinaryASAOp( RESULT , right, ADDRESSOF( left ), SIZEOF( FLOAT32 ),
										DivideSLALLoop );
		RETURN RESULT
	END "/";

(** FLOAT32 *)
	PROCEDURE DivideARSRLoop( ladr, radr, dadr: ADDRESS; linc, dinc, len: SIZE );
	VAR lval, rval: FLOAT32;  dval: FLOAT32;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  dval := lval / rval;  SYSTEM.PUT( dadr, dval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END DivideARSRLoop;

	OPERATOR "/"*(CONST left: ARRAY [ ? ] OF FLOAT32; right: FLOAT32 ): ARRAY {UNSAFE} [ ? ] OF FLOAT32;
	BEGIN
		ApplyBinaryASAOp( RESULT , left, ADDRESSOF( right ), SIZEOF( FLOAT32 ),
										DivideARSRLoop );
		RETURN RESULT
	END "/";

	PROCEDURE DivideSRARLoop( ladr, radr, dadr: ADDRESS; linc, dinc, len: SIZE );
	VAR lval, rval: FLOAT32;  dval: FLOAT32;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  dval := rval / lval;  SYSTEM.PUT( dadr, dval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END DivideSRARLoop;

	OPERATOR "/"*(left: FLOAT32; CONST right: ARRAY [ ? ] OF FLOAT32): ARRAY {UNSAFE} [ ? ] OF FLOAT32;
	BEGIN
		ApplyBinaryASAOp( RESULT , right, ADDRESSOF( left ), SIZEOF( FLOAT32 ),
										DivideSRARLoop );
		RETURN RESULT
	END "/";

(** FLOAT64 *)
	PROCEDURE DivideAXSXLoop( ladr, radr, dadr: ADDRESS; linc, dinc, len: SIZE );
	VAR lval, rval: FLOAT64;  dval: FLOAT64;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  dval := lval / rval;  SYSTEM.PUT( dadr, dval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END DivideAXSXLoop;

	OPERATOR "/"*(CONST left: ARRAY [ ? ] OF FLOAT64; right: FLOAT64 ): ARRAY {UNSAFE} [ ? ] OF FLOAT64;
	BEGIN
		ApplyBinaryASAOp( RESULT , left, ADDRESSOF( right ),
										SIZEOF( FLOAT64 ), DivideAXSXLoop );
		RETURN RESULT
	END "/";

	PROCEDURE DivideSXAXLoop( ladr, radr, dadr: ADDRESS; linc, dinc, len: SIZE );
	VAR lval, rval: FLOAT64;  dval: FLOAT64;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  dval := rval / lval;  SYSTEM.PUT( dadr, dval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END DivideSXAXLoop;

	OPERATOR "/"*(left: FLOAT64; CONST right: ARRAY [ ? ] OF FLOAT64): ARRAY {UNSAFE} [ ? ] OF FLOAT64;
	BEGIN
		ApplyBinaryASAOp( RESULT , right, ADDRESSOF( left ),
										SIZEOF( FLOAT64 ), DivideSXAXLoop );
		RETURN RESULT
	END "/";

(** COMPLEX32 *)
	PROCEDURE DivideAZSZLoop( ladr, radr, dadr: ADDRESS; linc, dinc, len: SIZE );
	VAR lval, rval: COMPLEX32;  dval: COMPLEX32;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  dval := lval / rval;  SYSTEM.PUT( dadr, dval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END DivideAZSZLoop;

	OPERATOR "/"*(CONST left: ARRAY [ ? ] OF COMPLEX32; right: COMPLEX32 ): ARRAY {UNSAFE} [ ? ] OF COMPLEX32;
	BEGIN
		ApplyBinaryASAOp( RESULT , left, ADDRESSOF( right ),
										SIZEOF( COMPLEX32 ), DivideAZSZLoop );
		RETURN RESULT
	END "/";

	PROCEDURE DivideSZAZLoop( ladr, radr, dadr: ADDRESS; linc, dinc, len: SIZE );
	VAR lval, rval: COMPLEX32;  dval: COMPLEX32;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  dval := rval / lval;  SYSTEM.PUT( dadr, dval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END DivideSZAZLoop;

	OPERATOR "/"*(left: COMPLEX32; CONST right: ARRAY [ ? ] OF COMPLEX32): ARRAY {UNSAFE} [ ? ] OF COMPLEX32;
	BEGIN
		ApplyBinaryASAOp( RESULT , right, ADDRESSOF( left ),
										SIZEOF( COMPLEX32 ), DivideSZAZLoop );
		RETURN RESULT
	END "/";

(** COMPLEX64 *)
	PROCEDURE DivideALZSLZLoop( ladr, radr, dadr: ADDRESS; linc, dinc, len: SIZE );
	VAR lvalRe, lvalIm, rvalRe, rvalIm: FLOAT64;  dvalRe, dvalIm: FLOAT64; v: FLOAT64;
	BEGIN
		SYSTEM.GET( radr, rvalRe ); SYSTEM.GET( radr+SIZEOF(FLOAT64), rvalIm );

		IF rvalIm # 0.0D0 THEN
			v := 1.0D0/(rvalRe*rvalRe + rvalIm*rvalIm);
			WHILE (len > 0) DO
				SYSTEM.GET( ladr, lvalRe ); SYSTEM.GET( ladr+SIZEOF(FLOAT64), lvalIm );
				dvalRe := v*(lvalRe*rvalRe+lvalIm*rvalIm);
				dvalIm := v*(lvalIm*rvalRe-lvalRe*rvalIm);
				SYSTEM.PUT( dadr, dvalRe ); SYSTEM.PUT( dadr+SIZEOF(FLOAT64), dvalIm );
				INC( ladr, linc );
				INC( dadr, dinc );  DEC( len );
			END;
		ELSE
			WHILE (len > 0) DO
				SYSTEM.GET( ladr, lvalRe ); SYSTEM.GET( ladr+SIZEOF(FLOAT64), lvalIm );
				dvalRe := lvalRe / rvalRe; dvalIm := lvalIm / rvalRe;
				SYSTEM.PUT( dadr, dvalRe ); SYSTEM.PUT( dadr+SIZEOF(FLOAT64), dvalIm );
				INC( ladr, linc );
				INC( dadr, dinc );  DEC( len );
			END;
		END;
	END DivideALZSLZLoop;

	OPERATOR "/"*(CONST left: ARRAY [ ? ] OF COMPLEX64; right: COMPLEX64 ): ARRAY {UNSAFE} [ ? ] OF COMPLEX64;
	BEGIN
		ApplyBinaryASAOp( RESULT , left, ADDRESSOF( right ),
										SIZEOF( COMPLEX64 ), DivideALZSLZLoop );
		RETURN RESULT
	END "/";

	PROCEDURE DivideSLZALZLoop( ladr, radr, dadr: ADDRESS; linc, dinc, len: SIZE );
	VAR lvalRe, lvalIm, rvalRe, rvalIm: FLOAT64;  dvalRe, dvalIm: FLOAT64; v: FLOAT64;
	BEGIN
		SYSTEM.GET( radr, rvalRe ); SYSTEM.GET( radr+SIZEOF(FLOAT64), rvalIm );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lvalRe ); SYSTEM.GET( ladr+SIZEOF(FLOAT64), lvalIm );
			v := 1.0D0/(lvalRe*lvalRe + lvalIm*lvalIm);
			dvalRe := v*(rvalRe*lvalRe+rvalIm*lvalIm);
			dvalIm := v*(rvalIm*lvalRe-rvalRe*lvalIm);
			SYSTEM.PUT( dadr, dvalRe ); SYSTEM.PUT( dadr+SIZEOF(FLOAT64), dvalIm );
			INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END DivideSLZALZLoop;

	OPERATOR "/"*(left: COMPLEX64; CONST right: ARRAY [ ? ] OF COMPLEX64): ARRAY {UNSAFE} [ ? ] OF COMPLEX64;
	BEGIN
		ApplyBinaryASAOp( RESULT , right, ADDRESSOF( left ),
										SIZEOF( COMPLEX64 ), DivideSLZALZLoop );
		RETURN RESULT
	END "/";

	(*** element-wise DIV array DIV array -> array  ********************************************************************)

(** SIGNED8 *)
	PROCEDURE EDivASASLoop( ladr, radr, dadr: ADDRESS; linc, rinc, dinc, len: SIZE );
	VAR lval, rval: SIGNED8;  dval: SIGNED8;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  dval := lval DIV rval;
			SYSTEM.PUT( dadr, dval );  INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );
			DEC( len );
		END;
	END EDivASASLoop;

	OPERATOR "DIV"*(CONST left,right: ARRAY [?] OF SIGNED8): ARRAY {UNSAFE} [?] OF SIGNED8;
	BEGIN
		ApplyBinaryAAAOp( RESULT, left, right,
										SIZEOF( SIGNED8 ), EDivASASLoop );
		RETURN RESULT
	END "DIV";

(** SIGNED16 *)
	PROCEDURE EDivAIAILoop( ladr, radr, dadr: ADDRESS; linc, rinc, dinc, len: SIZE );
	VAR lval, rval: SIGNED16;  dval: SIGNED16;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  dval := lval DIV rval;
			SYSTEM.PUT( dadr, dval );  INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );
			DEC( len );
		END;
	END EDivAIAILoop;

	OPERATOR "DIV"*(CONST left,right: ARRAY [?] OF SIGNED16): ARRAY {UNSAFE} [?] OF SIGNED16;
	BEGIN
		ApplyBinaryAAAOp( RESULT, left, right,
										SIZEOF( SIGNED16 ), EDivAIAILoop );
		RETURN RESULT
	END "DIV";

(** SIGNED32 *)
	PROCEDURE EDivALALLoop( ladr, radr, dadr: ADDRESS; linc, rinc, dinc, len: SIZE );
	VAR lval, rval: SIGNED32;  dval: SIGNED32;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  dval := lval DIV rval;
			SYSTEM.PUT( dadr, dval );  INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );
			DEC( len );
		END;
	END EDivALALLoop;

	OPERATOR "DIV"*(CONST left,right: ARRAY [?] OF SIGNED32): ARRAY {UNSAFE} [?] OF SIGNED32;
	BEGIN
		ApplyBinaryAAAOp( RESULT, left, right,
										SIZEOF( SIGNED32 ), EDivALALLoop );
		RETURN RESULT
	END "DIV";

(** SIZE *)
	PROCEDURE EDivAYAYLoop( ladr, radr, dadr: ADDRESS; linc, rinc, dinc, len: SIZE );
	VAR lval, rval: SIZE;  dval: SIZE;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  dval := lval DIV rval;
			SYSTEM.PUT( dadr, dval );  INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );
			DEC( len );
		END;
	END EDivAYAYLoop;

	OPERATOR "DIV"*(CONST left,right: ARRAY [?] OF SIZE): ARRAY {UNSAFE} [?] OF SIZE;
	BEGIN
		ApplyBinaryAAAOp( RESULT, left, right,
										SIZEOF( SIZE ), EDivAYAYLoop );
		RETURN RESULT
	END "DIV";
	(*** division array DIV scalar -> array and scalar DIV  array -> array ********************************************************************)

(** SIGNED8 *)
	PROCEDURE DivASSSLoop( ladr, radr, dadr: ADDRESS; linc, dinc, len: SIZE );
	VAR lval, rval: SIGNED8;  dval: SIGNED8;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  dval := lval DIV rval;  SYSTEM.PUT( dadr, dval );
			INC( ladr, linc );  INC( dadr, dinc );  DEC( len );
		END;
	END DivASSSLoop;

	OPERATOR "DIV"*(CONST left: ARRAY [ ? ] OF SIGNED8; right: SIGNED8 ): ARRAY {UNSAFE} [ ? ] OF SIGNED8;
	BEGIN
		ApplyBinaryASAOp( RESULT , left, ADDRESSOF( right ),
										SIZEOF( SIGNED8 ), DivASSSLoop );
		RETURN RESULT
	END "DIV";

	PROCEDURE DivSSASLoop( ladr, radr, dadr: ADDRESS; linc, dinc, len: SIZE );
	VAR lval, rval: SIGNED8;  dval: SIGNED8;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  dval := rval DIV lval;  SYSTEM.PUT( dadr, dval );
			INC( ladr, linc );  INC( dadr, dinc );  DEC( len );
		END;
	END DivSSASLoop;

	OPERATOR "DIV"*(left: SIGNED8; CONST right: ARRAY [ ? ] OF SIGNED8): ARRAY {UNSAFE} [ ? ] OF SIGNED8;
	BEGIN
		ApplyBinaryASAOp( RESULT , right, ADDRESSOF( left ),
										SIZEOF( SIGNED8 ), DivSSASLoop );
		RETURN RESULT
	END "DIV";

(** SIGNED16 *)
	PROCEDURE DivAISILoop( ladr, radr, dadr: ADDRESS; linc, dinc, len: SIZE );
	VAR lval, rval: SIGNED16;  dval: SIGNED16;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  dval := lval DIV rval;  SYSTEM.PUT( dadr, dval );
			INC( ladr, linc );  INC( dadr, dinc );  DEC( len );
		END;
	END DivAISILoop;

	OPERATOR "DIV"*(CONST left: ARRAY [ ? ] OF SIGNED16; right: SIGNED16 ): ARRAY {UNSAFE} [ ? ] OF SIGNED16;
	BEGIN
		ApplyBinaryASAOp( RESULT , left, ADDRESSOF( right ),
										SIZEOF( SIGNED16 ), DivAISILoop );
		RETURN RESULT
	END "DIV";

	PROCEDURE DivSIAILoop( ladr, radr, dadr: ADDRESS; linc, dinc, len: SIZE );
	VAR lval, rval: SIGNED16;  dval: SIGNED16;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  dval := rval DIV lval;  SYSTEM.PUT( dadr, dval );
			INC( ladr, linc );  INC( dadr, dinc );  DEC( len );
		END;
	END DivSIAILoop;

	OPERATOR "DIV"*(left: SIGNED16; CONST right: ARRAY [ ? ] OF SIGNED16): ARRAY {UNSAFE} [ ? ] OF SIGNED16;
	BEGIN
		ApplyBinaryASAOp( RESULT , right, ADDRESSOF( left ),
										SIZEOF( SIGNED16 ), DivSIAILoop );
		RETURN RESULT
	END "DIV";

(** SIGNED32 *)
	PROCEDURE DivALSLLoop( ladr, radr, dadr: ADDRESS; linc, dinc, len: SIZE );
	VAR lval, rval: SIGNED32;  dval: SIGNED32;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  dval := lval DIV rval;  SYSTEM.PUT( dadr, dval );
			INC( ladr, linc );  INC( dadr, dinc );  DEC( len );
		END;
	END DivALSLLoop;

	OPERATOR "DIV"*(CONST left: ARRAY [ ? ] OF SIGNED32; right: SIGNED32 ): ARRAY {UNSAFE} [ ? ] OF SIGNED32;
	BEGIN
		ApplyBinaryASAOp( RESULT , left, ADDRESSOF( right ),
										SIZEOF( SIGNED32 ), DivALSLLoop );
		RETURN RESULT
	END "DIV";

	PROCEDURE DivSLALLoop( ladr, radr, dadr: ADDRESS; linc, dinc, len: SIZE );
	VAR lval, rval: SIGNED32;  dval: SIGNED32;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  dval := rval DIV lval;  SYSTEM.PUT( dadr, dval );
			INC( ladr, linc );  INC( dadr, dinc );  DEC( len );
		END;
	END DivSLALLoop;

	OPERATOR "DIV"*(left: SIGNED32; CONST right: ARRAY [ ? ] OF SIGNED32): ARRAY {UNSAFE} [ ? ] OF SIGNED32;
	BEGIN
		ApplyBinaryASAOp( RESULT , right, ADDRESSOF( left ),
										SIZEOF( SIGNED32 ), DivSLALLoop );
		RETURN RESULT
	END "DIV";

(** SIZE *)
	PROCEDURE DivAYSYLoop( ladr, radr, dadr: ADDRESS; linc, dinc, len: SIZE );
	VAR lval, rval: SIZE;  dval: SIZE;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  dval := lval DIV rval;  SYSTEM.PUT( dadr, dval );
			INC( ladr, linc );  INC( dadr, dinc );  DEC( len );
		END;
	END DivAYSYLoop;

	OPERATOR "DIV"*(CONST left: ARRAY [ ? ] OF SIZE; right: SIZE ): ARRAY {UNSAFE} [ ? ] OF SIZE;
	BEGIN
		ApplyBinaryASAOp( RESULT , left, ADDRESSOF( right ),
										SIZEOF( SIZE ), DivAYSYLoop );
		RETURN RESULT
	END "DIV";

	PROCEDURE DivSYAYLoop( ladr, radr, dadr: ADDRESS; linc, dinc, len: SIZE );
	VAR lval, rval: SIZE;  dval: SIZE;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  dval := rval DIV lval;  SYSTEM.PUT( dadr, dval );
			INC( ladr, linc );  INC( dadr, dinc );  DEC( len );
		END;
	END DivSYAYLoop;

	OPERATOR "DIV"*(left: SIZE; CONST right: ARRAY [ ? ] OF SIZE): ARRAY {UNSAFE} [ ? ] OF SIZE;
	BEGIN
		ApplyBinaryASAOp( RESULT , right, ADDRESSOF( left ),
										SIZEOF( SIZE ), DivSYAYLoop );
		RETURN RESULT
	END "DIV";

	(*** element-wise modulus array MOD array -> array  ********************************************************************)

(** SIGNED8 *)
	PROCEDURE EModASASLoop( ladr, radr, dadr: ADDRESS; linc, rinc, dinc, len: SIZE );
	VAR lval, rval: SIGNED8;  dval: SIGNED8;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  dval := lval MOD rval;
			SYSTEM.PUT( dadr, dval );  INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );
			DEC( len );
		END;
	END EModASASLoop;

	OPERATOR "MOD"*(CONST left,right: ARRAY [?] OF SIGNED8): ARRAY {UNSAFE} [?] OF SIGNED8;
	BEGIN
		ApplyBinaryAAAOp( RESULT, left, right,
										SIZEOF( SIGNED8 ), EModASASLoop );
		RETURN RESULT
	END "MOD";

(** SIGNED16 *)
	PROCEDURE EModAIAILoop( ladr, radr, dadr: ADDRESS; linc, rinc, dinc, len: SIZE );
	VAR lval, rval: SIGNED16;  dval: SIGNED16;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  dval := lval MOD rval;
			SYSTEM.PUT( dadr, dval );  INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );
			DEC( len );
		END;
	END EModAIAILoop;

	OPERATOR "MOD"*(CONST left,right: ARRAY [?] OF SIGNED16): ARRAY {UNSAFE} [?] OF SIGNED16;
	BEGIN
		ApplyBinaryAAAOp( RESULT, left, right,
										SIZEOF( SIGNED16 ), EModAIAILoop );
		RETURN RESULT
	END "MOD";

(** SIGNED32 *)
	PROCEDURE EModALALLoop( ladr, radr, dadr: ADDRESS; linc, rinc, dinc, len: SIZE );
	VAR lval, rval: SIGNED32;  dval: SIGNED32;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  dval := lval MOD rval;
			SYSTEM.PUT( dadr, dval );  INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );
			DEC( len );
		END;
	END EModALALLoop;

	OPERATOR "MOD"*(CONST left,right: ARRAY [?] OF SIGNED32): ARRAY {UNSAFE} [?] OF SIGNED32;
	BEGIN
		ApplyBinaryAAAOp( RESULT, left, right,
										SIZEOF( SIGNED32 ), EModALALLoop );
		RETURN RESULT
	END "MOD";

(** SIZE *)
	PROCEDURE EModAYAYLoop( ladr, radr, dadr: ADDRESS; linc, rinc, dinc, len: SIZE );
	VAR lval, rval: SIZE;  dval: SIZE;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  dval := lval MOD rval;
			SYSTEM.PUT( dadr, dval );  INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );
			DEC( len );
		END;
	END EModAYAYLoop;

	OPERATOR "MOD"*(CONST left,right: ARRAY [?] OF SIZE): ARRAY {UNSAFE} [?] OF SIZE;
	BEGIN
		ApplyBinaryAAAOp( RESULT, left, right,
										SIZEOF( SIZE ), EModAYAYLoop );
		RETURN RESULT
	END "MOD";

	(*** modulus array MOD scalar -> array and scalar MOD  array -> array ********************************************************************)

(** SIGNED8 *)
	PROCEDURE ModASSSLoop( ladr, radr, dadr: ADDRESS; linc, dinc, len: SIZE );
	VAR lval, rval: SIGNED8;  dval: SIGNED8;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  dval := lval MOD rval;  SYSTEM.PUT( dadr, dval );
			INC( ladr, linc );  INC( dadr, dinc );  DEC( len );
		END;
	END ModASSSLoop;

	OPERATOR "MOD"*(CONST left: ARRAY [ ? ] OF SIGNED8; right: SIGNED8 ): ARRAY {UNSAFE} [ ? ] OF SIGNED8;
	BEGIN
		ApplyBinaryASAOp( RESULT , left, ADDRESSOF( right ),
										SIZEOF( SIGNED8 ), ModASSSLoop );
		RETURN RESULT
	END "MOD";

	PROCEDURE ModSSASLoop( ladr, radr, dadr: ADDRESS; linc, dinc, len: SIZE );
	VAR lval, rval: SIGNED8;  dval: SIGNED8;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  dval := rval MOD lval;  SYSTEM.PUT( dadr, dval );
			INC( ladr, linc );  INC( dadr, dinc );  DEC( len );
		END;
	END ModSSASLoop;

	OPERATOR "MOD"*(left: SIGNED8; CONST right: ARRAY [ ? ] OF SIGNED8): ARRAY {UNSAFE} [ ? ] OF SIGNED8;
	BEGIN
		ApplyBinaryASAOp( RESULT , right, ADDRESSOF( left ),
										SIZEOF( SIGNED8 ), ModSSASLoop );
		RETURN RESULT
	END "MOD";

(** SIGNED16 *)
	PROCEDURE ModAISILoop( ladr, radr, dadr: ADDRESS; linc, dinc, len: SIZE );
	VAR lval, rval: SIGNED16;  dval: SIGNED16;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  dval := lval MOD rval;  SYSTEM.PUT( dadr, dval );
			INC( ladr, linc );  INC( dadr, dinc );  DEC( len );
		END;
	END ModAISILoop;

	OPERATOR "MOD"*(CONST left: ARRAY [ ? ] OF SIGNED16; right: SIGNED16 ): ARRAY {UNSAFE} [ ? ] OF SIGNED16;
	BEGIN
		ApplyBinaryASAOp( RESULT , left, ADDRESSOF( right ),
										SIZEOF( SIGNED16 ), ModAISILoop );
		RETURN RESULT
	END "MOD";

	PROCEDURE ModSIAILoop( ladr, radr, dadr: ADDRESS; linc, dinc, len: SIZE );
	VAR lval, rval: SIGNED16;  dval: SIGNED16;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  dval := rval MOD lval;  SYSTEM.PUT( dadr, dval );
			INC( ladr, linc );  INC( dadr, dinc );  DEC( len );
		END;
	END ModSIAILoop;

	OPERATOR "MOD"*(left: SIGNED16; CONST right: ARRAY [ ? ] OF SIGNED16): ARRAY {UNSAFE} [ ? ] OF SIGNED16;
	BEGIN
		ApplyBinaryASAOp( RESULT , right, ADDRESSOF( left ),
										SIZEOF( SIGNED16 ), ModSIAILoop );
		RETURN RESULT
	END "MOD";

(** SIGNED32 *)
	PROCEDURE ModALSLLoop( ladr, radr, dadr: ADDRESS; linc, dinc, len: SIZE );
	VAR lval, rval: SIGNED32;  dval: SIGNED32;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  dval := lval MOD rval;  SYSTEM.PUT( dadr, dval );
			INC( ladr, linc );  INC( dadr, dinc );  DEC( len );
		END;
	END ModALSLLoop;

	OPERATOR "MOD"*(CONST left: ARRAY [ ? ] OF SIGNED32; right: SIGNED32 ): ARRAY {UNSAFE} [ ? ] OF SIGNED32;
	BEGIN
		ApplyBinaryASAOp( RESULT , left, ADDRESSOF( right ),
										SIZEOF( SIGNED32 ), ModALSLLoop );
		RETURN RESULT
	END "MOD";

	PROCEDURE ModSLALLoop( ladr, radr, dadr: ADDRESS; linc, dinc, len: SIZE );
	VAR lval, rval: SIGNED32;  dval: SIGNED32;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  dval := rval MOD lval;  SYSTEM.PUT( dadr, dval );
			INC( ladr, linc );  INC( dadr, dinc );  DEC( len );
		END;
	END ModSLALLoop;

	OPERATOR "MOD"*(left: SIGNED32; CONST right: ARRAY [ ? ] OF SIGNED32): ARRAY {UNSAFE} [ ? ] OF SIGNED32;
	BEGIN
		ApplyBinaryASAOp( RESULT , right, ADDRESSOF( left ),
										SIZEOF( SIGNED32 ), ModSLALLoop );
		RETURN RESULT
	END "MOD";

(** SIZE *)
	PROCEDURE ModAYSYLoop( ladr, radr, dadr: ADDRESS; linc, dinc, len: SIZE );
	VAR lval, rval: SIZE;  dval: SIZE;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  dval := lval MOD rval;  SYSTEM.PUT( dadr, dval );
			INC( ladr, linc );  INC( dadr, dinc );  DEC( len );
		END;
	END ModAYSYLoop;

	OPERATOR "MOD"*(CONST left: ARRAY [ ? ] OF SIZE; right: SIZE ): ARRAY {UNSAFE} [ ? ] OF SIZE;
	BEGIN
		ApplyBinaryASAOp( RESULT , left, ADDRESSOF( right ),
										SIZEOF( SIZE ), ModAYSYLoop );
		RETURN RESULT
	END "MOD";

	PROCEDURE ModSYAYLoop( ladr, radr, dadr: ADDRESS; linc, dinc, len: SIZE );
	VAR lval, rval: SIZE;  dval: SIZE;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  dval := rval MOD lval;  SYSTEM.PUT( dadr, dval );
			INC( ladr, linc );  INC( dadr, dinc );  DEC( len );
		END;
	END ModSYAYLoop;

	OPERATOR "MOD"*(left: SIZE; CONST right: ARRAY [ ? ] OF SIZE): ARRAY {UNSAFE} [ ? ] OF SIZE;
	BEGIN
		ApplyBinaryASAOp( RESULT , right, ADDRESSOF( left ),
										SIZEOF( SIZE ), ModSYAYLoop );
		RETURN RESULT
	END "MOD";

	(*** scalar product <array,array> -> scalar  ********************************************************************)

(** SIGNED8 *)
	PROCEDURE SPASASLoop( ladr, radr, dadr: ADDRESS; linc, rinc, len: SIZE );
	VAR lval, rval: SIGNED8;  dval: SIGNED32;
	BEGIN
		SYSTEM.GET( dadr, dval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  dval := dval + rval * lval;
			INC( ladr, linc );  INC( radr, rinc );  DEC( len );
		END;
		SYSTEM.PUT( dadr, dval );
	END SPASASLoop;

	OPERATOR "+*"*( CONST left, right: ARRAY [ ? ] OF SIGNED8 ): SIGNED32;
	VAR dest: SIGNED32;
	BEGIN
		dest := 0;
		ApplyBinaryAASOp( ADDRESSOF( dest ), left, right, SPASASLoop );
		RETURN dest;
	END "+*";

(** SIGNED16 *)
	PROCEDURE SPAIAILoop( ladr, radr, dadr: ADDRESS; linc, rinc, len: SIZE );
	VAR lval, rval: SIGNED16;  dval: SIGNED32;
	BEGIN
		SYSTEM.GET( dadr, dval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  dval := dval + rval * lval;
			INC( ladr, linc );  INC( radr, rinc );  DEC( len );
		END;
		SYSTEM.PUT( dadr, dval );
	END SPAIAILoop;

	OPERATOR "+*"*( CONST left, right: ARRAY [ ? ] OF SIGNED16 ): SIGNED32;
	VAR dest: SIGNED32;
	BEGIN
		dest := 0;
		ApplyBinaryAASOp( ADDRESSOF( dest ), left, right, SPAIAILoop );
		RETURN dest;
	END "+*";

(** SIGNED32 *)
	PROCEDURE SPALALLoop( ladr, radr, dadr: ADDRESS; linc, rinc, len: SIZE );
	VAR lval, rval: SIGNED32;  dval: SIGNED32;
	BEGIN
		SYSTEM.GET( dadr, dval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  dval := dval + rval * lval;
			INC( ladr, linc );  INC( radr, rinc );  DEC( len );
		END;
		SYSTEM.PUT( dadr, dval );
	END SPALALLoop;

	OPERATOR "+*"*( CONST left, right: ARRAY [ ? ] OF SIGNED32 ): SIGNED32;
	VAR dest: SIGNED32;
	BEGIN
		dest := 0;
		ApplyBinaryAASOp( ADDRESSOF( dest ), left, right, SPALALLoop );
		RETURN dest;
	END "+*";

(** FLOAT32 *)
	PROCEDURE SPARARLoop( ladr, radr, dadr: ADDRESS; linc, rinc, len: SIZE );
	VAR lval, rval: FLOAT32;  dval: FLOAT32;
	BEGIN
		SYSTEM.GET( dadr, dval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  dval := dval + rval * lval;
			INC( ladr, linc );  INC( radr, rinc );  DEC( len );
		END;
		SYSTEM.PUT( dadr, dval );
	END SPARARLoop;

	OPERATOR "+*"*( CONST left, right: ARRAY [ ? ] OF FLOAT32 ): FLOAT32;
	VAR dest: FLOAT32;
	BEGIN
		dest := 0;
		ApplyBinaryAASOp( ADDRESSOF( dest ), left, right, loopSPARAR );
		RETURN dest;
	END "+*";

	PROCEDURE SPAXAXLoop( ladr, radr, dadr: ADDRESS; linc, rinc, len: SIZE );
	VAR lval, rval, dval: FLOAT64;
	BEGIN
		IF debug THEN
			KernelLog.String( "SPAXAX, ladr,radr,dadr,linc,rinc,len= " );  KernelLog.Int( ladr, 10 );  KernelLog.Int( radr, 10 );
			KernelLog.Int( dadr, 10 );  KernelLog.Int( linc, 10 );  KernelLog.Int( rinc, 10 );
			KernelLog.Int( len, 10 );  KernelLog.Ln;
		END;

		SYSTEM.GET( dadr, dval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  INC( ladr, linc );  SYSTEM.GET( radr, rval );  INC( radr, rinc );
			dval := dval + rval * lval;  DEC( len );
		END;
		SYSTEM.PUT( dadr, dval );
	END SPAXAXLoop;

	OPERATOR "+*"*( CONST left, right: ARRAY [ ? ] OF FLOAT64 ): FLOAT64;
	VAR dest: FLOAT64;
	BEGIN
		dest := 0;
		ApplyBinaryAASOp( ADDRESSOF( dest ), left, right, loopSPAXAX );
		RETURN dest;
	END "+*";

(** COMPLEX32 *)
	PROCEDURE SPAZAZLoop( ladr, radr, dadr: ADDRESS; linc, rinc, len: SIZE );
	VAR lval, rval: COMPLEX32;  dval: COMPLEX32;
	BEGIN
		SYSTEM.GET( dadr, dval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );
			RE(dval) := RE(dval) + RE(lval) * RE(rval) + IM(lval) * IM(rval);
			IM(dval) := IM(dval) - RE(lval) * IM(rval) + IM(lval) * RE(rval);
			INC( ladr, linc );  INC( radr, rinc );  DEC( len );
		END;
		SYSTEM.PUT( dadr, dval );
	END SPAZAZLoop;

	OPERATOR "+*"*( CONST left, right: ARRAY [ ? ] OF COMPLEX32 ): COMPLEX32;
	VAR dest: COMPLEX32;
	BEGIN
		dest := 0;
		ApplyBinaryAASOp( ADDRESSOF( dest ), left, right, loopSPAZAZ );
		RETURN dest;
	END "+*";

	(** COMPLEX32 *)
	PROCEDURE SPALZALZLoop( ladr, radr, dadr: ADDRESS; linc, rinc, len: SIZE );
	VAR lvalRe, lvalIm, rvalRe, rvalIm: FLOAT64;  dvalRe, dvalIm: FLOAT64;
	BEGIN
		SYSTEM.GET( dadr, dvalRe ); SYSTEM.GET( dadr+SIZEOF(FLOAT64), dvalIm );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lvalRe ); SYSTEM.GET( ladr+SIZEOF(FLOAT64), lvalIm );
			SYSTEM.GET( radr, rvalRe ); SYSTEM.GET( radr+SIZEOF(FLOAT64), rvalIm );
			dvalRe := dvalRe + lvalRe * rvalRe + lvalIm * rvalIm;
			dvalIm := dvalIm - lvalRe * rvalIm + lvalIm * rvalRe;
			INC( ladr, linc );  INC( radr, rinc );  DEC( len );
		END;
		SYSTEM.PUT( dadr, dvalRe ); SYSTEM.PUT( dadr+SIZEOF(FLOAT64), dvalIm );
	END SPALZALZLoop;

	OPERATOR "+*"*( CONST left, right: ARRAY [ ? ] OF COMPLEX64 ): COMPLEX64;
	VAR dest: COMPLEX64;
	BEGIN
		dest := 0;
		ApplyBinaryAASOp( ADDRESSOF( dest ),left,right, loopSPALZALZ );
		RETURN dest;
	END "+*";

	(*** element-wise equal: array x array -> array of boolean  ********************************************************************)

(** BOOLEAN *)

	PROCEDURE EEqlABABLoop( ladr, radr, dadr: ADDRESS; linc, rinc, dinc, len: SIZE );
	VAR lval, rval: BOOLEAN;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.PUT( dadr, lval = rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END EEqlABABLoop;

	OPERATOR ".="*(CONST left,right : ARRAY [?] OF BOOLEAN):ARRAY {UNSAFE} [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryAAAOp( RESULT, left, right,
										SIZEOF( BOOLEAN ), EEqlABABLoop );
		RETURN RESULT
	END ".=";

(** SIGNED8 *)

	PROCEDURE EEqlASASLoop( ladr, radr, dadr: ADDRESS; linc, rinc, dinc, len: SIZE );
	VAR lval, rval: SIGNED8;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.PUT( dadr, lval = rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END EEqlASASLoop;

	OPERATOR ".="*(CONST left, right: ARRAY [ ? ] OF SIGNED8 ): ARRAY {UNSAFE} [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryAAAOp( RESULT, left, right,
										SIZEOF( BOOLEAN ), EEqlASASLoop );
		RETURN RESULT
	END ".=";

(** SIGNED16 *)

	PROCEDURE EEqlAIAILoop( ladr, radr, dadr: ADDRESS; linc, rinc, dinc, len: SIZE );
	VAR lval, rval: SIGNED16;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.PUT( dadr, lval = rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END EEqlAIAILoop;

	OPERATOR ".="*(CONST left, right: ARRAY [ ? ] OF SIGNED16 ): ARRAY {UNSAFE} [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryAAAOp( RESULT, left, right,
										SIZEOF( BOOLEAN ), EEqlAIAILoop );
		RETURN RESULT
	END ".=";

(** SIGNED32 *)

	PROCEDURE EEqlALALLoop( ladr, radr, dadr: ADDRESS; linc, rinc, dinc, len: SIZE );
	VAR lval, rval: SIGNED32;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.PUT( dadr, lval = rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END EEqlALALLoop;

	OPERATOR ".="*(CONST left, right: ARRAY [ ? ] OF SIGNED32 ): ARRAY {UNSAFE} [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryAAAOp( RESULT, left, right,
										SIZEOF( BOOLEAN ), EEqlALALLoop );
		RETURN RESULT
	END ".=";

(** FLOAT32 *)
	PROCEDURE EEqlARARLoop( ladr, radr, dadr: ADDRESS; linc, rinc, dinc, len: SIZE );
	VAR lval, rval: FLOAT32;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.PUT( dadr, lval = rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END EEqlARARLoop;

	OPERATOR ".="*(CONST left, right: ARRAY [ ? ] OF FLOAT32 ): ARRAY {UNSAFE} [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryAAAOp( RESULT, left, right,
										SIZEOF( BOOLEAN ), EEqlARARLoop );
		RETURN RESULT
	END ".=";

(** FLOAT64 *)
	PROCEDURE EEqlAXAXLoop( ladr, radr, dadr: ADDRESS; linc, rinc, dinc, len: SIZE );
	VAR lval, rval: FLOAT64;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.PUT( dadr, lval = rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END EEqlAXAXLoop;

	OPERATOR ".="*(CONST left, right: ARRAY [ ? ] OF FLOAT64 ): ARRAY {UNSAFE} [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryAAAOp( RESULT, left, right,
										SIZEOF( BOOLEAN ), EEqlAXAXLoop );
		RETURN RESULT
	END ".=";

	(*** elementwise equal  array x scalar ->  array of boolean ********************************************************************)

(** BOOLEAN *)
	PROCEDURE EEqlABSBLoop( ladr, radr, dadr: ADDRESS; linc, dinc, len: SIZE );
	VAR lval, rval: BOOLEAN;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.PUT( dadr, lval = rval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END EEqlABSBLoop;

	OPERATOR ".="*(CONST left : ARRAY [?] OF BOOLEAN; right: BOOLEAN):ARRAY {UNSAFE} [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryASAOp( RESULT , left, ADDRESSOF( right ),
										SIZEOF( BOOLEAN ), EEqlABSBLoop );
		RETURN RESULT
	END ".=";

	OPERATOR ".="*(left: BOOLEAN; CONST right : ARRAY {UNSAFE} [?] OF BOOLEAN):ARRAY {UNSAFE} [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryASAOp( RESULT , right, ADDRESSOF( left ),
										SIZEOF( BOOLEAN ), EEqlABSBLoop );
		RETURN RESULT
	END ".=";

(** SIGNED8 *)
	PROCEDURE EEqlASSSLoop( ladr, radr, dadr: ADDRESS; linc, dinc, len: SIZE );
	VAR lval, rval: SIGNED8;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.PUT( dadr, lval = rval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END EEqlASSSLoop;

	OPERATOR ".="*(CONST left: ARRAY [ ? ] OF SIGNED8; right: SIGNED8 ): ARRAY {UNSAFE} [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryASAOp( RESULT , left, ADDRESSOF( right ),
										SIZEOF( BOOLEAN ), EEqlASSSLoop );
		RETURN RESULT
	END ".=";

	OPERATOR ".="*(left: SIGNED8; CONST right: ARRAY [ ? ] OF SIGNED8): ARRAY {UNSAFE} [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryASAOp( RESULT , right, ADDRESSOF( left ),
										SIZEOF( BOOLEAN ), EEqlASSSLoop );
		RETURN RESULT
	END ".=";

(** SIGNED16 *)
	PROCEDURE EEqlAISILoop( ladr, radr, dadr: ADDRESS; linc, dinc, len: SIZE );
	VAR lval, rval: SIGNED16;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.PUT( dadr, lval = rval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END EEqlAISILoop;

	OPERATOR ".="*(CONST left: ARRAY [ ? ] OF SIGNED16; right: SIGNED16 ): ARRAY {UNSAFE} [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryASAOp( RESULT , left, ADDRESSOF( right ),
										SIZEOF( BOOLEAN ), EEqlAISILoop );
		RETURN RESULT
	END ".=";

	OPERATOR ".="*(left: SIGNED16; CONST right: ARRAY [ ? ] OF SIGNED16): ARRAY {UNSAFE} [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryASAOp( RESULT , right, ADDRESSOF( left ),
										SIZEOF( BOOLEAN ), EEqlAISILoop );
		RETURN RESULT
	END ".=";

(** SIGNED32 *)
	PROCEDURE EEqlALSLLoop( ladr, radr, dadr: ADDRESS; linc, dinc, len: SIZE );
	VAR lval, rval: SIGNED32;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.PUT( dadr, lval = rval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END EEqlALSLLoop;

	OPERATOR ".="*(CONST left: ARRAY [ ? ] OF SIGNED32; right: SIGNED32 ): ARRAY {UNSAFE} [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryASAOp( RESULT , left, ADDRESSOF( right ),
										SIZEOF( BOOLEAN ), EEqlALSLLoop );
		RETURN RESULT
	END ".=";

	OPERATOR ".="*(left: SIGNED32; CONST right: ARRAY [ ? ] OF SIGNED32): ARRAY {UNSAFE} [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryASAOp( RESULT , right, ADDRESSOF( left ),
										SIZEOF( BOOLEAN ), EEqlALSLLoop );
		RETURN RESULT
	END ".=";

(** FLOAT32 *)
	PROCEDURE EEqlARSRLoop( ladr, radr, dadr: ADDRESS; linc, dinc, len: SIZE );
	VAR lval, rval: FLOAT32;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.PUT( dadr, lval = rval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END EEqlARSRLoop;

	OPERATOR ".="*(CONST left: ARRAY [ ? ] OF FLOAT32; right: FLOAT32 ): ARRAY {UNSAFE} [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryASAOp( RESULT , left, ADDRESSOF( right ),
										SIZEOF( BOOLEAN ), EEqlARSRLoop );
		RETURN RESULT
	END ".=";

	OPERATOR ".="*(left: FLOAT32; CONST right: ARRAY [ ? ] OF FLOAT32): ARRAY {UNSAFE} [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryASAOp( RESULT , right, ADDRESSOF( left ),
										SIZEOF( BOOLEAN ), EEqlARSRLoop );
		RETURN RESULT
	END ".=";

(** FLOAT64 *)
	PROCEDURE EEqlAXSXLoop( ladr, radr, dadr: ADDRESS; linc, dinc, len: SIZE );
	VAR lval, rval: FLOAT64;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.PUT( dadr, lval = rval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END EEqlAXSXLoop;

	OPERATOR ".="*(CONST left: ARRAY [ ? ] OF FLOAT64; right: FLOAT64 ): ARRAY {UNSAFE} [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryASAOp( RESULT , left, ADDRESSOF( right ),
										SIZEOF( BOOLEAN ), EEqlAXSXLoop );
		RETURN RESULT
	END ".=";

	OPERATOR ".="*(left: FLOAT64; CONST right: ARRAY [ ? ] OF FLOAT64): ARRAY {UNSAFE} [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryASAOp( RESULT , right, ADDRESSOF( left ),
										SIZEOF( BOOLEAN ), EEqlAXSXLoop );
		RETURN RESULT
	END ".=";

	(*** elementwise nequal: array x array -> array of boolean  ********************************************************************)

(** BOOLEAN *)
	PROCEDURE ENeqABABLoop( ladr, radr, dadr: ADDRESS; linc, rinc, dinc, len: SIZE );
	VAR lval, rval: BOOLEAN;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.PUT( dadr, lval # rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END ENeqABABLoop;

	OPERATOR ".#"*(CONST left,right : ARRAY [?] OF BOOLEAN):ARRAY {UNSAFE} [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryAAAOp( RESULT, left, right,
										SIZEOF( BOOLEAN ), ENeqABABLoop );
		RETURN RESULT
	END ".#";

(** SIGNED8 *)
	PROCEDURE ENeqASASLoop( ladr, radr, dadr: ADDRESS; linc, rinc, dinc, len: SIZE );
	VAR lval, rval: SIGNED8;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.PUT( dadr, lval # rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END ENeqASASLoop;

	OPERATOR ".#"*(CONST left, right: ARRAY [ ? ] OF SIGNED8 ): ARRAY {UNSAFE} [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryAAAOp( RESULT, left, right,
										SIZEOF( BOOLEAN ), ENeqASASLoop );
		RETURN RESULT
	END ".#";

(** SIGNED16*)
	PROCEDURE ENeqAIAILoop( ladr, radr, dadr: ADDRESS; linc, rinc, dinc, len: SIZE );
	VAR lval, rval: SIGNED16;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.PUT( dadr, lval # rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END ENeqAIAILoop;

	OPERATOR ".#"*(CONST left, right: ARRAY [ ? ] OF SIGNED16 ): ARRAY {UNSAFE} [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryAAAOp( RESULT, left, right,
										SIZEOF( BOOLEAN ), ENeqAIAILoop );
		RETURN RESULT
	END ".#";

(** SIGNED32*)
	PROCEDURE ENeqALALLoop( ladr, radr, dadr: ADDRESS; linc, rinc, dinc, len: SIZE );
	VAR lval, rval: SIGNED32;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.PUT( dadr, lval # rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END ENeqALALLoop;

	OPERATOR ".#"*(CONST left, right: ARRAY [ ? ] OF SIGNED32 ): ARRAY {UNSAFE} [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryAAAOp( RESULT, left, right,
										SIZEOF( BOOLEAN ), ENeqALALLoop );
		RETURN RESULT
	END ".#";

(** FLOAT32 *)
	PROCEDURE ENeqARARLoop( ladr, radr, dadr: ADDRESS; linc, rinc, dinc, len: SIZE );
	VAR lval, rval: FLOAT32;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.PUT( dadr, lval # rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END ENeqARARLoop;

	OPERATOR ".#"*(CONST left, right: ARRAY [ ? ] OF FLOAT32 ): ARRAY {UNSAFE} [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryAAAOp( RESULT, left, right,
										SIZEOF( BOOLEAN ), ENeqARARLoop );
		RETURN RESULT
	END ".#";

(** FLOAT64 *)
	PROCEDURE ENeqAXAXLoop( ladr, radr, dadr: ADDRESS; linc, rinc, dinc, len: SIZE );
	VAR lval, rval: FLOAT64;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.PUT( dadr, lval # rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END ENeqAXAXLoop;

	OPERATOR ".#"*(CONST left, right: ARRAY [ ? ] OF FLOAT64 ): ARRAY {UNSAFE} [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryAAAOp( RESULT, left, right,
										SIZEOF( BOOLEAN ), ENeqAXAXLoop );
		RETURN RESULT
	END ".#";

	(*** elementwise nequal  array x scalar ->  array of boolean ********************************************************************)

(** BOOLEAN *)
	PROCEDURE ENeqABSBLoop( ladr, radr, dadr: ADDRESS; linc, dinc, len: SIZE );
	VAR lval, rval: BOOLEAN;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.PUT( dadr, lval # rval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END ENeqABSBLoop;

	OPERATOR ".#"*(CONST left : ARRAY [?] OF BOOLEAN; right: BOOLEAN):ARRAY {UNSAFE} [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryASAOp( RESULT , left, ADDRESSOF( right ),
										SIZEOF( BOOLEAN ), ENeqABSBLoop );
		RETURN RESULT
	END ".#";

	OPERATOR ".#"*(left: BOOLEAN; CONST right : ARRAY {UNSAFE} [?] OF BOOLEAN):ARRAY {UNSAFE} [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryASAOp( RESULT , right, ADDRESSOF( left ),
										SIZEOF( BOOLEAN ), ENeqABSBLoop );
		RETURN RESULT
	END ".#";

(** SIGNED8 *)
	PROCEDURE ENeqASSSLoop( ladr, radr, dadr: ADDRESS; linc, dinc, len: SIZE );
	VAR lval, rval: SIGNED8;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.PUT( dadr, lval # rval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END ENeqASSSLoop;

	OPERATOR ".#"*(CONST left: ARRAY [ ? ] OF SIGNED8; right: SIGNED8 ): ARRAY {UNSAFE} [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryASAOp( RESULT , left, ADDRESSOF( right ),
										SIZEOF( BOOLEAN ), ENeqASSSLoop );
		RETURN RESULT
	END ".#";

	OPERATOR ".#"*(left: SIGNED8; CONST right: ARRAY [ ? ] OF SIGNED8): ARRAY {UNSAFE} [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryASAOp( RESULT , right, ADDRESSOF( left ),
										SIZEOF( BOOLEAN ), ENeqASSSLoop );
		RETURN RESULT
	END ".#";

(** SIGNED16 *)
	PROCEDURE ENeqAISILoop( ladr, radr, dadr: ADDRESS; linc, dinc, len: SIZE );
	VAR lval, rval: SIGNED16;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.PUT( dadr, lval # rval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END ENeqAISILoop;

	OPERATOR ".#"*(CONST left: ARRAY [ ? ] OF SIGNED16; right: SIGNED16 ): ARRAY {UNSAFE} [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryASAOp( RESULT , left, ADDRESSOF( right ),
										SIZEOF( BOOLEAN ), ENeqAISILoop );
		RETURN RESULT
	END ".#";

	OPERATOR ".#"*(left: SIGNED16; CONST right: ARRAY [ ? ] OF SIGNED16): ARRAY {UNSAFE} [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryASAOp( RESULT , right, ADDRESSOF( left ),
										SIZEOF( BOOLEAN ), ENeqAISILoop );
		RETURN RESULT
	END ".#";

(** SIGNED32 *)
	PROCEDURE ENeqALSLLoop( ladr, radr, dadr: ADDRESS; linc, dinc, len: SIZE );
	VAR lval, rval: SIGNED32;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.PUT( dadr, lval # rval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END ENeqALSLLoop;

	OPERATOR ".#"*(CONST left: ARRAY [ ? ] OF SIGNED32; right: SIGNED32 ): ARRAY {UNSAFE} [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryASAOp( RESULT , left, ADDRESSOF( right ),
										SIZEOF( BOOLEAN ), ENeqALSLLoop );
		RETURN RESULT
	END ".#";

	OPERATOR ".#"*(left: SIGNED32; CONST right: ARRAY [ ? ] OF SIGNED32): ARRAY {UNSAFE} [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryASAOp( RESULT , right, ADDRESSOF( left ),
										SIZEOF( BOOLEAN ), ENeqALSLLoop );
		RETURN RESULT
	END ".#";

(** FLOAT32 *)
	PROCEDURE ENeqARSRLoop( ladr, radr, dadr: ADDRESS; linc, dinc, len: SIZE );
	VAR lval, rval: FLOAT32;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.PUT( dadr, lval # rval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END ENeqARSRLoop;

	OPERATOR ".#"*(CONST left: ARRAY [ ? ] OF FLOAT32; right: FLOAT32 ): ARRAY {UNSAFE} [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryASAOp( RESULT , left, ADDRESSOF( right ),
										SIZEOF( BOOLEAN ), ENeqARSRLoop );
		RETURN RESULT
	END ".#";

	OPERATOR ".#"*(left: FLOAT32; CONST right: ARRAY [ ? ] OF FLOAT32): ARRAY {UNSAFE} [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryASAOp( RESULT , right, ADDRESSOF( left ),
										SIZEOF( BOOLEAN ), ENeqARSRLoop );
		RETURN RESULT
	END ".#";

(** FLOAT64 *)
	PROCEDURE ENeqAXSXLoop( ladr, radr, dadr: ADDRESS; linc, dinc, len: SIZE );
	VAR lval, rval: FLOAT64;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.PUT( dadr, lval # rval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END ENeqAXSXLoop;

	OPERATOR ".#"*(CONST left: ARRAY [ ? ] OF FLOAT64; right: FLOAT64 ): ARRAY {UNSAFE} [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryASAOp( RESULT , left, ADDRESSOF( right ),
										SIZEOF( BOOLEAN ), ENeqAXSXLoop );
		RETURN RESULT
	END ".#";

	OPERATOR ".#"*(left: FLOAT64; CONST right: ARRAY [ ? ] OF FLOAT64): ARRAY {UNSAFE} [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryASAOp( RESULT , right, ADDRESSOF( left ),
										SIZEOF( BOOLEAN ), ENeqAXSXLoop );
		RETURN RESULT
	END ".#";

	(*** elementwise greater than: array x array -> array of boolean  ********************************************************************)

(** SIGNED8 *)
	PROCEDURE EGtrASASLoop( ladr, radr, dadr: ADDRESS; linc, rinc, dinc, len: SIZE );
	VAR lval, rval: SIGNED8;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.PUT( dadr, lval > rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END EGtrASASLoop;

	OPERATOR ".>"*(CONST left, right: ARRAY [ ? ] OF SIGNED8 ): ARRAY {UNSAFE} [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryAAAOp( RESULT, left, right,
										SIZEOF( BOOLEAN ), EGtrASASLoop );
		RETURN RESULT
	END ".>";

(** SIGNED16 *)
	PROCEDURE EGtrAIAILoop( ladr, radr, dadr: ADDRESS; linc, rinc, dinc, len: SIZE );
	VAR lval, rval: SIGNED16;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.PUT( dadr, lval > rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END EGtrAIAILoop;

	OPERATOR ".>"*(CONST left, right: ARRAY [ ? ] OF SIGNED16 ): ARRAY {UNSAFE} [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryAAAOp( RESULT, left, right,
										SIZEOF( BOOLEAN ), EGtrAIAILoop );
		RETURN RESULT
	END ".>";

(** SIGNED32 *)
	PROCEDURE EGtrALALLoop( ladr, radr, dadr: ADDRESS; linc, rinc, dinc, len: SIZE );
	VAR lval, rval: SIGNED32;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.PUT( dadr, lval > rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END EGtrALALLoop;

	OPERATOR ".>"*(CONST left, right: ARRAY [ ? ] OF SIGNED32 ): ARRAY {UNSAFE} [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryAAAOp( RESULT, left, right,
										SIZEOF( BOOLEAN ), EGtrALALLoop );
		RETURN RESULT
	END ".>";

(** FLOAT32 *)
	PROCEDURE EGtrARARLoop( ladr, radr, dadr: ADDRESS; linc, rinc, dinc, len: SIZE );
	VAR lval, rval: FLOAT32;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.PUT( dadr, lval > rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END EGtrARARLoop;

	OPERATOR ".>"*(CONST left, right: ARRAY [ ? ] OF FLOAT32 ): ARRAY {UNSAFE} [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryAAAOp( RESULT, left, right,
										SIZEOF( BOOLEAN ), EGtrARARLoop );
		RETURN RESULT
	END ".>";

(** FLOAT64 *)
	PROCEDURE EGtrAXAXLoop( ladr, radr, dadr: ADDRESS; linc, rinc, dinc, len: SIZE );
	VAR lval, rval: FLOAT64;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.PUT( dadr, lval > rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END EGtrAXAXLoop;

	OPERATOR ".>"*(CONST left, right: ARRAY [ ? ] OF FLOAT64 ): ARRAY {UNSAFE} [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryAAAOp( RESULT, left, right,
										SIZEOF( BOOLEAN ), EGtrAXAXLoop );
		RETURN RESULT
	END ".>";

	(*** elementwise greater  array x scalar ->  array of boolean ********************************************************************)

(** SIGNED8 *)
	PROCEDURE EGtrASSSLoop( ladr, radr, dadr: ADDRESS; linc, dinc, len: SIZE );
	VAR lval, rval: SIGNED8;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.PUT( dadr, lval > rval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END EGtrASSSLoop;

	OPERATOR ".>"*(CONST left: ARRAY [ ? ] OF SIGNED8; right: SIGNED8 ): ARRAY {UNSAFE} [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryASAOp( RESULT , left, ADDRESSOF( right ),
										SIZEOF( BOOLEAN ), EGtrASSSLoop );
		RETURN RESULT
	END ".>";

	OPERATOR ".<"*(left: SIGNED8; CONST right: ARRAY [ ? ] OF SIGNED8): ARRAY {UNSAFE} [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryASAOp( RESULT , right, ADDRESSOF( left ),
										SIZEOF( BOOLEAN ), EGtrASSSLoop );
		RETURN RESULT
	END ".<";

(** SIGNED16 *)
	PROCEDURE EGtrAISILoop( ladr, radr, dadr: ADDRESS; linc, dinc, len: SIZE );
	VAR lval, rval: SIGNED16;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.PUT( dadr, lval > rval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END EGtrAISILoop;

	OPERATOR ".>"*(CONST left: ARRAY [ ? ] OF SIGNED16; right: SIGNED16 ): ARRAY {UNSAFE} [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryASAOp( RESULT , left, ADDRESSOF( right ),
										SIZEOF( BOOLEAN ), EGtrAISILoop );
		RETURN RESULT
	END ".>";

	OPERATOR ".<"*(left: SIGNED16; CONST right: ARRAY [ ? ] OF SIGNED16): ARRAY {UNSAFE} [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryASAOp( RESULT , right, ADDRESSOF( left ),
										SIZEOF( BOOLEAN ), EGtrAISILoop );
		RETURN RESULT
	END ".<";

(** SIGNED32 *)
	PROCEDURE EGtrALSLLoop( ladr, radr, dadr: ADDRESS; linc, dinc, len: SIZE );
	VAR lval, rval: SIGNED32;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.PUT( dadr, lval > rval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END EGtrALSLLoop;

	OPERATOR ".>"*(CONST left: ARRAY [ ? ] OF SIGNED32; right: SIGNED32 ): ARRAY {UNSAFE} [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryASAOp( RESULT , left, ADDRESSOF( right ),
										SIZEOF( BOOLEAN ), EGtrALSLLoop );
		RETURN RESULT
	END ".>";

	OPERATOR ".<"*(left: SIGNED32; CONST right: ARRAY [ ? ] OF SIGNED32): ARRAY {UNSAFE} [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryASAOp( RESULT , right, ADDRESSOF( left ),
										SIZEOF( BOOLEAN ), EGtrALSLLoop );
		RETURN RESULT
	END ".<";

(** FLOAT32 *)
	PROCEDURE EGtrARSRLoop( ladr, radr, dadr: ADDRESS; linc, dinc, len: SIZE );
	VAR lval, rval: FLOAT32;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.PUT( dadr, lval > rval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END EGtrARSRLoop;

	OPERATOR ".>"*(CONST left: ARRAY [ ? ] OF FLOAT32; right: FLOAT32 ): ARRAY {UNSAFE} [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryASAOp( RESULT , left, ADDRESSOF( right ),
										SIZEOF( BOOLEAN ), EGtrARSRLoop );
		RETURN RESULT
	END ".>";

	OPERATOR ".<"*(left: FLOAT32; CONST right: ARRAY [ ? ] OF FLOAT32): ARRAY {UNSAFE} [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryASAOp( RESULT , right, ADDRESSOF( left ),
										SIZEOF( BOOLEAN ), EGtrARSRLoop );
		RETURN RESULT
	END ".<";

(** FLOAT64 *)
	PROCEDURE EGtrAXSXLoop( ladr, radr, dadr: ADDRESS; linc, dinc, len: SIZE );
	VAR lval, rval: FLOAT64;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.PUT( dadr, lval > rval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END EGtrAXSXLoop;

	OPERATOR ".>"*(CONST left: ARRAY [ ? ] OF FLOAT64; right: FLOAT64 ): ARRAY {UNSAFE} [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryASAOp( RESULT , left, ADDRESSOF( right ),
										SIZEOF( BOOLEAN ), EGtrAXSXLoop );
		RETURN RESULT
	END ".>";

	OPERATOR ".<"*(left: FLOAT64; CONST right: ARRAY [ ? ] OF FLOAT64): ARRAY {UNSAFE} [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryASAOp( RESULT , right, ADDRESSOF( left ),
										SIZEOF( BOOLEAN ), EGtrAXSXLoop );
		RETURN RESULT
	END ".<";

	(*** elementwise greater or equal: array x array -> array of boolean  ********************************************************************)

(** SIGNED8 *)
	PROCEDURE EGeqASASLoop( ladr, radr, dadr: ADDRESS; linc, rinc, dinc, len: SIZE );
	VAR lval, rval: SIGNED8;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.PUT( dadr, lval >= rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END EGeqASASLoop;

	OPERATOR ".>="*(CONST left, right: ARRAY [ ? ] OF SIGNED8 ): ARRAY {UNSAFE} [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryAAAOp( RESULT, left, right,
										SIZEOF( BOOLEAN ), EGeqASASLoop );
		RETURN RESULT
	END ".>=";

(** SIGNED16 *)
	PROCEDURE EGeqAIAILoop( ladr, radr, dadr: ADDRESS; linc, rinc, dinc, len: SIZE );
	VAR lval, rval: SIGNED16;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.PUT( dadr, lval >= rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END EGeqAIAILoop;

	OPERATOR ".>="*(CONST left, right: ARRAY [ ? ] OF SIGNED16 ): ARRAY {UNSAFE} [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryAAAOp( RESULT, left, right,
										SIZEOF( BOOLEAN ), EGeqAIAILoop );
		RETURN RESULT
	END ".>=";

(** SIGNED32 *)
	PROCEDURE EGeqALALLoop( ladr, radr, dadr: ADDRESS; linc, rinc, dinc, len: SIZE );
	VAR lval, rval: SIGNED32;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.PUT( dadr, lval >= rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END EGeqALALLoop;

	OPERATOR ".>="*(CONST left, right: ARRAY [ ? ] OF SIGNED32 ): ARRAY {UNSAFE} [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryAAAOp( RESULT, left, right,
										SIZEOF( BOOLEAN ), EGeqALALLoop );
		RETURN RESULT
	END ".>=";

(** FLOAT32 *)
	PROCEDURE EGeqARARLoop( ladr, radr, dadr: ADDRESS; linc, rinc, dinc, len: SIZE );
	VAR lval, rval: FLOAT32;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.PUT( dadr, lval >= rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END EGeqARARLoop;

	OPERATOR ".>="*(CONST left, right: ARRAY [ ? ] OF FLOAT32 ): ARRAY {UNSAFE} [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryAAAOp( RESULT, left, right,
										SIZEOF( BOOLEAN ), EGeqARARLoop );
		RETURN RESULT
	END ".>=";

(** FLOAT64 *)
	PROCEDURE EGeqAXAXLoop( ladr, radr, dadr: ADDRESS; linc, rinc, dinc, len: SIZE );
	VAR lval, rval: FLOAT64;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.PUT( dadr, lval >= rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END EGeqAXAXLoop;

	OPERATOR ".>="*(CONST left, right: ARRAY [ ? ] OF FLOAT64 ): ARRAY {UNSAFE} [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryAAAOp( RESULT, left, right,
										SIZEOF( BOOLEAN ), EGeqAXAXLoop );
		RETURN RESULT
	END ".>=";

	(*** elementwise geq  array x scalar ->  array of boolean ********************************************************************)

(** SIGNED8 *)
	PROCEDURE EGeqASSSLoop( ladr, radr, dadr: ADDRESS; linc, dinc, len: SIZE );
	VAR lval, rval: SIGNED8;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.PUT( dadr, lval >= rval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END EGeqASSSLoop;

	OPERATOR ".>="*(CONST left: ARRAY [ ? ] OF SIGNED8; right: SIGNED8 ): ARRAY {UNSAFE} [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryASAOp( RESULT , left, ADDRESSOF( right ),
										SIZEOF( BOOLEAN ), EGeqASSSLoop );
		RETURN RESULT
	END ".>=";

	OPERATOR ".<="*(left: SIGNED8; CONST right: ARRAY [ ? ] OF SIGNED8): ARRAY {UNSAFE} [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryASAOp( RESULT , right, ADDRESSOF( left ),
										SIZEOF( BOOLEAN ), EGeqASSSLoop );
		RETURN RESULT
	END ".<=";

(** SIGNED16 *)
	PROCEDURE EGeqAISILoop( ladr, radr, dadr: ADDRESS; linc, dinc, len: SIZE );
	VAR lval, rval: SIGNED16;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.PUT( dadr, lval >= rval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END EGeqAISILoop;

	OPERATOR ".>="*(CONST left: ARRAY [ ? ] OF SIGNED16; right: SIGNED16 ): ARRAY {UNSAFE} [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryASAOp( RESULT , left, ADDRESSOF( right ),
										SIZEOF( BOOLEAN ), EGeqAISILoop );
		RETURN RESULT
	END ".>=";

	OPERATOR ".<="*(left: SIGNED16; CONST right: ARRAY [ ? ] OF SIGNED16): ARRAY {UNSAFE} [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryASAOp( RESULT , right, ADDRESSOF( left ),
										SIZEOF( BOOLEAN ), EGeqAISILoop );
		RETURN RESULT
	END ".<=";

(** SIGNED32 *)
	PROCEDURE EGeqALSLLoop( ladr, radr, dadr: ADDRESS; linc, dinc, len: SIZE );
	VAR lval, rval: SIGNED32;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.PUT( dadr, lval >= rval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END EGeqALSLLoop;

	OPERATOR ".>="*(CONST left: ARRAY [ ? ] OF SIGNED32; right: SIGNED32 ): ARRAY {UNSAFE} [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryASAOp( RESULT , left, ADDRESSOF( right ),
										SIZEOF( BOOLEAN ), EGeqALSLLoop );
		RETURN RESULT
	END ".>=";

	OPERATOR ".<="*(left: SIGNED32; CONST right: ARRAY [ ? ] OF SIGNED32): ARRAY {UNSAFE} [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryASAOp( RESULT , right, ADDRESSOF( left ),
										SIZEOF( BOOLEAN ), EGeqALSLLoop );
		RETURN RESULT
	END ".<=";

(** FLOAT32 *)
	PROCEDURE EGeqARSRLoop( ladr, radr, dadr: ADDRESS; linc, dinc, len: SIZE );
	VAR lval, rval: FLOAT32;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.PUT( dadr, lval >= rval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END EGeqARSRLoop;

	OPERATOR ".>="*(CONST left: ARRAY [ ? ] OF FLOAT32; right: FLOAT32 ): ARRAY {UNSAFE} [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryASAOp( RESULT , left, ADDRESSOF( right ),
										SIZEOF( BOOLEAN ), EGeqARSRLoop );
		RETURN RESULT
	END ".>=";

	OPERATOR ".<="*(left: FLOAT32; CONST right: ARRAY [ ? ] OF FLOAT32): ARRAY {UNSAFE} [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryASAOp( RESULT , right, ADDRESSOF( left ),
										SIZEOF( BOOLEAN ), EGeqARSRLoop );
		RETURN RESULT
	END ".<=";

(** FLOAT64 *)
	PROCEDURE EGeqAXSXLoop( ladr, radr, dadr: ADDRESS; linc, dinc, len: SIZE );
	VAR lval, rval: FLOAT64;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.PUT( dadr, lval >= rval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END EGeqAXSXLoop;

	OPERATOR ".>="*(CONST left: ARRAY [ ? ] OF FLOAT64; right: FLOAT64 ): ARRAY {UNSAFE} [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryASAOp( RESULT , left, ADDRESSOF( right ),
										SIZEOF( BOOLEAN ), EGeqAXSXLoop );
		RETURN RESULT
	END ".>=";

	OPERATOR ".<="*(left: FLOAT64; CONST right: ARRAY [ ? ] OF FLOAT64): ARRAY {UNSAFE} [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryASAOp( RESULT , right, ADDRESSOF( left ),
										SIZEOF( BOOLEAN ), EGeqAXSXLoop );
		RETURN RESULT
	END ".<=";

	(*** elementwise less than: array x array -> array of boolean  ********************************************************************)

(** SIGNED8 *)
	PROCEDURE ELssASASLoop( ladr, radr, dadr: ADDRESS; linc, rinc, dinc, len: SIZE );
	VAR lval, rval: SIGNED8;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.PUT( dadr, lval < rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END ELssASASLoop;

	OPERATOR ".<"*(CONST left, right: ARRAY [ ? ] OF SIGNED8 ): ARRAY {UNSAFE} [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryAAAOp( RESULT, left, right,
										SIZEOF( BOOLEAN ), ELssASASLoop );
		RETURN RESULT
	END ".<";

(** SIGNED16 *)
	PROCEDURE ELssAIAILoop( ladr, radr, dadr: ADDRESS; linc, rinc, dinc, len: SIZE );
	VAR lval, rval: SIGNED16;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.PUT( dadr, lval < rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END ELssAIAILoop;

	OPERATOR ".<"*(CONST left, right: ARRAY [ ? ] OF SIGNED16 ): ARRAY {UNSAFE} [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryAAAOp( RESULT, left, right,
										SIZEOF( BOOLEAN ), ELssAIAILoop );
		RETURN RESULT
	END ".<";

(** SIGNED32*)
	PROCEDURE ELssALALLoop( ladr, radr, dadr: ADDRESS; linc, rinc, dinc, len: SIZE );
	VAR lval, rval: SIGNED32;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.PUT( dadr, lval < rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END ELssALALLoop;

	OPERATOR ".<"*(CONST left, right: ARRAY [ ? ] OF SIGNED32 ): ARRAY {UNSAFE} [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryAAAOp( RESULT, left, right,
										SIZEOF( BOOLEAN ), ELssALALLoop );
		RETURN RESULT
	END ".<";

(** FLOAT32 *)
	PROCEDURE ELssARARLoop( ladr, radr, dadr: ADDRESS; linc, rinc, dinc, len: SIZE );
	VAR lval, rval: FLOAT32;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.PUT( dadr, lval < rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END ELssARARLoop;

	OPERATOR ".<"*(CONST left, right: ARRAY [ ? ] OF FLOAT32 ): ARRAY {UNSAFE} [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryAAAOp( RESULT, left, right,
										SIZEOF( BOOLEAN ), ELssARARLoop );
		RETURN RESULT
	END ".<";

(** FLOAT64 *)
	PROCEDURE ELssAXAXLoop( ladr, radr, dadr: ADDRESS; linc, rinc, dinc, len: SIZE );
	VAR lval, rval: FLOAT64;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.PUT( dadr, lval < rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END ELssAXAXLoop;

	OPERATOR ".<"*(CONST left, right: ARRAY [ ? ] OF FLOAT64 ): ARRAY {UNSAFE} [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryAAAOp( RESULT, left, right,
										SIZEOF( BOOLEAN ), ELssAXAXLoop );
		RETURN RESULT
	END ".<";

	(*** elementwise less  array x scalar ->  array of boolean ********************************************************************)

(** SIGNED8 *)
	PROCEDURE ELssASSSLoop( ladr, radr, dadr: ADDRESS; linc, dinc, len: SIZE );
	VAR lval, rval: SIGNED8;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.PUT( dadr, lval < rval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END ELssASSSLoop;

	OPERATOR ".<"*(CONST left: ARRAY [ ? ] OF SIGNED8; right: SIGNED8 ): ARRAY {UNSAFE} [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryASAOp( RESULT , left, ADDRESSOF( right ),
										SIZEOF( BOOLEAN ), ELssASSSLoop );
		RETURN RESULT
	END ".<";

	OPERATOR ".>"*(left: SIGNED8; CONST right: ARRAY [ ? ] OF SIGNED8): ARRAY {UNSAFE} [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryASAOp( RESULT , right, ADDRESSOF( left ),
										SIZEOF( BOOLEAN ), ELssASSSLoop );
		RETURN RESULT
	END ".>";

(** SIGNED16 *)
	PROCEDURE ELssAISILoop( ladr, radr, dadr: ADDRESS; linc, dinc, len: SIZE );
	VAR lval, rval: SIGNED16;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.PUT( dadr, lval < rval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END ELssAISILoop;

	OPERATOR ".<"*(CONST left: ARRAY [ ? ] OF SIGNED16; right: SIGNED16 ): ARRAY {UNSAFE} [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryASAOp( RESULT , left, ADDRESSOF( right ),
										SIZEOF( BOOLEAN ), ELssAISILoop );
		RETURN RESULT
	END ".<";

	OPERATOR ".>"*(left: SIGNED16; CONST right: ARRAY [ ? ] OF SIGNED16): ARRAY {UNSAFE} [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryASAOp( RESULT , right, ADDRESSOF( left ),
										SIZEOF( BOOLEAN ), ELssAISILoop );
		RETURN RESULT
	END ".>";

(** SIGNED32 *)
	PROCEDURE ELssALSLLoop( ladr, radr, dadr: ADDRESS; linc, dinc, len: SIZE );
	VAR lval, rval: SIGNED32;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.PUT( dadr, lval < rval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END ELssALSLLoop;

	OPERATOR ".<"*(CONST left: ARRAY [ ? ] OF SIGNED32; right: SIGNED32 ): ARRAY {UNSAFE} [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryASAOp( RESULT , left, ADDRESSOF( right ),
										SIZEOF( BOOLEAN ), ELssALSLLoop );
		RETURN RESULT
	END ".<";

	OPERATOR ".>"*(left: SIGNED32; CONST right: ARRAY [ ? ] OF SIGNED32): ARRAY {UNSAFE} [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryASAOp( RESULT , right, ADDRESSOF( left ),
										SIZEOF( BOOLEAN ), ELssALSLLoop );
		RETURN RESULT
	END ".>";

(** FLOAT32 *)
	PROCEDURE ELssARSRLoop( ladr, radr, dadr: ADDRESS; linc, dinc, len: SIZE );
	VAR lval, rval: FLOAT32;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.PUT( dadr, lval < rval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END ELssARSRLoop;

	OPERATOR ".<"*(CONST left: ARRAY [ ? ] OF FLOAT32; right: FLOAT32 ): ARRAY {UNSAFE} [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryASAOp( RESULT , left, ADDRESSOF( right ),
										SIZEOF( BOOLEAN ), ELssARSRLoop );
		RETURN RESULT
	END ".<";

	OPERATOR ".>"*(left: FLOAT32; CONST right: ARRAY [ ? ] OF FLOAT32): ARRAY {UNSAFE} [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryASAOp( RESULT , right, ADDRESSOF( left ),
										SIZEOF( BOOLEAN ), ELssARSRLoop );
		RETURN RESULT
	END ".>";

(** FLOAT64 *)
	PROCEDURE ELssAXSXLoop( ladr, radr, dadr: ADDRESS; linc, dinc, len: SIZE );
	VAR lval, rval: FLOAT64;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.PUT( dadr, lval < rval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END ELssAXSXLoop;

	OPERATOR ".<"*(CONST left: ARRAY [ ? ] OF FLOAT64; right: FLOAT64 ): ARRAY {UNSAFE} [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryASAOp( RESULT , left, ADDRESSOF( right ),
										SIZEOF( BOOLEAN ), ELssAXSXLoop );
		RETURN RESULT
	END ".<";

	OPERATOR ".>"*(left: FLOAT64; CONST right: ARRAY [ ? ] OF FLOAT64): ARRAY {UNSAFE} [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryASAOp( RESULT , right, ADDRESSOF( left ),
										SIZEOF( BOOLEAN ), ELssAXSXLoop );
		RETURN RESULT
	END ".>";

	(*** elementwise less or equal: array x array -> array of boolean ********************************************************************)

(** SIGNED8 *)
	PROCEDURE ELeqASASLoop( ladr, radr, dadr: ADDRESS; linc, rinc, dinc, len: SIZE );
	VAR lval, rval: SIGNED8;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.PUT( dadr, lval <= rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END ELeqASASLoop;

	OPERATOR ".<="*(CONST left, right: ARRAY [ ? ] OF SIGNED8 ): ARRAY {UNSAFE} [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryAAAOp( RESULT, left, right,
										SIZEOF( BOOLEAN ), ELeqASASLoop );
		RETURN RESULT
	END ".<=";

(** SIGNED16 *)
	PROCEDURE ELeqAIAILoop( ladr, radr, dadr: ADDRESS; linc, rinc, dinc, len: SIZE );
	VAR lval, rval: SIGNED16;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.PUT( dadr, lval <= rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END ELeqAIAILoop;

	OPERATOR ".<="*(CONST left, right: ARRAY [ ? ] OF SIGNED16 ): ARRAY {UNSAFE} [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryAAAOp( RESULT, left, right,
										SIZEOF( BOOLEAN ), ELeqAIAILoop );
		RETURN RESULT
	END ".<=";

(** SIGNED32 *)
	PROCEDURE ELeqALALLoop( ladr, radr, dadr: ADDRESS; linc, rinc, dinc, len: SIZE );
	VAR lval, rval: SIGNED32;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.PUT( dadr, lval <= rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END ELeqALALLoop;

	OPERATOR ".<="*(CONST left, right: ARRAY [ ? ] OF SIGNED32 ): ARRAY {UNSAFE} [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryAAAOp( RESULT, left, right,
										SIZEOF( BOOLEAN ), ELeqALALLoop );
		RETURN RESULT
	END ".<=";

(** FLOAT32  *)
	PROCEDURE ELeqARARLoop( ladr, radr, dadr: ADDRESS; linc, rinc, dinc, len: SIZE );
	VAR lval, rval: FLOAT32;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.PUT( dadr, lval <= rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END ELeqARARLoop;

	OPERATOR ".<="*(CONST left, right: ARRAY [ ? ] OF FLOAT32 ): ARRAY {UNSAFE} [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryAAAOp( RESULT, left, right,
										SIZEOF( BOOLEAN ), ELeqARARLoop );
		RETURN RESULT
	END ".<=";

(** FLOAT64*)
	PROCEDURE ELeqAXAXLoop( ladr, radr, dadr: ADDRESS; linc, rinc, dinc, len: SIZE );
	VAR lval, rval: FLOAT64;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.PUT( dadr, lval <= rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END ELeqAXAXLoop;

	OPERATOR ".<="*(CONST left, right: ARRAY [ ? ] OF FLOAT64 ): ARRAY {UNSAFE} [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryAAAOp( RESULT, left, right,
										SIZEOF( BOOLEAN ), ELeqAXAXLoop );
		RETURN RESULT
	END ".<=";

	(*** elementwise leq  array x scalar ->  array of boolean ********************************************************************)

(** SIGNED8 *)
	PROCEDURE ELeqASSSLoop( ladr, radr, dadr: ADDRESS; linc, dinc, len: SIZE );
	VAR lval, rval: SIGNED8;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.PUT( dadr, lval <= rval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END ELeqASSSLoop;

	OPERATOR ".<="*(CONST left: ARRAY [ ? ] OF SIGNED8; right: SIGNED8 ): ARRAY {UNSAFE} [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryASAOp( RESULT , left, ADDRESSOF( right ),
										SIZEOF( BOOLEAN ), ELeqASSSLoop );
		RETURN RESULT
	END ".<=";

	OPERATOR ".>="*(left: SIGNED8; CONST right: ARRAY [ ? ] OF SIGNED8): ARRAY {UNSAFE} [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryASAOp( RESULT , right, ADDRESSOF( left ),
										SIZEOF( BOOLEAN ), ELeqASSSLoop );
		RETURN RESULT
	END ".>=";

(** SIGNED16 *)
	PROCEDURE ELeqAISILoop( ladr, radr, dadr: ADDRESS; linc, dinc, len: SIZE );
	VAR lval, rval: SIGNED16;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.PUT( dadr, lval <= rval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END ELeqAISILoop;

	OPERATOR ".<="*(CONST left: ARRAY [ ? ] OF SIGNED16; right: SIGNED16 ): ARRAY {UNSAFE} [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryASAOp( RESULT , left, ADDRESSOF( right ),
										SIZEOF( BOOLEAN ), ELeqAISILoop );
		RETURN RESULT
	END ".<=";

	OPERATOR ".>="*(left: SIGNED16; CONST right: ARRAY [ ? ] OF SIGNED16): ARRAY {UNSAFE} [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryASAOp( RESULT , right, ADDRESSOF( left ),
										SIZEOF( BOOLEAN ), ELeqAISILoop );
		RETURN RESULT
	END ".>=";

(** SIGNED32 *)
	PROCEDURE ELeqALSLLoop( ladr, radr, dadr: ADDRESS; linc, dinc, len: SIZE );
	VAR lval, rval: SIGNED32;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.PUT( dadr, lval <= rval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END ELeqALSLLoop;

	OPERATOR ".<="*(CONST left: ARRAY [ ? ] OF SIGNED32; right: SIGNED32 ): ARRAY {UNSAFE} [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryASAOp( RESULT , left, ADDRESSOF( right ),
										SIZEOF( BOOLEAN ), ELeqALSLLoop );
		RETURN RESULT
	END ".<=";

	OPERATOR ".>="*(left: SIGNED32; CONST right: ARRAY [ ? ] OF SIGNED32): ARRAY {UNSAFE} [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryASAOp( RESULT , right, ADDRESSOF( left ),
										SIZEOF( BOOLEAN ), ELeqALSLLoop );
		RETURN RESULT
	END ".>=";

(** FLOAT32 *)
	PROCEDURE ELeqARSRLoop( ladr, radr, dadr: ADDRESS; linc, dinc, len: SIZE );
	VAR lval, rval: FLOAT32;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.PUT( dadr, lval <= rval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END ELeqARSRLoop;

	OPERATOR ".<="*(CONST left: ARRAY [ ? ] OF FLOAT32; right: FLOAT32 ): ARRAY {UNSAFE} [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryASAOp( RESULT , left, ADDRESSOF( right ),
										SIZEOF( BOOLEAN ), ELeqARSRLoop );
		RETURN RESULT
	END ".<=";

	OPERATOR ".>="*(left: FLOAT32; CONST right: ARRAY [ ? ] OF FLOAT32): ARRAY {UNSAFE} [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryASAOp( RESULT , right, ADDRESSOF( left ),
										SIZEOF( BOOLEAN ), ELeqARSRLoop );
		RETURN RESULT
	END ".>=";

(** FLOAT64 *)
	PROCEDURE ELeqAXSXLoop( ladr, radr, dadr: ADDRESS; linc, dinc, len: SIZE );
	VAR lval, rval: FLOAT64;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.PUT( dadr, lval <= rval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END ELeqAXSXLoop;

	OPERATOR ".<="*(CONST left: ARRAY [ ? ] OF FLOAT64; right: FLOAT64 ): ARRAY {UNSAFE} [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryASAOp( RESULT , left, ADDRESSOF( right ),
										SIZEOF( BOOLEAN ), ELeqAXSXLoop );
		RETURN RESULT
	END ".<=";

	OPERATOR ".>="*(left: FLOAT64; CONST right: ARRAY [ ? ] OF FLOAT64): ARRAY {UNSAFE} [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryASAOp( RESULT , right, ADDRESSOF( left ),
										SIZEOF( BOOLEAN ), ELeqAXSXLoop );
		RETURN RESULT
	END ".>=";

	(*** elementwise or, elementwise and  ********************************************************************)

(** array x array *)
	PROCEDURE ElOrABABLoop( ladr, radr, dadr: ADDRESS; linc, rinc, dinc, len: SIZE );
	VAR lval, rval: BOOLEAN;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.PUT( dadr, (lval OR rval) );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END ElOrABABLoop;

	OPERATOR "OR"*(CONST left,right : ARRAY [?] OF BOOLEAN):ARRAY {UNSAFE} [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryAAAOp( RESULT, left, right,
										SIZEOF( BOOLEAN ), ElOrABABLoop );
		RETURN RESULT
	END "OR";

	PROCEDURE ElAndABABLoop( ladr, radr, dadr: ADDRESS; linc, rinc, dinc, len:SIZE );
	VAR lval, rval: BOOLEAN;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.PUT( dadr, lval & rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END ElAndABABLoop;

	OPERATOR "&"*(CONST left,right : ARRAY [?] OF BOOLEAN):ARRAY {UNSAFE} [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryAAAOp( RESULT, left, right,
										SIZEOF( BOOLEAN ), ElAndABABLoop );
		RETURN RESULT
	END "&";

(** array x boolean *)
	PROCEDURE ElOrABSBLoop( ladr, radr, dadr: ADDRESS; linc, dinc, len: SIZE );
	VAR lval, rval: BOOLEAN;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.PUT( dadr, lval OR rval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END ElOrABSBLoop;

	OPERATOR "OR"*(CONST left : ARRAY [?] OF BOOLEAN; right: BOOLEAN):ARRAY {UNSAFE} [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryASAOp( RESULT , left, ADDRESSOF( right ),
										SIZEOF( BOOLEAN ), ElOrABSBLoop );
		RETURN RESULT
	END "OR";

	OPERATOR "OR"*(left: BOOLEAN; CONST right : ARRAY {UNSAFE} [?] OF BOOLEAN):ARRAY {UNSAFE} [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryASAOp( RESULT , right, ADDRESSOF( left ),
										SIZEOF( BOOLEAN ), ElOrABSBLoop );
		RETURN RESULT
	END "OR";

	PROCEDURE ElAndABSBLoop( ladr, radr, dadr: ADDRESS; linc, dinc, len: SIZE );
	VAR lval, rval: BOOLEAN;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.PUT( dadr, lval & rval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END ElAndABSBLoop;

	OPERATOR "&"*(CONST left : ARRAY [?] OF BOOLEAN; right: BOOLEAN):ARRAY {UNSAFE} [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryASAOp( RESULT , left, ADDRESSOF( right ),
										SIZEOF( BOOLEAN ), ElAndABSBLoop );
		RETURN RESULT
	END "&";

	OPERATOR "&"*(left: BOOLEAN; CONST right : ARRAY {UNSAFE} [?] OF BOOLEAN):ARRAY {UNSAFE} [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryASAOp( RESULT , right, ADDRESSOF( left ),
										SIZEOF( BOOLEAN ), ElAndABSBLoop );
		RETURN RESULT
	END "&";

	(*** less than, greater or equal: array x array -> boolean  ********************************************************************)

(** SIGNED8 *)
	PROCEDURE LssASASLoop( ladr, radr: ADDRESS; linc, rinc, len: SIZE ): BOOLEAN;
	VAR lval, rval: SIGNED8;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );
			IF rval <= lval THEN RETURN FALSE END;
			INC( ladr, linc );  INC( radr, rinc );  DEC( len );
		END;
		RETURN TRUE;
	END LssASASLoop;

	OPERATOR "<"*( CONST left, right: ARRAY [ ? ] OF SIGNED8 ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryAABOp( left, right, LssASASLoop , FALSE);
	END "<";

	PROCEDURE GeqASASLoop( ladr, radr: ADDRESS; linc, rinc, len: SIZE ): BOOLEAN;
	VAR lval, rval: SIGNED8;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );
			IF rval > lval THEN RETURN FALSE END;
			INC( ladr, linc );  INC( radr, rinc );  DEC( len );
		END;
		RETURN TRUE;
	END GeqASASLoop;

	OPERATOR ">="*( CONST left, right: ARRAY [ ? ] OF SIGNED8 ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryAABOp( left, right, GeqASASLoop , FALSE);
	END ">=";

(** SIGNED16 *)
	PROCEDURE LssAIAILoop( ladr, radr: ADDRESS; linc, rinc, len: SIZE ): BOOLEAN;
	VAR lval, rval: SIGNED16;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );
			IF rval <= lval THEN RETURN FALSE END;
			INC( ladr, linc );  INC( radr, rinc );  DEC( len );
		END;
		RETURN TRUE;
	END LssAIAILoop;

	OPERATOR "<"*( CONST left, right: ARRAY [ ? ] OF SIGNED16 ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryAABOp( left, right, LssAIAILoop , FALSE);
	END "<";

	PROCEDURE GeqAIAILoop( ladr, radr: ADDRESS; linc, rinc, len: SIZE ): BOOLEAN;
	VAR lval, rval: SIGNED16;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );
			IF rval > lval THEN RETURN FALSE END;
			INC( ladr, linc );  INC( radr, rinc );  DEC( len );
		END;
		RETURN TRUE;
	END GeqAIAILoop;

	OPERATOR ">="*( CONST left, right: ARRAY [ ? ] OF SIGNED16 ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryAABOp( left, right, GeqAIAILoop , FALSE);
	END ">=";

(** SIGNED32 *)
	PROCEDURE LssALALLoop( ladr, radr: ADDRESS; linc, rinc, len: SIZE ): BOOLEAN;
	VAR lval, rval: SIGNED32;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );
			IF rval <= lval THEN RETURN FALSE END;
			INC( ladr, linc );  INC( radr, rinc );  DEC( len );
		END;
		RETURN TRUE;
	END LssALALLoop;

	OPERATOR "<"*( CONST left, right: ARRAY [ ? ] OF SIGNED32 ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryAABOp( left, right, LssALALLoop , FALSE);
	END "<";

	PROCEDURE GeqALALLoop( ladr, radr: ADDRESS; linc, rinc, len: SIZE ): BOOLEAN;
	VAR lval, rval: SIGNED32;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );
			IF rval > lval THEN RETURN FALSE END;
			INC( ladr, linc );  INC( radr, rinc );  DEC( len );
		END;
		RETURN TRUE;
	END GeqALALLoop;

	OPERATOR ">="*( CONST left, right: ARRAY [ ? ] OF SIGNED32 ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryAABOp( left, right, GeqALALLoop , FALSE);
	END ">=";

(** SIZE *)
	PROCEDURE LssAZAZLoop( ladr, radr: ADDRESS; linc, rinc, len: SIZE ): BOOLEAN;
	VAR lval, rval: SIGNED32;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );
			IF rval <= lval THEN RETURN FALSE END;
			INC( ladr, linc );  INC( radr, rinc );  DEC( len );
		END;
		RETURN TRUE;
	END LssAZAZLoop;

	OPERATOR "<"*( CONST left, right: ARRAY [ ? ] OF SIZE ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryAABOp( left, right, LssAZAZLoop , FALSE);
	END "<";

	PROCEDURE GeqAZAZLoop( ladr, radr: ADDRESS; linc, rinc, len: SIZE ): BOOLEAN;
	VAR lval, rval: SIZE;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );
			IF rval > lval THEN RETURN FALSE END;
			INC( ladr, linc );  INC( radr, rinc );  DEC( len );
		END;
		RETURN TRUE;
	END GeqAZAZLoop;

	OPERATOR ">="*( CONST left, right: ARRAY [ ? ] OF SIZE ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryAABOp( left, right, GeqAZAZLoop , FALSE);
	END ">=";

(** FLOAT32 *)
	PROCEDURE LssARARLoop( ladr, radr: ADDRESS; linc, rinc, len: SIZE ): BOOLEAN;
	VAR lval, rval: FLOAT32;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );
			IF rval <= lval THEN RETURN FALSE END;
			INC( ladr, linc );  INC( radr, rinc );  DEC( len );
		END;
		RETURN TRUE;
	END LssARARLoop;

	OPERATOR "<"*( CONST left, right: ARRAY [ ? ] OF FLOAT32 ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryAABOp( left, right, LssARARLoop , FALSE);
	END "<";

	PROCEDURE GeqARARLoop( ladr, radr: ADDRESS; linc, rinc, len: SIZE ): BOOLEAN;
	VAR lval, rval: FLOAT32;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );
			IF rval > lval THEN RETURN FALSE END;
			INC( ladr, linc );  INC( radr, rinc );  DEC( len );
		END;
		RETURN TRUE;
	END GeqARARLoop;

	OPERATOR ">="*( CONST left, right: ARRAY [ ? ] OF FLOAT32 ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryAABOp( left, right, GeqARARLoop , FALSE);
	END ">=";

(** FLOAT64 *)
	PROCEDURE LssAXAXLoop( ladr, radr: ADDRESS; linc, rinc, len: SIZE ): BOOLEAN;
	VAR lval, rval: FLOAT64;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );
			IF rval <= lval THEN RETURN FALSE END;
			INC( ladr, linc );  INC( radr, rinc );  DEC( len );
		END;
		RETURN TRUE;
	END LssAXAXLoop;

	OPERATOR "<"*( CONST left, right: ARRAY [ ? ] OF FLOAT64 ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryAABOp( left, right, LssAXAXLoop , FALSE);
	END "<";

	PROCEDURE GeqAXAXLoop( ladr, radr: ADDRESS; linc, rinc, len: SIZE ): BOOLEAN;
	VAR lval, rval: FLOAT64;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );
			IF rval > lval THEN RETURN FALSE END;
			INC( ladr, linc );  INC( radr, rinc );  DEC( len );
		END;
		RETURN TRUE;
	END GeqAXAXLoop;

	OPERATOR ">="*( CONST left, right: ARRAY [ ? ] OF FLOAT64 ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryAABOp( left, right, GeqAXAXLoop , FALSE);
	END ">=";

	(*** less than, greater or equal: array x array -> boolean  ********************************************************************)

(** SIGNED8 *)
	PROCEDURE GtrASASLoop( ladr, radr: ADDRESS; linc, rinc, len: SIZE ): BOOLEAN;
	VAR lval, rval: SIGNED8;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );
			IF rval >= lval THEN RETURN FALSE END;
			INC( ladr, linc );  INC( radr, rinc );  DEC( len );
		END;
		RETURN TRUE;
	END GtrASASLoop;

	OPERATOR ">"*( CONST left, right: ARRAY [ ? ] OF SIGNED8 ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryAABOp( left, right, GtrASASLoop , FALSE);
	END ">";

	PROCEDURE LeqASASLoop( ladr, radr: ADDRESS; linc, rinc, len: SIZE ): BOOLEAN;
	VAR lval, rval: SIGNED8;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );
			IF rval < lval THEN RETURN FALSE END;
			INC( ladr, linc );  INC( radr, rinc );  DEC( len );
		END;
		RETURN TRUE;
	END LeqASASLoop;

	OPERATOR "<="*( CONST left, right: ARRAY [ ? ] OF SIGNED8 ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryAABOp( left, right, LeqASASLoop , FALSE);
	END "<=";

(** SIGNED16 *)
	PROCEDURE GtrAIAILoop( ladr, radr: ADDRESS; linc, rinc, len: SIZE ): BOOLEAN;
	VAR lval, rval: SIGNED16;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );
			IF rval >= lval THEN RETURN FALSE END;
			INC( ladr, linc );  INC( radr, rinc );  DEC( len );
		END;
		RETURN TRUE;
	END GtrAIAILoop;

	OPERATOR ">"*( CONST left, right: ARRAY [ ? ] OF SIGNED16 ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryAABOp( left, right, GtrAIAILoop , FALSE);
	END ">";

	PROCEDURE LeqAIAILoop( ladr, radr: ADDRESS; linc, rinc, len: SIZE ): BOOLEAN;
	VAR lval, rval: SIGNED16;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );
			IF rval < lval THEN RETURN FALSE END;
			INC( ladr, linc );  INC( radr, rinc );  DEC( len );
		END;
		RETURN TRUE;
	END LeqAIAILoop;

	OPERATOR "<="*( CONST left, right: ARRAY [ ? ] OF SIGNED16 ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryAABOp( left, right, LeqAIAILoop ,FALSE);
	END "<=";

(** SIGNED32 *)
	PROCEDURE GtrALALLoop( ladr, radr: ADDRESS; linc, rinc, len: SIZE ): BOOLEAN;
	VAR lval, rval: SIGNED32;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );
			IF rval >= lval THEN RETURN FALSE END;
			INC( ladr, linc );  INC( radr, rinc );  DEC( len );
		END;
		RETURN TRUE;
	END GtrALALLoop;

	OPERATOR ">"*( CONST left, right: ARRAY [ ? ] OF SIGNED32 ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryAABOp( left, right, GtrALALLoop , FALSE);
	END ">";

	PROCEDURE LeqALALLoop( ladr, radr: ADDRESS; linc, rinc, len: SIZE ): BOOLEAN;
	VAR lval, rval: SIGNED32;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );
			IF rval < lval THEN RETURN FALSE END;
			INC( ladr, linc );  INC( radr, rinc );  DEC( len );
		END;
		RETURN TRUE;
	END LeqALALLoop;

	OPERATOR "<="*( CONST left, right: ARRAY [ ? ] OF SIGNED32 ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryAABOp( left, right, LeqALALLoop , FALSE);
	END "<=";

(** SIZE *)
	PROCEDURE GtrAZAZLoop( ladr, radr: ADDRESS; linc, rinc, len: SIZE ): BOOLEAN;
	VAR lval, rval: SIZE;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );
			IF rval >= lval THEN RETURN FALSE END;
			INC( ladr, linc );  INC( radr, rinc );  DEC( len );
		END;
		RETURN TRUE;
	END GtrAZAZLoop;

	OPERATOR ">"*( CONST left, right: ARRAY [ ? ] OF SIZE ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryAABOp( left, right, GtrAZAZLoop , FALSE);
	END ">";

	PROCEDURE LeqAZAZLoop( ladr, radr: ADDRESS; linc, rinc, len: SIZE ): BOOLEAN;
	VAR lval, rval: SIZE;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );
			IF rval < lval THEN RETURN FALSE END;
			INC( ladr, linc );  INC( radr, rinc );  DEC( len );
		END;
		RETURN TRUE;
	END LeqAZAZLoop;

	OPERATOR "<="*( CONST left, right: ARRAY [ ? ] OF SIZE ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryAABOp( left, right, LeqAZAZLoop , FALSE);
	END "<=";

(** SIZE *)
	PROCEDURE GtrARARLoop( ladr, radr: ADDRESS; linc, rinc, len: SIZE ): BOOLEAN;
	VAR lval, rval: FLOAT32;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );
			IF rval >= lval THEN RETURN FALSE END;
			INC( ladr, linc );  INC( radr, rinc );  DEC( len );
		END;
		RETURN TRUE;
	END GtrARARLoop;

	OPERATOR ">"*( CONST left, right: ARRAY [ ? ] OF FLOAT32 ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryAABOp( left, right, GtrARARLoop , FALSE);
	END ">";

	PROCEDURE LeqARARLoop( ladr, radr: ADDRESS; linc, rinc, len: SIZE ): BOOLEAN;
	VAR lval, rval: FLOAT32;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );
			IF rval < lval THEN RETURN FALSE END;
			INC( ladr, linc );  INC( radr, rinc );  DEC( len );
		END;
		RETURN TRUE;
	END LeqARARLoop;

	OPERATOR "<="*( CONST left, right: ARRAY [ ? ] OF FLOAT32 ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryAABOp( left, right, LeqARARLoop , FALSE);
	END "<=";

(** FLOAT64 *)
	PROCEDURE GtrAXAXLoop( ladr, radr: ADDRESS; linc, rinc, len: SIZE ): BOOLEAN;
	VAR lval, rval: FLOAT64;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );
			IF rval >= lval THEN RETURN FALSE END;
			INC( ladr, linc );  INC( radr, rinc );  DEC( len );
		END;
		RETURN TRUE;
	END GtrAXAXLoop;

	OPERATOR ">"*( CONST left, right: ARRAY [ ? ] OF FLOAT64 ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryAABOp( left, right, GtrAXAXLoop , FALSE);
	END ">";

	PROCEDURE LeqAXAXLoop( ladr, radr: ADDRESS; linc, rinc, len: SIZE ): BOOLEAN;
	VAR lval, rval: FLOAT64;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );
			IF rval < lval THEN RETURN FALSE END;
			INC( ladr, linc );  INC( radr, rinc );  DEC( len );
		END;
		RETURN TRUE;
	END LeqAXAXLoop;

	OPERATOR "<="*( CONST left, right: ARRAY [ ? ] OF FLOAT64 ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryAABOp( left, right, LeqAXAXLoop , FALSE);
	END "<=";

	(*** equals: array x array -> boolean  ********************************************************************)

(** BOOLEAN *)
	PROCEDURE EqlABABLoop( ladr, radr: ADDRESS; linc, rinc, len: SIZE ): BOOLEAN;
	VAR lval, rval: BOOLEAN;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );
			IF rval # lval THEN RETURN FALSE END;
			INC( ladr, linc );  INC( radr, rinc );  DEC( len );
		END;
		RETURN TRUE;
	END EqlABABLoop;

	OPERATOR "="*( CONST left, right: ARRAY [ ? ] OF BOOLEAN ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryAABOp( left, right, EqlABABLoop, FALSE);
	END "=";

	OPERATOR "#"*( CONST left, right: ARRAY [ ? ] OF BOOLEAN ): BOOLEAN;
	BEGIN
		RETURN ~ApplyBinaryAABOp( left, right, EqlABABLoop, FALSE);
	END "#";

(** SIGNED8 *)
	PROCEDURE EqlASASLoop( ladr, radr: ADDRESS; linc, rinc, len: SIZE ): BOOLEAN;
	VAR lval, rval: SIGNED8;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );
			IF rval # lval THEN RETURN FALSE END;
			INC( ladr, linc );  INC( radr, rinc );  DEC( len );
		END;
		RETURN TRUE;
	END EqlASASLoop;

	OPERATOR "="*( CONST left, right: ARRAY [ ? ] OF SIGNED8 ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryAABOp( left, right, EqlASASLoop , FALSE);
	END "=";

	OPERATOR "#"*( CONST left, right: ARRAY [ ? ] OF SIGNED8 ): BOOLEAN;
	BEGIN
		RETURN ~ApplyBinaryAABOp( left, right, EqlASASLoop, FALSE );
	END "#";

(** SIGNED16 *)
	PROCEDURE EqlAIAILoop( ladr, radr: ADDRESS; linc, rinc, len: SIZE ): BOOLEAN;
	VAR lval, rval: SIGNED16;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );
			IF rval # lval THEN RETURN FALSE END;
			INC( ladr, linc );  INC( radr, rinc );  DEC( len );
		END;
		RETURN TRUE;
	END EqlAIAILoop;

	OPERATOR "="*( CONST left, right: ARRAY [ ? ] OF SIGNED16 ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryAABOp( left, right, EqlAIAILoop, FALSE );
	END "=";

	OPERATOR "#"*( CONST left, right: ARRAY [ ? ] OF SIGNED16 ): BOOLEAN;
	BEGIN
		RETURN ~ApplyBinaryAABOp( left, right, EqlAIAILoop, FALSE );
	END "#";

(** SIGNED32 *)
	PROCEDURE EqlALALLoop( ladr, radr: ADDRESS; linc, rinc, len: SIZE ): BOOLEAN;
	VAR lval, rval: SIGNED32;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );
			IF rval # lval THEN RETURN FALSE END;
			INC( ladr, linc );  INC( radr, rinc );  DEC( len );
		END;
		RETURN TRUE;
	END EqlALALLoop;

	OPERATOR "="*( CONST left, right: ARRAY [ ? ] OF SIGNED32 ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryAABOp( left, right, EqlALALLoop, FALSE );
	END "=";

	OPERATOR "#"*( CONST left, right: ARRAY [ ? ] OF SIGNED32 ): BOOLEAN;
	BEGIN
		RETURN ~ApplyBinaryAABOp( left, right, EqlALALLoop, FALSE );
	END "#";

(** SIZE *)
	PROCEDURE EqlAZAZLoop( ladr, radr: ADDRESS; linc, rinc, len: SIZE ): BOOLEAN;
	VAR lval, rval: SIZE;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );
			IF rval # lval THEN RETURN FALSE END;
			INC( ladr, linc );  INC( radr, rinc );  DEC( len );
		END;
		RETURN TRUE;
	END EqlAZAZLoop;

	OPERATOR "="*( CONST left, right: ARRAY [ ? ] OF SIZE ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryAABOp( left, right, EqlAZAZLoop, FALSE );
	END "=";

	OPERATOR "#"*( CONST left, right: ARRAY [ ? ] OF SIZE ): BOOLEAN;
	BEGIN
		RETURN ~ApplyBinaryAABOp( left, right, EqlAZAZLoop, FALSE );
	END "#";

(** FLOAT32 *)
	PROCEDURE EqlARARLoop( ladr, radr: ADDRESS; linc, rinc, len: SIZE ): BOOLEAN;
	VAR lval, rval: FLOAT32;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );
			IF rval # lval THEN RETURN FALSE END;
			INC( ladr, linc );  INC( radr, rinc );  DEC( len );
		END;
		RETURN TRUE;
	END EqlARARLoop;

	OPERATOR "="*( CONST left, right: ARRAY [ ? ] OF FLOAT32 ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryAABOp( left, right, EqlARARLoop, FALSE );
	END "=";

	OPERATOR "#"*( CONST left, right: ARRAY [ ? ] OF FLOAT32 ): BOOLEAN;
	BEGIN
		RETURN ~ApplyBinaryAABOp( left, right, EqlARARLoop, FALSE );
	END "#";

(** FLOAT64 *)
	PROCEDURE EqlAXAXLoop( ladr, radr: ADDRESS; linc, rinc, len: SIZE ): BOOLEAN;
	VAR lval, rval: FLOAT64;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );
			IF rval # lval THEN RETURN FALSE END;
			INC( ladr, linc );  INC( radr, rinc );  DEC( len );
		END;
		RETURN TRUE;
	END EqlAXAXLoop;

	OPERATOR "="*( CONST left, right: ARRAY [ ? ] OF FLOAT64 ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryAABOp( left, right, EqlAXAXLoop, FALSE );
	END "=";

	OPERATOR "#"*( CONST left, right: ARRAY [ ? ] OF FLOAT64 ): BOOLEAN;
	BEGIN
		RETURN ~ApplyBinaryAABOp( left, right, EqlAXAXLoop, FALSE );
	END "#";

(** COMPLEX32 *)
	PROCEDURE EqlACACLoop( ladr, radr: ADDRESS; linc, rinc, len: SIZE ): BOOLEAN;
	VAR lval, rval: COMPLEX32;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );
			IF rval # lval THEN RETURN FALSE END;
			INC( ladr, linc );  INC( radr, rinc );  DEC( len );
		END;
		RETURN TRUE;
	END EqlACACLoop;

	OPERATOR "="*( CONST left, right: ARRAY [ ? ] OF COMPLEX32 ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryAABOp( left, right, EqlACACLoop, FALSE );
	END "=";

	OPERATOR "#"*( CONST left, right: ARRAY [ ? ] OF COMPLEX32 ): BOOLEAN;
	BEGIN
		RETURN ~ApplyBinaryAABOp( left, right, EqlACACLoop, FALSE );
	END "#";

(** COMPLEX64 *)
	PROCEDURE EqlALZALZLoop( ladr, radr: ADDRESS; linc, rinc, len: SIZE ): BOOLEAN;
	VAR lvalRe, lvalIm, rvalRe, rvalIm: FLOAT64;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lvalRe ); SYSTEM.GET( ladr+SIZEOF(FLOAT64), lvalIm );
			SYSTEM.GET( radr, rvalRe ); SYSTEM.GET( radr+SIZEOF(FLOAT64), rvalIm );
			IF (rvalRe # lvalRe) OR (rvalIm # lvalIm) THEN RETURN FALSE END;
			INC( ladr, linc );  INC( radr, rinc );  DEC( len );
		END;
		RETURN TRUE;
	END EqlALZALZLoop;

	OPERATOR "="*( CONST left, right: ARRAY [ ? ] OF COMPLEX64 ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryAABOp( left, right, EqlALZALZLoop, FALSE );
	END "=";

	OPERATOR "#"*( CONST left, right: ARRAY [ ? ] OF COMPLEX64 ): BOOLEAN;
	BEGIN
		RETURN ~ApplyBinaryAABOp( left, right, EqlALZALZLoop, FALSE );
	END "#";

	(*** equals: array x scalar -> boolean  ********************************************************************)

(** BOOLEAN *)
	PROCEDURE EqlABSBLoop( ladr, radr: ADDRESS; linc, len: SIZE ): BOOLEAN;
	VAR lval, rval: BOOLEAN;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );
			IF lval # rval THEN RETURN FALSE END;
			INC( ladr, linc );  DEC( len );
		END;
		RETURN TRUE;
	END EqlABSBLoop;

	OPERATOR "="*( CONST left: ARRAY [ ? ] OF BOOLEAN;
											right: BOOLEAN ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( left, ADDRESSOF( right ), EqlABSBLoop );
	END "=";

	OPERATOR "="*( left: BOOLEAN;
											CONST right: ARRAY [ ? ] OF BOOLEAN ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( right , ADDRESSOF( left ), EqlABSBLoop );
	END "=";

	OPERATOR "#"*( CONST left: ARRAY [ ? ] OF BOOLEAN;
											right: BOOLEAN ): BOOLEAN;
	BEGIN
		RETURN ~(left = right);
	END "#";

	OPERATOR "#"*( left: BOOLEAN;
											CONST right: ARRAY [ ? ] OF BOOLEAN ): BOOLEAN;
	BEGIN
		RETURN ~( left = right );
	END "#";

(** SIGNED8 *)
	PROCEDURE EqlASSSLoop( ladr, radr: ADDRESS; linc, len: SIZE ): BOOLEAN;
	VAR lval, rval: SIGNED8;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );
			IF lval # rval THEN RETURN FALSE END;
			INC( ladr, linc );  DEC( len );
		END;
		RETURN TRUE;
	END EqlASSSLoop;

	OPERATOR "="*( CONST left: ARRAY [ ? ] OF SIGNED8;right: SIGNED8 ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( left, ADDRESSOF( right ), EqlASSSLoop );
	END "=";

	OPERATOR "="*( left: SIGNED8;CONST right: ARRAY [ ? ] OF SIGNED8 ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( right , ADDRESSOF( left ), EqlASSSLoop );
	END "=";

	OPERATOR "#"*( CONST left: ARRAY [ ? ] OF SIGNED8; right: SIGNED8 ): BOOLEAN;
	BEGIN
		RETURN ~( left= right );
	END "#";

	OPERATOR "#"*( left: SIGNED8; CONST right: ARRAY [ ? ] OF SIGNED8 ): BOOLEAN;
	BEGIN
		RETURN ~( left= right );
	END "#";

(** SIGNED16 *)
	PROCEDURE EqlAISILoop( ladr, radr: ADDRESS; linc, len: SIZE ): BOOLEAN;
	VAR lval, rval: SIGNED16;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );
			IF lval # rval THEN RETURN FALSE END;
			INC( ladr, linc );  DEC( len );
		END;
		RETURN TRUE;
	END EqlAISILoop;

	OPERATOR "="*(CONST left: ARRAY [ ? ] OF SIGNED16; right: SIGNED16 ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( left, ADDRESSOF( right ), EqlAISILoop );
	END "=";

	OPERATOR "="*( left: SIGNED16; CONST right: ARRAY [ ? ] OF SIGNED16 ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( right , ADDRESSOF( left ), EqlAISILoop );
	END "=";

	OPERATOR "#"*(CONST left: ARRAY [ ? ] OF SIGNED16; right: SIGNED16 ): BOOLEAN;
	BEGIN
		RETURN ~( left = right );
	END "#";

	OPERATOR "#"*( left: SIGNED16; CONST right: ARRAY [ ? ] OF SIGNED16 ): BOOLEAN;
	BEGIN
		RETURN ~( left = right );
	END "#";

(** SIGNED32 *)
	PROCEDURE EqlALSLLoop( ladr, radr: ADDRESS; linc, len: SIZE ): BOOLEAN;
	VAR lval, rval: SIGNED32;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );
			IF lval # rval THEN RETURN FALSE END;
			INC( ladr, linc );  DEC( len );
		END;
		RETURN TRUE;
	END EqlALSLLoop;

	OPERATOR "="*( CONST left: ARRAY [ ? ] OF SIGNED32;
										right: SIGNED32 ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( left, ADDRESSOF( right ), EqlALSLLoop );
	END "=";

	OPERATOR "="*( left: SIGNED32;
										CONST right: ARRAY [ ? ] OF SIGNED32 ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( right , ADDRESSOF( left ), EqlALSLLoop );
	END "=";

	OPERATOR "#"*( CONST left: ARRAY [ ? ] OF SIGNED32;
											right: SIGNED32 ): BOOLEAN;
	BEGIN
		RETURN ~(left = right);
	END "#";

	OPERATOR "#"*( left: SIGNED32;
											CONST right: ARRAY [ ? ] OF SIGNED32 ): BOOLEAN;
	BEGIN
		RETURN ~(left = right);
	END "#";

(** SIZE *)
	PROCEDURE EqlAZSZLoop( ladr, radr: ADDRESS; linc, len: SIZE ): BOOLEAN;
	VAR lval, rval: SIZE;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );
			IF lval # rval THEN RETURN FALSE END;
			INC( ladr, linc );  DEC( len );
		END;
		RETURN TRUE;
	END EqlAZSZLoop;

	OPERATOR "="*( CONST left: ARRAY [ ? ] OF SIZE;
										right: SIZE ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( left, ADDRESSOF( right ), EqlAZSZLoop );
	END "=";

	OPERATOR "="*( left: SIZE;
										CONST right: ARRAY [ ? ] OF SIZE ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( right , ADDRESSOF( left ), EqlALSLLoop );
	END "=";

	OPERATOR "#"*( CONST left: ARRAY [ ? ] OF SIZE;
											right: SIZE ): BOOLEAN;
	BEGIN
		RETURN ~(left = right);
	END "#";

	OPERATOR "#"*( left: SIZE;
											CONST right: ARRAY [ ? ] OF SIZE ): BOOLEAN;
	BEGIN
		RETURN ~(left = right);
	END "#";

(** FLOAT32 *)
	PROCEDURE EqlARSRLoop( ladr, radr: ADDRESS; linc, len: SIZE ): BOOLEAN;
	VAR lval, rval: FLOAT32;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );
			IF lval # rval THEN RETURN FALSE END;
			INC( ladr, linc );  DEC( len );
		END;
		RETURN TRUE;
	END EqlARSRLoop;

	OPERATOR "="*( CONST left: ARRAY [ ? ] OF FLOAT32;
											right: FLOAT32 ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( left, ADDRESSOF( right ), EqlARSRLoop );
	END "=";

	OPERATOR "="*( left: FLOAT32;
											CONST right: ARRAY [ ? ] OF FLOAT32 ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( right , ADDRESSOF( left ), EqlARSRLoop );
	END "=";

	OPERATOR "#"*( CONST left: ARRAY [ ? ] OF FLOAT32;
											right: FLOAT32 ): BOOLEAN;
	BEGIN
		RETURN ~( left = right );
	END "#";

	OPERATOR "#"*( left: FLOAT32;
											CONST right: ARRAY [ ? ] OF FLOAT32 ): BOOLEAN;
	BEGIN
		RETURN ~( left = right );
	END "#";

(** FLOAT64 *)
	PROCEDURE EqlAXSXLoop( ladr, radr: ADDRESS; linc, len: SIZE ): BOOLEAN;
	VAR lval, rval: FLOAT64;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );
			IF lval # rval THEN RETURN FALSE END;
			INC( ladr, linc );  DEC( len );
		END;
		RETURN TRUE;
	END EqlAXSXLoop;

	OPERATOR "="*( CONST left: ARRAY [ ? ] OF FLOAT64;
										right: FLOAT64 ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( left, ADDRESSOF( right ), EqlAXSXLoop );
	END "=";

	OPERATOR "="*( left: FLOAT64;
										CONST right: ARRAY [ ? ] OF FLOAT64 ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( right , ADDRESSOF( left ), EqlAXSXLoop );
	END "=";

	OPERATOR "#"*( CONST left: ARRAY [ ? ] OF FLOAT64;
											right: FLOAT64 ): BOOLEAN;
	BEGIN
		RETURN ~( left = right );
	END "#";

	OPERATOR "#"*( left: FLOAT64;CONST right: ARRAY [ ? ] OF FLOAT64 ): BOOLEAN;
	BEGIN
		RETURN ~( left= right );
	END "#";

	(*** gtr : array x scalar -> boolean  ********************************************************************)

(** SIGNED8 *)
	PROCEDURE GtrASSSLoop( ladr, radr: ADDRESS; linc, len: SIZE ): BOOLEAN;
	VAR lval, rval: SIGNED8;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );
			IF lval <= rval THEN RETURN FALSE END;
			INC( ladr, linc );  DEC( len );
		END;
		RETURN TRUE;
	END GtrASSSLoop;

	OPERATOR ">"*( CONST left: ARRAY [ ? ] OF SIGNED8; right: SIGNED8 ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( left, ADDRESSOF( right ), GtrASSSLoop );
	END ">";

	OPERATOR "<"*( left: SIGNED8;CONST right: ARRAY [ ? ] OF SIGNED8 ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( right , ADDRESSOF( left ), GtrASSSLoop );
	END "<";

(** SIGNED16 *)
	PROCEDURE GtrAISILoop( ladr, radr: ADDRESS; linc, len: SIZE ): BOOLEAN;
	VAR lval, rval: SIGNED16;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );
			IF lval <= rval THEN RETURN FALSE END;
			INC( ladr, linc );  DEC( len );
		END;
		RETURN TRUE;
	END GtrAISILoop;

	OPERATOR ">"*(CONST left: ARRAY [ ? ] OF SIGNED16; right: SIGNED16 ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( left, ADDRESSOF( right ), GtrAISILoop );
	END ">";

	OPERATOR "<"*( left: SIGNED16; CONST right: ARRAY [ ? ] OF SIGNED16 ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( right , ADDRESSOF( left ), GtrAISILoop );
	END "<";

(** SIGNED32 *)
	PROCEDURE GtrALSLLoop( ladr, radr: ADDRESS; linc, len: SIZE ): BOOLEAN;
	VAR lval, rval: SIGNED32;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );
			IF lval <= rval THEN RETURN FALSE END;
			INC( ladr, linc );  DEC( len );
		END;
		RETURN TRUE;
	END GtrALSLLoop;

	OPERATOR ">"*( CONST left: ARRAY [ ? ] OF SIGNED32; right: SIGNED32 ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( left, ADDRESSOF( right ), GtrALSLLoop );
	END ">";

	OPERATOR "<"*( left: SIGNED32; CONST right: ARRAY [ ? ] OF SIGNED32 ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( right , ADDRESSOF( left ), GtrALSLLoop );
	END "<";

(** SIZE *)
	PROCEDURE GtrAZSZLoop( ladr, radr: ADDRESS; linc, len: SIZE ): BOOLEAN;
	VAR lval, rval: SIZE;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );
			IF lval <= rval THEN RETURN FALSE END;
			INC( ladr, linc );  DEC( len );
		END;
		RETURN TRUE;
	END GtrAZSZLoop;

	OPERATOR ">"*( CONST left: ARRAY [ ? ] OF SIZE; right: SIZE ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( left, ADDRESSOF( right ), GtrAZSZLoop );
	END ">";

	OPERATOR "<"*( left: SIZE; CONST right: ARRAY [ ? ] OF SIZE ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( right , ADDRESSOF( left ), GtrAZSZLoop );
	END "<";

(** FLOAT32 *)
	PROCEDURE GtrARSRLoop( ladr, radr: ADDRESS; linc, len: SIZE ): BOOLEAN;
	VAR lval, rval: FLOAT32;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );
			IF lval <= rval THEN RETURN FALSE END;
			INC( ladr, linc );  DEC( len );
		END;
		RETURN TRUE;
	END GtrARSRLoop;

	OPERATOR ">"*( CONST left: ARRAY [ ? ] OF FLOAT32;
										right: FLOAT32 ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( left, ADDRESSOF( right ), GtrARSRLoop );
	END ">";

	OPERATOR "<"*( left: FLOAT32;
											CONST right: ARRAY [ ? ] OF FLOAT32 ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( right , ADDRESSOF( left ), GtrARSRLoop );
	END "<";

(** FLOAT64 *)
	PROCEDURE GtrAXSXLoop( ladr, radr: ADDRESS; linc, len: SIZE ): BOOLEAN;
	VAR lval, rval: FLOAT64;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );
			IF lval <= rval THEN RETURN FALSE END;
			INC( ladr, linc );  DEC( len );
		END;
		RETURN TRUE;
	END GtrAXSXLoop;

	OPERATOR ">"*( CONST left: ARRAY [ ? ] OF FLOAT64;
										right: FLOAT64 ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( left, ADDRESSOF( right ), GtrAXSXLoop );
	END ">";

	OPERATOR "<"*( left: FLOAT64;
										CONST right: ARRAY [ ? ] OF FLOAT64 ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( right , ADDRESSOF( left ), GtrAXSXLoop );
	END "<";

	(*** geq : array x scalar -> boolean  ********************************************************************)

(** SIGNED8 *)
	PROCEDURE GeqASSSLoop( ladr, radr: ADDRESS; linc, len: SIZE ): BOOLEAN;
	VAR lval, rval: SIGNED8;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );
			IF lval < rval THEN RETURN FALSE END;
			INC( ladr, linc );  DEC( len );
		END;
		RETURN TRUE;
	END GeqASSSLoop;

	OPERATOR ">="*( CONST left: ARRAY [ ? ] OF SIGNED8;
											right: SIGNED8 ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( left, ADDRESSOF( right ), GeqASSSLoop );
	END ">=";

	OPERATOR "<="*( left: SIGNED8;
										CONST right: ARRAY [ ? ] OF SIGNED8 ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( right , ADDRESSOF( left ), GeqASSSLoop );
	END "<=";

(** SIGNED16 *)
	PROCEDURE GeqAISILoop( ladr, radr: ADDRESS; linc, len: SIZE ): BOOLEAN;
	VAR lval, rval: SIGNED16;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );
			IF lval < rval THEN RETURN FALSE END;
			INC( ladr, linc );  DEC( len );
		END;
		RETURN TRUE;
	END GeqAISILoop;

	OPERATOR ">="*(CONST left: ARRAY [ ? ] OF SIGNED16; right: SIGNED16 ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( left, ADDRESSOF( right ), GeqAISILoop );
	END ">=";

	OPERATOR "<="*( left: SIGNED16;
										CONST right: ARRAY [ ? ] OF SIGNED16 ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( right , ADDRESSOF( left ), GeqAISILoop );
	END "<=";

(** SIGNED32 *)
	PROCEDURE GeqALSLLoop( ladr, radr: ADDRESS; linc, len: SIZE ): BOOLEAN;
	VAR lval, rval: SIGNED32;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );
			IF lval < rval THEN RETURN FALSE END;
			INC( ladr, linc );  DEC( len );
		END;
		RETURN TRUE;
	END GeqALSLLoop;

	OPERATOR ">="*( CONST left: ARRAY [ ? ] OF SIGNED32;
										right: SIGNED32 ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( left, ADDRESSOF( right ), GeqALSLLoop );
	END ">=";

	OPERATOR "<="*( left: SIGNED32;
										CONST right: ARRAY [ ? ] OF SIGNED32 ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( right , ADDRESSOF( left ), GeqALSLLoop );
	END "<=";

(** SIZE *)
	PROCEDURE GeqAZSZLoop( ladr, radr: ADDRESS; linc, len: SIZE ): BOOLEAN;
	VAR lval, rval: SIZE;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );
			IF lval < rval THEN RETURN FALSE END;
			INC( ladr, linc );  DEC( len );
		END;
		RETURN TRUE;
	END GeqAZSZLoop;

	OPERATOR ">="*( CONST left: ARRAY [ ? ] OF SIZE;
										right: SIZE ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( left, ADDRESSOF( right ), GeqAZSZLoop );
	END ">=";

	OPERATOR "<="*( left:SIZE;
										CONST right: ARRAY [ ? ] OF SIZE ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( right , ADDRESSOF( left ), GeqAZSZLoop );
	END "<=";

(** FLOAT32 *)
	PROCEDURE GeqARSRLoop( ladr, radr: ADDRESS; linc, len: SIZE ): BOOLEAN;
	VAR lval, rval: FLOAT32;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );
			IF lval < rval THEN RETURN FALSE END;
			INC( ladr, linc );  DEC( len );
		END;
		RETURN TRUE;
	END GeqARSRLoop;

	OPERATOR ">="*( CONST left: ARRAY [ ? ] OF FLOAT32;
											right: FLOAT32 ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( left, ADDRESSOF( right ), GeqARSRLoop );
	END ">=";

	OPERATOR "<="*( left: FLOAT32; CONST right: ARRAY [ ? ] OF FLOAT32 ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( right , ADDRESSOF( left ), GeqARSRLoop );
	END "<=";

(** FLOAT64 *)
	PROCEDURE GeqAXSXLoop( ladr, radr: ADDRESS; linc, len: SIZE ): BOOLEAN;
	VAR lval, rval: FLOAT64;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );
			IF lval < rval THEN RETURN FALSE END;
			INC( ladr, linc );  DEC( len );
		END;
		RETURN TRUE;
	END GeqAXSXLoop;

	OPERATOR ">="*( CONST left: ARRAY [ ? ] OF FLOAT64; right: FLOAT64 ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( left, ADDRESSOF( right ), GeqAXSXLoop );
	END ">=";

	OPERATOR "<="*( left: FLOAT64; CONST right: ARRAY [ ? ] OF FLOAT64 ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( right , ADDRESSOF( left ), GeqAXSXLoop );
	END "<=";

	(*** leq : array x scalar -> boolean  ********************************************************************)

(** SIGNED8 *)
	PROCEDURE LeqASSSLoop( ladr, radr: ADDRESS; linc, len: SIZE ): BOOLEAN;
	VAR lval, rval: SIGNED8;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );
			IF lval > rval THEN RETURN FALSE END;
			INC( ladr, linc );  DEC( len );
		END;
		RETURN TRUE;
	END LeqASSSLoop;

	OPERATOR "<="*( CONST left: ARRAY [ ? ] OF SIGNED8;right: SIGNED8 ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( left, ADDRESSOF( right ), LeqASSSLoop );
	END "<=";

	OPERATOR ">="*( left: SIGNED8; CONST right: ARRAY [ ? ] OF SIGNED8 ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( right , ADDRESSOF( left ), LeqASSSLoop );
	END ">=";

(** SIGNED16 *)
	PROCEDURE LeqAISILoop( ladr, radr: ADDRESS; linc, len: SIZE ): BOOLEAN;
	VAR lval, rval: SIGNED16;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );
			IF lval > rval THEN RETURN FALSE END;
			INC( ladr, linc );  DEC( len );
		END;
		RETURN TRUE;
	END LeqAISILoop;

	OPERATOR "<="*(CONST left: ARRAY [ ? ] OF SIGNED16; right: SIGNED16 ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( left, ADDRESSOF( right ), LeqAISILoop );
	END "<=";

	OPERATOR ">="*( left: SIGNED16; CONST right: ARRAY [ ? ] OF SIGNED16 ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( right , ADDRESSOF( left ), LeqAISILoop );
	END ">=";

(** SIGNED32 *)
	PROCEDURE LeqALSLLoop( ladr, radr: ADDRESS; linc, len: SIZE ): BOOLEAN;
	VAR lval, rval: SIGNED32;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );
			IF lval > rval THEN RETURN FALSE END;
			INC( ladr, linc );  DEC( len );
		END;
		RETURN TRUE;
	END LeqALSLLoop;

	OPERATOR "<="*( CONST left: ARRAY [ ? ] OF SIGNED32; right: SIGNED32 ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( left, ADDRESSOF( right ), LeqALSLLoop );
	END "<=";

	OPERATOR ">="*( left: SIGNED32; CONST right: ARRAY [ ? ] OF SIGNED32 ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( right , ADDRESSOF( left ), LeqALSLLoop );
	END ">=";

(** SIZE *)
	PROCEDURE LeqAZSZLoop( ladr, radr: ADDRESS; linc, len: SIZE ): BOOLEAN;
	VAR lval, rval: SIZE;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );
			IF lval > rval THEN RETURN FALSE END;
			INC( ladr, linc );  DEC( len );
		END;
		RETURN TRUE;
	END LeqAZSZLoop;

	OPERATOR "<="*( CONST left: ARRAY [ ? ] OF SIZE; right: SIZE ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( left, ADDRESSOF( right ), LeqAZSZLoop );
	END "<=";

	OPERATOR ">="*( left: SIZE; CONST right: ARRAY [ ? ] OF SIZE ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( right , ADDRESSOF( left ), LeqAZSZLoop );
	END ">=";

(** FLOAT32 *)
	PROCEDURE LeqARSRLoop( ladr, radr: ADDRESS; linc, len: SIZE ): BOOLEAN;
	VAR lval, rval: FLOAT32;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );
			IF lval > rval THEN RETURN FALSE END;
			INC( ladr, linc );  DEC( len );
		END;
		RETURN TRUE;
	END LeqARSRLoop;

	OPERATOR "<="*( CONST left: ARRAY [ ? ] OF FLOAT32; right: FLOAT32 ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( left, ADDRESSOF( right ), LeqARSRLoop );
	END "<=";

	OPERATOR ">="*( left: FLOAT32; CONST right: ARRAY [ ? ] OF FLOAT32 ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( right , ADDRESSOF( left ), LeqARSRLoop );
	END ">=";

(** FLOAT64 *)
	PROCEDURE LeqAXSXLoop( ladr, radr: ADDRESS; linc, len: SIZE ): BOOLEAN;
	VAR lval, rval: FLOAT64;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );
			IF lval > rval THEN RETURN FALSE END;
			INC( ladr, linc );  DEC( len );
		END;
		RETURN TRUE;
	END LeqAXSXLoop;

	OPERATOR "<="*( CONST left: ARRAY [ ? ] OF FLOAT64; right: FLOAT64 ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( left, ADDRESSOF( right ), LeqAXSXLoop );
	END "<=";

	OPERATOR ">="*( left: FLOAT64; CONST right: ARRAY [ ? ] OF FLOAT64 ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( right , ADDRESSOF( left ), LeqAXSXLoop );
	END ">=";

	(*** lss: array x scalar -> boolean  ********************************************************************)

(** SIGNED8 *)
	PROCEDURE LssASSSLoop( ladr, radr: ADDRESS; linc, len: SIZE ): BOOLEAN;
	VAR lval, rval: SIGNED8;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );
			IF lval >= rval THEN RETURN FALSE END;
			INC( ladr, linc );  DEC( len );
		END;
		RETURN TRUE;
	END LssASSSLoop;

	OPERATOR "<"*( CONST left: ARRAY [ ? ] OF SIGNED8; right: SIGNED8 ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( left, ADDRESSOF( right ), LssASSSLoop );
	END "<";

	OPERATOR ">"*( left: SIGNED8; CONST right: ARRAY [ ? ] OF SIGNED8 ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( right , ADDRESSOF( left ), LssASSSLoop );
	END ">";

(** SIGNED16 *)
	PROCEDURE LssAISILoop( ladr, radr: ADDRESS; linc, len: SIZE ): BOOLEAN;
	VAR lval, rval: SIGNED16;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );
			IF lval >= rval THEN RETURN FALSE END;
			INC( ladr, linc );  DEC( len );
		END;
		RETURN TRUE;
	END LssAISILoop;

	OPERATOR "<"*(CONST left: ARRAY [ ? ] OF SIGNED16; right: SIGNED16 ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( left, ADDRESSOF( right ), LssAISILoop );
	END "<";

	OPERATOR ">"*( left: SIGNED16; CONST right: ARRAY [ ? ] OF SIGNED16 ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( right , ADDRESSOF( left ), LssAISILoop );
	END ">";

(** SIGNED32 *)
	PROCEDURE LssALSLLoop( ladr, radr: ADDRESS; linc, len: SIZE ): BOOLEAN;
	VAR lval, rval: SIGNED32;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );
			IF lval >= rval THEN RETURN FALSE END;
			INC( ladr, linc );  DEC( len );
		END;
		RETURN TRUE;
	END LssALSLLoop;

	OPERATOR "<"*( CONST left: ARRAY [ ? ] OF SIGNED32; right: SIGNED32 ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( left, ADDRESSOF( right ), LssALSLLoop );
	END "<";

	OPERATOR ">"*( left: SIGNED32;CONST right: ARRAY [ ? ] OF SIGNED32 ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( right , ADDRESSOF( left ), LssALSLLoop );
	END ">";

(** SIZE *)
	PROCEDURE LssAZSZLoop( ladr, radr: ADDRESS; linc, len: SIZE ): BOOLEAN;
	VAR lval, rval: SIZE;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );
			IF lval >= rval THEN RETURN FALSE END;
			INC( ladr, linc );  DEC( len );
		END;
		RETURN TRUE;
	END LssAZSZLoop;

	OPERATOR "<"*( CONST left: ARRAY [ ? ] OF SIZE; right: SIZE ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( left, ADDRESSOF( right ), LssAZSZLoop );
	END "<";

	OPERATOR ">"*( left: SIZE;CONST right: ARRAY [ ? ] OF SIZE ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( right , ADDRESSOF( left ), LssAZSZLoop );
	END ">";

(** FLOAT32 *)
	PROCEDURE LssARSRLoop( ladr, radr: ADDRESS; linc, len: SIZE ): BOOLEAN;
	VAR lval, rval: FLOAT32;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );
			IF lval >= rval THEN RETURN FALSE END;
			INC( ladr, linc );  DEC( len );
		END;
		RETURN TRUE;
	END LssARSRLoop;

	OPERATOR "<"*( CONST left: ARRAY [ ? ] OF FLOAT32;
											right: FLOAT32 ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( left, ADDRESSOF( right ), LssARSRLoop );
	END "<";

	OPERATOR ">"*( left: FLOAT32;
										CONST right: ARRAY [ ? ] OF FLOAT32 ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( right , ADDRESSOF( left ), LssARSRLoop );
	END ">";

(** FLOAT64 *)
	PROCEDURE LssAXSXLoop( ladr, radr: ADDRESS; linc, len: SIZE ): BOOLEAN;
	VAR lval, rval: FLOAT64;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );
			IF lval >= rval THEN RETURN FALSE END;
			INC( ladr, linc );  DEC( len );
		END;
		RETURN TRUE;
	END LssAXSXLoop;

	OPERATOR "<"*( CONST left: ARRAY [ ? ] OF FLOAT64;
										right: FLOAT64 ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( left, ADDRESSOF( right ), LssAXSXLoop );
	END "<";

	OPERATOR ">"*( left: FLOAT64;
										CONST right: ARRAY [ ? ] OF FLOAT64 ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( right , ADDRESSOF( left ), LssAXSXLoop );
	END ">";

	(**** binary max/min operators array x scalar-> array ********************************************************************)

	PROCEDURE MaxAXSXLoop( ladr, radr, dadr: ADDRESS; linc, dinc, len: SIZE );
	VAR lval, val: FLOAT64;
	BEGIN
		SYSTEM.GET( radr, val );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );
			INC( ladr, linc ); DEC( len );
			IF lval>val THEN SYSTEM.PUT( dadr, lval) ELSE SYSTEM.PUT(dadr, val) END;
			INC(dadr,dinc);
		END;
	END MaxAXSXLoop;

	OPERATOR "MAX"*(CONST left: ARRAY [?] OF FLOAT64; right: FLOAT64): ARRAY {UNSAFE} [?] OF FLOAT64;
	TYPE Type = FLOAT64;
	BEGIN
		ApplyBinaryASAOp( RESULT , left, ADDRESSOF( right ), SIZEOF( Type ), MaxAXSXLoop );
		RETURN RESULT
	END "MAX";

	PROCEDURE MaxARSRLoop( ladr, radr, dadr: ADDRESS; linc, dinc, len: SIZE );
	VAR lval, val: FLOAT32;
	BEGIN
		SYSTEM.GET( radr, val );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );
			INC( ladr, linc ); DEC( len );
			IF lval>val THEN SYSTEM.PUT( dadr, lval) ELSE SYSTEM.PUT(dadr, val) END;
			INC(dadr,dinc);
		END;
	END MaxARSRLoop;

	OPERATOR "MAX"*(CONST left: ARRAY [?] OF FLOAT32; right: FLOAT32): ARRAY {UNSAFE} [?] OF FLOAT32;
	TYPE Type = FLOAT32;
	BEGIN
		ApplyBinaryASAOp( RESULT , left, ADDRESSOF( right ), SIZEOF( Type ), MaxARSRLoop );
		RETURN RESULT
	END "MAX";

	PROCEDURE MaxALSLLoop( ladr, radr, dadr: ADDRESS; linc, dinc, len: SIZE );
	VAR lval, val: SIGNED32;
	BEGIN
		SYSTEM.GET( radr, val );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );
			INC( ladr, linc ); DEC( len );
			IF lval>val THEN SYSTEM.PUT( dadr, lval) ELSE SYSTEM.PUT(dadr, val) END;
			INC(dadr,dinc);
		END;
	END MaxALSLLoop;

	OPERATOR "MAX"*(CONST left: ARRAY [?] OF SIGNED32; right: SIGNED32): ARRAY {UNSAFE} [?] OF SIGNED32;
	TYPE Type = SIGNED32;
	BEGIN
		ApplyBinaryASAOp( RESULT , left, ADDRESSOF( right ), SIZEOF( Type ), MaxALSLLoop );
		RETURN RESULT
	END "MAX";

	PROCEDURE MaxAISILoop( ladr, radr, dadr: ADDRESS; linc, dinc, len: SIZE );
	VAR lval, val: SIGNED16;
	BEGIN
		SYSTEM.GET( radr, val );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );
			INC( ladr, linc ); DEC( len );
			IF lval>val THEN SYSTEM.PUT( dadr, lval) ELSE SYSTEM.PUT(dadr, val) END;
			INC(dadr,dinc);
		END;
	END MaxAISILoop;

	OPERATOR "MAX"*(CONST left: ARRAY [?] OF SIGNED16; right: SIGNED16): ARRAY {UNSAFE} [?] OF SIGNED16;
	TYPE Type = SIGNED16;
	BEGIN
		ApplyBinaryASAOp( RESULT , left, ADDRESSOF( right ), SIZEOF( Type ), MaxAISILoop );
		RETURN RESULT
	END "MAX";

	PROCEDURE MaxASSSLoop( ladr, radr, dadr: ADDRESS; linc, dinc, len: SIZE );
	VAR lval, val: SIGNED8;
	BEGIN
		SYSTEM.GET( radr, val );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );
			INC( ladr, linc ); DEC( len );
			IF lval>val THEN SYSTEM.PUT( dadr, lval) ELSE SYSTEM.PUT(dadr, val) END;
			INC(dadr,dinc);
		END;
	END MaxASSSLoop;

	OPERATOR "MAX"*(CONST left: ARRAY [?] OF SIGNED8; right: SIGNED8): ARRAY {UNSAFE} [?] OF SIGNED8;
	TYPE Type = SIGNED8;
	BEGIN
		ApplyBinaryASAOp( RESULT , left, ADDRESSOF( right ), SIZEOF( Type ), MaxASSSLoop );
		RETURN RESULT
	END "MAX";

	PROCEDURE MinAXSXLoop( ladr, radr, dadr: ADDRESS; linc, dinc, len: SIZE );
	VAR lval, val: FLOAT64;
	BEGIN
		SYSTEM.GET( radr, val );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );
			INC( ladr, linc ); DEC( len );
			IF lval<val THEN SYSTEM.PUT( dadr, lval) ELSE SYSTEM.PUT(dadr, val) END;
			INC(dadr,dinc);
		END;
	END MinAXSXLoop;

	OPERATOR "MIN"*(CONST left: ARRAY [?] OF FLOAT64; right: FLOAT64): ARRAY {UNSAFE} [?] OF FLOAT64;
	TYPE Type = FLOAT64;
	BEGIN
		ApplyBinaryASAOp( RESULT , left, ADDRESSOF( right ), SIZEOF( Type ), MinAXSXLoop );
		RETURN RESULT
	END "MIN";

	PROCEDURE MinARSRLoop( ladr, radr, dadr: ADDRESS; linc, dinc, len: SIZE );
	VAR lval, val: FLOAT32;
	BEGIN
		SYSTEM.GET( radr, val );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );
			INC( ladr, linc ); DEC( len );
			IF lval<val THEN SYSTEM.PUT( dadr, lval) ELSE SYSTEM.PUT(dadr, val) END;
			INC(dadr,dinc);
		END;
	END MinARSRLoop;

	OPERATOR "MIN"*(CONST left: ARRAY [?] OF FLOAT32; right: FLOAT32): ARRAY {UNSAFE} [?] OF FLOAT32;
	TYPE Type = FLOAT32;
	BEGIN
		ApplyBinaryASAOp( RESULT , left, ADDRESSOF( right ), SIZEOF( Type ), MinARSRLoop );
		RETURN RESULT
	END "MIN";

	PROCEDURE MinALSLLoop( ladr, radr, dadr: ADDRESS; linc, dinc, len: SIZE );
	VAR lval, val: SIGNED32;
	BEGIN
		SYSTEM.GET( radr, val );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );
			INC( ladr, linc ); DEC( len );
			IF lval<val THEN SYSTEM.PUT( dadr, lval) ELSE SYSTEM.PUT(dadr, val) END;
			INC(dadr,dinc);
		END;
	END MinALSLLoop;

	OPERATOR "MIN"*(CONST left: ARRAY [?] OF SIGNED32; right: SIGNED32): ARRAY {UNSAFE} [?] OF SIGNED32;
	TYPE Type = SIGNED32;
	BEGIN
		ApplyBinaryASAOp( RESULT , left, ADDRESSOF( right ), SIZEOF( Type ), MinALSLLoop );
		RETURN RESULT
	END "MIN";

	PROCEDURE MinAISILoop( ladr, radr, dadr: ADDRESS; linc, dinc, len: SIZE );
	VAR lval, val: SIGNED16;
	BEGIN
		SYSTEM.GET( radr, val );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );
			INC( ladr, linc ); DEC( len );
			IF lval<val THEN SYSTEM.PUT( dadr, lval) ELSE SYSTEM.PUT(dadr, val) END;
			INC(dadr,dinc);
		END;
	END MinAISILoop;

	OPERATOR "MIN"*(CONST left: ARRAY [?] OF SIGNED16; right: SIGNED16): ARRAY {UNSAFE} [?] OF SIGNED16;
	TYPE Type = SIGNED16;
	BEGIN
		ApplyBinaryASAOp( RESULT , left, ADDRESSOF( right ), SIZEOF( Type ), MinAISILoop );
		RETURN RESULT
	END "MIN";

	PROCEDURE MinASSSLoop( ladr, radr, dadr: ADDRESS; linc, dinc, len: SIZE );
	VAR lval, val: SIGNED8;
	BEGIN
		SYSTEM.GET( radr, val );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );
			INC( ladr, linc ); DEC( len );
			IF lval<val THEN SYSTEM.PUT( dadr, lval) ELSE SYSTEM.PUT(dadr, val) END;
			INC(dadr,dinc);
		END;
	END MinASSSLoop;

	OPERATOR "MIN"*(CONST left: ARRAY [?] OF SIGNED8; right: SIGNED8): ARRAY {UNSAFE} [?] OF SIGNED8;
	TYPE Type = SIGNED8;
	BEGIN
		ApplyBinaryASAOp( RESULT , left, ADDRESSOF( right ), SIZEOF( Type ), MinASSSLoop );
		RETURN RESULT
	END "MIN";

	(**** binary max/min operators array x array -> array ********************************************************************)

	PROCEDURE MaxAXAXLoop( ladr, radr, dadr: ADDRESS; linc, rinc, dinc, len: SIZE );
	VAR lval, rval: FLOAT64;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval ); SYSTEM.GET( radr, rval );
			INC( ladr, linc ); INC(radr,rinc ); DEC( len );
			IF lval>rval THEN SYSTEM.PUT( dadr, lval) ELSE SYSTEM.PUT (dadr,rval) END;
			INC(dadr,dinc);
		END;
	END MaxAXAXLoop;

	OPERATOR "MAX"*(CONST left, right: ARRAY [?] OF FLOAT64): ARRAY {UNSAFE} [?] OF FLOAT64;
	BEGIN
		ApplyBinaryAAAOp( RESULT, left, right, SIZEOF( FLOAT64 ), MaxAXAXLoop );
		RETURN RESULT
	END "MAX";

	PROCEDURE MaxARARLoop( ladr, radr, dadr: ADDRESS; linc, rinc, dinc, len: SIZE );
	VAR lval, rval: FLOAT32 ;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval ); SYSTEM.GET( radr, rval );
			INC( ladr, linc ); INC(radr,rinc ); DEC( len );
			IF lval>rval THEN SYSTEM.PUT( dadr, lval) ELSE SYSTEM.PUT (dadr,rval) END;
			INC(dadr,dinc);
		END;
	END MaxARARLoop;

	OPERATOR "MAX"*(CONST left, right: ARRAY [?] OF FLOAT32): ARRAY {UNSAFE} [?] OF FLOAT32;
	BEGIN
		ApplyBinaryAAAOp( RESULT, left, right, SIZEOF( FLOAT32 ), MaxARARLoop );
		RETURN RESULT
	END "MAX";

	PROCEDURE MaxALALLoop( ladr, radr, dadr: ADDRESS; linc, rinc, dinc, len: SIZE );
	VAR lval, rval: SIGNED32;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval ); SYSTEM.GET( radr, rval );
			INC( ladr, linc ); INC(radr,rinc ); DEC( len );
			IF lval>rval THEN SYSTEM.PUT( dadr, lval) ELSE SYSTEM.PUT (dadr,rval) END;
			INC(dadr,dinc);
		END;
	END MaxALALLoop;

	OPERATOR "MAX"*(CONST left, right: ARRAY [?] OF SIGNED32): ARRAY {UNSAFE} [?] OF SIGNED32 ;
	BEGIN
		ApplyBinaryAAAOp( RESULT, left, right, SIZEOF( SIGNED32 ), MaxALALLoop );
		RETURN RESULT
	END "MAX";

		PROCEDURE MaxAIAILoop( ladr, radr, dadr: ADDRESS; linc, rinc, dinc, len: SIZE );
	VAR lval, rval: SIGNED16;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval ); SYSTEM.GET( radr, rval );
			INC( ladr, linc ); INC(radr,rinc ); DEC( len );
			IF lval>rval THEN SYSTEM.PUT( dadr, lval) ELSE SYSTEM.PUT (dadr,rval) END;
			INC(dadr,dinc);
		END;
	END MaxAIAILoop;

	OPERATOR "MAX"*(CONST left, right: ARRAY [?] OF SIGNED16): ARRAY {UNSAFE} [?] OF SIGNED16;
	BEGIN
		ApplyBinaryAAAOp( RESULT, left, right, SIZEOF( SIGNED16 ), MaxAIAILoop );
		RETURN RESULT
	END "MAX";

	PROCEDURE MaxASASLoop( ladr, radr, dadr: ADDRESS; linc, rinc, dinc, len: SIZE );
	VAR lval, rval: SIGNED8;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval ); SYSTEM.GET( radr, rval );
			INC( ladr, linc ); INC(radr,rinc ); DEC( len );
			IF lval>rval THEN SYSTEM.PUT( dadr, lval) ELSE SYSTEM.PUT (dadr,rval) END;
			INC(dadr,dinc);
		END;
	END MaxASASLoop;

	OPERATOR "MAX"*(CONST left, right: ARRAY [?] OF SIGNED8): ARRAY {UNSAFE} [?] OF SIGNED8;
	BEGIN
		ApplyBinaryAAAOp( RESULT, left, right, SIZEOF( SIGNED8 ), MaxASASLoop );
		RETURN RESULT
	END "MAX";

	PROCEDURE MinAXAXLoop( ladr, radr, dadr: ADDRESS; linc, rinc, dinc, len: SIZE );
	VAR lval, rval: FLOAT64;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval ); SYSTEM.GET( radr, rval );
			INC( ladr, linc ); INC(radr,rinc ); DEC( len );
			IF lval<rval THEN SYSTEM.PUT( dadr, lval) ELSE SYSTEM.PUT (dadr,rval) END;
			INC(dadr,dinc);
		END;
	END MinAXAXLoop;

	OPERATOR "MIN"*(CONST left, right: ARRAY [?] OF FLOAT64): ARRAY {UNSAFE} [?] OF FLOAT64;
	BEGIN
		ApplyBinaryAAAOp( RESULT, left, right, SIZEOF( FLOAT64 ), MinAXAXLoop );
		RETURN RESULT
	END "MIN";

	PROCEDURE MinARARLoop( ladr, radr, dadr: ADDRESS; linc, rinc, dinc, len: SIZE );
	VAR lval, rval: FLOAT32 ;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval ); SYSTEM.GET( radr, rval );
			INC( ladr, linc ); INC(radr,rinc ); DEC( len );
			IF lval<rval THEN SYSTEM.PUT( dadr, lval) ELSE SYSTEM.PUT (dadr,rval) END;
			INC(dadr,dinc);
		END;
	END MinARARLoop;

	OPERATOR "MIN"*(CONST left, right: ARRAY [?] OF FLOAT32): ARRAY {UNSAFE} [?] OF FLOAT32;
	BEGIN
		ApplyBinaryAAAOp( RESULT, left, right, SIZEOF( FLOAT32 ), MinARARLoop );
		RETURN RESULT
	END "MIN";

	(*PROCEDURE MinALALLoop( ladr, radr, dadr: ADDRESS; linc, rinc, dinc, len: SIZE );
	VAR lval, rval: SIGNED32;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval ); SYSTEM.GET( radr, rval );
			INC( ladr, linc ); INC(radr,rinc ); DEC( len );
			IF lval<rval THEN SYSTEM.PUT( dadr, lval) ELSE SYSTEM.PUT (dadr,rval) END;
			INC(dadr,dinc);
		END;
	END MinALALLoop;
	*)

TYPE
	LongintPtr = POINTER {UNSAFE,UNTRACED} TO RECORD val: SIGNED32 END;

	PROCEDURE MinALALLoop( ladr, radr, dadr: LongintPtr; linc, rinc, dinc, len: SIZE);
	BEGIN
		WHILE (len > 0) DO
			IF ladr.val < ladr.val THEN dadr.val := ladr.val ELSE dadr.val := radr.val END;
			ladr := ladr + linc;
			radr := radr + rinc;
			dadr := dadr + dinc;
			DEC(len);
		END;
	END MinALALLoop;

	OPERATOR "MIN"*(CONST left, right: ARRAY [?] OF SIGNED32): ARRAY {UNSAFE} [?] OF SIGNED32 ;
	BEGIN
		ApplyBinaryAAAOp( RESULT, left, right, SIZEOF( SIGNED32 ), MinALALLoop );
		RETURN RESULT
	END "MIN";

	TYPE SizePtr = POINTER {UNSAFE,UNTRACED} TO RECORD val: SIZE END;

	PROCEDURE MinAYAYLoop( ladr, radr, dadr: SizePtr; linc, rinc, dinc, len: SIZE);
	BEGIN
		WHILE (len > 0) DO
			IF ladr.val < ladr.val THEN dadr.val := ladr.val ELSE dadr.val := radr.val END;
			ladr := ladr + linc;
			radr := radr + rinc;
			dadr := dadr + dinc;
			DEC(len);
		END;
	END MinAYAYLoop;

	OPERATOR "MIN"*(CONST left, right: ARRAY [?] OF SIZE): ARRAY {UNSAFE} [?] OF SIZE ;
	BEGIN
		ApplyBinaryAAAOp( RESULT, left, right, SIZEOF( SIZE ), MinAYAYLoop );
		RETURN RESULT
	END "MIN";

	PROCEDURE MinAIAILoop( ladr, radr, dadr: ADDRESS; linc, rinc, dinc, len: SIZE );
	VAR lval, rval: SIGNED16;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval ); SYSTEM.GET( radr, rval );
			INC( ladr, linc ); INC(radr,rinc ); DEC( len );
			IF lval<rval THEN SYSTEM.PUT( dadr, lval) ELSE SYSTEM.PUT (dadr,rval) END;
			INC(dadr,dinc);
		END;
	END MinAIAILoop;

	OPERATOR "MIN"*(CONST left, right: ARRAY  [?] OF SIGNED16): ARRAY {UNSAFE} [?] OF SIGNED16;
	BEGIN
		ApplyBinaryAAAOp( RESULT, left, right, SIZEOF( SIGNED16 ), MinAIAILoop );
		RETURN RESULT
	END "MIN";

	PROCEDURE MinASASLoop( ladr, radr, dadr: ADDRESS; linc, rinc, dinc, len: SIZE );
	VAR lval, rval: SIGNED8;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval ); SYSTEM.GET( radr, rval );
			INC( ladr, linc ); INC(radr,rinc ); DEC( len );
			IF lval<rval THEN SYSTEM.PUT( dadr, lval) ELSE SYSTEM.PUT (dadr,rval) END;
			INC(dadr,dinc);
		END;
	END MinASASLoop;

	OPERATOR "MIN"*(CONST left, right: ARRAY [?] OF SIGNED8): ARRAY {UNSAFE} [?] OF SIGNED8;
	BEGIN
		ApplyBinaryAAAOp( RESULT, left, right, SIZEOF( SIGNED8 ), MinASASLoop );
		RETURN RESULT
	END "MIN";

	(**** unary operators array -> scalar ********************************************************************)

	(*** min: array -> scalar ****************************************)

(** SIGNED8 *)
	PROCEDURE MinASLoop( ladr, dadr: ADDRESS; linc, len: SIZE );
	VAR lval, dval: SIGNED8;
	BEGIN
		SYSTEM.GET( dadr, dval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );
			IF lval < dval THEN dval := lval END;
			INC( ladr, linc );  DEC( len );
		END;
		SYSTEM.PUT( dadr, dval );
	END MinASLoop;

	OPERATOR "MIN"*( CONST left: ARRAY [ ? ] OF SIGNED8 ): SIGNED8;
	TYPE Type = SIGNED8;
	VAR val: Type;
	BEGIN
		val := MAX( Type );
		ApplyUnaryASOp( ADDRESSOF( val ), left , MinASLoop );  RETURN val;
	END "MIN";

(** SIGNED16 *)
	PROCEDURE MinAILoop( ladr, dadr: ADDRESS; linc, len: SIZE );
	VAR lval, dval: SIGNED16;
	BEGIN
		SYSTEM.GET( dadr, dval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );
			IF lval < dval THEN dval := lval END;
			INC( ladr, linc );  DEC( len );
		END;
		SYSTEM.PUT( dadr, dval );
	END MinAILoop;

	OPERATOR "MIN"*( CONST left: ARRAY [ ? ] OF SIGNED16 ): SIGNED16;
	TYPE Type = SIGNED16;
	VAR val: Type;
	BEGIN
		val := MAX( Type );
		ApplyUnaryASOp( ADDRESSOF( val ), left , MinAILoop );  RETURN val;
	END "MIN";

(** SIGNED32 *)
	PROCEDURE MinALLoop( ladr, dadr: ADDRESS; linc, len: SIZE );
	VAR lval, dval: SIGNED32;
	BEGIN
		SYSTEM.GET( dadr, dval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );
			IF lval < dval THEN dval := lval END;
			INC( ladr, linc );  DEC( len );
		END;
		SYSTEM.PUT( dadr, dval );
	END MinALLoop;

	OPERATOR "MIN"*( CONST left: ARRAY [ ? ] OF SIGNED32 ): SIGNED32;
	TYPE Type = SIGNED32;
	VAR val: Type;
	BEGIN
		val := MAX( Type );
		ApplyUnaryASOp( ADDRESSOF( val ),  left , MinALLoop );  RETURN val;
	END "MIN";

(** SIZE *)
	PROCEDURE MinAZLoop( ladr, dadr: ADDRESS; linc, len: SIZE );
	VAR lval, dval: SIZE;
	BEGIN
		SYSTEM.GET( dadr, dval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );
			IF lval < dval THEN dval := lval END;
			INC( ladr, linc );  DEC( len );
		END;
		SYSTEM.PUT( dadr, dval );
	END MinAZLoop;

	OPERATOR "MIN"*( CONST left: ARRAY [ ? ] OF SIZE ): SIZE;
	TYPE Type = SIZE;
	VAR val: Type;
	BEGIN
		val := MAX( Type );
		ApplyUnaryASOp( ADDRESSOF( val ), left , MinAZLoop );  RETURN val;
	END "MIN";

(** FLOAT32 *)
	PROCEDURE MinARLoop( ladr, dadr: ADDRESS; linc, len: SIZE );
	VAR lval, dval: FLOAT32;
	BEGIN
		SYSTEM.GET( dadr, dval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );
			IF lval < dval THEN dval := lval END;
			INC( ladr, linc );  DEC( len );
		END;
		SYSTEM.PUT( dadr, dval );
	END MinARLoop;

	OPERATOR "MIN"*( CONST left: ARRAY [ ? ] OF FLOAT32 ): FLOAT32;
	TYPE Type = FLOAT32;
	VAR val: Type;
	BEGIN
		val := MAX( Type );
		ApplyUnaryASOp( ADDRESSOF( val ), left, MinARLoop );  RETURN val;
	END "MIN";

(** FLOAT64 *)
	PROCEDURE MinAXLoop( ladr, dadr: ADDRESS; linc, len: SIZE );
	VAR lval, dval: FLOAT64;
	BEGIN
		SYSTEM.GET( dadr, dval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );
			IF lval < dval THEN dval := lval END;
			INC( ladr, linc );  DEC( len );
		END;
		SYSTEM.PUT( dadr, dval );
	END MinAXLoop;

	OPERATOR "MIN"*( CONST left: ARRAY [ ? ] OF FLOAT64 ): FLOAT64;
	TYPE Type = FLOAT64;
	VAR val: Type;
	BEGIN
		val := MAX( Type );
		ApplyUnaryASOp( ADDRESSOF( val ), left , MinAXLoop );  RETURN val;
	END "MIN";

	(*** max: array -> scalar  ********************************************************************)

(** SIGNED8 *)
	PROCEDURE MaxASLoop( ladr, dadr: ADDRESS; linc, len: SIZE );
	VAR lval, dval: SIGNED8;
	BEGIN
		SYSTEM.GET( dadr, dval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );
			IF lval > dval THEN dval := lval END;
			INC( ladr, linc );  DEC( len );
		END;
		SYSTEM.PUT( dadr, dval );
	END MaxASLoop;

	OPERATOR "MAX"*( CONST left: ARRAY [ ? ] OF SIGNED8 ): SIGNED8;
	TYPE Type = SIGNED8;
	VAR val: Type;
	BEGIN
		val := MIN( Type );
		ApplyUnaryASOp( ADDRESSOF( val ), left , MaxASLoop );  RETURN val;
	END "MAX";

(** SIGNED16 *)
	PROCEDURE MaxAILoop( ladr, dadr: ADDRESS; linc, len: SIZE );
	VAR lval, dval: SIGNED16;
	BEGIN
		SYSTEM.GET( dadr, dval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );
			IF lval > dval THEN dval := lval END;
			INC( ladr, linc );  DEC( len );
		END;
		SYSTEM.PUT( dadr, dval );
	END MaxAILoop;

	OPERATOR "MAX"*( CONST left: ARRAY [ ? ] OF SIGNED16 ): SIGNED16;
	TYPE Type = SIGNED16;
	VAR val: Type;
	BEGIN
		val := MIN( Type );
		ApplyUnaryASOp( ADDRESSOF( val ), left , MaxAILoop );  RETURN val;
	END "MAX";

(** SIGNED32 *)
	PROCEDURE MaxALLoop( ladr, dadr: ADDRESS; linc, len: SIZE );
	VAR lval, dval: SIGNED32;
	BEGIN
		SYSTEM.GET( dadr, dval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );
			IF lval > dval THEN dval := lval END;
			INC( ladr, linc );  DEC( len );
		END;
		SYSTEM.PUT( dadr, dval );
	END MaxALLoop;

	OPERATOR "MAX"*( CONST left: ARRAY [ ? ] OF SIGNED32 ): SIGNED32;
	TYPE Type = SIGNED32;
	VAR val: Type;
	BEGIN
		val := MIN( Type );
		ApplyUnaryASOp( ADDRESSOF( val ), left , MaxALLoop );  RETURN val;
	END "MAX";

(** FLOAT32 *)
	PROCEDURE MaxARLoop( ladr, dadr: ADDRESS; linc, len: SIZE );
	VAR lval, dval: FLOAT32;
	BEGIN
		SYSTEM.GET( dadr, dval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );
			IF lval > dval THEN dval := lval END;
			INC( ladr, linc );  DEC( len );
		END;
		SYSTEM.PUT( dadr, dval );
	END MaxARLoop;

	OPERATOR "MAX"*( CONST left: ARRAY [ ? ] OF FLOAT32 ): FLOAT32;
	TYPE Type = FLOAT32;
	VAR val: Type;
	BEGIN
		val := MIN( Type );
		ApplyUnaryASOp( ADDRESSOF( val ), left , MaxARLoop );  RETURN val;
	END "MAX";

(** FLOAT64 *)
	PROCEDURE MaxAXLoop( ladr, dadr: ADDRESS; linc, len: SIZE );
	VAR lval, dval: FLOAT64;
	BEGIN
		SYSTEM.GET( dadr, dval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );
			IF lval > dval THEN dval := lval END;
			INC( ladr, linc );  DEC( len );
		END;
		SYSTEM.PUT( dadr, dval );
	END MaxAXLoop;

	OPERATOR "MAX"*( CONST left: ARRAY [ ? ] OF FLOAT64 ): FLOAT64;
	TYPE Type = FLOAT64;
	VAR val: Type;
	BEGIN
		val := MIN( Type );
		ApplyUnaryASOp( ADDRESSOF( val ), left , MaxAXLoop );  RETURN val;
	END "MAX";

	(*** LEN: array -> array **)

	OPERATOR "LEN"*(CONST left: ARRAY [?]): ARRAY [*] OF SIZE;
	VAR dim,i: SIZE;
	BEGIN
		dim := GetDim( left );
		IF (DIM(RESULT)#1) OR (LEN(RESULT,0) # dim) THEN NEW(RESULT,dim) END;
		FOR i := 0 TO dim-1 DO RESULT[i] := LenType(GetLen(left,i)) END;
		RETURN RESULT
	END "LEN";

	(*** SUM: array -> scalar  ********************************************************************)

(** SIGNED8 *)
	PROCEDURE SumASLoop( ladr, dadr: ADDRESS; linc, len: SIZE );
	VAR lval, dval: SIGNED8;
	BEGIN
		SYSTEM.GET( dadr, dval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  dval := dval + lval;  INC( ladr, linc );  DEC( len );
		END;
		SYSTEM.PUT( dadr, dval );
	END SumASLoop;

	OPERATOR "SUM"*( CONST left: ARRAY [ ? ] OF SIGNED8 ): SIGNED8;
	TYPE Type = SIGNED8;
	VAR val: Type;
	BEGIN
		val := 0;  ApplyUnaryASOp( ADDRESSOF( val ), left , SumASLoop );
		RETURN val;
	END "SUM";

(** SIGNED16 *)
	PROCEDURE SumAILoop( ladr, dadr: ADDRESS; linc, len: SIZE );
	VAR lval, dval: SIGNED16;
	BEGIN
		SYSTEM.GET( dadr, dval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  dval := dval + lval;  INC( ladr, linc );  DEC( len );
		END;
		SYSTEM.PUT( dadr, dval );
	END SumAILoop;

	OPERATOR "SUM"*( CONST left: ARRAY [ ? ] OF SIGNED16 ): SIGNED16;
	TYPE Type = SIGNED16;
	VAR val: Type;
	BEGIN
		val := 0;  ApplyUnaryASOp( ADDRESSOF( val ), left, SumAILoop );
		RETURN val;
	END "SUM";

(** SIGNED32 *)
	PROCEDURE SumALLoop( ladr, dadr: ADDRESS; linc, len: SIZE );
	VAR lval, dval: SIGNED32;
	BEGIN
		SYSTEM.GET( dadr, dval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  dval := dval + lval;  INC( ladr, linc );  DEC( len );
		END;
		SYSTEM.PUT( dadr, dval );
	END SumALLoop;

	OPERATOR "SUM"*( CONST left: ARRAY [ ? ] OF SIGNED32 ): SIGNED32;
	TYPE Type = SIGNED32;
	VAR val: Type;
	BEGIN
		val := 0;  ApplyUnaryASOp( ADDRESSOF( val ), left , SumALLoop );
		RETURN val;
	END "SUM";

(** SIZE *)
	PROCEDURE SumAYLoop( ladr, dadr: ADDRESS; linc, len: SIZE );
	VAR lval, dval: SIZE;
	BEGIN
		SYSTEM.GET( dadr, dval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  dval := dval + lval;  INC( ladr, linc );  DEC( len );
		END;
		SYSTEM.PUT( dadr, dval );
	END SumAYLoop;

	OPERATOR "SUM"*( CONST left: ARRAY [ ? ] OF SIZE ): SIZE;
	TYPE Type = SIZE;
	VAR val: Type;
	BEGIN
		val := 0;  ApplyUnaryASOp( ADDRESSOF( val ), left, SumAYLoop );
		RETURN val;
	END "SUM";
(** FLOAT32 *)
	PROCEDURE SumARLoop( ladr, dadr: ADDRESS; linc, len: SIZE );
	VAR lval, dval: FLOAT32;
	BEGIN
		SYSTEM.GET( dadr, dval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  dval := dval + lval;  INC( ladr, linc );  DEC( len );
		END;
		SYSTEM.PUT( dadr, dval );
	END SumARLoop;

	OPERATOR "SUM"*( CONST left: ARRAY [ ? ] OF FLOAT32 ): FLOAT32;
	TYPE Type = FLOAT32;
	VAR val: Type;
	BEGIN
		val := 0;  ApplyUnaryASOp( ADDRESSOF( val ), left, SumARLoop );
		RETURN val;
	END "SUM";

(** FLOAT64 *)
	PROCEDURE SumAXLoop( ladr, dadr: ADDRESS; linc, len: SIZE );
	VAR lval, dval: FLOAT64;
	BEGIN
		SYSTEM.GET( dadr, dval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  dval := dval + lval;  INC( ladr, linc );  DEC( len );
		END;
		SYSTEM.PUT( dadr, dval );
	END SumAXLoop;

	OPERATOR "SUM"*( CONST left: ARRAY [ ? ] OF FLOAT64 ): FLOAT64;
	TYPE Type = FLOAT64;
	VAR val: Type;
	BEGIN
		val := 0;  ApplyUnaryASOp( ADDRESSOF( val ), left, SumAXLoop );
		RETURN val;
	END "SUM";

(** COMPLEX32 *)
	PROCEDURE SumAZLoop( ladr, dadr: ADDRESS; linc, len: SIZE );
	VAR lval, dval: COMPLEX32;
	BEGIN
		SYSTEM.GET( dadr, dval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  dval := dval + lval;  INC( ladr, linc );  DEC( len );
		END;
		SYSTEM.PUT( dadr, dval );
	END SumAZLoop;

	OPERATOR "SUM"*( CONST left: ARRAY [ ? ] OF COMPLEX32 ): COMPLEX32;
	TYPE Type = COMPLEX32;
	VAR val: Type;
	BEGIN
		val := 0;  ApplyUnaryASOp( ADDRESSOF( val ), left, SumAZLoop );
		RETURN val;
	END "SUM";

(** COMPLEX64 *)
	PROCEDURE SumALZLoop( ladr, dadr: ADDRESS; linc, len: SIZE );
	VAR lvalRe, lvalIm, dvalRe, dvalIm: FLOAT64;
	BEGIN
		SYSTEM.GET( dadr, dvalRe ); SYSTEM.GET( dadr+SIZEOF(FLOAT64), dvalIm );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lvalRe ); SYSTEM.GET( ladr+SIZEOF(FLOAT64), lvalIm );
			dvalRe := dvalRe + lvalRe; dvalIm := dvalIm + lvalIm;
			INC( ladr, linc );  DEC( len );
		END;
		SYSTEM.PUT( dadr, dvalRe ); SYSTEM.PUT( dadr+SIZEOF(FLOAT64), dvalIm );
	END SumALZLoop;

	OPERATOR "SUM"*( CONST left: ARRAY [ ? ] OF COMPLEX64 ): COMPLEX64;
	TYPE Type = COMPLEX64;
	VAR val: Type;
	BEGIN
		val := 0;  ApplyUnaryASOp( ADDRESSOF( val ), left, SumALZLoop );
		RETURN val;
	END "SUM";

	(*** monadic ABS array -> array  ********************************************************************)

(** SIGNED8 *)
	PROCEDURE AbsLoopS( ladr, dadr: ADDRESS; linc, dinc, len: SIZE );
	VAR lval: SIGNED8;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.PUT( dadr, ABS( lval ) );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END AbsLoopS;

	OPERATOR "ABS"*(CONST src: ARRAY [ ? ] OF SIGNED8): ARRAY {UNSAFE} [ ? ] OF SIGNED8;
	BEGIN
		ApplyUnaryAAOp(RESULT, src,SIZEOF( SIGNED8 ), AbsLoopS );
		RETURN RESULT
	END "ABS";

(** SIGNED16 *)
	PROCEDURE AbsLoopI( ladr, dadr: ADDRESS; linc, dinc, len: SIZE );
	VAR lval: SIGNED16;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.PUT( dadr, ABS( lval ) );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END AbsLoopI;

	OPERATOR "ABS"*(CONST src: ARRAY [ ? ] OF SIGNED16): ARRAY {UNSAFE} [ ? ] OF SIGNED16;
	BEGIN
		ApplyUnaryAAOp(RESULT, src,SIZEOF( SIGNED16 ), AbsLoopI );
		RETURN RESULT
	END "ABS";

(** SIGNED32 *)
	PROCEDURE AbsLoopL( ladr, dadr: ADDRESS; linc, dinc, len: SIZE );
	VAR lval: SIGNED32;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.PUT( dadr, ABS( lval ) );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END AbsLoopL;

	OPERATOR "ABS"*(CONST src: ARRAY [ ? ] OF SIGNED32): ARRAY {UNSAFE} [ ? ] OF SIGNED32;
	BEGIN
		ApplyUnaryAAOp(RESULT, src,SIZEOF( SIGNED32 ), AbsLoopL );
		RETURN RESULT
	END "ABS";

(** FLOAT32 *)
	PROCEDURE AbsLoopR( ladr, dadr: ADDRESS; linc, dinc, len: SIZE );
	VAR lval: FLOAT32;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.PUT( dadr, ABS( lval ) );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END AbsLoopR;

	OPERATOR "ABS"*(CONST src: ARRAY [ ? ] OF FLOAT32): ARRAY {UNSAFE} [ ? ] OF FLOAT32;
	BEGIN
		ApplyUnaryAAOp(RESULT, src,SIZEOF( FLOAT32 ), AbsLoopR );
		RETURN RESULT
	END "ABS";

(** FLOAT64 *)
	PROCEDURE AbsLoopX( ladr, dadr: ADDRESS; linc, dinc, len: SIZE );
	VAR lval: FLOAT64;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.PUT( dadr, ABS( lval ) );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END AbsLoopX;

	OPERATOR "ABS"*(CONST src: ARRAY [ ? ] OF FLOAT64): ARRAY {UNSAFE} [ ? ] OF FLOAT64;
	BEGIN
		ApplyUnaryAAOp(RESULT, src,SIZEOF( FLOAT64 ), AbsLoopX );
		RETURN RESULT
	END "ABS";

(** COMPLEX32 *)
	PROCEDURE AbsLoopZ( ladr, dadr: ADDRESS; linc, dinc, len: SIZE );
	VAR lval: COMPLEX32;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.PUT( dadr, ABS(lval) );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END AbsLoopZ;

	OPERATOR "ABS"*(CONST src: ARRAY [ ? ] OF COMPLEX32): ARRAY {UNSAFE} [ ? ] OF FLOAT32;
	BEGIN
		ApplyUnaryAAOp(RESULT, src,SIZEOF( FLOAT32 ), AbsLoopZ );
		RETURN RESULT
	END "ABS";

(** COMPLEX64 *)
	PROCEDURE AbsLoopLZ( ladr, dadr: ADDRESS; linc, dinc, len: SIZE );
	VAR lvalRe, lvalIm: FLOAT64;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lvalRe ); SYSTEM.GET( ladr+SIZEOF(FLOAT64), lvalIm );
			SYSTEM.PUT( dadr, MathL.sqrt(lvalRe*lvalRe + lvalIm*lvalIm) );
			INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END AbsLoopLZ;

	OPERATOR "ABS"*(CONST src: ARRAY [ ? ] OF COMPLEX64): ARRAY {UNSAFE} [ ? ] OF FLOAT64;
	BEGIN
		ApplyUnaryAAOp(RESULT, src,SIZEOF( FLOAT64 ), AbsLoopLZ );
		RETURN RESULT
	END "ABS";

	(*** assign number to array  (initialisation) ********************************************************************)

(** BOOLEAN *)
	PROCEDURE AssignSBABLoop( ladr, dadr: ADDRESS; dinc, len: SIZE );
	VAR lval: BOOLEAN;
	BEGIN
		SYSTEM.GET( ladr, lval );
		WHILE (len > 0) DO SYSTEM.PUT( dadr, lval );  INC( dadr, dinc );  DEC( len );  END;
	END AssignSBABLoop;

	OPERATOR ":="*(VAR dest: ARRAY {UNSAFE} [?] OF BOOLEAN; right: BOOLEAN);
	BEGIN
		ApplyUnarySAOp( dest, ADDRESSOF( right ), AssignSBABLoop );
	END ":=";

(** SIGNED8*)
	PROCEDURE AssignSSASLoop( ladr, dadr: ADDRESS; dinc, len: SIZE );
	VAR lval: SIGNED8;
	BEGIN
		SYSTEM.GET( ladr, lval );
		WHILE (len > 0) DO SYSTEM.PUT( dadr, lval );  INC( dadr, dinc );  DEC( len );  END;
	END AssignSSASLoop;

	OPERATOR ":="*(VAR dest: ARRAY {UNSAFE} [?] OF SIGNED8; right: SIGNED8);
	BEGIN
		ApplyUnarySAOp( dest, ADDRESSOF( right ), AssignSSASLoop );
	END ":=";

(**SIGNED16 *)
	PROCEDURE AssignSIAILoop( ladr, dadr: ADDRESS; dinc, len: SIZE );
	VAR lval: SIGNED16;
	BEGIN
		SYSTEM.GET( ladr, lval );
		WHILE (len > 0) DO SYSTEM.PUT( dadr, lval );  INC( dadr, dinc );  DEC( len );  END;
	END AssignSIAILoop;

	OPERATOR ":="*(VAR dest: ARRAY {UNSAFE} [?] OF SIGNED16; right: SIGNED16);
	BEGIN
		ApplyUnarySAOp( dest, ADDRESSOF( right ), AssignSIAILoop );
	END ":=";

(** SIGNED32 *)
	PROCEDURE AssignSLALLoop( ladr, dadr: ADDRESS; dinc, len: SIZE );
	VAR lval: SIGNED32;
	BEGIN
		SYSTEM.GET( ladr, lval );
		WHILE (len > 0) DO SYSTEM.PUT( dadr, lval );  INC( dadr, dinc );  DEC( len );  END;
	END AssignSLALLoop;

	OPERATOR ":="*(VAR dest: ARRAY {UNSAFE} [?] OF SIGNED32; right: SIGNED32);
	BEGIN
		ApplyUnarySAOp(dest, ADDRESSOF( right ), AssignSLALLoop );
	END ":=";

(** SIZE *)
	PROCEDURE AssignSYAYLoop( ladr, dadr: ADDRESS; dinc, len: SIZE );
	VAR lval: SIZE;
	BEGIN
		SYSTEM.GET( ladr, lval );
		WHILE (len > 0) DO SYSTEM.PUT( dadr, lval );  INC( dadr, dinc );  DEC( len );  END;
	END AssignSYAYLoop;

	OPERATOR ":="*(VAR dest: ARRAY {UNSAFE} [?] OF SIZE; right: SIZE);
	BEGIN
		ApplyUnarySAOp(dest, ADDRESSOF( right ), AssignSYAYLoop );
	END ":=";

(** SIGNED64 *)
	PROCEDURE AssignSHAHLoop( ladr, dadr: ADDRESS; dinc, len: SIZE );
	VAR dval: POINTER{UNSAFE,UNTRACED} TO RECORD val: SIGNED64 END;	lval: SIGNED64;
	BEGIN
		dval := dadr;
		SYSTEM.GET( ladr, lval );
		WHILE (len > 0) DO
			dval.val := lval;
			dval := dval + dinc;
			DEC( len );
		END;
	END AssignSHAHLoop;

	OPERATOR ":="*(VAR dest: ARRAY {UNSAFE} [?] OF SIGNED64; right: SIGNED64);
	BEGIN
		ApplyUnarySAOp(dest, ADDRESSOF( right ), AssignSHAHLoop );
	END ":=";

(** FLOAT32 *)
	PROCEDURE AssignSRARLoop( ladr, dadr: ADDRESS; dinc, len: SIZE );
	VAR lval: FLOAT32;
	BEGIN
		SYSTEM.GET( ladr, lval );
		WHILE (len > 0) DO SYSTEM.PUT( dadr, lval );  INC( dadr, dinc );  DEC( len );  END;
	END AssignSRARLoop;

	OPERATOR ":="*(VAR dest: ARRAY {UNSAFE} [?] OF FLOAT32; right: FLOAT32);
	BEGIN
		ApplyUnarySAOp( dest, ADDRESSOF( right ), AssignSRARLoop );
	END ":=";

(** FLOAT64 *)
	PROCEDURE AssignSXAXLoop( ladr, dadr: ADDRESS; dinc, len: SIZE );
	VAR lval: FLOAT64;
	BEGIN
		SYSTEM.GET( ladr, lval );
		WHILE (len > 0) DO SYSTEM.PUT( dadr, lval );  INC( dadr, dinc );  DEC( len );  END;
	END AssignSXAXLoop;

	OPERATOR ":="*(VAR dest: ARRAY {UNSAFE} [?] OF FLOAT64; right: FLOAT64);
	BEGIN
		ApplyUnarySAOp( dest, ADDRESSOF( right ), AssignSXAXLoop );
	END ":=";

(** COMPLEX32 *)
	PROCEDURE AssignSZAZLoop( ladr, dadr: ADDRESS; dinc, len: SIZE );
	VAR lval: COMPLEX32;
	BEGIN
		SYSTEM.GET( ladr, lval );
		WHILE (len > 0) DO SYSTEM.PUT( dadr, lval );  INC( dadr, dinc );  DEC( len );  END;
	END AssignSZAZLoop;

	OPERATOR ":="*(VAR dest: ARRAY {UNSAFE} [?] OF COMPLEX32; right: COMPLEX32);
	BEGIN
		ApplyUnarySAOp( dest, ADDRESSOF( right ), AssignSZAZLoop );
	END ":=";

(** COMPLEX64 *)
	PROCEDURE AssignSLZALZLoop( ladr, dadr: ADDRESS; dinc, len: SIZE );
	VAR lvalRe, lvalIm: FLOAT64;
	BEGIN
		SYSTEM.GET( ladr, lvalRe ); SYSTEM.GET( ladr+SIZEOF(FLOAT64), lvalIm );
		WHILE (len > 0) DO SYSTEM.PUT( dadr, lvalRe ); SYSTEM.PUT( dadr+SIZEOF(FLOAT64), lvalIm ); INC( dadr, dinc );  DEC( len );  END;
	END AssignSLZALZLoop;

	OPERATOR ":="*(VAR dest: ARRAY {UNSAFE} [?] OF COMPLEX64; right: COMPLEX64);
	BEGIN
		ApplyUnarySAOp( dest, ADDRESSOF( right ), AssignSLZALZLoop );
	END ":=";

(*** matrix multipliation ********************************************************************)

	PROCEDURE AllocateMatrix( dest: ADDRESS;
													rows, cols, elementsize: SIZE ): ANY;
	VAR p: ANY;
	BEGIN
		(*
		KernelLog.String( "ALLOCATE MATRIX WAS CALLED" );  KernelLog.Ln;
		*)
		SYSTEM.NEW( p, rows * cols * elementsize  + ArrayAlignment);  PutLen( dest, 1, cols );
		PutLen( dest, 0, rows );  PutInc( dest, 1, elementsize );
		PutInc( dest, 0, elementsize * cols );  PutAdr( dest, Align(p) );
		PutPtr( dest, p);  RETURN p;
	END AllocateMatrix;

	PROCEDURE AllocateVector(CONST dest: UnsafeArrayT;  l0, elementsize: SIZE );
	VAR p: ANY;
	BEGIN
		SYSTEM.NEW( p, l0 * elementsize  + ArrayAlignment);  PutLen( dest, 0, l0 );
		PutInc( dest, 0, elementsize );  PutAdr( dest, Align(p) );
		PutPtr( dest, p );
	END AllocateVector;

	PROCEDURE ApplyMatMulLoop*( dest, left, right: ADDRESS;  Size: SIZE;
														loop: BinaryAASLoop;
	fast: FastMatMul );   (* Size= element-size *)
	VAR ladr, radr, dadr: ADDRESS; dadri, radri, rowsL, colsL, rowsR, colsR, incL, incR, incD, strideR, strideL, strideD, colsRi: SIZE;
		p: ANY;  overlap: BOOLEAN;  destOld: UnsafeArray;  destNew: UnsafeArrayT;
	BEGIN
	(*
				<- 1 ->
			xxx  xxxx  ->  xxxx
	^	  xxx  xxxx        xxxx
	0	  xxx  xxxx        xxxx
	v	   xxx                  xxxx
			xxx                  xxxx

			Len(..,1): #columns ; Inc(..,1): inc in rows
			Len(..,0): #rows ; Inc(..,0): inc between rows

	*)

		(* apply multiplication D = L * R *)

		rowsL := GetLen( left, 0 );   (* # left rows  = # dest rows*)
		colsL := GetLen( left, 1 );   (* # left columns  *)
		rowsR := GetLen( right, 0 );   (* # right rows  =!= left columns *)
		colsR := GetLen( right, 1 );   (* # right columns = # dest columns*)

		(* check geometric restriction *)
		IF colsL # rowsR THEN Halt( GeometryMismatch, left, right, 0 );  END;

		IF GetAdr( dest ) = 0 THEN p := AllocateMatrix( dest, rowsL, colsR, Size );
		ELSIF (GetLen( dest, 0 ) # rowsL) OR (GetLen( dest, 1 ) # colsR) THEN
			IF RangeFlag IN GetFlags( dest ) THEN
				Halt( GeometryMismatch, left, right, dest )
			ELSE p := AllocateMatrix( dest, rowsL, colsR, Size );
			END;
		END;

		overlap := Overlap( left, dest ) OR Overlap( right, dest );
		IF overlap THEN
			destOld := dest;  destNew := NIL;
			IF AllocateSameT( destNew, destOld, Size ) THEN END;
			CopyContent( destNew, destOld, Size );   (* for INCMUL ! *)
			dest := destNew;
		END;

		IF (GetLen( dest, 0 ) # rowsL) OR (GetLen( dest, 1 ) # colsR) THEN
			HALT( 9999 )
		END;

		ladr := GetAdr( left );  radr := GetAdr( right );  dadr := GetAdr( dest );

		incL := GetIncr( left, 1 );  strideL := GetIncr( left, 0 );   (* increment and stride of left matrix *)
		incR := GetIncr( right, 1 );  strideR := GetIncr( right, 0 );   (* increment and stride of right matrix *)
		incD := GetIncr( dest, 1 );  strideD := GetIncr( dest, 0 );   (* increment and stride of dest matrix *)

		(*
		KernelLog.String("incD="); KernelLog.Int(incD,10); KernelLog.Ln;
		KernelLog.String("strideD="); KernelLog.Int(strideD,10); KernelLog.Ln;
		KernelLog.String("Len(dest,0) [rows]="); KernelLog.Int(GetLen(dest,0),10); KernelLog.Ln;
		KernelLog.String("Len(dest,1) [cols]="); KernelLog.Int(GetLen(dest,1),10); KernelLog.Ln;
		*)

		IF rowsL = 0 THEN RETURN
		ELSIF colsL=0 THEN RETURN
		ELSIF colsR=0 THEN RETURN
		ELSIF (fast = NIL ) OR
			~(fast( ladr, radr, dadr, incL, strideL, incR, strideR, incD, strideD, rowsL, colsL, rowsR, colsR )) THEN
			WHILE (rowsL > 0) DO  (* outer loop: traverse rows of left matrix *)
				radri := radr;  dadri := dadr;  colsRi := colsR;
				WHILE (colsRi > 0) DO  (* inner loop: traverse columns of right matrix *)
					loop( ladr, radri, dadri, incL, strideR, colsL );  INC( radri, incR );
					INC( dadri, incD );  DEC( colsRi );
				END;
				INC( ladr, strideL );  INC( dadr, strideD );  DEC( rowsL );
			END;
		END;

		IF overlap THEN CopyContent( destOld, dest, Size );
		END;
	END ApplyMatMulLoop;

	PROCEDURE ApplyMatVecMulLoop( dest, left, right: ADDRESS;
															Size: SIZE;  loop: BinaryAASLoop;
															fast: FastMatMul );   (* Size= element-size *)
	VAR ladr, radr, dadr: ADDRESS; li1, li0, ri0, di0, l1, l2: SIZE;
		overlap: BOOLEAN;  destOld, destNew: UnsafeArrayT;

	BEGIN
	(*
				<- 0 ->
			xxx  T(xxx)  ->  T(xxxxx)
			xxx
	1	  xxx
			xxx
			xxx

			Len(..,0): #columns ; Inc(..,0): inc in rows
			Len(..,1): #rows ; Inc(..,1): inc between rows

	*)
		(* check geometric restriction *)
		IF GetLen( left, 1 ) # GetLen( right, 0 ) THEN
			Halt( GeometryMismatch, left, right,0 );
		END;

		l1 := GetLen( left, 0 );   (* number of destination's rows *)
		l2 := GetLen( left, 1 );   (* inner loop len *)
		IF GetAdr( dest ) = 0 THEN AllocateVector( dest, l1, Size );
		ELSIF (GetLen( dest, 0 ) # l1) THEN
			IF RangeFlag IN GetFlags( dest ) THEN
				Halt( GeometryMismatch, left, right, dest );
			ELSE AllocateVector( dest, l1, Size );
			END;
		END;

		overlap := Overlap( left, dest ) OR Overlap( right, dest );
		IF overlap THEN
			destOld := dest;  destNew := NIL;
			IF AllocateSameT( destNew, destOld, Size ) THEN END;
			CopyContent( destNew, destOld, Size );   (* for INCMUL ! *)
			dest := destNew;
		END;

		(*
		IF GetAdr( dest ) = -1 THEN p := AllocateVector( dest, l1, Size );  ELSE
			IF (GetLen( dest, 0 ) # l1) THEN HALT( 102 ) END;
		END;
*)
		ladr := GetAdr( left );  radr := GetAdr( right );  dadr := GetAdr( dest );
		li0 := GetIncr( left, 1 );  li1 := GetIncr( left, 0 );  ri0 := GetIncr( right, 0 );
		di0 := GetIncr( dest, 0 );

		IF l1=0 THEN RETURN
		ELSIF l2=0 THEN RETURN
		ELSIF (fast = NIL ) OR
			~(fast( ladr, radr, dadr, li0, li1, ri0, ri0, di0, di0, l1, l2, l2, 1 )) THEN
			WHILE (l1 > 0) DO  (* inner loop: traverse columns of right matrix *)
				loop( ladr, radr, dadr, li0, ri0, l2 );  INC( ladr, li1 );  INC( dadr, di0 );
				DEC( l1 );
			END;
		END;

		IF overlap THEN CopyContent( destOld, dest, Size );
		END;

	END ApplyMatVecMulLoop;

	PROCEDURE ApplyVecMatMulLoop( dest, left, right: ADDRESS;
															Size: SIZE;  loop: BinaryAASLoop;
															fast: FastMatMul );   (* Size= element-size *)
	VAR ladr, radr, dadr: ADDRESS;  li0, ri1, ri0, di0, l0, l2: SIZE;  p: ANY;
		overlap: BOOLEAN;  destOld, destNew: UnsafeArrayT;

	BEGIN
	(*
				<- 0 ->
			xxx  xxxx  ->  xxxx
			       xxxx
	1	         xxxx

			Len(..,0): #columns ; Inc(..,0): inc in rows
			Len(..,1): #rows ; Inc(..,1): inc between rows

	*)
		(* check geometric restriction *)
		IF GetLen( left, 0 ) # GetLen( right, 0 ) THEN HALT( GeometryMismatch );  END;

		l0 := GetLen( right, 1 );   (* number of destination's column *)
		l2 := GetLen( right, 0 );   (* inner loop len *)
		IF GetAdr( dest ) = 0 THEN AllocateVector( dest, l0, Size );
		ELSIF (GetLen( dest, 0 ) # l0) THEN
			IF RangeFlag IN GetFlags( dest ) THEN HALT( GeometryMismatch )
			ELSE AllocateVector( dest, l0, Size );
			END;
		END;

		overlap := Overlap( left, dest ) OR Overlap( right, dest );
		IF overlap THEN
			destOld := dest;  destNew := NIL;
			IF AllocateSameT( destNew, destOld, Size ) THEN END;
			CopyContent( destNew, destOld, Size );   (* for INCMUL ! *)
			dest := destNew;
		END;

		(*
			IF GetAdr( dest ) = -1 THEN p := AllocateVector( dest, l0, Size );  ELSE
			IF (GetLen( dest, 0 ) # l0) THEN HALT( 102 ) END;
		END;
		*)

		ladr := GetAdr( left );  radr := GetAdr( right );  dadr := GetAdr( dest );
		li0 := GetIncr( left, 0 );  ri0 := GetIncr( right, 1 );  ri1 := GetIncr( right, 0 );
		di0 := GetIncr( dest, 0 );

		IF l2=0 THEN RETURN
		ELSIF l0=0 THEN RETURN
		ELSIF (fast = NIL ) OR ~fast( ladr, radr, dadr, li0, li0, ri0, ri1, di0, di0, 1, l2, l2, l0 ) THEN
			WHILE (l0 > 0) DO  (* inner loop: traverse columns of right matrix *)
				loop( ladr, radr, dadr, li0, ri1, l2 );  INC( radr, ri0 );  INC( dadr, di0 );
				DEC( l0 );
			END;
		END;

		IF overlap THEN CopyContent( destOld, dest, Size );
		END;
	END ApplyVecMatMulLoop;

(** SIGNED8 *)
	PROCEDURE MatMulASASLoop( ladr, radr, dadr: ADDRESS; linc, rinc, len: SIZE );
	VAR lval, rval, dval: SIGNED8;
	BEGIN
		dval := 0;
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  dval := dval + lval * rval;
			(* KernelLog.String("mul with: "); KernelLog.Int(lval,10); KernelLog.Int(rval,10); KernelLog.Ln; *)
			INC( ladr, linc );  INC( radr, rinc );  DEC( len );
		END;
		SYSTEM.PUT( dadr, dval );
	END MatMulASASLoop;

	OPERATOR "*"*(CONST left, right: ARRAY [ * , * ] OF SIGNED8 ): ARRAY [ * , * ] OF SIGNED8;
	BEGIN
		ApplyMatMulLoop( ADDRESS OF RESULT, ADDRESS OF left, ADDRESS OF right,
									SIZEOF( SIGNED8 ), MatMulASASLoop, NIL );
		RETURN RESULT
	END "*";

	OPERATOR "*"*(CONST left: ARRAY [ * , * ] OF SIGNED8; CONST right: ARRAY [ * ] OF SIGNED8): ARRAY [ * ] OF SIGNED8;
	BEGIN
		ApplyMatVecMulLoop( ADDRESS OF RESULT, ADDRESS OF left, ADDRESS OF right,
											SIZEOF( SIGNED8 ), MatMulASASLoop, NIL );
		RETURN RESULT
	END "*";

	OPERATOR "*"*( CONST left: ARRAY [ * ] OF SIGNED8; CONST right: ARRAY [ * , * ] OF SIGNED8  ): ARRAY [ * ] OF SIGNED8;
	BEGIN
		ApplyVecMatMulLoop( ADDRESS OF RESULT, ADDRESS OF left, ADDRESS OF right,
											SIZEOF( SIGNED8 ), MatMulASASLoop, NIL );
		RETURN RESULT
	END "*";

(** SIGNED16 *)
	PROCEDURE MatMulAIAILoop( ladr, radr, dadr: ADDRESS; linc, rinc, len: SIZE );
	VAR lval, rval, dval: SIGNED16;
	BEGIN
		dval := 0;
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  dval := dval + lval * rval;
			INC( ladr, linc );  INC( radr, rinc );  DEC( len );
		END;
		SYSTEM.PUT( dadr, dval );
	END MatMulAIAILoop;

	OPERATOR "*"*(  CONST left, right: ARRAY [ * , * ] OF SIGNED16 ): ARRAY [ * , * ] OF SIGNED16;
	BEGIN
		ApplyMatMulLoop( ADDRESS OF RESULT, ADDRESS OF left, ADDRESS OF right,
									SIZEOF( SIGNED16 ), MatMulAIAILoop, NIL );
		RETURN RESULT
	END "*";

	OPERATOR "*"*(CONST left: ARRAY [ * , * ] OF SIGNED16;
													CONST right: ARRAY [ * ] OF SIGNED16  ): ARRAY [ * ] OF SIGNED16;
	BEGIN
		ApplyMatVecMulLoop( ADDRESS OF RESULT, ADDRESS OF left, ADDRESS OF right,
											SIZEOF( SIGNED16 ), MatMulAIAILoop, NIL );
		RETURN RESULT
	END "*";

	OPERATOR "*"*(CONST left: ARRAY [ * ] OF SIGNED16;
													CONST right: ARRAY [ * , * ] OF SIGNED16 ): ARRAY [ * ] OF SIGNED16;
	BEGIN
		ApplyVecMatMulLoop( ADDRESS OF RESULT, ADDRESS OF left, ADDRESS OF right,
											SIZEOF( SIGNED16 ), MatMulAIAILoop, NIL );
		RETURN RESULT
	END "*";

(** SIGNED32 *)
	PROCEDURE MatMulALALLoop( ladr, radr, dadr: ADDRESS; linc, rinc, len: SIZE );
	VAR lval, rval, dval: SIGNED32;
	BEGIN
		dval := 0;
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  dval := dval + lval * rval;
			INC( ladr, linc );  INC( radr, rinc );  DEC( len );
		END;
		SYSTEM.PUT( dadr, dval );
	END MatMulALALLoop;

	OPERATOR "*"*(CONST left, right: ARRAY [ * , * ] OF SIGNED32 ): ARRAY [ * , * ] OF SIGNED32;
	BEGIN
		(*
		KernelLog.String("MatMulALAL");
		KernelLog.Int(SYSTEM.VAL(SIGNED32,dest),10);
		KernelLog.Int(SYSTEM.VAL(SIGNED32,left),10);
		KernelLog.Int(SYSTEM.VAL(SIGNED32,right),10);
		KernelLog.Ln;
		*)

		ApplyMatMulLoop( ADDRESS OF RESULT, ADDRESS OF left, ADDRESS OF right,
									SIZEOF( SIGNED32 ), MatMulALALLoop, NIL );
		RETURN RESULT
	END "*";

	OPERATOR "*"*(CONST left: ARRAY [ * , * ] OF SIGNED32; CONST right: ARRAY [ * ] OF SIGNED32  ): ARRAY [ * ] OF SIGNED32;
	BEGIN
		ApplyMatVecMulLoop( ADDRESS OF RESULT, ADDRESS OF left, ADDRESS OF right,
											SIZEOF( SIGNED32 ), MatMulALALLoop, NIL );
		RETURN RESULT
	END "*";

	OPERATOR "*"*(CONST left: ARRAY [ * ] OF SIGNED32;
														CONST right: ARRAY [ * , * ] OF SIGNED32): ARRAY [ * ] OF SIGNED32;
	BEGIN
		ApplyVecMatMulLoop( ADDRESS OF RESULT, ADDRESS OF left, ADDRESS OF right,
											SIZEOF( SIGNED32 ), MatMulALALLoop, NIL );
		RETURN RESULT
	END "*";

(** FLOAT32 *)
	PROCEDURE MatMulARARLoop( ladr, radr, dadr: ADDRESS; linc, rinc, len: SIZE );
	VAR lval, rval, dval: FLOAT32;
	BEGIN
		dval := 0;
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  dval := dval + lval * rval;
			INC( ladr, linc );  INC( radr, rinc );  DEC( len );
		END;
		SYSTEM.PUT( dadr, dval );
	END MatMulARARLoop;

	(*
		Optimized for small matrices (Alexey Morozov)

		use of CONST for left, right makes execution slower, it seems that a new descriptor is created in this case
	*)
	OPERATOR "*"*(CONST left, right: ARRAY [ * , * ] OF FLOAT32 ): ARRAY [ * , * ] OF FLOAT32;
	VAR flags: SET; dadr, ladr, radr: ADDRESS;
	BEGIN

		dadr := GetAdr(ADDRESSOF(RESULT));
		ladr := GetAdr(ADDRESSOF(left));
		radr := GetAdr(ADDRESSOF(right));

		(* account possible inplace left := left*right, right := left*right, left := left*left, right := right*right *)
		IF (ladr # dadr) & (radr # dadr) THEN

			flags := SmallArrayMask * GetFlags(ADDRESSOF(left)) * GetFlags(ADDRESSOF(right));

			CASE flags OF

				Mat2x2:
					IF GetFlags(ADDRESSOF(RESULT)) * SmallArrayMask # Mat2x2 THEN
						IF dadr = 0 THEN NEW(RESULT,2,2); dadr := GetAdr(ADDRESSOF(RESULT));
						ELSE Halt(GeometryMismatch,ADDRESSOF(left),ADDRESSOF(right),0);
						END;
					END;

					IF matMulR2x2 # NIL THEN matMulR2x2(dadr,ladr,radr);
					ELSE
						RESULT[0,0] := left[0,0]*right[0,0] + left[0,1]*right[1,0];
						RESULT[0,1] := left[0,0]*right[0,1] + left[0,1]*right[1,1];
						RESULT[1,0] := left[1,0]*right[0,0] + left[1,1]*right[1,0];
						RESULT[1,1] := left[1,0]*right[0,1] + left[1,1]*right[1,1];
					END;

				|Mat3x3:
					IF GetFlags(ADDRESSOF(RESULT)) * SmallArrayMask # Mat3x3 THEN
						IF dadr = 0 THEN NEW(RESULT,3,3);dadr := GetAdr(ADDRESSOF(RESULT));
						ELSE Halt(GeometryMismatch,ADDRESSOF(left),ADDRESSOF(right),0);
						END;
					END;

					IF matMulR3x3 # NIL THEN matMulR3x3(dadr,ladr,radr);
					ELSE
						RESULT[0,0] := left[0,0]*right[0,0] + left[0,1]*right[1,0] + left[0,2]*right[2,0];
						RESULT[0,1] := left[0,0]*right[0,1] + left[0,1]*right[1,1] + left[0,2]*right[2,1];
						RESULT[0,2] := left[0,0]*right[0,2] + left[0,1]*right[1,2] + left[0,2]*right[2,2];

						RESULT[1,0] := left[1,0]*right[0,0] + left[1,1]*right[1,0] + left[1,2]*right[2,0];
						RESULT[1,1] := left[1,0]*right[0,1] + left[1,1]*right[1,1] + left[1,2]*right[2,1];
						RESULT[1,2] := left[1,0]*right[0,2] + left[1,1]*right[1,2] + left[1,2]*right[2,2];

						RESULT[2,0] := left[2,0]*right[0,0] + left[2,1]*right[1,0] + left[2,2]*right[2,0];
						RESULT[2,1] := left[2,0]*right[0,1] + left[2,1]*right[1,1] + left[2,2]*right[2,1];
						RESULT[2,2] := left[2,0]*right[0,2] + left[2,1]*right[1,2] + left[2,2]*right[2,2];
					END;

				|Mat4x4:
					IF GetFlags(ADDRESSOF(RESULT)) * SmallArrayMask # Mat4x4 THEN
						IF dadr = 0 THEN NEW(RESULT,4,4); dadr := GetAdr(ADDRESSOF(RESULT));
						ELSE Halt(GeometryMismatch,ADDRESSOF(left),ADDRESSOF(right),0);
						END;
					END;

					IF matMulR4x4 # NIL THEN matMulR4x4(dadr,ladr,radr);
					ELSE
						RESULT[0,0] := left[0,0]*right[0,0] + left[0,1]*right[1,0] + left[0,2]*right[2,0] + left[0,3]*right[3,0];
						RESULT[0,1] := left[0,0]*right[0,1] + left[0,1]*right[1,1] + left[0,2]*right[2,1] + left[0,3]*right[3,1];
						RESULT[0,2] := left[0,0]*right[0,2] + left[0,1]*right[1,2] + left[0,2]*right[2,2] + left[0,3]*right[3,2];
						RESULT[0,3] := left[0,0]*right[0,3] + left[0,1]*right[1,3] + left[0,2]*right[2,3] + left[0,3]*right[3,3];

						RESULT[1,0] := left[1,0]*right[0,0] + left[1,1]*right[1,0] + left[1,2]*right[2,0] + left[1,3]*right[3,0];
						RESULT[1,1] := left[1,0]*right[0,1] + left[1,1]*right[1,1] + left[1,2]*right[2,1] + left[1,3]*right[3,1];
						RESULT[1,2] := left[1,0]*right[0,2] + left[1,1]*right[1,2] + left[1,2]*right[2,2] + left[1,3]*right[3,2];
						RESULT[1,3] := left[1,0]*right[0,3] + left[1,1]*right[1,3] + left[1,2]*right[2,3] + left[1,3]*right[3,3];

						RESULT[2,0] := left[2,0]*right[0,0] + left[2,1]*right[1,0] + left[2,2]*right[2,0] + left[2,3]*right[3,0];
						RESULT[2,1] := left[2,0]*right[0,1] + left[2,1]*right[1,1] + left[2,2]*right[2,1] + left[2,3]*right[3,1];
						RESULT[2,2] := left[2,0]*right[0,2] + left[2,1]*right[1,2] + left[2,2]*right[2,2] + left[2,3]*right[3,2];
						RESULT[2,3] := left[2,0]*right[0,3] + left[2,1]*right[1,3] + left[2,2]*right[2,3] + left[2,3]*right[3,3];

						RESULT[3,0] := left[3,0]*right[0,0] + left[3,1]*right[1,0] + left[3,2]*right[2,0] + left[3,3]*right[3,0];
						RESULT[3,1] := left[3,0]*right[0,1] + left[3,1]*right[1,1] + left[3,2]*right[2,1] + left[3,3]*right[3,1];
						RESULT[3,2] := left[3,0]*right[0,2] + left[3,1]*right[1,2] + left[3,2]*right[2,2] + left[3,3]*right[3,2];
						RESULT[3,3] := left[3,0]*right[0,3] + left[3,1]*right[1,3] + left[3,2]*right[2,3] + left[3,3]*right[3,3];
					END;
			ELSE
				ApplyMatMulLoop( ADDRESS OF RESULT, ADDRESS OF left, ADDRESS OF right, SIZEOF( FLOAT32 ),
									loopMatMulARAR, matMulR );
			END;
		ELSE
			ApplyMatMulLoop( ADDRESS OF RESULT, ADDRESS OF left, ADDRESS OF right, SIZEOF( FLOAT32 ),
									loopMatMulARAR, matMulR );
		END;
		RETURN RESULT
	END "*";

	(*
		Optimized for small arrays (Alexey Morozov)

		use of CONST for left, right makes execution slower, it seems that a new descriptor is created in this case
	*)
	OPERATOR "*"*(CONST left: ARRAY [ * , * ] OF FLOAT32; CONST right: ARRAY [ * ] OF FLOAT32 ): ARRAY [ * ] OF FLOAT32;
	VAR
		flags: SET; dadr, ladr, radr: ADDRESS;
		v0, v1, v2: FLOAT32;
	BEGIN

		dadr := GetAdr(ADDRESSOF(RESULT));
		ladr := GetAdr(ADDRESSOF(left));
		radr := GetAdr(ADDRESSOF(right));

		flags := SmallArrayMask * GetFlags(ADDRESSOF(left)) *  GetFlags(ADDRESSOF(right));

		CASE flags OF

			MatVec2x2:
				IF GetFlags(ADDRESSOF(RESULT)) * SmallArrayMask # Vec2 THEN
					IF dadr = 0 THEN NEW(RESULT,2);dadr := GetAdr(ADDRESSOF(RESULT));
					ELSE Halt(GeometryMismatch,ADDRESSOF(left),ADDRESSOF(right),0);
					END;
				END;

				IF matVecMulR2x2 # NIL THEN matVecMulR2x2(dadr,ladr,radr);
				ELSE
					(* account possible overlapping *)
					v0 := right[0];
					RESULT[0] := left[0,0]*v0 + left[0,1]*right[1];
					RESULT[1] := left[1,0]*v0 + left[1,1]*right[1];
				END;

			|MatVec3x3:
				IF GetFlags(ADDRESSOF(RESULT)) * SmallArrayMask # Vec3 THEN
					IF dadr = 0 THEN NEW(RESULT,3);dadr := GetAdr(ADDRESSOF(RESULT));
					ELSE Halt(GeometryMismatch,ADDRESSOF(left),ADDRESSOF(right),0);
					END;
				END;

				IF matVecMulR3x3 # NIL THEN matVecMulR3x3(dadr,ladr,radr);
				ELSE
					(* account possible overlapping *)
					v0 := right[0]; v1 := right[1];
					RESULT[0] := left[0,0]*v0 + left[0,1]*v1 + left[0,2]*right[2];
					RESULT[1] := left[1,0]*v0 + left[1,1]*v1 + left[1,2]*right[2];
					RESULT[2] := left[2,0]*v0 + left[2,1]*v1 + left[2,2]*right[2];
				END;

			|MatVec4x4:
				IF GetFlags(ADDRESSOF(RESULT)) * SmallArrayMask # Vec4 THEN
					IF dadr = 0 THEN NEW(RESULT,4);dadr := GetAdr(ADDRESSOF(RESULT));
					ELSE Halt(GeometryMismatch,ADDRESSOF(left),ADDRESSOF(right),0);
					END;
				END;

				IF matVecMulR4x4 # NIL THEN matVecMulR4x4(dadr,ladr,radr);
				ELSE
					(* account possible overlapping *)
					v0 := right[0]; v1 := right[1]; v2 := right[2];
					RESULT[0] := left[0,0]*v0 + left[0,1]*v1 + left[0,2]*v2 + left[0,3]*right[3];
					RESULT[1] := left[1,0]*v0 + left[1,1]*v1 + left[1,2]*v2 + left[1,3]*right[3];
					RESULT[2] := left[2,0]*v0 + left[2,1]*v1 + left[2,2]*v2 + left[2,3]*right[3];
					RESULT[3] := left[3,0]*v0 + left[3,1]*v1 + left[3,2]*v2 + left[3,3]*right[3];
				END;

		ELSE
			ApplyMatVecMulLoop( ADDRESS OF RESULT, ADDRESS OF left, ADDRESS OF right,
											SIZEOF( FLOAT32 ), loopMatMulARAR, matMulR );
		END;
		RETURN RESULT
	END "*";

	OPERATOR "*"*(  CONST left: ARRAY [ * ] OF FLOAT32;
														CONST right: ARRAY [ * , * ] OF FLOAT32  ): ARRAY [ * ] OF FLOAT32;
	BEGIN
		ApplyVecMatMulLoop( ADDRESS OF RESULT, ADDRESS OF left, ADDRESS OF right,
											SIZEOF( FLOAT32 ), loopMatMulARAR, matMulR );
		RETURN RESULT
	END "*";

(** FLOAT64 *)

	PROCEDURE MatMulAXAXLoop( ladr, radr, dadr: ADDRESS; linc, rinc, len: SIZE );
	VAR lval, rval, dval: FLOAT64;
	BEGIN
		dval := 0;
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  dval := dval + lval * rval;
			INC( ladr, linc );  INC( radr, rinc );  DEC( len );
		END;
		SYSTEM.PUT( dadr, dval );
	END MatMulAXAXLoop;

	(*
		Optimized for small matrices (Alexey Morozov)

		use of CONST for left, right makes execution slower, it seems that a new descriptor is created in this case
	*)
	OPERATOR "*"*( CONST left, right: ARRAY [ * , * ] OF FLOAT64): ARRAY [ * , * ] OF FLOAT64;
	VAR
		flags: SET; dadr, ladr, radr: ADDRESS;
	BEGIN

		dadr := GetAdr(ADDRESSOF(RESULT));
		ladr := GetAdr(ADDRESSOF(left));
		radr := GetAdr(ADDRESSOF(right));

		IF (ladr # dadr) & (radr # dadr) THEN

			flags := GetFlags(ADDRESSOF(left)) * GetFlags(ADDRESSOF(right));

			CASE flags OF
				Mat2x2:
					IF GetFlags(ADDRESSOF(RESULT)) # Mat2x2 THEN
						IF dadr = 0 THEN NEW(RESULT,2,2);
						ELSE Halt(GeometryMismatch,ADDRESSOF(left),ADDRESSOF(right),0);
						END;
					END;

					IF matMulLR2x2 # NIL THEN matMulLR2x2(dadr,ladr,radr);
					ELSE
						RESULT[0,0] := left[0,0]*right[0,0] + left[0,1]*right[1,0];
						RESULT[0,1] := left[0,0]*right[0,1] + left[0,1]*right[1,1];
						RESULT[1,0] := left[1,0]*right[0,0] + left[1,1]*right[1,0];
						RESULT[1,1] := left[1,0]*right[0,1] + left[1,1]*right[1,1];
					END;

				|Mat3x3:
					IF GetFlags(ADDRESSOF(RESULT)) # Mat3x3 THEN
						IF dadr = 0 THEN NEW(RESULT,3,3);
						ELSE Halt(GeometryMismatch,ADDRESSOF(left),ADDRESSOF(right),0);
						END;
					END;

					IF matMulLR3x3 # NIL THEN matMulLR3x3(dadr,ladr,radr);
					ELSE
						RESULT[0,0] := left[0,0]*right[0,0] + left[0,1]*right[1,0] + left[0,2]*right[2,0];
						RESULT[0,1] := left[0,0]*right[0,1] + left[0,1]*right[1,1] + left[0,2]*right[2,1];
						RESULT[0,2] := left[0,0]*right[0,2] + left[0,1]*right[1,2] + left[0,2]*right[2,2];

						RESULT[1,0] := left[1,0]*right[0,0] + left[1,1]*right[1,0] + left[1,2]*right[2,0];
						RESULT[1,1] := left[1,0]*right[0,1] + left[1,1]*right[1,1] + left[1,2]*right[2,1];
						RESULT[1,2] := left[1,0]*right[0,2] + left[1,1]*right[1,2] + left[1,2]*right[2,2];

						RESULT[2,0] := left[2,0]*right[0,0] + left[2,1]*right[1,0] + left[2,2]*right[2,0];
						RESULT[2,1] := left[2,0]*right[0,1] + left[2,1]*right[1,1] + left[2,2]*right[2,1];
						RESULT[2,2] := left[2,0]*right[0,2] + left[2,1]*right[1,2] + left[2,2]*right[2,2];
					END;

				|Mat4x4:
					IF GetFlags(ADDRESSOF(RESULT)) # Mat4x4 THEN
						IF dadr = 0 THEN NEW(RESULT,4,4);
						ELSE Halt(GeometryMismatch,ADDRESSOF(left),ADDRESSOF(right),0);
						END;
					END;

					IF matMulLR4x4 # NIL THEN matMulLR4x4(dadr,ladr,radr);
					ELSE
						RESULT[0,0] := left[0,0]*right[0,0] + left[0,1]*right[1,0] + left[0,2]*right[2,0] + left[0,3]*right[3,0];
						RESULT[0,1] := left[0,0]*right[0,1] + left[0,1]*right[1,1] + left[0,2]*right[2,1] + left[0,3]*right[3,1];
						RESULT[0,2] := left[0,0]*right[0,2] + left[0,1]*right[1,2] + left[0,2]*right[2,2] + left[0,3]*right[3,2];
						RESULT[0,3] := left[0,0]*right[0,3] + left[0,1]*right[1,3] + left[0,2]*right[2,3] + left[0,3]*right[3,3];

						RESULT[1,0] := left[1,0]*right[0,0] + left[1,1]*right[1,0] + left[1,2]*right[2,0] + left[1,3]*right[3,0];
						RESULT[1,1] := left[1,0]*right[0,1] + left[1,1]*right[1,1] + left[1,2]*right[2,1] + left[1,3]*right[3,1];
						RESULT[1,2] := left[1,0]*right[0,2] + left[1,1]*right[1,2] + left[1,2]*right[2,2] + left[1,3]*right[3,2];
						RESULT[1,3] := left[1,0]*right[0,3] + left[1,1]*right[1,3] + left[1,2]*right[2,3] + left[1,3]*right[3,3];

						RESULT[2,0] := left[2,0]*right[0,0] + left[2,1]*right[1,0] + left[2,2]*right[2,0] + left[2,3]*right[3,0];
						RESULT[2,1] := left[2,0]*right[0,1] + left[2,1]*right[1,1] + left[2,2]*right[2,1] + left[2,3]*right[3,1];
						RESULT[2,2] := left[2,0]*right[0,2] + left[2,1]*right[1,2] + left[2,2]*right[2,2] + left[2,3]*right[3,2];
						RESULT[2,3] := left[2,0]*right[0,3] + left[2,1]*right[1,3] + left[2,2]*right[2,3] + left[2,3]*right[3,3];

						RESULT[3,0] := left[3,0]*right[0,0] + left[3,1]*right[1,0] + left[3,2]*right[2,0] + left[3,3]*right[3,0];
						RESULT[3,1] := left[3,0]*right[0,1] + left[3,1]*right[1,1] + left[3,2]*right[2,1] + left[3,3]*right[3,1];
						RESULT[3,2] := left[3,0]*right[0,2] + left[3,1]*right[1,2] + left[3,2]*right[2,2] + left[3,3]*right[3,2];
						RESULT[3,3] := left[3,0]*right[0,3] + left[3,1]*right[1,3] + left[3,2]*right[2,3] + left[3,3]*right[3,3];
					END;
			ELSE
				ApplyMatMulLoop( ADDRESS OF RESULT, ADDRESS OF left, ADDRESS OF right, SIZEOF( FLOAT64 ),
									loopMatMulAXAX, matMulX );
			END;
		ELSE
			ApplyMatMulLoop( ADDRESS OF RESULT, ADDRESS OF left, ADDRESS OF right, SIZEOF( FLOAT64 ),
									loopMatMulAXAX, matMulX );
		END;
		RETURN RESULT
	END "*";

	(*
		Optimized for small arrays (Alexey Morozov)

		use of CONST for left, right makes execution slower, it seems that a new descriptor is created in this case
	*)
	OPERATOR "*"*(CONST left: ARRAY [ * , * ] OF FLOAT64;
												CONST right: ARRAY [ * ] OF FLOAT64  ): ARRAY [ * ] OF FLOAT64;
	VAR
		flags: SET; dadr, ladr, radr: ADDRESS;
		v0, v1, v2: FLOAT64;
	BEGIN

		dadr := GetAdr(ADDRESSOF(RESULT));
		ladr := GetAdr(ADDRESSOF(left));
		radr := GetAdr(ADDRESSOF(right));

		flags := GetFlags(ADDRESSOF(left)) * GetFlags(ADDRESSOF(right));

		CASE flags OF
			MatVec2x2:
				IF GetFlags(ADDRESSOF(RESULT)) # Vec2 THEN
					IF dadr = 0 THEN NEW(RESULT,2);
					ELSE Halt(GeometryMismatch,ADDRESSOF(left),ADDRESSOF(right),0);
					END;
				END;

				IF matVecMulLR2x2 # NIL THEN matVecMulLR2x2(dadr,ladr,radr);
				ELSE
					(* account possible overlapping *)
					v0 := right[0];
					RESULT[0] := left[0,0]*v0 + left[0,1]*right[1];
					RESULT[1] := left[1,0]*v0 + left[1,1]*right[1];
				END;

			|MatVec3x3:
				IF GetFlags(ADDRESSOF(RESULT)) # Vec3 THEN
					IF dadr = 0 THEN NEW(RESULT,3);
					ELSE Halt(GeometryMismatch,ADDRESSOF(left),ADDRESSOF(right),0);
					END;
				END;

				IF matVecMulLR3x3 # NIL THEN matVecMulLR3x3(dadr,ladr,radr);
				ELSE
					(* account possible overlapping *)
					v0 := right[0]; v1 := right[1];
					RESULT[0] := left[0,0]*v0 + left[0,1]*v1 + left[0,2]*right[2];
					RESULT[1] := left[1,0]*v0 + left[1,1]*v1 + left[1,2]*right[2];
					RESULT[2] := left[2,0]*v0 + left[2,1]*v1 + left[2,2]*right[2];
				END;

			|MatVec4x4:
				IF GetFlags(ADDRESSOF(RESULT)) # Vec4 THEN
					IF dadr = 0 THEN NEW(RESULT,4);
					ELSE Halt(GeometryMismatch,ADDRESSOF(left),ADDRESSOF(right),0);
					END;
				END;

				IF matVecMulLR4x4 # NIL THEN matVecMulLR4x4(dadr,ladr,radr);
				ELSE
					(* account possible overlapping *)
					v0 := right[0]; v1 := right[1]; v2 := right[2];
					RESULT[0] := left[0,0]*v0 + left[0,1]*v1 + left[0,2]*v2 + left[0,3]*right[3];
					RESULT[1] := left[1,0]*v0 + left[1,1]*v1 + left[1,2]*v2 + left[1,3]*right[3];
					RESULT[2] := left[2,0]*v0 + left[2,1]*v1 + left[2,2]*v2 + left[2,3]*right[3];
					RESULT[3] := left[3,0]*v0 + left[3,1]*v1 + left[3,2]*v2 + left[3,3]*right[3];
				END;

		ELSE
			ApplyMatVecMulLoop( ADDRESS OF RESULT, ADDRESS OF left, ADDRESS OF right,
											SIZEOF( FLOAT64 ), loopMatMulAXAX, matMulX );
		END;
		RETURN RESULT
	END "*";

	OPERATOR "*"*( CONST left: ARRAY [ * ] OF FLOAT64;
														CONST right: ARRAY [ * , * ] OF FLOAT64  ): ARRAY [ * ] OF FLOAT64;
	BEGIN
		ApplyVecMatMulLoop( ADDRESS OF RESULT, ADDRESS OF left, ADDRESS OF right,
											SIZEOF( FLOAT64 ), loopMatMulAXAX, matMulX );
		RETURN RESULT
	END "*";

(** SIGNED8 *)
	PROCEDURE MatMulIncASASLoop( ladr, radr, dadr: ADDRESS; linc, rinc, len: SIZE );
	VAR lval, rval, dval: SIGNED8;
	BEGIN
		SYSTEM.GET( dadr, dval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  dval := dval + lval * rval;
			(* KernelLog.String("mul with: "); KernelLog.Int(lval,10); KernelLog.Int(rval,10); KernelLog.Ln; *)
			INC( ladr, linc );  INC( radr, rinc );  DEC( len );
		END;
		SYSTEM.PUT( dadr, dval );
	END MatMulIncASASLoop;

	OPERATOR "INCMUL"*(CONST left, right: ARRAY [ * , * ] OF SIGNED8 ): ARRAY [ * , * ] OF SIGNED8;
	BEGIN
		ApplyMatMulLoop( ADDRESS OF RESULT, ADDRESS OF left, ADDRESS OF right,
									SIZEOF( SIGNED8 ), MatMulIncASASLoop, NIL );
		RETURN RESULT
	END "INCMUL";

	OPERATOR "INCMUL"*(CONST left: ARRAY [ * , * ] OF SIGNED8;
															CONST right: ARRAY [ * ] OF SIGNED8  ): ARRAY [ * ] OF SIGNED8;
	BEGIN
		ApplyMatVecMulLoop( ADDRESS OF RESULT, ADDRESS OF left, ADDRESS OF right,
											SIZEOF( SIGNED8 ), MatMulIncASASLoop, NIL );
		RETURN RESULT
	END "INCMUL";

	OPERATOR "INCMUL"*( CONST left: ARRAY [ * ] OF SIGNED8;
															CONST right: ARRAY [ * , * ] OF SIGNED8  ): ARRAY [ * ] OF SIGNED8;
		BEGIN
		ApplyVecMatMulLoop( ADDRESS OF RESULT, ADDRESS OF left, ADDRESS OF right,
											SIZEOF( SIGNED8 ), MatMulIncASASLoop, NIL );
		RETURN RESULT
	END "INCMUL";

	OPERATOR "DECMUL"*(CONST left, right: ARRAY [ * , * ] OF SIGNED8  ): ARRAY [ * , * ] OF SIGNED8;
	BEGIN
		RESULT := -RESULT;
		ApplyMatMulLoop( ADDRESS OF RESULT, ADDRESS OF left, ADDRESS OF right,
									SIZEOF( SIGNED8 ), MatMulIncASASLoop, NIL );
		RESULT := -RESULT;
		RETURN RESULT
	END "DECMUL";

	OPERATOR "DECMUL"*(CONST left: ARRAY [ * , * ] OF SIGNED8;
															CONST right: ARRAY [ * ] OF SIGNED8  ): ARRAY [ * ] OF SIGNED8;
	BEGIN
		RESULT := -RESULT;
		ApplyMatVecMulLoop( ADDRESS OF RESULT, ADDRESS OF left, ADDRESS OF right,
											SIZEOF( SIGNED8 ), MatMulIncASASLoop, NIL );
		RESULT := -RESULT;
		RETURN RESULT
	END "DECMUL";

	OPERATOR "DECMUL"*( CONST left: ARRAY [ * ] OF SIGNED8;
															CONST right: ARRAY [ * , * ] OF SIGNED8 ): ARRAY [ * ] OF SIGNED8;
	BEGIN
		RESULT := -RESULT;
		ApplyVecMatMulLoop( ADDRESS OF RESULT, ADDRESS OF left, ADDRESS OF right,
											SIZEOF( SIGNED8 ), MatMulIncASASLoop, NIL );
		RESULT := -RESULT;
		RETURN RESULT
	END "DECMUL";

(** SIGNED16 *)
	PROCEDURE MatMulIncAIAILoop( ladr, radr, dadr: ADDRESS; linc, rinc, len: SIZE );
	VAR lval, rval, dval: SIGNED16;
	BEGIN
		SYSTEM.GET( dadr, dval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  dval := dval + lval * rval;
			INC( ladr, linc );  INC( radr, rinc );  DEC( len );
		END;
		SYSTEM.PUT( dadr, dval );
	END MatMulIncAIAILoop;

	OPERATOR "INCMUL"*(CONST left, right: ARRAY [ * , * ] OF SIGNED16 ): ARRAY [ * , * ] OF SIGNED16;
	BEGIN
		ApplyMatMulLoop( ADDRESS OF RESULT, ADDRESS OF left, ADDRESS OF right,
									SIZEOF( SIGNED16 ), MatMulIncAIAILoop, NIL );
		RETURN RESULT
	END "INCMUL";

	OPERATOR "INCMUL"*(CONST left: ARRAY [ * , * ] OF SIGNED16; CONST right: ARRAY [ * ] OF SIGNED16): ARRAY [ * ] OF SIGNED16;
	BEGIN
		ApplyMatVecMulLoop( ADDRESS OF RESULT, ADDRESS OF left, ADDRESS OF right,
											SIZEOF( SIGNED16 ), MatMulIncAIAILoop, NIL );
		RETURN RESULT
	END "INCMUL";

	OPERATOR "INCMUL"*( CONST left: ARRAY [ * ] OF SIGNED16; CONST right: ARRAY [ * , * ] OF SIGNED16 ): ARRAY [ * ] OF SIGNED16;
		BEGIN
		ApplyVecMatMulLoop( ADDRESS OF RESULT, ADDRESS OF left, ADDRESS OF right,
											SIZEOF( SIGNED16 ), MatMulIncAIAILoop, NIL );
		RETURN RESULT
	END "INCMUL";

	OPERATOR "DECMUL"*(CONST left, right: ARRAY [ * , * ] OF SIGNED16 ): ARRAY [ * , * ] OF SIGNED16;
	BEGIN
		RESULT := -RESULT;
		ApplyMatMulLoop( ADDRESS OF RESULT, ADDRESS OF left, ADDRESS OF right,
									SIZEOF( SIGNED16 ), MatMulIncAIAILoop, NIL );
		RESULT := -RESULT;
		RETURN RESULT
	END "DECMUL";

	OPERATOR "DECMUL"*( CONST left: ARRAY [ * , * ] OF SIGNED16; CONST right: ARRAY [ * ] OF SIGNED16 ): ARRAY [ * ] OF SIGNED16;
		BEGIN
		RESULT := -RESULT;
		ApplyMatVecMulLoop( ADDRESS OF RESULT, ADDRESS OF left, ADDRESS OF right,
											SIZEOF( SIGNED16 ), MatMulIncAIAILoop, NIL );
		RESULT := -RESULT;
		RETURN RESULT
	END "DECMUL";

	OPERATOR "DECMUL"*( CONST left: ARRAY [ * ] OF SIGNED16; CONST right: ARRAY [ * , * ] OF SIGNED16  ): ARRAY [ * ] OF SIGNED16;
		BEGIN
		RESULT := -RESULT;
		ApplyVecMatMulLoop( ADDRESS OF RESULT, ADDRESS OF left, ADDRESS OF right,
											SIZEOF( SIGNED16 ), MatMulIncAIAILoop, NIL );
		RESULT := -RESULT;
		RETURN RESULT
	END "DECMUL";

(** SIGNED32 *)
	PROCEDURE MatMulIncALALLoop( ladr, radr, dadr: ADDRESS; linc, rinc, len: SIZE );
	VAR lval, rval, dval: SIGNED32;
	BEGIN
		SYSTEM.GET( dadr, dval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  dval := dval + lval * rval;
			INC( ladr, linc );  INC( radr, rinc );  DEC( len );
		END;
		SYSTEM.PUT( dadr, dval );
	END MatMulIncALALLoop;

	OPERATOR "INCMUL"*(CONST left, right: ARRAY [ * , * ] OF SIGNED32 ): ARRAY [ * , * ] OF SIGNED32;
	BEGIN
		ApplyMatMulLoop( ADDRESS OF RESULT, ADDRESS OF left, ADDRESS OF right,
									SIZEOF( SIGNED32 ), MatMulIncALALLoop, NIL );
		RETURN RESULT
	END "INCMUL";

	OPERATOR "INCMUL"*(CONST left: ARRAY [ * , * ] OF SIGNED32; CONST right: ARRAY [ * ] OF SIGNED32 ): ARRAY [ * ] OF SIGNED32;
	BEGIN
		ApplyMatVecMulLoop( ADDRESS OF RESULT, ADDRESS OF left, ADDRESS OF right,
											SIZEOF( SIGNED32 ), MatMulIncALALLoop, NIL );
		RETURN RESULT
	END "INCMUL";

	OPERATOR "INCMUL"*( CONST left: ARRAY [ * ] OF SIGNED32; CONST right: ARRAY [ * , * ] OF SIGNED32 ): ARRAY [ * ] OF SIGNED32;
	BEGIN
		ApplyVecMatMulLoop( ADDRESS OF RESULT, ADDRESS OF left, ADDRESS OF right,
											SIZEOF( SIGNED32 ), MatMulIncALALLoop, NIL );
		RETURN RESULT
	END "INCMUL";

	OPERATOR "DECMUL"*( CONST left, right: ARRAY [ * , * ] OF SIGNED32  ): ARRAY [ * , * ] OF SIGNED32;
	BEGIN
		RESULT := -RESULT;
		ApplyMatMulLoop( ADDRESS OF RESULT, ADDRESS OF left, ADDRESS OF right,
									SIZEOF( SIGNED32 ), MatMulIncALALLoop, NIL );
		RESULT := -RESULT;
		RETURN RESULT
	END "DECMUL";

	OPERATOR "DECMUL"*(CONST left: ARRAY [ * , * ] OF SIGNED32; CONST right: ARRAY [ * ] OF SIGNED32 ): ARRAY [ * ] OF SIGNED32;
	BEGIN
		RESULT := -RESULT;
		ApplyMatVecMulLoop( ADDRESS OF RESULT, ADDRESS OF left, ADDRESS OF right,
											SIZEOF( SIGNED32 ), MatMulIncALALLoop, NIL );
		RESULT := -RESULT;
		RETURN RESULT
	END "DECMUL";

	OPERATOR "DECMUL"*(CONST left: ARRAY [ * ] OF SIGNED32; CONST right: ARRAY [ * , * ] OF SIGNED32  ): ARRAY [ * ] OF SIGNED32;
	BEGIN
		RESULT := -RESULT;
		ApplyVecMatMulLoop( ADDRESS OF RESULT, ADDRESS OF left, ADDRESS OF right,
											SIZEOF( SIGNED32 ), MatMulIncALALLoop, NIL );
		RESULT := -RESULT;
		RETURN RESULT
	END "DECMUL";

	(** FLOAT32 *)
	PROCEDURE MatMulIncARARLoop( ladr, radr, dadr: ADDRESS; linc, rinc, len: SIZE );
	VAR lval, rval, dval: FLOAT32;
	BEGIN
		SYSTEM.GET( dadr, dval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  dval := dval + lval * rval;
			INC( ladr, linc );  INC( radr, rinc );  DEC( len );
		END;
		SYSTEM.PUT( dadr, dval );
	END MatMulIncARARLoop;

	OPERATOR "INCMUL"*(CONST left, right: ARRAY [ * , * ] OF FLOAT32 ): ARRAY [ * , * ] OF FLOAT32;
	BEGIN
		ApplyMatMulLoop( ADDRESS OF RESULT, ADDRESS OF left, ADDRESS OF right, SIZEOF( FLOAT32 ),
									loopMatMulIncARAR, matMulIncR );
		RETURN RESULT
	END "INCMUL";

	OPERATOR "INCMUL"*(CONST left: ARRAY [ * , * ] OF FLOAT32;CONST right: ARRAY [ * ] OF FLOAT32 ): ARRAY [ * ] OF FLOAT32;
	BEGIN
		ApplyMatVecMulLoop( ADDRESS OF RESULT, ADDRESS OF left, ADDRESS OF right,
											SIZEOF( FLOAT32 ), loopMatMulIncARAR, matMulIncR );
		RETURN RESULT
	END "INCMUL";

	OPERATOR "INCMUL"*( CONST left: ARRAY [ * ] OF FLOAT32; CONST right: ARRAY [ * , * ] OF FLOAT32 ): ARRAY [ * ] OF FLOAT32;
	BEGIN
		ApplyVecMatMulLoop( ADDRESS OF RESULT, ADDRESS OF left, ADDRESS OF right,
											SIZEOF( FLOAT32 ), loopMatMulIncARAR, matMulIncR );
		RETURN RESULT
	END "INCMUL";

	OPERATOR "DECMUL"*(CONST left, right: ARRAY [ * , * ] OF FLOAT32 ): ARRAY [ * , * ] OF FLOAT32;
	BEGIN
		RESULT := -RESULT;
		ApplyMatMulLoop( ADDRESS OF RESULT, ADDRESS OF left, ADDRESS OF right, SIZEOF( FLOAT32 ),
									loopMatMulIncARAR, matMulIncR );
		RESULT := -RESULT;
		RETURN RESULT
	END "DECMUL";

	OPERATOR "DECMUL"*( CONST left: ARRAY [ * , * ] OF FLOAT32; CONST right: ARRAY [ * ] OF FLOAT32 ): ARRAY [ * ] OF FLOAT32;
	BEGIN
		RESULT := -RESULT;
		ApplyMatVecMulLoop( ADDRESS OF RESULT, ADDRESS OF left, ADDRESS OF right,
											SIZEOF( FLOAT32 ), loopMatMulIncARAR, matMulIncR );
		RESULT := -RESULT;
		RETURN RESULT
	END "DECMUL";

	OPERATOR "DECMUL"*(CONST left: ARRAY [ * ] OF FLOAT32; CONST right: ARRAY [ * , * ] OF FLOAT32 ): ARRAY [ * ] OF FLOAT32;
	BEGIN
		RESULT := -RESULT;
		ApplyVecMatMulLoop( ADDRESS OF RESULT, ADDRESS OF left, ADDRESS OF right,
											SIZEOF( FLOAT32 ), loopMatMulIncARAR, matMulIncR );
		RESULT := -RESULT;
		RETURN RESULT
	END "DECMUL";
(** FLOAT64 *)

	PROCEDURE MatMulIncAXAXLoop( ladr, radr, dadr: ADDRESS; linc, rinc, len: SIZE );
	VAR lval, rval, dval: FLOAT64;
	BEGIN
		SYSTEM.GET( dadr, dval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  dval := dval + lval * rval;
			INC( ladr, linc );  INC( radr, rinc );  DEC( len );
		END;
		SYSTEM.PUT( dadr, dval );
	END MatMulIncAXAXLoop;

	OPERATOR "INCMUL"*(CONST left, right: ARRAY [ * , * ] OF FLOAT64  ): ARRAY [ * , * ] OF FLOAT64;
	BEGIN
		ApplyMatMulLoop( ADDRESS OF RESULT, ADDRESS OF left, ADDRESS OF right,
									SIZEOF( FLOAT64 ), loopMatMulIncAXAX, matMulIncX );
		RETURN RESULT
	END "INCMUL";

	OPERATOR "INCMUL"*(CONST left: ARRAY [ * , * ] OF FLOAT64; CONST right: ARRAY [ * ] OF FLOAT64  ): ARRAY [ * ] OF FLOAT64;
	BEGIN
		ApplyMatVecMulLoop( ADDRESS OF RESULT, ADDRESS OF left, ADDRESS OF right,
											SIZEOF( FLOAT64 ), loopMatMulIncAXAX, matMulIncX );
		RETURN RESULT
	END "INCMUL";

	OPERATOR "INCMUL"*( CONST left: ARRAY [ * ] OF FLOAT64; CONST right: ARRAY [ * , * ] OF FLOAT64 ): ARRAY [ * ] OF FLOAT64;
		BEGIN
		ApplyVecMatMulLoop( ADDRESS OF RESULT, ADDRESS OF left, ADDRESS OF right,
											SIZEOF( FLOAT64 ), loopMatMulIncAXAX, matMulIncX );
		RETURN RESULT
	END "INCMUL";

	OPERATOR "DECMUL"*(CONST left, right: ARRAY [ * , * ] OF FLOAT64 ): ARRAY [ * , * ] OF FLOAT64;
	BEGIN
		RESULT := -RESULT;
		ApplyMatMulLoop( ADDRESS OF RESULT, ADDRESS OF left, ADDRESS OF right,
									SIZEOF( FLOAT64 ), loopMatMulIncAXAX, matMulIncX );
		RESULT := -RESULT;
		RETURN RESULT
	END "DECMUL";

	OPERATOR "DECMUL"*( CONST left: ARRAY [ * , * ] OF FLOAT64; CONST right: ARRAY [ * ] OF FLOAT64 ): ARRAY [ * ] OF FLOAT64;
	BEGIN
		RESULT := -RESULT;
		ApplyMatVecMulLoop( ADDRESS OF RESULT, ADDRESS OF left, ADDRESS OF right,
											SIZEOF( FLOAT64 ), loopMatMulIncAXAX, matMulIncX );
		RESULT := -RESULT;
		RETURN RESULT
	END "DECMUL";

	OPERATOR "DECMUL"*( CONST left: ARRAY [ * ] OF FLOAT64; CONST right: ARRAY [ * , * ] OF FLOAT64 ): ARRAY [ * ] OF FLOAT64;
	BEGIN
		RESULT := -RESULT;
		ApplyVecMatMulLoop( ADDRESS OF RESULT, ADDRESS OF left, ADDRESS OF right,
											SIZEOF( FLOAT64 ), loopMatMulIncAXAX, matMulIncX );
		RESULT := -RESULT;
		RETURN RESULT
	END "DECMUL";

(*** Cross product ********************************************************************)

	OPERATOR "*"*(CONST left, right: ARRAY [ * ] OF SIGNED8  ): ARRAY [ * ] OF SIGNED8;
	VAR vl1, vl2, vl3, vr1, vr2, vr3: SIGNED8;
	BEGIN
		IF (LEN( left,0 ) # 3) OR (LEN( right,0 ) # 3) THEN
			Halt( GeometryMismatch, ADDRESSOF( left ), ADDRESSOF( right ),  0 )
		END;
		IF LEN( RESULT,0 ) # 3 THEN NEW( RESULT, 3 ) END;   (* will trap if not allowed *)
		vl1 := left[0];  vl2 := left[1];  vl3 := left[2];  vr1 := right[0];  vr2 := right[1];
		vr3 := right[2];  RESULT[0] := vl2 * vr3 - vl3 * vr2;
		RESULT[1] := vl3 * vr1 - vl1 * vr3;  RESULT[2] := vl1 * vr2 - vl2 * vr1;
		RETURN RESULT
	END "*";

	OPERATOR "*"*(CONST left, right: ARRAY [ * ] OF SIGNED16 ): ARRAY [ * ] OF SIGNED16;
	VAR vl1, vl2, vl3, vr1, vr2, vr3: SIGNED16;
	BEGIN
		IF (LEN( left,0 ) # 3) OR (LEN( right,0 ) # 3) THEN
			Halt( GeometryMismatch, ADDRESSOF( left ), ADDRESSOF( right ),  0 )
		END;
		IF LEN( RESULT,0 ) # 3 THEN NEW( RESULT, 3 ) END;   (* will trap if not allowed *)
		vl1 := left[0];  vl2 := left[1];  vl3 := left[2];  vr1 := right[0];  vr2 := right[1];
		vr3 := right[2];  RESULT[0] := vl2 * vr3 - vl3 * vr2;
		RESULT[1] := vl3 * vr1 - vl1 * vr3;  RESULT[2] := vl1 * vr2 - vl2 * vr1;
		RETURN RESULT
	END "*";

	OPERATOR "*"*(CONST left, right: ARRAY [ * ] OF SIGNED32 ): ARRAY [ * ] OF SIGNED32;
	VAR vl1, vl2, vl3, vr1, vr2, vr3: SIGNED32;
	BEGIN
		IF (LEN( left,0 ) # 3) OR (LEN( right,0 ) # 3) THEN
			Halt( GeometryMismatch, ADDRESSOF( left ), ADDRESSOF( right ),  0 )
		END;
		IF LEN( RESULT,0 ) # 3 THEN NEW( RESULT, 3 ) END;   (* will trap if not allowed *)
		vl1 := left[0];  vl2 := left[1];  vl3 := left[2];  vr1 := right[0];  vr2 := right[1];
		vr3 := right[2];  RESULT[0] := vl2 * vr3 - vl3 * vr2;
		RESULT[1] := vl3 * vr1 - vl1 * vr3;  RESULT[2] := vl1 * vr2 - vl2 * vr1;
		RETURN RESULT
	END "*";

	OPERATOR "*"*(CONST left, right: ARRAY [ * ] OF FLOAT32 ): ARRAY [ * ] OF FLOAT32;
	VAR vl1, vl2, vl3, vr1, vr2, vr3: FLOAT32;
	BEGIN
		IF (LEN( left,0 ) # 3) OR (LEN( right,0 ) # 3) THEN
			Halt( GeometryMismatch, ADDRESSOF( left ), ADDRESSOF( right ), 0 )
		END;
		IF LEN( RESULT,0 ) # 3 THEN NEW( RESULT, 3 ) END;   (* will trap if not allowed *)
		vl1 := left[0];  vl2 := left[1];  vl3 := left[2];  vr1 := right[0];  vr2 := right[1];
		vr3 := right[2];  RESULT[0] := vl2 * vr3 - vl3 * vr2;
		RESULT[1] := vl3 * vr1 - vl1 * vr3;  RESULT[2] := vl1 * vr2 - vl2 * vr1;
		RETURN RESULT
	END "*";

	OPERATOR "*"*(CONST left, right: ARRAY [ * ] OF FLOAT64 ): ARRAY [ * ] OF FLOAT64;
	VAR vl1, vl2, vl3, vr1, vr2, vr3: FLOAT64;
	BEGIN
		IF (LEN( left,0 ) # 3) OR (LEN( right,0 ) # 3) THEN
			Halt( GeometryMismatch, ADDRESSOF( left ), ADDRESSOF( right ),  0 )
		END;
		IF LEN( RESULT,0 ) # 3 THEN NEW( RESULT, 3 ) END;   (* will trap if not allowed *)
		vl1 := left[0];  vl2 := left[1];  vl3 := left[2];  vr1 := right[0];  vr2 := right[1];
		vr3 := right[2];  RESULT[0] := vl2 * vr3 - vl3 * vr2;
		RESULT[1] := vl3 * vr1 - vl1 * vr3;  RESULT[2] := vl1 * vr2 - vl2 * vr1;
		RETURN RESULT
	END "*";

	OPERATOR "*"*(CONST left, right: ARRAY [ ? ] OF FLOAT64 ): ARRAY {UNSAFE} [ ? ] OF FLOAT64;
	VAR tensor: Tensor;
	BEGIN
		IF (DIM(left) = 2) & (DIM(right)=2) THEN
			EnsureArrayDesc(2, SYSTEM.VAL(Tensor, RESULT));
		ELSIF (DIM(left) = 2) & (DIM(right)=1) THEN
			EnsureArrayDesc(1, SYSTEM.VAL(Tensor, RESULT));
		ELSE HALT(200);
		END;
		ApplyMatMulLoop(SYSTEM.VAL(Tensor, RESULT), SYSTEM.VAL(Tensor, left), SYSTEM.VAL(Tensor, right), SIZEOF( FLOAT64 ),
									loopMatMulAXAX, matMulX );
		RETURN RESULT
	END "*";

	OPERATOR "*"*(CONST left, right: ARRAY [ ? ] OF FLOAT32 ): ARRAY {UNSAFE} [ ? ] OF FLOAT32;
	BEGIN
		IF (DIM(left) = 2) & (DIM(right)=2) THEN
			EnsureArrayDesc(2, SYSTEM.VAL(Tensor, RESULT));
		ELSIF (DIM(left) = 2) & (DIM(right)=1) THEN
			EnsureArrayDesc(1, SYSTEM.VAL(Tensor, RESULT));
		ELSE HALT(200);
		END;

		ApplyMatMulLoop(SYSTEM.VAL(Tensor, RESULT), SYSTEM.VAL(Tensor, left), SYSTEM.VAL(Tensor, right), SIZEOF( FLOAT32 ),
									loopMatMulARAR, matMulR );
		RETURN RESULT
	END "*";

	OPERATOR "*"*(CONST left, right: ARRAY [ ? ] OF SIGNED32 ): ARRAY {UNSAFE} [ ? ] OF SIGNED32;
	BEGIN
		IF (DIM(left) = 2) & (DIM(right)=2) THEN
			EnsureArrayDesc(2, SYSTEM.VAL(Tensor, RESULT));
		ELSIF (DIM(left) = 2) & (DIM(right)=1) THEN
			EnsureArrayDesc(1, SYSTEM.VAL(Tensor, RESULT));
		ELSE HALT(200);
		END;
		ApplyMatMulLoop(SYSTEM.VAL(Tensor, RESULT), SYSTEM.VAL(Tensor, left), SYSTEM.VAL(Tensor, right),  SIZEOF( SIGNED32 ),
									MatMulALALLoop, NIL );
		RETURN RESULT
	END "*";

	OPERATOR "*"*(CONST left, right: ARRAY [ ? ] OF SIGNED16 ): ARRAY {UNSAFE} [ ? ] OF SIGNED16;
	BEGIN
		IF (DIM(left) = 2) & (DIM(right)=2) THEN
			EnsureArrayDesc(2, SYSTEM.VAL(Tensor, RESULT));
		ELSIF (DIM(left) = 2) & (DIM(right)=1) THEN
			EnsureArrayDesc(1, SYSTEM.VAL(Tensor, RESULT));
		ELSE HALT(200);
		END;
		ApplyMatMulLoop(SYSTEM.VAL(Tensor, RESULT), SYSTEM.VAL(Tensor, left), SYSTEM.VAL(Tensor, right), SIZEOF( SIGNED16 ),
									MatMulAIAILoop,NIL );
		RETURN RESULT
	END "*";

	OPERATOR "*"*(CONST left, right: ARRAY [ ? ] OF SIGNED8 ): ARRAY {UNSAFE} [ ? ] OF SIGNED8;
	BEGIN
		IF (DIM(left) = 2) & (DIM(right)=2) THEN
			EnsureArrayDesc(2, SYSTEM.VAL(Tensor, RESULT));
		ELSIF (DIM(left) = 2) & (DIM(right)=1) THEN
			EnsureArrayDesc(1, SYSTEM.VAL(Tensor, RESULT));
		ELSE HALT(200);
		END;
		ApplyMatMulLoop(SYSTEM.VAL(Tensor, RESULT), SYSTEM.VAL(Tensor, left), SYSTEM.VAL(Tensor, right), SIZEOF( SIGNED8 ),
									MatMulASASLoop, NIL );
		RETURN RESULT
	END "*";

(** Transpose  ********************************************************************)

	PROCEDURE Overlap( src1, src2: ADDRESS ): BOOLEAN;
	VAR from1, from2, to1, to2: ADDRESS;  dim: SIZE;
	BEGIN
		from1 := GetAdr( src1 );  from2 := GetAdr( src2 );  to1 := from1;  to2 := from2;
		dim := GetDim( src1 ) - 1;
		WHILE (dim > 0) DO
			to1 := to1 + (GetLen( src1, dim ) - 1) * GetIncr( src1, dim );  DEC( dim );
		END;
		dim := GetDim( src2 ) - 1;
		WHILE (dim > 0) DO
			to2 := to2 + (GetLen( src2, dim ) - 1) * GetIncr( src2, dim );  DEC( dim );
		END;
		IF from1 < from2 THEN RETURN to1 >= from2;
		ELSIF from2 < from1 THEN RETURN to2 >= from1;
		ELSE RETURN TRUE;
		END;
	END Overlap;

(*
	PROCEDURE Overlap( src1, src2, dim: ADDRESS ): BOOLEAN;
	VAR from1, from2, to1, to2: ADDRESS;
	BEGIN
		from1 := GetAdr( src1 );  from2 := GetAdr( src2 );  to1 := from1;  to2 := from2;
		DEC( dim );
		WHILE (dim > 0) DO
			to1 := to1 + (GetLen( src1, dim ) - 1) * GetIncr( src1, dim );
			to2 := to2 + (GetLen( src2, dim ) - 1) * GetIncr( src2, dim );  DEC( dim );
		END;
		IF from1 < from2 THEN RETURN to1 >= from2;
		ELSIF from2 < from1 THEN RETURN to2 >= from1;
		ELSE RETURN TRUE;
		END;
	END Overlap;
	*)

	PROCEDURE AllocateTransposed( VAR dest: UnsafeArrayT;  CONST src: UnsafeArrayT; elementsize: SIZE ): BOOLEAN;
	VAR Size: SIZE;
		(* allocate a structure in dest compatible with src, if necessary. returns if allocation has taken place *)

		PROCEDURE TransposedShape( l, r: ADDRESS ): BOOLEAN;
		VAR dim,max: SIZE;
		BEGIN
			dim := GetDim( l );
			IF dim # GetDim( r ) THEN RETURN FALSE END;
			max := dim-1;
			WHILE (dim > 0) DO
				DEC( dim );
				IF GetLen( l, max-dim ) # GetLen( r, dim ) THEN RETURN FALSE END;
			END;
			RETURN TRUE;
		END TransposedShape;

		PROCEDURE NewData;
		VAR max,dim, len, size: SIZE; data: ANY;
		BEGIN
			dim := GetDim( src );  size := elementsize;
			PutDim( dest, dim );
			PutSize( dest, elementsize );
			max := dim-1;
			WHILE (dim > 0) DO
				DEC( dim );
				len := GetLen( src, max-dim );  PutLen( dest, dim, len );
				PutInc( dest, dim, size );  size := size * len;
			END;
			SYSTEM.NEW( data, size  + ArrayAlignment);
			PutAdr( dest, Align(data) );
			PutPtr( dest, data );
		END NewData;

	BEGIN
		IF dest # 0 THEN Size := GetSize( dest );  ASSERT( Size = elementsize );  END;
		IF debug THEN KernelLog.String( "Allocate same " );  Report( "allocation source", src );  Report( "allocation des", dest );  END;
		IF dest = 0 THEN  (* NIL pointer, guaranteed to be tensor *)
			dest := GetArrayDesc( GetDim( src ) );
			PutFlags(dest, {TensorFlag});
			NewData();
			RETURN TRUE;
		ELSIF GetDim( dest ) # GetDim( src ) THEN  (* different dimension *)
			(* check if re-allocation of descriptor is allowed *)
			IF ~(TensorFlag IN GetFlags( dest )) &
				~(TemporaryFlag IN GetFlags( dest )) THEN  (* no, not allowed*)
				HALT( 100 );
			END;
			dest := GetArrayDesc( GetDim( src ) );
			PutFlags(dest, {TensorFlag});
			NewData();
			RETURN TRUE;
		ELSIF (GetAdr( dest ) = 0) OR ~TransposedShape( dest, src ) THEN
			(* check if re-allocation of array data is allowed *)
			IF RangeFlag IN GetFlags( dest ) THEN  (* no! not allowed *)
				HALT( 100 );
			END;
			NewData();
		END;
		RETURN FALSE;
	END AllocateTransposed;

	PROCEDURE Transpose*(dest: UnsafeArray (* untraced! *); CONST left: UnsafeArrayT;  Size: SIZE );
	VAR len0, len1, linc0, linc1, dinc0, dinc1: SIZE; ladr, dadr: ADDRESS;  p: ANY;

		PROCEDURE CopyLoop( src, dest: ADDRESS; srcinc, destinc, len: SIZE );
		BEGIN
			WHILE (len > 0) DO
				SYSTEM.MOVE( src, dest, Size );  INC( src, srcinc );  INC( dest, destinc );
				DEC( len );
			END;
		END CopyLoop;

	BEGIN
		IF TemporaryFlag IN GetFlags( dest ) THEN  (* destination is on the stack: can optimize transposition *)
			PutAdr( dest, GetAdr( left ) );  PutPtr( dest, GetPtr( left ) );
			PutLen( dest, 1, GetLen( left, 0 ) );  PutLen( dest, 0, GetLen( left, 1 ) );
			PutInc( dest, 1, GetIncr( left, 0 ) );  PutInc( dest, 0, GetIncr( left, 1 ) );
		ELSE
			len0 := GetLen( left, 0 );  len1 := GetLen( left, 1 );
			IF AllocateTransposed(dest,left,Size) THEN Halt(AllocationForbidden,dest,0,0); END;
			IF Overlap( left, dest ) THEN  (* copy data first, then transpose *)
				SYSTEM.NEW( p, len0 * len1 * Size  + ArrayAlignment);  dinc0 := Size;  dinc1 := len0 * Size;
				dadr := Align(p);  linc0 := GetIncr( left, 0 );
				linc1 := GetIncr( left, 1 );  ladr := GetAdr( left );
				WHILE (len0 > 0) DO
					CopyLoop( ladr, dadr, linc1, dinc1, len1 );  INC( ladr, linc0 );
					INC( dadr, dinc0 );  DEC( len0 );
				END;
				len0 := GetLen( left, 0 );  linc0 := Size;  linc1 := len0 * Size;
				ladr := p;
			ELSE
				linc0 := GetIncr( left, 0 );  linc1 := GetIncr( left, 1 );  ladr := GetAdr( left );
			END;
			dinc0 := GetIncr( dest, 0 );  dinc1 := GetIncr( dest, 1 );
			dadr := GetAdr( dest );
			IF (Size = 4) & (transpose4 # NIL ) THEN
				transpose4( ladr, dadr, linc0, linc1, dinc0, dinc1, len0, len1 );
			ELSIF (Size = 8) & (transpose8 # NIL ) THEN
				transpose8( ladr, dadr, linc0, linc1, dinc0, dinc1, len0, len1 );
			ELSE
				WHILE (len0 > 0) DO
					CopyLoop( ladr, dadr, linc1, dinc0, len1 );  INC( ladr, linc0 );
					INC( dadr, dinc1 );  DEC( len0 );
				END;
			END;
		END;
	END Transpose;

	OPERATOR "`"*(CONST left: ARRAY [ * , * ] OF SIGNED8): ARRAY [ * , * ] OF SIGNED8;
	BEGIN
		Transpose( ADDRESSOF( RESULT ), ADDRESSOF( left ), SIZEOF( SIGNED8 ) );
		RETURN RESULT
	END "`";

	OPERATOR "`"*( CONST left: ARRAY [ * , * ] OF SIGNED16 ):ARRAY [ * , * ] OF SIGNED16 ;
	BEGIN
		Transpose( ADDRESSOF( RESULT ), ADDRESSOF( left ), SIZEOF( SIGNED16 ) );
		RETURN RESULT
	END "`";

	OPERATOR "`"*( CONST left: ARRAY [ * , * ] OF SIGNED32 ): ARRAY [ * , * ] OF SIGNED32;
	BEGIN
		Transpose( ADDRESSOF( RESULT ), ADDRESSOF( left ), SIZEOF( SIGNED32 ) );
		RETURN RESULT
	END "`";

	OPERATOR "`"*( CONST left: ARRAY [ * , * ] OF FLOAT32 ): ARRAY [ * , * ] OF FLOAT32;
	BEGIN
		Transpose( ADDRESSOF( RESULT ), ADDRESSOF( left ), SIZEOF( FLOAT32 ) );
		RETURN RESULT
	END "`";

	OPERATOR "`"*( CONST left: ARRAY [ * , * ] OF FLOAT64 ): ARRAY [ * , * ] OF FLOAT64;
	BEGIN
		Transpose( ADDRESSOF( RESULT ), ADDRESSOF( left ), SIZEOF( FLOAT64 ) );
		RETURN RESULT
	END "`";

	PROCEDURE CheckTensorGeometry( left, right, dest: ADDRESS; ldim, rdim: SIZE ): BOOLEAN;
	VAR i: SIZE;
	BEGIN
		FOR i := 0 TO rdim - 1 DO
			IF GetLen( right, i ) # GetLen( dest, i ) THEN RETURN FALSE END;
		END;
		FOR i := 0 TO ldim - 1 DO
			IF GetLen( left, i ) # GetLen( dest, rdim + i ) THEN RETURN FALSE END;
		END;
		RETURN TRUE;
	END CheckTensorGeometry;

(*
	PROCEDURE Zero(p: ANY; size: SIGNED32);
	VAR adr: SIGNED32;
	BEGIN
		adr := SYSTEM.VAL(SIGNED32,p);
		WHILE(size>0) DO
			SYSTEM.PUT8(adr,0); DEC(size);INC(adr);
		END;
	END Zero;
*)

	PROCEDURE DoReshape*( VAR dest: UnsafeArrayT;  CONST src: UnsafeArrayT; CONST shape: ARRAY [ * ] OF SIZE );
	VAR i, Size: SIZE;

		oldSize, newSize: SIZE;  oldDim, newDim: SIZE;

		squeezingReshape: BOOLEAN;
		new: UnsafeArrayT;

		PROCEDURE CheckAlloc;
		BEGIN
			ASSERT( (dest = NIL) OR (TensorFlag IN GetFlags(dest)) & ~(RangeFlag IN GetFlags(dest)) );
		END CheckAlloc;

		PROCEDURE NewDescriptor(): UnsafeArrayT;
		BEGIN
			CheckAlloc;
			RETURN GetArrayDesc(newDim);
		END NewDescriptor;

		(*	Added by Alexey
			Returns TRUE if the new shape is the result of squeezing (removing of singleton dimensions)
		*)
		PROCEDURE SqueezingReshape(): BOOLEAN;
		VAR
			i, j, n: SIZE;
		BEGIN
			IF oldDim > newDim THEN
				i := 0; j := 0;
				WHILE (i < oldDim) & (j < newDim) DO
					n := GetLen(src,i);
					IF n = shape[j] THEN INC(j); END;
					INC(i);
				END;
				WHILE (i < oldDim) & (GetLen(src,i) = 1) DO INC(i); END; (* account for a trailing sequence of 1 *)
			ELSE
				squeezingReshape := FALSE;
			END;

			squeezingReshape := (i = oldDim) & (j = newDim);

			RETURN squeezingReshape;
		END SqueezingReshape;

		(*returns TRUE if the target is already allocated coninuous memory of correct length*)
		PROCEDURE TargetContinuous(): BOOLEAN;
		VAR
			i, n: SIZE;
			continue: BOOLEAN;
		BEGIN
			i := GetDim(dest)-1; n := GetIncr(dest,i);
			continue := TRUE;
			WHILE (i > 0) & continue DO
				n := n * GetLen(dest,i);
				DEC(i);
				continue := GetIncr(dest,i) = n;
			END;
			(*TRACE(i,continue,Size,GetSize(dest));*)
			(*tod obviously size is not what I expect it to be*)
			IF (i = 0) & (n#0) & continue & (Size=GetSize(dest))  THEN (* destination array is continuous memory of the proper lenght *)
				RETURN TRUE;
			ELSE
				RETURN FALSE;
			END;
		END TargetContinuous;
		(* returns TRUE if reshape preserves contiguity pattern and thus is valid even for subranged arrays *)
		PROCEDURE PreservesContiguity(): BOOLEAN;
		VAR
			i, n: SIZE;
			continue: BOOLEAN;
		BEGIN
			i := oldDim-1; n := GetIncr(src,i);
			continue := TRUE;
			WHILE (i > 0) & continue DO
				n := n * GetLen(src,i);
				DEC(i);
				continue := GetIncr(src,i) = n;
			END;

			IF (i = 0) & continue THEN (* array can be fully linearized and, therefore, can be reshaped to any size *)
				RETURN TRUE;
			ELSE Err("Not yet implemented!");
			END;
		END PreservesContiguity;

		(* Added by Alexey *)
		PROCEDURE NewDescriptorForSameData(CONST src: UnsafeArrayT): UnsafeArrayT;
		VAR len, size, i, j: SIZE; new: UnsafeArrayT;
		BEGIN
			CheckAlloc();
			new:= GetArrayDesc( newDim );

			IF ~squeezingReshape THEN
				size := Size;
				FOR i := newDim - 1 TO 0 BY -1 DO
					len := shape[i];  PutInc( new, i, size );  PutLen( new, i, len );
					size := size * len;
				END;
			ELSE (* squeezing reshape *)
				j := 0; len := shape[j];
				FOR i := 0 TO oldDim-1 DO
					IF GetLen(src,i) = len THEN
						PutInc(new,j,GetIncr(src,i)); PutLen(new,j,len);
						INC(j);
						IF j < newDim THEN len := shape[j]; END;
					END;
				END;
			END;

			IF RangeFlag IN GetFlags(src) THEN (* keep range awareness for case of squeezing reshape and preservation of contiguity *)
				PutFlags(new,GetFlags(new)+{RangeFlag});
			END;

			PutAdr( new, GetAdr(src) );
			PutPtr( new, GetPtr(src) );  PutDim( new, newDim );
			PutSize( new, Size );

			RETURN new;
		END NewDescriptorForSameData;

		PROCEDURE NewData(VAR dest: UnsafeArrayT);
		VAR len, size, i: SIZE; data: ANY;
		BEGIN
			size := Size;
			FOR i := newDim - 1 TO 0 BY -1 DO
				len := shape[i];  PutInc( dest, i, size );  PutLen( dest, i, len );
				size := size * len;
			END;
			SYSTEM.NEW( data, size  + ArrayAlignment);   (* Zero(data,size*Size); *)
			PutAdr( dest, Align(data) );
			PutPtr( dest, data );  PutDim( dest, newDim );
			PutSize( dest, Size );
		END NewData;

		PROCEDURE CopyData(CONST src: UnsafeArrayT; CONST dest: UnsafeArrayT);
		VAR d, s: SIZE; dadr: ADDRESS;

			PROCEDURE Loop( dim: SIZE;  sadr: ADDRESS );
			VAR inc, len, i: SIZE;
			BEGIN
				IF dim = d THEN
					inc := GetIncr( src, dim );  len := GetLen( src, dim );
					FOR i := 0 TO len - 1 DO
						SYSTEM.MOVE( sadr, dadr, s );  INC( dadr, s );  INC( sadr, inc );
					END;
				ELSE
					inc := GetIncr( src, dim );  len := GetLen( src, dim );  INC( dim );
					FOR i := 0 TO len - 1 DO Loop( dim, sadr );  INC( sadr, inc );  END;
				END;
			END Loop;

		BEGIN
			s := Size;  ASSERT( GetSize( src ) = s );  d := GetDim( src ) - 1;
			WHILE (d >= 0) & (GetIncr( src, d ) = s) DO
				s := s * GetLen( src, d );  DEC( d );
			END;
			IF d = -1 THEN  (* special case: both continuous *)
				SYSTEM.MOVE( GetAdr( src ), GetAdr( dest ), s );
			ELSE dadr := GetAdr( dest );  Loop( 0, GetAdr( src ) );
			END;
		END CopyData;

		PROCEDURE CopyDescriptor(CONST src: UnsafeArrayT; CONST dest: UnsafeArrayT);
		BEGIN
			ASSERT( GetDim( src ) = GetDim( dest ) );
			PutPtr(dest, GetPtr(src)); (* GC ! *)
			SYSTEM.MOVE( src, dest, MathLenOffset + GetDim( src ) * 8 );
		END CopyDescriptor;

		PROCEDURE ShapeDiffers( ): BOOLEAN;
		VAR i: SIZE;
		BEGIN
			ASSERT(GetDim(dest) = newDim);
			FOR i := 0 TO newDim - 1 DO
				IF GetLen(dest,i) # shape[i] THEN RETURN TRUE END;
			END;
			RETURN FALSE;
		END ShapeDiffers;

	BEGIN
	(*
			cases
			1.) descriptor may be replaced = dimension may vary: dest = TENSOR
			2.) descriptor may be reshaped: dest = ARRAY but no RANGE
			3.) descriptor may not be reshaped: dest = RANGE
		*)
		(* first check invariants *)
		oldDim := GetDim( src );
		IF oldDim = 0 THEN oldSize := 0
		ELSE
			oldSize := 1;
			FOR i := 0 TO oldDim - 1 DO oldSize := oldSize * GetLen( src, i );  END;
		END;
		newDim := LEN( shape, 0 );
		IF newDim = 0 THEN newSize := 0
		ELSE
			newSize := 1;
			FOR i := 0 TO newDim - 1 DO newSize := newSize * shape[i];  END;
		END;
		IF oldSize # newSize THEN Err( "RESHAPE: Total length mismatch" );  END;

		Size := GetSize( src );
		ASSERT( (Size > 0) & (Size < 128) );   (*! heuristic, remove upper bound *)

		IF dest = src THEN (* added by Alexey *)
			IF ~(RangeFlag IN GetFlags(dest)) OR PreservesContiguity() OR SqueezingReshape() THEN
				dest := NewDescriptorForSameData(src);
			ELSIF ((newDim = oldDim) & ~ShapeDiffers()) THEN
				(* create a copy of the original descriptor *)
				CheckAlloc();
				dest := GetArrayDesc(newDim);
				CopyDescriptor(src,dest);
			ELSE
				Err( "RESHAPE: given RANGE array can not be reshaped!" );
			END;
		ELSIF (dest = 0) THEN  (* is tensor for sure *)
			dest := NewDescriptor();  NewData(dest);  CopyData(src, dest);
		ELSIF (dest = temporary) THEN
			dest := NewDescriptorForSameData(src);
		ELSIF TargetContinuous() THEN
			dest := NewDescriptor(); CopyData(src, dest);
		(*todo: check if target continous memory of correct size, if so don't allocate memory*)
		ELSIF (newDim # GetDim( dest )) THEN  (* must be tensor *)
			IF ~(TensorFlag IN GetFlags( dest )) THEN  (* no, not allowed*)
				Err( "RESHAPE: new dimension only allowed for TENSOR" );
			END;
			dest := NewDescriptor();  NewData(dest);  CopyData(src, dest);
		ELSIF ShapeDiffers() THEN  (* same dim but shape of destination does not match *)
			IF RangeFlag IN GetFlags( dest ) THEN Err( "RESHAPE: new shape not allowed for RANGE" );  END;
			NewData(dest);  CopyData(src, dest);
		ELSIF ~SameShape( src, dest ) THEN  (* shape for destination matches but that of src is different *)
			new := NewDescriptor();  NewData(new);  CopyData(src, new); CopyData(new, dest);
		ELSE  (* same shape, just copy *)
			CopyContent( src, dest, Size );  RETURN;
		END;

	END DoReshape;

	(* this is memory safe: the allocation result is written to a pointer in the call chain *)
	PROCEDURE AllocateTensorA*( CONST a: ARRAY OF SIZE;  elementSize: SIZE; tag: ADDRESS; VAR dest: UnsafeArrayT );
	VAR descr, data: ANY;  same: BOOLEAN;  i: SIZE;  dim: SIZE;

		PROCEDURE NewData;
		VAR len, size, i: SIZE;
		BEGIN
			size := elementSize;
			FOR i := dim - 1 TO 0 BY -1 DO
				len := a[i];
				PutInc( dest, i, size );  PutLen( dest, i, len );  size := size * len;
			END;
			IF tag = 0 THEN
				SYSTEM.NEW( data, size  + ArrayAlignment);   (* Zero(data,size*Size); *)
				dest.adr := Align(data);
			ELSE
				Heaps.NewArr(data, tag, size DIV elementSize,1,FALSE);
				dest.adr := data + ADDRESS(ArrDataArrayOffset);
			END;
			PutPtr(dest, data);
			PutSize( dest, elementSize );
		END NewData;

		PROCEDURE ClearData;
		VAR size, i: SIZE;
		BEGIN
			size := elementSize;
			FOR i := 0 TO dim-1 DO
				size := size * GetLen(dest, i);
			END;
			INC(size, (-size) MOD 4); (* round up to next multiple of 4 *)
			Machine.Fill32(GetAdr(dest), size, 0);
		END ClearData;

	BEGIN
		dim := LEN( a,0 );
		IF (dest = 0) OR (dim # GetDim( dest )) THEN
			IF dest # 0 THEN
				IF (~(TensorFlag IN GetFlags( dest ))) THEN Err( "Array's number of dimension must not be modified (no TENSOR !)" );  END;
			END;
			descr := GetArrayDesc( LEN( a,0 ) );
			dest := descr;
			NewData;
			Heaps.SetPC(data);
		ELSE
			i := 0;
			same := TRUE;
			WHILE (i < dim) & same DO
				IF GetLen( dest, i ) # a[i] THEN same := FALSE;  END;
				INC( i );
			END;
			IF ~same THEN
				IF (RangeFlag IN GetFlags( dest )) THEN Err( "Array's shape must not be modified (is RANGE !) " );  END;
				NewData;
				Heaps.SetPC(data);
			ELSE ClearData
			END;
		END;
	END AllocateTensorA;

	PROCEDURE AllocateArrayA*( CONST a: ARRAY OF SIZE;  elementSize: SIZE; tag: ADDRESS; dest: UnsafeArray);
	BEGIN
		AllocateTensorA(a,elementSize,tag,dest);
		IF dest.ptr # NIL THEN Heaps.SetPC(dest.ptr) END;
	END AllocateArrayA;

	PROCEDURE DoAllocateTensorX*( VAR dest: UnsafeArrayT; CONST a: ARRAY [ * ] OF SIZE;  Size: SIZE; tag: ADDRESS );
	VAR data: ANY;  same: BOOLEAN;  i: SIZE;  dim: SIZE;

		PROCEDURE NewData;
		VAR len, size: SIZE; i: SIZE;
		BEGIN
			size := Size;
			FOR i := dim - 1 TO 0 BY -1 DO
				len := a[i];
				(*
				KernelLog.Int(len,10); KernelLog.Ln;
				*)
				PutInc( dest, i, size );  PutLen( dest, i, len );  size := size * len;
			END;
			IF tag = 0 THEN
				SYSTEM.NEW( data, size  + ArrayAlignment);   (* Zero(data,size*Size); *)
				PutAdr( dest, Align(data) );
			ELSE
				Heaps.NewArr(data, tag, size DIV Size,1,FALSE);
				PutAdr( dest, data+ ADDRESS(ArrDataArrayOffset) );
			END;
			PutPtr( dest, data );  PutSize( dest, Size );
		END NewData;

		PROCEDURE ClearData;
		VAR size, i: SIZE;
		BEGIN
			size := Size;
			FOR i := 0 TO dim-1 DO
				size := size * GetLen(dest, i);
			END;
			INC(size, (-size) MOD 4); (* round up to next multiple of 4 *)
			Machine.Fill32(GetAdr(dest), size, 0);
		END ClearData;

	BEGIN
		dim := LEN( a,0 );

		(*! check range flag! *)

		IF (dest = NIL) OR (dim # GetDim( dest )) THEN
			IF dest # NIL THEN
				IF (~(TensorFlag IN GetFlags( dest ))) THEN Err( "Array's number of dimension must not be modified (no TENSOR !)" );  END;
			END;
			dest := GetArrayDesc( LEN( a,0 ) );
			NewData;
		ELSE
			i := 0;
			WHILE (i < dim) & same DO
				IF GetLen( dest, i ) # a[i] THEN same := FALSE;  END;
				INC( i );
			END;
			IF ~same THEN
				IF (RangeFlag IN GetFlags( dest )) THEN Err( "Array's shape must not be modified (is RANGE !) " );  END;
				NewData
			ELSE ClearData
			END;
		END;
	END DoAllocateTensorX;

	PROCEDURE AllocateTensorX( VAR dest: ARRAY {UNSAFE} [?] OF SIZE; CONST a: ARRAY [ * ] OF SIZE;  Size: SIZE; tag: ADDRESS );
	BEGIN
		DoAllocateTensorX(dest,a,Size,tag);
	END AllocateTensorX;

	PROCEDURE LenA*( VAR dest: ARRAY [ * ] OF SIZE;  src: ADDRESS );
	VAR dim, i: SIZE;
	BEGIN
		dim := GetDim( src );
		IF LEN( dest, 0 ) # dim THEN NEW( dest, dim );  END;
		FOR i := 0 TO dim - 1 DO dest[i] := GetLen( src, i );  END;
	END LenA;

	PROCEDURE IncrA*( VAR dest: ARRAY [ * ] OF SIZE;  src: ADDRESS );
	VAR dim, len: SIZE; i: SIZE;
	BEGIN
		dim := GetDim( src );  len := LEN( dest, 0 );
		IF len # dim THEN NEW( dest, dim );  END;
		FOR i := 0 TO dim - 1 DO dest[i] := GetIncr( src, i );  END;
	END IncrA;

	PROCEDURE Len*(src: ADDRESS; d: SIZE): SIZE;
	VAR dim: SIZE;
	BEGIN
		dim := GetDim(src);
		IF (d<0) OR (d>=dim) THEN HALT(100)
		ELSE
			RETURN GetLen(src,d);
		END;
	END Len;

	PROCEDURE Incr*(src: ADDRESS; d: SIZE): SIZE;
	VAR dim: SIZE;
	BEGIN
		dim := GetDim(src);
		IF (d<0) OR (d>=dim) THEN HALT(100)
		ELSE
			RETURN GetIncr(src,d);
		END;
	END Incr;

	PROCEDURE AllocateTensor( VAR dest: UnsafeArrayT;  CONST left, right: UnsafeArrayT;
												Size: SIZE );
	VAR ldim, rdim: SIZE;

		PROCEDURE NewData;
		VAR len, size, i: SIZE; data: ANY;
		BEGIN
			size := 1;
			FOR i := 0 TO ldim - 1 DO
				len := GetLen( left, i );  size := size * len;  PutLen( dest, i, len );
			END;
			FOR i := 0 TO rdim - 1 DO
				len := GetLen( right, i );  size := size * len;  PutLen( dest, ldim + i, len );
			END;
			SYSTEM.NEW( data, size * Size  + ArrayAlignment);   (* Zero(data,size*Size); *)
			(*
			KernelLog.String("adr data="); KernelLog.Int(SYSTEM.VAL(SIGNED32,data),10); KernelLog.Ln;
			KernelLog.String("adr dest="); KernelLog.Int(dest,10); KernelLog.Ln;
			*)
			size := Size;
			FOR i := ldim + rdim - 1 TO 0 BY -1 DO
				PutInc( dest, i, size );  size := size * GetLen( dest, i );
			END;
			PutAdr( dest, Align(data) );
			PutPtr( dest, data );
		END NewData;

	BEGIN
		ldim := GetDim( left );  rdim := GetDim( right );
		IF dest = 0 THEN  (* NIL pointer, guaranteed to be tensor *)
			dest := GetArrayDesc( ldim + rdim );
			NewData();
		ELSIF (ldim + rdim # GetDim( dest )) THEN
			IF ~(TensorFlag IN GetFlags( dest )) &
				~(TemporaryFlag IN GetFlags( dest )) THEN  (* no, not allowed*)
				HALT( 100 );
			END;
			dest := GetArrayDesc( ldim + rdim );
			NewData();
		ELSIF ~CheckTensorGeometry( left, right, dest, ldim, rdim ) THEN  (* dimension matches but not geometry *)
			IF RangeFlag IN GetFlags( dest ) THEN  (* no! not allowed *)
				HALT( 100 );
			END;
			NewData();
		END;
	END AllocateTensor;

(* find the largest block with a regular pattern of the form offset+{i*linc: 0<=i<len} for two arrays simultaneously. d is dimension applying to the resulting loop *)
	PROCEDURE FindPatternTensor( left, right: ADDRESS;
														VAR rdim, len, linc, ri: SIZE );
	(* geometric precondition: lengths must coincide *)
	VAR ldim: SIZE;
	BEGIN
		ldim := GetDim( left ) - 1;  rdim := GetDim( right ) - 1;
		len := GetLen( left, ldim );  ASSERT( len = GetLen( right, rdim ) );
		WHILE (len = 1) & (ldim > 0) & (rdim > 0) DO
			DEC( ldim );  DEC( rdim );  len := GetLen( left, ldim );
			ASSERT( GetLen( left, ldim ) = GetLen( right, rdim ) );
		END;
		linc := GetIncr( left, ldim );  ri := GetIncr( right, rdim );  DEC( rdim );
		DEC( ldim );
		WHILE (ldim >= 0) & (rdim >= 0) & (GetIncr( left, ldim ) = len * linc) &
				(GetIncr( right, rdim ) = len * ri) DO
			len := len * GetLen( left, ldim );
			ASSERT( GetLen( left, ldim ) = GetLen( right, rdim ) );  DEC( rdim );
			DEC( ldim );
		END;
		INC( ldim );  INC( rdim );
		IF debug THEN
			KernelLog.String( "FindPatternTensor: " );  KernelLog.Int( rdim, 10 );  KernelLog.Int( len, 10 );
			KernelLog.Int( linc, 10 );  KernelLog.Int( ri, 10 );  KernelLog.Ln;
		END;
	END FindPatternTensor;

	PROCEDURE ApplyTensorAAAOp( VAR dest: UnsafeArrayT; CONST left, right: UnsafeArrayT;  elementSize: SIZE;
														Loop: BinaryASALoop );
	VAR loopd, looplen, loopri, loopdi, lDim, rDim: SIZE;
		origdest: ADDRESS;

		PROCEDURE Traverse( ladr, radr, dadr: ADDRESS;  ldim, rdim: SIZE );
		VAR len: SIZE;  linc, rinc, dinc: SIZE;
		BEGIN
			IF (ldim < lDim) THEN
				len := GetLen( left, ldim );  linc := GetIncr( left, ldim );
				dinc := GetIncr( dest, ldim + rdim );  INC( ldim );
				WHILE (len > 0) DO
					Traverse( ladr, radr, dadr, ldim, rdim );  INC( ladr, linc );
					INC( dadr, dinc );  DEC( len );
				END;
			ELSIF (rdim # loopd) THEN
				len := GetLen( right, rdim );  rinc := GetIncr( right, rdim );
				dinc := GetIncr( dest, ldim + rdim );  INC( rdim );
				WHILE (len > 0) DO
					Traverse( ladr, radr, dadr, ldim, rdim );  INC( radr, rinc );
					INC( dadr, dinc );  DEC( len );
				END;
			ELSE
				(*
				KernelLog.String("MulALSLLoop"); KernelLog.Int(dadr,10); KernelLog.Int(loopdi,10); KernelLog.Int(looplen,10);
				KernelLog.Int(GetAdr(dest),10);
				KernelLog.Int(GetAdr(dest)+clen,10);
				KernelLog.Ln;
				*)
				Loop( radr, ladr, dadr, loopri, loopdi, looplen );

				(* loop over right matrix and destination highest continuous dimension D[x,y,z,..] := L[x,y] ** R[z,..] *)
			END;
		END Traverse;

	BEGIN
		(* check array lengths *)
		origdest := 0;  lDim := GetDim( left );  rDim := GetDim( right );
		AllocateTensor( dest, left, right, elementSize );
		(*
		IF (dest = 0) OR (GetPtr( dest ) = 0) THEN
			p := AllocateTensor( left, right, dest, elementSize )
		ELSIF ~CheckTensorGeometry( left, right, dest, lDim, rDim ) THEN
			IF GetPtr( dest ) = -1 THEN HALT( GeometryMismatch )
			ELSE p := AllocateTensor( left, right, dest, elementSize );
			END;
			(*! to be done: treat overlapping memory *)
		END;
		*)

		(* debugging *)
		IF debug THEN Report( "AAA:left", left );  Report( "AAA:right", right );  Report( "AAA:dest", dest );  END;
		(* check pattern: longest piece that can be done with a loop *)
		FindPatternTensor( dest, right, loopd, looplen, loopri, loopdi );
		(*  run through dimensions  *)

		Traverse( GetAdr( left ), GetAdr( right ), GetAdr( dest ), 0, 0 );
	END ApplyTensorAAAOp;

	OPERATOR "**"*(CONST left,right: ARRAY [?] OF SIGNED8): ARRAY {UNSAFE} [?] OF SIGNED8;
	BEGIN
		ApplyTensorAAAOp( RESULT, left, right,
										SIZEOF( SIGNED8 ), MulASSSLoop );
		RETURN RESULT
	END "**";

	OPERATOR "**"*(CONST left,right: ARRAY [?] OF SIGNED16): ARRAY {UNSAFE} [?] OF SIGNED16;
	BEGIN
		ApplyTensorAAAOp( RESULT, left, right,
										SIZEOF( SIGNED16 ), MulAISILoop );
		RETURN RESULT
	END "**";

	OPERATOR "**"*(CONST left,right: ARRAY [?] OF SIGNED32): ARRAY {UNSAFE} [?] OF SIGNED32;
	BEGIN
		ApplyTensorAAAOp( RESULT, left, right,
										SIZEOF( SIGNED32 ), MulALSLLoop );
		RETURN RESULT
	END "**";

	OPERATOR "**"*(CONST left,right: ARRAY [?] OF FLOAT32): ARRAY {UNSAFE} [?] OF FLOAT32;
	BEGIN
		ApplyTensorAAAOp( RESULT, left, right, SIZEOF( FLOAT32 ),
										loopMulARSR );
		RETURN RESULT
	END "**";

	OPERATOR "**"*(CONST left,right: ARRAY [?] OF FLOAT64): ARRAY {UNSAFE} [?] OF FLOAT64;
	BEGIN
		ApplyTensorAAAOp( RESULT, left, right,
										SIZEOF( FLOAT64 ), loopMulAXSX );
		RETURN RESULT
	END "**";

	OPERATOR "**"*(CONST left,right: ARRAY [?] OF COMPLEX32): ARRAY {UNSAFE} [?] OF COMPLEX32;
	BEGIN
		ApplyTensorAAAOp( RESULT, left, right, SIZEOF( COMPLEX32 ),
										loopMulAZSZ );
		RETURN RESULT
	END "**";

	OPERATOR "**"*(CONST left,right: ARRAY [?] OF COMPLEX64): ARRAY {UNSAFE} [?] OF COMPLEX64;
	BEGIN
		ApplyTensorAAAOp( RESULT, left, right, SIZEOF( COMPLEX64 ),
										loopMulALZSLZ );
		RETURN RESULT
	END "**";

	PROCEDURE InitOptimization;
	VAR p: PROCEDURE;
	BEGIN
		GETPROCEDURE("FoxArrayBaseOptimized","Install",p);
		IF p # NIL THEN
			p;
		ELSE
			KernelLog.String( "Warning: ArrayBase runtime library optimizer not installed." ); KernelLog.Ln;
		END;
	END InitOptimization;

	(* functionality used for index designators of including a questiomark such as A[x,*,?,*,x] *)
	PROCEDURE CopyDescriptor*(VAR dest: UnsafeArrayT; CONST src: UnsafeArrayT; prefixIndices, prefixRanges, suffixIndices, suffixRanges: SIZE);
	VAR srcDim, destDim,i,len,incr: SIZE;
	BEGIN
		IF src = 0 THEN
			HALT(100);
		ELSE
			srcDim := GetDim(src);
			destDim := srcDim - prefixIndices - suffixIndices;

			(*
			KernelLog.String("srcDim "); KernelLog.Int(srcDim,1); KernelLog.Ln;
			KernelLog.String("prefixIndices "); KernelLog.Int(prefixIndices,1); KernelLog.Ln;
			KernelLog.String("prefixRanges "); KernelLog.Int(prefixRanges,1); KernelLog.Ln;
			KernelLog.String("suffixIndices "); KernelLog.Int(suffixIndices,1); KernelLog.Ln;
			KernelLog.String("suffixRanges "); KernelLog.Int(suffixRanges,1); KernelLog.Ln;
			KernelLog.String("destDim "); KernelLog.Int(destDim,1); KernelLog.Ln;
			*)

			dest := GetArrayDesc(destDim); (* destination dimension included *)
			(* SYSTEM.MOVE(src,dest,MathLenOffset); *)
			PutAdr(dest,GetAdr(src));
			PutPtr(dest,GetPtr(src));
			PutFlags(dest,GetFlags(src));
			PutSize(dest,GetSize(src));

			FOR i := 0 TO srcDim-suffixIndices-suffixRanges-prefixIndices-prefixRanges-1 DO
				srcDim := i + prefixIndices + prefixRanges;
				destDim := i + prefixRanges;
				len := GetLen(src,srcDim);
				incr := GetIncr(src,srcDim);
				PutLen(dest,destDim,len);
				PutInc(dest,destDim,incr);
			END;
			(*
			Report("copy descriptor src",src);
			Report("copy descriptor dest",dest);
			*)
		END;
	END CopyDescriptor;

	(* when Reshape is called by a compiler, the arguments are - for the compiler - replaced as follows, this makes them compatible
		VAR dest: ARRAY [?] OF basetype
		CONST src: ARRAY [?] OF basetype
		CONST shape: ARRAY [*] OF SIGNED32
	*)
	PROCEDURE Reshape*(CONST left: ARRAY [?]; CONST right: ARRAY [*] OF SIZE): ARRAY {UNSAFE} [?];
	BEGIN
		DoReshape(RESULT, left, right);
		RETURN RESULT
	END Reshape;

	(* OLIVIER *)
	(** creates a degenerated range from an integer.
		- makes it possible to convert the result of an integer-valued procedure F() into a range
		without executing the procedure twice as it would happen in "(F() .. F() BY 1)"
	**)
	PROCEDURE RangeFromInteger*(CONST integer: SIZE): RANGE;
	BEGIN RETURN (integer .. integer BY 1)
	END RangeFromInteger;

	(* OLIVIER *)
	(** create an array with the same data but with more dimensions
		- each element in the array 'keptDimensions' corresponds to a dimension in the resulting array
		- if element = TRUE: use a dimension from the source array, i.e. reuse length and increment
		- if element = FALSE: insert a new dimension having length = 1 and increment = 0

		e.g.:
			ExpandDimensions(array, [FALSE, TRUE, FALSE, FALSE, TRUE])
			performs the following type transformation:
			ARRAY [10, 20] OF FLOAT32 -> ARRAY [1, 10, 1, 1, 20] OF FLOAT32

	**)
	PROCEDURE ExpandDimensions*(CONST sourceArray: ARRAY [?]; CONST keptDimensions: ARRAY [*] OF BOOLEAN): ARRAY [?];
	VAR
		targetDimensionality, sourceIndex, targetIndex: SIZE;
		sourceADDRESS, targetADDRESS: ADDRESS;
		targetArrayDescriptor: ANY;
	BEGIN
		sourceADDRESS := SYSTEM.VAL(ADDRESS, sourceArray);
		targetDimensionality := LEN(keptDimensions, 0);
		targetArrayDescriptor := GetArrayDesc(targetDimensionality); (* create a new array descriptor *)
		SYSTEM.PUT(ADDRESSOF(RESULT), targetArrayDescriptor);
		targetADDRESS := SYSTEM.VAL(ADDRESS, RESULT);

		PutAdr(targetADDRESS, GetAdr(sourceADDRESS));
		PutPtr(targetADDRESS, GetPtr(sourceADDRESS));
		PutFlags(targetADDRESS, {TensorFlag});
		PutSize(targetADDRESS, GetSize(sourceADDRESS));

		(* set increments and lengths *)
		sourceIndex := 0;
		FOR targetIndex := 0 TO targetDimensionality - 1 DO
			IF keptDimensions[targetIndex] THEN
				(* reuse length and increment from source array *)
				ASSERT(sourceIndex < DIM(sourceArray));
				PutLen(targetADDRESS, targetIndex, GetLen(sourceADDRESS, sourceIndex));
				PutInc(targetADDRESS, targetIndex, GetIncr(sourceADDRESS, sourceIndex));
				INC(sourceIndex)
			ELSE
				(* set length = 1 and increment = 0 *)
				PutLen(targetADDRESS, targetIndex, 1);
				PutInc(targetADDRESS, targetIndex, 0);
			END
		END;

		(* Report("expand dimensions: ", targetADDRESS); *)
		RETURN RESULT
	END ExpandDimensions;

	(* index ranges *)

	(* the length of a range, i.e. the number of indices that it stands for *)
	OPERATOR "LEN"*(CONST range: RANGE): SIZE;
	VAR
		temp, result: SIZE;
	BEGIN
		IF (LAST(range) < FIRST(range)) OR (FIRST(range) < 0) OR (STEP(range) < 1) THEN
			(* invalid range *)
			result := 0
		ELSIF LAST(range) = MAX(SIGNED32) THEN
			(* open-ended range *)
			result := MAX(SIGNED32)
		ELSE
			temp := 1 + LAST(range) - FIRST(range);
			result := temp DIV STEP(range);
			IF (temp MOD STEP(range)) # 0 THEN
				INC(result)
			END
		END;
		RETURN result
	END "LEN";

	OPERATOR "ALL"*(CONST x: ARRAY {UNSAFE} [?] OF SIGNED8; op: PROCEDURE {DELEGATE}(x: SIGNED8): SIGNED8): ARRAY {UNSAFE} [?] OF SIGNED8;
	BEGIN
		ApplyGenericUnaryAAOpS(RESULT, x, SIZEOF(SIGNED8),GenericLoopS,op);
		RETURN RESULT;
	END "ALL";

	OPERATOR "ALL"*(CONST x: ARRAY {UNSAFE} [?] OF SIGNED16; op: PROCEDURE {DELEGATE} (x: SIGNED16): SIGNED16): ARRAY {UNSAFE} [?] OF SIGNED16;
	BEGIN
		ApplyGenericUnaryAAOpI(RESULT,x,SIZEOF(SIGNED16),GenericLoopI,op);
		RETURN RESULT;
	END "ALL";

	OPERATOR "ALL"*(CONST x: ARRAY {UNSAFE} [?] OF SIGNED32; op: PROCEDURE {DELEGATE}(x: SIGNED32): SIGNED32): ARRAY {UNSAFE} [?] OF SIGNED32;
	BEGIN
		ApplyGenericUnaryAAOpL(RESULT,x,SIZEOF(SIGNED32),GenericLoopL,op);
		RETURN RESULT;
	END "ALL";

	OPERATOR "ALL"*(CONST x: ARRAY {UNSAFE} [?] OF SIGNED64; op: PROCEDURE {DELEGATE}(x: SIGNED64): SIGNED64): ARRAY {UNSAFE} [?] OF SIGNED64; (*should also accept operator ?*)
	BEGIN
		ApplyGenericUnaryAAOpH(RESULT,x,SIZEOF(SIGNED64),GenericLoopH,op);
		RETURN RESULT;
	END "ALL";

	OPERATOR "ALL"*(CONST x: ARRAY {UNSAFE} [?] OF FLOAT32; op: PROCEDURE {DELEGATE}(x: FLOAT32): FLOAT32): ARRAY {UNSAFE} [?] OF FLOAT32; (*should also accept operator ?*)
	BEGIN
		ApplyGenericUnaryAAOpR(RESULT,x,SIZEOF(FLOAT32),GenericLoopR,op);
		RETURN RESULT;
	END "ALL";

	OPERATOR "ALL"*(CONST x: ARRAY {UNSAFE} [?] OF FLOAT64; op: PROCEDURE {DELEGATE}(x: FLOAT64): FLOAT64): ARRAY{UNSAFE} [?] OF FLOAT64; (*should also accept operator ?*)
	BEGIN
		ApplyGenericUnaryAAOpX(RESULT,x,SIZEOF(FLOAT64),GenericLoopX,op);
		RETURN RESULT;
	END "ALL";

	OPERATOR "ALL"*(CONST x: ARRAY {UNSAFE} [?] OF COMPLEX32; op: PROCEDURE {DELEGATE}(x: COMPLEX32): COMPLEX32): ARRAY {UNSAFE} [?] OF COMPLEX32; (*should also accept operator ?*)
	BEGIN
		ApplyGenericUnaryAAOpZ(RESULT,x,SIZEOF(COMPLEX32),GenericLoopZ,op);
		RETURN RESULT;
	END "ALL";

	OPERATOR "ALL"*(CONST x: ARRAY {UNSAFE} [?] OF COMPLEX64; op: PROCEDURE {DELEGATE}(x: COMPLEX64): COMPLEX64): ARRAY {UNSAFE} [?] OF COMPLEX64; (*should also accept operator ?*)
	BEGIN
		ApplyGenericUnaryAAOpLZ(RESULT,x,SIZEOF(COMPLEX64),GenericLoopLZ,op);
		RETURN RESULT;
	END "ALL";

	OPERATOR "ALL"*(CONST x: ARRAY [?] OF SIGNED8; map: PROCEDURE( ladr, dadr: ADDRESS; linc, dinc, len: SIZE)): ARRAY {UNSAFE}[?]  OF SIGNED8;
	VAR elementSize: SIZE;
	BEGIN
		ApplyUnaryAAOp(RESULT,x,GetSize(x),map);
		RETURN RESULT;
	END "ALL";

	OPERATOR "ALL"*(CONST x: ARRAY [?] OF SIGNED16; map: PROCEDURE( ladr, dadr: ADDRESS; linc, dinc, len: SIZE)): ARRAY {UNSAFE}[?]  OF SIGNED16;
	VAR elementSize: SIZE;
	BEGIN
		ApplyUnaryAAOp(RESULT,x,GetSize(x),map);
		RETURN RESULT;
	END "ALL";

	OPERATOR "ALL"*(CONST x: ARRAY [?] OF SIGNED32; map: PROCEDURE( ladr, dadr: ADDRESS; linc, dinc, len: SIZE)): ARRAY {UNSAFE}[?]  OF SIGNED32;
	VAR elementSize: SIZE;
	BEGIN
		ApplyUnaryAAOp(RESULT,x,GetSize(x),map);
		RETURN RESULT;
	END "ALL";

	OPERATOR "ALL"*(CONST x: ARRAY [?] OF SIGNED64; map: PROCEDURE( ladr, dadr: ADDRESS; linc, dinc, len: SIZE)): ARRAY {UNSAFE}[?]  OF SIGNED64;
	VAR elementSize: SIZE;
	BEGIN
		ApplyUnaryAAOp(RESULT,x,GetSize(x),map);
		RETURN RESULT;
	END "ALL";

	OPERATOR "ALL"*(CONST x: ARRAY [?] OF FLOAT32; map: PROCEDURE( ladr, dadr: ADDRESS; linc, dinc, len: SIZE)): ARRAY {UNSAFE}[?]  OF FLOAT32;
	VAR elementSize: SIZE;
	BEGIN
		ApplyUnaryAAOp(RESULT,x,GetSize(x),map);
		RETURN RESULT;
	END "ALL";

	OPERATOR "ALL"*(CONST x: ARRAY [?] OF FLOAT64; map: PROCEDURE( ladr, dadr: ADDRESS; linc, dinc, len: SIZE)): ARRAY {UNSAFE}[?]  OF FLOAT64;
	VAR elementSize: SIZE;
	BEGIN
		ApplyUnaryAAOp(RESULT,x,GetSize(x),map);
		RETURN RESULT;
	END "ALL";

	OPERATOR "ALL"*(CONST x: ARRAY [?] OF COMPLEX32; map: PROCEDURE( ladr, dadr: ADDRESS; linc, dinc, len: SIZE)): ARRAY {UNSAFE}[?]  OF COMPLEX32;
	VAR elementSize: SIZE;
	BEGIN
		ApplyUnaryAAOp(RESULT,x,GetSize(x),map);
		RETURN RESULT;
	END "ALL";

	OPERATOR "ALL"*(CONST x: ARRAY [?] OF COMPLEX64; map: PROCEDURE( ladr, dadr: ADDRESS; linc, dinc, len: SIZE)): ARRAY {UNSAFE}[?]  OF COMPLEX64;
	VAR elementSize: SIZE;
	BEGIN
		ApplyUnaryAAOp(RESULT,x,GetSize(x),map);
		RETURN RESULT;
	END "ALL";




BEGIN
	alloc := 0;  NEW(temporary);
	PutFlags(temporary,{TensorFlag});
	PutDim(temporary, 0);
	SetDefaults();  InitOptimization();  (* CreateTypePool;  *)
END FoxArrayBase.

Compiler.Compile FoxArrayBase.Mod ~

System.ListModules

System.FreeDownTo FoxArrayBase ~

Debugging.DisableGC
