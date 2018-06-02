MODULE WMJoysticks; (** AUTHOR "staubesv"; PURPOSE "Joystick control application"; *)
(**
 * Usage:
 *
 *	WMJoysticks.Open [joystickname] ~ opens a viewer for the specified joystick
 *	SystemTools.Free WMJoysticks ~ unloads this module
 *
 * History:
 *
 *	28.11.2006	First release (staubesv)
 *)

IMPORT
	Modules, Commands, Plugins, Joysticks, Strings,
	WMWindowManager, WMMessages, WMComponents, WMStandardComponents,
	WMGraphics, WMRectangles, WMProperties, WMDialogs, XML;

CONST
	DefaultHeight = 480;

	AxisWidth = 80;

TYPE
	KillerMsg = OBJECT
	END KillerMsg;

TYPE

	AxisComponent* = OBJECT(WMComponents.VisualComponent)
	VAR
		(* Axis values *)
		min-, max-, center-, cur-: WMProperties.Int32Property;
		showValues- : WMProperties.BooleanProperty; (* Default: TRUE *)

		name- : WMProperties.StringProperty;
		showName- : WMProperties.BooleanProperty;

		color-: WMProperties.ColorProperty;
		borderColor-: WMProperties.ColorProperty;
		textColor- : WMProperties.ColorProperty;
		vertical- : WMProperties.BooleanProperty;

		showDeadzone- : WMProperties.BooleanProperty;

		PROCEDURE &Init*;
		BEGIN
			Init^;
			SetNameAsString(StrAxisComponent);
			takesFocus.Set(FALSE);
			NEW(color, PrototypeAcColor, NIL, NIL); properties.Add(color);
			NEW(borderColor, PrototypeAcBorderColor, NIL, NIL); properties.Add(borderColor);
			NEW(min, PrototypeAcMin, NIL, NIL); properties.Add(min);
			NEW(max, PrototypeAcMax, NIL, NIL); properties.Add(max);
			NEW(center, PrototypeAcCenter, NIL, NIL); properties.Add(center);
			NEW(cur, PrototypeAcCur, NIL, NIL); properties.Add(cur);
			NEW(showValues, PrototypeAcShowValues, NIL, NIL); properties.Add(showValues);
			NEW(vertical, PrototypeAcVertical, NIL, NIL); properties.Add(vertical);
			NEW(textColor, PrototypeAcTextColor, NIL, NIL); properties.Add(textColor);
			NEW(name, PrototypeAcName, NIL, NIL); properties.Add(name);
			NEW(showName, PrototypeAcShowName, NIL, NIL); properties.Add(showName);
			NEW(showDeadzone, PrototypeAcShowDeadzone, NIL, NIL); properties.Add(showDeadzone);
			SetNameAsString(Strings.NewString("Axis Viewer"));
		END Init;

		PROCEDURE PropertyChanged*(sender, property : ANY);
		BEGIN
			IF (property = min) OR (property = max) THEN
				cur.SetBounds(min.Get(), max.Get());
				Invalidate;
			ELSIF (property = cur) OR (property = color) OR (property = borderColor) OR (property = textColor) OR
				 	(property = showValues) OR (property = vertical) OR (property = name) OR (property = showName)THEN
				Invalidate;
			ELSE PropertyChanged^(sender, property)
			END;
		END PropertyChanged;

		PROCEDURE DrawBackground*(canvas: WMGraphics.Canvas);
		VAR
			rect: WMRectangles.Rectangle;
			pt: ARRAY 4 OF WMGraphics.Point2d;
			string : ARRAY 32 OF CHAR;
			temp : Strings.String;
			min, max, cur, center : LONGINT;
			centerPixel, curPixel : LONGINT;
		BEGIN
			DrawBackground^(canvas);

			min := SELF.min.Get();
			max := SELF.max.Get();
			cur := SELF.cur.Get();
			center := SELF.center.Get();

			IF vertical.Get() THEN
				centerPixel := ENTIER(bounds.GetHeight() / 2);
				curPixel := ENTIER(ABS(cur) / (max - min) * bounds.GetHeight());
			ELSE
				centerPixel := ENTIER(bounds.GetWidth() / 2);
				curPixel := ENTIER(ABS(cur) / (max - min) * bounds.GetWidth());
			END;

			IF cur < center THEN
				IF vertical.Get() THEN
					rect := WMRectangles.MakeRect(0, centerPixel, bounds.GetWidth(), centerPixel + curPixel);
				ELSE
					rect := WMRectangles.MakeRect(centerPixel, 0, centerPixel + curPixel, bounds.GetHeight());
				END;
			ELSE
				IF vertical.Get() THEN
					rect := WMRectangles.MakeRect(0, centerPixel - curPixel, bounds.GetWidth(), centerPixel);
				ELSE
					rect := WMRectangles.MakeRect(centerPixel - curPixel, 0, centerPixel, bounds.GetHeight());
				END;
			END;

			canvas.Fill(rect, color.Get(), WMGraphics.ModeCopy);

			pt[0].x := 0; pt[0].y := 0;
			pt[1].x := bounds.GetWidth()-1; pt[1].y := 0;
			pt[2].x := bounds.GetWidth()-1; pt[2].y := bounds.GetHeight()-1;
			pt[3].x := 0; pt[3].y := bounds.GetHeight()-1;
			canvas.PolyLine(pt, 4, TRUE, borderColor.Get(), WMGraphics.ModeCopy);

			IF showValues.Get() THEN
				Strings.IntToStr(cur, string);
				canvas.SetColor(textColor.Get());
				WMGraphics.DrawStringInRect(canvas, GetClientRect(), FALSE, WMGraphics.AlignCenter, WMGraphics.AlignCenter, string)
			END;
			IF showName.Get() THEN
				temp := name.Get();
				IF temp # NIL THEN COPY(temp^, string) ELSE string := "Unknown"; END;
				canvas.SetColor(textColor.Get());

				IF vertical.Get() THEN
					WMGraphics.DrawStringInRect(canvas, GetClientRect(), FALSE, WMGraphics.AlignCenter, WMGraphics.AlignTop, string);
				ELSE
					WMGraphics.DrawStringInRect(canvas, GetClientRect(), FALSE, WMGraphics.AlignLeft, WMGraphics.AlignCenter, string);
				END;
			END;
			IF showDeadzone.Get() THEN

			END;
		END DrawBackground;

	END AxisComponent;

TYPE

	JoystickPanel = OBJECT (WMComponents.VisualComponent)
	VAR
		joystick : Joysticks.Joystick;

		buttons : POINTER TO ARRAY OF WMStandardComponents.Label;
		hats : POINTER TO ARRAY OF ARRAY 4 OF WMStandardComponents.Label;
		axis : ARRAY Joysticks.MaxNbrOfAxis OF AxisComponent;

		connectedLabel : WMStandardComponents.Label;

		calibrationStartStopBtn :  WMStandardComponents.Button;
		calibrationLabel : WMStandardComponents.Label;

		PROCEDURE HandleJoystickMessage(VAR msg : Joysticks.JoystickMessage);
		VAR dataMsg : Joysticks.JoystickDataMessage; i, j : LONGINT;
		BEGIN
			IF msg IS Joysticks.JoystickDataMessage THEN
				dataMsg := msg(Joysticks.JoystickDataMessage);
				FOR i := 0 TO LEN(buttons) - 1 DO
					IF i IN dataMsg.buttons THEN
						buttons[i].fillColor.Set(WMGraphics.Green);
					ELSE
						buttons[i].fillColor.Set(WMGraphics.Red);
					END;
				END;
				FOR i := 0 TO LEN(axis) - 1 DO
					IF i IN joystick.implementedAxis THEN
						axis[i].cur.Set(dataMsg.axis[i]);
					END;
				END;
				IF hats # NIL THEN
					FOR i := 0 TO LEN(hats) - 1 DO
						FOR j := 0 TO 3 DO
							IF j IN dataMsg.coolieHat[i] THEN
								hats[i][j].fillColor.Set(WMGraphics.Green);
							ELSE
								hats[i][j].fillColor.Set(WMGraphics.Red);
							END;
						END;
					END;
				END;
			ELSIF msg IS Joysticks.JoystickDisconnectedMessage THEN
				connectedLabel.fillColor.Set(WMGraphics.Red);
				connectedLabel.caption.SetAOC("Disconnected");
			END;
		END HandleJoystickMessage;

		PROCEDURE HandleCalibrationButton(sender, data : ANY);
		VAR res : WORD; message : ARRAY 128 OF CHAR;
		BEGIN
			IF joystick.calibrationMode THEN
				joystick.StopCalibration(message, res);
				IF res # Joysticks.Ok THEN
					WMDialogs.Error("Joystick Calibration", message);
				ELSE
					calibrationStartStopBtn.caption.SetAOC("Start Calibration");
					calibrationLabel.fillColor.Set(WMGraphics.Red);
				END;
			ELSE
				joystick.StartCalibration;
				calibrationStartStopBtn.caption.SetAOC("Stop Calibration");
				calibrationLabel.fillColor.Set(WMGraphics.Green);
			END;
		END HandleCalibrationButton;

		PROCEDURE InitNameLabel(CONST name, description : ARRAY OF CHAR);
		VAR caption : ARRAY 128 OF CHAR; label : WMStandardComponents.Label; panel : WMStandardComponents.Panel;
		BEGIN
			NEW(panel);
			panel.bounds.SetHeight(30);
			panel.alignment.Set(WMComponents.AlignTop);
			panel.bearing.Set(WMRectangles.MakeRect(5, 5, 5, 5));

			NEW(label);
			label.bounds.SetWidth(200);
			label.alignment.Set(WMComponents.AlignLeft);
			caption := "Joystick: ";
			Strings.Append(caption, name);
			Strings.Append(caption, " ("); Strings.Append(caption, description); Strings.Append(caption, ")");
			label.caption.SetAOC(caption);
			panel.AddContent(label);

			NEW(connectedLabel);
			connectedLabel.alignment.Set(WMComponents.AlignClient);
			connectedLabel.alignH.Set(WMGraphics.AlignCenter);
			connectedLabel.alignV.Set(WMGraphics.AlignCenter);
			IF joystick.connected THEN
				connectedLabel.fillColor.Set(WMGraphics.Green);
				connectedLabel.caption.SetAOC("Connected");
			ELSE
				connectedLabel.fillColor.Set(WMGraphics.Red);
				connectedLabel.caption.SetAOC("Disconnected");
			END;
			panel.AddContent(connectedLabel);

			AddContent(panel);
		END InitNameLabel;

		PROCEDURE InitButtonsPanel(nbrOfButtons : LONGINT);
		VAR
			panel : WMStandardComponents.Panel; label : WMStandardComponents.Label;
			number : ARRAY 32 OF CHAR; i : LONGINT;
		BEGIN
			NEW(panel);
			panel.bounds.SetHeight(26);
			panel.alignment.Set(WMComponents.AlignTop);
			panel.bearing.Set(WMRectangles.MakeRect(5, 5, 5, 5));

			NEW(label);
			label.alignment.Set(WMComponents.AlignLeft); label.bounds.SetWidth(70);
			label.caption.SetAOC("Buttons:");
			panel.AddContent(label);

			NEW(buttons, nbrOfButtons);
			FOR i := 0 TO nbrOfButtons-1 DO
				NEW(buttons[i]);
				buttons[i].bounds.SetExtents(20,20);
				buttons[i].alignment.Set(WMComponents.AlignLeft);
				buttons[i].alignH.Set(WMGraphics.AlignCenter);
				buttons[i].alignV.Set(WMGraphics.AlignCenter);
				buttons[i].fillColor.Set(WMGraphics.Red);
				buttons[i].bearing.Set(WMRectangles.MakeRect(2, 2, 2, 2));
				Strings.IntToStr(i + 1, number);
				buttons[i].caption.SetAOC(number);
				panel.AddContent(buttons[i]);
			END;
			AddContent(panel);
		END InitButtonsPanel;

		PROCEDURE InitCoolieHatPanels(nbrOfCoolieHats : LONGINT);
		VAR
			panel : WMStandardComponents.Panel; label : WMStandardComponents.Label;
			caption : ARRAY 16 OF CHAR;
			i, j : LONGINT;
		BEGIN
			IF nbrOfCoolieHats <= 0 THEN RETURN; END;
			NEW(hats, nbrOfCoolieHats);
			FOR i := 0 TO nbrOfCoolieHats - 1 DO
				NEW(panel);
				panel.bounds.SetHeight(26);
				panel.alignment.Set(WMComponents.AlignTop);
				panel.bearing.Set(WMRectangles.MakeRect(5, 5, 5, 5));

				NEW(label);
				label.alignment.Set(WMComponents.AlignLeft); label.bounds.SetWidth(70);
				label.caption.SetAOC("Coolie Hat:");
				panel.AddContent(label);

				FOR j := 0 TO 3 DO
					NEW(hats[i][j]);
					hats[i][j].bounds.SetExtents(40, 20);
					hats[i][j].alignment.Set(WMComponents.AlignLeft);
					hats[i][j].alignH.Set(WMGraphics.AlignCenter);
					hats[i][j].alignV.Set(WMGraphics.AlignCenter);
					hats[i][j].fillColor.Set(WMGraphics.Red);
					hats[i][j].bearing.Set(WMRectangles.MakeRect(2, 2, 2, 2));
					CASE j OF
						|0: caption := "UP";
						|1: caption := "LEFT";
						|2: caption := "DOWN";
						|3: caption := "RIGHT";
					ELSE
						caption := "Invalid";
					END;
					hats[i][j].caption.SetAOC(caption);
					panel.AddContent(hats[i][j]);
				END;
				AddContent(panel);
			END;
		END InitCoolieHatPanels;

		PROCEDURE InitAxisPanel(nbrOfAxis : LONGINT; implementedAxis : SET);
		VAR panel : WMStandardComponents.Panel; i : LONGINT; name : ARRAY 16 OF CHAR;
		BEGIN
			NEW(panel);
			panel.alignment.Set(WMComponents.AlignClient);
			FOR i := 0 TO Joysticks.MaxNbrOfAxis - 1 DO
				IF i IN implementedAxis THEN
					Joysticks.GetAxisName(i, name);
					NEW(axis[i]);
					axis[i].bounds.SetExtents(AxisWidth - 10, 100);
					axis[i].alignment.Set(WMComponents.AlignLeft);
					axis[i].bearing.Set(WMRectangles.MakeRect(5, 5, 5, 5));
					axis[i].min.Set(Joysticks.MinAxisValue); axis[i].max.Set(Joysticks.MaxAxisValue); axis[i].center.Set(0);
					axis[i].vertical.Set(TRUE);
					axis[i].showValues.Set(TRUE);
					axis[i].color.Set(WMGraphics.Blue);
					axis[i].borderColor.Set(WMGraphics.Black);
					axis[i].textColor.Set(WMGraphics.Black);
					axis[i].name.SetAOC(name);
					panel.AddContent(axis[i]);
				END;
			END;
			AddContent(panel);
		END InitAxisPanel;

		PROCEDURE InitToolbar;
		VAR panel : WMStandardComponents.Panel;
		BEGIN
			NEW(panel);
			panel.bounds.SetHeight(30);
			panel.bearing.Set(WMRectangles.MakeRect(5, 5, 5, 5));
			panel.alignment.Set(WMComponents.AlignBottom);
			AddContent(panel);

			NEW(calibrationStartStopBtn);
			calibrationStartStopBtn.alignment.Set(WMComponents.AlignLeft);
			calibrationStartStopBtn.bounds.SetWidth(100);
			calibrationStartStopBtn.onClick.Add(HandleCalibrationButton);
			IF ~joystick.calibrationMode THEN
				calibrationStartStopBtn.caption.SetAOC("Start Calibration");
			ELSE
				calibrationStartStopBtn.caption.SetAOC("Stop Calibration");
			END;
			panel.AddContent(calibrationStartStopBtn);

			NEW(calibrationLabel);
			calibrationLabel.alignment.Set(WMComponents.AlignClient);
			calibrationLabel.alignH.Set(WMGraphics.AlignCenter);
			calibrationLabel.alignV.Set(WMGraphics.AlignCenter);
			IF joystick.calibrationMode THEN calibrationLabel.fillColor.Set(WMGraphics.Green);
			ELSE calibrationLabel.fillColor.Set(WMGraphics.Red);
			END;
			calibrationLabel.caption.SetAOC("Calibration Mode");
			panel.AddContent(calibrationLabel);
		END InitToolbar;

		PROCEDURE Finalize*;
		BEGIN
			Finalize^;
			joystick.Unregister(HandleJoystickMessage);
			joystick := NIL;
		END Finalize;

		PROCEDURE &New*(joystick : Joysticks.Joystick);
		BEGIN
			ASSERT(joystick # NIL);
			Init; (* superclass constructor *)
			SetNameAsString(StrJoystickPanel);
			SELF.joystick := joystick;
			InitNameLabel(joystick.name, joystick.desc);
			InitButtonsPanel(joystick.nbrOfButtons);
			InitCoolieHatPanels(joystick.nbrOfCoolieHats);
			InitToolbar;
			InitAxisPanel(joystick.nbrOfAxis, joystick.implementedAxis);
			joystick.Register(HandleJoystickMessage);
			fillColor.Set(WMGraphics.White);
		END New;

	END JoystickPanel;

TYPE

	Window = OBJECT (WMComponents.FormWindow)

		PROCEDURE &New*(joystick : Joysticks.Joystick);
		VAR joystickPanel : JoystickPanel; width : LONGINT;
		BEGIN
			ASSERT(joystick # NIL);
			IncCount;
			IF joystick.nbrOfAxis > 0 THEN
				width := joystick.nbrOfAxis * AxisWidth;
			ELSE
				width := 100;
			END;
			NEW(joystickPanel, joystick);
			joystickPanel.bounds.SetExtents(width, DefaultHeight);
			joystickPanel.alignment.Set(WMComponents.AlignClient);

			Init(width, DefaultHeight, FALSE);
			SetContent(joystickPanel);
			SetTitle(Strings.NewString("Joystick Tool"));
			SetIcon(WMGraphics.LoadImage("WMIcons.tar://WMJoysticks.png", TRUE));
			WMWindowManager.DefaultAddWindow(SELF);
		END New;

		PROCEDURE Close*;
		BEGIN
			Close^;
			DecCount;
		END Close;

		PROCEDURE Handle*(VAR x: WMMessages.Message);
		BEGIN
			IF (x.msgType = WMMessages.MsgExt) & (x.ext # NIL) THEN
				IF (x.ext IS KillerMsg) THEN Close
				ELSE Handle^(x)
				END
			ELSE Handle^(x)
			END
		END Handle;

	END Window;

VAR
	nofWindows : LONGINT;

	VAR

	(** ProgressBar property prototypes *)
	PrototypeAcMin*, PrototypeAcMax*, PrototypeAcCenter*, PrototypeAcCur* : WMProperties.Int32Property;
	PrototypeAcColor*, PrototypeAcBorderColor* : WMProperties.ColorProperty;
	PrototypeAcShowValues* : WMProperties.BooleanProperty;
	PrototypeAcVertical* : WMProperties.BooleanProperty;
	PrototypeAcTextColor* : WMProperties.ColorProperty;
	PrototypeAcName* : WMProperties.StringProperty;
	PrototypeAcShowName* : WMProperties.BooleanProperty;
	PrototypeAcShowDeadzone* : WMProperties.BooleanProperty;

	 (* temporary prototype-prototypes *)
	 ColorPrototype : WMProperties.ColorProperty;
	 BooleanPrototype : WMProperties.BooleanProperty;
	 StringPrototype : WMProperties.StringProperty;
	 Int32Prototype : WMProperties.Int32Property;

	 StrAxisComponent, StrJoystickPanel : Strings.String;

PROCEDURE GenAxisViewer*() : XML.Element;
VAR ac : AxisComponent;
BEGIN NEW(ac); RETURN ac
END GenAxisViewer;

PROCEDURE Open*(context : Commands.Context); (** [joystickname] ~ *)
VAR
	joystickName : ARRAY 128 OF CHAR;
	plugin : Plugins.Plugin; window : Window;
BEGIN
	context.arg.SkipWhitespace; context.arg.String(joystickName);
	plugin := Joysticks.registry.Get(joystickName);
	IF plugin # NIL THEN
		NEW(window, plugin (Joysticks.Joystick));
	ELSE
		context.error.String("WMJoysticks: Joystick "); context.error.String(joystickName); context.error.String(" not found.");
		context.error.Ln;
	END;
END Open;

PROCEDURE InitStrings;
BEGIN
	StrAxisComponent := Strings.NewString("AxisComponent");
	StrJoystickPanel := Strings.NewString("JoystickPanel");
END InitStrings;

PROCEDURE InitPrototypes;
VAR plAxisViewer : WMProperties.PropertyList;
BEGIN
	(* ProgressBar properties *)
	NEW(plAxisViewer); WMComponents.propertyListList.Add("AxisComponent", plAxisViewer);
	(* colors *)
	NEW(ColorPrototype, NIL, Strings.NewString("BorderColor"), Strings.NewString("Axis Component Border Color")); ColorPrototype.Set(WMGraphics.White);
	NEW(PrototypeAcBorderColor, ColorPrototype, NIL, NIL); plAxisViewer.Add(PrototypeAcBorderColor);
	NEW(ColorPrototype, NIL, Strings.NewString("Color"), Strings.NewString("Axis Component Color")); ColorPrototype.Set(WMGraphics.Blue);
	NEW(PrototypeAcColor, ColorPrototype, NIL, NIL); plAxisViewer.Add(PrototypeAcColor);
	NEW(ColorPrototype, NIL, Strings.NewString("TextColor"), Strings.NewString("Axis Component Text Color")); ColorPrototype.Set(WMGraphics.White);
	NEW(PrototypeAcTextColor, ColorPrototype, NIL, NIL); plAxisViewer.Add(PrototypeAcTextColor);
	(* position *)
	NEW(Int32Prototype, NIL, Strings.NewString("Minimum"), Strings.NewString("Axis Minimum Position")); Int32Prototype.Set(0);
	NEW(PrototypeAcMin, Int32Prototype, NIL, NIL); plAxisViewer.Add(PrototypeAcMin);
	NEW(Int32Prototype, NIL, Strings.NewString("Maximum"), Strings.NewString("Axis Maximum Position")); Int32Prototype.Set(0);
	NEW(PrototypeAcMax, Int32Prototype, NIL, NIL); plAxisViewer.Add(PrototypeAcMax);
	NEW(Int32Prototype, NIL, Strings.NewString("Center"), Strings.NewString("Axis Center Position")); Int32Prototype.Set(0);
	NEW(PrototypeAcCenter, Int32Prototype, NIL, NIL); plAxisViewer.Add(PrototypeAcCenter);
	NEW(Int32Prototype, NIL, Strings.NewString("Current"), Strings.NewString("Axis Current Position")); Int32Prototype.Set(0);
	NEW(PrototypeAcCur, Int32Prototype, NIL, NIL); plAxisViewer.Add(PrototypeAcCur);
	(* other *)
	NEW(BooleanPrototype, NIL, Strings.NewString("ShowValues"), Strings.NewString("Display raw axis value")); BooleanPrototype.Set(FALSE);
	NEW(PrototypeAcShowValues, BooleanPrototype, NIL, NIL); plAxisViewer.Add(PrototypeAcShowValues);
	NEW(BooleanPrototype, NIL, Strings.NewString("Vertical"), Strings.NewString("Vertical")); BooleanPrototype.Set(TRUE);
	NEW(PrototypeAcVertical, BooleanPrototype, NIL, NIL); plAxisViewer.Add(PrototypeAcVertical);
	NEW(StringPrototype, NIL, Strings.NewString("Name"), Strings.NewString("Name of axis")); StringPrototype.SetAOC("No name");
	NEW(PrototypeAcName, StringPrototype, NIL, NIL); plAxisViewer.Add(PrototypeAcName);
	NEW(BooleanPrototype, NIL, Strings.NewString("ShowName"), Strings.NewString("Show name of axis")); BooleanPrototype.Set(TRUE);
	NEW(PrototypeAcShowName, BooleanPrototype, NIL, NIL); plAxisViewer.Add(PrototypeAcShowName);
	NEW(BooleanPrototype, NIL, Strings.NewString("ShowDeadzone"), Strings.NewString("Show deadzone of axis")); BooleanPrototype.Set(TRUE);
	NEW(PrototypeAcShowDeadzone, BooleanPrototype, NIL, NIL); plAxisViewer.Add(PrototypeAcShowDeadzone);
END InitPrototypes;

PROCEDURE IncCount;
BEGIN {EXCLUSIVE}
	INC(nofWindows);
END IncCount;

PROCEDURE DecCount;
BEGIN {EXCLUSIVE}
	DEC(nofWindows);
END DecCount;

PROCEDURE Cleanup;
VAR die : KillerMsg;
	 msg : WMMessages.Message;
	 m : WMWindowManager.WindowManager;
BEGIN {EXCLUSIVE}
	NEW(die); msg.ext := die; msg.msgType := WMMessages.MsgExt;
	m := WMWindowManager.GetDefaultManager();
	m.Broadcast(msg);
	AWAIT(nofWindows = 0);
END Cleanup;

BEGIN
	Modules.InstallTermHandler(Cleanup);
	InitStrings;
	InitPrototypes;
END WMJoysticks.

Joysticks.Show ~

JoysticksTest.CreateJoystick ~ 	SystemTools.Free JoysticksTest ~

WMJoysticks.Open~

WMJoysticks.Open JOYSTICK2 ~

SystemTools.Free WMJoysticks ~

SystemTools.Free WMJoysticks JoysticksTest Joysticks ~
