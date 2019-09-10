MODULE vyGraphBase0 IN Oberon;  (** fof  **)
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


(* 0103xx fof: Complete redesign for use of images, images as double buffer, alpha channel etc. *)
(* (if images unused functionality as before ) *)

(* 001120 fof: removed bug in Pict and ReplPict*)
(* 001122 fof: Double Buffering now on Displays.Display *)
(* 010222 fof: Going to implement our graphics on Images.Image to provide
- use of alpha channels in rastered images. can be used for printing also.
- Output of Ports to Pictures.Picture / GIF Files
Problems:
- No patterns yet, will be ignored for the moment.
- No strings yet
temporary solution: write Strings to Displays.Display and read in Image from there. Slow.

We will not use Gfx, might be too slow. Whenever you needs Gfx displays, implement that in your layers.
*)


IMPORT  Display,  Pictures, Display3, Fonts, Printer, Printer3, Files,  Images, Objects, vyPortability;
CONST
	BrushSize = 100;
	cDisplayBuffer*= 0;
	cImageBuffer*=1;
TYPE
	tPatPrinter* = PROCEDURE (x, y: SIGNED16);

	tSign* = POINTER TO tSignDesc;
	tSignDesc = RECORD
		pat: Display.Pattern;
		print: tPatPrinter;
		w-, h-: SIGNED16;
		wDIV2-, hDIV2-: SIGNED16
	END;

	doubleBuffer*= POINTER TO doubleBufferDesc;
	doubleBufferDesc*= RECORD
		new-: BOOLEAN;
		displayBuffer: vyPortability.displayBuffer;
		imageBuffer: Images.Image;
		mask: Display3.Mask;
		x,y,w,h: SIGNED16;
		active-: BOOLEAN;
		type-: SIGNED16;
	END;


	(* brush for drawing in images *)
	Brush = RECORD
		brul, brur: ARRAY BrushSize OF SIGNED16;
		bufl, bufr: ARRAY BrushSize OF SIGNED16;
		bufh, brushr: SIGNED16;
		x, y: SIGNED16
	END;

VAR
	du, pu, hpu: SIGNED32;  (* Display.Unit, Printer.Unit, Printer.Unit DIV 2 *)(* fof 020624 *)
	clipMask*: Display3.Mask;
	db-: doubleBuffer;
	xPrnOrg, yPrnOrg, xPortOrg, yPortOrg: SIGNED16;
	status: SIGNED16;
	(* global draw variables, do NOT export! *)
	(* globale variablen werden nur von Prozeduren gesetzt, z.B. wegen Farbmanagment für Images etc. *)
	contextfcol-, contextbcol-: Display.Color;
	contextmode: SIGNED16;
	contextstyle: SET;
	contextpattern: SIGNED32;
	contextpensize: SIGNED16;
	contextfnt: ARRAY 64 OF CHAR;
	tmpr, tmpg, tmpb: SIGNED16;
	Enum: RECORD
		img: Images.Image;
		x, y: SIGNED16
		(* map origin on device *)
	END;

	(* image based global variables *)
	contextimg: Images.Image;
	contextfpix-, contextbpix-: Images.Pixel;
	drawingPolygon: BOOLEAN;
	brush: Brush;
	stringpict: Pictures.Picture;
	contextpatternternimage: Images.Image;
	contextalpha : SIGNED16;
	PrntPat: ARRAY 9 OF Display.Pattern;  (** printer contextpatternterns (same as in Printer3) **)
	tmpPatPic: Pictures.Picture;  (* used for converting contextpatternterns to maps *)



CONST
	display = 0;  print = 1;
	StdFnt = "Syntax10.Scn.Fnt";
	paint = Display.paint;

VAR
	copyPattern*: PROCEDURE ( sgn: tSign;  x, y: SIGNED16);
	dot*: PROCEDURE ( x, y: SIGNED16);
	replConst*: PROCEDURE ( x, y, w, h: SIGNED16);
	replString*: PROCEDURE ( X, Y: SIGNED16;  fnt, str: ARRAY OF CHAR);
	replPict*: PROCEDURE (picture: Pictures.Picture;  px, py, x, y, w, h: SIGNED16);
	pict*: PROCEDURE (picture: Pictures.Picture;  x, y, w, h, dx, dy: SIGNED16);
	stretchedpict*: PROCEDURE (picture: Pictures.Picture;  x, y, w, h, dx, dy, dw, dh: SIGNED16);
	image*: PROCEDURE (VAR image: Images.Image;  x, y, w, h, dx, dy: SIGNED16);
	stretchedimage*: PROCEDURE (VAR image: Images.Image;  x, y, w, h, dx, dy, dw, dh: SIGNED16);
	line*: PROCEDURE ( x0, y0, x1, y1 : SIGNED16);
	circle*: PROCEDURE ( x, y, r: SIGNED16 );
	ellipse*: PROCEDURE ( x, y, a, b: SIGNED16 );
	rect*: PROCEDURE ( x, y, w, h: SIGNED16);
	rect3d*: PROCEDURE ( x, y, a, b: SIGNED16);
	paintrect*: PROCEDURE ( x, y, w, h: SIGNED16);
	poly* : PROCEDURE ( VAR x, y: ARRAY OF SIGNED16;  n: SIGNED16);

	(** setting global variables *)
PROCEDURE SetBackColor* (col: Display.Color);
BEGIN
	contextbcol := col;
Display.GetColor(col, tmpr, tmpg, tmpb);  Images.SetRGBA(contextbpix, tmpr, tmpg, tmpb, contextalpha) END SetBackColor;
PROCEDURE SetForeColor* (col: Display.Color);
BEGIN
	contextfcol := col ;
	Display.GetColor(col, tmpr, tmpg, tmpb);  Images.SetRGBA(contextfpix, tmpr, tmpg, tmpb, contextalpha)
END SetForeColor;

PROCEDURE SetFColRGBA* (r, g, b, a: SIGNED16);
BEGIN
	Images.SetRGBA(contextfpix, r, g, b, a);  contextfcol := Display.RGB(r, g, b)
END SetFColRGBA;

PROCEDURE SetBColRGBA* (r, g, b, a: SIGNED16);
BEGIN
	Images.SetRGBA(contextbpix, r, g, b, a);  contextbcol := Display.RGB(r, g, b)
END SetBColRGBA;

PROCEDURE SetPenSize* (size : SIGNED16);  (*! remove penSize !! *)
BEGIN	contextpensize := size 	END SetPenSize;
PROCEDURE SetDisplayMode* (m: SIGNED16);
BEGIN	contextmode := m 	END SetDisplayMode;
PROCEDURE SetDisplayStyle* (s: SET);
BEGIN	contextstyle := s 	END SetDisplayStyle;
PROCEDURE SetDisplayPattern* (p: SIGNED32);
BEGIN contextpattern := p 	END SetDisplayPattern;
PROCEDURE SetFont* (f: ARRAY OF CHAR);
BEGIN COPY(f, contextfnt) 	END SetFont;
PROCEDURE SetAlpha* (a: SIGNED16);
BEGIN contextalpha := a
END SetAlpha;

PROCEDURE Min (x, y: SIGNED16): SIGNED16;
BEGIN
	IF x < y THEN RETURN x ELSE RETURN y END
END Min;

PROCEDURE Max (x, y: SIGNED16): SIGNED16;
BEGIN
	IF x > y THEN RETURN x ELSE RETURN y END
END Max;

PROCEDURE StandardizeRect (VAR x, y, w, h: SIGNED16);
BEGIN IF w < 0 THEN x := x + w;  w := - w END;
	IF h < 0 THEN y := y + h;  h := - h END
END StandardizeRect;

PROCEDURE RectInRect (x, y, w, h, X, Y, W, H: SIGNED16): BOOLEAN;
BEGIN StandardizeRect (x, y, w, h);  StandardizeRect (X, Y, W, H);
	RETURN (x >= X) & (x + w <= X + W) & (y >= Y) & (y + h <= Y + H)
END RectInRect;

PROCEDURE RectIntersection (VAR x, y, w, h: SIGNED16;  X, Y, W, H: SIGNED16);
	VAR x1, y1, X1, Y1: SIGNED16;
BEGIN StandardizeRect (x, y, w, h);  StandardizeRect (X, Y, W, H);
	x1 := x + w;  y1 := y + h;  X1 := X + W;  Y1 := Y + H;
	x := Max (x, X);
	y := Max (y, Y);
	x1 := Min (x1, X1);
	y1 := Min (y1, Y1);
	w := x1 - x;  h := y1 - y;
	IF w < 0 THEN w := 0;  h := 0 END;
	IF h < 0 THEN w := 0;  h := 0 END
END RectIntersection;

PROCEDURE PlacedRectIntersect (VAR x, y, w, h, dx, dy: SIGNED16;  X, Y, W, H: SIGNED16);
BEGIN
	IF (dx + w < X) OR (dx > X + W) OR (dy + h < Y) OR (dy > Y + H) THEN w := 0;  h := 0;  RETURN END;
	IF dx < X THEN DEC(w, X - dx);  INC(x, X - dx) ;  dx := X END;
	IF dy < Y THEN DEC(h, Y - dy);  INC(y, Y - dy) ;  dy := Y END;
	IF dx + w > X + W THEN w := X + W - dx END;
	IF dy + h > Y + H THEN h := Y + H - dy END
END PlacedRectIntersect;


PROCEDURE EmptyIntersection (x, y, w, h, X, Y, W, H: SIGNED16): BOOLEAN;
BEGIN StandardizeRect (x, y, w, h);  StandardizeRect (X, Y, W, H);
	RETURN (x > X + W) OR (X > x + w) OR (y > Y + H) OR (Y > y + h)
END EmptyIntersection;

(** Screen primitives *)

PROCEDURE CopyPatternC (sgn: tSign;  x, y: SIGNED16);
	VAR w, h: SIGNED16;
BEGIN
	Display.GetDim(sgn.pat, w, h);
	Display3.CopyPattern (clipMask, contextfcol, sgn.pat, x, y, contextmode)
END CopyPatternC;

PROCEDURE DotC (x, y: SIGNED16);
BEGIN	Display3.Dot ( clipMask, contextfcol, x, y, contextmode) END DotC;

PROCEDURE ReplConstC (x, y, w, h: SIGNED16);
BEGIN	Display3.ReplConst (clipMask, contextfcol, x, y, w, h, contextmode) END ReplConstC;

PROCEDURE ReplStringC (X, Y: SIGNED16;  fnt, str: ARRAY OF CHAR);
	VAR f: Fonts.Font;
BEGIN
	f := Fonts.This (fnt);
	IF f = NIL THEN f := Fonts.This(StdFnt) END;
	Display3.String(clipMask, contextfcol, X, Y, f, str, contextmode)
END ReplStringC;

PROCEDURE LineC (x0, y0, x1, y1 : SIGNED16);
BEGIN Display3.Line (clipMask, contextfcol, contextpattern, x0, y0, x1, y1, contextpensize, contextmode)END LineC;

PROCEDURE CircleC (x, y, r: SIGNED16);
BEGIN Display3.Circle (clipMask, contextfcol, contextpattern , x, y, r, contextpensize, contextstyle, contextmode) END CircleC;

PROCEDURE EllipseC (x, y, a, b: SIGNED16);
BEGIN Display3.Ellipse(clipMask, contextfcol, contextpattern , x, y, a, b, contextpensize, contextstyle, contextmode) END EllipseC;

PROCEDURE RectC (x, y, w, h: SIGNED16);
BEGIN Display3.Rect(clipMask, contextfcol, contextpattern, x, y, w, h, contextpensize, contextmode) END RectC;

PROCEDURE Rect3DC (x, y, w, h: SIGNED16);
BEGIN Display3.Rect3D(clipMask, contextfcol, contextbcol, x, y, w, h, contextpensize, contextmode) END Rect3DC;

PROCEDURE PaintRectC (x, y, w, h: SIGNED16);
BEGIN	Display3.FillPattern(clipMask, contextfcol, contextpattern, 0, 0, x, y, w, h, contextmode) END PaintRectC;

PROCEDURE PolyC (VAR x, y: ARRAY OF SIGNED16;  n: SIGNED16);
BEGIN Display3.Poly(clipMask, contextfcol, contextpattern, x, y, n, 1, contextstyle, contextmode) END PolyC;

PROCEDURE ReplPictC (picture: Pictures.Picture;  px, py, x, y, w, h: SIGNED16);
BEGIN	Display3.ReplPict(clipMask, picture, px, py, x, y, w, h, contextmode) END ReplPictC;

PROCEDURE PictC (picture: Pictures.Picture;  x, y, w, h, dx, dy: SIGNED16);
BEGIN Display3.Pict(clipMask, picture, x, y, w, h, dx, dy, contextmode) END PictC;

PROCEDURE StretchedPictC (picture: Pictures.Picture;  x, y, w, h, dx, dy, dw, dh : SIGNED16);
BEGIN vyPortability.StretchedPict(clipMask, picture, x, y, w, h, dx, dy, dw, dh, contextmode) END StretchedPictC;

PROCEDURE RestoreRuns (x, y, w, h: SIGNED16);
	VAR x0, len, l, i, j, y0: SIGNED16;  line: ARRAY 512 OF CHAR;  b: CHAR;
BEGIN
	x0 := x;  y0 := 0;
	WHILE h > 0 DO
		x := x0;  len := w;
		REPEAT
			IF len < LEN(line) THEN l := len ELSE l := LEN(line) END;
			Images.GetPixels(Enum.img, x - Enum.x, y - Enum.y, l, Images.D8, line, Images.SrcCopy);
			i := 0;
			WHILE i < l DO
				b := line[i];  j := i + 1;
				WHILE (j < l) & (line[j] = b) DO INC(j) END;
				Display.ReplConst(ORD(b), x + i, y, j - i, 1, Display.replace);
				i := j
			END;
			INC(x, l);  DEC(len, l)
		UNTIL len = 0;
		DEC(h);  INC(y) ;  INC(y0)
	END
END RestoreRuns;

PROCEDURE RestoreLines (x, y, w, h: SIGNED16);
	VAR x0, lineLen, len, l: SIGNED16;  line: ARRAY 512 OF CHAR;  tmp: Images.Image;
BEGIN
	x0 := x;  lineLen := 8 * LEN(line) DIV Images.DisplayFormat.bpp;
	NEW(tmp);  Images.InitBuf(tmp, lineLen, 1, Images.DisplayFormat, 0, 0, line);
	WHILE h > 0 DO
		x := x0;  len := w;
		REPEAT
			IF len < lineLen THEN l := len ELSE l := lineLen END;
			Images.GetPixels(Enum.img, x - Enum.x, y - Enum.y, l, Images.DisplayFormat, line, Images.SrcCopy);
			Display.TransferBlock(line, 0, 0, x, y, l, 1, Display.set);
			INC(x, l);  DEC(len, l)
		UNTIL len = 0;
		DEC(h);  INC(y)
	END
END RestoreLines;

PROCEDURE RestoreBlock (x, y, w, h: SIGNED16);
	VAR offset: SIGNED32;
BEGIN
	offset := (y - Enum.y ) * Enum.img.bpr + (x - Enum.x ) * Enum.img.fmt.bpp DIV 8;
	Display.TransferBlock(Enum.img.mem^, offset, Enum.img.bpr, x, y, w, h, Display.set)
END RestoreBlock;



(** restore frame area **)
PROCEDURE ImageC (VAR img: Images.Image;  x, y, w, h, dx, dy: SIGNED16);
	VAR rx, ry, rw, rh, rxx, ryy: SIGNED16;
BEGIN
	rx := dx;  ry := dy;  rw := w;  rh := h;  rxx := x;  ryy := y;
	IF clipMask = NIL THEN
		PlacedRectIntersect(rxx, ryy, rw, rh, rx, ry, 0, 0, SHORT(vyPortability.DisplayWidth()), SHORT(vyPortability.DisplayHeight()));
		(*
		IF (rx+rw <0) OR (rx > Display.cur.width) OR (ry+rh <0 ) OR (ry > Display.cur.height) THEN RETURN END;
		IF rx <0 THEN rw := rw+rx; (*x := -rx; *) rx := 0; END;
		IF ry <0 THEN rh := rh+ry; (* y := -ry; *) ry := 0; END;
		IF rx + rw > Display.cur.width THEN rw := SHORT(Display.cur.width) - rx END;
		IF ry + rh > Display.cur.height THEN rh := SHORT(Display.cur.height) -ry END;
		*)
		IF (rw <= 0) OR (rh <= 0) THEN RETURN END
	ELSE
		PlacedRectIntersect(rxx, ryy, rw, rh, rx, ry, clipMask.X, clipMask.Y , clipMask.W, clipMask.H);
		(*
		IF rx < clipMask.X THEN DEC(rw, clipMask.X - rx); rx := clipMask.X END;
		IF rx + rw > clipMask.X + clipMask.W THEN rw := clipMask.X + clipMask.W - rx END;
		IF ry < clipMask.Y THEN DEC(rh, clipMask.Y - ry); ry := clipMask.Y END;
		IF ry + rh > clipMask.Y + clipMask.H THEN rh := clipMask.Y + clipMask.H - ry END;
		*)
		IF (rw <= 0) OR (rh <= 0) THEN RETURN END
	END;
	IF (rw > 0) & (rh > 0) THEN
		Enum.img := img;  Enum.x := dx - x;  Enum.y := dy - y;  (*?? rx-x, ry-y ?? *)
		IF Display.TransferFormat(dx) = Display.unknown THEN	(* can't use TransferBlock *)
			IF clipMask # NIL THEN
				Display3.EnumRect(clipMask, rx, ry, rw, rh, RestoreRuns)
			ELSE
				RestoreRuns(rx, ry, rw, rh)
			END
		ELSIF Images.Same(Images.DisplayFormat, img.fmt) & (img.mem # NIL)
			(* & ~(Images.alpha IN img.fmt.components) *)THEN
			IF clipMask # NIL THEN
				Display3.EnumRect(clipMask, rx, ry, rw, rh, RestoreBlock)
			ELSE
				RestoreBlock(rx, ry, rw, rh)
			END
		ELSE	(* must convert to display format *)
			IF clipMask # NIL THEN
				Display3.EnumRect(clipMask, rx, ry, rw, rh, RestoreLines)
			ELSE
				RestoreLines(rx, ry, rw, rh)
			END
		END
	END
END ImageC;


PROCEDURE StretchedImageC (VAR sP: Images.Image;  X, Y, W, H, DX, DY, DW, DH: SIGNED16);
	VAR y, x0, x1: SIGNED16;  oldpix, pix: Images.Pixel;
	xe, ye: SIGNED16;
	nx, ny, nw, nh, ndx, ndy, ndw, ndh: SIGNED16;  thisx, nextx, thisy, nexty: SIGNED16;
	scalex, scaley: FLOAT64;  r, g, b, a: SIGNED16;
	scalexl, scaleyl: SIGNED16;
BEGIN
	IF (W = DW) & (H = DH) THEN ImageC(sP, X, Y, W, H, DX, DY) END;
(*	ASSERT(RectInRect(X, Y, W, H, 0, 0, sP.width, sP.height), 100);*)
	RectIntersection(X,Y,W,H,0,0,sP.width, sP.height);
	(* first check if displayed: *)
	IF (DW = 0) OR (DH = 0) THEN RETURN END;
	oldpix := contextfpix;

	(* general case: non integer stretch values *)
	(*! speed up ! *)

	(* compute displayed area *)
	ndx := DX;  ndy := DY;  ndw := DW;  ndh := DH;
	nx := X;  ny := Y;  nw := W;  nh := H;


	IF clipMask = NIL THEN
		RectIntersection(ndx, ndy, ndw, ndh, 0, 0, SHORT(vyPortability.DisplayWidth()), SHORT(vyPortability.DisplayHeight()))
	ELSE
		RectIntersection(ndx, ndy, ndw, ndh, clipMask.X, clipMask.Y, clipMask.W, clipMask.H)
	END;

	nx := SHORT(ENTIER(X + W * ((ndx - DX) / DW)));
	ny := SHORT(ENTIER(Y + H * ((ndy - DY) / DH) ));
	nw := SHORT(ENTIER(W * (ndw / DW)));
	nh := SHORT(ENTIER(H * (ndh / DH)));
	xe := SHORT(ENTIER(X + W * ((ndx + ndw - DX) / DW) + 0.5));
	ye := SHORT(ENTIER(Y + H * ((ndy + ndh - DY) / DH) + 0.5 ));
	xe := Min(xe + 1, X + W);
	ye := Min(ye + 1, Y + H);


	scalexl := DW DIV W;  scaleyl := DH DIV H;
	IF (scalexl * W = DW) & (scaleyl * H = DH) THEN
		y := ny;
		WHILE y < ye DO
			thisy := DY + (y - Y) * scaleyl;
			nexty := scaleyl;  (* nexty is the width (!!) *)
			x0 := nx;
			WHILE x0 < xe DO
				x1 := x0;
				IGetRun(sP, pix, x1, y);
				IF x1 > xe THEN x1 := xe END;
				thisx := DX + (x0 - X) * scalexl;
				nextx := (x1 - x0) * scalexl;  (* nextx is the width (!!) *)
				Images.GetRGBA(pix, r, g, b, a);
				contextfcol := Display.RGB(r, g, b);
				ReplConstC(thisx, thisy, nextx, nexty);
				x0 := x1
			END;
			INC(y)
		END

	ELSE
		(* non integer valued stretch *)
		scalex := DW / W;  scaley := DH / H;
		y := ny;
		WHILE y < ye DO
			thisy := SHORT(ENTIER(DY + (y - Y) * scaley + 0.5));
			nexty := SHORT(ENTIER(DY + (y + 1 - Y) * scaley + 0.5));
			x0 := nx;
			WHILE x0 < xe DO
				x1 := x0;
				IGetRun(sP, pix, x1, y);
				IF x1 > xe THEN x1 := xe END;
				thisx := SHORT(ENTIER(DX + (x0 - X) * scalex + 0.5));
				nextx := SHORT(ENTIER(DX + (x1 - X) * scalex + 0.5));
				Images.GetRGBA(pix, r, g, b, a);
				contextfcol := Display.RGB(r, g, b);
				ReplConstC(thisx, thisy, nextx - thisx, nexty - thisy);
				x0 := x1
			END;
			INC(y)
		END
	END;
	contextfpix := oldpix
END StretchedImageC;

(** initialize picture from map **)
PROCEDURE ImageToPict (img: Images.Image;  pict: Pictures.Picture);
VAR
	i, y, r, g, b, a, x, w: SIGNED16;  pal: Images.Palette;  fmt: Images.Format;  byte: ARRAY 256 OF CHAR;
	int: ARRAY 256 OF SIGNED16;
BEGIN
	Pictures.Create(pict, img.width, img.height, 8);
	(* uses display palette *)
	IF img.fmt.pal # NIL THEN	(* modify picture palette *)
		i := 0;  pal := img.fmt.pal;
		WHILE i < pal.used DO
			Images.GetRGBA(pal.col[i], r, g, b, a);
			Pictures.SetColor(pict, i, r, g, b);
			INC(i)
		END;
		Images.InitPaletteFormat(fmt, pal)
	ELSE
		fmt := Images.D8
	END;
	y := 0;
	WHILE y < img.height DO
		x := 0;
		WHILE x < img.width DO
			w := img.width - x;
			IF w > 256 THEN w := 256 END;
			Images.GetPixels(img, x, y, w, fmt, byte, Images.SrcCopy);
			FOR i := 0 TO w - 1 DO
				int[i] := ORD(byte[i])
			END;
			Pictures.PutLine(pict, int, x, y, w);
			INC(x, w)
		END;
		INC(y)
	END
END ImageToPict;


PROCEDURE ImageP (VAR img: Images.Image;  x, y, w, h, dx, dy: SIGNED16);
	VAR p: Pictures.Picture;
BEGIN
	NEW(p);  ImageToPict(img, p);
	pictPrn(p, x, y, w, h, dx, dy)
END ImageP;

PROCEDURE StretchedImageP (VAR img: Images.Image;  x, y, w, h, dx, dy, dw, dh: SIGNED16);
	VAR p: Pictures.Picture;
BEGIN
	NEW(p);  ImageToPict(img, p);
	stretchedpictPrn(p, x, y, w, h, dx, dy, dw, dh)

END StretchedImageP;

(** image based primitives *)


PROCEDURE Doti (x, y: SIGNED16);
BEGIN
	IF (x < 0) OR (x > contextimg.width - 1) THEN RETURN END;
	IF (y < 0) OR (y > contextimg.height - 1) THEN RETURN END;
	Images.Put(contextimg, x, y, contextfpix, Images.SrcOverDst)
END Doti;

PROCEDURE ReplConsti (x, y, w, h: SIGNED16);
BEGIN
	RectIntersection(x, y, w, h, 0, 0, contextimg.width, contextimg.height);
	IF (w <= 0) OR (h <= 0) THEN RETURN END;
	Images.Fill(contextimg, x, y, x + w, y + h, contextfpix, Images.SrcOverDst)
END ReplConsti;

PROCEDURE DirectReplConsti (x, y, w, h: SIGNED16);  (* faster, but assert x,y in Image range FIRST !! *)
BEGIN
	IF (x>=0) & (y>=0) & (1.0D0+x+LONG(w) < 10000) & (1.0D0+ y+LONG(h) < 10000) THEN
	Images.Fill(contextimg, x, y, x + w, y + h, contextfpix, Images.SrcOverDst)
	END;
END DirectReplConsti;

PROCEDURE PatternToImage (pat: Display.Pattern;  patimg: Images.Image);
	VAR w, h, y, x: SIGNED16;
BEGIN
	ASSERT(pat # 0, 100);
	IF (1 <= pat) & (pat <= 8) THEN pat := PrntPat[pat] END;
	Display.GetDim(pat, w, h);
	Images.Create(patimg, w, h, Images.BGRA8888);

	(* it seems that the only portable way to access a pattern is to render it into a picture first *)
	IF tmpPatPic = NIL THEN NEW(tmpPatPic) END;
	IF (tmpPatPic.width < w) OR (tmpPatPic.height < h) THEN Pictures.Create(tmpPatPic, w, h, 8) END;
	Pictures.ReplConst(tmpPatPic, 0, 0, 0, w, h, Display.replace);
	Pictures.CopyPattern(tmpPatPic, 1, pat, 0, 0, Display.paint);

	y := 0;
	WHILE y < h DO
		x := 0;
		WHILE x < w DO
			IF Pictures.Get(tmpPatPic, x, y) # 0 THEN
				Images.Put(patimg, x, y, contextfpix, Images.SrcCopy)
			ELSE
				Images.Put(patimg, x, y, contextbpix, Images.SrcCopy)
			END;
			INC(x)
		END;
		INC(y)
	END
	(*
	Pictures.DisplayBlock(tmpPatPic,0,0,1,1,0,0,Display.replace); (*! remove when Pictures repaired, Mac specific *)
	*)
END PatternToImage;

PROCEDURE FillPatterni (pX, pY, X, Y, W, H: SIGNED16);
BEGIN
	RectIntersection(X, Y, W, H, 0, 0, contextimg.width, contextimg.height);
	IF (W <= 0) OR (H <= 0) THEN RETURN END;
	IF contextpattern = Display.solid THEN
		DirectReplConsti(X, Y, W, H)
	ELSE
		PatternToImage(contextpattern, contextpatternternimage);
		Images.FillPattern(contextpatternternimage, contextimg, X, Y, X + W, Y + H, pX, pY, Images.SrcOverDst)
	END
END FillPatterni;


PROCEDURE CopyPatterni ( sgn: tSign;  X, Y: SIGNED16);
	VAR W, H: SIGNED16;  pat: Display.Pattern;
BEGIN
	Display.GetDim(sgn.pat, W, H);
	pat := contextpattern;
	contextpattern := sgn.pat;
	(*! use Patterni ! *)
	FillPatterni(X, Y, X, Y, W, H);
	contextpattern := pat
	(* ReplConsti(X-W DIV 2, Y-H DIV 2, W,H); *)
END CopyPatterni;

PROCEDURE Recti (X, Y, W, H: SIGNED16);
	VAR width: SIGNED16;
BEGIN
	width := Min(contextpensize, Min(H DIV 2, W DIV 2));
	ReplConsti( X, Y, width, H);
	ReplConsti(X + W - width, Y, width, H);
	ReplConsti(X + width, Y, W - 2 * width, width);
	ReplConsti(X + width, Y + H - width, W - 2 * width, width)
END Recti;

PROCEDURE Rect3Di (X, Y, W, H: SIGNED16);
	VAR width: SIGNED16;  pix: Images.Pixel;
BEGIN
	pix := contextfpix;
	width := Min(contextpensize, Min(H DIV 2, W DIV 2));
	WHILE width > 0 DO
		contextfpix := contextfpix;
		ReplConsti(X, Y, W, 1);
		contextfpix := contextbpix;
		ReplConsti(X, Y + H - 1, W, 1);
		ReplConsti(X, Y, 1, H);
		contextfpix := pix;
		ReplConsti(X + W - 1, Y, 1, H);
		DEC(width);  INC(X);  INC(Y);  DEC(W, 2);  DEC(H, 2)
	END
END Rect3Di;

PROCEDURE BrushJump (VAR b: Brush;  x, y: SIGNED16);
	VAR i: SIGNED16;
BEGIN
	IF (b.x # x) OR (b.y # y) THEN
		b.x := x;  b.y := y;
		FOR i := 0 TO b.bufh - 1 DO b.bufl[i] := b.brul[i] + b.x;  b.bufr[i] := b.brur[i] + b.x END
	END
END BrushJump;

PROCEDURE BrushWalk (VAR b: Brush;  x, y: SIGNED16);
	VAR i, dx, dy, t: SIGNED16;
PROCEDURE Max (x, y: SIGNED16): SIGNED16;
BEGIN IF x > y THEN RETURN x ELSE RETURN y END
END Max;
BEGIN
	dx := x - b.x;  dy := y - b.y;  t := b.bufh - 1;
	IF dy = 0 THEN (* horizontal move *)
		IF dx < 0 THEN
			FOR i := 0 TO t DO b.bufl[i] := Min(b.bufl[i], b.brul[i] + x) END
		ELSIF dx > 0 THEN
			FOR i := 0 TO t DO b.bufr[i] := Max(b.bufr[i], b.brur[i] + x) END
		END
	ELSIF dy > 0 THEN (* up *)
		FillPatterni( 0, 0, b.bufl[0], b.y - b.brushr, b.bufr[0] - b.bufl[0] + 1, 1);
		FOR i := 0 TO b.bufh - 2 DO
			b.bufl[i] := Min(b.bufl[i + 1], b.brul[i] + x);  b.bufr[i] := Max(b.bufr[i + 1], b.brur[i] + x)
		END;
		b.bufl[t] := b.brul[t] + x;  b.bufr[t] := b.brur[t] + x

	ELSE (* dy < 0 *)(* down *)
		FillPatterni(0, 0, b.bufl[t], b.y - b.brushr + b.bufh - 1, b.bufr[t] - b.bufl[t] + 1, 1);
		FOR i := b.bufh - 1 TO 1 BY - 1 DO
			b.bufl[i] := Min(b.bufl[i - 1], b.brul[i] + x);  b.bufr[i] := Max(b.bufr[i - 1], b.brur[i] + x)
		END;
		b.bufl[0] := b.brul[0] + x;  b.bufr[0] := b.brur[0] + x
	END;
	b.x := x;  b.y := y
END BrushWalk;

PROCEDURE BrushFlush (VAR b: Brush);
	VAR i: SIGNED16;
BEGIN
	FOR i := 0 TO b.bufh - 1 DO
		FillPatterni( 0, 0, b.bufl[i], b.y + i - b.brushr, b.bufr[i] - b.bufl[i] + 1, 1)
	END
END BrushFlush;

PROCEDURE InitBrush (VAR b: Brush;  w: SIGNED16);
	VAR r, x, y, d, dx, dy: SIGNED16;

PROCEDURE Set (x, y: SIGNED16);
BEGIN
	b.brul[y + r] := - x + 1;  b.brur[y + r] := x;  b.brul[ - y + r] := - x + 1;  b.brur[ - y + r] := x;
	IF y + r > b.bufh THEN b.bufh := y + r END
END Set;

BEGIN b.bufh := 0;
	(* b.contextimg := contextimg; b.col := col; b.mode := mode; b.contextpattern := contextpattern; *)
	IF w >= BrushSize THEN w := BrushSize - 1 END;

	b.x := MIN(SIGNED16);  b.y := MIN(SIGNED16);
	r := w DIV 2;  (* radius *)
	IF r < 0 THEN r := 1 END;
	x := r;  y := 0;  d := 2 * r;  dx := 4 * r;  dy := 0;
	Set(x, y);
	WHILE y # r DO
		WHILE d <= 1 DO DEC(x);  DEC(dx, 4);  INC(d, dx) END;
		INC(y);  Set(x, y);  INC(dy, 4);  DEC(d, dy)
	END;
	b.brushr := r;  INC(b.bufh)
END InitBrush;

PROCEDURE Linei (X, Y, X1, Y1: SIGNED16);
	VAR x, y, dx, dy, inx, iny, d, dy2, dx2: SIGNED16;
BEGIN
	dx := contextpensize DIV 2;  dx2 := contextpensize + 1;
	x := X;  y := Y;  dx := X1 - X;  dy := Y1 - Y;
	IF contextpensize > 1 THEN
		IF drawingPolygon THEN
		ELSE InitBrush(brush, contextpensize);  BrushJump(brush, x, y)
		END;
		IF ABS(dy) > ABS(dx) THEN
			d := - ABS(dx);  dy2 := 2 * ABS(dy);  dx2 := 2 * ABS(dx);
			IF dx < 0 THEN inx := - 1 ELSE inx := 1 END;
			IF dy < 0 THEN iny := - 1 ELSE iny := 1 END;
			WHILE y # Y1 DO
				INC(y, iny);
				INC(d, dx2);
				IF d > 0 THEN INC(x, inx);  DEC(d, dy2) END;
				BrushWalk(brush, x, y)
			END
		ELSE
			d := - ABS(dx);  dy2 := 2 * ABS(dy);  dx2 := 2 * ABS(dx);
			IF dx < 0 THEN inx := - 1 ELSE inx := 1 END;
			IF dy < 0 THEN iny := - 1 ELSE iny := 1 END;
			WHILE x # X1 DO
				INC(x, inx);
				INC(d, dy2);
				IF d > 0 THEN INC(y, iny);  DEC(d, dx2) END;
				BrushWalk(brush, x, y)
			END
		END;
		IF ~drawingPolygon THEN BrushFlush(brush) END
	ELSE
		IF ABS(dy) > ABS(dx) THEN
			d := - ABS(dx);  dy2 := 2 * ABS(dy);  dx2 := 2 * ABS(dx);
			IF dx < 0 THEN inx := - 1 ELSE inx := 1 END;
			IF dy < 0 THEN iny := - 1 ELSE iny := 1 END;
			(* fof 970716 *)
			IF dx = 0 THEN
				IF contextpattern = Display.solid THEN
					ReplConsti( x, y, 1, dy)
				ELSE FillPatterni(0, 0, x, y, 1, dy)
				END
			ELSIF dy = 0 THEN
				IF contextpattern = Display.solid THEN
					ReplConsti(x, y, dx, 1)
				ELSE FillPatterni(0, 0, x, y, dx, 1)
				END
			ELSE
				(* fof 970716 *)
				WHILE y # Y1 DO
					INC(y, iny);
					INC(d, dx2);
					IF d > 0 THEN INC(x, inx);  DEC(d, dy2) END;
					IF contextpattern = Display.solid THEN
						Doti( x, y)
					ELSE FillPatterni(0, 0, x, y, 1, 1)
					END
				END
			END
		ELSE
			d := - ABS(dx);  dy2 := 2 * ABS(dy);  dx2 := 2 * ABS(dx);
			IF dx < 0 THEN inx := - 1 ELSE inx := 1 END;
			IF dy < 0 THEN iny := - 1 ELSE iny := 1 END;
			IF dx = 0 THEN
				IF contextpattern = Display.solid THEN
					ReplConsti( x, y, 1, dy)
				ELSE FillPatterni( 0, 0, x, y, 1, dy)
				END
			ELSIF dy = 0 THEN
				IF contextpattern = Display.solid THEN
					ReplConsti(x, y, dx, 1)
				ELSE FillPatterni(0, 0, x, y, dx, 1)
				END
			ELSE
				(* fof 970716 *)

				WHILE x # X1 DO
					INC(x, inx);
					INC(d, dy2);
					IF d > 0 THEN INC(y, iny);  DEC(d, dx2) END;

					IF contextpattern = Display.solid THEN
						Doti( x, y)
					ELSE FillPatterni(0, 0, x, y, 1, 1)
					END
				END
			END
		END
	END
END Linei;

PROCEDURE FilledPolyi (VAR X, Y: ARRAY OF SIGNED16;  n: SIGNED16);
TYPE
	Run = POINTER TO RunDesc0;
	RunDesc0 = RECORD next: Run;  x: SIGNED16 END;
VAR
	scan: ARRAY 2000 OF Run;  free, s: Run;
	i, miny, maxy, x0, x1: SIGNED16;

PROCEDURE New (VAR s: Run);
BEGIN IF free = NIL THEN NEW(s) ELSE s := free;  free := free.next;  s.next := NIL END
END New;

PROCEDURE Free (VAR s: Run);
	VAR s0: Run;
BEGIN
	IF s # NIL THEN
		s0 := s;  WHILE s0.next # NIL DO s0 := s0.next END;
		s0.next := free;  free := s;  s := NIL
	END
END Free;

PROCEDURE Insert (VAR s: Run;  x: SIGNED16);
	VAR t, t0: Run;
BEGIN
	IF s = NIL THEN New(s);  s.x := x
	ELSE
		New(t);  t.x := x;
		IF x < s.x THEN t.next := s;  s := t
		ELSE t0 := s;
			WHILE (t0.next # NIL) & (t0.next.x < x) DO t0 := t0.next END;
			IF t0.next = NIL THEN t0.next := t
			ELSE t.next := t0.next;  t0.next := t
			END
		END
	END
END Insert;
PROCEDURE line (x1, y1, x2, y2: SIGNED16);  (* standard bresenham *)
	VAR x, y, d, dx, dy, incx, incy: SIGNED16;
BEGIN
	(* Seg(x1,y1); *)
	x := x1;  y := y1;  dx := (x2 - x1) * 2;  dy := (y2 - y1) * 2;
	incx := 0;
	IF dx < 0 THEN incx := - 1;  dx := - dx
	ELSIF dx > 0 THEN incx := 1
	END;
	incy := 0;
	IF dy < 0 THEN incy := - 1;  dy := - dy ELSIF dy > 0 THEN incy := 1 END;
	d := incx * (x1 - x2);
	WHILE y # y2 DO
		INC(y, incy);  INC(d, dx);
		WHILE d > 0 DO INC(x, incx);  DEC(d, dy) END;
		IF incy > 0 THEN Insert(scan[y], x) ELSE Insert(scan[y + 1], x) END
	END
END line;
BEGIN free := NIL;
	miny := MAX(SIGNED16);  maxy := MIN(SIGNED16);
	i := 0;  WHILE i < n DO IF Y[i] < miny THEN miny := Y[i] END;  IF Y[i] > maxy THEN maxy := Y[i] END;  INC(i) END;
	i := 0;  WHILE i <= maxy - miny DO scan[i] := NIL;  INC(i) END;
	i := 1;
	WHILE i < n DO
		line(X[i - 1], Y[i - 1] - miny, X[i], Y[i] - miny);  INC(i)
	END;
	line(X[n - 1], Y[n - 1] - miny, X[0], Y[0] - miny);

	i := 0;
	WHILE i <= maxy - miny DO
		s := scan[i];
		WHILE s # NIL DO
			x0 := s.x;  s := s.next;
			IF s = NIL THEN x1 := x0 ELSE x1 := s.x;  s := s.next END;
			FillPatterni(0, 0, x0, i + miny, x1 - x0 + 1, 1)
		END;
		Free(scan[i]);
		INC(i)
	END
END FilledPolyi;

PROCEDURE Polyi (VAR X, Y: ARRAY OF SIGNED16;  n: SIGNED16 );
	VAR i: SIGNED16;
BEGIN
	IF Display3.filled IN contextstyle THEN FilledPolyi( X, Y, n)
	ELSE
		drawingPolygon := TRUE;
		IF contextpensize > 1 THEN InitBrush(brush, contextpensize);  BrushJump(brush, X[0], Y[0]) END;
		i := 0;
		WHILE i < n - 1 DO
			Linei(X[i], Y[i], X[i + 1], Y[i + 1]);  INC(i)
		END;
		drawingPolygon := FALSE;
		IF contextpensize > 1 THEN BrushFlush(brush) END
	END
END Polyi;

PROCEDURE Ellipsei ( X, Y, a, b: SIGNED16);
	VAR x1, y1: SIGNED16;  d, dx, dy, x2, y2, a1, a2, a8, b1, b2, b8: SIGNED32;

PROCEDURE Dot4 (x1, x2, y1, y2: SIGNED16);
BEGIN
	IF contextpattern = Display.solid THEN
		Doti(x1, y1);  Doti(x1, y2);
		Doti(x2, y1);  Doti(x2, y2)
	ELSE
		FillPatterni(0, 0, x1, y1, 1, 1);  FillPatterni(0, 0, x1, y2, 1, 1);
		FillPatterni(0, 0, x2, y1, 1, 1);  FillPatterni(0, 0, x2, y2, 1, 1)
	END
END Dot4;

BEGIN
	IF (a < 600) & (b < 600) THEN
		a1 := a;  a2 := a1 * a1;  a8 := 8 * a2;  b1 := b;  b2 := b1 * b1;  b8 := 8 * b2;
		x1 := a;  y1 := 0;  x2 := a1 * b2;  y2 := 0;  dx := b8 * (a1 - 1);  dy := 4 * a2;  d := b2 * (1 - 4 * a1);
		WHILE y2 < x2 DO
			Dot4(X - x1(*-1*), X + x1, Y - y1(*-1*), Y + y1);
			INC(d, dy);  INC(dy, a8);  INC(y1);  INC(y2, a2);
			IF d >= 0 THEN DEC(d, dx);  DEC(dx, b8);  DEC(x1);  DEC(x2, b2) END
		END;
		INC(d, 4 * (x2 + y2) - b2 + a2);
		WHILE x1 >= 0 DO
			Dot4(X - x1(*-1*), X + x1, Y - y1(*-1*), Y + y1);
			DEC(d, dx);  DEC(dx, b8);  DEC(x1);
			IF d < 0 THEN INC(d, dy);  INC(dy, a8);  INC(y1) END
		END
	END
END Ellipsei;

PROCEDURE Circlei ( X, Y, r: SIGNED16);
	VAR x, y, dx, dy, d, e: SIGNED16;
BEGIN
	IF Display3.filled IN contextstyle THEN
		x := r;  y := 0;  e := 0;  dx := 2;  dy := 2;
		WHILE y <= x DO
			FillPatterni(X, Y, X - x, Y + y, 2 * x + 1, 1);
			FillPatterni(X, Y, X - x, Y - y, 2 * x + 1, 1);
			INC(y);
			INC(e, y * dy - 1);
			IF e > x THEN
				DEC(x);  DEC(e, x * dx + 1);
				FillPatterni(X, Y, X - y, Y + x, 2 * y + 1, 1);
				FillPatterni(X, Y, X - y, Y - x, 2 * y + 1, 1)
			END
		END
	ELSIF contextpensize > 1 THEN
		d := r + (contextpensize + 1) DIV 2;
		x := X + r;  y := Y;
		InitBrush(brush, contextpensize);  BrushJump(brush, x, y);

		d := 2 * r;  dx := 4 * r;  dy := 0;
		WHILE y # Y + r DO
			WHILE d <= 1 DO DEC(x);  BrushWalk(brush, x, y);  DEC(dx, 4);  INC(d, dx) END;
			INC(y);  BrushWalk(brush, x, y);  INC(dy, 4);  DEC(d, dy)
		END;
		WHILE x # X DO DEC(x);  BrushWalk(brush, x, y);  DEC(dx, 4);  INC(d, dx) END;
		d := - d;
		WHILE x # X - r DO
			WHILE d <= 1 DO DEC(y);  BrushWalk(brush, x, y);  DEC(dy, 4);  INC(d, dy) END;
			DEC(x);  BrushWalk(brush, x, y);  INC(dx, 4);  DEC(d, dx)
		END;
		WHILE y # Y DO DEC(y);  BrushWalk(brush, x, y);  DEC(dy, 4);  INC(d, dy) END;
		d := - d;
		WHILE y # Y - r DO
			WHILE d <= 1 DO INC(x);  BrushWalk(brush, x, y);  DEC(dx, 4);  INC(d, dx) END;
			DEC(y);  BrushWalk(brush, x, y);  INC(dy, 4);  DEC(d, dy)
		END;
		WHILE x # X DO INC(x);  BrushWalk(brush, x, y);  DEC(dx, 4);  INC(d, dx) END;
		d := - d;
		WHILE x # X + r DO
			WHILE d <= 1 DO INC(y);  BrushWalk(brush, x, y);  DEC(dy, 4);  INC(d, dy) END;
			INC(x);  BrushWalk(brush, x, y);  INC(dx, 4);  DEC(d, dx)
		END;
		WHILE y # Y DO INC(y);  BrushWalk(brush, x, y);  DEC(dy, 4);  INC(d, dy) END;
		BrushFlush(brush)
	ELSE
		(*IF Visible(M, X - r, Y - r, 2 * r + 1, 2 * r + 1) THEN M := NIL END;*)
		Ellipsei(X, Y, r, r)
	END
END Circlei;

PROCEDURE PaintRecti (x, y, w, h: SIGNED16);
BEGIN	FillPatterni( 0, 0, x, y, w, h) END PaintRecti;

PROCEDURE Picti (sP: Pictures.Picture;  X, Y, W, H, DX, DY: SIGNED16);
	VAR pixs: ARRAY 256 OF Images.Pixel;  idx, max: SIGNED16;  pr, pg, pb: SIGNED16;  y, x0, x1: SIGNED16;  oldpix: Images.Pixel;  xi, yi, xe, ye: SIGNED16;
BEGIN
	(*! check for redundance ! *)

	PlacedRectIntersect(X, Y, W, H, DX, DY, 0, 0, contextimg.width, contextimg.height);
	IF (W = 0) OR (H = 0) THEN RETURN END;

	idx := 0;  max := SIGNED16(ASH(1, sP.depth));
	WHILE (idx < max) DO
		Pictures.GetColor(sP, idx, pr, pg, pb);
		Images.SetRGBA(pixs[idx], pr, pg, pb, contextalpha);
		INC(idx)
	END;

	oldpix := contextfpix;
	(* rect on pict: X,Y,W,H
	rect on image: DX,DY,W,H *)

	xi := DX - X;  yi := DY - Y;
	xe := X + W;  ye := Y + H;
	(* get picture contents *)
	y := Y;
	WHILE y < ye DO
		x0 := X;
		WHILE x0 < xe DO
			x1 := x0;
			Pictures.GetRun(sP, idx, x1, y);
			IF x1 > xe THEN x1 := xe END;
			contextfpix := pixs[idx];
			DirectReplConsti(x0 + xi, y + yi, x1 - x0, 1);
			x0 := x1
		END;
		INC(y)
	END;
	contextfpix := oldpix
END Picti;

PROCEDURE Stringi (x, y: SIGNED16;  fnt: Fonts.Font;  s: ARRAY OF CHAR);
	VAR r: Objects.Object;  p: SIGNED16;  X, Y, w, h, dsr: SIGNED16;  idx, x0, x1, xs, ys, xe, ye, xi, yi: SIGNED16;
BEGIN
	(* create sting on picture first, should be fastest method for the moment*)
	(* check booundaries, use DirectReplConst i/o Doti !!! *)
	(* ^ done, now check negative coordinates !*)

	Display3.StringSize(s, fnt, w, h, dsr);
	IF EmptyIntersection(x, y, w, h, 0, 0, contextimg.width, contextimg.height) THEN RETURN END;

	IF (stringpict = NIL) THEN
		NEW(stringpict);  Pictures.Create(stringpict, w, h + dsr, 8)
	END;

	IF (stringpict.width < w) OR (stringpict.height < h + dsr) THEN
		Pictures.Create(stringpict, w, h + dsr, 8)
	END;

	Pictures.ReplConst(stringpict, 0, 0, 0, w, h + dsr, Display.replace);  (* clear picture *)
	p := 0;  X := 0;  Y := 0;
	WHILE s[p] # 0X DO
		fnt.GetObj(fnt, ORD(s[p]), r);
		WITH r: Fonts.Char DO
			Pictures.CopyPattern(stringpict, 1, r.pat, X + r.x, Y + r.y + dsr, Display.replace);
			INC(X, r.dx);  INC(p);
			IF X + x > contextimg.width THEN s[p] := 0X END
		END
	END;

	h := h + dsr;  DEC(y, dsr);
	xs := 0;  ys := 0;
	IF x < 0 THEN w := w + x;  xs := - x;  x := 0 END;  (* left boundary *)
	IF x + w > contextimg.width THEN w := contextimg.width - x END;  (* right boundary *)
	IF y < 0 THEN h := h + y;  ys := - y ;  y := 0 END;  (* lower boundary *)
	IF y + h > contextimg.height THEN h := contextimg.height - y END;  (* upper boundary *)
	(* now: x,y,w,h: Rect on Image
	xs,ys,w,h: Rect on Picture *)
	ye := ys + h;  xe := xs + w;
	xi := x - xs;  yi := y - ys;

	(*	Pictures.DisplayBlock(stringpict,0,0,stringpict.width,stringpict.height,0,0,Display.replace); (*! remove when Pictures repaired *)
	*)
	Y := ys;
	WHILE (Y < ye) DO
		x0 := xs;
		WHILE x0 < xe DO
			(* IF Pictures.Get(stringpict,x0,Y)=1 THEN DirectDoti(xi+x0,yi+Y) END; INC(x0); *)

			x1 := x0;
			Pictures.GetRun(stringpict, idx, x1, Y);
			IF x1 > xe THEN x1 := xe END;
			IF idx = 1 THEN
				DirectReplConsti(xi + x0, yi + Y, x1 - x0, 1)
			END;
			x0 := x1

		END;
		INC(Y)
	END
	(*
	Pictures.DisplayBlock(stringpict,0,0,1,1,0,0,Display.replace); (*! remove when Pictures repaired *)
	*)
END Stringi;

PROCEDURE ReplStringi (X, Y: SIGNED16;  fnt, str: ARRAY OF CHAR);
	VAR f: Fonts.Font;
BEGIN
	f := Fonts.This (fnt);
	IF f = NIL THEN f := Fonts.This(StdFnt) END;
	Stringi(X, Y, f, str)
END ReplStringi;


PROCEDURE StretchedPicti (sP: Pictures.Picture;  X, Y, W, H, DX, DY, DW, DH: SIGNED16);
	VAR pixs: ARRAY 256 OF Images.Pixel;  idx, max: SIGNED16;  pr, pg, pb: SIGNED16;  y, x0, x1: SIGNED16;  oldpix: Images.Pixel;
	xe, ye: SIGNED16;
	nx, ny, nw, nh, ndx, ndy, ndw, ndh: SIGNED16;  thisx, nextx, thisy, nexty: SIGNED16;
	scalex, scaley: FLOAT64;
	scalexl, scaleyl: SIGNED16;
BEGIN
	IF (W = DW) & (H = DH) THEN Picti(sP, X, Y, W, H, DX, DY) END;
	(*
	ASSERT(RectInRect(X, Y, W, H, 0, 0, sP.width, sP.height), 100);
	*)
	(* first check if displayed: *)
	IF (DW = 0) OR (DH = 0) THEN RETURN END;
	IF EmptyIntersection(DX, DY, DW, DH, 0, 0, contextimg.width, contextimg.height) THEN RETURN END;
	oldpix := contextfpix;
	(* colors .. *)
	idx := 0;  max := SIGNED16(ASH(1, sP.depth));
	WHILE (idx < max) DO
		Pictures.GetColor(sP, idx, pr, pg, pb);
		Images.SetRGBA(pixs[idx], pr, pg, pb, contextalpha);
		INC(idx)
	END;

	(* general case: non integer stretch values *)
	(*! speed up ! *)

	(* compute displayed area *)
	ndx := DX;  ndy := DY;  ndw := DW;  ndh := DH;
	nx := X;  ny := Y;  nw := W;  nh := H;

	RectIntersection(ndx, ndy, ndw, ndh, 0, 0, contextimg.width, contextimg.height);
	nx := SHORT(ENTIER(X + W * ((ndx - DX) / DW)));
	ny := SHORT(ENTIER(Y + H * ((ndy - DY) / DH) ));
	nw := SHORT(ENTIER(W * (ndw / DW)));
	nh := SHORT(ENTIER(H * (ndh / DH)));
	xe := SHORT(ENTIER(X + W * ((ndx + ndw - DX) / DW) + 0.5));
	ye := SHORT(ENTIER(Y + H * ((ndy + ndh - DY) / DH) + 0.5 ));
	xe := Min(xe + 1, X + W);
	ye := Min(ye + 1, Y + H);


	scalexl := DW DIV W;  scaleyl := DH DIV H;
	IF (scalexl * W = DW) & (scaleyl * H = DH) THEN
		y := ny;
		WHILE y < ye DO
			thisy := DY + (y - Y) * scaleyl;
			nexty := scaleyl;  (* nexty is the width (!!) *)
			x0 := nx;
			WHILE x0 < xe DO
				x1 := x0;
				Pictures.GetRun(sP, idx, x1, y);
				IF x1 > xe THEN x1 := xe END;
				thisx := DX + (x0 - X) * scalexl;
				nextx := (x1 - x0) * scalexl;  (* nextx is the width (!!) *)
				contextfpix := pixs[idx];
				ReplConsti(thisx, thisy, nextx, nexty);
				x0 := x1
			END;
			INC(y)
		END

	ELSE
		(* non integer valued stretch *)
		scalex := DW / W;  scaley := DH / H;
		y := ny;
		WHILE y < ye DO
			thisy := SHORT(ENTIER(DY + (y - Y) * scaley + 0.5));
			nexty := SHORT(ENTIER(DY + (y + 1 - Y) * scaley + 0.5));
			x0 := nx;
			WHILE x0 < xe DO
				x1 := x0;
				Pictures.GetRun(sP, idx, x1, y);
				IF x1 > xe THEN x1 := xe
				END;
				thisx := SHORT(ENTIER(DX + (x0 - X) * scalex + 0.5));  (* fof 010406 *)
				nextx := SHORT(ENTIER(DX + (x1 - X) * scalex + 0.5));
				contextfpix := pixs[idx];
				ReplConsti(thisx, thisy, nextx - thisx, nexty - thisy);
				IF (x1 <= x0) THEN x1 := xe END;
				x0 := x1

			END;
			INC(y)
		END
	END;
	contextfpix := oldpix
END StretchedPicti;


PROCEDURE Imagei (VAR img: Images.Image;  x, y, w, h, dx, dy: SIGNED16);
	VAR tx, tx0, ty: SIGNED16;  pix, pix0: Images.Pixel;  r, g, b, a: SIGNED16;
BEGIN
	PlacedRectIntersect(x, y, w, h, dx, dy, 0, 0, contextimg.width, contextimg.height);
	IF (w = 0) OR (h = 0) THEN RETURN END;
	IF contextalpha = 255 THEN
		Images.Copy(img, contextimg, x, y, x + w, y + h, dx, dy, Images.SrcOverDst)
	ELSE

		FOR ty := y TO y + h - 1 DO
			tx := x;
			Images.Get(img, tx, ty, pix, Images.SrcCopy);  INC(tx);
			WHILE tx < x + w DO
				pix0 := pix;
				tx0 := tx - 1;
				WHILE(pix[0] = pix0[0]) & (pix[1] = pix0[1]) & (pix[2] = pix0[2]) & (pix[3] = pix0[3]) & (tx < x + w) DO
					Images.Get(img, tx, ty, pix, Images.SrcCopy);
					INC(tx)
				END;
				Images.GetRGBA(pix0, r, g, b, a);
				a := a - 255 + contextalpha;
				IF a < 0 THEN a := 0 END;
				Images.SetRGBA(pix0, r, g, b, a);
				IF tx - 1 = tx0 THEN
					Images.Put(contextimg, dx + tx0 - x, dy + ty - y, pix0, Images.SrcOverDst)
				ELSE
					Images.Fill(contextimg, dx + tx0 - x, dy + ty - y, dx + tx - x - 1, dy + ty - y + 1, pix0, Images.SrcOverDst)
				END
			END
		END
	END
END Imagei;



PROCEDURE IGetRun (P: Images.Image;  VAR pix: Images.Pixel;  VAR x: SIGNED16;  y: SIGNED16);
PROCEDURE Equals (VAR pix1: Images.Pixel;  x, y: SIGNED16): BOOLEAN;
	VAR pix2: Images.Pixel;
BEGIN
	Images.Get(P, x, y, pix2, Images.SrcCopy);
	IF (pix1[0] = pix2[0]) & (pix1[1] = pix2[1]) & (pix1[2] = pix2[2]) & (pix1[3] = pix2[3]) THEN RETURN TRUE ELSE RETURN FALSE END
END Equals;

BEGIN
	Images.Get(P, x, y, pix, Images.SrcCopy);
	INC(x);
	WHILE (x < P.width) & Equals(pix, x, y) DO INC(x) END
END IGetRun;

PROCEDURE StretchedImagei (VAR sP: Images.Image;  X, Y, W, H, DX, DY, DW, DH: SIGNED16);
	VAR y, x0, x1: SIGNED16;  oldpix, pix: Images.Pixel;
	xe, ye: SIGNED16;
	nx, ny, nw, nh, ndx, ndy, ndw, ndh: SIGNED16;  thisx, nextx, thisy, nexty: SIGNED16;
	scalex, scaley: FLOAT64;  r, g, b, a: SIGNED16;
	scalexl, scaleyl: SIGNED16;
BEGIN
	IF (W = DW) & (H = DH) THEN Imagei(sP, X, Y, W, H, DX, DY) END;
	(* first check if displayed: *)
	IF (DW = 0) OR (DH = 0) THEN RETURN END;
	IF EmptyIntersection(DX, DY, DW, DH, 0, 0, contextimg.width, contextimg.height) THEN RETURN END;
	oldpix := contextfpix;

	(* general case: non integer stretch values *)
	(*! speed up ! *)

	(* compute displayed area *)
	ndx := DX;  ndy := DY;  ndw := DW;  ndh := DH;
	nx := X;  ny := Y;  nw := W;  nh := H;

	RectIntersection(ndx, ndy, ndw, ndh, 0, 0, contextimg.width, contextimg.height);
	nx := SHORT(ENTIER(X + W * ((ndx - DX) / DW)));
	ny := SHORT(ENTIER(Y + H * ((ndy - DY) / DH) ));
	nw := SHORT(ENTIER(W * (ndw / DW)));
	nh := SHORT(ENTIER(H * (ndh / DH)));
	xe := SHORT(ENTIER(X + W * ((ndx + ndw - DX) / DW) + 0.5));
	ye := SHORT(ENTIER(Y + H * ((ndy + ndh - DY) / DH) + 0.5 ));
	xe := Min(xe + 1, X + W);
	ye := Min(ye + 1, Y + H);


	scalexl := DW DIV W;  scaleyl := DH DIV H;
	IF (scalexl * W = DW) & (scaleyl * H = DH) THEN
		y := ny;
		WHILE y < ye DO
			thisy := DY + (y - Y) * scaleyl;
			nexty := scaleyl;  (* nexty is the width (!!) *)
			x0 := nx;
			WHILE x0 < xe DO
				x1 := x0;
				IGetRun(sP, pix, x1, y);
				IF x1 > xe THEN x1 := xe END;
				thisx := DX + (x0 - X) * scalexl;
				nextx := (x1 - x0) * scalexl;  (* nextx is the width (!!) *)
				IF contextalpha < 255 THEN
					Images.GetRGBA(pix, r, g, b, a);
					a := contextalpha;
					Images.SetRGBA(pix, r, g, b, a)
				END;
				contextfpix := pix;
				ReplConsti(thisx, thisy, nextx, nexty);
				x0 := x1
			END;
			INC(y)
		END

	ELSE
		(* non integer valued stretch *)
		scalex := DW / W;  scaley := DH / H;
		y := ny;
		WHILE y < ye DO
			thisy := SHORT(ENTIER(DY + (y - Y) * scaley + 0.5));
			nexty := SHORT(ENTIER(DY + (y + 1 - Y) * scaley + 0.5));
			x0 := nx;
			WHILE x0 < xe DO
				x1 := x0;
				IGetRun(sP, pix, x1, y);
				IF x1 > xe THEN x1 := xe END;
				thisx := SHORT(ENTIER(DX + (x0 - X) * scalex + 0.5));
				nextx := SHORT(ENTIER(DX + (x1 - X) * scalex + 0.5));
				IF contextalpha < 255 THEN
					Images.GetRGBA(pix, r, g, b, a);
					a := contextalpha;
					Images.SetRGBA(pix, r, g, b, a)
				END;

				contextfpix := pix;
				ReplConsti(thisx, thisy, nextx - thisx, nexty - thisy);
				x0 := x1
			END;
			INC(y)
		END
	END;
	contextfpix := oldpix
END StretchedImagei;


(** printing primitives *)

PROCEDURE PointToPrnPoint (VAR x, y: SIGNED16);
	VAR xL, yL : SIGNED32;
BEGIN
	xL := x - xPortOrg;  xL := xL * du;
	x := xPrnOrg + SHORT ((xL + hpu) DIV pu);
	yL := y - yPortOrg;  yL := yL * du;
	y := yPrnOrg + SHORT ((yL + hpu) DIV pu)
END PointToPrnPoint;

PROCEDURE SizeToPrnSize (VAR w, h: SIGNED16);
BEGIN
	w := SHORT ((LONG(w) * du) DIV pu);
	h := SHORT ((LONG(h) * du) DIV pu)
END SizeToPrnSize;

PROCEDURE CopyPatternPrn (sgn: tSign;  x, y: SIGNED16);
BEGIN
	IF sgn.print # NIL THEN sgn.print (x, y) (*! ändern: sgn.print muss abgefangen werden können*)
	ELSE (*! GetPatternSize ?*)
		(*
		Display1.GetPatternSize (sgn.pat, w, h);
		Printer.ReplPattern (x, y, w, h, col)
		*)
	END
END CopyPatternPrn;

PROCEDURE DotPrn (x, y: SIGNED16);
	VAR w, h : SIGNED16;
BEGIN
	w := 1;  h := 1;
	PointToPrnPoint (x, y);
	SizeToPrnSize(w, h);
	Printer3.ReplConst(clipMask, contextfcol, x, y, w, h, contextmode)
END DotPrn;

PROCEDURE ReplConstPrn (x, y, w, h: SIGNED16);
BEGIN
	PointToPrnPoint (x, y);  SizeToPrnSize (w, h);
	Printer3.ReplConst (clipMask, contextfcol, x, y, w, h, paint)
END ReplConstPrn;

PROCEDURE ReplStringPrn (X, Y: SIGNED16;  fnt, str: ARRAY OF CHAR);
BEGIN
	PointToPrnPoint (X, Y);  Printer3.String (clipMask, contextfcol, X, Y, Fonts.This(fnt), str, contextmode)
END ReplStringPrn;

PROCEDURE LinePrn (x0, y0, x1, y1 : SIGNED16);
	VAR u, v: SIGNED16;
BEGIN
	u := contextpensize;  v := contextpensize;
	SizeToPrnSize(u, v);
	PointToPrnPoint (x0, y0);
	PointToPrnPoint (x1, y1);
	Printer3.Line (clipMask, contextfcol, contextpattern, x0, y0, x1, y1, u, paint)
END LinePrn;

PROCEDURE CirclePrn (x, y, r: SIGNED16);
	VAR u: SIGNED16;
BEGIN
	PointToPrnPoint (x, y);
	u := contextpensize;  SizeToPrnSize (r, u);
	Printer3.Circle (clipMask, contextfcol, contextpattern, x, y, r, u, contextstyle, paint)
END CirclePrn;

PROCEDURE EllipsePrn (x, y, a, b: SIGNED16);
	VAR u, v: SIGNED16;
BEGIN
	u := contextpensize;  v := contextpensize;  SizeToPrnSize (u, v);
	PointToPrnPoint (x, y);  SizeToPrnSize (a, b);
	Printer3.Ellipse(clipMask, contextfcol, contextpattern, x, y, a, b, u, contextstyle, paint)
END EllipsePrn;

PROCEDURE RectPrn (x, y, w, h: SIGNED16);
	VAR i, j: SIGNED16;
BEGIN
	i := contextpensize;  j := contextpensize;
	SizeToPrnSize(j, i);
	PointToPrnPoint (x, y);  SizeToPrnSize (w, h);
	Printer3.Rect(clipMask, contextfcol, contextpattern, x, y, w, h, j, paint)
END RectPrn;

PROCEDURE Rect3DPrn (x, y, w, h: SIGNED16);
	VAR i, j: SIGNED16;
BEGIN
	i := contextpensize;  j := contextpensize;  SizeToPrnSize(i, j);
	PointToPrnPoint (x, y);  SizeToPrnSize (w, h);
	Printer3.Rect3D(clipMask, contextfcol, contextbcol, x, y, w, h, j, paint)
END Rect3DPrn;

PROCEDURE PaintRectPrn (x, y, w, h: SIGNED16);
	VAR width, i: SIGNED16;
BEGIN
	width := 1;
	i := width;
	SizeToPrnSize(width, i);
	PointToPrnPoint (x, y);  SizeToPrnSize (w, h);
	Printer3.FillPattern(clipMask, contextfcol, contextpattern, 0, 0, x, y, w, h, paint)
END PaintRectPrn;

PROCEDURE PolyPrn (VAR x, y: ARRAY OF SIGNED16;  n: SIGNED16);
	VAR i : SIGNED16;  w1, w2: SIGNED16;
BEGIN
	w1 := 1;  w2 := 1;  SizeToPrnSize(w1, w2);
	FOR i := 0 TO n - 1 DO PointToPrnPoint(x[i], y[i]) END;  (* ! be careful, x,y are VAR parameters !*)
	Display3.Poly(clipMask, contextfcol, contextpattern, x, y, n, w1, contextstyle, paint)
END PolyPrn;

PROCEDURE ReplPictPrn (picture: Pictures.Picture;  px, py, x, y, w, h: SIGNED16);
BEGIN
	PointToPrnPoint(px, py);  PointToPrnPoint(x, y);  SizeToPrnSize(w, h);
	Printer3.ReplPict(clipMask, picture, px, py, x, y, w, h, contextmode)
END ReplPictPrn;

PROCEDURE pictPrn (picture: Pictures.Picture;  x, y, w, h, dx, dy: SIGNED16);
	VAR dbpict: Pictures.Picture;
BEGIN
	NEW(dbpict);
	Pictures.Create(dbpict, w + 1, h + 1, picture.depth);
	Pictures.Copy(picture, dbpict, x, y, w, h, 0, 0, w, h, Display.replace);
	PointToPrnPoint(dx, dy);  SizeToPrnSize(w, h);
	Printer3.Pict(clipMask, dbpict, dx, dy, w, h, contextmode)
END pictPrn;

PROCEDURE stretchedpictPrn (picture: Pictures.Picture;  x, y, w, h, dx, dy, dw, dh: SIGNED16);
	VAR dbpict: Pictures.Picture;
BEGIN
	NEW(dbpict);
	Pictures.Create(dbpict, dw + 1, dh + 1, picture.depth);
	Pictures.Copy(picture, dbpict, x, y, w, h, 0, 0, dw, dh, Display.replace);
	PointToPrnPoint(dx, dy);  SizeToPrnSize(dw, dh);
	Printer3.Pict(clipMask, dbpict, dx, dy, dw, dh, contextmode)
END stretchedpictPrn;

(** Pattern management *)

PROCEDURE StdSignPrinter (x, y: SIGNED16);
END StdSignPrinter;

PROCEDURE StorePattern* (VAR R: Files.Rider;  sgn: tSign);
BEGIN
	IF sgn = NIL THEN
		Files.WriteInt(R, - 1)
	ELSE
		Files.WriteInt(R, sgn.w);
		Files.WriteInt(R, sgn.h);
		Files.WriteLInt(R, sgn.pat);  (*! Is the store of sgn.pat allright*)
		(*! How could sgn.print be stored?*)
	END
END StorePattern;

PROCEDURE LoadPattern* (VAR R: Files.Rider): tSign;
VAR
	sgn: tSign;
	w: SIGNED16;
	adr: SIGNED32;
BEGIN
	Files.ReadInt(R, w);
	IF w = - 1 THEN RETURN NIL END;
	NEW(sgn);
	sgn.w := w;
	Files.ReadInt(R, sgn.h);
	Files.ReadLInt(R, adr);
	sgn.pat := adr;
	(*! Is the store of sgn.pat allright*)
	sgn.wDIV2 := sgn.w DIV 2;  sgn.hDIV2 := sgn.h DIV 2;
	(*! How could sgn.print be loaded?*)
	sgn.print := StdSignPrinter;
	RETURN sgn
END LoadPattern;

PROCEDURE NewPattern* (image: ARRAY OF SET;  w, h: SIGNED16;  prn: tPatPrinter): tSign;
	VAR sgn: tSign;
BEGIN
	NEW (sgn);
	sgn.pat := Display.NewPattern (w, h, image);
	sgn.w := w;  sgn.h := h;  sgn.wDIV2 := w DIV 2;  sgn.hDIV2 := h DIV 2;
	IF prn = NIL THEN sgn.print := StdSignPrinter ELSE sgn.print := prn END;
	RETURN sgn
END NewPattern;

(** setting *)

PROCEDURE SetDisplayPrimitives*;
BEGIN
	copyPattern := CopyPatternC;
	dot := DotC;
	replConst := ReplConstC;
	replString := ReplStringC;
	line := LineC;
	circle := CircleC;
	ellipse := EllipseC;
	rect := RectC;
	rect3d := Rect3DC;
	paintrect := PaintRectC;
	poly := PolyC;
	replPict := ReplPictC;
	pict := PictC;
	stretchedpict := StretchedPictC;
	image := ImageC;
	stretchedimage := StretchedImageC
END SetDisplayPrimitives;

PROCEDURE SetPrinterPrimitives*;
BEGIN
	copyPattern := CopyPatternPrn;
	dot := DotPrn;
	replConst := ReplConstPrn;
	replString := ReplStringPrn;
	line := LinePrn;
	circle := CirclePrn;
	ellipse := EllipsePrn;
	rect := RectPrn;
	rect3d := Rect3DPrn;
	paintrect := PaintRectPrn;
	poly := PolyPrn;
	replPict := ReplPictPrn;
	pict := pictPrn;
	stretchedpict := stretchedpictPrn;
	image := ImageP;
	stretchedimage := StretchedImageP
END SetPrinterPrimitives;

PROCEDURE SetImagePrimitives*;
BEGIN
	copyPattern := CopyPatterni;
	dot := Doti;
	replConst := ReplConsti;
	replString := ReplStringi;
	line := Linei;
	circle := Circlei;
	ellipse := Ellipsei;
	rect := Recti;
	rect3d := Rect3Di;
	paintrect := PaintRecti;
	poly := Polyi;
	replPict := NIL;
	pict := Picti;
	stretchedpict := StretchedPicti;
	image := Imagei;
	stretchedimage := StretchedImagei
END SetImagePrimitives;


PROCEDURE OpenPrinter* (x, y, px, py: SIGNED16);
BEGIN
	status := print;  xPrnOrg := x;  yPrnOrg := y;  xPortOrg := px;  yPortOrg := py;  SetPrinterPrimitives
END OpenPrinter;

PROCEDURE ClosePrinter*;
BEGIN
	status := display;
	SetDisplayPrimitives
END ClosePrinter;

PROCEDURE OpenBuffer*(VAR b: doubleBuffer; x,y,w,h: SIGNED16; translucent: BOOLEAN);
VAR newdisplayb: BOOLEAN;
BEGIN
	IF b = NIL THEN
		NEW(b); b.new := TRUE
	ELSIF (w # b.w) OR (h# b.h) THEN
		b.new := TRUE
	ELSE
		b.new := FALSE;
	END;
	b.x := x; b.y := y; b.w := w; b.h := h; b.mask := clipMask;
	IF ~translucent THEN
		newdisplayb := (b.displayBuffer = NIL);
		vyPortability.OpenBuffer(b.displayBuffer,w,h);
		IF (b.displayBuffer#NIL)  THEN
			IF newdisplayb THEN b.new := TRUE; END;
			b.imageBuffer := NIL;
			b.type := cDisplayBuffer;
			clipMask := NIL;
			SetDisplayPrimitives;
		END;
	ELSE
		b.displayBuffer := NIL;
	END;
	IF b.displayBuffer = NIL THEN
		IF (b.imageBuffer = NIL) THEN NEW(b.imageBuffer);  b.new := TRUE END;
		IF b.new THEN
			Images.Create(b.imageBuffer, w, h, Images.DisplayFormat);
		END;
		contextimg := b.imageBuffer;
		SetImagePrimitives;
		b.type := cImageBuffer;
	END;
	b.active := TRUE;
	db := b;
END OpenBuffer;

PROCEDURE UseAsBufferBG*(db: doubleBuffer; img: Images.Image);
BEGIN
	IF (img.width = db.w) & (img.height = db.h) & (img.fmt.code =  Images.DisplayFormat.code) THEN
		db.imageBuffer := img
	ELSE
		stretchedimage(img,0,0,img.width,img.height, db.x,db.y,db.w,db.h)
	END
END UseAsBufferBG;


PROCEDURE WriteBuffer*(b: doubleBuffer);
BEGIN
	IF b.displayBuffer # NIL THEN vyPortability.WriteBuffer(b.displayBuffer,b.mask,b.x,b.y);
	ELSIF b.imageBuffer # NIL THEN ImageC(b.imageBuffer, 0, 0, b.w, b.h, b.x, b.y)
	END;
END WriteBuffer;

PROCEDURE CloseBuffer*(b: doubleBuffer; VAR x,y: SIGNED16);
BEGIN
	IF b.displayBuffer # NIL THEN
		vyPortability.CloseBuffer(b.displayBuffer);
		clipMask := b.mask;
	END;
	SetDisplayPrimitives;
	b.active := FALSE;
	db := NIL;
	x := b.x; y := b.y;
END CloseBuffer;

(*

PROCEDURE SetBuffer* (b: Bitmaps.Bitmap;  X, Y: SIGNED16);
BEGIN
	db.dbBitmap := b;  db.X := X;  db.Y := Y
END SetBuffer;

PROCEDURE OpenBuffer* (b: Bitmaps.Bitmap;  X, Y: SIGNED16);
BEGIN
	SetBuffer(b, X, Y);  db.active := TRUE;  SetDisplayPrimitives;
	db.display := Display.cur;  db.displayMask := clipMask;
	Display.SetCurrent(b);  Display.SetClip(0, 0, b.width, b.height);
	db.dbMask := NIL;
	clipMask := db.dbMask
END OpenBuffer;

PROCEDURE OpenImgBuffer* (img: Images.Image;  X, Y: SIGNED16);
BEGIN
	SetBuffer(NIL, X, Y);  db.active := TRUE;  contextimg := img;  SetImagePrimitives
END OpenImgBuffer;


PROCEDURE CloseBuffer* (VAR X, Y: SIGNED16);
BEGIN
	IF db.active = TRUE THEN
		db.active := FALSE;  X := db.X;  Y := db.Y;  SetDisplayPrimitives ;
		IF db.dbBitmap # NIL THEN
			Display.SetCurrent(db.display);  clipMask := db.displayMask
		END
	END
END CloseBuffer;


PROCEDURE EnumBitmap (X, Y, W, H: SIGNED16);
BEGIN
	Bitmaps.CopyBlock(sbmp, dbmp, X + dX, Y + dY, W, H, X, Y)
END EnumBitmap;

PROCEDURE ClipAgainst (VAR x, y, w, h: SIGNED16;  x1, y1, w1, h1: SIGNED16);
	VAR r, t, r1, t1: SIGNED16;
BEGIN
	r := x + w - 1;  r1 := x1 + w1 - 1;  t := y + h - 1;  t1 := y1 + h1 - 1;
	IF x < x1 THEN x := x1 END;
	IF y < y1 THEN y := y1 END;
	IF r > r1 THEN r := r1 END;
	IF t > t1 THEN t := t1 END;
	w := r - x + 1;  h := t - y + 1;
	IF (w < 0) OR (h < 0) THEN w := 0;  h := 0 END
END ClipAgainst;

PROCEDURE Display3Bitmaps (M: Display3.Mask;  B: Displays.Display;  on: Displays.Display;  X, Y, W, H, DX, DY: SIGNED16);
BEGIN
	dX := X - DX;  dY := Y - DY;
	ClipAgainst(DX, DY, W, H, M.X, M.Y, M.W, M.H);
	sbmp := B ;  dbmp := on;
	Display3.EnumRect(M, DX, DY, W, H, EnumBitmap);
	sbmp := NIL;  dbmp := NIL
END Display3Bitmaps;
PROCEDURE WriteBuffer* (x, y, w, h, dx, dy: SIGNED16);
BEGIN
	IF db.dbBitmap # NIL THEN
		Display3Bitmaps(db.displayMask, db.dbBitmap, db.display, x, y, w, h, dx, dy)
	ELSIF contextimg # NIL THEN
		ImageC(contextimg, x, y, w, h, dx, dy)
	END
END WriteBuffer;
*)

BEGIN
	db := NIL;  clipMask := NIL;  xPrnOrg := 0;  yPrnOrg := 0;
	contextalpha := 255;
	NEW(contextpatternternimage);
	du := Display.Unit;  pu := Printer.Unit;  hpu := pu DIV 2;
END vyGraphBase0.
