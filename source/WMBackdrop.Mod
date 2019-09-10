MODULE WMBackdrop;	(** AUTHOR "TF"; PURPOSE "Backdrop images"; *)

(* 03-04-03	RG: Context menu support added *)

IMPORT
	Kernel, Files, KernelLog, Streams, Modules, Commands, Options, Strings, WMRectangles, Raster, WMMessages,
	WMWindowManager, WMGraphics, TFClasses, WMPopups, WMComponents, WMRestorable, WMDialogs, XML;

CONST
	ImagesFile = "Wallpapers.txt";

TYPE

	ImageInfo = RECORD
		filename: Files.FileName;
		img: WMGraphics.Image;
	END;

	Window = OBJECT(WMWindowManager.Window)
	VAR
		img : WMGraphics.Image;
		picname : ARRAY 256 OF CHAR;
		changeable, stop: BOOLEAN;
		interval: SIGNED32; (* in seconds *)
		timer : Kernel.Timer;

		currentImg: SIGNED32;

		fullscreen : BOOLEAN;
		fullscreenX, fullscreenY, fullscreenW, fullscreenH : SIGNED32;

		PROCEDURE & New*;
		BEGIN
			isVisible := TRUE;
			picname := "";
			changeable := FALSE; stop := FALSE;
			interval := 0;
			NEW(timer);
			currentImg := -1;
			fullscreen := FALSE;
			SetTitle(Strings.NewString("Backdrop"));
		END New;

		PROCEDURE Draw*(canvas : WMGraphics.Canvas; w, h : SIZE; q : SIGNED32);
		BEGIN
			IF img # NIL THEN
				canvas.ScaleImage(img,
					WMRectangles.MakeRect(0, 0, img.width, img.height),
					WMRectangles.MakeRect(0, 0, w, h), WMGraphics.ModeCopy, q);
			END
		END Draw;

		PROCEDURE PointerDown*(x, y : SIZE; keys : SET);
		VAR view : WMWindowManager.ViewPort;
			w, h : FLOAT32; originator : ANY;
			contextMenu : WMPopups.Popup;
		BEGIN
			originator := sequencer.GetOriginator();
			IF (originator # NIL) & (originator IS WMWindowManager.ViewPort) THEN
				IF keys={0} THEN
					view := originator(WMWindowManager.ViewPort);
					w := bounds.r - bounds.l;
					h := bounds.b - bounds.t;
					view.SetRange(bounds.l, bounds.t, w, h, TRUE);
				ELSIF keys={2} THEN
					NEW(contextMenu);
					IF ~fullscreen THEN contextMenu.Add("Full screen", HandleFullScreen); END;
					IF (imgList # NIL) & (LEN(imgList) > 0) THEN
						contextMenu.Add("Next", Change);
						IF changeable THEN
							contextMenu.Add("Stop Change", HandleChangeable)
						ELSE
							contextMenu.Add("Change", HandleChangeable)
						END;
					END;
					contextMenu.Add("Remove", HandleRemove);
					contextMenu.Popup(bounds.l+x, bounds.t+y)
				END
			END
		END PointerDown;

		PROCEDURE SetChangeable(c: BOOLEAN);
		BEGIN{EXCLUSIVE}
			changeable := c
		END SetChangeable;

		PROCEDURE HandleChangeable(sender, data: ANY);
		VAR str: ARRAY 32 OF CHAR; value, res: SIGNED32;
		BEGIN
			IF changeable THEN
				SetChangeable(FALSE);
			ELSE
				str := "300";
				res := WMDialogs.QueryString("Interval (in sec.)", str);
				IF res= WMDialogs.ResOk THEN
					Strings.StrToInt(str, value);
					IF value > 0 THEN
						interval := value * 1000;
					ELSE
						interval := 30 * 1000;
					END;
					SetChangeable(TRUE);
				ELSE
					interval := 0;
					SetChangeable(FALSE);
				END;
			END;
			timer.Wakeup;
		END HandleChangeable;

		PROCEDURE HandleFullScreen(sender, par: ANY);
		VAR view : WMWindowManager.ViewPort; w, h : FLOAT32; originator : ANY;
		BEGIN
			manager.SetFocus(SELF);
			originator := sender(WMComponents.Component).sequencer.GetOriginator();
			manager.SetFocus(SELF);
			view := originator(WMWindowManager.ViewPort);
			w := bounds.r - bounds.l;
			h := bounds.b - bounds.t;
			view.SetRange(bounds.l, bounds.t, w, h, TRUE);
		END HandleFullScreen;

		PROCEDURE HandleRemove(sender, par: ANY);
		BEGIN
			Stop();
			manager.SetFocus(SELF);
			manager.Remove(SELF);
			windowList.Remove(SELF)
		END HandleRemove;

		PROCEDURE Handle*(VAR x: WMMessages.Message);
		VAR configuration : XML.Element; value : SIGNED32;
		BEGIN
			IF (x.msgType = WMMessages.MsgExt) & (x.ext # NIL) THEN
				IF (x.ext IS WMRestorable.Storage) THEN
					NEW(configuration); configuration.SetName("Configuration");
					WMRestorable.StoreString(configuration, "Image", picname);
					IF changeable THEN value := interval; ELSE value := 0; END;
					WMRestorable.StoreLongint(configuration, "ChangeInterval", value);
					WMRestorable.StoreBoolean(configuration, "Fullscreen", fullscreen);
					WMRestorable.StoreLongint(configuration, "FullscreenX", fullscreenX);
					WMRestorable.StoreLongint(configuration, "FullscreenY", fullscreenY);
					WMRestorable.StoreLongint(configuration, "FullscreenW", fullscreenW);
					WMRestorable.StoreLongint(configuration, "FullscreenH", fullscreenH);
					x.ext(WMRestorable.Storage).Add("Backdrop", "WMBackdrop.Restore", SELF, configuration)
				ELSE Handle^(x)
				END
			ELSE Handle^(x)
			END
		END Handle;

		PROCEDURE Change(sender, data: ANY);
		VAR index: SIZE; img : WMGraphics.Image;
		BEGIN
			IF imgList # NIL THEN

				IF (currentImg < 0) THEN
					(* First time we change the image. If the current image is part of the image list, set the index to it *)
					currentImg := FindIndex(picname);
				END;

				REPEAT
					INC(currentImg);
					index := currentImg  MOD LEN(imgList);
				UNTIL (imgList[index].filename # "");

				KernelLog.String("WMBackdrop: Changing to  "); KernelLog.String(imgList[index].filename); KernelLog.Ln;

				IF imgList[index].img = NIL THEN
					img := GetImage(imgList[index].filename, GetWidth(), GetHeight());
					IF img = NIL THEN
						KernelLog.String("WBackdrop: Image could not be loaded."); KernelLog.Ln;
						RETURN
					ELSE
						imgList[index].img := img;
					END
				END;
				BEGIN{EXCLUSIVE}
					COPY(imgList[index].filename, picname);
					SELF.img := imgList[index].img;
					Invalidate(WMRectangles.MakeRect(0, 0, GetWidth(), GetHeight()))
				END
			END
		END Change;

		PROCEDURE Stop;
		BEGIN
			BEGIN{EXCLUSIVE}
				stop := TRUE;
			END;
			timer.Wakeup();
			BEGIN {EXCLUSIVE}
				AWAIT(~stop)
			END
		END Stop;


	BEGIN {ACTIVE}
		LOOP
			BEGIN {EXCLUSIVE}
				AWAIT(changeable OR stop);
			END;
			IF stop THEN EXIT END;
			Change(NIL, NIL);
			timer.Sleep(interval);
			IF stop THEN EXIT END
		END;

		BEGIN{EXCLUSIVE}
			stop := FALSE;
		END
	END Window;

VAR
	windowList : TFClasses.List;
	imgList: POINTER TO ARRAY OF ImageInfo;

PROCEDURE GetImage(CONST name : ARRAY OF CHAR; w, h : SIZE) : WMGraphics.Image;
VAR img, t : WMGraphics.Image;
	i, count : SIZE; ptr : ANY;

BEGIN
	img := NIL;
	windowList.Lock;
	i := 0; count := windowList.GetCount();
	WHILE (img = NIL) & (i < count) DO
		ptr := windowList.GetItem(i);
		IF (ptr(Window).picname = name) & (
			(ptr(Window).img.width = w) & (ptr(Window).img.height = h)
			OR ( (w = 0) OR (h = 0)))
		 THEN
			img := ptr(Window).img
		END;
		INC(i)
	END;
	windowList.Unlock;
	IF img = NIL THEN
		t := WMGraphics.LoadImage(name, TRUE);
		IF t # NIL THEN
			IF w = 0 THEN w := t.width END;
			IF h = 0 THEN h := t.height END;
			img := GetResizedImage(t, w, h);
		END
	END;
	KernelLog.Ln;
	RETURN img
END GetImage;

PROCEDURE GetResizedImage(image : WMGraphics.Image; width, height : SIZE) : WMGraphics.Image;
VAR canvas : WMGraphics.BufferCanvas; resizedImage : WMGraphics.Image;
BEGIN
	ASSERT(image # NIL);
	NEW(resizedImage); Raster.Create(resizedImage, width, height, WMWindowManager.format);
	NEW(canvas, resizedImage);
	canvas.ScaleImage(image,
		WMRectangles.MakeRect(0, 0, image.width-1, image.height-1),
		WMRectangles.MakeRect(0, 0, width, height),
		WMGraphics.ModeCopy, WMGraphics.ScaleBilinear);
	ASSERT(resizedImage # NIL);
	RETURN resizedImage;
END GetResizedImage;

(* Return index of img *)
PROCEDURE FindIndex(CONST imageName : ARRAY OF CHAR) : SIGNED32;
VAR index : SIGNED32;
BEGIN
	index := -1;
	IF (imageName # "") & (imgList # NIL) THEN
		index := 0;
		WHILE (index < LEN(imgList)) & (imgList[index].filename # imageName) DO INC(index); END;
		IF (index >= LEN(imgList)) THEN (* not found *) index := -1; END;
	END;
	RETURN index;
END FindIndex;

PROCEDURE DefaultPos(VAR x, y, w, h : SIZE);
VAR manager : WMWindowManager.WindowManager;
	view : WMWindowManager.ViewPort;
	s : WMWindowManager.WindowStyle;
BEGIN
	manager := WMWindowManager.GetDefaultManager();
	view := WMWindowManager.GetDefaultView();
	s := manager.GetStyle();
	x := ENTIER(view.range.l); y := ENTIER(view.range.t);
	w := ENTIER(view.range.r - view.range.l);
	h := ENTIER(view.range.b - view.range.t);
END DefaultPos;

PROCEDURE Rearrange;
VAR ptr : ANY; i : SIZE; manager : WMWindowManager.WindowManager;
BEGIN
	(* rearrange backrops so the latest added is on top to avoid confusion in the user *)
	manager := WMWindowManager.GetDefaultManager();
	windowList.Lock;
	FOR i := windowList.GetCount() - 1 TO 0 BY -1 DO
		ptr := windowList.GetItem(i);
		manager.ToBack(ptr(WMWindowManager.Window))
	END;
	windowList.Unlock;
END Rearrange;

(**
	parameters x y w h
	defaults : x = 0 y = 0 w = img.width h = img.height
	any parameter can be replaced by ? to use the respective position or size of the current viewport *)
PROCEDURE AddBackdropImage*(context : Commands.Context); (** [Options] imagename ~ *)
VAR
	options : Options.Options;
	manager : WMWindowManager.WindowManager;
	view : WMWindowManager.ViewPort;
	bw : Window;
	img : WMGraphics.Image;
	x, y, tx, ty, tw, th : SIZE;
	fx, fy, fw, fh : SIGNED32;
	width, height : SIZE;
	name : Files.FileName;
BEGIN {EXCLUSIVE}
	NEW(options);
	options.Add("f", "fullscreen", Options.Flag);
	IF options.Parse(context.arg, context.error) THEN
		context.arg.SkipWhitespace; context.arg.String(name);

		IF options.GetFlag("fullscreen") THEN
			context.arg.SkipWhitespace;context.arg.Int(fx, FALSE);
			context.arg.SkipWhitespace;context.arg.Int(fy, FALSE);
			context.arg.SkipWhitespace;context.arg.Int(fw, FALSE);
			context.arg.SkipWhitespace; context.arg.Int(fh, FALSE);
			IF (fw = 0) THEN fw := 1; END;
			IF (fh = 0) THEN fh := 1; END;
			view := WMWindowManager.GetDefaultView();
			x := fx * view.width0;
			y := fy * view.height0;
			width := fw* view.width0;
			height := fh * view.height0;
		ELSE
			DefaultPos(tx, ty, tw, th);
			IF context.arg.Peek() = '?' THEN
				x := tx; context.arg.SkipBytes(1); context.arg.SkipWhitespace();
			ELSE
				x := 0;
				IF (context.arg.Peek() >= '0') & (context.arg.Peek() <= '9') OR (context.arg.Peek() = '-') THEN context.arg.Size(x, TRUE) END;
				context.arg.SkipWhitespace();
			END;

			IF context.arg.Peek() = '?' THEN
				y := ty; context.arg.SkipBytes(1); context.arg.SkipWhitespace();
			ELSE
				y := 0;
				IF (context.arg.Peek() >= '0') & (context.arg.Peek() <= '9') OR (context.arg.Peek() = '-') THEN context.arg.Size(y, TRUE) END;
				context.arg.SkipWhitespace();
			END;
			IF context.arg.Peek() = '?' THEN
				width := tw; context.arg.SkipBytes(1); context.arg.SkipWhitespace();
			ELSE
				width := 0;
				IF (context.arg.Peek() >= '0') & (context.arg.Peek() <= '9') OR (context.arg.Peek() = '-') THEN context.arg.Size(width, TRUE) END;
				context.arg.SkipWhitespace();
			END;
			IF context.arg.Peek() = '?' THEN
				height := th; context.arg.SkipBytes(1); context.arg.SkipWhitespace();
			ELSE
				height := 0;
				IF (context.arg.Peek() >= '0') & (context.arg.Peek() <= '9') OR (context.arg.Peek() = '-') THEN context.arg.Size(height, TRUE) END;
				context.arg.SkipWhitespace();
			END;
		END;

		img := GetImage(name, width, height);
		IF img = NIL THEN
			context.error.String("WMBackdrop: Image '"); context.error.String(name);
			context.error.String("' could not be loaded."); context.error.Ln;
			RETURN
		END;

		(* use image size *)
		IF (width = 0) OR (height = 0) THEN
			width := img.width;
			height := img.height;
		END;

		NEW(bw);
		COPY(name, bw.picname);
		bw.bounds := WMRectangles.MakeRect(0, 0, width, height);
		bw.img := img;
		IF options.GetFlag("fullscreen") THEN
			bw.fullscreen := TRUE;
			bw.fullscreenX := fx; bw.fullscreenY := fy; bw.fullscreenW := fw; bw.fullscreenH := fh;
		END;
		windowList.Add(bw);
		manager := WMWindowManager.GetDefaultManager();
		manager.Add(x, y, bw, {WMWindowManager.FlagStayOnBottom, WMWindowManager.FlagHidden});
		Rearrange;
	END;
END AddBackdropImage;

(* restore the desktop *)
PROCEDURE Restore*(context : WMRestorable.Context);
VAR w : Window;
	 xml : XML.Element;
	 s : Strings.String; img : WMGraphics.Image;
	 view : WMWindowManager.ViewPort;
BEGIN
	IF context.appData # NIL THEN
		xml := context.appData(XML.Element);
		s := xml.GetAttributeValue("Image");
		IF s # NIL THEN
			img := GetImage(s^, 0, 0);
			IF img # NIL THEN

				NEW(w);
				WMRestorable.LoadBoolean(xml, "Fullscreen", w.fullscreen);

				IF w.fullscreen THEN
					view := WMWindowManager.GetDefaultView();
					IF (view # NIL) THEN
						WMRestorable.LoadLongint(xml, "FullscreenX", w.fullscreenX);
						WMRestorable.LoadLongint(xml, "FullscreenY", w.fullscreenY);
						WMRestorable.LoadLongint(xml, "FullscreenW", w.fullscreenW);
						WMRestorable.LoadLongint(xml, "FullscreenH", w.fullscreenH);
						context.l := w.fullscreenX * view.width0;
						context.r := context.l + (w.fullscreenW * view.width0);
						context.t := w.fullscreenY * view.height0;
						context.b := context.t + (w.fullscreenH * view.height0);
					END;
				END;

				COPY(s^, w.picname);
				w.img :=  GetResizedImage(img, context.r - context.l, context.b - context.t);
				windowList.Add(w);
				WMRestorable.AddByContext(w, context);
				Rearrange
			END
		END;
		s := xml.GetAttributeValue("ChangeInterval");
		IF (s # NIL) & (w # NIL) THEN
			IF s^ # "0" THEN
				Strings.StrToInt(s^, w.interval);
				IF w.interval > 500 THEN
					w.SetChangeable(TRUE);
				END;
			END;
		END;
	END
END Restore;

PROCEDURE Cleanup;
VAR manager : WMWindowManager.WindowManager;
	ptr : ANY;
	w: Window;
	i : SIZE;
BEGIN
	manager := WMWindowManager.GetDefaultManager();
	windowList.Lock;
	FOR i := 0 TO windowList.GetCount() - 1 DO
		ptr := windowList.GetItem(i);
		w := ptr(Window);
		w.Stop;
		manager.Remove(ptr(WMWindowManager.Window))
	END;
	windowList.Unlock;
END Cleanup;

PROCEDURE RemoveAll*;
BEGIN
	Cleanup;
END RemoveAll;

PROCEDURE ChangeList;
VAR
	f: Files.File;
	r: Files.Reader;
	i, nr: SIGNED32;

	PROCEDURE NumberImg(): SIGNED32;
	VAR line: Files.FileName; r: Files.Reader; nr: SIGNED32;
	BEGIN
		Files.OpenReader(r, f, 0);
		WHILE (r.res = Streams.Ok) DO
			r.Ln(line);
			INC(nr);
		END;
		RETURN nr;
	END NumberImg;

BEGIN
	f := Files.Old(ImagesFile);
	IF (f # NIL) THEN
		nr := NumberImg();
		NEW(imgList, nr);
		Files.OpenReader(r, f, 0);
		i := 0;
		WHILE (r.res = Streams.Ok) DO
			r.Ln(imgList[i].filename);
			INC(i);
		END;
		KernelLog.String("WMBackdrop: Image list "); KernelLog.String(ImagesFile); KernelLog.String(" loaded."); KernelLog.Ln;
	ELSE
		KernelLog.String("WMBackdrop: No image list found");KernelLog.Ln;
	END
END ChangeList;

BEGIN
	NEW(windowList);
	ChangeList;
	Modules.InstallTermHandler(Cleanup)
END WMBackdrop.

System.Free WMBackdrop ~

(* install backdrop at current view position and size *)
WMBackdrop.AddBackdropImage "Desktop1_1024x768.png" ? ? ? ?
WMBackdrop.AddBackdropImage BluebottlePic0.png ? ? ? ?~
WMBackdrop.AddBackdropImage AosBackdrop.png ? ? ? ?

(* install backdrop at specified position with original size of the image *)
WMBackdrop.AddBackdropImage BluebottlePic0.png ~
WMBackdrop.AddBackdropImage BluebottlePic0.png 0 0 ~
WMBackdrop.AddBackdropImage AosBackdrop.png 1280 0 ~

(* install backdrop whose size is specified relative to the view port size *)
WMBackdrop.AddBackdropImage --fullscreen BluebottlePic0.png ~
WMBackdrop.AddBackdropImage --fullscreen BluebottlePic0.png -1 0 ~

