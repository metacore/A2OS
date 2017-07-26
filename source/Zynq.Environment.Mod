(* Zynq environment *)
(* Copyright (C) Florian Negele *)

MODULE Environment;

IMPORT SYSTEM, Activities, CPU, HeapManager, Interrupts, Trace, Processors, Timer;

CONST Running* = 0; ShuttingDown* = 1; Rebooting* = 2;

VAR memory: SIZE;
VAR heap: HeapManager.Heap;
VAR frequency: Timer.Counter;
VAR status* := Running: WORD;

PROCEDURE {NORETURN} Abort-;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	IF SYSTEM.GetActivity () # NIL THEN Activities.TerminateCurrentActivity END;
	Activities.TerminateCurrentActivity;
END Abort;

PROCEDURE Allocate- (size: SIZE): ADDRESS;
VAR result, address: ADDRESS;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	result := HeapManager.Allocate (size, heap);
	IF result = NIL THEN RETURN NIL END;
	FOR address := result TO result + size - 1 DO SYSTEM.PUT8 (address, 0) END;
	RETURN result;
END Allocate;

PROCEDURE Deallocate- (address: ADDRESS);
BEGIN {UNCOOPERATIVE, UNCHECKED}
	HeapManager.Deallocate (address, heap);
END Deallocate;

PROCEDURE Write- (character: CHAR);
BEGIN {UNCOOPERATIVE, UNCHECKED}
	WHILE CPU.TXFULL IN CPU.ReadMask (CPU.UART1 + CPU.Channel_sts_reg0) DO END;
	CPU.WriteWord (CPU.UART1 + CPU.TX_RX_FIFO0, LSH (ORD (character), CPU.FIFO));
END Write;

PROCEDURE Flush-;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	REPEAT UNTIL CPU.TXEMPTY IN CPU.ReadMask (CPU.UART1 + CPU.Channel_sts_reg0);
END Flush;

PROCEDURE GetString- (CONST name: ARRAY OF CHAR; VAR result: ARRAY OF CHAR);
BEGIN {UNCOOPERATIVE, UNCHECKED}
	result[0] := 0X
END GetString;

PROCEDURE Clock- (): LONGINT;
BEGIN RETURN Timer.GetCounter () DIV frequency;
END Clock;

PROCEDURE Sleep- (milliseconds: LONGINT);
VAR clock: Timer.Counter;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	ASSERT (milliseconds >= 0);
	clock := Timer.GetCounter () + milliseconds * frequency;
	WHILE Timer.GetCounter () - clock < 0 DO Activities.Switch END;
END Sleep;

PROCEDURE Shutdown*;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	IF CAS (status, Running, ShuttingDown) # Running THEN RETURN END;
	Trace.StringLn ("system: shutting down...");
END Shutdown;

PROCEDURE Reboot*;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	Shutdown;
	ASSERT (CAS (status, ShuttingDown, Rebooting) = ShuttingDown);
END Reboot;

PROCEDURE {NORETURN} Exit- (status: WORD);
BEGIN {UNCOOPERATIVE, UNCHECKED}
	Trace.String ("system: ");
	IF status = Rebooting THEN Trace.StringLn ("rebooting..."); CPU.Reset END;
	Trace.StringLn ("ready for power off or restart"); Flush; CPU.Halt;
END Exit;

PROCEDURE InitTrace;
CONST BaudRate = 115200;
CONST BDIV = 6; CD = CPU.UART_REF_CLK DIV BaudRate DIV (BDIV + 1);
BEGIN {UNCOOPERATIVE, UNCHECKED}
	CPU.WriteMask (CPU.UART_RST_CTRL, {CPU.UART1_REF_RST, CPU.UART1_CPU1X_RST});
	CPU.WriteMask (CPU.UART1 + CPU.mode_reg0, {CPU.PAR + 2});
	CPU.WriteMask (CPU.UART1 + CPU.Intrpt_dis_reg0, {0..12});
(*	commented out to reuse UART settings from bootloader
	CPU.WriteMask (CPU.UART1 + CPU.Control_reg0, {CPU.RXDIS, CPU.TXDIS});
	CPU.WriteWord (CPU.UART1 + CPU.Baud_rate_gen_reg0, LSH (CD, CPU.CD));
	CPU.WriteWord (CPU.UART1 + CPU.Baud_rate_divider_reg0, LSH (BDIV, CPU.BDIV));
	CPU.WriteMask (CPU.UART1 + CPU.Control_reg0, {CPU.RXRST, CPU.TXRST});
	CPU.WriteMask (CPU.UART1 + CPU.Control_reg0, {CPU.RXEN, CPU.TXEN});
*)
	Trace.Init; Trace.Char := Write;
END InitTrace;

PROCEDURE InitMemory;
CONST MemorySize = 512 * 1024 * 1024;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	HeapManager.Initialize (heap, ADDRESS OF KernelEnd, MemorySize);
	memory := MemorySize - ADDRESS OF KernelEnd;
END InitMemory;

PROCEDURE StoreActivity;
BEGIN {UNCOOPERATIVE, UNCHECKED}
END StoreActivity;

PROCEDURE RestoreActivity;
BEGIN {UNCOOPERATIVE, UNCHECKED}
END RestoreActivity;

PROCEDURE Initialize-;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	CPU.Initialize; InitTrace; InitMemory;
	frequency := Timer.GetFrequency () DIV 1000;
END Initialize;

PROCEDURE Terminate-;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	Interrupts.Terminate;
END Terminate;

PROCEDURE {NOPAF, INITIAL, FIXED(100000H)} KernelBegin;
CODE
	; initialize SP
	MOV	SP, #0x8000
	MRC	P15, 0, R0, C0, C0, 5
	AND	R0, R0, #0x1
	SUB	SP, SP, R0, LSL #13

	; filter CPU
	CMP	R0, #0
	BEQ	skip
	WFE
	B		@Processors.Boot
skip:
END KernelBegin;

PROCEDURE {NOPAF, FINAL, ALIGNED(32)} KernelEnd;
CODE
END KernelEnd;

BEGIN {UNCHECKED}
	Trace.String ("Version "); Trace.String (SYSTEM.Date); Trace.String (" (");
	Trace.Int (memory DIV (1024 * 1024), 0); Trace.String (" MB RAM, GC, ");
	Trace.Int (Processors.count, 0); Trace.String (" CPU");
	IF Processors.count > 1 THEN Trace.Char ('s') END; Trace.Char (')'); Trace.Ln;
END Environment.
