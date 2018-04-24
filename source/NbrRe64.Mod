(* CAPO - Computational Analysis Platform for Oberon - by Alan Freed and Felix Friedrich. *)
(* Version 1, Update 2 *)

MODULE NbrRe64;   (** AUTHOR "adf"; PURPOSE "Alias for type LONGREAL."; *)

IMPORT Streams, MathL, NbrInt8, NbrInt16, NbrInt32, NbrInt64, NbrRe32;

CONST
	E* = MathL.e;  Pi* = MathL.pi;

TYPE
	Real* = LONGREAL;

VAR
	MinNbr-, MaxNbr-,
	(** Machine epsilon, i.e., e. *)
	reExp, Epsilon-: Real;  minExp, maxExp: NbrInt16.Integer;
	(** Machine radix, or base number. *)
	Radix-: NbrInt8.Integer;

(** Basic functions *)
	PROCEDURE Abs*( x: Real ): Real;
	BEGIN
		RETURN ABS( x )
	END Abs;

	PROCEDURE Entier*( x: Real ): NbrInt32.Integer;
	BEGIN
		RETURN ENTIER( x )
	END Entier;

	PROCEDURE LEntier*( x: Real ): NbrInt64.Integer;
	BEGIN
		RETURN ENTIERH(x); 
	END LEntier;

	PROCEDURE Long*( x: NbrRe32.Real ): Real;
	BEGIN
		RETURN LONG( x )
	END Long;

	PROCEDURE IsRe32*( x: Real ): BOOLEAN;
	BEGIN
		IF (ABS( x ) <= NbrRe32.MaxNbr) & (x = SHORT( x )) THEN RETURN TRUE ELSE RETURN FALSE END
	END IsRe32;

	PROCEDURE Short*( x: Real ): NbrRe32.Real;
	BEGIN
		RETURN SHORT( x )
	END Short;

	PROCEDURE Max*( x1, x2: Real ): Real;
	BEGIN
		IF x1 > x2 THEN RETURN x1 ELSE RETURN x2 END
	END Max;

	PROCEDURE Min*( x1, x2: Real ): Real;
	BEGIN
		IF x1 < x2 THEN RETURN x1 ELSE RETURN x2 END
	END Min;

	PROCEDURE Sign*( x: Real ): NbrInt8.Integer;
	VAR sign: NbrInt8.Integer;
	BEGIN
		IF x < 0 THEN sign := -1
		ELSIF x = 0 THEN sign := 0
		ELSE sign := 1
		END;
		RETURN sign
	END Sign;

	PROCEDURE Int*( x: Real ): NbrInt32.Integer;
	BEGIN
		RETURN Entier( x )
	END Int;

	PROCEDURE Frac*( x: Real ): Real;
	VAR y: Real;
	BEGIN
		y := x - LEntier( x );  RETURN y
	END Frac;

	PROCEDURE Round*( x: Real ): NbrInt32.Integer;
	VAR int: NbrInt32.Integer;
	BEGIN
		int := Entier( x );
		IF x > (0.5 + int) THEN NbrInt32.Inc( int ) END;
		RETURN int
	END Round;

	PROCEDURE Floor*( x: Real ): NbrInt32.Integer;
	BEGIN
		RETURN Entier( x )
	END Floor;

	PROCEDURE Ceiling*( x: Real ): NbrInt32.Integer;
	VAR int: NbrInt32.Integer;
	BEGIN
		int := Entier( x );
		IF x > int THEN NbrInt32.Inc( int ) END;
		RETURN int
	END Ceiling;

(** Functions based on:  real = mantissa * (radix ^ exponent) *)
	PROCEDURE Mantissa*( x: Real ): Real;
	VAR abs: Real;
	BEGIN
		abs := Abs( x );
		WHILE abs >= Radix DO abs := abs / Radix END;
		WHILE abs < 1 DO abs := Radix * abs END;
		RETURN Sign( x ) * abs
	END Mantissa;

	PROCEDURE Exponent*( x: Real ): NbrInt16.Integer;
	VAR exponent: NbrInt16.Integer;  abs: Real;
	BEGIN
		abs := Abs( x );
		IF abs > 0 THEN
			exponent := 0;
			WHILE abs >= Radix DO abs := abs / Radix;  NbrInt16.Inc( exponent ) END;
			WHILE abs < 1 DO abs := Radix * abs;  NbrInt16.Dec( exponent ) END
		ELSE exponent := 1
		END;
		RETURN exponent
	END Exponent;

	PROCEDURE MantissaExponent( y: Real;  VAR man: Real;  VAR exp: NbrInt16.Integer );
	VAR abs: Real;
	BEGIN
		abs := Abs( y );
		IF abs > 0 THEN
			exp := 0;
			WHILE abs >= Radix DO abs := abs / Radix;  NbrInt16.Inc( exp ) END;
			WHILE abs < 1 DO abs := Radix * abs;  NbrInt16.Dec( exp ) END;
			man := Sign( y ) * abs
		ELSE man := 0;  exp := 1
		END
	END MantissaExponent;

	PROCEDURE Re*( mantissa: Real;  exponent: NbrInt16.Integer ): Real;
	VAR exp, n: NbrInt16.Integer;  coef, power, x: Real;
	BEGIN
		IF mantissa = 0 THEN x := 0;  RETURN x END;
		(* Obtain a corrected mantissa. *)
		MantissaExponent( mantissa, coef, exp );
		(* Compute power = radix ^ (exp + exponent) *)
		n := exp + exponent;
		IF n < 0 THEN x := 1;  x := x / Radix;  n := -n ELSE x := Radix END;
		power := 1;
		WHILE n > 0 DO
			WHILE ~NbrInt16.Odd( n ) DO n := n DIV 2;  x := x * x END;
			NbrInt16.Dec( n );  power := power * x
		END;
		(* Return real = coef * radix ^ (exp + exponent) *)
		RETURN coef * power
	END Re;

(** Provide aliases for the Math functions called in NbrCplx. *)

	PROCEDURE Sqrt*( x: Real ): Real;
	BEGIN
		RETURN MathL.sqrt( x )
	END Sqrt;

	PROCEDURE Sin*( x: Real ): Real;
	BEGIN
		RETURN MathL.sin( x )
	END Sin;

	PROCEDURE Cos*( x: Real ): Real;
	BEGIN
		RETURN MathL.cos( x )
	END Cos;

	PROCEDURE ArcTan*( x: Real ): Real;
	BEGIN
		RETURN MathL.arctan( x )
	END ArcTan;

	PROCEDURE Exp*( x: Real ): Real;
	BEGIN
		RETURN MathL.exp( x )
	END Exp;

	PROCEDURE Ln*( x: Real ): Real;
	BEGIN
		RETURN MathL.ln( x )
	END Ln;


	(** String conversions. *)
(** Admissible characters include: {" ", "-", "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "D", "E", ",", "."}. *)
	PROCEDURE StdForm( VAR y: Real;  VAR exponent: NbrInt16.Integer );
	BEGIN
		(* Requires y >= 0, but doesn't check for this. *)
		IF y > 0 THEN
			exponent := 0;
			WHILE y >= 10 DO y := y / 10;  NbrInt16.Inc( exponent ) END;
			WHILE y < 1 DO y := 10 * y;  NbrInt16.Dec( exponent ) END
		ELSE y := 0;  exponent := 1
		END
	END StdForm;

	PROCEDURE StringToRe*( string: ARRAY OF CHAR;  VAR x: Real );
	VAR i, expSign, sign: NbrInt8.Integer;  coefExp, exp: NbrInt16.Integer;  base, coef, divisor, power: Real;
	BEGIN
		i := 0;
		(* Pass over any leading white space. *)
		WHILE string[i] = CHR( 20H ) DO NbrInt8.Inc( i ) END;
		(* Determine the sign. *)
		IF string[i] = CHR( 2DH ) THEN sign := -1;  NbrInt8.Inc( i ) ELSE sign := 1 END;
		coef := 0;
		(* Read in that part that is to the left of the decimal point. *)
		WHILE ((string[i] # ".") & (string[i] # "D")) & ((string[i] # "E") & (string[i] # 0X)) DO
			IF (CHR( 30H ) <= string[i]) & (string[i] <= CHR( 39H )) THEN coef := 10 * coef + LONG( ORD( string[i] ) - 30H )
			ELSE
				(* Inadmissible character - it is skipped. *)
			END;
			NbrInt8.Inc( i )
		END;
		IF string[i] = "." THEN
			NbrInt8.Inc( i );  divisor := 1;
			(* Read in that part that is to the right of the decimal point. *)
			WHILE (string[i] # "D") & (string[i] # "E") & (string[i] # 0X) DO
				IF (CHR( 30H ) <= string[i]) & (string[i] <= CHR( 39H )) THEN
					divisor := 10 * divisor;  coef := coef + LONG( ORD( string[i] ) - 30H ) / divisor
				ELSE
					(* Inadmissible character - it is skipped. *)
				END;
				NbrInt8.Inc( i )
			END
		END;
		(* Put this coefficient into standard format. *)
		StdForm( coef, coefExp );
		(* Assign the correct sign to the coefficient. *)
		coef := sign * coef;
		(* Read in the exponent. *)
		IF (string[i] = "D") OR (string[i] = "E") THEN NbrInt8.Inc( i );
			(* Pass over any leading white space. *)
			WHILE string[i] = CHR( 20H ) DO NbrInt8.Inc( i ) END;
			(* Determine the sign. *)
			IF string[i] = CHR( 2DH ) THEN expSign := -1;  NbrInt8.Inc( i ) ELSE expSign := 1 END;
			(* Read in the string and convert it to an integer. *)
			exp := 0;
			WHILE string[i] # 0X DO
				IF (CHR( 30H ) <= string[i]) & (string[i] <= CHR( 39H )) THEN exp := 10 * exp + (ORD( string[i] ) - 30H)
				ELSE
					(* Inadmissible character - it is skipped. *)
				END;
				NbrInt8.Inc( i )
			END;
			exp := expSign * exp
		ELSE
			(* There is no E part. *)
			exp := 0
		END;
		exp := coefExp + exp;
		(* Compute the integer power. *)
		IF exp > maxExp THEN x := sign * MaxNbr
		ELSIF exp < minExp THEN x := 0
		ELSE  (* Compute the power to a base of 10. *)
			IF exp > 0 THEN base := 10
			ELSIF exp < 0 THEN base := 0.1;  exp := -exp
			ELSE  (* exp = 0 *)
			END;
			power := 1;
			WHILE exp > 0 DO
				WHILE ~NbrInt16.Odd( exp ) & (exp > 0) DO base := base * base;  exp := exp DIV 2 END;
				power := base * power;  NbrInt16.Dec( exp )
			END;
			x := coef * power
		END
	END StringToRe;

(** LEN(string >= significantFigures + 7 *)
	PROCEDURE ReToString*( x: Real;  significantFigures: NbrInt8.Integer;  VAR string: ARRAY OF CHAR );
	VAR sign: CHAR;  i: NbrInt8.Integer;  exponent: NbrInt16.Integer;  coef, factor: NbrInt64.Integer;  abs: Real;
	BEGIN
		IF significantFigures < 1 THEN significantFigures := 1 END;
		IF significantFigures > 16 THEN significantFigures := 16 END;
		IF x < 0 THEN abs := -x;  string[0] := "-";  ELSE abs := x;  string[0] := CHR( 30H ) END;
		string[1] := ".";  exponent := 0;
		IF abs > 0 THEN
			WHILE abs < 0.1 DO abs := 10 * abs;  NbrInt16.Dec( exponent ) END;
			WHILE abs >= 1.0 DO abs := abs / 10;  NbrInt16.Inc( exponent ) END;
			factor := 1;
			FOR i := 1 TO significantFigures DO factor := 10 * factor END;
			coef := LEntier( factor * abs );  i := 2;
			REPEAT
				factor := factor DIV 10;
				(* The following IF statement is a hack to handle the special case when x = 1.0. *)
				IF (coef DIV factor) > 9 THEN factor := 10 * factor;  NbrInt16.Inc( exponent ) END;
				string[i] := CHR( NbrInt32.Short( NbrInt64.Short( coef DIV factor ) ) + 30H );  coef := coef MOD factor;  NbrInt8.Inc( i )
			UNTIL factor = 1
		ELSE
			FOR i := 2 TO significantFigures + 1 DO string[i] := CHR( 30H ) END
		END;
		IF exponent < 0 THEN sign := "-";  exponent := -exponent ELSE sign := "+" END;
		IF exponent = 0 THEN string[significantFigures + 2] := 0X
		ELSE
			string[significantFigures + 2] := "E";  string[significantFigures + 3] := sign;
			IF (exponent DIV 100) # 0 THEN
				string[significantFigures + 4] := CHR( (exponent DIV 100) + 30H );  exponent := exponent MOD 100;
				string[significantFigures + 5] := CHR( (exponent DIV 10) + 30H );
				string[significantFigures + 6] := CHR( (exponent MOD 10) + 30H );  string[significantFigures + 7] := 0X
			ELSE
				exponent := exponent MOD 100;
				IF (exponent DIV 10) # 0 THEN
					string[significantFigures + 4] := CHR( (exponent DIV 10) + 30H );
					string[significantFigures + 5] := CHR( (exponent MOD 10) + 30H );  string[significantFigures + 6] := 0X
				ELSE string[significantFigures + 4] := CHR( (exponent MOD 10) + 30H );  string[significantFigures + 5] := 0X
				END
			END
		END
	END ReToString;

(** Persistence: file IO *)
	PROCEDURE Load*( R: Streams.Reader;  VAR x: Real );
	VAR char: CHAR;  sInt: NbrInt8.Integer;  int: NbrInt16.Integer;  lInt: NbrInt32.Integer;  hInt: NbrInt64.Integer;
		re: NbrRe32.Real;
	BEGIN
		R.Char( char );
		CASE char OF
		"S":       R.RawSInt( sInt );  x := NbrInt32.Long( NbrInt16.Long( sInt ) )
		| "I":     R.RawInt( int );  x := LONG( int )
		| "L":     R.RawLInt( lInt );  x := lInt
		| "H":     NbrInt64.Load( R, hInt );  x := hInt;
		| "E":     R.RawReal( re );  x := Long( re )
		ELSE  (* char = "D" *)
			R.RawLReal( x )
		END
	END Load;

	PROCEDURE Store*( W: Streams.Writer;  x: Real );
	VAR sInt: NbrInt8.Integer;  int: NbrInt16.Integer;  lInt: NbrInt32.Integer;  hInt: NbrInt64.Integer;  re: NbrRe32.Real;
		y: Real;
	BEGIN
		hInt := LEntier( x );  y := x - hInt;
		IF y = 0 THEN
			IF NbrInt64.IsInt32( hInt ) THEN
				lInt := NbrInt64.Short( hInt );
				IF NbrInt32.IsInt16( lInt ) THEN
					int := NbrInt32.Short( lInt );
					IF NbrInt16.IsInt8( int ) THEN sInt := NbrInt16.Short( int );  W.Char( "S" );  W.RawSInt( sInt )
					ELSE W.Char( "I" );  W.RawInt( int )
					END
				ELSE W.Char( "L" );  W.RawLInt( lInt )
				END
			ELSE W.Char( "H" );  NbrInt64.Store( W, hInt )
			END
		ELSE
			IF IsRe32( x ) THEN re := Short( x );  W.Char( "E" );  W.RawReal( re ) ELSE W.Char( "D" );  W.RawLReal( x ) END
		END
	END Store;

(* A local procedure called when the module is loaded to compute machine epsilon for export. *)
	PROCEDURE EvalEpsilon;
	VAR rounding: BOOLEAN;  i, digits: NbrInt16.Integer;  a, b, c, epsilon, recipRadix: Real;

		PROCEDURE AddProc( x, y: Real ): Real;
		(* Forces  x  and  y  to be put into memory before adding,
			overcoming optimizers that might hold one or the other in a register. *)
		BEGIN
			RETURN x + y
		END AddProc;

		PROCEDURE EvalRadix;
		VAR x, y, z: Real;
		BEGIN
			(* Compute  x = 2 ** m  with smallest  m  such that  x + 1 = x. *)
			x := 1;  z := 1;
			WHILE z = 1 DO x := 2 * x;  z := AddProc( x, 1 );  z := AddProc( z, -x ) END;
			(* Now compute  y = 2 ** m  with smallest  m  such that  x + y > x. *)
			y := 1;  z := AddProc( x, y );
			WHILE z = x DO y := 2 * y;  z := AddProc( x, y ) END;
			(* Reals  x  and  z  are neighboring floating point numbers whose difference is the radix. *)
			y := AddProc( z, -x );
			(* The one-quarter ensures that  y  is truncated to  radix  and not  radix - 1. *)
			Radix := NbrInt16.Short( NbrInt32.Short( Entier( y + 0.25 ) ) )
		END EvalRadix;

		PROCEDURE EvalDigits;
		VAR x, y: Real;
		BEGIN
			(* Seek smallest positive integer for which  radix ** (digits + 1) = 1. *)
			digits := 0;  x := 1;  y := 1;
			WHILE y = 1 DO NbrInt16.Inc( digits );  x := Radix * x;  y := AddProc( x, 1 );  y := AddProc( y, -x ) END
		END EvalDigits;

	BEGIN
		EvalRadix;  EvalDigits;
		(* Compute epsilon. *)
		recipRadix := 1 / Radix;  epsilon := Radix;
		FOR i := 1 TO digits DO epsilon := AddProc( epsilon * recipRadix, 0 ) END;
		(* Determine if rounding or chopping takes place during arithmetic operations. *)
		a := 1;  b := 1;
		(* Find  a = 2 ** m  with smallest  m  such that  a + 1 = a. *)
		WHILE b = 1 DO a := 2 * a;  b := AddProc( a, 1 );  b := AddProc( b, -a ) END;
		(* Add a bit less than  radix / 2  to  a. *)
		b := AddProc( Radix / 2, -Radix / 100 );  c := AddProc( a, b );
		IF a = c THEN rounding := TRUE ELSE rounding := FALSE END;
		(* Add a bit more than  radix / 2  to  a. *)
		b := AddProc( Radix / 2, Radix / 100 );  c := AddProc( a, b );
		IF rounding & (a = c) THEN rounding := FALSE END;
		(* Account for rounding. *)
		IF rounding THEN epsilon := epsilon / 2 END;
		Epsilon := epsilon
	END EvalEpsilon;

BEGIN
	EvalEpsilon;  MaxNbr := MAX( LONGREAL );  MinNbr := MIN( LONGREAL );  reExp := MinNbr;  StdForm( reExp, minExp );  reExp := MaxNbr;
	StdForm( reExp, maxExp )
END NbrRe64.