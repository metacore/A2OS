MODULE WMScreenShot;	(** AUTHOR "TF"; PURPOSE "Screenshot utility"; *)

IMPORT
	Commands, Plugins, Raster, Strings, WMGraphics, WMRectangles,
	WM := WMWindowManager;

TYPE
	View = OBJECT (WM.ViewPort)
		VAR
			backbuffer : WMGraphics.Image;
			deviceRect : WMRectangles.Rectangle;

			c : WMGraphics.BufferCanvas;
			state : WMGraphics.CanvasState;

			fx, fy, inffx, inffy, factor, intfactor : REAL;

		PROCEDURE &New*(manager : WM.WindowManager; w, h : LONGINT);
		BEGIN
			SELF.manager := manager;
			NEW(backbuffer);
			Raster.Create(backbuffer, w, h, Raster.BGR565);
			NEW(c, backbuffer);
			c.SetFont(WMGraphics.GetDefaultFont());
			c.SaveState(state);
			deviceRect := WMRectangles.MakeRect(0, 0, w, h);
			factor := 1; intfactor := 1;
			fx := factor; fy := factor; inffx := 1 ; inffy := inffx;
			SetRange(0, 0, w, h, FALSE);
			manager.AddView(SELF); manager.RefreshView(SELF);
		END New;
		(** r in wm coordinates *)
		PROCEDURE Update*(r : WMRectangles.Rectangle; top : WM.Window);
		BEGIN
			Draw(WMRectangles.ResizeRect(r, 1), top.prev) (* assuming the src-domain is only 1 *)
		END Update;

		PROCEDURE Refresh*(top : WM.Window);
		BEGIN
			Update(WMRectangles.MakeRect(ENTIER(range.l)-1, ENTIER(range.t)-1, ENTIER(range.r) + 1, ENTIER(range.b) + 1), top)
		END Refresh;

		PROCEDURE SetRange*(x, y, w, h : REAL; showTransition : BOOLEAN);

			PROCEDURE Set(x, y, w, h : REAL);
			VAR tf : REAL;
			BEGIN
				range.l := x;
				range.t := y;
				factor := (backbuffer.width) / w;
				tf := (backbuffer.height) / h;
				IF factor > tf THEN factor := tf END;
				fx := factor; fy := factor; inffx := 1 / factor; inffy := inffx;
				range.r := x + backbuffer.width * inffx;
				range.b := y + backbuffer.height * inffy;
				intfactor := factor;
				manager.RefreshView(SELF);
			END Set;

		BEGIN
			IF w = 0 THEN w := 0.001 END;
			IF h = 0 THEN h := 0.001 END;
			Set(x, y, w, h)
		END SetRange;

		(* in wm coordinates *)
		PROCEDURE Draw(r : WMRectangles.Rectangle; top : WM.Window);
		VAR cur : WM.Window;
			wr, nr : WMRectangles.Rectangle;

			PROCEDURE InternalDraw(r : WMRectangles.Rectangle; cur : WM.Window);
			VAR nr, cb, dsr : WMRectangles.Rectangle;
			BEGIN
				IF cur.useAlpha & (cur.prev # NIL)  THEN Draw(r, cur.prev)
				ELSE
					WHILE cur # NIL DO (* draw r in wm coordinates in all the windows from cur to top *)
						nr := r; cb := cur.bounds; WMRectangles.ClipRect(nr, cb);
						dsr.l := ENTIER((nr.l - range.l) * fx) ; dsr.t := ENTIER((nr.t - range.t) * fy);
						dsr.r := ENTIER((nr.r - range.l) * fx + 0.5); dsr.b := ENTIER((nr.b - range.t) * fy + 0.5);
						IF (~WMRectangles.RectEmpty(dsr)) & (WMRectangles.Intersect(dsr, deviceRect)) THEN
							c.SetClipRect(dsr);  (* Set clip rect to dsr, clipped at current window *)
							c.ClipRectAsNewLimits(ENTIER((cur.bounds.l - range.l) * fx), ENTIER((cur.bounds.t - range.t) * fy));
							(* range can not be factored out because of rounding *)
							cur.Draw(c, ENTIER((cb.r - range.l)* fx) - ENTIER((cb.l - range.l) * fx),
													ENTIER((cb.b - range.t) * fy) - ENTIER((cb.t - range.t) * fy), 1);
							c.RestoreState(state);
						END;
						cur := cur.next
					END;
				END
			END InternalDraw;

		BEGIN
			cur := top;
			IF (cur # NIL) & (~WMRectangles.RectEmpty(r)) THEN
				wr := cur.bounds;
				IF ~WMRectangles.IsContained(wr, r) THEN
					IF WMRectangles.Intersect(r, wr) THEN
						(* r contains wr calculate r -  wr and recursively call for resulting rectangles*)
						(* calculate top rectangle *)
						IF wr.t > r.t THEN WMRectangles.SetRect(nr, r.l, r.t, r.r, wr.t); Draw(nr, cur.prev) END;
						(* calculate bottom rectangle *)
						IF wr.b < r.b THEN WMRectangles.SetRect(nr, r.l, wr.b, r.r, r.b); Draw(nr, cur.prev) END;
						(* calculate left rectangle *)
						IF wr.l > r.l THEN WMRectangles.SetRect(nr, r.l, Strings.Max(r.t, wr.t), wr.l, Strings.Min(r.b, wr.b)); Draw(nr, cur.prev) END;
						(* calculate left rectangle *)
						IF wr.r < r.r THEN WMRectangles.SetRect(nr, wr.r, Strings.Max(r.t, wr.t), r.r, Strings.Min(r.b, wr.b)); Draw(nr, cur.prev) END;
						(* calculate overlapping *)
						nr := r; WMRectangles.ClipRect(nr, wr);
						IF ~WMRectangles.RectEmpty(nr) THEN InternalDraw(nr, cur) END
					ELSE Draw(r, cur.prev)
					END
				ELSE InternalDraw(r, cur)
				END
			END
		END Draw;

		PROCEDURE Close;
		BEGIN
			 manager.RemoveView(SELF)
		END Close;

	END View;

(** Parameters : filename [viewname] [width] [height] *)
PROCEDURE SnapShotView*(context : Commands.Context);
VAR manager : WM.WindowManager;
	viewportName, fn : ARRAY 100 OF CHAR;
	viewport : WM.ViewPort;
	sv : View;
	p : Plugins.Plugin;
	w, h, res : LONGINT;
BEGIN
	context.arg.SkipWhitespace; context.arg.String(fn);
	IF ~((context.arg.Peek() >= '0') & (context.arg.Peek() <= '9')) THEN
		context.arg.String(viewportName);
	END;

	manager := WM.GetDefaultManager();
	p := manager.viewRegistry.Get(viewportName);
	IF p # NIL THEN viewport := p(WM.ViewPort) ELSE viewport := WM.GetDefaultView() END;

	w := Strings.Max(ENTIER(viewport.range.r - viewport.range.l), 1);
	h := Strings.Max(ENTIER(viewport.range.b - viewport.range.t), 1);
	context.arg.SkipWhitespace;
	IF (context.arg.Peek() >= '0') & (context.arg.Peek() <= '9') THEN context.arg.Int(w, FALSE) END;
	context.arg.SkipWhitespace;
	IF (context.arg.Peek() >= '0') & (context.arg.Peek() <= '9') THEN context.arg.Int(h, FALSE) END;

	context.out.String("Screenshot : ");
	NEW(sv, manager, w, h);
	sv.SetRange(viewport.range.l, viewport.range.t, viewport.range.r, viewport.range.b, FALSE);

	WMGraphics.StoreImage(sv.backbuffer, fn, res);
	IF res = 0 THEN
		context.out.String(" Click"); context.out.Ln; context.out.String("-->  WMPicView.Open ");
		context.out.String(fn); context.out.String(" ~"); context.out.Ln;
	ELSE
		context.error.String("Failed not written : "); context.error.String(fn); context.error.Ln;
	END;
	sv.Close;
END SnapShotView;

(** Parameters : filename width height [(left top)|(left top width height)]*)
PROCEDURE SnapShotRange*(context : Commands.Context);
VAR manager : WM.WindowManager;
	fn : ARRAY 100 OF CHAR;
	sv : View;
	w, h, rl, rt, rw, rh, res : LONGINT;
BEGIN
	context.arg.SkipWhitespace; context.arg.String(fn);
	context.arg.SkipWhitespace; context.arg.Int(w, FALSE);
	IF w <1 THEN w := 1 END; IF w > 10000 THEN w := 10000 END;

	context.arg.SkipWhitespace; context.arg.Int(h, FALSE);
	IF h <1 THEN h := 1 END; IF h > 10000 THEN h := 10000 END;

	context.arg.SkipWhitespace;
	IF (context.arg.Peek() >= '0') & (context.arg.Peek() <= '9') OR (context.arg.Peek() = '-')THEN
		context.arg.SkipWhitespace; context.arg.Int(rl, FALSE);
		context.arg.SkipWhitespace; context.arg.Int(rt, FALSE);
	 END;

	rw := w; rh := h;
	context.arg.SkipWhitespace;
	IF (context.arg.Peek() >= '0') & (context.arg.Peek() <= '9') THEN
		context.arg.SkipWhitespace; context.arg.Int(rw, FALSE);
		context.arg.SkipWhitespace; context.arg.Int(rh, FALSE);
	 END;

	 IF rw <= 0 THEN rw := 1 END;
	 IF rh <= 0 THEN rh := 1 END;

	context.out.String("Screenshot : ");
	manager := WM.GetDefaultManager();
	NEW(sv, manager, w, h);
	context.out.Int(rl, 0); context.out.String(",  "); context.out.Int(rt, 0);  context.out.String(", ");
	context.out.Int(rl + rw, 0); context.out.String(", "); context.out.Int(rt + rh, 0);
	sv.SetRange(rl, rt, rw, rh, FALSE);
	context.out.String(" Click"); context.out.Ln;
	WMGraphics.StoreImage(sv.backbuffer, fn, res);
	IF res = 0 THEN
		context.out.String("-->  WMPicView.Open "); context.out.String(fn); context.out.String(" ~"); context.out.Ln;
	ELSE
		context.error.String("Failed not written : "); context.error.String(fn); context.error.Ln;
	END;
	sv.Close;
END SnapShotRange;

END WMScreenShot.

System.Free WMScreenShot ~

Take a snap shot of the default view store it in test.bmp
WMScreenShot.SnapShotView test.bmp ~

Take a snap shot of the default view store it in test.bmp scaled to 100 by 100 pixels
WMScreenShot.SnapShotView test.bmp 100 100~


Take a snap shot of the View#0 store it in test.bmp
WMScreenShot.SnapShotView test.bmp View#0 ~

Take a snap shot of the View#0 store it in test.bmp scaled to 200 by 200 pixels
WMScreenShot.SnapShotView test.bmp View#0 200 200 ~

To a image of 300 by 300 pixels store a snapshot of range -100 -100 to 200 200 in the display space
WMScreenShot.SnapShotRange test.bmp 300 300 -100 -100 300 300 ~

WMPicView.Open test.bmp ~
