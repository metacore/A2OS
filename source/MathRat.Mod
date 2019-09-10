(* CAPO - Computational Analysis Platform for Oberon - by Alan Freed and Felix Friedrich. *)
(* Version 1, Update 2 *)

MODULE MathRat;   (** AUTHOR "adf"; PURPOSE "Rational math functions"; *)

IMPORT NbrInt, NbrInt64, NbrRat, DataErrors, MathInt;

CONST
	max = 2147483647;
	MaxFactorial* = 21;

	(**  h n i       n!
     |   | = ---------,  m 3 0
     j m k    m!(n-m)!
	*)
	PROCEDURE Binomial*( top, bottom: NbrInt.Integer ): NbrRat.Rational;
	(* Formula 6:3:1 of: J. Spanier and K. B. Oldham, An Atlas of Functions, Hemisphere Publishing Corp.,
		Washington DC, 1987. *)
	VAR denom, numer: NbrInt64.Integer;  i: NbrInt.Integer;  coef, prod: NbrRat.Rational;
	BEGIN
		IF bottom < 0 THEN prod := 0;  DataErrors.IntError( bottom, "Bottom parameter cannot be negative." )
		ELSIF bottom = 0 THEN prod := 1
		ELSE
			i := bottom;  prod := 1;
			REPEAT
				denom := NbrInt64.Long( i );  numer := NbrInt64.Long( top - (bottom - i) );
				NbrRat.Set( numer, denom, coef );  prod := coef * prod;
				NbrInt.Dec( i )
			UNTIL i = 0
		END;
		RETURN prod
	END Binomial;

(** Computes  n! = n * (n - 1) * (n - 2) * ... * 1,  MaxFactorial 3 n 3 0. *)
	PROCEDURE Factorial*( n: NbrInt.Integer ): NbrRat.Rational;
	VAR i: NbrInt.Integer;  x: NbrRat.Rational;
	BEGIN
		IF n < 0 THEN x := 0;  DataErrors.IntError( n, "Negative arguments are inadmissible." )
		ELSIF n = 0 THEN x := 1
		ELSIF n <= MaxFactorial THEN
			x := 1;  i := 0;
			REPEAT NbrInt.Inc( i );  x := i * x UNTIL i = n
		ELSE
			NbrRat.Set( NbrInt64.MaxNbr, NbrInt64.Long( 1 ), x );  DataErrors.IntError( n, "Arithmatic overflow." )
		END;
		RETURN x
	END Factorial;

(** Computes  xn,  {x,n} 9 {0,0}. *)
	PROCEDURE Power*( x: NbrRat.Rational;  n: NbrInt.Integer ): NbrRat.Rational;
	VAR sign: NbrInt.Integer;  denom, dPower, numer, nPower: NbrInt64.Integer;  power: NbrRat.Rational;

		PROCEDURE IntPower( a: NbrInt64.Integer;  b: NbrInt.Integer ): NbrInt64.Integer;
		 (* Computes  ab,  a > 0,  b 3 0. *)
		VAR max, p: NbrInt64.Integer;
		BEGIN
			p := 1;
			WHILE b > 0 DO
				WHILE ~NbrInt.Odd( b ) & (b > 0) DO
					max := NbrInt64.MaxNbr DIV a;
					IF a > max THEN a := max;  b := 2;  DataErrors.Error( "Arithmatic overflow." ) END;
					a := a * a;  b := b DIV 2
				END;
				max := NbrInt64.MaxNbr DIV p;
				IF a > max THEN a := max;  b := 1;  DataErrors.Error( "Arithmatic overflow." ) END;
				p := p * a;  NbrInt.Dec( b )
			END;
			RETURN p
		END IntPower;

	BEGIN
		sign := 1;
		IF n = 0 THEN
			IF x # 0 THEN power := 1
			ELSE power := 0;  DataErrors.Error( "Both argument and exponent cannot be zero." )
			END
		ELSIF x = 0 THEN
			power := 0;
			IF n < 0 THEN DataErrors.IntError( n, "Exponent cannot be negative when argument is zero." ) END
		ELSE
			numer := NbrRat.Numer( x );  denom := NbrRat.Denom( x );
			IF numer < 0 THEN
				numer := NbrInt64.Abs( numer );
				IF NbrInt.Odd( n ) THEN sign := -1 END
			END;
			IF n < 0 THEN nPower := IntPower( denom, -n );  dPower := IntPower( numer, -n )
			ELSE nPower := IntPower( numer, n );  dPower := IntPower( denom, n )
			END;
			NbrRat.Set( nPower, dPower, power )
		END;
		RETURN sign * power
	END Power;

(** Returns a pseudo-random rational number uniformly distributed over the unit interval, i.e.,  Random() N (0, 1). *)
	PROCEDURE Random*( ): NbrRat.Rational;
	VAR n, d: NbrInt64.Integer;  r: NbrRat.Rational;
	BEGIN
		n := NbrInt64.Long( MathInt.Random() );  d := NbrInt64.Long( MAX( SIGNED32 ) );
		NbrRat.Set( n, d, r );  RETURN r
	END Random;

END MathRat.