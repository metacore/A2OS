MODULE FP1616;	(** AUTHOR "PL"; PURPOSE "FixPoint 16.16 Module"; *)

CONST
	FIXPOINT = 65536;						(* 2^8 *)

TYPE
(* converts a 16.16 fixpoint integer to float *)
PROCEDURE FixpToFloat*(x: SIZE): FLOAT32;
BEGIN
	RETURN (x / FIXPOINT);
END FixpToFloat;

(* converts a float into a 16.16 fixpoint integer *)
PROCEDURE FloatToFixp*(x: FLOAT32): SIGNED32;
BEGIN
	IF x > FIXPOINT THEN RETURN FIXPOINT;
	ELSIF x < -FIXPOINT THEN RETURN -FIXPOINT
	ELSE RETURN ENTIER(x * (FIXPOINT));
	END;
END FloatToFixp;

PROCEDURE Int*(fp1616: SIGNED32) : SIGNED32;
BEGIN
	RETURN fp1616 DIV FIXPOINT
END Int;

(* addition / subtraction just do it *)

(* mulitplicates 2 Fixpoint Numbers *)
PROCEDURE Mult*(x, y: SIGNED32): SIGNED32;
BEGIN
	RETURN (ENTIER(FixpToFloat(x)*y));
END Mult;

(* division of 2 fixpoint NUmbers *)
PROCEDURE Div*(x, y: SIGNED32): SIGNED32;
BEGIN
	RETURN (ENTIER(x/FixpToFloat(y)));
END Div;

END FP1616.
