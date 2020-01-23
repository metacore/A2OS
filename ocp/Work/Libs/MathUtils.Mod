MODULE MathUtils; (** AUTHOR "SAGE"; PURPOSE "Some usefull math functions"; *)

IMPORT
	Math;

PROCEDURE floor*(x: REAL): LONGINT;
BEGIN
	RETURN ENTIER(x)
END floor;

PROCEDURE ceil*(x: REAL): LONGINT;
BEGIN
	RETURN -ENTIER(-x)
END ceil;

PROCEDURE round*(x: REAL): LONGINT;
BEGIN
	RETURN ENTIER(x + 0.5)
END round;

PROCEDURE trunc*(x: REAL): LONGINT;
BEGIN
	IF x >= 0.0 THEN
		RETURN ENTIER(x)
	ELSE
		RETURN -ENTIER(-x)
	END
END trunc;

PROCEDURE frac*(x: REAL): REAL;
BEGIN
	IF x > 0.0 THEN
		RETURN x - ENTIER(x)
	ELSE
		RETURN x + ENTIER(-x)
	END
END frac;

PROCEDURE power*(base, exponent: REAL): REAL;
BEGIN
	IF exponent = 0.0 THEN
		RETURN 1.0
	ELSIF (base = 0.0) & (exponent > 0.0) THEN
		RETURN 0.0
	ELSE
		RETURN Math.exp(exponent * Math.ln(base))
	END
END power;

END MathUtils.

