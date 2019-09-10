(* Paco, Copyright 2000 - 2002, Patrik Reali, ETH Zurich *)

MODULE PCLIR; (** AUTHOR "prk / be"; PURPOSE "Parallel Compiler: intermediate code representation"; *)

IMPORT
		Machine, KernelLog,
		PCM, PCBT;


CONST
	Statistics = FALSE;
	Debug= FALSE; (* fof for code generation debugging purposes *)


	(** ============= Instruction Set Definitions ======================== *)

TYPE
	Opcode* = SIGNED8;
	Register* = SIGNED32;
	Size* = SIGNED8;

CONST
		(**Register sizes*)
	NoSize* = 0;
	Int8* = 1;  Int16* = 2;  Int32* = 3;  Int64* = 4;  Float32* = 5;  Float64* = 6;
	IntSize* = {Int8..Int64};  FloatSize* = {Float32 .. Float64};

	(**Special Register Values*)
	none* = -1;  FP* = -2;  SP* = -3;  Absolute* = -4;
	HwReg* = -16;	(** map to a real register, reg := HwReg - Rx *)

TYPE
	InstructionAttribute* = OBJECT   END InstructionAttribute;
	Instruction* = RECORD
		op*: Opcode;
		src1*, src2*, src3*: Register;
		val*: SIGNED32;					(*src for constant values, used by form*C instr. *)
		adr-: PCM.Attribute;			(* reference to absolute addresses to be patched later or by the linker *)
		barrier-: SIGNED32;			(* pos of previous barrier in code *)

		suppress*: BOOLEAN;		(* suppress this instruction*)

		dstCount*: SIGNED8;			(* counts use of this register *)
		dstSize-: Size;						  (* size of this register *)
		dstSigned-: BOOLEAN; 		  (* TRUE if the value in dst is signed *)

		info*: InstructionAttribute;	(* link to user-defined information *)
	END;

	(**
		Opcodes
		The opcodes have a format XY,
		X = number of destinations [0,1] register assigned by the instruction
		Y =  number of sources [0..3, C] registers used by the instruction. C = Constant Value
	*)
CONST
		(** Instruction Formats *)
	form00* = 0;	(** Instr with no operands *)
	form0C* = 1;	(** Instr Immediate *)
	form01* = 2;	(** Instr Src *)
	form10* = 3;	(** Instr Dst *)
	form1C* = 4;	(** Instr Dst, Immediate *)
	form11* = 5;	(** Instr Dst, Src *)
	form1M* = 6;	(** Instr Dst, Mem *)
	formM1* = 7;	(** Instr Mem, Src *)
	form02* = 8;	(** Instr Src1, Src2 *)
	form12* = 9;	(** Instr Dst, Src1, Src2 *)
	form02C* = 10;	(** Instr Src1, Src2, Imm *)
	form03* = 11;	(** Instr Src1, Src2, Srcc3 *)
	formXX* = 12;	(** Special formats *)

	form1X* = {form1C, form1M, form10, form11, form12};

		(** Instruction Flags*)
	barrier* = 0;  (*this instruction is a barrier, optimizations should not go past it *)
	commutative* = 1;	(* formX2 - Src1 / Src2 can be swapped *)

		(** Opcodes *)
	(**

Definitions:
    Rpc: the register implicitely defined by the instruction
    R1:  the register defined by the src1 field
    R2:  the register defined by the src2 field
    R3:  the register defined by the src3 field
    val: the value in the val field


Opcode Table
op     Format   sss v a   Description
                123 a d
                    l r
---------------------------------------------------------
load     1M     x   x     Rpc := MEM[val+R1]   (relative)
                A   x x   Rpc := MEM[val+Adr]  (absolute)
loadc    1C         x     Rpc := val
                    x x   Rpc := val+Adr
store    M1     xx  x     MEM[value+R1]  := R2 (relative)
                Ax  x x   MEM[value+Adr] := R2 (relative)

in       11     x         Rpc := HwPort(R1)
out      02     xx        HwPort(R1) := R2

nop      00               no operation

saveregs 00               save registers currently in use
loadregs 00               restore registers in use at last saveregs

label    0C         x     val = position in source code
                    0     anchor for jumps (contains links list)

jCC      02C    xx  x     if CC(R1,R2) -> pc := val
                          CC = {e, ne, lt, le, gt, ge, ae, f, nf}

jmp      0C         x     pc := val
call     0C           x   push pc; pc := adr
callreg  01     x         push pc; pc := R1
syscall  0C         x     push pc; pc := SYSTEM_CALL[val]

enter    XX         x x   enter subrutine with CALLCONV[val]. Additional info = adr
exit     XX     x   x     exit subroutine with CALLCONV[val], nofbytes in src1

trap     0C         x     HALT(val)
tCC      02C    xx  x     IF CC(R1, R2) -> HALT(val)

setCC    12     xx        IF CC(R1, R2) THEN Rpc := 1 ELSE Rpc := 0 END

result   10               Rpc := 1st result of previous call (must follow call)
result2  10               Rpc := 2nd result of previous call (must follow result)
pop      10               Rpc := MEM[SP]; inc(SP)
ret      01     x         (1st result of current call) := R1
ret2     01     x         (2nd result of current call) := R1 (must follow ret)
push     01     x         MEM[SP] := R1; dec(SP)
kill     01     x         kill R1 (used with phi)
loadsp   01     x         SP := R1

convs    11     x         Rpc :=   SIGNED_CONVERSION(size, R1)
convu    11     x         Rpc := UNSIGNED_CONVERSION(size, R1)
copy     11     x         Rpc := Rsrc1 (no convertion, e.g. int->float register)

not      11     x         Rpc := BINARY_NEGATION(R1)
neg      11     x         Rpc := ARITH_NEGATION(R1)
abs      11     x         Rpc := ABSOLUTE(R1)

mul      12     xx        Rpc := R1 * R2
div      12     xx        Rpc := R1 / R2
mod      12     xx        Rpc := R1 % R2
sub      12     xx        Rpc := R1 - R2
add      12     xx        Rpc := R1 + R2

and      12     xx        Rpc := AND(R1, R2)
or       12     xx        Rpc := OR (R1, R2)
xor      12     xx        Rpc := XOR(R1, R2)

bts      12     xx        Rpc := OR (R1, 1<<R2)
btc      12     xx        Rpc := AND(R1, NOT(1<<R2))

bsh      12     xx        Rpc := BINARY_SHIFT(R1, R2)
ash      12     xx        Rpc :=  ARITH_SHIFT(R1, R2)
rot      12     xx        Rpc := ROTATE(R1, R2)

phi      12     xx        Rpc := PHI(R1, R2)

move     03     xxx       MOVE FROM MEM[R1..R1+R3-1] TO MEM[R2..R2+R3-1]
                          at end R1':=R1+R3 and R2':=R2+R3

inline   XX               inline assembler code

case     XX     xxx       case on R1 (R2 = min, R3 = max)
casel    XX     x   x     caseline: R1 = case, val = case-offset
casee    XX     x         caseelse: R1 = case


Remarks:
1) dstCount and dstSize are used by the form1X instructions

	*)

	(* ProgTools.Enum 0 *
		load loadc store
		in out
		nop saveregs loadregs
		label
		je jne jlt jle jgt jge jb jbe ja jae jf jnf
		jmp call syscall enter exit trap tae tne
		sete setne setlt setle setgt setge setb setbe seta setae setf setnf
		result result2 pop
		ret ret2 push callreg kill loadsp
		convs convu copy
		not neg abs
		mul  div  mod sub  add and or xor bts btc
		ash bsh rot
		phi
		move
		inline
		case casel casee
	*)
	load* =   0; loadc* =   1; store* =   2; in* =   3; out* =   4; nop* =   5;
	saveregs* =   6; loadregs* =   7; label* =   8; je* =   9; jne* =  10;
	jlt* =  11; jle* =  12; jgt* =  13; jge* =  14; jb* =  15; jbe* =  16;
	ja* =  17; jae* =  18; jf* =  19; jnf* =  20; jmp* =  21; call* =  22;
	syscall* =  23; enter* =  24; exit* =  25; trap* =  26; tae* =  27;
	tne* =  28; sete* =  29; setne* =  30; setlt* =  31; setle* =  32;
	setgt* =  33; setge* =  34; setb* =  35; setbe* =  36; seta* =  37;
	setae* =  38; setf* =  39; setnf* =  40; result* =  41; result2* =  42;
	pop* =  43; ret* =  44; ret2* =  45; push* =  46; callreg* =  47;
	kill* =  48; loadsp* =  49; convs* =  50; convu* =  51; copy* =  52;
	not* =  53; neg* =  54; abs* =  55; mul* =  56; div* =  57; mod* =  58;
	sub* =  59; add* =  60; and* =  61; or* =  62; xor* =  63; bts* =  64;
	btc* =  65; ash* =  66; bsh* =  67; rot* =  68; phi* =  69; move* =  70;
	inline* =  71; case* =  72; casel* =  73; casee* =  74; loadfp* = 75;
	moveDown* = 76; finallylabel* = 77; saveregsaligned* = 78;	(* fld *)


	NofOpcodes* = saveregsaligned+1;(* fld *)

		(*Module Configuration*)
	PieceLen = 128;	(*size of a code piece (in instructions). TO BE TUNED*)

TYPE
	InstructionSetDescription* = ARRAY NofOpcodes OF RECORD
		format-: SIGNED8;
		flags-: SET;
		name-: ARRAY 9 OF CHAR;	(* Debug *)

		emit-: EmitProc;
	END;


		(* a piece of code*)
	Piece* = OBJECT
		VAR
			instr*: ARRAY PieceLen OF Instruction;
			len: SIGNED32;
			next, prev: Piece;

		PROCEDURE & Init*;
		BEGIN len := 0; next := NIL; prev := NIL;
			IF Statistics THEN  Machine.AtomicInc(aPieceCount)  END
		END Init;
	END Piece;

	(** Code - a junk of code *)
	CodeAttributes* = POINTER TO RECORD  END;
	Code* = OBJECT (PCM.Attribute)
		VAR
			pc-: SIGNED32;	(* code length *)
			first, last: Piece;

			barrier-: SIGNED32;	(*last barrier in code*)
			info-: CodeAttributes;
			name*: ARRAY 32 OF CHAR;	(*debug*)

		PROCEDURE NewInstruction;
		BEGIN
			IF last.len = PieceLen THEN
				NEW(last.next);
				last.next.prev := last;  last := last.next
			END;
			INC(last.len); INC(pc)
		END NewInstruction;

		(* Get a piece containing the searched instruction *)

		PROCEDURE GetPiece*(VAR src: SIGNED32; VAR p: Piece);
		BEGIN
			p := first;
			WHILE src >= PieceLen DO
				p := p.next; DEC(src, PieceLen)
			END;
		END GetPiece;

		PROCEDURE Traverse*(proc: TraverseProc;  reversed: BOOLEAN;  context: ANY);
		VAR	p: Piece; pos, pc0: SIGNED32;
		BEGIN
			IF reversed THEN
				p := last; pc0 := pc;
				WHILE p # NIL DO
					pos := p.len;
					WHILE pos > 0 DO
						DEC(pos); DEC(pc0);
						proc(SELF, p.instr[pos], pc0, context)
					END;
					p := p.prev
				END
			ELSE
				p := first; pc0 := 0;
				WHILE p # NIL DO
					pos := 0;
					WHILE pos < p.len DO
						proc(SELF, p.instr[pos], pc0, context);
						INC(pos); INC(pc0)
					END;
					p := p.next
				END
			END
		END Traverse;

		PROCEDURE & Init*;
		BEGIN
			IF Statistics THEN  Machine.AtomicInc(aCodeCount)  END;
			NEW(first);  last := first;  barrier := 0
		END Init;
	END Code;

	EmitProc* = PROCEDURE (code: Code;  VAR instr: Instruction;  pc: SIGNED32);
	TraverseProc* = PROCEDURE (code: Code;  VAR instr: Instruction;  pc: SIGNED32;  context: ANY);

	AsmFixup* = POINTER TO RECORD
		offset*: SIGNED32;
		adr*: PCM.Attribute;
		next*: AsmFixup
	END;

	AsmBlock* = POINTER TO RECORD
		len*: SIGNED32;
		code*: ARRAY 256 OF CHAR;
		next*: AsmBlock
	END;

	AsmInline* = OBJECT (PCM.Attribute)
	VAR
		code*: AsmBlock;
		fixup*: AsmFixup;
	END AsmInline;


	(** ----------- Code Generator Types ----------------------*)
	CodeArray* = POINTER TO ARRAY OF CHAR;
	InitHandler* = PROCEDURE(): BOOLEAN;	(** Code generator initialization. Called before code generation *)
	DoneHandler* = PROCEDURE(VAR res: INTEGER);	(** called after code generation. result = 0 indicates success *)
	GetCodeHandler* = PROCEDURE(VAR code: CodeArray; VAR codelength, hdrlength, addressFactor: SIGNED32); (** returns the code *)
		(** codelength = actual size of the code (bytes); hdrlength = value stored in header file as code length (bytes)
			addressFactor = addresses in fixup-lists are multiplied by this factor *)

	CodeGenerator* = RECORD	(** abstract code generator *)
		MaxCodeSize*: SIGNED32; (** max. codesize *)
		SysCallMap*: POINTER TO ARRAY OF CHAR;	(** internal syscall id -> object file syscall tag *)
		Init*: InitHandler;
		Done*: DoneHandler;
		Optimize*: PROCEDURE (code: Code);
		GetCode*: GetCodeHandler;
		DumpCode*: TraverseProc;
		ParamAlign*: SIGNED32;
	END;


VAR
	InstructionSet*: InstructionSetDescription;
	InstructionInit*: PROCEDURE (VAR instr: Instruction);	(* plug-in, called whenever an instruction is created *)
	CG*: CodeGenerator;

	Address*, Set*, SizeType*: Size;

	RegName: ARRAY 8 OF CHAR;

	aTotalInstructions, aSuppressedInstructions,
	aCodeCount, aPieceCount: SIGNED32;	(* only if Statistics *)
	aInstrCount, aSupprInstrCount: ARRAY NofOpcodes OF SIGNED32;


(* ------------------------ Instruction-Based Helper Functions -------------------------------- *)

	PROCEDURE InitInstr(VAR instr: Instruction;  op: Opcode; size: Size; signed: BOOLEAN; val: SIGNED32;
										src1, src2, src3: Register;  adr: PCM.Attribute; barrier: SIGNED32);
	BEGIN
		instr.op := op;  instr.val := val;  instr.src1 := src1;
		instr.src2 := src2;  instr.src3 := src3;
		instr.adr := adr;
		instr.dstSize := size;  instr.dstCount := 0; instr.dstSigned := signed;
		instr.suppress := FALSE;
		instr.barrier := barrier;
	END InitInstr;

(* Use - Increment usage count of a register *)

	PROCEDURE Use(code: Code;  reg: Register);
	VAR p: Piece;
	BEGIN
		IF reg >= 0 THEN
			code.GetPiece(reg, p);  INC(p.instr[reg].dstCount)
		END
	END Use;

(** SizeOf - Return size of a Register *)

	PROCEDURE SizeOf*(code: Code;  reg: Register): Size;
	VAR p: Piece;
	BEGIN
		IF reg >= 0 THEN
			code.GetPiece(reg, p); 	RETURN (p.instr[reg].dstSize)
		ELSIF (reg = FP) OR (reg = SP) THEN
			RETURN  Address
		END;
		RETURN NoSize
	END SizeOf;

(** Signed- Returns TRUE if the value in this register is signed *)

	PROCEDURE Signed*(code: Code;  reg: Register): BOOLEAN;
	VAR p: Piece;
	BEGIN
		IF reg >= 0 THEN
			code.GetPiece(reg, p); RETURN (p.instr[reg].dstSigned)
		END;
		RETURN FALSE
	END Signed;

(** NofBytes - Return the number of Bytes taken by a Size *)

	PROCEDURE NofBytes*(size: Size): SIGNED8;
	BEGIN
		CASE size OF
		|  Int8:  RETURN 1
		|  Int16:  RETURN 2
		|  Int32, Float32:  RETURN 4
		|  Int64, Float64:  RETURN 8
		END
	END NofBytes;

(* Insert a new instruction in code *)

	PROCEDURE NewInstr(code: Code; op: Opcode; size: Size; signed: BOOLEAN; val: SIGNED32; s1, s2, s3: Register; adr: PCM.Attribute);
	VAR p: Piece;
	BEGIN
		code.NewInstruction;
		p := code.last;
		InitInstr(p.instr[p.len-1], op, size, signed, val, s1, s2, s3, adr, code.barrier);
		IF barrier IN InstructionSet[op].flags THEN  code.barrier := code.pc  END;
		IF InstructionInit # NIL THEN InstructionInit(p.instr[p.len-1]) END
	END NewInstr;

(** Code Emission Procedures *)

	PROCEDURE EmitStoreAbsolute*(code: Code; offset: SIGNED32; addr: PCM.Attribute; source: Register);	(** store  @dest, Rsource *)
	BEGIN
		NewInstr(code, store, NoSize, FALSE, offset, Absolute, source, none, addr);
	END EmitStoreAbsolute;

	PROCEDURE EmitStoreRelative*(code: Code; offset: SIGNED32; base, source: Register);	(** store off[Rbase], Rsource *)
	BEGIN
		NewInstr(code, store, NoSize, FALSE, offset, base, source, none, NIL);
		Use(code, source);
		Use(code, base);
	END EmitStoreRelative;

	PROCEDURE EmitStoreReg*(code: Code; dst, source: Register);
	BEGIN
		ASSERT(dst <= HwReg);
		NewInstr(code, store, NoSize, FALSE, none, dst, source, none, NIL);
		Use(code, source);
	END EmitStoreReg;

	PROCEDURE EmitLoadAbsolute*(code: Code; size: Size;  signed: BOOLEAN; VAR dest: Register;  offs: SIGNED32;  addr: PCM.Attribute);
	BEGIN
		dest := code.pc;
		NewInstr(code, load, size, signed, offs, Absolute, none, none, addr);
	END EmitLoadAbsolute;

	PROCEDURE EmitLoadRelative*(code: Code; size: Size; signed: BOOLEAN; VAR dest: Register; offset: SIGNED32; base: Register);
	BEGIN
	(*	ASSERT(Address = SizeOf(code, base),113); *)
		dest := code.pc;
		NewInstr(code, load, size, signed, offset, base, none, none, NIL);
		Use(code, base);
	END EmitLoadRelative;

	PROCEDURE EmitLoadConst*(code: Code;  VAR dest: Register;  size: Size;  signed: BOOLEAN;  value: SIGNED32);
		(*loadc - only for immediate mode! Use load (as abs) for const in the const table*)
	BEGIN
		ASSERT((Int8<=size) & (size<=Int64), 200);
		dest := code.pc;
		NewInstr(code, loadc, size, signed, value, none, none, none, NIL);
	END EmitLoadConst;

	PROCEDURE EmitLoadAddr*(code: Code;  VAR dest: Register;  offset: SIGNED32;  addr: PCM.Attribute);
	BEGIN
		dest := code.pc;
		NewInstr(code, loadc, Address, FALSE, offset, none, none, none, addr);
	END EmitLoadAddr;

	PROCEDURE Emit0C*(code: Code;  op: Opcode;  val: SIGNED32);	(** op const *)
	BEGIN
		ASSERT(InstructionSet[op].format = form0C, 200);
		NewInstr(code, op, NoSize, FALSE, val, none, none, none, NIL);
	END Emit0C;

	PROCEDURE EmitCall*(code: Code;  proc: PCM.Attribute);
	BEGIN
		NewInstr(code, call, NoSize, FALSE, none, none, none, none, proc);
	END EmitCall;

	PROCEDURE EmitEnter*(code: Code;  callconv: SIGNED32;  attr: PCM.Attribute);
	BEGIN
		NewInstr(code, enter, NoSize, FALSE, callconv, none, none, none, attr);
	END EmitEnter;

	PROCEDURE EmitFinallyLabel*(code: Code; attr: PCM.Attribute);
	BEGIN
		NewInstr(code, finallylabel, NoSize, FALSE, 0, none, none, none, attr);
	END EmitFinallyLabel;

	PROCEDURE EmitExit*(code: Code;  callconv, parSize: SIGNED32; attr: PCM.Attribute (* ug *));
	BEGIN
		NewInstr(code, exit, NoSize, FALSE, callconv, parSize, none, none, attr (* ug *));
	END EmitExit;

	PROCEDURE Emit00*(code: Code;  op: Opcode);	(** op (no operands) *)
	BEGIN
		ASSERT(InstructionSet[op].format = form00, 200);
		NewInstr(code, op, NoSize, FALSE, none, none, none, none, NIL);
	END Emit00;

	PROCEDURE Emit01*(code: Code;  op: Opcode; src: Register);	(** op Rsrc  (use src) *)
	BEGIN
		ASSERT(InstructionSet[op].format = form01, 200);
		ASSERT((op # loadsp) OR (SizeOf(code, src) = Address), 201);
		NewInstr(code, op, NoSize, FALSE, none, src, none, none, NIL);
		Use(code, src)
	END Emit01;

	PROCEDURE Emit10*(code: Code;  op: Opcode; VAR dest: Register; size: Size; signed: BOOLEAN);	(** op Rdest (create dest) *)
	BEGIN
		ASSERT(InstructionSet[op].format = form10, 200);
		dest := code.pc;
		NewInstr(code, op, size, signed, none, none, none, none, NIL)
	END Emit10;

	PROCEDURE EmitConv*(code: Code;  op: Opcode;  VAR dest: Register; size: Size; signed: BOOLEAN; src: Register);	(** conv Rdest, Rsrc (op11 but with different size) *)
	VAR s: Size; sign: BOOLEAN;
	BEGIN
		s := SizeOf(code, src);
		sign := Signed(code, src);
		ASSERT((size # s) OR (signed # sign) OR (op = in), 210);
		ASSERT((op = convs) OR (op = convu) OR (op = copy) OR (op = in), 211);
		dest := code.pc;
		NewInstr(code, op, size, signed, none, src, none, none, NIL);
		Use(code, src)
	END EmitConv;

	PROCEDURE Emit11*(code: Code;  op: Opcode; VAR dest: Register; src1: Register);	(** op Rdest, Rsrc1 *)
	VAR size: Size; signed: BOOLEAN;
	BEGIN
		ASSERT(InstructionSet[op].format = form11, 200);
		dest := code.pc;
		size := SizeOf(code, src1); signed := Signed(code, src1);
		NewInstr(code, op, size, signed, none, src1, none, none, NIL);
		Use(code, src1)
	END Emit11;

	PROCEDURE Emit02*(code: Code;  op: Opcode; src1, src2: Register);	(** op Rsrc1, Rsrc2 *)
	BEGIN
		ASSERT(InstructionSet[op].format = form02, 200);
		ASSERT((SizeOf(code, src1) = SizeOf(code, src2)) (*& (Signed(code, src1) = Signed(code, src2))*) OR (op = out), 201);
		NewInstr(code, op, NoSize, FALSE, none, src1, src2, none, NIL);
		Use(code, src1); Use(code, src2)
	END Emit02;

	PROCEDURE Emit02C*(code: Code;  op: Opcode; src1, src2: Register;  val: SIGNED32);	(** op Rsrc1, Rsrc2, Imm *)
		VAR size1, size2: Size;
	BEGIN
		size1 := SizeOf(code, src1);
		size2 := SizeOf(code, src2);
		ASSERT(InstructionSet[op].format = form02C, 200);
		ASSERT(size1 = size2, 201);
		NewInstr(code, op, NoSize, FALSE, val, src1, src2, none, NIL);
		Use(code, src1); Use(code, src2)
	END Emit02C;

	PROCEDURE Emit03*(code: Code;  op: Opcode; src1, src2, src3: Register);	(** op Rsrc1, Rsrc2, Rsrc3 *)
	BEGIN
		ASSERT(InstructionSet[op].format = form03, 200);
		ASSERT(Address = SizeOf(code, src1), 201);
		ASSERT(Address = SizeOf(code, src2), 202);
		NewInstr(code, op, NoSize, FALSE, none, src1, src2, src3, NIL);
		Use(code, src1); Use(code, src2); Use(code, src3)
	END Emit03;

	PROCEDURE Emit12*(code: Code;  op: Opcode; VAR dest: Register; src1, src2: Register);
	VAR size, size2: Size; signed(*, signed2*): BOOLEAN;
	BEGIN
		ASSERT(InstructionSet[op].format = form12, 200);
		ASSERT(op # phi, 201);	(*special case*)
		dest := code.pc;
		size := SizeOf(code, src1); signed := Signed(code, src1);
		size2 := SizeOf(code, src2); (*signed2 := Signed(code, src2);*)
		ASSERT((((op >= ash) & (op <= rot)) & (Int8 = size2)) OR (size = size2) (*& (signed = signed2)*), 202);
		NewInstr(code, op, size, signed, none, src1, src2, none, NIL);
		Use(code, src1); Use(code, src2)
	END Emit12;

	PROCEDURE Emit12Sized*(code: Code;  op: Opcode; VAR dest: Register; size: Size; src1, src2: Register);
	VAR size1, size2: Size;
	BEGIN
		ASSERT(InstructionSet[op].format = form12, 200);
		dest := code.pc;
		size1 := SizeOf(code, src1);
		size2 := SizeOf(code, src2);
		ASSERT((((op >= ash) & (op <= rot)) & (Int8 = size2)) OR (size1 = size2), 202);
		NewInstr(code, op, size, FALSE, none, src1, src2, none, NIL);
		Use(code, src1); Use(code, src2)
	END Emit12Sized;

	PROCEDURE EmitInline*(code: Code;  adr: PCM.Attribute);
	BEGIN
		NewInstr(code, inline, NoSize, FALSE, none, none, none, none, adr)
	END EmitInline;

	PROCEDURE EmitCase*(code: Code;  VAR dst: Register;  src: Register);
	BEGIN
		ASSERT(Int32 = SizeOf(code, src), 200);
		dst := code.pc;
		NewInstr(code, case, NoSize, FALSE, none, src, MAX(SIGNED32), MIN(SIGNED32), NIL);
		Use(code, src);
	END EmitCase;

	PROCEDURE EmitCaseLine*(code: Code;  base: Register;  val: SIGNED32);
	VAR  p: Piece;
	BEGIN
		NewInstr(code, casel, NoSize, FALSE, val, base, none, none, NIL);
		code.GetPiece(base, p);
		IF p.instr[base].src2 > val THEN  p.instr[base].src2 := val  END;
		IF p.instr[base].src3 < val THEN  p.instr[base].src3 := val  END
	END EmitCaseLine;

	PROCEDURE EmitCaseElse*(code: Code;  base: Register);
	BEGIN
		NewInstr(code, casee, NoSize, FALSE, none, base, none, none, NIL)
	END EmitCaseElse;

	PROCEDURE EmitPhi*(code: Code;  VAR dest: Register; src1, src2: Register);
	VAR size: Size; signed: BOOLEAN;
	BEGIN
		dest := code.pc;
		size := SizeOf(code, src1); signed := Signed(code, src1);
		ASSERT((src2 = none) OR (size = SizeOf(code, src2)) (*& (signed = Signed(code, src2) )*));
		NewInstr(code, phi, size, signed, none, src1, src2, none, NIL)
	END EmitPhi;

	PROCEDURE PatchPhi*(code: Code;  dest: Register;  src2: Register);
	VAR  p: Piece;
	BEGIN
		code.GetPiece(dest, p);  p.instr[dest].src2 := src2;
		ASSERT((SizeOf(code, p.instr[dest].src1) = SizeOf(code, src2)) (*& (Signed(code, p.instr[dest].src1) = Signed(code, src2))*))
	END PatchPhi;

(** Fixup list handling*)

	PROCEDURE FixList*(code: Code;  VAR pos: SIGNED32; val: SIGNED32);		(**fix the list starting at pos with val *)
	VAR p: Piece; next: SIGNED32;
	BEGIN
		WHILE pos # none DO
			code.GetPiece(pos, p);
			next := p.instr[pos].val; p.instr[pos].val := val;
			pos := next
		END
	END FixList;

	PROCEDURE MergeList*(code: Code;  l1, l2: SIGNED32): SIGNED32;			(** merge two fixup lists *)
	VAR	top: SIGNED32; p: Piece;
	BEGIN
		IF l1 = none THEN  RETURN l2
		ELSIF l2 = none THEN  RETURN l1
		ELSE
			top := l1;
			code.GetPiece(l1, p);
			WHILE p.instr[l1].val # none DO
				l1 := p.instr[l1].val;
				code.GetPiece(l1, p)
			END;
			p.instr[l1].val := l2;
			RETURN top
		END
	END MergeList;

(** Other LIR Functionalities *)

	(** SwapSources - formX2 only, swap Src1 and Src2 *)

	PROCEDURE SwapSources*(VAR instr: Instruction);
	VAR  t: Register;
	BEGIN
		ASSERT(InstructionSet[instr.op].format IN {form02, form12, form02C});
		t := instr.src1;  instr.src1 := instr.src2;  instr.src2 := t
	END SwapSources;

(** DumpCode (Debug) - TraverseProc, dumps whole code to global writer W *)

	PROCEDURE DumpCode*(code: Code;  VAR instr: Instruction;  pc: SIGNED32;  context: ANY);
	VAR  op: Opcode;  format: SIGNED8;

		PROCEDURE Reg(r: SIGNED32);
		BEGIN
			IF r = FP THEN
				PCM.LogWStr("FP")
			ELSIF r = SP THEN
				PCM.LogWStr("SP")
			ELSIF r <= HwReg THEN
				PCM.LogWStr("HW");
				PCM.LogWNum(HwReg-r)
			ELSE
				IF Signed(code, r) THEN PCM.LogW("S") END;
				PCM.LogW(RegName[SizeOf(code, r)]);
				PCM.LogWNum(r)
			END
		END Reg;

		PROCEDURE Indirect(offs, base: SIGNED32);
		BEGIN
			IF base <= HwReg THEN
				Reg(base)
			ELSIF base = Absolute THEN
				PCM.LogW("@"); PCM.LogWNum(offs)
			ELSE
				PCM.LogWNum(offs); PCM.LogW("[");
				Reg(base); PCM.LogW("]")
			END
		END Indirect;

		PROCEDURE CaseOpd(src: Register;  min, max: SIGNED32);
		BEGIN
			Reg(src); PCM.LogWStr("  {"); PCM.LogWNum(min);
			PCM.LogWStr(", "); PCM.LogWNum(max);  PCM.LogW("}")
		END CaseOpd;

		PROCEDURE CaseLineOpd(base, val: SIGNED32);
		BEGIN
			PCM.LogWNum(val); PCM.LogWStr("  {");
			PCM.LogWNum(base); PCM.LogWStr("}")
		END CaseLineOpd;

		PROCEDURE CaseElseOpd(base: SIGNED32);
		BEGIN PCM.LogWStr("  {"); PCM.LogWNum(base); PCM.LogWStr("}")
		END CaseElseOpd;

	BEGIN
		op := instr.op;  format := InstructionSet[op].format;
		PCM.LogWNum(pc); PCM.LogW(9X);
		IF (format IN form1X) OR (op = load) THEN
			PCM.LogWNum(instr.dstCount);
		ELSE
			PCM.LogWStr("   ")
		END;
		PCM.LogW(9X);
		PCM.LogWStr(InstructionSet[op].name); PCM.LogW(9X);
		CASE format OF
		| form00:
		| form0C:
				PCM.LogWNum(instr.val);
				IF instr.adr # NIL THEN  PCM.LogWStr(" + @")  END
		| form01:
				Reg(instr.src1)
		| form10:
				Reg(pc)
		| form1C:
				Reg(pc); PCM.LogWStr(", "); PCM.LogWNum(instr.val)
		| form1M:
				Reg(pc);  PCM.LogWStr(", ");  Indirect(instr.val, instr.src1)
		| form11:
				Reg(pc); PCM.LogWStr(", "); Reg(instr.src1)
		| formM1:
				Indirect(instr.val, instr.src1);  PCM.LogWStr(", ");  Reg(instr.src2)
		| form02:
				Reg(instr.src1); PCM.LogWStr(", "); Reg(instr.src2)
		| form12:
				Reg(pc); PCM.LogWStr(", "); Reg(instr.src1);
				PCM.LogWStr(", "); Reg(instr.src2)
		| form02C:
				Reg(instr.src1); PCM.LogWStr(", "); Reg(instr.src2);
				PCM.LogWStr(", "); PCM.LogWNum(instr.val)
		| form03:
				Reg(instr.src1); PCM.LogWStr(", "); Reg(instr.src2);
				PCM.LogWStr(", "); Reg(instr.src3)
		| formXX:
			CASE op OF
			| enter, exit:
			| inline:
			| case:
					CaseOpd(instr.src1, instr.src2, instr.src3)
			| casel:
					CaseLineOpd(instr.src1, instr.val)
			| casee:
					CaseElseOpd(instr.src1)
			END
		END;
		PCM.LogWLn;
	END DumpCode;

	(** Emit - Emit the code *)

	PROCEDURE Emit*(code: Code);
		VAR	p: Piece; pos, pc0: SIGNED32; trapped: BOOLEAN; c,piece: SIGNED32;  (* fof *)

		PROCEDURE EmitInstruction(VAR instr: Instruction);
		BEGIN
			IF Statistics THEN
				INC(aTotalInstructions);
				INC(aInstrCount[instr.op]);
				IF instr.suppress THEN
					INC(aSuppressedInstructions);
					INC(aSupprInstrCount[instr.op])
				END
			END;
			IF ~instr.suppress THEN InstructionSet[instr.op].emit(code, instr, pc0) END
		END EmitInstruction;

	BEGIN
		IF Debug THEN trapped := TRUE; c := 0;   END;
		p := code.first; pc0 := 0;
		WHILE p # NIL DO
			pos := 0;
			WHILE pos < p.len DO
				EmitInstruction(p.instr[pos]);
					IF Debug THEN
						KernelLog.Int(pos,0); KernelLog.String(" : "); KernelLog.String(InstructionSet[p.instr[pos].op].name);
						KernelLog.Int(p.instr[pos].dstCount,10);
						KernelLog.Ln;
						INC(c);
					END;
				INC(pos); INC(pc0)
			END;
			p := p.next
		END
		(** fof >> *)
	;IF Debug THEN trapped := FALSE; END;
	FINALLY
		IF Debug THEN
			IF trapped THEN
				KernelLog.String("Compiler trapped while emiting code, here is the code segment"); KernelLog.Ln;
				p := code.first; pc0 := 0; piece:= 0;
				WHILE p # NIL DO
					KernelLog.String("Piece: "); KernelLog.Int(piece,0); KernelLog.Ln; INC(piece);
					pos := 0;
					WHILE pos < p.len DO
						KernelLog.Int(pos,0); KernelLog.String(" : "); KernelLog.String(InstructionSet[p.instr[pos].op].name);
						KernelLog.Int(p.instr[pos].dstCount,10);
						IF c =0 THEN KernelLog.String("(TRAP)"); END;
						DEC(c);
						KernelLog.Ln;
						INC(pos); INC(pc0)
					END;
					p := p.next
				END;
				HALT(100); (* stop from further execution *)
			END;
		END;
	(** << fof  *)
	END Emit;

(* SetMethods - Install the upcall that implement the various opcode related functions *)

	PROCEDURE SetMethods*(op: Opcode;  p: EmitProc);
	BEGIN	InstructionSet[op].emit := p
	END SetMethods;


(** ------------ Default Code Generator ------------- *)
	PROCEDURE CGInit(): BOOLEAN;
	BEGIN RETURN FALSE
	END CGInit;

	PROCEDURE CGDone(VAR res: INTEGER);
	BEGIN res := -1
	END CGDone;

	PROCEDURE CGGetCode(VAR code: CodeArray; VAR codelen, hdrlen, addressFactor: SIGNED32);
	BEGIN code := NIL; codelen := 0; hdrlen := 0; addressFactor := 1
	END CGGetCode;

	PROCEDURE CGDumpCode(code: Code;  VAR instr: Instruction;  pc: SIGNED32;  context: ANY);
	END CGDumpCode;

	PROCEDURE InitDefaultSyscalls*;
	BEGIN
		(*syscalls entry nr *)
		CG.SysCallMap[PCBT.casetable] := 0FFX;
		CG.SysCallMap[PCBT.procaddr] := 0FEX;
		CG.SysCallMap[PCBT.newrec] := 0FDX;
		CG.SysCallMap[PCBT.newsys] := 0FCX;
		CG.SysCallMap[PCBT.newarr] := 0FBX;
		CG.SysCallMap[PCBT.start] := CHR(250);
		CG.SysCallMap[PCBT.passivate] := CHR(249);
		CG.SysCallMap[PCBT.lock] := CHR(247);
		CG.SysCallMap[PCBT.unlock] := CHR(246);
		CG.SysCallMap[PCBT.interfacelookup] := CHR(245);
		CG.SysCallMap[PCBT.registerinterface] := CHR(244);
		CG.SysCallMap[PCBT.getprocedure] := CHR(243);
	END InitDefaultSyscalls;

	PROCEDURE ShowStatistics*;
		VAR i: SIGNED32;
	BEGIN
		FOR i := 0 TO NofOpcodes-1 DO
			KernelLog.String(InstructionSet[i].name);
			KernelLog.Char(9X);
			KernelLog.Int(aInstrCount[i], 8);
			KernelLog.Int(aSupprInstrCount[i], 8);
			KernelLog.Ln
		END
	END ShowStatistics;

PROCEDURE InitModule;

	PROCEDURE NewInstr(op: Opcode;  format: SIGNED8;  name: ARRAY OF CHAR);
	VAR  i: SIGNED32;
	BEGIN
		InstructionSet[op].format := format;
		COPY(name, InstructionSet[op].name);
		i := 0;
		WHILE name[i] # 0X DO
			InstructionSet[op].name[i] := name[i]; INC(i)
		END;
		WHILE i < 7 DO
			InstructionSet[op].name[i] := 20X; INC(i)
		END;
		InstructionSet[op].name[7] := 0X;
	END NewInstr;

BEGIN
	NewInstr(load, form1M, "load");
	NewInstr(loadc, form1C, "loadc");
	NewInstr(store, formM1, "store");
	NewInstr(in, form11, "in   ");
	NewInstr(out, form02, "out  ");
	NewInstr(nop, form00, "nop");
	NewInstr(saveregs, form00, "saveregs");
	NewInstr(loadregs, form00, "loadregs");
	NewInstr(label, form0C, "label");
	NewInstr(finallylabel, form0C, "finlabel");
	NewInstr(je, form02C, "je");
	NewInstr(jne, form02C, "jne");
	NewInstr(jlt, form02C, "jlt");
	NewInstr(jle, form02C, "jle");
	NewInstr(jgt, form02C, "jgt");
	NewInstr(jge, form02C, "jge");
	NewInstr(jb, form02C, "jb");
	NewInstr(jbe, form02C, "jbe");
	NewInstr(ja, form02C, "ja");
	NewInstr(jae, form02C, "jae");
	NewInstr(jf, form02C, "jf");
	NewInstr(jnf, form02C, "jnf");
	NewInstr(jmp, form0C, "jmp");
	NewInstr(call, form0C, "call");
	NewInstr(syscall, form0C, "syscall");
	NewInstr(enter, formXX, "enter");
	NewInstr(exit, formXX, "exit");
	NewInstr(trap, form0C, "trap");
	NewInstr(tae, form02C, "tae");
	NewInstr(tne, form02C, "tne");
	NewInstr(sete, form12, "sete");
	NewInstr(setne, form12, "setne");
	NewInstr(setlt, form12, "setlt");
	NewInstr(setle, form12, "setle");
	NewInstr(setgt, form12, "setgt");
	NewInstr(setge, form12, "setge");
	NewInstr(setb, form12, "setb");
	NewInstr(setbe, form12, "setbe");
	NewInstr(seta, form12, "seta");
	NewInstr(setae, form12, "setae");
	NewInstr(setf, form12, "setf");
	NewInstr(setnf, form12, "setnf");
	NewInstr(result, form10, "result");
	NewInstr(result2, form10, "result2");
	NewInstr(pop, form10, "pop");
	NewInstr(ret, form01, "ret");
	NewInstr(ret2, form01, "ret2");
	NewInstr(push, form01, "push");
	NewInstr(callreg, form01, "callreg");
	NewInstr(kill, form01, "kill");
	NewInstr(loadsp, form01, "loadsp");
	NewInstr(loadfp, form01, "loadfp");
	NewInstr(convs, form11, "convs");
	NewInstr(convu, form11, "convu");
	NewInstr(copy, form11, "copy");
	NewInstr(not, form11, "not");
	NewInstr(neg, form11, "neg");
	NewInstr(abs, form11, "abs");
	NewInstr(mul, form12, "mul");
	NewInstr(div, form12, "div");
	NewInstr(mod, form12, "mod");
	NewInstr(sub, form12, "sub");
	NewInstr(add, form12, "add");
	NewInstr(and, form12, "and");
	NewInstr(or, form12, "or");
	NewInstr(xor, form12, "xor");
	NewInstr(bts, form12, "bts");
	NewInstr(btc, form12, "btc");
	NewInstr(ash, form12, "ash");
	NewInstr(bsh, form12, "bsh");
	NewInstr(rot, form12, "rot");
	NewInstr(phi, form12, "phi");
	NewInstr(move, form03, "move");
	NewInstr(moveDown, form03, "moveDown");
	NewInstr(inline, formXX, "inline");
	NewInstr(case, formXX, "case");
	NewInstr(casel, formXX, "casel");
	NewInstr(casee, formXX, "casee");

	InstructionSet[call].flags := {barrier};	(*code optimization should not go past a call*)
	InstructionSet[callreg].flags := {barrier};
	InstructionSet[syscall].flags := {barrier};
	InstructionSet[mul].flags := {commutative};
	InstructionSet[add].flags := {commutative};
	InstructionSet[and].flags := {commutative};
	InstructionSet[or].flags := {commutative};
	InstructionSet[xor].flags := {commutative};
	InstructionSet[je].flags := {commutative};
	InstructionSet[jne].flags := {commutative};

	RegName[Int8] := "B";
	RegName[Int16] := "W";
	RegName[Int32] := "D";
	RegName[Int64] := "Q";
	RegName[Float32] := "F";
	RegName[Float64] := "G";
(*
	Texts.OpenWriter(W);
	Texts.SetFont(W, Fonts.This("Courier10.Scn.Fnt"));
*)
	InstructionInit := NIL;
	CG.Init := CGInit;
	CG.Done := CGDone;
	CG.GetCode := CGGetCode;
	CG.DumpCode := CGDumpCode;
	IF Statistics THEN PCM.LogWLn; PCM.LogWStr("PCLIR.Statistics on") END
END InitModule;

BEGIN
	Address := Int32;
	Set := Int32;
	InitModule
END PCLIR.

(*
	20.09.03	prk	"/Dcode" compiler option added
	06.04.03	prk	LIR code trace output  adapted to new output model
	20.02.02	be	refinement in the code generator plugin
	02.04.02	prk	statistics
	20.02.02	be	refinement in the code generator plugin
	06.08.01    prk	Instruction: dst record removed, fields declared directly in instruction
	29.05.01    be	syscall structures moved to backend (PCLIR & code generators)
	14.05.01	prk	PCLIR.lea removed
	11.05.01	prk	correct handling of operation with hw-regs; PCLIR.loadsp instruction; PCC stack ops fixed
	07.05.01	prk	Installable code generators moved to PCLIR; debug function added
	07.05.01	be	register sign information added in the back-end
	26.04.01	prk	separation of RECORD and OBJECT in the parser
	26.04.01	prk	PCLIR.lea partly removed
	28.03.01	prk	Cleanup interface
	15.03.01	prk	calldel removed
	15.03.01	prk	ret2, result2 added
	22.02.01	prk	delegates
	23.02.01	prk	TraverseProc: context added
*)