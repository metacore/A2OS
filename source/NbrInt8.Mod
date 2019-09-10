(* CAPO - Computational Analysis Platform for Oberon - by Alan Freed and Felix Friedrich. *)
(* Version 1, Update 2 *)

MODULE NbrInt8;   (** AUTHOR "adf"; PURPOSE "Alias for type SIGNED8."; *)

IMPORT Streams;

TYPE
	Integer* = SIGNED8;

VAR
	MinNbr-, MaxNbr-: Integer;

	(** All arithmetic operations are built into the compiler and therefore need not to be defined here. *)

	(** Basic Functions*)
	PROCEDURE Abs*( i: Integer ): Integer;
	BEGIN
		IF i > MinNbr THEN RETURN ABS( i ) ELSE RETURN i END
	END Abs;

	PROCEDURE Dec*( VAR i: Integer );
	BEGIN
		IF i > MinNbr THEN DEC( i ) END
	END Dec;

	PROCEDURE Inc*( VAR i: Integer );
	BEGIN
		IF i < MaxNbr THEN INC( i ) END
	END Inc;

	PROCEDURE Odd*( i: Integer ): BOOLEAN;
	BEGIN
		RETURN (i MOD 2) = 1
	END Odd;

	PROCEDURE Max*( x1, x2: Integer ): Integer;
	BEGIN
		IF x1 > x2 THEN RETURN x1 ELSE RETURN x2 END
	END Max;

	PROCEDURE Min*( x1, x2: Integer ): Integer;
	BEGIN
		IF x1 < x2 THEN RETURN x1 ELSE RETURN x2 END
	END Min;

	PROCEDURE Sign*( x: Integer ): Integer;
	VAR sign: Integer;
	BEGIN
		IF x < 0 THEN sign := -1
		ELSIF x = 0 THEN sign := 0
		ELSE sign := 1
		END;
		RETURN sign
	END Sign;

	(** String conversions. *)
(** Admissible characters include: {" ", "-", "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", ","}. *)
	PROCEDURE StringToInt*( CONST string: ARRAY OF CHAR;  VAR x: Integer );
	VAR negative: BOOLEAN;  i: Integer;
	BEGIN
		i := 0;
		(* Pass over any leading white space. *)
		WHILE string[i] = CHR( 20H ) DO INC( i ) END;
		(* Determine the sign. *)
		IF string[i] = CHR( 2DH ) THEN negative := TRUE;  Inc( i ) ELSE negative := FALSE END;
		(* Read in the string and convert it into an integer. *)
		x := 0;
		WHILE string[i] # 0X DO
			IF (CHR( 30H ) <= string[i]) & (string[i] <= CHR( 39H )) THEN x := 10 * x + SHORT( ORD( string[i] ) - 30H )
			ELSE
				(* Inadmissible character - it is skipped. *)
			END;
			INC( i )
		END;
		IF negative THEN x := -x END
	END StringToInt;

(** LEN(string) >= 5 *)
	PROCEDURE IntToString*( x: Integer;  VAR string: ARRAY OF CHAR );
	VAR positive: BOOLEAN;  i, k: Integer;
		a: ARRAY 5 OF CHAR;
	BEGIN
		IF x > MinNbr THEN
			(* Determine the sign. *)
			IF x < 0 THEN x := -x;  positive := FALSE ELSE positive := TRUE END;
			(* Convert the integer into a string. *)
			WHILE x > 0 DO a[i] := CHR( (x MOD 10) + 30H );  x := x DIV 10;  Inc( i ) END;
			(* Test for zero. *)
			IF i = 0 THEN a[0] := CHR( 30H );  Inc( i ) END;
			(* Terminate the string. *)
			a[i] := 0X;  k := 0;
			IF ~positive THEN
				(* Write a minus sign. *)
				string[k] := CHR( 2DH );  Inc( k )
			END;
			(* Rewrite the string in a formatted output, inverting the order stored in a[i]. *)
			REPEAT Dec( i );  string[k] := a[i];  Inc( k ) UNTIL i = 0;
			string[k] := 0X
		ELSE COPY( "-128", string )
		END
	END IntToString;

(** Persistence: file IO *)
	PROCEDURE Load*( R: Streams.Reader;  VAR x: Integer );
	BEGIN
		R.RawSInt( x )
	END Load;

	PROCEDURE Store*( W: Streams.Writer;  x: Integer );
	BEGIN
		W.RawSInt( x )
	END Store;

BEGIN
	MinNbr := MIN( SIGNED8 );  MaxNbr := MAX( SIGNED8 )
END NbrInt8.