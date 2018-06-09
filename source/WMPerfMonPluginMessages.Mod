MODULE WMPerfMonPluginMessages; (** AUTHOR "staubesv"; PURPOSE "Performance Monitor WMMessages statistics plugin"; *)

IMPORT
	WMPerfMonPlugins,
	KernelLog, WMMessages, Modules;

CONST
	ModuleName = "WMPerfMonPluginMessages";

TYPE

	MessagesPlugin = OBJECT(WMPerfMonPlugins.Plugin)

		PROCEDURE Init*(p : WMPerfMonPlugins.Parameter);
		VAR ds : WMPerfMonPlugins.DatasetDescriptor;
		BEGIN
			p.name := "Messages"; p.description := "WMMessages statistics";
			p.modulename := ModuleName;
			p.autoMax := TRUE; p.perSecond := TRUE; p.minDigits := 5; p.showSum := TRUE;

			NEW(ds, 11);
			ds[0].name := "messagesAdded"; INCL(ds[0].flags, WMPerfMonPlugins.Sum);
			ds[1].name := "messagesDiscarded"; INCL(ds[1].flags, WMPerfMonPlugins.Standalone);
			ds[2].name := "MsgPointer ";
			ds[3].name := "MsgKey ";
			ds[4].name := "MsgClose ";
			ds[5].name := "MsgStyleChanged ";
			ds[6].name := "MsgFocus ";
			ds[7].name := "MsgExt ";
			ds[8].name := "MsgDrag ";
			ds[9].name := "MsgInvokeEvent ";
			ds[10].name := "MsgResized" ;
			p.datasetDescriptor := ds;
		END Init;

		PROCEDURE UpdateDataset*;
		BEGIN
			dataset[0] := WMMessages.messagesAdded;
			dataset[1] := WMMessages.messagesDiscarded;
			dataset[2] := WMMessages.messagesAddedByType[WMMessages.MsgPointer];
			dataset[3] := WMMessages.messagesAddedByType[WMMessages.MsgKey];
			dataset[4] := WMMessages.messagesAddedByType[WMMessages.MsgClose];
			dataset[5] := WMMessages.messagesAddedByType[WMMessages.MsgStyleChanged];
			dataset[6] := WMMessages.messagesAddedByType[WMMessages.MsgFocus];
			dataset[7] := WMMessages.messagesAddedByType[WMMessages.MsgExt];
			dataset[8] := WMMessages.messagesAddedByType[WMMessages.MsgDrag];
			dataset[9] := WMMessages.messagesAddedByType[WMMessages.MsgInvokeEvent];
			dataset[10] := WMMessages.messagesAddedByType[WMMessages.MsgResized];
		END UpdateDataset;

	END MessagesPlugin;

PROCEDURE Install*; (** ~ *)
VAR par : WMPerfMonPlugins.Parameter; plugin : MessagesPlugin;
BEGIN
	IF WMMessages.Statistics THEN
		NEW(par); NEW(plugin, par);
	ELSE KernelLog.String("WMPerfMonPluginMessages: WMMessages.Statistics is FALSE. Plugin not installed."); KernelLog.Ln;
	END;
END Install;

PROCEDURE Cleanup;
BEGIN
	IF WMMessages.Statistics THEN
		WMPerfMonPlugins.updater.RemoveByModuleName(ModuleName);
	END;
END Cleanup;

BEGIN
	Modules.InstallTermHandler(Cleanup);
END WMPerfMonPluginMessages.

WMPerfMonPluginMessages.Install ~  System.Free WMPerfMonPluginMessages ~