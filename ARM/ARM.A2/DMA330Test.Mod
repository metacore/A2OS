MODULE DMA330; (** AUTHOR "Timothee Martiel, 2015"; PURPOSE "Driver for CoreLink DMA-330"; *)

(* Code mostly written by F. Friedrich *)

IMPORT Platform, Machine, Objects, Trace, Random, SYSTEM;

CONST

	Size = 2 * 1024 + 8;
	Repeats = (*10000*) 1;

	slcr = 0F8000000H; (* system level control register *)
	APER_CLK_CTRL = slcr + 12CH; (* AMBA peripheral clock control *)
	DMAC_RST_CTRL = slcr + 20CH; (* DMAC Software Reset Control *)

	DMA_CPU_2XCLKACT = 0; (* DMA Controller clock control *)

	dmac0_ns = 0F8004000H; (* DMA non secure base address *)
	dmac0_s = 0F8003000H; (* DMA secure base address *)

	CR0_Offset = 0E00H; (* Configuration Register 0 *)
	CR1_Offset = 0E04H; (* Configuration Register 1 *)
	CR2_Offset = 0E08H; (* Configuration Register 2 *)
	CR3_Offset = 0E0CH; (* Configuration Register 3 *)
	CR4_Offset = 0E10H; (* Configuration Register 4 *)
	INT_EVENT_RIS_Offset = 24H; (* Event Interrupt Raw Status *)
	INTCLR_Offset = 2CH; (* Interrupt Clear *)
	INTEN_Offset = 20H; (* interrupt enable *)
	DBGSTATUS_Offset = 0D00H; (* DMA Manager execution status *)
	DBGCMD_Offset = 0D04H; (* DMA Manager Instr. Command *)
	DBGINST0_Offset	= 0D08H; (* DMA Manager instruction part A *)
	DBGINST1_Offset	= 0D0CH; (* DMA Manager instruction part A *)
	FSRD_Offset =  30H; (* Fault Status *)
	FSRC_Offset = 34H; (* Fault Status DMA Channel *)
	FTRn_Offset = 40H;

TYPE
	Program * = RECORD
		code: ARRAY 128 OF CHAR;
		offset: LONGINT;
		label0Offset, label1Offset: LONGINT; (* offset of loop 0 and loop1. Negative value indicates unused *)
		label0LPFE, label1LPFE: BOOLEAN;
	END;

VAR
	program: Program;
	busy: BOOLEAN;
	BaseAddress: ADDRESS;
	count, current: LONGINT;
	gen: Random.Generator;

	PROCEDURE DHex(CONST s: ARRAY OF CHAR; val: LONGINT);
	BEGIN
		Trace.String(s); Trace.String(" "); Trace.Hex(val,-8); Trace.StringLn("H");
	END DHex;

	PROCEDURE DSet(CONST s: ARRAY OF CHAR; val: SET);
	BEGIN
		Trace.String(s); Trace.String(" "); Trace.Bits(val,0,32); Trace.Ln;
	END DSet;

	PROCEDURE FaultHandler * (VAR state: Machine.State);
	VAR fault: BOOLEAN; faultChannels: SET; program: Program; i, busy: LONGINT;
	BEGIN
		Trace.StringLn("DMA: FaultHandler called");
		fault := SYSTEM.GET32(BaseAddress+FSRD_Offset) MOD 2 = 1;
		IF fault THEN
			Trace.StringLn("manager fault");
			(* DMA Kill *)
			DMAKILL(program);
		END;

		SYSTEM.GET(BaseAddress+FSRC_Offset, faultChannels);
		DSet("faultChannels", faultChannels);
		faultChannels := faultChannels * {0..7}; i := 0;
		WHILE (i<8) & (faultChannels # {}) DO
			IF i IN faultChannels THEN
				(* Read reason *)
				Trace.String("Fault on channel ");
				Trace.Int(i, 0);
				Trace.String(': ');
				Trace.Address(SYSTEM.GET32(BaseAddress + FTRn_Offset + 4 * i));
				Trace.Ln;
				(* write instruction 1 *)
				EXCL(faultChannels, i);
				SYSTEM.PUT32(BaseAddress+DBGINST0_Offset, 1 + ASH(i,8) + ASH(ORD(program.code[0]),16) + ASH(ORD(program.code[1]),24));
				(* wait until busy *)
				REPEAT
					SYSTEM.GET(BaseAddress+DBGSTATUS_Offset, busy)
				UNTIL busy MOD 2 # 0; (* DMA busy *)
				(* start the command *)
				SYSTEM.PUT32(BaseAddress+DBGCMD_Offset, 0);
			END;
			INC(i);
		END;
	END FaultHandler;

	PROCEDURE DoneHandler * (VAR state: Machine.State);
	VAR reason: LONGINT; i: LONGINT;
	BEGIN
		SYSTEM.GET(BaseAddress+INT_EVENT_RIS_Offset, reason);
		(* clear IRQ *)
		SYSTEM.PUT32(BaseAddress+INTCLR_Offset, 1);
		busy := FALSE
	END DoneHandler;

	PROCEDURE InitProgram * (VAR program: Program);
	BEGIN
		program.offset := 0; program.label0Offset := -1; program.label1Offset := -1;
	END InitProgram;


	PROCEDURE C8(VAR program: Program; ch: CHAR);
	BEGIN
		program.code[program.offset] := ch; INC(program.offset);
	END C8;

	PROCEDURE D8(VAR program: Program; val: LONGINT);
	BEGIN
		C8(program, CHR(val MOD 100H));
	END D8;

	PROCEDURE D16(VAR program: Program; val: LONGINT);
	VAR i: LONGINT;
	BEGIN
		FOR i := 0 TO 1 DO
			D8(program, val MOD 100H);
			val := val DIV 100H;
		END;
	END D16;

	PROCEDURE D32(VAR program: Program; val: LONGINT);
	VAR i: LONGINT;
	BEGIN
		FOR i := 0 TO 3 DO
			D8(program, val MOD 100H);
			val := val DIV 100H;
		END;
	END D32;

CONST
	SAR * = 0; CCR * = 1; DAR * = 2; (* do not change values, are used in encoding *)

	PROCEDURE DMAADDH * (VAR program: Program; register: LONGINT;  imm: LONGINT);
	BEGIN
		ASSERT(register IN {SAR, DAR});
		D8(program, 54H+register);
		D16(program,imm);
	END DMAADDH;

	PROCEDURE DMAADNH * (VAR program: Program; register: LONGINT; imm: LONGINT);
	BEGIN
		ASSERT(register IN {SAR, DAR});
		D8(program, 5CH+register);
		D16(program,imm);
	END DMAADNH;

	PROCEDURE DMAEND * (VAR program: Program);
	BEGIN
		C8(program, 0X);
	END DMAEND;

	PROCEDURE DMAFLUSHP * (VAR program: Program; peripheral: LONGINT);
	BEGIN
		C8(program, 35X);
		D8(program, ASH(peripheral,3));
	END DMAFLUSHP;

	PROCEDURE DMAGO * (VAR program: Program; nonSecure: BOOLEAN; channel: LONGINT; adr: ADDRESS);
	BEGIN
		IF nonSecure THEN
			C8(program, 0A2X);
		ELSE
			C8(program,0A0X);
		END;
		D8(program,channel);
		D32(program,adr);
	END DMAGO;

	PROCEDURE DMAKILL * (VAR program: Program);
	BEGIN
		C8(program, 01X);
	END DMAKILL;

	PROCEDURE DMALD * (VAR program: Program; S, B: BOOLEAN);
	BEGIN
		ASSERT(~S OR ~B);
		IF S THEN C8(program, 05X);
		ELSIF B THEN C8(program,07X);
		ELSE
			C8(program, 04X);
		END;
	END DMALD;

	PROCEDURE DMALDP * (VAR program: Program; S, B: BOOLEAN; peripheral: LONGINT);
	BEGIN
		ASSERT(~S OR ~B);
		IF S THEN C8(program, 25X);
		ELSIF B THEN C8(program,27X);
		ELSE HALT(100);
		END;
		D8(program,ASH(peripheral, 3));
	END DMALDP;

	PROCEDURE DMALP * (VAR program: Program; count: LONGINT);
	BEGIN
		ASSERT((0<=count) & (count < 100H));
		IF program.label0Offset < 0 THEN
			C8(program,20X);
			D8(program,count);
			program.label0Offset := program.offset;
			program.label0LPFE := FALSE;
		ELSE
			ASSERT(program.label1Offset < 0);
			C8(program, 22X);
			D8(program,count);
			program.label1Offset := program.offset;
			program.label1LPFE := FALSE;
		END;
	END DMALP;

	PROCEDURE DMALPEND * (VAR program: Program; S,B: BOOLEAN);
	VAR v: LONGINT; loopReg1: BOOLEAN; backward: LONGINT; lpfe: BOOLEAN;
	BEGIN
		ASSERT(program.label0Offset >= 0);
		IF program.label1Offset < 0 THEN
			loopReg1 := FALSE;
			backward := program.offset - program.label0Offset;
			program.label0Offset := -1;
			lpfe := program.label0LPFE;
		ELSE
			loopReg1 := TRUE;
			backward := program.offset - program.label1Offset;
			program.label1Offset := -1;
			lpfe := program.label1LPFE;
		END;
		ASSERT(~S OR ~B);
		v := 28H;
		IF S THEN INC(v,1)
		ELSIF B THEN INC(v,3)
		END;
		IF ~lpfe THEN INC(v, 10H) ELSE loopReg1 := TRUE END;
		IF loopReg1 THEN INC(v,4) END;
		D8(program,v);
		D8(program,backward);
	END DMALPEND;

	PROCEDURE DMALPFE * (VAR program: Program);
	BEGIN
		IF program.label0Offset < 0 THEN
			program.label0Offset := program.offset;
			program.label0LPFE := TRUE;
		ELSE
			ASSERT(program.label1Offset < 0);
			program.label1Offset := program.offset;
			program.label1LPFE := TRUE;
		END;
	END DMALPFE;

	PROCEDURE DMAMOV * (VAR program: Program; register: LONGINT; imm32: LONGINT);
	BEGIN
		ASSERT(register IN {SAR, DAR, CCR});
		C8(program, 0BCX);
		D8(program, register);
		D32(program, imm32);
	END DMAMOV;

	PROCEDURE DMANOP * (VAR program: Program);
	BEGIN
		C8(program, 18X);
	END DMANOP;

	PROCEDURE DMARMB * (VAR program: Program);
	BEGIN
		C8(program, 12X);
	END DMARMB;

	PROCEDURE DMASEV * (VAR program: Program; eventNum: LONGINT);
	BEGIN
		C8(program, 34X);
		D8(program, ASH(eventNum, 3));
	END DMASEV;

	PROCEDURE DMAST * (VAR program: Program; S, B: BOOLEAN);
	BEGIN
		ASSERT(~B OR ~S);
		IF S THEN C8(program, 09X)
		ELSIF B THEN C8(program, 0BX)
		ELSE C8(program, 08X)
		END;
	END DMAST;

	PROCEDURE DMASTZ * (VAR program: Program);
	BEGIN
		C8(program, 0CX)
	END DMASTZ;

	PROCEDURE DMAWFE * (VAR program: Program; eventNum: LONGINT; invalid: BOOLEAN);
	BEGIN
		C8(program, 36X);
		IF invalid THEN D8(program, 2 + ASH(eventNum, 3))
		ELSE D8(program, ASH(eventNum, 3))
		END;
	END DMAWFE;

CONST
	Single = 0; Peripheral = 1; Burst=2; (* do not change values, used in encoding *)

	PROCEDURE DMAWFP * (VAR program: Program; peripheral: LONGINT; mode: LONGINT);
	BEGIN
		ASSERT(mode IN {Single,Burst,Peripheral});
		D8(program, 30H + mode);
		D8(program, ASH(peripheral,3));
	END DMAWFP;

	PROCEDURE DMAWMB * (VAR program: Program);
	BEGIN
		C8(program, 13X);
	END DMAWMB;

	PROCEDURE StartDMAThread * (CONST transferProg: Program; channel: LONGINT);
	VAR dbg: LONGINT; program: Program; programAdr: ADDRESS;
	BEGIN
		(*Trace.String("Starting DMA program on channel "); Trace.Int(channel, 0); Trace.Ln;*)
		programAdr := ADDRESSOF(transferProg.code[0]);
		(*Trace.String("	prog adr:	"); Trace.Address(programAdr); Trace.Ln;*)
		REPEAT
			SYSTEM.GET(BaseAddress+DBGSTATUS_Offset, dbg)
		UNTIL dbg MOD 2 = 0; (* DMA still busy otherwise *)
		(* encode DMAGO *)
		InitProgram(program);
		DMAGO(program, FALSE, channel, programAdr);
		
		(*SysUtils.DCacheFlushRange(programAdr,1024);*)
		Machine.FlushDCacheRange(programAdr, 128);
		Machine.FlushDCacheRange(ADDRESSOF(program.code[0]), 128);
		
		(* write instruction 1 *)
		SYSTEM.PUT32(BaseAddress+DBGINST0_Offset, ASH(channel,8) + ASH(ORD(program.code[0]),16) + ASH(ORD(program.code[1]),24));
		SYSTEM.PUT32(BaseAddress+DBGINST1_Offset, ORD(program.code[2]) + ASH(ORD(program.code[3]),8) + ASH(ORD(program.code[4]),16) + ASH(ORD(program.code[5]),24));
		(* start the command *)
		SYSTEM.PUT32(BaseAddress+DBGCMD_Offset, 0);
	END StartDMAThread;

	PROCEDURE Log2(size: LONGINT): LONGINT;
	VAR val: LONGINT;
	BEGIN
		val := 0;
		WHILE size > 1 DO size := size DIV 2; INC(val) END;
		RETURN val;
	END Log2;

	CONST SI * = 1; DI * = 4000H;

	PROCEDURE SS * (size: LONGINT): LONGINT;
	BEGIN
		RETURN Log2(size DIV 8) * 02H (* bits 1..3 *)
	END SS;

	PROCEDURE SB * (size: LONGINT): LONGINT;
	BEGIN
		ASSERT((1<=size) & (size <=16));
		RETURN (size-1) * 10H (* bits 4..7 *)
	END SB;

	PROCEDURE SP * (prot: LONGINT): LONGINT;
	BEGIN
		RETURN prot * 100H (* bits 8..10 *)
	END SP;

	PROCEDURE SC * (cache: LONGINT): LONGINT;
	BEGIN
		RETURN cache * 800H; (* bits 11..13 *)
	END SC;

	PROCEDURE DS * (size: LONGINT): LONGINT;
	BEGIN
		RETURN Log2(size DIV 8) * 8000H (* bits 15.. 17 *)
	END DS;

	PROCEDURE DB * (size: LONGINT): LONGINT;
	BEGIN
		ASSERT((1<=size) & (size <=16));
		RETURN (size-1) * 40000H (* bits 18..21 *)
	END DB;

	PROCEDURE DP * (prot: LONGINT): LONGINT;
	BEGIN
		RETURN prot * 400000H (* bits 22..24 *)
	END DP;

	PROCEDURE DC * (cache: LONGINT): LONGINT;
	BEGIN
		RETURN cache * 2000000H; (* bits 25..27 *)
	END DC;

	PROCEDURE ES * (size: LONGINT): LONGINT;
	BEGIN
		RETURN Log2(size DIV 8) * 10000000H; (* bits 28..30 *)
	END ES;

	PROCEDURE SimpleTest*(): BOOLEAN;
	VAR
		(*program: Program;*)
		i, srcOfs, dstOfs, srcAdr, dstAdr: LONGINT;
		srcBuf, dstBuf: POINTER TO ARRAY OF CHAR;
		pre, tx, post: BOOLEAN; (* error markers *)
	BEGIN
		NEW(srcBuf, Size); NEW(dstBuf, Size);
		srcOfs := 8 - ADDRESSOF(srcBuf[0]) MOD 8;
		dstOfs := 8 - ADDRESSOF(dstBuf[0]) MOD 8;
		srcAdr := ADDRESSOF(srcBuf[srcOfs]);
		dstAdr := ADDRESSOF(dstBuf[dstOfs]);
		ASSERT(srcAdr MOD 8 = 0);
		ASSERT(dstAdr MOD 8 = 0);
		program.offset := 0;
		InitProgram(program);
		DMAMOV(program, CCR, SI+SB(4)+SS(64)+DI+DB(4)+DS(64));
		DMAMOV(program, SAR, srcAdr);
		DMAMOV(program, DAR, dstAdr);
		DMALP(program, 31);
		DMALD(program, FALSE, FALSE);
		DMAST(program, FALSE, FALSE);
		DMALPEND(program, FALSE, FALSE);

		DMARMB(program);
		DMAWMB(program);
		DMASEV(program, 0); (* send interrupt to processor *)
		DMAEND(program);

		FOR i := 0 TO Size - 1 DO
			srcBuf[i] := CHR(gen.Dice(100H));
			dstBuf[i] := CHR(i MOD 100H)
		END;
		Machine.FlushDCacheRange(ADDRESSOF(srcBuf[0]), Size);
		Machine.FlushDCacheRange(ADDRESSOF(dstBuf[0]), Size);

		busy := TRUE;
		StartDMAThread(program, 0);

		REPEAT UNTIL ~busy;

		Machine.InvalidateDCacheRange(ADDRESSOF(dstBuf[0]), Size);

		FOR i := 0 TO dstOfs - 1 DO
			IF dstBuf[i] # CHR(i MOD 100H) THEN
				Trace.String(" -> Error Flushing: "); Trace.Int(i, 4); Trace.String(", "); Trace.Hex(ORD(dstBuf[i]), -2);
				Trace.String(", "); Trace.Hex(i MOD 100H, -2); Trace.Ln;
				(*RETURN FALSE*)
				pre := TRUE
			END;
		END;
		IF ~pre THEN Trace.String(" -> No error from 0 to "); Trace.Int(dstOfs - 1, 0); Trace.Ln END;

		FOR i := 0 TO 1023 DO
			IF srcBuf[i + srcOfs] # dstBuf[i + dstOfs] THEN
				Trace.String(" -> Error :: "); Trace.Int(i, 0); Trace.String(" :: "); Trace.Hex(ORD(srcBuf[i + srcOfs]), -2);
				Trace.String(" :: "); Trace.Hex(ORD(dstBuf[i + dstOfs]), -2); Trace.Ln;
				(*RETURN FALSE*)
				tx := TRUE
			END;
		END;
		IF ~tx THEN Trace.String(" -> No error from "); Trace.Int(dstOfs, 0); Trace.String(" to "); Trace.Int(dstOfs + 1023, 0); Trace.Ln END;

		FOR i := dstOfs + 1024 TO Size - 1 DO
			IF dstBuf[i] # CHR(i MOD 100H) THEN
				Trace.String(" -> Error Flushing: "); Trace.Int(i, 4); Trace.String(", "); Trace.Hex(ORD(dstBuf[i]), -2);
				Trace.String(", "); Trace.Hex(i MOD 100H, -2); Trace.Ln;
				(*RETURN FALSE*)
				post := TRUE
			END;
		END;
		IF ~post THEN Trace.String(" -> No error from "); Trace.Int(dstOfs + 1024, 0); Trace.String(" to "); Trace.Int(Size - 1, 0); Trace.Ln END;

		RETURN ~(pre & tx & post)
	END SimpleTest;

	PROCEDURE SimpleTestStack*(): BOOLEAN;
	VAR
		(*program: Program;*)
		srcBuf, dstBuf: ARRAY Size OF CHAR;
		i, srcOfs, dstOfs, srcAdr, dstAdr: LONGINT;
		pre, tx, post: BOOLEAN;
	BEGIN
		srcOfs := 8 - ADDRESSOF(srcBuf[0]) MOD 8;
		dstOfs := 8 - ADDRESSOF(dstBuf[0]) MOD 8;
		srcAdr := Machine.PhysicalAdr(ADDRESSOF(srcBuf[srcOfs]), 1);
		dstAdr := Machine.PhysicalAdr(ADDRESSOF(dstBuf[dstOfs]), 1);
		ASSERT(srcAdr MOD 8 = 0);
		ASSERT(dstAdr MOD 8 = 0);
		program.offset := 0;
		InitProgram(program);
		DMAMOV(program, CCR, SI+SB(4)+SS(64)+DI+DB(4)+DS(64));
		DMAMOV(program, SAR, srcAdr);
		DMAMOV(program, DAR, dstAdr);
		DMALP(program, 31);
		DMALD(program, FALSE, FALSE);
		DMAST(program, FALSE, FALSE);
		DMALPEND(program, FALSE, FALSE);

		DMARMB(program);
		DMAWMB(program);
		DMASEV(program, 0); (* send interrupt to processor *)
		DMAEND(program);

		FOR i := 0 TO Size - 1 DO
			srcBuf[i] := CHR(gen.Dice(100H));
		END;
		Machine.FlushDCacheRange(ADDRESSOF(srcBuf[0]), Size);
		Machine.FlushDCacheRange(ADDRESSOF(dstBuf[0]), Size);

		busy := TRUE;
		StartDMAThread(program, 0);

		REPEAT UNTIL ~busy;

		Machine.InvalidateDCacheRange(ADDRESSOF(dstBuf[0]), Size);
		FOR i := 0 TO dstOfs - 1 DO
			IF dstBuf[i] # CHR(i MOD 100H) THEN
				Trace.String(" -> Error Flushing: "); Trace.Int(i, 4); Trace.String(", "); Trace.Hex(ORD(dstBuf[i]), -2);
				Trace.String(", "); Trace.Hex(i MOD 100H, -2); Trace.Ln;
				(*RETURN FALSE*)
				pre := TRUE
			END;
		END;
		IF ~pre THEN Trace.String(" -> No error from 0 to "); Trace.Int(dstOfs - 1, 0); Trace.Ln END;

		FOR i := 0 TO 1023 DO
			IF srcBuf[i + srcOfs] # dstBuf[i + dstOfs] THEN
				Trace.String(" -> Error :: "); Trace.Int(i, 0); Trace.String(" :: "); Trace.Hex(ORD(srcBuf[i + srcOfs]), -2);
				Trace.String(" :: "); Trace.Hex(ORD(dstBuf[i + dstOfs]), -2); Trace.Ln;
				(*RETURN FALSE*)
				tx := TRUE
			END;
		END;
		IF ~tx THEN Trace.String(" -> No error from "); Trace.Int(dstOfs, 0); Trace.String(" to "); Trace.Int(dstOfs + 1023, 0); Trace.Ln END;

		FOR i := dstOfs + 1024 TO Size - 1 DO
			IF dstBuf[i] # CHR(i MOD 100H) THEN
				Trace.String(" -> Error Flushing: "); Trace.Int(i, 4); Trace.String(", "); Trace.Hex(ORD(dstBuf[i]), -2);
				Trace.String(", "); Trace.Hex(i MOD 100H, -2); Trace.Ln;
				(*RETURN FALSE*)
				post := TRUE
			END;
		END;
		IF ~post THEN Trace.String(" -> No error from "); Trace.Int(dstOfs + 1024, 0); Trace.String(" to "); Trace.Int(Size - 1, 0); Trace.Ln END;

		RETURN ~(pre & tx & post)
	END SimpleTestStack;

	PROCEDURE InstallFaultHandler * (handler: Objects.EventHandler);
	BEGIN
		Objects.InstallHandler(handler, 45)
	END InstallFaultHandler;

	PROCEDURE InstallDoneHandler * (handler: Objects.EventHandler; channel: LONGINT);
	BEGIN
		IF channel < 5 THEN
			Objects.InstallHandler(handler, 46 + channel)
		ELSE
			Objects.InstallHandler(handler, 72 + channel - 5)
		END
	END InstallDoneHandler;

	PROCEDURE StartupController;
	VAR value, cacheLength: LONGINT; clocks, set: SET; i: LONGINT;
		dword: SET;
	BEGIN
		(* configure clocks *)
		SYSTEM.GET(APER_CLK_CTRL, clocks);
		INCL(clocks, DMA_CPU_2XCLKACT);
		SYSTEM.PUT32(APER_CLK_CTRL, clocks);

		(* configure security state *)
		SYSTEM.GET(BaseAddress+CR0_Offset, set);
		INCL(set, 2); (* TZ_DMA_NS was High at reset *)
		SYSTEM.PUT32(BaseAddress+CR0_Offset, set);
		DSet("CR0", set);

		(* reset *)
		SYSTEM.PUT32(DMAC_RST_CTRL, 1);

		(* set interrupt modes to edge-sensitive *)
		SYSTEM.GET(Platform.ICDICFR + 2 * 4, dword);
		dword := dword + {31, 30, 29, 28, 27, 26};
		SYSTEM.PUT32(Platform.ICDICFR + 2 * 4, dword);
		SYSTEM.GET(Platform.ICDICFR + 3 * 4, dword);
		dword := dword + {3, 2, 1, 0};
		SYSTEM.PUT32(Platform.ICDICFR + 3 * 4, dword);

		(* create interrupt service routines *)
		(* fault handler *)
		Machine.InstallHandler(FaultHandler, 45);
		(*Kernel.EnableIRQ(45, TRUE);*)
		(* done handlers for channels 1-4 *)
		FOR i := 46 TO 49 DO
			Machine.InstallHandler(DoneHandler, i);
			(*Kernel.EnableIRQ(i, TRUE);*)
		END;
		(* done handlers for channels 5-8 *)
		FOR i := 72 TO 75 DO
			Machine.InstallHandler(DoneHandler, i);
			(*Kernel.EnableIRQ(i, TRUE);*)
		END;

		(* get characteristic values *)

		SYSTEM.GET(BaseAddress+CR1_Offset, value);
		cacheLength := value MOD 8;
		IF (cacheLength <2) OR (cacheLength >5) THEN
			cacheLength := 0
		ELSE
			cacheLength := ASH(1, cacheLength);
		END;
		DHex("cacheLength",cacheLength);

		SYSTEM.PUT32(BaseAddress+INTEN_Offset, {0..31}); (* set all events to interrupts *)

		(* execute DMA transfers *)
	END StartupController;

BEGIN
	BaseAddress := dmac0_s;
	StartupController;
	NEW(gen);

	count := 0;
	FOR current := 1 TO Repeats DO
		Trace.String(" => Heap Test #"); Trace.Int(current, 0); Trace.Ln;
		IF ~SimpleTest() THEN
			INC(count)
		END;
	END;
	Trace.String(" :: Heap Transfer Errors: "); Trace.Int(count, 0); Trace.String("/"); Trace.Int(Repeats, 0); Trace.Ln;

	count := 0;
	FOR current := 1 TO Repeats DO
		Trace.String(" => Stack Test #"); Trace.Int(current, 0); Trace.Ln;
		IF ~SimpleTestStack() THEN
			INC(count)
		END;
	END;
	Trace.String(" :: Stack Transfer Errors: "); Trace.Int(count, 0); Trace.String("/"); Trace.Int(Repeats, 0); Trace.Ln
END DMA330.

Compiler.Compile -b=ARM --traceModule=Trace --objectFile=Generic --initLocals
	basel/ARM.A2/DMA330Test.Mod
~

StaticLinker.Link --fileName=Test.Bin --displacement=100000H -a
	Initializer Runtime Platform FPE64 ARMRuntime Trace Uart Machine
	Heaps Modules Objects Kernel
	Math Random
	DMA330
~
