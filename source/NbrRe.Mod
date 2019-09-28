(* CAPO - Computational Analysis Platform for Oberon - by Alan Freed and Felix Friedrich. *)
(* Version 1, Update 2 *)

MODULE NbrRe;   (** AUTHOR "adf"; PURPOSE "Defines a base Real type for scientific computing."; *)

(* To change to 64-bit reals, change all code that is in light red. *)

IMPORT Streams, NbrInt, NbrInt8, NbrInt16, NbrInt32, NbrInt64, NbrRat, NbrRe32;

(** This module hides the type size of the real implemented.  This makes it a straightforward process for
	the user to change this one module, and in doing so, change the type size for all reals without having
	to change any modules that import NbrRe, at least in principle.  That was one of our design goals. *)

CONST
	E* = NbrRe32.E;  Pi* = NbrRe32.Pi;

TYPE
	Real* = NbrRe32.Real;

VAR
	MinNbr-, MaxNbr-,
	(** Machine epsilon, i.e., e. *)
	Epsilon-: Real;
	(** Machine radix, or base number. *)
	Radix-: NbrInt.Integer;

	(** Type Conversions *)
	PROCEDURE RatToRe( n: NbrRat.Rational ): Real;
	VAR den, frac, int, num: NbrInt64.Integer;  denomR, intR, fracR, r: Real;
	BEGIN
		num := NbrRat.Numer( n );  den := NbrRat.Denom( n );  denomR := den;
		IF num > 0 THEN int := num DIV den;  intR := int;  frac := num MOD den;  fracR := frac;  r := intR + fracR / denomR
		ELSIF num < 0 THEN int := -(num DIV den);  intR := int;  frac := -(num MOD den);  fracR := frac;  r := -intR - fracR / denomR
		ELSE r := 0
		END;
		RETURN r
	END RatToRe;

	OPERATOR ":="*( VAR l: Real;  r: NbrRat.Rational );
	BEGIN
		l := RatToRe( r )
	END ":=";

	PROCEDURE ReToRat*( x: Real ): NbrRat.Rational;
	(* Algorithm from:  Spanier and Oldham, An Atlas of Functions,
			Hemisphere Publishing Corp., Washington DC, 1987, pg. 666. *)
	VAR rat: NbrRat.Rational;  dd, denom, nn, num, r: NbrInt64.Integer;  sign: NbrInt32.Integer;
		abs, error, errorLast, ratio, tol, y: Real;

		PROCEDURE Swap( VAR a, b: NbrInt64.Integer );
		VAR temp: NbrInt64.Integer;
		BEGIN
			temp := a;  a := b;  b := temp
		END Swap;

	BEGIN
		y := 1 / (Epsilon * Epsilon);  tol := 1;  error := MaxNbr;
		WHILE y > 10 DO y := y / 10;  tol := tol / 10 END;
		IF x < 0 THEN abs := -x;  sign := -1
		ELSIF x = 0 THEN rat := 0;  RETURN rat
		ELSE abs := x;  sign := 1
		END;
		num := NbrRe32.LEntier( abs );  denom := 1;
		IF Frac( abs ) = 0 THEN num := sign * num;  NbrRat.Set( num, denom, rat );  RETURN rat END;
		nn := num + 1;  dd := denom;  ratio := (nn - abs * dd) / (abs * denom - num);
		IF ratio < 1 THEN Swap( num, nn );  Swap( denom, dd ) END;
		REPEAT
			IF ratio < 1 THEN ratio := 1 / ratio END;
			r := NbrRe32.LEntier( ratio );  nn := nn + num * r;  dd := dd + denom * r;  num := num + nn;  denom := denom + dd;
			ratio := (nn - abs * dd) / (abs * denom - num);
			IF ratio < 1 THEN Swap( num, nn );  Swap( denom, dd ) END;
			errorLast := error;  error := Abs( 1 - num / (abs * denom) )
		UNTIL (error < tol) OR (errorLast < error);
		num := sign * num;  NbrRat.Set( num, denom, rat );  RETURN rat
	END ReToRat;

(** Comparison Operators *)
	OPERATOR "="*( l: Real;  r: NbrRat.Rational ): BOOLEAN;
	BEGIN
		RETURN l = RatToRe( r )
	END "=";

	OPERATOR "="*( l: NbrRat.Rational;  r: Real ): BOOLEAN;
	BEGIN
		RETURN RatToRe( l ) = r
	END "=";

	OPERATOR "#"*( l: Real;  r: NbrRat.Rational ): BOOLEAN;
	BEGIN
		RETURN l # RatToRe( r )
	END "#";

	OPERATOR "#"*( l: NbrRat.Rational;  r: Real ): BOOLEAN;
	BEGIN
		RETURN RatToRe( l ) # r
	END "#";

	OPERATOR "<"*( l: Real;  r: NbrRat.Rational ): BOOLEAN;
	BEGIN
		RETURN l < RatToRe( r )
	END "<";

	OPERATOR "<"*( l: NbrRat.Rational;  r: Real ): BOOLEAN;
	BEGIN
		RETURN RatToRe( l ) < r
	END "<";

	OPERATOR ">"*( l: Real;  r: NbrRat.Rational ): BOOLEAN;
	BEGIN
		RETURN l > RatToRe( r )
	END ">";

	OPERATOR ">"*( l: NbrRat.Rational;  r: Real ): BOOLEAN;
	BEGIN
		RETURN RatToRe( l ) > r
	END ">";

	OPERATOR "<="*( l: Real;  r: NbrRat.Rational ): BOOLEAN;
	BEGIN
		RETURN l <= RatToRe( r )
	END "<=";

	OPERATOR "<="*( l: NbrRat.Rational;  r: Real ): BOOLEAN;
	BEGIN
		RETURN RatToRe( l ) <= r
	END "<=";

	OPERATOR ">="*( l: Real;  r: NbrRat.Rational ): BOOLEAN;
	BEGIN
		RETURN l >= RatToRe( r )
	END ">=";

	OPERATOR ">="*( l: NbrRat.Rational;  r: Real ): BOOLEAN;
	BEGIN
		RETURN RatToRe( l ) >= r
	END ">=";

(** Arithmetic *)
	OPERATOR "+"*( l: Real;  r: NbrRat.Rational ): Real;
	BEGIN
		RETURN l + RatToRe( r )
	END "+";

	OPERATOR "+"*( l: NbrRat.Rational;  r: Real ): Real;
	BEGIN
		RETURN RatToRe( l ) + r
	END "+";

	OPERATOR "-"*( l: Real;  r: NbrRat.Rational ): Real;
	BEGIN
		RETURN l - RatToRe( r )
	END "-";

	OPERATOR "-"*( l: NbrRat.Rational;  r: Real ): Real;
	BEGIN
		RETURN RatToRe( l ) - r
	END "-";

	OPERATOR "*"*( l: Real;  r: NbrRat.Rational ): Real;
	BEGIN
		RETURN l * RatToRe( r )
	END "*";

	OPERATOR "*"*( l: NbrRat.Rational;  r: Real ): Real;
	BEGIN
		RETURN RatToRe( l ) * r
	END "*";

	OPERATOR "/"*( l: Real;  r: NbrRat.Rational ): Real;
	BEGIN
		RETURN l / RatToRe( r )
	END "/";

	OPERATOR "/"*( l: NbrRat.Rational;  r: Real ): Real;
	BEGIN
		RETURN RatToRe( l ) / r
	END "/";

(** Basic Functions*)
	PROCEDURE Abs*( x: Real ): Real;
	BEGIN
		RETURN NbrRe32.Abs( x )
	END Abs;

	PROCEDURE Entier*( x: Real ): NbrInt.Integer;
	BEGIN
		RETURN NbrRe32.Entier( x )
	END Entier;

	PROCEDURE Max*( x1, x2: Real ): Real;
	BEGIN
		RETURN NbrRe32.Max( x1, x2 )
	END Max;

	PROCEDURE Min*( x1, x2: Real ): Real;
	BEGIN
		RETURN NbrRe32.Min( x1, x2 )
	END Min;

	PROCEDURE Sign*( x: Real ): NbrInt.Integer;
	VAR sInt: NbrInt8.Integer;  lInt: NbrInt32.Integer;
	BEGIN
		sInt := NbrRe32.Sign( x );  lInt := NbrInt32.Long( NbrInt16.Long( sInt ) );  RETURN lInt
	END Sign;

	PROCEDURE Int*( x: Real ): NbrInt.Integer;
	BEGIN
		RETURN NbrRe32.Int( x )
	END Int;

	PROCEDURE Frac*( x: Real ): Real;
	BEGIN
		RETURN NbrRe32.Frac( x )
	END Frac;

	PROCEDURE Round*( x: Real ): NbrInt.Integer;
	BEGIN
		RETURN NbrRe32.Round( x )
	END Round;

	PROCEDURE Floor*( x: Real ): NbrInt.Integer;
	BEGIN
		RETURN NbrRe32.Floor( x )
	END Floor;

	PROCEDURE Ceiling*( x: Real ): NbrInt.Integer;
	BEGIN
		RETURN NbrRe32.Ceiling( x )
	END Ceiling;

(** Functions based on:  real = mantissa * (radix ^ exponent) *)
	PROCEDURE Mantissa*( x: Real ): Real;
	BEGIN
		RETURN NbrRe32.Mantissa( x )
	END Mantissa;

	PROCEDURE Exponent*( x: Real ): NbrInt.Integer;
	VAR exp: NbrInt16.Integer;
	BEGIN
		exp := NbrRe32.Exponent( x );  RETURN NbrInt32.Long( exp )
	END Exponent;

	PROCEDURE Re*( mantissa: Real;  exponent: NbrInt.Integer ): Real;
	VAR exp: NbrInt16.Integer;
	BEGIN
		exp := NbrInt32.Short( exponent );  RETURN NbrRe32.Re( mantissa, exp )
	END Re;

(** The basic Math functions. *)

	PROCEDURE Sqrt*( x: Real ): Real;
	BEGIN
		RETURN NbrRe32.Sqrt( x )
	END Sqrt;

	PROCEDURE Sin*( x: Real ): Real;
	BEGIN
		RETURN NbrRe32.Sin( x )
	END Sin;

	PROCEDURE Cos*( x: Real ): Real;
	BEGIN
		RETURN NbrRe32.Cos( x )
	END Cos;

	PROCEDURE ArcTan*( x: Real ): Real;
	BEGIN
		RETURN NbrRe32.ArcTan( x )
	END ArcTan;

	PROCEDURE Exp*( x: Real ): Real;
	BEGIN
		RETURN NbrRe32.Exp( x )
	END Exp;

	PROCEDURE Ln*( x: Real ): Real;
	BEGIN
		RETURN NbrRe32.Ln( x )
	END Ln;

(** String conversions. LEN(string) >= significantFigures + 6 *)
	PROCEDURE StringToRe*( string: ARRAY OF CHAR;  VAR x: Real );
	BEGIN
		NbrRe32.StringToRe( string, x )
	END StringToRe;

	PROCEDURE ReToString*( x: Real;  significantFigures: NbrInt.Integer;  VAR string: ARRAY OF CHAR );
	VAR sigFig: NbrInt8.Integer;
	BEGIN
		sigFig := NbrInt16.Short( NbrInt32.Short( significantFigures ) );  NbrRe32.ReToString( x, sigFig, string )
	END ReToString;

(** Persistence: file IO *)
	PROCEDURE Load*( R: Streams.Reader;  VAR x: Real );
	BEGIN
		NbrRe32.Load( R, x )
	END Load;

	PROCEDURE Store*( W: Streams.Writer;  x: Real );
	BEGIN
		NbrRe32.Store( W, x )
	END Store;

BEGIN
	MinNbr := NbrRe32.MinNbr;  MaxNbr := NbrRe32.MaxNbr;  Epsilon := NbrRe32.Epsilon;
	Radix := NbrInt32.Long( NbrInt16.Long( NbrRe32.Radix ) )
END NbrRe.