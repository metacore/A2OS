(* CAPO - Computational Analysis Platform for Oberon - by Alan Freed and Felix Friedrich. *)
(* Version 1, Update 2 *)

MODULE NbrCplx;   (** AUTHOR "adf"; PURPOSE "Defines a base Complex type for scientific computing."; *)

(** Cartesian componets:  z = x + i y  where  x, y N !.
	Polar components:  z = r exp(if)  where  r, f N !; r 3 0.
	Imaginary unit:  i = V-1. *)

IMPORT Streams, NbrInt, NbrRat, NbrRe;

TYPE
	Complex* = RECORD
		re, im: NbrRe.Real
	END;

VAR
	zero, one: NbrRe.Real;
	(**  The imaginary unit:  i = V-1. *)
	I-: Complex;

	(* Local procedure *)
	PROCEDURE Reciprocal( x: Complex ): Complex;
	VAR cplx: Complex;  denom, ratio: NbrRe.Real;
	BEGIN
		IF NbrRe.Abs( x.re ) > NbrRe.Abs( x.im ) THEN
			ratio := x.im / x.re;  denom := x.re + x.im * ratio;  cplx.re := 1 / denom;  cplx.im := -ratio / denom
		ELSE ratio := x.re / x.im;  denom := x.re * ratio + x.im;  cplx.re := ratio / denom;  cplx.im := -1 / denom
		END;
		RETURN cplx
	END Reciprocal;

	(** Monadic Operators *)
(** Negative, i.e., -z = -x - i y *)
	OPERATOR "-"*( x: Complex ): Complex;
	VAR cplx: Complex;
	BEGIN
		cplx.re := -x.re;  cplx.im := -x.im;  RETURN cplx
	END "-";

(** Complex conjugate, i.e., ~z = x - i y  *)
	OPERATOR "~"*( x: Complex ): Complex;
	VAR cplx: Complex;
	BEGIN
		cplx.re := x.re;  cplx.im := -x.im;  RETURN cplx
	END "~";

	(** Dyadic Operators *)
(** Type Conversions *)
	OPERATOR ":="*( VAR l: Complex;  r: NbrInt.Integer );
	BEGIN
		l.re := r;  l.im := 0
	END ":=";

	OPERATOR ":="*( VAR l: Complex;  r: NbrRat.Rational );
	BEGIN
		l.re := r;  l.im := 0
	END ":=";

	OPERATOR ":="*( VAR l: Complex;  r: NbrRe.Real );
	BEGIN
		l.re := r;  l.im := 0
	END ":=";

(** Comparison Operators *)
	OPERATOR "="*( l, r: Complex ): BOOLEAN;
	BEGIN
		RETURN (l.re = r.re) & (l.im = r.im)
	END "=";

	OPERATOR "="*( l: Complex;  r: NbrRe.Real ): BOOLEAN;
	BEGIN
		RETURN (l.re = r) & (l.im = 0)
	END "=";

	OPERATOR "="*( l: Complex;  r: NbrRat.Rational ): BOOLEAN;
	BEGIN
		RETURN (l.re = r) & (l.im = 0)
	END "=";

	OPERATOR "="*( l: Complex;  r: NbrInt.Integer ): BOOLEAN;
	BEGIN
		RETURN (l.re = r) & (l.im = 0)
	END "=";

	OPERATOR "="*( l: NbrRe.Real;  r: Complex ): BOOLEAN;
	BEGIN
		RETURN (l = r.re) & (r.im = 0)
	END "=";

	OPERATOR "="*( l: NbrRat.Rational;  r: Complex ): BOOLEAN;
	BEGIN
		RETURN (l = r.re) & (r.im = 0)
	END "=";

	OPERATOR "="*( l: NbrInt.Integer;  r: Complex ): BOOLEAN;
	BEGIN
		RETURN (l = r.re) & (r.im = 0)
	END "=";

	OPERATOR "#"*( l, r: Complex ): BOOLEAN;
	BEGIN
		RETURN (l.re # r.re) OR (l.im # r.im)
	END "#";

	OPERATOR "#"*( l: Complex;  r: NbrRe.Real ): BOOLEAN;
	BEGIN
		RETURN (l.re # r) OR (l.im # 0)
	END "#";

	OPERATOR "#"*( l: Complex;  r: NbrRat.Rational ): BOOLEAN;
	BEGIN
		RETURN (l.re # r) OR (l.im # 0)
	END "#";

	OPERATOR "#"*( l: Complex;  r: NbrInt.Integer ): BOOLEAN;
	BEGIN
		RETURN (l.re # r) OR (l.im # 0)
	END "#";

	OPERATOR "#"*( l: NbrRe.Real;  r: Complex ): BOOLEAN;
	BEGIN
		RETURN (l # r.re) OR (r.im # 0)
	END "#";

	OPERATOR "#"*( l: NbrRat.Rational;  r: Complex ): BOOLEAN;
	BEGIN
		RETURN (l # r.re) OR (r.im # 0)
	END "#";

	OPERATOR "#"*( l: NbrInt.Integer;  r: Complex ): BOOLEAN;
	BEGIN
		RETURN (l # r.re) OR (r.im # 0)
	END "#";

(** Arithmetic *)
	OPERATOR "+"*( l, r: Complex ): Complex;
	VAR cplx: Complex;
	BEGIN
		cplx.re := l.re + r.re;  cplx.im := l.im + r.im;  RETURN cplx
	END "+";

	OPERATOR "+"*( l: Complex;  r: NbrRe.Real ): Complex;
	VAR cplx: Complex;
	BEGIN
		cplx.re := l.re + r;  cplx.im := l.im;  RETURN cplx
	END "+";

	OPERATOR "+"*( l: Complex;  r: NbrRat.Rational ): Complex;
	VAR cplx: Complex;
	BEGIN
		cplx.re := l.re + r;  cplx.im := l.im;  RETURN cplx
	END "+";

	OPERATOR "+"*( l: Complex;  r: NbrInt.Integer ): Complex;
	VAR cplx: Complex;
	BEGIN
		cplx.re := l.re + r;  cplx.im := l.im;  RETURN cplx
	END "+";

	OPERATOR "+"*( l: NbrRe.Real;  r: Complex ): Complex;
	VAR cplx: Complex;
	BEGIN
		cplx.re := l + r.re;  cplx.im := r.im;  RETURN cplx
	END "+";

	OPERATOR "+"*( l: NbrRat.Rational;  r: Complex ): Complex;
	VAR cplx: Complex;
	BEGIN
		cplx.re := l + r.re;  cplx.im := r.im;  RETURN cplx
	END "+";

	OPERATOR "+"*( l: NbrInt.Integer;  r: Complex ): Complex;
	VAR cplx: Complex;
	BEGIN
		cplx.re := l + r.re;  cplx.im := r.im;  RETURN cplx
	END "+";

	OPERATOR "-"*( l, r: Complex ): Complex;
	VAR cplx: Complex;
	BEGIN
		cplx.re := l.re - r.re;  cplx.im := l.im - r.im;  RETURN cplx
	END "-";

	OPERATOR "-"*( l: Complex;  r: NbrRe.Real ): Complex;
	VAR cplx: Complex;
	BEGIN
		cplx.re := l.re - r;  cplx.im := l.im;  RETURN cplx
	END "-";

	OPERATOR "-"*( l: Complex;  r: NbrRat.Rational ): Complex;
	VAR cplx: Complex;
	BEGIN
		cplx.re := l.re - r;  cplx.im := l.im;  RETURN cplx
	END "-";

	OPERATOR "-"*( l: Complex;  r: NbrInt.Integer ): Complex;
	VAR cplx: Complex;
	BEGIN
		cplx.re := l.re - r;  cplx.im := l.im;  RETURN cplx
	END "-";

	OPERATOR "-"*( l: NbrRe.Real;  r: Complex ): Complex;
	VAR cplx: Complex;
	BEGIN
		cplx.re := l - r.re;  cplx.im := -r.im;  RETURN cplx
	END "-";

	OPERATOR "-"*( l: NbrRat.Rational;  r: Complex ): Complex;
	VAR cplx: Complex;
	BEGIN
		cplx.re := l - r.re;  cplx.im := -r.im;  RETURN cplx
	END "-";

	OPERATOR "-"*( l: NbrInt.Integer;  r: Complex ): Complex;
	VAR cplx: Complex;
	BEGIN
		cplx.re := l - r.re;  cplx.im := -r.im;  RETURN cplx
	END "-";

	OPERATOR "*"*( l, r: Complex ): Complex;
	VAR cplx: Complex;  left, right: NbrRe.Real;
	BEGIN
		left := l.re * r.re;  right := l.im * r.im;  cplx.re := left - right;  left := l.re * r.im;  right := l.im * r.re;
		cplx.im := left + right;  RETURN cplx
	END "*";

	OPERATOR "*"*( l: Complex;  r: NbrRe.Real ): Complex;
	VAR cplx: Complex;
	BEGIN
		cplx.re := l.re * r;  cplx.im := l.im * r;  RETURN cplx
	END "*";

	OPERATOR "*"*( l: Complex;  r: NbrRat.Rational ): Complex;
	VAR cplx: Complex;
	BEGIN
		cplx.re := l.re * r;  cplx.im := l.im * r;  RETURN cplx
	END "*";

	OPERATOR "*"*( l: Complex;  r: NbrInt.Integer ): Complex;
	VAR cplx: Complex;
	BEGIN
		cplx.re := l.re * r;  cplx.im := l.im * r;  RETURN cplx
	END "*";

	OPERATOR "*"*( l: NbrRe.Real;  r: Complex ): Complex;
	VAR cplx: Complex;
	BEGIN
		cplx.re := l * r.re;  cplx.im := l * r.im;  RETURN cplx
	END "*";

	OPERATOR "*"*( l: NbrRat.Rational;  r: Complex ): Complex;
	VAR cplx: Complex;
	BEGIN
		cplx.re := l * r.re;  cplx.im := l * r.im;  RETURN cplx
	END "*";

	OPERATOR "*"*( l: NbrInt.Integer;  r: Complex ): Complex;
	VAR cplx: Complex;
	BEGIN
		cplx.re := l * r.re;  cplx.im := l * r.im;  RETURN cplx
	END "*";

	OPERATOR "/"*( l, r: Complex ): Complex;
	(* Algorithm can be found in Press et al. *)
	VAR cplx: Complex;  denom, ratio: NbrRe.Real;
	BEGIN
		IF NbrRe.Abs( r.re ) > NbrRe.Abs( r.im ) THEN
			ratio := r.im / r.re;  denom := r.re + r.im * ratio;  cplx.re := (l.re + l.im * ratio) / denom;
			cplx.im := (l.im - l.re * ratio) / denom
		ELSE
			ratio := r.re / r.im;  denom := r.re * ratio + r.im;  cplx.re := (l.re * ratio + l.im) / denom;
			cplx.im := (l.im * ratio - l.re) / denom
		END;
		RETURN cplx
	END "/";

	OPERATOR "/"*( l: Complex;  r: NbrRe.Real ): Complex;
	VAR cplx: Complex;
	BEGIN
		cplx := l * (1 / r);  RETURN cplx
	END "/";

	OPERATOR "/"*( l: Complex;  r: NbrRat.Rational ): Complex;
	VAR cplx: Complex;
	BEGIN
		cplx := l * (1 / r);  RETURN cplx
	END "/";

	OPERATOR "/"*( l: Complex;  r: NbrInt.Integer ): Complex;
	VAR re: NbrRe.Real;  cplx: Complex;
	BEGIN
		re := r;  cplx := l * (1 / re);  RETURN cplx
	END "/";

	OPERATOR "/"*( l: NbrRe.Real;  r: Complex ): Complex;
	VAR cplx: Complex;
	BEGIN
		cplx := l * Reciprocal( r );  RETURN cplx
	END "/";

	OPERATOR "/"*( l: NbrRat.Rational;  r: Complex ): Complex;
	VAR cplx: Complex;
	BEGIN
		cplx := l * Reciprocal( r );  RETURN cplx
	END "/";

	OPERATOR "/"*( l: NbrInt.Integer;  r: Complex ): Complex;
	VAR cplx: Complex;
	BEGIN
		cplx := l * Reciprocal( r );  RETURN cplx
	END "/";

	(** Basic functions *)
(** x  in  z = x + i y *)
	PROCEDURE Re*( x: Complex ): NbrRe.Real;
	BEGIN
		RETURN x.re
	END Re;

(** y  in  z = x + i y *)
	PROCEDURE Im*( x: Complex ): NbrRe.Real;
	BEGIN
		RETURN x.im
	END Im;

(** r  in  z = r exp(if) *)
	PROCEDURE Abs*( x: Complex ): NbrRe.Real;
	VAR abs, absRe, absIm, ratio: NbrRe.Real;
	BEGIN
		absRe := NbrRe.Abs( x.re );  absIm := NbrRe.Abs( x.im );
		IF absRe > absIm THEN ratio := absIm / absRe;  abs := absRe * NbrRe.Sqrt( 1 + ratio * ratio )
		ELSIF absIm = 0 THEN abs := 0
		ELSE ratio := absRe / absIm;  abs := absIm * NbrRe.Sqrt( 1 + ratio * ratio )
		END;
		RETURN abs
	END Abs;

(** f  in  z = r exp(if) *)
	PROCEDURE Arg*( x: Complex ): NbrRe.Real;
	VAR arg: NbrRe.Real;

		PROCEDURE ArcTan( xn, xd: NbrRe.Real ): NbrRe.Real;
		VAR sn, sd: NbrInt.Integer;  atan, ratio: NbrRe.Real;
		BEGIN
			IF xn < 0 THEN sn := -1
			ELSIF xn = 0 THEN sn := 0
			ELSE sn := 1
			END;
			IF xd < 0 THEN sd := -1
			ELSIF xd = 0 THEN sd := 0
			ELSE sd := 1
			END;
			IF xd = 0 THEN atan := sn * NbrRe.Pi / 2
			ELSIF xn = 0 THEN atan := (1 - sd) * NbrRe.Pi / 2
			ELSE ratio := xn / xd;  atan := NbrRe.ArcTan( ratio ) + sn * (1 - sd) * NbrRe.Pi / 2
			END;
			RETURN atan
		END ArcTan;

	BEGIN
		IF x = 0 THEN arg := 0 ELSE arg := ArcTan( x.im, x.re ) END;
		RETURN arg
	END Arg;

(** re = x  and  im = y  in  z = x + i y. *)
	PROCEDURE Get*( x: Complex;  VAR re, im: NbrRe.Real );
	BEGIN
		re := x.re;  im := x.im
	END Get;

	PROCEDURE Set*( re, im: NbrRe.Real;  VAR x: Complex );
	BEGIN
		x.re := re;  x.im := im
	END Set;

(** abs = r  and  arg = f  in  z = r exp(if). *)
	PROCEDURE GetPolar*( x: Complex;  VAR abs, arg: NbrRe.Real );
	BEGIN
		abs := Abs( x );  arg := Arg( x )
	END GetPolar;

	PROCEDURE SetPolar*( abs, arg: NbrRe.Real;  VAR x: Complex );
	VAR cos, sin: NbrRe.Real;
	BEGIN
		cos := NbrRe.Cos( arg );  sin := NbrRe.Sin( arg );  x.re := abs * cos;  x.im := abs * sin
	END SetPolar;

	(** String conversions. *)
(** Admissible characters: {" ", "+", "-", "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "E", "i", ",", "."}. *)
	PROCEDURE StringToCplx*( string: ARRAY OF CHAR;  VAR x: Complex );
	VAR negative: BOOLEAN;  i, j: NbrInt.Integer;
		reString, imString: ARRAY 32 OF CHAR;
	BEGIN
		i := 0;
		WHILE (string[i] # 0X) & (string[i] # "i") DO reString[i] := string[i];  NbrInt.Inc( i ) END;
		j := i;
		LOOP
			NbrInt.Dec( j );
			IF j < 1 THEN x.re := 0;  EXIT END;
			(* Pass over any tailing white space and a plus or minus sign. *)
			IF (reString[j] # CHR( 20H )) & ((reString[j] # CHR( 2BH )) OR (reString[j] = CHR( 2DH ))) THEN
				reString[j + 1] := 0X;  NbrRe.StringToRe( reString, x.re );  EXIT
			END
		END;
		IF string[i] = "i" THEN
			j := i;
			LOOP
				NbrInt.Dec( j );
				(* Determine the sign of the imaginary part. *)
				IF j < 1 THEN negative := FALSE;  EXIT END;
				IF string[j] = CHR( 2BH ) THEN negative := FALSE;  EXIT END;
				IF string[j] = CHR( 2DH ) THEN negative := TRUE;  EXIT END
			END;
			NbrInt.Inc( i );  j := 0;
			REPEAT imString[j] := string[i];  NbrInt.Inc( i );  NbrInt.Inc( j ) UNTIL string[i] = 0X;
			NbrRe.StringToRe( imString, x.im );
			IF negative THEN x.im := -x.im END
		ELSE x.im := 0
		END
	END StringToCplx;

(** LEN(string) >= 2*significantFigures+18 *)
	PROCEDURE CplxToString*( x: Complex;  significantFigures: NbrInt.Integer;  VAR string: ARRAY OF CHAR );
	VAR i, j: NbrInt.Integer;
		reString, imString: ARRAY 32 OF CHAR;
	BEGIN
		NbrRe.ReToString( x.re, significantFigures, reString );  i := 0;
		REPEAT string[i] := reString[i];  NbrInt.Inc( i ) UNTIL reString[i] = 0X;
		IF x.im > 0 THEN
			string[i] := CHR( 20H );  NbrInt.Inc( i );  string[i] := "+";  NbrInt.Inc( i );  string[i] := CHR( 20H );  NbrInt.Inc( i );  string[i] := "i";
			NbrInt.Inc( i );  string[i] := CHR( 20H );  NbrInt.Inc( i );  NbrRe.ReToString( x.im, significantFigures, imString );  j := 0;
			REPEAT string[i] := imString[j];  NbrInt.Inc( i );  NbrInt.Inc( j ) UNTIL imString[j] = 0X
		ELSIF x.im = 0 THEN  (* write nothing *)
		ELSE
			string[i] := CHR( 20H );  NbrInt.Inc( i );  string[i] := "-";  NbrInt.Inc( i );  string[i] := CHR( 20H );  NbrInt.Inc( i );  string[i] := "i";
			NbrInt.Inc( i );  string[i] := CHR( 20H );  NbrInt.Inc( i );  NbrRe.ReToString( -x.im, significantFigures, imString );  j := 0;
			REPEAT string[i] := imString[j];  NbrInt.Inc( i );  NbrInt.Inc( j ) UNTIL imString[j] = 0X
		END;
		string[i] := 0X
	END CplxToString;

(** Admissible characters: {" ", "+", "-", "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "E", "exp", "(", ")", "i", ",", "."}. *)
	PROCEDURE PolarStringToCplx*( string: ARRAY OF CHAR;  VAR x: Complex );
	VAR negative: BOOLEAN;  i, j: NbrInt.Integer;  abs, arg: NbrRe.Real;
		absString, argString: ARRAY 32 OF CHAR;
	BEGIN
		i := 0;
		WHILE (string[i] # 0X) & (string[i] # "e") DO absString[i] := string[i];  NbrInt.Inc( i ) END;
		IF i = 0 THEN x.re := 0;  x.im := 0;  RETURN END;
		absString[i] := 0X;  NbrRe.StringToRe( absString, abs );
		IF string[i] = "e" THEN
			REPEAT NbrInt.Inc( i ) UNTIL string[i] = "(";
			NbrInt.Inc( i );
			(* Pass over leading white space. *)
			WHILE string[i] = CHR( 20H ) DO NbrInt.Inc( i ) END;
			(* Determine the sign. *)
			IF string[i] = CHR( 2DH ) THEN negative := TRUE;  NbrInt.Inc( i ) ELSE negative := FALSE END;
			(* Move to the first digit. *)
			WHILE (string[i] < CHR( 30H )) OR (string[i] > CHR( 39H )) DO NbrInt.Inc( i ) END;
			j := 0;
			WHILE string[i] # ")" DO argString[j] := string[i];  NbrInt.Inc( i );  NbrInt.Inc( j ) END;
			argString[j] := 0X;  NbrRe.StringToRe( argString, arg );
			IF negative THEN arg := -arg END
		ELSE arg := 0
		END;
		SetPolar( abs, arg, x )
	END PolarStringToCplx;

(** LEN(string) >= 2*significantFigures+22 *)
	PROCEDURE CplxToPolarString*( x: Complex;  significantFigures: NbrInt.Integer;  VAR string: ARRAY OF CHAR );
	VAR i, j: NbrInt.Integer;  abs, arg: NbrRe.Real;
		absString, argString: ARRAY 32 OF CHAR;
	BEGIN
		GetPolar( x, abs, arg );  NbrRe.ReToString( abs, significantFigures, absString );  i := 0;
		REPEAT string[i] := absString[i];  NbrInt.Inc( i ) UNTIL absString[i] = 0X;
		IF arg > 0 THEN
			string[i] := CHR( 20H );  NbrInt.Inc( i );  string[i] := "e";  NbrInt.Inc( i );  string[i] := "x";  NbrInt.Inc( i );  string[i] := "p";
			NbrInt.Inc( i );  string[i] := "(";  NbrInt.Inc( i );  string[i] := "i";  NbrInt.Inc( i );  string[i] := CHR( 20H );  NbrInt.Inc( i );
			NbrRe.ReToString( arg, significantFigures, argString );  j := 0;
			REPEAT string[i] := argString[j];  NbrInt.Inc( i );  NbrInt.Inc( j ) UNTIL argString[j] = 0X;
			string[i] := ")";  NbrInt.Inc( i )
		ELSIF arg = 0 THEN
			(* write nothing *)
		ELSE
			string[i] := CHR( 20H );  NbrInt.Inc( i );  string[i] := "e";  NbrInt.Inc( i );  string[i] := "x";  NbrInt.Inc( i );  string[i] := "p";
			NbrInt.Inc( i );  string[i] := "(";  NbrInt.Inc( i );  string[i] := "-";  NbrInt.Inc( i );  string[i] := "i";  NbrInt.Inc( i );
			string[i] := CHR( 20H );  NbrInt.Inc( i );  NbrRe.ReToString( -arg, significantFigures, argString );  j := 0;
			REPEAT string[i] := argString[j];  NbrInt.Inc( i );  NbrInt.Inc( j ) UNTIL argString[j] = 0X;
			string[i] := ")";  NbrInt.Inc( i )
		END;
		string[i] := 0X
	END CplxToPolarString;

(** Persistence: file IO *)
	PROCEDURE Load*( R: Streams.Reader;  VAR x: Complex );
	BEGIN
		NbrRe.Load( R, x.re );  NbrRe.Load( R, x.im )
	END Load;

	PROCEDURE Store*( W: Streams.Writer;  x: Complex );
	BEGIN
		NbrRe.Store( W, x.re );  NbrRe.Store( W, x.im )
	END Store;

BEGIN
	zero := 0;  one := 1;  Set( zero, one, I )
END NbrCplx.