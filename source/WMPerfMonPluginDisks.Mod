MODULE WMPerfMonPluginDisks; (** AUTHOR "staubesv"; PURPOSE "Performance Monitor disk transfer rate plugin"; *)
(**
 * History:
 *
 *	16.02.2006	First Release (staubesv)
 *	23.06.2006	Adapted to WMPerfMonPlugins (staubesv)
 *	27.02.2007	Remove plugins when unloading module, distinct bytesRead/bytesWritten (staubesv)
 *	26.03.2007	Added NnofReads, NnofWrites, NnofOthers, NnofErrors, AvgBlockSize (staubesv)
 *)

IMPORT
	WMPerfMonPlugins,
	KernelLog, Disks, Plugins, Modules;

CONST
	PluginName = "DiskDevice";
	ModuleName = "WMPerfMonPluginDisks";

TYPE

	DiskParameter = POINTER TO RECORD(WMPerfMonPlugins.Parameter)
		dev : Disks.Device;
	END;

	DiskPlugin = OBJECT(WMPerfMonPlugins.Plugin)
	VAR
		dev : Disks.Device;

		PROCEDURE Init*(p : WMPerfMonPlugins.Parameter);
		VAR ds : WMPerfMonPlugins.DatasetDescriptor;
		BEGIN
			p.name := PluginName; p.description := "Disk device statistics";
			SELF.dev := p(DiskParameter).dev;
			WMPerfMonPlugins.GetNameDesc(dev, p.devicename);
			p.modulename := ModuleName;
			p.autoMax := TRUE; p.unit := "KB"; p.perSecond := TRUE; p.minDigits := 5; p.showSum := TRUE;

			NEW(ds, 8);
			ds[0].name := "TotalKB";
			ds[1].name := "ReadKB";
			ds[2].name := "WrittenKB";
			ds[3].name := "AvgBlockSizeBytes";
			ds[4].name := "NnofReads";
			ds[5].name := "NnofWrites";
			ds[6].name := "NnofOthers";
			ds[7].name := "NnofErrors";
			p.datasetDescriptor := ds;
		END Init;

		PROCEDURE UpdateDataset*;
		VAR read, written, nofReads, nofWrites, nofTot, nofErrors : HUGEINT; total : REAL;
		BEGIN
			read := dev.NbytesRead; nofReads := dev.NnofReads;
			written := dev.NbytesWritten; nofWrites := dev.NnofWrites;
			total := read + written;
			nofErrors := dev.NnofErrors;
			nofTot := nofReads + nofWrites - nofErrors;
			dataset[0] := total / 1024;
			dataset[1] := read / 1024;
			dataset[2] := written / 1024;
			dataset[3] := total / nofTot;
			dataset[4] := nofReads;
			dataset[5] := nofWrites;
			dataset[6] := dev.NnofOthers;
			dataset[7] := nofErrors;
		END UpdateDataset;

	END DiskPlugin;

PROCEDURE AddPlugin(disk : Disks.Device);
VAR par : DiskParameter; plugin : DiskPlugin;
BEGIN {EXCLUSIVE}
	NEW(par); par.dev := disk; NEW(plugin, par);
END AddPlugin;

PROCEDURE RemovePlugin(disk : Disks.Device);
VAR devicename : WMPerfMonPlugins.DeviceName;
BEGIN {EXCLUSIVE}
	WMPerfMonPlugins.GetNameDesc(disk, devicename);
	WMPerfMonPlugins.updater.RemoveByName(PluginName, devicename);
END RemovePlugin;

PROCEDURE EventHandler(event : WORD; plugin : Plugins.Plugin);
BEGIN
	IF event = Plugins.EventAdd THEN
		AddPlugin(plugin (Disks.Device))
	ELSIF event = Plugins.EventRemove THEN
		RemovePlugin(plugin (Disks.Device));
	END;
END EventHandler;

PROCEDURE InitPlugins;
VAR table : Plugins.Table; i : LONGINT;
BEGIN
	IF Disks.Stats THEN
		Disks.registry.AddEventHandler(EventHandler, i); (* ignore res *)
		Disks.registry.GetAll(table);
		IF table # NIL THEN FOR i := 0 TO LEN(table)-1 DO AddPlugin(table[i] (Disks.Device)); END; END;
	ELSE KernelLog.String("WMPerfMonPluginDisks: Disks.PerformanceMonitoring is FALSE."); KernelLog.Ln;
	END;
END InitPlugins;

PROCEDURE Install*;
END Install;

PROCEDURE Cleanup;
VAR ignore : LONGINT;
BEGIN
	IF Disks.Stats THEN
		Disks.registry.RemoveEventHandler(EventHandler, ignore);
		WMPerfMonPlugins.updater.RemoveByModuleName(ModuleName);
	END;
END Cleanup;

BEGIN
	Modules.InstallTermHandler(Cleanup);
	InitPlugins;
END WMPerfMonPluginDisks.

WMPerfMonPluginDisks.Install ~ System.Free WMPerfMonPluginDisks ~
