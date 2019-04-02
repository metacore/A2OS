MODULE WMCalendar; (** AUTHOR "staubesv"; PURPOSE "Calendar component and applicatoin"; *)

IMPORT
	Dates, Strings, Modules, Kernel, XML,
	WMRectangles, Raster, WMRasterScale, WMGraphics, WMGraphicUtilities, WMMessages, WMWindowManager, WMRestorable,
	WMEvents, WMProperties, WMComponents, WMStandardComponents, WMPopups;

CONST
	Monday* = 1;
	Tuesday* = 2;
	Wednesday* = 3;
	Thursday* = 4;
	Friday* = 5;
	Saturday* = 6;
	Sunday* = 7;

	January* = 1;
	February* = 2;
	March* = 3;
	April* = 4;
	May* = 5;
	June* = 6;
	July* = 7;
	August* = 8;
	September* = 9;
	October* = 10;
	November* = 11;
	December* = 12;

	MinCellWidth = 5;
	MinCellHeight = 5;

	NofColumns = 7;
	NofRows = 7;

	WindowWidth = 200;
	WindowHeight = 200;

TYPE

	SelectionWrapper* = OBJECT
	VAR
		year-, month-, day-,
		week-, weekDay- : LONGINT;

		PROCEDURE &Init(year, month, day, week, weekDay : LONGINT);
		BEGIN
			SELF.year := year; SELF.month := month; SELF.day := day;
			SELF.week := week; SELF.weekDay := weekDay;
		END Init;

	END SelectionWrapper;

TYPE

	Calendar* = OBJECT(WMComponents.VisualComponent)
	VAR
		onSelect- : WMEvents.EventSource;
		allowSelection- : WMProperties.BooleanProperty;

		year-, month- : WMProperties.Int32Property;
		firstDayOfWeek- : WMProperties.Int32Property;

		clText-, clTextTitle-, clTextWeekend-, clTextOtherMonths-,
		clTextCurrentDay-, clMouseOver- : WMProperties.ColorProperty;

		currentDayImageName- : WMProperties.StringProperty;
		currentDayImage : WMGraphics.Image;

		backgroundImageName- : WMProperties.StringProperty;
		backgroundImage : WMGraphics.Image;

		mouseOverColumn, mouseOverRow : LONGINT;
		selected : BOOLEAN;

		currentDate : Dates.DateTime;

		date0 : Dates.DateTime; (* date of position (0,1) *)
		cellWidth, cellHeight : LONGINT;
		fixWidth, fixHeight : LONGINT; (* additional width and height of last column respectively row (division remainder) *)

		state : LONGINT;
		timer : Kernel.Timer;

		PROCEDURE &Init*;
		BEGIN
			Init^;
			SetNameAsString(StrCalendar);
			NEW(onSelect, SELF, StrOnSelect, StrOnSelectInfo, NIL); events.Add(onSelect);
			NEW(allowSelection, PrototypeAllowSelection, NIL, NIL); properties.Add(allowSelection);
			NEW(year, PrototypeYear, NIL, NIL); properties.Add(year);
			NEW(month, PrototypeMonth, NIL, NIL); properties.Add(month);
			NEW(firstDayOfWeek, PrototypeFirstDayOfWeek, NIL, NIL); properties.Add(firstDayOfWeek);
			NEW(clText, PrototypeClText, NIL, NIL); properties.Add(clText);
			NEW(clTextTitle, PrototypeClTextTitle, NIL, NIL); properties.Add(clTextTitle);
			NEW(clTextWeekend, PrototypeClTextWeekend, NIL, NIL); properties.Add(clTextWeekend);
			NEW(clTextOtherMonths, PrototypeClTextOtherMonths, NIL, NIL); properties.Add(clTextOtherMonths);
			NEW(clTextCurrentDay, PrototypeClTextCurrentDay, NIL, NIL); properties.Add(clTextCurrentDay);
			NEW(clMouseOver, PrototypeClMouseOver, NIL, NIL); properties.Add(clMouseOver);
			NEW(currentDayImageName, PrototypeCurrentDayImageName, NIL, NIL); properties.Add(currentDayImageName);
			NEW(backgroundImageName, PrototypeBackgroundImageName, NIL, NIL); properties.Add(backgroundImageName);
			mouseOverColumn := -1; mouseOverRow := -1;
			selected := FALSE;
		 	currentDate := Dates.Now();
		 	date0 := currentDate; (* to get a valid initial date0 value *)
		 	state := NotInitialized;
		 	NEW(timer);
		END Init;

		PROCEDURE Initialize*;
		BEGIN
			Initialize^;
			BEGIN {EXCLUSIVE} state := Running; END;
		END Initialize;

		PROCEDURE PropertyChanged*(sender, property : ANY);
		BEGIN
			RecacheProperties;
			PropertyChanged^(sender, property);
		END PropertyChanged;

		PROCEDURE RecacheProperties*;
		VAR dt : Dates.DateTime; ignore, weekDay : LONGINT; string : Strings.String;

			PROCEDURE GetResizedImage(name : WMProperties.StringProperty; width, height : LONGINT) : WMGraphics.Image;
			VAR newImage, resizedImage : WMGraphics.Image;
			BEGIN
				newImage := NIL;
				string := name.Get();
				IF (string # NIL) THEN
					newImage := WMGraphics.LoadImage(string^, TRUE);
					IF (newImage # NIL) THEN
						IF (width # newImage.width) OR (height # newImage.height) THEN
							NEW(resizedImage);
							Raster.Create(resizedImage, width, height, Raster.BGRA8888);
							WMRasterScale.Scale(
								newImage, WMRectangles.MakeRect(0, 0, newImage.width, newImage.height),
								resizedImage, WMRectangles.MakeRect(0, 0, resizedImage.width, resizedImage.height),
								WMRectangles.MakeRect(0, 0, resizedImage.width, resizedImage.height),
								WMRasterScale.ModeCopy, WMRasterScale.ScaleBilinear);
							newImage := resizedImage;
						END;
					END;
				END;
				RETURN newImage;
			END GetResizedImage;

		BEGIN
			RecacheProperties^;
			cellWidth := bounds.GetWidth() DIV NofColumns;
			IF (cellWidth < MinCellWidth) THEN
				cellWidth := MinCellWidth;
				fixWidth := 0;
			ELSE
				fixWidth := bounds.GetWidth() MOD NofColumns;
			END;
			cellHeight := bounds.GetHeight() DIV NofRows;
			IF (cellHeight < MinCellHeight) THEN
				cellHeight := MinCellHeight;
				fixHeight := 0;
			ELSE
				fixHeight := bounds.GetHeight() MOD NofRows;
			END;
			dt.year := year.Get(); dt.month := month.Get();
			dt.day := 1; dt.hour := 0; dt.minute := 0; dt.second := 0;
			Dates.WeekDate(dt, ignore, ignore, weekDay);
			Dates.AddDays(dt, firstDayOfWeek.Get() - weekDay);
			date0.day := dt.day; date0.month := dt.month; date0.year := dt.year;

			currentDayImage := GetResizedImage(currentDayImageName, cellWidth, cellHeight);
			backgroundImage := GetResizedImage(backgroundImageName, bounds.GetWidth(), bounds.GetHeight());

			Invalidate;
		END RecacheProperties;

		PROCEDURE NextMonth*;
		BEGIN
			Acquire;
			ChangeMonth(1);
			Release;
		END NextMonth;

		PROCEDURE PreviousMonth*;
		BEGIN
			Acquire;
			ChangeMonth(-1);
			Release;
		END PreviousMonth;

		PROCEDURE ChangeMonth(delta : LONGINT);
		VAR dt : Dates.DateTime;
		BEGIN
			dt.year := year.Get(); dt.month := month.Get(); dt.day := 1;
			dt.hour := 1; dt.minute := 1; dt.day := 1;
			Dates.AddMonths(dt, delta);
			year.Set(dt.year);
			month.Set(dt.month);
		END ChangeMonth;

		PROCEDURE PointerDown*(x, y : LONGINT; keys : SET);
		BEGIN
			PointerDown^(x, y, keys);
			IF (0 IN keys) THEN selected := TRUE; END;
		END PointerDown;

		PROCEDURE PointerUp*(x, y : LONGINT; keys : SET);
		VAR
			selection : SelectionWrapper; dt : Dates.DateTime;
			year, week, weekDay : LONGINT;
		BEGIN
			PointerUp^(x, y, keys);
			IF selected & ~(0 IN keys) & allowSelection.Get() THEN
				selected := FALSE;
			 	IF GetDateXY(x, y, dt) THEN
					Dates.WeekDate(dt, year, week, weekDay);
					NEW(selection, dt.year, dt.month, dt.day, week, weekDay);
					onSelect.Call(selection);
				END;
			END;
		END PointerUp;

		PROCEDURE PointerMove*(x, y : LONGINT; keys : SET);
		VAR column, row : LONGINT;
		BEGIN
			PointerMove^(x, y, keys);
			GetCell(x, y, column, row);
			IF (column # mouseOverColumn) OR (row # mouseOverRow) THEN
				mouseOverColumn := column; mouseOverRow := row;
				Invalidate;
			END;
		END PointerMove;

		PROCEDURE PointerLeave*;
		BEGIN
			PointerLeave^;
			mouseOverColumn := -1; mouseOverRow := -1;
			Invalidate;
	 	END PointerLeave;

	 	PROCEDURE GetDateXY(x, y : LONGINT; VAR dt : Dates.DateTime) : BOOLEAN;
	 	VAR column, row : LONGINT;
	 	BEGIN
	 		GetCell(x, y, column, row);
	 		IF (column # -1) & (row > 0) THEN
	 			dt := date0;
	 			Dates.AddDays(dt, (row - 1) * NofColumns + column);
	 			RETURN TRUE;
	 		ELSE
	 			RETURN FALSE;
	 		END;
	 	END GetDateXY;

	 	PROCEDURE GetCell(x, y : LONGINT; VAR column, row : LONGINT);
	 	BEGIN
	 		column := -1; row := -1;
	 		IF WMRectangles.PointInRect(x, y, GetClientRect()) THEN
	 			column := x DIV cellWidth;
	 			row := y DIV cellHeight;
	 		END;
	 	END GetCell;

		PROCEDURE DrawBackground*(canvas : WMGraphics.Canvas);
		VAR
			rect : WMRectangles.Rectangle;
			dt : Dates.DateTime;
			string : ARRAY 16 OF CHAR;
			column, temp, row : LONGINT; color: WMGraphics.Color;

			PROCEDURE DrawStringInRect(rect : WMRectangles.Rectangle; CONST string : ARRAY OF CHAR);
			BEGIN
				WMGraphics.DrawStringInRect(canvas, rect, FALSE, WMGraphics.AlignCenter, WMGraphics.AlignCenter, string);
			END DrawStringInRect;

		BEGIN
			dt := date0;
			DrawBackground^(canvas);
			IF (backgroundImage # NIL) THEN
				canvas.DrawImage(0, 0, backgroundImage, WMGraphics.ModeSrcOverDst);
			END;
			FOR row := 0 TO NofRows - 1 DO
				FOR column := 0 TO NofColumns - 1 DO
					rect := WMRectangles.MakeRect(column * cellWidth, row * cellHeight, (column + 1) * cellWidth, (row + 1) * cellHeight);
					IF (column = NofColumns - 1) THEN rect.r := rect.r + fixWidth; END;
					IF (row = NofRows - 1) THEN rect.b := rect.b + fixHeight; END;
					IF (row = 0) THEN
						temp := firstDayOfWeek.Get() + column;
						IF (temp DIV 8 >=1) THEN temp := (temp MOD 8) + 1; ELSE temp := (temp MOD 8); END;
						COPY(WeekDay[temp], string);
						color := clTextTitle.Get();
					ELSE
						IF (column = mouseOverColumn) & (row = mouseOverRow) & allowSelection.Get() THEN
							color := clMouseOver.Get();
	 						canvas.Fill(rect, color, WMGraphics.ModeSrcOverDst);
	 						color := color - (color MOD 100H) + 0FFH;
	 						WMGraphicUtilities.DrawRect(canvas, rect, color, WMGraphics.ModeCopy);
	 					END;
						Strings.IntToStr(dt.day, string);
						IF (dt.month = month.Get()) THEN
							IF SameDay(dt, currentDate) THEN
	 							color := clTextCurrentDay.Get();
							ELSE
								color := clText.Get();
							END;
						ELSE
							color := clTextOtherMonths.Get();
						END;
						Dates.AddDays(dt, 1);
					END;
					canvas.SetColor(color);
					DrawStringInRect(rect, string);
				END;
			END;
		END DrawBackground;

		PROCEDURE Finalize*;
		BEGIN
			Finalize^;
			BEGIN {EXCLUSIVE} state := Terminating END;
			timer.Wakeup;
			BEGIN {EXCLUSIVE} AWAIT(state = Terminated); END;
		END Finalize;

		PROCEDURE UpdateCurrentDate;
		VAR currentDate : Dates.DateTime;
		BEGIN
			currentDate := Dates.Now();
			IF ~SameDay(currentDate, SELF.currentDate) THEN
				Acquire;
				SELF.currentDate := currentDate;
				Release;
				Invalidate;
			END;
		END UpdateCurrentDate;

	BEGIN {ACTIVE}
		BEGIN {EXCLUSIVE} AWAIT(state > NotInitialized); END;
		WHILE (state = Running) DO
			UpdateCurrentDate;
			timer.Sleep(5000);
		END;
		BEGIN {EXCLUSIVE} state := Terminated; END;
	END Calendar;

CONST
	NotInitialized = 0;
	Running = 1;
	Terminating = 2;
	Terminated = 3;

TYPE

	CalendarController* = OBJECT(WMComponents.VisualComponent)
	VAR
		calendar : Calendar;

		prevBtn, nextBtn : WMStandardComponents.Button;
		dateLabel : WMStandardComponents.Label;

		state : LONGINT;
		timer : Kernel.Timer;

		PROCEDURE &Init*;
		BEGIN
			Init^;
			SetNameAsString(StrCalendarController);

			calendar := NIL;
			state := NotInitialized;
			NEW(timer);

			NEW(prevBtn); prevBtn.alignment.Set(WMComponents.AlignLeft);
			prevBtn.bounds.SetWidth(15);
			prevBtn.caption.SetAOC("<");
			prevBtn.onClick.Add(ButtonHandler);
			AddContent(prevBtn);

			NEW(nextBtn); nextBtn.alignment.Set(WMComponents.AlignRight);
			nextBtn.bounds.SetWidth(15);
			nextBtn.caption.SetAOC(">");
			nextBtn.onClick.Add(ButtonHandler);
			AddContent(nextBtn);

			NEW(dateLabel); dateLabel.alignment.Set(WMComponents.AlignClient);
			dateLabel.alignV.Set(WMGraphics.AlignCenter);
			dateLabel.alignH.Set(WMGraphics.AlignCenter);
			dateLabel.textColor.Set(WMGraphics.Black);
			AddContent(dateLabel);
		END Init;

		PROCEDURE ButtonHandler(sender, data : ANY);
		BEGIN
			IF (sender = prevBtn) THEN
				calendar.PreviousMonth;
			ELSIF (sender = nextBtn) THEN
				calendar.NextMonth;
			END;
			UpdateDateLabel;
		END ButtonHandler;

		PROCEDURE UpdateDateLabel;
		VAR dt : Dates.DateTime; caption : ARRAY 128 OF CHAR;
		BEGIN
			dt.year := calendar.year.Get();
			dt.month := calendar.month.Get();
			dt.day := 1; dt.hour := 1; dt.minute := 1; dt.second := 1;
			Strings.FormatDateTime("mmmm yyyy", dt, caption);
			dateLabel.caption.SetAOC(caption);
		END UpdateDateLabel;

		PROCEDURE SetCalendar*(calendar : Calendar);
		VAR dt : Dates.DateTime;
		BEGIN {EXCLUSIVE}
			SELF.calendar := calendar;
			dt := Dates.Now();
			calendar.year.Set(dt.year);
			calendar.month.Set(dt.month);
			UpdateDateLabel;
		END SetCalendar;

	END CalendarController;

TYPE

	KillerMsg = OBJECT
	END KillerMsg;

	Window = OBJECT(WMComponents.FormWindow);
	VAR
		calendar : Calendar;
		control : CalendarController;
		colorScheme : LONGINT;
		contextMenu : WMPopups.Popup;
		dragging, resizing : BOOLEAN;
		lastX, lastY : LONGINT;

		PROCEDURE &New*(context : WMRestorable.Context);
		VAR panel : WMStandardComponents.Panel; configuration : WMRestorable.XmlElement;
		BEGIN
			IncCount;
			IF (context # NIL) THEN
				Init(context.r - context.l, context.b - context.t, TRUE);
			ELSE
				Init(WindowWidth, WindowHeight, TRUE);
			END;

			NEW(panel); panel.alignment.Set(WMComponents.AlignClient);

			NEW(control); control.alignment.Set(WMComponents.AlignTop);
			control.bounds.SetHeight(20);
			control.nextBtn.useBgBitmaps.Set(FALSE);
			control.nextBtn.clDefault.Set(0);
			control.nextBtn.effect3D.Set(0);
			control.prevBtn.useBgBitmaps.Set(FALSE);
			control.prevBtn.clDefault.Set(0);
			control.prevBtn.effect3D.Set(0);

			panel.AddContent(control);

			NEW(calendar);
			calendar.alignment.Set(WMComponents.AlignClient);
			calendar.allowSelection.Set(FALSE);
			panel.AddContent(calendar);

			control.SetCalendar(calendar);

			SetContent(panel);
			SetTitle(Strings.NewString("Calendar"));

			colorScheme := 0;

			IF (context # NIL) THEN
				configuration := WMRestorable.GetElement(context, "Configuration");
				IF (configuration # NIL) THEN
					WMRestorable.LoadLongint(configuration, "ColorScheme", colorScheme);
			 	END;
				SetColorScheme(colorScheme);
				WMRestorable.AddByContext(SELF, context);
			ELSE
				SetColorScheme(0);
				WMWindowManager.ExtAddWindow(SELF, 50, 50, {WMWindowManager.FlagHidden})
			END;
		END New;

		PROCEDURE SetColorScheme(scheme : LONGINT);
		BEGIN
			IF (scheme = 0) THEN
				calendar.clText.Set(WMGraphics.White);
				calendar.clTextTitle.Set(WMGraphics.White);
				calendar.clTextOtherMonths.Set(0FFFFFF80H);
				calendar.clTextWeekend.Set(WMGraphics.White);
				control.dateLabel.textColor.Set(WMGraphics.White);
				control.prevBtn.clTextDefault.Set(WMGraphics.White);
				control.nextBtn.clTextDefault.Set(WMGraphics.White);
			ELSE
				calendar.clText.Set(WMGraphics.Black);
				calendar.clTextTitle.Set(WMGraphics.Black);
				calendar.clTextOtherMonths.Set(080H);
				calendar.clTextWeekend.Set(WMGraphics.Black);
				control.dateLabel.textColor.Set(WMGraphics.Black);
				control.prevBtn.clTextDefault.Set(WMGraphics.Black);
				control.nextBtn.clTextDefault.Set(WMGraphics.Black);
			END;
		END SetColorScheme;

		PROCEDURE Close*;
		BEGIN
			Close^;
			DecCount;
		END Close;

		PROCEDURE PointerDown*(x, y:LONGINT; keys:SET);
		BEGIN
			lastX := bounds.l + x; lastY:=bounds.t + y;
			IF keys = {0} THEN
				dragging := TRUE
			ELSIF keys = {1,2} THEN
				dragging := FALSE;
				resizing := TRUE;
			ELSIF keys = {2} THEN
				NEW(contextMenu);
				contextMenu.Add("Close", HandleClose);
				contextMenu.Add("CurrentDay", HandleCurrentDay);
				contextMenu.Add("ToggleColor", HandleToggleColor);
				contextMenu.Popup(bounds.l + x, bounds.t + y)
			END
		END PointerDown;

		PROCEDURE HandleClose(sender, par: ANY);
		VAR manager : WMWindowManager.WindowManager;
		BEGIN
			manager := WMWindowManager.GetDefaultManager();
			manager.SetFocus(SELF);
			Close;
		END HandleClose;

		PROCEDURE HandleCurrentDay(sender, data: ANY);
		VAR dt : Dates.DateTime;
		BEGIN
			dt := Dates.Now();
			calendar.year.Set(dt.year);
			calendar.month.Set(dt.month);
			control.UpdateDateLabel;
		END HandleCurrentDay;

		PROCEDURE HandleToggleColor(sender, data : ANY);
		BEGIN
			colorScheme := (colorScheme + 1) MOD 2;
			SetColorScheme(colorScheme);
		END HandleToggleColor;

		PROCEDURE PointerMove*(x,y:LONGINT; keys:SET);
		VAR dx, dy, width, height : LONGINT;
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

		PROCEDURE PointerUp*(x, y:LONGINT; keys:SET);
		BEGIN
			PointerUp^(x, y, keys);
			dragging := FALSE;
			IF (keys # {1,2}) THEN
				IF resizing THEN
					resizing := FALSE;
					Resized(GetWidth(), GetHeight());
				END;
			END;
		END PointerUp;

		PROCEDURE Handle*(VAR x: WMMessages.Message);
		VAR configuration : WMRestorable.XmlElement;
		BEGIN
			IF (x.msgType = WMMessages.MsgExt) & (x.ext # NIL) THEN
				IF (x.ext IS KillerMsg) THEN
					Close;
				ELSIF (x.ext IS WMRestorable.Storage) THEN
					NEW(configuration); configuration.SetName("Configuration");
					WMRestorable.StoreLongint(configuration, "ColorScheme", colorScheme);
					x.ext(WMRestorable.Storage).Add("WMCalendar", "WMCalendar.Restore", SELF, configuration);
				ELSE Handle^(x)
				END
			ELSE Handle^(x)
			END
		END Handle;

	END Window;

VAR
	WeekDay : ARRAY 8 OF ARRAY 16 OF CHAR;
	nofWindows : LONGINT;

	StrCalendar, StrCalendarController, StrOnSelect, StrOnSelectInfo : Strings.String;

	PrototypeAllowSelection : WMProperties.BooleanProperty;
	PrototypeYear, PrototypeMonth, PrototypeFirstDayOfWeek : WMProperties.Int32Property;
	PrototypeClText, PrototypeClTextTitle, PrototypeClTextWeekend, PrototypeClTextOtherMonths, PrototypeClTextCurrentDay,
	PrototypeClMouseOver : WMProperties.ColorProperty;
	PrototypeCurrentDayImageName, PrototypeBackgroundImageName : WMProperties.StringProperty;

PROCEDURE Open*;
VAR window : Window;
BEGIN
	NEW(window, NIL);
END Open;

PROCEDURE Restore*(context : WMRestorable.Context);
VAR window : Window;
BEGIN
	NEW(window, context);
END Restore;

PROCEDURE GenCalendar*() : XML.Element;
VAR calendar : Calendar;
BEGIN
	NEW(calendar); RETURN calendar;
END GenCalendar;

PROCEDURE SameDay(dt1, dt2 : Dates.DateTime) : BOOLEAN;
BEGIN
	RETURN (dt1.year = dt2.year) & (dt1.month = dt2.month) & (dt1.day = dt2.day);
END SameDay;

PROCEDURE InitStrings;
BEGIN
	StrCalendar := Strings.NewString("Calendar");
	StrCalendarController := Strings.NewString("CalendarController");
	StrOnSelect := Strings.NewString("OnSelect");
	StrOnSelectInfo := Strings.NewString("Event generated when the user selects a day");
END InitStrings;

PROCEDURE InitPrototypes;
BEGIN
	NEW(PrototypeAllowSelection, NIL, Strings.NewString("AllowSelection"), Strings.NewString("Left click generates onSelect event"));
	PrototypeAllowSelection.Set(TRUE);

	NEW(PrototypeYear, NIL, Strings.NewString("Year"), Strings.NewString("Currently displayed year"));
	PrototypeYear.Set(2000);
	PrototypeYear.SetBounds(1, MAX(LONGINT));

	NEW(PrototypeMonth, NIL, Strings.NewString("Month"), Strings.NewString("Currently displayed month"));
	PrototypeMonth.Set(1);
	PrototypeMonth.SetBounds(January, December);

	NEW(PrototypeFirstDayOfWeek, NIL, Strings.NewString("FirstDayOfWeek"), Strings.NewString("First day of week (0 = Monday)"));
	PrototypeFirstDayOfWeek.Set(Monday);
	PrototypeFirstDayOfWeek.SetBounds(Monday, Sunday);

	NEW(PrototypeClText, NIL, Strings.NewString("ClText"), Strings.NewString("Default text color"));
	PrototypeClText.Set(0A0A0AFFH);

	NEW(PrototypeClTextTitle, NIL, Strings.NewString("ClTextTitle"), Strings.NewString("Text color of title row"));
	PrototypeClTextTitle.Set(WMGraphics.Black);

	NEW(PrototypeClTextWeekend, NIL, Strings.NewString("ClTextWeekend"), Strings.NewString("Text color of weekend days"));
	PrototypeClTextWeekend.Set(WMGraphics.Black);

	NEW(PrototypeClTextCurrentDay, NIL, Strings.NewString("ClTextCurrentDay"), Strings.NewString("Text color of current day"));
	PrototypeClTextCurrentDay.Set(WMGraphics.Red);

	NEW(PrototypeClTextOtherMonths, NIL, Strings.NewString("ClTextOtherMonths"), Strings.NewString("Text color of other months displayed"));
	PrototypeClTextOtherMonths.Set(0CCCCCCFFH);

	NEW(PrototypeClMouseOver, NIL, Strings.NewString("ClMouseOver"), Strings.NewString("Background color of mouse over cell"));
	PrototypeClMouseOver.Set(0FFFF0060H);

	NEW(PrototypeCurrentDayImageName, NIL, Strings.NewString("CurrentDayImageName"), Strings.NewString("Filename of current day image"));
	PrototypeCurrentDayImageName.Set(NIL);

	NEW(PrototypeBackgroundImageName, NIL, Strings.NewString("BackgroundImageName"), Strings.NewString("Filename of background image"));
	PrototypeBackgroundImageName.Set(NIL);
END InitPrototypes;

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
	AWAIT(nofWindows = 0)
END Cleanup;

BEGIN
	nofWindows := 0;
	InitStrings;
	InitPrototypes;
	Modules.InstallTermHandler(Cleanup);
	WeekDay[0] := "ERROR";
	WeekDay[Monday] := "Mo";
	WeekDay[Tuesday] := "Tu";
	WeekDay[Wednesday] := "We";
	WeekDay[Thursday] := "Th";
	WeekDay[Friday] := "Fr";
	WeekDay[Saturday] := "Sa";
	WeekDay[Sunday] := "Su";
END WMCalendar.

WMCalendar.Open ~

System.Free WMCalendar ~
