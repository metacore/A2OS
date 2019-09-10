(* Runtime support for CPU internals *)
(* Copyright (C) Florian Negele *)

MODULE CPU;

IMPORT SYSTEM;

CONST StackSize* = 32 * 1024 * SIZEOF(ADDRESS);
CONST Quantum* = 1000000;
CONST CacheLineSize* = 64;
CONST StackDisplacement* = 0;

PROCEDURE Backoff-;
CODE
#IF I386 THEN
	MOV	EAX, 80000H
loop:	DEC	EAX
	JNZ		loop
#ELSIF AMD64 THEN
	MOV	EAX, 80000H
loop:	DEC	EAX
	JNZ		loop
#ELSE
	unimplemented
#END
END Backoff;

(* cpu control *)
PROCEDURE {NORETURN} Reset-;
CODE
#IF I386 THEN
	CLI
	PUSH	0
	PUSH	0
	LIDT	[ESP]
	INT3
#ELSIF AMD64 THEN
	CLI
	PUSH	0
	PUSH	0
	LIDT	[RSP]
	INT3
#ELSE
	unimplemented
#END
END Reset;

PROCEDURE {NORETURN} Halt-;
CODE
#IF I386 THEN
	CLI
end:	HLT
	JMP	end
#ELSIF AMD64 THEN
	CLI
end:	HLT
	JMP	end
#ELSE
	unimplemented
#END
END Halt;

(* input / output ports *)
PROCEDURE OutChar- (port: SIZE; value: CHAR);
CODE
#IF I386 THEN
	MOV	AL, [EBP + value]
	MOV	DX, [EBP + port]
	OUT	DX, AL
#ELSIF AMD64 THEN
	MOV	AL, [RBP + value]
	MOV	DX, [RBP + port]
	OUT	DX, AL
#ELSE
	unimplemented
#END
END OutChar;

PROCEDURE OutByte- (port: SIZE; value: SIZE);
CODE
#IF I386 THEN
	MOV	AL, [EBP + value]
	MOV	DX, [EBP + port]
	OUT	DX, AL
#ELSIF AMD64 THEN
	MOV	AL, [RBP + value]
	MOV	DX, [RBP + port]
	OUT	DX, AL
#ELSE
	unimplemented
#END
END OutByte;

PROCEDURE OutSet- (port: SIZE; value: SET);
CODE
#IF I386 THEN
	MOV	AL, [EBP + value]
	MOV	DX, [EBP + port]
	OUT	DX, AL
#ELSIF AMD64 THEN
	MOV	AL, [RBP + value]
	MOV	DX, [RBP + port]
	OUT	DX, AL
#ELSE
	unimplemented
#END
END OutSet;

PROCEDURE InChar- (port: SIZE): CHAR;
CODE
#IF I386 THEN
	MOV	DX, [EBP + port]
	IN		AL, DX
#ELSIF AMD64 THEN
	MOV	DX, [RBP + port]
	IN		AL, DX
#ELSE
	unimplemented
#END
END InChar;

PROCEDURE InByte- (port: SIZE): SIZE;
CODE
#IF I386 THEN
	MOV	DX, [EBP + port]
	IN		AL, DX
	MOVZX	EAX, AL
#ELSIF AMD64 THEN
	MOV	DX, [RBP + port]
	IN		AL, DX
	MOVZX	EAX, AL
#ELSE
	unimplemented
#END
END InByte;

PROCEDURE InSet- (port: SIZE): SET;
CODE
#IF I386 THEN
	MOV	DX, [EBP + port]
	IN		AL, DX
	MOVZX	EAX, AL
#ELSIF AMD64 THEN
	MOV	DX, [RBP + port]
	IN		AL, DX
	MOVZX	EAX, AL
#ELSE
	unimplemented
#END
END InSet;

PROCEDURE -SaveResult-;
CODE
#IF I386 THEN
	PUSH EAX
	PUSH EDX
#ELSIF AMD64 THEN
	PUSH RAX
#ELSE
	unimplemented
#END
END SaveResult;

PROCEDURE -RestoreResultAndReturn-;
CODE
#IF I386 THEN
	POP EDX
	POP EAX
	LEA ESP, [EBP + 4]
	POP EBP
	RET
#ELSIF AMD64 THEN
	POP RAX
	LEA RSP, [RBP + 8]
	POP RBP
	RET
#ELSE
	unimplemented
#END
END RestoreResultAndReturn;

PROCEDURE Mask- (port: SIZE; value: SET);
BEGIN {UNCOOPERATIVE, UNCHECKED}
	OutSet (port, InSet (port) + value);
END Mask;

PROCEDURE Unmask- (port: SIZE; value: SET);
BEGIN {UNCOOPERATIVE, UNCHECKED}
	OutSet (port, InSet (port) - value);
END Unmask;

(* interrupt handling *)
CONST Interrupts* = 48;
CONST IRQ0* = 32; IRQ1* = 33; IRQ2* = 34; IRQ3* = 35; IRQ4* = 36; IRQ5* = 37; IRQ6* = 38; IRQ7* = 39;
CONST IRQ8* = 40; IRQ9* = 41; IRQ10* = 42; IRQ11* = 43; IRQ12* = 44; IRQ13* = 45; IRQ14* = 46; IRQ15* = 47;

CONST PIC1CommandPort = 020H; PIC1DataPort = 021H; PIC2CommandPort = 0A0H; PIC2DataPort = 0A1H;
CONST ICW1_ICW4 = 001H; ICW1_INIT = 010H; ICW4_8086 = 001H; PIC_EOI = 020H; PIC_READ_ISR = 00AH;

TYPE InterruptHandler* = PROCEDURE (index: SIZE);

VAR handlers: ARRAY Interrupts OF InterruptHandler;

PROCEDURE InstallInterrupt- (handler: InterruptHandler; index: SIZE): InterruptHandler;
VAR previous: InterruptHandler;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	ASSERT (handler # NIL); ASSERT (index < Interrupts);
	REPEAT previous := CAS (handlers[index], NIL, NIL) UNTIL CAS (handlers[index], previous, handler) = previous;
	IF previous = NIL THEN EnableIRQ (index) END;
	RETURN previous;
END InstallInterrupt;

PROCEDURE HandleInterrupt (index: SIZE);
BEGIN {UNCOOPERATIVE, UNCHECKED}
	CODE
	#IF I386 THEN
		PUSHAD
	#ELSIF AMD64 THEN
		PUSH	RAX
		PUSH	RCX
		PUSH	RDX
		PUSH	RBX
		PUSH	RSI
		PUSH	RDI
		PUSH	R8
		PUSH	R9
		PUSH	R10
		PUSH	R11
		PUSH	R12
		PUSH	R13
		PUSH	R14
		PUSH	R15
	#ELSE
		unimplemented
	#END
	END;

	SYSTEM.SetActivity (NIL);

	IF handlers[index] # NIL THEN handlers[index] (index) ELSE HALT (1234) END;

	IF index >= IRQ8 THEN
		OutByte (PIC2CommandPort, PIC_EOI); OutByte (PIC1CommandPort, PIC_EOI);
	ELSIF index >= IRQ0 THEN
		OutByte (PIC1CommandPort, PIC_EOI);
	END;

	CODE
	#IF I386 THEN
		POPAD
	#ELSIF AMD64 THEN
		POP	R15
		POP	R14
		POP	R13
		POP	R12
		POP	R11
		POP	R10
		POP	R9
		POP	R8
		POP	RDI
		POP	RSI
		POP	RBX
		POP	RDX
		POP	RCX
		POP	RAX
	#ELSE
		unimplemented
	#END
	END;
END HandleInterrupt;

PROCEDURE DisableInterrupt- (index: SIZE);
VAR previous: InterruptHandler;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	ASSERT (index < Interrupts);
	DisableIRQ (index);
	REPEAT previous := CAS (handlers[index], NIL, NIL) UNTIL CAS (handlers[index], previous, NIL) = previous;
END DisableInterrupt;

PROCEDURE EnableIRQ- (index: SIZE);
BEGIN {UNCOOPERATIVE, UNCHECKED}
	ASSERT (index < Interrupts);
	IF (index >= IRQ0) & (index <= IRQ7) THEN Unmask (PIC1DataPort, {index - IRQ0}) END;
	IF (index >= IRQ8) & (index <= IRQ15) THEN Unmask (PIC2DataPort, {index - IRQ8}) END;
END EnableIRQ;

PROCEDURE DisableIRQ- (index: SIZE);
BEGIN {UNCOOPERATIVE, UNCHECKED}
	ASSERT (index < Interrupts);
	IF (index >= IRQ0) & (index <= IRQ7) THEN Mask (PIC1DataPort, {index - IRQ0}) END;
	IF (index >= IRQ8) & (index <= IRQ15) THEN Mask (PIC2DataPort, {index - IRQ8}) END;
END DisableIRQ;

#IF I386 THEN

VAR idt-: ARRAY Interrupts OF ARRAY 4 OF SIGNED16;
VAR wrapper: ARRAY Interrupts OF ARRAY 16 OF CHAR;

PROCEDURE Initialize-;
CONST IRETD = 0CFX; PUSH = 06AX; CALL = 0E8X; ADD = 083X; ESP = 0C4X;
VAR i, c: SIZE; address: ADDRESS;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	(* ICW1: initialization *)
	OutByte (PIC1CommandPort, ICW1_INIT + ICW1_ICW4);
	OutByte (PIC2CommandPort, ICW1_INIT + ICW1_ICW4);

	(* ICW2: vector offsets *)
	OutByte (PIC1DataPort, IRQ0);
	OutByte (PIC2DataPort, IRQ8);

	(* ICW3: cascading *)
	OutByte (PIC1DataPort, 4);
	OutByte (PIC2DataPort, 2);

	(* ICW4: mode *)
	OutByte (PIC1DataPort, ICW4_8086);
	OutByte (PIC2DataPort, ICW4_8086);

	(* mask all maskable interrupts *)
	OutChar (PIC1DataPort, 0FBX);
	OutChar (PIC2DataPort, 0FFX);

	FOR i := 0 TO Interrupts - 1 DO
		IF (i # 9) & (i # 15) & ((i < 20) OR (i > 29)) & (i # 31) THEN
			idt[i][0] := SIGNED16 (ADDRESS OF wrapper[i] MOD 10000H);
			idt[i][1] := SIGNED16(8H);
			idt[i][2] := SIGNED16(8E00H);
			idt[i][3] := SIGNED16(ADDRESS OF wrapper[i] DIV 10000H);

			c := 0;
			IF i # 2 THEN
				IF (i = 8) OR (i >= 10) & (i <= 14) OR (i = 17) THEN
					wrapper[i][c] := ADD; INC (c);
					wrapper[i][c] := ESP; INC (c);
					wrapper[i][c] := CHR (4); INC (c);
				END;
				wrapper[i][c] := PUSH; INC (c);
				wrapper[i][c] := CHR (i); INC (c);
				wrapper[i][c] := CALL; INC (c);
				address := ADDRESS OF HandleInterrupt - ADDRESS OF wrapper[i][c + 4];
				wrapper[i][c] := CHR (address DIV 1H); INC (c);
				wrapper[i][c] := CHR (address DIV 100H); INC (c);
				wrapper[i][c] := CHR (address DIV 10000H); INC (c);
				wrapper[i][c] := CHR (address DIV 1000000H); INC (c);
				wrapper[i][c] := ADD; INC (c);
				wrapper[i][c] := ESP; INC (c);
				wrapper[i][c] := CHR (4); INC (c);
			END;
			wrapper[i][c] := IRETD;
		ELSE
			idt[i][0] := 0;
			idt[i][1] := 0;
			idt[i][2] := 0;
			idt[i][3] := 0;
		END;
	END;

	CODE
		MOV	EAX, idt
		PUSH	EAX
		MOV	AX, Interrupts * 8
		PUSH	AX
		LIDT	[ESP]
		STI
	END;
END Initialize;

#ELSIF AMD64 THEN

VAR idt-: ARRAY Interrupts OF ARRAY 8 OF SIGNED16;
VAR wrapper: ARRAY Interrupts OF ARRAY 20 OF CHAR;

PROCEDURE Initialize-;
CONST IRETQ = 0CFX; PUSH = 06AX; CALL = 0E8X; REX = 048X; ADD = 083X; RSP = 0C4X;
VAR i, c: SIZE; address: ADDRESS;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	(* ICW1: initialization *)
	OutByte (PIC1CommandPort, ICW1_INIT + ICW1_ICW4);
	OutByte (PIC2CommandPort, ICW1_INIT + ICW1_ICW4);

	(* ICW2: vector offsets *)
	OutByte (PIC1DataPort, IRQ0);
	OutByte (PIC2DataPort, IRQ8);

	(* ICW3: cascading *)
	OutByte (PIC1DataPort, 4);
	OutByte (PIC2DataPort, 2);

	(* ICW4: mode *)
	OutByte (PIC1DataPort, ICW4_8086);
	OutByte (PIC2DataPort, ICW4_8086);

	(* mask all maskable interrupts *)
	OutChar (PIC1DataPort, 0FBX);
	OutChar (PIC2DataPort, 0FFX);

	FOR i := 0 TO Interrupts - 1 DO
		IF (i # 9) & (i # 15) & ((i < 20) OR (i > 29)) & (i # 31) THEN
			idt[i][0] := SIGNED16 (ADDRESS OF wrapper[i] MOD 10000H);
			idt[i][1] := SIGNED16(8H);
			idt[i][2] := SIGNED16(8E00H);
			idt[i][3] := SIGNED16(ADDRESS OF wrapper[i] DIV 10000H);

			c := 0;
			IF i # 2 THEN
				IF (i = 8) OR (i >= 10) & (i <= 14) OR (i = 17) THEN
					wrapper[i][c] := REX; INC (c);
					wrapper[i][c] := ADD; INC (c);
					wrapper[i][c] := RSP; INC (c);
					wrapper[i][c] := CHR (8); INC (c);
				END;
				wrapper[i][c] := PUSH; INC (c);
				wrapper[i][c] := CHR (i); INC (c);
				wrapper[i][c] := CALL; INC (c);
				address := ADDRESS OF HandleInterrupt - ADDRESS OF wrapper[i][c + 4];
				wrapper[i][c] := CHR (address DIV 1H); INC (c);
				wrapper[i][c] := CHR (address DIV 100H); INC (c);
				wrapper[i][c] := CHR (address DIV 10000H); INC (c);
				wrapper[i][c] := CHR (address DIV 1000000H); INC (c);
				wrapper[i][c] := REX; INC (c);
				wrapper[i][c] := ADD; INC (c);
				wrapper[i][c] := RSP; INC (c);
				wrapper[i][c] := CHR (8); INC (c);
			END;
			wrapper[i][c] := IRETQ;
		ELSE
			idt[i][0] := 0;
			idt[i][1] := 0;
			idt[i][2] := 0;
			idt[i][3] := 0;
		END;
		idt[i][4] := 0;
		idt[i][5] := 0;
		idt[i][6] := 0;
		idt[i][7] := 0;
	END;

	CODE
		LEA	RAX, [idt]
		PUSH	RAX
		MOV	AX, Interrupts * 8
		PUSH	AX
		LIDT	[RSP]
		STI
	END;
END Initialize;

#ELSE

	unimplemented

#END

END CPU.
