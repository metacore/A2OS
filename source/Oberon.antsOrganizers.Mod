(* ETH Oberon, Copyright 2000 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

(* fof: modification of Organizers from Hannes Marais to handle scalable Panels, needed by ants *)
(* this file is part of the ants distribution by Felix Friedrich, (c) 2002, above Copyright of the ETH applies. *)

(* Copyright notice:

This file is part of AntsInFields
Copyright (C) 1997-2002, Felix Friedrich

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
Report any problems as soon as possible to ants@AntsInFields.de
*)

MODULE antsOrganizers IN Oberon;   (** portable *)  (* jm 8.12.94 *)

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

Added functionality for scalable content of a Panel:

Gadgets.ChangeAttr fConstraints "<left> <top> <right> <bottom>" where left,top,rght, bottom are reals between 0 and 1 in Format 0.12345.
Gadgets.ChangeAttr fConstraints "0.1 0.1 0.8 0.8" ~ (* floating Constraints *) Gadget will be displayed from 10% to 80% of Panel vertically and horizontal.
x applies also:
Gadgets.ChangeAttr fConstraints "0.1 0.1 x x" Gadget will be displayed with upper left edge at point 10% 10% of Panel width and height.
IF right and left conincide then displayed centered in hor direction:
Gadgets.ChangeAttr fConstraints "0.5 x 0.5 x" Gadget will be displayed horizontally centered but free in ydir.
Gadgets.ChangeAttr fConstraints "0.5 0.2 0.5 x" Gadget will be displayed horizontally centered but free in ysize and fixed with top to 20%.

best is to test it yourself.

One can automatic apply constraints to a selection via:

antsOrganizers.MakeConstraints ltrb ~ fully scaled
antsOrganizers.MakeConstraints cccc ~ centered fixed
antsOrganizers.MakeConstraints xxrb ~ fixed to right bot
antsOrganizers.MakeConstraints xcrc ~ fixed to right and vert center
antsOrganizers.MakeConstraints xtrx ~ fixed to top right
antsOrganizers.MakeConstraints cxcb ~ fixed hor centered to bot
antsOrganizers.MakeConstraints ctcx ~ fixed hor centered to top
antsOrganizers.MakeConstraints ltxx ~ fixed to top left
antsOrganizers.MakeConstraints lcxc ~ fixed to right and vert center
antsOrganizers.MakeConstraints lxxb ~ fixed to right and vert center
antsOrganizers.MakeConstraints xxxx ~remove constraints
antsOrganizers.MakeConstraints ltrx ~ attached to top, scales in hor
antsOrganizers.MakeConstraints lxrb ~ attached to bot, scales in hor
antsOrganizers.MakeConstraints xtrb ~ attached to right, scales in ver
antsOrganizers.MakeConstraints ltxb ~ attached to right, scales in ver

see also: antsOrganizers.Panel

Felix Friedrich.



*)

IMPORT Objects, Display, Effects, Gadgets, Panels, Oberon, Strings, Out, Attributes, Fonts, Links, vyHost, Texts, EditTools,
	Documents, Desktops, antsPortability, vyHostTexts;

TYPE
	Task = POINTER TO TaskDesc;
	TaskDesc = RECORD (Oberon.TaskDesc)
		f: Display.Frame;
		w, h: INTEGER
	END;

	contentList = POINTER TO contentListDesc;
	contentListDesc = RECORD
		obj: Objects.Object;
		next: contentList;
	END;

CONST
	outofboundsmodify = 3;  DontCare = MAX( LONGINT );

VAR
	methods: Panels.Methods;  thispanel: Panels.Panel;  restrictive*: BOOLEAN;  fallbackfont: Fonts.Font;  globallist: contentList;
	inupdate: Panels.Panel;

	PROCEDURE Parse( s: ARRAY OF CHAR;  VAR l, t, r, b: LONGINT );
	VAR p: ARRAY 64 OF CHAR;
		i, j: INTEGER;

		PROCEDURE ReadNum( ): LONGINT;
		VAR x: LONGINT;
		BEGIN
			WHILE (s[i] # 0X) & (s[i] <= " ") DO INC( i ) END;
			IF s[i] = 0X THEN RETURN 0
			ELSIF ((s[i] < "0") OR (s[i] > "9")) & (s[i] # "-") THEN INC( i );  RETURN DontCare
			END;
			j := 0;
			WHILE (s[i] # 0X) & (s[i] > " ") DO p[j] := s[i];  INC( i );  INC( j ) END;
			p[j] := 0X;  Strings.StrToInt( p, x );  RETURN x
		END ReadNum;

	BEGIN
		i := 0;  l := ReadNum();  t := ReadNum();  r := ReadNum();  b := ReadNum()
	END Parse;

	PROCEDURE Round( x: LONGREAL ): LONGINT;
	BEGIN
		RETURN ENTIER( x + 0.5 )
	END Round;

	PROCEDURE fParse( pw, ph: INTEGER;  w, h: INTEGER;  s: ARRAY OF CHAR;  VAR l, t, r, b: LONGINT );
	VAR p: ARRAY 64 OF CHAR;
		i, j: INTEGER;  xr, yr, x2r, y2r: LONGREAL;

		PROCEDURE ReadNum( ): LONGREAL;
		VAR x: LONGREAL;
		BEGIN
			WHILE (s[i] # 0X) & (s[i] <= " ") DO INC( i ) END;
			IF s[i] = 0X THEN RETURN 0
			ELSIF ((s[i] < "0") OR (s[i] > "9")) & (s[i] # "-") & (s[i] # ".") THEN INC( i );  RETURN MAX( LONGREAL )
			END;
			j := 0;
			WHILE (s[i] # 0X) & (s[i] > " ") DO p[j] := s[i];  INC( i );  INC( j ) END;
			p[j] := 0X;  Strings.StrToReal( p, x );   (* Out.String("p = "); Out.String(p); Out.Ln;  *) RETURN x
		END ReadNum;

	BEGIN
		i := 0;  xr := ReadNum();  yr := ReadNum();  x2r := ReadNum();  y2r := ReadNum();
		IF (xr = MAX( LONGREAL )) THEN l := DontCare ELSE l := Round( pw * xr );  END;
		IF (yr = MAX( LONGREAL )) THEN t := DontCare;  ELSE t := Round( ph * yr );  END;
		IF (x2r = MAX( LONGREAL )) THEN r := DontCare;  ELSE r := pw - Round( pw * x2r ) END;
		IF (y2r = MAX( LONGREAL )) THEN b := DontCare;  ELSE b := ph - Round( ph * y2r );  END;
		IF (xr = x2r) & (xr # MAX( LONGREAL )) THEN  (* center hor *)
			l := Round( pw * xr ) - w DIV 2;  r := pw - Round( pw * x2r ) - w DIV 2;
		END;
		IF (yr = y2r) & (yr # MAX( LONGREAL )) THEN  (* center ver *)
			t := Round( ph * yr ) - h DIV 2;  b := ph - Round( ph * y2r ) - h DIV 2;
		END;
		IF t < 0 THEN t := 0 END;
		IF l < 0 THEN l := 0 END;
		IF r < 0 THEN r := 0 END;
		IF b < 0 THEN b := 0 END;
	END fParse;

	PROCEDURE HasConstraints*( f: Display.Frame;  pw, ph: INTEGER;  VAR l, t, r, b: LONGINT ): BOOLEAN;
	VAR A: Objects.AttrMsg;
	BEGIN
		IF (f.W = 1) & (f.H = 1) THEN RETURN FALSE END;
		A.id := Objects.get;  A.name := "Constraints";  A.res := -1;  f.handle( f, A );
		IF (A.res >= 0) & (A.class = Objects.String) & (A.s # "") THEN Parse( A.s, l, t, r, b );  RETURN TRUE END;
		A.id := Objects.get;  A.name := "fConstraints";  A.res := -1;  f.handle( f, A );
		IF (A.res >= 0) & (A.class = Objects.String) & (A.s # "") THEN fParse( pw, ph, f.W, f.H, A.s, l, t, r, b );  RETURN TRUE END;
		RETURN FALSE;
	END HasConstraints;

	PROCEDURE SolveGadget*( PW, PH: INTEGER;  f: Display.Frame;  l, t, r, b: LONGINT;  VAR X, Y, W, H: INTEGER );
	VAR ll, tt, rr, bb: LONGINT;
	BEGIN
		IF l = DontCare THEN ll := f.X
		ELSIF l >= 0 THEN ll := l
		ELSE ll := PW + l
		END;
		IF r = DontCare THEN rr := f.X + f.W - 1
		ELSIF r >= 0 THEN rr := PW - 1 - r
		ELSE rr := ABS( r )
		END;
		IF t = DontCare THEN tt := f.Y + f.H - 1
		ELSIF t >= 0 THEN tt := -t
		ELSE tt := -PH - t
		END;
		IF b = DontCare THEN bb := f.Y
		ELSIF b >= 0 THEN bb := -PH + 1 + b
		ELSE bb := b
		END;

		IF (l = DontCare) & (r # DontCare) THEN ll := rr - f.W + 1
		ELSIF (l # DontCare) & (r = DontCare) THEN rr := ll + f.W - 1
		END;
		IF (t = DontCare) & (b # DontCare) THEN tt := bb + f.H - 1
		ELSIF (t # DontCare) & (b = DontCare) THEN bb := tt - f.H + 1
		END;
		X := SHORT( ll );  Y := SHORT( bb );

		IF Gadgets.lockedsize IN f( Gadgets.Frame ).state THEN W := f.W;  H := f.H
		ELSE W := SHORT( rr ) - X + 1;  H := SHORT( tt ) - Y + 1
		END
	END SolveGadget;

	PROCEDURE Solve*( F: Panels.Panel;  dX, dY, W, H: INTEGER;  pw, ph: INTEGER;  mode: INTEGER );
	VAR f: Display.Frame;  l, t, r, b: LONGINT;  M: Display.ModifyMsg;
	BEGIN
		f := F.dsc;
		WHILE f # NIL DO
			IF HasConstraints( f, F.W, F.H, l, t, r, b ) THEN
				SolveGadget( W, H, f, l, t, r, b, M.X, M.Y, M.W, M.H );
				IF (M.W > 0) & (M.H > 0) THEN
					INC( M.X, dX );  INC( M.Y, dY );  M.id := outofboundsmodify;  M.F := f;  M.mode := Display.state;  M.dX := M.X - f.X;
					M.dY := M.Y - f.Y;  M.dW := M.W - f.W;  M.dH := M.H - f.H;  Objects.Stamp( M );  M.res := -1;  M.dlink := NIL;
					M.x := 0;  M.y := 0;  f.handle( f, M )
				END
			END;
			f := f.next
		END;
	END Solve;

	PROCEDURE minSize( F: Display.Frame;  VAR w, h: INTEGER ): BOOLEAN;
	VAR W, H: LONGINT;
	BEGIN
		Attributes.GetInt( F, "minSizeX", W );  Attributes.GetInt( F, "minSizeY", H );  w := SHORT( W );  h := SHORT( H );
		IF (w > 0) & (h > 0) THEN RETURN TRUE ELSE RETURN FALSE END;
	END minSize;

	PROCEDURE toMin( t: Oberon.Task );
	BEGIN
		WITH t: Task DO ResizeTo( t.f( Gadgets.Frame ), t.w, t.h );
		END;
		Oberon.Remove( t );
	END toMin;

	PROCEDURE InstallSizer( F: Display.Frame;  w, h: INTEGER );
	VAR task: Task;
	BEGIN
		NEW( task );  task.w := w;  task.h := h;  task.f := F;  task.handle := toMin;  task.time := Oberon.Time();  Oberon.Install( task );
	END InstallSizer;

	PROCEDURE Max( x, y: INTEGER ): INTEGER;
	BEGIN
		IF x > y THEN RETURN x ELSE RETURN y END;
	END Max;

	PROCEDURE Handler*( F: Objects.Object;  VAR M: Objects.ObjMsg );
	VAR l, t, r, b: LONGINT;  oX, oY, oW, oH, mode: INTEGER;  f: Objects.Object;  A: Display.ModifyMsg;  hadselection: BOOLEAN;
		fontname: ARRAY 256 OF CHAR;
		bool: BOOLEAN;  stdFont: Fonts.Font;
	BEGIN
		WITH F: Panels.Panel DO
			IF M IS Display.ModifyMsg THEN
				WITH M: Display.ModifyMsg DO
					IF (M.F = F) & ((M.W # F.W) OR (M.H # F.H)) THEN
						Attributes.GetBool( F, "noScaledFonts", bool );
						(*
					IF (minSize(F, oW, oH)) THEN
						IF  ((M.W < oW)) OR (M.H < oH) THEN
							IF restrictive THEN
								InstallSizer(F, Max(M.W, oW), Max(M.H, oH));
							ELSIF (F.W >= oW) & (F.H >= oH) THEN
								Out.String("You have underrun the minimal framesize");  Out.Ln;
								Out.String("Execute antsOrganizers.ToMinSize * to readjust");  Out.Ln;
							END;
						END;
					END;
					*)

						IF ((M.dH = 0) OR (M.Y + M.H = F.Y + F.H)) & ((M.dW = 0) OR (M.X = F.X)) THEN
							Panels.PanelHandler( F, M );  Solve( F, M.X - F.X, M.Y + M.H - F.Y - F.H, M.W, M.H, M.W, M.H, M.mode );
							Panels.PanelHandler( F, M );
						ELSE
							mode := M.mode;  M.mode := Display.state;  Panels.PanelHandler( F, M );
							Solve( F, M.X - F.X, M.Y + M.H - F.Y - F.H, M.W, M.H, M.W, M.H, M.mode );
							IF mode = Display.display THEN Gadgets.Update( F ) END
						END;
						IF ~bool THEN TryMakeFontSizes( F ) END;
					ELSIF Panels.IsChild( F, M.F ) & (M.id # outofboundsmodify) THEN  (* not send to self *)
						oW := M.F.W;  oH := M.F.H;
						M.F.W := M.W;  M.F.H := M.H;   (* for floating constraints, might accept resize actions *)
						IF HasConstraints( M.F, F.W, F.H, l, t, r, b ) THEN
							M.F.W := oW;  M.F.H := oH;  oX := M.F.X;  oY := M.F.Y;  oW := M.F.W;  oH := M.F.H;  M.F.X := M.X;
							M.F.Y := M.Y;  M.F.W := M.W;  M.F.H := M.H;  SolveGadget( F.W, F.H, M.F, l, t, r, b, M.X, M.Y, M.W, M.H );
							M.F.X := oX;  M.F.Y := oY;  M.F.W := oW;  M.F.H := oH;  M.dX := M.X - M.F.X;  M.dY := M.Y - M.F.Y;
							M.dW := M.W - M.F.W;  M.dH := M.H - M.F.H;
						ELSE M.F.W := oW;  M.F.H := oH;
						END;
						Panels.PanelHandler( F, M );
					ELSE Panels.PanelHandler( F, M )
					END;
				END

			ELSIF M IS Gadgets.UpdateMsg THEN  (* when an attribute changes *)
				WITH M: Gadgets.UpdateMsg DO
					Panels.PanelHandler( F, M );   (* forward *)
					f := M.obj;
					IF (f IS Gadgets.Frame) & Panels.IsChild( F, f( Gadgets.Frame ) ) THEN
						WITH f: Gadgets.Frame DO
							IF HasConstraints( f, F.W, F.H, l, t, r, b ) THEN
								SolveGadget( F.W, F.H, f, l, t, r, b, A.X, A.Y, A.W, A.H );
								IF (A.X # f.X) OR (A.Y # f.Y) OR (A.W # f.W) OR (A.H # f.H) THEN
									A.id := outofboundsmodify;  A.F := f;  A.mode := Display.display;  A.dX := A.X - f.X;  A.dY := A.Y - f.Y;
									A.dW := A.W - f.W;  A.dH := A.H - f.H;  Display.Broadcast( A )
								END
							END
						END
					END
				END
			ELSIF M IS Objects.AttrMsg THEN
				WITH M: Objects.AttrMsg DO
					IF (M.id = Objects.get) & (M.name = "Gen") THEN M.s := "antsOrganizers.NewPanel";  M.class := Objects.String;  M.res := 0
					ELSIF (M.id = Objects.set) & (M.name = "Locked") THEN Panels.PanelHandler( F, M );  EXCL( F.state, Gadgets.lockedsize )
					ELSE Panels.PanelHandler( F, M )
					END
				END
			ELSIF M IS Display.SelectMsg THEN
				hadselection := (M( Display.SelectMsg ).sel # NIL );  Panels.PanelHandler( F, M );
				IF (~hadselection) & (M( Display.SelectMsg ).sel # NIL ) THEN M( Display.SelectMsg ).F := F;  thispanel := F;  END;
			ELSIF M IS Display.DisplayMsg THEN
				stdFont := Fonts.Default;  Attributes.GetString( F, "Font", fontname );
				IF (fontname # "") & (Fonts.This( fontname ) # NIL ) THEN Fonts.Default := Fonts.This( fontname );  END;
				Panels.PanelHandler( F, M );  Fonts.Default := stdFont;
			ELSIF M IS Oberon.InputMsg THEN
				stdFont := Fonts.Default;  fallbackfont := stdFont;  Attributes.GetString( F, "Font", fontname );
				IF (fontname # "") & (Fonts.This( fontname ) # NIL ) THEN Fonts.Default := Fonts.This( fontname );  END;
				Panels.PanelHandler( F, M );  Fonts.Default := stdFont;
			ELSE Panels.PanelHandler( F, M )
			END
		END
	END Handler;

	PROCEDURE makefontsize( t: Oberon.Task );
	BEGIN
		WITH t: Task DO
			MakeFontSizes( t.f );
			IF inupdate = t.f THEN inupdate := NIL END;
			Oberon.Remove( t );
		END;
	END makefontsize;

	PROCEDURE TryMakeFontSizes*( F: Panels.Panel );
	VAR fontsizetask: Task;
	BEGIN
		IF ~(F = inupdate) THEN
			inupdate := F;  NEW( fontsizetask );  fontsizetask.f := F;  fontsizetask.time := Oberon.Time();
			fontsizetask.handle := makefontsize;  Oberon.Install( fontsizetask );
		END;
	END TryMakeFontSizes;


(*PROCEDURE RestoreBackGround (F: Panels.Panel; x, y: INTEGER; R: Display3.Mask);
BEGIN
Panels.methods.RestoreBackGround(F, x, y, R);
Display3.Line(R, Display.FG, Display.solid, x + 1, y + F.H - 11, x + 10, y + F.H - 2, 1, Display.replace);
Display3.Line(R, Display.BG, Display.solid, x + 1, y + F.H - 12, x + 10, y + F.H - 3, 1, Display.replace)
END RestoreBackGround;*)

	PROCEDURE InsertChild( F: Panels.Panel;  f: Display.Frame;  u, v: INTEGER );
	VAR l, t, r, b: LONGINT;  x, y, w, h: INTEGER;
	BEGIN
		IF HasConstraints( f, F.W, F.H, l, t, r, b ) THEN
			SolveGadget( F.W, F.H, f, l, t, r, b, x, y, w, h );
			IF (w > 0) & (h > 0) THEN u := x;  v := y;  f.W := w;  f.H := h;  END
		END;
		Panels.methods.InsertChild( F, f, u, v )
	END InsertChild;

	PROCEDURE TrackMouse( F: Panels.Panel;  VAR M: Oberon.InputMsg );
	VAR T: Display.Frame;  x, y, t, u, v: INTEGER;  d: LONGINT;  Fdlink, Mdlink: Objects.Object;  flags: SET;
	BEGIN
		x := M.x + F.X;  y := M.y + F.Y;  t := y + F.H - 1;  T := Panels.ThisChild( F, x, y, M.X, M.Y );

		IF T # NIL THEN
			Effects.SetSnap( x, t, F.grid, F.grid );
			IF HasConstraints( T, F.W, F.H, d, d, d, d ) THEN  (* simulated a locked environment *)
				flags := F.state;  INCL( F.state, Gadgets.lockedcontents );  Panels.ToChild( F, T, x, y, M );  F.state := flags
			ELSE Panels.ToChild( F, T, x, y, M )
			END;
			Effects.SetSnap( 0, 0, 1, 1 )
		END;

		IF M.res < 0 THEN
			Effects.SetSnap( x, t, F.grid, F.grid );
			IF 2 IN M.keys THEN  (* left *)
				IF ~(Panels.noinsert IN F.state0) THEN F.do.TrackCaret( F, M ) END
			ELSIF 1 IN M.keys THEN  (* middle *)
				IF (T # NIL ) & (Gadgets.selected IN T( Gadgets.Frame ).state) THEN
					WITH T: Gadgets.Frame DO
						IF Effects.InCorner( M.X, M.Y, x + T.X, t + T.Y, T.W, T.H ) & ~(Gadgets.lockedsize IN T.state) THEN
							u := M.x;  v := M.y;  M.x := x;  M.y := t;  Fdlink := F.dlink;  Mdlink := M.dlink;  F.dlink := M.dlink;  M.dlink := F;
							Gadgets.SizeFrame( T, M );  F.dlink := Fdlink;  M.dlink := Mdlink;  M.x := u;  M.y := v;  M.res := 0
						ELSE F.do.DragSelection( F, M )
						END
					END
				END
			ELSIF 0 IN M.keys THEN  (* right *)
				IF ~(Panels.noselect IN F.state0) THEN
					IF T = NIL THEN F.do.TrackSelection( F, M ) ELSE F.do.TrackSelectChild( F, M, T( Gadgets.Frame ) ) END
				END
			END;
			Effects.SetSnap( 0, 0, 1, 1 )
		END
	END TrackMouse;

	PROCEDURE InitPanel*( F: Panels.Panel );
	BEGIN
		Panels.InitPanel( F );  F.handle := Handler;  F.do := methods;
	END InitPanel;

	PROCEDURE NewPanel*;
	VAR p: Panels.Panel;
	BEGIN
		NEW( p );  InitPanel( p );  Objects.NewObj := p
	END NewPanel;

	PROCEDURE DoExchange*( F: Objects.Object );
	VAR locked: BOOLEAN;  updmsg: Display.DisplayMsg;  gumsg: Gadgets.UpdateMsg;
	BEGIN
		IF (F = NIL ) OR (~(F IS Panels.Panel)) THEN RETURN END;
		WITH F: Panels.Panel DO
			WITH F: Panels.Panel DO
				IF F.do # methods THEN  (* will become Organizer *)
					Attributes.SetInt( F, "minSizeX", F.W );  Attributes.SetInt( F, "minSizeY", F.H );  F.handle := Handler;  F.do := methods;
					EXCL( F.state, Gadgets.lockedsize );  Attributes.GetBool( F, "Locked", locked );  Attributes.SetBool( F, "Locked", locked );
					Solve( F, 0, 0, F.W, F.H, F.W, F.H, Display.state );  gumsg.obj := F;  gumsg.obj.slink := NIL;  gumsg.F := NIL;
					Display.Broadcast( gumsg );
					(*
				updmsg.F := F; updmsg.device := Display.screen; updmsg.id := Display.full; Display.Broadcast(updmsg);
				*)
					ResizeTo( F, F.W, F.H );  updmsg.F := F;  updmsg.device := Display.screen;  updmsg.id := Display.full;
					Display.Broadcast( updmsg );  Out.String( "antsOrganizers: changed to antsOrganizers.Panel" );  Out.Ln;
				ELSE  (* will become Panel *)
					ResetFontSizes( F );  DoToMin( F );  F.handle := Panels.PanelHandler;  F.do := Panels.methods;
					Attributes.GetBool( F, "Locked", locked );  Attributes.SetBool( F, "Locked", locked );  gumsg.obj := F;  gumsg.obj.slink := NIL;
					gumsg.F := NIL;  Display.Broadcast( gumsg );
					(*
				updmsg.F := F; updmsg.device := Display.screen; updmsg.id := Display.full; Display.Broadcast(updmsg);
				*)
					ResizeTo( F, F.W, F.H );  ResetFontSizes( F );  Out.String( "antsOrganizers: changed to Panels.Panel " );  Out.Ln;
					IF fallbackfont # NIL THEN Attributes.SetString( F, "Font", fallbackfont.name );
					ELSE Attributes.SetString( F, "Font", Fonts.Default.name );
					END;
				END;
			END;

		END;
	END DoExchange;

	PROCEDURE ToOrig*;
	BEGIN
		ResetFontSizes( Gadgets.context );  DoToMin( Gadgets.context );
	END ToOrig;


(* Make a normal panel into a organizer, and vice versa *)
	PROCEDURE Exchange*;
	VAR F: Objects.Object;
	BEGIN
		IF Oberon.Pointer.on THEN F := Oberon.MarkedFrame();  DoExchange( F );  END
	END Exchange;

	PROCEDURE ExchangeThis*;
	BEGIN
		DoExchange( Gadgets.context );
	END ExchangeThis;

	PROCEDURE SetLockedContent*;   (* lock content but not size *)
	VAR F: Display.Frame;  updmsg: Display.DisplayMsg;  gumsg: Gadgets.UpdateMsg;
	BEGIN
		IF Oberon.Pointer.on THEN
			F := Oberon.MarkedFrame();
			IF (F # NIL ) & (F IS Gadgets.Frame) THEN
				WITH F: Gadgets.Frame DO
					Attributes.SetBool( F, "Locked", TRUE );  EXCL( F.state, Gadgets.lockedsize );  gumsg.obj := F;  gumsg.obj.slink := NIL;
					gumsg.F := NIL;  Display.Broadcast( gumsg );  updmsg.F := F;  updmsg.device := Display.screen;
					updmsg.id := Display.full;  Display.Broadcast( updmsg );
				END
			END
		END
	END SetLockedContent;


(* -----------------  font sizes  ------------------ *)

	PROCEDURE SplitFontName( fn: ARRAY OF CHAR;  VAR i, j, size: INTEGER );   (* from EditTools.Mod *)
	VAR k: INTEGER;
	BEGIN
		i := 0;  size := 0;
		WHILE (fn[i] # 0X) & ((fn[i] < "0") OR ("9" < fn[i])) DO INC( i ) END;
		j := i;
		WHILE ("0" <= fn[j]) & (fn[j] <= "9") DO INC( j ) END;
		k := i;
		WHILE k < j DO size := size * 10 + ORD( fn[k] ) - 30H;  INC( k ) END
	END SplitFontName;

	PROCEDURE CombineFontName( prefix, suffix: ARRAY OF CHAR;  i, j, size: INTEGER;  VAR fn: ARRAY OF CHAR );   (* from EditTools.Mod *)
	VAR k: INTEGER;  ch: CHAR;
		dig: ARRAY 10 OF CHAR;
	BEGIN
		COPY( prefix, fn );  k := 0;
		IF size < 6 THEN size := 6
		ELSIF size > 128 THEN size := 128
		END;
		REPEAT dig[k] := CHR( size MOD 10 + 30H );  size := size DIV 10;  INC( k ) UNTIL size = 0;
		REPEAT DEC( k );  fn[i] := dig[k];  INC( i ) UNTIL k = 0;
		REPEAT ch := suffix[j];  fn[i] := ch;  INC( i );  INC( j ) UNTIL ch = 0X
	END CombineFontName;

	PROCEDURE ThisFont( name: ARRAY OF CHAR ): Fonts.Font;
	VAR fnt: Fonts.Font;
	BEGIN
		fnt := Fonts.This( name );
		IF (fnt = Fonts.Default) & (fnt.name # name) THEN RETURN NIL ELSE RETURN fnt END
	END ThisFont;

	PROCEDURE MakeFontSize*( F: Objects.Object;  ratio: LONGREAL;  offset: INTEGER );
	VAR Font, this: Objects.Name;  i, j, size, i1, j1, size1, newsize: INTEGER;  fnt: Fonts.Font;  fn: Objects.Name;
		updmsg: Display.DisplayMsg;  diff: LONGINT;
	BEGIN
		IF (ratio = 1) & (offset = 0) THEN  (* reset to original font *)
			Attributes.GetString( F, "OrigFont", Font );
			IF (Font # "") & (Fonts.This( Font ) # NIL ) THEN Attributes.SetString( F, "Font", Font );  END;
			Attributes.SetString( F, "OrigFont", "" );  RETURN
		ELSE

			Attributes.GetString( F, "OrigFont", Font );   (* get original font *)
			IF (Font = "") (* OR (Fonts.This(Font) = NIL) *) THEN  (* no original font ? take current as original font *)
				Attributes.GetString( F, "Font", Font );
				IF (Font = "") OR (Fonts.This( Font ) = NIL ) THEN  (* no current font ? take Fontsdefault as original font *)
					COPY( Fonts.Default.name, Font );
				END;
				Attributes.SetString( F, "OrigFont", Font );   (* set original font *)
			END;
			SplitFontName( Font, i, j, size );  newsize := SHORT( ENTIER( size * ratio + 0.5 ) ) + offset;  Attributes.GetString( F, "Font", this );
			SplitFontName( this, i1, j1, size1 );
			IF newsize # size1 THEN
				IF newsize < 6 THEN newsize := 6;
				ELSIF newsize > 60 THEN newsize := 60
				END;
				CombineFontName( Font, Font, i, j, newsize, fn );   (* fnt := ThisFont(fn);
			IF ThisFont(fn) # NIL THEN*)
				Attributes.SetString( F, "Font", fn );   (* set new font *)
				(*END;*)
			END;
		END;
	END MakeFontSize;

	PROCEDURE GetObjectsWithFont( F: Display.Frame;  VAR ll: contentList );
	VAR o: Objects.Object;  this: contentList;  font: Objects.Name;
	BEGIN
		o := F.dsc;
		IF ll = NIL THEN NEW( ll ) END;
		this := ll;
		WHILE (o # NIL ) DO
			Attributes.GetString( o, "Font", font );
			IF font # "" THEN
				(* Out.String("found: "); Out.String(font); Out.Ln; *)
				IF this.next = NIL THEN NEW( this.next ) END;
				this := this.next;  this.obj := o;
			END;
			o := o( Display.Frame ).next;
		END;
		this.next := NIL;
	END GetObjectsWithFont;

	PROCEDURE MakeFontSizes*( F: Objects.Object );
	VAR Font: ARRAY 256 OF CHAR;
		w, h: LONGINT;  i, j, size, newsize: INTEGER;  fnt: Fonts.Font;  fn: Objects.Name;  updmsg: Display.DisplayMsg;  diff: LONGINT;  ratio: LONGREAL;
		list: contentList;
	BEGIN
		IF (F # NIL ) & (F IS Panels.Panel) THEN
			Attributes.GetInt( F, "minSizeX", w );
			IF w = 0 THEN RETURN END;
			Attributes.GetInt( F, "minSizeY", h );
			IF h = 0 THEN RETURN END;
			ratio := F( Panels.Panel ).W / w;
			IF (F( Panels.Panel ).H / h) < ratio THEN ratio := F( Panels.Panel ).H / h END;
			Attributes.GetInt( F, "FontDiff", diff );  MakeFontSize( F, ratio, SHORT( diff ) );

			GetObjectsWithFont( F( Display.Frame ), globallist );  list := globallist.next;
			WHILE (list # NIL ) DO MakeFontSize( list.obj, ratio, SHORT( diff ) );  list := list.next;  END;

			updmsg.F := F( Display.Frame );  updmsg.device := Display.screen;  updmsg.id := Display.full;
			Display.Broadcast( updmsg );
			(* Attributes.SetLongReal(F,"FontRatio",ratio); *)
			(*
		Attributes.GetInt(F, "FontDiff", diff);
		Attributes.SetInt(F, "FontDiff", diff + by);
		*)
		END;
	END MakeFontSizes;

	PROCEDURE ResetFontSizes*( F: Objects.Object );
	VAR Font: ARRAY 256 OF CHAR;
		w, h: LONGINT;  i, j, size, newsize: INTEGER;  fnt: Fonts.Font;  fn: Objects.Name;  updmsg: Display.DisplayMsg;  diff: LONGINT;  ratio: LONGREAL;
		list: contentList;
	BEGIN
		IF (F # NIL ) & (F IS Panels.Panel) THEN
			MakeFontSize( F, 1, 0 );  Attributes.SetInt( F, "FontDiff", 0 );  GetObjectsWithFont( F( Display.Frame ), globallist );
			list := globallist.next;
			WHILE (list # NIL ) DO MakeFontSize( list.obj, 1, 0 );  list := list.next;  END;
			updmsg.F := F( Display.Frame );  updmsg.device := Display.screen;  updmsg.id := Display.full;
			Display.Broadcast( updmsg );

			(*
		Attributes.GetInt(F, "FontDiff", diff);
		Attributes.SetInt(F, "FontDiff", diff + by);
		*)
		END;
	END ResetFontSizes;

	PROCEDURE IncFontSizes*( F: Objects.Object;  by: INTEGER );
	VAR Font: ARRAY 256 OF CHAR;
		i, j, size: INTEGER;  fnt: Fonts.Font;  fn: Objects.Name;  updmsg: Display.DisplayMsg;  diff: LONGINT;
	BEGIN
		IF (F # NIL ) & (F IS Panels.Panel) THEN
			(*
		Attributes.GetString(F, "Font", Font);
		IF (Font = "") OR (Fonts.This(Font) = NIL) THEN COPY(Fonts.Default.name, Font) END;
		SplitFontName(Font, i, j, size);
		CombineFontName(Font, Font, i, j, size + by, fn);  fnt := ThisFont(fn);
		IF fnt # NIL THEN
			Attributes.SetString(F, "Font", fn);
		END;
		updmsg.F := F(Display.Frame);  updmsg.device := Display.screen;  updmsg.id := Display.full;  Display.Broadcast(updmsg);
		*)
			Attributes.GetInt( F, "FontDiff", diff );  Attributes.SetInt( F, "FontDiff", diff + by );  MakeFontSizes( F );
		END;
	END IncFontSizes;

	PROCEDURE FontSizeDiff*( F: Objects.Object ): INTEGER;
	VAR diff: LONGINT;
	BEGIN
		IF (F # NIL ) & (F IS Panels.Panel) THEN
			Attributes.GetInt( F, "FontDiff", diff );  RETURN -SHORT( diff );
			(*
		Attributes.GetString(F,"Font",Font);
		IF (Font="") OR (Fonts.This(Font) = NIL) THEN COPY(Fonts.Default.name,Font) END;
		SplitFontName(Font, i, j, size1);
		SplitFontName(Fonts.Default.name, i, j, size2);
		RETURN size2-size1;
		*)
		ELSE RETURN 0;
		END;
	END FontSizeDiff;

	PROCEDURE SetMinSize*;
	VAR F: Display.Frame;
	BEGIN
		IF Oberon.Pointer.on THEN
			F := Oberon.MarkedFrame();
			IF (F # NIL ) & (F IS Panels.Panel) THEN
				Attributes.SetInt( F, "minSizeX", F.W );  Attributes.SetInt( F, "minSizeY", F.H );  Out.String( "Set min sizes to " );  Out.Int( F.W, 5 );  Out.String( " , " );
				Out.Int( F.H, 5 );  Out.Ln;
			END;
		END;
	END SetMinSize;

	PROCEDURE ResizeTo( F: Gadgets.Frame;  W, H: INTEGER );
	VAR M: Display.ModifyMsg;
	BEGIN
		IF W > F.W THEN M.id := Display.extend;  ELSE M.id := Display.reduce END;
		M.mode := Display.display;  M.F := F;
		M.X := F.X;  M.Y := F.Y;   (* Same top coordinates *)
		M.dX := 0;  M.dY := 0;
		M.W := W;  M.H := H;   (* New size *)
		M.dW := W - F.W;  M.dH := H - F.H;  Display.Broadcast( M )
	END ResizeTo;

	PROCEDURE ToMinSize*;
	VAR F: Display.Frame;  w, h: LONGINT;
	BEGIN
		IF Oberon.Pointer.on THEN
			F := Oberon.MarkedFrame();
			IF (F # NIL ) & (F IS Panels.Panel) THEN
				Attributes.GetInt( F, "minSizeX", w );  Attributes.GetInt( F, "minSizeY", h );
				IF (w = 0) OR (h = 0) THEN RETURN END;
				Out.String( "Set min sizes to " );  Out.Int( w, 5 );  Out.String( " , " );  Out.Int( h, 5 );  Out.Ln;
				ResizeTo( F( Gadgets.Frame ), SHORT( w ), SHORT( h ) );
			END;
		END;
	END ToMinSize;

	PROCEDURE DoToMin( F: Objects.Object );
	VAR w, h: LONGINT;
	BEGIN
		IF (F # NIL ) & (F IS Panels.Panel) THEN
			Attributes.GetInt( F, "minSizeX", w );  Attributes.GetInt( F, "minSizeY", h );
			IF (w = 0) OR (h = 0) THEN RETURN END;
			(* Out.String("Set min sizes to ");  Out.Int(w, 5);  Out.String(" , ");  Out.Int(h, 5) ;  Out.Ln; *)
			ResizeTo( F( Gadgets.Frame ), SHORT( w ), SHORT( h ) );
		END;
	END DoToMin;

	PROCEDURE SetSize*;
	VAR F: Display.Frame;  w, h: INTEGER;  sc: Texts.Scanner;
	BEGIN
		IF Oberon.Pointer.on THEN
			F := Oberon.MarkedFrame();
			IF (F # NIL ) THEN
				Texts.OpenScanner( sc, Oberon.Par.text, Oberon.Par.pos );  Texts.Scan( sc );
				IF (sc.class = Texts.Int) THEN w := SHORT( sc.i );  ELSE RETURN END;
				Texts.Scan( sc );
				IF (sc.class = Texts.Int) THEN h := SHORT( sc.i );  ELSE RETURN END;
				ResizeTo( F( Gadgets.Frame ), w, h );
			END
		END;

	END SetSize;

	PROCEDURE IncPanelTextSizes*;
	VAR o, text: Objects.Object;  dsize: INTEGER;  sc: Texts.Scanner;
	TYPE mylist = POINTER TO RECORD
			next: mylist;
			text: Texts.Text
		END;
	VAR ll, prevl: mylist;
	BEGIN
		Texts.OpenScanner( sc, Oberon.Par.text, Oberon.Par.pos );  Texts.Scan( sc );
		IF (sc.class = Texts.Int) THEN dsize := SHORT( sc.i );  ELSE Out.String( "antsOrganizers.IncPanelTextSizes: number expected" );  Out.Ln;  END;
		o := Gadgets.context;
		IF (o = NIL ) OR (~(o IS Display.Frame)) THEN RETURN END;
		IncFontSizes( o, dsize );
	END IncPanelTextSizes;

	PROCEDURE ToggleVisibility*;
	VAR o: Objects.Object;  w, h: LONGINT;  sc: Texts.Scanner;
	BEGIN
		Texts.OpenScanner( sc, Oberon.Par.text, Oberon.Par.pos );  Texts.Scan( sc );
		IF (sc.class = Texts.String) OR (sc.class = Texts.Name) THEN
			o := Gadgets.FindObj( Gadgets.context, sc.s );
			IF (o # NIL ) & (o IS Gadgets.Frame) THEN
				WITH o: Gadgets.Frame DO
					IF o.W > 1 THEN Attributes.SetInt( o, "origWidth", o.W );  Attributes.SetInt( o, "origHeight", o.H );  ResizeTo( o, 1, 1 );
					ELSE Attributes.GetInt( o, "origWidth", w );  Attributes.GetInt( o, "origHeight", h );  ResizeTo( o, SHORT( w ), SHORT( h ) );
					END;
				END;
			END;
		END;
	END ToggleVisibility;

	PROCEDURE ReplaceSuffix( VAR name: ARRAY OF CHAR;  suffix: ARRAY OF CHAR );   (* replace suffix by stdsuffix will be appended *)
	VAR i, j, start, pos: LONGINT;
		name2: ARRAY 256 OF CHAR;
	BEGIN
		i := 0;  start := 0;  pos := LEN( name ) - 1;
		WHILE (name[i] # 0X) DO
			IF name[i] = antsPortability.PathChar THEN start := i + 1 END;
			INC( i );
		END;
		i := start;  j := 0;
		WHILE (name[i] # 0X) DO
			name2[j] := name[i];  INC( j );
			IF name[i] = "." THEN pos := j;  END;
			INC( i )
		END;
		(* name[pos] := 0X; *)
		name2[pos] := 0X;  Strings.Append( name2, "" );  Strings.Append( name2, suffix );  COPY( name2, name );
	END ReplaceSuffix;

	PROCEDURE OpenHelp*;
	VAR res: INTEGER;  obj: Objects.Object;
		name: ARRAY 256 OF CHAR;
	BEGIN
		obj := Gadgets.context;
		WHILE (obj # NIL ) & ~(obj IS Documents.Document) DO obj := obj.dlink END;
		IF obj # NIL THEN COPY( obj( Documents.Document ).name, name );  ReplaceSuffix( name, "Help" );  ELSE name := "Help.Panel" END;
		vyHost.CallWString( "Desktops.OpenDoc", name, FALSE , res );
	END OpenHelp;

	PROCEDURE ViewObjectCopy*;
	VAR o: Objects.Object;  sc: Texts.Scanner;  copymsg: Objects.CopyMsg;  unm: Desktops.UpdateNameMsg;
		name: ARRAY 256 OF CHAR;
	BEGIN
		Texts.OpenScanner( sc, Oberon.Par.text, Oberon.Par.pos );  Texts.Scan( sc );
		IF (sc.class = Texts.String) OR (sc.class = Texts.Name) THEN
			o := Gadgets.FindObj( Gadgets.context, sc.s );  Oberon.Defocus;
			IF (o # NIL ) & (o IS Gadgets.Frame) THEN
				Objects.Stamp( copymsg );  o.handle( o, copymsg );
				IF (copymsg.obj # NIL ) & (copymsg.obj IS Gadgets.Frame) THEN
					vyHostTexts.InsertGadget( copymsg.obj );  unm.obj := vyHostTexts.NewDocument;
					IF unm.obj # NIL THEN
						name := "Copy of ";  Strings.Append( name, sc.s );  Strings.Append( name, " (resizeable)" );
						COPY( name, unm.obj( Documents.Document ).name );  Display.Broadcast( unm )
					END;
				END;
			END;
		END;
	END ViewObjectCopy;

(*
ltrb
ltrb: Scaled to left, top, right and bottom
ltxx: adjusted to left top etc.
lcrc: adjusted to vertical center, scaled in hor dir
lcxc: adjusted to left center
...
xxxx remove adjust
*)

	PROCEDURE MakeConstraints*;
	VAR M: Display.SelectMsg;  obj: Objects.Object;  X, Y, W, H, x, y, w, h: INTEGER;
		xstr, ystr, wstr, hstr, str, name: ARRAY 64 OF CHAR;
		d: Display.DisplayMsg;  S: Attributes.Scanner;
	CONST left = 0;  top = 1;  right = 2;  bottom = 3;
	BEGIN
		Attributes.OpenScanner( S, Oberon.Par.text, Oberon.Par.pos );  Attributes.Scan( S );  name := "";
		IF S.class = Attributes.String THEN COPY( S.s, name )
		ELSIF S.class = Attributes.Name THEN COPY( S.s, name )
		END;
		IF Strings.Length( name ) # 4 THEN Out.String( "MakeConstraints: expecting String with 4 chars (x,c or o)" );  Out.Ln;  RETURN END;

		M.id := Display.get;  M.F := NIL;  M.sel := NIL;  M.obj := NIL;  M.time := -1;  Display.Broadcast( M );
		IF M.time # -1 THEN
			obj := M.obj;
			IF (M.F # NIL ) & (M.F = thispanel) THEN
				X := M.F.X;  Y := M.F.Y;  W := M.F.W;  H := M.F.H;
				WHILE obj # NIL DO
					IF obj IS Display.Frame THEN
						WITH obj: Display.Frame DO
							x := obj.X;  y := obj.Y;  w := obj.W;  h := obj.H;
							IF (w > 1) & (h > 1) THEN  (* apply to visible objects only (Assuming size 1 to be invisble) *)
								y := -y - h;  w := x + w;  h := y + h;
								(* analyze input *)
								IF name[left] = "x" THEN xstr := "x"
								ELSIF name[left] = "c" THEN Strings.RealToFixStr( (x + w) / 2 / W, xstr, 0, 10, 0 );
								ELSE Strings.RealToFixStr( x / W, xstr, 0, 10, 0 );
								END;
								IF name[top] = "x" THEN ystr := "x"
								ELSIF name[top] = "c" THEN Strings.RealToFixStr( (y + h) / 2 / H, ystr, 0, 10, 0 );
								ELSE Strings.RealToFixStr( y / H, ystr, 0, 10, 0 );
								END;
								IF name[right] = "x" THEN wstr := "x"
								ELSIF name[right] = "c" THEN Strings.RealToFixStr( (x + w) / 2 / W, wstr, 0, 10, 0 );
								ELSE Strings.RealToFixStr( w / W, wstr, 0, 10, 0 );
								END;
								IF name[bottom] = "x" THEN hstr := "x"
								ELSIF name[bottom] = "c" THEN Strings.RealToFixStr( (y + h) / 2 / H, hstr, 0, 10, 0 );
								ELSE Strings.RealToFixStr( h / H, hstr, 0, 10, 0 );
								END;
								str := "";  Strings.Append( str, xstr );  Strings.Append( str, " " );  Strings.Append( str, ystr );
								Strings.Append( str, " " );  Strings.Append( str, wstr );  Strings.Append( str, " " );  Strings.Append( str, hstr );
								Attributes.SetString( obj, "fConstraints", str );  Out.String( "Setting constraint: " );  Out.String( str );  Out.Ln;
							END;
						END;
					ELSE
					END;

					obj := obj.slink
				END;
				d.F := M.F;  d.id := Display.display;  Display.Broadcast( d );
			END;
		END
	END MakeConstraints;

	PROCEDURE Refresh*;
	VAR updmsg: Display.DisplayMsg;
	BEGIN
		updmsg.F := NIL;  updmsg.device := Display.screen;  updmsg.id := Display.full;  Display.Broadcast( updmsg );
	END Refresh;

BEGIN
	NEW( methods );  methods^ := Panels.methods^;
	(*methods.RestoreBackGround := RestoreBackGround;*) methods.InsertChild := InsertChild;
	methods.TrackMouse := TrackMouse;  restrictive := FALSE;
END antsOrganizers.

antsOrganizers.SetMinSize ~
System.Free antsOrganizers ~
Gadgets.Insert antsOrganizers.NewPanel ~
Gadgets.Insert Button ~
antsOrganizers.MakeConstraints lcxc~

antsOrganizers.Exchange
Gadgets.ChangeAttr Constraints "8 8 20 20"~
Gadgets.ChangeAttr Constraints "x 2 x 2"~
Gadgets.ChangeAttr Constraints "104 8 8 x"~
Gadgets.ChangeAttr Constraints "8 36 8 8"~

Gadgets.ChangeAttr Constraints "10 50 10 10"~

Gadgets.ChangeAttr fConstraints "0.4 0.4 0.5 0.5"~
antsOrganizers.Panel
Gadgets.Insert Panels.NewPanel ~
antsToolbox.Mod

antsOrganizers.MakeConstraints ltrb ~ fully scaled
antsOrganizers.MakeConstraints cccc ~ centered fixed
antsOrganizers.MakeConstraints xxrb ~ fixed to right bot
antsOrganizers.MakeConstraints xcrc ~ fixed to right and vert center
antsOrganizers.MakeConstraints xtrx ~ fixed to top right
antsOrganizers.MakeConstraints cxcb ~ fixed hor centered to bot
antsOrganizers.MakeConstraints ctcx ~ fixed hor centered to top
antsOrganizers.MakeConstraints ltxx ~ fixed to top left
antsOrganizers.MakeConstraints lcxc ~ fixed to right and vert center
antsOrganizers.MakeConstraints lxxb ~ fixed to right and vert center
antsOrganizers.MakeConstraints xxxx ~remove constraints
antsOrganizers.MakeConstraints ltrx ~ attached to top, scales in hor
antsOrganizers.MakeConstraints lxrb ~ attached to bot, scales in hor
antsOrganizers.MakeConstraints xtrb ~ attached to right, scales in ver
antsOrganizers.MakeConstraints ltxb ~ attached to right, scales in ver



testxxxx.Panel