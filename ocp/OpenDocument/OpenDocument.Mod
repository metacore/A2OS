MODULE OpenDocument; (** AUTHOR "Patrick Hunziker"; PURPOSE "OpenDocument Standard 1.0 Implementation"; *)
(** writes, and in the future reads documents in the OpenDocument stardard format, see
	http://www.wikipedia.org/wiki/OpenDocument
	http://docs.oasis-open.org/office/v1.1/OS/OpenDocument-v1.1-html/OpenDocument-v1.1.html
	http://mashupguide.net/1.0/html/ch17s03.xhtml  (OpenDocument format programming)

	detailed tutorial: http://books.evc-cit.info/oobook/ch03.html
	linked frames: http://www.tutorialsforopenoffice.org/tutorial/Frames.html 
	
*)

(*OpenDocument documents may have two different forms:
a) rarely, everything is packed into a single XML root document <office:document>
b) usually, subparts are packed into a zip archive ( with the ending .odt for text) with the following XML root documents with specific possible contents {} (not all mandatory)
	<office:document-content> {script, font decls, auto style, body}
	<office:document-styles> {font decls, style, auto style, mast style}
	<office:document-meta> {meta}
	<office:document-settings> {appl settings}
	and complemented by a 'mimetype' file and a directory file 'META-INF/manifest.xml' and folders for images, thumbnails etc
*)

(*
Implementation Limitations: 
- this is a basically working alpha version that produces formatted text documents that can be read by OpenOffice Writer
- Currently, only a simple formatted text writer is implemented, no reading yet
- not all compression algorithms from OpenDocument  Standard are supported
*)

(* Digital Signatures
http://docs.oasis-open.org/office/v1.2/cs01/OpenDocument-v1.2-cs01-part3.odt
An OpenDocument document that is stored in a package may have one or more digital signatures applied to the package.
Document signatures shall be stored in a file called META-INF/documentsignatures.xml in the package as described in section 3.5 of the OpenDocument specification part 3. 
Document signatures shall contain a <ds:Reference> element for each file within the package, 
with the exception that <ds:Reference> elements for the META-INF/documentsignatures.xml file containing the signature, 
and any files contained in the package whose relative path starts with "external-data/" should be omitted.

digital signatures: http://docs.oasis-open.org/office/v1.2/cs01/OpenDocument-v1.2-cs01-dsig-schema.rng

see also general implementation hints for xml digital signatures: http://msdn.microsoft.com/en-us/library/ms229749%28v=vs.80%29
*)
(*
metadata: http://docs.oasis-open.org/office/v1.2/cs01/OpenDocument-v1.2-cs01-metadata.owl
*)

IMPORT Zip, XML, XMLSignatures, Streams, Files, Strings, Texts, KernelLog;

CONST Generator*="A2 OpenDocument Generator 0.3";
	OpenDocumentVersion*="1.0";
	DefaultEncoding*="UTF-8";
	(* see http://de.wikipedia.org/wiki/Liste_von_Dateinamenserweiterungen/O ; more options exist there *)
	SuffixText*="odt"; 			MimeTypeText*="application/vnd.oasis.opendocument.text";
	SuffixSpreadsheet*="ods"; 	MimeTypeSpreadsheed*="application/vnd.oasis.opendocument.spreadsheet";
	SuffixPresentation*="odp"; 	MimeTypePresentation*="application/vnd.oasis.opendocument.presentation";
	SuffixDatabase*="odb"; 		MimeTypeDatabase*="application/vnd.oasis.opendocument.database";
	SuffixGraphics*="odg"; 		MimeTypeGraphics*="application/vnd.oasis.opendocument.graphics";
	
	ZipLevel* = Zip.BestCompression;
	ZipStrategy* = Zip.DefaultStrategy;

TYPE Collection=RECORD END;

(*
4.1 Paragraphs and headings are the basic building blocks of a text

4.1.1 Headings
Headings define the chapter structure for a document. A chapter or subchapter begins with a heading and extends to the next heading at the same or higher level.
*)
TYPE Heading=OBJECT
END Heading;

(*
4.1.2 Paragraphs
Paragraphs are a basic unit of text, having a common paragraph formatting style.
e.g. <text:p text:style-name="Standard"> some text </text:p>
*)
TYPE Paragraph=OBJECT (* deprecated - use text Structure of Texts.Mod *)
	VAR 
		next:Paragraph;
		stylename: ARRAY 64 OF CHAR;
		b:Piece;
		 rider:Rider;	 
	PROCEDURE &Init*(CONST style: ARRAY OF CHAR);
	
	BEGIN
		COPY(style,stylename);
		 NEW(rider,b,0);
	END Init;
	
	PROCEDURE Write(ch:CHAR);
	BEGIN
		rider.Write(ch);
	END Write;
	
END Paragraph;

(* a span is an externalized subunit of a text  with a common charater format.
e.g. <text:span text:style-name="T1"> some text </text:span> *)
TYPE Span=OBJECT 
END Span;

(* frames can be linked to contain text floating throught them: http://www.tutorialsforopenoffice.org/tutorial/Frames.html *)
TYPE Frame= OBJECT
	END Frame;
	
TYPE Section= OBJECT
	END Section;
	
TYPE Page= OBJECT
	END Page;
	



(*
4.2 Page Sequences
A page sequence element <text:page-sequence> specifies a sequence of master pages that are instantiated in exactly the same order as they are referenced in the page sequence. 
If a text document contains a page sequence, it will consist of exactly as many pages as specified. 
Documents with page sequences do not have a main text flow consisting of headings and paragraphs as is the case for documents that do not contain a page sequence. 
Text content is included within text boxes for documents with page sequences.
*)
TYPE PageSequence=OBJECT
END PageSequence;

(*
4.3 Lists
The OpenDocument format supports list structures, similar to those found in [HTML4]. 
A list is a paragraph-level element, which contains an optional list header, followed by a sequence of list items. 
The list header and each list item contains a sequence of paragraph or list elements. Lists can be nested and numbered.
*)
TYPE List=OBJECT
END List;

(*
4.4 Text Sections
A text section is a named region of paragraph-level text content. 
Sections start and end on paragraph boundaries and can contain any number of paragraphs.
Sections have two uses in the OpenDocument format: 
	They can be used to assign certain formatting properties to a region of text. 
	They can also be used to group text that is automatically acquired from some external data source.
*)
TYPE TextSection=OBJECT 
END TextSection;

(* a piece is 0X terminated string serving as the (internal) basic unit/buffer of a text . 
It contains a number of characters, sharing the same format *)

Piece=POINTER TO RECORD
	s: ARRAY 1025 OF CHAR; (*including a 0X*)
	next: Piece
END;


TYPE Rider= OBJECT
		VAR
			pos,valid,length: LONGINT;
			buf: Piece;
		PROCEDURE &Init(VAR b:Piece; loc:LONGINT);
		BEGIN
			buf:=b; pos:=loc; length:=LEN(buf.s)-1;
			IF buf=NIL THEN NEW(b); buf:=b; valid:=0; pos:=0 END;
		END Init;
				
		PROCEDURE Write(ch: CHAR);
		VAR b: Piece;
		BEGIN
			IF pos>=length THEN NEW(b); b.next:=buf.next; buf.next:=b; buf:=b; pos:=0; valid:=0; buf.s[0]:=0X END;
			buf.s[pos]:=ch; 
			IF pos>valid THEN buf.s[pos+1]:=0X; INC(valid) END;
			INC(pos);
		END Write;
	END Rider;

TYPE Text= OBJECT
	END Text;

TYPE ContentWriter=PROCEDURE{DELEGATE}(w:Streams.Writer);

TYPE Document*=OBJECT 
		VAR 
			metainf: Collection; (*folder contains manifest.xml etc*)
			thumbs: Collection; (*folder for png thumbnails*)
			pics: Collection; (*folder for png pictures*)
			mimetype: ARRAY 128 OF CHAR;
			manifest,
			(*root elements of OpenDocument XML structure*)
			content,
			styles,
			meta,
			settings,
			signatures: XML.Document;
			
			xmlDecl:XML.XMLDecl;
			contentRoot*, autoStyles*, contentBody*, contentBodyText*,contentFontFaceDecls*, contentScripts*: XML.Element;
			(*
			WriteContent*: ContentWriter; (*if content is written to a writer*)
			*)
			zip: Zip.Archive; 
				(*a text document is either a series of paragraphs (representing lines)	or a series of pages containing*)
			paragraphs: Paragraph;
			res:LONGINT;

		PROCEDURE &Init*(CONST type: ARRAY OF CHAR);
		VAR bold, italic, red, fatitalic, text, arial, fontface: XML.Element;
		BEGIN
			(*WriteContent:=writeContent;*) (* for demo; write 'content.xml' file directly and add it using AddFile() for productive use *)
			NEW(xmlDecl); xmlDecl.SetVersion(OpenDocumentVersion); xmlDecl.SetEncoding(DefaultEncoding);
			
			NEW(contentRoot); contentRoot.SetName("office:document-content");
				contentRoot.SetAttributeValue("xmlns:office","urn:oasis:names:tc:opendocument:xmlns:office:1.0");
				contentRoot.SetAttributeValue("xmlns:style","urn:oasis:names:tc:opendocument:xmlns:style:1.0");
				contentRoot.SetAttributeValue("xmlns:text","urn:oasis:names:tc:opendocument:xmlns:text:1.0");
				contentRoot.SetAttributeValue("xmlns:fo","urn:oasis:names:tc:opendocument:xmlns:xsl-fo-compatible:1.0"); 
				contentRoot.SetAttributeValue("xmlns:svg","urn:oasis:names:tc:opendocument:xmlns:svg-compatible:1.0");

			NEW(autoStyles); autoStyles.SetName("office:automatic-styles"); 
				NEW(fatitalic); fatitalic.SetName("style:style");
				fatitalic.SetAttributeValue("style:name","P1");
				fatitalic.SetAttributeValue("style:family","paragraph");
				fatitalic.SetAttributeValue("style:parent-style-name","Standard");
					NEW(text); text.SetName("style:text-properties");
					text.SetAttributeValue("fo:font-style","italic");
					text.SetAttributeValue("fo:font-weight","bold");
					fatitalic.AddContent(text);
				autoStyles.AddContent(fatitalic);
				
				NEW(bold); bold.SetName("style:style");
				bold.SetAttributeValue("style:name","Bold");
				bold.SetAttributeValue("style:family","text");
					NEW(text); text.SetName("style:text-properties"); text.SetAttributeValue("fo:font-weight","bold");
						(*The fo:font-weight attribute is usable with the following element: <style:text-properties> 16.27.28.
						The values of the fo:font-weight attribute are normal, bold, 100, 200, 300, 400, 500, 600, 700, 800 or 900. *)
					bold.AddContent(text);
				autoStyles.AddContent(bold);
				
				NEW(italic); italic.SetName("style:style");
				italic.SetAttributeValue("style:name","Italic");
				italic.SetAttributeValue("style:family","text");
					NEW(text); text.SetName("style:text-properties"); text.SetAttributeValue("fo:font-style","italic");
					italic.AddContent(text);
				autoStyles.AddContent(italic);
				
				NEW(red); red.SetName("style:style");
				red.SetAttributeValue("style:name","Red");
				red.SetAttributeValue("style:family","text");
					NEW(text); text.SetName("style:text-properties"); text.SetAttributeValue("fo:color","#ff0000");
					red.AddContent(text);
				autoStyles.AddContent(red);
				
				NEW(arial); arial.SetName("style:style");
				arial.SetAttributeValue("style:name","Arial");
				arial.SetAttributeValue("style:family","text");
					NEW(text); text.SetName("style:text-properties"); text.SetAttributeValue("style:font-name","Arial");
					arial.AddContent(text);
				autoStyles.AddContent(arial);
			contentRoot.AddContent(autoStyles);
			
			NEW(contentBody); contentBody.SetName("office:body");
				IF type="text" THEN 
					NEW(contentBodyText); contentBodyText.SetName("office:text");
					contentBody.AddContent(contentBodyText); 
				ELSIF type="presentation" THEN 
				ELSE HALT(201)  (*! other types here*)
				END;
				
			contentRoot.AddContent(contentBody);

			NEW(contentFontFaceDecls); contentFontFaceDecls.SetName("office:font-face-decls");
				NEW(fontface); fontface.SetName("style:font-face"); 
					fontface.SetAttributeValue("style:name", "Times New Roman");
					fontface.SetAttributeValue("svg:font-family","&apos;Times New Roman&apos;");
					fontface.SetAttributeValue("style:font-family-generic","roman");
					fontface.SetAttributeValue("style:font-pitch","variable");
				contentFontFaceDecls.AddContent(fontface);
				NEW(fontface); fontface.SetName("style:font-face"); 
					fontface.SetAttributeValue("style:name", "Arial");
					fontface.SetAttributeValue("svg:font-family","Arial");
					fontface.SetAttributeValue("style:font-family-generic","swiss");
					fontface.SetAttributeValue("style:font-pitch","variable");
				contentFontFaceDecls.AddContent(fontface);
			contentRoot.AddContent(contentFontFaceDecls);
			
			NEW(contentScripts); contentScripts.SetName("office:scripts");
			contentRoot.AddContent(contentScripts);
			
			NEW(paragraphs,"Standard");
			IF type="text" THEN COPY(MimeTypeText, mimetype);
			ELSIF type="presentation" THEN COPY(MimeTypePresentation, mimetype); 
			ELSE HALT(201);(*other file  types*)
			END;
			content:=Content(paragraphs); (* example only; will be overwritten in actual application *)
			styles:=Styles();
			meta:=Meta();
			settings:=Settings();
			manifest:=Manifest(type);
			
			zip:=Zip.CreateArchive("",res);
		END Init;
		
	PROCEDURE AutomaticStyle*(cstyle: Texts.CharacterStyle): XML.Element;
		VAR style, charstyle: XML.Element; str, str1: ARRAY 16 OF CHAR;
		BEGIN
			NEW(style); style.SetName("style:style"); 
			IF cstyle.name#""  THEN style.SetAttributeValue("style:name", cstyle.name); ELSE style.SetAttributeValue("style:name", "XXX");   END;
			style.SetAttributeValue("style:family", "text"); 
			NEW(charstyle); charstyle.SetName("style:text-properties");
			IF cstyle.family#"" THEN charstyle.SetAttributeValue("svg:font-family",cstyle.family); END;
			(*charstyle.SetAttributeValue("style:font-family-generic","roman");*)
			(*OpenDocument color format is '#rrggbb' *)
			Strings.IntToHexStr(cstyle.color,0, str);  str1:="#"; Strings.Append(str1,str); str1[7]:=0X; charstyle.SetAttributeValue("fo:color", str1);
			(*Strings.IntToHexStr(cstyle.bgColor,0, str);  str1:="#"; Strings.Append(str1,str); str1[7]:=0X; charstyle.SetAttributeValue("fo:background-color", str1); *) (*!  Does not yet work because A2 knows 32 bit incl transparency 000000FF, while for OpenDocument , the first 6 Bytes are interpreted as black*)
			(*charstyle.SetAttributeValue("style:font-pitch","variable");*)
			IF 1 IN cstyle.style THEN charstyle.SetAttributeValue("fo:font-style","italic") END;
			IF 0 IN cstyle.style THEN charstyle.SetAttributeValue("fo:font-weight","bold")END;
			Strings.IntToStr(cstyle.size, str); charstyle.SetAttributeValue("fo:font-size", str);
			style.AddContent(charstyle);
			RETURN style
		END AutomaticStyle;
		
		(*
		PROCEDURE writeContent(w:Streams.Writer); (* fallback content writer*)
		BEGIN
			content.Write(w,NIL,0); 
			w.Update;
		END writeContent;	
		*)	
		
		(*
		PROCEDURE AddContent;
		VAR f:Files.File; w:Files.Writer; res:LONGINT;
		BEGIN
			IF WriteContent#NIL THEN
				f:=Files.New("content.xml"); IF f#NIL THEN Files.OpenWriter(w,f,0); WriteContent(w); AddFile(f,"content.xml",0,0,res); END;
			END;
		END AddContent;
		*)
		
		PROCEDURE AddStandardFiles*;
		VAR res:LONGINT; f:Files.File; w:Files.Writer;
		BEGIN
			f:=Files.New("mimetype"); IF f#NIL THEN Files.OpenWriter(w,f,0); w.String(mimetype); w.Update; AddFile(f,"mimetype",ZipLevel,ZipStrategy,res) END;	
			f:=Files.New("styles.xml"); IF f#NIL THEN Files.OpenWriter(w,f,0); styles.Write(w,NIL,0); w.Update; AddFile(f,"styles.xml",ZipLevel,ZipStrategy,res) END;
			f:=Files.New("meta.xml"); IF f#NIL THEN Files.OpenWriter(w,f,0); meta.Write(w,NIL,0); w.Update; AddFile(f,"meta.xml",ZipLevel,ZipStrategy,res) END;
			f:=Files.New("settings.xml"); IF f#NIL THEN Files.OpenWriter(w,f,0); settings.Write(w,NIL,0); w.Update; AddFile(f,"settings.xml",ZipLevel,ZipStrategy,res) END;
			f:=Files.New("manifest.xml"); IF f#NIL THEN Files.OpenWriter(w,f,0); manifest.Write(w,NIL,0); w.Update; AddFile(f,"META-INF/manifest.xml",ZipLevel,ZipStrategy,res) END;			
		END AddStandardFiles;
		
		PROCEDURE AddSignatureFile*;
		VAR res:LONGINT; f:Files.File; w:Files.Writer;
		BEGIN
			f:=Files.New("documentsignatures.xml"); 
			signatures:=Signatures();
			IF f#NIL THEN Files.OpenWriter(w,f,0); signatures.Write(w,NIL,0); w.Update; AddFile(f,"META-INF/documentsignatures.xml",ZipLevel,ZipStrategy,res) END;	
		END AddSignatureFile;
		
			(* writing first to file, then to ZIP archive; zip is Rider based, not writer/reader based*)
	PROCEDURE AddFile*(f: Files.File; CONST dstname: ARRAY OF CHAR; level, strategy: LONGINT; VAR res: LONGINT);
		VAR r: Files.Rider;
		BEGIN
			IF f = NIL THEN res := Zip.BadName
			ELSE
				f.Set(r, 0);
				Zip.AddEntry(zip, dstname, r, f.Length(), SHORT(SHORT(level)), SHORT(SHORT(strategy)), res);
			END;
		END AddFile;
		
		PROCEDURE Read(r:Streams.Reader);
		END Read;
		
		PROCEDURE Write*(out: Streams.Writer);
		VAR rd: Files.Reader; res, len, readlen: LONGINT;
			buf: ARRAY 1024 OF CHAR;
		BEGIN
			Files.OpenReader(rd, zip.file,0);
			len:=zip.file.Length();
			WHILE len>0 DO
				rd.Bytes(buf, 0, MIN(len,1024), readlen); out.Bytes(buf, 0, readlen); DEC(len, readlen);
			END;
			out.Update;
		END Write;
		
		(* (*simple solution, but does not comply to the Streams.Writer paradigm which is necessary for Codecs *)
		PROCEDURE Store*(CONST name: ARRAY OF CHAR);
		VAR res:LONGINT; f:Files.File; w:Files.Writer;
		BEGIN
			zip := Zip.CreateArchive(name, res);
			AddStandardFiles;
			AddContent;
		END Store;
		*)
		
		PROCEDURE Update;
		BEGIN
			content:=Content(paragraphs);
		END Update;
		
		
		PROCEDURE Log;
		BEGIN
			log.String(mimetype); log.Ln;
			content.Write(log,NIL,0); log.Ln;
			styles.Write(log,NIL,0); log.Ln;
			meta.Write(log,NIL,0); log.Ln;
			settings.Write(log,NIL,0); log.Ln; 
			manifest.Write(log,NIL,0); log.Ln;
		END Log;
		
	END Document;
	(*
	TYPE XMLDoc= OBJECT (XML.Container)
		VAR 
			mimetype: ARRAY 128 OF CHAR;
			
			xmldocument: XML.Element; (*topmost level*)
			zipdocument: RECORD END;
			
			(*first level items*)
			manifest,
			document_meta,
			document_settings,
			document_styles,
			document_content: XML.Document;
			
			<office:document-content> {script, font decls, auto style, body}
			<office:document-styles> {font decls, style, auto style, mast style}
			<office:document-meta> {meta}
			<office:document-settings> {appl settings}
			
			(*second level items*)
			document_attrs,
			document_common_attrs,
			
			meta, 
			settings,
			scripts,
			font_face_decls,
			styles,
			automatic_styles,
			master_styles,
			master_styles,
			body: XML.Element;
			
			(*
			"office:document-attrs"/>
			"office:document-common-attrs"/>
			"office:meta"
			"office:settings"
			"office:scripts"
			"office:font-face-decls"
			"office:styles"
			"office:automatic-styles"
			"office:master-styles"
			"office:body"			
			*)
		
		PROCEDURE &Init*; (* xml elements for flat version*)
		BEGIN
			NEW(document); 
				document_content.AddContent(xmlDecl);
				NEW(root); root.SetName("office:document"); 
				(*add here the office:document attributes ... *)
				root.SetAttributeValue();
				NEW(meta); meta.SetName("office:meta"); root.AddContent(meta);
				NEW(settings); settings.SetName("office:settings"); root.AddContent(settings);
				NEW(scripts); scripts.SetName("office:scripts"); root.AddContent(scripts);
				NEW(font_face_decls); font_face_decls.SetName("office:font-face-decls"); root.AddContent(font_face_decls);
				NEW(styles); styles.SetName("office:styles"); document.AddContent(styles);
				NEW(automatic_styles); automatic_styles.SetName("office:automatic-styles"); root.AddContent(automatic_styles);
				NEW(master_styles); master_styles.SetName("office:master-styles"); root.AddContent(master_styles);
				NEW(body); body.SetName("office:body"); root.AddContent(body);
			document.SetContent(root);
		END Init;
		
		PROCEDURE Init2*; (* xml documents for zip version *)
		VAR root: XML.Element;
		BEGIN
			COPY(TextMimeTypeText, mimetype);
			NEW(xmlDecl); xmlDecl.SetVersion(OpenDocumentVersion); xmlDecl.SetEncoding(DefaultEncoding); doc.AddContent(xmlDecl); XXXXX
			NEW(document_content); 
				document_content.AddContent(xmlDecl);
				NEW(root); root.SetName("office:document-content"); 
				root.SetAttributeValue("xmlns:office","urn:oasis:names:tc:opendocument:xmlns:office:1.0");
				root.SetAttributeValue("xmlns:style","urn:oasis:names:tc:opendocument:xmlns:style:1.0");
				root.SetAttributeValue("xmlns:text","urn:oasis:names:tc:opendocument:xmlns:text:1.0");
				root.SetAttributeValue("xmlns:fo","urn:oasis:names:tc:opendocument:xmlns:xsl-fo-compatible:1.0"); 
				root.SetAttributeValue("xmlns:svg","urn:oasis:names:tc:opendocument:xmlns:svg-compatible:1.0");
				root.AddContent(font_face_decls); 
				root.AddContent(scripts); 
				root.AddContent(automatic_styles); 
				root.AddContent(content - do later);
			document_content.AddContent(root);
			
			NEW(document_styles); 
				document_styles.AddContent(xmlDecl);
				NEW(root); root.SetName("office:document-style"); 
				root.SetAttributeValue("xmlns:office","urn:oasis:names:tc:opendocument:xmlns:office:1.0");
				root.SetAttributeValue("xmlns:style","urn:oasis:names:tc:opendocument:xmlns:style:1.0");
				root.SetAttributeValue("xmlns:text","urn:oasis:names:tc:opendocument:xmlns:text:1.0");
				root.SetAttributeValue("xmlns:fo","urn:oasis:names:tc:opendocument:xmlns:xsl-fo-compatible:1.0"); 
				root.SetAttributeValue("xmlns:svg","urn:oasis:names:tc:opendocument:xmlns:svg-compatible:1.0");
				root.AddContent(styles); 
				root.AddContent(master_styles);  
			document_styles.AddContent(root);
			
			NEW(document_meta); 
				document_meta.AddContent(xmlDecl);
				NEW(root); root.SetName("office:document-meta"); 
				root.SetAttributeValue("xmlns:office","urn:oasis:names:tc:opendocument:xmlns:office:1.0");
				root.SetAttributeValue("xmlns:meta","urn:oasis:names:tc:opendocument:xmlns:meta:1.0");
				root.SetAttributeValue("xmlns:dc","http://purl.org/dc/elements/1.1/");
				root.SetAttributeValue("xmlns:xlink","http://www.w3.org/1999/xlink");
				root.AddContent(meta);
			document_meta.AddContent(root);
			
			NEW(document_settings); 
				document_settings.AddContent(xmlDecl);
				NEW(root); root.SetName("office:document-settings"); 
				root.SetAttributeValue("xmlns","XXX");
				root.AddContent(settings);
			document_settings.AddContent(root);
			
			NEW(document_manifest); 
				document_manifest.AddContent(xmlDecl);
				NEW(root); root.SetName("manifest"); 
				root.SetAttributeValue("xmlns","urn:oasis:names:tc:opendocument:xmlns:manifest:1.0");
				NEW(file); file.SetName("file-entry"); root.AddContent(file);
					file.SetAttributeValue("media-type","application/vnd.oasis.opendocument.text"); file.SetAttributeValue("full-path","/");
				NEW(file); file.SetName("file-entry"); root.AddContent(file);
					file.SetAttributeValue("media-type","text/xml"); file.SetAttributeValue("full-path","content.xml");
				NEW(file); file.SetName("file-entry"); root.AddContent(file);
					file.SetAttributeValue("media-type","text/xml"); file.SetAttributeValue("full-path","meta.xml");
				NEW(file); file.SetName("file-entry"); root.AddContent(file);
					file.SetAttributeValue("media-type","text/xml"); file.SetAttributeValue("full-path","content.xml");
				NEW(file); file.SetName("file-entry"); root.AddContent(file);
					file.SetAttributeValue("media-type","text/xml"); file.SetAttributeValue("full-path","settings.xml");	
			document_manifest.AddContent(root);
		END Init;
			
		END XMLDoc;
		
		TYPE DocWriter= OBJECT (Streams.Writer)
			VAR xmldoc: XMLDoc;
			PROCEDURE Update;
			BEGIN
			END Update;
		END DocWriter;
		*)
	

	VAR log: Streams.Writer;

	
	(* may contain:
	"office-document-common-attrs"
	"office-meta"
	*)
	PROCEDURE Meta(): XML.Document;
		VAR doc: XML.Document; root: XML.Element; meta: XML.Element; xmlDecl: XML.XMLDecl;
		BEGIN
			NEW(doc); 
			(*! do we need an xml declaration here ? *)
			NEW(root); root.SetName("office:document-meta");
			root.SetAttributeValue("xmlns:office","urn:oasis:names:tc:opendocument:xmlns:office:1.0");
			root.SetAttributeValue("xmlns:meta","urn:oasis:names:tc:opendocument:xmlns:meta:1.0");
			root.SetAttributeValue("xmlns:dc","http://purl.org/dc/elements/1.1/");
			root.SetAttributeValue("xmlns:xlink","http://www.w3.org/1999/xlink");
			(* other standard name spaces available for different documents:
				xmlns:table="urn:oasis:names:tc:opendocument:xmlns:table:1.0" 
				xmlns:draw="urn:oasis:names:tc:opendocument:xmlns:drawing:1.0" 
				xmlns:xlink="http://www.w3.org/1999/xlink" 
				xmlns:dc="http://purl.org/dc/elements/1.1/" 
				xmlns:meta="urn:oasis:names:tc:opendocument:xmlns:meta:1.0" 
				xmlns:number="urn:oasis:names:tc:opendocument:xmlns:datastyle:1.0" 
				xmlns:chart="urn:oasis:names:tc:opendocument:xmlns:chart:1.0"
				xmlns:dr3d="urn:oasis:names:tc:opendocument:xmlns:dr3d:1.0" 
				xmlns:math="http://www.w3.org/1998/Math/MathML" 
				xmlns:form="urn:oasis:names:tc:opendocument:xmlns:form:1.0" 
				xmlns:script="urn:oasis:names:tc:opendocument:xmlns:script:1.0" 
				xmlns:ooo="http://openoffice.org/2004/office" 
				xmlns:ooow="http://openoffice.org/2004/writer" 
				xmlns:oooc="http://openoffice.org/2004/calc" 
				xmlns:presentation="http://openoffice.org/2000/presentation"
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
				*)
			doc.AddContent(root);
			
			NEW(meta); meta.SetName("office:meta");
			meta.AddContent(CharLeaf("meta:generator", Generator));
			meta.AddContent(CharLeaf("meta:initial-creator","Vorname Nachname"));
			meta.AddContent(CharLeaf("meta:creation-date","2005-09-27T16:53:48"));
               meta.AddContent(CharLeaf("dc:creator","Vorname Nachname"));
               meta.AddContent(CharLeaf("dc:date","2005-09-29T18:12:57"));
               meta.AddContent(CharLeaf("meta:printed-by","Vorname Nachname"));
               meta.AddContent(CharLeaf("meta:print-date","2005-09-29T17:57:42"));
               meta.AddContent(CharLeaf("dc:language","de-DE"));
               meta.AddContent(CharLeaf("meta:editing-cycles","11"));
               meta.AddContent(CharLeaf("meta:editing-duration","PT6H11M44S"));
               meta.AddContent(AttrLeaf("meta:user-defined","meta:name","Info 1")); 
               root.AddContent(meta);
               (*
                <meta:document-statistic (*! tbd*)
                        meta:table-count="0"
                        meta:image-count="4"
                        meta:object-count="0"
                        meta:page-count="5"
                        meta:paragraph-count="92"
                        meta:word-count="1460"
                        meta:character-count="10405"/>
                *)
		RETURN doc
		END Meta;
		
		(* 
			may contain: 
			"office:document-common-attrs"
			"office:scripts"
			"office:font-face-decls"
			"office:automatic-styles"
			"office:body"
		*)
		
		(* example implementation; content *)
		PROCEDURE Content(par:Paragraph):XML.Document;
		VAR doc: XML.Document; xmlDecl: XML.XMLDecl; root, auto, body,text, p, bold, fatitalic, italic, red, arial: XML.Element; chars: XML.ArrayChars;
			para:Paragraph;
		BEGIN
			NEW(doc); 
			NEW(xmlDecl); xmlDecl.SetVersion(OpenDocumentVersion); xmlDecl.SetEncoding(DefaultEncoding); doc.AddContent(xmlDecl);
			NEW(root); root.SetName("office:document-content"); 
				root.SetAttributeValue("xmlns:office","urn:oasis:names:tc:opendocument:xmlns:office:1.0");
				root.SetAttributeValue("xmlns:style","urn:oasis:names:tc:opendocument:xmlns:style:1.0");
				root.SetAttributeValue("xmlns:text","urn:oasis:names:tc:opendocument:xmlns:text:1.0");
				root.SetAttributeValue("xmlns:fo","urn:oasis:names:tc:opendocument:xmlns:xsl-fo-compatible:1.0"); 
				root.SetAttributeValue("xmlns:svg","urn:oasis:names:tc:opendocument:xmlns:svg-compatible:1.0");
			doc.AddContent(root);
			
			(*automatic styles needed for the document content:*)
			NEW(auto); auto.SetName("office:automatic-styles"); root.AddContent(auto);
				NEW(fatitalic); fatitalic.SetName("style:style");
				fatitalic.SetAttributeValue("style:name","P1");
				fatitalic.SetAttributeValue("style:family","paragraph");
				fatitalic.SetAttributeValue("style:parent-style-name","Standard");
					NEW(text); text.SetName("style:text-properties");
					text.SetAttributeValue("fo:font-style","italic");
					text.SetAttributeValue("fo:font-weight","bold");
					fatitalic.AddContent(text);
				auto.AddContent(fatitalic);
				
				NEW(bold); bold.SetName("style:style");
				bold.SetAttributeValue("style:name","Bold");
				bold.SetAttributeValue("style:family","text");
					NEW(text); text.SetName("style:text-properties"); text.SetAttributeValue("fo:font-weight","bold");
						(*The fo:font-weight attribute is usable with the following element: <style:text-properties> 16.27.28.
						The values of the fo:font-weight attribute are normal, bold, 100, 200, 300, 400, 500, 600, 700, 800 or 900. *)
					bold.AddContent(text);
				auto.AddContent(bold);
				
				NEW(italic); bold.SetName("style:style");
				italic.SetAttributeValue("style:name","Italic");
				italic.SetAttributeValue("style:family","text");
					NEW(text); text.SetName("style:text-properties"); text.SetAttributeValue("fo:font-style","italic");
					italic.AddContent(text);
				auto.AddContent(italic);
				
				NEW(red); red.SetName("style:style");
				red.SetAttributeValue("style:name","Red");
				red.SetAttributeValue("style:family","text");
					NEW(text); text.SetName("style:text-properties"); text.SetAttributeValue("fo:color","#ff0000");
					red.AddContent(text);
				auto.AddContent(red);
				
				NEW(arial); arial.SetName("style:style");
				arial.SetAttributeValue("style:name","Arial");
				arial.SetAttributeValue("style:family","text");
					NEW(text); text.SetName("style:text-properties"); text.SetAttributeValue("style:font-name","Arial");
					arial.AddContent(text);
				auto.AddContent(arial);

               (*
			The document body contains an element to indicate which type of content this document contains. Currently supported document types are:
				text documents
				drawing documents
				presentation documents
				spreadsheet documents
				chart documents
				image documents
			*)
			(* text example *)
			NEW(body); body.SetName("office:body"); 
				NEW(text); text.SetName("office:text");
					NEW(p); p.SetName("text:p");  p.SetAttributeValue("text:style-name","Standard"); 
						NEW(chars); chars.SetStr("Hello World"); (*! text block 1*)
						p.AddContent(chars);
					text.AddContent(p); 
					NEW(p); p.SetName("text:p"); 
						p.SetAttributeValue("text:style-name","P1"); 
						NEW(chars); chars.SetStr("Holla World");  (*! text block 2 in different format*)
						p.AddContent(chars); 
					text.AddContent(p); 
					para:=par;
					WHILE para#NIL DO 
						NEW(p); p.SetName("text:p"); p.SetAttributeValue("text:style-name",para.stylename); 
						NEW(chars); chars.SetStr(para.b.s);
						p.AddContent(chars);
						text.AddContent(p);
						para:=para.next
					END;
				body.AddContent(text); 
			root.AddContent(body);
			RETURN doc
		END Content;
		
		(* may contain:
		"office:document-common-attrs"
		"office:font-face-decls"
		"office:styles"
		"office:automatic-styles"
		"office:master-styles"
		*)
		PROCEDURE Styles():XML.Document;
		VAR doc: XML.Document; xmlDecl: XML.XMLDecl; root, style, font, bold, default, parstyle,text,standard: XML.Element;
		BEGIN
			NEW(doc); 
			NEW(xmlDecl); xmlDecl.SetVersion(OpenDocumentVersion); xmlDecl.SetEncoding(DefaultEncoding); doc.AddContent(xmlDecl);
			NEW(root); root.SetName("office:document-style");
			root.SetAttributeValue("xmlns:office","urn:oasis:names:tc:opendocument:xmlns:office:1.0");
			root.SetAttributeValue("xmlns:style","urn:oasis:names:tc:opendocument:xmlns:style:1.0");
			root.SetAttributeValue("xmlns:text","urn:oasis:names:tc:opendocument:xmlns:text:1.0");
			root.SetAttributeValue("xmlns:fo","urn:oasis:names:tc:opendocument:xmlns:xsl-fo-compatible:1.0"); 
			root.SetAttributeValue("xmlns:svg","urn:oasis:names:tc:opendocument:xmlns:svg-compatible:1.0");
			doc.AddContent(root);
			
			NEW(style); style.SetName("office:font-face-decls"); 
				NEW(font); font.SetName("style:font-face"); 
				font.SetAttributeValue("style:name",'Times New Roman');
				font.SetAttributeValue("svg:font-family","&apos;Times New Roman&apos;");
				font.SetAttributeValue("style:font-family-generic","roman");
				font.SetAttributeValue("style:font-pitch","variable");
				style.AddContent(font);	
				
				NEW(font); font.SetName("style:font-face"); 
				font.SetAttributeValue("style:name",'Arial');
				font.SetAttributeValue("svg:font-family","Arial");
				font.SetAttributeValue("style:font-family-generic","swiss");
				font.SetAttributeValue("style:font-pitch","variable");
				style.AddContent(font);	
			root.AddContent(style);
			NEW(style); style.SetName("office:styles");
				NEW(default); default.SetName("style:default-style"); 
				default.SetAttributeValue("style:family","paragraph");
					NEW(parstyle); parstyle.SetName("style:paragraph-properties"); 
					parstyle.SetAttributeValue("fo:hyphenation-ladder-count","no-limit");
					parstyle.SetAttributeValue("style:text-autospace","ideograph-alpha");
					parstyle.SetAttributeValue("style:punctuation-wrap","hanging");
					parstyle.SetAttributeValue("style:line-break","strict");
					parstyle.SetAttributeValue("style:tab-stop-distance","1.251cm");
					parstyle.SetAttributeValue("style:writing-mode","page");
					default.AddContent(parstyle);
					
					NEW(text); text.SetName("style:text-properties");
					text.SetAttributeValue("style:use-window-font-color","true");
					text.SetAttributeValue("style:font-name","Times New Roman");
					text.SetAttributeValue("fo:font-size","12pt");
					text.SetAttributeValue("fo:language","de");
					text.SetAttributeValue("fo:country","DE");
					text.SetAttributeValue("style:letter-kerning","true");
					text.SetAttributeValue("fo:hyphenate","false");
					text.SetAttributeValue("fo:hyphenation-remain-char-count","2");
					text.SetAttributeValue("fo:hyphenation-push-char-count","2");
					default.AddContent(text);
				style.AddContent(default);
				
				NEW(standard); standard.SetName("style:style");
				standard.SetAttributeValue("style:name","Standard");
				standard.SetAttributeValue("style:family","paragraph");
				standard.SetAttributeValue("style:class","text");
				style.AddContent(standard);
				

				
			root.AddContent(style);
			(* root.AddComponents(<automatic styles needed for the named styles>); *)
			(* root.AddComponents(<master styles>); *)
			RETURN doc
		END Styles;
		
		(*may contain
		"office:document-common-attrs"
		"office:settings"
		*)
		PROCEDURE Settings():XML.Document;
		VAR doc: XML.Document; xmlDecl: XML.XMLDecl; root: XML.Element;
		BEGIN
			NEW(doc); 
			NEW(xmlDecl); xmlDecl.SetVersion(OpenDocumentVersion); xmlDecl.SetEncoding(DefaultEncoding); doc.AddContent(xmlDecl);
			NEW(root); root.SetName("office:document-settings"); root.SetAttributeValue("xmlns:office", "urn:oasis:names:tc:opendocument:xmlns:office:1.0");
			root.SetAttributeValue("xmlns:xlink", "http://www.w3.org/1999/xlink"); root.SetAttributeValue("xmlns:config", "urn:oasis:names:tc:opendocument:xmlns:config:1.0");
			root.SetAttributeValue("xmlns:ooo", "http://openoffice.org/2004/office"); root.SetAttributeValue("office:version", "1.2");
			doc.AddContent(root);
			RETURN doc
		END Settings;
		
		(* enumerates all parts of archive *)
		PROCEDURE Manifest(CONST type: ARRAY OF CHAR):XML.Document;
		VAR doc: XML.Document; xmlDecl: XML.XMLDecl; root,file: XML.Element; 
		BEGIN
			NEW(doc); 
			NEW(xmlDecl); xmlDecl.SetVersion(OpenDocumentVersion); xmlDecl.SetEncoding(DefaultEncoding); doc.AddContent(xmlDecl);
			NEW(root); root.SetName("manifest"); doc.AddContent(root);
			root.SetAttributeValue("xmlns","urn:oasis:names:tc:opendocument:xmlns:manifest:1.0");
			NEW(file); file.SetName("file-entry"); root.AddContent(file);
			IF type="text" THEN file.SetAttributeValue("media-type","application/vnd.oasis.opendocument.text"); (*! make dependent on type *)
			ELSIF type="presentation" THEN file.SetAttributeValue("media-type","application/vnd.oasis.opendocument.presentation");
			ELSE HALT(200)
			END;
			file.SetAttributeValue("full-path","/");
			NEW(file); file.SetName("file-entry"); root.AddContent(file);
			file.SetAttributeValue("media-type","text/xml");
			file.SetAttributeValue("full-path","content.xml");
			NEW(file); file.SetName("file-entry"); root.AddContent(file);
			file.SetAttributeValue("media-type","text/xml");
			file.SetAttributeValue("full-path","meta.xml");
			NEW(file); file.SetName("file-entry"); root.AddContent(file);
			file.SetAttributeValue("media-type","text/xml");
			file.SetAttributeValue("full-path","content.xml");
			NEW(file); file.SetName("file-entry"); root.AddContent(file);
			file.SetAttributeValue("media-type","text/xml");
			file.SetAttributeValue("full-path","settings.xml");		
			RETURN doc
		END Manifest;
		
		PROCEDURE Signatures():XML.Document;
		VAR doc: XML.Document; xmlDecl: XML.XMLDecl; root, sig, si,sv, ki, x509: XML.Element; 
		BEGIN
			NEW(doc); 
			NEW(xmlDecl); xmlDecl.SetVersion(OpenDocumentVersion); xmlDecl.SetEncoding(DefaultEncoding); doc.AddContent(xmlDecl);
			NEW(root); 
				root.SetName("dsig:document-signatures"); 
				root.SetAttributeValue("xmlns:dsig","urn:oasis:names:tc:opendocument:xmlns:digitalsignature:1.0");
				root.SetAttributeValue("dsig:version","1.2");
				doc.AddContent(root);
				
				sig:=XMLSignatures.Signature("ID0002");
					si:=XMLSignatures.SignedInfo("http://www.w3.org/2001/10/xml-exc-c14n#", "http://www.w3.org/2000/09/xmldsig#hmac-sha1");  (*canonicAlgo, signatureAlgo*)
					si.AddContent(XMLSignatures.Reference("content.XML", 'http://www.w3.org/2000/09/xmldsig#sha1', "VEPKwzfPGOxh2OUpoK0bcl58jtU=")); (* URI, digestmethod, digestvalue *)
					sig.AddContent(si);
	
					sv:=XMLSignatures.SignatureValue("KG4NUHBP123XHR459dw==");
					sig.AddContent(sv);
					
					ki:=XMLSignatures.KeyInfo("");
					sig.AddContent(ki); 
					
					x509:=XMLSignatures.X509Data("CN=Sample,OU=R&amp;D,O=Company Ltd.,L=Dublin 4,ST=Dublin,C=IE", "MIIEZDCCA0ygRNp9aKD1fEQgJ");
					x509.AddContent(XMLSignatures.X509IssuerSerial("The Issuer","001"));
					ki.AddContent(x509);
				root.AddContent(sig);
				
				(*root.AddContent(Signature("testId","testIssuer","1","asffasdfasdfasdfsdfFA0CD34BA001CCF0dw==")); (* test *)*)
		RETURN doc
			(*The <dsig:document-signatures> element is a root element.
The <dsig:document-signatures> element has the following attribute: dsig:version 5.4.1.
The <dsig:document-signatures> element has the following child element: <ds:Signature> 5.3.
*)
		END Signatures;
		
		(*Consumers may require that a digital signature includes a certain set of files. That is, they may consider a digital signature to be valid if, and only if,
the digital signature itself is valid, and
if the <ds:Reference> child elements of the <ds:Signature> element reference a certain set of files.
In particular, consumers may require that a digital signature references all files contained in a package.*)

		
		PROCEDURE CharLeaf(CONST name, string: ARRAY OF CHAR): XML.Element;
		VAR xml: XML.Element; chars: XML.ArrayChars;
		BEGIN
			NEW(xml); xml.SetName(name); 
			NEW(chars); chars.SetStr(string); xml.AddContent(chars);
			RETURN xml
		END CharLeaf;
		
		PROCEDURE AttrLeaf(CONST name, attr, value: ARRAY OF CHAR): XML.Element;
		VAR xml: XML.Element; 
		BEGIN
			NEW(xml); xml.SetName(name);
			xml.SetAttributeValue(attr,value);
			RETURN xml
		END AttrLeaf;
		(*
		PROCEDURE Test*;
		VAR doc: Document; f: Files.File; w:Files.Writer;
		BEGIN
			NEW(doc);
			doc.AddStandardFiles;
			doc. AddContent;
			
			f:=Files.New("Test14.odt");
			Files.OpenWriter(w,f,0);
			doc.Write(w);
			Files.Register(f);

			doc.Log; log.Ln;
			log.Update;
		END Test;
		
		PROCEDURE Test1*;
		VAR doc: Document; f:Files.File; w:Files.Writer;
		BEGIN
			NEW(doc); 
			doc.AddStandardFiles;
			(* try out: document body as a series of paragraphs *)
			doc.paragraphs.Write("a");
			doc.paragraphs.Write("b");
			doc.paragraphs.Write("d");
			doc.Update;
			
			f:=Files.New("Test20.odt");
			Files.OpenWriter(w,f,0);
			doc.Write(w);
			Files.Register(f);
			
			doc.Log; log.Ln;log.Update;
			
		END Test1;
		*)
BEGIN
	NEW(log, KernelLog.Send, 1024);
END OpenDocument.

SystemTools.FreeDownTo OpenDocument~
OpenDocument.Test~
OpenDocument.Test1~



OpenDocument files consist of a Zip file containing a hierarchy of folders, files, and XML files
Example: TextDoc structure:

Document.odt
|
+-- META-INF
|    +-- manifest.xml
+-- Thumbnails
|    +-- thumbnail.png
+-- Pictures    |
|    +-- 10000000000001E800000118B5A37F3F.png
+-- mimetype
+-- content.xml
+-- styles.xml
+-- meta.xml
+-- settings.xml

Dabei ist die Datei mimetype innerhalb der Zip-Datei immer unkomprimiert, alle anderen Dateien können komprimiert sein.
Im Ordner Pictures befindet sich, in diesem Beispiel, ein Bild im PNG-Format. 
Die Datei content.xml enthält die Textinhalte des Dokumentes. 
In styles.xml sind Formatierungen gespeichert. 
Die Datei meta.xml enthält Metadaten. Zum Beispiel, wie viele Seiten das Dokument enthält, wer der Autor ist und wann es angelegt und geändert wurde. 
Die Datei thumbnail.png im Ordner Thumbnails zeigt ein kleines Dokumentabbild der ersten Seite des Dokumentes. Dieses Abbild kann von einem Dateibetrachter als Vorschaubildchen verwendet werden. 
Die dokumentspezifischen Einstellungen finden sich in der settings.xml. Üblicherweise finden sich dort die Druckeinstellungen. 
Die manifest.xml listet alle Dateien mit Dateityp in diesem Archivformat auf. 

Normative RelaxNG Grammar: 
<grammar

xmlns="http://relaxng.org/ns/structure/1.0"
xmlns:a="http://relaxng.org/ns/compatibility/annotations/1.0"

datatypeLibrary="http://www.w3.org/2001/XMLSchema-datatypes"

xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0"
xmlns:meta="urn:oasis:names:tc:opendocument:xmlns:meta:1.0"
xmlns:config="urn:oasis:names:tc:opendocument:xmlns:config:1.0"
xmlns:text="urn:oasis:names:tc:opendocument:xmlns:text:1.0"
xmlns:table="urn:oasis:names:tc:opendocument:xmlns:table:1.0"
xmlns:draw="urn:oasis:names:tc:opendocument:xmlns:drawing:1.0"
xmlns:presentation="urn:oasis:names:tc:opendocument:xmlns:presentation:1.0"
xmlns:dr3d="urn:oasis:names:tc:opendocument:xmlns:dr3d:1.0"
xmlns:chart="urn:oasis:names:tc:opendocument:xmlns:chart:1.0"
xmlns:form="urn:oasis:names:tc:opendocument:xmlns:form:1.0"
xmlns:script="urn:oasis:names:tc:opendocument:xmlns:script:1.0"
xmlns:style="urn:oasis:names:tc:opendocument:xmlns:style:1.0"
xmlns:number="urn:oasis:names:tc:opendocument:xmlns:datastyle:1.0"
xmlns:anim="urn:oasis:names:tc:opendocument:xmlns:animation:1.0"

xmlns:dc="http://purl.org/dc/elements/1.1/"
xmlns:xlink="http://www.w3.org/1999/xlink"
xmlns:math="http://www.w3.org/1998/Math/MathML"
xmlns:xforms="http://www.w3.org/2002/xforms"

xmlns:fo="urn:oasis:names:tc:opendocument:xmlns:xsl-fo-compatible:1.0"
xmlns:svg="urn:oasis:names:tc:opendocument:xmlns:svg-compatible:1.0"
xmlns:smil="urn:oasis:names:tc:opendocument:xmlns:smil-compatible:1.0"
>


A typical text file structure (*from an OpenOffice Test file is given here:

<?xml version="1.0" encoding="UTF-8"?>

<office:document-content xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0" xmlns:style="urn:oasis:names:tc:opendocument:xmlns:style:1.0" xmlns:text="urn:oasis:names:tc:opendocument:xmlns:text:1.0" xmlns:table="urn:oasis:names:tc:opendocument:xmlns:table:1.0" xmlns:draw="urn:oasis:names:tc:opendocument:xmlns:drawing:1.0" xmlns:fo="urn:oasis:names:tc:opendocument:xmlns:xsl-fo-compatible:1.0" xmlns:xlink="http://www.w3.org/1999/xlink" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:meta="urn:oasis:names:tc:opendocument:xmlns:meta:1.0" xmlns:number="urn:oasis:names:tc:opendocument:xmlns:datastyle:1.0" xmlns:svg="urn:oasis:names:tc:opendocument:xmlns:svg-compatible:1.0" xmlns:chart="urn:oasis:names:tc:opendocument:xmlns:chart:1.0" xmlns:dr3d="urn:oasis:names:tc:opendocument:xmlns:dr3d:1.0" xmlns:math="http://www.w3.org/1998/Math/MathML" xmlns:form="urn:oasis:names:tc:opendocument:xmlns:form:1.0" xmlns:script="urn:oasis:names:tc:opendocument:xmlns:script:1.0" xmlns:ooo="http://openoffice.org/2004/office" xmlns:ooow="http://openoffice.org/2004/writer" xmlns:oooc="http://openoffice.org/2004/calc" xmlns:dom="http://www.w3.org/2001/xml-events" xmlns:xforms="http://www.w3.org/2002/xforms" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:rpt="http://openoffice.org/2005/report" xmlns:of="urn:oasis:names:tc:opendocument:xmlns:of:1.2" xmlns:xhtml="http://www.w3.org/1999/xhtml" xmlns:grddl="http://www.w3.org/2003/g/data-view#" xmlns:tableooo="http://openoffice.org/2009/table" xmlns:field="urn:openoffice:names:experimental:ooo-ms-interop:xmlns:field:1.0" office:version="1.2" grddl:transformation="http://docs.oasis-open.org/office/1.2/xslt/odf2rdf.xsl">

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
	</office:body>
</office:document-content>
*)

signature example
<Signature xmlns="http://www.w3.org/2000/09/xmldsig#">
  <SignedInfo>
   <CanonicalizationMethod
    Algorithm="http://www.w3.org/TR/2001/REC-xml-c14n-20010315"/>
   <SignatureMethod
    Algorithm="http://www.w3.org/2000/09/xmldsig#rsa-sha1"/>
   <Reference URI="">
    <Transforms>
     <Transform
      Algorithm="http://www.w3.org/2000/09/xmldsig#enveloped-signature"/>
    </Transforms>
    <DigestMethod Algorithm="http://www.w3.org/2000/09/xmldsig#sha1"/>
    <DigestValue>tVicGh6V+8cHbVYFIU91o5+L3OQ=</DigestValue>
   </Reference>
  </SignedInfo>
  <SignatureValue>
   dJDHiGQMaKN8iPuWApAL57eVnxz2BQtyujwfPSgE7HyKoxYtoRB97ocxZ
   8ZU440wHtE39ZwRGIjvwor3WfURxnIgnI1CChMXXwoGpHH//Zc0z4ejaz
   DuCNEq4Mm4OUVTiEVuwcWAOMkfDHaM82awYQiOGcwMbZe38UX0oPJ2DOE=
  </SignatureValue>
  <KeyInfo>
   <X509Data>
    <X509SubjectName>
     CN=My Name,O=Test Certificates Inc.,C=US
    </X509SubjectName>
    <X509Certificate>
     MIIB9zCCAWCgAwIBAgIERZwdkzANBgkqhkiG9w0BAQUFADBAMQswCQYD
     VQQGEwJVUzEfMB0GA1UEChMWVGVzdCBDZXJ0aWZpY2F0ZXMgSW5jLjEQ
     MA4GA1UEAxMHTXkgTmFtZTAeFw0wNzAxMDMyMTE4MTFaFw0zMTA4MjUy
     ...
    </X509Certificate>
   </X509Data>
  </KeyInfo>
 </Signature>


X509 certificate:
Struktur eines X-509-v3-Zertifikats

    Zertifikat
        Version
        Seriennummer
        Algorithmen-ID
        Aussteller
            Land/Region
            Bundesland/Kanton
            Ort
            Organisationseinheit
            Organisation
            Gemeinsamer Name
        Gültigkeit
            von
            bis
        Zertifikatinhaber
        Zertifikatinhaber-Schlüsselinformationen
            Public-Key-Algorithmus
            Public Key des Zertifikatinhabers
        Eindeutige ID des Ausstellers (optional)
        Eindeutige ID des Inhabers (optional)
        Erweiterungen
            
    Zertifikat-Signaturalgorithmus
    Zertifikat-Signatur

-----------------------
http://www.w3.org/TR/xmldsig-core/#sec-CoreSyntax
An X509Data element within KeyInfo contains one or more identifiers of keys or X509 certificates (or certificates' identifiers or a revocation list). The content of X509Data is:

    At least one element, from the following set of element types; any of these may appear together or more than once iff (if and only if) each instance describes or is related to the same certificate:
        The X509IssuerSerial element, which contains an X.509 issuer distinguished name/serial number pair. The distinguished name SHOULD be represented as a string that complies with section 3 of RFC4514 [LDAP-DN], to be generated according to the Distinguished Name Encoding Rules section below,
        The X509SubjectName element, which contains an X.509 subject distinguished name that SHOULD be represented as a string that complies with section 3 of RFC4514 [LDAP-DN], to be generated according to the Distinguished Name Encoding Rules section below,
        The X509SKI element, which contains the base64 encoded plain (i.e. non-DER-encoded) value of a X509 V.3 SubjectKeyIdentifier extension.
        The X509Certificate element, which contains a base64-encoded [X509v3] certificate, and
        Elements from an external namespace which accompanies/complements any of the elements above.
        The X509CRL element, which contains a base64-encoded certificate revocation list (CRL) [X509v3].

<ds:Reference 
  Id=ID
  URI=anyURI
  Type=anyURI>
</ds:Reference>

Message digests in xmldsig-core
http://www.w3.org/TR/xmldsig-core/#sec-CoreSyntax