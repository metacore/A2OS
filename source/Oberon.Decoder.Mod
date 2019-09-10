(* ETH Oberon, Copyright 2001 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

MODULE Decoder IN Oberon;	(** non-portable *) (* NM 2.3.93 / 26.10.93 *)

(* Niklaus Mannhart, Patrik Reali, Pieter Muller, Bernhard Egger *)

	IMPORT SYSTEM, Modules, Files, Fonts, Texts, Objects, Display, Oberon, Strings, Out;

	CONST
		(* prefix *)
		pCS = 2EH; pDS = 3EH; pES = 26H; pFS = 64H; pGS = 65H; pSS = 36H;
		AdrSize = 67H; OpSize = 66H; none = -1;

		(* output *)
		PCpos = 0; HexPos = 7; OpPosC = 43; RMPosC = 52; Pos1 = 4;
		OffPos = 35;

		(* addressing modes *)
		Reg = 0; (* Register *)
		Mem1 = 1; (* addressing mode 1 *)
		Mem2 = 2; (* addressing mode 2 *)
		RegImm = 3; (* immediate to register *)
		MemImm = 4; (* memory to register *)
		MemFull = 5; (* full 32 bit adr *)

		(* i386 Register *)
		EAX = 0; ECX = 1; EDX = 2; EBX = 3; ESP = 4; EBP = 5; ESI = 6; EDI = 7; (* 32 bit register *)
		AX = 0; CX = 1; DX = 2; BX = 3; SP =  4; BP = 5; SI = 6; DI = 7; (* 16 bit register *)
		AL = 0; CL = 1; DL = 2; BL = 3; AH = 4; CH = 5; DH = 6; BH = 7; (* 8 bit register *)
		ES = 20; CS = 21; SS = 22; DS = 23; FS = 24; GS = 25;  (* 6, 7 reserved *) (* Segment register *)
		CR = 0; DR = 8; TR = 16;

		(* i387 *)
		SReal = 0; (* single real 32 bit*)
		LReal = 1; (* long real 64 bit *)
		EReal = 2; (* extended real 80 bit *)
		WInt = 3; (* word integer 16 bit *)
		SInt = 4; (* single integer 32 bit *)
		LInt = 5; (* long integer 64 bit *)
		Byte14 = 6; Byte28 = 7; Byte94 = 8; Byte108 = 9;
		Decimal = 10; (* BCD *)
		nothing = 11;

		(* size *)
		Byte = 0; SignExt = 1; (* sign extended *)

		BUG = 40;

		(* String constants, define only once to avoid err 230 *)
		VarEntriesStr = "VarEntries:";
		EntriesStr = "Entries:";
		CommandsStr = "Commands:";
		PointersStr = "Pointers:";
		DataStr = "Data:";
		ConstStr = "Const:     ";
		CodeStr = "Code:     ";
		nofEntriesStr = "  nofEntries:      ";
		nofCmdsStr = "  nofCmds:         ";
		nofPtrsStr = "  nofPtrs:         ";
		nofTypesStr = "  nofTds:          ";
		nofImpsStr = "  nofImps:         ";
		dataSizeStr = "  dataSize:        ";
		constSizeStr = "  conSize:         ";
		codeSizeStr = "  codeSize:        ";
		refSizeStr = "  refSize:         ";
		exTableSizeStr ="  exTableSize:      ";


		(*Targets*)
		Priv = 16;
		i486 = 1; Pentium = 2; PPro = 3;

	TYPE
		ProcEntry* = RECORD
			name*: ARRAY 64 OF CHAR;
			point*: SIGNED32
		END;
		ProcArray* = POINTER TO ARRAY OF ProcEntry;
		EntryArray = POINTER TO ARRAY OF SIGNED32;
		DecodeHandler* = PROCEDURE(VAR pc: SIGNED32; VAR r: Files.Rider; VAR w: Texts.Writer);
		HeaderCallback* = PROCEDURE(VAR dataSize, constSize, codeSize: SIGNED32);

	VAR
		R: Files.Rider; (* Rider for Object file *)
		W: Texts.Writer; (* Writer for output on screen *)
		pc, breakpos: SIGNED32; column: SIGNED16; (* cursor position in the current line *)
		prefix, w: SIGNED16; adrPrefix, opPrefix: BOOLEAN;
		defaultFont, titleFont: Fonts.Font;
		PE*: ProcArray;
		nofPE*: SIGNED32;
		memory, compilable, raw, suppressOut, suppressH, noOutput: BOOLEAN;
		ReadAdr: ADDRESS;
		target: SET;
		objSuffix: ARRAY 8 OF CHAR;
		OpPos, RMPos: SIGNED8;
		decoder: DecodeHandler;
		headerCallback: HeaderCallback;
		addressFactor: SIGNED32;

(* general Procedures *)

	PROCEDURE Bug (no: SIGNED16);
	BEGIN
		WriteLn;  WriteString("*** decode error ***"); WriteLn
	END Bug;

	PROCEDURE Next (VAR ch: CHAR);
	BEGIN
		INC(pc);
		IF memory THEN SYSTEM.GET (ReadAdr, ch); INC (ReadAdr)
		ELSE Files.Read(R, ch)
		END;
		(* IF pc = breakpos THEN Texts.SetFont(W, Fonts.This("Syntax12b.Scn.Fnt"))
		ELSE Texts.SetFont(W, defaultFont)
		END *)
	END Next;

	PROCEDURE GetByte (VAR b: SIGNED16);
		VAR ch: CHAR;
	BEGIN
		Next(ch);
		b:= ORD(ch)
	END GetByte;

	PROCEDURE GetWord (VAR w: SIGNED32);
		VAR ch: CHAR;
	BEGIN
		Next(ch); w:= ORD(ch);
		Next(ch);  w:= LONG(ORD(ch)) * 100H + w
	END GetWord;

	PROCEDURE GetDWord (VAR dw: SIGNED32);
		VAR ch: CHAR; byte: SIGNED16;
	BEGIN
		Next(ch); dw:= LONG(ORD(ch));
		Next(ch); dw:= LONG(ORD(ch)) * 100H + dw;
		Next(ch); dw:= LONG(ORD(ch)) * 10000H + dw;
		GetByte(byte);
		IF byte >= 128 THEN byte:= byte - 256 END;
		dw:= LONG(byte) * 1000000H + dw
	END GetDWord;

	PROCEDURE GetNum (VAR x: SIGNED32);
		VAR ch: CHAR; n: SIGNED16; y: SIGNED32;
	BEGIN n := 0; y := 0; Next (ch);
		WHILE ch >= 80X DO INC(y, LSH(LONG(ORD(ch)) - 128, n)); INC(n, 7); Next (ch) END;
		x := ASH(LSH(LONG(ORD(ch)), 25), n-25) + y
	END GetNum;

	PROCEDURE WriteLn;
	BEGIN
		IF ~suppressOut THEN Texts.WriteLn(W) END;
		column:= 0
	END WriteLn;

	PROCEDURE WriteString (str: ARRAY OF CHAR);
	BEGIN
		IF ~suppressOut THEN	Texts.WriteString(W, str); column:= column + SIGNED16(LEN(str))	END
	END WriteString;

	PROCEDURE Write (ch: CHAR);
	BEGIN
		IF ~suppressOut THEN	Texts.Write(W, ch); INC(column)	END
	END Write;

	PROCEDURE WriteInt (x: SIGNED32);
	BEGIN
		IF ~suppressOut THEN	Texts.WriteInt(W, x, 10); INC(column, 10)	END
	END WriteInt;

	PROCEDURE WriteByte (byte: SIGNED16);
	(* write byte in hexadecimal form *)

		PROCEDURE WriteHex(d: SIGNED16);
		BEGIN
			IF d > 9 THEN Write(CHR(41H + d - 10))
			ELSE Write(CHR(30H + d))
			END
		END WriteHex;

	BEGIN (* WriteByte *)
		WriteHex(byte DIV 16); WriteHex(byte MOD 16);
		IF (~suppressH) & (column >= OpPos) THEN Write("H") END
	END WriteByte;

	PROCEDURE WriteWord (word: SIGNED32);
	(* write word in byte form, little endian notation *)
	BEGIN
		WriteByte(SHORT(word MOD 100H)); Write(" ");
		WriteByte(SHORT(word DIV 100H) MOD 100H)
	END WriteWord;

	PROCEDURE WriteDWord (dword: SIGNED32);
	(* write dword in byte form, little endian notation *)
	BEGIN
		WriteWord(dword MOD 10000H); Write(" ");
		WriteWord((dword DIV 10000H) MOD 10000H)
	END WriteDWord;

	PROCEDURE WriteWHex (word: SIGNED32);
	(* write word hexadecimal *)
		VAR b: BOOLEAN;
	BEGIN
		b := suppressH; suppressH := TRUE;
		WriteByte(SHORT(word DIV 100H)); WriteByte(SHORT(word MOD 100H));
		IF ~b & (column >= OpPos) THEN Write("H") END;
		suppressH := b;
	END WriteWHex;

	PROCEDURE WriteDWHex (dword: SIGNED32);
		VAR b: BOOLEAN;
	BEGIN
		b := suppressH; suppressH := TRUE;
		WriteWHex(dword DIV 10000H MOD 10000H); WriteWHex(dword MOD 10000H);
		IF ~b & (column >= OpPos) THEN Write("H") END;
		suppressH := b;
	END WriteDWHex;

	PROCEDURE WriteDisp (disp: SIGNED32);
	BEGIN
		IF ~suppressOut THEN
			Texts.WriteInt(W, disp, 1);
			IF disp = MIN(SIGNED32) THEN INC(column, 12)	(* " -2147483648" *)
			ELSE
				IF disp <= 0 THEN INC(column) END;
				disp:= ABS(disp);
				WHILE disp # 0 DO
					disp:= disp DIV 10;
					INC(column)
				END
			END
		END
	END WriteDisp;

	PROCEDURE Tab (pos: SIGNED16);
	BEGIN
		IF ~suppressOut THEN
			WHILE column < pos DO Write(" ") END
		END
	END Tab;

	PROCEDURE WriteOp (opStr: ARRAY OF CHAR);
	BEGIN
		suppressOut := noOutput;
		Tab(OpPos); WriteString(opStr); Tab(RMPos)
	END WriteOp;

	PROCEDURE WriteReg (reg: SIGNED16);
	(* w = 0: 8 bit; w = 1: 16/32 bit *)
	BEGIN
		IF reg >= ES (*DS*) THEN 					(*  <<<< MH 15.3.1994 *)
			IF reg = CS THEN WriteString("CS")
			ELSIF reg = DS THEN WriteString("DS")
			ELSIF reg = ES THEN WriteString("ES")
			ELSIF reg = SS THEN WriteString("SS")
			ELSIF reg = FS THEN WriteString("FS")
			ELSIF reg = GS THEN WriteString("GS")
			ELSE Bug(BUG)
			END
		ELSIF w = 0 THEN
			IF reg = 0 THEN WriteString("AL")
			ELSIF reg = 1 THEN WriteString("CL")
			ELSIF reg = 2 THEN WriteString("DL")
			ELSIF reg = 3 THEN WriteString("BL")
			ELSIF reg = 4 THEN WriteString("AH")
			ELSIF reg = 5 THEN WriteString("CH")
			ELSIF reg = 6 THEN WriteString("DH")
			ELSIF reg = 7 THEN WriteString("BH")
			ELSE Bug(BUG)
			END
		ELSIF opPrefix THEN
			IF reg = 0 THEN WriteString("AX")
			ELSIF reg = 1 THEN WriteString("CX")
			ELSIF reg = 2 THEN WriteString("DX")
			ELSIF reg = 3 THEN WriteString("BX")
			ELSIF reg = 4 THEN WriteString("SP")
			ELSIF reg = 5 THEN WriteString("BP")
			ELSIF reg = 6 THEN WriteString("SI")
			ELSIF reg = 7 THEN WriteString("DI")
			ELSE Bug(BUG)
			END
		ELSE
			IF reg = 0 THEN WriteString("EAX")
			ELSIF reg = 1 THEN WriteString("ECX")
			ELSIF reg = 2 THEN WriteString("EDX")
			ELSIF reg = 3 THEN WriteString("EBX")
			ELSIF reg = 4 THEN WriteString("ESP")
			ELSIF reg = 5 THEN WriteString("EBP")
			ELSIF reg = 6 THEN WriteString("ESI")
			ELSIF reg = 7 THEN WriteString("EDI")
			ELSE Bug(BUG)
			END
		END
	END WriteReg;

	PROCEDURE WriteAdrReg(reg: SIGNED16);
	BEGIN
		IF adrPrefix THEN
			IF reg = 0 THEN WriteString("AX")
			ELSIF reg = 1 THEN WriteString("CX")
			ELSIF reg = 2 THEN WriteString("DX")
			ELSIF reg = 3 THEN WriteString("BX")
			ELSIF reg = 4 THEN WriteString("SP")
			ELSIF reg = 5 THEN WriteString("BP")
			ELSIF reg = 6 THEN WriteString("SI")
			ELSIF reg = 7 THEN WriteString("DI")
			ELSE Bug(BUG)
			END
		ELSE
			IF reg = 0 THEN WriteString("EAX")
			ELSIF reg = 1 THEN WriteString("ECX")
			ELSIF reg = 2 THEN WriteString("EDX")
			ELSIF reg = 3 THEN WriteString("EBX")
			ELSIF reg = 4 THEN WriteString("ESP")
			ELSIF reg = 5 THEN WriteString("EBP")
			ELSIF reg = 6 THEN WriteString("ESI")
			ELSIF reg = 7 THEN WriteString("EDI")
			ELSE Bug(BUG)
			END
		END
	END WriteAdrReg;

	PROCEDURE WriteSpecialReg(reg: SIGNED16);
	BEGIN
		IF reg >= TR THEN
			WriteString("TR"); Write(CHR( reg-TR + ORD("0")))
		ELSIF reg >= DR THEN
			WriteString("DR"); Write(CHR( reg-DR + ORD("0")))
		ELSE
			WriteString("CR"); Write(CHR( reg-CR + ORD("0")))
		END;
		INCL(target, Priv)
	END WriteSpecialReg;

	PROCEDURE WritePrefix (prefix: SIGNED16);
	BEGIN
		IF prefix = pCS THEN WriteString("CS:")
		ELSIF prefix = pDS THEN WriteString("DS: ")
		ELSIF prefix = pES THEN WriteString("ES: ")
		ELSIF prefix = pFS THEN WriteString("FS: ")
		ELSIF prefix = pGS THEN WriteString("GS: ")
		ELSIF prefix = pSS THEN WriteString("SS: ")
		ELSE
		END
	END WritePrefix;

	PROCEDURE WriteRegReg (d, reg1, reg2: SIGNED16);
	BEGIN
		IF d = 1 THEN
			WriteReg(reg1); Write(","); WriteReg(reg2)
		ELSE
			WriteReg(reg2); Write(","); WriteReg(reg1)
		END
	END WriteRegReg;

	PROCEDURE WriteMem (base, inx, scale: SIGNED16; disp: SIGNED32);
	BEGIN
		WritePrefix(prefix);
		IF base # none THEN(* register relative *)
			WriteDisp(disp);
			Write("["); WriteAdrReg(base)
		ELSE (* absolute *)
			Write("["); WriteDisp(disp)
		END;
		IF (inx # none) & ~((inx = ESP) & (base = ESP))(* !! 15.4.93 Bug? & (base # ESP) *) THEN (* indexed *)
			WriteString(" + "); WriteAdrReg(inx);
			IF scale = 0 THEN WriteString(" * 1")
			ELSIF scale = 1 THEN WriteString(" * 2")
			ELSIF scale = 2 THEN WriteString(" * 4")
			ELSE WriteString(" *  8")
			END;
		END;
		Write("]")
	END WriteMem;

	PROCEDURE WriteMem1 (d, reg, base: SIGNED16; disp: SIGNED32);
	(* d = TRUE: reg, mem ; d = FALSE: mem, reg *)
	BEGIN
		IF d = 1 THEN
			WriteReg(reg); Write(",")
		END;
		WriteMem(base, none, 0, disp);
		IF d = 0 THEN
			Write(","); WriteReg(reg)
		END
	END WriteMem1;

	PROCEDURE WriteMem2 (d, reg, base, inx: SIGNED16; scale: SIGNED8; disp: SIGNED32);
	(* d = TRUE: reg, mem; d= FALSE: mem, reg *)
	BEGIN
		IF d = 1 THEN
			WriteReg(reg); Write(",")
		END;
		WriteMem(base, inx, scale, disp);
		IF d = 0 THEN
			Write(","); WriteReg(reg)
		END
	END WriteMem2;

	PROCEDURE WriteRegImm (reg: SIGNED16; imm: SIGNED32; hex: BOOLEAN);
	BEGIN
		WriteReg(reg); Write(",");
		IF hex THEN WriteDWHex(imm) ELSE WriteDisp(imm) END
	END WriteRegImm;

	PROCEDURE WriteMemImm (reg, base, inx: SIGNED16; scale: SIGNED8; disp, imm: SIGNED32; hex: BOOLEAN);
	BEGIN
		WritePrefix(prefix);
		WriteMem(base, inx, scale, disp);
		Write(",");
		IF hex THEN WriteDWHex(imm) ELSE WriteDisp(imm) END
	END WriteMemImm;

	PROCEDURE WriteRM (mode: SIGNED8; d, reg, base, inx, scale: SIGNED16; disp, imm: SIGNED32; hex: BOOLEAN);
	BEGIN
		CASE mode OF
			RegImm:
				WriteRegImm(reg, imm, hex)
		  | MemImm:
				WriteMemImm(reg, base, inx, SHORT(scale), disp, imm, hex)
		  | Reg:
				WriteRegReg(d, reg, base)
		  | Mem1:
				WriteMem1(d, reg, base, disp)
		  | Mem2:
				WriteMem2(d, reg, base, inx, SHORT(scale), disp)
		  | MemFull:
				IF d = 1 THEN
					WriteReg(reg); Write(",")
				END;
				Write("["); WriteDisp(disp); Write("]");
				IF d = 0 THEN
					Write(","); WriteReg(reg)
				END
		ELSE Bug(BUG)
		END
	END WriteRM;

(* Decode part *)

	PROCEDURE GetImm (w: SIGNED16; VAR imm: SIGNED32);
		VAR byte: SIGNED16;
	BEGIN
		IF w = 0 THEN (* 8 bit *)
			GetByte(byte); WriteByte(byte); Write(" ");
			IF  byte >= 128 THEN byte:= byte - 256 END;
			imm:= byte
		ELSIF opPrefix THEN (* 16 bit *)
			GetWord(imm); WriteWord(imm); Write(" ");
			IF imm >= 32768 THEN imm:= imm - 65536 END
		ELSE (* 32 bit *)
			GetDWord(imm); WriteDWord(imm); Write(" ")
		END
	END GetImm;

	PROCEDURE ModRm (VAR mode: SIGNED8; VAR reg, base, inx: SIGNED16; VAR scale: SIGNED8; VAR disp: SIGNED32);
		VAR mod, byte: SIGNED16;
	BEGIN
		GetByte(byte); WriteByte(byte); Write(" ");
		mod:= byte DIV 40H;
		reg:=(byte DIV 8) MOD 8;
		base:= byte MOD 8;
		IF mod = 3 THEN (* reg *)
			mode:= Reg; inx:= none
		ELSE
			IF base = 4 THEN (* escape to two bytes *)
				mode:= Mem2;
				GetByte(byte);
				WriteByte(byte); Write(" ");
				scale:= SHORT(byte DIV 40H);
				inx:= (byte DIV 8) MOD 8;
				base:= byte MOD 8
			ELSE (* one byte addressing mode *)
				mode:= Mem1; inx:= none
			END;
			IF mod = 0 THEN (* no displ, or 32 bit address *)
				IF base = 5 THEN (* disp32 *)
					base:= none;
					GetDWord(disp);
					WriteDWord(disp); Write(" ")
				ELSE disp:= 0
				END
			ELSIF mod = 1 THEN (* 8 bit displ *)
				GetImm(0, disp)
			ELSE (* 32 bit displacement *)
				GetDWord(disp);
				WriteDWord(disp); Write(" ")
			END
		END
	END ModRm;

	PROCEDURE Type1 (op: SIGNED16; VAR mode: SIGNED8; VAR d, reg, base, inx: SIGNED16;
								VAR scale: SIGNED8; VAR disp, imm: SIGNED32);
	(* type 1: add, or, adc, sbb, and, sub, xor, cmp *)
	BEGIN
		IF op = 4 THEN
			mode:= RegImm; w:= 0; reg:= AL; GetImm(0, imm)
		ELSIF op = 5 THEN
			mode:= RegImm; w:= 1; reg:= AX; GetImm(1, imm)
		ELSE
			CASE op OF
				0: w:= 0; d:= 0
			  | 1: w:= 1; d:= 0
			  | 2: w:= 0; d:= 1
			  | 3: w:= 1; d:= 1
			ELSE Bug(BUG)
			END;
			ModRm(mode, reg, base, inx, scale, disp)
		END
	END Type1;

	PROCEDURE Add (op: SIGNED16);
		VAR reg, base, inx, d: SIGNED16; scale, mode: SIGNED8; disp, imm: SIGNED32;
	BEGIN
		Type1(op, mode, d, reg, base, inx, scale, disp, imm);
		WriteOp("ADD");
		WriteRM(mode, d, reg, base, inx, scale, disp, imm, FALSE)
	END Add;

	PROCEDURE Push (op: SIGNED16);
		VAR imm: SIGNED32;
	BEGIN
		w:= 1;
		IF op = 60H THEN
			IF opPrefix THEN WriteOp("PUSHA") ELSE WriteOp("PUSHAD") END;
		ELSIF op = 68H THEN
			IF opPrefix THEN
				GetWord(imm); WriteWord(imm)
			ELSE
				GetDWord(imm); WriteDWord(imm)
			END;
			WriteOp("PUSH"); WriteDisp(imm)
		ELSIF op = 6AH THEN
			GetImm(0, imm);
			WriteOp("PUSH"); WriteDisp(imm)
		ELSIF op = 9CH THEN
			IF opPrefix THEN WriteOp("PUSHF") ELSE WriteOp("PUSHFD") END;
		ELSE
			WriteOp("PUSH");
			CASE op OF
				6: WriteReg(ES)
			  | 0EH: WriteReg(CS)
			  | 16H: WriteReg(SS)
			  | 1EH: WriteReg(DS)
			  | 50H..57H: WriteReg(op - 50H)
			ELSE Bug(BUG)
			END
		END
	END Push;

	PROCEDURE Push2 (op: SIGNED16);
	END Push2;

	PROCEDURE Pop(op: SIGNED16);
		VAR reg, base, inx: SIGNED16; scale, mode: SIGNED8; disp: SIGNED32;
	BEGIN
		IF op = 61H THEN
			IF opPrefix THEN WriteOp("POPA") ELSE WriteOp("POPAD") END;
		ELSIF op = 8FH THEN
			ModRm(mode, reg, base, inx, scale, disp);
			WriteOp("POP");
			IF opPrefix THEN WriteString("WORD PTR ")
			ELSE WriteString("DWORD PTR ")
			END;
			WriteMem(base, inx, scale, disp)
		ELSIF op = 9DH THEN
			IF opPrefix THEN WriteOp("POPF") ELSE WriteOp("POPFD") END;
		ELSE
			WriteOp("POP");
			w := 1;	(* pop takes only 16 or 32 bit ops *)
			CASE op OF
				7: WriteReg(ES)
			  | 17H: WriteReg(SS)
			  | 1FH: WriteReg(DS)
			  | 58H..5FH: WriteReg(op - 58H)
			 ELSE Bug(BUG)
			 END
		END
	END Pop;

	PROCEDURE Pop2 (op: SIGNED16);
	END Pop2;

	PROCEDURE Or (op: SIGNED16);
		VAR reg, base, inx, d: SIGNED16; scale, mode: SIGNED8; disp, imm: SIGNED32;
	BEGIN
		Type1(op - 08H, mode, d, reg, base, inx, scale, disp, imm);
		WriteOp("OR");
		WriteRM(mode, d, reg, base, inx, scale, disp, imm, TRUE)
	END Or;

	PROCEDURE Adc (op: SIGNED16);
		VAR reg, base, inx, d: SIGNED16; scale, mode: SIGNED8; disp, imm: SIGNED32;
	BEGIN
		Type1(op -10H, mode, d, reg, base, inx, scale, disp, imm);
		WriteOp("ADC");
		WriteRM(mode, d, reg, base, inx, scale, disp, imm, FALSE)
	END Adc;

	PROCEDURE Sbb (op: SIGNED16);
		VAR reg, base, inx, d: SIGNED16; scale, mode: SIGNED8; disp, imm: SIGNED32;
	BEGIN
		Type1(op - 18H, mode, d, reg, base, inx, scale, disp, imm);
		WriteOp("SBB");
		WriteRM(mode, d, reg, base, inx, scale, disp, imm, FALSE)
	END Sbb;

	PROCEDURE  And (op: SIGNED16);
		VAR reg, base, inx, d: SIGNED16; scale, mode: SIGNED8; disp, imm: SIGNED32;
	BEGIN
		Type1(op - 20H, mode, d, reg, base, inx, scale, disp, imm);
		WriteOp("AND");
		WriteRM(mode, d, reg, base, inx, scale, disp, imm, TRUE)
	END And;

	PROCEDURE Sub (op: SIGNED16);
		VAR reg, base, inx, d: SIGNED16; scale, mode: SIGNED8; disp, imm: SIGNED32;
	BEGIN
		Type1(op - 28H, mode, d, reg, base, inx, scale, disp, imm);
		WriteOp("SUB");
		WriteRM(mode, d, reg, base, inx, scale, disp, imm, FALSE)
	END Sub;

	PROCEDURE Xor (op: SIGNED16);
		VAR reg, base, inx, d: SIGNED16; scale, mode: SIGNED8; disp, imm: SIGNED32;
	BEGIN
		Type1(op - 30H, mode, d, reg, base, inx, scale, disp, imm);
		WriteOp("XOR");
		WriteRM(mode, d, reg, base, inx, scale, disp, imm, TRUE)
	END Xor;

	PROCEDURE Cmp (op: SIGNED16);
		VAR reg, base, inx, d: SIGNED16; scale, mode: SIGNED8; disp, imm: SIGNED32;
	BEGIN
		Type1(op - 38H, mode, d, reg, base, inx, scale, disp, imm);
		WriteOp("CMP");
		WriteRM(mode, d, reg, base, inx, scale, disp, imm, FALSE)
	END Cmp ;

	PROCEDURE Inc (op: SIGNED16);
	BEGIN
		WriteOp("INC"); w := 1;		(* set width to 16/32 bits, bug2 *)
		WriteReg(op - 40H)
	END Inc;

	PROCEDURE Dec (op: SIGNED16);
	BEGIN
		WriteOp("DEC"); w := 1;
		WriteReg(op - 48H)
	END Dec;

	PROCEDURE Bound (op: SIGNED16);
		VAR reg, base, inx: SIGNED16; scale, mode: SIGNED8; disp: SIGNED32;
	BEGIN
		w:= 1;
		ModRm(mode, reg, base, inx, scale, disp);
		WriteOp("BOUND");
		WriteRM(mode, 1, reg, base, inx, scale, disp, 0, FALSE)
	END Bound;

	PROCEDURE Imul (op: SIGNED16);
		VAR reg, base, inx: SIGNED16; scale, mode: SIGNED8; disp, imm: SIGNED32;
	BEGIN
		ModRm(mode, reg, base, inx, scale, disp);
		w:= 1;
		IF op = 69H THEN GetImm(1, imm)
		ELSIF op = 6BH THEN GetImm(0, imm) (* sign extended *)
		END;
		WriteOp("IMUL");
		WriteRM(mode, 1, reg, base, inx, scale, disp, 0, FALSE);
		Write(","); WriteDisp(imm)
	END Imul;

	PROCEDURE Imul2 (op: SIGNED16);
		VAR reg, base, inx: SIGNED16; scale, mode: SIGNED8; disp: SIGNED32;
	BEGIN
		w:= 1;
		ModRm(mode, reg, base, inx, scale, disp);
		WriteOp("IMUL");
		WriteRM(mode, 1, reg, base, inx, scale, disp, 0, FALSE)
	END Imul2;

	PROCEDURE Ins (op: SIGNED16);
	BEGIN
		IF op =  6CH THEN WriteOp("INSB")
		ELSIF opPrefix THEN WriteOp("INSW")
		ELSE WriteOp("INSD")
		END
	END Ins;

	PROCEDURE Outs (op: SIGNED16);
	BEGIN
		IF op = 6EH THEN WriteOp("OUTSB")
		ELSIF opPrefix THEN WriteOp("OUTSW")
		ELSE WriteOp("OUTSD")
		END
	END Outs;

	PROCEDURE Jcc (op: SIGNED16);
		VAR disp: SIGNED16;
	BEGIN
		GetByte(disp); WriteByte(disp);
		IF disp >= 128 THEN disp:= disp - 256 END;
		CASE op OF
			70H: WriteOp("JO")
		  | 71H: WriteOp("JNO")
		  | 72H: WriteOp("JB")
		  | 73H: WriteOp("JNB")
		  | 74H: WriteOp("JZ")
		  | 75H: WriteOp("JNZ")
		  | 76H: WriteOp("JBE")
		  | 77H: WriteOp("JNBE")
		  | 78H: WriteOp("JS")
		  | 79H: WriteOp("JNS")
		  | 7AH: WriteOp("JP")
		  | 7BH: WriteOp("JNP")
		  | 7CH: WriteOp("JL")
		  | 7DH: WriteOp("JNL")
		  | 7EH: WriteOp("JLE")
		  | 7FH: WriteOp("JNLE")
		ELSE Bug(BUG)
		END;
		WriteDisp(disp); WriteString("  ("); (*Texts.*)WriteDWHex(pc + disp); Write(")")
	END Jcc;

	PROCEDURE Jcc2 (op: SIGNED16);
		VAR disp: SIGNED32;
	BEGIN
		IF adrPrefix THEN
			GetWord(disp); WriteWord(disp)
		ELSE
			GetDWord(disp); WriteDWord(disp)
		END;
		CASE op OF
			80H: WriteOp("JO")
		  | 81H: WriteOp("JNO")
		  | 82H: WriteOp("JB")
		  | 83H: WriteOp("JNB")
		  | 84H: WriteOp("JZ")
		  | 85H: WriteOp("JNZ")
		  | 86H: WriteOp("JBE")
		  | 87H: WriteOp("JNBE")
		  | 88H: WriteOp("JS")
		  | 89H: WriteOp("JNS")
		  | 8AH: WriteOp("JP")
		  | 8BH: WriteOp("JNP")
		  | 8CH: WriteOp("JL")
		  | 8DH: WriteOp("JNL")
		  | 8EH: WriteOp("JLE")
		  | 8FH: WriteOp("JNLE")
		ELSE Bug(BUG)
		END;
		WriteDisp(disp); WriteString("  ("); (*Texts.*)WriteDWHex(pc + disp); Write(")")
	END Jcc2;

	PROCEDURE Test (op: SIGNED16);
		VAR reg, base, inx: SIGNED16; scale, mode: SIGNED8; disp, imm: SIGNED32;
	BEGIN
		IF (op = 0A8H) OR (op = 0A9H) THEN
			IF op = 0A8H THEN
				w:= 0; reg:= AL
			ELSE
				w:= 1; reg:= AX
			END;
			GetImm(w, imm);
			mode:= RegImm
		ELSE
			ModRm(mode, reg, base, inx, scale, disp);
			IF op = 84H THEN w:= 0
			ELSE w:= 1
			END
		END;
		WriteOp("TEST");
		WriteRM(mode, 0, reg, base, inx, scale, disp, imm, FALSE)			(* bug1 *)
	END Test;

	PROCEDURE Xchg (op: SIGNED16);
		VAR reg, base, inx: SIGNED16; scale, mode: SIGNED8; disp: SIGNED32;
	BEGIN
		IF (op >= 91H) & (op <= 97H) THEN (* xchg .ax, reg *)
			w:= 1; reg:= AX; base:= op MOD 8;
			mode:= Reg
		ELSE
			ModRm(mode, reg, base, inx, scale, disp);
			IF op = 86H THEN w:= 0
			ELSE w:= 1
			END
		END;
		WriteOp("XCHG");
		WriteRM(mode, 1, reg, base, inx, scale, disp, 0, FALSE)
	END Xchg;

	PROCEDURE Mov (op: SIGNED16);
		VAR reg, base, inx, d: SIGNED16; scale, mode: SIGNED8; disp, imm: SIGNED32;
	BEGIN
		IF (op >= 88H) & (op <= 8BH) THEN
			Type1(op - 88H, mode, d, reg, base, inx, scale, disp, imm)
		ELSIF (op >= 0B0H) & (op <= 0B7H) THEN
			mode:= RegImm; w:= 0; reg:= op - 0B0H; GetImm(w, imm)
		ELSIF (op >= 0B8H) & (op <= 0BFH) THEN
			mode:= RegImm; w:= 1; reg:= op - 0B8H; GetImm(w, imm)
		ELSIF (op >= 0A0H) & (op <= 0A3H) THEN
			CASE op OF
				0A0H: w:= 0; d:= 1; reg:= AL
			  | 0A1H: w:= 1; d:= 1; reg:= AX
			  | 0A2H: w:= 0; d:= 0; reg:= AL
			  | 0A3H: w:= 1; d:= 0; reg:= AX
			END;
			mode:= MemFull;
			IF adrPrefix THEN
				GetWord(disp); WriteWord(disp)
			ELSE
				GetDWord(disp); WriteDWord(disp)
			END
		ELSIF op = 8CH THEN (* mov mem, seg *)
			w:= 1; d:= 0; opPrefix:= TRUE;
			ModRm(mode, reg, base, inx, scale, disp);
			reg:= reg + ES (* reg is a segment register *)
		ELSIF op = 8EH THEN (* mov seg, mem *)
			w:= 1; d:= 1; opPrefix:= TRUE;
			ModRm(mode, reg, base, inx, scale, disp);
			reg:= reg + ES (* reg is segment register *)
		ELSIF (op = 0C6H) OR (op = 0C7H) THEN
			d:= 1;
			IF op = 0C6H THEN w:= 0
			ELSE w:= 1
			END;
			ModRm(mode, reg, base, inx, scale, disp);
			IF mode = Reg THEN
				reg:= base; mode:= RegImm
			ELSE mode:= MemImm
			END;
			GetImm(w, imm)
		END;
		WriteOp("MOV");
		WriteRM(mode, d, reg, base, inx, scale, disp, imm, FALSE)
	END Mov;

	PROCEDURE Mov2 (op: SIGNED16);
		VAR reg, base, inx: SIGNED16; scale, mode: SIGNED8; disp: SIGNED32;
	BEGIN (* reg, base only used, because Mov2 op codes contains special registers (debug/test/controll) *)
		ModRm(mode, reg, base, inx, scale, disp);
		WriteOp("MOV"); w := 1;
		CASE op OF
		 	20H: WriteReg(base); Write(","); WriteSpecialReg(CR+reg)
		  | 21H: WriteReg(base); Write(","); WriteSpecialReg(DR+reg)
		  | 22H: WriteSpecialReg(CR+reg); Write(","); WriteReg(base)
		  | 23H: WriteSpecialReg(DR+reg); Write(","); WriteReg(base)
		  | 24H: WriteReg(base); Write(","); WriteSpecialReg(TR+reg)
		  | 26H: WriteSpecialReg(TR+reg); Write(","); WriteReg(base)
		ELSE Bug(BUG)
		END
	END Mov2;

	PROCEDURE Movx(op: SIGNED16);
		VAR reg, base, inx: SIGNED16; scale, mode: SIGNED8; disp: SIGNED32; byte: BOOLEAN;
	BEGIN
		byte := (op = 0B6H) OR (op = 0BEH);
		ModRm(mode, reg, base, inx, scale, disp);
		IF (op = 0B6H) OR (op = 0B7H) THEN
			WriteOp("MOVZX")
		ELSE
			WriteOp("MOVSX")
		END;
		w:= 1;
		WriteReg(reg); Write(",");
		IF mode = Reg THEN
			IF byte THEN
				w:= 0; WriteReg(base)
			ELSE
				w:= 1; opPrefix:= TRUE; WriteReg(base)
			END
		ELSE
			IF byte THEN WriteString("BYTE PTR ")
			ELSE WriteString("WORD PTR ")
			END;
			WriteMem(base, inx, scale, disp)
		END
	END Movx;

	PROCEDURE Lea (op: SIGNED16);
		VAR reg, base, inx: SIGNED16; scale, mode: SIGNED8; disp: SIGNED32;
	BEGIN
		ModRm(mode, reg, base, inx, scale, disp);
		w:= 1;
		WriteOp("LEA");
		WriteRM(mode, 1, reg, base, inx, scale, disp, 0, TRUE)
	END Lea;

	PROCEDURE Call (op: SIGNED16);
		VAR imm, sel: SIGNED32;
	BEGIN
		IF op = 0E8H THEN
			IF adrPrefix THEN
				GetWord(imm); WriteWord(imm)
			ELSE
				GetDWord(imm); WriteDWord(imm)
			END
		ELSE (* intrasegment *)
			IF adrPrefix THEN
				GetWord(imm); WriteWord(imm)
			ELSE
				GetDWord(imm); WriteDWord(imm)
			END;
			GetWord(sel); Write(" "); WriteWord(sel);
		END;
		WriteOp("CALL");
		IF op = 09AH THEN
			WriteDisp(sel); Write(":")
		END;
		WriteDisp(imm); WriteString("  ("); (*Texts.*)WriteDWHex(pc + imm); Write(")")
	END Call;

	PROCEDURE Movs (op: SIGNED16);
	BEGIN
		IF op = 0A4H THEN WriteOp("MOVSB")
		ELSIF (op = 0A5H) & opPrefix THEN WriteOp("MOVSW")
		ELSIF op  = 0A5H THEN WriteOp("MOVSD")
		ELSE Bug(BUG)
		END
	END Movs;

	PROCEDURE Cmps (op: SIGNED16);
	BEGIN
		IF op = 0A6H THEN WriteOp("CMPSB")
		ELSIF (op = 0A7H) & opPrefix THEN WriteOp("CMPSB")
		ELSIF op = 0A7H THEN WriteOp("CMPSW")
		ELSE Bug(BUG)
		END
	END Cmps;

	PROCEDURE Stos (op: SIGNED16);
	BEGIN
		IF op = 0AAH THEN WriteOp("STOSB")
		ELSIF (op = 0ABH) & opPrefix THEN WriteOp("STOSW")
		ELSIF op = 0ABH THEN WriteOp("STOSD")
		ELSE Bug(BUG)
		END
	END Stos;

	PROCEDURE Lods (op: SIGNED16);
	BEGIN
		IF op = 0ACH THEN WriteOp("LODSB")
		ELSIF op = 0ADH THEN
			IF opPrefix THEN WriteOp("LODSW") ELSE WriteOp("LODSD") END
		ELSE Bug(BUG)
		END
	END Lods;

	PROCEDURE Scas (op: SIGNED16);
	BEGIN
		IF op = 0AEH THEN WriteOp("SCASB")
		ELSIF (op = 0AFH) & opPrefix THEN WriteOp("SCASW")
		ELSIF op = 0AFH THEN WriteOp("SCASD")
		ELSE Bug(BUG)
		END
	END Scas;

	PROCEDURE Ret (op: SIGNED16);
		VAR imm: SIGNED32;
	BEGIN
		IF (op = 0C2H) OR (op = 0CAH) THEN
			GetWord(imm); WriteWord(imm)
		END;
		IF (op = 0CAH) OR (op = 0CBH) THEN WriteOp("RET FAR")
		ELSE WriteOp("RET")
		END;
		IF (op = 0C2H) OR (op = 0CAH) THEN WriteDisp(imm) END
	END Ret;

	PROCEDURE Enter (op: SIGNED16);
		VAR l: SIGNED32; b: SIGNED16;
	BEGIN
		GetWord(l); WriteWord(l); Write(" ");
		GetByte(b); WriteByte(b); Write(" ");
		WriteOp("ENTER");
		WriteDisp(l); Write(","); WriteDisp(b)
	END Enter;

	PROCEDURE Les (op: SIGNED16);
		VAR reg, base, inx: SIGNED16; scale, mode: SIGNED8; disp: SIGNED32;
	BEGIN
		ModRm(mode, reg, base, inx, scale, disp);
		WriteOp("LES");
		WriteRM(mode, 1, reg, base, inx, scale, disp, 0, FALSE)
	END Les;

	PROCEDURE Lds (op: SIGNED16);
		VAR reg, base, inx: SIGNED16; scale, mode: SIGNED8; disp: SIGNED32;
	BEGIN
		ModRm(mode, reg, base, inx, scale, disp);
		WriteOp("LDS");
		WriteRM(mode, 1, reg, base, inx, scale, disp, 0, FALSE)
	END Lds;

	PROCEDURE Ldseg (op: SIGNED16);
		VAR reg, base, inx: SIGNED16; scale, mode: SIGNED8; disp: SIGNED32;
	BEGIN
		ModRm(mode, reg, base, inx, scale, disp);
		IF op = 0B2H THEN WriteOp("LSS")
		ELSIF op = 0B4H THEN WriteOp("LFS")
		ELSE WriteOp("LGS")
		END;
		WriteRM(mode, 1, reg, base, inx, scale, disp, 0, FALSE)
	END Ldseg;

	PROCEDURE Int (op: SIGNED16);
		VAR imm: SIGNED16;
	BEGIN
		IF op = 0CDH THEN
			GetByte(imm); WriteByte(imm)
		ELSE imm := 3
		END;
		WriteOp("INT");
		WriteDisp(imm)
	END Int;

	PROCEDURE Loop (op: SIGNED16);
		VAR imm: SIGNED32;
	BEGIN
		GetImm(0, imm);
		CASE op OF
			0E0H: WriteOp("LOOPNE")
		  | 0E1H: WriteOp("LOOPE")
		  | 0E2H: WriteOp("LOOP")
		  | 0E3H: IF adrPrefix THEN WriteOp("JCXZ") ELSE WriteOp("JECXZ") END
		ELSE Bug(BUG)
		END;
		WriteDisp(imm)
	END Loop;

	PROCEDURE InOut (op: SIGNED16);
		VAR port: SIGNED16; in, dx: BOOLEAN;
	BEGIN
		in := op MOD 4 < 2;
		dx := op MOD 16 >= 8;
		IF ~dx THEN GetByte(port); WriteByte(port) END;
		IF in THEN WriteOp("IN") ELSE WriteOp("OUT") END;
		IF ~in & dx THEN WriteString("dx,")
		ELSIF ~in THEN WriteDisp(port); Write(",") END;
		IF ODD(op) THEN
			IF opPrefix THEN WriteString("AX") ELSE WriteString("EAX") END
		ELSE WriteString("AL") END;
		IF in THEN
			IF dx THEN WriteString(",DX") ELSE WriteString(","); WriteDisp(port) END
		END
	END InOut;

	PROCEDURE Jmp (op: SIGNED16);
		VAR imm: SIGNED32; byte: SIGNED16;
	BEGIN
		IF (op = 0E9H) OR (op = 0EAH) THEN
			GetDWord(imm); WriteDWord(imm)
		ELSE
			GetByte(byte); WriteByte(byte);
			IF byte >= 128 THEN imm:= byte - 256
			ELSE imm:= byte
			END;
		END;
		Tab(OpPos);
		IF op = 0EAH THEN WriteOp("JMP FAR")
		ELSE WriteOp("JMP")
		END;
		Tab(RMPos); WriteDisp(imm); WriteString ("  ("); (*Texts.*)WriteDWHex(pc + imm); Write(")")
	END Jmp;

	PROCEDURE Lar (op: SIGNED16);
		VAR reg, base, inx: SIGNED16; scale, mode: SIGNED8; disp: SIGNED32;
	BEGIN
		ModRm(mode, reg, base, inx, scale, disp);
		WriteOp("LAR");
		WriteRM(mode, 1, reg, base, inx, scale, disp, 0, FALSE)
	END Lar;

	PROCEDURE Lsl (op: SIGNED16);
		VAR reg, base, inx: SIGNED16; scale, mode: SIGNED8; disp: SIGNED32;
	BEGIN
		ModRm(mode, reg, base, inx, scale, disp);
		WriteOp("LSL");
		WriteRM(mode, 1, reg, base, inx, scale, disp, 0, FALSE)
	END Lsl;

	PROCEDURE Setcc (op: SIGNED16);
		VAR reg, base, inx: SIGNED16; scale, mode: SIGNED8; disp: SIGNED32;
	BEGIN
		w:= 0; (* always 8 bit wide *)
		ModRm(mode, reg, base, inx, scale, disp);
		(* not nice but necessary -> no more constant memory for case table *)
		IF op = 90H THEN WriteOp("SETO")
		ELSIF op = 91H THEN WriteOp("SETNO")
		ELSIF op = 92H THEN WriteOp("SETB/SETC/SETNAE")
		ELSIF op = 93H THEN WriteOp("SETNB/SETAE/SETNC")
		ELSIF op = 94H THEN WriteOp("SETZ/SETE")
		ELSIF op = 95H THEN WriteOp("SETNZ/SETNE")
		ELSIF op = 96H THEN WriteOp("SETBE/SETNA")
		ELSIF op = 97H THEN WriteOp("SETNBE/SETA")
		ELSIF op = 98H THEN WriteOp("SETS")
		ELSIF op = 99H THEN WriteOp("SETNS")
		ELSIF op = 9AH THEN WriteOp("SETP/SETPE")
		ELSIF op = 9BH THEN WriteOp("SETNP/SETNP")
		ELSIF op = 9CH THEN WriteOp("SETL/SETNGE")
		ELSIF op = 9DH THEN WriteOp("SETNL/SETGE")
		ELSIF op = 9EH THEN WriteOp("SETLE/SETNG")
		ELSIF op = 9FH THEN WriteOp("SETNLE/SETG")
		ELSE Bug(BUG)
		END;
		IF mode = Reg THEN WriteReg(base)
		ELSE WriteMem(base, inx, scale, disp)
		END
	END Setcc;

	PROCEDURE Bit (op: SIGNED16);
		VAR reg, base, inx, d: SIGNED16; scale, mode: SIGNED8; disp: SIGNED32;
	BEGIN
		w:= 1;
		ModRm(mode, reg, base, inx, scale, disp);
		IF op = 0A3H THEN
			WriteOp("BT"); d:= 0
		ELSIF op = 0ABH THEN
			WriteOp("BTS"); d:= 0
		ELSIF op = 0B3H THEN
			WriteOp("BTR"); d:= 0
		ELSIF op = 0BBH THEN
			WriteOp("BTC"); d:= 0
		ELSIF op = 0BCH THEN
			WriteOp("BSF"); d:= 1
		ELSE
			WriteOp("BSR"); d:= 1
		END;
		IF mode = Reg THEN WriteRM(Reg, d, reg, base, none, 0, 0, 0, FALSE)
		ELSE WriteRM(mode, d, reg, base, inx, scale, disp, 0, FALSE)
		END
	END Bit;

	PROCEDURE Shift (op: SIGNED16);
		VAR reg, base, inx: SIGNED16; scale, mode: SIGNED8; disp, imm: SIGNED32;
	BEGIN
		ModRm(mode, reg, base, inx, scale, disp);
		IF (op = 0A4H) OR (op = 0ACH) THEN (* immediate byte *)
			w:= 0; GetImm(0, imm)
		ELSE
			imm := -1
		END;
		IF (op = 0A4H) OR (op = 0A5H) THEN WriteOp("SHLD")
		ELSIF (op = 0ACH) OR (op = 0ADH) THEN WriteOp("SHRD")
		ELSE Bug(BUG)
		END;
		w := 1;
		WriteRM(mode, 0, reg, base, inx, scale, disp, imm, FALSE);
		Write(",");
		IF imm = -1 THEN WriteString("CL")
		ELSE WriteDisp(imm)
		END
	END Shift;

	PROCEDURE Bswap (op: SIGNED16);
	BEGIN
		w := 1; INCL(target, i486);
		WriteOp("bswap"); WriteReg(op-0C8H)
	END Bswap;

	PROCEDURE Xadd (op: SIGNED16);
		VAR reg, base, inx: SIGNED16; scale, mode: SIGNED8; disp: SIGNED32;
	BEGIN
		INCL(target, i486);
		ModRm(mode, reg, base, inx, scale, disp);
		WriteOp("XADD");
		IF op = 0C1H THEN w := 1 END;
		IF mode = Reg THEN WriteReg(base)
		ELSE WriteMem(base, inx, scale, disp)
		END ;
		Write(","); WriteReg(reg)
	END Xadd;

	PROCEDURE Cmpxchg (op: SIGNED16);
		VAR reg, base, inx: SIGNED16; scale, mode: SIGNED8; disp: SIGNED32;
	BEGIN
		INCL(target, i486);
		ModRm(mode, reg, base, inx, scale, disp);
		WriteOp("CMPXCHG");
		IF op = 0B1H THEN w := 1 END;
		IF mode = Reg THEN WriteReg(base)
		ELSE WriteMem(base, inx, scale, disp)
		END ;
		Write(","); WriteReg(reg)
	END Cmpxchg;

	PROCEDURE Cmov (op: SIGNED16);
		VAR reg, base, inx: SIGNED16; scale, mode: SIGNED8; disp: SIGNED32;
	BEGIN
		INCL(target, PPro);  w := 1;
		ModRm(mode, reg, base, inx, scale, disp);
		CASE op OF
			40H: WriteOp("CMOVO")
		  | 41H: WriteOp("CMOVNO")
		  | 42H: WriteOp("CMOVB")
		  | 43H: WriteOp("CMOVNB")
		  | 44H: WriteOp("CMOVZ")
		  | 45H: WriteOp("CMOVNZ")
		  | 46H: WriteOp("CMOVBE")
		  | 47H: WriteOp("CMOVNBE")
		  | 48H: WriteOp("CMOVS")
		  | 49H: WriteOp("CMOVNS")
		  | 4AH: WriteOp("CMOVP")
		  | 4BH: WriteOp("CMOVNP")
		  | 4CH: WriteOp("CMOVL")
		  | 4DH: WriteOp("CMOVNL")
		  | 4EH: WriteOp("CMOVLE")
		  | 4FH: WriteOp("CMOVNLE")
		ELSE Bug(BUG)
		END;
		WriteRM(mode, 1, reg, base, inx, scale, disp, 0, FALSE)
	END Cmov;

	PROCEDURE Grp1 (op: SIGNED16);
		VAR reg, base, inx: SIGNED16; scale, mode: SIGNED8; disp, imm: SIGNED32;
	BEGIN
		ModRm(mode, reg, base, inx, scale, disp);
		IF op = 80H THEN (* byte *)
			w:= 0; GetImm(0, imm)
		ELSIF op = 81H THEN (* full immediate *)
			w:= 1; GetImm(w, imm)
		ELSE (* op = 83H, signed extendes *)
			w:= 1; GetImm(0, imm)
		END;
		CASE reg OF
			0: WriteOp("ADD")
		  | 1: WriteOp("OR")
		  | 2: WriteOp("ADC")
		  | 3: WriteOp("SBB")
		  | 4: WriteOp("AND")
		  | 5: WriteOp("SUB")
		  | 6: WriteOp("XOR")
		  | 7: WriteOp("CMP")
		ELSE Bug(BUG)
		END;
		IF mode = Reg THEN WriteReg(base)
		ELSE WriteMem(base, inx, scale, disp)
		END;
		Write(",");
		IF (reg = 0) OR (reg = 2) OR (reg = 3) OR (reg = 5) OR (reg = 7) THEN WriteDisp(imm)
		ELSE WriteDWHex(imm)
		END
	END Grp1;

	PROCEDURE Grp2 (op: SIGNED16);
		VAR reg, base, inx: SIGNED16; scale, mode: SIGNED8; disp, imm: SIGNED32;
	BEGIN
		ModRm(mode, reg, base, inx, scale, disp);
		IF (op >= 0D0H) & (op <= 0D3H) THEN
			IF (op = 0D0H) OR (op = 0D2H) THEN w:= 0
			ELSE w:= 1
			END
		ELSE
			IF op = 0C0H THEN w:= 0
			ELSE w:= 1
			END;
			GetImm(0, imm); (* only 8 bit possible *)
		END;
		CASE reg OF
			0: WriteOp("ROL")
		  | 1: WriteOp("ROR")
		  | 2: WriteOp("RCL")
		  | 3: WriteOp("rcr")
		  | 4: WriteOp("SHL/SAL")
		  | 5: WriteOp("SHR")
		  | 7: WriteOp("SAR")
		ELSE Bug(BUG)
		END;
		IF mode = Reg THEN WriteReg(base)
		ELSE WriteMem(base, inx, scale, disp)
		END;
		Write(",");
		IF (op = 0D0H) OR (op = 0D1H) THEN Write("1")
		ELSIF (op = 0D2H) OR (op = 0D3H) THEN WriteString("CL")
		ELSE WriteDisp(imm)
		END
	END Grp2;

	PROCEDURE Grp3 (op: SIGNED16);
		VAR reg, base, inx: SIGNED16; scale, mode: SIGNED8; disp, imm: SIGNED32;
	BEGIN
		ModRm(mode, reg, base, inx, scale, disp);
		IF op = 0F6H THEN w:= 0
		ELSE w:= 1
		END;
		IF reg = 0 (* test *) THEN GetImm(w, imm) END;
		CASE reg OF
			0: WriteOp("TEST")
		  | 2: WriteOp("NOT")
		  | 3: WriteOp("NEG")
		  | 4: WriteOp("MUL")
		  | 5: WriteOp("IMUL")
		  | 6: WriteOp("DIV")
		  | 7: WriteOp("IDIV")
		ELSE Bug(BUG)
		END;
		IF mode = Reg THEN WriteReg(base)
		ELSE WriteMem(base, inx, scale, disp)
		END;
		IF reg = 0 THEN
			Write(","); WriteDisp(imm)
		END
	END Grp3;

	PROCEDURE Grp4 (op: SIGNED16);
		VAR reg, base, inx: SIGNED16; scale, mode: SIGNED8; disp: SIGNED32;
	BEGIN
		w:= 0;
		ModRm(mode, reg, base, inx, scale, disp);
		IF reg = 0 THEN WriteOp("INC")
		ELSE WriteOp("DEC")
		END;
		IF mode # Reg THEN
			WriteString("BYTE PTR "); WriteMem(base, inx, scale, disp)
		ELSE WriteReg(base)
		END
	END Grp4;

	PROCEDURE Grp5 (op: SIGNED16);
		VAR reg, base, inx: SIGNED16; scale, mode: SIGNED8; disp: SIGNED32;
	BEGIN
		w:= 1;
		ModRm(mode, reg, base, inx, scale, disp);
		IF reg = 0 THEN WriteOp("INC")
		ELSIF reg = 1 THEN WriteOp("DEC")
		ELSIF reg = 2 THEN WriteOp("CALL")
		ELSIF reg = 3 THEN WriteOp("CALL FAR")
		ELSIF reg = 4 THEN WriteOp("JMP")
		ELSIF reg = 5 THEN WriteOp("JMP FAR")
		ELSIF reg = 6 THEN WriteOp("PUSH")
		ELSE Bug(BUG)
		END;
		IF mode = Reg THEN WriteReg(base)
		ELSE WriteMem(base, inx, scale, disp)
		END
	END Grp5;

	PROCEDURE Grp6 (op: SIGNED16);
		VAR reg, base, inx: SIGNED16; scale, mode: SIGNED8; disp: SIGNED32;
	BEGIN
		w := 1;
		ModRm(mode, reg, base, inx, scale, disp);
		CASE reg OF
		|  0: WriteOp("SLDT")
		|  1: WriteOp("STR")
		|  2: WriteOp("LLDT"); INCL(target, Priv)
		|  3: WriteOp("LTR"); INCL(target, Priv)
		|  4: WriteOp("VERR")
		|  6: WriteOp("VERW")
		ELSE Bug(BUG)
		END;
		IF mode = Reg THEN WriteReg(base)
		ELSE WriteMem(base, inx, scale, disp)
		END;
	END Grp6;

	PROCEDURE Grp7 (op: SIGNED16);
		VAR reg, base, inx: SIGNED16; scale, mode: SIGNED8; disp: SIGNED32;
	BEGIN
		w := 1;
		ModRm(mode, reg, base, inx, scale, disp);
		CASE reg OF
		|  0: WriteOp("SGDT")
		|  1: WriteOp("SIDT")
		|  2: WriteOp("LGDT"); INCL(target, Priv)
		|  3: WriteOp("LIDT"); INCL(target, Priv)
		|  4: WriteOp("SMSW")
		|  6: WriteOp("LMSW"); INCL(target, Priv)
		|  7: WriteOp("INVLPG"); target := target + {Priv,i486}
		ELSE Bug(BUG)
		END;
		IF mode = Reg THEN WriteReg(base)
		ELSE WriteMem(base, inx, scale, disp)
		END;
	END Grp7;

	PROCEDURE Grp8 (op: SIGNED16);
		VAR reg, base, inx: SIGNED16; scale, mode: SIGNED8; disp, imm: SIGNED32;
	BEGIN
		w:= 1;
		ModRm(mode, reg, base, inx, scale, disp);
		GetImm(0, imm); (* always 8 bit wide *)
		CASE reg OF
			4: WriteOp("BT")
		  | 5: WriteOp("BTS")
		  | 6: WriteOp("BTR")
		  | 7: WriteOp("BTC")
		ELSE Bug(BUG)
		END;
		IF mode = Reg THEN WriteReg(base)
		ELSE WriteMem(base, inx, scale, disp)
		END;
		Write(","); WriteDisp(imm)
	END Grp8;

	PROCEDURE Grp9 (op: SIGNED16);
		VAR reg, base, inx: SIGNED16; scale, mode: SIGNED8; disp: SIGNED32;
	BEGIN
		w:= 1;
		ModRm(mode, reg, base, inx, scale, disp);
		CASE reg OF
			1: WriteOp("CMPXCH8"); INCL(target, Pentium)
		ELSE Bug(BUG)
		END;
		WriteRM(mode, 1, reg, base, inx, scale, disp, 0, FALSE)
	END Grp9;

	PROCEDURE Escape (op: SIGNED16);
	BEGIN
		GetByte(op); WriteByte(op); Write(" ");
		IF op < 50H THEN (* because of DOSOberon *)
			CASE op OF
				0:
					Grp6(op)
			  | 1:
					Grp7(op)
			  | 2:
					Lar(op)
			  | 3:
					Lsl(op)
			  | 6:
					WriteOp("CLTS"); INCL(target, Priv)
			  | 8:
					WriteOp("INVD"); target := target + {Priv,i486}
			  | 9:
					WriteOp("WBINVD"); target := target + {Priv,i486}
			  | 20H..24H, 26H:
					Mov2(op)
			  | 30H:
			         WriteOp("WRMSR"); target := target + {Priv,Pentium}
			  | 31H:
			         WriteOp("RDTSC"); target := target + {Priv,Pentium}
			  | 32H:
			         WriteOp("RDMSR"); target := target + {Priv,Pentium}
			  | 33H:
			         WriteOp("RDPMC"); target := target + {Priv,Pentium}
			  | 40H..4FH:
					Cmov(op)
			ELSE Bug(BUG)
			END
		ELSIF op < 0D0H THEN
			CASE op OF
			  | 80H..8FH:
					Jcc2(op)
			  | 90H..9FH:
					Setcc(op)
			  | 0A0H, 0A8H:
					Push2(op)
			  | 0A1H, 0A9H:
					Pop2(op)
			  | 0A2H:
					WriteOp ("CPUID");  INCL(target, Pentium)
			  | 0A3H, 0ABH, 0B3H, 0BBH..0BDH:
					Bit(op)
			  | 0A4H, 0A5H, 0ACH, 0ADH:
					Shift(op)
			  | 0AFH:
					Imul2(op)
			  | 0B0H,0B1H:
					Cmpxchg(op)
			  | 0B2H, 0B4H, 0B5H:
					Ldseg(op)
			  | 0B6H, 0B7H, 0BEH, 0BFH:
					Movx(op)
			  | 0BAH:
					Grp8(op)
			  | 0C0H,0C1H:
					Xadd(op)
			  | 0C7H:
					Grp9(op)
			  | 0C8H..0CFH:
					Bswap(op)
			ELSE Bug(BUG)
			END
		ELSE Bug(BUG)
		END
	END Escape;

(* floating point i387 instruction set *)

	PROCEDURE WriteFReg (freg: SIGNED16);
	BEGIN
		IF freg = 0 THEN WriteString("ST")
		ELSE
			WriteString("ST("); WriteDisp(freg); Write(")")
		END
	END WriteFReg;

	PROCEDURE WriteFloat (form: SIGNED8; base, inx: SIGNED16; scale: SIGNED8; disp: SIGNED32);
	BEGIN
		(* not nice but necessary -> no more constant memory for case table *)
		IF form = SReal THEN WriteString("SINGLE ")
		ELSIF form = LReal THEN WriteString("DOUBLE ")
		ELSIF form = EReal THEN WriteString("EXTENDED ")
		ELSIF form = WInt THEN WriteString("INTEGER ")
		ELSIF form = SInt THEN WriteString("SHORT ")
		ELSIF form = LInt THEN WriteString("LONG ")
		ELSIF (form = Byte14) OR (form = Byte94) THEN WriteString("SMALL ")
		ELSIF (form = Byte28) OR (form = Byte108) THEN WriteString("BIG ")
		ELSIF form = Decimal THEN WriteString("BCD ")
		END;
		WriteMem(base, inx, scale, disp)
	END WriteFloat;

	PROCEDURE Float0 (op: SIGNED16);
	(* op is 0D8H *)
		VAR stat, base, inx: SIGNED16; scale, mode: SIGNED8; disp: SIGNED32;
	BEGIN
		ModRm(mode, stat, base, inx, scale, disp);
		IF mode # Reg THEN (* memory *)
			CASE stat OF
				0: WriteOp("FADD")
			  | 1: WriteOp("FMUL")
			  | 2: WriteOp("FCOM")
			  | 3: WriteOp("FCOMP")
			  | 4: WriteOp("FSUB")
			  | 5: WriteOp("FSUBR")
			  | 6: WriteOp("FDIV")
			  | 7: WriteOp("FDIVR")
			ELSE Bug(BUG)
			END;
			WriteFloat(SReal, base, inx, scale, disp)
		ELSE
			CASE stat OF
				0: WriteOp("FADD"); WriteFReg(0); Write(",")
			  | 1: WriteOp("FMUL"); WriteFReg(0); Write(",")
			  | 2: WriteOp("FCOM")
			  | 3: WriteOp("FCOMP")
			  | 4: WriteOp("FSUB"); WriteFReg(0); Write(",")
			  | 5: WriteOp("FSUBR"); WriteFReg(0); Write(",")
			  | 6: WriteOp("FDIV"); WriteFReg(0); Write(",")
			  | 7: WriteOp("FDIVR"); WriteFReg(0); Write(",")
			ELSE Bug(BUG)
			END;
			WriteFReg(base)
		END
	END Float0;

	PROCEDURE Float1 (op: SIGNED16);
	(* op is 0D9H *)
		VAR stat, base, inx: SIGNED16; scale, mode: SIGNED8; disp: SIGNED32;
	BEGIN
		ModRm(mode, stat, base, inx, scale, disp);
		IF mode # Reg THEN
			CASE stat OF
				0: WriteOp("FLD")
			  | 2: WriteOp("FST")
			  | 3: WriteOp("FSTP")
			  | 4: WriteOp("FLDENV")
			  | 5: WriteOp("FLDCW")
			  | 6: WriteOp("FSTENV")
			  | 7: WriteOp("FSTCW")
			ELSE Bug(BUG)
			END;
			IF (stat = 4) OR (stat = 6) THEN
				IF opPrefix THEN WriteFloat(Byte14, base, inx, scale, disp)
				ELSE WriteFloat(Byte28, base, inx, scale, disp)
				END
			ELSIF (stat = 2) OR (stat = 3) THEN WriteFloat(SReal, base, inx, scale, disp)
			ELSE WriteFloat(nothing, base, inx, scale, disp)
			END
		ELSIF stat = 0 THEN
			WriteOp("FLD"); WriteFReg(base)
		ELSIF stat = 1 THEN
			WriteOp("FXCH"); WriteFReg(base)
		ELSE
			stat:= stat * 8 + base;
			IF stat = 10H THEN WriteOp("FNOP")
			ELSE
				CASE stat OF
					20H: WriteOp("FCHS")
				  | 21H: WriteOp("FABS")
				  | 24H: WriteOp("FTST")
				  | 25H: WriteOp("FXAM")
				  | 28H: WriteOp("FLD1")
				  | 29H: WriteOp("FLDL2T")
				  | 2AH: WriteOp("FLDL2E")
				  | 2BH: WriteOp("FLDPI")
				  | 2CH: WriteOp("FLDLG2")
				  | 2DH: WriteOp("FLDLN2")
				  | 2EH: WriteOp("FLDZ")
				  | 30H: WriteOp("F2XM1")
				  | 31H: WriteOp("FYL2X")
				  | 32H: WriteOp("FPTAN")
				  | 33H: WriteOp("FPATAN")
				  | 34H: WriteOp("FXTRACT")
				  | 35H: WriteOp("FPREM1")
				  | 36H: WriteOp("FDECSTP")
				  | 37H: WriteOp("FINCSTP")
				  | 38H: WriteOp("FPREM")
				  | 39H: WriteOp("FYL2XP1")
				  | 3AH: WriteOp("FSQRT")
				  | 3BH: WriteOp("FSINCOS")
				  | 3CH: WriteOp("FRNDINT")
				  | 3DH: WriteOp("FSCALE")
				  | 3EH: WriteOp("FSIN")
				  | 3FH: WriteOp("FCOS")
				ELSE Bug(BUG)
				END
			END
		END
	END Float1;

	PROCEDURE Float2 (op: SIGNED16);
	(* op is 0DAH *)
		VAR stat, base, inx: SIGNED16; scale, mode: SIGNED8; disp: SIGNED32;
	BEGIN
		ModRm(mode, stat, base, inx, scale, disp);
		IF mode # Reg THEN
			CASE stat OF
				0: WriteOp("FIADD")
			  | 1: WriteOp("FIMUL")
			  | 2: WriteOp("FICOM")
			  | 3: WriteOp("FICOMP")
			  | 4: WriteOp("FISUB")
			  | 5: WriteOp("FISUBR")
			  | 6: WriteOp("FIDIV")
			  | 7: WriteOp("FIDIVR")
			ELSE Bug(BUG)
			END;
			WriteFloat(SInt, base, inx, scale, disp)
		ELSIF stat = 5 THEN WriteOp("FUCOMPP")
		ELSE Bug(BUG)
		END
	END Float2;

	PROCEDURE Float3 (op: SIGNED16);
	(* op is 0DBH *)
		VAR stat, base, inx: SIGNED16; scale, mode: SIGNED8; disp: SIGNED32;
	BEGIN
		ModRm(mode, stat, base, inx, scale, disp);
		IF mode # Reg THEN
			CASE stat OF
				0: WriteOp("FILD")
			  | 2: WriteOp("FIST")
			  | 3: WriteOp("FISTP")
			  | 5: WriteOp("FLD")
			  | 7: WriteOp("FSTP")
			ELSE Bug(BUG)
			END;
			IF (stat = 5) OR (stat = 7) THEN WriteFloat(EReal, base, inx, scale, disp)
			ELSE WriteFloat(SInt, base, inx, scale, disp)
			END
		ELSIF base = 2 THEN WriteOp("FCLEX")
		ELSIF base = 3 THEN WriteOp("FINIT")
		ELSE Bug(BUG)
		END
	END Float3;

	PROCEDURE Float4 (op: SIGNED16);
	(* op is 0DCH *)
		VAR stat, base, inx: SIGNED16; scale, mode: SIGNED8; disp: SIGNED32;
	BEGIN
		ModRm(mode, stat, base, inx, scale, disp);
		IF mode # Reg THEN
			CASE stat OF
				0: WriteOp("FADD")
			  | 1: WriteOp("FMUL")
			  | 2: WriteOp("FCOM")
			  | 3: WriteOp("FCOMP")
			  | 4: WriteOp("FSUB")
			  | 5: WriteOp("FSUBR")
			  | 6: WriteOp("FDIV")
			  | 7: WriteOp("FDIVR")
			ELSE Bug(BUG)
			END;
			WriteFloat(LReal, base, inx, scale, disp)
		ELSE
			CASE stat OF
				0: WriteOp("FADD")
			  | 1: WriteOp("FMUL")
			  | 4: WriteOp("FSUBR")
			  | 5: WriteOp("FSUB")
			  | 6: WriteOp("FDIVR")
			  | 7: WriteOp("FDIV")
			ELSE Bug(BUG)
			END;
			WriteFReg(base); Write(","); WriteFReg(0)
		END
	END Float4;

	PROCEDURE Float5 (op: SIGNED16);
	(* op is 0DDH *)
		VAR stat, base, inx: SIGNED16; scale, mode: SIGNED8; disp: SIGNED32;
	BEGIN
		ModRm(mode, stat, base, inx, scale, disp);
		IF mode # Reg THEN (* memory *)
			CASE stat OF
				0: WriteOp("FLD")
			  | 2: WriteOp("FST")
			  | 3: WriteOp("FSTP")
			  | 4: WriteOp("FRSTOR")
			  | 6: WriteOp("FSAVE")
			  | 7: WriteOp("FSTSW")
			ELSE Bug(BUG)
			END;
			IF (stat = 4) OR (stat = 6) THEN
				IF opPrefix THEN WriteFloat(Byte94, base, inx, scale, disp)
				ELSE WriteFloat(Byte108, base, inx, scale, disp)
				END
			ELSIF stat = 7 THEN WriteFloat(nothing, base, inx, scale, disp)
			ELSE WriteFloat(LReal, base, inx, scale, disp)
			END
		ELSE
			CASE stat OF
				0: WriteOp("FFREE")
			  | 2: WriteOp("FST")
			  | 3: WriteOp("FSTP")
			  | 4: WriteOp("FUCOM")
			  | 5: WriteOp("FUCOMP")
			ELSE Bug(BUG)
			END;
			WriteFReg(base)
		END
	END Float5;

	PROCEDURE Float6(op: SIGNED16);
	(* op is 0DEH *)
		VAR stat, base, inx: SIGNED16; scale, mode: SIGNED8; disp: SIGNED32;
	BEGIN
		ModRm(mode, stat, base, inx, scale, disp);
		IF mode # Reg THEN (* memory *)
			CASE stat OF
				0: WriteOp("FIADD")
			  | 1: WriteOp("FIMUL")
			  | 2: WriteOp("FICOM")
			  | 3: WriteOp("FICOMP")
			  | 4: WriteOp("FISUB")
			  | 5: WriteOp("FISUBR")
			  | 6: WriteOp("FIDIV")
			  | 7: WriteOp("FIDIVR")
			ELSE Bug(BUG)
			END;
			WriteFloat(WInt, base, inx, scale, disp)
		ELSE
			CASE stat OF
				0: WriteOp("FADDP")
			  | 1: WriteOp("FMULP")
			  | 3: WriteOp("FCOMPP")
			  | 4: WriteOp("FSUBRP")
			  | 5: WriteOp("FSUBP")
			  | 6: WriteOp("FDIVRP")
			  | 7: WriteOp("FDIVP")
			ELSE Bug(BUG)
			END;
			IF stat # 3 THEN
				WriteFReg(base); Write(","); WriteFReg(0)
			END
		END
	END Float6;

	PROCEDURE Float7(op: SIGNED16);
	(* op is 0DFH *)
		VAR stat, base, inx: SIGNED16; scale, mode: SIGNED8; disp: SIGNED32;
	BEGIN
		ModRm(mode, stat, base, inx, scale, disp);
		IF mode # Reg THEN (* memory *)
			CASE stat OF
				0, 5: WriteOp("FILD")
			  | 2: WriteOp("FIST")
			  | 3, 7: WriteOp("FISTP")
			  | 4: WriteOp("FBLD")
			  | 6: WriteOp("FBSTP")
			ELSE Bug(BUG)
			END;
			IF (stat = 4) OR (stat = 6) THEN WriteFloat(Decimal, base, inx, scale, disp)
			ELSIF (stat = 5) OR (stat = 7) THEN WriteFloat(LInt, base, inx, scale, disp)
			ELSE WriteFloat(WInt, base, inx, scale, disp)
			END
		ELSIF stat = 4 THEN WriteOp("FSTSW"); WriteString("AX")
		ELSE Bug(BUG)
		END
	END Float7;

	PROCEDURE Prefix (VAR op: SIGNED16);
	BEGIN
		IF (op = pCS) OR (op = pDS) OR (op = pES) OR (op = pFS) OR (op = pGS) OR (op = pSS) THEN
			prefix:= op;
			WriteByte(op); Write("|");
			GetByte(op);
			Prefix(op)
		ELSIF op =  AdrSize THEN
			adrPrefix:= TRUE;
			WriteByte(op); Write("|");
			GetByte(op);
			Prefix(op)
		ELSIF op = OpSize THEN
			opPrefix:= TRUE;
			WriteByte(op); Write("|");
			GetByte(op);
			Prefix(op)
		END
	END Prefix;

	PROCEDURE IA32Decoder(VAR PC: SIGNED32; VAR r: Files.Rider; VAR w: Texts.Writer); (* ignore params *)
	VAR op: SIGNED16;
	BEGIN
			GetByte(op);
			Prefix(op);
			WriteByte(op); Write(" ");
			IF op < 40H THEN (* because of the DOSOberon *)
				CASE op OF
					0..5:
						Add(op)
				  | 6, 0EH, 16H, 1EH:
						Push(op)
				  | 7, 17H, 1FH:
				 		Pop(op)
				  | 8..0DH:
						Or(op)
				  | 0FH:
						Escape(op)
				  | 10H..15H:
						Adc(op)
				  | 18H..1DH:
						Sbb(op)
				  | 20H..25H:
						And(op)
				  | 27H:
						WriteOp("DAA")
				  | 28H..2DH:
						Sub(op)
				  | 2FH:
						WriteOp("DAS")
				  | 30H..35H:
						Xor(op)
				  | 37H:
						WriteOp("AAA")
				  | 38H..3DH:
						Cmp(op)
				  | 3FH:
						WriteOp("AAS")
				ELSE Bug(BUG)
				END
			ELSIF op < 80H THEN
				CASE op OF
					40H..47H:
						Inc(op)
				  | 48H..4FH:
						Dec(op)
				  | 50H..57H, 60H, 68H, 6AH:
						Push(op)
				  | 58H..5FH, 61H:
						Pop(op)
				  | 62H:
						Bound(op)
				  | 69H, 6BH:
						Imul(op)
				  | 6CH, 6DH:
						Ins(op)
				  | 6EH, 06FH:
						Outs(op)
				  | 70H..7FH:
						Jcc(op)
				ELSE Bug(BUG)
				END
			ELSIF op < 0C0H THEN
				CASE op OF
					80H..81H, 83H:
						Grp1(op)
				  | 84H..85H:
						Test(op)
				  | 86H..87H, 91H..97H:
						Xchg(op)
				  | 88H..8CH, 8EH, 0A0H..0A3H, 0B0H..0BFH:
						Mov(op)
				  | 8DH:
						Lea(op)
				  | 8FH, 9DH:
						Pop(op)
				  | 90H:
						WriteOp("NOP")
				  | 98H:
						IF opPrefix THEN WriteOp("CBW") ELSE WriteOp("CWDE") END
				  | 99H:
						IF opPrefix THEN WriteOp("CWD") ELSE WriteOp("CDQ") END
				  | 9AH:
						Call(op)
				  | 9BH:
						WriteOp("WAIT")
				  | 9CH:
						Push(op)
				  | 9EH:
						WriteOp("SAHF")
				  | 9FH:
						WriteOp("LAHF")
				  | 0A4H..0A5H:
						Movs(op)
				  | 0A6H..0A7H:
						Cmps(op)
				  | 0A8H..0A9H:
						Test(op)
				  | 0AAH..0ABH:
						Stos(op)
				  | 0ACH..0ADH:
						Lods(op)
				  | 0AEH..0AFH:
						Scas(op)
				ELSE Bug(BUG)
				END
			ELSIF op <= 0FFH THEN
				CASE op OF
					0C0H..0C1H:
						Grp2(op)
				  | 0C2H..0C3H, 0CAH, 0CBH:
						Ret(op)
				  | 0C4H:
						Les(op)
				  | 0C5H:
						Lds(op)
				  | 0C6H..0C7H:
						Mov(op)
				  | 0C8H:
						Enter(op)
				  | 0C9H:
						WriteOp("LEAVE")
				  | 0CCH..0CDH:
						Int(op)
				  | 0CEH:
						WriteOp("INTO")
				  | 0CFH:
						WriteOp("IRET")
				  | 0D0H..0D3H:
						Grp2(op)
				  | 0D4H:
						WriteOp("AAM")
				  | 0D5H:
						WriteOp("AAD")
				  | 0D7H:
						WriteOp("XLAT")
				  | 0D8H:
						Float0(op)
				  | 0D9H, 0D6H:
						Float1(op)
				  | 0DAH:
						Float2(op)
				  | 0DBH:
						Float3(op)
				  | 0DCH:
						Float4(op)
				  | 0DDH:
						Float5(op)
				  | 0DEH:
						Float6(op)
				  | 0DFH:
						Float7(op)
				  | 0E0H..0E3H:
						Loop(op) (* and jcxz *)
				  | 0E4H..0E7H, 0ECH..0EFH:
						InOut(op)
				  | 0E8H:
						Call(op)
				  | 0E9H..0EBH:
						Jmp(op)
				  | 0F0H:
						WriteOp("LOCK")
				  | 0F2H:
						WriteOp("REPNE")
				  | 0F3H:
						WriteOp("REP")
				  | 0F4H:
						WriteOp("HLT"); INCL(target, Priv)
				  | 0F5H:
						WriteOp("CMC")
				  | 0F6H..0F7H:
						Grp3(op)
				  | 0F8H:
						WriteOp("CLC")
				  | 0F9H:
						WriteOp("STC")
				  | 0FAH:
						WriteOp("CLI")
				  | 0FBH:
						WriteOp("STI")
				  | 0FCH:
						WriteOp("CLD")
				  | 0FDH:
						WriteOp("STD")
				  | 0FEH:
						Grp4(op)
				  | 0FFH:
						Grp5(op)
				ELSE Bug(BUG)
				END
			ELSE Bug(BUG)
			END
	END IA32Decoder;

	PROCEDURE Dump (size: SIZE);
		VAR op, pe: SIGNED16;
	BEGIN
		pc:= 0; pe := 0; target := {};  OpPos := OpPosC; RMPos := RMPosC;
		IF compilable THEN  DEC(OpPos, OffPos);  DEC(RMPos, OffPos)  END;
		WHILE pc < size DO
			IF target # {} THEN
				Tab(70);  Write(";");
				IF i486 IN target THEN WriteString(" i486") END;
				IF Pentium IN target THEN WriteString(" Pentium") END;
				IF PPro IN target THEN WriteString(" PPro") END;
				IF Priv IN target THEN WriteString(" privileged") END;
				target := {}
			END;
			IF pc # 0 THEN WriteLn END;
			IF (op # 0F0H) & (op # 0F2H) & (op # 0F3H) THEN	(*LOCK/REP/REPNE don't clear prefix*)
				adrPrefix:= FALSE; opPrefix:= FALSE; prefix:= none; w := 0
			END;
			IF (pe # nofPE) & (pc >= PE[pe].point) THEN
				WriteLn; Texts.SetFont(W, titleFont);
				WriteString("PROCEDURE "); WriteString(PE[pe].name);
				IF pc # PE[pe].point THEN WriteString(" adr = "); WriteDWHex(PE[pe].point) END;	(* should not happen *)
				WriteLn; Texts.SetFont(W, defaultFont); INC(pe)
			END;
			suppressOut := compilable OR noOutput;
			Tab(PCpos); WriteDWHex(pc); Write("H"); Write(":"); Tab(HexPos);
			decoder(pc, R, W)
		END;
		IF target # {} THEN
			Tab(60);  Write(";");
			IF i486 IN target THEN WriteString(" i486") END;
			IF Pentium IN target THEN WriteString(" Pentium") END;
			IF PPro IN target THEN WriteString(" PPro") END;
			IF Priv IN target THEN WriteString(" privileged") END
		END;
	END Dump;

	PROCEDURE Reference (size: SIGNED32);
		VAR
			offs, dim: SIGNED32;
			name: ARRAY 64 OF CHAR;
			b, par, sl, lev: CHAR;
			old: ProcArray;
			i: SIZE;

			PROCEDURE GetName(VAR name: ARRAY OF CHAR);
				VAR i: SIGNED32;
			BEGIN
				i:= 0;
				REPEAT
					Next(name[i]);
					INC(i);
				UNTIL name[i-1] = 0X
			END GetName;

			PROCEDURE Type(long: BOOLEAN);
			BEGIN
				IF b > 80X THEN
					WriteString("ARRAY ");
					IF dim # 0 THEN  WriteDisp(dim); WriteString(" "); END;
					WriteString("OF ");
					b := CHR(ORD(b) MOD 10H)
				END;
				CASE b OF
					 0X: WriteString("")
				  | 1X: WriteString("BYTE  ")
				  | 2X: WriteString("BOOLEAN  ")
				  | 3X: WriteString("CHAR  ")
				  | 4X: WriteString("SIGNED8  ")
				  | 5X: WriteString("SIGNED16  ")
				  | 6X: WriteString("SIGNED32  ")
				  | 7X: WriteString("FLOAT32  ")
				  | 8X: WriteString("FLOAT64  ")
				  | 9X: WriteString("SET  ")
				  | 0DX: WriteString("POINTER  ")
				  | 0EX: WriteString("PROCEDURE  ")
				  | 0FX: WriteString("STRING ")
				  | 10X: WriteString("SIGNED64 ")
				  | 12X: WriteString("Static Array")
				  | 14X: WriteString("Dynamic Array")
				  | 15X: WriteString("Open Array")
				  | 16X: WriteString("RECORD")
				  | 1DX: WriteString("POINTER TO RECORD")
				ELSE Bug(BUG)
				END;
				IF long & (ORD(b) IN {16H, 1DH}) THEN
					WriteString(" ["); WriteDisp(dim); WriteString("]  ")
				END;
			END Type;

	BEGIN
		Next(b);
		nofPE := 0; pc := 0;
		WHILE pc < size-1 DO
			IF (b # 0F8X) & (b # 0F9X) THEN
				WriteString("wrong sign!"); WriteByte(ORD(b)); WriteLn;
				RETURN
			ELSE
				WriteLn;
				IF nofPE = LEN(PE) THEN
					old := PE;  NEW(PE, 2*LEN(PE));
					FOR i := 0 TO LEN(old)-1 DO PE[i] := old[i] END
				END;
				GetNum(PE[nofPE].point);
				IF b = 0F9X THEN	(*extended information*)
				PE[nofPE].point := PE[nofPE].point*addressFactor;
				Next(par); Next(b); Next(lev); Next(sl);
					GetName(PE[nofPE].name);
					WriteString(PE[nofPE].name); WriteString("   "); WriteDWord(PE[nofPE].point);
					WriteString(" : "); Type(FALSE);
					WriteString("  par="); WriteDisp(ORD(par));
					WriteString("  lev="); WriteDisp(ORD(lev));
					WriteString("  sl="); WriteDisp(ORD(sl));
					WriteLn;
				ELSE
					GetName(PE[nofPE].name);
					WriteString(PE[nofPE].name); WriteString("   "); WriteDWord(PE[nofPE].point); WriteLn;
				END;
				INC(nofPE); Next(b);
				WHILE (b = 1X) OR (b = 3X) DO
					IF b = 3X THEN WriteString("VAR  ") ELSE WriteString("     ") END;
					Next(b);
					IF b > 10X THEN  GetNum(dim) END;
					GetNum(offs); GetName(name);
					WriteString(name); WriteString(": ");
					Type(TRUE);
					WriteDisp(offs);
					WriteLn;
					Next(b);
				END;
			END
		END
	END Reference;

	PROCEDURE Check (ch: CHAR; str: ARRAY OF CHAR);
		VAR b: CHAR;
	BEGIN
		Next(b); Texts.SetFont(W, titleFont); WriteString(str);
		IF memory THEN WriteDWHex(SIGNED32(ReadAdr)-1) ELSE WriteDWHex(Files.Pos(R)-1) END;
		IF b = ch THEN WriteLn ELSE WriteString(" wrong sign! "); WriteByte(ORD(b)); WriteLn END;
		Texts.SetFont(W, defaultFont)
	END Check;

	PROCEDURE DumpData(VAR a: ARRAY OF CHAR; len: SIGNED32);
		VAR i: SIGNED16;
	BEGIN
		i := 0;
		WHILE i<len DO
			IF (a[i] >= " ") & (a[i] <= "~") THEN Write(a[i]) ELSE Write(".") END;
			INC(i)
		END
	END DumpData;

	PROCEDURE ReadExport;
		VAR count: SIGNED32; name: ARRAY 64 OF CHAR;
		PROCEDURE LoadScope (level: SIGNED32);
			VAR	adr, fp, off, i, len: SIGNED32; exp: SIGNED32; check: POINTER TO ARRAY OF SIGNED32;
		BEGIN
			GetDWord ( exp ); (*fof*)  WriteString(" cnt = ");  WriteDisp(exp);
			GetNum ( fp);
			len := 0;
			IF fp # 0 THEN NEW(check, exp) END;
			WHILE fp # 0 DO
				IF fp = 1 THEN
					Files.ReadNum (R, off);
					IF off >= 0 THEN
						WriteString(" TD(");  INC(count);  WriteDisp(count);  WriteString(") ");  WriteDWHex(off);
						LoadScope (level+1(*1*))
					ELSE
						WriteString(" TD(");  WriteDisp(-off);  Write(")")	(*already exported*)
					END
				ELSE
					WriteLn; Tab(4+SHORT(level*4)); WriteDWHex(fp);
					IF level = 0 THEN
						Files.ReadNum (R, adr);
						IF adr > 0 THEN  adr := adr*addressFactor; WriteString(" P ")  ELSIF adr = 0 THEN  WriteString(" T ")  ELSE  WriteString(" V ")  END;
						WriteDWHex(adr);
						i := 0;
						WHILE i # len DO
							IF check[i] = fp THEN
								WriteString(" Duplicate FP");
								Files.GetName(Files.Base(R), name);
								Out.String(name);
								Out.String(" - Duplicate FP");
								Out.Hex(fp); Out.Ln;
								i := len
							ELSE
								INC(i)
							END
						END;
						check[len] := fp; INC(len)
					END
				END;
				Files.ReadNum (R, fp)
			END
		END LoadScope;

	BEGIN
		Check (88X, "Export:");
		Tab(4);
		LoadScope (0);
		WriteLn;
	END ReadExport;

	PROCEDURE ReadUse;
		VAR  name: ARRAY 32 OF CHAR;

		PROCEDURE GetString (VAR str: ARRAY OF CHAR);
			VAR i: SIGNED32;
		BEGIN
		(*
			i := 0;
			REPEAT
				Next (str[i]); INC (i)
			UNTIL (str[i-1] = 0X) OR (str[i-1] > 7FX);
			IF str[i-1] > 7FX THEN str[i-1] := CHR (ORD (str[i-1]) - 80H); str[i] := 0X END
		*)
		i := 0;
		REPEAT
			Next(str[i]); INC(i);
		UNTIL str[i-1] = 0X;
		END GetString;

		PROCEDURE CheckUse (level: SIGNED32);
			VAR fp, link: SIGNED32; tmpErr: BOOLEAN; name: ARRAY 32 OF CHAR;
		BEGIN tmpErr := (level = -1);
			Files.ReadNum (R, fp);
			WHILE fp # 0 DO
				IF fp = 1 THEN Files.ReadNum (R, link);
					WriteString(" TD "); WriteDWHex(link);
					IF tmpErr THEN CheckUse (-1)
					ELSE CheckUse (1)
					END
				ELSE
					GetString (name);
					WriteLn; Tab(4);  Write("[");  WriteDWHex(fp);  Write("]");
					IF level >= 0 THEN tmpErr := FALSE;
						IF level = 0 THEN
							Files.ReadNum (R, link);
							Tab(16);
							IF link >= 0 THEN Write("V") ELSE Write("P") END;
							Tab(18); WriteDWHex(link)
						END;
					END;
					Tab(24); WriteString(name);
				END;
				Files.ReadNum (R, fp)
			END
		END CheckUse;

	BEGIN
		Check (8AX, "Use:");
		GetString (name);
		WHILE (name # "") DO
			Tab(2); WriteString("Module  "); WriteString(name);
			CheckUse (0); GetString (name);
			WriteLn
		END
	END ReadUse;

	PROCEDURE WriteProc(pc: SIGNED32);
	VAR i: SIGNED32;
	BEGIN
		i := 0;  WHILE (i < nofPE) & (pc # PE[i].point) DO INC(i) END;
		IF i # nofPE THEN WriteString(PE[i].name) END
	END WriteProc;

	PROCEDURE DecodeObjFile*(objName : ARRAY OF CHAR; VAR T : Texts.Text);
		VAR
			f: Files.File;
			byte, version, tag: SIGNED16;
			word, dword, nofEntries, nofCmds, nofPtrs, nofImports,
			nofVarConsLinks, nofLinks, conssize, codesize, exTableLen, nofTypes, refSize, i, j, ptrs, newMths: SIGNED32;
			symSize: SIGNED32;
			name: ARRAY 32 OF CHAR;
			ch: CHAR;
			pos, filepos: SIGNED32;
			data: ARRAY 16 OF CHAR;
			entry: EntryArray;
			noProcs,tmp,codeoffset,beginOffset,endOffset,nofptrs,p: SIGNED32;   (* fof *)
	BEGIN
		T := NIL; f := Files.Old(objName);
		IF f # NIL THEN
			IF ~noOutput THEN
				NEW(T); Texts.Open(T, "")
			END;
			Files.Set(R, f, 0);
			Texts.SetFont(W, titleFont);
			suppressH := TRUE;
			GetByte (tag);
			IF tag = 0BBH THEN
				WriteString ("Object Model -- Object File Dump"); WriteLn;
				Texts.SetFont(W, defaultFont);
				WriteString("  Version:         "); GetByte(version);
				IF version = 0ADH THEN GetByte(version) END;
				WriteByte(version);
				WriteLn;
				Files.ReadNum (R, symSize); Files.Set (R, Files.Base (R), Files.Pos (R) + symSize);	(* skip symbol file *)
			ELSE
				WriteString ("  tag not supported or wrong file type!"); WriteLn;
				IF T # NIL THEN Texts.Append (T, W.buf) END;
				RETURN
			END;
			GetDWord(refSize); GetDWord(nofEntries); GetDWord(nofCmds); GetDWord(nofPtrs); GetDWord(nofTypes); GetDWord(nofImports);
			GetDWord(nofVarConsLinks); GetDWord(nofLinks); GetDWord(dword);  GetDWord(conssize); GetDWord(codesize); (* fof *)

			GetDWord(exTableLen);

				GetDWord(noProcs);(* fof *)
				GetDWord(tmp); (* skip *)(* fof *)

			IF (headerCallback # NIL) THEN headerCallback(dword, conssize, codesize); END;
			WriteString(refSizeStr); WriteDWHex(refSize); WriteLn;
			WriteString(nofEntriesStr); WriteWHex(nofEntries); WriteLn;
			WriteString(nofCmdsStr); WriteWHex(nofCmds); WriteLn;
			WriteString(nofPtrsStr); WriteWHex(nofPtrs); WriteLn;
			WriteString(nofTypesStr); WriteWHex(nofTypes); WriteLn;
			WriteString(nofImpsStr); WriteWHex(nofImports); WriteLn;
			WriteString("  nofVarConsLinks: "); WriteWHex(nofVarConsLinks); WriteLn;
			WriteString("  nofLinks:        "); WriteWHex(nofLinks); WriteLn;
			WriteString(dataSizeStr); WriteDWHex(dword); WriteLn;
			WriteString(constSizeStr); WriteWHex(conssize); WriteLn;
			WriteString(codeSizeStr); WriteWHex(codesize); WriteLn;
			WriteString("  exTableLen       "); WriteDWHex(exTableLen); WriteLn;
			WriteString("  pointers in procs       "); WriteDWHex(noProcs); WriteLn;
			WriteString("  Modulename:      ");
			i := 0;
			REPEAT
				Next(name[i]);
				INC(i)
			UNTIL name[i-1] = 0X;
			WriteString(name); WriteLn; WriteLn;
			IF T # NIL THEN Texts.Append(T, W.buf) END;
		(* skip to reference block *)
			pos := Files.Pos(R);  Files.Set(R, f, Files.Length(f)-refSize);
			Check(8CX, "Reference:");
			Reference (refSize);
			Files.Set(R, f, pos);
			IF T # NIL THEN
				pos := T.len;  Texts.Append(T, W.buf)
			END;
		(* entry block *)
			Check(82X, EntriesStr);
			i:= 0; NEW(entry, nofEntries);
			WHILE i < nofEntries DO
				Tab(Pos1); GetNum(word); (* fof *)
				word := word*addressFactor;
				WriteDWHex(word);
				WriteString(" "); WriteProc(word); WriteLn;
				entry[i] := word; INC(i)
			END;
			WriteLn;
		(* Command block *)
			Check(83X, CommandsStr);
			i:= 0;
			WHILE i < nofCmds DO
				Tab(Pos1); Next(ch); j := 0;
				WHILE ch # 0X DO
					name[j] := ch; INC(j); Next(ch)
				END;
				name[j] := 0X;
				Tab(Pos1); GetNum(word);(* fof *)  WriteWHex(word*addressFactor);
				WriteString(" "); WriteString(name); WriteLn;
				INC(i)
			END;
			WriteLn;
		(* pointer block *)
			Check(84X, PointersStr);
			i:= 0;
			WHILE i < nofPtrs DO
				Tab(Pos1); GetNum(dword); (* fof *) WriteDWHex(dword); WriteInt(dword); WriteLn;
				INC(i)
			END;
			WriteLn;
		(* import block *)
			Check(85X, "Imports:");
			i:= 0;
			WHILE i < nofImports DO
				INC(i);
				Tab(Pos1);  WriteByte(SHORT (i));  Tab(HexPos);
				Next(ch);
				WHILE ch # 0X DO
					Write(ch); Next(ch)
				END;
				WriteLn
			END;
			WriteLn;
		(* VarConsLink block *)
			Check(8DX, "VarConsLinks:");
			i:= 0;
			WHILE i < nofVarConsLinks DO
				WriteString("  modNr: "); GetByte(byte); WriteByte(byte);
				WriteString("  entryNr: "); GetNum(word); (* fof *) WriteWHex(word);
				WriteString("  noffixups: "); GetDWord(word); (* fof *) WriteWHex(word);
				WriteLn; Tab(Pos1);
				j:= SHORT(word);
				WHILE j > 0 DO
					IF j MOD 8 = 0 THEN
						WriteLn; Tab(Pos1)
					END;
					GetNum(word);(* fof *) WriteWHex(word); Tab(column + 2);
					DEC(j)
				END;
				WriteLn;
				INC(i)
			END;
			WriteLn;
		(* Link block *)
			Check(86X, "Links:");
			i:= 0;
			WHILE i < nofLinks DO
				Tab(Pos1); GetByte(byte); WriteByte(byte); Tab(column + 2);
				GetByte(byte); WriteByte(byte); Tab(column + 2);
				GetNum(word); (* fof *)WriteWHex(word); WriteLn;
				INC(i)
			END;
			FOR i := 0 TO nofEntries-1 DO(* fof *)
				 GetNum(word)
			END;
			GetNum(word);

			WriteLn;
		(* Data block *)
			Check(87X, ConstStr);
			i:= 0;
			WHILE i < conssize DO
				Tab(Pos1); WriteWHex(i); Write(":"); Tab(column + 2);
				j := 0;
				WHILE (i < conssize) & (j < 16) DO
					GetByte(byte); WriteByte(byte); Tab(column + 1); data[j] := CHR(byte); INC(i); INC(j)
				END;
				Tab(60); DumpData(data, j); WriteLn;
			END;
			WriteLn;
		(* Export Block *)
			ReadExport; WriteLn;
		(* Code block *)
			Check(89X, CodeStr);
			filepos := Files.Pos(R);
			suppressH := FALSE; Dump(codesize); suppressH := TRUE; WriteLn; WriteLn;
			Files.Set(R, f, filepos + codesize); (* if the wrong decoder is installed, the file position might be invalid *)
		(* Use Block *)
			ReadUse; WriteLn;
		(* type block *)
			Check(8BX, "Type:");
			i:= 0;
			WHILE i < nofTypes DO
				WriteString("  recsize: "); GetNum(dword); (* fof *)WriteDWHex(dword);
				WriteString("  entry: "); GetNum(word); (* fof *)WriteWHex(word);
				WriteString("  basetypMod: "); GetNum(word); (* fof *)WriteWHex(word);
				WriteString("  basetypEntry: "); GetNum(dword); (* fof *)WriteDWHex(dword);
				WriteLn;
				WriteString("  nofMths: "); GetNum(word); (* fof *)WriteWHex(word);
				WriteString("  nofInhMths: "); GetNum(word); (* fof *)WriteWHex(word);
				WriteString("  nofnewMths: ");GetNum(newMths); (* fof *)WriteWHex(newMths);
				WriteString("  nofPtrs: "); GetDWord(ptrs); (* fof *)WriteWHex(ptrs);
				WriteLn; WriteString("  ");
				Next(ch);
				WHILE ch # 0X DO
					Write(ch); Next(ch)
				END;
				j:= 0;
				WHILE j < newMths DO
					WriteLn; WriteString("  mthNr: ");
					GetNum(word); (* fof *)WriteWHex(word); WriteString("  entryNr: ");
					GetNum(word); (* fof *)WriteWHex(word);
					WriteString(" "); WriteProc(entry[word]);
					INC(j)
				END;
				WriteString("  ptrOfs: ");
				j:= 0;
				WHILE j < ptrs DO
					IF j MOD 8 = 0 THEN WriteLn END;
					GetNum(dword); (* fof *)WriteDWHex(dword); WriteString("  ");
					INC(j)
				END;
				WriteLn;
				INC(i)
			END;
			WriteLn;
			Check(8EX, "Exception Table:");
			FOR i := 0 TO exTableLen - 1 DO
				WriteInt(i); WriteString(": ");
				GetByte(tag);
				IF tag = 0FEH THEN
					(* pcFrom *) WriteString("pcFrom= "); GetNum(word); WriteDWHex(word);
					(* pcTo *) WriteString(" pcTo="); GetNum(word); WriteDWHex(word);
					(* pcHandler *) WriteString(" pcHandler="); GetNum(word); WriteDWHex(word);
					WriteLn
				ELSE
					WriteString("Error"); WriteLn
				END
			END;

			WriteLn;(* fof *)
			Check(8EX, "PointerInProc Table:");
			FOR i := 0 TO noProcs - 1 DO
				WriteInt(i); WriteString(": ");
				GetByte(tag);
				IF tag = 08FH THEN
					GetNum(codeoffset); WriteString("codeoffs= ");WriteDWHex(codeoffset);
					GetNum(beginOffset);WriteString("beginOffset= ");WriteDWHex(beginOffset);
					GetNum(endOffset);WriteString("endOffset= ");WriteDWHex(endOffset);
					GetDWord(nofptrs);WriteString("nofptrs"); WriteDWHex(nofptrs);
				FOR j := 0 TO nofptrs - 1 DO
					GetNum(p)
				END
				ELSE
					WriteString("Error"); WriteLn
				END
			END;

			WriteLn;
			(* output *)
			IF T # NIL THEN Texts.Insert(T, pos, W.buf) END;
			Files.Set(R, NIL, 0)
		END
	END DecodeObjFile;

	(* ------------------------------------------------------------------------------------ *)
	(* Memory Module Dump *)
(*
	PROCEDURE DumpType (tdadr, codebase: SIGNED32);
		VAR tdbase, i, j: SIGNED32; m: Modules.Module;

		PROCEDURE DumpTypeName (tdadr: SIGNED32);
			VAR tdbase, i: SIGNED32; ch: CHAR;
		BEGIN
			IF tdadr # 0 THEN
				SYSTEM.GET (tdadr-4, tdbase);
				i := tdbase+16; SYSTEM.GET (i, ch);
				WHILE ch # 0X DO Write (ch); INC (i); SYSTEM.GET (i, ch) END
			END
		END DumpTypeName;

	BEGIN
		IF tdadr MOD 16 # 8 THEN WriteString (" TDAdr MOD 16 # 8 !!!"); WriteLn; RETURN END;

		SYSTEM.GET (tdadr-4, tdbase);
		IF tdbase MOD 32 # 0 THEN WriteString (" TDBase MOD 32 # 0 !!!"); WriteLn; RETURN END;
		(* td name *)
		Tab (Pos1); WriteString ("TD at     "); WriteDWHex (tdadr);
		Write(" "); Texts.SetFont(W, titleFont); DumpTypeName (tdadr); Texts.SetFont(W, defaultFont); WriteLn;
		Tab (Pos1); WriteString ("TDBase at "); WriteDWHex (tdbase); WriteLn;

		(* check td of td *)
		SYSTEM.GET (tdbase-4, i);
		IF i # tdbase THEN WriteString (" TD of TD is wrong"); WriteLn; RETURN END;

		(* td size *)
		SYSTEM.GET (tdbase, i); Tab (Pos1); WriteString ("tdsize:   "); WriteDWHex (i); WriteLn;
		SYSTEM.GET (tdbase + 8, i); Tab (Pos1); WriteString ("self:     "); WriteDWHex (i); Write(" "); DumpTypeName (i); WriteLn;
		SYSTEM.GET (tdbase + 12, i); Tab (Pos1); WriteString ("ext:      "); WriteDWHex (i); WriteLn;
		SYSTEM.GET (tdbase + 48, i); Tab (Pos1); WriteString ("mdesc:    "); WriteDWHex (i);
		m := SYSTEM.VAL (Modules.Module, i); WriteString (" ["); WriteString (m.name); Write ("]"); WriteLn;

		i := tdbase + 52;
		Tab (Pos1); WriteString ("methods"); WriteLn;
		WHILE i <= tdadr - 72 DO
			Tab (Pos1+4); SYSTEM.GET (i, j);
			IF j # 0 THEN
				WriteDWHex ((tdadr-i-72) DIV 4); WriteString(": ");
				WriteDWHex (j-codebase); WriteLn
			END;
			INC (i, 4)
		END;

		i := 16;
		Tab (Pos1); WriteString ("tags"); WriteLn;
		WHILE i > 0 DO
			DEC (i);
			SYSTEM.GET (tdadr - 8 - i*4, j);
			IF j # 0 THEN
				Tab (Pos1+4); WriteByte(SHORT(i)); WriteString(": "); WriteDWHex (j);
				WriteString (" ["); DumpTypeName (j); Write ("]"); WriteLn
			END
		END;
		WriteLn;

		Tab (Pos1); WriteString ("rec size: "); SYSTEM.GET (tdadr, j); WriteDWHex (j); WriteLn;
		Tab (Pos1); WriteString ("ptr off"); WriteLn;
		i := tdadr + 4;
		REPEAT
			SYSTEM.GET (i, j); INC (i, 4);
			Tab (Pos1+4); WriteDWHex (j); WriteLn
		UNTIL j < 0;
		WriteLn;
	END DumpType;
*)

(*
	PROCEDURE DecodeModule* (objName : ARRAY OF CHAR; VAR T : Texts.Text);
		VAR i, j, pos: SIGNED32; mod: Modules.Module;
			codesize, refsize, datasize, constsize: SIGNED32;
			data: ARRAY 16 OF CHAR;
	BEGIN
		mod := Modules.ThisMod (objName);
		IF mod = NIL THEN T := NIL; RETURN END;
		NEW(T); Texts.Open(T, "");
		Texts.SetFont(W, titleFont); WriteString ("Module Dump"); WriteLn; Texts.SetFont(W, defaultFont);
		suppressH := TRUE;
		WriteString ("  mdesc:           "); WriteDWHex (SYSTEM.VAL (SIGNED32, mod)); WriteLn;
		WriteString ("  name:            "); WriteString (mod.name); WriteLn;
		WriteString ("  refcnt:          "); WriteDWHex (mod.refcnt); WriteLn;
		WriteString ("  sb:              "); WriteDWHex (mod.sb); WriteLn;
		datasize := mod.sb - ADDRESSOF(mod.data[0]);
		constsize := mod.sb - ADDRESSOF(mod.data[0])+ LEN(mod.data);
		codesize := LEN(mod.code);
		refsize := LEN(mod.refs);
		WriteString (dataSizeStr); WriteDWHex (datasize); WriteLn;
		WriteString (constSizeStr); WriteDWHex (constsize); WriteLn;
		WriteString (codeSizeStr); WriteDWHex (codesize); WriteLn;
		WriteString (refSizeStr); WriteDWHex (refsize); WriteLn;
		WriteString (nofEntriesStr); WriteDWHex (LEN(mod.entries)); WriteLn;
		WriteString (nofCmdsStr); WriteDWHex (LEN(mod.cmds)); WriteLn;
		WriteString (nofImpsStr); WriteDWHex (LEN(mod.imports)); WriteLn;
		WriteString (nofTypesStr); WriteDWHex (LEN(mod.tdescs)); WriteLn;
		WriteString (nofPtrsStr); WriteDWHex (LEN(mod.ptrTab)); WriteLn;
		WriteLn;
		Texts.Append(T, W.buf);
		(* skip to reference block *)
		Texts.SetFont(W, titleFont); WriteString ("Reference: "); WriteLn; Texts.SetFont(W, defaultFont);
		pos := ReadAdr; ReadAdr := ADDRESSOF (mod.refs[0]);
		Reference (LEN(mod.refs));
		ReadAdr := pos;
		pos := T.len; Texts.Append(T, W.buf);
		(* entry block *)
		Texts.SetFont(W, titleFont); WriteString (EntriesStr); WriteLn; Texts.SetFont(W, defaultFont);
		i:= 0;
		WHILE i < LEN(mod.entries) DO
			Tab(Pos1); WriteDWHex(mod.entries[i]);
			WriteString(" "); WriteDWHex(mod.entries[i] - ADDRESSOF(mod.code[0]));
			WriteString(" "); WriteProc(mod.entries[i] - ADDRESSOF(mod.code[0])); WriteLn;
			INC(i)
		END;
		WriteLn;
		(* Command block *)
		Texts.SetFont(W, titleFont); WriteString (CommandsStr); WriteLn; Texts.SetFont(W, defaultFont);
		i:= 0;
		WHILE i < LEN(mod.cmds) DO
			Tab(Pos1); WriteString (mod.cmds[i].name);
			Tab(column + 4); WriteDWHex(mod.cmds[i].adr); WriteLn;
			INC(i)
		END;
		WriteLn;
		(* pointer block *)
		Texts.SetFont(W, titleFont); WriteString (PointersStr); WriteLn; Texts.SetFont(W, defaultFont);
		i:= 0;
		WHILE i < LEN(mod.ptrTab) DO
			Tab(Pos1); WriteDWHex(mod.ptrTab[i]); WriteLn;
			INC(i)
		END;
		WriteLn;
		(* type block *)
		Texts.SetFont(W, titleFont); WriteString ("TypeDescriptors:"); WriteLn; Texts.SetFont(W, defaultFont);
		i := 0;
		WHILE i < LEN(mod.tdescs) DO
			DumpType (mod.tdescs[i], ADDRESSOF(mod.code[0])); WriteLn;
			INC (i)
		END;

		Texts.SetFont(W, titleFont); WriteString ("imports: not implemented yet"); WriteLn; Texts.SetFont(W, defaultFont);

		(* data/const section *)
		Texts.SetFont(W, titleFont); WriteString (DataStr); WriteLn; Texts.SetFont(W, defaultFont);
		i := 0;
		WHILE i < LEN(mod.data) DO
			Tab(Pos1); WriteWHex(i); Write(":"); Tab(column + 2);
			j := 0;
			WHILE (i < LEN(mod.data)) & (j < 16) DO
				WriteByte(ORD(mod.data[i])); Tab(column + 1); data[j] := mod.data[i]; INC(i); INC(j)
			END;
			Tab(60); DumpData(data, j); WriteLn;
		END;
		WriteLn;

		(* code section *)
		Texts.SetFont(W, titleFont); WriteString (CodeStr); WriteLn; Texts.SetFont(W, defaultFont);
		ReadAdr := ADDRESSOF (mod.code[0]);
		Dump (LEN(mod.code)); WriteLn; WriteLn;

		Texts.SetFont(W, titleFont); WriteString ("import: not implemented yet"); WriteLn; Texts.SetFont(W, defaultFont);
		Texts.SetFont(W, titleFont); WriteString ("struct: not implemented yet"); WriteLn; Texts.SetFont(W, defaultFont);
		Texts.SetFont(W, titleFont); WriteString ("reimp: not implemented yet"); WriteLn; Texts.SetFont(W, defaultFont);
		Texts.SetFont(W, titleFont); WriteString ("export: not implemented yet"); WriteLn; Texts.SetFont(W, defaultFont);

		Texts.Insert(T, pos, W.buf)
	END DecodeModule;
*)

	(** Decoder.Decode Module	Decodes the object file of Module *)
	PROCEDURE Decode*;
		VAR
			i, j: SIGNED32;
			name, suf: ARRAY 32 OF CHAR;
			ch: CHAR;
			S: Texts.Scanner;
			beg, end, start, time: SIGNED32;
			T: Texts.Text;
			res: SIGNED16; arm, big: BOOLEAN;
	BEGIN
		Texts.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos);
		start := Texts.Pos(S); Texts.Scan(S); arm := FALSE; big := FALSE;
		memory := FALSE; compilable := FALSE; raw := FALSE; noOutput := FALSE;
		WHILE (S.class = Texts.Char) & (S.c = "\") DO	(* get options *)
			Texts.Scan (S);
			IF S.s = "b" THEN
				big := TRUE
			ELSIF S.s = "dARM" THEN
				arm := TRUE
			ELSIF S.s = "d386" THEN
				InstallIA32Decoder
			ELSE
				i := 0;
				WHILE S.s[i] # 0X DO
					IF (S.s[i] = "m") THEN memory := TRUE
					ELSIF (S.s[i] = "c") THEN compilable := TRUE
					ELSIF (S.s[i] = "n") THEN noOutput := TRUE
					ELSIF (S.s[i] = "r") THEN raw := TRUE
					ELSE Out.String("Unsupported option "); Out.Char(S.s[i]); Out.Ln
					END;
					INC(i)
				END
			END;
			start := Texts.Pos(S); Texts.Scan(S)
		END;
		IF big & ~arm THEN
			Out.String("use \b only with \dARM"); Out.Ln(); RETURN
		END;
		IF arm THEN
			Oberon.Call("PCARMDecoder.InstallDecoder", Oberon.Par, FALSE, res);
			IF big THEN
				Oberon.Call("PCARMDecoder.SetBigEndian", Oberon.Par, FALSE, res)
			ELSE
				Oberon.Call("PCARMDecoder.SetLittleEndian", Oberon.Par, FALSE, res)
			END;
			ASSERT(res = 0)
		END;
		suppressH := FALSE; suppressOut := noOutput;
		IF (S.class = Texts.Char) & (S.c = "^") THEN
			Oberon.GetSelection(T, beg, end, time);
			IF (T = NIL) OR (time <= 0) THEN S.class := Texts.Inval
			ELSE Texts.OpenScanner(S, T, beg); start := Texts.Pos(S); Texts.Scan(S)
			END
		ELSE
			end := MAX(SIGNED32)
		END;
		WHILE (S.class = Texts.Name) & (start <= end) DO
			i := 0; ch := S.s[0];  j := MAX(SIGNED32);
			WHILE ("A" <= CAP(ch)) & (CAP(ch) <= "Z") OR ("0" <= ch) & (ch <= "9") OR (ch = ".") DO
				IF ch = "." THEN j := i END;
				name[i] := ch; INC(i); ch := S.s[i]
			END;
			IF j < i THEN i := j END;
			name[i] := 0X;
			IF ~memory THEN
				Strings.GetSuffix (S.s, suf);
				IF (suf = "Obj") OR (suf = "Obf") OR (suf = "Obx") OR (suf = "Obz") OR (suf = "Obw") (* fof *)  THEN
					Strings.AppendCh (name, "."); Strings.Append (name, suf)
				ELSE
					Strings.Append (name, objSuffix)
				END
			END;
			start := Texts.Pos(S); Texts.Scan(S);
			IF S.class = Texts.Int THEN
				breakpos:= S.i; start := Texts.Pos(S); Texts.Scan(S)
			ELSE
				breakpos:= -1
			END;
			IF memory THEN HALT(99) (*DecodeModule(name, T)*)
			ELSE DecodeObjFile(name, T)
			END;
			IF T # NIL THEN
				name[i+1] := "D"; name[i+2] := "e"; name[i+3] := "c";
				Oberon.OpenText(name, T, 600, 300);
				breakpos := -1
			ELSE
				IF Files.Old(name) = NIL THEN
					Out.String("Decoder error: "); Out.String(name); Out.String(" does not exist"); Out.Ln;
					S.class := Texts.Inval
				END
			END;
			T := NIL
		END
	END Decode;

	PROCEDURE DecodeThis*(dest: Texts.Text; VAR code: ARRAY OF CHAR);
	BEGIN
		memory := TRUE; ReadAdr := ADDRESSOF(code[0]); suppressH := FALSE;
		Dump(LEN(code));
		Texts.Append(dest, W.buf)
	END DecodeThis;

(* ======================================================================================== *)
(* Returns the frame that is at X, Y on the display. u, v contain the relative coordinates inside this frame *)
PROCEDURE ThisFrame(X, Y: SIGNED16; VAR F: Display.Frame);
VAR M: Display.LocateMsg;
BEGIN M.X := X; M.Y := Y; M.F := NIL; M.loc := NIL; Display.Broadcast(M); F := M.loc
END ThisFrame;

(* Get the marked text *)
PROCEDURE GetText(VAR par: Display.Frame): Texts.Text;
VAR M: Objects.LinkMsg; t: Texts.Text;
BEGIN
	t := NIL;
	ThisFrame(Oberon.Pointer.X, Oberon.Pointer.Y, par);
	IF par # NIL THEN
		M.id := Objects.get; M.name := "Model"; M.obj := NIL; M.res := -1; par.handle(par, M);
		IF (M.obj # NIL) & (M.obj IS Texts.Text) THEN t := M.obj(Texts.Text) END
	END;
	RETURN t
END GetText;

PROCEDURE Locate(F: Display.Frame;  T: Texts.Text;  pos: SIGNED32);
VAR M: Oberon.CaretMsg;  N: Oberon.ControlMsg;
BEGIN
	IF pos < 0 THEN pos := 0
	ELSIF pos > T.len THEN pos := T.len
	END;
	N.F := NIL; N.id := Oberon.neutralize; Display.Broadcast(N);
	Oberon.FadeCursor(Oberon.Pointer);
	M.id := Oberon.set; M.F := F; M.car := F; M.text := T; M.pos := pos; Display.Broadcast(M)
END Locate;

PROCEDURE Scan(s: ARRAY OF CHAR): SIGNED32;
VAR x, i: SIGNED32;
BEGIN
	x := 0;  i := 0;
	WHILE ((s[i] >= "0") & (s[i] <= "9")) OR ((s[i] >= "A") & (s[i] <= "F")) & (i # LEN(s)) DO
		IF s[i] >= "A" THEN x := x*16 + (ORD(s[i])-ORD("A")+10)
		ELSE x := x*16 + (ORD(s[i])-ORD("0"))
		END;
		INC(i)
	END;
	RETURN x
END Scan;

PROCEDURE GetLine(VAR r: Texts.Reader;  VAR buf: ARRAY OF CHAR);
VAR i: SIGNED32;  ch: CHAR;
BEGIN
	i := 0;
	Texts.Read(r, ch);
	WHILE ~r.eot & (ch # 0DX) DO
		IF i < LEN(buf)-1 THEN buf[i] := ch; INC(i) END;
		Texts.Read(r, ch)
	END;
	buf[i] := 0X
END GetLine;

(** Decoder.Find	Finds the selected pc in the marked window *)
PROCEDURE Find*;
VAR
	fbeg, fend, ftime, breakpc, breakpos: SIGNED32;  ftext: Texts.Text;  S1: Texts.Scanner;
	line: SIGNED16;  fpar: Display.Frame;  scan: BOOLEAN;  buf: ARRAY 6 OF CHAR;
	r: Texts.Reader;
BEGIN
	Oberon.GetSelection(ftext, fbeg, fend, ftime);
	IF ftime >= 0 THEN
		Texts.OpenScanner(S1, ftext, fbeg); Texts.Scan(S1); line := S1.line;
		WHILE ~(S1.class IN {Texts.Int, Texts.Inval}) & (S1.line = line) DO Texts.Scan(S1) END
	ELSE
		S1.class := Texts.Inval
	END;
	IF S1.class = Texts.Int THEN
		breakpc := S1.i;
		ftext := GetText(fpar);
		Texts.OpenReader(r, ftext, 0);
		GetLine(r, buf);  scan := FALSE;  breakpos := -1;
		WHILE ~r.eot & (breakpos < 0) DO
			IF buf = "Code:" THEN scan := TRUE
			ELSIF scan & (Scan(buf) >= breakpc) THEN breakpos := Texts.Pos(r)-1
			END;
			GetLine(r, buf)
		END;
		IF breakpos >= 0 THEN
			Texts.WriteString(W, "pos ");  Texts.WriteInt(W, breakpos, 1);
			Texts.WriteString(W, "  pc");  Texts.WriteHex(W, breakpc);  Texts.Write(W, "H");
			Texts.WriteLn(W);  Texts.Append(Oberon.Log, W.buf);
			Locate(fpar, ftext, breakpos)
		END
	ELSE
		Texts.WriteString(W, "  pc not selected"); Texts.WriteLn(W);
		Texts.Append(Oberon.Log, W.buf)
	END
END Find;

(* SetObjSuffix - changes the expected suffix of an object file *)
PROCEDURE SetObjSuffix*(suffix: ARRAY OF CHAR);
BEGIN
	COPY(suffix, objSuffix)
END SetObjSuffix;

PROCEDURE SetSuffix*;	(* suffix *)
VAR S: Texts.Scanner;
BEGIN
	Texts.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos);
	Texts.Scan(S);
	IF S.class IN {Texts.Name, Texts.String} THEN
		SetObjSuffix(S.s);
		Out.String("Object file suffix set to ");
		Out.String(objSuffix)
	ELSE
		Out.String("Parameter not found")
	END;
	Out.Ln
END SetSuffix;

PROCEDURE InstallDecoder*(decodeHandler: DecodeHandler; suffix: ARRAY OF CHAR; adrFactor: SIGNED32);
BEGIN
	IF (decodeHandler = NIL) THEN InstallIA32Decoder
	ELSE decoder := decodeHandler; SetObjSuffix(suffix); addressFactor := adrFactor
	END;
END InstallDecoder;

PROCEDURE InstallHeaderCallback*(hdrCallback: HeaderCallback);
BEGIN headerCallback := hdrCallback
END InstallHeaderCallback;

(* ActiveDecoder - returns the currently installed decoder plugin *)
PROCEDURE ActiveDecoder*(): DecodeHandler;
BEGIN RETURN decoder
END ActiveDecoder;

PROCEDURE InstallIA32Decoder*;
VAR h, d: DecodeHandler;
BEGIN
	h := IA32Decoder;
	(* Paco bug workaround *)
	d := ActiveDecoder();
	IF h # d THEN
		InstallDecoder(IA32Decoder, Modules.extension, (* fof *) 1);
		InstallHeaderCallback(NIL);
		Out.String("Intel IA32 Decoder Plugin installed"); Out.Ln
	END
END InstallIA32Decoder;

BEGIN
	COPY(Modules.extension, objSuffix);
	(*Out.String("Decoder  NM / pjm / prk 26.04.00"); Out.Ln;*)
	breakpos := -1; suppressH := FALSE; suppressOut := FALSE;
	NEW(PE, 32);
	Texts.OpenWriter(W);  defaultFont := Fonts.This("Courier10.Scn.Fnt"); titleFont := Fonts.This("Oberon12b.Scn.Fnt");
	InstallIA32Decoder
END Decoder.

System.Free PCARMDecoder Decoder ~

Decoder.Decode \d386 ^
Decoder.Decode \dARM ^
Decoder.Decode \dARM \b ^
Decoder.Decode \m ^
Decoder.Decode \c ^
Decoder.Decode \n ^
Decoder.SetSuffix .Obx

SoftRISC32.Obx

Decoder.Decode \n SoftBase.Obx SoftRISC32.Obx SoftRISC32Test.Obx ~
