MODULE WMPerfMonPluginCpu; (** AUTHOR "staubesv"; PURPOSE "Performance Monitor CPU load plugin"; *)

IMPORT
	WMPerfMonPlugins, Modules;

CONST

	ModuleName = "WMPerfMonPluginCpu";

TYPE

	(* Dummy parameter for compatiblity only *)
	CpuParameter* = POINTER TO RECORD (WMPerfMonPlugins.Parameter)
		processorID* : SIZE;
	END;

	CpuLoad* = OBJECT(WMPerfMonPlugins.Plugin);

		PROCEDURE Init*(p : WMPerfMonPlugins.Parameter);
		BEGIN
			p.name := "CPU Load (not implemented)"; p.description := "CPU Load (not yet implemented)";
			p.modulename := ModuleName;
			p.autoMin := TRUE; p.autoMax := TRUE; p.minDigits := 2;
		END Init;

		PROCEDURE UpdateDataset*;
		BEGIN
			dataset[0] := 0;
		END UpdateDataset;

	END CpuLoad;

VAR
	nbrOfCpus- : LONGINT;

PROCEDURE InitPlugins;
VAR cpuLoad : CpuLoad; par : WMPerfMonPlugins.Parameter;
BEGIN
	NEW(par); NEW(cpuLoad, par);
END InitPlugins;

PROCEDURE Install*;
END Install;

PROCEDURE Cleanup;
BEGIN
	WMPerfMonPlugins.updater.RemoveByModuleName(ModuleName);
END Cleanup;

BEGIN
	nbrOfCpus := 1;
	InitPlugins;
	Modules.InstallTermHandler(Cleanup);
END WMPerfMonPluginCpu.

WMPerfMonPluginCpu.Install ~ 	System.Free WMPerfMonPluginCpu ~
