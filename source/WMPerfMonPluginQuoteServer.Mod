MODULE WMPerfMonPluginQuoteServer; (** AUTHOR "staubesv"; PURPOSE "Performance Monitor plugin for quote server statistics"; *)
(**
 * History:
 *
 *	27.02.2007	First release (staubesv)
 *)

IMPORT
	WMPerfMonPlugins, QuoteServer, Modules;

CONST
	ModuleName = "WMPerfMonPluginQuoteServer";

TYPE

	QuoteStats= OBJECT(WMPerfMonPlugins.Plugin)

		PROCEDURE Init*(p : WMPerfMonPlugins.Parameter);
		VAR ds : WMPerfMonPlugins.DatasetDescriptor;
		BEGIN
			p.name := "Quote Server";
			p.description := "Quote server statistics";
			p.modulename := ModuleName;
			p.autoMin := FALSE; p.autoMax := TRUE; p.minDigits := 7;

			NEW(ds, 2);
			ds[0].name := "NnofQuotes";
			ds[1].name := "Nrequests";
			p.datasetDescriptor := ds;
		END Init;

		PROCEDURE UpdateDataset*;
		BEGIN
			dataset[0] := QuoteServer.NnofQuotes;
			dataset[1] := QuoteServer.Nrequests;
		END UpdateDataset;

	END QuoteStats;

PROCEDURE Install*;
END Install;

PROCEDURE InitPlugin;
VAR par : WMPerfMonPlugins.Parameter; stats : QuoteStats;
BEGIN
	NEW(par); NEW(stats, par);
END InitPlugin;

PROCEDURE Cleanup;
BEGIN
	WMPerfMonPlugins.updater.RemoveByModuleName(ModuleName);
END Cleanup;

BEGIN
	Modules.InstallTermHandler(Cleanup);
	InitPlugin;
END WMPerfMonPluginQuoteServer.

WMPerfMonPluginQuoteServer.Install ~   System.Free WMPerfMonPluginQuoteServer ~
