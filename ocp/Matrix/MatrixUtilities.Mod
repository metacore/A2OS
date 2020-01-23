MODULE MatrixUtilities;   (**  AUTHOR "Patrick Hunziker"; PURPOSE "";    **)

IMPORT Rand:=Random, MatrixBase, ComplexMathL, KernelLog, Strings, Reals, Streams, Files(*, Shortreal*);  

TYPE 
	
	Bytes2=ARRAY 2 OF CHAR;
	Datatype* = MatrixBase.Datatype;  
	Matrix* = MatrixBase.Matrix;  Vector* = MatrixBase.Vector;  Tensor*=ARRAY[?] OF Datatype;
	IntVector*= ARRAY [*] OF SIZE; IntMatrix= ARRAY [*,*] OF SIGNED32; IntTensor*=ARRAY[?] OF SIGNED32;
	BoolMatrix*= ARRAY [*,*] OF BOOLEAN;	BoolTensor*=ARRAY [?] OF BOOLEAN;
	UnaryOp*=PROCEDURE(x:Datatype):Datatype;
	BinaryOp*=PROCEDURE(x,y:Datatype):Datatype;
	
TYPE RandomGenerator*= OBJECT(Rand.Generator);
		PROCEDURE Random*(CONST size: ARRAY [*] OF SIZE;  content: SIGNED32 ): Tensor;  
		VAR i: SIZE;
		BEGIN {EXCLUSIVE}
			IF DIM(RESULT)=0 THEN NEW(RESULT, size) END;
			IF DIM(RESULT)=1 THEN
				FOR i:=0 TO LEN(RESULT,0)-1 DO
					IF content = UNIFORM THEN RESULT[i] :=Uniform();
					ELSE (*! to be done*)
					END;  
				END;  
			ELSE
				FOR i:=0 TO LEN(RESULT,0)-1 DO
					RESULT[i,?]:=Random(size[1..],content) 
				END;  
			END;  
			RETURN RESULT
		END Random;  	
		PROCEDURE Dices*(CONST size: ARRAY [*] OF SIZE;  sides: SIGNED32 ): IntTensor;  
		VAR i: SIZE;
		BEGIN {EXCLUSIVE}
			IF DIM(RESULT)=0 THEN NEW(RESULT, size) END;
			IF DIM(RESULT)=1 THEN
				FOR i:=0 TO LEN(RESULT,0)-1 DO RESULT[i] :=Dice(sides) END;  
			ELSE
				FOR i:=0 TO LEN(RESULT,0)-1 DO	RESULT[i,?]:=Dices(size[1..],sides) END;  
			END;  
			RETURN RESULT
		END Dices;  	
		PROCEDURE Binary*(CONST size: ARRAY [*] OF SIZE;  p: Datatype ): IntTensor;  
		VAR i: SIZE;
		BEGIN  {EXCLUSIVE}
			(*IF DIM(RESULT)=0 THEN NEW(RESULT, size) END;*)
			IF LEN(RESULT)#size THEN NEW(RESULT, size) END;
			IF DIM(RESULT)=1 THEN
				FOR i:=0 TO LEN(RESULT,0)-1 DO 
					IF Uniform()<p THEN RESULT[i] :=1 
					ELSE RESULT[i]:=0
					END;
				END;  
			ELSE
				FOR i:=0 TO LEN(RESULT,0)-1 DO	RESULT[i,?]:=Binary(size[1..],p) END;  
			END;  
			RETURN RESULT
		END Binary;  	
	END RandomGenerator;

CONST 
	Uniform* = 0;  Diag* = 1;  DiagDominant* = 2;  BandDiag3* = 3;  BandDiag5* = 4;  BandDiag7* = 5;  
	UNIFORM=Uniform; (*hack*)
	Tiny = 1.0D-10;  
	Equal*=0; Smaller*=1; Larger*=2; NoFit*=3;
	Downsample*=0; And*=1; Or*=2;
	
	DatatypeChar*=0;
	DatatypeLR*=2;
	DatatypeR*=3;
	DatatypeSR*=4;(*16 bit Float*)
	
	DatatypeHInt*=6;
	DatatypeLInt*=7;	
	DatatypeInt*=8;
	DatatypeSInt*=9;
	DatatypeUInt8*=10;
	DatatypeSize*=DatatypeHInt;

	
VAR  RG: RandomGenerator (*Rand.Generator*);

	


	PROCEDURE Identity*( VAR M: Matrix );  
	VAR i: SIZE;  
	BEGIN 
		M := 0;  
		FOR i := 0 TO MIN(LEN( M)) - 1 DO M[i, i] := 1;  END;  
	END Identity;  

	PROCEDURE Diagonal*( CONST v: Vector ): Matrix;  
	VAR  i: SIZE;
	BEGIN 
		IF (LEN(RESULT,0)<LEN(v,0)) OR (LEN(RESULT,1)<LEN(v,0)) THEN NEW( RESULT, LEN( v,0 ), LEN( v,0 ) ) 
		ELSE RESULT:=0;
		END;  
		FOR i := 0 TO LEN( v,0 ) - 1 DO RESULT[i, i] := v[i] END;  
		RETURN RESULT
	END Diagonal;  

(*inverted diagonal, whereby for very small elements, the inverse is set to zero. *)
	PROCEDURE InvDiag*( CONST M: Matrix ): Vector;  
	VAR x: Vector;  i: SIZE;  a: FLOAT64;
	BEGIN 
		NEW( x, MAX( LEN( M, 0 ), LEN( M, 1 ) ) );  
		FOR i := 0 TO LEN( x,0 ) - 1 DO 
			a := M[i, i];  
			IF ABS( a ) > Tiny (*MatrixBase.EPS*) THEN x[i] := 1 / a ELSE x[i] := 0 END;  
		END;  
		RETURN x
	END InvDiag;  

	PROCEDURE RandomVec*( m: SIZE;  content: SIGNED32 ): Vector;  
	VAR i: SIZE;  A: Vector;  x:Datatype;
	BEGIN 
		NEW( A, m );  
		FOR i := 0 TO m - 1 DO 
			x:=(RG.Uniform()-0.5)*2; (* -1 < x < 1 *)
			IF content = Uniform THEN A[i] := x 
			ELSE HALT(200)
			END;  
		END;  
		RETURN A
	END RandomVec;  

	PROCEDURE RandomMatrix*( m, n: SIZE;  content: SIGNED32 ): Matrix;  
	VAR i, j: SIZE;  A: Matrix;  x:Datatype;
	BEGIN 
		NEW( A, m, n );  
		FOR i := 0 TO m - 1 DO 
			FOR j := 0 TO n - 1 DO 
				x:=(RG.Uniform()-0.5)*2; (* -1 < x < 1 *)
				IF content = Uniform THEN A[i, j] := x;
				ELSIF (content = Diag) & (i = j) THEN A[i, j] := x;
				ELSIF content = DiagDominant THEN A[i, j] := x+sign(x) / ((ABS( i - j )) + 1)
				ELSIF (content = BandDiag3) & (ABS( i - j ) < 2) THEN A[i, j] := x
				ELSIF (content = BandDiag5) & (ABS( i - j ) < 3) THEN A[i, j] := x
				ELSIF (content = BandDiag7) & (ABS( i - j ) < 4) THEN A[i, j] := x
				END;  
			END;  
		END;  
		RETURN A
	END RandomMatrix;  

	PROCEDURE Random*(CONST size: ARRAY [*] OF SIZE;  content: SIGNED32 ): Tensor;  
	VAR i: SIZE;
	BEGIN 
		IF DIM(RESULT)=0 THEN NEW(RESULT, size) END;
		(*RESULT:= RG.Random(size,content);
		RETURN RESULT;
		*)
		
		IF DIM(RESULT)=1 THEN
			FOR i:=0 TO LEN(RESULT,0)-1 DO
				(*x:=(RG.Uniform()-0.5)*2; *)(* -1 < x < 1 *)
				IF content = Uniform THEN RESULT[i] :=RG.Uniform();
				ELSE (*! to be done*)
				END;  
			END;  
		ELSE
			FOR i:=0 TO LEN(RESULT,0)-1 DO
				RESULT[i,?]:=Random(size[1..],content) 
			END;  
		END;  
		RETURN RESULT
	END Random;  	
	
	(* rescale to <-1..1> *)
	PROCEDURE Normalize*(CONST m: ARRAY [?] OF Datatype):ARRAY [?] OF Datatype;
	VAR max,min:Datatype;
	BEGIN
		max:=MAX(m); min:=MIN(m);
		max:=MAX(ABS(max),ABS(min));
		RESULT:=1/max * m;
		RETURN RESULT
	END Normalize;
	
	(*rotates a matrix by 90*)
	PROCEDURE Rotate90*(VAR A: Matrix);
	BEGIN
		A:=A`;
		Mirror(A,1);
	END Rotate90;	
	

	PROCEDURE RotateRow*( VAR A: Matrix;  row, offset: SIZE );   (*cave in loops: performance killer because of repeated allocation of Vector 'r' *)
	VAR r: Vector;  len: SIZE;
	BEGIN 
		len := LEN( A, 1 );  r := A[row];  A[row, offset..] := r[.. len - offset - 1];  A[row, .. offset - 1] := r[len - offset - 1..];  
	END RotateRow;  

	PROCEDURE RotateCol*( VAR A: Matrix;  col, offset: SIZE );
	VAR r: Vector;  len: SIZE;
	BEGIN 
		len := LEN( A, 0 );  offset := offset MOD len;  r := A[.. , col];  A[offset.., col] := r[.. len - offset - 1];  A[.. offset - 1, col] := r[len - offset - 1..];  
	END RotateCol;  

	PROCEDURE RotateVec*( CONST v: Vector;  offset: SIZE ): Vector;
	VAR r: Vector;  len: SIZE;
	BEGIN 
		len := LEN( v,0 );  offset := offset MOD len;  NEW( r, len );  r[offset..] := v[.. len - offset - 1];  
		IF offset # 0 THEN 
			r[.. offset - 1] := v[len - offset..];   (*temporary fix for problem in array addressing*)
		END;  
		RETURN r
	END RotateVec;  

	(*mirror a tensor along the specified dimension.*)
	PROCEDURE Mirror*(VAR a: Tensor; CONST dim: SIGNED32);
	VAR
		i: SIZE;
		tmp: Tensor;
		tmpScal: Datatype;
	BEGIN
		ASSERT(dim<DIM(a));
		IF dim=0 THEN
			IF DIM(a)=1 THEN (*special case for vector, because 0-dimensional tensor doesn't act like a scalar*)
				FOR i:=0 TO (LEN(a,0)-1) DIV 2 DO
					tmpScal:=a[i];
					a[i]:=a[LEN(a,0)-i-1];
					a[LEN(a,0)-i-1]:=tmpScal;
				END;
			ELSE
				FOR i:=0 TO (LEN(a,0)-1) DIV 2 DO
					tmp:=a[i,?];
					a[i,?]:=a[LEN(a,0)-i-1,?];
					a[LEN(a,0)-i-1,?]:=tmp;
				END;
			END;
		ELSE
			FOR i:=0 TO (LEN(a,0)-1)  DO
				Mirror(a[i,?],dim-1);
			END;
		END;
	END Mirror;

	PROCEDURE RestrictionOp*( M, N, rowstep, origin: SIGNED32;  CONST operator: Vector ): Matrix;  
	VAR res: Matrix;  op: Vector;  row: SIGNED32;  
	BEGIN 
		NEW( res, M, N );  NEW( op, N );  op[.. MIN( LEN( operator,0 ), N ) - 1] := operator;  op := RotateVec( op, -origin );  
		FOR row := 0 TO M - 1 DO res[row] := op;  op := RotateVec( op, rowstep );  END;  
		RETURN res
	END RestrictionOp;  

	PROCEDURE ProlongationOp*( M, N, colstep, origin: SIGNED32;  CONST operator: Vector ): Matrix;  
	VAR res: Matrix;  op: Vector;  col: SIGNED32;  
	BEGIN 
		NEW( res, M, N );  NEW( op, M );  op[.. MIN( LEN( operator,0 ), M ) - 1] := operator;  op := RotateVec( op, -origin );  
		FOR col := 0 TO N - 1 DO res[.. , col] := op;  op := RotateVec( op, colstep );  END;  
		RETURN res
	END ProlongationOp;  

	PROCEDURE InterpolateMUp2*( CONST A: Matrix ): Matrix;  
	VAR res: Matrix;  i, j: SIZE;
	BEGIN 
		NEW( res, 2 * LEN( A, 0 ), 2 * LEN( A, 1 ) );  
		FOR i := 0 TO LEN( A, 0 ) - 1 DO 
			FOR j := 0 TO LEN( A, 1 ) - 1 DO res[2 * i, 2 * j] := A[i, j];  END;  
		END;  
		FOR i := 0 TO LEN( res, 0 ) - 1 BY 2 DO  (*smooth*)
			FOR j := 1 TO LEN( res, 1 ) - 2 BY 2 DO res[i, j] := 0.5 * res[i, j - 1] + 0.5 * res[i, j + 1];  END;  
			res[i, LEN( res, 1 ) - 1] := res[i, LEN( res, 1 ) - 2];   (* 1-point mirror boundary condition at end*)
		END;  
		FOR i := 1 TO LEN( res, 0 ) - 1 BY 2 DO 
			FOR j := 0 TO LEN( res, 1 ) - 1 DO res[i, j] := 0.5 * res[i - 1, j] + 0.5 * res[i - 1, j];  END;  
			res[LEN( res, 0 ) - 1, LEN( res, 1 ) - 1] := res[LEN( res, 0 ) - 2, LEN( res, 1 ) - 1];   (* 1-point mirror boundary condition at end*)
		END;  
		RETURN res
	END InterpolateMUp2;  

	PROCEDURE InterpolateMDown2*( CONST A: Matrix ): Matrix;   (*simplicistic*)
	VAR   i, j: SIZE;
	BEGIN 
		IF LEN(RESULT,0)=0 THEN NEW( RESULT, LEN( A, 0 ) DIV 2, LEN( A, 1 ) DIV 2 ); END;
		IF (LEN(A,0) MOD 2=0) & (LEN(A,1) MOD 2=0) THEN
			RESULT := A[.. BY 2, .. BY 2] + A[1.. BY 2, .. BY 2] + A[.. BY 2, 1.. BY 2] + A[1.. BY 2, 1.. BY 2]; 
		ELSE 
			FOR i := 0 TO LEN( RESULT, 0 ) - 1 DO 
				FOR j := 0 TO LEN( RESULT, 1 ) - 1 DO RESULT[i, j] := A[2 * i, 2 * j];  END;  
			END;  
		END;
		RETURN RESULT
	END InterpolateMDown2;  

	PROCEDURE InterpolateVUp2*( CONST A: Vector ): Vector;  
	VAR res: Vector;  i: SIZE;
	BEGIN 
		NEW( res, 2 * LEN( A,0 ) );  
		FOR i := 0 TO LEN( A, 0 ) - 1 DO res[2 * i] := A[i];  END;  
		FOR i := 1 TO LEN( res, 0 ) - 2 BY 2 DO  (*smooth*)
			res[i] := 0.5 * res[i - 1] + 0.5 * res[i + 1];  
		END;  
		res[LEN( res,0 ) - 1] := res[LEN( res,0 ) - 2];   (*mirror boundary at end*)
		RETURN res
	END InterpolateVUp2;  

	PROCEDURE InterpolateVDown2*( CONST A: Vector ): Vector;   (*simplicistic*)
	VAR res: Vector;  i: SIZE;
	BEGIN 
		NEW( res, LEN( A,0 ) DIV 2 );  
		FOR i := 0 TO LEN( res, 0 ) - 1 DO res[i] := (A[2 * i]+A[2 * i+1])/2;  END;  
		RETURN res
	END InterpolateVDown2;  
	
	PROCEDURE BoolToIntVector*(CONST b: ARRAY [*] OF BOOLEAN) : IntVector;
	VAR x:SIZE;
	BEGIN
		IF LEN(RESULT)=0 THEN NEW(RESULT, LEN(b,0)) END;
		FOR x:=0 TO LEN(b,0)-1 DO
			IF b[x] THEN RESULT[x]:=1 ELSE RESULT[x]:=0 END;
		END;
		RETURN RESULT
	END BoolToIntVector;
	
	PROCEDURE BoolToFloat*(CONST b: ARRAY [?] OF BOOLEAN): Tensor;
	VAR y,x:SIZE;
	BEGIN
		(*IF DIM(RESULT)#DIM(b) OR ( LEN(RESULT)#LEN(b)) THEN NEW(RESULT, LEN(b)) END;*)(*this does not currently work with the recursion*)
		IF DIM(b)>1 THEN
			FOR y:=0 TO LEN(b,0)-1 DO
				RESULT [y,?]:= BoolToFloat(b[y,?])
			END;
		ELSE
			FOR x:=0 TO LEN(b,0)-1 DO
				IF b[x] THEN RESULT[x]:=1 ELSE RESULT[x]:=0 END;
			END;
		END;
		RETURN RESULT
	END BoolToFloat;

	
	PROCEDURE BoolToIntMatrix*(CONST b: ARRAY [*,*] OF BOOLEAN): IntMatrix;
	VAR y,x:SIZE;
	BEGIN
		IF LEN(RESULT,0)=0 THEN NEW(RESULT, LEN(b,0),LEN(b,1)) END;
		FOR y:=0 TO LEN(b,0)-1 DO
			FOR x:=0 TO LEN(b,1)-1 DO
				IF b[y,x] THEN RESULT[y,x]:=1 ELSE RESULT[y,x]:=0 END;
			END;
		END;
		RETURN RESULT
	END BoolToIntMatrix;

	PROCEDURE ReduceBool2*(CONST b: ARRAY [*,*] OF BOOLEAN; sampling:SIGNED32): BoolMatrix; (*implementation limitation: even size*)
	VAR y,x:SIZE;
	BEGIN
		IF LEN(RESULT,0)=0 THEN NEW(RESULT, (LEN(b,0)+1) DIV 2, (LEN(b,1)+1) DIV 2) END;
		FOR y:=0 TO LEN(RESULT,0)-1 DO
			FOR x:=0 TO LEN(RESULT,1)-1 DO
				CASE sampling OF
					Downsample: RESULT [y,x]:= b[2*y,2*x]
					| And: RESULT [y,x]:= b[2*y,2*x] & b[2*y,2*x+1] & b[2*y+1,2*x] & b[2*y+1,2*x+1]
					| Or: RESULT [y,x]:= b[2*y,2*x] OR b[2*y,2*x+1] OR b[2*y+1,2*x] OR b[2*y+1,2*x+1]
				ELSE HALT(100);
				END;
			END;
		END; 
		RETURN RESULT
		(* (*does not yet work- reported problem to Felix*)
		CASE sampling OF
		Downsample: (*...*)
		| And:
			RESULT:=b[..BY 2, ..BY 2] & b[1..BY 2, .. BY 2];
			RESULT:=RESULT & b[1..BY 2, ..BY 2];
			RESULT:=RESULT & b[1..BY 2, 1..BY 2];
		| Or:
			RESULT:=b[..BY 2, ..BY 2] OR b[1..BY 2, .. BY 2];
			RESULT:=RESULT OR b[1..BY 2, ..BY 2];
			RESULT:=RESULT OR b[1..BY 2, 1..BY 2];
		ELSE HALT(100)
		END;
		RETURN RESULT
		*)
	END ReduceBool2;
	
	PROCEDURE ExpandBool2*(CONST b: ARRAY [*,*] OF BOOLEAN): BoolMatrix; (*implementation limitation: even size*)
	BEGIN
		IF (LEN(RESULT,0)#2*LEN(b,0)) OR (LEN(RESULT,1)#2*LEN(b,1))   THEN 
			NEW(RESULT, LEN(b,0)*2, LEN(b,1)*2) 
		END;
		RESULT[..BY 2, ..BY 2]:=b; 
		RESULT[1..BY 2, ..BY 2]:=b;
		RESULT[..BY 2, 1..BY 2]:=b;
		RESULT[1..BY 2, 1..BY 2]:=b;
		RETURN RESULT
	END ExpandBool2;
	

	PROCEDURE ApplyUnaryVec*(CONST m:Vector; op: UnaryOp): Vector;
	VAR x:SIZE;
	BEGIN
		IF LEN(RESULT,0)=0 THEN NEW(RESULT, LEN(m,0)) END;
		FOR x:=0 TO LEN(m,0)-1 DO
			RESULT[x]:=op(m[x])
		END;
		RETURN RESULT
	END ApplyUnaryVec;


	PROCEDURE ApplyUnary*(CONST m:Matrix; op: UnaryOp): Matrix;
	VAR y,x:SIZE;
	BEGIN
		IF LEN(RESULT,0)=0 THEN NEW(RESULT, LEN(m,0),LEN(m,1)) END;
		FOR y:=0 TO LEN(m,0)-1 DO
			FOR x:=0 TO LEN(m,1)-1 DO
				RESULT[y,x]:=op(m[y,x])
			END;
		END;
		RETURN RESULT
	END ApplyUnary;
	
	PROCEDURE ApplyBinaryVec*(CONST m, m1:Vector; op: BinaryOp): Vector;
	VAR x:SIZE;
	BEGIN
		IF LEN(RESULT,0)=0 THEN NEW(RESULT, LEN(m,0)) END;
		FOR x:=0 TO LEN(m,0)-1 DO
			RESULT[x]:=op(m[x], m1[x])
		END;
		RETURN RESULT
	END ApplyBinaryVec;
	
	PROCEDURE ApplyBinary*(CONST m, m1:Matrix; op: BinaryOp): Matrix;
	VAR y,x:SIZE;
	BEGIN
		IF LEN(RESULT,0)=0 THEN NEW(RESULT, LEN(m,0),LEN(m,1)) END;
		FOR y:=0 TO LEN(m,0)-1 DO
			FOR x:=0 TO LEN(m,1)-1 DO
				RESULT[y,x]:=op(m[y,x], m1[y,x])
			END;
		END;
		RETURN RESULT
	END ApplyBinary;

	PROCEDURE IsNaNL*(CONST m: Matrix): BoolMatrix;
	VAR y,x:SIZE;
	BEGIN
		IF LEN(RESULT,0)=0 THEN NEW(RESULT, LEN(m,0),LEN(m,1)) END;
		FOR y:=0 TO LEN(m,0)-1 DO
			FOR x:=0 TO LEN(m,1)-1 DO
				IF Reals.IsNaNL( m[y,x]) THEN RESULT[y,x]:=TRUE 
				ELSE RESULT[y,x]:=FALSE
				END;
			END;
		END;
		RETURN RESULT
	END IsNaNL;
	
	PROCEDURE AssignIF*(CONST m: Matrix; CONST map:BoolMatrix): Matrix;
	VAR y,x:SIZE;
	BEGIN
		IF LEN(RESULT,0)=0 THEN NEW(RESULT, LEN(m,0),LEN(m,1)) END;
		FOR y:=0 TO LEN(m,0)-1 DO
			FOR x:=0 TO LEN(m,1)-1 DO
				IF map[y,x] THEN RESULT[y,x]:=m[y,x] END;
			END;
		END;
		RETURN RESULT
	END AssignIF;
	
	PROCEDURE ApplyMask*(CONST data: Tensor; CONST mask: BoolTensor; background:Datatype): Tensor;
	VAR i:SIZE;
	BEGIN
		(*ASSERT(DIM(data)=DIM(mask));
		ASSERT(LEN(data)=LEN(mask));*)
		(*IF (DIM(RESULT)=0) OR (LEN(RESULT)#LEN(data)) THEN NEW(RESULT, LEN(data)) END;*)
		IF (DIM(RESULT)=0) OR (LEN(RESULT)<LEN(mask)) THEN NEW(RESULT, LEN(mask)) END;
		IF DIM(data)>1 THEN
			FOR i:=0 TO MIN(LEN(data,0),LEN(mask,0))-1 DO
				RESULT[i,?]:= ApplyMask(data[i,?], mask[i,?],background);
			END;
		ELSE
			FOR i:=0 TO MIN(LEN(data,0),LEN(mask,0))-1 DO
				IF mask[i] THEN RESULT[i]:=data[i] ELSE RESULT[i]:=background END;
			END;
		END;
		RETURN RESULT
	END ApplyMask;

PROCEDURE JoinMasked*(CONST data,data1: Tensor; CONST mask: BoolTensor): Tensor;
	VAR i:SIZE;
	BEGIN
		ASSERT(DIM(data)=DIM(mask));
		ASSERT(LEN(data)=LEN(mask));
		IF (DIM(RESULT)#DIM(data)) OR (LEN(RESULT)#LEN(data)) THEN NEW(RESULT, LEN(data)) END;
		IF DIM(data)>1 THEN
			FOR i:=0 TO LEN(data,0)-1 DO
				RESULT[i,?]:= JoinMasked(data[i,?], data1[i,?], mask[i,?]);
			END;
		ELSE
			FOR i:=0 TO LEN(data,0)-1 DO
				IF mask[i] THEN RESULT[i]:=data[i] ELSE RESULT[i]:=data1[i] END;
			END;
		END;
		RETURN RESULT
	END JoinMasked;

	PROCEDURE SetMasked*(CONST data: Tensor; CONST mask: BoolTensor; value:Datatype): Tensor;
	VAR i:SIZE;
	BEGIN
		ASSERT(DIM(data)=DIM(mask));
		ASSERT(LEN(data)=LEN(mask));
		IF (DIM(RESULT)#DIM(data)) OR (LEN(RESULT)#LEN(data)) THEN NEW(RESULT, LEN(data)) END;
		IF DIM(data)>1 THEN
			FOR i:=0 TO LEN(data,0)-1 DO
				RESULT[i,?]:= SetMasked(data[i,?], mask[i,?],value);
			END;
		ELSE
			FOR i:=0 TO LEN(data,0)-1 DO
				IF mask[i] THEN RESULT[i]:=data[i] ELSE RESULT[i]:=value END;
			END;
		END;
		RETURN RESULT
	END SetMasked;

	PROCEDURE OutVector*(CONST  v: Vector );  
	VAR i: SIZE;
	BEGIN
		FOR i := 0 TO LEN( v,0 ) - 1 DO OutFloat( v[i], 7, 4, 0 );  END;  
		KernelLog.Ln;  
	END OutVector;  
	
	PROCEDURE OutVectorBool*( CONST v: ARRAY [*] OF BOOLEAN);  
	VAR i: SIZE;
	BEGIN
		FOR i := 0 TO LEN( v,0 ) - 1 DO IF v[i] THEN KernelLog.Char("+") ELSE KernelLog.Char("-"); END; END;  
		KernelLog.Ln;  
	END OutVectorBool;  
	
	PROCEDURE Out*(CONST t: ARRAY[?] OF Datatype);
	VAR i:SIZE;
	BEGIN
		IF DIM(t)>1 THEN
			FOR i:=0 TO LEN(t,0)-1 DO
				Out(t[i,?]);
			END;
			KernelLog.Ln;
		ELSE
			OutVector(t)
		END;
	END Out;
	
	PROCEDURE OutInt*(CONST t: ARRAY[?] OF SIGNED32);
	VAR i:SIZE;
	BEGIN
		IF DIM(t)>1 THEN
			FOR i:=0 TO LEN(t,0)-1 DO
				OutInt(t[i,?]);
			END;
			KernelLog.Ln;
		ELSE
			FOR i:=0 TO LEN(t,0)-1 DO
				KernelLog.Int(t[i],6);
			END;
		END;
	END OutInt;

	PROCEDURE OutMatrix*( CONST m: Matrix );  
	VAR i: SIZE;
	BEGIN
		FOR i := 0 TO LEN( m,0 ) - 1 DO OutVector( m[i] );  END;  
		KernelLog.Ln;  
	END OutMatrix;  
	
	PROCEDURE OutMatrixBool*( CONST m: ARRAY [*,*] OF BOOLEAN);  
	VAR i: SIZE;
	BEGIN
		FOR i := 0 TO LEN( m,0 ) - 1 DO OutVectorBool( m[i] );  END;  
		KernelLog.Ln;  
	END OutMatrixBool;  

	PROCEDURE OutLn*( CONST m: Matrix );  
	BEGIN 
		KernelLog.Ln;  
	END OutLn;  

	PROCEDURE OutFloat*( x: FLOAT64;  n, f, D: SIGNED32 );  
	VAR s: ARRAY 64 OF CHAR;  
	BEGIN 
		Strings.FloatToStr( x, n, f, D, s );  KernelLog.String( s );  
	END OutFloat;  
	
	PROCEDURE OutComplex*(c: ComplexMathL.COMPLEXTYPE; n, f, D: SIGNED32);
	BEGIN
		OutFloat(c.re,n,f,D); OutFloat(c.im,n,f,D); KernelLog.String("i"); KernelLog.Ln;
	END OutComplex;
	
	PROCEDURE OutComplexVector*(CONST C: ARRAY [*] OF ComplexMathL. COMPLEXTYPE);
	VAR i:SIZE;
	BEGIN
		FOR i:=0 TO LEN(C,0)-1 DO
			OutComplex(C[i], 10,6,0);
		END;
	END OutComplexVector;
	
	PROCEDURE Print*(w:Streams.Writer; CONST t: ARRAY[?] OF Datatype; n, f, D: SIGNED32 );
	VAR i:SIZE;
	BEGIN
		IF DIM(t)>1 THEN
			FOR i:=0 TO LEN(t,0)-1 DO
				Print(w, t[i,?],n,f,D);
			END;
			w.Ln;
		ELSE
			FOR i:=0 TO LEN(t,0)-1 DO
				WriteFloat(w,t[i],n,f,D);
			END;
			w.Ln;
		END;
	END Print;
	
	PROCEDURE PrintInt*(w:Streams.Writer; CONST t: ARRAY[?] OF SIGNED32);
	VAR i:SIZE;
	BEGIN
		IF DIM(t)>1 THEN
			FOR i:=0 TO LEN(t,0)-1 DO
				PrintInt(w, t[i,?]);
			END;
			w.Ln;
		ELSE
			FOR i:=0 TO LEN(t,0)-1 DO
				w.Int(t[i],6);
			END;
			w.Ln;
		END;
	END PrintInt;
	
	PROCEDURE PrintSize*(w:Streams.Writer; CONST t: ARRAY[?] OF SIZE);
	VAR i:SIZE;
	BEGIN
		IF DIM(t)>1 THEN
			FOR i:=0 TO LEN(t,0)-1 DO
				PrintSize(w, t[i,?]);
			END;
			w.Ln;
		ELSE
			FOR i:=0 TO LEN(t,0)-1 DO
				w.Int(t[i],6);
			END;
			w.Ln;
		END;
	END PrintSize;
	
	PROCEDURE WriteFloat*(W:Streams.Writer; x: FLOAT64;  n, f, D: SIGNED32 ); (* call Update() after writing *)
	VAR s: ARRAY 64 OF CHAR;  
	BEGIN 
		Strings.FloatToStr( x, n, f, D, s );  W.String( s );  (*?   spaces ...? *)
	END WriteFloat;
	
	PROCEDURE WriteArray*(W:Streams.Writer; CONST t: ARRAY [?] OF Datatype; n,f,D:SIGNED32);(* call Update() after writing *)
	VAR len: ARRAY [*] OF SIZE; i:SIZE;
	BEGIN
		ASSERT(DIM(t)>0);
		len:=LEN(t);
		IF  DIM(t)=1 THEN 
			FOR i:=0 TO LEN(t,0)-1 DO WriteFloat(W,t[i],n,f,D) END;
			W.Ln; 
		ELSE
			FOR i:=0 TO LEN(t,0)-1 DO WriteArray(W, t[i,?],n,f,D) END;
			W.Ln; 
		END;
	END WriteArray;
	
	(*convert a tensor of DATATYPE (longreal) to datatype FLOAT32*)
	PROCEDURE MatrixToFloat*(CONST m: ARRAY[?] OF Datatype; VAR ret: ARRAY[?] OF FLOAT32);
	VAR
		i: SIZE;
	BEGIN
		ASSERT(DIM(m)=DIM(ret));
		IF DIM(m)=1 THEN
			ASSERT(LEN(m,0)=LEN(ret,0));
			FOR i:=0 TO LEN(m,0)-1 DO
				ret[i]:=FLOAT32(m[i]);
			END;
		ELSE
			MatrixToFloat(m[0,?],ret[0,?]);
		END;
	END MatrixToFloat;
	
	(*convert a tensor or FLOAT32 to DATATYPE*)
	PROCEDURE FloatToMatrix*(CONST m: ARRAY[?] OF FLOAT32 ; VAR ret: ARRAY[?] OF Datatype);
	VAR
		i: SIZE;
	BEGIN
		ASSERT(DIM(m)=DIM(ret));
		IF DIM(m)=1 THEN
			ASSERT(LEN(m,0)=LEN(ret,0));
			FOR i:=0 TO LEN(m,0)-1 DO
				ret[i]:=m[i];
			END;
		ELSE
			FloatToMatrix(m[0,?], ret[0,?]);
		END;
	END FloatToMatrix;
	
	(* raw *)
	PROCEDURE WriteLR*(W:Streams.Writer; CONST t: ARRAY [?] OF Datatype);
	VAR i:SIZE;
	BEGIN
		ASSERT(DIM(t)>0);
		IF  DIM(t)=1 THEN 
			FOR i:=0 TO LEN(t,0)-1 DO W.RawLReal(t[i]) END;
		ELSE
			FOR i:=0 TO LEN(t,0)-1 DO WriteLR(W, t[i,?]) END;
		END;
	END WriteLR;
	
	PROCEDURE WriteR*(W:Streams.Writer; CONST t: ARRAY [?] OF FLOAT32);
	VAR i:SIZE;
	BEGIN
		ASSERT(DIM(t)>0);
		IF  DIM(t)=1 THEN 
			FOR i:=0 TO LEN(t,0)-1 DO W.RawReal(t[i]) END;
		ELSE
			FOR i:=0 TO LEN(t,0)-1 DO WriteR(W, t[i,?]) END;
		END;
	END WriteR;
		
	PROCEDURE WriteRasSR*(W:Streams.Writer; CONST t: ARRAY [?] OF FLOAT32);
	(*VAR i:SIZE; sr: Shortreal.SHORTREAL;
	BEGIN
		ASSERT(DIM(t)>0);
		IF  DIM(t)=1 THEN 
			FOR i:=0 TO LEN(t,0)-1 DO 
				sr:=t[i];
				W.Bytes(SYSTEM.VAL( Bytes2,  sr), 0, 2); (*W.RawLReal(t[i])*) 
			END;
		ELSE
			FOR i:=0 TO LEN(t,0)-1 DO WriteLR(W, t[i,?]) END;
		END;
		*)
	END WriteRasSR;

	PROCEDURE WriteUInt8*(W:Streams.Writer; CONST t: ARRAY [?] OF SIGNED16);
	VAR i:SIZE;
	BEGIN
		ASSERT(DIM(t)>0);
		IF  DIM(t)=1 THEN 
			FOR i:=0 TO LEN(t,0)-1 DO W.Char(CHR(t[i])) END;
		ELSE
			FOR i:=0 TO LEN(t,0)-1 DO WriteUInt8(W, t[i,?]) END;
		END;
	END WriteUInt8;
	
	(* raw *)
	PROCEDURE WriteInt*(W:Streams.Writer; CONST t: ARRAY [?] OF SIGNED16);
	VAR i:SIZE;
	BEGIN
		ASSERT(DIM(t)>0);
		IF  DIM(t)=1 THEN 
			FOR i:=0 TO LEN(t,0)-1 DO W.RawInt(t[i]) END;
		ELSE
			FOR i:=0 TO LEN(t,0)-1 DO WriteInt(W, t[i,?]) END;
		END;
	END WriteInt;

	(* raw *)
	PROCEDURE WriteLInt*(W:Streams.Writer; CONST t: ARRAY [?] OF SIGNED32);
	VAR i:SIZE;
	BEGIN
		ASSERT(DIM(t)>0);
		IF  DIM(t)=1 THEN 
			FOR i:=0 TO LEN(t,0)-1 DO W.RawLInt(t[i]) END;
		ELSE
			FOR i:=0 TO LEN(t,0)-1 DO WriteLInt(W, t[i,?]) END;
		END;
	END WriteLInt;
	
		(* raw *)
	PROCEDURE WriteSize*(W:Streams.Writer; CONST t: ARRAY [?] OF SIZE);
	VAR i:SIZE;
	BEGIN
		ASSERT(DIM(t)>0);
		IF  DIM(t)=1 THEN 
			FOR i:=0 TO LEN(t,0)-1 DO W.RawHInt(t[i]) END;
		ELSE
			FOR i:=0 TO LEN(t,0)-1 DO WriteSize(W, t[i,?]) END;
		END;
	END WriteSize;
	
		(* raw *)
	(* todo: packed storage of bits
	PROCEDURE WriteBool*(W:Streams.Writer; CONST t: ARRAY [?] OF BOOLEAN);
	VAR i:SIZE;
	BEGIN
		ASSERT(DIM(t)>0);
		IF  DIM(t)=1 THEN 
			FOR i:=0 TO LEN(t,0)-1 DO W.RawLInt(t[i]) END;
		ELSE
			FOR i:=0 TO LEN(t,0)-1 DO WriteLInt(W, t[i,?]) END;
		END;
	END WriteBool;
	*)
	
	PROCEDURE WriteHeader*(W: Streams.Writer; datatype: SIGNED32; CONST len: ARRAY [*] OF SIZE);
	VAR
		i: SIZE;
		comment:ARRAY 16 OF CHAR;
	BEGIN
		W.String("TENSOR 2.0 ");
		IF(datatype=DatatypeLR) THEN W.String("LR ");
		ELSIF(datatype=DatatypeR) THEN W.String("R ");
		ELSIF(datatype=DatatypeSR) THEN W.String("SR ");
		ELSIF datatype=DatatypeInt THEN W.String("Int ");
		ELSIF datatype=DatatypeLInt THEN W.String("LInt ");
		ELSIF datatype=DatatypeUInt8 THEN W.String("UInt8 ");
		ELSIF datatype=DatatypeHInt THEN W.String("HInt ");
		ELSE
			HALT(202);
		END;
		comment:=""; W.String(comment); (*! tbd*)
		W.Ln;
		W.Int(LEN(len,0),0);
		FOR i:=0 TO LEN(len,0)-1 DO
			W.Char(" ");
			W.Int(len[i],0);
		END;
		W.Ln;
		W.Update;
	END WriteHeader;
	
	PROCEDURE StoreLR*(W:Streams.Writer; CONST t: ARRAY [?] OF Datatype);
	BEGIN
		WriteHeader(W, DatatypeLR, LEN(t));
		IF DIM(t)>0 THEN WriteLR(W,t) END;
		W.Update;
	END StoreLR;

	PROCEDURE StoreR*(W:Streams.Writer; CONST t: ARRAY [?] OF FLOAT32);
	BEGIN
		WriteHeader(W, DatatypeR, LEN(t));
		IF DIM(t)>0 THEN WriteR(W,t) END;
		W.Update;
	END StoreR;
	
	PROCEDURE StoreRasSR*(W:Streams.Writer; CONST t: ARRAY [?] OF FLOAT32);
	BEGIN
		WriteHeader(W, DatatypeSR, LEN(t));
		IF DIM(t)>0 THEN WriteRasSR(W,t) END;
		W.Update;
	END StoreRasSR;
	
	PROCEDURE StoreInt*(W:Streams.Writer; CONST t: ARRAY [?] OF SIGNED16);
	BEGIN
		WriteHeader(W,DatatypeInt, LEN(t));
		IF DIM(t)>0 THEN WriteInt(W,t) END;
		W.Update;
	END StoreInt;
	
	PROCEDURE StoreLInt*(W:Streams.Writer; CONST t: ARRAY [?] OF SIGNED32);
	BEGIN
		WriteHeader(W,DatatypeLInt, LEN(t));
		IF DIM(t)>0 THEN WriteLInt(W,t) END;
		W.Update;
	END StoreLInt;

	
	PROCEDURE StoreSize*(W:Streams.Writer; CONST t: ARRAY [?] OF SIZE);
	BEGIN
		WriteHeader(W,DatatypeSize, LEN(t));
		IF DIM(t)>0 THEN WriteSize(W,t) END;
		W.Update;
	END StoreSize;
	
	PROCEDURE ReadLR*(R:Streams.Reader; VAR t: ARRAY [?] OF Datatype);
	VAR i:SIZE;
	BEGIN
		ASSERT(DIM(t)>0);
		IF  DIM(t)=1 THEN 
			FOR i:=0 TO LEN(t,0)-1 DO R.RawLReal(t[i]) END;
		ELSE
			FOR i:=0 TO LEN(t,0)-1 DO ReadLR(R, t[i,?]) END;
		END;
	END ReadLR;
	
	PROCEDURE ReadR*(R:Streams.Reader; VAR t: ARRAY [?] OF FLOAT32);
	VAR i:SIZE;
	BEGIN
		ASSERT(DIM(t)>0);
		IF  DIM(t)=1 THEN 
			FOR i:=0 TO LEN(t,0)-1 DO R.RawReal(t[i]) END;
		ELSE
			FOR i:=0 TO LEN(t,0)-1 DO ReadR(R, t[i,?]) END;
		END;
	END ReadR;
	
	PROCEDURE ReadRfromSR*(R:Streams.Reader; VAR t: ARRAY [?] OF FLOAT32);
	(*VAR i:SIZE; sr: Shortreal.SHORTREAL; b2: ARRAY 2 OF CHAR;
	BEGIN
		ASSERT(DIM(t)>0);
		IF  DIM(t)=1 THEN 
			FOR i:=0 TO LEN(t,0)-1 DO R.Bytes(b2,0,2); t[i]:= LONG(LONG(SYSTEM.VAL(Shortreal.SHORTREAL,b2))) (*R.RawLReal(t[i])*) END;
		ELSE
			FOR i:=0 TO LEN(t,0)-1 DO ReadLR(R, t[i,?]) END;
		END;*)
	END ReadRfromSR;

	PROCEDURE ReadUInt8*(R:Streams.Reader; VAR t: ARRAY [?] OF SIGNED16);
	VAR i:SIZE; c:CHAR;
	BEGIN
		ASSERT(DIM(t)>0);
		IF  DIM(t)=1 THEN 
			FOR i:=0 TO LEN(t,0)-1 DO R.Char(c); t[i]:=ORD(c) END;
		ELSE
			FOR i:=0 TO LEN(t,0)-1 DO ReadUInt8(R, t[i,?]) END;
		END;
	END ReadUInt8;
	
	PROCEDURE ReadInt*(R:Streams.Reader; VAR t: ARRAY [?] OF SIGNED16);
	VAR i:SIZE;
	BEGIN
		ASSERT(DIM(t)>0);
		IF  DIM(t)=1 THEN 
			FOR i:=0 TO LEN(t,0)-1 DO R.RawInt(t[i]) END;
		ELSE
			FOR i:=0 TO LEN(t,0)-1 DO ReadInt(R, t[i,?]) END;
		END;
	END ReadInt;
	
	PROCEDURE ReadLInt*(R:Streams.Reader; VAR t: ARRAY [?] OF SIGNED32);
	VAR i:SIZE;
	BEGIN
		ASSERT(DIM(t)>0);
		IF  DIM(t)=1 THEN 
			FOR i:=0 TO LEN(t,0)-1 DO R.RawLInt(t[i]) END;
		ELSE
			FOR i:=0 TO LEN(t,0)-1 DO ReadLInt(R, t[i,?]) END;
		END;
	END ReadLInt;

	PROCEDURE ReadSize*(R:Streams.Reader; VAR t: ARRAY [?] OF SIZE);
	VAR i:SIZE; h:SIGNED64;
	BEGIN
		ASSERT(DIM(t)>0);
		IF  DIM(t)=1 THEN 
			FOR i:=0 TO LEN(t,0)-1 DO R.RawHInt(h); t[i]:=SHORT(h) END; (* compiler problem with R.RawHInt(t[i])  ?*)
		ELSE
			FOR i:=0 TO LEN(t,0)-1 DO ReadSize(R, t[i,?]) END;
		END;
	END ReadSize;

	
	PROCEDURE GetSizeVectorV1(r: Streams.Reader): ARRAY [*] OF SIGNED32;
	VAR 
		i, k:SIGNED32;
		lenL: ARRAY [*] OF SIGNED32;
	BEGIN
		IF r.GetInteger(k,FALSE) THEN 
			NEW(lenL,k);
			FOR i:=0 TO k-1 DO 
				IF r.GetInteger(lenL[i],FALSE) THEN ELSE HALT(201); END;
			END;
		ELSE HALT(200)
		END;
		RETURN lenL
	END GetSizeVectorV1;
	
	PROCEDURE GetSizeVectorV2(r: Streams.Reader): ARRAY [*] OF SIZE;
	VAR 
		i,j, k:SIGNED32;
	BEGIN
		IF r.GetInteger(k,FALSE) THEN 
			NEW(RESULT,k);
			FOR i:=0 TO k-1 DO 
				IF r.GetInteger(j,FALSE) THEN
					RESULT[i]:=j 
				ELSE HALT(201); 
				END;
			END;
		ELSE HALT(200)
		END;
		RETURN RESULT
	END GetSizeVectorV2;
	
	(*parse header of .MtA files storing an ARRAY [?] OF Datatype, or ARRAY [*{*}] OF Datatype*)
	PROCEDURE ParseHeader*(r:Streams.Reader; VAR version, datatype: SIGNED32; VAR len: ARRAY [*] OF SIZE);
	VAR 
		i, j, k:SIGNED32;
		dontcare: BOOLEAN;
		structure, datatypeString, versionString, comment: ARRAY 8 OF CHAR;
	BEGIN
		IF r.GetString(structure) & r.GetString(versionString) &	r.GetString(datatypeString) THEN
			ASSERT(structure="TENSOR",202);
			IF versionString="1.0" THEN version:=1;
			ELSIF versionString="2.0" THEN version:=2;
			ELSE HALT(200)
			END;
			IF datatypeString='LR' THEN	datatype:=DatatypeLR;
			ELSIF datatypeString='R' THEN	datatype:=DatatypeR;
			ELSIF datatypeString='SR' THEN	datatype:=DatatypeSR;
			ELSIF datatypeString='LInt' THEN	datatype:=DatatypeLInt;
			ELSIF datatypeString='Int' THEN	datatype:=DatatypeInt;
			ELSIF (datatypeString='C') OR (datatypeString='UInt8') THEN datatype:=DatatypeUInt8
			ELSIF (datatypeString='HInt') THEN datatype:=DatatypeHInt
			ELSE HALT(202);
			END;
			r.Ln(comment);
			
			IF version=1 THEN len:=GetSizeVectorV1(r);
			ELSIF version=2 THEN len:=GetSizeVectorV2(r);
			ELSE HALT(200);
			END;
		END;
		r.SkipLn;
	END ParseHeader;
	
	(* derive structure from header*)
	
	PROCEDURE Load*(R:Streams.Reader): ARRAY [?] OF Datatype;
		VAR  len: ARRAY [*] OF SIZE;
		version, datatype:SIGNED32;	
		pos:Streams.Position;
	BEGIN
		pos:=R.Pos();
		ParseHeader(R,version, datatype,len);
		IF R.CanSetPos() THEN R.SetPos(pos) ELSE HALT(200) END;
		IF datatype=DatatypeLR THEN RETURN LoadLR(R)
		ELSIF datatype=DatatypeR THEN RETURN LoadR(R)
		(*ELSIF datatype=DatatypeSR THEN RETURN LoadSR(R)*)
		ELSIF datatype=DatatypeLInt THEN RETURN LoadLInt(R)
		ELSIF datatype=DatatypeInt THEN RETURN LoadInt(R)
		ELSIF datatype=DatatypeSize THEN RETURN LoadSize(R)
		ELSIF datatype=DatatypeUInt8 THEN RETURN LoadUInt8(R)
		END;
	END Load;
	
	PROCEDURE LoadLR*(R:Streams.Reader): ARRAY [?] OF Datatype;
	VAR  len: ARRAY [*] OF SIZE;
		version, datatype:SIGNED32;
	BEGIN
		ParseHeader(R,version, datatype,len);
		ASSERT(datatype=DatatypeLR);
		IF (DIM(RESULT)#LEN(len,0)) OR (LEN(RESULT)#len) THEN NEW(RESULT,len) END;
		IF DIM(RESULT)>0 THEN ReadLR(R,RESULT) END;
		RETURN RESULT
	END LoadLR;

	PROCEDURE LoadR*(R:Streams.Reader): ARRAY [?] OF FLOAT32;
	VAR  len: ARRAY [*] OF SIZE;
		version, datatype:SIGNED32;
	BEGIN
		ParseHeader(R,version, datatype,len);
		ASSERT(datatype=DatatypeR);
		IF (DIM(RESULT)#LEN(len,0)) OR (LEN(RESULT)#len) THEN NEW(RESULT,len) END;
		IF DIM(RESULT)>0 THEN ReadR(R,RESULT) END;
		RETURN RESULT
	END LoadR;


	PROCEDURE LoadRfromSR*(R:Streams.Reader): ARRAY [?] OF FLOAT32;
	VAR  len: ARRAY [*] OF SIZE;
		version, datatype:SIGNED32;
	BEGIN
		ParseHeader(R,version, datatype,len);
		ASSERT(datatype=DatatypeSR);
		IF (DIM(RESULT)#LEN(len,0)) OR (LEN(RESULT)#len) THEN NEW(RESULT,len) END;
		IF DIM(RESULT)>0 THEN ReadRfromSR(R,RESULT) END;
		RETURN RESULT
	END LoadRfromSR;
	
	(* derive structure from header*)
	PROCEDURE LoadInt*(R:Streams.Reader): ARRAY [?] OF SIGNED16;
	VAR  len: ARRAY [*] OF SIZE;
		version, datatype: SIGNED32;
	BEGIN
		ParseHeader(R,version, datatype,len);
		ASSERT(datatype=DatatypeInt);
		IF (DIM(RESULT)#LEN (len,0)) OR (LEN(RESULT)#len) THEN NEW(RESULT,len) END;
		IF DIM(RESULT)>0 THEN ReadInt(R,RESULT) END;
		RETURN RESULT
	END LoadInt;
	
(* derive structure from header*)
	PROCEDURE LoadLInt*(R:Streams.Reader): ARRAY [?] OF SIGNED32;
	VAR  len: ARRAY [*] OF SIZE;
		version, datatype: SIGNED32;
	BEGIN
		ParseHeader(R,version, datatype,len);
		ASSERT(datatype=DatatypeLInt);
		IF (DIM(RESULT)#LEN (len,0)) OR (LEN(RESULT)#len) THEN NEW(RESULT,len) END;
		IF DIM(RESULT)>0 THEN ReadLInt(R,RESULT) END;
		RETURN RESULT
	END LoadLInt;
	
	(* derive structure from header*)
	PROCEDURE LoadSize*(R:Streams.Reader): ARRAY [?] OF SIZE;
	VAR  len: ARRAY [*] OF SIZE;
		resultLInt:ARRAY [*] OF SIGNED32;
		version, datatype: SIGNED32;
	BEGIN
		ParseHeader(R,version, datatype,len);
		IF (version=1)&(datatype=DatatypeLInt) THEN datatype:=DatatypeSize END;(*!bug fix for  2018.4.27 to about 2018.8.15*) 
		IF LEN(len,0)>0 THEN 	
			IF datatype=DatatypeSize THEN 
				IF (DIM(RESULT)#LEN(len,0)) OR (LEN(RESULT)#len) THEN NEW(RESULT,len) END;
				ReadSize(R,RESULT) 
			ELSIF datatype=DatatypeLInt THEN 
				IF (DIM(resultLInt)#LEN (len,0)) OR (LEN(resultLInt)#len) THEN NEW(resultLInt,len) END;
				ReadLInt(R,resultLInt); 
				RESULT:=resultLInt
			END;
		END;
		RETURN RESULT
	END LoadSize;

(* derive structure from header*)
	PROCEDURE LoadUInt8*(R:Streams.Reader): ARRAY [?] OF SIGNED16;
	VAR  len: ARRAY [*] OF SIZE;
		version, datatype: SIGNED32;
	BEGIN
		ParseHeader(R,version, datatype,len);
		ASSERT(datatype=DatatypeUInt8);
		IF (DIM(RESULT)#LEN (len,0)) OR (LEN(RESULT)#len) THEN NEW(RESULT,len) END;
		ReadUInt8(R,RESULT);
		RETURN RESULT
	END LoadUInt8;

	
(*
	PROCEDURE Test*(context:Commands.Context);
	VAR a,b: ARRAY [?] OF FLOAT64; len: ARRAY [*] OF SIGNED32; f:Files.File; w:Files.Writer; r:Files.Reader;
	BEGIN
		len:=[2,3,4];
		NEW(a,len);
		a:=[[[0,1,2,3],[4,5,6,7],[8,9,10,11]],[[0,0,1,1],[2,2,3,3],[4,4,5,5]]];
		f:=Files.New("Test.ten");
		Files.OpenWriter(w,f,0);
		StoreLR(w,a);
		Files.Register(f);
		Files.OpenReader(r,f,0);
		b:=LoadLR(r);
		context.out.Float(SUM(b),14); context.out.Ln; context.out.Update;
	END Test;
	*)

	PROCEDURE sign(x:Datatype ): Datatype; 
	BEGIN 
		IF x>=0 THEN RETURN 1.0
		ELSE RETURN -1.0
		END;
	END sign;  

	PROCEDURE eps*( ): FLOAT32;   (*binary: last mantissa of FLOAT32 number*)
	VAR x, y: FLOAT32;  
	BEGIN 
		x := 1;  
		LOOP 
			y := 1 + x;  
			IF y = 1 THEN RETURN 2 * x END;  
			x := x / 2;  
		END;  
	END eps;  

	PROCEDURE epsL*( ): FLOAT64;   (*binary: last mantissa of FLOAT64 number*)
	VAR x, y: FLOAT64;  
	BEGIN 
		x := 1;  
		LOOP 
			y := 1 + x;  
			IF y = 1 THEN RETURN 2 * x END;  
			x := x / 2;  
		END;  
	END epsL;  

	PROCEDURE Set22*( a1, a2, b1, b2: MatrixBase.Datatype ): Matrix;  
	BEGIN 
		IF (LEN( RESULT, 0 ) # 2) OR (LEN( RESULT, 1 ) # 2) THEN NEW( RESULT, 2, 2 );  END;  
		RESULT[0, 0] := a1;  RESULT[0, 1] := a2;  RESULT[1, 0] := b1;  RESULT[1, 1] := b2;  
		RETURN RESULT
	END Set22;  

	PROCEDURE Set33*( a1, a2, a3, b1, b2, b3, c1, c2, c3: MatrixBase.Datatype ): Matrix;  
	BEGIN 
		IF (LEN( RESULT, 0 ) # 3) OR (LEN( RESULT, 1 ) # 3) THEN NEW( RESULT, 3, 3 );  END;  
		RESULT[0, 0] := a1;  RESULT[0, 1] := a2;  RESULT[0, 2] := a3;  RESULT[1, 0] := b1;  
		RESULT[1, 1] := b2;  RESULT[1, 2] := b3;  RESULT[2, 0] := c1;  RESULT[2, 1] := c2;  
		RESULT[2, 2] := c3;  RETURN RESULT
	END Set33;  

	PROCEDURE MaxAbs*( CONST m: Matrix ): Datatype;  
	BEGIN 
		RETURN MAX( MAX( m ), -MIN( m ) );   (*non-copying ABS(MAX(m))*)
	END MaxAbs;  

	PROCEDURE SumAbs*( CONST v: Vector ): Datatype;   (* useful because SUM(ABS(m)) leads to undesired allocation of temporary memory *)
	VAR sum: Datatype;  i: SIZE;
	BEGIN 
		sum := 0;  
		FOR i := 0 TO LEN( v,0 ) - 1 DO sum := sum + ABS( v[i] ) END;  
		RETURN sum
	END SumAbs;  
	
	PROCEDURE SizeMatch(CONST A,B: Matrix):SIGNED32;
	BEGIN
		IF (LEN(A,0)=LEN(B,0)) & (LEN(A,1)=LEN(B,1)) THEN RETURN Equal
		ELSIF (LEN(A,0)<=LEN(B,0)) & (LEN(A,1)<=LEN(B,1)) THEN RETURN Smaller
		ELSIF (LEN(A,0)>=LEN(B,0)) & (LEN(A,1)>=LEN(B,1)) THEN RETURN Larger
		ELSE RETURN NoFit
		END;
	END SizeMatch;

	PROCEDURE NewMatrix*(rows,cols:SIZE):Matrix;
	VAR m:Matrix;
	BEGIN
		NEW(m,rows,cols); RETURN m
	END NewMatrix;
	
	PROCEDURE GetVectorOrder*(CONST v:Vector; VAR sorted: Vector; VAR index: IntVector; ascending: BOOLEAN);
	VAR x: Datatype; i, ind:SIZE; done:BOOLEAN;
	BEGIN
		NEW(sorted,LEN(v,0));
		NEW(index,LEN(v,0));
		FOR i:=0 TO LEN(sorted,0)-1 DO index[i]:=i; sorted[i]:=v[i] END;
		WHILE ~done DO
			done:=TRUE;
			FOR i:=0 TO LEN(sorted,0)-2 DO
				IF (ascending &(sorted[i+1]<sorted[i])) OR (~ascending & (sorted[i+1]>sorted[i])) THEN 
					ind:=index[i]; index[i]:=index[i+1]; index[i+1]:=ind;
					x:=sorted[i]; sorted[i]:=sorted[i+1]; sorted[i+1]:=x; 
					done:=FALSE;
				END;
			END;
		END;
	END GetVectorOrder;
	
	(*naive neighbour sort, from high to low *)
	PROCEDURE GetDiagonalOrder*(CONST m:Matrix; VAR sorted: Vector; VAR index: IntVector; ascending: BOOLEAN);
	VAR i:SIZE;  v:Vector;
	BEGIN
		ASSERT(LEN(m,0)=LEN(m,1));
		NEW(v,LEN(m,0));
		FOR i:=0 TO LEN(v,0)-1 DO v[i]:=m[i,i] END;
		GetVectorOrder(v, sorted, index, ascending);
	END GetDiagonalOrder;
	
	PROCEDURE ReorderMatrix*(CONST m:Matrix; CONST order: IntVector; byRows: BOOLEAN): Matrix;
	VAR v: Vector; m1:Matrix; i:SIZE;
	BEGIN
		NEW(m1, LEN(m,0),LEN(m,1));
		IF byRows THEN
			NEW(v, LEN(m,1));
			FOR i:=0 TO LEN(m,0)-1 DO m1[i]:=m[order[i]] END;
		ELSE
			NEW(v,LEN(m,0)); 
			FOR i:=0 TO LEN(m,1)-1 DO m1[..,i]:=m[..,order[i]] END;
		END;
		RETURN m1
	END ReorderMatrix;
	
	(*
	PROCEDURE Test*;
	VAR a:Matrix; v: Vector; index:IntVector;
	BEGIN
		a:=[[1,0,0,0],[0,3,0,0],[0,0,2,0],[0,0,0,4]];
		
		(* reorder diagonal matrix in ascending order; could be done cheaper *)
		GetDiagonalOrder(a, v, index, TRUE);
		a:=ReorderMatrix(a,index,TRUE);  (* reorder rows *)
		a:=ReorderMatrix(a,index,FALSE); (* reorder columns *)
		OutMatrix(a);
		
		GetDiagonalOrder(a, v, index, FALSE);
		a:=ReorderMatrix(a,index,TRUE); 
		a:=ReorderMatrix(a,index,FALSE); 
		OutMatrix(a);
	END Test;
	
	*)
	
	PROCEDURE Test*;
	VAR t,t1:Tensor; len:ARRAY [*]OF SIZE; i:SIGNED32;
		f:Files.File; w:Files.Writer; r:Files.Reader;
	BEGIN
		NEW(len,0);
		NEW(t,len);
		f:=Files.New("");
		Files.OpenWriter(w,f,0);
		w.Int(0,0); w.Ln(); w.Update;
		Files.OpenReader(r,f,0);
		IF ~ r.GetInteger(i,FALSE) THEN HALT(200) END;
	END Test;

#IF TEST THEN
	TYPE Success=OBJECT END Success;
	PROCEDURE TEST*():ANY; VAR success:Success; BEGIN	NEW(success); RETURN success	END TEST;
#END


BEGIN
NEW(RG);
END MatrixUtilities.

MatrixUtilities.Test

fofPC.Compile \s * 
OFormatter.Format * MN * 
System.FreeDownTo MatrixUtilities ~

(*

From Wikipedia: F16C, Half-Float: 
Technical information

There are variants that convert four floating-point values in an XMM register or 8 floating-point values in a YMM register.

The instructions are abbreviations for "vector convert packed half to packed single" and vice versa:

    VCVTPH2PS xmmreg,xmmrm64  convert four half-precision floating point values in memory or the bottom half of an XMM register to four single-precision floating-point values in an XMM register.
    VCVTPH2PS ymmreg,xmmrm128  convert eight half-precision floating point values in memory or an XMM register (the bottom half of a YMM register) to eight single-precision floating-point values in a YMM register.
    VCVTPS2PH xmmrm64,xmmreg,imm8  convert four single-precision floating point values in an XMM register to half-precision floating-point values in memory or the bottom half an XMM register.
    VCVTPS2PH xmmrm128,ymmreg,imm8  convert eight single-precision floating point values in a YMM register to half-precision floating-point values in memory or an XMM register.

The 8-bit immediate argument to VCVTPS2PH selects the rounding mode. Values 0..4 select nearest, down, up, truncate, and the mode set in MXCSR.RC.

Support for these instructions is indicated by bit 29 of ECX after CPUID with EAX=1. 

*)