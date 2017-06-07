MODULE ComplexNumbers;
(* 
	operators for complex numbers
	this module is automatically loaded (FoxSemanticChecker) when operators on complex numbers are encountered
*)

IMPORT Math, MathL;

	OPERATOR "+"*(CONST left, right: COMPLEX): COMPLEX;
	VAR result: COMPLEX;
	BEGIN
		RE(result) := RE(left) + RE(right);
		IM(result) := IM(left) + IM(right);
		RETURN result
	END "+";

	OPERATOR "+"*(CONST left, right: LONGCOMPLEX): LONGCOMPLEX;
	VAR result: LONGCOMPLEX;
	BEGIN
		RE(result) := RE(left) + RE(right);
		IM(result) := IM(left) + IM(right);
		RETURN result
	END "+";

	OPERATOR "-"*(CONST left, right: COMPLEX): COMPLEX;
	VAR result: COMPLEX;
	BEGIN
		RE(result) := RE(left) - RE(right);
		IM(result) := IM(left) - IM(right);
		RETURN result
	END "-";

	OPERATOR "-"*(CONST left, right: LONGCOMPLEX): LONGCOMPLEX;
	VAR result: LONGCOMPLEX;
	BEGIN
		RE(result) := RE(left) - RE(right);
		IM(result) := IM(left) - IM(right);
		RETURN result
	END "-";

	OPERATOR "*"*(CONST left, right: COMPLEX): COMPLEX;
	VAR result: COMPLEX;
	BEGIN
		RE(result) := RE(left) * RE(right) - IM(left) * IM(right);
		IM(result) := RE(left) * IM(right) + IM(left) * RE(right);
		RETURN result
	END "*";

	OPERATOR "*"*(CONST left, right: LONGCOMPLEX): LONGCOMPLEX;
	VAR result: LONGCOMPLEX;
	BEGIN
		RE(result) := RE(left) * RE(right) - IM(left) * IM(right);
		IM(result) := RE(left) * IM(right) + IM(left) * RE(right);
		RETURN result
	END "*";

	OPERATOR "/"*(CONST left, right: COMPLEX): COMPLEX;
	VAR result: COMPLEX; iDivisor: REAL;
	BEGIN
		iDivisor := 1.0 / (RE(right) * RE(right) + IM(right) * IM(right));
		RE(result) := (RE(left) * RE(right) + IM(left) * IM(right)) * iDivisor;
		IM(result) := (IM(left) * RE(right) - RE(left) * IM(right)) * iDivisor;
		RETURN result
	END "/";

	OPERATOR "/"*(CONST left, right: LONGCOMPLEX): LONGCOMPLEX;
	VAR result: LONGCOMPLEX; iDivisor: LONGREAL;
	BEGIN
		iDivisor := 1.0D0 / (RE(right) * RE(right) + IM(right) * IM(right));
		RE(result) := (RE(left) * RE(right) + IM(left) * IM(right)) * iDivisor;
		IM(result) := (IM(left) * RE(right) - RE(left) * IM(right)) * iDivisor;
		RETURN result
	END "/";

	OPERATOR "ABS"*(CONST arg: COMPLEX): REAL;
	BEGIN RETURN Math.sqrt(RE(arg) * RE(arg) + IM(arg) * IM(arg))
	END "ABS";

	OPERATOR "ABS"*(CONST arg: LONGCOMPLEX): LONGREAL;
	BEGIN RETURN MathL.sqrt(RE(arg) * RE(arg) + IM(arg) * IM(arg))
	END "ABS";

	OPERATOR "~"*(CONST left: COMPLEX): COMPLEX;
	BEGIN
		RETURN RE(left) - IM(left) * IMAG
	END "~";

	OPERATOR "~"*(CONST left: LONGCOMPLEX): LONGCOMPLEX;
	BEGIN
		RETURN RE(left) - IM(left) * IMAG
	END "~";

	OPERATOR "<="*(CONST x, y: COMPLEX): BOOLEAN; BEGIN RETURN ABS(x) <= ABS(y); END "<=";
	OPERATOR ">="*(CONST x, y: COMPLEX): BOOLEAN; BEGIN RETURN ABS(x) >= ABS(y); END ">=";
	OPERATOR "<"*(CONST x, y: COMPLEX): BOOLEAN; BEGIN RETURN ABS(x) < ABS(y); END "<";
	OPERATOR ">"*(CONST x, y: COMPLEX): BOOLEAN; BEGIN RETURN ABS(x) > ABS(y); END ">";

	OPERATOR "<="*(CONST x, y: LONGCOMPLEX): BOOLEAN; BEGIN RETURN ABS(x) <= ABS(y); END "<=";
	OPERATOR ">="*(CONST x, y: LONGCOMPLEX): BOOLEAN; BEGIN RETURN ABS(x) >= ABS(y); END ">=";
	OPERATOR "<"*(CONST x, y: LONGCOMPLEX): BOOLEAN; BEGIN RETURN ABS(x) < ABS(y); END "<";
	OPERATOR ">"*(CONST x, y: LONGCOMPLEX): BOOLEAN; BEGIN RETURN ABS(x) > ABS(y); END ">";


END ComplexNumbers.
