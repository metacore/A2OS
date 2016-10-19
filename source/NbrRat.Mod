(* CAPO - Computational Analysis Platform for Oberon - by Alan Freed and Felix Friedrich. *)
(* Version 1, Update 2 *)

MODULE NbrRat;   (** AUTHOR "adf"; PURPOSE "Defines a base fixed-point Rational type for scientific computing. "; *)

IMPORT Streams, NbrInt, NbrInt64;

TYPE
	Rational* = RECORD
		n, d: NbrInt64.Integer
	END;

VAR
	MinNbr-, MaxNbr-: Rational;

	(* Local Procedures for Rational Numbers. *)
	PROCEDURE CommonDenominator( num, denom: NbrInt64.Integer;  VAR cd: NbrInt64.Integer );
	(* Algorithm from:  P. Henrici, "A Subroutine for Computations with
			Rational Numbers," J. ACM, Vol. 3, No. 1, 1956, pp. 6-9. *)
	VAR absNum, absDenom, prev, current, next: NbrInt64.Integer;
	BEGIN
		IF (num > NbrInt64.MinNbr) & (num # 0) THEN
			absNum := NbrInt64.Abs( num );  absDenom := NbrInt64.Abs( denom );
			IF absNum > absDenom THEN current := absNum;  next := absDenom ELSE current := absDenom;  next := absNum END;
			REPEAT  (* The Euclidean algorithm. *)
				prev := current;  current := next;  next := prev MOD current
			UNTIL next = 0;
			cd := current
		ELSE cd := 1
		END
	END CommonDenominator;

	PROCEDURE Simplify( VAR x: Rational );
	VAR cd, n, d: NbrInt64.Integer;
	BEGIN
		n := x.n;  d := x.d;
		IF n # 0 THEN
			IF (d < 0) & (d > NbrInt64.MinNbr) & (n > NbrInt64.MinNbr) THEN n := -n;  d := -d END;
			CommonDenominator( n, d, cd );
			IF cd = 1 THEN x.n := n;  x.d := d ELSE x.n := n DIV cd;  x.d := d DIV cd END
		ELSE x.n := 0;  x.d := 1
		END
	END Simplify;

(** Monadic Operator *)
	OPERATOR "-"*( x: Rational ): Rational;
	VAR n: Rational;
	BEGIN
		n.n := -x.n;  n.d := x.d;  RETURN n
	END "-";

	(** Dyadic Operators *)
(** Type Conversion *)
	OPERATOR ":="*( VAR l: Rational;  r: NbrInt.Integer );
	BEGIN
		l.n := r;  l.d := 1
	END ":=";

(** Comparison Operators *)
	OPERATOR "="*( l, r: Rational ): BOOLEAN;
	BEGIN
		RETURN (l.n = r.n) & (l.d = r.d)
	END "=";

	OPERATOR "="*( l: Rational;  r: NbrInt.Integer ): BOOLEAN;
	BEGIN
		RETURN (l.n = r) & (l.d = 1)
	END "=";

	OPERATOR "="*( l: NbrInt.Integer;  r: Rational ): BOOLEAN;
	BEGIN
		RETURN (l = r.n) & (r.d = 1)
	END "=";

	OPERATOR "#"*( l, r: Rational ): BOOLEAN;
	BEGIN
		RETURN (l.n # r.n) OR (l.d # r.d)
	END "#";

	OPERATOR "#"*( l: Rational;  r: NbrInt.Integer ): BOOLEAN;
	BEGIN
		RETURN (l.n # r) OR (l.d # 1)
	END "#";

	OPERATOR "#"*( l: NbrInt.Integer;  r: Rational ): BOOLEAN;
	BEGIN
		RETURN (l # r.n) OR (r.d # 1)
	END "#";

	OPERATOR "<"*( l, r: Rational ): BOOLEAN;
	VAR a, b: NbrInt64.Integer;
	BEGIN
		a := l.n DIV l.d;  b := r.n DIV r.d;
		IF a < b THEN RETURN TRUE
		ELSIF a > b THEN RETURN FALSE
		ELSE
			IF (l.n MOD l.d) < (r.n MOD r.d) THEN RETURN TRUE ELSE RETURN FALSE END
		END
	END "<";

	OPERATOR "<"*( l: Rational;  r: NbrInt.Integer ): BOOLEAN;
	BEGIN
		IF (l.n DIV l.d) < r THEN RETURN TRUE ELSE RETURN FALSE END
	END "<";

	OPERATOR "<"*( l: NbrInt.Integer;  r: Rational ): BOOLEAN;
	VAR b: NbrInt64.Integer;
	BEGIN
		b := r.n DIV r.d;
		IF l < b THEN RETURN TRUE
		ELSIF l > b THEN RETURN FALSE
		ELSE
			IF (r.n MOD r.d > 0) & (r.n > 0) THEN RETURN TRUE ELSE RETURN FALSE END
		END
	END "<";

	OPERATOR ">"*( l, r: Rational ): BOOLEAN;
	VAR a, b: NbrInt64.Integer;
	BEGIN
		a := l.n DIV l.d;  b := r.n DIV r.d;
		IF a > b THEN RETURN TRUE
		ELSIF a < b THEN RETURN FALSE
		ELSE
			IF (l.n MOD l.d) > (r.n MOD r.d) THEN RETURN TRUE ELSE RETURN FALSE END
		END
	END ">";

	OPERATOR ">"*( l: Rational;  r: NbrInt.Integer ): BOOLEAN;
	VAR a: NbrInt64.Integer;
	BEGIN
		a := l.n DIV l.d;
		IF a > r THEN RETURN TRUE
		ELSIF a < r THEN RETURN FALSE
		ELSE
			IF (l.n MOD l.d) > 0 THEN RETURN TRUE ELSE RETURN FALSE END
		END
	END ">";

	OPERATOR ">"*( l: NbrInt.Integer;  r: Rational ): BOOLEAN;
	BEGIN
		IF l > (r.n DIV r.d) THEN RETURN TRUE ELSE RETURN FALSE END
	END ">";

	OPERATOR "<="*( l, r: Rational ): BOOLEAN;
	BEGIN
		RETURN ~(l > r)
	END "<=";

	OPERATOR "<="*( l: Rational;  r: NbrInt.Integer ): BOOLEAN;
	BEGIN
		RETURN ~(l > r)
	END "<=";

	OPERATOR "<="*( l: NbrInt.Integer;  r: Rational ): BOOLEAN;
	BEGIN
		RETURN ~(l > r)
	END "<=";

	OPERATOR ">="*( l, r: Rational ): BOOLEAN;
	BEGIN
		RETURN ~(l < r)
	END ">=";

	OPERATOR ">="*( l: Rational;  r: NbrInt.Integer ): BOOLEAN;
	BEGIN
		RETURN ~(l < r)
	END ">=";

	OPERATOR ">="*( l: NbrInt.Integer;  r: Rational ): BOOLEAN;
	BEGIN
		RETURN ~(l < r)
	END ">=";

(** Arithmetic *)
	OPERATOR "+"*( l, r: Rational ): Rational;
	VAR cd, ld, rd: NbrInt64.Integer;  sum: Rational;
	BEGIN
		CommonDenominator( l.d, r.d, cd );  ld := l.d DIV cd;  rd := r.d DIV cd;  sum.n := l.n * rd + r.n * ld;  sum.d := l.d * rd;
		Simplify( sum );  RETURN sum
	END "+";

	OPERATOR "+"*( l: Rational;  r: NbrInt.Integer ): Rational;
	VAR sum: Rational;
	BEGIN
		sum.n := l.n + r * l.d;  sum.d := l.d;  Simplify( sum );  RETURN sum
	END "+";

	OPERATOR "+"*( l: NbrInt.Integer;  r: Rational ): Rational;
	VAR sum: Rational;
	BEGIN
		sum.n := l * r.d + r.n;  sum.d := r.d;  Simplify( sum );  RETURN sum
	END "+";

	OPERATOR "-"*( l, r: Rational ): Rational;
	VAR cd, ld, rd: NbrInt64.Integer;  diff: Rational;
	BEGIN
		CommonDenominator( l.d, r.d, cd );  ld := l.d DIV cd;  rd := r.d DIV cd;  diff.n := l.n * rd - r.n * ld;  diff.d := l.d * rd;
		Simplify( diff );  RETURN diff
	END "-";

	OPERATOR "-"*( l: Rational;  r: NbrInt.Integer ): Rational;
	VAR diff: Rational;
	BEGIN
		diff.n := l.n - r * l.d;  diff.d := l.d;  Simplify( diff );  RETURN diff
	END "-";

	OPERATOR "-"*( l: NbrInt.Integer;  r: Rational ): Rational;
	VAR diff: Rational;
	BEGIN
		diff.n := l * r.d - r.n;  diff.d := r.d;  Simplify( diff );  RETURN diff
	END "-";

	OPERATOR "*"*( l, r: Rational ): Rational;
	VAR cd, ld, ln, rd, rn: NbrInt64.Integer;  prod: Rational;
	BEGIN
		CommonDenominator( l.n, r.d, cd );  ln := l.n DIV cd;  ld := r.d DIV cd;  CommonDenominator( r.n, l.d, cd );
		rn := r.n DIV cd;  rd := l.d DIV cd;  prod.n := ln * rn;  prod.d := ld * rd;  Simplify( prod );  RETURN prod
	END "*";

	OPERATOR "*"*( l: Rational;  r: NbrInt.Integer ): Rational;
	VAR cd, int: NbrInt64.Integer;  prod: Rational;
	BEGIN
		int := r;  CommonDenominator( l.d, int, cd );  prod.n := l.n * (int DIV cd);  prod.d := l.d DIV cd;  Simplify( prod );
		RETURN prod
	END "*";

	OPERATOR "*"*( l: NbrInt.Integer;  r: Rational ): Rational;
	VAR cd, int: NbrInt64.Integer;  prod: Rational;
	BEGIN
		int := l;  CommonDenominator( int, r.d, cd );  prod.n := (int DIV cd) * r.n;  prod.d := r.d DIV cd;  Simplify( prod );
		RETURN prod
	END "*";

	OPERATOR "/"*( l, r: Rational ): Rational;
	VAR cd, ld, ln, rd, rn: NbrInt64.Integer;  div: Rational;
	BEGIN
		CommonDenominator( l.n, r.n, cd );  ln := l.n DIV cd;  ld := r.n DIV cd;  CommonDenominator( r.d, l.d, cd );
		rn := r.d DIV cd;  rd := l.d DIV cd;  div.n := ln * rn;  div.d := ld * rd;  Simplify( div );  RETURN div
	END "/";

	OPERATOR "/"*( l: Rational;  r: NbrInt.Integer ): Rational;
	VAR cd, int: NbrInt64.Integer;  div: Rational;
	BEGIN
		int := r;  CommonDenominator( l.n, int, cd );  div.n := l.n DIV cd;  div.d := l.d * (int DIV cd);  Simplify( div );  RETURN div
	END "/";

	OPERATOR "/"*( l: NbrInt.Integer;  r: Rational ): Rational;
	VAR cd, int: NbrInt64.Integer;  div: Rational;
	BEGIN
		int := l;  CommonDenominator( int, r.n, cd );  div.n := (int DIV cd) * r.d;  div.d := r.n DIV cd;  Simplify( div );  RETURN div
	END "/";

(** Additional Functions and Procedures *)
	PROCEDURE Abs*( x: Rational ): Rational;
	VAR abs: Rational;
	BEGIN
		abs.n := NbrInt64.Abs( x.n );  abs.d := x.d;  RETURN abs
	END Abs;

	PROCEDURE Frac*( x: Rational ): Rational;
	VAR frac: Rational;
	BEGIN
		frac.n := x.n MOD x.d;  frac.d := x.d;  RETURN frac
	END Frac;

	PROCEDURE Max*( x1, x2: Rational ): Rational;
	BEGIN
		IF x1 > x2 THEN RETURN x1 ELSE RETURN x2 END
	END Max;

	PROCEDURE Min*( x1, x2: Rational ): Rational;
	BEGIN
		IF x1 < x2 THEN RETURN x1 ELSE RETURN x2 END
	END Min;

	PROCEDURE Sign*( x: Rational ): NbrInt.Integer;
	VAR sign: NbrInt.Integer;
	BEGIN
		IF x.n < 0 THEN sign := -1
		ELSIF x.n = 0 THEN sign := 0
		ELSE sign := 1
		END;
		RETURN sign
	END Sign;

	(** String conversions. *)
(** Admissible characters include: {" ", "-", "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "/", ","}. LEN(string) >= 53 *)
	PROCEDURE StringToRat*( string: ARRAY OF CHAR;  VAR x: Rational );
	VAR i, j: NbrInt.Integer;
		numerString, denomString: ARRAY 32 OF CHAR;
	BEGIN
		i := 0;
		(* Read in the numerator string. *)
		WHILE (string[i] # 0X) & (string[i] # "/") DO numerString[i] := string[i];  NbrInt.Inc( i ) END;
		numerString[i] := 0X;
		IF string[i] = "/" THEN
			(* A division sign is present. Read in the denominator string. *)
			j := 0;
			REPEAT NbrInt.Inc( i );  denomString[j] := string[i];  NbrInt.Inc( j ) UNTIL string[i] = 0X
		ELSE
			(* Read in an integer that is to be treated as a rational. *)
			COPY( "1", denomString )
		END;
		NbrInt64.StringToInt( numerString, x.n );  NbrInt64.StringToInt( denomString, x.d );  Simplify( x )
	END StringToRat;

	PROCEDURE RatToString*( x: Rational;  VAR string: ARRAY OF CHAR );
	VAR i, k: NbrInt.Integer;
		numerString, denomString: ARRAY 32 OF CHAR;
	BEGIN
		NbrInt64.IntToString( x.n, numerString );  NbrInt64.IntToString( x.d, denomString );  i := 0;
		REPEAT string[i] := numerString[i];  NbrInt.Inc( i ) UNTIL numerString[i] = 0X;
		k := 0;  string[i] := "/";  NbrInt.Inc( i );
		REPEAT string[i] := denomString[k];  NbrInt.Inc( i );  NbrInt.Inc( k ) UNTIL denomString[k] = 0X;
		string[i] := 0X
	END RatToString;

(** Persistence: file IO *)
	PROCEDURE Load*( R: Streams.Reader;  VAR x: Rational );
	BEGIN
		NbrInt64.Load( R, x.n );  NbrInt64.Load( R, x.d )
	END Load;

	PROCEDURE Store*( W: Streams.Writer;  x: Rational );
	BEGIN
		NbrInt64.Store( W, x.n );  NbrInt64.Store( W, x.d )
	END Store;

(** The following procedures are useful, but their use exposes the implemented type size, and therefore,
	any module that imports NbrRat and that uses any of these procedures will have to be rewritten if the
	base type size for defining rational numbers is changed. *)
	PROCEDURE Numer*( x: Rational ): NbrInt64.Integer;
	BEGIN
		RETURN x.n
	END Numer;

	PROCEDURE Denom*( x: Rational ): NbrInt64.Integer;
	BEGIN
		RETURN x.d
	END Denom;

	PROCEDURE Int*( x: Rational ): NbrInt64.Integer;
	BEGIN
		RETURN x.n DIV x.d
	END Int;

	PROCEDURE Round*( x: Rational ): NbrInt64.Integer;
	VAR int, twoN: NbrInt64.Integer;  frac: Rational;
	BEGIN
		int := x.n DIV x.d;  frac := Frac( x );  twoN := 2 * frac.n;
		IF twoN > frac.d THEN NbrInt64.Inc( int )
		ELSIF twoN = frac.d THEN
			IF int >= 0 THEN NbrInt64.Inc( int ) END
		ELSE  (* round = int *)
		END;
		RETURN int
	END Round;

	PROCEDURE Floor*( x: Rational ): NbrInt64.Integer;
	BEGIN
		RETURN Int( x )
	END Floor;

	PROCEDURE Ceiling*( x: Rational ): NbrInt64.Integer;
	VAR int: NbrInt64.Integer;
	BEGIN
		int := Int( x );  NbrInt64.Inc( int );  RETURN int
	END Ceiling;

	PROCEDURE Set*( numerator, denominator: NbrInt64.Integer;  VAR x: Rational );
	BEGIN
		x.n := numerator;  x.d := denominator;  Simplify( x );
	END Set;

BEGIN
	MinNbr.n := NbrInt64.MinNbr;  MinNbr.d := NbrInt64.Long( 1 );  MaxNbr.n := NbrInt64.MaxNbr;
	MaxNbr.d := NbrInt64.Long( 1 )
END NbrRat.