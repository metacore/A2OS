MODULE CSS2Parser;	(** Stefan Walthert  *)
(** AUTHOR "swalthert"; PURPOSE ""; *)

IMPORT
	KernelLog, Strings, Scanner := CSS2Scanner, XMLObjects, CSS2, Files;

TYPE
	String = CSS2.String;

	Parser* = OBJECT
		VAR
			reportError*: PROCEDURE(pos, line, row: SIGNED32; msg: ARRAY OF CHAR);
			scanner: Scanner.Scanner;

		PROCEDURE & Init*(scanner: Scanner.Scanner);
		BEGIN
			reportError := DefaultReportError;
			SELF.scanner := scanner;
			scanner.Scan()
		END Init;

		PROCEDURE CheckSymbol(expectedSymbols: SET; errormsg: ARRAY OF CHAR): BOOLEAN;
		BEGIN
			IF scanner.sym IN expectedSymbols THEN
				RETURN TRUE
			ELSE
				Error(errormsg);
				RETURN FALSE
			END
		END CheckSymbol;

		PROCEDURE Error(msg: ARRAY OF CHAR);
		BEGIN
			reportError(scanner.GetPos(), scanner.line, scanner.row, msg)
		END Error;

		PROCEDURE Parse*(): CSS2.StyleSheet;
		VAR styleSheet: CSS2.StyleSheet; s: String;
		BEGIN
			NEW(styleSheet);
			s := scanner.GetStr();
			IF (scanner.sym = Scanner.AtKeyword) & (s^ = 'charset') THEN
				scanner.Scan();
				IF ~CheckSymbol({Scanner.String}, "charset expected") THEN RETURN styleSheet END;
				s := scanner.GetStr(); styleSheet.SetCharSet(s^);
				scanner.Scan();
				IF ~CheckSymbol({Scanner.Semicolon}, "';' expected") THEN RETURN styleSheet END;
				scanner.Scan()
			END;
			WHILE scanner.sym IN {Scanner.Cdo, Scanner.Cdc} DO scanner.Scan() END;
			s := scanner.GetStr();
			WHILE (scanner.sym = Scanner.AtKeyword) & (s^ = 'import') DO
				ParseImport(styleSheet);
				s := scanner.GetStr()
			END;
			WHILE scanner.sym # Scanner.Eof DO
				IF scanner.sym = Scanner.AtKeyword THEN
					s := scanner.GetStr();
					IF s^ = 'media' THEN
						ParseMedia(styleSheet)
					ELSIF s^ = 'page' THEN
						styleSheet.AddPage(ParsePage())
					ELSIF s^ = 'font-face' THEN
						styleSheet.AddFontFace(ParseFontFace())
					ELSE	(* skip unknown atkeyword *)
						IgnoreKeyword()
					END
				ELSIF scanner.sym # Scanner.Eof THEN
					styleSheet.AddRuleSet(ParseRuleSet())
				END;
				WHILE scanner.sym IN {Scanner.Cdo, Scanner.Cdc} DO scanner.Scan() END
			END;
			RETURN styleSheet
		END Parse;

		PROCEDURE ParseImport(styleSheet: CSS2.StyleSheet);
		VAR s: String; newParser: Parser; newScanner: Scanner.Scanner; file: Files.File;
			importedStyleSheet: CSS2.StyleSheet; media, media2, media3: SET; ruleSets: XMLObjects.Enumerator;
			ruleSet: ANY;
		BEGIN
			scanner.Scan();
			IF ~CheckSymbol({Scanner.String, Scanner.URI}, "URI expected") THEN RETURN END;
			s := scanner.GetStr();
			file := Files.Old(s^);
			IF file # NIL THEN
				NEW(newScanner, file);
				NEW(newParser, newScanner); newParser.reportError := reportError;
				importedStyleSheet := newParser.Parse()
			END;
			scanner.Scan();
			IF scanner.sym # Scanner.Ident THEN
				INCL(media, CSS2.All)
			ELSE
				s := scanner.GetStr();
				INCL(media, GetMedium(s^));
				scanner.Scan();
				WHILE scanner.sym = Scanner.Comma DO
					scanner.Scan();
					IF ~CheckSymbol({Scanner.Ident}, "medium identifier expected") THEN RETURN END;
					s := scanner.GetStr();
					INCL(media, GetMedium(s^));
					scanner.Scan()
				END
			END;
			ruleSets := importedStyleSheet.GetRuleSets();
			WHILE ruleSets.HasMoreElements() DO
				ruleSet := ruleSets.GetNext();
				media2 := ruleSet(CSS2.RuleSet).GetMedia();
				media3 := media + media2;
				IF (media3 - {CSS2.All} # {}) THEN media3 := media3 - {CSS2.All} END;
				ruleSet(CSS2.RuleSet).SetMedia(media3);
				styleSheet.AddRuleSet(ruleSet(CSS2.RuleSet))
			END;
			IF ~CheckSymbol({Scanner.Semicolon}, "';' expected") THEN RETURN END;
			scanner.Scan()
		END ParseImport;

		PROCEDURE ParseMedia(styleSheet: CSS2.StyleSheet);
		VAR s: String; media: SET; ruleSet: CSS2.RuleSet;
		BEGIN
			scanner.Scan();
			IF ~CheckSymbol({Scanner.Ident}, "medium identifier expected") THEN RETURN END;
			s := scanner.GetStr();
			INCL(media, GetMedium(s^));
			scanner.Scan();
			WHILE scanner.sym = Scanner.Comma DO
				scanner.Scan();
				IF ~CheckSymbol({Scanner.Ident}, "medium identifier expected") THEN RETURN END;
				s := scanner.GetStr();
				INCL(media, GetMedium(s^));
				scanner.Scan()
			END;
			IF ~CheckSymbol({Scanner.BraceOpen}, "'{' expected") THEN RETURN END;
			scanner.Scan();
			WHILE (scanner.sym # Scanner.BraceClose) & (scanner.sym # Scanner.Eof) & (scanner.sym # Scanner.Invalid) DO
				ruleSet := ParseRuleSet();
				ruleSet.SetMedia(media);
				styleSheet.AddRuleSet(ruleSet)
			END;
			IF ~CheckSymbol({Scanner.BraceClose}, "'}' expected") THEN RETURN END;
			scanner.Scan()
		END ParseMedia;

		PROCEDURE ParsePage(): CSS2.Page;
		VAR page: CSS2.Page; s: String;
		BEGIN
			scanner.Scan();
			IF ~CheckSymbol({Scanner.Ident, Scanner.Colon, Scanner.BraceOpen},
					"page selector, pseudo page or '{' expected") THEN RETURN page END;
			NEW(page);
			IF scanner.sym = Scanner.Ident THEN
				s := scanner.GetStr();
				page.SetSelector(s^);
				scanner.Scan()
			END;
			IF ~CheckSymbol({Scanner.Colon, Scanner.BraceOpen}, "pseudo page or '{' expected") THEN RETURN page END;
			IF scanner.sym = Scanner.Colon THEN
				scanner.Scan();
				IF ~CheckSymbol({Scanner.Ident}, "pseudo page identifier expected") THEN RETURN page END;
				s := scanner.GetStr();
				page.SetPseudoPage(GetPseudoPage(s^));
				scanner.Scan()
			END;
			IF ~CheckSymbol({Scanner.BraceOpen}, "'{' expected") THEN RETURN page END;
			scanner.Scan();
			page.AddDeclaration(ParseDeclaration());
			WHILE scanner.sym = Scanner.Semicolon DO
				scanner.Scan();
				page.AddDeclaration(ParseDeclaration());
			END;
			IF ~CheckSymbol({Scanner.BraceClose}, "'}' expected") THEN RETURN page END;
			scanner.Scan();
			RETURN page
		END ParsePage;

		PROCEDURE ParseFontFace(): CSS2.FontFace;
		VAR fontFace: CSS2.FontFace;
		BEGIN
			scanner.Scan();
			IF ~CheckSymbol({Scanner.BraceOpen}, "'{' expected") THEN RETURN fontFace END;
			NEW(fontFace);
			scanner.Scan();
			fontFace.AddDeclaration(ParseDeclaration());
			WHILE scanner.sym = Scanner.Semicolon DO
				scanner.Scan();
				fontFace.AddDeclaration(ParseDeclaration());
			END;
			IF ~CheckSymbol({Scanner.BraceClose}, "'}' expected") THEN RETURN fontFace END;
			scanner.Scan();
			RETURN fontFace
		END ParseFontFace;

		PROCEDURE ParseRuleSet(): CSS2.RuleSet;
		VAR ruleSet: CSS2.RuleSet;
		BEGIN
			NEW(ruleSet);
			ruleSet.AddSelector(ParseSelector());
			WHILE scanner.sym = Scanner.Comma DO
				scanner.Scan();
				ruleSet.AddSelector(ParseSelector())
			END;
			IF ~CheckSymbol({Scanner.BraceOpen}, "'{' expected") THEN RETURN ruleSet END;
			scanner.Scan();
			ruleSet.AddDeclaration(ParseDeclaration());
			WHILE scanner.sym = Scanner.Semicolon DO
				scanner.Scan();
				IF scanner.sym # Scanner.BraceClose THEN ruleSet.AddDeclaration(ParseDeclaration()) END
			END;
			IF ~CheckSymbol({Scanner.BraceClose}, "'}' expected") THEN RETURN ruleSet END;
			scanner.Scan();
			RETURN ruleSet
		END ParseRuleSet;

		PROCEDURE ParseSelector(): CSS2.Selector;
		VAR selector: CSS2.Selector;
		BEGIN
			NEW(selector);
			selector.AddSimpleSelector(ParseSimpleSelector());
			WHILE scanner.sym IN {Scanner.Ident, Scanner.Asterisk, Scanner.Hash, Scanner.Dot, Scanner.BracketOpen,
					Scanner.Colon, Scanner.Greater, Scanner.Plus} DO
				selector.AddSimpleSelector(ParseSimpleSelector())
			END;
			RETURN selector
		END ParseSelector;

		PROCEDURE ParseSimpleSelector(): CSS2.SimpleSelector;
		VAR simpleSelector: CSS2.SimpleSelector; s: String;
		BEGIN
			NEW(simpleSelector);
			IF scanner.sym = Scanner.Plus THEN
				simpleSelector.SetCombinator(CSS2.Sibling); scanner.Scan()
			ELSIF scanner.sym = Scanner.Greater THEN
				simpleSelector.SetCombinator(CSS2.Child); scanner.Scan()
			ELSE
				simpleSelector.SetCombinator(CSS2.Descendant)
			END;
			IF scanner.sym = Scanner.Ident THEN
				s := scanner.GetStr();
				simpleSelector.SetElementName(s^); scanner.Scan()
			ELSE
				NEW(s, 2); s[0] := '*'; s[1] := 0X;
				simpleSelector.SetElementName(s^);
				IF scanner.sym = Scanner.Asterisk THEN scanner.Scan() END
			END;
			WHILE scanner.sym IN {Scanner.Hash, Scanner.Dot, Scanner.BracketOpen, Scanner.Colon} DO
				CASE scanner.sym OF
				| Scanner.Hash: simpleSelector.AddSubSelector(ParseId())
				| Scanner.Dot: simpleSelector.AddSubSelector(ParseClass())
				| Scanner.BracketOpen: simpleSelector.AddSubSelector(ParseAttribute())
				| Scanner.Colon: simpleSelector.AddSubSelector(ParsePseudo())
				ELSE	(* do nothing *)
				END
			END;
			RETURN simpleSelector
		END ParseSimpleSelector;

		PROCEDURE ParseId(): CSS2.Id;
		VAR id: CSS2.Id; s: String;
		BEGIN
			IF ~CheckSymbol({Scanner.Hash}, "'#'element id expected") THEN RETURN id END;
			NEW(id);
			s := scanner.GetStr();
			id.SetValue(s^);
			scanner.Scan();
			RETURN id
		END ParseId;

		PROCEDURE ParseClass(): CSS2.Class;
		VAR class: CSS2.Class; s: String;
		BEGIN
			IF ~CheckSymbol({Scanner.Dot}, "'.'class value expected") THEN RETURN class END;
			scanner.Scan();
			IF ~CheckSymbol({Scanner.Ident}, "class value expected") THEN RETURN class END;
			NEW(class);
			s := scanner.GetStr();
			class.SetValue(s^);
			scanner.Scan();
			RETURN class
		END ParseClass;

		PROCEDURE ParseAttribute(): CSS2.Attribute;
		VAR attribute: CSS2.Attribute; s: String;
		BEGIN
			IF ~CheckSymbol({Scanner.BracketOpen}, "'[' expected") THEN RETURN attribute END;
			scanner.Scan();
			IF ~CheckSymbol({Scanner.Ident}, "attribute name expected") THEN RETURN attribute END;
			NEW(attribute);
			s := scanner.GetStr();
			attribute.SetName(s^);
			scanner.Scan();
			IF scanner.sym IN {Scanner.Equal, Scanner.Includes, Scanner.Dashmatch} THEN
				CASE scanner.sym OF
				| Scanner.Equal: attribute.SetRelation(CSS2.Equal)
				| Scanner.Includes: attribute.SetRelation(CSS2.Includes)
				| Scanner.Dashmatch: attribute.SetRelation(CSS2.Dashmatch)
				END;
				scanner.Scan();
				IF ~CheckSymbol({Scanner.Ident, Scanner.String}, "attribute value expected") THEN RETURN attribute END;
				s := scanner.GetStr();
				attribute.SetValue(s^);
				scanner.Scan()
			END;
			IF ~CheckSymbol({Scanner.BracketClose}, "']' expected") THEN RETURN attribute END;
			scanner.Scan();
			RETURN attribute
		END ParseAttribute;

		PROCEDURE ParsePseudo(): CSS2.Pseudo;
		VAR pseudo: CSS2.Pseudo; s: String;
		BEGIN
			IF ~CheckSymbol({Scanner.Colon}, "':' expected") THEN RETURN pseudo END;
			scanner.Scan();
			IF ~CheckSymbol({Scanner.Ident, Scanner.Function}, "':'type expected") THEN RETURN pseudo END;
			s := scanner.GetStr();
			NEW(pseudo);
			pseudo.SetType(s^);
			IF (scanner.sym = Scanner.Function) & (s^ = 'lang') THEN
				scanner.Scan();
				IF ~CheckSymbol({Scanner.Ident}, "language expected") THEN RETURN pseudo END;
				s := scanner.GetStr();
				pseudo.SetLanguage(s^);
				scanner.Scan();
				IF ~CheckSymbol({Scanner.ParenClose}, "')' expected") THEN RETURN pseudo END
			END;
			scanner.Scan();
			RETURN pseudo
		END ParsePseudo;

		PROCEDURE ParseDeclaration(): CSS2.Declaration;
		VAR declaration: CSS2.Declaration; s: String;
		BEGIN
			IF ~CheckSymbol({Scanner.Ident}, "declaration property expected") THEN RETURN declaration END;
			NEW(declaration);
			s := scanner.GetStr();
			declaration.SetProperty(s^);
			scanner.Scan();
			IF ~CheckSymbol({Scanner.Colon}, "':' expected") THEN RETURN declaration END;
			scanner.Scan();
			declaration.AddTerm(ParseTerm());
			WHILE ~(scanner.sym IN {Scanner.Semicolon, Scanner.BraceClose, Scanner.Important, Scanner.Eof})
					& (scanner.sym # Scanner.Invalid) DO	(* expr *)
				declaration.AddTerm(ParseTerm())
			END;
			IF scanner.sym = Scanner.Important THEN
				declaration.SetImportant(TRUE);
				scanner.Scan()
			END;
			RETURN declaration
		END ParseDeclaration;

		PROCEDURE ParseTerm(): CSS2.Term;
		VAR term: CSS2.Term; s: String;
		BEGIN
			NEW(term);
			IF scanner.sym = Scanner.Slash THEN
				term.SetOperator(CSS2.Slash); scanner.Scan()
			ELSIF scanner.sym = Scanner.Comma THEN
				term.SetOperator(CSS2.Comma); scanner.Scan()
			END;
			IF scanner.sym = Scanner.Minus THEN
				term.SetUnaryOperator(CSS2.Minus); scanner.Scan()
			ELSIF scanner.sym = Scanner.Plus THEN
				term.SetUnaryOperator(CSS2.Plus); scanner.Scan()
			END;
			CASE scanner.sym OF
			| Scanner.Number:
					IF scanner.numberType = Scanner.Integer THEN
						term.SetType(CSS2.IntNumber); term.SetIntVal(scanner.intVal)
					ELSIF scanner.numberType = Scanner.Real THEN
						term.SetType(CSS2.RealNumber); term.SetRealVal(scanner.realVal)
					END
			| Scanner.Percentage:
					term.SetType(CSS2.Percent);
					IF scanner.numberType = Scanner.Integer THEN
						term.SetRealVal(scanner.intVal / 100)
					ELSIF scanner.numberType = Scanner.Real THEN
						term.SetRealVal(scanner.realVal / 100)
					END
			| Scanner.Dimension:
					IF scanner.numberType = Scanner.Integer THEN
						term.SetType(CSS2.IntDimension); term.SetIntVal(scanner.intVal)
					ELSIF scanner.numberType = Scanner.Real THEN
						term.SetType(CSS2.RealDimension); term.SetRealVal(scanner.realVal)
					END;
					s := scanner.GetStr();
					term.SetUnit(GetTermUnit(s^))
			| Scanner.Function:
					s := scanner.GetStr();
					IF (s^ = 'rgb') OR (s^ = 'rgba') THEN
						scanner.Scan();
						term.SetType(CSS2.Color); term.SetIntVal(ParseRGB(s^ = 'rgba'))
					ELSE
						term.SetType(CSS2.Function); term.SetStringVal(s^);
						scanner.Scan();
						term.AddTerm(ParseTerm());
						WHILE scanner.sym IN {Scanner.Slash, Scanner.Comma} DO
							term.AddTerm(ParseTerm())
						END;
						IF ~CheckSymbol({Scanner.ParenClose}, "')' expected") THEN RETURN term END;
					END
			| Scanner.String:
					s := scanner.GetStr();
					term.SetType(CSS2.StringVal); term.SetStringVal(s^)
			| Scanner.Ident:
					s := scanner.GetStr();
					term.SetType(CSS2.StringIdent); term.SetStringVal(s^)
			| Scanner.URI:
					s := scanner.GetStr();
					term.SetType(CSS2.URI); term.SetStringVal(s^)
			(* | Scanner.Unicoderange	*)
			| Scanner.Hash:
					s := scanner.GetStr();
					term.SetType(CSS2.Color); term.SetIntVal(ComputeRGB(s^))
			ELSE
				Error("unknown symbol")
			END;
			scanner.Scan();
			RETURN term
		END ParseTerm;

		PROCEDURE ParseRGB(hasAlpha: BOOLEAN): SIGNED32;
		VAR term: CSS2.Term; r, g, b, a: SIGNED32;
		BEGIN
			term := ParseTerm();
			IF (term # NIL) & (term.GetOperator() = CSS2.Undefined) & (term.GetUnaryOperator() = CSS2.Plus) THEN
				IF (term.GetType() = CSS2.Percent) THEN r := ENTIER(0.5 + term.GetRealVal() * 255)
				ELSIF (term.GetType() = CSS2.IntNumber) THEN r := term.GetIntVal()
				ELSIF (term.GetType() = CSS2.RealNumber) THEN r := ENTIER(0.5 + term.GetRealVal())
				ELSE Error("<number>'%' expected"); RETURN 0
				END
			ELSE
				Error("<number>'%' expected"); RETURN 0
			END;
			term := ParseTerm();
			IF (term # NIL) & (term.GetOperator() = CSS2.Comma) & (term.GetUnaryOperator() = CSS2.Plus) THEN
				IF (term.GetType() = CSS2.Percent) THEN g := ENTIER(0.5 + term.GetRealVal() * 255)
				ELSIF (term.GetType() = CSS2.IntNumber) THEN g := term.GetIntVal()
				ELSIF (term.GetType() = CSS2.RealNumber) THEN g := ENTIER(0.5 + term.GetRealVal())
				ELSE Error("<number>'%' expected"); RETURN 0
				END
			ELSE
				Error("<number>'%' expected"); RETURN 0
			END;
			term := ParseTerm();
			IF (term # NIL) & (term.GetOperator() = CSS2.Comma) & (term.GetUnaryOperator() = CSS2.Plus) THEN
				IF (term.GetType() = CSS2.Percent) THEN b := ENTIER(0.5 + term.GetRealVal() * 255)
				ELSIF (term.GetType() = CSS2.IntNumber) THEN b := term.GetIntVal()
				ELSIF (term.GetType() = CSS2.RealNumber) THEN b := ENTIER(0.5 + term.GetRealVal())
				ELSE Error("<number>'%' expected"); RETURN 0
				END
			ELSE
				Error("<number>'%' expected"); RETURN 0
			END;
			IF hasAlpha THEN
				term := ParseTerm();
				IF (term # NIL) & (term.GetOperator() = CSS2.Comma) & (term.GetUnaryOperator() = CSS2.Plus) THEN
					IF (term.GetType() = CSS2.Percent) THEN a := ENTIER(0.5 + term.GetRealVal() * 255)
					ELSIF (term.GetType() = CSS2.IntNumber) THEN a := term.GetIntVal()
					ELSIF (term.GetType() = CSS2.RealNumber) THEN a := ENTIER(0.5 + term.GetRealVal())
					ELSE Error("<number>'%' expected"); RETURN 0
					END
				END
			ELSE
				a := 0
			END;
			IF ~CheckSymbol({Scanner.ParenClose}, "')' expected") THEN RETURN 0 END;
			RETURN ASH(a, 24) + ASH(r, 16) + ASH(g, 8) + b
		END ParseRGB;

		PROCEDURE IgnoreKeyword;
		BEGIN
			WHILE (scanner.sym # Scanner.BraceOpen) & (scanner.sym # Scanner.Semicolon) & (scanner.sym # Scanner.Eof)
					& (scanner.sym # Scanner.Invalid) DO
				scanner.Scan();
				IF scanner.sym = Scanner.AtKeyword THEN IgnoreKeyword() END
			END;
			IF ~CheckSymbol({Scanner.BraceOpen, Scanner.Semicolon}, "'{' or ';' expected") THEN RETURN END;
			IF scanner.sym = Scanner.BraceOpen THEN
				WHILE (scanner.sym # Scanner.BraceClose) & (scanner.sym # Scanner.Eof) & (scanner.sym # Scanner.Invalid) DO
					scanner.Scan();
					IF scanner.sym = Scanner.AtKeyword THEN IgnoreKeyword() END
				END;
				IF ~CheckSymbol({Scanner.BraceClose}, "'}' expected") THEN RETURN END
			END;
			scanner.Scan()
		END IgnoreKeyword;

	END Parser;

	PROCEDURE GetMedium(mediumStr: ARRAY OF CHAR): SIGNED8;
	BEGIN
		IF mediumStr = 'all' THEN RETURN CSS2.All
		ELSIF mediumStr = 'aural' THEN RETURN CSS2.Aural
		ELSIF mediumStr = 'braille' THEN RETURN CSS2.Braille
		ELSIF mediumStr = 'embossed' THEN RETURN CSS2.Embossed
		ELSIF mediumStr = 'handheld' THEN RETURN CSS2.Handheld
		ELSIF mediumStr = 'print' THEN RETURN CSS2.Print
		ELSIF mediumStr = 'projection' THEN RETURN CSS2.Projection
		ELSIF mediumStr = 'screen' THEN RETURN CSS2.Screen
		ELSIF mediumStr = 'tty' THEN RETURN CSS2.TTY
		ELSIF mediumStr = 'tv' THEN RETURN CSS2.TV
		ELSE RETURN CSS2.All
		END
	END GetMedium;

	PROCEDURE GetPseudoPage(pseudoPageStr: ARRAY OF CHAR): SIGNED8;
	BEGIN
		IF pseudoPageStr = 'left' THEN RETURN CSS2.Left
		ELSIF pseudoPageStr = 'right' THEN RETURN CSS2.Right
		ELSIF pseudoPageStr = 'first' THEN RETURN CSS2.First
		ELSE RETURN CSS2.Undefined
	END
	END GetPseudoPage;

(*	PROCEDURE GetPseudoType(typeStr: ARRAY OF CHAR): SIGNED8;
	BEGIN
		IF typeStr = 'first-child' THEN RETURN CSS2.FirstChild
		ELSIF typeStr = 'link' THEN RETURN CSS2.Link
		ELSIF typeStr = 'visited' THEN RETURN CSS2.Visited
		ELSIF typeStr = 'hover' THEN RETURN CSS2.Hover
		ELSIF typeStr = 'active' THEN RETURN CSS2.Active
		ELSIF typeStr = 'focus' THEN RETURN CSS2.Focus
		ELSIF typeStr = 'first-line' THEN RETURN CSS2.FirstLine
		ELSIF typeStr = 'first-letter' THEN RETURN CSS2.FirstLetter
		ELSIF typeStr = 'before' THEN RETURN CSS2.Before
		ELSIF typeStr = 'after' THEN RETURN CSS2.After
		ELSE RETURN CSS2.Undefined
		END
	END GetPseudoType;*)

	PROCEDURE GetTermUnit(unitStr: ARRAY OF CHAR): SIGNED8;
	BEGIN
		IF unitStr = 'em' THEN RETURN CSS2.em
		ELSIF unitStr = 'ex' THEN RETURN CSS2.ex
		ELSIF unitStr = 'px' THEN RETURN CSS2.px
		ELSIF unitStr = 'in' THEN RETURN CSS2.in
		ELSIF unitStr = 'cm' THEN RETURN CSS2.cm
		ELSIF unitStr = 'mm' THEN RETURN CSS2.mm
		ELSIF unitStr = 'pt' THEN RETURN CSS2.pt
		ELSIF unitStr = 'pc' THEN RETURN CSS2.pc
		ELSIF unitStr = 'deg' THEN RETURN CSS2.deg
		ELSIF unitStr = 'grad' THEN RETURN CSS2.grad
		ELSIF unitStr = 'rad' THEN RETURN CSS2.rad
		ELSIF unitStr = 'ms' THEN RETURN CSS2.ms
		ELSIF unitStr = 's' THEN RETURN CSS2.s
		ELSIF unitStr = 'Hz' THEN RETURN CSS2.Hz
		ELSIF unitStr = 'kHz' THEN RETURN CSS2.kHz
		ELSE RETURN CSS2.Undefined
		END
	END GetTermUnit;

	PROCEDURE ComputeRGB(VAR s: ARRAY OF CHAR): SIGNED32;
	VAR col: SIGNED32; r, g, b, a: SIGNED32;
	BEGIN
		HexStrToInt(s, col);
		IF (Strings.Length(s) = 6) OR (Strings.Length(s) = 8) THEN
			RETURN col
		ELSIF (Strings.Length(s) = 3) OR (Strings.Length(s) = 4) THEN
			a := col DIV 1000H; r := (col DIV 100H) MOD 10H; g := (col DIV 10H) MOD 10H; b := col MOD 10H;
			RETURN ASH(a, 28) + ASH(a, 24) + ASH(r, 20) + ASH(r, 16) + ASH(g, 12) + ASH(g, 8) + ASH(b, 4) + b
		ELSE
			RETURN 0
		END
	END ComputeRGB;

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
			val := ASH(val, 4)+d
		END
	END HexStrToInt;

(*	PROCEDURE SetKeyword();
	VAR s: DynamicStrings.String;
	BEGIN
		sym := Import;
		s := GetStr();
		IF s^ = 'import' THEN keyword := Import
		ELSIF s^ = 'page' THEN keyword := Page
		ELSIF s^ = 'media' THEN keyword := Media
		ELSIF s^ = 'font-face' THEN keyword := FontFace
		ELSIF s^ = 'charset' THEN keyword := CharSet
		ELSE keyword := Unknown
		END
	END SetKeyword; *)

	PROCEDURE DefaultReportError(pos, line, row: SIGNED32; msg: ARRAY OF CHAR);
	BEGIN
		KernelLog.Enter; KernelLog.Char(CHR(9H)); KernelLog.Char(CHR(9H)); KernelLog.String("pos "); KernelLog.Int(pos, 6);
		KernelLog.String(", line "); KernelLog.Int(line, 0); KernelLog.String(", row "); KernelLog.Int(row, 0);
		KernelLog.String("    "); KernelLog.String(msg); KernelLog.Exit;
	END DefaultReportError;

END CSS2Parser.
