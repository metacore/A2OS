(* CAPO - Computational Analysis Platform for Oberon - by Alan Freed and Felix Friedrich. *)
(* Version 1, Update 2 *)

MODULE NbrInt64;   (** AUTHOR "prk & adf"; PURPOSE "MathH with name changes to avoid basic-type conflicts."; *)

IMPORT NbrInt8, NbrInt32, Streams;

TYPE
	(** A 64-bit integer type. *)
	Integer* =SIGNED64;

VAR
	MinNbr-, MaxNbr-, One, Two: Integer;

CONST


	PROCEDURE Abs*( a: Integer ): Integer;
	BEGIN
		RETURN ABS(a);
	END Abs;

	PROCEDURE Dec*( VAR a: Integer );
	BEGIN
		DEC(a);
	END Dec;

	PROCEDURE Inc*( VAR a: Integer );
	BEGIN
		INC(a);
	END Inc;

	PROCEDURE Odd*( a: Integer ): BOOLEAN;
	BEGIN
		RETURN Odd(a);
	END Odd;

	PROCEDURE Long*( i: NbrInt32.Integer ): Integer;
	BEGIN
		RETURN i;
	END Long;

	PROCEDURE IsInt32*( i: Integer ): BOOLEAN;
	BEGIN
			IF (i >= NbrInt32.MinNbr) & (i <= NbrInt32.MaxNbr) THEN RETURN TRUE ELSE RETURN FALSE END
	END IsInt32;

	PROCEDURE Short*( h: Integer ): NbrInt32.Integer;
	BEGIN
		RETURN SHORT(h);
	END Short;

	PROCEDURE Max*( x1, x2: Integer ): Integer;
	BEGIN
		IF x1 > x2 THEN RETURN x1 ELSE RETURN x2 END
	END Max;

	PROCEDURE Min*( x1, x2: Integer ): Integer;
	BEGIN
		IF x1 < x2 THEN RETURN x1 ELSE RETURN x2 END
	END Min;

	PROCEDURE Sign*( x: Integer ): NbrInt8.Integer;
	VAR sign: NbrInt8.Integer;
	BEGIN
		IF x < 0 THEN sign := -1
		ELSIF x = 0 THEN sign := 0
		ELSE sign := 1
		END;
		RETURN sign
	END Sign;

	(** String conversions. *)
(** Admissible characters include: {" ", "-", "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", ","}. *)
	PROCEDURE StringToInt*( string: ARRAY OF CHAR;  VAR x: Integer );
	VAR negative: BOOLEAN;  i: NbrInt8.Integer;
	BEGIN
		i := 0;
		(* Pass over any leading white space. *)
		WHILE string[i] = CHR( 20H ) DO NbrInt8.Inc( i ) END;
		(* Determine the sign. *)
		IF string[i] = CHR( 2DH ) THEN negative := TRUE;  NbrInt8.Inc( i ) ELSE negative := FALSE END;
		(* Read in the string and convert it into an integer. *)
		x := 0;
		WHILE string[i] # 0X DO
			IF (CHR( 30H ) <= string[i]) & (string[i] <= CHR( 39H )) THEN x := 10 * x + LONG( ORD( string[i] ) - 30H )
			ELSE
				(* Inadmissible character - it is skipped. *)
			END;
			NbrInt8.Inc( i )
		END;
		IF negative THEN x := -x END
	END StringToInt;

(** LEN(string) >= 27 *)
	PROCEDURE IntToString*( x: Integer;  VAR string: ARRAY OF CHAR );
	VAR positive: BOOLEAN;  i, k: NbrInt8.Integer;
		a: ARRAY 21 OF CHAR;
	BEGIN
		IF x > MinNbr THEN
			(* Determine the sign. *)
			IF x < 0 THEN x := -x;  positive := FALSE ELSE positive := TRUE END;
			(* Convert the integer into a string. *)
			WHILE x > 0 DO a[i] := CHR( Short( x MOD 10 ) + 30H );  x := x DIV 10;  NbrInt8.Inc( i ) END;
			(* Test for zero. *)
			IF i = 0 THEN a[0] := CHR( 30H );  NbrInt8.Inc( i ) END;
			(* Terminate the string. *)
			a[i] := 0X;  k := 0;
			IF ~positive THEN
				(* Write a minus sign. *)
				string[k] := CHR( 2DH );  NbrInt8.Inc( k )
			END;
			(* Rewrite the string in a formatted output, inverting the order stored in a[i]. *)
			REPEAT
				NbrInt8.Dec( i );  string[k] := a[i];  NbrInt8.Inc( k );
				IF (i > 0) & ((i MOD 3) = 0) THEN
					(* Write a comma. *)
					string[k] := CHR( 2CH );  NbrInt8.Inc( k )
				END
			UNTIL i = 0;
			string[k] := 0X
		ELSE COPY( "-9,223,372,036,854,775,808", string )
		END
	END IntToString;

(** Persistence: file IO *)
	PROCEDURE Load*( R: Streams.Reader;  VAR x: Integer );
	VAR low, hi: NbrInt32.Integer
	BEGIN
		NbrInt32.Load( R, low );  NbrInt32.Load( R, hi );
		x := low + 100000000H * hi;
	END Load;

	PROCEDURE Store*( W: Streams.Writer;  x: Integer );
	VAR low, hi: NbrInt32.Integer;
	BEGIN
		low := SHORT(x);
		hi := SHORT(x DIV 100000000H);
		NbrInt32.Store( W, low );  NbrInt32.Store( W, hi )
	END Store;

BEGIN
	MinNbr := MIN(Integer);
	MaxNbr := MAX(Integer);
	One := 1;
	Two := 2;
END NbrInt64.