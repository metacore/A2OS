MODULE vyPort IN Oberon;
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



(*	(c) Project Voyager, StatLab Heidelberg
(c) G.Sawitzki, StatLab Heidelberg
(c) F.Friedrich, StatLab Heidelberg
(c) M. Diller StatLab Heidelberg
*)
(* fof 001120 inserted prohibitDB in LayerDesc, Implementation of handling thereof, cleaned up PictureHandleDisplay*)
(* jb 4.11.00 bug in FocusLayer fixed, probably variable focusLayer is not necessary *)

(* 000816 fof: Any (nonexported) procedures referrring to Frame begin with the keyword Frame now,
the same for Picture and Layer,
e.g. PictureDraw, PictureCopy, FrameDraw, FrameCopy, PictureHandleFileMsg,FrameHandleFileMsg,LayerHandleFileMsg ...
! remove defunctxxx
*)
(* 010307 fof: Coordinate Set and Region messages in wrong order, repaired. *)
(* 010509 fof: adapted to antsEffects, -> ANTS *)


(*! enhance double buffering, should work on true color display i/o Pictures.Picture *)

IMPORT  (*SYSTEM,*) Objects, Display, Display3, Texts,  (* Effects, *) Oberon, Pictures, Files, Panels, Gadgets, vyLinks,
	vyHostTexts, vyBase, vyName, vyTypes, Fonts, Attributes, Input, vyEvents, vyTracking, vyConsume,
	vyStrings := vyHostStrings, vyRectangles, vyGraphBase,  (*PictConverters, *) vyDisplay2d, Effects, antsEffects := vyTracking (* remove vyTracking for full usage of ANTS functionality *) ,
	antsCommandList := vyCommandMenus, vyHost, Out, vyPortability;

CONST
	idversion* = "vyPort.S3 v0r0a5";  framesize = 3;  BGPictureName = "Voyager.Pict";  Border* = 4;
	(** Aspect Ratios **)
	gold* = 0.618034;   (*= 1 / (1 + sqrt(5)) *)
	square* = 1;

	(** Pict **)
	ActionLayerRemove = 1;  ActionLayerCopy = 2;
TYPE
	Real = vyBase.Real;

	(** Frames *)
	(*= Frames are the generic containers for Voyager.
	Common tasks, like external axis or labels, or trellis arrangement, should be handled by frames.
	*)

	Frame* = Panels.Panel;

	(** Pictures *)
	(*= Pictures are the generic display frames for Voyager. In Oberon S3 terms, Pictures are containers. Pictures contain layers, which render the proper graphic information. Synchronized coordinates and managent of grafics contexts should be handled by pictures; additional display should be delegated to layers.
	*)

	Picture* = POINTER TO PictureDesc;
	PictureDesc* = RECORD (vyBase.FrameDesc)
	(*	defunctx * , defuncty * : INTEGER;*)
		Pictx, Picty, Pictw, Picth: REAL;   (* pictures location factors relative to the frame.
		See AdjustPict for semantics *)
		(*= pictures absolute location, is updated by host frame's handler *)
		needsRedraw*: BOOLEAN;   (*= set to force redraw if doublebuffering *)
		(* Pict *)
		hx, hy: INTEGER;   (* header location= layer list *)
		header: BOOLEAN;   (* show header *)
		backGround*: Display.Color;
		gcontext*: Objects.Object;   (*= graphic context. usually not shared - may be a cache of grafics state *)
		(* dbPict: Pictures.Picture; *)
		db: vyGraphBase.doubleBuffer;
		(*= vylinks must be Layers. Layers usually are transparent. All layers of a picture share the same coordinate system, as defined by the Picture *)
		(* entries from vyBase:
		x,y: INTEGER; <- absolute location, cache variable
		border:INTEGER;
		hotupdate: BOOLEAN;
		vylinks: vyLinks.Link; <- Layers;
		*)
	END;
	(*= gcontext may be any graphic context type. For most Voyager pictures, a simpl 2d context is sufficient. It is wrapped into a vyBase Object to allow extensions . *)

	(** Layers *)
	(*= Layers are the primitive grafic environment in Voyager. Layers should always be attached to pictures. When a Layer rouine is called, the graphic environment and coordinate system should be set up. Layers should be transparent. One or more layers put on top of each other gives a picture. Messages should to layers should only be sent by the enclosing picture.
	*)

	tLayer* = POINTER TO tLayerDesc;
	tLayerDesc* = RECORD (vyBase.ObjDesc)
		style*: vyGraphBase.Style;
		highlight*: vyBase.Object;
		x*, y*, z*: vyBase.tVector;
		prohibitDB*: BOOLEAN;   (* indicates that layer displaying cannot use double buffering device *)
		forceImage*: BOOLEAN;
		(*host: Picture*)
	END;

	(*	ResetMsg = RECORD (Objects.ObjMsg) END;
	PrintPictMsg = RECORD (Display.DisplayMsg) (* gs *)
	Q * : Display3.Mask
	END;
	*)
	FindMsg = RECORD (Display.FrameMsg)
		fx, fy: INTEGER
	END;

	ExtractContentMsg = RECORD (Objects.ObjMsg)
		o*: vyBase.Object
	END;
	(* set coordinates and cliprect *)
	SetPictureMsg = RECORD (Objects.ObjMsg) END;

	AdjustCoordMsg* = RECORD (Objects.ObjMsg) (* sent from pict to layer. Layer may call back to adjust gcontext *)
		pict*: Picture;
		layer*: tLayer
	END;

	setfocusMsg = RECORD (Display.DisplayMsg) END;

	UpMsg* = RECORD (Objects.ObjMsg) END;

VAR
	(* cache & temporary variables *)
	focusFrame-: Frame;   (* cache: latest accessed frame *)
	focusPicture-: Picture;   (* cache: latest accessed picture *)
	focusLayer-: tLayer;   (* cache: latest accessed picture *)

	newpicture-: Picture;   (*= exported for debugging only *)
	newframe-: Frame;   (*= exported for debugging only *)
	stdFrameCol: INTEGER;  setfrontmostcalled: BOOLEAN;

	(** Port Variables **)
	DfltFramesPLine- (*=Default number of frames per line *) , defFramehwRelation (*? *) : REAL;  screenRatio*: REAL;
	updatesuspend: BOOLEAN;  BGPicture: Pictures.Picture;
	(*	ftemp : Display.Frame;*)

	(** Picture Variables **)

	foreColor*, backGround: Display.Color;  PrintHeaders*: BOOLEAN;  undoPict: Picture;  undoLayer: tLayer;  undoAction: INTEGER;
	onTheFly*: BOOLEAN;   (* = TRUE iff undo is restricted, e.g. we going to rotate *)
	(*templayer : tLayer;*)

	DefaultWidth: INTEGER;   (* substituted if Views returns 0 *)


(*** support routines *)

	PROCEDURE SetFocusPicture*( p: Picture );
	VAR msg: Display.DisplayMsg;  setf: setfocusMsg;
	BEGIN
		IF focusPicture = p THEN RETURN END;
		IF (focusPicture # NIL ) THEN
			msg.device := Display.full;  msg.id := Display.display;  msg.F := focusPicture;  focusPicture.needsRedraw := FALSE;
			focusPicture := NIL;  Display.Broadcast( msg ) (* removes focus from picture *)
		END;
		focusPicture := p;  setf.F := p;  Display.Broadcast( setf );
		IF focusPicture # NIL THEN  (* ignore state of updatesuspend bit *)
			msg.device := Display.full;  msg.id := Display.display;  msg.F := focusPicture;  focusPicture.needsRedraw := FALSE;
			Display.Broadcast( msg ) (* puts focus to new picture *)
		END

	END SetFocusPicture;

	PROCEDURE SetFocusPort*( p: Frame );
	VAR msg: Display.DisplayMsg;
	BEGIN
		IF p = focusFrame THEN RETURN END;
		IF (focusFrame # NIL ) THEN
			msg.device := Display.full;  msg.id := Display.display;  msg.F := focusFrame;  focusFrame := NIL;
			Display.Broadcast( msg ) (* removes focus from picture *)
		END;
		focusFrame := p;
		IF focusFrame # NIL THEN  (* ignore state of updatesuspend bit *)
			msg.device := Display.full;  msg.id := Display.display;  msg.F := focusFrame;
			Display.Broadcast( msg ) (* puts focus to new picture *)
		END
	END SetFocusPort;

	PROCEDURE SetNewC2d*( p: Picture;  x, y, w, h: Real );
	VAR cont: vyBase.Object;
	BEGIN
		IF w <= 0 THEN w := 1 END;
		IF h <= 0 THEN h := 1 END;

		IF (w > 1 / MAX( LONGINT )) & (h > 1 / MAX( LONGINT )) THEN
			cont := vyDisplay2d.NewC2d( x, y, w, h );
			IF (p.gcontext = NIL ) OR (vyPortability.TypeOf( p.gcontext ) = vyPortability.TypeOf( cont )) THEN
				IF (p.gcontext # NIL ) THEN vyBase.UnSubscribe( p.gcontext, p ) END;
				p.gcontext := cont
			ELSE vyHostTexts.Note( vyHostTexts.cWarning, "can not replace coordinate system, wrong type" );

				RETURN
			END;
			vyBase.Subscribe( (*for messages from source*) p.gcontext, p );
			vyBase.Update( p.gcontext ) (* fof 0103xx*)
		ELSE p.gcontext := NIL
		END;
		ASSERT ( p.gcontext # NIL , 100 )
	END SetNewC2d;

	PROCEDURE SetC2d*( p: Picture;  x, y, w, h: LONGREAL );
	BEGIN
		Attributes.SetLongReal( p, "x2d", x );  Attributes.SetLongReal( p, "y2d", y );  Attributes.SetLongReal( p, "w2d", w );
		Attributes.SetLongReal( p, "h2d", h )
	END SetC2d;

	PROCEDURE GetPictureScreenRegion*( picture: Picture;  VAR x, y, w, h: INTEGER );   (*! remove ! *)
	VAR msg: FindMsg;
	BEGIN
		msg.F := picture;  Display.Broadcast( msg );  x := msg.fx;  y := msg.fy;  w := picture.W;  h := picture.H
	END GetPictureScreenRegion;

	PROCEDURE GetPictureXY*( frame: Frame;  X, Y: INTEGER ): Picture;
	(*! remove frame from procedure definition *)
	(*= get picture at screen coordinates x,y. The frame parameter may be passed to speed up search. *)
	VAR u, v: INTEGER;  frame1: Display.Frame;
	BEGIN
		Gadgets.ThisFrame( X, Y, frame1, u, v );
		IF (frame # NIL ) OR (frame1 = NIL ) OR ~(frame1 IS Picture) THEN RETURN NIL ELSE RETURN frame1( Picture ) END
	END GetPictureXY;

	(** focus frame managment **)
(*? reduce these routines *)
	PROCEDURE GetFocus*( ): Frame;   (*vs 0.0a2 fof 26.3.96*)
	BEGIN  (* debug $IF debug THEN *)
		IF (focusFrame # NIL ) & (focusFrame.handle = NIL ) THEN HALT( 100 ) END
		;   (* $END debug *)
		RETURN focusFrame
	END GetFocus;

(*? join w. next *)
	PROCEDURE GetFocusPicture*( ): Picture;   (*vs 0.0a2 fof 26.3.96*)
	(*= get focus picture. The frame parameter may be passed to speed up search. *)
	BEGIN  (* debug $IF debug THEN *)
		IF (focusPicture # NIL ) & (focusPicture.handle = NIL ) THEN HALT( 100 ) END
		;   (* $END debug *)
		RETURN focusPicture
	END GetFocusPicture;

(*
PROCEDURE PictureCopy (VAR M: Objects.CopyMsg; source, dest: Picture);
BEGIN
dest^ := source^;
Gadgets.CopyFrame(M, source, dest)
END PictureCopy;
*)
	PROCEDURE PictureCopy( VAR M: Objects.CopyMsg;  source, dest: Picture );
	VAR copymsg: Objects.CopyMsg;  layerRef: vyLinks.Link;
	BEGIN
		dest^ := source^;   (*! fof 010316 , ok ?, Problems with subscribe mechanisms. *)
		Gadgets.CopyFrame( M, source, dest );
		(*dest.dbPict := NIL;*) dest.db := NIL;   (* otherwise source writes db of dest *)
		copymsg := M;
		IF (source.gcontext # NIL ) & (source.gcontext.handle # NIL ) THEN
			source.gcontext.handle( source.gcontext, copymsg );  PictureSetgcontext( dest, copymsg.obj( vyBase.Object ) )
		END;

		(* links have to be copied, otherwise adding / removing layers in dest picture extents to original *)
		dest.vylinks := NIL;  vyLinks.CopyLinks( M, source.vylinks, dest.vylinks );

		IF dest.vylinks # NIL THEN
			layerRef := dest.vylinks;
			WHILE layerRef # NIL DO vyBase.Subscribe( (*for messages from source*) layerRef.obj, dest );  layerRef := layerRef.link END
		END
	END PictureCopy;
(*
PROCEDURE AdjustPict (frame: Frame; ppict: Picture);
VAR msg: Display.ModifyMsg; innerwidth, innerheight, lowx, lowy: INTEGER;
BEGIN
innerwidth := frame.W - 2 * frame.borderW;
innerheight := frame.H - 2 * frame.borderW;
lowx := frame.borderW;
lowy := - frame.H + frame.borderW ;

msg.W := SHORT(ENTIER(ppict.Pictw * innerwidth));
msg.H := SHORT(ENTIER(ppict.Picth * innerheight));

msg.X := lowx + SHORT(ENTIER(ppict.Pictx * innerwidth)) ;
msg.Y := lowy + SHORT(ENTIER(ppict.Picty * innerheight)) ;
(*
Out.String("Frame"); Out.Int( frame.W,10); Out.Int(frame.H,10); Out.Ln();
Out.String("msg"); Out.Int( msg.X,10); Out.Int(msg.Y,10);Out.Int( msg.W,10); Out.Int(msg.H,10); Out.Ln();
Out.String("xryr"); Out.Real(ppict.Pictx,10); Out.Real(ppict.Picty,10); Out.Real(ppict.Pictw,10); Out.Real(ppict.Picth,10);
*)
(*? find good definition *)
ppict.W := msg.W; ppict.H := msg.H;

msg.mode := Display.state; msg.id := Display.extend; msg.F := ppict;
(* Display.Broadcast(msg); *)

Gadgets.Adjust(ppict, msg);
(* Gadgets.Update(ppict); *)
ppict.mask := NIL
END AdjustPict;
*)
	PROCEDURE AdjustPict( frame: Frame;  ppict: Picture );
	VAR msg: Display.ModifyMsg;  innerwidth, innerheight, lowx, lowy: INTEGER;
	BEGIN
		innerwidth := frame.W - 2 * frame.borderW;  innerheight := frame.H - 2 * frame.borderW - 1;
		lowx := frame.borderW;  lowy := -frame.H + frame.borderW + 1;

		msg.X := SHORT( ENTIER( lowx + ppict.Pictx * innerwidth + 0.5 ) );  msg.Y := SHORT( ENTIER( lowy + ppict.Picty * innerheight + 0.5 ) );
		msg.W := SHORT( ENTIER( lowx + (ppict.Pictx + ppict.Pictw) * innerwidth + 0.5 ) ) - msg.X;
		msg.H := SHORT( ENTIER( lowy + (ppict.Picty + ppict.Picth) * innerheight + 0.5 ) ) - msg.Y;

		ppict.W := msg.W;  ppict.H := msg.H;

		msg.mode := Display.state;  msg.id := Display.extend;  msg.F := ppict;
		(* Display.Broadcast(msg); *)

		Gadgets.Adjust( ppict, msg );
		(* Gadgets.Update(ppict); *)
		ppict.mask := NIL
	END AdjustPict;

(** Frames **)
	PROCEDURE FrameHandleAttributes( obj: Frame;  VAR M: Objects.AttrMsg );
	BEGIN
		IF M.id = Objects.get THEN
			IF M.name = "Gen" THEN M.class := Objects.String;  COPY( "vyPort.NewFrame", M.s );  M.res := 0 ELSE Panels.PanelHandler( obj, M ) END
		ELSE Panels.PanelHandler( obj, M )
		END
	END FrameHandleAttributes;

	PROCEDURE FrameHandler*( obj: Objects.Object;  VAR msg: Objects.ObjMsg );
	VAR f: Display.Frame;  count: INTEGER;  rows, cols: LONGINT;  tr, tc: INTEGER;  x, y, w, h: INTEGER;

		PROCEDURE FrameDrawRect( PRINT: BOOLEAN );   (*! move to HostDisplay *)
		(*! implement and call in a reliable way
		BEGIN
	vyGraphBase.SetDisplayMode (vyGraphBase.replace);
	IF PRINT THEN vyGraphBase.SetForeColor(14) ELSE vyGraphBase.SetForeColor(0) END;
	vyGraphBase.SetBackColor(12);
	vyGraphBase.GetPenSize(oldsize);
	vyGraphBase.SetPenSize(obj(Frame).borderW);
	vyGraphBase.ShadowRect (x, y, obj(Frame).W, obj(Frame).H);
	vyGraphBase.SetPenSize(oldsize)
	*)
		END FrameDrawRect;

	BEGIN
		WITH obj: Frame DO
			IF msg IS Display.FrameMsg THEN
				IF msg IS Display.FrameMsg THEN
					WITH msg: Display.FrameMsg DO
						x := msg.x + obj.X;  y := msg.y + obj.Y;  w := obj.W;  h := obj.H;
						IF (msg.F = NIL ) OR (msg.F = obj) OR (Panels.IsChild( obj, msg.F ) & (msg.F IS Picture)) THEN
							IF msg IS setfocusMsg THEN
								WITH msg: setfocusMsg DO
								(* SetFocusPort(obj); *)
								END;
							ELSIF msg IS Display.ModifyMsg THEN
								WITH msg: Display.ModifyMsg DO
									Panels.PanelHandler( obj, msg );
									IF msg.F = obj THEN
										f := obj( Frame ).dsc;
										WHILE f # NIL DO
											IF f IS Picture THEN AdjustPict( obj, f( Picture ) ) END;
											f := f.next
										END
									END;
									FrameDrawRect( FALSE );
								END;
							ELSIF msg IS Display.DisplayMsg THEN
								WITH msg: Display.DisplayMsg DO
									IF obj = focusFrame THEN obj.col := SHORT( vyGraphBase.lgrey ) ELSE obj.col := stdFrameCol END;
									Panels.PanelHandler( obj, msg );  FrameDrawRect( FALSE );
								END;
							ELSIF msg IS Display.ConsumeMsg THEN
								WITH msg: Display.ConsumeMsg DO
									IF msg.res < 0 THEN
										Panels.PanelHandler( obj, msg );  f := obj( Frame ).dsc;  count := 0;
										WHILE f # NIL DO
											IF f IS Display.Frame (*Picture*) THEN INC( count ) END;
											f := f.next
										END;
										(*! improve. use numbers which give cells with proportions nearest to required ratio *)
										CASE count OF
										4:     rows := 2;  cols := 2;
										| 6:   rows := 2;  cols := 3;
										| 8:   rows := 2;  cols := 4;
										| 9:   rows := 3;  cols := 3;
										| 12:
												rows := 3;  cols := 4
										ELSE cols := 1;  rows := count
										END;

										tc := 0;  tr := 0;  f := obj( Frame ).dsc;
										WHILE f # NIL DO
											IF f IS Picture THEN
												WITH f: Picture DO
													f.Pictx := tc / cols;  f.Picty := (rows - tr - 1) / rows;  f.Pictw := 1 / cols;  f.Picth := 1 / rows;
													AdjustPict( obj, f( Picture ) );  INC( tc );
													IF tc = cols THEN tc := 0;  INC( tr ) END
												END;
											ELSE
												(* change size of frame *)
											END;
											f := f.next
										END;
										Gadgets.Update( obj );  FrameDrawRect( FALSE );  msg.res := 0
									END
								END;
							ELSIF msg IS Oberon.InputMsg THEN
								WITH msg: Oberon.InputMsg DO
									Panels.PanelHandler( obj, msg );
									IF (obj.W # w) OR (obj.H # h) THEN  (* Panel size changed -> update *)
										Gadgets.Update( obj )
									END
								END;
							ELSE Panels.PanelHandler( obj, msg );  FrameDrawRect( FALSE )

							END  (* WITH msg:DisplayModify *)
						ELSE Panels.PanelHandler( obj, msg )

						END  (* IF msg.F=NIL *)
					END;
				ELSE Panels.PanelHandler( obj, msg )

				END  (* WITH msg.Display.Frame*)
			ELSE
				IF msg IS Objects.AttrMsg THEN
					WITH msg: Objects.AttrMsg DO FrameHandleAttributes( obj, msg )
					END;
				ELSE Panels.PanelHandler( obj, msg )
				END
			END  (* not msg IS Display.FrameMsg *)
		END  (* WITH obj: Frame DO *)

	END FrameHandler;

(** picture managment **)
	PROCEDURE AddPicture*( frame: Frame;  picture: Picture;  x, y, w, h: REAL );
	BEGIN
		picture.Pictx := x;  picture.Picty := y;  picture.Pictw := w;  picture.Picth := h;  picture.X := 0;  picture.Y := -picture.H;
		Panels.InsertChild( frame, picture, 0, 0 );   (*! adjust w,h *)
		AdjustPict( frame, picture );  SetFocusPicture( picture );  PictureUpdate( picture )
	END AddPicture;

	PROCEDURE RemovePicture*( frame: Frame;  picture: Picture );
	BEGIN
		Panels.RemoveChild( frame, picture )
	END RemovePicture;

(** Frame generation **)
	PROCEDURE SetDefaultFrameRatio*( framesPerLine, whRelation: REAL );
	(*? should also work on the focus frame? *)
	(*! Layla support *)
	BEGIN
		DfltFramesPLine := framesPerLine;  defFramehwRelation := whRelation
	END SetDefaultFrameRatio;

	PROCEDURE InitFrame( frame: Frame;  w, h: INTEGER );
	BEGIN
		frame.handle := FrameHandler;
		IF (w <= 0) OR (h <= 0) THEN
			w := SHORT( ENTIER( vyHostTexts.GetCurWidth() / DfltFramesPLine ) );  h := SHORT( ENTIER( w * defFramehwRelation + 0.5 ) )
		END;
		IF (w <= 0) OR (h <= 0) THEN  (* vyHostTexts.getCurWidth did not work *)
			w := DefaultWidth;  h := SHORT( ENTIER( w * defFramehwRelation + 0.5 ) )
		END;
		frame.X := 0;  frame.Y := -h;  frame.W := w;  frame.H := h;  frame.borderW := Border;
		INCL( frame.state, Gadgets.lockedcontents );   (*INCL(frame.state0,Panels.noinsert)*)
	END InitFrame;

	(*! reduce following routines *)
(*! reduce following routines *)
	PROCEDURE NewFrame*;   (*vs 0.0a2 fof 28.3.96*)  (* Gadgets.Insert vyPort.NewFrame *)
	(* Gadgets.Insert Panels.NewPanel *)

	(*= create a new frame, and deposit as Objects.NewObj. Focus is set to the new frame *)
	(*? is it safe to set the focus to the new frame even without showing it??*)
	BEGIN
		Panels.NewPanel;  newframe := Objects.NewObj( Frame );  InitFrame( newframe, 0, 0 );
		stdFrameCol := newframe.col;  focusFrame := NIL
	END NewFrame;

	PROCEDURE ResizeFrame*( f: Frame;  w, h: INTEGER );
	VAR M: Display.ModifyMsg;
	BEGIN
		M.W := w;  M.H := h;  M.X := f.X;  M.Y := f.Y;  M.dW := f.W - w;  M.dH := f.H - h;  M.dX := 0;  M.dY := 0;
		M.id := Display.extend;  M.mode := Display.display;  M.F := f;  Display.Broadcast( M );
		f.W := M.W;  f.H := M.H;   (*if not in display space*)
	END ResizeFrame;

	PROCEDURE XNewFrame*( w, h: INTEGER ): Frame;   (*vs 0.0a2 md 1995 & fof 19.3.96 *)
	(*= create a new frame *)
	BEGIN
		NewFrame;
		IF (w > 0) & (h > 0) THEN ResizeFrame( newframe, w, h ) END;
		focusFrame := newframe;  RETURN newframe
	END XNewFrame;

	PROCEDURE InsertNewFrame*( w, h: INTEGER ): Frame;
	BEGIN
		vyHostTexts.InsertGadget( XNewFrame( w, h ) );   (* ASSERT(newframe.lib # NIL); *)
		RETURN newframe
	END InsertNewFrame;

(** Picture **)


	PROCEDURE PictureUpdate*( picture: Picture );
	VAR msg: Display.DisplayMsg;
	BEGIN
		(*	Out.String("vyPort.PictureUpdate>");*)
		IF picture = NIL THEN RETURN END;
		picture.needsRedraw := TRUE;
		IF (~updatesuspend)
			THEN  (*vyHostTexts.Msg('PictureUpdate');*)
			msg.device := Display.full;  msg.id := Display.display;  msg.F := picture;  Display.Broadcast( msg )
		END
		(*	Out.String("<vyPort.PictureUpdate"); Out.Ln*)
	END PictureUpdate;

	PROCEDURE RedrawFocusPict*;   (* vyPort.RedrawFocusPict *)
	VAR msg: Display.DisplayMsg;
	BEGIN
		IF focusPicture # NIL THEN  (* ignore state of updatesuspend bit *)
			msg.device := Display.full;  msg.id := Display.display;  msg.F := focusPicture;  focusPicture.needsRedraw := TRUE;
			Display.Broadcast( msg )
		ELSE
			(*		Out.String('No focus picture'); Out.Ln *)
		END
	END RedrawFocusPict;

	PROCEDURE RedrawFocusFrame*;   (* vyPort.RedrawFocusFrame *)
	VAR msg: Display.DisplayMsg;
	BEGIN
		IF focusPicture # NIL THEN
			msg.device := Display.full;  msg.id := Display.display;  msg.F := focusFrame;
			IF focusPicture # NIL THEN focusPicture.needsRedraw := TRUE END;
			Display.Broadcast( msg )
		ELSE
			(*		Out.String('No focus frame'); Out.Ln*)
		END
	END RedrawFocusFrame;

	PROCEDURE UpdateHostPicture*( obj: tLayer;  VAR msg: Objects.ObjMsg );
	(* update user pictures *)
	VAR link: vyLinks.Link;
	BEGIN
	(* vyBase.Update(obj); *)  (*? double update ??? fof 001120, remove if no update *)
		(*	templayer := obj;*)
		link := obj.users;
		WHILE link # NIL DO
			IF (link.obj # NIL ) & (link.obj IS Picture) THEN PictureUpdate( link.obj( Picture ) ) END;
			link := link.link
		END
	END UpdateHostPicture;

	PROCEDURE FrontLayer( pict: Picture ): tLayer;
	VAR obj: Objects.Object;
	BEGIN
		obj := vyLinks.GetLastObj( pict.vylinks );
		IF obj = NIL THEN RETURN NIL ELSE RETURN obj( tLayer ) END
	END FrontLayer;

	PROCEDURE FocusLayer*( ): tLayer;
	BEGIN
	(*	IF (focusLayer = NIL) & (focusPicture # NIL) THEN focusLayer := FrontLayer(focusPicture) END;
	RETURN focusLayer*)
		(*? should we set focusLayer ? *)
		IF (focusLayer = NIL ) & (focusPicture # NIL ) THEN
			RETURN FrontLayer( focusPicture ) (* jb 4.11.00 instead of focusLayer := FrontLayer(focusPicture) *)
		ELSE RETURN focusLayer
		END
	END FocusLayer;

	PROCEDURE SetFrontMostLayer( pict: Picture;  layer: tLayer );
	(*! replace by generic procedure *)
	VAR ref, last: vyLinks.Link;
	BEGIN
		focusLayer := NIL;
		IF layer = FrontLayer( pict ) THEN RETURN END;
		ref := pict.vylinks;
		IF ref = NIL THEN vyHostTexts.Msg( "no layers found in picture" );  RETURN END;
		last := ref;
		WHILE last.link # NIL DO last := last.link END;
		IF last = ref THEN RETURN END;

		IF ref.obj = layer THEN pict.vylinks := ref.link;  last.link := ref;  ref.link := NIL
		ELSE
			WHILE (ref.link # NIL ) & (ref.link.obj # layer) DO ref := ref.link END;
			IF ref.link = NIL THEN vyHostTexts.Msg( "layer not found in picture" );  RETURN END;

			last.link := ref.link;  ref.link := ref.link.link;  last.link.link := NIL
		END;
		PictureUpdate( pict )
	END SetFrontMostLayer;

	PROCEDURE GetHeader( pict: Picture;  VAR header: vyName.tNameArray );
	VAR layer: tLayer;
	BEGIN
		header[0] := 0X;  layer := FrontLayer( pict );
		IF layer = NIL THEN COPY( "empty picture", header ) ELSE vyName.GetObjId( layer, header ) END;
		IF header[0] = 0X THEN COPY( "unknown object", header ) END
	END GetHeader;

(*PROCEDURE RemoveLayer* (picture: Picture; layer: tLayer);
(*? use remove link *)
VAR l: vyLinks.Link;
BEGIN
IF layer = NIL THEN RETURN END;
(*	IF layer(tLayer).host # picture THEN
vyHostTexts.Msg ("this layer does not belong to that picture!"); ASSERT (layer(tLayer).host = picture)
END;
*)
l := picture.vylinks;
IF l = NIL THEN vyHostTexts.Msg ("no such layer in this picture!"); RETURN END;
IF l.obj = layer THEN picture.vylinks := l.link; RETURN END;
WHILE (l.link # NIL) & (l.link.obj # layer) DO
l := l.link
END;
IF l.link = NIL THEN vyHostTexts.Msg ("no such layer in this picture!"); RETURN END;
l.link := l.link.link;
vyBase.UnSubscribe(layer, picture);
PictureUpdate (picture)
END RemoveLayer;
*)
	PROCEDURE RemoveLayer*( picture: Picture;  layer: tLayer );
	(*? use remove link *)
	VAR l: vyLinks.Link;
	BEGIN
		IF layer = NIL THEN RETURN END;
		(*	IF layer(tLayer).host # picture THEN
	vyHostTexts.Msg ("this layer does not belong to that picture!"); ASSERT (layer(tLayer).host = picture)
	END;
	*)
		l := picture.vylinks;
		IF l = NIL THEN vyHostTexts.Msg( "no such layer in this picture!" );  RETURN END;
		IF l.obj = layer THEN picture.vylinks := l.link ELSE
			WHILE (l.link # NIL ) & (l.link.obj # layer) DO l := l.link END;
			IF l.link = NIL THEN vyHostTexts.Msg( "no such layer in this picture!" );  RETURN END;
			l.link := l.link.link
		END;
		vyBase.UnSubscribe( layer, picture );  PictureUpdate( picture )
	END RemoveLayer;

	PROCEDURE AddLayer*( picture: Picture;  layer: tLayer );   (*! use vyLinks.InsertObj *)
	VAR ref, temp: vyLinks.Link;  adjcoord: AdjustCoordMsg;
	BEGIN
		IF picture = NIL THEN vyHostTexts.Msg( "layer added to a NIL picture!" );
			ASSERT ( picture # NIL )
		END;
		IF layer = NIL THEN vyHostTexts.Msg( "NIL layer added to picture!" );
			ASSERT ( layer # NIL )
		END;
		(*	IF layer.host # NIL THEN
	vyHostTexts.Msg ("this layer is already linked to another picture!"); ASSERT (layer.host = NIL)
	END;
	*)
		ref := NIL;  vyLinks.InsertObj( ref, layer );
		(*	ref.link := picture.vylinks; picture.vylinks := ref;*)
		(*? link *)
		IF picture.vylinks = NIL THEN picture.vylinks := ref
		ELSE
			temp := picture.vylinks;
			WHILE (temp.link # NIL ) DO temp := temp.link END;
			temp.link := ref
		END;
		(* ref.link := picture.vylinks; picture.vylinks := ref; *)

		(*	layer.host := picture; *)
		IF picture.lib # NIL THEN Gadgets.BindObj( layer, picture.lib ) END;
		vyBase.Subscribe( (*for messages from source*) layer, picture );   (*templayer := layer;*)
		(*	IF templayer.users # NIL THEN Out.String("Subscribe success ") ELSE Out.String("Subscribe no success ") END;*)
		(* AdjustLayerCoordinates(picture, layer);*)
		layer.dlink := picture;   (*? seems to be used for PictureUpdate. Remove dependency !*)
		adjcoord.pict := picture;  adjcoord.layer := layer;  layer.handle( layer, adjcoord );  PictureUpdate( picture )
	END AddLayer;
(*
PROCEDURE AddFocusLayer* (layer: tLayer);
BEGIN
AddLayer(focusPicture, layer)
END AddFocusLayer;
*)

	PROCEDURE PictureHandleSetPicture*( pict: Picture );
	VAR x, y, w, h: INTEGER;  cRgnMsg: vyDisplay2d.CoordRgnMessage;  cSetMsg: vyDisplay2d.CoordSetMessage;
	BEGIN
		(* changed by fof , 001205 , picture sets screen region, mask and coordinate system origin *)
		GetPictureScreenRegion( pict, x, y, w, h );  vyGraphBase.UseClipMask( pict.mask );
		IF (pict.gcontext # NIL ) & (pict.gcontext.handle # NIL ) THEN
			cRgnMsg.X := x;  cRgnMsg.Y := y;  cRgnMsg.W := w;  cRgnMsg.H := h;  cRgnMsg.dlink := pict;  cSetMsg.dlink := pict;
			pict.gcontext.handle( pict.gcontext, cSetMsg );   (* fof 0103xx: Ordering *)
			pict.gcontext.handle( pict.gcontext, cRgnMsg )
		END
		(*
	(* vyGraphBase.SetClipRect (x, y, w, h); *)
	IF pict.gcontext.handle # NIL THEN pict.gcontext.handle (pict.gcontext, set) END*)
	END PictureHandleSetPicture;

	PROCEDURE GetHeaderRect( picture: Picture;  VAR x, y, w, h: INTEGER );
	VAR header: vyName.tNameArray;  dsr: INTEGER;
	BEGIN
		GetHeader( picture, header );  GetPictureScreenRegion( picture, x, y, w, h );
		vyGraphBase.SetStringJustification( vyGraphBase.left, vyGraphBase.top );
		vyGraphBase.GetStringFrame( x + picture.hx, y + h + picture.hy, "Syntax10.Scn.Fnt", header, x, y, w, h, dsr )
	END GetHeaderRect;

	PROCEDURE CopyLayerOver( picture: Picture;  layer: tLayer;  list: vyTracking.List );
	VAR dx, dy, x, y: INTEGER;  remoteP: Picture;  cloneMess: Objects.CopyMsg;
	BEGIN
		antsEffects.Help( "Hold Buttons and shift to dest Port" );  focusLayer := NIL;  cloneMess.id := 1;

		antsEffects.MoveListEntry( list, x, y, dx, dy );

		IF (dx # 0) OR (dy # 0) THEN
			remoteP := GetPictureXY( NIL , x, y );
			IF (remoteP # NIL ) & (remoteP # picture) THEN Objects.Stamp( cloneMess );
				ASSERT ( layer.handle # NIL );
				layer.handle( layer, cloneMess );
				IF cloneMess.obj # NIL THEN
					AddLayer( remoteP, cloneMess.obj( tLayer ) );  undoPict := remoteP( Picture );
					undoLayer := cloneMess.obj( tLayer );  undoAction := ActionLayerCopy

				END
			END
		END;
		antsEffects.HelpEnd
	END CopyLayerOver;

	PROCEDURE HeaderEdit( picture: Picture;  VAR event: vyEvents.EventMsg );
	VAR x, y, w, h: INTEGER;  selLayer: tLayer;  res, list: vyTracking.List;  selName: vyName.tNameArray;
		(*picture: vyPort.tPicture;*)
		PROCEDURE GetList( ): vyTracking.List;
		VAR list, e: vyTracking.List;  name: vyName.tNameArray;  layer: vyLinks.Link;
		BEGIN
			layer := picture.vylinks;
			IF layer # NIL THEN NEW( list );  e := list END;
			WHILE layer # NIL DO
				vyName.GetObjId( layer.obj( vyBase.Object ), name );  COPY( name, e.name );
				IF layer.link # NIL THEN NEW( e.next );  e := e.next END;
				layer := layer.link
			END;
			RETURN list
		END GetList;

		PROCEDURE GetLayer( start, e: vyTracking.List ): tLayer;
		VAR temp: vyTracking.List;  layer: vyLinks.Link;
		BEGIN
			temp := start;  layer := picture.vylinks;
			WHILE layer # NIL DO
				IF e = temp THEN RETURN layer.obj( tLayer ) END;
				temp := temp.next;  layer := layer.link
			END
		END GetLayer;

	BEGIN
		antsEffects.Help( "Header Edit: Hold RM to select front layer, RM+LM: delete layer, RM+MM: copy layer" );  vyGraphBase.SetStyle( vyGraphBase.defaultStyle );  GetHeaderRect( picture, x, y, w, h );
		(* vyGraphBase.SetClipRect (0, 0, vyGraphBase.DisplayWidth, vyGraphBase.DisplayHeight); *)
		list := GetList();  vyTracking.ScrollList( list, x, y + h, res );
		IF res = NIL THEN antsEffects.HelpEnd;  RETURN END;
		selLayer := GetLayer( list, res );
		IF selLayer # NIL THEN
			WHILE event.gesture = vyEvents.EvtSelect DO vyEvents.GetEvent( event ) END;
			IF event.gesture = vyEvents.EvtEmpty THEN SetFrontMostLayer( picture, selLayer )
			ELSIF event.gesture = vyEvents.EvtRemove THEN
				RemoveLayer( picture, selLayer );  undoPict := picture;  undoLayer := selLayer;  undoAction := ActionLayerRemove
			ELSIF event.gesture = vyEvents.EvtCopy THEN
				IF selLayer # NIL THEN Out.Ln;  Out.String( "#NIL" ) END;
				CopyLayerOver( picture, selLayer, res )
			END
		ELSE vyHostTexts.NoteSS( 0, "selected layer not found", selName )
		END;

		REPEAT vyEvents.GetEvent( event )
		UNTIL event.gesture = vyEvents.EvtEmpty;
		antsEffects.HelpEnd
	END HeaderEdit;

	PROCEDURE ReverseOrdered( link: vyLinks.Link ): vyLinks.Link;
	(*! move to vyLinks *)
	VAR nlink: vyLinks.Link;
	BEGIN
		WHILE (link # NIL ) DO vyLinks.InsertFirstLink( nlink, link );  link := link.link END;
		RETURN nlink
	END ReverseOrdered;

	PROCEDURE GetResponder( picture: Picture;  VAR msg: vyEvents.EventMsg );
	BEGIN
		msg.callForResponder := TRUE;  msg.responder := NIL;  msg.priority := vyEvents.PrioNone;
		msg.dlink := picture;   (*! bubble up. Should be set by message sender *)
		vyLinks.ToLinks( ReverseOrdered( picture.vylinks ), msg );   (* order must be set like in header !*)
		msg.callForResponder := FALSE
	END GetResponder;


(* menu handling *)

	PROCEDURE storepictasgif;
	VAR res: INTEGER;
	BEGIN
		antsCommandList.Wait();  Out.Ln;  Out.String( "Calling storepictasgif" );  antsCommandList.noWait := TRUE;
		Oberon.Call( "antsToolbox.FocusPictToGIF", Oberon.Par, FALSE , res );
		IF res # 0 THEN Out.Ln;  Out.String( "Storing GIF Images not available." ) END
	END storepictasgif;

	PROCEDURE setfrontmost;
	BEGIN
		antsCommandList.Wait();
		SetFrontMostLayer( focusPicture, antsCommandList.res( antsCommandList.List ).obj( tLayer ) );
		setfrontmostcalled := TRUE
		(*
	IF event.gesture = vyEvents.EvtEmpty THEN SetFrontMostLayer (picture, selLayer)
	ELSIF event.gesture = vyEvents.EvtRemove THEN
	RemoveLayer (picture, selLayer);
	undoPict := picture; undoLayer := selLayer; undoAction := ActionLayerRemove
	ELSIF event.gesture = vyEvents.EvtCopy THEN
	IF selLayer # NIL THEN Out.Ln; Out.String("#NIL"); END;
	CopyLayerOver (picture, selLayer, res);
	END
	*)
	END setfrontmost;

	PROCEDURE delfrontlayer;
	VAR l: tLayer;
	BEGIN
		antsCommandList.Wait();  l := FrontLayer( focusPicture );  RemoveLayer( focusPicture, l );  undoPict := focusPicture;
		undoLayer := l;  undoAction := ActionLayerRemove

	END delfrontlayer;

	PROCEDURE CopyLayerEasy( picture: Picture;  layer: tLayer );
	VAR dx, dy, x, y: INTEGER;  remoteP: Picture;  cloneMess: Objects.CopyMsg;  keys: SET;
	BEGIN
		focusLayer := NIL;  cloneMess.id := 1;

		(*
	antsEffects.MoveListEntry (list, x, y, dx, dy);
	*)
		Input.Mouse( keys, x, y );  dx := x;  dy := y;  antsEffects.TrackMouseCont( keys, x, y, Effects.CopyHand );  dx := dx - x;
		dy := dy - y;

		IF (dx # 0) OR (dy # 0) THEN
			remoteP := GetPictureXY( NIL , x, y );
			IF (remoteP # NIL ) & (remoteP # picture) THEN Objects.Stamp( cloneMess );
				ASSERT ( layer.handle # NIL );
				layer.handle( layer, cloneMess );
				IF cloneMess.obj # NIL THEN
					AddLayer( remoteP, cloneMess.obj( tLayer ) );  undoPict := remoteP( Picture );
					undoLayer := cloneMess.obj( tLayer );  undoAction := ActionLayerCopy

				END
			END
		END
	END CopyLayerEasy;

	PROCEDURE copyfrontlayer;
	BEGIN
		antsCommandList.Wait();  CopyLayerEasy( focusPicture, FrontLayer( focusPicture ) )
	END copyfrontlayer;

	PROCEDURE coordcopy*;
	VAR dx, dy, x, y: INTEGER;  keys: SET;  remoteP: Picture;
	BEGIN
		antsCommandList.Wait();  Input.Mouse( keys, x, y );  dx := x;  dy := y;
		antsEffects.TrackMouseCont( keys, x, y, Effects.CopyHand );  dx := dx - x;  dy := dy - y;

		IF (dx # 0) OR (dy # 0) THEN
			remoteP := GetPictureXY( NIL , x, y );
			IF (remoteP # NIL ) & (remoteP # focusPicture) THEN
				IF (remoteP.gcontext # NIL ) &
				    (vyPortability.TypeOf( remoteP.gcontext ) = vyPortability.TypeOf( focusPicture.gcontext )) THEN
					vyBase.UnSubscribe( remoteP.gcontext, remoteP );  remoteP.gcontext := focusPicture.gcontext;
					vyBase.Subscribe( remoteP.gcontext, remoteP );  vyBase.Update( remoteP.gcontext )
				ELSE vyHostTexts.Note( vyHostTexts.cWarning, "cannot adopt coordinate system, not of same type !" )
				END
			END
		END
	END coordcopy;

	PROCEDURE nextlayer;
	VAR ref: vyLinks.Link;
	BEGIN
		antsCommandList.Wait();

		ref := focusPicture.vylinks;
		(* WHILE(ref.link) # NIL DO ref := ref.link END; *)

		SetFrontMostLayer( focusPicture, ref.obj( tLayer ) );  setfrontmostcalled := TRUE
	END nextlayer;

	PROCEDURE switch;
	VAR l: antsCommandList.List;  event: vyEvents.EventMsg;

		PROCEDURE Menu( event: vyEvents.EventMsg );
		VAR front: tLayer;
			name: ARRAY 256 OF CHAR;
		BEGIN
			antsCommandList.Wait();  l := NIL;  front := FrontLayer( focusPicture );
			IF front = NIL THEN RETURN END;
			antsCommandList.Add( l, NIL , "done" );  vyName.GetObjId( front, name );  vyStrings.Append( name, ", next _>" );
			antsCommandList.Add( l, nextlayer, name );  setfrontmostcalled := FALSE;
			antsCommandList.ExecuteListedCommand( event.x, event.y, event, l );
			IF (setfrontmostcalled) THEN Menu( event ) END
		END Menu;

	BEGIN
		vyEvents.GetEvent( event );  Menu( event );  setfrontmostcalled := FALSE
	END switch;

	PROCEDURE layersmenu*;
	VAR l: antsCommandList.List;  event: vyEvents.EventMsg;

		PROCEDURE GetList( p: Picture ): antsCommandList.List;
		VAR list, e, temp: antsCommandList.List;  name: vyName.tNameArray;  layer: vyLinks.Link;  pos: INTEGER;
		BEGIN
			pos := 0;  layer := p.vylinks;
			IF layer # NIL THEN NEW( list );  e := list END;
			WHILE layer # NIL DO
				vyName.GetObjId( layer.obj( vyBase.Object ), name );
				IF layer.link = NIL THEN
					e.obj := NIL;  e.command := NIL;  e.name := antsCommandList.emptyLine;  NEW( temp );  e.next := temp;  e := temp
				END;
				COPY( name, e.name );  e.obj := layer.obj;  e.command := setfrontmost;
				IF layer.link # NIL THEN NEW( temp );  e.next := temp;  e := temp END;
				layer := layer.link;  INC( pos )
			END;
			RETURN list
		END GetList;

		PROCEDURE Menu( event: vyEvents.EventMsg );
		VAR front: tLayer;
		BEGIN
			l := GetList( focusPicture );  antsCommandList.Wait();

			antsCommandList.Init( l, event.x, event.y );  front := FrontLayer( focusPicture );
			IF (front # NIL ) & (front.handle # NIL ) THEN front.handle( front, antsCommandList.msg ) END;

			(*vyLinks.ToLinks (ReverseOrdered(focusPicture.vylinks), antsCommandList.msg); *)

			l := antsCommandList.dynamic;

			antsCommandList.Add( l, NIL , antsCommandList.emptyLine );
			IF front # NIL THEN
				antsCommandList.Add( l, switch, "cycle layers" );  antsCommandList.Add( l, delfrontlayer, "remove front Layer " );
				antsCommandList.Add( l, copyfrontlayer, "copy front Layer " )
			END;
			IF (undoAction # 0) & (undoPict = focusPicture) THEN antsCommandList.Add( l, Undo, "undo removing" ) END;
			antsCommandList.Add( l, NIL , antsCommandList.emptyLine );  setfrontmostcalled := FALSE;
			antsCommandList.ExecuteListedCommand( event.x, event.y, event, l );
			IF (antsCommandList.res # NIL ) & (setfrontmostcalled) THEN Menu( event ) END

		END Menu;

	BEGIN
		vyEvents.GetEvent( event );  Menu( event )
	END layersmenu;

	PROCEDURE alllayers;
	VAR l: antsCommandList.List;  event: vyEvents.EventMsg;

		PROCEDURE Menu( event: vyEvents.EventMsg );
		VAR front: tLayer;
		BEGIN
			antsCommandList.Wait();

			antsCommandList.Init( l, event.x, event.y );  front := FrontLayer( focusPicture );

			vyLinks.ToLinks( ReverseOrdered( focusPicture.vylinks ), antsCommandList.msg );

			l := antsCommandList.dynamic;

			antsCommandList.ExecuteListedCommand( event.x, event.y, event, l );
		END Menu;

	BEGIN
		vyEvents.GetEvent( event );  Menu( event );
	END alllayers;

	PROCEDURE ContextResponding( picture: Picture;  VAR msg: vyEvents.EventMsg ): BOOLEAN;

	VAR layerresp: Objects.Object;  contextmenu: antsCommandList.List;  front: tLayer;
	BEGIN
		IF picture.gcontext = NIL THEN RETURN FALSE END;
		contextmenu := NIL;  antsCommandList.Init( contextmenu, msg.x, msg.y );

		antsCommandList.current := contextmenu;

		front := FrontLayer( focusPicture );
		IF (front # NIL ) & (front.handle # NIL ) THEN front.handle( front, antsCommandList.msg ) END;

		(*
	IF (focusPicture.vylinks # NIL) & (focusPicture.vylinks.obj # NIL) & (focusPicture.vylinks.obj.handle # NIL)THEN
	focusPicture.vylinks.obj.handle(focusPicture.vylinks.obj,antsCommandList.msg);
	END;

	vyLinks.ToLinks (ReverseOrdered(picture.vylinks), antsCommandList.msg);
	*)
		contextmenu := antsCommandList.dynamic;

		antsCommandList.Add( contextmenu, lock, "Lock" );  antsCommandList.Add( contextmenu, adjust, "try to adjust to data" );
		antsCommandList.Add( contextmenu, showcopy, "view a copy" );  antsCommandList.Add( contextmenu, storepictasgif, "store frame as GIF" );
		antsCommandList.Add( contextmenu, coordcopy, "send coordinate system" );  antsCommandList.Add( contextmenu, layersmenu, "Layer operations ____>" );
		antsCommandList.Add( contextmenu, alllayers, "All Layer ops ____>" );

		antsCommandList.current := contextmenu;  msg.callForResponder := TRUE;  layerresp := msg.responder;
		(* msg.responder := NIL; *)
		msg.priority := vyEvents.PrioNone;  msg.dlink := picture;
		IF picture.gcontext.handle # NIL THEN picture.gcontext.handle( picture.gcontext, msg ) END;
		IF layerresp = msg.responder THEN msg.responder := NIL END;
		IF msg.responder # NIL THEN msg.callForResponder := FALSE END;
		IF msg.responder # NIL THEN RETURN TRUE ELSE RETURN FALSE END
	END ContextResponding;

	PROCEDURE PictureHandleEventMsg( picture: Picture;  VAR event: vyEvents.EventMsg );
	VAR cRgnMsg: vyDisplay2d.CoordRgnMessage;  cSetMsg: vyDisplay2d.CoordSetMessage;  x, y, w, h: INTEGER;
		pictEvent: vyEvents.EventMsg;  copy: vyEvents.EventMsg;  dlink: Objects.Object;
	BEGIN
		SetFocusPicture( picture );  dlink := event.dlink;  event.dlink := picture;  pictEvent.dlink := picture;
		GetPictureScreenRegion( picture, x, y, w, h );
		(*
	Out.String("vyPort.PictureHandleEventMsg Picture coordinates "); Out.Int(x, 6); Out.Int(y, 6); Out.Int(w, 6); Out.Int(h, 6); Out.String(" Event coordinates: "); Out.Int(event.x, 6); Out.Int(event.y, 6);Out.Ln();
	*)
		IF (picture.gcontext # NIL ) & (picture.gcontext.handle # NIL ) THEN
			cRgnMsg.X := x;  cRgnMsg.Y := y;  cRgnMsg.W := w;  cRgnMsg.H := h;  cRgnMsg.dlink := picture;
			cSetMsg.dlink := picture;

			picture.gcontext.handle( picture.gcontext, cSetMsg );   (* fof 0103xx Ordering *)
			picture.gcontext.handle( picture.gcontext, cRgnMsg )
		END;
		GetHeaderRect( picture, x, y, w, h );
		IF (event.gesture = vyEvents.EvtSelect) & (vyRectangles.PointInRect( event.x, event.y, x, y, w, h )) THEN
			HeaderEdit( picture, event )
		ELSE
			vyEvents.GetEvent( pictEvent );  copy := pictEvent;  GetResponder( picture, pictEvent );
			IF ContextResponding( picture, pictEvent ) THEN
				picture.gcontext.handle( picture.gcontext, pictEvent )
				(* IF (pictEvent.gesture = vyEvents.EvtLoc) & (picture.gcontext # NIL) & (picture.gcontext.handle # NIL) THEN
			antsEffects.Help("LM: shift coordinate system, LM+RM: zoom in, LM+MM: zoom out");
			GetResponder (picture, pictEvent);
			SetFrontMostLayer (picture, FrontLayer(picture));
			picture.gcontext.handle (picture.gcontext, pictEvent);
			antsEffects.HelpEnd; 		Oberon.FadeCursor(Oberon.Mouse); Oberon.OpenCursor(Oberon.Pointer);
			ELSIF (pictEvent.gesture = vyEvents.EvtSelect) OR (pictEvent.gesture = vyEvents.EvtIdent) THEN *)
			END;
			picture.gcontext.handle( picture.gcontext, cSetMsg );   (* fof 0103xx Ordering *)
			picture.gcontext.handle( picture.gcontext, cRgnMsg );
			IF pictEvent.callForResponder THEN
			(*IF (pictEvent.gesture = vyEvents.EvtSelect) THEN
			antsEffects.Help("RM: select, action depends on front layer");
			ELSE
			antsEffects.Help("MM: identify, action depends on front layer");
			END;
			*)
			(*
			Out.String('vyPort.PictureHandleEventMsg: looking for responder');Out.Ln;
			*)
			(* vyEvents.ClearCurrentEvent; *)  (*! fof 020323 *)
				vyEvents.GetEvent( pictEvent );  GetResponder( picture, pictEvent );
				IF pictEvent.responder # NIL THEN
					(*Out.String('vyPort.PictureHandleEventMsg: got responder');Out.Ln;*)
					pictEvent.dlink := picture;  SetFrontMostLayer( picture, pictEvent.responder( tLayer ) );
					pictEvent.responder.handle( pictEvent.responder, pictEvent )
				ELSE antsCommandList.Wait()
				END;
				(*antsEffects.HelpEnd; *) Oberon.FadeCursor( Oberon.Mouse );  Oberon.OpenCursor( Oberon.Pointer )
			END
		END;
		event.dlink := dlink
	END PictureHandleEventMsg;

	PROCEDURE PictureHandleInputMsg( obj: Picture;  VAR msg: Oberon.InputMsg;  x, y, w, h: INTEGER );
	VAR event: vyEvents.EventMsg;  Q: Display3.Mask;
	BEGIN
		(*Out.String('vyPort.PictureHandleInputMsg'); Out.Ln;*)
		Gadgets.MakeMask( obj, x, y, msg.dlink, Q );  vyGraphBase.UseClipMask( Q );
		IF Gadgets.InActiveArea( obj, msg ) THEN
		(*vyGraphBase.SetCursor (vyGraphBase.DefPoint); (* changed for better identifciation*)
		vyGraphBase.DrawCursor (msg.X, msg.Y);*)
			(* uncomment for debugging only.*)

			IF msg.keys # {} THEN  (*Out.String('vyPort.PictureHandleInputMsg Event'); Out.Ln;*)
				IF 31 IN msg.keys THEN
					vyEvents.GetWheelEvent( event, msg.ch = 0C1X );  obj.handle( obj, event );
					IF obj.hotupdate THEN updatesuspend := FALSE;  PictureUpdate( obj ) END;
					vyEvents.ClearCurrentEvent();

				ELSE
					vyEvents.GetEvent( event );  obj.handle( obj, event );
					IF obj.hotupdate THEN updatesuspend := FALSE;  PictureUpdate( obj ) END;
					vyEvents.ClearCurrentEvent();
				END;
				(*Out.String('vyPort.PictureHandleInputMsg Event done'); Out.Ln;*)
				msg.res := 0

			ELSE vyBase.framehandle( obj, msg )
			END
		ELSE
			(*Out.String('vyPort.PictureHandleInputMsg not in active area'); Out.Ln;*)
			vyBase.framehandle( obj, msg )
		END
		(* Out.String('vyPort.PictureHandleInputMsg done'); Out.Ln; *)
	END PictureHandleInputMsg;

	PROCEDURE PictureHandleExtract( picture: Picture;  VAR msg: ExtractContentMsg );
	VAR event: vyEvents.EventMsg;  dlink: Objects.Object;
	BEGIN
		dlink := msg.dlink;  msg.dlink := picture;

		vyEvents.GetEvent( event );  GetResponder( picture, event );
		IF event.responder # NIL THEN event.responder.handle( event.responder, msg ) END;
		msg.dlink := dlink
	END PictureHandleExtract;

	PROCEDURE PictureHandleConsume( ppict: Picture;  VAR msg: Display.ConsumeMsg );
	VAR cmsg: Display.ConsumeMsg;  layerRef: vyLinks.Link;  dlink: Objects.Object;
	BEGIN
		dlink := msg.dlink;  msg.dlink := ppict;  cmsg.obj := vyConsume.DataFromMsg( msg, ppict.obj );  cmsg.res := msg.res;
		IF cmsg.obj = NIL THEN cmsg.obj := msg.obj END;   (* paranoia *)
		cmsg.dlink := ppict;  layerRef := ppict.vylinks;
		WHILE layerRef # NIL DO
			IF layerRef.obj( tLayer ).handle # NIL THEN layerRef.obj.handle( layerRef.obj( tLayer ), cmsg ) END;
			layerRef := layerRef.link
		END;
		PictureUpdate( ppict );  msg.dlink := dlink;  msg.res := cmsg.res
	END PictureHandleConsume;

	PROCEDURE PictureHandleUpdate( ppict: Picture );
	VAR cmsg: Display.ConsumeMsg;  layerRef: vyLinks.Link;
	BEGIN
		cmsg.obj := vyConsume.DataFromObj( ppict.obj, ppict.obj );
		IF cmsg.obj = NIL THEN cmsg.obj := ppict.obj END;   (* paranoia *)
		cmsg.dlink := ppict;  layerRef := ppict.vylinks;
		WHILE layerRef # NIL DO
			IF layerRef.obj( tLayer ).handle # NIL THEN layerRef.obj.handle( layerRef.obj( tLayer ), cmsg ) END;
			layerRef := layerRef.link
		END;
		PictureUpdate( ppict )
	END PictureHandleUpdate;
(*
PROCEDURE PictureReset (pict: Picture; VAR msg: ResetMsg);
VAR rmsg : ResetMsg; layerRef: vyLinks.Link; dlink: Objects.Object;
BEGIN
dlink := msg.dlink; msg.dlink := pict; rmsg.dlink := pict;
layerRef := pict.vylinks;
WHILE layerRef # NIL DO
IF layerRef.obj(tLayer).handle # NIL THEN
layerRef.obj.handle (layerRef.obj(tLayer), rmsg)
END;
layerRef := layerRef.link
END;
msg.dlink := dlink
END PictureReset;
*)
	PROCEDURE ToGContext( F: Picture;  VAR M: Objects.AttrMsg );
	VAR dlink: Objects.Object;
	BEGIN
		dlink := M.dlink;  M.dlink := F;  F.gcontext.handle( F.gcontext, M );  M.dlink := dlink
	END ToGContext;
(*

PROCEDURE PictureHandleDisplay (obj: Picture; VAR msg: Display.DisplayMsg; 	x, y, w, h: INTEGER
);
VAR 	Q: Display3.Mask;

PROCEDURE PictureDraw ( (* obj:Picture; x,y,w,h:INTEGER; *) print: BOOLEAN; gif: BOOLEAN);
(*! reduce *)
VAR layerRef: vyLinks.Link; header: vyName.tNameArray;
dmsg: Display.DisplayMsg; cMsg: vyDisplay2d.CoordRgnMessage; cSetMsg: vyDisplay2d.CoordSetMessage;
i, r, g, b: INTEGER;
draw: BOOLEAN;

PROCEDURE PictureDrawRect ; (*! move to HostDisplay *)
VAR oldsize: INTEGER;
BEGIN 		vyGraphBase.SetDisplayMode (vyGraphBase.replace);
IF print THEN vyGraphBase.SetForeColor(14) ELSE vyGraphBase.SetForeColor(0) END;
vyGraphBase.SetBackColor(12);
vyGraphBase.GetPenSize(oldsize); 		vyGraphBase.SetPenSize(obj.borderW);
IF obj.borderW >0 THEN (*! improve *)
(*	ASSERT(obj.defunctx = x, 100); ASSERT(obj.defuncty = y, 101);
vyGraphBase.ShadowRect (obj.defunctx, obj.defuncty, obj.W, obj.H);*)
vyGraphBase.ShadowRect (x, y, obj.W, obj.H);
END;

vyGraphBase.SetPenSize(oldsize)
END PictureDrawRect;
(* alternate version:
IF print THEN vyGraphBase.rect3d(14(*fcol*),12(*bcol*),x,y,w,h,ppict.border,vyGraphBase.replace)
ELSE vyGraphBase.rect3d(14(*fcol*),10(*bcol*),x,y,w,h,ppict.border,vyGraphBase.replace) END;
*)

BEGIN (* PictureDraw *)
(*	Out.String('Enter vyPort.PictureDraw '); Out.Int(x, 4); Out.Int(y, 4); Out.Int(w, 4); Out.Int(h, 4);*)
(*! simplify setup *)
ASSERT(w > 0, 100); ASSERT(h > 0, 101);
(*	IF ~obj.needsRedraw THEN Out.String(' no') ELSE END; Out.String(' needsRedraw'); Out.Ln;*)
dmsg.device := 0; (*screen*)dmsg.id := 1; dmsg.dlink := obj;
draw := TRUE;
vyGraphBase.SetStyle(vyGraphBase.defaultStyle);
PictureDrawRect; (*! move later *)

vyGraphBase.SetStyle(vyGraphBase.defaultStyle);
(* GetPictureScreenRegion (obj, x, y, w, h); *)
IF ~print THEN (*vyGraphBase.SetClipRect(x, y, w, h) *) END;
IF (obj.gcontext # NIL) & (obj.gcontext.handle # NIL) THEN
cMsg.X := x; cMsg.Y := y; cMsg.W := w; cMsg.H := h;
obj.gcontext.handle (obj.gcontext, cSetMsg);
obj.gcontext.handle (obj.gcontext, cMsg)
END;
vyGraphBase.SetForeColor (15); vyGraphBase.SetDisplayPattern(Display.solid); (*? remove? *)
vyGraphBase.SetPenSize (1); (*? remove? *)
vyGraphBase.FrameRect (x, y, w, h); (*? better: vyGraphBase.rect(15 (*fcol*), Display.solid, x,y,w,h,1, vyGraphBase.replace); *)
IF ~print THEN (* vyGraphBase.SetClipRect(x + 1, y + 1, w - 2, h - 2)*) END;
(* db *)
IF ~print & (* vyGraphBase.db.active*) vyGraphBase.UseDoubleBuffering THEN
IF (obj.dbPict = NIL) OR (obj.dbPict.width # w) OR (obj.dbPict.height # h ) THEN
NEW(obj.dbPict); Pictures.Create(obj.dbPict, w, h, 8); (*! support variable depth from Display !!! *)
FOR i := 0 TO 255 DO Display.GetColor(i, r, g, b); Pictures.SetColor(obj.dbPict, i, r, g, b) END
ELSIF ~obj.needsRedraw THEN draw := FALSE
END;
vyGraphBase.enableDB(obj.dbPict, x, y)
END;
IF draw THEN
vyGraphBase.SetBackColor (obj.backGround);
(*		Out.String('drawbg '); Out.Int(vyGraphBase.S.bcol, 4); Out.Ln;*)

vyGraphBase.EraseRect (x + obj.borderW, y + obj.borderW, w - 2 * obj.borderW, h - 2 * obj.borderW);
(* db *)
layerRef := obj.vylinks;
WHILE layerRef # NIL DO
IF layerRef.obj.handle # NIL THEN
layerRef.obj(tLayer).style.bcol := obj.backGround;
vyGraphBase.SetStyle(layerRef.obj(tLayer).style);
layerRef.obj.handle (layerRef.obj, dmsg)
END;
layerRef := layerRef.link
END;
IF obj.header & ((~print & ~gif) OR PrintHeaders) THEN
vyGraphBase.SetStringJustification (vyGraphBase.left, vyGraphBase.top);
vyGraphBase.SetForeColor (15); vyGraphBase.SetBackColor(obj.backGround);
GetHeader (obj, header);
vyGraphBase.String (x + obj.hx, y + h + obj.hy, "Syntax10.Scn.Fnt", header)
END
END;
(*! move here PictureDrawRect; *)
IF ~print & (* vyGraphBase.db.active*) vyGraphBase.UseDoubleBuffering & ~gif THEN
vyGraphBase.WriteDB(1, 1, w - 2, h - 2, x + 1, y + 1); 	vyGraphBase.disableDB
END;
IF gif THEN vyGraphBase.disableDB END;
obj.needsRedraw := FALSE
END PictureDraw;

BEGIN (* PictureHandleDisplay *)

ASSERT(msg.x + obj.X = x, 102); ASSERT(msg.y + obj.Y = y, 103);

x := msg.x + obj.X; y := msg.y + obj.Y; w := obj.W; h := obj.H;
(**	IF x#obj.defunctx THEN
Out.String('Enter vyPort.PictureHandleDisplay '); Out.Int(x, 4); Out.Int(y, 4); Out.Int(w, 4); Out.Int(h, 4); Out.Ln;
Out.Int(obj.defunctx, 4); Out.Int(obj.defuncty, 4); Out.Ln;

END;
*)
IF msg.device = Display.screen THEN
Gadgets.MakeMask(obj, x, y, msg.dlink, Q);
(*						IF x#obj.defunctx THEN
Out.String('Pos1 vyPort.PictureHandleDisplay '); Out.Int(x, 4); Out.Int(y, 4); Out.Int(w, 4); Out.Int(h, 4); Out.Ln;
Out.Int(obj.defunctx, 4); Out.Int(obj.defuncty, 4); Out.Ln;

END;
*)
(*		ASSERT(obj.defunctx = x,100);ASSERT(obj.defuncty = y,101);*)
(*		Display3.FillPattern(Q, Display3.blue,
Display.ticks, x, y, x, y, w, h, Display.paint);*)
(*				obj.defunctx := x; obj.defuncty := y; *)
IF (msg.id = Display.full) OR (msg.F = NIL) THEN (* gs *)

(* obj.x := x; obj.y := y; *)
ELSIF msg.id = Display.area THEN
Display3.AdjustMask(Q, x + msg.u, y + h - 1 + msg.v, msg.w, msg.h)
END;
(*	Display3.FillPattern(Q,Display3.white,
Display3.selectpat, x, y, x, y, obj.W, obj.H, Display.paint); (*? needed? *)*)

vyGraphBase.UseClipMask(Q);
Oberon.FadeCursor(Oberon.Mouse);
PictureDraw ( FALSE, FALSE);

IF Gadgets.selected IN obj.state THEN
Display3.FillPattern(Q, Display3.white,
Display3.selectpat, x, y, x, y, w, h, Display.paint)
END

ELSIF (msg.device = Display.printer) THEN (* fof *)
Gadgets.MakePrinterMask(obj, msg.x, msg.y, msg.dlink, Q);
vyGraphBase.SetScreenCoordinate;
vyGraphBase.OpenPrinter (msg.x, msg.y, x, y);
vyGraphBase.UseClipMask(Q);
PictureDraw (TRUE, FALSE);
vyGraphBase.ClosePrinter
END
END PictureHandleDisplay;
*)
	PROCEDURE PictureHandleDisplay( obj: Picture;  VAR msg: Display.DisplayMsg );
	VAR Q: Display3.Mask;  x, y, w, h: INTEGER;  bcr, bcg, bcb: INTEGER;

		PROCEDURE PictureDraw( print: BOOLEAN;  gif: BOOLEAN );
		VAR layerRef: vyLinks.Link;  header: vyName.tNameArray;  dmsg: Display.DisplayMsg;
			cMsg: vyDisplay2d.CoordRgnMessage;  cSetMsg: vyDisplay2d.CoordSetMessage;  db, tl: BOOLEAN;  draw: BOOLEAN;

			PROCEDURE PictureDrawRect;
			VAR oldsize: INTEGER;  bw: INTEGER;
			BEGIN
				IF obj.borderW > 0 THEN
					vyGraphBase.SetDisplayMode( vyGraphBase.replace );  vyGraphBase.SetForeColor( vyGraphBase.black );
					vyGraphBase.GetPenSize( oldsize );  bw := obj.borderW;
					IF (2 * bw > w) OR (2 * bw > h) THEN bw := 1 END;
					vyGraphBase.SetPenSize( bw );
					IF obj = focusPicture THEN vyGraphBase.SetForeColor( vyGraphBase.red );  END;
					vyGraphBase.FrameRect( x, y, w, h );
					IF obj = focusPicture THEN vyGraphBase.SetForeColor( vyGraphBase.black ) END;
					INC( x, bw );  INC( y, bw );  DEC( w, 2 * bw );  DEC( h, 2 * bw );
					IF ~print THEN Display3.AdjustMask( Q, x, y, w, h );  END;
					vyGraphBase.SetPenSize( oldsize );
				END;
			END PictureDrawRect;

			PROCEDURE CheckDB( ): BOOLEAN;
			BEGIN
				layerRef := obj.vylinks;
				WHILE layerRef # NIL DO
					IF (layerRef.obj IS tLayer) & (layerRef.obj( tLayer ).prohibitDB) THEN RETURN FALSE END;
					layerRef := layerRef.link
				END;
				RETURN TRUE
			END CheckDB;

			PROCEDURE CheckTranslucent( ): BOOLEAN;
			BEGIN
				layerRef := obj.vylinks;
				WHILE layerRef # NIL DO
					IF (layerRef.obj IS tLayer) THEN
						IF layerRef.obj( tLayer ).forceImage THEN RETURN TRUE END;
						IF layerRef.obj( tLayer ).style.alpha # 255 THEN RETURN TRUE END;
					END;
					layerRef := layerRef.link
				END;
				RETURN FALSE

			END CheckTranslucent;

		BEGIN
			ASSERT ( w > 0, 100 );
			ASSERT ( h > 0, 101 );
			dmsg.device := Display.screen;  dmsg.id := Display.area;  dmsg.dlink := obj;  draw := TRUE;
			vyGraphBase.SetScreenCoordinate();  vyGraphBase.SetStyle( vyGraphBase.defaultStyle );  PictureDrawRect;
			IF (w <= 0) OR (h <= 0) THEN RETURN END;
			vyGraphBase.SetStyle( vyGraphBase.defaultStyle );

			IF (obj.gcontext # NIL ) & (obj.gcontext.handle # NIL ) THEN
				cMsg.X := x;  cMsg.Y := y;  cMsg.W := w;  cMsg.H := h;  obj.gcontext.handle( obj.gcontext, cSetMsg );
				obj.gcontext.handle( obj.gcontext, cMsg )
			END;

			db := CheckDB();  tl := CheckTranslucent();
			IF ~db THEN tl := FALSE END;
			IF ~print & vyGraphBase.UseDoubleBuffering & db THEN  (*! check translucent when printing .. *)
				draw := obj.needsRedraw;  vyGraphBase.openDB( obj.db, x, y, w, h, tl );
				IF obj.db = NIL THEN draw := FALSE
				ELSIF obj.db.new THEN draw := TRUE
				END;

				(*

		IF tl THEN
			draw := obj.needsRedraw;
			IF (obj.dbImage = NIL) THEN NEW(obj.dbImage);  draw := TRUE;  END;
			IF (obj.dbImage.width # w) OR (obj.dbImage.height # h) THEN
				Images.Create(obj.dbImage, w, h, Images.DisplayFormat);
				draw := TRUE;
			END;
			vyGraphBase.enableDB(NIL, obj.dbImage , x, y);
		ELSE
			IF (obj.dbBitmap = NIL) OR (obj.dbBitmap.width # w) OR (obj.dbBitmap.height # h ) THEN
				obj.dbBitmap := Bitmaps.New(w, h);
				(* NEW(obj.db); Pictures.Create(obj.dbPict, w, h, 8); (*! support variable depth from Display !!! *)
				FOR i := 0 TO 255 DO Display.GetColor(i, r, g, b); Pictures.SetColor(obj.dbPict, i, r, g, b) END
				*)
				vyGraphBase.enableDB(obj.dbBitmap, NIL, x, y);
			ELSIF ~obj.needsRedraw THEN draw := FALSE
			END;
			vyGraphBase.enableDB(obj.dbBitmap, NIL, x, y);
		END;

		*)

				(*			IF tl THEN
		IF (obj.orig = NIL) OR (obj.orig.width # obj.dbBitmap.width) OR (obj.orig.height # obj.dbBitmap.height) THEN
		NEW(obj.orig); NEW(obj.overlay);
		Images.Create(obj.orig,w,h,Images.DisplayFormat);
		Images.Create(obj.overlay,w,h,Images.DisplayFormat);
		END;
		END;
		*)

			END;
			IF draw THEN
				vyGraphBase.SetAlpha( 255 );  vyGraphBase.SetBackColor( obj.backGround );
				Display.GetColor( obj.backGround, bcr, bcg, bcb );  vyGraphBase.EraseRect( x, y, w, h );
				IF (obj.borderW = 0) & ((~vyGraphBase.UseDoubleBuffering) OR (~db)) THEN
					Display3.AdjustMask( Q, x, y + 1, w, h );   (* fof 001120 Shrink due to Display errors probably in Display3.Line *)
				END;
				layerRef := obj.vylinks;
				WHILE layerRef # NIL DO
					IF layerRef.obj = NIL THEN Out.String( "NIL Layer accounted, fatal" );  Out.Ln();  RETURN;  END;   (* fof 0103xx debug *)
					IF ~(layerRef.obj IS tLayer) THEN Out.String( "NON Layer accounted, fatal" );  Out.Ln();  RETURN;  END;
					IF layerRef.obj.handle # NIL THEN
						layerRef.obj( tLayer ).style.bcol := obj.backGround;  vyGraphBase.SetStyle( layerRef.obj( tLayer ).style );
						(*
				vyGraphBase.SetAlpha(255-layerRef.obj(tLayer).translucent);
				done by setstyle
				*)
						layerRef.obj.handle( layerRef.obj, dmsg );
					END;
					layerRef := layerRef.link
				END;
				vyGraphBase.SetAlpha( 255 );
				IF (obj.gcontext # NIL ) & (obj.gcontext.handle # NIL ) THEN obj.gcontext.handle( obj.gcontext, dmsg ) END;
				IF obj.header & ((~print & ~gif) OR PrintHeaders) THEN
					vyGraphBase.SetStyle( vyGraphBase.defaultStyle );
					vyGraphBase.SetStringJustification( vyGraphBase.left, vyGraphBase.top );  vyGraphBase.SetForeColor( 15 );
					vyGraphBase.SetBackColor( obj.backGround );  vyGraphBase.SetDisplayMode( Display.paint );
					GetHeader( obj, header );  vyGraphBase.String( x + obj.hx, y + h + obj.hy, "Syntax10.Scn.Fnt", header );
					vyGraphBase.String( x + obj.hx, y + h + obj.hy, "Syntax10.Scn.Fnt", header )
					(*! unclear, when only one Call is given, String does not work here, only in db mode *)
				END;
			END;
			IF print THEN  (* patch: Printer writes on Border, overwriting here *)
				x := msg.x + obj.X;  y := msg.y + obj.Y;  w := obj.W;  h := obj.H;  PictureDrawRect;
			END;
			IF ~print & vyGraphBase.UseDoubleBuffering & ~gif & db THEN vyGraphBase.writeDB();  END;
			vyGraphBase.closeDB;   (* just in case something went wrong, otherwise Display is missing *)
			IF gif THEN vyGraphBase.closeDB END;
			obj.needsRedraw := FALSE
		END PictureDraw;

	BEGIN
		x := msg.x + obj.X;  y := msg.y + obj.Y;  w := obj.W;  h := obj.H;
		IF msg.device = Display.screen THEN
			Gadgets.MakeMask( obj, x, y, msg.dlink, Q );
			IF (msg.id = Display.full) OR (msg.F = NIL ) THEN Display3.AdjustMask( Q, x, y - 1, w, h + 1 )
			ELSIF msg.id = Display.area THEN Display3.AdjustMask( Q, x + msg.u, y + h - 1 + msg.v, msg.w, msg.h )
			END;
			vyGraphBase.UseClipMask( Q );  Oberon.FadeCursor( Oberon.Mouse );  PictureDraw( FALSE , FALSE );
			IF Gadgets.selected IN obj.state THEN
				x := msg.x + obj.X;  y := msg.y + obj.Y;  w := obj.W;  h := obj.H;
				Display3.FillPattern( Q, Display3.white,
				Display3.selectpat, x, y, x, y, w, h, Display.paint ) (* adjusted, fof *)
			END
		ELSIF (msg.device = Display.printer) THEN
			Gadgets.MakePrinterMask( obj, msg.x, msg.y, msg.dlink, Q );  vyGraphBase.SetScreenCoordinate;
			vyGraphBase.OpenPrinter( msg.x, msg.y, x, y );  vyGraphBase.UseClipMask( Q );  PictureDraw( TRUE , FALSE );
			vyGraphBase.ClosePrinter
		END
	END PictureHandleDisplay;

	PROCEDURE PictureHandleAttributes( pict: Picture;  VAR M: Objects.AttrMsg );
	BEGIN
		(*Out.String('vyPort.HandlePictureAttributes'); Out.Ln; *)
		IF M.id = Objects.get THEN
			IF M.name = "Gen" THEN M.class := Objects.String;  COPY( "vyPort.NewPicture", M.s );  M.res := 0
			ELSIF M.name = "lockedsize" THEN M.class := Objects.Bool;  M.b := Gadgets.lockedsize IN pict.state;  M.res := 0
			ELSIF M.name = "lockedcontent" THEN M.class := Objects.Bool;  M.b := Gadgets.lockedcontents IN pict.state;  M.res := 0

			ELSIF M.name = "hx" THEN M.class := Objects.Int;  M.i := pict.hx;  M.res := 0
			ELSIF M.name = "hy" THEN M.class := Objects.Int;  M.i := pict.hy;  M.res := 0
			ELSIF M.name = "hdr" THEN M.class := Objects.Bool;  M.b := pict.header;  M.res := 0
			ELSIF (M.name = "bgCol") OR (M.name = "Color") THEN M.class := Objects.Int;  M.i := pict.backGround;  M.res := 0
			ELSIF M.name = "rx" THEN M.class := Objects.Real;  M.x := pict.Pictx;  M.res := 0
			ELSIF M.name = "ry" THEN M.class := Objects.Real;  M.x := pict.Picty;  M.res := 0
			ELSIF M.name = "rw" THEN M.class := Objects.Real;  M.x := pict.Pictw;  M.res := 0
			ELSIF M.name = "rh" THEN M.class := Objects.Real;  M.x := pict.Picth;  M.res := 0

			ELSIF M.name = "LineupHY" (* hidden attribute for vertical displacement *)
			THEN
				M.class := Objects.Int;  M.i := pict.H - Fonts.Default.height;  M.res := 0
			ELSE
				IF pict.gcontext # NIL THEN ToGContext( pict, M ) END;
				IF M.res < 0 THEN vyBase.framehandle( pict, M ) END
			END
		ELSIF M.id = Objects.set THEN
			pict.needsRedraw := TRUE;
			IF M.name = "lockedsize" THEN
				IF M.class = Objects.Bool THEN
					IF M.b THEN pict.state := pict.state + {Gadgets.lockedsize};  ELSE pict.state := pict.state - {Gadgets.lockedsize};  END;
					M.res := 0
				END
			ELSIF M.name = "lockedcontent" THEN
				IF M.class = Objects.Bool THEN
					IF M.b THEN pict.state := pict.state + {Gadgets.lockedcontents};
					ELSE pict.state := pict.state - {Gadgets.lockedcontents};
					END;
					M.res := 0
				END
			ELSIF M.name = "hx" THEN
				IF M.class = Objects.Int THEN pict.hx := SHORT( M.i );  M.res := 0 END
			ELSIF M.name = "hy" THEN
				IF M.class = Objects.Int THEN pict.hy := SHORT( M.i );  M.res := 0 END
			ELSIF M.name = "borderW" THEN
				IF M.class = Objects.Int THEN pict.borderW := SHORT( M.i );  Gadgets.Update( pict );  M.res := 0 END
			ELSIF M.name = "hdr" THEN
				IF M.class = Objects.Bool THEN pict.header := M.b;  M.res := 0 END
			ELSIF (M.name = "bgCol") OR (M.name = "Color") THEN
				IF M.class = Objects.Int THEN pict.backGround := SHORT( M.i );  Gadgets.Update( pict );  M.res := 0 END
			ELSIF M.name = "rx" THEN
				IF M.class = Objects.Real THEN pict.Pictx := M.x;  Gadgets.Update( pict );  M.res := 0 END
			ELSIF M.name = "ry" THEN
				IF M.class = Objects.Real THEN pict.Picty := M.x;  Gadgets.Update( pict );  M.res := 0 END

			ELSIF M.name = "rw" THEN
				IF M.class = Objects.Real THEN pict.Pictw := M.x;  Gadgets.Update( pict );  M.res := 0 END
			ELSIF M.name = "rh" THEN
				IF M.class = Objects.Real THEN pict.Picth := M.x;  Gadgets.Update( pict );  M.res := 0 END

			ELSE
				IF pict.gcontext # NIL THEN ToGContext( pict, M ) END;
				IF M.res < 0 THEN vyBase.framehandle( pict, M ) END
			END
		ELSIF M.id = Objects.enum THEN
			M.Enum( "hx" );  M.Enum( "hy" );  M.Enum( 'hdr' );  M.Enum( "bgCol" );  M.Enum( "rx" );  M.Enum( "rx" );  M.Enum( "ry" );  M.Enum( "rw" );  M.Enum( "rh" );
			M.Enum( "lockedsize" );  M.Enum( "lockedcontent" );

			IF pict.gcontext # NIL THEN ToGContext( pict, M )
			END;
			vyBase.framehandle( pict, M )
		END
	END PictureHandleAttributes;

	PROCEDURE PictureHandleLinks( pict: Picture;  VAR M: Objects.LinkMsg );
	VAR oldlink: Objects.Object;
	BEGIN
		oldlink := pict.dlink;
		IF M.id = Objects.enum THEN
			M.Enum( 'vyobj' );  M.Enum( 'coord' );  M.Enum( 'obj' );  vyLinks.DoHandleLinks( pict.vylinks, 'Layer', M );  vyBase.framehandle( pict, M )
		ELSIF M.id = Objects.get THEN
			IF M.name = 'coord' THEN M.obj := pict.gcontext;  M.res := 0
			ELSIF M.name = 'obj' THEN
				M.obj := pict.obj;  M.res := 0 (*! handle subscribe *)
			ELSE
				vyLinks.DoHandleLinks( pict.vylinks, 'Layer', M );
				IF M.res < 0 THEN vyBase.framehandle( pict, M ) END
			END
		ELSIF M.id = Objects.set THEN
			pict.dlink := M.dlink;  M.dlink := pict;
			IF M.name = 'Model' THEN vyLinks.ToLinks( pict.vylinks, M )
			ELSIF M.name = 'obj' THEN
				pict.obj := M.obj;  M.res := 0;  PictureHandleUpdate( pict );   (*! handle subscribe *)
			ELSE vyLinks.DoHandleLinks( pict.vylinks, 'Layer', M )
			END;
			IF M.res < 0 THEN vyBase.framehandle( pict, M ) END
		ELSE vyBase.framehandle( pict, M )
		END;
		pict.dlink := oldlink
	END PictureHandleLinks;

	PROCEDURE PictureHandleFileMsg( obj: Picture;  VAR msg: Objects.FileMsg );
	VAR l: vyLinks.Link;
	BEGIN
		IF msg.id = Objects.load THEN
			Files.ReadReal( msg.R, obj.Pictx );  Files.ReadReal( msg.R, obj.Picty );  Files.ReadReal( msg.R, obj.Pictw );
			Files.ReadReal( msg.R, obj.Picth );  Files.ReadBool( msg.R, obj.needsRedraw );  Files.ReadInt( msg.R, obj.hx );
			Files.ReadInt( msg.R, obj.hy );  Files.ReadBool( msg.R, obj.header );
			Gadgets.ReadRef( msg.R, obj.lib, obj.gcontext );
			vyBase.Subscribe( (*for messages from source*) obj.gcontext, obj );   (*? *)
			Files.ReadLInt( msg.R, obj.backGround );  vyBase.framehandle( obj, msg );  l := obj.vylinks;
			WHILE (l # NIL ) DO
				IF l.obj # NIL THEN l.obj.dlink := obj;  vyBase.Subscribe( (*for messages from source*) l.obj, obj ) END;
				l := l.link
			END

		ELSIF msg.id = Objects.store THEN
			Files.WriteReal( msg.R, obj.Pictx );  Files.WriteReal( msg.R, obj.Picty );  Files.WriteReal( msg.R, obj.Pictw );
			Files.WriteReal( msg.R, obj.Picth );

			Files.WriteBool( msg.R, obj.needsRedraw );  Files.WriteInt( msg.R, obj.hx );  Files.WriteInt( msg.R, obj.hy );
			Files.WriteBool( msg.R, obj.header );  Gadgets.WriteRef( msg.R, obj.lib, obj.gcontext );
			Files.WriteLInt( msg.R, obj.backGround );  vyBase.framehandle( obj, msg )
		ELSE vyBase.framehandle( obj, msg )
		END

	END PictureHandleFileMsg;

	PROCEDURE ViewCopyOfPict*( pict: Picture );
	VAR msg: Objects.CopyMsg;
	BEGIN
		IF pict = NIL THEN RETURN END;
		Objects.Stamp( msg );  pict.handle( pict, msg );
		IF msg.obj # NIL THEN vyHostTexts.InsertGadget( msg.obj );  END;
	END ViewCopyOfPict;

	PROCEDURE showcopy;
	BEGIN
		ViewCopyOfPict( focusPicture );
	END showcopy;

	PROCEDURE adjust;
	BEGIN
		AdjustPicture( focusPicture )
	END adjust;

	PROCEDURE unlock;
	BEGIN
		Attributes.SetBool( focusPicture, "lockedcontent", FALSE );
	END unlock;

	PROCEDURE lock;
	BEGIN
		Attributes.SetBool( focusPicture, "lockedcontent", TRUE );
	END lock;

	PROCEDURE PictureHandler*( obj: Objects.Object;  VAR msg: Objects.ObjMsg );
	(* proper support for double buffering is needed. Set o.needsRedraw if redraw is needed *)
	VAR copy: Picture;  x, y, w, h: INTEGER;  l: antsCommandList.List;
	BEGIN
		ASSERT ( (obj # NIL ) & (obj IS Picture), 100 );

		WITH obj: Picture DO
			IF (obj.vylinks # NIL ) & (obj.vylinks.obj # NIL ) & (obj.vylinks.obj.lib # obj.lib) THEN
			(*!F.handle:=NIL; ASSERT(F.vylinks.obj.lib=F.lib,100)*)
			(*! bad hack: fix problem at source!*)
				(* Gadgets.BindObj(obj.vylinks.obj, obj.lib) *) END;   (* this makes a lot of problems ! do NEVER bind an object before the store message, thisproblem transfers to all dependent objects !! *)

			IF msg IS Display.FrameMsg THEN
				IF (msg( Display.FrameMsg ).F = NIL ) OR (msg( Display.FrameMsg ).F = obj) THEN
					WITH msg: Display.FrameMsg DO
						x := msg.x + obj.X;  y := msg.y + obj.Y;  w := obj.W;  h := obj.H;
						IF (msg.F = NIL ) OR (msg.F = obj) THEN END;
						IF msg IS Oberon.InputMsg THEN
							WITH msg: Oberon.InputMsg DO PictureHandleInputMsg( obj, msg, x, y, w, h );
							END;
						ELSIF msg IS Display.DisplayMsg THEN
							WITH msg: Display.DisplayMsg DO PictureHandleDisplay( obj, msg );
							END;
						ELSIF msg IS Display.ConsumeMsg THEN
							WITH msg: Display.ConsumeMsg DO
								IF (msg.F = obj) THEN PictureHandleConsume( obj, msg );  END;
							END;
						ELSIF msg IS FindMsg THEN
							WITH msg: FindMsg DO
								IF msg.F = obj THEN msg.fx := x;  msg.fy := y END;
								(*? PrintPicMsg *)
							END;
						ELSIF msg IS Texts.UpdateMsg THEN
							WITH msg: Texts.UpdateMsg DO
								IF obj.obj = msg.text THEN PictureHandleUpdate( obj ) END;
							END;
						ELSIF msg IS Gadgets.UpdateMsg THEN
							WITH msg: Gadgets.UpdateMsg DO
								IF obj.obj = msg.obj THEN PictureHandleUpdate( obj ) END
							END;
						ELSE vyBase.framehandle( obj, msg )
						END  (* WITH msg : Oberon.InputMsg *)
						(*! improve. do early filtering. Can we skip all display messages? *)
						(*	obj.defunctx := x; obj.defuncty := y*)
					END  (* WITH msg: Display.FrameMsg *)
				ELSE
					vyBase.framehandle( obj, msg );   (* fof 0103xx *)

				END  (* (msg(Display.FrameMsg ).F = NIL) OR (msg(Display.FrameMsg).F = obj) *)
			ELSE  (* not Display.FrameMsg *)
				IF msg IS vyEvents.EventMsg THEN
					WITH msg: vyEvents.EventMsg DO
						IF (~(Gadgets.lockedcontents IN obj.state)) THEN
							IF msg.callForResponder THEN GetResponder( obj, msg ) END;
							PictureHandleEventMsg( obj, msg )
						ELSE
							IF msg.gesture = vyEvents.EvtSelect THEN
								SetFocusPicture( obj );  l := NIL;  antsCommandList.Add( l, unlock, "UnLock" );  antsCommandList.Wait();
								vyEvents.GetEvent( msg );  antsCommandList.ExecuteListedCommand( msg.x + 2, msg.y + 2, msg, l );
							END;
						END;
						(*		| msg: ResetMsg DO PictureReset(obj, msg);*)
					END;
				ELSIF msg IS Objects.CopyMsg THEN
					WITH msg: Objects.CopyMsg DO
						Out.Ln;  Out.String( "Picture: Copy called" );
						IF msg.stamp = obj.stamp THEN msg.obj := obj.dlink
						ELSE
							NEW( copy );  obj.stamp := msg.stamp;  obj.dlink := copy;  PictureCopy( msg, obj( Picture ), copy );
							msg.obj := copy
						END
					END;
				ELSIF msg IS Objects.FileMsg THEN
					WITH msg: Objects.FileMsg DO PictureHandleFileMsg( obj, msg )
					END;
				ELSIF msg IS vyBase.UpdateMessage THEN
					WITH msg: vyBase.UpdateMessage DO
					(*			Out.String("via Update Mesage (Picture)");*)
						PictureUpdate( obj )
					END;
				ELSIF msg IS SetPictureMsg THEN
					WITH msg: SetPictureMsg DO PictureHandleSetPicture( obj )
					END;
				ELSIF msg IS ExtractContentMsg THEN
					WITH msg: ExtractContentMsg DO PictureHandleExtract( obj, msg )
					END;
				ELSIF msg IS Objects.AttrMsg THEN
					WITH msg: Objects.AttrMsg DO PictureHandleAttributes( obj, msg )
					END;
				ELSIF msg IS Objects.LinkMsg THEN
					WITH msg: Objects.LinkMsg DO PictureHandleLinks( obj, msg )
					END;
				ELSIF msg IS Objects.BindMsg THEN
					WITH msg: Objects.BindMsg DO
						ASSERT ( obj.gcontext # NIL , 111 );
						Gadgets.BindObj( obj.gcontext, msg.lib );   (*! add other fields if necessary *)
						vyBase.framehandle( obj, msg )
					END;
				ELSE vyBase.framehandle( obj, msg )
				END
			END
		END
	END PictureHandler;

(*PROCEDURE LayerHandleAttributes (o: tLayer; VAR msg: Objects.AttrMsg);
BEGIN
IF msg.id = Objects.enum THEN

vyBase.objecthandle(o, msg);

vyGraphBase.HandleStyleAttributes(o.style, msg)
ELSE
vyGraphBase.HandleStyleAttributes(o.style, msg);
IF msg.res # 0 THEN vyBase.objecthandle(o, msg) END
END
END LayerHandleAttributes;*)

	PROCEDURE LayerHandleAttributes( o: tLayer;  VAR msg: Objects.AttrMsg );
	BEGIN
		IF msg.id = Objects.enum THEN
			msg.Enum( "prohibitDB" );  msg.Enum( "forceImage" );  vyGraphBase.HandleStyleAttributes( o.style, msg );  vyBase.objecthandle( o, msg )
		ELSIF msg.id = Objects.get THEN
			IF msg.name = "prohibitDB" THEN msg.b := o.prohibitDB;  msg.class := Objects.Bool;  msg.res := 0
			ELSIF msg.name = "forceImage" THEN msg.b := o.forceImage;  msg.class := Objects.Bool;  msg.res := 0;
			ELSE
				vyGraphBase.HandleStyleAttributes( o.style, msg );
				IF msg.res # 0 THEN vyBase.objecthandle( o, msg ) END
			END
		ELSIF msg.id = Objects.set THEN
			IF msg.name = "prohibitDB" THEN
				IF msg.class = Objects.Bool THEN o.prohibitDB := msg.b;  msg.res := 0;  vyBase.Update( o ) END
			ELSIF msg.name = "forceImage" THEN
				IF msg.class = Objects.Bool THEN
					o.forceImage := (msg.b);
					IF msg.b = TRUE THEN o.prohibitDB := FALSE END;
					msg.res := 0;  vyBase.Update( o )
				END;
			ELSE
				vyGraphBase.HandleStyleAttributes( o.style, msg );
				IF (msg.id = Objects.set) & (msg.res = 0) THEN vyBase.Update( o )
				ELSIF msg.res # 0 THEN vyBase.objecthandle( o, msg )
				END
			END
		END
	END LayerHandleAttributes;

	PROCEDURE LayerCopy*( VAR M: Objects.CopyMsg;  obj, obj0: tLayer );
	BEGIN
		obj0.style := obj.style;  obj0.x := obj.x;  obj0.y := obj.y;  obj0.z := obj.z;  obj0.highlight := obj.highlight;

		M.id := Objects.shallow;   (* Layers view data -> data itself may never be copied *)
		Gadgets.CopyObject( M, obj, obj0 );
		IF obj0.x # NIL THEN vyBase.Subscribe( obj0.x, obj0 );  END;
		IF obj0.y # NIL THEN vyBase.Subscribe( obj0.y, obj0 );  END;
		IF obj0.z # NIL THEN vyBase.Subscribe( obj0.z, obj0 );  END;

	END LayerCopy;

	PROCEDURE Bind( o: Objects.Object;  VAR msg: Objects.BindMsg );
	BEGIN
		IF (o # NIL ) & (msg.lib # o.lib) THEN
			Gadgets.BindObj( o, msg.lib );
			IF o.handle # NIL THEN o.handle( o, msg ) END
		END
	END Bind;

	PROCEDURE LayerHandler*( o: Objects.Object;  VAR M: Objects.ObjMsg );
	VAR obj0: tLayer;  obsub: Objects.Object;  minX, minY, maxX, maxY, dy: Real;  nansX, nansY: LONGINT;  vx, vy: vyBase.tVector;
		pmsg: Gadgets.PriorityMsg;  p: Picture;

	BEGIN  (*vyHostTexts.Msg(' Enter LayerHandler');*)
		WITH o: tLayer DO
			IF M IS Objects.AttrMsg THEN
				WITH M: Objects.AttrMsg DO LayerHandleAttributes( o, M )
				END;
			ELSIF M IS UpMsg THEN
				WITH M: UpMsg DO  (* gadget to front *)
					IF o.dlink # NIL THEN
						p := o.dlink( Picture );  pmsg.id := Gadgets.visible;  pmsg.passon := TRUE;  pmsg.F := p;  pmsg.res := -1;
						Display.Broadcast( pmsg );
					END;
				END;
			ELSIF M IS AdjustCoordMsg THEN
				WITH M: AdjustCoordMsg DO
					IF (o.x # NIL ) & (o.y # NIL ) & (o.z # NIL ) THEN
					ELSIF (o.x # NIL ) & (o.y # NIL ) THEN
						vx := o.x( vyBase.tVector );  vy := o.y( vyBase.tVector );  vyTypes.VGetMinMax( vx, minX, maxX, nansX );
						vyTypes.VGetMinMax( vy, minY, maxY, nansY );

						IF minX < -1.0E5 THEN RETURN
						END;
						IF minY < -1.0E5 THEN RETURN END;
						IF maxX > 1.0E5 THEN RETURN END;
						IF maxY > 1.0E5 THEN RETURN END;

						IF minX = maxX THEN maxX := minX + 1
						ELSE minX := minX - 0.1 * (maxX - minX);  maxX := maxX + 0.1 * (maxX - minX)
						END;
						IF minY = maxY THEN maxY := minY + 1
						ELSE minY := minY - 0.1 * (maxY - minY);  maxY := maxY + 0.1 * (maxY - minY)
						END;

						SetC2d( o.dlink( Picture ), minX, minY, maxX - minX, maxY - minY );
					ELSIF (o.x # NIL ) THEN
						vx := o.x( vyBase.tVector );  vyTypes.VGetMinMax( vx, minY, maxY, nansY );
						IF minY = maxY THEN maxY := minY + 1
						ELSE minY := minY - 0.1 * (maxY - minY);  maxY := maxY + 0.1 * (maxY - minY)
						END;
						Attributes.GetLongReal( o.dlink, "x2d", minX );  Attributes.GetLongReal( o.dlink, "w2d", maxX );
						SetC2d( o.dlink( Picture ), minX, minY, maxX, maxY - minY );  dy := (maxY - minY) * 0.05;
						vyGraphBase.SetRealWorldRgn( minX, minY - dy, maxX, maxY - minY + 2 * dy, 0 )
					END;
				END;
			ELSIF M IS Objects.FileMsg THEN
				WITH M: Objects.FileMsg DO  (* vyHostTexts.Msg(' Enter FileMsg');*)
					IF M.id = Objects.load THEN vyGraphBase.ReadStyle( M.R, o.style );  Files.ReadBool( M.R, o.prohibitDB );

						Gadgets.ReadRef( M.R, o.lib, obsub );
						IF (obsub # NIL ) & (obsub IS vyBase.Object) THEN
							o.highlight := obsub( vyBase.Object );  vyBase.Subscribe( (*for messages from source*) o.highlight, o )
						ELSE o.highlight := NIL
						END;

						Gadgets.ReadRef( M.R, o.lib, obsub );
						IF (obsub # NIL ) & (obsub IS vyBase.tVector) THEN
							o.x := obsub( vyBase.tVector );  vyBase.Subscribe( (*for messages from source*) o.x, o )
						ELSE o.x := NIL
						END;

						Gadgets.ReadRef( M.R, o.lib, obsub );
						IF (obsub # NIL ) & (obsub IS vyBase.tVector) THEN
							o.y := obsub( vyBase.tVector );  vyBase.Subscribe( (*for messages from source*) o.y, o )
						ELSE o.y := NIL
						END;

						Gadgets.ReadRef( M.R, o.lib, obsub );
						IF (obsub # NIL ) & (obsub IS vyBase.tVector) THEN
							o.z := obsub( vyBase.tVector );  vyBase.Subscribe( (*for messages from source*) o.z, o )
						ELSE o.z := NIL
						END;

						(* ASSERT(newpicture # NIL); *)  (* fof 010410 it may happen that layers get stored without their container, which might be not too bad 2*)

						IF newpicture # NIL THEN vyBase.Subscribe( (*for messages from source*) newpicture, o ) END;   (* subscribe to host picture *)
						o.forceImage := FALSE;
					ELSIF M.id = Objects.store THEN
						vyGraphBase.WriteStyle( M.R, o.style );  Files.WriteBool( M.R, o.prohibitDB );
						Gadgets.WriteRef( M.R, o.lib, o.highlight );  Gadgets.WriteRef( M.R, o.lib, o.x );
						Gadgets.WriteRef( M.R, o.lib, o.y );  Gadgets.WriteRef( M.R, o.lib, o.z )
					END;
					vyBase.objecthandle( o, M );
				END;
			ELSIF M IS Objects.CopyMsg THEN
				WITH M: Objects.CopyMsg DO
					IF M.stamp = o.stamp THEN
						IF M.obj = NIL THEN M.obj := o.dlink END
					ELSE  (* Layer copy is a deep copy, always ! *)
						(*NEW(obj0); o.stamp := M.stamp; o.dlink := obj0;
				LayerCopy(M, o, obj0); M.obj := obj0 *)
						obj0 := M.obj( tLayer );  LayerCopy( M, o, M.obj( tLayer ) );  M.obj := obj0
					END
				END;
			ELSIF M IS vyBase.UpdateMessage THEN
				WITH M: vyBase.UpdateMessage DO  (*PictureUpdate (HostPicture(o))*)
				(*Out.String('vyPort.LayerHandler UpdateMessage'); Out.Ln;*)
					UpdateHostPicture( o, M ) (*! avoid recycling *)
				END;
			ELSIF M IS Objects.BindMsg THEN
				WITH M: Objects.BindMsg DO
					vyBase.objecthandle( o, M );  Bind( o.x, M );  Bind( o.y, M );  Bind( o.z, M );  Bind( o.highlight, M )

				END;
			ELSE  (* vyHostTexts.Msg(' Enter Else'); *) vyBase.objecthandle( o, M )
			END
		END;
		(*vyHostTexts.Msg(' Exit LayerHandler');*)
	END LayerHandler;

	PROCEDURE PictureInit( picture: Picture );
	BEGIN
		picture.handle := PictureHandler;

		(*picture.W := 100; picture.H := 100;*)
		picture.W := SHORT( ENTIER( vyHostTexts.GetCurWidth() / DfltFramesPLine ) );
		picture.H := SHORT( ENTIER( picture.W * defFramehwRelation + 0.5 ) );  picture.X := 0;  picture.Y := -picture.H;
		picture.needsRedraw := TRUE;

		picture.gcontext := NIL;  picture.backGround := backGround;  picture.borderW := 1;

		picture.hx := 2;  picture.hy := -1;  picture.header := TRUE;  picture.vylinks := NIL
	END PictureInit;

	PROCEDURE NewPicture*;   (* System.Free vyPort* *)
	(*	Gadgets.Insert vyPort.NewPicture *)  (* SpotRef.Insert vyPort.NewPicture *)
	BEGIN
		NEW( newpicture );  PictureInit( newpicture );  Objects.NewObj := newpicture
	END NewPicture;

	PROCEDURE PictureSetgcontext( picture: Picture;  gc: vyBase.Object );
	BEGIN
		IF picture.gcontext # NIL THEN vyBase.UnSubscribe( gc, picture ) END;
		picture.gcontext := gc;
		IF gc # NIL THEN vyBase.Subscribe( (*for messages from source*) gc, picture ) END
	END PictureSetgcontext;

	PROCEDURE InsertNewCPicture*( x, y, w, h: REAL;  gc: vyBase.Object ): Picture;
	BEGIN
		NewPicture;  PictureSetgcontext( newpicture, gc );  AddPicture( InsertNewFrame( 0, 0 ), newpicture, x, y, w, h );
		RETURN newpicture
	END InsertNewCPicture;

	PROCEDURE XNewCPicture*( x, y, w, h: REAL;  gc: vyBase.Object ): Picture;
	BEGIN
		NewPicture;  PictureSetgcontext( newpicture, gc );  AddPicture( XNewFrame( 0, 0 ), newpicture, x, y, w, h );
		RETURN newpicture
	END XNewCPicture;

	PROCEDURE NewP*( gc: vyBase.Object ): Picture;
	BEGIN
		NewPicture;  PictureSetgcontext( newpicture, gc );  RETURN newpicture
	END NewP;

	PROCEDURE InsertNewVecPicture*( vx, vy: vyBase.tVector ): Picture;
	VAR minX, minY, maxX, maxY: Real;  nansX, nansY: LONGINT;
	BEGIN
		IF vx = NIL THEN minX := 0;  maxX := 1;  nansX := 0 ELSE vyTypes.VGetMinMax( vx, minX, maxX, nansX ) END;
		IF vy = NIL THEN minY := 0;  maxY := 1;  nansY := 0 ELSE vyTypes.VGetMinMax( vy, minY, maxY, nansY ) END;
		IF minX = maxX THEN maxX := minX + 1 END;
		IF minY = maxY THEN maxY := minY + 1 END;
		RETURN InsertNewCPicture( 0, 0, 1, 1, vyDisplay2d.NewC2d( minX, minY, maxX - minX, maxY - minY ) )
	END InsertNewVecPicture;

	PROCEDURE Write*( picture: Picture );
	VAR frame: Frame;
	BEGIN
		frame := InsertNewFrame( 0, 0 );  AddPicture( frame, picture, 0, 0, 1, 1 )
	END Write;

	PROCEDURE OpenLayer*( layer: tLayer;  id: ARRAY OF CHAR );
	BEGIN
		(*Out.String('vyPort.OpenLayer'); Out.Ln;*)
		layer.style := vyGraphBase.defaultStyle;  layer.prohibitDB := FALSE;  layer.forceImage := FALSE;
		(* layer.sources := NIL; layer.users := NIL; *)  (* no ! while loading a file OpenLayer may be called too late *)
		vyName.RegisterNamed( layer, id )
	END OpenLayer;

	PROCEDURE StorePictAsGIF*( pict: Picture;  R: Files.Rider );
	BEGIN
		(*! PictConverters.Pict2GIF(PictToPicture(pict), R) *) HALT( 100 )
	END StorePictAsGIF;

	PROCEDURE Undo*;
	BEGIN
		IF undoAction # 0 THEN
			IF undoAction = ActionLayerRemove THEN AddLayer( undoPict, undoLayer )
			ELSIF undoAction = ActionLayerCopy THEN RemoveLayer( undoPict, undoLayer )
			ELSE vyHostTexts.Note( vyHostTexts.cWarning, "can`t undo last action, unknown action " )
			END;
			undoAction := 0
		ELSE vyHostTexts.Note( vyHostTexts.cWarning, "can`t undo last action " )
		END
	END Undo;

	PROCEDURE ZoomIn*;
	VAR x, y, w, h: INTEGER;  pict: Picture;  event: vyEvents.EventMsg;  zoomMsg: vyDisplay2d.CoordZoomMessage;
	BEGIN  (* vyGraphBase.SetClipRect (0, 0, vyGraphBase.DisplayWidth, vyGraphBase.DisplayHeight);*)
		vyEvents.GetEvent( event );  vyGraphBase.SetStringJustification( vyGraphBase.center, vyGraphBase.bottom );
		vyTracking.FramedString( event.x, event.y, "", "Select ZoomRegion", w, h );  vyEvents.GetEvent( event );
		pict := GetPictureXY( NIL , event.x, event.y );
		IF pict = NIL THEN RETURN END;
		IF event.gesture # vyEvents.EvtSelect THEN RETURN END;
		x := event.x;  y := event.y;  vyTracking.GrowRectangleRL( x, y, 0, 0, w, h );
		WHILE event.gesture # vyEvents.EvtEmpty DO vyEvents.GetEvent( event ) END;

		IF w < 0 THEN x := x + w;  w := -w
		END;
		IF h < 0 THEN y := y + h;  h := -h END;

		IF (w # 0) & (h # 0) THEN
			zoomMsg.in := TRUE;  zoomMsg.x := x;  zoomMsg.y := y;  zoomMsg.w := w;  zoomMsg.h := h;
			pict.gcontext.handle( pict.gcontext, zoomMsg );  PictureUpdate( pict )
		END
	END ZoomIn;

	PROCEDURE ZoomOut*;
	VAR zoomMsg: vyDisplay2d.CoordZoomMessage;  pict: Picture;
	BEGIN
		pict := GetFocusPicture();
		IF pict = NIL THEN vyHostTexts.Note( vyHostTexts.cAlert, "no picture focused" );  RETURN END;
		IF (pict.gcontext # NIL ) & (pict.gcontext.handle # NIL ) THEN
			zoomMsg.in := FALSE;  pict.gcontext.handle( pict.gcontext, zoomMsg );  PictureUpdate( pict )
		END
	END ZoomOut;

	PROCEDURE AdjustPicture( pict: Picture );
	VAR msg: AdjustCoordMsg;  layerRef: vyLinks.Link;
	BEGIN
		IF pict # NIL THEN
			IF pict.vylinks # NIL THEN
				layerRef := pict.vylinks;
				WHILE layerRef # NIL DO
					IF layerRef.obj # NIL THEN layerRef.obj.handle( layerRef.obj, msg );  END;
					layerRef := layerRef.link
				END
			END
		END;
	END AdjustPicture;

	PROCEDURE TogglePrintHeaders*;
	BEGIN
		PrintHeaders := ~PrintHeaders;
		IF PrintHeaders THEN vyHostTexts.Note( 0, "Header printing enabled" ) ELSE vyHostTexts.Note( 0, "Header printing disabled" ) END
	END TogglePrintHeaders;

	PROCEDURE Init;
	VAR temp: BOOLEAN;  res: INTEGER;
	BEGIN
		NEW( BGPicture );  screenRatio := vyGraphBase.DisplayWidth / vyGraphBase.DisplayHeight;  DfltFramesPLine := framesize;
		defFramehwRelation := gold;  updatesuspend := FALSE;  Pictures.Open( BGPicture, BGPictureName, temp );
		vyHost.CallWString( "antsObjects.Launch", "", FALSE , res );   (* to exchange some routines, especially in vyGraphBase0 *)
	END Init;

BEGIN
	(** Port **)
	Init();
	(** Picture **)
	backGround := 14;  foreColor := 15;  PrintHeaders := FALSE;  onTheFly := FALSE;  DefaultWidth := Display.Width DIV 8;

END vyPort.
(* vy/tools/vyPort.Panel
LayLa.OpenAsDoc
(TABLE Panel (border=2 sameWidth=TRUE orientation=HOR cols=4 rows=4) (ATTR Color=5)
(NEW Caption ( w=80 h=16) (ATTR Value='vyPort'))
(NEW Button (w=80 h=16) (ATTR Caption='Zoom In' Cmd='vyPort.ZoomIn' ))
(NEW Button (w=80 h=16) (ATTR Caption='Zoom out' Cmd='vyPort.ZoomOut'))
VIRTUAL
)) ~
*)

Port ~ Gadgets.Insert vyPort.New ~ Gadgets.Insert vyPort.NewPicture ~
System.Free vyPort ~
Voyager.Random 20 ~
Generator: U
Gadgets.Insert vyScatter1.NewPict dbgTestVec.RRndmVec128~
System.Free vyScatter1 dbgTestVec vyPort ~
vy / src / vyScatter1.Mod
Generator: U
New random numbers generated as
Voyager.Random 2000 ~
Generator: U
New random numbers generated as
Voyager.Show UPM08FA024F as Histogram~
Voyager.Random
vyScale.Insert

Gadgets