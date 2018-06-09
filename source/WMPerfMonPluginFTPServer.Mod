MODULE WMPerfMonPluginFTPServer; (** AUTHOR "staubesv"; PURPOSE "Performance Monitor plugin for FTP server statistics"; *)
(**
 * History:
 *
 *	27.02.2007	First release (staubesv)
 *)

IMPORT
	WMPerfMonPlugins, WebFTPServer, Modules;

CONST
	ModuleName = "WMPerfMonPluginFTPServer";

TYPE

	FTPStats= OBJECT(WMPerfMonPlugins.Plugin)

		PROCEDURE Init*(p : WMPerfMonPlugins.Parameter);
		VAR ds : WMPerfMonPlugins.DatasetDescriptor;
		BEGIN
			p.name := "WebFTPServer"; p.description := "FTP server statistics";
			p.modulename := ModuleName;
			p.autoMin := FALSE; p.autoMax := TRUE; p.minDigits := 7;

			NEW(ds, 6);
			ds[0].name := "NclientsTotal";
			ds[1].name := "NclientsActive";
			ds[2].name := "NMebiBReceived"; ds[2].unit := "MiB";
			ds[3].name := "NMebiBSent"; ds[3].unit := "MiB";
			ds[4].name := "NbytesReceived"; ds[4].unit := "B";
			ds[5].name := "NbytesSent"; ds[5].unit := "B";
			p.datasetDescriptor := ds;
		END Init;

		PROCEDURE UpdateDataset*;
		BEGIN
			dataset[0] := WebFTPServer.NclientsTotal;
			dataset[1] := WebFTPServer.NclientsActive;
			dataset[2] := WebFTPServer.NMebiBReceived;
			dataset[3] := WebFTPServer.NMebiBSent;
			dataset[4] := WebFTPServer.NbytesReceived;
			dataset[5] := WebFTPServer.NbytesSent;
		END UpdateDataset;

	END FTPStats;

PROCEDURE Install*; (** ~ *)
END Install;

PROCEDURE InitPlugin;
VAR par : WMPerfMonPlugins.Parameter; stats : FTPStats;
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
END WMPerfMonPluginFTPServer.

WMPerfMonPluginFTPServer.Install ~   System.Free WMPerfMonPluginFTPServer ~
