MODULE UsbEhciZynq; (** AUTHOR "Timothée Martiel"; PURPOSE "Instal EHCI driver on Zynq systems."; *)
(**
 * The main purpose of this module is to install the EHCI driver on Zynq SoCs.
 * Call
 * 		UsbEhciZynq.Install ~
 * to install the driver and unload this module ro remove it.
 *
 * This module also patches the behavior of the EHCI driver to the Zynq host controller. The host controller is
 * not fully compliant with the EHCI specifications and has On-The-Go features that require additional steps in
 * the initialization. These differences are accounted for in the EnhancedHostController object provided here.
 *)
IMPORT SYSTEM, Platform, BootConfig, Machine, Objects, Kernel, KernelLog, Debug := UsbDebug, Usbdi, Usb, UsbHcdi, UsbEhci, UsbEhciPhy;

CONST
	HcUlpiViewport = 30H;
	HcOtgSc = 64H;
	HcUsbMode = 68H;
	TTCtrl * = 1CH;

	(* HcUsbMode bits *)
	ModeHost = {0, 1};
	ModeDevice = {1};
	ModeIdle = {};

	(* HcOtgSc bits *)
	OtgScId = 8;
	OtgScIdPu = 5;

	(* HcPortSc bits *)
	PortScPortSpeed = {26, 27};
	PortScPortSpeedLow = {26};
	PortScPortSpeedFull = {};
	PortScPortSpeedHigh = {27};

TYPE
	(** Zynq-specific EHCI driver. Uses the main implementation and adds Zynq-specific initialization code where needed. *)
	EnhancedHostController = OBJECT (UsbEhci.EnhancedHostController)
	VAR
		phyResetGpio: SIGNED32;

		PROCEDURE GetPortStatus * (port : SIGNED32; ack : BOOLEAN) : SET;
		VAR
			status, dword: SET;
		BEGIN
			status := GetPortStatus^(port, ack);
			dword := SYSTEM.VAL(SET, SYSTEM.GET32(ports[port]));
			IF UsbHcdi.PortStatusEnabled * status # {} THEN
				IF dword * PortScPortSpeed = PortScPortSpeedHigh THEN
					status := status + UsbHcdi.PortStatusHighSpeed
				ELSIF dword * PortScPortSpeed = PortScPortSpeedLow THEN
					status := status + UsbHcdi.PortStatusLowSpeed
				ELSIF dword * PortScPortSpeed = PortScPortSpeedFull THEN
					status := status + UsbHcdi.PortStatusFullSpeed
				END
			END;
			RETURN status
		END GetPortStatus;

		PROCEDURE HasCompanion * (): BOOLEAN;
		BEGIN
			RETURN FALSE
		END HasCompanion;

		PROCEDURE ResetAndEnablePort (port: SIGNED32): BOOLEAN;
		VAR
			dword: SET;
			res: BOOLEAN;
		BEGIN
			res := ResetAndEnablePort^(port);
			IF res THEN
				dword := SYSTEM.VAL(SET, SYSTEM.GET32(iobase + HcUsbMode));
				dword := dword + ModeHost;
				SYSTEM.PUT32(iobase + HcUsbMode, dword);
			END;
			RETURN res
		END ResetAndEnablePort;

		(* Reset the host controller. Note: This will NOT assert reset on the USB downstream ports. *)
		PROCEDURE HardwareReset() : BOOLEAN;
		VAR
			viewportInit: ARRAY 32 OF CHAR;
			viewport: SIGNED32;
			dword: SET;
			res: BOOLEAN;
		BEGIN
			(* Set mode to host *)
			SYSTEM.GET(iobase + HcUsbMode, dword);
			SYSTEM.PUT(iobase + HcUsbMode, dword + ModeHost);

			res := HardwareReset^();

			IF res THEN
				(* Set mode to host *)
				SYSTEM.GET(iobase + HcUsbMode, dword);
				SYSTEM.PUT(iobase + HcUsbMode, dword + ModeHost);
				SYSTEM.GET(iobase + HcOtgSc, dword);
				INCL(dword, 7);
				INCL(dword, 5);
				SYSTEM.PUT(iobase + HcOtgSc, dword);

				(* Try putting port in full-speed mode *)
				SYSTEM.PUT(iobase + UsbEhci.HcPortSc, {8});
			END;
			IF ~res THEN
				RETURN FALSE
			END;
			Machine.GetConfig('UsbViewportInit', viewportInit);
			IF viewportInit = '0' THEN
				viewport := 0
			ELSE
				viewport := iobase + HcUlpiViewport
			END;
			RETURN UsbEhciPhy.Init(viewport, phyResetGpio)
		END HardwareReset;

		(*
		 * Start the host controller.
		 * This will:
		 * - enable interrupts for the host controller and install a interrupt handler
		 * - set the addresses for the periodic and asynchronous lists
		 * - turn the host controller on
		 * - route all ports to the EHCI controller
		 * - power on all ports of the root hub
	  	 *)
		PROCEDURE Start():BOOLEAN;
		VAR dword : SET;
			res: BOOLEAN;
		BEGIN
			res := Start^();
			IF ~res THEN RETURN FALSE END;

			(* Clear interrupts *)
			SYSTEM.PUT32(iobase + UsbEhci.HcUsbSts, 0);

			(* Enable all interrupts except the frame list rollover interrupt *)
			dword := SYSTEM.VAL(SET, SYSTEM.GET32(iobase + UsbEhci.HcUsbIntr));
			interruptsEnabled := dword + {0 .. 5} - UsbEhci.StsFrameListRollover + {19} (* UPI: triggered by iTD IOC *);
			SYSTEM.PUT32(iobase + UsbEhci.HcUsbIntr, interruptsEnabled);

			(* Set the TT HubAddress to 7FH *)
			(*SYSTEM.PUT32(iobase + 1CH, SYSTEM.VAL(SET, SYSTEM.GET32(iobase + (* TTCTRL *)1CH)) + {24 .. 30});*)

			RETURN TRUE
		END Start;

		PROCEDURE Schedule * (transfer: UsbHcdi.TransferToken);
		VAR
			address: SIGNED32;
		BEGIN
			IF (transfer.pipe.speed = UsbHcdi.LowSpeed) OR (transfer.pipe.speed = UsbHcdi.FullSpeed) THEN
				address := transfer.pipe.device(Usb.UsbDevice).ttAddress;
				IF address = 0 THEN
					address := transfer.pipe.address
				END;
			END;
			SYSTEM.PUT32(iobase + TTCtrl, LSH(address, 24));
			Schedule^(transfer);
		END Schedule;
	END EnhancedHostController;

VAR
	i: SIGNED32;

	(**
	 * Initializes and install the EHCI host controller driver on the host controller mapped at address iobase
	 * and using interrupt number irq.
	 *)
	PROCEDURE Init(irq, phyResetGpio: SIGNED32; iobase: ADDRESS);
	CONST
		(* Some part of the EHCI driver is PCI-related. These are dummy values for it. *)
		bus = 0;
		device = 0;
		function = 0;
	VAR
		hostController: EnhancedHostController;
	BEGIN
		NEW(hostController, bus, device, function);
		hostController.phyResetGpio := phyResetGpio;
		IF hostController.Init(iobase, irq) THEN
			KernelLog.String("UsbEhci: Initialised USB Enhanced Host Controller."); KernelLog.Ln;
			UsbHcdi.RegisterHostController(hostController, UsbEhci.Description);
		ELSE
			KernelLog.String("UsbEhci: Cannot init USB Enhanced Host Controller."); KernelLog.Ln;
		END;
	END Init;

	PROCEDURE Install*;
	(* Load module *)
	END Install;

BEGIN
	IF BootConfig.GetBoolValue("UsbEnable0") THEN
		KernelLog.Enter; KernelLog.String("Initializing USB"); KernelLog.Int(0, 0); KernelLog.String(", Address = "); KernelLog.Address(Platform.UsbBase[0]); KernelLog.String(", IRQ = "); KernelLog.Int(Platform.UsbIrq[0], 0); KernelLog.String(", PHY Reset = "); KernelLog.Int(BootConfig.GetIntValue("UsbPhyRstGpio0"), 0); KernelLog.Exit;
		Init(Platform.UsbIrq[0], BootConfig.GetIntValue("UsbPhyRstGpio0"), Platform.UsbBase[0])
	END;
	IF BootConfig.GetBoolValue("UsbEnable1") THEN
		KernelLog.Enter; KernelLog.String("Initializing USB"); KernelLog.Int(1, 0); KernelLog.String(", Address = "); KernelLog.Address(Platform.UsbBase[1]); KernelLog.String(", IRQ = "); KernelLog.Int(Platform.UsbIrq[1], 0); KernelLog.String(", PHY Reset = "); KernelLog.Int(BootConfig.GetIntValue("UsbPhyRstGpio1"), 0); KernelLog.Exit;
		Init(Platform.UsbIrq[1], BootConfig.GetIntValue("UsbPhyRstGpio1"), Platform.UsbBase[1])
	END
END UsbEhciZynq.
