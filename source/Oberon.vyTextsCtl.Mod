MODULE vyTextsCtl IN Oberon;
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



(* 	(c) Project Voyager, StatLab Heidelberg
(c) F. Friedrich, StatLab Heidelberg
*)

IMPORT	vyHostTexts, Texts, Oberon, TextFrames, Display, TextGadgets, Gadgets,Objects, Links;
CONST idversion* = "vyTextsCtl v0.0a2";

PROCEDURE GetTextFrame(t: Objects.Object): Display.Frame;
BEGIN
	WHILE (t#NIL) DO
		IF (t IS TextGadgets.Frame) OR  (t IS TextFrames.Frame) THEN RETURN t(Display.Frame) END;
		Links.GetLink(t,"Model",t);
	END;
	RETURN NIL;
END GetTextFrame;


PROCEDURE NewOutput* ; 	(** vs 0.01d fof*)
	VAR	S: Texts.Scanner;
	v: Display.Frame;  F: Display.Frame;  i, j: INTEGER;
BEGIN
	v := Oberon.MarkedViewer(); F := GetTextFrame(v);
		IF F#NIL THEN
			vyHostTexts.SetStdOutput(F) ;
			vyHostTexts.Msg("New TextFrame choosen");
			RETURN;
		ELSE
			Gadgets.ThisFrame(Oberon.Pointer.X, Oberon.Pointer.Y, F, i, j);
			IF (F#NIL) & (F IS TextGadgets.Frame) OR (F IS TextFrames.Frame) THEN
				vyHostTexts.Note(0, "New Textgadgets.Frame as output");
				vyHostTexts.SetStdOutput(F);
				RETURN
			ELSE
				vyHostTexts.Note(0, "No TextGadget, set pointer (*) first (Key F1)!");
				RETURN
			END
		END
END NewOutput;

PROCEDURE DeleteOutput* ; (** vs 0.01d *)
BEGIN	vyHostTexts.SetStdOutput(NIL)
END DeleteOutput;

PROCEDURE CaretHasPriority*; 	(** vs 0.01d *)
BEGIN
	vyHostTexts.CaretHasPriority := TRUE
END CaretHasPriority;

PROCEDURE CaretHasNoPriority*; 	(** vs 0.01d *)
BEGIN
	vyHostTexts.CaretHasPriority := FALSE
END CaretHasNoPriority;



END vyTextsCtl.

