MODULE WMPerfMonPluginHTTPServer; (** AUTHOR "staubesv"; PURPOSE "Performance Monitor plugin for HTTP server statistics"; *)
(**
 * History:
 *
 *	27.02.2007	First release (staubesv)
 *)

IMPORT
	WMPerfMonPlugins, WebHTTPServer, Modules;

CONST
	ModuleName = "WMPerfMonPluginHTTPServer";

TYPE

	HTTPStats= OBJECT(WMPerfMonPlugins.Plugin)

		PROCEDURE Init*(p : WMPerfMonPlugins.Parameter);
		VAR ds : WMPerfMonPlugins.DatasetDescriptor;
		BEGIN
			p.name := "WebHTTPServer";
			p.description := "HTTP server statistics";
			p.modulename := ModuleName;
			p.autoMin := FALSE; p.autoMax := TRUE; p.minDigits := 7;

			NEW(ds, 3);
			ds[0].name := "nofRequests";
			ds[1].name := "requestsPerMinute";
			ds[2].name := "nofConnects";
			p.datasetDescriptor := ds;
		END Init;

		PROCEDURE UpdateDataset*;
		BEGIN
			dataset[0] := WebHTTPServer.nofRequests;
			dataset[1] := WebHTTPServer.requestsPerMinute;
			dataset[2] := WebHTTPServer.nofConnects;
		END UpdateDataset;

	END HTTPStats;

PROCEDURE Install*;
END Install;

PROCEDURE InitPlugin;
VAR par : WMPerfMonPlugins.Parameter; stats : HTTPStats;
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
END WMPerfMonPluginHTTPServer.

WMPerfMonPluginHTTPServer.Install ~   SystemTools.Free WMPerfMonPluginHTTPServer ~
