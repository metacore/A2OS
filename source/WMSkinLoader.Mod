MODULE WMSkinLoader;	(** AUTHOR "ug"; December 1, 2005 *)

IMPORT
	Commands, Modules, WMComponents, WMStandardComponents,
	Strings, UTF8Strings, Files,
	Looks, KernelLog,
	WM := WMWindowManager;

CONST
	Toleft = 300;
	Fromtop = 400;
	PanelWidth = 100;
	ButtonHeight = 20;

TYPE
	Window=OBJECT (WMComponents.FormWindow);
	VAR
		nofLooks : LONGINT;
		nextINchain : Window;
		buttonArr : POINTER TO ARRAY OF WMStandardComponents.Button;
		lookList : Looks.LookList;

		PROCEDURE &New *(lookList : Looks.LookList);
		VAR
			panel : WMStandardComponents.Panel;
			i : LONGINT;
			look : Looks.Look;
		BEGIN
			ASSERT((lookList # NIL) & (lookList.GetCount() > 0));
			SELF.lookList := lookList;
			nofLooks := lookList.GetCount ();

			NEW (panel);
			panel.bounds.SetWidth (PanelWidth);
			panel.bounds.SetHeight (nofLooks * ButtonHeight);

			NEW(buttonArr, nofLooks);
			FOR i := 0 TO nofLooks-1 DO
				NEW(buttonArr[i]);
				look := lookList.GetItem (i);
				buttonArr[i].caption.SetAOC(look.name); buttonArr[i].alignment.Set(WMComponents.AlignTop);
				buttonArr[i].bounds.SetWidth(PanelWidth); buttonArr[i].bounds.SetHeight(ButtonHeight);
				buttonArr[i].onClick.Add(LoadSkin);
				panel.AddContent(buttonArr[i]);
			END;

			Init (panel.bounds.GetWidth (), panel.bounds.GetHeight (), TRUE);
			SetContent (panel);

			WM.AddWindow (SELF, Toleft, Fromtop);
			manager := WM.GetDefaultManager();
			manager.SetFocus(SELF);
			SetTitle (WM.NewString ("SkinLoader"));

			nextINchain := windows;
			windows := SELF
		END New;

		PROCEDURE FindSender(sender : WMStandardComponents.Button; VAR index : LONGINT);
		VAR i : LONGINT;
		BEGIN
			i := 0;
			WHILE (i < nofLooks) & (buttonArr[i] # sender) DO INC(i) END;
			IF i < nofLooks THEN index := i ELSE index := -1 END
		END FindSender;

		PROCEDURE LoadSkin(sender, data : ANY);
		VAR look : Looks.Look;
			cmd, msg : ARRAY 128 OF CHAR;
			index: LONGINT; res: WORD;
		BEGIN
			IF sender IS WMStandardComponents.Button THEN
				FindSender(sender(WMStandardComponents.Button), index);
				IF index >= 0 THEN
					look := lookList.GetItem(index);
					IF (UTF8Strings.Compare(look.name, "ZeroSkin") = UTF8Strings.CmpEqual) THEN
						cmd := "SkinEngine.Unload";
					ELSE
						Strings.Concat("SkinEngine.Load ", look.file, cmd);
					END;
					Commands.Call(cmd, {}, res, msg);
					IF res # 0 THEN KernelLog.Enter; KernelLog.String(msg); KernelLog.Exit END
				END
			END
		END LoadSkin;

		PROCEDURE Close*;
		BEGIN
			Close^;
			FreeWindow(SELF)
		END Close;

	END Window;

VAR
	windows : Window;

PROCEDURE FreeWindow(free : Window);
VAR
	win : Window;
BEGIN
	IF free = windows THEN
		windows := windows.nextINchain
	ELSE
		win := windows;
		WHILE (win # NIL) & (win.nextINchain # free) DO
			win := win.nextINchain
		END;
		IF win # NIL THEN
			win.nextINchain := free.nextINchain
		END
	END
END FreeWindow;

PROCEDURE Open*(context : Commands.Context);
VAR win: Window; filename : Files.FileName; lookList : Looks.LookList;
BEGIN
	context.arg.SkipWhitespace; context.arg.String(filename);
	Looks.LoadLooks(filename, lookList);
	IF (lookList.GetCount() > 0) THEN
		NEW(win, lookList);
	ELSE
		context.out.String("WMSkinLoader: No looks found in file '");
		context.out.String(filename); context.out.String("'");
		context.out.Ln;
	END;
END Open;

PROCEDURE Cleanup;
BEGIN
	WHILE windows # NIL DO
		windows.Close();
	END
END Cleanup;

BEGIN
	Modules.InstallTermHandler(Cleanup)
END WMSkinLoader.

System.Free WMSkinLoader Looks ~
WMSkinLoader.Open SkinList.XML ~


