(* ETH Oberon, Copyright 2001 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

MODULE Math;	(** portable *)
(** AUTHOR "?"; PURPOSE "Math utility module (REAL)"; *)

(* Aos version - requires floating-point instruction support. *)

IMPORT SYSTEM;

CONST
	e* = 2.7182818284590452354E0;
	pi* = 3.14159265358979323846E0;

TYPE
	Value = REAL;

PROCEDURE sin*(x: Value): Value;
BEGIN
#IF I386 THEN
	CODE
		FLD [EBP + x]
		FSIN
		#IF ~LEGACY THEN
			FSTP [EBP + x]
			MOVSS XMM0, [EBP + x]
		#END
	END
#ELSIF AMD64 THEN
	CODE
		FLD [RBP + x]
		FSIN
		#IF ~LEGACY THEN
			FSTP [RBP + x]
			MOVSS XMM0, [RBP + x]
		#END
	END
#ELSE
	unimplemented
#END
END sin;

PROCEDURE cos*(x: Value): Value;
BEGIN
#IF I386 THEN
	CODE
		FLD [EBP + x]
		FCOS
		#IF ~LEGACY THEN
			FSTP [EBP + x]
			MOVSS XMM0, [EBP + x]
		#END
	END
#ELSIF AMD64 THEN
	CODE
		FLD [RBP + x]
		FCOS
		#IF ~LEGACY THEN
			FSTP [RBP + x]
			MOVSS XMM0, [RBP + x]
		#END
	END
#ELSE
	unimplemented
#END
END cos;

PROCEDURE arctan*(x: Value): Value;
BEGIN
#IF I386 THEN
	CODE
		FLD [EBP + x]
		FLD1
		FPATAN
		#IF ~LEGACY THEN
			FSTP [EBP + x]
			MOVSS XMM0, [EBP + x]
		#END
	END
#ELSIF AMD64 THEN
	CODE
		FLD [RBP + x]
		FLD1
		FPATAN
		#IF ~LEGACY THEN
			FSTP [RBP + x]
			MOVSS XMM0, [RBP + x]
		#END
	END
#ELSE
	unimplemented
#END
END arctan;

PROCEDURE sqrt*(x: Value): Value;
BEGIN
	IF x <= 0 THEN
		IF x = 0 THEN RETURN 0 ELSE HALT(80) END;
	END;
#IF I386 THEN
	CODE
		FLD [EBP + x]
		FSQRT
		#IF ~LEGACY THEN
			FSTP [EBP + x]
			MOVSS XMM0, [EBP + x]
		#END
	END
#ELSIF AMD64 THEN
	CODE
		FLD [RBP + x]
		FSQRT
		#IF ~LEGACY THEN
			FSTP [RBP + x]
			MOVSS XMM0, [RBP + x]
		#END
	END
#ELSE
	unimplemented
#END
END sqrt;

PROCEDURE ln*(x: Value): Value;
BEGIN
	IF x <= 0 THEN
		HALT(80);
	END;
#IF I386 THEN
	CODE
		FLD1
		FLDL2E
		FDIVP
		FLD [EBP + x]
		FYL2X
		#IF ~LEGACY THEN
			FSTP [EBP + x]
			MOVSS XMM0, [EBP + x]
		#END
	END
#ELSIF AMD64 THEN
	CODE
		FLD1
		FLDL2E
		FDIVP
		FLD [RBP + x]
		FYL2X
		#IF ~LEGACY THEN
			FSTP [RBP + x]
			MOVSS XMM0, [RBP + x]
		#END
	END
#ELSE
	unimplemented
#END
END ln;

PROCEDURE exp*(x: Value): Value;
BEGIN
#IF I386 THEN
	CODE
		FLD [EBP + x]
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
			FSTP [EBP + x]
			MOVSS XMM0, [EBP + x]
		#END
	END
#ELSIF AMD64 THEN
	CODE
		FLD [RBP + x]
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
			FSTP [RBP + x]
			MOVSS XMM0, [RBP + x]
		#END
	END
#ELSE
	unimplemented
#END
END exp;

END Math.
