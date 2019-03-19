MODULE antsContainers IN Oberon;
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




IMPORT Objects, Display, Gadgets, Panels, Oberon, vyLinks, aM := antsMessages;

CONST
	outofboundsmodify = 3;
TYPE

	SortList = POINTER TO SortListDesc;
	SortListDesc = RECORD (vyLinks.LinkDesc)
		pos: LONGINT;
		size: INTEGER;
		frames: vyLinks.Link
	END;

VAR
	Handler*: Objects.Handler;  lastframe: Objects.Object;

	PROCEDURE Next( l: SortList ): SortList;
	BEGIN
		IF l.link = NIL THEN RETURN NIL ELSE RETURN l.link( SortList ) END
	END Next;

	PROCEDURE InsertSorted( VAR list: SortList;  f: Display.Frame;  pos: LONGINT;  VAR size: INTEGER );
	VAR this, next: SortList;  insert: SortList;
	BEGIN
		IF list = NIL THEN NEW( list );  list.pos := pos;  list.size := size;  vyLinks.InsertObj( list.frames, f )
		ELSIF pos < list.pos THEN
			NEW( insert );  insert.pos := pos;  insert.size := size;  vyLinks.InsertObj( insert.frames, f );  insert.link := list;  list := insert
		ELSE
			this := list;
			WHILE this # NIL DO
				next := Next( this );
				IF this.pos = pos THEN vyLinks.InsertObj( this.frames, f );  size := this.size;  next := NIL
				ELSIF (next = NIL ) OR (next( SortList ).pos > pos) THEN
					NEW( insert );  insert.pos := pos;  insert.size := size;  vyLinks.InsertObj( insert.frames, f );  insert.link := next;
					this.link := insert;  next := NIL
				END;
				this := next
			END
		END
	END InsertSorted;

	PROCEDURE InitMsg( f: Display.Frame;  VAR msg: Display.ModifyMsg );
	BEGIN
		msg.X := f.X;  msg.Y := f.Y;  msg.H := f.H;  msg.W := f.W;  msg.dX := 0;  msg.dY := 0;  msg.dW := 0;  msg.dH := 0;
		msg.id := outofboundsmodify;  msg.mode := Display.display;  msg.F := f;  msg.res := -1
	END InitMsg;

	PROCEDURE ShiftTo( f: Display.Frame;  x, y: INTEGER );
	VAR msg: Display.ModifyMsg;
	BEGIN
		InitMsg( f, msg );  msg.dX := x - msg.X;  msg.dY := y - msg.Y;  msg.X := x;  msg.Y := y;
		IF (msg.dX # 0) OR (msg.dY # 0) THEN Display.Broadcast( msg ) END
	END ShiftTo;

	PROCEDURE Update( f: Display.Frame );
	VAR umsg: Display.DisplayMsg;
	BEGIN
		umsg.F := f;  umsg.id := Display.full;  umsg.device := Display.screen;  umsg.res := -1;  Display.Broadcast( umsg )
	END Update;

	PROCEDURE Resize*( f: Display.Frame;  w, h: INTEGER );
	VAR msg: Display.ModifyMsg;
	BEGIN
		IF (f.W = w) & (f.H = h) THEN RETURN END;
		InitMsg( f, msg );  msg.dW := w - msg.W;  msg.dH := h - msg.H;  msg.W := w;  msg.H := h;  msg.dY := -msg.dH;
		msg.Y := msg.Y + msg.dY;
		IF (msg.dW # 0) OR (msg.dH # 0) THEN Display.Broadcast( msg ) END;
		IF (msg.W # f.W) OR (msg.H # f.H) THEN f.handle( f, msg ) END  (* in case is not in Display *)
	END Resize;

	PROCEDURE SetPosition( f: Objects.Object;  posx, posy: LONGINT );
	VAR setc: Objects.AttrMsg;
	BEGIN
		setc.id := Objects.set;  setc.name := "PosX";  setc.res := -1;  setc.class := Objects.Int;  setc.i := posx;  f.handle( f, setc );
		setc.id := Objects.set;  setc.name := "PosY";  setc.res := -1;  setc.class := Objects.Int;  setc.i := posy;  f.handle( f, setc )
	END SetPosition;

	PROCEDURE GetPosition( f: Objects.Object;  VAR posx, posy: LONGINT ): BOOLEAN;
	VAR getc: Objects.AttrMsg;
	BEGIN
		getc.id := Objects.get;  getc.name := "PosX";  getc.res := -1;  f.handle( f, getc );
		IF getc.res < 0 THEN RETURN FALSE END;
		IF getc.class # Objects.Int THEN RETURN FALSE END;
		posx := getc.i;  getc.id := Objects.get;  getc.name := "PosY";  getc.res := -1;  f.handle( f, getc );
		IF getc.res < 0 THEN RETURN FALSE END;
		IF getc.class # Objects.Int THEN RETURN FALSE END;
		posy := getc.i;  RETURN TRUE
	END GetPosition;

	PROCEDURE MakePosLists( F: Display.Frame;  VAR xlist, ylist, undeflist: SortList );
	(* guarantees consitency of width and heights *)
	VAR c: Display.Frame;  w, h: INTEGER;  posx, posy: LONGINT;
	BEGIN
		c := F.dsc;
		WHILE c # NIL DO
			IF GetPosition( c, posx, posy ) THEN w := c.W;  InsertSorted( xlist, c, posx, w );  h := c.H;  InsertSorted( ylist, c, posy, h )
			ELSE w := 0;  InsertSorted( undeflist, c, 0, w )
			END;
			c := c.next
		END
	END MakePosLists;

	PROCEDURE GetPosList( VAR list: SortList;  pos: LONGINT ): vyLinks.Link;
	BEGIN
		WHILE list # NIL DO
			IF pos = list.pos THEN RETURN list.frames END;
			list := Next( list )
		END;
		RETURN NIL
	END GetPosList;

	PROCEDURE SizeOfFrame( ref: Display.Frame;  xlist, ylist: SortList;  VAR w, h: INTEGER );
	BEGIN
		w := 0;  h := 0;
		WHILE xlist # NIL DO
			INC( w, xlist.size );
			IF xlist.link # NIL THEN xlist := xlist.link( SortList ) ELSE xlist := NIL END
		END;
		WHILE ylist # NIL DO
			INC( h, ylist.size );
			IF ylist.link # NIL THEN ylist := ylist.link( SortList ) ELSE ylist := NIL END
		END;
		INC( w, 2 * ref( Panels.Panel ).borderW );  INC( h, 2 * ref( Panels.Panel ).borderW )
	END SizeOfFrame;

	PROCEDURE SameWidth( link: vyLinks.Link;  width: INTEGER );
	BEGIN
		WHILE link # NIL DO Resize( link.obj( Display.Frame ), width, link.obj( Display.Frame ).H );  link := link.link END
	END SameWidth;

	PROCEDURE SameHeight( link: vyLinks.Link;  height: INTEGER );
	BEGIN
		WHILE link # NIL DO Resize( link.obj( Display.Frame ), link.obj( Display.Frame ).W, height );  link := link.link END
	END SameHeight;

	PROCEDURE SameXPos( link: vyLinks.Link;  posx: INTEGER );
	BEGIN
		WHILE link # NIL DO ShiftTo( link.obj( Display.Frame ), posx, link.obj( Display.Frame ).Y );  link := link.link END
	END SameXPos;

	PROCEDURE SameYPos( link: vyLinks.Link;  posy: INTEGER );
	BEGIN
		WHILE link # NIL DO ShiftTo( link.obj( Display.Frame ), link.obj( Display.Frame ).X, posy );  link := link.link END
	END SameYPos;

	PROCEDURE FindItemWithPosition( f: Display.Frame;  posx, posy: LONGINT ): BOOLEAN;
	VAR o: Display.Frame;  tposx, tposy: LONGINT;
	BEGIN
		o := f.dsc;
		WHILE o # NIL DO
			IF GetPosition( o, tposx, tposy ) & (posx = tposx) & (posy = tposy) THEN RETURN TRUE END;
			o := o.next
		END;
		RETURN FALSE
	END FindItemWithPosition;

	PROCEDURE Max( x, y: LONGINT ): LONGINT;
	BEGIN
		IF x > y THEN RETURN x ELSE RETURN y END
	END Max;

	PROCEDURE NextFreePosition( f: Display.Frame;  VAR posx, posy: LONGINT );
	VAR x, y: LONGINT;  max: LONGINT;
	BEGIN
		x := posx;  y := posy;  max := Max( ABS( x ), ABS( y ) );
		WHILE FindItemWithPosition( f, x, y ) DO
			IF (x = max) & (y >= 0) & (y < max) THEN INC( y )
			ELSIF (y = max) & (x > -max) THEN DEC( x )
			ELSIF (x = -max) & (y > -max) THEN DEC( y )
			ELSIF (y = -max) & (x < max) THEN INC( x )
			ELSIF (x = max) & (y < -1) THEN INC( y )
			ELSIF (x = max) & (y = -1) THEN INC( max );  x := max;  y := 0
			ELSIF max = 0 THEN INC( max );  x := max;  y := 0
			END
		END;
		posx := x;  posy := y
	END NextFreePosition;

	PROCEDURE Position( ref: Panels.Panel;  center: Display.Frame );
	VAR X, Y, W, H: INTEGER;  xl, yl, ul: SortList;
	BEGIN
		MakePosLists( ref, xl, yl, ul );  SizeOfFrame( ref, xl, yl, W, H );  Resize( ref, W, H );  X := ref.borderW;
		Y := -ref.H + ref.borderW + 1;
		WHILE xl # NIL DO SameXPos( xl.frames, X );  INC( X, xl.size );  xl := Next( xl ) END;
		WHILE yl # NIL DO SameYPos( yl.frames, Y );  INC( Y, yl.size );  yl := Next( yl ) END
	END Position;

	PROCEDURE AdjustPosition( ref: Display.Frame;  center: Display.Frame );
	VAR x, y: LONGINT;  xl, yl, ul: SortList;  l: vyLinks.Link;
	BEGIN
		IF GetPosition( center, x, y ) THEN
			MakePosLists( ref, xl, yl, ul );  l := GetPosList( xl, x );  SameWidth( l, center.W );  xl.size := center.W;
			l := GetPosList( yl, y );  SameHeight( l, center.H );  yl.size := center.H
		END
	END AdjustPosition;

	PROCEDURE AdjustPositionFromL( ref: Display.Frame;  center: Display.Frame;  x, y: LONGINT );
	VAR xl, yl, ul: SortList;  l: vyLinks.Link;  W, H: INTEGER;
	BEGIN
		W := center.W;  H := center.H;  MakePosLists( ref, xl, yl, ul );  l := GetPosList( xl, x );
		IF l # NIL THEN W := xl.size END;
		l := GetPosList( yl, y );
		IF l # NIL THEN H := yl.size END;
		Resize( center, W, H )
	END AdjustPositionFromL;

	PROCEDURE FindCentral( o: Display.Frame ): Display.Frame;
	VAR obj: Display.Frame;  x, y: LONGINT;
	BEGIN
		obj := o.dsc;
		WHILE obj # NIL DO
			IF GetPosition( obj, x, y ) & (x = 0) & (y = 0) THEN RETURN obj END;
			obj := obj.next
		END;
		RETURN NIL
	END FindCentral;

	PROCEDURE handler( F: Objects.Object;  VAR M: Objects.ObjMsg );
	VAR o: Display.Frame;  posx, posy: LONGINT;
	BEGIN
		WITH F: Panels.Panel DO
			IF M IS Display.DisplayMsg THEN
				WITH M: Display.DisplayMsg DO
					IF (M.F = NIL ) OR (M.F = F) THEN Position( F, FindCentral( F ) ) END;
					Panels.PanelHandler( F, M );
				END;
			ELSIF M IS Display.ModifyMsg THEN
				WITH M: Display.ModifyMsg DO
					IF (M.F = F) & ((M.W # F.W) OR (M.H # F.H)) THEN
						IF M.id # outofboundsmodify THEN
							o := FindCentral( F );
							IF o # NIL THEN Resize( o, o.W + M.W - F.W, o.H + M.H - F.H );  AdjustPosition( F, o ) END
						END;
						Panels.PanelHandler( F, M )
					ELSIF Panels.IsChild( F, M.F ) & (M.id # outofboundsmodify) THEN  (* not send to self *)
						Panels.PanelHandler( F, M );  Resize( M.F, M.W, M.H );  o := FindCentral( F );
						IF o # NIL THEN AdjustPosition( F, M.F );  Position( F, o ) END
					ELSE Panels.PanelHandler( F, M )
					END;
				END;
			ELSIF M IS Gadgets.UpdateMsg THEN
				WITH M: Gadgets.UpdateMsg DO  (* when an attribute changes *)
					IF Panels.IsChild( F, M.F ) OR (M.F = F) THEN
						o := FindCentral( F );
						IF o # NIL THEN Position( F, o ) END
					END;
					Panels.PanelHandler( F, M );   (* forward *)
				END;
			ELSIF M IS Objects.AttrMsg THEN
				WITH M: Objects.AttrMsg DO
					IF (M.id = Objects.get) & (M.name = "Gen") THEN M.s := "antsContainers.NewPanel";  M.class := Objects.String;  M.res := 0
					ELSIF (M.id = Objects.set) & (M.name = "Locked") THEN Panels.PanelHandler( F, M );  EXCL( F.state, Gadgets.lockedsize )
					ELSIF (M.id = Objects.set) & ((M.name = "PosX") OR (M.name = "PosY")) THEN
						Panels.PanelHandler( F, M ) (* Gadgets.Update(F); *)
					ELSE Panels.PanelHandler( F, M )
					END
				END;
			ELSIF M IS Display.ConsumeMsg THEN
				WITH M: Display.ConsumeMsg DO
					Panels.PanelHandler( F, M );
					IF M.obj IS Display.Frame THEN
						IF Panels.IsChild( F, M.obj( Display.Frame ) ) THEN
							IF ~GetPosition( M.obj( Display.Frame ), posx, posy ) THEN
								posx := 0;  posy := 0;  NextFreePosition( F, posx, posy )
							END;
							AdjustPositionFromL( F, M.obj( Display.Frame ), posx, posy );
							SetPosition( M.obj( Display.Frame ), posx, posy );  Position( F, FindCentral( F ) );  Update( F )
						END
					END
				END;
			ELSE Panels.PanelHandler( F, M )
			END
		END
	END handler;

	PROCEDURE InitPanel*( F: Panels.Panel );
	BEGIN
		Panels.InitPanel( F );  F.handle := Handler
	END InitPanel;

	PROCEDURE NewPanel*;
	VAR p: Panels.Panel;
	BEGIN
		aM.cmd;  NEW( p );  InitPanel( p );  Objects.NewObj := p
	END NewPanel;

	PROCEDURE Exchange*;
	VAR F: Display.Frame;
	BEGIN
		IF Oberon.Pointer.on THEN
			F := Oberon.MarkedFrame();
			IF (F # NIL ) & (F IS Panels.Panel) THEN
				WITH F: Panels.Panel DO
					IF (F.handle # Handler) THEN F.handle := Handler;  Gadgets.Update( F )
					ELSE F.handle := Panels.PanelHandler;  Gadgets.Update( F )
					END
				END
			END
		END
	END Exchange;

	PROCEDURE myHandler( F: Objects.Object;  VAR M: Objects.ObjMsg );
	BEGIN
		WITH F: Display.Frame DO
			WITH M: Display.FrameMsg DO lastframe := M.dlink
			END
		END
	END myHandler;

	PROCEDURE GetContext( F: Display.Frame ): Display.Frame;
	VAR Handler: Objects.Handler;  msg: Display.FrameMsg;
	BEGIN
		Handler := F.handle;  F.handle := myHandler;  msg.F := F;  lastframe := NIL;  Display.Broadcast( msg );
		F.handle := Handler;
		IF lastframe # NIL THEN
			IF lastframe IS Display.Frame THEN
				WITH lastframe: Display.Frame DO RETURN lastframe
				END;
			ELSE RETURN NIL
			END
		ELSE RETURN NIL
		END
	END GetContext;

	PROCEDURE StickOn*( F: Display.Frame;  sticker: Display.Frame;  posx, posy: LONGINT );
	VAR f: Display.Frame;  c: Display.ConsumeMsg;  x, y: LONGINT;
	BEGIN
		f := GetContext( F );
		IF ~(f IS Panels.Panel) THEN RETURN
		ELSIF (f.handle # Handler) THEN f.handle := Handler;  x := 0;  y := 0;  NextFreePosition( f, x, y );  SetPosition( F, x, y )
		END;
		SetPosition( sticker, posx, posy );  c.id := Display.drop;  c.obj := sticker;  c.F := f;  Display.Broadcast( c );  Update( f )
	END StickOn;

	PROCEDURE Embed*;
	VAR F, f: Display.Frame;  x, y: LONGINT;
	BEGIN
		IF Oberon.Pointer.on THEN
			F := Oberon.MarkedFrame();  f := GetContext( F );
			IF (f # NIL ) & (f IS Panels.Panel) THEN
				f.handle := Handler;  x := 0;  y := 0;  NextFreePosition( f, x, y );  SetPosition( F, x, y );
				Position( f( Panels.Panel ), FindCentral( f ) )
			END
		END
	END Embed;

BEGIN
	aM.launch;  Handler := handler;
END antsContainers.

Gadgets.Insert Panels.NewPanel
antsContainers.Test
System.Free antsContainers ~
Gadgets.Insert antsContainers.NewPanel ~
Gadgets.Insert Button ~
antsContainers.Exchange
antsContainers.Embed
Gadgets.ChangeAttr PosY 0 ~
Gadts.ChangeAttr PosX 0 ~

Gadgets.ChangeAttr PosY 10 ~
Gadgets.ChangeAttr PosX 10 ~

Gadgets.ChangeAttr PosY 1 ~
Gadgets.ChangeAttr PosX 0 ~

Gadgets.ChangeAttr PosY 1 ~
Gadgets.ChangeAttr PosX 1 ~

Gadgets.ChangeAttr PosY 0 ~
Gadgets.ChangeAttr PosX - 1 ~

~

