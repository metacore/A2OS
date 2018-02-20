MODULE WMInputMethodTool;	(** AUTHOR "gubsermi"; PURPOSE "Input Method Tool"; *)


IMPORT
	Modules, Texts, Strings, XML, WMComponents, WMInputMethods, WMArabicIME, WMRussianIME, WMUkrainianIME,
	WMArmenianIME, WMHebrewIME, WMPinyinIME, WMUnicodeIME, WMGraphics, WMRestorable,
	WMMessages, WMStandardComponents, WM := WMWindowManager;

CONST
	(* currentUtfState *)
	DefaultBidi = 1;
	ForceBidi = 2;
	UnforceBidi = 3;

	ColorIMESelected = WMGraphics.Yellow;
	ColorIMEActive = WMGraphics.Green;

TYPE
	KillerMsg = OBJECT
	END KillerMsg;

	Window* = OBJECT (WMComponents.FormWindow)
	VAR
		arabicButton, russianButton, ukrainianButton, armenianButton, hebrewButton, pinyinButton, unicodeButton,
		noIMEButton, switchIMEButton, utfModeButton : WMStandardComponents.Button;
		currentIME : ARRAY 32 OF CHAR;
		currentUtfState : LONGINT;

		PROCEDURE CreateForm(): WMComponents.VisualComponent;
		VAR
			panel : WMStandardComponents.Panel;

			PROCEDURE AddButton(VAR button : WMStandardComponents.Button; CONST caption : ARRAY OF CHAR; panel : WMStandardComponents.Panel);
			BEGIN
				NEW(button);
				button.caption.SetAOC(caption);
				button.alignment.Set(WMComponents.AlignTop); button.bounds.SetHeight(20); panel.AddContent(button)
			END AddButton;

		BEGIN
			NEW(panel); panel.bounds.SetExtents(90, 200); panel.takesFocus.Set(TRUE);

			AddButton(arabicButton, "Arabic", panel); arabicButton.useBgBitmaps.Set(FALSE);
			AddButton(armenianButton, "Armenian", panel); armenianButton.useBgBitmaps.Set(FALSE);
			AddButton(russianButton, "Russian", panel); russianButton.useBgBitmaps.Set(FALSE);
			AddButton(ukrainianButton, "Ukrainian", panel); ukrainianButton.useBgBitmaps.Set(FALSE);
			AddButton(hebrewButton, "Hebrew", panel); hebrewButton.useBgBitmaps.Set(FALSE);
			AddButton(pinyinButton, "Pinyin", panel); pinyinButton.useBgBitmaps.Set(FALSE);
			AddButton(unicodeButton, "Unicode", panel); unicodeButton.useBgBitmaps.Set(FALSE);

			AddButton(noIMEButton, "No IME", panel);
			AddButton(switchIMEButton, "Switch IME on", panel);
			AddButton(utfModeButton, "Default Bidi", panel);

			RETURN panel
		END CreateForm;


		PROCEDURE &New*(c : WMRestorable.Context);
		VAR vc : WMComponents.VisualComponent;
			xml : XML.Element;
			 s : Strings.String;
		BEGIN
			IncCount;
			vc := CreateForm();

			arabicButton.onClick.Add(ChangeIME);
			russianButton.onClick.Add(ChangeIME);
			ukrainianButton.onClick.Add(ChangeIME);
			armenianButton.onClick.Add(ChangeIME);
			hebrewButton.onClick.Add(ChangeIME);
			pinyinButton.onClick.Add(ChangeIME);
			unicodeButton.onClick.Add(ChangeIME);
			noIMEButton.onClick.Add(ChangeIME);
			switchIMEButton.onClick.Add(SwitchIME);
			utfModeButton.onClick.Add(SetUtfMode);

			IF Texts.forceUTF & ~Texts.unforceUTF THEN
				utfModeButton.caption.SetAOC("Force Bidi");
				currentUtfState := ForceBidi;
			ELSIF ~Texts.forceUTF & Texts.unforceUTF THEN
				utfModeButton.caption.SetAOC("Unforce Bidi");
				currentUtfState := UnforceBidi;
			ELSE (* force default bidi *)
				utfModeButton.caption.SetAOC("Default Bidi");
				currentUtfState := DefaultBidi;
			END;

			Init(vc.bounds.GetWidth(), vc.bounds.GetHeight(), TRUE);
			SetContent(vc);

			IF c # NIL THEN
				WMRestorable.AddByContext(SELF, c);
				IF c.appData # NIL THEN
					xml := c.appData(XML.Element);
					s := xml.GetAttributeValue("ime");
					IF s # NIL THEN
						IF s^ = WMArabicIME.imeName THEN
							ChangeIME(arabicButton,NIL);
						ELSIF s^ = WMRussianIME.imeName THEN
							ChangeIME(russianButton,NIL);
						ELSIF s^ = WMUkrainianIME.imeName THEN
							ChangeIME(ukrainianButton, NIL);
						ELSIF s^ = WMArmenianIME.imeName THEN
							ChangeIME(armenianButton,NIL);
						ELSIF s^ = WMHebrewIME.imeName THEN
							ChangeIME(hebrewButton,NIL);
						ELSIF s^ = WMPinyinIME.imeName THEN
							ChangeIME(pinyinButton,NIL);
						ELSIF s^ = WMUnicodeIME.imeName THEN
							ChangeIME(unicodeButton,NIL);
						ELSIF s^ = "none" THEN
							ChangeIME(noIMEButton,NIL);
						END;
					END;
				END;
				Resized(GetWidth(), GetHeight());
			ELSE
				WM.ExtAddWindow(SELF, 50, 50, {WM.FlagStayOnTop, WM.FlagFrame, WM.FlagClose, WM.FlagMinimize})
			 END;
			SetTitle(Strings.NewString("Input Methods"));

			GETPROCEDURE("WMInputMethodTool","ChangeAppearance",WMInputMethods.toolSwitch);
		END New;

		(* -- Handlers -- *)

		PROCEDURE ResetButtonColors;
		BEGIN
			arabicButton.clDefault.Reset;
			russianButton.clDefault.Reset;
			ukrainianButton.clDefault.Reset;
			armenianButton.clDefault.Reset;
			hebrewButton.clDefault.Reset;
			pinyinButton.clDefault.Reset;
			unicodeButton.clDefault.Reset;
			noIMEButton.clDefault.Reset;
		END ResetButtonColors;

		(* Switches the current IME to the new one.
			The new IME's name is taken to identify its installer. Some colors are changed and finally the installer is called. *)
		PROCEDURE ChangeIME(sender, data : ANY);
		VAR
			res : LONGINT;
			install : WMInputMethods.IMEInstaller;
		BEGIN
			res := -1;
			ResetButtonColors;

			IF sender = arabicButton THEN
				currentIME := WMArabicIME.imeName;
				install := WMInputMethods.GetIME(currentIME,res);
				IF WMInputMethods.activeIME = NIL THEN
					arabicButton.clDefault.Set(ColorIMESelected);
				ELSE
					arabicButton.clDefault.Set(ColorIMEActive);
				END;

			ELSIF sender = russianButton THEN
				currentIME := WMRussianIME.imeName;
				install := WMInputMethods.GetIME(currentIME,res);
				IF WMInputMethods.activeIME = NIL THEN
					russianButton.clDefault.Set(ColorIMESelected);
				ELSE
					russianButton.clDefault.Set(ColorIMEActive);
				END;

			ELSIF sender = ukrainianButton THEN
				currentIME := WMUkrainianIME.imeName;
				install := WMInputMethods.GetIME(currentIME,res);
				IF WMInputMethods.activeIME = NIL THEN
					ukrainianButton.clDefault.Set(ColorIMESelected);
				ELSE
					ukrainianButton.clDefault.Set(ColorIMEActive);
				END;

			ELSIF sender = armenianButton THEN
				currentIME := WMArmenianIME.imeName;
				install := WMInputMethods.GetIME(currentIME,res);
				IF WMInputMethods.activeIME = NIL THEN
					armenianButton.clDefault.Set(ColorIMESelected);
				ELSE
					armenianButton.clDefault.Set(ColorIMEActive);
				END;

			ELSIF sender = hebrewButton THEN
				currentIME := WMHebrewIME.imeName;
				install := WMInputMethods.GetIME(currentIME,res);
				IF WMInputMethods.activeIME = NIL THEN
					hebrewButton.clDefault.Set(ColorIMESelected);
				ELSE
					hebrewButton.clDefault.Set(ColorIMEActive);
				END;

			ELSIF sender = pinyinButton THEN
				currentIME := WMPinyinIME.imeName;
				install := WMInputMethods.GetIME(currentIME,res);
				IF WMInputMethods.activeIME = NIL THEN
					pinyinButton.clDefault.Set(ColorIMESelected);
				ELSE
					pinyinButton.clDefault.Set(ColorIMEActive);
				END;

			ELSIF sender = unicodeButton THEN
				currentIME := WMUnicodeIME.imeName;
				install := WMInputMethods.GetIME(currentIME,res);
				IF WMInputMethods.activeIME = NIL THEN
					unicodeButton.clDefault.Set(ColorIMESelected);
				ELSE
					unicodeButton.clDefault.Set(ColorIMEActive);
				END;

			ELSIF sender = noIMEButton THEN

				currentIME := "";
				noIMEButton.clDefault.Set(ColorIMESelected);

			END;

			IF res = 0 THEN
				install;
			ELSE
				WMInputMethods.InstallIME(NIL);
			END;

		END ChangeIME;

		(* Switches the current IME on or off *)
		PROCEDURE SwitchIME(sender, data : ANY);
		VAR
			dummyIME : WMInputMethods.IME;
		BEGIN
			dummyIME := WMInputMethods.SwitchIME();
		END SwitchIME;

		(* Cycles the through the utf modes for newly opened texts *)
		PROCEDURE SetUtfMode(sender, data : ANY);
		BEGIN
			IF currentUtfState = DefaultBidi THEN
				utfModeButton.caption.SetAOC("Force Bidi");
				Texts.forceUTF := TRUE;
				Texts.unforceUTF := FALSE;
				currentUtfState := ForceBidi;
			ELSIF currentUtfState = ForceBidi THEN
				utfModeButton.caption.SetAOC("Unforce Bidi");
				Texts.forceUTF := FALSE;
				Texts.unforceUTF := TRUE;
				currentUtfState := UnforceBidi;
			ELSE
				utfModeButton.caption.SetAOC("Default Bidi");
				Texts.forceUTF := FALSE;
				Texts.unforceUTF := FALSE;
				currentUtfState := DefaultBidi;
			END;
		END SetUtfMode;

		(* Updates the appearance according to the most resent changes. *)
		PROCEDURE ChangeAppearance;
		VAR
			thisIME : WMInputMethods.IME;
		BEGIN
			thisIME := WMInputMethods.activeIME;
			IF currentIME = WMArabicIME.imeName THEN
				IF thisIME = NIL THEN
					arabicButton.clDefault.Set(ColorIMESelected);
					switchIMEButton.caption.SetAOC("Switch IME on");
				ELSE
					arabicButton.clDefault.Set(ColorIMEActive);
					switchIMEButton.caption.SetAOC("Switch IME off");
				END;

			ELSIF currentIME = WMRussianIME.imeName THEN
				IF thisIME = NIL THEN
					russianButton.clDefault.Set(ColorIMESelected);
					switchIMEButton.caption.SetAOC("Switch IME on");
				ELSE
					russianButton.clDefault.Set(ColorIMEActive);
					switchIMEButton.caption.SetAOC("Switch IME off");
				END;

			ELSIF currentIME = WMUkrainianIME.imeName THEN
				IF thisIME = NIL THEN
					ukrainianButton.clDefault.Set(ColorIMESelected);
					switchIMEButton.caption.SetAOC("Switch IME on");
				ELSE
					ukrainianButton.clDefault.Set(ColorIMEActive);
					switchIMEButton.caption.SetAOC("Switch IME off");
				END;

			ELSIF currentIME = WMArmenianIME.imeName THEN
				IF thisIME = NIL THEN
					armenianButton.clDefault.Set(ColorIMESelected);
					switchIMEButton.caption.SetAOC("Switch IME on");
				ELSE
					armenianButton.clDefault.Set(ColorIMEActive);
					switchIMEButton.caption.SetAOC("Switch IME off");
				END;

			ELSIF currentIME = WMHebrewIME.imeName THEN
				IF thisIME = NIL THEN
					hebrewButton.clDefault.Set(ColorIMESelected);
					switchIMEButton.caption.SetAOC("Switch IME on");
				ELSE
					hebrewButton.clDefault.Set(ColorIMEActive);
					switchIMEButton.caption.SetAOC("Switch IME off");
				END;

			ELSIF currentIME = WMPinyinIME.imeName THEN
				IF thisIME = NIL THEN
					pinyinButton.clDefault.Set(ColorIMESelected);
					switchIMEButton.caption.SetAOC("Switch IME on");
				ELSE
					pinyinButton.clDefault.Set(ColorIMEActive);
					switchIMEButton.caption.SetAOC("Switch IME off");
				END;

			ELSIF currentIME = WMUnicodeIME.imeName THEN
				IF thisIME = NIL THEN
					unicodeButton.clDefault.Set(ColorIMESelected);
					switchIMEButton.caption.SetAOC("Switch IME on");
				ELSE
					unicodeButton.clDefault.Set(ColorIMEActive);
					switchIMEButton.caption.SetAOC("Switch IME off");
				END;

			ELSIF currentIME = "" THEN
				noIMEButton.clDefault.Set(ColorIMESelected);
				switchIMEButton.caption.SetAOC("Switch IME on");

			END;
		END ChangeAppearance;

		(* Closes this instance of the Input Method Tool. *)
		PROCEDURE Close*;
		BEGIN
			Close^;
			DecCount
		END Close;

		(* Handles messages/events *)
		PROCEDURE Handle*(VAR x: WMMessages.Message);
		VAR
			data : XML.Element;
			a : XML.Attribute;
			n: ARRAY 32 OF CHAR;
			str : Strings.String;
		BEGIN
			IF (x.msgType = WMMessages.MsgExt) & (x.ext # NIL) THEN
				IF (x.ext IS KillerMsg) THEN Close
				ELSIF (x.ext IS WMRestorable.Storage) THEN
					NEW(data);
					n := "InputMethodToolData";
					data.SetName(n);
					NEW(a);
					n := "ime";
					a.SetName(n);
					IF WMInputMethods.defaultIME # NIL THEN
						str := WMInputMethods.defaultIME.GetName();
					ELSE
						str := Strings.NewString("none");
					END;
					a.SetValue(str^);
					data.AddAttribute(a);
					x.ext(WMRestorable.Storage).Add("WMInputMethodTool", "WMInputMethodTool.Restore", SELF, data);
				ELSE
					Handle^(x)
				END
			ELSE
				Handle^(x)
			END
		END Handle;

	END Window;

VAR
	nofWindows : LONGINT;
	currentWindow : Window;

(* used as a callback procedure of WMInputMethods *)
PROCEDURE ChangeAppearance*;
BEGIN
	currentWindow.ChangeAppearance;
END ChangeAppearance;

(* opens a new instance of the Input Method Tool *)
PROCEDURE Open*;
VAR
	winstance : Window;
BEGIN
	NEW(winstance, NIL);
	currentWindow := winstance;
END Open;

(* restores an instance of the Input Method Tool *)
PROCEDURE Restore*(context : WMRestorable.Context);
VAR
	winstance : Window;
BEGIN
	NEW(winstance, context);
	currentWindow := winstance;
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
VAR
	die : KillerMsg;
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
END WMInputMethodTool.

SystemTools.Free WMInputMethodTool ~
WMInputMethodTool.Open  ~



