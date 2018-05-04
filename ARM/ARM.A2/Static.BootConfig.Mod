MODULE BootConfig; (** AUTHOR "Timothée Martiel"; PURPOSE "System boot configuration, defined with constants"; *)
IMPORT ARMRuntime;
CONST
	(* ===== Units ===== *)
	k = 1024;
	M = k * k;
	G = k * k * k;

	(* ===== Clock Frequencies ===== *)
	PsRefClockHz = 333333333; (** Processing System (PS) external reference clock frequency in Hz *)
	CpuClockHz = 666666666; (** CPU clock frequency in Hz *)

	(* ===== Uart Parameters ===== *)
	UartInputClockHz = 50000000;
	TracePort = 2; (* index of UART controller +1 used for kernel output; -1 if UART is not used for kernel output *)
	TraceBPS = 115200; (* trace UART baudrate *)

	(* ===== USB Parameters ===== *)
	UsbPhyRstGpio = [-1, -1]; (** USB PHY reset GPIOs *)
	UsbEnable = [TRUE, FALSE]; (** Which USB controller to enable ? *)
	UsbViewportInit = TRUE; (** Use USB Viewport mechanism to reset PHY? *)

	(* ===== SD Parameters ===== *)
	SdClocks = [PsRefClockHz, PsRefClockHz];
	SdEnable = [TRUE, FALSE];

	(* ===== System Configuration ===== *)
	(* CPUs *)
	CpuNb = 2;
	(* Memory *)
	DDRSize = 512 * M;
	(* Maximal space reserved for boot config string *)
	ConfigSize = 0;
	(* Maximal heap size, including kernel image. All the rest of the memory will be used by stacks. *)
	HeapSize = 448 * M;
	KernelLoadAdr = M;
	(* Size of a single process stack. Min: 8kB. 4kB of the stack are used as guard and will not be available for data. *)
	StackSize = 256 * k;
	(* Globally activate caching *)
	EnableCaching = TRUE;

	(** Actiate Watchdog and reset it at each Timeslice *)
	EnableKernelWatchdog = TRUE;

	(* DYNAMIC CONFIGURATION *)
	(* ===== Heap Config ===== *)
	EnableFreeLists = FALSE;
	EnableReturnBlocks = FALSE;

	(* ===== Trace information ===== *)
	TraceHeaps = FALSE;
	TraceModules = FALSE;
	TraceInterrupts = FALSE;

	(* ===== BootConsole ===== *)
	BootVol1 = "";
	AosFS = "";
	Boot = "";
	Boot1 = "";
	Boot2 = "";
	Boot3 = "";
	Boot4 = "";
	Boot5 = "";
	Boot6 = "";
	Boot7 = "";
	Boot8 = "";
	Boot9 = "";

	PROCEDURE GetValue * (CONST key: ARRAY OF CHAR; VAR value: ARRAY OF CHAR);
	BEGIN
		IF key = "ClockMode" THEN value := "1"
		ELSIF key = "ConfigSize" THEN WriteIntValue(ConfigSize, value)
		ELSIF key = "CpuClockHz" THEN WriteIntValue(CpuClockHz, value)
		ELSIF key = "CpuNb" THEN WriteIntValue(CpuNb, value)
		ELSIF key = "DDRSize" THEN WriteIntValue(DDRSize, value)
		ELSIF key = "EnableCaching" THEN WriteBoolValue(EnableCaching, value)
		ELSIF key = "EnableFreeLists" THEN WriteBoolValue(EnableFreeLists, value)
		ELSIF key = "EnableKernelWatchdog" THEN WriteBoolValue(EnableKernelWatchdog, value)
		ELSIF key = "EnableReturnBlocks" THEN WriteBoolValue(EnableReturnBlocks, value)
		ELSIF key = "HardwareDetection" THEN value := "0"
		ELSIF key = "HeapSize" THEN WriteIntValue(HeapSize, value)
		ELSIF key = "KernelLoadAdr" THEN WriteIntValue(KernelLoadAdr, value)
		ELSIF key = "TracePort" THEN WriteIntValue(TracePort, value)
		ELSIF key = "TraceBPS" THEN WriteIntValue(TraceBPS, value)
		ELSIF key = "PsRefClockHz" THEN WriteIntValue(PsRefClockHz, value)
		ELSIF key = "SdClock0" THEN WriteIntValue(SdClocks[0], value)
		ELSIF key = "SdClock1" THEN WriteIntValue(SdClocks[1], value)
		ELSIF key = "SdEnable0" THEN WriteBoolValue(SdEnable[0], value)
		ELSIF key = "SdEnable1" THEN WriteBoolValue(SdEnable[1], value)
		ELSIF key = "StackSize" THEN WriteIntValue(StackSize, value)
		ELSIF key = "TraceHeaps" THEN WriteBoolValue(TraceHeaps, value)
		ELSIF key = "TraceInterrupts" THEN WriteBoolValue(TraceInterrupts, value)
		ELSIF key = "TraceModules" THEN WriteBoolValue(TraceModules, value)
		ELSIF key = "UartInputClockHz" THEN WriteIntValue(UartInputClockHz, value)
		ELSIF key = "UsbEnable0" THEN WriteBoolValue(UsbEnable[0], value)
		ELSIF key = "UsbEnable1" THEN WriteBoolValue(UsbEnable[1], value)
		ELSIF key = "UsbPhyRstGpio0" THEN WriteIntValue(UsbPhyRstGpio[0], value)
		ELSIF key = "UsbPhyRstGpio1" THEN WriteIntValue(UsbPhyRstGpio[1], value)
		ELSIF key = "UsbViewportInit" THEN WriteBoolValue(UsbViewportInit, value)

		ELSIF key = "BootVol1" THEN COPY(BootVol1, value)
		ELSIF key = "AosFS" THEN COPY(AosFS, value)
		ELSIF key = "Boot" THEN COPY(Boot, value)
		ELSIF key = "Boot1" THEN COPY(Boot1, value)
		ELSIF key = "Boot2" THEN COPY(Boot2, value)
		ELSIF key = "Boot3" THEN COPY(Boot3, value)
		ELSIF key = "Boot4" THEN COPY(Boot4, value)
		ELSIF key = "Boot5" THEN COPY(Boot5, value)
		ELSIF key = "Boot6" THEN COPY(Boot6, value)
		ELSIF key = "Boot7" THEN COPY(Boot7, value)
		ELSIF key = "Boot8" THEN COPY(Boot8, value)
		ELSIF key = "Boot9" THEN COPY(Boot9, value)
		ELSE value := ""
		END;
	END GetValue;

	PROCEDURE GetIntValue * (CONST key: ARRAY OF CHAR): LONGINT;
	VAR
		value: LONGINT;
	BEGIN
		IF key = "CpuClockHz" THEN value := CpuClockHz
		ELSIF key = "CpuNb" THEN value := CpuNb
		ELSIF key = "DDRSize" THEN value := DDRSize
		ELSIF key = "HeapSize" THEN value := HeapSize
		ELSIF key = "KernelLoadAdr" THEN value := KernelLoadAdr
		ELSIF key = "TracePort" THEN value := TracePort
		ELSIF key = "TraceBPS" THEN value := TraceBPS
		ELSIF key = "PsRefClockHz" THEN value := PsRefClockHz
		ELSIF key = "StackSize" THEN value := StackSize
		ELSIF key = "UartInputClockHz" THEN value := UartInputClockHz
		ELSIF key = "UsbPhyRstGpio0" THEN value := UsbPhyRstGpio[0]
		ELSIF key = "UsbPhyRstGpio1" THEN value := UsbPhyRstGpio[1]
		ELSE value := 0
		END;
		RETURN value
	END GetIntValue;

	PROCEDURE GetBoolValue * (CONST key: ARRAY OF CHAR): BOOLEAN;
	VAR
		res: BOOLEAN;
	BEGIN
		IF key = "EnableCaching" THEN res := EnableCaching
		ELSIF key = "EnableFreeLists" THEN res := EnableFreeLists
		ELSIF key = "EnableReturnBlocks" THEN res := EnableReturnBlocks
		ELSIF key = "TraceHeaps" THEN res := TraceHeaps
		ELSIF key = "TraceInterrupts" THEN res := TraceInterrupts
		ELSIF key = "TraceModules" THEN res := TraceModules
		ELSIF key = "UsbEnable0" THEN res := UsbEnable[0]
		ELSIF key = "UsbEnable1" THEN res := UsbEnable[1]
		ELSIF key = "UsbViewPortInit" THEN res := UsbViewportInit
		ELSE
			res := FALSE
		END;
		RETURN res
	END GetBoolValue;

	PROCEDURE Init *;
	END Init;

	PROCEDURE WriteIntValue (i: LONGINT; VAR s: ARRAY OF CHAR);
	VAR j,k: LONGINT; digits: ARRAY 10 OF LONGINT;
	BEGIN
		IF (i = MIN(LONGINT)) THEN COPY("-2147483648", s)
		ELSE
			IF (i < 0) THEN i := -i; s[0] := "-"; j := 1
			ELSE j := 0
			END;

			k := 0; digits[k] := 0;
			WHILE (i > 0) DO
				digits[k] := i MOD 10; i := i DIV 10;
				INC(k)
			END;
			IF (k > 0) THEN DEC(k) END; (* no leading "0" *)

			WHILE (k >= 0) DO
				s[j] := CHR(digits[k] + ORD("0"));
				INC(j); DEC(k)
			END;
			s[j] := 0X
		END
	END WriteIntValue;

	PROCEDURE WriteBoolValue (b: BOOLEAN; VAR value: ARRAY OF CHAR);
	BEGIN
		IF b THEN
			value := "1"
		ELSE
			value := "0"
		END
	END WriteBoolValue;
END BootConfig.
