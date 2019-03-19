MODULE vyPatterns IN Oberon; 		(*vs 0.0a1 md   08.08.95 *)
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
*)

(*= Pattern definition for the use of the voyager graphic
This Module contains the definition of the tDesign, which is a pair of vyHostDisplay.tSign. It can be used for all signs, needed in two different representation (e.g. a data point: selected or non-selected). A couple of standard tDesigns for the data representation are also defined here.*)

(*	history:
8.8.95 md 0.0a1	alpha version
16.5.95 md 0.0d7
26.1.95 md 0.0d6	cleaned
27.10.94 md 0.0d5	adaped to the renamed vyHostDisplay
21.10.94 md 0.0d4	Justify in the print-routines removed
30.07.94 md 0.0d1	StdSignPrinter added
17.07.94 md 0.0d0	created *)


IMPORT	vyGraphBase, vyHostDisplay := vyGraphBase;

CONST
	idversion* = "vyPatterns v0r0a2";

TYPE
	Coordinate = vyGraphBase.Coordinate;

	tDesign* = POINTER TO tDesignDesc;
	tDesignDesc* = RECORD
		sgn0*, sgn1*: vyHostDisplay.tSign
	END;

VAR
	cross*, dot*, circle*, rhombus*, plus*, vLine*, hLine*,
	ascLine*, descLine* : tDesign;



	(* the standard patterns for the data representation  *)

	(* the print routines of the standard patterns   *)

PROCEDURE PrintCross0 (x, y: Coordinate);
	(* md	 14.04.94 10:55:06 *)
	VAR sgn: vyHostDisplay.tSign;
BEGIN
	sgn := cross.sgn0;
	vyHostDisplay.Line (x, y, x + 3 * vyHostDisplay.pixel, y + 3 * vyHostDisplay.pixel);
	vyHostDisplay.Line (x, y + 3 * vyHostDisplay.pixel, x + 3 * vyHostDisplay.pixel, y)
END PrintCross0;

PROCEDURE PrintCross1 (x, y: Coordinate);
	(* md	 14.04.94 10:55:06 *)
	VAR sgn: vyHostDisplay.tSign;
BEGIN
	sgn := cross.sgn1;
	vyHostDisplay.Line (x, y, x + 5 * vyHostDisplay.pixel, y + 5 * vyHostDisplay.pixel);
	vyHostDisplay.Line (x, y + 5 * vyHostDisplay.pixel, x + 5 * vyHostDisplay.pixel, y)
END PrintCross1;

PROCEDURE PrintDot0 (x, y: Coordinate);
	(* md	 14.04.94 12:24:50 *)
	VAR sgn: vyHostDisplay.tSign;
BEGIN
	sgn := dot.sgn0;
	vyHostDisplay.PaintRect (x, y, 1 * vyHostDisplay.pixel, 1 * vyHostDisplay.pixel)
END PrintDot0;

PROCEDURE PrintDot1 (x, y: Coordinate);
	(* md	 14.04.94 12:24:50 *)
	VAR sgn: vyHostDisplay.tSign;
BEGIN
	sgn := dot.sgn1;
	vyHostDisplay.PaintRect (x, y, 3 * vyHostDisplay.pixel, 3 * vyHostDisplay.pixel)
END PrintDot1;

PROCEDURE PrintPlus0 (x, y: Coordinate);
	(* md	 14.04.94 13:31:49 *)
	VAR sgn: vyHostDisplay.tSign;
BEGIN
	sgn := plus.sgn0;
	vyHostDisplay.Line (x, y + 1 * vyHostDisplay.pixel, x + 3 * vyHostDisplay.pixel, y + 1 * vyHostDisplay.pixel);
	vyHostDisplay.Line (x + 1 * vyHostDisplay.pixel, y, x + 1 * vyHostDisplay.pixel, y + 3 * vyHostDisplay.pixel);
END PrintPlus0;

PROCEDURE PrintPlus1 (x, y: Coordinate);
	(* md	 14.04.94 13:31:49 *)
	VAR sgn: vyHostDisplay.tSign;
BEGIN
	sgn := plus.sgn1;
	vyHostDisplay.Line (x, y + 2 * vyHostDisplay.pixel, x + 5 * vyHostDisplay.pixel, y + 2 * vyHostDisplay.pixel);
	vyHostDisplay.Line (x + 2 * vyHostDisplay.pixel, y, x + 2 * vyHostDisplay.pixel, y + 5 * vyHostDisplay.pixel);
END PrintPlus1;

PROCEDURE PrintCircle0 (x, y: Coordinate);
	(* md	 14.04.94 13:34:12 *)
	VAR sgn: vyHostDisplay.tSign;
BEGIN
	sgn := circle.sgn0;
	vyHostDisplay.FrameCircle (x, y, 1 * vyHostDisplay.pixel);
END PrintCircle0;

PROCEDURE PrintCircle1 (x, y: Coordinate);
	(* md	 14.04.94 13:34:12 *)
	VAR sgn: vyHostDisplay.tSign;
BEGIN
	sgn := circle.sgn1;
	vyHostDisplay.FrameCircle (x, y, 3 * vyHostDisplay.pixel);
END PrintCircle1;

PROCEDURE PrintRhombus0 (x, y: Coordinate);
	(* md	 14.04.94 13:37:31 *)
	VAR sgn: vyHostDisplay.tSign;
BEGIN
	sgn := rhombus.sgn0;
	vyHostDisplay.Line (x, y + 1 * vyHostDisplay.pixel, x + 1 * vyHostDisplay.pixel, y + 3 * vyHostDisplay.pixel);
	vyHostDisplay.Line (x + 1 * vyHostDisplay.pixel, y + 3 * vyHostDisplay.pixel, x + 3 * vyHostDisplay.pixel, y + 1 * vyHostDisplay.pixel);
	vyHostDisplay.Line (x + 3 * vyHostDisplay.pixel, y + 1 * vyHostDisplay.pixel, x + 1 * vyHostDisplay.pixel, y);
	vyHostDisplay.Line (x + 1 * vyHostDisplay.pixel, y, x, y + 1 * vyHostDisplay.pixel);
END PrintRhombus0;

PROCEDURE PrintRhombus1 (x, y: Coordinate);
	(* md	 14.04.94 13:37:31 *)
	VAR sgn: vyHostDisplay.tSign;
BEGIN
	sgn := rhombus.sgn1;
	vyHostDisplay.Line (x, y + 2 * vyHostDisplay.pixel, x + 2 * vyHostDisplay.pixel, y + 5 * vyHostDisplay.pixel);
	vyHostDisplay.Line (x + 2 * vyHostDisplay.pixel, y + 5 * vyHostDisplay.pixel, x + 5 * vyHostDisplay.pixel, y + 2 * vyHostDisplay.pixel);
	vyHostDisplay.Line (x + 5 * vyHostDisplay.pixel, y + 2 * vyHostDisplay.pixel, x + 2 * vyHostDisplay.pixel, y);
	vyHostDisplay.Line (x + 2 * vyHostDisplay.pixel, y, x, y + 2 * vyHostDisplay.pixel);
END PrintRhombus1;

PROCEDURE PrintVLine0 (x, y: Coordinate);
	(* md	 14.04.94 13:41:47 *)
	VAR sgn: vyHostDisplay.tSign;
BEGIN
	sgn := vLine.sgn0;
	vyHostDisplay.Line (x, y, x, y + 3 * vyHostDisplay.pixel);
END PrintVLine0;

PROCEDURE PrintVLine1 (x, y: Coordinate);
	(* md	 14.04.94 13:41:47 *)
	VAR sgn: vyHostDisplay.tSign;
BEGIN
	sgn := vLine.sgn1;
	vyHostDisplay.Line (x, y, x, y + 5 * vyHostDisplay.pixel);
END PrintVLine1;

PROCEDURE PrintHLine0 (x, y: Coordinate);
	(* md	 14.04.94 13:43:43 *)
	VAR sgn: vyHostDisplay.tSign;
BEGIN
	sgn := hLine.sgn0;
	vyHostDisplay.Line (x, y, x + 3 * vyHostDisplay.pixel, y);
END PrintHLine0;

PROCEDURE PrintHLine1 (x, y: Coordinate);
	(* md	 14.04.94 13:43:43 *)
	VAR sgn: vyHostDisplay.tSign;
BEGIN
	sgn := hLine.sgn1;
	vyHostDisplay.Line (x, y, x + 5 * vyHostDisplay.pixel, y);
END PrintHLine1;

PROCEDURE PrintAscLine0 (x, y: Coordinate);
	(* md	 14.04.94 13:45:33 *)
	VAR sgn: vyHostDisplay.tSign;
BEGIN
	sgn := ascLine.sgn0;
	vyHostDisplay.Line (x, y, x + 3 * vyHostDisplay.pixel, y + 3 * vyHostDisplay.pixel);
END PrintAscLine0;

PROCEDURE PrintAscLine1 (x, y: Coordinate);
	(* md	 14.04.94 13:45:33 *)
	VAR sgn: vyHostDisplay.tSign;
BEGIN
	sgn := ascLine.sgn1;
	vyHostDisplay.Line (x, y, x + 5 * vyHostDisplay.pixel, y + 5 * vyHostDisplay.pixel);
END PrintAscLine1;

PROCEDURE PrintDescLine0 (x, y: Coordinate);
	(* md	 14.04.94 13:48:17 *)
	VAR sgn: vyHostDisplay.tSign;
BEGIN
	sgn := descLine.sgn0;
	vyHostDisplay.Line (x, y + 3 * vyHostDisplay.pixel, x + 3 * vyHostDisplay.pixel, y);
END PrintDescLine0;

PROCEDURE PrintDescLine1 (x, y: Coordinate);
	(* md	 14.04.94 13:48:17 *)
	VAR sgn: vyHostDisplay.tSign;
BEGIN
	sgn := descLine.sgn1;
	vyHostDisplay.Line (x, y + 5 * vyHostDisplay.pixel, x + 5 * vyHostDisplay.pixel, y);
END PrintDescLine1;


PROCEDURE InitPattern;
	(* md	 24.03.94 16:01:19 *)
	VAR img: ARRAY 10 OF SET;
BEGIN
	(* dot *)
	NEW(dot);
	img[1] := {0};
	dot.sgn0 := vyHostDisplay.NewPattern (img, 1 * vyHostDisplay.pixel, 1 * vyHostDisplay.pixel, PrintDot0);

	img[1] := {0, 1, 2};
	img[2] := {0, 1, 2};
	img[3] := {0, 1, 2};
	dot.sgn1 := vyHostDisplay.NewPattern (img, 3 * vyHostDisplay.pixel, 3 * vyHostDisplay.pixel, PrintDot1);

	(* cross *)
	NEW (cross);
	img[1] := {0, 2};
	img[2] := {1};
	img[3] := {0, 2};
	cross.sgn0 := vyHostDisplay.NewPattern (img, 3 * vyHostDisplay.pixel, 3 * vyHostDisplay.pixel, PrintCross0);

	img[1] := {0, 4};
	img[2] := {1, 3};
	img[3] := {2};
	img[4] := {1, 3};
	img[5] := {0, 4};
	cross.sgn1 := vyHostDisplay.NewPattern (img, 5 * vyHostDisplay.pixel, 5 * vyHostDisplay.pixel, PrintCross1);

	(* plus *)
	NEW(plus);
	img[1] := {1};
	img[2] := {0, 1, 2};
	img[3] := {1};
	plus.sgn0 := vyHostDisplay.NewPattern (img, 3 * vyHostDisplay.pixel, 3 * vyHostDisplay.pixel, PrintPlus0);

	img[1] := {2};
	img[2] := {2};
	img[3] := {0, 1, 2, 3, 4};
	img[4] := {2};
	img[5] := {2};
	plus.sgn1 := vyHostDisplay.NewPattern (img, 5 * vyHostDisplay.pixel, 5 * vyHostDisplay.pixel, PrintPlus1);

	(* circle *)
	NEW(circle);
	img[1] := {1};
	img[2] := {0, 2};
	img[3] := {1};
	circle.sgn0 := vyHostDisplay.NewPattern (img, 3 * vyHostDisplay.pixel, 3 * vyHostDisplay.pixel, PrintCircle0);

	img[1] := {1, 2, 3};
	img[2] := {0, 4};
	img[3] := {0, 4};
	img[4] := {0, 4};
	img[5] := {1, 2, 3};
	circle.sgn1 := vyHostDisplay.NewPattern (img, 5 * vyHostDisplay.pixel, 5 * vyHostDisplay.pixel, PrintCircle1);

	(* rhombus *)
	NEW(rhombus);
	img[1] := {1};
	img[2] := {0, 2};
	img[3] := {1};
	rhombus.sgn0 := vyHostDisplay.NewPattern (img, 3 * vyHostDisplay.pixel, 3 * vyHostDisplay.pixel, PrintRhombus0);

	img[1] := {2};
	img[2] := {1, 3};
	img[3] := {0, 4};
	img[4] := {1, 3};
	img[5] := {2};
	rhombus.sgn1 := vyHostDisplay.NewPattern (img, 5 * vyHostDisplay.pixel, 5 * vyHostDisplay.pixel, PrintRhombus1);

	(* vLine *)
	NEW(vLine);
	img[1] := {0};
	img[2] := {0};
	img[3] := {0};
	vLine.sgn0 := vyHostDisplay.NewPattern (img, 1 * vyHostDisplay.pixel, 3 * vyHostDisplay.pixel, PrintVLine0);

	img[1] := {0};
	img[2] := {0};
	img[3] := {0};
	img[4] := {0};
	img[5] := {0};
	vLine.sgn1 := vyHostDisplay.NewPattern (img, 1 * vyHostDisplay.pixel, 5 * vyHostDisplay.pixel, PrintVLine1);

	(* hLine *)
	NEW(hLine);
	img[1] := {0, 1, 2};
	hLine.sgn0 := vyHostDisplay.NewPattern (img, 3 * vyHostDisplay.pixel, 1 * vyHostDisplay.pixel, PrintHLine0);

	img[1] := {0, 1, 2, 3, 4};
	hLine.sgn1 := vyHostDisplay.NewPattern (img, 5 * vyHostDisplay.pixel, 1 * vyHostDisplay.pixel, PrintHLine1);

	(* ascLine *)
	NEW(ascLine);
	img[1] := {0};
	img[2] := {1};
	img[3] := {2};
	ascLine.sgn0 := vyHostDisplay.NewPattern (img, 3 * vyHostDisplay.pixel, 3 * vyHostDisplay.pixel, PrintAscLine0);

	img[1] := {0};
	img[2] := {1};
	img[3] := {2};
	img[4] := {3};
	img[5] := {4};
	ascLine.sgn1 := vyHostDisplay.NewPattern (img, 5 * vyHostDisplay.pixel, 5 * vyHostDisplay.pixel, PrintAscLine1);

	(* descLine *)
	NEW(descLine);
	img[1] := {2};
	img[2] := {1};
	img[3] := {0};
	descLine.sgn0 := vyHostDisplay.NewPattern (img, 3 * vyHostDisplay.pixel, 3 * vyHostDisplay.pixel, PrintDescLine0);

	img[1] := {4};
	img[2] := {3};
	img[3] := {2};
	img[4] := {1};
	img[5] := {0};
	descLine.sgn1 := vyHostDisplay.NewPattern (img, 5 * vyHostDisplay.pixel, 5 * vyHostDisplay.pixel, PrintDescLine1);
END InitPattern;


BEGIN InitPattern;
END vyPatterns.