MODULE Builtins; (** AUTHOR ""; PURPOSE ""; *)
(**
@concept
The module [[TRMRuntime]] provides run-time services implemented as procedures. The compiler \
emits procedure calls for all invocations of the runtime.
**)
IMPORT SYSTEM;

CONST expo = 7F800000H; bias = 3F800000H;
	mant = 7FFFFFH; mant1 = SIGNED32(0FFC00000H); mant2 = 0FFFFFFH;
	LimE = 0C800000H; C = 800000H; S = SIGNED32(80000000H); M= SIGNED32(7FFFFFFFH);

VAR
	lastDataAddress-: ADDRESS;
	emptyVariable: RECORD END; (* always linked to top of used memory *)

(* for testing test with intel
VAR high: SIGNED32;

	PROCEDURE SimulatedMul(l,r: SIGNED32): SIGNED32;
	VAR h: SIGNED64;
	BEGIN
		h := SIGNED64(l)*r;
		high := SIGNED32(h DIV 100000000H);
		RETURN SIGNED32(h MOD 100000000H);
	END SimulatedMul;

	PROCEDURE H(): SIGNED32;
		RETURN high
	END H;
*)
	PROCEDURE H(): SIGNED32;
	CODE
		LDH R0
	END H;

	(* helper functions *)
	PROCEDURE MSK(x,bits: SIGNED32): SIGNED32;
	BEGIN
		RETURN SYSTEM.VAL(SIGNED32, SYSTEM.VAL(SET,x)*SYSTEM.VAL(SET,bits))
	END MSK;

	PROCEDURE NULLF(x: SIGNED32): BOOLEAN;
	BEGIN RETURN SYSTEM.VAL(SET,x) * SYSTEM.VAL(SET,M) = {}
	END NULLF;

	PROCEDURE ConvertIR*(x: SIGNED32): FLOAT32; (* Float 32 bit *)
	VAR xe, s: SIGNED32; odd,odd1: BOOLEAN; odds: SIGNED32;
	BEGIN s := x;
		IF x # 0 THEN
			x := ABS(x); xe := 4B000000H;
			IF x >= 2*C THEN
				odd := FALSE; odd1 := FALSE;
				REPEAT
					odd1 := odd1 OR odd;
					odd := ODD(x); (* rounding bit *)
					x := ROT(MSK(x, -2),-1); (*ASH(x,-1);*) INC(xe,C);
					(*D.Hex(x,10); D.Ln;*)
				UNTIL x <2*C;

				(* round half to even, standard in IEEE 754 *)
				IF odd & (ODD(x) OR odd1) & (x<2*C) THEN INC(x) END; (* rounding *)
			ELSIF x < C THEN
				REPEAT x := x+x; xe := xe - C UNTIL x >= C
			END ;
			x := xe - C + x;
			IF s < 0 THEN x := x+S END
		END ;
		RETURN SYSTEM.VAL(FLOAT32,x)
	END ConvertIR;

	PROCEDURE ConvertHR*(x: SIGNED64): FLOAT32;
	BEGIN HALT(200);
	END ConvertHR;

	PROCEDURE ConvertRI*(l: FLOAT32): SIGNED32; (* Floor 32bit *)
	VAR x,xe, n, sign: SIGNED32;
	BEGIN
		x := SYSTEM.VAL(SIGNED32,l);
		IF ~NULLF(x) THEN
			sign := MSK(x, S);
			xe := MSK(x, expo) - bias; x := MSK(x, mant) + C;
			IF xe >= 0 THEN xe := ROT(xe, -23) ELSE xe := -1 END ;
			IF sign < 0 THEN x := -x END ;
			IF xe < 24 THEN n := 23 - xe;
				WHILE n > 0 DO x := ROT(MSK(x, -2), -1) + sign; DEC(n) END
			ELSIF xe >= 31 THEN x := MIN(SIGNED32)
			ELSE n := xe - 23;
				WHILE n > 0 DO x := x+x; DEC(n) END
			END
		ELSE x := 0
		END ;
		RETURN x
	END ConvertRI;

	PROCEDURE ConvertRH*(x: FLOAT32): SIGNED64 ;
	BEGIN HALT(200);
	END ConvertRH;

	(* 32 bit float instructions *)

	PROCEDURE AddR*(l,r: FLOAT32): FLOAT32;
	VAR x,y,xe, ye, xm, ym, sign: SIGNED32; odd, odd1: BOOLEAN;
	BEGIN
		x := SYSTEM.VAL(SIGNED32,l);
		y := SYSTEM.VAL(SIGNED32,r);
		IF NULLF(x) THEN x := y
		ELSIF ~NULLF(y) THEN
			xe := MSK(x, expo) - bias; xm := MSK(x, mant) + C;
			ye := MSK(y, expo) - bias; ym := MSK(y, mant) + C;
			IF xe < ye THEN (*denorm x*)
				IF ye - xe > LimE THEN xm := 0; xe := ye ELSE
					odd1 := FALSE; odd := FALSE;
					REPEAT odd1 := odd1 OR odd; odd := ODD(xm); xe := xe + C; xm := ROT(MSK(xm, -2), -1) UNTIL xe = ye;
					(* half even rounding *)
					IF odd & (odd1 OR ODD(xm)) THEN INC(xm) END;
				END
			ELSIF ye < xe THEN (*denorm y*)
				IF xe - ye > LimE THEN ym := 0 ELSE
					odd := FALSE; odd1 := FALSE;
					REPEAT odd1 := odd1 OR odd; odd := ODD(ym); ye := ye + C; ym := ROT(MSK(ym, -2), -1) UNTIL ye = xe;
					(* half even rounding *)
					IF odd & (odd1 OR ODD(ym)) THEN INC(xm) END;
				END
			END ;
			IF x < 0 THEN xm := -xm END ;
			IF y < 0 THEN ym := -ym END ;
			x := xm + ym; sign := MSK(x, S);
			IF x # 0 THEN
				IF x < 0 THEN x := -x END ;
				IF x >= 2*C THEN
					odd := ODD(x);
					x := ROT(MSK(x, -2), -1);
					(* half even rounding *)
					IF odd & ODD(x) THEN INC(x) END;
					xe := xe + C
				ELSE (*normalize*)
					WHILE x < C DO
						x := ROT(x, -31); xe := xe - C
					END
				END ;
				IF xe < -bias THEN x := 0  (*underflow*)
				ELSIF (xe <= bias) THEN x := (x-C) + xe + bias + sign
				ELSE xe := M
				END
			END
		END ;
		RETURN SYSTEM.VAL(FLOAT32,x)
	END AddR;

	PROCEDURE SubR*(l,r: FLOAT32): FLOAT32;
	BEGIN RETURN AddR(l,-r)
	END SubR;

	PROCEDURE MulR*(l,r: FLOAT32): FLOAT32; (* float 32 * float 32 => float 32 *)
	VAR x,y,xe, ye, sign: SIGNED32;
	BEGIN
		x := SYSTEM.VAL(SIGNED32,l);
		y := SYSTEM.VAL(SIGNED32,r);
		IF NULLF(y) THEN x := 0
		ELSIF ~NULLF(x) THEN
			sign := MSK(x, S) + MSK(y, S);
			xe := MSK(x, expo) - bias; x := MSK(x, mant) + C;
			ye := MSK(y, expo) - bias; y := MSK(y, mant) + C;
			xe := xe + ye; x := x * y (*testing: SimulatedMul(x,y) *);
			IF xe < -bias THEN x := 0  (*underflow*)
			ELSIF (xe <= bias) THEN
				x := ROT(MSK(x, mant1),-24)+ROT(H(),8);
				IF MSK(x, C) = 0 THEN (*normalize*)
					x := ROT(x, -31); xe := xe - C
				END;
				IF x < 0 THEN x := x + 1 (*round*) END;
				x := MSK(x, mant2) + xe + bias + sign;
			ELSE x := M;
			END
		ELSE x := 0;
		END ;
		RETURN SYSTEM.VAL(FLOAT32,x)
	END MulR;

	PROCEDURE DivR*(l,r: FLOAT32): FLOAT32; (* float 32 / float 32 => float 32 *)
	VAR x,y,xe, ye, q, n, sign: SIGNED32;
	BEGIN
		x := SYSTEM.VAL(SIGNED32,l);
		y := SYSTEM.VAL(SIGNED32,r);
		ASSERT(ABS(y) # 0,26);
		IF ~NULLF(x) THEN
			sign := MSK(x, S) + MSK(y, S);
			xe := MSK(x, expo) - bias; x := MSK(x, mant) + C;
			ye := MSK(y, expo) - bias; y := MSK(y, mant) + C;
			xe := xe - ye;
			IF x < y THEN x := ROT(x, -31); xe := xe - C END ;
			n := 25; q := 0;
			REPEAT q := ROT(q, -31);
				IF x >= y THEN x := x - y; INC(q) END ;
				x := ROT(x, -31); DEC(n)
			UNTIL n = 0;
			q := ROT(MSK(q+1, -2), -1);  (*round*)
			IF xe < -bias THEN x := 0  (*underflow*)
			ELSIF (xe <= bias) THEN x := q - C + xe + bias + sign
			ELSE x := M;
			END
		ELSE x := 0
		END ;
		RETURN SYSTEM.VAL(FLOAT32,x)
	END DivR;

	PROCEDURE AbsR*(x: FLOAT32): FLOAT32;
	BEGIN
		IF x < 0 THEN RETURN -x ELSE RETURN x END
	END AbsR;

	PROCEDURE DivModL(dividend, divisor: SIGNED32; VAR quotient, remainder: SIGNED32);
	VAR d: SIGNED32;
	BEGIN
		ASSERT(dividend >=0); ASSERT(divisor > 0);
		remainder := dividend;
		quotient := 0;
		d := divisor;
		REPEAT d := ASH(d,1) UNTIL (d > dividend) OR (d < 0);
		REPEAT d := LSH(d,-1); quotient := ASH(quotient,1);
			IF remainder >= d THEN remainder := remainder - d; quotient := quotient+1 END
		UNTIL d = divisor;
	END DivModL;

	(* 32 bit integer instructions *)
	PROCEDURE DivL*(l,r: SIGNED32): SIGNED32;
	VAR quotient, remainder: SIGNED32;
	BEGIN
		IF l < 0 THEN
			DivModL(-l,r,quotient,remainder);
			RETURN -quotient-1;
		ELSE
			DivModL(l,r,quotient,remainder);
			RETURN quotient
		END;
	END DivL;

	PROCEDURE ModL*(l,r: SIGNED32): SIGNED32;
	VAR quotient, remainder: SIGNED32;
	BEGIN
		IF l < 0 THEN
			DivModL(-l,r,quotient,remainder);
			RETURN r - remainder;
		ELSE
			DivModL(l,r,quotient,remainder);
			RETURN remainder
		END;
	END ModL;

	(* 64 bit integer instructions *)
	PROCEDURE DivH*(l,r: SIGNED64): SIGNED64 ;
	BEGIN HALT(200);
	END DivH;
	PROCEDURE ModH*(l,r: SIGNED64): SIGNED64 ;
	BEGIN HALT(200);
	END ModH;
	PROCEDURE AbsH*(x: SIGNED64): SIGNED64;
	BEGIN IF x < 0 THEN RETURN -x ELSE RETURN x END;
	END AbsH;
	PROCEDURE AslH*(l,r: SIGNED64): SIGNED64 ;
	BEGIN HALT(200);
	END AslH;
	PROCEDURE LslH*(l,r: SIGNED64): SIGNED64 ;
	BEGIN HALT(200);
	END LslH;
	PROCEDURE AsrH*(l,r: SIGNED64): SIGNED64;
	BEGIN HALT(200);
	END AsrH;
	PROCEDURE LsrH*(l,r: SIGNED64): SIGNED64 ;
	BEGIN HALT(200);
	END LsrH;
	PROCEDURE RorH*(l,r: SIGNED64): SIGNED64;
	BEGIN HALT(200);
	END RorH;
	PROCEDURE RolH*(l,r: SIGNED64): SIGNED64;
	BEGIN HALT(200);
	END RolH;

	(* currently unused 64 bit float support

	(* conversions such as ENTIER, SHORT or implicit *)
	PROCEDURE ConvertXR*(x: FLOAT64): FLOAT32;
	BEGIN HALT(200);
	END ConvertXR;

	PROCEDURE ConvertRX*(x: FLOAT32): FLOAT64 ;
	BEGIN HALT(200);
	END ConvertRX;

	PROCEDURE ConvertIX*(x: SIGNED32): FLOAT64;
	VAR xe: SIGNED32;  h: SIGNED64;
	CONST B = 1023; C=10000000000000H;
	BEGIN
		IF x # 0 THEN
			h := ABS(x); xe := 52;
			IF h >= 2*C THEN
				REPEAT h := h DIV 2; INC(xe) UNTIL h < 2*C
			ELSIF h < C THEN
				REPEAT h := 2*h; DEC(xe) UNTIL h >= C
			END ;
			h := (xe + B -1)*C + h;
			IF x < 0 THEN h := -h END
		END ;
		RETURN SYSTEM.VAL(FLOAT64,h)
	END ConvertIX;

	PROCEDURE ConvertXI*(x: FLOAT64): SIGNED32 ;
	BEGIN HALT(200);
	END ConvertXI;

	PROCEDURE ConvertXH*(x: FLOAT64): SIGNED64 ;
	BEGIN HALT(200);
	END ConvertXH;

	(* 64 bit float instructions *)
	PROCEDURE AddX*(l,r: FLOAT64): FLOAT64 ;
	BEGIN HALT(200);
	END AddX;

	PROCEDURE SubX*(l,r: FLOAT64): FLOAT64 ;
	BEGIN HALT(200);
	END SubX;

	PROCEDURE MulX*(l,r: FLOAT64): FLOAT64;
	BEGIN HALT(200);
	END MulX;

	PROCEDURE DivX*(l,r: FLOAT64): FLOAT64;
	BEGIN HALT(200);
	END DivX;

	PROCEDURE AbsX*(x: FLOAT64): FLOAT64;
	BEGIN 	IF x < 0 THEN RETURN -x ELSE RETURN x END
	END AbsX;

	PROCEDURE ConvertHX*(x: SIGNED64): FLOAT64;
	BEGIN HALT(200);
	END ConvertHX;
	*)


	(* compare strings,
		returns 0 if strings are equal,
		returns +1 if left is lexicographic greater than right,
		returns -1 if left is lexicographics smaller than right
		traps if src or destination is not 0X terminated and comparison is not finished
	*)
	PROCEDURE CompareString*(CONST left,right: ARRAY OF CHAR): SIGNED8;
	VAR i: SIGNED32; res: SIGNED8; l,r: CHAR;
	BEGIN
		i := 0; res := 0;
		LOOP
			l := left[i]; 		(* index check included *)
			r := right[i];		(* index check included *)
			IF (l > r) THEN
				res := 1; EXIT
			ELSIF (l<r) THEN
				res := -1; EXIT
			ELSIF l=0X THEN
				EXIT
			END;
			INC(i);
		END;
		RETURN res
	END CompareString;

	(* copy string from src to dest, emits trap if not 0X terminated or destination too short *)
	PROCEDURE CopyString*(VAR dest: ARRAY OF CHAR; CONST src: ARRAY OF CHAR);
	VAR i: SIGNED32; ch :CHAR; l1,l2: SIGNED32;
	BEGIN
		(*
		i := 0;
		REPEAT
			ch := src[i];		(* index check included *)
			dest[i] := ch;	(* index check included *)
			INC(i);
		UNTIL ch=0X;
		*)

		(*! currently implemented: old PACO semantics *)
		l1 := LEN(dest);
		l2 := LEN(src);
		IF l2 < l1 THEN l1 := l2 END;
		SYSTEM.MOVE(ADDRESSOF(src[0]),ADDRESSOF(dest[0]),l1);
		dest[l1-1] := 0X;
	END CopyString;

	PROCEDURE EnsureAllocatedStack*(size: SIZE);
	VAR i,temp: ADDRESS;
	BEGIN
		FOR i := 0 TO size BY 4096 DO
			temp := SYSTEM.GET32(ADDRESSOF(i)-i);
			(*
			SYSTEM.PUT(ADDRESSOF(val)-i,0);
			*)
		END;
	(*
	CODE{SYSTEM.i386}
		MOV EAX, [EBP+size]
		SHR EAX,12 ; divide by 4096
		MOV ECX,-4
	start:
		MOV EDX,[EBP+ECX]
		SUB ECX,4096
		TST EAX
		DEC EAX
		JNZ start
	*)
	END EnsureAllocatedStack;

	(*! should not be used, linker cannot deal with fixup here -- late time code generation does not help because this is a code section *)
	(*
	PROCEDURE {NOPAF} LastAddress; (* empty procedure, linker places this always at the end of code memory *)
	CODE
	END LastAddress;
	*)

BEGIN
	lastDataAddress := ADDRESSOF(emptyVariable);
END Builtins.
