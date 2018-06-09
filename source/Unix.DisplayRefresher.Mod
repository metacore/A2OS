MODULE DisplayRefresher; (** AUTHOR "staubesv"; PURPOSE "Force redraw of default viewport when receiving a X11 expore event"; *)

IMPORT
	Modules, KernelLog, Inputs, WMMessages, WMWindowManager;

VAR
	manager : WMWindowManager.WindowManager;
	viewport : WMWindowManager.ViewPort;

(* Message preview handler for window manager. MUST NOT TRAP!!! *)
PROCEDURE Handle(VAR msg : WMMessages.Message; VAR discard : BOOLEAN);
VAR meta : BOOLEAN;

BEGIN
	discard := FALSE;
	IF msg.msgType = WMMessages.MsgKey THEN
		meta := (msg.flags * Inputs.Meta # {}) OR ((msg.flags * Inputs.Alt # {}) & (msg.flags * Inputs.Shift # {}));
 		IF ~meta & (msg.y =  0FFC6H) THEN
 			manager.RefreshView(viewport);
 		END;
	END;
END Handle;

PROCEDURE Install*;
BEGIN (* load module *)
END Install;

PROCEDURE Cleanup;
BEGIN
	IF (manager # NIL) THEN manager.RemoveMessagePreview(Handle); END;
END Cleanup;

BEGIN
	Modules.InstallTermHandler(Cleanup);
	manager := WMWindowManager.GetDefaultManager();
	viewport := WMWindowManager.GetDefaultView();
	IF (manager # NIL) & (viewport # NIL) THEN
		manager.InstallMessagePreview(Handle);
		KernelLog.String("DisplayRefresher installed.");
	ELSE
		KernelLog.String("DisplayRefresher installation failed (could not find window manager or viewport) ");
	END;
	KernelLog.Ln;
END DisplayRefresher.

DisplayRefresher.Install ~

System.Free DisplayRefresher ~
