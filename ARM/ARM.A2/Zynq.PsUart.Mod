MODULE PsUart;
(**
	AUTHOR: Alexey Morozov, Timothee Martiel, HighDim GmbH, 2013-2018
	PURPOSE: driver implementation for Xilinx Zynq UART PS controller
*)

IMPORT SYSTEM, UartMin := PsUartMin, PsUartInterrupts, Trace;

CONST
	(** Receive errors - compatible with A2 Serials *)
	OverrunError* = 10;
	ParityError* = 11;
	FramingError* = 12;
	BreakInterrupt* = 13;

	DefaultRxBufSize* = 4096;
	DefaultTxBufSize* = 4096;

	ReceiveTimeoutInUs* = 500; (** Receive timeout in microseconds *)

	(* RX data interrupts *)
	RxDataInterrupts = {UartMin.XUARTPS_IXR_TOUT , UartMin.XUARTPS_IXR_RXFULL , UartMin.XUARTPS_IXR_RXOVR};

	(* RX error interrupts *)
	RxErrorInterrupts = {UartMin.XUARTPS_IXR_PARITY , UartMin.XUARTPS_IXR_FRAMING , UartMin.XUARTPS_IXR_OVER};

	(* TX data interrupts *)
	TxDataInterrupts = {UartMin.XUARTPS_IXR_TXEMPTY, UartMin.XUARTPS_IXR_TTRIG};

	(* TX error interrupts *)
	TxErrorInterrupts = {UartMin.XUARTPS_IXR_TOVR};

TYPE

	UartController* = POINTER TO RECORD
		id-: LONGINT; (** UART controller ID *)
		regs-: UartMin.UartRegisters; (** controller registers *)
		inputClock-: LONGINT; (** controller input clock in Hz *)
		bps-, data-, parity-, stop-: LONGINT; (** current parameter values *)

		open-: BOOLEAN; (** TRUE if the controller is open *)

		rxBuf: POINTER TO ARRAY OF CHAR; (* receive (RX) circular buffer *)
		rxBufRdPos, rxBufWrPos: LONGINT; (* RX buffer read and write positions *)

		txBuf: POINTER TO ARRAY OF CHAR; (* transmit (TX) circular buffer *)
		txBufRdPos, txBufWrPos: LONGINT; (* TX buffer read and write positions *)

		errors: SET;
	END;

VAR
	uarts: ARRAY 2 OF UartController;

	(* Disable all UART interrupts *)
	PROCEDURE DisableInterrupts(regs: UartMin.UartRegisters);
	BEGIN
		regs.idr := UartMin.XUARTPS_IXR_MASK;
	END DisableInterrupts;

	PROCEDURE IntrHandler(param: ANY);
	VAR
		uart: UartController;
		intrStatus: SET;
	BEGIN
		uart := param(UartController);
		(*Trace.String("imr="); Trace.Set(uart.regs.imr); Trace.Ln;
		Trace.String("isr="); Trace.Set(uart.regs.isr); Trace.Ln;*)

		intrStatus := uart.regs.imr * uart.regs.isr;
		uart.regs.isr := intrStatus; (* clear the interrupt *)

		(*Trace.String("intrStatus="); Trace.Set(intrStatus); Trace.Ln;*)

		IF intrStatus * (RxDataInterrupts+RxErrorInterrupts) # {} THEN
			IntrHandlerRx(uart,intrStatus);
		END;

		IF intrStatus * TxDataInterrupts # {} THEN
			IntrHandlerTx(uart,intrStatus);
		END;
	END IntrHandler;

	PROCEDURE IntrHandlerRx(uart: UartController; intrStatus: SET);
	VAR
		bufWrPos: LONGINT;
	BEGIN

		IF intrStatus * RxErrorInterrupts # {} THEN
			IF UartMin.XUARTPS_IXR_OVER IN intrStatus THEN
				INCL(uart.errors,OverrunError);
				Trace.String("---rx overrun(1)---: intrStatus="); Trace.Set(intrStatus); Trace.Ln;
				RETURN;
			END;
		END;

		bufWrPos := uart.rxBufWrPos;

		WHILE ~(UartMin.XUARTPS_SR_RXEMPTY IN uart.regs.sr) DO

			uart.rxBuf[bufWrPos] := CHR(uart.regs.fifo);
			INC(bufWrPos);
			IF bufWrPos = LEN(uart.rxBuf) THEN
				bufWrPos := 0;
			END;

			IF bufWrPos = uart.rxBufRdPos THEN
				INCL(uart.errors,OverrunError);
				Trace.String("---rx overrun(2)---: intrStatus="); Trace.Set(intrStatus); Trace.Ln;
				RETURN;
			END;
		END;

		uart.rxBufWrPos := bufWrPos;
	END IntrHandlerRx;

	PROCEDURE IntrHandlerTx(uart: UartController; intrStatus: SET);
	VAR bufRdPos: LONGINT;
	BEGIN
		IF intrStatus * TxErrorInterrupts # {} THEN
			IF UartMin.XUARTPS_IXR_TOVR IN intrStatus THEN
				INCL(uart.errors,OverrunError);
				Trace.String("---tx overrun---: intrStatus="); Trace.Set(intrStatus); Trace.Ln;
				RETURN;
			END;
		END;

		bufRdPos := uart.txBufRdPos;

		WHILE (bufRdPos # uart.txBufWrPos) & ~(UartMin.XUARTPS_SR_TXFULL IN uart.regs.sr) DO
			uart.regs.fifo := ORD(uart.txBuf[bufRdPos]);
			INC(bufRdPos);
			IF bufRdPos = LEN(uart.txBuf) THEN
				bufRdPos := 0;
			END;
		END;

		(* disable TX data interrupts if the buffer is empty *)
		IF bufRdPos = uart.txBufWrPos THEN
			uart.regs.idr := uart.regs.idr + TxDataInterrupts;
		END;

		uart.txBufRdPos := bufRdPos;
	END IntrHandlerTx;

	(*
		Returns TRUE if a cyclic buffer is full
	*)
	PROCEDURE BufIsFull(bufWrPos, bufRdPos, bufSize: LONGINT): BOOLEAN;
	BEGIN
		IF bufWrPos # (bufSize-1) THEN
			RETURN bufRdPos = (bufWrPos+1);
		ELSE
			RETURN bufRdPos = 0;
		END;
	END BufIsFull;

	(**
		Install a UART controller present in the system

		uart: ID (0-based index) of the UART controller to install
		base: controller base address
		inputClock: controller input clock in Hz
		res: returned error code, 0 in case of success
	*)
	PROCEDURE Install* (uart: LONGINT; base: ADDRESS; inputClock: LONGINT; VAR res: LONGINT);
	VAR ctl: UartController;
	BEGIN
		UartMin.Install(uart, base, inputClock, res);
		IF res # 0 THEN RETURN; END;

		NEW(ctl);
		uarts[uart] := ctl;

		ctl.id := uart;
		ctl.regs := UartMin.GetUart(uart);
		ctl.inputClock := inputClock;
		ctl.open := FALSE;
		ctl.bps := UartMin.DefaultBPS;
		ctl.data := UartMin.DefaultDataBits;
		ctl.parity := UartMin.DefaultParity;
		ctl.stop := UartMin.DefaultStop;

		NEW(ctl.rxBuf,DefaultRxBufSize);
		NEW(ctl.txBuf,DefaultTxBufSize);

		ASSERT(PsUartInterrupts.InstallInterruptHandler(uart,IntrHandler,ctl));
	END Install;

	(**
		Get UART controller with a given ID

		uart: UART controller ID

		Returns NIL in case if no controller with given ID has been installed
	*)
	PROCEDURE GetUart*(uart: LONGINT): UartController;
	BEGIN
		IF (uart >= 0) & (uart < LEN(uarts)) THEN
			RETURN uarts[uart];
		ELSE RETURN NIL;
		END;
	END GetUart;

	(**
		Open a UART controller

		uart: UART controller
		bps: baudrate
		data: number of data bits
		parity: parity control
		stop: number of stop bits
		res: returned error code, 0 in case of success
	*)
	PROCEDURE Open*(uart: UartController; bps, data, parity, stop: LONGINT; VAR res: LONGINT);
	VAR n: LONGINT;
	BEGIN
		IF uart.open THEN res := UartMin.PortInUse; RETURN; END;

		UartMin.Reset(uart.regs);

		IF ~UartMin.SetBps(uart.regs, bps, res) OR
			~UartMin.SetDataBits(uart.regs, data, res) OR
			~UartMin.SetParity(uart.regs, parity, res) OR
			~UartMin.SetStopBits(uart.regs, stop, res) THEN  RETURN;
		END;

		uart.bps := bps;
		uart.data := data;
		uart.parity := parity;
		uart.stop := stop;

		uart.rxBufWrPos := 0;
		uart.rxBufRdPos := 0;

		uart.txBufWrPos := 0;
		uart.txBufRdPos := 0;

		(* configure receive timeout to be as close as possible to ReceiveTimeoutInUs *)
		n := ENTIER((ReceiveTimeoutInUs*REAL(bps)+1000000) / 4000000 + 0.5);
		n := MAX(1,MIN(255,n-1));
		TRACE(n);
		uart.regs.rxtout := n;

		uart.regs.cr := uart.regs.cr + {UartMin.XUARTPS_CR_TORST}; (* restart receive timeout counter *)

		uart.regs.rxwm := 32; (* RX FIFO triggering threshold *)

		uart.regs.txwm := 32; (* TX FIFO triggering threshold *)

		uart.regs.ier := (RxDataInterrupts+RxErrorInterrupts+TxErrorInterrupts);

		UartMin.Enable(uart.regs,TRUE);

		uart.open := TRUE;
	END Open;

	(**
		Close a UART controller

		uart: UART controller
	*)
	PROCEDURE Close*(uart: UartController);
	BEGIN
		uart.open := FALSE;
		DisableInterrupts(uart.regs);
		UartMin.Enable(uart.regs,FALSE);
	END Close;

	PROCEDURE OccupiedBufSpace(bufWrPos, bufRdPos, bufSize: LONGINT): LONGINT;
	VAR n: LONGINT;
	BEGIN
		n := bufWrPos - bufRdPos;
		IF n >= 0 THEN
			RETURN n;
		ELSE
			RETURN n+bufSize;
		END;
	END OccupiedBufSpace;

	(* Returns the amount of available free space in a cyclic buffer *)
	PROCEDURE AvailableBufSpace(bufWrPos, bufRdPos, bufSize: LONGINT): LONGINT;
	VAR n: LONGINT;
	BEGIN
		n := bufWrPos - bufRdPos;
		IF n >= 0 THEN
			RETURN bufSize-1-n;
		ELSE
			RETURN -n-1;
		END;
	END AvailableBufSpace;

	(**
		Returns number of bytes available in the receive buffer of a UART controller

		uart: UART controller
		res: error code, 0 in case of success
	*)
	PROCEDURE Available*(uart: UartController): LONGINT;
	BEGIN
		RETURN OccupiedBufSpace(uart.rxBufWrPos,uart.rxBufRdPos,LEN(uart.rxBuf));
	END Available;

	(**
		Send a single character to the UART

		ch: character to send
		propagate: TRUE for flushing the TX FIFO buffer
		res: error code, 0 in case of success
	*)
	PROCEDURE SendChar*(uart: UartController; ch: CHAR; propagate: BOOLEAN; onBusy: UartMin.BusyLoopCallback; VAR res: LONGINT);
	TYPE ArrayOfChar1 = ARRAY 1 OF CHAR;
	BEGIN
		(*!TODO: do not use interrupts here to avoid problems when SendChar is used for trace output *)
		Send(uart, SYSTEM.VAL(ArrayOfChar1,ch), 0, 1, propagate, onBusy, res);
	END SendChar;

	(**
		Send data to the UART
	*)
	PROCEDURE Send*(uart: UartController; CONST buf: ARRAY OF CHAR; offs, len: LONGINT; propagate: BOOLEAN; onBusy: UartMin.BusyLoopCallback; VAR res: LONGINT);
	VAR
		bufWrPos, n: LONGINT;
	BEGIN

		IF ~uart.open THEN res := UartMin.Closed; RETURN; END;

		WHILE uart.open & (len > 0) DO

			bufWrPos := uart.txBufWrPos;
			n := AvailableBufSpace(bufWrPos,uart.txBufWrPos,LEN(uart.txBuf));

			IF n # 0 THEN

				n := MIN(n,len);
				DEC(len,n);

				WHILE n > 0 DO
					uart.txBuf[bufWrPos] := buf[offs];
					INC(bufWrPos);
					IF bufWrPos = LEN(uart.txBuf) THEN
						bufWrPos := 0;
					END;
					INC(offs); DEC(n);
				END;

				uart.txBufWrPos := bufWrPos;

				(* enable TX interrupts *)
				uart.regs.ier := uart.regs.ier + TxDataInterrupts;
			ELSE
				(* enable TX interrupts *)
				uart.regs.ier := uart.regs.ier + TxDataInterrupts;
				IF (onBusy # NIL) & ~onBusy(res) THEN RETURN; END;
			END;
		END;

		IF propagate THEN
			(* flush the buffer *)
			WHILE uart.open & (uart.txBufRdPos # uart.txBufWrPos) DO
				IF (onBusy # NIL) & ~onBusy(res) THEN RETURN; END;
			END;

			(* flush the FIFO *)
			WHILE uart.open & ~(UartMin.XUARTPS_SR_TXEMPTY IN uart.regs.sr) DO
				IF (onBusy # NIL) & ~onBusy(res) THEN RETURN; END;
			END;
		END;

		IF uart.open THEN
			res := 0;
		ELSE
			IF OverrunError IN uart.errors THEN res := OverrunError;
			ELSE res := UartMin.Closed;
			END;
		END;
(*	BEGIN

		WHILE uart.open & (len > 0) DO
			IF ~(UartMin.XUARTPS_SR_TNFUL IN uart.regs.sr) THEN
				uart.regs.fifo := ORD(buf[offs]);
				INC(offs); DEC(len);
			ELSIF (onBusy # NIL) & ~onBusy(res) THEN
				RETURN;
			END;
		END;

		IF propagate THEN (* flush the FIFO *)
			WHILE uart.open & ~(UartMin.XUARTPS_SR_TXEMPTY IN uart.regs.sr) DO
				IF (onBusy # NIL) & ~onBusy(res) THEN RETURN; END;
			END;
		END;

		IF uart.open THEN
			res := UartMin.Ok;
		ELSE
			res := UartMin.Closed;
		END;*)
	END Send;

	(**
		Receive a single character from UART

		res: error code, 0 in case of success

		Remarks: blocks until a character is available
	*)
	PROCEDURE ReceiveChar*(uart: UartController; onBusy: UartMin.BusyLoopCallback; VAR res: LONGINT): CHAR;
	VAR
		buf: ARRAY 1 OF CHAR;
		len: LONGINT;
	BEGIN
		Receive(uart,buf,0,1,1,len,onBusy,res);
		RETURN buf[0];
	END ReceiveChar;

	(**
		Receive data from the UART
	*)
	PROCEDURE Receive*(uart: UartController; VAR buf: ARRAY OF CHAR; offs, size, min: LONGINT; VAR len: LONGINT; onBusy: UartMin.BusyLoopCallback; VAR res: LONGINT);
	VAR
		bufRdPos, n: LONGINT;
	BEGIN
		IF ~uart.open THEN res := UartMin.Closed; RETURN; END;

		res := UartMin.Ok;
		len := 0;

		IF size = 0 THEN RETURN; END;

		min := MIN(size,min);

		WHILE uart.open & (size > 0) DO

			bufRdPos := uart.rxBufRdPos;

			n := OccupiedBufSpace(uart.rxBufWrPos,bufRdPos,LEN(uart.rxBuf));

			IF n # 0 THEN

				n := MIN(n,size);
				DEC(size,n); INC(len,n);
				IF min > 0 THEN DEC(min,n); END;

				WHILE n > 0 DO
					buf[offs] := uart.rxBuf[bufRdPos];
					INC(bufRdPos);
					IF bufRdPos = LEN(uart.rxBuf) THEN
						bufRdPos := 0;
					END;
					INC(offs); DEC(n);
				END;

				uart.rxBufRdPos := bufRdPos;

			ELSIF min > 0 THEN
				IF (onBusy # NIL) & ~onBusy(res) THEN RETURN; END;
			ELSE
				RETURN;
			END;
		END;

	(*BEGIN
		res := Ok;
		len := 0;

		IF size = 0 THEN RETURN; END;

		min := MIN(size,min);

		WHILE uart.open & (~(UartMin.XUARTPS_SR_RXEMPTY IN uart.regs.sr) OR (min > 0)) DO
			IF ~(UartMin.XUARTPS_SR_RXEMPTY IN uart.regs.sr) THEN
				WHILE (size > 0) & ~(UartMin.XUARTPS_SR_RXEMPTY IN uart.regs.sr) DO
					buf[offs] := uart.regs.fifo;
					DEC(min); DEC(size); INC(offs); INC(len);
				END;
			ELSIF (onBusy # NIL) & ~onBusy(res) THEN
				RETURN;
			END;
		END;

		IF ~uart.open THEN
			res := Closed;
		END;*)
	END Receive;

	PROCEDURE PrintRegisters(regs: UartMin.UartRegisters);
	BEGIN
		Trace.String("cr("); Trace.Hex(ADDRESSOF(regs.cr),-8); Trace.String("): "); Trace.Set(regs.cr); Trace.Ln;
		Trace.String("mr("); Trace.Hex(ADDRESSOF(regs.mr),-8); Trace.String("): "); Trace.Set(regs.mr); Trace.Ln;
		Trace.String("ier(");  Trace.Hex(ADDRESSOF(regs.ier),-8); Trace.String("): write only"); Trace.Ln;
		Trace.String("idr("); Trace.Hex(ADDRESSOF(regs.idr),-8); Trace.String("): write only"); Trace.Ln;
		Trace.String("imr("); Trace.Hex(ADDRESSOF(regs.imr),-8); Trace.String("): "); Trace.Set(regs.imr); Trace.Ln;
		Trace.String("isr("); Trace.Hex(ADDRESSOF(regs.isr),-8); Trace.String("): "); Trace.Set(regs.isr); Trace.Ln;
		Trace.String("baudgen("); Trace.Hex(ADDRESSOF(regs.baudgen),-8); Trace.String("): "); Trace.Int(regs.baudgen,0); Trace.Ln;
		Trace.String("rxtout("); Trace.Hex(ADDRESSOF(regs.rxtout),-8); Trace.String("): "); Trace.Int(regs.rxtout,0); Trace.Ln;
		Trace.String("rxwm("); Trace.Hex(ADDRESSOF(regs.rxwm),-8); Trace.String("): "); Trace.Int(regs.rxwm,0); Trace.Ln;
		Trace.String("modemcr("); Trace.Hex(ADDRESSOF(regs.modemcr),-8); Trace.String("): "); Trace.Set(regs.modemcr); Trace.Ln;
		Trace.String("modemsr("); Trace.Hex(ADDRESSOF(regs.modemsr),-8); Trace.String("): "); Trace.Set(regs.modemsr); Trace.Ln;
		Trace.String("sr("); Trace.Hex(ADDRESSOF(regs.sr),-8); Trace.String("): "); Trace.Set(regs.sr); Trace.Ln;
		Trace.String("fifo(");  Trace.Hex(ADDRESSOF(regs.fifo),-8); Trace.String("): --- "); Trace.Ln;
		Trace.String("bauddiv("); Trace.Hex(ADDRESSOF(regs.bauddiv),-8); Trace.String("): "); Trace.Int(regs.bauddiv,0); Trace.Ln;
		Trace.String("flowdel("); Trace.Hex(ADDRESSOF(regs.flowdel),-8); Trace.String("): "); Trace.Int(regs.flowdel,0); Trace.Ln;
		Trace.String("txwm("); Trace.Hex(ADDRESSOF(regs.txwm),-8); Trace.String("): "); Trace.Int(regs.txwm,0); Trace.Ln;
	END PrintRegisters;

	PROCEDURE Show*;
	BEGIN
		IF uarts[0] # NIL THEN
			Trace.StringLn("PS UART0 registers:");
			PrintRegisters(uarts[0].regs);
			Trace.Ln;
		END;
		IF uarts[1] # NIL THEN
			Trace.StringLn("PS UART1 registers:");
			PrintRegisters(uarts[1].regs);
			Trace.Ln;
		END;

	END Show;

END PsUart.