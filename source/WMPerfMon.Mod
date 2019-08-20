MODULE WMPerfMon; (** AUTHOR "TF/staubesv"; PURPOSE "Performance Monitor"; *)

IMPORT
	KernelLog, Modules, Plugins, Strings, Network,
	WMRectangles, WMGraphics, WMMessages, WMWindowManager, WMRestorable, WMComponents, WMStandardComponents,
	WMTabComponents, WMProcessInfo,
	WMPerfMonPlugins, WMPerfMonComponents, WMPerfMonTabAlerts, WMPerfMonTabSystem,
	WMPerfMonPluginMemory, WMPerfMonPluginCpu, WMPerfMonPluginNetwork;

CONST

	(* Startup width and height of Performance Monitor window *)
	DefaultWidth = 750; DefaultHeight = 400;

	(* Scale window if its smaller than this size *)
	MinWidth = 150; MinHeight = 150;

	NbrOfTabs = 6;

TYPE

	(* Container containing CpuLoad plugins for each CPU and the memory statistics plugin *)
	CpuMemoryComponent =  OBJECT(WMPerfMonComponents.PluginContainer)
	VAR
		cpu : POINTER TO ARRAY OF WMPerfMonPluginCpu.CpuLoad;
		ml : WMPerfMonPluginMemory.MemoryLoad;

		PROCEDURE LocatePlugins*() : BOOLEAN;
		VAR
			par : WMPerfMonPlugins.Parameter;
			cpar : WMPerfMonPluginCpu.CpuParameter;
			i : SIZE;
		BEGIN
			NEW(cpu, WMPerfMonPluginCpu.nbrOfCpus);
			FOR i := 0 TO LEN(cpu)-1 DO
				NEW(cpar); cpar.processorID := i; cpar.hide := TRUE; NEW(cpu[i], cpar);
				AddPlugin(cpu[i], WMPerfMonComponents.GraphView);
			END;
			NEW(par); par.hide := TRUE; NEW(ml, par); AddPlugin(ml, WMPerfMonComponents.GraphView);
			RETURN TRUE;
		END LocatePlugins;

		PROCEDURE Finalize*;
		VAR i : SIZE;
		BEGIN
			Finalize^;
			FOR i := 0 TO LEN(cpu)-1 DO WMPerfMonPlugins.updater.RemovePlugin(cpu[i]); END;
			WMPerfMonPlugins.updater.RemovePlugin(ml);
		END Finalize;

	END CpuMemoryComponent;

	(* Container containing NetSend/NetReceive plugins for each link device *)
	NetworkComponent = OBJECT(WMPerfMonComponents.PluginContainer)
	VAR
		netspeed : POINTER TO ARRAY OF WMPerfMonPluginNetwork.NetworkSpeed;

		PROCEDURE LocatePlugins*() : BOOLEAN;
		VAR
			npar : WMPerfMonPluginNetwork.NetParameter;
			table : Plugins.Table; dev : Network.LinkDevice;
			i : SIZE;
		BEGIN
			Network.registry.GetAll(table);
			IF table # NIL THEN
				NEW(netspeed, LEN(table));
				FOR i := 0 TO LEN(table)-1 DO
					dev := table[i] (Network.LinkDevice);
					NEW(npar); npar.hide := TRUE; npar.device := dev; NEW(netspeed[i], npar); AddPlugin(netspeed[i], WMPerfMonComponents.GraphView);
				END;
				RETURN TRUE;
			ELSE
				netspeed := NIL;
				RETURN FALSE;
			END;
		END LocatePlugins;

		PROCEDURE Finalize*;
		VAR i : SIZE;
		BEGIN
			Finalize^;
			IF (netspeed # NIL) THEN
				FOR i := 0 TO LEN(netspeed)-1 DO
					WMPerfMonPlugins.updater.RemovePlugin(netspeed[i]);
				END;
			END;
		END Finalize;

	END NetworkComponent;

TYPE

	KillerMsg = OBJECT
	END KillerMsg;

	Window = OBJECT (WMComponents.FormWindow)
	VAR
		tabs : WMTabComponents.Tabs;
		tabList : ARRAY NbrOfTabs OF WMTabComponents.Tab;
		tabPanels : ARRAY NbrOfTabs OF WMComponents.VisualComponent;

		tabPanel : WMStandardComponents.Panel;
		curTabPanel : WMComponents.VisualComponent;
		curTab : WMTabComponents.Tab;

		cpuMemory : CpuMemoryComponent;
		network : NetworkComponent;
		selection : WMPerfMonComponents.SelectionComponent;

		width, height : SIZE;

		PROCEDURE Resized*(width, height : SIZE);
		BEGIN
			IF (width >= MinWidth) & (height >= MinHeight) THEN
				scaling := FALSE;
				SELF.width := width; SELF.height := height;
			ELSE
				scaling := TRUE;
			END;
			Resized^(width, height);
		END Resized;

		PROCEDURE CreateForm(): WMComponents.VisualComponent;
		VAR
			panel : WMStandardComponents.Panel;
			alerts : WMPerfMonTabAlerts.AlertsTab; systemPanel : WMPerfMonTabSystem.SystemTab;
			processManager : WMProcessInfo.ProcessManager;
			caption : Strings.String; i : LONGINT;
		BEGIN
			panel := WMPerfMonComponents.NewPanel(WMComponents.AlignClient, 0, 0);

			NEW(tabs);  tabs.bounds.SetHeight(20); tabs.alignment.Set(WMComponents.AlignTop);
			tabs.onSelectTab.Add(TabSelected);
			IF ~WMPerfMonComponents.UseSkinColors THEN
				tabs.clTextDefault.Set(WMGraphics.White);
				tabs.clTextHover.Set(WMGraphics.Black);
				tabs.clTextSelected.Set(WMGraphics.Black);
				tabs.clHover.Set(WMGraphics.White);
				tabs.clSelected.Set(WMGraphics.White);
			END;
			panel.AddContent(tabs);

			NEW(tabPanel); tabPanel.alignment.Set(WMComponents.AlignClient);
			panel.AddContent(tabPanel);

			NEW(cpuMemory); tabPanels[0] := cpuMemory; cpuMemory.bearing.Set(WMRectangles.MakeRect(2,5,2,2));
			NEW(network); tabPanels[1] := network; network.bearing.Set(WMRectangles.MakeRect(2,5,2,2));
			NEW(systemPanel); tabPanels[2] := systemPanel;
			NEW(processManager); tabPanels[3] := processManager;
			NEW(selection); tabPanels[4] := selection;
			NEW(alerts); tabPanels[5] := alerts;

			FOR i := 0 TO NbrOfTabs-1 DO
				tabPanels[i].alignment.Set(WMComponents.AlignClient);
				tabPanels[i].visible.Set(FALSE);
				tabList[i] := tabs.NewTab(); tabs.AddTab(tabList[i]);
				IF ~WMPerfMonComponents.UseSkinColors THEN tabs.SetTabColor(tabList[i], WMGraphics.Black); END;
				CASE i OF
					(* Note: Characters used for caption must be allowed in XML attributes *)
					|0: caption := Strings.NewString("CPU/Memory");
					|1: caption := Strings.NewString("Network");
					|2: caption := Strings.NewString("System");
					|3: caption := Strings.NewString("Processes");
					|4: caption := Strings.NewString("Plugins");
					|5: caption := Strings.NewString("Alerts");
				ELSE
					caption := Strings.NewString("Unnamed");
				END;
				tabs.SetTabCaption(tabList[i], caption);
				tabs.SetTabData(tabList[i], tabPanels[i]);
				tabPanel.AddContent(tabPanels[i]);
			END;

			curTabPanel := cpuMemory; curTab := tabList[0]; curTabPanel.visible.Set(TRUE);
			RETURN panel
		END CreateForm;

		PROCEDURE TabSelected(sender, data : ANY);
		VAR tab : WMTabComponents.Tab;
		BEGIN
			IF (data # NIL) & (data IS WMTabComponents.Tab) THEN
				DisableUpdate;
				tab := data(WMTabComponents.Tab);
				IF (tab.data # NIL) & (tab.data IS WMComponents.VisualComponent) THEN
					curTabPanel.visible.Set(FALSE);
					curTab := tab;
					curTabPanel := tab.data(WMComponents.VisualComponent);
					curTabPanel.visible.Set(TRUE);
					tabPanel.Reset(SELF, NIL);
					tabPanel.AlignSubComponents;
				END;
				EnableUpdate;
				tabPanel.Invalidate;
				curTabPanel.Invalidate;
			END;
		END TabSelected;

		PROCEDURE SelectTabByName(CONST name : ARRAY OF CHAR);
		VAR i : LONGINT;
		BEGIN
			LOOP
				IF i >= LEN(tabList) THEN EXIT; END;
				IF (tabList[i] # NIL) & (Strings.Match(name, tabList[i].caption^)) THEN EXIT; END;
				INC(i);
			END;
			IF i < LEN(tabList) THEN tabs.Select(tabList[i]); TabSelected(SELF, tabList[i]); END;
		END SelectTabByName;

		PROCEDURE Handle*(VAR x: WMMessages.Message);
		VAR elem, data : WMRestorable.XmlElement;
		BEGIN
			IF (x.msgType = WMMessages.MsgExt) & (x.ext # NIL) THEN
				IF x.ext IS WMRestorable.Storage THEN
					NEW(data); data.SetName("Data");
					NEW(elem); elem.SetName("Configuration"); data.AddContent(elem);
					WMRestorable.StoreLongint(elem, "SampleInterval", WMPerfMonPlugins.updater.sampleInterval);
					WMRestorable.StoreLongint(elem, "SampleBufferSize", WMPerfMonPlugins.updater.sampleBufferSize);
					WMRestorable.StoreLongint(elem, "ScreenInterval", WMPerfMonPlugins.updater.screenInterval);
					WMRestorable.StoreString(elem, "CurrentTab", curTab.caption^);
					NEW(elem); elem.SetName("Size"); data.AddContent(elem);
					WMRestorable.StoreSize(elem, "Width", width);
					WMRestorable.StoreSize(elem, "Height", height);
					x.ext(WMRestorable.Storage).Add("WMPerfMon", "WMPerfMon.Restore", SELF, data);
				ELSIF x.ext IS KillerMsg THEN
					Close;
				ELSE Handle^(x)
				END
			ELSE Handle^(x)
			END
		END Handle;

		PROCEDURE Close*;
		BEGIN
			Close^;
			DecCount;
		END Close;

		PROCEDURE &New*(c : WMRestorable.Context);
		VAR
			vc : WMComponents.VisualComponent;
			configuration, size : WMRestorable.XmlElement;
			curTabName : ARRAY 32 OF CHAR;
			si, sbs, scri : LONGINT;
			scale : BOOLEAN;
		BEGIN
			vc := CreateForm(); scaling := FALSE; scale := FALSE;
			IF c # NIL THEN
				width := c.r - c.l; height :=  c.b - c.t;
				size := WMRestorable.GetElement(c, "Data\Size");
				IF size # NIL THEN
					WMRestorable.LoadSize(size, "Width", width);
					WMRestorable.LoadSize(size, "Height", height);
					IF (width < MinWidth) OR (height < MinHeight) THEN
						scale := TRUE;
					END;
				END;
			ELSE
				width := DefaultWidth; height := DefaultHeight;
			END;

			Init(width, height, FALSE);
			SetContent(vc);
			SetTitle(Strings.NewString("Performance Monitor 2.0"));
			SetIcon(WMGraphics.LoadImage("WMIcons.tar://WMPerfMon.png", TRUE));

			IF c # NIL THEN
				WMRestorable.AddByContext(SELF, c);
				configuration := WMRestorable.GetElement(c, "Data\Configuration");
				IF configuration # NIL THEN
					WMRestorable.LoadLongint(configuration, "SampleInterval", si);
					WMRestorable.LoadLongint(configuration, "SampleBufferSize", sbs);
					WMRestorable.LoadLongint(configuration, "ScreenInterval", scri);
					WMRestorable.LoadString(configuration, "CurrentTab", curTabName);
				END;
				IF (si # 0) & (sbs # 0) & (scri # 0) THEN
					WMPerfMonPlugins.updater.SetIntervals(si, sbs, scri);
				ELSE
					KernelLog.String("WMPerfMon: Could not restore config data."); KernelLog.Ln;
				END;
				IF curTabName # "" THEN SelectTabByName(curTabName); END;
				IF scale THEN Resized(c.r - c.l, c.b - c.t); END;
			ELSE
				WMWindowManager.DefaultAddWindow(SELF);
				SelectTabByName("CPU/Memory");
			END;
			IncCount;
		END New;

	END Window;

VAR
	nofWindows : LONGINT;

PROCEDURE Open*;
VAR w : Window;
BEGIN
	NEW(w, NIL);
END Open;

PROCEDURE Restore*(context : WMRestorable.Context);
VAR w : Window;
BEGIN
	NEW(w, context);
END Restore;

PROCEDURE IncCount;
BEGIN {EXCLUSIVE}
	INC(nofWindows);
END IncCount;

PROCEDURE DecCount;
BEGIN {EXCLUSIVE}
	DEC(nofWindows);
END DecCount;

PROCEDURE Cleanup;
VAR die : KillerMsg; msg : WMMessages.Message; m : WMWindowManager.WindowManager;
BEGIN {EXCLUSIVE}
	NEW(die); msg.ext := die; msg.msgType := WMMessages.MsgExt;
	m := WMWindowManager.GetDefaultManager();
	m.Broadcast(msg);
	AWAIT(nofWindows = 0);
END Cleanup;

BEGIN
	Modules.InstallTermHandler(Cleanup);
END WMPerfMon.

WMPerfMon.Open ~ 	System.Free WMPerfMon ~
