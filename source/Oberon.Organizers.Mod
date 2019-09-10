(* ETH Oberon, Copyright 2001 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

MODULE Organizers IN Oberon; (** portable *)	(* jm 8.12.94 *)

(*
	This is an example of a Panel extension. It uses simple constraints attached as attributes to its direct contents
	to calculate a new layout when the panel is resized. It uses a strategy by Luca Cardelli, and described
	in his paper "Building User Interfaces by Direct Manipulation", DEC, 1987.

	Four wires are strung between the four sides of a descendant and an edge of the panel. The horizontal sides
	of the child gadget are attached to the top or bottom of the panel, and the vertical sides to the left or the right.
	The length of the four wires are given as four numbers in the "Constraint" attribute. Positive numbers strung the
	wire "outward" and negative numbers "over the gadget".

	That is

		Gadgets.ChangeAttr Constraints "10 20 10 10" ~

	sets a constraint where the left edge of the gadget is 10 pixels from the left of the panel, the top edge 20 pixels
	from the panel top, the right edge 10 pixels from the panel right, and the bottom edge 10 pixels from the panel
	bottom. Thus the sequence of numbers are left, top, right, and bottom distances.

	Changing the 20 to -20 attaches the top edge of the gadget 20 pixels from the bottom of the panel.
	Get the idea? The mechanism is quite flexible, although I am sure you will want more!

	Gadgets.Exchange flips the marked panel between an organizer and a normal panel. This works on panel
	documents too. An example document built with Organizers is "TestOrganizer.Panel".

	Hannes Marais, 9.12.94

	----------------------
	Extension 15.3.2005 Patrick Hunziker:
	the Organizer accepts now also Child Constraints in relative dimensions (compared to the parent size) instead of Pixels, e.g.

	Gadgets.ChangeAttr Constraints "0.3 0.1 0.2 0.2" ~

	This makes resizing of Organizers together with its contents more powerful.

*)

IMPORT Objects, Display, Effects, Gadgets, Panels, Oberon, Strings (*, Messages*);

CONST
	outofboundsmodify = 3;
	DontCare = MAX(SIGNED32);
	DontCareR = MAX(FLOAT64);

VAR
	methods: Panels.Methods;

PROCEDURE Parse(s: ARRAY OF CHAR; VAR l, t, r, b: SIGNED32);
VAR p: ARRAY 64 OF CHAR; i, j: SIGNED16;

	PROCEDURE ReadNum(): SIGNED32;
	VAR x: SIGNED32;
	BEGIN
		WHILE (s[i] # 0X) & (s[i] <= " ") DO INC(i) END;
		IF s[i] = 0X THEN RETURN 0
		ELSIF ((s[i] < "0") OR (s[i] > "9")) & (s[i] # "-")  THEN INC(i); RETURN DontCare	(**)
		END;
		j := 0; WHILE (s[i] # 0X) & (s[i] > " ") DO p[j] := s[i]; INC(i); INC(j) END;
		p[j] := 0X; Strings.StrToInt(p, x); RETURN x
	END ReadNum;

BEGIN
	i := 0;
	l := ReadNum(); t := ReadNum(); r := ReadNum(); b := ReadNum()
END Parse;

PROCEDURE ParseGeneral(s: ARRAY OF CHAR; VAR l, t, r, b: SIGNED32; VAR lrel,trel,rrel,brel:FLOAT64);
VAR p: ARRAY 64 OF CHAR; i, j: SIGNED16;

	PROCEDURE ReadNum(VAR x:SIGNED32; VAR y:FLOAT64);
	VAR isReal:BOOLEAN;
	BEGIN
		isReal:=FALSE;
		x:=DontCare; y:=DontCareR;
		WHILE (s[i] # 0X) & (s[i] <= " ") DO INC(i) END;
		IF s[i] = 0X THEN x:=0;  RETURN
		ELSIF ((s[i] < "0") OR (s[i] > "9")) & (s[i] # "-") & (s[i] # ".") THEN INC(i); RETURN (*not a number*)
		END;
		j := 0; WHILE (s[i] # 0X) & (s[i] > " ") DO p[j] := s[i]; IF s[i]="." THEN isReal:=TRUE END; INC(i); INC(j); END;
		p[j] := 0X;
		IF isReal THEN Strings.StrToReal(p, y);
		ELSE Strings.StrToInt(p, x);
		END;
	END ReadNum;

BEGIN
	i := 0;
	ReadNum(l,lrel); ReadNum(t,trel); ReadNum(r,rrel); ReadNum(b,brel);
END ParseGeneral;

PROCEDURE HasConstraints*(f: Display.Frame; VAR l, t, r, b: SIGNED32): BOOLEAN;
VAR A: Objects.AttrMsg;
BEGIN
	A.id := Objects.get; A.name := "Constraints"; A.res := -1; f.handle(f, A);
	IF (A.res >= 0) & (A.class = Objects.String) & (A.s # "") THEN Parse(A.s, l, t, r, b); RETURN TRUE
	ELSE RETURN FALSE
	END
END HasConstraints;

PROCEDURE HasGeneralConstraints*(f: Display.Frame; VAR l, t, r, b: SIGNED32; VAR lrel,trel,rrel,brel:FLOAT64): BOOLEAN;
VAR A: Objects.AttrMsg;
BEGIN
	A.id := Objects.get; A.name := "Constraints"; A.res := -1; f.handle(f, A);
	IF (A.res >= 0) & (A.class = Objects.String) & (A.s # "") THEN ParseGeneral(A.s, l, t, r, b, lrel,trel,rrel,brel); RETURN TRUE
	ELSE RETURN FALSE
	END
END HasGeneralConstraints;

PROCEDURE SolveGadget*(PW, PH: SIGNED16; f: Display.Frame; l, t, r, b: SIGNED32; VAR X, Y, W, H: SIGNED16);
VAR ll, tt, rr, bb: SIGNED32;
BEGIN
	IF l = DontCare THEN ll := f.X ELSIF l >= 0 THEN ll := l ELSE ll := PW + l END;
	IF r = DontCare THEN rr := f.X + f.W - 1 ELSIF r >= 0 THEN rr := PW - 1 - r ELSE rr := ABS(r) END;
	IF t = DontCare THEN tt := f.Y + f.H - 1 ELSIF t >= 0 THEN tt := - t ELSE tt := -PH - t END;
	IF b = DontCare THEN bb := f.Y ELSIF b >= 0 THEN bb := -PH + 1 + b ELSE bb := b END;

	IF (l = DontCare) & (r # DontCare) THEN ll := rr - f.W + 1
	ELSIF (l # DontCare) & (r = DontCare) THEN rr := ll + f.W - 1
	END;
	IF (t = DontCare) & (b # DontCare) THEN tt := bb + f.H - 1
	ELSIF (t # DontCare) & (b = DontCare) THEN bb := tt - f.H + 1
	END;
	X := SHORT(ll); Y := SHORT(bb);

	IF Gadgets.lockedsize IN f(Gadgets.Frame).state THEN W := f.W; H := f.H
	ELSE W := SHORT(rr) - X + 1; H := SHORT(tt) - Y + 1
	END
END SolveGadget;

PROCEDURE SolveGadgetGeneral*(PW, PH: SIGNED16; f: Display.Frame; l, t, r, b: SIGNED32; lrel,trel,rrel,brel:FLOAT64; VAR X, Y, W, H: SIGNED16);
VAR ll, tt, rr, bb: SIGNED32;
BEGIN
	IF lrel#DontCareR THEN l := ENTIER(PW*lrel) END;
	IF rrel#DontCareR THEN r := ENTIER(PW*rrel) END;
	IF trel#DontCareR THEN t := ENTIER(PH*trel) END;
	IF brel#DontCareR THEN b := ENTIER(PH*brel) END;

	IF l = DontCare THEN ll := f.X ELSIF l >= 0 THEN ll := l ELSE ll := PW + l END;
	IF r = DontCare THEN rr := f.X + f.W - 1 ELSIF r >= 0 THEN rr := PW - 1 - r ELSE rr := ABS(r) END;
	IF t = DontCare THEN tt := f.Y + f.H - 1 ELSIF t >= 0 THEN tt := - t ELSE tt := -PH - t END;
	IF b = DontCare THEN bb := f.Y ELSIF b >= 0 THEN bb := -PH + 1 + b ELSE bb := b END;

	IF (l = DontCare) & (r # DontCare) THEN ll := rr - f.W + 1
	ELSIF (l # DontCare) & (r = DontCare) THEN rr := ll + f.W - 1
	END;
	IF (t = DontCare) & (b # DontCare) THEN tt := bb + f.H - 1
	ELSIF (t # DontCare) & (b = DontCare) THEN bb := tt - f.H + 1
	END;
	X := SHORT(ll); Y := SHORT(bb);

	IF Gadgets.lockedsize IN f(Gadgets.Frame).state THEN W := f.W; H := f.H
	ELSE W := SHORT(rr) - X + 1; H := SHORT(tt) - Y + 1
	END
END SolveGadgetGeneral;

PROCEDURE Solve*(F: Panels.Panel; dX, dY, W, H: SIGNED16; mode: SIGNED16);
VAR f: Display.Frame; l, t, r, b: SIGNED32; lrel, trel, rrel, brel:FLOAT64; M: Display.ModifyMsg;
BEGIN
	f := F.dsc;
	WHILE f # NIL DO
		IF HasGeneralConstraints(f, l, t, r, b, lrel, trel, rrel, brel) THEN
			SolveGadgetGeneral(W, H, f, l, t, r, b, lrel, trel, rrel, brel, M.X, M.Y, M.W, M.H);
			IF (M.W > 0) & (M.H > 0) THEN INC(M.X, dX); INC(M.Y, dY);
				M.id := outofboundsmodify; M.F := f; M.mode := Display.state;
				M.dX := M.X - f.X; M.dY := M.Y - f.Y; M.dW := M.W - f.W; M.dH := M.H - f.H;
				Objects.Stamp(M); M.res := -1; M.dlink := NIL; M.x := 0; M.y := 0;
				f.handle(f, M)
			END
		END;
		f := f.next
	END;
END Solve;

PROCEDURE Handler*(F: Objects.Object; VAR M: Objects.ObjMsg);
VAR l, t, r, b: SIGNED32; lrel, trel, rrel, brel:FLOAT64; oX, oY, oW, oH, mode: SIGNED16; f: Objects.Object; A: Display.ModifyMsg;
BEGIN
	WITH F: Panels.Panel DO
		IF M IS Display.ModifyMsg THEN
			WITH M: Display.ModifyMsg DO
				IF (M.F = F) & ((M.W # F.W) OR (M.H # F.H)) THEN
					IF ((M.dH = 0) OR (M.Y + M.H = F.Y + F.H)) & ((M.dW = 0) OR (M.X = F.X)) THEN
						Solve(F, M.X - F.X, M.Y + M.H - F.Y - F.H, M.W, M.H, M.mode);
						Panels.PanelHandler(F, M);
					ELSE
						mode := M.mode; M.mode := Display.state;
						Panels.PanelHandler(F, M);
						Solve(F, M.X - F.X, M.Y + M.H - F.Y - F.H, M.W, M.H, M.mode);
						IF mode = Display.display THEN Gadgets.Update(F) END
					END
				ELSIF Panels.IsChild(F, M.F) & (M.id # outofboundsmodify) THEN (* not send to self *)
					IF HasGeneralConstraints(M.F, l, t, r, b, lrel, trel, rrel, brel) THEN
						oX := M.F.X; oY := M.F.Y; oW := M.F.W; oH := M.F.H;
						M.F.X := M.X; M.F.Y := M.Y; M.F.W := M.W; M.F.H := M.H;
						SolveGadgetGeneral(F.W, F.H, M.F, l, t, r, b, lrel, trel, rrel, brel, M.X, M.Y, M.W, M.H);
						M.F.X := oX; M.F.Y := oY; M.F.W := oW; M.F.H := oH;
						M.dX := M.X - M.F.X; M.dY := M.Y - M.F.Y; M.dW := M.W - M.F.W; M.dH := M.H - M.F.H;
					END;
					Panels.PanelHandler(F, M)
				ELSE
					Panels.PanelHandler(F, M)
				END;
			END
		ELSIF M IS Gadgets.UpdateMsg THEN (* when an attribute changes *)
			WITH M: Gadgets.UpdateMsg DO
				Panels.PanelHandler(F, M); (* forward *)
				f := M.obj;
				IF (f IS Gadgets.Frame) & Panels.IsChild(F, f(Gadgets.Frame)) THEN
					WITH f: Gadgets.Frame DO
						IF HasGeneralConstraints(f, l, t, r, b, lrel, trel, rrel, brel) THEN
							SolveGadgetGeneral(F.W, F.H, f, l, t, r, b, lrel, trel, rrel, brel, A.X, A.Y, A.W, A.H);
							IF (A.X # f.X) OR (A.Y # f.Y) OR (A.W # f.W) OR (A.H # f.H) THEN
								A.id := outofboundsmodify; A.F := f; A.mode := Display.display;
								A.dX := A.X - f.X; A.dY := A.Y - f.Y; A.dW := A.W - f.W; A.dH := A.H - f.H;
								Display.Broadcast(A)
							END
						END
					END
				END;
				(*Panels.PanelHandler(F, M);*)
			END
		ELSIF M IS Objects.AttrMsg THEN
			WITH M: Objects.AttrMsg DO
				IF (M.id = Objects.get) & (M.name = "Gen") THEN M.s := "Organizers.NewPanel"; M.class := Objects.String; M.res := 0
				ELSIF (M.id = Objects.set) & (M.name = "Locked") THEN
					Panels.PanelHandler(F, M); EXCL(F.state, Gadgets.lockedsize)
				ELSE Panels.PanelHandler(F, M)
				END
			END
		ELSE Panels.PanelHandler(F, M)
		END
	END
END Handler;

(*PROCEDURE RestoreBackGround(F: Panels.Panel; x, y: SIGNED16; R: Display3.Mask);
BEGIN
	Panels.methods.RestoreBackGround(F, x, y, R);
	Display3.Line(R, Display.FG, Display.solid, x + 1, y + F.H - 11, x + 10, y + F.H - 2, 1, Display.replace);
	Display3.Line(R, Display.BG, Display.solid, x + 1, y + F.H - 12, x + 10, y + F.H - 3, 1, Display.replace)
END RestoreBackGround;*)

PROCEDURE InsertChild(F: Panels.Panel; f: Display.Frame; u, v: SIGNED16);
VAR l, t, r, b: SIGNED32; lrel, trel, rrel, brel:FLOAT64; x, y, w, h: SIGNED16;
BEGIN
	IF HasGeneralConstraints(f, l, t, r, b, lrel, trel, rrel, brel) THEN
		SolveGadgetGeneral(F.W, F.H, f, l, t, r, b, lrel, trel, rrel, brel, x, y, w, h);
		IF (w > 0) & (h > 0) THEN
			u := x; v := y; f.W := w; f.H := h;
		END
	END;
	Panels.methods.InsertChild(F, f, u, v)
END InsertChild;

PROCEDURE TrackMouse(F: Panels.Panel; VAR M: Oberon.InputMsg);
VAR T: Display.Frame; x, y, t, u, v: SIGNED16; d: SIGNED32; r:FLOAT64; Fdlink, Mdlink: Objects.Object; flags: SET;
BEGIN
	x := M.x + F.X; y := M.y + F.Y; t := y + F.H - 1;
	T := Panels.ThisChild(F, x, y, M.X, M.Y);

	IF T # NIL THEN
		Effects.SetSnap(x, t, F.grid, F.grid);
		IF HasGeneralConstraints(T, d, d, d, d, r, r, r, r) THEN (* simulated a locked environment *)
			flags := F.state;
			INCL(F.state, Gadgets.lockedcontents);
			Panels.ToChild(F, T, x, y, M);
			F.state := flags
		ELSE
			Panels.ToChild(F, T, x, y, M)
		END;
		Effects.SetSnap(0, 0, 1, 1)
	END;

	IF M.res < 0 THEN
		Effects.SetSnap(x, t, F.grid, F.grid);
		IF 2 IN M.keys THEN (* left *)
			IF ~(Panels.noinsert IN F.state0) THEN F.do.TrackCaret(F, M) END
		ELSIF 1 IN M.keys THEN (* middle *)
			IF (T # NIL) & (Gadgets.selected IN T(Gadgets.Frame).state) THEN
				WITH T: Gadgets.Frame DO
					IF Effects.InCorner(M.X, M.Y, x + T.X, t + T.Y, T.W, T.H) & ~(Gadgets.lockedsize IN T.state) THEN
						u := M.x; v := M.y; M.x := x; M.y := t;
						Fdlink := F.dlink; Mdlink := M.dlink; F.dlink := M.dlink; M.dlink := F;
						Gadgets.SizeFrame(T, M);
						F.dlink := Fdlink; M.dlink := Mdlink;
						M.x := u; M.y := v; M.res := 0
					ELSE F.do.DragSelection(F, M)
					END
				END
			END
		ELSIF 0 IN M.keys THEN (* right *)
			IF ~(Panels.noselect IN F.state0) THEN
				IF T = NIL THEN F.do.TrackSelection(F, M)
				ELSE F.do.TrackSelectChild(F, M, T(Gadgets.Frame))
				END
			END
		END;
		Effects.SetSnap(0, 0, 1, 1)
	END
END TrackMouse;

PROCEDURE InitPanel*(F: Panels.Panel);
BEGIN Panels.InitPanel(F); F.handle := Handler; F.do := methods;
END InitPanel;

PROCEDURE NewPanel*;
VAR p: Panels.Panel;
BEGIN
	NEW(p); InitPanel(p); Objects.NewObj := p
END NewPanel;

(* Make a normal panel into a organizer, and vice versa *)
PROCEDURE Exchange*;
VAR F: Display.Frame;
BEGIN
	IF Oberon.Pointer.on THEN
		F := Oberon.MarkedFrame();
		IF (F # NIL) & (F IS Panels.Panel) THEN
			WITH F: Panels.Panel DO
				IF F.do # methods THEN
					F.handle := Handler; F.do := methods;
					Solve(F, 0, 0, F.W, F.H, Display.state); Gadgets.Update(F)
				ELSE F.handle := Panels.PanelHandler; F.do := Panels.methods; Gadgets.Update(F)
				END
			END
		END
	END
END Exchange;

BEGIN NEW(methods); methods^ := Panels.methods^;
	(*methods.RestoreBackGround := RestoreBackGround;*) methods.InsertChild := InsertChild;
	methods.TrackMouse := TrackMouse
END Organizers.

System.Free Organizers ~
Gadgets.Insert Organizers.NewPanel ~
Gadgets.Insert Button ~
Gadgets.Insert TextField ~


Organizers.Exchange
Gadgets.ChangeAttr Constraints "8 8 x x" ~
Gadgets.ChangeAttr Constraints "56 8 x x" ~
Gadgets.ChangeAttr Constraints "104 8 8 x" ~
Gadgets.ChangeAttr Constraints "8 36 8 8" ~

Gadgets.ChangeAttr Constraints "0.1 0.1 x x" ~
Gadgets.ChangeAttr Constraints "0.5  0.1 x x" ~
Gadgets.ChangeAttr Constraints "0.8 8 8 x" ~
Gadgets.ChangeAttr Constraints "0.2 0.2 0.5 0.5" ~\
Gadgets.ChangeAttr Constraints "0.2 0.6 0.5 0.1" ~
Gadgets.ChangeAttr Constraints "0.7 0.2 0.1 0.5" ~\
Gadgets.ChangeAttr Constraints "0.7 0.6 0.1 0.1" ~

Gadgets.ChangeAttr Constraints "0.5 0.3 0.3 0.5" ~\
Gadgets.ChangeAttr Constraints "0.5 0.4 0.3 0.3" ~


Gadgets.ChangeAttr Constraints "10 50 10 10" ~

Try also to resize the entire Organizer with the mouse and look at the behaviour of its children !

TextFieldsNEW.Mod