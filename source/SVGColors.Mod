MODULE SVGColors;

IMPORT Strings, SVGUtilities, Raster;

(* Constants defining colors in the format 0RRGGBBAAH *)
CONST
	Aliceblue*				= SIGNED32(0F0F8FFFFH);
	Antiquewhite*			= SIGNED32(0FAEBD7FFH);
	Aqua*					= 000FFFFFFH;
	Aquamarine*			= 07FFFD4FFH;
	Azure*					= SIGNED32(0F0FFFFFFH);
	Beige*					= SIGNED32(0F5F5DCFFH);
	Bisque*					= SIGNED32(0FFE4C4FFH);
	Black*					= 0000000FFH;
	Blanchedalmond*		= SIGNED32(0FFEBCDFFH);
	Blue*					= 00000FFFFH;
	Blueviolet*				= SIGNED32(08A2BE2FFH);
	Brown*					= SIGNED32(0A52A2AFFH);
	Burlywood*				= SIGNED32(0DEB887FFH);
	Cadetblue*				= 05F9EA0FFH;
	Chartreuse*				= 07FFF00FFH;
	Chocolate*				= SIGNED32(0D2691EFFH);
	Coral*					= SIGNED32(0FF7F50FFH);
	Cornflowerblue*		= 06495EDFFH;
	Cornsilk*				= SIGNED32(0FFF8DCFFH);
	Crimson*				= SIGNED32(0DC143CFFH);
	Cyan*					= 000FFFFFFH;
	Darkblue*				= 000008BFFH;
	Darkcyan*				= 0008B8BFFH;
	Darkgoldenrod*			= 0008B8BFFH;
	Darkgray*				= SIGNED32(0A9A9A9FFH);
	Darkgreen*				= 0006400FFH;
	Darkgrey*				= SIGNED32(0A9A9A9FFH);
	Darkkhaki*				= SIGNED32(0BDB76BFFH);
	Darkmagenta*			= SIGNED32(08B008BFFH);
	Darkolivegreen*		= 0556B2FFFH;
	Darkorange*			= SIGNED32(0FF8C00FFH);
	Darkorchid*				= SIGNED32(09932CCFFH);
	Darkred*				= SIGNED32(08B0000FFH);
	Darksalmon*			= SIGNED32(0E9967AFFH);
	Darkseagreen*			= SIGNED32(08FBC8FFFH);
	Darkslateblue*			= 0483D8BFFH;
	Darkslategray*			= 02F4F4FFFH;
	Darkslategrey*			= 02F4F4FFFH;
	Darkturquoise*			= 000CED1FFH;
	Darkviolet*				= SIGNED32(09400D3FFH);
	Deeppink*				= SIGNED32(0FF1493FFH);
	Deepskyblue*			= 000BFFFFFH;
	Dimgray*				= 0696969FFH;
	Dimgrey*				= 0696969FFH;
	Dodgerblue*			= 01E90FFFFH;
	Firebrick*				= SIGNED32(0B22222FFH);
	Floralwhite*			= SIGNED32(0FFFAF0FFH);
	Forestgreen*			= 0228B22FFH;
	Fuchsia*				= SIGNED32(0FF00FFFFH);
	Gainsboro*				= SIGNED32(0DCDCDCFFH);
	Ghostwhite*			= SIGNED32(0F8F8FFFFH);
	Gold*					= SIGNED32(0FFD700FFH);
	Goldenrod*				= SIGNED32(0DAA520FFH);
	Gray*					= SIGNED32(0808080FFH);
	Grey*					= SIGNED32(0808080FFH);
	Green*					= 0008000FFH;
	Greenyellow*			= SIGNED32(0ADFF2FFFH);
	Honeydew*				= SIGNED32(0F0FFF0FFH);
	Hotpink*				= SIGNED32(0FF69B4FFH);
	Indianred*				= SIGNED32(0CD5C5CFFH);
	Indigo*					= 04B0082FFH;
	Ivory*					= SIGNED32(0FFFFF0FFH);
	Khaki*					= SIGNED32(0F0E68CFFH);
	Lavender*				= SIGNED32(0E6E6FAFFH);
	Lavenderblush*			= SIGNED32(0FFF0F5FFH);
	Lawngreen*			= 07CFC00FFH;
	Lemonchiffon*			= SIGNED32(0FFFACDFFH);
	Lightblue*				= SIGNED32(0ADD8E6FFH);
	Lightcoral*				= SIGNED32(0F08080FFH);
	Lightcyan*				= SIGNED32(0E0FFFFFFH);
	Lightgoldenrodyellow*	= SIGNED32(0FAFAD2FFH);
	Lightgray*				= SIGNED32(0D3D3D3FFH);
	Lightgreen*				= SIGNED32(090EE90FFH);
	Lightgrey*				= SIGNED32(0D3D3D3FFH);
	Lightpink*				= SIGNED32(0FFB6C1FFH);
	Lightsalmon*			= SIGNED32(0FFA07AFFH);
	Lightseagreen*			= 020B2AAFFH;
	Lightskyblue*			= SIGNED32(087CEFAFFH);
	Lightslategray*			= 0778899FFH;
	Lightslategrey*			= 0778899FFH;
	Lightsteelblue*			= SIGNED32(0B0C4DEFFH);
	Lightyellow*			= SIGNED32(0FFFFE0FFH);
	Lime*					= 000FF00FFH;
	Limegreen*				= 032CD32FFH;
	Linen*					= SIGNED32(0FAF0E6FFH);
	Magenta*				= SIGNED32(0FF00FFFFH);
	Maroon*				= SIGNED32(0800000FFH);
	Mediumaquamarine*	= 066CDAAFFH;
	Mediumblue*			= 00000CDFFH;
	Mediumorchid*			= SIGNED32(0BA55D3FFH);
	Mediumpurple*			= SIGNED32(09370DBFFH);
	Mediumseagreen*		= 03CB371FFH;
	Mediumslateblue*		= 07B68EEFFH;
	Mediumspringgreen*	= 000FA9AFFH;
	Mediumturquoise*		= 048D1CCFFH;
	Mediumvioletred*		= SIGNED32(0C71585FFH);
	Midnightblue*			= 0191970FFH;
	Mintcream*				= SIGNED32(0F5FFFAFFH);
	Mistyrose*				= SIGNED32(0FFE4E1FFH);
	Moccasin*				= SIGNED32(0FFE4B5FFH);
	Navajowhite*			= SIGNED32(0FFDEADFFH);
	Navy*					= 0000080FFH;
	Oldlace*				= SIGNED32(0FDF5E6FFH);
	Olive*					= SIGNED32(0808000FFH);
	Olivedrab*				= 06B8E23FFH;
	Orange*				= SIGNED32(0FFA500FFH);
	Orangered*				= SIGNED32(0FF4500FFH);
	Orchid*					= SIGNED32(0DA70D6FFH);
	Palegoldenrod*			= SIGNED32(0EEE8AAFFH);
	Palegreen*				= SIGNED32(098FB98FFH);
	Paleturquoise*			= SIGNED32(0AFEEEEFFH);
	Palevioletred*			= SIGNED32(0DB7093FFH);
	Papayawhip*			= SIGNED32(0FFEFD5FFH);
	Peachpuff*				= SIGNED32(0FFDAB9FFH);
	Peru*					= SIGNED32(0CD853FFFH);
	Pink*					= SIGNED32(0FFC0CBFFH);
	Plum*					= SIGNED32(0DDA0DDFFH);
	Powderblue*			= SIGNED32(0B0E0E6FFH);
	Purple*					= SIGNED32(0800080FFH);
	Red*					= SIGNED32(0FF0000FFH);
	Rosybrown*				= SIGNED32(0BC8F8FFFH);
	Royalblue*				= 04169E1FFH;
	Saddlebrown*			= SIGNED32(08B4513FFH);
	Salmon*				= SIGNED32(0FA8072FFH);
	Sandybrown*			= SIGNED32(0F4A460FFH);
	Seagreen*				= 02E8B57FFH;
	Seashell*				= SIGNED32(0FFF5EEFFH);
	Sienna*					= SIGNED32(0A0522DFFH);
	Silver*					= SIGNED32(0C0C0C0FFH);
	Skyblue*				= SIGNED32(087CEEBFFH);
	Slateblue*				= 06A5ACDFFH;
	Slategray*				= 0708090FFH;
	Slategrey*				= 0708090FFH;
	Snow*					= SIGNED32(0FFFAFAFFH);
	Springgreen*			= 000FF7FFFH;
	Steelblue*				= 04682B4FFH;
	Tan*					= SIGNED32(0D2B48CFFH);
	Teal*					= 0008080FFH;
	Thistle*					= SIGNED32(0D8BFD8FFH);
	Tomato*				= SIGNED32(0FF6347FFH);
	Turquoise*				= 040E0D0FFH;
	Violet*					= SIGNED32(0EE82EEFFH);
	Wheat*					= SIGNED32(0F5DEB3FFH);
	White*					= SIGNED32(0FFFFFFFFH);
	Whitesmoke*			= SIGNED32(0F5F5F5FFH);
	Yellow*					= SIGNED32(0FFFF00FFH);
	Yellowgreen*			= SIGNED32(09ACD32FFH);

TYPE
	Color*=SIGNED32;
	ColorSum*=ARRAY 4 OF FLOAT64;

(* Parse a color specified by name or value *)
PROCEDURE Parse*(value: Strings.String; VAR color: Color):BOOLEAN;
VAR res: INTEGER; i: SIZE; r, g, b: SIGNED32;
	f: FLOAT64;
BEGIN
	IF value[0]='#' THEN
		value := Strings.Substring2(1,value^);
		Strings.HexStrToInt(value^, color, res);
		IF res # Strings.Ok THEN RETURN FALSE END;
		IF Strings.Length(value^)=3 THEN
			(* Expand #rgb to #rrggbb *)
			r := (color DIV 0100H)  MOD 0100H;
			g := (color DIV 010H) MOD 010H;
			b := color MOD 010H;
			Unsplit(color, r+r*010H, g+g*010H, b+b*010H, 0FFH)
		ELSE
			color := color * 0100H + 0FFH
		END
	ELSIF Strings.StartsWith2("rgb(",value^) THEN
		i := 4;
		IF Strings.IndexOfByte2('%', value^) # -1 THEN
			SVGUtilities.StrToFloatPos(value^, f, i);
			IF value[i]#'%' THEN RETURN FALSE ELSE INC(i) END;
			SVGUtilities.SkipCommaWhiteSpace(i, value);
			r := ENTIER((f*255)/100);

			SVGUtilities.StrToFloatPos(value^, f, i);
			IF value[i]#'%' THEN RETURN FALSE ELSE INC(i) END;
			SVGUtilities.SkipCommaWhiteSpace(i, value);
			g := ENTIER((f*255)/100);

			SVGUtilities.StrToFloatPos(value^, f, i);
			IF value[i]#'%' THEN RETURN FALSE ELSE INC(i) END;
			SVGUtilities.SkipWhiteSpace(i, value);
			b := ENTIER((f*255)/100);
		ELSE
			Strings.StrToIntPos(value^, r, i);
			SVGUtilities.SkipCommaWhiteSpace(i, value);
			Strings.StrToIntPos(value^, g, i);
			SVGUtilities.SkipCommaWhiteSpace(i, value);
			Strings.StrToIntPos(value^, b, i);
			SVGUtilities.SkipWhiteSpace(i, value);
		END;
		IF value[i]#')' THEN
			SVGUtilities.Warning("color starting with rgb( omitted closing )");
			RETURN FALSE
		END;
		Unsplit(color, r, g, b, 0FFH)
	ELSIF value^ = "aliceblue" THEN color := Aliceblue
	ELSIF value^ = "antiquewhite" THEN color := Antiquewhite
	ELSIF value^ = "aqua" THEN color := Aqua
	ELSIF value^ = "aquamarine" THEN color := Aquamarine
	ELSIF value^ = "azure" THEN color := Azure
	ELSIF value^ = "beige" THEN color := Beige
	ELSIF value^ = "bisque" THEN color := Bisque
	ELSIF value^ = "black" THEN color := Black
	ELSIF value^ = "blanchedalmond" THEN color := Blanchedalmond
	ELSIF value^ = "blue" THEN color := Blue
	ELSIF value^ = "blueviolet" THEN color := Blueviolet
	ELSIF value^ = "brown" THEN color := Brown
	ELSIF value^ = "burlywood" THEN color := Burlywood
	ELSIF value^ = "cadetblue" THEN color := Cadetblue
	ELSIF value^ = "chartreuse" THEN color := Chartreuse
	ELSIF value^ = "chocolate" THEN color := Chocolate
	ELSIF value^ = "coral" THEN color := Coral
	ELSIF value^ = "cornflowerblue" THEN color := Cornflowerblue
	ELSIF value^ = "cornsilk" THEN color := Cornsilk
	ELSIF value^ = "crimson" THEN color := Crimson
	ELSIF value^ = "cyan" THEN color := Cyan
	ELSIF value^ = "darkblue" THEN color := Darkblue
	ELSIF value^ = "darkcyan" THEN color := Darkcyan
	ELSIF value^ = "darkgoldenrod" THEN color := Darkgoldenrod
	ELSIF value^ = "darkgray" THEN color := Darkgray
	ELSIF value^ = "darkgreen" THEN color := Darkgreen
	ELSIF value^ = "darkgrey" THEN color := Darkgrey
	ELSIF value^ = "darkkhaki" THEN color := Darkkhaki
	ELSIF value^ = "darkmagenta" THEN color := Darkmagenta
	ELSIF value^ = "darkolivegreen" THEN color := Darkolivegreen
	ELSIF value^ = "darkorange" THEN color := Darkorange
	ELSIF value^ = "darkorchid" THEN color := Darkorchid
	ELSIF value^ = "darkred" THEN color := Darkred
	ELSIF value^ = "darksalmon" THEN color := Darksalmon
	ELSIF value^ = "darkseagreen" THEN color := Darkseagreen
	ELSIF value^ = "darkslateblue" THEN color := Darkslateblue
	ELSIF value^ = "darkslategray" THEN color := Darkslategray
	ELSIF value^ = "darkslategrey" THEN color := Darkslategrey
	ELSIF value^ = "darkturquoise" THEN color := Darkturquoise
	ELSIF value^ = "darkviolet" THEN color := Darkviolet
	ELSIF value^ = "deeppink" THEN color := Deeppink
	ELSIF value^ = "deepskyblue" THEN color := Deepskyblue
	ELSIF value^ = "dimgray" THEN color := Dimgray
	ELSIF value^ = "dimgrey" THEN color := Dimgrey
	ELSIF value^ = "dodgerblue" THEN color := Dodgerblue
	ELSIF value^ = "firebrick" THEN color := Firebrick
	ELSIF value^ = "floralwhite" THEN color := Floralwhite
	ELSIF value^ = "forestgreen" THEN color := Forestgreen
	ELSIF value^ = "fuchsia" THEN color := Fuchsia
	ELSIF value^ = "gainsboro" THEN color := Gainsboro
	ELSIF value^ = "ghostwhite" THEN color := Ghostwhite
	ELSIF value^ = "gold" THEN color := Gold
	ELSIF value^ = "goldenrod" THEN color := Goldenrod
	ELSIF value^ = "gray" THEN color := Gray
	ELSIF value^ = "grey" THEN color := Grey
	ELSIF value^ = "green" THEN color := Green
	ELSIF value^ = "greenyellow" THEN color := Greenyellow
	ELSIF value^ = "honeydew" THEN color := Honeydew
	ELSIF value^ = "hotpink" THEN color := Hotpink
	ELSIF value^ = "indianred" THEN color := Indianred
	ELSIF value^ = "indigo" THEN color := Indigo
	ELSIF value^ = "ivory" THEN color := Ivory
	ELSIF value^ = "khaki" THEN color := Khaki
	ELSIF value^ = "lavender" THEN color := Lavender
	ELSIF value^ = "lavenderblush" THEN color := Lavenderblush
	ELSIF value^ = "lawngreen" THEN color := Lawngreen
	ELSIF value^ = "lemonchiffon" THEN color := Lemonchiffon
	ELSIF value^ = "lightblue" THEN color := Lightblue
	ELSIF value^ = "lightcoral" THEN color := Lightcoral
	ELSIF value^ = "lightcyan" THEN color := Lightcyan
	ELSIF value^ = "lightgoldenrodyellow" THEN color := Lightgoldenrodyellow
	ELSIF value^ = "lightgray" THEN color := Lightgray
	ELSIF value^ = "lightgreen" THEN color := Lightgreen
	ELSIF value^ = "lightgrey" THEN color := Lightgrey
	ELSIF value^ = "lightpink" THEN color := Lightpink
	ELSIF value^ = "lightsalmon" THEN color := Lightsalmon
	ELSIF value^ = "lightseagreen" THEN color := Lightseagreen
	ELSIF value^ = "lightskyblue" THEN color := Lightskyblue
	ELSIF value^ = "lightslategray" THEN color := Lightslategray
	ELSIF value^ = "lightslategrey" THEN color := Lightslategrey
	ELSIF value^ = "lightsteelblue" THEN color := Lightsteelblue
	ELSIF value^ = "lightyellow" THEN color := Lightyellow
	ELSIF value^ = "lime" THEN color := Lime
	ELSIF value^ = "limegreen" THEN color := Limegreen
	ELSIF value^ = "linen" THEN color := Linen
	ELSIF value^ = "magenta" THEN color := Magenta
	ELSIF value^ = "maroon" THEN color := Maroon
	ELSIF value^ = "mediumaquamarine" THEN color := Mediumaquamarine
	ELSIF value^ = "mediumblue" THEN color := Mediumblue
	ELSIF value^ = "mediumorchid" THEN color := Mediumorchid
	ELSIF value^ = "mediumpurple" THEN color := Mediumpurple
	ELSIF value^ = "mediumseagreen" THEN color := Mediumseagreen
	ELSIF value^ = "mediumslateblue" THEN color := Mediumslateblue
	ELSIF value^ = "mediumspringgreen" THEN color := Mediumspringgreen
	ELSIF value^ = "mediumturquoise" THEN color := Mediumturquoise
	ELSIF value^ = "mediumvioletred" THEN color := Mediumvioletred
	ELSIF value^ = "midnightblue" THEN color := Midnightblue
	ELSIF value^ = "mintcream" THEN color := Mintcream
	ELSIF value^ = "mistyrose" THEN color := Mistyrose
	ELSIF value^ = "moccasin" THEN color := Moccasin
	ELSIF value^ = "navajowhite" THEN color := Navajowhite
	ELSIF value^ = "navy" THEN color := Navy
	ELSIF value^ = "oldlace" THEN color := Oldlace
	ELSIF value^ = "olive" THEN color := Olive
	ELSIF value^ = "olivedrab" THEN color := Olivedrab
	ELSIF value^ = "orange" THEN color := Orange
	ELSIF value^ = "orangered" THEN color := Orangered
	ELSIF value^ = "orchid" THEN color := Orchid
	ELSIF value^ = "palegoldenrod" THEN color := Palegoldenrod
	ELSIF value^ = "palegreen" THEN color := Palegreen
	ELSIF value^ = "paleturquoise" THEN color := Paleturquoise
	ELSIF value^ = "palevioletred" THEN color := Palevioletred
	ELSIF value^ = "papayawhip" THEN color := Papayawhip
	ELSIF value^ = "peachpuff" THEN color := Peachpuff
	ELSIF value^ = "peru" THEN color := Peru
	ELSIF value^ = "pink" THEN color := Pink
	ELSIF value^ = "plum" THEN color := Plum
	ELSIF value^ = "powderblue" THEN color := Powderblue
	ELSIF value^ = "purple" THEN color := Purple
	ELSIF value^ = "red" THEN color := Red
	ELSIF value^ = "rosybrown" THEN color := Rosybrown
	ELSIF value^ = "royalblue" THEN color := Royalblue
	ELSIF value^ = "saddlebrown" THEN color := Saddlebrown
	ELSIF value^ = "salmon" THEN color := Salmon
	ELSIF value^ = "sandybrown" THEN color := Sandybrown
	ELSIF value^ = "seagreen" THEN color := Seagreen
	ELSIF value^ = "seashell" THEN color := Seashell
	ELSIF value^ = "sienna" THEN color := Sienna
	ELSIF value^ = "silver" THEN color := Silver
	ELSIF value^ = "skyblue" THEN color := Skyblue
	ELSIF value^ = "slateblue" THEN color := Slateblue
	ELSIF value^ = "slategray" THEN color := Slategray
	ELSIF value^ = "slategrey" THEN color := Slategrey
	ELSIF value^ = "snow" THEN color := Snow
	ELSIF value^ = "springgreen" THEN color := Springgreen
	ELSIF value^ = "steelblue" THEN color := Steelblue
	ELSIF value^ = "tan" THEN color := Tan
	ELSIF value^ = "teal" THEN color := Teal
	ELSIF value^ = "thistle" THEN color := Thistle
	ELSIF value^ = "tomato" THEN color := Tomato
	ELSIF value^ = "turquoise" THEN color := Turquoise
	ELSIF value^ = "violet" THEN color := Violet
	ELSIF value^ = "wheat" THEN color := Wheat
	ELSIF value^ = "white" THEN color := White
	ELSIF value^ = "whitesmoke" THEN color := Whitesmoke
	ELSIF value^ = "yellow" THEN color := Yellow
	ELSIF value^ = "yellowgreen" THEN color := Yellowgreen
	ELSE
		RETURN FALSE
	END;
	RETURN TRUE
END Parse;

(* Split a color into r, g, b and a values *)
PROCEDURE Split*(color: Color; VAR r, g, b, a: SIGNED16);
BEGIN
	r := SHORT((color DIV 01000000H) MOD 0100H);
	g := SHORT((color DIV 010000H) MOD 0100H);
	b := SHORT((color DIV 0100H) MOD 0100H);
	a := SHORT(color MOD 0100H);
END Split;

(* Create a color using r, g, b and a values *)
PROCEDURE Unsplit*(VAR color: Color; r, g, b, a: SIGNED32);
BEGIN
	color := ((r * 0100H + g) * 0100H + b) * 0100H + a
END Unsplit;

(* Blend two pixels and premultiply their alpha values *)
PROCEDURE BlendAndPremultiply*(VAR a,b: Raster.Pixel; t: FLOAT64): Raster.Pixel;
VAR p: Raster.Pixel;
	fa: FLOAT64;
BEGIN
	fa := (ORD(a[3])+(ORD(b[3])-ORD(a[3]))*t) / 255.0;
	p[0] := CHR(ENTIER( fa*(ORD(a[0])+(ORD(b[0])-ORD(a[0]))*t) ));
	p[1] := CHR(ENTIER( fa*(ORD(a[1])+(ORD(b[1])-ORD(a[1]))*t) ));
	p[2] := CHR(ENTIER( fa*(ORD(a[2])+(ORD(b[2])-ORD(a[2]))*t) ));
	p[3] := CHR(ENTIER( fa*255 ));

	RETURN p;
END BlendAndPremultiply;

(* Convert a color to a pixel *)
PROCEDURE ColorToPixel*(c: Color; VAR p: Raster.Pixel);
VAR r,g,b,a: SIGNED16;
BEGIN
	Split(c, r,g,b,a);
	p[0] := CHR(b);
	p[1] := CHR(g);
	p[2] := CHR(r);
	p[3] := CHR(a);
END ColorToPixel;

(* Add the r, g, b and a values of a pixel to a running sum *)
PROCEDURE WeightedAdd*(VAR sum: ColorSum;  w: FLOAT64; pix: Raster.Pixel);
BEGIN
	sum[0] := sum[0] + w*ORD(pix[0]);
	sum[1] := sum[1] + w*ORD(pix[1]);
	sum[2] := sum[2] + w*ORD(pix[2]);
	sum[3] := sum[3] + w*ORD(pix[3]);
END WeightedAdd;

(* Convert a sum of r, g, b and a values to a pixel *)
PROCEDURE ColorSumToPixel*(sum: ColorSum;  VAR pix: Raster.Pixel);
BEGIN
	pix[0] := CHR(ENTIER(sum[0]));
	pix[1] := CHR(ENTIER(sum[1]));
	pix[2] := CHR(ENTIER(sum[2]));
	pix[3] := CHR(ENTIER(sum[3]));
END ColorSumToPixel;

END SVGColors.
