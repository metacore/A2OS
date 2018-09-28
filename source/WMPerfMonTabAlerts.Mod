MODULE WMPerfMonTabAlerts; (** AUTHOR "staubesv"; PURPOSE "Perfomance Monitor tab for Alerts"; *)
(**
 * History:
 *
 *	02.03.2007	First release (staubesv)
 *)

IMPORT
	Kernel, Strings,
	WMComponents, WMStandardComponents, WMGrids, WMStringGrids, WMGraphics, WMEditors, WMDialogs,
	Perf := WMPerfMonComponents, Alerts := WMPerfMonAlerts;

CONST
	PollingInterval = 500; (* ms *)

	GridBgFillColor = 0646464FFH;

TYPE

	CellData = POINTER TO RECORD
		id : LONGINT;
	END;

	AlertsTab* = OBJECT(WMComponents.VisualComponent)
	VAR
		(* status panel *)
		statusIndicator, statusLabel : WMStandardComponents.Label;
		onOffBtn : WMStandardComponents.Button;

		(* alerts panel *)
		alertsGrid : WMStringGrids.StringGrid;

		(* rules panel *)
		rulesGrid : WMStringGrids.StringGrid;
		resetBtn, addBtn, removeBtn : WMStandardComponents.Button;
		alertEdit : WMEditors.TextField;

		(* rule files panel *)
		saveBtn, loadBtn, appendBtn : WMStandardComponents.Button;
		filenameEdit : WMEditors.TextField;

		oldStatus, status : Alerts.Status;

		filename : ARRAY 256 OF CHAR;
		modified : BOOLEAN;

		spacings : WMGrids.Spacings;

		timer : Kernel.Timer;
		dead, alive : BOOLEAN;

		PROCEDURE HandleButtons(sender, data : ANY);
		VAR string, msg : ARRAY 256 OF CHAR; nofRemoved, res : WORD;
		BEGIN
			IF sender = onOffBtn THEN
				IF status.enabled THEN
					Alerts.DisableAlerts;
				ELSE
					Alerts.EnableAlerts;
				END;
			ELSIF sender = resetBtn THEN
				ResetSelectedAlerts;
			ELSIF sender = addBtn THEN
				alertEdit.GetAsString(string);
				Alerts.AddByString(string, msg, res);
				IF res # Alerts.Ok THEN
					WMDialogs.Error("Error", msg);
				ELSE
					modified := TRUE;
				END;
			ELSIF sender = removeBtn THEN
				nofRemoved := RemoveSelectedAlerts();
				IF nofRemoved > 0 THEN modified := TRUE; END;
			ELSIF (sender = loadBtn) OR (sender = appendBtn) THEN
				filenameEdit.GetAsString(string);
				Alerts.LoadRules(string, sender = appendBtn, msg, res);
				IF res # Alerts.Ok THEN
					WMDialogs.Error("Error", msg);
				END;
			ELSIF sender = saveBtn THEN
				filenameEdit.GetAsString(string);
				Alerts.StoreRules(string, msg, res);
				IF res # Alerts.Ok THEN
					WMDialogs.Error("Error", msg);
				END;
			END;
		END HandleButtons;

		PROCEDURE ResetSelectedAlerts;
		VAR scol, srow, ecol, erow, row: LONGINT; res: WORD; ptr : ANY; cellData : CellData; msg : ARRAY 128 OF CHAR;
		BEGIN
			rulesGrid.Acquire;
			rulesGrid.model.Acquire;
			rulesGrid.GetSelection(scol, srow, ecol, erow);
			IF (srow >= 1) & (erow >= 1) THEN
				FOR row := srow TO erow DO
					ptr := rulesGrid.model.GetCellData(0, row);
					IF ptr # NIL THEN cellData := ptr (CellData); END;
					IF cellData # NIL THEN
						Alerts.SetStateByID(cellData.id, Alerts.Reset, msg, res);
					END;
				END;
			END;
			rulesGrid.model.Release;
			rulesGrid.Release;
		END ResetSelectedAlerts;

		PROCEDURE RemoveSelectedAlerts() : LONGINT;
		VAR scol, srow, ecol, erow, row : LONGINT; ptr : ANY; cellData : CellData; nofRemoved : LONGINT;
		BEGIN
			rulesGrid.Acquire;
			rulesGrid.model.Acquire;
			rulesGrid.GetSelection(scol, srow, ecol, erow);
			IF (srow >= 1) & (erow >= 1) THEN
				FOR row := srow TO erow DO
					ptr := rulesGrid.model.GetCellData(0, row);
					IF ptr # NIL THEN cellData := ptr (CellData); END;
					IF cellData # NIL THEN
						nofRemoved := nofRemoved + Alerts.RemoveAlertByID(cellData.id);
					END;
				END;
			END;
			rulesGrid.model.Release;
			rulesGrid.Release;
			RETURN nofRemoved;
		END RemoveSelectedAlerts;

		PROCEDURE Update;
		BEGIN
			status := Alerts.GetStatus();
			IF status.stamp # oldStatus.stamp THEN
				IF (status.filename # "") & (filename = "") THEN
					COPY(status.filename, filename); modified := FALSE;
				ELSE
					IF status.filename # filename THEN modified := FALSE; END;
				END;
				UpdateStatusIndicator(status.enabled);
				UpdateStatusLabel(status);
				UpdateGrids;
				oldStatus := status;
			ELSIF modified THEN
				UpdateStatusLabel(status);
			END;
		END Update;

		PROCEDURE UpdateStatusIndicator(enabled : BOOLEAN);
		BEGIN
			IF enabled THEN
				statusIndicator.fillColor.Set(WMGraphics.Green);
				statusIndicator.caption.SetAOC("ON");
				onOffBtn.caption.SetAOC("Disable");
			ELSE
				statusIndicator.fillColor.Set(WMGraphics.Red);
				statusIndicator.caption.SetAOC("OFF");
				onOffBtn.caption.SetAOC("Enable");
			END;
		END UpdateStatusIndicator;

		PROCEDURE UpdateStatusLabel(status : Alerts.Status);
		VAR nbr, caption : ARRAY 128 OF CHAR;
		BEGIN
			caption := "  ";
			Strings.IntToStr(status.nbrOfAlerts, nbr);
			Strings.Append(caption, nbr);
			Strings.Append(caption, " alerts, ");

			Strings.IntToStr(status.nbrOfRules, nbr);
			Strings.Append(caption, nbr);
			Strings.Append(caption, " rules loaded");
			IF status.filename # "" THEN
				Strings.Append(caption, " from file "); Strings.Append(caption, status.filename);
				IF modified THEN Strings.Append(caption, " (modified)"); END;
			END;
			Strings.Append(caption, ".");
			statusLabel.caption.SetAOC(caption);
		END UpdateStatusLabel;

		PROCEDURE ComputeAlertInfo(alerts : Alerts.Alerts; VAR nbrOfRules, nbrOfAlerts : LONGINT);
		VAR i : LONGINT;
		BEGIN
			nbrOfRules := 0; nbrOfAlerts := 0;
			IF alerts # NIL THEN
				FOR i := 0 TO LEN(alerts)-1 DO
					INC(nbrOfRules);
					IF alerts[i].state = Alerts.Triggered THEN
						INC(nbrOfAlerts);
					END;
				END;
			END;
		END ComputeAlertInfo;

		PROCEDURE SetRowText(grid : WMStringGrids.StringGrid; alert : Alerts.AlertInfo; row : LONGINT);
		VAR caption : ARRAY 128 OF CHAR; col : LONGINT; cellData : CellData;
		BEGIN
			NEW(cellData); cellData.id := alert.id;
			grid.model.SetCellData(0, row, cellData);
			grid.model.SetTextAlign(0, row, WMGraphics.AlignCenter);
			grid.model.SetTextAlign(4, row, WMGraphics.AlignCenter);
			FOR col := 0 TO 4 DO
				CASE col OF
					|0: Alerts.GetStateString(alert.state, caption);
					|1: Alerts.GetTypeString(alert.type, caption);
					|2: Alerts.GetFullTriggerString(alert, caption);
					|3: Strings.FloatToStr(alert.violation, 4, 2, 0, caption);
					|4: Strings.IntToStr(alert.nbrOfViolations, caption);
				ELSE
				END;
				grid.model.SetCellText(col, row, Strings.NewString(caption));
			END;
		END SetRowText;

		PROCEDURE UpdateGrids;
		VAR
			gridRow, alertsGridRow : LONGINT; alerts : Alerts.Alerts;
			nbrOfRules, nbrOfAlerts : LONGINT;
			i : LONGINT;
		BEGIN
			alerts := Alerts.GetAlerts();
			ComputeAlertInfo(alerts, nbrOfRules, nbrOfAlerts);
			rulesGrid.Acquire;
			rulesGrid.model.Acquire;
			alertsGrid.Acquire;
			alertsGrid.model.Acquire;
			IF alerts # NIL THEN
				rulesGrid.model.SetNofRows(nbrOfRules + 1); gridRow := 1;
				alertsGrid.model.SetNofRows(nbrOfAlerts + 1); alertsGridRow := 1;
				FOR i := 0 TO LEN(alerts)-1 DO
					IF alerts[i].state = Alerts.Triggered THEN
						SetRowText(alertsGrid, alerts[i], alertsGridRow);
						INC(alertsGridRow);
					END;
					SetRowText(rulesGrid, alerts[i], gridRow);
					INC(gridRow);
				END;
			ELSE
				rulesGrid.model.SetNofRows(1);
				alertsGrid.model.SetNofRows(1);
			END;
			alertsGrid.model.Release;
			alertsGrid.Release;
			rulesGrid.model.Release;
			rulesGrid.Release;
		END UpdateGrids;

		PROCEDURE NewGrid() : WMStringGrids.StringGrid;
		VAR grid : WMStringGrids.StringGrid;
		BEGIN
			NEW(grid);
			grid.fixedRows.Set(1);
			grid.fillColor.Set(GridBgFillColor);
			grid.alignment.Set(WMComponents.AlignTop);
			grid.SetSelectionMode(WMGrids.GridSelectRows);
			grid.SetSelection(-1, -1, -1, -1);
			grid.alwaysShowScrollX.Set(FALSE); grid.showScrollX.Set(TRUE);
			grid.alwaysShowScrollY.Set(FALSE); grid.showScrollY.Set(TRUE);
			grid.allowColResize.Set(TRUE); grid.allowRowResize.Set(FALSE);
			grid.adjustFocusPosition.Set(FALSE);

			NEW(spacings, 5);
			spacings[0] := 40; spacings[1] := 80; spacings[2] := 480; spacings[3] := 50; spacings[4] := 70;

			grid.Acquire;
			grid.model.Acquire;
			grid.model.SetNofCols(5); grid.SetColSpacings(spacings);
			grid.model.SetNofRows(1);
			(* column titles *)
			grid.model.SetCellText(0, 0, Strings.NewString("Status")); grid.model.SetTextAlign(0, 0, WMGraphics.AlignCenter);
			grid.model.SetCellText(1, 0, Strings.NewString("Type"));
			grid.model.SetCellText(2, 0, Strings.NewString("Trigger"));
			grid.model.SetCellText(3, 0, Strings.NewString("Violation"));
			grid.model.SetCellText(4, 0, Strings.NewString("NbrOfAlerts"));
			grid.model.Release;
			grid.Release;
			RETURN grid;
		END NewGrid;

		PROCEDURE CreateStatusPanel() : WMStandardComponents.GroupPanel;
		VAR panel : WMStandardComponents.GroupPanel;
		BEGIN
			panel := Perf.NewGroupPanel("Status", WMComponents.AlignTop, 45);

			statusIndicator := Perf.NewLabel("", WMComponents.AlignLeft, 80, 0);
			statusIndicator.alignH.Set(WMGraphics.AlignCenter); statusIndicator.alignV.Set(WMGraphics.AlignCenter);
			panel.AddContent(statusIndicator);

			onOffBtn := Perf.NewButton("", HandleButtons); panel.AddContent(onOffBtn);
			statusLabel := Perf.NewLabel("", WMComponents.AlignClient, 0, 0); panel.AddContent(statusLabel);

			RETURN panel;
		END CreateStatusPanel;

		PROCEDURE CreateAlertsPanel() : WMStandardComponents.GroupPanel;
		VAR panel : WMStandardComponents.GroupPanel;
		BEGIN
			panel := Perf.NewGroupPanel("Alerts", WMComponents.AlignTop, 100);
			alertsGrid := NewGrid(); alertsGrid.bounds.SetHeight(100); alertsGrid.SetSelectionMode(WMGrids.GridSelectNone);
			panel.AddContent(alertsGrid);
			RETURN panel;
		END CreateAlertsPanel;

		PROCEDURE CreateRulesPanel() : WMStandardComponents.GroupPanel;
		VAR panel : WMStandardComponents.GroupPanel; line : WMStandardComponents.Panel;
		BEGIN
			panel := Perf.NewGroupPanel("Rules", WMComponents.AlignTop, 180);
			line := Perf.NewPanel(WMComponents.AlignBottom, 0, Perf.LineHeight); panel.AddContent(line);

			resetBtn := Perf.NewButton("Reset", HandleButtons); line.AddContent(resetBtn);
			removeBtn := Perf.NewButton("Remove", HandleButtons); line.AddContent(removeBtn);
			addBtn := Perf.NewButton("Add", HandleButtons); line.AddContent(addBtn);
			alertEdit := Perf.NewTextField(0); alertEdit.alignment.Set(WMComponents.AlignClient); line.AddContent(alertEdit);
			alertEdit.SetAsString("PluginName.ValueName sticky|singleshot|multishot trigger value1 value2 onAlertCmd onLeaveCmd");

			rulesGrid := NewGrid(); rulesGrid.alignment.Set(WMComponents.AlignClient);
			panel.AddContent(rulesGrid);

			RETURN panel;
		END CreateRulesPanel;

		PROCEDURE CreateRulefilesPanel() : WMStandardComponents.GroupPanel;
		VAR panel : WMStandardComponents.GroupPanel;
		BEGIN
			panel := Perf.NewGroupPanel("Rule files", WMComponents.AlignTop, 45);

			loadBtn := Perf.NewButton("Load", HandleButtons); panel.AddContent(loadBtn);
			appendBtn := Perf.NewButton("Append", HandleButtons); panel.AddContent(appendBtn);
			saveBtn := Perf.NewButton("Store", HandleButtons); panel.AddContent(saveBtn);
			filenameEdit := Perf.NewTextField(0); filenameEdit.alignment.Set(WMComponents.AlignClient); panel.AddContent(filenameEdit);

			RETURN panel;
		END CreateRulefilesPanel;

		PROCEDURE Finalize*;
		BEGIN
			alive := FALSE;
			timer.Wakeup;
			BEGIN {EXCLUSIVE} AWAIT(dead); END;
			Finalize^;
		END Finalize;

		PROCEDURE &Init*;
		VAR panel : WMStandardComponents.Panel;
		BEGIN
			Init^;
			SetNameAsString(StrAlertsTab);
			NEW(timer);
			alive := TRUE; dead := FALSE;
			AddContent(CreateStatusPanel());
			AddContent(CreateRulefilesPanel());
			AddContent(CreateAlertsPanel());
			panel := CreateRulesPanel(); panel.alignment.Set(WMComponents.AlignClient);
			AddContent(panel);
		END Init;

	BEGIN {ACTIVE}
		WHILE alive DO
			Update;
			timer.Sleep(PollingInterval);
		END;
		BEGIN {EXCLUSIVE} dead := TRUE; END;
	END AlertsTab;

VAR
	StrAlertsTab : Strings.String;

BEGIN
	StrAlertsTab := Strings.NewString("AlertsTab");
END WMPerfMonTabAlerts.
