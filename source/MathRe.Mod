(* CAPO - Computational Analysis Platform for Oberon - by Alan Freed and Felix Friedrich. *)
(* Version 1, Update 2 *)

MODULE MathRe;   (** AUTHOR "adf"; PURPOSE "Real math functions"; *)

IMPORT NbrInt, NbrRe, DataErrors, MathInt, MathRat, MathReSeries;

VAR
	MaxFactorial-, maxIterations: NbrInt.Integer;
	delta, expInfinity, expNegligible, expZero, ln2, ln2Inv, ln10, ln10Inv, sqrtInfinity: NbrRe.Real;

TYPE
	ArcSinA = OBJECT (MathReSeries.Coefficient)

		PROCEDURE Evaluate*;
		VAR i, k, index: NbrInt.Integer;  den, num: NbrRe.Real;
		BEGIN {EXCLUSIVE}
			IF NbrInt.Odd( n ) THEN
				num := 1;  den := 1;  k := n;
				FOR i := k - 2 TO 1 BY -2 DO index := i;  num := num * index;  den := den * (index + 1) END;
				coef := num / (n * den)
			ELSE coef := 0
			END;
			IF n > maxIterations THEN eos := TRUE;  DataErrors.ReWarning( x, "Did not converge -  timed out." ) END
		END Evaluate;

	END ArcSinA;

	ArcSinhA = OBJECT (MathReSeries.Coefficient)

		PROCEDURE Evaluate*;
		VAR index: NbrInt.Integer;
		BEGIN {EXCLUSIVE}
			IF n = 0 THEN coef := 0
			ELSIF n = 1 THEN coef := 1 / x
			ELSE
				IF NbrInt.Odd( n ) THEN index := ((n - 2) * (n - 1)) ELSE index := (n * (n - 1)) END;
				coef := index * x
			END;
			IF n > maxIterations THEN eos := TRUE;  DataErrors.ReWarning( x, "Did not converge -  timed out." ) END
		END Evaluate;

	END ArcSinhA;

	ArcSinhB = OBJECT (MathReSeries.Coefficient)

		PROCEDURE Evaluate*;
		BEGIN {EXCLUSIVE}
			IF n = 0 THEN coef := 0 ELSE coef := (2 * n - 1) END
		END Evaluate;

	END ArcSinhB;

	ArcTanhA = OBJECT (MathReSeries.Coefficient)

		PROCEDURE Evaluate*;
		VAR index: NbrInt.Integer;
		BEGIN {EXCLUSIVE}
			IF n = 0 THEN coef := 0
			ELSIF n = 1 THEN coef := 1 / x
			ELSE index := (-(n - 1) * (n - 1));  coef := index * x
			END;
			IF n > maxIterations THEN eos := TRUE;  DataErrors.ReWarning( x, "Did not converge -  timed out." ) END
		END Evaluate;

	END ArcTanhA;

	ArcTanhB = OBJECT (MathReSeries.Coefficient)

		PROCEDURE Evaluate*;
		BEGIN {EXCLUSIVE}
			IF n = 0 THEN coef := 0 ELSE coef := (2 * n - 1) END
		END Evaluate;

	END ArcTanhB;

	TanA = OBJECT (MathReSeries.Coefficient)

		PROCEDURE Evaluate*;
		BEGIN {EXCLUSIVE}
			IF n = 0 THEN coef := 0
			ELSIF n = 1 THEN coef := 1
			ELSE coef := -x
			END;
			IF n > maxIterations THEN eos := TRUE;  DataErrors.ReWarning( x, "Did not converge -  timed out." ) END
		END Evaluate;

	END TanA;

	TanB = OBJECT (MathReSeries.Coefficient)

		PROCEDURE Evaluate*;
		BEGIN {EXCLUSIVE}
			IF n = 0 THEN coef := 0 ELSE coef := (2 * n - 1) END
		END Evaluate;

	END TanB;

	(**  h n i         G(n+1)
         |     | = ---------- ,  m 3 0
	 	j m k    m!G(n-m+1)
	*)
	PROCEDURE Binomial*( top: NbrRe.Real;  bottom: NbrInt.Integer ): NbrRe.Real;
	(* Formula 6:3:1 of: J. Spanier and K. B. Oldham, An Atlas of Functions, Hemisphere Publishing Corp., Washington DC, 1987. *)
	VAR i: NbrInt.Integer;  coef, prod: NbrRe.Real;
	BEGIN
		IF bottom < 0 THEN DataErrors.IntError( bottom, "Bottom parameter cannot be negative" );  prod := 0
		ELSIF bottom = 0 THEN prod := 1
		ELSE
			i := bottom;  prod := 1;
			REPEAT coef := (top - (bottom - i)) / i;  prod := coef * prod;  NbrInt.Dec( i ) UNTIL i = 0
		END;
		RETURN prod
	END Binomial;

(** Computes  n! = n * (n - 1) * (n - 2) * ... * 1,  MaxFactorial 3 n 3 0. *)
	PROCEDURE Factorial*( n: NbrInt.Integer ): NbrRe.Real;
	VAR x, n2, n4, n6, n8, nR: NbrRe.Real;
	BEGIN
		IF n < 0 THEN DataErrors.IntError( n, "Negative arguments are inadmissible." );  x := 0
		ELSIF n <= MathInt.MaxFactorial THEN x := MathInt.Factorial( n )
		ELSIF n <= MathRat.MaxFactorial THEN x := MathRat.Factorial( n )
		ELSIF n <= MaxFactorial THEN
			(* Use Stirling's approximation. *)
			nR := n;  n2 := nR * nR;  n4 := n2 * n2;  n6 := n2 * n4;  n8 := n4 * n4;
			x := (1 - 1 / (30 * n2) + 1 / (105 * n4) - 1 / (140 * n6) + 1 / (99 * n8)) / (12 * nR);
			x := Exp( x + nR * (Ln( nR ) - 1) );  x := x * Sqrt( 2 * NbrRe.Pi * nR )
		ELSE DataErrors.IntError( n, "Argument is too large - overflow." );  x := 0
		END;
		RETURN x
	END Factorial;

(** Returns a pseudo-random number  r  uniformly distributed over the unit interval, i.e.,  r N (0, 1). *)
	PROCEDURE Random*( ): NbrRe.Real;
	VAR x: NbrRe.Real;
	BEGIN
		x := MathRat.Random();  RETURN x
	END Random;

(** Returns the Heaviside step function:   0 if x < x0,  1/2  if  x = x0,  and  1  if  x > x0. *)
	PROCEDURE Step*( x, x0: NbrRe.Real ): NbrRe.Real;
	VAR step: NbrRe.Real;
	BEGIN
		IF x < x0 THEN step := 0
		ELSIF x = x0 THEN step := 0.5
		ELSE step := 1
		END;
		RETURN step
	END Step;

(** Computes the square root. *)
	PROCEDURE Sqrt*( x: NbrRe.Real ): NbrRe.Real;
	VAR sqrt: NbrRe.Real;
	BEGIN
		IF x < 0 THEN DataErrors.ReError( x, "Argument cannot be negative." );  sqrt := 0
		ELSIF x = 0 THEN sqrt := 0
		ELSE sqrt := NbrRe.Sqrt( x )
		END;
		RETURN sqrt
	END Sqrt;

(** Computes the Pythagorean distance:  V(x2 + y2). *)
	PROCEDURE Pythag*( x, y: NbrRe.Real ): NbrRe.Real;
	VAR absx, absy, dist, ratio: NbrRe.Real;
	BEGIN
		absx := NbrRe.Abs( x );  absy := NbrRe.Abs( y );
		IF absx > absy THEN ratio := absy / absx;  dist := absx * Sqrt( 1 + ratio * ratio )
		ELSIF absy = 0 THEN dist := 0
		ELSE ratio := absx / absy;  dist := absy * Sqrt( 1 + ratio * ratio )
		END;
		RETURN dist
	END Pythag;

(** Computes  xn,  {x,n} 9 {0,0}. *)
	PROCEDURE IntPower*( x: NbrRe.Real;  n: NbrInt.Integer ): NbrRe.Real;
	VAR sign: NbrInt.Integer;  max, power: NbrRe.Real;
	BEGIN
		sign := 1;
		IF n = 0 THEN
			IF x # 0 THEN power := 1 ELSE DataErrors.Error( "Both argument and exponent cannot be zero." );  power := 1
			(* Sending an error message is ok, but if without stopping people in most cases do expect 0^0 =1 *)
			END
		ELSIF x = 0 THEN
			IF n > 0 THEN power := 0
			ELSE DataErrors.IntError( n, "Exponent cannot be negative when argument is zero." );  power := 0;
			END
		ELSE
			IF x < 0 THEN
				x := NbrRe.Abs( x );
				IF NbrInt.Odd( n ) THEN sign := -1 END
			END;
			IF n < 0 THEN x := 1 / x;  n := NbrInt.Abs( n ) END;
			power := 1;
			WHILE n > 0 DO
				WHILE ~NbrInt.Odd( n ) & (n > 0) DO
					max := NbrRe.MaxNbr / x;
					IF x > max THEN x := max;  n := 2;  DataErrors.Error( "Arithmatic overflow." ) END;
					x := x * x;  n := n DIV 2
				END;
				max := NbrRe.MaxNbr / power;
				IF x > max THEN x := max;  n := 1;  DataErrors.Error( "Arithmatic overflow." ) END;
				power := power * x;  NbrInt.Dec( n )
			END
		END;
		RETURN sign * power
	END IntPower;

(** Computes xy,  x 3 0,  {x,y} 9 {0,0} . *)
	PROCEDURE Power*( x: NbrRe.Real;  y: NbrRe.Real ): NbrRe.Real;
	VAR arg, power: NbrRe.Real;
	BEGIN
		IF x < 0 THEN DataErrors.ReError( x, "Argument cannot be negative." );  power := 0
		ELSIF x = 0 THEN
			power := 0;
			IF y <= 0 THEN DataErrors.Error( "Exponent must be positive when argument is zero." ) END
		ELSIF ( x = 1 ) OR ( y = 0 ) THEN power := 1
		ELSE arg := y * Ln( x );  power := Exp( arg )
		END;
		RETURN power
	END Power;

(** Computes ex *)
	PROCEDURE Exp*( x: NbrRe.Real ): NbrRe.Real;
	VAR exp: NbrRe.Real;
	BEGIN
		IF x > expInfinity THEN DataErrors.ReError( x, "Argument is too large." );  exp := NbrRe.MaxNbr
		ELSIF x < expZero THEN exp := 0
		ELSE exp := NbrRe.Exp( x )
		END;
		RETURN exp
	END Exp;

(** Computes 2x *)
	PROCEDURE Exp2*( x: NbrRe.Real ): NbrRe.Real;
	VAR exp, xLn2: NbrRe.Real;
	BEGIN
		xLn2 := x * ln2;
		IF xLn2 > expInfinity THEN DataErrors.ReError( x, "Argument is too large." );  exp := NbrRe.MaxNbr
		ELSIF xLn2 < expZero THEN exp := 0
		ELSE exp := NbrRe.Exp( xLn2 )
		END;
		RETURN exp
	END Exp2;

(** Computes 10x *)
	PROCEDURE Exp10*( x: NbrRe.Real ): NbrRe.Real;
	VAR exp, xLn10: NbrRe.Real;
	BEGIN
		xLn10 := x * ln10;
		IF xLn10 > expInfinity THEN DataErrors.ReError( x, "Argument is too large." );  exp := NbrRe.MaxNbr
		ELSIF xLn10 < expZero THEN exp := 0
		ELSE exp := NbrRe.Exp( xLn10 )
		END;
		RETURN exp
	END Exp10;

(** Computes Loge(x) - the natural log. *)
	PROCEDURE Ln*( x: NbrRe.Real ): NbrRe.Real;
	VAR ln: NbrRe.Real;
	BEGIN
		IF x > 0 THEN ln := NbrRe.Ln( x ) ELSE DataErrors.ReError( x, "Argument must be positive." );  ln := 0 END;
		RETURN ln
	END Ln;

(** Computes Log2(x) - log base 2. *)
	PROCEDURE Log2*( x: NbrRe.Real ): NbrRe.Real;
	VAR ln, log: NbrRe.Real;
	BEGIN
		IF x > 0 THEN ln := NbrRe.Ln( x );  log := ln2Inv * ln
		ELSE DataErrors.ReError( x, "Argument must be positive." );  log := 0
		END;
		RETURN log
	END Log2;

(** Computes Log10(x) - log base 10. *)
	PROCEDURE Log*( x: NbrRe.Real ): NbrRe.Real;
	VAR ln, log: NbrRe.Real;
	BEGIN
		IF x > 0 THEN ln := NbrRe.Ln( x );  log := ln10Inv * ln
		ELSE DataErrors.ReError( x, "Argument must be positive." );  log := 0
		END;
		RETURN log
	END Log;

(** Triganometric Functions *)
	PROCEDURE Sin*( x: NbrRe.Real ): NbrRe.Real;
	BEGIN
		RETURN NbrRe.Sin( x )
	END Sin;

	PROCEDURE Cos*( x: NbrRe.Real ): NbrRe.Real;
	BEGIN
		RETURN NbrRe.Cos( x )
	END Cos;

	PROCEDURE Tan*( x: NbrRe.Real ): NbrRe.Real;
	VAR cos, sin, tan: NbrRe.Real;  a: TanA;  b: TanB;
	BEGIN
		IF NbrRe.Abs( x ) < delta THEN NEW( a );  NEW( b );  tan := MathReSeries.ContinuedFraction( a, b, x )
		ELSE
			cos := Cos( x );  sin := Sin( x );
			IF cos # 0 THEN tan := sin / cos
			ELSE
				DataErrors.ReError( x, "Division by zero, i.e., the cos(x) = 0." );
				IF sin > 0 THEN tan := NbrRe.MaxNbr ELSE tan := NbrRe.MinNbr END
			END
		END;
		RETURN tan
	END Tan;

	PROCEDURE ArcSin*( x: NbrRe.Real ): NbrRe.Real;
	(* Returns the arcus sine of 'x' in the range [-p/2, p/2] where -1 <= x <= 1 *)
	VAR a: ArcSinA;  n, d, abs, arcsin: NbrRe.Real;
	BEGIN
		abs := NbrRe.Abs( x );
		IF abs > 1 THEN DataErrors.ReError( x, "Argument is outside the admissible range:  -1 <= x <= 1." );  arcsin := 0
		ELSIF abs = 1 THEN n := x;  d := 0;  arcsin := ArcTan2( n, d )
		ELSIF abs > delta THEN n := x;  d := Sqrt( 1 - x * x );  arcsin := ArcTan2( n, d )
		ELSE NEW( a );  arcsin := MathReSeries.PowerSeries( a, x )
		END;
		RETURN arcsin
	END ArcSin;

	PROCEDURE ArcCos*( x: NbrRe.Real ): NbrRe.Real;
	(* Returns the arcus cosine of 'x' in the range [0, p] where -1 <= x <= 1 *)
	VAR n, d, abs, arccos: NbrRe.Real;
	BEGIN
		abs := NbrRe.Abs( x );
		IF abs > 1 THEN DataErrors.ReError( x, "Argument is outside the admissible range:  -1 <= x <= 1." );  arccos := 0
		ELSIF abs = 1 THEN n := 0;  d := x;  arccos := ArcTan2( n, d )
		ELSE n := Sqrt( 1 - x * x );  d := x;  arccos := ArcTan2( n, d )
		END;
		RETURN arccos
	END ArcCos;

	PROCEDURE ArcTan*( x: NbrRe.Real ): NbrRe.Real;
	BEGIN
		RETURN NbrRe.ArcTan( x )
	END ArcTan;

	PROCEDURE ArcTan2*( xn, xd: NbrRe.Real ): NbrRe.Real;   (** Quadrant-correct arcus tangent: atan(xn/xd). *)
	VAR atan: NbrRe.Real;
	BEGIN
		IF xd = 0 THEN
			IF xn # 0 THEN atan := NbrRe.Sign( xn ) * NbrRe.Pi / 2
			ELSE DataErrors.Error( "Both arguments cannot be zero." );  atan := 0
			END
		ELSIF xn = 0 THEN atan := (1 - NbrRe.Sign( xd )) * NbrRe.Pi / 2
		ELSE atan := NbrRe.ArcTan( xn / xd ) + NbrRe.Sign( xn ) * (1 - NbrRe.Sign( xd )) * NbrRe.Pi / 2
		END;
		RETURN atan
	END ArcTan2;

(** Hyperbolic Functions *)
	PROCEDURE Sinh*( x: NbrRe.Real ): NbrRe.Real;
	VAR abs, expM1, sinh: NbrRe.Real;
	BEGIN
		abs := NbrRe.Abs( x );
		IF abs < 1 THEN expM1 := Exp( abs ) - 1;  sinh := NbrRe.Sign( x ) * (expM1 + expM1 / (1 + expM1)) / 2
		ELSIF abs < expNegligible THEN sinh := (Exp( x ) - Exp( -x )) / 2
		ELSE sinh := NbrRe.Sign( x ) * Exp( abs ) / 2
		END;
		RETURN sinh
	END Sinh;

	PROCEDURE Cosh*( x: NbrRe.Real ): NbrRe.Real;
	VAR abs, cosh: NbrRe.Real;
	BEGIN
		abs := NbrRe.Abs( x );
		IF abs < expNegligible THEN cosh := (Exp( x ) + Exp( -x )) / 2 ELSE cosh := Exp( abs ) / 2 END;
		RETURN cosh
	END Cosh;

	PROCEDURE Tanh*( x: NbrRe.Real ): NbrRe.Real;
	VAR abs, exp, expM, exp2xM1, tanh: NbrRe.Real;
	BEGIN
		abs := NbrRe.Abs( x );
		IF abs < 1 THEN exp2xM1 := Exp( 2 * abs ) - 1;  tanh := NbrRe.Sign( x ) * exp2xM1 / (2 + exp2xM1)
		ELSIF abs < expNegligible THEN exp := Exp( x );  expM := Exp( -x );  tanh := (exp - expM) / (exp + expM)
		ELSE tanh := NbrRe.Sign( x )
		END;
		RETURN tanh
	END Tanh;

	PROCEDURE ArcSinh*( x: NbrRe.Real ): NbrRe.Real;
	(* ArcSinh(x) is the arcus hyperbolic sine of 'x'. *)
	VAR abs, asinh: NbrRe.Real;  a: ArcSinhA;  b: ArcSinhB;
	BEGIN
		abs := NbrRe.Abs( x );
		IF abs > sqrtInfinity THEN DataErrors.ReError( x, "Argument is too large." );  asinh := 0
		ELSIF x < -delta THEN asinh := -Ln( abs + Sqrt( abs ) * Sqrt( abs + 1 / abs ) )
		ELSIF x < delta THEN
			IF x = 0 THEN asinh := 0
			ELSE NEW( a );  NEW( b );  asinh := x * Sqrt( 1 + x * x ) * MathReSeries.ContinuedFraction( a, b, x )
			END
		ELSE asinh := Ln( x + Sqrt( x ) * Sqrt( x + 1 / x ) )
		END;
		RETURN asinh
	END ArcSinh;

	PROCEDURE ArcCosh*( x: NbrRe.Real ): NbrRe.Real;
	(* ArcCosh(x) is the arcus hyperbolic cosine of 'x'.
			All arguments greater than or equal to 1 are legal. *)
	VAR acosh: NbrRe.Real;
	BEGIN
		IF x < 1 THEN DataErrors.ReError( x, "Argument is out of range, i.e., x >= 1." );  acosh := 0
		ELSIF x = 1 THEN acosh := 0
		ELSIF x < sqrtInfinity THEN acosh := Ln( x + Sqrt( x ) * Sqrt( x - 1 / x ) )
		ELSE DataErrors.ReError( x, "Argument is too large." );  acosh := 0
		END;
		RETURN acosh
	END ArcCosh;

	PROCEDURE ArcTanh*( x: NbrRe.Real ): NbrRe.Real;
	(* ArcTanh(x) is the arcus hyperbolic tangent of 'x'. *)
	VAR abs, atanh: NbrRe.Real;  a: ArcTanhA;  b: ArcTanhB;
	BEGIN
		abs := NbrRe.Abs( x );
		IF abs > 1 THEN DataErrors.ReError( x, "Argument is out of range, i.e., -1 <= x <= 1." );  atanh := 0
		ELSIF abs = 1 THEN atanh := NbrRe.Sign( x ) * expNegligible
		ELSIF abs > delta THEN atanh := Ln( (1 + x) / (1 - x) ) / 2
		ELSIF abs > 0 THEN NEW( a );  NEW( b );  atanh := x * MathReSeries.ContinuedFraction( a, b, x )
		ELSE atanh := 0
		END;
		RETURN atanh
	END ArcTanh;

BEGIN
	IF NbrRe.MaxNbr = MAX( FLOAT32 ) THEN MaxFactorial := 34 ELSE MaxFactorial := 171 END;
	maxIterations := 1000;  expZero := Ln( 1/NbrRe.MaxNbr );  expInfinity := Ln( NbrRe.MaxNbr );
	expNegligible := -Ln( NbrRe.Epsilon ) / 2;  sqrtInfinity := Sqrt( NbrRe.MaxNbr ) / 2;  delta := 0.1;
	ln10 := NbrRe.Ln( 10 );  ln10Inv := 1 / ln10;  ln2 := NbrRe.Ln( 2 );  ln2Inv := 1 / ln2
END MathRe.