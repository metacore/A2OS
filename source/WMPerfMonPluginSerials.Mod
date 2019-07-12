MODULE WMPerfMonPluginSerials; (** AUTHOR "staubesv"; PURPOSE "Performance Monitor Serial Port transfer rate plugin"; *)

IMPORT
	WMPerfMonPlugins, Strings, Modules, Serials;

CONST
	PluginName = "Serials";
	PluginDescription = "Serial Port Transfer Rate";

TYPE

	SerialsParameter = POINTER TO RECORD(WMPerfMonPlugins.Parameter)
		port : Serials.Port;
	END;

	SerialPortTransferRate = OBJECT(WMPerfMonPlugins.Plugin)
	VAR
		port : Serials.Port;

		PROCEDURE Init*(p : WMPerfMonPlugins.Parameter);
		VAR ds : WMPerfMonPlugins.DatasetDescriptor;
		BEGIN
			p.name := PluginName; p.description := PluginDescription;
			SELF.port := p(SerialsParameter).port;
			COPY(port.name, p.devicename);
			Strings.Append(p.devicename, " ("); Strings.Append(p.devicename, port.description); Strings.Append(p.devicename, ")");
			p.modulename := "WMPerfMonPluginSerials";
			p.autoMin := FALSE; p.autoMax := TRUE; p.unit := "KB"; p.perSecond := TRUE; p.minDigits := 5; p.showSum := TRUE;

			NEW(ds, 3);
			ds[0].name := "Total"; ds[0].unit := "KB"; INCL(ds[0].flags, WMPerfMonPlugins.Sum);
			ds[1].name := "Received"; ds[1].unit := "KB";
			ds[2].name := "Sent"; ds[2].unit := "KB";
			p.datasetDescriptor := ds;
		END Init;

		PROCEDURE UpdateDataset*;
		VAR sent, received : LONGINT;
		BEGIN
			sent := port.charactersSent; received := port.charactersReceived;
			dataset[0] := sent + received / 1024;
			dataset[1] := received / 1024;
			dataset[2] := sent / 1024;
		END UpdateDataset;

	END SerialPortTransferRate;

VAR
	plugins : ARRAY Serials.MaxPorts OF SerialPortTransferRate;

(** Install a serial port plugin for each serial port. Previously installed plugins will be removed *)
PROCEDURE Install*;
VAR
	plugin : SerialPortTransferRate; p : SerialsParameter;
	port : Serials.Port; i : LONGINT;
BEGIN {EXCLUSIVE}
	RemovePlugins;
	FOR i := 1 TO Serials.MaxPorts DO
		port := Serials.GetPort(i);
		IF port # NIL THEN
			NEW(p); p.port := port;
			NEW(plugin, p);
			plugins[i-1] := plugin;
		END;
	END;
END Install;

PROCEDURE RemovePlugins;
VAR i : LONGINT;
BEGIN
	(* Remove currently installed plugins *)
	FOR i := 0 TO LEN(plugins)-1 DO
		IF plugins[i] # NIL THEN
			plugins[i].Finalize;
			plugins[i] := NIL;
		END;
	END;
END RemovePlugins;

PROCEDURE Cleanup;
BEGIN {EXCLUSIVE}
	RemovePlugins;
END Cleanup;

BEGIN
	Modules.InstallTermHandler(Cleanup);
END WMPerfMonPluginSerials.

WMPerfMonPluginSerials.Install ~	System.Free WMPerfMonPluginSerials ~