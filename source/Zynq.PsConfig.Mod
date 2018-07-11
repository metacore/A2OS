(**
	AUTHOR "Alexey Morozov, HighDim GmbH, 2015";
	PURPOSE "Interface for system level configuration/control of Zynq Processing System (PS)";
*)
MODULE PsConfig;

IMPORT
	SYSTEM, Platform, BootConfig, Trace;

CONST
	(** error codes *)
	Ok* = 0;
	InvalidChannel* = 1; (** invalid channel (e.g. PL clock channel) specified *)
	InvalidClockSource* = 2; (** invalid clock source specified *)
	InvalidDivisor* = 3; (** invalid clock divisor value specified *)
	InvalidModule* = 4; (** invalid I/O module specified *)
	InvalidDevice* = 5; (** invalid I/O device for specified module *)

	UnknownError* = 256;

	(** PLL clock source types *)
	IoPll* = 0; (** IO PLL used as a clock source for IO peripherals *)
	ArmPll* = 1; (** ARM PLL used as a clock source for the CPU *)
	DdrPll* = 3; (** DDR PLL used as a clock source for DDR memory *)

	(** I/O Clock Modules *)
	IoUsb* = 0;
	IoGem* = 1;
	IoSdio* = 2;
	IoSmc* = 3;
	IoSpi* = 4;
	IoQuadSpi* = 5;
	IoUart* = 6;
	IoCan* = 7;
	IoGpio* = 8;
	IoI2c* = 9;

VAR
	psRefClockHz: HUGEINT;

	(**
		Get clock frequency of a given PLL clock source

		srcSel: source selector (either of IoPll, ArmPll, DdrPll)
		res: result code; zero in case of success

		Returns the frequency in Hz
	*)
	PROCEDURE GetPllClockFrequency*(srcSel: LONGINT; VAR res: LONGINT): HUGEINT;
	BEGIN
		CASE srcSel OF
			|IoPll: RETURN HUGEINT(LSH(SYSTEM.MSK(Platform.slcr.IO_PLL_CTRL,0x7F000),-12)) * psRefClockHz;
			|ArmPll: RETURN HUGEINT(LSH(SYSTEM.MSK(Platform.slcr.ARM_PLL_CTRL,0x7F000),-12)) * psRefClockHz;
			|DdrPll: RETURN HUGEINT(LSH(SYSTEM.MSK(Platform.slcr.DDR_PLL_CTRL,0x7F000),-12)) * psRefClockHz;
		ELSE
			res := InvalidClockSource; RETURN 0;
		END;
	END GetPllClockFrequency;

	(**
		Setup reset signals to programming logic

		assertedChannels: specifies the set of PL channels with asserted reset; can include 0, 1, 2, 3
		res: result code; zero in case of success

		Returns TRUE in case of success
	*)
	PROCEDURE SetPlResets*(assertedChannels: SET; VAR res: LONGINT): BOOLEAN;
	BEGIN
		IF assertedChannels * {4..31} # {} THEN res := InvalidChannel; RETURN FALSE; END;

		Platform.slcr.SLCR_UNLOCK := Platform.SlcrUnlockKey; (* enable writing to SLCR registers *)
		Platform.slcr.FPGA_RST_CTRL := assertedChannels;
		Platform.slcr.SLCR_LOCK := Platform.SlcrLockKey; (* disable writing to SLCR registers *)

		res := Ok;
		RETURN TRUE;
	END SetPlResets;

	(**
		Setup a given channel of Programming Logic (PL) clock

		channel: selected channel (either of 0, 1, 2, 3)
		srcSel: source selector (either of IoPll, ArmPll, DdrPll)
		divisor0: provides the divisor used to divide the source clock to generate the required generated clock frequency. First cascade divider.
		divisor1: provides the divisor used to divide the source clock to generate the required generated clock frequency. Second cascade divider.
		res: result code; zero in case of success

		Returns TRUE in case of success
	*)
	PROCEDURE SetPlClock*(channel: LONGINT; srcSel: LONGINT; divisor0, divisor1: LONGINT; VAR res: LONGINT): BOOLEAN;
	BEGIN
		IF (srcSel > 0) OR (srcSel > 3) THEN res := InvalidClockSource; RETURN FALSE; END;
		IF (divisor0 < 1) OR (divisor0 > 63) OR (divisor1 < 0) OR (divisor1 > 63) THEN res := InvalidDivisor; RETURN FALSE; END;

		Platform.slcr.SLCR_UNLOCK := Platform.SlcrUnlockKey; (* enable writing to SLCR registers *)

		CASE channel OF
			|0: Platform.slcr.FPGA0_CLK_CTRL := srcSel + LSH(divisor0,8) + LSH(divisor1,20);
			|1: Platform.slcr.FPGA1_CLK_CTRL := srcSel + LSH(divisor0,8) + LSH(divisor1,20);
			|2: Platform.slcr.FPGA2_CLK_CTRL := srcSel + LSH(divisor0,8) + LSH(divisor1,20);
			|3: Platform.slcr.FPGA3_CLK_CTRL := srcSel + LSH(divisor0,8) + LSH(divisor1,20);
		ELSE
			Platform.slcr.SLCR_LOCK := Platform.SlcrLockKey; (* disable writing to SLCR registers *)
			res := InvalidChannel;
			RETURN FALSE;
		END;

		Platform.slcr.SLCR_LOCK := Platform.SlcrLockKey; (* disable writing to SLCR registers *)

		res := Ok;
		RETURN TRUE;
	END SetPlClock;

	(**
		Get clock frequency of a given PL clock channel

		res: result code; zero in case of success

		Returns the frequency in Hz
	*)
	PROCEDURE GetPlClockFrequency*(channel: LONGINT; VAR res: LONGINT): HUGEINT;
	VAR
		d, srcSel, divisor0, divisor1: LONGINT;
	BEGIN
		CASE channel OF
			|0: d := Platform.slcr.FPGA0_CLK_CTRL;
			|1: d := Platform.slcr.FPGA1_CLK_CTRL;
			|2: d := Platform.slcr.FPGA2_CLK_CTRL;
			|3: d := Platform.slcr.FPGA3_CLK_CTRL;
		ELSE
			res := InvalidChannel;
			RETURN 0;
		END;

		srcSel := LSH(SYSTEM.MSK(d,0x30),-4);
		divisor0 := LSH(SYSTEM.MSK(d,0x3F00),-8);
		divisor1 := LSH(SYSTEM.MSK(d,0x3F00000),-20);

		RETURN GetPllClockFrequency(srcSel,res) DIV (divisor0*divisor1);
	END GetPlClockFrequency;

	(**
		Stop a given PL clock

		channel: clock channel number
		res: result code; zero in case of success

		Returns TRUE in case of success
	*)
	PROCEDURE StopPlClock*(channel: LONGINT; VAR res: LONGINT): BOOLEAN;
	BEGIN

		Platform.slcr.SLCR_UNLOCK := Platform.SlcrUnlockKey; (* enable writing to SLCR registers *)

		CASE channel OF
			|0: Platform.slcr.FPGA0_THR_CNT := 1;
			|1: Platform.slcr.FPGA1_THR_CNT := 1;
			|2: Platform.slcr.FPGA2_THR_CNT := 1;
			|3: Platform.slcr.FPGA3_THR_CNT := 1;
		ELSE
			Platform.slcr.SLCR_LOCK := Platform.SlcrLockKey; (* disable writing to SLCR registers *)
			res := InvalidChannel;
			RETURN FALSE;
		END;

		Platform.slcr.SLCR_LOCK := Platform.SlcrLockKey; (* disable writing to SLCR registers *)

		res := Ok;
		RETURN TRUE;
	END StopPlClock;

	(**
		Start a given PL clock

		channel: clock channel number
		res: result code; zero in case of success

		Returns TRUE in case of success
	*)
	PROCEDURE StartPlClock*(channel: LONGINT; VAR res: LONGINT): BOOLEAN;
	BEGIN
		Platform.slcr.SLCR_UNLOCK := Platform.SlcrUnlockKey; (* enable writing to SLCR registers *)

		CASE channel OF
			|0: Platform.slcr.FPGA0_THR_CNT := 0;
			|1: Platform.slcr.FPGA1_THR_CNT := 0;
			|2: Platform.slcr.FPGA2_THR_CNT := 0;
			|3: Platform.slcr.FPGA3_THR_CNT := 0;
		ELSE
			Platform.slcr.SLCR_LOCK := Platform.SlcrLockKey; (* disable writing to SLCR registers *)
			res := InvalidChannel;
			RETURN FALSE;
		END;

		Platform.slcr.SLCR_LOCK := Platform.SlcrLockKey; (* disable writing to SLCR registers *)

		res := Ok;
		RETURN TRUE;
	END StartPlClock;

	(**
		Stop given PL clocks

		channels: a set of clock channels to stop
		res: result code; zero in case of success

		Returns TRUE in case of success
	*)
	PROCEDURE StopPlClocks*(channels: SET; VAR res: LONGINT): BOOLEAN;
	BEGIN
		IF channels * {0,1,2,3} = {} THEN res := InvalidChannel; RETURN FALSE; END;

		Platform.slcr.SLCR_UNLOCK := Platform.SlcrUnlockKey; (* enable writing to SLCR registers *)

		IF 0 IN channels THEN Platform.slcr.FPGA0_THR_CNT := 1; END;
		IF 1 IN channels THEN Platform.slcr.FPGA1_THR_CNT := 1; END;
		IF 2 IN channels THEN Platform.slcr.FPGA2_THR_CNT := 1; END;
		IF 3 IN channels THEN Platform.slcr.FPGA3_THR_CNT := 1; END;

		Platform.slcr.SLCR_LOCK := Platform.SlcrLockKey; (* disable writing to SLCR registers *)

		res := Ok;
		RETURN TRUE;
	END StopPlClocks;

	(**
		Start given PL clocks

		channels: a set of clock channels to start
		res: result code; zero in case of success

		Returns TRUE in case of success
	*)
	PROCEDURE StartPlClocks*(channels: SET; VAR res: LONGINT): BOOLEAN;
	BEGIN
		IF channels * {0,1,2,3} = {} THEN res := InvalidChannel; RETURN FALSE; END;

		Platform.slcr.SLCR_UNLOCK := Platform.SlcrUnlockKey; (* enable writing to SLCR registers *)

		IF 0 IN channels THEN Platform.slcr.FPGA0_THR_CNT := 0; END;
		IF 1 IN channels THEN Platform.slcr.FPGA1_THR_CNT := 0; END;
		IF 2 IN channels THEN Platform.slcr.FPGA2_THR_CNT := 0; END;
		IF 3 IN channels THEN Platform.slcr.FPGA3_THR_CNT := 0; END;

		Platform.slcr.SLCR_LOCK := Platform.SlcrLockKey; (* disable writing to SLCR registers *)

		res := Ok;
		RETURN TRUE;
	END StartPlClocks;

	PROCEDURE GetIoClockFrequency*(module: LONGINT; VAR res: LONGINT): HUGEINT;
	VAR
		baseFreq: HUGEINT;
		val: LONGINT;
	BEGIN
		CASE module OF
			 IoUsb: (*!TODO*)
			|IoGem: (*!TODO*)
			|IoSdio: val := Platform.slcr.SDIO_CLK_CTRL;
			|IoSmc: val := Platform.slcr.SMC_CLK_CTRL;
			|IoSpi: val := Platform.slcr.SPI_CLK_CTRL;
			|IoQuadSpi: val := Platform.slcr.LQSPI_CLK_CTRL;
			|IoUart: val := Platform.slcr.UART_CLK_CTRL;
			|IoCan: (*!TODO*)
			|IoGpio: (*!TODO*)
			|IoI2c: (*!TODO*)
		ELSE
			res := InvalidModule;
			RETURN 0;
		END;
		CASE module OF
			 IoUsb: (*!TODO*)
			|IoGem: (*!TODO*)
			|IoSdio, IoSmc, IoSpi, IoQuadSpi, IoUart:
				val := LSH(SYSTEM.MSK(val, 0x3f00), -8)
			|IoCan:(*!TODO*)
			|IoGpio:(*!TODO*)
			|IoI2c:(*!TODO*)
		END;
		baseFreq := GetPllClockFrequency(GetIoClockSource(module, res), res);
		IF res # Ok THEN RETURN 0 END;
		RETURN baseFreq DIV val
	END GetIoClockFrequency;

	PROCEDURE GetIoClockSource*(module: LONGINT; VAR res: LONGINT): LONGINT;
	VAR
		pll, val: LONGINT;
	BEGIN
		res := Ok;
		CASE module OF
			 IoUsb: (*!TODO*)
			|IoGem: (*!TODO*)
			|IoSdio: val := Platform.slcr.SDIO_CLK_CTRL;
			|IoSmc: val := Platform.slcr.SMC_CLK_CTRL;
			|IoSpi: val := Platform.slcr.SPI_CLK_CTRL;
			|IoQuadSpi: val := Platform.slcr.LQSPI_CLK_CTRL;
			|IoUart: val := Platform.slcr.UART_CLK_CTRL;
			|IoCan: (*!TODO*)
			|IoGpio: (*!TODO*)
			|IoI2c: (*!TODO*)
		ELSE
			res := InvalidModule;
			RETURN -1;
		END;
		CASE module OF
			 IoUsb: (*!TODO*)
			|IoGem: (*!TODO*)
			|IoSdio, IoSmc, IoSpi, IoQuadSpi, IoUart:
				pll := LSH(SYSTEM.MSK(val, 0x30), -4);
				IF pll = 2 THEN pll := ArmPll END;
			|IoCan:(*!TODO*)
			|IoGpio:(*!TODO*)
			|IoI2c:(*!TODO*)
		END;
		RETURN pll
	END GetIoClockSource;

	PROCEDURE SetIoClockFrequency*(module: LONGINT; freq: HUGEINT; VAR res: LONGINT): BOOLEAN;
	VAR
		baseFreq: HUGEINT;
		val, div: LONGINT;
	BEGIN
		res := Ok;
		CASE module OF
			 IoUsb: (*!TODO*)
			|IoGem: (*!TODO*)
			|IoSdio: val := Platform.slcr.SDIO_CLK_CTRL;
			|IoSmc: val := Platform.slcr.SMC_CLK_CTRL;
			|IoSpi: val := Platform.slcr.SPI_CLK_CTRL;
			|IoQuadSpi: val := Platform.slcr.LQSPI_CLK_CTRL;
			|IoUart: val := Platform.slcr.UART_CLK_CTRL;
			|IoCan: (*!TODO*)
			|IoGpio: (*!TODO*)
			|IoI2c: (*!TODO*)
		ELSE
			res := InvalidModule;
			RETURN FALSE;
		END;
		baseFreq := GetPllClockFrequency(GetIoClockSource(module, res), res);
		IF res # Ok THEN RETURN FALSE END;

		Platform.slcr.SLCR_UNLOCK := Platform.SlcrUnlockKey; (* enable writing to SLCR registers *)
		CASE module OF
			 IoUsb: (*!TODO*)
			|IoGem: (*!TODO*)
			|IoSdio, IoSmc, IoSpi, IoQuadSpi, IoUart:
				div := LONGINT(baseFreq DIV freq);
				val := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, val) - {8 .. 13} + SYSTEM.VAL(SET, LSH(div, 8)) * {8 .. 13});
				Platform.slcr.SDIO_CLK_CTRL := val
			|IoCan:(*!TODO*)
			|IoGpio:(*!TODO*)
			|IoI2c:(*!TODO*)
		END;
		Platform.slcr.SLCR_LOCK := Platform.SlcrLockKey; (* disable writing to SLCR registers *)
		RETURN TRUE
	END SetIoClockFrequency;

	PROCEDURE SetIoClockSource*(module, source: LONGINT; VAR res: LONGINT): BOOLEAN;
	BEGIN
		
	END SetIoClockSource;

	PROCEDURE StartIoClock*(module, device: LONGINT; VAR res: LONGINT): BOOLEAN;
	BEGIN
		
	END StartIoClock;

	PROCEDURE StopIoClock*(module, device: LONGINT; VAR res: LONGINT): BOOLEAN;
	BEGIN
		
	END StopIoClock;

BEGIN
	psRefClockHz := BootConfig.GetIntValue("PsRefClockHz");
END PsConfig.