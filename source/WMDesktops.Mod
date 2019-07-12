MODULE WMDesktops; (** AUTHOR "staubesv"; PURPOSE "Load/Store desktops"; *)

IMPORT
	Commands, WMWindowManager, WMRestorable;

VAR
	manager : WMWindowManager.WindowManager;

PROCEDURE Load*(context : Commands.Context); (** desktopname ~ *)
BEGIN
	CloseAllWindows;
	WMRestorable.Load(context);
END Load;

PROCEDURE Store*(context : Commands.Context); (** desktopname ~ *)
BEGIN
	WMRestorable.Store(context);
END Store;

PROCEDURE CloseAllWindows;
VAR
	window : WMWindowManager.Window;
	windows : POINTER TO ARRAY OF WMWindowManager.Window;
	nofWindows, i : SIZE;
BEGIN
	ASSERT(manager # NIL);
	manager.lock.AcquireWrite;
	(* count number of windows *)
	nofWindows := 0;
	window := manager.GetFirst();
	WHILE (window # NIL) DO
		IF  ~(WMWindowManager.FlagHidden IN window.flags) THEN INC(nofWindows); END;
		window := manager.GetNext(window);
	END;

	(* create result *)
	IF (nofWindows > 0) THEN
		NEW(windows, nofWindows);
		window := manager.GetFirst();
		i := 0;
		WHILE (i < LEN(windows)) & (window # NIL) DO
			IF ~(WMWindowManager.FlagHidden IN window.flags) THEN
				windows[i] := window;
				INC(i);
			END;
			window := manager.GetNext(window);
		END;
	END;
	manager.lock.ReleaseWrite;
	FOR i := 0 TO LEN(windows)-1 DO
		windows[i].Close;
	END;
END CloseAllWindows;

BEGIN
	manager := WMWindowManager.GetDefaultManager();
	ASSERT(manager # NIL);
END WMDesktops.

WMDesktops.Store Test.Desktop ~

WMDesktops.Load Test.Desktop ~

System.Free WMDesktops ~
