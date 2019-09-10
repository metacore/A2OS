(* ETH Oberon, Copyright 2001 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

MODULE LeoLists IN Oberon; (** portable **)	(* eos  *)

	(**
		Leonardo  shape list gadgets
	**)

	IMPORT
		Files, Display, Input, Objects, Fonts, Oberon, Attributes, Links, Display3, Effects, Gadgets, Leonardo;


	CONST
		Indent = 12; Tab = 10;


	TYPE
		Line = POINTER TO RECORD
			next, prev: Line;
			shape: Leonardo.Shape;
			level: SIGNED16;
			parent, open: BOOLEAN;
		END;

		(** list gadget for displaying shape components **)
		List* = POINTER TO ListDesc;
		ListDesc* = RECORD (Gadgets.FrameDesc)
			cont: Objects.Object;	(* container shape whose components are displayed *)
			lines: Line;	(* sentinel of cyclic list *)
			first, point: Line;
			pos, max: Objects.Object;	(* connectors to scroll bar *)
			active: Leonardo.Shape;	(* specially marked entry *)
		END;


	VAR
		Font: Fonts.Font;
		Time, Wait: SIGNED32;


	PROCEDURE DrawFold (mask: Display3.Mask; col, x, y, dim, mode: SIGNED16; open: BOOLEAN);
		VAR d: SIGNED16;
	BEGIN
		dim := dim DIV 2; d := 1 + 2*dim;
		IF open THEN
			INC(y, dim DIV 2);
			WHILE d > 0 DO
				Display3.ReplConst(mask, col, x, y, d, 1, mode);
				INC(x); DEC(y); DEC(d, 2)
			END
		ELSE
			INC(x, dim DIV 2); DEC(y, dim);
			WHILE d > 0 DO
				Display3.ReplConst(mask, col, x, y, 1, d, mode);
				INC(x); INC(y); DEC(d, 2)
			END
		END
	END DrawFold;

	PROCEDURE DrawLine (list: List; mask: Display3.Mask; x, y, w: SIGNED16; l: Line);
		VAR fg, bg: SIGNED16; s: ARRAY 64 OF CHAR;
	BEGIN
		IF l.shape = list.active THEN fg := Display3.white; bg := Display3.black
		ELSIF l.shape.sel THEN fg := Display3.white; bg := 12
		ELSE fg := Display3.black; bg := Display3.textbackC
		END;
		Display3.ReplConst(mask, bg, x, y, w, Font.height, Display.replace);
		IF l.parent THEN
			DrawFold(mask, fg, x+1, y + Font.height DIV 2, Font.height-4, Display.replace, l.open)
		END;
		INC(x, Indent + l.level * Tab);
		Attributes.GetString(l.shape, "Item", s);
		IF s = "" THEN
			Attributes.GetString(l.shape, "Gen", s)
		END;
		Display3.String(mask, fg, x, y - Font.minY, Font, s, Display.paint)
	END DrawLine;

	PROCEDURE Restore (list: List; x, y, w, h, lx, ly: SIGNED16; mask: Display3.Mask);
		VAR l: Line; cy: SIGNED16;
	BEGIN
		Oberon.RemoveMarks(lx + x, ly + y, w, h);
		Display3.Rect3D(mask, Display3.bottomC, Display3.topC, lx, ly, list.W, list.H, 1, Display.replace);
		Display3.AdjustMask(mask, lx+1, ly+1, list.W-2, list.H-2);
		l := list.first; cy := ly + (list.H-1) - Font.height;
		WHILE (l # list.lines) & (cy >= ly + y + h) DO
			l := l.next; DEC(cy, Font.height)
		END;
		WHILE (l # list.lines) & (cy >= ly + y) DO
			DrawLine(list, mask, lx+1, cy, list.W-2, l);
			l := l.next; DEC(cy, Font.height)
		END;
		Display3.ReplConst(mask, Display3.textbackC, lx + x, ly + y, w, cy + Font.height - (ly + y), Display.replace);
		IF Gadgets.selected IN list.state THEN
			Display3.FillPattern(mask, Display3.white, Display3.selectpat, lx, ly, lx + x, ly + y, w, h, Display.paint)
		END
	END Restore;

	PROCEDURE Print (list: List; VAR msg: Display.DisplayMsg);
	END Print;

	PROCEDURE UpdateLevel (list: List; cont: Objects.Object; VAR l: Line; level: SIGNED16);
		VAR shape: Leonardo.Shape; lm: Objects.LinkMsg; ll: Line;
	BEGIN
		shape := NIL;
		lm.id := Objects.get; lm.name := "Top"; lm.obj := NIL; lm.res := -1;
		IF cont # NIL THEN cont.handle(cont, lm) END;
		IF (lm.res >= 0) & (lm.obj # NIL) & (lm.obj IS Leonardo.Shape) THEN
			shape := lm.obj(Leonardo.Shape)
		END;
		WHILE shape # NIL DO
			IF (l.shape # shape) OR (l.level # level) THEN
				ll := l; WHILE (ll # list.lines) & (ll.level = level) & (ll.shape # shape) DO ll := ll.next END;
				IF (ll.shape = shape) & (ll.level = level) THEN	(* delete lines until line with shape *)
					ll.prev := l.prev; l.prev.next := ll
				ELSE	(* not found => insert line *)
					NEW(ll); ll.shape := shape; ll.level := level; ll.open := FALSE;
					lm.obj := NIL; lm.res := -1; shape.handle(shape, lm); ll.parent := (lm.res >= 0);
					ll.prev := l.prev; l.prev.next := ll; ll.next := l; l.prev := ll
				END;
				l := ll
			END;
			IF l.open THEN
				l := l.next;
				UpdateLevel(list, shape, l, level+1)
			ELSE
				l := l.next;
				IF (l # list.lines) & (l.level > level) THEN	(* delete lines of higher level *)
					ll := l; REPEAT ll := ll.next UNTIL (ll = list.lines) OR (ll.level = level);
					ll.prev := l.prev; l.prev.next := ll; l := ll
				END
			END;
			shape := shape.down
		END;
		IF (l # list.lines) & (l.level = level) THEN	(* delete remaining lines on this level *)
			ll := l; REPEAT ll := ll.next UNTIL (ll = list.lines) OR (ll.level < level);
			ll.prev := l.prev; l.prev.next := ll; l := ll
		END
	END UpdateLevel;

	PROCEDURE UpdateModel (list: List);
		VAR shape: Leonardo.Shape; prev, l: Line;
	BEGIN
		shape := list.first.shape; prev := list.first.prev; l := list.lines.next;
		UpdateLevel(list, list.cont, l, 0);
		l := list.lines; REPEAT l := l.next UNTIL (l = list.lines) OR (l.shape = shape);
		IF l = list.lines THEN
			l := l.next
		ELSIF l.prev # prev THEN
			WHILE (l.prev # list.lines) & (l.prev # prev) DO l := l.prev END
		END;
		list.first := l
	END UpdateModel;

	PROCEDURE SetPos (list: List; update: BOOLEAN);
		VAR l: Line; pos: SIGNED32;
	BEGIN
		IF list.pos # NIL THEN
			l := list.lines.next; pos := 0;
			WHILE l # list.first DO l := l.next; INC(pos) END;
			Attributes.SetInt(list.pos, "Value", pos);
			Gadgets.Update(list.pos)
		ELSIF update THEN
			Gadgets.Update(list)
		END
	END SetPos;

	PROCEDURE SetMax (list: List);
		VAR l: Line; max: SIGNED32;
	BEGIN
		IF list.max # NIL THEN
			l := list.lines.next; max := 0;
			WHILE l # list.lines DO l := l.next; INC(max) END;
			Attributes.SetInt(list.max, "Value", max);
			Gadgets.Update(list.max)
		END
	END SetMax;

	PROCEDURE SetCont (list: List);
		VAR lines: Line;
	BEGIN
		lines := list.lines;
		lines.next := lines; lines.prev := lines;
		UpdateLevel(list, list.cont, lines, 0);
		list.first := list.lines.next;
		SetPos(list, FALSE); SetMax(list)
	END SetCont;

	PROCEDURE Update (list: List; VAR msg: Gadgets.UpdateMsg);
		VAR dm: Display.DisplayMsg; pos, first: SIGNED32; l: Line;
	BEGIN
		IF list.pos # NIL THEN list.pos.handle(list.pos, msg) END;
		IF list.max # NIL THEN list.max.handle(list.max, msg) END;
		IF msg.obj = list.obj THEN
			IF msg.stamp # list.stamp THEN
				list.stamp := msg.stamp;
				UpdateModel(list); SetPos(list, FALSE); SetMax(list)
			END;
			dm.dlink := msg.dlink; dm.F := list; dm.x := msg.x; dm.y := msg.y; dm.res := -1;
			dm.device := Display.screen; dm.id := Display.full;
			list.handle(list, dm)
		ELSIF msg.obj = list.pos THEN
			IF msg.stamp # list.stamp THEN
				list.stamp := msg.stamp;
				Attributes.GetInt(list.pos, "Value", pos);
				l := list.lines.next; first := 0;
				WHILE l # list.first DO l := l.next; INC(first) END;
				IF pos < first THEN
					l := list.first; WHILE (l.prev # list.lines) & (pos < first) DO l := l.prev; DEC(first) END;
					IF l # list.first THEN list.first := l
					ELSE SetPos(list, FALSE)
					END
				ELSIF pos > first THEN
					l := list.first; WHILE (l.next # list.lines) & (pos > first) DO l := l.next; INC(first) END;
					IF l # list.first THEN list.first := l
					ELSE SetPos(list, FALSE)
					END
				END
			END;
			dm.dlink := msg.dlink; dm.F := list; dm.x := msg.x; dm.y := msg.y; dm.res := -1;
			dm.device := Display.screen; dm.id := Display.full;
			list.handle(list, dm)
		ELSIF msg.obj = list.max THEN
		ELSE
			Gadgets.framehandle(list, msg)
		END
	END Update;

	PROCEDURE ScrollDist (list: List; y: SIGNED16): SIGNED16;
		VAR n, bot, scroll: SIGNED16; l, last: Line;
	BEGIN
		n := (list.H-2) DIV Font.height; bot := (list.H-1) - n * Font.height;
		IF y > (list.H-2) THEN
			scroll := ((list.H-2) - y) DIV Font.height;
			l := list.lines.next; n := 0;
			WHILE l # list.first DO
				l := l.next; DEC(n)
			END;
			IF scroll < n THEN
				scroll := n
			END
		ELSIF y < bot THEN
			scroll := -((y - bot) DIV Font.height);
			l := list.first; y := (list.H-1) - Font.height;
			WHILE (l.next # list.lines) & (y > bot) DO
				l := l.next; DEC(y, Font.height)
			END;
			IF l.next = list.lines THEN
				scroll := 0	(* last line is visible => don't scroll *)
			ELSE
				last := l.next; n := 1;
				WHILE last.next # list.lines DO
					last := last.next; INC(n)
				END;
				IF scroll > n THEN
					scroll := n
				END
			END
		ELSE
			scroll := 0
		END;
		RETURN scroll
	END ScrollDist;

	PROCEDURE LocateLine (list: List; y: SIGNED16; VAR l: Line; VAR ly: SIGNED16);
	BEGIN
		l := list.first; ly := (list.H-1) - Font.height;
		WHILE (l # list.lines) & (ly >= y) & (ly > Font.height) DO
			l := l.next; DEC(ly, Font.height)
		END
	END LocateLine;

	PROCEDURE MayScroll (): BOOLEAN;
	BEGIN
		IF Oberon.Time() < Time THEN
			RETURN FALSE
		ELSE
			Time := Oberon.Time() + Wait;
			RETURN TRUE
		END
	END MayScroll;

	PROCEDURE Scroll (list: List; scroll, lx, ly: SIGNED16; mask: Display3.Mask; dlink: Objects.Object);
		VAR l: Line; n, dy, y, bot: SIGNED16; dm: Display.DisplayMsg;
	BEGIN
		l := list.first; n := scroll;
		WHILE n > 0 DO
			l := l.next; DEC(n)
		END;
		WHILE n < 0 DO
			l := l.prev; INC(n)
		END;
		list.first := l;
		IF Display3.Visible(mask, lx+1, ly+1, list.W-2, list.H-2) THEN
			dy := scroll * Font.height;
			n := (list.H-2) DIV Font.height; bot := (list.H-1) - n * Font.height;
			IF scroll < 0 THEN	(* new lines on top *)
				Display.CopyBlock(lx+1, ly + (bot - dy), list.W-2, (list.H-1) - (bot - dy), lx+1, ly + bot, Display.replace);
				l := list.first; y := (list.H-1) - Font.height;
				WHILE scroll < 0 DO
					DrawLine(list, mask, lx+1, ly + y, list.W-2, l);
					l := l.next; DEC(y, Font.height); INC(scroll)
				END
			ELSE	(* new lines at bottom *)
				Display.CopyBlock(lx+1, ly + bot, list.W-2, (list.H-1) - dy, lx+1, ly + bot + dy, Display.replace);
				l := list.first; y := (list.H-1) - Font.height;
				WHILE y > bot + dy DO
					l := l.next; DEC(y, Font.height)
				END;
				WHILE scroll > 0 DO
					DrawLine(list, mask, lx+1, ly + y, list.W-2, l);
					l := l.next; DEC(y, Font.height); DEC(scroll)
				END
			END
		ELSE
			dm.dlink := dlink; dm.F := list; dm.x := lx - list.X; dm.y := ly - list.Y;
			dm.device := Display.screen; dm.id := Display.full;
			list.handle(list, dm)
		END
	END Scroll;

	PROCEDURE ToggleLine (list: List; line: Line);
		VAR l: Line; obj: Objects.Object; shape: Leonardo.Shape; lm: Objects.LinkMsg;
	BEGIN
		IF line.open THEN	(* fold lines *)
			l := line.next; WHILE l.level > line.level DO l := l.next END;
			line.next := l; l.prev := line;
			line.open := FALSE
		ELSE	(* unfold next level *)
			Links.GetLink(line.shape, "Bottom", obj);
			IF (obj # NIL) & (obj IS Leonardo.Shape) THEN
				shape := obj(Leonardo.Shape);
				REPEAT
					NEW(l); l.shape := shape; l.level := line.level+1; l.open := FALSE;
					lm.id := Objects.get; lm.name := "Bottom"; lm.res := -1; l.shape.handle(l.shape, lm); l.parent := (lm.res >= 0);
					l.next := line.next; l.next.prev := l; l.prev := line; line.next := l;
					shape := shape.up
				UNTIL shape = NIL
			END;
			line.open := TRUE
		END;
		SetMax(list)
	END ToggleLine;

	PROCEDURE TrackSel (list: List; VAR msg: Oberon.InputMsg);
		VAR
			fig: Leonardo.Figure; lx, ly, fy, scroll, oy, lines, my, x, y, cy, dy: SIGNED16; mask: Display3.Mask;
			state, keysum, keys: SET; first, ol, cl: Line;

		PROCEDURE invert (l: Line; y: SIGNED16);
			VAR shape: Leonardo.Shape;
		BEGIN
			shape := l.shape;
			IF shape # NIL THEN
				shape.slink := NIL;
				IF shape.sel THEN Leonardo.Deselect(fig, shape)
				ELSE Leonardo.Select(fig, shape)
				END;
				DrawLine(list, mask, lx+1, ly + y, list.W-2, l)
			END
		END invert;

	BEGIN
		IF (list.obj # NIL) & (list.obj IS Leonardo.Figure) THEN
			fig := list.obj(Leonardo.Figure);
			Leonardo.DisableUpdate(fig);
			lx := msg.x + list.X; ly := msg.y + list.Y;
			Gadgets.MakeMask(list, lx, ly, msg.dlink, mask);
			Oberon.RemoveMarks(lx, ly, list.W, list.H);
			Input.KeyState(state);
			IF ~(Input.SHIFT IN state) THEN
				Leonardo.ClearSelection(fig);
				first := list.first; fy := ly + (list.H-1) - Font.height;
				WHILE (first # list.lines) & (fy > ly) DO
					DrawLine(list, mask, lx+1, fy, list.W-2, first);
					first := first.next; DEC(fy, Font.height)
				END
			END;
			LocateLine(list, msg.Y - ly, first, fy); ol := first; oy := fy; lines := 0;
			invert(first, fy);
			keysum := msg.keys; my := msg.Y;
			Oberon.DrawCursor(Oberon.Mouse, Effects.Arrow, msg.X, msg.Y);
			REPEAT
				Input.Mouse(keys, x, y); keysum := keysum + keys;
				IF keys # {} THEN
					scroll := ScrollDist(list, y - ly);
					IF scroll = 0 THEN
						LocateLine(list, y - ly, cl, cy);
						scroll := my - y
					ELSIF MayScroll() THEN
						Oberon.FadeCursor(Oberon.Mouse);
						Scroll(list, scroll, lx, ly, mask, msg.dlink);
						dy := scroll * Font.height; INC(fy, dy); INC(oy, dy);
						cl := list.first; cy := (list.H-1) - Font.height;
						IF scroll > 0 THEN
							WHILE cy > Font.height DO
								cl := cl.next; DEC(cy, Font.height)
							END
						END
					END;
					IF cl # ol THEN
						Oberon.FadeCursor(Oberon.Mouse);
						IF scroll < 0 THEN
							REPEAT
								IF lines > 0 THEN invert(ol, oy); ol := ol.prev; INC(oy, Font.height)
								ELSE ol := ol.prev; INC(oy, Font.height); invert(ol, oy)
								END;
								DEC(lines)
							UNTIL ol = cl
						ELSE
							REPEAT
								INC(lines);
								IF lines > 0 THEN ol := ol.next; DEC(oy, Font.height); invert(ol, oy)
								ELSE invert(ol, oy); ol := ol.next; DEC(oy, Font.height)
								END
							UNTIL ol = cl
						END
					END;
					my := y;
					Oberon.DrawCursor(Oberon.Mouse, Effects.Arrow, x, y)
				END
			UNTIL keys = {};
			Leonardo.EnableUpdate(fig)
		END;
		SetPos(list, TRUE)
	END TrackSel;

	PROCEDURE TrackPoint (list: List; VAR msg: Oberon.InputMsg);
		VAR
			update: BOOLEAN; lx, ly, oy, ox, x, y, scroll, cy, cx: SIGNED16; mask: Display3.Mask; ol, cl: Line;
			keysum, keys: SET;

		PROCEDURE feedback;
		BEGIN
			IF ol.shape # NIL THEN
				IF ol.parent & (0 < ox) & (ox < Indent) THEN
					DrawFold(mask, Display3.invertC, lx+4, ly + oy + Font.height DIV 2, Font.height-6, Display.invert, ol.open)
				ELSE
					Display3.ReplConst(mask, Display3.invertC, lx+1, ly + oy, list.W-2, Font.height, Display.invert)
				END
			END
		END feedback;

	BEGIN
		update := FALSE;
		lx := msg.x + list.X; ly := msg.y + list.Y;
		Gadgets.MakeMask(list, lx, ly, msg.dlink, mask);
		Oberon.RemoveMarks(lx, ly, list.W, list.H);
		LocateLine(list, msg.Y - ly, ol, oy); ox := msg.X - lx;
		keysum := msg.keys;
		feedback();
		Oberon.DrawCursor(Oberon.Mouse, Effects.Arrow, msg.X, msg.Y);
		REPEAT
			Input.Mouse(keys, x, y); keysum := keysum + keys;
			IF keys # {} THEN
				scroll := ScrollDist(list, y - ly);
				IF scroll = 0 THEN
					LocateLine(list, y - ly, cl, cy); cx := x - lx;
					IF (cx # ox) OR (cy # oy) THEN
						Oberon.FadeCursor(Oberon.Mouse);
						feedback(); ox := cx; oy := cy; ol := cl; feedback()
					END
				ELSIF MayScroll() THEN
					Oberon.FadeCursor(Oberon.Mouse);
					feedback();
					Scroll(list, scroll, lx, ly, mask, msg.dlink);
					ol := list.first; oy := (list.H-1) - Font.height;
					IF scroll > 0 THEN
						WHILE oy > Font.height DO
							ol := ol.next; DEC(oy, Font.height)
						END
					END;
					feedback()
				END;
				Oberon.DrawCursor(Oberon.Mouse, Effects.Arrow, x, y)
			END
		UNTIL keys = {};
		Oberon.FadeCursor(Oberon.Mouse);
		feedback();
		IF keysum = {1} THEN
			IF ol.parent & (lx < x) & (x < lx + Indent) THEN	(* toggle fold *)
				ToggleLine(list, ol); update := TRUE
			ELSE
				list.point := ol;
				Gadgets.ExecuteAttr(list, "Cmd", msg.dlink, NIL, NIL);
				list.point := NIL
			END
		END;
		IF update THEN
			Gadgets.Update(list)
		END
	END TrackPoint;

	PROCEDURE HandleAttr* (list: List; VAR msg: Objects.AttrMsg);
	BEGIN
		IF msg.id = Objects.enum THEN
			msg.Enum("Cmd")
		ELSIF msg.id = Objects.get THEN
			IF msg.name = "Gen" THEN msg.class := Objects.String; msg.s := "LeoLists.New"; msg.res := 0
			ELSIF msg.name = "Cmd" THEN
				Gadgets.framehandle(list, msg);
				IF msg.res < 0 THEN msg.class := Objects.String; msg.s := ""; msg.res := 0 END
			ELSE Gadgets.framehandle(list, msg)
			END
		ELSIF msg.id = Objects.set THEN
			Gadgets.framehandle(list, msg)
		END
	END HandleAttr;

	PROCEDURE HandleLinks* (list: List; VAR msg: Objects.LinkMsg);
	BEGIN
		IF msg.id = Objects.enum THEN
			msg.Enum("Container"); msg.Enum("Point"); msg.Enum("VPos"); msg.Enum("VMax"); msg.Enum("Active");
			Gadgets.framehandle(list, msg)
		ELSIF msg.id = Objects.get THEN
			IF msg.name = "Container" THEN msg.obj := list.cont; msg.res := 0
			ELSIF msg.name = "Point" THEN
				IF list.point = NIL THEN msg.obj := NIL; msg.res := 0
				ELSE msg.obj := list.point.shape; msg.res := 0
				END
			ELSIF msg.name = "VPos" THEN msg.obj := list.pos; msg.res := 0
			ELSIF msg.name = "VMax" THEN msg.obj := list.max; msg.res := 0
			ELSIF msg.name = "Active" THEN msg.obj := list.active; msg.res := 0
			ELSE Gadgets.framehandle(list, msg)
			END
		ELSIF msg.id = Objects.set THEN
			IF msg.name = "Container" THEN
				IF (msg.obj = NIL) & (list.cont # NIL) THEN
					list.cont := NIL; SetCont(list); msg.res := 0
				ELSIF msg.obj # list.cont THEN
					list.cont := msg.obj; SetCont(list); msg.res := 0
				END
			ELSIF msg.name = "Model" THEN
				IF (msg.obj = NIL) & (list.obj # NIL) THEN
					list.obj := NIL; list.cont := NIL; SetCont(list); msg.res := 0
				ELSIF (msg.obj # list.obj) & (msg.obj IS Leonardo.Figure) THEN
					list.obj := msg.obj; list.cont := NIL; SetCont(list); msg.res := 0
				END
			ELSIF msg.name = "VPos" THEN
				IF msg.obj # list.pos THEN list.pos := msg.obj; SetPos(list, FALSE) END;
				msg.res := 0
			ELSIF msg.name = "VMax" THEN
				IF msg.obj # list.max THEN list.max := msg.obj; SetMax(list) END;
				msg.res := 0
			ELSIF msg.name = "Active" THEN
				IF msg.obj = NIL THEN list.active := NIL; msg.res := 0
				ELSIF msg.obj IS Leonardo.Shape THEN list.active := msg.obj(Leonardo.Shape); msg.res := 0
				END
			ELSE
				Gadgets.framehandle(list, msg)
			END
		END
	END HandleLinks;

	PROCEDURE Copy* (VAR msg: Objects.CopyMsg; from, to: List);
		VAR tl, fl: Line;
	BEGIN
		Gadgets.CopyFrame(msg, from, to);
		to.cont := from.cont;	(* always shallow semantics *)
		NEW(tl); tl.prev := tl; tl.next := tl; to.lines := tl;
		fl := from.lines.next;
		WHILE fl # from.lines DO
			NEW(tl.next); tl.next.prev := tl; tl := tl.next;
			tl.shape := fl.shape; tl.parent := fl.parent; tl.open := fl.open;
			IF fl = from.first THEN to.first := tl END;
			fl := fl.next
		END;
		tl.next := to.lines; to.lines.prev := tl;
		to.pos := Gadgets.CopyPtr(msg, from.pos);
		to.max := Gadgets.CopyPtr(msg, from.max)
	END Copy;

	PROCEDURE Handle* (obj: Objects.Object; VAR msg: Objects.ObjMsg);
		VAR list, copy: List; keys: SET; lx, ly: SIGNED16; mask: Display3.Mask; fig: Leonardo.Figure; ver: SIGNED32;
	BEGIN
		list := obj(List);
		IF msg IS Display.FrameMsg THEN
			WITH msg: Display.FrameMsg DO
				IF (msg.F = NIL) OR (msg.F = list) THEN
					IF msg IS Oberon.InputMsg THEN
						WITH msg: Oberon.InputMsg DO
							IF (msg.id = Oberon.track) & (msg.keys # {}) & Gadgets.InActiveArea(list, msg) THEN
								IF msg.keys = {0} THEN TrackSel(list, msg)
								ELSIF msg.keys = {1} THEN TrackPoint(list, msg)
								END;
								Input.Mouse(keys, lx, ly);
								Oberon.DrawCursor(Oberon.Mouse, Effects.Arrow, lx, ly);
								msg.res := 0
							ELSE Gadgets.framehandle(list, msg)
							END
						END
					ELSIF msg IS Display.DisplayMsg THEN
						WITH msg: Display.DisplayMsg DO
							IF msg.device = Display.screen THEN
								lx := msg.x + list.X; ly := msg.y + list.Y;
								IF (msg.id = Display.full) OR (msg.F = NIL) THEN
									Gadgets.MakeMask(list, lx, ly, msg.dlink, mask);
									Restore(list, 0, 0, list.W, list.H, lx, ly, mask)
								ELSIF msg.id = Display.area THEN
									Gadgets.MakeMask(list, lx, ly, msg.dlink, mask);
									Display3.AdjustMask(mask, lx + msg.u, ly + (list.H-1) + msg.v, msg.w, msg.h);
									Restore(list, msg.u, (list.H-1) + msg.v, msg.w, msg.h, lx, ly, mask)
								END
							ELSIF msg.device = Display.printer THEN
								Print(list, msg)
							END
						END
					ELSIF msg IS Leonardo.UpdateMsg THEN
						IF msg(Leonardo.UpdateMsg).fig = list.obj THEN
							UpdateModel(list); SetPos(list, TRUE); SetMax(list);
							Gadgets.Update(list)
						END
					ELSIF msg IS Gadgets.UpdateMsg THEN
						Update(list, msg(Gadgets.UpdateMsg))
					ELSIF msg IS Oberon.ControlMsg THEN
						IF (msg(Oberon.ControlMsg).id = Oberon.neutralize) & (list.obj # NIL) THEN
							Leonardo.ClearSelection(list.obj(Leonardo.Figure))
						END
					ELSIF msg IS Display.SelectMsg THEN
						WITH msg: Display.SelectMsg DO
							IF (msg.id = Display.get) & (list.obj # NIL) THEN
								fig := list.obj(Leonardo.Figure);
								IF fig.seltime > msg.time THEN
									msg.obj := Leonardo.Selection(fig); msg.time := fig.seltime; msg.sel := list
								END
							END
						END
					ELSE
						Gadgets.framehandle(list, msg)
					END
				END
			END
		ELSIF msg IS Objects.AttrMsg THEN
			HandleAttr(list, msg(Objects.AttrMsg))
		ELSIF msg IS Objects.LinkMsg THEN
			HandleLinks(list, msg(Objects.LinkMsg))
		ELSIF msg IS Objects.CopyMsg THEN
			WITH msg: Objects.CopyMsg DO
				IF msg.stamp # list.stamp THEN
					NEW(copy); list.dlink := copy; list.stamp := msg.stamp;
					Copy(msg, list, copy)
				END;
				msg.obj := list.dlink
			END
		ELSIF msg IS Objects.BindMsg THEN
			IF list.pos # NIL THEN list.pos.handle(list.pos, msg) END;
			IF list.max # NIL THEN list.max.handle(list.max, msg) END;
			Gadgets.framehandle(list, msg)
		ELSIF msg IS Objects.FileMsg THEN
			WITH msg: Objects.FileMsg DO
				Gadgets.framehandle(list, msg);
				IF msg.id = Objects.store THEN
					Files.WriteNum(msg.R, 1);
					Gadgets.WriteRef(msg.R, list.lib, list.pos);
					Gadgets.WriteRef(msg.R, list.lib, list.max)
				ELSIF msg.id = Objects.load THEN
					Files.ReadNum(msg.R, ver);
					Gadgets.ReadRef(msg.R, list.lib, list.pos);
					Gadgets.ReadRef(msg.R, list.lib, list.max)
				END
			END
		ELSE
			Gadgets.framehandle(list, msg)
		END
	END Handle;

	PROCEDURE Init* (list: List; fig: Leonardo.Figure; cont: Objects.Object);
	BEGIN
		list.handle := Handle; list.W := 200; list.H := 100; list.obj := fig; list.cont := cont;
		NEW(list.lines); SetCont(list)
	END Init;

	PROCEDURE New*;
		VAR list: List;
	BEGIN
		NEW(list); Init(list, NIL, NIL);
		Objects.NewObj := list
	END New;


BEGIN
	Font := Fonts.This("Oberon10.Scn.Fnt");
	Wait := Input.TimeUnit DIV 5; Time := Oberon.Time()
END LeoLists.
