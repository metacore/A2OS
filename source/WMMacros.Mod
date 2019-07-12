MODULE WMMacros;	(** AUTHOR "TF"; PURPOSE "Text macros"; *)

IMPORT
	Texts, KernelLog, Strings, TextUtilities, WMTextView, WMEditors,
	Commands, Files, XML, XMLScanner, XMLParser, XMLObjects;

TYPE
	String = Strings.String;
	Char32 = Texts.Char32;
	ParameterEntry = RECORD
		a, b : LONGINT;
	END;
	ParameterList = POINTER TO ARRAY OF ParameterEntry;

CONST
	(* Default keysym of key that invokes macros *)
	DefaultMacroKeySym =  0FF63H; (* Insert key *)

VAR
	macros : XML.Element;
	macroKeySym : LONGINT; (* keysym of key that invokes macros *)
	hasErrors : BOOLEAN;

PROCEDURE IsStop(ch : Char32) : BOOLEAN;
BEGIN
	RETURN IsWhiteSpace(ch) OR (ch = ORD(":"))
END IsStop;

PROCEDURE IsWhiteSpace(ch : Char32) : BOOLEAN;
BEGIN
	RETURN TextUtilities.IsWhiteSpace(ch,FALSE) OR (ch = ORD(">")) OR (ch = ORD("<"))
END IsWhiteSpace;

PROCEDURE LeftSkipString(r : Texts.TextReader; VAR ch : Char32; stop : Char32) : BOOLEAN;
BEGIN
	r.ReadCh(ch);
	WHILE (~r.eot) & (ch # stop) DO r.ReadCh(ch) END;
	IF ch = stop THEN r.ReadCh(ch); RETURN TRUE ELSE RETURN FALSE END
END LeftSkipString;

PROCEDURE LeftSkipIdent(r : Texts.TextReader; VAR ch : Char32) : BOOLEAN;
BEGIN
	WHILE (~r.eot) & (~IsStop(ch)) DO r.ReadCh(ch);
		IF (ch = ORD("'")) OR (ch = ORD('"')) THEN RETURN FALSE END
	END;
	RETURN TRUE
END LeftSkipIdent;

PROCEDURE ParseLeft(r : Texts.TextReader; VAR nof : LONGINT) : BOOLEAN;
VAR ch : Char32;
BEGIN
	nof := 0;
	REPEAT
		r.ReadCh(ch);
		IF (nof = 0) & IsStop(ch) THEN RETURN FALSE END;
		IF ch = ORD("'") THEN IF ~LeftSkipString(r, ch, ORD("'")) THEN RETURN FALSE END
		ELSIF ch = ORD('"') THEN IF ~LeftSkipString(r, ch, ORD('"')) THEN RETURN FALSE END
		ELSIF  ~IsStop(ch) THEN IF ~LeftSkipIdent(r, ch) THEN RETURN FALSE END
		END;
		INC(nof)
	UNTIL (r.eot) OR (ch # ORD(":"));
	RETURN TRUE
END ParseLeft;

PROCEDURE ParseToRight(r : Texts.TextReader; end, nof : LONGINT; par : ParameterList; VAR startPos : LONGINT) : BOOLEAN;
VAR ch : Char32; i : LONGINT;
BEGIN
	i := 0;
	startPos := -2;
	REPEAT
		IF i >= LEN(par^) THEN RETURN FALSE END;
		r.ReadCh(ch);
		WHILE (~r.eot) & IsWhiteSpace(ch) DO r.ReadCh(ch) END;
		IF startPos = -2 THEN startPos := r.GetPosition() - 1 END;
		IF ch = ORD("'") THEN
			par[i].a := r.GetPosition();
			REPEAT r.ReadCh(ch) UNTIL (ch = ORD("'")) OR (r.eot);
			par[i].b := r.GetPosition() - 1;
			r.ReadCh(ch)
		ELSIF ch = ORD('"') THEN
			par[i].a := r.GetPosition();
			REPEAT r.ReadCh(ch) UNTIL (ch = ORD('"')) OR (r.eot);
			par[i].b := r.GetPosition() - 1;
			r.ReadCh(ch)
		ELSIF  ~IsStop(ch) THEN
			par[i].a := r.GetPosition() - 1;
			REPEAT r.ReadCh(ch) UNTIL (ch = ORD(':')) OR (r.GetPosition() > end) OR (r.eot);
			par[i].b := r.GetPosition() - 1; IF r.eot THEN INC(par[i].b) END
		ELSE par[i].a := r.GetPosition(); par[i].b := par[i].a
		END;
		INC(i)
	UNTIL (r.eot) OR (r.GetPosition() > end) OR (i = nof);
	RETURN TRUE
END ParseToRight;

PROCEDURE InsertParameter(text : Texts.Text; parameter: ParameterEntry; pos : LONGINT);
BEGIN
	text.CopyFromText(text, parameter.a, parameter.b - parameter.a, pos)
END InsertParameter;

PROCEDURE FindMacro*(parent: XML.Element; CONST key : ARRAY OF CHAR): XML.Element;
VAR enum: XMLObjects.Enumerator; p: ANY; e: XML.Element; s: XML.String;
BEGIN
	IF parent = NIL THEN RETURN NIL END;
	enum := parent.GetContents();
	WHILE enum.HasMoreElements() DO
		p := enum.GetNext();
		IF p IS XML.Element THEN
			e := p(XML.Element); s := e.GetName();
			IF (s # NIL) & (s^ = "Macro") THEN
				s := e.GetAttributeValue("key");
				IF (s # NIL) & (s^ = key) THEN RETURN e END
			END
		END
	END;
	RETURN NIL
END FindMacro;

PROCEDURE ExecuteMacro(text : Texts.Text; r : Texts.TextReader; cursor : WMTextView.PositionMarker; parameters : ParameterList; macro : XML.Element);
VAR
	en : XMLObjects.Enumerator;
	p : ANY; s: String; cp, nofWhitespace, lineStart : LONGINT;

		PROCEDURE HandleString(xml : XML.Element);
			VAR en : XMLObjects.Enumerator;
			p : ANY;
			s : String;
		BEGIN
			en := xml.GetContents();
			p := en.GetNext();
			IF p IS XML.ArrayChars THEN
				s := p(XML.ArrayChars).GetStr();
				IF s # NIL THEN TextUtilities.StrToText(text, cursor.GetPosition(), s^) END;
			END
		END HandleString;

		PROCEDURE HandleArg(xml : XML.Element);
		VAR s : String; nr : LONGINT;
		BEGIN
			s := xml.GetAttributeValue("nr");
			IF s # NIL THEN
				Strings.StrToInt(s^, nr);
				IF nr < LEN(parameters^) THEN InsertParameter(text, parameters[nr], cursor.GetPosition()) END
			END
		END HandleArg;

		PROCEDURE InsertChar(ch : Texts.Char32);
		VAR buf : ARRAY 2 OF Texts.Char32;
		BEGIN
			buf[0] := ch; buf[1] := 0;
			text.InsertUCS32(cursor.GetPosition(), buf) (* cursor moves automagically *)
		END InsertChar;

BEGIN
	(* remember original indentation *)
	lineStart := TextUtilities.FindPosLineStart(r, cursor.GetPosition());
	nofWhitespace := TextUtilities.CountWhitespace(r, lineStart);
	cp := -1;
	en := macro.GetContents();
	WHILE en.HasMoreElements() DO
		p := en.GetNext();
		IF p IS XML.Element THEN
			s := p(XML.Element).GetName();
			IF (s # NIL) THEN
				IF s^ = "String" THEN HandleString(p(XML.Element))
				ELSIF s^ = "CR" THEN
					InsertChar(Texts.NewLineChar);
					IF nofWhitespace > 0 THEN text.CopyFromText(text, lineStart, nofWhitespace, cursor.GetPosition()) END;
				ELSIF s^ = "Indent" THEN InsertChar(9)
				ELSIF s^ = "LT" THEN InsertChar(ORD("<"))
				ELSIF s^ = "GT" THEN InsertChar(ORD(">"))
				ELSIF s^ = "Arg" THEN HandleArg(p(XML.Element))
				ELSIF s^ = "Cursor" THEN cp := cursor.GetPosition()
				ELSIF s^ = "Quote" THEN InsertChar(ORD('"'))
				END
			END
		END
	END;
	IF cp # -1 THEN cursor.SetPosition(cp) END
END ExecuteMacro;

PROCEDURE Insert(text : Texts.Text; cursor : WMTextView.PositionMarker);
VAR buf : ARRAY 3 OF Texts.Char32;
	 r : Texts.TextReader;
	 nof : LONGINT;
	 a, b, i : LONGINT;
	 parameters : ParameterList;
	 key : ARRAY 128 OF CHAR;
	 macro : XML.Element;
BEGIN
	NEW(r, text); r.SetDirection(-1); r.SetPosition(cursor.GetPosition() - 1);
	(* read left until the first word ends *)
	IF ParseLeft(r, nof) THEN
		NEW(parameters, nof);
		r.SetDirection(1);
		IF r.GetPosition() > 0 THEN r.SetPosition(r.GetPosition() + 1) END;
		b := cursor.GetPosition();
		IF ParseToRight(r, cursor.GetPosition(), nof, parameters, a) THEN
			IF FALSE THEN
				KernelLog.String("Parameters:"); KernelLog.Ln;
				FOR i := 0 TO nof -1  DO
					TextUtilities.SubTextToStr(text, parameters[i].a, parameters[i].b - parameters[i].a, key);
					KernelLog.String(key);KernelLog.Ln
				END
			END;
			TextUtilities.SubTextToStr(text, parameters[nof-1].a, parameters[nof-1].b - parameters[nof-1].a, key);
			IF FALSE THEN
				KernelLog.String("Key = '"); KernelLog.String(key); KernelLog.String("'"); KernelLog.Ln;
			END;
			macro := FindMacro(macros, key);
			IF macro # NIL THEN
				ExecuteMacro(text, r, cursor, parameters, macro);
				text.Delete(a, b - a)
			ELSE
				KernelLog.String("unknown macro : "); KernelLog.String(key); KernelLog.Ln
			END;
		ELSE KernelLog.String("Macro assertion failed") END;
	ELSE
		KernelLog.String("WMMacros: Macro not found."); KernelLog.Ln;
	END;
	text.InsertUCS32(cursor.GetPosition(), buf) (* cursor moves automagically *)
END Insert;

PROCEDURE Handle*(sender, data: ANY);
VAR md : WMEditors.MacroData; text : Texts.Text; cursor : WMTextView.PositionMarker;
BEGIN
	IF (data # NIL) & (data IS WMEditors.MacroData) THEN
		md := data(WMEditors.MacroData);
		IF md.keySym = macroKeySym THEN
			text := md.text; cursor := md.cursor;
			IF (text # NIL) & (cursor # NIL) THEN Insert(text, cursor); md.handled := TRUE END
		END;
	END
END Handle;

(* <MacroKey keysym="..."/> can be used to specify the key to be used to invoke macros. This procedure tries to		*)
(* find and parse this element in the Macro file. If the keysym value cannot be retrieved, the DefaultMacrokeysym is	*)
(* returned.																										*)
PROCEDURE GetMacroKeySym() : LONGINT;
VAR
	enum : XMLObjects.Enumerator; elem : XML.Element; s : XML.String; p : ANY;
	keysym : LONGINT; res: WORD;
BEGIN
	IF macros # NIL THEN
		enum := macros.GetContents();
		WHILE enum.HasMoreElements() DO
			p := enum.GetNext();
			IF p IS XML.Element THEN
				elem := p (XML.Element); s := elem.GetName();
				IF (s # NIL) & (s^ = "MacroKey") THEN
					s := elem.GetAttributeValue("keysym");
					IF s # NIL THEN
						Strings.HexStrToInt(s^, keysym, res);
						IF res = Strings.Ok THEN RETURN keysym; END;
					END;
				END;
			END;
		END;
	END;
	RETURN DefaultMacroKeySym;
END GetMacroKeySym;

(* Report errors while parsing *)
PROCEDURE Error(pos, line, row: LONGINT; CONST msg: ARRAY OF CHAR);
BEGIN
	KernelLog.String("WMMacros: Parse error at pos "); KernelLog.Int(pos, 5); KernelLog.String(" in line "); KernelLog.Int(line, 5);
	KernelLog.String(" row "); KernelLog.Int(row, 5); KernelLog.String(" - "); KernelLog.String(msg); KernelLog.Ln;
	hasErrors := TRUE
END Error;

PROCEDURE Read(CONST name : ARRAY OF CHAR);
VAR f : Files.File;
	scanner : XMLScanner.Scanner;
	parser : XMLParser.Parser;
	reader : Files.Reader;
	doc : XML.Document;
BEGIN
	hasErrors := FALSE;
	f := Files.Old(name);
	IF f # NIL THEN
		NEW(reader, f, 0);
		NEW(scanner, reader); scanner.reportError := Error;
		NEW(parser, scanner); parser.reportError := Error;
		doc := parser.Parse();
		KernelLog.String("WMMacros: Macro file "); KernelLog.String(name);
		IF hasErrors THEN
			KernelLog.String(" has errors.");
		ELSE
			macros := doc.GetRoot();
			macroKeySym := GetMacroKeySym();
			KernelLog.String(" loaded.");
		END;
		KernelLog.Ln;
	END
END Read;

PROCEDURE ReadMacros*(context : Commands.Context);
VAR filename : ARRAY 64 OF CHAR;
BEGIN {EXCLUSIVE}
	IF context.arg.GetString(filename) THEN
		Read(filename);
	ELSE
		context.result := Commands.CommandParseError;
	END;
END ReadMacros;

BEGIN
	macroKeySym := DefaultMacroKeySym;
	Read("Macros.XML");
END WMMacros.

WMMacros.ReadMacros Macros.XML ~  System.Free WMMacros ~

History:

	20.02.2006	Added option to specify the macro key in the macro XML file (staubesv)

