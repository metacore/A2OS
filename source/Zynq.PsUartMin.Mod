MODULE PsUartMin;
(**
	AUTHOR: Alexey Morozov, Timothee Martiel
	PURPOSE: minimal driver implementation for Xilinx Zynq UART PS controller
*)

IMPORT SYSTEM;

CONST
	(** Parity types - compatible with A2 Serials *)
	ParNo* = 0;  ParOdd* = 1;  ParEven* = 2;  ParMark* = 3;  ParSpace* = 4;

	(** Stop bits - compatible with A2 Serials *)
	Stop1* = 1;  Stop2* = 2;  Stop1dot5* = 3;

	(** Error codes - compatible with A2 Serials *)
	Ok* =  0;
	Closed* = -1;
	PortInUse* =  1; NoSuchPort* =  2; WrongBPS* =  3; WrongData* =  4; WrongParity* =  5; WrongStop* =  6;

	(* Default settings *)
	DefaultBPS* = 115200; DefaultDataBits* = 8; DefaultParity* = ParNo; DefaultStop* = Stop1;

	NumUarts* = 2; (** number of supported UART controllers *)

	 (* Control Register Bit Definition
	 	The Control register (CR) controls the major functions of the device.
	 *)
	XUARTPS_CR_STOPBRK* = 8; (* Stop transmission of break *)
	XUARTPS_CR_STARTBRK* = 7; (* Set break *)
	XUARTPS_CR_TORST* = 6; (* RX timeout counter restart *)
	XUARTPS_CR_TX_DIS* = 5; (* TX disabled. *)
	XUARTPS_CR_TX_EN* = 4; (* TX enabled *)
	XUARTPS_CR_RX_DIS* = 3; (* RX disabled. *)
	XUARTPS_CR_RX_EN* = 2; (* RX enabled *)
	XUARTPS_CR_EN_DIS_MASK* = {2..5}; (* Enable/disable Mask *)
	XUARTPS_CR_TXRST* = 1; (* TX logic reset *)
	XUARTPS_CR_RXRST* = 0; (* RX logic reset *)

	(* Mode Register Bit Definition

		The mode register (MR) defines the mode of transfer as well as the data
		format. If this register is modified during transmission or reception,
		data validity cannot be guaranteed.
	*)
	XUARTPS_MR_CHMODE_R_LOOP = {8,9}; (* Remote loopback mode *)
	XUARTPS_MR_CHMODE_L_LOOP = {9}; (* Local loopback mode *)
	XUARTPS_MR_CHMODE_ECHO = {8}; (* Auto echo mode *)
	XUARTPS_MR_CHMODE_NORM = {}; (* Normal mode *)
	XUARTPS_MR_CHMODE_SHIFT = 8; (* Mode shift *)
	XUARTPS_MR_CHMODE_MASK = {8..9}; (* Mode mask *)
	XUARTPS_MR_STOPMODE_2 = {7}; (* 2 stop bits *)
	XUARTPS_MR_STOPMODE_1_5 = {6}; (* 1.5 stop bits *)
	XUARTPS_MR_STOPMODE_1 = {}; (* 1 stop bit *)
	XUARTPS_MR_STOPMODE_SHIFT = 6; (* Stop bits shift *)
	XUARTPS_MR_STOPMODE_MASK = {6..7}; (* Stop bits mask *)
	XUARTPS_MR_PARITY_NONE = {5}; (* No parity mode *)
	XUARTPS_MR_PARITY_MARK = {3,4}; (* Mark parity mode *)
	XUARTPS_MR_PARITY_SPACE = {4}; (* Space parity mode *)
	XUARTPS_MR_PARITY_ODD = {3}; (* Odd parity mode *)
	XUARTPS_MR_PARITY_EVEN = {}; (* Even parity mode *)
	XUARTPS_MR_PARITY_SHIFT = 3; (* Parity setting shift *)
	XUARTPS_MR_PARITY_MASK = {3..5}; (* Parity mask *)
	XUARTPS_MR_CHARLEN_6 = {1,2}; (* 6 bits data *)
	XUARTPS_MR_CHARLEN_7 = {2}; (* 7 bits data *)
	XUARTPS_MR_CHARLEN_8 = {}; (* 8 bits data *)
	XUARTPS_MR_CHARLEN_SHIFT = 1; (* Data Length shift *)
	XUARTPS_MR_CHARLEN_MASK = {1..2}; (* Data length mask *)
	XUARTPS_MR_CLKSEL_BIT = 0; (* Input clock selection *)

	(** Interrupt Registers

		Interrupt control logic uses the interrupt enable register (IER) and the
		interrupt disable register (IDR) to set the value of the bits in the
		interrupt mask register (IMR). The IMR determines whether to pass an
		interrupt to the interrupt status register (ISR).
		Writing a 1 to IER Enbables an interrupt, writing a 1 to IDR disables an
		interrupt. IMR and ISR are read only, and IER and IDR are write only.
		Reading either IER or IDR returns 0x00.

		All four registers have the same bit definitions.
	*)
	XUARTPS_IXR_RBRK	= 13; (** Rx FIFO break detect interrupt *)
	XUARTPS_IXR_TOVR*	= 12; (** Tx FIFO Overflow interrupt *)
	XUARTPS_IXR_TNFUL*	= 11; (** Tx FIFO Nearly Full interrupt *)
	XUARTPS_IXR_TTRIG*	= 10; (** Tx Trig interrupt *)
	XUARTPS_IXR_DMS*		= 9; (** Modem status change interrupt *)
	XUARTPS_IXR_TOUT*	= 8; (** Timeout error interrupt *)
	XUARTPS_IXR_PARITY* 	= 7; (** Parity error interrupt *)
	XUARTPS_IXR_FRAMING*	= 6; (** Framing error interrupt *)
	XUARTPS_IXR_OVER*	= 5; (** Overrun error interrupt *)
	XUARTPS_IXR_TXFULL* 	= 4; (** TX FIFO full interrupt. *)
	XUARTPS_IXR_TXEMPTY*	= 3; (** TX FIFO empty interrupt. *)
	XUARTPS_IXR_RXFULL* 	= 2; (** RX FIFO full interrupt. *)
	XUARTPS_IXR_RXEMPTY*	= 1; (** RX FIFO empty interrupt. *)
	XUARTPS_IXR_RXOVR*  	= 0; (** RX FIFO trigger interrupt. *)
	XUARTPS_IXR_MASK*	= {0..13}; (** Valid bit mask *)

	(** Channel Status Register

		The channel status register (CSR) is provided to enable the control logic
		to monitor the status of bits in the channel interrupt status register,
		even if these are masked out by the interrupt mask register.
	*)
	XUARTPS_SR_TNFUL* =	14; (** TX FIFO Nearly Full Status *)
	XUARTPS_SR_TTRIG*	 =	13; (** TX FIFO Trigger Status *)
	XUARTPS_SR_FLOWDEL* =	12; (** RX FIFO fill over flow delay *)
	XUARTPS_SR_TACTIVE* =	11; (** TX active *)
	XUARTPS_SR_RACTIVE* =	10; (** RX active *)
	XUARTPS_SR_DMS*	 =	9; (** Delta modem status change *)
	XUARTPS_SR_TOUT*	 =	8; (** RX timeout *)
	XUARTPS_SR_PARITY* =	7; (** RX parity error *)
	XUARTPS_SR_FRAME* =	6; (** RX frame error *)
	XUARTPS_SR_OVER*	 =	5; (** RX overflow error *)
	XUARTPS_SR_TXFULL* =	4; (** TX FIFO full *)
	XUARTPS_SR_TXEMPTY* =	3; (** TX FIFO empty *)
	XUARTPS_SR_RXFULL* =	2; (** RX FIFO full *)
	XUARTPS_SR_RXEMPTY* =	1; (** RX FIFO empty *)
	XUARTPS_SR_RXOVR* =	0; (** RX FIFO fill over trigger *)

	(*
		Modem Control register
	*)
	XUARTPS_MODEMCR_FCM = 5;
	XUARTPS_MODEMCR_RTS = 1;
	XUARTPS_MODEMCR_DTR = 0;

	(*
		Modem Status register
	*)
	XUARTPS_MODEMSR_FCMS = 8;
	XUARTPS_MODEMSR_DCD = 7;
	XUARTPS_MODEMSR_RI = 6;
	XUARTPS_MODEMSR_DSR = 5;
	XUARTPS_MODEMSR_CTS = 4;
	XUARTPS_MODEMSR_DCDX = 3;
	XUARTPS_MODEMSR_RIX = 2;
	XUARTPS_MODEMSR_DSRX = 1;
	XUARTPS_MODEMSR_CTSX = 0;

	(* The following constant defines the amount of error that is allowed for
		a specified baud rate. This error is the difference between the actual
		baud rate that will be generated using the specified clock and the
		desired baud rate.
	*)
	XUARTPS_MAX_BAUD_ERROR_RATE = 3;	(* max % error allowed *)

TYPE
	(*
		(* Register offsets for the UART controller *)
		XUARTPS_CR_OFFSET = 0x0000;  (* Control Register [8:0] *)
		XUARTPS_MR_OFFSET = 0x0004;  (* Mode Register [9:0] *)
		XUARTPS_IER_OFFSET = 0x0008;  (* Interrupt Enable [12:0] *)
		XUARTPS_IDR_OFFSET = 0x000C;  (* Interrupt Disable [12:0] *)
		XUARTPS_IMR_OFFSET = 0x0010;  (* Interrupt Mask [12:0] *)
		XUARTPS_ISR_OFFSET = 0x0014;  (* Interrupt Status [12:0]*)
		XUARTPS_BAUDGEN_OFFSET = 0x0018;  (* Baud Rate Generator [15:0] *)
		XUARTPS_RXTOUT_OFFSET = 0x001C;  (* RX Timeout [7:0] *)
		XUARTPS_RXWM_OFFSET = 0x0020;  (* RX FIFO Trigger Level [5:0] *)
		XUARTPS_MODEMCR_OFFSET = 0x0024;  (* Modem Control [5:0] *)
		XUARTPS_MODEMSR_OFFSET = 0x0028;  (* Modem Status [8:0] *)
		XUARTPS_SR_OFFSET = 0x002C;  (* Channel Status [14:0] *)
		XUARTPS_FIFO_OFFSET = 0x0030;  (* FIFO [7:0] *)
		XUARTPS_BAUDDIV_OFFSET = 0x0034;  (* Baud Rate Divider [7:0] *)
		XUARTPS_FLOWDEL_OFFSET = 0x0038;  (* Flow Delay [5:0] *)
		XUARTPS_TXWM_OFFSET = 0x0044;  (* TX FIFO Trigger Level [5:0] *)
		XUARTPS_RXBS_OFFSET = 0x0048;  (* RX FIFO Byte Status [11:0] *)
	*)
	UartRegisters* = POINTER {UNSAFE, UNTRACED}  TO RECORD
		cr*, mr*, ier*, idr*, imr*, isr*: SET32;
		baudgen*, rxtout*, rxwm*: LONGINT;
		modemcr*, modemsr*: SET32;
		sr*: SET32;
		fifo*: LONGINT;
		bauddiv*, flowdel*: LONGINT;
		padding2: ARRAY 2 OF LONGINT;
		txwm*: LONGINT;
	END;

	BusyLoopCallback* = PROCEDURE{DELEGATE}(VAR res: WORD): BOOLEAN;

	UartId* = SIZE;
	ClockFrequency* = LONGINT;

VAR
	uarts: ARRAY NumUarts OF UartRegisters;
	inputClocks: ARRAY NumUarts OF ClockFrequency;

	(**
		Install a UART controller

		uart: ID (0-based index) of the UART controller to install
		base: controller base address
		inputClock: controller input clock in Hz
		res: returned error code, 0 in case of success
	*)
	PROCEDURE Install* (uart: UartId; base: ADDRESS; inputClock: ClockFrequency; VAR res: WORD);
	BEGIN
		IF (uart < 0) OR (uart >= LEN(uarts)) THEN
			res := NoSuchPort; RETURN;
		END;

		res := Ok;

		uarts[uart] := base;
		inputClocks[uart] := inputClock;

		Reset(uarts[uart]);
		ASSERT(SetBps(uarts[uart],DefaultBPS,res));
		ASSERT(SetDataBits(uarts[uart],DefaultDataBits,res));
		ASSERT(SetParity(uarts[uart],DefaultParity,res));
		ASSERT(SetStopBits(uarts[uart],DefaultStop,res));
	END Install;

	(**
		Get UART controller with a given ID
	*)
	PROCEDURE GetUart*(uart: UartId): UartRegisters;
	BEGIN
		IF (uart >= 0) & (uart < LEN(uarts)) THEN
			RETURN uarts[uart];
		ELSE RETURN NIL;
		END;
	END GetUart;

	(**
		Enable/Disable the UART controller

		enable: TRUE for enabling
	*)
	PROCEDURE Enable*(uart: UartRegisters; enable: BOOLEAN);
	BEGIN
		IF enable THEN
			uart.cr := uart.cr * SET32(-XUARTPS_CR_EN_DIS_MASK) + {XUARTPS_CR_RX_EN, XUARTPS_CR_TX_EN};
		ELSE
			uart.cr := uart.cr * SET32(-XUARTPS_CR_EN_DIS_MASK) + {XUARTPS_CR_RX_DIS, XUARTPS_CR_TX_DIS};
		END;
	END Enable;

	(**
		Reset the controller
	*)
	PROCEDURE Reset*(uart: UartRegisters);
	BEGIN
		(* disable all UART interrupts *)
		uart.idr := XUARTPS_IXR_MASK;

		(* disable RX/TX *)
		uart.cr := {XUARTPS_CR_RX_DIS, XUARTPS_CR_TX_DIS};

		(* software reset of RX and TX - this clears the FIFO. *)
		uart.cr := {XUARTPS_CR_RXRST, XUARTPS_CR_TXRST};

(*! this makes the controller crazy when executed within PsUart.Open
		(* clear status flags - SW reset will not clear sticky flags *)
		uart.isr := XUARTPS_IXR_MASK;*)

		(* set CR to its default value *)
		uart.cr := {XUARTPS_CR_RX_DIS, XUARTPS_CR_TX_DIS, XUARTPS_CR_STOPBRK};
	END Reset;

	(*
		Setup baudrate in bps
	*)
	PROCEDURE SetBps*(uart: UartRegisters; baudrate: LONGINT; VAR res: WORD): BOOLEAN;
	VAR
		i: SIZE;
		clock: ClockFrequency;
		valBAUDDIV, valBRGR, calcBaudrate, baudError: LONGINT;
		bestError, bestBRGR, bestBAUDDIV: LONGINT;
	BEGIN
		i := 0;
		WHILE (i < LEN(uarts)) & (uarts[i] # uart) DO INC(i); END;
		ASSERT(i < LEN(uarts));
		clock := inputClocks[i];

		(*
			Make sure the baud rate is not impossilby large.
	 		Fastest possible baud rate is Input Clock / 2
		*)
		IF (baudrate <= 0) OR (baudrate*2 > clock) THEN
			res := NoSuchPort; RETURN FALSE;
		END;

		(* Check whether the input clock is divided by 8 *)
		IF XUARTPS_MR_CLKSEL_BIT IN uart.mr THEN
			clock := clock DIV 8;
		END;

		(* Determine the Baud divider. It can be 4 to 254.
			Loop through all possible combinations *)
		bestError := MAX(LONGINT);
		FOR valBAUDDIV := 4 TO 255 DO

			(* Calculate the value for BRGR register *)
			valBRGR := clock DIV (baudrate * (valBAUDDIV + 1));

			IF valBRGR > 0 THEN
				(* Calculate the baud rate from the BRGR value *)
				calcBaudrate := clock DIV (valBRGR * (valBAUDDIV + 1));

				(* Avoid unsigned integer underflow *)
				IF baudrate > calcBaudrate THEN
					baudError := baudrate - calcBaudrate;
				ELSE
					baudError := calcBaudrate - baudrate;
				END;

				(*
					Find the calculated baud rate closest to requested baud rate.
				*)
				IF baudError < bestError THEN
					bestBRGR := valBRGR;
					bestBAUDDIV := valBAUDDIV;
					bestError := baudError;
				END;
			END;

			INC(valBAUDDIV);
		END;

		(*
			Make sure the best error is not too large.
		*)
		IF (bestError * 100) DIV baudrate > XUARTPS_MAX_BAUD_ERROR_RATE THEN (* baudrate error *)
			res := WrongBPS; RETURN FALSE;
		END;

		(* write baudrate settings *)
		uart.baudgen := bestBRGR;
		uart.bauddiv := bestBAUDDIV;

		res := Ok;
		RETURN TRUE
	END SetBps;

	(**
		Set number of data bits
	*)
	PROCEDURE SetDataBits*(uart: UartRegisters; dataBits: LONGINT; VAR res: WORD): BOOLEAN;
	VAR reg: SET32;
	BEGIN
		CASE dataBits OF
			 6: reg := XUARTPS_MR_CHARLEN_6;
			|7: reg := XUARTPS_MR_CHARLEN_7;
			|8: reg := XUARTPS_MR_CHARLEN_8;
		ELSE
			res := WrongData; RETURN FALSE;
		END;

		uart.mr := uart.mr * SET32(-XUARTPS_MR_CHARLEN_MASK) + reg;

		res := Ok;
		RETURN TRUE
	END SetDataBits;

	(**
		Setup parity check type
	*)
	PROCEDURE SetParity*(uart: UartRegisters; parityType: LONGINT; VAR res: WORD): BOOLEAN;
	VAR reg: SET32;
	BEGIN
		CASE parityType OF
			 ParNo: reg := XUARTPS_MR_PARITY_NONE;
			|ParEven: reg := XUARTPS_MR_PARITY_EVEN;
			|ParOdd: reg := XUARTPS_MR_PARITY_ODD;
			|ParMark: reg := XUARTPS_MR_PARITY_MARK;
			|ParSpace: reg := XUARTPS_MR_PARITY_SPACE;
		ELSE
			res := WrongParity; RETURN FALSE;
		END;

		uart.mr := uart.mr * SET32(-XUARTPS_MR_PARITY_MASK) + reg;

		res := Ok;
		RETURN TRUE
	END SetParity;

	(**
		Setup number of stop bits
	*)
	PROCEDURE SetStopBits*(uart: UartRegisters; stopBits: LONGINT; VAR res: WORD): BOOLEAN;
	VAR reg: SET32;
	BEGIN
		CASE stopBits OF
			 Stop1: reg := XUARTPS_MR_STOPMODE_1;
			|Stop2: reg := XUARTPS_MR_STOPMODE_2;
			|Stop1dot5: reg := XUARTPS_MR_STOPMODE_1_5;
		ELSE
			res := WrongStop; RETURN FALSE;
		END;

		uart.mr := uart.mr * SET32(-XUARTPS_MR_STOPMODE_MASK) + reg;

		res := Ok;
		RETURN TRUE
	END SetStopBits;

	(**
		Send a single character to the UART

		ch: character to send
		propagate: TRUE for flushing the TX FIFO buffer
		res: error code, 0 in case of success
	*)
	PROCEDURE SendChar*(uart: UartRegisters; ch: CHAR; propagate: BOOLEAN; onBusy: BusyLoopCallback; VAR res: WORD);
	BEGIN
		(* Wait until TX FIFO is not full *)
		WHILE (XUARTPS_CR_TX_EN IN uart.cr) & (XUARTPS_SR_TXFULL IN uart.sr) DO
			IF (onBusy # NIL) & ~onBusy(res) THEN RETURN; END;
		END;

		IF (XUARTPS_CR_TX_EN IN uart.cr) THEN
			uart.fifo := ORD(ch);
			IF propagate THEN (* flush the FIFO *)
				WHILE (XUARTPS_CR_TX_EN IN uart.cr) & ~(XUARTPS_SR_TXEMPTY IN uart.sr) DO
					IF (onBusy # NIL) & ~onBusy(res) THEN RETURN; END;
				END;
			END;
			IF (XUARTPS_CR_TX_EN IN uart.cr) THEN res := Ok; ELSE res := Closed; END;
		ELSE res := Closed;
		END;
	END SendChar;

	(**
		Receive a single character from UART

		res: error code, 0 in case of success

		Remarks: blocks until a character is available
	*)
	PROCEDURE ReceiveChar*(uart: UartRegisters; onBusy: BusyLoopCallback; VAR res: WORD): CHAR;
	BEGIN
		(* wait until data is available *)
		WHILE (XUARTPS_CR_RX_EN IN uart.cr) & (XUARTPS_SR_RXEMPTY IN uart.sr) DO
			IF (onBusy # NIL) & ~onBusy(res) THEN RETURN 0X; END;
		END;

		IF (XUARTPS_CR_RX_EN IN uart.cr) THEN
			res := Ok; RETURN CHR(uart.fifo);
		ELSE
			res := Closed; RETURN 0X;
		END;
	END ReceiveChar;

	(**
		Returns number of bytes available in the receive FIFO of the UART controller
	*)
	PROCEDURE Available*(uart: UartRegisters): SIZE;
	BEGIN
		IF ~(XUARTPS_SR_RXEMPTY IN uart.sr) THEN
			RETURN 1;
		ELSE
			RETURN 0;
		END;
	END Available;

END PsUartMin.