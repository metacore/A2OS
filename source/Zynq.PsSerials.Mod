MODULE PsSerials; (** AUTHOR "Timothée Martiel, 11/2017"; PURPOSE "Serial interface for Zynq PS UARTs"; *)

IMPORT Platform, BootConfig, Modules, Strings, PsUartMin, PsUart, Serials, Objects, Machine;

TYPE
	Port = OBJECT (Serials.Port)
	VAR
		uart: PsUart.UartController;
		
		sendCharLock := FALSE : BOOLEAN;

		PROCEDURE & Init (id: LONGINT);
		BEGIN
			uart := PsUart.GetUart(id);
			ASSERT(uart # NIL);
		END Init;

		PROCEDURE Open (bps, data, parity, stop : LONGINT; VAR res: LONGINT);
		BEGIN{EXCLUSIVE}
			PsUart.Open(uart, bps, data, parity, stop, res);
		END Open;

		PROCEDURE Close;
		BEGIN{EXCLUSIVE}
			PsUart.Close(uart);
		END Close;

		PROCEDURE Yield(VAR res: LONGINT): BOOLEAN;
		BEGIN
			IF uart.open THEN
				Objects.Yield;
				RETURN TRUE;
			ELSE
				res := Serials.Closed;
				RETURN FALSE;
			END;
		END Yield;

		PROCEDURE Yield0(VAR res: LONGINT): BOOLEAN;
		BEGIN
			IF uart.open THEN
				RETURN TRUE;
			ELSE
				res := Serials.Closed;
				RETURN FALSE;
			END;
		END Yield0;

		PROCEDURE SendChar(char: CHAR; VAR res: LONGINT);
		BEGIN
			Machine.AcquireObject(sendCharLock);
			(*! use Yield0 method to make sure no low-level lock is acquired here - required when used as trace output *)
			PsUart.SendChar(uart, char, TRUE, Yield0, res);
		FINALLY
			Machine.ReleaseObject(sendCharLock);
		END SendChar;

		PROCEDURE Send(CONST buf: ARRAY OF CHAR; ofs, len: LONGINT; propagate: BOOLEAN; VAR res: LONGINT);
		BEGIN
			PsUart.Send(uart, buf, ofs, len, propagate, Yield, res);
		END Send;

		PROCEDURE ReceiveChar(VAR char: CHAR; VAR res: LONGINT);
		BEGIN
			char := PsUart.ReceiveChar(uart, Yield, res);
		END ReceiveChar;

		PROCEDURE Receive(VAR buf: ARRAY OF CHAR; ofs, size, min: LONGINT; VAR len, res: LONGINT);
		BEGIN
			PsUart.Receive(uart, buf, ofs, size, min, len, Yield, res);
		END Receive;

		PROCEDURE Available(): LONGINT;
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
		i, clk, res: LONGINT;
		name, desc: ARRAY 32 OF CHAR;
		tracePort: LONGINT;
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
	VAR i: LONGINT;
	BEGIN
		FOR i := 0 TO LEN(ports) - 1 DO
			IF ports[i] # NIL THEN Serials.UnRegisterPort(ports[i]) END
		END
	END Cleanup;

BEGIN
	Init
END PsSerials.
