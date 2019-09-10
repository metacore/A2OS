MODULE WMPerfMonPluginInterrupts; (** AUTHOR "staubesv"; PURPOSE "Performance Monitor interrupt statistics plugin"; *)
(**
 * This Performance Monitor plugin counts the number of interrupt occurences for the first 64 interrupt vectors.
 *
 * Usage:
 *
 *	WMPerfMonPluginInterrupts.Install ~ loads this plugin		Use System.Free WMPerfMonPluginInterrupts ~ to unload it
 *
 *	Once loaded, the plugin is accessible using the Performance Monitor application -> WMPerfMon.Open ~
 *
 * Notes:
 *
 *	- 	This plugin is not intended to run in productive environments
 *	-	When this plugin is loaded, first-level interrupt handlers for the first 64 interrupt vectors  will be installed. As side effect, these
 *		interrupts are enabled. Keep this in mind.
 *	-	IRQ8 (Real Time Clock) is programmed to deliver one interrupt per second (see Clock)
 *
 *
 * History:
 *
 *	30.03.2007	First release (staubesv)
 *)

IMPORT
	WMPerfMonPlugins,
	Machine, Modules;

CONST
	ModuleName = "WMPerfMonPluginInterrupts";

TYPE

	InterruptStatistics = OBJECT(WMPerfMonPlugins.Plugin)

		PROCEDURE Init(p : WMPerfMonPlugins.Parameter);
		VAR ds : WMPerfMonPlugins.DatasetDescriptor;
		BEGIN
			p.name := "Interrupts"; p.description := "Interrupt statistics";
			p.modulename := ModuleName;
			p.autoMin := FALSE; p.autoMax := TRUE; p.minDigits := 7;

			NEW(ds, 44);
			(* pre-defined interrupts *)
			ds[0].name := "INT0-Divide Error";
			ds[1].name := "INT1-Reserved";
			ds[2].name := "INT2-NMI";
			ds[3].name := "INT3-Breakpoint";
			ds[4].name := "INT4-Overflow";
			ds[5].name := "INT5-BOUND range exceeded";
			ds[6].name := "INT6-Invalid Opcode";
			ds[7].name := "INT7-No Math Coprocessor";
			ds[8].name := "INT8-Double Fault";
			ds[9].name := "INT9-CoprocessorSegment Overrun";
			ds[10].name := "INT10-Invalid TSS";
			ds[11].name := "INT11-Segment not present";
			ds[12].name := "INT12-Stack segment fault";
			ds[13].name := "INT13-General Protection";
			ds[14].name := "INT14-Page Fault";
			ds[15].name := "INT15-Reserved";
			ds[16].name := "INT16-Math Fault";
			ds[17].name := "INT17-Alignment Check";
			ds[18].name := "INT18-Machine Check";
			ds[19].name := "INT19-SIMD FP Exception";

			ds[20].name := "INT32-IRQ0 (Timer)";
			ds[21].name := "INT33-IRQ1 (Keyboard)";
			(* IRQ 2 not monitored since used for cascading PICs *)
			ds[22].name := "INT35-IRQ3";
			ds[23].name := "INT36-IRQ4";
			ds[24].name := "INT37-IRQ5";
			ds[25].name := "INT38-IRQ6";
			ds[26].name := "INT39-IRQ7";
			ds[27].name := "INT40-IRQ8 (RTC)";
			ds[28].name := "INT41-IRQ9";
			ds[29].name := "INT42-IRQ10";
			ds[30].name := "INT43-IRQ11";
			ds[31].name := "INT44-IRQ12";
			ds[32].name := "INT45-IRQ13";
			ds[33].name := "INT46-IRQ14";
			ds[34].name := "INT47-IRQ15";

			ds[35].name := "INT49-SMP Kernel Call";
			ds[36].name := "INT58-SoftInt";
			ds[37].name := "INT59-SMP Local IPC";
			ds[38].name := "INT60-SMP Timer Interrupt";
			ds[39].name := "INT61-SMP IPC ";
			ds[40].name := "INT62-SMP Error Interrupt";
			ds[41].name := "INT63-SMP Spurious Interrupt";

			ds[42].name := "Total"; INCL(ds[42].flags, WMPerfMonPlugins.Sum);
			ds[43].name := "Others";
			p.datasetDescriptor := ds;
		END Init;

		PROCEDURE UpdateDataset;
		VAR i, offset, temp : SIGNED32;
		BEGIN
			FOR i := 0 TO 19 DO (* pre-defined interrupts *)
				dataset[i] := interrupts[i].count;
			END;
			offset := Machine.IRQ0;
			dataset[20] := interrupts[offset + 0].count;
			dataset[21] := interrupts[offset + 1].count;
			(* Skip IRQ 2 *)
			FOR i := 3 TO 15 DO
				dataset[22 - 3 + i] := interrupts[offset + i].count;
			END;
			dataset[35] := interrupts[49].count;
			dataset[36] := interrupts[58].count;
			dataset[37] := interrupts[59].count;
			dataset[38] := interrupts[60].count;
			dataset[39] := interrupts[61].count;
			dataset[40] := interrupts[62].count;
			dataset[41] := interrupts[63].count;

			temp := others;

			dataset[42] := temp;
			FOR i := 0 TO 41 DO
				dataset[42] := dataset[42] + dataset[i];
			END;
			dataset[43] := temp;
		END UpdateDataset;

	END InterruptStatistics;

	InterruptInfo = RECORD
		count : SIGNED32;
		handlerInstalled : BOOLEAN;
		isOther : BOOLEAN;
	END;

VAR
	interrupts : ARRAY 256 OF InterruptInfo;
	others : SIGNED32;

PROCEDURE HandleInterrupts(VAR state : Machine.State);
BEGIN
	IF (0 <= state.INT) & (state.INT < 256) THEN
		IF interrupts[state.INT].handlerInstalled THEN
			Machine.AtomicInc(interrupts[state.INT].count);
		ELSE
			Machine.AtomicInc(others);
		END;
	END;
END HandleInterrupts;

PROCEDURE RegisterHandlers;
VAR i : SIGNED32;
BEGIN
	FOR i := 0 TO LEN(interrupts)-1 DO interrupts[i].isOther := TRUE; END;
	FOR i := 0 TO 19 DO interrupts[i].isOther := FALSE; END;
	FOR i := 32 TO 47 DO interrupts[i].isOther := FALSE; END;
	interrupts[49].isOther := FALSE;
	FOR i := 58 TO 63 DO interrupts[i].isOther := FALSE; END;
	FOR i := 244 TO 253 DO interrupts[i].isOther := FALSE; END;

	FOR i := 0 TO 63 DO
		IF (i # 34) & (i # 39) THEN (* IRQ2 used for cascading *)
			Machine.InstallHandler(HandleInterrupts, i);
			interrupts[i].handlerInstalled := TRUE;
		END;
	END;
END RegisterHandlers;

PROCEDURE UnregisterHandlers;
VAR i : SIGNED32;
BEGIN
	FOR i := 0 TO LEN(interrupts)-1 DO
		IF interrupts[i].handlerInstalled THEN
			Machine.RemoveHandler(HandleInterrupts, i);
			interrupts[i].count := 0;
			interrupts[i].handlerInstalled := FALSE;
		END;
	END;
END UnregisterHandlers;

PROCEDURE InitPlugin;
VAR par : WMPerfMonPlugins.Parameter; plugin : InterruptStatistics;
BEGIN
	NEW(par); NEW(plugin, par);
END InitPlugin;

PROCEDURE Install*;
END Install;

PROCEDURE Cleanup;
BEGIN
	UnregisterHandlers;
	WMPerfMonPlugins.updater.RemoveByModuleName(ModuleName);
END Cleanup;

BEGIN
	Modules.InstallTermHandler(Cleanup);
	RegisterHandlers;
	InitPlugin;
END WMPerfMonPluginInterrupts.

WMPerfMonPluginInterrupts.Install ~		System.Free WMPerfMonPluginInterrupts ~
