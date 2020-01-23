MODULE PascalScanner; (** AUTHOR "Yaroslav Romanchenko rapturize@gmail.com";
	PURPOSE "Object Pascal scanner"; *)

IMPORT
	Streams, Strings, Containers;

CONST
	Eot	= 0X;

	TAB	= 09X;
	LF	= 0AX;
	CR	= 0DX;
	SP	= 20X;

	(** Symbols *)

	sym_arrow* = 1; (* ^ *)
	sym_becomes* = 2; (* := *)
	sym_colon* = 3; (* : *)
	sym_comma* = 4; (* , *)
	sym_eql* = 5; (* = *)
	sym_geq* = 6; (* >= *)
	sym_gtr* = 7; (* > *)
	sym_lbrak* = 8; (* [ *)
	sym_leq* = 9; (* <= *)
	sym_lparen* = 10; (* ( *)
	sym_lss* = 11; (* < *)
	sym_minus* = 12; (* - *)
	sym_neq* = 13; (* <> *)
	sym_period* = 14; (* . *)
	sym_plus* = 15; (* + *)
	sym_rbrak* = 16; (* ] *)
	sym_rparen* = 17; (* ) *)
	sym_semicolon* = 18; (* ; *)
	sym_slash* = 19; (* / *)
	sym_times* = 20; (* * *)
	sym_upto* = 21; (* .. *)

	(* Special cases: character strings, numbers, comments, identifiers, ... *)
	sym_char_string* = 22; (* a character string *)
	sym_comment* = 23; (* an any comment *)
	sym_eof* = 24; (* end of file *)
	sym_hex_char* = 25; (* a hex char *)
	sym_hex* = 26; (* a hex number *)
	sym_ident* = 27; (* an indentifier *)
	sym_new_line* = 28; (* a new line *)
	sym_space* = 29; (* a space *)

	(** Object Pascal reserved words symbols *)

	RW_BASE = sym_space;

	sym_and* = RW_BASE + 1;
	sym_array* = RW_BASE + 2;
	sym_as* = RW_BASE + 3;
	sym_asm* = RW_BASE + 4;
	sym_begin* = RW_BASE + 5;
	sym_case* = RW_BASE + 6;
	sym_class* = RW_BASE + 7;
	sym_const* = RW_BASE + 8;
	sym_constructor* = RW_BASE + 9;
	sym_destructor* = RW_BASE + 10;
	sym_dispinterface* = RW_BASE + 11;
	sym_div* = RW_BASE + 12;
	sym_do* = RW_BASE + 13;
	sym_downto* = RW_BASE + 14;
	sym_else* = RW_BASE + 15;
	sym_end* = RW_BASE + 16;
	sym_except* = RW_BASE + 17;
	sym_exports* = RW_BASE + 18;
	sym_file* = RW_BASE + 19;
	sym_finalization* = RW_BASE + 20;
	sym_finally* = RW_BASE + 21;
	sym_for* = RW_BASE + 22;
	sym_function* = RW_BASE + 23;
	sym_goto* = RW_BASE + 24;
	sym_if* = RW_BASE + 25;
	sym_implementation* = RW_BASE + 26;
	sym_in* = RW_BASE + 27;
	sym_inherited* = RW_BASE + 28;
	sym_initialization* = RW_BASE + 29;
	sym_inline* = RW_BASE + 30;
	sym_interface* = RW_BASE + 31;
	sym_is* = RW_BASE + 32;
	sym_label* = RW_BASE + 33;
	sym_library* = RW_BASE + 34;
	sym_mod* = RW_BASE + 35;
	sym_nil* = RW_BASE + 36;
	sym_not* = RW_BASE + 37;
	sym_object* = RW_BASE + 38;
	sym_of* = RW_BASE + 39;
	sym_or* = RW_BASE + 40;
	sym_out* = RW_BASE + 41;
	sym_packed* = RW_BASE + 42;
	sym_procedure* = RW_BASE + 43;
	sym_program* = RW_BASE + 44;
	sym_property* = RW_BASE + 45;
	sym_raise* = RW_BASE + 46;
	sym_record* = RW_BASE + 47;
	sym_repeat* = RW_BASE + 48;
	sym_resourcestring* = RW_BASE + 49;
	sym_set* = RW_BASE + 50;
	sym_shl* = RW_BASE + 51;
	sym_shr* = RW_BASE + 52;
	sym_string* = RW_BASE + 53;
	sym_then* = RW_BASE + 54;
	sym_threadvar* = RW_BASE + 55;
	sym_to* = RW_BASE + 56;
	sym_try* = RW_BASE + 57;
	sym_type* = RW_BASE + 58;
	sym_unit* = RW_BASE + 59;
	sym_until* = RW_BASE + 60;
	sym_uses* = RW_BASE + 61;
	sym_var* = RW_BASE + 62;
	sym_while* = RW_BASE + 63;
	sym_with* = RW_BASE + 64;
	sym_xor* = RW_BASE + 65;

	(** Object Pascal directives symbols *)

	DIR_BASE = sym_xor;

	sym_absolute* = DIR_BASE + 1;
	sym_abstract* = DIR_BASE + 2;
	sym_assembler* = DIR_BASE + 3;
	sym_automated* = DIR_BASE + 4;
	sym_cdecl* = DIR_BASE + 5;
	sym_contains* = DIR_BASE + 6;
	sym_default* = DIR_BASE + 7;
	sym_deprecated* = DIR_BASE + 8;
	sym_dispid* = DIR_BASE + 9;
	sym_dynamic* = DIR_BASE + 10;
	sym_export* = DIR_BASE + 11;
	sym_external* = DIR_BASE + 12;
	sym_far* = DIR_BASE + 13;
	sym_forward* = DIR_BASE + 14;
	sym_implements* = DIR_BASE + 15;
	sym_index* = DIR_BASE + 16;
	sym_local* = DIR_BASE + 17;
	sym_message* = DIR_BASE + 18;
	sym_name* = DIR_BASE + 19;
	sym_near* = DIR_BASE + 20;
	sym_nodefault* = DIR_BASE + 21;
	sym_overload* = DIR_BASE + 22;
	sym_override* = DIR_BASE + 23;
	sym_package* = DIR_BASE + 24;
	sym_pascal* = DIR_BASE + 25;
	sym_platform* = DIR_BASE + 26;
	sym_private* = DIR_BASE + 27;
	sym_protected* = DIR_BASE + 28;
	sym_public* = DIR_BASE + 29;
	sym_published* = DIR_BASE + 30;
	sym_read* = DIR_BASE + 31;
	sym_readonly* = DIR_BASE + 32;
	sym_register* = DIR_BASE + 33;
	sym_reintroduce* = DIR_BASE + 34;
	sym_requires* = DIR_BASE + 35;
	sym_resident* = DIR_BASE + 36;
	sym_safecall* = DIR_BASE + 37;
	sym_stdcall* = DIR_BASE + 38;
	sym_stored* = DIR_BASE + 39;
	sym_varargs* = DIR_BASE + 40;
	sym_virtual* = DIR_BASE + 41;
	sym_write* = DIR_BASE + 42;
	sym_writeonly* = DIR_BASE + 43;

TYPE

	Scanner* = OBJECT
	VAR
		buffer: Strings.String;
		pos: LONGINT;	(*pos in buffer*)
		ch: CHAR;		(**look-ahead *)
		str-, strLower: ARRAY 1024 OF CHAR;
		itemCompare: KeywordsMapItem;
		sym-: LONGINT;
		lastpos-, curpos-, errpos: LONGINT;	(*pos in text*)
		cw: Streams.StringWriter;

		PROCEDURE &Init*(buffer: Strings.String);
		BEGIN
			SELF.buffer := buffer;
			ch := SP;
			pos := 0;
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
			sym := sym_char_string
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
			COPY(str, strLower);
			Strings.LowerCase(strLower)
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
				| LF: s := sym_new_line; NextChar
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
						COPY(strLower, itemCompare.key^);
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

		PROCEDURE Next*;
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

VAR

	reservedChar, ignoredChar, newChar, hexChar: ARRAY 256 OF BOOLEAN;
	mapKeywords: KeywordsMap;

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
		mapKeywords.Add("and", sym_and);
		mapKeywords.Add("array", sym_array);
		mapKeywords.Add("as", sym_as);
		mapKeywords.Add("asm", sym_asm);
		mapKeywords.Add("begin", sym_begin);
		mapKeywords.Add("case", sym_case);
		mapKeywords.Add("class", sym_class);
		mapKeywords.Add("const", sym_const);
		mapKeywords.Add("constructor", sym_constructor);
		mapKeywords.Add("destructor", sym_destructor);
		mapKeywords.Add("dispinterface", sym_dispinterface);
		mapKeywords.Add("div", sym_div);
		mapKeywords.Add("do", sym_do);
		mapKeywords.Add("downto", sym_downto);
		mapKeywords.Add("else", sym_else);
		mapKeywords.Add("end", sym_end);
		mapKeywords.Add("except", sym_except);
		mapKeywords.Add("exports", sym_exports);
		mapKeywords.Add("file", sym_file);
		mapKeywords.Add("finalization", sym_finalization);
		mapKeywords.Add("finally", sym_finally);
		mapKeywords.Add("for", sym_for);
		mapKeywords.Add("function", sym_function);
		mapKeywords.Add("goto", sym_goto);
		mapKeywords.Add("if", sym_if);
		mapKeywords.Add("implementation", sym_implementation);
		mapKeywords.Add("in", sym_in);
		mapKeywords.Add("inherited", sym_inherited);
		mapKeywords.Add("initialization", sym_initialization);
		mapKeywords.Add("inline", sym_inline);
		mapKeywords.Add("interface", sym_interface);
		mapKeywords.Add("is", sym_is);
		mapKeywords.Add("label", sym_label);
		mapKeywords.Add("library", sym_library);
		mapKeywords.Add("mod", sym_mod);
		mapKeywords.Add("nil", sym_nil);
		mapKeywords.Add("not", sym_not);
		mapKeywords.Add("object", sym_object);
		mapKeywords.Add("of", sym_of);
		mapKeywords.Add("or", sym_or);
		mapKeywords.Add("out", sym_out);
		mapKeywords.Add("packed", sym_packed);
		mapKeywords.Add("procedure", sym_procedure);
		mapKeywords.Add("program", sym_program);
		mapKeywords.Add("property", sym_property);
		mapKeywords.Add("raise", sym_raise);
		mapKeywords.Add("record", sym_record);
		mapKeywords.Add("repeat", sym_repeat);
		mapKeywords.Add("resourcestring", sym_resourcestring);
		mapKeywords.Add("set", sym_set);
		mapKeywords.Add("shl", sym_shl);
		mapKeywords.Add("shr", sym_shr);
		mapKeywords.Add("string", sym_string);
		mapKeywords.Add("then", sym_then);
		mapKeywords.Add("threadvar", sym_threadvar);
		mapKeywords.Add("to", sym_to);
		mapKeywords.Add("try", sym_try);
		mapKeywords.Add("type", sym_type);
		mapKeywords.Add("unit", sym_unit);
		mapKeywords.Add("until", sym_until);
		mapKeywords.Add("uses", sym_uses);
		mapKeywords.Add("var", sym_var);
		mapKeywords.Add("while", sym_while);
		mapKeywords.Add("with", sym_with);
		mapKeywords.Add("xor", sym_xor);

		mapKeywords.Add("absolute", sym_absolute);
		mapKeywords.Add("abstract", sym_abstract);
		mapKeywords.Add("assembler", sym_assembler);
		mapKeywords.Add("automated", sym_automated);
		mapKeywords.Add("cdecl", sym_cdecl);
		mapKeywords.Add("contains", sym_contains);
		mapKeywords.Add("default", sym_default);
		mapKeywords.Add("deprecated", sym_deprecated);
		mapKeywords.Add("dispid", sym_dispid);
		mapKeywords.Add("dynamic", sym_dynamic);
		mapKeywords.Add("export", sym_export);
		mapKeywords.Add("external", sym_external);
		mapKeywords.Add("far", sym_far);
		mapKeywords.Add("forward", sym_forward);
		mapKeywords.Add("implements", sym_implements);
		mapKeywords.Add("index", sym_index);
		mapKeywords.Add("local", sym_local);
		mapKeywords.Add("message", sym_message);
		mapKeywords.Add("name", sym_name);
		mapKeywords.Add("near", sym_near);
		mapKeywords.Add("nodefault", sym_nodefault);
		mapKeywords.Add("overload", sym_overload);
		mapKeywords.Add("override", sym_override);
		mapKeywords.Add("package", sym_package);
		mapKeywords.Add("pascal", sym_pascal);
		mapKeywords.Add("platform", sym_platform);
		mapKeywords.Add("private", sym_private);
		mapKeywords.Add("protected", sym_protected);
		mapKeywords.Add("public", sym_public);
		mapKeywords.Add("published", sym_published);
		mapKeywords.Add("read", sym_read);
		mapKeywords.Add("readonly", sym_readonly);
		mapKeywords.Add("register", sym_register);
		mapKeywords.Add("reintroduce", sym_reintroduce);
		mapKeywords.Add("requires", sym_requires);
		mapKeywords.Add("resident", sym_resident);
		mapKeywords.Add("safecall", sym_safecall);
		mapKeywords.Add("stdcall", sym_stdcall);
		mapKeywords.Add("stored", sym_stored);
		mapKeywords.Add("varargs", sym_varargs);
		mapKeywords.Add("virtual", sym_virtual);
		mapKeywords.Add("write", sym_write);
		mapKeywords.Add("writeonly", sym_writeonly);
	END InitKeywordsList;

BEGIN
	InitReservedChars;
	InitNewChar;
	InitIgnoredChar;
	InitHexChar;
	InitKeywordsList;
END PascalScanner.

SystemTools.Free PascalScanner ~

