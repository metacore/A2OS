(* CAPO - Computational Analysis Platform for Oberon - by Alan Freed and Felix Friedrich. *)
(* Version 1, Update 2 *)

MODULE NbrInt32;   (** AUTHOR "adf"; PURPOSE "Alias for type SIGNED32."; *)

IMPORT NbrInt8, NbrInt16, Streams;

TYPE
	Integer* = SIGNED32;

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

	PROCEDURE Long*( i: NbrInt16.Integer ): Integer;
	BEGIN
		RETURN LONG( i )
	END Long;

	PROCEDURE IsInt16*( i: Integer ): BOOLEAN;
	BEGIN
		IF (i >= NbrInt16.MinNbr) & (i <= NbrInt16.MaxNbr) THEN RETURN TRUE ELSE RETURN FALSE END
	END IsInt16;

	PROCEDURE Short*( i: Integer ): NbrInt16.Integer;
	BEGIN
		RETURN SHORT( i )
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

(** LEN(string) >= 15 *)
	PROCEDURE IntToString*( x: Integer;  VAR string: ARRAY OF CHAR );
	VAR positive: BOOLEAN;  i, k: NbrInt8.Integer;
		a: ARRAY 12 OF CHAR;
	BEGIN
		IF x > MinNbr THEN
			(* Determine the sign. *)
			IF x < 0 THEN x := -x;  positive := FALSE ELSE positive := TRUE END;
			(* Convert the integer into a string. *)
			WHILE x > 0 DO a[i] := CHR( (x MOD 10) + 30H );  x := x DIV 10;  NbrInt8.Inc( i ) END;
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
		ELSE COPY( "-2,147,483,648", string )
		END
	END IntToString;

(** Persistence: file IO *)
	PROCEDURE Load*( R: Streams.Reader;  VAR x: Integer );
	VAR char: CHAR;  sInt: NbrInt8.Integer;  int: NbrInt16.Integer;
	BEGIN
		R.Char( char );
		IF char = "S" THEN R.RawSInt( sInt );  x := Long( NbrInt16.Long( sInt ) )
		ELSIF char = "I" THEN R.RawInt( int );  x := Long( int )
		ELSE  (* char = "L" *) R.RawLInt( x )
		END
	END Load;

	PROCEDURE Store*( W: Streams.Writer;  x: Integer );
	VAR sInt: NbrInt8.Integer;  int: NbrInt16.Integer;
	BEGIN
		IF IsInt16( x ) THEN
			int := Short( x );
			IF NbrInt16.IsInt8( int ) THEN sInt := NbrInt16.Short( int );  W.Char( "S" );  W.RawSInt( sInt )
			ELSE W.Char( "I" );  W.RawInt( int )
			END
		ELSE W.Char( "L" );  W.RawLInt( x )
		END
	END Store;

BEGIN
	MinNbr := MIN( SIGNED32 );  MaxNbr := MAX( SIGNED32 )
END NbrInt32.