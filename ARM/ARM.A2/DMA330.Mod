MODULE DMA330; (** AUTHOR "Timothee Martiel, 2015"; PURPOSE "Driver for CoreLink DMA-330"; *)

(* Code mostly written by F. Friedrich *)

IMPORT Platform, Machine, Objects, Trace, SYSTEM;

CONST


	slcr = 0F8000000H; (* system level control register *)
	APER_CLK_CTRL = slcr + 12CH; (* AMBA peripheral clock control *)
	DMAC_RST_CTRL = slcr + 20CH; (* DMAC Software Reset Control *)

	DMA_CPU_2XCLKACT = 0; (* DMA Controller clock control *)

	dmac0_ns * = 0F8004000H; (* DMA non secure base address *)
	dmac0_s * = 0F8003000H; (* DMA secure base address *)

	CR0_Offset * = 0E00H; (* Configuration Register 0 *)
	CR1_Offset * = 0E04H; (* Configuration Register 1 *)
	CR2_Offset * = 0E08H; (* Configuration Register 2 *)
	CR3_Offset * = 0E0CH; (* Configuration Register 3 *)
	CR4_Offset * = 0E10H; (* Configuration Register 4 *)
	INT_EVENT_RIS_Offset = 24H; (* Event Interrupt Raw Status *)
	INTCLR_Offset = 2CH; (* Interrupt Clear *)
	INTEN_Offset = 20H; (* interrupt enable *)
	DBGSTATUS_Offset = 0D00H; (* DMA Manager execution status *)
	DBGCMD_Offset = 0D04H; (* DMA Manager Instr. Command *)
	DBGINST0_Offset	= 0D08H; (* DMA Manager instruction part A *)
	DBGINST1_Offset	= 0D0CH; (* DMA Manager instruction part A *)
	FSRD_Offset * =  30H; (* Fault Status *)
	FSRC_Offset * = 34H; (* Fault Status DMA Channel *)
	FTRD_Offset * = 38H; (* Fault Type DMA Manager *)
	FTRn_Offset * = 40H; (* Fault Type DMA Channel base address *)
	CSR0_Offset * = 100H;
	CSR1_Offset * = 108H;
	CSR2_Offset * = 110H;
	CPC0_Offset * = 104H;
	CPC1_Offset * = 10CH;
	CPC2_Offset * = 114H;

	TracePrograms * = FALSE;

TYPE
	Program * = RECORD
		code: ARRAY 128 OF CHAR;
		offset *: LONGINT;
		label0Offset, label1Offset: LONGINT; (* offset of loop 0 and loop1. Negative value indicates unused *)
		label0LPFE, label1LPFE: BOOLEAN;
	END;

VAR
	(*program: Program;
	srcBuf, dstBuf: POINTER TO ARRAY 3 * 1024 + 8 OF CHAR;
	srcAdr, dstAdr,*) BaseAddress: ADDRESS;
	doneHandler: PROCEDURE (channel: LONGINT);
	faultHandler: PROCEDURE (channel, fault: LONGINT);

	PROCEDURE DHex(CONST s: ARRAY OF CHAR; val: LONGINT);
	BEGIN
		Trace.String(s); Trace.String(" "); Trace.Hex(val,-8); Trace.StringLn("H");
	END DHex;

	PROCEDURE DSet(CONST s: ARRAY OF CHAR; val: SET);
	BEGIN
		Trace.String(s); Trace.String(" "); Trace.Bits(val,0,32); Trace.Ln;
	END DSet;

	PROCEDURE FaultHandler * (*VAR state: Machine.State*);
	VAR
		fault: BOOLEAN;
		faultChannels: SET;
		program: Program;
		status, i, busy: LONGINT;
	BEGIN
		(*Trace.StringLn("DMA: FaultHandler called");*)
		fault := SYSTEM.GET32(BaseAddress + FSRD_Offset) MOD 2 = 1;
		IF fault THEN
			(* DMA Kill *)
			DMAKILL(program);

			IF faultHandler # NIL THEN
				status := SYSTEM.GET32(BaseAddress + FTRD_Offset);
				faultHandler(-1, status)
			END
		END;

		SYSTEM.GET(BaseAddress+FSRC_Offset, faultChannels);
		faultChannels := faultChannels * {0..7}; i := 0;
		WHILE (i<8) & (faultChannels # {}) DO
			IF i IN faultChannels THEN
				EXCL(faultChannels, i);

				(* Read reason *)
				IF faultHandler # NIL THEN
					status := SYSTEM.GET32(BaseAddress + FTRn_Offset + 4 * i);
					faultHandler(i, status)
				END;

				(* Execute DMAKILL for channel i *)
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

	PROCEDURE DoneHandler * (*VAR state: Machine.State*);
	VAR
		reason: SET;
		channel: LONGINT;
	BEGIN
		(* Get reason, i.e. active events *)
		SYSTEM.GET(BaseAddress+INT_EVENT_RIS_Offset, reason);
		(* clear IRQ *)
		SYSTEM.PUT32(BaseAddress+INTCLR_Offset, reason);
		(* inform application *)
		IF doneHandler # NIL THEN
			FOR channel := 0 TO 31 DO
				IF channel IN reason THEN
					doneHandler(channel)
				END
			END
		END
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
		IF TracePrograms THEN
			Trace.Address(ADDRESSOF(program.code[program.offset]));
			Trace.String(": ");
			Trace.String("DMAADDH ");
			CASE register OF
				 SAR: Trace.String("SAR")
				|DAR: Trace.String("DAR")
			END;
			Trace.String(", ");
			Trace.Int(imm, 0);
			Trace.Ln
		END;
		D8(program, 54H+register);
		D16(program,imm);
	END DMAADDH;

	PROCEDURE DMAADNH * (VAR program: Program; register: LONGINT; imm: LONGINT);
	BEGIN
		ASSERT(register IN {SAR, DAR});
		IF TracePrograms THEN
			Trace.Address(ADDRESSOF(program.code[program.offset]));
			Trace.String(": ");
			Trace.String("DMAADDNH ");
			CASE register OF
				 SAR: Trace.String("SAR")
				|DAR: Trace.String("DAR")
			END;
			Trace.String(", ");
			Trace.Int(imm, 0);
			Trace.Ln
		END;
		D8(program, 5CH+register);
		D16(program,imm);
	END DMAADNH;

	PROCEDURE DMAEND * (VAR program: Program);
	BEGIN
		IF TracePrograms THEN
			Trace.Address(ADDRESSOF(program.code[program.offset]));
			Trace.String(": ");
			Trace.String("DMAEND ");
			Trace.Ln
		END;
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
		IF TracePrograms THEN
			Trace.Address(ADDRESSOF(program.code[program.offset]));
			Trace.String(": ");
			Trace.String("DMALD");
			Trace.Ln
		END;
		IF S THEN C8(program, 05X);
		ELSIF B THEN C8(program,07X);
		ELSE
			C8(program, 04X);
		END;
	END DMALD;

	PROCEDURE DMALDP * (VAR program: Program; S, B: BOOLEAN; peripheral: LONGINT);
	BEGIN
		ASSERT(~S OR ~B);
		IF TracePrograms THEN
			Trace.Address(ADDRESSOF(program.code[program.offset]));
			Trace.String(": ");
			Trace.String("DMALDP");
			Trace.Ln
		END;
		IF S THEN C8(program, 25X);
		ELSIF B THEN C8(program,27X);
		ELSE HALT(100);
		END;
		D8(program,ASH(peripheral, 3));
	END DMALDP;

	PROCEDURE DMALP * (VAR program: Program; count: LONGINT);
	BEGIN
		ASSERT((0<=count) & (count < 100H));
		IF TracePrograms THEN
			Trace.Address(ADDRESSOF(program.code[program.offset]));
			Trace.String(": ");
			Trace.String("DMALP ");
			Trace.Int(count, 0);
			Trace.Ln
		END;
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
		IF TracePrograms THEN
			Trace.Address(ADDRESSOF(program.code[program.offset]));
			Trace.String(": ");
			Trace.String("DMALPEND");
			Trace.Ln
		END;
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
		IF TracePrograms THEN
			Trace.Address(ADDRESSOF(program.code[program.offset]));
			Trace.String(": ");
			Trace.String("DMAMOV ");
			CASE register OF
				 SAR: Trace.String("SAR")
				|DAR: Trace.String("DAR")
				|CCR: Trace.String("CCR")
			END;
			Trace.String(", ");
			Trace.Hex(imm32, -8);
			Trace.Ln
		END;
		C8(program, 0BCX);
		D8(program, register);
		D32(program, imm32);
	END DMAMOV;

	PROCEDURE DMANOP * (VAR program: Program);
	BEGIN
		IF TracePrograms THEN
			Trace.Address(ADDRESSOF(program.code[program.offset]));
			Trace.String(": ");
			Trace.String("DMANOP");
			Trace.Ln
		END;
		C8(program, 18X);
	END DMANOP;

	PROCEDURE DMARMB * (VAR program: Program);
	BEGIN
		IF TracePrograms THEN
			Trace.Address(ADDRESSOF(program.code[program.offset]));
			Trace.String(": ");
			Trace.String("DMARMB");
			Trace.Ln
		END;
		C8(program, 12X);
	END DMARMB;

	PROCEDURE DMASEV * (VAR program: Program; eventNum: LONGINT);
	BEGIN
		IF TracePrograms THEN
			Trace.Address(ADDRESSOF(program.code[program.offset]));
			Trace.String(": ");
			Trace.String("DMASEV ");
			Trace.Int(eventNum, 0);
			Trace.Ln
		END;
		C8(program, 34X);
		D8(program, ASH(eventNum, 3));
	END DMASEV;

	PROCEDURE DMAST * (VAR program: Program; S, B: BOOLEAN);
	BEGIN
		ASSERT(~B OR ~S);
		IF TracePrograms THEN
			Trace.Address(ADDRESSOF(program.code[program.offset]));
			Trace.String(": ");
			Trace.String("DMAST ");
			Trace.Ln
		END;
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
	Single * = 0; Peripheral * = 1; Burst * = 2; (* do not change values, used in encoding *)

	PROCEDURE DMAWFP * (VAR program: Program; peripheral: LONGINT; mode: LONGINT);
	BEGIN
		ASSERT(mode IN {Single,Burst,Peripheral});
		IF TracePrograms THEN
			Trace.Address(ADDRESSOF(program.code[program.offset]));
			Trace.String(": ");
			Trace.String("DMAWFP ");
			Trace.Int(peripheral, 0);
			Trace.String(", ");
			CASE mode OF
				 Single: Trace.String("single")
				|Peripheral: Trace.String("peripheral")
				|Burst: Trace.String("burst")
			END;
			Trace.Ln
		END;
		D8(program, 30H + mode);
		D8(program, ASH(peripheral,3));
	END DMAWFP;

	PROCEDURE DMAWMB * (VAR program: Program);
	BEGIN
		IF TracePrograms THEN
			Trace.Address(ADDRESSOF(program.code[program.offset]));
			Trace.String(": ");
			Trace.String("DMAWMB");
			Trace.Ln
		END;
		C8(program, 13X);
	END DMAWMB;

	PROCEDURE StartDMAThread * (CONST transferProg: Program; channel: LONGINT);
	VAR dbg: LONGINT; program: Program; programAdr: ADDRESS;
	BEGIN
		programAdr := ADDRESSOF(transferProg.code[0]);
		Machine.FlushDCacheRange(programAdr, 128);

		REPEAT
			SYSTEM.GET(BaseAddress+DBGSTATUS_Offset, dbg)
		UNTIL dbg MOD 2 = 0; (* DMA still busy otherwise *)
		(* encode DMAGO *)
		InitProgram(program);
		DMAGO(program, FALSE, channel, programAdr);
		
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

	(*PROCEDURE SimpleTest*;
	VAR
		(*program: Program;*)
		i, srcPhys, dstPhys: LONGINT;
	BEGIN
		Trace.StringLn("SimpleTest Starting");
		NEW(srcBuf); NEW(dstBuf);
		(*srcAdr := 1000000H; dstAdr := 1000000H+1000H;*)
		srcAdr := ADDRESSOF(srcBuf[1024]) + (8 - ADDRESSOF(srcBuf[1024]) MOD 8);
		dstAdr := ADDRESSOF(dstBuf[1024]) + (8 - ADDRESSOF(dstBuf[1024]) MOD 8);
		Trace.String("src address:	"); Trace.Address(srcAdr); Trace.Ln;
		Trace.String("dst address:	"); Trace.Address(dstAdr); Trace.Ln;
		srcPhys := srcAdr;
		dstPhys := dstAdr;
		program.offset := 0;
		InitProgram(program);
		DMAMOV(program, CCR, SI+SB(4)+SS(64)+DI+DB(4)+DS(64));
		DMAMOV(program, SAR, srcPhys);
		DMAMOV(program, DAR, dstPhys);
		DMALP(program, 32);
		DMALD(program, FALSE, FALSE);
		DMAST(program, FALSE, FALSE);
		DMALPEND(program, FALSE, FALSE);

		DMARMB(program);
		DMAWMB(program);
		DMASEV(program, 0); (* send interrupt to processor *)
		DMAEND(program);
		FOR i := 0 TO 3071 + 8 DO
			(*SYSTEM.PUT8(srcAdr+i, CHR(i MOD 100H));
			SYSTEM.PUT8(dstAdr+i, 0X);*)
			srcBuf[i] := CHR(i MOD 80H);
			dstBuf[i] := CHR(i MOD 80H + 80H)
		END;
		Trace.StringLn("Source Data:");
		Trace.Memory(ADDRESSOF(srcBuf[0]), 3072 + 8);
		Trace.StringLn("Dest Data:");
		Trace.Memory(ADDRESSOF(dstBuf[0]), 3072 + 8);
		Machine.FlushDCacheRange(ADDRESSOF(srcBuf[0]), 3072 + 8);
		Machine.FlushDCacheRange(ADDRESSOF(dstBuf[0]), 3072 + 8);

		Trace.StringLn("Starting SimpleTest");
		StartDMAThread(program, 0);
		Trace.StringLn("SimpleTest Started");

		(*Trace.StringLn("Source Data:");
		Trace.Memory(srcAdr, 1024);
		Trace.StringLn("Dest Data:");
		Trace.Memory(dstAdr, 1024);*)
	END SimpleTest;*)

	PROCEDURE InstallFaultHandler * (handler: PROCEDURE (channel, fault: LONGINT));
	BEGIN
		faultHandler := handler
	END InstallFaultHandler;

	PROCEDURE InstallDoneHandler * (handler: PROCEDURE (channel: LONGINT));
	BEGIN
		doneHandler := handler
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
		(*Machine.InstallHandler(FaultHandler, 45);*)
		Objects.InstallHandler(FaultHandler, 45);

		(* done handlers for channels 1-4 *)
		FOR i := 46 TO 49 DO
			(*Machine.InstallHandler(DoneHandler, i);*)
			Objects.InstallHandler(DoneHandler, i);
		END;
		(* done handlers for channels 5-8 *)
		FOR i := 72 TO 75 DO
			(*Machine.InstallHandler(DoneHandler, i);*)
			Objects.InstallHandler(DoneHandler, i);
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
	(*SimpleTest*)
END DMA330.