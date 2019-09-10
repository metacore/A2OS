MODULE PCARMRegisters;	(** be  **)

IMPORT PCM, PCOARM, KernelLog;

CONST
	INTERNALERROR = 100;

	CheckRegisterSize = TRUE;	(* temporary *)
	TraceDetail = FALSE; 	(* careful ! generates A LOT of output ! *)

	Constants* = 0;		  (* constants reused *)
	MemoryStack* = 1;		(* memory access with base register FP reused *)
	MemoryAbsolute* =2; (* memory access with PC-relative addressing *)
	MemoryAll* = 3;		(* all memory access reused. WARNING: may produce false results when used together with memory mapped I/O !!! *)

	FP = PCOARM.FP;
	SP = PCOARM.SP;
	PC = PCOARM.PC;

TYPE
	Content* = OBJECT
		VAR
			next: Content;

		PROCEDURE Equals(c: Content): BOOLEAN;
		BEGIN RETURN FALSE
		END Equals;
	END Content;

	MemoryContent* = OBJECT(Content)
		VAR
			baseReg-,offset-, size-: SIGNED32;

		PROCEDURE &Init*(baseReg, offset, size: SIGNED32);
		BEGIN SELF.baseReg := baseReg; SELF.offset := offset; SELF.size := size
		END Init;

		(* returns TRUE iff two MemoryContents are equal *)
		PROCEDURE Equals(c: Content): BOOLEAN;
		BEGIN
			IF (c IS MemoryContent) THEN
				WITH c: MemoryContent DO
					IF bimboTrace & ((baseReg = c.baseReg) & (offset = c.offset) & (~CheckRegisterSize OR (size = c.size))) THEN
						KernelLog.String("RegisterManager: Different size: size = "); KernelLog.Int(size, 0); KernelLog.String("; c.size = "); KernelLog.Int(c.size, 0); KernelLog.Ln;
					END;
					RETURN (baseReg = c.baseReg) & (offset = c.offset) & (~CheckRegisterSize OR (size = c.size))
				END
			ELSE
				RETURN FALSE
			END
		END Equals;

		(* returns TRUE iff two MemoryContents overlapp *)
		PROCEDURE Overlapps(c: Content): BOOLEAN;
		BEGIN
			IF (c IS MemoryContent) THEN
				WITH c: MemoryContent DO
					RETURN (baseReg = c.baseReg) & ((offset+size >  c.offset) & (c.offset+c.size > offset))
				END
			ELSE
				RETURN FALSE
			END
		END Overlapps;
	END MemoryContent;

	PCRelMemContent* = OBJECT(MemoryContent)
		VAR
			pc-: SIGNED32;

		PROCEDURE &Init*(pc, offset, size: SIGNED32);
		BEGIN Init^(PC, offset, size); SELF.pc := pc
		END Init;

		PROCEDURE Equals(c: Content): BOOLEAN;
		BEGIN
			IF (c IS PCRelMemContent) THEN
				WITH c: PCRelMemContent DO
					IF bimboTrace & (pc+offset = c.pc+c.offset) & (~CheckRegisterSize OR (size = c.size)) THEN
						KernelLog.String("RegisterManager: Different size: size = "); KernelLog.Int(size, 0); KernelLog.String("; c.size = "); KernelLog.Int(c.size, 0); KernelLog.Ln;
					END;
					RETURN (pc+offset = c.pc+c.offset) & (~CheckRegisterSize OR (size = c.size))
				END
			ELSE
				RETURN FALSE
			END
		END Equals;
	END PCRelMemContent;

	Address* = OBJECT(Content)
		VAR
			adr: PCM.Attribute;
			offset: SIGNED32;

		PROCEDURE &Init*(adr: PCM.Attribute; offset: SIGNED32);
		BEGIN SELF.adr := adr; SELF.offset := offset
		END Init;

		PROCEDURE Equals(c: Content): BOOLEAN;
		VAR b: BOOLEAN;
		BEGIN
			IF TraceDetail THEN
				KernelLog.String("Address.Equals: ");
				b := (c IS Address);
				IF ~b THEN KernelLog.String("no adr")
				ELSE
					b := (adr = c(Address).adr);
						IF ~b THEN KernelLog.String("not same adr")
					ELSE
						b := (offset = c(Address).offset);
						IF ~b THEN KernelLog.String("not same offset")
						ELSE KernelLog.String("equal!")
						END
					END
				END;
				KernelLog.Ln
			END;

			RETURN (c IS Address) & (adr = c(Address).adr) & (offset = c(Address).offset)
		END Equals;
	END Address;

	ConstantContent* = OBJECT(Content)
	END ConstantContent;

	IntConstant* = OBJECT(ConstantContent)
		VAR
			v-: SIGNED32;

		PROCEDURE &Init*(value: SIGNED32);
		BEGIN v := value
		END Init;

		PROCEDURE Equals(c: Content): BOOLEAN;
		BEGIN
			RETURN (c IS IntConstant) & (v = c(IntConstant).v)
		END Equals;
	END IntConstant;

	RealConstant* = OBJECT(ConstantContent)
		VAR
			v-: FLOAT32;

		PROCEDURE &Init*(value: FLOAT32);
		BEGIN v := value
		END Init;

		PROCEDURE Equals(c: Content): BOOLEAN;
		BEGIN
			RETURN (c IS RealConstant) & (v = c(RealConstant).v)
		END Equals;
	END RealConstant;

	LongRealConstant* = OBJECT(ConstantContent)
		VAR
			v-: FLOAT64;

		PROCEDURE &Init*(value: FLOAT64);
		BEGIN v := value
		END Init;

		PROCEDURE Equals(c: Content): BOOLEAN;
		BEGIN
			RETURN (c IS LongRealConstant) & (v = c(LongRealConstant).v)
		END Equals;
	END LongRealConstant;

	Register* = OBJECT
		VAR
			id-: SIGNED32; (** register number *)
			free-: SIGNED32;
			value: Content;
			memory: Content;
			prevLRU, nextLRU: Register;

		PROCEDURE &Init*(ID: SIGNED32);
		BEGIN id := ID
		END Init;

		(* AddContent - add a content for this register. ConstantContents are replaced, MemoryContents added to a list *)
		PROCEDURE AddContent(c: Content);
		VAR m: Content;
		BEGIN
			IF (c # NIL) THEN
				IF (c IS ConstantContent) THEN
					IF TraceDetail THEN
						KernelLog.Char("R"); KernelLog.Int(id, 0); KernelLog.String(": adding constant content... ");
					END;
					value := c; memory := NIL
				ELSE
					IF TraceDetail THEN
						KernelLog.Char("R"); KernelLog.Int(id, 0); KernelLog.String(": adding memory content...");
					END;
					c.next := memory; memory := c
				END;
				IF TraceDetail THEN
					IF (value # NIL) & (value IS IntConstant) THEN KernelLog.Int(value(IntConstant).v, 0); KernelLog.String(", ") END;
					m := memory;
					WHILE (m # NIL) DO
						IF (m IS MemoryContent) THEN KernelLog.Char("["); KernelLog.Int(m(MemoryContent).baseReg, 0); KernelLog.Char(",");
							KernelLog.Int(m(MemoryContent).offset, 0); KernelLog.String("], ")
						ELSE KernelLog.String("huga?, ")
						END;
						m := m.next
					END;
					KernelLog.Ln
				END
			END
		END AddContent;

		(* RemoveContent - removes a content from this register.
			If the parameter is a memory content, the list is searched for this content. If it is found, it's deleted from the list. If the content
			is not found in the list, the whole memory content is cleared. If r = NIL, all contents are cleared
		*)
		PROCEDURE RemoveContent(r: Content);
		VAR p,c: Content;
		BEGIN
			IF (r = NIL) THEN
				value := NIL; memory := NIL;
				IF TraceDetail THEN
					KernelLog.Char("R"); KernelLog.Int(id, 0); KernelLog.String(": content cleared"); KernelLog.Ln
				END
			ELSIF (r IS ConstantContent) THEN (* nothing *)
			ELSE
				p := NIL; c := memory;
				WHILE (c # NIL) & (c IS MemoryContent) & ~c(MemoryContent).Overlapps(r) DO p := c; c := c.next END;
				IF (c # NIL) THEN
					IF TraceDetail THEN
						KernelLog.Char("R"); KernelLog.Int(id, 0); KernelLog.String(": memory content removed"); KernelLog.Ln
					END;
					IF (p = NIL) THEN memory := c.next
					ELSE p.next := c.next
					END
				END
			END
		END RemoveContent;

		(* Equals - *)
		PROCEDURE Equals(c: Content): BOOLEAN;
		VAR m: Content;
		BEGIN
			IF (c # NIL) THEN
				IF (c IS ConstantContent) & (value # NIL) THEN
					RETURN value.Equals(c)
				ELSIF (memory # NIL) THEN
					m := memory;
					WHILE (m # NIL) & ~m.Equals(c) DO m := m.next END;
					RETURN m # NIL
				END
			END;
			RETURN FALSE
		END Equals;
	END Register;

	ARMRegisters* = OBJECT
		VAR
			registers: POINTER TO ARRAY OF Register;
			nofRegs: SIGNED32;
			reuse: SET;
			lru: Register;

		PROCEDURE &Init*(nofRegs: SIGNED32; reuseFlags: SET);
		VAR i: SIGNED32;
		BEGIN
			ASSERT(nofRegs < MAX(SET));
			NEW(registers, nofRegs); SELF.nofRegs := nofRegs;
			FOR i := 0 TO nofRegs-1 DO NEW(registers[i], i) END;
			FOR i := 0 TO nofRegs-1 DO
				registers[i].prevLRU := registers[(nofRegs+i-1) MOD nofRegs];
				registers[i].nextLRU := registers[(i+1) MOD nofRegs]
			END;
			lru := registers[0];
			reuse := reuseFlags
		END Init;

		PROCEDURE ReuseType(c: Content): BOOLEAN;
		BEGIN
			RETURN (c # NIL) &
				((((c IS ConstantContent) & (Constants IN reuse)) OR
				((c IS MemoryContent) &
					 ((MemoryAll IN reuse) OR
					((MemoryStack IN reuse) & (c(MemoryContent).baseReg = FP))))) OR
				((c IS Address) & (MemoryAbsolute IN reuse)))
		END ReuseType;

		PROCEDURE AllocDestReg*(useCount: SIGNED32): SIGNED32;
		VAR dummy: BOOLEAN;
		BEGIN RETURN AllocReg(NIL, dummy, useCount)
		END AllocDestReg;

		PROCEDURE AllocReg*(content: Content; VAR contentValid: BOOLEAN; useCount: SIGNED32): SIGNED32;
		VAR reg, i: SIGNED32; r: Register;
		BEGIN
			contentValid := FALSE;
			reg := -1;
			IF ReuseType(content) THEN (* try to reuse register *)
				WHILE (i < nofRegs) & ~contentValid DO
					IF (registers[i].free =  0) THEN
						IF (registers[i].Equals(content)) THEN
							reg := i; contentValid := TRUE
						END
					END;
					INC(i)
				END
			END;
			IF (reg = -1) THEN
				r := lru;
				WHILE (r # lru.prevLRU) & (r.free > 0) DO r := r.nextLRU END;
				IF (r.free = 0) THEN reg := r.id
				ELSE (* not enough registers *)
					PCM.Error(215, PCM.InvalidPosition, "Not enough registers.");
					HALT(MAX(SIGNED16));
					HALT(INTERNALERROR)
				END;
				IF (content # NIL) THEN Invalidate(content); r.AddContent(content)
				ELSE r.RemoveContent(NIL)
				END
			END;
			InAllocReg(reg, useCount);
			RETURN reg
		END AllocReg;

		PROCEDURE AllocSpecialReg*(reg: SIGNED32; content: Content; useCount: SIGNED32);
		BEGIN {EXCLUSIVE}
			ASSERT((0 <= reg) & (reg < nofRegs));
			IF (registers[reg].free # 0) THEN
				KernelLog.Enter;
				KernelLog.String("ERROR in AllocSpecialReg: register is not free (use count: ");
				KernelLog.Int(registers[reg].free, 0); KernelLog.Char(")");
				KernelLog.Exit
			END;
			IF (content # NIL) THEN Invalidate(content); registers[reg].AddContent(content)
			ELSE registers[reg].RemoveContent(NIL)
			END;
			InAllocReg(reg, useCount)
		END AllocSpecialReg;

		PROCEDURE InAllocReg(reg, useCount: SIGNED32);
		VAR r: Register;
		BEGIN
			ASSERT(registers[reg].free = 0);
			r := registers[reg];
			r.free := useCount;
			r.prevLRU.nextLRU := r.nextLRU; r.nextLRU.prevLRU := r.prevLRU;
			IF (lru = r) THEN lru := r.nextLRU END;
			r.prevLRU := lru.prevLRU; lru.prevLRU.nextLRU := r;
			r.nextLRU := lru; lru.prevLRU := r
		END InAllocReg;

		PROCEDURE FixRegisterUse*(reg, deltaUse: SIGNED32);
		BEGIN {EXCLUSIVE}
			ASSERT((0 <= reg) & (reg < nofRegs) & (registers[reg].free + deltaUse >= 0));
			INC(registers[reg].free, deltaUse)
		END FixRegisterUse;

		PROCEDURE FreeReg*(reg: SIGNED32);
		BEGIN {EXCLUSIVE}
			IF ~SpecialReg(reg) THEN
				ASSERT((0 <= reg) & (reg < nofRegs) & (registers[reg].free > 0));
				DEC(registers[reg].free)
			END
		END FreeReg;

		PROCEDURE FreeAll*;
		VAR i: SIGNED32;
		BEGIN {EXCLUSIVE}
			FOR i := 0 TO nofRegs-1 DO registers[i].free := 0 END
		END FreeAll;

		PROCEDURE SetRegisterContent*(reg: SIGNED32; content: Content);
		VAR r: Register;
		BEGIN { EXCLUSIVE }
			IF (0 <= reg) & (reg < nofRegs) THEN	(* ignore invalid registerers (CG may want to set the register content of the SP register) *)
				r := registers[reg];
				r.RemoveContent(NIL);
				IF (content # NIL) THEN r.AddContent(content) END;
				r.prevLRU.nextLRU := r.nextLRU; r.nextLRU.prevLRU := r.prevLRU;
				IF (lru = r) THEN lru := r.nextLRU END;
				r.prevLRU := lru.prevLRU; lru.prevLRU.nextLRU := r;
				r.nextLRU := lru; lru.prevLRU := r
			END
		END SetRegisterContent;

		PROCEDURE AddRegisterContent*(reg: SIGNED32; content: Content);
		VAR r: Register;
		BEGIN { EXCLUSIVE }
			IF (content # NIL) THEN
				ASSERT((0 <= reg) & (reg < nofRegs));
				r := registers[reg];
				Invalidate(content); r.AddContent(content);
				r.prevLRU.nextLRU := r.nextLRU; r.nextLRU.prevLRU := r.prevLRU;
				IF (lru = r) THEN lru := r.nextLRU END;
				r.prevLRU := lru.prevLRU; lru.prevLRU.nextLRU := r;
				r.nextLRU := lru; lru.prevLRU := r
			END
		END AddRegisterContent;

		PROCEDURE Invalidate*(content: Content);
		VAR i: SIGNED32;
		BEGIN
			IF (content # NIL) & (content IS MemoryContent) THEN
				FOR i := 0 TO nofRegs-1 DO
					registers[i].RemoveContent(content)
				END
			END
		END Invalidate;

		PROCEDURE InvalidateAll*;
		VAR i: SIGNED32;
		BEGIN
			FOR i := 0 TO nofRegs-1 DO registers[i].RemoveContent(NIL) END
		END InvalidateAll;

		PROCEDURE GetReg*(reg: SIGNED32): Register;
		BEGIN
			ASSERT((0 <= reg) & (reg < nofRegs));
			RETURN registers[reg]
		END GetReg;

		PROCEDURE GetUsedRegisterSet*(): SET;
		VAR r: SET; i: SIGNED32;
		BEGIN
			FOR i := 0 TO nofRegs-1 DO
				IF (registers[i].free > 0) THEN INCL(r, i) END
			END;
			RETURN r
		END GetUsedRegisterSet;

		PROCEDURE IsRegisterFree*(reg: SIGNED32): BOOLEAN;
		BEGIN
			ASSERT((0 <= reg) & (reg < nofRegs));
			RETURN registers[reg].free = 0
		END IsRegisterFree;

		PROCEDURE GetRegisterUseCount*(reg: SIGNED32): SIGNED32;
		BEGIN
			ASSERT((0 <= reg) & (reg < nofRegs));
			RETURN registers[reg].free
		END GetRegisterUseCount;

	END ARMRegisters;

VAR bimboTrace*: BOOLEAN;

PROCEDURE SpecialReg(r: SIGNED32): BOOLEAN;
BEGIN RETURN (r = PCOARM.SP) OR (r = PCOARM.FP) OR (r = PCOARM.LR) OR (r = PCOARM.PC)
END SpecialReg;

PROCEDURE NewMemContent*(pc, rBase, offset, size: SIGNED32): MemoryContent;
VAR c: MemoryContent;
BEGIN
	IF (size = 0) THEN HALT(MAX(SIGNED16)) END;
	IF (rBase = PC) THEN RETURN NewPCRelMemContent(pc, offset, size)
	ELSE NEW(c, rBase, offset, size); RETURN c
	END
END NewMemContent;

PROCEDURE NewPCRelMemContent*(pc, offset, size: SIGNED32): PCRelMemContent;
VAR c: PCRelMemContent;
BEGIN 	IF (size = 0) THEN HALT(MAX(SIGNED16)) END;
NEW(c, pc, offset, size); RETURN c
END NewPCRelMemContent;

PROCEDURE NewMemAddress*(adr: PCM.Attribute; offset: SIGNED32): Address;
VAR c: Address;
BEGIN NEW(c, adr, offset); RETURN c
END NewMemAddress;

PROCEDURE NewIntConst*(v: SIGNED32): IntConstant;
VAR c: IntConstant;
BEGIN NEW(c, v); RETURN c
END NewIntConst;

PROCEDURE NewRealConst*(v: FLOAT32): RealConstant;
VAR c: RealConstant;
BEGIN NEW(c, v); RETURN c
END NewRealConst;

PROCEDURE NewLongRealConst*(v: FLOAT64): LongRealConstant;
VAR c: LongRealConstant;
BEGIN NEW(c, v); RETURN c
END NewLongRealConst;


END PCARMRegisters.
