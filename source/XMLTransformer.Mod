MODULE XMLTransformer;	(** AUTHOR "Simon L. Keel"; PURPOSE "transforming XML to BB-text"; *)

IMPORT
	Strings, XML, XMLObjects, Commands, Files, Modules;

TYPE
	String = Strings.String;

	XMLPluginProcInfo = POINTER TO RECORD
		name, procedure : ARRAY 128 OF CHAR;
		next : XMLPluginProcInfo;
	END;

	TransformProc = PROCEDURE (element : XML.Element) : XML.Container;

VAR
	xmlPluginProcs : XMLPluginProcInfo;

PROCEDURE Transform*(elem : XML.Element) : XML.Container;
VAR
	transformProc : TransformProc;
	container : XML.Container;
	s, name : String;
BEGIN
	s := elem.GetName();
	name := Strings.UpperCaseInNew(s^);
	transformProc := FindProcedure(name^);
	IF transformProc # NIL THEN
		RETURN transformProc(elem);
	ELSE
		NEW(container);
		RETURN container;
	END;
END Transform;

PROCEDURE AddContentsOf*(source, target : XML.Container);
VAR
	enum: XMLObjects.Enumerator;
	p : ANY;
BEGIN
	enum := source.GetContents();
	WHILE (enum.HasMoreElements()) DO
		p := enum.GetNext();
		target.AddContent(p(XML.Content));
	END;
END AddContentsOf;

PROCEDURE TransformElemsIn*(container : XML.Container) : XML.Container;
VAR
	c : XML.Container;
	enum: XMLObjects.Enumerator;
	p : ANY;
BEGIN
	NEW(c);
	enum := container.GetContents();
	WHILE (enum.HasMoreElements()) DO
		p := enum.GetNext();
		IF p IS XML.Element THEN
			AddContentsOf(Transform(p(XML.Element)), c);
		END;
	END;
	RETURN c;
END TransformElemsIn;

PROCEDURE GetNewParagraph*(style : ARRAY OF CHAR) : XML.Element;
VAR
	paragraph : XML.Element;
	styleAttrPar : XML.Attribute;
	s : String;
BEGIN
	NEW(paragraph); paragraph.SetName("Paragraph");
	NEW(styleAttrPar); s := Strings.NewString("style"); styleAttrPar.SetName(s^);
	styleAttrPar.SetValue(style);
	paragraph.AddAttribute(styleAttrPar);
	RETURN paragraph;
END GetNewParagraph;

PROCEDURE GetNewSpan*(style : ARRAY OF CHAR) : XML.Element;
VAR
	span : XML.Element;
	styleAttrPar : XML.Attribute;
	s : String;
BEGIN
	NEW(span); span.SetName("Span");
	NEW(styleAttrPar); s := Strings.NewString("style"); styleAttrPar.SetName(s^);
	styleAttrPar.SetValue(style);
	span.AddAttribute(styleAttrPar);
	RETURN span;
END GetNewSpan;

PROCEDURE FindProcedure(name : ARRAY OF CHAR) : TransformProc;
VAR
	transformProc : TransformProc;
	moduleName, procedureName : Modules.Name; msg : ARRAY 32 OF CHAR; res : WORD;
	cur : XMLPluginProcInfo;
BEGIN {EXCLUSIVE}
	Strings.Delete(name, 0, 3);
	cur := xmlPluginProcs;
	WHILE cur # NIL DO
		IF cur.name = name THEN
			Commands.Split(cur.procedure, moduleName, procedureName, res, msg);
			IF (res = Commands.Ok) THEN
				GETPROCEDURE(moduleName, procedureName, transformProc);
				RETURN transformProc;
			END;
		END;
		cur := cur.next
	END;
	RETURN NIL
END FindProcedure;

PROCEDURE Register*(context : Commands.Context);
VAR c : XMLPluginProcInfo;
BEGIN {EXCLUSIVE}
	NEW(c);
	context.arg.SkipWhitespace; context.arg.String(c.name);
	context.arg.SkipWhitespace; context.arg.String(c.procedure);
	c.next := xmlPluginProcs; xmlPluginProcs := c;
	StoreXMLPlugins;
END Register;

PROCEDURE StoreXMLPlugins;
VAR f : Files.File;
	w : Files.Writer;
	cur : XMLPluginProcInfo;
	res : WORD;
	n0, n1 : ARRAY 64 OF CHAR;
BEGIN
	n0 := "XMLPluginConfig.dat"; n1 := "XMLPluginConfig.dat.Bak";
	Files.Rename(n0, n1, res);
	f := Files.New("XMLPluginConfig.dat");
	Files.OpenWriter(w, f, 0);
	Files.Register(f);
	cur := xmlPluginProcs;
	WHILE cur # NIL DO
		w.Char('"'); w.String(cur.name); w.Char('"'); w.Char(09X);
		w.Char('"'); w.String(cur.procedure); w.Char('"'); w.Ln;
 		cur := cur.next
	END;
	w.Update
END StoreXMLPlugins;

PROCEDURE LoadXMLPlugins;
VAR f : Files.File;
	r : Files.Reader;
	c : XMLPluginProcInfo;
BEGIN
	f := Files.Old("XMLPluginConfig.dat");
	IF f # NIL THEN
		Files.OpenReader(r, f, 0);
		WHILE r.res = 0 DO
			NEW(c);
			r.String(c.name); r.SkipWhitespace;
			r.String(c.procedure);
			IF r.res = 0 THEN c.next := xmlPluginProcs; xmlPluginProcs:= c END;
			r.SkipLn
		END
	END
END LoadXMLPlugins;

BEGIN
	LoadXMLPlugins;
END XMLTransformer.