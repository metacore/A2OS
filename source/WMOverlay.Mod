MODULE WMOverlay; (** AUTHOR "staubesv"; PURPOSE "Drawing over the screen"; *)

IMPORT
	Modules, Files, Inputs, Strings,
	Raster, WMRectangles, WMGraphics, WMGraphicUtilities, WMWindowManager, WMRestorable, WMDialogs;

CONST

	(* Window.mode *)
	Mode_Idle = 0;
	Mode_Drawing = 1;

	Pointer_Arrow = 0;
	Pointer_Crosshair = 1;

	NofImages = 4;
	NofFunctions = 3;

	Function_Close = 0;
	Function_Clear = 1;
	Function_ToggleMode = 2;

	IconWidth = 48;
	IconHeight = 48;
	Border = 16;

	FontName = "Vera";
	FontSize = 24;

TYPE
	Item = RECORD
		isEnabled : BOOLEAN;
		bgEnabled : LONGINT;
		rect : WMRectangles.Rectangle;
		image, imageHover : WMGraphics.Image;
	END;

TYPE
	Window = OBJECT (WMWindowManager.BufferWindow);
	VAR
		lx, ly, stringX, stringY, stringX0, stringY0 : LONGINT;
		mode : LONGINT;

		currentString : ARRAY 1024 OF CHAR;
		currentIdx : LONGINT;

		mrEnabled : BOOLEAN;
		mouseOver : LONGINT; (* index of mouse over icon, -1 of no mouse over *)
		currentPointer : LONGINT;
		currentIndex : LONGINT;
		color, bgColor : LONGINT;

		dragStartX, dragStartY : LONGINT;
		dragging, noDrag : BOOLEAN;

		modifierFlags : SET;

		items : ARRAY NofFunctions + NofImages OF Item;

		PROCEDURE &New*;
		VAR
			image, imageHover : Files.FileName; font : WMGraphics.Font;
			i : LONGINT;
		BEGIN
			Init(viewport.width0, viewport.height0, TRUE);
			lx := -1; ly := -1;
			stringX := lx; stringY := ly;
			stringX0 := stringX; stringY0 := stringY;
			currentString := ""; currentIdx := 0;
			mode := Mode_Idle;
			mrEnabled := FALSE;
			mouseOver := -1;
			color := WMGraphics.Red;
			bgColor := 0;
			dragging := FALSE; noDrag := FALSE;
			modifierFlags := {};

			FOR i := 0 TO LEN(items)-1 DO
				items[i].isEnabled := FALSE;
				items[i].bgEnabled := 0;
				items[i].rect := WMRectangles.MakeRect(
					viewport.width0 - Border - (i + 1) * (Border + IconWidth), viewport.height0 - Border - IconHeight,
					viewport.width0 - Border - i * (Border + IconWidth), viewport.height0 - Border
				);

				IF (i < NofFunctions) THEN
					image := ""; imageHover := "";
					CASE i OF
						|Function_Close:
							image := "WMIcons.tar://WMKernelLog";
						|Function_Clear:
							image := "WMOverlay.tar://trashcan.png"; imageHover := "WMOverlay.tar://trashcanHover.png";
						|Function_ToggleMode:
							image := "WMOverlay.tar://feather.png"; imageHover := "WMOverlay.tar://featherHover.png";
							items[i].bgEnabled := 0FF0030H;
					ELSE
					END;
					items[i].image := WMGraphics.LoadImage(image, TRUE);
					items[i].imageHover := WMGraphics.LoadImage(imageHover, TRUE);
				ELSE
					NEW(items[i].image);
					Raster.Create(items[i].image, img.width, img.height, img.fmt);
					Raster.Clear(items[i].image);
				END;
			END;
			currentIndex := LEN(items)-1;
			items[currentIndex].isEnabled := TRUE;
			WMWindowManager.ExtAddWindow(SELF, 0, 0, {WMWindowManager.FlagStayOnTop, WMWindowManager.FlagNavigation});
			SetTitle(Strings.NewString("Overlay"));
			SetIcon(WMGraphics.LoadImage("WMIcons.tar://WMScribble.png", TRUE));
			Fill(0);
			SetPointerInfo(manager.pointerCrosshair);
			currentPointer := Pointer_Crosshair;
			font := WMGraphics.GetFont(FontName, FontSize, {});
			IF (font # NIL) THEN canvas.SetFont(font); END;
		END New;

		PROCEDURE GetItemIndex(x, y : LONGINT) : LONGINT;
		VAR i, result : LONGINT;
		BEGIN
			i := 0; result := -1;
			WHILE (result < 0) & (i < LEN(items)) DO
				IF WMRectangles.PointInRect(x, y, items[i].rect) THEN result := i; END;
				INC(i);
			END;
			RETURN result;
		END GetItemIndex;

		PROCEDURE IsHit*(x, y : LONGINT) : BOOLEAN;
		BEGIN
			RETURN (mode = Mode_Drawing) OR (GetItemIndex(x, y) >= 0);
		END IsHit;

		PROCEDURE Draw*(canvas : WMGraphics.Canvas; width, height, quality : LONGINT);
		CONST IconBorder = 8;
		VAR image : WMGraphics.Image; nbr : ARRAY 8 OF CHAR; color, i : LONGINT;
		BEGIN
			Draw^(canvas, width, height, quality);
			FOR i := 0 TO LEN(items)-1 DO
				IF (i < NofFunctions) THEN
					IF (items[i].image # NIL) THEN
						IF (i = mouseOver) & (items[i].imageHover # NIL) THEN
							image := items[i].imageHover;
						ELSE
							image := items[i].image;
						END;
						IF items[i].isEnabled & (items[i].bgEnabled # 0) THEN
							canvas.Fill(items[i].rect, items[i].bgEnabled, WMGraphics.ModeSrcOverDst);
						END;
						canvas.ScaleImage(image,
							WMRectangles.MakeRect(0, 0, image.width, image.height),
							WMRectangles.MakeRect(items[i].rect.l + IconBorder, items[i].rect.t + IconBorder, items[i].rect.r - IconBorder, items[i].rect.b - IconBorder), WMGraphics.ModeSrcOverDst, quality)
					END;
				ELSE
					IF (i = mouseOver) THEN color := WMGraphics.Blue; ELSE color := WMGraphics.White; END;
					WMGraphicUtilities.DrawRect(canvas, items[i].rect, color, WMGraphics.ModeCopy);
					IF items[i].isEnabled THEN canvas.Fill(items[i].rect, 0FF40H, WMGraphics.ModeSrcOverDst); END;
					Strings.IntToStr(NofImages - (i - NofFunctions), nbr);
					WMGraphics.DrawStringInRect(canvas, items[i].rect, FALSE , WMGraphics.AlignCenter, WMGraphics.AlignCenter, nbr);
				END;
			END;
		END Draw;

		PROCEDURE PointerMove*(x, y : LONGINT; keys : SET);
		VAR icon, oldMouseOver : LONGINT;

			PROCEDURE InvalidateIcon(idx  : LONGINT);
			BEGIN
				IF (0 <= idx) & (idx < LEN(items)) THEN
					Invalidate(items[idx].rect);
				END;
			END InvalidateIcon;

		BEGIN
			PointerMove^(x, y, keys);

			stringX := x; stringY := y;
			stringX0 := x; stringY0 := y;
			currentString := ""; currentIdx := 0;

			icon := GetItemIndex(x, y);
			IF (icon # mouseOver) THEN
				oldMouseOver := mouseOver;
				mouseOver := icon;
				InvalidateIcon(oldMouseOver);
				InvalidateIcon(mouseOver);
			END;
			IF (icon < 0) THEN
				IF (currentPointer # Pointer_Crosshair) THEN
					currentPointer := Pointer_Crosshair;
					SetPointerInfo(manager.pointerCrosshair);
				END;
				IF (0 IN keys) & ~dragging THEN
					IF (color # 0) THEN
						canvas.Line(lx, ly, x, y, color, WMGraphics.ModeSrcOverDst);
					ELSE
						canvas.Line(lx, ly, x, y, color, WMGraphics.ModeCopy);
					END;
					Invalidate(WMRectangles.MakeRect(Strings.Min(lx, x), Strings.Min(ly, y), Strings.Max(lx, x) + 1, Strings.Max(ly, y) + 1));
				END;
			ELSIF (currentPointer # Pointer_Arrow) THEN
				currentPointer := Pointer_Arrow;
				SetPointerInfo(manager.pointerStandard);
			END;
			lx := x; ly := y
		END PointerMove;

		PROCEDURE PointerDown*(x, y : LONGINT; keys : SET);
		VAR rect : WMRectangles.Rectangle; index : LONGINT;
		BEGIN
			PointerDown^(x, y, keys);
			lx := x; ly := y;
			IF (keys  =  {1}) THEN
				mode := Mode_Idle;
				items[Function_ToggleMode].isEnabled := FALSE;
				Invalidate(items[Function_ToggleMode].rect);
			ELSIF (keys = {2}) THEN
				Fill(bgColor);
			ELSIF 0 IN keys THEN
				IF dragging & (2 IN keys) THEN
					rect := WMRectangles.MakeRect(dragStartX, dragStartY, x, y);
					canvas.Fill(rect, bgColor, WMGraphics.ModeCopy);
					Invalidate(rect);
					noDrag := TRUE;
				END;
				index := GetItemIndex(x, y);
				IF (index >= 0) THEN
					items[index].isEnabled := ~items[index].isEnabled;
					IF (items[index].bgEnabled # 0) THEN
						Invalidate(items[index].rect);
					END;
					ProcessCommand(items[index], index);
				ELSE
					IF (Inputs.Shift * modifierFlags # {}) & ~dragging THEN
						dragStartX := x; dragStartY := y;
						dragging := TRUE;
					END;
				END;
			END;
		END PointerDown;

		PROCEDURE PointerUp*(x, y : LONGINT; keys : SET);
		VAR rect : WMRectangles.Rectangle;
		BEGIN
			PointerUp^(x, y, keys);
			IF dragging & ~(0 IN keys) THEN
				IF ~noDrag THEN
					rect := WMRectangles.MakeRect(dragStartX, dragStartY, x, y);
					WMGraphicUtilities.DrawRect(canvas, rect, color, WMGraphics.ModeCopy);
					Invalidate(rect);
				END;
				dragging := FALSE; noDrag := FALSE;
			END;
		END PointerUp;

		PROCEDURE PointerLeave*;
		BEGIN
			PointerLeave^;
			IF (mouseOver >= 0) THEN mouseOver := -1; Invalidate(bounds); END;
		END PointerLeave;

		PROCEDURE ProcessCommand(item : Item; index : LONGINT);
		VAR i : LONGINT; c : WMGraphics.BufferCanvas;
		BEGIN
			IF (index = Function_Close) THEN
				Close;
			ELSIF (index = Function_ToggleMode) THEN
				mrEnabled := FALSE;
				IF (mode = Mode_Idle) THEN mode := Mode_Drawing; ELSE mode := Mode_Idle; END;
			ELSIF (index = Function_Clear) THEN
				Fill(0);
			ELSE
				FOR i := NofFunctions TO LEN(items)-1 DO
					items[i].isEnabled := (i = index);
				END;
				IF (currentIndex # index) THEN
					NEW(c, items[currentIndex].image);
					c.DrawImage(0, 0, img, WMGraphics.ModeCopy);
					currentIndex := index;
					canvas.DrawImage(0, 0, items[index].image, WMGraphics.ModeCopy);
				END;
				Invalidate(WMRectangles.MakeRect(0, 0, GetWidth(), GetHeight()));
			END;
		END ProcessCommand;

		PROCEDURE FocusLost*;
		BEGIN
			FocusLost^;
			modifierFlags := {};
		END FocusLost;

		PROCEDURE Fill(color : LONGINT);
		BEGIN
			canvas.Fill(WMRectangles.MakeRect(0, 0, GetWidth(), GetHeight()), color, WMGraphics.ModeCopy);
			Invalidate(WMRectangles.MakeRect(0, 0, GetWidth(), GetHeight()))
		END Fill;

		PROCEDURE KeyEvent*(ucs : LONGINT; flags : SET; keySym : LONGINT);
		VAR
			filename : Files.FileName; newImg : WMGraphics.Image; oldMode: LONGINT; res: WORD;
			string : ARRAY 2 OF CHAR; dx, dy : LONGINT;
			font : WMGraphics.Font;
		BEGIN
			modifierFlags := flags;
			IF (Inputs.Release IN flags) THEN RETURN; END;
			IF (Inputs.Ctrl * flags # {}) THEN
				IF (Inputs.Shift * flags # {}) THEN
					IF (ucs = ORD("1")) THEN bgColor := WMGraphics.Red;
					ELSIF (ucs = ORD("2")) THEN bgColor := WMGraphics.Black;
					ELSIF (ucs = ORD("3")) THEN bgColor := WMGraphics.White;
					ELSIF (ucs = ORD("4")) THEN bgColor := WMGraphics.Blue;
					ELSIF (ucs = ORD("5")) THEN bgColor := WMGraphics.Green;
					ELSIF (ucs = ORD("0")) THEN bgColor := 0;
					END;
					Fill(bgColor);
				ELSE
					IF (ucs = ORD("1")) THEN color := WMGraphics.Red;
					ELSIF (ucs = ORD("2")) THEN color := WMGraphics.Black;
					ELSIF (ucs = ORD("3")) THEN color := WMGraphics.White;
					ELSIF (ucs = ORD("4")) THEN color := WMGraphics.Blue;
					ELSIF (ucs = ORD("5")) THEN color := WMGraphics.Green;
					ELSIF (ucs = ORD("0")) THEN color := 0;
					ELSIF ucs = ORD("s") THEN
						filename := "scribble.bmp";
						oldMode := mode;
						mode := Mode_Idle;
						IF WMDialogs.QueryString("Save as :", filename) = WMDialogs.ResOk THEN
							WMGraphics.StoreImage(img, filename, res);
							IF (res # 0) THEN
								WMDialogs.Error("Sorry", "The image could not be stored. Try another file name.");
							END;
						END;
						mode := oldMode;
					ELSIF (ucs= ORD("l")) THEN
						filename := "";
						oldMode := mode;
						mode := Mode_Idle;
						IF WMDialogs.QueryString("Load from: ", filename) = WMDialogs.ResOk THEN
							newImg := WMGraphics.LoadImage(filename, FALSE);
							IF (res = 0) THEN
								Fill(0);
								img := newImg;
								Invalidate(WMRectangles.MakeRect(0, 0, GetWidth(), GetHeight()));
							ELSE
								WMDialogs.Error("Sorry", "Could not load the image file");
							END;
						END;
						mode := oldMode;
					END;
				END;
			ELSIF (32 <= ucs) & (ucs < 128) & (keySym # 0FF08H) THEN
				string[0] := CHR(ucs); string[1] := 0X;
				canvas.SetColor(color);
				canvas.DrawString(stringX, stringY, string);
				font := canvas.GetFont();
				font.GetStringSize(string, dx, dy);
				Invalidate(WMRectangles.MakeRect(stringX, stringY - dy, stringX + dx, stringY + dy));
				stringX := stringX + dx;
				IF (currentIdx < LEN(currentString)) THEN currentString[currentIdx] := CHR(ucs); INC(currentIdx); END;
			ELSIF (ucs = 13) THEN
				font := canvas.GetFont();
				font.GetStringSize("X", dx, dy);
				stringX := stringX0;
				stringY := stringY + dy + 4;
				currentString := "";
				currentIndex := 0;
			ELSIF (keySym = 0FF08H) THEN (* backspace *)
				IF (currentIdx > 0) THEN
					font := canvas.GetFont();
					string[0] := currentString[currentIdx-1]; string[1] := 0X;
					font.GetStringSize(string, dx, dy);
					canvas.SetColor(bgColor);
					stringX := stringX - dx;
					canvas.DrawString(stringX, stringY, string);
					Invalidate(WMRectangles.MakeRect(stringX, stringY - dy, stringX + dx, stringY + dy));
					DEC(currentIdx);
				END;
			END;
		END KeyEvent;
	END Window;

VAR
	window : Window;
	viewport : WMWindowManager.ViewPort;

PROCEDURE Open*;
BEGIN {EXCLUSIVE}
	IF (window # NIL) THEN window.Close; END;
	NEW(window);
END Open;

PROCEDURE Close*;
BEGIN {EXCLUSIVE}
	IF (window # NIL) THEN window.Close; window := NIL; END;
END Close;

PROCEDURE Toggle*;
BEGIN {EXCLUSIVE}
	IF (window = NIL) THEN
		NEW(window);
	ELSE
		window.Close; window := NIL;
	END;
END Toggle;

PROCEDURE ToggleMode*;
BEGIN {EXCLUSIVE}
	IF (window = NIL) THEN
		NEW(window);
		window.mode := Mode_Drawing;
	ELSE
		IF window.mode = Mode_Drawing THEN window.mode := Mode_Idle; ELSE window.mode := Mode_Drawing; END;
	END;
END ToggleMode;

PROCEDURE Restore*(context : WMRestorable.Context);
BEGIN {EXCLUSIVE}
	IF (window = NIL) THEN
		NEW(window); (* ignore context information here *)
	END;
END Restore;

PROCEDURE Cleanup;
BEGIN
	IF (window # NIL) THEN window.Close; window := NIL; END;
END Cleanup;

BEGIN
	viewport := WMWindowManager.GetDefaultView();
	ASSERT(viewport # NIL);
	Modules.InstallTermHandler(Cleanup)
END WMOverlay.

System.Free WMOverlay ~
WMOverlay.Open ~