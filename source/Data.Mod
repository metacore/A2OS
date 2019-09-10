(* CAPO - Computational Analysis Platform for Oberon - by Alan Freed and Felix Friedrich. *)
(* Version 1, Update 2 *)

MODULE Data;   (** AUTHOR "adf"; PURPOSE "Sortable data objects (via a key)"; *)

IMPORT NbrInt64, NbrInt, DataErrors, DataIO;

CONST
	(*  Version number used when reading/writing an instance of Datum to file. *)
	VERSION* = 1;
	(* The maximum that base can be is 78 and still retain a 10 character string when based on a 64-bit integer. *)
	BASE = 78;
	(** Maximum number of characters allowed in a Word. *)
	CHARACTERS* = 10;

TYPE
	Key* = RECORD
		k: NbrInt64.Integer
	END;

	(** Class Datum has been DataIO registered, and therefore, any instance of it can be made persistent
		by using the DataIO Reader and Writer, or more simply, by calling procedures Load and Store below. *)

	Datum* = OBJECT
	VAR key: Key;

		(** Sets the key to its sentinel value. *)
		PROCEDURE & Initialize*;
		BEGIN
			key.k := Sentinel.k
		END Initialize;

	(** Returns a deep copy of the data; shallow copies are obtained via assignment, i.e., :=. *)
		PROCEDURE Copy*( VAR copy: Datum );
		BEGIN
			IF copy = NIL THEN NEW( copy ) END;
			copy.key := SELF.key
		END Copy;

	(** Used internally to read data from a file. *)
		PROCEDURE Read*( R: DataIO.Reader );
		BEGIN {EXCLUSIVE}
			NbrInt64.Load( R, key.k )
		END Read;

	(** Used internally to write data to a file. *)
		PROCEDURE Write*( W: DataIO.Writer );
		BEGIN
			NbrInt64.Store( W, key.k )
		END Write;

	(** Obtain the key held by an instance of Datum. *)
		PROCEDURE GetKey*( VAR k: Key );
		BEGIN
			k.k := key.k
		END GetKey;

	(** A datum's key can only be changed when its key = Sentinel.  Once set, it cannot be reset. *)
		PROCEDURE SetKey*( k: Key );
		BEGIN
			IF key.k = Sentinel.k THEN
				BEGIN {EXCLUSIVE}
					key.k := k.k
				END
			END
		END SetKey;

	END Datum;


	(** A word is case sensitive.  Admissible characters include:
						word		=	char { char }.
						char			=	letter | digit | punctuation | arithmetic | alien.
						letter		=	"A" ... "Z" | "a" ... "z".
						digit		=	"0" ... "9".
						punctuation	=	" " | "." | ":" | ";" | "," | "_" | "~" | " ' " | ' " '.
						arithmetic	=	"+" | "-" | "*" | "/" | "^" | "=".
						alien		=	"?".
			Yes, white space is an admissible character.  However, leading and trailing white space is ignored.
			All unknown characters are assigned the alien glyph "?". *)
	Word* = ARRAY CHARACTERS + 1 OF CHAR;

VAR
	intToChar: POINTER TO ARRAY OF CHAR;
	charToInt: POINTER TO ARRAY OF SIGNED32;
	(** The initial key assigned to a Data.Datum.  It is the only key that can be overwritten via SetKey. *)
	Sentinel-: Key;


	(** Assignment operators for Keys. *)
	OPERATOR ":="*( VAR l: Key;  r: NbrInt.Integer );
	BEGIN
		l.k := r
	END ":=";

	OPERATOR ":="*( VAR l: Key;  r: NbrInt64.Integer );
	BEGIN
		l.k := r
	END ":=";

(** Comparison Operators between Keys. *)
	OPERATOR "="*( l, r: Key ): BOOLEAN;
	BEGIN
		RETURN l.k = r.k
	END "=";

	OPERATOR "#"*( l, r: Key ): BOOLEAN;
	BEGIN
		RETURN l.k # r.k
	END "#";

	OPERATOR "<"*( l, r: Key ): BOOLEAN;
	BEGIN
		RETURN l.k < r.k
	END "<";

	OPERATOR ">"*( l, r: Key ): BOOLEAN;
	BEGIN
		RETURN l.k > r.k
	END ">";

	OPERATOR "<="*( l, r: Key ): BOOLEAN;
	BEGIN
		RETURN l.k <= r.k
	END "<=";

	OPERATOR ">="*( l, r: Key ): BOOLEAN;
	BEGIN
		RETURN l.k >= r.k
	END ">=";

(** Comparison Operators between Data. *)
	OPERATOR "="*( l, r: Datum ): BOOLEAN;
	BEGIN
		RETURN l.key = r.key
	END "=";

	OPERATOR "#"*( l, r: Datum ): BOOLEAN;
	BEGIN
		RETURN l.key # r.key
	END "#";

	OPERATOR "<"*( l, r: Datum ): BOOLEAN;
	BEGIN
		RETURN l.key < r.key
	END "<";

	OPERATOR ">"*( l, r: Datum ): BOOLEAN;
	BEGIN
		RETURN l.key > r.key
	END ">";

	OPERATOR "<="*( l, r: Datum ): BOOLEAN;
	BEGIN
		RETURN l.key <= r.key
	END "<=";

	OPERATOR ">="*( l, r: Datum ): BOOLEAN;
	BEGIN
		RETURN l.key >= r.key
	END ">=";

(** Conversion procedure. *)
	PROCEDURE KeyToInt64*( key: Key;  VAR x: NbrInt64.Integer );
	BEGIN
		x := key.k
	END KeyToInt64;

(** Instead of using integers for sorting against, sometimes it is useful to use words for this purpose,
	like entries in a dictionary.  KetToWord  and  WordToKey  are mappings that allow for this.  *)
	PROCEDURE KeyToWord*( key: Key;  VAR word: Word );
	VAR i, k, len: NbrInt.Integer;  base1, base2, base3, base4, base5, base6, base7, base8, base9: NbrInt64.Integer;
		int: ARRAY CHARACTERS OF NbrInt64.Integer;
		string: Word;
	BEGIN
		(* Extract the string of integers from the single compressed integer. *)
		base1 := BASE;  base2 := base1 * base1;  base3 := base2 * base1;  base4 := base3 * base1;  base5 := base4 * base1;
		base6 := base5 * base1;  base7 := base6 * base1;  base8 := base7 * base1;  base9 := base8 * base1;
		(* The following algorithm is for CHARACTERS = 10. *)
		int[0] := key.k DIV base9;  int[1] := (key.k DIV base8) MOD base1;  int[2] := (key.k DIV base7) MOD base1;
		int[3] := (key.k DIV base6) MOD base1;  int[4] := (key.k DIV base5) MOD base1;  int[5] := (key.k DIV base4) MOD base1;
		int[6] := (key.k DIV base3) MOD base1;  int[7] := (key.k DIV base2) MOD base1;  int[8] := (key.k DIV base1) MOD base1;
		int[9] := key.k MOD base1;
		(* Convert this integer string into a character string. *)
		FOR i := 0 TO CHARACTERS - 1 DO k := NbrInt64.Short( int[i] );  string[i] := intToChar[k] END;
		string[CHARACTERS] := 0X;
		(* Remove trailing white space recreating the compressed string. *)
		len := CHARACTERS;
		WHILE (len > 0) & (string[len - 1] = 20X) DO DEC( len ) END;
		FOR i := 0 TO len - 1 DO word[i] := string[i] END;
		word[len] := 0X
	END KeyToWord;

	PROCEDURE WordToKey*( word: Word;  VAR key: Key );
	VAR i, k, len: NbrInt.Integer;
		int: ARRAY CHARACTERS OF NbrInt.Integer;
		string: Word;
	BEGIN
		len := -1;
		REPEAT INC( len )
		UNTIL word[len] = 0X;
		(* Remove leading white space. *)
		k := 0;
		WHILE word[k] = 20X DO INC( k ) END;
		(* Convert the passed string into a local string. *)
		FOR i := 0 TO len - k - 1 DO string[i] := word[i + k] END;
		(* Add trailing white space, as required, to the local string. *)
		FOR i := len - k TO CHARACTERS - 1 DO string[i] := 20X END;
		string[CHARACTERS] := 0X;
		(* Convert each character in the local string to a corresponding integer. *)
		FOR i := 0 TO CHARACTERS - 1 DO int[i] := charToInt[ORD( string[i] )] END;
		(* Compress this integer string into a single integer. *)
		key.k := 0;
		FOR i := 0 TO CHARACTERS - 2 DO key.k := (key.k + int[i]) * BASE END;
		key.k := key.k + int[CHARACTERS - 1]
	END WordToKey;

(* Create the local variables  charToInt  and  intToChar.  These procedures are courtesy of Patrik Reali. *)
	PROCEDURE MakeCharToInt;
	VAR i: NbrInt.Integer;
	BEGIN
		FOR i := 0 TO 255 DO
			charToInt[i] := BASE - 1 (* Default - set all entries to the alien's value. *)
		END;
		charToInt[20H] := 0;   (* white space *)
		charToInt[ORD( "." )] := 1;  charToInt[ORD( ":" )] := 2;  charToInt[ORD( ";" )] := 3;  charToInt[ORD( "," )] := 4;  charToInt[ORD( "_" )] := 5;
		charToInt[ORD( "~" )] := 6;  charToInt[ORD( "'" )] := 7;  charToInt[ORD( '"' )] := 8;  charToInt[ORD( "+" )] := 9;  charToInt[ORD( "-" )] := 10;
		charToInt[ORD( "*" )] := 11;  charToInt[ORD( "/" )] := 12;  charToInt[ORD( "^" )] := 13;  charToInt[ORD( "=" )] := 14;  charToInt[ORD( "0" )] := 15;
		charToInt[ORD( "1" )] := 16;  charToInt[ORD( "2" )] := 17;  charToInt[ORD( "3" )] := 18;  charToInt[ORD( "4" )] := 19;  charToInt[ORD( "5" )] := 20;
		charToInt[ORD( "6" )] := 21;  charToInt[ORD( "7" )] := 22;  charToInt[ORD( "8" )] := 23;  charToInt[ORD( "9" )] := 24;  charToInt[ORD( "A" )] := 25;
		charToInt[ORD( "a" )] := 26;  charToInt[ORD( "B" )] := 27;  charToInt[ORD( "b" )] := 28;  charToInt[ORD( "C" )] := 29;  charToInt[ORD( "c" )] := 30;
		charToInt[ORD( "D" )] := 31;  charToInt[ORD( "d" )] := 32;  charToInt[ORD( "E" )] := 33;  charToInt[ORD( "e" )] := 34;  charToInt[ORD( "F" )] := 35;
		charToInt[ORD( "f" )] := 36;  charToInt[ORD( "G" )] := 37;  charToInt[ORD( "g" )] := 38;  charToInt[ORD( "H" )] := 39;  charToInt[ORD( "h" )] := 40;
		charToInt[ORD( "I" )] := 41;  charToInt[ORD( "i" )] := 42;  charToInt[ORD( "J" )] := 43;  charToInt[ORD( "j" )] := 44;  charToInt[ORD( "K" )] := 45;
		charToInt[ORD( "k" )] := 46;  charToInt[ORD( "L" )] := 47;  charToInt[ORD( "l" )] := 48;  charToInt[ORD( "M" )] := 49;  charToInt[ORD( "m" )] := 50;
		charToInt[ORD( "N" )] := 51;  charToInt[ORD( "n" )] := 52;  charToInt[ORD( "O" )] := 53;  charToInt[ORD( "o" )] := 54;  charToInt[ORD( "P" )] := 55;
		charToInt[ORD( "p" )] := 56;  charToInt[ORD( "Q" )] := 57;  charToInt[ORD( "q" )] := 58;  charToInt[ORD( "R" )] := 59;  charToInt[ORD( "r" )] := 60;
		charToInt[ORD( "S" )] := 61;  charToInt[ORD( "s" )] := 62;  charToInt[ORD( "T" )] := 63;  charToInt[ORD( "t" )] := 64;  charToInt[ORD( "U" )] := 65;
		charToInt[ORD( "u" )] := 66;  charToInt[ORD( "V" )] := 67;  charToInt[ORD( "v" )] := 68;  charToInt[ORD( "W" )] := 69;  charToInt[ORD( "w" )] := 70;
		charToInt[ORD( "X" )] := 71;  charToInt[ORD( "x" )] := 72;  charToInt[ORD( "Y" )] := 73;  charToInt[ORD( "y" )] := 74;  charToInt[ORD( "Z" )] := 75;
		charToInt[ORD( "z" )] := 76;
		(* Assign the alien character. *)
		charToInt[ORD( "?" )] := 77
	END MakeCharToInt;

	PROCEDURE MakeIntToChar;
	VAR i, k: NbrInt.Integer;
	BEGIN
		(* Assigns all elements the alien character. *)
		FOR i := 0 TO BASE - 1 DO intToChar[i] := "?" END;
		(* Overwrite with the correct character. *)
		FOR i := 0 TO 255 DO k := charToInt[i];  intToChar[k] := CHR( i ) END
	END MakeIntToChar;

(* The procedures needed to register type Datum so that its instances can be made persistent. *)
	PROCEDURE LoadObj( R: DataIO.Reader;  VAR obj: OBJECT );
	VAR version: SIGNED8;  ver: NbrInt.Integer;  new: Datum;
	BEGIN
		R.RawSInt( version );
		IF version = -1 THEN
			obj := NIL  (* Version tag is -1 for NIL. *)
		ELSE
			IF version = VERSION THEN NEW( new );  new.Read( R );  obj := new
					ELSE  (* Encountered an unknown version number. *)
				ver := version;  DataErrors.IntError( ver, "Alien version number encountered." );  HALT( 1000 )
			END
		END
	END LoadObj;

	PROCEDURE StoreObj( W: DataIO.Writer;  obj: OBJECT );
	VAR old: Datum;
	BEGIN
		IF obj = NIL THEN W.RawSInt( -1 ) ELSE W.RawSInt( VERSION );  old := obj( Datum );  old.Write( W ) END
	END StoreObj;

	PROCEDURE Register;
	VAR anInstanceOf: Datum;
	BEGIN
		NEW( anInstanceOf );  DataIO.PlugIn( anInstanceOf, LoadObj, StoreObj )
	END Register;

(** Load and Store are procedures for external use that read/write an instance of Datum from/to a file. *)
	PROCEDURE Load*( R: DataIO.Reader;  VAR obj: Datum );
	VAR ptr: OBJECT;
	BEGIN
		R.Object( ptr );  obj := ptr( Datum )
	END Load;

	PROCEDURE Store*( W: DataIO.Writer;  obj: Datum );
	BEGIN
		W.Object( obj )
	END Store;

BEGIN
	Sentinel.k := NbrInt64.MinNbr;  NEW( charToInt, 256 );  MakeCharToInt;  NEW( intToChar, BASE );  MakeIntToChar;  Register
END Data.