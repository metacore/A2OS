(**
	AUTHOR: Timothee Martiel, Alexey Morozov
	PURPOSE: A2 Serials interface for Zynq PS UARTs
*)
MODULE PsSerials;

IMPORT Platform, BootConfig, Modules, Strings, PsUartMin, PsUart, Serials, Objects, Machine;

TYPE
	Port = OBJECT (Serials.Port)
	VAR
		uart: PsUart.UartController;

		recvLocked := FALSE : BOOLEAN;
		sendLocked := FALSE : BOOLEAN;

		PROCEDURE & Init (id: PsUart.UartId);
		BEGIN
			uart := PsUart.GetUart(id);
			ASSERT(uart # NIL);
		END Init;

		PROCEDURE Open (bps, data, parity, stop : LONGINT; VAR res: WORD);
		BEGIN{EXCLUSIVE}
			PsUart.Open(uart, bps, data, parity, stop, res);
		END Open;

		PROCEDURE Close;
		BEGIN{EXCLUSIVE}
			PsUart.Close(uart);
		END Close;

		PROCEDURE BusyLoopCallback(VAR res: WORD): BOOLEAN;
		BEGIN
			IF uart.open THEN
				Objects.Yield;
				RETURN TRUE;
			ELSE
				res := Serials.Closed;
				RETURN FALSE;
			END;
		END BusyLoopCallback;

		PROCEDURE BusyLoopCallback0(VAR res: WORD): BOOLEAN;
		BEGIN
			IF uart.open THEN
				RETURN TRUE;
			ELSE
				res := Serials.Closed;
				RETURN FALSE;
			END;
		END BusyLoopCallback0;

		(* This method can be safely used for trace output *)
		PROCEDURE SendChar(char: CHAR; VAR res: WORD);
		BEGIN
			(*! use BusyLoopCallback0 method to make sure no low-level lock is acquired here - required when used as trace output *)
			PsUart.SendChar(uart, char, TRUE, BusyLoopCallback0, res);
		END SendChar;

		(*! This method must not be used for trace output - danger of a dead lock! *)
		PROCEDURE Send(CONST buf: ARRAY OF CHAR; ofs, len: SIZE; propagate: BOOLEAN; VAR res: WORD);
		BEGIN
			Machine.AcquireObject(sendLocked);
			PsUart.Send(uart, buf, ofs, len, propagate, BusyLoopCallback, res);
		FINALLY
			Machine.ReleaseObject(sendLocked);
		END Send;

		PROCEDURE ReceiveChar(VAR char: CHAR; VAR res: WORD);
		BEGIN
			Machine.AcquireObject(recvLocked);
			char := PsUart.ReceiveChar(uart, BusyLoopCallback, res);
		FINALLY
			Machine.ReleaseObject(recvLocked);
		END ReceiveChar;

		PROCEDURE Receive(VAR buf: ARRAY OF CHAR; ofs, size, min: SIZE; VAR len: SIZE; VAR res: WORD);
		BEGIN
			Machine.AcquireObject(recvLocked);
			PsUart.Receive(uart, buf, ofs, size, min, len, BusyLoopCallback, res);
		FINALLY
			Machine.ReleaseObject(recvLocked);
		END Receive;

		PROCEDURE Available(): SIZE;
		BEGIN
			RETURN PsUart.Available(uart);
		END Available;

		PROCEDURE GetPortState(VAR openstat : BOOLEAN; VAR bps, data, parity, stop : LONGINT);
		BEGIN{EXCLUSIVE}
			openstat := uart.open;
			bps := uart.bps;
			data := uart.data;
			parity := uart.parity;
			stop := uart.stop;
		END GetPortState;

	END Port;

VAR
	ports: ARRAY 2 OF Port;

	PROCEDURE Init;
	VAR
		i: SIZE;
		clk: PsUart.ClockFrequency; res: WORD;
		name, desc: ARRAY 32 OF CHAR;
		tracePort: SIZE;
	BEGIN
		clk := BootConfig.GetIntValue("UartInputClockHz");
		FOR i := 0 TO LEN(Platform.UartBase,0)-1 DO
			PsUart.Install(i, Platform.UartBase[i], clk, res);
		END;

		(* if one of PS UART's is used for tracing, make the corresponding port open to allow trace output via PsUartMin *)
		tracePort := BootConfig.GetIntValue("TracePort");
		IF (tracePort >= 1) & (tracePort <= LEN(Platform.UartBase,0)) THEN
			PsUart.Open(PsUart.GetUart(tracePort-1), BootConfig.GetIntValue("TraceBPS"),PsUartMin.DefaultDataBits,PsUartMin.DefaultParity,PsUartMin.DefaultStop, res);
		ELSE tracePort := -1;
		END;

		FOR i := 0 TO LEN(ports) - 1 DO
			NEW(ports[i], i);
			name := "UART";
			Strings.AppendInt(name, i+1);
			desc := "Zynq PS UART";
			Strings.AppendInt(desc, i);
			Serials.RegisterOnboardPort(i+1, ports[i], name, desc);
		END;

		IF tracePort >= 0 THEN
			(* switch from PsUartMin to port-based trace output *)
			Serials.SetTracePort(tracePort, BootConfig.GetIntValue("TraceBPS"),PsUartMin.DefaultDataBits,PsUartMin.DefaultParity,PsUartMin.DefaultStop, res);
		END;
		Modules.InstallTermHandler(Cleanup)
	END Init;

	PROCEDURE Cleanup;
	VAR i: SIZE;
	BEGIN
		FOR i := 0 TO LEN(ports) - 1 DO
			IF ports[i] # NIL THEN Serials.UnRegisterPort(ports[i]) END
		END
	END Cleanup;

BEGIN
	Init
END PsSerials.
