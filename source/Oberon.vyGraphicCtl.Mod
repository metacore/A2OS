MODULE vyGraphicCtl IN Oberon;
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
(c) F.Friedrich, StatLab Heidelberg
This is an alpha test version used for early exploration only. Please do
not redistribute. Report any problems as soon as possible to
voyager@statlab.uni-heidelberg.de  *)
(*	history:
9.8.95 md 0.0a1		alpha version
27.10.94 md 0.0d14	adaped to the renamed vyPictures
26.1.95 md 0.0d5		cleaned *)
(*!	ResizePort		resizes the FocusPort relative to a given size relative to the parc before
ResizeAllPorts	resizes all ports of the FocusViewer to a given size*)

IMPORT	 Texts, Oberon, Display, Fonts,
	vyHostStrings, vyHostTexts, vyParser,
	vyHostDisplay := vyGraphBase,
	vyPort;

CONST
	idversion* = 	"vyGraphicCtl v0r0a3";
	(*	c2dShow = "vyStd2dLayer.Show"; *)


PROCEDURE GetLayer (): vyPort.tLayer;
	VAR focus: vyPort.Picture;  layer: vyPort.tLayer;
BEGIN
	focus := vyPort.GetFocusPicture();
	IF focus = NIL THEN vyHostTexts.Note (vyHostTexts.cNotify, "no picture focused");  RETURN NIL  END;
	layer := vyPort.FocusLayer();
	IF layer = NIL THEN vyHostTexts.Note (vyHostTexts.cNotify, "no front most layer"); RETURN NIL  END;
	RETURN layer
END GetLayer;

PROCEDURE Update;
	VAR focus: vyPort.Picture;
BEGIN
	focus := vyPort.GetFocusPicture ();
	IF focus = NIL THEN vyHostTexts.Note (vyHostTexts.cNotify, "no picture focused");  HALT(204) END;
	vyPort.PictureUpdate (focus)
END Update;

PROCEDURE SetBackColor*;
	VAR s: vyParser.Scanner;   focus: vyPort.Picture;  i: SIGNED32;
BEGIN NEW(s);  vyParser.OpenParScanner(s);
	IF ~vyParser.ExpectNumber(s, i) THEN  RETURN END;
	focus := vyPort.GetFocusPicture ();
	IF focus = NIL THEN vyHostTexts.Note (vyHostTexts.cNotify, "no pictue focused");  RETURN END;
	focus.backGround := SHORT(i);
	vyPort.PictureUpdate (focus)
END SetBackColor;



PROCEDURE SetColor*;
	VAR s: vyParser.Scanner;   layer: vyPort.tLayer;  i: SIGNED32;  name: ARRAY 32 OF CHAR;
BEGIN
	NEW(s);  vyParser.OpenParScanner(s);
	IF vyParser.ExpectName(s, name) & vyParser.ExpectNumber (s, i) THEN
		layer := GetLayer(); IF layer = NIL THEN RETURN END;
		vyHostStrings.Cap(name);
		IF vyHostStrings.Equal(name, "FORECOL") THEN		layer.style.fcol := SHORT(i)
		ELSIF vyHostStrings.Equal(name, "SELECTCOL") THEN layer.style.selectcol := SHORT(i)
		ELSIF vyHostStrings.Equal(name, "FILLCOL") THEN layer.style.fillcol := SHORT(i)
		END;
		Update()
	ELSE
		vyHostTexts.Note (vyHostTexts.cNotify, "Synatx: SetColor forecol | selectcol | fillcol #val")
	END
END SetColor;

PROCEDURE SetC2d*;
	VAR s: vyParser.Scanner;   focus: vyPort.Picture;  x2d, y2d, w2d, h2d: FLOAT32;
BEGIN
	focus := vyPort.GetFocusPicture ();
	IF focus = NIL THEN vyHostTexts.Note (vyHostTexts.cNotify, "no picture focused");  RETURN  END;
	NEW(s);  vyParser.OpenParScanner(s);
	IF vyParser.ExpectReal(s, x2d) & vyParser.ExpectReal(s, y2d) & vyParser.ExpectReal(s, w2d) & vyParser.ExpectReal(s, h2d) THEN
		vyPort.SetC2d(focus, x2d, y2d, w2d, h2d)
	END
END SetC2d;

PROCEDURE SetWidth*;
	VAR s: vyParser.Scanner;   layer: vyPort.tLayer;  i: SIGNED32;
BEGIN NEW(s);  vyParser.OpenParScanner(s);
	IF vyParser.ExpectNumber (s, i) THEN
		layer := GetLayer (); IF layer = NIL THEN RETURN END;
		layer.style.pensize := SHORT(i);
		Update()
	END
END SetWidth;

PROCEDURE SetPattern*;
	VAR s: vyParser.Scanner;   layer: vyPort.tLayer;   name, pattern: ARRAY 32 OF CHAR;  pat: SIGNED32;
BEGIN
	NEW(s);  vyParser.OpenParScanner(s);

	IF vyParser.ExpectName(s, name) & vyParser.ExpectName (s, pattern) THEN
		layer := GetLayer(); IF layer = NIL THEN RETURN END;
		vyHostStrings.Cap(name);
		IF vyHostStrings.Equal(pattern, "solid") THEN pat := Display.solid
		ELSIF vyHostStrings.Equal(pattern, "grey0") THEN pat := Display.grey0
		ELSIF vyHostStrings.Equal(pattern, "grey1") THEN pat := Display.grey1
		ELSIF vyHostStrings.Equal(pattern, "grey2") THEN pat := Display.grey2
		ELSIF vyHostStrings.Equal(pattern, "ticks") THEN pat := Display.ticks
		ELSIF vyHostStrings.Equal(pattern, "hook") THEN pat := Display.hook
		ELSIF vyHostStrings.Equal(pattern, "star") THEN pat := Display.star
		ELSIF vyHostStrings.Equal(pattern, "cross") THEN pat := Display.cross
		END;
		(*! Implement  better PatternIdentification *)
		IF vyHostStrings.Equal(name, "PATTERN") THEN		layer.style.pattern := pat
		ELSIF vyHostStrings.Equal(name, "SELECTPAT") THEN layer.style.selectpat := pat
		ELSIF vyHostStrings.Equal(name, "FILLPAT") THEN layer.style.fillpat := pat
		END;
		Update()
	ELSE
		vyHostTexts.Note (vyHostTexts.cNotify, "Synatx: SetPattern pattern | selectpat | fillpat  solid | grey0 | grey1 | grey2 | ticks | hook | star | cross ")
	END
END SetPattern;

PROCEDURE SetFont*;
	VAR sc: Texts.Scanner;  font: ARRAY 32 OF CHAR;  layer: vyPort.tLayer;
BEGIN
	layer := GetLayer();IF layer = NIL THEN RETURN END;
	Texts.OpenScanner(sc, Oberon.Par.text, Oberon.Par.pos);  Texts.Scan(sc);  COPY(sc.s, font);
	IF Fonts.This(font) = NIL THEN vyHostTexts.NoteSS(1, font, " : no valid font !") END;
	COPY(font, layer.style.fnt);
	Update()
END SetFont;



PROCEDURE SetPortRatio*;
	VAR ppl, whr: FLOAT32;  sc: vyParser.Scanner;
BEGIN vyParser.OpenParScanner(sc);
	IF vyParser.Real (sc, ppl) & vyParser.Real (sc, whr)  THEN vyPort.SetDefaultFrameRatio (ppl, whr)
	ELSE vyParser.MsgSyntax (" vyGraphicCtl.SetPortRatio", "portsPerWidth;whRelation")
	END
END SetPortRatio;


PROCEDURE DefineUserPalette*;
	(*vs 0.0d0   md  14.08.95 15:21:50 *)
	VAR r1, g1, b1, r2, g2, b2, start, end: SIGNED32;  sc: vyParser.Scanner;
BEGIN
	vyParser.OpenParScanner(sc);
	IF ~(vyParser.Number(sc, r1) & vyParser.Number(sc, g1) & vyParser.Number(sc, b1)  &
		vyParser.Number(sc, r2) & vyParser.Number(sc, g2) & vyParser.Number(sc, b2)) THEN
		vyHostTexts.Note (vyHostTexts.cAlert, "");  RETURN
	END;
	IF vyParser.Number(sc, start) & vyParser.Number(sc, end) THEN
	ELSE start := 4;  end := 14
	END;
	vyHostDisplay.PalettePath (SHORT (r1), SHORT (g1), SHORT (b1),
	SHORT (r2), SHORT (g2), SHORT (b2), SHORT (start), SHORT (end), vyHostDisplay.userPalette);
	vyHostDisplay.mincol := SHORT(start);  vyHostDisplay.maxcol := SHORT(end)
END DefineUserPalette;

END vyGraphicCtl.

free: Automatic.Do
vyGraphicCtl.RestoreStandardPalette
System.Free vy3DObjects
~


vyGraphicCtl.SetPalette ^
standard	grey	blue	yellowRedBlue	user

vyGraphicCtl.DefineUserPalette  255 255 0 255 0 0 4 6
vyGraphicCtl.DefineUserPalette  255 0 0 125 0 255 6 14

vyGraphicCtl.DefineUserPalette  255 255 0 255 0 0 4 10
vyGraphicCtl.DefineUserPalette  255 0 0 125 0 255 10 * )