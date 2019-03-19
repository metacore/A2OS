MODULE vyAxis IN Oberon;
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
(c) F. Friedrich, StatLab Heidelberg
*)

(*
960822 fof corrected error in AppendRealToString *)

IMPORT vyBase, vyGraphBase, vyHost, vyHostDisplay := vyGraphBase,  vyHostStrings, Files;
VAR
	DefaultLabelColor* : vyGraphBase.Color;  (* black *)
	DefaultAxeColor* : vyGraphBase.Color;
	DefaultTicksColor* : vyGraphBase.Color;

CONST
	idversion* = 	"vyAxis v0r0a2";
	DefaultLabelFont* = "Syntax8.Scn.Fnt";
	DefaultMinorTicks* = 1;
	DefaultEFormat* = FALSE;
	DefaultDigitsAfterPoint* = 2;
	Automatic* = 0;
	Fix* = 1;

	horizontal = 0;  vertical = 1;  under = 0;  over = 1;  leftfrom = 2;  rightfrom = 3;
	down = 0;  up = 1;  left = 2;  right = 3;
	LabelDistance = 10 * vyHostDisplay.pixel;  MinLabelToLabelDistance = 2 * vyHostDisplay.pixel;
	TicksLength = 8 * vyHostDisplay.pixel;  MinorTicksLength = 4 * vyHostDisplay.pixel;
	EPS = 1 / 10000;  infinity = MAX(INTEGER);
	MinLabelRoom = 30 * vyHostDisplay.pixel;

TYPE
	Real = vyBase.Real;
	Coordinate = vyGraphBase.Coordinate;
	Color = vyGraphBase.Color;

	Label = POINTER TO LabelDesc;
	LabelDesc = RECORD
		x, y, w, h, dsr, pos: Coordinate;
		r: Real;
		s: ARRAY 32 OF CHAR;
		next: Label
	END;

	Tick = POINTER TO TickDesc;
	TickDesc = RECORD
		x, y: Coordinate;
		pos: Coordinate;
		r: Real;
		next: Tick
	END;

	tAxe* = POINTER TO tAxeDesc;
	tAxeDesc* = RECORD
		x1, y1, x2, y2: Coordinate;
		r1, r2, r, dr: Real;
		r1x, r1y, r2x, r2y: Real;
		X- , Y- , W- , H- : Coordinate;
		TickRoot: Tick;
		LabelRoot: Label;
		tdx, tdy: Coordinate;
		DigitsAfterPoint: INTEGER;
		Format: BOOLEAN;
		MinorTicks: INTEGER;
		Orientation: INTEGER;
		RtoXY: PROCEDURE (axe: tAxe;  r: Real;  VAR x, y: Coordinate);
		UsePaint2d: BOOLEAN
	END;

VAR
	LabelFont : ARRAY 32 OF CHAR;
	LabelColor, AxeColor, TicksColor : Color;
	MinorTicks, DigitsAfterPoint: INTEGER;
	EFormat, Opposite,  TicksAutomatic: BOOLEAN;
	LabelsPlot : BOOLEAN;
	UsePaint2d*: BOOLEAN;
	showlast0: BOOLEAN;


PROCEDURE StoreTick (VAR R: Files.Rider;  t:  Tick);
BEGIN
	IF t = NIL THEN
		Files.WriteInt(R, - 1)
	ELSE
		Files.WriteInt(R, 0);
		Files.WriteInt(R, t.x);  Files.WriteInt(R, t.y);  Files.WriteInt(R, t.pos);  Files.WriteLReal(R, t.r)
	END
END StoreTick;

PROCEDURE StoreTicksQueue (VAR R: Files.Rider;  t:  Tick);
BEGIN
	WHILE t # NIL DO
		StoreTick(R, t);
		t := t.next
	END;
	StoreTick(R, t)
END StoreTicksQueue;

PROCEDURE LoadTick (VAR R: Files.Rider;  VAR t: Tick);
	VAR i: INTEGER;
BEGIN
	Files.ReadInt(R, i);
	IF i = - 1 THEN t := NIL
	ELSE
		NEW(t);
		Files.ReadInt(R, t.x);  Files.ReadInt(R, t.y);  Files.ReadInt(R, t.pos);  Files.ReadLReal(R, t.r)
	END
END LoadTick;
PROCEDURE LoadTicksQueue (VAR R: Files.Rider;  VAR t: Tick);
	VAR t0: Tick;
BEGIN
	LoadTick(R, t);
	t0 := t;
	WHILE (t0 # NIL) DO
		LoadTick(R, t0.next);
		t0 := t0.next
	END
END LoadTicksQueue;

PROCEDURE StoreLabel (VAR R: Files.Rider;  t: Label);
BEGIN
	IF t = NIL THEN
		Files.WriteInt(R, - 1)
	ELSE
		Files.WriteInt(R, 0);
		Files.WriteInt(R, t.x);  Files.WriteInt(R, t.y);
		Files.WriteInt(R, t.w);  Files.WriteInt(R, t.h);
		Files.WriteInt(R, t.dsr);  Files.WriteInt(R, t.pos);
		Files.WriteLReal(R, t.r);
		Files.WriteString(R, t.s)
	END

END StoreLabel;
PROCEDURE StoreLabelsQueue (VAR R: Files.Rider;  t:  Label);
BEGIN
	WHILE t # NIL DO
		StoreLabel(R, t);
		t := t.next
	END;
	StoreLabel(R, t)
END StoreLabelsQueue;


PROCEDURE LoadLabel (VAR R: Files.Rider;  VAR t: Label);
	VAR i: INTEGER;
BEGIN
	Files.ReadInt(R, i);
	IF i = - 1 THEN t := NIL
	ELSE
		NEW(t);
		Files.ReadInt(R, t.x);  Files.ReadInt(R, t.y);
		Files.ReadInt(R, t.w);  Files.ReadInt(R, t.h);
		Files.ReadInt(R, t.dsr);  Files.ReadInt(R, t.pos);
		Files.ReadLReal(R, t.r);
		Files.ReadString(R, t.s)
	END
END LoadLabel;

PROCEDURE LoadLabelsQueue (VAR R: Files.Rider;  VAR t: Label);
	VAR t0: Label;
BEGIN
	LoadLabel(R, t);
	t0 := t;
	WHILE (t0 # NIL) DO
		LoadLabel(R, t0.next);
		t0 := t0.next
	END
END LoadLabelsQueue;
PROCEDURE StoreAxe* (VAR R: Files.Rider;  a: tAxe);
BEGIN
	IF a = NIL THEN
		Files.WriteInt(R, - 1)
	ELSE
		Files.WriteInt(R, 0);
		Files.WriteInt(R, a.x1);  Files.WriteInt(R, a.y1);  Files.WriteInt(R, a.x2);  Files.WriteInt(R, a.y2);
		Files.WriteLReal(R, a.r1);  Files.WriteLReal(R, a.r2);  Files.WriteLReal(R, a.r);  Files.WriteLReal(R, a.dr);
		Files.WriteLReal(R, a.r1x);  Files.WriteLReal(R, a.r1y);  Files.WriteLReal(R, a.r2x);  Files.WriteLReal(R, a.r2y);
		Files.WriteInt(R, a.X);  Files.WriteInt(R, a.Y);  Files.WriteInt(R, a.W);  Files.WriteInt(R, a.H);
		StoreTicksQueue(R, a.TickRoot);
		StoreLabelsQueue(R, a.LabelRoot);
		Files.WriteInt(R, a.tdx);  Files.WriteInt(R, a.tdy);
		Files.WriteInt(R, a.DigitsAfterPoint);
		Files.WriteBool(R, a.Format);
		Files.WriteInt(R, a.MinorTicks);
		Files.WriteInt(R, a.Orientation);
		Files.WriteBool(R, a.UsePaint2d)
	END
END StoreAxe;

PROCEDURE LoadAxe* (VAR R: Files.Rider;  VAR a: tAxe);
	VAR i: INTEGER;
BEGIN
	Files.ReadInt(R, i);
	IF i = - 1 THEN a := NIL
	ELSE
		NEW(a);
		Files.ReadInt(R, a.x1);  Files.ReadInt(R, a.y1);  Files.ReadInt(R, a.x2);  Files.ReadInt(R, a.y2);
		Files.ReadLReal(R, a.r1);  Files.ReadLReal(R, a.r2);  Files.ReadLReal(R, a.r);  Files.ReadLReal(R, a.dr);
		Files.ReadLReal(R, a.r1x);  Files.ReadLReal(R, a.r1y);  Files.ReadLReal(R, a.r2x);  Files.ReadLReal(R, a.r2y);
		Files.ReadInt(R, a.X);  Files.ReadInt(R, a.Y);  Files.ReadInt(R, a.W);  Files.ReadInt(R, a.H);
		LoadTicksQueue(R, a.TickRoot);
		LoadLabelsQueue(R, a.LabelRoot);
		Files.ReadInt(R, a.tdx);  Files.ReadInt(R, a.tdy);
		Files.ReadInt(R, a.DigitsAfterPoint);
		Files.ReadBool(R, a.Format);
		Files.ReadInt(R, a.MinorTicks);
		Files.ReadInt(R, a.Orientation);
		Files.ReadBool(R, a.UsePaint2d);
		IF a.UsePaint2d THEN
			a.RtoXY := GetXYbyR2
		ELSE
			a.RtoXY := GetXYbyR
		END

	END
END LoadAxe;

PROCEDURE DecExpR (m: INTEGER): LONGREAL;
	(*! ???? TenL aus vyBase benutzen. gs *)
	VAR z : LONGREAL;
BEGIN
	z := 1;
	WHILE m > 0 DO DEC(m);  z := z * 10 END;
	WHILE m < 0 DO INC(m);  z := z / 10 END;
	RETURN z
END DecExpR;

PROCEDURE InRect (VAR X, Y, W, H: INTEGER;  x, y, w, h: INTEGER);
BEGIN
	IF x < X THEN INC(W, X - x);  DEC(X, X - x)  END;
	IF x + w > W + X THEN INC(W, x + w - X - W) END;
	IF y < Y THEN INC(H, Y - y);  DEC(Y, Y - y) END;
	IF y + h > Y + H THEN INC(H, y + h - Y - H) END
END InRect;


PROCEDURE equals (r1, r2: Real): BOOLEAN;
BEGIN IF ABS(r1 - r2) < EPS THEN RETURN TRUE ELSE RETURN FALSE END END equals;

PROCEDURE SetExponent (VAR r: LONGREAL;  VAR Expo: INTEGER);  	(** vs 1.0d FOF	 27.06.94 15:30:37*)
	(*! ???? Intervallschachtelung benutzten ! gs *)
	VAR m : INTEGER;
BEGIN
	m := 0;
	IF ~(equals(SHORT(r), 0))  THEN
		WHILE DecExpR(m) < ABS(r) DO INC(m) END;
		WHILE DecExpR(m) > ABS(r) DO DEC(m) END;
		r := r / vyHost.TenL(m);
		Expo := m
	ELSE
		Expo := 0
	END
END SetExponent;


PROCEDURE AppendRealToString (l: LONGREAL;  VAR s: ARRAY OF CHAR;  E: BOOLEAN;  m: INTEGER);
VAR
	e, i: INTEGER;
PROCEDURE RTS (r: LONGREAL;  m1: INTEGER;  VAR string: ARRAY OF CHAR);
VAR
	r1: LONGREAL;  L, L1, L2: LONGINT;  h, a: INTEGER;  neg: BOOLEAN;
BEGIN
	IF r < 0 THEN neg := TRUE;  r := - r ELSE neg := FALSE END;
	r1 := vyHost.TenL(m1) * r;
	IF r1 - ENTIER(r1) > 0.5 THEN
		r1 := r1 + 1
	END;
	L := ENTIER(r1);
	L1 := L DIV ENTIER(vyHost.TenL(m1));  L2 := L MOD ENTIER(vyHost.TenL(m1));
	IF (L1 = 0) THEN (* fof insert 960822 *)
		IF neg THEN vyHostStrings.Append(s, "-0")
		ELSE vyHostStrings.Append(s, "0") END
	ELSIF neg THEN vyHostStrings.AppendInt(  - L1, 0, s)
	ELSE vyHostStrings.AppendInt(L1, 0, s) END;
	IF ((~showlast0) & (L2 = 0)) OR (m1 <= 0) THEN RETURN END;
	L1 := L2;
	a := 0;  WHILE(L1 # 0) DO L1 := L1 DIV 10;  INC(a) END;
	h := 0;  WHILE(s[h] # 0X) DO INC(h) END;  s[h] := ".";  INC(h);
	WHILE(a < m1) DO s[h] := "0";  INC(h);  INC(a) END;
	s[h] := 0X;
	IF L2 # 0 THEN  vyHostStrings.AppendInt(L2, 0, s) END
END RTS;

BEGIN
	e := 0;
	IF E = FALSE THEN
		IF  (ABS(l) * vyHost.TenL(m) > MAX(LONGINT))  OR ((l > 0) & (ABS(l) * vyHost.TenL(m) < 1 / MAX(LONGINT)))  THEN
			E := TRUE;  AppendRealToString(l, s, E, m);  RETURN
		ELSE
			RTS(l, m, s)
		END
	ELSE
		SetExponent(l, e);
		IF e = 0 THEN
			RTS(l, m, s)
		ELSE
			RTS(l, m, s);
			i := 0;  WHILE(s[i] # 0X) DO INC(i) END;  s[i] := "E";  s[i + 1] := 0X;
			RTS(e, 0, s)
		END
	END
END AppendRealToString;


PROCEDURE GetXbyY (axe: tAxe;  yval: Coordinate): Coordinate;
BEGIN IF axe.y1 < axe.y2 THEN
		RETURN (axe.x2 - axe.x1) * (yval - axe.y1) DIV (axe.y2 - axe.y1)
	ELSIF axe.y1 > axe.y2 THEN
		RETURN - (axe.x2 - axe.x1) * (yval - axe.y1) DIV (axe.y1 - axe.y2)
	ELSE RETURN infinity END END GetXbyY;

PROCEDURE GetYbyX (axe: tAxe ;  xval: Coordinate): Coordinate;
BEGIN IF axe.x1 < axe.x2 THEN
		RETURN (axe.y2 - axe.y1) * (xval - axe.x1) DIV (axe.x2 - axe.x1)
	ELSIF axe.x1 > axe.x2 THEN
		RETURN - (axe.y2 - axe.y1) * (xval - axe.x1) DIV (axe.x1 - axe.x2)
	ELSE RETURN infinity END END GetYbyX;

PROCEDURE GetXYbyR (axe: tAxe;  r: Real;  VAR x, y: Coordinate);
BEGIN
	x := SHORT(ENTIER((axe.x2 - axe.x1) * (r - axe.r1) / (axe.r2 - axe.r1))) ;
	y := SHORT(ENTIER((axe.y2 - axe.y1) * (r - axe.r1) / (axe.r2 - axe.r1)))
END GetXYbyR;


PROCEDURE GetXYbyR2 (axe: tAxe;  r: Real;  VAR x, y: Coordinate);
	VAR rx, ry: Real;
BEGIN
	rx := axe.r1x + (axe.r2x - axe.r1x) * (r - axe.r1) / (axe.r2 - axe.r1);
	ry := axe.r1y + (axe.r2y - axe.r1y) * (r - axe.r1) / (axe.r2 - axe.r1);
	vyGraphBase.Point2dToPoint(rx, ry, x, y);
	x := x - axe.x1;
	y := y - axe.y1
END GetXYbyR2;
(*____________________________________________________*)




PROCEDURE TestTheLabels (axe: tAxe);
	VAR 	label: Label;  x, y, w, h, X, Y: Coordinate;

PROCEDURE ShiftTheLabels (dir: INTEGER);
BEGIN
	label := axe.LabelRoot.next;
	WHILE(label # NIL) DO
		IF dir = right THEN label.x := label.x + label.w DIV 2
		ELSIF dir = left THEN  label.x := label.x - label.w DIV 2
		ELSIF dir = up THEN label.y := label.y + label.h DIV 2
		ELSIF dir = down THEN label.y := label.y - label.h DIV 2
		END;
		label := label.next
	END
END ShiftTheLabels;

BEGIN
	label := axe.LabelRoot.next;
	WHILE(label # NIL) DO
		x := label.x - MinLabelToLabelDistance;
		y := label.y - MinLabelToLabelDistance;
		w := label.w + 2 * MinLabelToLabelDistance;
		h := label.h + 2 * MinLabelToLabelDistance;
		IF label.pos = over THEN
			Y := GetYbyX(axe, x + w);
			IF (Y # infinity) & (Y > y) THEN ShiftTheLabels(left);  RETURN  END;
			Y := GetYbyX(axe, x);
			IF (Y # infinity) & (Y > label.y) THEN ShiftTheLabels(right);  RETURN  END
		ELSIF label.pos = under THEN
			Y := GetYbyX(axe, x + w);
			IF (Y # infinity) & (Y < y + h) THEN ShiftTheLabels(left);  RETURN  END;
			Y := GetYbyX(axe, x);
			IF (Y # infinity) & (Y < y + h) THEN ShiftTheLabels(right);  RETURN  END
		ELSIF label.pos = rightfrom THEN
			X := GetXbyY(axe, y + h);
			IF (X # infinity) & (X > x) THEN ShiftTheLabels(down);  RETURN  END;
			X := GetXbyY(axe, y);
			IF (X # infinity) & (X > x) THEN ShiftTheLabels(up);  RETURN  END
		ELSIF label.pos = leftfrom THEN
			X := GetXbyY(axe, y + h);
			IF (X # infinity) & (X < x + w) THEN ShiftTheLabels(down);  RETURN END;
			X := GetXbyY(axe, y);
			IF (X # infinity) & (X < x + w) THEN ShiftTheLabels(up);  RETURN  END
		END;
		label := label.next
	END
END TestTheLabels;

PROCEDURE MinStdWidth* (): INTEGER;
BEGIN
	RETURN LabelDistance
END MinStdWidth;


PROCEDURE PlotTheLabels (axe: tAxe);
	VAR label: Label;
BEGIN
	IF axe.LabelRoot = NIL THEN RETURN END;   (* fof 020624 *)
	label := axe.LabelRoot.next;
	vyHostDisplay.SetForeColor(LabelColor);
	WHILE(label # NIL) DO vyHostDisplay.String(label.x + axe.x1, label.y + axe.y1, LabelFont, label.s);  label := label.next
	END
END PlotTheLabels;

PROCEDURE PlotTheAxe (axe: tAxe);
	VAR xmt, ymt, k : Coordinate;  tick: Tick;  r, r1, dr: Real;
PROCEDURE inaxe (x, y: Coordinate): BOOLEAN;
BEGIN
	IF axe.x1 < axe.x2 THEN IF (x < 0) OR (x > axe.x2 - axe.x1) THEN RETURN FALSE END
	ELSE IF (x > 0) OR (x < axe.x2 - axe.x1) THEN RETURN FALSE END END;
	IF axe.y1 < axe.y2 THEN IF (y < 0) OR (y > axe.y2 - axe.y1) THEN RETURN FALSE END
	ELSE IF (y > 0) OR (y < axe.y2 - axe.y1) THEN RETURN FALSE END END;
	RETURN TRUE
END inaxe;

PROCEDURE PlotTick (x, y: Coordinate;  pos, length: Coordinate);
BEGIN
	IF inaxe(x, y) THEN
		IF pos = rightfrom THEN vyHostDisplay.Line(x + axe.x1, y + axe.y1, x + length + axe.x1, y + axe.y1)
		ELSIF pos = leftfrom THEN vyHostDisplay.Line(x + axe.x1, y + axe.y1, x - length + axe.x1, y + axe.y1)
		ELSIF pos = over THEN vyHostDisplay.Line(x + axe.x1, y + axe.y1, x + axe.x1, y + length + axe.y1)
		ELSIF pos = under THEN vyHostDisplay.Line(x + axe.x1, y + axe.y1, x + axe.x1, y - length + axe.y1) END
	END
END PlotTick;

BEGIN
	vyHostDisplay.SetForeColor(AxeColor);  vyHostDisplay.Line(axe.x1, axe.y1, axe.x2, axe.y2);
	vyHostDisplay.SetForeColor(TicksColor);
	tick := axe.TickRoot;
	IF tick = NIL THEN RETURN END;
	WHILE(tick.next # NIL) DO
		PlotTick(tick.x, tick.y, tick.pos, TicksLength);
		k := 1;
		r := tick.r;
		dr := (tick.next.r - tick.r) / (axe.MinorTicks + 1);
		WHILE(k <= axe.MinorTicks) DO
			r1 := r + k * dr;
			axe.RtoXY(axe, r1, xmt, ymt);
			PlotTick(xmt, ymt, tick.pos, MinorTicksLength);
			INC(k)
		END;
		tick := tick.next
	END
END PlotTheAxe;

PROCEDURE CalcTheLabels (axe: tAxe);
	VAR  label: Label;  tick: Tick;  i, tpl, dsr: Coordinate;  (* adjusted for dsr *)
PROCEDURE TicksPerLabel (): INTEGER;
	VAR s1, s2: ARRAY 32 OF CHAR;  w1, w2, h1, h2: Coordinate;  i: INTEGER;
BEGIN
	s1 := "";   AppendRealToString(axe.r1, s1, axe.Format, axe.DigitsAfterPoint);
	s2 := "";   AppendRealToString(axe.r2, s2, axe.Format, axe.DigitsAfterPoint);
	vyHostDisplay.GetStringSize(LabelFont, s1, w1, h1, dsr);   vyHostDisplay.GetStringSize(LabelFont, s2, w2, h2, dsr);
	IF w2 > w1 THEN w1 := w2 END;  IF h2 > h1 THEN h1 := h2 END;
	i := 1;

	WHILE (i * axe.tdx < w1 + MinLabelToLabelDistance) & (i * axe.tdy < h1 + MinLabelToLabelDistance) & (i < 100) DO INC(i) END;  (* fof 020624 *)
	RETURN i
END TicksPerLabel;

BEGIN
	tpl := TicksPerLabel();
	NEW(label);  label.next := NIL;
	axe.LabelRoot := label ;
	tick := axe.TickRoot.next;
	IF tick = NIL THEN RETURN END;
	WHILE(tick.next # NIL) DO
		IF label.next = NIL THEN
			NEW(label.next);
			label.next.r := tick.r - 1
		END;

		label := label.next;
		label.pos := tick.pos;
		IF label.r # tick.r THEN
			label.r := tick.r;  label.s := "";
			AppendRealToString(label.r, label.s, axe.Format, axe.DigitsAfterPoint);
			vyHostDisplay.GetStringSize(LabelFont, label.s, label.w, label.h, label.dsr)
		END;
		axe.RtoXY(axe, label.r, label.x, label.y);  INC(label.y, label.dsr);
		IF label.pos = rightfrom THEN
			label.x := label.x + LabelDistance ;
			label.y := label.y - label.h DIV 2
		ELSIF label.pos = leftfrom THEN
			label.x := label.x - LabelDistance - label.w ;
			label.y := label.y - label.h DIV 2
		ELSIF label.pos = over  THEN
			label.x := label.x - label.w DIV 2 ;
			label.y := label.y + LabelDistance
		ELSIF label.pos = under THEN
			label.x := label.x - label.w DIV 2 ;
			label.y := label.y - LabelDistance - label.h
		END;
		InRect(axe.X, axe.Y, axe.W, axe.H, label.x + axe.x1, label.y + axe.y1, label.w, label.h);
		(* IF axe.X > label.x + axe.x1 THEN axe.X := label.x; END;
		IF axe.X + axe.W < label.x + label.w + axe.x1 THEN axe.W := label.x + label.w - axe.X END;
		IF axe.Y > label.y + axe.y1 THEN axe.Y := label.y; END;
		IF axe.H + axe.Y < label.y + label.h + axe.y1 THEN axe.H := label.y + label.h - axe.Y END;  *)
		i := tpl;
		WHILE(tick.next # NIL) & (i > 0) DO
			tick := tick.next;
			DEC(i)
		END
	END;
	label.next := NIL
END CalcTheLabels;


PROCEDURE CalcTheTicks (axe: tAxe);
	VAR tick: Tick;  i: INTEGER;  r: Real;

BEGIN
	IF axe.Orientation = vertical THEN
		IF Opposite THEN
			INC(axe.W, TicksLength)
		ELSE
			DEC (axe.X, TicksLength);  INC(axe.W, TicksLength)
		END
	ELSE
		IF Opposite THEN
			INC(axe.H, TicksLength)
		ELSE
			DEC (axe.Y, TicksLength);  INC(axe.H, TicksLength)
		END
	END;

	NEW(tick);  tick.next := NIL;
	axe.TickRoot := tick;
	i := 0;
	r := axe.r;
	WHILE (r < axe.r2) OR (equals(r, axe.r2)) DO
		r := axe.r + i * axe.dr;
		tick.r := r;
		axe.RtoXY(axe, r, tick.x, tick.y);
		IF axe.Orientation = vertical THEN
			IF Opposite THEN tick.pos := rightfrom ELSE tick.pos := leftfrom END
		ELSE
			IF Opposite THEN tick.pos := over ELSE tick.pos := under END
			(*
			IF vyHostDisplay.ycorrection = -1 THEN
			IF tick.pos = under THEN tick.pos := over
			ELSIF tick.pos = over THEN tick.pos := under
			END;

			END; *)

		END;

		INC(i);
		IF (r < axe.r2) OR (equals(r, axe.r2)) THEN
			IF tick.next = NIL THEN
				NEW(tick.next)
			END;
			tick := tick.next
		END
	END;
	tick.next := NIL
END CalcTheTicks;


PROCEDURE AutomaticMinorTicks (maxnumoflabels: Coordinate;  axe: tAxe);
	VAR dr: LONGREAL;  e2: INTEGER;
BEGIN
	dr := axe.dr;   SetExponent(dr, e2);
	IF equals(SHORT(dr), 1) THEN axe.MinorTicks := 9
	ELSIF equals(SHORT(dr), 2) THEN axe.MinorTicks := 1
	ELSIF equals(SHORT(dr), 5) THEN axe.MinorTicks := 4
	ELSE axe.MinorTicks := 1 END;
	IF axe.Orientation = horizontal THEN
		IF ABS((axe.x2 - axe.x1)) <  5 * maxnumoflabels * (axe.MinorTicks + 1)   THEN axe.MinorTicks := 1 END
	ELSE
		IF ABS((axe.y2 - axe.y1)) < 5 * maxnumoflabels * (axe.MinorTicks + 1)   THEN axe.MinorTicks := 1 END
	END
END AutomaticMinorTicks;

PROCEDURE Automaticdr (maxnumoflabels: Coordinate;  axe: tAxe);
	VAR z: LONGREAL;  e2: INTEGER;
BEGIN
	z := axe.r2 - axe.r1;   SetExponent(z, e2);
	z := axe.r2 - axe.r1;  axe.dr := SHORT( vyHost.TenL(e2));
	WHILE ENTIER(z / axe.dr)  < maxnumoflabels DO axe.dr := axe.dr / 10 END;
	WHILE ENTIER(z / axe.dr) > maxnumoflabels DO axe.dr := axe.dr * 10 END;
	WHILE ENTIER(z / axe.dr)  < maxnumoflabels DO axe.dr := axe.dr / 5 END;
	WHILE ENTIER(z / axe.dr) > maxnumoflabels DO axe.dr := axe.dr * 5 END;
	WHILE ENTIER(z / axe.dr)  < maxnumoflabels DO axe.dr := axe.dr / 2  END;
	WHILE ENTIER(z / axe.dr) > maxnumoflabels DO axe.dr := axe.dr * 2 END
END Automaticdr;

PROCEDURE Automaticr (axe: tAxe);
	VAR e1: LONGINT;
BEGIN e1 := ENTIER(axe.r1 / axe.dr);  axe.r := e1 * axe.dr;
	WHILE(axe.r > axe.r1) OR equals(axe.r, axe.r1) DO
		axe.r := axe.r - axe.dr
	END
END Automaticr;


PROCEDURE Init;
BEGIN
	vyHostDisplay.SetDisplayMode(vyHostDisplay.paint);
	vyHostDisplay.SetStringJustification(vyHostDisplay.left, vyHostDisplay.bottom)
END Init;

PROCEDURE UpdateAxis2dCoordinate (axe: tAxe);
BEGIN
	vyGraphBase.PointToPoint2d(axe.x1, axe.y1, axe.r1x, axe.r1y);
	vyGraphBase.PointToPoint2d(axe.x2, axe.y2, axe.r2x, axe.r2y)
END UpdateAxis2dCoordinate;

PROCEDURE InitPara (axe: tAxe): BOOLEAN;
	VAR q: Real;  i, maxnumoflabels, x1, y1, x2, y2: Coordinate;
BEGIN
	IF (axe.x1 = axe.x2) & (axe.y1 = axe.y2) THEN RETURN FALSE END;
	IF (axe.r1 > axe.r2) THEN
		q := axe.r1;  axe.r1 := axe.r2;  axe.r2 := q;
		i := axe.x1;  axe.x1 := axe.x2;  axe.x2 := i;  i := axe.y1;  axe.y1 := axe.y2;  axe.y2 := i
	ELSIF axe.r1 = axe.r2 THEN RETURN FALSE
	END;
	IF ABS((axe.x2 - axe.x1)) >= ABS((axe.y2 - axe.y1)) THEN
		axe.Orientation := horizontal;
		maxnumoflabels := ABS((axe.x2 - axe.x1)) DIV MinLabelRoom
	ELSE
		axe.Orientation := vertical;
		maxnumoflabels := ABS((axe.y2 - axe.y1))  DIV MinLabelRoom
	END;

	IF (TicksAutomatic) OR (axe.dr = 0) THEN Automaticdr(maxnumoflabels, axe) END;
	IF TicksAutomatic THEN
		Automaticr(axe);
		AutomaticMinorTicks(maxnumoflabels, axe)
	ELSE
		axe.r := axe.r1 - axe.dr;  axe.MinorTicks := MinorTicks
	END;
	IF axe.UsePaint2d THEN UpdateAxis2dCoordinate(axe) END;
	axe.RtoXY(axe, axe.r, x1, y1);  axe.RtoXY(axe, axe.r+axe.dr, x2, y2);
	axe.tdx := ABS(x2 - x1);  axe.tdy := ABS(y2 - y1);
	RETURN TRUE
END InitPara;


PROCEDURE Prepare* (Axe: tAxe;  x1, y1, x2, y2: Coordinate;  r1, r2, dr: Real);
	VAR label: Label;
BEGIN
	IF Axe = NIL THEN RETURN END;
	IF dr > 1000000 THEN EFormat := TRUE ELSE EFormat := FALSE END;
	IF UsePaint2d THEN
		Axe.UsePaint2d := TRUE;
		Axe.RtoXY := GetXYbyR2
	ELSE
		Axe.RtoXY := GetXYbyR;
		Axe.UsePaint2d := FALSE
	END;
	Axe.LabelRoot := NIL;  Axe.TickRoot := NIL;
	Axe.Format := EFormat;  Axe.DigitsAfterPoint := DigitsAfterPoint;
	Axe.x1 := x1;  Axe.x2 := x2;  Axe.y1 := y1;  Axe.y2 := y2;
	Axe.r1 := r1;  Axe.r2 := r2;  Axe.dr := dr;  Axe.r := r1;
	IF InitPara(Axe) = FALSE THEN RETURN  END;
	IF x1 < x2 THEN Axe.X := x1;  Axe.W := x2 - x1 ELSE   Axe.X := x2;  Axe.W := x1 - x2  END;
	IF y1 < y2 THEN Axe.Y := y1;  Axe.H := y2 - y1 ELSE Axe.Y := y2;  Axe.H := y1 - y2 END;
	CalcTheTicks(Axe);
	IF LabelsPlot THEN CalcTheLabels(Axe) ELSE NEW(Axe.LabelRoot);
	Axe.LabelRoot.next := NIL END;
	IF (Axe.x1 # Axe.x2) OR (Axe.y1 # Axe.y2) THEN TestTheLabels(Axe) END;
	IF x1 < x2 THEN Axe.X := x1;  Axe.W := x2 - x1 ELSE   Axe.X := x2;  Axe.W := x1 - x2  END;
	IF y1 < y2 THEN Axe.Y := y1;  Axe.H := y2 - y1 ELSE Axe.Y := y2;  Axe.H := y1 - y2 END;
	label := Axe.LabelRoot.next;
	WHILE label # NIL DO
		InRect(Axe.X, Axe.Y, Axe.W, Axe.H, label.x + Axe.x1, label.y + Axe.y1 - label.dsr, label.w, label.h);
		label := label.next
	END;
	RETURN
END Prepare;



PROCEDURE AxeTo* (Axe: tAxe;  x1, y1: Coordinate);
BEGIN
	Axe.x2 := Axe.x2 + x1 - Axe.x1;
	Axe.y2 := Axe.y2 + y1 - Axe.y1;
	Axe.x1 := x1;
	Axe.y1 := y1;
	IF Axe.UsePaint2d THEN UpdateAxis2dCoordinate(Axe) END
END AxeTo;

PROCEDURE RealTo* (Axe: tAxe;  r1: Real);
BEGIN

	Axe.r2 := Axe.r2 + (r1 - Axe.r1);
	Axe.r1 := r1;
	IF TicksAutomatic THEN
		WHILE (Axe.r > Axe.r1 - Axe.dr)  OR equals(Axe.r, Axe.r1 - Axe.dr)DO
			Axe.r := Axe.r - Axe.dr
		END;
		WHILE (Axe.r < Axe.r1 - Axe.dr) DO
			Axe.r := Axe.r + Axe.dr
		END
	ELSE
		Axe.r := r1 - Axe.dr
	END;
	CalcTheTicks(Axe);
	IF LabelsPlot THEN CalcTheLabels(Axe) END;
	IF (Axe.x1 # Axe.x2) OR (Axe.y1 # Axe.y2) THEN TestTheLabels(Axe) END
END RealTo;

PROCEDURE Plot* (Axe: tAxe);
BEGIN IF Axe # NIL THEN Init();  PlotTheAxe(Axe);  PlotTheLabels(Axe) END END Plot;

PROCEDURE ForcePlot* (x1, y1, x2, y2: Coordinate;  r1, r2, dr: Real);
	VAR axe: tAxe;
BEGIN NEW(axe);   Prepare(axe, x1, y1, x2, y2, r1, r2, dr);  Plot(axe);  axe := NIL END ForcePlot;


PROCEDURE PlotLabels* (Labels: BOOLEAN);
BEGIN LabelsPlot := Labels END PlotLabels;

PROCEDURE SetExpFormat* (b: BOOLEAN);
BEGIN	EFormat := b END SetExpFormat;

PROCEDURE SetColors* (labelcolor, axecolor, tickscolor: Color);
BEGIN LabelColor := labelcolor;  AxeColor := axecolor;  TicksColor := tickscolor END SetColors;

PROCEDURE SetLabelFont* (font : ARRAY OF CHAR);
BEGIN	COPY(font, LabelFont) 	END SetLabelFont;

PROCEDURE SetNumOfMinorTicks* (ticks: INTEGER);
BEGIN MinorTicks := ticks END SetNumOfMinorTicks;

PROCEDURE SetDigitsAfterPoint* (digits: INTEGER);
BEGIN DigitsAfterPoint := digits END SetDigitsAfterPoint;

PROCEDURE FlipAxesOrientation* (flip: BOOLEAN);
BEGIN Opposite := flip END FlipAxesOrientation;

PROCEDURE AutomaticTicks* (auto: BOOLEAN);
BEGIN TicksAutomatic := auto END AutomaticTicks;

(* PROCEDURE Test*;
VAR
axe: tAxe;
BEGIN
SetLabelFont("Syntax8b.Scn.Fnt");

vyHostDisplay.SetClipRect(0,0,1000,1000);
SetDigitsAfterPoint (1);

NEW(axe); Prepare(axe,100,100,500,100,-100,-10,40);
Plot(axe);
AxeTo(axe,100,300);
RealTo(axe,-101);
Plot(axe);
END Test; *)



BEGIN
	DefaultLabelColor := vyHostDisplay.black;  (* black *)
	DefaultAxeColor := vyHostDisplay.black;
	DefaultTicksColor := vyHostDisplay.black;
	LabelColor := DefaultLabelColor;
	LabelFont  := DefaultLabelFont;
	AxeColor := DefaultAxeColor;
	TicksColor := DefaultTicksColor;
	MinorTicks := DefaultMinorTicks;
	DigitsAfterPoint := DefaultDigitsAfterPoint;
	EFormat := DefaultEFormat;
	Opposite := FALSE;
	TicksAutomatic := TRUE;
	LabelsPlot := TRUE;
	UsePaint2d := TRUE;

END vyAxis.

