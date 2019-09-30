(**
	AUTHOR: Alexey Morozov
	PURPOSE: AMD64 half precision floating point runtime
*)
MODULE Shortreal;

IMPORT
	SYSTEM, FoxArrayBase;

CONST
	MinValue = 0xFBFF; (* minimal SHORTREAL value *)
	MaxValue = 0x7BFF; (* maximal SHORTREAL value *)

TYPE
	Real = FLOAT32;

	Vector4* = ARRAY [4] OF SHORTREAL;
	Matrix4* = ARRAY [4,4] OF SHORTREAL;

	OPERATOR "SHORT"*(x: Real): SHORTREAL;
	VAR y: SHORTREAL;
	BEGIN
		y.value := RealToShortreal(x); RETURN y;
	END "SHORT";

	OPERATOR "LONG"*(x: SHORTREAL): FLOAT32;
	BEGIN
		RETURN ShortrealToReal(x.value);
	END "LONG";

	OPERATOR ":="*(VAR y: FLOAT32; x: SHORTREAL);
	BEGIN
		y := ShortrealToReal(x.value);
	END ":=";

	OPERATOR "+"*(x, y: SHORTREAL): SHORTREAL;
	VAR z: SHORTREAL;
	BEGIN
		z.value := Add(x.value,y.value);
		RETURN z;
	END "+";

	OPERATOR "-"*(x, y: SHORTREAL): SHORTREAL;
	VAR z: SHORTREAL;
	BEGIN
		z.value := Sub(x.value,y.value);
		RETURN z;
	END "-";

	OPERATOR "*"*(x, y: SHORTREAL): SHORTREAL;
	VAR z: SHORTREAL;
	BEGIN
		z.value := Mul(x.value,y.value);
		RETURN z;
	END "*";

	OPERATOR "/"*(x, y: SHORTREAL): SHORTREAL;
	VAR z: SHORTREAL;
	BEGIN
		z.value := Div(x.value,y.value);
		RETURN z;
	END "/";

	OPERATOR "-"*(x: SHORTREAL): SHORTREAL;
	VAR y: SHORTREAL;
	BEGIN
		y.value := Negate(x.value);
		RETURN y;
	END "-";

	OPERATOR "ABS"*(x: SHORTREAL): SHORTREAL;
	VAR y: SHORTREAL;
	BEGIN
		y.value := Abs(x.value);
		RETURN y;
	END "ABS";

	OPERATOR "MIN"*(x, y: SHORTREAL): SHORTREAL;
	VAR z: SHORTREAL;
	BEGIN
		IF x < y THEN z.value := x.value;
		ELSE z.value := y.value;
		END;
		RETURN z;
	END "MIN";

	OPERATOR "MAX"*(x, y: SHORTREAL): SHORTREAL;
	VAR z: SHORTREAL;
	BEGIN
		IF x > y THEN z.value := x.value;
		ELSE z.value := y.value;
		END;
		RETURN z;
	END "MAX";

	OPERATOR "="*(x, y: SHORTREAL): BOOLEAN;
	BEGIN
		RETURN Equal(x.value,y.value);
	END "=";

	OPERATOR "#"*(x, y: SHORTREAL): BOOLEAN;
	BEGIN
		RETURN ~Equal(x.value,y.value);
	END "#";

	OPERATOR "<"*(x, y: SHORTREAL): BOOLEAN;
	BEGIN
		RETURN LessThan(x.value,y.value);
	END "<";

	OPERATOR "<="*(x, y: SHORTREAL): BOOLEAN;
	BEGIN
		RETURN ~GreaterThan(x.value,y.value);
	END "<=";

	OPERATOR ">"*(x, y: SHORTREAL): BOOLEAN;
	BEGIN
		RETURN GreaterThan(x.value,y.value);
	END ">";

	OPERATOR ">="*(x, y: SHORTREAL): BOOLEAN;
	BEGIN
		RETURN ~LessThan(x.value,y.value);
	END ">=";

	OPERATOR ":="*(VAR y: ARRAY {UNSAFE} [?] OF SHORTREAL; x: SHORTREAL);
	BEGIN
		FoxArrayBase.ApplyUnarySAOp(y,ADDRESS OF x,AssignScalarLoop);
	END ":=";

	OPERATOR "+"*(CONST x, y: ARRAY [?] OF SHORTREAL): ARRAY {UNSAFE} [?] OF SHORTREAL;
	BEGIN
		FoxArrayBase.ApplyBinaryAAAOp(RESULT,x,y,SIZEOF(SHORTREAL),AddLoop);
		RETURN RESULT;
	END "+";

	OPERATOR "+"*(CONST x: ARRAY [?] OF SHORTREAL; y: SHORTREAL): ARRAY {UNSAFE} [?] OF SHORTREAL;
	BEGIN
		FoxArrayBase.ApplyBinaryASAOp(RESULT,x,ADDRESS OF y,SIZEOF(SHORTREAL),AddScalarLoop);
		RETURN RESULT;
	END "+";

	OPERATOR "+"*(x: SHORTREAL; CONST y: ARRAY [?] OF SHORTREAL): ARRAY {UNSAFE} [?] OF SHORTREAL;
	BEGIN
		FoxArrayBase.ApplyBinaryASAOp(RESULT,y,ADDRESS OF x,SIZEOF(SHORTREAL),AddScalarLoop);
		RETURN RESULT;
	END "+";

	OPERATOR "-"*(CONST x, y: ARRAY [?] OF SHORTREAL): ARRAY {UNSAFE} [?] OF SHORTREAL;
	BEGIN
		FoxArrayBase.ApplyBinaryAAAOp(RESULT,x,y,SIZEOF(SHORTREAL),SubLoop);
		RETURN RESULT;
	END "-";

	OPERATOR "-"*(CONST x: ARRAY [?] OF SHORTREAL; y: SHORTREAL): ARRAY {UNSAFE} [?] OF SHORTREAL;
	BEGIN
		y.value := Negate(y.value);
		FoxArrayBase.ApplyBinaryASAOp(RESULT,x,ADDRESS OF y,SIZEOF(SHORTREAL),AddScalarLoop);
		RETURN RESULT;
	END "-";

	OPERATOR "-"*(x: SHORTREAL; CONST y: ARRAY [?] OF SHORTREAL): ARRAY {UNSAFE} [?] OF SHORTREAL;
	BEGIN
		FoxArrayBase.ApplyBinaryASAOp(RESULT,y,ADDRESS OF x,SIZEOF(SHORTREAL),ScalarSubLoop);
		RETURN RESULT;
	END "-";

	OPERATOR ".*"*(CONST x, y: ARRAY [?] OF SHORTREAL): ARRAY {UNSAFE} [?] OF SHORTREAL;
	BEGIN
		FoxArrayBase.ApplyBinaryAAAOp(RESULT,x,y,SIZEOF(SHORTREAL),MulLoop);
		RETURN RESULT;
	END ".*";

	OPERATOR ".*"*(CONST x: ARRAY [?] OF SHORTREAL; y: SHORTREAL): ARRAY {UNSAFE} [?] OF SHORTREAL;
	BEGIN
		FoxArrayBase.ApplyBinaryASAOp(RESULT,x,ADDRESS OF y,SIZEOF(SHORTREAL),MulScalarLoop);
		RETURN RESULT;
	END ".*";

	OPERATOR ".*"*(x: SHORTREAL; CONST y: ARRAY [?] OF SHORTREAL): ARRAY {UNSAFE} [?] OF SHORTREAL;
	BEGIN
		FoxArrayBase.ApplyBinaryASAOp(RESULT,y,ADDRESS OF x,SIZEOF(SHORTREAL),MulScalarLoop);
		RETURN RESULT;
	END ".*";

	OPERATOR "*"*(CONST x: ARRAY [?] OF SHORTREAL; y: SHORTREAL): ARRAY {UNSAFE} [?] OF SHORTREAL;
	BEGIN
		FoxArrayBase.ApplyBinaryASAOp(RESULT,x,ADDRESS OF y,SIZEOF(SHORTREAL),MulScalarLoop);
		RETURN RESULT;
	END "*";

	OPERATOR "*"*(x: SHORTREAL; CONST y: ARRAY [?] OF SHORTREAL): ARRAY {UNSAFE} [?] OF SHORTREAL;
	BEGIN
		FoxArrayBase.ApplyBinaryASAOp(RESULT,y,ADDRESS OF x,SIZEOF(SHORTREAL),MulScalarLoop);
		RETURN RESULT;
	END "*";

	OPERATOR "./"*(CONST x, y: ARRAY [?] OF SHORTREAL): ARRAY {UNSAFE} [?] OF SHORTREAL;
	BEGIN
		FoxArrayBase.ApplyBinaryAAAOp(RESULT,x,y,SIZEOF(SHORTREAL),DivLoop);
		RETURN RESULT;
	END "./";

	OPERATOR "./"*(CONST x: ARRAY [?] OF SHORTREAL; y: SHORTREAL): ARRAY {UNSAFE} [?] OF SHORTREAL;
	BEGIN
		FoxArrayBase.ApplyBinaryASAOp(RESULT,x,ADDRESS OF y,SIZEOF(SHORTREAL),DivScalarLoop);
		RETURN RESULT;
	END "./";

	OPERATOR "./"*(x: SHORTREAL; CONST y: ARRAY [?] OF SHORTREAL): ARRAY {UNSAFE} [?] OF SHORTREAL;
	BEGIN
		FoxArrayBase.ApplyBinaryASAOp(RESULT,y,ADDRESS OF x,SIZEOF(SHORTREAL),ScalarDivLoop);
		RETURN RESULT;
	END "./";

	OPERATOR "/"*(CONST x: ARRAY [?] OF SHORTREAL; y: SHORTREAL): ARRAY {UNSAFE} [?] OF SHORTREAL;
	BEGIN
		FoxArrayBase.ApplyBinaryASAOp(RESULT,x,ADDRESS OF y,SIZEOF(SHORTREAL),DivScalarLoop);
		RETURN RESULT;
	END "/";

	OPERATOR "+*"*(CONST x, y: ARRAY [?] OF SHORTREAL): FLOAT32;
	VAR acc: FLOAT32;
	BEGIN
		acc := 0;
		FoxArrayBase.ApplyBinaryAASOp(ADDRESSOF(acc),x,y,InnerProdLoop);
		RETURN acc;
	END "+*";

	OPERATOR "*"*(CONST x, y: ARRAY [*,*] OF SHORTREAL): ARRAY {UNSAFE} [*,*] OF SHORTREAL;
	BEGIN
		FoxArrayBase.ApplyMatMulLoop(ADDRESS OF RESULT,ADDRESS OF x,ADDRESS OF y,SIZEOF(SHORTREAL),MatMulLoop,FALSE,NIL);
		RETURN RESULT;
	END "*";

	OPERATOR "="*(CONST x, y: ARRAY [?] OF SHORTREAL): BOOLEAN;
	BEGIN
		RETURN FoxArrayBase.ApplyBinaryAABOp(x,y,EqualLoop,FALSE);
	END "=";

	OPERATOR "<"*(CONST x, y: ARRAY [?] OF SHORTREAL): BOOLEAN;
	BEGIN
		RETURN FoxArrayBase.ApplyBinaryAABOp(x,y,LessThanLoop,FALSE);
	END "<";

	OPERATOR "<="*(CONST x, y: ARRAY [?] OF SHORTREAL): BOOLEAN;
	BEGIN
		RETURN ~FoxArrayBase.ApplyBinaryAABOp(x,y,GreaterThanLoop,FALSE);
	END "<=";

	OPERATOR ">"*(CONST x, y: ARRAY [?] OF SHORTREAL): BOOLEAN;
	BEGIN
		RETURN FoxArrayBase.ApplyBinaryAABOp(x,y,GreaterThanLoop,FALSE);
	END ">";

	OPERATOR ">="*(CONST x, y: ARRAY [?] OF SHORTREAL): BOOLEAN;
	BEGIN
		RETURN ~FoxArrayBase.ApplyBinaryAABOp(x,y,LessThanLoop,FALSE);
	END ">=";

	OPERATOR ".="*(CONST x, y: ARRAY [?] OF SHORTREAL): ARRAY {UNSAFE} [?] OF BOOLEAN;
	BEGIN
		FoxArrayBase.ApplyBinaryAAAOp(RESULT,x,y,SIZEOF(BOOLEAN),EwEqualLoop);
		RETURN RESULT;
	END ".=";

	OPERATOR ".<"*(CONST x, y: ARRAY [?] OF SHORTREAL): ARRAY {UNSAFE} [?] OF BOOLEAN;
	BEGIN
		FoxArrayBase.ApplyBinaryAAAOp(RESULT,x,y,SIZEOF(BOOLEAN),EwLessThanLoop);
		RETURN RESULT;
	END ".<";

	OPERATOR ".<="*(CONST x, y: ARRAY [?] OF SHORTREAL): ARRAY {UNSAFE} [?] OF BOOLEAN;
	BEGIN
		FoxArrayBase.ApplyBinaryAAAOp(RESULT,x,y,SIZEOF(BOOLEAN),EwLessOrEqualThanLoop);
		RETURN RESULT;
	END ".<=";

	OPERATOR ".>"*(CONST x, y: ARRAY [?] OF SHORTREAL): ARRAY {UNSAFE} [?] OF BOOLEAN;
	BEGIN
		FoxArrayBase.ApplyBinaryAAAOp(RESULT,x,y,SIZEOF(BOOLEAN),EwGreaterThanLoop);
		RETURN RESULT;
	END ".>";

	OPERATOR ".>="*(CONST x, y: ARRAY [?] OF SHORTREAL): ARRAY {UNSAFE} [?] OF BOOLEAN;
	BEGIN
		FoxArrayBase.ApplyBinaryAAAOp(RESULT,x,y,SIZEOF(BOOLEAN),EwGreaterOrEqualThanLoop);
		RETURN RESULT;
	END ".>=";

	OPERATOR "+"*(CONST x, y: Vector4): Vector4;
	BEGIN
		CODE
			MOV RAX, [RBP+x]
			MOV RBX, [RBP+y]
			MOV RCX, [RBP+RESULT]
			MOVQ XMM0, [RAX]
			MOVQ XMM1, [RBX]
			VCVTPH2PS XMM0, XMM0
			VCVTPH2PS XMM1, XMM1
			ADDPS XMM0, XMM1
			VCVTPS2PH XMM0, XMM0, 0
			MOVQ [RCX], XMM0
		END;
		RETURN RESULT;
	END "+";

	OPERATOR "+"*(CONST x: Vector4; y: SHORTREAL): Vector4;
	BEGIN
		CODE
			MOV RAX, [RBP+x]
			MOV BX, [RBP+y]
			MOV RCX, [RBP+RESULT]
			MOVQ XMM0, [RAX]
			MOVD XMM1, EBX
			VCVTPH2PS XMM0, XMM0
			VCVTPH2PS XMM1, XMM1
			SHUFPS XMM1, XMM1, 0
			ADDPS XMM0, XMM1
			VCVTPS2PH XMM0, XMM0, 0
			MOVQ [RCX], XMM0
		END;
		RETURN RESULT;
	END "+";

	OPERATOR "-"*(CONST x, y: Vector4): Vector4;
	BEGIN
		CODE
			MOV RAX, [RBP+x]
			MOV RBX, [RBP+y]
			MOV RCX, [RBP+RESULT]
			MOVQ XMM0, [RAX]
			MOVQ XMM1, [RBX]
			VCVTPH2PS XMM0, XMM0
			VCVTPH2PS XMM1, XMM1
			SUBPS XMM0, XMM1
			VCVTPS2PH XMM0, XMM0, 0
			MOVQ [RCX], XMM0
		END;
		RETURN RESULT;
	END "-";

	OPERATOR "-"*(CONST x: Vector4; y: SHORTREAL): Vector4;
	BEGIN
		CODE
			MOV RAX, [RBP+x]
			MOV BX, [RBP+y]
			MOV RCX, [RBP+RESULT]
			MOVQ XMM0, [RAX]
			MOVD XMM1, EBX
			VCVTPH2PS XMM0, XMM0
			VCVTPH2PS XMM1, XMM1
			SHUFPS XMM1, XMM1, 0
			SUBPS XMM0, XMM1
			VCVTPS2PH XMM0, XMM0, 0
			MOVQ [RCX], XMM0
		END;
		RETURN RESULT;
	END "-";

	OPERATOR ".*"*(CONST x, y: Vector4): Vector4;
	BEGIN
		CODE
			MOV RAX, [RBP+x]
			MOV RBX, [RBP+y]
			MOV RCX, [RBP+RESULT]
			MOVQ XMM0, [RAX]
			MOVQ XMM1, [RBX]
			VCVTPH2PS XMM0, XMM0
			VCVTPH2PS XMM1, XMM1
			MULPS XMM0, XMM1
			VCVTPS2PH XMM0, XMM0, 0
			MOVQ [RCX], XMM0
		END;
		RETURN RESULT;
	END ".*";

	OPERATOR ".*"*(CONST x: Vector4; y: SHORTREAL): Vector4;
	BEGIN
		CODE
			MOV RAX, [RBP+x]
			MOV BX, [RBP+y]
			MOV RCX, [RBP+RESULT]
			MOVQ XMM0, [RAX]
			MOVD XMM1, EBX
			VCVTPH2PS XMM0, XMM0
			VCVTPH2PS XMM1, XMM1
			SHUFPS XMM1, XMM1, 0
			MULPS XMM0, XMM1
			VCVTPS2PH XMM0, XMM0, 0
			MOVQ [RCX], XMM0
		END;
		RETURN RESULT;
	END ".*";

	OPERATOR "./"*(CONST x, y: Vector4): Vector4;
	BEGIN
		CODE
			MOV RAX, [RBP+x]
			MOV RBX, [RBP+y]
			MOV RCX, [RBP+RESULT]
			MOVQ XMM0, [RAX]
			MOVQ XMM1, [RBX]
			VCVTPH2PS XMM0, XMM0
			VCVTPH2PS XMM1, XMM1
			DIVPS XMM0, XMM1
			VCVTPS2PH XMM0, XMM0, 0
			MOVQ [RCX], XMM0
		END;
		RETURN RESULT;
	END "./";

	OPERATOR "./"*(CONST x: Vector4; y: SHORTREAL): Vector4;
	BEGIN
		CODE
			MOV RAX, [RBP+x]
			MOV BX, [RBP+y]
			MOV RCX, [RBP+RESULT]
			MOVQ XMM0, [RAX]
			MOVD XMM1, EBX
			VCVTPH2PS XMM0, XMM0
			VCVTPH2PS XMM1, XMM1
			SHUFPS XMM1, XMM1, 0
			DIVPS XMM0, XMM1
			VCVTPS2PH XMM0, XMM0, 0
			MOVQ [RCX], XMM0
		END;
		RETURN RESULT;
	END "./";

	OPERATOR "+*"*(CONST x, y: Vector4): FLOAT32;
	CODE
		MOV RAX, [RBP+x]
		MOV RBX, [RBP+y]
		MOVQ XMM0, [RAX]
		MOVQ XMM1, [RBX]
		VCVTPH2PS XMM0, XMM0
		VCVTPH2PS XMM1, XMM1
		MULPS XMM0, XMM1
		HADDPS XMM0, XMM0
		HADDPS XMM0, XMM0
	END "+*";

	OPERATOR "SUM"*(CONST x: Vector4): FLOAT32;
	CODE
		MOV RAX, [RBP+x]
		MOVQ XMM0, [RAX]
		VCVTPH2PS XMM0, XMM0
		HADDPS XMM0, XMM0
		HADDPS XMM0, XMM0
	END "SUM";

	OPERATOR "MAX"*(CONST x: Vector4): SHORTREAL;
	VAR y: SHORTREAL;
	BEGIN
		CODE
			MOV RAX, [RBP+x]
			MOVQ XMM0, [RAX]
			VCVTPH2PS XMM0, XMM0
			SHUFPS XMM1, XMM0, 044H ; XMM0=[s3, s2, s1, s0], XMM1=[d3, d2, d1, d0] => XMM1 = [s1, s0, d1, d0]
			MAXPS XMM0, XMM1
			SHUFPS XMM1, XMM0, 0F4H ; XMM0=[s3, s2, s1, s0], XMM1=[d3, d2, d1, d0] => XMM1 = [s3, s3, d1, d0]
			MAXPS XMM0, XMM1
			MOVHLPS XMM0, XMM0
			VCVTPS2PH XMM0, XMM0, 0
			MOVD EAX, XMM0
			MOV [RBP+y], AX
		END;
		RETURN y;
	END "MAX";

	OPERATOR "MIN"*(CONST x: Vector4): SHORTREAL;
	VAR y: SHORTREAL;
	BEGIN
		CODE
			MOV RAX, [RBP+x]
			MOVQ XMM0, [RAX]
			VCVTPH2PS XMM0, XMM0
			SHUFPS XMM1, XMM0, 044H ; XMM0=[s3, s2, s1, s0], XMM1=[d3, d2, d1, d0] => XMM1 = [s1, s0, d1, d0]
			MINPS XMM0, XMM1
			SHUFPS XMM1, XMM0, 0F4H ; XMM0=[s3, s2, s1, s0], XMM1=[d3, d2, d1, d0] => XMM1 = [s3, s3, d1, d0]
			MINPS XMM0, XMM1
			MOVHLPS XMM0, XMM0
			VCVTPS2PH XMM0, XMM0, 0
			MOVD EAX, XMM0
			MOV [RBP+y], AX
		END;
		RETURN y;
	END "MIN";

	OPERATOR "ABS"*(CONST x: Vector4): Vector4;
	CODE
		MOV RAX, [RBP+x]
		MOV RBX, [RBP+RESULT]
		MOV EDX, 7FFF7FFFH
		SHL RDX, 32
		OR RDX, 7FFF7FFFH
		MOV RAX, [RAX]
		AND RAX, RDX
		MOV [RBX], RAX
	END "ABS";

	OPERATOR "-"*(CONST x: Vector4): Vector4;
	CODE
		MOV RAX, [RBP+x]
		MOV RBX, [RBP+RESULT]
		MOV EDX, 80008000H
		SHL RDX, 32
		OR RDX, 80008000H
		MOV RAX, [RAX]
		XOR RAX, RDX
		MOV [RBX], RAX
	END "-";

	OPERATOR "SUM"*(CONST x: ARRAY [?] OF SHORTREAL): FLOAT32;
	VAR acc: FLOAT32;
	BEGIN
		acc := 0;
		FoxArrayBase.ApplyUnaryASOp(ADDRESSOF(acc),x,SumLoop);
		RETURN acc;
	END "SUM";

	OPERATOR "MAX"*(CONST x: ARRAY [?] OF SHORTREAL): SHORTREAL;
	VAR max: SHORTREAL;
	BEGIN
		max.value := MinValue;
		FoxArrayBase.ApplyUnaryASOp(ADDRESSOF(max),x,MaxLoop);
		RETURN max;
	END "MAX";

	OPERATOR "MIN"*(CONST x: ARRAY [?] OF SHORTREAL): SHORTREAL;
	VAR max: SHORTREAL;
	BEGIN
		max.value := MaxValue;
		FoxArrayBase.ApplyUnaryASOp(ADDRESSOF(max),x,MinLoop);
		RETURN max;
	END "MIN";

	OPERATOR "ABS"*(CONST x: ARRAY [?] OF SHORTREAL): ARRAY {UNSAFE} [?] OF SHORTREAL;
	BEGIN
		FoxArrayBase.ApplyUnaryAAOp(RESULT,x,SIZEOF(SHORTREAL),AbsLoop);
		RETURN RESULT;
	END "ABS";

	OPERATOR "-"*(CONST x: ARRAY [?] OF SHORTREAL): ARRAY {UNSAFE} [?] OF SHORTREAL;
	BEGIN
		FoxArrayBase.ApplyUnaryAAOp(RESULT,x,SIZEOF(SHORTREAL),NegateLoop);
		RETURN RESULT;
	END "-";

	(*!TODO: replace by SHORT operator after fixing a compiler bug which does not allow to compile the operator code *)
	PROCEDURE Short*(CONST x: ARRAY [?] OF Real): ARRAY {UNSAFE} [?] OF SHORTREAL;
	BEGIN
		FoxArrayBase.ApplyUnaryAAOp(RESULT,x,SIZEOF(SHORTREAL),ShortLoop);
		RETURN RESULT;
	END Short;
(*
	OPERATOR "SHORT"*(CONST x: ARRAY [?] OF Real): ARRAY {UNSAFE} [?] OF SHORTREAL;
	BEGIN
		FoxArrayBase.ApplyUnaryAAOp(RESULT,x,SIZEOF(SHORTREAL),ShortLoop);
		RETURN RESULT;
	END "SHORT";
*)
	OPERATOR "LONG"*(CONST x: ARRAY [?] OF SHORTREAL): ARRAY {UNSAFE} [?] OF FLOAT32;
	BEGIN
		FoxArrayBase.ApplyUnaryAAOp(RESULT,x,SIZEOF(FLOAT32),LongLoop);
		RETURN RESULT;
	END "LONG";

	PROCEDURE Sqrt*(CONST x: ARRAY [?] OF SHORTREAL): ARRAY {UNSAFE} [?] OF SHORTREAL;
	BEGIN
		FoxArrayBase.ApplyUnaryAAOp(RESULT,x,SIZEOF(SHORTREAL),SqrtLoop);
		RETURN RESULT;
	END Sqrt;

	PROCEDURE Sin*(CONST x: ARRAY [?] OF SHORTREAL): ARRAY {UNSAFE} [?] OF SHORTREAL;
	BEGIN
		FoxArrayBase.ApplyUnaryAAOp(RESULT,x,SIZEOF(SHORTREAL),SinLoop);
		RETURN RESULT;
	END Sin;

	PROCEDURE Cos*(CONST x: ARRAY [?] OF SHORTREAL): ARRAY {UNSAFE} [?] OF SHORTREAL;
	BEGIN
		FoxArrayBase.ApplyUnaryAAOp(RESULT,x,SIZEOF(SHORTREAL),CosLoop);
		RETURN RESULT;
	END Cos;

	PROCEDURE Arctan*(CONST x: ARRAY [?] OF SHORTREAL): ARRAY {UNSAFE} [?] OF SHORTREAL;
	BEGIN
		FoxArrayBase.ApplyUnaryAAOp(RESULT,x,SIZEOF(SHORTREAL),ArctanLoop);
		RETURN RESULT;
	END Arctan;

	PROCEDURE Ln*(CONST x: ARRAY [?] OF SHORTREAL): ARRAY {UNSAFE} [?] OF SHORTREAL;
	BEGIN
		FoxArrayBase.ApplyUnaryAAOp(RESULT,x,SIZEOF(SHORTREAL),LnLoop);
		RETURN RESULT;
	END Ln;

	PROCEDURE Exp*(CONST x: ARRAY [?] OF SHORTREAL): ARRAY {UNSAFE} [?] OF SHORTREAL;
	BEGIN
		FoxArrayBase.ApplyUnaryAAOp(RESULT,x,SIZEOF(SHORTREAL),ExpLoop);
		RETURN RESULT;
	END Exp;

	PROCEDURE Sqrt0(x: UNSIGNED16): UNSIGNED16;
	CODE
		MOV AX, [RBP+x] ; load U16
		MOVD XMM0, EAX
		VCVTPH2PS XMM0, XMM0
		SQRTSS XMM0, XMM0
		VCVTPS2PH XMM0, XMM0, 0
		MOVD RAX, XMM0
	END Sqrt0;

	PROCEDURE Sin0(x: UNSIGNED16): UNSIGNED16;
	CODE
		SUB RSP, 4 ; create a local variable of type FLOAT32
		MOV AX, [RBP+x] ; load U16
		MOVD XMM0, EAX
		VCVTPH2PS XMM0, XMM0
		MOVD [RSP], XMM0
		FLD [RSP]
		FSIN
		FST [RSP]
		MOVSS XMM0, [RSP]
		VCVTPS2PH XMM0, XMM0, 0
		MOVD RAX, XMM0
		ADD RSP, 4 ; remove local variable
	END Sin0;

	PROCEDURE Cos0(x: UNSIGNED16): UNSIGNED16;
	CODE
		SUB RSP, 4 ; create a local variable of type FLOAT32
		MOV AX, [RBP+x] ; load U16
		MOVD XMM0, EAX
		VCVTPH2PS XMM0, XMM0
		MOVD [RSP], XMM0
		FLD [RSP]
		FCOS
		FST [RSP]
		MOVSS XMM0, [RSP]
		VCVTPS2PH XMM0, XMM0, 0
		MOVD RAX, XMM0
		ADD RSP, 4 ; remove local variable
	END Cos0;

	PROCEDURE Arctan0(x: UNSIGNED16): UNSIGNED16;
	CODE
		SUB RSP, 4 ; create a local variable of type FLOAT32
		MOV AX, [RBP+x] ; load U16
		MOVD XMM0, EAX
		VCVTPH2PS XMM0, XMM0
		MOVD [RSP], XMM0
		FLD [RSP]
		FLD1
		FPATAN
		FST [RSP]
		MOVSS XMM0, [RSP]
		VCVTPS2PH XMM0, XMM0, 0
		MOVD RAX, XMM0
		ADD RSP, 4 ; remove local variable
	END Arctan0;

	PROCEDURE Ln0(x: UNSIGNED16): UNSIGNED16;
	CODE
		SUB RSP, 4 ; create a local variable of type FLOAT32
		MOV AX, [RBP+x] ; load U16
		MOVD XMM0, EAX
		VCVTPH2PS XMM0, XMM0
		MOVD [RSP], XMM0
		FLD1
		FLDL2E
		FDIVP
		FLD [RSP]
		FYL2X
		FST [RSP]
		MOVSS XMM0, [RSP]
		VCVTPS2PH XMM0, XMM0, 0
		MOVD RAX, XMM0
		ADD RSP, 4 ; remove local variable
	END Ln0;

	PROCEDURE Exp0(x: UNSIGNED16): UNSIGNED16;
	CODE
		SUB RSP, 4 ; create a local variable of type FLOAT32
		MOV AX, [RBP+x] ; load U16
		MOVD XMM0, EAX
		VCVTPH2PS XMM0, XMM0
		MOVD [RSP], XMM0
		FLD [RSP]
		FLDL2E
		FMULP
		FLD ST0
		FRNDINT
		FXCH ST1
		FSUB ST0, ST1
		F2XM1
		FLD1
		FADDP
		FSCALE
		FSTP ST1
		FST [RSP]
		MOVSS XMM0, [RSP]
		VCVTPS2PH XMM0, XMM0, 0
		MOVD RAX, XMM0
		ADD RSP, 4 ; remove local variable
	END Exp0;

	PROCEDURE Abs(x: UNSIGNED16): UNSIGNED16;
	CODE
		MOV AX, [RBP+x] ; load U16
		AND RAX, 7FFFH
	END Abs;

	PROCEDURE Negate(x: UNSIGNED16): UNSIGNED16;
	CODE
		MOV AX, [RBP+x] ; load U16
		XOR AX, 8000H
	END Negate;

	PROCEDURE Add(x, y: UNSIGNED16): UNSIGNED16;
	CODE
		MOV AX, [RBP+x]
		MOV BX, [RBP+y]
		MOVD XMM0, EAX
		MOVD XMM1, EBX
		VCVTPH2PS XMM0, XMM0
		VCVTPH2PS XMM1, XMM1
		ADDSS XMM0, XMM1
		VCVTPS2PH XMM0, XMM0, 0
		MOVD RAX, XMM0
	END Add;

	PROCEDURE Sub(x, y: UNSIGNED16): UNSIGNED16;
	CODE
		MOV AX, [RBP+x]
		MOV BX, [RBP+y]
		MOVD XMM0, EAX
		MOVD XMM1, EBX
		VCVTPH2PS XMM0, XMM0
		VCVTPH2PS XMM1, XMM1
		SUBSS XMM0, XMM1
		VCVTPS2PH XMM0, XMM0, 0
		MOVD RAX, XMM0
	END Sub;

	PROCEDURE Mul(x, y: UNSIGNED16): UNSIGNED16;
	CODE
		MOV AX, [RBP+x]
		MOV BX, [RBP+y]
		MOVD XMM0, EAX
		MOVD XMM1, EBX
		VCVTPH2PS XMM0, XMM0
		VCVTPH2PS XMM1, XMM1
		MULSS XMM0, XMM1
		VCVTPS2PH XMM0, XMM0, 0
		MOVD RAX, XMM0
	END Mul;

	PROCEDURE Div(x, y: UNSIGNED16): UNSIGNED16;
	CODE
		MOV AX, [RBP+x]
		MOV BX, [RBP+y]
		MOVD XMM0, EAX
		MOVD XMM1, EBX
		VCVTPH2PS XMM0, XMM0
		VCVTPH2PS XMM1, XMM1
		DIVSS XMM0, XMM1
		VCVTPS2PH XMM0, XMM0, 0
		MOVD RAX, XMM0
	END Div;

	PROCEDURE Equal(x, y: UNSIGNED16): BOOLEAN;
	CODE
		MOV AX, [RBP+x]
		MOV BX, [RBP+y]
		MOVD XMM0, EAX
		MOVD XMM1, EBX
		VCVTPH2PS XMM0, XMM0
		VCVTPH2PS XMM1, XMM1
		CMPSS XMM0, XMM1, 0
		MOVD EAX, XMM0
		AND EAX, 1
	END Equal;

	PROCEDURE LessThan(x, y: UNSIGNED16): BOOLEAN;
	CODE
		MOV AX, [RBP+x]
		MOV BX, [RBP+y]
		MOVD XMM0, EAX
		MOVD XMM1, EBX
		VCVTPH2PS XMM0, XMM0
		VCVTPH2PS XMM1, XMM1
		CMPSS XMM0, XMM1, 1
		MOVD EAX, XMM0
		AND EAX, 1
	END LessThan;

	PROCEDURE GreaterThan(x, y: UNSIGNED16): BOOLEAN;
	CODE
		MOV AX, [RBP+x]
		MOV BX, [RBP+y]
		MOVD XMM0, EAX
		MOVD XMM1, EBX
		VCVTPH2PS XMM0, XMM0
		VCVTPH2PS XMM1, XMM1
		CMPSS XMM0, XMM1, 6
		MOVD EAX, XMM0
		AND EAX, 1
	END GreaterThan;

	PROCEDURE AssignScalarLoop(laddr, daddr: ADDRESS; dinc, len: SIZE);
	BEGIN
		(*!TODO: optimize contiguous case *)
		IF FALSE(*dinc = 2*) THEN
		ELSE (* striding single element access *)
			CODE
				MOV RAX, [RBP+laddr]
				MOV AX, [RAX]
				MOV RBX, [RBP+daddr]
				MOV RCX, [RBP+len]
				MOV RDX, [RBP+dinc]
			Loop:
				CMP RCX, 0
				JLE Exit
				MOV [RBX], AX
				ADD RBX, RDX
				SUB RCX, 1
				JMP Loop
			Exit:
			END;
		END;
	END AssignScalarLoop;

	PROCEDURE SumLoop(laddr, daddr: ADDRESS; linc, len: SIZE);
	BEGIN
		IF linc = 2 THEN
			CODE
				MOV RAX, [RBP+laddr]
				MOV RCX, [RBP+len]
				MOV RDX, [RBP+daddr]
				MOVD XMM0, [RDX]
			Loop4:
				CMP RCX, 4
				JL Reminder2
				MOVQ XMM1, [RAX]
				VCVTPH2PS XMM1, XMM1
				ADDPS XMM0, XMM1
				ADD RAX, 8
				SUB RCX, 4
				JMP Loop4
			Reminder2:
				CMP RCX, 2
				JL Reminder1
				MOV EDX, [RAX]
				MOVD XMM1, EDX
				VCVTPH2PS XMM1, XMM1
				ADDPS XMM0, XMM1
				ADD RAX, 4
				SUB RCX, 2
			Reminder1:
				CMP RCX, 0
				JLE Exit
				MOV AX, [RAX]
				MOVD XMM1, EAX
				VCVTPH2PS XMM1, XMM1
				ADDSS XMM0, XMM1
			Exit:
				HADDPS XMM0, XMM0
				HADDPS XMM0, XMM0
				MOV RDX, [RBP+daddr]
				MOVD [RDX], XMM0
			END;
		ELSE
			CODE
				MOV RAX, [RBP+laddr]
				MOV RBX, [RBP+linc]
				MOV RCX, [RBP+len]
				MOV RDX, [RBP+daddr]
				MOVD XMM0, [RDX]
			Loop:
				CMP RCX, 0
				JLE Exit
				MOV DX, [RAX]
				MOVD XMM1, EDX
				VCVTPH2PS XMM1, XMM1
				ADDSS XMM0, XMM1
				ADD RAX, RBX
				SUB RCX, 1
				JMP Loop
			Exit:
				MOV RDX, [RBP+daddr]
				MOVD [RDX], XMM0
			END;
		END;
	END SumLoop;

	PROCEDURE MaxLoop( laddr, daddr: ADDRESS; linc, len: SIZE );
	BEGIN
		IF linc = 2 THEN
			CODE
				MOV RAX, [RBP+laddr]
				MOV RCX, [RBP+len]
				MOV RDX, [RBP+daddr]
				MOV DX, [RDX]
				MOVD XMM0, EDX
				VCVTPH2PS XMM0, XMM0
				SHUFPS XMM0, XMM0, 0 ; [0, 0, 0, x0] => [x0, x0, x0, x0]
			Loop4:
				CMP RCX, 4
				JL Reminder2
				MOVQ XMM1, [RAX]
				VCVTPH2PS XMM1, XMM1
				MAXPS XMM0, XMM1
				ADD RAX, 8
				SUB RCX, 4
				JMP Loop4
			Reminder2:
				CMP RCX, 2
				JL Reminder1
				MOV EDX, [RAX]
				MOVD XMM1, EDX
				VCVTPH2PS XMM1, XMM1
				SHUFPS XMM1, XMM1, 044H ; [0, 0, x1, x0] => [x1, x0, x1, x0]
				MAXPS XMM0, XMM1
				ADD RAX, 4
				SUB RCX, 2
			Reminder1:
				CMP RCX, 0
				JLE Exit
				MOV AX, [RAX]
				MOVD XMM1, EAX
				VCVTPH2PS XMM1, XMM1
				SHUFPS XMM1, XMM1, 0 ; [0, 0, 0, x0] => [x0, x0, x0, x0]
				MAXPS XMM0, XMM1
			Exit:
				SHUFPS XMM1, XMM0, 044H ; XMM0=[s3, s2, s1, s0], XMM1=[d3, d2, d1, d0] => XMM1 = [s1, s0, d1, d0]
				MAXPS XMM0, XMM1
				SHUFPS XMM1, XMM0, 0F4H ; XMM0=[s3, s2, s1, s0], XMM1=[d3, d2, d1, d0] => XMM1 = [s3, s3, d1, d0]
				MAXPS XMM0, XMM1
				MOVHLPS XMM0, XMM0
				MOV RDX, [RBP+daddr]
				VCVTPS2PH XMM0, XMM0, 0
				MOVD EAX, XMM0
				MOV [RDX], AX
			END;
		ELSE
			CODE
				MOV RAX, [RBP+laddr]
				MOV RBX, [RBP+linc]
				MOV RCX, [RBP+len]
				MOV RDX, [RBP+daddr]
				MOV DX, [RDX]
				MOVD XMM0, EDX
				VCVTPH2PS XMM0, XMM0
			Loop:
				CMP RCX, 0
				JLE Exit
				MOV DX, [RAX]
				MOVD XMM1, EDX
				VCVTPH2PS XMM1, XMM1
				MAXSS XMM0, XMM1
				ADD RAX, RBX
				SUB RCX, 1
				JMP Loop
			Exit:
				MOV RDX, [RBP+daddr]
				VCVTPS2PH XMM0, XMM0, 0
				MOVD EAX, XMM0
				MOV [RDX], AX
			END;
		END;
	END MaxLoop;

	PROCEDURE MinLoop( laddr, daddr: ADDRESS; linc, len: SIZE );
	BEGIN
		IF linc = 2 THEN
			CODE
				MOV RAX, [RBP+laddr]
				MOV RCX, [RBP+len]
				MOV RDX, [RBP+daddr]
				MOV DX, [RDX]
				MOVD XMM0, EDX
				VCVTPH2PS XMM0, XMM0
				SHUFPS XMM0, XMM0, 0 ; [0, 0, 0, x0] => [x0, x0, x0, x0]
			Loop4:
				CMP RCX, 4
				JL Reminder2
				MOVQ XMM1, [RAX]
				VCVTPH2PS XMM1, XMM1
				MINPS XMM0, XMM1
				ADD RAX, 8
				SUB RCX, 4
				JMP Loop4
			Reminder2:
				CMP RCX, 2
				JL Reminder1
				MOV EDX, [RAX]
				MOVD XMM1, EDX
				VCVTPH2PS XMM1, XMM1
				SHUFPS XMM1, XMM1, 044H ; [0, 0, x1, x0] => [x1, x0, x1, x0]
				MINPS XMM0, XMM1
				ADD RAX, 4
				SUB RCX, 2
			Reminder1:
				CMP RCX, 0
				JLE Exit
				MOV AX, [RAX]
				MOVD XMM1, EAX
				VCVTPH2PS XMM1, XMM1
				SHUFPS XMM1, XMM1, 0 ; [0, 0, 0, x0] => [x0, x0, x0, x0]
				MINPS XMM0, XMM1
			Exit:
				SHUFPS XMM1, XMM0, 044H ; XMM0=[s3, s2, s1, s0], XMM1=[d3, d2, d1, d0] => XMM1 = [s1, s0, d1, d0]
				MINPS XMM0, XMM1
				SHUFPS XMM1, XMM0, 0F4H ; XMM0=[s3, s2, s1, s0], XMM1=[d3, d2, d1, d0] => XMM1 = [s3, s3, d1, d0]
				MINPS XMM0, XMM1
				MOVHLPS XMM0, XMM0
				MOV RDX, [RBP+daddr]
				VCVTPS2PH XMM0, XMM0, 0
				MOVD EAX, XMM0
				MOV [RDX], AX
			END;
		ELSE
			CODE
				MOV RAX, [RBP+laddr]
				MOV RBX, [RBP+linc]
				MOV RCX, [RBP+len]
				MOV RDX, [RBP+daddr]
				MOV DX, [RDX]
				MOVD XMM0, EDX
				VCVTPH2PS XMM0, XMM0
			Loop:
				CMP RCX, 0
				JLE Exit
				MOV DX, [RAX]
				MOVD XMM1, EDX
				VCVTPH2PS XMM1, XMM1
				MINSS XMM0, XMM1
				ADD RAX, RBX
				SUB RCX, 1
				JMP Loop
			Exit:
				MOV RDX, [RBP+daddr]
				VCVTPS2PH XMM0, XMM0, 0
				MOVD EAX, XMM0
				MOV [RDX], AX
			END;
		END;
	END MinLoop;

	PROCEDURE AbsLoop( laddr, daddr: ADDRESS; linc, dinc, len: SIZE );
	BEGIN
		IF (linc = 2) & (dinc = 2) THEN
			CODE
				MOV RAX, [RBP+laddr]
				MOV RBX, [RBP+daddr]
				MOV RCX, [RBP+len]
				MOV EDX, 7FFF7FFFH
				MOVD XMM1, EDX
				SHUFPS XMM1, XMM1, 0 ; mask
			Loop8:
				CMP RCX, 8
				JL Reminder4
				MOVUPS XMM0, [RAX]
				ANDPS XMM0, XMM1
				MOVUPS [RBX], XMM0
				ADD RAX, 16
				ADD RBX, 16
				SUB RCX, 8
				JMP Loop8
			Reminder4:
				CMP RCX, 4
				JL Reminder2
				MOVQ XMM0, [RAX]
				ANDPS XMM0, XMM1
				MOVQ [RBX], XMM0
				ADD RAX, 8
				ADD RBX, 8
				SUB RCX, 4
			Reminder2:
				CMP RCX, 2
				JL Reminder1
				MOV EDX, [RAX]
				AND RDX, 7FFF7FFFH
				MOV [RBX], EDX
				ADD RAX, 4
				ADD RBX, 4
				SUB RCX, 2
			Reminder1:
				CMP RCX, 0
				JLE Exit
				MOV DX, [RAX]
				AND RDX, 7FFFH
				MOV [RBX], DX
			Exit:
			END;
		ELSE (* striding single element access *)
			CODE
				MOV RAX, [RBP+laddr]
				MOV RBX, [RBP+daddr]
				MOV RCX, [RBP+len]
			Loop:
				CMP RCX, 0
				JLE Exit
				MOV DX, [RAX]
				AND RDX, 7FFFH
				MOV [RBX], DX
				ADD RAX, [RBP+linc]
				ADD RBX, [RBP+dinc]
				SUB RCX, 1
				JMP Loop
			Exit:
			END;
		END;
	END AbsLoop;

	PROCEDURE NegateLoop( laddr, daddr: ADDRESS; linc, dinc, len: SIZE );
	BEGIN
		IF (linc = 2) & (dinc = 2) THEN
			CODE
				MOV RAX, [RBP+laddr]
				MOV RBX, [RBP+daddr]
				MOV RCX, [RBP+len]
				MOV EDX, 80008000H ; mask
				MOVD XMM1, EDX
				SHUFPS XMM1, XMM1, 0
			Loop8:
				CMP RCX, 8
				JL Reminder4
				MOVUPS XMM0, [RAX]
				XORPS XMM0, XMM1
				MOVUPS [RBX], XMM0
				ADD RAX, 16
				ADD RBX, 16
				SUB RCX, 8
				JMP Loop8
			Reminder4:
				CMP RCX, 4
				JL Reminder2
				MOVQ XMM0, [RAX]
				XORPS XMM0, XMM1
				MOVQ [RBX], XMM0
				ADD RAX, 8
				ADD RBX, 8
				SUB RCX, 4
			Reminder2:
				CMP RCX, 2
				JL Reminder1
				MOV EDX, [RAX]
				XOR RDX, 80008000H
				MOV [RBX], EDX
				ADD RAX, 4
				ADD RBX, 4
				SUB RCX, 2
			Reminder1:
				CMP RCX, 0
				JLE Exit
				MOV DX, [RAX]
				XOR RDX, 8000H
				MOV [RBX], DX
			Exit:
			END;
		ELSE (* striding single element access *)
			CODE
				MOV RAX, [RBP+laddr]
				MOV RBX, [RBP+daddr]
				MOV RCX, [RBP+len]
			Loop:
				CMP RCX, 0
				JLE Exit
				MOV DX, [RAX]
				XOR RDX, 8000H
				MOV [RBX], DX
				ADD RAX, [RBP+linc]
				ADD RBX, [RBP+dinc]
				SUB RCX, 1
				JMP Loop
			Exit:
			END;
		END;
	END NegateLoop;

	PROCEDURE ShortLoop( laddr, daddr: ADDRESS; linc, dinc, len: SIZE );
	BEGIN
		IF (linc = 4) & (dinc = 2) THEN
			CODE
				MOV RAX, [RBP+laddr]
				MOV RBX, [RBP+daddr]
				MOV RCX, [RBP+len]
			Loop4:
				CMP RCX, 4
				JL Reminder2
				MOVUPS XMM0, [RAX]
				VCVTPS2PH XMM0, XMM0, 0
				MOVQ [RBX], XMM0
				ADD RAX, 16
				ADD RBX, 8
				SUB RCX, 4
				JMP Loop4
			Reminder2:
				CMP RCX, 2
				JL Reminder1
				MOVQ XMM0, [RAX]
				VCVTPS2PH XMM0, XMM0, 0
				MOVD [RBX], XMM0
				ADD RAX, 8
				ADD RBX, 4
				SUB RCX, 2
			Reminder1:
				CMP RCX, 0
				JLE Exit
				MOVD XMM0, [RAX]
				VCVTPS2PH XMM0, XMM0, 0
				MOVD EDX, XMM0
				MOV [RBX], DX
			Exit:
			END;
		ELSE (* striding single element access *)
			CODE
				MOV RAX, [RBP+laddr]
				MOV RBX, [RBP+daddr]
				MOV RCX, [RBP+len]
			Loop:
				CMP RCX, 0
				JLE Exit
				MOVD XMM0, [RAX]
				VCVTPS2PH XMM0, XMM0, 0
				MOVD EDX, XMM0
				MOV [RBX], DX
				ADD RAX, [RBP+linc]
				ADD RBX, [RBP+dinc]
				SUB RCX, 1
				JMP Loop
			Exit:
			END;
		END;
	END ShortLoop;

	PROCEDURE LongLoop( laddr, daddr: ADDRESS; linc, dinc, len: SIZE );
	BEGIN
		IF (linc = 2) & (dinc = 4) THEN
			CODE
				MOV RAX, [RBP+laddr]
				MOV RBX, [RBP+daddr]
				MOV RCX, [RBP+len]
			Loop4:
				CMP RCX, 4
				JL Reminder2
				MOVQ XMM0, [RAX]
				VCVTPH2PS XMM0, XMM0
				MOVUPS [RBX], XMM0
				ADD RAX, 8
				ADD RBX, 16
				SUB RCX, 4
				JMP Loop4
			Reminder2:
				CMP RCX, 2
				JL Reminder1
				MOV EDX, [RAX]
				MOVD XMM0, EDX
				VCVTPH2PS XMM0, XMM0
				MOVQ [RBX], XMM0
				ADD RAX, 4
				ADD RBX, 8
				SUB RCX, 2
			Reminder1:
				CMP RCX, 0
				JLE Exit
				MOV DX, [RAX]
				MOVD XMM0, EDX
				VCVTPH2PS XMM0, XMM0
				MOVD [RBX], XMM0
			Exit:
			END;
		ELSE (* striding single element access *)
			CODE
				MOV RAX, [RBP+laddr]
				MOV RBX, [RBP+daddr]
				MOV RCX, [RBP+len]
			Loop:
				CMP RCX, 0
				JLE Exit
				MOV DX, [RAX]
				MOVD XMM0, EDX
				VCVTPH2PS XMM0, XMM0
				MOVD [RBX], XMM0
				ADD RAX, [RBP+linc]
				ADD RBX, [RBP+dinc]
				SUB RCX, 1
				JMP Loop
			Exit:
			END;
		END;
	END LongLoop;

	PROCEDURE AddLoop( laddr, raddr, daddr: ADDRESS; linc, rinc, dinc, len: SIZE );
	BEGIN
		IF (linc = 2) & (rinc = 2) & (dinc = 2) THEN
			CODE
				MOV RAX, [RBP+laddr]
				MOV RBX, [RBP+raddr]
				MOV RCX, [RBP+daddr]
				MOV RDX, [RBP+len]
			Loop4:
				CMP RDX, 4
				JL Reminder2
				MOVQ XMM0, [RAX]
				VCVTPH2PS XMM0, XMM0
				MOVQ XMM1, [RBX]
				VCVTPH2PS XMM1, XMM1
				ADDPS XMM0, XMM1
				VCVTPS2PH XMM0, XMM0, 0
				MOVQ [RCX], XMM0
				ADD RAX, 8
				ADD RBX, 8
				ADD RCX, 8
				SUB RDX, 4
				JMP Loop4
			Reminder2:
				CMP RDX, 2
				JL Reminder1
				MOV [RBP+len], RDX
				MOVD XMM0, [RAX]
				MOVD XMM1, [RBX]
				VCVTPH2PS XMM0, XMM0
				VCVTPH2PS XMM1, XMM1
				ADDPS XMM0, XMM1
				VCVTPS2PH XMM0, XMM0, 0
				MOVD [RCX], XMM0
				ADD RAX, 4
				ADD RBX, 4
				ADD RCX, 4
				MOV RDX, [RBP+len]
				SUB RDX, 2
			Reminder1:
				CMP RDX, 0
				JLE Exit
				MOV AX, [RAX]
				MOVD XMM0, EAX
				MOV BX, [RBX]
				MOVD XMM1, EBX
				VCVTPH2PS XMM0, XMM0
				VCVTPH2PS XMM1, XMM1
				ADDSS XMM0, XMM1
				VCVTPS2PH XMM0, XMM0, 0
				MOVD RAX, XMM0
				MOV [RCX], AX
			Exit:
			END;
		ELSE (* striding single element access *)
			CODE
				MOV RAX, [RBP+laddr]
				MOV RBX, [RBP+raddr]
				MOV RCX, [RBP+daddr]
			Loop:
				MOV RDX, [RBP+len]
				CMP RDX, 0
				JLE Exit
				SUB RDX, 1
				MOV [RBP+len], RDX
				MOV DX, [RAX]
				MOVD XMM0, EDX
				MOV DX, [RBX]
				MOVD XMM1, EDX
				VCVTPH2PS XMM0, XMM0
				VCVTPH2PS XMM1, XMM1
				ADDSS XMM0, XMM1
				VCVTPS2PH XMM0, XMM0, 0
				MOVD RDX, XMM0
				MOV [RCX], DX
				ADD RAX, [RBP+linc]
				ADD RBX, [RBP+rinc]
				ADD RCX, [RBP+dinc]
				JMP Loop
			Exit:
			END;
		END;
	END AddLoop;

	(* array@daddr := array@laddr + scalar@raddr *)
	PROCEDURE AddScalarLoop(laddr, raddr, daddr: ADDRESS; linc, dinc, len: SIZE);
	BEGIN
		IF (linc = 2) & (dinc = 2) THEN
			CODE
				MOV RAX, [RBP+laddr]
				MOV RBX, [RBP+raddr]
				MOV RCX, [RBP+daddr]
				MOV RDX, [RBP+len]
				MOV BX, [RBX]
				MOVD XMM1, EBX
				VCVTPH2PS XMM1, XMM1
				SHUFPS XMM1, XMM1, 0
			Loop4:
				CMP RDX, 4
				JL Reminder2
				MOVQ XMM0, [RAX]
				VCVTPH2PS XMM0, XMM0
				ADDPS XMM0, XMM1
				VCVTPS2PH XMM0, XMM0, 0
				MOVQ [RCX], XMM0
				ADD RAX, 8
				ADD RCX, 8
				SUB RDX, 4
				JMP Loop4
			Reminder2:
				CMP RDX, 2
				JL Reminder1
				MOVD XMM0, [RAX]
				VCVTPH2PS XMM0, XMM0
				ADDPS XMM0, XMM1
				VCVTPS2PH XMM0, XMM0, 0
				MOVD [RCX], XMM0
				ADD RAX, 4
				ADD RCX, 4
				SUB RDX, 2
			Reminder1:
				CMP RDX, 0
				JLE Exit
				MOV AX, [RAX]
				MOVD XMM0, EAX
				VCVTPH2PS XMM0, XMM0
				ADDSS XMM0, XMM1
				VCVTPS2PH XMM0, XMM0, 0
				MOVD EAX, XMM0
				MOV [RCX], AX
			Exit:
			END;
		ELSE (* striding single element access *)
			CODE
				MOV RAX, [RBP+laddr]
				MOV RBX, [RBP+raddr]
				MOV RCX, [RBP+daddr]
				MOV RDX, [RBP+len]
				MOV BX, [RBX]
				MOVD XMM1, EBX
				VCVTPH2PS XMM1, XMM1
			Loop:
				CMP RDX, 0
				JLE Exit
				MOV BX, [RAX]
				MOVD XMM0, EBX
				VCVTPH2PS XMM0, XMM0
				ADDSS XMM0, XMM1
				VCVTPS2PH XMM0, XMM0, 0
				MOVD EBX, XMM0
				MOV [RCX], BX
				ADD RAX, [RBP+linc]
				ADD RCX, [RBP+dinc]
				SUB RDX, 1
				JMP Loop
			Exit:
			END;
		END;
	END AddScalarLoop;

	PROCEDURE SubLoop( laddr, raddr, daddr: ADDRESS; linc, rinc, dinc, len: SIZE );
	BEGIN
		IF (linc = 2) & (rinc = 2) & (dinc = 2) THEN
			CODE
				MOV RAX, [RBP+laddr]
				MOV RBX, [RBP+raddr]
				MOV RCX, [RBP+daddr]
				MOV RDX, [RBP+len]
			Loop4:
				CMP RDX, 4
				JL Reminder2
				MOVQ XMM0, [RAX]
				VCVTPH2PS XMM0, XMM0
				MOVQ XMM1, [RBX]
				VCVTPH2PS XMM1, XMM1
				SUBPS XMM0, XMM1
				VCVTPS2PH XMM0, XMM0, 0
				MOVQ [RCX], XMM0
				ADD RAX, 8
				ADD RBX, 8
				ADD RCX, 8
				SUB RDX, 4
				JMP Loop4
			Reminder2:
				CMP RDX, 2
				JL Reminder1
				MOV [RBP+len], RDX
				MOVD XMM0, [RAX]
				MOVD XMM1, [RBX]
				VCVTPH2PS XMM0, XMM0
				VCVTPH2PS XMM1, XMM1
				SUBPS XMM0, XMM1
				VCVTPS2PH XMM0, XMM0, 0
				MOVD [RCX], XMM0
				ADD RAX, 4
				ADD RBX, 4
				ADD RCX, 4
				MOV RDX, [RBP+len]
				SUB RDX, 2
			Reminder1:
				CMP RDX, 0
				JLE Exit
				MOV AX, [RAX]
				MOVD XMM0, EAX
				MOV BX, [RBX]
				MOVD XMM1, EBX
				VCVTPH2PS XMM0, XMM0
				VCVTPH2PS XMM1, XMM1
				SUBSS XMM0, XMM1
				VCVTPS2PH XMM0, XMM0, 0
				MOVD RAX, XMM0
				MOV [RCX], AX
			Exit:
			END;
		ELSE (* striding single element access *)
			CODE
				MOV RAX, [RBP+laddr]
				MOV RBX, [RBP+raddr]
				MOV RCX, [RBP+daddr]
			Loop:
				MOV RDX, [RBP+len]
				CMP RDX, 0
				JLE Exit
				SUB RDX, 1
				MOV [RBP+len], RDX
				MOV DX, [RAX]
				MOVD XMM0, EDX
				MOV DX, [RBX]
				MOVD XMM1, EDX
				VCVTPH2PS XMM0, XMM0
				VCVTPH2PS XMM1, XMM1
				SUBSS XMM0, XMM1
				VCVTPS2PH XMM0, XMM0, 0
				MOVD RDX, XMM0
				MOV [RCX], DX
				ADD RAX, [RBP+linc]
				ADD RBX, [RBP+rinc]
				ADD RCX, [RBP+dinc]
				JMP Loop
			Exit:
			END;
		END;
	END SubLoop;

	(* array@daddr := scalar@raddr - array@laddr *)
	PROCEDURE ScalarSubLoop(laddr, raddr, daddr: ADDRESS; linc, dinc, len: SIZE);
	BEGIN
		IF (linc = 2) & (dinc = 2) THEN
			CODE
				MOV RAX, [RBP+laddr]
				MOV RBX, [RBP+raddr]
				MOV RCX, [RBP+daddr]
				MOV RDX, [RBP+len]
				MOV BX, [RBX]
				MOVD XMM1, EBX
				VCVTPH2PS XMM1, XMM1
				SHUFPS XMM1, XMM1, 0
			Loop4:
				CMP RDX, 4
				JL Reminder2
				MOVQ XMM0, [RAX]
				VCVTPH2PS XMM0, XMM0
				MOVAPS XMM2, XMM1
				SUBPS XMM2, XMM0
				VCVTPS2PH XMM0, XMM2, 0
				MOVQ [RCX], XMM0
				ADD RAX, 8
				ADD RCX, 8
				SUB RDX, 4
				JMP Loop4
			Reminder2:
				CMP RDX, 2
				JL Reminder1
				MOVD XMM0, [RAX]
				VCVTPH2PS XMM0, XMM0
				MOVAPS XMM2, XMM1
				SUBPS XMM2, XMM0
				VCVTPS2PH XMM0, XMM2, 0
				MOVD [RCX], XMM0
				ADD RAX, 4
				ADD RCX, 4
				SUB RDX, 2
			Reminder1:
				CMP RDX, 0
				JLE Exit
				MOV AX, [RAX]
				MOVD XMM0, EAX
				VCVTPH2PS XMM0, XMM0
				MOVAPS XMM2, XMM1
				SUBSS XMM2, XMM0
				VCVTPS2PH XMM0, XMM2, 0
				MOVD EAX, XMM0
				MOV [RCX], AX
			Exit:
			END;
		ELSE (* striding single element access *)
			CODE
				MOV RAX, [RBP+laddr]
				MOV RBX, [RBP+raddr]
				MOV RCX, [RBP+daddr]
				MOV RDX, [RBP+len]
				MOV BX, [RBX]
				MOVD XMM1, EBX
				VCVTPH2PS XMM1, XMM1
			Loop:
				CMP RDX, 0
				JLE Exit
				MOV BX, [RAX]
				MOVD XMM0, EBX
				VCVTPH2PS XMM0, XMM0
				MOVAPS XMM2, XMM1
				SUBSS XMM2, XMM0
				VCVTPS2PH XMM0, XMM2, 0
				MOVD EBX, XMM0
				MOV [RCX], BX
				ADD RAX, [RBP+linc]
				ADD RCX, [RBP+dinc]
				SUB RDX, 1
				JMP Loop
			Exit:
			END;
		END;
	END ScalarSubLoop;

	PROCEDURE MulLoop( laddr, raddr, daddr: ADDRESS; linc, rinc, dinc, len: SIZE );
	BEGIN
		IF (linc = 2) & (rinc = 2) & (dinc = 2) THEN
			CODE
				MOV RAX, [RBP+laddr]
				MOV RBX, [RBP+raddr]
				MOV RCX, [RBP+daddr]
				MOV RDX, [RBP+len]
			Loop4:
				CMP RDX, 4
				JL Reminder2
				MOVQ XMM0, [RAX]
				VCVTPH2PS XMM0, XMM0
				MOVQ XMM1, [RBX]
				VCVTPH2PS XMM1, XMM1
				MULPS XMM0, XMM1
				VCVTPS2PH XMM0, XMM0, 0
				MOVQ [RCX], XMM0
				ADD RAX, 8
				ADD RBX, 8
				ADD RCX, 8
				SUB RDX, 4
				JMP Loop4
			Reminder2:
				CMP RDX, 2
				JL Reminder1
				MOV [RBP+len], RDX
				MOVD XMM0, [RAX]
				MOVD XMM1, [RBX]
				VCVTPH2PS XMM0, XMM0
				VCVTPH2PS XMM1, XMM1
				MULPS XMM0, XMM1
				VCVTPS2PH XMM0, XMM0, 0
				MOVD [RCX], XMM0
				ADD RAX, 4
				ADD RBX, 4
				ADD RCX, 4
				MOV RDX, [RBP+len]
				SUB RDX, 2
			Reminder1:
				CMP RDX, 0
				JLE Exit
				MOV AX, [RAX]
				MOVD XMM0, EAX
				MOV BX, [RBX]
				MOVD XMM1, EBX
				VCVTPH2PS XMM0, XMM0
				VCVTPH2PS XMM1, XMM1
				MULSS XMM0, XMM1
				VCVTPS2PH XMM0, XMM0, 0
				MOVD RAX, XMM0
				MOV [RCX], AX
			Exit:
			END;
		ELSE (* striding single element access *)
			CODE
				MOV RAX, [RBP+laddr]
				MOV RBX, [RBP+raddr]
				MOV RCX, [RBP+daddr]
			Loop:
				MOV RDX, [RBP+len]
				CMP RDX, 0
				JLE Exit
				SUB RDX, 1
				MOV [RBP+len], RDX
				MOV DX, [RAX]
				MOVD XMM0, EDX
				MOV DX, [RBX]
				MOVD XMM1, EDX
				VCVTPH2PS XMM0, XMM0
				VCVTPH2PS XMM1, XMM1
				MULSS XMM0, XMM1
				VCVTPS2PH XMM0, XMM0, 0
				MOVD RDX, XMM0
				MOV [RCX], DX
				ADD RAX, [RBP+linc]
				ADD RBX, [RBP+rinc]
				ADD RCX, [RBP+dinc]
				JMP Loop
			Exit:
			END;
		END;
	END MulLoop;

	PROCEDURE MulScalarLoop(laddr, raddr, daddr: ADDRESS; linc, dinc, len: SIZE);
	BEGIN
		IF (linc = 2) & (dinc = 2) THEN
			CODE
				MOV RAX, [RBP+laddr]
				MOV RBX, [RBP+raddr]
				MOV RCX, [RBP+daddr]
				MOV RDX, [RBP+len]
				MOV BX, [RBX]
				MOVD XMM1, EBX
				VCVTPH2PS XMM1, XMM1
				SHUFPS XMM1, XMM1, 0
			Loop4:
				CMP RDX, 4
				JL Reminder2
				MOVQ XMM0, [RAX]
				VCVTPH2PS XMM0, XMM0
				MULPS XMM0, XMM1
				VCVTPS2PH XMM0, XMM0, 0
				MOVQ [RCX], XMM0
				ADD RAX, 8
				ADD RCX, 8
				SUB RDX, 4
				JMP Loop4
			Reminder2:
				CMP RDX, 2
				JL Reminder1
				MOVD XMM0, [RAX]
				VCVTPH2PS XMM0, XMM0
				MULPS XMM0, XMM1
				VCVTPS2PH XMM0, XMM0, 0
				MOVD [RCX], XMM0
				ADD RAX, 4
				ADD RCX, 4
				SUB RDX, 2
			Reminder1:
				CMP RDX, 0
				JLE Exit
				MOV AX, [RAX]
				MOVD XMM0, EAX
				VCVTPH2PS XMM0, XMM0
				MULSS XMM0, XMM1
				VCVTPS2PH XMM0, XMM0, 0
				MOVD EAX, XMM0
				MOV [RCX], AX
			Exit:
			END;
		ELSE (* striding single element access *)
			CODE
				MOV RAX, [RBP+laddr]
				MOV RBX, [RBP+raddr]
				MOV RCX, [RBP+daddr]
				MOV RDX, [RBP+len]
				MOV BX, [RBX]
				MOVD XMM1, EBX
				VCVTPH2PS XMM1, XMM1
			Loop:
				CMP RDX, 0
				JLE Exit
				MOV BX, [RAX]
				MOVD XMM0, EBX
				VCVTPH2PS XMM0, XMM0
				MULSS XMM0, XMM1
				VCVTPS2PH XMM0, XMM0, 0
				MOVD EBX, XMM0
				MOV [RCX], BX
				ADD RAX, [RBP+linc]
				ADD RCX, [RBP+dinc]
				SUB RDX, 1
				JMP Loop
			Exit:
			END;
		END;
	END MulScalarLoop;

	PROCEDURE DivLoop( laddr, raddr, daddr: ADDRESS; linc, rinc, dinc, len: SIZE );
	BEGIN
		IF (linc = 2) & (rinc = 2) & (dinc = 2) THEN
			CODE
				MOV RAX, [RBP+laddr]
				MOV RBX, [RBP+raddr]
				MOV RCX, [RBP+daddr]
				MOV RDX, [RBP+len]
			Loop4:
				CMP RDX, 4
				JL Reminder2
				MOVQ XMM0, [RAX]
				VCVTPH2PS XMM0, XMM0
				MOVQ XMM1, [RBX]
				VCVTPH2PS XMM1, XMM1
				DIVPS XMM0, XMM1
				VCVTPS2PH XMM0, XMM0, 0
				MOVQ [RCX], XMM0
				ADD RAX, 8
				ADD RBX, 8
				ADD RCX, 8
				SUB RDX, 4
				JMP Loop4
			Reminder2:
				CMP RDX, 2
				JL Reminder1
				MOV [RBP+len], RDX
				MOVD XMM0, [RAX]
				MOVD XMM1, [RBX]
				VCVTPH2PS XMM0, XMM0
				VCVTPH2PS XMM1, XMM1
				DIVPS XMM0, XMM1
				VCVTPS2PH XMM0, XMM0, 0
				MOVD [RCX], XMM0
				ADD RAX, 4
				ADD RBX, 4
				ADD RCX, 4
				MOV RDX, [RBP+len]
				SUB RDX, 2
			Reminder1:
				CMP RDX, 0
				JLE Exit
				MOV AX, [RAX]
				MOVD XMM0, EAX
				MOV BX, [RBX]
				MOVD XMM1, EBX
				VCVTPH2PS XMM0, XMM0
				VCVTPH2PS XMM1, XMM1
				DIVSS XMM0, XMM1
				VCVTPS2PH XMM0, XMM0, 0
				MOVD RAX, XMM0
				MOV [RCX], AX
			Exit:
			END;
		ELSE (* striding single element access *)
			CODE
				MOV RAX, [RBP+laddr]
				MOV RBX, [RBP+raddr]
				MOV RCX, [RBP+daddr]
			Loop:
				MOV RDX, [RBP+len]
				CMP RDX, 0
				JLE Exit
				SUB RDX, 1
				MOV [RBP+len], RDX
				MOV DX, [RAX]
				MOVD XMM0, EDX
				MOV DX, [RBX]
				MOVD XMM1, EDX
				VCVTPH2PS XMM0, XMM0
				VCVTPH2PS XMM1, XMM1
				DIVSS XMM0, XMM1
				VCVTPS2PH XMM0, XMM0, 0
				MOVD RDX, XMM0
				MOV [RCX], DX
				ADD RAX, [RBP+linc]
				ADD RBX, [RBP+rinc]
				ADD RCX, [RBP+dinc]
				JMP Loop
			Exit:
			END;
		END;
	END DivLoop;

	(* array@daddr := scalar@raddr / array@laddr *)
	PROCEDURE DivScalarLoop(laddr, raddr, daddr: ADDRESS; linc, dinc, len: SIZE);
	BEGIN
		IF (linc = 2) & (dinc = 2) THEN
			CODE
				MOV RAX, [RBP+laddr]
				MOV RBX, [RBP+raddr]
				MOV RCX, [RBP+daddr]
				MOV RDX, [RBP+len]
				MOV BX, [RBX]
				MOVD XMM1, EBX
				VCVTPH2PS XMM1, XMM1
				SHUFPS XMM1, XMM1, 0
			Loop4:
				CMP RDX, 4
				JL Reminder2
				MOVQ XMM0, [RAX]
				VCVTPH2PS XMM0, XMM0
				DIVPS XMM0, XMM1
				VCVTPS2PH XMM0, XMM0, 0
				MOVQ [RCX], XMM0
				ADD RAX, 8
				ADD RCX, 8
				SUB RDX, 4
				JMP Loop4
			Reminder2:
				CMP RDX, 2
				JL Reminder1
				MOVD XMM0, [RAX]
				VCVTPH2PS XMM0, XMM0
				DIVPS XMM0, XMM1
				VCVTPS2PH XMM0, XMM0, 0
				MOVD [RCX], XMM0
				ADD RAX, 4
				ADD RCX, 4
				SUB RDX, 2
			Reminder1:
				CMP RDX, 0
				JLE Exit
				MOV AX, [RAX]
				MOVD XMM0, EAX
				VCVTPH2PS XMM0, XMM0
				DIVSS XMM0, XMM1
				VCVTPS2PH XMM0, XMM0, 0
				MOVD EAX, XMM0
				MOV [RCX], AX
			Exit:
			END;
		ELSE (* striding single element access *)
			CODE
				MOV RAX, [RBP+laddr]
				MOV RBX, [RBP+raddr]
				MOV RCX, [RBP+daddr]
				MOV RDX, [RBP+len]
				MOV BX, [RBX]
				MOVD XMM1, EBX
				VCVTPH2PS XMM1, XMM1
			Loop:
				CMP RDX, 0
				JLE Exit
				MOV BX, [RAX]
				MOVD XMM0, EBX
				VCVTPH2PS XMM0, XMM0
				DIVSS XMM0, XMM1
				VCVTPS2PH XMM0, XMM0, 0
				MOVD EBX, XMM0
				MOV [RCX], BX
				ADD RAX, [RBP+linc]
				ADD RCX, [RBP+dinc]
				SUB RDX, 1
				JMP Loop
			Exit:
			END;
		END;
	END DivScalarLoop;

	PROCEDURE ScalarDivLoop(laddr, raddr, daddr: ADDRESS; linc, dinc, len: SIZE);
	BEGIN
		IF (linc = 2) & (dinc = 2) THEN
			CODE
				MOV RAX, [RBP+laddr]
				MOV RBX, [RBP+raddr]
				MOV RCX, [RBP+daddr]
				MOV RDX, [RBP+len]
				MOV BX, [RBX]
				MOVD XMM1, EBX
				VCVTPH2PS XMM1, XMM1
				SHUFPS XMM1, XMM1, 0
			Loop4:
				CMP RDX, 4
				JL Reminder2
				MOVQ XMM0, [RAX]
				VCVTPH2PS XMM0, XMM0
				MOVAPS XMM2, XMM1
				DIVPS XMM2, XMM0
				VCVTPS2PH XMM0, XMM2, 0
				MOVQ [RCX], XMM0
				ADD RAX, 8
				ADD RCX, 8
				SUB RDX, 4
				JMP Loop4
			Reminder2:
				CMP RDX, 2
				JL Reminder1
				MOVD XMM0, [RAX]
				VCVTPH2PS XMM0, XMM0
				MOVAPS XMM2, XMM1
				DIVPS XMM2, XMM0
				VCVTPS2PH XMM0, XMM2, 0
				MOVD [RCX], XMM0
				ADD RAX, 4
				ADD RCX, 4
				SUB RDX, 2
			Reminder1:
				CMP RDX, 0
				JLE Exit
				MOV AX, [RAX]
				MOVD XMM0, EAX
				VCVTPH2PS XMM0, XMM0
				MOVAPS XMM2, XMM1
				DIVSS XMM2, XMM0
				VCVTPS2PH XMM0, XMM2, 0
				MOVD EAX, XMM0
				MOV [RCX], AX
			Exit:
			END;
		ELSE (* striding single element access *)
			CODE
				MOV RAX, [RBP+laddr]
				MOV RBX, [RBP+raddr]
				MOV RCX, [RBP+daddr]
				MOV RDX, [RBP+len]
				MOV BX, [RBX]
				MOVD XMM1, EBX
				VCVTPH2PS XMM1, XMM1
			Loop:
				CMP RDX, 0
				JLE Exit
				MOV BX, [RAX]
				MOVD XMM0, EBX
				VCVTPH2PS XMM0, XMM0
				MOVAPS XMM2, XMM1
				DIVSS XMM2, XMM0
				VCVTPS2PH XMM0, XMM2, 0
				MOVD EBX, XMM0
				MOV [RCX], BX
				ADD RAX, [RBP+linc]
				ADD RCX, [RBP+dinc]
				SUB RDX, 1
				JMP Loop
			Exit:
			END;
		END;
	END ScalarDivLoop;

	PROCEDURE InnerProdLoop(laddr, raddr, daddr: ADDRESS; linc, rinc, len: SIZE);
	BEGIN
		IF (linc = 2) & (rinc = 2) THEN
			CODE
				MOV RAX, [RBP+laddr]
				MOV RBX, [RBP+raddr]
				MOV RCX, [RBP+len]
				MOV RDX, [RBP+daddr]
				MOVD XMM0, [RDX]
			Loop4:
				CMP RCX, 4
				JL Reminder2
				MOVQ XMM1, [RAX]
				MOVQ XMM2, [RBX]
				VCVTPH2PS XMM1, XMM1
				VCVTPH2PS XMM2, XMM2
				MULPS XMM1, XMM2
				ADDPS XMM0, XMM1
				ADD RAX, 8
				SUB RCX, 4
				JMP Loop4
			Reminder2:
				CMP RCX, 2
				JL Reminder1
				MOV EDX, [RAX]
				MOVD XMM1, EDX
				MOV EDX, [RBX]
				MOVD XMM2, EDX
				VCVTPH2PS XMM1, XMM1
				VCVTPH2PS XMM2, XMM2
				MULPS XMM1, XMM2
				ADDPS XMM0, XMM1
				ADD RAX, 4
				SUB RCX, 2
			Reminder1:
				CMP RCX, 0
				JLE Exit
				MOV AX, [RAX]
				MOV BX, [RBX]
				MOVD XMM1, EAX
				MOVD XMM2, EBX
				VCVTPH2PS XMM1, XMM1
				VCVTPH2PS XMM2, XMM2
				MULSS XMM1, XMM2
				ADDSS XMM0, XMM1
			Exit:
				HADDPS XMM0, XMM0
				HADDPS XMM0, XMM0
				MOV RDX, [RBP+daddr]
				MOVD [RDX], XMM0
			END;
		ELSE
			CODE
				MOV RAX, [RBP+laddr]
				MOV RBX, [RBP+raddr]
				MOV RCX, [RBP+len]
				MOV RDX, [RBP+daddr]
				MOVD XMM0, [RDX]
			Loop:
				CMP RCX, 0
				JLE Exit
				MOV DX, [RAX]
				MOVD XMM1, EDX
				MOV DX, [RBX]
				MOVD XMM2, EDX
				VCVTPH2PS XMM1, XMM1
				VCVTPH2PS XMM2, XMM2
				MULSS XMM1, XMM2
				ADDSS XMM0, XMM1
				ADD RAX, [RBP+linc]
				ADD RBX, [RBP+rinc]
				SUB RCX, 1
				JMP Loop
			Exit:
				MOV RDX, [RBP+daddr]
				MOVD [RDX], XMM0
			END;
		END;
	END InnerProdLoop;

	PROCEDURE MatMulLoop(laddr, raddr, daddr: ADDRESS; linc, rinc, len: SIZE);
	VAR y: FLOAT32;
	BEGIN
		InnerProdLoop(laddr,raddr,ADDRESS OF y,linc,rinc,len);
		SYSTEM.PUT16(daddr,RealToShortreal(y));
	END MatMulLoop;

	PROCEDURE EqualLoop( laddr, raddr: ADDRESS; linc, rinc, len: SIZE ): BOOLEAN;
	VAR
		b: BOOLEAN;
	BEGIN
		(*!TODO: optimize contiguous case *)
		IF FALSE(*(linc = 2) & (rinc = 2)*) THEN
		ELSE (* striding single element access *)
			CODE
				MOV RAX, [RBP+laddr]
				MOV RBX, [RBP+raddr]
				MOV RCX, [RBP+len]
			Loop:
				CMP RCX, 0
				JLE EQ
				MOV DX, [RAX]
				MOVD XMM0, EDX
				MOV DX, [RBX]
				MOVD XMM1, EDX
				VCVTPH2PS XMM0, XMM0
				VCVTPH2PS XMM1, XMM1
				COMISS XMM0, XMM1
				JNE Exit
				ADD RAX, [RBP+linc]
				ADD RBX, [RBP+rinc]
				JMP Loop
			EQ:
				MOV [RBP+b], 1
			Exit:
			END;
		END;
		RETURN b;
	END EqualLoop;

	PROCEDURE LessThanLoop( laddr, raddr: ADDRESS; linc, rinc, len: SIZE ): BOOLEAN;
	VAR
		b: BOOLEAN;
	BEGIN
		(*!TODO: optimize contiguous case *)
		IF FALSE(*(linc = 2) & (rinc = 2)*) THEN
		ELSE (* striding single element access *)
			CODE
				MOV RAX, [RBP+laddr]
				MOV RBX, [RBP+raddr]
				MOV RCX, [RBP+len]
			Loop:
				CMP RCX, 0
				JLE LT
				MOV DX, [RAX]
				MOVD XMM0, EDX
				MOV DX, [RBX]
				MOVD XMM1, EDX
				VCVTPH2PS XMM0, XMM0
				VCVTPH2PS XMM1, XMM1
				COMISS XMM0, XMM1
				JGE Exit
				ADD RAX, [RBP+linc]
				ADD RBX, [RBP+rinc]
				JMP Loop
			LT:
				MOV [RBP+b], 1
			Exit:
			END;
		END;
		RETURN b;
	END LessThanLoop;

	PROCEDURE GreaterThanLoop( laddr, raddr: ADDRESS; linc, rinc, len: SIZE ): BOOLEAN;
	VAR
		b: BOOLEAN;
	BEGIN
		(*!TODO: optimize contiguous case *)
		IF FALSE(*(linc = 2) & (rinc = 2)*) THEN
		ELSE (* striding single element access *)
			CODE
				MOV RAX, [RBP+laddr]
				MOV RBX, [RBP+raddr]
				MOV RCX, [RBP+len]
			Loop:
				CMP RCX, 0
				JLE GT
				MOV DX, [RAX]
				MOVD XMM0, EDX
				MOV DX, [RBX]
				MOVD XMM1, EDX
				VCVTPH2PS XMM0, XMM0
				VCVTPH2PS XMM1, XMM1
				COMISS XMM0, XMM1
				JLE Exit
				ADD RAX, [RBP+linc]
				ADD RBX, [RBP+rinc]
				JMP Loop
			GT:
				MOV [RBP+b], 1
			Exit:
			END;
		END;
		RETURN b;
	END GreaterThanLoop;

	PROCEDURE EwEqualLoop( laddr, raddr, daddr: ADDRESS; linc, rinc, dinc, len: SIZE );
	BEGIN
		(*!TODO: optimize contiguous case *)
		IF FALSE(*(linc = 2) & (rinc = 2) & (dinc = 1)*) THEN
		ELSE (* striding single element access *)
			CODE
				MOV RAX, [RBP+laddr]
				MOV RBX, [RBP+raddr]
				MOV RCX, [RBP+daddr]
			Loop:
				MOV RDX, [RBP+len]
				CMP RDX, 0
				JLE Exit
				SUB RDX, 1
				MOV [RBP+len], RDX
				MOV DX, [RAX]
				MOVD XMM0, EDX
				MOV DX, [RBX]
				MOVD XMM1, EDX
				VCVTPH2PS XMM0, XMM0
				VCVTPH2PS XMM1, XMM1
				CMPSS XMM0, XMM1, 0
				MOVD RDX, XMM0
				MOV [RCX], DX
				ADD RAX, [RBP+linc]
				ADD RBX, [RBP+rinc]
				ADD RCX, [RBP+dinc]
				JMP Loop
			Exit:
			END;
		END;
	END EwEqualLoop;

	PROCEDURE EwLessThanLoop( laddr, raddr, daddr: ADDRESS; linc, rinc, dinc, len: SIZE );
	BEGIN
		(*!TODO: optimize contiguous case *)
		IF FALSE(*(linc = 2) & (rinc = 2) & (dinc = 1)*) THEN
		ELSE (* striding single element access *)
			CODE
				MOV RAX, [RBP+laddr]
				MOV RBX, [RBP+raddr]
				MOV RCX, [RBP+daddr]
			Loop:
				MOV RDX, [RBP+len]
				CMP RDX, 0
				JLE Exit
				SUB RDX, 1
				MOV [RBP+len], RDX
				MOV DX, [RAX]
				MOVD XMM0, EDX
				MOV DX, [RBX]
				MOVD XMM1, EDX
				VCVTPH2PS XMM0, XMM0
				VCVTPH2PS XMM1, XMM1
				CMPSS XMM0, XMM1, 1
				MOVD RDX, XMM0
				MOV [RCX], DX
				ADD RAX, [RBP+linc]
				ADD RBX, [RBP+rinc]
				ADD RCX, [RBP+dinc]
				JMP Loop
			Exit:
			END;
		END;
	END EwLessThanLoop;

	PROCEDURE EwLessOrEqualThanLoop( laddr, raddr, daddr: ADDRESS; linc, rinc, dinc, len: SIZE );
	BEGIN
		(*!TODO: optimize contiguous case *)
		IF FALSE(*(linc = 2) & (rinc = 2) & (dinc = 1)*) THEN
		ELSE (* striding single element access *)
			CODE
				MOV RAX, [RBP+laddr]
				MOV RBX, [RBP+raddr]
				MOV RCX, [RBP+daddr]
			Loop:
				MOV RDX, [RBP+len]
				CMP RDX, 0
				JLE Exit
				SUB RDX, 1
				MOV [RBP+len], RDX
				MOV DX, [RAX]
				MOVD XMM0, EDX
				MOV DX, [RBX]
				MOVD XMM1, EDX
				VCVTPH2PS XMM0, XMM0
				VCVTPH2PS XMM1, XMM1
				CMPSS XMM0, XMM1, 2
				MOVD RDX, XMM0
				MOV [RCX], DX
				ADD RAX, [RBP+linc]
				ADD RBX, [RBP+rinc]
				ADD RCX, [RBP+dinc]
				JMP Loop
			Exit:
			END;
		END;
	END EwLessOrEqualThanLoop;

	PROCEDURE EwGreaterThanLoop( laddr, raddr, daddr: ADDRESS; linc, rinc, dinc, len: SIZE );
	BEGIN
		(*!TODO: optimize contiguous case *)
		IF FALSE(*(linc = 2) & (rinc = 2) & (dinc = 1)*) THEN
		ELSE (* striding single element access *)
			CODE
				MOV RAX, [RBP+laddr]
				MOV RBX, [RBP+raddr]
				MOV RCX, [RBP+daddr]
			Loop:
				MOV RDX, [RBP+len]
				CMP RDX, 0
				JLE Exit
				SUB RDX, 1
				MOV [RBP+len], RDX
				MOV DX, [RAX]
				MOVD XMM0, EDX
				MOV DX, [RBX]
				MOVD XMM1, EDX
				VCVTPH2PS XMM0, XMM0
				VCVTPH2PS XMM1, XMM1
				CMPSS XMM0, XMM1, 6
				MOVD RDX, XMM0
				MOV [RCX], DX
				ADD RAX, [RBP+linc]
				ADD RBX, [RBP+rinc]
				ADD RCX, [RBP+dinc]
				JMP Loop
			Exit:
			END;
		END;
	END EwGreaterThanLoop;

	PROCEDURE EwGreaterOrEqualThanLoop( laddr, raddr, daddr: ADDRESS; linc, rinc, dinc, len: SIZE );
	BEGIN
		(*!TODO: optimize contiguous case *)
		IF FALSE(*(linc = 2) & (rinc = 2) & (dinc = 1)*) THEN
		ELSE (* striding single element access *)
			CODE
				MOV RAX, [RBP+laddr]
				MOV RBX, [RBP+raddr]
				MOV RCX, [RBP+daddr]
			Loop:
				MOV RDX, [RBP+len]
				CMP RDX, 0
				JLE Exit
				SUB RDX, 1
				MOV [RBP+len], RDX
				MOV DX, [RAX]
				MOVD XMM0, EDX
				MOV DX, [RBX]
				MOVD XMM1, EDX
				VCVTPH2PS XMM0, XMM0
				VCVTPH2PS XMM1, XMM1
				CMPSS XMM0, XMM1, 5
				MOVD RDX, XMM0
				MOV [RCX], DX
				ADD RAX, [RBP+linc]
				ADD RBX, [RBP+rinc]
				ADD RCX, [RBP+dinc]
				JMP Loop
			Exit:
			END;
		END;
	END EwGreaterOrEqualThanLoop;

	PROCEDURE SqrtLoop(laddr, daddr: ADDRESS; linc, dinc, len: SIZE);
	BEGIN
		IF (linc = 2) & (dinc = 2) THEN
			CODE
				MOV RAX, [RBP+laddr]
				MOV RCX, [RBP+daddr]
				MOV RDX, [RBP+len]
			Loop4:
				CMP RDX, 4
				JL Reminder2
				MOVQ XMM0, [RAX]
				VCVTPH2PS XMM0, XMM0
				SQRTPS XMM0, XMM0
				VCVTPS2PH XMM0, XMM0, 0
				MOVQ [RCX], XMM0
				ADD RAX, 8
				ADD RCX, 8
				SUB RDX, 4
				JMP Loop4
			Reminder2:
				CMP RDX, 2
				JL Reminder1
				MOVD XMM0, [RAX]
				VCVTPH2PS XMM0, XMM0
				SQRTPS XMM0, XMM1
				VCVTPS2PH XMM0, XMM0, 0
				MOVD [RCX], XMM0
				ADD RAX, 4
				ADD RCX, 4
				SUB RDX, 2
			Reminder1:
				CMP RDX, 0
				JLE Exit
				MOV AX, [RAX]
				MOVD XMM0, EAX
				VCVTPH2PS XMM0, XMM0
				SQRTSS XMM0, XMM0
				VCVTPS2PH XMM0, XMM0, 0
				MOVD EAX, XMM0
				MOV [RCX], AX
			Exit:
			END;
		ELSE (* striding single element access *)
			CODE
				MOV RAX, [RBP+laddr]
				MOV RCX, [RBP+daddr]
				MOV RDX, [RBP+len]
			Loop:
				CMP RDX, 0
				JLE Exit
				MOV BX, [RAX]
				MOVD XMM0, EBX
				VCVTPH2PS XMM0, XMM0
				SQRTSS XMM0, XMM0
				VCVTPS2PH XMM0, XMM0, 0
				MOVD EBX, XMM0
				MOV [RCX], BX
				ADD RAX, [RBP+linc]
				ADD RCX, [RBP+dinc]
				SUB RDX, 1
				JMP Loop
			Exit:
			END;
		END;
	END SqrtLoop;

	PROCEDURE SinLoop(laddr, daddr: ADDRESS; linc, dinc, len: SIZE);
	CODE
		MOV RAX, [RBP+laddr]
		MOV RCX, [RBP+daddr]
		MOV RDX, [RBP+len]
		SUB RSP, 4 ; create a local variable of type FLOAT32
	Loop:
		CMP RDX, 0
		JLE Exit
		MOV BX, [RAX]
		MOVD XMM0, EBX
		VCVTPH2PS XMM0, XMM0
		MOVD [RSP], XMM0
		FLD [RSP]
		FSIN
		FST [RSP]
		MOVSS XMM0, [RSP]
		VCVTPS2PH XMM0, XMM0, 0
		MOVD EBX, XMM0
		MOV [RCX], BX
		ADD RAX, [RBP+linc]
		ADD RCX, [RBP+dinc]
		SUB RDX, 1
		JMP Loop
	Exit:
		ADD RSP, 4 ; remove local variable
	END SinLoop;

	PROCEDURE CosLoop(laddr, daddr: ADDRESS; linc, dinc, len: SIZE);
	CODE
		MOV RAX, [RBP+laddr]
		MOV RCX, [RBP+daddr]
		MOV RDX, [RBP+len]
		SUB RSP, 4 ; create a local variable of type FLOAT32
	Loop:
		CMP RDX, 0
		JLE Exit
		MOV BX, [RAX]
		MOVD XMM0, EBX
		VCVTPH2PS XMM0, XMM0
		MOVD [RSP], XMM0
		FLD [RSP]
		FCOS
		FST [RSP]
		MOVSS XMM0, [RSP]
		VCVTPS2PH XMM0, XMM0, 0
		MOVD EBX, XMM0
		MOV [RCX], BX
		ADD RAX, [RBP+linc]
		ADD RCX, [RBP+dinc]
		SUB RDX, 1
		JMP Loop
	Exit:
		ADD RSP, 4 ; remove local variable
	END CosLoop;

	PROCEDURE ArctanLoop(laddr, daddr: ADDRESS; linc, dinc, len: SIZE);
	CODE
		MOV RAX, [RBP+laddr]
		MOV RCX, [RBP+daddr]
		MOV RDX, [RBP+len]
		SUB RSP, 4 ; create a local variable of type FLOAT32
	Loop:
		CMP RDX, 0
		JLE Exit
		MOV BX, [RAX]
		MOVD XMM0, EBX
		VCVTPH2PS XMM0, XMM0
		MOVD [RSP], XMM0
		FLD [RSP]
		FLD1
		FPATAN
		FST [RSP]
		MOVSS XMM0, [RSP]
		VCVTPS2PH XMM0, XMM0, 0
		MOVD EBX, XMM0
		MOV [RCX], BX
		ADD RAX, [RBP+linc]
		ADD RCX, [RBP+dinc]
		SUB RDX, 1
		JMP Loop
	Exit:
		ADD RSP, 4 ; remove local variable
	END ArctanLoop;

	PROCEDURE LnLoop(laddr, daddr: ADDRESS; linc, dinc, len: SIZE);
	CODE
		MOV RAX, [RBP+laddr]
		MOV RCX, [RBP+daddr]
		MOV RDX, [RBP+len]
		SUB RSP, 4 ; create a local variable of type FLOAT32
	Loop:
		CMP RDX, 0
		JLE Exit
		MOV BX, [RAX]
		MOVD XMM0, EBX
		VCVTPH2PS XMM0, XMM0
		MOVD [RSP], XMM0
		FLD1
		FLDL2E
		FDIVP
		FLD [RSP]
		FYL2X
		FST [RSP]
		MOVSS XMM0, [RSP]
		VCVTPS2PH XMM0, XMM0, 0
		MOVD EBX, XMM0
		MOV [RCX], BX
		ADD RAX, [RBP+linc]
		ADD RCX, [RBP+dinc]
		SUB RDX, 1
		JMP Loop
	Exit:
		ADD RSP, 4 ; remove local variable
	END LnLoop;

	PROCEDURE ExpLoop(laddr, daddr: ADDRESS; linc, dinc, len: SIZE);
	CODE
		MOV RAX, [RBP+laddr]
		MOV RCX, [RBP+daddr]
		MOV RDX, [RBP+len]
		SUB RSP, 4 ; create a local variable of type FLOAT32
	Loop:
		CMP RDX, 0
		JLE Exit
		MOV BX, [RAX]
		MOVD XMM0, EBX
		VCVTPH2PS XMM0, XMM0
		MOVD [RSP], XMM0
		FLD [RSP]
		FLDL2E
		FMULP
		FLD ST0
		FRNDINT
		FXCH ST1
		FSUB ST0, ST1
		F2XM1
		FLD1
		FADDP
		FSCALE
		FSTP ST1
		FST [RSP]
		MOVSS XMM0, [RSP]
		VCVTPS2PH XMM0, XMM0, 0
		MOVD EBX, XMM0
		MOV [RCX], BX
		ADD RAX, [RBP+linc]
		ADD RCX, [RBP+dinc]
		SUB RDX, 1
		JMP Loop
	Exit:
		ADD RSP, 4 ; remove local variable
	END ExpLoop;

	PROCEDURE ShortrealToReal(x: UNSIGNED16): FLOAT32;
	CODE
		MOV AX, [RBP+x] ; load U16
		MOVD XMM0, EAX
		VCVTPH2PS XMM0, XMM0 ; result is returned in XMM0
	END ShortrealToReal;

	PROCEDURE RealToShortreal(x: FLOAT32): UNSIGNED16;
	CODE
		MOVD XMM0, [RBP+x]
		VCVTPS2PH XMM0, XMM0, 0
		MOVD RAX, XMM0 ; result is returned in RAX
	END RealToShortreal;

VAR
	eps-: SHORTREAL;

	PROCEDURE InitMod;
	VAR i: SIZE;
	BEGIN
		eps := SHORT(1.0);
		FOR i := 0 TO 9 DO
			eps := eps / SHORT(2.0);
		END;
	END InitMod;

TYPE
	SHORTREAL* = RECORD
		value*: UNSIGNED16;

		PROCEDURE Sqrt*(): SHORTREAL;
		VAR y: SHORTREAL;
		BEGIN
			y.value := Sqrt0(value);
			RETURN y;
		END Sqrt;

		PROCEDURE Sin*(): SHORTREAL;
		VAR y: SHORTREAL;
		BEGIN
			y.value := Sin0(value);
			RETURN y;
		END Sin;

		PROCEDURE Cos*(): SHORTREAL;
		VAR y: SHORTREAL;
		BEGIN
			y.value := Cos0(value);
			RETURN y;
		END Cos;

		PROCEDURE Arctan*(): SHORTREAL;
		VAR y: SHORTREAL;
		BEGIN
			y.value := Arctan0(value);
			RETURN y;
		END Arctan;

		PROCEDURE Ln*(): SHORTREAL;
		VAR y: SHORTREAL;
		BEGIN
			y.value := Ln0(value);
			RETURN y;
		END Ln;

		PROCEDURE Exp*(): SHORTREAL;
		VAR y: SHORTREAL;
		BEGIN
			y.value := Exp0(value);
			RETURN y;
		END Exp;
	END;

BEGIN
	ASSERT(SIZEOF(SHORTREAL) = 2);
	InitMod;
END Shortreal.

System.FreeDownTo Shortreal ~