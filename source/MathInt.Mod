(* CAPO - Computational Analysis Platform for Oberon - by Alan Freed and Felix Friedrich. *)
(* Version 1, Update 2 *)

MODULE MathInt;   (** AUTHOR "adf"; PURPOSE "Integer math functions"; *)

IMPORT Modules, Files, AosRandom := Random, NbrInt, DataErrors;

CONST
	MaxFactorial* = 12; (* Assumes NbrInt.Integer = SIGNED32 *)
VAR
	rng: AosRandom.Sequence;  nbr: SIGNED32;

	(** Computes  n! = n * (n - 1) * (n - 2) * ... * 1,  MaxFactorial 3 n 3 0. *)
	PROCEDURE Factorial*( n: NbrInt.Integer ): NbrInt.Integer;
	VAR i, x: NbrInt.Integer;
	BEGIN
		IF n < 0 THEN x := 0;  DataErrors.IntError( n, "Negative arguments are inadmissible." )
		ELSIF n = 0 THEN x := 1
		ELSIF n <= MaxFactorial THEN
			x := 1;  i := 0;
			REPEAT NbrInt.Inc( i );  x := i * x UNTIL i = n
		ELSE x := MAX( NbrInt.Integer );  DataErrors.IntError( n, "Arithmatic overflow." )
		END;
		RETURN x
	END Factorial;

(** Computes  xn,  n 3 0,  {x,n} 9 {0,0}.  *)
	PROCEDURE Power*( x, n: NbrInt.Integer ): NbrInt.Integer;
	VAR max, power, sign: NbrInt.Integer;
	BEGIN
		sign := 1;
		IF n < 0 THEN power := 0;  DataErrors.IntError( n, "Exponent cannot be negative." )
		ELSIF n = 0 THEN
			IF x # 0 THEN power := 1
			ELSE power := 0;  DataErrors.Error( "Both argument and exponent cannot be zero." )
			END
		ELSIF x = 0 THEN power := 0
		ELSE
			power := 1;
			IF x < 0 THEN
				x := ABS( x );
				IF ODD( n ) THEN sign := -1 END
			END;
			WHILE n > 0 DO
				WHILE ~ODD( n ) & (n > 0) DO
					max := MAX( NbrInt.Integer ) DIV x;
					IF x > max THEN x := max;  n := 2;  DataErrors.Error( "Arithmatic overflow." ) END;
					x := x * x;  n := n DIV 2
				END;
				max := MAX( NbrInt.Integer ) DIV power;
				IF x > max THEN x := max;  n := 1;  DataErrors.Error( "Arithmatic overflow." ) END;
				power := power * x;  NbrInt.Dec( n )
			END
		END;
		RETURN sign * power
	END Power;

(** Returns a positive pseudo-random number.  To help ensure a truely random random-number,
	the seed is automatically retrieved-from/stored-to file MathRandomSeed by Aos. *)
	PROCEDURE Random*( ): NbrInt.Integer;
	BEGIN
		nbr := rng.Integer();  RETURN nbr
	END Random;

(* Open the file MathRandomSeed to get the starting seed for the random number generator.
	If the file does not exist, then assign a default value of 1 for the seed. *)
	PROCEDURE Open;
	VAR N: Files.FileName;  F: Files.File;  R: Files.Reader;
	BEGIN
		NEW( rng );  COPY( "MathRandomSeed.dat", N );  F := Files.Old( N );
		IF F = NIL THEN nbr := 1 ELSE Files.OpenReader( R, F, 0 );  R.RawLInt( nbr ) END;
		rng.InitSeed( nbr )
	END Open;

(* The file is automatically closed whenever this module is garbage collected, thereby saving the seed. *)
	PROCEDURE Close;
	VAR N: Files.FileName;  F: Files.File;  W: Files.Writer;
	BEGIN
		COPY( "MathRandomSeed.dat", N );  F := Files.Old( N );
		IF F = NIL THEN F := Files.New( N ) END;
		Files.OpenWriter( W, F, 0 );  W.RawLInt( nbr );  W.Update;  Files.Register( F )
	END Close;

BEGIN
	Open;  Modules.InstallTermHandler( Close )
END MathInt.