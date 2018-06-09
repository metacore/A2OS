MODULE WMPerfMonPluginEvents; (** AUTHOR "staubesv"; PURPOSE "Performance Monitor plugin for event system"; *)
(**
 * History:
 *
 *	03.03.2007	First Release (staubesv)
 *)

IMPORT
	Modules,
	WMPerfMonPlugins, Events;

CONST
	ModuleName = "WMPerfMonPluginEvents";

TYPE

	EventStats* = OBJECT(WMPerfMonPlugins.Plugin)

		PROCEDURE Init*(p : WMPerfMonPlugins.Parameter);
		VAR ds : WMPerfMonPlugins.DatasetDescriptor;
		BEGIN
			p.name := "Events"; p.description := "Event log statistics";
			p.modulename := ModuleName;
			p.autoMin := FALSE; p.autoMax := TRUE; p.minDigits := 5;

			NEW(ds, 12);
			ds[0].name := "NnofEvents";
			ds[1].name := "NnofDiscarded";
			ds[2].name := "NnofEventsHandled";
			ds[3].name := "NnofEventsNotHandled";
			ds[4].name := "NnofUnknown";
			ds[5].name := "NnofUndefined";
			ds[6].name := "NnofInformation";
			ds[7].name := "NnofWarning";
			ds[8].name := "NnofError";
			ds[9].name := "NnofCritical";
			ds[10].name := "NnofFailure";
			ds[11].name := "NnofListeners";
			p.datasetDescriptor := ds;
		END Init;

		PROCEDURE UpdateDataset*;
		BEGIN
			dataset[0] := Events.NnofEvents;
			dataset[1] := Events.NnofDiscarded;
			dataset[2] := Events.NnofEventsHandled;
			dataset[3] := Events.NnofEventsNotHandled;
			dataset[4] := Events.NnofUnknown;
			dataset[5] := Events.NnofUndefined;
			dataset[6] := Events.NnofInformation;
			dataset[7] := Events.NnofWarning;
			dataset[8] := Events.NnofError;
			dataset[9] := Events.NnofCritical;
			dataset[10] := Events.NnofFailure;
			dataset[11] := Events.NnofListeners;
		END UpdateDataset;

	END EventStats;

PROCEDURE Install*;
END Install;

PROCEDURE InitPlugin;
VAR par : WMPerfMonPlugins.Parameter; plugin : EventStats;
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
END WMPerfMonPluginEvents.

WMPerfMonPluginEvents.Install ~	System.Free WMPerfMonPluginEvents ~