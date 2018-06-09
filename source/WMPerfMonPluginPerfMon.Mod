MODULE WMPerfMonPluginPerfMon; (** AUTHOR "staubesv"; PURPOSE "Performance Monitor plugin for self-monitoring"; *)
(**
 * History:
 *
 *	27.02.2007	First release (staubesv)
 *)

IMPORT
	WMPerfMonPlugins, Modules;

CONST
	ModuleName = "WMPerfMonPluginPerfMon";

TYPE

	PerfMonStats= OBJECT(WMPerfMonPlugins.Plugin)

		PROCEDURE Init*(p : WMPerfMonPlugins.Parameter);
		VAR ds : WMPerfMonPlugins.DatasetDescriptor;
		BEGIN
			p.name := "WMPerfMonPlugins"; p.description := "Performance Monitor monitoring";
			p.modulename := ModuleName;
			p.autoMin := FALSE; p.autoMax := TRUE; p.minDigits := 7;

			NEW(ds, 2);
			ds[0].name := "NnofPlugins";
			ds[1].name := "NnofValues";
			p.datasetDescriptor := ds;
		END Init;

		PROCEDURE UpdateDataset*;
		BEGIN
			dataset[0] := WMPerfMonPlugins.NnofPlugins;
			dataset[1] := WMPerfMonPlugins.NnofValues;
		END UpdateDataset;

	END PerfMonStats;

PROCEDURE Install*;
END Install;

PROCEDURE InitPlugin;
VAR par : WMPerfMonPlugins.Parameter; plugin : PerfMonStats;
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
END WMPerfMonPluginPerfMon.

WMPerfMonPluginPerfMon.Install ~   System.Free WMPerfMonPluginPerfMon ~