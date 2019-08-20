MODULE SkinLanguage; (** AUTHOR "FN"; PURPOSE "Bluebottle Skin Language"; *)

IMPORT
	XML, XMLScanner, XMLParser, XMLObjects, Strings, Files, Streams, KernelLog,
	WMGraphics;

CONST
	Buffersize = 128;
	CR = 0DX; LF = 0AX; TAB = 9X; SP = 20X; EOF = 0X;
	ConfigFileName* = "SkinConfig.XML";

TYPE
	String = Strings.String;

	ReportError* = PROCEDURE {DELEGATE} (pos, line, col : LONGINT; msg : String);
	StringReportError = PROCEDURE {DELEGATE} (msg : String);

	Property = OBJECT
	VAR name, type : String;
		mandatory, succeeded: BOOLEAN;
		next : Property;

		PROCEDURE & Init *(n, t : String);
		BEGIN
			name := n;
			type := t;
			mandatory := TRUE;
			succeeded := FALSE
		END Init;

	END Property;

	PropertyList = OBJECT
	VAR first : Property;

		PROCEDURE Add(e : XML.Element);
		VAR p : Property; s : String;
		BEGIN
			NEW(p, e.GetAttributeValue("name"), e.GetAttributeValue("type"));
			s := e.GetAttributeValue("mandatory");
			IF s # NIL THEN
				LowerCase(s); p.mandatory := (s^ # "false")
			END;
			p.next := first; first := p
		END Add;

		PROCEDURE Find(s : String) : Property;
		VAR p : Property;
		BEGIN
			p := first;
			WHILE p # NIL DO
				IF p.name^ = s^ THEN RETURN p END;
				p := p.next
			END;
			RETURN NIL
		END Find;

	END PropertyList;

	Component = OBJECT
	VAR properties : PropertyList;
		name : String;
		next : Component;

		PROCEDURE & Init*(s : String);
		BEGIN
			name := s;
			NEW(properties)
		END Init;

		PROCEDURE MandatoryPropertiesSucceeded(re : StringReportError) : BOOLEAN;
		VAR result : BOOLEAN;
			p : Property;
		BEGIN
			result := TRUE; p := properties.first;
			WHILE p # NIL DO
				IF p.mandatory & ~p.succeeded THEN
					re(Append(NewString("Missing mandatory property : "), p.name^));
					result := FALSE
				END;
				p := p.next
			END;
			RETURN result
		END MandatoryPropertiesSucceeded;

	END Component;

	ComponentList = OBJECT
	VAR first: Component;

		PROCEDURE Add(e : XML.Element);
		VAR c : Component;
			en : XMLObjects.Enumerator;
			x : XML.Element;
			a : ANY;
			s : String;
		BEGIN
			NEW(c , e.GetAttributeValue("name"));
			en := e.GetContents();
			en.Reset();
			WHILE en.HasMoreElements() DO
				a := en.GetNext();
				IF a IS XML.Element THEN
					x := a(XML.Element);
					s := x.GetName();
					IF s^ = "property" THEN
						c.properties.Add(x)
					END
				END
			END;
			c.next := first;
			first := c
		END Add;

		PROCEDURE Find(s : String) : Component;
		VAR c : Component;
		BEGIN
			c := first;
			WHILE c # NIL DO
				IF c.name^ = s^ THEN RETURN c END;
				c := c.next
			END;
			RETURN NIL
		END Find;

	END ComponentList;

	Scanner* = OBJECT
	VAR r: Streams.Reader;
		pos-, oldpos-, line-, col-, oldcol- : LONGINT;

			(** initialize with stream to scan *)
		PROCEDURE & Init*(r : Streams.Reader);
		BEGIN
			SELF.r := r;
			line := 1; col := 0; pos := 0; oldpos := 0; oldcol := 0
		END Init;

			(* return the next character in the stream. update pos, line and col *)
		PROCEDURE NextCh() : CHAR;
		VAR ch : CHAR;
		BEGIN
			ch := r.Get(); INC(pos);
			IF (ch = CR) OR (ch = LF) THEN INC(line); col := 0
			ELSE INC(col) END;
			RETURN ch
		END NextCh;

			(* proceed in the stream until the next non-whitespace occures *)
		PROCEDURE SkipWhitespace;
		VAR ch : CHAR;
		BEGIN
			ch := r.Peek();
			WHILE IsWhitespace(ch) DO
				ch := NextCh(); ch := r.Peek()
			END
		END SkipWhitespace;

			(** return next token. return NIL if end of stream is reached *)
		PROCEDURE GetString() : String;
		VAR ch : CHAR;
			buf : ARRAY Buffersize OF CHAR;
			i : LONGINT;
			s : String;
		BEGIN
			buf[0] := NextCh(); (* must be '"' *)
			i := 1;
			ch := NextCh();
			WHILE ch # '"' DO
				buf[i] := ch;
				ch := NextCh();
				INC(i)
			END;
			buf[i] := ch;
			NEW(s, i+2);
			COPY(buf, s^);
			RETURN s
		END GetString;

		PROCEDURE GetDelimiter() : String;
		VAR s : String;
		BEGIN
			NEW(s, 2); s[0] := NextCh(); s[1] := 0X; RETURN s
		END GetDelimiter;

		(* return a string delimited by {, }, :, ;, SP, TAB, EOF, CR or LF *)
		PROCEDURE GetToken() : String;
		VAR ch : CHAR; a : ARRAY Buffersize OF CHAR;
			i : LONGINT; s : String;
		BEGIN
			i := 0;
			ch := r.Peek();
			WHILE (ch # '{') & (ch # '}') & (ch # ':') & (ch # ';') &(ch # CR) & (ch # LF) & (ch # EOF) & (ch # SP) & (ch # TAB ) DO
				a[i] := NextCh();
				ch := r.Peek();
				INC(i)
			END;
			a[i] := 0X;
			NEW(s, i+1);
			COPY(a, s^);
			RETURN s
		END GetToken;

		PROCEDURE Get*() : String;
		VAR ch : CHAR;
		BEGIN
			SkipWhitespace();
			oldpos := pos; oldcol := col;
			ch := r.Peek();
			IF ch = '"' THEN
				RETURN GetString()
			ELSIF (ch = '{') OR (ch = '}') OR (ch = ':') OR (ch = ';') THEN
				RETURN GetDelimiter()
			ELSIF ch = EOF THEN
				RETURN NIL (* end of file *)
			ELSE
				RETURN GetToken()
			END;
		END Get;

		PROCEDURE IsWhitespace(ch : CHAR) : BOOLEAN;
		BEGIN
			RETURN (ch = SP) OR (ch = TAB) OR (ch = CR) OR (ch = LF)
		END IsWhitespace;

	END Scanner;

	Parser *= OBJECT
	VAR reportError*: ReportError;
		scanner : Scanner;
		components : ComponentList;
		warnings : BOOLEAN;
		prefix : ARRAY 128 OF CHAR; (* name of skinfile || "://" *)
		prefixLength : LONGINT;

			(** initialize with bsl-scanner *)
		PROCEDURE & Init*(CONST filename : ARRAY OF CHAR; s : Scanner);
		VAR i : LONGINT;
		BEGIN
			scanner := s;
			reportError := DefaultReportError;
			NEW(components);
			ReadConfiguration();
			warnings := TRUE;
			i := 0;
			WHILE filename[i] # 0X DO prefix[i] := filename[i]; INC(i) END;
			prefix[i] := ':'; INC(i); prefix[i] := '/'; INC(i); prefix[i] := '/'; INC(i);
			prefix[i] := 0X; prefixLength := i
		END Init;

			(** parse skin. if warnings is FALSE, only errors are shown *)
		PROCEDURE Parse*(warnings : BOOLEAN) : XML.Document;
		VAR x : XML.Element;
			doc : XML.Document;
		BEGIN
			SELF.warnings := warnings;
			IF FailToParse("skin") THEN RETURN NIL END;
			NEW(doc);
			x := ParseSkin();
			IF x = NIL THEN RETURN NIL END;
			doc.AddContent(x);
			RETURN doc
		END Parse;

		(* parse skin elements *)
		PROCEDURE ParseSkin() : XML.Element;
		VAR x, y : XML.Element;
		BEGIN
			IF FailToParse("{") THEN RETURN NIL END;
			NEW(x);
			x.SetName("Skin");
				(* meta information *)
			IF FailToParse("meta") THEN RETURN NIL END;
			IF ParseMeta() = NIL THEN RETURN NIL END;
				(* window-style*)
			IF FailToParse("window") THEN RETURN NIL END;
			y := ParseWindow();
			IF y = NIL THEN RETURN NIL END;
			x.AddContent(y);
				(* cursors *)
			IF FailToParse("cursor") THEN RETURN NIL END;
			y := ParseCursor();
			IF y = NIL THEN RETURN NIL END;
			x.AddContent(y);
				(* component-style *)
			IF FailToParse("component") THEN RETURN NIL END;
			y := ParseComponentSet();
			IF y = NIL THEN RETURN NIL END;
			x.AddContent(y);
			IF FailToParse("}") THEN RETURN NIL END;
			RETURN x
		END ParseSkin;

		(* parse cursor-style *)
		PROCEDURE ParseCursor() : XML.Element;
		VAR x, sub : XML.Element;
			c : Component;
			s : String;
		BEGIN
			IF FailToParse("{") THEN RETURN NIL END;
			NEW(x);
			x.SetName("Cursors");
			s := scanner.Get();
			WHILE (s # NIL) & (s^ # "}") DO
				c := components.Find(s);
				IF c = NIL THEN
					ErrorString(Append(NewString("Unknown cursor : "), s^));
					RETURN NIL
				ELSE
					sub := ParseComponent(c);
					IF sub = NIL THEN RETURN NIL END;
					x.AddContent(sub)
				END;
				s := scanner.Get()
			END;
			IF s = NIL THEN Error("Expected : }"); RETURN NIL END;
			RETURN x
		END ParseCursor;

		(* parse window-style *)
		PROCEDURE ParseWindow() : XML.Element;
		VAR x, sub : XML.Element;
			c : Component;
			useBitmaps : BOOLEAN;
		BEGIN
			IF FailToParse("{") THEN RETURN NIL END;
			NEW(x);
			x.SetName("Window");
				(* useBitmaps ? *)
			IF FailToParse("useBitmaps") THEN RETURN NIL END;
			sub := ParseBooleanProperty(useBitmaps);
			IF sub = NIL THEN RETURN NIL END;
			sub.SetName("UseBitmaps");
			x.AddContent(sub);
				(* title*)
			IF FailToParse("title") THEN RETURN NIL END;
			c := components.Find(NewString("title"));
			ASSERT(c # NIL);
			sub := ParseComponent(c);
			IF sub = NIL THEN RETURN NIL END;
			x.AddContent(sub);
			IF useBitmaps THEN
					(* top *)
				IF FailToParse("top") THEN RETURN NIL END;
				c := components.Find(NewString("top"));
				ASSERT(c # NIL);
				sub := ParseComponent(c);
				IF sub = NIL THEN RETURN NIL END;
				x.AddContent(sub);
					(* bottom *)
				IF FailToParse("bottom") THEN RETURN NIL END;
				c := components.Find(NewString("bottom"));
				ASSERT(c # NIL);
				sub := ParseComponent(c);
				IF sub = NIL THEN RETURN NIL END;
				x.AddContent(sub);
					(* left *)
				IF FailToParse("left") THEN RETURN NIL END;
				c := components.Find(NewString("left"));
				ASSERT(c # NIL);
				sub := ParseComponent(c);
				IF sub = NIL THEN RETURN NIL END;
				x.AddContent(sub);
					(* right *)
				IF FailToParse("right") THEN RETURN NIL END;
				c := components.Find(NewString("right"));
				ASSERT(c # NIL);
				sub := ParseComponent(c);
				IF sub = NIL THEN RETURN NIL END;
				x.AddContent(sub);
			ELSE
				(* border *)
				IF FailToParse("border") THEN RETURN NIL END;
				c := components.Find(NewString("border"));
				ASSERT(c # NIL);
				sub := ParseComponent(c);
				IF sub = NIL THEN RETURN NIL END;
				x.AddContent(sub);
			END;
				(* desktop *)
			IF FailToParse("desktop") THEN RETURN NIL END;
			c := components.Find(NewString("desktop"));
			ASSERT(c # NIL);
			sub := ParseComponent(c);
			IF sub = NIL THEN RETURN NIL END;
			x.AddContent(sub);
			IF FailToParse("}") THEN RETURN NIL END;
			RETURN x
		END ParseWindow;

		(* parse meta-data of skin *)
		PROCEDURE ParseMeta() : XML.Element;
		VAR x, y : XML.Element;
		BEGIN
			IF FailToParse("{") THEN RETURN NIL END;
			NEW(x); x.SetName("Meta");
			IF FailToParse("name") THEN RETURN NIL END;
			y := ParseStringProperty();
			IF y = NIL THEN RETURN NIL END;
			x.AddContent(y);
			IF FailToParse("description") THEN RETURN NIL END;
			y := ParseStringProperty();
			IF y = NIL THEN RETURN NIL END;
			x.AddContent(y);
			IF FailToParse("author") THEN RETURN NIL END;
			y := ParseStringProperty();
			IF y = NIL THEN RETURN NIL END;
			x.AddContent(y);
			IF FailToParse("date") THEN RETURN	NIL END;
			y := ParseStringProperty();
			IF y = NIL THEN RETURN NIL END;
			x.AddContent(y);
			IF FailToParse("}") THEN RETURN NIL END;
			RETURN x
		END ParseMeta;

		(* parse set of components. return NIL in case of error. *)
		PROCEDURE ParseComponentSet() : XML.Element;
		VAR s : String;
			c : Component;
			x, sub : XML.Element;
			error : BOOLEAN;
		BEGIN
			error := FALSE;
			IF FailToParse("{") THEN RETURN NIL END;
			NEW(x);
			x.SetName("Components");
			s := scanner.Get();
			WHILE (s # NIL) & (s^ # "}") DO
				c := components.Find(s);
				IF c = NIL THEN
					ErrorString(Append(NewString("Unknown component : "), s^));
					error := TRUE;
					s := scanner.Get();
					IF (s # NIL) & (s^ = "{") THEN
						IF SkipUntilClosingBracket() = NIL THEN RETURN NIL END
					ELSE
						RETURN NIL
					END
				ELSE
					sub := ParseComponent(c);
					IF sub = NIL THEN
						error := TRUE;
						IF SkipUntilClosingBracket() = NIL THEN RETURN NIL END
					ELSE
						x.AddContent(sub)
					END
				END;
				s := scanner.Get()
			END;
			IF s = NIL THEN Error("Expected : }"); RETURN NIL END;
			IF ~error THEN RETURN x ELSE RETURN NIL END
		END ParseComponentSet;

		(* parse component and it's respective properties *)
		PROCEDURE ParseComponent(c : Component) : XML.Element;
		VAR s : String;
			p : Property;
			x, sub : XML.Element;
		BEGIN
			IF FailToParse("{") THEN RETURN NIL END;
			NEW(x);
			c.name^[0] := CAP(c.name^[0]);
			x.SetNameAsString(c.name);
				(* parse properties *)
			s := scanner.Get();
			WHILE (s # NIL) & (s^ # "}") DO
				p := c.properties.Find(s);
				IF p = NIL THEN
					ErrorString(Append(NewString("Unknown property : "), s^));
					RETURN NIL;
				END;
				sub := ParseProperty(p);
				IF sub = NIL THEN RETURN NIL END;
				x.AddContent(sub);
				s := scanner.Get()
			END;
			IF s = NIL THEN Error("Expected '}'"); RETURN NIL END;
			IF ~c.MandatoryPropertiesSucceeded(ErrorString) THEN RETURN NIL END;
			RETURN x
		END ParseComponent;

		(* parse property according to type-information given in p. return NIL in case of failure *)
		PROCEDURE ParseProperty(p : Property) : XML.Element;
		VAR x : XML.Element;
			dummy : BOOLEAN;
		BEGIN
			IF p.type^ = "color" THEN 		x := ParseColorProperty()
			ELSIF p.type^ = "rectangle" THEN x := ParseRectangleProperty()
			ELSIF p.type^ = "int32" THEN 	x := ParseInt32Property()
			ELSIF p.type^ = "boolean" THEN 	x := ParseBooleanProperty(dummy)
			ELSIF p.type^ = "string" THEN 	x := ParseStringProperty()
			ELSIF p.type^ = "resource" THEN x := ParseResourceProperty(SELF.warnings)
			END;
			IF x = NIL THEN RETURN NIL END;
			p.succeeded := TRUE;
			p.name^[0] := CAP(p.name^[0]);
			x.SetNameAsString(p.name);
			RETURN x
		END ParseProperty;

		(* parse rectangular property. return NIL if fail *)
		PROCEDURE ParseRectangleProperty() : XML.Element;
		VAR prop, sub : XML.Element;
			ac : XML.ArrayChars;
			s : String;
		BEGIN
			IF FailToParse("{") THEN RETURN NIL END;
				(* height *)
			IF FailToParse("height") THEN RETURN NIL END;
			IF FailToParse(":") THEN RETURN NIL END;
			s := scanner.Get();
			IF NoNumber(s) THEN RETURN NIL END;
			NEW(prop);
			NEW(sub);
			prop.AddContent(sub);
			sub.SetName("Height");
			NEW(ac);
			sub.AddContent(ac);
			ac.SetStr(s^);
			IF FailToParse(";") THEN RETURN NIL END;
				(* width *)
			IF FailToParse("width") THEN RETURN NIL END;
			IF FailToParse(":") THEN RETURN NIL END;
			s := scanner.Get();
			IF NoNumber(s) THEN RETURN NIL END;
			NEW(sub);
			prop.AddContent(sub);
			sub.SetName("Width");
			NEW(ac);
			sub.AddContent(ac);
			ac.SetStr(s^);
			IF FailToParse(";") THEN RETURN NIL END;
			IF FailToParse("}") THEN RETURN NIL END;
			RETURN prop
		END ParseRectangleProperty;

		(* parse color-property. return NIL if fail *)
		PROCEDURE ParseColorProperty() : XML.Element;
		BEGIN
			RETURN ParseInt32Property()
		END ParseColorProperty;

		(* parse integer-property. return NIL if fail *)
		PROCEDURE ParseInt32Property() : XML.Element;
		VAR prop : XML.Element;
			ac : XML.ArrayChars;
			s : String;
		BEGIN
			NEW(prop);
			IF FailToParse(":") THEN RETURN NIL END;
			s := scanner.Get();
			IF NoNumber(s) THEN RETURN NIL END;
			NEW(ac);
			ac.SetStr(s^);
			IF FailToParse(";") THEN RETURN NIL END;
			prop.AddContent(ac);
			RETURN prop
		END ParseInt32Property;

		(* when successful parsed : RETURN xml-Element, bool := parsed value
			when parsing not possible : RETURN NIL, bool undefined *)
		PROCEDURE ParseBooleanProperty(VAR bool : BOOLEAN) : XML.Element;
		VAR prop : XML.Element;
			ac : XML.ArrayChars;
			s : String;
		BEGIN
			NEW(prop);
			IF FailToParse(":") THEN RETURN NIL END;
			s := scanner.Get();
			IF NoBoolean(s) THEN RETURN NIL END;
			bool := (s^ = "true");
			NEW(ac);
			ac.SetStr(s^);
			IF FailToParse(";") THEN RETURN NIL END;
			prop.AddContent(ac);
			RETURN prop
		END ParseBooleanProperty;

		(* parse string-property *)
		PROCEDURE ParseStringProperty() : XML.Element;
		VAR prop : XML.Element; ac : XML.ArrayChars; s, t : String; i : SIZE;
		BEGIN
			NEW(prop);
			IF FailToParse(":") THEN RETURN NIL END;
			s := scanner.Get();
			IF NoString(s) THEN RETURN NIL END;
			NEW(t, LEN(s^)-2);
			FOR i := 1 TO LEN(s^)-3 DO t^[i-1] := s^[i] END;
			t[LEN(s^)-3] := 0X;
			NEW(ac);
			ac.SetStr(t^);
			IF FailToParse(";") THEN RETURN NIL END;
			prop.AddContent(ac);
			RETURN prop
		END ParseStringProperty;

		(* parse name of a resource. check availability of resource if check is TRUE. return NIL if fail *)
		PROCEDURE ParseResourceProperty(check : BOOLEAN) : XML.Element;
		VAR prop : XML.Element; ac : XML.ArrayChars; s, t : String; i : SIZE;
		BEGIN
			NEW(prop);
			IF FailToParse(":") THEN RETURN NIL END;
			s := scanner.Get();
			IF NoString(s) THEN RETURN NIL END;
			NEW(t, LEN(s^)-2+prefixLength);
			COPY(prefix, t^);
			FOR i := 1 TO LEN(s^)-3 DO t^[i-1+prefixLength] := s^[i] END;
			t[LEN(s^)+prefixLength-3] := 0X;
			NEW(ac);
			ac.SetStr(t^);
			IF FailToParse(";") THEN RETURN NIL END;
			prop.AddContent(ac);
			IF check THEN CheckImage(t^) END; (* is parsed string name of a loadable image ? *)
			RETURN prop
		END ParseResourceProperty;

		(* read SkinLanguage-configuration from the config-file *)
		PROCEDURE ReadConfiguration;
		VAR scanner : XMLScanner.Scanner; parser : XMLParser.Parser;
			doc : XML.Document; el : XML.Element; en : XMLObjects.Enumerator;
			file : Files.File; r : Files.Reader; p : ANY; s : String;
		BEGIN
			file := Files.Old(ConfigFileName);
			IF file = NIL THEN KernelLog.String(ConfigFileName); KernelLog.String(" not found"); KernelLog.Ln; RETURN END;
			Files.OpenReader(r, file, 0);
			NEW(scanner, r);
			NEW(parser, scanner);
			doc := parser.Parse();
			el := doc.GetRoot();
			en := el.GetContents();
			en.Reset();
			WHILE en.HasMoreElements() DO
				p := en.GetNext();
				IF p IS XML.Element THEN
					el := p(XML.Element);
					s := el.GetName();
					IF s^ = "component" THEN components.Add(el) END
				END
			END;
		END ReadConfiguration;

		PROCEDURE CheckImage(CONST name : ARRAY OF CHAR);
		BEGIN
			IF WMGraphics.LoadImage(name, TRUE) = NIL THEN
				ErrorString(Append(NewString("Warning, no valid image : "), name))
			END
		END CheckImage;

		PROCEDURE FailToParse(CONST a : ARRAY OF CHAR) : BOOLEAN;
		VAR s : String;
		BEGIN
			s := scanner.Get();
			IF (s = NIL) OR (s^ # a) THEN
				ErrorString(Append(Append(NewString("Failed to parse, expected '"), a), "'"));
				RETURN TRUE
			ELSE
				RETURN FALSE
			END
		END FailToParse;

		(* return TRUE if s is not a valid number *)
		PROCEDURE NoNumber(s : String) : BOOLEAN;
		VAR i : LONGINT;
		BEGIN
			i := ORD(s^[0]);
			IF (i >= ORD('0')) & (i <= ORD('9')) THEN
				RETURN FALSE
			ELSE
				Error("Not a valid number (must begin with digit).");
				RETURN TRUE
			END
		END NoNumber;

		(* return FALSE if LOW(s) equals either 'true' or 'false'. s := LOW(s) *)
		PROCEDURE NoBoolean(s : String) : BOOLEAN;
		BEGIN
			LowerCase(s);
			IF (s^ # "true") & (s^ # "false") THEN
				Error("Expected 'true' or 'false'.");
				RETURN TRUE
			ELSE
				RETURN FALSE
			END
		END NoBoolean;

		(* return TRUE if s is not a valid string that starts and ends with an " *)
		PROCEDURE NoString(s : String) : BOOLEAN;
		BEGIN
			IF (s = NIL) OR (s^[0] # '"') OR (s^[LEN(s^)-2] # '"') THEN
				Error("Expected a string (encapsulated with '').");
				RETURN TRUE
			ELSE
				RETURN FALSE
			END
		END NoString;

		(* return the next '}' that hasn't been preceeded by a corresponding '{'. return NIL at the end of the stream *)
		PROCEDURE SkipUntilClosingBracket() : String;
		VAR s : String;
		BEGIN
			s := scanner.Get();
			WHILE s # NIL DO
				IF s^ = "{" THEN
					s := SkipUntilClosingBracket();
					IF s = NIL THEN RETURN NIL END
				ELSIF s^ = "}" THEN
					RETURN s
				END;
				s := scanner.Get()
			END;
			RETURN NIL
		END SkipUntilClosingBracket;

		PROCEDURE Error(CONST msg : ARRAY OF CHAR);
		BEGIN
			reportError(scanner.oldpos, scanner.line, scanner.col, NewString(msg));
		END Error;

		PROCEDURE ErrorString(msg :String);
		BEGIN
			reportError(scanner.oldpos, scanner.line, scanner.oldcol, msg);
		END ErrorString;

	END Parser;

PROCEDURE DefaultReportError(pos, line, col: LONGINT; msg: String);
BEGIN
	KernelLog.String("ERROR : "); KernelLog.Ln;
	KernelLog.String("  position : "); KernelLog.Int(pos, 0); KernelLog.Ln;
	KernelLog.String("  line : "); KernelLog.Int(line, 0); KernelLog.Ln;
	KernelLog.String("  column : "); KernelLog.Int(col, 0); KernelLog.Ln;
	KernelLog.String("  message : "); KernelLog.String(msg^); KernelLog.Ln
END DefaultReportError;

(* ---- helpers ---------------------------------------------------------------*)

PROCEDURE NewString(CONST x : ARRAY OF CHAR) : String;
VAR t : String;
BEGIN
	NEW(t, LEN(x)); COPY(x, t^); RETURN t
END NewString;

(* result := a || b *)
PROCEDURE Append(a : String; CONST b : ARRAY OF CHAR) : String;
VAR s : String;
	i, al, bl : SIZE;
BEGIN
	al := LEN(a^); bl := LEN(b);
	NEW(s, al+bl-1);
	FOR i := 0 TO al-1 DO s^[i] := a^[i] END;
	FOR i := 0 TO bl-1 DO s^[al+i-1] := b[i] END;
	RETURN s
END Append;

PROCEDURE LowerCase(s : String);
VAR i : SIZE;
BEGIN
	FOR i := 0 TO LEN(s^)-1 DO s^[i] := Strings.LOW(s^[i]) END
END LowerCase;

END SkinLanguage.

