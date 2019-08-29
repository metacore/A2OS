(* ETH Oberon, Copyright 2001 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

MODULE MathL;	(** portable *)
(** AUTHOR "?"; PURPOSE "Math utility module (LONGREAL)"; *)

(* Aos version - requires floating-point instruction support. *)

IMPORT SYSTEM;

CONST
	e* = 2.7182818284590452354D0;
	pi* = 3.14159265358979323846D0;
	ln2* = 0.693147180559945309417232121458D0;
	eps = 2.2D-16;

TYPE
	Value = LONGREAL;

PROCEDURE Expo (x: Value): UNSIGNED32;
BEGIN
	RETURN UNSIGNED32(ASH(SYSTEM.VAL(UNSIGNED64, x), -52)) MOD 2048
END Expo;

PROCEDURE Mantissa (x: Value): UNSIGNED64;
BEGIN
	RETURN SYSTEM.VAL(UNSIGNED64, SYSTEM.VAL(SET64, x) * {0 .. 51})
END Mantissa;

PROCEDURE Equal (x, y: Value): BOOLEAN;
BEGIN
	IF x > y THEN
		x := x - y
	ELSE
		x := y - x
	END;
	RETURN x < eps
END Equal;

PROCEDURE sin*(x: Value): Value;
VAR
	k: WORD;
	xk, prev, res: Value;
BEGIN
#IF I386 THEN
	CODE
		FLD QWORD [EBP + x]
		FSIN
		#IF ~LEGACY THEN
			FSTP QWORD [EBP + x]
			MOVSD XMM0, [EBP + x]
		#END
	END;
	RETURN RESULT;
#ELSIF AMD64 THEN
	CODE
		FLD QWORD [RBP + x]
		FSIN
		#IF ~LEGACY THEN
			FSTP QWORD [RBP + x]
			MOVSD XMM0, [RBP + x]
		#END
	END;
	RETURN RESULT;
#ELSE
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
#END
END sin;

PROCEDURE cos*(x: Value): Value;
VAR
	k: WORD;
	prev, res, xk: Value;
BEGIN
#IF I386 THEN
	CODE
		FLD QWORD [EBP + x]
		FCOS
		#IF ~LEGACY THEN
			FSTP QWORD [EBP + x]
			MOVSD XMM0, [EBP + x]
		#END
	END;
	RETURN RESULT;
#ELSIF AMD64 THEN
	CODE
		FLD QWORD [RBP + x]
		FCOS
		#IF ~LEGACY THEN
			FSTP QWORD [RBP + x]
			MOVSD XMM0, [RBP + x]
		#END
	END;
	RETURN RESULT;
#ELSE
	WHILE x >= 2 * pi DO x := x - 2*pi END;
	WHILE x < 0 DO x := x + 2*pi END;
	res := 1.0;
	xk := 1.0;
	k := 1;
	REPEAT
		prev := res;
		xk := -xk * x * x / (2 * k - 1) / (2 * k);
		res := res + xk;
		INC(k, 1)
	UNTIL Equal(xk, 0.0) OR Equal(prev, res) OR (k = 5000);
	RETURN res
#END
END cos;

PROCEDURE arctan*(x: Value): Value;
VAR
	k: WORD;
	prev, res, term, xk: Value;
BEGIN
#IF I386 THEN
	CODE
		FLD QWORD [EBP + x]
		FLD1
		FPATAN
		#IF ~LEGACY THEN
			FSTP QWORD [EBP + x]
			MOVSD XMM0, [EBP + x]
		#END
	END;
	RETURN RESULT;
#ELSIF AMD64 THEN
	CODE
		FLD QWORD [RBP + x]
		FLD1
		FPATAN
		#IF ~LEGACY THEN
			FSTP QWORD [RBP + x]
			MOVSD XMM0, [RBP + x]
		#END
	END;
	RETURN RESULT;
#ELSE
	IF (x = 1) OR (x = -1) THEN
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
#END
END arctan;

PROCEDURE sqrt*(x: Value): Value;
BEGIN
	IF x <= 0 THEN
		IF x = 0 THEN RETURN 0 ELSE HALT(80) END;
	END;
#IF I386 THEN
	CODE
		FLD QWORD [EBP + x]
		FSQRT
		#IF ~LEGACY THEN
			FSTP QWORD [EBP + x]
			MOVSD XMM0, [EBP + x]
		#END
	END;
	RETURN RESULT;
#ELSIF AMD64 THEN
	CODE
		FLD QWORD [RBP + x]
		FSQRT
		#IF ~LEGACY THEN
			FSTP QWORD [RBP + x]
			MOVSD XMM0, [RBP + x]
		#END
	END;
	RETURN RESULT;
#ELSE
	RETURN exp(0.5 * ln(x));
#END
END sqrt;

PROCEDURE ln*(x: Value): Value;
VAR
	k: WORD;
	res, y, yk: Value;
BEGIN
	IF x <= 0 THEN
		HALT(80);
	END;
#IF I386 THEN
	CODE
		FLD1
		FLDL2E
		FDIVP
		FLD QWORD [EBP + x]
		FYL2X
		#IF ~LEGACY THEN
			FSTP QWORD [EBP + x]
			MOVSD XMM0, [EBP + x]
		#END
	END;
	RETURN RESULT;
#ELSIF AMD64 THEN
	CODE
		FLD1
		FLDL2E
		FDIVP
		FLD QWORD [RBP + x]
		FYL2X
		#IF ~LEGACY THEN
			FSTP QWORD [RBP + x]
			MOVSD XMM0, [RBP + x]
		#END
	END;
	RETURN RESULT;
#ELSE
	IF x < 1.0 THEN
		RETURN -ln(1.0 / x)
	ELSIF x >= 2.0 THEN
		(*
			algorithm idea from http://stackoverflow.com/questions/10732034/how-are-logarithms-programmed
			and https://en.wikipedia.org/wiki/Natural_logarithm (Newton's method)

			ln(m * 2^e) = e ln(2) + ln(m)
		*)
		RETURN (Expo(x) - 1023) * ln2 + ln(SYSTEM.VAL(Value, Mantissa(x) + 3FF0000000000000H))
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
#END
END ln;

PROCEDURE exp*(x: Value): Value;
VAR
	k: WORD;
	prev, res, xk: Value;
BEGIN
#IF I386 THEN
	CODE
		FLD QWORD [EBP + x]
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
		#IF ~LEGACY THEN
			FSTP QWORD [EBP + x]
			MOVSD XMM0, [EBP + x]
		#END
	END;
	RETURN RESULT;
#ELSIF AMD64 THEN
	CODE
		FLD QWORD [RBP + x]
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
		#IF ~LEGACY THEN
			FSTP QWORD [RBP + x]
			MOVSD XMM0, [RBP + x]
		#END
	END;
	RETURN RESULT;
#ELSE
	IF x < 0.0 THEN
		RETURN 1.0 / exp(-x)
	ELSE
		(* exp(x) = sum_k x^(k) / k! *)
		prev := 0.0;
		res := 1.0;

		k := 1;
		xk := 1;
		REPEAT
			prev := res;

			xk := xk / k * x;
			res := res + xk;
			INC(k, 1)
		UNTIL Equal(xk, 0.0) OR (k = 5000);
		RETURN res
	END
#END
END exp;

END MathL.
