MODULE PlanarMath;

(*To do: complex derivatives including complex optimization algorithms: see
Kenneth Kreutz-Delgado : The Complex Gradient Operator and the CR-Calculus.
ECE275A - Lecture Supplement - Fall 2006: "complex_derivatives.pdf *)

IMPORT MatrixBase, LinearMath, Mathe:=MathL, PMath;

TYPE
	Datatype=MatrixBase.Datatype;
	Array = ARRAY [*,*] OF Datatype;

	PROCEDURE Max*(CONST a,b:Array):Array;
	VAR i:SIZE;
	BEGIN
		ASSERT(LEN(a)=LEN(b));
		IF LEN(RESULT,0)#LEN(a) THEN NEW(RESULT,LEN(a,0),LEN(a,1)) END;
		FOR i:=0 TO LEN(a,0)-1 DO
			RESULT[i]:=LinearMath.Max(a[i],b[i])
		END;
		RETURN RESULT
	END Max;

	PROCEDURE Min*(CONST a,b:Array):Array;
	VAR i:SIZE;
	BEGIN
		ASSERT(LEN(a)=LEN(b));
		IF LEN(RESULT,0)#LEN(a) THEN NEW(RESULT,LEN(a,0),LEN(a,1)) END;
		FOR i:=0 TO LEN(a,0)-1 DO
			RESULT[i]:=LinearMath.Min(a[i],b[i])
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
		IF LEN(RESULT)#LEN(in) THEN NEW(RESULT,LEN(in,0),LEN(in,1)) END;
		RESULT:=ALL(in, Mathe.sqrt);
		(*FOR i:=0 TO LEN(in,0)-1 DO
			RESULT[i]:=LinearMath.Sqrt(in[i])
		END;*)
		RETURN RESULT
	END Sqrt;

	PROCEDURE Sin*(CONST in:Array):Array;
	VAR i:SIGNED32;
	BEGIN
		IF LEN(RESULT)#LEN(in) THEN NEW(RESULT,LEN(in,0),LEN(in,1)) END;
		RESULT:=ALL(in, Mathe.sin);
		(*FOR i:=0 TO LEN(in,0)-1 DO
			RESULT[i]:=LinearMath.Sin(in[i])
		END;*)
		RETURN RESULT
	END Sin;

	PROCEDURE Cos*(CONST in:Array):Array;
	VAR i:SIGNED32;
	BEGIN
		IF LEN(RESULT)#LEN(in) THEN NEW(RESULT,LEN(in,0),LEN(in,1)) END;
		RESULT:=ALL(in, Mathe.cos);
		(*FOR i:=0 TO LEN(in,0)-1 DO
			RESULT[i]:=LinearMath.Cos(in[i])
		END;*)
		RETURN RESULT
	END Cos;

	PROCEDURE Arctan*(CONST in:Array):Array;
	VAR i:SIGNED32;
	BEGIN
		IF LEN(RESULT)#LEN(in) THEN NEW(RESULT,LEN(in,0),LEN(in,1)) END;
		RESULT:=ALL(in, Mathe.arctan);
		(*FOR i:=0 TO LEN(in,0)-1 DO
			RESULT[i]:=LinearMath.Arctan(in[i])
		END;*)
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
		IF LEN(RESULT)#LEN(in) THEN NEW(RESULT,LEN(in,0),LEN(in,1)) END;
		RESULT:=ALL(in, Mathe.ln);
		(*FOR i:=0 TO LEN(in,0)-1 DO
			RESULT[i]:=LinearMath.Ln(in[i])
		END;*)
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
		FOR i:=0 TO LEN(R,0)-1 DO
			LinearMath.ComplexSqrt(R[i],I[i], outR[i],outI[i]);
		END;
	END ComplexSqrt;


END PlanarMath.

SystemTools.FreeDownTo PlanarMath
