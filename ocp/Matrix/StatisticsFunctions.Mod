(***************** Oberon	StatisticsFunctions .Mod **********************
		Version 1.0 P.Hunziker (c) 2000

		Derived from TurboPascal Library FMATH.PAS version 2.3 (c) J. Debord, July 2000
		http://ourworld.compuserve.com/homepages/JDebord/

 **********
 This library is distributed as freeware. You may use it any way you like, as
 long as you don't charge money for it, remove the copyright notices, or hold
 anyone liable for its results.
 ************************************************************** *)


(* **********************************************************************
 This unit implements some mathematical functions in Pascal ----ported to Oberon PH 9/2000
	**********************************************************************
from J.Debord's Pascal version:
	.....
		2) Error handling: The function MathError returns the error code from
		 the last function evaluation. It must be checked immediately after
		 a function call:
			 Y := f(X);				(* f is one of the functions of the library *)
			 IF MathError = FNOK THEN

		 The possible error codes, and the default values attributed to the
		 function, are the following:

		 ------------------------------------------------------------------
		 Error code	 Value	SignIFicance						Function default value
		 ------------------------------------------------------------------
		 FNOK					0		No error
		 FNDOMAIN		 -1		Argument domain error	 0
		 FNSING			 -2		Function singularity		+/- MAXNUM
		 FNOVERFLOW	 -3		Overflow range error		MAXNUM
		 FNUNDERFLOW	-4		Underflow range error	 0
		 ------------------------------------------------------------------

		 where MAXNUM is a constant defining the highest number which may be
		 represented within the chosen floating point TYPE.

		 The standard functions Exp and Ln have been redefined according to
		 the above conventions as Expo and Log.

	********************************************************************** *)

MODULE StatisticsFunctions;
IMPORT BasicMath:=MathL;

(* ----------------------------------------------------------------------
	Floating point TYPE (Default = FLOAT64)
	---------------------------------------------------------------------- *)

		TYPE Float = FLOAT64;
	TabCoef = ARRAY [10] OF Float;

(* ----------------------------------------------------------------------
	Mathematical constants
	---------------------------------------------------------------------- *)

CONST
	PI			*	 = 3.14159265358979323846;	(* Pi *)
	LN2		*		= 0.69314718055994530942;	(* Ln(2) *)
	LN10	 *		= 2.30258509299404568402;	(* Ln(10) *)
	LNPI		*	 = 1.14472988584940017414;	(* Ln(Pi) *)
	INVLN2	*	 = 1.44269504088896340736;	(* 1/Ln(2) *)
	INVLN10 *	 = 0.43429448190325182765;	(* 1/Ln(10) *)
	TWOPI	 *	 = 6.28318530717958647693;	(* 2*Pi *)
	PIDIV2	*	 = 1.57079632679489661923;	(* Pi/2 *)
	SQRTPI	*	 = 1.77245385090551602730;	(* Sqrt(Pi) *)
	SQRT2PI	*	= 2.50662827463100050242;	(* Sqrt(2*Pi) *)
	INVSQRT2PI * = 0.39894228040143267794;	(* 1/Sqrt(2*Pi) *)
	LNSQRT2PI *	= 0.91893853320467274178;	(* Ln(Sqrt(2*Pi)) *)
	LN2PIDIV2	*	= 0.91893853320467274178;	(* Ln(2*Pi)/2 *)
	SQRT2		*	= 1.41421356237309504880;	(* Sqrt(2) *)
	SQRT2DIV2 *	= 0.70710678118654752440;	(* Sqrt(2)/2 *)
	GOLD	 *		= 1.61803398874989484821;	(* Golden Mean = (1 + Sqrt(5))/2 *)
	CGOLD	*		= 0.38196601125010515179;	(* 2 - GOLD *)


(* Used by IGamma and IBeta *)
	BIG		= 9.223372036854775808E18;
	BIGINV = 1.084202172485504434007E-19;

(* ----------------------------------------------------------------------
	Machine-dependent CONSTants
	---------------------------------------------------------------------- *)

(* constants for use with Float=FLOAT64; These constants are still approximate
and could profit from improved definition, preferably in machine-dependent base modules*)
CONST
	MACHEP = 2.220446049250E-16;		 (* Floating point precision: 2^(-52) *)
	MAXNUM = MAX(Float);		(* Max. floating point number *)
	MINNUM = MIN(Float);		(* Min. floating point number *)
	MAXLOG = 709.7827128933840; (* Max. argument for Exp = Ln(MAXNUM) *)
	MINLOG = -708.396392; (* Min. argument for Exp *)
	MAXFAC = 170; (* Max. argument for Factorial *)
	MAXGAM = 170; (* Max. argument for Gamma: Improve ! *)
	MAXLGM = MAXNUM/1000; (* Max. argument for LnGamma: Improve !	*)

(* ----------------------------------------------------------------------
	Error codes for mathematical functions
	---------------------------------------------------------------------- *)
CONST
	FNOK		*		=	 0;	(* No error *)
	FNDOMAIN	*	= - 1;	(* Argument domain error *)
	FNSING		*	= - 2;	(* Function singularity *)
	FNOVERFLOW *	= - 3;	(* Overflow range error *)
	FNUNDERFLOW * = - 4;	(* Underflow range error *)
	FNTLOSS	*	 = - 5;	(* Total loss of precision *)
	FNPLOSS	 *	= - 6;	(* Partial loss of precision *)

(* ----------------------------------------------------------------------
	Global variables and constants
	---------------------------------------------------------------------- *)

CONST
	NFACT = 33;	(* The factorials of the first NFACT integers are stored
								 in a table *)
VAR
	MathErr * : SIGNED32;	(* Error code from the latest function evaluation *)
	FactArray : ARRAY [NFACT+1] OF Float;	(* Table of factorials *)
	StirfSTIR,GamSmallS,GamSmallSN,StirfLP,GammaP,GammaQ,LnGammaP,LnGammaQ,
	InvNormP0,InvNormQ0,InvNormP1,InvNormQ1,InvNormP2,InvNormQ2,InvNormP3,
	InvNormQ3:	TabCoef ;
	I : SIGNED32;

(* interface
 ------- Error handling function-------------
PROCEDURE MathError : SIGNED32;	(* Error code from the last function call *)

 ------- Minimum, maximum, sign and exchange---------------
PROCEDURE FMin(X, Y : Float) : Float;			(* Minimum of 2 reals *)
PROCEDURE FMax(X, Y : Float) : Float;			(* Maximum of 2 reals *)
PROCEDURE IMin(X, Y : SIGNED32) : SIGNED32;	(* Minimum of 2 integers *)
PROCEDURE IMax(X, Y : SIGNED32) : SIGNED32;	(* Maximum of 2 integers *)
PROCEDURE Sgn(X : Float) : SIGNED32;				(* Sign (returns 1 IF X = 0) *)
PROCEDURE Sgn0(X : Float) : SIGNED32;			 (* Sign (returns 0 IF X = 0) *)

PROCEDURE FSwap(VAR X, Y : Float);				(* Exchange 2 reals *)
PROCEDURE ISwap(VAR X, Y : SIGNED32);			(* Exchange 2 integers *)

 ------ Assembler functions	---------------
 (None in this version)

 --------- Sign, logarithms, exponentials and power---------------
PROCEDURE Expo(X : Float) : Float;									 (* Exponential *)
PROCEDURE Exp2(X : Float) : Float;									 (* 2^X *)
PROCEDURE Exp10(X : Float) : Float;									(* 10^X *)
PROCEDURE Log(X : Float) : Float;										(* Natural log *)
PROCEDURE Log2(X : Float) : Float;									 (* Log, base 2 *)
PROCEDURE Log10(X : Float) : Float;									(* Decimal log *)
PROCEDURE LogA(X, A : Float) : Float;								(* Log, base A *)
PROCEDURE IntPower(X : Float; N : SIGNED32) : Float;	(* X^N *)
PROCEDURE Power(X, Y : Float) : Float;							 (* X^Y, X >= 0 *)
PROCEDURE Pythag(X, Y : Float) : Float;							(* Sqrt(X^2 + Y^2) *)
PROCEDURE Logistic(X : Float) : Float;  (* logistic function as nonlinear element for unit response *)

 ------- Trigonometric and inverse trigonometric functions --------------
PROCEDURE FixAngle(Theta : Float) : Float;	(* Set Theta in -Pi..Pi *)
PROCEDURE Tan(X : Float) : Float;					 (* Tangent *)
PROCEDURE ArcSin(X : Float) : Float;				(* Arc sinus *)
PROCEDURE ArcCos(X : Float) : Float;				(* Arc cosinus *)
PROCEDURE ArcTan2(Y, X : Float) : Float;		(* Angle (Ox, OM) with M(X,Y) *)

PROCEDURE SinCos(X : Float; var SinX, CosX : Float);	(* Sin & Cos *)

----------------- Hyperbolic and inverse hyperbolic functions----------
PROCEDURE Sinh(X : Float) : Float;		 (* Hyperbolic sine *)
PROCEDURE Cosh(X : Float) : Float;		 (* Hyperbolic cosine *)
PROCEDURE Tanh(X : Float) : Float;		 (* Hyperbolic tangent *)
PROCEDURE ArcSinh(X : Float) : Float;	(* Inverse hyperbolic sine *)
PROCEDURE ArcCosh(X : Float) : Float;	(* Inverse hyperbolic cosine *)
PROCEDURE ArcTanh(X : Float) : Float;	(* Inverse hyperbolic tangent *)

PROCEDURE SinhCosh(X : Float; var SinhX, CoshX : Float);	(* Sinh & Cosh *)

---------- Special functions ------------------------
PROCEDURE Fact(N : SIGNED32) : Float;				 (* Factorial *)
PROCEDURE Binomial(N, K : SIGNED32) : Float;	(* Binomial coef. C(N,K) *)
PROCEDURE Gamma(X : Float) : Float;					(* Gamma PROCEDURE *)
PROCEDURE SgnGamma(X : Float) : SIGNED32;		 (* Sign of Gamma PROCEDURE *)
PROCEDURE LnGamma(X : Float) : Float;				(* Log(|Gamma(X)|) *)
PROCEDURE IGamma(A, X : Float) : Float;			(* Incomplete Gamma PROCEDURE *)
PROCEDURE JGamma(A, X : Float) : Float;			(* Complement of IGamma *)
PROCEDURE Beta(X, Y : Float) : Float;				(* Beta PROCEDURE *)
PROCEDURE IBeta(A, B, X : Float) : Float;		(* Incomplete Beta PROCEDURE *)
PROCEDURE Erf(X : Float) : Float;						(* Error PROCEDURE *)
PROCEDURE Erfc(X : Float) : Float;					 (* Complement of Erf *)

-------- Binomial distribution with probability P and number of repetitions N----
PROCEDURE PBinom(N : SIGNED32; P : Float; K : SIGNED32) : Float; (* Prob(X = K) *)
PROCEDURE FBinom(N : SIGNED32; P : Float; K : SIGNED32) : Float; (* Prob(X <= K) *)

--------------------- Poisson distribution with mean Mu-----------
PROCEDURE PPoisson(Mu : Float; K : SIGNED32) : Float;	(* Prob(X = K) *)
PROCEDURE FPoisson(Mu : Float; K : SIGNED32) : Float;	(* Prob(X <= K) *)

---------------- Standard normal distribution--------------------
PROCEDURE DNorm(X : Float) : Float;		(* Density of standard normal *)
PROCEDURE FNorm(X : Float) : Float;		(* Prob(U <= X) *)
PROCEDURE PNorm(X : Float) : Float;		(* Prob(|U| >= |X|) *)
PROCEDURE InvNorm(P : Float) : Float;	(* Inverse of FNorm : returns X
																				such that Prob(U <= X) = P*)

-----------------	Student distribution with Nu d.o.f.-------------
PROCEDURE DStudent(Nu : SIGNED32; X : Float) : Float;	(* Density of t *)
PROCEDURE FStudent(Nu : SIGNED32; X : Float) : Float;	(* Prob(t <= X) *)
PROCEDURE PStudent(Nu : SIGNED32; X : Float) : Float;	(* Prob(|t| >= |X|) *)

---------------- Khi-2 distribution with Nu d.o.f.----------------
PROCEDURE DKhi2(Nu : SIGNED32; X : Float) : Float;	(* Density of Khi2 *)
PROCEDURE FKhi2(Nu : SIGNED32; X : Float) : Float;	(* Prob(Khi2 <= X) *)
PROCEDURE PKhi2(Nu : SIGNED32; X : Float) : Float;	(* Prob(Khi2 >= X) *)

----------- Fisher-Snedecor distribution with Nu1 and Nu2 d.o.f.-------
PROCEDURE DSnedecor(Nu1, Nu2 : SIGNED32; X : Float) : Float;	(* Density of F *)
PROCEDURE FSnedecor(Nu1, Nu2 : SIGNED32; X : Float) : Float;	(* Prob(F <= X) *)
PROCEDURE PSnedecor(Nu1, Nu2 : SIZE; X : Float) : Float;	(* Prob(F >= X) *)

------------- Exponential distribution------------------
PROCEDURE DExpo(A, X : Float) : Float;	(* Density of exponential distrib. *)
PROCEDURE FExpo(A, X : Float) : Float;	(* Prob( <= X) *)

------------- Beta distribution-----------------
PROCEDURE DBeta(A, B, X : Float) : Float;	 (* Density of Beta distribution *)
PROCEDURE FBeta(A, B, X : Float) : Float;	 (* Prob( <= X) *)

-------------	Gamma distribution-----------
PROCEDURE DGamma(A, B, X : Float) : Float;	(* Density of Gamma distribution *)
PROCEDURE FGamma(A, B, X : Float) : Float;	(* Prob( <= X) *)

******************************************
************ implementation *******************)

(* ----------------------------------------------------------------------
	Error handling procedures
	---------------------------------------------------------------------- *)

	PROCEDURE DefaultVal(ErrCode : SIGNED32) : Float;
	(* Sets the global variable MathErr and the PROCEDURE default value
		according to the error code *)
	BEGIN
		MathErr := ErrCode;
		CASE ErrCode OF
			FNDOMAIN		: RETURN 0.0;
			| FNSING			: RETURN MAXNUM;
			| FNOVERFLOW	: RETURN MAXNUM;
			| FNUNDERFLOW : RETURN 0.0;
		ELSE
			RETURN 0.0;
		END;
	END DefaultVal;

	PROCEDURE MathError*() : SIGNED32;	(* Error code from the last function call *)
	BEGIN
		RETURN MathErr;
	END MathError;

(* ----------------------------------------------------------------------
	Minimum, maximum and sign
	---------------------------------------------------------------------- *)

	PROCEDURE FMin*(X, Y : Float) : Float;			(* Minimum of 2 reals *)
	BEGIN
		IF X <= Y THEN RETURN X
		ELSE RETURN Y
		END;
	END FMin;

	PROCEDURE FMax*(X, Y : Float) : Float;			(* Maximum of 2 reals *)
	BEGIN
		IF X >= Y THEN RETURN	X
		ELSE RETURN Y
		END;
	END FMax;

	PROCEDURE IMin*(X, Y : SIGNED32) : SIGNED32;	(* Minimum of 2 integers *)
	BEGIN
		IF X <= Y THEN RETURN X
		ELSE RETURN Y;
		END;
	END IMin;

	PROCEDURE IMax*(X, Y : SIGNED32) : SIGNED32;	(* Maximum of 2 integers *)
	BEGIN
		IF X >= Y THEN RETURN X
		ELSE RETURN	Y
		END;
	END IMax;

	PROCEDURE FSwap*(VAR X, Y : Float);				(* Exchange 2 reals *)
	VAR
		Temp : Float;
	BEGIN
		Temp := X;
		X := Y;
		Y := Temp;
	END FSwap;

	PROCEDURE ISwap*(VAR X, Y : SIGNED32);			(* Exchange 2 integers *)
	VAR
		Temp : SIGNED32;
	BEGIN
		Temp := X;
		X := Y;
		Y := Temp;
	END ISwap;

	PROCEDURE Sgn*(X : Float) : SIGNED32;				(* Sign (returns 1 IF X = 0) *)
	BEGIN
		IF X >= 0.0 THEN RETURN 1
		ELSE RETURN - 1
		END;
	END Sgn;

	PROCEDURE Sgn0*(X : Float) : SIGNED32;			 (* Sign (returns 0 IF X = 0) *)
	BEGIN
		IF X > 0.0 THEN RETURN 1
		ELSIF X = 0.0 THEN RETURN 0
	ELSE RETURN - 1
	END;
	END Sgn0;

(* ----------------------------------------------------------------------
	Assembler functions: NOT NEEDED FOR OBERON VERSION
	---------------------------------------------------------------------- *)

(* ----------------------------------------------------------------------
	Elementary functions
	---------------------------------------------------------------------- *)
	PROCEDURE Ln(X : Float) : Float;
	BEGIN RETURN BasicMath.ln(X) END Ln;

	PROCEDURE Exp(X:Float) : Float;
	BEGIN RETURN BasicMath.exp(X) END Exp;

	PROCEDURE Sin(X : Float) : Float;
	BEGIN RETURN BasicMath.sin(X) END Sin;

	PROCEDURE Cos(X:Float) : Float;
	BEGIN RETURN BasicMath.cos(X) END Cos;

	PROCEDURE ArcTan(X:Float) : Float;
	BEGIN RETURN BasicMath.arctan(X) END ArcTan;

	PROCEDURE Sqr(X:Float) : Float;
	BEGIN RETURN X*X END Sqr;

	PROCEDURE Sqrt(X:Float) : Float;
	BEGIN RETURN BasicMath.sqrt(X) END Sqrt; (** To do: Handling of negative numbers*)

	PROCEDURE Expo*(X : Float) : Float;
	BEGIN
		MathErr := FNOK;
		IF X < MINLOG THEN RETURN DefaultVal(FNUNDERFLOW)
		ELSIF X > MAXLOG THEN RETURN DefaultVal(FNOVERFLOW)
		ELSE RETURN Exp(X);
		END;
	END Expo;

	PROCEDURE Exp2*(X : Float) : Float;
	VAR
		XLn2 : Float;
	BEGIN
		MathErr := FNOK;
		XLn2 := X * LN2;
		IF XLn2 < MINLOG THEN RETURN DefaultVal(FNUNDERFLOW)
		ELSIF XLn2 > MAXLOG THEN RETURN DefaultVal(FNOVERFLOW)
		ELSE RETURN Exp(XLn2)
		END;
	END Exp2;

	PROCEDURE Exp10*(X : Float) : Float;
	VAR
		XLn10 : Float;
	BEGIN
		MathErr := FNOK;
		XLn10 := X * LN10;
		IF XLn10 < MINLOG THEN RETURN DefaultVal(FNUNDERFLOW)
		ELSIF XLn10 > MAXLOG THEN RETURN DefaultVal(FNOVERFLOW)
		ELSE RETURN Exp(XLn10)
		END;
	END Exp10;

	PROCEDURE Log*(X : Float) : Float;
	BEGIN
		MathErr := FNOK;
		IF X < 0.0 THEN RETURN DefaultVal(FNDOMAIN)
		ELSIF X = 0.0 THEN RETURN DefaultVal(FNSING)
		ELSE RETURN Ln(X);
		END;
	END Log;

	PROCEDURE Log10*(X : Float) : Float;
	BEGIN
		MathErr := FNOK;
		IF X < 0.0 THEN RETURN DefaultVal(FNDOMAIN)
		ELSIF X = 0.0 THEN RETURN DefaultVal(FNSING)
		ELSE RETURN Ln(X) * INVLN10
		END;
	END Log10;

	PROCEDURE Log2*(X : Float) : Float;
	BEGIN
		MathErr := FNOK;
		IF X < 0.0 THEN RETURN DefaultVal(FNDOMAIN)
		ELSIF X = 0.0 THEN RETURN	DefaultVal(FNSING)
		ELSE RETURN Ln(X) * INVLN2
		END;
	END Log2;

	PROCEDURE LogA*(X, A : Float) : Float;
	BEGIN
		MathErr := FNOK;
		IF (X < 0.0) OR (A <= 0.0) OR (A = 1.0) THEN RETURN DefaultVal(FNDOMAIN)
		ELSIF X = 0.0 THEN RETURN Sgn(1.0 - A) * DefaultVal(FNSING)
		ELSE
			RETURN Ln(X) / Ln(A);
		END;
	END LogA;

	PROCEDURE IntPower*(X : Float; N : SIGNED32) : Float;
	(* Computes X^N by REPEATed multiplications *)
	VAR
		M : SIGNED32;
		T : Float;
	BEGIN
		MathErr := FNOK;

		IF X = 0.0 THEN
				IF N = 0 THEN (* 0^0 = lim	x^x = 1 *)
					RETURN 1.0	 (*			 x->0				 *)
				ELSIF N > 0 THEN RETURN 0.0	 (* 0^N = 0 *)
				ELSE RETURN DefaultVal(FNSING);
				END;
		END;

		IF N = 0 THEN RETURN 1.0 END;

		(* Legendre's algorithm for minimizing the number of multiplications *)
		T := 1.0;
		M := ABS(N);
		REPEAT
			IF ODD(M) THEN
					DEC(M);
					T := T * X;
			ELSE
					M := M DIV 2;
					X := Sqr(X);
			END;
		UNTIL M = 0;

		IF N > 0 THEN RETURN T
		ELSE RETURN 1.0 / T
		END;
	END IntPower;

	PROCEDURE Power*(X, Y : Float) : Float;
	(* Computes X^Y = Exp(Y * Ln(X)), for X >= 0 *)
	VAR
		YLnX : Float;
	BEGIN
		MathErr := FNOK;
		IF X < 0.0 THEN RETURN DefaultVal(FNDOMAIN) END;
		IF X = 0.0 THEN
				 IF Y = 0.0 THEN
			 (* 0^0 = lim	x^x = 1 *)
					RETURN 1.0				(*			 x->0				 *)
				ELSIF Y > 0.0 THEN RETURN 0.0				(* 0^Y = 0 *)
				ELSE RETURN DefaultVal(FNSING);
				END;
		END;
		IF Y = 0.0 THEN RETURN 1.0 END;
		YLnX := Y * Ln(X);

		IF YLnX < MINLOG THEN RETURN DefaultVal(FNUNDERFLOW)
		ELSIF YLnX > MAXLOG THEN RETURN DefaultVal(FNOVERFLOW)
		ELSE RETURN Exp(YLnX);
		END;
	END Power;

	PROCEDURE Pythag*(X, Y : Float) : Float;
	(* Computes Sqrt(X^2 + Y^2) without destructive underflow or overflow *)
	VAR
		ABSX, ABSY : Float;
	BEGIN
		MathErr := FNOK;
		ABSX := ABS(X);
		ABSY := ABS(Y);
		IF ABSX > ABSY THEN RETURN ABSX * Sqrt(1.0 + Sqr(ABSY / ABSX))
		ELSIF ABSY = 0.0 THEN RETURN 0.0
		ELSE RETURN ABSY * Sqrt(1.0 + Sqr(ABSX / ABSY));
		END;
	END Pythag;

	PROCEDURE Logistic*(X : Float) : Float;  (* logistic function as nonlinear element for unit response *)
	BEGIN
		IF X >= 18.3684002848 (*expNegligibleL*) THEN RETURN 1
		ELSIF (-X) > 18.3684002848 (*expNegligibleL*) THEN RETURN 0
		ELSE RETURN 1 / (1 + Exp( -X ));
		END;
	END Logistic;

	PROCEDURE SinCos*(X : Float; VAR SinX, CosX : Float);
	BEGIN
		MathErr := FNOK;
		SinX := Sin(X);
		CosX := Cos(X);
	END SinCos;

	PROCEDURE FixAngle*(Theta : Float) : Float;
	BEGIN
		MathErr := FNOK;
		WHILE Theta > PI DO Theta := Theta - TWOPI END;
		WHILE Theta <= - PI DO Theta := Theta + TWOPI END;
		RETURN Theta;
	END FixAngle;

	PROCEDURE Tan*(X : Float) : Float;
	VAR
		SinX, CosX : Float;
	BEGIN
		MathErr := FNOK;
		SinX := Sin(X);
		CosX := Cos(X);
		IF CosX = 0.0 THEN RETURN Sgn(SinX) * DefaultVal(FNSING)
		ELSE RETURN SinX / CosX
		END;
	END Tan;

	PROCEDURE ArcSin*(X : Float) : Float;
	BEGIN
		MathErr := FNOK;
		IF (X < - 1.0) OR (X > 1.0) THEN RETURN DefaultVal(FNDOMAIN)
		ELSIF X = 1.0 THEN RETURN PIDIV2
		ELSIF X = - 1.0 THEN RETURN - PIDIV2
		ELSE RETURN ArcTan(X / Sqrt(1.0 - Sqr(X)));
	END;
	END ArcSin;

	PROCEDURE ArcCos*(X : Float) : Float;
	BEGIN
		MathErr := FNOK;
		IF (X < - 1.0) OR (X > 1.0) THEN RETURN DefaultVal(FNDOMAIN)
		ELSIF X = 1.0 THEN RETURN 0.0
		ELSIF X = - 1.0 THEN RETURN PI
		ELSE RETURN PIDIV2 - ArcTan(X / Sqrt(1.0 - Sqr(X)));
	END;
	END ArcCos;

	PROCEDURE ArcTan2*(Y, X : Float) : Float;
	VAR
		Theta : Float;
	BEGIN
		MathErr := FNOK;
		IF X = 0.0 THEN
			IF Y = 0.0 THEN RETURN 0.0
			ELSIF Y > 0.0 THEN RETURN PIDIV2
			ELSE RETURN - PIDIV2
			END;
		ELSE
				 (* 4th/1st quadrant -PI/2..PI/2 *)
				RETURN ArcTan(Y / X)
		END;

				(* 2nd/3rd quadrants *)
		 IF X < 0.0 THEN
				IF Y >= 0.0 THEN RETURN Theta + PI	 (* 2nd quadrant:	PI/2..PI *)
				ELSE RETURN Theta - PI;	(* 3rd quadrant: -PI..-PI/2 *)
				END;
			END;
	END ArcTan2;

(* ----------------------------------------------------------------------
	Hyperbolic functions
	---------------------------------------------------------------------- *)

	PROCEDURE Sinh*(X : Float) : Float;
	VAR
		ExpX : Float;
	BEGIN
		MathErr := FNOK;
		IF (X < MINLOG) OR (X > MAXLOG) THEN RETURN Sgn(X) * DefaultVal(FNOVERFLOW)
		ELSE
				ExpX := Exp(X);
				RETURN 0.5 * (ExpX - 1.0 / ExpX);
		END;
	END Sinh;

	PROCEDURE Cosh*(X : Float) : Float;
	VAR
		ExpX : Float;
	BEGIN
		MathErr := FNOK;
		IF (X < MINLOG) OR (X > MAXLOG) THEN RETURN DefaultVal(FNOVERFLOW)
		ELSE
				ExpX := Exp(X);
				RETURN 0.5 * (ExpX + 1.0 / ExpX);
		END;
	END Cosh;

	PROCEDURE SinhCosh*(X : Float; VAR SinhX, CoshX : Float);
	VAR
		ExpX, ExpMinusX : Float;
	BEGIN
		MathErr := FNOK;
		IF (X < MINLOG) OR (X > MAXLOG) THEN
				CoshX := DefaultVal(FNOVERFLOW);
				SinhX := Sgn(X) * CoshX;
		 ELSE
				ExpX := Exp(X);
				ExpMinusX := 1.0 / ExpX;
				SinhX := 0.5 * (ExpX - ExpMinusX);
				CoshX := 0.5 * (ExpX + ExpMinusX);
		 END;
		 RETURN
	END SinhCosh;

	PROCEDURE Tanh*(X : Float) : Float;
	VAR
		SinhX, CoshX : Float;
	BEGIN
		SinhCosh(X, SinhX, CoshX);
		RETURN SinhX / CoshX;
	END Tanh;

	PROCEDURE ArcSinh*(X : Float) : Float;
	BEGIN
		MathErr := FNOK;
		RETURN Ln(X + Sqrt(Sqr(X) + 1.0));
	END ArcSinh;

	PROCEDURE ArcCosh*(X : Float) : Float;
	BEGIN
		MathErr := FNOK;
		IF X < 1.0 THEN RETURN DefaultVal(FNDOMAIN)
		ELSE RETURN Ln(X + Sqrt(Sqr(X) - 1.0));
		END;
	END ArcCosh;

	PROCEDURE ArcTanh*(X : Float) : Float;
	BEGIN
		MathErr := FNOK;
		IF (X < - 1.0) OR (X > 1.0) THEN RETURN DefaultVal(FNDOMAIN)
		ELSIF (X = - 1.0) OR (X = 1.0) THEN RETURN Sgn(X) * DefaultVal(FNSING)
		ELSE RETURN 0.5 * Ln((1.0 + X) / (1.0 - X));
		END;
	END ArcTanh;

(* ----------------------------------------------------------------------
	Special functions (translated from Cephes math library by S. Moshier:
	http://www.netlib.org/cephes)
	---------------------------------------------------------------------- *)


	PROCEDURE PolEvl*(VAR X : Float; CONST Coef : TabCoef; N : SIGNED32) : Float;
(* ----------------------------------------------------------------------
	Evaluates polynomial of degree N:

			2		 N
		y	=	C	+ C x + C x	+...+ C x
		 0	1		 2 	 N

	Coefficients are stored in reverse order:

	Coef[0] = C	, ..., Coef[N] = C
						 N									 0

	The PROCEDURE P1Evl() assumes that Coef[N] = 1.0 and is
	omitted from the ARRAY. Its calling arguments are
	otherwise the same as PolEvl().
	---------------------------------------------------------------------- *)
	VAR
		Ans : Float;
		I : SIGNED32;
	BEGIN
		Ans := Coef[0];
		FOR I := 1 TO N DO Ans := Ans * X + Coef[I] END;
		RETURN Ans;
	END PolEvl;

	PROCEDURE P1Evl*(VAR X : Float; CONST Coef : TabCoef; N : SIGNED32) : Float;
(* ----------------------------------------------------------------------
	Evaluate polynomial when coefficient of X is 1.0.
	Otherwise same as PolEvl.
	---------------------------------------------------------------------- *)
	VAR
		Ans : Float;
		I : SIGNED32;
	BEGIN
		Ans := X + Coef[0];
		FOR I := 1 TO N - 1 DO
			Ans := Ans * X + Coef[I]
		END;
		RETURN Ans;
	END P1Evl;

	PROCEDURE SgnGamma*(X : Float) : SIGNED32;
	BEGIN
		IF X > 0.0 THEN RETURN 1
		ELSIF ODD(ENTIER(ABS(X))) THEN RETURN 1
		ELSE RETURN - 1;
		END;
	END SgnGamma;

	PROCEDURE Stirf*(X : Float) : Float;
	(* Stirling's FORmula for the gamma function
		Gamma(x) = Sqrt(2*Pi) x^(x-.5) exp(-x) (1 + 1/x P(1/x))
		where P(x) is a polynomial *)
	VAR
		W, P : Float;
	BEGIN
		W := 1.0 / X;
		IF X > 1024.0 THEN
				P := 6.97281375836585777429E-5 * W + 7.84039221720066627474E-4;
				P := P * W - 2.29472093621399176955E-4;
				P := P * W - 2.68132716049382716049E-3;
				P := P * W + 3.47222222222222222222E-3;
				P := P * W + 8.33333333333333333333E-2;
		ELSE
			P := PolEvl(W, StirfSTIR, 8);
		RETURN SQRT2PI * Exp((X - 0.5) * Ln(X) - X) * (1.0 + W * P);
		END;
	END Stirf;

	PROCEDURE GamSmall*(X1, Z : Float) : Float;
	(* Gamma function for small values of the argument *)
	VAR
		P : Float;
	BEGIN
		IF X1 = 0.0 THEN RETURN DefaultVal(FNSING) END;
		IF X1 < 0.0 THEN
				X1 := - X1;
				P := PolEvl(X1, GamSmallSN, 8);
		ELSE
			P := PolEvl(X1, GamSmallS, 8)
		END;
		RETURN Z / (X1 * P);
	END	GamSmall;

	PROCEDURE StirfL*(X : Float) : Float;
	(* Approximate Ln(Gamma) by Stirling's formula, for X >= 13 *)
	VAR
		Q, W : Float;
	BEGIN
		Q := Ln(X) * (X - 0.5) - X;
		Q := Q + LNSQRT2PI;
		IF X > 1.0E+10 THEN RETURN Q
		ELSE
				W := 1.0 / Sqr(X);
				RETURN Q + PolEvl(W, StirfLP, 6) / X;
		END;
	END StirfL;

	PROCEDURE Gamma*(X : Float) : Float;
	VAR
		SgnGam, N : SIGNED32;
		A, X1, Z : Float;
	BEGIN
		MathErr := FNOK;
		SgnGam := SgnGamma(X);

		IF (X = 0.0) OR ((X < 0.0) & ((ENTIER(X)-X) = 0.0)) THEN
			RETURN SgnGam * DefaultVal(FNSING);
		END;

		IF X > MAXGAM THEN
			RETURN DefaultVal(FNOVERFLOW);
		END;

		A := ABS(X);
		IF A > 13.0 THEN
				IF X < 0.0 THEN
						N := ENTIER(A);
						Z := A - N;
						IF Z > 0.5 THEN
								N := N + 1;
								Z := A - N;
						END;
						Z := ABS(A * Sin(PI * Z)) * Stirf(A);
						IF Z <= PI / MAXNUM THEN
								RETURN SgnGam * DefaultVal(FNOVERFLOW);
						END;
						Z := PI / Z;
				ELSE
					Z := Stirf(X);
				END;
				RETURN SgnGam * Z;
		ELSE
				Z := 1.0;
				X1 := X;
				WHILE X1 >= 3.0 DO
						X1 := X1 - 1.0;
						Z := Z * X1;
				END;
				WHILE X1 < - 0.03125 DO
						Z := Z / X1;
						X1 := X1 + 1.0;
				END;
				IF X1 <= 0.03125 THEN RETURN GamSmall(X1, Z)
				ELSE
						WHILE X1 < 2.0 DO
								Z := Z / X1;
								X1 := X1 + 1.0;
						END;
						IF (X1 = 2.0) OR (X1 = 3.0) THEN RETURN Z
						ELSE
								X1 := X1 - 2.0;
								RETURN Z * PolEvl(X1, GammaP, 7) / PolEvl(X1, GammaQ, 8);
						END;
				END;
		END;
	END Gamma;

	PROCEDURE LnGamma*(X : Float) : Float;
	VAR
		N : SIGNED32;
		A, X1, Z : Float;
	BEGIN
		MathErr := FNOK;

		IF (X = 0.0) OR ((X < 0.0) & ((ENTIER(X)-X) = 0.0)) THEN RETURN	DefaultVal(FNSING); END;

		IF X > MAXLGM THEN RETURN DefaultVal(FNOVERFLOW); END;

		A := ABS(X);
		IF A > 34.0 THEN
			IF X < 0.0 THEN
				 	N := ENTIER(A);
					Z := A - N;
					IF Z > 0.5 THEN
							N := N + 1;
							Z := N - A;
					END;
					Z := A * Sin(PI * Z);
					IF Z = 0.0 THEN RETURN DefaultVal(FNOVERFLOW); END;
					Z := LNPI - Ln(Z) - StirfL(A);
			 ELSE
				Z := StirfL(X)
			END;
			RETURN Z;
		ELSIF X < 13.0 THEN
			Z := 1.0;
			X1 := X;
			WHILE X1 >= 3 DO
				X1 := X1 - 1.0;
				Z := Z * X1;
			END;
			WHILE X1 < 2.0 DO
				IF ABS(X1) <= 0.03125 THEN
					 RETURN Ln(ABS(GamSmall(X1, Z)));
				END;
				Z := Z / X1;
				X1 := X1 + 1.0;
			END;
			IF Z < 0.0 THEN	Z := - Z END;
			IF X1 = 2.0 THEN RETURN Ln(Z)
			ELSE
				X1 := X1 - 2.0;
				RETURN X1 * PolEvl(X1, LnGammaP, 6) / P1Evl(X1, LnGammaQ, 7) + Ln(Z);
			END
		ELSE RETURN StirfL(X)
		END
	END LnGamma;

	PROCEDURE IGamma*(A, X : Float) : Float;
	VAR
		Ans, Ax, C, R : Float;
	BEGIN
		MathErr := FNOK;

		IF (X <= 0.0) OR (A <= 0.0) THEN	RETURN 0.0 END;

		IF (X > 1.0) & (X > A) THEN RETURN 1.0 - JGamma(A, X) END;

		Ax := A * Ln(X) - X - LnGamma(A);
		IF Ax < MINLOG THEN RETURN DefaultVal(FNUNDERFLOW) END;

		Ax := Exp(Ax);

		(* power series *)
		R := A;
		C := 1.0;
		Ans := 1.0;

		REPEAT
			R := R + 1.0;
			C := C * X / R;
			Ans := Ans + C;
		UNTIL C / Ans <= MACHEP;

		RETURN Ans * Ax / A;
	END IGamma;

	PROCEDURE JGamma*(A, X : Float) : Float;
	VAR
		Ans, C, Yc, Ax, Y, Z, R, T,
		Pk, Pkm1, Pkm2, Qk, Qkm1, Qkm2 : Float;
	BEGIN
		MathErr := FNOK;

		IF (X <= 0.0) OR (A <= 0.0) THEN RETURN 1.0 END;

		IF (X < 1.0) OR (X < A) THEN RETURN 1.0 - IGamma(A, X) END;

		Ax := A * Ln(X) - X - LnGamma(A);

		IF Ax < MINLOG THEN RETURN DefaultVal(FNUNDERFLOW) END;

		Ax := Exp(Ax);

		(* continued fraction *)
		Y := 1.0 - A;
		Z := X + Y + 1.0;
		C := 0.0;
		Pkm2 := 1.0;
		Qkm2 := X;
		Pkm1 := X + 1.0;
		Qkm1 := Z * X;
		Ans := Pkm1 / Qkm1;

		REPEAT
			C := C + 1.0;
			Y := Y + 1.0;
			Z := Z + 2.0;
			Yc := Y * C;
			Pk := Pkm1 * Z - Pkm2 * Yc;
			Qk := Qkm1 * Z - Qkm2 * Yc;
			IF Qk # 0.0 THEN
					R := Pk / Qk;
					T := ABS((Ans - R) / R);
					Ans := R;
			ELSE
				T := 1.0
			END;
			Pkm2 := Pkm1;
			Pkm1 := Pk;
			Qkm2 := Qkm1;
			Qkm1 := Qk;
			IF ABS(Pk) > BIG THEN
					Pkm2 := Pkm2 / BIG;
					Pkm1 := Pkm1 / BIG;
					Qkm2 := Qkm2 / BIG;
					Qkm1 := Qkm1 / BIG;
			END;
		UNTIL T <= MACHEP;

		RETURN Ans * Ax;
	END JGamma;

	PROCEDURE Fact*(N : SIGNED32) : Float;
	BEGIN
		MathErr := FNOK;
		IF N < 0 THEN RETURN DefaultVal(FNDOMAIN)
		ELSIF N > MAXFAC THEN RETURN DefaultVal(FNOVERFLOW)
		ELSIF N <= NFACT THEN RETURN FactArray[N]
		ELSE RETURN Gamma(N + 1)
		END;
	END Fact;

	PROCEDURE Binomial*(N, K : SIGNED32) : Float;
	VAR
		I, N1 : SIGNED32;
		Prod : Float;
	BEGIN
		MathErr := FNOK;
		IF K < 0 THEN RETURN 0.0
		ELSIF (K = 0) OR (K = N) THEN RETURN 1.0
		ELSIF (K = 1) OR (K = N - 1) THEN RETURN N
		ELSE
				IF K > N - K THEN K := N - K END;
				N1 := N+1;
				Prod := N;
				FOR I := 2 TO K DO
					Prod := Prod * ((N1 - I) / I);
				END;
				RETURN ENTIER(0.5 + Prod);
		END;
	END	Binomial;

	PROCEDURE Beta*(X, Y : Float) : Float;
	(* Computes Beta(X, Y) = Gamma(X) * Gamma(Y) / Gamma(X + Y) *)
	VAR
		Lx, Ly, Lxy : Float;
		SgnBeta : SIGNED32;
	BEGIN
		MathErr := FNOK;
		SgnBeta := SgnGamma(X) * SgnGamma(Y) * SgnGamma(X + Y);
		Lxy := LnGamma(X + Y);
		IF MathErr # FNOK THEN RETURN 0.0 END;
		Lx := LnGamma(X);
		IF MathErr # FNOK THEN RETURN SgnBeta * MAXNUM END;
		Ly := LnGamma(Y);
		IF MathErr # FNOK THEN RETURN SgnBeta * MAXNUM END;
		RETURN SgnBeta * Exp(Lx + Ly - Lxy);
	END	Beta;

	PROCEDURE PSeries*(A, B, X : Float) : Float;
	(* Power series for incomplete beta integral. Use when B*X is small *)
	VAR
		S, T, U, V, T1, Z, Ai : Float;
		N : SIGNED32;
	BEGIN
		Ai := 1.0 / A;
		U := (1.0 - B) * X;
		V := U / (A + 1.0);
		T1 := V;
		T := U;
		N := 2;
		S := 0.0;
		Z := MACHEP * Ai;
		WHILE ABS(V) > Z DO
				U := (N - B) * X / N;
				T := T * U;
				V := T / (A + N);
				S := S + V;
				N := N + 1;
		END;
		S := S + T1;
		S := S + Ai;

		U := A * Ln(X);
		IF (A + B < MAXGAM) & (ABS(U) < MAXLOG) THEN
				T := Gamma(A + B) / (Gamma(A) * Gamma(B));
				RETURN S * T * Power(X, A);
		ELSE
				T := LnGamma(A + B) - LnGamma(A) - LnGamma(B)
						 + U + Ln(S);
				IF T < MINLOG THEN
					RETURN 0.0
				ELSE
					RETURN Exp(T);
				END;
		END;
	END	PSeries;

PROCEDURE CFrac1*(A, B, X : Float) : Float;
	(* Continued fraction expansion #1 for incomplete beta integral *)
	VAR
		Xk, Pk, Pkm1, Pkm2, Qk, Qkm1, Qkm2,
		K1, K2, K3, K4, K5, K6, K7, K8,
		R, T, Ans, Thresh : Float;
		N : SIGNED32;
		CDone:BOOLEAN;
	BEGIN
	CDone:=FALSE;
		K1 := A;
		K2 := A + B;
		K3 := A;
		K4 := A + 1.0;
		K5 := 1.0;
		K6 := B - 1.0;
		K7 := K4;
		K8 := A + 2.0;

		Pkm2 := 0.0;
		Qkm2 := 1.0;
		Pkm1 := 1.0;
		Qkm1 := 1.0;
		Ans := 1.0;
		R := 1.0;
		N := 0;
		Thresh := 3.0 * MACHEP;

		REPEAT
			Xk := - (X * K1 * K2) / (K3 * K4);
			Pk := Pkm1 + Pkm2 * Xk;
			Qk := Qkm1 + Qkm2 * Xk;
			Pkm2 := Pkm1;
			Pkm1 := Pk;
			Qkm2 := Qkm1;
			Qkm1 := Qk;

			Xk := (X * K5 * K6) / (K7 * K8);
			Pk := Pkm1 + Pkm2 * Xk;
			Qk := Qkm1 + Qkm2 * Xk;
			Pkm2 := Pkm1;
			Pkm1 := Pk;
			Qkm2 := Qkm1;
			Qkm1 := Qk;

			IF Qk # 0.0 THEN R := Pk / Qk END;

			IF R # 0.0 THEN
					T := ABS((Ans - R) / R);
					Ans := R;
			ELSE T := 1.0;
			END;

			IF T < Thresh THEN CDone :=TRUE
			ELSE
				K1 := K1 + 1.0;
				K2 := K2 + 1.0;
				K3 := K3 + 2.0;
				K4 := K4 + 2.0;
				K5 := K5 + 1.0;
				K6 := K6 - 1.0;
				K7 := K7 + 2.0;
				K8 := K8 + 2.0;

				IF ABS(Qk) + ABS(Pk) > BIG THEN
						Pkm2 := Pkm2 * BIGINV;
						Pkm1 := Pkm1 * BIGINV;
						Qkm2 := Qkm2 * BIGINV;
						Qkm1 := Qkm1 * BIGINV;
				END;

				IF (ABS(Qk) < BIGINV) OR (ABS(Pk) < BIGINV) THEN
						Pkm2 := Pkm2 * BIG;
						Pkm1 := Pkm1 * BIG;
						Qkm2 := Qkm2 * BIG;
						Qkm1 := Qkm1 * BIG;
				END;
				INC(N);
		END;
		UNTIL (N > 400) OR CDone;
		IF ~CDone THEN MathErr := FNPLOSS END;
(*CDone:*)
		RETURN Ans;
	END	CFrac1;

	PROCEDURE CFrac2*(A, B, X : Float) : Float;
	(* Continued fraction expansion #2 for incomplete beta integral *)
	VAR
		Xk, Pk, Pkm1, Pkm2, Qk, Qkm1, Qkm2,
		K1, K2, K3, K4, K5, K6, K7, K8,
		R, T, Z, Ans, Thresh : Float;
		N : SIGNED32;
		CDone:BOOLEAN;
	BEGIN
	CDone:=FALSE;
		K1 := A;
		K2 := B - 1.0;
		K3 := A;
		K4 := A + 1.0;
		K5 := 1.0;
		K6 := A + B;
		K7 := A + 1.0;
		K8 := A + 2.0;

		Pkm2 := 0.0;
		Qkm2 := 1.0;
		Pkm1 := 1.0;
		Qkm1 := 1.0;
		Z := X / (1.0 - X);
		Ans := 1.0;
		R := 1.0;
		N := 0;
		Thresh := 3.0 * MACHEP;

		REPEAT
			Xk := - (Z * K1 * K2) / (K3 * K4);
			Pk := Pkm1 + Pkm2 * Xk;
			Qk := Qkm1 + Qkm2 * Xk;
			Pkm2 := Pkm1;
			Pkm1 := Pk;
			Qkm2 := Qkm1;
			Qkm1 := Qk;

			Xk := (Z * K5 * K6) / (K7 * K8);
			Pk := Pkm1 + Pkm2 * Xk;
			Qk := Qkm1 + Qkm2 * Xk;
			Pkm2 := Pkm1;
			Pkm1 := Pk;
			Qkm2 := Qkm1;
			Qkm1 := Qk;

			IF Qk # 0.0 THEN R := Pk / Qk END;

			IF R # 0.0 THEN
					T := ABS((Ans - R) / R);
					Ans := R;
			ELSE T := 1.0
			END;

			IF T < Thresh THEN CDone:=TRUE
			ELSE
				K1 := K1 + 1.0;
				K2 := K2 - 1.0;
				K3 := K3 + 2.0;
				K4 := K4 + 2.0;
				K5 := K5 + 1.0;
				K6 := K6 + 1.0;
				K7 := K7 + 2.0;
				K8 := K8 + 2.0;

				IF ABS(Qk) + ABS(Pk) > BIG THEN
						Pkm2 := Pkm2 * BIGINV;
						Pkm1 := Pkm1 * BIGINV;
						Qkm2 := Qkm2 * BIGINV;
						Qkm1 := Qkm1 * BIGINV;
				END;

				IF (ABS(Qk) < BIGINV) OR (ABS(Pk) < BIGINV) THEN
						Pkm2 := Pkm2 * BIG;
						Pkm1 := Pkm1 * BIG;
						Qkm2 := Qkm2 * BIG;
						Qkm1 := Qkm1 * BIG;
				END;
				N := N + 1;
			END;
		UNTIL (N > 400) OR CDone;
		IF ~CDone THEN MathErr := FNPLOSS END;

(*CDone:*)
		RETURN Ans;
	END CFrac2;

	PROCEDURE IBeta*(A, B, X : Float) : Float; (*! there is a problem with noninteger A or B ; PSnedecor calls IBeta with half-integers *)
	VAR
		A1, B1, X1, T, W, Xc, Y : Float;
		Flag,Done : BOOLEAN;
	BEGIN
		MathErr := FNOK;

		IF (A <= 0.0) OR (B <= 0.0) OR (X < 0.0) OR (X > 1.0) THEN
				RETURN DefaultVal(FNDOMAIN);
		END;

		IF (X = 0.0) OR (X = 1.0) THEN
				 RETURN X;
		END;

		Flag := FALSE;
		IF (B * X <= 1.0) & (X <= 0.95) THEN
				T := PSeries(A, B, X);
				Done:=TRUE
				(*goto Done;
		END;*)
		ELSE

		W := 1.0 - X;

		(* Reverse a AND b IF x is greater than the mean. *)
		IF X > A / (A + B) THEN
				Flag := TRUE;
				A1 := B;
				B1 := A;
				Xc := X;
				X1 := W;
		ELSE
				A1 := A;
				B1 := B;
				Xc := W;
				X1 := X;
		END;

		IF Flag & (B1 * X1 <= 1.0) & (X1 <= 0.95) THEN
				 T := PSeries(A1, B1, X1);
				Done:=TRUE
				(*goto Done;
		END;
		IF ~Done THEN*)
		ELSE
			(* Choose expansion for optimal convergence *)
			Y := X1 * (A1 + B1 - 2.0) - (A1 - 1.0);
			IF Y < 0.0 THEN W := CFrac1(A1, B1, X1)
			ELSE W := CFrac2(A1, B1, X1) / Xc
			END;

			(* Multiply w by the factor
			 a			b	 _						 _		 _
			x	(1-x)	 | (a+b) / ( a | (a) | (b) )		*)

			Y := A1 * Ln(X1);
			T := B1 * Ln(Xc);
			IF (A1 + B1 < MAXGAM) & (ABS(Y) < MAXLOG) & (ABS(T) < MAXLOG) THEN
					T := Power(Xc, B1) ;
					T := T * Power(X1, A1);
					T := T / A1;
					T := T * W;
					T := T * Gamma(A1 + B1) / (Gamma(A1) * Gamma(B1));
			ELSE
					(* Resort to logarithms *)
					Y := Y + T + LnGamma(A1 + B1) - LnGamma(A1) - LnGamma(B1)
								 + Ln(W / A1);
					IF Y < MINLOG THEN T := 0.0
					ELSE T := Exp(Y);
					END;
			END;
	END;

	END;
(*Done:*)
		IF Flag THEN
			IF T <= MACHEP THEN T := 1.0 - MACHEP
			ELSE T := 1.0 - T;
		END;
	END;
		RETURN T;
	END IBeta;

	PROCEDURE Erf*(X : Float) : Float;
	BEGIN
		IF X < 0.0 THEN RETURN - IGamma(0.5, Sqr(X))
		ELSE RETURN IGamma(0.5, Sqr(X))
		END;
	END Erf;

	PROCEDURE Erfc*(X : Float) : Float;
	BEGIN
		IF X < 0.0 THEN RETURN 1.0 + IGamma(0.5, Sqr(X))
		ELSE RETURN JGamma(0.5, Sqr(X))
		END;
	END Erfc;

(* ----------------------------------------------------------------------
	Probability functions
	---------------------------------------------------------------------- *)

	PROCEDURE PBinom*(N : SIGNED32; P : Float; K : SIGNED32) : Float;
	BEGIN
		MathErr := FNOK;
		IF (P < 0.0) OR (P > 1.0) OR (N <= 0) OR (N < K) THEN RETURN DefaultVal(FNDOMAIN)
		ELSIF K = 0 THEN RETURN IntPower(1.0 - P, N)
		ELSIF K = N THEN RETURN IntPower(P, N)
		ELSE RETURN Binomial(N, K) * IntPower(P, K) * IntPower(1.0 - P, N - K)
		END;
	END PBinom;

	PROCEDURE FBinom*(N : SIGNED32; P : Float; K : SIGNED32) : Float;
	BEGIN
		MathErr := FNOK;
		IF (P < 0.0) OR (P > 1.0) OR (N <= 0) OR (N < K) THEN RETURN DefaultVal(FNDOMAIN)
		ELSIF K = 0 THEN RETURN IntPower(1.0 - P, N)
		ELSIF K = N THEN RETURN 1.0
		ELSE RETURN 1.0 - IBeta(K + 1, N - K, P)
		END;
	END FBinom;

	PROCEDURE PPoisson*(Mu : Float; K : SIGNED32) : Float;
	VAR
		P : Float;
		I : SIGNED32;
	BEGIN
		MathErr := FNOK;
		IF (Mu <= 0.0) OR (K < 0) THEN RETURN DefaultVal(FNDOMAIN)
		ELSIF K = 0 THEN RETURN Expo(- Mu)
		ELSE
				P := Mu;
				FOR I := 2 TO K DO P := P * Mu / I END;
				RETURN Expo(- Mu) * P;
		END;
	END PPoisson;

	PROCEDURE FPoisson*(Mu : Float; K : SIGNED32) : Float;
	BEGIN
		MathErr := FNOK;
		IF (Mu <= 0.0) OR (K < 0) THEN RETURN DefaultVal(FNDOMAIN)
		ELSIF K = 0 THEN RETURN Expo(- Mu)
		ELSE RETURN JGamma(K + 1, Mu)
		END;
	END FPoisson;

	PROCEDURE DNorm*(X : Float) : Float;
	BEGIN
		RETURN INVSQRT2PI * Expo(- 0.5 * Sqr(X));
	END DNorm;

	PROCEDURE FNorm*(X : Float) : Float;
	BEGIN
		RETURN 0.5 * (1.0 + Erf(X * SQRT2DIV2));
	END FNorm;

	PROCEDURE InvNorm*(P : Float) : Float;
(* ----------------------------------------------------------------------
	Inverse of Normal distribution function
	Returns the argument, X, for which the area under the Gaussian
	probability density function (integrated from minus infinity TO X)
	is equal TO P.

	Translated from Cephes library.
	---------------------------------------------------------------------- *)
	VAR
		X, Y, Z, Y2, X0, X1 : Float;
		Code : SIGNED32;
	BEGIN
		IF (P <= 0.0) OR (P >= 1.0) THEN RETURN DefaultVal(FNDOMAIN) END;

		Code := 1;
		Y := P;
		IF Y > (1.0 - 0.13533528323661269189) THEN
			 (* 0.135... = exp(-2) *)
				Y := 1.0 - Y;
				Code := 0;
		END;
		IF Y > 0.13533528323661269189 THEN
				Y := Y - 0.5;
				Y2 := Y * Y;
				X := Y + Y * (Y2 * PolEvl(Y2, InvNormP0, 7) / P1Evl(Y2, InvNormQ0, 7));
				X := X * SQRT2PI;
				RETURN X;
		END;

		X := Sqrt(- 2.0 * Ln(Y));
		X0 := X - Ln(X) / X;
		Z := 1.0 / X;
		IF X < 8.0 THEN X1 := Z * PolEvl(Z, InvNormP1, 9) / P1Evl(Z, InvNormQ1, 9)
		ELSIF X < 32.0 THEN X1 := Z * PolEvl(Z, InvNormP2, 7) / P1Evl(Z, InvNormQ2, 7)
		ELSE X1 := Z * PolEvl(Z, InvNormP3, 7) / P1Evl(Z, InvNormQ3, 7)
		END;
		X := X0 - X1;
		IF Code # 0 THEN X := - X END;
		RETURN X;
	END InvNorm;

	PROCEDURE PNorm*(X : Float) : Float;
	VAR
		A : Float;
	BEGIN
		A := ABS(X);
		MathErr := FNOK;
		IF A = 0.0 THEN RETURN 1.0
		ELSIF A < 1.0 THEN	RETURN 1.0 - Erf(A * SQRT2DIV2)
		ELSE RETURN Erfc(A * SQRT2DIV2)
		END;
	END PNorm;

	PROCEDURE DStudent*(Nu : SIGNED32; X : Float) : Float;
	VAR
		L, P, Q : Float;
	BEGIN
		MathErr := FNOK;
		IF Nu < 1 THEN RETURN DefaultVal(FNDOMAIN)
		ELSE
				P := 0.5 * (Nu + 1);
			Q := 0.5 * Nu;
			L := LnGamma(P) - LnGamma(Q)
						 - 0.5 * Ln(Nu * PI)
						 - P * Ln(1.0 + Sqr(X) / Nu);
			RETURN Expo(L);
		END;
	END DStudent;

	PROCEDURE FStudent*(Nu : SIGNED32; X : Float) : Float;
	BEGIN
		MathErr := FNOK;
		IF Nu < 1 THEN RETURN DefaultVal(FNDOMAIN)
		ELSE RETURN 1.0 - IBeta(0.5 * Nu, 0.5, Nu / (Nu + Sqr(X)))
		END;
	END FStudent;

	PROCEDURE PStudent*(Nu : SIGNED32; X : Float) : Float;
	BEGIN
		MathErr := FNOK;
		IF Nu < 1 THEN RETURN DefaultVal(FNDOMAIN)
		ELSE RETURN IBeta(0.5 * Nu, 0.5, Nu / (Nu + Sqr(X)))
		END;
	END PStudent;



	PROCEDURE DKhi2*(Nu : SIGNED32; X : Float) : Float;
	BEGIN
		MathErr := FNOK;
		RETURN DGamma(0.5 * Nu, 0.5, X);
	END DKhi2;

	PROCEDURE FKhi2*(Nu : SIGNED32; X : Float) : Float;
	BEGIN
		MathErr := FNOK;
		IF (Nu < 1) OR (X <= 0.0) THEN RETURN DefaultVal(FNDOMAIN)
		ELSE RETURN IGamma(0.5 * Nu, 0.5 * X)
		END;
	END FKhi2;

	PROCEDURE PKhi2*(Nu : SIGNED32; X : Float) : Float;
	BEGIN
		MathErr := FNOK;
		IF (Nu < 1) OR (X <= 0.0) THEN RETURN DefaultVal(FNDOMAIN)
		ELSE RETURN JGamma(0.5 * Nu, 0.5 * X)
		END;
	END PKhi2;

	PROCEDURE DSnedecor*(Nu1, Nu2 : SIGNED32; X : Float) : Float;
	VAR
		P1, P2, R, S, L : Float;
	BEGIN
		MathErr := FNOK;
		IF (Nu1 < 1) OR (Nu2 < 1) OR (X <= 0.0) THEN RETURN DefaultVal(FNDOMAIN)
		ELSE
				R := Nu1 / Nu2;
				P1 := 0.5 * Nu1;
				P2 := 0.5 * Nu2;
				S := P1 + P2;
				L := LnGamma(S) - LnGamma(P1) - LnGamma(P2)
						 + P1 * Ln(R);
				L := L + (P1 - 1.0) * Ln(X)
							 - S * Ln(1.0 + R * X);
				RETURN Expo(L);
		END;
	END DSnedecor;

	PROCEDURE FSnedecor*(Nu1, Nu2 : SIGNED32; X : Float) : Float;
	BEGIN
		MathErr := FNOK;
		IF (Nu1 < 1) OR (Nu2 < 1) OR (X <= 0.0) THEN RETURN DefaultVal(FNDOMAIN)
		ELSE RETURN 1.0 - IBeta(0.5 * Nu2, 0.5 * Nu1, Nu2 / (Nu2 + Nu1 * X))
		END;
	END FSnedecor;

	PROCEDURE PSnedecor*(Nu1, Nu2 : SIZE; X : Float) : Float;
	BEGIN
		MathErr := FNOK;
		IF (Nu1 < 1) OR (Nu2 < 1) OR (X <= 0.0) THEN RETURN DefaultVal(FNDOMAIN)
		ELSE RETURN IBeta(0.5 * Nu2, 0.5 * Nu1, Nu2 / (Nu2 + Nu1 * X))
		END;
	END PSnedecor;

	PROCEDURE DExpo*(A, X : Float) : Float;
	BEGIN
		IF (A <= 0.0) OR (X < 0.0) THEN RETURN DefaultVal(FNDOMAIN)
		ELSE RETURN A * Expo(- A * X)
		END;
	END DExpo;

	PROCEDURE FExpo*(A, X : Float) : Float;
	BEGIN
		IF (A <= 0.0) OR (X < 0.0) THEN RETURN DefaultVal(FNDOMAIN)
		ELSE RETURN 1.0 - Expo(- A * X)
		END;
	END FExpo;

	PROCEDURE DBeta*(A, B, X : Float) : Float;
	VAR
		L : Float;
	BEGIN
		MathErr := FNOK;
		IF (A <= 0.0) OR (B <= 0.0) OR (X < 0.0) OR (X > 1.0) THEN RETURN DefaultVal(FNDOMAIN)
		ELSIF X = 0.0 THEN
			IF A < 1.0 THEN RETURN DefaultVal(FNSING) ELSE RETURN 0.0 END;
		ELSIF X = 1.0 THEN
			IF B < 1.0 THEN RETURN DefaultVal(FNSING) ELSE RETURN 0.0 END;
		ELSE
				L := LnGamma(A + B) - LnGamma(A) - LnGamma(B);
				L := L + (A - 1.0) * Ln(X)
							 + (B - 1.0) * Ln(1.0 - X);
				RETURN Expo(L);
		END;
	END DBeta;

	PROCEDURE FBeta*(A, B, X : Float) : Float;
	BEGIN
		RETURN IBeta(A, B, X);
	END FBeta;

	PROCEDURE DGamma*(A, B, X : Float) : Float;
	VAR
		L : Float;
	BEGIN
		MathErr := FNOK;
		IF (A <= 0.0) OR (B <= 0.0) OR (X < 0.0) THEN RETURN DefaultVal(FNDOMAIN)
		ELSIF X = 0.0 THEN
			IF A < 1.0 THEN RETURN DefaultVal(FNSING)
			ELSIF A = 1.0 THEN RETURN B
			ELSE RETURN 0.0
			END;
		ELSE
				L := A * Ln(B) - LnGamma(A)
						 + (A - 1.0) * Ln(X) - B * X;
				RETURN Expo(L);
		END;
	END DGamma;

	PROCEDURE FGamma*(A, B, X : Float) : Float;
	BEGIN
		RETURN IGamma(A, B * X);
	END FGamma;

(* ----------------------------------------------------------------------
	Initialization code
	---------------------------------------------------------------------- *)

PROCEDURE Assign10(VAR T:TabCoef; x0,x1,x2,x3,x4,x5,x6,x7,x8,x9:Float);
BEGIN
	T[0]:=x0;
	T[1]:=x1;
	T[2]:=x2;
	T[3]:=x3;
	T[4]:=x4;
	T[5]:=x5;
	T[6]:=x6;
	T[7]:=x7;
	T[8]:=x8;
	T[9]:=x9;
END Assign10;

BEGIN
	(* Initialize MathErr *)
	MathErr := FNOK;
	(* Initialize Coefficients *)
	Assign10 (StirfSTIR,
				7.147391378143610789273E-4,
			- 2.363848809501759061727E-5,
			- 5.950237554056330156018E-4,
				6.989332260623193171870E-5,
				7.840334842744753003862E-4,
			- 2.294719747873185405699E-4,
			- 2.681327161876304418288E-3,
				3.472222222230075327854E-3,
				8.333333333333331800504E-2,
				0);
	Assign10(GamSmallS,
			- 1.193945051381510095614E-3,
				7.220599478036909672331E-3,
			- 9.622023360406271645744E-3,
			- 4.219773360705915470089E-2,
				1.665386113720805206758E-1,
			- 4.200263503403344054473E-2,
			- 6.558780715202540684668E-1,
				5.772156649015328608253E-1,
				1.000000000000000000000E0,
				0);
	Assign10(GamSmallSN,
				1.133374167243894382010E-3,
				7.220837261893170325704E-3,
				9.621911155035976733706E-3,
			- 4.219773343731191721664E-2,
			- 1.665386113944413519335E-1,
			- 4.200263503402112910504E-2,
				6.558780715202536547116E-1,
				5.772156649015328608727E-1,
			- 1.000000000000000000000E0,
				0);
	Assign10(StirfLP,
				4.885026142432270781165E-3,
			- 1.880801938119376907179E-3,
				8.412723297322498080632E-4,
			- 5.952345851765688514613E-4,
				7.936507795855070755671E-4,
			- 2.777777777750349603440E-3,
				8.333333333333331447505E-2,
				0, 0, 0);
	Assign10(GammaP,
			4.212760487471622013093E-5,
			4.542931960608009155600E-4,
			4.092666828394035500949E-3,
			2.385363243461108252554E-2,
			1.113062816019361559013E-1,
			3.629515436640239168939E-1,
			8.378004301573126728826E-1,
			1.000000000000000000009E0,
			0, 0);
	Assign10(GammaQ,
			- 1.397148517476170440917E-5,
				2.346584059160635244282E-4,
			- 1.237799246653152231188E-3,
			- 7.955933682494738320586E-4,
				2.773706565840072979165E-2,
			- 4.633887671244534213831E-2,
			- 2.243510905670329164562E-1,
				4.150160950588455434583E-1,
				9.999999999999999999908E-1,
				0);
	Assign10(LnGammaP,
			- 2.163690827643812857640E3,
			- 8.723871522843511459790E4,
			- 1.104326814691464261197E6,
			- 6.111225012005214299996E6,
			- 1.625568062543700591014E7,
			- 2.003937418103815175475E7,
			- 8.875666783650703802159E6,
				0, 0, 0);
	Assign10(LnGammaQ,
			- 2.163690827643812857640E3,
			- 8.723871522843511459790E4,
			- 1.104326814691464261197E6,
			- 6.111225012005214299996E6,
			- 1.625568062543700591014E7,
			- 2.003937418103815175475E7,
			- 8.875666783650703802159E6,
				0, 0, 0);
	Assign10(InvNormP0,
				8.779679420055069160496E-3,
			- 7.649544967784380691785E-1,
				2.971493676711545292135E0,
			- 4.144980036933753828858E0,
				2.765359913000830285937E0,
			- 9.570456817794268907847E-1,
				1.659219375097958322098E-1,
			- 1.140013969885358273307E-2,
				0, 0);
	Assign10(InvNormQ0,
			- 5.303846964603721860329E0,
				9.908875375256718220854E0,
			- 9.031318655459381388888E0,
				4.496118508523213950686E0,
			- 1.250016921424819972516E0,
				1.823840725000038842075E-1,
			- 1.088633151006419263153E-2,
				0, 0, 0);
	Assign10(InvNormP1,
			4.302849750435552180717E0,
			4.360209451837096682600E1,
			9.454613328844768318162E1,
			9.336735653151873871756E1,
			5.305046472191852391737E1,
			1.775851836288460008093E1,
			3.640308340137013109859E0,
			3.691354900171224122390E-1,
			1.403530274998072987187E-2,
			1.377145111380960566197E-4);
Assign10(InvNormQ1,
			2.001425109170530136741E1,
			7.079893963891488254284E1,
			8.033277265194672063478E1,
			5.034715121553662712917E1,
			1.779820137342627204153E1,
			3.845554944954699547539E0,
			3.993627390181238962857E-1,
			1.526870689522191191380E-2,
			1.498700676286675466900E-4,
			0);
	Assign10(InvNormP2,
			3.244525725312906932464E0,
			6.856256488128415760904E0,
			3.765479340423144482796E0,
			1.240893301734538935324E0,
			1.740282292791367834724E-1,
			9.082834200993107441750E-3,
			1.617870121822776093899E-4,
			7.377405643054504178605E-7,
			0, 0);
	Assign10(InvNormQ2,
			6.021509481727510630722E0,
			3.528463857156936773982E0,
			1.289185315656302878699E0,
			1.874290142615703609510E-1,
			9.867655920899636109122E-3,
			1.760452434084258930442E-4,
			8.028288500688538331773E-7,
			0, 0, 0);
			Assign10(InvNormP3,
				2.020331091302772535752E0,
				2.133020661587413053144E0,
				2.114822217898707063183E-1,
			- 6.500909615246067985872E-3,
			- 7.279315200737344309241E-4,
			- 1.275404675610280787619E-5,
			- 6.433966387613344714022E-8,
			- 7.772828380948163386917E-11,
				0, 0);
	Assign10(InvNormQ3,
				2.278210997153449199574E0,
				2.345321838870438196534E-1,
			- 6.916708899719964982855E-3,
			- 7.908542088737858288849E-4,
			- 1.387652389480217178984E-5,
			- 7.001476867559193780666E-8,
			- 8.458494263787680376729E-11,
				0, 0, 0);
	(* Store the factorials of the first NFACT integers in a table *)
	FactArray[0] := 1.0;
	FactArray[1] := 1.0;
	FactArray[2] := 2.0;
	FOR I := 3 TO NFACT DO
		FactArray[I] := FactArray[I - 1] * I
	END;
END StatisticsFunctions.

SystemTools.FreeDownTo StatisticsFunctions ~

