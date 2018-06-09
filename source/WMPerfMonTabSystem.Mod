MODULE WMPerfMonTabSystem; (** AUTHOR "staubesv"; PURPOSE "Performance Monitor system tab"; *)

IMPORT
	Plugins := WMPerfMonPlugins, Perf := WMPerfMonComponents,
	Machine, Heaps, Kernel, Commands, Streams, Dates, Strings, UpTime,
	WMComponents, WMStandardComponents;

TYPE

	SystemTab* = OBJECT(WMComponents.VisualComponent)
	VAR
		clockrate : LONGINT; (* MHz, -1 if invalid *)

		(* GC Statistics *)
		gcCurrentRun : Perf.Indicator;
		line1, line2, line3 : Perf.Indicator;

		(* CPU clock rate detection *)
		cpuClockrate : Perf.Indicator;

		(* Timers *)
		milliTimer : Kernel.MilliTimer;
		lastTimestamp : HUGEINT;
		lastGcCyclesAllRuns : HUGEINT;
		lastNgc : LONGINT;
		started : BOOLEAN;
		startBtn : WMStandardComponents.Button;
		elapsed : Perf.Indicator;

		(* System information *)
		format : ARRAY 32 OF CHAR;
		timeLabel, uptimeLabel : Perf.Indicator;
		w : Streams.StringWriter;

		(* Performance Monitoring *)
		unloadBtn : WMStandardComponents.Button;

		timer : Kernel.Timer;
		alive, dead : BOOLEAN;

		PROCEDURE EstimateClockRate() : LONGINT;
		CONST Tries = 10;
		VAR
			try : LONGINT; done : BOOLEAN; clockrate : LONGINT;
			string, nbr : ARRAY 128 OF CHAR;
		BEGIN
			cpuClockrate.SetCaption("   CPU clock rate estimation...");
			try := 1; done := FALSE; clockrate := -1;
			WHILE ~done & (try <= Tries) DO
				IF Plugins.EstimateCpuClockrate(clockrate) THEN
					done := TRUE;
				END;
				INC(try);
			END;
			IF done THEN
				string := "   CPU clock rate is ";
				Strings.IntToStr(clockrate, nbr); Strings.Append(string, nbr);
				Strings.Append(string, "MHz (estimated)");
				cpuClockrate.SetCaption(string);
			ELSE
				cpuClockrate.SetCaption("   CPU clock rate estimation failed");
			END;
			RETURN clockrate;
		END EstimateClockRate;

		PROCEDURE HandleGcButton(sender, data : ANY);
		VAR
			string, nbr : ARRAY 128 OF CHAR;
			lastGcCyclesTot : HUGEINT;
			w : Streams.StringWriter;
		BEGIN
			IF clockrate = -1 THEN clockrate := EstimateClockRate(); END;

			lastGcCyclesTot := Heaps.NgcCyclesAllRuns;
			Kernel.GC;

			string := "   Last run: ";
			IF clockrate # -1 THEN
				Plugins.MsToString(Plugins.CyclesToMs(Heaps.NgcCyclesLastRun, clockrate), nbr);
			ELSE
				nbr := "Clockrate unkown";
			END;
			Strings.Append(string, nbr);
			gcCurrentRun.SetCaption(string);

			(* Number of GC runs & total GC time & max time*)
			NEW(w, 128);
			w.String("GC Runs: "); w.Int(Heaps.Ngc, 0); w.String("   GC Total Time: ");
			Plugins.MsToString(Plugins.CyclesToMs(Heaps.NgcCyclesAllRuns, clockrate), nbr); w.String(nbr);
			w.String("   GC longest run: ");
			Plugins.MsToString(Plugins.CyclesToMs(Heaps.NgcCyclesMax, clockrate), nbr); w.String(nbr);
			w.Get(string);
			line1.SetCaption(string);

			(* Mark phase *)
			w.Reset;
			w.String("Mark phase: "); w.Int(Heaps.Nmarked, 0); w.String(" blocks marked in ");
			Plugins.MsToString(Plugins.CyclesToMs(Heaps.NgcCyclesMark, clockrate), nbr); w.String(nbr);
			w.String(" ("); w.Int(Heaps.Nmark, 0); w.String(" calls to Heaps.Mark)");
			w.Get(string);
			line2.SetCaption(string);

			(* Sweep phase *)
			w.Reset;
			w.String("Sweep phase: "); w.Int(Heaps.NgcSweeps, 0); w.String(" calls to sweep in ");
			Plugins.MsToString(Plugins.CyclesToMs(Heaps.NgcSweepTime, clockrate), nbr); w.String(nbr);
			w.String(" (max "); 
			Plugins.MsToString(Plugins.CyclesToMs(Heaps.NgcSweepMax, clockrate), nbr); w.String(nbr);
			w.String(")");
			w.Get(string);
			line3.SetCaption(string);
		END HandleGcButton;

		PROCEDURE HandleDetectButton(sender, data : ANY);
		BEGIN
			clockrate := EstimateClockRate();
		END HandleDetectButton;

		PROCEDURE HandleTimerButton(sender, data : ANY);
		VAR string, nbr : ARRAY 128 OF CHAR; msTicks, msTimestamp, msGc, msDiff : LONGINT;
		BEGIN
			IF clockrate = -1 THEN clockrate := EstimateClockRate(); END;
			IF started THEN
				started := FALSE; startBtn.caption.SetAOC("Start");
				string := "   Time elapsed: ";
				msTicks := Kernel.Elapsed(milliTimer);
				msTimestamp := Plugins.CyclesToMs(Machine.GetTimer() - lastTimestamp, clockrate);
				Plugins.MsToString(msTicks, nbr);
				Strings.Append(string, nbr); Strings.Append(string, " (Ticks),  ");
				Plugins.MsToString(msTimestamp ,nbr);
				Strings.Append(string, nbr); Strings.Append(string, " (Timestamps), ");
				Strings.Append(string, "TimeDiff: ");
				msDiff := msTimestamp - msTicks; IF msDiff < 0 THEN msDiff := -msDiff; END;
				Plugins.MsToString(msDiff, nbr);
				Strings.Append(string, nbr);
				Strings.Append(string, ", GC Time: ");
				msGc := Plugins.CyclesToMs(Heaps.NgcCyclesAllRuns - lastGcCyclesAllRuns, clockrate);
				Plugins.MsToString(msGc, nbr); Strings.Append(string, nbr);
				Strings.Append(string, ", GC Runs: ");
				Strings.IntToStr(Heaps.Ngc - lastNgc, nbr); Strings.Append(string, nbr);
				elapsed.SetCaption(string);
			ELSE
				started := TRUE; startBtn.caption.SetAOC("Stop");
				Kernel.SetTimer(milliTimer, 0);
				lastTimestamp := Machine.GetTimer();
				lastGcCyclesAllRuns := Heaps.NgcCyclesAllRuns;
				lastNgc := Heaps.Ngc;
				elapsed.SetCaption("   Timer is running...");
			END;
		END HandleTimerButton;

		PROCEDURE HandleUnloadButton(sender, data : ANY);
		VAR msg : ARRAY 128 OF CHAR; res : WORD;
		BEGIN
			Commands.Call("System.FreeDownTo WMPerfMonPlugins", {}, res, msg);
		END HandleUnloadButton;

		PROCEDURE CreateSysinfoPanel() : WMStandardComponents.Panel;
		VAR
			panel, line : WMStandardComponents.Panel; label : WMStandardComponents.Label;
			caption : ARRAY 128 OF CHAR;

			PROCEDURE AppendBoolean(VAR string : ARRAY OF CHAR; value : BOOLEAN);
			BEGIN
				IF value THEN
					Strings.Append(string, "Yes");
				ELSE
					Strings.Append(string, "No");
				END;
			END AppendBoolean;

		BEGIN
			panel := Perf.NewGroupPanel("System Information", WMComponents.AlignTop, 100);

			(* First Line: Version *)
			line := Perf.NewPanel(WMComponents.AlignTop, 0, Perf.LineHeight); panel.AddContent(line);
			label := Perf.NewLabel("Version:", WMComponents.AlignLeft, 100, 0); line.AddContent(label);
			label := Perf.NewLabel(Machine.version, WMComponents.AlignClient, 0, 0); line.AddContent(label);

			(* Second Line: System Time *)
			line := Perf.NewPanel(WMComponents.AlignTop, 0, Perf.LineHeight); panel.AddContent(line);
			label := Perf.NewLabel("System Time:", WMComponents.AlignLeft, 100, 0); line.AddContent(label);
			timeLabel := Perf.NewIndicator("--", WMComponents.AlignClient, 0, 0); line.AddContent(timeLabel);

			(* Third Line: System Start time and up time *)
			line := Perf.NewPanel(WMComponents.AlignTop, 0, Perf.LineHeight); panel.AddContent(line);
			label := Perf.NewLabel("Start Time: ", WMComponents.AlignLeft, 100, 0); line.AddContent(label);

			Strings.FormatDateTime(format, UpTime.GetStartTime(), caption);
			label := Perf.NewLabel(caption, WMComponents.AlignLeft, 210, 0); line.AddContent(label);

			uptimeLabel := Perf.NewIndicator("--", WMComponents.AlignClient, 0, 0); line.AddContent(uptimeLabel);

			(* 4th Line: MMX/SSE/SSE2 capabilities *)

			line := Perf.NewPanel(WMComponents.AlignTop, 0, Perf.LineHeight); panel.AddContent(line);
			label := Perf.NewLabel("Capabilities:", WMComponents.AlignLeft, 100, 0); line.AddContent(label);

			caption := "MMX: "; AppendBoolean(caption, Machine.MMX IN Machine.features);
			Strings.Append(caption, ", SSE: "); AppendBoolean(caption, Machine.SSESupport);
			Strings.Append(caption, ", SSE2: "); AppendBoolean(caption, Machine.SSE2Support);

			label := Perf.NewLabel(caption, WMComponents.AlignClient, 0, 0); line.AddContent(label);

			RETURN panel;
		END CreateSysinfoPanel;

		PROCEDURE CreateGcStatisticsPanel() : WMStandardComponents.Panel;
		VAR panel : WMStandardComponents.Panel; line : WMStandardComponents.Panel;
		BEGIN
			panel := Perf.NewGroupPanel("Garbage Collector", WMComponents.AlignTop, 120);

			line := Perf.NewPanel(WMComponents.AlignTop, 0, 20); panel.AddContent(line);
			line.AddContent(Perf.NewButton("Run GC", HandleGcButton));

			gcCurrentRun := Perf.NewIndicator("", WMComponents.AlignClient, 0, 0);
			line.AddContent(gcCurrentRun);

			line1 := Perf.NewIndicator("", WMComponents.AlignTop, 0, 20); panel.AddContent(line1);
			line2 := Perf.NewIndicator("", WMComponents.AlignTop, 0, 20); panel.AddContent(line2);
			line3 := Perf.NewIndicator("", WMComponents.AlignTop, 0, 20); panel.AddContent(line3);

			RETURN panel;
		END CreateGcStatisticsPanel;

		PROCEDURE CreateCPUClockratePanel() : WMStandardComponents.Panel;
		VAR panel : WMStandardComponents.Panel;
		BEGIN
			panel := Perf.NewGroupPanel("CPU Clockrate", WMComponents.AlignTop, 45);
			panel.AddContent(Perf.NewButton("Detect", HandleDetectButton));

			cpuClockrate := Perf.NewIndicator("   Press button to detect CPU clockrate", WMComponents.AlignClient, 0, 0);
			panel.AddContent(cpuClockrate);

			RETURN panel;
		END CreateCPUClockratePanel;

		PROCEDURE CreateTimerPanel() : WMStandardComponents.Panel;
		VAR panel : WMStandardComponents.Panel;
		BEGIN
			panel := Perf.NewGroupPanel("Timers", WMComponents.AlignTop, 45);
			startBtn := Perf.NewButton("Start", HandleTimerButton); panel.AddContent(startBtn);
			elapsed := Perf.NewIndicator("   Press button to start time...", WMComponents.AlignClient, 0, 0); panel.AddContent(elapsed);
			RETURN panel;
		END CreateTimerPanel;

		PROCEDURE CreateUnloadPanel() : WMStandardComponents.Panel;
		VAR panel : WMStandardComponents.Panel;
		BEGIN
			panel := Perf.NewGroupPanel("Performance Monitoring", WMComponents.AlignTop, 45);
			unloadBtn := Perf.NewButton("Unload", HandleUnloadButton); panel.AddContent(unloadBtn);
			panel.AddContent(Perf.NewLabel("   Window close button just closes GUI. This closes all.", WMComponents.AlignClient, 0, 0));
			RETURN panel;
		END CreateUnloadPanel;

		PROCEDURE UpdateTime;
		VAR caption : ARRAY 64 OF CHAR;
		BEGIN
			(* System Time *)
			Strings.FormatDateTime(format, Dates.Now(), caption);
			timeLabel.SetCaption(caption);

			(* System Uptime *)
			w.Reset;
			w.String(" (Uptime: "); UpTime.ToStream(w); w.Char(")");
			w.Get(caption);
			uptimeLabel.SetCaption(caption);
		END UpdateTime;

		PROCEDURE Finalize*;
		BEGIN
			alive := FALSE;
			timer.Wakeup;
			BEGIN {EXCLUSIVE} AWAIT(dead); END;
			Finalize^;
		END Finalize;

		PROCEDURE &Init*;
		BEGIN
			Init^;
			SetNameAsString(StrSystemTab);
			NEW(timer); alive := TRUE; dead := FALSE;
			NEW(w, 64);
			format := "hh:nn:ss, wwww, mmmm d, yyyy";
			clockrate := -1; (* invalid *)
			AddContent(CreateSysinfoPanel());
			AddContent(CreateCPUClockratePanel());
			AddContent(CreateGcStatisticsPanel());
			AddContent(CreateTimerPanel());
			AddContent(CreateUnloadPanel());
		END Init;

	BEGIN {ACTIVE}
		WHILE alive DO
			IF visible.Get() THEN UpdateTime; END;
			timer.Sleep(500);
		END;
		BEGIN {EXCLUSIVE} dead := TRUE; END;
	END SystemTab;

VAR
	StrSystemTab : Strings.String;

BEGIN
	StrSystemTab := Strings.NewString("SystemTab");
END WMPerfMonTabSystem.
