MODULE TensorMath;

(*To do: complex derivatives including complex optimization algorithms: see
Kenneth Kreutz-Delgado : The Complex Gradient Operator and the CR-Calculus.
ECE275A - Lecture Supplement - Fall 2006: "complex_derivatives.pdf *)

IMPORT MatrixBase, LinearMath, Mathe:=MathL, PMath;

TYPE
	Datatype=MatrixBase.Datatype;
	Array = ARRAY [?] OF Datatype;

	PROCEDURE Max*(CONST a,b:Array):Array;
	VAR i:SIZE;
	BEGIN
		ASSERT(LEN(a)=LEN(b));
		IF LEN(RESULT,0)#LEN(a) THEN NEW(RESULT,LEN(a,0),LEN(a,1)) END;
		IF DIM(a)=1 THEN
			RESULT[..]:=LinearMath.Max(a[..],b[..])
		ELSE
			FOR i:=0 TO LEN(a,0)-1 DO
				RESULT[i,?]:=LinearMath.Max(a[i,?],b[i,?])
			END;
		END;
		RETURN RESULT
	END Max;

	PROCEDURE Min*(CONST a,b:Array):Array;
	VAR i:SIZE;
	BEGIN
		ASSERT(LEN(a)=LEN(b));
		IF LEN(RESULT,0)#LEN(a) THEN NEW(RESULT,LEN(a,0),LEN(a,1)) END;
		IF DIM(a)=1 THEN
			RESULT[..]:=LinearMath.Max(a[..],b[..])
		ELSE
			FOR i:=0 TO LEN(a,0)-1 DO
				RESULT[i,?]:=LinearMath.Min(a[i,?],b[i,?])
			END;
		END;
		RETURN RESULT
	END Min;

	PROCEDURE Sqr*(CONST in:Array):Array;
	BEGIN
		RETURN in.*in
	END Sqr;

	PROCEDURE Sqrt*(CONST in:Array):Array;
	BEGIN
		IF LEN(RESULT)#LEN(in) THEN NEW(RESULT,LEN(in))  END;
		RESULT:=ALL(in, Mathe.sqrt);
		RETURN RESULT
	END Sqrt;

	PROCEDURE Sin*(CONST in:Array):Array;
	BEGIN
		IF LEN(RESULT)#LEN(in) THEN NEW(RESULT,LEN(in))  END;
		RESULT:=ALL(in, Mathe.sin);
		RETURN RESULT
	END Sin;

	PROCEDURE Cos*(CONST in:Array):Array;
	BEGIN
		IF LEN(RESULT)#LEN(in) THEN NEW(RESULT,LEN(in))  END;
		RESULT:=ALL(in, Mathe.cos);
		RETURN RESULT
	END Cos;

	PROCEDURE Arctan*(CONST in:Array):Array;
	BEGIN
		IF LEN(RESULT)#LEN(in) THEN NEW(RESULT,LEN(in))  END;
		RESULT:=ALL(in, Mathe.arctan);
		RETURN RESULT
	END Arctan;

	PROCEDURE Tanh*(CONST in:Array):Array;
	BEGIN
		IF LEN(RESULT)#LEN(in) THEN NEW(RESULT,LEN(in))  END;
		RESULT:=ALL(in, PMath.tanhL);
		RETURN RESULT
	END Tanh;

	PROCEDURE Logistic*(CONST in:Array):Array;
	BEGIN
		IF LEN(RESULT)#LEN(in) THEN NEW(RESULT,LEN(in))  END;
		RESULT:=ALL(in, PMath.logisticL);
		RETURN RESULT
	END Logistic;

	PROCEDURE Ln*(CONST in:Array):Array;
	BEGIN
		IF LEN(RESULT)#LEN(in) THEN NEW(RESULT,LEN(in))  END;
		RESULT:=ALL(in, Mathe.ln);
		RETURN RESULT
	END Ln;

	PROCEDURE ComplexDivision*(CONST R1,I1,R2,I2: Array; VAR outR,outI:Array);
	VAR rsqr:Array;
	BEGIN
		rsqr:=R2.*R2;  rsqr:= rsqr + I2 .*I2;
		outR := R1 .* R2;   outR := outR + I1 .* I2;
		outI := I1 .* R2;  outI := outI - R1 .* I2;
		outR:= outR ./ rsqr;
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
	VAR  i:SIZE;
	BEGIN
		IF DIM(R)=1 THEN
			LinearMath.ComplexSqrt(R,I, outR[..], outI[..]);
		ELSE
			FOR i:=0 TO LEN(R,0)-1 DO
				ComplexSqrt(R[i,?],I[i,?], outR[i,?],outI[i,?]);
			END;
		END;
	END ComplexSqrt;


END TensorMath.

SystemTools.FreeDownTo TensorMath
