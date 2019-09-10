(* ETH Oberon, Copyright 2001 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

MODULE ScriptGadgets IN Oberon; (** portable *)	(* RS, Wed, 9-Jun-1993 / KR, Mon, 23-Aug-1993*)
(* KR Mon, 23-Aug-1993 adaptStyle, scrollup, hook, attributes from left
	KR Thu, 26-Aug-1993 Mark
	KR Tue, 14-Sep-1993 Make ScriptGadgets work in MenuViewers & JG-Scroll
	KR Wed, 22-Sep-1993 Mask corrected
	KR Fri, 15-Oct-1993 Oberon.Call
	KR Wed, 20-Oct-1993 F.view := NIL removed
	RS Thu, 21-Oct-93 LinkMsg instead of DisplaySecBrk
	RS Mon, 25-Oct-1993 PrintMsg implemented
	KR Mon, 25-Oct-1993 handle of ModifyMsg corrected, 2nd view no flicker !
	KR Tue, 26-Oct-1993 org - implemented
	RS/KR Thu, 25-Nov-1993 CalcSize
	KR Fri, 26-Nov-1993 Remove restore - flicker
	KR Wed, 1-Dec-1993 recursive struktures
	RS/KR Wed, 15-Dec-1993 restore area
	RS Thu, 6-Jan-1994 locate in caret & selectmsg
	KR Wed, 12-Jan-1994 flat canvas
	KR Mon, 24-Jan-1994 display msg brcst
	KR Fri, 28-Jan-1994 don't show caret (showCaret)
	KR Fri, 4-Feb-1994 CaretMsg
	KR Wed, 16-Feb-1994 Erase last line fixed
	KR Sat, 19-Feb-1994 version 1; obj # text
	KR Fri, 11-Mar-1994 fix resize show all lines
	RS/KR Thu, 17-Mar-1994 scrollback at last line fixed
	KR Sat, 19-Mar-1994 track full line
	KR Tue, 22-Mar-1994 edit inserted
	KR Mon, 28-Mar-1994 StyleGadgets
	KR Fri, 8-Apr-1994 F.mask := NIL removed
	KR  Fri, 15-Apr-1994  version 2 state 0
	RS Fri, 15-Apr-1994 eot Height corrected (Formatline) narrow option
	KR Tue, 19-Apr-1994 scroll to top with 2-Button Mouse
	KR Thu, 21-Apr-1994 fast scroll
	KR Fri, 29-Apr-1994 deep copy
	KR Mon, 16-May-1994 hide because RS wanted it
	RS Wed, 15-Jun-1994 sophisticated scroll bar/tick
	RS Tue, 31-Jan-1995 new release
	*)

	(* still to do
		text may be view of integer or real <>	model = text if object = NIL
		modell equal integer => rel to pos
		TextAttr => ModelAttr
	*)

	IMPORT Texts, Fonts, Objects, Oberon, Styles, StyleGadgets,  Input, Display, Modules, Files, Gadgets, Display3, Effects,
		Printer, Printer3;


	CONST
		insert* = 0; delete* = 1; change* = 2;
		TAB = 09X;	CR = 0DX;	LeftArrow = 0C4X;	RightArrow = 0C3X;	(*special chars*)
		SpcW = 3;
		ML = 2;	MM = 1;	MR = 0;

		LeftMode = {Styles.left};
		RightMode = {Styles.right};
		AdjMode = {Styles.left, Styles.right};
		CenterMode = {};

		car = 0; sel = 1; arrow = -1; (* MarkMsg id *)

		(*  Scn0Unit = 10973;	 factor to multiply screen metrics with in order to approximate printer width *)
		PrtUnit = 3048;
		flat = 0;  down = 1;  up = 2; border = 3;
		adaptStyle* = Styles.break + 1;
		scrollup* = adaptStyle + 1;
		scrollback* = scrollup + 1;
		drop* = scrollback +1;
		underlineOff* = drop +1;
		autoScroll* = underlineOff +1;
		fullLine * = autoScroll + 1;
		lineBrkOff* = fullLine +1;
		narrow* =lineBrkOff +1;
		hide = narrow+1;
		version = 2;


	TYPE
		Box = POINTER TO BoxDesc;
		Line = POINTER TO LineDesc;
		LineDesc = RECORD
			len, W: SIGNED32;
			w, h: SIGNED16;
			asr, dsr: SIGNED16;
			off, w0: SIGNED16;
			nSpc: SIGNED16;
			style: Styles.Style;
			brk, eot, tabs: BOOLEAN;
			next: Line;
			box: Box
		END;

		Location* = RECORD
			org*, pos*: SIGNED32;
			dx*, x*, y*: SIGNED16;
			lin: Line
		END;

		Frame* = POINTER TO FrameDesc;
		FrameDesc* = RECORD (Gadgets.ViewDesc)
			background*: PROCEDURE (F:Frame; x, y: SIGNED16; R: Display3.Mask); (* region is in absolute coords *)
			edit* : PROCEDURE(F : Frame; id : SIGNED16; beg, end : SIGNED32; text : Texts.Text);
			text*: Texts.Text;
			org*: SIGNED32;
			left*, right*, top*, bot*: SIGNED16;
			markH*, mark*: SIGNED16;
			time*: SIGNED32;
			car*, sel*, hide*, hidetext*: BOOLEAN;
			carLoc*: Location;
			selBeg*, selEnd*: Location;
			trailer: Line;
			hook* : Display.Pattern;
			cmd*  : ARRAY 64 OF CHAR;
			pointPos* : SIGNED32;
			point*, select* : POINTER TO ARRAY 64 OF CHAR;
			profile* : SIGNED16;
			msk: Display3.Mask;
			defStyle* : Styles.Style;
			save: Line;
			sorg : SIGNED32;
			deleting : BOOLEAN;
			state0* : SET;
			col*: SIGNED16
		END;

	(*mark < 0: arrow mark
		mark = 0: no mark*)

		Formatter = RECORD(Texts.Reader)
			len, W: SIGNED32;
			w, asr, dsr, nSpc: SIGNED16;
			hide, narrow: BOOLEAN;
			fnt, mfnt: Fonts.Font;
			unit: SIGNED32
		END;

		MarkMsg = RECORD(Display.FrameMsg)
			id: SIGNED16;
			absX, absY : SIGNED16;
		END;
		DisplayMsg = RECORD(Display.FrameMsg)
			pos: SIGNED32;
		END;
		FocusMsg = RECORD(Display.FrameMsg)
			foc: Frame
		END;

		CaretMsg* = RECORD(Display.FrameMsg)
			id* : SIGNED16;
			frame* : Frame; pos* : SIGNED32;
		END;

		BoxDesc = RECORD
			next: Box;
			F: Display.Frame;
			off: SIGNED32;
			X, dY: SIGNED16
		END;

		RecursiveMsg = RECORD (Display.FrameMsg)
			text : Texts.Text;
			rec : BOOLEAN
		END;

	VAR
		barW*, left*, right*, top*, bot*: SIGNED16; (*standard sizes*)
		Asr, Dsr, markW, eolW: SIGNED16;

		R1: Texts.Reader;	(* displayer *)
		fnt, mfnt: Fonts.Font; unit: SIGNED32;	(*cache*)
		R: Formatter;
		ch: CHAR;
		dx, a, d: SIGNED16;
		dX: SIGNED32;
		style: Styles.Style;

		W, KW, XW: Texts.Writer; (*keyboard writer*)

		nomarks : BOOLEAN;
		hook : Display.Pattern;
		hookS : ARRAY 12 OF SET;
		visible : BOOLEAN;
		showCaret : BOOLEAN;
		show: PROCEDURE(F: Frame; pos: SIGNED32);
		repeatTime, waitTime : SIGNED32;
		block : BOOLEAN;

	PROCEDURE Min (i, j: SIGNED32): SIGNED32;
	BEGIN IF i >= j THEN RETURN j ELSE RETURN i END
	END Min;

	PROCEDURE Max (i, j: SIGNED16): SIGNED16;
	BEGIN IF j >= i THEN RETURN j ELSE RETURN i END
	END Max;

	PROCEDURE Txt(buf : Texts.Buffer) : Texts.Text;
		VAR tmp : Texts.Text;
	BEGIN
		NEW(tmp); Texts.Open(tmp,""); Texts.Append(tmp,buf); RETURN tmp
	END Txt;

	PROCEDURE Recursive(parent : Frame;  newchild : Objects.Object) : BOOLEAN;
		VAR  M: RecursiveMsg;
	BEGIN
		M.text := parent.text; M.rec := FALSE; M.F := NIL; M.dlink := NIL;
		newchild.handle(newchild,M);
		RETURN M.rec
	END Recursive;

	(*---display support & misc---*)
	(*
	PROCEDURE View(F: Frame): Display.Frame;
		VAR view: Gadgets.View;
	BEGIN
		IF (F.view = NIL) OR TRUE THEN NEW(view); F.view := view ELSE view := F.view(Gadgets.View) END;
		view.dlink := F;
		view.absX := F.absX; view.absY := F.absY; view.W := F.W; view.H := F.H; view.border := 6;
		view.mask := F.msk;
		RETURN view
	END View;
	*)
	PROCEDURE InvC(col : SIGNED16) : SIGNED16;
	BEGIN
		IF col = Display3.textbackC THEN RETURN 1
		ELSIF (col = Display.BG) OR (col = Display3.white) THEN RETURN Display3.FG
		ELSIF col > 0  THEN RETURN 15 - col
		ELSE RETURN Display3.FG
		END
	END  InvC;

	PROCEDURE Marks(F: Frame; id: SIGNED16);
		VAR M: MarkMsg;
	BEGIN M.absX := MIN(SIGNED16); M.id := id; M.F := F; Display.Broadcast(M)
	END Marks;

	PROCEDURE Mark*(F: Frame; mark : SIGNED16);
	BEGIN Marks(F, arrow)
	END Mark;

	PROCEDURE Caret(F : Frame; pos : SIGNED32; id : SIGNED16);
		VAR M : CaretMsg;
	BEGIN
		M.frame := F; M.pos := pos; M.id := id; M.F := NIL;
		Display.Broadcast(M);
	END Caret;

	PROCEDURE DrawCursor(X, Y: SIGNED16);
	BEGIN Oberon.DrawCursor(Oberon.Mouse, Effects.Arrow, X, Y)
	END DrawCursor;

	PROCEDURE TrackMouse(VAR X, Y: SIGNED16; VAR Keys, keysum: SET);
	BEGIN Input.Mouse(Keys, X, Y); DrawCursor(X, Y); keysum := keysum + Keys
	END TrackMouse;

	PROCEDURE InvertRect(F: Frame; x, y, X, Y, W, H: SIGNED16);
	BEGIN INC(X, x+F.X); INC(Y, y+F.Y); Oberon.RemoveMarks(X, Y, W, H);
		IF X + W <= x+F.X + F.W THEN Display3.ReplConst(F.msk,InvC(F.col), X, Y, W, H, Display3.invert)
		ELSIF X < x+F.X + F.W THEN Display3.ReplConst(F.msk,InvC(F.col), X, Y, x+F.X + F.W - X-1, H, Display3.invert)
		END;
	END InvertRect;

	PROCEDURE RemoveMark(F : Frame);
	BEGIN
		IF ~ nomarks THEN Oberon.RemoveMarks(F.absX,F.absY,F.W,F.H) END;
	END RemoveMark;

	PROCEDURE ReplConst(msk : Display3.Mask; col, x, y, w, h: SIGNED16);
	BEGIN
		IF ~ nomarks THEN Oberon.RemoveMarks(x, y, w, h) END;
		Display3.ReplConst(msk, col, x, y, w, h, Display.replace)
	END ReplConst;


	PROCEDURE Background(F : Frame; x, y, X, Y, W, H : SIGNED16);
		VAR mX,mY,mW,mH : SIGNED16;
	BEGIN
		IF F.background = NIL THEN
			ReplConst(F.msk,F.col, X, Y, W, H);
		ELSE
			mX := F.msk.X; mY := F.msk.Y; mW := F.msk.W; mH := F.msk.H;
			Display3.AdjustMask(F.msk,X, Y,W,H);
			RemoveMark(F);
			F.background(F, x, y, F.msk);
			F.msk.X := mX; F.msk.Y := mY; F.msk.W := mW; F.msk.H := mH;
		END
	END Background;

	PROCEDURE Erase(F: Frame; x, y, X, Y, H, R: SIGNED16);	(* erase content *)
	BEGIN
		Background(F,x, y, x+F.X + F.left + X, y+F.Y+Y, F.W - F.left-1 -X-R, H);
	END Erase;

	PROCEDURE RemTick(F: Frame; x, y: SIGNED16);
	BEGIN
		IF F.left >= barW THEN
			Background(F, x, y, x+F.X+1,y+F.Y + 1,markW, F.H - 2);
		END
	END RemTick;

	PROCEDURE ShowTick(F: Frame; x, y: SIGNED16);	(*update*)
		VAR t, b: SIGNED16;
	BEGIN
		IF F.left >= barW THEN
			IF (F.profile = flat) OR (F.profile = border) THEN
				F.markH := SHORT(F.org * (F.H-2)  DIV (F.text.len + 1))  ;
				ReplConst(F.msk,Display.FG, x+F.X+1, y+F.Y + F.H - 2 - F.markH, markW, 1)
			ELSE
				F.markH := SHORT(F.org * (F.H-4)  DIV (F.text.len + 1))  ;	(*4: height of tick + border*)
				IF F.profile = down THEN b := Display3.bottomC; t := Display3.topC
				ELSE b := Display3.topC; t := Display3.bottomC
				END;
				ReplConst(F.msk,t, x+F.X+2, y+F.Y + F.H - 2 - F.markH, markW-1, 1);
				ReplConst(F.msk,b, x+F.X+2, y+F.Y + F.H - 3 - F.markH, markW-1, 1);
			END
		END
	END ShowTick;

	PROCEDURE Bar(F: Frame; x, y, Y, H: SIGNED16);
		VAR h,v , b, t, d, p: SIGNED16;
	BEGIN
		h := F.H; F.H := H; v := F.Y; F.Y := F.Y + Y;
		(*
		Background(F,x, y, x+F.X,y+F.Y, F.W, H);
		*)
		p := F.profile;
		RemoveMark(F);
		nomarks := TRUE;
		IF (F.background # NIL) OR (p = flat)  THEN d := 0 ELSE d := 1 END;
		Background(F, x, y, F.absX+d, F.absY +F.H - F.top, F.W-2*d,F.top-d); (* top *)
		Background(F, x, y, F.absX+d, F.absY +d, F.W-2*d, F.bot-d); (* bottom*)
		Background(F, x, y, F.absX+d,  F.absY +d, F.left-d, F.H-2*d); (* left *)
		Background(F, x, y, F.absX+F.W-F.right,  F.absY +d, F.right-d, F.H-2*d); (* right *)
		F.H := h; F.Y := v;
		IF p = down THEN
			b := Display3.bottomC; t := Display3.topC
		ELSIF p = up THEN
			b := Display3.topC; t := Display3.bottomC;
		ELSE
			IF F.col # Display3.textbackC THEN
				b := Display3.textbackC;
			ELSE
				b := Display3.downC
			END;
			t := b;
		END;
		IF (p # flat)  & (F.background = NIL) THEN
			Display3.Rect3D(F.msk, b, t, F.absX,F.absY,F.W,H,1,Display.replace);
			IF (F.col = Display3.white) OR (F.col = Display.BG) THEN
				Display3.ReplConst(F.msk, Display3.textbackC, F.absX,F.absY,1,H,Display.replace);
			END;
		END;
		IF F.left >= barW THEN (* bar *)
			IF (p = flat) OR (p = border) THEN
				ReplConst(F.msk,Display3.FG, F.absX + barW - 1, y + F.Y + Y, 1, H)
			ELSE
				ReplConst(F.msk,b, F.absX + barW - 1, y + F.Y + Y, 1, H);
				ReplConst(F.msk,t, F.absX + barW - 2, y + F.Y + Y, 1, H)
			END
		END;
		nomarks  := FALSE;
	END Bar;

	PROCEDURE FrameDsr(F: Display.Frame): SIGNED16;
		VAR B: Objects.AttrMsg;
	BEGIN B.dlink := NIL;
	(*		IF narrow & ~(F IS StyleGadgets.Frame) THEN B.i := 3 ELSE B.i := 0 END; *)
		B.i := 0;
		Objects.Stamp(B);
		B.res := -1; B.id := Objects.get; B.name := "LineupHY"; F.handle(F, B); RETURN SHORT(B.i)
	END FrameDsr;


	(*

	PROCEDURE StyleReplConst(col, X, Y, W, H, mode: SIGNED16);
	BEGIN
		Display3.ReplConst(styleMask,col, X, Y, W, H, mode);
	END StyleReplConst;

	PROCEDURE StyleReplPattern(col: SIGNED16; pat: SIGNED32; X, Y, W, H, mode: SIGNED16);
	BEGIN
		Display3.FillPattern(styleMask, col, pat, 0,0, X, Y, W, H, mode);
	END StyleReplPattern;

	PROCEDURE StyleCopyPattern(col: SIGNED16; pat: SIGNED32; X, Y, mode: SIGNED16);
	BEGIN
		Display3.CopyPattern(styleMask,col, pat,X, Y, mode);
	END StyleCopyPattern;

	PROCEDURE InitStyle(F : Frame);
	BEGIN
		INC(styleC);
		styleMask := F.msk;
		Styles.ReplConst := StyleReplConst; Styles.ReplPattern := StyleReplPattern; Styles.CopyPattern := StyleCopyPattern;
	END InitStyle;

	PROCEDURE CloseStyle;
	BEGIN
		DEC(styleC); IF styleC = 0 THEN Styles.Init END;
	END CloseStyle;
	*)


	PROCEDURE DrawFrame(F: Frame; G: Display.Frame; x, y, X, Y: SIGNED16);
	VAR M: Display.DisplayMsg; N: Display.ControlMsg; col : SIGNED16;  A : Objects.AttrMsg;
	BEGIN
		A.id := Objects.get; A.name := "Gen";G.handle(G,A);
		IF A.s = "Illustrate.NewCanvas" THEN
			A.id := Objects.set; A.name := "Flat"; A.b := TRUE; A.class := Objects.Bool; G.handle(G,A);
			A.id := Objects.set; A.name := "Color"; A.i := F.col;  A.class := Objects.Int; G.handle(G,A);
		END;

		INC(x, F.X + X); INC(y, F.Y + Y);
		IF X >= F.W-F.right THEN RETURN END;
		N.id := Display.restore; N.res := -1; N.F := G; Objects.Stamp(N);	(*restore*)
		N.dlink := F; N.x := x - G.X; N.y := y - G.Y; G.handle(G, N);
		M.device := Display.screen; M.id := Display.full; M.res := -1; M.F := G; Objects.Stamp(M);
		M.dlink := F; M.x := x - G.X; M.y := y - G.Y;

		IF G IS StyleGadgets.Frame THEN
			(* InitStyle(F); *)
			col := F.col;
			IF F.col = Display3.textbackC  THEN col :=  14 ELSIF col  < 0 THEN  col := Display.FG END; G(StyleGadgets.Frame).col :=col;
			G.handle(G, M);
			(* CloseStyle; *)
		ELSE
			G.handle(G, M);
		END;
	END DrawFrame;

	PROCEDURE Move(F: Frame; x, y, Y, H, dY: SIGNED16);	(* move content including frames *)
	VAR w: SIGNED16;
	BEGIN INC(x, F.X+F.left); INC(y, F.Y+Y); w := F.W - F.left;
		Oberon.RemoveMarks(x, SHORT(Min(y, y+dY)), w, Max(H+dY, H-dY));
		Display.CopyBlock (x, y, w, H, x, y + dY, 0);
	END Move;

	PROCEDURE FlipCaret (F: Frame; x, y: SIGNED16);
	BEGIN
		 IF  (F.carLoc.y >=  4) &  (F.carLoc.x + 6 < F.W) THEN
			INC(x,F.X + F.carLoc.x) ; INC(y ,F.Y + F.carLoc.y - 10);
			Oberon.RemoveMarks(x, y, 20, 20 );
			Display3.CopyPattern(F.msk,InvC(F.col), F.hook, x, y, Display3.invert)
		 END
	END FlipCaret;

	(*---frames---*)
	PROCEDURE Insert(L: Line; X, voff: SIGNED16; off: SIGNED32; G: Display.Frame; VAR dY: SIGNED16);
	VAR b, p: Box;
	BEGIN NEW(b); b.X := X; b.F := G; dY := FrameDsr(G)-voff; b.dY := dY; b.off := off;
		p := L.box;
		IF p = NIL THEN NEW(p); p.next := p; p.X := MAX(SIGNED16); L.box := p END;
		WHILE p.next.X < X DO p := p.next END;
		b.next := p.next; p.next := b
	END Insert;

	PROCEDURE Append(L: Line; X: SIGNED16; b: Box);	(*append everything up to X*)
	VAR p: Box;
	BEGIN
		IF b # NIL THEN p := b;
			WHILE (p.next # b) & (p.next.X + p.next.F.W <= X) DO p := p.next END; 	(*p.next.X + p.next.F.W > X*)
			IF p # b THEN	(*list ~empty*)
				IF L.box = NIL THEN L.box := b; p.next := b
				ELSE p.next := L.box.next; L.box.next := b.next
				END
			END
		END
	END Append;

	PROCEDURE Broadcast(F: Frame; VAR M: Display.FrameMsg);
	VAR x, y, Y: SIGNED16; L: Line; msk: Display.Frame;

		PROCEDURE Broadcast0(box: Box; y: SIGNED16; VAR M: Display.FrameMsg);
		VAR b: Box; G: Display.Frame;
		BEGIN b := box.next;
			WHILE b # box DO G := b.F;
				M.dlink := msk;
				M.x :=  x+b.X - G.X; M.y := y - b.dY - G.Y; G.handle(G, M);
				b := b.next
			END
		END Broadcast0;

	BEGIN
		x := M.x + F.X; y := M.y + F.Y;
		Y := F.H-F.top; L := F.trailer.next; msk :=F;
		WHILE (M.res < 0) & (L # F.trailer) & (L # NIL) DO DEC(Y, L.h);	(*Broadcast while formatting !!!*)
			IF L.box # NIL THEN Broadcast0(L.box, y+Y+L.dsr, M) END;
			L := L.next
		END;
	END Broadcast;

	(*---select---*)

	PROCEDURE InvertArea(F: Frame; L: Line; x, y, X, Y, W: SIGNED16);
	VAR X0, H0, H1: SIGNED16; b: Box; G: Display.Frame;
	BEGIN
		IF L.box # NIL THEN b := L.box.next;
			WHILE b.X < X DO b := b.next END;
			WHILE (b.X < X+W) & ~(b.F IS StyleGadgets.Frame) DO
				G := b.F; X0 := b.X; H0 := L.dsr - b.dY; H1 := L.h - G.H - H0;
				IF X < X0 THEN InvertRect(F, x, y, X, Y, X0-X, L.h) END;	(*before*)
				IF H0 > 0 THEN InvertRect(F, x, y, X0, Y, G.W, H0) END;	(*below*)
				IF H1 > 0 THEN InvertRect(F, x, y, X0, Y+H0+G.H, G.W, H1) END;	(*above*)
				INC(X0, G.W); DEC(W, X0-X); X := X0;
				b := b.next
			END
		END;
		InvertRect(F, x, y, X, Y, W, L.h)
	END InvertArea;

	PROCEDURE FlipSelection (F: Frame; x, y: SIGNED16; VAR beg, end: Location);
	VAR L: Line; Y : SIGNED16;
	BEGIN
		L := beg.lin; Y := beg.y - L.dsr;	(* Y = bottom of line *)
		(*
		IF fullLine THEN
			LOOP
				InvertRect(F, x, y, F.left + L.off, Y, F.W- F.left-L.off-F.border , L.h);
				IF L = end.lin  THEN EXIT END;
				L := L.next; DEC(Y, L.h);
			END;
		ELS *)
		IF L = end.lin THEN InvertArea(F, L, x, y, beg.x, Y, end.x - beg.x)
		ELSE
			InvertArea(F, L, x, y, beg.x, Y, F.left + L.off + L.w0 - beg.x); L := L.next; DEC(Y, L.h);
			WHILE L # end.lin DO
				InvertArea(F, L, x, y, F.left + L.off, Y, L.w0); L := L.next; DEC(Y, L.h)
			END;
			InvertArea(F, L, x, y, F.left + L.off, Y, end.x - F.left - L.off)
		END
	END FlipSelection;

	PROCEDURE Deselect(F: Frame; G: Display.Frame);
		VAR S: Display.SelectMsg;
	BEGIN S.res := -1; S.x := 0; S.y := 0; S.id := Display.reset;
		S.sel := F; S.obj := G; S.dlink :=F; Objects.Stamp(S);
		S.F := G; G.handle(G, S)
	END Deselect;

	(*---lines---*)

	PROCEDURE Lim(F: Frame): SIGNED32;
	VAR pos: SIGNED32; L: Line;
	BEGIN
		pos := F.org; L := F.trailer.next;
		WHILE L # F.trailer DO INC(pos, L.len); L := L.next END;
		RETURN pos
	END Lim;

	PROCEDURE CollectLines(F: Frame; VAR L: Line; VAR Y: SIGNED16; VAR org: SIGNED32);
	BEGIN
		WHILE (L.next # F.trailer) & (Y >= F.bot + L.next.h) DO
			L := L.next; INC(org, L.len); DEC(Y, L.h)
		END
	END CollectLines;

	(*---objects---*)

(*	PROCEDURE Objs(T: Texts.Text): Objects.Library;
	BEGIN IF (T.obs = NIL) OR (T.obs.maxref >= 256) THEN NEW(T.obs); Objects.OpenLibrary(T.obs) END; RETURN T.obs
	END Objs;*)

	PROCEDURE Clone(obj: Objects.Object; id: SIGNED16; VAR new: Objects.Object);
	VAR M: Objects.CopyMsg;
	BEGIN M.id := id; Objects.Stamp(M); obj.handle(obj, M); new := M.obj;	(* copy *)
	(*	IF lib # NIL THEN N.lib := lib; Objects.Stamp(N); new.handle(new, N) END	(* bind *)*)
	END Clone;

	PROCEDURE SaveAndCopy(F: Frame; text : Texts.Text; beg, end: SIGNED32; VAR W: Texts.Writer);
	VAR
		R: Texts.Finder;
		obj, new: Objects.Object;
	BEGIN
		IF end > text.len THEN end := text.len END;
		Texts.OpenFinder(R, text, beg);
		WHILE R.pos < end DO
			IF beg < R.pos THEN Texts.Save(text, beg, R.pos, W.buf) END;
			beg := R.pos; Texts.FindObj(R, obj);
			IF obj IS Display.Frame THEN
				IF ~((obj IS Frame) & ((obj(Frame).text = F.text) OR (Recursive(F,obj))))   THEN
					(*lib := Objs(F.text); Clone(obj, Objects.shallow, lib, new); ch := CHR(new.ref);
					Texts.SetFont(W, lib); Texts.Write(W, ch); *)
					Clone(obj, Objects.shallow, new);
					Texts.WriteObj(W, new)
				END;
				INC(beg)
			END
		END;
		IF beg < end THEN Texts.Save(text, beg, end, W.buf) END
	END SaveAndCopy;

	PROCEDURE StyleAt(F: Frame; pos: SIGNED32): Styles.Style;
	VAR R: Texts.Finder;
		obj: Objects.Object; style: Styles.Style;
	BEGIN Texts.OpenFinder(R, F.text, 0);
		IF F.defStyle = NIL THEN F.defStyle := Styles.defStyle END;
		style := F.defStyle;
		IF adaptStyle IN F.defStyle.opts THEN  F.defStyle.paraW := LONG(F.W - F.right- F.left) * Display.Unit END;
		WHILE ~R.eot & (R.pos <= pos) DO
			Texts.FindObj(R, obj); IF (obj # NIL) & (obj IS Styles.Style) THEN style := obj(Styles.Style) END
		END;
		RETURN style
	END StyleAt;

	PROCEDURE StyleFrame(F: Frame; st: Styles.Style; X: SIGNED16): Objects.Object;
	VAR G: Display.Frame;
	BEGIN G := StyleGadgets.NewFrame(st); G.W := SHORT(st.paraW DIV Display.Unit);
		IF G.W > F.W-F.right - X THEN G.W := F.W-F.right - X END;
		IF F.hide THEN G.H := 1 END;
		RETURN G
	END StyleFrame;

	(*---display---*)

	PROCEDURE Offsets(L: Line; VAR spc, rest: SIGNED16);
	VAR
		width, diff: SIGNED16;
		s: Styles.Style;
		mode: SET;
	BEGIN
		rest := 0; spc := 0; L.w0 := L.w; s := L.style;
		IF L.brk THEN INC(L.w0, eolW) ELSE INC(L.w0, SpcW) END;
		IF s # NIL THEN
			L.off := SHORT(s.left DIV Display.Unit);
			mode := s.opts * AdjMode;
			IF mode = LeftMode THEN RETURN
			ELSE width := SHORT(s.paraW DIV Display.Unit); diff := width - L.w;
				IF mode = AdjMode THEN
					IF L.brk OR (L.nSpc = 0) THEN RETURN END;	(* = left adjust for last line/one word*)
					L.w0 := width+SpcW; spc := diff DIV L.nSpc; rest := diff MOD L.nSpc
				ELSIF mode = CenterMode THEN INC(L.off, diff DIV 2)
				ELSIF mode = RightMode THEN INC(L.off, diff)
				END
			END
		END
	END Offsets;

	PROCEDURE IncPos(spc: SIGNED16; VAR rest, X: SIGNED16);
	BEGIN INC(X, spc); IF rest > 0 THEN INC(X); DEC(rest) END
	END IncPos;

	PROCEDURE GetWidth(lib: Objects.Library; ch: CHAR; VAR obj: Objects.Object; VAR dx: SIGNED16; VAR dX: SIGNED32);
	BEGIN
		IF lib IS Fonts.Font THEN
			IF lib # fnt THEN fnt := lib(Fonts.Font); Styles.MetricFnt(fnt, unit, mfnt) END;	(*cache!!*)
			mfnt.GetObj(mfnt, ORD(ch), obj); dX := obj(Fonts.Char).dx*unit;
			lib.GetObj(lib, ORD(ch), obj); dx := obj(Fonts.Char).dx
		ELSE lib.GetObj(lib, ORD(ch), obj);
			IF obj IS Display.Frame THEN dx := obj(Display.Frame).W; dX := dx * LONG(PrtUnit); RETURN
			ELSIF obj IS Styles.Style THEN dX := obj(Styles.Style).paraW; dx := SHORT(dX DIV Display.Unit); RETURN
			ELSE dx := 2; dX := 2*PrtUnit
			END
		END
	END GetWidth;

	PROCEDURE Width(F: Frame; L: Line; beg, end: SIGNED32; VAR x: SIGNED16; VAR X: SIGNED32);
		VAR R: Texts.Reader; obj: Objects.Object;
		pos: SIGNED32; dx: SIGNED16; ch: CHAR;
		spc, rest: SIGNED16;
		DX: SIGNED32;
	BEGIN Offsets(L, spc, rest);
		Texts.OpenReader(R, F.text, beg); Texts.Read(R, ch);
		pos := beg; x := 0; X := 0;
		WHILE pos <  end DO
			GetWidth(R.lib, ch, obj, dx, DX);
			IF obj IS Fonts.Char THEN
				IF ch = TAB THEN Styles.Tab(L.style, R.lib(Fonts.Font), x, X, dx, DX)
				ELSIF ch = " " THEN IncPos(spc, rest, x)
				END
			END;
			INC(x, dx); INC(X, DX);
			INC(pos);
			Texts.Read(R, ch)
		END
	END Width;

	PROCEDURE Height(fnt: Fonts.Font; narrow : BOOLEAN; VAR a, d: SIGNED16);	(*rule line height = 1.2*font height*)
	BEGIN
		IF narrow THEN a := fnt.maxY; d := fnt.height  -a; INC(a);
		ELSE a := 6*fnt.maxY DIV 5; d := (6*fnt.height DIV 5) - a END
	END Height;

	PROCEDURE DisplayLine (F: Frame; pos, dXX: SIGNED32; x, y, dX, Y: SIGNED16; L: Line);	(*dX = offset into lineblock*)
	VAR
		X0, Y0, XT, x0, y0, dx, v, off, dY, bY, a, d: SIGNED16;
		X, DX: SIGNED32;
		spc, rest: SIGNED16;
		obj: Objects.Object; G: Display.Frame;
		ch: CHAR;

		PROCEDURE GetObj(lib: Objects.Library; ch: CHAR; VAR obj: Objects.Object; VAR dx: SIGNED16; VAR DX: SIGNED32);
		BEGIN GetWidth(lib, ch, obj, dx, DX);
			IF lib IS Fonts.Font THEN
				IF ch > " " THEN RETURN
				ELSIF ch = " " THEN INC(dx, spc); IF rest > 0 THEN INC(dx); DEC(rest) END; RETURN
				ELSIF ch = TAB THEN Styles.Tab(L.style, lib(Fonts.Font), X0-x0, X, dx, DX); RETURN
				END
			ELSIF obj IS Styles.Style THEN obj := StyleFrame(F, obj(Styles.Style), X0-x0+off);
				dx := obj(Display.Frame).W; DX := LONG(dx)*PrtUnit
			END
		END GetObj;

	BEGIN
		IF ~F.hidetext THEN
			Offsets(L, spc, rest); off := F.left+L.off; L.box := NIL;
			x0 := x+F.X+off; XT := x+F.X+F.W-F.right; y0 := y+F.Y+Y-L.asr;	(* absolute screen*)
			v := 0; X0 := x0+dX; Y0 := y0; X := dXX; bY := Y-L.h;
			WHILE pos # L.len DO
				Texts.Read(R1, ch); INC(pos);
				IF R1.lib # NIL THEN GetObj(R1.lib, ch, obj, dx, DX);
					IF X0 (*+ dx*) <= XT THEN v := R1.voff;
						IF X0 + dx > XT THEN ch := " " END;	(*not draw*)
						IF (ch > " ") & (obj IS Fonts.Char) & (bY >= F.bot) THEN
							IF v # 0 THEN Height(R1.lib(Fonts.Font), narrow IN F.defStyle.opts, a, d); Y0 := y0 + (a+d)*v DIV 100 ELSE Y0 := y0 END;	(*R1.voff#v*)
							WITH obj: Fonts.Char DO Display3.CopyPattern(F.msk,R1.col, obj.pat, X0+obj.x, Y0+obj.y, Display.paint) END
						ELSIF obj IS Display.Frame THEN G := obj(Display.Frame);
							IF v # 0 THEN dY := G.H * v DIV 100 ELSE dY := 0 END;
							Insert(L, X0-x0+off, dY, pos-1, G, dY);
							DrawFrame(F, G, x, y, X0-x0+off, Y-L.asr-dY)	(*rel*)
						END
					END;
					INC(X0, dx); INC(X, DX)
				END
			END
		END
		(*Display.ReplConst(F.col, X0, y0-L.dsr, XT-X0, L.h, 0)*)
	END DisplayLine;

	PROCEDURE DisplaySec (F: Frame; x, y, Y0: SIGNED16; org0: SIGNED32; L0, L1: Line);
		VAR L: Line; Y, y0, h0: SIGNED16;
	BEGIN L := L0; Y := Y0; Texts.OpenReader(R1, F.text, org0);
		WHILE L # L1 DO
			y0 := Y - L.h; h0 := L.h;
			IF y0 <= 0 THEN INC(h0, y0 - 1); y0 := 1 END;
			Erase(F, x, y, 0, y0, h0,0); DisplayLine(F, 0, 0, x, y, 0, Y, L);
			DEC(Y, L.h); L := L.next
		END
	END DisplaySec;

	PROCEDURE DisplaySec0 (F: Frame; x, y: SIGNED16; org0, off: SIGNED32; Y0: SIGNED16; oldL0, L0, L1: Line);
	VAR pos: SIGNED32; u, v, dx, xx: SIGNED16; dXX: SIGNED32;
	BEGIN
		IF (L0.asr = oldL0.asr) & (L0.dsr = oldL0.dsr) &
			((L0.style.opts * AdjMode = {Styles.left}) OR (L0.brk & oldL0.brk & (L0.style.opts * AdjMode = AdjMode))) THEN
			pos := Min(off, L0.len); Width(F, L0, org0, org0+pos, dx, dXX); Texts.OpenReader(R1, F.text, org0+pos);
			u := x+F.X+F.left; v := y+F.Y+Y0-L0.h;
			Erase(F,x, y, 0,  Y0-L0.h, L0.h, F.W - F.left-1-  L0.off);
			xx := L0.off+dx;
			Erase(F,x, y, xx, Y0-L0.h, L0.h,0);
			DisplayLine(F, pos, dXX, x, y, dx, Y0, L0); Append(L0, F.left+xx, oldL0.box);	(*right part*)
			DEC(Y0, L0.h); INC(org0, L0.len); L0 := L0.next
		END;
		DisplaySec(F, x, y, Y0, org0, L0, L1)
	END DisplaySec0;

	PROCEDURE ScrollBack(F: Frame; x, y: SIGNED16; oldL: Line; VAR L: Line; VAR Y: SIGNED16; VAR org: SIGNED32);
	VAR
		L0: Line;
		dY, Y1: SIGNED16;
	BEGIN d := 0; L.next := oldL; Y1 := Y; CollectLines(F, L, Y, org);
		IF L.next = oldL THEN L0 := L.next ELSE L0 := oldL END;	(* last line to draw *)
		dY := F.H - F.top - Y1; Move(F, x, y, Y + dY, Y1 - Y, -dY);
		DisplaySec(F, x, y, F.H - F.top, F.org, F.trailer.next, L0);
	END ScrollBack;

	(*---formatting---*)

	PROCEDURE Read;
	VAR
		obj: Objects.Object; G: Display.Frame;
		s: Styles.Style;
		v: SIGNED16;
	BEGIN
		Texts.Read(R, ch);
		IF ~R.eot THEN R.lib.GetObj(R.lib, ORD(ch), obj);
			IF R.lib IS Fonts.Font THEN
				IF R.lib # R.fnt THEN R.fnt := R.lib(Fonts.Font); Styles.MetricFnt(R.fnt, R.unit, R.mfnt) END;
				Height(R.fnt, R.narrow, a, d);
				(*IF R.voff # 0 THEN v := (a+d)*R.voff DIV 100; INC(a, v); DEC(d, v) END;*)
				IF ch >= " " THEN
					dx := obj(Fonts.Char).dx;
					R.mfnt.GetObj(R.mfnt, ORD(ch), obj); dX := R.unit*obj(Fonts.Char).dx
				ELSE dx := 0; dX := 0
				END
			ELSIF obj IS Display.Frame THEN G := obj(Display.Frame);
				dx := G.W; dX := LONG(dx)*Display.Unit; d := FrameDsr(G); a := G.H - d
			ELSIF obj IS Styles.Style THEN s := obj(Styles.Style); style := s;
				dX := Styles.pageW; dx := SHORT(s.paraW DIV Display.Unit);
				a := SHORT(s.gap DIV Display.Unit); d := 0;
				IF R.hide THEN a := Max(1, a) ELSE G := Styles.NewFrame(s); INC(a, G.H) END
			ELSE dx := 2; dX := 2*PrtUnit; Height(Fonts.Default, R.narrow, a, d)
			END;
			IF R.voff # 0 THEN v := (a+d)*R.voff DIV 100; INC(a, v); DEC(d, v) END
		ELSE dx := 0; dX := 0; a := 0; d := 0	(*a := Asr; d := Dsr*)
		END
	END Read;

	PROCEDURE InitFormatter(F: Frame; org: SIGNED32);
	BEGIN
		Texts.OpenReader(R, F.text, org); R.fnt := NIL; R.hide := F.hide; Read;
		R.w := 0; R.len := 0; R.W := 0; R.nSpc := 0; R.asr := a; R.dsr := d;
		style := StyleAt(F, org); R.narrow := narrow IN  F.defStyle.opts
	END InitFormatter;

	PROCEDURE FormatLine(VAR L: Line);
	VAR
		len, len0: SIGNED32;
		w, spc, w0, nspc, dsr0, asr0, asr, dsr, width, lsp: SIGNED16;
		W, Spc, W0, Width: SIGNED32;
		brk, tab: BOOLEAN;
		s: Styles.Style;
	BEGIN
		NEW(L); s := style;
		w := 0; len := 0; spc := 0; W := 0; Spc := 0;
		w0 := R.w; W0 := R.W; len0 := R.len; brk := FALSE; tab := FALSE; nspc := R.nSpc;
		asr := 0; dsr := 0; asr0 := R.asr; dsr0 := R.dsr;
		Width := style.paraW; width := SHORT(Width DIV Display.Unit);
		WHILE (w + spc + w0 + dx < width) & (W + Spc + W0 + dX < Width) & ~brk DO
			INC(len0);
			IF (R.lib # NIL) & (~(R.lib IS Fonts.Font) OR (ch > " ")) THEN
				INC(w0, dx); INC(W0, dX);
				IF a > asr0 THEN asr0 := a END; IF d > dsr0 THEN dsr0 := d END;
			ELSE
				INC(w, spc + w0); INC(W, Spc + W0); INC(len, len0); w0 := 0; W0 := 0; len0 := 0;
				IF asr0 > asr THEN asr := asr0 END; IF dsr0 > dsr THEN dsr := dsr0 END;
				dsr0 := d; asr0 := a;
				IF ch = " " THEN spc := dx; Spc := dX; INC(nspc); tab := FALSE
				ELSIF R.eot OR ((ch = CR) & ~(lineBrkOff IN s.opts)) THEN brk := TRUE; L.brk := TRUE; L.eot := R.eot;
					IF a > asr THEN asr := a END; IF d > dsr THEN dsr := d END; asr0 := 0; dsr0 := 0
				ELSIF ch = TAB THEN Styles.Tab(s, R.lib(Fonts.Font), w, W, spc, Spc); L.tabs := TRUE; tab := TRUE
				END
			END;
			IF ~R.eot THEN Read END
		END;
		IF s # style THEN INC(w, spc + w0); INC(W, Spc + W0); INC(len, len0); L.brk := TRUE;
			IF asr0 > asr THEN asr := asr0 END; IF dsr0 > dsr THEN dsr := dsr0 END;
			w0 := 0; W0 := 0; len0 := 0; asr0 := 0; dsr0 := 0	(*asr0 := Asr; dsr0 := Dsr*)
		END;
		IF len > 0 THEN
			L.w := w; L.W := W; L.len := len; L.asr := asr; L.dsr := dsr; L.nSpc := nspc;
			IF (nspc > 0) & ~tab THEN DEC(L.nSpc) END;
			R.w := w0; R.W := W0; R.len := len0; R.asr := asr0; R.dsr := dsr0
		ELSIF len0 > 0 THEN	(*one word*)
			L.w := w0; L.W := W0; L.len := len0; L.asr := asr0; L.dsr := dsr0; L.nSpc := 0;
			R.w := dx; R.W := dX; R.len := 1; R.asr := a; R.dsr := d
		ELSE	(*one char*)
			L.w := dx; L.W := dX; L.len := 1; L.asr := a; L.dsr := d;
			R.w := 0; R.W := 0; R.len := 0; R.asr := 0; R.dsr := 0	(*R.asr := Asr; R.dsr := Dsr*)
		END;
		IF (len = 0) & ~R.eot THEN Read END;
		L.style := s;
		lsp := SHORT(s.lsp DIV Display.Unit); dsr := SHORT(s.dsr DIV Display.Unit);	(*line spacing*)
		IF (Styles.grid IN s.opts) & (lsp > 0) THEN
			WHILE dsr < L.dsr DO INC(dsr, lsp) END;
			L.dsr := dsr;  L.h := Max(lsp, L.asr+dsr); INC(L.h, (-L.h) MOD lsp)
		ELSE L.dsr := Max(L.dsr, dsr);
			(* IF narrow  THEN L.dsr := Max(0,L.dsr-1) END; *)
			L.h := Max(lsp, L.asr+L.dsr);
		END;
		IF L.h = 0 THEN Height(Fonts.Default,R.narrow, asr,dsr); L.h := asr+dsr; L.dsr := dsr END;	(*min height*)
		L.asr := L.h-L.dsr
	END FormatLine;

	PROCEDURE NewLines(F: Frame; limit: SIGNED32; VAR L: Line; VAR Y: SIGNED16; VAR org: SIGNED32);
	VAR L1: Line;
	BEGIN InitFormatter(F, org); FormatLine(L1);
		WHILE ~L.eot & (Y >= F.bot + L1.h) & (org # limit) DO
			L.next := L1; L := L1; INC(org, L.len); DEC(Y, L.h); FormatLine(L1)
		END;
		L.next := L1	(*!*)
	END NewLines;

	PROCEDURE BottomLine(F: Frame; x, y, Y: SIGNED16; VAR L: Line; org: SIGNED32);
	VAR R: Texts.Finder; pos: SIGNED32; obj: Objects.Object;
	BEGIN
		IF org < F.text.len THEN Texts.OpenFinder(R, F.text, org); pos := R.pos; Texts.FindObj(R, obj);
			IF (pos - org < L.next.len) & (obj # NIL) & (obj IS Display.Frame) THEN
				L := L.next; Erase(F, x, y, 0, 1, Y-1,0);	(*clear to bottom*)
				Oberon.FadeCursor(Oberon.Mouse);
				Texts.OpenReader(R1, F.text, org); DisplayLine(F, 0, 0, x, y, 0, Y, L)
			ELSE
				Erase(F, x, y, 0, (*F.bot*) 1, Y-1,0)
			END
		ELSE
			Erase(F, x, y, 0, (*F.bot*) 1, Y -1,0)
		END
	END BottomLine;

	PROCEDURE AppendLines(F: Frame; x, y: SIGNED16; org: SIGNED32; L: Line; VAR Y: SIGNED16);
	VAR
		L0: Line; Y0: SIGNED16; org0: SIGNED32;
		botY: SIGNED16;
	BEGIN botY := F.bot; L0 := L; org0 := org; Y0 := Y;
		(* Erase(F, x, y, 0, botY, Y0 - botY,0); *) (**)NewLines(F, F.text.len+1, L, Y, org);
		DisplaySec(F, x, y, Y0, org0, L0.next, L.next); BottomLine(F, x, y, Y, L, org);
		L.next := F.trailer
	END AppendLines;

	PROCEDURE ShowText (F: Frame; x, y: SIGNED16; pos: SIGNED32; restore : BOOLEAN);
	VAR
		org, oldOrg, org0: SIGNED32;
		curY, Y0, dY, botY: SIGNED16;
		L, L1, oldL: Line;
	BEGIN	(* pos valid *)

		RemTick(F, x, y);
		botY := F.bot; curY := F.H - F.top;
		(*
		IF F.H < 25 THEN simple := TRUE;
			Texts.OpenReader(R,F.text,pos); i := 0;
			Texts.Read(R,s[i]); fnt := NIL;
			WHILE ~R.eot & (s[i] # 0DX) DO
				fnt := R.lib; col := R.col;
				INC(i); Texts.Read(R,s[i]);
				IF ~R.eot THEN
					simple := simple & (R.lib = fnt) & (col = R.col)
				END
			END;
			s[i] := 0X;
		ELSE simple := FALSE END;
		IF simple & (fnt # NIL) & (fnt IS Fonts.Font) THEN
			Background(F,x,y, F.X + x + 1, F.Y + y +1, F.W-2,F.H -2);
			Display3.String(F.msk, col, F.X + x + left, F.Y + y + bot-fnt(Fonts.Font).minY, fnt.name, s, Display3.textmode);
			RETURN
		END;
		*)
		IF ~restore & Display3.Visible(F.msk,x+F.X,y+F.Y,F.W,F.H) & (F.background = NIL) THEN
			IF pos < F.org THEN
				oldOrg := F.org; oldL := F.trailer.next; org := pos; F.org := pos; L := F.trailer;
				Y0 := curY; NewLines(F, oldOrg, L, curY, org);	(* curY org L *)
				IF org = oldOrg THEN ScrollBack(F, x, y, oldL, L, curY, org)
				ELSE	(* totally before *)
					DisplaySec(F, x, y, Y0, F.org, F.trailer.next, L.next)
				END;
				BottomLine(F, x, y, curY, L, org); L.next := F.trailer	(*Erase(F, x, y, botY, curY - botY)*)
			ELSE (* pos >=org *)
				L := F.trailer; org := F.org;
				WHILE (L.next # F.trailer) & (org # pos) DO L := L.next; INC(org, L.len); DEC(curY, L.h) END;	(* find pos *)
				L1 := L.next;	(* curY org L1 *)
				IF (org = pos) & (L.next # F.trailer) THEN org0 := org; Y0 := curY; CollectLines(F, L, curY, org);	(* curY org L *)
					IF (L.next # F.trailer) & (F.org = org0) THEN	(*cut rest*)
						IF (L.next.box # NIL) & (curY > botY) THEN BottomLine(F, x, y, curY, L, org); curY := botY END;
						L.next := F.trailer; Erase(F, x, y, 0, 1, curY-1,0)
					ELSE
						F.org := org0; F.trailer.next := L1; dY := F.H - F.top - Y0;
						IF dY # 0 THEN Move(F, x, y, curY, Y0 - curY, dY); INC(curY, dY) END;
						IF (L.next = F.trailer) & (L.box # NIL) THEN	(*redraw if more lines in frame*)
							Texts.OpenReader(R1, F.text, org-L.len); DisplayLine(F, 0, 0, x, y, 0, curY+L.h, L)
						END;
						AppendLines(F, x, y, org, L, curY)
					END
				ELSE	(* outside *)
					F.org := pos; curY := F.H - F.top; AppendLines(F, x, y, pos, F.trailer, curY)
				END
			END
		ELSE
			F.org := pos; curY := F.H - F.top; AppendLines(F, x, y, pos, F.trailer, curY)
		END;
		ShowTick(F,x,y);
	END ShowText;

	PROCEDURE Resize* (F: Frame; x, y, newY: SIGNED16);
	BEGIN (*F.mark = 0*)
		IF newY < F.Y THEN Bar(F, x, y, newY-F.Y, F.Y - newY) END;	(* extend *)
		F.H := F.H + F.Y - newY; F.Y := newY;
		ShowText(F,  x, y, F.org, FALSE)
	END Resize;

	(*---locators---*)

	PROCEDURE LocateOrg(F: Frame; org, pos: SIGNED32; VAR loc: Location);
		VAR L: Line; cury: SIGNED16;
	BEGIN
		cury := F.H - F.top; L := F.trailer.next;
		IF pos < org THEN pos := org END;
		WHILE (L.next # F.trailer) & (pos >= org + L.len) DO
			INC(org, L.len); DEC(cury, L.h); L := L.next
		END;
		loc.org := org; loc.pos := pos; loc.lin := L;
		loc.x := F.left; loc.y := cury - L.asr
	END LocateOrg;

	PROCEDURE LocateLine (F: Frame; y: SIGNED16; VAR loc: Location);
		VAR L: Line;  cury: SIGNED16;
	BEGIN loc.org := F.org; cury := F.H - F.top; L := F.trailer.next;
		WHILE (L.next # F.trailer) & (cury - L.h > y) & (cury - L.h - L.next.h >= F.bot)  DO
			INC(loc.org, L.len); DEC(cury, L.h); L := L.next
		END;
		loc.y := cury - L.asr; loc.lin := L
	END LocateLine;

	PROCEDURE LocateObj (F: Frame; x, y: SIGNED16; VAR loc: Location; VAR obj: Objects.Object);
		VAR R: Texts.Reader; pos, lim: SIGNED32; ox, dx: SIGNED16; ch: CHAR;
			spc, rest: SIGNED16; L: Line;
			X, DX: SIGNED32;
	BEGIN LocateLine(F, y, loc); L := loc.lin; Offsets(L, spc, rest);
		pos := loc.org; lim := loc.org+L.len- 1; ox := F.left + L.off; X := 0; obj := NIL;
		IF pos <= lim THEN
			Texts.OpenReader(R, F.text, pos); dx := 0; DX := 0; DEC(pos);
			REPEAT
				Texts.Read(R, ch);
				INC(ox, dx); INC(X, DX); INC(pos);
				IF R.lib # NIL THEN GetWidth(R.lib, ch, obj, dx, DX);
					IF R.lib IS Fonts.Font THEN
						IF ch = TAB THEN Styles.Tab(L.style, R.lib(Fonts.Font), ox - L.off - F.left, X, dx, DX)
						ELSIF ch = " " THEN IncPos(spc, rest, dx)
						END
					END
				ELSE obj := NIL
				END
			UNTIL (obj = NIL) OR (pos = lim) OR (ox+dx > x)
		END;
		IF pos = lim THEN
			IF ((ch = CR)  & ~(lineBrkOff IN F.defStyle.opts)) OR (obj = NIL) THEN dx := eolW
			ELSIF (ch = " ") OR (ch = TAB) THEN dx := SpcW
			END
		END;
		loc.pos := pos; loc.dx := dx; loc.x := ox
	END LocateObj;

	PROCEDURE LocatePos (F: Frame; pos: SIGNED32; VAR loc: Location);
		VAR dX: SIGNED32;  dx: SIGNED16;
	BEGIN LocateOrg(F, F.org, pos, loc);
		IF pos >= loc.org + loc.lin.len THEN pos := loc.org + loc.lin.len - 1 ELSIF pos < F.org THEN pos := F.org END;
		Width(F, loc.lin, loc.org, pos, dx, dX); loc.pos := pos; INC(loc.x, dx+loc.lin.off);
	END LocatePos;

	PROCEDURE LocateString (F: Frame; x, y: SIGNED16; VAR loc: Location);
	VAR
		pos, end, X, lim: SIGNED32;
		ch: CHAR;
		R: Texts.Reader;
		obj: Objects.Object;
	BEGIN LocateObj(F, x, y, loc, obj); lim := loc.org+loc.lin.len;
		end := loc.pos; Texts.OpenReader(R, F.text, end); Texts.Read(R, ch);
		IF R.lib # NIL THEN
			IF (R.lib IS Fonts.Font) & (ch <= " ") THEN	(*backwards*)
				REPEAT DEC(end); Texts.OpenReader(R, F.text, end); Texts.Read(R, ch)
				UNTIL (end < loc.org) OR ~(R.lib IS Fonts.Font) OR (ch > " ");
				INC(end); pos := end
			ELSIF R.lib # NIL THEN	(*forward*)
				REPEAT INC(end); Texts.Read(R, ch)
				UNTIL (R.lib = NIL) OR (end >= lim) OR (R.lib IS Fonts.Font) & (ch <= " ");
				pos := loc.pos
			END
		ELSE pos := end
		END;
		REPEAT DEC(pos); Texts.OpenReader(R, F.text, pos); Texts.Read(R, ch);
		UNTIL (pos < loc.org) OR (R.lib IS Fonts.Font) & (ch <= " ");
		INC(pos); LocatePos(F, pos, loc); Width(F, loc.lin, pos, end, loc.dx, X)
	END LocateString;

	PROCEDURE FindFrame(F: Frame; G: Display.Frame; VAR loc: Location);
	VAR Y: SIGNED16; L: Line; b: Box;
	BEGIN Y := F.H-F.top; L := F.trailer.next; loc.org := F.org; loc.pos := -1;
		WHILE L # F.trailer DO DEC(Y, L.h);
			IF L.box # NIL THEN b := L.box.next;
				WHILE b # L.box DO
					IF b.F = G THEN loc.x := b.X; loc.y := Y+L.dsr-b.dY; loc.dx := b.F.W;
						loc.pos := loc.org+b.off; loc.lin := L; RETURN
					END;
					b := b.next
				END
			END;
			INC(loc.org, L.len); L := L.next
		END
	END FindFrame;


	PROCEDURE TouchFrame(F: Frame; VAR M: Oberon.InputMsg): BOOLEAN;
	VAR X, Y: SIGNED16; b: Box; loc: Location; G: Display.Frame;
	BEGIN
		IF F.trailer.next # F.trailer THEN
			X := M.X-F.X-M.x; Y := M.Y-F.Y-M.y; LocateLine(F, Y, loc);
			IF Y < loc.y-loc.lin.dsr THEN DEC(loc.y, loc.lin.dsr+loc.lin.next.asr); loc.lin := loc.lin.next END;	(*bottom*)
			IF loc.lin.box # NIL THEN b := loc.lin.box;
				WHILE (b.next.X <= X) DO b := b.next END;
				G := b.F; DEC(loc.y, b.dY);
				IF (G # NIL) & (X < b.X+G.W) & (loc.y <= Y) & (Y < loc.y+G.H) THEN
					Oberon.FadeCursor(Oberon.Mouse);	(*clip !*)
					G.X := F.X; G.Y :=  F.Y+F.H;
					INC(M.x, F.X+b.X-G.X); INC(M.y, F.Y+loc.y-G.Y); M.dlink :=F;
					G.handle(G, M);
					RETURN (M.res >= 0)
				END
			END
		END;
		RETURN FALSE
	END TouchFrame;

	PROCEDURE Pos* (F: Frame; X, Y: SIGNED16): SIGNED32;	(* local coords *)
	VAR loc: Location; obj: Objects.Object;
	BEGIN LocateObj(F, X, Y, loc, obj); RETURN loc.pos
	END Pos;

	PROCEDURE ParaBeg(F : Frame; T: Texts.Text; pos: SIGNED32; VAR org: SIGNED32);
	VAR R: Texts.Reader; ch: CHAR; obj: Objects.Object;
	BEGIN org := pos;
		WHILE org > 0 DO
			Texts.OpenReader(R, T, org-1); Texts.Read(R, ch);
			R.lib.GetObj(R.lib, ORD(ch), obj);
			IF ((ch = CR) & ~(lineBrkOff IN F.defStyle.opts)) & (obj IS Fonts.Char) OR (obj IS Styles.Style) THEN RETURN END;
			DEC(org)
		END
	END ParaBeg;

	PROCEDURE Validate (F: Frame; VAR pos: SIGNED32);	(* find org of line *)
		VAR org: SIGNED32; L: Line; loc: Location;
	BEGIN
		IF F.trailer.next # F.trailer THEN
			IF pos >= F.org THEN LocateOrg(F, F.org, pos, loc);	(* find start of line within line list *)
				IF pos < loc.org + loc.lin.len THEN pos := loc.org; RETURN END
			END;
		END;
		IF pos > F.text.len THEN pos := F.text.len END;
		IF pos > 0 THEN ParaBeg(F, F.text, pos, org);
			InitFormatter(F, org); FormatLine(L);
			WHILE org + L.len <= pos DO INC(org, L.len); FormatLine(L) END;
			pos := org
		ELSE pos := 0
		END
	END Validate;

	PROCEDURE SetAttributes(F: Frame; pos: SIGNED32);
		VAR R: Texts.Reader; x: CHAR;
	BEGIN
		IF (* (F.text.len > 0) & (pos = F.text.len) *)  pos > 0 THEN DEC(pos) END;
		Texts.OpenReader(R, F.text, pos); Texts.Read(R, x);
		IF (R.lib = NIL) OR ~(R.lib IS Fonts.Font) THEN
			Texts.SetFont(KW, Oberon.CurFnt); Texts.SetColor(KW, Oberon.CurCol); Texts.SetOffset(KW, Oberon.CurOff)
		ELSE
			Texts.SetFont(KW, R.lib); Texts.SetColor(KW, R.col); Texts.SetOffset(KW, R.voff)
		END
	END SetAttributes;

	(*---caret & select---*)

	PROCEDURE SetCaret* (F: Frame; pos: SIGNED32);
	BEGIN
		IF ~F.car OR (F.carLoc.pos # pos) THEN
			IF F.car THEN Marks(F, car); F.car := FALSE END;
			IF showCaret THEN
				IF (pos < F.org) OR (pos >= Lim(F)) THEN show(F, pos) END
			END;
			LocatePos(F, pos, F.carLoc);
			Marks(F, car); F.car := TRUE;	(*old version*)
			SetAttributes(F, F.carLoc.pos)
		END
	END SetCaret;

	PROCEDURE RemoveCaret* (F: Frame);
	BEGIN IF F.car THEN
		Marks(F, car) END; F.car := FALSE
	END RemoveCaret;

	PROCEDURE SetSelection* (F: Frame; beg, end: SIGNED32);
	BEGIN
		IF F.sel THEN Marks(F, sel) END;
		IF (beg < F.org) OR (beg >= Lim(F)) THEN show(F, beg) END;
		LocatePos(F, beg, F.selBeg); LocatePos(F, end, F.selEnd);
		IF F.selBeg.pos < F.selEnd.pos THEN
			Marks(F, sel); F.time := Oberon.Time(); F.sel := TRUE
		END
	END SetSelection;

	PROCEDURE RemoveSelection* (F: Frame);
	BEGIN IF F.sel THEN Marks(F, sel); F.sel := FALSE END
	END RemoveSelection;

	PROCEDURE RemoveMarks (F: Frame);
	BEGIN RemoveCaret(F); RemoveSelection(F)
	END RemoveMarks;

	PROCEDURE FlipMarks (F: Frame; x, y : SIGNED16);
	BEGIN
		IF F.car  THEN FlipCaret(F,  x, y) END;
		IF F.sel  THEN FlipSelection(F, x, y, F.selBeg, F.selEnd) END;
	END FlipMarks;

	PROCEDURE Neutralize* (F: Frame);
	BEGIN RemoveMarks(F)
	END Neutralize;

	(*---update---*)

	PROCEDURE UpdateVisible(F: Frame; x, y: SIGNED16; beg, end, corr: SIGNED32);
	VAR
		oldL, oldL0, L, L0: Line;
		oldorg, org, org0: SIGNED32;
		oldY, dY, Y, Y0, Y1, botY: SIGNED16;
		visible : BOOLEAN;
	BEGIN
		org := F.org; Y := F.H - F.top; L := F.trailer; botY := F.bot;
		WHILE (L.next # F.trailer) & (org + L.next.len <= beg) DO	(* find line where beg lies in *)
			L := L.next; INC(org, L.len); DEC(Y, L.h)
		END;
		IF L.next # F.trailer THEN
			(* [org, Y, L.next] = line where update starts *)
			oldorg := org; oldY := Y; oldL := L.next; oldL0 := oldL;
			INC(oldorg, oldL.len); DEC(oldY, oldL.h); oldL := oldL.next;	(* set org to next line *)
			IF (corr <= 0) OR (corr < end-beg) THEN
				WHILE (oldorg < end) & (oldL # F.trailer) DO
					INC(oldorg, oldL.len); DEC(oldY, oldL.h); oldL := oldL.next	(* find last line of update *)
				END
			END;
			oldorg := oldorg + corr;
			InitFormatter(F, org); FormatLine(L.next);
			visible := Display3.Visible(F.msk,x+F.X,y+F.Y,F.W,F.H) & (F.background = NIL);
			IF Y >= botY + L.next.h THEN
				org0 := org; Y0 := Y; L0 := L.next;	(* L0 = first line *)
				LOOP
					L := L.next; INC(org, L.len); DEC(Y, L.h);
					IF L.eot THEN EXIT END;
					WHILE (oldL # F.trailer) & (oldorg < org) DO
						INC(oldorg, oldL.len); DEC(oldY, oldL.h); oldL := oldL.next
					END;
					IF (oldorg = org) & (style = oldL.style) & (visible OR (Y = oldY)) THEN EXIT END;	(* old and new structure are synchronized again *)
					FormatLine(L.next);
					IF Y < botY + L.next.h THEN EXIT END	(* bot of frame *)
				END;
				IF  L.eot OR ((oldorg # org) OR (style # oldL.style)) & (Y < botY + L.next.h) THEN (* redisplay to bottom of frame *)
					DisplaySec0(F, x, y, org0, beg - org0, Y0, oldL0, L0, L.next);
					BottomLine(F, x, y, Y, L, org);
					(*IF org # oldorg THEN BottomLine(F, x, y, Y, L, org) ELSE Erase(F, x, y, botY, Y - botY,0) END;*)
					L.next := F.trailer
					(* Erase(F, x, y, botY, Y - botY)	cleanup *)
				ELSE (* (oldorg = org) & (style = oldL.style) *)
					dY := Y - oldY; L.next := oldL;	(* connect line lists *)
					IF dY # 0 THEN Y1 := Y;	(* move sync part *)
						INC(F.bot, Max(dY, 0)); CollectLines(F, L, Y, org); F.bot := botY;	(*cut off bottom line*)
						Move(F, x, y, Y - dY, Y1 - Y, dY)
					END;
					DisplaySec0(F, x, y, org0, beg - org0, Y0, oldL0, L0, oldL);
					IF dY # 0 THEN AppendLines(F, x, y, org, L, Y) END;
				END
			ELSE (*L.next := F.trailer; Erase(F, x, y, botY, Y - botY)*)
				BottomLine(F, x, y, Y, L, org); L.next := F.trailer
			END
		END
	END UpdateVisible;

	PROCEDURE UpdateSection (F: Frame; x, y: SIGNED16; beg, end, corr: SIGNED32);
	VAR
		L, L0: Line;
		org: SIGNED32;
	BEGIN L := F.trailer.next;
		IF (F.org > 0) & (beg < F.org + L.len) THEN
			IF beg < F.org THEN INC(F.org, corr); corr := 0; beg := F.org END;
			org := F.org -1; Validate(F, org); InitFormatter(F, org); FormatLine(L0);	(*outside line*)
			IF (org + L0.len = F.org) & (L0.style = L.style) THEN
				IF end > F.org THEN UpdateVisible(F, x, y, beg, end, corr) END
			ELSE
				IF F.org-org < L0.len DIV 3 THEN INC(corr, F.org-org); F.org := org
				ELSE DEC(corr, org + L0.len-F.org); F.org := org + L0.len
				END;
				IF end < F.org THEN end := F.org+corr END; UpdateVisible(F, x, y, F.org, end, corr)
			END
		ELSE
			org := F.org; L := F.trailer;
			WHILE (L.next # F.trailer) & (org + L.next.len <= beg) DO L := L.next; INC(org, L.len) END;
			IF org > 0 THEN InitFormatter(F, org - L.len); FormatLine(L0);
				IF L0.len # L.len THEN beg := org - L.len END	(*start at prev line*)
			END;
			IF (beg < org) OR (L.next # F.trailer) THEN UpdateVisible(F, x, y, beg, end, corr) END;
		(*
			IF L.next # F.trailer THEN
				IF org > 0 THEN
					InitFormatter(F, org - L.len); FormatLine(L0);
					IF L0.len # L.len THEN beg := org - L.len END	(*start at prev line*)
				END;
				UpdateVisible(F, x, y, beg, end, corr)
			END
	*)
		END
	END UpdateSection;

	(*
	PROCEDURE DisplaySecBrk (F: Frame; x, y, Y0: SIGNED16; org0: SIGNED32; L0, L1: Line);
		VAR L: Line; Y: SIGNED16;
	BEGIN L := L0; Y := Y0; Texts.OpenReader(R1, F.text, org0);
		WHILE L # L1 DO
			IF ~L.brk THEN Erase(F, x, y, 0, Y - L.h, L.h,0); DisplayLine(F, 0, 0, x, y, 0, Y, L)
			ELSE Texts.OpenReader(R1, F.text, Texts.Pos(R1)+L.len)	(*skip*)
			END;
			DEC(Y, L.h); L := L.next
		END
	END DisplaySecBrk;
	*)

	PROCEDURE UpdateStyle(F: Frame; VAR M: Styles.UpdateMsg);
	VAR
		L0, L1: Line;
		org0, org1, pos, len: SIGNED32;
		Y0, Y1, Y: SIGNED16;
		style: Styles.Style;
		L: Line; org: SIGNED32;
		tabs: BOOLEAN;
	BEGIN
		(*	InitStyle(F); *)
		RemoveMarks(F); style := M.obj;
		L0 := F.trailer.next; org0 := F.org; Y0 := F.H - F.top;	(* top line *)
		WHILE L0 # F.trailer DO
			IF L0.style = style THEN	(* [org0 Y0 L0] *)
				org1 := org0; Y1 := Y0; L1 := L0;
				REPEAT INC(org1, L1.len); DEC(Y1, L1.h); L1 := L1.next UNTIL (L1 = F.trailer) OR (L1.style # style);
				(* [org1 Y1 L1] (first outside) *)
				IF (M.id = Styles.leftmarg) & (M.dX # 0) THEN DisplaySec(F, M.x, M.y, Y0, org0, L0, L1)
				ELSIF M.id = Styles.fmode THEN
					IF (M.dX = Styles.right) & (Styles.left IN style.opts) THEN DisplaySec(* Brk*) (F, M.x, M.y, Y0, org0, L0, L1)
					ELSE DisplaySec(F, M.x, M.y, Y0, org0, L0, L1)
					END;
				ELSIF M.id = Styles.tabs THEN
					WHILE L0 # L1 DO
						IF L0.tabs THEN	(*format upto next line break*)
							L := L0; org := org0; Y := Y0; len := 0; tabs := FALSE;
							WHILE ~L.brk & (L.next # L1) DO
								IF L.tabs THEN len := org+L.len-org0 END;	(*text portion to be formatted anyway*)
								INC(org, L.len); DEC(Y, L.h); L := L.next
							END;
							IF L.tabs THEN INC(len, L.len) END;
							INC(org, L.len); L := L.next; DEC(Y, L.h);	(*line after brk or L1*)
							UpdateSection(F, M.x, M.y, org0, org0+len, 0); L0 := L; org0 := org; Y0 := Y (*L0 := L1*)
						ELSE INC(org0, L0.len); DEC(Y0, L0.h); L0 := L0.next
						END
					END
				ELSIF M.id < 0 THEN	(* break -> no formatting *)
				ELSE
					pos := org0; Validate(F, pos); UpdateSection(F, M.x, M.y, pos, org1, 0)	(* replace *)
				END;
				L0 := L1; org0 := org1; Y0 := Y1
			ELSE
				INC(org0, L0.len); DEC(Y0, L0.h); L0 := L0.next
			END
		END;
		(*CloseStyle;*)
	END UpdateStyle;

	(*---user interface---*)

	PROCEDURE TrackCaret* (F: Frame; x, y, X, Y: SIGNED16; VAR keysum: SET);
		VAR keys: SET;
	BEGIN
		IF F.trailer.next # F.trailer THEN keysum := {};
			REPEAT
				TrackMouse(X, Y, keys, keysum);
				SetCaret(F, Pos(F, X - F.X - x, Y - F.Y - y))
			UNTIL keys = {};
		END
	END TrackCaret;

	PROCEDURE KeyPressed() : BOOLEAN;
	BEGIN
		IF waitTime = 0 THEN waitTime := Oberon.Time(); RETURN TRUE END;
		IF  Oberon.Time() - waitTime < 50 THEN RETURN FALSE
		ELSE
			IF Oberon.Time() - repeatTime < 10 THEN RETURN FALSE
			ELSE  repeatTime := Oberon.Time(); RETURN TRUE END;
		END;
	END KeyPressed;

	PROCEDURE ResetRepeat;
	BEGIN
		waitTime := 0;
	END ResetRepeat;

	PROCEDURE Scroll*(F : Frame; x, y : SIGNED16; back : BOOLEAN);
		VAR pos : SIGNED32; L : Line;
	BEGIN
		Neutralize(F);
		pos := F.org-1;
		IF back THEN
			Validate(F,pos);
			IF pos # F.org THEN
				ShowText(F,  x, y, pos, FALSE)
			END;
		ELSE
			IF F.trailer.next # F.trailer THEN
				pos := F.org;
				L := F.trailer.next; WHILE (pos < F.text.len) & (L # F.trailer) DO INC(pos,L.len); L := L.next END;
				IF pos < F.text.len THEN
					L := F.trailer.next;
					ShowText(F, x, y, F.org + L.len,FALSE)
				END;
			END;
		END
	END Scroll;

	(*
	PROCEDURE TrackFullLine*(F: Frame; x, y, X, Y: SIGNED16; sel :BOOLEAN; VAR keysum: SET);
		VAR old, new: Location; keys: SET;  oh,ow, nw, nh, oy, ny, yo, ye   : SIGNED16;
			 org : SIGNED32; obj : Objects.Object;

		PROCEDURE Inv(Y,H : SIGNED16); BEGIN
			IF Y # MIN(SIGNED16) THEN InvertRect(F, x, y, F.left + new.lin.off, Y, nw, H) END; END Inv;

	BEGIN
		org := -1;
		IF F.trailer.next # F.trailer THEN
			LocateLine(F, Y - F.Y - y, old); DEC(old.y, old.lin.dsr);
			oh :=  old.lin.h; ow := F.W - F.left - old.lin.off - F.border ;oy := old.y;
			nw := ow; nh := oh;  ny := oy; yo := oy; ye := yo; new := old;
			Inv(old.y,  oh);
			keysum := {};
			REPEAT
				TrackMouse(X, Y, keys, keysum);
				LocateLine(F, Y - F.Y - y, new); DEC(new.y, new.lin.dsr);
				IF ~sel & ((Y > y + F.Y + F.H) OR (Y < y + F.Y)) THEN
					IF ~ sel THEN Inv(oy,oh) END; oy := MIN(SIGNED16); ny := MIN(SIGNED16);
					IF KeyPressed() THEN
						Scroll(F,x,y,Y > y + F.Y + F.H);
					END;
				ELSIF new.org # old.org  THEN
					ResetRepeat;
					IF ~ sel THEN Inv(oy,oh) END;
					nh :=  new.lin.h; nw := F.W - F.left - new.lin.off - F.border ; ny := new.y;
					IF ~ sel  THEN Inv(ny,nh);
					ELSIF (ye > ny) & (ny < yo)  THEN  ye := ny; Inv(ny,oy - ny);
					ELSIF (ye < ny) & (ny > yo) THEN  ye := ny; Inv(oy + oh, ny  +   nh - oy - oh);
					ELSIF (oy > ny)   THEN  Inv(ny+nh,oy +oh - ny- nh);
					ELSIF (oy < ny)   THEN  Inv(oy,ny - oy);
					END;
					oh := nh; ow := nw; oy := ny;
					old := new
				END
			UNTIL keys = {};
			IF ~sel THEN Inv(ny,nh) END;
			org := new.org
		END;
		IF sel THEN
			IF yo < ny THEN oh := yo; yo := ny; ny := oh END;
			LocateObj(F, F.left, yo, old, obj);
			LocateObj(F, F.left+F.W,ny, new, obj);
			F.selBeg := old; F.selEnd := new
		END;
	END TrackFullLine;
	*)

	PROCEDURE TrackSelection* (F: Frame; x, y, X, Y: SIGNED16; VAR keysum: SET);
		VAR loc: Location; obj: Objects.Object; keys: SET; Y0 : SIGNED16;
	BEGIN
		IF F.trailer.next # F.trailer THEN
			IF F.sel THEN RemoveSelection(F); F.sel := TRUE; (* FlipSelection(F, x, y, F.selBeg, F.selEnd) *) END;
			(*IF  fullLine THEN TrackFullLine(F,x, y, X, Y, TRUE, keysum);
			ELSE*)
				Y0 := Y;
				LocateObj(F, X - F.X - x, Y - F.Y - y, loc, obj);
				IF F.sel & (loc.pos = F.selBeg.pos) & (F.selEnd.pos = F.selBeg.pos + 1) THEN
					LocateObj(F, F.left, Y - F.Y - y, F.selBeg, obj)
				ELSE F.selBeg := loc
				END;
				INC(loc.pos); INC(loc.x, loc.dx); F.selEnd := loc;
				FlipSelection(F, x, y, F.selBeg, F.selEnd);
				keysum := {};
				REPEAT
					TrackMouse(X, Y, keys, keysum);
					LocateObj(F, X - F.X - x, Y - F.Y - y, loc, obj);
					IF loc.pos < F.selBeg.pos THEN loc := F.selBeg END;
					INC(loc.pos); INC(loc.x, loc.dx);
					IF loc.pos < F.selEnd.pos THEN FlipSelection(F, x, y, loc, F.selEnd)
					ELSIF loc.pos > F.selEnd.pos THEN FlipSelection(F, x, y, F.selEnd, loc)
					END;
					F.selEnd := loc
				UNTIL keys = {};
			(* END; *)
			F.time := Oberon.Time(); F.sel := TRUE
		END
	END TrackSelection;


	PROCEDURE TrackLine* (F: Frame; x, y, X, Y: SIGNED16; VAR org: SIGNED32; VAR keysum: SET);
		VAR old, new: Location; keys: SET;

		PROCEDURE H(l : Location) : SIGNED16;
		BEGIN IF block  THEN RETURN l.lin.h ELSE RETURN 2 END;END H;

	BEGIN org := -1;
		IF F.trailer.next # F.trailer THEN
			LocateLine(F, Y - F.Y - y, old); DEC(old.y, old.lin.dsr);
			InvertRect(F, x, y, F.left + old.lin.off, old.y, old.lin.w0, H(old));
			keysum := {};
			REPEAT
				TrackMouse(X, Y, keys, keysum);
				IF  (autoScroll IN F.defStyle.opts) & ((Y > y + F.Y + F.H) OR (Y < y + F.Y)) THEN
					IF old.y # MIN(SIGNED16) THEN InvertRect(F, x, y, F.left + old.lin.off, old.y, old.lin.w0, H(old));
						old.y := MIN(SIGNED16); new.y := MIN(SIGNED16)
					END;
					IF KeyPressed() THEN Scroll(F,x,y,Y > y + F.Y + F.H) END;
				ELSE
					ResetRepeat;
					LocateLine(F, Y - F.Y - y, new); DEC(new.y, new.lin.dsr);
					IF new.org # old.org THEN
						IF old.y # MIN(SIGNED16) THEN InvertRect(F, x, y, F.left + old.lin.off, old.y, old.lin.w0, H(old)) END;
						InvertRect(F, x, y, F.left + new.lin.off, new.y, new.lin.w0, H(new));
						old := new
					END
				END
			UNTIL keys = {};
			IF new.y # MIN(SIGNED16) THEN InvertRect(F, x, y, F.left + new.lin.off, new.y, new.lin.w0, H(new)) END;
			org := new.org
		END;
	END TrackLine;

	PROCEDURE TrackWord* (F: Frame; x, y, X, Y: SIGNED16; VAR pos: SIGNED32; VAR keysum: SET);
		VAR old, new: Location; keys: SET;

		PROCEDURE H(l : Location) : SIGNED16;
		BEGIN IF underlineOff IN F.defStyle.opts THEN RETURN l.lin.h ELSE RETURN 2 END;END H;

	BEGIN pos := -1;
		IF (fullLine IN F.defStyle.opts) THEN
			block := TRUE; TrackLine(F,x, y, X, Y, pos, keysum); block := FALSE;
			Input.Mouse(keys,X,Y);
			LocateString(F, 0,  Y - F.Y - y, new); pos := new.pos;
			IF (Y < F.Y+ y) OR (Y > F.Y + y + F.H) THEN keysum := {0,1,2} END;
		ELSIF F.trailer.next # F.trailer THEN
			LocateString(F, X - F.X - x, Y - F.Y - y, old); DEC(old.y, old.lin.dsr);
			InvertRect(F, x, y, old.x, old.y, old.dx, H(old));
			keysum := {};
			REPEAT
				TrackMouse(X, Y, keys, keysum);
				IF  (autoScroll IN F.defStyle.opts) & ((Y > y + F.Y + F.H) OR (Y < y + F.Y)) THEN
					IF old.y # MIN(SIGNED16) THEN InvertRect(F, x, y, old.x, old.y, old.dx, H(old));
						old.y := MIN(SIGNED16); new.y := MIN(SIGNED16)
					END;
					IF KeyPressed() THEN Scroll(F,x,y,Y > y + F.Y + F.H) END;
				ELSE
					ResetRepeat;
					LocateString(F, X - F.X - x, Y - F.Y - y, new); DEC(new.y, new.lin.dsr);
					IF new.pos # old.pos THEN
						IF old.y # MIN(SIGNED16) THEN InvertRect(F, x, y, old.x, old.y, old.dx, H(old)) END;
						InvertRect(F, x, y, new.x, new.y, new.dx, H(old)); old := new
					END
				END
			UNTIL keys = {};
			IF new.y # MIN(SIGNED16) THEN InvertRect(F, x, y, new.x, new.y, new.dx, H(new)); ELSE keysum := {ML,MM,MR} END;
			pos := new.pos
		END
	END TrackWord;

	PROCEDURE Show* (F: Frame; pos: SIGNED32);
	VAR M: DisplayMsg;
	BEGIN
		RemoveMarks(F);
		IF F.trailer.next # F.trailer THEN Validate(F, pos);
			(* M.device := Display.screen; M.id := Display.full; *)
			M.F := F; M.pos := pos; Display.Broadcast(M);	(* ShowText(F, pos); *)
		END
	END Show;

	PROCEDURE Call* (F: Frame; pos: SIGNED32; new: BOOLEAN; dlink : Objects.Object);
		VAR S: Texts.Scanner; res, i: SIGNED16; par: Oberon.ParList; R : Texts.Reader; dl : Objects.Object;
	BEGIN
		F.pointPos := pos;
		Texts.OpenReader(R, F.text, pos); i := 0;
		IF F.point = NIL THEN NEW(F.point) END; Texts.Read(R,F.point[i]);
		IF (R.lib IS Fonts.Font) & (F.point[i] = 22X) THEN Texts.Read(R,F.point[i]) END;
		WHILE (R.lib IS Fonts.Font) & (F.point[i] # 22X) & (F.point[i] > " ") & (i < 62) DO INC(i); Texts.Read(R,F.point[i]); END; F.point[i] := 0X;
		(*
		i := 0; WHILE (F.cmd[i] # 0X) & (F.cmd[i] > " ") DO cmd[i] := F.cmd[i]; INC(i) END; cmd[i] := 0X;
		*)
		IF F.cmd = "#Point" THEN
			Gadgets.executorObj := F; dl := F.dlink; F.dlink := dlink;
			Texts.OpenScanner(S, F.text, pos); Texts.Scan(S);
			IF S.class = Texts.Name THEN NEW(par);
				par.frame := F; par.text := F.text; par.pos := pos + S.len;
				Oberon.Call(S.s, par, new, res);
				IF res > 1 THEN
					Texts.WriteString(W, Modules.resMsg);
					Texts.WriteLn(W); Texts.Append(Oberon.Log, W.buf)
				END
			END;
			F.dlink := dl;
		ELSE
			Gadgets.ExecuteAttr(F, "Cmd", dlink, NIL, NIL);
		END;
	END Call;

	(*---message handling---*)

	PROCEDURE Write* (F: Frame; ch: CHAR; lib: Objects.Library; col, voff: SIGNED8);
	VAR
		pos, i: SIGNED32;
		s: ARRAY 64 OF CHAR;

		PROCEDURE char(ch: CHAR): BOOLEAN;
		BEGIN RETURN (20X <= ch) & (ch < 86X) OR (ch = CR) OR (ch = TAB) OR (ch = 0ABX)	(*sz*)
		END char;

		PROCEDURE ReadAll(ch: CHAR; VAR s: ARRAY OF CHAR);
		VAR i: SIGNED16;
		BEGIN s[0] := ch; i := 1;
			WHILE Input.Available() > 0 DO Input.Read(s[i]); INC(i) END;
			s[i] := 0X
		END ReadAll;

	BEGIN (*F.car*)
		pos := F.carLoc.pos;
		IF ch = 7FX THEN
			IF pos > F.org THEN
				IF F.edit # NIL THEN
					 F.edit(F,delete,pos -1, pos,NIL); RETURN
				ELSE
					Texts.Delete(F.text, pos-1, pos); DEC(pos)
				END;
			END;
			ReadAll(ch, s)	(*flush*)
		ELSIF char(ch) THEN
			ReadAll(ch, s);
			(*
			IF FALSE THEN KW.lib := lib; KW.col := col; KW.voff := voff END;
			*)
			i := 0; WHILE char(s[i]) DO Texts.Write(KW, s[i]); INC(i) END;
			IF i > 0 THEN
				IF F.edit # NIL THEN
					F.edit(F,insert,pos,0,Txt(KW.buf)); RETURN;
				ELSE
					Texts.Insert(F.text, pos, KW.buf); INC(pos, i)
				END
			END
		ELSIF ch = LeftArrow THEN DEC(pos)
		ELSIF ch = RightArrow THEN INC(pos)
		END;
		IF  (F.trailer.next # F.trailer) & (scrollup IN F.defStyle.opts)  THEN
			IF (pos < F.text.len) & (pos >= Lim(F)) THEN
				WHILE (pos >= Lim(F)) DO Show(F, F.org+F.trailer.next.len) END
			ELSIF pos < F.org THEN Show(F, pos)
			END;
		END;
		SetCaret(F, pos);
	END Write;

	PROCEDURE Open* (F: Frame; H: Objects.Handler; T: Texts.Text; org: SIGNED32;
				col, left, right, top, bot: SIGNED16);
		VAR L: Line;
	BEGIN NEW(L);
		L.len := 0; L.w := 0; L.eot := FALSE; L.next := L;
		F.handle := H; F.text := T; F.org := org; F.trailer := L;
		F.left := left; F.right := right; F.top := top; F.bot := bot;
		F.col := col; F.mark := 0; F.car := FALSE; F.sel := FALSE;
		F.W := 100; F.H := 100;  F.profile := down; F.col := Display3.textbackC;
		F.cmd := "#Point"; F.hook := hook; (* Display.hook; *) F.msk := NIL	(*Effects.screen*);
		F.border := 2;
		Styles.New;
		F.defStyle := Objects.NewObj(Styles.Style); (*  INCL(F.defStyle.opts, scrollup);*)  INCL(F.defStyle.opts, scrollback);
		F.defStyle.paraW := LONG(Display.Width)*Display.Unit;
	END Open;

	PROCEDURE CopyOver* (F: Frame; text: Texts.Text; beg, end: SIGNED32);
		VAR buf: Texts.Buffer;
	BEGIN
		IF F.car THEN
			SaveAndCopy(F, text, beg, end, XW); buf := XW.buf;
			IF F.edit # NIL THEN
				F.edit(F,insert,F.carLoc.pos,0, Txt(buf));
			ELSE
				Texts.Insert(F.text, F.carLoc.pos, buf);
				SetCaret(F, F.carLoc.pos + (end - beg))
			END;
		END
	END CopyOver;

	PROCEDURE GetSelection* (F: Frame; VAR M: Oberon.SelectMsg);
	BEGIN
		IF F.sel THEN
			IF F.time > M.time THEN M.sel := F; M.time := F.time;
				M.text := F.text; M.beg := F.selBeg.pos; M.end := Min(F.selEnd.pos, F.text.len)
			ELSIF (F.text = M.text) & (F.selBeg.pos < M.beg) THEN	(* extend select over frame boundaries *)
				M.beg := F.selBeg.pos
			END
		END
	END GetSelection;

	PROCEDURE GetCaret* (F: Frame; VAR M: Oberon.CaretMsg);
	BEGIN
		IF F.car THEN M.car := F; M.text := F.text; M.pos := F.carLoc.pos; M.res := 0 END
	END GetCaret;


	PROCEDURE Recall (F: Frame);
		VAR buf: Texts.Buffer; pos: SIGNED32;
	BEGIN	(*F.car*)
		NEW(buf); Texts.OpenBuf(buf); Texts.Recall(buf); pos := F.carLoc.pos + buf.len;
		IF F.edit # NIL THEN
			F.edit(F,insert,F.carLoc.pos, 0, Txt(buf));
		ELSE
			Texts.Insert(F.text, F.carLoc.pos, buf); SetCaret(F, pos)
		END
	END Recall;

(*--back scroll--*)
	PROCEDURE FormatBack(F: Frame; pos: SIGNED32; H: SIGNED16; VAR org: SIGNED32; VAR L: Line; VAR h: SIGNED16);
	VAR
		org0, org1: SIGNED32;
		L0, L1: Line;
	BEGIN
		org := pos; h := 0;
		REPEAT
			ParaBeg(F, F.text, org-1, org0); InitFormatter(F, org0); FormatLine(L0); L1 := L0; org1 := org0; INC(h, L1.h);
			WHILE org1 + L1.len < org DO
				INC(org1, L1.len); FormatLine(L1.next); L1 := L1.next; INC(h, L1.h)
			END;
			L1.next := L; L := L0; org := org0
		UNTIL (h >= H) OR (org = 0);
		WHILE h > H DO DEC(h, L.h); INC(org, L.len); L := L.next END	(*remove overhead*)
	END FormatBack;

	PROCEDURE ScrollBackTo(F: Frame; x, y: SIGNED16; pos: SIGNED32);
	VAR
		L,  L1: Line;
		org, org0: SIGNED32;
		h0, Y: SIGNED16;
	BEGIN
		org := F.org; Y := F.H - F.top; L := F.trailer.next;
		WHILE org # pos DO INC(org, L.len); DEC(Y, L.h); L := L.next END;
		IF(*  (L.next # F.trailer) & *)  (F.org > 0) THEN
			L1 := F.trailer.next;	(*keep old first line*)
			FormatBack(F, F.org, Y - F.bot - L.h, org0, F.trailer.next, h0);
			RemoveMarks(F);  RemTick(F, x, y);
			IF Display3.Visible(F.msk,x+F.X,y+F.Y,F.W,F.H) & (F.background = NIL) THEN
				L := F.trailer.next; WHILE L.next # L1 DO L := L.next END;	(*find last line of new section*)
				F.org := org0;
				Y := F.H - F.top - h0;
				ScrollBack(F, x, y, L1, L, Y, org); (*Erase(F, x, y, F.bot, Y - F.bot);*)
				BottomLine(F, x, y, Y, L, org); L.next := F.trailer;
				ShowTick(F,x,y);
			ELSE
				ShowText(F,  x, y, org0, TRUE)
			END;
			ShowTick(F,x,y);
		END
	END ScrollBackTo;

	PROCEDURE ScrollToEnd(F: Frame; x, y: SIGNED16);
	VAR L: Line; org: SIGNED32; h: SIGNED16;
	BEGIN L := F.trailer;
		IF F.text.len # 0 THEN
			FormatBack(F, F.text.len, F.H-F.top-F.bot, org, L, h);
			RemoveMarks(F); ShowText(F,  x, y, org, FALSE)
		END
	END ScrollToEnd;

	PROCEDURE Update* (F: Frame; VAR M: Texts.UpdateMsg);
		VAR end: SIGNED32;
	BEGIN (*F.text = M.text*)
		RemoveMarks(F);
		end := M.beg + M.len; IF M.end > end THEN end := M.end END;
		UpdateSection(F, M.x, M.y, M.beg, end, M.beg + M.len - M.end);
		IF (M.text = Oberon.Log) OR ((M.beg = M.end) & (M.beg > F.org)  & (M.beg >= F.text.len - M.len - 10)
			& (scrollup IN F.defStyle.opts) & (Pos(F,1000,0) < F.text.len-20)) THEN
			WHILE (Pos(F,1000,0) < F.text.len-8)  &(F.trailer.next # F.trailer)  DO
				ShowText(F,M.x,M.y, F.org + F.trailer.next.len, TRUE);
			END;
			ScrollToEnd(F,M.x,M.y)
		END;
	END Update;

	PROCEDURE Edit* (F: Frame; x, y, X, Y: SIGNED16; Keys: SET; dlink : Objects.Object; VAR res : SIGNED16);
		VAR
			M: Oberon.ConsumeMsg;
			R: Texts.Reader;
			text: Texts.Text;
			time, pos, beg, end: SIGNED32;
			keysum: SET;
			ch: CHAR;
			m : MarkMsg;
			i : SIGNED16;
			C : Oberon.CaretMsg;
			car : BOOLEAN;

	BEGIN	(*M.X & M.Y not inside any object*)
		DrawCursor(X, Y);
		IF F.trailer.next = F.trailer THEN RETURN END;	(* as nothing to edit exists *)
		IF (X < x + F.X + Min(F.left, barW)) & (F.left > barW) THEN	(*bar*)
			IF MR IN Keys THEN
				keysum := Keys; TrackLine(F, x, y, X, Y, pos, keysum);
				IF ~(scrollback IN F.defStyle.opts) THEN Show(F,0)
				ELSE
					ScrollBackTo(F, x, y, pos)
				END;
				res := 0;
			ELSIF MM IN Keys THEN keysum := Keys;
				REPEAT TrackMouse(X, Y, Keys, keysum) UNTIL Keys = {};
				IF ~(ML IN keysum) THEN
					IF (MR IN keysum) OR (y+F.Y + F.H < Y) THEN pos := 0
					ELSE pos := (y+F.Y + F.H - Y) * (F.text.len) DIV F.H
					END;
					Show(F, pos)
				ELSIF ~(MR IN keysum) THEN ScrollToEnd(F, x, y)
				END;
				res := 0;
			ELSIF ML IN Keys THEN TrackLine(F, x, y, X, Y, pos, keysum);
				IF ~(MR IN keysum) & ~(MM IN keysum) THEN
					IF (pos >= 0) & (pos # F.org) THEN Show(F, pos)  END
				ELSE
					Show(F, 0)
				END;
				res := 0;
			END;
		ELSE	(*text*)
			IF MR IN Keys THEN TrackSelection(F, x, y, X, Y, keysum);
				IF F.sel THEN
					IF keysum = {MR, ML} THEN	(*delete text*)
						car := F.car;
						F.deleting := TRUE;
						Oberon.Defocus; Oberon.GetSelection(text, beg, end, time);	(*!*)
						IF F.edit # NIL THEN
							F.edit(F,delete,beg, end,NIL);
						ELSE
							Texts.Delete(text, beg, end);
							IF ~car THEN Caret(F,beg,Display.set) END;
							SetCaret(F, beg)
						END;
						F.deleting := FALSE;
					ELSIF keysum = {MR, MM} THEN	(*copy to focus*)
						Oberon.GetSelection(M.text, M.beg, M.end, time); M.F := NIL; Display.Broadcast(M)
					END;
					IF F.sel THEN
						m.id := sel; m.absX := F.absX; m.absY := F.absY; m.F := F; Display.Broadcast(m);
						Texts.OpenReader(R, F.text, F.selBeg.pos);
						IF F.select = NIL THEN NEW(F.select) END; i := 0;
						WHILE (Texts.Pos(R) < F.selEnd.pos) & (i < 62) DO Texts.Read(R,F.select[i]); INC(i) END;
						F.select[i] := 0X;
					END;
				END;
				res := 0;
			ELSIF MM IN Keys  THEN
				IF F.cmd # "" THEN
					TrackWord(F, x, y, X, Y, pos, keysum);
					IF (pos >= 0) & ~(MR IN keysum) THEN Call(F, pos, ML IN keysum, dlink) END
				ELSE
					RETURN
				END;
				res := 0;
			ELSIF ML IN Keys THEN
				 car := F.car;
				C.pos := Pos(F, X - F.X - x, Y - F.Y - y);
				(* IF ~F.car THEN Caret(F,C.pos,Display.set) END; *)
				C.id := Display.set; C.car := F; C.F := NIL; C.text := F.text;
				Display.Broadcast(C);
				TrackCaret(F, x, y, X, Y, keysum);
				IF F.car THEN
					IF keysum = {ML, MM} THEN	(*copy from select*)
						Oberon.GetSelection(text, beg, end, time);
						IF time >= 0 THEN CopyOver(F, text, beg, end) END
					ELSIF keysum = {ML, MR} THEN	(*copy font*)
						Oberon.GetSelection(text, beg, end, time);
						IF (time >= 0) & (F.carLoc.pos < F.text.len) THEN
							Texts.OpenReader(R, F.text, F.carLoc.pos); Texts.Read(R, ch);
							Texts.ChangeLooks(text, beg, end, {0, 1, 2}, R.lib, R.col, R.voff)
						END
					END;
					IF ~ car THEN Caret(F,F.carLoc.pos, Display.set) END;
				END;
				res := 0;
			END;
		END;
	END Edit;

	PROCEDURE Integrate(F: Frame; pos: SIGNED32; obj: Objects.Object; new: BOOLEAN; VAR res : SIGNED16);
		VAR N: Display.ControlMsg; len: SIGNED32;
	BEGIN	(*clear XW.buf*)
		IF ~((obj IS Frame) & ((obj(Frame).text = F.text) OR (Recursive(F,obj)))) THEN
			WHILE obj # NIL DO
				IF ~new THEN	(*unbind*)
				(*	IF (obj.lib = NIL) OR (obj.lib = F.text.obs) OR (obj.lib.name = "") THEN	(*free own or public*)*)
						N.id := Display.remove; N.F := obj(Display.Frame); Display.Broadcast(N)
				(*	END *)
				END;
				IF obj IS Display.Frame THEN Deselect(F, obj(Display.Frame)) END;
				IF (obj IS Display.Frame) OR (obj IS Styles.Style) THEN
				(*	lib := Objs(F.text); lib.GenRef(lib, ref);
					IF ref > 255 THEN F.text.obs := NIL; lib := Objs(F.text); lib.GenRef(lib, ref) END;
					lib.PutObj(lib, ref, obj); Texts.SetFont(XW, lib); Texts.Write(XW, CHR(ref))*)
					Texts.WriteObj(XW, obj)
				END;
				obj := obj.slink
			END;
			len := XW.buf.len;
			IF F.edit # NIL THEN
				F.edit(F,insert,pos,0,Txt(XW.buf));
			ELSE
				Texts.Insert(F.text, pos, XW.buf);
				IF new THEN SetCaret(F, pos+len) END;
			END;
			res := 0;
		END
	END Integrate;

	PROCEDURE Control(F: Frame; VAR M: Display.ControlMsg);
	VAR R: Texts.Finder; obj: Objects.Object; pos: SIGNED32;
	BEGIN
		IF M.id = Display.remove THEN
			Texts.OpenFinder(R, F.text, 0); pos := R.pos; Texts.FindObj(R, obj);
			WHILE ~R.eot DO
				IF obj = M.F THEN
					IF F.edit # NIL THEN F.edit(F,delete,pos,pos+1,NIL) ELSE  Texts.Delete(F.text, pos, pos+1); END;
					M.res := 0; RETURN
				END;
				pos := R.pos; Texts.FindObj(R, obj)
			END;
			Broadcast(F, M)
		ELSE Broadcast(F, M)
		END
	END Control;

	PROCEDURE DisplayArea (F: Frame; x, y, X, Y, W, H: SIGNED16);
		VAR Y1: SIGNED16; loc0, loc1: Location;
	BEGIN
		Bar(F, x, y, 0, F.H); LocateLine(F, Y+H, loc0); LocateLine(F, Y, loc1);
		IF loc1.lin.next # F.trailer THEN loc1.lin := loc1.lin.next END;
		DisplaySec(F, x, y, loc0.y+loc0.lin.asr, loc0.org, loc0.lin, loc1.lin.next);
		loc0.lin := F.trailer.next; Y1 := F.H-F.top;
		WHILE loc0.lin # F.trailer DO DEC(Y1, loc0.lin.h); loc0.lin := loc0.lin.next END;
		IF Y1 > Y THEN Erase(F, x, y, 0, 1, Y1-1, 0) END;
		ShowTick(F, x, y)
	END DisplayArea;

	PROCEDURE Enum(X,Y,W,H : SIGNED16);
	BEGIN
		visible := TRUE;
	END Enum;

	PROCEDURE Restore(F: Frame; x, y: SIGNED16; VAR M: Display.FrameMsg);
		VAR Y: SIGNED16;
	BEGIN
		F.dlink := M.dlink;
		IF M IS DisplayMsg THEN
			FlipMarks(F,x,y); ShowText(F, x, y, M(DisplayMsg).pos,TRUE);
		ELSIF M IS Display.DisplayMsg THEN
			WITH M: Display.DisplayMsg DO
				IF (M.id = Display.full) OR (F.trailer.next = F.trailer) THEN
					Y := F.Y; INC(F.Y, F.H); F.H := 0; F.trailer.next := F.trailer; Resize(F, x, y, Y)
				ELSIF M.id = Display.area THEN
					visible := FALSE;
					Display3.EnumRect(F.mask, F.mask.X,F.mask.Y,F.mask.W,F.mask.H,Enum);
					IF visible THEN
						DisplayArea(F, x, y, M.u, F.H+M.v-1, M.w, M.h)
					END;
				END
			END
		ELSE
			(*FlipMarks(F,x,y); ShowText(F, x, y, F.org,TRUE)*) DisplayArea(F, x, y, 0, 0, 0, F.H)
		END;
		FlipMarks(F,x,y);
		IF Gadgets.selected IN F.state THEN
			Display3.FillPattern(F.msk, Display3.white, Display.grey1, F.X + x, F.Y + y,F.X + x, F.Y + y,F.W,F.H, Display.paint)
		END;
	END Restore;

(*
	PROCEDURE Restore(F: Frame; x, y: SIGNED16;  VAR  M: Display.FrameMsg);
		VAR Y: SIGNED16;
	BEGIN
		IF M IS DisplayMsg THEN
			FlipMarks(F,x,y); ShowText(F, x, y, M(DisplayMsg).pos,TRUE);
		ELSIF M IS Display.DisplayMsg THEN Y := F.Y; INC(F.Y, F.H); F.H := 0; F.trailer.next := F.trailer;
			Resize(F, x, y, Y);
		ELSE
			FlipMarks(F,x,y); ShowText(F, x, y, F.org,TRUE);
		END;
		FlipMarks(F,x,y);
		IF Gadgets.selected IN F.state THEN
			Display3.FillPattern(F.msk, Display3.white, Display.grey1, F.X + x, F.Y + y,F.X + x, F.Y + y,F.W,F.H, Display.paint)
		END
	END Restore;
*)

	PROCEDURE ModifyDsc(F: Frame; x, y: SIGNED16; M: Display.ModifyMsg);
	VAR R: Texts.Finder; obj: Objects.Object; G, msk: Display.Frame;
		loc: Location;
		pos, org, lim, lim0: SIGNED32;
		dw, mode: SIGNED16;
		dlink : Objects.Object;
		found : BOOLEAN;
	BEGIN
		dlink := F.dlink; F.dlink := M.dlink; found := FALSE; F.absX := F.X + x; F.absY := F.Y + y;
		org := F.org; lim := Lim(F); lim0 := 0; mode := M.mode; msk :=F; loc.pos := 0;
		Texts.OpenFinder(R, F.text, 0); pos := R.pos; Texts.FindObj(R, obj);
		WHILE ~R.eot & (pos < F.text.len) & (M.res < 0) DO
			IF obj IS Display.Frame THEN G := obj(Display.Frame);
				IF M.F = G THEN	(*direct dsc*)
					found := TRUE;
					F.absX := F.X + M.x; F.absY := F.Y + M.y;
					IF (M.dW = 0) & (M.dH = 0) & (M.dX # 0) & (M.dY # 0) THEN M.res := 0	(*move: ignore*)
					ELSIF M.id = Display.extend THEN dw := M.W-Styles.scnW;
						IF dw > 0 THEN DEC(M.W, dw); DEC(M.dW, dw) END
					END;
					IF M.res < 0 THEN F.mask := NIL;
						Gadgets.MakeMask(F,M.x+F.X,M.y +F.Y, M.dlink, F.msk);
						IF (F.stamp # M.stamp) THEN
							F.stamp := M.stamp;
							IF pos < org THEN M.mode := Display.state; M.dlink := msk; G.handle(G, M);	(*before*)
								IF R.pos >= org THEN RemoveMarks(F); UpdateSection(F, x, y, pos, pos+1, 0); org := F.org; lim := Lim(F) END
							ELSE
								IF loc.pos >= 0 THEN FindFrame(F, G, loc) END;
								IF (*pos < lim*) loc.pos >= 0 THEN
									M.x := x+F.X+loc.x-G.X; M.y := y+F.Y+loc.y-G.Y;	(*visible*)
									IF M.F = G THEN M.mode := Display.state; M.dlink := msk; G.handle(G, M);
										RemoveMarks(F); UpdateSection(F, x, y, pos, pos+1, 0); lim := Lim(F)
									ELSE M.mode := mode; M.dlink := msk; G.handle(G, M)
									END
								ELSE M.mode := Display.state; M.dlink := msk; G.handle(G, M);
									IF lim0 < lim THEN lim0 := lim; RemoveMarks(F); UpdateSection(F, x, y, lim, lim+1, 0); lim := Lim(F) END
								END
							END
						ELSE
							 Restore(F,x,y,M);
						END
					END
				END;
			END;
			pos := R.pos; Texts.FindObj(R, obj)
		END;
		IF ~found THEN M.mode := mode; Broadcast(F,M); END;
		F.dlink := dlink;
	END ModifyDsc;

	PROCEDURE InvalidateMasks(F: Frame);
		VAR L : Line; box : Box;
	BEGIN
		L := F.trailer.next;
		WHILE L # F.trailer DO
			IF L.box # NIL THEN
				box := L.box.next;
				WHILE box # L.box DO
					IF box.F IS Gadgets.Frame THEN box.F(Gadgets.Frame).mask := NIL END;
					box := box.next;
				END;
			END;
			L := L.next;
		END;
	END InvalidateMasks;

	PROCEDURE Modify(F: Frame; VAR M: Display.ModifyMsg);
		VAR x, y: SIGNED16;  T : Texts.UpdateMsg;
	BEGIN x := M.x; y := M.y;
		InvalidateMasks(F);
		IF F.car THEN Caret(F,F.carLoc.pos,Display.remove) END;
		IF  (M.id = Display.move) OR (M.id = Display.extend) OR (F.absY # F.Y) OR
			~Display3.Visible(F.msk,M.x+F.X,M.y+F.Y,F.W,F.H) OR (F.background # NIL)  THEN
			RemoveMarks(F);
			Gadgets.framehandle(F,M);
			T.text := F.text; T.beg := F.org; T.end := F.text.len; T.len := T.end - T.beg;
			T.F := NIL; T.dlink := M.dlink; Objects.Stamp(T); T.x := x; T.y := y; F.handle(F,T);
		ELSE
			RemTick(F,x,y);
			RemoveMarks(F);
			(*
			IF M.id = Display.extend THEN
				IF M.dY > 0 THEN
					Bar(F, x, y, F.H, M.dY); Move(F, x, y, 0, F.H, M.dY); INC(F.Y, M.dY); INC(F.absY, M.dY)
				END;
				Resize(F, x, y, M.Y)	(* Extend *)
			ELS*)
			IF M.id = Display.reduce THEN
				Resize(F, x, y, M.Y + M.dY);	(* Reduce *)
				IF M.dY > 0 THEN
					RemTick(F,M.x,M.y); Move(F, x, y, 0, F.H, -M.dY); DEC(F.Y, M.dY); DEC(F.absY, M.dY);
					IF F.H > 0 THEN ShowTick(F,x,y); END
				END
			END;
			M.res := 0
		END;
	END Modify;

	PROCEDURE FrameAttr(F: Frame; VAR M: Objects.AttrMsg);
		VAR s : SIGNED16;

	BEGIN
		s := -1;
		IF M.name = "Adjust" THEN s := adaptStyle
		ELSIF M.name = "Scroll" THEN s := scrollback
		ELSIF M.name = "Block" THEN s := Styles.right
		ELSIF M.name = "Drop" THEN s := drop
		ELSIF M.name = "ScrollUp" THEN s := scrollup
		ELSIF M.name = "AutoScroll" THEN s := autoScroll
		ELSIF M.name = "NoLine"  THEN s := underlineOff
		ELSIF M.name = "FullLine" THEN s := fullLine
		ELSIF M.name = "NoLineBrk"  THEN s := lineBrkOff;
		ELSIF M.name = "Narrow" THEN s := narrow;
		ELSIF M.name = "Hide" THEN s := hide;
		END;
		IF M.id = Objects.get THEN M.class := Objects.String; M.res := 0;
			IF M.name = "Gen" THEN COPY("ScriptGadgets.NewFrame", M.s);
			ELSIF M.name = "Cmd" THEN COPY(F.cmd, M.s);
			ELSIF M.name = "Point" THEN IF F.point # NIL THEN COPY(F.point^, M.s)  ELSE M.s := "" END;
			ELSIF M.name = "Sel"THEN IF F.select # NIL THEN COPY(F.select^, M.s) ELSE M.s := "" END;
			ELSIF M.name = "Color" THEN M.class := Objects.Int; M.i := F.col;
			ELSIF M.name = "Left" THEN M.class := Objects.Int; M.i := F.left;
			ELSIF M.name = "Profile" THEN M.class := Objects.Int; M.i := F.profile;
			ELSIF M.name = "Org" THEN M.class := Objects.Int; M.i := F.org;
			ELSIF M.name = "PointPos" THEN M.class := Objects.Int; M.i := F.pointPos;
			ELSE
				IF s >=0 THEN M.class := Objects.Bool; M.b := s IN F.defStyle.opts
				ELSE Gadgets.framehandle(F, M) END
			END;
		ELSIF M.id = Objects.set THEN
			IF M.name = "Color" THEN F.col := SHORT(M.i);
			ELSIF M.name = "Left" THEN F.left := SHORT(M.i);
			ELSIF M.name = "Profile" THEN F.profile := SHORT(M.i);
			ELSIF M.name = "Cmd" THEN COPY(M.s,F.cmd);
			ELSIF M.name = "Point" THEN IF F.point = NIL THEN NEW(F.point) END; COPY(M.s,F.point^);
			ELSIF M.name = "Sel" THEN  IF F.select = NIL THEN NEW(F.select) END; COPY(M.s,F.select^);
			ELSIF M.name = "Org" THEN  Validate(F, M.i); F.org := M.i; Show(F, F.org)
			ELSE
				IF s >=  0 THEN
					IF M.b THEN INCL(F.defStyle.opts,s) ELSE EXCL (F.defStyle.opts,s);
						IF M.name = "Adjust" THEN F.defStyle.paraW :=  Styles.defStyle.paraW  END;
					END
				ELSE
					Gadgets.framehandle(F, M);
				END;
			END;
			F.hide := hide IN F.defStyle.opts;
			M.res := 0;
		ELSE (* IF M.id = Objects.enum THEN *)
			M.Enum("Color"); M.Enum("Left"); M.Enum("Org"); M.Enum("Adjust");  M.Enum("Block");
			(* M.Enum("Scroll"); *) M.Enum("ScrollUp"); M.Enum("Drop");
			M.Enum("NoLine"); M.Enum("FullLine");
			M.Enum("AutoScroll");  M.Enum("NoLineBrk"); (* M.Enum("Narrow"); *)
			M.Enum("Profile"); M.Enum("Cmd"); M.Enum("Point"); M.Enum("PointPos"); M.Enum("Sel");

			Gadgets.framehandle(F, M)
		END
	END FrameAttr;

	PROCEDURE CopyFrame* (M :Objects.CopyMsg;F: Frame;  F1: Frame);
		VAR B : Texts.Buffer;
	BEGIN
		Open(F1, F.handle, F.text, F.org, F.col, F.left, F.right, F.top, F.bot);
		F.defStyle.handle(F.defStyle,M); F1.defStyle := M.obj(Styles.Style);
		Gadgets.CopyFrame(M,F,F1);
		F1.cmd := F.cmd; F1.hook := F.hook;
		F1.background := F.background; F1.edit := F.edit; F1.state0 := F.state0;

		F1.handle := F.handle; F1.profile := F.profile;
		F1.hide := F.hide; F.mask := NIL; F.msk := NIL;
		(*  F1.text := F1.obj(Texts.Text); ???? *)
		F1.hidetext := F.hidetext;
		IF Objects.deep = M.id THEN
			NEW(F1.text); Texts.Open(F1.text,"");
			IF F.text.len # 0 THEN
				NEW(B); Texts.OpenBuf(B);
				Texts.Save(F.text,0,F.text.len,B);
				Texts.Append(F1.text,B);
			END
		END
	END CopyFrame;

	PROCEDURE Link(F: Frame; VAR M: Objects.LinkMsg);
		VAR N: DisplayMsg;
	BEGIN
		IF (M.id = Objects.get) & ((M.name = "Text") OR (M.name = "Model") OR (F.obj = NIL)) THEN M.obj := F.text
		ELSIF (M.id = Objects.set)  & (M.obj IS Texts.Text) THEN
			F.text := M.obj(Texts.Text); RemoveMarks(F);
			N.pos := 0; N.F := F; N.res := -1; Display.Broadcast(N)
		ELSE
			Gadgets.framehandle(F,M);
		END
	END Link;

	PROCEDURE CopyLineDesc(trailer : Line; VAR save :  Line);
		VAR  line,new,prev : Line; box, newB, prevB : Box;

	BEGIN
		(* save line desc *)
		NEW(save);  save^ := trailer^; new := save;
		line := trailer.next; prev := save;
		WHILE line # trailer DO
			NEW(new); new^ := line^;
			prev.next := new; prev := new;
			(* save boxes *)
			IF new.box # NIL THEN
				NEW(new.box); new.box^ := line.box^;
				box := new.box.next; prevB := new.box; newB := new.box;
				WHILE box # line.box DO
					NEW(newB); newB^ := box^;
					prevB.next := newB; prevB := newB;
					box := box.next
				END;
				newB.next := new.box;
			END;
			line := line.next;
		END;
		new.next  := save;
	END CopyLineDesc;

	PROCEDURE P(d: SIGNED16): SIGNED16;
	BEGIN RETURN SHORT(LONG(d)*Display.Unit DIV PrtUnit)
	END P;

	PROCEDURE PrintLine(F : Frame; L: Line; msk: Display3.Mask; X, Y, XT: SIGNED16);	(*X, Y: baseline*)
	VAR
		buf: ARRAY 256 OF CHAR;
		pos, ddX: SIGNED32;
		obj: Objects.Object; G: Display.Frame;
		lib: Objects.Library;
		k, x, dx, dY, dX, X0, voff, offX, col, sx, rx, dW: SIGNED16;
		r, g, b: SIGNED16;
		ch: CHAR;
		s: Styles.Style;

		PROCEDURE Out;
		BEGIN IF k > 0 THEN buf[k] := 0X; Printer3.String(msk, col, X0, Y + dY, lib(Fonts.Font), buf, Display.paint) END; k := 0
		END Out;

		PROCEDURE PrintFrame(G: Display.Frame; X, Y: SIGNED16);
			VAR M: Display.DisplayMsg;
		BEGIN
			M.res := -1; M.device := Display.printer; M.id := Display.full; M.dlink := F;
			M.x := X; M.y := Y - P(FrameDsr(G)); Objects.Stamp(M);
			(* G.dlink := NIL; *)  M.F := G; G.handle(G, M)	(*G.dlink : HACK*)
		END PrintFrame;

	BEGIN
		s := L.style; sx := 0; rx := 0;
		INC(X, SHORT(s.left DIV PrtUnit)); dW := SHORT((s.paraW - L.W) DIV PrtUnit);
		IF Styles.left IN s.opts THEN
			IF (Styles.right IN s.opts) & (L.nSpc > 0) THEN sx := dW DIV L.nSpc; rx := dW MOD L.nSpc END
		ELSE
			IF Styles.right IN s.opts THEN INC(X, dW) ELSE INC(X, dW DIV 2) END
		END;
		lib := NIL; col := -1; k := 0; pos := 0; x := 0; X0 := X; offX := X; voff := 0;
		WHILE pos # L.len DO
			Texts.Read(R1, ch); INC(pos);
			IF X < XT THEN
				IF R1.lib # NIL THEN
					IF (lib # R1.lib) OR (voff # R1.voff) OR (col # R1.col) THEN Out; X0 := X;
						col := R1.col; Display.GetColor(col, r, g, b); Printer.UseColor(r, g, b);
						lib := R1.lib; voff := R1.voff; dY := 0;
						IF lib IS Fonts.Font THEN dY := P(lib(Fonts.Font).height)*voff DIV 100 END
					END;
					GetWidth(lib, ch, obj, dx, ddX); dX := SHORT(ddX DIV PrtUnit);
					IF obj IS Fonts.Char THEN
						IF (ch = " ") & ((sx # 0) OR (rx # 0)) THEN Out;
							INC(dX, sx); IF rx > 0 THEN INC(dX); DEC(rx) END;
							INC(X, dX); X0 := X
						ELSIF ch = TAB THEN Out; Styles.Tab(s, lib(Fonts.Font), x, LONG(X-offX)*PrtUnit, dx, ddX);
							INC(X, SHORT(ddX DIV PrtUnit)); X0 := X
						ELSIF ch >= " " THEN buf[k] := ch; INC(k); INC(X, dX)
						(*ELSIF (ch =HYPH) & (pos = len) THEN buf[k] := "_"; INC(k)	hyph*)
						END;
					ELSE	(*object*)
						IF obj IS Display.Frame THEN G := obj(Display.Frame); dx := G.W; dX := P(dx);
							PrintFrame(G, X, Y+dY+P((voff*G.H) DIV 100)); col := -1;
							INC(X, dX); X0 := X
						END
					END;
					INC(x, dx)
				END
			END
		END;
		Out
	END PrintLine;

	PROCEDURE PrintView(F: Frame; x, y: SIGNED16);
		VAR L: Line; y0, xt: SIGNED16; b, t: SIGNED16;
	BEGIN
(*
		Printer3.ReplConst(F.msk,F.col, x, y, P(F.W), P(F.H), Display.replace);
*)
		IF F.profile # flat THEN
			IF F.profile = down THEN b := Display3.bottomC; t := Display3.topC
			ELSE b := Display3.topC; t := Display3.bottomC
			END;
			Printer3.Rect3D(F.msk, b, t, x, y, P(F.W), P(F.H),P(1), Display.replace)
		END;
		y0 := y + P(F.H-F.top); xt := x+P(F.W-F.right); INC(x, P(F.left));
		Texts.OpenReader(R1, F.text, F.org); L := F.trailer.next;
		WHILE L # F.trailer DO
			PrintLine(F , L, F.msk, x, y0-P(L.asr), xt); DEC(y0, P(L.h)); L := L.next
		END
	END PrintView;

	PROCEDURE Handle* (F: Objects.Object; VAR M: Objects.ObjMsg);
		VAR F0: Frame; bcast: BOOLEAN;
			x, y, i : SIGNED16; dlink: Objects.Object; absX,absY : SIGNED16;
			mskD : Display3.MaskDesc; msk  : Display3.Mask;
			r1  : Texts.Reader; f : Texts.Finder; obj : Objects.Object;

	BEGIN
		r1 := R1;
		WITH F: Frame DO
			(* InitStyle(F); *)
			IF (M IS Display.ModifyMsg) & (M(Display.ModifyMsg).F # F)  THEN
				WITH M: Display.ModifyMsg DO
					ModifyDsc(F, M.x, M.y, M);
				END;
			ELSIF M IS Display.ControlMsg THEN
				WITH M: Display.ControlMsg DO
					IF M.F = F THEN
						Gadgets.framehandle(F, M)
					ELSE
						Control(F, M)
					END
				END;
			ELSIF M IS Display.FrameMsg THEN
				WITH M: Display.FrameMsg DO
					x := M.x; y := M.y; dlink := F.dlink; absX := F.absX; absY := F.absY;
					F.absX := F.X + M.x; F.absY := F.Y + M.y; F.dlink := M.dlink; msk := F.msk;
					IF (M.F = F) OR (M.F = NIL) THEN
						bcast := (M.F = NIL);	(* bcast = "msg has to be broadcasted to every descender" *)
						IF M IS Oberon.InputMsg THEN
							WITH M: Oberon.InputMsg DO
								IF M.id = Oberon.track THEN
									IF Gadgets.InActiveArea(F, M) OR (F.absY = F.Y) OR (M.keys = {ML}) THEN
										Gadgets.MakeMask(F, x+F.X, y+F.Y, M.dlink, F.msk); msk := F.msk;
										IF (M.keys = {})  OR  ~TouchFrame(F, M) THEN Edit(F, x, y, M.X, M.Y, M.keys, M.dlink, M.res);
											IF M.res < 0 THEN Gadgets.framehandle(F, M)  END
										END
									ELSE
										Gadgets.framehandle(F, M)
									END
								ELSIF M.id = Oberon.consume THEN
									IF F.car THEN Write(F, M.ch, M.fnt, M.col, M.voff); M.res := 0 (*ELSE bcast := TRUE*) END
								END
							END
						ELSIF M IS RecursiveMsg THEN
							IF M(RecursiveMsg).text = F.text THEN M(RecursiveMsg).rec := TRUE END;
							Texts.OpenFinder(f,F.text,0);
							LOOP
								Texts.FindObj(f,obj);
								IF f.eot THEN EXIT END;
								obj.handle(obj,M);
							END
						ELSIF M IS Display.ModifyMsg THEN
							WITH M: Display.ModifyMsg DO
								Modify(F, M)
							END
						ELSIF M IS Oberon.ControlMsg THEN
							WITH M: Oberon.ControlMsg DO
								IF M.id = Oberon.defocus THEN
									IF ~F.deleting & F.car THEN Caret(F,F.carLoc.pos,Display.remove) END;
									RemoveCaret(F)
								ELSIF M.id = Oberon.neutralize THEN
									IF F.car THEN Caret(F,F.carLoc.pos,Display.remove)  END;
									F.select := NIL; RemoveMarks(F)
								END;
								(*bcast := TRUE*)
							END
						ELSIF M IS DisplayMsg THEN
							WITH M: DisplayMsg DO
								Gadgets.MakeMask(F, x+F.X, y+F.Y, M.dlink, F.msk); msk := F.msk;
								Restore(F, x, y, M);
							END
						ELSIF M IS Display.DisplayMsg THEN
							WITH M: Display.DisplayMsg DO
								IF M.device = Display.screen THEN
									IF (M.F = F) OR (M.F = NIL) THEN (* F.mask := NIL; *)
										Gadgets.MakeMask(F, x+F.X, y+F.Y, M.dlink, F.msk);
										IF M.id = Display.area THEN
											Display3.AdjustMask(F.msk, x + F.X + M.u, y + F.Y + F.H - 1 + M.v, M.w, M.h)
										END;
										msk := F.msk;
										Restore(F, x, y, M);
									ELSE Broadcast(F, M)
									END
								ELSIF M.device = Display.printer THEN
									IF  M.id = Display.full THEN
										F.dlink := M.dlink; F.absX := M.x; F.absY := M.y;
										Gadgets.MakePrinterMask(F, M.x, M.y, M.dlink, F.msk);
										PrintView(F, M.x, M.y); F.msk := NIL
									END
								ELSE Broadcast(F, M)
								END
							END
						ELSIF M IS Display.ConsumeMsg THEN
							WITH M: Display.ConsumeMsg DO
								IF F.car & (M.id = Display.integrate) THEN
									Integrate(F, F.carLoc.pos, M.obj, TRUE,M.res);
								ELSIF (M.F = F) & (M.id = Display.drop) THEN
									IF drop IN F.defStyle.opts THEN
										Integrate(F, Pos(F, M.u, M.v), M.obj, FALSE,M.res);
									END
								ELSE Broadcast(F, M)
								END
							END
						ELSIF M IS Display.LocateMsg THEN
							WITH M: Display.LocateMsg DO
								IF Effects.Inside(M.X,M.Y, F.absX,F.absY, F.W,F.H) THEN
									M.loc := NIL;
									Broadcast(F, M);
									IF M.loc = NIL THEN
										M.u := M.X - F.X - x; M.v := M.Y - (F.Y + y +F.H-1); M.loc := F; M.res := 0;
									END
								END
							END
						ELSIF M IS Texts.UpdateMsg THEN
							WITH M: Texts.UpdateMsg DO
								IF F.text = M.text THEN
									IF F.stamp = M.stamp THEN  F.mask := NIL  END;
									Gadgets.MakeMask(F, x+F.X, y+F.Y, M.dlink, F.msk); msk := F.msk;
									IF F.stamp # M.stamp THEN F.stamp := M.stamp;
										CopyLineDesc(F.trailer,F.save);
										F.sorg := F.org;
								    	Update(F, M) (* cont *) (*ELSE bcast := TRUE*);
								    ELSE
								    	F.org := F.sorg;
								    	CopyLineDesc(F.save,F.trailer);
								    	Update(F, M) ;
								    END
								 END
							END
						ELSIF M IS Oberon.SelectMsg THEN
							WITH M: Oberon.SelectMsg DO
								IF M.id = Oberon.get THEN GetSelection(F, M)	(*; bcast := TRUE*)
								ELSIF (M.sel = F) & (M.text = F.text) THEN
									IF M.id = Oberon.set THEN SetSelection(F, M.beg, M.end)
									ELSE (* IF M.id = Oberon.reset THEN *) RemoveSelection(F)
									END
								END
							END
						ELSIF M IS Oberon.CaretMsg THEN
							WITH M: Oberon.CaretMsg DO
								IF M.id = Oberon.get THEN GetCaret(F, M)	(*; bcast := TRUE*)
								ELSIF (M.car = F)  THEN
									IF M.id = Oberon.set THEN
									IF ~F.car & (M.car = F) THEN Oberon.Defocus;
										Caret(F,M.pos, Display.set);
									 END;
									showCaret := TRUE; SetCaret(F, M.pos); showCaret := FALSE;
									ELSE (* IF M.id = Oberon.reset  THEN *) RemoveCaret(F)
									END
								END
							END
						ELSIF M IS Oberon.ConsumeMsg THEN
							WITH M: Oberon.ConsumeMsg DO
								IF F.car THEN CopyOver(F, M.text, M.beg, M.end); M.res := 0 (*ELSE bcast := TRUE*) END
							END
						ELSIF M IS Oberon.RecallMsg THEN  IF F.car THEN Recall(F) (*ELSE bcast := TRUE*) END
						ELSIF M IS FocusMsg THEN  IF F.car THEN M(FocusMsg).foc := F; M.res := 0 END
						ELSIF M IS MarkMsg THEN
							WITH M: MarkMsg DO
								IF F.msk # NIL THEN mskD := F.msk^; END;
								F.mask := NIL;
								Gadgets.MakeMask(F, x+F.X, y+F.Y, M.dlink, F.msk);
								IF M.id = car THEN FlipCaret(F,  x, y)
								ELSIF (M.id = sel) & ((F.absX # M.absX) OR  (F.absY # M.absY)) THEN FlipSelection(F, x, y, F.selBeg, F.selEnd)
								ELSIF (M.id = arrow) & (F.H >= 16) THEN
									Display3.CopyPattern(F.msk,Display.FG, Display.downArrow, x+F.X, y+F.Y, 2)
								END;
								IF F.msk # NIL THEN F.msk^ := mskD END;
							END
							(*
						ELSIF M IS Display3.OverlapMsg THEN
							WITH M : Display3.OverlapMsg DO
								Gadgets.framehandle(F, M);
								InvalidateMasks(F);
							END;
							*)
						ELSIF M IS Styles.UpdateMsg THEN
							WITH M: Styles.UpdateMsg DO UpdateStyle(F, M); bcast := TRUE (* *) END
						ELSE Gadgets.framehandle(F,M);
							bcast := TRUE
						END;
						IF bcast THEN Broadcast(F, M) END;
					ELSE
						Broadcast(F, M);
					END;
					M.x := x; M.y := y; F.dlink := dlink; F.absX := absX; F.absY := absY; F.msk := msk;
					(*reset*)
				END
			ELSIF M IS Objects.FileMsg THEN
				WITH M : Objects.FileMsg DO
					IF M.id = Objects.store THEN
						Files.WriteInt(M.R,version);
						Files.WriteInt(M.R,F.left);
						Files.WriteString(M.R,F.cmd);
						Files.WriteSet(M.R,F.defStyle.opts);
						Files.WriteLInt(M.R,F.defStyle.paraW);
						Files.WriteInt(M.R,F.profile);
						Gadgets.framehandle(F,M);
						Gadgets.WriteRef(M.R, F.lib,F.text);
						Files.WriteSet(M.R,F.state0);
					ELSE
						Files.ReadInt(M.R,i);
						Files.ReadInt(M.R,F.left);
						Files.ReadString(M.R,F.cmd);
						Files.ReadSet(M.R,F.defStyle.opts);
						Files.ReadLInt(M.R,F.defStyle.paraW);
						Files.ReadInt(M.R,F.profile);
						Gadgets.framehandle(F,M);
						IF i = 0 THEN F.text := F.obj(Texts.Text)
						ELSE
							Gadgets.ReadRef(M.R, F.lib, obj);
							F.text := obj(Texts.Text);
							IF i = 2 THEN Files.ReadSet(M.R,F.state0) END ;
						END;
						F.hide := hide IN F.defStyle.opts
					END
				END
			ELSIF M IS Objects.BindMsg THEN
				Gadgets.framehandle(F,M);
				F.text.handle(F.text,M);
			ELSIF M IS Objects.CopyMsg THEN
				WITH M: Objects.CopyMsg DO
					IF M.stamp = F.stamp THEN M.obj := F.dlink	(* copy msg arrives again *)
					ELSE	(* first time copy message arrives *)
						NEW(F0); F.stamp := M.stamp; F.dlink := F0; CopyFrame(M, F, F0); M.obj := F0;
					END
				END
			ELSIF M IS Objects.AttrMsg THEN
				WITH M: Objects.AttrMsg DO
					FrameAttr(F,M);
				END
			ELSIF M IS Objects.LinkMsg THEN  Link(F, M(Objects.LinkMsg))
			ELSE
				Gadgets.framehandle(F,M)
			END;
		END;
		R1 := r1; (* CloseStyle; *)
	END Handle;

	(* --- creation --- *)

	PROCEDURE NewText* (text: Texts.Text; pos: SIGNED32): Frame;
		VAR F: Frame;
	BEGIN NEW(F);
		Open(F, Handle, text, pos, Display.BG, left, right, top, bot);
		F.col := 0; F.profile := flat;
		RETURN F
	END NewText;

	PROCEDURE CalcSize*(F: Frame; VAR w, h : SIGNED16);
		VAR L: Line;  r, s: SIGNED16;
	BEGIN InitFormatter(F, 0); w := 0; h := 0;
		IF adaptStyle IN F.defStyle.opts THEN w := SHORT(F.defStyle.paraW DIV Display.Unit) END;
		REPEAT
			FormatLine(L); Offsets(L, s, r);
			IF L.off + L.w > w THEN w := L.off + L.w END; INC(h, L.h)
		UNTIL L.eot;
		INC(h, F.top+F.bot); INC(w, F.left+F.right);
		(*
		IF (w # F.W) OR (h # F.H) THEN
			IF update THEN
				M.W := w; M.H := h; M.dW := w-F.W; M.dH := h-F.H;
				M.dX := 0; M.dY := -M.dH; M.X := F.X; M.Y := F.Y+M.dY;
				M.F := F; M.id := Display.extend; M.mode := Display.display; Display.Broadcast(M)
			ELSE F.W := w; F.H := h
			END
		END
		*)
	END CalcSize;

	(*
	PROCEDURE LineExtend(L: Line; VAR w, asr, dsr: SIGNED16; VAR brk: BOOLEAN);
	BEGIN w := SHORT(L.W DIV PrtUnit);
		IF (L.len = 1) & (pL.style # L.style) THEN asr := SHORT(L.style.gap DIV PrtUnit); dsr := 0;
			brk := TRUE	(*for printing: styles always break the line*)
		ELSE brk := L.brk;
			asr := SHORT(LONG(L.asr)*Display.Unit DIV PrtUnit); dsr := SHORT(LONG(L.dsr)*Display.Unit DIV PrtUnit)
		END
	END LineExtend;

	PROCEDURE FirstLine*(T: Texts.Text; VAR w, asr, dsr, nSpc: SIGNED16; VAR len: SIGNED32; VAR brk, eot: BOOLEAN);
	VAR F: Frame; L: Line;
	BEGIN NEW(F); F.text := T; NEW(pL); pL.style := Styles.defStyle; InitFormatter(F, 0); FormatLine(L);
		len := L.len; eot := L.eot; nSpc := L.nSpc; LineExtend(L, w, asr, dsr, brk); pL := L
	END FirstLine;

	PROCEDURE NextLine*(VAR w, asr, dsr, nSpc: SIGNED16; VAR len: SIGNED32; VAR brk, eot: BOOLEAN);
	VAR L: Line;
	BEGIN FormatLine(L); len := L.len; eot := L.eot; nSpc := L.nSpc; LineExtend(L, w, asr, dsr, brk); pL := L
	END NextLine;
	*)

	(*
	PROCEDURE Enum(X,Y,W,H : SIGNED16);
	BEGIN
		Pictures.DisplayBlock(enum.pict,X + enum.dX, Y + enum.dY, W, H, X, Y, Display.replace);
	END Enum;

	PROCEDURE ClipAgainst(VAR x, y, w, h: SIGNED16; x1, y1, w1, h1: SIGNED16);
	VAR r, t, r1, t1: SIGNED16;
	BEGIN
		r := x + w - 1; r1 := x1 + w1 - 1; t := y + h - 1; t1 := y1 + h1 - 1;
		IF x < x1 THEN x := x1 END;
		IF y < y1 THEN y := y1 END;
		IF r > r1 THEN r := r1 END;
		IF t > t1 THEN t := t1 END;
		w := r - x + 1; h := t - y + 1;
	END ClipAgainst;

	PROCEDURE DisplayBlock(VAR M : Display3.Mask; P : Pictures.Picture; X, Y, W, H, DX, DY : SIGNED16);
	BEGIN
		enum.dX := X-DX; enum.dY :=Y-DY;
		ClipAgainst(DX, DY, W, H, M.X, M.Y, M.W, M.H);
		enum.pict := P;
		Display3.EnumRect(M, DX, DY, W, H, Enum);
	END DisplayBlock;

	PROCEDURE Back(F:Frame; x, y: SIGNED16; R: Display3.Mask);
	BEGIN
		DisplayBlock(R, pict, 0,0,pict.width, pict.height, F.X + x, F.Y + y);
		(*
		Display3.ReplConst(R, Display3.white, F.X + x , F.Y + y, F.W,F.H,Display.replace);
		*)
	END Back;
	*)

	PROCEDURE NewFrame*;
		VAR F : Frame; t : Texts.Text;
	BEGIN
		NEW(t); Texts.Open(t,""); F:= NewText(t,0);
		F.col := Display3.textbackC; F.profile := down;
		Objects.NewObj := F;
	END NewFrame;

BEGIN
	show := Show;
	barW := Fonts.Default.height + 2;
	top := Fonts.Default.height DIV 2;  (*bot := top; *) bot := 3; left := barW + top; right := top;
	markW := barW *5 DIV 8; (*top*) eolW := top;
	Asr := Fonts.Default.maxY; Dsr := -Fonts.Default.minY;
	Texts.OpenWriter(W); Texts.OpenWriter(KW); Texts.OpenWriter(XW);
	(* hookS[4] := {0..7}; *) hookS[5] := {0..6};
	hookS[6] := {0..5};hookS[7] := {0..4};hookS[8] := {0..3};
	hookS[9] := {0..2};hookS[10] := {0..1};hookS[11] := {0};
	hook := Display.NewPattern(16,12,hookS);
	(* NEW(pict); Pictures.Open(pict,"Shop.Pict",FALSE); *)
END ScriptGadgets.

Views.Open  ^ Test.Panel
Gadgets.Insert ScriptGadgets.NewFrame ~
Gadgets.Insert Button ~
Script.Open gdsa
Gadgets.Insert Script.NewStyle