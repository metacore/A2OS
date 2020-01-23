MODULE PascalPreprocessor;

IMPORT
	Commands, Files, Streams, Strings,
	Containers, PreciseTimer;

CONST
	Eot             = 0X;

	TAB             = 09X;
	LF              = 0AX;
	CR              = 0DX;
	SP              = 20X;

	sym_and         = 1;
	sym_array       = 2;
	sym_arrow       = 3;  (* ^ *)
	sym_becomes     = 4;  (* := *)
	sym_begin       = 5;  (* begin, initialization *)
	sym_boolean     = 6;
	sym_case        = 7;
	sym_char        = 8;
	sym_code        = 9;  (* asm *)
	sym_colon       = 10; (* : *)
	sym_comma       = 11;
	sym_comment     = 12;
	sym_const       = 13;
	sym_dec         = 14;
	sym_div         = 15;
	sym_do          = 16;
	sym_double      = 18;
	sym_else        = 19;
	sym_end         = 20;
	sym_eof         = 21;
	sym_eql         = 22;
	sym_exit        = 23;
	sym_false       = 24;
	sym_for         = 25;
	sym_geq         = 26;
	sym_gtr         = 27;
	sym_ident       = 28;
	sym_if          = 29;
	sym_import      = 30; (* uses *)
	sym_in          = 31;
	sym_inc         = 32;
	sym_int64       = 33; (* int64 *)
	sym_is          = 34;
	sym_lbrak       = 35; (* [ *)
	sym_leq         = 36;
	sym_longint     = 37; (* integer, int32, longint *)
	sym_lparen      = 38; (* ( *)
	sym_lss         = 39;
	sym_minus       = 40;
	sym_mod         = 41;
	sym_module      = 42; (* unit, program *)
	sym_neq         = 43; (* <> *)
	sym_newLine     = 44;
	sym_nil         = 45;
	sym_not         = 46; (* not *)
	sym_object      = 48; (* class, object *)
	sym_of          = 49;
	sym_or          = 50;
	sym_pas_string  = 51; (* string *)
	sym_period      = 52; (* . *)
	sym_plus        = 53;
	sym_pointer     = 54; (* pointer *)
	sym_procedure   = 55; (* procedure, function *)
	sym_rbrak       = 56; (* ] *)
	sym_record      = 57;
	sym_repeat      = 58;
	sym_rparen      = 59; (* ) *)
	sym_semicolon   = 60; (* ; *)
	sym_shortint    = 61; (* shortint *)
	sym_single      = 62;
	sym_slash       = 63;
	sym_smallint    = 64; (* smallint, int16 *)
	sym_space       = 65;
	sym_string      = 66;
	sym_then        = 67;
	sym_times       = 68;
	sym_to          = 69;
	sym_true        = 70;
	sym_type        = 71;
	sym_until       = 72;
	sym_upto        = 73; (* .. *)
	sym_var         = 74;
	sym_while       = 75;
	sym_with        = 76;
	sym_file        = 77;
	sym_forward     = 78;
	sym_finalization= 79;
	sym_implementation= 80;
	sym_interface   = 81;
	sym_packed      = 82;
	sym_chr         = 83;
	sym_ord         = 84;
	sym_hex         = 85;
	sym_hex_char    = 86;

	(* Oberon only keywords *)
	KW_ANY          = "ANY";
	KW_CODE         = "CODE";
	KW_HUGEINT      = "HUGEINT";
	KW_IMPORT       = "IMPORT";
	KW_LONGREAL     = "LONGREAL";
	KW_MODULE       = "MODULE";
	(* Pascal and Pascal-Oberon common keywords *)
	KW_AND          = "AND";
	KW_ARRAY        = "ARRAY";
	KW_ASM          = "ASM";
	KW_BEGIN        = "BEGIN";
	KW_BOOLEAN      = "BOOLEAN";
	KW_CASE         = "CASE";
	KW_CHAR         = "CHAR";
	KW_CHR          = "CHR";
	KW_CLASS        = "CLASS";
	KW_CONST        = "CONST";
	KW_DEC          = "DEC";
	KW_DIV          = "DIV";
	KW_DO           = "DO";
	KW_DOUBLE       = "DOUBLE";
	KW_ELSE         = "ELSE";
	KW_END          = "END";
	KW_EXIT         = "EXIT";
	KW_EXTENDED     = "EXTENDED";
	KW_FALSE        = "FALSE";
	KW_FILE         = "FILE";
	KW_FINALIZATION = "FINALIZATION";
	KW_FOR          = "FOR";
	KW_FORWARD      = "FORWARD";
	KW_FUNCTION     = "FUNCTION";
	KW_IF           = "IF";
	KW_IMPLEMENTATION = "IMPLEMENTATION";
	KW_IN           = "IN";
	KW_INC          = "INC";
	KW_INITIALIZATION = "INITIALIZATION";
	KW_INT16        = "INT16";
	KW_INT32        = "INT32";
	KW_INT64        = "INT64";
	KW_INTEGER      = "INTEGER";
	KW_INTERFACE    = "INTERFACE";
	KW_IS           = "IS";
	KW_LONGINT      = "LONGINT";
	KW_MOD          = "MOD";
	KW_NIL          = "NIL";
	KW_NOT          = "NOT";
	KW_OBJECT       = "OBJECT";
	KW_OF           = "OF";
	KW_OR           = "OR";
	KW_ORD          = "ORD";
	KW_PACKED       = "PACKED";
	KW_POINTER      = "POINTER";
	KW_PROCEDURE    = "PROCEDURE";
	KW_PROGRAM      = "PROGRAM";
	KW_REAL         = "REAL";
	KW_RECORD       = "RECORD";
	KW_REPEAT       = "REPEAT";
	KW_SHORTINT     = "SHORTINT";
	KW_SINGLE       = "SINGLE";
	KW_SMALLINT     = "SMALLINT";
	KW_STRING       = "STRING";
	KW_THEN         = "THEN";
	KW_TO           = "TO";
	KW_TRUE         = "TRUE";
	KW_TYPE         = "TYPE";
	KW_UNIT         = "UNIT";
	KW_UNTIL        = "UNTIL";
	KW_USES         = "USES";
	KW_VAR          = "VAR";
	KW_WHILE        = "WHILE";
	KW_WITH         = "WITH";

TYPE

	Scanner = OBJECT
	VAR
		buffer: Strings.String;
		pos: LONGINT;	(*pos in buffer*)
		ch: CHAR;	(**look-ahead *)
		str, strUp: ARRAY 1024 OF CHAR;
		itemCompare: KeywordsMapItem;
		sym: LONGINT;
		lastpos, curpos, errpos: LONGINT;	(*pos in text*)
		cw: Streams.StringWriter;

		PROCEDURE &Init;
		BEGIN
			NEW(itemCompare);
			NEW(itemCompare.key, 256);
			NEW(cw, 1024);
		END Init;

		PROCEDURE NextChar;
		BEGIN
			IF pos < LEN(buffer) THEN
				ch := buffer[pos]; INC(pos)
			ELSE
				ch := Eot
			END;
			IF newChar[ORD(ch)] THEN INC(curpos) END; (* curpos := pos; *)
		END NextChar;

		PROCEDURE Str(VAR sym: LONGINT);
		VAR
			i: LONGINT;
			och: CHAR;
		BEGIN
			i := 0; och := ch;
			LOOP
				NextChar;
				IF ch = och THEN EXIT END;
				str[i] := ch; INC(i)
			END ;
			NextChar;
			str[i] := 0X;
			sym := sym_string
		END Str;

		PROCEDURE Space(VAR sym: LONGINT);
		VAR i: LONGINT;
		BEGIN
			i := 1;
			str[0] := ch;
			sym := sym_space;
			LOOP
				NextChar;
				IF ~((ch = SP) OR (ch = TAB)) THEN str[i] := 0X; EXIT END;
				str[i] := ch; INC(i)
			END;
			(* Convert SP to TAB *)
			
		END Space;

		PROCEDURE Identifier(VAR sym: LONGINT);
		VAR
			i: LONGINT;
		BEGIN i := 0;
			REPEAT
				str[i] := ch; INC(i); NextChar
			UNTIL reservedChar[ORD(ch)] OR (i = LEN(str));
			IF i = LEN(str) THEN DEC(i) END;
			str[i] := 0X; sym := sym_ident;
			COPY(str, strUp);
			Strings.UpperCase(strUp)
		END Identifier;

		PROCEDURE Hex;
		VAR
			i: LONGINT;
		BEGIN
			i := 1;
			str[0] := ch;
			LOOP
				NextChar;
				IF ~hexChar[ORD(ch)] THEN str[i] := 0X; EXIT END;
				str[i] := ch; INC(i)
			END;
			Strings.TrimLeft(str, '0');
			Strings.UpperCase(str);
			IF (str[0] = 0X) OR (('A' <= str[0]) & (str[0] <= 'F')) THEN
				Strings.Concat('0', str, str)
			END
		END Hex;
		
		PROCEDURE Num;
		VAR
			i, n: LONGINT;
			strTemp: ARRAY 24 OF CHAR;
		BEGIN
			i := 1;
			strTemp[0] := ch;
			LOOP
				NextChar;
				IF ~(('0' <= ch) & (ch <= '9')) THEN strTemp[i] := 0X; EXIT END;
				strTemp[i] := ch; INC(i)
			END;
			Strings.TrimLeft(strTemp, '0');
			Strings.StrToInt(strTemp, n);
			Strings.IntToHexStr(n, 16, str);
			Strings.TrimLeft(str, '0');
			IF (str[0] = 0X) OR (('A' <= str[0]) & (str[0] <= 'F')) THEN
				Strings.Concat('0', str, str)
			END
		END Num;

		PROCEDURE CommentStar(VAR sym: LONGINT);
		BEGIN
			cw.Reset;
			NextChar;
			LOOP
				IF ch = "*" THEN
					NextChar;
					IF ch = ")" THEN
						NextChar; EXIT
					ELSIF (ch = Eot) THEN
						cw.Char('*'); EXIT
					ELSE
						cw.Char('*'); cw.Char(ch)
					END
				ELSIF ch = Eot THEN
					EXIT
				ELSE
					 cw.Char(ch)
				END;
				NextChar
			END;
			cw.Update;
			cw.Get(str);
			Strings.Trim(str, SP);
			Strings.Trim(str, TAB);
			Strings.Trim(str, CR);
			Strings.Trim(str, LF);
			sym := sym_comment
		END CommentStar;

		PROCEDURE CommentBrace(VAR sym: LONGINT);
		BEGIN
			cw.Reset;
			NextChar;
			LOOP
				IF (ch = "}") OR (ch = Eot) THEN
					NextChar; EXIT
				ELSE
					cw.Char(ch)
				END;
				NextChar
			END;
			cw.Update;
			cw.Get(str);
			Strings.Trim(str, SP);
			Strings.Trim(str, TAB);
			Strings.Trim(str, CR);
			Strings.Trim(str, LF);
			sym := sym_comment
		END CommentBrace;

		PROCEDURE CommentLine(VAR sym: LONGINT);
		BEGIN
			cw.Reset;
			NextChar;
			WHILE (ch # Eot) & (ch # LF) & (ch # CR) DO
				cw.Char(ch);
				NextChar
			END;
			cw.Update;
			cw.Get(str);
			Strings.Trim(str, SP);
			Strings.Trim(str, TAB);
			Strings.Trim(str, CR);
			Strings.Trim(str, LF);
			sym := sym_comment
		END CommentLine;

		PROCEDURE Get(VAR s: LONGINT);
		BEGIN
			REPEAT
				WHILE ignoredChar[ORD(ch)] DO
					IF ch = Eot THEN s := sym_eof; RETURN
					ELSE NextChar
					END
				END;
				lastpos := curpos - 1;
				errpos := curpos - 1;
				CASE CAP(ch) OF
				| LF: s := sym_newLine; NextChar
				| SP, TAB: Space(s)
				| "(": NextChar;
					IF ch = "*" THEN CommentStar(s)
					ELSE s := sym_lparen
					END
				| "{": CommentBrace(s)
				| "/": NextChar;
					IF ch = "/" THEN CommentLine(s)
					ELSE s := sym_slash
					END
				| "'", '"': Str(s)
				| "#": NextChar;
						IF ch = "$" THEN NextChar;
							IF hexChar[ORD(ch)] THEN
								Hex; sym := sym_hex_char
							END
						ELSIF ('0' <= ch) & (ch <= '9') THEN
							Num; sym := sym_hex_char
						END
				| "$": NextChar;
						IF hexChar[ORD(ch)] THEN
							Hex; sym := sym_hex
						END
				| ")": s := sym_rparen; NextChar
				| "*": s := sym_times; NextChar
				| "+": s := sym_plus; NextChar
				| ",": s := sym_comma; NextChar
				| "-": s := sym_minus; NextChar
				| ".": NextChar;
						IF ch = "." THEN NextChar; s := sym_upto
						ELSE s := sym_period
						END
				| ":": NextChar;
						IF ch = "=" THEN NextChar; s := sym_becomes
						ELSE s := sym_colon
						END
				| ";": s := sym_semicolon; NextChar
				| "<": NextChar;
						IF ch = "=" THEN NextChar; s := sym_leq
						ELSIF ch = ">" THEN NextChar; s := sym_neq
						ELSE s := sym_lss
						END
				| "=": s :=  sym_eql; NextChar
				| ">": NextChar;
						IF ch = "=" THEN NextChar; s := sym_geq
						ELSE s := sym_gtr
						END
				| "A".."Z": Identifier(s);
						(*COPY(strUp, itemCompare.key^);
						iKW := mapKeywords.IndexOf(itemCompare);
						IF iKW # -1 THEN
							s := mapKeywords.GetItem(iKW)(KeywordsMapItem).sym
						END;*)
						COPY(strUp, itemCompare.key^);
						IF mapKeywords.Contains(itemCompare) THEN
							s := mapKeywords.Get(itemCompare)
						END;
				| "[": s := sym_lbrak; NextChar
				| "]": s := sym_rbrak; NextChar
				| "^": s := sym_arrow; NextChar
				| 7FX: s := sym_upto; NextChar
				ELSE Identifier(s); (* s := null; NextChar; *)
				END;
			UNTIL s >= 0;
		END Get;

		PROCEDURE Next;
		BEGIN
			Get(sym)
		END Next;

	END Scanner;
	
	KeywordsMapItem = POINTER TO RECORD
		key: Strings.String;
		sym: LONGINT;
	END;
	
	KeywordsMap = OBJECT(Containers.CustomSet)
			
		PROCEDURE &New;
		BEGIN
			NEW(dictionary, KeywordsMapItemsEqual, KeywordsMapItemHash)
		END New;
		
		PROCEDURE KeywordsMapItemsEqual(first, second: ANY): BOOLEAN;
		BEGIN
			RETURN first(KeywordsMapItem).key^ = second(KeywordsMapItem).key^
		END KeywordsMapItemsEqual;
		
		PROCEDURE KeywordsMapItemHash(item: ANY): LONGINT;
		BEGIN
			RETURN Containers.HashString(item(KeywordsMapItem).key)
		END KeywordsMapItemHash;
				
		PROCEDURE Add(CONST key: ARRAY OF CHAR; sym: LONGINT);
		VAR
			item: KeywordsMapItem;
		BEGIN 
			NEW(item);
			item.key := Strings.NewString(key);
			item.sym := sym;
			dictionary.Add(item)
		END Add;
		
		PROCEDURE Contains*(item: KeywordsMapItem): BOOLEAN;
		BEGIN
			RETURN dictionary.Contains(item)
		END Contains;
		
		PROCEDURE Get*(item: KeywordsMapItem): LONGINT;
		VAR
			p: ANY;
		BEGIN
			p := dictionary.Get(item);
			IF p # NIL THEN
				RETURN p(KeywordsMapItem).sym
			ELSE
				RETURN 0
			END
		END Get;
		
	END KeywordsMap;
	
	Ext = POINTER TO RECORD
		strExt: ARRAY 4 OF CHAR;
		extNext: Ext;
	END;
	
VAR

	reservedChar, ignoredChar, newChar, hexChar: ARRAY 256 OF BOOLEAN;
	exts: Ext;
	mapKeywords: KeywordsMap;
	
	PROCEDURE AddExt(str: ARRAY OF CHAR);
	VAR
		ext: Ext;
	BEGIN
		NEW(ext);
		COPY(str, ext.strExt);
		ext.extNext := exts;
		exts := ext
	END AddExt;

	PROCEDURE InitReservedChars;
	VAR
		i: LONGINT;
	BEGIN
		FOR i := 0 TO LEN(reservedChar)-1 DO
			IF CHR(i) <= 20X THEN	(* TAB, CR, ESC ... *)
				reservedChar[i] := TRUE;
			ELSE
				CASE CHR(i) OF
					| "#", "&", "(", ")", "*", "+", ",", "-", ".", "/", "?": reservedChar[i] := TRUE;
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

	PROCEDURE InitIgnoredChar;
	VAR
		i: LONGINT;
	BEGIN
		FOR i := 0 TO LEN(ignoredChar)-1 DO
			ignoredChar[i] :=
			  (i < ORD(SP)) & (i # ORD(TAB)) & (i # ORD(LF)) & (i # ORD(SP))
		END
	END InitIgnoredChar;
	
	PROCEDURE InitHexChar;
	VAR
		i: LONGINT;
		ch: CHAR;
	BEGIN
		FOR i := 0 TO LEN(hexChar) - 1 DO
			ch := CHR(i);
			hexChar[i] := (('a' <= ch) & (ch <= 'f')) OR
				(('A' <= ch) & (ch <= 'H')) OR
				(('0' <= ch) & (ch <= '9'))
		END
	END InitHexChar;

	PROCEDURE InitKeywordsList;
	BEGIN
		NEW(mapKeywords);
		mapKeywords.Add(KW_AND, sym_and);
		mapKeywords.Add(KW_ARRAY, sym_array);
		mapKeywords.Add(KW_ASM, sym_code);
		mapKeywords.Add(KW_BEGIN, sym_begin);
		mapKeywords.Add(KW_BOOLEAN, sym_boolean);
		mapKeywords.Add(KW_CASE, sym_case);
		mapKeywords.Add(KW_CHAR, sym_char);
		mapKeywords.Add(KW_CHR, sym_chr);
		mapKeywords.Add(KW_CLASS, sym_object);
		mapKeywords.Add(KW_CONST, sym_const);
		mapKeywords.Add(KW_DEC, sym_dec);
		mapKeywords.Add(KW_DIV, sym_div);
		mapKeywords.Add(KW_DO, sym_do);
		mapKeywords.Add(KW_DOUBLE, sym_double);
		mapKeywords.Add(KW_ELSE, sym_else);
		mapKeywords.Add(KW_END, sym_end);
		mapKeywords.Add(KW_EXIT, sym_exit);
		mapKeywords.Add(KW_EXTENDED, sym_double);
		mapKeywords.Add(KW_FALSE, sym_false);
		mapKeywords.Add(KW_FILE, sym_file);
		mapKeywords.Add(KW_FINALIZATION, sym_finalization);
		mapKeywords.Add(KW_FOR, sym_for);
		mapKeywords.Add(KW_FORWARD, sym_forward);
		mapKeywords.Add(KW_FUNCTION, sym_procedure);
		mapKeywords.Add(KW_IF, sym_if);
		mapKeywords.Add(KW_IMPLEMENTATION, sym_implementation);
		mapKeywords.Add(KW_IN, sym_in);
		mapKeywords.Add(KW_INC, sym_inc);
		mapKeywords.Add(KW_INITIALIZATION, sym_begin);
		mapKeywords.Add(KW_INT16, sym_smallint);
		mapKeywords.Add(KW_INT32, sym_longint);
		mapKeywords.Add(KW_INT64, sym_int64);
		mapKeywords.Add(KW_INTEGER, sym_longint);
		mapKeywords.Add(KW_INTERFACE, sym_interface);
		mapKeywords.Add(KW_IS, sym_is);
		mapKeywords.Add(KW_LONGINT, sym_longint);
		mapKeywords.Add(KW_MOD, sym_mod);
		mapKeywords.Add(KW_NIL, sym_nil);
		mapKeywords.Add(KW_NOT, sym_not);
		mapKeywords.Add(KW_OBJECT, sym_object);
		mapKeywords.Add(KW_OF, sym_of);
		mapKeywords.Add(KW_OR, sym_or);
		mapKeywords.Add(KW_ORD, sym_ord);
		mapKeywords.Add(KW_PACKED, sym_packed);
		mapKeywords.Add(KW_POINTER, sym_pointer);
		mapKeywords.Add(KW_PROCEDURE, sym_procedure);
		mapKeywords.Add(KW_PROGRAM, sym_module);
		mapKeywords.Add(KW_REAL, sym_single);
		mapKeywords.Add(KW_RECORD, sym_record);
		mapKeywords.Add(KW_REPEAT, sym_repeat);
		mapKeywords.Add(KW_SHORTINT, sym_shortint);
		mapKeywords.Add(KW_SINGLE, sym_single);
		mapKeywords.Add(KW_SMALLINT, sym_smallint);
		mapKeywords.Add(KW_STRING, sym_pas_string);
		mapKeywords.Add(KW_THEN, sym_then);
		mapKeywords.Add(KW_TO, sym_to);
		mapKeywords.Add(KW_TRUE, sym_true);
		mapKeywords.Add(KW_TYPE, sym_type);
		mapKeywords.Add(KW_UNIT, sym_module);
		mapKeywords.Add(KW_UNTIL, sym_until);
		mapKeywords.Add(KW_USES, sym_import);
		mapKeywords.Add(KW_VAR, sym_var);
		mapKeywords.Add(KW_WHILE, sym_while);
		mapKeywords.Add(KW_WITH, sym_with);
	END InitKeywordsList;

	PROCEDURE PreprocessFile(context: Commands.Context; CONST strFileName: ARRAY OF CHAR);
	VAR
		fileIn, fileOut: Files.File;
		r: Files.Rider;
		w: Files.Writer;
		buffer: Strings.String;
		s: Scanner;
		strName, strExt, strNewFileName: ARRAY 1024 OF CHAR;
		
		PROCEDURE WriteComment(strComment: ARRAY OF CHAR);
		BEGIN
			w.String("(* ");
			IF strComment[0] = 0X THEN w.Char(' ')
			ELSE w.String(strComment)
			END;
			w.String(" *)")
		END WriteComment;
		
		PROCEDURE PackSpaces(VAR str: ARRAY OF CHAR);
		VAR
			iIn, iOut, nSP: LONGINT;
		BEGIN
			iIn := 0;
			iOut := 0;
			nSP := 0;
			WHILE (iIn < LEN(str)) & (str[iIn] # 0X) DO
				IF str[iIn] = TAB THEN
					IF iIn # iOut THEN
						str[iOut] := TAB
					END;
					INC(iOut)
				ELSIF str[iIn] = SP THEN
					IF nSP = 1 THEN
						nSP := 0;
						str[iOut] := TAB;
						INC(iOut)
					ELSE
						INC(nSP)
					END
				END;
				INC(iIn)
			END;
			str[iOut] := 0X
		END PackSpaces;
		
		PROCEDURE Case(sym: LONGINT);
		BEGIN
			CASE sym OF
			| sym_ident, sym_space: w.String(s.str);
			| sym_newLine: w.Ln;
					s.Next;
					IF s.sym = sym_space THEN
						PackSpaces(s.str);
						w.String(s.str)
					ELSE
						Case(s.sym)
					END
			| sym_comment: WriteComment(s.str)
			| sym_hex: w.String(s.str); w.Char('H')
			| sym_hex_char: w.String(s.str); w.Char('X')
			| sym_string: w.Char('"');
			    w.String(s.str);
			    w.Char('"');
			| sym_code: w.String(KW_CODE)
			| sym_arrow: s.Next;
					IF (s.sym = sym_ident) OR (s.sym = sym_array) OR
						(s.sym = sym_boolean) OR (s.sym = sym_double) OR
						(s.sym = sym_int64) OR (s.sym = sym_longint) OR
						(s.sym = sym_record) OR (s.sym = sym_shortint) OR
						(s.sym = sym_single) OR (s.sym = sym_pas_string) OR
						(s.sym = sym_pointer) OR (s.sym = sym_smallint)
					THEN
						w.String("POINTER TO ")
					ELSE
						w.Char('^')
					END;
					Case(s.sym)
			| sym_and: w.Char('&');
			| sym_becomes: w.String(':=');
			| sym_colon: w.Char(':');
			| sym_comma: w.Char(',');
			| sym_eql: w.Char('=');
			| sym_geq: w.String('>=');
			| sym_gtr: w.Char('>');
			| sym_lbrak: w.Char('[');
			| sym_leq: w.String('<=');
			| sym_lparen: w.Char('(');
			| sym_lss: w.Char('<');
			| sym_minus: w.Char('-');
			| sym_neq: w.Char('#');
			| sym_not: w.Char('~');
			| sym_period: w.Char('.');
			| sym_plus: w.Char('+');
			| sym_rbrak: w.Char(']');
			| sym_rparen: w.Char(')');
			| sym_semicolon: w.Char(';');
			| sym_slash: w.Char('/');
			| sym_times: w.Char('*');
			| sym_upto: w.String('..');

			| sym_array: w.String(KW_ARRAY);
			| sym_begin: w.String(KW_BEGIN);
			| sym_boolean: w.String(KW_BOOLEAN);
			| sym_case: w.String(KW_CASE);
			| sym_char: w.String(KW_CHAR);
			| sym_chr: w.String(KW_CHR);
			| sym_const: w.String(KW_CONST);
			| sym_dec: w.String(KW_DEC);
			| sym_div: w.String(KW_DIV);
			| sym_do: w.String(KW_DO);
			| sym_double: w.String(KW_LONGREAL);
			| sym_else: w.String(KW_ELSE);
			| sym_end: w.String(KW_END);
			| sym_exit: w.String(KW_EXIT);
			| sym_false: w.String(KW_FALSE);
			| sym_file: w.String("Files.File");
			| sym_finalization: WriteComment(KW_FINALIZATION)
			| sym_for: w.String(KW_FOR);
			| sym_forward: WriteComment(KW_FORWARD)
			| sym_if: w.String(KW_IF);
			| sym_implementation: WriteComment(KW_IMPLEMENTATION);
			| sym_import: w.String(KW_IMPORT);
			| sym_in: w.String(KW_IN);
			| sym_inc: w.String(KW_INC);
			| sym_interface: WriteComment(KW_INTERFACE)
			| sym_int64: w.String(KW_HUGEINT);
			| sym_is: w.String(KW_IS);
			| sym_longint: w.String(KW_LONGINT);
			| sym_mod: w.String(KW_MOD);
			| sym_module: w.String(KW_MODULE);
			| sym_nil: w.String(KW_NIL);
			| sym_object: w.String(KW_OBJECT);
			| sym_of: w.String(KW_OF);
			| sym_or: w.String(KW_OR);
			| sym_ord: w.String(KW_ORD);
			| sym_packed: WriteComment(KW_PACKED)
			| sym_pas_string: w.String("ARRAY OF CHAR");
			| sym_pointer: w.String(KW_ANY);
			| sym_procedure: w.String(KW_PROCEDURE);
			| sym_record: w.String(KW_RECORD);
			| sym_repeat: w.String(KW_REPEAT);
			| sym_shortint: w.String(KW_SHORTINT);
			| sym_single: w.String(KW_REAL);
			| sym_smallint: w.String(KW_INTEGER);
			| sym_then: w.String(KW_THEN);
			| sym_to: w.String(KW_TO);
			| sym_true: w.String(KW_TRUE);
			| sym_type: w.String(KW_TYPE);
			| sym_until: w.String(KW_UNTIL);
			| sym_var: w.String(KW_VAR);
			| sym_while: w.String(KW_WHILE);
			| sym_with: w.String(KW_WITH);

			ELSE
			END;
		END Case;

	BEGIN
		fileIn := Files.Old(strFileName);
		IF fileIn = NIL THEN
			context.out.String(" file not found.");
			RETURN
		END;
		fileIn.Set(r, 0);
		Strings.GetExtension(strFileName, strName, strExt);
		Strings.Concat(strName, ".Mod", strNewFileName);
		fileOut := Files.New(strNewFileName);
		IF fileOut = NIL THEN
			context.out.String(" can't create file.");
			RETURN
		END;
		Files.OpenWriter(w, fileOut, 0);
		NEW(buffer, fileIn.Length() + 1);
		r.file.ReadBytes(r, buffer^, 0, fileIn.Length());
		buffer[LEN(buffer) - 1] := 0X;
		NEW(s); s.buffer := buffer;
		s.pos := 0;
		s.ch := " ";
		s.Next; s.Next;
		WHILE s.sym # sym_eof DO
			Case(s.sym);
			s.Next
		END;
		w.Update;
		Files.Register(fileOut);
		fileOut.Close;
		context.out.String(" done.");
	END PreprocessFile;

	PROCEDURE Preprocess*(context: Commands.Context);
	VAR
		strFileName, strName, strExt: ARRAY 1024 OF CHAR;
		ext: Ext;
		t: HUGEINT;
	BEGIN
		context.out.Ln;
		WHILE context.arg.GetString(strFileName) DO
			context.out.String("Preprocessing: ");
			context.out.String(strFileName);
			context.out.Update;
			Strings.GetExtension(strFileName, strName, strExt);
			Strings.UpperCase(strExt);
			ext := exts;
			WHILE (ext # NIL) & (strExt # ext.strExt) DO
				ext := ext.extNext
			END;
			IF ext # NIL THEN
				t := PreciseTimer.GetTicks();
				PreprocessFile(context, strFileName);
				t := PreciseTimer.GetTicks() - t;
				context.out.Ln;
				context.out.String("Time: ");
				context.out.Float(PreciseTimer.GetTime(t), 15)
			END;
			context.out.Ln;
			context.out.Update;
		END;
	END Preprocess;

BEGIN
	InitReservedChars;
	InitNewChar;
	InitIgnoredChar;
	InitHexChar;
	exts := NIL;
	AddExt("PAS");
	AddExt("DPR");
	AddExt("PP");
	InitKeywordsList
END PascalPreprocessor.

System.Free PascalPreprocessor ~

PascalPreprocessor.Preprocess Doom32/Doom32_combined.dpr Doom32/Doom32_combined_unit.pas ~


