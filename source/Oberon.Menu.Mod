(* ETH Oberon, Copyright 2001 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

MODULE Menu IN Oberon;	(** portable *)	(* rs/uh, Wed, 7-Jul-1993 *)

(*
	popup menu
	----------------
	a popup menu text consists of lines of commands
	with possible (one line) parameters

	the last command must not be terminated by a carriage
	return as this would introduce an extra (empty) line.

	don't insert white space characters in front of commands!

	it is possible to introduce separation lines or arbitrary
	text which may be selected but will not be executed.

	commands are executed as if placed within the standard
	title bar on top of a viewer, except for commands
	immediately preceded by a "/" character which are
	executed as if located within the main frame.
*)

	IMPORT Display, Fonts, Input, Oberon, Texts, Modules;

	CONST
		ML = 2; MR = 0;
		CR = 0DX;
		MaxCount = 1000;

	TYPE
		Cache = RECORD
			name: ARRAY 32 OF CHAR;
			text: Texts.Text;
			cmd: SIGNED16;
			count: SIGNED32
		END;

	VAR
		cache: ARRAY 4 OF Cache;
		R: Texts.Reader;
		ch: CHAR;
		W: Texts.Writer;
		buf: POINTER TO ARRAY OF CHAR;

	PROCEDURE GetChar(F: Fonts.Font; ch: CHAR; VAR dx, x, y, w, h: SIGNED16; VAR pat: Display.Pattern);
	BEGIN
		Fonts.GetChar(F, ch, dx, x, y, w, h, pat)
	END GetChar;

	PROCEDURE FontOf(VAR R: Texts.Reader): Fonts.Font;
	BEGIN RETURN R.lib(Fonts.Font)
	END FontOf;

	PROCEDURE CopyArea(x, y, w, h: SIGNED16; save: BOOLEAN);
		VAR cx, cy, cw, ch, x0, h0: SIGNED16; size, pix: SIGNED32;
	BEGIN
		pix := Display.TransferFormat(0) DIV 8;
		IF pix = 0 THEN	(* TransferBlock not available, use offscreen CopyBlock *)
			Display.GetClip(cx, cy, cw, ch);
			x0 := (x DIV Display.Width)*Display.Width;
			h0 := Display.Bottom - Display.UBottom;
			IF h0 > Display.Height THEN DEC(h0, Display.Height) END;
			IF cy > -h0 THEN Display.SetClip(cx, -h0, cw, Display.Height+h0) END;	(* expand clipping *)
			WHILE h0 < h DO
				IF save THEN Display.CopyBlock(x, y, w, h0, x0, -h0, Display.replace)
				ELSE Display.CopyBlock(x0, -h0, w, h0, x, y, Display.replace)
				END;
				INC(x0, w); INC(y, h0); DEC(h, h0)
			END;
			IF save THEN Display.CopyBlock(x, y, w, h, x0, -h, Display.replace)
			ELSE Display.CopyBlock(x0, -h, w, h, x, y, Display.replace)
			END;
			Display.SetClip(cx, cy, cw, ch)
		ELSE
			IF save THEN
				size := LONG(w)*h*pix+4;
				IF (buf = NIL) OR (size > LEN(buf^)) THEN NEW(buf, size) END;
				Display.TransferBlock(buf^, 0, w*pix, x, y, w, h, Display.get)
			ELSE
				Display.TransferBlock(buf^, 0, w*pix, x, y, w, h, Display.set)
			END
		END
	END CopyArea;

	PROCEDURE MainFrame(ch: CHAR): BOOLEAN;
	BEGIN
		RETURN ch = "/";
	END MainFrame;

	PROCEDURE WaitRelease;
	VAR mx, my: SIGNED16; keys: SET;
	BEGIN
		REPEAT Input.Mouse(keys, mx, my);
			Oberon.DrawCursor(Oberon.Mouse, Oberon.Arrow, mx, my);
		UNTIL keys = {};
	END WaitRelease;

	PROCEDURE SelectItem(cmd, x, y, w, h, entryH: SIGNED16);
	BEGIN
		Display.ReplConst(Display.FG, x+2, y+h-entryH-cmd*entryH, w-4, entryH, Display.invert)
	END SelectItem;

	PROCEDURE Area(fnt: Fonts.Font; VAR entryH, width, height: SIGNED16);
		VAR pat: Display.Pattern; dx, x, y, w, h, w0: SIGNED16;
	BEGIN	(* ch read *)
		entryH := fnt.height + 3; width := 0; height := entryH; w0 := 0;
		REPEAT
			IF ch = CR THEN
				IF w0 > width THEN width := w0 END;
				w0 := 0; INC(height, entryH)
			ELSE
				IF ~MainFrame(ch) THEN
					GetChar(fnt, ch, dx, x, y, w, h, pat); INC(w0, dx)
				END;
			END;
			Texts.Read(R, ch)
		UNTIL R.eot;
		IF w0 > width THEN width := w0 END
	END Area;

	PROCEDURE Write(fnt: Fonts.Font; X, Y, entryH: SIGNED16);
		VAR pat: Display.Pattern; dx, x, y, w, h, xleft: SIGNED16;
	BEGIN	(* ch read *)
		DEC(Y, entryH); xleft := X;
		REPEAT
			IF ch = CR THEN X := xleft; DEC(Y, entryH)
			ELSE
				IF ~MainFrame(ch) THEN
					GetChar(fnt, ch, dx, x, y, w, h, pat);
					Display.CopyPattern(R.col, pat, X+x, Y+y-fnt.minY, Display.replace); INC(X, dx)
				END
			END;
			Texts.Read(R, ch)
		UNTIL R.eot
	END Write;

	PROCEDURE MenuDraw(fnt: Fonts.Font; x, y, w, h, entryH: SIGNED16);
	BEGIN
		Display.ReplConst(Display.BG, x, y+2, w, h, Display.replace);	(*background*)
		Display.ReplConst(Display.FG, x, y+2, w, 1, Display.replace);	(*frame*)
		Display.ReplConst(Display.FG, x, y+2, 1, h, Display.replace);
		Display.ReplConst(Display.FG, x+w-1, y+2, 1, h, Display.replace);
		Display.ReplConst(Display.FG, x, y+h+1, w, 1, Display.replace);

		Display.ReplConst(Display.FG, x+1, y+1, w, 1, Display.replace);	(*shadow*)
		Display.ReplConst(Display.FG, x+w, y+1, 1, h, Display.replace);
		Display.ReplConst(Display.FG, x+2, y, w, 1, Display.replace);
		Display.ReplConst(Display.FG, x+w+1, y, 1, h, Display.replace);
		Write(fnt, x+2, y+h, entryH)
	END MenuDraw;

	PROCEDURE AdjustCoords(dx, dy: SIGNED16; VAR x, y, w, h: SIGNED16);
		VAR off: SIGNED16;
	BEGIN
		IF y +dy+ h > Display.Height THEN y := Display.Height - h
		ELSIF y + dy < 0 THEN y := 0
		ELSE INC(y, dy)
		END;
		off := 0;
		IF x+dx+w > Display.Width THEN x := Display.Width - w
		ELSIF x+dx < 0 THEN x := 0
		ELSE INC(x, dx)
		END;
		INC(x, off)
	END AdjustCoords;

	PROCEDURE Show(T: Texts.Text; x, y: SIGNED16; VAR cmd: SIGNED16; VAR cancel: BOOLEAN);
		VAR keys: SET;	mx, my, W, H, w, h, newCmd, entryH: SIGNED16;
	BEGIN
		Texts.OpenReader(R, T, 0); Texts.Read(R, ch);
		IF ~R.eot THEN Area(FontOf(R), entryH, w, h);
			INC(w, 4); INC(h, 4);	(* area plus border *)
			W := w + 2; H := h + 2;	(* plus shadow *)
			Oberon.RemoveMarks(x, y, W, H);
			AdjustCoords(-20, - (h-entryH-cmd*entryH) - 2, x, y, W, H);
			CopyArea(x, y, W, H, TRUE);	(* save area *)
			Texts.OpenReader(R, T, 0); Texts.Read(R, ch); MenuDraw(FontOf(R), x, y, w, h, entryH);
			cancel := FALSE;
			IF cmd # -1 THEN SelectItem(cmd, x, y, w, h, entryH) END;
			REPEAT
				Input.Mouse(keys, mx, my);
				cancel := cancel OR (MR IN keys) OR (ML IN keys);
				Oberon.DrawCursor(Oberon.Mouse, Oberon.Arrow, mx, my);
				IF cancel THEN
					Oberon.FadeCursor(Oberon.Mouse);
					CopyArea(x, y, W, H, FALSE);	(* restore area *)
					WaitRelease;
					cmd := -1;
					RETURN
				END;
				IF (mx >= x) & (mx <= x+w) & (my >= y+5) & (my <= y+h) THEN
					newCmd := (y + h - my) DIV entryH;	(* title *)
					IF newCmd # cmd THEN
						IF cmd # -1 THEN SelectItem(cmd, x, y, w, h, entryH) END;
						SelectItem(newCmd, x, y, w, h, entryH);
						cmd := newCmd
					END
				ELSE
					newCmd := -1;
					IF newCmd # cmd THEN SelectItem(cmd, x, y, w, h, entryH); cmd := newCmd END
				END;
			UNTIL keys = {};
			Oberon.FadeCursor(Oberon.Mouse);
			CopyArea(x, y, W, H, FALSE)	(* restore area *)
		END
	END Show;

	PROCEDURE CmdMenu*(menu: Texts.Text; x, y: SIGNED16; VAR cmd: SIGNED16);
		VAR cmdStr: ARRAY 32 OF CHAR;
			res, i, c: SIGNED16;	mainF, cancel: BOOLEAN;
	BEGIN
		Show(menu, x, y, cmd, cancel);
		Texts.OpenReader(R, menu, 0);
		IF (cmd > -1) & ~cancel THEN
			c := 0; Texts.Read(R, ch);
			WHILE c < cmd DO
				IF ch = CR  THEN INC(c) END;
				Texts.Read(R, ch)
			END;
			i := 0;
			mainF := MainFrame(ch);
			IF mainF THEN Texts.Read(R, ch) END;
			WHILE (ch > " ") & (ch # CR) DO
				cmdStr[i] := ch; INC(i); Texts.Read(R, ch)
			END;
			cmdStr[i] := 0X;
			(* no frame, no viewer *)
			IF mainF THEN Oberon.Par.frame := Oberon.Par.vwr.dsc.next END;
			Oberon.Par.text := menu; Oberon.Par.pos := Texts.Pos(R)-1;
			Oberon.Call(cmdStr, Oberon.Par, FALSE, res);	(*no free*)
			IF res > 0 THEN
				Texts.WriteString(W, "Error: "); Texts.WriteString(W, Modules.resMsg);
				Texts.WriteLn(W); Texts.Append(Oberon.Log, W.buf)
			END
		END
	END CmdMenu;

	PROCEDURE ShowCmd*;
		VAR S: Texts.Scanner;	T: Texts.Text;	k: SET;	x, y, i, this: SIGNED16;
	BEGIN
		Texts.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos); Texts.Scan(S);
		IF S.class = Texts.Name THEN
			Input.Mouse(k, x, y);
			i := 0; this := 0;
			WHILE i < 4 DO
				IF S.s # cache[i].name THEN
					IF cache[i].count < MaxCount THEN INC(cache[i].count) END;
					IF cache[i].count > cache[this].count THEN this := i END;
					INC(i)
				ELSE
					cache[i].count := 0;
					CmdMenu(cache[i].text, x, y, cache[i].cmd);
					WHILE i < 4 DO
						IF cache[i].count < MaxCount THEN INC(cache[i].count) END; INC(i)
					END;
					RETURN
				END
			END;
			NEW(T); Texts.Open(T, S.s);
			IF T.len > 0 THEN
				cache[this].count := 0; cache[this].cmd := -1; cache[this].text := T;
				COPY(S.s, cache[this].name);
				CmdMenu(T, x, y, cache[this].cmd)
			ELSE
				WaitRelease
			END
		END
	END ShowCmd;

	PROCEDURE Reset*;
		VAR i: SIGNED16;
	BEGIN i := 0;
		WHILE i < 4 DO
			cache[i].name := "zzz"; cache[i].count := MaxCount; cache[i].cmd := -1;
			INC(i)
		END
	END Reset;

BEGIN
	Texts.OpenWriter(W);
	Reset
END Menu.
