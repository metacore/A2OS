MODULE WMUnicodeMarkerTool;	(** AUTHOR "gubsermi"; PURPOSE "Unicode Marker Tool"; *)


IMPORT
	Strings, WMComponents, WMRestorable, WMCharMap, WMMessages,
	WMStandardComponents, WMTextView, Modules, WM := WMWindowManager,
	XML, UnicodeBidirectionality;

CONST
	AlignLeft = 0; AlignCenter = 1; AlignRight = 2; AlignJustified = 3;
	StyleRegular = 0; StyleBold = 1; StyleItalic = 2; StyleBoldItalic = 3;

TYPE
	KillerMsg = OBJECT
	END KillerMsg;

	ContextMenuData = OBJECT
	VAR val: SIGNED32;
		PROCEDURE &New*(val: SIGNED32);
		BEGIN
			SELF.val := val;
		END New;
	END ContextMenuData;

	Window* = OBJECT (WMComponents.FormWindow)
	VAR
		leftRightMarkerButton, rightLeftMarkerButton, zeroWidthJoinerButton, zeroWidthNonJoinerButton,
		leftRightEmbeddingButton, rightLeftEmbeddingButton, leftRightOverrideButton, rightLeftOverrideButton,
		popDirectionalFormatButton, otherMarkerButton, displayMarkersButton, focusButton: WMStandardComponents.Button;
		winpanel : WMStandardComponents.Panel;

		PROCEDURE CreateForm(): WMComponents.VisualComponent;
		VAR
			panel : WMStandardComponents.Panel;
			toolbar: WMStandardComponents.Panel;

			PROCEDURE AB(panel : WMStandardComponents.Panel; btn: WMStandardComponents.Button);
			BEGIN
				btn.alignment.Set(WMComponents.AlignLeft); btn.bounds.SetWidth(60); panel.AddContent(btn)
			END AB;

		BEGIN
			NEW(panel); panel.bounds.SetExtents(120, 140); panel.takesFocus.Set(TRUE);


			(* styles *)
			(**)
			NEW(toolbar); toolbar.bounds.SetHeight(20); toolbar.alignment.Set(WMComponents.AlignTop);
			panel.AddContent(toolbar);
			NEW(leftRightMarkerButton); leftRightMarkerButton.caption.SetAOC("LRM"); AB(toolbar, leftRightMarkerButton);
			NEW(rightLeftMarkerButton); rightLeftMarkerButton.caption.SetAOC("RLM"); AB(toolbar, rightLeftMarkerButton);

			(**)
			NEW(toolbar); toolbar.bounds.SetHeight(20); toolbar.alignment.Set(WMComponents.AlignTop);
			panel.AddContent(toolbar);
			NEW(zeroWidthJoinerButton); zeroWidthJoinerButton.caption.SetAOC("ZWJ"); AB(toolbar, zeroWidthJoinerButton);
			NEW(zeroWidthNonJoinerButton); zeroWidthNonJoinerButton.caption.SetAOC("ZWNJ"); AB(toolbar, zeroWidthNonJoinerButton);

			(**)
			NEW(toolbar); toolbar.bounds.SetHeight(20); toolbar.alignment.Set(WMComponents.AlignTop);
			panel.AddContent(toolbar);
			NEW(leftRightEmbeddingButton); leftRightEmbeddingButton.caption.SetAOC("LRE"); AB(toolbar, leftRightEmbeddingButton);
			NEW(rightLeftEmbeddingButton); rightLeftEmbeddingButton.caption.SetAOC("RLE"); AB(toolbar, rightLeftEmbeddingButton);

			(**)
			NEW(toolbar); toolbar.bounds.SetHeight(20); toolbar.alignment.Set(WMComponents.AlignTop);
			panel.AddContent(toolbar);
			NEW(leftRightOverrideButton); leftRightOverrideButton.caption.SetAOC("LRO"); AB(toolbar, leftRightOverrideButton);
			NEW(rightLeftOverrideButton); rightLeftOverrideButton.caption.SetAOC("RLO"); AB(toolbar, rightLeftOverrideButton);

			(**)
			NEW(toolbar); toolbar.bounds.SetHeight(20); toolbar.alignment.Set(WMComponents.AlignTop);
			panel.AddContent(toolbar);
			NEW(popDirectionalFormatButton); popDirectionalFormatButton.caption.SetAOC("PDF"); AB(toolbar, popDirectionalFormatButton);
			NEW(otherMarkerButton); otherMarkerButton.caption.SetAOC("other"); AB(toolbar, otherMarkerButton);

			(**)
			NEW(toolbar); toolbar.bounds.SetHeight(20); toolbar.alignment.Set(WMComponents.AlignTop);
			panel.AddContent(toolbar);
			NEW(displayMarkersButton);
			IF UnicodeBidirectionality.showUnicodeControlCharacters THEN
				displayMarkersButton.caption.SetAOC("hide markers");
			ELSE
				displayMarkersButton.caption.SetAOC("show markers");
			END;
			displayMarkersButton.alignment.Set(WMComponents.AlignLeft);
			displayMarkersButton.bounds.SetWidth(120);
			toolbar.AddContent(displayMarkersButton);

			(**)
			NEW(toolbar); toolbar.bounds.SetHeight(20); toolbar.alignment.Set(WMComponents.AlignTop);
			panel.AddContent(toolbar);
			NEW(focusButton); focusButton.caption.SetAOC("focus");
			focusButton.alignment.Set(WMComponents.AlignLeft);
			focusButton.bounds.SetWidth(120);
			toolbar.AddContent(focusButton);

			winpanel := panel;
			RETURN panel
		END CreateForm;

		PROCEDURE &New*(c : WMRestorable.Context);
		VAR
			vc : WMComponents.VisualComponent;
		BEGIN
			IncCount;
			vc := CreateForm();

			leftRightMarkerButton.onClick.Add(InsertMarker);
			rightLeftMarkerButton.onClick.Add(InsertMarker);
			zeroWidthJoinerButton.onClick.Add(InsertMarker);
			zeroWidthNonJoinerButton.onClick.Add(InsertMarker);
			leftRightEmbeddingButton.onClick.Add(InsertMarker);
			rightLeftEmbeddingButton.onClick.Add(InsertMarker);
			leftRightOverrideButton.onClick.Add(InsertMarker);
			rightLeftOverrideButton.onClick.Add(InsertMarker);
			popDirectionalFormatButton.onClick.Add(InsertMarker);
			displayMarkersButton.onClick.Add(ChangeVisibility);
			otherMarkerButton.onClick.Add(OpenUnicodeMap);

			Init(vc.bounds.GetWidth(), vc.bounds.GetHeight(), TRUE);
			SetContent(vc);

			IF c # NIL THEN
				WMRestorable.AddByContext(SELF, c);
				Resized(GetWidth(), GetHeight());
			ELSE
				WM.ExtAddWindow(SELF, 50, 50, {WM.FlagStayOnTop, WM.FlagFrame, WM.FlagClose, WM.FlagMinimize});
			END;
			SetTitle(Strings.NewString("Unicode Markers"));
		END New;

		(* -- Handlers -- *)

		(* Opens a map with all Unicode characters *)
		PROCEDURE OpenUnicodeMap(sender, data : ANY);
		BEGIN
			WMCharMap.Open;
		END OpenUnicodeMap;

		(* Switches the markers' visibility on and off *)
		PROCEDURE ChangeVisibility(sender, data : ANY);
		BEGIN
			IF UnicodeBidirectionality.showUnicodeControlCharacters THEN
				UnicodeBidirectionality.showUnicodeControlCharacters := FALSE;
				displayMarkersButton.caption.SetAOC("show markers");
			ELSE
				UnicodeBidirectionality.showUnicodeControlCharacters := TRUE;
				displayMarkersButton.caption.SetAOC("hide markers");
			END;
			WMTextView.Refresh;
		END ChangeVisibility;

		(* Insert a certain marker into the currently active text *)
		PROCEDURE InsertMarker(sender, data : ANY);
		VAR
			res : SIGNED16;
		BEGIN
			IF sender = leftRightMarkerButton THEN
				res := WMTextView.InsertChar(200EH);
			ELSIF sender = rightLeftMarkerButton THEN
				res := WMTextView.InsertChar(200FH);
			ELSIF sender = zeroWidthJoinerButton THEN
				res := WMTextView.InsertChar(200DH);
			ELSIF sender = zeroWidthNonJoinerButton THEN
				res := WMTextView.InsertChar(200CH);
			ELSIF sender = leftRightEmbeddingButton THEN
				res := WMTextView.InsertChar(202AH);
			ELSIF sender = rightLeftEmbeddingButton THEN
				res := WMTextView.InsertChar(202BH);
			ELSIF sender = leftRightOverrideButton THEN
				res := WMTextView.InsertChar(202DH);
			ELSIF sender = rightLeftOverrideButton THEN
				res := WMTextView.InsertChar(202EH);
			ELSIF sender = popDirectionalFormatButton THEN
				res := WMTextView.InsertChar(202CH);
			END;

			IF res = 0 THEN
				focusButton.clDefault.Set(0CC0080H);
				focusButton.caption.SetAOC("");
			ELSE
				focusButton.clDefault.Set(0CC000080H);
				IF res = -1 THEN
					focusButton.caption.SetAOC("bad format");
				ELSIF res = -2 THEN
					focusButton.caption.SetAOC("no text");
				ELSE
					focusButton.caption.SetAOC("no textview");
				END;
			END;
		END InsertMarker;

		(* Closes the current instance of the Unicode Marker Tool *)
		PROCEDURE Close*;
		BEGIN
			Close^;
			DecCount
		END Close;

		(* Handles messages/events *)
		PROCEDURE Handle*(VAR x: WMMessages.Message);
		VAR
			data : XML.Element;
			name : ARRAY 32 OF CHAR;
		BEGIN
			IF (x.msgType = WMMessages.MsgExt) & (x.ext # NIL) THEN
				IF (x.ext IS KillerMsg) THEN
					Close
				ELSIF (x.ext IS WMRestorable.Storage) THEN
					NEW(data);  name := "UnicodeMarkerToolData"; data.SetName(name);
					x.ext(WMRestorable.Storage).Add("WMUnicodeMarkerTool", "WMUnicodeMarkerTool.Restore", SELF, data);
				ELSE
					Handle^(x);
				END
			ELSE
				Handle^(x)
			END
		END Handle;

	END Window;


VAR
	nofWindows : SIGNED32;
	ctxAlignLeft, ctxAlignCenter, ctxAlignRight, ctxAlignJustified : ContextMenuData;
	ctxRegular, ctxBold, ctxItalic, ctxBoldItalic : ContextMenuData;


(* Opens a new instance of the Unicode Marker Tool *)
PROCEDURE Open*;
VAR winstance : Window;
BEGIN
	NEW(winstance, NIL);
END Open;

(* Restores an instance of the Unicode Marker Tool *)
PROCEDURE Restore*(context : WMRestorable.Context);
VAR w : Window;
BEGIN
	NEW(w, context);
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
	NEW(ctxAlignLeft, AlignLeft);
	NEW(ctxAlignCenter, AlignCenter);
	NEW(ctxAlignRight, AlignRight);
	NEW(ctxAlignJustified, AlignJustified);
	NEW(ctxRegular, StyleRegular);
	NEW(ctxBold, StyleBold);
	NEW(ctxItalic, StyleItalic);
	NEW(ctxBoldItalic, StyleBoldItalic);

	Modules.InstallTermHandler(Cleanup)
END WMUnicodeMarkerTool.

System.Free WMUnicodeMarkerTool~
WMUnicodeMarkerTool.Open  ~




