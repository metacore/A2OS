(* Raspberry Pi environment *)
(* Copyright (C) Florian Negele *)

MODULE Environment;

IMPORT SYSTEM, Activities, CPU, HeapManager, Interrupts, Trace, Processors, Timer;

CONST Running* = 0; ShuttingDown* = 1; Rebooting* = 2;

VAR heap: HeapManager.Heap;
VAR clock := 0: LONGINT;
VAR frequency: Timer.Counter;
VAR status* := Running: WORD;
VAR uartInterruptInstalled := 0: SIZE;
VAR timerInterruptInstalled := 0: SIZE;
VAR uartInterrupt: Interrupts.Interrupt;
VAR previousTimerHandler := NIL: CPU.InterruptHandler;

PROCEDURE {NORETURN} Abort-;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	IF SYSTEM.GetActivity () # NIL THEN Activities.TerminateCurrentActivity END;
	Activities.TerminateCurrentActivity;
END Abort;

PROCEDURE Allocate- (size: SIZE): ADDRESS;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	RETURN HeapManager.Allocate (size, heap);
END Allocate;

PROCEDURE Deallocate- (address: ADDRESS);
BEGIN {UNCOOPERATIVE, UNCHECKED}
	HeapManager.Deallocate (address, heap);
END Deallocate;

PROCEDURE Write- (character: CHAR);
BEGIN {UNCOOPERATIVE, UNCHECKED}
	WHILE CPU.TXFF IN CPU.ReadMask (CPU.UART_FR) DO END;
	CPU.WriteWord (CPU.UART_DR, ORD (character));
END Write;

PROCEDURE Read- (VAR character: CHAR): BOOLEAN;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	WHILE CPU.RXFE IN CPU.ReadMask (CPU.UART_FR) DO
		IF CAS (uartInterruptInstalled, 0, 1) = 0 THEN
			Interrupts.Install (uartInterrupt, CPU.IRQ);
		END;
		CPU.WriteMask (CPU.IRQEnable2, {25});
		Interrupts.Await (uartInterrupt);
		IF status # Running THEN RETURN FALSE END;
	END;
	character := CHR (CPU.ReadWord (CPU.UART_DR));
	Write (character); RETURN TRUE;
END Read;

PROCEDURE Flush-;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	REPEAT UNTIL CPU.TXFE IN CPU.ReadMask (CPU.UART_FR);
END Flush;

PROCEDURE GetString- (CONST name: ARRAY OF CHAR; VAR result: ARRAY OF CHAR);
BEGIN {UNCOOPERATIVE, UNCHECKED}
	result[0] := 0X
END GetString;

PROCEDURE Clock- (): LONGINT;
BEGIN RETURN Timer.GetCounter () DIV frequency;
END Clock;

PROCEDURE Sleep- (milliseconds: LONGINT);
VAR interrupt: Interrupts.Interrupt;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	ASSERT (milliseconds >= 0);
	IF CAS (timerInterruptInstalled, 0, 1) = 0 THEN
		previousTimerHandler := CPU.InstallInterrupt (HandleTimer, CPU.IRQ);
		CPU.WriteWord (CPU.STC1, CPU.ReadWord (CPU.STCLO) + 1000);
		CPU.WriteMask (CPU.IRQEnable1, {1});
	END;
	Interrupts.Install (interrupt, CPU.IRQ); INC (milliseconds, clock);
	WHILE clock - milliseconds < 0 DO Interrupts.Await (interrupt) END;
END Sleep;

PROCEDURE HandleTimer (index: SIZE);
BEGIN {UNCOOPERATIVE, UNCHECKED}
	IF previousTimerHandler # NIL THEN previousTimerHandler (index) END;
	IF 1 IN CPU.ReadMask (CPU.STCS) THEN
		CPU.WriteWord (CPU.STC1, CPU.ReadWord (CPU.STCLO) + 1000);
		CPU.WriteMask (CPU.STCS, {1}); INC (clock);
		CPU.WriteMask (CPU.IRQEnable1, {1});
	END;
END HandleTimer;

PROCEDURE LED- (status: BOOLEAN);
BEGIN {UNCOOPERATIVE, UNCHECKED}
	CPU.Mask (CPU.GPFSEL1, {18});
	IF status THEN CPU.WriteMask (CPU.GPSET1, {15}) ELSE CPU.WriteMask (CPU.GPCLR1, {15}) END;
END LED;

PROCEDURE Shutdown*;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	IF CAS (status, Running, ShuttingDown) # Running THEN RETURN END;
	Trace.StringLn ("system: shutting down...");
	IF uartInterruptInstalled # 0 THEN CPU.WriteMask (CPU.IRQDisable2, {25}); Interrupts.Cancel (uartInterrupt) END;
	IF timerInterruptInstalled # 0 THEN CPU.WriteMask (CPU.IRQDisable1, {1}) END;
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

PROCEDURE Initialize-;
CONST BaudRate = 115200;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	SYSTEM.SetActivity (NIL);
	CPU.Initialize; LED (TRUE);
	frequency := Timer.GetFrequency () DIV 1000;
	CPU.WriteMask (CPU.UART_CR, {CPU.UARTEN});
	CPU.Unmask (CPU.GPPUD, {CPU.PUD}); CPU.Delay (150);
	CPU.Mask (CPU.GPPUDCLK0, {14, 15}); CPU.Delay (150);
	CPU.WriteMask (CPU.GPPUDCLK0, {});
	CPU.WriteMask (CPU.UART_ICR, {1, 4..10});
	CPU.WriteWord (CPU.UART_IBRD, CPU.FUARTCLK DIV (16 * BaudRate));
	CPU.WriteWord (CPU.UART_FBRD, (CPU.FUARTCLK MOD (16 * BaudRate)) * 64 DIV (16 * BaudRate));
	CPU.WriteMask (CPU.UART_LCRH, CPU.WLEN8);
	CPU.WriteMask (CPU.UART_IMSC, {CPU.RXIM});
	CPU.WriteMask (CPU.UART_CR, {CPU.UARTEN, CPU.TXE, CPU.RXE});
	CPU.IdentityMapMemory; CPU.EnableMemoryManagementUnit;
	HeapManager.Initialize (heap, ADDRESS OF KernelEnd, CPU.MemorySize);
END Initialize;

PROCEDURE Terminate-;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	Interrupts.Terminate;
	LED (FALSE);
END Terminate;

PROCEDURE {NOPAF, ALIGNED(32)} KernelEnd;
CODE
END KernelEnd;

BEGIN {UNCHECKED}
	Trace.String ("Version "); Trace.String (SYSTEM.Date); Trace.String (" (");
	Trace.Int (CPU.MemorySize DIV (1024 * 1024), 0); Trace.String (" MB RAM, GC, ");
	Trace.String ("GC, ");
	Trace.Int (Processors.count, 0); Trace.String (" CPU");
	IF Processors.count > 1 THEN Trace.Char ('s') END; Trace.Char (')'); Trace.Ln;
END Environment.
