MODULE WMPerfMonPluginMemory; (** AUTHOR "staubesv"; PURPOSE "Performance Monitor memory utilization plugin"; *)

IMPORT
	Modules, WMPerfMonPlugins, Heaps;

CONST
	ModuleName = "WMPerfMonPluginMemory";

TYPE

	(* Heaps.GetHeapInfo is a slow operation. HeapHelper provides its results to multiple plugins *)
	HeapHelper = OBJECT(WMPerfMonPlugins.Helper)
	VAR
		free, total : SIZE;

		PROCEDURE Update;
		BEGIN
			total := Heaps.HeapSize();
			free := total - Heaps.Used();
		END Update;

	END HeapHelper;

TYPE

	MemoryLoad* = OBJECT(WMPerfMonPlugins.Plugin)
	VAR
		h : HeapHelper;

		PROCEDURE Init*(p : WMPerfMonPlugins.Parameter);
		VAR ds : WMPerfMonPlugins.DatasetDescriptor;
		BEGIN
			p.name := "Heap"; p.description := "Heap statistics"; p.modulename := ModuleName;
			p.autoMax := TRUE; p.unit := "KB"; p.minDigits := 7;
			p.noSuperSampling := TRUE;
			p.helper := heapHelper; h := heapHelper;
			NEW(ds, 2);
			ds[0].name := "Size"; INCL(ds[0].flags, WMPerfMonPlugins.Maximum);
			ds[1].name := "Free";
			p.datasetDescriptor := ds;
		END Init;

		PROCEDURE UpdateDataset*;
		BEGIN
			dataset[0] := h.total DIV 1024;
			dataset[1] := h.free DIV 1024;
		END UpdateDataset;

	END MemoryLoad;

VAR
	heapHelper : HeapHelper;

PROCEDURE InitPlugins;
VAR
	par : WMPerfMonPlugins.Parameter;
	ml : MemoryLoad;
BEGIN
	NEW(par); NEW(ml, par);
END InitPlugins;

PROCEDURE Install*;
END Install;

PROCEDURE Cleanup;
BEGIN
	WMPerfMonPlugins.updater.RemoveByModuleName(ModuleName);
END Cleanup;

BEGIN
	NEW(heapHelper);
	InitPlugins;
	Modules.InstallTermHandler(Cleanup);
END WMPerfMonPluginMemory.

WMPerfMonPluginMemory.Install ~	SystemTools.Free WMPerfMonPluginMemory ~
