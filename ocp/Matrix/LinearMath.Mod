MODULE LinearMath;

IMPORT MatrixBase, Mathe:=MathL, NbrCplx, MathCplx, PMath;

TYPE
	Datatype=MatrixBase.Datatype;
	Array = ARRAY [*] OF Datatype;

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
	VAR i:SIGNED32;
	BEGIN
		IF LEN(RESULT,0)=0 THEN NEW(RESULT,LEN(in,0)) END;
		RESULT:=ALL(in, Mathe.sqrt);
		(*FOR i:=0 TO LEN(in,0)-1 DO
			RESULT[i]:=Mathe.sqrt(in[i])
		END;;*)
		RETURN RESULT
	END Sqrt;

	PROCEDURE Sin*(CONST in:Array):Array;
	VAR i:SIGNED32;
	BEGIN
		IF LEN(RESULT,0)=0 THEN NEW(RESULT,LEN(in,0)) END;
		RESULT:=ALL(in, Mathe.sin);
		(*FOR i:=0 TO LEN(in,0)-1 DO
			RESULT[i]:=Mathe.sin(in[i])
		END;;*)
		RETURN RESULT
	END Sin;

	PROCEDURE Cos*(CONST in:Array):Array;
	VAR i:SIGNED32;
	BEGIN
		IF LEN(RESULT,0)=0 THEN NEW(RESULT,LEN(in,0)) END;
		RESULT:=ALL(in, Mathe.cos);
		(*FOR i:=0 TO LEN(in,0)-1 DO
			RESULT[i]:=Mathe.cos(in[i])
		END;;*)
		RETURN RESULT
	END Cos;

	PROCEDURE Arctan*(CONST in:Array):Array;
	VAR i:SIGNED32;
	BEGIN
		IF LEN(RESULT,0)=0 THEN NEW(RESULT,LEN(in,0)) END;
		RESULT:=ALL(in, Mathe.arctan);
		(*FOR i:=0 TO LEN(in,0)-1 DO
			RESULT[i]:=Mathe.arctan(in[i])
		END;;*)
		RETURN RESULT
	END Arctan;

	PROCEDURE Tanh*(CONST in:Array):Array;
	BEGIN
		IF LEN(RESULT)#LEN(in) THEN NEW(RESULT,LEN(in))  END;
		RESULT:=ALL(in, PMath.tanhL);
		RETURN RESULT
	END Tanh;

	PROCEDURE Ln*(CONST in:Array):Array;
	VAR i:SIGNED32;
	BEGIN
		IF LEN(RESULT,0)=0 THEN NEW(RESULT,LEN(in,0)) END;
		RESULT:=ALL(in, Mathe.ln);
		(*FOR i:=0 TO LEN(in,0)-1 DO
			RESULT[i]:=Mathe.ln(in[i])
		END;;*)
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
	VAR rsqr:Array;
	BEGIN
		outR := R1 .* R2;
		outR := outR - I1 .* I2;
		outI := I1 .* R2;  outI := outI + R1 .* I2;
	END ComplexMultiplication;

	PROCEDURE ComplexSqrt*( CONST R,I:Array; VAR outR,outI:Array);
	VAR cplx,root:NbrCplx.Complex; i:SIZE; re,im:FLOAT32;
	BEGIN
		FOR i:=0 TO LEN(R,0)-1 DO
			IF LEN(I)=0 THEN NbrCplx.Set(SHORT(R[i]),0, cplx);
			ELSE NbrCplx.Set(SHORT(R[i]),SHORT(I[i]), cplx); (*hack: NbrCplx can be compiled for FLOAT32 or FLOAT64*)
			END;
			root:=MathCplx.Sqrt(cplx);
			NbrCplx.Get(root, re,im);
			outR[i]:=re; outI[i]:=im; (*hack: NbrCplx can be compiled for FLOAT32 or FLOAT64*)
		END;
	END ComplexSqrt;


END LinearMath.

SystemTools.FreeDownTo LinearMath ~
