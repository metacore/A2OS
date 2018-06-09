MODULE PresentViewer; (** AUTHOR "TF"; PURPOSE "Testbed for the component system"; *)

IMPORT
	Modules, Commands, WMComponents, XML, WM := WMWindowManager;

VAR w : WMComponents.FormWindow;

PROCEDURE Open*(context : Commands.Context);
VAR
	c : XML.Content; filename : ARRAY 128 OF CHAR;
	width, height : LONGINT;
BEGIN
	context.arg.SkipWhitespace; context.arg.String(filename);
	c := WMComponents.Load(filename);
	width := 320; height := 240;
	IF c # NIL THEN
		IF c IS WMComponents.VisualComponent THEN
			width := c(WMComponents.VisualComponent).bounds.GetWidth();
			height := c(WMComponents.VisualComponent).bounds.GetHeight();
			IF width <= 0 THEN width := 10 END; IF height <= 0 THEN height := 10 END
		END;
		NEW(w, width, height, TRUE);
		w.pointerThreshold := 50;
		WM.ExtAddWindow(w, 500, 350, {});
		w.SetTitle(c(XML.Element).GetAttributeValue("caption"));
		w.SetContent(c);
	ELSE
		context.error.String(filename); context.error.String(" not correctly loaded"); context.error.Ln;
	END;
END Open;

(* Cleanup on module free *)
PROCEDURE Cleanup;
BEGIN
	IF w # NIL THEN w.Close END
END Cleanup;

BEGIN
	Modules.InstallTermHandler(Cleanup)
END PresentViewer.

System.Free PresentViewer ~
PresentViewer.Open XmasMenu.XML ~



