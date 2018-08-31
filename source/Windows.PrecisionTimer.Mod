(**
	AUTHOR: Alexey Morozov
	PURPOSE: high precision timer support for Windows platforms
*)
MODULE PrecisionTimer;

IMPORT
	SYSTEM, Kernel32, KernelLog;

TYPE
	Counter* = HUGEINT;

CONST

	(**
		Query timer counter in ticks
	*)
	PROCEDURE GetCounter*(): Counter;
	VAR counter: Counter;
	BEGIN
		IF Kernel32.QueryPerformanceCounter(SYSTEM.VAL(Kernel32.LargeInteger,counter)) # 0 THEN
			RETURN counter;
		ELSE
			RETURN 0;
		END;
	END GetCounter;

	(**
		Query timer tick frequency in Hz
	*)
	PROCEDURE GetFrequency*(): Counter;
	VAR frequencyInHz: Counter;
	BEGIN
		IF Kernel32.QueryPerformanceFrequency(SYSTEM.VAL(Kernel32.LargeInteger,frequencyInHz)) # 0 THEN
			RETURN frequencyInHz;
		ELSE
			RETURN 0;
		END;
	END GetFrequency;

	PROCEDURE InitMod;
	BEGIN
		KernelLog.String("PrecisionTimer: timer tick frequency is "); KernelLog.Int(GetFrequency(),0); KernelLog.String(" Hz"); KernelLog.Ln;
	END InitMod;

BEGIN
	InitMod;
END PrecisionTimer.

System.Free PrecisionTimer ~