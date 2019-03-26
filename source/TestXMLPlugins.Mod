MODULE TestXMLPlugins;	(** AUTHOR "Simon L. Keel"; PURPOSE "example-plugins for the XMLTransformer"; *)

IMPORT
	XMLTransformer, Strings, XML, WebBrowserComponents;

TYPE
	String = Strings.String;

VAR
	newLine : ARRAY 3 OF CHAR;

PROCEDURE A*(elem : XML.Element) : XML.Container;
VAR
	container : XML.Container;
	p, sp : XML.Element;
	cdata : XML.CDataSect;
	s : String;
BEGIN
	NEW(container);

	p := XMLTransformer.GetNewParagraph("Center");
	sp := XMLTransformer.GetNewSpan("Assertion");
	NEW(cdata);
	s := Strings.ConcatToNew("This is example-output of BB:A tag", newLine);
	cdata.SetStr(s^);
	sp.AddContent(cdata);
	p.AddContent(sp);
	container.AddContent(p);

	RETURN container;
END A;

PROCEDURE AB*(elem : XML.Element) : XML.Container;
VAR
	container : XML.Container;
	e : XML.Element;
BEGIN
	NEW(container);

	NEW(e); e.SetName("BB:A");
	XMLTransformer.AddContentsOf(XMLTransformer.Transform(e), container);

	XMLTransformer.AddContentsOf(XMLTransformer.TransformElemsIn(elem), container);

	NEW(e); e.SetName("BB:B");
	XMLTransformer.AddContentsOf(XMLTransformer.Transform(e), container);

	RETURN container;
END AB;

PROCEDURE B*(elem : XML.Element) : XML.Container;
VAR
	container : XML.Container;
	p, sp : XML.Element;
	cdata : XML.CDataSect;
	s : String;
BEGIN
	NEW(container);

	p := XMLTransformer.GetNewParagraph("Left");
	sp := XMLTransformer.GetNewSpan("Preferred");
	NEW(cdata);
	s := Strings.ConcatToNew("This is example-output of the BB:B tag", newLine);
	cdata.SetStr(s^);
	sp.AddContent(cdata);
	p.AddContent(sp);
	container.AddContent(p);

	RETURN container;
END B;

PROCEDURE PICT*(elem : XML.Element) : XML.Container;
VAR
	container : XML.Container;
	p, o : XML.Element;
	img : WebBrowserComponents.StretchImagePanel;
BEGIN
	NEW(container);

	p := XMLTransformer.GetNewParagraph("Left");
	NEW(o);
	o.SetName("Object");
	NEW(img, NIL, Strings.NewString("file://BluebottlePic0.png"), -1, -1);
	o.AddContent(img);
	p.AddContent(o);
	container.AddContent(p);

	RETURN container;
END PICT;

BEGIN
	newLine[0] := 0DX; newLine[1] := 0AX; newLine[2] := 0X;
END TestXMLPlugins.

XMLTransformer.Register A TestXMLPlugins.A ~
XMLTransformer.Register AB TestXMLPlugins.AB ~
XMLTransformer.Register B TestXMLPlugins.B ~
XMLTransformer.Register PICT TestXMLPlugins.PICT ~

Example-HTML-File:

<html>
<body background="paper.gif">

<h1>XML-Transfomer-Demo</h1>

<h2>The BB:A tag</h2>
<BB:A />
<hr>

<h2>The BB:B tag</h2>
<BB:B />
<hr>

<h2>The BB:PICT tag</h2>
<BB:PICT />
<hr>

<h2>The BB:AB tag when empty</h2>
<BB:AB />
<hr>

<h2>The BB:AB tag when containing a BB:PICT tag</h2>
<BB:AB>
   <BB:PICT />
</BB:AB>
<hr>

</body>
</html>
