MODULE Trace;	(** AUTHOR "fn"; PURPOSE "Low-level trace output based on KernelLog"; *)

IMPORT SYSTEM;

TYPE
	CharProc*= PROCEDURE (c:CHAR);
VAR
	Char*: CharProc;
	Color*: PROCEDURE (c: SHORTINT);

(** Send the specified characters to the trace output (cf. Streams.Sender). *)
PROCEDURE Send*(CONST buf: ARRAY OF CHAR; ofs, len: LONGINT; propagate: BOOLEAN; VAR res: LONGINT);
BEGIN INC (len, ofs); WHILE ofs # len DO Char (buf[ofs]); INC (ofs); END; res := 0;
END Send;

(** Skip to the next line on trace output. *)
PROCEDURE Ln*;
BEGIN Char (0DX); Char (0AX);
END Ln;

(** Write a string to the trace output. *)
PROCEDURE String* (CONST s: ARRAY OF CHAR);
VAR i: LONGINT;
BEGIN i := 0; WHILE (i< LEN(s)) & (s[i] # 0X) DO Char (s[i]); INC (i) END;
END String;

(** Write a string to the trace output and skip to next line. *)
PROCEDURE StringLn* (CONST s: ARRAY OF CHAR);
BEGIN String (s); Ln;
END StringLn;

(** Write a character. *)
PROCEDURE Int* (x: HUGEINT; w: LONGINT);
VAR i: SIZE; x0: HUGEINT; a: ARRAY 21 OF CHAR;
BEGIN
	IF x < 0 THEN
		IF x = MIN (HUGEINT) THEN
			DEC (w, 20);
			WHILE w > 0 DO Char (' '); DEC (w) END;
			String ("-9223372036854775808");
			RETURN
		ELSE
			DEC (w); x0 := -x
		END
	ELSE
		x0 := x
	END;
	i := 0;
	REPEAT
		a[i] := CHR (x0 MOD 10 + 30H); x0 := x0 DIV 10; INC (i)
	UNTIL x0 = 0;
	WHILE w > i DO Char (' '); DEC (w) END;
	IF x < 0 THEN Char ('-') END;
	REPEAT DEC (i); Char (a[i]) UNTIL i = 0
END Int;

PROCEDURE Boolean* (x : BOOLEAN);
BEGIN IF x THEN String ("TRUE") ELSE String ("FALSE") END
END Boolean;

(** Write "x" as a decimal number with a power-of-two multiplier (K, M or G), followed by "suffix". "w" is the field width, excluding "suffix". *)
PROCEDURE IntSuffix* (x, w: LONGINT; CONST suffix: ARRAY OF CHAR);
CONST K = 1024; M = K*K; G = K*M;
VAR mult: CHAR;
BEGIN
	IF x MOD K # 0 THEN
		Int (x, w)
	ELSE
		IF x MOD M # 0 THEN mult := 'K'; x := x DIV K
		ELSIF x MOD G # 0 THEN mult := 'M'; x := x DIV M
		ELSE mult := 'G'; x := x DIV G
		END;
		Int (x, w-1); Char (mult)
	END;
	String (suffix)
END IntSuffix;

(**
	Write an integer in hexadecimal right-justified in a field of at least ABS(w) characters.
	If w < 0 THEN w least significant hex digits of x are written (possibly including leading zeros)
*)
PROCEDURE Hex*(x: HUGEINT; w: LONGINT );
VAR i: LONGINT;
	buf: ARRAY 2*SIZEOF(HUGEINT)+2 OF CHAR;
	neg: BOOLEAN;
	c: HUGEINT;
BEGIN
	IF w >= 0 THEN
		i:= 0;
		IF x < 0 THEN neg := TRUE; x :=-x ELSIF x=0 THEN buf := "0" ELSE neg := FALSE END;
		i := 0;
		REPEAT
			c := x MOD 10H;
			IF c < 10 THEN buf[i] := CHR(c+ORD("0")) ELSE buf[i] := CHR(c-10+ORD("A")) END;
			x := x DIV 10H;
			INC(i);
		UNTIL (i = 2 * SIZEOF(HUGEINT)) OR (x=0);
		IF c > 9 THEN buf[i] := "0"; INC(i) END;
		IF neg THEN buf[i] := "-"; INC(i) END;
		WHILE(w > i) DO Char(" "); DEC(w); END;
		REPEAT DEC(i); Char(buf[i]); UNTIL i=0;
	ELSE
		w := -w;
		WHILE(w>2*SIZEOF(HUGEINT)) DO
			Char(" "); DEC(w);
		END;
		buf[w] := 0X;
		REPEAT
			DEC(w);
			c := x MOD 10H;
			IF c <10 THEN buf[w] := CHR(c+ORD("0")) ELSE buf[w] := CHR(c-10+ORD("A")) END;
			x := x DIV 10H;
		UNTIL w = 0;
		String(buf);
	END;

END Hex;

(** Write "x" as a hexadecimal address *)
PROCEDURE Address* (x: ADDRESS);
BEGIN
	Hex(x,-2*SIZEOF(ADDRESS));
END Address;

(** Write "x" as a hexadecimal number. "w" is the field width. Always prints 16 digits. *)
PROCEDURE HIntHex* (x: HUGEINT; w: LONGINT);
BEGIN Hex (x, w);
END HIntHex;

(** Write a block of memory in hex. *)
PROCEDURE Memory* (adr: ADDRESS; size: SIZE);
VAR i, j: ADDRESS; ch: CHAR;
BEGIN
	size := adr+size-1;
	FOR i := adr TO size BY 16 DO
		Address (i); Char (' ');
		FOR j := i TO i+15 DO
			IF j <= size THEN
				SYSTEM.GET (j, ch);
				Char(' ');
				Hex (ORD (ch), -2)
			ELSE
				Char (' ');
			END
		END;
		Char (' ');
		FOR j := i TO i+15 DO
			IF j <= size THEN
				SYSTEM.GET (j, ch);
				IF (ch < ' ') OR (ch >= CHR (127)) THEN ch := '.' END;
				Char (ch)
			END
		END;
		Ln
	END;
END Memory;

(** Write a buffer in hex. *)
PROCEDURE Buffer* (CONST buf: ARRAY OF CHAR; ofs, len: LONGINT);
BEGIN Memory (ADDRESSOF (buf[ofs]), len)
END Buffer;

(** Write bits (ofs..ofs+n-1) of x in binary. *)
PROCEDURE Bits* (x: SET; ofs, n: LONGINT);
BEGIN
	REPEAT
		DEC (n);
		IF (ofs+n) IN x THEN Char ('1') ELSE Char ('0') END
	UNTIL n = 0
END Bits;

PROCEDURE Set*(x: SET);
VAR first: BOOLEAN; i: LONGINT;
BEGIN
	first := TRUE;
	Char("{");
	FOR i := 0 TO MAX(SET) DO
		IF i IN x THEN
			IF ~first THEN Char(",") ELSE first := FALSE END;
			Int(i,1);
		END;
	END;
	Char("}");
END Set;


(** Colors *)
PROCEDURE Blue*;
BEGIN Color (9);
END Blue;

PROCEDURE Green*;
BEGIN Color (10);
END Green;

PROCEDURE Red*;
BEGIN Color (12);
END Red;

PROCEDURE Yellow*;
BEGIN Color (14);
END Yellow;

PROCEDURE Default*;
BEGIN Color (7);
END Default;


PROCEDURE NullChar(c: CHAR);
BEGIN
END NullChar;

PROCEDURE NullColor(c: SHORTINT);
BEGIN
END NullColor;

PROCEDURE Init*;
BEGIN
	Char := NullChar;
	Color := NullColor;	
END Init;


(*
BEGIN
	Char := NullChar;
	Color := NullColor;
	*)
END Trace.

