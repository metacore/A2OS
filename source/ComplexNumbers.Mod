MODULE ComplexNumbers;
(*
	operators for complex numbers
	this module is automatically loaded (FoxSemanticChecker) when operators on complex numbers are encountered
*)

IMPORT Math, MathL;

	OPERATOR "+"*(CONST left, right: COMPLEX32): COMPLEX32;
	VAR result: COMPLEX32;
	BEGIN
		RE(result) := RE(left) + RE(right);
		IM(result) := IM(left) + IM(right);
		RETURN result
	END "+";

	OPERATOR "+"*(CONST left, right: COMPLEX64): COMPLEX64;
	VAR result: COMPLEX64;
	BEGIN
		RE(result) := RE(left) + RE(right);
		IM(result) := IM(left) + IM(right);
		RETURN result
	END "+";

	OPERATOR "-"*(CONST left, right: COMPLEX32): COMPLEX32;
	VAR result: COMPLEX32;
	BEGIN
		RE(result) := RE(left) - RE(right);
		IM(result) := IM(left) - IM(right);
		RETURN result
	END "-";

	OPERATOR "-"*(CONST left, right: COMPLEX64): COMPLEX64;
	VAR result: COMPLEX64;
	BEGIN
		RE(result) := RE(left) - RE(right);
		IM(result) := IM(left) - IM(right);
		RETURN result
	END "-";

	OPERATOR "*"*(CONST left, right: COMPLEX32): COMPLEX32;
	VAR result: COMPLEX32;
	BEGIN
		RE(result) := RE(left) * RE(right) - IM(left) * IM(right);
		IM(result) := RE(left) * IM(right) + IM(left) * RE(right);
		RETURN result
	END "*";

	OPERATOR "*"*(CONST left, right: COMPLEX64): COMPLEX64;
	VAR result: COMPLEX64;
	BEGIN
		RE(result) := RE(left) * RE(right) - IM(left) * IM(right);
		IM(result) := RE(left) * IM(right) + IM(left) * RE(right);
		RETURN result
	END "*";

	OPERATOR "/"*(CONST left, right: COMPLEX32): COMPLEX32;
	VAR result: COMPLEX32; iDivisor: FLOAT32;
	BEGIN
		iDivisor := 1.0 / (RE(right) * RE(right) + IM(right) * IM(right));
		RE(result) := (RE(left) * RE(right) + IM(left) * IM(right)) * iDivisor;
		IM(result) := (IM(left) * RE(right) - RE(left) * IM(right)) * iDivisor;
		RETURN result
	END "/";

	OPERATOR "/"*(CONST left, right: COMPLEX64): COMPLEX64;
	VAR result: COMPLEX64; iDivisor: FLOAT64;
	BEGIN
		iDivisor := 1.0D0 / (RE(right) * RE(right) + IM(right) * IM(right));
		RE(result) := (RE(left) * RE(right) + IM(left) * IM(right)) * iDivisor;
		IM(result) := (IM(left) * RE(right) - RE(left) * IM(right)) * iDivisor;
		RETURN result
	END "/";

	OPERATOR "ABS"*(CONST arg: COMPLEX32): FLOAT32;
	BEGIN RETURN Math.sqrt(RE(arg) * RE(arg) + IM(arg) * IM(arg))
	END "ABS";

	OPERATOR "ABS"*(CONST arg: COMPLEX64): FLOAT64;
	BEGIN RETURN MathL.sqrt(RE(arg) * RE(arg) + IM(arg) * IM(arg))
	END "ABS";

	OPERATOR "~"*(CONST left: COMPLEX32): COMPLEX32;
	BEGIN
		RETURN RE(left) - IM(left) * IMAG
	END "~";

	OPERATOR "~"*(CONST left: COMPLEX64): COMPLEX64;
	BEGIN
		RETURN RE(left) - IM(left) * IMAG
	END "~";

	OPERATOR "<="*(CONST x, y: COMPLEX32): BOOLEAN; BEGIN RETURN ABS(x) <= ABS(y); END "<=";
	OPERATOR ">="*(CONST x, y: COMPLEX32): BOOLEAN; BEGIN RETURN ABS(x) >= ABS(y); END ">=";
	OPERATOR "<"*(CONST x, y: COMPLEX32): BOOLEAN; BEGIN RETURN ABS(x) < ABS(y); END "<";
	OPERATOR ">"*(CONST x, y: COMPLEX32): BOOLEAN; BEGIN RETURN ABS(x) > ABS(y); END ">";

	OPERATOR "<="*(CONST x, y: COMPLEX64): BOOLEAN; BEGIN RETURN ABS(x) <= ABS(y); END "<=";
	OPERATOR ">="*(CONST x, y: COMPLEX64): BOOLEAN; BEGIN RETURN ABS(x) >= ABS(y); END ">=";
	OPERATOR "<"*(CONST x, y: COMPLEX64): BOOLEAN; BEGIN RETURN ABS(x) < ABS(y); END "<";
	OPERATOR ">"*(CONST x, y: COMPLEX64): BOOLEAN; BEGIN RETURN ABS(x) > ABS(y); END ">";


END ComplexNumbers.
