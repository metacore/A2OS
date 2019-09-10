MODULE antsPictCoordinate IN Oberon;   (* fof *)
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




IMPORT vyBase, vyGraphBase, vyDisplay2d, Input, vyEvents, Objects, Files, vyRectangles, Pictures, vyCommandMenus,
	Display, Images, aM := antsMessages, Oberon;

TYPE

	tZoom* = POINTER TO tZoomDesc;
	tZoomDesc* = RECORD
		x-, y-, dx-, dy-: SIGNED16;   (* x,y: Offset; dx,dy: PixelSize *)
		next: tZoom
	END;

	Selection* = POINTER TO SelectionDesc;
	SelectionDesc* = RECORD (vyDisplay2d.SelDesc)
		px*, py*, pw*, ph*: SIGNED16
	END;

	tCoordinate* = POINTER TO tCoordinateDesc;
	tCoordinateDesc* = RECORD (vyDisplay2d.tCoordinate2dDesc);
	(* 	c*: vyGraphBase.tCoordinate;	*)  (* this coordinate system is the generic coordinate system of the host picture ! *)
		x-, y-, dx-, dy-, X-, Y-, W-, H-: SIGNED16;   (*= X,Y,W,H: cache, screen region of layers host's picture;
		x,y: Offset of Picture`s screen region, dx,dy: PixelSize *)
		vx-, vy-, px-, py-, pw-, ph-: SIGNED16;   (* vx,vy: Coordinates of the first INT Rectangle (partially) viewed,
		px,py,pw,ph: Picture Coordinate of viewed part *)
		zoom: tZoom;   (* history of coordinates zoom *)
		pictW*, pictH*: SIGNED16 (* pure cache for visualization *) ;
		fixed*, free*: BOOLEAN;
		p*: Pictures.Picture;
		i*: Images.Image

	END;

	ttt = RECORD
		x, y, dx, dy: SIGNED16;
		c: tCoordinate
	END;

VAR
	command: ttt;
	tc*: tCoordinate;   (*=cache variable *)
	currentsel*: Selection;  passevent: BOOLEAN;  globalHost: Objects.Object;

	PROCEDURE GrowRectangleRL*( x, y, w, h: SIGNED16;  VAR dx, dy: SIGNED16 );
	(*vs 0.0a1  md  29.05.95 *)
	VAR keys, keys0: SET;  x1, y1, x0, y0, xOld, yOld: SIGNED16;  oldm: SIGNED16;
	BEGIN
		(* antsToolbox.StartDisplayHelp("Hold buttons and zoom rect"); *)
		vyGraphBase.GetDisplayMode( oldm );  vyGraphBase.SetDisplayMode( vyGraphBase.invert );
		Input.Mouse( keys0, x0, y0 );  vyGraphBase.DrawCursor( x0, y0 );  vyGraphBase.FrameRect( x, y, w, h );
		Input.Mouse( keys, x1, y1 );  xOld := x0;  yOld := y0;
		WHILE (keys = keys0) DO
			IF ((x1 # xOld) OR (y1 # yOld)) THEN
				vyGraphBase.FrameRect( x, y, w, h );  y := y + (y1 - yOld);  w := w + (x1 - xOld);  h := h - (y1 - yOld);
				vyGraphBase.FrameRect( x, y, w, h );  xOld := x1;  yOld := y1
			END;
			Input.Mouse( keys, x1, y1 );  vyGraphBase.DrawCursor( x1, y1 )
		END;
		vyGraphBase.FrameRect( x, y, w, h );  dx := x1 - x0;  dy := y1 - y0;  vyGraphBase.SetDisplayMode( oldm )
	END GrowRectangleRL;

	PROCEDURE Min( a, b: SIGNED32 ): SIGNED32;
	BEGIN
		IF a < b THEN RETURN a ELSE RETURN b END
	END Min;

	PROCEDURE Max( a, b: SIGNED32 ): SIGNED32;
	BEGIN
		IF a > b THEN RETURN a ELSE RETURN b END
	END Max;

	PROCEDURE ShiftCoordinate( c: tCoordinate;  event: vyEvents.EventMsg );
	VAR x0, y0, dx, dy: SIGNED16;  zoom: vyDisplay2d.CoordZoomMessage;  vX, vY, vW, vH: SIGNED16;  pW, pH, pX, pY: SIGNED16;
		xp0, yp0, xp1, yp1, wp, hp: SIGNED32;  sizey, sizex: SIGNED32;  msg: Display.DisplayMsg;
	BEGIN
		(* antsToolbox.StartDisplayHelp("hold LM to shift, LM+MM: zoom out, LM+RM: zoom in");*)
		x0 := event.x;  y0 := event.y;
		IF globalHost # NIL THEN msg.device := Display.full;  msg.id := Display.display;  msg.F := globalHost( Display.Frame ) END;

		WHILE event.gesture = vyEvents.EvtLoc DO
			IF (event.x # x0) OR (event.y # y0) THEN
				dx := event.x - x0;  dy := event.y - y0;
				IF (dx # 0) OR (dy # 0) THEN
					INC( c.x, dx );  INC( c.y, dy );  vyBase.Update( c );
					IF globalHost # NIL THEN Display.Broadcast( msg ) END;
					sizex := c.W DIV 4;  sizey := c.H DIV 4;  x0 := event.x;  y0 := event.y;
					IF (c.pictW # 0) THEN
						xp0 := Min( c.x + c.X, c.X );  yp0 := Min( c.y + c.Y, c.Y );  xp1 := Max( c.x + c.X + c.pictW * c.dx, c.X + c.W );
						yp1 := Max( c.y + c.Y + c.pictH * c.dy, c.Y + c.H );

						wp := xp1 - xp0;  hp := yp1 - yp0;  pX := c.X + SHORT( ENTIER( sizex * (c.x + c.X - xp0) / wp + 0.5 ) );
						pY := c.Y + c.H - SHORT( sizey ) + SHORT( ENTIER( sizey * (c.y + c.Y - yp0) / hp + 0.5 ) );
						pW := SHORT( ENTIER( sizex * c.pictW * c.dx / wp + 0.5 ) );  pH := SHORT( ENTIER( sizey * c.pictH * c.dy / hp + 0.5 ) );
						vX := c.X + SHORT( ENTIER( sizex * (c.X - xp0) / wp + 0.5 ) );
						vY := c.Y + c.H - SHORT( sizey ) + SHORT( ENTIER( sizey * (c.Y - yp0) / hp + 0.5 ) );  vW := SHORT( ENTIER( sizex * c.W / wp + 0.5 ) );
						vH := SHORT( ENTIER( sizey * c.H / hp + 0.5 ) );

						vyGraphBase.SetForeColor( vyGraphBase.black );
						vyGraphBase.FillRect( c.X, c.Y + c.H - SHORT( sizey ), SHORT( sizex ), SHORT( sizey ) );
						vyGraphBase.SetForeColor( vyGraphBase.red );
						IF c.p # NIL THEN
							vyGraphBase.StretchedPict( c.p, 0, 0, c.p.width, c.p.height, pX, pY, pW, pH );
							vyGraphBase.FrameRect( pX, pY, pW, pH )
						ELSIF c.i # NIL THEN
							vyGraphBase.StretchedImage( c.i, 0, 0, c.i.width, c.i.height, pX, pY, pW, pH );
							vyGraphBase.FrameRect( pX, pY, pW, pH )
						ELSE vyGraphBase.FrameRect( pX, pY, pW, pH )
						END;

						vyGraphBase.SetForeColor( vyGraphBase.yellow );  vyGraphBase.FrameRect( vX, vY, vW, vH );
						IF (c.p = NIL ) & (c.i = NIL ) THEN
							vyRectangles.RectIntersection( pX, pY, pW, pH, vX, vY, vW, vH );
							vyGraphBase.SetForeColor( vyGraphBase.green );  vyGraphBase.FillRect( pX, pY, pW, pH )
						ELSE vyGraphBase.SetForeColor( vyGraphBase.blue );  vyGraphBase.FrameRect( vX - 1, vY - 1, vW + 2, vH + 2 )
						END
					END
				END
			END;
			vyEvents.GetEvent( event )
		END;
		vyBase.Update( c );  tc := c;

		IF event.gesture = vyEvents.EvtCopyAttr THEN
			GrowRectangleRL( x0, y0, 0, 0, dx, dy );  zoom.in := TRUE;  zoom.x := x0;  zoom.y := y0;  zoom.w := dx;  zoom.h := dy;
			c.handle( c, zoom )
		ELSIF event.gesture = vyEvents.EvtPointCmd THEN
			(* antsToolbox.StartDisplayHelp("Release buttons to zoom out"); *)
			zoom.in := FALSE;  c.handle( c, zoom )
		END;
		tc := c;
		(* vyEvents.ClearCurrentEvent(); *)
		WHILE (event.gesture # vyEvents.EvtEmpty) & (event.gesture # vyEvents.EvtUnknown) DO vyEvents.GetEvent( event ) END
	END ShiftCoordinate;

	PROCEDURE zoomin;
	VAR zoom: vyDisplay2d.CoordZoomMessage;
	BEGIN
		IF (command.dx = 0) OR (command.dy = 0) THEN IncSize( command.c )
		ELSE
			zoom.in := TRUE;  zoom.x := command.x;  zoom.y := command.y;  zoom.w := command.dx;  zoom.h := command.dy;
			command.c.handle( command.c, zoom )
		END
	END zoomin;

	PROCEDURE zoomout;
	VAR zoom: vyDisplay2d.CoordZoomMessage;
	BEGIN
		zoom.in := FALSE;
		IF command.c.zoom = NIL THEN DecSize( command.c ) ELSE command.c.handle( command.c, zoom ) END
	END zoomout;

(*
PROCEDURE keepsel;
VAR c: tCoordinate; x2,y2: FLOAT64;
BEGIN

c := command.c;
vyGraphBase.Global2Local(command.x,command.y);
vyGraphBase.SetCoordinate(c.c2d);
vyGraphBase.RectToRect2d(command.x,command.y,command.dx,command.dy, c.sel.x,c.sel.y,c.sel.w,c.sel.h);

AdjustRectR(c.sel.x,c.sel.y,c.sel.w,c.sel.h);
x2 := c.sel.x+c.sel.w; y2 := c.sel.y+c.sel.h;
c.sel.x := ENTIER(c.sel.x); c.sel.y := ENTIER(c.sel.y);  c.sel.w := ENTIER(x2+1)-c.sel.x; c.sel.h := ENTIER(y2+1)-c.sel.y;
c.sel.px := SHORT(ENTIER(c.sel.x+0.5)); c.sel.py := SHORT(ENTIER(c.sel.y+0.5));
c.sel.pw := SHORT(ENTIER(c.sel.w+0.5)); c.sel.ph := SHORT(ENTIER(c.sel.h+0.5));
IF c.sel.px < 0 THEN c.sel.pw := c.sel.px+c.sel.pw; c.sel.px := 0 END;
IF c.sel.py < 0 THEN c.sel.ph := c.sel.py+c.sel.ph; c.sel.py := 0 END;
IF c.sel.pw > c.pictW THEN c.sel.pw := c.pictW END;
IF c.sel.ph> c.pictH THEN c.sel.ph := c.pictH END;
(*
c.selx := command.x; c.sely := command.y; c.selw := command.dx; c.selh := command.dy;
IF c.selw < 0 THEN c.selx := c.selx+c.selw; c.selw := -c.selw END;
IF c.selh < 0 THEN c.sely := c.sely+c.selh; c.selh := -c.selh END;
*)
END keepsel;
*)

	PROCEDURE usecurrentsel;
	VAR c: tCoordinate;
	BEGIN
		c := command.c;  c.sel := currentsel
	END usecurrentsel;

	PROCEDURE MakeSel*( cc: tCoordinate;  sel: Selection;  xx, yy, ww, hh: SIGNED16 );
	VAR x2, y2: FLOAT64;
	CONST eps = 0.001;
	BEGIN
		vyDisplay2d.MakeSel( cc, sel, xx, yy, ww, hh );  x2 := sel.x + sel.w;  y2 := sel.y + sel.h;  sel.x := ENTIER( sel.x + eps );
		sel.y := ENTIER( sel.y + eps );  sel.w := ENTIER( x2 + 1 - eps ) - sel.x;  sel.h := ENTIER( y2 + 1 - eps ) - sel.y;  sel.px := SHORT( ENTIER( sel.x + 0.5 ) );
		sel.py := SHORT( ENTIER( sel.y + 0.5 ) );  sel.pw := SHORT( ENTIER( sel.w + 0.5 ) );  sel.ph := SHORT( ENTIER( sel.h + 0.5 ) );
		(*
	IF sel.px < 0 THEN sel.pw := sel.px+sel.pw; sel.px := 0 END;
	IF sel.py < 0 THEN sel.ph := sel.py+sel.ph; sel.py := 0 END;
	IF sel.px+sel.pw > cc.pictW THEN sel.pw :=cc.pictW-sel.px END;
	IF sel.py+sel.ph> cc.pictH THEN sel.ph := cc.pictH-sel.py END;
	*)
		(* commented since possibly more than one picture . *)
	END MakeSel;

	PROCEDURE removesel;
	BEGIN
		command.c.sel := NIL
	END removesel;

	PROCEDURE selectlayer;
	BEGIN
		passevent := TRUE
	END selectlayer;

	PROCEDURE Select( c: tCoordinate;  VAR event: vyEvents.EventMsg );
	VAR x0, y0, dx, dy: SIGNED16;  l: vyCommandMenus.List;

	BEGIN
		IF c.sel # NIL THEN currentsel := c.sel( Selection ) ELSE currentsel := NIL END;
		passevent := FALSE;  l := vyCommandMenus.current;  x0 := event.x;  y0 := event.y;
		GrowRectangleRL( x0, y0, 0, 0, dx, dy );  command.x := x0;  command.y := y0;  command.dx := dx;  command.dy := dy;
		command.c := c;
		IF (dx # 0) & (dy # 0) THEN
			NEW( currentsel );  MakeSel( c, currentsel, x0, y0, dx, dy );
			IF (currentsel.pw = 0) OR (currentsel.ph = 0) THEN currentsel := NIL END
		ELSE currentsel := NIL
		END;

		IF currentsel # NIL THEN
			vyCommandMenus.current := NIL;  l := NIL;  vyCommandMenus.Add( l, zoomout, "Zoom out " );  vyCommandMenus.current := l;
			vyCommandMenus.Add( l, zoomin, "Zoom in" );  vyCommandMenus.currentmode := vyCommandMenus.select;
			vyGraphBase.SetDisplayMode( vyGraphBase.invert );  vyGraphBase.SetPenSize( 2 );
			vyGraphBase.FrameRect( x0, y0, dx, dy );  vyGraphBase.SetPenSize( 1 );
			vyGraphBase.SetDisplayMode( vyGraphBase.paint );  vyCommandMenus.Add( l, usecurrentsel, "Keep Selection" )
			(* NEW(currentsel); MakeSel(c,currentsel,x0,y0,dx,dy); *)
		ELSE
			vyCommandMenus.Add( l, zoomout, "Zoom out " );  vyCommandMenus.Add( l, zoomin, "Zoom in" );
			vyCommandMenus.currentmode := vyCommandMenus.click;
			IF c.sel # NIL THEN currentsel := c.sel( Selection );  vyCommandMenus.Add( l, removesel, "Remove Selection" ) END;
			vyCommandMenus.Add( l, selectlayer, "mouse event to layers" )
		END;
		vyCommandMenus.ExecuteListedCommand( x0 + dx, y0 + dy, event, l );
		IF ~passevent THEN vyCommandMenus.Wait() END;
		vyGraphBase.SetCoordinate( c.c2d );  vyBase.Update( c );
		IF passevent THEN event.callForResponder := TRUE ELSE event.callForResponder := FALSE END  (* port goes on with event *)
	END Select;

	PROCEDURE ZoomOut( c: tCoordinate );
	BEGIN
		IF c.zoom # NIL THEN
			c.x := c.zoom.x;  c.y := c.zoom.y;  c.dx := c.zoom.dx;  c.dy := c.zoom.dy;   (* copy old coordinates *)
			c.zoom := c.zoom.next (* delete first entry in zoom list *)
		ELSE DecSize( c )
		END
	END ZoomOut;

	PROCEDURE AdjustRect( VAR x, y, w, h: SIGNED16 ): BOOLEAN;
	BEGIN
		IF w < 0 THEN x := x + w;  w := -w
		ELSIF w = 0 THEN RETURN FALSE
		END;
		IF h < 0 THEN y := y + h;  h := -h
		ELSIF h = 0 THEN RETURN FALSE
		END;
		RETURN TRUE
	END AdjustRect;

	PROCEDURE GetXY*( c: tCoordinate;  fromx, fromy: SIGNED16;  VAR x, y: SIGNED16 );
	VAR xr, yr: FLOAT64;
	BEGIN
		IF ~c.fixed THEN x := (fromx - (c.X + c.x)) DIV c.dx;  y := (fromy - (c.Y + c.y)) DIV c.dy
		ELSE vyGraphBase.PointToPoint2d( fromx, fromy, xr, yr );  x := SHORT( ENTIER( xr + 0.5 ) );  y := SHORT( ENTIER( yr + 0.5 ) )
		END
	END GetXY;

	PROCEDURE ZoomIn( c: tCoordinate;  x, y, w, h: SIGNED16 );
	VAR lastzoom: tZoom;  newx, newy, newdx, newdy: FLOAT64;  a, b: SIGNED16;  time: SIGNED32;
	VAR fact: FLOAT64;
	BEGIN
		lastzoom := c.zoom;
		NEW( c.zoom );  c.zoom.next := lastzoom;   (* create new entry in zoom list *)
		c.zoom.x := c.x;  c.zoom.y := c.y;  c.zoom.dx := c.dx;  c.zoom.dy := c.dy;   (* copy recent coordinates *)
		IF ~AdjustRect( x, y, w, h ) THEN
			fact := 1 - 1 / (2 * c.dx);
			IF w = 0 THEN a := x - c.X;  b := c.X + c.W - x;  x := x - SHORT( ENTIER( a * fact ) );  w := SHORT( ENTIER( b * fact + a * fact ) );  END;
			fact := 1 - 1 / (2 * c.dy);
			IF h = 0 THEN a := y - c.Y;  b := c.Y + c.H - y;  y := y - SHORT( ENTIER( a * fact ) );  h := SHORT( ENTIER( b * fact + a * fact ) );  END;

		END;

		newdx := (1.0 * c.W * c.dx / w);
		IF newdx = 0 THEN newdx := 1
		ELSIF newdx > 100 THEN newdx := 100
		END;
		newdy := (1.0 * c.H * c.dy / h);
		IF newdy = 0 THEN newdy := 1
		ELSIF newdy > 100 THEN newdy := 100
		END;
		IF newdx > newdy THEN newdx := newdy ELSE newdy := newdx END;
		newx := -((1.0 * newdx * (x - (c.X + c.x)) / c.dx));  newy := -((1.0 * newdy * (y - (c.Y + c.y)) / c.dy));
		c.dx := SHORT( ENTIER( newdx + 0.5 ) );  c.dy := SHORT( ENTIER( newdy + 0.5 ) );  c.x := SHORT( ENTIER( newx + 0.5 ) );  c.y := SHORT( ENTIER( newy + 0.5 ) )
	END ZoomIn;

	PROCEDURE IncSize*( c: tCoordinate );
	BEGIN
		INC( c.dx );  INC( c.dy )
	END IncSize;

	PROCEDURE DecSize*( c: tCoordinate );
	BEGIN
		DEC( c.dx );  DEC( c.dy );
		IF c.dx = 0 THEN INC( c.dx ) END;
		IF c.dy = 0 THEN INC( c.dy ) END
	END DecSize;

	PROCEDURE Center*( w, h: SIGNED16;  c: tCoordinate );
	BEGIN
		c.x := (c.W - (w * c.dx)) DIV 2;  c.y := (c.H - (h * c.dy)) DIV 2
	END Center;

	PROCEDURE CopyC( source, dest: tCoordinate );
	BEGIN
		dest^ := source^;  dest.handle := source.handle
	END CopyC;

	PROCEDURE CalcV( c: tCoordinate );
	BEGIN
		IF c.x >= 0 THEN c.vx := c.x;  c.px := 0 ELSE c.vx := ((c.x) MOD c.dx) - c.dx;  c.px := -c.x DIV c.dx - 1 END;
		IF c.y >= 0 THEN c.vy := c.y;  c.py := 0 ELSE c.vy := ((c.y) MOD c.dy) - c.dy;  c.py := -c.y DIV c.dy - 1 END;   (* ?? *)

		IF c.W > c.x THEN c.pw := (c.W - c.vx) DIV c.dx + 1 ELSE c.pw := 0 END;
		IF c.H > c.y THEN c.ph := (c.H - c.vy) DIV c.dy + 1 ELSE c.ph := 0 END;

		INC( c.vx, c.X );  INC( c.vy, c.Y )

	END CalcV;

	PROCEDURE WriteCoordinate*( VAR R: Files.Rider;  VAR  (*IN*) c: tCoordinate );
	BEGIN
		IF c = NIL THEN Files.WriteInt( R, 0 )
				ELSE Files.WriteInt( R, 90 );   (*magic number*)
			Files.WriteInt( R, c.x );  Files.WriteInt( R, c.y );  Files.WriteInt( R, c.dx );  Files.WriteInt( R, c.dy );
			Files.WriteInt( R, c.vx );  Files.WriteInt( R, c.vy );  Files.WriteInt( R, c.px );  Files.WriteInt( R, c.py );
			Files.WriteInt( R, c.pw );  Files.WriteInt( R, c.ph );  Files.WriteBool( R, c.fixed );  Files.WriteBool( R, c.free );
			(*
		Files.WriteBool(R, c.allowfractions);  Files.WriteBool(R, c.allowstretch)
		*)
			(*
		IF c.sel # NIL  THEN
		Files.WriteLReal(R,c.sel.x); Files.WriteLReal(R,c.sel.y); Files.WriteLReal(R,c.sel.w); Files.WriteLReal(R,c.sel.h)
		ELSE
		Files.WriteLReal(R,MIN(FLOAT64)); Files.WriteLReal(R,MIN(FLOAT64)); Files.WriteLReal(R,MIN(FLOAT64)); Files.WriteLReal(R,MIN(FLOAT64))
		END;
		*)
		END
	END WriteCoordinate;

	PROCEDURE ReadCoordinate*( VAR R: Files.Rider;  VAR  (*IN*) c: tCoordinate );
	VAR flag: SIGNED16;  b: BOOLEAN;
	BEGIN
		Files.ReadInt( R, flag );
		IF flag = 0 THEN c := NIL
		ELSE
			(* ASSERT(flag = 87, 100);   (*magic number*)*)
			Files.ReadInt( R, c.x );  Files.ReadInt( R, c.y );  Files.ReadInt( R, c.dx );  Files.ReadInt( R, c.dy );
			Files.ReadInt( R, c.vx );  Files.ReadInt( R, c.vy );  Files.ReadInt( R, c.px );  Files.ReadInt( R, c.py );
			Files.ReadInt( R, c.pw );  Files.ReadInt( R, c.ph );
			IF flag = 87 THEN Files.ReadBool( R, b );  Files.ReadBool( R, b );  c.fixed := FALSE
			ELSIF flag > 87 THEN Files.ReadBool( R, c.fixed )
			END;
			IF flag > 88 THEN
				(*
			IF c.sel # NIL THEN NEW(c.sel) END;
			Files.ReadLReal(R,c.sel.x); Files.ReadLReal(R,c.sel.y); Files.ReadLReal(R,c.sel.w); Files.ReadLReal(R,c.sel.h);
			IF c.sel.x = MIN(FLOAT64) THEN c.sel := NIL END;
			*)
			END;
			IF flag > 89 THEN Files.ReadBool( R, c.free ) END;

		END
	END ReadCoordinate;

	PROCEDURE DoHandleAttributes( o: tCoordinate;  VAR M: Objects.AttrMsg );
	BEGIN
		IF M.id = Objects.enum THEN M.Enum( "Gen" );  M.Enum( "fixed" );  M.Enum( "free" );
		ELSIF (M.id = Objects.get) THEN
			IF M.name = "Gen" THEN M.class := Objects.String;  COPY( "antsPictCoordinate.Gen", M.s );  M.res := 0
			ELSIF M.name = "fixed" THEN M.class := Objects.Bool;  M.b := o.fixed;  M.res := 0
			ELSIF M.name = "free" THEN M.class := Objects.Bool;  M.b := o.free;  M.res := 0
			ELSE vyDisplay2d.C2dHandler( o, M )
			END
		ELSIF M.id = Objects.set THEN
			IF M.name = "fixed" THEN
				IF M.class = Objects.Bool THEN o.fixed := M.b;  M.res := 0;  vyBase.Update( o ) END
			ELSIF M.name = "free" THEN
				IF M.class = Objects.Bool THEN o.free := M.b;  M.res := 0;  vyBase.Update( o ) END
			ELSE vyDisplay2d.C2dHandler( o, M )
			END
		ELSE vyDisplay2d.C2dHandler( o, M )
		END
	END DoHandleAttributes;

	PROCEDURE CHandler( o: Objects.Object;  VAR msg: Objects.ObjMsg );
	VAR c, ccopy: tCoordinate;
	BEGIN
		ASSERT ( o IS tCoordinate, 102 );
		c := o( tCoordinate );

		IF msg IS vyDisplay2d.CoordRgnMessage THEN
			WITH msg: vyDisplay2d.CoordRgnMessage DO
				tc.X := msg.X;  tc.Y := msg.Y;  tc.W := msg.W;  tc.H := msg.H;  CalcV( c );  vyDisplay2d.C2dHandler( c, msg );
				IF ~(c.fixed OR c.free) THEN
					vyGraphBase.SetRealWorldRgn( -tc.x / tc.dx, -tc.y / tc.dy, tc.W / tc.dx, tc.H / tc.dy, 0.0 )
				END;
			END;
		ELSIF msg IS vyDisplay2d.CoordSetMessage THEN
			WITH msg: vyDisplay2d.CoordSetMessage DO
				tc := c;
				IF c.sel = NIL THEN currentsel := NIL ELSE currentsel := c.sel( Selection ) END;   (* vyGraphBase.SetScreenCoordinate(); *)
				vyDisplay2d.C2dHandler( c, msg );
			END;
		ELSIF msg IS vyEvents.EventMsg THEN
			WITH msg: vyEvents.EventMsg DO
				IF c.free THEN vyDisplay2d.C2dHandler( c, msg ) ELSE
					IF msg.callForResponder THEN
						globalHost := msg.dlink;
						IF (msg.gesture = vyEvents.EvtLoc) OR (msg.gesture = vyEvents.EvtWheelUp) OR
						    (msg.gesture = vyEvents.EvtWheelDown) THEN
							IF msg.responder # NIL THEN msg.responder := NIL ELSE msg.responder := o END
						ELSIF (msg.gesture = vyEvents.EvtSelect) THEN msg.responder := o
						END
					ELSE
						IF msg.gesture = vyEvents.EvtSelect THEN Select( c, msg );  CalcV( c )
						ELSIF (msg.gesture = vyEvents.EvtWheelUp) THEN
							ZoomIn( c, msg.x, msg.y, 0, 0 );  CalcV( c );  vyBase.Update( c );
						ELSIF (msg.gesture = vyEvents.EvtWheelDown) THEN command.c := c;  zoomout;
						ELSE ShiftCoordinate( c, msg );  CalcV( c )
						END
					END;
				END;
			END;
		ELSIF msg IS Objects.CopyMsg THEN
			WITH msg: Objects.CopyMsg DO
				IF msg.stamp = c.stamp THEN msg.obj := c.dlink ELSE
					IF msg.id = Objects.deep THEN
						NEW( ccopy );  OpenC( ccopy, 1, 1 );  CopyC( c, ccopy );  vyBase.CopyObject( msg, c, ccopy );
						vyDisplay2d.CopyC2d( c, ccopy );  msg.obj := ccopy
					ELSE ccopy := c;  msg.obj := ccopy
					END
				END;
			END;
		ELSIF msg IS vyDisplay2d.CoordZoomMessage THEN
			WITH msg: vyDisplay2d.CoordZoomMessage DO
				IF ~msg.in THEN ZoomOut( c );  CalcV( c ) ELSE ZoomIn( c, msg.x, msg.y, msg.w, msg.h );  CalcV( c ) END;
				vyBase.Update( c );
			END;
		ELSIF msg IS Objects.FileMsg THEN
			WITH msg: Objects.FileMsg DO
				IF msg.id = Objects.load THEN vyBase.objecthandle( o, msg );  ReadCoordinate( msg.R, c )
				ELSIF msg.id = Objects.store THEN vyBase.objecthandle( o, msg );  WriteCoordinate( msg.R, c )
				END;
			END;
		ELSIF msg IS Objects.AttrMsg THEN
			WITH msg: Objects.AttrMsg DO DoHandleAttributes( c, msg( Objects.AttrMsg ) )
			END;
		ELSIF msg IS Display.DisplayMsg THEN
			WITH msg: Display.DisplayMsg DO
				IF (c.sel # NIL ) & (c.sel IS Selection) THEN
					vyGraphBase.SetDisplayMode( vyGraphBase.invert );  vyGraphBase.SetPenSize( 2 );
					vyGraphBase.FrameRect2d( c.sel( Selection ).px, c.sel( Selection ).py, c.sel( Selection ).pw, c.sel( Selection ).ph );
					vyGraphBase.SetPenSize( 1 );  vyGraphBase.SetDisplayMode( vyGraphBase.paint )
				END
			END;
		ELSE vyDisplay2d.C2dHandler( o, msg )
		END
	END CHandler;

	PROCEDURE OpenC*( c: tCoordinate;  dx, dy: SIGNED16 );
	BEGIN
		c.x := 0;  c.y := 0;  c.dx := dx;  c.dy := dy;  vyDisplay2d.OpenC2d( c, c.x, c.y, c.dx, c.dy );  c.handle := CHandler
	END OpenC;

	PROCEDURE Gen*;
	VAR c: tCoordinate;
	BEGIN
		aM.cmd;  NEW( c );  OpenC( c, 1, 1 );  Objects.NewObj := c;  c.fixed := FALSE
	END Gen;

BEGIN
	aM.launch;
END antsPictCoordinate.

