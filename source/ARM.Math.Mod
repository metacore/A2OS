MODULE Math;
(*
	AUTHOR Timothée Martiel, 12/2015
	PURPOSE Math utilities for REALs
*)
IMPORT SYSTEM, Reals;

CONST
	e* = 2.7182818284590452354E0;
	pi* = 3.14159265358979323846E0;
	ln2* = 0.693147180559945309417232121458; (** ln(2), from https://en.wikipedia.org/wiki/Natural_logarithm_of_2 *)

	eps = 1.2E-7;
	NEON = FALSE;

PROCEDURE Mantissa (x: REAL): LONGINT;
BEGIN
	RETURN SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, x) * {0 .. 22})
END Mantissa;

PROCEDURE Equal (x, y: REAL): BOOLEAN;
BEGIN
	IF x > y THEN
		x := x - y
	ELSE
		x := y - x
	END;
	RETURN x < eps
END Equal;

PROCEDURE Sin(x: REAL):REAL;
END Sin;

PROCEDURE Cos(x: REAL):REAL;
END Cos;

PROCEDURE Arctan(x: REAL):REAL;
END Arctan;

PROCEDURE Sqrt(x: REAL):REAL;
END Sqrt;

PROCEDURE Ln(x: REAL):REAL;
END Ln;

PROCEDURE Exp(x: REAL):REAL;
END Exp;

PROCEDURE sin*(x: REAL): REAL;
VAR
	xk, prev, res: REAL;
	k: LONGINT;
BEGIN
	IF NEON THEN
		RETURN Sin(x);
	ELSE
		WHILE x >= 2 * pi DO x := x - 2*pi END;
		WHILE x < 0 DO x := x + 2*pi END;
		res := x;
		xk := x;
		k := 1;
		REPEAT
			prev := res;
			xk := -xk * x * x / (2 * k) / (2 * k + 1);
			res := res + xk;
			INC(k)
		UNTIL Equal(prev, res) OR (k = 5000);
		RETURN res
	END
END sin;

PROCEDURE cos*(x: REAL): REAL;
VAR
	k, kf: LONGINT;
	prev, res, xk: REAL;
BEGIN
	IF NEON THEN
		RETURN Cos(x);
	ELSE
		WHILE x >= 2 * pi DO x := x - 2*pi END;
		WHILE x < 0 DO x := x + 2*pi END;
		res := 1.0;
		xk := 1.0;
		kf := 1;
		k := 1;
		REPEAT
			prev := res;
			xk := -xk * x * x / (2 * k - 1) / (2 * k);
			res := res + xk;
			INC(k, 1)
		UNTIL Equal(xk, 0.0) OR Equal(prev, res) OR (k = 5000);
		RETURN res
	END
END cos;

PROCEDURE arctan*(x: REAL): REAL;
VAR
	k: LONGINT;
	prev, res, term, xk: REAL;
BEGIN
	IF NEON THEN
		RETURN Arctan(x)
	ELSIF (x = 1) OR (x = -1) THEN
		RETURN x * pi / 4
	ELSIF (x > 1) OR (x < -1) THEN
		RETURN pi / 2 - arctan(1 / x)
	ELSE
		(* atan(x) = sum_k (-1)^(k) x^{2 k + 1} / (2 k + 1), |x| < 1 *)
		prev := pi / 2;
		res := 0.0;
		xk := x;
		k := 0;
		REPEAT
			prev := res;

			term := 1 / (2 * k + 1) * xk;
			IF ODD(k) THEN
				res := res - term
			ELSE
				res := res + term
			END;
			xk := xk * x * x;
			INC(k)
		UNTIL Equal(prev, res) OR (k = 50000);
		RETURN res
	END
END arctan;

PROCEDURE sqrt*(x: REAL): REAL;
BEGIN
	IF x <= 0 THEN
		IF x = 0 THEN RETURN 0 ELSE HALT(80) END
	ELSIF NEON THEN
		RETURN Sqrt(x)
	ELSE
		RETURN exp(0.5 * ln(x))
	END
END sqrt;

PROCEDURE ln*(x: REAL): REAL;
VAR
	res, y, yk: REAL;
	k: LONGINT;
BEGIN
	IF x <= 0 THEN
		HALT(80)
	ELSIF NEON THEN
		RETURN Ln(x)
	ELSIF x < 1.0 THEN
		RETURN -ln(1.0 / x)
	ELSIF x >= 2.0 THEN
		(*
			algorithm idea from http://stackoverflow.com/questions/10732034/how-are-logarithms-programmed
			and https://en.wikipedia.org/wiki/Natural_logarithm (Newton's method)

			ln(m * 2^e) = e ln(2) + ln(m)
		*)
		RETURN (Reals.Expo(x) - 127) * ln2 + ln(SYSTEM.VAL(REAL, Mantissa(x) + 3F800000H))
	ELSE
		(* ln(x) = 2 * sum_k 1/(2 k + 1) y^k, where y = (x - 1) / (x + 1), x real *)
		y := (x - 1) / (x + 1);
		yk := y;
		res := y;
		k := 1;
		REPEAT
			yk := yk * y * y;
			res := res + yk / (2 * k + 1);
			INC(k)
		UNTIL Equal(yk, 0.0) OR (k = 5000);
		RETURN 2.0 * res;

	END
END ln;

PROCEDURE exp*(x: REAL): REAL;
VAR
	k: LONGINT;
	prev, res, xk, kf: REAL;
BEGIN
	IF NEON THEN
		RETURN Exp(x)
	ELSIF x < 0.0 THEN
		RETURN 1.0 / exp(-x)
	ELSE
		(* exp(x) = sum_k x^(k) / k! *)
		prev := 0.0;
		res := 1.0;

		k := 1;
		xk := 1;
		kf := 1.0;
		REPEAT
			prev := res;

			xk := xk / k * x;
			res := res + xk;
			INC(k, 1)
		UNTIL Equal(xk, 0.0) OR (k = 5000);
		RETURN res
	END
END exp;
END Math.
