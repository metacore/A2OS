MODULE HTMLParser;	(** AUTHOR "Simon L. Keel" (heavily based on swalthert's "XMLParser"); PURPOSE "HTML parser"; *)

IMPORT
	Strings, KernelLog, DynamicStrings, Scanner := HTMLScanner, XML;

TYPE
	String = Strings.String;

	Node = POINTER TO RECORD
		name : String;
		back : Node;
	END;


	OpenTagStack= OBJECT
		VAR
			top : Node;

		PROCEDURE &Init*;
		BEGIN
			top := NIL;
		END Init;

		PROCEDURE Insert(s: String);
		VAR
			node : Node;
		BEGIN
			NEW(node);
			node.name := s;
			node.back := top;
			top := node;
		END Insert;

		PROCEDURE Remove(s: String);
		VAR
			node, old : Node;
		BEGIN
			old := NIL;
			node := top;
			WHILE (node#NIL) & (s^ # node.name^) DO
				old := node;
				node := node.back;
			END;
			IF node#NIL THEN
				IF old=NIL THEN
					top := node.back;
				ELSE
					old.back := node.back;
				END;
			END;
		END Remove;

		PROCEDURE IsMember(s: String): BOOLEAN;
		VAR
			node : Node;
		BEGIN
			node := top;
			WHILE (node#NIL) & (s^ # node.name^) DO
				node := node.back;
			END;
			RETURN node#NIL;
		END IsMember;

		(** For debugging pupose only. **)
		PROCEDURE Print;
		VAR
			node : Node;
		BEGIN
			node := top;
			WHILE (node#NIL) DO
				KernelLog.String(node.name^); KernelLog.Ln();
				node := node.back;
			END;
			KernelLog.String("----------"); KernelLog.Ln();
		END Print;

	END OpenTagStack;


	Parser* = OBJECT
		VAR
			scanner: Scanner.Scanner;
			openTagStack : OpenTagStack;
			elemReg*: XML.ElementRegistry;
			reportError*: PROCEDURE {DELEGATE} (pos, line, row: LONGINT; msg: ARRAY OF CHAR);
			closedTag : String;
			newTagName : String;
			closedTagPremature : BOOLEAN;

		PROCEDURE &Init*(s: Scanner.Scanner);
		BEGIN
			reportError := DefaultReportError;
			scanner := s;
			NEW(openTagStack);
		END Init;

		PROCEDURE Error(msg: ARRAY OF CHAR);
		BEGIN
			reportError(scanner.GetPos(), scanner.line, scanner.col, msg)
		END Error;

		PROCEDURE CheckSymbol(expectedSymbols: SET; errormsg: ARRAY OF CHAR): BOOLEAN;
		BEGIN
			IF ~(scanner.sym IN expectedSymbols) THEN
				Error(errormsg); RETURN FALSE
			ELSE
				RETURN TRUE
			END
		END CheckSymbol;

		PROCEDURE Parse*(): XML.Document;
		VAR
			doc: XML.Document;
			decl: XML.XMLDecl;
			dtd, newDtd: XML.DocTypeDecl;
			e : XML.Element;
			s: String;
			ds: DynamicStrings.DynamicString;
			msg: ARRAY 21 OF CHAR;
		BEGIN
			NEW(doc);
			dtd := doc.GetDocTypeDecl();

			WHILE TRUE DO
				scanner.ScanContent();
				CASE scanner.sym OF
				(* <?xml *)
				| Scanner.TagXMLDeclOpen:
					decl := ParseXMLDecl();
					IF decl#NIL THEN doc.AddContent(decl) END;
				(* <!-- ... --> *)
				| Scanner.Comment: doc.AddContent(ParseComment())
				(* <!... *)
				| Scanner.TagDeclOpen:
					s := scanner.GetStr();
					Strings.UpperCase(s^);
					IF s^ = 'DOCTYPE' THEN
						newDtd := ParseDocTypeDecl();
						IF dtd=NIL THEN
							IF newDtd#NIL THEN
								dtd := newDtd;
								doc.AddContent(dtd);
							END;
						END;
					ELSE
						NEW(ds);
						msg := "ignoring '<"; ds.Append(msg); ds.Append(s^); ds.Append(msg);
						s := ds.ToArrOfChar();
						Error(s^);
					END;
				(* < *)
				| Scanner.TagElemStartOpen:
					ParseStartTagName();
					e := ParseElement();
					IF e # NIL THEN doc.AddContent(e) END;
				(* char data *)
				| Scanner.CharData: doc.AddContent(ParseCharData())
				(* </ *)
				| Scanner.TagElemEndOpen:
					(* ignore *)
					s := ParseEndTag();
				(* EOF *)
				| Scanner.Eof: RETURN doc
				ELSE
					Error("unknown content");
				END;
			END;
		END Parse;

		PROCEDURE ParseXMLDecl(): XML.XMLDecl;
		VAR
			decl: XML.XMLDecl;
			s: String;
		BEGIN
			NEW(decl);
			scanner.ScanMarkup();
			IF ~CheckSymbol({Scanner.Name}, "<?xml>: 'version' expected") THEN RETURN NIL END;
			s := scanner.GetStr();
			IF s^ # "version" THEN Error("<?xml>: 'version' expected"); RETURN NIL END;
			scanner.ScanMarkup();
			IF ~CheckSymbol({Scanner.Equal}, "<?xml>: '=' expected") THEN RETURN NIL END;
			scanner.ScanMarkup();
			IF ~CheckSymbol({Scanner.Literal}, "<?xml>: Version Number expected") THEN RETURN NIL END;
			s := scanner.GetStr();
			IF s=NIL THEN s:=Strings.NewString(""); END;
			decl.SetVersion(s^);
			scanner.ScanMarkup();
			s := scanner.GetStr();
			Strings.LowerCase(s^);
			IF (scanner.sym = Scanner.Name) & (s^ = "encoding") THEN
				scanner.ScanMarkup();
				IF ~CheckSymbol({Scanner.Equal}, "<?xml>: encoding: '=' expected") THEN RETURN decl END;
				scanner.ScanMarkup();
				IF ~CheckSymbol({Scanner.Literal}, "<?xml>: Encoding Name expected") THEN RETURN decl END;
				s := scanner.GetStr();
				IF s=NIL THEN s:=Strings.NewString(""); END;
				decl.SetEncoding(s^);
				scanner.ScanMarkup();
				 s := scanner.GetStr();
				 Strings.LowerCase(s^);
			END;
			IF (scanner.sym = Scanner.Name) & (s^ = "standalone") THEN
				scanner.ScanMarkup();
				IF ~CheckSymbol({Scanner.Equal}, "<?xml>: standalone: '=' expected") THEN RETURN decl END;
				scanner.ScanMarkup();
				IF ~CheckSymbol({Scanner.Literal}, '<?xml>: standalone: "yes" or "no" expected') THEN RETURN decl END;
				s := scanner.GetStr();
				Strings.LowerCase(s^);
				IF s^ = "yes" THEN decl.SetStandalone(TRUE)
				ELSIF s^ = "no" THEN decl.SetStandalone(FALSE)
				ELSE Error('<?xml>: standalone: "yes" or "no" expected'); RETURN decl
				END;
				scanner.ScanMarkup()
			END;
			WHILE (scanner.sym#Scanner.TagPIClose) & (scanner.sym#Scanner.Eof) DO
				scanner.ScanMarkup();
			END;
			IF scanner.sym=Scanner.Eof THEN Error("<?xml>: '?>' expected") END;
			RETURN decl
		END ParseXMLDecl;

		PROCEDURE ParseComment(): XML.Comment;
		VAR comment: XML.Comment; s: String;
		BEGIN
			NEW(comment);
			s := scanner.GetStr();
			comment.SetStr(s^);
			RETURN comment
		END ParseComment;

		PROCEDURE ParseDocTypeDecl(): XML.DocTypeDecl;
		VAR
			dtd: XML.DocTypeDecl;
			externalSubset: XML.EntityDecl;
			s: String;
		BEGIN
			NEW(dtd);
			scanner.ScanMarkup();
			IF ~CheckSymbol({Scanner.Name}, "<!DOCTYPE: DTD name expected") THEN RETURN NIL END;
			s := scanner.GetStr();
			dtd.SetName(s^);
			scanner.ScanMarkup();
			IF scanner.sym = Scanner.Name THEN	(* DTD points to external subset *)
				NEW(externalSubset);
				s := scanner.GetStr();
				Strings.UpperCase(s^);
				IF s^ = 'SYSTEM' THEN
					scanner.ScanMarkup();
					s := ParseSystemLiteral();
					IF s=NIL THEN s:=Strings.NewString(""); END;
					externalSubset.SetSystemId(s^);
					scanner.ScanMarkup();
				ELSIF s^ = 'PUBLIC' THEN
					scanner.ScanMarkup();
					s := ParsePubidLiteral();
					IF s=NIL THEN s:=Strings.NewString(""); END;
					externalSubset.SetPublicId(s^);
					scanner.ScanMarkup();
					IF scanner.sym=Scanner.Literal THEN
						s := ParseSystemLiteral();
						IF s=NIL THEN s:=Strings.NewString(""); END;
						externalSubset.SetSystemId(s^);
						scanner.ScanMarkup();
					ELSE
						s:=Strings.NewString("");
						externalSubset.SetSystemId(s^);
					END;
				ELSE
					Error("<!DOCTYPE>:'SYSTEM' or 'PUBLIC' expected");
					RETURN NIL;
				END;
				dtd.SetExternalSubset(externalSubset);
			END;
			WHILE (scanner.sym#Scanner.TagClose) & (scanner.sym#Scanner.Eof) DO
				scanner.ScanMarkup();
			END;
			IF scanner.sym=Scanner.Eof THEN Error("<!DOCTYPE>: '>' expected") END;
			RETURN dtd;
		END ParseDocTypeDecl;

		PROCEDURE ParseSystemLiteral(): String;
		VAR systemLiteral: String;
		BEGIN
			IF ~CheckSymbol({Scanner.Literal}, "System Literal expected") THEN RETURN NIL END;
			systemLiteral := scanner.GetStr();
			RETURN systemLiteral
		END ParseSystemLiteral;

		PROCEDURE ParsePubidLiteral(): String;
		VAR pubidLiteral: String;
		BEGIN
			IF ~CheckSymbol({Scanner.Literal}, "PubidLiteral expected") THEN RETURN NIL END;
			pubidLiteral := scanner.GetStr();
			IF ~IsPubidLiteral(pubidLiteral^) THEN Error("not a correct Pubid Literal"); RETURN NIL END;
			RETURN pubidLiteral
		END ParsePubidLiteral;

		PROCEDURE ParseCharData(): XML.ArrayChars;
		VAR
			cd: XML.ArrayChars;
			s: String;
		BEGIN
			NEW(cd);
			s := scanner.GetStr();
			cd.SetStr(s^);
			RETURN cd
		END ParseCharData;

		PROCEDURE ParseElement(): XML.Element;
		VAR
			e: XML.Element;
			empty: BOOLEAN;
			name, s: String;
(*			ds: DynamicStrings.DynamicString;
			msg: ARRAY 21 OF CHAR; *)
		BEGIN
			ParseStartTag(e, empty);
			IF e = NIL THEN RETURN NIL END;
			IF empty THEN
				openTagStack.Remove(e.GetName());
				RETURN e;
			END;
			name := e.GetName();
			IF name^ = "SCRIPT" THEN
				scanner.ScanSCRIPT();
				e.AddContent(ParseComment());
				RETURN e;
			END;
			IF name^ = "STYLE" THEN
				scanner.ScanSTYLE();
				e.AddContent(ParseComment());
				RETURN e;
			END;
			WHILE TRUE DO
				scanner.ScanContent();
				CASE scanner.sym OF
				| Scanner.CharData: e.AddContent(ParseCharData())
				| Scanner.TagElemStartOpen:
					ParseStartTagName();
					REPEAT
						IF PrematureTagClosing(name, newTagName) THEN
							closedTagPremature := TRUE;
							openTagStack.Remove(name);
						(*	NEW(ds);
							msg := "closing '<"; ds.Append(msg); ds.Append(name^);
							msg := ">' before opening '<"; ds.Append(msg); ds.Append(newTagName^);
							msg := ">'"; ds.Append(msg); s := ds.ToArrOfChar();
							Error(s^);	*)
							RETURN e;
						END;
						closedTagPremature := FALSE;
						e.AddContent(ParseElement());
						IF closedTag#NIL THEN
							IF closedTag^=name^ THEN
								openTagStack.Remove(name);
								closedTag := NIL;
							END;
							RETURN e;
						END;
					UNTIL ~closedTagPremature;
				| Scanner.Comment: e.AddContent(ParseComment())
				| Scanner.TagPIOpen:
					WHILE (scanner.sym#Scanner.TagClose) & (scanner.sym#Scanner.Eof) DO
						scanner.ScanMarkup();
					END;
					IF scanner.sym=Scanner.Eof THEN Error("'>' expected") END;
				| Scanner.TagElemEndOpen:
					s := ParseEndTag();
					IF s#NIL THEN
						openTagStack.Remove(name);
						IF s^=name^ THEN
							closedTag := NIL;
						ELSE
							closedTag := s;
						END;
						RETURN e;
					END;
				| Scanner.Eof: Error("element not closed"); RETURN e
				ELSE
					Error("unknown Element Content");
				END;
			END;
		END ParseElement;

		PROCEDURE ParseStartTagName;
		BEGIN
			scanner.ScanMarkup();
			IF ~CheckSymbol({Scanner.Name}, "Element Name expected") THEN
				newTagName := Strings.NewString("");
				RETURN
			END;
			newTagName := scanner.GetStr();
			Strings.UpperCase(newTagName^);
		END ParseStartTagName;

		PROCEDURE ParseStartTag(VAR e: XML.Element; VAR empty: BOOLEAN);
		VAR s: String;
		BEGIN
			s := newTagName;
			IF elemReg # NIL THEN
				e := elemReg.InstantiateElement(s^)
			END;
			IF e = NIL THEN NEW(e) END;
			e.SetName(s^);
			openTagStack.Insert(s);
			scanner.ScanMarkup();
			WHILE scanner.sym = Scanner.Name DO
				e.AddAttribute(ParseAttribute());
			END;
			IF ~CheckSymbol({Scanner.TagEmptyElemClose, Scanner.TagClose}, "'/>' or '>' expected") THEN RETURN END;
			IF scanner.sym = Scanner.TagEmptyElemClose THEN
				empty := TRUE
			ELSIF scanner.sym = Scanner.TagClose THEN
				IF IsSolitaryTag(e.GetName()) THEN
					empty := TRUE;
				ELSE
					empty := FALSE;
				END;
			END
		END ParseStartTag;

		PROCEDURE ParseAttribute(): XML.Attribute;
		VAR a: XML.Attribute; s: String;
		BEGIN
			NEW(a);
			s := scanner.GetStr();
			a.SetName(s^);
			scanner.ScanMarkup();
			IF scanner.sym=Scanner.Equal THEN
				scanner.ScanAttributeValue();
				IF ~CheckSymbol({Scanner.Literal}, "Attribute Value expected") THEN RETURN a END;
				s := scanner.GetStr();
				a.SetValue(s^);
				scanner.ScanMarkup();
			ELSE
				s:=Strings.NewString("");
				a.SetValue(s^);
			END;
			RETURN a
		END ParseAttribute;

		PROCEDURE ParseEndTag():String;
		VAR ds: DynamicStrings.DynamicString; s: String; msg: ARRAY 14 OF CHAR;
		BEGIN
			scanner.ScanMarkup();
			s := scanner.GetStr();
			Strings.UpperCase(s^);
			IF (scanner.sym = Scanner.Name) THEN
				scanner.ScanMarkup();
				IF ~CheckSymbol({Scanner.TagClose}, "'>' expected") THEN RETURN NIL; END;
				IF openTagStack.IsMember(s) THEN
					RETURN s;
				ELSE
					NEW(ds);
					msg := "ignoring '</"; ds.Append(msg); ds.Append(s^);
					msg := ">'"; ds.Append(msg); s := ds.ToArrOfChar();
					Error(s^);
					RETURN NIL;
				END;
			ELSE
				NEW(ds);
				msg := "ignoring '</"; ds.Append(msg); ds.Append(s^);
				s := ds.ToArrOfChar();
				Error(s^);
				RETURN NIL;
			END
		END ParseEndTag;

	END Parser;


	PROCEDURE IsPubidLiteral(CONST str: ARRAY OF CHAR): BOOLEAN;
	VAR i, len: SIZE; ch: CHAR;
	BEGIN
		i := 0; len := LEN(str); ch := str[0];
		REPEAT
			ch := str[i]; INC(i)
		UNTIL ((ch # 20X) & (ch # 0DX) & (ch # 0AX) & ((ch < 'a') OR ('z' < ch)) & ((ch < 'A') & ('Z' < ch))
				& ((ch < '0') & ('9' < ch)) & (ch # '(') & (ch # ')') & (ch # '+') & (ch # ',') & (ch # '.')
				& (ch # '/') & (ch # ':') & (ch # '=') & (ch # '?') & (ch # ';') & (ch # '!') & (ch # '*') & (ch # '#')
				& (ch # '@') & (ch # '$') & (ch # '_') & (ch # '%')) OR (i >= len);
		RETURN i = len
	END IsPubidLiteral;

	PROCEDURE DefaultReportError(pos, line, col: LONGINT; msg: ARRAY OF CHAR);
	BEGIN
		KernelLog.Enter; KernelLog.Char(CHR(9H)); KernelLog.Char(CHR(9H)); KernelLog.String("pos "); KernelLog.Int(pos, 6);
		KernelLog.String(", line "); KernelLog.Int(line, 0); KernelLog.String(", column "); KernelLog.Int(col, 0);
		KernelLog.String("    "); KernelLog.String(msg); KernelLog.Exit;
	END DefaultReportError;

	PROCEDURE IsSolitaryTag(name: String): BOOLEAN;
	BEGIN
		IF name^ = "AREA" THEN RETURN TRUE END;
		IF name^ = "BASE" THEN RETURN TRUE END;
		IF name^ = "BASEFONT" THEN RETURN TRUE END;
		IF name^ = "BR" THEN RETURN TRUE END;
		IF name^ = "COL" THEN RETURN TRUE END;
		IF name^ = "FRAME" THEN RETURN TRUE END;
		IF name^ = "HR" THEN RETURN TRUE END;
		IF name^ = "IMG" THEN RETURN TRUE END;
		IF name^ = "INPUT" THEN RETURN TRUE END;
		IF name^ = "ISINDEX" THEN RETURN TRUE END;
		IF name^ = "LINK" THEN RETURN TRUE END;
		IF name^ = "META" THEN RETURN TRUE END;
		IF name^ = "PARAM" THEN RETURN TRUE END;
		RETURN FALSE
	END IsSolitaryTag;

	PROCEDURE PrematureTagClosing(name, next: String): BOOLEAN;
	BEGIN
		IF name^ = "COLGROUP" THEN
			IF next^ # "COL" THEN RETURN TRUE END;
		ELSIF name^ = "DD" THEN
			IF (next^ = "DD") OR (next^ = "DT") OR (next^ = "DL") THEN RETURN TRUE END;
		ELSIF name^ = "DT" THEN
			IF (next^ = "DT") OR (next^ = "DD") OR (next^ = "DL") THEN RETURN TRUE END;
		ELSIF name^ = "HEAD" THEN
			IF next^ = "BODY" THEN RETURN TRUE END;
		ELSIF name^ = "LI" THEN
			IF next^ = "LI" THEN RETURN TRUE END;
		ELSIF name^ = "OPTION" THEN
			RETURN TRUE;
		ELSIF name^ = "P" THEN
			IF next^ = "P" THEN RETURN TRUE END;
		ELSIF name^ = "TBODY" THEN
			IF (next^ = "TBODY") OR (next^ = "THEAD") OR (next^ = "TFOOT") THEN RETURN TRUE END;
		ELSIF name^ = "TD" THEN
			IF (next^ = "TD") OR (next^ = "TH") OR (next^ = "TR") OR (next^ = "THEAD") OR (next^ = "TBODY") OR (next^ = "TFOOT") THEN RETURN TRUE END;
		ELSIF name^ = "TFOOT" THEN
			IF (next^ = "TBODY") OR (next^ = "THEAD") OR (next^ = "TFOOT") THEN RETURN TRUE END;
		ELSIF name^ = "TH" THEN
			IF (next^ = "TD") OR (next^ = "TH") OR (next^ = "TR") OR (next^ = "THEAD") OR (next^ = "TBODY") OR (next^ = "TFOOT") THEN RETURN TRUE END;
		ELSIF name^ = "THEAD" THEN
			IF (next^ = "TBODY") OR (next^ = "THEAD") OR (next^ = "TFOOT") THEN RETURN TRUE END;
		ELSIF name^ = "TR" THEN
			IF (next^ = "TR")  OR (next^ = "THEAD") OR (next^ = "TBODY") OR (next^ = "TFOOT") THEN RETURN TRUE END;
		END;
		RETURN FALSE

		(* The following code is html-standard. but it's too strict to get good results!
		IF name^ = "COLGROUP" THEN
			IF next^ # "COL" THEN RETURN TRUE END;
		ELSIF name^ = "DD" THEN
			IF ~IsFlow(next) THEN RETURN TRUE END;
		ELSIF name^ = "DT" THEN
			IF ~IsInline(next) THEN RETURN TRUE END;
		ELSIF name^ = "HEAD" THEN
			IF next^ = "BODY" THEN RETURN TRUE END;
		ELSIF name^ = "LI" THEN
			IF ~IsFlow(next) THEN RETURN TRUE END;
		ELSIF name^ = "OPTION" THEN
			RETURN TRUE;
		ELSIF name^ = "P" THEN
			IF ~IsInline(next) THEN RETURN TRUE END;
		ELSIF name^ = "TBODY" THEN
			IF next^ # "TR" THEN RETURN TRUE END;
		ELSIF name^ = "TD" THEN
			IF ~IsFlow(next) THEN RETURN TRUE END;
		ELSIF name^ = "TFOOT" THEN
			IF next^ # "TR" THEN RETURN TRUE END;
		ELSIF name^ = "TH" THEN
			IF ~IsFlow(next) THEN RETURN TRUE END;
		ELSIF name^ = "THEAD" THEN
			IF next^ # "TR" THEN RETURN TRUE END;
		ELSIF name^ = "TR" THEN
			IF (next^ # "TH") & (next^ # "TD") THEN RETURN TRUE END;
		END;
		RETURN FALSE
		*)
	END PrematureTagClosing;

(*
	PROCEDURE IsFlow(name: String): BOOLEAN;
	BEGIN
		IF IsInline(name) THEN RETURN TRUE END;
		IF name^ = "P" THEN RETURN TRUE END;
		IF name^ = "H1" THEN RETURN TRUE END;
		IF name^ = "H2" THEN RETURN TRUE END;
		IF name^ = "H3" THEN RETURN TRUE END;
		IF name^ = "H4" THEN RETURN TRUE END;
		IF name^ = "H5" THEN RETURN TRUE END;
		IF name^ = "H6" THEN RETURN TRUE END;
		IF name^ = "UL" THEN RETURN TRUE END;
		IF name^ = "OL" THEN RETURN TRUE END;
		IF name^ = "PRE" THEN RETURN TRUE END;
		IF name^ = "DL" THEN RETURN TRUE END;
		IF name^ = "DIV" THEN RETURN TRUE END;
		IF name^ = "NOSCRIPT" THEN RETURN TRUE END;
		IF name^ = "BLOCKQUOTE" THEN RETURN TRUE END;
		IF name^ = "FORM" THEN RETURN TRUE END;
		IF name^ = "HR" THEN RETURN TRUE END;
		IF name^ = "TABLE" THEN RETURN TRUE END;
		IF name^ = "FIELDSET" THEN RETURN TRUE END;
		IF name^ = "ADDRESS" THEN RETURN TRUE END;
		RETURN FALSE
	END IsFlow;

	PROCEDURE IsInline(name: String): BOOLEAN;
	BEGIN
		IF name^ = "TT" THEN RETURN TRUE END;
		IF name^ = "I" THEN RETURN TRUE END;
		IF name^ = "B" THEN RETURN TRUE END;
		IF name^ = "BIG" THEN RETURN TRUE END;
		IF name^ = "SMALL" THEN RETURN TRUE END;
		IF name^ = "EM" THEN RETURN TRUE END;
		IF name^ = "STRONG" THEN RETURN TRUE END;
		IF name^ = "DFN" THEN RETURN TRUE END;
		IF name^ = "CODE" THEN RETURN TRUE END;
		IF name^ = "SAMP" THEN RETURN TRUE END;
		IF name^ = "KBD" THEN RETURN TRUE END;
		IF name^ = "VAR" THEN RETURN TRUE END;
		IF name^ = "CITE" THEN RETURN TRUE END;
		IF name^ = "ABBR" THEN RETURN TRUE END;
		IF name^ = "ACRONYM" THEN RETURN TRUE END;
		IF name^ = "A" THEN RETURN TRUE END;
		IF name^ = "IMG" THEN RETURN TRUE END;
		IF name^ = "OBJECT" THEN RETURN TRUE END;
		IF name^ = "BR" THEN RETURN TRUE END;
		IF name^ = "SCRIPT" THEN RETURN TRUE END;
		IF name^ = "MAP" THEN RETURN TRUE END;
		IF name^ = "Q" THEN RETURN TRUE END;
		IF name^ = "SUB" THEN RETURN TRUE END;
		IF name^ = "SUP" THEN RETURN TRUE END;
		IF name^ = "SPAN" THEN RETURN TRUE END;
		IF name^ = "BDO" THEN RETURN TRUE END;
		IF name^ = "INPUT" THEN RETURN TRUE END;
		IF name^ = "SELECT" THEN RETURN TRUE END;
		IF name^ = "TEXTAREA" THEN RETURN TRUE END;
		IF name^ = "LABEL" THEN RETURN TRUE END;
		IF name^ = "BUTTON" THEN RETURN TRUE END;
		RETURN FALSE
	END IsInline;
*)

END HTMLParser.
