MODULE PositionDebugging;	(** AUTHOR "gubsermi"; PURPOSE "Debug window for the internal and the display position"; *)


IMPORT
	Strings, WMComponents, WM := WMWindowManager, WMGraphics, WMGraphicUtilities, WMPopups,
	WMProperties, WMMessages, WMStandardComponents, Objects;


TYPE

	DebugWindow = OBJECT(WMComponents.FormWindow);
	VAR
		dragging : BOOLEAN;
		lastX, lastY : SIZE;
		debugComponent : DebugComponent;
		contextMenu : WMPopups.Popup;

		PROCEDURE &New*;
		BEGIN
			Init(160, 40, TRUE);
			manager := WM.GetDefaultManager();

			NEW(debugComponent);
			debugComponent.alignment.Set(WMComponents.AlignClient);
			SetContent(debugComponent);

			WM.ExtAddWindow(SELF, 50, 50,{WM.FlagStayOnTop})
		END New;

		PROCEDURE PointerDown*(x, y:SIZE; keys:SET);
		BEGIN
			lastX := bounds.l+x; lastY:=bounds.t+y;
			IF keys = {0} THEN
				dragging := TRUE
			ELSIF keys = {2} THEN
				NEW(contextMenu);
				contextMenu.Add("Close", HandleClose);
				contextMenu.Popup(bounds.l+x, bounds.t+y)
			END
		END PointerDown;

		PROCEDURE HandleClose(sender, par: ANY);
		VAR manager : WM.WindowManager;
		BEGIN
			manager := WM.GetDefaultManager();
			manager.SetFocus(SELF);
			Close;
		END HandleClose;

		PROCEDURE PointerMove*(x,y:SIZE; keys:SET);
		VAR dx, dy : SIZE;
		BEGIN
			IF dragging THEN
				x := bounds.l + x; y := bounds.t + y; dx := x - lastX; dy := y - lastY;
				lastX := lastX + dx; lastY := lastY + dy;
				IF (dx # 0) OR (dy # 0) THEN manager.SetWindowPos(SELF, bounds.l + dx, bounds.t + dy) END
			END
		END PointerMove;

		PROCEDURE PointerUp*(x, y:SIZE; Keys:SET);
		BEGIN
			dragging := FALSE
		END PointerUp;

		PROCEDURE Handle*(VAR x: WMMessages.Message);
		BEGIN
			Handle^(x)
		END Handle;

		(* Adjusts the view to the new positions *)
		PROCEDURE ChangePos(realPos, bidiPos : SIZE);
		VAR
			realString, bidiString : ARRAY 8 OF CHAR;
		BEGIN
			Strings.IntToStr(realPos,realString);
			Strings.IntToStr(bidiPos,bidiString);
			Strings.Concat("(",realString,debugComponent.str^);
			Strings.Concat(debugComponent.str^,",",debugComponent.str^);
			Strings.Concat(debugComponent.str^,bidiString,debugComponent.str^);
			Strings.Concat(debugComponent.str^,")",debugComponent.str^);
			debugComponent.Invalidate;
		END ChangePos;

	END DebugWindow;

	DebugComponent* = OBJECT(WMComponents.VisualComponent)
	VAR
		str: Strings.String;
		viewMode*, color* : WMProperties.Int32Property;


		PROCEDURE DrawBackground*(canvas : WMGraphics.Canvas);
		BEGIN
			DrawBackground^(canvas);
			canvas.SetColor(color.Get());
			WMGraphicUtilities.DrawRect(canvas, GetClientRect(), color.Get(), WMGraphics.ModeCopy);
			WMGraphics.DrawStringInRect(canvas, GetClientRect(), FALSE, WMGraphics.AlignCenter, WMGraphics.AlignCenter, str^)
		END DrawBackground;

		PROCEDURE PropertyChanged*(sender, property: ANY);
		BEGIN
			PropertyChanged^(sender, property);
		END PropertyChanged;

		PROCEDURE & Init*;
		BEGIN
			Init^;
			NEW(str, 24);
			SetFont(WMGraphics.GetFont("Oberon", 16, {WMGraphics.FontBold}));

			NEW(color, prototypeColor, NIL, NIL); properties.Add(color);
			color.Set(0FFH);
			SetNameAsString(StrDebugComponent);
		END Init;

		PROCEDURE Initialize*;
		BEGIN
			Initialize^;
		END Initialize;

	END DebugComponent;

	DebugWindowNode = OBJECT
		VAR
			debugWindow : DebugWindow;
			next : DebugWindowNode;

		PROCEDURE &New*(dw : DebugWindow);
		BEGIN
			debugWindow := dw
		END New;
	END DebugWindowNode;


VAR
	debugWindow : DebugWindow;
	firstNode, lastNode : DebugWindowNode;
	StrDebugComponent : Strings.String;
	prototypeColor : WMProperties.Int32Property;


PROCEDURE AppendToList(debugWindow : DebugWindow);
VAR newNode : DebugWindowNode;
BEGIN {EXCLUSIVE}
	NEW(newNode, debugWindow);
	IF firstNode = NIL THEN
		firstNode := newNode
	ELSE
		lastNode.next := newNode
	END;
	lastNode := newNode;
END AppendToList;

PROCEDURE Open*;
BEGIN
	NEW(debugWindow);
	AppendToList(debugWindow);
END Open;

PROCEDURE CloseAll*;
VAR
	current : DebugWindowNode;
BEGIN
	Objects.SetPriority(Objects.Low); (* garantees that the active object terminates before the module is unloaded *)
	current := firstNode;
	WHILE current # NIL DO
		current.debugWindow.Close;
		current := current.next
	END;
	Objects.SetPriority(Objects.Normal)
END CloseAll;

PROCEDURE SetPos*(realPos, bidiPos : SIZE);
VAR
	current : DebugWindowNode;
BEGIN
	current := firstNode;
	WHILE current # NIL DO
		IF current.debugWindow # NIL THEN
			current.debugWindow.ChangePos(realPos,bidiPos);
		END;
		current := current.next;
	END;
END SetPos;


BEGIN
	StrDebugComponent := Strings.NewString("DebugComponent");
	NEW(prototypeColor, NIL, WMStandardComponents.NewString("Color"),
		WMStandardComponents.NewString("toggle debugging color"));


END PositionDebugging.
