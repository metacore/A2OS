MODULE vyScanners IN Oberon;
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



(* Test examples in :vy:vyScanners.Test.Mod
System.Free vyScanners* *)

(* Generic scanner
Based on Mess 0.1
(C) G. Sawitzki, StatLab Heidelberg 1995 <gs@statlab.uni-heidelberg.de>
To save compilation time, additional information is placed at the end of this file.
*)
(*! Check naming. Get ? Next ? *)
(*! Support Get for basic classes, including signed numbers *)
(*! Saveguard channel switching against multiple invocation *)
(*! Check reading of strings, EOT handling *)
(*! Support string input. All Oberon qualidents which are no names should be entered as string *)
IMPORT Texts, vyBase, vyHost;
CONST	(*cDebug=FALSE;*)	idversion* = "vyScanner 0.0a2-1";
	TAB = 9X;  		CR = 0DX;  	SPACE = 20X; 	EOT = 0X;
	(*ELEM=vyHost.TextElemCode;*)
	maxNameLen = 256; 	maxReserved = 65;

	(* character classes. see Get for interpretation  *)
	ccAny = -1;
	ccNOOP = 0;
	ccDigit = 1;  		(* start of a number *)
	ccAlpha = 2; 		(* start of identifier, but not reserved *)
	ccString = 3;
	(*	ccChar=4;	*)	(* C char constants *)
	ccResStart = 5;  	(* Start of a reserved word or identifier *)
	ccResSym = 6; 	(* Start of reserved symbol - no identifier *)
	ccEOT = 7;
	ccCR = 8;
	ccComment = 9;

	(** token classes *)
	ctStuff* = -1; 		(* unknown or undefined *)
	ctEOT* = 0;
	ctId* = 1;
	ctString* = 2;
	ctSym* = 3;
	(* *)	(* variant is from csXxxxx *)
	ctNumber* = 4; 	(*= unsigned *)
	ctReal* = 5;  		(*= unsigned, float *)
	ctFixed* = 6; 		(*= unsigned, fixed *)
	ctNL* = 7;
	ctComment* = 8;

	(** symbols *)
	(*=These symbols are aligned with Mess. not all are used in Voyager. *)
	(* jb, 5.11.01 - csColon, csDot exported *)
	csAny* = -1;
	csnull = 0; 		csStar* = 1; 		csSlash* = 2; 		csDIV = 3; 		csMOD = 4;
	csAnd = 5; 		csPlus* = 6; 		csMinus* = 7; 	csOR = 8; 		csEq* = 9;
	csNEq = 10; 		csLess* = 11; 		csLessT = 12; 	csGreat* = 13; 	csGreatT = 14;
	csIN = 15; 		csIS = 16; 		csArrow = 17; 	csDot* = 18; 		csComma = 19;
	csColon* = 20; 	csDotDot = 21; 	csRBrac = 22; 	csRBrac1 = 23; 	csRBrace = 24;
	csOF = 25; 		csTHEN = 26; 	csDO = 27; 		csTO = 28; 		csLBrac = 29;
	csLBrac1 = 30; 	csLBrace = 31; 	csNot = 32; 		csAssign = 33; 	csNumber = 34;
	csNIL = 35; 		csString = 36; 	csIdent = 37; 	csSemic = 38;
	csEND = 40;  	csELSE = 41; 	csELSIF = 42;  	sUNTIL = 43; 	csIF = 44;
	csCASE = 45; 	csWHILE = 46; 	csREPEAT = 47; 	csLOOP = 48; 	csWITH = 49;
	csEXIT = 50; 		csRETURN = 51; 	csARRAY = 52; 	csRECORD = 53; 	csPOINTER = 54;
	csBEGIN = 55; 	csCONST = 56; 	csTYPE = 57; 	csVAR = 58;
	csPROCEDURE = 59;
	csIMPORT = 60; 	csMODULE = 61;
	csFOR = 62; 	cseof = 63;  csAt = 64;
	csExclam = 70; csTicTic = 71; csDollar = 72; csPercent = 73; csTic = 74; csQuestion = 75;
	csBackslash = 76;
TYPE
	tName = ARRAY maxNameLen OF CHAR;
	tChTable = ARRAY 256 OF SHORTINT;
	tReserved = POINTER TO tReservedTable;
	tReservedTable = ARRAY maxReserved OF tName;

	Scanner* = POINTER TO ScannerDesc;  (*= input redirection may switch scanner - always use as VAR parameter *)
	tGetNext = PROCEDURE (VAR sc: Scanner): INTEGER;
	tSwitch = PROCEDURE (VAR sc: Scanner);

	ScannerDesc* = RECORD (Texts.Reader)
		(* public information *)
		class*: INTEGER; 			(*= current token class. From token class *)
		v*: INTEGER; 				(*= current token variant. Class dependent *)
		(* hooks to allow modification. These procedures are called by the scanner. *)
		Switcher*: tSwitch; 			(*= Switch scanner input stream *)
		GetNext*: tGetNext; 			(*= Get next token into scanner.
		Set class and variant, return class.
		Call switcher, if necessary.
		Do not proceed beyond EO.  *)
		(* internal information *)
		text-: Texts.Text; 				(* the text we operate on *)
		ch-, chnext: CHAR; 			(* characters to scan next *)
		chpos-, chnextpos: LONGINT;
		end: LONGINT;
		Start, Stop: tChTable;
		prevScanner: Scanner; 			(* switch back if stream is exhausted *)
		curTokid: tName;
		curTokPos-, curTokLen-: LONGINT;
		trailpos, traillen: LONGINT; 	(* trailing white space *)
		TokDelLPos, TokDelLLen, TokDelRPos, TokDelRLen: LONGINT;  (* for strings & comments. For fixed: Pre,PreLen,Dec,DecLe *)
		minusExp: BOOLEAN; 	(* For class Real only *)
		ExpPos, ExpLen: LONGINT; 	(* For class Real only *)
		tabcount: LONGINT; 	(* nr tabs in trailing white space *)
		(*		token:tToken;*)
	END;

VAR
	DefaultStart, DefaultStop: tChTable;
	(** Debugging support - will be removed later *)
PROCEDURE Dump* (VAR w: vyBase.TextsWriter;  s: Scanner);
PROCEDURE wln; BEGIN Texts.WriteLn(w)  END wln;
PROCEDURE ws (st: ARRAY OF CHAR); BEGIN Texts.WriteString(w, st)  END ws;
PROCEDURE wsi (st: ARRAY OF CHAR; i: LONGINT); BEGIN ws(st); Texts.Write(w, ' ');
Texts.WriteInt(w, i, 0)  END wsi;
PROCEDURE wsc (st: ARRAY OF CHAR; c: CHAR);
BEGIN ws(st); Texts.Write(w, " ");  Texts.Write(w, c) END wsc;

BEGIN
	IF s = NIL THEN ws("-- DUMP Scanner is NIL")
	ELSE
		wsi('--DUMP Scanner till', s.end);
		IF s.eot THEN ws(' EOT is set.') END;  wln;
		ws("current token:"); ws(s.curTokid); wsi(" at pos", s.curTokPos);
		wsi(" len:", s.curTokLen); wsi(" class:", s.class);
		wsi(" variant:", s.v); wln; 			(* Token variant, by class *)
		wsi("trailpos:", s.trailpos);
		wsi(" traillen:", s.traillen); wln; 	(* trailing white space *)
		wsi("TokDelLPos:", s.TokDelLPos);
		wsi(" TokDelLLen:", s.TokDelLLen);
		wsi(" TokDelRPos:", s.TokDelRPos);
		wsi(" TokDelRLen:", s.TokDelRLen); wln;

		IF s.class = ctReal THEN
			IF s.minusExp THEN wsc("Exp ", "-") END;
			wsi(" ExpPos:", s.ExpPos); 	wsi(" ExpLen:", s.ExpLen); wln
		END;
		wsi("tabcount:", s.tabcount); wln; 	(* nr tabs in trailing white space *)
		wsc("char ", s.ch); wsi(" at pos", s.chpos); 		wsc(" next ", s.chnext); wsi(" at pos", s.chnextpos); 		wsi(" end:", s.end); wln
	END
END Dump;

(** core character read routine for DefaultGetNext *)
PROCEDURE Ch* (VAR sc: Scanner);
BEGIN	sc.ch := sc.chnext; sc.chpos := sc.chnextpos;
	IF  (~sc.eot) & (Texts.Pos(sc^) < sc.end) THEN
		sc.chnextpos := Texts.Pos(sc^);
		Texts.Read(sc^, sc.chnext)
	ELSE sc.chnext := EOT; sc.chnextpos := Texts.Pos(sc^)
	END
END Ch;

(** internal get routines, by type *)
PROCEDURE getName (VAR sc: Scanner; pos: LONGINT;  len: INTEGER;  VAR s: ARRAY OF CHAR): BOOLEAN;
	VAR i: INTEGER;  r: Texts.Reader; temp: BOOLEAN;
BEGIN
	Texts.OpenReader(r, sc.text, pos);
	IF len >= LEN(s) THEN len := SHORT(LEN(s)) - 1;  temp := FALSE
	ELSE temp := TRUE END;
	i := 0;  WHILE i < len DO Texts.Read(r, s[i]);  INC(i) END;
	s[i] := 0X;
	RETURN temp
END getName;

PROCEDURE getNumber (VAR sc: Scanner; pos: LONGINT;  len: INTEGER;
neg: BOOLEAN; VAR x: LONGINT): BOOLEAN;
	VAR i: INTEGER;  r: Texts.Reader;  res: BOOLEAN; c: CHAR;
BEGIN
	(*! add error check and perform proper test *)
	Texts.OpenReader(r, sc.text, pos);
	x := 0; res := TRUE;
	i := 0;  WHILE i < len DO Texts.Read(r, c);  INC(i);
		IF ("0" <= c) & (c <= "9") THEN x := x * 10 + (ORD(c) - 30H); 	ASSERT(x >= 0, 101)
		ELSE res := FALSE;  i := len  END
	END;  (* WHILE *)
	IF neg THEN x := - x  END;
	RETURN res
END getNumber;


PROCEDURE getReal (VAR sc: Scanner; pos: LONGINT;  len: INTEGER;
neg: BOOLEAN; VAR x: REAL): BOOLEAN;
	VAR i: INTEGER;  r: Texts.Reader;  more, okSoFar, negex: BOOLEAN; c: CHAR; pre, post, exp, pow: LONGINT;
	(*	xx:ARRAY 2 OF CHAR; *)
BEGIN	Texts.OpenReader(r, sc.text, pos);
	x := 0; okSoFar := TRUE; pre := 0; post := 0; exp := 0;  more := TRUE; pow := 1; negex := FALSE;
	(*vyHostTexts.MsgSISI('GetReal* scan from pos ',pos,'for len ',len);*)
	(* pre *)
	i := 0;  WHILE (i < len) & more DO Texts.Read(r, c);  INC(i);
		IF ("0" <= c) & (c <= "9") THEN pre := pre * 10 + (ORD(c) - 30H); 	ASSERT(pre >= 0, 101)
		ELSE more := FALSE;    okSoFar := (c = ".")
		END
	END; (* WHILE *)
	(* IF okSoFar THEN vyHostTexts.MsgSI('pre:',pre) ELSE vyHostTexts.MsgSI('~pre:',pre) END; *)
	(* post *)
	IF okSoFar THEN
		more := TRUE; WHILE (i < len) & more DO Texts.Read(r, c);  INC(i);
			IF ("0" <= c) & (c <= "9") THEN
								IF post < MAX(LONGINT)/100 THEN
				post := post * 10 + (ORD(c) - 30H); pow := pow * 10;
				END;
ASSERT(post >= 0, 102); ASSERT(pow >= 0, 103)  (* catch overflow *)
			ELSE more := FALSE;   okSoFar := ( (c = "E") OR (c="D") OR (c="e"))  END
		END (* WHILE *)
	END;
	(* IF okSoFar THEN vyHostTexts.MsgSI('post:',post) ELSE vyHostTexts.MsgSI('~post:',post) END;
	vyHostTexts.MsgSI('pow',pow);*)

	(* exponent *)
	IF okSoFar THEN
		more := TRUE;  IF (i < len) THEN Texts.Read(r, c);  INC(i);  negex := ( c = "-");
			IF (c = "+") OR (c = "-") THEN
				IF (i < len) THEN Texts.Read(r, c);  INC(i) ELSE okSoFar := FALSE END (* at least one digit is needed *)
			END;  (*(c='+') OR (c='-') *)
			IF ("0" <= c) & (c <= "9") THEN exp := (ORD(c) - 30H) ELSE okSoFar := FALSE  END;
			(* IF okSoFar THEN vyHostTexts.Msg('passed 1') ELSE vyHostTexts.Msg('~passed 1') END; *)

			IF okSoFar THEN
				WHILE (i < len) & more DO Texts.Read(r, c);  INC(i);
					(* vyHostTexts.MsgSI('char ',ORD(c)); *)
					IF ("0" <= c) & (c <= "9") THEN exp := exp * 10 + (ORD(c) - 30H); 	ASSERT(exp >= 0, 101)
					ELSE  okSoFar := FALSE END
				END (* WHILE *)
			END
		END;  (* exponent*)

		(*	 IF okSoFar THEN vyHostTexts.MsgSI('exp:',exp) ELSE vyHostTexts.MsgSI('~exp:',exp) END; *)
		IF okSoFar THEN x := (pre + (post / pow) ) END;
		IF okSoFar THEN IF negex THEN x := SHORT(x / vyHost.TenL(SHORT(exp)))
			ELSE  x := SHORT(x * vyHost.TenL(SHORT(exp))) END  END; (*okSoFar*)END;
		(*! handle/note real underflow or overflow *)
		IF neg THEN x := - x  END;  (* gs 29.3.96 *)
		RETURN okSoFar;  (*! dummy *)
	END getReal;

PROCEDURE GetName* (VAR sc: Scanner; VAR s: ARRAY OF CHAR): BOOLEAN;
BEGIN RETURN getName(sc, sc.curTokPos, SHORT(sc.curTokLen), s)
END GetName;

PROCEDURE GetNumber* (VAR sc: Scanner; neg: BOOLEAN; VAR x: LONGINT): BOOLEAN;
BEGIN	RETURN getNumber(sc, sc.curTokPos, SHORT(sc.curTokLen), neg, x)
END GetNumber;

PROCEDURE GetReal* (VAR sc: Scanner; neg: BOOLEAN; VAR x: REAL): BOOLEAN;
BEGIN	RETURN getReal(sc, sc.curTokPos, SHORT(sc.curTokLen), neg, x)
END GetReal;

PROCEDURE ExpectName* (VAR sc: Scanner; VAR s: ARRAY OF CHAR): BOOLEAN;  VAR c: INTEGER;
BEGIN c := sc.GetNext(sc);
	IF (c = ctId) THEN
		RETURN getName(sc, sc.curTokPos, SHORT(sc.curTokLen), s)
	ELSE RETURN FALSE END
END ExpectName;

PROCEDURE ExpectNumber* (VAR sc: Scanner; VAR x: LONGINT): BOOLEAN;  VAR c: INTEGER;  sign: BOOLEAN;
BEGIN 	c := sc.GetNext(sc);
	IF (c = ctSym) & (sc.v = csMinus) & ('0' <= sc.ch) & ('9' >= sc.ch)
	THEN sign := TRUE;  c := sc.GetNext(sc) ELSE sign := FALSE END;
	IF (c = ctNumber) THEN
		RETURN getNumber(sc, sc.curTokPos, SHORT(sc.curTokLen), sign, x)
	ELSE RETURN FALSE END
END ExpectNumber;

PROCEDURE ExpectReal* (VAR sc: Scanner; VAR x: REAL): BOOLEAN;
	VAR c: INTEGER; sign, b: BOOLEAN;  i: LONGINT;
BEGIN 	c := sc.GetNext(sc);
	IF (c = ctSym) & (sc.v = csMinus) & ('0' <= sc.ch) & ('9' >= sc.ch)
	THEN sign := TRUE;  c := sc.GetNext(sc) ELSE sign := FALSE END;
	IF (c = ctFixed) OR (c = ctReal) THEN
		RETURN getReal(sc, sc.curTokPos, SHORT(sc.curTokLen), sign, x)
	ELSIF (c = ctNumber) THEN b := GetNumber(sc, sign, i);  x := i;  RETURN b
	ELSE RETURN FALSE END
END ExpectReal;

PROCEDURE AddReserved
 (n: ARRAY OF CHAR; tok: INTEGER;  R: tReserved; VAR t: tChTable);
BEGIN	IF R # NIL THEN COPY(n, R[tok]) END;
	t[ORD(n[0])] := ccResStart
END AddReserved;

PROCEDURE AddReservedSym
 (n: ARRAY OF CHAR; tok: INTEGER;  R: tReserved; VAR t: tChTable);
BEGIN	IF R # NIL THEN COPY(n, R[tok]) END;
	t[ORD(n[0])] := ccResSym
END AddReservedSym;

PROCEDURE SetupDefaults;
	VAR i: INTEGER;
BEGIN
	FOR i := 0 TO 255 DO DefaultStart[i] := ccNOOP END; (* default *)
	FOR i := ORD("A") TO ORD("Z") DO DefaultStart[i] := ccAlpha END;
	FOR i := ORD("a") TO ORD("z") DO DefaultStart[i] := ccAlpha END;
	DefaultStart[ORD(CR)] := ccCR;
	DefaultStart[ORD(EOT)] := ccEOT;
	DefaultStart[ORD("(")] := ccComment;
	FOR i := ORD("0") TO ORD("9") DO DefaultStart[i] := ccDigit END;
	AddReservedSym("!", csExclam, NIL, DefaultStart);
	AddReservedSym('"', csTicTic, NIL, DefaultStart);
	AddReservedSym('#', csNot, NIL, DefaultStart);
	AddReservedSym('$', csDollar, NIL, DefaultStart);
	AddReservedSym('%', csPercent, NIL, DefaultStart);
	AddReservedSym('&', csAnd, NIL, DefaultStart);
	AddReservedSym("'", csTic, NIL, DefaultStart);
	(* AddReservedSym("(", csLBrac, NIL, DefaultStart); *)
	AddReservedSym(")", csRBrac, NIL, DefaultStart);
	AddReservedSym("[", csLBrac1, NIL, DefaultStart);
	AddReservedSym("]", csRBrac1, NIL, DefaultStart);
	AddReservedSym("*", csStar, NIL, DefaultStart);
	AddReservedSym("+", csPlus, NIL, DefaultStart);
	AddReservedSym(",", csComma, NIL, DefaultStart);
	AddReservedSym("-", csMinus, NIL, DefaultStart);
	AddReservedSym(".", csDot, NIL, DefaultStart);
	AddReservedSym("/", csSlash, NIL, DefaultStart);
	AddReservedSym(";", csSemic, NIL, DefaultStart);  	(* jb 20.8.01 - ; instead of : *)
	AddReservedSym(":", csColon, NIL, DefaultStart); 	(* jb 20.8.01 *)
	AddReservedSym("<", csLess, NIL, DefaultStart);
	AddReservedSym("=", csEq, NIL, DefaultStart);
	AddReservedSym(">", csGreat, NIL, DefaultStart);
	AddReservedSym("?", csQuestion, NIL, DefaultStart);
	AddReservedSym("@", csAt, NIL, DefaultStart);
	AddReservedSym("\", csBackslash, NIL, DefaultStart);


	AddReservedSym("^", csArrow, NIL, DefaultStart);
	AddReservedSym("~", csNot, NIL, DefaultStart);
	AddReservedSym("|", csOR, NIL, DefaultStart);
	FOR i := 0 TO 255 DO DefaultStop[i] := ccAny END; (* default *)
	FOR i := ORD("A") TO ORD("Z") DO DefaultStop[i] := ccNOOP END;
	FOR i := ORD("a") TO ORD("z") DO DefaultStop[i] := ccNOOP END;
	FOR i := ORD("0") TO ORD("9") DO DefaultStop[i] := ccNOOP END

END SetupDefaults;

PROCEDURE GetCurTok (VAR sc: Scanner);
	VAR i: INTEGER;
BEGIN	i := 0;  sc.curTokid[i] := sc.ch; INC(i); 	sc.curTokPos := sc.chpos;
	WHILE (sc.ch # 0X) & (sc.Stop[ORD(sc.ch)] = ccNOOP) & (i<maxNameLen) DO
		Ch(sc); sc.curTokid[i] := sc.ch; INC(i);
	END;
	sc.curTokid[i - 1] := 0X; 	sc.curTokLen := sc.chpos - sc.curTokPos
END GetCurTok;

(* Token separators. Consume all chars of token, set at least curtokpos and cutoklen *)
PROCEDURE OneCh (VAR sc: Scanner);
BEGIN	sc.curTokPos := sc.chpos; 	sc.curTokLen := 1;  Ch(sc)
END OneCh;

PROCEDURE TwoCh (VAR sc: Scanner);
BEGIN	sc.curTokPos := sc.chpos; 	sc.curTokLen := 2;  Ch(sc); Ch(sc)
END TwoCh;

PROCEDURE Id (VAR sc: Scanner);
BEGIN	GetCurTok(sc)
END Id;

PROCEDURE String (VAR sc: Scanner);
	(* Start on Del. Terminated by next char and step over; does not exceed EOL or EOT *)
	VAR del: CHAR;
BEGIN	sc.TokDelLPos := sc.chpos; sc.TokDelLLen := 1; del := sc.ch; Ch(sc);
	sc.curTokPos := sc.chpos;
	WHILE (sc.ch # 0X) & (sc.ch # del) & (sc.ch # CR) DO  Ch(sc)  END;
	sc.TokDelRPos := sc.chpos; sc.TokDelRLen := 1;
	sc.curTokLen := sc.chpos -
	sc.curTokPos;
	IF (sc.ch = CR) OR  (sc.ch = 0X) THEN (*OString("pos");OInt(TokDelLPos);
		OString(" String not closed.");OLn;*)
	ELSE (*Ch(sc)*)
	END
END String;

PROCEDURE Number (VAR sc: Scanner);
BEGIN
	sc.curTokPos := sc.chpos;
	REPEAT Ch(sc)  UNTIL (sc.ch < "0") OR (sc.ch > "9");
	sc.curTokLen := sc.chpos - sc.curTokPos;
	sc.TokDelLPos := sc.curTokPos; sc.TokDelLLen := sc.curTokLen
END Number;

PROCEDURE Fixed (VAR sc: Scanner);
BEGIN
	Number(sc);
	IF (sc.ch = ".") & ((sc.chnext >= "0") & (sc.chnext <= "9"))
		THEN sc.TokDelRPos := sc.chnextpos; 	REPEAT Ch(sc)  UNTIL (sc.ch < "0") OR (sc.ch > "9");
		sc.class := ctFixed; 	sc.curTokLen := sc.chpos - sc.curTokPos;
		sc.TokDelRLen := sc.chpos - sc.TokDelRPos
	END
END Fixed;

PROCEDURE Real (VAR sc: Scanner);
	VAR oldpos: LONGINT;
BEGIN
	Fixed(sc);
	IF (sc.ch = "E") OR  (sc.ch = "D") OR (sc.ch = "e") THEN
		oldpos := sc.chpos; sc.minusExp := (sc.chnext <= "-");
		IF ((sc.chnext = "+") OR (sc.chnext <= "-")) THEN Ch(sc);
			IF (sc.chnext < "0") OR (sc.chnext > "9") THEN (* FALL BACK *)
			Texts.OpenReader(sc^, sc.text, oldpos); Ch(sc); Ch(sc);  RETURN END
		END;
		sc.ExpPos := sc.chnextpos;
		REPEAT Ch(sc)  UNTIL (sc.ch < "0") OR (sc.ch > "9");
		sc.class := ctReal; 	sc.curTokLen := sc.chpos - sc.curTokPos;
		sc.ExpLen := sc.chpos - sc.ExpPos
	END
END Real;

PROCEDURE NL (VAR sc: Scanner);
BEGIN	OneCh(sc)
END NL;

PROCEDURE IsSym (VAR sc: Scanner): BOOLEAN;
BEGIN
	CASE sc.ch OF
		"*": 	sc.v := csStar;  OneCh(sc);
	| "^": 	sc.v := csArrow;  OneCh(sc);
	| "@": 	sc.v := csAt;  OneCh(sc);
	| "+": 	sc.v := csPlus;  OneCh(sc);
	| "-": 	sc.v := csMinus;  OneCh(sc);
	| ".": 	IF sc.chnext = "."THEN sc.v := csDotDot;  TwoCh(sc)
		ELSE sc.v := csDot; OneCh(sc)
		END;
	| ":": 	sc.v := csColon;  OneCh(sc) 	(* jb 20.8.01 *)
	ELSE
		sc.v := csAny; OneCh(sc)
	END;
	RETURN (sc.v # csAny)
END IsSym;

PROCEDURE Sym (VAR sc: Scanner);
BEGIN	IF ~IsSym(sc) THEN sc.v := csAny	END
END Sym;

PROCEDURE IsComment (VAR sc: Scanner): BOOLEAN;
	VAR commentlevel: INTEGER;
BEGIN

		IF  (sc.chnext = "*") THEN
		commentlevel := 1; sc.curTokPos := sc.chnextpos + 1;
		sc.TokDelLPos := sc.chpos; sc.TokDelLLen := 2; Ch(sc);
		REPEAT Ch(sc);
			IF (sc.ch = "(") & (sc.chnext = "*") THEN INC(commentlevel); Ch(sc)
			ELSIF
				(sc.ch = "*") & (sc.chnext = ")")THEN DEC(commentlevel); Ch(sc)
			END
		UNTIL (commentlevel = 0) OR (sc.ch = 0X);
		IF commentlevel = 0 THEN sc.curTokLen := sc.chpos - sc.curTokPos - 1;
			sc.TokDelRPos := sc.chpos - 1; sc.TokDelRLen := 2
		ELSE
			sc.curTokLen := sc.chpos - sc.curTokPos; sc.TokDelRPos := sc.chpos; sc.TokDelRLen := 0
		END;
		Ch(sc); (* remove last char *)
		RETURN TRUE
	ELSE
		RETURN FALSE
	END
END IsComment;

PROCEDURE IsReserved (VAR sc: Scanner): BOOLEAN;
BEGIN
	RETURN FALSE
END IsReserved;

PROCEDURE StopGet(VAR sc: Scanner): INTEGER;
BEGIN
	sc.eot := TRUE; sc.class := ctEOT; sc.chnext := EOT;
	RETURN ctEOT;
END StopGet;


PROCEDURE DefaultGetNext (VAR sc: Scanner): INTEGER;
	(*= Scan in next token and return token class *)
	VAR StartClass: INTEGER;
	lastpos: LONGINT;
BEGIN
	sc.class := ctStuff; lastpos := sc.chpos; sc.curTokid[0] := 0X;
	LOOP (* while sc.class=ctStuff *)
		WHILE (sc.ch # 0X) & (sc.Start[ORD(sc.ch)] = ccNOOP) DO  Ch(sc) END;
		StartClass := sc.Start[ORD(sc.ch)];
		CASE StartClass OF
			ccAny:  Ch(sc);  (*! stuff, for now *)
		|	ccAlpha:  sc.class := ctId; 	Id(sc);
		|	ccDigit:   sc.class := ctNumber; 	Real(sc);
		|	ccString: sc.class := ctString; 	String(sc);
		|	ccResStart: 	Id(sc);
			IF IsReserved(sc) THEN sc.class := ctSym
			ELSE sc.class := ctId END;
		|	ccResSym:  sc.class := ctSym; 	Sym(sc);
			IF sc.Switcher # NIL THEN
				CASE sc.v OF
					csArrow, csAt, csStar: sc.Switcher(sc);
					RETURN sc.GetNext(sc)
				ELSE
				END  (* CASE*)
			END;
		|	ccEOT: sc.class := ctEOT;
			IF sc.prevScanner # NIL THEN
				(* release old scanner *)
			sc := sc.prevScanner;  RETURN sc.GetNext(sc)  END ;

		|	ccCR: sc.class := ctNL;  NL(sc);
		|	ccComment:  IF IsComment(sc) THEN sc.class := ctComment
			ELSIF IsSym(sc) THEN sc.class := ctSym ELSE sc.class := ctStuff END
		END;  (* CASE *)
		ASSERT((sc.chpos # lastpos) OR (sc.class = ctEOT)); (*! failed for one char selection*)lastpos := sc.chpos;
		(*IF sc.class#ctStuff THEN*)RETURN sc.class (* END*);
	END  (* LOOP *)
END DefaultGetNext;

PROCEDURE NewScanner* (VAR sc: Scanner);
BEGIN
	NEW(sc);
	IF sc # NIL THEN
		sc.Start := DefaultStart;  sc.Stop := DefaultStop;
		sc.prevScanner := NIL;
		sc.Switcher := NIL
	END
END NewScanner;

PROCEDURE OpenScanner* (VAR sc: Scanner;  t: Texts.Text; beg, end: LONGINT);
BEGIN
	IF t = NIL THEN sc := NIL;  RETURN END;
	sc.end := end; sc.chnext := EOT;  sc.chnextpos := 0; 	sc.text := t;
	sc.GetNext := DefaultGetNext;
	Texts.OpenReader(sc^, t, beg);
	Ch(sc); (* load chnext *)
	Ch(sc)
END OpenScanner;

PROCEDURE OpenParScanner* (VAR sc: Scanner);
	VAR selbeg: LONGINT;  text: Texts.Text;
BEGIN
	vyHost.GetParText(text, selbeg);
	OpenScanner(sc, text, selbeg, MAX(LONGINT))
END OpenParScanner;

PROCEDURE OpenSelScanner* (VAR sc: Scanner);
	VAR selbeg, selend: LONGINT;  text: Texts.Text;
BEGIN
	vyHost.GetSelectionText(text, selbeg, selend);
	OpenScanner(sc, text, selbeg, selend)
END OpenSelScanner;

PROCEDURE OpenSelXScanner* (VAR sc: Scanner);
	VAR selbeg, selend: LONGINT;  text: Texts.Text;
BEGIN
	vyHost.GetSelectionText(text, selbeg, selend);
	OpenScanner(sc, text, selbeg, MAX(LONGINT))
END OpenSelXScanner;

PROCEDURE OpenMarkedScanner* (VAR sc: Scanner);
	VAR text: Texts.Text;
BEGIN
	vyHost.GetMarkedText(text);
	OpenScanner(sc, text, 0, MAX(LONGINT))
END OpenMarkedScanner;

PROCEDURE OpenNamedScanner* (VAR sc: Scanner; name: ARRAY OF CHAR);
	VAR text: Texts.Text;
BEGIN
	vyHost.GetNamedText(name, text);
	OpenScanner(sc, text, 0, MAX(LONGINT))
END OpenNamedScanner;

PROCEDURE NextToken* (VAR sc: Scanner): INTEGER;
	(*= scan; return token class *)
BEGIN
	sc.class := sc.GetNext(sc);
	sc.trailpos := sc.chpos; sc.tabcount := 0;
	WHILE (sc.ch = SPACE) OR (sc.ch = TAB) DO IF (sc.ch = TAB) THEN INC(sc.tabcount) END;  Ch(sc) END;
	sc.traillen := sc.chpos - sc.trailpos;
	RETURN sc.class
END NextToken;

PROCEDURE SuperSwitch (VAR sc: Scanner);
(*= Get all Characters,  upon @, insert switch stream until end of selection
upon * insert switch to marked viewer
upon  ^, switch permanent  *)
(*! needs strict testing *)
VAR scnew: Scanner; dummy: INTEGER;
BEGIN
	CASE sc.v OF
		csArrow: NewScanner(scnew); OpenSelXScanner(scnew);  IF scnew # NIL THEN sc := scnew END;   (* fof 0103xx *)
	|csAt: NewScanner(scnew); OpenSelScanner(scnew); IF scnew # NIL  THEN scnew.prevScanner := sc; sc := scnew END;
	|csStar:
		IF sc.ch = ")" THEN
			(* end of a comment, do nothing *)
			Ch(sc);
			RETURN
		END;
		NewScanner(scnew); OpenMarkedScanner(scnew);
		IF scnew # NIL THEN sc := scnew  ELSE sc.GetNext := StopGet END
	END
END SuperSwitch;

PROCEDURE SwitchBack* (VAR sc: Scanner);  BEGIN
	IF sc.prevScanner # NIL THEN sc := sc.prevScanner END
END SwitchBack;

PROCEDURE NewSScanner* (VAR sc: Scanner);
BEGIN
	NEW(sc);
	IF sc # NIL THEN
		sc.Start := DefaultStart;  sc.Stop := DefaultStop;
		sc.prevScanner := NIL;
		sc.Switcher := SuperSwitch
	END
END NewSScanner;

BEGIN
	SetupDefaults;
END vyScanners.

(* additional information *)
(*
Generic scanner model for voyager. The scanner takes a stream of characters and splits it into tokens. Tokens have a class (see CONST token classes) and, depending on their class, a variant.

Basic usage:
VAR sc:vyScanners.Scanner;class:INTEGER;
...
vyScanners.NewScanner(sc);	(* create a new scanner variable, and initialize it *)
vyScanners.OpenScanner(sc,t,beg,end);	(* open on Text t for range [beg,end[ *)
REPEAT
CASE NextToken(sc) OF
ctStuff: (* handle stuff tokens *)
| ctEOT: (* handle EOT *)
| ctId: (* handle identifiers *)
| ctString: (* handle strings *)
| ctSym: (* handle symbols. In particular, handle signs.
Decide whether they should be trated as binary or unitary operators *)
| ctNumber: (* handle unsigned integer numbers. Add unary operator if appropriate *)
| ctReal: (* handle unsigned float numbers. Add unary operator if appropriate *)
| ctFixed:(* handle unsigned fixed numbers. Add unary operator if appropriate *)
| ctNL: (* handle linefeeds *)
| ctComment: (* handle comments *)
END; (* Case *)
UNTIL sc.class=ctEOT; (* or some other stop condition *)

A typical usage is:
VAR sc:vyScanners.Scanner;class:INTEGER;
name:tName;x:REAL; l:LONGINT; neg.negold,ok:BOOLEAN;
...
vyScanners.NewScanner(sc);	(* create a new scanner variable, and initialize it *)
vyScanners.OpenScanner(sc,t,beg,end);	(* open on Text t for range [beg,end[ *)
REPEAT
negold:=neg; neg:=FALSE;
CASE NextToken(sc) OF
ctStuff: (* handle stuff tokens *)
| ctEOT: (* handle EOT *)
| ctId: IF GetName(sc,name) THEN (* handle identifier *)
ELSE  (* handle identifier too long *)END;
| ctString: (* handle strings *)
| ctSym: (* handle symbols. In particular, handle signs.
Decide whether they should be trated as binary or unitary operators *)
IF sc.v=csMinus THEN neg:=TRUE (* handle minus sign *)
ELSE (* other symbol *) END;
| ctNumber: (* handle unsigned integer numbers. Add unary operator if appropriate *)
IF GetNumber(sc,negold,l) THEN (* handle number *)
ELSE (* handle number out of range *) END;
| ctReal,ctFixed: (* handle unsigned float numbers. Add unary operator if appropriate *)
IF GetReal(sc,negold,x) THEN (* handle real *)
ELSE (* handle real out of range *) END;
| ctNL: (* handle linefeeds *)
| ctComment: (* handle comments *)
END; (* Case *)
UNTIL sc.class=ctEOT; (* or some other stop condition *)

For convenience, there are routines which advance the scanner and get the next token, if it is of a certain class. Typical usage is:
IF ExpectName(sc,name) THEN (* handle name ok *) ELSE
(* handle name too long, or token other than name encountered *) END;

IF ExpectNumber(sc,l) THEN (* handle number l ok *) ELSE
(* number out of range, or token other than name encountered *) END;
(* note: a minus sign immediately preceding a numer is interpreted as unary minus *)

IF ExpectReal(sc,x) THEN (* handle real number x ok *) ELSE
(* number out of range, or token other than name encountered *) END;
(* note: a minus sign immediately preceding a numer is interpreted as unary minus *)

Variants:
Instead of vyScanners.NewScanner(sc), use
vyScanners.NewSScanner(sc)
to create and initialize a scanner which switches on all conventional Oberon parameters (*,^,..).


Instead of vyScanners.OpenScanner(sc,t,beg,end), use
vyScanners.OpenParScanner(sc);	(* open a scanner on the input parameters *)
or
vyScanners.OpenSelScanner(sc);	(* open a scanner on the current selection *)
or
vyScanners.OpenSelXScanner(sc);	(* open a scanner on the starting at
current selection, extending to end of input *)
or
vyScanners.OpenMarkedScanner(sc);  (* open a scanner on the current maked viewer *)
or
vyScanners.OpenNamedScanner(sc,name);  (* open a scanner on the named text *)



The next token is isolated by the scanner procedure GetNext which may be customized. The scanner may switch input streams, depending on the incoming tokens. This is done by the scanner procedure Switcher which may be customized.
Token interpretations are postponed as much as possible. This means that the scanner scans the input for you. It does not interpret it unless you explicitely ask for it.

Internal operation: Token separation is done using a table of classes for characters. Each character belongs to one character class ccXxxxx - possibly depending on the left context. When a character of class ccXxxxx is seen, the scanner uses procedure Xxxxx or isXxxxx to find the appropriate token class and to isolate the corresponding token.
Tokens may be separated by white space. Information about trailing white space is kept with each token.
The reader keeps one look-ahead character.
**)*)