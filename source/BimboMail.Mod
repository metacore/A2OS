MODULE BimboMail; (** AUTHOR "TF"; PURPOSE "Simple Mail Reader"; *)

IMPORT
	Modules,  WMGrids, WMStringGrids, MailStorage, WMGraphics,
	WMMessages, WMStandardComponents, WMComponents,
	WMEditors, Strings, TextUtilities, Texts,
	WM := WMWindowManager;

CONST
	TempFilename = "BimboMail.Temp";

TYPE
	KillerMsg = OBJECT
	END KillerMsg;

	Window* = OBJECT (WMComponents.FormWindow)
	VAR currentMailbox : MailStorage.Storage;
		messageList : WMStringGrids.StringGrid;
		messageText : WMEditors.Editor;

		PROCEDURE CreateForm(): WMComponents.VisualComponent;
		VAR
			panel : WMStandardComponents.Panel;
			toolbar, mailboxSelection, mailContentPanel : WMStandardComponents.Panel;
			mailboxEntries : WMStringGrids.StringGrid;
			mailText : WMEditors.Editor;
			vResizer : WMStandardComponents.Resizer;
		BEGIN
			NEW(panel); panel.bounds.SetExtents(800, 700); panel.fillColor.Set(0FFFFFFFFH); panel.takesFocus.Set(TRUE);
			NEW(toolbar); toolbar.fillColor.Set(000FF00FFH); toolbar.bounds.SetHeight(20); toolbar.alignment.Set(WMComponents.AlignTop);
			panel.AddContent(toolbar);

			NEW(mailboxSelection); mailboxSelection.fillColor.Set(0FF0000FFH); mailboxSelection.bounds.SetWidth(64);
			mailboxSelection.alignment.Set(WMComponents.AlignLeft);
			panel.AddContent(mailboxSelection);

			NEW(mailContentPanel); mailContentPanel.fillColor.Set(0FFFFFFFFH); mailContentPanel.bounds.SetHeight(350);
			mailContentPanel.alignment.Set(WMComponents.AlignBottom);
			panel.AddContent(mailContentPanel);

			NEW(mailboxEntries); mailboxEntries.alignment.Set(WMComponents.AlignClient);
			panel.AddContent(mailboxEntries);
			messageList := mailboxEntries;

			NEW(vResizer); vResizer.bounds.SetHeight(5); vResizer.alignment.Set(WMComponents.AlignTop);
			mailContentPanel.AddContent(vResizer);

			NEW(mailText); mailText.alignment.Set(WMComponents.AlignClient); mailText.tv.showBorder.Set(TRUE);
			mailContentPanel.AddContent(mailText);
			messageText := mailText;

			mailText.multiLine.Set(TRUE);
			mailText.readOnly.Set(TRUE);
			RETURN panel
		END CreateForm;

		PROCEDURE SetMailbox(mb : MailStorage.Storage);
		VAR i : LONGINT;
			hFrom, hTo, hSubject, hDate : ARRAY 128 OF CHAR;
		BEGIN
			currentMailbox := mb;
			messageList.model.Acquire;
			messageList.model.SetNofCols(3);
			messageList.model.SetNofRows(mb.GetCount());
			FOR i := 0 TO mb.GetCount() - 1 DO
				currentMailbox.GetHeader(i, hFrom, hTo, hSubject, hDate);
				messageList.model.SetCellText(0, i + 1, Strings.NewString(hFrom));
				messageList.model.SetTextAlign(0, i + 1, WMGraphics.AlignCenter);

				messageList.model.SetCellText(1, i + 1, Strings.NewString(hSubject));
				messageList.model.SetTextAlign(1, i + 1, WMGraphics.AlignCenter);

				messageList.model.SetCellText(2, i + 1, Strings.NewString(hDate));
				messageList.model.SetTextAlign(2, i + 1, WMGraphics.AlignCenter)
			END;
			messageList.model.Release;
		END SetMailbox;

		PROCEDURE &New*;
		VAR vc : WMComponents.VisualComponent;
			mb : MailStorage.Storage;
			colWidths : WMGrids.Spacings;
			i : LONGINT;
			str : ARRAY 32 OF CHAR;
		BEGIN
			IncCount;
			vc := CreateForm();

			Init(vc.bounds.GetWidth(), vc.bounds.GetHeight(), FALSE);
			SetContent(vc);
			manager := WM.GetDefaultManager();
			manager.Add(100, 100, SELF, {WM.FlagFrame});
			SetTitle(Strings.NewString("Bimbo Mail"));

			messageList.fixedRows.Set(1);
			NEW(colWidths, 4);
			colWidths[0] := messageList.bounds.GetWidth() DIV 3;
			colWidths[1] := 0;
			colWidths[2] := messageList.bounds.GetWidth() DIV 3;
			colWidths[3] := messageList.bounds.GetWidth() DIV 3;
			messageList.SetColSpacings(colWidths);
			messageList.onClick.Add(MessageClick);
			messageList.SetSelectionMode(WMGrids.GridSelectSingleRow);
			messageList.model.Acquire;
			messageList.model.SetNofCols(3);
			messageList.model.SetNofRows(2);
			FOR i := 0 TO 3 - 1 DO
				GetTitleStr(i, str);
				messageList.model.SetCellText(i, 0, Strings.NewString(str));
				messageList.model.SetTextAlign(i, 0, WMGraphics.AlignCenter)
			END;
			messageList.SetColSpacings(colWidths);
			messageList.model.Release;

			NEW(mb); mb.Open("MailMessages", "");
			SetMailbox(mb);
		END New;

		PROCEDURE GetTitleStr(col: LONGINT; VAR x : ARRAY OF CHAR);
		BEGIN
			CASE col OF
				| 0 : COPY("From", x)
				| 1 : COPY("Subject", x)
				| 2 : COPY("Date", x)
			ELSE COPY("", x);
			END
		END GetTitleStr;

		PROCEDURE Close*;
		BEGIN
			Close^;
			DecCount
		END Close;

		PROCEDURE Handle*(VAR x: WMMessages.Message);
		BEGIN
			IF (x.msgType = WMMessages.MsgExt) & (x.ext # NIL) & (x.ext IS KillerMsg) THEN Close
			ELSE Handle^(x)
			END
		END Handle;

		(*PROCEDURE DrawCell(canvas : WMGraphics.Canvas; w, h : LONGINT; state : SET; x, y : LONGINT);
		VAR color: LONGINT; str, hFrom, hTo, hSubject, hDate : ARRAY 128 OF CHAR;
		BEGIN
			color := WMGraphics.RGBAToColor(255, 255, 255, 255);
			IF state * {WMGrids.CellFixed, WMGrids.CellSelected} = {WMGrids.CellFixed, WMGrids.CellSelected} THEN
				color := WMGraphics.RGBAToColor(0, 128, 255, 255)
			ELSIF WMGrids.CellFixed IN state THEN
				color := WMGraphics.RGBAToColor(196, 196, 196, 255)
			ELSIF WMGrids.CellSelected IN state THEN
				color := WMGraphics.RGBAToColor(196, 196, 255, 255)
			ELSIF WMGrids.CellFocused IN state THEN
				color := WMGraphics.RGBAToColor(255, 255, 196, 255)
			END;
			canvas.SetColor(WMGraphics.RGBAToColor(0, 0, 0, 255));
			canvas.SetFont(WMBitmapFont.bimbofont);

			canvas.Fill(WMRectangles.MakeRect(0, 0, w, h), color, WMGraphics.ModeCopy);
			IF (WMGrids.CellFocused IN state) & ~(WMGrids.CellHighlighted IN state) THEN
				WMGraphicUtilities.DrawBevel(canvas, WMRectangles.MakeRect(0, 0, w, h), 1, TRUE, WMGraphics.RGBAToColor(0, 0, 0, 196),
				WMGraphics.ModeSrcOverDst)
			END;
			IF y = 0 THEN
				CASE x OF
					| 0 : str := "From"
					| 1 : str := "To"
					| 2 : str := "Subject"
					| 3 : str := "Date"
				ELSE
				END
			ELSIF (currentMailbox # NIL) & (y - 1 >= 0) & (y - 1 < currentMailbox.GetCount()) THEN
				currentMailbox.GetHeader(y - 1, hFrom, hTo, hSubject, hDate);
				CASE x OF
					| 0 : COPY(hFrom, str)
					| 1 : COPY(hTo, str)
					| 2 : COPY(hSubject, str)
					| 3 : COPY(hDate, str)
				ELSE
				END
			END;
			canvas.DrawString(4, h-4, str)
		END DrawCell; *)

		PROCEDURE MessageClick(sender, data : ANY);
		VAR scol, srow, ecol, erow, y : SIZE; res: WORD; text : Texts.Text;
		BEGIN
			messageList.GetSelection(scol, srow, ecol, erow);
			y := srow - 1;
			IF (currentMailbox # NIL) & (y >= 0) & (y < currentMailbox.GetCount()) THEN
				IF currentMailbox.ToFile(y, TempFilename) THEN
					text := messageText.text;
					text.AcquireWrite;
					text.Delete(0, text.GetLength());
					TextUtilities.LoadOberonText(text, TempFilename, res);
					text.ReleaseWrite;
					messageText.tv.firstLine.Set(0);
				END
			END
		END MessageClick;

	END Window;

VAR
	nofWindows : LONGINT;

PROCEDURE Open*;
VAR winstance : Window;
BEGIN
	NEW(winstance);
END Open;

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
	 m : WM.WindowManager;
BEGIN {EXCLUSIVE}
	NEW(die);
	msg.ext := die;
	msg.msgType := WMMessages.MsgExt;
	m := WM.GetDefaultManager();
	m.Broadcast(msg);
	AWAIT(nofWindows = 0)
END Cleanup;

BEGIN
	Modules.InstallTermHandler(Cleanup)
END BimboMail.

BimboMail.Open ~
System.Free BimboMail MailStorage POP3Client ~

PET.Open MailStorage.Mod ~
PET.Open POP3Client.Mod ~
