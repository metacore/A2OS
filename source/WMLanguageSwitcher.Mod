MODULE WMLanguageSwitcher; (** AUTHOR "Yaroslav Romanchenko rapturize@gmail.com"; PURPOSE "Simple GUI language switcher"; *)

IMPORT
	Commands, Options, Localization, Repositories, Strings, Modules,
	WMComponents, WMMessages, WMWindowManager, WMStandardComponents;
	
CONST
	Toleft = 300;
	Fromtop = 400;
	PanelWidth = 100;
	ButtonHeight = 20;
	
(*TYPE
	String = Strings.String;
	Chars = ARRAY OF CHAR;
	
OPERATOR "+"(CONST a1, a2: Chars): String;
VAR str: String;
BEGIN
	NEW(str, Strings.Length(a1) + Strings.Length(a2) + 1);
	Strings.Concat(a1, a2, str^);
	RETURN str
END "+";*)

TYPE

	Window=OBJECT (WMComponents.FormWindow);
	VAR
		nofLanguages : SIZE;
		nextINchain: Window;
		buttonArr: POINTER TO ARRAY OF WMStandardComponents.Button;
		languages: Localization.Languages;

		PROCEDURE &New*(languages: Localization.Languages);
		VAR
			panel: WMStandardComponents.Panel;
			i: SIZE;
			language: Localization.Language;
		BEGIN
			ASSERT(languages # NIL);
			SELF.languages := languages;
			nofLanguages := LEN(languages^);
			NEW (panel);
			panel.bounds.SetWidth (PanelWidth);
			panel.bounds.SetHeight (nofLanguages * ButtonHeight);

			NEW(buttonArr, nofLanguages);
			FOR i := 0 TO nofLanguages-1 DO
				NEW(buttonArr[i]);
				language := languages^[i];
				(*buttonArr[i].caption.Set("::System:Strings:S" + language.code);*)
				buttonArr[i].caption.SetAOC(language.code);
				buttonArr[i].alignment.Set(WMComponents.AlignTop);
				buttonArr[i].bounds.SetWidth(PanelWidth); buttonArr[i].bounds.SetHeight(ButtonHeight);
				buttonArr[i].onClick.Add(SetLanguage);
				panel.AddContent(buttonArr[i]);
			END;

			Init (panel.bounds.GetWidth (), panel.bounds.GetHeight (), TRUE);
			SetContent (panel);

			WMWindowManager.AddWindow (SELF, Toleft, Fromtop);
			manager := WMWindowManager.GetDefaultManager();
			manager.SetFocus(SELF);
			
			(*SetTitle(Strings.NewString("::StartMenu:ButtonTitles:SLanguage"));*)
			SetTitle(Strings.NewString("Language"));

			nextINchain := windows;
			windows := SELF
		END New;

		PROCEDURE FindSender(sender : WMStandardComponents.Button; VAR index : SIGNED32);
		VAR i : SIGNED32;
		BEGIN
			i := 0;
			WHILE (i < nofLanguages) & (buttonArr[i] # sender) DO INC(i) END;
			IF i < nofLanguages THEN index := i ELSE index := -1 END
		END FindSender;

		PROCEDURE SetLanguage(sender, data : ANY);
		VAR
			language: Localization.Language;
			index: SIGNED32;
		BEGIN
			IF sender IS WMStandardComponents.Button THEN
				FindSender(sender(WMStandardComponents.Button), index);
				IF index >= 0 THEN
					language := languages^[index];
					SetLanguageInternal(language)
				END
			END
		END SetLanguage;

		PROCEDURE Close*;
		BEGIN
			Close^;
			FreeWindow (SELF)
		END Close;

	END Window;

VAR
	windows : Window;

PROCEDURE FreeWindow(free : Window);
VAR
	winstance : Window;
BEGIN
	IF free = windows THEN
		windows := windows.nextINchain
	ELSE
		winstance := windows;
		WHILE (winstance # NIL) & (winstance.next # free) DO
			winstance := winstance.nextINchain
		END;
		IF winstance # NIL THEN
			winstance.nextINchain := free.nextINchain
		END
	END
END FreeWindow;

PROCEDURE Open*(context: Commands.Context);
VAR
	winstance: Window;
	languages: Localization.Languages;	
BEGIN
	languages := GetLanguages();
	IF (languages # NIL) THEN
		NEW(winstance, languages);
	ELSE
		context.out.String("WMLanguageSwitcher: No thanslations present.");
		context.out.Ln
	END
END Open;

PROCEDURE Cleanup;
BEGIN
	WHILE windows # NIL DO
		windows.Close ();
	END
END Cleanup;

PROCEDURE SetLanguageInternal(language: Localization.Language);
VAR
	extension: WMComponents.LanguageExtension;
	message: WMMessages.Message;
	manager: WMWindowManager.WindowManager;
BEGIN
	Localization.SetLanguage(language);
	message.msgType := WMMessages.MsgSetLanguage;
	NEW(extension);
	NEW(extension.languages, 1);
	extension.languages[0] := language;
	message.ext := extension;
	manager := WMWindowManager.GetDefaultManager();
	manager.Broadcast(message)
END SetLanguageInternal;
		
PROCEDURE SetLanguage*(ctx: Commands.Context);
VAR
	options: Options.Options;
	languages: Localization.Languages;
	language: Localization.Language;
	i: SIZE;
BEGIN
	languages := GetLanguages();
	IF languages = NIL THEN
		ctx.out.String("WMLanguageSwitcher: No thanslations present.")
	ELSE
		NEW(options);
		options.Add("l", "lang", Options.String);
		IF options.Parse(ctx.arg, ctx.out) & options.GetString("lang", language.code) THEN
			Strings.LowerCase(language.code);
			i := 0;
			WHILE (i < LEN(languages^)) & (languages^[i].code # language.code) DO
				INC(i)
			END;
			IF i >= LEN(languages^) THEN
				ctx.out.String("WMLanguageSwitcher: There are no thanslations for language: ");
				ctx.out.String(language.code)
			ELSE
				ctx.out.String("WMLanguageSwitcher: Setting language: ");
				ctx.out.String(language.code);
				SetLanguageInternal(language)
			END
		ELSE
			ctx.out.String("WMLanguageSwitcher: Error: Language code expected.")
		END
	END;
	ctx.out.Ln
END SetLanguage;

PROCEDURE GetLanguages*(): Localization.Languages;
VAR
	dictionary: Repositories.Dictionary;
	res: INTEGER;
BEGIN
	(* Just try to open some dictionary in assumption that all dictionaries has translations for all languages *)
	Repositories.GetDictionary("StartMenu", "ButtonTitles", dictionary, res);
	IF res = Repositories.Ok THEN
		RETURN dictionary.GetLanguages()
	ELSE
		RETURN NIL
	END
END GetLanguages;

BEGIN
	Modules.InstallTermHandler (Cleanup)
END WMLanguageSwitcher.

WMLanguageSwitcher.Open ~

WMLanguageSwitcher.SetLanguage -l=en ~
WMLanguageSwitcher.SetLanguage -l=ru ~
WMLanguageSwitcher.SetLanguage -l=uk ~
WMLanguageSwitcher.SetLanguage -l=de ~

System.Free WMLanguageSwitcher ~