MODULE PrecisionTimer; (** AUTHOR ""; PURPOSE ""; *)

IMPORT
	Machine, BootConfig;

TYPE
	Counter* = HUGEINT;

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
	frequencyInHz := BootConfig.GetIntValue("CpuClockHz");
END PrecisionTimer.
