MODULE vyHostFonts IN Oberon;  (*vs fof/gs 970228 *)
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



IMPORT Fonts, Pictures, Display;
CONST MAXCHARS = ORD(MAX(CHAR)) + 1;  maxW = 80;  maxH = 80;
	idversion* = '0.1d1';
TYPE
	Char* = POINTER TO CharDesc;
	CharDesc* = RECORD(Fonts.CharDesc)
		dy*: INTEGER
	END;

	TheChars = ARRAY MAXCHARS OF Char;

	Font* = POINTER TO FontDesc;
	FontDesc* = RECORD(Fonts.FontDesc)
		f: Fonts.Font;
		c: TheChars;
		(*? height => width ?*)
		next: Font
	END;

VAR
	Anchor: Font;
	bP: Pictures.Picture;

PROCEDURE GetChar* (F: Font;  ch: CHAR;  VAR dy, x, y, w, h: INTEGER;  VAR pat: Display.Pattern);
	VAR nr: INTEGER;
BEGIN	ASSERT(F # NIL);
	nr := ORD(ch); 	dy := F.c[nr] .dy;
	x := F.c[nr] .y;  y := F.c[nr] .x;  w := F.c[nr] .h;  h := F.c[nr] .w;
	pat := F.c[nr] .pat
END GetChar;

PROCEDURE NewVerticalFont (vertical: Font;  orig: Fonts.Font);
	VAR i: INTEGER;  ch: CHAR;  dx, x, y, w, h, hx: INTEGER;  pat: Display.Pattern;  c: Char;  image: POINTER TO ARRAY OF SET;
	temp: SET;
BEGIN	vertical.f := orig; 	vertical.height := orig.height;
	vertical.minX := orig.minY;  vertical.minY := orig.minX;  vertical.maxY := orig.maxX;  vertical.maxX := orig.maxY;
	FOR i := 0 TO MAXCHARS - 1 DO
		ch := CHR(i);
		Fonts.GetChar(orig, ch, dx, x, y, w, h, pat);
		NEW(c); 		vertical.c[i]  := c; 		c.dy := dx;  c.x := y;  c.y := x;  c.w := h;  c.h := w;
		Pictures.CopyPattern(bP, 1, pat, 0, 0, Display.replace);
		Pictures.DisplayBlock(bP, 0, 0, 0, 0, 0, 0, Display.replace); (* 970919 needed, otherwise pictures` content near to random (why?)*)
		Display.GetDim(pat, w, h);
		IF (w # 0) & (h # 0) THEN
			NEW(image, ((h DIV 32) + 1) * w);
			FOR x := 0 TO w - 1 DO hx := ((h DIV 32) + 1) * x;
				FOR y := 0 TO h - 1 DO
					IF Pictures.Get(bP, x, y) # 0 THEN  temp  := image[y DIV 32 + hx] + {(h - 1 - y) MOD 32} ;
						(* 970919 fof inserted temp for windows compatibilty (~"too many registers")*)
					image[y DIV 32 + hx] := temp END
				END
			END;
			c.pat := Display.NewPattern(h, w, image^)
		END
	END
END NewVerticalFont;

PROCEDURE This* (name: ARRAY OF CHAR): Font;
	VAR fnt: Fonts.Font;  f, lastf: Font;
BEGIN	fnt := Fonts.This(name); 	ASSERT(fnt # NIL);
	f := Anchor;
	WHILE (f # NIL) DO
		IF f.f = fnt THEN RETURN f END;
		lastf := f;
		f := f.next
	END;
	NEW(lastf.next);  f := lastf.next;
	NewVerticalFont(f, fnt);
	RETURN f
END This;

BEGIN
	NEW(Anchor);  NEW(bP);  Pictures.Create(bP, maxW, maxH, 1)
END vyHostFonts.
