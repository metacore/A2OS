MODULE WMVNCView;	(** AUTHOR "TF"; PURPOSE "VNC Viewport"; *)

IMPORT
		Raster, Rect := WMRectangles, WMWindowManager, VNCServer, Modules, KernelLog, Commands,
		Graphics := WMGraphics, Messages := WMMessages, Strings, Texts, TextUtilities;

TYPE
	Window = WMWindowManager.Window;
	Rectangle = Rect.Rectangle;
	String = Strings.String;


	VNCView = OBJECT (WMWindowManager.ViewPort)
		VAR
			server: VNCServer.Server;
			error:BOOLEAN;
			backbuffer* : Graphics.Image;
			c : Graphics.BufferCanvas;
			state : Graphics.CanvasState;
			navig : BOOLEAN;
			scrollLock : BOOLEAN;

			fx, fy, inffx, inffy, factor, intfactor : FLOAT32;
			active : BOOLEAN;

		PROCEDURE &New*(manager:WMWindowManager.WindowManager; port, dx, dy, w, h:SIGNED32; name, password:ARRAY OF CHAR);
		VAR str : ARRAY 16 OF CHAR;
		BEGIN
			NEW(backbuffer);
			Raster.Create(backbuffer, w, h, Raster.BGR565);
			NEW(c, backbuffer);
			c.SetFont(Graphics.GetDefaultFont());
			c.SaveState(state);
			SetExtents(w, h);
			width0 := w; height0 := h;
			range.l := dx; range.t := dy; range.r := dx + w; range.b := dy + h;
			Strings.IntToStr(port, str);
			desc := "VNC view on port "; Strings.Append(desc, str);
			factor := 1; intfactor := 1;
			fx := factor; fy := factor; inffx := 1 ; inffy := inffx;
			active := FALSE;
			server := VNCServer.OpenServer(port, backbuffer, name, password, MouseEvent, KeyEvent, ClipboardEvent, CheckActive);
			IF server # NIL THEN
				manager.AddView(SELF);
				manager.RefreshView(SELF);
				error := FALSE
			ELSE error := TRUE
			END;
			Texts.clipboard.onTextChanged.Add(ClipboardChanged)
		END New;

		PROCEDURE CheckActive(nof : SIGNED32);
		BEGIN
			IF ~active & (nof > 0) THEN
				active := TRUE;
				manager.RefreshView(SELF)
			END
		END CheckActive;

		PROCEDURE Update*(r : Rectangle; top : WMWindowManager.Window);
		BEGIN
			IF ~active THEN RETURN END;
			Draw(Rect.ResizeRect(r, 1), top.prev)
		END Update;

		PROCEDURE Refresh*(top : Window);
		BEGIN
			Update(Rect.MakeRect(ENTIER(range.l)-1, ENTIER(range.t)-1, ENTIER(range.r) + 1, ENTIER(range.b) + 1), top)
		END Refresh;

		(* in wm coordinates *)
		PROCEDURE Draw(r : Rectangle; top : Window);
		VAR cur : Window;
			wr, nr : Rectangle;

			PROCEDURE InternalDraw(r : Rectangle; cur : Window);
			VAR nr, cb, tnr, dsr : Rectangle;
			BEGIN
				IF cur.useAlpha & (cur.prev # NIL)  THEN Draw(r, cur.prev)
				ELSE
					WHILE cur # NIL DO (* draw r in wm coordinates in all the windows from cur to top *)
						nr := r; cb := cur.bounds; Rect.ClipRect(nr, cb);
						dsr.l := ENTIER((nr.l - range.l) * fx) ; dsr.t := ENTIER((nr.t - range.t) * fy);
						dsr.r := ENTIER((nr.r - range.l) * fx + 0.5); dsr.b := ENTIER((nr.b - range.t) * fy + 0.5);
						IF ~Rect.RectEmpty(dsr) THEN
							c.SetClipRect(dsr);  (* Set clip rect to dsr, clipped at current window *)
							c.ClipRectAsNewLimits(ENTIER((cur.bounds.l - range.l) * fx), ENTIER((cur.bounds.t - range.t) * fy));
							(* range can not be factored out because of rounding *)
							IF navig THEN
								cur.Draw(c, ENTIER((cb.r - range.l)* fx) - ENTIER((cb.l - range.l) * fx),
													ENTIER((cb.b - range.t) * fy) - ENTIER((cb.t - range.t) * fy), 0);
							ELSE
								cur.Draw(c, ENTIER((cb.r - range.l)* fx) - ENTIER((cb.l - range.l) * fx),
													ENTIER((cb.b - range.t) * fy) - ENTIER((cb.t - range.t) * fy), 1);
							END;
							c.RestoreState(state);
						END;
						cur := cur.next
					END;
					tnr.l := ENTIER((r.l - range.l) * fx); tnr.t := ENTIER((r.t - range.t) * fy);
					tnr.r := ENTIER((r.r - range.l) * fx + 0.5); tnr.b := ENTIER((r.b - range.t) * fy + 0.5);
					ClipAtImage(tnr, backbuffer);
					server.AddDirty(tnr)
				END
			END InternalDraw;

		BEGIN
			cur := top;
			IF (cur # NIL) & (~Rect.RectEmpty(r)) THEN
				wr := cur.bounds;
				IF ~Rect.IsContained(wr, r) THEN
					IF Rect.Intersect(r, wr) THEN
						(* r contains wr calculate r -  wr and recursively call for resulting rectangles*)
						(* calculate top rectangle *)
						IF wr.t > r.t THEN Rect.SetRect(nr, r.l, r.t, r.r, wr.t); Draw(nr, cur.prev) END;
						(* calculate bottom rectangle *)
						IF wr.b < r.b THEN Rect.SetRect(nr, r.l, wr.b, r.r, r.b); Draw(nr, cur.prev) END;
						(* calculate left rectangle *)
						IF wr.l > r.l THEN Rect.SetRect(nr, r.l, MAX(r.t, wr.t), wr.l, MIN(r.b, wr.b)); Draw(nr, cur.prev) END;
						(* calculate left rectangle *)
						IF wr.r < r.r THEN Rect.SetRect(nr, wr.r, MAX(r.t, wr.t), r.r, MIN(r.b, wr.b)); Draw(nr, cur.prev) END;
						(* calculate overlapping *)
						nr := r; Rect.ClipRect(nr, wr);
						IF ~Rect.RectEmpty(nr) THEN InternalDraw(nr, cur) END
					ELSE Draw(r, cur.prev)
					END
				ELSE InternalDraw(r, cur)
				END
			END
		END Draw;

		PROCEDURE SetExtents(w, h : SIGNED32);
		BEGIN
			range.r := range.l + w; range.b := range.t + h;
		END SetExtents;

		PROCEDURE SetScaleFactor(factor : FLOAT32);
		VAR centerX, centerY : FLOAT32;
		BEGIN
			centerX := (range.l + range.r) / 2; centerY := (range.t + range.b) /2;
			fx := factor; fy := factor; inffx := 1 / factor; inffy := inffx;
			SELF.factor := factor;
			range.l := centerX - inffx * 0.5 * backbuffer.width;
			range.t := centerY - inffy * 0.5 * backbuffer.height;
			range.r := centerX + inffx * 0.5 * backbuffer.width;
			range.b := centerY + inffy * 0.5 * backbuffer.height
		END SetScaleFactor;

		PROCEDURE KeyEvent(ucs: SIGNED32; flags : SET; keysym : SIGNED32);
		VAR msg : Messages.Message;
		BEGIN
			manager.lock.AcquireWrite;
			msg.originator := SELF;
			IF keysym = 0FFC9H THEN scrollLock := ~scrollLock END;
			msg.msgType := Messages.MsgKey;
			msg.x := ucs;
			msg.y := keysym;
			msg.flags := flags;
			manager.Handle(msg);
			manager.lock.ReleaseWrite
		END KeyEvent;

		PROCEDURE MouseEvent(x, y, dz: SIGNED32; keys : SET);
		VAR msg : Messages.Message;
		BEGIN
			manager.lock.AcquireWrite;
			msg.originator := SELF;
			msg.msgType := Messages.MsgPointer;
			msg.x := ENTIER(range.l + x * inffx); msg.y := ENTIER(range.t + y * inffy);
			msg.dz := dz;
			msg.flags := keys;
			IF manager # NIL THEN manager.Handle(msg) END;
			manager.lock.ReleaseWrite
		END MouseEvent;

		PROCEDURE ClipboardEvent(text : String);
		BEGIN {EXCLUSIVE}
			Texts.clipboard.onTextChanged.Remove(ClipboardChanged);
			Texts.clipboard.AcquireWrite;
			Texts.clipboard.Delete(0, Texts.clipboard.GetLength());
			TextUtilities.StrToText(Texts.clipboard, 0, text^);
			Texts.clipboard.ReleaseWrite;
			Texts.clipboard.onTextChanged.Add(ClipboardChanged)
		END ClipboardEvent;

		PROCEDURE ClipboardChanged(sender, data : ANY);
		VAR text : String;
		BEGIN {EXCLUSIVE}
			NEW(text, 16 * 1024);
			TextUtilities.TextToStr(Texts.clipboard, text^);
			IF server = NIL THEN KernelLog.String("Cann not understand how this could possibly happen :-( "); KernelLog.Ln
			ELSE
				server.SendClipboard(text)
			END
		END ClipboardChanged;

		PROCEDURE Close;
		BEGIN
			Texts.clipboard.onTextChanged.Remove(ClipboardChanged);
			manager.RemoveView(SELF); server.Close
		END Close;

	END VNCView;

TYPE
	VVList = POINTER TO RECORD
		v:VNCView;
		next:VVList
	END;

VAR v: VVList;

PROCEDURE Bound(VAR x:SIZE; min, max:SIZE);
BEGIN
	IF x < min THEN x := min ELSE IF x > max THEN x := max END END
END Bound;

PROCEDURE ClipAtImage(VAR x: Rectangle; img:Raster.Image);
BEGIN
	Bound(x.l, 0, img.width - 1);Bound(x.r, 0, img.width - 1);
	Bound(x.t, 0, img.height - 1);Bound(x.b, 0, img.height - 1)
END ClipAtImage;

(** name password port x y w h
name and password are strings optionally in " "
use "" for no password
*)
PROCEDURE Install*(context : Commands.Context); (** name password [port [x [ y [ width [ height ] ] ] ] ] ~ *)
VAR
	name:ARRAY 100 OF CHAR;
	password: ARRAY 32 OF CHAR;
	port, dx, dy, w, h:SIGNED32;
	nv:VNCView;
	vl:VVList;
BEGIN
	context.arg.SkipWhitespace;
	context.arg.String(name);
	context.arg.SkipWhitespace;
	context.arg.String(password);
	context.arg.SkipWhitespace;

	(* port *)
	port := 5901;
	IF (context.arg.Peek() >= '0') & (context.arg.Peek() <= '9') THEN context.arg.Int(port, TRUE) END;
	context.arg.SkipWhitespace;
	(* dx *)
	dx := 0;
	IF (context.arg.Peek() >= '0') & (context.arg.Peek() <= '9') OR (context.arg.Peek()='-') THEN context.arg.Int(dx, TRUE) END;
	context.arg.SkipWhitespace;
	(* dy *)
	dy := 0; IF (context.arg.Peek() >= '0') & (context.arg.Peek() <= '9') OR (context.arg.Peek()='-') THEN context.arg.Int(dy, TRUE) END;
	context.arg.SkipWhitespace;
	(* w *)
	w := 1024; IF (context.arg.Peek() >= '0') & (context.arg.Peek() <= '9') THEN context.arg.Int(w, TRUE) END;
	context.arg.SkipWhitespace;
	(* h *)
	h := 768; IF (context.arg.Peek() >= '0') & (context.arg.Peek() <= '9') THEN context.arg.Int(h, TRUE) END;
	context.arg.SkipWhitespace;

	NEW(nv, WMWindowManager.GetDefaultManager(), port, dx, dy, w, h, name, password);
	context.out.String("VNC server started. Listening on port : "); context.out.Int(port, 4);
	context.out.Ln; context.out.String("Position (x, y): "); context.out.Int(dx, 4); context.out.String(", "); context.out.Int(dy, 4);
	context.out.Ln; context.out.String("Size (w, h): "); context.out.Int(w, 4); context.out.String(", "); context.out.Int(h, 4);
	IF ~nv.error THEN
		NEW(vl); vl.v:=nv;
		vl.next:=v; v:=vl
	END;
END Install;

PROCEDURE Uninstall*;
BEGIN
	WHILE v # NIL DO v.v.Close;  v := v.next END;
END Uninstall;

PROCEDURE Cleanup;
BEGIN
	Uninstall;
END Cleanup;

BEGIN
	Modules.InstallTermHandler(Cleanup)
END WMVNCView.

System.Free WMVNCView VNCServer~
Aos.Call WMVNCView.Install "Bluebottle VNC View1" "" 5903 0 0 1024 768~
Aos.Call WMVNCView.Install "Bluebottle VNC View1" "" 5902 1280 0 1280 1024~
Aos.Call WMVNCView.Install "Bluebottle VNC View1" "" 5903 0 0 1024 768~
Aos.Call WMVNCView.Uninstall (BYE)

