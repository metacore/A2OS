MODULE WMVC;

(** AUTHOR "Yaroslav Romanchenko (SAGE) http://sage.com.ua/";
	PURPOSE "Visual Objects Container application inspired by article and Delphi sources
	of Yuri Spektor http://delphikingdom.ru/asp/viewitem.asp?catalogid=1344 "; *)

IMPORT
	SYSTEM, Modules, Commands, Strings,
	WMDialogs, WMRectangles, WMGraphics, WMWindowManager,
	XML, WMProperties, WMEvents, WMComponents, WMStandardComponents,
	WMScrollableComponents, WMEditors, WMDropDownLists,
	AAGraphics, Generics, VCTypes, VCBase, VCObjects;

TYPE

	VisualContainer* = OBJECT(VCBase.VisualContainerBase)
	VAR
		vObjects: VCObjects.VisualObjectVector;
		pObjectGen: VCObjects.VisualObjectGen;
		bConstructing: BOOLEAN;
		bDragging: BOOLEAN;
		oCurrentObject: VCObjects.BaseVisualObject;
		selected-: LONGINT;

		scale-, dpi-,
		logicalWidth-,
		logicalHeight-: WMProperties.RealProperty;

		onObjectSelect-: WMEvents.EventSource;
		onBeginConstruct-: WMEvents.EventSource;
		onEndConstruct-: WMEvents.EventSource;

		PROCEDURE &Init*;
		BEGIN
			Init^;

			SetNameAsString(StrVisualContainer);

			(* properties *)
			NEW(scale, PrototypeScale, NIL,NIL); properties.Add(scale);
			NEW(dpi, PrototypeDPI, NIL,NIL); properties.Add(dpi);
			NEW(logicalWidth, PrototypeLogicalWidth, NIL,NIL); properties.Add(logicalWidth);
			NEW(logicalHeight, PrototypeLogicalHeight, NIL,NIL); properties.Add(logicalHeight);

			(* events *)
			NEW(onObjectSelect, SELF, GSonObjectSelect, GSonObjectSelectInfo, NIL);
			events.Add(onObjectSelect);
			NEW(onBeginConstruct, SELF, GSonBeginConstruct, GSonBeginConstructInfo, NIL);
			events.Add(onBeginConstruct);
			NEW(onEndConstruct, SELF, GSonEndConstruct, GSonEndConstructInfo, NIL);
			events.Add(onEndConstruct);

			SetGenerator("WMVisualContainer.GenVisualContainer");

			selected := -1;
			NEW(vObjects);

			SetPointerInfo(WMWindowManager.GetDefaultManager().pointerCrosshair)

		END Init;

		PROCEDURE PropertyChanged*(sender, property: ANY);
		BEGIN
			IF ~IsCallFromSequencer() THEN
				sequencer.ScheduleEvent(SELF.PropertyChanged, sender, property)
			ELSE
				IF (property = scale) OR (property = dpi) THEN
					bounds.SetWidth(round(LogToScreen(SHORT(logicalWidth.Get()))));
					bounds.SetHeight(round(LogToScreen(SHORT(logicalHeight.Get()))));
					Resized
				ELSIF property = logicalWidth THEN
					bounds.SetWidth(round(LogToScreen(SHORT(logicalWidth.Get()))));
					Resized
				ELSIF property = logicalHeight THEN
					bounds.SetHeight(round(LogToScreen(SHORT(logicalHeight.Get()))));
					Resized
				ELSE
					PropertyChanged^(sender, property)
				END
			END
		END PropertyChanged;

		PROCEDURE RecacheProperties;
		BEGIN
			RecacheProperties^;
			bounds.SetWidth(round(LogToScreen(SHORT(logicalWidth.Get()))));
			bounds.SetHeight(round(LogToScreen(SHORT(logicalHeight.Get()))));
			Resized
		END RecacheProperties;

		PROCEDURE LogToScreen*(Value: REAL): REAL;
		BEGIN
			RETURN SHORT(dpi.Get()) * (Value / 25.4) * (SHORT(scale.Get()) / 100)
		END LogToScreen;

		PROCEDURE ScreenToLog*(Value: LONGINT): REAL;
		BEGIN
			RETURN ((Value / SHORT(dpi.Get())) * 25.4) / (SHORT(scale.Get()) / 100)
		END ScreenToLog;

		PROCEDURE LogToScreenPt*(lX, lY: REAL; VAR sX, sY: REAL);
		BEGIN
			sX := LogToScreen(lX); sY := LogToScreen(lY)
		END LogToScreenPt;

		PROCEDURE ScreenToLogPt*(sX, sY: LONGINT; VAR lX, lY: REAL);
		BEGIN
			lX := ScreenToLog(sX); lY := ScreenToLog(sY)
		END ScreenToLogPt;

		PROCEDURE SetSelected(Index: LONGINT);
		BEGIN
			IF selected # Index THEN
				selected := Index;
				onObjectSelect.Call(SYSTEM.VAL(ANY, ADDRESS(selected)))
			END
		END SetSelected;

		PROCEDURE FindObject(X, Y: LONGINT; VAR HitTest: VCObjects.HitTest): LONGINT;
		VAR
			i, res: LONGINT;
			cmdHitTest: VCObjects.CommandHitTest;
		BEGIN
			res := -1;
			IF vObjects.Count() = 0 THEN
				RETURN res
			END;
			cmdHitTest.ConvertIntf := SELF;
			cmdHitTest.Params.Pos.x := X;
			cmdHitTest.Params.Pos.y := Y;
			cmdHitTest.Params.Tolerance := 3;
			i := vObjects.Count() - 1;
			REPEAT
				vObjects.Get(i).HandleCommand(cmdHitTest);
				IF cmdHitTest.Hit.Type # VCObjects.HT.OUTSIDE THEN
					HitTest := cmdHitTest.Hit;
					res := i
				END;
				DEC(i)
			UNTIL (i = -1) OR (cmdHitTest.Hit.Type # VCObjects.HT.OUTSIDE);
			RETURN res
		END FindObject;

		PROCEDURE ObjectChanged(sender, par: ANY);
		BEGIN
			IF ~IsCallFromSequencer() THEN
				sequencer.ScheduleEvent(SELF.ObjectChanged, sender, par)
			ELSE
				Invalidate
			END
		END ObjectChanged;

		PROCEDURE FinishConstruct;
		VAR
			Index: LONGINT;
		BEGIN
			bConstructing := FALSE;
			Index := vObjects.IndexOf(oCurrentObject);

			(* Generate event *)
			(* onEndConstruct.Call(Index); *)

		END FinishConstruct;

		PROCEDURE PointerDown(x, y : LONGINT; keys : SET);
		VAR
			Index: LONGINT;
			Pos: VCTypes.Point2f;
			HitTest: VCObjects.HitTest;
			cmdBeginDrag: VCObjects.CommandBeginDrag;
			cmdConstructPoint: VCObjects.CommandConstructPoint;
			cmdStopConstruct: VCObjects.CommandStopConstruct;
		BEGIN
			IF keys = {0} THEN
				(* Left mouse button *)
				ScreenToLogPt(x, y, Pos.x, Pos.y);
				IF pObjectGen = NIL THEN
					Index := FindObject(x, y, HitTest);
					SetSelected(Index);
					IF Index > -1 THEN
						bDragging := TRUE;
						oCurrentObject := vObjects.Get(Index);
						cmdBeginDrag.Hit := HitTest;
						cmdBeginDrag.StartPos := Pos;
						oCurrentObject.HandleCommand(cmdBeginDrag)
					END
				ELSE
					IF ~bConstructing THEN
						bConstructing := TRUE;
						oCurrentObject := pObjectGen();
						oCurrentObject.onChange.Add(ObjectChanged);
						SetSelected(vObjects.Add(oCurrentObject));

						(* Generate event *)
						(*onBeginConstruct.Call(iSelected)*)

					END;
					cmdConstructPoint.Pos := Pos;
					oCurrentObject.HandleCommand(cmdConstructPoint);
					IF ~cmdConstructPoint.Result THEN
						FinishConstruct
					END
				END
			ELSIF keys = {2} THEN
				(* Right mouse button *)
				IF bConstructing THEN
					oCurrentObject.HandleCommand(cmdStopConstruct);
					IF ~cmdStopConstruct.Result THEN
						SetSelected(-1);
						Index := vObjects.IndexOf(oCurrentObject);
						vObjects.Remove(Index)
					END;
					FinishConstruct;
					Invalidate;
				END
			END
		END PointerDown;

		PROCEDURE PointerMove(x, y : LONGINT; keys : SET);
		VAR
			Index: LONGINT;
			Pos: VCTypes.Point2f;
			HitTest: VCObjects.HitTest;
			cmdGetCursor: VCObjects.CommandGetCursor;
			cmdProcessConstruct: VCObjects.CommandProcessConstruct;
			cmdDrag: VCObjects.CommandDrag;
			manager: WMWindowManager.WindowManager;
		BEGIN
			manager := WMWindowManager.GetDefaultManager();
			SetPointerInfo(manager.pointerCrosshair);
			IF pObjectGen = NIL THEN
				Index := FindObject(x, y, HitTest);
				IF Index > -1 THEN
					cmdGetCursor.Hit := HitTest;
					vObjects.Get(Index).HandleCommand(cmdGetCursor);
					CASE cmdGetCursor.Cursor OF
						VCObjects.CR.SIZEALL: SetPointerInfo(manager.pointerMove)
					|	VCObjects.CR.HORIZONTAL: SetPointerInfo(manager.pointerLeftRight)
					|	VCObjects.CR.VERTICAL: SetPointerInfo(manager.pointerUpDown)
					|	VCObjects.CR.DIAG1: SetPointerInfo(manager.pointerULDR)
					|	VCObjects.CR.DIAG2: SetPointerInfo(manager.pointerURDL)
					ELSE
						SetPointerInfo(manager.pointerCrosshair)
					END;
				END;
			END;
			ScreenToLogPt(x, y, Pos.x, Pos.y);
			IF bConstructing THEN
				cmdProcessConstruct.Pos := Pos;
				oCurrentObject.HandleCommand(cmdProcessConstruct);
				Invalidate;
			END;
			IF bDragging THEN
				cmdDrag.NewPos := Pos;
				oCurrentObject.HandleCommand(cmdDrag);
				Invalidate;
			END
		END PointerMove;

		PROCEDURE PointerUp(x, y : LONGINT; keys : SET);
		VAR
			cmdEndDrag: VCObjects.CommandEndDrag;
		BEGIN
			IF bDragging THEN
				oCurrentObject.HandleCommand(cmdEndDrag);
				bDragging := FALSE
			END
		END PointerUp;

		PROCEDURE DrawBackground(canvas: WMGraphics.Canvas);
		VAR
			i: LONGINT;
			logicalCanvas: VCBase.LogicalCanvas;
		BEGIN
			IF ~(canvas IS AAGraphics.Canvas) THEN
				RETURN
			END;
			NEW(logicalCanvas, canvas, SELF);
			canvas.Fill(WMRectangles.MakeRect(0, 0, bounds.GetWidth(), bounds.GetHeight()), LONGINT(0FFFFBBFFH), WMGraphics.ModeCopy);
			IF logicalCanvas # NIL THEN
				(*logicalCanvas.SetColor(WMGraphics.Black);
				logicalCanvas.DrawRect(0, 0, SHORT(logicalWidth.Get()) - 0.1, SHORT(logicalHeight.Get()) - 0.1, 0.01);*)
				FOR i := 0 TO vObjects.Count() - 1 DO
					IF i = selected THEN
						logicalCanvas.SetColor(WMGraphics.Green)
					ELSE
						logicalCanvas.SetColor(WMGraphics.Black)
					END;
					vObjects.Get(i).Draw(logicalCanvas)
				END
			END
		END DrawBackground;

	END VisualContainer;

	Window = OBJECT(WMComponents.FormWindow)
	VAR

		pnlToolbar: WMStandardComponents.Panel;

		btnSelect,
		btnLine,
		btnPoly,
		btnBeginEnd,
		btnInOut,
		btnAction,
		btnCondition,
		btnSub,
		btnText: WMStandardComponents.Button;

		fldText: WMEditors.TextField;

		ddlScale: WMDropDownLists.DropDownList;

		boxEditor: WMScrollableComponents.ScrollableContainer;
		VisCont: VisualContainer;

		PROCEDURE FormInit;

			PROCEDURE ButtonsSetup(buttons: ARRAY OF WMStandardComponents.Button);
			VAR
				i: LONGINT;
			BEGIN
				FOR i := 0 TO LEN(buttons) - 1 DO
					buttons[i].onClick.Add(ButtonsOnClickHandler);
					buttons[i].isToggle.Set(TRUE);
					buttons[i].indicateToggle.Set(FALSE);
					(* Make button flat *)
					buttons[i].effect3D.Set(0)
				END
			END ButtonsSetup;

		BEGIN
			SetTitle(Strings.NewString("Visual container application"));
			FillScaleDropDownList;

			ButtonsSetup([btnSelect, btnLine, btnPoly, btnBeginEnd,
				btnInOut, btnAction, btnCondition, btnSub, btnText]);
			btnSelect.SetPressed(TRUE);
			(* Emphasize pressed button by smallest degree of 3D effect *)
			btnSelect.effect3D.Set(1);

			ddlScale.onSelect.Add(ScaleOnSelect);

			VisCont.pObjectGen := NIL;
			VisCont.onObjectSelect.Add(ObjectOnSelect);

			fldText.onChanged.Add(TextOnChanged)

		END FormInit;

		PROCEDURE FillScaleDropDownList;
		VAR
			i, i100, res: LONGINT;
			sText: ARRAY 8 OF CHAR;
		BEGIN
			ddlScale.mode.Set(WMDropDownLists.Mode_SelectOnly);
			i100 := -1;
			FOR i := 0 TO LEN(scales) - 1 DO
				IF scales[i] = 100 THEN i100 := i END;
				Strings.IntToStr(scales[i], sText); Strings.AppendChar(sText, '%');
				ddlScale.model.Add(i, sText, res)
			END;
			IF i100 # -1 THEN ddlScale.SelectKey(i100) ELSE ddlScale.SelectKey(0) END
		END FillScaleDropDownList;

		PROCEDURE Close;
		BEGIN
			Close^;
			window := NIL
		END Close;

		PROCEDURE ButtonsOnClickHandler(sender, par: ANY);

			PROCEDURE ButtonsCheckUpdate(buttons: ARRAY OF WMStandardComponents.Button; button: WMStandardComponents.Button; VAR iMode: LONGINT);
			VAR
				i: LONGINT;
			BEGIN
				iMode := -1;
				i := 0;
				WHILE (i < LEN(buttons)) & ~buttons[i].GetPressed() DO
					INC(i)
				END;
				IF ~(i < LEN(buttons)) THEN
					(* There are no pressed buttons. It may be possible if previously pressed button was unpressed.
						We should set it to pressed again. This doesn't change the mode *)
					button.SetPressed(TRUE);
					RETURN
				END;
				FOR i := 0 TO LEN(buttons) - 1 DO
					IF buttons[i] # button THEN
						buttons[i].SetPressed(FALSE);
						buttons[i].effect3D.Set(0)
					ELSE
						iMode := i;
						(* Emphasize pressed button by smallest degree of 3D effect *)
						buttons[i].effect3D.Set(1)
					END
				END
			END ButtonsCheckUpdate;

		VAR
			iMode: LONGINT;

		BEGIN
			IF ~IsCallFromSequencer() THEN
				sequencer.ScheduleEvent(SELF.ButtonsOnClickHandler, sender, par)
			ELSIF sender IS WMStandardComponents.Button THEN
				(* Check if mode should be changed and update buttons *)
				ButtonsCheckUpdate([btnSelect, btnLine, btnPoly, btnBeginEnd, btnInOut, btnAction,
					btnCondition, btnSub, btnText], sender(WMStandardComponents.Button), iMode);
				IF iMode > -1 THEN
					VisCont.pObjectGen := VCObjects.BlockGenerators[iMode]
				END
			END
		END ButtonsOnClickHandler;

		PROCEDURE ScaleOnSelect(sender, par: ANY);
		VAR
			entry: WMDropDownLists.Entry;
		BEGIN
			IF ~IsCallFromSequencer() THEN
				sequencer.ScheduleEvent(SELF.ScaleOnSelect, sender, par)
			ELSE
				ddlScale.Acquire;
				ddlScale.model.Acquire;
				entry := ddlScale.GetSelection();
				IF entry # NIL THEN
					VisCont.scale.Set(scales[entry.key]);
					boxEditor.Invalidate
				END;
				ddlScale.model.Release;
				ddlScale.Release
			END
		END ScaleOnSelect;

		PROCEDURE ObjectOnSelect(sender, par: ANY);
		VAR
			Index: LONGINT;
			o: VCObjects.BaseVisualObject;
			s: ARRAY 128 OF CHAR;
		BEGIN
			IF ~IsCallFromSequencer() THEN
				sequencer.ScheduleEvent(SELF.ObjectOnSelect, sender, par)
			ELSE
				Index := SYSTEM.VAL(ADDRESS, par);
				IF Index > -1 THEN
					o := VisCont.vObjects.Get(Index);
					IF o IS VCObjects.RectVisualObject THEN
						o(VCObjects.RectVisualObject).GetText(s);
						fldText.SetAsString(s);
						fldText.readOnly.Set(FALSE)
					ELSE
						fldText.SetAsString("");
						fldText.readOnly.Set(TRUE)
					END
				ELSE
					fldText.SetAsString("");
					fldText.readOnly.Set(TRUE)
				END
			END
		END ObjectOnSelect;

		PROCEDURE TextOnChanged(sender, par: ANY);
		VAR
			Index: LONGINT;
			o: VCObjects.BaseVisualObject;
			s: ARRAY 128 OF CHAR;
		BEGIN
			IF ~IsCallFromSequencer() THEN
				sequencer.ScheduleEvent(SELF.ObjectOnSelect, sender, par)
			ELSE
				Index := SYSTEM.VAL(ADDRESS, par);
				IF Index > -1 THEN
					o := VisCont.vObjects.Get(Index);
					IF o IS VCObjects.RectVisualObject THEN
						fldText.GetAsString(s);
						o(VCObjects.RectVisualObject).SetText(s)
					END
				END
			END
		END TextOnChanged;

	END Window;

VAR
	StrVisualContainer: Strings.String;
	window: Window;
	context: Commands.Context;

	scales: ARRAY 8 OF LONGINT;

	GSonObjectSelect, GSonObjectSelectInfo: Strings.String;
	GSonBeginConstruct, GSonBeginConstructInfo: Strings.String;
	GSonEndConstruct, GSonEndConstructInfo: Strings.String;

	PrototypeScale, PrototypeDPI,
	PrototypeLogicalWidth,
	PrototypeLogicalHeight: WMProperties.RealProperty;

	PROCEDURE FindComponents(c: XML.Content; data: ANY);
	VAR
		comp: WMComponents.Component;
		sUID: Strings.String;
	BEGIN
		IF c IS WMComponents.Component THEN
			comp := c(WMComponents.Component);
			sUID := comp.uid.Get();
			IF (sUID # NIL) & (sUID^ # "") THEN
				data(Generics.ObjectMap).Insert(sUID, comp)
			END
		END
	END FindComponents;

	PROCEDURE WireComponents(root: WMComponents.VisualComponent; win: Window): BOOLEAN;
	VAR
		trap: BOOLEAN;
		components: Generics.ObjectMap;
	BEGIN
		trap := FALSE;

		NEW(components);
		root.Traverse(FindComponents, components);

		window.pnlToolbar := components.GetAOC("pnlToolbar")(WMStandardComponents.Panel);

		window.btnSelect := components.GetAOC("btnSelect")(WMStandardComponents.Button);
		window.btnLine := components.GetAOC("btnLine")(WMStandardComponents.Button);
		window.btnPoly := components.GetAOC("btnPoly")(WMStandardComponents.Button);
		window.btnBeginEnd := components.GetAOC("btnBeginEnd")(WMStandardComponents.Button);
		window.btnInOut := components.GetAOC("btnInOut")(WMStandardComponents.Button);
		window.btnAction := components.GetAOC("btnAction")(WMStandardComponents.Button);
		window.btnCondition := components.GetAOC("btnCondition")(WMStandardComponents.Button);
		window.btnSub := components.GetAOC("btnSub")(WMStandardComponents.Button);
		window.btnText := components.GetAOC("btnText")(WMStandardComponents.Button);

		window.fldText := components.GetAOC("fldText")(WMEditors.TextField);

		window.ddlScale := components.GetAOC("ddlScale")(WMDropDownLists.DropDownList);

		window.boxEditor := components.GetAOC("boxEditor")(WMScrollableComponents.ScrollableContainer);
		window.VisCont := components.GetAOC("VisCont")(VisualContainer);

	FINALLY

		RETURN ~trap

	END WireComponents;

	PROCEDURE WindowGenerator*(ctx: Commands.Context): WMWindowManager.Window;
	VAR
		xml: XML.Content;
		root: WMComponents.VisualComponent;
		x, y: LONGINT;
		manager: WMWindowManager.WindowManager;

		PROCEDURE RaiseError(CONST msg: ARRAY OF CHAR);
		BEGIN
			HALT(105)
		END RaiseError;

	BEGIN
		IF window = NIL THEN
			context := ctx;

			xml := WMComponents.Load("WMVC.zip://WMVC.xml");
			IF xml = NIL THEN
				RaiseError("Resources file not found.");
				RETURN NIL
			ELSIF xml IS WMComponents.VisualComponent THEN

				root := xml(WMComponents.VisualComponent);

				(* Window setup *)
				NEW(window, root.bounds.GetWidth(), root.bounds.GetHeight(), FALSE);

				window.SetCanvasGenerator(AAGraphics.GenCanvas);

				window.SetContent(root);
				IF ~WireComponents(root, window) THEN
					context.out.String("Form resource corrupted"); context.out.Ln;
					context.out.Update;
					RETURN NIL
				END;

				(* Initialize form and wire event handlers *)
				window.FormInit;

				(* Form show *)
				WMDialogs.DefaultPos(x, y, window.GetWidth(), window.GetHeight());
				WMWindowManager.ExtAddWindow(	window, x, y,
					{WMWindowManager.FlagFrame, WMWindowManager.FlagClose,
						WMWindowManager.FlagMinimize});
				manager := WMWindowManager.GetDefaultManager();
				manager.SetFocus(window);

				RETURN window
			ELSE
				RETURN NIL
			END
		ELSE
			RETURN NIL
		END
	END WindowGenerator;

	PROCEDURE Open*(ctx: Commands.Context);
	VAR
		wDummy: WMWindowManager.Window;
	BEGIN
		IF window = NIL THEN
			wDummy := WindowGenerator(ctx)
		END
	END Open;

	PROCEDURE Cleanup;
	BEGIN
		IF window # NIL THEN
			window.Close;
		END
	END Cleanup;

	PROCEDURE GenVisualContainer*(): XML.Element;
	VAR el: VisualContainer;
	BEGIN NEW(el); RETURN el
	END GenVisualContainer;

	PROCEDURE round(f: REAL): LONGINT;
	BEGIN
		RETURN ENTIER(f + 0.5)
	END round;

	PROCEDURE Init;
	BEGIN
		scales[0] := 10;
		scales[1] := 25;
		scales[2] := 50;
		scales[3] := 100;
		scales[4] := 200;
		scales[5] := 400;
		scales[6] := 800;
		scales[7] := 1600;
	END Init;

	PROCEDURE InitStrings;
	BEGIN
		StrVisualContainer := Strings.NewString("VisualContainer");

		GSonObjectSelect := Strings.NewString("onObjectSelect");
		GSonObjectSelectInfo := Strings.NewString("Event generated whenever an object is selected");

		GSonBeginConstruct := Strings.NewString("onBeginConstruct");
		GSonBeginConstructInfo := Strings.NewString("Event generated whenever an object construction started");

		GSonEndConstruct := Strings.NewString("onEndConstruct");
		GSonEndConstructInfo := Strings.NewString("Event generated whenever an object construction ended");
	END InitStrings;

	PROCEDURE InitPrototypes;
	BEGIN
		NEW(PrototypeScale, NIL, Strings.NewString("Scale"), Strings.NewString("scaling percentage of objects in Visual Container (default 100%)"));
		PrototypeScale.Set(100);
		NEW(PrototypeDPI, NIL, Strings.NewString("DPI"), Strings.NewString("resolution in dots per inch"));
		PrototypeDPI.Set(96);
		NEW(PrototypeLogicalWidth, NIL, Strings.NewString("LogicalWidth"), Strings.NewString("paper width (default 297 mm)"));
		PrototypeLogicalWidth.Set(297);
		NEW(PrototypeLogicalHeight, NIL, Strings.NewString("LogicalHeight"), Strings.NewString("paper height (default 210 mm)"));
		PrototypeLogicalHeight.Set(210);
	END InitPrototypes;

BEGIN

	Init;
	InitStrings;
	InitPrototypes;
	Modules.InstallTermHandler(Cleanup)

END WMVC.

WMVC.Open ~
System.Free WMVC VCObjects VCBase VCPoly VCTypes FloatAA Generics ~


