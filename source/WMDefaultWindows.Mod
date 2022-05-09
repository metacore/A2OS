MODULE WMDefaultWindows;	(** AUTHOR "TF"; PURPOSE "Decoration windows, background window for WM"; *)

IMPORT
	Strings, WM := WMWindowManager, WMRectangles, Raster, Graphics := WMGraphics,
	Messages := WMMessages, Inputs, WMGraphicUtilities;

CONST
	DraggingSnapRangeBase = 40;

	(* Dragging: Window corners *)
	NoCorner = 0;
	UpperLeft = 1;
	UpperRight = 2;
	BottomLeft = 3;
	BottomRight = 4;

TYPE
	WindowState = WM.WindowState;
	Window = WM.Window;
	Message = Messages.Message;
	String = Strings.String;
	DecorWindow* = OBJECT(Window);
	VAR
		lastX, lastY : SIZE;
		useBitmaps*, dragging : BOOLEAN;
		resized : BOOLEAN;
		mode* : SIGNED32;
		corner : SIGNED32;
		mode0Move : BOOLEAN; (* Move window in mode 0 or resize it? *)
		hasFocus : BOOLEAN;
		picAa*, picBa*, picCa*,
		picAb*, picBb*, picCb* : Graphics.Image;
		distXY* : SIGNED32;
		vertical* : BOOLEAN;
		focusthreshold*, threshold* : SIGNED32;
		draggingWidth, draggingHeight : SIZE;
		draggingSnapRange : SIGNED32;
		sac, sic, basw, bisw : SIGNED32;
		modKeys : SET;

		PROCEDURE SetMasterFocus*(hasFocus : BOOLEAN);
		BEGIN
			SELF.hasFocus := hasFocus; Invalidate(WMRectangles.MakeRect(0, 0, GetWidth(), GetHeight()))
		END SetMasterFocus;

		PROCEDURE GetActivePics*(VAR a, b, c : Graphics.Image);
		BEGIN
			IF hasFocus THEN a := picAa; b := picBa; c := picCa
			ELSE
				IF picAb # NIL THEN a := picAb ELSE a := picAa END;
				IF picBb # NIL THEN b := picBb ELSE b := picBa END;
				IF picCb # NIL THEN c := picCb ELSE c := picCa END;
			END
		END GetActivePics;

		PROCEDURE CheckHorizontal*(x, y : SIZE) : BOOLEAN;
		VAR t : SIZE; th : SIGNED32; a, b, c: Graphics.Image;
		BEGIN
			GetActivePics(a, b, c);
			IF hasFocus THEN th := focusthreshold ELSE th := threshold END;
			IF (c # NIL) & (x >= GetWidth() - c.width) THEN
				RETURN Graphics.IsBitmapHit(x - (GetWidth() - c.width), y, th, c)
			ELSIF (a # NIL) & (x < a.width) THEN
				RETURN Graphics.IsBitmapHit(x, y, th, a)
			ELSIF (b # NIL) THEN
				IF a # NIL THEN t := a.width ELSE t := 0 END;
				RETURN Graphics.IsBitmapHit((x - t) MOD b.width, y, th, b)
			ELSE RETURN FALSE
			END
		END CheckHorizontal;

		PROCEDURE CheckVertical*(x, y : SIZE) : BOOLEAN;
		VAR t : SIZE; th : SIGNED32; a, b, c: Graphics.Image;
		BEGIN
			GetActivePics(a, b, c);
			IF hasFocus THEN th := focusthreshold ELSE th := threshold END;
			IF (c # NIL) & (y >= GetHeight() - c.height) THEN
				RETURN Graphics.IsBitmapHit(x, y - (GetHeight() - c.height), th, c)
			ELSIF (a # NIL) & (y < a.height) THEN
				RETURN Graphics.IsBitmapHit(x, y, th, a)
			ELSIF (b # NIL) THEN
				IF a # NIL THEN t := a.height ELSE t := 0 END;
				RETURN Graphics.IsBitmapHit(x, (y - t) MOD b.height, th, b)
			ELSE RETURN FALSE
			END
		END CheckVertical;

		PROCEDURE IsHit*(x, y : SIZE) : BOOLEAN;
		BEGIN
			IF ~useBitmaps THEN RETURN TRUE
			ELSE
				IF vertical THEN RETURN CheckVertical(x, y)
				ELSE RETURN CheckHorizontal(x, y)
				END
			END
		END IsHit;

		PROCEDURE PointerDown*(x, y : SIZE; keys : SET);
		BEGIN
			IF ~hasFocus OR (ABS(lastX - (bounds.l + x)) < 10) & (ABS(lastY - (bounds.t + y)) < 10) THEN manager.ToFront(master) END;
			lastX := bounds.l + x; lastY := bounds.t + y;
			IF ((mode = 0) & (x < distXY)) OR ((mode = 3) & (y < distXY)) THEN
				corner := UpperLeft;
			ELSIF ((mode = 0) & (x > GetWidth() - distXY)) OR ((mode = 1) & (y < distXY)) THEN
				corner := UpperRight;
			ELSIF ((mode = 3) & (y > GetHeight() - distXY)) OR ((mode = 2) & (x < distXY)) THEN
				corner := BottomLeft;
			ELSIF ((mode = 2) & (x > GetWidth() - distXY)) OR ((mode = 1) & (y  > GetHeight() - distXY)) THEN
				corner := BottomRight;
			ELSE
				corner := NoCorner;
			END;
			mode0Move := (y >= 3) & (3 <= x ) & (x <= GetWidth() - 3);
			draggingWidth := master.GetWidth();
			draggingHeight := master.GetHeight();
			draggingSnapRange := DraggingSnapRangeBase;
			IF ~(WM.FlagNoResizing IN flags) OR (mode # 0) OR mode0Move THEN
				dragging := TRUE;
			ELSE
				dragging := FALSE;
			END;
			IF master # NIL THEN master.HintReduceQuality(TRUE) END
		END PointerDown;

		PROCEDURE PointerMove*(x, y : SIZE; keys : SET);
		VAR curX, curY, dx, dy, moveX, moveY, newWidth, newHeight, snapWidth, snapHeight: SIZE;
		tx, ty : SIZE;
		BEGIN
			IF dragging THEN
				curX := bounds.l + x; curY := bounds.t + y; dx := curX - lastX; dy := curY - lastY;
				lastX := lastX + dx; lastY := lastY + dy;
				IF (dx # 0) OR (dy # 0) THEN

					IF (master # NIL) & (master.windowState = WindowState.Maximized) THEN
						master.SetWindowState(WindowState.Normal);
					END;
					moveX := 0; moveY := 0;
					IF (mode = 0) & mode0Move THEN (* move the window *)
						moveX := dx; moveY := dy;
					ELSE (* resize the window *)
						IF (corner = NoCorner) THEN
							IF (mode = 0) THEN (* Top *)
								draggingHeight := draggingHeight - dy; moveY := dy;
							ELSIF (mode = 1) THEN (* Right *)
								draggingWidth := draggingWidth + dx;
							ELSIF (mode = 2) THEN (* Bottom *)
								draggingHeight := draggingHeight + dy;
							ELSIF (mode = 3) THEN (* Left *)
								draggingWidth := draggingWidth - dx; moveX := dx;
							END;
						ELSIF (corner = UpperLeft) THEN
							draggingWidth := draggingWidth - dx; moveX := dx;
							draggingHeight := draggingHeight - dy; moveY := dy;
						ELSIF (corner = UpperRight) THEN
							draggingWidth := draggingWidth + dx;
							draggingHeight := draggingHeight - dy; moveY := dy;
						ELSIF (corner = BottomLeft) THEN
							draggingHeight := draggingHeight + dy;
							draggingWidth := draggingWidth - dx; moveX := dx;
						ELSIF (corner = BottomRight) THEN
							draggingHeight := draggingHeight + dy;
							draggingWidth := draggingWidth + dx;
						END;

						newWidth := MAX(1, draggingWidth);
						newHeight := MAX(1, draggingHeight);

						IF modKeys * Inputs.Alt # {} THEN
							snapWidth := newWidth; snapHeight := newHeight;
							SnapDraggingSize(snapWidth, snapHeight);
							newWidth := snapWidth;
							newHeight := snapHeight;
							IF (newWidth # draggingWidth) THEN
								IF (moveX # 0) THEN
									moveX := moveX - (newWidth - draggingWidth);
									draggingWidth := newWidth;
								END;
							END;
							IF (newHeight # draggingHeight) THEN
								IF (moveY # 0) THEN
									moveY := moveY - (newHeight - draggingHeight);
									draggingHeight := newHeight;
								END;
							END;
						END;

						tx := newWidth; ty := newHeight;
						manager.SetWindowSize(master, newWidth, newHeight);
						(* If the window has not accepted the new size, we have to potentially correct its movement *)
						IF (tx # newWidth) THEN
							IF (moveX # 0) THEN moveX := moveX - (newWidth - draggingWidth); END;
							draggingWidth := newWidth;
						END;
						IF  (ty # newHeight) THEN
							IF (moveY # 0) THEN moveY := moveY - (newHeight - draggingHeight); END;
							draggingHeight := newHeight;
						END;
						resized := TRUE;
						master.normalBounds.r := master.bounds.r;
						master.normalBounds.b := master.bounds.b;
					END;

					IF (moveX # 0) OR (moveY # 0) THEN
						manager.SetWindowPos(SELF, bounds.l + moveX, bounds.t + moveY);
						master.normalBounds.l := master.bounds.l;
						master.normalBounds.t := master.bounds.t;
					END;
				END;
			END;
		END PointerMove;

		PROCEDURE SnapDraggingSize(VAR width, height : SIZE);
		VAR
			ow, oh, snapWidth, snapHeight : SIZE;

			PROCEDURE Pow2(x : SIGNED16) : SIGNED32;
			VAR
				r : SIGNED32;
				i : SIGNED16;
			BEGIN
				r := 1;
				FOR i := 1 TO x DO
					r := r * 2
				END;
				RETURN r;
			END Pow2;

			PROCEDURE FindNearestPow2 (value: FLOAT32): SIGNED32;
			VAR result: SIGNED32;
			BEGIN
				result := 1;
				WHILE result < value DO INC (result, result) END;
				IF value - result DIV 2 < result - value THEN result := result DIV 2 END;
				RETURN result;
			END FindNearestPow2;

		BEGIN
			ow := master.initialBounds.r - master.initialBounds.l;
			oh := master.initialBounds.b - master.initialBounds.t;
			(* find multiple nearest to current size *)
			IF width > ow THEN
				snapWidth := ENTIER(width / ow + 0.5) * ow
			ELSE
				snapWidth := ENTIER ((1 / FindNearestPow2 (ow / width)) * ow);
(*
				snapWidth := ENTIER((1 / Pow2(SHORT(ENTIER((Math.ln(ow / width) / Math.ln(2)) + 0.5)))) * ow)
*)
			END;
			IF height > oh THEN
				snapHeight := ENTIER(height / oh + 0.5) * oh
			ELSE
				snapHeight := ENTIER ((1 / FindNearestPow2 (oh / height)) * oh);
(*
				snapHeight := ENTIER((1 / Pow2(SHORT(ENTIER((Math.ln(oh / height) / Math.ln(2)) + 0.5)))) * oh)
*)
			END;
			IF (height > snapHeight - draggingSnapRange) & (height < snapHeight + draggingSnapRange) THEN height := snapHeight END;
			IF (width > snapWidth - draggingSnapRange) & (width < snapWidth + draggingSnapRange) THEN width := snapWidth END;
		END SnapDraggingSize;

		PROCEDURE PointerUp*(x, y : SIZE; keys:SET);
		VAR m : Messages.Message;
		BEGIN
			IF master # NIL THEN master.HintReduceQuality(FALSE) END;
			IF resized & (master # NIL)  THEN
				m.msgType := Messages.MsgResized;
				m.x := master.bounds.r - master.bounds.l;
				m.y := master.bounds.b - master.bounds.t;
				IF ~master.sequencer.Add(m) THEN TRACE(" resized message was not queued") END;
				resized := FALSE;
			END;
			dragging := FALSE;
			corner := NoCorner;
		END PointerUp;

		PROCEDURE Handle*(VAR m : Messages.Message);
		BEGIN
			IF m.msgType = Messages.MsgFocus THEN
				IF m.msgSubType = Messages.MsgSubMasterFocusGot THEN hasFocus := TRUE
				ELSIF m.msgSubType = Messages.MsgSubMasterFocusLost THEN hasFocus := FALSE
				END;
				Invalidate(WMRectangles.MakeRect(0, 0, GetWidth(), GetHeight()))
			ELSE
				(* read the modifier keys from the view where the message originates *)
				IF (m.originator # NIL) & (m.originator IS WM.ViewPort) THEN
					m.originator(WM.ViewPort).GetKeyState(modKeys);
				END;
				Handle^(m)
			END
		END Handle;

	END DecorWindow;

CONST
	NoButton = 0;
	CloseButton = 1;
	MinimizeButton = 2;
	MaximizeButton = 3;
	RestoreButton = 4;
	HelpButton = 5;
	MenuButton = 6;
	UserButton = 7;
	Spacer = 8;

TYPE

	TopWindow* = OBJECT(DecorWindow)
	VAR
		closeInactive*, closeActive*, closeSelected*, closeHover*, closeHoverInactive*,
		minimizeInactive*, minimizeActive*, minimizeHover*, minimizeHoverInactive*,
		maximizeInactive*, maximizeActive*, maximizeHover*, maximizeHoverInactive*,
		restoreInactive*, restoreActive*, restoreHover*, restoreHoverInactive*,
		titleImg : Graphics.Image;
		minimizeOffset, spaceBetweenButtons : SIGNED32;
		titleCanvas : Graphics.BufferCanvas;
		down, hover : SIGNED32;
		tac, tic, tax, tix, tay, tiy : SIGNED32;

		PROCEDURE CheckButtons(x, y : SIZE; VAR button : SIGNED32);
		VAR img : Graphics.Image;
		VAR style := manager.GetStyle();
		VAR offsetX := GetWidth() IF style.version = 1 ELSE GetWidth() - style.rw - style.buttonRightMargin;
		VAR offsetY := 0, th := style.th, bm := style.buttonTopMargin : SIZE;
		BEGIN
			button := NoButton;
			(* check close button *)
			IF (master # NIL) & (WM.FlagClose IN master.flags) THEN
				IF hasFocus THEN img := closeActive ELSE img := closeInactive END;
				IF (img # NIL) THEN
					offsetX := offsetX - img.width;
					offsetY := 0 IF style.version = 1 ELSE (th - img.height) DIV 2 + bm;
					IF Graphics.IsBitmapHit(x - offsetX, y - offsetY, 64, img) THEN button := CloseButton; END;
				ELSE
					DEC(offsetX, 20);
					IF (x > offsetX) & (y > 2) THEN button := CloseButton; END;
				END;
			END;

			(* check maximize button *)
			IF (master # NIL) & (WM.FlagMaximize IN master.flags) & (button = NoButton) THEN
				IF master.windowState = WindowState.Maximized THEN
					IF hasFocus THEN img := restoreActive ELSE img := restoreInactive END;
				ELSE
					IF hasFocus THEN img := maximizeActive ELSE img := maximizeInactive END;
				END;
				IF (img # NIL) THEN
					offsetX := offsetX - (img.width + spaceBetweenButtons);
					offsetY := 0 IF style.version = 1 ELSE (th - img.height) DIV 2 + bm;
					IF Graphics.IsBitmapHit(x - offsetX, y - offsetY, 64, img) THEN button := RestoreButton IF master.windowState = WindowState.Maximized ELSE MaximizeButton END;
				END;
			END;

			(* check minimize button *)
			IF (master # NIL) & (WM.FlagMinimize IN master.flags) & (button = NoButton) THEN
				IF hasFocus THEN img := minimizeActive ELSE img := minimizeInactive END;
				IF (img # NIL) THEN
					offsetX := offsetX + minimizeOffset - (img.width + spaceBetweenButtons);
					offsetY := 0 IF style.version = 1 ELSE (th - img.height) DIV 2 + bm;
					IF Graphics.IsBitmapHit(x - offsetX, y - offsetY, 64, img) THEN button := MinimizeButton; END;
				END;
			END;
		END CheckButtons;

		PROCEDURE PointerMove*(x, y : SIZE; keys : SET);
		VAR oldHover : SIGNED32;
		BEGIN
			IF ~dragging THEN
				oldHover := hover;
				CheckButtons(x, y, hover);
				IF (hover # oldHover) THEN Invalidate(WMRectangles.MakeRect(0, 0, GetWidth(), GetHeight())); END;
				IF (hover # NoButton) THEN
					SetPointerInfo(manager.pointerStandard);
				ELSIF (y < 3) OR (x < 3) OR (x > GetWidth() - 3) THEN
					IF  ~(WM.FlagNoResizing IN flags) THEN
						IF (x < distXY) THEN SetPointerInfo(manager.pointerULDR);
						ELSIF (x > GetWidth() - distXY) THEN SetPointerInfo(manager.pointerURDL);
						ELSE SetPointerInfo(manager.pointerUpDown);
						END;
					END;
				ELSE
					SetPointerInfo(manager.pointerMove);
				END;
			END;
			PointerMove^(x, y, keys);
		END PointerMove;

		PROCEDURE PointerDown*(x, y : SIZE; keys : SET);
		BEGIN
			CheckButtons(x, y, down);
			PointerDown^(x, y, keys);
			IF (down # NoButton) THEN dragging := FALSE; END;
		END PointerDown;

		PROCEDURE PointerUp*(x, y:SIZE; keys:SET);
		VAR temp : SIGNED32; l, t, w, h: SIZE;
		BEGIN
			IF (down # NoButton) THEN
				CheckButtons(x, y, temp);
				IF (temp = CloseButton) THEN
					CloseDispatch(SELF, NIL);
					(*IF master # NIL THEN master.Close; END;*)
				ELSIF (temp = MinimizeButton) THEN
					MinimizeDispatch(SELF, NIL);
					(*IF master # NIL THEN master.Minimize; END;*)
				ELSIF (temp = MaximizeButton) THEN
					MaximizeDispatch(SELF, NIL);
					(*IF master # NIL THEN master.Maximize; END;*)
				ELSIF (temp = RestoreButton) THEN
					RestoreDispatch(SELF, NIL);
					(*IF master # NIL THEN master.Restore; END;*)
				ELSE
					PointerUp^(x, y, keys);
				END;
			ELSE PointerUp^(x, y, keys)
			END;
			down := NoButton;
		END PointerUp;

		PROCEDURE PointerLeave*;
		BEGIN
			PointerLeave^;
			IF (hover # NoButton) THEN
				Invalidate(WMRectangles.MakeRect(0, 0, GetWidth(), GetHeight()));
				hover := NoButton;
			END;
		END PointerLeave;

		PROCEDURE Draw*(canvas : Graphics.Canvas; w, h : SIZE; q : SIGNED32);
		CONST IconBorder  = 5;
		VAR
			color, tc, sw : SIGNED32; tx, ty, dx, dy : SIZE; fw, fh : FLOAT32; a, b, c, img : Graphics.Image; title : String;
			f : Graphics.Font;
			iconSize, closeImageWidth, offsetX := 0, imgWidth := 0: SIZE;
			VAR style := manager.GetStyle();
			VAR offsetY := 0: SIZE;
			VAR th := style.th, rw := style.rw + style.buttonRightMargin, btm := style.buttonTopMargin : SIZE;
		BEGIN
			fw := w / GetWidth(); fh := h / GetHeight();
			IF hasFocus THEN
				tc := tac; color := sac; sw := basw; tx := tax; ty := tay
			ELSE
				tc := tic; color := sic; sw := bisw; tx := tix; ty := tiy
			END;
			IF useBitmaps THEN
				GetActivePics(a, b, c);
				RepeatMiddleHorizontal(canvas, GetWidth(), GetHeight(), w, h, q, a, b, c)
			ELSE
				canvas.Fill(WMRectangles.MakeRect(0, 0, w, h), color, Graphics.ModeSrcOverDst);
			END;

			(* Close button *)
			IF (master # NIL) & (WM.FlagClose IN master.flags) THEN
				img := closeHoverInactive IF ~hasFocus & (hover = CloseButton) & (closeHoverInactive # NIL)
					ELSE closeHover	IF (hover = CloseButton) & (closeHover # NIL)
						ELSE closeActive IF hasFocus ELSE closeInactive;

				IF img # NIL THEN
					offsetX := img.width IF style.version = 1 ELSE img.width + rw;
					offsetY := 0 IF style.version = 1 ELSE ENTIER((th - img.height) DIV 2 * fh) + btm;
					canvas.ScaleImage(img, WMRectangles.MakeRect(0, 0, img.width, img.height),
						WMRectangles.MakeRect(w - ENTIER(offsetX * fw), offsetY, w IF style.version = 1 ELSE w - ENTIER(rw * fw), offsetY + ENTIER(img.height * fh)), Graphics.ModeSrcOverDst, q);
				ELSE
					offsetX := 20 IF style.version = 1 ELSE rw + 20;
					canvas.Fill(WMRectangles.MakeRect(w - ENTIER(offsetX * fw), ENTIER(2 * fh), w IF style.version = 1 ELSE w - ENTIER(rw * fw), h), SIGNED32(0FF0000C0H), Graphics.ModeSrcOverDst);
				END;
			END;

			(* Maximize button *)
			IF (master # NIL) & (WM.FlagMaximize IN master.flags) THEN
				IF master.windowState = WindowState.Maximized THEN
					img := restoreHoverInactive IF ~hasFocus & (hover = RestoreButton) & (restoreHoverInactive # NIL)
						ELSE restoreHover IF (hover = RestoreButton) & (restoreHover # NIL)
							ELSE restoreActive IF hasFocus ELSE restoreInactive;
				ELSE
					img := maximizeHoverInactive IF ~hasFocus & (hover = MaximizeButton) & (maximizeHoverInactive # NIL)
						ELSE maximizeHover IF (hover = MaximizeButton) & (maximizeHover # NIL)
							ELSE maximizeActive IF hasFocus ELSE maximizeInactive;
				END;
				IF img # NIL THEN
					imgWidth := img.width;
					INC(offsetX, spaceBetweenButtons);
					offsetY := 0 IF style.version = 1 ELSE ENTIER((th - img.height) DIV 2 * fh) + btm;
					canvas.ScaleImage(img, WMRectangles.MakeRect(0, 0, imgWidth, img.height),
						WMRectangles.MakeRect(w - ENTIER((offsetX + imgWidth) * fw), offsetY, w - ENTIER(offsetX * fw), offsetY + ENTIER(img.height * fh)), Graphics.ModeSrcOverDst, q);
					INC(offsetX, imgWidth);
				ELSE

				END;
			END;

			(* Minimize button *)
			IF (master # NIL) & (WM.FlagMinimize IN master.flags) THEN
				img := minimizeHoverInactive IF ~hasFocus & (hover = MinimizeButton) & (minimizeHoverInactive # NIL)
					ELSE minimizeHover IF (hover = MinimizeButton) & (minimizeHover # NIL)
					ELSE minimizeActive IF hasFocus ELSE minimizeInactive;

				IF img # NIL THEN
					INC(offsetX, spaceBetweenButtons - minimizeOffset);
					imgWidth := img.width;
					offsetY := 0 IF style.version = 1 ELSE ENTIER((th - img.height) DIV 2 * fh) + btm;
					canvas.ScaleImage(img, WMRectangles.MakeRect(0, 0, imgWidth, img.height),
						WMRectangles.MakeRect(w - ENTIER((offsetX + imgWidth) * fw), offsetY, w - ENTIER(offsetX * fw), offsetY + ENTIER(img.height * fh)), Graphics.ModeSrcOverDst, q)
				ELSE
				(*	canvas.Fill(WMRectangles.MakeRect(w - ENTIER(20 * fw), ENTIER(2 * fh), w, h), SIGNED32(0FF0000C0H), Graphics.ModeSrcOverDst);  *)
				END;
			END;

			IF master # NIL THEN
				IF (master.icon # NIL) THEN
					iconSize := GetHeight()- 2*IconBorder;
					IF (iconSize * fw > 4) THEN
						canvas.ScaleImage(master.icon,
							WMRectangles.MakeRect(0, 0, master.icon.width, master.icon.height),
							WMRectangles.MakeRect(ENTIER(tx * fw), h - ENTIER((iconSize + IconBorder) * fh), ENTIER((tx + iconSize) * fw), h - ENTIER(IconBorder * fh)),
							Graphics.ModeSrcOverDst, q);
						tx := tx + iconSize + 2;
					END;
				END;
				title := master.GetTitle();
				IF title # NIL THEN
					IF (w = GetWidth()) & (h = GetHeight()) THEN
						canvas.SetColor(tc);
						canvas.DrawString(tx, ty, title^)
					ELSE
						f := Graphics.GetDefaultFont();

						f.GetStringSize(title^, dx, dy);
						IF (titleImg = NIL) OR (tx + dx > titleImg.width) OR (GetHeight() > titleImg.height)  THEN NEW(titleImg);
							Raster.Create(titleImg, tx + dx + 10, GetHeight(), Raster.BGRA8888);
							NEW(titleCanvas, titleImg);
						END;
						titleCanvas.Fill(WMRectangles.MakeRect(0, 0, titleImg.width, titleImg.height), 0, Graphics.ModeCopy);
						titleCanvas.SetColor(tc);
						titleCanvas.DrawString(tx, ty, title^);
						canvas.ScaleImage(titleImg, WMRectangles.MakeRect(0, 0, titleImg.width, titleImg.height),
							WMRectangles.MakeRect(0, 0, ENTIER(titleImg.width * fw), ENTIER(titleImg.height * fh)), Graphics.ModeSrcOverDst, q)
					END
				END
			END;
			IF ~useBitmaps THEN
				WMGraphicUtilities.ExtRectGlassShade(canvas, WMRectangles.MakeRect(0, 0, w, h), {2}, sw, FALSE)
			END
		END Draw;

		PROCEDURE CloseDispatch*(sender, data : ANY);
		VAR m : Message;
		BEGIN
			IF master = NIL THEN RETURN END;
			m.msgType := Messages.MsgClose;
			IF master.sequencer # NIL THEN
				IF ~master.sequencer.Add(m) THEN TRACE("Close message could not be queued."); END
			ELSE
				master.Handle(m);
			END;
		END CloseDispatch;

		PROCEDURE MinimizeDispatch*(sender, data : ANY);
		VAR m : Message;
		BEGIN
			IF master = NIL THEN RETURN END;
			m.msgType := Messages.MsgMinimize;
			IF master.sequencer # NIL THEN
				IF ~master.sequencer.Add(m) THEN TRACE("Maximize message could not be queued."); END;
			ELSE
				master.Handle(m);
			END;
		END MinimizeDispatch;

		PROCEDURE MaximizeDispatch*(sender, data : ANY);
		VAR m : Message;
		BEGIN
			IF master = NIL THEN RETURN END;
			m.msgType := Messages.MsgMaximize;
			m.ext := sender;
			IF master.sequencer # NIL THEN
				IF ~master.sequencer.Add(m) THEN TRACE("Maximize message could not be queued."); END;
			ELSE
				master.Handle(m);
			END;
		END MaximizeDispatch;

		PROCEDURE RestoreDispatch*(sender, data : ANY);
		VAR m : Message;
		BEGIN
			IF master = NIL THEN RETURN END;
			m.msgType := Messages.MsgRestore;
			IF master.sequencer # NIL THEN
				IF ~master.sequencer.Add(m) THEN TRACE("Maximize message could not be queued."); END;
			ELSE
				master.Handle(m);
			END;
		END RestoreDispatch;

		PROCEDURE StyleChanged*;
		VAR s : WM.WindowStyle; r : WMRectangles.Rectangle;
		BEGIN
			s := manager.GetStyle();
			useBitmaps := s.useBitmaps; sac := s.baCol; sic := s.biCol; basw := s.basw; bisw := s.bisw;
			focusthreshold := s.topFocusThreshold; threshold := s.topThreshold;

			picAa := s.taa; picBa := s.tab; picCa := s.tac;
			picAb := s.tia; picBb := s.tib; picCb := s.tic;
			tac := s.atextColor; tic := s.itextColor;
			tax := s.atextX; tix := s.itextX;
			tay := s.atextY; tiy := s.itextY;

			closeActive := s.ca; closeInactive := s.ci; closeHover := s.closeHover;
			minimizeActive := s.ma; minimizeInactive := s.mi; minimizeHover := s.minimizeHover; minimizeHoverInactive := s.minimizeHoverInactive;
			maximizeActive := s.maximizeActive; maximizeInactive := s.maximizeInactive; maximizeHover := s.maximizeHover; maximizeHoverInactive := s.maximizeHoverInactive;
			restoreActive := s.restoreActive; restoreInactive := s.restoreInactive; restoreHover := s.restoreHover; restoreHoverInactive := s.restoreHoverInactive;
			minimizeOffset := s.minimizeOffset;
			spaceBetweenButtons := s.spaceBetweenButtons;
			manager.lock.AcquireWrite;
			r := bounds;
			bounds := WMRectangles.MakeRect(master.bounds.l - s.lw, master.bounds.t - s.th, master.bounds.r + s.rw, master.bounds.t);
			WMRectangles.ExtendRect(r, bounds);
			manager.lock.ReleaseWrite;
			manager.AddDirty(r)
		END StyleChanged;

	END TopWindow;

	LeftWindow* = OBJECT(DecorWindow)

		PROCEDURE Draw*(canvas : Graphics.Canvas; w, h : SIZE; q : SIGNED32);
		VAR color, sw : SIGNED32; a, b, c : Graphics.Image;
		BEGIN
			IF hasFocus THEN color := sac; sw := basw ELSE color := sic; sw := bisw END;
			IF useBitmaps THEN
				GetActivePics(a, b, c);
				RepeatMiddleVertical(canvas, GetWidth(), GetHeight(), w, h, q, a, b, c)
			ELSE
				canvas.Fill(WMRectangles.MakeRect(0, 0, w, h), color, Graphics.ModeSrcOverDst);
				WMGraphicUtilities.ExtRectGlassShade(canvas, WMRectangles.MakeRect(0, 0, w, h), {0, 2, 3}, sw, FALSE);
			END
		END Draw;

		PROCEDURE PointerMove*(x, y : SIZE; keys : SET);
		BEGIN
			IF ~dragging & ~(WM.FlagNoResizing IN flags) THEN
				IF (y < distXY) THEN SetPointerInfo(manager.pointerULDR);
				ELSIF (y > GetHeight() - distXY) THEN SetPointerInfo(manager.pointerURDL)
				ELSE SetPointerInfo(manager.pointerLeftRight)
				END;
			END;
			PointerMove^(x, y, keys)
		END PointerMove;

		PROCEDURE StyleChanged*;
		VAR s : WM.WindowStyle; r : WMRectangles.Rectangle;
		BEGIN
			s := manager.GetStyle();
			useBitmaps := s.useBitmaps; sac := s.baCol; sic := s.biCol; basw := s.basw; bisw := s.bisw;
			focusthreshold := s.leftFocusThreshold; threshold := s.leftThreshold;

			picAa := s.laa; picBa := s.lab; picCa := s.lac;
			picAb := s.lia; picBb := s.lib; picCb := s.lic;
			manager.lock.AcquireWrite;
			r :=bounds;
			bounds := WMRectangles.MakeRect(master.bounds.l - s.lw, master.bounds.t, master.bounds.l, master.bounds.b);
			WMRectangles.ExtendRect(r, bounds);
			manager.lock.ReleaseWrite;
			manager.AddDirty(r)
		END StyleChanged;

	END LeftWindow;

	RightWindow* = OBJECT(DecorWindow)

		PROCEDURE Draw*(canvas : Graphics.Canvas; w, h : SIZE; q : SIGNED32);
		VAR color, sw : SIGNED32; a, b, c : Graphics.Image;
		BEGIN
			IF hasFocus THEN color := sac; sw := basw ELSE color := sic; sw := bisw END;
			IF useBitmaps THEN
				GetActivePics(a, b, c);
				RepeatMiddleVertical(canvas, GetWidth(), GetHeight(), w, h, q, a, b, c)
			ELSE
				canvas.Fill(WMRectangles.MakeRect(0, 0, w, h), color, Graphics.ModeSrcOverDst);
				WMGraphicUtilities.ExtRectGlassShade(canvas, WMRectangles.MakeRect(0, 0, w, h), {0, 1, 2}, sw, FALSE);
			END
		END Draw;

		PROCEDURE PointerMove*(x, y : SIZE; keys : SET);
		BEGIN
			IF ~dragging & ~(WM.FlagNoResizing IN flags) THEN
				IF (y < distXY) THEN SetPointerInfo(manager.pointerURDL);
				ELSIF (y > GetHeight() - distXY) THEN SetPointerInfo(manager.pointerULDR)
				ELSE SetPointerInfo(manager.pointerLeftRight)
				END;
			END;
			PointerMove^(x, y, keys)
		END PointerMove;

		PROCEDURE StyleChanged*;
		VAR s : WM.WindowStyle; r : WMRectangles.Rectangle;
		BEGIN
			s := manager.GetStyle();
			useBitmaps := s.useBitmaps; sac := s.baCol; sic := s.biCol; basw := s.basw; bisw := s.bisw;
			focusthreshold := s.rightFocusThreshold; threshold := s.rightThreshold;

			picAa := s.raa; picBa := s.rab; picCa := s.rac;
			picAb := s.ria; picBb := s.rib; picCb := s.ric;
			manager.lock.AcquireWrite;
			r :=bounds;
			bounds := WMRectangles.MakeRect(master.bounds.r, master.bounds.t, master.bounds.r + s.rw, master.bounds.b);
			WMRectangles.ExtendRect(r, bounds);
			manager.lock.ReleaseWrite;
			manager.AddDirty(r)
		END StyleChanged;
	END RightWindow;

	BottomWindow* = OBJECT(DecorWindow)

		PROCEDURE Draw*(canvas : Graphics.Canvas; w, h : SIZE; q : SIGNED32);
		VAR color, sw : SIGNED32; a, b, c : Graphics.Image;
		BEGIN
			IF hasFocus THEN color := sac; sw := basw ELSE color := sic; sw := bisw END;
			IF useBitmaps THEN
				GetActivePics(a, b, c);
				RepeatMiddleHorizontal(canvas, GetWidth(), GetHeight(), w, h, q, a, b, c)
			ELSE
				canvas.Fill(WMRectangles.MakeRect(0, 0, w, h), color, Graphics.ModeSrcOverDst);
				WMGraphicUtilities.ExtRectGlassShade(canvas, WMRectangles.MakeRect(0, 0, w, h), {0}, sw, FALSE);
			END
		END Draw;

		PROCEDURE PointerMove*(x, y : SIZE; keys : SET);
		BEGIN
			IF ~dragging & ~(WM.FlagNoResizing IN flags) THEN
				IF (x < distXY) THEN SetPointerInfo(manager.pointerURDL);
				ELSIF (x > GetWidth() - distXY) THEN SetPointerInfo(manager.pointerULDR);
				ELSE SetPointerInfo(manager.pointerUpDown)
				END;
			END;
			PointerMove^(x, y, keys)
		END PointerMove;

		PROCEDURE StyleChanged*;
		VAR s : WM.WindowStyle; r : WMRectangles.Rectangle;
		BEGIN
			s := manager.GetStyle();
			useBitmaps := s.useBitmaps; sac := s.baCol; sic := s.biCol; basw := s.basw; bisw := s.bisw;
			focusthreshold := s.bottomFocusThreshold; threshold := s.bottomThreshold;

			picAa := s.baa; picBa := s.bab; picCa := s.bac;
			picAb := s.bia; picBb := s.bib; picCb := s.bic;
			manager.lock.AcquireWrite;
			r := bounds;
			bounds := WMRectangles.MakeRect(master.bounds.l - s.lw, master.bounds.b, master.bounds.r + s.rw, master.bounds.b + s.bh);
			WMRectangles.ExtendRect(r, bounds);
			manager.lock.ReleaseWrite;
			manager.AddDirty(r)
		END StyleChanged;

	END BottomWindow;

	BackWindow* = OBJECT(WM.Window)
	VAR color : Graphics.Color;

		PROCEDURE &New*(bgColor: SIGNED32);
		BEGIN
			color := bgColor;
			isVisible := TRUE;
		END New;

		PROCEDURE StyleChanged*;
		VAR s : WM.WindowStyle; r : WMRectangles.Rectangle;
		BEGIN
			s := manager.GetStyle();
			IF s # NIL THEN
				IF s.desktopColor # color THEN
					color := s.desktopColor;
					r := WMRectangles.MakeRect(-10000, -10000, 10000, 10000);
					manager.AddDirty(r)
				END
			END;
		END StyleChanged;

		PROCEDURE Draw*(canvas : Graphics.Canvas; w, h : SIZE; q : SIGNED32);
		VAR rect : WMRectangles.Rectangle;
		BEGIN
			canvas.GetClipRect(rect);
			canvas.Fill(rect, color, Graphics.ModeCopy);
		END Draw;
	END BackWindow;

(** GRAPHIC TOOLS *)
(** Fill a rectangle vertically with images, repeating the middle if needed *)
PROCEDURE RepeatMiddleVertical*(canvas : Graphics.Canvas; csw, csh, w, h : SIZE; q : INTEGER; top, middle, bottom : Graphics.Image);
VAR fh : FLOAT32; y, t : SIZE;
BEGIN
	IF (csw = 0) OR (csh = 0) OR (w = 0) OR (h = 0) THEN RETURN END;
	fh := h / csh;
	y := 0;
	(* left border *)
	IF top # NIL THEN
		canvas.ScaleImage(top, WMRectangles.MakeRect(0, 0, top.width, top.height),
		WMRectangles.MakeRect(0, 0, w, ENTIER(top.height * fh)), Graphics.ModeSrcOverDst, q);
		y := top.height; DEC(csh, top.height)
	END;
	IF bottom # NIL THEN t := bottom.height ELSE t := 0 END;
	IF middle # NIL THEN
		WHILE csh - t > middle.height DO
			canvas.ScaleImage(middle, WMRectangles.MakeRect(0, 0, middle.width, middle.height),
				WMRectangles.MakeRect(0, ENTIER(y * fh), w, ENTIER((y + middle.height) * fh)), Graphics.ModeSrcOverDst, q);
			INC(y, middle.height); DEC(csh, middle.height)
		END;
		IF (csh - t) > 0 THEN
			canvas.ScaleImage(middle, WMRectangles.MakeRect(0, 0, middle.width, (csh - t)),
				WMRectangles.MakeRect(0, ENTIER(y * fh), w, ENTIER((y + (csh - t)) * fh+ 0.5)), Graphics.ModeSrcOverDst, q);
			INC(y, (csh - t));
		END;
	END;
	IF bottom # NIL THEN
		canvas.ScaleImage(bottom, WMRectangles.MakeRect(0, 0, bottom.width, bottom.height),
			WMRectangles.MakeRect(0, ENTIER(y * fh + 0.5), w, h), Graphics.ModeSrcOverDst, q)
	END;
END RepeatMiddleVertical;

(** Fill a rectangle vertically with images, repeating the middle if needed *)
PROCEDURE RepeatMiddleHorizontal*(canvas : Graphics.Canvas; csw, csh, w, h : SIZE; q : INTEGER; left, middle, right : Graphics.Image);
VAR fw : FLOAT32; x, t : SIZE;
BEGIN
	IF (csw = 0) OR (csh = 0) OR (w = 0) OR (h = 0) THEN RETURN END;
	fw := w / csw;
	x := 0;
	(* left border *)
	IF left # NIL THEN
		canvas.ScaleImage(left, WMRectangles.MakeRect(0, 0, left.width, left.height),
			WMRectangles.MakeRect(0, 0, ENTIER(left.width * fw), h), Graphics.ModeSrcOverDst, q);
		x := left.width; DEC(csw, left.width)
	END;
	IF right # NIL THEN t := right.width ELSE t := 0 END;
	IF middle # NIL THEN
		WHILE csw - t > middle.width DO
			canvas.ScaleImage(middle, WMRectangles.MakeRect(0, 0, middle.width, middle.height),
				WMRectangles.MakeRect(ENTIER(x * fw), 0, ENTIER((x + middle.width) * fw), h), Graphics.ModeSrcOverDst, q);
			INC(x, middle.width); DEC(csw, middle.width)
		END;
		IF (csw - t) > 0 THEN
			canvas.ScaleImage(middle, WMRectangles.MakeRect(0, 0, (csw - t), middle.height),
				WMRectangles.MakeRect(ENTIER(x * fw), 0, ENTIER((x + (csw - t)) * fw + 0.5), h), Graphics.ModeSrcOverDst, q);
			INC(x, (csw - t));
		END;
	END;
	IF right # NIL THEN
		canvas.ScaleImage(right, WMRectangles.MakeRect(0, 0, right.width, right.height),
			WMRectangles.MakeRect(ENTIER(x * fw + 0.5), 0, w, h), Graphics.ModeSrcOverDst, q)
	END;
END RepeatMiddleHorizontal;

END WMDefaultWindows.

Release.Rebuild -b Win64 WMMessages.Mod WMWindowManager.Mod SkinLanguage.Mod SkinEngine.Mod WMDefaultWindows.Mod WMComponents~ 