MODULE ReleaseVisualizerScanner; (** AUTHOR "TF"; PURPOSE "Active Oberon Scanner for Release Visualizer Tool"; *)

IMPORT
	Texts, Streams, UTF8Strings, Strings;

CONST
	Eot* = 0X;
	ObjectMarker = 020X;

	(* numtyp values *)
	char* = 1; integer* = 2; longinteger* = 3; real* = 4; longreal* = 5;
	null* =   0; times* =   1; slash* =   2; div* =   3; mod* =   4; and* =   5;
	plus* =   6; minus* =   7; or* =   8; eql* =   9; neq* =  10; lss* =  11;
	leq* =  12; gtr* =  13; geq* =  14; in* =  15; is* =  16; arrow* =  17;
	period* =  18; comma* =  19; colon* =  20; upto* =  21; rparen* =  22;
	rbrak* =  23; rbrace* =  24; of* =  25; then* =  26; do* =  27; to* =  28;
	by* =  29; lparen* =  30; lbrak* =  31; lbrace* =  32; not* =  33;
	becomes* =  34; number* =  35; nil* =  36; true* =  37; false* =  38;
	string* =  39; ident* =  40; semicolon* =  41; bar* =  42; end* =  43;
	else* =  44; elsif* =  45; until* =  46; if* =  47; case* =  48; while* =  49;
	repeat* =  50; for* =  51; loop* =  52; with* =  53; exit* =  54;
	passivate* =  55; return* =  56; refines* =  57; implements* =  58;
	array* =  59; definition* =  60; object* =  61; record* =  62; pointer* =  63;
	begin* =  64; code* =  65; const* =  66; type* =  67; var* =  68;
	procedure* =  69; import* =  70; module* =  71; eof* =  72;
	comment* = 73;

VAR
	reservedChar-, newChar: ARRAY 256 OF BOOLEAN;

TYPE

	StringMaker* = OBJECT
	VAR
		length : LONGINT;
		data : Strings.String;

		PROCEDURE &Init(initialSize : LONGINT);
		BEGIN
			IF initialSize < 256 THEN initialSize := 256 END;
			NEW(data, initialSize); length := 0;
		END Init;

		PROCEDURE Add*(CONST buf: ARRAY OF CHAR; ofs, len: LONGINT; propagate: BOOLEAN; VAR res: WORD);
		VAR i : LONGINT; n : Strings.String;
		BEGIN
			IF length + len + 1 >= LEN(data) THEN
				NEW(n, LEN(data) + len + 1); FOR i := 0 TO length - 1 DO n[i] := data[i] END;
				data := n
			END;
			WHILE len > 0 DO
				data[length] := buf[ofs];
				INC(ofs); INC(length); DEC(len)
			END;
			data[length] := 0X;
		END Add;

		PROCEDURE Clear*;
		BEGIN
			data[0] := 0X;
			length := 0
		END Clear;

		PROCEDURE GetWriter*() : Streams.Writer;
		VAR w : Streams.Writer;
		BEGIN
			NEW(w, SELF.Add, 256);
			RETURN w
		END GetWriter;

		PROCEDURE GetLength*() : LONGINT;
		BEGIN
			RETURN length
		END GetLength;

		PROCEDURE GetString*() : Strings.String;
		BEGIN
			RETURN data
		END GetString;

	END StringMaker;


	Scanner* = OBJECT
		VAR
			buffer: Strings.String;
			pos: LONGINT;	(*pos in buffer*)
			ch-: CHAR;	(**look-ahead *)
			str-: ARRAY 1024 OF CHAR;
			sym- : LONGINT;
			numStartPos, numEndPos: LONGINT;
			curpos-, errpos-: LONGINT;	(*pos in text*)
			isNummer: BOOLEAN;
			commentStr- : StringMaker;
			cw : Streams.Writer;

		PROCEDURE &Init;
		BEGIN
			NEW(commentStr, 1024);
			cw := commentStr.GetWriter()
		END Init;

		PROCEDURE err(n: INTEGER);
		BEGIN
		END err;

		PROCEDURE NextChar*;
		BEGIN
			IF pos < LEN(buffer) THEN
				ch := buffer[pos]; INC(pos)
			ELSE
				ch := Eot
			END;
			IF newChar[ORD(ch)] THEN INC(curpos) END; (* curpos := pos; *)
		END NextChar;

		PROCEDURE Str(VAR sym: LONGINT);
		VAR i: LONGINT; och: CHAR;
		BEGIN i := 0; och := ch;
			LOOP NextChar;
				IF ch = och THEN EXIT END ;
				IF ch < " " THEN err(3); EXIT END ;
				IF i = LEN(str)-1 THEN err(241); EXIT END ;
				str[i] := ch; INC(i)
			END ;
			NextChar; str[i] := 0X;
			IF i = 1 THEN
				sym := number
			ELSE sym := string
			END
		END Str;

		PROCEDURE Identifier(VAR sym: LONGINT);
			VAR i: LONGINT;
		BEGIN i := 0;
			REPEAT
				str[i] := ch; INC(i); NextChar
			UNTIL reservedChar[ORD(ch)] OR (i = LEN(str));
			IF i = LEN(str) THEN err(240); DEC(i) END ;
			str[i] := 0X; sym := ident;
			(* temporary code! delete when moving to ANY and adapt PCT *)
			IF str = "ANY" THEN COPY("PTR", str) END;
		END Identifier;

		PROCEDURE GetNumAsString*(VAR val: ARRAY OF CHAR);
		VAR i, l: LONGINT;
		BEGIN
			(*Strings.Copy(buffer^, numStartPos, numEndPos-numStartPos, val);*)
			IF isNummer THEN
				i := 0; l := LEN(val)-1;
				WHILE (i < numEndPos-numStartPos) & (i < l) DO
					val[i] := buffer[numStartPos + i];
					INC(i);
				END;
			END;
			val[i] := 0X
		END GetNumAsString;

		PROCEDURE Get(VAR s: LONGINT);

			PROCEDURE Comment;	(* do not read after end of file *)
			BEGIN NextChar; cw.Char(ch);
				LOOP
					LOOP
						WHILE ch = "(" DO NextChar; cw.Char(ch);
							IF ch = "*" THEN Comment END
						END;
						IF ch = "*" THEN NextChar; cw.Char(ch); EXIT END ;
						IF ch = Eot THEN EXIT END ;
						NextChar; cw.Char(ch);
					END ;
					IF ch = ")" THEN NextChar; cw.Char(ch); EXIT END ;
					IF ch = Eot THEN err(5); EXIT END
				END
			END Comment;

		BEGIN
			REPEAT
				WHILE ch <= " " DO (*ignore control characters*)
					IF ch = Eot THEN
						s := eof; RETURN
					ELSE NextChar
					END
				END ;
				errpos := curpos - 1;
				isNummer := FALSE;
				CASE ch OF   (* ch > " " *)
					| 22X, 27X  : Str(s)
					| "#"  : s := neq; NextChar
					| "&"  : s :=  and; NextChar
					| "("  : NextChar;
							 IF ch = "*" THEN commentStr.Clear; Comment; cw.Update; s := comment;		(*allow recursion without reentrancy*)
							 ELSE s := lparen
							 END
					| ")"  : s := rparen; NextChar
					| "*"  : s:=times; NextChar
					| "+"  : s :=  plus; NextChar
					| ","  : s := comma; NextChar
					| "-"  : s :=  minus; NextChar
					| "."  : NextChar;
									 IF ch = "." THEN NextChar; s := upto ELSE s := period END
					| "/"  : s :=  slash; NextChar
					| "0".."9": isNummer := TRUE; numStartPos := pos-1; (*Number;*) numEndPos := pos-1; s := number
					| ":"  : NextChar;
									 IF ch = "=" THEN NextChar; s := becomes ELSE s := colon END
					| ";"  : s := semicolon; NextChar
					| "<"  : NextChar;
									 IF ch = "=" THEN NextChar; s := leq; ELSE s := lss; END
					| "="  : s :=  eql; NextChar
					| ">"  : NextChar;
									 IF ch = "=" THEN NextChar; s := geq; ELSE s := gtr; END
					| "A": Identifier(s);
								IF str = "ARRAY" THEN s := array
								ELSIF str = "AWAIT" THEN s := passivate
								END
					| "B": Identifier(s);
								IF str = "BEGIN" THEN s := begin
								ELSIF str = "BY" THEN s := by
								END
					| "C": Identifier(s);
								IF str = "CONST" THEN s := const
								ELSIF str = "CASE" THEN s := case
								ELSIF str = "CODE" THEN s := code
								END
					| "D": Identifier(s);
								IF str = "DO" THEN s := do
								ELSIF str = "DIV" THEN s := div
								ELSIF str = "DEFINITION" THEN s := definition
								END
					| "E": Identifier(s);
								IF str = "END" THEN s := end
								ELSIF str = "ELSE" THEN s := else
								ELSIF str = "ELSIF" THEN s := elsif
								ELSIF str = "EXIT" THEN s := exit
								END
					| "F": Identifier(s);
								IF str = "FALSE" THEN s := false
								ELSIF str = "FOR" THEN s := for
								END
					| "I": Identifier(s);
								IF str = "IF" THEN s := if
								ELSIF str = "IN" THEN s := in
								ELSIF str = "IS" THEN s := is
								ELSIF str = "IMPORT" THEN s := import
								ELSIF str = "IMPLEMENTS" THEN s := implements
								END
					| "L": Identifier(s);
								IF str = "LOOP" THEN s := loop END
					| "M": Identifier(s);
								IF str = "MOD" THEN s := mod
								ELSIF str = "MODULE" THEN s := module
								END
					| "N": Identifier(s);
								IF str = "NIL" THEN s := nil END
					| "O": Identifier(s);
								IF str = "OR" THEN s := or
								ELSIF str = "OF" THEN s := of
								ELSIF str = "OBJECT" THEN s := object
								END
					| "P": Identifier(s);
								IF str = "PROCEDURE" THEN s := procedure
								ELSIF str = "POINTER" THEN s := pointer
								END
					| "R": Identifier(s);
								IF str = "RECORD" THEN s := record
								ELSIF str = "REPEAT" THEN s := repeat
								ELSIF str = "RETURN" THEN s := return
								ELSIF str = "REFINES" THEN s := refines
								END
					| "T": Identifier(s);
								IF str = "THEN" THEN s := then
								ELSIF str = "TRUE" THEN s := true
								ELSIF str = "TO" THEN s := to
								ELSIF str = "TYPE" THEN s := type
								END
					| "U": Identifier(s);
								IF str = "UNTIL" THEN s := until END
					| "V": Identifier(s);
								IF str = "VAR" THEN s := var END
					| "W": Identifier(s);
								IF str = "WHILE" THEN s := while
								ELSIF str = "WITH" THEN s := with
								END
					| "G".."H", "J", "K", "Q", "S", "X".."Z": Identifier(s)
					| "["  : s := lbrak; NextChar
					| "]"  : s := rbrak; NextChar
					| "^"  : s := arrow; NextChar
					| "a".."z": Identifier(s)
					| "{"  : s := lbrace; NextChar
					| "|"  : s := bar; NextChar
					| "}"  : s := rbrace; NextChar
					| "~"  : s := not; NextChar
					| 7FX  : s := upto; NextChar
				ELSE  Identifier(s); (* s := null; NextChar; *)
				END ;
			UNTIL s >= 0;
		END Get;

		PROCEDURE Next*;
		BEGIN
			Get(sym)
		END Next;


	END Scanner;

PROCEDURE InitWithText*(t: Texts.Text; pos: LONGINT): Scanner;
	VAR buffer: Strings.String; len, i, j, ch: LONGINT; r: Texts.TextReader;
	bytesPerChar: LONGINT;
	s : Scanner;
BEGIN
	t.AcquireRead;
	len := t.GetLength();
	bytesPerChar := 2;
	NEW(buffer, len * bytesPerChar);	(* UTF8 encoded characters use up to 5 bytes *)
	NEW(r, t);
	r.SetPosition(pos);
	j := 0;
	FOR i := 0 TO len-1 DO
		r.ReadCh(ch);
		WHILE ~UTF8Strings.EncodeChar(ch, buffer^, j) DO
				(* buffer too small *)
			INC(bytesPerChar);
			ExpandBuf(buffer, bytesPerChar * len);
		END;
	END;
	t.ReleaseRead;
	NEW(s); s.buffer := buffer;
	s.pos := 0;
	s.ch := " ";
	RETURN s;
END InitWithText;

PROCEDURE ExpandBuf(VAR oldBuf: Strings.String; newSize: LONGINT);
VAR newBuf: Strings.String; i: LONGINT;
BEGIN
	IF LEN(oldBuf^) >= newSize THEN RETURN END;
	NEW(newBuf, newSize);
	FOR i := 0 TO LEN(oldBuf^)-1 DO
		newBuf[i] := oldBuf[i];
	END;
	oldBuf := newBuf;
END ExpandBuf;

PROCEDURE InitReservedChars;
VAR
	i: LONGINT;
BEGIN
	FOR i := 0 TO LEN(reservedChar)-1 DO
		IF CHR(i) <= 20X THEN	(* TAB, CR, ESC ... *)
			reservedChar[i] := TRUE;
		ELSE
			CASE CHR(i) OF
				| "#", "&", "(", ")", "*", "+", ",", "-", ".", "/": reservedChar[i] := TRUE;
				| ":", ";", "<", "=", ">": reservedChar[i] := TRUE;
				| "[", "]", "^", "{", "|", "}", "~": reservedChar[i] := TRUE;
				| "$": reservedChar[i] := TRUE;
				| 22X, 27X, 7FX: reservedChar[i] := TRUE;	(* 22X = ", 27X = ', 7FX = del *)
			ELSE
				reservedChar[i] := FALSE;
			END;
		END;
	END;
END InitReservedChars;

PROCEDURE InitNewChar;
VAR
	i: LONGINT;
BEGIN
	FOR i := 0 TO LEN(newChar)-1 DO
		(* UTF-8 encoded characters with bits 10XXXXXX do not start a new unicode character *)
		IF (i < 80H) OR (i > 0BFH) THEN
			newChar[i] := TRUE;
		ELSE
			newChar[i] := FALSE;
		END
	END
END InitNewChar;


BEGIN
	InitReservedChars;
	InitNewChar;
END ReleaseVisualizerScanner.
