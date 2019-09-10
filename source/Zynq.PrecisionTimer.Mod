(**
	AUTHOR: Alexey Morozov
	PURPOSE: high precision timer support for Xilinx Zynq platform
*)
MODULE PrecisionTimer;

IMPORT
	Machine, BootConfig;

TYPE
	Counter* = SIGNED64;

	(**
		Query timer counter in ticks
	*)
	PROCEDURE GetCounter*(): Counter;
	BEGIN
		RETURN Machine.GetTimer();
	END GetCounter;

	(**
		Query timer tick frequency in Hz
	*)
	PROCEDURE GetFrequency*(): Counter;
	BEGIN
		RETURN frequencyInHz;
	END GetFrequency;

VAR
	frequencyInHz: Counter;

BEGIN
	frequencyInHz := BootConfig.GetIntValue("CpuClockHz") DIV 2;
END PrecisionTimer.
