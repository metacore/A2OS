MODULE FP1616;	(** AUTHOR "PL"; PURPOSE "FixPoint 16.16 Module"; *)

CONST
	FIXPOINT = 65536;						(* 2^8 *)

TYPE
(* converts a 16.16 fixpoint integer to float *)
PROCEDURE FixpToFloat*(x: SIZE): REAL;
BEGIN
	RETURN (x / FIXPOINT);
END FixpToFloat;

(* converts a float into a 16.16 fixpoint integer *)
PROCEDURE FloatToFixp*(x: REAL): LONGINT;
BEGIN
	IF x > FIXPOINT THEN RETURN FIXPOINT;
	ELSIF x < -FIXPOINT THEN RETURN -FIXPOINT
	ELSE RETURN ENTIER(x * (FIXPOINT));
	END;
END FloatToFixp;

PROCEDURE Int*(fp1616: LONGINT) : LONGINT;
BEGIN
	RETURN fp1616 DIV FIXPOINT
END Int;

(* addition / subtraction just do it *)

(* mulitplicates 2 Fixpoint Numbers *)
PROCEDURE Mult*(x, y: LONGINT): LONGINT;
BEGIN
	RETURN (ENTIER(FixpToFloat(x)*y));
END Mult;

(* division of 2 fixpoint NUmbers *)
PROCEDURE Div*(x, y: LONGINT): LONGINT;
BEGIN
	RETURN (ENTIER(x/FixpToFloat(y)));
END Div;

END FP1616.
