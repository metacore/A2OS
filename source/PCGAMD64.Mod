MODULE PCGAMD64;	(** AUTHOR "negelef"; PURPOSE "AMD64 code generator"; *)

IMPORT
		SYSTEM, PCLIR, PCM, PCBT, PCB, PCA := PCAAMD64, ASM := ASMAMD64;

CONST

	AlignParameters = TRUE;

	rAX = 0;
	rCX = 1;
	rDX = 2;
	rBX = 3;
	rSP = 4;
	rBP = 5;
	rSI = 6;
	rDI = 7;
	r8 = 8;
	r9 = 9;
	r10 = 10;
	r11 = 11;
	r12 = 12;
	r13 = 13;
	r14 = 14;
	r15 = 15;

	(* standard predefined register *)
	predefinedGppRegisters = {rAX, rCX, rDX, rSP, rBP, rDI, rSI};
	predefinedXmmRegisters = {};

	LegacyIntegers = {PCLIR.Int8, PCLIR.Int16, PCLIR.Int32};

TYPE

	XMM32 = OBJECT (PCA.XMMReg)
	END XMM32;

	XMM64 = OBJECT (PCA.XMMReg)
	END XMM64;

	Fixup = OBJECT (PCLIR.InstructionAttribute)
	VAR
		pc: SIGNED32;
		next: Fixup;
	END Fixup;

	CaseLine = OBJECT (PCLIR.InstructionAttribute)
	VAR
		first, last: BOOLEAN;
		from, to: SIGNED32;
	END CaseLine;

	Case = OBJECT (PCLIR.InstructionAttribute)
	VAR
		reg: PCA.Reg;
		prevCase, nextCase: Fixup;
		curCasePC: SIGNED32;
		curCaseLine: CaseLine;
	END Case;

	(* one set per register size *)
	RegisterSet = RECORD gpp, xmm: SET END;

VAR
	assembly: PCA.Assembly;

	currentRegisters: RegisterSet;
	savedRegisters: ARRAY 10 OF RegisterSet;
	saveLevel : SIGNED16;

PROCEDURE IsFloat (size: PCLIR.Size): BOOLEAN;
BEGIN RETURN (size = PCLIR.Float32) OR (size = PCLIR.Float64)
END IsFloat;

PROCEDURE NewXMM32 (index: SIGNED32): XMM32;
VAR xmm32: XMM32;
BEGIN NEW (xmm32, index); RETURN xmm32;
END NewXMM32;

PROCEDURE NewXMM64 (index: SIGNED32): XMM64;
VAR xmm64: XMM64;
BEGIN NEW (xmm64, index); RETURN xmm64;
END NewXMM64;

(* create a new register with the given size *)
PROCEDURE NewReg (size: PCLIR.Size; index: SIGNED32): PCA.Reg;
BEGIN CASE size OF
	| PCLIR.Int8: RETURN PCA.NewReg8 (index);
	| PCLIR.Int16: RETURN PCA.NewReg16 (index);
	| PCLIR.Int32: RETURN PCA.NewReg32 (index);
	| PCLIR.Int64: RETURN PCA.NewReg64 (index);
	| PCLIR.Float32: RETURN NewXMM32 (index);
	| PCLIR.Float64: RETURN NewXMM64 (index);
	END;
END NewReg;

PROCEDURE AllocReg (size: PCLIR.Size; index: SIGNED32);
BEGIN IF size IN PCLIR.FloatSize THEN
		INCL (currentRegisters.xmm, index);
	ELSE
		INCL (currentRegisters.gpp, index);
	END;
END AllocReg;

PROCEDURE FreeReg (size: PCLIR.Size; index: SIGNED32);
BEGIN IF size IN PCLIR.FloatSize THEN
		EXCL (currentRegisters.xmm, index);
	ELSE
		EXCL (currentRegisters.gpp, index);
	END;
END FreeReg;

PROCEDURE GetNextFreeReg (registerSet: SET): SIGNED32;
VAR  index: SIGNED32;
BEGIN index := 0;
	WHILE index IN registerSet DO INC (index) END;
	ASSERT (index <= r15);
	RETURN index;
END GetNextFreeReg;

(* look within the current register set for a free register with the given size *)
PROCEDURE AcquireReg (VAR instr: PCLIR.Instruction);
VAR index: SIGNED32; reg: PCA.Reg;
BEGIN
	IF instr.info = NIL THEN

		IF instr.dstSize IN PCLIR.FloatSize THEN
			index := GetNextFreeReg (currentRegisters.xmm + predefinedXmmRegisters) ;
		ELSE
			index := GetNextFreeReg (currentRegisters.gpp + predefinedGppRegisters) ;
		END;

		AllocReg (instr.dstSize, index);

		instr.info := NewReg (instr.dstSize, index);
	END;

	reg := instr.info(PCA.Reg);
	AllocReg (GetSize (reg), reg.index);
END AcquireReg;

(* return the given source register if this is its only access otherwise aquire a free register*)
PROCEDURE AcquireSourceReg (VAR instr: PCLIR.Instruction; VAR source: PCLIR.Register; piece: PCLIR.Piece);
VAR reg: PCA.Reg;
BEGIN
	IF (instr.info = NIL) & (source >= 0) & (piece.instr[source].dstCount = 1) THEN
		instr.info := NewReg (instr.dstSize, piece.instr[source].info(PCA.Reg).index);
		source := PCLIR.none;
	ELSE
		AcquireReg (instr);
		reg := GetReg (source, piece);
		IF instr.info(PCA.Reg).index = reg.index THEN
			DEC (piece.instr[source].dstCount);
			source := PCLIR.none;
		ELSE
			assembly.Emit (ASM.opMOV, instr.info(PCA.Reg), reg, NIL);
			ReleaseSourceReg (source, piece);
		END;
	END;
END AcquireSourceReg;

(* return a source register *)
PROCEDURE GetReg (source: PCLIR.Register; piece: PCLIR.Piece): PCA.Reg;
CONST HwReg = PCLIR.HwReg + 8;
BEGIN
	IF source >= 0 THEN
		RETURN piece.instr[source].info(PCA.Reg);
	ELSE
		CASE source OF
		| PCLIR.FP:
			RETURN PCA.NewReg64 (rBP);
		| PCLIR.SP:
			RETURN PCA.NewReg64 (rSP);
		| PCLIR.Absolute:
			RETURN NIL;

		| HwReg - PCB.regRDI .. HwReg - PCB.regRAX:
			RETURN PCA.NewReg64 (HwReg - PCB.regRAX - source);
		| HwReg - PCB.regR15, HwReg - PCB.regR8:
			RETURN PCA.NewReg64 (HwReg - PCB.regR8 + 8 - source);

		| HwReg - PCB.regEDI .. HwReg - PCB.regEAX:
			RETURN PCA.NewReg32 (HwReg - PCB.regEAX - source);
		| HwReg - PCB.regR15D, HwReg - PCB.regR8D:
			RETURN PCA.NewReg32 (HwReg - PCB.regR8D + 8 - source);

		| HwReg - PCB.regBX .. HwReg - PCB.regAX:
			RETURN PCA.NewReg16 (HwReg - PCB.regAX - source);
		| HwReg - PCB.regR15W, HwReg - PCB.regR8W:
			RETURN PCA.NewReg16 (HwReg - PCB.regR8W + 8 - source);

		| HwReg - PCB.regBL, HwReg - PCB.regAL:
			RETURN PCA.NewReg8 (HwReg - PCB.regAL - source);
		| HwReg - PCB.regR15B, HwReg - PCB.regR8B:
			RETURN PCA.NewReg8 (HwReg - PCB.regR8B + 8 - source);

		END;
	END;
END GetReg;

PROCEDURE GetSize (reg: PCA.Reg): PCLIR.Size;
BEGIN
	IF reg IS PCA.Reg8 THEN
		RETURN PCLIR.Int8;
	ELSIF reg IS PCA.Reg16 THEN
		RETURN PCLIR.Int16;
	ELSIF reg IS PCA.Reg32 THEN
		RETURN PCLIR.Int32;
	ELSIF reg IS PCA.Reg64 THEN
		RETURN PCLIR.Int64;
	ELSIF reg IS PCA.Reg64 THEN
		RETURN PCLIR.Int64;
	ELSIF reg IS XMM32 THEN
		RETURN PCLIR.Float32;
	ELSIF reg IS XMM64 THEN
		RETURN PCLIR.Float64;
	END;
END GetSize;

(* release a register and return it to the register pool if there are no more accesses to it *)
PROCEDURE ReleaseReg (VAR instr: PCLIR.Instruction);
BEGIN
	DEC (instr.dstCount);

	IF instr.dstCount = 0 THEN
		FreeReg (instr.dstSize, instr.info(PCA.Reg).index);
	END;
END ReleaseReg;

(* release a source register and return it to the register pool if there are no more accesses to it *)
PROCEDURE ReleaseSourceReg (source: PCLIR.Register; piece: PCLIR.Piece);
BEGIN
	IF source >= 0 THEN
		ReleaseReg (piece.instr[source]);
	END;
END ReleaseSourceReg;

PROCEDURE NewImm (size: PCLIR.Size; val: SIGNED32): PCA.Imm;
BEGIN
	CASE size OF
	| PCLIR.Int8: RETURN PCA.NewImm8 (val);
	| PCLIR.Int16: RETURN PCA.NewImm16 (val);
	| PCLIR.Int32: RETURN PCA.NewImm32 (val);
	| PCLIR.Int64: RETURN PCA.NewImm64 (val);
	END;
END NewImm;

PROCEDURE NewMem (size: PCLIR.Size; reg: PCA.Reg; displacement: SIGNED32): PCA.Mem;
BEGIN
	CASE size OF
	| PCLIR.Int8: RETURN PCA.NewMem8 (reg, displacement);
	| PCLIR.Int16: RETURN PCA.NewMem16 (reg, displacement);
	| PCLIR.Int32: RETURN PCA.NewMem32 (reg, displacement);
	| PCLIR.Int64: RETURN PCA.NewMem64 (reg, displacement);
	| PCLIR.Float32: RETURN PCA.NewMem32 (reg, displacement);
	| PCLIR.Float64: RETURN PCA.NewMem64 (reg, displacement);
	END;
END NewMem;

(*
PROCEDURE Dump (code: PCLIR.Code;  VAR instr: PCLIR.Instruction;  pc: SIGNED32);
BEGIN
	PCM.log.CharLn;
	PCM.log.CharStr(PCLIR.InstructionSet[instr.op].name); PCM.log.CharLn;
	PCM.log.CharStr("  code.barrier: "); PCM.log.CharNum (code.barrier); PCM.log.CharLn;
	PCM.log.CharStr("  instr.src1: "); PCM.log.CharNum (instr.src1); PCM.log.CharLn;
	PCM.log.CharStr("  instr.src2: "); PCM.log.CharNum (instr.src2); PCM.log.CharLn;
	PCM.log.CharStr("  instr.src3: "); PCM.log.CharNum (instr.src3); PCM.log.CharLn;
	PCM.log.CharStr("  instr.val: "); PCM.log.CharNum (instr.val); PCM.log.CharLn;
	PCM.log.CharStr("  instr.adr: "); PCM.log.CharBool (instr.adr # NIL); PCM.log.CharLn;
	IF (instr.adr # NIL) & (instr.adr IS PCBT.Procedure) THEN
		PCM.log.CharStr("    procedure ");  PCM.log.CharLn;
	END;
	IF (instr.adr # NIL) & (instr.adr IS PCBT.Variable) THEN
		PCM.log.CharStr("   Variable:");  PCM.log.CharLn;
		PCM.log.CharStr("    offset"); PCM.log.CharNum (instr.adr(PCBT.Variable).offset); PCM.log.CharLn;
	END;
	PCM.log.CharStr("  instr.suppress: "); PCM.log.CharBool (instr.suppress); PCM.log.CharLn;
	PCM.log.CharStr("  instr.dstCount: "); PCM.log.CharNum (instr.dstCount); PCM.log.CharLn;
	PCM.log.CharStr("  instr.dstSize: "); PCM.log.CharNum (instr.dstSize); PCM.log.CharLn;
	PCM.log.CharStr("  instr.dstSigned: "); PCM.log.CharBool (instr.dstSigned); PCM.log.CharLn;
	PCM.log.CharStr("  instr.info: "); PCM.log.CharBool (instr.info # NIL); PCM.log.CharLn;
	PCM.log.CharStr("  pc: "); PCM.log.CharNum (pc); PCM.log.CharLn;
END Dump;
*)

PROCEDURE InstructionInit(VAR instr: PCLIR.Instruction);
END InstructionInit;

PROCEDURE IsAbsolute (adr: PCM.Attribute): BOOLEAN;
BEGIN
	IF adr # NIL THEN
		IF adr IS PCBT.GlobalVariable THEN
			RETURN TRUE;
		ELSIF adr IS PCBT.Procedure THEN
			RETURN TRUE
		END;
	END;
	RETURN FALSE;
END IsAbsolute;

PROCEDURE FixAbsolute (adr: PCM.Attribute; pc: SIGNED32);
BEGIN
	IF adr # NIL THEN
		IF adr IS PCBT.GlobalVariable THEN
			PCBT.context.UseVariable (adr(PCBT.GlobalVariable), pc)
		ELSIF adr IS PCBT.Procedure THEN
			PCBT.context.UseProcedure (adr(PCBT.Procedure), pc)
		END;
	END;
END FixAbsolute;

PROCEDURE FixFixups (VAR fixup: Fixup);
VAR prevPC: SIGNED32;
BEGIN
	IF fixup # NIL THEN
		prevPC := assembly.pc;
		REPEAT
			assembly.SetPC (fixup.pc - 4);
			assembly.PutDWord (prevPC - fixup.pc);
			fixup := fixup.next;
		UNTIL fixup = NIL;
		assembly.SetPC (prevPC);
		fixup := NIL;
	END
END FixFixups;

(* Code Generation Procedures *)

PROCEDURE EmitPush (reg: PCA.Reg);
VAR RSP: PCA.Reg;
BEGIN
	IF AlignParameters THEN
		assembly.Emit (ASM.opPUSH, PCA.NewReg64 (reg.index), NIL, NIL);
	ELSE
		CASE GetSize (reg) OF
		PCLIR.Int16, PCLIR.Int64:
			assembly.Emit (ASM.opPUSH, reg, NIL, NIL);
		| PCLIR.Int32:
			RSP := PCA.NewReg64 (rSP);
			assembly.Emit (ASM.opSUB, RSP, PCA.NewImm8 (4), NIL);
			assembly.Emit (ASM.opMOV, PCA.NewMem32 (RSP, 0), reg, NIL);
		END;
	END;
END EmitPush;

PROCEDURE EmitPop (reg: PCA.Reg);
VAR RSP: PCA.Reg;
BEGIN
	IF AlignParameters THEN
		assembly.Emit (ASM.opPOP, PCA.NewReg64 (reg.index), NIL, NIL);
	ELSE
		CASE GetSize (reg) OF
		PCLIR.Int16, PCLIR.Int64:
			assembly.Emit (ASM.opPOP, reg, NIL, NIL);
		| PCLIR.Int32:
			RSP := PCA.NewReg64 (rSP);
			assembly.Emit (ASM.opMOV, reg, PCA.NewMem32 (RSP, 0), NIL);
			assembly.Emit (ASM.opADD, RSP, PCA.NewImm8 (4), NIL);
		END;
	END;
END EmitPop;

PROCEDURE EmitResult (VAR instr: PCLIR.Instruction; srcReg: SIGNED32);
VAR op: SIGNED32; source: PCA.Reg;
BEGIN
	AcquireReg (instr);

	CASE instr.dstSize OF
	PCLIR.Int8 .. PCLIR.Int64:
		op := ASM.opMOV;
		source := NewReg (instr.dstSize, srcReg);
	| PCLIR.Float32:
		op := ASM.opMOVD;
		source := PCA.NewReg32 (srcReg);
	| PCLIR.Float64:
		op := ASM.opMOVD;
		source := PCA.NewReg64 (srcReg);
	END;

	assembly.Emit (op, instr.info(PCA.Reg), source, NIL);
	FreeReg (PCLIR.Int64, srcReg);
END EmitResult;

PROCEDURE EmitReturn (code: PCLIR.Code; VAR instr: PCLIR.Instruction; destReg: SIGNED32);
VAR
	piece1: PCLIR.Piece;
	reg1, dest: PCA.Reg;
	sourceSize: PCLIR.Size;
	op: SIGNED32;

BEGIN
	code.GetPiece (instr.src1, piece1);
	reg1 := GetReg (instr.src1, piece1);

	sourceSize := GetSize (reg1);

	CASE sourceSize OF
	PCLIR.Int8 .. PCLIR.Int64:
		op := ASM.opMOV;
		dest := NewReg (sourceSize, destReg);
	| PCLIR.Float32:
		op := ASM.opMOVD;
		dest := PCA.NewReg32 (destReg);
	| PCLIR.Float64:
		op := ASM.opMOVD;
		dest := PCA.NewReg64 (destReg);
	END;

	assembly.Emit (op, dest, reg1, NIL);
	AllocReg (sourceSize, destReg);

	ReleaseSourceReg (instr.src1, piece1);

END EmitReturn;

PROCEDURE EmitJmp (opCode: SIGNED32; code: PCLIR.Code;  VAR instr: PCLIR.Instruction);
VAR piece1: PCLIR.Piece; offset: SIGNED32; fixup: Fixup;
BEGIN
	code.GetPiece (instr.val, piece1);

	IF piece1.instr[instr.val].val = 0 THEN
		assembly.Emit (opCode, PCA.NewImm32 (0), NIL, NIL);
		NEW (fixup); fixup.pc := assembly.pc;
		IF piece1.instr[instr.val].info # NIL THEN
			fixup.next := piece1.instr[instr.val].info(Fixup);
		END;
		piece1.instr[instr.val].info := fixup;
	ELSE
		assembly.Emit (opCode, PCA.NewOffset32 (piece1.instr[instr.val].val), NIL, NIL);
	END;

END EmitJmp;

PROCEDURE EmitType1 (op: SIGNED32; code: PCLIR.Code;  VAR instr: PCLIR.Instruction; operand: PCA.Operand);
VAR piece1: PCLIR.Piece;
BEGIN
	code.GetPiece (instr.src1, piece1);
	AcquireSourceReg (instr, instr.src1, piece1);

	(* minor optimizations *)
	IF (instr.src1 = PCLIR.none) & (operand # NIL) & (operand IS PCA.Imm) THEN
		IF (op = ASM.opADD) & (operand(PCA.Imm).val = 1) THEN op := ASM.opINC; operand := NIL END;
		IF (op = ASM.opADD) & (operand(PCA.Imm).val = -1) THEN op := ASM.opDEC; operand := NIL END;
		IF (op = ASM.opSUB) & (operand(PCA.Imm).val = 1) THEN op := ASM.opDEC; operand := NIL END;
		IF (op = ASM.opSUB) & (operand(PCA.Imm).val = -1) THEN op := ASM.opINC; operand := NIL END;
	END;

	IF (op = ASM.opIMUL) & (GetSize (operand(PCA.Reg)) = PCLIR.Int8) THEN
		assembly.Emit (ASM.opMOV, PCA.NewReg8 (rAX), operand, NIL);
		assembly.Emit (op, instr.info(PCA.Reg), NIL, NIL);
	ELSIF op # ASM.opNOP THEN
		assembly.Emit (op, instr.info(PCA.Reg), operand, NIL);
	END;
END EmitType1;

PROCEDURE EmitType2 (op: SIGNED32; code: PCLIR.Code;  VAR instr: PCLIR.Instruction);
VAR piece2: PCLIR.Piece;
BEGIN
	IF instr.src2 = PCLIR.none THEN
		EmitType1 (op, code, instr, PCA.NewImm (PCA.default, instr.val));
	ELSE
		code.GetPiece (instr.src2, piece2);
		EmitType1 (op, code, instr, GetReg (instr.src2, piece2));
		ReleaseSourceReg (instr.src2, piece2);
	END;
END EmitType2;

PROCEDURE EmitSSEBitOp (code: PCLIR.Code;  VAR instr: PCLIR.Instruction;  op, bit: SIGNED32; invert: BOOLEAN);
VAR RAX, tmp: PCA.Reg;
BEGIN
	RAX := PCA.NewReg64 (rAX);
	assembly.Emit (ASM.opXOR, RAX, RAX, NIL);
	assembly.Emit (ASM.opBTS, RAX, PCA.NewImm8 (bit), NIL);
	IF invert THEN
		assembly.Emit (ASM.opNOT, RAX, NIL, NIL);
	END;
	tmp := PCA.NewXMMReg (GetNextFreeReg (currentRegisters.xmm + predefinedXmmRegisters));
	assembly.Emit (ASM.opMOVD, tmp, RAX, NIL);
	EmitType1 (op, code, instr, tmp);
END EmitSSEBitOp;

PROCEDURE EmitMove(code: PCLIR.Code;  VAR instr: PCLIR.Instruction;  op: SIGNED32);
VAR
	piece1, piece2, piece3: PCLIR.Piece;
	from, to, size: PCA.Reg;
	RSI, RDI, RCX: PCA.Reg;
BEGIN

	code.GetPiece (instr.src1, piece1);
	code.GetPiece (instr.src2, piece2);
	code.GetPiece (instr.src3, piece3);

	from := GetReg (instr.src1, piece1);
	to := GetReg (instr.src2, piece2);
	size := GetReg (instr.src3, piece3);

	RSI := NewReg (GetSize (from), rSI);
	RDI := NewReg (GetSize (to), rDI);
	RCX := NewReg (GetSize (size), rCX);

	assembly.Emit (ASM.opMOV,  RSI, from, NIL);
	assembly.Emit (ASM.opMOV,  RDI, to, NIL);
	assembly.Emit (ASM.opMOV,  RCX, size, NIL);

	assembly.Emit (op, NIL, NIL, NIL);

	assembly.EmitPrefix (ASM.prfREP);
	assembly.Emit (ASM.opMOVSB, NIL, NIL, NIL);

	ReleaseSourceReg (instr.src1, piece1);
	ReleaseSourceReg (instr.src2, piece2);
	ReleaseSourceReg (instr.src3, piece3);

END EmitMove;

PROCEDURE EmitCmpJmp (reg: PCA.Reg; val: SIGNED32; op: SIGNED32; VAR fixup: Fixup);
VAR fix: Fixup;
BEGIN
	assembly.Emit (ASM.opCMP, reg, PCA.NewImm (PCA.default, val), NIL);
	assembly.Emit (op, PCA.NewImm32 (0), NIL, NIL);
	NEW (fix); fix.pc := assembly.pc; fix.next := fixup; fixup := fix
END EmitCmpJmp;

(* GenEnter - Create Procedure activation frame of given size and clear the stack *)
PROCEDURE GenEnter (code: PCLIR.Code;  VAR instr: PCLIR.Instruction;  pc: SIGNED32);
CONST PushLoopUnrollSize = 4;
VAR stackSize, i: SIGNED32;  adr: PCBT.Procedure;

	PROCEDURE FixAddress;
	VAR prevPC, nextPC: SIGNED32;
	BEGIN
		prevPC := assembly.pc;
		WHILE adr.fixlist # PCBT.FixupSentinel DO
			assembly.SetPC (adr.fixlist);
			nextPC := assembly.GetDWord ();
			assembly.SetPC (adr.fixlist);
			assembly.PutDWord (prevPC - 4 - adr.fixlist);
			adr.fixlist := nextPC;
		END;
		assembly.SetPC (prevPC);
	END FixAddress;

BEGIN
	IF (instr.adr # NIL) & (instr.adr IS PCBT.Procedure) THEN
		adr := instr.adr(PCBT.Procedure);
		PCBT.context.AddOwnProc (adr, assembly.pc);
		FixAddress;
		stackSize := adr.locsize
	ELSE
		stackSize := 0
	END;

	(* check calling convention *)
	IF instr.val = PCBT.OberonPassivateCC THEN

		(* push the current stack frame on the stack *)
		assembly.Emit (ASM.opPUSH, PCA.NewReg64 (rBP), NIL, NIL);
		(* assign the first argument to the stack frame (16 = 8 for RIP pushed by caller + 8 for preceding push) *)
		assembly.Emit (ASM.opMOV, PCA.NewReg64 (rBP), PCA.NewMem64 (PCA.NewReg64 (rSP), 16), NIL);

	ELSIF PCM.FullStackInit IN PCM.codeOptions THEN

		(* ENTER instruction instead of PUSH RBP, MOV RBP, RSP; both versions need 4 byte in 64-bit mode *)
		assembly.Emit (ASM.opENTER, PCA.NewImm16 (0), PCA.NewImm8 (0), NIL);

		(* clear the stack and choose smallest encoding for given stack size (needs some performance heuristic ?) *)

		ASSERT (stackSize MOD 8 = 0);

		IF stackSize > 120 THEN
			assembly.Emit (ASM.opXOR, PCA.NewReg32 (rAX), PCA.NewReg32 (rAX), NIL);

			assembly.Emit (ASM.opMOV, PCA.NewReg32 (rCX), PCA.NewImm (PCA.default, stackSize DIV (8 * PushLoopUnrollSize)), NIL);

			stackSize := stackSize MOD (8 * PushLoopUnrollSize);

			WHILE stackSize # 0 DO
				assembly.Emit (ASM.opPUSH, PCA.NewReg64 (rAX), NIL, NIL);
				DEC (stackSize, 8);
			END;

			stackSize := assembly.pc;

			assembly.Emit (ASM.opDEC, PCA.NewReg32 (rCX), NIL, NIL);

			FOR i := 0 TO PushLoopUnrollSize - 1 DO
				assembly.Emit (ASM.opPUSH, PCA.NewReg64 (rAX), NIL, NIL);
			END;

			assembly.Emit (ASM.opJNZ, PCA.NewOffset8 (stackSize), NIL, NIL);

		ELSIF stackSize > 16 THEN
			assembly.Emit (ASM.opXOR, PCA.NewReg32 (rAX), PCA.NewReg32 (rAX), NIL);
			WHILE stackSize # 0 DO
				assembly.Emit (ASM.opPUSH, PCA.NewReg64 (rAX), NIL, NIL);
				DEC (stackSize, 8);
			END;
		ELSE
			WHILE stackSize # 0 DO
				assembly.Emit (ASM.opPUSH, PCA.NewImm8 (0), NIL, NIL);
				DEC (stackSize, 8);
			END;
		END;
	ELSE
		(* performs PUSH RBP; MOV RBP, RSP; SUB RSP, stackSize *)
		assembly.Emit (ASM.opENTER, PCA.NewImm16 (stackSize), PCA.NewImm8 (0), NIL);
	END;

	currentRegisters.gpp := {};
	currentRegisters.xmm := {};
	saveLevel := 0;

END GenEnter;

(* GenExit - Remove procedure activation frame, remove the give size of parameters and return to the caller *)
PROCEDURE GenExit (code: PCLIR.Code;  VAR instr: PCLIR.Instruction;  pc: SIGNED32);
BEGIN
	IF instr.val = PCBT.OberonPassivateCC THEN
		(* pop the stack frame from the stack *)
		assembly.Emit (ASM.opPOP, PCA.NewReg64 (rBP), NIL, NIL);
		(* return to caller popping the first argument *)
		assembly.Emit (ASM.opRET, PCA.NewImm16 (8), NIL, NIL);
	ELSE
		assembly.Emit (ASM.opLEAVE, NIL, NIL, NIL);

		FreeReg (PCLIR.Int64, rAX); FreeReg (PCLIR.Int64, rDX);

		IF instr.src1 = 0 THEN
			assembly.Emit (ASM.opRET, NIL, NIL, NIL);
		ELSE
			assembly.Emit (ASM.opRET, PCA.NewImm16 (instr.src1), NIL, NIL);
		END
	END;
END GenExit;

PROCEDURE GenTrap (code: PCLIR.Code;  VAR instr: PCLIR.Instruction;  pc: SIGNED32);
BEGIN
	(* prohibit pushing a 16-bit immediate which decrements the stack pointer by two not by 8 *)
	IF instr.val < 80H THEN
		assembly.Emit (ASM.opPUSH, PCA.NewImm8 (instr.val), NIL, NIL);
	ELSE
		assembly.Emit (ASM.opPUSH, PCA.NewImm32 (instr.val), NIL, NIL);
	END;
	assembly.Emit (ASM.opINT3, NIL, NIL, NIL);
END GenTrap;

PROCEDURE GenTrapcc (code: PCLIR.Code;  VAR instr: PCLIR.Instruction;  pc: SIGNED32);
VAR
	piece1, piece2: PCLIR.Piece;
	reg1, reg2: PCA.Reg;
	cmpop, jmpop: SIGNED32;
BEGIN
	code.GetPiece (instr.src1, piece1);
	code.GetPiece (instr.src2, piece2);

	reg1 := GetReg (instr.src1, piece1);
	reg2 := GetReg (instr.src2, piece2);

	CASE instr.op OF
	PCLIR.tae:
		cmpop := ASM.opCMP; jmpop := ASM.opJB;
	| PCLIR.tne:
		cmpop := ASM.opCMP; jmpop := ASM.opJE;
	END;

	CASE GetSize (reg1) OF
	PCLIR.Int8 .. PCLIR.Int64:
	| PCLIR.Float32:
		cmpop := ASM.opCOMISS;
	| PCLIR.Float64:
		cmpop := ASM.opCOMISD;
	END;

	assembly.Emit (cmpop, reg1, reg2, NIL);

	IF instr.val < 80H THEN
		assembly.Emit (jmpop, PCA.NewImm8 (3), NIL, NIL); (* one byte push in trap *)
	ELSE
		assembly.Emit (jmpop, PCA.NewImm8 (3), NIL, NIL); (* four byte push in trap *)
	END;

	GenTrap (code, instr, pc);

	ReleaseSourceReg (instr.src1, piece1);
	ReleaseSourceReg (instr.src2, piece2);
END GenTrapcc;

PROCEDURE GenSaveRegisters (code: PCLIR.Code;  VAR instr: PCLIR.Instruction;  pc: SIGNED32);
VAR index: SIGNED32; RAX: PCA.Reg;
BEGIN
	RAX := PCA.NewReg64 (rAX);
	FOR index := rAX TO r15 DO
		IF index IN currentRegisters.gpp THEN
			assembly.Emit (ASM.opPUSH, PCA.NewReg64 (index), NIL, NIL);
		END;
		IF index IN currentRegisters.xmm THEN
			assembly.Emit (ASM.opMOVD, RAX, PCA.NewXMMReg (index), NIL);
			assembly.Emit (ASM.opPUSH, RAX, NIL, NIL);
		END;
	END;
	savedRegisters[saveLevel] := currentRegisters; INC (saveLevel);
END GenSaveRegisters;

PROCEDURE GenRestoreRegisters (code: PCLIR.Code;  VAR instr: PCLIR.Instruction;  pc: SIGNED32);
VAR index: SIGNED32; RAX: PCA.Reg;
BEGIN
	DEC (saveLevel);
	RAX := PCA.NewReg64 (rAX);
	FOR index := r15 TO rAX BY -1 DO
		IF index IN savedRegisters[saveLevel].xmm THEN
			assembly.Emit (ASM.opPOP, RAX, NIL, NIL);
			assembly.Emit (ASM.opMOVD, PCA.NewXMMReg (index), RAX, NIL);
		END;
		IF index IN savedRegisters[saveLevel].gpp THEN
			assembly.Emit (ASM.opPOP, PCA.NewReg64 (index), NIL, NIL);
		END;
	END;
	currentRegisters.gpp := currentRegisters.gpp + savedRegisters[saveLevel].gpp;
	currentRegisters.xmm := currentRegisters.xmm + savedRegisters[saveLevel].xmm;
END GenRestoreRegisters;

PROCEDURE GenPush (code: PCLIR.Code;  VAR instr: PCLIR.Instruction;  pc: SIGNED32);
VAR
	piece1: PCLIR.Piece;
	reg1, tmp: PCA.Reg;

BEGIN
	code.GetPiece (instr.src1, piece1);
	reg1 := GetReg (instr.src1, piece1);

	CASE GetSize (reg1) OF
	PCLIR.Int8 .. PCLIR.Int64:
		EmitPush (reg1);
	| PCLIR.Float32:
		tmp := PCA.NewReg32 (rAX);
		assembly.Emit (ASM.opMOVD, tmp, reg1, NIL);
		EmitPush (tmp);
	| PCLIR.Float64:
		tmp := PCA.NewReg64 (rAX);
		assembly.Emit (ASM.opMOVD, tmp, reg1, NIL);
		EmitPush (tmp);
	END;

	ReleaseSourceReg (instr.src1, piece1);
END GenPush;

PROCEDURE GenPop (code: PCLIR.Code;  VAR instr: PCLIR.Instruction;  pc: SIGNED32);
VAR tmp: PCA.Reg;
BEGIN
	AcquireReg (instr);

	CASE instr.dstSize OF
	PCLIR.Int8 .. PCLIR.Int64:
		EmitPop (instr.info(PCA.Reg));
	| PCLIR.Float32:
		tmp := PCA.NewReg32 (rAX);
		EmitPop (tmp);
		assembly.Emit (ASM.opCVTSI2SS, instr.info(PCA.Reg), tmp, NIL);
	| PCLIR.Float64:
		tmp := PCA.NewReg64 (rAX);
		EmitPop (tmp);
		assembly.Emit (ASM.opCVTSI2SD, instr.info(PCA.Reg), tmp, NIL);
	END;
END GenPop;

(* GenResult - Allocate the registers for functions results (after a call) *)
PROCEDURE GenResult (code: PCLIR.Code;  VAR instr: PCLIR.Instruction;  pc: SIGNED32);
BEGIN EmitResult (instr, rAX);
END GenResult;

PROCEDURE GenResult2 (code: PCLIR.Code;  VAR instr: PCLIR.Instruction;  pc: SIGNED32);
BEGIN EmitResult (instr, rDX);
END GenResult2;

PROCEDURE GenReturn (code: PCLIR.Code;  VAR instr: PCLIR.Instruction;  pc: SIGNED32);
BEGIN EmitReturn (code, instr, rAX);
END GenReturn;

PROCEDURE GenReturn2 (code: PCLIR.Code;  VAR instr: PCLIR.Instruction;  pc: SIGNED32);
BEGIN EmitReturn (code, instr, rDX);
END GenReturn2;

PROCEDURE GenLoad (code: PCLIR.Code;  VAR instr: PCLIR.Instruction;  pc: SIGNED32);
VAR
	piece1: PCLIR.Piece;
	reg1, tmp: PCA.Reg;
	imm: PCA.Imm;
	op: SIGNED32;
BEGIN
	code.GetPiece (instr.src1, piece1);

	reg1 := GetReg (instr.src1, piece1);

	IF instr.dstCount # 0 THEN

		AcquireReg (instr);

		CASE instr.dstSize OF
		PCLIR.Int8 .. PCLIR.Int64:
			op := ASM.opMOV;
		| PCLIR.Float32:
			op := ASM.opMOVSS;
		| PCLIR.Float64:
			op := ASM.opMOVSD;
		END;

		IF IsAbsolute (instr.adr) THEN
			tmp := PCA.NewReg64 (instr.info(PCA.Reg).index);
			imm := PCA.NewImm64 (instr.val);
			assembly.Emit (ASM.opMOV, tmp, imm, NIL);
			assembly.Emit (op, instr.info(PCA.Reg), NewMem (instr.dstSize, tmp, 0), NIL);
			FixAbsolute (instr.adr, imm.pc);
		ELSE
			assembly.Emit (op, instr.info(PCA.Reg), NewMem (instr.dstSize, reg1, instr.val), NIL);
		END;

	END;

	ReleaseSourceReg (instr.src1, piece1);
END GenLoad;

PROCEDURE GenLoadC (code: PCLIR.Code;  VAR instr: PCLIR.Instruction;  pc: SIGNED32);
VAR imm: PCA.Imm;
BEGIN
	ASSERT (instr.dstSize IN PCLIR.IntSize);

	IF instr.dstCount # 0 THEN

		AcquireReg (instr);

		IF IsAbsolute (instr.adr) THEN
			imm := PCA.NewImm64 (instr.val);
			assembly.Emit (ASM.opMOV,  instr.info(PCA.Reg), imm, NIL);
			FixAbsolute (instr.adr, imm.pc);
		ELSIF (instr.val = 0) & (instr.adr = NIL) THEN
			assembly.Emit (ASM.opXOR, instr.info(PCA.Reg), instr.info(PCA.Reg), NIL);
		ELSIF (instr.dstSize = PCLIR.Int64) & (SYSTEM.VAL(SIGNED32, instr.val) = instr.val) THEN
			(*	since the upper half of the 64bit wide target register is signed extended using
				this MOV instruction, one can save the leading bits of the 64bit wide immediate value	*)
			assembly.Emit (ASM.opMOV,  instr.info(PCA.Reg), PCA.NewImm32 (instr.val), NIL);
		ELSE
			assembly.Emit (ASM.opMOV,  instr.info(PCA.Reg), NewImm (instr.dstSize, instr.val), NIL);
		END;
	END;
END GenLoadC;

PROCEDURE GenLoadSP(code: PCLIR.Code;  VAR instr: PCLIR.Instruction;  pc: SIGNED32);
VAR piece1: PCLIR.Piece; reg1: PCA.Reg;
BEGIN
	code.GetPiece (instr.src1, piece1);
	reg1 := GetReg (instr.src1, piece1);
	assembly.Emit (ASM.opMOV, PCA.NewReg64 (rSP), reg1, NIL);
	ReleaseSourceReg (instr.src1, piece1);
END GenLoadSP;

PROCEDURE GenLoadFP(code: PCLIR.Code;  VAR instr: PCLIR.Instruction;  pc: SIGNED32);
VAR piece1: PCLIR.Piece; reg1: PCA.Reg;
BEGIN
	code.GetPiece (instr.src1, piece1);
	reg1 := GetReg (instr.src1, piece1);
	assembly.Emit (ASM.opMOV, PCA.NewReg64 (rBP), reg1, NIL);
	ReleaseSourceReg (instr.src1, piece1);
END GenLoadFP;

PROCEDURE GenStore (code: PCLIR.Code;  VAR instr: PCLIR.Instruction;  pc: SIGNED32);
VAR
	piece1, piece2: PCLIR.Piece;
	dest: PCA.Reg;
	source: PCA.Operand;
	dstSize: PCLIR.Size;
	op: SIGNED32;
BEGIN
	code.GetPiece (instr.src1, piece1);
	code.GetPiece (instr.src2, piece2);

	dest := GetReg (instr.src1, piece1);

	IF (instr.src2 >= 0) & (piece2.instr[instr.src2].suppress) & (piece2.instr[instr.src2].op = PCLIR.loadc) THEN

		source := PCA.NewImm (PCA.default, piece2.instr[instr.src2].val);

		dstSize := piece2.instr[instr.src2].dstSize;

		IF dstSize = PCLIR.Int64 THEN dstSize := PCLIR.Int32 END;

		op := ASM.opMOV;

	ELSE
		source := GetReg (instr.src2, piece2);

		dstSize := GetSize (source(PCA.Reg));

		CASE dstSize OF
		PCLIR.Int8 .. PCLIR.Int64:
			op := ASM.opMOV;
		| PCLIR.Float32:
			op := ASM.opMOVSS;
		| PCLIR.Float64:
			op := ASM.opMOVSD;
		END;
	END;

	IF instr.src1 <= PCLIR.HwReg THEN
		ASSERT (op = ASM.opMOV);
		assembly.Emit (op, dest, source, NIL);
	ELSE
		assembly.Emit (op, NewMem (dstSize, dest, instr.val), source, NIL);
	END;

	ReleaseSourceReg (instr.src1, piece1);
	ReleaseSourceReg (instr.src2, piece2);
END GenStore;

PROCEDURE GenOut (code: PCLIR.Code;  VAR instr: PCLIR.Instruction;  pc: SIGNED32);
VAR
	piece1, piece2: PCLIR.Piece;
	reg1, reg2, port, source: PCA.Reg;
BEGIN
	code.GetPiece (instr.src1, piece1);
	code.GetPiece (instr.src2, piece2);

	reg1 := GetReg (instr.src1, piece1);
	reg2 := GetReg (instr.src2, piece2);

	port := PCA.NewReg16 (rDX);
	source := NewReg (GetSize (reg2), rAX);

	IF GetSize (reg1) = PCLIR.Int8 THEN
		assembly.Emit (ASM.opMOVSX, port, reg1, NIL);
	ELSE
		assembly.Emit (ASM.opMOV, port, NewReg (PCLIR.Int16, reg1.index), NIL);
	END;

	assembly.Emit (ASM.opMOV, source, reg2, NIL);
	assembly.Emit (ASM.opOUT, port, source, NIL);

	ReleaseSourceReg (instr.src1, piece1);
	ReleaseSourceReg (instr.src2, piece2);
END GenOut;

PROCEDURE GenIn (code: PCLIR.Code;  VAR instr: PCLIR.Instruction;  pc: SIGNED32);
VAR
	piece1: PCLIR.Piece;
	reg1, port, dest: PCA.Reg;
BEGIN
	ASSERT (instr.dstSize IN PCLIR.IntSize);

	code.GetPiece (instr.src1, piece1);

	reg1 := GetReg (instr.src1, piece1);

	port := PCA.NewReg16 (rDX);
	dest := NewReg (instr.dstSize, rAX);

	AcquireReg (instr);

	IF GetSize (reg1) = PCLIR.Int8 THEN
		assembly.Emit (ASM.opMOVSX, port, reg1, NIL);
	ELSE
		assembly.Emit (ASM.opMOV, port, PCA.NewReg16 (reg1.index), NIL);
	END;

	assembly.Emit (ASM.opIN, dest, port, NIL);
	assembly.Emit (ASM.opMOV, instr.info(PCA.Reg), dest, NIL);

	ReleaseSourceReg (instr.src1, piece1);
END GenIn;

PROCEDURE GenNop (code: PCLIR.Code;  VAR instr: PCLIR.Instruction;  pc: SIGNED32);
BEGIN assembly.Emit (ASM.opNOP, NIL, NIL, NIL);
END GenNop;

PROCEDURE GenLabel(code: PCLIR.Code;  VAR instr: PCLIR.Instruction;  pc: SIGNED32);
BEGIN
	IF instr.val = 0 THEN
		instr.val := assembly.pc;
	ELSIF assembly.pc >= PCM.breakpc THEN
		PCM.Error(400, instr.val, ""); PCM.breakpc := MAX(SIGNED32)
	END;
	IF  instr.info # NIL THEN
		FixFixups (instr.info (Fixup));
	END;
END GenLabel;

PROCEDURE GenJcc(code: PCLIR.Code;  VAR instr: PCLIR.Instruction;  pc: SIGNED32);
VAR
	piece1, piece2: PCLIR.Piece;
	reg1: PCA.Reg; op2: PCA.Operand;
	cmpop, jmpop: SIGNED32;
BEGIN
	code.GetPiece (instr.src1, piece1);
	code.GetPiece (instr.src2, piece2);

	reg1 := GetReg (instr.src1, piece1);

	IF instr.src2 = PCLIR.none THEN
		op2 := PCA.NewImm (PCA.default, instr.val);
	ELSE
		op2 := GetReg (instr.src2, piece2);
	END;

	CASE instr.op OF
	PCLIR.je:
		cmpop := ASM.opCMP; jmpop := ASM.opJE;
	| PCLIR.jne:
		cmpop := ASM.opCMP; jmpop := ASM.opJNE;
	| PCLIR.jlt:
		cmpop := ASM.opCMP; IF IsFloat (GetSize (reg1)) THEN jmpop := ASM.opJB ELSE jmpop := ASM.opJL END;
	| PCLIR.jle:
		cmpop := ASM.opCMP; IF IsFloat (GetSize (reg1)) THEN jmpop := ASM.opJBE ELSE jmpop := ASM.opJLE END;
	| PCLIR.jgt:
		cmpop := ASM.opCMP; IF IsFloat (GetSize (reg1)) THEN jmpop := ASM.opJA ELSE jmpop := ASM.opJG END;
	| PCLIR.jge:
		cmpop := ASM.opCMP; IF IsFloat (GetSize (reg1)) THEN jmpop := ASM.opJAE ELSE jmpop := ASM.opJGE END;
	| PCLIR.jb:
		cmpop := ASM.opCMP; jmpop := ASM.opJB;
	| PCLIR.jbe:
		cmpop := ASM.opCMP; jmpop := ASM.opJBE;
	| PCLIR.ja:
		cmpop := ASM.opCMP; jmpop := ASM.opJA;
	| PCLIR.jae:
		cmpop := ASM.opCMP; jmpop := ASM.opJAE;
	| PCLIR.jf:
		cmpop := ASM.opBT; jmpop := ASM.opJC;
	| PCLIR.jnf:
		cmpop := ASM.opBT; jmpop := ASM.opJNC;
	END;

	CASE GetSize (reg1) OF
	PCLIR.Int8 .. PCLIR.Int64:
	| PCLIR.Float32:
		ASSERT (cmpop = ASM.opCMP);
		cmpop := ASM.opCOMISS;
	| PCLIR.Float64:
		ASSERT (cmpop = ASM.opCMP);
		cmpop := ASM.opCOMISD;
	END;

	assembly.Emit (cmpop, reg1, op2, NIL);
	EmitJmp (jmpop, code, instr);

	ReleaseSourceReg (instr.src1, piece1);
	ReleaseSourceReg (instr.src2, piece2);
END GenJcc;

PROCEDURE GenJmp (code: PCLIR.Code;  VAR instr: PCLIR.Instruction;  pc: SIGNED32);
BEGIN
	EmitJmp (ASM.opJMP, code, instr);
END GenJmp;

PROCEDURE GenCall(code: PCLIR.Code;  VAR instr: PCLIR.Instruction;  pc: SIGNED32);
VAR adr: PCBT.Procedure; imm: PCA.Imm; dest: PCA.Reg;
BEGIN
	adr := instr.adr(PCBT.Procedure);
	IF (adr.owner # PCBT.context) THEN
		imm := PCA.NewImm64 (0);
		dest := PCA.NewReg64 (rAX);
		assembly.Emit (ASM.opMOV, dest, imm, NIL);
		assembly.Emit (ASM.opCALL, dest, NIL, NIL);
		PCBT.context.UseProcedure (adr, imm.pc);
	ELSIF adr.codeoffset # 0 THEN
		assembly.Emit (ASM.opCALL, PCA.NewOffset32 (adr.codeoffset), NIL, NIL);
	ELSE
		imm := PCA.NewImm32 (adr.fixlist);
		assembly.Emit (ASM.opCALL, imm, NIL, NIL);
		adr.fixlist := imm.pc
	END
END GenCall;

PROCEDURE GenCallReg(code: PCLIR.Code;  VAR instr: PCLIR.Instruction;  pc: SIGNED32);
VAR piece1: PCLIR.Piece; reg1: PCA.Reg;
BEGIN
	code.GetPiece (instr.src1, piece1);
	reg1 := GetReg (instr.src1, piece1);

	assembly.Emit (ASM.opCALL, reg1, NIL, NIL);

	ReleaseSourceReg (instr.src1, piece1);
END GenCallReg;

PROCEDURE GenSysCall(code: PCLIR.Code;  VAR instr: PCLIR.Instruction;  pc: SIGNED32);
VAR imm: PCA.Imm; dest: PCA.Reg;
BEGIN
	imm := PCA.NewImm64 (0);
	dest := PCA.NewReg64 (rAX);
	assembly.Emit (ASM.opMOV, dest, imm, NIL);
	assembly.Emit (ASM.opCALL, dest, NIL, NIL);
	PCBT.context.UseSyscall (instr.val, imm.pc);
END GenSysCall;

PROCEDURE GenSetcc(code: PCLIR.Code;  VAR instr: PCLIR.Instruction;  pc: SIGNED32);
VAR
	piece1, piece2: PCLIR.Piece;
	reg1: PCA.Reg; op2: PCA.Operand;
	cmpop, setop: SIGNED32;
BEGIN
	AcquireReg (instr);

	code.GetPiece (instr.src1, piece1);
	code.GetPiece (instr.src2, piece2);

	reg1 := GetReg (instr.src1, piece1);

	IF instr.src2 = PCLIR.none THEN
		op2 := PCA.NewImm (PCA.default, instr.val);
	ELSE
		op2 := GetReg (instr.src2, piece2);
	END;

	CASE instr.op OF
	PCLIR.sete:
		cmpop := ASM.opCMP; setop := ASM.opSETE;
	| PCLIR.setne:
		cmpop := ASM.opCMP; setop := ASM.opSETNE;
	| PCLIR.setlt:
		cmpop := ASM.opCMP; IF IsFloat (GetSize (reg1)) THEN setop := ASM.opSETB ELSE setop := ASM.opSETL END;
	| PCLIR.setle:
		cmpop := ASM.opCMP; IF IsFloat (GetSize (reg1)) THEN setop := ASM.opSETBE ELSE setop := ASM.opSETLE END;
	| PCLIR.setgt:
		cmpop := ASM.opCMP; IF IsFloat (GetSize (reg1)) THEN setop := ASM.opSETA ELSE setop := ASM.opSETG END;
	| PCLIR.setge:
		cmpop := ASM.opCMP; IF IsFloat (GetSize (reg1)) THEN setop := ASM.opSETAE ELSE setop := ASM.opSETGE END;
	| PCLIR.setb:
		cmpop := ASM.opCMP; setop := ASM.opSETB;
	| PCLIR.setbe:
		cmpop := ASM.opCMP; setop := ASM.opSETBE;
	| PCLIR.seta:
		cmpop := ASM.opCMP; setop := ASM.opSETA;
	| PCLIR.setae:
		cmpop := ASM.opCMP; setop := ASM.opSETAE;
	| PCLIR.setf:
		cmpop := ASM.opBT; setop := ASM.opSETC;
	| PCLIR.setnf:
		cmpop := ASM.opBT; setop := ASM.opSETNC;
	END;

	CASE GetSize (reg1) OF
	PCLIR.Int8 .. PCLIR.Int64:
	| PCLIR.Float32:
		ASSERT (cmpop = ASM.opCMP);
		cmpop := ASM.opCOMISS;
	| PCLIR.Float64:
		ASSERT (cmpop = ASM.opCMP);
		cmpop := ASM.opCOMISD;
	END;

	assembly.Emit (cmpop, reg1, op2, NIL);

	IF instr.dstSize # PCLIR.Int8 THEN
		assembly.Emit (ASM.opXOR, instr.info(PCA.Reg), instr.info(PCA.Reg), NIL);
	END;

	assembly.Emit (setop, instr.info(PCA.Reg), NIL, NIL);

	ReleaseSourceReg (instr.src1, piece1);
	ReleaseSourceReg (instr.src2, piece2);
END GenSetcc;

PROCEDURE GenKill(code: PCLIR.Code;  VAR instr: PCLIR.Instruction;  pc: SIGNED32);
VAR piece1: PCLIR.Piece; reg1: PCA.Reg;
BEGIN
	code.GetPiece (instr.src1, piece1);
	ReleaseSourceReg (instr.src1, piece1);
END GenKill;

PROCEDURE GenPhi(code: PCLIR.Code;  VAR instr: PCLIR.Instruction;  pc: SIGNED32);
VAR
	piece1, piece2: PCLIR.Piece;
	reg1, reg2: PCA.Reg;
BEGIN
	ASSERT (instr.dstSize IN PCLIR.IntSize);
	ASSERT (instr.info = NIL);

	IF instr.src1 > instr.src2 THEN PCLIR.SwapSources (instr) END;

	code.GetPiece (instr.src1, piece1);
	code.GetPiece (instr.src2, piece2);

	(* The first source register must be acquired
	before this phi instruction *)

	ASSERT (piece1.instr[instr.src1].info # NIL);
	reg1 := GetReg (instr.src1, piece1);

	(* the second source register might not be acquired now *)

	IF piece2.instr[instr.src2].info = NIL THEN
		reg2 := reg1;
		piece2.instr[instr.src2].info := reg2;
	ELSE
		reg2 := GetReg (instr.src2, piece2);
	END;

	(* only the same register is mergeable *)
	ASSERT (reg1.index = reg2.index);
	ASSERT (GetSize (reg1) = GetSize (reg2));

	instr.info := reg1;
	AllocReg (instr.dstSize, reg1.index);
END GenPhi;

PROCEDURE GenConv (code: PCLIR.Code;  VAR instr: PCLIR.Instruction;  pc: SIGNED32);
VAR
	piece1: PCLIR.Piece;
	reg1, tmp: PCA.Reg;
	srcSize: PCLIR.Size;
	op: SIGNED32;
BEGIN
	ASSERT (instr.info = NIL);

	code.GetPiece (instr.src1, piece1);

	reg1 := GetReg (instr.src1, piece1);

	srcSize := GetSize (reg1);

	IF instr.dstSize = srcSize THEN

		AcquireSourceReg (instr, instr.src1, piece1);

	ELSIF instr.dstSize IN PCLIR.FloatSize THEN

		AcquireReg (instr);

		CASE srcSize OF
		| PCLIR.Int8, PCLIR.Int16:
			IF instr.dstSize = PCLIR.Float32 THEN
				tmp := PCA.NewReg32 (rAX);
				op := ASM.opCVTSI2SS;
			ELSE
				op := ASM.opCVTSI2SD;
				tmp := PCA.NewReg64 (rAX);
			END;
			assembly.Emit (ASM.opMOVSX, tmp, reg1, NIL);
			reg1 := tmp;
		| PCLIR.Int32, PCLIR.Int64:
			IF instr.dstSize = PCLIR.Float32 THEN
				op := ASM.opCVTSI2SS;
			ELSE
				op := ASM.opCVTSI2SD;
			END;
		| PCLIR.Float32:
			op := ASM.opCVTSS2SD;
		| PCLIR.Float64:
			op := ASM.opCVTSD2SS;
		END;

		assembly.Emit (op, instr.info(PCA.Reg), reg1, NIL);

		ReleaseSourceReg (instr.src1, piece1);

	ELSE

		CASE srcSize OF
		PCLIR.Int8 .. PCLIR.Int64:

			IF instr.dstSize < srcSize THEN
				AcquireSourceReg (instr, instr.src1, piece1);
			ELSIF instr.op = PCLIR.convs THEN
				AcquireReg (instr);

				IF (instr.dstSize = PCLIR.Int64) & (srcSize = PCLIR.Int32) THEN
					assembly.Emit (ASM.opMOVSXD, instr.info(PCA.Reg), reg1, NIL);
				ELSE
					assembly.Emit (ASM.opMOVSX, instr.info(PCA.Reg), reg1, NIL);
				END;
				ReleaseSourceReg (instr.src1, piece1);
			ELSE
				IF (instr.dstSize = PCLIR.Int64) & (srcSize = PCLIR.Int32) THEN
					AcquireSourceReg (instr, instr.src1, piece1);
				ELSE
					AcquireReg (instr);
					assembly.Emit (ASM.opMOVZX, instr.info(PCA.Reg), reg1, NIL);
					ReleaseSourceReg (instr.src1, piece1);
				END;
			END;

		| PCLIR.Float32:
			AcquireReg (instr);
			assembly.Emit (ASM.opCVTSS2SI, instr.info(PCA.Reg), reg1, NIL);
			ReleaseSourceReg (instr.src1, piece1);

		| PCLIR.Float64:
			AcquireReg (instr);
			assembly.Emit (ASM.opCVTSD2SI, instr.info(PCA.Reg), reg1, NIL);
			ReleaseSourceReg (instr.src1, piece1);
		END;
	END;
END GenConv;

PROCEDURE GenNegNot (code: PCLIR.Code;  VAR instr: PCLIR.Instruction;  pc: SIGNED32);
BEGIN
	CASE instr.dstSize OF
	PCLIR.Int8 .. PCLIR.Int64:
		IF (instr.op = PCLIR.neg) OR (instr.dstSigned) THEN
			EmitType1 (ASM.opNEG, code, instr, NIL);
		ELSE
			EmitType1 (ASM.opNOT, code, instr, NIL);
		END;
	| PCLIR.Float32:
		EmitSSEBitOp (code, instr, ASM.opXORPS, 31, FALSE);
	| PCLIR.Float64:
		EmitSSEBitOp (code, instr, ASM.opXORPD, 63, FALSE);
	END;
END GenNegNot;

PROCEDURE GenAbs(code: PCLIR.Code;  VAR instr: PCLIR.Instruction;  pc: SIGNED32);
VAR
	piece1: PCLIR.Piece;
	reg1, dest, source: PCA.Reg;
	imm: PCA.Imm;
BEGIN
	ASSERT (instr.dstSigned);

	CASE instr.dstSize OF
	PCLIR.Int8 .. PCLIR.Int64:
		code.GetPiece (instr.src1, piece1);

		reg1 := GetReg (instr.src1, piece1);

		AcquireReg (instr);
		dest := instr.info(PCA.Reg);

		source := NewReg (instr.dstSize, rAX);
		assembly.Emit (ASM.opMOV, source, reg1, NIL);

		CASE instr.dstSize OF
		| PCLIR.Int8: imm := PCA.NewImm8 (7);
		| PCLIR.Int16: imm := PCA.NewImm8 (15);
		| PCLIR.Int32: imm := PCA.NewImm8 (31);
		| PCLIR.Int64: imm := PCA.NewImm8 (63);
		END;

		assembly.Emit (ASM.opMOV, dest, source, NIL);
		assembly.Emit (ASM.opSAR, source, imm, NIL);
		assembly.Emit (ASM.opXOR, dest, source, NIL);
		assembly.Emit (ASM.opSUB, dest, source, NIL);

		ReleaseSourceReg (instr.src1, piece1);

	| PCLIR.Float32:
		EmitSSEBitOp (code, instr, ASM.opANDPS, 31, TRUE);
	| PCLIR.Float64:
		EmitSSEBitOp (code, instr, ASM.opANDPD, 63, TRUE);
	END;
END GenAbs;

PROCEDURE GenBts (code: PCLIR.Code;  VAR instr: PCLIR.Instruction;  pc: SIGNED32);
BEGIN
	ASSERT (instr.dstSize IN PCLIR.IntSize);
	EmitType2 (ASM.opBTS, code, instr);
END GenBts;

PROCEDURE GenBtc (code: PCLIR.Code;  VAR instr: PCLIR.Instruction;  pc: SIGNED32);
BEGIN
	ASSERT (instr.dstSize IN PCLIR.IntSize);
	EmitType2 (ASM.opBTR, code, instr);
END GenBtc;

PROCEDURE GenMul(code: PCLIR.Code;  VAR instr: PCLIR.Instruction;  pc: SIGNED32);
BEGIN
(*	ASSERT (instr.dstSigned); *)
	CASE instr.dstSize OF
	PCLIR.Int8 .. PCLIR.Int64:
		EmitType2 (ASM.opIMUL, code, instr);
	| PCLIR.Float32:
		EmitType2 (ASM.opMULSS, code, instr);
	| PCLIR.Float64:
		EmitType2 (ASM.opMULSD, code, instr);
	END;
END GenMul;

PROCEDURE GenDivMod(code: PCLIR.Code;  VAR instr: PCLIR.Instruction;  pc: SIGNED32);
VAR
	piece1, piece2: PCLIR.Piece;
	reg1, reg2, dividend, quotient, remainder: PCA.Reg;
	offset: PCA.Imm; prevPC: SIGNED32;
BEGIN
(*	ASSERT (instr.dstSigned); *)

	CASE instr.dstSize OF
	PCLIR.Int8 .. PCLIR.Int64:

		code.GetPiece (instr.src1, piece1);
		code.GetPiece (instr.src2, piece2);

		reg1 := GetReg (instr.src1, piece1);
		reg2 := GetReg (instr.src2, piece2);

		IF instr.dstSize = PCLIR.Int8 THEN
			dividend := PCA.NewReg16 (rAX);
			quotient := PCA.NewReg8 (rAX);
			remainder := quotient; (* eventually AH *)
		ELSE
			dividend := NewReg (instr.dstSize, rAX);
			quotient := dividend;
			remainder := NewReg (instr.dstSize, rDX);
		END;

		assembly.Emit (ASM.opMOV, quotient, reg1, NIL);

		(* sign extend dividend (rDX or AX register) *)
		CASE instr.dstSize OF
		PCLIR.Int8:
			assembly.Emit (ASM.opCBW, NIL, NIL, NIL);
		| PCLIR.Int16:
			assembly.Emit (ASM.opCWD, NIL, NIL, NIL);
		| PCLIR.Int32:
			assembly.Emit (ASM.opCDQ, NIL, NIL, NIL);
		| PCLIR.Int64:
			assembly.Emit (ASM.opCQO, NIL, NIL, NIL);
		END;

		assembly.Emit (ASM.opIDIV, reg2, NIL, NIL);

		IF instr.dstSize = PCLIR.Int8 THEN
			assembly.Emit (ASM.opSAR, dividend, PCA.NewImm8 (8), NIL);
		END;

		AcquireSourceReg (instr, instr.src1, piece1);

		IF instr.op = PCLIR.mod THEN
			assembly.Emit (ASM.opCMP, remainder, PCA.NewImm8 (0), NIL);
			offset := PCA.NewImm8 (0);
			assembly.Emit (ASM.opJGE, offset, NIL, NIL);
			assembly.Emit (ASM.opADD, remainder, reg2, NIL);
			prevPC := assembly.pc;
			assembly.SetPC (offset.pc);
			assembly.PutByte (prevPC - offset.pc - 1);
			assembly.SetPC (prevPC);
			assembly.Emit (ASM.opMOV, instr.info(PCA.Reg), remainder, NIL);
		ELSE
			assembly.Emit (ASM.opSHL, remainder, PCA.NewImm8 (1), NIL);
			assembly.Emit (ASM.opSBB, quotient, PCA.NewImm8 (0), NIL);
			assembly.Emit (ASM.opMOV, instr.info(PCA.Reg), quotient, NIL);
		END;

		ReleaseSourceReg (instr.src2, piece2);

	| PCLIR.Float32:
		EmitType2 (ASM.opDIVSS, code, instr);
	| PCLIR.Float64:
		EmitType2 (ASM.opDIVSD, code, instr);
	END;
END GenDivMod;

PROCEDURE GenAdd (code: PCLIR.Code;  VAR instr: PCLIR.Instruction;  pc: SIGNED32);
BEGIN
	CASE instr.dstSize OF
	PCLIR.Int8 .. PCLIR.Int64:
		IF (instr.src2 = PCLIR.none) & (instr.val = 0) THEN
			EmitType1 (ASM.opNOP, code, instr, NIL);
		ELSE
			EmitType2 (ASM.opADD, code, instr);
		END;
	| PCLIR.Float32:
		EmitType2 (ASM.opADDSS, code, instr);
	| PCLIR.Float64:
		EmitType2 (ASM.opADDSD, code, instr);
	END;
END GenAdd;

PROCEDURE GenSub (code: PCLIR.Code;  VAR instr: PCLIR.Instruction;  pc: SIGNED32);
BEGIN
	CASE instr.dstSize OF
	PCLIR.Int8 .. PCLIR.Int64:
		IF (instr.src2 = PCLIR.none) & (instr.val = 0) THEN
			EmitType1 (ASM.opNOP, code, instr, NIL);
		ELSE
			EmitType2 (ASM.opSUB, code, instr);
		END;
	| PCLIR.Float32:
		EmitType2 (ASM.opSUBSS, code, instr);
	| PCLIR.Float64:
		EmitType2 (ASM.opSUBSD, code, instr);
	END;
END GenSub;

PROCEDURE GenAnd (code: PCLIR.Code;  VAR instr: PCLIR.Instruction;  pc: SIGNED32);
BEGIN
	ASSERT (instr.dstSize IN PCLIR.IntSize);
	EmitType2 (ASM.opAND, code, instr);
END GenAnd;

PROCEDURE GenOr (code: PCLIR.Code;  VAR instr: PCLIR.Instruction;  pc: SIGNED32);
BEGIN
	ASSERT (instr.dstSize IN PCLIR.IntSize);
	EmitType2 (ASM.opOR, code, instr);
END GenOr;

PROCEDURE GenXor (code: PCLIR.Code;  VAR instr: PCLIR.Instruction;  pc: SIGNED32);
BEGIN
	ASSERT (instr.dstSize IN PCLIR.IntSize);
	EmitType2 (ASM.opXOR, code, instr);
END GenXor;

PROCEDURE GenShift(code: PCLIR.Code;  VAR instr: PCLIR.Instruction;  pc: SIGNED32);
VAR
	piece1, piece2: PCLIR.Piece;
	reg2, shift, CL: PCA.Reg;
	op: SIGNED32;

	prevPC: SIGNED32;
	thenOffset, elseOffset: PCA.Imm;

BEGIN
	ASSERT (instr.dstSize IN PCLIR.IntSize);

	IF instr.src2 = PCLIR.none THEN
		CASE instr.op OF
		PCLIR.bsh:
			IF instr.val < 0 THEN op := ASM.opSHR ELSE op := ASM.opSHL END
		| PCLIR.ash:
			IF instr.val < 0 THEN op := ASM.opSAR ELSE op := ASM.opSAL END
		| PCLIR.rot:
			IF instr.val < 0 THEN op := ASM.opROR ELSE op := ASM.opROL END
		END;

		EmitType1 (op, code, instr, PCA.NewImm8 (ABS (instr.val)));

	ELSE

		code.GetPiece (instr.src1, piece1);
		code.GetPiece (instr.src2, piece2);

		AcquireSourceReg (instr, instr.src1, piece1);

		reg2 := GetReg (instr.src2, piece2);
		shift := PCA.NewReg8 (rCX);

		assembly.Emit (ASM.opMOV, shift, PCA.NewReg8 (reg2.index), NIL);

		assembly.Emit (ASM.opCMP, shift, PCA.NewImm (PCA.default, 0), NIL);

		thenOffset := PCA.NewImm8 (0);
		assembly.Emit (ASM.opJL, thenOffset, NIL, NIL);

		CASE instr.op OF
		PCLIR.bsh: op := ASM.opSHL;
		| PCLIR.ash: op := ASM.opSAL;
		| PCLIR.rot: op := ASM.opROL;
		END;

		assembly.Emit (op, instr.info(PCA.Reg), shift, NIL);

		elseOffset := PCA.NewImm8 (0);
		assembly.Emit (ASM.opJMP, elseOffset, NIL, NIL);

		prevPC := assembly.pc;
		assembly.SetPC (thenOffset.pc); assembly.PutByte (prevPC - thenOffset.pc - 1);
		assembly.SetPC (prevPC);

		assembly.Emit (ASM.opNEG, shift, NIL, NIL);

		CASE instr.op OF
		PCLIR.bsh: op := ASM.opSHR;
		| PCLIR.ash: op := ASM.opSAR;
		| PCLIR.rot: op := ASM.opROR;
		END;

		assembly.Emit (op, instr.info(PCA.Reg), shift, NIL);

		prevPC := assembly.pc;
		assembly.SetPC (elseOffset.pc); assembly.PutByte (prevPC - elseOffset.pc - 1);
		assembly.SetPC (prevPC);

		ReleaseSourceReg (instr.src2, piece2);
	END;

END GenShift;

PROCEDURE GenMoveDown(code: PCLIR.Code;  VAR instr: PCLIR.Instruction;  pc: SIGNED32);
BEGIN EmitMove (code, instr, ASM.opSTD);
END GenMoveDown;

PROCEDURE GenMove(code: PCLIR.Code;  VAR instr: PCLIR.Instruction;  pc: SIGNED32);
BEGIN EmitMove (code, instr, ASM.opCLD);
END GenMove;

PROCEDURE GenInline(code: PCLIR.Code;  VAR instr: PCLIR.Instruction;  pc: SIGNED32);
VAR
	inline: PCLIR.AsmInline;
	block: PCLIR.AsmBlock;
	fixup: PCLIR.AsmFixup;
	i: SIGNED32;
BEGIN
	inline := instr.adr(PCLIR.AsmInline);

	fixup := inline.fixup;
	WHILE fixup # NIL DO
		FixAbsolute (fixup.adr, assembly.pc + fixup.offset);
		fixup := fixup.next;
	END;

	block := inline.code;
	WHILE block # NIL DO
		FOR i := 0 TO block.len - 1 DO assembly.PutByte(ORD(block.code[i])) END;
		block := block.next
	END;
END GenInline;

PROCEDURE GenCase(code: PCLIR.Code;  VAR instr: PCLIR.Instruction;  pc: SIGNED32);
VAR
	piece1: PCLIR.Piece;
	case: Case;
BEGIN
	code.GetPiece (instr.src1, piece1);

	case := instr.info(Case);
	case.reg := GetReg (instr.src1, piece1);
	case.curCasePC := -2;

	ReleaseSourceReg (instr.src1, piece1);
END GenCase;

PROCEDURE GenCaseLine(code: PCLIR.Code;  VAR instr: PCLIR.Instruction;  pc: SIGNED32);
VAR
	piece1, piece2: PCLIR.Piece;
	case: Case; caseLine: CaseLine;

BEGIN
	code.GetPiece (instr.src1, piece1);
	case := piece1.instr[instr.src1].info(Case);

	FixFixups (case.prevCase);

	IF instr.op = PCLIR.casel THEN
		caseLine := instr.info(CaseLine);
		IF caseLine.last THEN
			IF caseLine.from = caseLine.to THEN
				EmitCmpJmp (case.reg, caseLine.from, ASM.opJNE, case.prevCase);
			ELSE
				EmitCmpJmp (case.reg, caseLine.from, ASM.opJL, case.prevCase);
				EmitCmpJmp (case.reg, caseLine.to, ASM.opJG, case.prevCase);
			END;
			FixFixups (case.nextCase);
		ELSIF caseLine.from = caseLine.to THEN
			EmitCmpJmp (case.reg, instr.val, ASM.opJE, case.nextCase);
		ELSE
			EmitCmpJmp (case.reg, caseLine.from, ASM.opJL, case.prevCase);
			EmitCmpJmp (case.reg, caseLine.to, ASM.opJLE, case.nextCase);
		END;
		case.curCasePC := pc;
	END;

(*

	IF instr.op = PCLIR.casel THEN

		IF instr.src2 = pc THEN
			assembly.Emit (ASM.opCMP, case.reg, PCA.NewImm (PCA.default, instr.val), NIL);
			assembly.Emit (ASM.opJNE, PCA.NewImm32 (0), NIL, NIL);
			NEW (case.fixup); case.fixup.pc := assembly.pc;
		ELSE
			code.GetPiece (instr.src2, piece2);

			assembly.Emit (ASM.opCMP, case.reg, PCA.NewImm (PCA.default, instr.val), NIL);
			assembly.Emit (ASM.opJL, PCA.NewImm32 (0), NIL, NIL);
			NEW (case.fixup); case.fixup.pc := assembly.pc;

			assembly.Emit (ASM.opCMP, case.reg, PCA.NewImm (PCA.default, piece2.instr[instr.src2].val), NIL);
			assembly.Emit (ASM.opJG, PCA.NewImm32 (0), NIL, NIL);
			NEW (case.fixup.next);
			case.fixup.next.pc := assembly.pc;
		END;
	END;
	case.prevCasePC := pc;
*)
END GenCaseLine;

(* Debug Procedures *)
PROCEDURE DumpCode (code: PCLIR.Code;  VAR instr: PCLIR.Instruction;  pc: SIGNED32;  context: ANY);
END DumpCode;

PROCEDURE Optimize (code: PCLIR.Code;  VAR instr: PCLIR.Instruction;  pc: SIGNED32;  context: ANY);
VAR
	piece1, piece2: PCLIR.Piece;
	src1, src2: PCLIR.Register;
	case: Case; caseLine: CaseLine;

	PROCEDURE UseResult (VAR instr: PCLIR.Instruction);
	BEGIN
		DEC (instr.dstCount);
		IF instr.dstCount = 0 THEN
			instr.suppress := TRUE;
		END;
	END UseResult;

	PROCEDURE SetConstant (VAR reg: PCLIR.Register);
	VAR
		src: PCLIR.Register;
		piece: PCLIR.Piece;
	BEGIN
		src := reg;

		IF src >= 0 THEN
			code.GetPiece (src, piece);

			IF (piece.instr[src].op = PCLIR.loadc) & (piece.instr[src].dstSize IN PCLIR.IntSize) & (piece.instr[src].adr = NIL) THEN
				instr.val := piece.instr[src].val;
				UseResult (piece.instr[src]);
				reg := PCLIR.none;
			END;
		END;
	END SetConstant;

	PROCEDURE SetResult (VAR reg: PCLIR.Register);
	VAR
		src: PCLIR.Register;
		piece: PCLIR.Piece;
	BEGIN
		src := reg;

		IF src >= 0 THEN
			code.GetPiece (src, piece);

			IF (piece.instr[src].dstSize IN PCLIR.IntSize) & (piece.instr[src].dstCount = 1) THEN
				IF piece.instr[src].op = PCLIR.result THEN
					piece.instr[src].info := NewReg (piece.instr[src].dstSize, rAX);
					UseResult (piece.instr[src]);
				ELSIF piece.instr[src].op = PCLIR.result2 THEN
					piece.instr[src].info := NewReg (piece.instr[src].dstSize, rDX);
					UseResult (piece.instr[src]);
				END;
			END;
		END;
	END SetResult;

BEGIN

	src1 := instr.src1;
	src2 := instr.src2;

	IF (src1 >= 0) & (src1 < code.pc) THEN code.GetPiece (src1, piece1) ELSE piece1 := NIL END;
	IF (src2 >= 0) & (src2 < code.pc) THEN code.GetPiece (src2, piece2) ELSE piece2 := NIL END;

	CASE instr.op OF
	PCLIR.ash, PCLIR.bsh, PCLIR.rot:
		SetConstant (instr.src2);
	| PCLIR.add, PCLIR.sub, PCLIR.and, PCLIR.or, PCLIR.xor:
		SetConstant (instr.src2);
	| PCLIR.sete .. PCLIR.setnf:
		SetConstant (instr.src2);
	| PCLIR.store:
		IF (src1 >= 0) & (piece1.instr[src1].op = PCLIR.add) THEN
			IF (piece1.instr[src1].dstCount = 1) & (piece1.instr[src1].src2 = PCLIR.none) THEN
				INC (instr.val, piece1.instr[src1].val);
				instr.src1 := piece1.instr[src1].src1;
				UseResult (piece1.instr[src1]);
			END;
		END;
		IF (src2 >= 0) & (piece2.instr[src2].op = PCLIR.loadc) THEN
			IF (piece2.instr[src2].dstCount = 1) & (piece2.instr[src2].dstSize IN LegacyIntegers) & (piece2.instr[src2].adr = NIL) THEN
				UseResult (piece2.instr[src2]);
			END;
		END;
(*		SetResult (instr.src2); *)
	| PCLIR.loadc:
		(* workaround for paco generating code that assigns too large values to bytes *)
		IF instr.dstSize = PCLIR.Int8 THEN
			instr.val := SIGNED8(instr.val);
		END;
	| PCLIR.ret:
		IF src1 >= 0 THEN
			CASE piece1.instr[src1].op OF
			PCLIR.loadc:
				piece1.instr[src1].info := NewReg (piece1.instr[src1].dstSize, rAX);
				instr.suppress := TRUE;
			| PCLIR.sete .. PCLIR.setnf:
				piece1.instr[src1].info := PCA.NewReg8 (rAX);
				instr.suppress := TRUE;
			ELSE
			END
		END
	| PCLIR.case:

		NEW (case);
		instr.info := case;
		case.curCasePC := -2;

	| PCLIR.casel:

		case := piece1.instr[src1].info(Case);

		IF pc = case.curCasePC + 1 THEN
			src2 := case.curCasePC;
			code.GetPiece (src2, piece2);
			piece2.instr[src2].info(CaseLine).last := FALSE;

			IF instr.val = case.curCaseLine.to + 1 THEN
				caseLine := case.curCaseLine;
				instr.suppress := TRUE;
			ELSE
				NEW (caseLine);
				caseLine.first := FALSE;
				caseLine.from := instr.val;
				case.curCaseLine := caseLine;
			END;
		ELSE
			NEW (caseLine);
			caseLine.first := TRUE;
			caseLine.from := instr.val;
			case.curCaseLine := caseLine;
		END;

		instr.info := caseLine;
		caseLine.to := instr.val;
		case.curCasePC := pc;
		caseLine.last := TRUE;

(*

		(* if the case value is one ahead the previous case ignore this instruction and adapt the first case instruction *)
		IF (case.firstCasePC # -1) & (pc = case.prevCasePC + 1) & (instr.val = case.prevCaseValue + 1) THEN
			src2 := case.firstCasePC;
			code.GetPiece (src2, piece2);
			piece2.instr[src2].src2 := pc;
			instr.suppress := TRUE;
		ELSE
			(* src2 stores the pc of the last case line defining the range down to this instruction *)
			instr.src2 := pc;
			case.firstCasePC := pc;
		END;
		case.prevCasePC := pc;
		case.prevCaseValue := instr.val;
*)
	ELSE
	END;

END Optimize;

PROCEDURE DoOptimize (code: PCLIR.Code);
BEGIN code.Traverse (Optimize, FALSE, NIL);
END DoOptimize;

(* Init - Initialize code generator - Installed in PCBT.CG *)
PROCEDURE Init (): BOOLEAN;
BEGIN
	NEW (assembly, PCM.diagnostics, NIL);

	currentRegisters.gpp := {};
	currentRegisters.xmm := {};
	saveLevel := 0;

	RETURN TRUE
END Init;

(* Done - Code generator results - Installed in PCBT.CG *)
PROCEDURE Done (VAR result: INTEGER);
BEGIN result := 0;
END Done;

PROCEDURE GetCode (VAR codeArr: PCLIR.CodeArray; VAR length, hdrlength, addressFactor: SIGNED32);
VAR i: SIGNED32;
BEGIN
	length := assembly.pc;
	hdrlength := length;
	addressFactor := 1;
	assembly.SetPC (0);
	NEW (codeArr, length);
	FOR i := 0 TO length - 1 DO
		codeArr[i] := assembly.GetByte ();
	END;

(*	SendFile.SendData ("code.bin", codeArr^, length);    *)

END GetCode;

(* Module Initialization and Configuration *)
PROCEDURE Install*;
VAR  i: PCLIR.Opcode;
BEGIN
	PCLIR.CG.Init := Init;
	PCLIR.CG.Done := Done;
	PCLIR.CG.GetCode := GetCode;
	PCLIR.CG.DumpCode := DumpCode;
	PCLIR.CG.Optimize := DoOptimize;
	PCLIR.CG.MaxCodeSize := 40000H; (* should depend also on object filegenerator *)

	IF AlignParameters THEN
		PCLIR.CG.ParamAlign := 8;
	ELSE
		PCLIR.CG.ParamAlign := 2;
	END;

	PCBT.SetNumberOfSyscalls(PCBT.DefaultNofSysCalls);
	NEW(PCLIR.CG.SysCallMap, PCBT.NofSysCalls);
	PCLIR.InitDefaultSyscalls;

	PCLIR.Address := PCLIR.Int64;
	PCLIR.Set := PCLIR.Int64;
	PCLIR.SizeType := PCLIR.Int64;

	PCLIR.InstructionInit := InstructionInit;
	PCLIR.SetMethods(PCLIR.enter, GenEnter);
	PCLIR.SetMethods(PCLIR.exit, GenExit);
	PCLIR.SetMethods(PCLIR.trap, GenTrap);
	FOR i := PCLIR.tae TO PCLIR.tne DO
		PCLIR.SetMethods(i, GenTrapcc)
	END;
	PCLIR.SetMethods(PCLIR.saveregs, GenSaveRegisters);
	PCLIR.SetMethods(PCLIR.loadregs, GenRestoreRegisters);
	PCLIR.SetMethods(PCLIR.ret, GenReturn);
	PCLIR.SetMethods(PCLIR.ret2, GenReturn2);
	PCLIR.SetMethods(PCLIR.result, GenResult);
	PCLIR.SetMethods(PCLIR.result2, GenResult2);
	PCLIR.SetMethods(PCLIR.pop, GenPop);
	PCLIR.SetMethods(PCLIR.load, GenLoad);
	PCLIR.SetMethods(PCLIR.loadc, GenLoadC);
	PCLIR.SetMethods(PCLIR.store, GenStore);
	PCLIR.SetMethods(PCLIR.in, GenIn);
	PCLIR.SetMethods(PCLIR.out, GenOut);
	PCLIR.SetMethods(PCLIR.nop, GenNop);
	PCLIR.SetMethods(PCLIR.label, GenLabel);
	PCLIR.SetMethods(PCLIR.finallylabel, GenLabel);
	FOR i := PCLIR.je TO PCLIR.jnf DO
		PCLIR.SetMethods(i, GenJcc)
	END;
	PCLIR.SetMethods(PCLIR.jmp, GenJmp);
	PCLIR.SetMethods(PCLIR.call, GenCall);
	PCLIR.SetMethods(PCLIR.callreg, GenCallReg);
	PCLIR.SetMethods(PCLIR.syscall, GenSysCall);
	FOR i := PCLIR.sete TO PCLIR.setnf DO
		PCLIR.SetMethods(i, GenSetcc)
	END;
	PCLIR.SetMethods(PCLIR.kill, GenKill);
	PCLIR.SetMethods(PCLIR.phi, GenPhi);
	PCLIR.SetMethods(PCLIR.push, GenPush);
	PCLIR.SetMethods(PCLIR.loadsp, GenLoadSP);
	PCLIR.SetMethods(PCLIR.loadfp, GenLoadFP);

	PCLIR.SetMethods(PCLIR.convs, GenConv);
	PCLIR.SetMethods(PCLIR.convu, GenConv);
	PCLIR.SetMethods(PCLIR.copy, GenConv);

	PCLIR.SetMethods(PCLIR.not, GenNegNot);
	PCLIR.SetMethods(PCLIR.neg, GenNegNot);
	PCLIR.SetMethods(PCLIR.abs, GenAbs);
	PCLIR.SetMethods(PCLIR.bts, GenBts);
	PCLIR.SetMethods(PCLIR.btc, GenBtc);
	PCLIR.SetMethods(PCLIR.mul, GenMul);
	PCLIR.SetMethods(PCLIR.div, GenDivMod);
	PCLIR.SetMethods(PCLIR.mod, GenDivMod);
	PCLIR.SetMethods(PCLIR.sub, GenSub);
	PCLIR.SetMethods(PCLIR.add, GenAdd);
	PCLIR.SetMethods(PCLIR.and, GenAnd);
	PCLIR.SetMethods(PCLIR.or, GenOr);
	PCLIR.SetMethods(PCLIR.xor, GenXor);

	PCLIR.SetMethods(PCLIR.ash, GenShift);
	PCLIR.SetMethods(PCLIR.bsh, GenShift);
	PCLIR.SetMethods(PCLIR.rot, GenShift);
	PCLIR.SetMethods(PCLIR.move, GenMove);
	PCLIR.SetMethods(PCLIR.moveDown, GenMoveDown);
	PCLIR.SetMethods(PCLIR.inline, GenInline);
	PCLIR.SetMethods(PCLIR.case, GenCase);
	PCLIR.SetMethods(PCLIR.casel, GenCaseLine);
	PCLIR.SetMethods(PCLIR.casee, GenCaseLine);

	PCM.log.String ("AMD64 code generator installed"); PCM.log.Ln;
END Install;

END PCGAMD64.
