MODULE TraceDevice;
(**
	AUTHOR: Timothee Martiel, Alexey Morozov, HighDim GmbH, 2013-2017
	PURPOSE: simple abtraction for installing kernel tracing over Zynq PS UART
*)

IMPORT SYSTEM, Platform, BootConfig, Trace, PsUartMin;

VAR
	uart: PsUartMin.UartRegisters;

	PROCEDURE TraceChar(ch: CHAR);
	VAR res: WORD;
	BEGIN
		PsUartMin.SendChar(uart, ch, TRUE, NIL, res);
	END TraceChar;

	PROCEDURE Install *;
	VAR
		uartId: LONGINT;
		res: WORD;
	BEGIN
		Trace.Init;
		uartId := BootConfig.GetIntValue("TracePort")-1;

		PsUartMin.Install(uartId, Platform.UartBase[uartId], BootConfig.GetIntValue("UartInputClockHz"), res);
		IF res # 0 THEN RETURN; END;

		uart := PsUartMin.GetUart(uartId);

		IF ~PsUartMin.SetBps(uart, BootConfig.GetIntValue("TraceBPS"), res) THEN RETURN; END;
		PsUartMin.Enable(uart,TRUE);

		Trace.Char := TraceChar;
	END Install;

END TraceDevice.
