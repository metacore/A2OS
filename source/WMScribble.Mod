MODULE WMScribble;	(** AUTHOR "TF"; PURPOSE "Example program"; *)

IMPORT WMWindowManager, Strings, WMGraphics, WMRectangles, Modules, WMDialogs;

TYPE
	ScribbleWindow = OBJECT (WMWindowManager.BufferWindow);
	VAR lx, ly : LONGINT;

	     PROCEDURE &New*;
	     BEGIN
			Init(400, 400, FALSE);
			WMWindowManager.AddWindow(SELF, 200, 200);
			SetTitle(Strings.NewString("Scribble Example"));
			SetIcon(WMGraphics.LoadImage("WMIcons.tar://WMScribble.png", TRUE));
			canvas.Fill(WMRectangles.MakeRect(0, 0, GetWidth(), GetHeight()), WMGraphics.White, WMGraphics.ModeCopy);
			Invalidate(WMRectangles.MakeRect(0, 0, GetWidth(), GetHeight()));
			SetPointerInfo(manager.pointerCrosshair)
	     END New;

		PROCEDURE PointerMove*(x, y : LONGINT; keys : SET);
		BEGIN
			IF 0 IN keys THEN canvas.Line(lx, ly, x, y, WMGraphics.Blue, WMGraphics.ModeSrcOverDst);
				Invalidate(
					WMRectangles.MakeRect(Strings.Min(lx, x), Strings.Min(ly, y), Strings.Max(lx, x) + 1, Strings.Max(ly, y) + 1)
				)
			 END;
			lx := x; ly := y
		END PointerMove;

		PROCEDURE PointerDown*(x, y : LONGINT; keys : SET);
		BEGIN
			lx := x; ly := y;
			IF 2 IN keys THEN
				canvas.Fill(WMRectangles.MakeRect(0, 0, GetWidth(), GetHeight()), WMGraphics.White, WMGraphics.ModeCopy);
				Invalidate(WMRectangles.MakeRect(0, 0, GetWidth(), GetHeight()))
			END
		END PointerDown;

		PROCEDURE KeyEvent*(ucs : LONGINT; flags : SET; keySym : LONGINT);
		VAR res: LONGINT; filename : ARRAY 128 OF CHAR;
		BEGIN
			IF ucs = ORD("s") THEN
				filename := "scribble.bmp";
				IF WMDialogs.QueryString("Save as :", filename) = WMDialogs.ResOk THEN
					WMGraphics.StoreImage(img, filename, res);
					IF res # 0 THEN
						WMDialogs.Error("Sorry", "The image could not be stored. Try another file name.");
					END
				END
			END
		END KeyEvent;
	END ScribbleWindow;

VAR s : ScribbleWindow;

PROCEDURE Open*;
BEGIN {EXCLUSIVE}
	IF s # NIL THEN s.Close END; NEW(s);
END Open;

PROCEDURE Cleanup;
BEGIN
	IF s # NIL THEN s.Close END
END Cleanup;

BEGIN
	Modules.InstallTermHandler(Cleanup)
END WMScribble.

SystemTools.Free WMScribble ~
WMScribble.Open ~
WMPicView.Open scribble.bmp ~