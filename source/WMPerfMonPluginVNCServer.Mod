MODULE WMPerfMonPluginVNCServer; (** AUTHOR "staubesv"; PURPOSE "Performance Monitor plugin for VNC server"; *)
(**
 * History:
 *
 *	27.02.2007	First release (staubesv)
 *)

IMPORT
	WMPerfMonPlugins, Modules, VNCServer;

CONST
	ModuleName = "WMPerfMonPluginVNCServer";

TYPE

	VncStats= OBJECT(WMPerfMonPlugins.Plugin)

		PROCEDURE Init*(p : WMPerfMonPlugins.Parameter);
		VAR ds : WMPerfMonPlugins.DatasetDescriptor;
		BEGIN
			p.name := "VNCServer"; p.description := "Performance Monitor plugin for VNC server";
			p.modulename := ModuleName;
			p.autoMin := FALSE; p.autoMax := TRUE; p.minDigits := 7;

			NEW(ds, 7);
			ds[0].name := "NnofAuthenticate";
			ds[1].name := "NnofAuthNone";
			ds[2].name := "NnofAuthVNC";
			ds[3].name := "NnofAuthOk";
			ds[4].name := "NnofAuthFailed";
			ds[5].name := "NnofEnteredServe";
			ds[6].name := "NnofLeftServer";
			p.datasetDescriptor := ds;
		END Init;

		PROCEDURE UpdateDataset*;
		BEGIN
			dataset[0] := VNCServer.NnofAuthenticate;
			dataset[1] := VNCServer.NnofAuthNone;
			dataset[2] := VNCServer.NnofAuthVNC;
			dataset[3] := VNCServer.NnofAuthOk;
			dataset[4] := VNCServer.NnofAuthFailed;
			dataset[5] := VNCServer.NnofEnteredServe;
			dataset[6] := VNCServer.NnofLeftServer;
		END UpdateDataset;

	END VncStats;

PROCEDURE Install*;
END Install;

PROCEDURE InitPlugin;
VAR par : WMPerfMonPlugins.Parameter; plugin : VncStats;
BEGIN
	NEW(par); NEW(plugin, par);
END InitPlugin;

PROCEDURE Cleanup;
BEGIN
	WMPerfMonPlugins.updater.RemoveByModuleName(ModuleName);
END Cleanup;

BEGIN
	Modules.InstallTermHandler(Cleanup);
	InitPlugin;
END WMPerfMonPluginVNCServer.

WMPerfMonPluginVNCServer.Install ~	SystemTools.Free WMPerfMonPluginVNCServer ~