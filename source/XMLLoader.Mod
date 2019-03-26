MODULE XMLLoader;	(** Stefan Walthert   *)
(** AUTHOR "swalthert"; PURPOSE ""; *)

IMPORT
	Files, XML, XMLGeneratorSchema, XMLScanner, XMLParser, CSS2, CSS2Scanner, CSS2Parser, XMLStyle;

CONST
	DefaultXMLGeneratorFile* = "DefaultXGS.xml";
	DefaultCSS2File* = "DefaultCSS2.css";

VAR
	DefaultXMLElementRegistry-: XML.ElementRegistry;
	DefaultStyleSheet-: CSS2.StyleSheet;

PROCEDURE LoadCSS*(cssName: ARRAY OF CHAR): CSS2.StyleSheet;
VAR cssFile: Files.File; cssScanner: CSS2Scanner.Scanner; cssParser: CSS2Parser.Parser;
BEGIN
	cssFile := Files.Old(cssName);
	IF cssFile = NIL THEN cssFile := Files.Old(DefaultCSS2File)
	END;
	IF cssFile = NIL THEN RETURN NIL
	ELSE NEW(cssScanner, cssFile); NEW(cssParser, cssScanner); RETURN cssParser.Parse()
	END
END LoadCSS;

PROCEDURE LoadXML*(xmlName: ARRAY OF CHAR): XML.Document;
VAR xmlFile: Files.File; xmlScanner: XMLScanner.Scanner; xmlParser: XMLParser.Parser;
	reader: Files.Reader;
BEGIN
	xmlFile := Files.Old(xmlName);
	IF xmlFile = NIL THEN RETURN NIL
	ELSE NEW(reader, xmlFile, 0); NEW(xmlScanner, reader); NEW(xmlParser, xmlScanner); RETURN xmlParser.Parse()
	END
END LoadXML;

PROCEDURE LoadComponents*(xmlName, generatorSchemaName: ARRAY OF CHAR): XML.Document;
VAR xmlFile: Files.File; xmlScanner: XMLScanner.Scanner; xmlParser: XMLParser.Parser;
	reader: Files.Reader;
BEGIN
	xmlFile := Files.Old(xmlName);
	IF xmlFile = NIL THEN RETURN NIL
	ELSE
		NEW(reader, xmlFile, 0);
		NEW(xmlScanner, reader); NEW(xmlParser, xmlScanner);
		xmlParser.elemReg := XMLGeneratorSchema.OpenGeneratorSchema(generatorSchemaName);
		IF xmlParser.elemReg = NIL THEN xmlParser.elemReg := DefaultXMLElementRegistry END;
		RETURN xmlParser.Parse()
	END
END LoadComponents;

PROCEDURE Load*(xmlName, cssName, generatorSchemaName: ARRAY OF CHAR): XML.Document;
VAR xml: XML.Document; css: CSS2.StyleSheet;
BEGIN
	xml := LoadComponents(xmlName, generatorSchemaName); css := LoadCSS(cssName);
	IF xml = NIL THEN RETURN NIL
	ELSE XMLStyle.AttachStyle(xml.GetRoot(), css); RETURN xml
	END
END Load;

PROCEDURE SetDefaultXMLElementRegistry*(generatorSchemaName: ARRAY OF CHAR);
BEGIN
	DefaultXMLElementRegistry := XMLGeneratorSchema.OpenGeneratorSchema(generatorSchemaName)
END SetDefaultXMLElementRegistry;

PROCEDURE SetDefaultStyleSheet*(cssName: ARRAY OF CHAR);
BEGIN
	DefaultStyleSheet := LoadCSS(cssName)
END SetDefaultStyleSheet;

BEGIN
	DefaultXMLElementRegistry := XMLGeneratorSchema.OpenGeneratorSchema(DefaultXMLGeneratorFile);
	DefaultStyleSheet := LoadCSS(DefaultCSS2File)
END XMLLoader.
