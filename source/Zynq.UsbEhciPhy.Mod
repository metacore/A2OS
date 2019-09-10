MODULE UsbEhciPhy; (** AUTHOR "Timothée Martiel"; PURPOSE "TUSB1210 USB EHCI PHY Control"; *)

IMPORT SYSTEM, Kernel, KernelLog, Gpio, UsbDebug;

CONST
	(* Ulpi Viewport bits *)
	UlpiWakeup = 31;
	UlpiRun = 30;
	UlpiWrite = 29;
	UlpiAddressMask = {16 .. 23};
	UlpiAddressOfs = 16;
	UlpiWriteDataMask = {0 .. 7};

	(* ULPI addresses *)
	FuncCtrl = 4H;
	FuncCtrlSet = 5H;
	FuncCtrlClr = 6H;
	IfcCtrlSet = 8H;
	IfcCtrlClr = 9H;
	OtgCtrlSet = 0BH;
	OtgCtrlClr = 0CH;

	(* Register bits in FuncCtrl *)
	Reset = 5;
	SuspendM = 6;
	Opmode = {3, 4};
	OpmodeNorm = {};
	XcvrSelect = {0, 1};
	XcvrHS = {};
	XcvrFS = {0};
	XcvrLS = {1};


	(* Register bits in OtgCtrl *)
	IdPullUp = 0;
	DmPullDown = 2;
	DpPullDown = 1;
	DrvVbus = 5;
	DrvVbusExt = 6;

	(* Default Timeout. Value comes from Linux implementation *)
	Timeout = 2000;

	(** Wakeup ULPI *)
	PROCEDURE Wakeup (viewport: ADDRESS): BOOLEAN;
	VAR
		timer: Kernel.MilliTimer;
		reg: SET;
	BEGIN
		Kernel.SetTimer(timer, Timeout);
		SYSTEM.PUT32(viewport, {UlpiWakeup});
		REPEAT
			reg := SYSTEM.VAL(SET, SYSTEM.GET32(viewport))
		UNTIL ~(31 IN reg) OR Kernel.Expired(timer);
		IF (31 IN reg) & (UsbDebug.Level >= UsbDebug.Errors) THEN
			KernelLog.String("TUSB1210 UsbEhciPhy: could not wakeup PHY");
			KernelLog.Ln
		END;
		RETURN ~(31 IN reg)
	END Wakeup;

	(** Write to ULPI register *)
	PROCEDURE Write(viewport, address: ADDRESS; value: SET): BOOLEAN;
	VAR
		timer: Kernel.MilliTimer;
		reg: SET;
	BEGIN
		IF ~Wakeup(viewport) THEN RETURN FALSE END;
		Kernel.SetTimer(timer, Timeout);
		SYSTEM.PUT32(viewport, SYSTEM.VAL(SET, value) * UlpiWriteDataMask + SYSTEM.VAL(SET, LSH(address, UlpiAddressOfs)) * UlpiAddressMask + {UlpiWrite, UlpiRun});
		REPEAT
			SYSTEM.GET(viewport, reg);
		UNTIL ~(30 IN reg) OR Kernel.Expired(timer);
		IF (30 IN reg) & (UsbDebug.Level >= UsbDebug.Errors) THEN
			KernelLog.String("TUSB1210 UsbEhcuPhy: could not write to PHY");
			KernelLog.Ln
		END;
		RETURN ~(30 IN reg)
	END Write;

	(**
	 * Inits the ULPI via the Viewport register of the EHCI controller.
	 * Has to be done when the controller is configured and running.
	 *
	 * 'viewport' is the address of the viewport register. 'reset' is the GPIO
	 * pin to which the full ULPI reset is wired (negative if not available).
	 *)
	PROCEDURE Init * (viewport: ADDRESS; reset: SIGNED32): BOOLEAN;
	VAR
		i: SIGNED32;
	BEGIN
		IF reset >= 0 THEN
			Gpio.SetDirection(reset, Gpio.Output);
			Gpio.EnableOutput(reset, TRUE);
			Gpio.SetData(reset, TRUE);
			Gpio.SetData(reset, FALSE);
			(*! TODO: Wait 2 us *)
			FOR i := 0 TO 1000000 DO END;
			Gpio.SetData(reset, TRUE)
		ELSE
			KernelLog.Enter; KernelLog.String("Skipping GPIO USB reset"); KernelLog.Exit
		END;

		(* Reset *)
		IF viewport # 0 THEN
			IF ~Write(viewport, FuncCtrlSet, {Reset}) THEN RETURN FALSE END;
			IF ~Write(viewport, OtgCtrlSet, {DmPullDown, DpPullDown, IdPullUp}) THEN RETURN FALSE END;
			IF ~Write(viewport, FuncCtrlSet, {2, SuspendM} + OpmodeNorm + XcvrLS) THEN RETURN FALSE END;
			IF ~Write(viewport, FuncCtrlClr, {0 .. 6} - OpmodeNorm  - XcvrLS - {2, SuspendM}) THEN RETURN FALSE END;
			IF ~Write(viewport, OtgCtrlSet, {DrvVbus, DrvVbusExt}) THEN RETURN FALSE END;
			IF ~Write(viewport, FuncCtrlClr, {2}) THEN RETURN FALSE END
		ELSE
			KernelLog.Enter; KernelLog.String("Skipping USB Viewport reset"); KernelLog.Exit
		END;
		KernelLog.Enter; KernelLog.String("USB PHY Initialized sucessfully"); KernelLog.Exit;
		RETURN TRUE
	END Init;
END UsbEhciPhy.
