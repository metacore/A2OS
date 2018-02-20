MODULE WMObjectTracker; (** AUTHOR "tf/staubesv"; PURPOSE "Visualize active objects"; *)

IMPORT
	Modules, Commands, Strings,
	WMGraphics, WMComponents, WMProcessInfo, WMMessages, WMRestorable, WM := WMWindowManager;

CONST

	(* Window size at startup *)
	DefaultWidth = 800; DefaultHeight = 400;

TYPE

	Window = OBJECT (WMComponents.FormWindow)
	VAR
		processManager : WMProcessInfo.ProcessManager;

		PROCEDURE &New*(c : WMRestorable.Context);
		BEGIN
			Init(DefaultWidth, DefaultHeight, FALSE);

			NEW(processManager); processManager.alignment.Set(WMComponents.AlignClient);

			SetContent(processManager);
			SetTitle(Strings.NewString("Object Tracker"));
			SetIcon(WMGraphics.LoadImage("WMIcons.tar://WMObjectTracker.png", TRUE));

			IF c # NIL THEN WMRestorable.AddByContext(SELF, c)
			ELSE WM.DefaultAddWindow(SELF)
			END;
		END New;

		PROCEDURE Close*; (* override *)
		BEGIN
			Close^;
			window := NIL
		END Close;

		PROCEDURE Handle*(VAR x : WMMessages.Message);
		BEGIN
			IF (x.msgType = WMMessages.MsgExt) & (x.ext # NIL) THEN
				IF (x.ext IS WMRestorable.Storage) THEN
					x.ext(WMRestorable.Storage).Add("WMObjectTracker", "WMObjectTracker.Restore", SELF, NIL)
				ELSE Handle^(x)
				END
			ELSE Handle^(x)
			END
		END Handle;

	END Window;

VAR
	window : Window;

PROCEDURE Open*(context : Commands.Context);
BEGIN
	BEGIN {EXCLUSIVE}
		IF window = NIL THEN
			NEW(window, NIL)
		ELSE
			WM.DefaultBringToView(window, TRUE)
		END
	END;
END Open;

PROCEDURE Restore*(context : WMRestorable.Context);
BEGIN {EXCLUSIVE}
	IF window = NIL THEN
		NEW(window, context)
	ELSE
		WM.DefaultBringToView(window, TRUE)
	END;
END Restore;

PROCEDURE Close*;
VAR w : Window;
BEGIN
	BEGIN {EXCLUSIVE} w := window END;
	IF w # NIL THEN w.Close; END;
END Close;

PROCEDURE Cleanup;
BEGIN
	Close
END Cleanup;

BEGIN
	Modules.InstallTermHandler(Cleanup)
END WMObjectTracker.

WMObjectTracker.Open ~
WMObjectTracker.Close ~
SystemTools.Free WMObjectTracker ~

