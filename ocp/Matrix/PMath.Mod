MODULE PMath;
IMPORT Math,MathL,BIT,Reals,SYSTEM;
CONST wordlengthlongint=32;
	upperExp=500;
	LongOne*=1.0D000;
	(*EpsL*=1.11022302463E-16;
	Eps*=5.9604645E-08;*)
VAR OneDivLn10*:FLOAT32;
		Comments*:BOOLEAN;
		NaN*, Inf*,Eps*:FLOAT32;
		NaNL*,InfL*,EpsL*:FLOAT64;
		expNegligible*:FLOAT32;
		expNegligibleL*:FLOAT64;

PROCEDURE log*(x:FLOAT32):FLOAT32;
BEGIN
RETURN Math.ln(x)*OneDivLn10;
END log;

PROCEDURE power*(base,exponent:FLOAT64):FLOAT32;
BEGIN
	IF ABS(base)<Eps THEN RETURN 0
	ELSE RETURN SHORT(MathL.exp(exponent*MathL.ln(base)));
	END;
END power;

PROCEDURE powerL*(base,exponent:FLOAT64):FLOAT64;
BEGIN
	(*IF ABS(base)<EpsL THEN RETURN 0 *)
	IF ABS(base)<=0 THEN RETURN 0 (* should rather trap on negative argument*)
	ELSE RETURN MathL.exp(exponent*MathL.ln(base));
	END;
END powerL;

PROCEDURE intpower*(base:FLOAT32; exponent:SIGNED32):FLOAT32;
VAR res:FLOAT32; i:SIGNED32;
BEGIN
res:=1;
FOR i:=0 TO exponent-1 DO res:=res*base END;
RETURN res
END intpower;

(*
PROCEDURE ShortEnt*(CONST in:ARRAY OF FLOAT32; VAR out:ARRAY OF SIGNED16);

(** Sehr rasches SHORT(ENTIER()) fuer Arrays; von P Reali, 1/01*)

   CODE {SYSTEM.i386, SYSTEM.FPU}

   MOV   EDI, [EBP+8]       ; dest   = ADR(out)

   MOV   ECX, [EBP+12]      ; count  = LEN(out)

   MOV   ESI, [EBP+16]      ; source = ADR(in)

   CMP   ECX, [EBP+20]

   JGE   Ok

   PUSH  99                  ; LEN(in) > LEN(out)  then TRAP(99)

   INT   3

Ok:

   SUB   ESP, 8              ; change FPU rounding to "round to nearest"

   FSTCW [ESP]

   WAIT

   MOV   EBX, [ESP]

   OR    EBX, 0400H          ; clear bit 10,11 (round to nearest)

   MOV   [ESP+4], EBX

   FLDCW [ESP+4]

   JMP   Check

Loop:

   DEC   ECX

   FLD   DWORD [ESI][ECX*4]  ; in: FLOAT32

   FISTP INTEGER [EDI][ECX*2]   ; out: SIGNED16

   WAIT

Check:

   CMP   ECX, 0

   JG    Loop

   FLDCW [ESP]                ; restore original FPU configuration

   ADD   ESP, 8

END ShortEnt;
*)


PROCEDURE powerof2*(n:SIGNED32):SIGNED32;
VAR i:SIGNED32;
BEGIN
i:=0;
BIT.LSETBIT (i, SHORT(SHORT(n)));
RETURN i
END powerof2;

PROCEDURE round*(x:FLOAT32):SIGNED32;
BEGIN
	RETURN ENTIER(x+0.5);
END round;

PROCEDURE sigmoid*(x:FLOAT32):FLOAT32;
BEGIN
	IF x>upperExp THEN RETURN 1
	ELSIF (-x)>upperExp THEN RETURN 0
	ELSE RETURN SHORT(1/(LongOne+MathL.exp(-x)));
	END;
END sigmoid;

PROCEDURE invsigmoid*(x:FLOAT32):FLOAT32;
BEGIN
	IF x>1 THEN RETURN Inf
	ELSIF x=1 THEN RETURN 16
	ELSIF x>9.9999985E-01 THEN RETURN 16
	ELSIF x< 0 THEN RETURN -Inf
	ELSIF x=0 THEN RETURN -1.0097634E+02
	ELSIF x<-101 THEN RETURN -1.0097634E+02
	ELSE RETURN -SHORT(MathL.ln(LongOne/x-1));
	END;
END invsigmoid;

PROCEDURE invsigmoidL*(x:FLOAT64):FLOAT64;
BEGIN
	IF x>1 THEN RETURN InfL
	ELSIF x=1 THEN RETURN 16
	ELSIF x>9.9999985E-01 THEN RETURN 16
	ELSIF x< 0 THEN RETURN -InfL
	ELSIF x=0 THEN RETURN -1.0097634E+02
	ELSIF x<-101 THEN RETURN -1.0097634E+02
	ELSE RETURN -(MathL.ln(LongOne/x-1));
	END;
END invsigmoidL;

PROCEDURE pythag* (a,b: FLOAT32): FLOAT32;
(**calculates sqrt(aSquare+bSquare) without destructive under- or overflow*)
VAR absa, absb: FLOAT32;
BEGIN
		absa := ABS(a);
		absb := ABS(b);
		IF (absa > absb) THEN RETURN(absa * Math.sqrt(1.0 + absb * absb / (absa * absa)));
		ELSIF absb = 0 THEN RETURN 0
		ELSE RETURN (absb * Math.sqrt(1.0 + absa * absa / (absb * absb)))
		END;
END pythag;


PROCEDURE fastExp(x:FLOAT64):FLOAT64; (*  decreasingly accurate for increasing x, and only faster than standard if inlined,  see https://codingforspeed.com/using-faster-exponential-approximation/ *)
	BEGIN
		IF x<2 THEN
			x:=1+ 1.0D0/1024 * x; (*/1024/1024;  *) (*will increase accuracy for higher x *)
			x:=x*x; x:=x*x; x:=x*x; x:=x*x;
			x:=x*x; x:=x*x; x:=x*x; x:=x*x;
			x:=x*x; x:=x*x;
			(*
			x:=x*x; x:=x*x; x:=x*x; x:=x*x;
			x:=x*x; x:=x*x; x:=x*x; x:=x*x;
			x:=x*x; x:=x*x;

			x:=x*x; x:=x*x; x:=x*x; x:=x*x;
			x:=x*x; x:=x*x; x:=x*x; x:=x*x;
			x:=x*x; x:=x*x;
			*)
			RETURN x
		ELSE
			RETURN MathL.exp(x)
		END;
	END fastExp;


PROCEDURE tanh*( x: FLOAT32 ): FLOAT32; (*secured against overflow - from MathRe.Mod*)
VAR abs, exp, expM, exp2xM1, res: FLOAT32;
BEGIN
	abs := ABS( x );
	IF abs < 1 THEN exp2xM1 := Math.exp( 2 * abs ) - 1;  res := sign( x ) * exp2xM1 / (2 + exp2xM1)
	ELSIF abs < expNegligible THEN exp := Math.exp( x );  expM := Math.exp( -x );  res := (exp - expM) / (exp + expM)
	ELSE res := sign( x )
	END;
	RETURN res
END tanh;

PROCEDURE tanhL*( x: FLOAT64 ): FLOAT64; (*secured against overflow - from MathRe.Mod*)
VAR abs, exp, expM, exp2xM1, res: FLOAT64;
BEGIN
	abs := ABS( x );
	IF abs < 1 THEN exp2xM1 := MathL.exp( 2 * abs ) - 1;  res := sign( x ) * exp2xM1 / (2 + exp2xM1)
	ELSIF abs < expNegligibleL THEN
		exp := MathL.exp( x );  expM := MathL.exp( -x );  res := (exp - expM) / (exp + expM)
	ELSE res := sign( x )
	END;
	RETURN res
END tanhL;

PROCEDURE logistic*( x: FLOAT32): FLOAT32;  (* logistic function as nonlinear element for unit response *)
BEGIN
	IF x >= expNegligible THEN RETURN 1
	ELSIF (-x) > expNegligible THEN RETURN 0
	ELSE RETURN 1 / (1 + Math.exp( -x ));
	END;
END logistic;

PROCEDURE logisticL*( x: FLOAT64): FLOAT64;  (* logistic function as nonlinear element for unit response *)
BEGIN
	IF x >= expNegligibleL THEN RETURN 1
	ELSIF (-x) > expNegligibleL THEN RETURN 0
	ELSE RETURN 1 / (1 + MathL.exp( -x ));
	END;
END logisticL;

(*
PROCEDURE tanhL*(x:FLOAT64):FLOAT64;
VAR e:FLOAT64;
BEGIN
	e:=MathL.exp(2*x);
	RETURN (e-1)/(e+1)
END tanhL;
*)

PROCEDURE sign* (x:FLOAT64):SIGNED8;
BEGIN
	IF x>=0 THEN RETURN 1 ELSE RETURN -1 END;
END sign;

PROCEDURE max*(CONST Data:ARRAY OF SIGNED32):SIGNED32;
VAR res:SIGNED32; len,i:SIZE;
BEGIN
	len:=LEN(Data);
	IF LEN(Data)=0 THEN res:= 0
	ELSE res:=Data[0];
		FOR i:=1 TO len-1 DO IF Data[i]>res THEN res:=Data[i] END END
	END;
	RETURN res;
END max;

PROCEDURE min*(CONST Data:ARRAY OF SIGNED32):SIGNED32;
VAR res:SIGNED32; len,i:SIZE;
BEGIN
	len:=LEN(Data);
	IF LEN(Data)=0 THEN res:= 0
	ELSE res:=Data[0];
		FOR i:=1 TO len-1 DO IF Data[i]<res THEN res:=Data[i] END END
	END;
	RETURN res;
END min;

PROCEDURE Max*(x,y:SIGNED32):SIGNED32;
BEGIN IF x>=y THEN RETURN x ELSE RETURN y END
END Max;

PROCEDURE Min*(x,y:SIGNED32):SIGNED32;
BEGIN IF x<=y THEN RETURN x ELSE RETURN y END
END Min;

PROCEDURE Clamp*(x,min,max:SIGNED32):SIGNED32;
BEGIN
	RETURN MIN(max, MAX(min,x))
END Clamp;


PROCEDURE RMax*(x,y:FLOAT64):FLOAT64;
BEGIN IF x>=y THEN RETURN x ELSE RETURN y END
END RMax;

PROCEDURE rMax*(x,y:FLOAT32):FLOAT32;
BEGIN IF x>=y THEN RETURN x ELSE RETURN y END
END rMax;

PROCEDURE RMin*(x,y:FLOAT64):FLOAT64;
BEGIN IF x<=y THEN RETURN x ELSE RETURN y END
END RMin;

PROCEDURE rMin*(x,y:FLOAT32):FLOAT32;
BEGIN IF x<y THEN RETURN x ELSE RETURN y END
END rMin;

PROCEDURE rescaleInt*(x,minIn,maxIn,minOut,maxOut:SIGNED16):SIGNED16;
BEGIN
IF x>maxIn THEN x:=maxIn ELSIF x<minIn THEN x:=minIn END;
RETURN SHORT(round( (x-minIn)/(maxIn-minIn)*(maxOut-minOut)+minOut))
END rescaleInt;

(*PROCEDURE IsPowerOf2*(i:SIGNED32):BOOLEAN;
BEGIN
	IF i=1 THEN RETURN TRUE
	ELSIF i<1 THEN RETURN FALSE
	ELSIF (i MOD 2)#0 THEN RETURN FALSE
	ELSE RETURN IsPowerOf2(i DIV 2);
	END;
END IsPowerOf2;*)

PROCEDURE IsPowerOf2*(n:SIGNED32):BOOLEAN;
VAR i,cnt:SIGNED8;
BEGIN
	i:=wordlengthlongint-1;
	cnt:=0;
	WHILE i>=0 DO
		IF BIT.BIT(n,i) THEN INC(cnt); END;
		DEC(i)
	END;
	IF cnt=1 THEN RETURN TRUE ELSE RETURN FALSE END;
END IsPowerOf2;


(*PROCEDURE RoundToPowerOf2*(i:SIGNED32):SIGNED32;
VAR number,n:SIGNED32;
BEGIN
	n:=0; number:=i;
	IF i>=2 THEN REPEAT number:=number DIV 2; INC(n) UNTIL number<1;
		RETURN round(power(2,n-1))
	ELSIF i>=1 THEN RETURN 1
	ELSE RETURN 0
	END;
END RoundToPowerOf2;*)

PROCEDURE RoundToPowerOf2*(n:SIGNED32):SIGNED32;
VAR i:SIGNED8;
BEGIN
i:=wordlengthlongint-1;
WHILE (i>0)&~BIT.BIT(n,i) DO DEC(i) END;
DEC(i);
WHILE i>=0 DO BIT.LCLRBIT(n,i); DEC(i) END;
RETURN n
END RoundToPowerOf2;

PROCEDURE ASCIIHex2SInt(c:CHAR):SIGNED8;
	BEGIN
		CASE c OF
			"0": RETURN 0;
		| "1": RETURN 1;
		| "2": RETURN 2;
		| "3": RETURN 3;
		| "4": RETURN 4;
		| "5": RETURN 5;
		| "6": RETURN 6;
		| "7": RETURN 7;
		| "8": RETURN 8;
		| "9": RETURN 9;
		| "A": RETURN 10;
		| "B": RETURN 11;
		| "C": RETURN 12;
		| "D": RETURN 13;
		| "E": RETURN 14;
		| "F": RETURN 15;
		ELSE RETURN 0;
		END;
	END ASCIIHex2SInt;

PROCEDURE ASCIIHexInt*(CONST A:ARRAY OF CHAR):SIGNED16;
VAR res:SIGNED16; i,len:SIZE;
BEGIN
	len:=LEN(A);
	IF len>4 THEN len:=4 END;
	res:=0;
	FOR i:=0 TO len-1 DO
		IF A[i]=0X THEN i:=len
		ELSE res:=BIT.IOR(ASCIIHex2SInt(A[i]), BIT.ILSH(res,4) );
		END;
	END;
	RETURN res
END ASCIIHexInt;

PROCEDURE ASCIIHexLInt*(CONST A:ARRAY OF CHAR):SIGNED32;
VAR res: SIGNED32; i,len:SIZE;
BEGIN
	len:=LEN(A);
	IF len>8 THEN len:=8 END;
	res:=0;
	FOR i:=0 TO len-1 DO
		IF A[i]=0X THEN i:=len
		ELSE res:=BIT.LOR(ASCIIHex2SInt(A[i]), ASH(res,4) );
		END;
	END;
	RETURN res
END ASCIIHexLInt;

PROCEDURE eps*():FLOAT32;
VAR x,y:FLOAT32;
BEGIN
	x:=0.5;
	WHILE (1-x<1)&(1-x>0) DO y:=x; x:=x/2 END;
	RETURN y
END eps;

PROCEDURE epsL*():FLOAT64;
VAR x,y:FLOAT64;
BEGIN
	x:=0.5;
	WHILE (1-x<1)&(1-x>0) DO y:=x; x:=x/2 END;
	RETURN y
END epsL;

PROCEDURE  arctan2*(x,y: FLOAT32): FLOAT32; (*arctan in range 0..2pi*)(* note that in C and Python, atan2 and arctan2 result in range -pi..pi *)
BEGIN
	IF (x>0) & (y>=0) THEN RETURN Math.arctan(y/x)
	ELSIF (x>0) & (y<0) THEN RETURN Math.arctan(y/x)+2*Math.pi
	ELSIF x<0 THEN RETURN Math.arctan(y/x)+Math.pi
	ELSIF (x=0) & (y>0) THEN RETURN Math.pi/2
	ELSIF (x=0) & (y<0) THEN RETURN 3*Math.pi/2
	ELSE (*( x=0) & (y=0) *) RETURN 0 
	END
END arctan2;


PROCEDURE arctan2L*(x,y:FLOAT64):FLOAT64; (*arctan in range 0..2pi*) (* note that in C and Python, atan2 and arctan2 result in range -pi..pi *)
BEGIN
	IF (x>0) & (y>=0) THEN RETURN MathL.arctan(y/x)
	ELSIF (x>0) & (y<0) THEN RETURN MathL.arctan(y/x)+2*MathL.pi
	ELSIF x<0 THEN RETURN MathL.arctan(y/x)+MathL.pi
	ELSIF (x=0) & (y>0) THEN RETURN MathL.pi/2
	ELSIF (x=0) & (y<0) THEN RETURN 3*MathL.pi/2
	ELSE (*( x=0) & (y=0) *) RETURN 0 
	END
END arctan2L;

BEGIN
	Comments:=FALSE;

	OneDivLn10:=1/Math.ln(10);
	NaN:= Reals.NaN(1);
	NaNL:=Reals.NaN(1);
	Inf:=Reals.NaN(0);
	InfL:=Reals.NaN(0);
	EpsL:=epsL();
	Eps:=eps();
	expNegligibleL := -MathL.ln( EpsL ) / 2;
	expNegligible := -Math.ln( Eps ) / 2;
END PMath.

SystemTools.FreeDownTo PMath~
PMath.Test
PMath.EpsL

