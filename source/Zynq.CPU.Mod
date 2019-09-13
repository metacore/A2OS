(* Runtime support for CPU internals *)
(* Copyright (C) Florian Negele *)

MODULE CPU;

IMPORT SYSTEM;

CONST StackSize* = 4096;
CONST Quantum* = 100000;
CONST CacheLineSize* = 32;
CONST StackDisplacement* = 0;

PROCEDURE Backoff-;
CODE
	MOV	R2, #0x100
loop:
	SUBS	R2, R2, #1
	BNE	loop
END Backoff;

(* cpu control *)
PROCEDURE Delay- (cycles: SIZE);
CODE
	LDR	R2, [FP, #cycles]
delay:
	SUBS	R2, R2, #1
	BNE	delay
END Delay;

PROCEDURE {NORETURN} Reset-;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	WriteWord (WDOG_CONTROL, LSH (0, CLKSEL) + LSH (0, CRV) + LSH (0248H, CKEY));
	WriteWord (WDOG_MODE, LSH (1, WDEN) + LSH (1, RSTEN) + LSH (0ABCH, ZKEY));
	Halt;
END Reset;

PROCEDURE {NORETURN} Halt-;
CODE
	MRS	R2, CPSR
	ORR	R2, R2, #0b1100000
	MSR	CPSR_c, r2
	WFI
END Halt;

PROCEDURE -SaveResult-;
CODE
	STMDB	SP!, {R0, R1}
END SaveResult;

PROCEDURE -RestoreResultAndReturn-;
CODE
	LDMIA	SP!, {R0, R1}
	ADD	SP, FP, #4
	LDMIA	SP!, {FP, PC}
END RestoreResultAndReturn;

(* hardware registers *)
CONST PSS_RST_CTRL* = 0F8000200H; SOFT_RST* = 0;

CONST UART_RST_CTRL* = 0F8000228H; UART0_CPU1X_RST* = 0; UART1_CPU1X_RST* = 1; UART0_REF_RST* = 2; UART1_REF_RST* = 3;

CONST UART_REF_CLK* = 50000000;
CONST UART0* = 0E0000000H; UART1* = 0E0001000H;
CONST Control_reg0* = 000H; RXRST* = 0; TXRST* = 1; RXEN* = 2; RXDIS* = 3; TXEN* = 4; TXDIS* = 5;
CONST mode_reg0* = 004H; CHMOD* = 8; NBSTOP* = 6; PAR* = 3; CHRL* = 1; CLKS* = 0;
CONST Intrpt_dis_reg0* = 00CH;
CONST Baud_rate_gen_reg0* = 018H; CD* = 0;
CONST Channel_sts_reg0* = 02CH; TXEMPTY* = 3; TXFULL* = 4;
CONST Baud_rate_divider_reg0* = 034H; BDIV* = 0;
CONST TX_RX_FIFO0* = 030H; FIFO* = 0;

CONST Global_Timer_Counter_Register0* = 0F8F00200H;
CONST Global_Timer_Counter_Register1* = 0F8F00204H;

CONST WDOG_MODE* = 0F8005000H; WDEN* = 0; RSTEN* = 1; ZKEY* = 12;
CONST WDOG_CONTROL* = 0F8005004H; CLKSEL* = 0; CRV* = 2; CKEY* = 14;

PROCEDURE ReadWord- (register: ADDRESS): INTEGER;
CODE
	LDR	R2, [FP, #register]
	LDR	R0, [R2, #0]
END ReadWord;

PROCEDURE ReadMask- (register: ADDRESS): SET;
CODE
	LDR	R2, [FP, #register]
	LDR	R0, [R2, #0]
END ReadMask;

PROCEDURE WriteWord- (register: ADDRESS; value: ADDRESS);
CODE
	LDR	R2, [FP, #register]
	LDR	R3, [FP, #value]
	STR	R3, [R2, #0]
END WriteWord;

PROCEDURE WriteMask- (register: ADDRESS; value: SET);
CODE
	LDR	R2, [FP, #register]
	LDR	R3, [FP, #value]
	STR	R3, [R2, #0]
END WriteMask;

PROCEDURE Mask- (register: ADDRESS; value: SET);
CODE
	LDR	R2, [FP, #register]
	LDR	R3, [FP, #value]
	LDR	R4, [R2, #0]
	ORR	R4, R4, R3
	STR	R4, [R2, #0]
END Mask;

PROCEDURE Unmask- (register: ADDRESS; value: SET);
CODE
	LDR	R2, [FP, #register]
	LDR	R3, [FP, #value]
	LDR	R4, [R2, #0]
	BIC	R4, R4, R3
	STR	R4, [R2, #0]
END Unmask;

(* combined mask / unmask: clear mask and set value *)
PROCEDURE MaskIn-(register: ADDRESS; mask, value: SET);
CODE
	LDR	R2, [FP, #register]
	LDR	R3, [FP, #mask]
	LDR	R4, [FP, #value]
	LDR	R5, [R2, #0]
	BIC	R5, R5, R3
	ORR R5, R5, R4
	STR	R5, [R2, #0]
END MaskIn;

(* interrupt handling *)
CONST Interrupts* = 7;
CONST UndefinedInstruction* = 1; SoftwareInterrupt* = 2; PrefetchAbort* = 3; DataAbort* = 4; IRQ* = 5; FIQ* = 6; IRQ0* = IRQ;

TYPE InterruptHandler* = PROCEDURE (index: SIZE);

VAR handlers: ARRAY Interrupts OF InterruptHandler;

PROCEDURE InstallInterrupt- (handler: InterruptHandler; index: SIZE): InterruptHandler;
VAR previous: InterruptHandler;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	ASSERT (handler # NIL); ASSERT (index < Interrupts);
	REPEAT previous := CAS (handlers[index], NIL, NIL) UNTIL CAS (handlers[index], previous, handler) = previous;
	RETURN previous;
END InstallInterrupt;

PROCEDURE HandleInterrupt (index: SIZE);
BEGIN {UNCOOPERATIVE, UNCHECKED}
	SYSTEM.SetActivity (NIL);
	IF handlers[index] # NIL THEN handlers[index] (index) ELSE HALT (1234) END;
END HandleInterrupt;

PROCEDURE DisableInterrupt- (index: SIZE);
VAR previous: InterruptHandler;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	ASSERT (index < Interrupts);
	REPEAT previous := CAS (handlers[index], NIL, NIL) UNTIL CAS (handlers[index], previous, NIL) = previous;
END DisableInterrupt;

PROCEDURE EnableIRQ- (index: SIZE);
BEGIN
	(* no effect -- only for compatibility *)
END EnableIRQ;

PROCEDURE DisableIRQ-(index: SIZE);
BEGIN
	(* no effect -- only for compatibility *)
END DisableIRQ;


PROCEDURE Initialize-;
CODE
	ADD	R2, PC, #vector-$-8
	MOV	R3, #0
	ADD	R4, R3, #vector_end - vector
copy:
	CMP	R3, R4
	BEQ	vector_end
	LDR	r5, [R2], #4
	STR	r5, [R3], #4
	B	copy
vector:
	LDR	PC, [PC, #header-$-8]
	LDR	PC, [PC, #undefined_instruction-$-8]
	LDR	PC, [PC, #software_interrupt-$-8]
	LDR	PC, [PC, #prefetch_abort-$-8]
	LDR	PC, [PC, #data_abort-$-8]
	MOV	R0, R0
	LDR	PC, [PC, #irq-$-8]
fiq:
	STMDB	SP!, {R0, R1, R2, R3, R4, R5, R6, R7, LR}
	MOV	R2, #UndefinedInstruction
	STR	R2, [SP, #-4]!
	LDR	R2, [PC, #handle-$-8]
	BLX	R2
	ADD	SP, SP, #4
	LDMIA	SP!, {R0, R1, R2, R3, R4, R5, R6, R7, LR}
	SUBS	PC, LR, #4
header:
	d32	0x8000
undefined_instruction:
	d32	UndefinedInstructionHandler
software_interrupt:
	d32	SoftwareInterruptHandler
prefetch_abort:
	d32	PrefetchAbortHandler
data_abort:
	d32	DataAbortHandler
irq:
	d32	IRQHandler
handle:
	d32	HandleInterrupt
vector_end:
	MOV	R2, #0b10001
	MSR	CPSR_c, R2
	MOV	SP, #0x7000
	MOV	R2, #0b10010
	MSR	CPSR_c, R2
	MOV	SP, #0x6000
	MOV	R2, #0b10111
	MSR	CPSR_c, R2
	MOV	SP, #0x5000
	MOV	R2, #0b11011
	MSR	CPSR_c, R2
	MOV	SP, #0x4000
	MOV	R2, #0b10011
	MSR	CPSR_c, R2
END Initialize;

PROCEDURE {PLAIN} UndefinedInstructionHandler;
CODE
	STMDB	SP!, {R0, R1, R2, R3, R4, R5, R6, R7, R8, R9, R10, R11, R12, LR}
	MOV	R2, #UndefinedInstruction
	STR	R2, [SP, #-4]!
	LDR	R2, [PC, #handle-$-8]
	BLX	R2
	ADD	SP, SP, #4
	LDMIA	SP!, {R0, R1, R2, R3, R4, R5, R6, R7, R8, R9, R10, R11, R12, LR}
	MOVS	PC, LR
handle:
	d32	HandleInterrupt
END UndefinedInstructionHandler;

PROCEDURE {PLAIN} SoftwareInterruptHandler;
CODE
	STMDB	SP!, {R0, R1, R2, R3, R4, R5, R6, R7, R8, R9, R10, R11, R12, LR}
	MOV	R2, #SoftwareInterrupt
	STR	R2, [SP, #-4]!
	LDR	R2, [PC, #handle-$-8]
	BLX	R2
	ADD	SP, SP, #4
	LDMIA	SP!, {R0, R1, R2, R3, R4, R5, R6, R7, R8, R9, R10, R11, R12, LR}
	MOVS	PC, LR
handle:
	d32	HandleInterrupt
END SoftwareInterruptHandler;

PROCEDURE {PLAIN} PrefetchAbortHandler;
CODE
	STMDB	SP!, {R0, R1, R2, R3, R4, R5, R6, R7, R8, R9, R10, R11, R12, LR}
	MOV	R2, #PrefetchAbort
	STR	R2, [SP, #-4]!
	LDR	R2, [PC, #handle-$-8]
	BLX	R2
	ADD	SP, SP, #4
	LDMIA	SP!, {R0, R1, R2, R3, R4, R5, R6, R7, R8, R9, R10, R11, R12, LR}
	SUBS	PC, LR, #4
handle:
	d32	HandleInterrupt
END PrefetchAbortHandler;

PROCEDURE {PLAIN} DataAbortHandler;
CODE
	STMDB	SP!, {R0, R1, R2, R3, R4, R5, R6, R7, R8, R9, R10, R11, R12, LR}
	MOV	R2, #DataAbort
	STR	R2, [SP, #-4]!
	LDR	R2, [PC, #handle-$-8]
	BLX	R2
	ADD	SP, SP, #4
	LDMIA	SP!, {R0, R1, R2, R3, R4, R5, R6, R7, R8, R9, R10, R11, R12, LR}
	SUBS	PC, LR, #4
handle:
	d32	HandleInterrupt
END DataAbortHandler;

PROCEDURE {PLAIN} IRQHandler;
CODE
	STMDB	SP!, {R0, R1, R2, R3, R4, R5, R6, R7, R8, R9, R10, R11, R12, LR}
	MOV	R2, #IRQ
	STR	R2, [SP, #-4]!
	LDR	R2, [PC, #handle-$-8]
	BLX	R2
	ADD	SP, SP, #4
	LDMIA	SP!, {R0, R1, R2, R3, R4, R5, R6, R7, R8, R9, R10, R11, R12, LR}
	SUBS	PC, LR, #4
handle:
	d32	HandleInterrupt
END IRQHandler;

END CPU.
