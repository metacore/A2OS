MODULE SVG;

IMPORT SVGUtilities, SVGColors, SVGMatrix, XML, CSS2, Strings, Raster, GfxFonts;

CONST
(* Constants that determine the type of some paint attribute *)
	PaintNone* = 0;
	PaintCurrentColor* = 1;
	PaintColor* = 2;
	PaintURI* = 3;
(* Constants that determine the type of some units *)
	UnitsUserSpaceOnUse* = 0;
	UnitsObjectBoundingBox* = 1;
(* Constants that determine if percentage values are allowed *)
	AllowPercentages*=TRUE;
	DisallowPercentages*=FALSE;

TYPE
	Document*=Raster.Image;

	String*=XML.String;

	Number*=SVGMatrix.Number;
	Length*=Number;
	Color*=SVGColors.Color;

	Box*=RECORD
		x*, y*, width*, height*: Length;
	END;

	Coordinate*=SVGMatrix.Point;
	Transform*=SVGMatrix.Matrix;

	Paint*=RECORD
		type*: SHORTINT;
		color*: Color;
		uri*: String;
	END;

	Style*=RECORD
		fill*: Paint;
		stroke*: Paint;
		strokeWidth*: Length;
	END;

	State*=OBJECT
		VAR
			style*: Style;

			target*: Document;

			transparencyUsed*: BOOLEAN;

			viewport*: Box;
			userToWorldSpace*: Transform;

			next: State;

		(* Push a new copy of the states on a stack *)
		PROCEDURE Push*;
		VAR pushed: State;
		BEGIN
			NEW(pushed);

			pushed^ := SELF^;
			next := pushed;
		END Push;

		(* Pop the top state from the stack *)
		PROCEDURE Pop*;
		BEGIN
			SELF^ := next^;
		END Pop;

	END State;

(* Load the default style attributes *)
PROCEDURE InitDefaultStyle*(VAR style: Style);
BEGIN
	style.fill.type := PaintColor;
	style.fill.color := SVGColors.Black;
	style.stroke.type := PaintNone;
	style.strokeWidth := 1;
END InitDefaultStyle;

(* Parse a number at the specified position in the string *)
PROCEDURE ParseNumber2(value: String; VAR number: Number; percentageAllowed: BOOLEAN; percent100: Length; VAR i: SIZE; VAR unitStr: String);
BEGIN
	SVGUtilities.StrToFloatPos(value^, number, i);
	unitStr := Strings.Substring2(i, value^);
	IF unitStr^ = '%' THEN
		IF percentageAllowed THEN
			number := number*percent100/100.0;
		ELSE
			Error("expected number, found percentage: ");
			Error(value^);
		END
	END
END ParseNumber2;

(* Parse a number *)
PROCEDURE ParseNumber*(value: String; VAR number: Number; percentageAllowed: BOOLEAN; percent100: Length);
VAR i: SIZE;
	unitStr: String;
BEGIN
	i := 0;
	ParseNumber2(value, number, percentageAllowed, percent100, i, unitStr);
END ParseNumber;

(* Parse an attribute of type length at the specified position in the string *)
PROCEDURE ParseLength2(value:String; ppi: LONGREAL;  percent100: Length; VAR length: Length; VAR i: SIZE);
VAR
	term: CSS2.Term;
	unit: SHORTINT;
	unitStr: String;
BEGIN
	ParseNumber2(value, length, AllowPercentages, percent100, i, unitStr);
	IF unitStr^ # '%' THEN
		unit := GetTermUnit(unitStr^);
		IF unit # CSS2.Undefined THEN
			term := ChangeToPixel(length);
			term.SetUnit(unit);
			length := GetPixels(term, ppi, GfxFonts.Default)			(* Use DefaultFont for now... *)
		END
	END
END ParseLength2;

(* Parse an attribute of type length *)
PROCEDURE ParseLength*(value:String; ppi: LONGREAL;  percent100: Length; VAR length: Length);
VAR
	i: SIZE;
BEGIN
	i := 0;
	ParseLength2(value,ppi,percent100,length,i)
END ParseLength;

(* Parse one or optionally two attributes of type length *)
PROCEDURE ParseLengthOptional2*(value:String; ppi: LONGREAL;  percent100: Length; VAR length, length2: Length);
VAR
	i: SIZE;
BEGIN
	i := 0;
	ParseLength2(value,ppi,percent100,length,i);
	SVGUtilities.SkipCommaWhiteSpace(i, value);
	IF value[i]=0X THEN
		length2 := length
	ELSE
		ParseLength2(value,ppi,percent100,length2,i)
	END
END ParseLengthOptional2;

(* Parse a coordinate pair *)
PROCEDURE ParseCoordinate*(value: String; VAR i: SIZE;  VAR current: Coordinate; relative: BOOLEAN);
VAR x, y: Length;
BEGIN
	SVGUtilities.SkipCommaWhiteSpace(i, value);
	SVGUtilities.StrToFloatPos(value^, x, i);
	SVGUtilities.SkipCommaWhiteSpace(i, value);
	SVGUtilities.StrToFloatPos(value^, y, i);
	IF relative THEN
		current.x := current.x + x;
		current.y := current.y + y;
	ELSE
		current.x := x;
		current.y := y;
	END
END ParseCoordinate;

(* Parse a single coordinate value *)
PROCEDURE ParseCoordinate1*(value: String; VAR i: SIZE;  VAR current: Length; relative: BOOLEAN);
VAR l: Length;
BEGIN
	SVGUtilities.SkipCommaWhiteSpace(i, value);
	SVGUtilities.StrToFloatPos(value^, l, i);
	IF relative THEN
		current := current + l;
	ELSE
		current := l;
	END
END ParseCoordinate1;

(* Parse a paint style attribute *)
PROCEDURE ParsePaint*(value: String; VAR paint: Paint);
BEGIN
	IF value^ = "none" THEN paint.type := PaintNone
	ELSIF value^ = "currentColor" THEN paint.type := PaintCurrentColor
	ELSIF SVGColors.Parse(value, paint.color)  THEN paint.type := PaintColor
	ELSIF ParseURI(value, paint.uri) THEN paint.type := PaintURI
	ELSE
		Error("expected paint, found :");
		Error(value^);
		paint.type := PaintNone
	END
END ParsePaint;

(* Parse the contents of the xlink:href attribute *)
PROCEDURE ParseURI*(value: String; VAR uri: String):BOOLEAN;
BEGIN
	IF Strings.StartsWith2("url(#", value^) & Strings.EndsWith(")", value^) THEN
		uri := Strings.Substring(5, Strings.Length(value^)-1, value^);
		RETURN TRUE
	ELSIF Strings.StartsWith2("#", value^) THEN
		uri := Strings.Substring2(1, value^);
		RETURN TRUE
	ELSE RETURN FALSE
	END
END ParseURI;

(* Parse the contents of the gradientUnits attribute *)
PROCEDURE ParseUnits*(value: String; VAR units: SHORTINT);
BEGIN
	IF value^ = "userSpaceOnUse" THEN units := UnitsUserSpaceOnUse
	ELSIF value^ = "objectBoundingBox" THEN units := UnitsObjectBoundingBox
	ELSE
		Error("expected userSpaceOnUse or objectBoundingBox, found: ");
		Error(value^)
	END
END ParseUnits;

(* Parse the contents of the fill or stroke attributes *)
PROCEDURE ParseStyle*(style: String; CONST name: ARRAY OF CHAR): String;
VAR i, end: SIZE;
	id: String;
BEGIN
	i := 0;
	SVGUtilities.SkipWhiteSpace(i, style);
	WHILE style[i] # 0X DO
		end:=Strings.IndexOfByte(':', i, style^);
		IF end=-1 THEN RETURN NIL END;
		id := Strings.Substring(i, end, style^);
		i := end+1;
		SVGUtilities.SkipWhiteSpace(i, style);

		end:=Strings.IndexOfByte(';', i, style^);
		IF end=-1 THEN
			IF id^ = name THEN
				RETURN Strings.Substring2(i, style^);
			END;
			RETURN NIL
		END;
		IF id^ = name THEN
			RETURN Strings.Substring(i, end, style^);
		END;
		i := end+1;
		SVGUtilities.SkipWhiteSpace(i, style);
	END;
	RETURN NIL;
END ParseStyle;

(* Parse the contents of the transform and gradientTransform attributes *)
PROCEDURE ParseTransformList*(value: String; VAR transform: Transform);
VAR
	i, len: SIZE;
	a, b, c, d, e, f: Length;
BEGIN
	i := 0;
	len := Strings.Length(value^);
	SVGUtilities.SkipWhiteSpace(i, value);
	WHILE i#len DO
		IF Strings.StartsWith("matrix(", i, value^) THEN
			i := i + 7;
			SVGUtilities.StrToFloatPos(value^, a, i);
			SVGUtilities.SkipCommaWhiteSpace(i, value);
			SVGUtilities.StrToFloatPos(value^, b, i);
			SVGUtilities.SkipCommaWhiteSpace(i, value);
			SVGUtilities.StrToFloatPos(value^, c, i);
			SVGUtilities.SkipCommaWhiteSpace(i, value);
			SVGUtilities.StrToFloatPos(value^, d, i);
			SVGUtilities.SkipCommaWhiteSpace(i, value);
			SVGUtilities.StrToFloatPos(value^, e, i);
			SVGUtilities.SkipCommaWhiteSpace(i, value);
			SVGUtilities.StrToFloatPos(value^, f, i);
			transform := transform.TransformBy(a, b, c, d, e, f)
		ELSIF Strings.StartsWith("translate(", i, value^) THEN
			i := i + 10;
			SVGUtilities.StrToFloatPos(value^, a, i);
			SVGUtilities.SkipCommaWhiteSpace(i, value);
			IF value[i] # ")" THEN SVGUtilities.StrToFloatPos(value^, b, i)
			ELSE b := 0.0 END;
			transform := transform.Translate(a, b)
		ELSIF Strings.StartsWith("scale(", i, value^) THEN
			i := i + 6;
			SVGUtilities.StrToFloatPos(value^, a, i);
			SVGUtilities.SkipCommaWhiteSpace(i, value);
			IF value[i] # ")" THEN SVGUtilities.StrToFloatPos(value^, b, i)
			ELSE b := a END;
			transform := transform.Scale(a, b)
		ELSIF Strings.StartsWith("rotate(", i, value^) THEN
			i := i + 7;
			SVGUtilities.StrToFloatPos(value^, a, i);
			SVGUtilities.SkipCommaWhiteSpace(i, value);
			IF value[i] # ")" THEN
				SVGUtilities.StrToFloatPos(value^, b, i);
				SVGUtilities.SkipCommaWhiteSpace(i, value);
				SVGUtilities.StrToFloatPos(value^, c, i)
			ELSE b := 0.0; c := 0.0 END;
			transform := transform.Rotate(a, b, c)
		ELSIF Strings.StartsWith("skewX(", i, value^) THEN
			i := i + 6;
			SVGUtilities.StrToFloatPos(value^, a, i);
			transform := transform.SkewX(a)
		ELSIF Strings.StartsWith("skewY(", i, value^) THEN
			i := i + 6;
			SVGUtilities.StrToFloatPos(value^, a, i);
			transform := transform.SkewY(a)
		ELSE
			Error("unknown transform command");
			Error(value^);
			RETURN
		END;

		SVGUtilities.SkipWhiteSpace(i, value);
		SVGUtilities.SkipChar(i, value, ')');
		SVGUtilities.SkipCommaWhiteSpace(i,value)
	END
END ParseTransformList;

(* Parse the contents of the viewBoxattribute *)
PROCEDURE ParseViewBox*(value: String; VAR minx, miny, width, height: Length);
VAR i: SIZE;
BEGIN
	i := 0;
	SVGUtilities.SkipWhiteSpace(i, value);
	SVGUtilities.StrToFloatPos(value^, minx, i);
	SVGUtilities.SkipCommaWhiteSpace(i, value);
	SVGUtilities.StrToFloatPos(value^, miny, i);
	SVGUtilities.SkipCommaWhiteSpace(i, value);
	SVGUtilities.StrToFloatPos(value^, width, i);
	SVGUtilities.SkipCommaWhiteSpace(i, value);
	SVGUtilities.StrToFloatPos(value^, height, i);
END ParseViewBox;

(* Parse the contents of the preserveAspectRatio attribute *)
PROCEDURE ParsePreserveAspect*(value: String; VAR xAlign, yAlign: LONGINT; VAR meet: BOOLEAN);
VAR i: SIZE;
BEGIN
	i := 0;

	IF Strings.StartsWith("xMin", i, value^) THEN i := i + 4; xAlign := -1
	ELSIF Strings.StartsWith("xMid", i, value^) THEN i := i + 4; xAlign := 0
	ELSIF Strings.StartsWith("xMax", i, value^) THEN i := i + 4; xAlign := +1
	ELSE
		Error("expected xMin, xMid or xMax, found: ");
		Error(value^);
	END;

	IF Strings.StartsWith("YMin", i, value^) THEN i := i + 4; yAlign := -1
	ELSIF Strings.StartsWith("YMid", i, value^) THEN i := i + 4; yAlign := 0
	ELSIF Strings.StartsWith("YMax", i, value^) THEN i := i + 4; yAlign := +1
	ELSE
		Error("expected yMin, yMid or yMax, found: ");
		Error(value^);
	END;

	SVGUtilities.SkipWhiteSpace(i, value);

	IF Strings.StartsWith("slice", i, value^) THEN
		meet := FALSE
	ELSIF Strings.StartsWith("meet", i, value^) THEN
		meet := TRUE
	ELSIF i=Strings.Length(value^) THEN
		meet := TRUE
	ELSE
		Error("expected meet or slive, found: ");
	END
END ParsePreserveAspect;

(* Create a new, empty SVG.Document *)
PROCEDURE NewDocument*(width, height: Length):Document;
VAR
	doc: Document;
BEGIN
	NEW(doc);
	Raster.Create(doc,ENTIER(width),ENTIER(height),Raster.BGRA8888);
	Raster.Clear(doc);
	RETURN doc;
END NewDocument;

(* The following procedures are forwarded to SVGUtilities for convenience *)
PROCEDURE Log*(CONST msg: ARRAY OF CHAR);
BEGIN
	SVGUtilities.Log(msg)
END Log;

PROCEDURE Warning*(CONST msg: ARRAY OF CHAR);
BEGIN
	SVGUtilities.Warning(msg)
END Warning;

PROCEDURE Error*(CONST msg: ARRAY OF CHAR);
BEGIN
	SVGUtilities.Error(msg)
END Error;

(* The following procedures are defined in, but not exported from the Modules CSS2Properties and CSS2Parser *)
PROCEDURE GetPixels(term: CSS2.Term; ppi: LONGREAL; font: GfxFonts.Font): LONGREAL;
VAR fact, pixels: LONGREAL; x, y, dx, dy: REAL; map: Raster.Image;
BEGIN
	IF (term # NIL) & term.IsLength() THEN
		CASE term.GetUnit() OF
		| CSS2.em: fact := font.ptsize / ppi
		| CSS2.ex: GfxFonts.GetMap(font, 'x', x, y, dx, dy, map); fact := -y / ppi
		| CSS2.px: fact := 1.0 / ppi
		| CSS2.in: fact := 1.0
		| CSS2.cm: fact := 1.0 / 2.54
		| CSS2.mm: fact := 1.0 / 25.4
		| CSS2.pt: fact := 1.0 / 72.0
		| CSS2.pc: fact := 1.0 / 6.0
		END;
		IF term.GetType() = CSS2.IntDimension THEN pixels := term.GetIntVal() * ppi * fact
		ELSIF term.GetType() = CSS2.RealDimension THEN pixels := term.GetRealVal() * ppi * fact
		END
	ELSIF (term # NIL) & (((term.GetType() = CSS2.IntNumber) & (term.GetIntVal() = 0))
			OR ((term.GetType() = CSS2.RealNumber) & (term.GetRealVal() = 0.0))) THEN
		pixels := 0.0
	ELSE
		pixels := 0.0
	END;
	RETURN pixels
END GetPixels;

PROCEDURE ChangeToPixel(pixelVal: LONGREAL): CSS2.Term;
VAR term: CSS2.Term;
BEGIN
	NEW(term); term.SetType(CSS2.RealDimension); term.SetRealVal(pixelVal); term.SetUnit(CSS2.px); RETURN term
END ChangeToPixel;

PROCEDURE GetTermUnit(CONST unitStr: ARRAY OF CHAR): SHORTINT;
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

END SVG.
