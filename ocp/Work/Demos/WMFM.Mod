MODULE WMFM;

IMPORT
	Commands, WMWindowManager, WMFileManager;
	
PROCEDURE WindowGenerator*(ctx: Commands.Context): WMWindowManager.Window;
VAR
	fm: WMFileManager.Window;
BEGIN
	NEW(fm, NIL);
	RETURN fm;
END WindowGenerator;

END WMFM.
