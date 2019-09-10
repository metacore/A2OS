MODULE vyHostStrings IN Oberon;
(* Copyright notice:

This file is part of Voyager
Copyright (C) 1993-2002 Project Voyager, StatLab Heidelberg ; (C) 1993-2002 G. Sawitzki et al.

This library is free software; you can redistribute it and/or
modify it under the terms of the GNU Lesser General Public
License as published by the Free Software Foundation; either
version 2.1 of the License, or (at your option) any later version.

This library is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
Lesser General Public License for more details.

You should have received a copy of the GNU Lesser General Public
License along with this library; if not, write to the Free Software
Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

Copy of the GNU Lesser General Public License can be found in the file COPYING.TXT
Report any problems as soon as possible to voyager@statlab.uni-heidelberg.de
*)


(* 	(c) Project Voyager, StatLab Heidelberg  *)

IMPORT (*Objects,Texts,*)Reals IN A2;
	(*= Try to avoid strings if possible. Use Text instead *)
	(*From Strings HM 94-06-22*)
	(*-------------------------------------------------------------
	Strings provides a set of operations on strings (i.e., on string constants and character
	arrays, both of which contain the character 0X as a terminator). All positions in
	strings start at 0.

	Strings.Length(s)
	returns the number of characters in s up to and excluding the first 0X.
	Strings.Insert(src, pos, dst)
	inserts the string src into the string dst at position pos (0 <= pos <= Length(dst)).
	If pos = Length(dst), src is appended to dst. If the size of dst is not large enough
	to hold the result of the operation, the result is truncated so that dst is always
	terminated with a 0X.
	Strings.Append(s, dst)
	has the same effect as Insert(s, Length(s), dst).
	Strings.Delete(s, pos, n)
	deletes n characters from s starting at position pos (0 <= pos < Length(s)).
	If n > Length(s) - pos, the new length of s is pos.
	Strings.Replace(src, pos, dst)
	has the same effect as Delete(dst, pos, Length(src)) followed by an Insert(src, pos, dst).
	Strings.Extract(src, pos, n, dst)
	extracts a substring dst with n characters from position pos (0 <= pos < Length(src)) in src.
	If n > Length(src) - pos, dst is only the part of src from pos to Length(src) - 1. If the size of
	dst is not large enough to hold the result of the operation, the result is truncated so that
	dst is always terminated with a 0X.
	Strings.Pos(pat, s, pos)
	returns the position of the first occurrence of pat in s after position pos (inclusive).
	If pat is not found, -1 is returned.
	Strings.Cap(s)
	replaces each lower case letter in s by its upper case equivalent.
	-------------------------------------------------------------*)
CONST
	(*	maxD = 9; *)(* from Texts.Mod *)
	maxreallen = 20;  (* maximal string lenght for real *)
	ExpChar = "E";  (* instead of "D" as used in Strings *)

	VAR TenM1, Ten7, Ten8: FLOAT64;
	HexDig: ARRAY 17 OF CHAR;
	(*
	PROCEDURE Expo (x: FLOAT32): SIGNED16;
	(* Fix for Oberon f. Windows *)
	VAR
	L : SIGNED32;
	BEGIN L := Reals.Expo(x); RETURN SHORT(L) END Expo;
	*)

PROCEDURE Length* (s: ARRAY OF CHAR): SIGNED32;
	VAR VAR i, len: SIGNED32;
BEGIN
	len := LEN(s);   i := 0;   WHILE (i < len) & (s[i] # 0X) DO INC(i) END;
	RETURN i
END Length;


PROCEDURE Append* (VAR dest: ARRAY OF CHAR;   extra: ARRAY OF CHAR);
	(*= Append extra to dest. Always adds a stopping 0X.
	Argument order as in Strings. May be changed in future release!! *)
	VAR n1, n2, i, LENdest: SIGNED32;
BEGIN
	n1 := Length(dest);   n2 := Length(extra);   i := 0;   LENdest := LEN(dest);
	WHILE (i < n2) & (i + n1 < LENdest) DO dest[i + n1] := extra[i];   INC(i) END;
	IF i + n1 < LENdest THEN dest[i + n1] := 0X ELSE dest[LENdest - 1] := 0X END
END Append;


PROCEDURE Insert* (source: ARRAY OF CHAR;   pos: SIGNED32;   VAR dest: ARRAY OF CHAR);
	VAR n1, n2, i: SIGNED32;
BEGIN
	n1 := Length(dest);   n2 := Length(source);
	IF pos < 0 THEN pos := 0 END;
	IF pos > n1 THEN Append(dest, source);   RETURN END;
	IF pos + n2 < LEN(dest) THEN  (*make room for source*)
		i := n1;   (*move also 0X if it is there*)
		WHILE i >= pos DO
			IF i + n2 < LEN(dest) THEN dest[i + n2] := dest[i] END;
			DEC(i)
		END
	END;
	i := 0;   WHILE i < n2 DO dest[pos + i] := source[i];   INC(i) END
END Insert;


PROCEDURE Delete* (VAR s: ARRAY OF CHAR;   pos, n: SIGNED32);
	VAR len, i: SIGNED32;
BEGIN
	len := Length(s);
	IF pos < 0 THEN pos := 0 ELSIF pos >= len THEN RETURN END;
	IF pos + n < len THEN
		i := pos + n;   WHILE i < len DO s[i - n] := s[i];   INC(i) END;
		IF i - n < LEN(s) THEN s[i - n] := 0X END
	ELSE s[pos] := 0X
	END
END Delete;


PROCEDURE Replace* (source: ARRAY OF CHAR;   pos: SIGNED32;   VAR dest: ARRAY OF CHAR);
BEGIN
	Delete(dest, pos, pos + Length(source));
	Insert(source, pos, dest)
END Replace;


PROCEDURE Extract* (source: ARRAY OF CHAR;   pos, n: SIGNED32;   VAR dest: ARRAY OF CHAR);
	VAR len, destLen, i: SIGNED32;
BEGIN
	len := Length(source);   destLen := SIGNED32(LEN(dest)) - 1;
	IF pos < 0 THEN pos := 0 END;
	IF pos >= len THEN dest[0] := 0X;   RETURN END;
	i := 0;
	WHILE (pos + i <= LEN(source)) & (source[pos + i] # 0X) & (i < n) DO
		IF i < destLen THEN dest[i] := source[pos + i] END;
		INC(i)
	END;
	dest[i] := 0X
END Extract;


PROCEDURE Pos* (pattern, s: ARRAY OF CHAR;   pos: SIGNED32): SIGNED32;
	VAR n1, n2, i, j: SIGNED32;
BEGIN
	n1 := Length(s);   n2 := Length(pattern);
	IF n2 = 0 THEN RETURN 0 END;
	i := pos;
	WHILE i <= n1 - n2 DO
		IF s[i] = pattern[0] THEN
			j := 1;   WHILE (j < n2) & (s[i + j] = pattern[j]) DO INC(j) END;
			IF j = n2 THEN RETURN i END
		END;
		INC(i)
	END;
	RETURN - 1
END Pos;

PROCEDURE Cap* (VAR s: ARRAY OF CHAR);
	VAR i: SIGNED32;
BEGIN
	FOR i := 0 TO Length(s) - 1 DO s[i] := CAP(s[i]) END
END Cap;


PROCEDURE Equal* (s1, s2: ARRAY OF CHAR): BOOLEAN;
	VAR i, n1, n2: SIGNED32;
BEGIN
	i := 0;   n1 := Length(s1);   n2 := Length(s2);
	LOOP
		IF i >= n1 THEN RETURN i >= n2 END;
		IF i >= n2 THEN RETURN i >= n1 END;
		IF s1[i] = 0X THEN RETURN s2[i] = 0X END;
		IF s1[i] # s2[i] THEN RETURN FALSE END;
		INC(i)
	END
END Equal;


PROCEDURE Less* (s1, s2: ARRAY OF CHAR): BOOLEAN;
	VAR i, n1, n2: SIGNED32;
BEGIN
	i := 0;   n1 := Length(s1);   n2 := Length(s2);
	LOOP
		IF i >= n1 THEN RETURN i < n2 END;
		IF i >= n2 THEN RETURN FALSE END;
		IF s1[i] # s2[i] THEN RETURN s1[i] < s2[i] END;
		INC(i)
	END
END Less;


PROCEDURE Diff* (s1, s2: ARRAY OF CHAR): SIGNED32;
BEGIN
	IF Equal(s1, s2) THEN RETURN 0
	ELSIF Less(s1, s2) THEN RETURN - 1
	ELSE RETURN 1
	END
END Diff;

(* adapted from Texts.Mod. Calling sequence as above. Text uses destination first *)
PROCEDURE AppendInt* (x, fieldlen: SIGNED32;   VAR dest: ARRAY OF CHAR);
	(*= Append to dest; use at least fieldlen positions *)
	VAR i: SIGNED32;   x0: SIGNED32;
	a: ARRAY 11 OF CHAR;   pos: SIGNED32;
BEGIN
	i := 0;   (* FOF changed *)
	IF x < 0 THEN
		IF x = MIN(SIGNED32) THEN Append(dest, " -2147483648");   RETURN
		ELSE DEC(fieldlen);   x0 := - x
		END
	ELSE x0 := x
	END;
	REPEAT
		a[i] := CHR(x0 MOD 10 + 30H);   x0 := x0 DIV 10;   INC(i)
	UNTIL x0 = 0;
	pos := Length(dest);
	WHILE fieldlen > i DO dest[pos] := " ";   DEC(fieldlen);   INC(pos) END;
	IF x < 0 THEN dest[pos] := "-";   INC(pos)  END;
	REPEAT DEC(i);   dest[pos] := a[i];   INC(pos) UNTIL i = 0;
	dest[pos] := 0X
END AppendInt;


PROCEDURE IntToHexStr* (x: SIGNED32;   VAR dest: ARRAY OF CHAR);
	(* Convert SIGNED32 to 8 digit hex string. No leading space, no trailing 'H' *)
	VAR i: SIGNED32;
BEGIN
	i := 0;
	REPEAT
		dest[i] := HexDig[x MOD 10H];
		x := x DIV 10H;   INC(i)
	UNTIL i = 8;
	dest[i] := 0X
END IntToHexStr;

PROCEDURE AppendHex* (x: SIGNED32;   VAR dest: ARRAY OF CHAR);
	(* no leading space used *)
	VAR i: SIGNED32;
	a: ARRAY 10 OF CHAR;   pos: SIGNED32;
BEGIN 		pos := Length(dest);
	IntToHexStr(x, a);
	i := 0;  REPEAT   dest[pos] := a[i];   INC(pos);  INC(i)  UNTIL i = 8;
	dest[pos] := 0X
END  AppendHex;

(* tricks for the windows version *)
(*
PROCEDURE AppendBuffer (buf: Texts.Buffer;  VAR str: ARRAY OF CHAR);
VAR
text: Texts.Text;  R: Texts.Reader;  j: SIGNED32;
BEGIN (*	NEW(text);
text := TextFrames.Text("xy001zz"); (*! ????? avoid call to text frames *)
(*Texts.Open(text,'Temp');*)  (*! how do we get a new empty open text ?*)*)
Texts.New;  text:=Objects.NewObj(Texts.Text);
Texts.Append(text, buf);
Texts.OpenReader(R, text, 0);
j := Length(str);  WHILE (j < text.len) DO Texts.Read(R, str[j]);  INC(j) END
END AppendBuffer;
*)

PROCEDURE RealToHexStr* (x: FLOAT64;  VAR s: ARRAY OF CHAR);
	(* adapted from Texts.WriteLongRealHex *)
	VAR h, l: SIGNED32;
BEGIN Reals.IntL(x, h, l); IntToHexStr(h, s);  AppendHex(l, s)
END RealToHexStr;

PROCEDURE RealToStr* (x: FLOAT64;  n: SIGNED32;  VAR s: ARRAY OF CHAR);
	(*= Right adjusted in n pos. n >=9 preferred *)
	(* from Texts.WriteLongReal *)
	VAR e, h, l, i, len, pos: SIGNED32;  z: FLOAT64;  d: ARRAY 16 OF CHAR;

PROCEDURE Wr (ch: CHAR);
BEGIN
	IF ch = 0X THEN HALT(42) END;  (*! remove when possible *)
	IF pos < len THEN s[pos] := ch;  INC(pos) END
END Wr;
BEGIN
	len := LEN(s) - 1; ASSERT(len >= n);
	pos := 0;
	e := Reals.ExpoL(x);
	IF e = 2047 THEN
		WHILE n > 9 DO Wr( " ");  DEC(n) END;
		Reals.NaNCodeL(x, h, l);
		IF (h # 0) OR (l # 0) THEN Wr("N");  Wr("a");  Wr("N")
		ELSIF x < 0 THEN Wr("-");  Wr("I");  Wr("N");  Wr("F")
		ELSE Wr("I");  Wr("N");  Wr("F")
		END
	ELSE
		IF n <= 9 THEN n := 1 ELSE DEC(n, 8) END;
		REPEAT Wr( " ");  DEC(n) UNTIL n <= 15;  (* 0 <= n <= 15 fraction digits *)
		IF (e # 0) & (x < 0) THEN Wr( "-");  x := - x ELSE Wr( " ") END;
		IF e = 0 THEN h := 0;  l := 0 (* no denormals *)
		ELSE e := (e - 1023) * 301029 DIV 1000000;  (* ln(2)/ln(10) = 0.301029996 *)
			z := Reals.Ten(e + 1);
			IF x >= z THEN x := x / z;  INC(e) ELSE x := x * Reals.Ten( - e) END;
			IF x >= 10 THEN x := x * Reals.Ten( - 1) + 0.5D0 / Reals.Ten(n);  INC(e)
			ELSE x := x + 0.5D0 / Reals.Ten(n);
				IF x >= 10 THEN x := x * Reals.Ten( - 1);  INC(e) END
			END;
			x := x * Reals.Ten(7);  h := ENTIER(x);  x := (x - h) * Reals.Ten(8);  l := ENTIER(x)
		END;
		i := 15;  WHILE i > 7 DO d[i] := CHR(l MOD 10 + ORD("0"));  l := l DIV 10;  DEC(i) END;
		WHILE i >= 0 DO d[i] := CHR(h MOD 10 + ORD("0"));  h := h DIV 10;  DEC(i) END;
		Wr( d[0]);  Wr( ".");  i := 1;  WHILE i <= n DO Wr( d[i]);  INC(i) END;
		Wr(ExpChar);  IF e < 0 THEN Wr('-');  (*WriteString(W, "D-");*)e := - e ELSE Wr('+');  (*WriteString(W, "D+")*)END;
			Wr( CHR(e DIV 100 + ORD("0")));  e := e MOD 100;
			Wr( CHR(e DIV 10 + ORD("0")));  Wr( CHR(e MOD 10 + ORD("0")))
		END
	END RealToStr;

	PROCEDURE RealToStrOld* (x: FLOAT64;  VAR s: ARRAY OF CHAR);
		(*= Deprecated. Use new  RealToStr instead. Left adjusted. Length is determined by length of s. *)
		(* from Strings. Modified to use E notation, using precalculated powers of ten  *)
		VAR e, h, l, n, len: SIGNED32;  i, j, pos: SIGNED32;  z: FLOAT64;  d: ARRAY 16 OF CHAR;
	PROCEDURE Wr (ch: CHAR);
	BEGIN
		IF ch = 0X THEN HALT(42) END;  (*! remove when possible *)
		IF pos < len THEN s[pos] := ch;  INC(pos) END
	END Wr;
BEGIN
	len := LEN(s) - 1;  pos := 0;
	e := Reals.ExpoL(x);
	IF e = 2047 THEN
		Reals.NaNCodeL(x, h, l);
		IF (h # 0) OR (l # 0) THEN Wr("N");  Wr("a");  Wr("N")
		ELSIF x < 0 THEN Wr("-");  Wr("I");  Wr("N");  Wr("F")
		ELSE Wr("I");  Wr("N");  Wr("F")
		END
	ELSE
		n := 14;
		IF (x < 0) & (e # 0) THEN Wr("-");  x := - x END;
		IF e = 0 THEN
			h := 0;  l := 0 (* no denormals *)
		ELSE
			e := (e - 1023) * 301029 DIV 1000000;  (* ln(2)/ln(10) = 0.301029996 *)
			z := Reals.Ten(e + 1);
			IF x >= z THEN x := x / z;  INC(e) ELSE x := x * Reals.Ten(  - e) END;
			IF x >= 10 THEN
				x := x * TenM1 + 0.5D0 / Reals.Ten(n);  INC(e)
			ELSE
				x := x + 0.5D0 / Reals.Ten(n);
				IF x >= 10 THEN x := x * TenM1;  INC(e) END
			END;
			x := x * Reals.Ten(7);  h := ENTIER(x);  x := (x - h) * Ten8;  l := ENTIER(x)
		END;
		i := 15;  WHILE i > 7 DO d[i] := CHR(l MOD 10 + ORD("0"));  l := l DIV 10;  DEC(i) END;
		WHILE i >= 0 DO d[i] := CHR(h MOD 10 + ORD("0"));  h := h DIV 10;  DEC(i) END;
		IF ABS(e) > 8 THEN (* scientific notation *)
			j := 15;  WHILE (j > 0) & (d[j] = "0") DO DEC(j) END;
			Wr(d[0]);  IF j # 0 THEN Wr(".") END;  i := 1;  WHILE i <= j DO Wr(d[i]);  INC(i) END;
			IF e < 0 THEN  Wr(ExpChar); (*Wr("D");*)Wr("-");  e := - e ELSE Wr(ExpChar); (*Wr("D");*)Wr("+") END;
			Wr(CHR(e DIV 100 + ORD("0")));  e := e MOD 100;
			Wr(CHR(e DIV 10 + ORD("0")));  Wr(CHR(e MOD 10 + ORD("0")))
		ELSE
			IF e < 0 THEN (* leading zeros *)
				j := (* !15*)14;  WHILE (j > 0) & (d[j] = "0") DO DEC(j) END;
				Wr("0");  Wr(".");  INC(e);
				WHILE e < 0 DO Wr("0");  INC(e) END;
				i := 0;  WHILE i <= j DO Wr(d[i]);  INC(i) END
			ELSE
				i := 0;  WHILE (e >= 0) & (i < 16 ) DO Wr(d[i]);  INC(i);  DEC(e) END;
				IF i < 16 THEN
					Wr(".");
					WHILE i < (*16*)15 DO Wr(d[i]);  INC(i) END;
					WHILE s[pos - 1] = "0"DO DEC(pos) END;
					IF s[pos - 1] = "."THEN DEC(pos) END
				END
			END
		END
	END;
	s[pos] := 0X
END RealToStrOld;


PROCEDURE RealToFixStr* (x: FLOAT64;   VAR str: ARRAY OF CHAR;   n, f, D: SIGNED32);
	(* from Strings. Modified to use E notation, using precalculated powers of ten *)
	VAR pos, len, e, i, h, l: SIGNED32;   r, z: FLOAT64;   d: ARRAY 16 OF CHAR;   s: CHAR;

PROCEDURE Wr (ch: CHAR);
BEGIN
	IF ch = 0X THEN HALT(42) END;   (*! remove when possible *)
	IF pos < len THEN str[pos] := ch;   INC(pos) END
END Wr;

BEGIN
	len := LEN(str) - 1;   pos := 0;
	e := Reals.ExpoL(x);
	IF (e = 2047) OR (ABS(D) > 308) THEN
		Reals.NaNCodeL(x, h, l);
		IF (h # 0) OR (l # 0) THEN Wr("N");  Wr("a");  Wr("N")
		ELSIF x < 0 THEN Wr("-");  Wr("I");  Wr("N");  Wr("F")
		ELSE Wr("I");  Wr("N");  Wr("F")
		END
	ELSE
		IF D = 0 THEN DEC(n, 2) ELSE DEC(n, 7) END;
		IF n < 2 THEN n := 2 END;
		IF f < 0 THEN f := 0 END;
		IF n < f + 2 THEN n := f + 2 END;
		DEC(n, f);
		IF (e # 0) & (x < 0) THEN s := "-";   x := - x ELSE s := " "END;
		IF e = 0 THEN
			h := 0;   l := 0;   DEC(e, D - 1) (* no denormals *)
		ELSE
			e := (e - 1023) * 301029 DIV 1000000;   (* ln(2)/ln(10) = 0.301029996 *)
			z := Reals.Ten(e + 1);
			IF x >= z THEN x := x / z;   INC(e) ELSE x := x * Reals.Ten( - e) END;
			DEC(e, D - 1);   i := - (e + f);
			IF i <= 0 THEN r := 5 * Reals.Ten(i) ELSE r := 0 END;
			IF x >= 10 THEN
				x := x * TenM1 + r;   INC(e)
			ELSE
				x := x + r;
				IF x >= 10 THEN x := x * TenM1;   INC(e) END
			END;
			x := x * Ten7;   h := ENTIER(x);   x := (x - h) * Ten8;   l := ENTIER(x)
		END;
		i := 15;
		WHILE i > 7 DO d[i] := CHR(l MOD 10 + ORD("0"));   l := l DIV 10;   DEC(i) END;
		WHILE i >= 0 DO d[i] := CHR(h MOD 10 + ORD("0"));   h := h DIV 10;   DEC(i) END;
		IF n <= e THEN n := e + 1 END;
		IF e > 0 THEN
			WHILE n > e DO Wr(" ");   DEC(n) END;
			Wr(s);   e := 0;
			WHILE n > 0 DO
				DEC(n);
				IF e < 16 THEN Wr(d[e]);   INC(e) ELSE Wr("0") END
			END;
			Wr(".")
		ELSE
			WHILE n > 1 DO Wr(" ");   DEC(n) END;
			Wr(s);   Wr("0");   Wr(".");
			WHILE (0 < f) & (e < 0) DO Wr("0");   DEC(f);   INC(e) END
		END;
		WHILE f > 0 DO
			DEC(f);
			IF e < 16 THEN Wr(d[e]);   INC(e) ELSE Wr("0") END
		END;
		IF D # 0 THEN
			IF D < 0 THEN Wr(ExpChar); (*Wr("D");*)Wr("-");   D := - D
			ELSE Wr(ExpChar); (*Wr("D");*)Wr("+")
			END;
			Wr(CHR(D DIV 100 + ORD("0")));   D := D MOD 100;
			Wr(CHR(D DIV 10 + ORD("0")));   Wr(CHR(D MOD 10 + ORD("0")))
		END
	END;
	str[pos] := 0X
END RealToFixStr;


PROCEDURE AppendRealFix* ( x: FLOAT64;   n, k, D: SIGNED32;   VAR dest: ARRAY OF CHAR);
	VAR s: ARRAY 64 OF CHAR;
BEGIN 	(*ASSERT((x >= MIN(FLOAT32)) & (x <= MAX(FLOAT32)), 100);
	Texts.OpenWriter(W);
	Texts.WriteRealFix(W, SHORT(x), n, k, 5); (*! support free E parameter *)
	AppendBuffer(W.buf, dest)*)
	RealToFixStr(x, s, n, k, D);
	Append(dest, s)

END AppendRealFix;

PROCEDURE AppendLongReal* (x: FLOAT64;   n: SIGNED32;   VAR dest: ARRAY OF CHAR);
	VAR s: ARRAY maxreallen OF CHAR;
BEGIN
	RealToStr(x, n, s);  Append(dest, s)
END AppendLongReal;

PROCEDURE AppendReal* (x: FLOAT32;   n: SIGNED32;   VAR  dest: ARRAY OF CHAR);
	VAR s: ARRAY maxreallen OF CHAR;
BEGIN 	 RealToStr(x, n, s);  Append(dest, s)
END AppendReal;

PROCEDURE AppendLongRealHex* ( x: FLOAT64;   VAR dest: ARRAY OF CHAR);
	VAR s: ARRAY maxreallen OF CHAR;
BEGIN
	RealToHexStr(x, s);  Append(dest, s)
END AppendLongRealHex;

PROCEDURE AppendRealHex* ( x: FLOAT64;   VAR dest: ARRAY OF CHAR);
	VAR s: ARRAY maxreallen OF CHAR;
BEGIN
	RealToHexStr(x, s);  Append(dest, s)
END AppendRealHex;



(*

PROCEDURE AppendReal* (x: FLOAT32; n: SIGNED32;VAR  dest: ARRAY OF CHAR);
VAR e: SIGNED32; x0: FLOAT32;
d: ARRAY maxD OF CHAR;pos:SIGNED32;
BEGIN pos:=Length(dest);
e := Expo(x);
IF e = 0 THEN
dest[pos]:= " "; INC(pos); dest[pos]:= "0"; INC(pos);
REPEAT dest[pos]:= " "; INC(pos); DEC(n) UNTIL n <= 3
ELSIF e = 255 THEN
Append(" NaN",dest);pos:=Length(dest);
WHILE n > 4 DO dest[pos]:= " "; INC(pos); DEC(n) END
ELSE
IF n <= 9 THEN n := 3 ELSE DEC(n, 6) END;
REPEAT dest[pos]:= " "; INC(pos); DEC(n) UNTIL n <= 8;
(*there are 2 < n <= 8 digits to be written*)
IF x < 0.0 THEN dest[pos]:= "-"; INC(pos); x := -x ELSE dest[pos]:= " "; INC(pos) END;
e := (e - 127) * 77  DIV 256;
IF e >= 0 THEN x := x / vyHost.Ten(e) ELSE x := vyHost.Ten(-e) * x END;
IF x >= 10.0 THEN x := 0.1*x; INC(e) END;
x0 := vyHost.Ten(n-1); x := x0*x + 0.5;
IF x >= 10.0*x0 THEN x := x*0.1; INC(e) END;
Reals.Convert(x, n, d);
DEC(n); dest[pos]:= d[n]; INC(pos); dest[pos]:= "."; INC(pos);
REPEAT DEC(n); dest[pos]:= d[n]; INC(pos) UNTIL n = 0;
dest[pos]:= ExpChar (*"E";*) INC(pos);
IF e < 0 THEN dest[pos]:= "-"; INC(pos); e := -e ELSE dest[pos]:= "+"; INC(pos) END;
dest[pos]:= CHR(e DIV 10 + 30H); INC(pos); dest[pos]:= CHR(e MOD 10 + 30H); INC(pos)
END;
dest[pos]:=0X;
END AppendReal;

PROCEDURE AppendRealFix* ( x: FLOAT32; n, k: SIGNED32;VAR dest:ARRAY OF CHAR);
VAR e, i: SIGNED32; sign: CHAR; x0: FLOAT32;
d: ARRAY maxD OF CHAR;pos:SIGNED32;

PROCEDURE seq (ch: CHAR; n: SIGNED32);
BEGIN WHILE n > 0 DO dest[pos]:= ch; INC(pos); DEC(n) END
END seq;

PROCEDURE dig (n: SIGNED32);
BEGIN
WHILE n > 0 DO
DEC(i); dest[pos]:= d[i]; INC(pos); DEC(n)
END
END dig;

BEGIN
i := 0; pos := 0;
e := Expo(x);
IF k < 0 THEN k := 0 END;
IF e = 0 THEN seq(" ", n-k-2); dest[pos]:= "0"; INC(pos); seq(" ", k+1)
ELSIF e = 255 THEN Append(" NaN",dest); pos:=Length(dest);seq(" ", n-4)
ELSE e := (e - 127) * 77 DIV 256;
IF x < 0 THEN sign := "-"; x := -x ELSE sign := " " END;
IF e >= 0 THEN  (*x >= 1.0,  77/256 = log 2*) x := x/vyHost.Ten(e)
ELSE (*x < 1.0*) x := vyHost.Ten(-e) * x
END;
IF x >= 10.0 THEN x := 0.1*x; INC(e) END;
(* 1 <= x < 10 *)
IF k+e >= maxD-1 THEN k := maxD-1-e
ELSIF k+e < 0 THEN k := -e; x := 0.0
END;
x0 := vyHost.Ten(k+e); x := x0*x + 0.5;
IF x >= 10.0*x0 THEN INC(e) END;
(*e = no. of digits before decimal point*)
INC(e); i := k+e; Reals.Convert(x, i, d);
IF e > 0 THEN
seq(" ", n-e-k-2); dest[pos]:= sign; INC(pos); dig(e);
dest[pos]:= "."; INC(pos); dig(k)
ELSE seq(" ", n-k-3);
dest[pos]:= sign; INC(pos); dest[pos]:= "0"; INC(pos);
dest[pos]:= "."; INC(pos);
seq("0", -e); dig(k+e)
END
END;
dest[pos]:=0X
END AppendRealFix;

PROCEDURE AppendRealHex* (x: FLOAT32;VAR dest: ARRAY OF CHAR);
VAR i: SIGNED32;
d: ARRAY 8 OF CHAR;pos:SIGNED32;
BEGIN Reals.ConvertH(x, d); i := 0; pos:=Length(dest);
REPEAT dest[pos]:= d[i]; INC(pos); INC(i) UNTIL i = 8;
dest[pos]:=0X
END AppendRealHex;

PROCEDURE AppendLongReal* (x: FLOAT64; n: SIGNED32;VAR dest: ARRAY OF CHAR);
CONST maxD = 16;
VAR e: SIGNED32; x0: FLOAT64;
d: ARRAY maxD OF CHAR;pos:SIGNED32;
BEGIN pos:=Length(dest);
e := Reals.ExpoL(x);
IF e = 0 THEN
Append("  0",dest);pos:=Length(dest);
REPEAT dest[pos]:= " "; INC(pos); DEC(n) UNTIL n <= 3
ELSIF e = 2047 THEN
Append(" NaN",dest);pos:=Length(dest);
WHILE n > 4 DO dest[pos]:= " "; INC(pos); DEC(n) END
ELSE
IF n <= 10 THEN n := 3 ELSE DEC(n, 7) END;
REPEAT dest[pos]:= " "; INC(pos); DEC(n) UNTIL n <= maxD;
(*there are 2 <= n <= maxD digits to be written*)
IF x < 0 THEN dest[pos]:= "-"; INC(pos); x := -x ELSE dest[pos]:= " "; INC(pos) END;
e := SHORT(LONG(e - 1023) * 77 DIV 256);
IF e >= 0 THEN x := x / vyHost.TenL(e) ELSE x := vyHost.TenL(-e) * x END ;
IF x >= 10.0D0 THEN x := 0.1D0 * x; INC(e) END ;
x0 := vyHost.TenL(n-1); x := x0*x + 0.5D0;
IF x >= 10.0D0*x0 THEN x := 0.1D0 * x; INC(e) END ;
Reals.ConvertL(x, n, d);
DEC(n); dest[pos]:= d[n]; INC(pos); dest[pos]:= "."; INC(pos);
REPEAT DEC(n); dest[pos]:= d[n]; INC(pos) UNTIL n = 0;
dest[pos]:= ExpChar (*"D"*); INC(pos);
IF e < 0 THEN dest[pos]:= "-"; INC(pos); e := -e ELSE dest[pos]:= "+" END;
dest[pos]:= CHR(e DIV 100 + 30H); INC(pos); e := e MOD 100;
dest[pos]:= CHR(e DIV 10 + 30H); INC(pos);
dest[pos]:= CHR(e MOD 10 + 30H); INC(pos)
END;
dest[pos]:=0X;
END AppendLongReal;

PROCEDURE AppendLongRealHex* ( x: FLOAT64;VAR dest: ARRAY OF CHAR);
VAR pos,i: SIGNED32;
d: ARRAY 16 OF CHAR;
BEGIN pos:=Length(dest);
Reals.ConvertHL(x, d); i := 0;
REPEAT dest[pos]:= d[i]; INC(pos); INC(i) UNTIL i = 16;
dest[pos]:=0X
END AppendLongRealHex;
*)

PROCEDURE AppendDate* (t, d: SIGNED32;   VAR dest: ARRAY OF CHAR);
	VAR pos: SIGNED32;

PROCEDURE AppendPair (ch: CHAR;   x: SIGNED32);
BEGIN dest[pos] := ch;   INC(pos);
	dest[pos] := CHR(x DIV 10 + 30H);   INC(pos);
	dest[pos] := CHR(x MOD 10 + 30H);   INC(pos)
END AppendPair;

BEGIN
	pos := Length(dest);
	AppendPair(" ", d MOD 32);   AppendPair(".", d DIV 32 MOD 16);   AppendPair(".", d DIV 512 MOD 128);
	AppendPair(" ", t DIV 4096 MOD 32);   AppendPair(":", t DIV 64 MOD 64);
	AppendPair(":", t MOD 64);
	dest[pos] := 0X
END AppendDate;
(*MODULE StringSearch;	(* Christoph Steindl, CS, steindl@ssw.uni-linz.ac.at, 2. May 95 *)
*)
PROCEDURE BruteSearch* (VAR s: ARRAY OF CHAR;   VAR pat: ARRAY OF CHAR): SIGNED32;
	(** Returns the position of the first ocurrence of pat in s.
	Time: worst case: O(strlen(s) * strlen(pat)	average: O(strlen(s) + strlen(pat)
	Comparisons: average: strlen(s) * strlen(pat) *)
	(* modified to return -1 if not found *)
	VAR i, j, M, N: SIGNED32;
BEGIN
	j := 0;   M := 0;   WHILE pat[M] # 0X DO INC(M) END;
	i := 0;   N := 0;   WHILE s[N] # 0X DO INC(N) END;
	WHILE (j < M) & (i < N) DO
		IF s[i] # pat[j] THEN DEC(i, j - 1);   j := - 1 END;
		INC(i);   INC(j)
	END;
	IF j = M THEN RETURN i - M ELSE RETURN - 1 END
END BruteSearch;

PROCEDURE KMPSearch* (VAR s: ARRAY OF CHAR;   VAR pat: ARRAY OF CHAR): SIGNED32;
	(** Knuth-Morris-Pratt-Search
	Comparisons: worst case: strlen(s) * strlen(pat) *)
	(* modified to return -1 if not found gs.*)

	VAR i, j, M, N: SIGNED32;   next: ARRAY 256 OF SIGNED32;
PROCEDURE InitNext;
	VAR i, j: SIGNED32;
BEGIN
	next[0] := - 1;   i := 0;   j := - 1;
	WHILE i < M DO
		WHILE (j >= 0) & (pat[i] # pat[j]) DO j := next[j] END;
		INC(i);   INC(j);
		IF pat[i] = pat[j] THEN next[i] := next[j] ELSE next[i] := j END
	END
END InitNext;
BEGIN
	j := 0;   M := 0;   WHILE pat[M] # 0X DO INC(M) END;
	i := 0;   N := 0;   WHILE s[N] # 0X DO INC(N) END;
	InitNext;
	WHILE (j < M) & (i < N) DO
		WHILE (j >= 0) & (s[i] # pat[j]) DO j := next[j] END;
		INC(i);   INC(j)
	END;
	IF j = M THEN RETURN i - M ELSE RETURN - 1 END
END KMPSearch;

PROCEDURE BMSearch* (VAR s: ARRAY OF CHAR;   VAR pat: ARRAY OF CHAR): SIGNED32;
	(*= Boyer-Moore-Search*)
	(* modified to return -1 if not found gs.*)

	VAR i, j, t, M, N: SIGNED32;   skip: ARRAY 256 OF SIGNED32;
PROCEDURE InitSkip;
	VAR i, j: SIGNED32;
BEGIN
	FOR i := 0 TO 255 DO skip[i] := M END;
	FOR j := 0 TO M - 1 DO skip[ORD(pat[j])] := M - j - 1 END
END InitSkip;
BEGIN
	M := 0;   WHILE pat[M] # 0X DO INC(M) END;
	N := 0;   WHILE s[N] # 0X DO INC(N) END;
	InitSkip;   i := M - 1;   j := M - 1;
	WHILE j > 0 DO
		WHILE s[i] # pat[j] DO
			t := skip[ORD(s[i])];
			IF (M - j) > t THEN INC(i, M - j) ELSE INC(i, t) END;
			IF i >= N THEN RETURN - 1 END;
			j := M - 1
		END;
		DEC(i);   DEC(j)
	END;
	RETURN i
END BMSearch;

PROCEDURE RKSearch* (VAR s: ARRAY OF CHAR;   VAR pat: ARRAY OF CHAR): SIGNED32;
	(*= Robin-Karp-Search
	Time: average linear*)
	(* modified to return -1 if not found gs.*)

CONST q = 33554393;
	d = 32;
	VAR dM, h1, h2: SIGNED32;   i, M, N: SIGNED32;
BEGIN
	M := 0;   WHILE pat[M] # 0X DO INC(M) END;
	N := 0;   WHILE s[N] # 0X DO INC(N) END;
	dM := 1;   h1 := 0;   h2 := 0;
	FOR i := 1 TO M - 1 DO dM := (d * dM) MOD q END;
	FOR i := 0 TO M - 1 DO
		h1 := (h1 * d + ORD(pat[i])) MOD q;
		h2 := (h2 * d + ORD(s[i])) MOD q
	END;
	i := 0;
	WHILE h1 # h2 DO
		h2 := (h2 + d * q - ORD(s[i]) * dM) MOD q;
		h2 := (h2 * d + ORD(s[i + M])) MOD q;
		IF i > N - M THEN RETURN - 1 END;
		INC(i)
	END;
	RETURN i
END RKSearch;

PROCEDURE SeqName* (stub: ARRAY OF CHAR;  sep: CHAR;  seqnr: SIGNED32;  VAR res: ARRAY OF CHAR);
CONST cseqlen = 4;
	VAR i: SIGNED16;
BEGIN
	ASSERT(LEN(stub) + 1 + cseqlen < LEN(res), 100);
	ASSERT((seqnr < 10000) & (seqnr >= 0), 101);
	i := 0;   WHILE stub[i] # 0X DO res[i] := stub[i];   INC(i) END;
	res[i] := sep;   INC(i);
	res[i + 4] := 0X;
	res[i + 3] := CHR((seqnr MOD 10) + 30H);   seqnr := seqnr DIV 10;
	res[i + 2] := CHR((seqnr MOD 10) + 30H);   seqnr := seqnr DIV 10;
	res[i + 1] := CHR((seqnr MOD 10) + 30H);   seqnr := seqnr DIV 10;
	res[i] := CHR((seqnr MOD 10) + 30H)
END SeqName;

PROCEDURE NameToSeq* (name: ARRAY OF CHAR;   sep: CHAR;  VAR stub: ARRAY OF CHAR;  VAR seqnr: SIGNED32);
	VAR i: SIGNED16;  (*xname:ARRAY 32 OF CHAR;  xch:CHAR; *)
BEGIN
	(*	COPY(name,xname); *)
	seqnr := 0;
	i := 0;
	WHILE (name[i] # sep) & (name[i] # 0X) DO
		stub[i] := name[i];   INC(i)
	END;
	stub[i] := 0X;
	IF name[i] = 0X THEN RETURN END;
	INC(i);  (*delim*)
	WHILE  name[i] # 0X DO (*xch:=name[i]; *)
		ASSERT(('0' <= name[i]) & ('9' >= name[i]), 100);
		seqnr := seqnr * 10 + ORD(name[i]) - 30H;   INC(i)
	END
END NameToSeq;

(*END StringSearch.*)
BEGIN
	TenM1 := Reals.Ten( - 1);
	Ten7 := Reals.Ten(7);
	Ten8 := Reals.Ten(8);
	HexDig := '0123456789ABCDEF'
END vyHostStrings.
