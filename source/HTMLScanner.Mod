MODULE HTMLScanner;	(** AUTHOR "Simon L. Keel" (heavily based on swalthert's "XMLScanner"); PURPOSE "HTML scanner"; *)

IMPORT
	KernelLog, Streams, Strings, DynamicStrings;

CONST
	(** Scanner: Tokens *)
	Invalid* = -1;
	TagElemStartOpen* = 0;	(** '<' *)
	TagElemEndOpen* = 1;	(** '</' *)
	TagDeclOpen* = 2;	(** '<!NAME' *)
	TagClose* = 3;	(** '>' *)
	TagEmptyElemClose* = 4;	(** '/>' *)
	TagXMLDeclOpen* = 5;	(** '<?xml' *)
	TagPIOpen* = 6;	(** '<?', PITarget := GetStr() *)
	TagPIClose* = 7;	(** '?>' *)
	TagCondSectOpen* = 8;	(** '<![' *)
	TagCondSectClose* = 9;	(** ']]>' *)
	BracketOpen* = 10;	(** '[' *)
	BracketClose* = 11;	(** ']' *)
	ParenOpen* = 12;	(** '(' *)
	ParenClose* = 13;	(** ')' *)
	Comment* = 14;	(** '<!--' chars '-->', chars := GetStr() *)
	CDataSect* = 15;	(** '<![CDATA[' chars ']]>', chars := GetStr() *)
	CharRef* = 16;	(** '&#' number ';' or '&#x' hexnumber ';', number, hexnumber := GetStr() *)
	EntityRef* = 17;	(** '&' name ';', name := GetStr() *)
	ParamEntityRef* = 18;	(** '%' name ';', name := GetStr() *)
	CharData* = 19;	(** chars := GetStr() *)
	Literal* = 20;	(** '"'chars'"' or "'"chars"'", chars := GetStr() *)
	Name* = 21;	(** 	Name ::= (Letter | '_' | ':') {NameChar}
										NameChar ::= Letter | Digit | '.' | '-' | '_' | ':' | CombiningChar | Extender
										chars := GetStr() *)
	Nmtoken* = 22;	(**	Nmtoken ::= NameChar {NameChar}, chars := GetStr() *)
	PoundName* = 23;	(** '#'name, name := GetStr() *)
	Question* = 24;	(** '?' *)
	Asterisk* = 25;	(** '*' *)
	Plus* = 26;	(** '+' *)
	Or* = 27;	(** '|' *)
	Comma* = 28;	(** ',' *)
	Percent* = 29;	(** '%' *)
	Equal* = 30;	(** '=' *)
	Eof* = 31;

	LF = 0AX;
	CR = 0DX;

TYPE
	String = Strings.String;

	Scanner* = OBJECT
		VAR
			sym-: SIGNED8;	(** current token *)
			line-, col-, oldpos, pos: SIGNED32;
			reportError*: PROCEDURE {DELEGATE} (pos, line, row: SIGNED32; msg: ARRAY OF CHAR);
			nextCh: CHAR;	(* look-ahead *)
			dynstr: DynamicStrings.DynamicString;	(* buffer for CharData, Literal, Name, CharRef, EntityRef and ParamEntityRef *)
			r : Streams.Reader;

		(** Initialize scanner to read from the given ascii file *)
		PROCEDURE & Init*(r: Streams.Reader);
		BEGIN
			reportError := DefaultReportError;
			SELF.r := r;
			NEW(dynstr);
			line := 1; pos := 0; col := 0;
			NextCh();
			(* remove byte order marker (bom) *)
			WHILE (ORD(nextCh) = 0EFH) OR (ORD(nextCh) = 0BBH) OR (ORD(nextCh) = 0BFH) OR
				(ORD(nextCh) = 0FFH) OR (ORD(nextCh) = 0FEH) OR ( nextCh = 0X ) & ( sym # Eof ) DO
					NextCh();
			END;
		END Init;

		PROCEDURE Error(msg: ARRAY OF CHAR);
		BEGIN
			sym := Invalid;
			reportError(GetPos(), line, col, msg)
		END Error;

		PROCEDURE NextCh;
		BEGIN
			IF (nextCh = CR) OR (nextCh = LF) THEN INC(line); col := 0;
			ELSE INC(col)
			END;
			IF r.res # Streams.Ok THEN
				nextCh := 0X; sym := Eof
			ELSE
				nextCh := r.Get(); INC(pos);
			END;
		END NextCh;

		PROCEDURE ReadTillChar(ch: CHAR);
		VAR i: SIGNED32;
		BEGIN
			i := 0;
			WHILE (nextCh # ch) & (sym # Eof) DO
				dynstr.Put(nextCh, i); INC(i); NextCh()
			END;
			dynstr.Put(0X, i);
			IF sym = Eof THEN sym := Invalid END
		END ReadTillChar;

		PROCEDURE SkipWhiteSpaces;
		BEGIN
			WHILE IsWhiteSpace(nextCh) & (sym # Eof) DO
				NextCh()
			END
		END SkipWhiteSpaces;

		(* Possible results:
				Name
				Nmtoken
				Invalid	*)
		PROCEDURE ScanNm;
		VAR i: SIGNED32;
		BEGIN
			SkipWhiteSpaces();
			IF (('0' <= nextCh) & (nextCh <= '9')) OR (nextCh = '.') OR (nextCh = '-') THEN
				sym := Nmtoken
			ELSIF (('a' <= nextCh) & (nextCh <= 'z')) OR (('A' <= nextCh) & (nextCh <= 'Z')) OR (nextCh = '_') OR (nextCh = ':') THEN
				sym := Name
			ELSE
				sym := Invalid; RETURN
			END;
			dynstr.Put(nextCh, 0);
			i := 1; NextCh();
			WHILE ((('a' <= nextCh) & (nextCh <= 'z')) OR (('A' <= nextCh) & (nextCh <= 'Z')) OR
					(('0' <= nextCh) & (nextCh <= '9')) OR (nextCh = '.') OR (nextCh = '-') OR (nextCh = '_')
					OR (nextCh = ':')) & (sym # Eof) DO
				dynstr.Put(nextCh, i); INC(i); NextCh()
			END;
			dynstr.Put(0X, i);
			IF sym = Eof THEN sym := Invalid END;
		END ScanNm;

		(* Scan Comment after comment open tag '<!--', write characters to dynstr.
				Possible results:
				Invalid
				Comment	*)
		PROCEDURE ScanComment;
		VAR i: SIGNED32;
		BEGIN
			i := 0;
			NEW(dynstr);
			LOOP
				WHILE (nextCh # '-') & (sym # Eof) DO
					dynstr.Put(nextCh, i); INC(i); NextCh()
				END;
				IF nextCh = '-' THEN
					NextCh();
					IF nextCh = '-' THEN
						LOOP
							NextCh();
							IF nextCh = '>' THEN
								dynstr.Put(0X, i); NextCh(); sym := Comment; RETURN
							ELSIF nextCh = '-' THEN
								dynstr.Put('-', i); INC(i);
							ELSE
								dynstr.Put('-', i); INC(i);
								dynstr.Put('-', i); INC(i);
								EXIT;
							END
						END;
					ELSE
						dynstr.Put('-', i); INC(i)
					END
				ELSE
					sym := Invalid; RETURN
				END
			END
		END ScanComment;

		PROCEDURE ScanSCRIPT*;
		VAR
			i, j : SIGNED32;
			t : DynamicStrings.DynamicString;
			s : String;
		BEGIN
			i := 0;
			NEW(dynstr);
			LOOP
				WHILE (nextCh # '<') & (sym # Eof) DO
					dynstr.Put(nextCh, i); INC(i); NextCh()
				END;
				NEW(t); j := 0;
				IF nextCh = '<' THEN
					t.Put(nextCh, j); INC(j); NextCh();
					IF nextCh = '/' THEN
						t.Put(nextCh, j); INC(j); NextCh();
						IF (nextCh = 's') OR (nextCh = 'S') THEN
							t.Put(nextCh, j); INC(j); NextCh();
							IF (nextCh = 'c') OR (nextCh = 'C') THEN
								t.Put(nextCh, j); INC(j); NextCh();
								IF (nextCh = 'r') OR (nextCh = 'R') THEN
									t.Put(nextCh, j); INC(j); NextCh();
									IF (nextCh = 'i') OR (nextCh = 'I') THEN
										t.Put(nextCh, j); INC(j); NextCh();
										IF (nextCh = 'p') OR (nextCh = 'P') THEN
											t.Put(nextCh, j); INC(j); NextCh();
											IF (nextCh = 't') OR (nextCh = 'T') THEN
												t.Put(nextCh, j); INC(j); NextCh();
												WHILE ORD(nextCh) < 33 DO
													t.Put(nextCh, j); INC(j); NextCh();
												END;
												IF (nextCh = '>') THEN
													NextCh();
													sym := Comment;
													EXIT;
												END;
											END;
										END;
									END;
								END;
							END;
						END;
					END;
					t.Put(nextCh, j);
					s := t.ToArrOfChar();
					dynstr.Append(s^); INC(i, j);
				ELSE
					sym := Invalid;
					EXIT;
				END;
			END;
		END ScanSCRIPT;

		PROCEDURE ScanSTYLE*;
		VAR
			i, j : SIGNED32;
			t : DynamicStrings.DynamicString;
			s : String;
		BEGIN
			i := 0;
			NEW(dynstr);
			LOOP
				WHILE (nextCh # '<') & (sym # Eof) DO
					dynstr.Put(nextCh, i); INC(i); NextCh()
				END;
				NEW(t); j := 0;
				IF nextCh = '<' THEN
					t.Put(nextCh, j); INC(j); NextCh();
					IF nextCh = '/' THEN
						t.Put(nextCh, j); INC(j); NextCh();
						IF (nextCh = 's') OR (nextCh = 'S') THEN
							t.Put(nextCh, j); INC(j); NextCh();
							IF (nextCh = 't') OR (nextCh = 'T') THEN
								t.Put(nextCh, j); INC(j); NextCh();
								IF (nextCh = 'y') OR (nextCh = 'Y') THEN
									t.Put(nextCh, j); INC(j); NextCh();
									IF (nextCh = 'l') OR (nextCh = 'L') THEN
										t.Put(nextCh, j); INC(j); NextCh();
										IF (nextCh = 'e') OR (nextCh = 'E') THEN
											t.Put(nextCh, j); INC(j); NextCh();
											WHILE ORD(nextCh) < 33 DO
												t.Put(nextCh, j); INC(j); NextCh();
											END;
											IF (nextCh = '>') THEN
												NextCh();
												sym := Comment;
												EXIT;
											END;
										END;
									END;
								END;
							END;
						END;
					END;
					t.Put(nextCh, j);
					s := t.ToArrOfChar();
					dynstr.Append(s^); INC(i, j);
				ELSE
					sym := Invalid;
					EXIT;
				END;
			END;
		END ScanSTYLE;

		(** possible results:
			Invalid
			TagPIClose
			CharData	*)
		PROCEDURE ScanPInstruction*;
		VAR i: SIGNED32;
		BEGIN
			IF sym = Eof THEN
				sym := Invalid;
				RETURN
			END;
			i := 0;
			LOOP
				WHILE (nextCh # '?') & (sym # Eof) DO
					dynstr.Put(nextCh, i); INC(i); NextCh()
				END;
				IF nextCh = '?' THEN
					NextCh();
					IF nextCh = '>' THEN
						sym := TagPIClose; NextCh(); RETURN
					ELSE
						dynstr.Put('?', i); INC(i)
					END
				ELSIF sym = Eof THEN
					sym := Invalid; RETURN
				ELSE
					dynstr.Put(0X, i); sym := CharData; RETURN
				END
			END
		END ScanPInstruction;

		PROCEDURE ScanMarkup*;
		VAR ch: CHAR;
		BEGIN
			SkipWhiteSpaces();
			oldpos := GetPos();
			IF sym = Eof THEN
				sym := Eof; RETURN
			END;
			CASE nextCh OF
			| '<': NextCh();
					IF nextCh = '!' THEN
						NextCh();
						IF nextCh = '-' THEN
							NextCh();
							IF nextCh = '-' THEN
								NextCh();
								ScanComment()
							ELSE
								Error("'<!--' expected")
							END
						ELSE
							ScanNm();
							IF sym = Name THEN
								sym := TagDeclOpen
							ELSE
								Error("'<!NAME' expected")
							END
						END
					ELSIF nextCh = '?' THEN
						NextCh();
						ScanNm();
						IF sym = Name THEN
							sym := TagPIOpen
						ELSE
							Error("'<?' Name expected")
						END
					ELSE
						Error("'<?' Name or '<!--' expected")
					END
			| '/': NextCh();
					IF nextCh = '>' THEN
						NextCh(); sym := TagEmptyElemClose
					ELSE
						sym := Invalid
					END
			| '>': NextCh(); sym := TagClose
			| '?': NextCh();
					IF nextCh = '>' THEN
						NextCh();
						sym := TagPIClose
					ELSE
						sym := Question
					END
			| '=': NextCh(); sym := Equal
			| '"', "'": ch := nextCh; NextCh(); ReadTillChar(ch); NextCh();
					IF sym # Invalid THEN sym := Literal END;
			ELSE ScanNm()
			END
		END ScanMarkup;

		PROCEDURE ScanContent*;
		VAR s: String; i: SIGNED32;
		BEGIN
			i := 0;
			oldpos := GetPos();
			IF sym = Eof THEN nextCh := 0X END;
			CASE nextCh OF
			| 0X: sym := Eof
			| '<': NextCh();
				CASE nextCh OF
				| '/': sym := TagElemEndOpen; NextCh()
				| '?': NextCh(); ScanNm();
						IF (sym = Name) THEN
							s := dynstr.ToArrOfChar(); DynamicStrings.Lower(s^, s^);
							IF s^ = "xml" THEN
								sym := TagXMLDeclOpen
							ELSE
								Error("''<?xml' expected")
							END
						ELSE
							Error("''<?xml' expected")
						END
				| '!': NextCh();
						IF nextCh = '-' THEN
							NextCh();
							IF nextCh = '-' THEN
								NextCh(); ScanComment()
							ELSE
								Error("'<!--' expected")
							END
						ELSE
							ScanNm();
							IF  sym = Name THEN
								sym := TagDeclOpen
							ELSE
								Error("'<!xml' or '<!NAME' expected")
							END
						END
				ELSE
					sym:=TagElemStartOpen
				END
			ELSE
				REPEAT
					dynstr.Put(nextCh, i); INC(i);
					NextCh();
				UNTIL (nextCh='<') OR (sym = Eof);
				dynstr.Put(0X, i);
				sym := CharData;
			END
		END ScanContent;

		PROCEDURE ScanAttributeValue*;
		VAR i: SIGNED32;
		BEGIN
			SkipWhiteSpaces();
			i := 0;
			IF nextCh = '"' THEN
				NextCh();
				WHILE (nextCh # '"') & (sym # Eof) DO
					dynstr.Put(nextCh, i); INC(i); NextCh();
				END;
				NextCh();
			ELSIF nextCh = "'" THEN
				NextCh();
				WHILE (nextCh # "'") & (sym # Eof) DO
					dynstr.Put(nextCh, i); INC(i); NextCh();
				END;
				NextCh();
			ELSE
				WHILE ~IsWhiteSpace(nextCh) & (nextCh # '>') & (sym # Eof) DO
					dynstr.Put(nextCh, i); INC(i); NextCh()
				END;
			END;
			dynstr.Put(0X, i);
			IF sym#Eof THEN sym := Literal END;
		END ScanAttributeValue;

		PROCEDURE GetStr*(): String;
		BEGIN
			RETURN dynstr.ToArrOfChar();
		END GetStr;

		PROCEDURE GetPos*(): SIGNED32;
		BEGIN
			RETURN pos - 1
		END GetPos;

		PROCEDURE GetOldPos*(): SIGNED32;
		BEGIN
			RETURN oldpos
		END GetOldPos;

	END Scanner;

	PROCEDURE IsWhiteSpace(ch: CHAR): BOOLEAN;
	BEGIN
		RETURN (ch = 020X) OR (ch = 9X) OR (ch = 0DX) OR (ch = 0AX)
	END IsWhiteSpace;

	PROCEDURE DefaultReportError(pos, line, col: SIGNED32; msg: ARRAY OF CHAR);
	BEGIN
		KernelLog.Enter; KernelLog.Char(CHR(9H)); KernelLog.Char(CHR(9H)); KernelLog.String("pos "); KernelLog.Int(pos, 6);
		KernelLog.String(", line "); KernelLog.Int(line, 0); KernelLog.String(", col "); KernelLog.Int(col, 0);
		KernelLog.String("    "); KernelLog.String(msg); KernelLog.Exit;
	END DefaultReportError;

END HTMLScanner.
