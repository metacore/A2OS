MODULE vyGraphBase IN Oberon;     (*=    fof,gs *)
(* Copyright notice:

This file is part of Voyager
Copyright (C) 1993-2002 Project Voyager, StatLab Heidelberg ; (C) 1993-2002 G. Sawitzki et al.

This library is free software; you can redistribute it and/or
modify it under the terms of the GNU Lesser General Public
License as published by the Free Software Foundation; either
version 2.1 of the License, or (at your option) any later version.

This library is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
Lesser General Public License for more details.

You should have received a copy of the GNU Lesser General Public
License along with this library; if not, write to the Free Software
Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

Copy of the GNU Lesser General Public License can be found in the file COPYING.TXT
Report any problems as soon as possible to voyager@statlab.uni-heidelberg.de
*)


IMPORT Objects, Files, Display, vyBase, Pictures, Display3, Fonts, Oberon, vyHost, vyGraphBase0, Images, Strings;
	(***** Voyager Graphics Abstractions *)

CONST
	UseDBDefaultVal = TRUE;
	(** mode constants **)
	invert* = Display.invert;     	paint* = Display.paint;     	replace* = Display.replace;
	(** Display styles **)
	filled* = Display3.filled;
	display = 0;     print = 1;
	(** hJustification constants , vJustification constants **)
	left* = 0;     	center* = 1;     	right* = 2;
	bottom* = 0;     (* - " - *)	top* = 2;

	StdFnt = "Syntax10.Scn.Fnt";
	correctScreendumpBlack* = (* TRUE; *)FALSE;

	pixel* = 1;     (* fof 980427 for consistency with O/F *)
	xcorrection* = 1;     ycorrection* = 1;      (* for correction of orientation ,  fof 980427 for consistency with O/F , ycoor = -1 O/F *)
	maxNumPoints = 100;

	NAN = MAX(SIGNED16);

TYPE
	doubleBuffer *= vyGraphBase0.doubleBuffer;

	tPatPrinter* = vyGraphBase0.tPatPrinter;
	tSign* = vyGraphBase0.tSign;

	tPalette* = POINTER TO tPaletteDesc;
	tPaletteDesc = RECORD
		red, green, blue: ARRAY 256 OF SIGNED16
	END;

	Style* = RECORD
		fcol*, bcol*: Display.Color   ;   (*! fof: fcol read only ?*)
		mode*: SIGNED16;     (** Display paint mode **)(*! fof: mode read only  ?*)
		style*: SET;     (** Display styles **)(*! fof:  read only ? *)
		pattern*: SIGNED32;     (** Display Patterns **)(*! fof:  read only ? *)
		pensize* : SIGNED16;   (*! fof:  read only *)
		fnt*: ARRAY 64 OF CHAR;
		fillcol*, selectcol*: Display.Color;
		fillpat*, selectpat*: SIGNED32;
		alpha*: SIGNED16
	END;

	CursorMarker* = Oberon.Marker;

	Real* = vyBase.Real;
	Coordinate* = SIGNED16;    	(*= type used for output coordinates *)
	Color* = Display.Color;

	(** 2d: Declarations for real valued 2d graphics *)

	tRegion2d  = POINTER TO tRegion2dDesc;
	tRegion2dDesc  = RECORD
		x  , y , w  , h  : Real;
		prev  : tRegion2d
	END;

	tCoordinate2d* = POINTER TO tCoordinate2dDesc;
	tCoordinate2dDesc  = RECORD
		x0 , y0    : SIGNED16;  			(* internal coordinate shift due to double buffering effects, do not remove *)
		x  , y  , w  , h  : SIGNED16;    			(* screen region *)(*? duplicated in Gadget??*)(*x=x0,y=y0 if no double buffer active or Displays.Display used as double buffer*)
		x2d  , y2d  , w2d  , h2d : Real;    	(* real world region *)
		xFact  , yFact  : Real;
		(* x02d  , y02d  : SIGNED16; *)
		zoomCache  : tRegion2d
	END;
	tPolygon = ARRAY maxNumPoints OF Coordinate;

VAR
	DisplayHeight*, DisplayWidth*: SIGNED16;
	UseDoubleBuffering*: BOOLEAN;
	theCoordinate, screenCoordinate  : tCoordinate2d;

	stdPalette*, bluePalette*, yellowRedBluePalette*, greyPalette*, userPalette*: tPalette;
	mincol*, maxcol*: Display.Color ;     (*! shield from user *)

	selectpat-: Display.Pattern;     (** Pattern used to draw gadgets when in a selected state. **)

	(** Colors *)
	FG*, BG*: Display.Color;     		(** Foreground (black) and background (white) color indexes. *)

	white-, dgrey-, mgrey-, lgrey-, black-, green-, red-, blue-, yellow-: Display.Color;
	cyan-, 	dkred-, 	dkgreen-, 	dkblue-, 	orange-, 	skyblue-, 	dkcyan-: Display.Color;

	bottomC*: SIGNED16;     	(** Bottom shadow color. *)

	textC*: SIGNED16;     	(** Default text color. *)
	textbackC*: SIGNED16;     	(** Default text background. *)

	(* tmp variables for picture enumerator *)

	S-: Style;   (* current style *)
	defaultStyle*: Style;

	pen : RECORD x, y : SIGNED16 END;     	(* pen position in the coordinate *)
	clipping- : BOOLEAN;
	status : SIGNED16;
	(* the print origin (given from TextPrinter.PrintMsg) of the PortElem *)
	stdFnt: ARRAY 32 OF CHAR;
	(* string justification *)
	vStringJustification-, hStringJustification-: SIGNED16;
	vPatJustification-, hPatJustification-: SIGNED16;
	theCursor: CursorMarker;
	Crosshair*, Wheel*, DefPoint*: CursorMarker;
	wheel, defPoint: Display.Pattern;
	Display2Local*, Local2Display*: PROCEDURE (VAR x, y: SIGNED16);
	dbx, dby: SIGNED16;

	(* use Display2Local, Local2Display when drawing to screen *)
	(* use Global2Local, Local2Global when getting Mouse coordinates etc.  *)

PROCEDURE Min (a, b: vyBase.Index): vyBase.Index;
BEGIN
	IF (a < b) THEN RETURN a ELSE RETURN b END
END Min;



PROCEDURE DoSetPalette* (pal: tPalette);
	VAR i: Display.Color;
BEGIN FOR i := mincol TO maxcol DO Display.SetColor (i, pal.red[i], pal.green[i], pal.blue[i]) END
END DoSetPalette;


PROCEDURE SetClippingRoutines;
BEGIN
	vyGraphBase0.SetDisplayPrimitives();
	clipping := TRUE
END SetClippingRoutines;

PROCEDURE SetImageRoutines;
BEGIN
	vyGraphBase0.SetImagePrimitives();
	clipping := TRUE
END SetImageRoutines;

PROCEDURE SetNonClippingRoutines;
BEGIN
	IF status = display THEN
		clipping := FALSE;
		vyGraphBase0.clipMask := NIL
	END
END SetNonClippingRoutines;

(*** printing *)
PROCEDURE OpenPrinter* (x, y, px, py: SIGNED16);
BEGIN
	Local2Global0(x, y);
	vyGraphBase0.OpenPrinter(x, y, px, py);
	status := print
END OpenPrinter;

PROCEDURE ClosePrinter*;
BEGIN
	vyGraphBase0.ClosePrinter();
	status := display
END ClosePrinter;

PROCEDURE UseClipMask* (mask: Display3.Mask);
	(*!
	programming for  VOYAGER this procedure UseClipMask is intended for vyPort  O N L Y !!
	it had to be inserted due to update mechanism of ports, which are gadgets themselves.
	N E V E R use this procedure, when you are programming in the Voyager framework.
	Operating system specific procedure for System3 ,fof 15.3.96.
	*)
BEGIN vyGraphBase0.clipMask := mask   END UseClipMask;

PROCEDURE GetMask* (): Display3.Mask;
BEGIN RETURN vyGraphBase0.clipMask END GetMask;

PROCEDURE GetClipRect* (VAR x, y, w, h: SIGNED16);
BEGIN
	x := vyGraphBase0.clipMask.X;     y := vyGraphBase0.clipMask.Y;     w := vyGraphBase0.clipMask.W;     h := vyGraphBase0.clipMask.H;
	Global2Local0(x, y)
END GetClipRect;

PROCEDURE EmptyIntersection* (x, y, w, h, X, Y, W, H: SIGNED16): BOOLEAN;

PROCEDURE GiveRegularRect (VAR x, y, w, h: SIGNED16);
BEGIN IF w < 0 THEN x := x + w;     w := - w END;
	IF h < 0 THEN y := y + h;     h := - h END
END GiveRegularRect;

BEGIN GiveRegularRect (x, y, w, h);     GiveRegularRect (X, Y, W, H);
	RETURN (x > X + W) OR (X > x + w) OR (y > Y + H) OR (Y > y + h)
END EmptyIntersection;

PROCEDURE ClipCheck* (x, y, w, h: SIGNED16): BOOLEAN;
	VAR clipCheck : BOOLEAN;
BEGIN
	clipCheck := TRUE;
	IF vyGraphBase0.clipMask = NIL THEN x := 0;     y := 0;     w := Display.Width;     h := Display.Height END;
	IF Display3.Visible(vyGraphBase0.clipMask, x, y, w, h) THEN SetNonClippingRoutines
	ELSE
		IF EmptyIntersection (x, y, w, h, vyGraphBase0.clipMask.X, vyGraphBase0.clipMask.Y, vyGraphBase0.clipMask.W, vyGraphBase0.clipMask.H) THEN
			clipCheck := FALSE
		ELSE  IF ~clipping THEN SetClippingRoutines END
		END
	END;
	RETURN clipCheck
END ClipCheck;

PROCEDURE CorrectCol (col:  Display.Color): Display.Color;
BEGIN
	IF correctScreendumpBlack & (col = 15) THEN RETURN 255 END;
	RETURN col
END CorrectCol;

PROCEDURE InvertCorrectCol (col:  Display.Color): Display.Color;
BEGIN
	IF correctScreendumpBlack  & (col = 255) THEN RETURN 15 END;
	RETURN col
END InvertCorrectCol;

(*** control of display variables  *)
PROCEDURE SetStyle* (s: Style);
BEGIN S := s;     S.fcol := CorrectCol (S.fcol);     S.bcol := CorrectCol(S.bcol);
	vyGraphBase0.SetAlpha(S.alpha);
	vyGraphBase0.SetBackColor(S.bcol);
	vyGraphBase0.SetForeColor(S.fcol);
	vyGraphBase0.SetPenSize(S.pensize);
	vyGraphBase0.SetDisplayStyle(S.style);
	vyGraphBase0.SetFont(S.fnt);
	vyGraphBase0.SetDisplayPattern(S.pattern)
END SetStyle;

PROCEDURE GetStyle* (VAR s: Style);
BEGIN s := S END GetStyle;

PROCEDURE HandleStyleAttributes* (VAR s: Style;     VAR M: Objects.AttrMsg);
BEGIN
	IF M.id = Objects.get THEN
		IF M.name = "fcol"THEN M.class := Objects.Int;     M.i := s.fcol;     M.res := 0
		ELSIF M.name = "bcol"THEN M.class := Objects.Int;     M.i := s.bcol;     M.res := 0
		ELSIF M.name = "mode"THEN M.class := Objects.Int;     M.i := s.mode;     M.res := 0
			(*ELSIF M.name="style" THEN M.class:=Objects.Int; M.i:=s.style; M.res:=0*)
		ELSIF M.name = "pattern"THEN M.class := Objects.Int;     M.i := s.pattern;     M.res := 0
		ELSIF M.name = "pensize"THEN M.class := Objects.Int;     M.i := s.pensize;     M.res := 0
		ELSIF M.name = "alpha"THEN M.class := Objects.Int;     M.i := s.alpha;  M.res := 0
		ELSIF M.name = "style"THEN M.class := Objects.String;  Strings.SetToStr(s.style, M.s);  M.res := 0
		ELSIF M.name = "fnt"THEN M.class := Objects.String;  COPY(s.fnt, M.s);  M.res := 0
		ELSIF M.name = "fillcol"THEN M.class := Objects.Int;     M.i := s.fillcol;     M.res := 0
		ELSIF M.name = "selectcol"THEN M.class := Objects.Int;     M.i := s.selectcol;  M.res := 0
		ELSIF M.name = "fillpat"THEN M.class := Objects.Int;     M.i := s.fillpat;     M.res := 0
		ELSIF M.name = "selectpat"THEN M.class := Objects.Int;     M.i := s.selectpat;     M.res := 0
		END
	ELSIF M.id = Objects.set THEN
		IF (M.name = "fcol") & (M.class = Objects.Int )THEN  s.fcol := SHORT(M.i);     M.res := 0
		ELSIF (M.name = "bcol") & (M.class = Objects.Int) THEN s.bcol := SHORT(M.i);     M.res := 0
		ELSIF (M.name = "mode") & (M.class = Objects.Int) THEN s.mode := SHORT(M.i);     M.res := 0
			(*ELSIF M.name="style" THEN M.class:=Objects.Int; M.i:=s.style; M.res:=0*)
		ELSIF (M.name = "pattern") & (M.class = Objects.Int) THEN s.pattern := M.i;     M.res := 0
		ELSIF (M.name = "pensize") & (M.class = Objects.Int) THEN s.pensize := SHORT( M.i);     M.res := 0
		ELSIF (M.name = "alpha") & (M.class = Objects.Int) THEN s.alpha := SHORT( M.i);     M.res := 0
		ELSIF (M.name = "style") & ( M.class = Objects.String) THEN  Strings.StrToSet(M.s, s.style);  M.res := 0
		ELSIF (M.name = "fnt") & (  M.class = Objects.String) THEN COPY(M.s, s.fnt);  M.res := 0
		ELSIF (M.name = "fillcol") &  ( M.class = Objects.Int) THEN    s.fillcol :=  M.i;     M.res := 0
		ELSIF (M.name = "selectcol") &  ( M.class = Objects.Int) THEN s.selectcol :=  M.i;  M.res := 0
		ELSIF (M.name = "fillpat") & (M.class = Objects.Int) THEN     s.fillpat := M.i;     M.res := 0
		ELSIF (M.name = "selectpat") & ( M.class = Objects.Int) THEN   s.selectpat := M.i;   M.res := 0
		END

	ELSIF M.id = Objects.enum THEN
		M.Enum("fcol");     M.Enum("bcol");   M.Enum("alpha");
		M.Enum("mode");    M.Enum("style");
		M.Enum("pattern");
		M.Enum("pensize");
		M.Enum("fnt");
		M.Enum("fillcol");    M.Enum("selectcol");
		M.Enum("fillpat");     M.Enum("selectpat")
	END
END HandleStyleAttributes;

PROCEDURE WriteStyle* (VAR R: Files.Rider;    VAR (* IN *)s: Style);
PROCEDURE PatToId (pat: SIGNED32): SIGNED16;
BEGIN
	IF pat = Display.solid THEN RETURN(1)
	ELSIF pat = Display.grey0 THEN RETURN(2)
	ELSIF pat = Display.grey1 THEN RETURN(3)
	ELSIF pat = Display.grey2 THEN RETURN(4)
	ELSIF pat = Display.ticks THEN RETURN(5)
	ELSIF pat = Display.hook THEN RETURN(6)
	ELSIF pat = Display.star THEN RETURN(7)
	ELSIF pat = Display.cross THEN RETURN(8)
	END
END PatToId;

BEGIN
	Files.WriteLInt(R, s.fcol);    Files.WriteLInt(R, s.bcol);
	Files.WriteInt(R, s.mode);
	Files.WriteSet(R, s.style);
	(*Files.WriteLInt(R, s.pattern);*)Files.WriteInt(R, PatToId(s.pattern));
	Files.WriteInt(R, s.pensize);
	Files.WriteString(R, s.fnt);
	Files.WriteLInt(R, s.fillcol);    Files.WriteLInt(R, s.selectcol);
	(*Files.WriteLInt(R, s.fillpat); Files.WriteLInt(R, s.selectpat)*)
	Files.WriteInt(R, PatToId(s.fillpat));
	Files.WriteInt(R, - 1);   (* hack to get version management *)
	Files.WriteInt(R, PatToId(s.selectpat));
	Files.WriteInt(R, s.alpha)
END WriteStyle;
PROCEDURE ReadStyle* (VAR R: Files.Rider;    VAR (* OUT *)s: Style);
	VAR i: SIGNED16;
PROCEDURE IdToPat (id: SIGNED16): Display.Pattern;
BEGIN
	CASE id OF
		0: RETURN Display.solid
	|1: RETURN Display.solid
	|2: RETURN Display.grey0
	|3: RETURN  Display.grey1
	|4: RETURN Display.grey2
	|5: RETURN Display.ticks
	|6: RETURN Display.hook
	|7: RETURN Display.star
	|8: RETURN Display.cross
	END
END IdToPat;

BEGIN
	s := defaultStyle;  (* fof 0103xx *)
	Files.ReadLInt(R, s.fcol);    Files.ReadLInt(R, s.bcol);
	Files.ReadInt(R, s.mode);
	Files.ReadSet(R, s.style);
	(*Files.ReadLInt(R, s.pattern);*)Files.ReadInt(R, i);    s.pattern := IdToPat(i);
	Files.ReadInt(R, s.pensize);
	Files.ReadString(R, s.fnt);
	Files.ReadLInt(R, s.fillcol);    Files.ReadLInt(R, s.selectcol);
	(*Files.ReadLInt(R, s.fillpat); Files.ReadLInt(R, s.selectpat)*)
	Files.ReadInt(R, i);    s.fillpat := IdToPat(i);   Files.ReadInt(R, i);
	IF i = - 1 THEN
		Files.ReadInt(R, i);
		s.selectpat := IdToPat(i);
		Files.ReadInt(R, s.alpha)
	ELSE
		s.selectpat := IdToPat(i)
	END
END ReadStyle;

(* Set procedures at this position for easier handling, takes effect on Global variables in vyGraphBase0 !! *)

PROCEDURE SetBackColor* (col: Display.Color);
BEGIN	 S.bcol := CorrectCol(col)  ;  vyGraphBase0.SetBackColor(col) END SetBackColor;
PROCEDURE GetBackColor* (VAR col: Display.Color);
BEGIN	col := InvertCorrectCol(S.bcol)   	END GetBackColor;
PROCEDURE SetForeColor* (col: Display.Color);
BEGIN	  S.fcol := CorrectCol(col);  vyGraphBase0.SetForeColor(col)   END SetForeColor;
PROCEDURE SetFColRGBA* (r, g, b, a: SIGNED16);
BEGIN vyGraphBase0.SetFColRGBA(r, g, b, a);  S.fcol := vyGraphBase0.contextfcol  END SetFColRGBA;
PROCEDURE SetBColRGBA* (r, g, b, a: SIGNED16);
BEGIN vyGraphBase0.SetBColRGBA(r, g, b, a);  S.fcol := vyGraphBase0.contextbcol  END SetBColRGBA;
PROCEDURE GetFColRGBA* (VAR r, g, b, a: SIGNED16);
BEGIN Images.GetRGBA(vyGraphBase0.contextfpix, r, g, b, a) END GetFColRGBA;
PROCEDURE GetBColRGBA* (VAR r, g, b, a: SIGNED16);
BEGIN Images.GetRGBA(vyGraphBase0.contextbpix, r, g, b, a) END GetBColRGBA;
PROCEDURE GetForeColor* (VAR col: Display.Color);
BEGIN	col := InvertCorrectCol(S.fcol) END GetForeColor;
PROCEDURE SetPenSize* (size : SIGNED16);     (*! remove penSize !! *)
BEGIN	S.pensize := size  ;  vyGraphBase0.SetPenSize(size)	END SetPenSize;
PROCEDURE GetPenSize* (VAR size : SIGNED16);
BEGIN	size := S.pensize  	END GetPenSize;
PROCEDURE SetDisplayMode* (m: SIGNED16);
BEGIN	S.mode := m  ;  vyGraphBase0.SetDisplayMode(m)	END SetDisplayMode;
PROCEDURE GetDisplayMode* (VAR m: SIGNED16);
BEGIN	m := S.mode  	END GetDisplayMode;
PROCEDURE SetDisplayStyle* (s: SET);
BEGIN	S.style := s   ;  vyGraphBase0.SetDisplayStyle(s) 	END SetDisplayStyle;
PROCEDURE GetDisplayStyle* (VAR s: SET);
BEGIN	s := S.style  	END GetDisplayStyle;
PROCEDURE SetDisplayPattern* (p: SIGNED32);
BEGIN	S.pattern := p  ;  vyGraphBase0.SetDisplayPattern(p)	END SetDisplayPattern;
PROCEDURE GetDisplayPattern* (VAR p: SIGNED32);
BEGIN	p := S.pattern  	END GetDisplayPattern;
PROCEDURE SetFont* (fnt: ARRAY OF CHAR);
BEGIN	COPY(fnt, S.fnt)  ;  vyGraphBase0.SetFont(fnt)	END SetFont;
PROCEDURE SetAlpha* (a: SIGNED16);
BEGIN	vyGraphBase0.SetAlpha(a)	END SetAlpha;


(*
PROCEDURE FillPattern* ( col:  Display.Color;    pat: Display.Pattern;    pX, pY, X, Y, W, H, mode: SIGNED16);
BEGIN Display3.FillPattern(vyGraphBase0.clipMask, col, pat, pX, pY, X, Y, W, H, mode)
END FillPattern;
(*! fof 010123: FillPattern never used in Voyager and ants, removed *)
(* das führt zu Missverständnissen: FillPattern arbeitet nur auf Display3, so nicht einsetzbar ! *)
*)

PROCEDURE MoveTo* (x, y: SIGNED16);
BEGIN pen.x := x;     pen.y := y END MoveTo;

PROCEDURE MoveTo2d* (x2d, y2d: Real);
	VAR x, y: Coordinate;
BEGIN
	Point2dToPoint (x2d, y2d, x, y);    MoveTo (x, y)
END MoveTo2d;

PROCEDURE Line* (x0, y0, x1, y1: SIGNED16);
BEGIN
	pen.x := x1;     pen.y := y1;   Local2Global0(x0, y0);   Local2Global0(x1, y1);
	(* if line is straight, replace by ReplConst, much faster *)
	vyGraphBase0.line ( x0, y0, x1, y1)
END Line;

PROCEDURE Line2d* (x2d0, y2d0, x2d1, y2d1: Real);
	VAR x0, y0, x1, y1: Coordinate;
BEGIN
	Point2dToPoint (x2d0, y2d0, x0, y0);
	Point2dToPoint (x2d1, y2d1, x1, y1);
	Line (x0, y0, x1, y1)
END Line2d;

PROCEDURE LineTo* (x, y: SIGNED16);
BEGIN Line (pen.x, pen.y, x, y);     pen.x := x;     pen.y := y END LineTo;

PROCEDURE LineTo2d* (x2d, y2d: Real);
	VAR x, y: Coordinate;
BEGIN
	Point2dToPoint (x2d, y2d, x, y);    LineTo (x, y)
END LineTo2d;

PROCEDURE GiveRegularRect (VAR x, y, w, h: SIGNED16);
BEGIN
	IF w <= 0 THEN x := x + w;     w := - w END;
	IF h <= 0 THEN y := y + h;     h := - h END
END GiveRegularRect;

PROCEDURE FrameRect* (x, y, w, h: SIGNED16);
BEGIN Local2Global0(x, y);
	GiveRegularRect(x, y, w, h);       vyGraphBase0.rect( x, y, w, h)
END FrameRect;

PROCEDURE FrameRect2d* (x2d, y2d, w2d, h2d: Real);
	VAR x, y, w, h: Coordinate;
BEGIN
	Rect2dToRect (x2d, y2d, w2d, h2d, x, y, w, h);    FrameRect (x, y, w, h)
END FrameRect2d;

PROCEDURE ShadowRect* (x, y, w, h: SIGNED16);
BEGIN Local2Global0(x, y);
	GiveRegularRect(x, y, w, h);      	vyGraphBase0.rect3d(x, y, w, h)
END ShadowRect;

PROCEDURE PaintRect* (x, y, w, h: SIGNED16);
BEGIN  Local2Global0(x, y);
	GiveRegularRect(x, y, w, h);       vyGraphBase0.paintrect( x, y, w, h)
END PaintRect;

PROCEDURE PaintRect2d* (x2d, y2d, w2d, h2d: Real);
	VAR x, y, w, h: Coordinate;
BEGIN
	Rect2dToRect (x2d, y2d, w2d, h2d, x, y, w, h);    PaintRect (x, y, w, h)
END PaintRect2d;

PROCEDURE EraseRect* (x, y, w, h: SIGNED16);
BEGIN
	IF status = display THEN
		Local2Global0(x, y);
		GiveRegularRect(x, y, w, h);
		vyGraphBase0.SetForeColor(S.bcol);
		vyGraphBase0.replConst ( x, y, w, h);
		vyGraphBase0.SetForeColor(S.fcol)
	END
END EraseRect;

PROCEDURE EraseRect2d* (x2d, y2d, w2d, h2d: Real);
	VAR x, y, w, h: Coordinate;
BEGIN
	Rect2dToRect (x2d, y2d, w2d, h2d, x, y, w, h);    EraseRect (x, y, w, h)
END EraseRect2d;

PROCEDURE InvertRect* (x, y, w, h: SIGNED16);
BEGIN
	IF status = display THEN  Local2Global0(x, y);
		vyGraphBase0.SetDisplayMode(Display.invert);
		vyGraphBase0.SetForeColor(white);
		GiveRegularRect(x, y, w, h);      vyGraphBase0.replConst ( x, y, w, h);
		vyGraphBase0.SetDisplayMode(S.mode);
		vyGraphBase0.SetForeColor(S.fcol)
	END
END InvertRect;

PROCEDURE InvertRect2d* (x2d, y2d, w2d, h2d: Real);
	VAR x, y, w, h: Coordinate;
BEGIN
	Rect2dToRect (x2d, y2d, w2d, h2d, x, y, w, h);    InvertRect (x, y, w, h)
END InvertRect2d;

PROCEDURE FillRect* (x, y, w, h: SIGNED16);
BEGIN  Local2Global0(x, y);
	GiveRegularRect(x, y, w, h);      	vyGraphBase0.paintrect(x, y, w, h)
END FillRect;

PROCEDURE FillRect2d* (x2d, y2d, w2d, h2d: Real);
	VAR x, y, w, h: Coordinate;
BEGIN
	Rect2dToRect (x2d, y2d, w2d, h2d, x, y, w, h);    FillRect (x, y, w, h)
END FillRect2d;

PROCEDURE ReplPict* (pict: Pictures.Picture;     px, py, x, y, w, h: SIGNED16);
BEGIN   Local2Global0(x, y);
	vyGraphBase0.replPict(pict, px, py, x, y, w, h)
END ReplPict;

PROCEDURE Pict* (picture: Pictures.Picture;     x, y, w, h, dx, dy: SIGNED16);
BEGIN  Local2Global0(dx, dy);
	vyGraphBase0.pict(picture, x, y, w, h, dx, dy)
END Pict;

PROCEDURE StretchedPict* (picture: Pictures.Picture;  x, y, w, h, dx, dy, dw, dh: SIGNED16);
BEGIN
	Local2Global0(dx, dy);
	vyGraphBase0.stretchedpict(picture, x, y, w, h, dx, dy, dw, dh)
END StretchedPict;

PROCEDURE Pict2d* (picture: Pictures.Picture;     x, y, w, h: SIGNED16;  dx, dy: Real);
	VAR dxi, dyi: Coordinate;
BEGIN   Point2dToPoint (dx, dy, dxi, dyi);
	Pict(picture, x, y, w, h, dxi, dyi)
END Pict2d;

PROCEDURE StretchedPict2d* (picture: Pictures.Picture;     x, y, w, h: SIGNED16;  dx, dy, dw, dh: Real);
	VAR dxi, dyi, dwi, dhi: Coordinate;
	factx,facty,factw,facth: FLOAT64;
	nx,ny,nw,nh: SIGNED16;
	ndx,ndy,ndw,ndh: FLOAT64;
BEGIN
	factx := (theCoordinate.x2d-dx) / dw;
	facty := (theCoordinate.y2d-dy) / dh;
	factw := (theCoordinate.x2d+theCoordinate.w2d-dx)/dw;
	facth := (theCoordinate.y2d+theCoordinate.h2d-dx)/dh;

	IF (0<=factx) & (factx <=1) THEN (* *)
		nx := x+SHORT(ENTIER(w*factx));
		ndx := dx+ (nx-x)/w * dw;
	ELSE
		nx := x; ndx := dx;
	END;
	IF (0<=facty) & (facty <=1) THEN (* *)
		ny := y+SHORT(ENTIER(h*facty));
		ndy := dy+ (ny-y)/h * dh;
	ELSE
	ny := y; ndy := dy;
	END;
	IF (0<=factw) & (factw <=1) THEN (* *)
		nw := SHORT(ENTIER((x+w)*factw+1))-x;
		ndw := nw/w*dw;
	ELSE
		nw := w; ndw := dw;
	END;
	IF (0<=facth) & (facth <=1) THEN (* *)
		nh := y+SHORT(ENTIER((y+h)*facth+1))-y;
		ndh := nh/h*dh;
	ELSE
		nh := h; ndh := dh;
	END;

	(*
	Rect2dToRect (dx, dy, dw, dh , dxi, dyi, dwi, dhi);
	StretchedPict(picture, x, y, w, h, dxi, dyi, dwi, dhi)
	*)
	(*
	Out.String("Rect2d, showing: ");
	Out.Int(nx,5); Out.String(","); Out.Int(ny,5); Out.String(","); Out.Int(nw,5); Out.String(","); Out.Int(nh,5); Out.Ln;
	Out.LongReal(ndx,10); Out.String(","); Out.LongReal(ndy,10); Out.String(","); Out.LongReal(ndw,10); Out.String(","); Out.LongReal(ndh,10); Out.Ln;
	*)

	Rect2dToRect (ndx, ndy, ndw, ndh , dxi, dyi, dwi, dhi);
	StretchedPict(picture, nx, ny, nw, nh, dxi, dyi, dwi, dhi)

END StretchedPict2d;

PROCEDURE Image* (image: Images.Image;     x, y, w, h, dx, dy: SIGNED16);
BEGIN  Local2Global0(dx, dy);
	vyGraphBase0.image(image, x, y, w, h, dx, dy)
END Image;

PROCEDURE StretchedImage* (image: Images.Image;     x, y, w, h, dx, dy, dw, dh: SIGNED16);
BEGIN Local2Global0(dx, dy);  vyGraphBase0.stretchedimage(image, x, y, w, h, dx, dy, dw, dh)
END StretchedImage;

PROCEDURE StretchedImage2d* (image: Images.Image;     x, y, w, h: SIGNED16;  dx, dy, dw, dh: Real);
	VAR dxi, dyi, dwi, dhi: Coordinate;
BEGIN   Rect2dToRect (dx, dy, dw, dh , dxi, dyi, dwi, dhi);
	StretchedImage(image, x, y, w, h, dxi, dyi, dwi, dhi)
END StretchedImage2d;


PROCEDURE ReplConst* (x, y, w, h: SIGNED16);
BEGIN
	Local2Global0(x, y);
	GiveRegularRect(x, y, w, h);
	vyGraphBase0.replConst (x, y, w, h)
END ReplConst;

PROCEDURE ReplConst2d* (x2d, y2d, w2d, h2d: Real);
	VAR x, y, w, h: Coordinate;
BEGIN
	Rect2dToRect (x2d, y2d, w2d, h2d, x, y, w, h);  ReplConst(x, y, w, h)
END ReplConst2d;

PROCEDURE FitFillArea (VAR x, y: ARRAY OF SIGNED16;     numPoints: SIGNED16);
	VAR  i: SIGNED16;
BEGIN
	FOR i := 0 TO numPoints - 1 DO Local2Global0(x[i], y[i])
	END
END FitFillArea;

PROCEDURE FrameFillArea* (x, y: ARRAY OF SIGNED16;     numPoints: vyHost.Index);
BEGIN 	FitFillArea(x, y, SHORT(numPoints));     vyGraphBase0.poly(x, y, SHORT(numPoints)) END FrameFillArea;

PROCEDURE FrameFillArea2d* (x, y: ARRAY OF Real;    numPoints: vyBase.Index);
	VAR i, end: vyBase.Index;    X, Y: tPolygon;
BEGIN end := Min (numPoints, maxNumPoints);
	FOR i := 0 TO end - 1 DO
	Point2dToPoint (x[i], y[i], X[i], Y[i])  END;
	FrameFillArea (X, Y, numPoints)
END FrameFillArea2d;

PROCEDURE PaintFillArea* (x, y: ARRAY OF SIGNED16;     numPoints: vyHost.Index);
BEGIN FitFillArea(x, y, SHORT(numPoints));
	vyGraphBase0.SetDisplayStyle({Display3.filled});
	vyGraphBase0.poly(x, y, SHORT(numPoints)) ;
	vyGraphBase0.SetDisplayStyle(S.style)

END PaintFillArea;

PROCEDURE PaintFillArea2d* (x, y: ARRAY OF Real;    numPoints: vyBase.Index );
	VAR i, end: vyBase.Index;    X, Y: tPolygon;
BEGIN end := Min (numPoints, maxNumPoints);
	FOR i := 0 TO end - 1 DO
	Point2dToPoint (x[i], y[i], X[i], Y[i])  END;
	PaintFillArea (X, Y, numPoints)
END PaintFillArea2d;

PROCEDURE EraseFillArea* (x, y: ARRAY OF SIGNED16;     numPoints: vyHost.Index);
	VAR col:  Display.Color;     pat: SIGNED32;
BEGIN
	IF status = display THEN
		pat := S.pattern;     S.pattern := Display.solid;
		col := S.fcol;     S.fcol := S.bcol;
		PaintFillArea (x, y, numPoints);
		S.fcol := col ;
		S.pattern := pat
	END
END EraseFillArea;

PROCEDURE EraseFillArea2d* (x, y: ARRAY OF Real;    numPoints: vyBase.Index);
	VAR i, end: vyBase.Index;    X, Y: tPolygon;
BEGIN end := Min (numPoints, maxNumPoints);
	FOR i := 0 TO end - 1 DO Point2dToPoint (x[i], y[i], X[i], Y[i])  END;
	EraseFillArea (X, Y, numPoints)
END EraseFillArea2d;

PROCEDURE InvertFillArea* (x, y: ARRAY OF SIGNED16;     numPoints: vyHost.Index);
	VAR m: SIGNED16;
BEGIN
	IF status = display THEN
		m := S.mode;     S.mode := Display.invert;
		PaintFillArea (x, y, numPoints);
		S.mode := m
	END
END InvertFillArea;

PROCEDURE InvertFillArea2d* (x, y: ARRAY OF Real;    numPoints: vyBase.Index);
	VAR i, end: vyBase.Index;    X, Y: tPolygon;
BEGIN end := Min (numPoints, maxNumPoints);
	FOR i := 0 TO end - 1 DO Point2dToPoint (x[i], y[i], X[i], Y[i])  END;
	InvertFillArea (X, Y, numPoints)
END InvertFillArea2d;

PROCEDURE FrameCircle* (x, y, r: SIGNED16);
BEGIN  Local2Global0(x, y);     	vyGraphBase0.circle ( x, y, r)
END FrameCircle;

PROCEDURE FrameEllipse* (x, y, a, b: SIGNED16);
BEGIN Local2Global0(x, y);     vyGraphBase0.ellipse (x, y, a, b) END FrameEllipse;

PROCEDURE SetStringJustification* (hJust, vJust: SIGNED16);
BEGIN hStringJustification := hJust;     vStringJustification := vJust
END SetStringJustification;

PROCEDURE GetStringSize* (f, s: ARRAY OF CHAR;      VAR w, h, dsr: SIGNED16);
	VAR	fnt: Fonts.Font;
BEGIN
	fnt := Fonts.This (f);
	IF fnt = NIL THEN fnt := Fonts.This(StdFnt) END;
	Display3.StringSize(s, fnt, w, h, dsr)
END GetStringSize;

PROCEDURE GetStringLocation (VAR x, y: SIGNED16;     f, s: ARRAY OF CHAR);
	VAR w, h, dsr: SIGNED16;
BEGIN
	GetStringSize (f, s, w, h, dsr);
	IF hStringJustification = center THEN x := x - (w DIV 2)
	ELSIF hStringJustification = right THEN x := x - w
	END;
	IF vStringJustification = center THEN y := y - (h DIV 2)
	ELSIF vStringJustification = top THEN y := y - h
	END
END GetStringLocation;

PROCEDURE GetStringFrame* (X, Y: SIGNED16;     f, s: ARRAY OF CHAR;     VAR x, y, w, h, dsr: SIGNED16);
BEGIN x := X;     y := Y;
	GetStringLocation (x, y, f, s);     GetStringSize (f, s, w, h, dsr)
END GetStringFrame;

PROCEDURE GetStringFrame2d* (x2d, y2d: Real;    f, s: ARRAY OF CHAR;    VAR x, y, w, h, dsr: Coordinate);
	VAR X, Y :  Coordinate;
BEGIN Point2dToPoint (x2d, y2d, X, Y);    GetStringFrame (X, Y, f, s, x, y, w, h, dsr)
END GetStringFrame2d;

PROCEDURE String* (x, y: SIGNED16;     f, s: ARRAY OF CHAR);
BEGIN   Local2Global0(x, y);
	vyGraphBase0.SetDisplayMode(paint);
	IF (f # "") THEN GetStringLocation (x, y, f, s);     vyGraphBase0.replString (x, y,  f, s)
	ELSE GetStringLocation (x, y, stdFnt, s);     vyGraphBase0.replString (x, y, stdFnt, s) END;
	vyGraphBase0.SetDisplayMode(S.mode)
END String;

PROCEDURE String2d* (x2d, y2d: Real;    f, s: ARRAY OF CHAR);
	VAR x, y : Coordinate;
BEGIN	Point2dToPoint (x2d, y2d, x, y);    String (x, y, f, s)
END String2d;

PROCEDURE EraseString* (x, y: SIGNED16;     f, s: ARRAY OF CHAR);
BEGIN   Local2Global0(x, y);
	vyGraphBase0.SetForeColor(S.bcol);
	IF (f # "") THEN GetStringLocation (x, y, f, s);     vyGraphBase0.replString ( x, y, f, s)
	ELSE GetStringLocation (x, y, stdFnt, s);     vyGraphBase0.replString (x, y, stdFnt, s) END;
	vyGraphBase0.SetForeColor(S.fcol)
END EraseString;

PROCEDURE EraseString2d* (x2d, y2d: Real;    f, s: ARRAY OF CHAR);
	VAR x, y : Coordinate;
BEGIN	Point2dToPoint (x2d, y2d, x, y);    EraseString (x, y, f, s)
END EraseString2d;

PROCEDURE InvertString* (x, y: SIGNED16;     f, s: ARRAY OF CHAR);
BEGIN  Local2Global0(x, y);
	vyGraphBase0.SetDisplayMode(Display.invert);
	vyGraphBase0.SetForeColor(white);
	IF (f # "") THEN GetStringLocation (x, y, f, s);     vyGraphBase0.replString ( x, y, f, s)
	ELSE GetStringLocation (x, y, stdFnt, s);     vyGraphBase0.replString (x, y, stdFnt, s) END;
	vyGraphBase0.SetDisplayMode(S.mode);
	vyGraphBase0.SetForeColor(S.fcol)
END InvertString;

PROCEDURE InvertString2d* (x2d, y2d: Real;    f, s: ARRAY OF CHAR);
	VAR x, y : Coordinate;
BEGIN	Point2dToPoint (x2d, y2d, x, y);    InvertString (x, y, f, s)
END InvertString2d;

PROCEDURE Justify (VAR x, y: SIGNED16;     sgn: tSign);
BEGIN
	IF hPatJustification = center THEN x := x - sgn.wDIV2
	ELSIF hPatJustification = right THEN x := x - sgn.w
	END;
	IF vPatJustification = center THEN y := y - sgn.hDIV2
	ELSIF vPatJustification = top THEN y := y - sgn.h
	END
END Justify;

PROCEDURE PaintPat* (x, y: SIGNED16;     sgn: tSign);
BEGIN  Local2Global0(x, y);   	Justify (x, y, sgn);     vyGraphBase0.copyPattern (sgn, x, y)
END PaintPat;

PROCEDURE PaintPat2d* (x2d, y2d: Real;    sgn: tSign);
	VAR x, y : Coordinate;
BEGIN	Point2dToPoint (x2d, y2d, x, y);
PaintPat (x, y, sgn)  END PaintPat2d;

(*
PROCEDURE PaintColPat* (x, y:SIGNED16;   col:  Display.Color;    sgn: tSign);
BEGIN  Local2Global0(x,y);
Justify (x, y, sgn);    vyGraphBase0.copyPattern (col, sgn, x, y, S.mode)
END PaintColPat;

PROCEDURE PaintColPat2d* (x2d, y2d: Real;   col: Color;   sgn: tSign);
VAR x, y : Coordinate;
BEGIN	Point2dToPoint (x2d, y2d, x, y);
PaintColPat (x, y, col, sgn)
END PaintColPat2d;
*)(*! fof 010122: unused in Voyager, removed *)

PROCEDURE ErasePat* (x, y: SIGNED16;     sgn: tSign);
BEGIN
	IF status = display THEN
		Local2Global0(x, y);
		Justify (x, y, sgn);
		vyGraphBase0.SetForeColor(S.bcol);
		vyGraphBase0.copyPattern (sgn, x, y);
		vyGraphBase0.SetForeColor(S.fcol)
	END
END ErasePat;

PROCEDURE ErasePat2d* (x2d, y2d: Real;    sgn: tSign);
	VAR x, y : Coordinate;
BEGIN	Point2dToPoint (x2d, y2d, x, y);
	ErasePat (x, y, sgn)
END ErasePat2d;


PROCEDURE SetPatternJustification* (hJust, vJust: SIGNED16);
BEGIN
	hPatJustification := hJust;
	vPatJustification := vJust
END SetPatternJustification;

PROCEDURE StorePattern* (VAR R: Files.Rider;     sgn: tSign);
BEGIN
	vyGraphBase0.StorePattern(R, sgn)
END StorePattern;

PROCEDURE LoadPattern* (VAR R: Files.Rider): tSign;
BEGIN RETURN vyGraphBase0.LoadPattern(R)
END LoadPattern;

PROCEDURE NewPattern* (image: ARRAY OF SET;     w, h: SIGNED16;     prn: tPatPrinter): tSign;
BEGIN
	RETURN vyGraphBase0.NewPattern(image, w, h, prn)
END NewPattern;

(*
PROCEDURE SetDB* (bmp: Bitmaps.Bitmap;    X, Y: SIGNED16);
BEGIN
vyGraphBase0.SetBuffer(bmp,X,Y);
ShiftCoordinate(-X, -Y);
END SetDB;
*)

PROCEDURE openDB* (VAR db: vyGraphBase0.doubleBuffer; x, y,w,h: SIGNED16; translucent: BOOLEAN);
BEGIN
	IF (vyGraphBase0.db # NIL) THEN  RETURN END;
	vyGraphBase0.OpenBuffer(db,x,y,w,h,translucent); dbx := x;  dby := y;ShiftCoordinate( - x, - y);
	IF db.type = vyGraphBase0.cDisplayBuffer THEN
		SetClippingRoutines();
		Display2Local := Global2Local0;
		Local2Display := Local2Global0
	ELSIF db.type = vyGraphBase0.cImageBuffer THEN
		SetImageRoutines();
		Display2Local := Global2Local1;
		Local2Display := Local2Global1
	ELSE HALT(101);
	END;

(*	IF ~vyGraphBase0.db.active THEN
		IF bmp # NIL THEN
			vyGraphBase0.OpenBuffer(bmp , X, Y);  dbx := X;  dby := Y;
			ShiftCoordinate( - X, - Y);
			SetClippingRoutines();
			Display2Local := Global2Local0;
			Local2Display := Local2Global0
		ELSIF img # NIL THEN
			vyGraphBase0.OpenImgBuffer(img , X, Y);  dbx := X;  dby := Y;
			ShiftCoordinate( - X, - Y);
			SetImageRoutines();
			Display2Local := Global2Local1;
			Local2Display := Local2Global1
		ELSE HALT(101)
		END
	END
	*)
END openDB;

PROCEDURE closeDB*;
	VAR X, Y: SIGNED16;
BEGIN
	IF vyGraphBase0.db = NIL THEN RETURN END;
	IF vyGraphBase0.db.active THEN
		vyGraphBase0.CloseBuffer(vyGraphBase0.db,X,Y);
		ShiftCoordinate(X, Y);
		Display2Local := Global2Local0;
		Local2Display := Local2Global0;
		(* theCoordinate.x := theCoordinate.x0; theCoordinate.y := theCoordinate.y0; *)
		SetClippingRoutines()
	END
END closeDB;

PROCEDURE writeDB*;
BEGIN vyGraphBase0.WriteBuffer(vyGraphBase0.db);
END writeDB;

(*   CURSOR CONTROL ROUTINES   *)
PROCEDURE SetCursor* (shape: CursorMarker);
BEGIN theCursor := shape  END SetCursor;

PROCEDURE GetCursor* (VAR shape: CursorMarker);
BEGIN shape := theCursor  END GetCursor;

PROCEDURE DrawCursor* (x, y: SIGNED16);
BEGIN Oberon.DrawCursor(Oberon.Mouse, theCursor, x, y)  END DrawCursor;

PROCEDURE FadeCursor*;
BEGIN Oberon.FadeCursor(Oberon.Mouse)  END FadeCursor;
(*  GENRAL ROUTINES   *)

PROCEDURE DrawCrosshair (x, y: SIGNED16);
(*= draw the port cursor *)
BEGIN
	IF x < Display.ColLeft THEN
		IF x < 5 THEN x := 5
		ELSIF x > Display.Width THEN x := Display.Width - 5 END
	ELSE
		IF x < Display.ColLeft + 5 THEN x := Display.ColLeft + 5
		ELSIF x > Display.ColLeft + Display.Width THEN x := Display.ColLeft + Display.Width - 5 END
	END ;
	IF y < 5 THEN y := 5 ELSIF y > Display.Height THEN y := Display.Height - 5 END ;
	Display.CopyPattern(white, Display.cross, x - 5, y - 5, 2)
END DrawCrosshair;

PROCEDURE DrawWheel (x, y: SIGNED16);
BEGIN Display.CopyPattern (white, wheel, x - 3, y - 3, 2)  END DrawWheel;

PROCEDURE DrawDefPoint (x, y: SIGNED16);
BEGIN Display.CopyPattern (white, defPoint, x - 3, y - 3, 2)  END DrawDefPoint;
PROCEDURE CursorInit;
	VAR img: ARRAY 10 OF SET;
BEGIN
	img[1] := {2, 3, 4};    			(* --***-- *)
	img[2] := {1, 3, 5};    			(* -*-*-*- * *)
	img[3] := {0, 6};    				(* *-----* *)
	img[4] := {0, 1, 5, 6};    		(* **---** *)
	img[5] := {0, 6};    				(* *-----* *)
	img[6] := {1, 3, 5};    			(* -*-*-*- * *)
	img[7] := {2, 3, 4};    			(* --***-- *)
	wheel := Display.NewPattern(7, 7, img);

	img[1] := {          3};    			(* ---*--- *)
	img[2] := {       2, 3};    			(* --**--- *)
	img[3] := {   1, 2, 3, 4, 5, 6};     (* -****** *)
	img[4] := {0, 1, 2, 3, 4, 5, 6};
	img[5] := img[3];
	img[6] := img[2];
	img[7] := img[1];
	defPoint := Display.NewPattern( 7, 7, img)
END CursorInit;

PROCEDURE PalettePath* (r1, g1, b1, r2, g2, b2, start, end: SIGNED16;     palette: tPalette);
	VAR i: SIGNED16;
BEGIN
	FOR i := start TO end DO
		palette.red[i] := SHORT (ENTIER (r1 + (r2 - r1) / (end - start) * (i - start)));
		palette.green[i] := SHORT (ENTIER (g1 + (g2 - g1) / (end - start) * (i - start)));
		palette.blue[i] := SHORT (ENTIER (b1 + (b2 - b1) / (end - start) * (i - start)))
	END
END PalettePath;

PROCEDURE InstallPalettes;
	VAR i: SIGNED16;

BEGIN
	NEW (stdPalette);
	FOR i := 0 TO 15 DO
		Display.GetColor (i, stdPalette.red[i], stdPalette.green[i], stdPalette.blue[i])
	END;

	NEW (bluePalette);
	PalettePath (200, 255, 255, 0, 0, 180, 4, 14, bluePalette);
	NEW (greyPalette);
	PalettePath (255, 255, 255, 20, 20, 20, 4, 14, greyPalette);

	NEW (yellowRedBluePalette);
	PalettePath (255, 255, 125, 255, 0, 0, 4, 10, yellowRedBluePalette);
	PalettePath (255, 0, 0, 125, 0, 255, 10, 14, yellowRedBluePalette);

	NEW (userPalette);
	userPalette.red := stdPalette.red;
	userPalette.green := stdPalette.green;
	userPalette.blue := stdPalette.blue;

	DoSetPalette (stdPalette)
END InstallPalettes;


PROCEDURE WriteRegion* (VAR R: Files.Rider;    VAR (*IN*)reg: tRegion2d);
BEGIN
	WHILE reg # NIL DO
		Files.WriteInt(R, 1);
		Files.WriteLReal(R, reg.x);   Files.WriteLReal(R, reg.y);
		Files.WriteLReal(R, reg.w);   Files.WriteLReal(R, reg.h);
		reg := reg.prev
	END;
	Files.WriteInt(R, 0)
END WriteRegion;

PROCEDURE ReadRegion* (VAR R: Files.Rider;    VAR reg: tRegion2d);
	VAR flag: SIGNED16;    tempreg: tRegion2d;
BEGIN
	Files.ReadInt(R, flag);    IF flag = 0 THEN reg := NIL
	ELSE IF reg = NIL THEN NEW(reg)  END;
	tempreg := reg END;
	WHILE flag # 0 DO
		Files.ReadLReal(R, tempreg.x);   Files.ReadLReal(R, tempreg.y);
		Files.ReadLReal(R, tempreg.w);   Files.ReadLReal(R, tempreg.h);
		Files.ReadInt(R, flag);    IF flag # 0 THEN NEW(tempreg.prev);    tempreg := tempreg.prev END
	END
END ReadRegion;

PROCEDURE WriteCoordinate* (VAR R: Files.Rider;    VAR (*IN*)c: tCoordinate2d);
BEGIN
	IF c = NIL THEN Files.WriteInt(R, 0)
	ELSE Files.WriteInt(R, 1);
		Files.WriteInt(R, c.x0);   Files.WriteInt(R, c.y0)
	END
END WriteCoordinate;

PROCEDURE ReadCoordinate* (VAR R: Files.Rider;    VAR (*OUT*)c: tCoordinate2d);
	VAR flag: SIGNED16;
BEGIN
	Files.ReadInt(R, flag);
	IF flag = 0 THEN  c := NIL ELSE
		IF c = NIL THEN NEW(c) END;
		Files.ReadInt(R, c.x0);   Files.ReadInt(R, c.y0)
	END
END ReadCoordinate;

PROCEDURE WriteCoordinate2d* (VAR R: Files.Rider;    VAR (*IN*)c: tCoordinate2d);
BEGIN
	IF c = NIL THEN Files.WriteInt(R, 0)
	ELSE Files.WriteInt(R, 87);   (*magic number*)
		Files.WriteInt(R, c.x);   Files.WriteInt(R, c.y);
		Files.WriteInt(R, c.w);   Files.WriteInt(R, c.h);
		Files.WriteLReal(R, c.x2d);   Files.WriteLReal(R, c.y2d);
		Files.WriteLReal(R, c.w2d);   Files.WriteLReal(R, c.h2d);
		Files.WriteLReal(R, c.xFact);   Files.WriteLReal(R, c.yFact);
		(* Files.WriteInt(R, c.x02d);  Files.WriteInt(R, c.y02d); *)
		WriteRegion(R, c.zoomCache)
	END
END WriteCoordinate2d;

PROCEDURE ReadCoordinate2d* (VAR R: Files.Rider;    VAR (*IN*)c: tCoordinate2d);
	VAR flag: SIGNED16;
BEGIN
	Files.ReadInt(R, flag);    IF flag = 0 THEN c := NIL
	ELSE
		ASSERT(flag = 87, 100);   (*magic number*)
		IF c = NIL THEN NEW(c) END;
		Files.ReadInt(R, c.x);   Files.ReadInt(R, c.y);
		Files.ReadInt(R, c.w);   Files.ReadInt(R, c.h);
		Files.ReadLReal(R, c.x2d);   Files.ReadLReal(R, c.y2d);
		Files.ReadLReal(R, c.w2d);   Files.ReadLReal(R, c.h2d);
		Files.ReadLReal(R, c.xFact);   Files.ReadLReal(R, c.yFact);
		(* Files.ReadInt(R, c.x02d);  Files.ReadInt(R, c.y02d); *)
		ReadRegion(R, c.zoomCache)
	END
END ReadCoordinate2d;


(** 2d: Procedures for real valued 2d graphics *)
PROCEDURE HandleCoordinate2dAttr* (VAR M: Objects.AttrMsg;   VAR c: tCoordinate2d);
BEGIN
	IF M.id = Objects.get THEN
		IF M.name = 'x0'THEN M.i := c.x0;    M.class := Objects.Int;    M.res := 0
		ELSIF M.name = 'y0'THEN M.i := c.y0;    M.class := Objects.Int;    M.res := 0
		ELSIF M.name = 'x'THEN M.i := c.x;    M.class := Objects.Int;    M.res := 0
		ELSIF M.name = 'y'THEN M.i := c.y;    M.class := Objects.Int;    M.res := 0
		ELSIF M.name = 'w'THEN M.i := c.w;    M.class := Objects.Int;    M.res := 0
		ELSIF M.name = 'h'THEN M.i := c.h;    M.class := Objects.Int;    M.res := 0
		ELSIF M.name = 'x2d'THEN M.y := c.x2d;    M.class := Objects.LongReal;    M.res := 0
		ELSIF M.name = 'y2d'THEN M.y := c.y2d;    M.class := Objects.LongReal;    M.res := 0
		ELSIF M.name = 'w2d'THEN M.y := c.w2d;    M.class := Objects.LongReal;    M.res := 0
		ELSIF M.name = 'h2d'THEN M.y := c.h2d;    M.class := Objects.LongReal;    M.res := 0
		END
	ELSIF M.id = Objects.set THEN
		IF M.name = "x2d"THEN IF M.class = Objects.LongReal THEN c.x2d := M.y;  M.res := 0   END
		ELSIF M.name = "y2d"THEN IF M.class = Objects.LongReal THEN c.y2d := M.y;  M.res := 0   END
		ELSIF M.name = "w2d"THEN IF M.class = Objects.LongReal THEN c.w2d := M.y;  M.res := 0   END
		ELSIF M.name = "h2d"THEN IF M.class = Objects.LongReal THEN c.h2d := M.y;  M.res := 0   END
		END
	ELSIF M.id = Objects.enum THEN
		M.Enum('x0');
		M.Enum('y0');
		M.Enum('x');
		M.Enum('y');
		M.Enum('w');
		M.Enum('h');
		M.Enum('x2d');
		M.Enum('y2d');
		M.Enum('w2d');
		M.Enum('h2d')
	END
END HandleCoordinate2dAttr;

(** Coordinate support *)
PROCEDURE CopyCoordinate2d* (sc, dc: tCoordinate2d);
BEGIN
	dc.x := sc.x;     dc.y := sc.y;     dc.w := sc.w;     dc.h := sc.h;
	dc.x2d := sc.x2d;     dc.y2d := sc.y2d;     dc.w2d := sc.w2d;     dc.h2d := sc.h2d;
	dc.x0 := sc.x0;     dc.y0 := sc.y0;     dc.xFact := sc.xFact;     dc.yFact := sc.yFact;
	dc.zoomCache := NIL
END CopyCoordinate2d;

PROCEDURE RealToCoord* (r: Real): Coordinate;
BEGIN
	IF (r < MAX(SIGNED16)) & (r > MIN(SIGNED16)) THEN RETURN SHORT(ENTIER(r)) ELSE (* Out.String("Coordinate problem !"); Out.Ln; *)RETURN NAN END
END RealToCoord;

PROCEDURE ShiftCoordinate* (x, y: SIGNED16);
BEGIN
	INC(theCoordinate.x0, x);    INC(theCoordinate.y0, y)
	(* INC(theCoordinate.x, x);   INC(theCoordinate.y, y);*)
END ShiftCoordinate;

PROCEDURE SyncFactors;
BEGIN
	WITH theCoordinate: tCoordinate2d DO
		theCoordinate.xFact := theCoordinate.w / theCoordinate.w2d;
		theCoordinate.yFact := theCoordinate.h / theCoordinate.h2d;
		(*
		theCoordinate.x02d := (RealToCoord(theCoordinate.x - theCoordinate.x2d * theCoordinate.xFact));

		theCoordinate.y02d := (RealToCoord(theCoordinate.y - theCoordinate.y2d * theCoordinate.yFact))
		*)(* wrong !! Do not store RealCoord origin in SIGNED16 coords -> Overflow, fof *)
		(* theCoordinate.x02d := theCoordinate.x;
		theCoordinate.y02d := theCoordinate.y; *)
		(*
		ELSE
		theCoordinate.y02d :=  (ENTIER(theCoordinate.y+ theCoordinate.h + theCoordinate.y2d*theCoordinate.yFact))
		END;
		*)
	END;
END SyncFactors;

PROCEDURE SetScreenRgn* (x, y, w, h: Coordinate);
BEGIN
	WITH theCoordinate: tCoordinate2d DO
		theCoordinate.x := x;    theCoordinate.y := y;    theCoordinate.w := w;    theCoordinate.h := h;
		SyncFactors
	END
END SetScreenRgn;


PROCEDURE GetScreenRgn* (VAR x, y, w, h: Coordinate);
BEGIN
	WITH theCoordinate: tCoordinate2d DO
		x := theCoordinate.x;  y :=  theCoordinate.y;  w := theCoordinate.w;  h :=  theCoordinate.h
	END
END GetScreenRgn;

PROCEDURE SetRealWorldRgn* (x2d, y2d, w2d, h2d, stretch: Real);
	VAR x, y, w, h, dx, dy: Real;
BEGIN
	dx := w2d * stretch;    dy := h2d * stretch;
	x := x2d - dx;    y := y2d - dy;    w := w2d + 2 * dx;    h := h2d + 2 * dy;
	WITH theCoordinate: tCoordinate2d DO	theCoordinate.x2d := x;    theCoordinate.y2d := y;    theCoordinate.w2d := 	w;    theCoordinate.h2d := h
	END;
	SyncFactors
END SetRealWorldRgn;

PROCEDURE GetRealWorldRgn* (VAR x2d, y2d, w2d, h2d: Real);
BEGIN WITH theCoordinate: tCoordinate2d DO
		x2d := theCoordinate.x2d;    y2d := theCoordinate.y2d;
	w2d := theCoordinate.w2d;    h2d := theCoordinate.h2d   END
END GetRealWorldRgn;

PROCEDURE Global2Local0 (VAR x, y: SIGNED16);
BEGIN x := x - theCoordinate.x0;    y := y - theCoordinate.y0 END Global2Local0;

PROCEDURE Local2Global0 (VAR x, y: SIGNED16);
BEGIN x := x + theCoordinate.x0;    y := y + theCoordinate.y0 END Local2Global0;

PROCEDURE Global2Local1 (VAR x, y: SIGNED16);
BEGIN x := x - theCoordinate.x0 - dbx;    y := y - theCoordinate.y0 - dby END Global2Local1;

PROCEDURE Local2Global1 (VAR x, y: SIGNED16);
BEGIN x := x + theCoordinate.x0 + dbx;    y := y + theCoordinate.y0 + dby END Local2Global1;

(* fof : 010214:  use conversion routines (0) when  painting (e.g. layer), includes cache Display coordinate system  variables   *)
(* use conversionroutines when identifying mouse etc., only visible coordinate system : *)

PROCEDURE Global2Local* (VAR x, y: SIGNED16);
BEGIN 	x := x - theCoordinate.x;    y := y - theCoordinate.y
END Global2Local;

PROCEDURE Local2Global* (VAR x, y: SIGNED16);
BEGIN x := x + theCoordinate.x;    y := y + theCoordinate.y END Local2Global;


(*! provide distinction between GlobalToLocal on Screen and for painting when in db-Display mode *)


PROCEDURE SetCoordinate* (c: tCoordinate2d);
BEGIN 	theCoordinate := c END SetCoordinate;

PROCEDURE SetScreenCoordinate*;
BEGIN  	theCoordinate := screenCoordinate END SetScreenCoordinate;

PROCEDURE GetCoordinate* (): tCoordinate2d;
BEGIN RETURN theCoordinate END GetCoordinate;

PROCEDURE OpenCoordinate* (c: tCoordinate2d;    x, y: SIGNED16);
BEGIN c.x0 := x;    c.y0 := y;    SetCoordinate (c) END OpenCoordinate;

PROCEDURE OpenCoordinate1* (c: tCoordinate2d;    x, y, w, h: SIGNED16);
BEGIN OpenCoordinate (c, x, y);   c.zoomCache := NIL;   c.w := w;   c.h := h   END OpenCoordinate1;

PROCEDURE OpenCoordinate2d* (c: tCoordinate2d;    x, y, w, h: Real);
BEGIN OpenCoordinate1(c, 0, 0, DisplayWidth, DisplayHeight);
	SetRealWorldRgn (x, y, w, h, 0.05)
END OpenCoordinate2d;

PROCEDURE InsetRealWorldRegion* (dxPix, dyPix: Coordinate);
	VAR x2ds, y2ds, w2ds, h2ds, xfacts, yfacts: Real;    ws, hs: Coordinate;
BEGIN
	WITH theCoordinate: tCoordinate2d DO

		ws := theCoordinate.w - 2 * dxPix;
		xfacts := ws / theCoordinate.w2d;
		x2ds := theCoordinate.x2d - dxPix / xfacts;
		w2ds := theCoordinate.w / xfacts;
		hs := theCoordinate.h - 2 * dyPix;
		yfacts := hs / theCoordinate.h2d;
		y2ds := theCoordinate.y2d - dyPix / yfacts;
		h2ds := theCoordinate.h / yfacts;
		SetRealWorldRgn (x2ds, y2ds, w2ds, h2ds, 0)
	END
END InsetRealWorldRegion;

PROCEDURE FixCoordinate* (x, y: Coordinate);
BEGIN WITH theCoordinate: tCoordinate2d DO
	SetScreenRgn (x, y, theCoordinate.w, theCoordinate.h) END
END FixCoordinate;

PROCEDURE MoveRealWorldRgn* (x2d, y2d: Real);
BEGIN	WITH theCoordinate: tCoordinate2d DO
	SetRealWorldRgn (theCoordinate.x2d + x2d, theCoordinate.y2d + y2d, theCoordinate.w2d, theCoordinate.h2d, 0) END
END MoveRealWorldRgn;
(** **)

PROCEDURE PointToPoint2d* (x, y: Coordinate;    VAR x2d, y2d: Real);
BEGIN	WITH theCoordinate: tCoordinate2d DO
		x2d := (x - theCoordinate.x) / theCoordinate.xFact + theCoordinate.x2d;
		y2d := (y - theCoordinate.y) / theCoordinate.yFact + theCoordinate.y2d
	END
END PointToPoint2d;

PROCEDURE Point2dToPoint* (x2d, y2d: Real;    VAR x, y: Coordinate);
BEGIN
	WITH theCoordinate: tCoordinate2d DO
		x := RealToCoord	(theCoordinate.x + (x2d - theCoordinate.x2d) * theCoordinate.xFact + 0.5)   ;
		y := RealToCoord	(theCoordinate.y + (y2d - theCoordinate.y2d) * theCoordinate.yFact + 0.5)
	END
END Point2dToPoint;

PROCEDURE VectorToVector2d* (dx, dy: Coordinate;    VAR dx2d, dy2d: Real);
BEGIN WITH theCoordinate: tCoordinate2d DO
	dx2d := dx / theCoordinate.xFact;    dy2d :=  dy / theCoordinate.yFact END
END VectorToVector2d;

(* transformation: rectangle in real coordinate <-> rectangle in screen pixels   *)

PROCEDURE RectToRect2d* (x, y, w, h: Coordinate;    VAR x2d, y2d, w2d, h2d: Real);
BEGIN WITH theCoordinate: tCoordinate2d DO
		PointToPoint2d (x, y, x2d, y2d);
	w2d := w / theCoordinate.xFact;   		h2d := h / theCoordinate.yFact END
END RectToRect2d;

PROCEDURE Rect2dToRect* (x2d, y2d, w2d, h2d: Real;    VAR x, y, w, h: Coordinate);
	VAR x1, y1: Coordinate;
BEGIN WITH theCoordinate: tCoordinate2d DO
		Point2dToPoint (x2d, y2d, x, y);
		Point2dToPoint (x2d + w2d, y2d + h2d, x1, y1);
	w := x1 - x;    h := y1 - y END
END Rect2dToRect;

PROCEDURE ZoomIn* (x, y, w, h: Coordinate);
	VAR x0, y0, x1, y1: Real;    cache: tRegion2d; a,b: SIGNED16;
CONST fact=0.77;
BEGIN WITH theCoordinate: tCoordinate2d DO
		IF w = 0 THEN
			a := x-theCoordinate.x; b := theCoordinate.x+theCoordinate.w -x;
			x := x- SHORT(ENTIER(a * fact)) ; w :=  SHORT(ENTIER(b*fact+a*fact));
		END;
		IF h = 0 THEN
			a := y-theCoordinate.y; b := theCoordinate.y+theCoordinate.h-y;
			y := y- SHORT(ENTIER(a * fact)); h := SHORT(ENTIER(b*fact+a*fact));
		END;


		PointToPoint2d (x, y, x0, y0);   		PointToPoint2d (x + w, y + h, x1, y1);
		NEW (cache);
		cache.x := theCoordinate.x2d;
		cache.y := theCoordinate.y2d;
		cache.w := theCoordinate.w2d;
		cache.h := theCoordinate.h2d;
		cache.prev := theCoordinate.zoomCache;
		theCoordinate.zoomCache := cache;
		SetRealWorldRgn (x0, y0, x1 - x0, y1 - y0, 0)
	END
END ZoomIn;

PROCEDURE ZoomOut*;
BEGIN
	WITH theCoordinate: tCoordinate2d DO
		IF theCoordinate.zoomCache # NIL THEN
			SetRealWorldRgn (theCoordinate.zoomCache.x, theCoordinate.zoomCache.y,
			theCoordinate.zoomCache.w, theCoordinate.zoomCache.h, 0);
			theCoordinate.zoomCache := theCoordinate.zoomCache.prev
		ELSE
			SetRealWorldRgn (theCoordinate.x2d, theCoordinate.y2d, theCoordinate.w2d, theCoordinate.h2d, 0.5)
		END
	END
END ZoomOut;


(** **)

PROCEDURE Init;
BEGIN 	NEW (theCoordinate);    OpenCoordinate (theCoordinate, 0, 0);
	NEW (screenCoordinate);    OpenCoordinate (screenCoordinate, 0, 0);
	DisplayHeight := Display.Height;    	DisplayWidth := Display.Width
END Init;

BEGIN
	Display2Local := Global2Local0;
	Local2Display := Local2Global0;
	Init;
	selectpat := Display3.selectpat;
	FG := Display3.FG;     BG := Display3.BG;
	red := Display3.red;     green := Display3.green;     blue := Display3.blue;
	black := Display3.black;     white := Display3.white;
	bottomC := Display3.bottomC;
	textC := Display3.textC;
	textbackC := Display3.textbackC;

	SetClippingRoutines;

	black := Display3.black;
	white := Display3.white;
	lgrey := 14;
	mgrey := 13;
	dgrey := 12;
	green := Display3.green;
	blue := Display3.blue;
	red := Display3.red;
	yellow := 5;
	cyan := 4;
	dkred  :=  7;
	dkgreen := 8;
	dkblue := 9;
	orange := 11;
	skyblue := 6;
	dkcyan := 10;
	pen.x := 0;     pen.y := 0;
	status := display;
	stdFnt := "Syntax10.Scn.Fnt";
	SetStringJustification (left, bottom);
	SetPatternJustification (center, center);
	DisplayHeight := Display.Height;     	DisplayWidth := Display.Width;

	defaultStyle.fcol := CorrectCol(15);
	defaultStyle.bcol := 14;
	defaultStyle.pattern := Display.solid;
	defaultStyle.mode := Display.replace;
	defaultStyle.fillcol := 0;
	defaultStyle.selectcol := 12;
	defaultStyle.selectpat := Display.solid;
	defaultStyle.fillpat := Display.solid;
	defaultStyle.style := {};
	defaultStyle.pensize := 1;
	defaultStyle.fnt := "Syntax.10.Scn.Fnt";
	defaultStyle.alpha := 255;
	SetStyle(defaultStyle);

	Display.SetColor(255, 0, 0, 0);

	(* Cursor *)
	CursorInit;
	theCursor := Oberon.Arrow;
	Crosshair.Draw := DrawCrosshair;     Crosshair.Fade := DrawCrosshair;
	Wheel.Draw := DrawWheel;     Wheel.Fade := DrawWheel;
	DefPoint.Draw := DrawDefPoint;     DefPoint.Fade := DrawDefPoint;

	InstallPalettes;
	mincol := 0;     maxcol := 15;
	UseDoubleBuffering := UseDBDefaultVal ;
END vyGraphBase.