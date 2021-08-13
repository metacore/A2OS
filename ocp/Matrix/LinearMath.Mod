MODULE LinearMath;

IMPORT MatrixBase, Mathe:=MathL, NbrCplx, NbrRe, MathCplx, PMath;

TYPE
	Datatype=MatrixBase.Datatype;
	Array = ARRAY [*] OF Datatype;

	PROCEDURE sqrt*(x: Datatype): Datatype;
	BEGIN
		RETURN Datatype(Mathe.sqrt(x));
	END sqrt;

	PROCEDURE sin*(x: Datatype): Datatype;
	BEGIN
		RETURN Datatype(Mathe.sin(x));
	END sin;

	PROCEDURE cos*(x: Datatype): Datatype;
	BEGIN
		RETURN Datatype(Mathe.cos(x));
	END cos;

	PROCEDURE arctan*(x: Datatype): Datatype;
	BEGIN
		RETURN Datatype(Mathe.arctan(x));
	END arctan;

	PROCEDURE tanh*(x: Datatype): Datatype;
	BEGIN
		RETURN Datatype(PMath.tanhL(x));
	END tanh;
	
	PROCEDURE logistic*(x: Datatype): Datatype;
	BEGIN
		RETURN Datatype(PMath.logisticL(x));
	END logistic;

	PROCEDURE ln*(x: Datatype): Datatype;
	BEGIN
		RETURN Datatype(Mathe.ln(x));
	END ln;

	PROCEDURE Max*(CONST a,b:Array):Array;
	VAR i:SIZE;
	BEGIN
		ASSERT(LEN(a,0)=LEN(b,0));
		IF LEN(RESULT,0)=0 THEN NEW(RESULT,LEN(a,0)) END;
		FOR i:=0 TO LEN(a,0)-1 DO
			RESULT[i]:=MAX(a[i],b[i])
		END;
		RETURN RESULT
	END Max;

	PROCEDURE Min*(CONST a,b:Array):Array;
	VAR i:SIZE;
	BEGIN
		ASSERT(LEN(a,0)=LEN(b,0));
		IF LEN(RESULT,0)=0 THEN NEW(RESULT,LEN(a,0)) END;
		FOR i:=0 TO LEN(a,0)-1 DO
			RESULT[i]:=MIN(a[i],b[i])
		END;
		RETURN RESULT
	END Min;

	PROCEDURE Sqr*(CONST in:Array):Array;
	BEGIN
		RETURN in.*in
	END Sqr;

	PROCEDURE Sqrt*(CONST in:Array):Array;
	BEGIN
		IF LEN(RESULT,0)=0 THEN NEW(RESULT,LEN(in,0)) END;
		RESULT:=ALL(in, sqrt);
		RETURN RESULT
	END Sqrt;

	PROCEDURE Sin*(CONST in:Array):Array;
	BEGIN
		IF LEN(RESULT,0)=0 THEN NEW(RESULT,LEN(in,0)) END;
		RESULT:=ALL(in, sin);
		RETURN RESULT
	END Sin;

	PROCEDURE Cos*(CONST in:Array):Array;
	BEGIN
		IF LEN(RESULT,0)=0 THEN NEW(RESULT,LEN(in,0)) END;
		RESULT:=ALL(in, cos);
		RETURN RESULT
	END Cos;

	PROCEDURE Arctan*(CONST in:Array):Array;
	BEGIN
		IF LEN(RESULT,0)=0 THEN NEW(RESULT,LEN(in,0)) END;
		RESULT:=ALL(in, arctan);
		RETURN RESULT
	END Arctan;

	PROCEDURE Tanh*(CONST in:Array):Array;
	BEGIN
		IF LEN(RESULT)#LEN(in) THEN NEW(RESULT,LEN(in))  END;
		RESULT:=ALL(in, tanh);
		RETURN RESULT
	END Tanh;

	PROCEDURE Logistic*(CONST in:Array):Array;
	BEGIN
		IF LEN(RESULT)#LEN(in) THEN NEW(RESULT,LEN(in))  END;
		RESULT:=ALL(in, logistic);
		RETURN RESULT
	END Logistic;

	PROCEDURE Ln*(CONST in:Array):Array;
	BEGIN
		IF LEN(RESULT,0)=0 THEN NEW(RESULT,LEN(in,0)) END;
		RESULT:=ALL(in, ln);
		RETURN RESULT
	END Ln;

	PROCEDURE ComplexDivision*(CONST R1,I1,R2,I2: Array; VAR outR,outI:Array);
	VAR rsqr:Array;
	BEGIN
		rsqr:=R2.*R2;  rsqr:= rsqr + I2 .*I2;
		outR := R1 .* R2;   outR := outR + I1 .* I2;
		outI := I1 .* R2;  outI := outI - R1 .* I2;
		outR:= outR ./ rsqr; (*! NOT protected against division by zero*)
		outI:= outI ./ rsqr;
	END ComplexDivision;

	PROCEDURE ComplexMultiplication*(CONST R1,I1,R2,I2: Array; VAR outR,outI:Array);
	BEGIN
		outR := R1 .* R2;
		outR := outR - I1 .* I2;
		outI := I1 .* R2;  outI := outI + R1 .* I2;
	END ComplexMultiplication;

	PROCEDURE ComplexSqrt*( CONST R,I:Array; VAR outR,outI:Array);
	VAR cplx,root:NbrCplx.Complex; i:SIZE; re,im:FLOAT32;
	BEGIN
		FOR i:=0 TO LEN(R,0)-1 DO
			IF LEN(I)=0 THEN NbrCplx.Set(NbrRe.Real(R[i]),0, cplx);
			ELSE NbrCplx.Set(NbrRe.Real(R[i]),NbrRe.Real(I[i]), cplx); (*hack: NbrCplx can be compiled for FLOAT32 or FLOAT64*)
			END;
			root:=MathCplx.Sqrt(cplx);
			NbrCplx.Get(root, re,im);
			outR[i]:=re; outI[i]:=im; (*hack: NbrCplx can be compiled for FLOAT32 or FLOAT64*)
		END;
	END ComplexSqrt;


END LinearMath.

SystemTools.FreeDownTo LinearMath ~
