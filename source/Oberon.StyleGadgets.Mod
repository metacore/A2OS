(* ETH Oberon, Copyright 2001 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

MODULE StyleGadgets IN Oberon; (** portable *)	(* RS, Wed, 9-Jun-1993 *)

(* copy "by hand" -> obj.link*)
(*other kind of feedback*)
(*portable write*)

(*
	make mask as wide as page width	(visual feedback)
*)

	IMPORT Display3, Gadgets, Display, Fonts, Objects, Oberon, Texts, Input, Styles;

	CONST
		left* = 0; right* = 1;	(* format flags *)
		fmode* = 0; leftmarg*  = 1; width* = 2; tabs* = 3;
		Adjust* = {left, right};
		break* = 3;	(* page break *)
		grid* = 2;

		get* = 0;	set* = 1;

		ScnUnit = 10000;	(* Display.Unit *)

		mm = 36000;
		pageW* = 160*mm;
		scnW* = pageW DIV ScnUnit;
		MinTab = 8;

		BoxH = 7; BoxW = 8; TabW = 5;
		MinW = scnW DIV 6;
		MaxTabs = 32;
		ML = 2;	MM = 1;	MR = 0;

	TYPE
		Frame* = POINTER TO FrameDesc;
		FrameDesc* = RECORD(Gadgets.FrameDesc)
			style*: Styles.Style;
			col*: SIGNED16
		END;

	VAR
		W: Texts.Writer;
		dash, dash2: Display.Pattern;
		nfnt: Fonts.Font;

(* document coordinate stuff *)

	PROCEDURE Screen(x: SIGNED32): SIGNED16;
	BEGIN
		RETURN SHORT(x DIV ScnUnit)
	END Screen;

	PROCEDURE Doc(x: SIGNED16): SIGNED32;
	BEGIN
		RETURN LONG(x)*ScnUnit;
	END Doc;

	PROCEDURE DrawTab(F : Frame; msk: Display3.Mask; sel, x, y, mode: SIGNED16);
	BEGIN
		Display3.ReplConst(msk, Display.FG(*- F.col*), x-2, y, 5, 1, mode);
		Display3.ReplConst(msk, Display.FG(*- F.col*), x-1, y+1, 3, 1, mode);
		Display3.ReplConst(msk, Display.FG(*- F.col*), x, y+2, 1, 1, mode);
		IF sel > 0 THEN Display3.ReplConst(msk, Display.FG(*- F.col*), x -2, y + 1, 5, 2, mode) END
	END DrawTab;

	PROCEDURE DrawMode(F : Frame; msk: Display3.Mask; opts: SET; x, y, w, mode: SIGNED16);
	VAR h: SIGNED16;
	BEGIN
		h := BoxH - (BoxH DIV 2)-1; INC(y, BoxH DIV 2+1);
		IF left IN opts THEN Display3.ReplConst(msk, Display.FG(*- F.col*), x, y, BoxW, h, mode)
		ELSE Display3.ReplConst(msk, Display.FG(*- F.col*), x, y+h-1, BoxW, 1, mode)
		END;
		IF right IN opts THEN Display3.ReplConst(msk, Display.FG(*- F.col*), x+w-BoxW, y, BoxW, h, mode)
		ELSE Display3.ReplConst(msk, Display.FG(*- F.col*), x+w-BoxW, y+h-1, BoxW, 1, mode)
		END;
	END DrawMode;

	PROCEDURE DrawName(style: Styles.Style; msk: Display3.Mask; x, y, w: SIGNED16);
		VAR s: ARRAY 32 OF CHAR; obj: Objects.Object; i: SIGNED16;
	BEGIN RETURN;
		i := 0; s[0] := 0X; Objects.GetName(style.lib.dict, style.ref, s);
		IF s[0] # 0X THEN
			INC(x, w-100); DEC(y, nfnt.minY);
			WHILE s[i] # 0X DO nfnt.GetObj(nfnt, ORD(s[i]), obj);
				WITH obj: Fonts.Char DO
					Display3.ReplConst(msk, Display.BG, x, y+nfnt.minY, obj.dx, nfnt.height, Display.replace);
					Display.CopyPattern(Display.FG, obj.pat, x+obj.x, y+obj.y, Display.replace); INC(x, obj.dx)
				END;
				INC(i)
			END
		END
	END DrawName;

	PROCEDURE DrawBox(F: Frame; msk: Display3.Mask; x, y, X, Y, W: SIGNED16);
	BEGIN Display3.ReplConst(msk, Display.FG, x+F.X + X, y+F.Y+Y, W, BoxH DIV 2, Display.invert)
	END DrawBox;

	PROCEDURE Wide(F: Frame): BOOLEAN;
	BEGIN RETURN (F.W = F.style.paraW DIV ScnUnit)
	END Wide;

	PROCEDURE DrawTabs(F: Frame; msk: Display3.Mask; x, y: SIGNED16);
	VAR i, t: SIGNED16;
	BEGIN INC(x, F.X); INC(y, F.Y); i := 0;
		WHILE i < F.style.nTabs DO t := Screen(F.style.tab[i]);
			IF (t < F.W) OR Wide(F) THEN DrawTab(F, msk, 0, x + t, y, Display.replace) END; INC(i)
		END
	END DrawTabs;

	PROCEDURE DrawBar(F: Frame; msk: Display3.Mask; x, y, w: SIGNED16);
	VAR BoxW: SIGNED16;
	BEGIN
		INC(x, F.X); INC(y, F.Y); BoxW := 0;
		Display3.ReplConst(msk, F.col, x, y , w, F.H, Display.replace);
		IF F.H = BoxH THEN
			IF break IN F.style.opts THEN Display3.ReplConst(msk, Display.FG, x+BoxW, y+ F.H DIV 2, w -2*BoxW, 1, Display.paint)
			ELSE Display3.FillPattern(msk, Display.FG, dash, x+BoxW, y+ F.H DIV 2, x+BoxW, y+ F.H DIV 2, w -2*BoxW, 1, Display.paint)
			END;
			DrawMode(F, msk, F.style.opts, x, y, w, Display.replace); DrawName(F.style, msk, x, y, w); DrawTabs(F, msk, x-F.X, y-F.Y)
		ELSIF break IN F.style.opts THEN
			Display3.FillPattern(msk, Display.FG, dash2, x, y, x, y, F.W, 1, Display.paint)
		END
	END DrawBar;

	PROCEDURE Update(style: Styles.Style; what, dX: SIGNED16);
		VAR M: Styles.UpdateMsg;
	BEGIN M.obj := style; M.dX := dX; M.id := what; M.F := NIL; Display.Broadcast(M)
	END Update;

	PROCEDURE CheckTab(style: Styles.Style; i: SIGNED16);
	VAR
		tab: SIGNED32;
		j: SIGNED16;
	BEGIN
		tab := style.tab[i]; j := i;
		IF (j < style.nTabs-1) & (style.tab[j+1] <= tab) THEN
			WHILE (j < style.nTabs-1) & (style.tab[j+1] <= tab) DO style.tab[j] := style.tab[j+1]; INC(j) END
		ELSE
			WHILE (j > 0) & (style.tab[j-1] >= tab) DO style.tab[j] := style.tab[j-1]; DEC(j) END
		END;
		IF (j # i) & (style.tab[j] = tab) THEN	(* multiple tabs -> delete *)
			DEC(style.nTabs); WHILE j < style.nTabs DO style.tab[j] := style.tab[j+1]; INC(j) END
		ELSE
			style.tab[j] := tab
		END;
		WHILE (style.nTabs > 0) & (style.tab[style.nTabs-1] > style.paraW) DO DEC(style.nTabs) END
	END CheckTab;

	PROCEDURE FindTab(F: Frame; x: SIGNED16; VAR d, t: SIGNED16);
	VAR
		tab: SIGNED16;
	BEGIN
		t := 0; d := 0;
		WHILE t < F.style.nTabs DO
			tab := Screen(F.style.tab[t]);
			IF (tab - 2 <= x) & (x <= tab + 2) THEN d := x - tab; RETURN ELSE INC(t) END
		END
	END FindTab;

	PROCEDURE TrackMouse(VAR x, y: SIGNED16; VAR keys, keysum: SET);
	BEGIN Input.Mouse(keys, x, y); keysum := keysum + keys;
		Oberon.DrawCursor(Oberon.Mouse, Oberon.Arrow, x, y)
	END TrackMouse;

	PROCEDURE TrackLeft(F: Frame; msk: Display3.Mask; x, y, X, Y: SIGNED16; VAR left: SIGNED16; VAR keysum: SET);
	VAR
		d, min, max, left0, boxW: SIGNED16;
		Keys: SET;
	BEGIN
		d := X - F.X - x;
		min := -Screen(F.style.left); max := F.W - MinW; left0 := 0; boxW := BoxW;
		left := X - d - F.X - x; DrawBox(F, msk, x, y, left, BoxH DIV 2+1, boxW);
		keysum := {};
		REPEAT
			Input.Mouse(Keys, X, Y);
			IF (ML IN Keys) & ~(ML IN keysum) & Wide(F) THEN	(*move column*)
				max := scnW-F.W+min;
				DrawBox(F, msk, x, y, left0, BoxH DIV 2+1, boxW); boxW := F.W; DrawBox(F, msk, x, y, left, BoxH DIV 2+1, boxW)
			END;
			keysum := keysum + Keys;
			Oberon.DrawCursor(Oberon.Mouse, Oberon.Arrow, X, Y);
			left := X - d - F.X - x;
			IF left < min THEN left := min ELSIF left > max THEN left := max END;
			IF left # left0 THEN
				Oberon.FadeCursor(Oberon.Mouse);
				DrawBox(F, msk, x, y, left0, BoxH DIV 2+1, boxW); DrawBox(F, msk, x, y, left, BoxH DIV 2+1, boxW); left0 := left
			END
		UNTIL Keys = {};
		DrawBox(F, msk, x, y, left, BoxH DIV 2+1, boxW);
		IF (ML IN keysum) & ~Wide(F) THEN EXCL(keysum, ML) END;
		Oberon.FadeCursor(Oberon.Mouse)
	END TrackLeft;

	PROCEDURE TrackRight(F: Frame; msk: Display3.Mask; x, y, X, Y: SIGNED16; VAR w: SIGNED16; VAR keysum: SET);
	VAR
		w0, d: SIGNED16;
		max: SIGNED16;
		Keys: SET;
	BEGIN
		d := X - F.X - x;
		max := scnW - Screen(F.style.left); w0 := Screen(F.style.paraW);
		w := F.W + X - d - F.X - x; DrawBox(F, msk, x, y, w-BoxW, BoxH DIV 2+1, BoxW);
		keysum := {};
		REPEAT
			TrackMouse(X, Y, Keys, keysum);
			w := F.W + X - d - F.X - x;
			IF w < MinW THEN w := MinW ELSIF w > max THEN w := max END;
			IF w # w0 THEN
				Oberon.FadeCursor(Oberon.Mouse);
				DrawBox(F, msk, x, y, w0-BoxW, BoxH DIV 2+1, BoxW); DrawBox(F, msk, x, y, w-BoxW, BoxH DIV 2+1, BoxW);
				w0 := w
			END
		UNTIL Keys = {};
		DrawBox(F, msk, x, y, w-BoxW, BoxH DIV 2+1, BoxW);
		Oberon.FadeCursor(Oberon.Mouse)
	END TrackRight;

(**)
	PROCEDURE LocTab(style: Styles.Style; t, x: SIGNED16): SIGNED16;
	VAR i, x0: SIGNED16;
	BEGIN
		x0 := MinTab; i := 0;
		IF i = t THEN INC(i) END;
		WHILE (i < style.nTabs) & (x0 <= x) DO
			IF (x < Screen(style.tab[i])-MinTab) THEN RETURN x END;
			REPEAT x0 := Screen(style.tab[i])+MinTab; INC(i);
				IF i = t THEN INC(i) END
			UNTIL (i >= style.nTabs) OR (x0 < Screen(style.tab[i])-MinTab)
		END;
		IF (style.nTabs > 0) & (x < x0) THEN RETURN x0
		ELSE RETURN x
		END
	END LocTab;


	PROCEDURE TrackTab(F: Frame; msk: Display3.Mask; x, y, X, Y: SIGNED16; VAR tabX, t: SIGNED16; VAR keysum: SET);
	VAR
		d, tabX0: SIGNED16;
		new: BOOLEAN;
		Keys: SET;
	BEGIN
		FindTab(F, X - F.X - x, d, t);
		keysum := {};
		tabX0 := X - d - F.X - x;
		IF t < F.style.nTabs THEN tabX0 := Screen(F.style.tab[t]);
			DrawTab(F,msk, 0, x + F.X + tabX0, y + F.Y, Display.invert); DrawTab(F,msk, 1, x + F.X + tabX0, y + F.Y, Display.invert)
		ELSE
			DrawBox(F, msk, x, y, tabX0-TabW DIV 2, 0, TabW)
		END;
		REPEAT
			TrackMouse(X, Y, Keys, keysum);
			(*tabX := X - d - F.X - x;*)
			tabX := LocTab(F.style, t, X - d - F.X - x);
			IF tabX > F.W + MinTab THEN tabX := F.W + MinTab
			ELSIF tabX < MinTab THEN tabX := MinTab
			END;
			IF (ML IN Keys) & (t = F.style.nTabs) & (F.style.nTabs < MaxTabs) THEN	(* add a new *)
				DrawBox(F, msk, x, y, tabX0-TabW DIV 2, 0, TabW);
				DrawTab(F,msk, 1, x + F.X + tabX, y + F.Y, Display.invert); d := 0; tabX0 := tabX; INC(F.style.nTabs); new := TRUE
			END;
			IF tabX # tabX0 THEN
				Oberon.FadeCursor(Oberon.Mouse);
				IF t < F.style.nTabs THEN
					DrawTab(F,msk, 1, x + F.X + tabX0, y + F.Y, Display.invert); DrawTab(F,msk, 1, x + F.X + tabX, y + F.Y, Display.invert)
				ELSE DrawBox(F, msk, x, y, tabX0-TabW DIV 2, 0, TabW); DrawBox(F, msk, x, y, tabX-TabW DIV 2, 0, TabW)
				END;
				tabX0 := tabX
			END
		UNTIL Keys = {};
		IF t < F.style.nTabs THEN
			DrawTab(F,msk, 1, x + F.X + tabX, y + F.Y, Display.invert); DrawTab(F,msk, 0, x + F.X + tabX, y + F.Y, Display.invert);	(*unselect*)
			IF (MR IN keysum) OR ~(left IN F.style.opts) OR (tabX >= F.W) & ~Wide(F) THEN INCL(keysum, MR);
				DrawTab(F,msk, 0, x + F.X + tabX, y + F.Y, Display.invert);	(* erase *)
				IF new THEN DEC(F.style.nTabs)	(* delete *)
				ELSE DrawTab(F, msk, 0, x +F.X + Screen(F.style.tab[t]), y + F.Y, Display.replace)	(* reset at old pos *)
				END
			END
		ELSE DrawBox(F, msk, x, y, tabX-TabW DIV 2, 0, TabW)
		END;
		Oberon.FadeCursor(Oberon.Mouse)
	END TrackTab;

	PROCEDURE TrackMode(F: Frame; msk: Display3.Mask; x, y, X, Y: SIGNED16; VAR keysum: SET);
	VAR x0, y0: SIGNED16;
		Keys: SET;
	BEGIN
		INC(x, F.X); INC(y, F.Y);
		IF (X - x > BoxW) & (X - x <= F.W DIV 2) THEN x := x + BoxW
		ELSIF (x + F.W - X > BoxW) & (x + F.W - X <= F.W DIV 2) THEN x := x + F.W DIV 2
		ELSE INCL(keysum, MR); RETURN	(*not hit: do nothing cf. Edit*)
		END;
		Display3.FillPattern(msk, Display.FG, Display.grey1, x, y + BoxH DIV 2 + 1, x, y + BoxH DIV 2 + 1, F.W DIV 2-BoxW, BoxH DIV 2, Display.invert);
		keysum := {};
		REPEAT TrackMouse(x0, y0, Keys, keysum) UNTIL Keys = {};
		Display3.FillPattern(msk, Display.FG, Display.grey1, x, y + BoxH DIV 2 + 1, x, y + BoxH DIV 2 + 1, F.W DIV 2-BoxW, BoxH DIV 2, Display.invert)
	END TrackMode;

	PROCEDURE Edit (F: Frame; msk: Display3.Mask; x, y, X, Y: SIGNED16; Keys: SET; VAR res: SIGNED16);
	VAR
		mode, keysum: SET;
		leftX, W, tabX, tab, oldleftX, modif: SIGNED16;
		style: Styles.Style;
	BEGIN
		Oberon.DrawCursor(Oberon.Mouse, Oberon.Arrow, X, Y);
		IF Keys = {MM} THEN
			IF X - F.X - x < BoxW THEN TrackLeft(F, msk, x, y, X, Y, leftX, keysum);
				IF ~(MR IN keysum) THEN oldleftX := Screen(F.style.left);
					IF FALSE (*MM IN keysum*) THEN	(* center *)
						F.style.left := (pageW - F.style.paraW) DIV 2;
						leftX := Screen(F.style.left)
					ELSIF leftX # 0 THEN INC(F.style.left, Doc(leftX)); modif := leftmarg;
						IF ~(ML IN keysum) THEN DEC(F.style.paraW, Doc(leftX)); modif := width;
							DrawTabs(F, msk, x, y); CheckTab(F.style, 0); DrawTabs(F, msk, x, y)
						END
					END;
					IF oldleftX # leftX THEN Update(F.style, modif, oldleftX-leftX) END
				END
			ELSIF x + F.X + F.W - X < BoxW THEN
				IF Wide(F) THEN TrackRight(F, msk, x, y, X, Y, W, keysum)
				ELSE REPEAT TrackMouse(X, Y, Keys, keysum) UNTIL Keys = {}; INCL(keysum, MR)
				END;
				IF ~(MR IN keysum) & (W # F.W) THEN
					F.style.paraW := Doc(W);
					DrawTabs(F, msk, x, y); CheckTab(F.style, 0); DrawTabs(F, msk, x, y);	(* drop tabs *)
					Update(F.style, width, 0)
				END
			ELSIF Y - F.Y - y <= BoxH DIV 2 THEN TrackTab(F, msk, x, y, X, Y, tabX, tab, keysum);
				IF ~(MR IN keysum) THEN
					IF (F.style.nTabs > 0) & (tab < F.style.nTabs) THEN F.style.tab[tab] := Doc(tabX);
						DrawTabs(F, msk, x, y); CheckTab(F.style, tab); DrawTabs(F, msk, x, y); Update(F.style, tabs, 0)
					END
				END
			ELSE (*mode*)
				TrackMode(F, msk, x, y, X, Y, keysum);
				IF ~(MR IN keysum) THEN
					mode := F.style.opts;
					IF X - F.X - x < F.W DIV 2 THEN	(* left *)
						IF (left IN F.style.opts) & (F.style.nTabs = 0) THEN EXCL(F.style.opts, left)
						ELSE INCL(F.style.opts, left)
						END;
						modif := left
					ELSIF x + F.X + F.W - X < F.W DIV 2 THEN	(* right *)
						IF right IN F.style.opts THEN EXCL(F.style.opts, right) ELSE INCL(F.style.opts, right) END;
						modif := right
					END;
					IF mode # F.style.opts THEN
						DrawMode(F,msk, mode, x+F.X, y+F.Y, F.W, Display.replace); DrawMode(F,msk, F.style.opts, x+F.X, y+F.Y, F.W, Display.replace);
						Update(F.style, fmode, modif)
					END
				END
			END;
			res := 0
		ELSIF Keys = {ML} THEN
			REPEAT TrackMouse(X, Y, Keys, keysum) UNTIL Keys = {};
			IF MR IN keysum THEN	(*copy attributes to selection*)
				res := 0;
				IF ~(MM IN keysum) THEN Styles.SelStyle(style);
					IF style # NIL THEN	(*selection exists*)
						style.opts := F.style.opts;
						style.paraW := F.style.paraW; style.left := F.style.left; style.lsp := F.style.lsp; style.dsr := F.style.dsr;
						style.gap := F.style.gap; style.nTabs := F.style.nTabs; style.tab := F.style.tab;
						Update(style, tabs+1, 0)
					END
				END
			END;
			res := 0
		END
	END Edit;

	PROCEDURE CopyF(s, d: Frame);
	BEGIN
		d.handle := s.handle; d.lib := s.lib; d.ref := s.ref;
		d.next := s.next; d.dsc := s.dsc; d.slink := s.slink;
		d.X := s.X; d.Y := s.Y; d.W := s.W; d.H := s.H;
		d.style := s.style;
	END CopyF;

	PROCEDURE Restore(F: Frame; msk: Display3.Mask; x, y: SIGNED16);
	BEGIN
		Oberon.RemoveMarks(x+F.X, y+F.Y, F.W, F.H);
		Display3.ReplConst(msk, F.col, x+F.X, y+F.Y, F.W, F.H, 0);
		DrawBar(F, msk, x, y, F.W)
	END Restore;

	PROCEDURE Handle(F: Objects.Object; VAR M: Objects.ObjMsg);	(* volatile frame never stored/bound etc. *)
	VAR
		F1: Frame;
		x, y: SIGNED16;
		msk: Display3.Mask;
	BEGIN
		WITH F: Frame DO
			IF M IS Display.FrameMsg THEN
				WITH M: Display.FrameMsg DO
					IF (M.F = NIL) OR (M.F = F) THEN
						x := M.x; y := M.y; msk := NIL;
						IF M IS Oberon.InputMsg THEN
							WITH M: Oberon.InputMsg DO
								IF (M.id = Oberon.track) & (F.H = BoxH) THEN
									Gadgets.MakeMask(F, x+F.X, y+F.Y, M.dlink, msk);
									Edit(F, msk, x, y, M.X, M.Y, M.keys, M.res)
								END
							END
						ELSIF M IS Display.DisplayMsg THEN
							IF (F = M.F) & (M(Display.DisplayMsg).device = Display.screen) THEN
								Gadgets.MakeMask(F, x+F.X, y+F.Y, M.dlink, msk);
								Restore(F, msk, x, y)
							END
	(*
						ELSIF M IS Display.SelectMsg THEN
							WITH M: Display.SelectMsg DO
								IF M.id = Display.set THEN F.sel := 1
								ELSIF M.id = Display.reset THEN F.sel := 0
								END
							END
	*)
						ELSIF M IS Display.ModifyMsg THEN
							WITH M: Display.ModifyMsg DO
								IF (M.id = Display.move) & (M.F = F)  & (M.mode # Display.state) THEN
									F.Y := M.Y; F.X := M.X;
									Gadgets.MakeMask(F, x+F.X, y+F.Y, M.dlink, msk);
									Restore(F, msk, x, y)
								END
							END
						ELSIF M IS Styles.UpdateMsg THEN
							WITH M: Styles.UpdateMsg DO
								IF F.style = M.obj THEN
									Gadgets.MakeMask(F, x+F.X, y+F.Y, M.dlink, msk);
									Restore(F, msk, x, y)
								END
							END
						ELSIF M IS Display.ControlMsg THEN Gadgets.framehandle(F, M)
						ELSIF M IS Oberon.ControlMsg THEN Gadgets.framehandle(F, M)
						ELSE Gadgets.framehandle(F, M)
						END
					END
				END
			ELSIF M IS Objects.CopyMsg THEN
				WITH M: Objects.CopyMsg DO
					NEW(F1); CopyF(F, F1);	(* F1^ := F^; *)
					IF M.id = Objects.deep THEN F.style.handle(F.style, M); F1.style := M.obj(Styles.Style) END;
					M.obj := F1
				END
			ELSIF M IS Objects.AttrMsg THEN
				WITH M: Objects.AttrMsg DO
					IF M.id = Objects.get THEN
						IF M.name = "Transparent" THEN M.b := TRUE
						ELSIF M.name = "Gen" THEN (* ignore *)
						ELSE Gadgets.framehandle(F, M)
						END
					ELSE Gadgets.framehandle(F, M)
					END
				END
			ELSE F.style.handle(F.style, M);
				Gadgets.framehandle(F, M);
			END
		END
	END Handle;

	PROCEDURE NewFrame* (style: Styles.Style): Display.Frame;
		VAR F: Frame;
	BEGIN
		NEW(F); F.handle := Handle; F.W := scnW; F.H := BoxH; F.style := style; RETURN F
	END NewFrame;

	PROCEDURE Insert*;
		VAR M: Display.ConsumeMsg;
	BEGIN M.id := Display.integrate;
		M.F := NIL; M.obj := Styles.NewStyle(); Display.Broadcast(M)
	END Insert;

(* ------ commands ------ *)

	PROCEDURE Init;
		VAR
		img: ARRAY 32 OF SET;
		i: SIGNED32;
	BEGIN
		img[0] := {0,2,4,6,8,10,12,14,16,18,20,22,24,26,28,30}; (*055555555H*)
		FOR i := 1 TO 31 DO
			img[i] := img[0]
		END;
		dash := Display.NewPattern(32, 32, img);
		img[0] := {2,6,10,14,18,22,26,30}; (*044444444H*)
		FOR i := 1 TO 31 DO
			img[i] := img[0]
		END;
		dash2 := Display.NewPattern(32, 32, img)
	END Init;

BEGIN
	Texts.OpenWriter(W); Init;
	nfnt := Fonts.This("Default8.Scn.Fnt")
END StyleGadgets.
ScriptGadgets.ModX
System.Free ScriptGadgets StyleGadgets ~
Desktops.OpenDoc X.Panel

Gadgets.Insert ScriptGadgets.NewFrame ~
Gadgets.Insert Button ~
StyleGadgets.Insert
