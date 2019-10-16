MODULE Strings; (** AUTHOR "be,tf, staubesv"; PURPOSE "String functions" *)

IMPORT Streams, Dates, RC := RealConversions;

CONST
	Ok* = 0;

TYPE
	String* = POINTER TO ARRAY OF CHAR;

	StringArray* = POINTER TO ARRAY OF String;

VAR
	DateFormat*, TimeFormat*: ARRAY 32 OF CHAR;	(** date and time format strings used by DateToStr/TimeToStr *)

TYPE

	(** The stringmaker creates an automatically growing character array from the input with an Streams writer *)
	Buffer* = OBJECT
	VAR
		length : SIZE;
		data : String;
		w : Streams.Writer;

		PROCEDURE &Init*(initialSize : SIZE);
		BEGIN
			IF initialSize < 16 THEN initialSize := 256 END;
			NEW(data, initialSize); length := 0;
		END Init;

		PROCEDURE Add*(CONST buf: ARRAY OF CHAR; ofs, len: SIZE; propagate: BOOLEAN; VAR res: INTEGER);
		VAR newSize, i : SIZE; n : String;
		BEGIN
			IF length + len + 1 >= LEN(data) THEN
				newSize := MAX(LEN(data) * 2, length + len + 1);
				NEW(n, newSize);
				FOR i := 0 TO length - 1 DO n[i] := data[i] END;
				data := n;
			END;
			WHILE len > 0 DO
				data[length] := buf[ofs];
				INC(ofs); INC(length); DEC(len);
			END;
			data[length] := 0X;
			res := Ok;
		END Add;

		(** resets the length of the string to 0. The buffer is reused*)
		PROCEDURE Clear*;
		BEGIN
			data[0] := 0X;
			length := 0
		END Clear;

		(** returns an Streams.Writer to the string *)
		PROCEDURE GetWriter*() : Streams.Writer;
		BEGIN
			IF w = NIL THEN NEW(w, SELF.Add, 256) END;
			RETURN w
		END GetWriter;

		(** returns the number of bytes written to the string. The Streams.Writer is updated *)
		PROCEDURE GetLength*() : SIZE;
		BEGIN
			IF w # NIL THEN w.Update END;
			RETURN length
		END GetLength;

		(** returns the current string buffer. If the string maker is reused, the content of the string may or may not
			vary. The application might need to copy the returned string. The Streams.Writer is updated *)
		PROCEDURE GetString*() : String;
		BEGIN
			IF w # NIL THEN w.Update END;
			RETURN data
		END GetString;

		PROCEDURE Write*(out : Streams.Writer);
		BEGIN
			IF w # NIL THEN w.Update END;
			out.Bytes(data^, 0, length)
		END Write;

	END Buffer;

	OPERATOR "+"*( a: String; CONST b: ARRAY OF CHAR ): String;
	VAR str: String;
	BEGIN
		NEW( str, LEN( a ) + Length( b ) );
		COPY( a^, str^ );  Append( str^, b );
		RETURN str
	END "+";

	OPERATOR "+"*( a: String; b: CHAR ): String;
	VAR str: String;
	BEGIN
		NEW( str, LEN( a ) + 1 );
		COPY( a^, str^ );  AppendChar( str^, b );
		RETURN str
	END "+";

	OPERATOR "+"*( a, b: String ): String;
	VAR str: String;
	BEGIN
		NEW( str, LEN( a ) + LEN( b ) );
		COPY( a^, str^ );  Append( str^, b^ );
		RETURN str
	END "+";

	OPERATOR "+"*( a: String; b: SIGNED64 ): String;
	VAR
		digits: ARRAY 32 OF CHAR;
		str: String;
	BEGIN
		IntToStr( b, digits );
		NEW( str, LEN( a ) + Length( digits ) );
		COPY( a^, str^ );  Append( str^, digits );
		RETURN str
	END "+";

	OPERATOR "+"*( a: String; b: FLOAT64 ): String;
	VAR
		digits: ARRAY 32 OF CHAR;
		str: String;
	BEGIN
		RC.RealToString( b, 18, digits );
		NEW( str, LEN( a ) + Length( digits ) );
		COPY( a^, str^ );  Append( str^, digits );
		RETURN str
	END "+";

(** string handling *)

(** returns the length of a string *)
PROCEDURE Length* (CONST string: ARRAY OF CHAR): SIZE;
VAR len: SIZE;
BEGIN
	len := 0; WHILE (string[len] # 0X) DO INC(len) END;
	RETURN len
END Length;

(** Find position of character, returns -1 if not found*)
PROCEDURE Find* (CONST string: ARRAY OF CHAR; pos: SIZE; ch: CHAR): SIZE;
BEGIN
	WHILE (string[pos] # 0X ) & (string[pos] # ch) DO INC(pos) END;
	IF string[pos] = 0X THEN pos := -1 END;
	RETURN pos
END Find;

(** returns the number of occurences of ch within string *)
PROCEDURE Count* (CONST string: ARRAY OF CHAR; ch: CHAR): SIZE;
VAR count, pos: SIZE;
BEGIN
	count := 0; pos := Find (string, 0, ch);
	WHILE pos # -1 DO INC (count); pos := Find (string, pos + 1, ch) END;
	RETURN count
END Count;

(** truncates string to length *)
PROCEDURE Truncate* (VAR string: ARRAY OF CHAR; length: SIZE);
BEGIN
	IF LEN(string) > length THEN string[length] := 0X END;
END Truncate;

(**
 * Returns the position of the first occurrence of pattern in the string or -1 if no occurrence is found.
 * Rabin-Karp algorithm, adopted from Sedgewick.
 *)
PROCEDURE Pos*(CONST pattern, string: ARRAY OF CHAR): SIZE;
CONST
	q = 8204957;	(* prime number, {(d+1) * q <= MAX(SIGNED32)} *)
	d = 256;			(* number of different characters *)
VAR h1, h2, dM: SIGNED32; i, j, m, n: SIZE; found : BOOLEAN;
BEGIN
	m := Length(pattern); n := Length(string);
	IF (m > n) THEN RETURN -1 END;

	dM := 1; FOR i := 0 TO m-2 DO dM := (d*dM) MOD q END;
	h1 := 0; FOR i := 0 TO m-1 DO h1 := (h1*d + ORD(pattern[i])) MOD q END;
	h2 := 0; FOR i := 0 TO m-1 DO h2 := (h2*d + ORD(string[i])) MOD q END;
	i := 0; found := FALSE;

	IF (h1 = h2) THEN (* verify *)
		j := 0; found := TRUE;
		WHILE (j < m) DO
			IF (string[j] # pattern[j]) THEN found := FALSE; j := m; END; (* hash values are equal, but strings are not *)
			INC(j);
		END;
	END;

	WHILE ~found & (i < n-m) DO
		h2 := (h2 + d*q - ORD(string[i])*dM) MOD q;
		h2 := (h2*d + ORD(string[i+m])) MOD q;
		INC(i);

		IF (h1 = h2) THEN (* verify *)
			j := 0; found := TRUE;
			WHILE (j < m) DO
				IF (string[i + j] # pattern[j]) THEN found := FALSE; j := m; END; (* hash values are equal, but strings are not *)
				INC(j);
			END
		END;
	END;

	IF found THEN
		RETURN i;
	ELSE
		RETURN -1
	END
END Pos;

(** More generic version of Pos. Basically the same search algorithm, but can also perform case-insensitive searching and/or
 * backwards directed searching.
 * Returns the position of the first character of the first occurence of 'pattern' in 'text'  in search direction or -1 if pattern not found *)
PROCEDURE GenericPos*(CONST pattern: ARRAY OF CHAR; from : SIZE; CONST string: ARRAY OF CHAR; ignoreCase, backwards : BOOLEAN): SIZE;
CONST
	q = 8204957;	(* prime number, {(d+1) * q <= MAX(SIGNED32)} *)
	d = 256;			(* number of different characters *)
VAR ch, chp : CHAR; h1, h2, dM: SIGNED32; i, j, patternLength, stringLength: SIZE; found : BOOLEAN;
BEGIN
	patternLength := Length(pattern); stringLength := Length(string);

	(* check whether the search pattern can be contained in the text regarding the search direction *)
	IF backwards THEN
		IF (patternLength > from + 1) THEN RETURN -1; END;
	ELSE
		IF (from + patternLength > stringLength) THEN RETURN -1; END;
	END;

	dM := 1; FOR i := 0 TO patternLength-2 DO dM := (d*dM) MOD q END;

	(* calculate hash value for search pattern string *)
	h1 := 0; FOR i := 0 TO patternLength-1 DO
		IF backwards THEN
			ch := pattern[patternLength-1-i];
		ELSE
			ch := pattern[i];
		END;
		IF ignoreCase THEN UpperCaseChar(ch); END;
		h1 := (h1*d + ORD(ch)) MOD q;
	END;

	(* calculate hash value for the first 'patternLength' characters of the text to be searched *)
	h2 := 0; FOR i := 0 TO patternLength-1 DO
		IF backwards THEN
			ch := string[from - i];
		ELSE
			ch := string[from + i];
		END;
		IF ignoreCase THEN UpperCaseChar(ch); END;
		h2 := (h2*d + ORD(ch)) MOD q;
	END;

	i := from; found := FALSE;

	IF (h1 = h2) THEN (* Hash values match, compare strings *)
		j := 0; found := TRUE;
		WHILE (j < patternLength) DO
			ch := string[from + j];
			chp := pattern[j];
			IF ignoreCase THEN UpperCaseChar(ch); UpperCaseChar(chp); END;
			IF (ch # chp) THEN found := FALSE; j := patternLength; END; (* hash values are equal, but strings are not *)
			INC(j);
		END;
	END;

	LOOP
		(* check wether we're finished *)
		IF found THEN EXIT; END;
		IF backwards THEN
			IF (i < patternLength) THEN EXIT; END;
		ELSE
			IF (i >= stringLength-patternLength) THEN EXIT; END;
		END;

		(* remove last character from hash value *)
		ch := string[i];
		IF ignoreCase THEN UpperCaseChar(ch); END;
		h2 := (h2 + d*q - ORD(ch)*dM) MOD q;

		(* add next character to hash value *)
		IF backwards THEN
			ch := string[i-patternLength];
		ELSE
			ch := string[i+patternLength];
		END;
		IF ignoreCase THEN UpperCaseChar(ch); END;
		h2 := (h2*d + ORD(ch)) MOD q;

		IF backwards THEN DEC(i); ELSE INC(i); END;

		IF (h1 = h2) THEN (* verify *)
			j := 0; found := TRUE;
			WHILE (j < patternLength) DO
				IF backwards THEN
					ch := string[i - patternLength + 1 + j];
				ELSE
					ch := string[i + j];
				END;
				chp := pattern[j];
				IF ignoreCase THEN UpperCaseChar(ch); UpperCaseChar(chp); END;
				IF (ch # chp) THEN found := FALSE; j := patternLength; END; (* hash values are equal, but strings are not *)
				INC(j);
			END
		END;
	END;

	IF found THEN
		IF backwards THEN RETURN i - patternLength + 1;
		ELSE RETURN i;
		END;
	ELSE
		RETURN -1;
	END;
END GenericPos;

(** Simple pattern matching with support for "*" and "?" wildcards  - returns TRUE if name matches mask. Patent pending ;-) *)
PROCEDURE Match*(CONST mask, name: ARRAY OF CHAR): BOOLEAN;
VAR m,n, om, on: SIZE; f: BOOLEAN;
BEGIN
	m := 0; n := 0; om := -1;
	f := TRUE;
	LOOP
		IF (mask[m] = "*") THEN
			om := m; INC(m);
			WHILE (name[n] # 0X) & (name[n] # mask[m]) DO INC(n) END;
			on := n
		ELSIF (mask[m] = "?") THEN
			IF (name[n] = 0X) THEN f := FALSE; EXIT END;
			INC(m); INC(n)
		ELSE
			IF (mask[m] # name[n]) THEN
				IF (om = -1) THEN f := FALSE; EXIT
				ELSIF (name[n] # 0X) THEN (* try the next position *)
					m := om; n := on + 1;
					IF (name[n] = 0X) THEN f := FALSE; EXIT END
				ELSE
					f := FALSE; EXIT
				END
			ELSE INC(m); INC(n)
			END
		END;
		IF (mask[m] = 0X) & ((name[n] = 0X) OR (om=-1)) THEN EXIT END
	END;
	RETURN f & (name[n] = 0X)
END Match;

(** copies src[soff ... soff + len - 1] to dst[doff ... doff + len - 1] *)
PROCEDURE Move* (CONST src: ARRAY OF CHAR; soff, len: SIZE; VAR dst: ARRAY OF CHAR; doff: SIZE);
BEGIN
	(* reverse copy direction in case src and dst denote the same string *)
	IF soff < doff THEN
		INC (soff, len - 1); INC (doff, len - 1);
		WHILE len > 0 DO dst[doff] := src[soff]; DEC (soff); DEC (doff); DEC (len) END
	ELSE
		WHILE len > 0 DO dst[doff] := src[soff]; INC (soff); INC (doff); DEC (len) END
	END;
END Move;

(** concatenates s1 and s2: s := s1 || s2 *)
PROCEDURE Concat* (CONST s1, s2: ARRAY OF CHAR; VAR s: ARRAY OF CHAR);
VAR len1, len2 : SIZE;
BEGIN
	len1 := Length (s1); len2 := Length (s2);
	Move(s2, 0, len2, s, len1);
	Move (s1, 0, len1, s, 0);
	Truncate (s, len1 + len2);
END Concat;

(** concatenates s1 and s2: s := s1 || s2. The resulting string is truncated to the length of s if necessary *)
PROCEDURE ConcatX*(CONST s1, s2 : ARRAY OF CHAR; VAR s : ARRAY OF CHAR);
VAR len1, len2 : SIZE;
BEGIN
	len1 := Length (s1); len2 := Length (s2);
	IF (len1 + 1 >= LEN(s)) THEN
		COPY(s1, s);
	ELSE
		IF (len1 + len2 + 1 > LEN(s)) THEN
			len2 := LEN(s) - 1 - len1;
		END;
		Move(s2, 0, len2, s, len1);
		Move (s1, 0, len1, s, 0);
		Truncate (s, len1 + len2);
	END;
END ConcatX;

(** appends appendix to s: s := s || appendix *)
PROCEDURE Append* (VAR s: ARRAY OF CHAR; CONST appendix: ARRAY OF CHAR);
BEGIN Concat (s, appendix, s)
END Append;

(** appends appendix to s: s := s || appendix. The resulting string is truncated to the length of s if necessary *)
PROCEDURE AppendX* (VAR s: ARRAY OF CHAR; CONST appendix: ARRAY OF CHAR);
BEGIN ConcatX (s, appendix, s)
END AppendX;

(** appends an integer number to a string *)
PROCEDURE AppendInt*(VAR s: ARRAY OF CHAR; num: SIGNED64);
VAR number: ARRAY 21 OF CHAR;
BEGIN
	IntToStr(num,number); Append(s,number);
END AppendInt;

(** appends a character to a string s := s || char *)
PROCEDURE AppendChar*(VAR s: ARRAY OF CHAR; ch: CHAR);
VAR cs: ARRAY 2 OF CHAR;
BEGIN
	cs[0] := ch; cs[1] := 0X; Append(s,cs);
END AppendChar;

(** copies src[index ... index + len-1] to dst *)
PROCEDURE Copy* (CONST src: ARRAY OF CHAR; index, len: SIZE; VAR dst: ARRAY OF CHAR);
BEGIN
	Move (src, index, len, dst, 0);
	Truncate (dst, len);
END Copy;

(** deletes positions index ... index + count - 1 from 's' *)
PROCEDURE Delete* (VAR s: ARRAY OF CHAR; index, count: SIZE);
VAR len: SIZE;
BEGIN
	len := Length (s);
	Move (s, index + count, len - index - count, s, index);
	Truncate (s, len - count);
END Delete;

(** inserts 'src' at position 'index' into 'dst' *)
PROCEDURE Insert* (CONST src: ARRAY OF CHAR; VAR dst: ARRAY OF CHAR; index: SIZE);
VAR slen, dlen: SIZE;
BEGIN
	slen := Length (src); dlen := Length (dst);
	Move (dst, index, dlen-index, dst, index+slen);
	Move (src, 0, slen, dst, index);
	Truncate (dst, slen + dlen);
END Insert;

(** removes all occurrences of 'c' at the head of 'string' *)
PROCEDURE TrimLeft* (VAR string: ARRAY OF CHAR; c: CHAR);
VAR len, index: SIZE;
BEGIN
	len := Length (string); index := 0;
	WHILE (index # len) & (string[index] = c) DO INC (index) END;
	Delete (string, 0, index);
END TrimLeft;

(** removes all occurrences of 'c' at the end of 'string' *)
PROCEDURE TrimRight* (VAR string: ARRAY OF CHAR; c: CHAR);
VAR len, index: SIZE;
BEGIN
	len := Length (string); index := len;
	WHILE (index # 0) & (string[index - 1] = c) DO DEC (index) END;
	Delete (string, index, len - index);
END TrimRight;

(** removes all occurrences of 'c' at both ends of 'string' *)
PROCEDURE Trim* (VAR string: ARRAY OF CHAR; c: CHAR);
BEGIN
	TrimLeft(string, c);
	TrimRight(string, c)
END Trim;

(**
 * Splits 'string' into multiple strings separated by 'separator'.
 * Result properties:
 *	separator = 0X:	LEN(StringArray) = 1
 *	separator # 0X:	LEN(StringArray) = 1 + <Number of occurences of 'ch' in 'string'>
 *	StringArray[i] # NIL (0 <= i <= LEN(StringArray)-1)
 *)
PROCEDURE Split*(CONST string : ARRAY OF CHAR; separator : CHAR) : StringArray;
VAR count, index, pos, next: SIZE; result : StringArray;
BEGIN
	count := Count (string, separator);
	NEW (result, count + 1); pos := 0;
	FOR index := 0 TO count DO
		next := Find (string, pos, separator);
		IF next = -1 THEN next := Length (string) END;
		NEW (result[index], next - pos + 1);
		Copy (string, pos, next - pos, result[index]^);
		pos := next + 1;
	END;
	RETURN result;
END Split;

PROCEDURE Join*(CONST strings : StringArray; startIndex, endIndex : SIZE; separator : CHAR) : String;
VAR string : String; length, pos, i : SIZE;
BEGIN
	ASSERT((strings # NIL) & (LEN(strings) >= 1));
	ASSERT((0 <= startIndex) & (startIndex <= endIndex) & (endIndex < LEN(strings)));
	length := 1; (* 0X termination *)
	IF (separator # 0X) THEN length := length + (endIndex - startIndex); END;
	FOR i := startIndex TO endIndex DO
		length := length + Length(strings[i]^);
	END;
	pos := 0;
	NEW(string, length);
	FOR i := startIndex TO endIndex DO
		length := Length(strings[i]^);
		Move(strings[i]^, 0, length, string^, pos);
		pos := pos + length;
		IF (i < endIndex) & (separator # 0X) THEN string[pos] := separator; INC(pos); END;
	END;
	string^[LEN(string)-1] := 0X;
	ASSERT((string # NIL) & (LEN(string) > 0) & (string^[LEN(string)-1] = 0X));
	RETURN string;
END Join;

(** returns the corresponding lower-case letter for "A" <= ch <= "Z" *)
PROCEDURE LOW*(ch: CHAR): CHAR;
BEGIN
	IF (ch >= "A") & (ch <= "Z") THEN RETURN CHR(ORD(ch) - ORD("A") + ORD("a"))
	ELSE RETURN ch
	END
END LOW;

(** converts s to lower-case letters *)
PROCEDURE LowerCase*(VAR s: ARRAY OF CHAR);
VAR i: SIZE;
BEGIN
	i := 0;
	WHILE (s[i] # 0X) DO
		s[i] := LOW(s[i]);
		INC(i)
	END
END LowerCase;

(** returns the corresponding upper-case letter for "a" <= ch <= "z" *)
PROCEDURE UP*(ch : CHAR) : CHAR;
BEGIN
	IF ("a" <= ch) & (ch <= "z") THEN ch := CAP(ch); END;
	RETURN ch;
END UP;

PROCEDURE UpperCaseChar*(VAR ch : CHAR);
BEGIN
	IF ("a" <= ch) & (ch <= "z") THEN ch := CAP(ch); END;
END UpperCaseChar;

(** converts s to upper-case letters *)
PROCEDURE UpperCase*(VAR s: ARRAY OF CHAR);
VAR i: SIZE; c : CHAR;
BEGIN
	i := 0;
	WHILE (s[i] # 0X) DO
		c := s[i];
		IF ('a' <= c) & (c <= 'z') THEN s[i] := CAP(c) END;
		INC(i)
	END
END UpperCase;

(* ASCII printable characters *)
PROCEDURE IsPrintable*(ch:CHAR):BOOLEAN;
BEGIN
	RETURN (ch>=20X) & (ch<=7EX)
END IsPrintable;

(** conversion functions *)

(** converts a boolean value to a string *)
PROCEDURE BoolToStr*(b: BOOLEAN; VAR s: ARRAY OF CHAR);
CONST True = "True"; False = "False";
BEGIN
	IF b THEN COPY(True, s)
	ELSE COPY(False, s)
	END
END BoolToStr;

(** converts a string to a boolean value: b := CAP(s[0]) = "T" *)
PROCEDURE StrToBool*(CONST s: ARRAY OF CHAR; VAR b: BOOLEAN);
BEGIN b := CAP(s[0]) = "T"
END StrToBool;

(** converts an integer value to a string *)
PROCEDURE IntToStr*(x: SIGNED64; VAR s: ARRAY OF CHAR);
VAR i, j: SIZE; x0: SIGNED64; digits: ARRAY 21 OF CHAR;
BEGIN
	IF x < 0 THEN
		IF x = MIN( SIGNED64 ) THEN
			COPY("-9223372036854775808", s) ;
			RETURN;
		ELSE
			x0 := -x; s[0] := "-"; j := 1;
		END;
	ELSE
		x0 := x; j := 0;
	END;

	i := 0;
	REPEAT digits[i] := CHR( x0 MOD 10 + 30H );  x0 := x0 DIV 10;  INC( i ) UNTIL x0 = 0;
	REPEAT DEC( i );  s[j] := digits[i]; INC(j) UNTIL i = 0;
	s[j] := 0X;
END IntToStr;

(** converts a string to an integer. Leading whitespace is ignored *)
PROCEDURE StrToInt*(CONST str: ARRAY OF CHAR; VAR val: SIGNED32);
VAR i: SIZE; d: SIGNED32; neg: BOOLEAN;
BEGIN
	i := 0; WHILE (str[i] # 0X) & (str[i] <= " ") DO INC(i) END;
	neg := FALSE;
	IF (str[i] = "+") THEN INC(i)
	ELSIF (str[i] = "-") THEN neg := TRUE; INC(i)
	END;

	val := 0;
	WHILE (str[i] >= "0") & (str[i] <= "9") DO
		d := ORD(str[i])-ORD("0");
		IF (val <= ((MAX(SIGNED32)-d) DIV 10)) THEN val := 10*val+d
		ELSIF neg & (val = 214748364) & (d = 8) & ((str[i+1] < "0") OR (str[i+1] > "9")) THEN
			(* SIGNED32 range: -2147483648 ... 2147483647 _> need special handling for -2147483648 here *)
			val := MIN(SIGNED32); neg := FALSE
		ELSE
			HALT(99)
		END;
		INC(i)
	END;
	IF neg THEN val := -val END
END StrToInt;

(** converts a string to a huge integer. Leading whitespace is ignored *)
PROCEDURE StrToHInt*(CONST str: ARRAY OF CHAR; VAR val: SIGNED64);
VAR i: SIZE; d: SIGNED64; neg: BOOLEAN;
BEGIN
	i := 0; WHILE (str[i] # 0X) & (str[i] <= " ") DO INC(i) END;
	neg := FALSE;
	IF (str[i] = "+") THEN INC(i)
	ELSIF (str[i] = "-") THEN neg := TRUE; INC(i)
	END;

	val := 0;
	WHILE (str[i] >= "0") & (str[i] <= "9") DO
		d := ORD(str[i])-ORD("0");
		IF (val <= ((MAX(SIGNED64)-d) DIV 10)) THEN val := 10*val+d
		ELSIF neg & (val = 922337203685477580) & (d = 8) & ((str[i+1] < "0") OR (str[i+1] > "9")) THEN
			(* SIGNED64 range: -9223372036854775808 ... 9223372036854775807 _> need special handling for -9223372036854775808 here *)
			val := MIN(SIGNED64); neg := FALSE
		ELSE
			HALT(99)
		END;
		INC(i)
	END;
	IF neg THEN val := -val END
END StrToHInt;

(** converts a string to a size. Leading whitespace is ignored *)
PROCEDURE StrToSize*(CONST str: ARRAY OF CHAR; VAR val: SIZE);
VAR i: SIZE; d: SIZE; neg: BOOLEAN;
BEGIN
	i := 0; WHILE (str[i] # 0X) & (str[i] <= " ") DO INC(i) END;
	neg := FALSE;
	IF (str[i] = "+") THEN INC(i)
	ELSIF (str[i] = "-") THEN neg := TRUE; INC(i)
	END;

	val := 0;
	WHILE (str[i] >= "0") & (str[i] <= "9") DO
		d := ORD(str[i])-ORD("0");
		IF (val <= ((MAX(SIZE)-d) DIV 10)) THEN val := 10*val+d
		ELSIF neg & (val = MAX(SIZE) DIV 10) & (d = MAX(SIZE) MOD 10) & ((str[i+1] < "0") OR (str[i+1] > "9")) THEN
			(* SIZE range needs special handling *)
			val := MIN(SIZE); neg := FALSE
		ELSE
			HALT(99)
		END;
		INC(i)
	END;
	IF neg THEN val := -val END
END StrToSize;

(** Convert the substring beginning at position i in str into an integer. Leading whitespace is ignored.
	After the conversion i points to the first character after the integer. *)
PROCEDURE StrToIntPos*(CONST str: ARRAY OF CHAR; VAR val: SIGNED32; VAR i: SIZE);
VAR noStr: ARRAY 16 OF CHAR;
BEGIN
	WHILE (str[i] # 0X) & (str[i] <= " ") DO INC(i) END;
	val := 0;
	IF str[i] = "-" THEN
		noStr[val] := str[i]; INC(val); INC(i);
		WHILE (str[i] # 0X) & (str[i] <= " ") DO INC(i) END
	END;
	WHILE (str[i] >= "0") & (str[i] <= "9") DO noStr[val] := str[i]; INC(val); INC(i) END;
	noStr[val] := 0X;
	StrToInt(noStr, val)
END StrToIntPos;

(** Convert the substring beginning at position i in str into a huge integer. Leading whitespace is ignored.
	After the conversion i points to the first character after the integer. *)
PROCEDURE StrToHIntPos*(CONST str: ARRAY OF CHAR; VAR val: SIGNED64; VAR i: SIZE);
VAR noStr: ARRAY 32 OF CHAR;
BEGIN
	WHILE (str[i] # 0X) & (str[i] <= " ") DO INC(i) END;
	val := 0;
	IF str[i] = "-" THEN
		noStr[val] := str[i]; INC(val); INC(i);
		WHILE (str[i] # 0X) & (str[i] <= " ") DO INC(i) END
	END;
	WHILE (str[i] >= "0") & (str[i] <= "9") DO noStr[val] := str[i]; INC(val); INC(i) END;
	noStr[val] := 0X;
	StrToHInt(noStr, val)
END StrToHIntPos;

(** Convert the substring beginning at position i in str into a size. Leading whitespace is ignored.
	After the conversion i points to the first character after the integer. *)
PROCEDURE StrToSizePos*(CONST str: ARRAY OF CHAR; VAR val: SIZE; VAR i: SIZE);
VAR noStr: ARRAY 32 OF CHAR;
BEGIN
	WHILE (str[i] # 0X) & (str[i] <= " ") DO INC(i) END;
	val := 0;
	IF str[i] = "-" THEN
		noStr[val] := str[i]; INC(val); INC(i);
		WHILE (str[i] # 0X) & (str[i] <= " ") DO INC(i) END
	END;
	WHILE (str[i] >= "0") & (str[i] <= "9") DO noStr[val] := str[i]; INC(val); INC(i) END;
	noStr[val] := 0X;
	StrToSize(noStr, val)
END StrToSizePos;

(** converts an integer value to a hex string *)
PROCEDURE IntToHexStr*(h : SIGNED64; width: INTEGER; VAR s: ARRAY OF CHAR);
CONST hexDigits = "0123456789ABCDEF";
BEGIN
	IF (width <= 0) THEN width := 8 END; (*! legacy?*)

	s[width] := 0X;
	DEC(width);
	WHILE (width >= 0) DO
		s[width] := hexDigits[h MOD 16];
		h := LSH(h, -4);
		DEC(width);
	END
END IntToHexStr;

(** converts a hex string to an integer. Leading whitespace is ignored. res=Ok indicates success, val=0 on failure. *)
PROCEDURE HexStrToInt*(CONST string: ARRAY OF CHAR; VAR val: SIGNED32; VAR res: INTEGER);
VAR length, i : SIZE; ch: CHAR; negative : BOOLEAN;
BEGIN
	length := LEN(string); val := 0; res := -1;
	(* skip whitespace *)
	i := 0; WHILE (i < length) & (string[i] # 0X) & (string[i] <= " ") DO INC(i); END;
	IF (i < length) THEN
		IF (string[i] = "+") OR (string[i] = "-") THEN
			negative := (string[i] = "-"); INC(i);
		ELSE
			negative := FALSE;
		END;
		LOOP
			IF (i >= length) OR (string[i] = 0X) THEN EXIT; END;
			ch := string[i];
			IF (ch >= "0") & (ch <= "9") THEN val := 16 * val + ORD(ch) - ORD("0");
			ELSIF (CAP(ch) >= "A") & (CAP(ch) <= "F") THEN val := 16 * val + ORD(CAP(ch)) - ORD("A") + 10;
			ELSE EXIT;
			END;
			INC(i);
		END;
		IF (i < length) & (string[i] = "H") THEN INC(i); END; (* skip optional "H" *)
		IF (i < length) & (string[i] = 0X) THEN
			IF negative THEN val := -val END;
			res := Ok;
		END;
	END;
END HexStrToInt;

(** converts a hex string to a size. Leading whitespace is ignored. res=Ok indicates success, val=0 on failure. *)
PROCEDURE HexStrToSize*(CONST string: ARRAY OF CHAR; VAR val: SIZE; VAR res: INTEGER);
VAR length, i : SIZE; ch: CHAR;
BEGIN
	length := LEN(string); val := 0; res := -1;
	(* skip whitespace *)
	i := 0; WHILE (i < length) & (string[i] # 0X) & (string[i] <= " ") DO INC(i); END;
	IF (i < length) THEN
		LOOP
			IF (i >= length) OR (string[i] = 0X) THEN EXIT; END;
			ch := string[i];
			IF (ch >= "0") & (ch <= "9") THEN val := 16 * val + ORD(ch) - ORD("0");
			ELSIF (CAP(ch) >= "A") & (CAP(ch) <= "F") THEN val := 16 * val + ORD(CAP(ch)) - ORD("A") + 10;
			ELSE EXIT;
			END;
			INC(i);
		END;
		IF (i < length) & (string[i] = "H") THEN INC(i); END; (* skip optional "H" *)
		IF (i < length) & (string[i] = 0X) THEN
			res := Ok;
		END;
	END;
END HexStrToSize;

(** converts a real value to a string *)
PROCEDURE FloatToStr*(x: FLOAT64; n, f, D: SIGNED32; VAR str: ARRAY OF CHAR);
BEGIN
	RC.RealToStringFix( x, n, f, D, str )
END FloatToStr;

PROCEDURE AddressToStr*(adr : ADDRESS; VAR str : ARRAY OF CHAR);
BEGIN
	IntToHexStr(adr, 2*SIZEOF(ADDRESS), str);
END AddressToStr;

(** converts a string to a real value *)
PROCEDURE StrToFloat*(CONST s: ARRAY OF CHAR; VAR r: FLOAT64);
BEGIN
	RC.StringToReal(s,r);
END StrToFloat;

(** converts a set to a string *)
PROCEDURE SetToStr*(set: SET; VAR s: ARRAY OF CHAR);
VAR i, j, k: SIGNED16; noFirst: BOOLEAN;
BEGIN
	s[0] := "{"; i := 0; k := 1; noFirst := FALSE;
	WHILE i <= MAX(SET) DO
		IF i IN set THEN
			IF noFirst THEN s[k] := ","; INC(k) ELSE noFirst := TRUE END;
			IF i >= 10 THEN s[k] := CHR(i DIV 10 + 30H); INC(k) END;
			s[k] := CHR(i MOD 10 + 30H); INC(k);
			j := i; INC(i);
			WHILE (i <= MAX(SET)) & (i IN set) DO INC(i) END;
			IF i-2 > j THEN
				s[k] := "."; s[k+1] := "."; INC(k, 2); j := i - 1;
				IF j >= 10 THEN s[k] := CHR(j DIV 10 + 30H); INC(k) END;
				s[k] := CHR(j MOD 10 + 30H); INC(k)
			ELSE i := j
			END
		END;
		INC(i)
	END;
	s[k] := "}"; s[k+1] := 0X
END SetToStr;

(** converts a string to a set *)
PROCEDURE StrToSet*(CONST str: ARRAY OF CHAR; VAR set: SET);
VAR i, d, d1: SIGNED16; dot: BOOLEAN;
BEGIN
	set := {}; dot := FALSE;
	i := 0;
	WHILE (str[i] # 0X) & (str[i] # "}") DO
		WHILE (str[i] # 0X) & ((str[i] < "0") OR ("9" < str[i])) DO INC(i) END;
		d := 0; WHILE ("0" <= str[i]) & (str[i] <= "9") DO d := d*10 + ORD(str[i]) - 30H; INC(i) END;
		IF (str[i] = 0X) THEN RETURN; END;
		IF d <= MAX(SET) THEN INCL(set, d) END;
		IF dot THEN
			WHILE (d1 <= MAX(SET)) & (d1 < d) DO INCL(set, d1); INC(d1) END;
			dot := FALSE
		END;
		WHILE (str[i] = " ") DO INC(i) END;
		IF (str[i] = ".") THEN d1 := d + 1; dot := TRUE END
	END
END StrToSet;

(** converts a time to a string, using the 'TimeFormat' format. C.f. FormatDateTime *)
PROCEDURE TimeToStr*(time: Dates.DateTime; VAR s: ARRAY OF CHAR);
BEGIN FormatDateTime(TimeFormat, time, s)
END TimeToStr;

(** converts a string to a time *)
PROCEDURE StrToTime*(CONST str: ARRAY OF CHAR; VAR dt: Dates.DateTime);
VAR i: SIZE;
BEGIN
	i := 0;
	WHILE (str[i] # 0X) & ((str[i] < "0") OR (str[i] > "9")) DO INC(i) END;
	StrToIntPos(str, dt.hour, i);
	WHILE (str[i] # 0X) & ((str[i] < "0") OR (str[i] > "9")) DO INC(i) END;
	StrToIntPos(str, dt.minute, i);
	WHILE (str[i] # 0X) & ((str[i] < "0") OR (str[i] > "9")) DO INC(i) END;
	StrToIntPos(str, dt.second, i);
	ASSERT(Dates.ValidDateTime(dt));
END StrToTime;

(** converts a date to a string, using the 'DateFormat' format. C.f. FormatDateTime *)
PROCEDURE DateToStr*(date: Dates.DateTime; VAR s: ARRAY OF CHAR);
BEGIN FormatDateTime(DateFormat, date, s)
END DateToStr;

(** Convert a string of the form 'day month year' into an date value. Leading whitespace is ignored. *)
PROCEDURE StrToDate*(CONST str: ARRAY OF CHAR; VAR dt: Dates.DateTime);
VAR i: SIZE;
BEGIN
	i := 0;
	WHILE (str[i] # 0X) & ((str[i] < "0") OR (str[i] > "9")) DO INC(i) END;
	StrToIntPos(str, dt.day, i);
	WHILE (str[i] # 0X) & ((str[i] < "0") OR (str[i] > "9")) DO INC(i) END;
	StrToIntPos(str, dt.month, i);
	WHILE (str[i] # 0X) & ((str[i] < "0") OR (str[i] > "9")) DO INC(i) END;
	StrToIntPos(str, dt.year, i);
	ASSERT(Dates.ValidDateTime(dt));
END StrToDate;

(** converts a TDateTime into a string.
	Format rules:
	yyyy	->	four-digit year, e.g. 2001
	yy		->	two-digit year, e.g. 01
	mmmm ->	clear-text month, e.g. May
	mmm  ->  clear-text month, abbreviated, e.g. Sep
	mm	->	two-digit month, e.g. 05
	m		->	month, e.g. 5
	dd		->	two-digit day, e.g. 02
	d		->	day, e.g. 2 or 15
	wwww	-> clear-text week-day, e.g. Monday
	www	->  clear-text week-day, e.g. Mon

	hh		->	two-digit hour, e.g. 08
	h		->	hour, e.g. 8
	nn		-> two-digit minute, e.g. 03
	n		-> minute, e.g. 3
	ss		-> two-digit second, e.g. 00
	s		-> second, e.g. 0
	any other characters will be copied 1:1 to the result string

	Examples:
	"yyyy.mm.dd hh:nn:ss"	-> "2002.01.01 17:08:00"
	"yyyyyy.m.ddd"				-> "002002.1.001"
	"wwww, mmmm d, yyyy"			-> "Tuesday, September 11, 2001"
*)
PROCEDURE FormatDateTime*(CONST format: ARRAY OF CHAR; dt: Dates.DateTime; VAR result: ARRAY OF CHAR);
VAR i,k,l,len,n: SIZE; m,y,w,dw: SIGNED32;

	PROCEDURE IntToStr(v: SIGNED32; len: SIZE; VAR s: ARRAY OF CHAR; VAR pos: SIZE);
	VAR i: SIZE;
	BEGIN
		FOR i := 1 TO len DO s[pos+len-i] := CHR(ORD("0") + v MOD 10); v := v DIV 10 END;
		INC(pos, len)
	END IntToStr;

BEGIN
	k := 0;
	IF Dates.ValidDateTime(dt) THEN
		i := 0;
		WHILE (format[i] # 0X) DO
			n := 1; WHILE (format[i+n] = format[i]) DO INC(n) END;
			len := n;
			CASE format[i] OF
			|"w": Dates.WeekDate(dt, y, w, dw); DEC(dw);
					IF (len >= 4) THEN len := 10 END;
					l := 0; WHILE (l < len) & (Dates.Days[dw,l] # 0X) DO result[k] := Dates.Days[dw,l]; INC(k); INC(l) END;
			|"y": IntToStr(dt.year, n, result, k);
			|"m": IF (n >= 3) THEN
						m := dt.month-1; ASSERT((m>=0) & (m<12));
						IF (len > 3) THEN len := 12 END;
						l := 0; WHILE (l < len) & (Dates.Months[m,l] # 0X) DO result[k] := Dates.Months[m, l]; INC(k); INC(l) END
					ELSE
						IF (len=1) & (dt.month > 9) THEN len := 2; END;
						IntToStr(dt.month, len, result, k)
					END;
			|"d": IF (len=1) & (dt.day > 9) THEN len := 2 END;
					IntToStr(dt.day, len, result, k);
			|"h": IF (len=1) & (dt.hour > 9) THEN len := 2 END;
					IntToStr(dt.hour, len, result, k);
			|"n": IF (len=1) & (dt.minute > 9) THEN len := 2 END;
					IntToStr(dt.minute, len, result, k);
			|"s": IF (len=1) & (dt.second > 9) THEN len := 2 END;
					IntToStr(dt.second, len, result, k);
			ELSE result[k] := format[i]; INC(k); n := 1
			END;
			INC(i, n)
		END
	END;
	result[k] := 0X
END FormatDateTime;

PROCEDURE ShowTimeDifference*(t1, t2 : Dates.DateTime; out : Streams.Writer);
VAR days, hours, minutes, seconds : SIGNED32; show : BOOLEAN;
BEGIN
	Dates.TimeDifference(t1, t2, days, hours, minutes, seconds);
	show := FALSE;
	IF (days > 0) THEN out.Int(days, 0); out.String("d "); show := TRUE; END;
	IF show OR (hours > 0) THEN out.Int(hours, 0); out.String("h "); show := TRUE;  END;
	IF show OR (minutes > 0) THEN out.Int(minutes, 0); out.String("m "); show := TRUE; END;
	out.Int(seconds, 0); out.String("s");
END ShowTimeDifference;

PROCEDURE NewString*(CONST str : ARRAY OF CHAR) : String;
VAR l : SIZE; s : String;
BEGIN
	l := Length(str) + 1;
	NEW(s, l);
	COPY(str, s^);
	RETURN s
END NewString;

PROCEDURE SetAOC*(CONST str: ARRAY OF CHAR; VAR s: String);
VAR l: SIZE;
BEGIN
	l := Length(str) + 1;
	IF (s = NIL) OR (LEN(s^) < l) THEN
		NEW(s,l)
	END;
	COPY(str, s^);
END SetAOC;

(* Gets extension of the given name, returns file (without extension) and ext *)
PROCEDURE GetExtension* (CONST name : ARRAY OF CHAR; VAR file, ext: ARRAY OF CHAR);
VAR len, index: SIZE;
BEGIN
	len := Length (name); index := len;
	WHILE (index # 0) & (name[index- 1] # '.') DO DEC (index) END;
	IF index = 0 THEN
		Copy (name, 0, len, file);
		Truncate (ext, 0);
	ELSE
		Copy (name, 0, index - 1, file);
		Copy (name, index, len - index, ext);
	END
END GetExtension;

(* Returns a new string that is a concatenation of s1 and s2: s := s1 || s2 *)
PROCEDURE ConcatToNew*(CONST s1, s2 : ARRAY OF CHAR) : String;
VAR
	s : String;
BEGIN
	NEW(s, Length(s1) + Length(s2) + 1);
	Concat(s1, s2, s^);
	RETURN s;
END ConcatToNew;

(* Tests if string s ends with the specified suffix *)
PROCEDURE EndsWith*(CONST suffix, s : ARRAY OF CHAR) : BOOLEAN;
BEGIN
	RETURN StartsWith(suffix, Length(s)-Length(suffix), s);
END EndsWith;

(* Tests if two strings are equal *)
(* This procedure makes sense, because "proc(..)^ = proc(..)^" is not supported by the compiler! *)
PROCEDURE Equal*(s1, s2 : String) : BOOLEAN;
BEGIN
	ASSERT(s1 # NIL);
	ASSERT(s2 # NIL);
	RETURN s1^ = s2^;
END Equal;

(** Returns TRUE if the 0X-terminated string contains the character 'ch', FALSE otherwise. *)
PROCEDURE ContainsChar*(CONST string : ARRAY OF CHAR; ch : CHAR; ignoreCase : BOOLEAN) : BOOLEAN;
BEGIN
	IF ignoreCase THEN
		RETURN (Find (string, 0, LOW (ch)) # -1) & (Find (string, 0, UP (ch)) # -1)
	ELSE
		RETURN Find (string, 0, ch) # -1
	END
END ContainsChar;

(* Returns the index within string s of the first occurrence of the specified character *)
PROCEDURE IndexOfByte2*(ch : CHAR; CONST s : ARRAY OF CHAR) : SIZE;
BEGIN
	RETURN IndexOfByte(ch, 0, s);
END IndexOfByte2;

(* Returns the index within string s of the first occurrence of the specified character, starting the search at the specified index *)
PROCEDURE IndexOfByte*(ch : CHAR; fromIndex : SIZE; CONST s : ARRAY OF CHAR) : SIZE;
VAR
	lenString, i : SIZE;
BEGIN
	lenString := Length(s);
	IF fromIndex < 0 THEN
		fromIndex := 0;
	ELSIF fromIndex >= lenString THEN
		RETURN -1;
	END;
	FOR i := fromIndex TO lenString-1 DO
		IF s[i] = ch THEN RETURN i; END;
	END;
	RETURN -1;
END IndexOfByte;

(* Returns the index within string s of the last occurrence of the specified character *)
PROCEDURE LastIndexOfByte2*(ch : CHAR; CONST s : ARRAY OF CHAR) : SIZE;
BEGIN
	RETURN LastIndexOfByte(ch, Length(s)-1, s);
END LastIndexOfByte2;

(* Returns the index within string s of the last occurrence of the specified character, searching backward starting at the specified index *)
PROCEDURE LastIndexOfByte*(ch : CHAR; fromIndex : SIZE; CONST s : ARRAY OF CHAR) : SIZE;
VAR
	lenString, i : SIZE;
BEGIN
	lenString := Length(s);
	IF fromIndex >= lenString THEN
		fromIndex := lenString - 1;
	END;
	FOR i := fromIndex TO 0 BY -1 DO
		IF s[i] = ch THEN RETURN i; END;
	END;
	RETURN -1;
END LastIndexOfByte;

(* Returns a new string that is a copy of s in lower-case letters *)
PROCEDURE LowerCaseInNew*(CONST s : ARRAY OF CHAR) : String;
VAR
	n : String;
BEGIN
	n := NewString(s);
	LowerCase(n^);
	RETURN n;
END LowerCaseInNew;

(* Tests if string s starts with the specified prefix *)
PROCEDURE StartsWith2*(CONST prefix, s : ARRAY OF CHAR) : BOOLEAN;
BEGIN
	RETURN StartsWith(prefix, 0, s);
END StartsWith2;

(* Tests if string s starts with the specified prefix beginning a specified index *)
PROCEDURE StartsWith*(CONST prefix : ARRAY OF CHAR; toffset : SIZE; CONST s : ARRAY OF CHAR) : BOOLEAN;
VAR
	lenString, lenPrefix, i : SIZE;
BEGIN
	lenString := Length(s);
	lenPrefix := Length(prefix);
	IF (toffset < 0) OR (toffset > lenString - lenPrefix) THEN
		RETURN FALSE;
	END;
	FOR i := 0 TO lenPrefix-1 DO
		IF prefix[i] # s[toffset + i] THEN RETURN FALSE; END;
	END;
	RETURN TRUE;
END StartsWith;

(* Returns a new string that is a substring of string s *)
PROCEDURE Substring2*(beginIndex : SIZE; CONST s : ARRAY OF CHAR) : String;
BEGIN
	RETURN Substring(beginIndex, Length(s), s);
END Substring2;

(* Returns a new string that is a substring of string s *)
(* s[endIndex-1] is the last character of the new string *)
PROCEDURE Substring*(beginIndex : SIZE; endIndex : SIZE; CONST s : ARRAY OF CHAR) : String;
VAR
	lenString, lenNewString : SIZE;
	st : String;
BEGIN
	ASSERT(beginIndex >= 0);
	lenString := Length(s);
	ASSERT(endIndex <= lenString);
	lenNewString := endIndex - beginIndex;
	ASSERT(lenNewString >= 0);
	NEW(st, lenNewString + 1);
	Copy(s, beginIndex, lenNewString, st^);
	RETURN st;
END Substring;

(* Omitts leading and trailing whitespace of string s *)
PROCEDURE TrimWS*(VAR s : ARRAY OF CHAR);
VAR
	len, start, i : SIZE;
BEGIN
	len := Length(s);
	start := 0;
	WHILE (start < len) & (ORD(s[start]) < 33) DO
		INC(start);
	END;
	WHILE (start < len) & (ORD(s[len-1]) < 33) DO
		DEC(len);
	END;
	IF start > 0 THEN
		FOR i := 0 TO len - start - 1 DO
			s[i] := s[start + i];
		END;
		s[i] := 0X;
	ELSE
		s[len] := 0X;
	END;
END TrimWS;

(* Returns a new string that is a copy of s in upper-case letters *)
PROCEDURE UpperCaseInNew*(CONST s : ARRAY OF CHAR) : String;
VAR n : String;
BEGIN
	n := NewString(s);
	UpperCase(n^);
	RETURN n;
END UpperCaseInNew;

BEGIN
	DateFormat := "dd.mmm.yyyy";
	TimeFormat := "hh:nn:ss"
END Strings.

System.Free Strings ~
