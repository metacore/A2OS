MODULE vyTracking IN Oberon;  		(*vs 0.0a2 md   08.08.95, fof 28.3.96 *)
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


(*		(c) Project Voyager, StatLab Heidelberg
(c) M. Diller, StatLab Heidelberg
(c) F. Friedrich, StatLab Heidelberg
*)

(*= 	Contents	visual feedback of rectangles manipulation
!!! THIS MODULE DEPENDS ON THE UNDERLYING OBERON-VERSION !!!
The routines in this module supports the visual feedback during interactions (e.g. tracking a rectangle or a string, resize a given rectangle etc.) and takes the control of such an interaction until it finished. Despite of ScrollList all routines just returns the value of the movement: dx, dy.
For an quick porting, you can renounce on the visual feedback and just return the value of the movement.*)

(*	history:
25.06.2002 fof  all Procedures realized as Procedure Variables for exchangeable behaviour on different platforms ( compatibility with ANTS)
28.3.96 fof 0.0a2   ported to System3, including own popup lists for system3.
8.8.95 md 0.0a1	alpha version
9.05.95 md 0.0d0	created as an extraction of vyInterActive.v0r0d4.md.Mod
*)

IMPORT
	Input,  Display, Display3, Fonts, Texts, vyGraphBase, vyBase, vyHostDisplay := vyGraphBase,  (*Bitmaps*)Effects,
	vyName, vyRectangles,  Oberon, vyPortability;

CONST
	idversion* = 	"vyTracking v0r0a5";
	Font = "Syntax10.Scn.Fnt";  minW = 30;  minH = 10;  Border = 3;  (*for Lists*)
	allkeys = {vyBase.leftKey, vyBase.middleKey, vyBase.rightKey};
	maxIdleTime* = 5;
	listMaxIdleTime = 2;

TYPE

	List* =  POINTER TO ListDesc;
	ListDesc* = RECORD
		name*: vyName.tNameArray;
		x, y, w, h, dsr: SIGNED16;
		fnt: ARRAY 32 OF CHAR;
		nr: SIGNED16;
		next*: List
	END;

	fofPopup = RECORD
		x, y, w, h, dh: SIGNED16;
		nr: SIGNED16;
		e: List
	END;

	VAR Wr: vyBase.TextsWriter;
	BorderBGColor, BorderFGColor, BGColor, FGColor, SelectColor: Display.Color;  (* for Lists *)
	inHelp: BOOLEAN;

	Rectangle*: PROCEDURE (x, y, w, h:  SIGNED16;  VAR dx, dy: SIGNED16);
	Rectangles*: PROCEDURE (x, y, w, h: ARRAY OF SIGNED16;  rectCount: SIGNED16;  VAR dx, dy: SIGNED16);
	GrowRectangleRL*: PROCEDURE (x, y, w, h: SIGNED16;  VAR dx, dy: SIGNED16);
	GrowRectangleR*: PROCEDURE (x, y, w, h: SIGNED16;  VAR dx, dy: SIGNED16);
	ZoomCentralRect*: PROCEDURE (x, y, w, h: SIGNED16;  VAR dx, dy: SIGNED16);
	TrackMouse*: PROCEDURE (VAR keys: SET;  VAR X, Y: SIGNED16;  marker: Oberon.Marker);
	ScrollList*: PROCEDURE (e0: List;  x0, y0: SIGNED16;  VAR res: List);
	MoveListEntry*: PROCEDURE (list: List;  VAR x, y, dx, dy: SIGNED16);
	FramedString*: PROCEDURE (X, Y: SIGNED16;  fnt, str: ARRAY OF CHAR;  VAR dx, dy: SIGNED16);
	String*: PROCEDURE (X, Y: SIGNED16;  fnt, str: ARRAY OF CHAR;  VAR dx, dy: SIGNED16);
	Help*: PROCEDURE (s: ARRAY OF CHAR);
	HelpAt*: PROCEDURE (x, y: SIGNED16;  s: ARRAY OF CHAR);
	HelpEnd*: PROCEDURE;
	TrackMouseCont*: PROCEDURE (VAR keys: SET;  VAR x, y:  SIGNED16;  marker: Oberon.Marker);

PROCEDURE rectangle (x, y, w, h: SIGNED16;  VAR dx, dy: SIGNED16);
	(*vs 0.0a1 md  03.11.94 *)
	VAR keys, keys0: SET;  x1, y1, x0, y0, xOld, yOld: SIGNED16;  oldm: SIGNED16;
BEGIN
	vyHostDisplay.GetDisplayMode (oldm);
	vyHostDisplay.SetDisplayMode (vyHostDisplay.invert);
	Input.Mouse (keys0, x0, y0);  vyHostDisplay.DrawCursor (x0, y0);  vyHostDisplay.FrameRect (x, y, w, h);
	Input.Mouse (keys, x1, y1);  xOld := x0;  yOld := y0;
	WHILE (keys = keys0) DO
		IF ((x1 # xOld) OR (y1 # yOld)) THEN
			vyHostDisplay.FrameRect (x, y, w, h);
			x := x + (x1 - xOld);  y := y + (y1 - yOld);
			vyHostDisplay.FrameRect (x, y, w, h);
			xOld := x1;  yOld := y1
		END;
		Input.Mouse (keys, x1, y1);  vyHostDisplay.DrawCursor (x1, y1)
	END;
	vyHostDisplay.FrameRect (x, y, w, h);
	(*IF keys={} THEN dx := x1-x0; dy := y1-y0 ELSE dx := 0; dy := 0 END;*)
	IF keys - keys0 = {} THEN dx := x1 - x0;  dy := y1 - y0 ELSE dx := 0;  dy := 0 END;
	vyHostDisplay.SetDisplayMode (oldm)
END rectangle;
(*  System.Free vyTracking     vyTracking.RectangleTest   *)

PROCEDURE rectangles (x, y, w, h: ARRAY OF SIGNED16;  rectCount: SIGNED16;
VAR dx, dy: SIGNED16);
	(*vs 0.0a1  md  03.11.94 *)
	VAR keys, keys0: SET;  x1, y1, x0, y0, xOld, yOld, oldm: SIGNED16;

PROCEDURE FrameRects;
	VAR i: SIGNED16;
BEGIN i := 0;
	WHILE i < rectCount DO vyHostDisplay.FrameRect (x[i] + dx, y[i] + dy, w[i], h[i]);  INC (i) END
END FrameRects;

BEGIN 	vyHostDisplay.GetDisplayMode (oldm);
	vyHostDisplay.SetDisplayMode (vyHostDisplay.invert);
	Input.Mouse (keys0, x0, y0);  vyHostDisplay.DrawCursor (x0, y0);
	dx := 0;  dy := 0;  FrameRects;
	Input.Mouse (keys, x1, y1);  xOld := x0;  yOld := y0;
	WHILE (keys = keys0) DO
		IF ((x1 # xOld) OR (y1 # yOld)) THEN
			FrameRects;
			dx := x1 - x0;  dy := y1 - y0;
			FrameRects;
			xOld := x1;  yOld := y1
		END;
		Input.Mouse (keys, x1, y1);  vyHostDisplay.DrawCursor (x1, y1)
	END;
	FrameRects;
	IF keys # allkeys THEN dx := 0;  dy := 0 END;
	vyHostDisplay.SetDisplayMode (oldm)
END rectangles;
(*  System.Free vyTracking     vyTracking.RectanglesTest   *)

PROCEDURE growRectangleRL (x, y, w, h: SIGNED16;  VAR dx, dy: SIGNED16);
	(*vs 0.0a1  md  29.05.95 *)
	VAR keys, keys0: SET;  x1, y1, x0, y0, xOld, yOld: SIGNED16;  oldm: SIGNED16;
BEGIN
	vyHostDisplay.GetDisplayMode (oldm);
	vyHostDisplay.SetDisplayMode (vyHostDisplay.invert);
	Input.Mouse (keys0, x0, y0);  vyHostDisplay.DrawCursor (x0, y0);  vyHostDisplay.FrameRect (x, y, w, h);
	Input.Mouse (keys, x1, y1);  xOld := x0;  yOld := y0;
	WHILE (keys = keys0) DO
		IF ((x1 # xOld) OR (y1 # yOld)) THEN
			vyHostDisplay.FrameRect (x, y, w, h);
			y := y + (y1 - yOld);  w := w + (x1 - xOld);  h := h - (y1 - yOld);
			vyHostDisplay.FrameRect (x, y, w, h);
			xOld := x1;  yOld := y1
		END;

		Input.Mouse (keys, x1, y1);  vyHostDisplay.DrawCursor (x1, y1)
	END;
	vyHostDisplay.FrameRect (x, y, w, h);
	IF keys # {vyBase.rightKey, vyBase.middleKey, vyBase.leftKey} THEN dx := x1 - x0;  dy := y1 - y0 ELSE dx := 0;  dy := 0 END;
	vyHostDisplay.SetDisplayMode (oldm)

END growRectangleRL;
(*  System.Free vyTracking     vyTracking.GrowRectangleRLTest  *)

PROCEDURE growRectangleR (x, y, w, h: SIGNED16;  VAR dx, dy: SIGNED16);
	(*vs 0.0a1  md  29.05.95 *)
	VAR keys, keys0: SET;  x1, y1, x0, y0, xOld, yOld, oldm: SIGNED16;
BEGIN 	vyHostDisplay.GetDisplayMode (oldm);
	vyHostDisplay.SetDisplayMode (vyHostDisplay.invert);
	Input.Mouse (keys0, x0, y0);  vyHostDisplay.DrawCursor (x0, y0);  vyHostDisplay.FrameRect (x, y, w, h);
	Input.Mouse (keys, x1, y1);  xOld := x0;  yOld := y0;
	WHILE (keys = keys0) DO
		IF ((x1 # xOld) OR (y1 # yOld)) THEN
			vyHostDisplay.FrameRect (x, y, w, h);
			w := w + (x1 - xOld);
			vyHostDisplay.FrameRect (x, y, w, h);
			xOld := x1;  yOld := y1
		END;

		Input.Mouse (keys, x1, y1);  vyHostDisplay.DrawCursor (x1, y1)
	END;
	vyHostDisplay.FrameRect (x, y, w, h);
	IF keys = allkeys THEN dx := x1 - x0;  dy := y1 - y0 ELSE dx := 0;  dy := 0 END;
	vyHostDisplay.SetDisplayMode (oldm)

END growRectangleR;
(*  System.Free vyTracking     vyTracking.GrowRectangleRTest  *)

PROCEDURE zoomCentralRect (x, y, w, h: SIGNED16;  VAR dx, dy: SIGNED16);
	(*vs 0.0a1 md*)
CONST growBox = 4;
	VAR keys, keys0: SET;  x0, y0, x1, y1, dxOld, dyOld, oldm: SIGNED16;

PROCEDURE Prompt;

BEGIN vyHostDisplay.FrameRect (x - dx, y - dy, w + 2 * dx, h + 2 * dy);
	vyHostDisplay.PaintRect (x - dx + w + 2 * dx - growBox, y - dy + 1, growBox, growBox)
END Prompt;

BEGIN 	vyHostDisplay.GetDisplayMode (oldm);
	vyHostDisplay.SetDisplayMode (vyHostDisplay.invert);  dx := 0;  dy := 0;  dxOld := 0;  dyOld := 0;
	Input.Mouse (keys0, x0, y0);  (*vyHostDisplay.DrawCursor (x1, y1);*)Prompt;
	(*REPEAT Input.Mouse (keys0, x0, y0);
	UNTIL (vyRectangles.PointInRect (x0, y0, x+w-growBox, y+1, growBox, growBox))
	& (keys0#{});*)

	Input.Mouse (keys, x1, y1);
	WHILE (keys = keys0) DO
		IF (((x1 - x0) # dxOld) OR ((y0 - y1) # dyOld)) THEN
			Prompt;  dxOld := dx;  dyOld := dy;
			dx := x1 - x0;  dy := y0 - y1;  Prompt
		END;
		Input.Mouse (keys, x1, y1);  vyHostDisplay.DrawCursor (x1, y1)
	END;
	Prompt;
	IF keys = allkeys THEN dx := x1 - x0;  dy := y1 - y0 ELSE dx := 0;  dy := 0 END;
	vyHostDisplay.SetDisplayMode (oldm)

END zoomCentralRect;
(*  System.Free vyTracking     vyTracking.ZoomRectTest   *)

PROCEDURE trackMouse (VAR keys : SET;  VAR x, y: SIGNED16;  marker: Oberon.Marker);
BEGIN	(* Input.Mouse(keys, x, y); vyHostDisplay.DrawCursor(x, y); *)Effects.TrackMouse(keys, x, y, marker)  END trackMouse;

PROCEDURE  scrollList (e0: List;  x0, y0: SIGNED16;  VAR res: List);  (* stable for windows interaction, fof *)
	(*vs 0.0a2 fof 26.3.96 *)
	VAR (*bitmap: Bitmaps.Bitmap;*)Q: Display3.Mask;   list: fofPopup;
PROCEDURE MakeList;
	VAR W, H, w0, h0, dsr: SIGNED16;  e: List;
BEGIN
	list.nr := 0;  W := 0;  H := 0;  e := e0;  list.e := e0;
	WHILE(e # NIL) DO
		vyHostDisplay.GetStringSize(Font, e.name, w0, h0, dsr);
		IF w0 > W THEN W := w0 END;  IF h0 > H THEN H := h0 END;
		e.nr := list.nr ;  e.dsr := dsr;  COPY(Font, e.fnt);  INC(list.nr);
		e := e.next
	END;
	IF W < minW THEN W := minW END;  IF H < minH THEN H := minH	END;
	list.w := W;  list.dh := H;  list.h := list.nr * H;
	IF x0 + list.w + Border > vyPortability.DisplayWidth()  THEN x0 := SHORT(vyPortability.DisplayWidth() -  list.w - Border ) END;
	IF y0 - list.h - Border < 0 THEN y0 := Border ELSE y0 := y0 - list.h END;
	IF x0 < 0 THEN x0 := Border END;
	IF y0 +  list.h + Border > vyPortability.DisplayHeight() THEN y0 := SHORT(vyPortability.DisplayHeight()  - list.h  - Border) END;


	list.x := x0;  list.y := y0;  e := list.e;
	WHILE(e # NIL) DO
		e.w := list.w;  e.h := list.dh;  e.x := list.x;  e.y :=  e.nr * list.dh + list.y;   e := e.next
	END
END MakeList;

PROCEDURE ShowList;
	VAR pens: SIGNED16;  e: List;
BEGIN
	vyHostDisplay.SetBackColor(BGColor);
	vyHostDisplay.EraseRect(list.x, list.y, list.w, list.h);
	vyHostDisplay.GetPenSize(pens);  vyHostDisplay.SetPenSize(Border);
	vyHostDisplay.SetBackColor(BorderBGColor);  vyHostDisplay.SetForeColor(BorderFGColor);
	vyHostDisplay.ShadowRect(list.x - Border, list.y - Border, list.w + 2 * Border, list.h + 2 * Border);
	vyHostDisplay.SetPenSize(pens);  vyHostDisplay.SetStringJustification(vyHostDisplay.bottom, vyHostDisplay.left);
	vyHostDisplay.SetForeColor(FGColor);
	e := list.e;
	WHILE(e # NIL) DO vyHostDisplay.String(e.x, e.y + e.dsr , e.fnt, e.name);  e := e.next END
END ShowList;


PROCEDURE FindNew (x, y: SIGNED16): List;
	VAR e: List;
BEGIN	e := list.e;
	WHILE(e # NIL) DO
		IF vyRectangles.PointInRect(x, y, e.x, e.y, e.w, e.h) THEN RETURN e END;
		e := e.next
	END;
	RETURN NIL
END FindNew;

PROCEDURE Selecte (e: List);
BEGIN
	IF e # NIL THEN
		(*vyHostDisplay.SetBackColor(vyHostDisplay.bottomC);
		vyHostDisplay.EraseRect(e.x, e.y, e.w, e.h);
		vyHostDisplay.SetForeColor(FGColor); vyHostDisplay.String(e.x, e.y + e.dsr , e.fnt, e.name)*)
		vyHostDisplay.SetBackColor(FGColor);  vyHostDisplay.EraseRect(e.x, e.y, e.w, e.h);
		vyHostDisplay.SetForeColor(BGColor);  vyHostDisplay.String(e.x, e.y + e.dsr , e.fnt, e.name)
	END
END Selecte;

PROCEDURE Deselecte (e: List);
BEGIN
	vyHostDisplay.SetBackColor(BGColor);  vyHostDisplay.EraseRect(e.x, e.y, e.w, e.h);
	vyHostDisplay.SetForeColor(FGColor);  vyHostDisplay.String(e.x, e.y + e.dsr , e.fnt, e.name)
END Deselecte;

PROCEDURE Select (VAR ls: List);
	VAR xm, ym: SIGNED16;  orgkeys, keys: SET;  stoptime: SIGNED32;
BEGIN
	stoptime := Oberon.Time() + listMaxIdleTime * Input.TimeUnit;   (* stop track mouse after idle *)

	ls := NIL;  Input.Mouse(orgkeys, xm, ym);
	REPEAT
		IF ls = NIL THEN ls := FindNew(xm, ym);  Selecte(ls)
		ELSIF ~vyRectangles.PointInRect(xm, ym, ls.x, ls.y, ls.w, ls.h) THEN Deselecte(ls);  ls := FindNew(xm, ym);  Selecte(ls)
		END;
		IF ls # NIL THEN stoptime := Oberon.Time() + listMaxIdleTime * Input.TimeUnit  END;
		TrackMouse(keys, xm, ym, Oberon.Arrow);
		IF (orgkeys = {}) & (Oberon.Time() > stoptime) & (ls = NIL) THEN RETURN END;
		IF ~vyPortability.DisplayAvailable() THEN (* Display not available*)ls := NIL;  RETURN END
	UNTIL keys # orgkeys
END Select;

BEGIN
	(* Display.SetCurrent(Displays.desktop); *)(* testing, fof, could use for menu on display space, problem: Mouse not identified !! *)
	MakeList();
	(*bitmap := Bitmaps.New(list.w + 2 * Border, list.h + 2 * Border);
	Bitmaps.CopyBlock(Display.cur, bitmap, list.x - Border, list.y - Border, list.w + 2 * Border, list.h + 2 * Border, 0, 0);*)
	(*
	IF list.x+list.w+Border > Display.cur.width THEN list.x := SHORT(Display.cur.width-list.w-Border); new := TRUE; END;
	IF list.y  <0 THEN list.y := Border ; new := TRUE;END;
	IF list.y+list.h+Border > Display.cur.height THEN list.y := SHORT(Display.cur.height-list.h-Border) ; new := TRUE;END;
	IF list.x < 0 THEN list.x := Border  ; new := TRUE;END;
	IF new THEN x0 := list.x; y0 := list.y;  MakeList(); END;
	*)

	Effects.OpenMenu(list.x - Border, list.y - Border, list.w + 2 * Border, list.h + 2 * Border);
	vyGraphBase.SetScreenCoordinate();  	Q := vyHostDisplay.GetMask();  	vyHostDisplay.UseClipMask(NIL);
	vyGraphBase.SetDisplayMode(vyGraphBase.replace);  (* fof 0103, sometimes invert was set *)
	ShowList();
	Select(res);
	(*Bitmaps.CopyBlock(bitmap, Display.cur, 0, 0, list.w + 2 * Border, list.h + 2 * Border, list.x - Border, list.y - Border);*)
	Effects.CloseMenu();
	vyHostDisplay.UseClipMask(Q)
END scrollList;
(*
PROCEDURE MoveListEntry* (list: List; VAR x, y, dx, dy: SIGNED16);
(*vs 0.0a2 fof 28.3.96*)
VAR (*bitmap: Bitmaps.Bitmap;*) x0, y0, x1, y1: SIGNED16; oldkeys, keys: SET; Q: Display3.Mask;

PROCEDURE Show ();
VAR pens: SIGNED16;
BEGIN
vyHostDisplay.GetPenSize(pens); vyHostDisplay.SetPenSize(Border);
vyHostDisplay.SetBackColor(BorderBGColor); vyHostDisplay.SetForeColor(BorderFGColor);
vyHostDisplay.ShadowRect(list.x - Border, list.y - Border, list.w + 2 * Border, list.h + 2 * Border);
vyHostDisplay.SetPenSize(pens);
vyHostDisplay.SetBackColor(SelectColor);
vyHostDisplay.EraseRect(list.x, list.y, list.w, list.h);
vyHostDisplay.SetForeColor(FGColor);
vyHostDisplay.String(list.x, list.y + list.dsr , list.fnt, list.name);
END Show;
*)
PROCEDURE moveListEntry (list: List;  VAR x, y, dx, dy: SIGNED16);
	(*vs 0.0a2 fof 28.3.96*)
	VAR (*bitmap: Bitmaps.Bitmap;*)x0, y0, x1, y1: SIGNED16;  oldkeys, keys: SET;  Q: Display3.Mask;

PROCEDURE Show;
	VAR pens: SIGNED16;
BEGIN
	(* fof 010215
	vyHostDisplay.GetPenSize(pens); vyHostDisplay.SetPenSize(Border);
	vyHostDisplay.SetBackColor(BorderBGColor); vyHostDisplay.SetForeColor(BorderFGColor);
	vyHostDisplay.ShadowRect(list.x - Border, list.y - Border, list.w + 2 * Border, list.h + 2 * Border);
	vyHostDisplay.SetPenSize(pens);
	vyHostDisplay.SetBackColor(SelectColor);
	vyHostDisplay.EraseRect(list.x, list.y, list.w, list.h);
	vyHostDisplay.SetForeColor(FGColor);
	*)
	vyHostDisplay.SetBackColor(BGColor);
	vyHostDisplay.EraseRect(list.x, list.y, list.w, list.h);
	vyHostDisplay.GetPenSize(pens);  vyHostDisplay.SetPenSize(Border);
	vyHostDisplay.SetBackColor(BorderBGColor);  vyHostDisplay.SetForeColor(BorderFGColor);
	vyHostDisplay.ShadowRect(list.x - Border, list.y - Border, list.w + 2 * Border, list.h + 2 * Border);
	vyHostDisplay.SetPenSize(pens);  vyHostDisplay.SetStringJustification(vyHostDisplay.bottom, vyHostDisplay.left);
	vyHostDisplay.SetForeColor(FGColor);

	vyHostDisplay.String(list.x, list.y + list.dsr , list.fnt, list.name)
END Show;

BEGIN
	Q := vyHostDisplay.GetMask();
	vyHostDisplay.UseClipMask(NIL);
	vyHostDisplay.SetStringJustification(vyHostDisplay.bottom, vyHostDisplay.left);
	(*bitmap := Bitmaps.New(list.w + 2 * Border, list.h + 2 * Border);
	Bitmaps.CopyBlock(Display.cur, bitmap, list.x - Border, list.y - Border, list.w + 2 * Border, list.h + 2 * Border, 0, 0);*)
	Effects.OpenMenu(list.x - Border, list.y - Border, list.w + 2 * Border, list.h + 2 * Border);
	x0 := list.x;  y0 := list.y;  	Input.Mouse(oldkeys, x1, y1);
	x := x1;  y := y1;
	Show();
	REPEAT
		IF (x # x1) OR (y # y1) THEN
			(*Bitmaps.CopyBlock(bitmap, Display.cur, 0, 0, list.w + 2 * Border, list.h + 2 * Border, list.x - Border, list.y - Border);*)
			Effects.CloseMenu();
			list.x := list.x + x - x1;  list.y := list.y - y1 + y;
			(*Bitmaps.CopyBlock(Display.cur, bitmap, list.x - Border, list.y - Border, list.w + 2 * Border, list.h + 2 * Border, 0, 0);*)
			Effects.OpenMenu(list.x - Border, list.y - Border, list.w + 2 * Border, list.h + 2 * Border);
			Show()
		END;
		x1 := x;  y1 := y;
		Input.Mouse(keys, x, y)
	UNTIL keys # oldkeys;
	(*Bitmaps.CopyBlock(bitmap, Display.cur, 0, 0, list.w + 2 * Border, list.h + 2 * Border, list.x - Border, list.y - Border);*)
	Effects.CloseMenu();
	dy := list.y - y0;  dx := list.x - x0;
	vyHostDisplay.UseClipMask(Q)
END moveListEntry;

PROCEDURE ArrayToList* (names: ARRAY OF ARRAY OF CHAR;  nr: SIGNED16): List;
	(*vs 0.0a2 fof 28.3.96*)
VAR
	i: SIGNED16;  e, e0: List;
BEGIN
	i := 0;
	IF nr > 0 THEN NEW(e0);  e := e0  END;
	WHILE(i < nr) DO
		COPY(names[i], e.name);
		INC(i);
		IF i < nr THEN NEW(e.next);  e := e.next  END
	END;
	RETURN e0
END ArrayToList;

PROCEDURE framedString (X, Y: SIGNED16;  fnt, str: ARRAY OF CHAR;  VAR dx, dy: SIGNED16);
	(*vs 0.0a2 fof  28.3.96 *)
	VAR  e: List;
BEGIN
	NEW(e);
	IF Fonts.This(fnt) = NIL THEN COPY(Font, e.fnt)   ELSE COPY(fnt, e.fnt)  END;
	e.x := X;  e.y := Y;  COPY(str, e.name);
	vyHostDisplay.GetStringSize(e.fnt, e.name, e.w, e.h, e.dsr);
	MoveListEntry(e, X, Y, dx, dy)
END framedString;

PROCEDURE string (X, Y: SIGNED16;  fnt, str: ARRAY OF CHAR;  VAR dx, dy: SIGNED16);
	(*vs 0.0a1  md  04.07.95 *)
	VAR x0, y0, x1, y1, xOld, yOld, x, y, w, h, dsr, oldm: SIGNED16;  keys, keys0: SET;  font: ARRAY 32 OF CHAR;
BEGIN
	IF Fonts.This(fnt) = NIL THEN COPY(Font, font) ELSE COPY(fnt, font) END;
	vyHostDisplay.GetStringFrame (X, Y, font, str, x, y, w, h, dsr);  INC (w);
	vyHostDisplay.GetDisplayMode (oldm);
	vyHostDisplay.SetDisplayMode (vyHostDisplay.invert);
	vyHostDisplay.SetStringJustification (vyHostDisplay.left, vyHostDisplay.bottom);
	Input.Mouse (keys0, x0, y0);  vyHostDisplay.DrawCursor (x0, y0);
	vyHostDisplay.FrameRect (x - 1, y, w, h);  vyHostDisplay.InvertString (x, y + dsr, font, str);
	Input.Mouse (keys, x1, y1);  xOld := x0;  yOld := y0;
	WHILE (keys = keys0) DO
		IF ((x1 # xOld) OR (y1 # yOld)) THEN
			vyHostDisplay.FrameRect (x - 1, y, w, h);  vyHostDisplay.InvertString (x, y + dsr, font, str);
			x := x + (x1 - xOld);  y := y + (y1 - yOld);
			vyHostDisplay.FrameRect (x - 1, y, w, h);  vyHostDisplay.InvertString (x, y + dsr, font, str);
			xOld := x1;  yOld := y1
		END;
		Input.Mouse (keys, x1, y1);  vyHostDisplay.DrawCursor (x1, y1)
	END;
	vyHostDisplay.FrameRect (x - 1, y, w, h);  vyHostDisplay.InvertString (x, y + dsr, font, str);

	IF keys - keys0 = {} THEN dx := x1 - x0;  dy := y1 - y0 ELSE dx := 0;  dy := 0 END;
	vyHostDisplay.SetDisplayMode (oldm)

END string;

PROCEDURE help (s: ARRAY OF CHAR);
VAR set: SET; x,y: SIGNED16;
BEGIN
	Input.Mouse(set,x,y);
	HelpAt(x,y,s);
	(* for consistency with service modules in ANTS used by vyPort *)
END help;

PROCEDURE helpAt (x, y: SIGNED16;  s: ARRAY OF CHAR);
BEGIN
	IF inHelp THEN RETURN END;
	Texts.WriteString(Wr,"vyTracking Help : ");
	Texts.WriteString(Wr,s);
	Texts.WriteLn(Wr);
	Texts.Append(Oberon.Log,Wr.buf);
	inHelp := TRUE;
	(* for consistency with service modules in ANTS used by vyPort *)
END helpAt;

PROCEDURE helpEnd;
BEGIN
	IF ~inHelp THEN RETURN END;
	inHelp := FALSE;
	(* for consistency with service modules in ANTS used by vyPort *)
END helpEnd;

PROCEDURE trackMouseCont (VAR keys: SET;  VAR x, y:  SIGNED16;  marker: Oberon.Marker);
	(* for consistency with ANTS functionality, should be safe procedure for mouse handling*)
	VAR k: SET;   stoptime: SIGNED32;
BEGIN
	stoptime := Oberon.Time() + maxIdleTime * Input.TimeUnit;   (* stop track mouse after idle *)
	Input.Mouse(k, x, y);
	WHILE(keys = k) DO
		Effects.TrackMouse(keys, x, y, marker);
		IF ~vyPortability.DisplayAvailable() THEN (* Display not available*)RETURN END;
		IF (k = {}) & (Oberon.Time() > stoptime) THEN
			Oberon.DrawCursor(Oberon.Mouse, Oberon.Arrow, x, y);   x := MIN(SIGNED16);  y := MIN(SIGNED16);
		RETURN END
	END;
	Oberon.DrawCursor(Oberon.Mouse, Effects.Cross, x, y)
END trackMouseCont;

BEGIN Texts.OpenWriter(Wr);
	BorderFGColor := vyHostDisplay.white;  BorderBGColor := vyHostDisplay.black;
	FGColor := vyHostDisplay.textC;  BGColor := vyHostDisplay.textbackC;  SelectColor := vyHostDisplay.bottomC;
	inHelp := FALSE;
	Rectangle := rectangle;
	Rectangles := rectangles;
	GrowRectangleRL := growRectangleRL;
	GrowRectangleR := growRectangleR;
	ZoomCentralRect := zoomCentralRect;
	TrackMouse := trackMouse;
	ScrollList := scrollList;
	MoveListEntry := moveListEntry;
	FramedString := framedString;
	String := string;
	Help := help;
	HelpAt := helpAt;
	HelpEnd := helpEnd;
	TrackMouseCont := trackMouseCont;

END vyTracking.

 - - - - - -   Testing   - - - - - -
PROCEDURE TestScroll*;
VAR
	teststring: ARRAY 10 OF ARRAY 32 OF CHAR;
	x, y: SIGNED16;  resnr: SIGNED16;  keys: SET;  res: List;  l, m, n, o: SIGNED16;
BEGIN
	COPY("test0", teststring[0]);
	COPY("test1", teststring[1]);
	COPY("test2", teststring[2]);
	COPY("test ist dieses 3", teststring[3]);
	COPY("test                     4", teststring[4]);
	COPY("test5", teststring[5]);
	COPY("test6", teststring[6]);
	COPY("test7", teststring[7]);
	resnr := 8;

	REPEAT
		Input.Mouse(keys, x, y)
	UNTIL keys # {};
	ScrollList(ArrayToList(teststring, resnr), x, y, res, l, m, n, o);
	IF res # NIL THEN
		vyHostTexts.NoteSS(0, "resname ", res.name);
		MoveListEntry(res, l, m, n, o, x, y)
	ELSE
		vyHostTexts.Note(0, "NIL ")
	END

END TestScroll;

PROCEDURE RectangleTest*;
	(** vs 0.0d0 *)	(* md  03.11.94 09:19:10 *)
	VAR x, y, dx, dy: SIGNED16;  keys: SET;
BEGIN vyHostDisplay.SetClipRect (0, 0, 800, 500);
	REPEAT Input.Mouse (keys, x, y)  UNTIL (keys # {});
	vyHostDisplay.SetCursor (vyHostDisplay.Crosshair);
	Rectangle (x - 10, y - 10, 40, 20, dx, dy);
	vyHostDisplay.SetCursor (Oberon.Arrow);
	vyHostTexts.MsgSISI ("dx", dx, "dy", dy)
END RectangleTest;

PROCEDURE RectanglesTest*;
	(** vs 0.0d0 *)	(* md  29.05.95 10:06:49 *)
	VAR x, y, w, h: ARRAY 10 OF SIGNED16;  rectCount, X, Y, dx, dy: SIGNED16;  keys: SET;
BEGIN vyHostDisplay.SetClipRect (0, 0, 800, 500);
	REPEAT Input.Mouse (keys, X, Y)  UNTIL (keys # {});
	x[0] := X;  y[0] := Y + 10;  w[0] := 20;  h[0] := 150;
	x[1] := X + 30;  y[1] := Y;  w[1] := 80;  h[1] := 50;
	rectCount := 2;
	Rectangles (x, y, w, h, rectCount, dx, dy);
	vyHostTexts.MsgSISI ("dx", dx, "dy", dy)
END RectanglesTest;

PROCEDURE GrowRectangleRLTest*;
	(** vs 0.0d0 *)	(* md  03.11.94 09:19:10 *)
	VAR x, y, dx, dy: SIGNED16;  keys: SET;
BEGIN vyHostDisplay.SetClipRect (0, 0, 800, 500);
	REPEAT Input.Mouse (keys, x, y)  UNTIL (keys # {});
	vyHostDisplay.SetCursor (vyHostDisplay.Crosshair);
	GrowRectangleRL (x - 10, y, 10, 10, dx, dy);
	vyHostDisplay.SetCursor (Oberon.Arrow);
	vyHostTexts.MsgSISI ("dx", dx, "dy", dy)
END GrowRectangleRLTest;

PROCEDURE GrowRectangleRTest*;
	(** vs 0.0d0 *)	(* md  03.11.94 09:19:10 *)
	VAR x, y, dx, dy: SIGNED16;  keys: SET;
BEGIN vyHostDisplay.SetClipRect (0, 0, 800, 500);
	REPEAT Input.Mouse (keys, x, y)  UNTIL (keys # {});
	GrowRectangleR (x - 10, y - 5, 10, 10, dx, dy);
	vyHostTexts.MsgSISI ("dx", dx, "dy", dy)
END GrowRectangleRTest;

PROCEDURE ZoomRectTest*;
	(** vs 0.0d0 *)	(* md  03.11.94 09:19:10 *)
	VAR x, y, dx, dy: SIGNED16;  keys: SET;
BEGIN vyHostDisplay.SetClipRect (0, 0, 800, 500);
	REPEAT Input.Mouse (keys, x, y)  UNTIL (keys # {});
	ZoomCentralRect (x - 10, y - 10, 40, 20, dx, dy);
	vyHostTexts.MsgSISI ("dx", dx, "dy", dy)
END ZoomRectTest;

PROCEDURE ScrollListTest*;
	(** vs 0.0d0 *)	(* md  31.05.95 12:29:53 *)
	VAR t: Texts.Text;  sel, X, Y: SIGNED16;  keys: SET;  v: Viewers.Viewer;
	content: ARRAY 128 OF CHAR;
BEGIN
	t := TextFrames.Text ("");
	Texts.WriteString(Wr, "histogram: P2");  Texts.WriteLn(Wr);
	Texts.WriteString(Wr, "scatter: P2");  Texts.WriteLn(Wr);
	Texts.WriteString(Wr, "scale");  Texts.WriteLn(Wr);
	Texts.WriteString(Wr, "dies ist ein Beispiel fr einen verdammt langen Eintrag, leider funktionieren keine Umlaute");  Texts.WriteLn(Wr);
	vyHost.AppendToText(t, Wr);

	vyHostDisplay.SetClipRect (0, 0, Display.Width, Display.Height);
	ScrollList (100, 100, t, sel, content);
	IF sel # - 1 THEN vyHostTexts.MsgSI (content, sel) END
END ScrollListTest;

PROCEDURE FramedStringTest*;
	(** vs 0.0d0 *)	(* md  03.11.94 09:19:10 *)
	VAR x, y, dx, dy: SIGNED16;  keys: SET;
BEGIN vyHostDisplay.SetClipRect (0, 0, 800, 500);
	REPEAT Input.Mouse (keys, x, y)  UNTIL (keys # {});
	vyHostDisplay.SetCursor (vyHostDisplay.Crosshair);
	FramedString (x - 10, y - 10, "Syntax10.Scn.Fnt", "dummy", dx, dy);
	vyHostDisplay.SetCursor (Oberon.Arrow);
	vyHostTexts.MsgSISI ("dx", dx, "dy", dy)
END FramedStringTest;

