MODULE WMPerfMonPluginExample; (** AUTHOR "staubesv"; PURPOSE "Performance Monitor plugin example"; *)
(**
 * History:
 *
 *	27.02.2007	First release (staubesv)
 *)

IMPORT
	WMPerfMonPlugins, Modules, Commands;

CONST
	ModuleName = "WMPerfMonPluginExample";

TYPE

	Example= OBJECT(WMPerfMonPlugins.Plugin)

		PROCEDURE Init*(p : WMPerfMonPlugins.Parameter);
		VAR ds : WMPerfMonPlugins.DatasetDescriptor;
		BEGIN
			p.name := "Example"; p.description := "Performance Monitor plugin example";
			p.modulename := ModuleName;
			p.autoMin := FALSE; p.autoMax := TRUE; p.minDigits := 7;

			NEW(ds, 3);
			ds[0].name := "Nvalue1";
			ds[1].name := "Nvalue2";
			ds[2].name := "Nvalue3";
			p.datasetDescriptor := ds;
		END Init;

		PROCEDURE UpdateDataset*;
		BEGIN
			dataset[0] := Nvalue1;
			dataset[1] := Nvalue2;
			dataset[2] := Nvalue3;
		END UpdateDataset;

	END Example;

VAR
	Nvalue1, Nvalue2, Nvalue3 : LONGINT;

PROCEDURE SetValues*(context : Commands.Context); (** Nvalue1 Nvalue2 Nvalue3 ~ *)
BEGIN
	context.arg.SkipWhitespace; context.arg.Int(Nvalue1, FALSE);
	context.arg.SkipWhitespace; context.arg.Int(Nvalue2, FALSE);
	context.arg.SkipWhitespace; context.arg.Int(Nvalue3, FALSE);
END SetValues;

PROCEDURE Install*; (** ~ *)
END Install;

PROCEDURE InitPlugin;
VAR par : WMPerfMonPlugins.Parameter; plugin : Example;
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
END WMPerfMonPluginExample.

WMPerfMonPluginExample.Install ~   SystemTools.Free WMPerfMonPluginExample ~

WMPerfMonPluginExample.SetValues 112 1 9 ~

WMPerfMonPluginExample.SetValues 10 1 1 ~

WMPerfMonPluginExample.SetValues 1 1 1 ~

WMPerfMonPluginExample.SetValues -1 -11 1 ~

WMPerfMonPluginExample.SetValues 1 1 100 ~