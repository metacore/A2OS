MODULE CSS2Scanner;	(** Stefan Walthert  *)
(** AUTHOR "swalthert"; PURPOSE ""; *)

IMPORT
	KernelLog, Strings, Streams, Files, DynamicStrings;

CONST
	(** Scanner: Tokens *)
	Null = -2;
	Invalid* = -1;
	Ident* = 0;
	AtKeyword* = 1;	(** '@'ident *)
	String* = 2;	(** '"'chars'"' | "'"chars"'" *)
	Hash* = 3;	(** '#'name *)
	Important* = 4;	(** '!important' *)
	Number* = 5;	(** number (cf. Scanner.numType) *)
	Percentage* = 6;	(** num'%' *)
	Dimension* = 7;	(** num ident *)
	URI* = 8;	(** 'url('string')' | 'url('chars')' *)
	Function* = 9;	(** ident'(' *)
	UnicodeRange* = 10;	(**  *)
	Cdo* = 11;	(** '<!--' *)
	Cdc* = 12;	(** '-->' *)
	Slash* = 13;	(** '/' *)
	Comma* = 14;	(** ',' *)
	Greater* = 15;	(** '>' *)
	Plus* = 16;	(** '+' *)
	Minus* = 17;	(** '-' *)
	Asterisk* = 18;	(** '*' *)
	Semicolon* = 19;	(** ';' *)
	Colon* = 20;	(** ':' *)
	Dot* = 21;	(** '.' *)
	BracketOpen* = 22;	(** '[' *)
	BracketClose* = 23;	(** ']' *)
	ParenOpen* = 24;	(** '(' *)
	ParenClose* = 25;	(** ')' *)
	BraceOpen* = 26;	(** '{' *)
	BraceClose* = 27;	(** '}' *)
	Equal* = 28;	(** '=' *)
	Includes* = 29;	(** '~=' *)
	Dashmatch* = 30;	(** '|=' *)
	Eof* = 31;	(**  *)

	(** real or integer number *)
	Undefined* = 0;
	Integer* = 1;	(** integer number *)
	Real* = 2;	(** real number *)

TYPE
		Scanner* = OBJECT
		VAR
			sym-: SIGNED32;
			numberType-: SIGNED8;
			intVal-: SIGNED32;
			realVal-: FLOAT64;
			line-, row-, pos: SIGNED32;
			reportError*: PROCEDURE (pos, line, row: SIGNED32; msg: ARRAY OF CHAR);
			nextCh: CHAR;
			dynstr: DynamicStrings.DynamicString;
			f: Files.File;
			r: Files.Reader;

		PROCEDURE & Init*(f: Files.File);
		BEGIN
			IF f = NIL THEN
				sym := Invalid
			ELSE
				reportError := DefaultReportError;
				sym := Null; numberType := Undefined; intVal := 0; realVal := 0.0;
				line := 1; row := 1;
				NEW(dynstr);
				SELF.f := f;
				Files.OpenReader(r, f, 0); pos := 0;
				NextCh()
			END
		END Init;

		PROCEDURE Error(msg: ARRAY OF CHAR);
		BEGIN
			reportError(GetPos(), line, row, msg)
		END Error;

		PROCEDURE NextCh;
		BEGIN
			IF (nextCh = DynamicStrings.CR) (* OR (nextCh = Strings.LF) *) THEN INC(line); row := 1
			ELSE INC(row)
			END;
			IF r.res # Streams.Ok THEN
				nextCh := 0X; sym := Eof
			ELSE
				r.Char(nextCh); INC(pos)
			END
		END NextCh;

		PROCEDURE SkipWhiteSpace;
		BEGIN
			WHILE IsWhiteSpace(nextCh) DO
				NextCh()
			END
		END SkipWhiteSpace;

		PROCEDURE ScanComment;
		BEGIN
			LOOP
				NextCh();
				WHILE (nextCh # '*') & (sym # Eof) DO
					NextCh()
				END;
				IF nextCh = '*' THEN
					NextCh();
					IF nextCh = '/' THEN
						NextCh(); EXIT
					END
				ELSIF sym = Eof THEN
					Error("unclosed comment")
				END
			END
		END ScanComment;

		PROCEDURE ScanEscape(isString: BOOLEAN; VAR i: SIGNED32);
		VAR val: SIGNED32; n: SIGNED8; hexstr: ARRAY 7 OF CHAR; newline: BOOLEAN;
		BEGIN
			newline := FALSE;
			NextCh();
			IF IsDigit(nextCh) OR (('a' <= nextCh) & (nextCh <= 'f')) OR (('A' <= nextCh) & (nextCh <= 'F')) THEN (* hexadecimal digit *)
				n := 0;
(*				WHILE ~IsWhiteSpace(nextCh) & (n < 6) DO	*)
				WHILE (IsDigit(nextCh) OR (('a' <= nextCh) & (nextCh <= 'f')) OR (('A' <= nextCh) & (nextCh <= 'F'))) & (n < 6) DO
					hexstr[n] := nextCh; NextCh(); INC(n)
				END;
				hexstr[n] := 0X;
				HexStrToInt(hexstr, val);
				IF IsWhiteSpace(nextCh) & (n # 6) THEN NextCh() END;	(* skip space after escape digits (if less than 6 digits) *)
			ELSE
				val := ORD(nextCh);
				IF (nextCh = 0AX) OR (nextCh = 0DX) THEN newline := TRUE END;
				NextCh()
			END;
			(* INC(i, number of bytes needed to write unicode value val as a UTF8 character); *)
			IF ~isString OR ~newline THEN
				(* compute UTF8 characters out of 'val', put them to dynstr *)
			END
		END ScanEscape;

		PROCEDURE ScanIdent;
		VAR i: SIGNED32;
		BEGIN
			IF IsNmChar(nextCh) THEN
				i := 0;
				IF IsEscape(nextCh) THEN
					ScanEscape(FALSE, i)
				ELSE
					dynstr.Put(nextCh, 0); INC(i);
					NextCh()
				END;
				WHILE IsNmChar(nextCh) DO
					IF IsEscape(nextCh) THEN
						ScanEscape(FALSE, i)
					ELSE
						dynstr.Put(nextCh, i); INC(i);
						NextCh()
					END
				END;
				dynstr.Put(0X, i); sym := Ident
			ELSE
				Error("{nmstart} expected")
			END
		END ScanIdent;

		PROCEDURE ScanName;
		VAR i: SIGNED32;
		BEGIN
			i := 0;
			WHILE IsNmChar(nextCh) DO
				IF IsEscape(nextCh) THEN
					ScanEscape(FALSE, i)
				ELSE
					dynstr.Put(nextCh, i); INC(i);
					NextCh()
				END
			END;
			dynstr.Put(0X, i); sym := Ident
		END ScanName;

		PROCEDURE ScanString;
		VAR i: SIGNED32; ch, allowedQuote: CHAR;
		BEGIN
			ch := nextCh;
			IF ch = '"' THEN allowedQuote := "'"
			ELSIF ch = "'" THEN allowedQuote := '"'
			ELSE Error("quote expected")
			END;
			NextCh();
			i := 0;
			WHILE ((nextCh = 9X) OR (nextCh = ' ') OR (nextCh = '!') OR (('#' <= nextCh) & (nextCh <= '&'))
					OR (('(' <= nextCh) & (nextCh <= '~')) OR (nextCh = allowedQuote)
					OR IsNonAscii(nextCh) OR IsEscape(nextCh)) & (sym # Eof) DO
				IF IsEscape(nextCh) THEN
					ScanEscape(TRUE, i)
				ELSE
					dynstr.Put(nextCh, i); NextCh(); INC(i)
				END;
			END;
			IF nextCh # ch THEN Error("quote expected") END;
			dynstr.Put(0X, i);
			NextCh()
		END ScanString;

		PROCEDURE ScanURL;
		VAR i : SIGNED32;
		BEGIN
			i := 0;
			WHILE ((nextCh = '!') OR (('#' <= nextCh) & (nextCh <= '&')) OR (('*' <= nextCh) & (nextCh <= '~'))
					OR IsNonAscii(nextCh) OR IsEscape(nextCh)) & (sym # Eof) DO
				IF IsEscape(nextCh) THEN
					ScanEscape(FALSE, i)
				ELSE
					dynstr.Put(nextCh, i); INC(i);
					NextCh()
				END
			END;
			dynstr.Put(0X, i)
		END ScanURL;

		PROCEDURE ScanNumber;
		VAR a, b, div: SIGNED32;
		BEGIN
			a := 0;
			WHILE IsDigit(nextCh) & (sym # Eof) DO
				a := 10 * a + ORD(nextCh) - ORD('0');
				NextCh()
			END;
			IF nextCh = '.' THEN
				b := 0; div := 1;
				NextCh();
				IF ~IsDigit(nextCh) THEN sym := Dot; RETURN END;
				WHILE IsDigit(nextCh) & (sym # Eof) DO
					b := 10 * b + ORD(nextCh) - ORD('0'); div := 10 * div;
					NextCh()
				END;
				realVal := a + b / div;
				sym := Number; numberType := Real
			ELSE
				intVal := a;
				sym := Number; numberType := Integer
			END;
			IF IsNmStart(nextCh) THEN
				ScanIdent(); sym := Dimension
			ELSIF nextCh = '%' THEN
				NextCh(); sym := Percentage
			END
		END ScanNumber;

		PROCEDURE Scan*;
		VAR s: Strings.String; msg: ARRAY 22 OF CHAR;
		BEGIN
			dynstr.Put(0X, 0); sym := Null;
			numberType := Undefined; intVal := 0; realVal := 0.0;	(* reset all fields *)
			REPEAT
				SkipWhiteSpace();
				CASE nextCh OF
				| 0X: sym := Eof
				| 'a' .. 'z', 'A' .. 'Z', '\': ScanIdent();
						IF nextCh = '(' THEN
							NextCh();
							s := GetStr();
							IF s^ = 'url' THEN
								SkipWhiteSpace();
								IF (nextCh = '"') OR (nextCh = "'") THEN
									ScanString()
								ELSE
									ScanURL()
								END;
								SkipWhiteSpace();
								IF nextCh = ')' THEN
									NextCh(); sym := URI
								ELSE
									Error("')' expected")
								END
							ELSE
								sym := Function
							END
						END
				| '!': NextCh(); SkipWhiteSpace();
						ScanIdent(); s := GetStr();
						IF s^ = 'important' THEN
							sym := Important
						ELSE
							Error("'!important' expected")
						END
				| '+': NextCh();
						IF IsDigit(nextCh) OR (nextCh = '.') THEN
							ScanNumber()
						ELSE
							sym := Plus
						END
				| '-': NextCh();
						IF nextCh = '-' THEN
							NextCh();
							IF nextCh = '>' THEN
								NextCh(); sym := Cdc
							ELSE
								Error("'-->' expected")
							END
						ELSE
							sym := Minus
						END;
				| '0' .. '9', '.' : ScanNumber()
				| '@': NextCh(); ScanIdent(); sym := AtKeyword
				| '#': NextCh(); ScanName(); sym := Hash
				| '*': NextCh(); sym := Asterisk
				| '<': NextCh();
						IF nextCh = '!' THEN
							NextCh();
							IF nextCh = '-' THEN
								NextCh();
								IF nextCh = '-' THEN
									NextCh(); sym := Cdo
								ELSE
									Error("'<!--' expected")
								END
							ELSE
								Error("'<!--' expected")
							END
						ELSE
							Error("'<!--' expected")
						END
				| '/': NextCh();
						IF nextCh = '*' THEN
							ScanComment(); sym := Null
						ELSE
							sym := Slash
						END
				| '>': NextCh(); sym := Greater
				| '~': NextCh();
						IF nextCh = '=' THEN
							NextCh(); sym := Includes
						ELSE
							Error("'~= expected")
						END
				| '|': NextCh();
						IF nextCh = '=' THEN
							NextCh(); sym := Dashmatch
						ELSE
							Error("'|=' expected")
						END
				| '=': NextCh(); sym := Equal
				| '"', "'": ScanString(); sym := String
				| '[': NextCh(); sym := BracketOpen
				| ']': NextCh(); sym := BracketClose
				| '(': NextCh(); sym := ParenOpen
				| ')': NextCh(); sym := ParenClose
				| '{': NextCh(); sym := BraceOpen
				| '}': NextCh(); sym := BraceClose
				| ',': NextCh(); sym := Comma
				| ';': NextCh(); sym := Semicolon
				| ':': NextCh(); sym := Colon
				ELSE
					msg := "unknown character"; msg[17] := " "; msg[18] := "'"; msg[19] := nextCh; msg[20] := "'"; msg[21] := 0X;
					Error(msg)
				END
			UNTIL sym # Null
		END Scan;

		PROCEDURE GetStr*(): Strings.String;
		BEGIN
			RETURN dynstr.ToArrOfChar();
		END GetStr;

		PROCEDURE GetPos*(): SIGNED32;
		BEGIN
			RETURN pos
		END GetPos;

	END Scanner;

	PROCEDURE IsWhiteSpace(ch: CHAR): BOOLEAN;
	BEGIN
		RETURN (ch = 020X) OR (ch = 9X) OR (ch = 0DX) OR (ch = 0AX)
	END IsWhiteSpace;

	PROCEDURE IsNonAscii(ch: CHAR): BOOLEAN;
	BEGIN
		RETURN FALSE
	END IsNonAscii;

	PROCEDURE IsEscape(ch: CHAR): BOOLEAN;
	BEGIN
		RETURN ch = '\'
	END IsEscape;

	PROCEDURE IsNmStart(ch: CHAR): BOOLEAN;
	BEGIN
		RETURN (('a' <= ch) & (ch <= 'z')) OR (('A' <= ch) & (ch <= 'Z')) OR (ch = '-') OR IsNonAscii(ch) OR IsEscape(ch)
	END IsNmStart;

	PROCEDURE IsNmChar(ch: CHAR): BOOLEAN;
	BEGIN
		RETURN (('a' <= ch) & (ch <= 'z')) OR (('A' <= ch) & (ch <= 'Z')) OR (ch = '-')
				OR IsDigit(ch) OR IsNonAscii(ch) OR IsEscape(ch)
	END IsNmChar;

	PROCEDURE IsDigit(ch: CHAR): BOOLEAN;
	BEGIN
		RETURN ('0' <= ch) & (ch <= '9')
	END IsDigit;

	PROCEDURE HexStrToInt(VAR str: ARRAY OF CHAR; VAR val: SIGNED32);
	VAR i, d: SIGNED32; ch: CHAR;
	BEGIN
		i := 0; ch := str[0];
		WHILE (ch # 0X) & (ch <= " ") DO
			INC(i); ch := str[i]
		END;
		val := 0;
		WHILE (("0" <= ch) & (ch <= "9")) OR (("A" <= ch) & (ch <= "F")) DO
			IF (("0" <= ch) & (ch <= "9")) THEN d := ORD(ch)-ORD("0")
			ELSE d := ORD(ch) - ORD("A") + 10
			END;
			INC(i); ch := str[i];
			IF val <= ((MAX(SIGNED32)-d) DIV 10H) THEN
				val := 10H*val+d
			ELSE
				HALT(99)
			END
		END
	END HexStrToInt;

	PROCEDURE DefaultReportError(pos, line, row: SIGNED32; msg: ARRAY OF CHAR);
	BEGIN
		KernelLog.Enter; KernelLog.Char(CHR(9H)); KernelLog.Char(CHR(9H)); KernelLog.String("pos "); KernelLog.Int(pos, 6);
		KernelLog.String(", line "); KernelLog.Int(line, 0); KernelLog.String(", row "); KernelLog.Int(row, 0);
		KernelLog.String("    "); KernelLog.String(msg); KernelLog.Exit;
	END DefaultReportError;

END CSS2Scanner.
