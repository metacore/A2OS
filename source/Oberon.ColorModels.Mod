(* ETH Oberon, Copyright 2001 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

MODULE ColorModels IN Oberon;	(** portable *)	(** by W. Ibl *)

IMPORT Display, Objects, Texts, Oberon, Strings;

CONST
	RGBtop = 255;	(* current RGB value maximum *)
TYPE
	(* a color symbol contains the color description *)
	ColorSym = POINTER TO ColorSymDesc;
	ColorSymDesc = RECORD
		name: Objects.Name;	(* color name *)
		x,y,z: FLOAT32;	(* color parameters, RGB, HSV or CMY *)
		next: ColorSym;	(* next color symbol *)
	END;
VAR
	RGBcolor,HSVcolor,CMYcolor: ColorSym;	(* supported color symbols *)
	depth: SIGNED16;	(* current color depth *)
	dr,dg,db: ARRAY RGBtop+1 OF SIGNED16;	(* current color tables *)

PROCEDURE LoadPalette(VAR d: SIGNED16; VAR r,g,b: ARRAY OF SIGNED16);
	(* scan the currently loaded RGB values of the palette *)
VAR
	i: SIGNED16;
BEGIN
	d:= SIGNED16(ASH(1,Display.Depth(0))-1);
	FOR i:= 0 TO d DO Display.GetColor(i,dr[i],dg[i],db[i]); END;
END LoadPalette;

PROCEDURE LoadColorSymbols(VAR sym: ColorSym; model: ARRAY OF CHAR);
	(* Parse Oberon.Text for color names. The chapter is "ColorSystem", model
	specifies the section *)
VAR
	system: Objects.Name;
	col,last: ColorSym;
	S: Texts.Scanner;
	x,y,z: FLOAT32;
BEGIN
	sym:= NIL; last:= NIL;
	COPY("ColorSystem.", system); Strings.Append(system,model);
	Oberon.OpenScanner(S,system);
	IF (S.class # Texts.Inval) THEN
		WHILE ~S.eot & (S.class IN {Texts.Name, Texts.String}) DO
			NEW(col); COPY(S.s, col.name); Texts.Scan(S);
			IF (S.class = Texts.Char) & (S.c = "=") THEN Texts.Scan(S) END;
			IF (S.class = Texts.Char) & (S.c = "{") THEN Texts.Scan(S) END;
			IF S.class = Texts.Real THEN x := S.x; Texts.Scan(S) END;
			IF S.class = Texts.Real THEN y := S.x; Texts.Scan(S) END;
			IF S.class = Texts.Real THEN z := S.x; Texts.Scan(S) END;
			IF (S.class = Texts.Char) & (S.c = "}") THEN Texts.Scan(S) END;
			col.x := x; col.y := y; col.z := z; col.next := NIL;
			IF last = NIL THEN sym:= col ELSE last.next:= col END;
			last := col
		END
	END
END LoadColorSymbols;

PROCEDURE FindColorSymbol(sym: ColorSym; s: ARRAY OF CHAR): ColorSym;
	(* find the colorsymbol s in the symbol list sym, returns NIL if not found *)
BEGIN
	WHILE (sym # NIL) & ~Strings.CAPCompare(sym.name,s) DO sym:= sym.next; END;
	RETURN(sym);
END FindColorSymbol;

(** Searches in ColorSymbols.RGB of Oberon.Text for color S and returns the associated RGB values.
ok is set to TRUE if S has been found and to FALSE otherwise. r, g and b are left unchanged if ok is FALSE. *)
PROCEDURE StrToRGB*(S: ARRAY OF CHAR; VAR r,g,b: FLOAT32; VAR ok: BOOLEAN);
VAR
	sym: ColorSym;
BEGIN
	IF (RGBcolor = NIL) THEN LoadColorSymbols(RGBcolor,"RGB"); END;
	sym:= FindColorSymbol(RGBcolor,S);
	ok:= (sym # NIL);
	IF ok THEN r:= sym.x; g:= sym.y; b:= sym.z; END;
END StrToRGB;

(** Searches in ColorSymbols.HSV of Oberon.Text for color S and returns the associated HSV values.
ok is set to TRUE if S has been found and to FALSE otherwise. h, s and v are left unchanged if ok is FALSE. *)
PROCEDURE StrToHSV*(S: ARRAY OF CHAR; VAR h,s,v: FLOAT32; VAR ok: BOOLEAN);
VAR
	sym: ColorSym;
BEGIN
	IF (HSVcolor = NIL) THEN LoadColorSymbols(HSVcolor,"HSV"); END;
	sym:= FindColorSymbol(HSVcolor,S);
	ok:= (sym # NIL);
	IF ok THEN h:= sym.x; s:= sym.y; v:= sym.z; END;
END StrToHSV;

(** Searches in ColorSymbols.CMY of Oberon.Text for color S and returns the associated CMY values.
ok is set to TRUE if S has been found and to FALSE otherwise. c, m and y are left unchanged if ok is FALSE. *)
PROCEDURE StrToCMY*(S: ARRAY OF CHAR; VAR c,m,y: FLOAT32; VAR ok: BOOLEAN);
VAR
	sym: ColorSym;
BEGIN
	IF (CMYcolor = NIL) THEN LoadColorSymbols(CMYcolor,"CMY"); END;
	sym:= FindColorSymbol(CMYcolor,S);
	ok:= (sym # NIL);
	IF ok THEN c:= sym.x; m:= sym.y; y:= sym.z; END;
END StrToCMY;

(** convert a RedGreenBlue color specification to HueSaturationValue *)
PROCEDURE RGBToHSV*(r,g,b: FLOAT32; VAR h,s,v: FLOAT32);
VAR
	m,rl,gl,bl: FLOAT32;
BEGIN
	IF (g > b) THEN	(* set v *)
		IF (r > g) THEN v:= r; ELSE v:= g; END;
	ELSE
		IF (r > b) THEN v:= r; ELSE v:= b; END;
	END;
	IF (g < b) THEN
		IF (r < g) THEN m:= r; ELSE m:= g; END;
	ELSE
		IF (r < b) THEN m:= r; ELSE m:= b; END;
	END;
	IF (v # 0.0) THEN s:= (v - m) / v; ELSE s:= 0.0; END;	(* set s *)
	IF (s # 0.0) THEN
		rl:= (v - r) / (v - m);	(* distance of color from red *)
		gl:= (v - g) / (v - m);	(* distance of color from green *)
		bl:= (v - b) / (v - m);	(* distance of color from blue *)
		IF (v = r) THEN IF (m = g) THEN h:= 5.0 + bl; ELSE h:= 1.0 - gl; END; END;
		IF (v = g) THEN
			IF (m = b) THEN h:= 1.0 + rl; ELSE h:= 3.0 - bl; END;
		ELSIF (m = r) THEN
			h:= 3.0 + gl;
		ELSE
			h:= 5.0 - rl;
		END;
		h:= h * 60.0;
	ELSE
		h:= 0.0;
	END;
END RGBToHSV;

(** convert a HueSaturationValue color specification to RedGreenBlue *)
PROCEDURE HSVToRGB*(h,s,v: FLOAT32; VAR r,g,b: FLOAT32);
VAR
	i: SIGNED32;
	f,p1,p2,p3: FLOAT32;
BEGIN
	IF h = 360.0 THEN h:= 0.0; ELSE h:= h / 60.0; END;	(* convert h to be in [0,6] *)
	i:= ENTIER(h); f:= h - i;
	p1:= v * (1.0 - s); p2:= v * (1.0 - (s * f)); p3:= v * (1.0 - (s * (1.0 - f)));
	CASE i OF
	|	0: r:= v; g:= p3; b:= p1;
	|	1: r:= p2; g:= v; b:= p1;
	|	2: r:= p1; g:= v; b:= p3;
	|	3: r:= p1; g:= p2; b:= v;
	|	4: r:= p3; g:= p1; b:= v;
	|	5: r:= v; g:= p1; b:= p2;
	END;
END HSVToRGB;

(** convert a RedGreenBlue color specification to CyanMagentaYellow *)
PROCEDURE RGBToCMY*(r,g,b: FLOAT32; VAR c,m,y: FLOAT32);
BEGIN
	c:= 1.0 - r; m:= 1.0 - g; y:= 1.0 - b;
END RGBToCMY;

(** convert a CyanMagentaYellow color specification to RedGreenBlue *)
PROCEDURE CMYToRGB*(c,m,y: FLOAT32; VAR r,g,b: FLOAT32);
BEGIN
	r:= 1.0 - c; g:= 1.0 - m; b:= 1.0 - y;
END CMYToRGB;

(** transform a RedGreenBlue color specification to Display values,
no color transformation is done. *)
PROCEDURE RGBToColor*(r,g,b: FLOAT32; VAR R,G,B: SIGNED16);
BEGIN
	R:= SHORT(ENTIER(r * RGBtop));
	G:= SHORT(ENTIER(g * RGBtop));
	B:= SHORT(ENTIER(b * RGBtop));
END RGBToColor;

(** transform a RedGreenBlue color specification to a Display value, which is currently part of the palette.
Color transformation is performed by using the euclidic distance.
If scanpal is TRUE, the currently active palette is rescanned, otherwise the latest loaded values are used.
With C the index of the best fitting palette entry is returned, R,G and B hold the RGB values of C *)
PROCEDURE RGBToPalette*(r,g,b: FLOAT32; VAR C,R,G,B: SIGNED16; scanpal: BOOLEAN);
VAR
	i: SIGNED16;
	d,m,x,y,z: FLOAT32;
BEGIN
	C:= -1; R:= -1; G:= -1; B:= -1; m:= MAX(FLOAT32);
	IF scanpal OR (depth = -1) THEN LoadPalette(depth,dr,dg,db); END;
	FOR i:= 0 TO depth DO
		x:= ABS(r - (dr[i]/RGBtop)); y:= ABS(g - (dg[i]/RGBtop)); z:= ABS(b - (db[i]/RGBtop));
		d:= x;
		IF (y > d) THEN d:= y; END;
		IF (z > d) THEN d:= z; END;
		d:= d*d + (x*x + y*y + z*z);
		IF (d < m) THEN m:= d; C:= i; END;
	END;
	IF (C # -1) THEN R:= dr[C]; G:= dg[C]; B:= db[C]; END;
END RGBToPalette;

BEGIN
	RGBcolor:= NIL; HSVcolor:= NIL; CMYcolor:= NIL; depth:= -1;
END ColorModels.
