(**
	Test driver for USB controller for the ZedBoard.
	Here we just try to configure the EHCI controller in order to get the PortChangeInterrupt.

	Written by Timothée Martiel, 2014.
*)
MODULE UsbEhci;
IMPORT SYSTEM, Trace, Kernel, Objects, Machine;

CONST
	(* Base address of the controller *)
	BaseAddress = 0E0002140H;
	(* Interrupt *)
	IRQ = 53;

	(* Host Controller Capability Registers *)
	HcCapLength = 00H;
	HcCapHciVersion = 02H;
	HcCapSparams = 04H;
	HcCapCparams = 08H;
	HcCapPortroute = 0CH;

	(* Host Controller Operational Registers *)
	HcUsbCmd = 00H;
	HcUsbSts = 04H;
	HcUsbIntr = 08H;
	HcFrIndex = 0CH;
	(*HcCtrlDsSegment = 10H;*)
	HcPeriodicListBase = 14H;
	HcAsyncListAddr = 18H;
	HcUlpiViewport = 30H;
	HcConfigFlag = 40H;
	HcPortSc = 44H;
	HcUsbMode = 68H;
	HcOtgSc = 64H;

	(* HcUsbCmd register fields *)
	CmdInterruptThreshold = {16..23};
	CmdAsyncSchedParkMode = {11};
	CmdAsyncSchedParkCount = {8..9};
	CmdLightHcReset = {7}; (* Note: optional *)
	CmdAsyncAdvDoorbell = {6};
	CmdAsyncSchedEnable = {5};
	CmdPeriodicSchedEnable = {4};
	CmdFrameListSize = {2..3};
	CmdHcReset = {1};
	CmdRunStop = {0};
	CmdReserved = {10} + {12..15} + {24..31};

	(* HcUsbSts register fields *)
	StsAsyncSchedule = {15};
	StsPeriodicSchedule = {14};
	StsReclamation = {13};
	StsHcHalted = {12};
	(* HcUsbSts & HcUsbIntr common fields *)
 	StsAsyncAdvance= {5};
	StsHostSystemError = {4};
	StsFrameListRollover = {3};
	StsPortChange = {2};
	StsUsbError = {1};
	StsUsbInterrupt = {0};

	(* Port Status & Control register, EHCIspec p. 26-30 *)
	PscWakeOnOvercurrent = {22};
	PscWakeOnDisconnect = {21};
	PscWakeOnConnect = {20};
	PscTestControl = {16..19};
	PscIndicatorControl = {14..15};
	PscPortOwner = {13};
	PscPortPower = {12};
	PscLineStatus = {10..11};
	PscPortReset = {8};
	PscSuspend = {7};
	PscForcePortResume = {6};
	PscOvercurrentChange = {5};
	PscOvercurrentActive = {4};
	PscPortEnableChange = {3};
	PscPortEnable = {2};
	PscConnectStatusChange = {1};
	PscCurrentConnectStatus = {0};
	PscReserved = {9} + {23..31};
	PscChangeMask = {1, 3, 5};

	(* HcUsbMode bits *)
	ModeHost = {0, 1};
	ModeDevice = {1};
	ModeIdle = {};

	(* HcOtgSc bits *)
	OtgScId = 8;
	OtgScIdPu = 5;

	(* Timeout in milliseconds the HC must have completed the reset command *)
	MaxWaits = 1000;

	(* GPIO Registers & Pins *)
	Pin = 15;
	GpioData =	ADDRESS(0E000A040H);
	GpioDir =		ADDRESS(0E000A204H);
	GpioOen =		ADDRESS(0E000A208H);

VAR
	reg: SET;
	i: SIGNED32;
	t: Kernel.Timer;
	irqCounter: SIGNED32;

	(** Reports USB Interrupts *)
	PROCEDURE InterruptHandler;
	VAR s  : SET;
	BEGIN (* Works without being exclusive *)
		SYSTEM.GET(BaseAddress + HcUsbSts, s);
		s := s * ({0 .. 5} - StsFrameListRollover);

		IF s # {} THEN
			(* Reset interrupt status register (Write clear)*)
			SYSTEM.PUT32(BaseAddress + HcUsbSts, s * {0..5});

			IF s * StsAsyncAdvance # {} THEN
				Trace.StringLn("INTERRUPT: AsyncAdvance")
			END;
			IF s * StsHostSystemError # {} THEN
				Trace.StringLn("INTERRUPT: HostSystemError")
			END;
			IF s * StsFrameListRollover # {} THEN
				Trace.StringLn("INTERRUPT: FrameListRollover")
			END;
			IF s * StsPortChange # {} THEN
				Trace.StringLn("INTERRUPT: PortChange")
			END;
			IF s * (StsUsbError + StsUsbInterrupt) # {} THEN
				Trace.StringLn("INTERRUPT: UsbError or UsbInterrupt")
			END;
		END;
		Trace.String('IRQ Counter: '); Trace.Int(irqCounter, 0); Trace.Ln;
		INC(irqCounter)
	END InterruptHandler;

	(** Write to ULPI register *)
	PROCEDURE UlpiWrite(address: ADDRESS; value: SET);
	VAR
		viewport: ADDRESS;
		reg: SET;
	BEGIN
		viewport := SYSTEM.VAL(ADDRESS, value);
		INC(viewport, address * 10000H);
		INC(viewport, 60000000H);
		UlpiWakeup;
		SYSTEM.PUT(BaseAddress + HcUlpiViewport, viewport);
		Trace.String('ULPI Viewport: '); Trace.Address(SYSTEM.GET32(BaseAddress + HcUlpiViewport));
		REPEAT
			SYSTEM.GET(BaseAddress + HcUlpiViewport, reg);
			Trace.Ln; Trace.String("	"); Trace.Address(SYSTEM.VAL(ADDRESS, reg));
		UNTIL ~(30 IN reg);
		Trace.StringLn(" -- Transaction finished")
	END UlpiWrite;

	(** Wakeup ULPI *)
	PROCEDURE UlpiWakeup;
	VAR
		reg: SET;
	BEGIN
		SYSTEM.PUT(BaseAddress + HcUlpiViewport, {31});
		REPEAT
			SYSTEM.GET(BaseAddress + HcUlpiViewport, reg)
		UNTIL ~(31 IN reg);
	END UlpiWakeup;
BEGIN
	Trace.StringLn("Starting EHCI configuration");
	NEW(t);

	(* Install handler *)
	Objects.InstallHandler(InterruptHandler, Machine.IRQ0 + IRQ);

	(*
	(* Configure Pin 15 (USB0 Reset) as output *)
	SYSTEM.PUT(GpioDir, {Pin});
	SYSTEM.PUT(GpioOen, {Pin});

	(* Hold low state for at least 200ns *)
	SYSTEM.GET(GpioData, reg);
	SYSTEM.PUT(GpioData, reg - {Pin});
	t.Sleep(1000);
	SYSTEM.PUT(GpioData, reg + {Pin});
	SYSTEM.PUT32(0F8000210H, 1);
	t.Sleep(1000);
	SYSTEM.PUT32(0F8000210H, 0);
	t.Sleep(1000);
	SYSTEM.PUT32(0F8000210H, 1);
	*)

	(* Reset PHY.
		see: http://www.zedboard.org/content/bare-metal-usb-device-code
		C code:
			Xil_Out32(0xe000a204, 0x80);
			Xil_Out32(0xe000a208, 0x80);
			Xil_Out32(0xe000a040, 0x80);
			Xil_Out32(0xe000a040, 0x00);
			Xil_Out32(0xe000a040, 0x80);
	*)
	(*
	(* Setting MIO 8 as output *)
	SYSTEM.PUT32(0E000A204H, ADDRESS(0FFFFFFFFH));
	(* Setting MIO 8 enable output *)
	SYSTEM.PUT32(0E000A208H, ADDRESS(0FFFFFFFFH));
	(* set state of MIO 8 to 1, 0 and then 1 again *)
	SYSTEM.PUT32(0E000A040H, ADDRESS(0FFFFFFFFH));
	t.Sleep(100);
	SYSTEM.PUT32(0E000A040H, {});
	t.Sleep(100);
	SYSTEM.PUT32(0E000A040H, ADDRESS(0FFFFFFFFH));
	t.Sleep(100);
	*)

	(*
	(* Select ULPI clock source *)
	SYSTEM.GET(0F8000130H, reg);
	SYSTEM.PUT32(0F8000130H, reg + {6});
	*)

	(*
	(* USB0 reset *)
	SYSTEM.GET(0F8000210H, reg);
	SYSTEM.PUT32(0F8000210H, reg + {0});
	t.Sleep(20);
	SYSTEM.GET(0F8000210H, reg);
	SYSTEM.PUT32(0F8000210H, reg - {0});
	*)

	(* Get MIO pins 28 to 39 in USB mode *)
	SYSTEM.GET(0F8000770H, reg);
	Trace.String("MIO 28 state: "); Trace.Address(SYSTEM.VAL(ADDRESS, reg)); Trace.Ln;
	SYSTEM.GET(0F8000774H, reg);
	Trace.String("MIO 29 state: "); Trace.Address(SYSTEM.VAL(ADDRESS, reg)); Trace.Ln;
	SYSTEM.GET(0F8000778H, reg);
	Trace.String("MIO 30 state: "); Trace.Address(SYSTEM.VAL(ADDRESS, reg)); Trace.Ln;
	SYSTEM.GET(0F800077CH, reg);
	Trace.String("MIO 31 state: "); Trace.Address(SYSTEM.VAL(ADDRESS, reg)); Trace.Ln;
	SYSTEM.GET(0F8000780H, reg);
	Trace.String("MIO 32 state: "); Trace.Address(SYSTEM.VAL(ADDRESS, reg)); Trace.Ln;
	SYSTEM.GET(0F8000784H, reg);
	Trace.String("MIO 33 state: "); Trace.Address(SYSTEM.VAL(ADDRESS, reg)); Trace.Ln;
	SYSTEM.GET(0F8000788H, reg);
	Trace.String("MIO 34 state: "); Trace.Address(SYSTEM.VAL(ADDRESS, reg)); Trace.Ln;
	SYSTEM.GET(0F800078CH, reg);
	Trace.String("MIO 35 state: "); Trace.Address(SYSTEM.VAL(ADDRESS, reg)); Trace.Ln;
	SYSTEM.GET(0F8000790H, reg);
	Trace.String("MIO 36 state: "); Trace.Address(SYSTEM.VAL(ADDRESS, reg)); Trace.Ln;
	SYSTEM.GET(0F8000794H, reg);
	Trace.String("MIO 37 state: "); Trace.Address(SYSTEM.VAL(ADDRESS, reg)); Trace.Ln;
	SYSTEM.GET(0F8000798H, reg);
	Trace.String("MIO 38 state: "); Trace.Address(SYSTEM.VAL(ADDRESS, reg)); Trace.Ln;
	SYSTEM.GET(0F800079CH, reg);
	Trace.String("MIO 39 state: "); Trace.Address(SYSTEM.VAL(ADDRESS, reg)); Trace.Ln;

	(* Set mode to host *)
	SYSTEM.GET(BaseAddress + HcUsbMode, reg);
	SYSTEM.PUT(BaseAddress + HcUsbMode, reg + ModeHost);

	(* Stop *)
	SYSTEM.GET(BaseAddress + HcUsbCmd, reg);
	SYSTEM.PUT(BaseAddress + HcUsbCmd, reg - CmdRunStop);

	i := 1;
	SYSTEM.GET(BaseAddress + HcUsbSts, reg);
	WHILE (reg * StsHcHalted = {}) & (i <= MaxWaits) DO
		SYSTEM.GET(BaseAddress + HcUsbSts, reg);
		INC(i);
		t.Sleep(1);
	END;
	IF reg * StsHcHalted = {} THEN
		Trace.StringLn("ERROR: Controller did not stop");
		LOOP END
	ELSE
		Trace.StringLn("EHCI stopped")
	END;

	(* Reset *)
	SYSTEM.GET(BaseAddress + HcUsbCmd, reg);
	SYSTEM.PUT(BaseAddress + HcUsbCmd, reg + CmdHcReset);

	i := 1;
	SYSTEM.GET(BaseAddress + HcUsbCmd, reg);
	WHILE (i <= MaxWaits) & (reg * CmdHcReset # {}) DO
		SYSTEM.GET(BaseAddress + HcUsbCmd, reg);
		t.Sleep(1);
	END;
	IF i = MaxWaits THEN
		Trace.StringLn("ERROR: Reset timeout");
		LOOP END
	ELSE
		Trace.StringLn("EHCI reset")
	END;

	(* Clear interrupts *)
	SYSTEM.PUT32(BaseAddress + HcUsbSts, 0);

	(* Enable all interrupts except the frame list rollover interrupt *)
	SYSTEM.GET(BaseAddress + HcUsbIntr, reg);
	SYSTEM.PUT32(BaseAddress + HcUsbIntr, reg + {0 .. 5} - StsFrameListRollover);

	(* Port power in OTGSC *)
	SYSTEM.GET(BaseAddress + HcOtgSc, reg);
	INCL(reg, 1); EXCL(reg, 0);
	SYSTEM.PUT(BaseAddress + HcOtgSc, reg);

	(* Set mode to host *)
	SYSTEM.GET(BaseAddress + HcUsbMode, reg);
	SYSTEM.PUT(BaseAddress + HcUsbMode, reg + ModeHost);

	(* Port power in PortSc *)
	SYSTEM.GET(BaseAddress + HcPortSc, reg);
	SYSTEM.PUT32(BaseAddress + HcPortSc, reg + PscPortPower);
	t.Sleep(20); (* wait 20 ms for stable power *)

	(* Start EHCI *)
	SYSTEM.GET(BaseAddress + HcUsbCmd, reg);
	SYSTEM.PUT32(BaseAddress + HcUsbCmd, reg + CmdRunStop);

	(* Initialize ULPI. See linux_ehci.c *)
	(* Reset *)
	UlpiWrite(5H, {5});
	(* Set DRVVBUSEXTERNAL, DMPULLDOWN & DPPULLDOWN *)
	UlpiWrite(0BH, {1, 2});
	(* Set FULLSPEED, OPMODE NORMAL & SUSPENDM *)
	UlpiWrite(5H, {6});
	(* Set DRVVBUS & DRVVBUSEXT *)
	UlpiWrite(0BH, {5, 6});

	Trace.StringLn("END EHCI Configuration")
END UsbEhci.