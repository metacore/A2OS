MODULE vyDialogElems IN Oberon;
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


(*
(c) Project Voyager, StatLab Heidelberg
(c) M. Diller, StatLab Heidelberg
*)

(*!	todo:
realize the buttoms independent from vyPort, place this module before vyPort
place vyTracking.ScrollList here
*)

IMPORT
	Display, vyRectangles, vyHostDisplay := vyGraphBase,  vyTracking,  vyEvents;

CONST
	idversion* = 	"vyDialogElems v0r0d3";

TYPE
	tButton* = POINTER TO tButtonDesc;
	tButtonDesc* = RECORD
		x, y, w, h, dsr: SIGNED16;
		text: ARRAY 32 OF CHAR;
		sign: vyHostDisplay.tSign;
		pressed: BOOLEAN;
		recall*: PROCEDURE (b: tButton;  x0, y0: SIGNED16);
		track*: PROCEDURE (b: tButton;  x0, y0: SIGNED16);
		press*: PROCEDURE (b: tButton;  x0, y0: SIGNED16): BOOLEAN;
		switch*: PROCEDURE (b: tButton;  x0, y0: SIGNED16): BOOLEAN;
		pointInButton*: PROCEDURE (x, y: SIGNED16;  b: tButton;  x0, y0: SIGNED16): BOOLEAN
	END;


PROCEDURE RecallButton (b: tButton;  x0, y0: SIGNED16);
	(*vs 0.0d0 *)	(* md  04.05.95 10:15:04 *)
	VAR col: Display.Color;
BEGIN
	vyHostDisplay.GetForeColor (col);
	vyHostDisplay.SetForeColor (14);  vyHostDisplay.SetDisplayMode (vyHostDisplay.paint);
	vyHostDisplay.PaintRect (b.x + x0, b.y + y0, b.w + 1, b.h + 1);

	vyHostDisplay.SetForeColor (15);
	vyHostDisplay.Line (b.x + x0, b.y + y0 - 1, b.x + x0 + b.w, b.y + y0 - 1);
	vyHostDisplay.Line (b.x + x0 + b.w + 1, b.y + y0, b.x + x0 + b.w + 1, b.y + y0 + b.h);
	vyHostDisplay.Line (b.x + x0, b.y + y0 + b.h + 1, b.x + x0 + b.w, b.y + y0 + b.h + 1);
	vyHostDisplay.Line (b.x + x0 - 1, b.y + y0, b.x + x0 - 1, b.y + y0 + b.h);

	vyHostDisplay.SetForeColor (0);
	IF b.pressed THEN
		vyHostDisplay.SetForeColor (12);
		vyHostDisplay.Line (b.x + x0, b.y + y0, b.x + x0, b.y + y0 + b.h);
		vyHostDisplay.Line (b.x + x0, b.y + y0 + b.h, b.x + x0 + b.w, b.y + y0 + b.h);
		y0 := y0 - 1;  x0 := x0 + 1;
		vyHostDisplay.SetForeColor (1);
		vyHostDisplay.PaintRect (b.x + x0 + 2, b.y + y0 + b.h - 3, 3, 2)
	ELSE
		vyHostDisplay.SetForeColor (0);
		vyHostDisplay.Line (b.x + x0, b.y + y0, b.x + x0, b.y + y0 + b.h);
		vyHostDisplay.Line (b.x + x0, b.y + y0 + b.h, b.x + x0 + b.w, b.y + y0 + b.h);
		vyHostDisplay.SetForeColor (12);
		vyHostDisplay.Line (b.x + x0 + b.w, b.y + y0, b.x + x0 + b.w, b.y + y0 + b.h);
		vyHostDisplay.Line (b.x + x0, b.y + y0, b.x + x0 + b.w, b.y + y0);
		vyHostDisplay.SetForeColor (13);
		vyHostDisplay.PaintRect (b.x + x0 + 2, b.y + y0 + b.h - 3, 3, 2)
	END;

	vyHostDisplay.SetForeColor (15);
	IF b.text # ""THEN
		IF b.sign = NIL THEN
			vyHostDisplay.SetStringJustification (vyHostDisplay.center, vyHostDisplay.center);
			vyHostDisplay.String (b.x + x0 + b.w DIV 2, b.y + y0 + b.h DIV 2 + b.dsr, "", b.text)
		ELSE
			(*! there is a text AND a sign, whats to do? *)
		END
	ELSIF b.sign # NIL THEN
		vyHostDisplay.SetPatternJustification (vyHostDisplay.center, vyHostDisplay.center);
		vyHostDisplay.PaintPat (b.x + x0 + b.w DIV 2, b.y + y0 + b.h DIV 2, b.sign)
	ELSE
	END;

	vyHostDisplay.SetForeColor (col)
END RecallButton;
PROCEDURE EraseButton (b: tButton;  x0, y0: SIGNED16);
	(*vs 0.0d0 *)	(* md  04.05.95 11:33:42 *)
BEGIN vyHostDisplay.EraseRect (b.x + x0 - 1, b.y + y0 - 1, b.w + 3, b.h + 3)
END EraseButton;

PROCEDURE TrackButton (b: tButton;  x0, y0: SIGNED16);
	(*! ensure, that after using Trackbuttom the context in vyPort are handled correctly, i.e. use
	WHILE event.gesture#vyEvents.EvtEmpty DO vyEvents.GetEvent (event) END;*)
	(*vs 0.0d0 *)	(* md  04.05.95 10:30:35 *)
	VAR dx, dy: SIGNED16;
BEGIN
	vyTracking.Rectangle (b.x + x0, b.y + y0, b.w, b.h, dx, dy);
	IF (dx # 0)OR(dy # 0) THEN
		EraseButton (b, x0, y0);
		b.x := b.x + dx;  b.y := b.y + dy;
		b.recall (b, x0, y0)
	END
END TrackButton;

PROCEDURE PointInButton (x, y: SIGNED16;  b: tButton;  x0, y0: SIGNED16): BOOLEAN;
	(*vs 0.0d0 *)	(* md  04.05.95 10:31:23 *)
BEGIN RETURN vyRectangles.PointInRect (x, y, b.x + x0, b.y + y0, b.w, b.h)
END PointInButton;

PROCEDURE PressButton (b: tButton;  x0, y0: SIGNED16): BOOLEAN;
	(*vs 0.0d0 *)	(* md  04.05.95 12:12:45 *)
	VAR event: vyEvents.EventMsg;
BEGIN
	vyHostDisplay.FadeCursor;
	b.pressed := ~b.pressed;  b.recall (b, x0, y0);
	vyEvents.GetEvent (event);
	WHILE event.gesture # vyEvents.EvtEmpty DO vyEvents.GetEvent (event) END;
	b.pressed := ~b.pressed;  b.recall (b, x0, y0);
	vyHostDisplay.DrawCursor (event.x, event.y);
	RETURN b.pointInButton (event.x, event.y, b, x0, y0)
END PressButton;

PROCEDURE SwitchButton (b: tButton;  x0, y0: SIGNED16): BOOLEAN;
	(*vs 0.0d0 *)	(* md  04.05.95 15:14:34 *)
	VAR event: vyEvents.EventMsg;
BEGIN
	b.pressed := ~b.pressed;  b.recall (b, x0, y0);
	vyEvents.GetEvent (event);
	WHILE event.gesture # vyEvents.EvtEmpty DO vyEvents.GetEvent (event) END;
	RETURN b.pointInButton (event.x, event.y, b, x0, y0)
END SwitchButton;



PROCEDURE OpenButton* (b: tButton;  x, y, w, h, dsr: SIGNED16;  text: ARRAY OF CHAR;  sign: vyHostDisplay.tSign);
	(*vs 0.0d0 *)	(* md  04.05.95 09:21:23 *)
BEGIN
	b.x := x;  b.y := y;  b.w := w;  b.h := h; b.dsr := dsr;
	COPY (text, b.text);  b.sign := sign;
	b.recall := RecallButton;
	b.track := TrackButton;
	b.press := PressButton;
	b.switch := SwitchButton;
	b.pointInButton := PointInButton
END OpenButton;

END vyDialogElems.
