MODULE WMPerfMonPluginMemory; (** AUTHOR "staubesv"; PURPOSE "Performance Monitor memory utilization plugin"; *)

IMPORT
	Kernel32, Modules, WMPerfMonPlugins, Heaps;

CONST
	ModuleName = "WMPerfMonPluginMemory";

TYPE

	(* Heaps.GetHeapInfo is a slow operation. HeapHelper provides its results to multiple plugins *)
	HeapHelper = OBJECT(WMPerfMonPlugins.Helper)
	VAR
		free, total, largest : SIZE;

		PROCEDURE Update*;
		BEGIN
			Heaps.GetHeapInfo(total, free, largest);
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
			NEW(ds, 3);
			ds[0].name := "Size"; INCL(ds[0].flags, WMPerfMonPlugins.Maximum);
			ds[1].name := "Free";
			ds[2].name := "LargestBlock"; INCL(ds[2].flags, WMPerfMonPlugins.Standalone);
			p.datasetDescriptor := ds;
		END Init;

		PROCEDURE UpdateDataset*;
		BEGIN
			dataset[0] := h.total DIV 1024;
			dataset[1] := h.free DIV 1024;
			dataset[2] := h.largest DIV 1024;
		END UpdateDataset;

	END MemoryLoad;

TYPE

	WindowsMemoryLoad = OBJECT(WMPerfMonPlugins.Plugin)
	VAR
		status : Kernel32.MemoryStatusEx;

		PROCEDURE Init*(p : WMPerfMonPlugins.Parameter);
		VAR ds : WMPerfMonPlugins.DatasetDescriptor;
		BEGIN
			p.name := "Memory"; p.description := "Windows Memory Statistics"; p.modulename := ModuleName;
			p.noSuperSampling := TRUE;
			p.autoMax := TRUE; p.unit := "KB"; p.minDigits := 7;
			NEW(ds, 7);
			ds[0].name := "Memory Load [%]";
			ds[1].name := "Total (Physical)";
			ds[2].name := "Free (Physical)";
			ds[3].name := "Total (Page file)";
			ds[4].name := "Free (Page file)";
			ds[5].name := "Total (Virtual)";
			ds[6].name := "Free (Virtual)";
			p.datasetDescriptor := ds;
		END Init;

		PROCEDURE UpdateDataset*;
		BEGIN
			status.dwLength := 64;
			IF (Kernel32.GlobalMemoryStatusEx(status) = Kernel32.True) THEN
				dataset[0] := status.dwMemoryLoad;
				dataset[1] := status.ullTotalPhys DIV 1024;
				dataset[2] := status.ullAvailPhys DIV 1024;
				dataset[3] := status.ullTotalPageFile DIV 1024;
				dataset[4] := status.ullAvailPageFile DIV 1024;
				dataset[5] := status.ullTotalVirtual DIV 1024;
				dataset[6] := status.ullAvailVirtual DIV 1024;
			END;
		END UpdateDataset;

	END WindowsMemoryLoad;

VAR
	heapHelper : HeapHelper;

PROCEDURE InitPlugins;
VAR
	par : WMPerfMonPlugins.Parameter;
	ml : MemoryLoad;
	wml : WindowsMemoryLoad;
BEGIN
	NEW(par); NEW(ml, par);
	NEW(par); NEW(wml, par);
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

WMPerfMonPluginMemory.Install ~	System.Free WMPerfMonPluginMemory ~
