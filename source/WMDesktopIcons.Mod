MODULE WMDesktopIcons; (** AUTHOR "staubesv"; PURPOSE "Programmable Desktop Icons"; *)

IMPORT
	Modules, Commands, Options, Strings,
	WMWindowManager, Raster, WMRasterScale, WMRectangles, WMGraphics, WMGraphicUtilities,
	WMRestorable, WMMessages, WMComponents, WMProperties, WMStandardComponents,
	WMPopups, WMDialogs;

CONST
	CmSetCommandString = 1;
	CmSetImageName = 2;
	CmSetCaption = 3;

TYPE

	ContextMenuPar = OBJECT
	VAR
		mode : SIGNED32;

		PROCEDURE &New*(mode : SIGNED32);
		BEGIN
			SELF.mode := mode;
		END New;

	END ContextMenuPar;

TYPE

	KillerMsg = OBJECT
	END KillerMsg;

	IconWindow = OBJECT(WMComponents.FormWindow);
	VAR
		dragging, resizing : BOOLEAN;
		lastX, lastY : SIZE;
		iconComponent : IconComponent;
		contextMenu : WMPopups.Popup;

		PROCEDURE &New*(c : WMRestorable.Context; flags : SET);
		VAR configuration : WMRestorable.XmlElement; color : SIGNED32; string : Strings.String;
		BEGIN
			IncCount;
			dragging := FALSE; resizing := FALSE;
			Init(120, 40, TRUE);
			manager := WMWindowManager.GetDefaultManager();

			NEW(iconComponent);
			iconComponent.alignment.Set(WMComponents.AlignClient);
			SetContent(iconComponent);
			SetTitle(StrWindowTitle);

			IF (c # NIL) THEN
				flags := {};
				configuration := WMRestorable.GetElement(c, "Configuration");
				IF configuration # NIL THEN
					WMRestorable.LoadStringPtr(configuration, "commandString", string); iconComponent.commandString.Set(string);
					WMRestorable.LoadStringPtr(configuration, "imageName", string); iconComponent.imageName.Set(string);
					WMRestorable.LoadStringPtr(configuration, "caption", string); iconComponent.caption.Set(string);
					WMRestorable.LoadLongint(configuration, "color", color); iconComponent.color.Set(color);
				END;
				WMRestorable.AddByContext(SELF, c);
				Resized(c.r - c.l, c.b - c.t);
			ELSE
				WMWindowManager.ExtAddWindow(SELF, 50, 50, flags)
			END;
		END New;

		PROCEDURE PointerDown*(x, y:SIZE; keys:SET);
		BEGIN
			lastX := bounds.l+x; lastY:=bounds.t+y;
			IF keys = {0} THEN
				dragging := TRUE;
			ELSIF keys = {0,2} THEN
				dragging := FALSE;
				resizing := TRUE;
			ELSIF (keys = {1}) THEN
				ExecuteCommand;
			ELSIF keys = {2} THEN
				NEW(contextMenu);
				contextMenu.Add("Close", HandleContextMenuClose);
				contextMenu.AddParButton("Set Command", HandleContextMenu, cmSetCommandString);
				contextMenu.AddParButton("Set Image", HandleContextMenu, cmSetImageName);
				contextMenu.AddParButton("Set Caption", HandleContextMenu, cmSetCaption);
				contextMenu.Popup(bounds.l + x, bounds.t + y)
			END
		END PointerDown;

		PROCEDURE PointerMove*(x,y:SIZE; keys:SET);
		VAR dx, dy : SIZE; width, height : SIZE;
		BEGIN
			IF dragging OR resizing THEN
				x := bounds.l + x; y := bounds.t + y; dx := x - lastX; dy := y - lastY;
				lastX := lastX + dx; lastY := lastY + dy;
				IF (dx # 0) OR (dy # 0) THEN
					IF dragging THEN
						manager.SetWindowPos(SELF, bounds.l + dx, bounds.t + dy);
					ELSE
						width := GetWidth();
						height := GetHeight();
						width := MAX(10, width + dx);
						height := MAX(10, height + dy);
						manager.SetWindowSize(SELF, width, height);
					END;
				END;
			END;
		END PointerMove;

		PROCEDURE PointerUp*(x, y:SIZE; keys:SET);
		BEGIN
			dragging := FALSE;
			IF (keys # {0,2}) THEN
				IF resizing THEN
					resizing := FALSE;
					Resized(GetWidth(), GetHeight());
				END;
			END;
		END PointerUp;

		PROCEDURE ExecuteCommand;
		VAR cmdString : Strings.String; msg : ARRAY 128 OF CHAR; res : INTEGER;
		BEGIN
			cmdString := iconComponent.commandString.Get();
			IF (cmdString # NIL) THEN
				Commands.Call(cmdString^, {}, res, msg);
			END;
		END ExecuteCommand;

		PROCEDURE HandleContextMenu(sender, data : ANY);
		VAR string : ARRAY 256 OF CHAR; mode, res : SIGNED32;
		BEGIN
			IF (data # NIL) & (data IS ContextMenuPar) THEN
				mode := data(ContextMenuPar).mode;
				IF (mode = CmSetCommandString) THEN
					res := WMDialogs.QueryString("Enter command string", string);
					IF (res = WMDialogs.ResOk) THEN
						iconComponent.commandString.Set(Strings.NewString(string));
					END;
				ELSIF (mode = CmSetImageName) THEN
					res := WMDialogs.QueryString("Enter image name", string);
					IF (res = WMDialogs.ResOk) THEN
						iconComponent.imageName.Set(Strings.NewString(string));
					END;
				ELSIF (mode = CmSetCaption) THEN
					res := WMDialogs.QueryString("Enter caption", string);
					IF (res = WMDialogs.ResOk) THEN
						iconComponent.caption.Set(Strings.NewString(string));
					END;
				END;
			END;
		END HandleContextMenu;

		PROCEDURE HandleContextMenuClose(sender, data : ANY);
		BEGIN
			Close;
		END HandleContextMenuClose;

		PROCEDURE Close*;
		BEGIN
			IF (contextMenu # NIL) THEN contextMenu.Close; END;
			Close^;
			DecCount;
		END Close;

		PROCEDURE Handle*(VAR x: WMMessages.Message);
		VAR configuration : WMRestorable.XmlElement;
		BEGIN
			IF (x.msgType = WMMessages.MsgExt) & (x.ext # NIL) THEN
				IF (x.ext IS KillerMsg) THEN Close
				ELSIF (x.ext IS WMRestorable.Storage) THEN
					NEW(configuration); configuration.SetName("Configuration");
					WMRestorable.StoreStringPtr(configuration, "commandString", iconComponent.commandString.Get());
					WMRestorable.StoreStringPtr(configuration, "imageName", iconComponent.imageName.Get());
					WMRestorable.StoreStringPtr(configuration, "caption", iconComponent.caption.Get());
					WMRestorable.StoreLongint(configuration, "color", iconComponent.color.Get());
					WMRestorable.StoreBoolean(configuration, "stayOnTop", WMWindowManager.FlagStayOnTop IN flags);
					WMRestorable.StoreBoolean(configuration, "navigation", WMWindowManager.FlagNavigation IN flags);
					x.ext(WMRestorable.Storage).Add("WMDesktopIcons", "WMDesktopIcons.Restore", SELF, configuration)
				ELSE Handle^(x)
				END
			ELSE Handle^(x)
			END
		END Handle;

	END IconWindow;

TYPE

	IconComponent* = OBJECT(WMComponents.VisualComponent)
	VAR
		commandString- : WMProperties.StringProperty;
		imageName- : WMProperties.StringProperty;
		caption- : WMProperties.StringProperty;
		color- : WMProperties.Int32Property;
		border- : WMProperties.Int32Property;

		image : WMGraphics.Image;
		hover : BOOLEAN;
		borderI : SIGNED32;

		PROCEDURE & Init*;
		BEGIN
			Init^;
			SetNameAsString(StrIconComponent);
			NEW(commandString, prototypeCommandString, NIL, NIL); properties.Add(commandString);
			NEW(imageName, prototypeImageName, NIL, NIL); properties.Add(imageName);
			NEW(color, prototypeColor, NIL, NIL); properties.Add(color);
			NEW(caption, prototypeCaption, NIL, NIL); properties.Add(caption);
			NEW(border, prototypeBorder, NIL, NIL); properties.Add(border);
			image := NIL; hover := FALSE;
			borderI := 0;
		END Init;

		PROCEDURE DrawBackground*(canvas : WMGraphics.Canvas);
		VAR captionStr : Strings.String; rect : WMRectangles.Rectangle;
		BEGIN
			DrawBackground^(canvas);
			IF hover THEN
				rect := GetClientRect();
				canvas.Fill(rect, SHORT(06060C0C0H), WMGraphics.ModeSrcOverDst);
				WMGraphicUtilities.DrawRect(canvas, rect, SHORT(06060C0C0H), WMGraphics.ModeSrcOverDst);
			END;
			canvas.SetColor(color.Get());
			IF image # NIL THEN
				canvas.DrawImage(borderI, borderI, image, WMGraphics.ModeSrcOverDst);
			ELSE
				WMGraphicUtilities.DrawRect(canvas, GetClientRect(), color.Get(), WMGraphics.ModeSrcOverDst);
			END;
			captionStr := caption.Get();
			IF (captionStr # NIL) THEN
				WMGraphics.DrawStringInRect(canvas, GetClientRect(), FALSE, WMGraphics.AlignCenter, WMGraphics.AlignCenter, captionStr^)
			END;
		END DrawBackground;

		PROCEDURE PointerMove*(x, y : SIZE; keys : SET);
		BEGIN
			PointerMove^(x, y, keys);
			IF ~hover THEN hover := TRUE; Invalidate; END;
		END PointerMove;

		PROCEDURE PointerLeave*;
		BEGIN
			PointerLeave^;
			IF hover THEN hover := FALSE; Invalidate; END;
		END PointerLeave;

		PROCEDURE PropertyChanged*(sender, property: ANY);
		BEGIN
			IF (property = imageName) OR (property = border) THEN
				RecacheProperties;
			ELSIF (property = color) OR (property = caption) THEN
				Invalidate;
			ELSIF (property = bounds) THEN
				PropertyChanged^(sender, property);
				RecacheProperties;
			ELSE
				PropertyChanged^(sender, property);
			END
		END PropertyChanged;

		PROCEDURE RecacheProperties*;
		VAR
			string : Strings.String; resizedImage : WMGraphics.Image;
			imageWidth, imageHeight : SIZE;
		BEGIN
			string := imageName.Get();
			IF (string # NIL) THEN
				image := WMGraphics.LoadImage(string^, TRUE);
				IF (bounds.GetWidth() - 2*border.Get() > 10) & (bounds.GetHeight() - 2*border.Get() > 10) THEN
					imageWidth := bounds.GetWidth() - 2*border.Get();
					imageHeight := bounds.GetHeight() - 2*border.Get();
					borderI := border.Get();
				ELSE
					imageWidth := bounds.GetWidth();
					imageHeight := bounds.GetHeight();
					borderI := 0;
				END;
				IF (image # NIL) & ((image.width # imageWidth) OR (image.height # imageHeight)) THEN
					NEW(resizedImage);
					Raster.Create(resizedImage, imageWidth, imageHeight, Raster.BGRA8888);
					WMRasterScale.Scale(
						image, WMRectangles.MakeRect(0, 0, image.width, image.height),
						resizedImage, WMRectangles.MakeRect(0, 0, resizedImage.width, resizedImage.height),
							WMRectangles.MakeRect(0, 0, resizedImage.width, resizedImage.height),
							WMRasterScale.ModeCopy, WMRasterScale.ScaleBilinear);
					image := resizedImage;
				END;
			ELSE
				image := NIL;
			END;
			Invalidate;
		END RecacheProperties;

	END IconComponent;

VAR
	nofWindows : SIGNED32;

	prototypeCommandString, prototypeImageName, prototypeCaption : WMProperties.StringProperty;
	prototypeColor, prototypeBorder : WMProperties.Int32Property;

	cmSetImageName, cmSetCommandString, cmSetCaption : ContextMenuPar;

	StrIconComponent, StrWindowTitle : Strings.String;

PROCEDURE Open*(context : Commands.Context);
VAR options : Options.Options; window: IconWindow; flags : SET;
BEGIN
	NEW(options);
	options.Add("n", "navigation", Options.Flag);
	options.Add("s", "stayOnTop", Options.Flag);
	IF options.Parse(context.arg, context.error) THEN
		flags := {WMWindowManager.FlagHidden};
		IF options.GetFlag("navigation") THEN INCL(flags, WMWindowManager.FlagNavigation); END;
		IF options.GetFlag("stayOnTop") THEN INCL(flags, WMWindowManager.FlagStayOnTop); END;
		NEW(window, NIL, flags);
	END;
END Open;

PROCEDURE Restore*(context : WMRestorable.Context);
VAR icon : IconWindow;
BEGIN
	NEW(icon, context, {});
END Restore;

PROCEDURE IncCount;
BEGIN {EXCLUSIVE}
	INC(nofWindows)
END IncCount;

PROCEDURE DecCount;
BEGIN {EXCLUSIVE}
	DEC(nofWindows)
END DecCount;

PROCEDURE Cleanup;
VAR die : KillerMsg;
	 msg : WMMessages.Message;
	 m : WMWindowManager.WindowManager;
BEGIN {EXCLUSIVE}
	NEW(die);
	msg.ext := die;
	msg.msgType := WMMessages.MsgExt;
	m := WMWindowManager.GetDefaultManager();
	m.Broadcast(msg);
	AWAIT(nofWindows = 0);
END Cleanup;

BEGIN
	StrIconComponent := Strings.NewString("IconComponent");
	StrWindowTitle := Strings.NewString("DesktopIcon");
	NEW(cmSetCommandString, CmSetCommandString);
	NEW(cmSetImageName, CmSetImageName);
	NEW(cmSetCaption, CmSetCaption);
	Modules.InstallTermHandler(Cleanup);
	NEW(prototypeColor, NIL, WMStandardComponents.NewString("color"),
		WMStandardComponents.NewString("toggle icon border color"));
	prototypeColor.Set(WMGraphics.White);
	NEW(prototypeCommandString, NIL, WMStandardComponents.NewString("commandString"),
		WMStandardComponents.NewString("command to be executed when double-clicking the icon"));
	NEW(prototypeImageName, NIL, WMStandardComponents.NewString("imageName"),
		WMStandardComponents.NewString("name of icon image"));
	NEW(prototypeCaption, NIL, WMStandardComponents.NewString("caption"),
		WMStandardComponents.NewString("caption of the icon"));
	NEW(prototypeBorder, NIL, WMStandardComponents.NewString("border"),
		WMStandardComponents.NewString("border"));
	prototypeBorder.Set(5);
END WMDesktopIcons.

System.Free WMDesktopIcons~

WMDesktopIcons.Open -n ~
