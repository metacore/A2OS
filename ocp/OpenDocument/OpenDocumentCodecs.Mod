MODULE OpenDocumentCodecs; (** AUTHOR "Patrick Hunziker"; PURPOSE "Codecs for OpenDocument format"; *)

IMPORT TextUtilities, Texts, Files, Codecs, Streams, Strings, UTF8Strings, OpenDocument, Repositories, FP1616, XML, XMLScanner, XMLParser, XMLObjects, KernelLog;

CONST CR=0DX;
		LF=0AX;

TYPE TextDecoder* = OBJECT(Codecs.TextDecoder)
	VAR errors : BOOLEAN;
		text : Texts.Text;
		doc : XML.Document;
		cont, tc, tc2 : XMLObjects.Enumerator; ptr : ANY; root : XML.Element; str : Strings.String;
		o : Texts.ObjectPiece; attr: Texts.Attributes; fi : Texts.FontInfo;
		stylename, pstylename: ARRAY 64 OF CHAR;
		link : Texts.Link;

		PROCEDURE Error(CONST x : ARRAY OF CHAR);
		BEGIN
			KernelLog.String("OpenDocument Decoder Error: ");
			KernelLog.String(x); KernelLog.Ln;
			errors := TRUE
		END Error;

		PROCEDURE GetUTF8Char(r : Streams.Reader; VAR u : Texts.Char32; VAR pos : LONGINT) : BOOLEAN;
		VAR ch : ARRAY 8 OF CHAR; i : LONGINT;
		BEGIN
			ch[0] := r.Get(); INC(pos);
			FOR i := 1 TO ORD(UTF8Strings.CodeLength[ORD(ch[0])]) - 1 DO ch[i] := r.Get(); INC(pos) END;
			i := 0;
			RETURN UTF8Strings.DecodeChar(ch, i, u)
		END GetUTF8Char;

		PROCEDURE InsertPiece(charContent : XML.CDataSect);
		VAR i, m, tpos, res : LONGINT; ch, last : Texts.Char32; tempUCS32 : ARRAY 1024 OF Texts.Char32;
			oldpos, len : LONGINT;
			r, sr : Streams.StringReader; token : ARRAY 256 OF CHAR;
			tempInt: LONGINT;
			buffer : Strings.String;
			char : CHAR;
			cStyle : Texts.CharacterStyle;
			pStyle : Texts.ParagraphStyle;
		BEGIN
			m := LEN(tempUCS32) - 1;
			buffer := charContent.GetStr();
			NEW(r, LEN(buffer^));
			r.Set(buffer^);

			oldpos := text.GetLength();
			len := charContent.GetLength();
			tpos := 0;
			REPEAT
				IF GetUTF8Char(r, ch, tpos) THEN
					IF i = m  THEN tempUCS32[i] := 0; text.InsertUCS32(text.GetLength(), tempUCS32); i := 0 END;
					IF (last # ORD(CR)) OR (ch # ORD(LF)) THEN
						IF ch = ORD(CR) THEN tempUCS32[i] := ORD(LF)
						ELSE tempUCS32[i] := ch
						END;
						INC(i)
					END;
					last := ch;
				END
			UNTIL (tpos >= len) OR (r.res # Streams.Ok);
			tempUCS32[i] := 0; text.InsertUCS32(text.GetLength(), tempUCS32);

			(* get style from the System *)
			cStyle := Texts.GetCharacterStyleByName(stylename);
			pStyle := Texts.GetParagraphStyleByName(pstylename);

			(* set attributes to emulate style in non-style supporting applications *)
			IF (attr = NIL) THEN NEW(attr); END;
			attr.voff := 0; attr.color := 0000000FFH; attr.bgcolor := 000000000H;
			IF (attr.fontInfo = NIL) THEN NEW(fi); attr.fontInfo := fi; END;
			attr.fontInfo.name := "Oberon"; attr.fontInfo.size := 10; attr.fontInfo.style := {};
			IF (stylename = "Bold") THEN attr.fontInfo.style := {0};
			ELSIF (stylename = "Highlight") THEN attr.fontInfo.style := {1};
			ELSIF (stylename = "Assertion") THEN attr.fontInfo.style := {0}; attr.color := 00000FFFFH;
			ELSIF (stylename = "Debug") THEN attr.color := 00000FFFFH;
			ELSIF (stylename = "Lock") THEN attr.color := LONGINT(0FF00FFFFH);
			ELSIF (stylename = "Stupid") THEN attr.color := LONGINT(0FF0000FFH);
			ELSIF (stylename = "Comment") THEN attr.color := LONGINT(0808080FFH);
			ELSIF (stylename = "Preferred") THEN attr.fontInfo.style := {0}; attr.color := LONGINT(0800080FFH);
			ELSIF Strings.Match("AdHoc*", stylename) THEN
				NEW(sr, LEN(stylename)); sr.Set(stylename);
				sr.SkipWhitespace; sr.Token(token);												(* AdHoc *)
				sr.SkipWhitespace; sr.Token(token); COPY(token, attr.fontInfo.name); 				(* family *)
				sr.SkipWhitespace; sr.Token(token); Strings.StrToInt(token, attr.fontInfo.size);		(* size *)
				sr.SkipWhitespace; sr.Token(token); Strings.StrToInt(token, res); 					(* style *)
				IF (res = 0) THEN attr.fontInfo.style := {};
				ELSIF (res = 1) THEN attr.fontInfo.style := {0};
				ELSIF (res = 2) THEN attr.fontInfo.style := {1};
				ELSIF (res = 3) THEN attr.fontInfo.style := {0,1};
				ELSE attr.fontInfo.style := {};
				END;
				sr.SkipWhitespace; sr.Token(token); Strings.StrToInt(token, attr.voff);				(* voff *)
				sr.SkipWhitespace; sr.Token(token); Strings.HexStrToInt(token, attr.color, res);		(* color *)
				sr.SkipWhitespace; sr.Token(token); Strings.HexStrToInt(token, attr.bgcolor, res);	(* bgcolor *)

				(* add Ad-Hoc style to the System in case it was not present already *)
				IF cStyle = NIL THEN
					NEW(cStyle);
					COPY(stylename, cStyle.name);
					COPY(attr.fontInfo.name, cStyle.family);
					cStyle.size := FP1616.FloatToFixp(attr.fontInfo.size);
					cStyle.style := attr.fontInfo.style;
					cStyle.baselineShift := attr.voff;
					cStyle.color := attr.color;
					cStyle.bgColor := attr.bgcolor;
					Texts.AddCharacterStyle(cStyle);
				END;
			ELSE
				(* Get the attributes from the style for compatibility *)
				IF (cStyle # NIL) THEN attr := TextUtilities.StyleToAttribute(cStyle)
				ELSE token := "Style not present in System: "; Strings.Append(token, stylename); Error(token); END;
			END;
			text.SetAttributes(oldpos, text.GetLength()-oldpos, attr.Clone());

			(* set the style for style supporting applications *)
			text.SetCharacterStyle(oldpos, text.GetLength()-oldpos, cStyle);

			(* Get AdHoc paragraph style & add to system *)
			IF Strings.Match("AdHoc*", pstylename) & (pStyle = NIL) THEN
				NEW(pStyle);
				NEW(sr, LEN(pstylename)); sr.Set(pstylename);
				sr.SkipWhitespace; sr.Token(token); COPY(pstylename, pStyle.name);														(* AdHoc *)
				sr.SkipWhitespace; sr.Token(token); Strings.StrToInt(token, tempInt); pStyle.alignment := tempInt;							(* alignment *)
				sr.SkipWhitespace; sr.Token(token); Strings.StrToInt(token, tempInt); pStyle.firstIndent := FP1616.FloatToFixp(tempInt);		(* first Indent *)
				sr.SkipWhitespace; sr.Token(token); Strings.StrToInt(token, tempInt); pStyle.leftIndent := FP1616.FloatToFixp(tempInt);		(* left Indent *)
				sr.SkipWhitespace; sr.Token(token); Strings.StrToInt(token, tempInt); pStyle.rightIndent := FP1616.FloatToFixp(tempInt);	(* right Indent *)
				sr.SkipWhitespace; sr.Token(token); Strings.StrToInt(token, tempInt); pStyle.spaceBefore := FP1616.FloatToFixp(tempInt);	(* space above *)
				sr.SkipWhitespace; sr.Token(token); Strings.StrToInt(token, tempInt); pStyle.spaceAfter := FP1616.FloatToFixp(tempInt);		(* space below *)
				sr.SkipWhitespace; char := sr.Peek(); IF (char = "t") THEN sr.SkipBytes(1); sr.RawString(token); COPY(token, pStyle.tabStops); END; (* tabstops *)
				Texts.AddParagraphStyle(pStyle);
			END;

			(* set the paragraph style *)
			IF (pStyle # NIL) THEN text.SetParagraphStyle(oldpos, text.GetLength()-oldpos, pStyle) END;
			(* set the link *)
			text.SetLink(oldpos, text.GetLength()-oldpos, link);
		END InsertPiece;

		PROCEDURE InsertChar(pos : LONGINT; ch : Texts.Char32);
		VAR bufUCS32 : ARRAY 2 OF Texts.Char32;
			oldpos : LONGINT;
			cStyle : Texts.CharacterStyle;
			pStyle : Texts.ParagraphStyle;
		BEGIN
			bufUCS32[0] := ch; bufUCS32[1] := 0;
			oldpos := text.GetLength();
			text.InsertUCS32(pos, bufUCS32);					 (* cursor moves automagically *)

			(* get style from the System *)
			cStyle := Texts.GetCharacterStyleByName(stylename);
			pStyle := Texts.GetParagraphStyleByName(pstylename);
			(* set the character style *)
			IF (cStyle # NIL) THEN text.SetCharacterStyle(oldpos, text.GetLength()-oldpos, cStyle) END;
			(* set the paragraph style *)
			IF (pStyle # NIL) THEN text.SetParagraphStyle(oldpos, text.GetLength()-oldpos, pStyle) END;
			(* set the link *)
			IF (link # NIL) THEN text.SetLink(oldpos, text.GetLength()-oldpos, link); KernelLog.String("bonk"); END;
		END InsertChar;

		PROCEDURE MalformedXML(pos, line, row: LONGINT; CONST msg: ARRAY OF CHAR);
		BEGIN
			Error(msg);
		END MalformedXML;

		PROCEDURE Open*(in : Streams.Reader; VAR res : LONGINT);
		VAR
			scanner : XMLScanner.Scanner; parser : XMLParser.Parser;
			d : XML.Document;
		BEGIN
			res := -1;
			errors := FALSE;
			IF in = NIL THEN Error("Input Stream is NIL"); RETURN; END;
			NEW(scanner, in); NEW(parser, scanner);
			parser.elemReg := Repositories.registry;
			parser.reportError := MalformedXML;
			d := parser.Parse();

			IF errors THEN RETURN END;
			OpenXML(d);
			res := 0;
		END Open;

		PROCEDURE OpenXML*(d : XML.Document);
		VAR lp : Texts.LabelPiece;
		BEGIN
			errors := FALSE;
			doc := d;
			NEW(text);
			text.AcquireWrite;

			NEW(attr);

			root := doc.GetRoot();
			cont := root.GetContents(); cont.Reset();
			WHILE cont.HasMoreElements() DO
				ptr := cont.GetNext();
				IF ptr IS XML.Element THEN
					str := ptr(XML.Element).GetName();
					IF (str # NIL) & (str^ = "Label") THEN
						str := ptr(XML.Element).GetAttributeValue("name");
						IF str # NIL THEN NEW(lp); lp.label := Strings.NewString(str^); text.InsertPiece(text.GetLength(), lp) END;
					ELSIF (str # NIL) & (str^ = "Paragraph") THEN
						tc := ptr(XML.Element).GetContents(); tc.Reset();
						str := ptr(XML.Element).GetAttributeValue("style");
						IF str # NIL THEN COPY(str^, pstylename); END;
						WHILE tc.HasMoreElements() DO
							ptr := tc.GetNext();
							IF ptr IS XML.Element THEN
								str := ptr(XML.Element).GetName();
								IF (str # NIL) & (str^ = "Label") THEN
									str := ptr(XML.Element).GetAttributeValue("name");
									IF str # NIL THEN NEW(lp); lp.label := Strings.NewString(str^); text.InsertPiece(text.GetLength(), lp) END;
								ELSIF (str # NIL) & (str^ = "Span") THEN
									tc2 := ptr(XML.Element).GetContents(); tc2.Reset();
									str := ptr(XML.Element).GetAttributeValue("style"); IF str # NIL THEN COPY(str^, stylename); END;
									str := ptr(XML.Element).GetAttributeValue("link"); IF str # NIL THEN NEW(link, LEN(str^)); COPY(str^, link^); ELSE link := NIL; END;
									WHILE tc2.HasMoreElements() DO
										ptr := tc2.GetNext();
										IF ptr IS XML.CDataSect THEN InsertPiece(ptr(XML.CDataSect)) END;
									END;
								ELSIF (str # NIL) & (str^ = "Object") THEN
									tc2 := ptr(XML.Element).GetContents(); tc2.Reset();
									IF tc2.HasMoreElements() THEN
										NEW(o); o.object := tc2.GetNext(); text.InsertPiece(text.GetLength(), o);
									END
								END
							END
						END;
						(* Insert a newline to finish paragraph *)
						(* InsertChar(text.GetLength(), Texts.NewLineChar); *)
					ELSIF (str # NIL) & (str^ = "Span") THEN
						COPY("Left", pstylename);
						tc := ptr(XML.Element).GetContents(); tc.Reset();
						str := ptr(XML.Element).GetAttributeValue("style"); IF str # NIL THEN COPY(str^, stylename); END;
						str := ptr(XML.Element).GetAttributeValue("link"); IF str # NIL THEN NEW(link, LEN(str^)); COPY(str^, link^); ELSE link := NIL; END;
						WHILE tc.HasMoreElements() DO
							ptr := tc.GetNext();
							IF ptr IS XML.CDataSect THEN InsertPiece(ptr(XML.CDataSect)) END;
						END
					ELSIF (str # NIL) & (str^ = "Object") THEN
						tc := ptr(XML.Element).GetContents(); tc.Reset();
						IF tc.HasMoreElements() THEN
							NEW(o); o.object := tc.GetNext(); text.InsertPiece(text.GetLength(), o);
						END;
					END;
				END
			END;
			text.ReleaseWrite;
		END OpenXML;

		PROCEDURE GetText*() : Texts.Text;
		BEGIN
			RETURN text;
		END GetText;

	END TextDecoder;

TYPE	TextEncoder* = OBJECT(Codecs.TextEncoder)
	VAR out: Streams.Writer;
		
		ch :Texts.Char32;
		r: Texts.TextReader;
		changed, pchanged, pOpen : BOOLEAN;
		stylename, pstylename: ARRAY 256 OF CHAR;
		cStyle: Texts.CharacterStyle;
		pStyle: Texts.ParagraphStyle;
		link : Texts.Link;
	(*	hStyle: Texts.HighlightStyle;             <-- TO DO
	*)
		(* Attributes attributes *)
		family, dfFamily : ARRAY 64 OF CHAR;
		size, dfSize : LONGINT;
		style, dfStyle : LONGINT;							(* 0 = regular; 1 = bold; 2 = italic; 3 = bold-italic *)
		voff, dfVoff : LONGINT;
		color, dfColor : LONGINT;
		bgcolor, dfBgcolor : LONGINT;
		
		doc: OpenDocument.Document;
		adhocindex:LONGINT;


		(* Set the default  attribute values *)
		PROCEDURE Init;
		BEGIN
			dfFamily := "Oberon";
			dfSize := 10;
			dfStyle := 0;
			dfVoff := 0;
			dfColor := 0000000FFH;
			dfBgcolor := 000000000H;
		END Init;

		(* extract the attributes from the current textreader *)
		PROCEDURE RetrieveAttributes;
		VAR tempstring, string: ARRAY 128 OF CHAR;
		BEGIN
			(* Get Character Style if any *)
			IF (r.cstyle # NIL) THEN
				cStyle := r.cstyle;
				COPY(cStyle.name, stylename);
				COPY(cStyle.family, family);
				size := cStyle.size;
				IF (cStyle.style = {}) THEN style := 0; ELSIF (cStyle.style = {0}) THEN style := 1; ELSIF (cStyle.style = {1}) THEN style := 2; ELSIF (cStyle.style = {0,1}) THEN style := 3; ELSE style := 0; END;
				voff := cStyle.baselineShift;
				color := cStyle.color;
				bgcolor := cStyle.bgColor;
			ELSE
				cStyle:=NIL; 

				
				(* Get attributes from char *)
				IF (r.font = NIL) THEN								(* Fix missing values *)
					family := dfFamily;
					size := dfSize;
					style := dfStyle;
				ELSE
					COPY(r.font.name, family);
					size := r.font.size;
					IF (r.font.style = {}) THEN style := 0; ELSIF (r.font.style = {0}) THEN style := 1; ELSIF (r.font.style = {1}) THEN style := 2; ELSIF (r.font.style = {0,1}) THEN style := 3; ELSE style := 0; END;
					
				END;
				voff := r.voff;
				color := r.color;
				bgcolor := r.bgcolor;

				(* Find appropriate style *)
				IF (color = 0000000FFH) & (style = 0) THEN stylename := "Normal"
				ELSIF (color = 0000000FFH) & (style = 1) THEN stylename := "Bold"
				ELSIF (color = 0000000FFH) & (style = 2) THEN stylename := "Highlight"
				ELSIF ((color = 00000FFFFH) OR (color = 00000AAFFH)) & (style = 1) THEN stylename := "Assertion"
				ELSIF (color = 00000FFFFH) & (style = 0) THEN stylename := "Debug"
				ELSIF (color = 0FF00FFFFH) & (style = 0) THEN stylename := "Lock"
				ELSIF (color = 0FF0000FFH) & (style = 0) THEN stylename := "Stupid"
				ELSIF ((color = 0808080FFH) OR (color = 08A8A8AFFH)) & (style = 0) THEN stylename := "Comment"
				ELSIF (color = 0800080FFH) & (style = 1) THEN stylename := "Preferred"
				ELSE
					tempstring := "AdHoc"; Strings.Append(tempstring, " ");
					Strings.Append(tempstring, family); Strings.Append(tempstring, " ");
					Strings.IntToStr(size, string); Strings.Append(tempstring, string); Strings.Append(tempstring, " ");
					Strings.IntToStr(style, string); Strings.Append(tempstring, string); Strings.Append(tempstring, " ");
					Strings.IntToStr(voff, string); Strings.Append(tempstring, string); Strings.Append(tempstring, " ");
					Strings.IntToHexStr(color,7, string); Strings.Append(tempstring, string); Strings.Append(tempstring, " ");
					Strings.IntToHexStr(bgcolor,7, string); Strings.Append(tempstring, string);
					COPY(tempstring, stylename);
					(* KernelLog.String("Writing Ad-hoc Style: "); KernelLog.String(tempstring);  KernelLog.Ln; *)
				END;
				
				
				
				
			END;
			(* Get Paragraph Style if any *)
			IF (r.pstyle # NIL) THEN
				pStyle := r.pstyle;
				COPY(pStyle.name, pstylename)
			ELSE
				pStyle := NIL;
				COPY("", pstylename)
			END;
			(* Get Link if any *)
			IF (r.link # NIL) THEN
				link := r.link;
			ELSE
				link := NIL;
			END;
		END RetrieveAttributes;

		PROCEDURE PrintAttributes;
		BEGIN
			KernelLog.String("# family: "); KernelLog.String(family);  KernelLog.Ln;
			KernelLog.String("# size: "); KernelLog.Int(size, 0);  KernelLog.Ln;
			KernelLog.String("# style: "); KernelLog.Int(style, 0);  KernelLog.Ln;
			KernelLog.String("# voff: "); KernelLog.Int(voff, 0);  KernelLog.Ln;
			KernelLog.String("# color: "); KernelLog.Hex(color, 0);  KernelLog.Ln;
			KernelLog.String("# bgcolor: "); KernelLog.Hex(bgcolor, 0);  KernelLog.Ln;
		END PrintAttributes;

		(* Return TRUE if current textreader attributes don't match the chached one *)
		PROCEDURE CompareAttributes():BOOLEAN;
		VAR tempstyle: LONGINT;
			isEqual : BOOLEAN;
		BEGIN
			IF (link = r.link) THEN
				IF r.cstyle # NIL THEN
					isEqual := (stylename = r.cstyle.name);
					RETURN ~isEqual;
				ELSE
					IF (r.font = NIL) THEN
						isEqual := (family = dfFamily) & (size = dfSize) & (style = dfStyle) & (voff = r.voff) & (color = r.color) & (bgcolor = r.bgcolor);
					ELSE
						IF (r.font.style = {}) THEN tempstyle := 0; ELSIF (r.font.style = {0}) THEN tempstyle := 1; ELSIF (r.font.style = {1}) THEN tempstyle := 2; ELSIF (r.font.style = {0,1}) THEN tempstyle := 3; ELSE tempstyle := 0; END;
						isEqual := (family = r.font.name) & (size = r.font.size) & (style = tempstyle) & (voff = r.voff) & (color = r.color) & (bgcolor = r.bgcolor);
					END;
					RETURN ~isEqual;
				END;
			ELSE
				RETURN TRUE;
			END
		END CompareAttributes;

		(* Return TRUE if current textreader paragraphstyle doesn't match the chached one *)
		PROCEDURE CompareParagraphs(): BOOLEAN;
		VAR isEqual : BOOLEAN;
		BEGIN
			IF r.pstyle # NIL THEN
				isEqual := (pstylename = r.pstyle.name);
				RETURN ~isEqual
			ELSIF (r.pstyle = NIL) & (pStyle = NIL) THEN
				RETURN FALSE;
			ELSE
				RETURN TRUE;
			END;
		END CompareParagraphs;

		PROCEDURE WriteSection;
			(* <text:section text:style-name="Sect1" text:name="Section1"> *)
		END WriteSection;
		
		PROCEDURE CloseSection;
		(*  </text:section> *)
		END CloseSection;

		PROCEDURE WriteParagraph(out: Streams.Writer; CONST name : ARRAY OF CHAR);
		BEGIN
			pOpen := TRUE;
			out.String("<text:p "); 
			out.String('text:style-name="'); 
			IF name="" THEN out.String("Standard") ELSE out.String(name) END;
			out.String('">');
		END WriteParagraph;

		PROCEDURE CloseParagraph(out:Streams.Writer);
		BEGIN
			IF pOpen THEN
				out.String("</text:p>");
				pOpen := FALSE;
			END;
		END CloseParagraph;

		PROCEDURE WriteSpan(out:Streams.Writer; CONST name: ARRAY OF CHAR); 
		BEGIN
			out.String("<text:span  ");
			IF name#"" THEN out.String('text:style-name="'); out.String(name); out.String('"'); END;
			IF link # NIL THEN out.String(' link="'); out.String(link^); out.String('"'); END;
			out.String("><![CDATA[")
		END WriteSpan;

		PROCEDURE CloseSpan(out:Streams.Writer);
		BEGIN
			out.String("]]></text:span>");
		END CloseSpan;

		PROCEDURE WriteObject(out:Streams.Writer; o : ANY);
		BEGIN
			out.Ln;
			out.String("<Object>");
			IF (o # NIL) & (o IS XML.Element) THEN
				o(XML.Element).Write(out, NIL, 1);
			END;
			out.String("</Object>");out.Ln;
		END WriteObject;

		PROCEDURE WriteLabel(out:Streams.Writer; CONST label: ARRAY OF CHAR);
		BEGIN
			out.String("<Label ");
			out.String('name="'); out.String(label); out.String('"/>');
		END WriteLabel;
		
		PROCEDURE WriteSpace(out:Streams.Writer); (*needed because whitespace after an xml tag is automatically suppressed*)
		BEGIN
			out.String("<text:s/>");
		END WriteSpace;
		
		PROCEDURE WriteTab(out:Streams.Writer);
		BEGIN
			out.String("<text:tab/>");
		END WriteTab;
		
		PROCEDURE WriteLineBreak(out:Streams.Writer);
		BEGIN
			out.String("<text:line-break/>");
		END WriteLineBreak;

		PROCEDURE Open*(out : Streams.Writer);
		BEGIN
			IF out = NIL THEN KernelLog.String("OpenDocument Encoder Error: output stream is NIL");
			ELSE SELF.out := out;
			END;
		END Open;

		PROCEDURE WriteText*(text : Texts.Text; VAR res : LONGINT);
		VAR
			contentfile: Files.File;
			w: Files.Writer; 

		BEGIN
			NEW(doc,"text"); 
			
			contentfile:=Files.New("content.xml"); 
			Files.OpenWriter(w,contentfile,0);
			WriteTextInternal(text, w, res);
			
			(*doc.WriteContent:=NIL;*)
			doc.AddStandardFiles;
			doc.AddFile(contentfile,"content.xml", OpenDocument.ZipLevel, OpenDocument.ZipStrategy, res); 
			doc.AddSignatureFile;

			doc.Write(out);
			out.Update;
		END WriteText;

		PROCEDURE WriteTextInternal(text : Texts.Text; out:Streams.Writer; VAR res : LONGINT);
		VAR
			buf : Strings.String; rbuf : ARRAY 4 OF CHAR;
			str: ARRAY 16 OF CHAR;
			bytesPerChar, length, counter : LONGINT;
			el:XML.Element;
			buffile: Files.File; bufw: Files.Writer; bufr: Files.Reader;
			bufs: ARRAY 1024 OF CHAR; readlen,len:LONGINT;
			
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

		BEGIN
			Init;
			res := 1;

			out.String('<?xml version="1.0" encoding="UTF-8"?>'); out.Ln;
			out.String('<office:document-content xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0" xmlns:style="urn:oasis:names:tc:opendocument:xmlns:style:1.0" xmlns:text="urn:oasis:names:tc:opendocument:xmlns:text:1.0" xmlns:fo="urn:oasis:names:tc:opendocument:xmlns:xsl-fo-compatible:1.0" xmlns:xlink="http://www.w3.org/1999/xlink" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:meta="urn:oasis:names:tc:opendocument:xmlns:meta:1.0">'); out.Ln;
			
			(*doc.autoStyles.Write(out, NIL, 0);*) (*comes too early here as automatic styles can be defined later=> place at the end possible ?*)
			doc.contentFontFaceDecls.Write(out, NIL,0);
			doc.contentScripts.Write(out,NIL,0);
			out.Ln;
			
			buffile:=Files.New(""); Files.OpenWriter(bufw, buffile,  0); (*hack: everything written to a temp file here, because styles need to be written first, but are only made visible through parsing through the text*)
			bufw.String('<office:body><office:text>'); bufw.Ln;
			text.AcquireRead;
			NEW(r, text);
			r.ReadCh(ch);
			IF (ch = Texts.LabelChar) THEN WriteLabel(bufw, r.object(Texts.LabelPiece).label^) END;
			RetrieveAttributes;
			(* PrintAttributes; *)
			WriteParagraph(bufw,pstylename);
			WriteSpan(bufw, stylename);
			bytesPerChar := 2;
			length := text.GetLength();
			NEW(buf, length * bytesPerChar); (* UTF8 encoded characters use up to 5 bytes *)
			counter := 0; COPY("   ", rbuf);
			WHILE ~r.eot DO

				WHILE ~UTF8Strings.EncodeChar(ch, buf^, counter) DO
					INC(bytesPerChar);
					ASSERT(bytesPerChar <= 5);
					ExpandBuf(buf, bytesPerChar * length);
				END;

				(* CDATA escape fix *)
				rbuf[0] := rbuf[1]; rbuf[1] := rbuf[2]; rbuf[2] := CHR(ch);
				IF (rbuf = "]]>") THEN
					buf[counter] := 0X;
					bufw.String(buf^); bufw.String("]]><![CDATA["); counter := 0;
					buf[counter] := CHR(ch);
				END;

				r.ReadCh(ch);

				IF ch = Texts.ObjectChar THEN
					buf[counter] := 0X; bufw.String(buf^); counter := 0; COPY("   ", rbuf);
					CloseSpan(bufw);
					WriteObject(bufw, r.object);
					RetrieveAttributes;
					IF ~r.eot THEN WriteSpan(bufw, stylename) END
				ELSIF ch = Texts.LabelChar THEN
					buf[counter] := 0X; bufw.String(buf^); counter := 0; COPY("   ", rbuf);
					CloseSpan(bufw);
					WriteLabel(bufw, r.object(Texts.LabelPiece).label^);
					RetrieveAttributes;
					IF ~r.eot THEN WriteSpan(bufw, stylename) END
				ELSIF ch = Texts.TabChar THEN
					buf[counter] := 0X; bufw.String(buf^); counter := 0; COPY("   ", rbuf);
					CloseSpan(bufw);
					WriteTab(bufw);
					WriteSpan(bufw, stylename)
				ELSIF ch = Texts.NewLineChar THEN
					buf[counter] := 0X; bufw.String(buf^); counter := 0; COPY("   ", rbuf);
					CloseSpan(bufw);
					WriteLineBreak(bufw);
					WriteSpan(bufw, stylename)
				ELSIF ch = Texts.SpaceChar THEN
					(*! not yet implemented *)
				ELSE
					pchanged := CompareParagraphs();
					changed := CompareAttributes();
					IF pchanged THEN
						RetrieveAttributes;
						IF ~r.eot THEN
							buf[counter] := 0X; bufw.String(buf^); counter := 0; COPY("   ", rbuf);
							CloseSpan(bufw);
							CloseParagraph(bufw);
							IF (pStyle # NIL) & (pstylename # "Left") THEN WriteParagraph(bufw, pstylename) END;
							WriteSpan(bufw, stylename)
						END
					ELSIF changed THEN
						RetrieveAttributes;
					
						NEW(cStyle); cStyle.name:="AdHoc"; INC(adhocindex); Strings.IntToStr(adhocindex,str); Strings.Append(cStyle.name,str);
						COPY(cStyle.name, stylename);
						COPY(dfFamily,cStyle.family); cStyle.size:=size; cStyle.color:=color; cStyle.bgColor:=bgcolor; cStyle.baselineShift:=voff;
						IF r.font#NIL THEN cStyle.style:=r.font.style END;
						(*PrintAttributes;*)

						IF ~r.eot THEN
							buf[counter] := 0X; bufw.String(buf^); counter := 0; COPY("   ", rbuf);
							CloseSpan(bufw); WriteSpan(bufw, cStyle.name);
							el:=doc.autoStyles.GetIdElement("style:name","stylename");
							IF el=NIL THEN doc.autoStyles.AddContent(doc.AutomaticStyle(cStyle)) END;
						END
					END
				END
			END;

			buf[counter] := 0X;
			bufw.String(buf^);
			CloseSpan(bufw); bufw.Ln;
			CloseParagraph(bufw); bufw.Ln;
			
			bufw.String('</office:text></office:body>'); bufw.Ln;
			bufw.Update;
			
			doc.autoStyles.Write(out, NIL, 0);
			
			Files.OpenReader(bufr, buffile, 0); (* temporary file copy: necessary hack because it appears that OpenDocument automaticStyles need to be before office:body *)
			len:=buffile.Length();
			WHILE len>0 DO
				bufr.Bytes(bufs,0,1024, readlen); out.Bytes(bufs,0,readlen); DEC(len,readlen);
			END;
			
			out.String('</office:document-content>'); out.Ln;
			out.Update;
			text.ReleaseRead;
			res := 0
		END WriteTextInternal;

	END TextEncoder;
	
	TYPE	PresentationEncoder* = OBJECT(Codecs.TextEncoder) (*! create a presentation encoder template in Codecs.Mod *)
	VAR out: Streams.Writer;
		doc: OpenDocument.Document;
	PROCEDURE Open(out : Streams.Writer);
	BEGIN
		IF out = NIL THEN KernelLog.String("OpenDocument Encoder Error: output stream is NIL");
		ELSE SELF.out := out;
		END;
	END Open;
	PROCEDURE WriteText*(text : Texts.Text; VAR res : LONGINT);
		VAR
			contentfile: Files.File;
			w: Files.Writer; 
		BEGIN
			NEW(doc,"presentation"); 
			contentfile:=Files.New("content.xml"); 
			Files.OpenWriter(w,contentfile,0);
		(*here is the action: WriteTextInternal(text, w, res);*)
			doc.AddStandardFiles;
			doc.AddFile(contentfile,"content.xml", OpenDocument.ZipLevel, OpenDocument.ZipStrategy, res); 
			doc.Write(out);
			out.Update;
		END WriteText;
	END PresentationEncoder;


(*
The <draw:page> element contains child elements for each of the objects on the slide. These can be
    <draw:frame> for a title, subtitle, outline, or a placeholder.
    <draw:image> for clip art.
    <draw:object> for embedded charts or spreadsheets.
*)

(*! this does not work yet*)
PROCEDURE DemoPresentation*;
VAR doc: OpenDocument.Document; presentation, contentfile: Files.File; w, out:Files.Writer; res:LONGINT;
BEGIN
	NEW(doc,"presentation");
	contentfile:=Files.New("content.xml");
	Files.OpenWriter(out,contentfile,0);
		out.String('<?xml version="1.0" encoding="UTF-8"?>'); out.Ln;
		out.String('<office:document-content xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0" xmlns:style="urn:oasis:names:tc:opendocument:xmlns:style:1.0" xmlns:text="urn:oasis:names:tc:opendocument:xmlns:text:1.0" xmlns:fo="urn:oasis:names:tc:opendocument:xmlns:xsl-fo-compatible:1.0" xmlns:xlink="http://www.w3.org/1999/xlink" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:meta="urn:oasis:names:tc:opendocument:xmlns:meta:1.0">'); out.Ln;
		(*doc.autoStyles.Write(out, NIL, 0);*) (*comes too early here as automatic styles can be defined later=> place at the end possible ?*)
		doc.contentFontFaceDecls.Write(out, NIL,0);
		doc.contentScripts.Write(out,NIL,0);
		out.Ln;
		
		out.String('<office:automatic-styles>'); out.Ln;
		out.String('<style:style style:name="dp1" style:family="drawing-page">'); out.Ln;		
		out.String('<style:drawing-page-properties presentation:background-visible="true" presentation:background-objects-visible="true" presentation:display-footer="true" presentation:display-page-number="false" presentation:display-date-time="true"/>'); out.Ln;		
		out.String('</style:style>'); out.Ln;		
		out.String('<style:style style:name="dp2" style:family="drawing-page">'); out.Ln;
		out.String('<style:drawing-page-properties presentation:display-header="true" presentation:display-footer="true" presentation:display-page-number="false" presentation:display-date-time="true"/>'); out.Ln;
		out.String('</style:style>'); out.Ln;
		out.String('<style:style style:name="gr1" style:family="graphic">'); out.Ln;
		out.String('<style:graphic-properties style:protect="size"/>'); out.Ln;
		out.String('</style:style>'); out.Ln;
		out.String('<style:style style:name="pr1" style:family="presentation" style:parent-style-name="Standard-title">'); out.Ln;
		out.String('<style:graphic-properties fo:min-height="3.506cm"/>'); out.Ln;
		out.String('</style:style>'); out.Ln;
		out.String('<style:style style:name="pr2" style:family="presentation" style:parent-style-name="Standard-subtitle">'); out.Ln;
		out.String('<style:graphic-properties draw:fill-color="#ffffff" fo:min-height="13.859cm"/>'); out.Ln;
		out.String('</style:style>'); out.Ln;
		out.String('<style:style style:name="pr3" style:family="presentation" style:parent-style-name="Standard-notes">'); out.Ln;
		out.String('<style:graphic-properties draw:fill-color="#ffffff" fo:min-height="13.364cm"/>'); out.Ln;
		out.String('</style:style>'); out.Ln;
		out.String('</office:automatic-styles>'); out.Ln;

		out.String('<office:body>'); out.Ln;
		out.String('<office:presentation>'); out.Ln;
		out.String('<draw:page draw:name="page1" draw:style-name="dp1" draw:master-page-name="Standard" presentation:presentation-page-layout-name="AL1T0">'); out.Ln;
			out.String('<draw:frame presentation:style-name="pr1" draw:layer="layout" svg:width="25.199cm" svg:height="3.506cm" svg:x="1.4cm" svg:y="0.837cm" presentation:class="title">'); out.Ln;
				out.String('<draw:text-box>'); out.Ln;
					out.String('<text:p>Dies ist der Titel</text:p>'); out.Ln;
				out.String('</draw:text-box>'); out.Ln;
			out.String('</draw:frame>'); out.Ln;
			out.String('<draw:frame presentation:style-name="pr2" draw:layer="layout" svg:width="25.199cm" svg:height="13.859cm" svg:x="1.4cm" svg:y="4.914cm" presentation:class="subtitle">'); out.Ln;
				out.String('<draw:text-box>'); out.Ln;
					out.String('<text:p>Dies ist der Slide Text</text:p>'); out.Ln;
				out.String('</draw:text-box>'); out.Ln;
			out.String('</draw:frame>'); out.Ln;
		out.String('<presentation:notes draw:style-name="dp2">'); out.Ln;
			out.String('<draw:page-thumbnail draw:style-name="gr1" draw:layer="layout" svg:width="14.848cm" svg:height="11.136cm" svg:x="3.075cm" svg:y="2.257cm" draw:page-number="1" presentation:class="page"/>'); out.Ln;
			out.String('<draw:frame presentation:style-name="pr3" draw:layer="layout" svg:width="16.799cm" svg:height="13.364cm" svg:x="2.1cm" svg:y="14.107cm" presentation:class="notes" presentation:placeholder="true">'); out.Ln;
				out.String('<draw:text-box/>'); out.Ln;
			out.String('</draw:frame>'); out.Ln;
		out.String('</presentation:notes>'); out.Ln;
		out.String('</draw:page>'); out.Ln;
		out.String('<presentation:settings presentation:mouse-visible="false"/>'); out.Ln;


		out.String('</office:presentation></office:body>'); out.Ln;
		out.String('</office:document-content>'); out.Ln;
		out.Update;
	doc.AddStandardFiles;
	doc.AddFile(contentfile,"content.xml", OpenDocument.ZipLevel, OpenDocument.ZipStrategy, res); 
	doc.Write(out);
	out.Update;
	
	presentation:=Files.New("presentation.odp");
	Files.OpenWriter(w,presentation,0);
	doc.Write(w);
	Files.Register(presentation);
END DemoPresentation;



(* OpenDocument File Format *)

PROCEDURE TextDecoderFactory*() : Codecs.TextDecoder;
VAR p : TextDecoder;
BEGIN
	NEW(p);
	RETURN p
END TextDecoderFactory;


PROCEDURE TextEncoderFactory*() : Codecs.TextEncoder;
VAR p : TextEncoder;
BEGIN
	NEW(p);
	RETURN p
END TextEncoderFactory;

(* to be called by TextUtilities.Load and TextUtilities.Store via Codec mechanism *)
(** Import a OpenDocument Text *)
PROCEDURE LoadText*(text : Texts.Text; CONST filename : ARRAY OF CHAR; VAR res : LONGINT);
BEGIN
	TextUtilities.Load(text, filename, "OpenDocument", res)
END LoadText;

(** Export text in OpenDocument format *)
PROCEDURE StoreText*(text : Texts.Text; CONST fileName : ARRAY OF CHAR; VAR res : LONGINT);
VAR doc: OpenDocument.Document;
BEGIN
	TextUtilities.Store(text, fileName, "OpenDocument", res)
END StoreText;


END OpenDocumentCodecs.

SystemTools.FreeDownTo OpenDocumentCodecs ~

OpenDocumentCodecs.DemoPresentation ~

(* content.xml example for a text file *)
<?xml version="1.0" encoding="UTF-8"?>

<office:document-content 
	xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0" 
	xmlns:style="urn:oasis:names:tc:opendocument:xmlns:style:1.0" 
	xmlns:text="urn:oasis:names:tc:opendocument:xmlns:text:1.0" 
	xmlns:table="urn:oasis:names:tc:opendocument:xmlns:table:1.0" 
	xmlns:draw="urn:oasis:names:tc:opendocument:xmlns:drawing:1.0" 
	xmlns:fo="urn:oasis:names:tc:opendocument:xmlns:xsl-fo-compatible:1.0" 
	xmlns:xlink="http://www.w3.org/1999/xlink" xmlns:dc="http://purl.org/dc/elements/1.1/" 
	xmlns:meta="urn:oasis:names:tc:opendocument:xmlns:meta:1.0" 
	xmlns:number="urn:oasis:names:tc:opendocument:xmlns:datastyle:1.0" 
	xmlns:svg="urn:oasis:names:tc:opendocument:xmlns:svg-compatible:1.0" 
	xmlns:chart="urn:oasis:names:tc:opendocument:xmlns:chart:1.0" 
	xmlns:dr3d="urn:oasis:names:tc:opendocument:xmlns:dr3d:1.0" 
	xmlns:math="http://www.w3.org/1998/Math/MathML" 
	xmlns:form="urn:oasis:names:tc:opendocument:xmlns:form:1.0" 
	xmlns:script="urn:oasis:names:tc:opendocument:xmlns:script:1.0" 
	xmlns:ooo="http://openoffice.org/2004/office" 
	xmlns:ooow="http://openoffice.org/2004/writer" 
	xmlns:oooc="http://openoffice.org/2004/calc"
	xmlns:dom="http://www.w3.org/2001/xml-events" 
	xmlns:xforms="http://www.w3.org/2002/xforms" 
	xmlns:xsd="http://www.w3.org/2001/XMLSchema" 
	xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" 
	xmlns:rpt="http://openoffice.org/2005/report" 
	xmlns:of="urn:oasis:names:tc:opendocument:xmlns:of:1.2" 
	xmlns:xhtml="http://www.w3.org/1999/xhtml" 
	xmlns:grddl="http://www.w3.org/2003/g/data-view#" 
	xmlns:tableooo="http://openoffice.org/2009/table" 
	xmlns:field="urn:openoffice:names:experimental:ooo-ms-interop:xmlns:field:1.0" 
	office:version="1.2" 
	grddl:transformation="http://docs.oasis-open.org/office/1.2/xslt/odf2rdf.xsl">

	<office:scripts/>
	
	<office:font-face-decls>
		<style:font-face style:name="Mangal1" svg:font-family="Mangal"/>
		<style:font-face style:name="Times New Roman" svg:font-family="&apos;Times New Roman&apos;" style:font-family-generic="roman" style:font-pitch="variable"/>
		<style:font-face style:name="Arial" svg:font-family="Arial" style:font-family-generic="swiss" style:font-pitch="variable"/>
		<style:font-face style:name="Mangal" svg:font-family="Mangal" style:font-family-generic="system" style:font-pitch="variable"/>
		<style:font-face style:name="SimSun" svg:font-family="SimSun" style:font-family-generic="system" style:font-pitch="variable"/>
	</office:font-face-decls>
	
	<office:automatic-styles>
		<style:style style:name="T1" style:family="text"><style:text-properties fo:font-weight="bold" style:font-weight-asian="bold" style:font-weight-complex="bold"/></style:style>
		<style:style style:name="T2" style:family="text"><style:text-properties fo:font-style="italic" style:font-style-asian="italic" style:font-style-complex="italic"/></style:style>
		<style:style style:name="T3" style:family="text"><style:text-properties fo:font-style="italic" fo:font-weight="bold" style:font-style-asian="italic" style:font-weight-asian="bold" style:font-style-complex="italic" style:font-weight-complex="bold"/></style:style>
	</office:automatic-styles>
	
	<office:body>
		<office:text>
			<text:sequence-decls>
				<text:sequence-decl text:display-outline-level="0" text:name="Illustration"/>
				<text:sequence-decl text:display-outline-level="0" text:name="Table"/>
				<text:sequence-decl text:display-outline-level="0" text:name="Text"/>
				<text:sequence-decl text:display-outline-level="0" text:name="Drawing"/>
			</text:sequence-decls>
	
			<text:p text:style-name="Standard">Dies <text:span text:style-name="T1">ist eine </text:span>Zeile.</text:p>
			<text:p text:style-name="Standard">Dies <text:span text:style-name="T3">ist eine zweite</text:span> ZeileDies <text:span text:style-name="T1">ist </text:span><text:span text:style-name="T3">eine </text:span><text:span text:style-name="T2">dritte </text:span>Zeile</text:p>
		</office:text>
	</office:body'); out.Ln;
		out.String('/office:document-content>


(* content.xml example for a presentation file, see discussion  in http://www.xml.com/pub/a/2004/02/04/tr-xml.html *)
the file format ending is ".sxi" 
inside the 
<office:document-content>
	<office:body> element:

<draw:page draw:name="page1" draw:style-name="dp1" 
           draw:id="1" draw:master-page-name="Default" 
           presentation:presentation-page-layout-name="AL1T0">
  <draw:text-box presentation:style-name="pr1" 
        draw:text-style-name="P1" draw:layer="layout" 
        svg:width="23.912cm" svg:height="3.508cm" 
        svg:x="2.058cm" svg:y="1.743cm" 
        presentation:class="title">
    <text:p text:style-name="P1">Title of slide 1
    </text:p>
  </draw:text-box>
  <draw:text-box presentation:style-name="pr2" 
        draw:text-style-name="P1" draw:layer="layout" 
        svg:width="23.912cm" svg:height="13.231cm" 
        svg:x="2.058cm" svg:y="5.838cm" 
        presentation:class="subtitle">
    <text:p text:style-name="P1">Text of slide 1
    </text:p>
  </draw:text-box>
  <presentation:notes>
    <draw:page-thumbnail draw:style-name="gr1" 
          draw:layer="layout" svg:width="12.768cm" 
          svg:height="9.576cm" svg:x="4.411cm" 
          svg:y="2.794cm" draw:page-number="1" 
          presentation:class="page"/>
    <draw:text-box presentation:style-name="pr3" 
          draw:text-style-name="P2" draw:layer="layout" 
          svg:width="15.021cm" svg:height="10.63cm" 
          svg:x="3.292cm" svg:y="13.299cm" 
          presentation:class="notes">
      <text:p text:style-name="P2">First par of notes for slide 1. 
      </text:p>
      <text:p text:style-name="P2"/>
      <text:p text:style-name="P2">Second par of notes. 
      <text:span text:style-name="T1">Bolded
      </text:span>
      <text:span text:style-name="T2"> text right there. 
      </text:span>
      </text:p>
      <text:p text:style-name="P2">
        <text:span text:style-name="T2"/>
      </text:p>
      <text:p text:style-name="P2">
        <text:span text:style-name="T2">End of first test.
        </text:span>
      </text:p>
    </draw:text-box>
  </presentation:notes'); out.Ln;
		out.String('/draw:page>
