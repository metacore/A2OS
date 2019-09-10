MODULE Machine; (** AUTHOR "Timothée Martiel"; PURPOSE "Machine abstraction module for ARM"; *)
(**
 * Machine abstraction:
 * - processor management: caches, FPU
 * - interrupts and exceptions
 * - virtual memory management
 *)

IMPORT SYSTEM, Initializer, Trace, Platform, TraceDevice, BootConfig, PrivateWatchdog;

CONST
	Version = "A2 on ARM, revision 4677 (15.10.2017)";
	DefaultObjectFileExtension* = ".Gof";

	(* Interrupts Dummy Test *)
	DummyTest = FALSE;

	(* Lock levels *)
	TraceOutput* = 0;
	Memory* = 1;
	Heaps* = 2;
	Interrupts* = 3	;
	Modules* = 4;
	Objects* = 5;
	Processors* = 6;
	KernelLog* = 7;

	MaxLock = 8;

	(* Unit prefixes *)
	k = 1024;
	M = k * k;
	G = M * k;
	LogM = 20; (* log2(M) *)
	(*LogK = 10;  (* log2(K) *)*)

	(* CPU number *)
	MaxCPU* = 32(*BootConfig.CpuNb*);

	(* If TRUE, enables some assertions in the code *)
	StrongChecks = TRUE;

	(* Page size, in bytes *)
	PS = 4 * k;
	PSlog2 = 12;		(* ASH(1, PSlog2) = PS *)

	PTSize = 400H;	(* size of a coarse page table *)
	(*PTEntries = 100H;	(* 32bit entries per page table *)*)

	(* Absolute maximal process stack numbers *)
	MaxStackNb = 1024;

	(* Hard limit on cache reference size *)
	MaxCacheRefSize = M;

	(* Interrupt Vector base. Valid only after MMU is enabled *)
	InterruptVector = 0FFFF0000H;

	(* Interrupts *)
	MinIRQ* = 0;
	MaxIRQ* = 255;
	IRQ0* = MinIRQ; (* Alias *)
	(** ID of the global timer IRQ *)
	TimerIRQ* = 27;
	PrivateTimerIRQ* = 29;

	MaxIRQHandlers = 16;

	(* Exceptions codes. DO NOT CHANGE: they represent interrupt vector offsets *)
	Reset * = 20H;		(** Reset *)
	Undef * = 24H;	(** Undefined Exception *)
	Swi * = 28H;		(** Software Interrupt *)
	Prefetch * = 2CH;	(** Prefetch Abort *)
	Data * = 30H;		(** Data Abort *)
	Irq * = 38H;		(** Interrupt Request *)
	Fiq * = 3CH;		(** Fast Interrupt *)

	(* Initial Stack size for user stacks *)
	(*InitUserStackSize = PS;*)

	HeapMin = 50;					(* "minimum" heap size as percentage of total memory size (used for heap expansion in scope of GC ) *)
	HeapMax = 95;				(* "maximum" heap size as percentage of total memory size (used for heap expansion in scope of GC) *)
	ExpandRate = 1;				(* always extend heap with at least this percentage of total memory size *)
	Threshold = 10;				(* periodic GC initiated when this percentage of total memory size bytes has "passed through" NewBlock *)

	(* Stack parameters *)
	InitStackSize = PS;
	StackGuardSize = PS;

	(* access permissions *)
	SrwUrw = 3;
	FullAccess = (*SrwUrw*400H+SrwUrw*100H+SrwUrw*40H+*)SrwUrw*10H; (* for small pages only *)
	LastStackPage = SrwUrw*400H+SrwUrw*100H+SrwUrw*40H; (* for small pages only *)

	(* first level page table types *)
	flCoarse = 1;
	flSection = 2;

	(* Second Level *)
	slFault = 0;
	slSmall = 2;

	(* cachable/bufferable mapping options *)
	cb = 0;
	C = 8;
	B = 4;
	CB = C + B + 440H;
	(* Inner and Outer Cacheable, Write-Through, no Write Allocate *)
	Cacheable = 100CH; (* here inner cacheable, write-back, write-allocate *)
	(* Shareable *)
	Shareable = 10000H;

	(* NIL *)
	NilAdr* = -1;

	(* Control Register Flags *)
	DCache = 2;
	ICache = 12;

	Second* = 1000; (* frequency of ticks increments in Hz *)

	Preemption* = 31;	(** flag for BreakAll() *)

	(** Period at which the CPU timer interrupts, in micro seconds *)
	TimerPeriod* = 1000;

	(** Last reboot info *)
	RebootPowerOn * = 0;
	RebootHardReset * = 1;
	RebootSoftReset * = 2;
	RebootSystemWatchdog * = 3;
	RebootWatchdogCPU0 * = 4;
	RebootWatchdogCPU1 * = 5;
	RebootDebug * = 6;

	(** Needed, but not used yet by Reals.Mod *)
	fcr * = {};

TYPE
	(** processor state *)
	State* = RECORD
		R*: ARRAY 12 OF ADDRESS;		(** registers 0-11 *)
		BP*, SP*, LR*, PC*: ADDRESS;	(** special registers *)
		PSR*: ADDRESS;					(** processor state register *)
		INT*: ADDRESS;					(** IRQ number *)
	END;

	(** NEON Coprocessor state *)
	NEONState* = RECORD
		D*: ARRAY 32 OF SIGNED64; (* 32 64-bits registers *)
		FPSCR*: ADDRESS;
		FPEXC*: ADDRESS;
	END;

	(** exception state *)
	ExceptionState* = RECORD
		halt*: SIGNED32;	 	(** halt code *)
		instn*: SIGNED32;		(** undefined instruction *)
		pf*: ADDRESS;		(** page fault address *)
		status*: SIGNED32;	(** page fault status *)
		locks*: SET;			(** active locks *)
	END;

	(** Interrupt Hanlder *)
	Handler* = PROCEDURE {DELEGATE} (VAR state: State);
	EventHandler = PROCEDURE (id: SIGNED32; CONST state: State);

	(** Spinlock *)
	Lock = RECORD
		locked: BOOLEAN;
		(* Padding to the granularity of exclusive monitor: 8 words on Cortex-A9 *)
		pad: ARRAY 31 OF CHAR;
	END;

	(** Processor status *)
	Proc* = RECORD
		locksHeld*: SET;
		preemptCount*: SIGNED32;
		(*nestCount-: SIGNED32;	(** total locks held by a processor *)*)
		intStatus*, mmu*: BOOLEAN; (* muu: if the MMU is enabled for this processor *)
	END;

	(** Virtual/physical address pair *)
	AddressTuple = RECORD virtual, physical: ADDRESS; END;

	(** Stack descriptor:
	low:	lowest possible stack address
	adr:	current lowest allocated address
	high:	highest address
	*)
	Stack* = RECORD
		low: ADDRESS;
		adr*: ADDRESS;
		high*: ADDRESS;
	END;

	(** Heap memory block *)
	MemoryBlock* = POINTER TO MemoryBlockDesc;
	MemoryBlockDesc* = RECORD
		next- {UNTRACED}: MemoryBlock;
		startAdr-: ADDRESS; 		(* unused field for I386 *)
		size-: SIZE; 					(* unused field for I386 *)
		beginBlockAdr-, endBlockAdr-: ADDRESS
	END;

	Address32* = ADDRESS;
	Range* = RECORD
		adr*: ADDRESS; size*: SIZE;
	END;

	CacheRefs = POINTER {UNSAFE,UNTRACED} TO ARRAY MaxCacheRefSize OF SIGNED8;
VAR
	version -: ARRAY 64 OF CHAR;

	sp, fp: ADDRESS;

	(** Interrupt Mask *)
	IRQMask: SET;
	(** IRQ Handlers. IRQ can have multiple handlers. Dispatching to those is done in IRQGlue and IRQCaller. *)
	irqHandler: ARRAY MaxIRQ + 1, MaxIRQHandlers OF Handler;

	(* Exception handlers. Called by *Glue. *)
	undefHandler, swiHandler, prefetchHandler, dataHandler, fiqHandler: Handler;

	stateTag: SIGNED32;
	dummyIRQHandler: ARRAY MaxIRQ+1 OF RECORD h: Handler; END;

	(** Low level locks *)
	lock: ARRAY MaxLock OF Lock;

	(** Processors status:
	- locksHeld:		set of low-level locks held by the processor
	- preemptCount:	preemption counter
	*)
	proc-: ARRAY MaxCPU OF Proc;
	(** IDs of all successfully started processors. *)
	allProcessors-: SET;

	heapHigh, heapLow, stackHigh, stackLow: AddressTuple;

	(* Memory *)
	pageTable: RECORD virtual, memory: ADDRESS END;	  (* contains the virtual & memory address of the first level page table *)
	memory: RECORD size, free: SIZE; END;
	stackPT: ADDRESS;

	(* Free stack bitmap: each set element is set to indicate free stack *)
	freeStack: ARRAY (MaxStackNb + 31) DIV 32 OF SET;
	freeStackIndex: SIZE;

	(* Address of the highest free page *)
	freePage: ADDRESS;

	(* Memory blocks -- For the heap *)
	memBlockHead-{UNTRACED}, memBlockTail-{UNTRACED}: MemoryBlock;
	initialMemBlock: MemoryBlockDesc;

	dCacheBase: ADDRESS;

	(** GC parameters *)
	expandMin, heapMinKB, heapMaxKB : SIZE;
	gcThreshold: SIZE;

	(** For preemptive scheduling. *)
	Timeslice*: Handler;
	timer: EventHandler;

	(** timer ticks. Written to by GetTicks. Read-only *)
	ticks*: SIGNED32;
	eventCount, eventMax: SIGNED32;
	event: Handler;

	(** Number of processor used. *)
	numProcessors*: SIGNED32;
	numberOfProcessors: SIGNED32;

	(** Scheduling start procedure for non-booting processors. *)
	start*: PROCEDURE;

	(** Upcall to get current stack -- used for stack extension *)
	getStack*: PROCEDURE (VAR stack: Stack);

	(* Memory Layout *)
	(* The system area contains:
	 *		- the interrupt vector, which will be mapped high
	 *		- interrupt stacks
	 *		- the page table
	 * Except for the first 4kB page, it is mapped 1:1.
	 *)
	memSysLowStart,
	memSysLowStop,
	(* The heap area contains:
	 *		- the static kernel image
	 *		- the heap
	 * The heap is mapped 1:1 with 1MB pages.
	 *)
	memHeapStart,
	memHeapStop,
	(* Process Stacks are allocated in this area.
	 * Stacks are mapped with 4kB pages. They take at least 2 pages:
	 *		- 1 for the actual stack
	 *		- 1 kept unmapped as the stack guard.
	 * Stacks are mapped 1:1.
	 * The stack size can be tuned to allow the system to run more processes.
	 *)
	memStackStart,
	memStackStop,
	(* Boot configuration is placed in memory. It takes 4 kB at most *)
	memConfigStart,
	memConfigStop,
	(* IO registers and peripheral control are located in this region. Mapped 1:1 with 1MB and 4kB
	 * pages, as necessary. Mapped as Device memory. *)
	memIOStart,
	memIOStop,
	(* High system memory region. Within the last MB, contains: interrupt vector and reference counts
	 * for caching. *)
	memSysHighStart,
	memSysHighStop,

	(* System Parameters *)
	(* Interrupt stacks. 8kB of virtual space (4kB for stack, 4kB for guard) and 4 stacks per processor. *)
	sysIntStackStart,
	sysIntStackStop,
	(* First Level Page Table: size of 16 * k to map 4GB with 1MB pages. *)
	sysFirstLvlPtStart,
	sysFirstLvlPtStop,
	(*
	 * Second Level Page Table:
	 *		- 2 * 256 entries for the system area (first and last MB of VMem)
	 *		- 256 entries for each MB of virtual stack space
	 * 256 entries take 1kB memory space.
	 *)
	sysSecondLvlPtStart,
	sysSecondLvlPtStop,
	(*
	 * Interrupt Vector. Located at 0FFFFFFF0H
	 *)
	sysVectorStart,
	sysVectorStop,
	sysCacheRefStart,
	sysCacheRefStop,
	(*
	 * Number of ref counters: 1 per 1st level heap page, 1 per 2nd level stack page.
	 * This memory region is organized as follows: the first part [0 .. SysCacheStackOfs) is used for heap pages,
	 * the second part, [SysCacheStackOfs .. SysCacheRefSize) is used for stack pages.
	 *)
	sysCacheRefSize,
	(* Offset in the ref count table for stack pages. *)
	sysCacheStackOfs: ADDRESS;

	(* Process stack system *)
	maxUserStackSize: SIZE;
	maxUserStacks: SIGNED32;

	(* TRUE iff caching should be globally enabled *)
	enableCaching: BOOLEAN;

	(* UART used for kernel output *)
	kernelOutputUart -: SIGNED32;

	(** Interrupt tracing option *)
	traceInterrupts: BOOLEAN;
	(** Trace option for CPU state *)
	traceCpus: BOOLEAN;

	(** Use private watchdog to check scheduling timers? *)
	enableWatchdog: BOOLEAN;

	(** Array of reference counts for page caching *)
	cacheRefs -: CacheRefs;

	(** Reason for last reboot *)
	lastReboot -: SIGNED32;

	(* ===== Processor Management ===== *)
	(* Current processor's ID, between 0 and MaxProc - 1 *)
	PROCEDURE - ID*(): SIGNED32;
	CODE
		MRC p15, 0, R0, C0, C0, 5
		AND R0, R0, #3H; Get the last 2 bits of R0
	END ID;

	(** Enables current processor's L1 caches *)
	PROCEDURE EnableL1Cache;
	CODE
		; Enable Cache and TLB maintenance broadcast
		mrc	p15, 0, r0, c1, c0, 1
		orr	r0, r0, #1H
		mcr	p15, 0, r0, c1, c0, 1
		isb

		; Enable Caching in SCTLR
		mrc	p15, 0, r0, c1, c0, 0
		orr r0, r0, #4H
		mcr	p15, 0, r0, c1, c0, 0
		isb
	END EnableL1Cache;

	(** Enable L2 cache, prefetching and other speculative execution support *)
	PROCEDURE EnableL2Cache;
	CODE
			ldr	r0,[pc, #L2CCCrtl-$-8]			; Load L2CC base address base + control register
			mov	r1, #0				; force the disable bit
			str	r1, [r0,#0]			; disable the L2 Caches

			ldr	r0, [pc, #L2CCAuxCtrl-$-8]			; Load L2CC base address base + Aux control register
			ldr	r1,[r0,#0]				; read the register
			ldr	r2, [pc, #L2CCAuxControl-$-8]		; set the default bits
			orr	r1,r1,r2
			str	r1, [r0,#0]			; store the Aux Control Register

			ldr	r0,[pc, #L2CCTAGLatReg-$-8]		; Load L2CC base address base + TAG Latency address
			ldr	r1, [pc, #L2CCTAGLatency-$-8]		; set the latencies for the TAG
			str	r1, [r0,#0]			; store the TAG Latency register Register

			ldr	r0, [pc, #L2CCDataLatReg-$-8]		; Load L2CC base address base + Data Latency address
			ldr	r1,[pc, #L2CCDataLatency-$-8]		; set the latencies for the Data
			str	r1, [r0,#0]			; store the Data Latency register Register

			ldr	r0,[pc, #L2CCWay-$-8]			; Load L2CC base address base + way register
			ldr	r2, [pc, #H0xffff-$-8]
			str	r2, [r0,#0]			; force invalidate

			ldr	r0, [pc, #L2CCSync-$-8]			; need to poll 0x730, PSS_L2CC_CACHE_SYNC_OFFSET
								; Load L2CC base address base + sync register
			; poll for completion

		Sync:
			ldr	r1, [r0,#0]
			cmp	r1, #0
			bne	Sync

			ldr	r0,[pc, #L2CCIntRaw-$-8]			; clear pending interrupts
			ldr	r1,[r0,#0]
			ldr	r0,[pc, #L2CCIntClear-$-8]
			str	r1,[r0,#0]
			ldr	r0,[pc,#L2CCCrtl-$-8]		; Load L2CC base address base + control register
			ldr	r1,[r0,#0]					; read the register
			mov	r2, #1					; set the enable bit
			orr	r1,r1,r2
			str	r1, [r0,#0]					; enable the L2 Caches

			mrc	p15,0,r0,c1,c0,0		; flow prediction enable
			orr	r0, r0, #0x800		; #0x800
			mcr	p15,0,r0,c1,c0,0
			isb

			mrc	p15,0,r0,c1,c0,1		; read Auxiliary Control Register
			orr	r0, r0, #4				; enable Dside prefetch
			orr	r0, r0, #2				; enable L2 Prefetch hint
			mcr	p15,0,r0,c1,c0,1		; write Auxiliary Control Register
			isb

			b exit
		; Data
		H0xffff: 			d32 0FFFFH
		L2CCWay:			d32 0F8F02000H + 077CH
		L2CCSync:			d32 0F8F02000H + 0730H
		L2CCCrtl:			d32 0F8F02000H + 0100H
		L2CCAuxCtrl:		d32 0F8F02000H + 0104H
		L2CCTAGLatReg: 	d32 0F8F02000H + 0108H
		L2CCDataLatReg: 	d32 0F8F02000H + 010CH
		L2CCIntClear:		d32 0F8F02000H + 0220H
		L2CCIntRaw:		d32 0F8F02000H + 021CH
		L2CCAuxControl:	d32 72360000H
		L2CCTAGLatency:	d32 0111H
		L2CCDataLatency:	d32 0121H

		exit:
	END EnableL2Cache;

	(** Enables the Snoop Control Unit
		for L1 coherency and LDREX/STREX global monitor
	*)
	PROCEDURE EnableSCU;
	CODE
		; set scu enable bit in scu
		ldr	r7, [pc, #H0xf8f00000-$-8]
		ldr	r0, [r7, #0]
		orr	r0, r0, #1
		str	r0, [r7,#0]

		; invalidate scu
		ldr	r7, [pc, #H0xf8f0000c-$-8]
		ldr	r6, [pc, #H0xffff-$-8]
		str	r6, [r7, #0]

		b exit

	; Data
	H0xf8f00000: 		d32 0F8F00000H
	H0xf8f0000c: 		d32 0F8F0000CH
	H0xffff: 			d32 0FFFFH
	exit:
	END EnableSCU;

	(** Init NEON / VFP Engine *)
	PROCEDURE InitFPU;
	CODE
		MRC p15, 0, R0, C1, C0, 2;
		ORR R0, R0, #0x00f00000;
		MCR p15, 0, R0, C1, C0, 2;
		ISB
		MOV R0, #0x40000000;
		VMSR FPEXC, R0;

		VMRS R0, FPSCR
		BIC R0, R0, #0x0c00000 ; round to nearest as the default
		; remark: if we put round to minus infinity as the default, we can spare quite some instructions in emission of ENTIER
		VMSR FPSCR, R0;
	END InitFPU;

	(** Activate the Symmetric Multiprocessing Mode for current CPU.
		This activates L1 cache coherency.
	*)
	PROCEDURE SetSmpMode;
	CODE
		(*
		mrc	p15, 0, r0, c1, c0, 1		/* Read ACTLR*/
		orr	r0, r0, #(0x01 << 6)		/* set SMP bit */
		orr	r0, r0, #(0x01 )		/* */
		mcr	p15, 0, r0, c1, c0, 1		/* Write ACTLR*/
		*)
		MRC p15, 0, R0, C1, C0, 1
		ORR R0, R0, #047H
		MCR p15, 0, R0, C1, C0, 1
		ISB
	END SetSmpMode;

	(** Activate Assymmetric Multiprocessing Mode for current CPU.
		This desactivates L1 cache coherency
	*)
	PROCEDURE SetAmpMode;
	CODE
		MRC p15, 0, R0, C1, C0, 1
		MOV R1, #040H
		RSB R1, R1, #0
		ORR R0, R0, R1
		MCR p15, 0, R0, C1, C0, 1
		ISB
	END SetAmpMode;

	(** Enable coprocessors CP10 and CP11(= VFP and NEON engine) *)
	PROCEDURE EnableCoprocessors;
	CODE
		mov	r0, r0
		mrc	p15, 0, r1, c1, c0, 2		; read cp access control register (CACR) into r1
		orr	r1, r1, #0xf00000		; enable full access for p10 & p11
		mcr	p15, 0, r1, c1, c0, 2		; write back into CACR
		isb
	END EnableCoprocessors;

	(* Initializes a processor. Has to be called once by each processor. *)
	PROCEDURE InitProcessor*;
	BEGIN
		timer := DummyEvent;
		Timeslice := DummyTimeslice;
		SetSmpMode;
		EnableSCU;
		EnableL1Cache;
		InvalidateTLB;
		InvalidateICache;
		Initializer.InvalidateDCache;
		(*InvalidateDCacheRange(0, SYSTEM.VAL(ADDRESS, LastAddress));*)
		(* SCU and L2 caches are enabled in the initialization sequence *)
		EnableL2Cache;
		EnableCoprocessors;
		InitFPU;
		allProcessors := {0}
	END InitProcessor;

	(** Shut system down. If reboot is TRUE, attempts to restart system. *)
	PROCEDURE Shutdown*(reboot: BOOLEAN);
	VAR i: SIGNED32; procs: SET;
	BEGIN
		IF enableWatchdog THEN PrivateWatchdog.Stop END;
		StopTicks;
		Trace.String("Shutting down secondary CPUs... ");
		procs := allProcessors;
		FOR i := 0 TO numberOfProcessors - 1 DO
			IF (i # ID()) & (i IN allProcessors) THEN
				EXCL(allProcessors, i)
			END
		END;
		FOR i := 0 TO numberOfProcessors - 1 DO
			IF (i #ID()) & (i IN procs) THEN
				REPEAT	 UNTIL i IN allProcessors
			END
		END;
		Trace.StringLn("done");

		IF reboot THEN
			Platform.slcr.SLCR_UNLOCK := Platform.SlcrUnlockKey;
			Platform.slcr.PSS_RST_CTRL := 1
		ELSE
			EndInterrupts;
			LOOP
				CODE
					WFE
				END;
			END
		END;
	END Shutdown;

	(** Shut down secondary processors *)
	PROCEDURE ShutdownSecondary;
	BEGIN
		IF enableWatchdog THEN PrivateWatchdog.Stop END;
		INCL(allProcessors, ID());
		LOOP
			CODE
				WFE
			END
		END
	END ShutdownSecondary;

	(** Cleans the whole DCache. Taken from Minos *)
	PROCEDURE CleanDCache *;
	CONST
		L2CCBBase	= 0F8F02000H;
		L2COfs		= L2CCBBase + 7BCH;
		L2CSync	= L2CCBBase + 730H;
	CODE
		; Clean all sets of all ways of L1 cache
		MOV	R0, #0
	WayLoop:
		CMP	R0, #4
		BEQ	EndWayLoop
		LSL		R4, R0, #30
		MOV	R1, #0
	SetLoop:
		CMP	R1, #256
		BEQ	EndSetLoop

		LSL		R3, R1, #5
		ORR	R3, R4, R3
		MCR	P15, 0, R3, C7, C10, 2

		ADD	R1, R1, #1
		B		SetLoop
	EndSetLoop:
		ADD	R0, R0, #1
		B		WayLoop

	EndWayLoop:
		DSB

		; Invalidate all L2 ways
		LDR	R0, [PC, #L2COfsAdr - $ - 8]	; R0 := reg7_inv_way address
		MOV	R1, #0FH			; R1 := 0FH => invalidate all ways
		STR	R1, [R0, #0]		; reg7_inv_way <- R1

	Sync:
		DSB
		LDR	R0, [PC, #L2CSyncAdr - $ - 8]	; R0 := L2 cache sync register address
		MOV	R1, #1
		STR	R1, [R0, #0]		; [R0] := 1
	SyncLoop:						; repeat
		LDR	R1, [R0, #0]		; R1 := l2 cache syc state
		CMP	R1, #0
		BEQ	Exit					; until R1 = 0
		B		SyncLoop

	L2COfsAdr:		d32 L2COfs
	L2CSyncAdr:	d32 L2CSync
	Exit:
	END CleanDCache;

	PROCEDURE FlushDCacheRange*(adr:ADDRESS; len: SIZE);
	CONST
		cacheline = 32;
		L2CCBBase				= 0F8F02000H; (*XPS_L2CC_BASEADDR*)
		L2CCCacheSync		= L2CCBBase + 00730H;		(* Cache Sync *)(*XPS_L2CC_CACHE_SYNC_OFFSET	*)
		L2CCCacheInvClnPAOfs= 007F0H;		(* Cache Clean by PA *)(*XPS_L2CC_CACHE_INV_CLN_PA_OFFSET*)
		L2CCOffset				= L2CCBBase + L2CCCacheInvClnPAOfs;
	BEGIN
		IF ~enableCaching OR (len = 0) THEN RETURN END;
		IF len MOD cacheline # 0 THEN INC(len, cacheline - len MOD cacheline) END;
		IF adr MOD cacheline # 0 THEN DEC(adr, len MOD cacheline) END;
		CODE
			LDR	R0, [FP, #adr]						; R0 := adr
			LDR	R1, [FP, #len]						; R1 := len

			LDR	R2, [PC, #Cacheline - 8 - $]		; R2 := cacheline
			SUB	R3, R2, #1							; R3 := cacheline - 1
			AND	R3, R0, R3							; R3 := adr MOD cacheline

			ADD	R1, R1, R0
			SUB	R0, R0, R3							; R0 := adr - adr MOD cacheline
			;ADD	R1, R1, R3							; R1 := len + adr MOD cacheline

			MOV	R3, #0
			MCR	P15, 2, R3,  C0,  C0, 0				; Select cache level 1
			LDR	R4, [PC, #L2COfs - 8 - $]			; R4 := L2 cache flush address register address

		Loop:
			CMP	R0, R1								; while R0 < R1
			BEQ	Sync
			BHI		Sync

			MCR	P15, 0, R0,  C7, C14, 1				; Clean Cache Level 1 By MVA (R0)
			STR	R0, [R4, #0]						; Clean Cache Level 2 By PA (R0)
			DSB
			ADD	R0, R0, R2							; R0 := R0 + cacheline

			B		Loop								; end

		Sync:
			DSB
			LDR	R0, [PC, #L2CSync - 8 - $]		; R0 := L2 cache sync register address
			;MOV	R1, #1
			;STR	R1, [R0, #0]						; [R0] := 1
		SyncLoop:										; repeat
			LDR	R1, [R0, #0]						; R1 := l2 cache syc state
			CMP	R1, #0
			BEQ	Exit									; until R1 = 0
			B		SyncLoop

		Cacheline:	d32 cacheline
		L2COfs:	d32 L2CCOffset
		L2CSync:	d32 L2CCCacheSync

		Exit:
		END;
	END FlushDCacheRange;

	PROCEDURE FlushDCachePhysRange * (adr: ADDRESS; len: SIGNED32; CONST ranges: ARRAY OF Range; numRanges: SIGNED32);
	CONST
		cacheline = 32;
		L2CCBBase				= 0F8F02000H; (*XPS_L2CC_BASEADDR*)
		L2CCCacheSync		= L2CCBBase + 00730H;		(* Cache Sync *)(*XPS_L2CC_CACHE_SYNC_OFFSET	*)
		L2CCCacheInvClnPAOfs= 007F0H;		(* Cache Clean by PA *)(*XPS_L2CC_CACHE_INV_CLN_PA_OFFSET*)
		L2CCOffset				= L2CCBBase + L2CCCacheInvClnPAOfs;
	VAR
		cur, end: ADDRESS;
		r: SIGNED32;
	BEGIN
		IF ~enableCaching & (len # 0) THEN
			IF len MOD cacheline # 0 THEN INC(len, cacheline - len MOD cacheline) END;
			(* Select cache L0 Data cache in CSSR *)
			CODE
				mov	r0, #0
				mcr	p15, 2, r0,  c0,  c0, 0	(*		mtcp(XREG_CP15_CACHE_SIZE_SEL, 0);*)
			END;

			(* Flush all cache lines in the memory region *)
			FOR r := 0 TO numRanges - 1 DO
				cur := ranges[r].adr;
				end := cur + ranges[r].size;
				WHILE (cur < end)  DO
					(* Flush L1 Data cache line with virtual address *)
					CODE
						ldr r3, [fp, #adr]    (* load*)
						mcr	p15, 0, r3,  c7, c14, 1;				MCR XREG_CP15_CLEAN_INVAL_DC_LINE_MVA_POC :: "r" (adr));
					END;
					(* Flush L2 cache line with physical address *)
					SYSTEM.PUT(L2CCOffset, cur);
					cur := cur + cacheline;
					adr := adr + cacheline
				END
			END
		END;
		(* Wait for L1 and L2 flush to complete *)
		CODE
			DSB
		END;

		SYSTEM.PUT32(L2CCCacheSync, 1);
		REPEAT UNTIL SYSTEM.GET32(L2CCCacheSync) = 0;
	END FlushDCachePhysRange;

	PROCEDURE InvalidateDCacheRange*(adr: ADDRESS; len: SIZE);
	CONST
		cacheline = 32;
		L2CCBBase				= 0F8F02000H; (*XPS_L2CC_BASEADDR*)
		L2CCCacheSync		= L2CCBBase + 00730H;		(* Cache Sync *)(*XPS_L2CC_CACHE_SYNC_OFFSET	*)
		L2CCCacheInvPAOfs	= 00770H;		(* Cache Invalidate by PA *)(*XPS_L2CC_CACHE_INV_CLN_PA_OFFSET*)
		L2CCOffset = L2CCBBase + L2CCCacheInvPAOfs;
	BEGIN
		IF ~enableCaching OR (len = 0) THEN RETURN END;
		IF len MOD cacheline # 0 THEN INC(len, cacheline - len MOD cacheline) END;
		IF adr MOD cacheline # 0 THEN DEC(adr, len MOD cacheline) END;
		CODE
			LDR	R0, [FP, #adr]						; R0 := adr
			LDR	R1, [FP, #len]						; R1 := len

			LDR	R2, [PC, #Cacheline - 8 - $]		; R2 := cacheline
			SUB	R3, R2, #1							; R3 := cacheline - 1
			AND	R3, R0, R3							; R3 := adr MOD cacheline

			SUB	R0, R0, R3							; R0 := adr - adr MOD cacheline
			ADD	R1, R1, R3							; R1 := len + adr MOD cacheline
			MOV	R5, #0								; R5 := 0 (counter value)

			MOV	R3, #0
			MCR	P15, 2, R3,  C0,  C0, 0				; Select cache level 1
			LDR	R4, [PC, #L2COfs - 8 - $]			; R4 := L2 cache invalidate address register address

		Loop:
			CMP	R5, R1								; while R5 < R1
			BEQ	Sync
			BHI		Sync
			STR	R0, [R4, #0]						; Invalidate Cache Level 2 By PA (R0)
			DSB

			MCR	P15, 0, R0,  C7, C6, 1				; Invalidate Cache Level 1 By MVA (R0)
			ADD	R0, R0, R2							; R0 := R0 + cacheline
			ADD	R5, R5, R2

			B		Loop								; end

		Sync:
			DSB
			LDR	R0, [PC, #L2CSync - 8 - $]		; R0 := L2 cache sync register address
			MOV	R1, #1
			STR	R1, [R0, #0]						; [R0] := 1
		SyncLoop:										; repeat
			LDR	R1, [R0, #0]						; R1 := l2 cache syc state
			CMP	R1, #0
			BEQ	Exit									; until R1 = 0
			B		SyncLoop

		Cacheline:	d32 cacheline
		L2COfs:	d32 L2CCOffset
		L2CSync:	d32 L2CCCacheSync

		Exit:
		END;
	END InvalidateDCacheRange;

	(**
		Disable data cache for the memory range [adr, adr + len). Repeated cache disabling is recorded. A maximum of 127 successive disabling is supported.
		Cache disabling is allowed for heap and stack memory ranges only.
	*)
	PROCEDURE DisableDCacheRange * (adr: ADDRESS; len: SIZE);
	VAR
		range: ARRAY 1 OF Range;
		end: ADDRESS;
		ofs, entry: SIGNED32;
	BEGIN
		(* Changing cache status allowed for heap and stack only. *)
		ASSERT(((memHeapStart <= adr) & (adr + len <= memHeapStop)) OR ((memStackStart <= adr) & (adr + len <= memStackStop)));
		end := adr + len;
		Acquire(Memory);
		WHILE adr < end DO
			entry := GetFirstLevelEntry(adr - adr MOD M);
			CASE entry MOD 4 OF
				 0:
					(* Page is not allocated: generate a data abort trap *)
					Release(Memory);
					ASSERT(entry MOD 4 # 0);
				|flSection:
					(* 1 MB heap page *)
					IF enableCaching THEN
						(* index in cache reference count array *)
						ofs := (adr - memHeapStart) DIV M;
						IF cacheRefs[ofs] = 0 THEN
							(* First disabling: disable cache *)
							range[0].adr := adr - adr MOD M;
							range[0].size := M;
							SetFirstLevelEntry(adr - adr MOD M, adr - adr MOD M(*SHRL(entry, 20)*), SrwUrw, Shareable + B, flSection);
							InvalidateTLBEntry(adr);
							FlushDCachePhysRange(adr - adr MOD M, M, range, 1);
							cacheRefs[ofs] := 1
						ELSE
							(* Increase reference count and avoid overflows. *)
							ASSERT(cacheRefs[ofs] < 127);
							INC(cacheRefs[ofs])
						END
					END;
					INC(adr, M);
					DEC(adr, adr MOD M);
				|flCoarse:
					(* Second level pt *)
					entry := GetSecondLevelEntry(adr - adr MOD PS);
					CASE entry MOD 4 OF
						 0:
							(* Page is not allocated: generate a data abort trap *)
							Release(Memory);
							ASSERT(entry MOD 4 # 0);
						|slSmall:
							(* 4 kB stack page *)
							IF enableCaching THEN
								(* Index in cache reference count array *)
								ofs := (adr - memStackStart) DIV PS + sysCacheStackOfs;
								IF cacheRefs[ofs] = 0 THEN
									(* First disabling: disable cache *)
									range[0].adr := adr - adr MOD PS;
									range[0].size := PS;
									SetSecondLevelEntry(adr - adr MOD PS, SHRL(entry, PSlog2), FullAccess + 400H + B);
									InvalidateTLBEntry(adr);
									FlushDCachePhysRange(adr - adr MOD PS, PS, range, 1);
									cacheRefs[ofs] := 1
								ELSE
									(* Increase reference count and avoid overflows *)
									ASSERT(cacheRefs[ofs] < 127);
									INC(cacheRefs[ofs])
								END
							END;
							INC(adr, PS);
							DEC(adr, adr MOD PS)
					END;
			END;
		END;
		Release(Memory)
	END DisableDCacheRange;

	(**
		Enable data cache for the memory range [adr, adr + len).
		The memory range must have been previously disabled.
		It is the responsibility of client software to re-enable cache for the regions that it disabled.
	*)
	PROCEDURE EnableDCacheRange * (adr: ADDRESS; len: SIZE);
	VAR
		end: ADDRESS;
		ofs, entry: SIGNED32;
	BEGIN
		(* Changing cache status allowed for heap and stack only. *)
		ASSERT(((memHeapStart <= adr) & (adr < memHeapStop)) OR ((memStackStart <= adr) & (adr < memStackStop)));
		(*InvalidateDCacheRange(adr - (adr MOD M), len + M - (adr + len) MOD M + adr MOD M);*)
		Acquire(Memory);
		end := adr + len;
		WHILE adr < end DO
			entry := GetFirstLevelEntry(SHRL(adr, LogM));
			CASE entry MOD 4 OF
				 0:
					(* page not mapped: generate trap *)
					Release(Memory);
					ASSERT(entry MOD 4 # 0);
				|flSection:
					(* 1 MB heap page *)
					IF enableCaching THEN
						ofs := (adr - memHeapStart) DIV M;
						ASSERT(cacheRefs[ofs] > 0);
						IF cacheRefs[ofs] = 1 THEN
							SetFirstLevelEntry(SHRL(adr, LogM), SHRL(entry, LogM), SrwUrw, Cacheable + Shareable, entry MOD 4);
							InvalidateTLBEntry(adr);
							cacheRefs[ofs] := 0
						ELSE
							DEC(cacheRefs[ofs])
						END
					END;
					INC(adr, M);
					DEC(adr, adr MOD M)
				|flCoarse:
					(* Second-level pt entry *)
					entry := GetSecondLevelEntry(SHRL(adr, PSlog2));
					CASE entry MOD 4 OF
						 0:
							(* Page not mapped: generate trap *)
							Release(Memory);
							ASSERT(entry MOD 4 # 0);
						|slSmall:
							(* 4 kB stack page *)
							IF enableCaching THEN
								ofs := (adr - memStackStart) DIV PS + sysCacheStackOfs;
								ASSERT(cacheRefs[ofs] > 0);
								IF cacheRefs[ofs] = 1 THEN
									SetSecondLevelEntry(SHRL(adr, PSlog2), SHRL(entry, PSlog2), FullAccess + CB);
									InvalidateTLBEntry(SHRL(adr, PSlog2));
									cacheRefs[ofs] := 0
								ELSE
									DEC(cacheRefs[ofs])
								END
							END;
							INC(adr, PS);
							DEC(adr, adr MOD PS)
					END;
			END;
		END;
		Release(Memory)
	END EnableDCacheRange;

	(* InvalidateICache - invalidates the ICache. Works only in a priviledged mode. *)
	PROCEDURE InvalidateICache*;
	CODE
		MCR p15, 0, R0, c7, c5, 0	; invalidate ICache & BTB
		ISB
		; cpwait
		MRC p15, 0, R0, c2, c0, 0
		MOV R0, R0
		SUB PC, PC, #4
		MOV R0, R0
		MOV R0, R0
		MOV R0, R0
		MOV R0, R0
	END InvalidateICache;

	(* InvalidateTLB: data and instruction TLBs - Works only in a priviledged mode *)
	PROCEDURE - InvalidateTLB *;
	CODE
		MCR p15, 0, R0, c8, c3, 0	; invalidate I+D TLB
		ISB
		; cpwait
		MRC p15, 0, R0, c2, c0, 0
		MOV R0, R0
		SUB PC, PC, #4
		MOV R0, R0
		MOV R0, R0
		MOV R0, R0
		MOV R0, R0
		DSB
	END InvalidateTLB;

	(* InvalidateTLBEntry - invalidates the TLB for a given virtual address. Works only in a priviledged mode *)
	PROCEDURE - InvalidateTLBEntry(address: SIGNED32);
	CODE
		LDR R0, [SP, #address]
		ADD SP, SP, #4
		;MCR p15, 0, R0, c8, c6, 1	; invalidate address
		MCR p15, 0, R0, c8, c3, 1	; invalidate address
		ISB
		; cpwait
		MRC p15, 0, R0, c2, c0, 0
		MOV R0, R0
		SUB PC, PC, #4
		MOV R0, R0
		MOV R0, R0
		MOV R0, R0
		MOV R0, R0
		DSB
	END InvalidateTLBEntry;

	(* GetControlRegister - returns the control register of coprocessor 15 *)
	PROCEDURE -GetControlRegister(): SET;
	CODE
		MRC p15, 0, R0, c1, c0, 0
	END GetControlRegister;

	(* SetControlRegister - sets the control register of coprocessor 15. Works only in a priviledged mode *)
	PROCEDURE -SetControlRegister(cr: SET);
	CODE
		LDR R0, [SP, #cr]
		ADD SP, SP, #4	; remove parameter
		MCR p15, 0, R0, c1, c0, 0
		ISB
		; cpwait
		MRC p15, 0, R0, c2, c0, 0
		MOV R0, R0
		SUB PC, PC, #4
		MOV R0, R0
		MOV R0, R0
		MOV R0, R0
		MOV R0, R0
	END SetControlRegister;

	(* DrainWriteBuffer - drains the write buffer. Works only in a priviledged mode *)
	PROCEDURE DrainWriteBuffer*;
	CODE
		MCR p15, 0, R0, c7, c10, 4	; drain WB
		ISB
		; cpwait
		MRC p15, 0, R0, c2, c0, 0
		MOV R0, R0
		SUB PC, PC, #4
		MOV R0, R0
		MOV R0, R0
		MOV R0, R0
		MOV R0, R0
	END DrainWriteBuffer;

	PROCEDURE -CurrentPC*(): ADDRESS;
	CODE
		MOV R0, PC
	END CurrentPC;

	PROCEDURE GetTimer*(): SIGNED64;
	VAR t: ARRAY 2 OF SIGNED32;
	BEGIN
		REPEAT
			t[1] := SYSTEM.GET32(Platform.GlobalTimerCounterRegister1);
			t[0] := SYSTEM.GET32(Platform.GlobalTimerCounterRegister0);
		UNTIL t[1] = SYSTEM.GET32(Platform.GlobalTimerCounterRegister1);
		RETURN SYSTEM.VAL(SIGNED64,t);
	END GetTimer;

	(* ===== Multiprocessor booting ===== *)
	(** Initializes non-booting processors *)
	PROCEDURE InitProcessors*;
	VAR
		i: SIGNED32;
		val: ARRAY 8 OF CHAR;
	BEGIN
		GetConfig("TraceCpu", val);
		traceCpus := val = "1";
		InstallHandler(HandleUPTimer, PrivateTimerIRQ);
		InstallHandler(TimerInterruptHandler, PrivateTimerIRQ);
		InitTicks;
		InitWatchdog;
		CleanDCache;
		DrainWriteBuffer;
		FOR i := 1 TO numProcessors - 1 DO
			StartProcessor(i, BootMP);
		END;
	END InitProcessors;

	PROCEDURE StartAll*;
	BEGIN
	END StartAll;

	(* Send event instruction *)
	PROCEDURE -Sev;
	CODE
		SEV
	END Sev;

	(** Start core id on procedure p. *)
	PROCEDURE StartProcessor(id: SIGNED32; p: PROCEDURE);
	VAR
		time, ticks0: SIGNED32;
		started: BOOLEAN;
		sevCount: SIZE;
	BEGIN
		IF traceCpus THEN
			Acquire(TraceOutput);
			Trace.String("Starting CPU");
			Trace.Int(id, 0);
			Trace.String(" on address ");
			Trace.Address(SYSTEM.VAL(ADDRESS, p));
			Trace.Ln;
			Release(TraceOutput)
		END;
		Initializer.secondaryProcId := id;
		Initializer.secondaryBootProc :=  SYSTEM.VAL(ADDRESS, p);
		FlushDCacheRange(ADDRESSOF(Initializer.secondaryProcId), 4);
		FlushDCacheRange(ADDRESSOF(Initializer.secondaryBootProc), 4);

		(* wake up the other cores *)
		Sev;

		time := ticks + 1000;
		sevCount := 0;
		ticks0 := ticks;
		REPEAT
			started := id IN allProcessors;
			(*! a workaround for rare but nevertheless occurring case when the other CPU does not wake up  *)
			IF ~started & (ticks - ticks0 > 1) THEN
				Sev;
				ticks0 := ticks;
				INC(sevCount);
			END;
		UNTIL started OR (time <= ticks);
		IF traceCpus THEN
			Acquire(TraceOutput);
			Trace.String("SEV call count="); Trace.Int(sevCount,0); Trace.Ln;
			Release(TraceOutput);
		END;
		IF id IN allProcessors THEN
			IF traceCpus THEN
				Acquire(TraceOutput);
				Trace.String("Confirm: CPU");
				Trace.Int(id, 0);
				Trace.StringLn(" started");
				Release(TraceOutput)
			END
		ELSE
			Acquire(TraceOutput);
			Trace.String("WARNING: Could not start CPU");
			Trace.Int(id, 0);
			Trace.Ln;
			Release(TraceOutput)
		END
	END StartProcessor;

	(** Init Memory for non-booting processors.
		This enables MMU and copies the mapping of CPU0
	*)
	PROCEDURE InitMPMemory;
	VAR
		tbFlags: SIGNED32;
	BEGIN
		IF enableCaching THEN
			tbFlags := 7BH
		ELSE
			tbFlags := 0
		END;
		EnableMM(sysFirstLvlPtStart, tbFlags, 2000H + 1007H);
	END InitMPMemory;

	(** Init code fo a non-booting processor. No local variable allowed. *)
	PROCEDURE {NOPAF} BootMP;
	BEGIN
		(* Setup stack *)
		SYSTEM.LDPSR( 0, Platform.IRQMode + Platform.FIQDisabled + Platform.IRQDisabled );
		SYSTEM.SETSP(sysIntStackStart + 1000H * 5);

		SYSTEM.LDPSR( 0, Platform.UndefMode + Platform.FIQDisabled + Platform.IRQDisabled );
		SYSTEM.SETSP(sysIntStackStart + 1000H * 6);

		SYSTEM.LDPSR( 0, Platform.AbortMode + Platform.FIQDisabled + Platform.IRQDisabled );
		SYSTEM.SETSP(sysIntStackStart + 1000H * 7);

		SYSTEM.LDPSR( 0, Platform.SVCMode + Platform.FIQDisabled + Platform.IRQDisabled );   (* Disable interrupts, init SP, FP *)
		SYSTEM.SETSP(sysIntStackStart + 1000H * 8);

		SYSTEM.LDPSR( 0, Platform.SystemMode + Platform.FIQDisabled + Platform.IRQDisabled );   (* Disable interrupts, init SP, FP *)
		SYSTEM.SETSP(sysIntStackStart + 1000H * 8);

		Initializer.InvalidateDCache;
		SetSmpMode;
		EnableL1Cache;
		EnableCoprocessors;
		InitFPU;
		InvalidateICache;
		Initializer.InvalidateDCache;
		InitMPMemory;
		(*InvalidateDCacheRange(4096, SYSTEM.VAL(ADDRESS, LastAddress));*)
		(*InvalidateDCacheRange(memSysHighStart, memSysHighStop - memSysHighStart);*)
		(*CODE
			DSB
		END;*)

		InitInterrupts;
		EnableIRQ(PrivateTimerIRQ);
		EnableInterrupts;

		IF traceCpus THEN
			Acquire(TraceOutput);
			Trace.String("CPU "); Trace.Int(ID(), 0); Trace.StringLn(" started.");
			Release(TraceOutput)
		END;
		Acquire(Processors);
		INCL(allProcessors, ID());
		Release(Processors);
		InitTicks;
		InitWatchdog;
		start;
		HALT(400)
	END BootMP;

	PROCEDURE KernelCallHLT*;
	BEGIN
	END KernelCallHLT;

	(* function returning the number of processors that are available to Aos *)
	PROCEDURE NumberOfProcessors*( ): SIGNED32;
	BEGIN
		RETURN numberOfProcessors
	END NumberOfProcessors;

	(*! non portable code, for native Aos only *)
	PROCEDURE SetNumberOfProcessors*(num: SIGNED32);
	BEGIN
		numberOfProcessors := num;
	END SetNumberOfProcessors;

	(* ===== Context Switching ===== *)
	(** Pushes state of the processor on the stack. Used in task-switching.
		Does not exactly represent the layout of State. Pushed data is always used by JumpState.
	 *)
	PROCEDURE -PushState*(CONST state: State);
	CODE
		LDR R0, [SP, #0]	; R0 <- address of state
		ADD SP, SP, #8

		LDR R1, [R0, #60]	; push PC
		STR R1, [SP, #-4]!
		LDR R1, [R0, #56]	; push LR
		STR R1, [SP, #-4]!
		LDR R1, [R0, #48]	; push FP
		STR R1, [SP, #-4]!
		LDR R1, [R0, #44]	; push R11
		STR R1, [SP, #-4]!
		LDR R1, [R0, #40]	; push R10
		STR R1, [SP, #-4]!
		LDR R1, [R0, #36]	; push R9
		STR R1, [SP, #-4]!
		LDR R1, [R0, #32]	; push R8
		STR R1, [SP, #-4]!
		LDR R1, [R0, #28]	; push R7
		STR R1, [SP, #-4]!
		LDR R1, [R0, #24]	; push R6
		STR R1, [SP, #-4]!
		LDR R1, [R0, #20]	; push R5
		STR R1, [SP, #-4]!
		LDR R1, [R0, #16]	; push R4
		STR R1, [SP, #-4]!
		LDR R1, [R0, #12]	; push R3
		STR R1, [SP, #-4]!
		LDR R1, [R0, #8]	; push R2
		STR R1, [SP, #-4]!
		LDR R1, [R0, #4]	; push R1
		STR R1, [SP, #-4]!
		LDR R1, [R0, #0]	; push R0
		STR R1, [SP, #-4]!
		LDR R1, [R0, #64]	; push SPSR
		STR R1, [SP, #-4]!
	END PushState;

	(** Pops a processor state from the stack and restore it. Including jumping to the PC. *)
	PROCEDURE -JumpState*;
	CODE
		; Load PSR
		LDR R0, [SP], #4
		MSR CPSR_cxsf, R0	; set CPSR

		; Load registers, including branch
		LDMIA SP!, {R0, R1, R2, R3, R4, R5, R6, R7, R8, R9, R10, R11, FP, LR}
		LDR PC, [SP], #4
	END JumpState;

	PROCEDURE CopyState*(CONST from: State; VAR to: State);
	BEGIN
		to.R[0] := from.R[0];
		to.R[1] := from.R[1];
		to.R[2] := from.R[2];
		to.R[3] := from.R[3];
		to.R[4] := from.R[4];
		to.R[5] := from.R[5];
		to.R[6] := from.R[6];
		to.R[7] := from.R[7];
		to.R[8] := from.R[8];
		to.R[9] := from.R[9];
		to.R[10] := from.R[10];
		to.R[11] := from.R[11];
		to.BP := from.BP;
		to.SP := from.SP;
		to.LR := from.LR;
		to.PC := from.PC;
		to.PSR := from.PSR;
	END CopyState;

	PROCEDURE -JumpToUserLevel*(userFP: ADDRESS);
	CODE
		; this is an inlined procedure, so the 'userFP' parameter lies on top of the stack
		LDR	FP, [SP, #userFP]	; pop FP (FP is not a banked register)
		ADD	SP, SP, #4

		MRS	R0, CPSR			; get current PSR
		BIC		R0, R0, #1FH		; clear bits 4:0
		ORR	R0, R0, #1FH		; CPU mode = System
		MSR	CPSR_c, R0			; switch mode

		MOV	SP, FP
		LDMIA	SP! ,  {FP, LR}
		BX		LR

	END JumpToUserLevel;

	PROCEDURE UpdateState*;
	BEGIN
	END UpdateState;

	(** Save complete VFP/NEON state *)
	PROCEDURE -FPUSaveFull*(VAR state: NEONState);
	CODE
		LDR R0, [SP, #state]
		ADD SP, SP, #8

		VST1 D0, R0
		ADD R0, R0, #8
		VST1 D1, R0
		ADD R0, R0, #8
		VST1 D2, R0
		ADD R0, R0, #8
		VST1 D3, R0
		ADD R0, R0, #8
		VST1 D4, R0
		ADD R0, R0, #8
		VST1 D5, R0
		ADD R0, R0, #8
		VST1 D6, R0
		ADD R0, R0, #8
		VST1 D7, R0
		ADD R0, R0, #8
		VST1 D8, R0
		ADD R0, R0, #8
		VST1 D9, R0
		ADD R0, R0, #8
		VST1 D10, R0
		ADD R0, R0, #8
		VST1 D11, R0
		ADD R0, R0, #8
		VST1 D12, R0
		ADD R0, R0, #8
		VST1 D13, R0
		ADD R0, R0, #8
		VST1 D14, R0
		ADD R0, R0, #8
		VST1 D15, R0
		ADD R0, R0, #8

		VSTR D16, R0, #0
		ADD R0, R0, #8
		VSTR D17, R0, #0
		ADD R0, R0, #8
		VSTR D18, R0, #0
		ADD R0, R0, #8
		VSTR D19, R0, #0
		ADD R0, R0, #8
		VSTR D20, R0, #0
		ADD R0, R0, #8
		VSTR D21, R0, #0
		ADD R0, R0, #8
		VSTR D22, R0, #0
		ADD R0, R0, #8
		VSTR D23, R0, #0
		ADD R0, R0, #8
		VSTR D24, R0, #0
		ADD R0, R0, #8
		VSTR D25, R0, #0
		ADD R0, R0, #8
		VSTR D26, R0, #0
		ADD R0, R0, #8
		VSTR D27, R0, #0
		ADD R0, R0, #8
		VSTR D28, R0, #0
		ADD R0, R0, #8
		VSTR D29, R0, #0
		ADD R0, R0, #8
		VSTR D30, R0, #0
		ADD R0, R0, #8
		VSTR D31, R0, #0
		ADD R0, R0, #8

		VMRS	R1, FPSCR
		STR	R1, [R0, #0]
		ADD	R0, R0, #4
		VMRS	R1, FPEXC
		STR	R1, [R0, #0]
	END FPUSaveFull;

	(** Save minimal VFP/NEON state *)
	PROCEDURE -FPUSaveMin*(VAR state: NEONState);
	CODE
		ADD SP, SP, #4
	END FPUSaveMin;

	(** Restore full VFP/NEON state *)
	PROCEDURE -FPURestoreFull*(VAR state: NEONState);
	CODE
		LDR R0, [SP, #state];
		ADD SP, SP, #8

		VLD1 D0, R0
		ADD R0, R0, #8
		VLD1 D1, R0
		ADD R0, R0, #8
		VLD1 D2, R0
		ADD R0, R0, #8
		VLD1 D3, R0
		ADD R0, R0, #8
		VLD1 D4, R0
		ADD R0, R0, #8
		VLD1 D5, R0
		ADD R0, R0, #8
		VLD1 D6, R0
		ADD R0, R0, #8
		VLD1 D7, R0
		ADD R0, R0, #8
		VLD1 D8, R0
		ADD R0, R0, #8
		VLD1 D9, R0
		ADD R0, R0, #8
		VLD1 D10, R0
		ADD R0, R0, #8
		VLD1 D11, R0
		ADD R0, R0, #8
		VLD1 D12, R0
		ADD R0, R0, #8
		VLD1 D13, R0
		ADD R0, R0, #8
		VLD1 D14, R0
		ADD R0, R0, #8
		VLD1 D15, R0
		ADD R0, R0, #8

		VLDR D16, R0, #0
		ADD R0, R0, #8
		VLDR D17, R0, #0
		ADD R0, R0, #8
		VLDR D18, R0, #0
		ADD R0, R0, #8
		VLDR D19, R0, #0
		ADD R0, R0, #8
		VLDR D20, R0, #0
		ADD R0, R0, #8
		VLDR D21, R0, #0
		ADD R0, R0, #8
		VLDR D22, R0, #0
		ADD R0, R0, #8
		VLDR D23, R0, #0
		ADD R0, R0, #8
		VLDR D24, R0, #0
		ADD R0, R0, #8
		VLDR D25, R0, #0
		ADD R0, R0, #8
		VLDR D26, R0, #0
		ADD R0, R0, #8
		VLDR D27, R0, #0
		ADD R0, R0, #8
		VLDR D28, R0, #0
		ADD R0, R0, #8
		VLDR D29, R0, #0
		ADD R0, R0, #8
		VLDR D30, R0, #0
		ADD R0, R0, #8
		VLDR D31, R0, #0
		ADD R0, R0, #8

		LDR	R1, [R0, #0]
		VMSR	FPSCR, R1
		ADD	R0, R0, #4
		LDR	R1, [R0, #0]
		VMSR	FPEXC, R1
	END FPURestoreFull;

	(** Restore minimal VFP/NEON state *)
	PROCEDURE -FPURestoreMin*(VAR state: NEONState);
	CODE
		ADD SP, SP, #4
	END FPURestoreMin;

	(* ===== Interrupts ===== *)
	(* Taken from Minos/Kernel.Mos *)
	PROCEDURE EnableInterrupts*;
	VAR cpsr: SIGNED32;
	BEGIN
		SYSTEM.STPSR(0, cpsr);
		cpsr := SYSTEM.VAL(SIGNED32, SYSTEM.VAL(SET, cpsr) - {7(*, 8*)});
		SYSTEM.LDPSR(0, cpsr);
		(*SYSTEM.PUT32(Platform.ICDDCR, {EnableSecure, EnableNonSecure});*)
	END EnableInterrupts;

	(* Taken from Minos/Kernel.Mos *)
	PROCEDURE DisableInterrupts*;
	VAR cpsr: SIGNED32;
	BEGIN
		SYSTEM.STPSR(0, cpsr);
		cpsr := SYSTEM.VAL(SIGNED32, SYSTEM.VAL(SET, cpsr) + {7(*, 8*)});
		SYSTEM.LDPSR( 0, cpsr);
		(*SYSTEM.PUT32(Platform.ICDDCR, {});*)
	END DisableInterrupts;

	(** AreInterruptsEnabled - returns TRUE if interrupts are enabled at the current processor level, FALSE otherwise *)
	PROCEDURE AreInterruptsEnabled*(): BOOLEAN;
	CODE
		MRS	R0, CPSR	; move CPSR to R0
		TST	R0, #80H	; was IBit set ?
		MOVEQ	R0, #1	; no, interrupts are enabled
		MOVNE	R0, #0	; yep, interrupts are disabled
	END AreInterruptsEnabled;

	(* InstallDefaultInterrupts - installs default interrupt handlers *)
	PROCEDURE InstallDefaultInterrupts;
		VAR p: PROCEDURE; base: ADDRESS;
		i, int: SIGNED32;
	BEGIN
		base := 0;
		(* Install all *Glue procedures. *)
		p := undefGlue; SYSTEM.PUT32(base + Undef, SYSTEM.VAL(SIGNED32, p));
		p := SWIGlue; SYSTEM.PUT32(base + Swi, SYSTEM.VAL(SIGNED32, p));
		p := prefetchGlue; SYSTEM.PUT32(base + Prefetch, SYSTEM.VAL(SIGNED32, p));
		p := dataGlue; SYSTEM.PUT32(base + Data, SYSTEM.VAL(SIGNED32, p));
		p := DefaultIRQ; SYSTEM.PUT32(base + Irq, SYSTEM.VAL(SIGNED32, p));
		p := fiqGlue; SYSTEM.PUT32(base + Fiq, SYSTEM.VAL(SIGNED32, p));

		(* Install default exception handlers *)
		InstallExceptionHandler(DefaultUndefined, Undef);
		InstallExceptionHandler(DefaultSWI, Swi);
		InstallExceptionHandler(DefaultPrefetchAbort, Prefetch);
		InstallExceptionHandler(DefaultDataAbort, Data);
		InstallExceptionHandler(DefaultFIQ, Fiq);

		FOR int := 0 TO MaxIRQ DO
			FOR i := 0 TO MaxIRQHandlers -1 DO
				irqHandler[int, i] := NIL
			END
		END;
	END InstallDefaultInterrupts;

	(* DefaultUndef - default handler for undefined instruction exceptions *)
	PROCEDURE DefaultUndefined (VAR state: State);
	VAR
		instn: SIGNED32;
	BEGIN
		instn := SYSTEM.GET32(state.PC);

		Acquire(TraceOutput);
		Trace.Ln;
		Trace.StringLn("Undefined Instruction Trap:");
		Trace.String("  pc: "); Trace.Address(state.PC); Trace.Ln;
		Trace.String("  instruction: "); Trace.Hex(instn, -8); Trace.Ln;
		Trace.String("  CPU: "); Trace.Int(ID(), 0); Trace.Ln;

		TraceState(state);
		Trace.String("Kernel Halted");
		Release(TraceOutput);
		LOOP END
	END DefaultUndefined;

	(* DefaultSWI - default handler for software interrupts *)
	PROCEDURE DefaultSWI (VAR state: State);
	BEGIN
		Acquire(TraceOutput);
		Trace.Ln;
		Trace.StringLn("Software Interrupt:");
		Trace.String("  pc: "); Trace.Address(state.PC); Trace.Ln;
		Trace.String("  number: "); Trace.Int(state.INT, -8); Trace.Ln;
		Trace.String("  CPU: "); Trace.Int(ID(), 0); Trace.Ln;

		TraceState(state);
		Trace.Ln;
		Trace.String("Kernel halted.");
		Release(TraceOutput);
		LOOP END
	END DefaultSWI;

	(* Instruction Prefetch abort *)
	PROCEDURE DefaultPrefetchAbort (VAR state: State);
	BEGIN
		Acquire(TraceOutput);
		Trace.String("Prefetch abort at location: "); Trace.Address(state.PC); Trace.Ln;
		Trace.String(" CPU: "); Trace.Int(ID(), 0); Trace.Ln;
		Trace.String("  FP: "); Trace.Address(state.BP); Trace.Ln;
		Trace.String("SPSR: "); Trace.Hex(state.PSR, -8); Trace.Ln;

		TraceState(state);
		Trace.Ln;
		Trace.StringLn("Kernel Halted");
		Release(TraceOutput);
		LOOP END;
	END DefaultPrefetchAbort;

	(* DefaultDataAbort - default handler for data abort exceptions *)
	PROCEDURE DefaultDataAbort (VAR state: State);
	VAR
		faultAdr: ADDRESS;
		faultStatus: SIGNED32;
		stack: Stack;
	BEGIN
		GetPageFault(faultAdr, faultStatus);
		(*getStack(stack);

		IF ~ExtendStack(stack, faultAdr) THEN*)
			Acquire(TraceOutput);
			IF faultAdr < 4 * k THEN
				Trace.StringLn("NIL pointer exception");
				Trace.String("pc:	"); Trace.Address(state.PC); Trace.Ln
			ELSE
				Trace.StringLn("Data Abort Trap");
				Trace.String("pc:		"); Trace.Address(state.PC); Trace.Ln;
				Trace.String("instn:	"); Trace.Address(SYSTEM.GET32(state.PC)); Trace.Ln;
				Trace.String("address:	"); Trace.Address(faultAdr); Trace.Ln;
				Trace.String("status:	"); Trace.Address(faultStatus); Trace.Ln
			END;

			TraceState(state);
			Trace.Ln; Trace.StringLn("Kernel Halted.");
			Release(TraceOutput);
			LOOP END
		(*END*)
	END DefaultDataAbort;

	(* DefaultIRQ - default handler for IRQs *)
	PROCEDURE DefaultIRQ;
	BEGIN
		Acquire(TraceOutput);
		Trace.StringLn("(IRQ)");
		Trace.String("  CPU: "); Trace.Address(ID()); Trace.Ln;

		Trace.Ln; Trace.StringLn("Kernel Halted");
		Release(TraceOutput);
		LOOP END
	END DefaultIRQ;

	(* DefaultFIQ - default handler for fast interrupts *)
	(*PROCEDURE DefaultFIQ;
	BEGIN
		Trace.StringLn("Fast IRQ Trap");
		Trace.String("  CPU: "); Trace.Address(ID()); Trace.Ln;
		Trace.String("Kernel halted.");
		LOOP END
	END DefaultFIQ;*)
	PROCEDURE DefaultFIQ (VAR state: State);
	BEGIN
		Acquire(TraceOutput);
		Trace.StringLn("Fast IRQ Trap");
		Trace.String("  CPU: "); Trace.Address(ID()); Trace.Ln;
		Trace.String("Kernel halted.");
		Release(TraceOutput);
		LOOP END
	END DefaultFIQ;

	PROCEDURE DummyISR(VAR state: State);
	VAR i: SIGNED32; icip : SET;
	BEGIN
		icip := SYSTEM.VAL(SET, SYSTEM.GET32((*IC +*) Platform.ICIP));
		FOR i:=MinIRQ TO MaxIRQ DO
			IF i IN icip THEN
				state.INT := i;
				dummyIRQHandler[state.INT].h(state);
			END;
		END;
	END DummyISR;

	(** EnableIRQ - enables a hardware interrupt (also done automatically by InstallHandler) *)
	PROCEDURE InEnableIRQ(num: SIGNED32);
	BEGIN
		ASSERT((MinIRQ <= num) & (num<= MaxIRQ));
		(*IF TRUE OR (num = 53) THEN Trace.StringLn("Enable USB IRQ") END;*)
		SYSTEM.PUT32(Platform.ICDISER + 4 * (num DIV 32) , {num MOD 32});
	END InEnableIRQ;

	PROCEDURE EnableIRQ*(int: SIGNED32);
	BEGIN
		Acquire(Interrupts);
		InEnableIRQ(int);
		Release(Interrupts)
	END EnableIRQ;

	(** DisableIRQ - disables a hardware interrupt (also done automatically by RemoveHandler) *)
	PROCEDURE InDisableIRQ(num: SIGNED32);
	BEGIN
		ASSERT((MinIRQ <= num) & (num <= MaxIRQ));
		(*IF TRUE OR (num = 53) THEN Trace.StringLn("Disable USB IRQ") END;*)
		SYSTEM.PUT32(Platform.ICDICER + 4 * (num DIV 32) , {num MOD 32});
	END InDisableIRQ;

	PROCEDURE DisableIRQ*(int: SIGNED32);
	BEGIN
		Acquire(Interrupts);
		InDisableIRQ(int);
		Release(Interrupts)
	END DisableIRQ;

	PROCEDURE IsIRQEnabled(int: SIGNED32): BOOLEAN;
	VAR
		enabled: BOOLEAN;
		reg: SET;
	BEGIN
		Acquire(Interrupts);
		SYSTEM.GET(Platform.ICDISER + 4 * (int DIV 32) , reg);
		enabled := (int MOD 32) IN reg;
		Release(Interrupts);
		RETURN enabled
	END IsIRQEnabled;

	(** InstallHandler - installs a interrupt handler & enable IRQ if necessary.
		On entry to h interrupts are disabled and may be enabled with XXXXX.  After handling the interrupt
		the state of interrupts are restored.  The acknowledgement of a hardware interrupt is done automatically.
		IRQs are mapped from MinIRQ to MaxIRQ. *)
	PROCEDURE InstallHandler*(h: Handler; int: SIGNED32);
	VAR
		i: SIGNED32;
	BEGIN
		(*NEW(n);*)	(* outside locked region, to allow gc *)
		i := 0;
		WHILE irqHandler[int, i] # NIL DO
			INC(i)
		END;

		Acquire(Interrupts);
			(* IRQGlue may traverse list while it is being modified. *)
		irqHandler[int, i] := h;

		IF DummyTest THEN
			irqHandler[int, i] := DummyISR;
			dummyIRQHandler[int].h := h;
		END;

		IF (int >= MinIRQ) & (int <= MaxIRQ) THEN InEnableIRQ(int) END;

		Release(Interrupts);

		IF traceInterrupts THEN
			Acquire(TraceOutput);
			Trace.String("[Machine]InstallHandler: h = 0x"); Trace.Address(SYSTEM.VAL(SIGNED32, h));
			Trace.String("; int = "); Trace.Address(int);
			Trace.String("; IRQMask = 0x"); Trace.Address(SYSTEM.VAL(SIGNED32, IRQMask));
			Trace.Ln;
			Release(TraceOutput)
		END
	END InstallHandler;

	PROCEDURE RemoveHandler * (h: Handler; int: SIGNED32);
	END RemoveHandler;

	PROCEDURE InstallExceptionHandler * (h: Handler; e: SIGNED32);
	BEGIN
		CASE e OF
			 Undef: undefHandler := h
			|Swi: swiHandler := h
			|Prefetch: prefetchHandler := h
			|Data: dataHandler := h
			|Fiq: fiqHandler := h
		ELSE
			Trace.String("Unknown exception offset: ");
			Trace.Int(e, 0);
			Trace.Ln;
			HALT(99)
		END
	END InstallExceptionHandler;

	(*
		IRQGlue - every IRQ enters through this handler. It reads the IRR (Interrupt Request Register) of the PIC and calls the
		appropriate handlers for each pending IRQ. A problem (which caused a nice debugging session of ~1 day...) is this
		'VAR state: State' parameter. Theoretically, a interrupt handler can change the values of this field to continue execution in
		a different process, e.g. the scheduler works that way. This means that we can't call the handlers of every pending IRQ in
		one loop - we must exit this procedure after each handled IRQ.

		- routine has been changed so that all handlers of pending interrupts will be called
		- using ICIP (interrupt Pending Register) instead of IRR (Interrupt Request Register)
		- after handler call we don't turn interrupts off explicitly
	*)
	PROCEDURE {NOPAF} IRQGlue;
	CODE
		CLREX
		SUB		SP, SP, #72						; Room for the State record
		STMIA		SP, {R0, R1, R2, R3, R4, R5, R6, R7, R8, R9, R10, R11, FP, SP, LR}^
		MOV		R0, R0
		ADD		SP, SP, #60
		SUB		R0, LR, #4						; return address = LR-4
		STR		R0, [SP], #4					; push ('PC' in 'State'). SP points to offset 64
		MRS		R0, SPSR						; get saved PSR
		STR		R0, [SP], #4					; push ('PSR' in 'State'). SP points to offset 68

		SUB		SP, SP, #68
		MOV		R11, SP

		LDR		R5, [pc, #state-$-8]			; load address of stateTag constant
		STR		R5, [SP, #-4]!					; push value (type tag)
		STR		R11, [SP, #-4]!					; push parameter (address of 'State' parameter)

		BL			IRQCaller
		LDR		R11, [SP], #4
		ADD		SP, SP, #4

		ADD		SP, SP, #72						; adjust SP & remove PAF
		LDR		R0, [R11, #64]					; load 'State.PSR'
		MSR		SPSR_cxsf, R0					; and store it into SPSR
		LDR		R0, [R11, #60]					; load 'State.PC'...
		MOV		LR, R0							; ...into LR (because we will return to LR, not PC)
		ADD		R0, R11, #48					; R0 points to 'State.SP'
		LDMIA		R0, { FP, SP, LR }^				; load 'State.SP' & 'State.LR' into user mode registers
		MOV		R0, R0							; nop, to not access banked registers after LDM ^
		LDMIA		R11, { R0, R1, R2, R3, R4, R5, R6, R7, R8, R9, R10 } 				; restore unbanked regs
		LDR		R11, [R11, #44]

		MOVS		PC, LR							; SPSR -> CPSR & return

		; Data section
	state:	d32 stateTag							; address of stateTag
	END IRQGlue;

	(** Calls all handlers for all pending IRQs.
		Is called by IRQGlue.
	*)
	PROCEDURE IRQCaller(VAR state: State);
	VAR i, reg, irq, ack, count: SIGNED32;  handler: Handler;  icip: SET;
	BEGIN
		ack := SYSTEM.GET32(Platform.ICCIAR);
		(* service this irq *)
		irq := ack MOD 1024;
		IF irq # 1023 THEN (* not a spurious IRQ *)
			state.INT := irq;
			IF (MinIRQ <= irq) & (irq<= MaxIRQ) THEN
				count := 0;
				handler := irqHandler[irq, count];
				WHILE (handler # NIL) & (count < MaxIRQHandlers - 1) DO
					handler(state);
					DisableInterrupts; (* handler may have reactivated interrupts *)
					INC(count);
					handler := irqHandler[irq, count];
				END;
				SYSTEM.PUT32(Platform.ICCEOIR, ack);
			END;
		END;

		(* service pending IRQs *)
		FOR reg := 0 TO 2 DO
			SYSTEM.GET( Platform.ICDISPR+reg*4, icip );
			i := 0;
			WHILE (i <= 31) & (icip # {}) DO
				IF (i IN icip) THEN
					icip := icip - {i};
					irq := i+reg*32;

					(* Do not service pending interrupts that are disabled: this allows state triggered interrupts to be
					 * handled by software in an interrupt process. *)
					IF IsIRQEnabled(irq) & (irq # PrivateTimerIRQ) THEN
						(*Trace.String("Pending IRQ "); Trace.Int(irq, 0); Trace.Ln;*)
						count := 0;
						state.INT := irq;
						handler := irqHandler[irq, count];
						WHILE (handler # NIL) & (count < MaxIRQHandlers - 1) DO
							handler(state);
							DisableInterrupts; (* handler may have reactivated interrupts *)
							INC(count);
							handler := irqHandler[irq, count]
						END;
						SYSTEM.PUT32(Platform.ICCEOIR, irq); (* end of interrupt *)
						SYSTEM.PUT32(Platform.ICDICPR+reg*4, {i}); (* clear pending bit *)
					END
				END;
				INC( i )
			END
		END;
	END IRQCaller;

	(** Undefined Exception Handler. Saves the processor state and calls the registered handler. *)
	PROCEDURE {NOPAF} undefGlue;
	CODE
		CLREX
		SUB		SP, SP, #72						; Room for the State record
		STMIA		SP, {R0, R1, R2, R3, R4, R5, R6, R7, R8, R9, R10, R11, FP, SP, LR}^
		MOV		R0, R0
		ADD		SP, SP, #60
		SUB		R0, LR, #4						; return address = LR-4
		STR		R0, [SP], #4					; push ('PC' in 'State'). SP points to offset 64
		MRS		R0, SPSR						; get saved PSR
		STR		R0, [SP], #4					; push ('PSR' in 'State'). SP points to offset 68
		LDR		R0, [PC, #undefined-8-$]		; save -Undef in the INT field
		STR		R0, [SP], #4

		SUB		SP, SP, #72
		MOV		R11, SP

		LDR		R5, [pc, #state-$-8]			; load address of stateTag constant
		STR		R5, [SP, #-4]!					; push value (type tag)
		STR		R11, [SP, #-4]!					; push parameter (address of 'State' parameter)

		LDR		R0, [PC,#handler-8-$]
		LDR		R0, [R0, #0]
		BLX		R0
		LDR		R11, [SP], #4
		ADD		SP, SP, #4

		ADD		SP, SP, #72						; adjust SP & remove PAF
		LDR		R0, [R11, #64]					; load 'State.PSR'
		MSR		SPSR_cxsf, R0					; and store it into SPSR
		LDR		R0, [R11, #60]					; load 'State.PC'...
		MOV		LR, R0							; ...into LR (because we will return to LR, not PC)
		ADD		R0, R11, #48					; R0 points to 'State.SP'
		LDMIA		R0, { FP, SP, LR }^				; load 'State.SP' & 'State.LR' into user mode registers
		MOV		R0, R0							; nop, to not access banked registers after LDM ^
		LDMIA		R11, { R0, R1, R2, R3, R4, R5, R6, R7, R8, R9, R10 } 				; restore unbanked regs
		LDR		R11, [R11, #44]

		MOVS		PC, LR							; SPSR -> CPSR & return

		; Data section
	state:			d32 stateTag					; address of stateTag
	handler:		d32 undefHandler				; handler
	undefined:		d32 -Undef					; INT number for undefined instructions
	END undefGlue;

	(**
	 * Software Interrupt Handler. Saves the processor state and calls the registered handler.
	 * The SWI number is stored into the INT field of the state record.
	 *)
	PROCEDURE {NOPAF} SWIGlue;
	CODE
		SUB		SP, SP, #72						; Room for the State record
		STMIA		SP, {R0, R1, R2, R3, R4, R5, R6, R7, R8, R9, R10, R11, FP, SP, LR}^
		MOV		R0, R0
		ADD		SP, SP, #60
		SUB		R1, LR, #4						; return address = LR-4
		STR		R1, [SP], #4					; push ('PC' in 'State'). SP points to offset 64
		MRS		R0, SPSR						; get saved PSR
		STR		R0, [SP], #4					; push ('PSR' in 'State'). SP points to offset 68
		LDR		R0, [R1, #0]					; Load SWI instruction
		LDR		R2, [PC, #HFFFFFF-8-$]
		AND		R0, R0, R2						; R0 MOD 1000000 = SWI number
		STR		R0, [SP], #4					; push SWI number as INT. SP points to offset 72

		SUB		SP, SP, #72						; Update SP to correct location
		MOV		R11, SP

		LDR		R5, [pc, #state-$-8]			; load address of stateTag constant
		STR		R5, [SP, #-4]!					; push value (type tag)
		STR		R11, [SP, #-4]!					; push parameter (address of 'State' parameter)

		LDR		R0, [PC,#handler-8-$]
		LDR		R0, [R0, #0]
		BLX		R0
		LDR		R11, [SP], #4
		ADD		SP, SP, #4

		ADD		SP, SP, #72						; adjust SP & remove PAF
		LDR		R0, [R11, #64]					; load 'State.PSR'
		MSR		SPSR_cxsf, R0					; and store it into SPSR
		LDR		R0, [R11, #60]					; load 'State.PC'...
		MOV		LR, R0							; ...into LR (because we will return to LR, not PC)
		ADD		R0, R11, #48					; R0 points to 'State.SP'
		LDMIA		R0, { FP, SP, LR }^				; load 'State.SP' & 'State.LR' into user mode registers
		MOV		R0, R0							; nop, to not access banked registers after LDM ^
		LDMIA		R11, { R0, R1, R2, R3, R4, R5, R6, R7, R8, R9, R10 } 				; restore unbanked regs
		LDR		R11, [R11, #44]

		MOVS		PC, LR							; SPSR -> CPSR & return

		; Data section
	state:		d32 stateTag						; address of stateTag
	HFFFFFF:	d32 0FFFFFFH						; SWI number mask
	handler:	d32 swiHandler					; swiHandler
	END SWIGlue;

	(**
	 * Prefetch Abort Handler. Saves the processor state and calls the registered handler.
	 * The PC field of the state record holds the address at which the prefetch fault occurred.
	 *)
	PROCEDURE {NOPAF} prefetchGlue;
	CODE
		CLREX
		SUB		SP, SP, #72						; Room for the State record
		STMIA		SP, {R0, R1, R2, R3, R4, R5, R6, R7, R8, R9, R10, R11, FP, SP, LR}^
		MOV		R0, R0
		ADD		SP, SP, #60
		SUB		R0, LR, #4						; return address = LR-4
		STR		R0, [SP], #4					; push ('PC' in 'State'). SP points to offset 64
		MRS		R0, SPSR						; get saved PSR
		STR		R0, [SP], #4					; push ('PSR' in 'State'). SP points to offset 68
		LDR		R0, [PC, #prefetchAbort-8-$]		; save -Data in the INT field
		STR		R0, [SP], #4

		SUB		SP, SP, #72
		MOV		R11, SP

		LDR		R5, [pc, #state-$-8]			; load address of stateTag constant
		STR		R5, [SP, #-4]!					; push value (type tag)
		STR		R11, [SP, #-4]!					; push parameter (address of 'State' parameter)

		LDR		R0, [PC,#handler-8-$]
		LDR		R0, [R0, #0]
		BLX		R0
		LDR		R11, [SP], #4
		ADD		SP, SP, #4

		ADD		SP, SP, #72						; adjust SP & remove PAF
		LDR		R0, [R11, #64]					; load 'State.PSR'
		MSR		SPSR_cxsf, R0					; and store it into SPSR
		LDR		R0, [R11, #60]					; load 'State.PC'...
		MOV		LR, R0							; ...into LR (because we will return to LR, not PC)
		ADD		R0, R11, #48					; R0 points to 'State.SP'
		LDMIA		R0, { FP, SP, LR }^				; load 'State.SP' & 'State.LR' into user mode registers
		MOV		R0, R0							; nop, to not access banked registers after LDM ^
		LDMIA		R11, { R0, R1, R2, R3, R4, R5, R6, R7, R8, R9, R10 } 				; restore unbanked regs
		LDR		R11, [R11, #44]

		MOVS		PC, LR							; SPSR -> CPSR & return

		; Data section
	state:			d32 stateTag					; address of stateTag
	handler:		d32 prefetchHandler			; handler
	prefetchAbort:	d32 -Prefetch					; prefetch INT number
	END prefetchGlue;

	(**
	 * Data Abort Handler. Saves the processor state and calls the registered handler.
	 * Use procedure GetPageFault to get abort status and address.
	 *)
	PROCEDURE {NOPAF} dataGlue;
	CODE
		CLREX
		SUB		SP, SP, #72						; Room for the State record
		STMIA		SP, {R0, R1, R2, R3, R4, R5, R6, R7, R8, R9, R10, R11, FP, SP, LR}^
		MOV		R0, R0
		ADD		SP, SP, #60
		SUB		R0, LR, #8						; return address = LR-8
		STR		R0, [SP], #4					; push ('PC' in 'State'). SP points to offset 64
		MRS		R0, SPSR						; get saved PSR
		STR		R0, [SP], #4					; push ('PSR' in 'State'). SP points to offset 68
		LDR		R0, [PC, #dataAbort-8-$]		; save -Data in the INT field
		STR		R0, [SP], #4

		SUB		SP, SP, #72
		MOV		R11, SP

		LDR		R5, [pc, #state-$-8]			; load address of stateTag constant
		STR		R5, [SP, #-4]!					; push value (type tag)
		STR		R11, [SP, #-4]!					; push parameter (address of 'State' parameter)

		LDR		R0, [PC,#handler-8-$]
		LDR		R0, [R0, #0]
		BLX		R0
		LDR		R11, [SP], #4
		ADD		SP, SP, #4

		ADD		SP, SP, #72						; adjust SP & remove PAF
		LDR		R0, [R11, #64]					; load 'State.PSR'
		MSR		SPSR_cxsf, R0					; and store it into SPSR
		LDR		R0, [R11, #60]					; load 'State.PC'...
		MOV		LR, R0							; ...into LR (because we will return to LR, not PC)
		ADD		R0, R11, #48					; R0 points to 'State.SP'
		LDMIA		R0, { FP, SP, LR }^				; load 'State.SP' & 'State.LR' into user mode registers
		MOV		R0, R0							; nop, to not access banked registers after LDM ^
		LDMIA		R11, { R0, R1, R2, R3, R4, R5, R6, R7, R8, R9, R10 } 				; restore unbanked regs
		LDR		R11, [R11, #44]

		MOVS		PC, LR							; SPSR -> CPSR & return

		; Data section
	state:			d32 stateTag					; address of stateTag
	handler:		d32 dataHandler				; address of the handler variable
	dataAbort:		d32 -Data
	END dataGlue;

	(** Fast Interrupt Handler. Saves the processor state and calls the registered handler *)
	PROCEDURE {NOPAF} fiqGlue;
	CODE
		CLREX
		SUB		SP, SP, #72						; Room for the State record
		STMIA		SP, {R0, R1, R2, R3, R4, R5, R6, R7, R8, R9, R10, R11, FP, SP, LR}^
		MOV		R0, R0
		ADD		SP, SP, #60
		SUB		R0, LR, #4						; return address = LR-4
		STR		R0, [SP], #4					; push ('PC' in 'State'). SP points to offset 64
		MRS		R0, SPSR						; get saved PSR
		STR		R0, [SP], #4					; push ('PSR' in 'State'). SP points to offset 68

		SUB		SP, SP, #68
		MOV		R11, SP

		LDR		R5, [pc, #state-$-8]			; load address of stateTag constant
		STR		R5, [SP, #-4]!					; push value (type tag)
		STR		R11, [SP, #-4]!					; push parameter (address of 'State' parameter)

		BL			fiqHandler
		LDR		R11, [SP], #4
		ADD		SP, SP, #4

		ADD		SP, SP, #72						; adjust SP & remove PAF
		LDR		R0, [R11, #64]					; load 'State.PSR'
		MSR		SPSR_cxsf, R0					; and store it into SPSR
		LDR		R0, [R11, #60]					; load 'State.PC'...
		MOV		LR, R0							; ...into LR (because we will return to LR, not PC)
		ADD		R0, R11, #48					; R0 points to 'State.SP'
		LDMIA		R0, { FP, SP, LR }^				; load 'State.SP' & 'State.LR' into user mode registers
		MOV		R0, R0							; nop, to not access banked registers after LDM ^
		LDMIA		R11, { R0, R1, R2, R3, R4, R5, R6, R7, R8, R9, R10 } 				; restore unbanked regs
		LDR		R11, [R11, #44]

		MOVS		PC, LR							; SPSR -> CPSR & return

		; Data section
	state:	d32 stateTag							; address of stateTag
	END fiqGlue;

	(** Initializes IRQ handling. *)
	PROCEDURE InitInterrupts*;
	CONST
		EnableSecure=0;
		EnableNonSecure=1;
		NumberIRQs = 96;
	VAR p: PROCEDURE; i: SIGNED32;
	BEGIN
		Acquire(Interrupts);
		IRQMask := {};
		p := IRQGlue;
		SYSTEM.PUT32(InterruptVector + Irq, SYSTEM.VAL(SIGNED32, p));	(* install new IRQ handler *)
		SYSTEM.PUT32(Platform.ICDDCR, 0);


		FOR i := 32 DIV 16 TO (NumberIRQs-1) DIV 16 (* 2 bits per IRQ *)  DO
			SYSTEM.PUT32(Platform.ICDICFR+i*4, 0);
		END;

		FOR i := 0  TO (NumberIRQs-1) DIV 4 (* 8 bits per IRQ *) DO
			SYSTEM.PUT32(Platform.ICDIPR+i*4, SIGNED32(0A0A0A0A0H)); (* set priority of each interrupt to 160 *)
		END;

		FOR i := (32 DIV 4) TO (NumberIRQs-1) DIV 4 (* 8 bits per IRQ *) DO
			SYSTEM.PUT32(Platform.ICDIPTR+i*4, 1010101H); (* reset interrupt targets to processor 0 *)
		END;

		(* disable all interrupt forwardings *)
		FOR i := 0 TO (NumberIRQs-1) DIV 32 (* 1 bit per IRQ *) DO
			SYSTEM.PUT32(Platform.ICDICER+i*4, SIGNED32(0FFFFFFFFH));
		END;

		SYSTEM.PUT32(Platform.ICCPMR, 0F0H);
		SYSTEM.PUT32(Platform.ICCICR, {0,1,2});
		SYSTEM.PUT32(Platform.ICCBPR, 0);

		SYSTEM.PUT32(Platform.ICDDCR, {EnableSecure, EnableNonSecure});
		Release(Interrupts);

		(*InvalidateDCache(dCacheBase);*)
		(*EnableIRQ(PrivateTimerIRQ);*)
	END InitInterrupts;

	(** Restore silent, infinitly-looping exception handlers *)
	PROCEDURE EndInterrupts;
	BEGIN
		SYSTEM.PUT32(InterruptVector + Undef, InterruptVector + Undef);
		SYSTEM.PUT32(InterruptVector + Swi, InterruptVector + Swi);
		SYSTEM.PUT32(InterruptVector + Prefetch, InterruptVector + Prefetch);
		SYSTEM.PUT32(InterruptVector + Data, InterruptVector + Data);
		SYSTEM.PUT32(InterruptVector + Irq, InterruptVector + Irq);
		SYSTEM.PUT32(InterruptVector + Fiq, InterruptVector + Fiq);
	END EndInterrupts;

	(* GetExceptionState *)
	PROCEDURE GetExceptionState*(VAR int: State; VAR exc: ExceptionState);
	BEGIN
		(* save all state information while interrupts are still disabled *)
		exc.locks := BreakAll();
		IF int.INT = -Undef THEN
			exc.halt := 17;
			exc.instn := SYSTEM.GET32(int.PC)
		ELSIF int.INT = -Prefetch THEN
			exc.pf := int.PC;
			exc.status := -1;
			exc.halt := 19
		ELSIF int.INT = -Data THEN
			GetPageFault(exc.pf, exc.status);
			IF exc.pf < 4 * k THEN
				(* NIL pointer *)
				exc.halt := 18
			ELSE
				exc.halt := 19
			END
		ELSE
			(* SWI *)
			exc.halt := int.INT
		END
	END GetExceptionState;

	PROCEDURE GetPageFault * (VAR adr: ADDRESS; VAR status: SIGNED32);
	CODE
		MRC	p15, 0, R0, C5, C0	; load fault status register (FSR)
		AND	R0, R0, #0FFH			; only bits 7:0 are valid
		LDR	R1, [FP, #status]
		STR R0, [R1, #0]

		MRC	p15, 0, R0, C6, C0	; load fault address (FAR)
		LDR	R1, [FP, #adr]
		STR R0, [R1, #0]
	END GetPageFault;

	(* FAR - returns the Fault Address Register. *)
	PROCEDURE -FAR*(): SIGNED32;
	CODE
		MRC	p15, 0, R0, C6, C0	; FAR is co-processor 15 register 6
	END FAR;

	(** Init global timer *)
	PROCEDURE InitGlobalTimer;
	CONST
		TimerEnable=0;
	BEGIN
		(* disable first *)
		SYSTEM.PUT32(Platform.GlobalTimerControlRegister, {});
		(* reset global counter *)
		SYSTEM.PUT32(Platform.GlobalTimerCounterRegister0, 0);
		SYSTEM.PUT32(Platform.GlobalTimerCounterRegister1, 0);
		SYSTEM.PUT32(Platform.GlobalTimerControlRegister, {TimerEnable});
	END InitGlobalTimer;


	(** Init private timer *)
	PROCEDURE InitTicks;
	CONST
		TimerEnable=0;
		AutoReload=1;
		IRQEnable=2;
	VAR
		(* time slot in private timer counts; take into account that private timer clock frequency is equal to half of the CPU clock frequency *)
		delay: SIGNED32;
	BEGIN
		delay := ENTIER( ( FLOAT64(TimerPeriod) * 0.5D0 * FLOAT64(BootConfig.GetIntValue("CpuClockHz")) ) / 1.0D6 + 0.5D0 );
		(* disable first *)
		SYSTEM.PUT32(Platform.PrivateTimerControlRegister, {});

		(*SYSTEM.PUT32(Platform.PrivateTimerCounterRegister, Delay);*)
		SYSTEM.PUT32(Platform.PrivateLoadValueRegister, delay);
		SYSTEM.PUT32(Platform.PrivateTimerControlRegister, {TimerEnable, AutoReload, IRQEnable});
	END InitTicks;

	PROCEDURE StopTicks;
	BEGIN
		SYSTEM.PUT32(Platform.PrivateTimerControlRegister, {});
	END StopTicks;

	(** Handle multiprocessor timer interrupt. *)
	PROCEDURE HandleMPTimer*(VAR state: State);
	BEGIN	(* {interrupts off} *)
		timer(ID(), state); (* rarely used *)
		(* Clear timer interrupt *)
		SYSTEM.PUT32(Platform.GlobalTimerInterruptStatusRegister, 1);
		EnableInterrupts;	(* enable interrupts before acquiring locks below - to avoid deadlock with StopAll. *)
		Timeslice(state);	(* fixme: check recursive interrupt *)
	END HandleMPTimer;

	(** Handle uniprocessor timer interrupt. *)
	PROCEDURE HandleUPTimer(VAR state: State);
	BEGIN	(* {interrupts off} *)
		timer(ID(), state);
		SYSTEM.PUT32(Platform.PrivateTimerInterruptStatusRegister, 1);

		(* Shutdown if requested *)
		IF ~(ID() IN allProcessors) THEN ShutdownSecondary END;
		IF enableWatchdog THEN PrivateWatchdog.Feed(Second) END;
		Timeslice(state)
	END HandleUPTimer;

	(** Install a processor timer event handler. *)
	PROCEDURE InstallEventHandler* (h: EventHandler);
	BEGIN
		IF h # NIL THEN timer := h ELSE timer := DummyEvent END
	END InstallEventHandler;

	PROCEDURE DummyEvent*(id: SIGNED32; CONST state: State);
	BEGIN
	END DummyEvent;

	PROCEDURE DummyTimeslice*(VAR state: State);
	BEGIN
	END DummyTimeslice;

	PROCEDURE DummyIRQ*;
	BEGIN
	END DummyIRQ;

	PROCEDURE IRQBeginPrinter;
	BEGIN
		Trace.StringLn("IRQ BEGIN");
	END IRQBeginPrinter;

	PROCEDURE IRQEndPrinter;
	BEGIN
		Trace.StringLn("IRQ END");
	END IRQEndPrinter;

	(* Timer interrupt handler. *)
	PROCEDURE TimerInterruptHandler(VAR state: State);
	BEGIN
		IF ID() = 0 THEN
			INC(ticks);
			DEC(eventCount);
			IF eventCount = 0 THEN
				eventCount := eventMax; event(state)
			END;
		END
	END TimerInterruptHandler;

	(* Set timer upcall. The handler procedure will be called at a rate of Second/divisor Hz. *)
	PROCEDURE InstallTickHandler(handler: Handler; divisor: SIGNED32);
	BEGIN
		eventMax := divisor; event := handler;
		eventCount := eventMax
	END InstallTickHandler;

	(* ===== Low-Level Locks ===== *)
	(* Initializes spinlocks. This is not exported in Intel version. *)
	PROCEDURE InitLocks;
	VAR
		i: SIGNED32;
	BEGIN
		FOR i := 0 TO MaxLock - 1 DO
			lock[i].locked := FALSE
		END;
	END InitLocks;

	PROCEDURE AcquirePreemption*(): SIGNED32;
	VAR
		id: SIGNED32;
	BEGIN
		id := ID();
		INC(proc[id].preemptCount);
		RETURN id
	END AcquirePreemption;

	PROCEDURE ReleasePreemption*;
	VAR
		id: SIGNED32;
	BEGIN
		id := ID();

		IF StrongChecks THEN
			ASSERT(proc[id].preemptCount > 0);
		END;

		DEC(proc[id].preemptCount);
	END ReleasePreemption;

	PROCEDURE PreemptCount*(id: SIGNED32): SIGNED32;
	BEGIN
		IF StrongChecks THEN
			ASSERT(id = ID());
		END;
		RETURN proc[id].preemptCount;
	END PreemptCount;

	(* Acquire lock. Disables interrupts. *)
	PROCEDURE Acquire*(level: SIGNED32);
	VAR
		id: SIGNED32;
		enabled: BOOLEAN;
	BEGIN
		enabled := AreInterruptsEnabled();
		DisableInterrupts();
		id := AcquirePreemption();
		IF proc[id].locksHeld = {} THEN
			proc[id].intStatus := enabled
		END;

		IF StrongChecks THEN
			ASSERT(~AreInterruptsEnabled());
			ASSERT((~enabled) OR (proc[id].locksHeld = {}));	(* interrupts enabled => no locks held *)
			ASSERT(~(level IN proc[id].locksHeld))	(* recursive locks not allowed *)
		END;

		AcquireObject(lock[level].locked);
		(* Now, we hold the lock *)
		INCL(proc[id].locksHeld, level);

		IF StrongChecks THEN	(* no lower-level locks currently held by this processor *)
			ASSERT((level = 0) OR (proc[id].locksHeld * {0..level-1} = {}));
		END;
	END Acquire;

	(* Release lock. Enables interrupts if last lock held. *)
	PROCEDURE Release*(level: SIGNED32);
	VAR
		id: SIGNED32;
	BEGIN
		id := ID();

		IF StrongChecks THEN
			ASSERT(~AreInterruptsEnabled());
			ASSERT(level IN proc[id].locksHeld);
			ASSERT(lock[level].locked # FALSE)
		END;

		EXCL(proc[id].locksHeld, level);
		ReleaseObject(lock[level].locked);

		ReleasePreemption;
		IF (proc[id].locksHeld = {}) & proc[id].intStatus THEN
			EnableInterrupts
		END;
	END Release;

	PROCEDURE AcquireAll*;
	VAR
		i: SIGNED32;
	BEGIN
		FOR i := MaxLock - 1 TO 0 BY -1 DO
			Acquire(i)
		END
	END AcquireAll;

	PROCEDURE ReleaseAll*;
	VAR
		i: SIGNED32;
	BEGIN
		FOR i := 0 TO MaxLock - 1 DO
			Release(i)
		END
	END ReleaseAll;

	(** Acquire a fine-grained lock on an active object. *)
	(* Based on the code from "Barrier Litmus Tests and Cookbook" by Richard Grisenthwaite, ARM, 26.11.2009 *)
	PROCEDURE AcquireObject*(VAR locked: BOOLEAN);
	CODE
		CLREX ; ensure that the local monitor is in the Open Access state after a context switch

		LDR R1, [FP, #locked]

		MOV R0, #1
	Loop:
		LDREXB R5, R1 ; read lock
		CMP R5, #0 ; check if 0
		WFENE ; sleep if the lock is held

		STREXBEQ R5, R0, R1 ; attempt to store new value
		CMPEQ R5, #0 ; test if store suceeded
		BNE Loop ; retry if not

		DMB ; ensures that all subsequent accesses are observed after the gaining of the lock is observed

		; loads and stores in the critical region can now be performed
	END AcquireObject;

	(** Release an active object lock. *)
	(* Based on the code from "Barrier Litmus Tests and Cookbook" by Richard Grisenthwaite, ARM, 26.11.2009 *)
	PROCEDURE ReleaseObject*(VAR locked: BOOLEAN);
	CODE
		LDR R1, [FP, #locked]

		MOV R0, #0
		DMB ; ensure all previous accesses are observed before the lock is cleared
		STRB R0, [R1, #0] ; clear the lock.
		DSB ; ensure completion of the store that cleared the lock before sending the event
		SEV
	END ReleaseObject;

	(** Break all locks held by current processor (for exception handling).  Returns levels released. *)
	PROCEDURE BreakAll*(): SET;
	VAR id, level: SIGNED32; released: SET;
	BEGIN
		id := AcquirePreemption();
		released := {};
		FOR level := 0 TO MaxLock-1 DO
			IF level IN proc[id].locksHeld THEN
				lock[level].locked := FALSE;	(* break the lock *)
				EXCL(proc[id].locksHeld, level);
				INCL(released, level)
			END
		END;
		(*IF released = {} THEN
			ASSERT(proc[id].nestCount = 0)	(* no locks held *)
		ELSE
			ASSERT(proc[id].nestCount > 0);	(* some locks held *)
			proc[id].nestCount := 0	(* interrupt state will be restored later *)
		END;*)
		IF proc[id].preemptCount > 1 THEN INCL(released, Preemption) END;
		proc[id].preemptCount := 0;	(* clear preemption flag *)
		RETURN released
	END BreakAll; (* !!! interrupts are still off !!! *)

	(* ===== Atomic Operations ===== *)
	(* Atomic INC(x) *)
	PROCEDURE -AtomicInc*(VAR x: SIGNED32);
	CODE
	;loop:
	;	ADD R0, SP, #x	; R0 := ADR(x)
	;	LDREX R1, R0		; R1 := x
	;	ADD R1, R1, #1	; increment x
	;	STREX R2, R1, R0
	;	CMP R2, #0
	;	BEQ loop			; if store failed, try again, else exit
	;	ADD SP, SP, #4

		LDR	R0, [SP], #4
	loop:
		LDREX	R1, R0
		ADD	R1, R1, #1
		STREX	R2, R1, R0
		CMP	R2, #0
		BNE	loop
	END AtomicInc;

	(* Atomic INC(x) *)
	PROCEDURE -AtomicDec*(VAR x: SIGNED32);
	CODE
		LDR	R0, [SP], #4
	loop:
		LDREX	R1, R0
		SUB	R1, R1, #1
		STREX	R2, R1, R0
		CMP	R2, #0
		BNE	loop
	END AtomicDec;

	PROCEDURE -AtomicAdd * (VAR x: SIGNED32; y: SIGNED32);
	CODE
		LDR R3, [SP, #y]	; R3 := y
		LDR R0, [SP, #x]	; R0 := ADR(x)
	loop:
		LDREX R1, R0		; R1 := x
		ADD R1, R1, R3	; increment x
		STREX R2, R1, R0
		CMP R2, #0
		BNE loop			; if store failed, try again, else exit
		ADD SP, SP, #8
	END AtomicAdd;

	(* Atomic test-and-set. Set x = TRUE and return old value of x. *)
	PROCEDURE -AtomicTestSet * (VAR x: BOOLEAN): BOOLEAN;
	CODE
		LDR	R3, [SP, #x]			; R3 := ADDRESSOF(x)
		MOV	R1, #0				; R1 := FALSE
		MOV	R2, #1				; R2 := TRUE
		ADD	SP, SP, #4				; pop variable from stack

	loop:
		LDREXB	R0, R3					; load excl x
		CMP	R0, R1
		BNE	exit						; x # old -> exit
		STREXB	R4, R2, R3				; x = old -> store excl new -> x
		CMP	R4, #0
		BNE	loop					; store exclusive failed: retry

	exit:
	END AtomicTestSet;

	(* Atomic compare-and-swap. Set x = new if x = old and return old value of x *)
	PROCEDURE -AtomicCAS * (VAR x: SIGNED32; old, new: SIGNED32): SIGNED32;
	CODE
		LDR	R3, [SP, #x]			; R3 := ADDRESSOF(x)
		LDR	R1, [SP, #old]			; R1 := old
		LDR	R2, [SP, #new]			; R2 := new
		ADD	SP, SP, #12				; pop variable from stack

	loop:
		LDREX	R0, R3					; load excl x
		CMP	R0, R1
		BNE	exit						; x # old -> exit
		STREX	R4, R2, R3				; x = old -> store excl new -> x
		CMP	R4, #0
		BNE	loop					; store exclusive failed: retry

	exit:
	END AtomicCAS;

	(* ===== Virtual Memory Management ===== *)

	PROCEDURE GetSecondLevelEntry(virtualAddress: ADDRESS): ADDRESS;
	VAR
		ptIdx, basePT, entry: ADDRESS;
	BEGIN
		IF (PS <= virtualAddress) & (virtualAddress < M) THEN
			(* First 256 entries *)
			basePT := sysSecondLvlPtStart
		ELSIF (4 * G - M <= virtualAddress) THEN
			(* Entries 256 to 511 *)
			basePT := sysSecondLvlPtStart + 400H
		ELSIF (memStackStart <= virtualAddress) & (virtualAddress < memStackStop) THEN
			basePT := sysSecondLvlPtStart + 800H + virtualAddress DIV M * k - memStackStart DIV k
		ELSIF (memConfigStart <= virtualAddress) & (virtualAddress < memConfigStop) THEN
			basePT := sysSecondLvlPtStop - (memConfigStop DIV k - virtualAddress DIV M * k)
		END;
		ptIdx := opSHR(virtualAddress MOD M, PSlog2);
		ASSERT(basePT + 4 * ptIdx >= sysSecondLvlPtStart);
		ASSERT(basePT + 4 * ptIdx < sysSecondLvlPtStop);
		entry := SYSTEM.GET32(basePT + 4 * ptIdx);
		RETURN entry
	END GetSecondLevelEntry;

	PROCEDURE SetSecondLevelEntry(virtualAddress, physicalAddress, flags: ADDRESS);
	VAR ptIdx, basePT, entry: ADDRESS;
		firstLvlEntry: ADDRESS;
	BEGIN
		IF (PS <= virtualAddress) & (virtualAddress < M) THEN
			(* First 256 entries *)
			basePT := sysSecondLvlPtStart
		ELSIF (4 * G - M <= virtualAddress) THEN
			(* Entries 256 to 511 *)
			basePT := sysSecondLvlPtStart + 400H
		ELSIF (memStackStart <= virtualAddress) & (virtualAddress < memStackStop) THEN
			basePT := sysSecondLvlPtStart + 800H + virtualAddress DIV M * k - memStackStart DIV k
		ELSIF (memConfigStart <= virtualAddress) & (virtualAddress < memConfigStop) THEN
			basePT := sysSecondLvlPtStop - (memConfigStop DIV k - virtualAddress DIV M * k)
		END;
		ptIdx := opSHR(virtualAddress MOD M, PSlog2);

		IF physicalAddress = NilAdr THEN
			entry := slFault
		ELSE
			ASSERT(physicalAddress MOD PS = 0);
			ASSERT((flags DIV PS = 0) & (flags MOD 4 = 0));
			entry := physicalAddress + flags + slSmall
		END;
		ASSERT(basePT + 4 * ptIdx >= sysSecondLvlPtStart);
		ASSERT(basePT + 4 * ptIdx < sysSecondLvlPtStop);
		SYSTEM.PUT32(basePT + 4 * ptIdx, entry);
	END SetSecondLevelEntry;

	PROCEDURE UnmapPhysical*(viartAdr: ADDRESS; size: SIZE);
	BEGIN
	END UnmapPhysical;

	(* Unmap a virtual page and deallocate the corresponding physical page *)
	PROCEDURE DeallocatePage(virtualAdr: ADDRESS);
	VAR memoryAdr: SIGNED32;
	BEGIN
		(* unmap the page *)
		memoryAdr := GetSecondLevelEntry(virtualAdr);
		ASSERT(memoryAdr MOD 4 = slSmall);	(* page must be mapped *)
		SYSTEM.PUT32(virtualAdr, freePage); 	(* link freePage list (must be done as long as the page is still mapped !) *)
		SetSecondLevelEntry(virtualAdr, NilAdr, 0);
		InvalidateTLBEntry(SHRL(virtualAdr, PSlog2));

		(* free the page *)
		memoryAdr := SHRL(memoryAdr, 12);
		freePage := memoryAdr;
		INC(memory.free, PS)
	END DeallocatePage;

	(* AllocatePage - allocates and maps one memory page to [virtualAdr...virtualAdr+PageSize]. Returns TRUE iff successful *)
	PROCEDURE AllocatePage(virtualAdr, accessPermissions, flags: ADDRESS): BOOLEAN;
	VAR memoryAdr, entry: ADDRESS;
	BEGIN
		(* Use 1:1 Mapping for stack *)
		(* map the page *)
		entry := GetSecondLevelEntry(virtualAdr);
		IF entry MOD 4 # slFault THEN
			Acquire(TraceOutput);
			Trace.String("Allocate Page: entry = ");
			Trace.Address(entry);
			Trace.String("; vadr = ");
			Trace.Address(virtualAdr);
			Trace.String("; CPU = ");
			Trace.Int(ID(), 0);
			Trace.Ln;
			Release(TraceOutput)
		END;
		ASSERT(entry MOD 4 = slFault);	(* page must not be mapped *)
		SetSecondLevelEntry(virtualAdr, (*memoryAdr*) virtualAdr, accessPermissions + flags);
		InvalidateTLBEntry(SHRL(virtualAdr, PSlog2));
		RETURN TRUE
	END AllocatePage;

	(** PhysicalAdr - returns the (real) physical address of the specified range of memory, or NilAdr if the range is not contiguous.
		It is the caller's responsiblilty to assure the range remains allocated during the time it is in use.
	*)
	PROCEDURE PhysicalAdr*(adr, size: SIGNED32): SIGNED32;
	VAR physAdr: ARRAY 400H OF Range; num, i, end: SIGNED32;
	BEGIN
		TranslateVirtual(adr, size, num, physAdr);
		IF (num > 0) THEN
			FOR i := 1 TO num-1 DO
				IF (physAdr[i].adr # (physAdr[i-1].adr + physAdr[i-1].size)) THEN
					RETURN NilAdr
				END
			END;
			RETURN physAdr[0].adr
		ELSE
			RETURN NilAdr
		END
	END PhysicalAdr;

	(** TranslateVirtual - translates a virtual address range to num ranges of (real) physical addresses.  num returns 0 on error.*)
	PROCEDURE TranslateVirtual*(virtAdr: ADDRESS; size: SIGNED32; VAR num: SIGNED32; VAR physAdr: ARRAY OF Range);
	VAR entry, base, ofs, len: SIGNED32; endAdr: ADDRESS; abort: BOOLEAN;
	BEGIN
		Acquire(Memory);

		endAdr := virtAdr + size;
		IF ((memHeapStart <= virtAdr) & (endAdr <= memHeapStop)) OR ((memStackStart <= virtAdr) & (endAdr <= memStackStop)) OR ((memIOStart <= virtAdr) & (endAdr <= memIOStop)) THEN
			(* Optimizations: we know that heap, stacks and I/O regions are mapped 1:1. *)
			(*! This code is very aggressive: it returns only 1 range, and not 1 range per physical page. It assumes that all stack pages of the specified region are mapped *)
			num := 1;
			physAdr[0].adr := virtAdr;
			physAdr[0].size := size;
		ELSE
			abort := FALSE;
			num := 0;
			WHILE (size > 0) & (num < LEN(physAdr)) & ~abort DO
				entry := (*SYSTEM.GET32(pageTable.virtual + 4*SHR(virtAdr, LogM));*)GetFirstLevelEntry(virtAdr - virtAdr MOD M);
				IF (entry MOD 4 = flSection) THEN
					ofs := virtAdr MOD M;
					len := MIN(size, M - ofs);
					physAdr[num].adr := SHRL(entry, LogM) + ofs;
					physAdr[num].size := len;
					INC(num);
					INC(virtAdr, len); DEC(size, len)
				ELSIF (entry MOD 4 = flCoarse) THEN
					base := SHRL(entry, 10);

					WHILE (size > 0) & (num < LEN(physAdr)) & ~abort DO
						entry := GetSecondLevelEntry(virtAdr);
						IF (entry MOD 4 = slSmall) THEN
							ofs := virtAdr MOD PS;
							len := MIN(size, PS - ofs);
							physAdr[num].adr := SHRL(entry, 12) + ofs;
							physAdr[num].size := len;
							INC(num);
							INC(virtAdr, len); DEC(size, len)
						ELSE
							num := 0;
							abort := TRUE
						END
					END
				ELSE
					num := 0; abort := TRUE
				END;
			END;
			IF (size > 0) & (num = LEN(physAdr)) THEN num := 0 END;	(* array 'physAdr' was too small *)
		END;
		Release(Memory)
	END TranslateVirtual;

	PROCEDURE SetFirstLevelEntry (virtual, physical: ADDRESS; permissions, flags, type: SIGNED32);
	VAR
		index, entry: SIGNED32;
	BEGIN
		index := opSHR(virtual, LogM) * 4;
		ASSERT(index >= 0);
		ASSERT(sysFirstLvlPtStart + index < sysFirstLvlPtStop);
		entry := physical + permissions * 400H + flags + type;
		(*Trace.Address(virtual); Trace.String("	"); Trace.Address(physical); Trace.String("	"); Trace.Address(SysFirstLvlPtStart(*pageTable.virtual*) + index); Trace.String("	"); Trace.Address(entry); Trace.Ln;*)
		SYSTEM.PUT32(sysFirstLvlPtStart + index, entry)
	END SetFirstLevelEntry;

	PROCEDURE GetFirstLevelEntry (virtual: ADDRESS): SIGNED32;
	VAR
		index: SIGNED32;
	BEGIN
		index := LSH(virtual, -(LogM)) * 4;
		ASSERT(index >= 0);
		ASSERT(sysFirstLvlPtStart + index < sysFirstLvlPtStop);
		RETURN SYSTEM.GET32(sysFirstLvlPtStart + index)
	END GetFirstLevelEntry;

	(* AllocateHeap - allocates and maps [physicalAddress...physicalAddress+size] to [virtualAddress...virtualAddress+size] *)
	PROCEDURE AllocateHeap(virtualAddress, physicalAddress, size: ADDRESS; accessPermissions, flags: SIGNED32);
	VAR i, entry: SIGNED32;
	BEGIN
		ASSERT(size MOD M = 0);
		FOR i := 0 TO (size DIV M) - 1 DO
			entry := GetFirstLevelEntry(virtualAddress + i * M);
			ASSERT(entry = 0);
			SetFirstLevelEntry(virtualAddress + i * M, physicalAddress + i * M, accessPermissions, flags, flSection)
		END
	END AllocateHeap;

	(** Enable Memory Management and virtual memory. *)
	PROCEDURE EnableMM(translationBase, tbFlags, mmuFlags: ADDRESS);
	BEGIN
		InvalidateTLB;
		CODE
			; Disable AFE (special permission mode) and TRE (special memory mode)
			ldr r0, [pc, #pattern-$-8]
			mrc p15, 0, r1, c1, c0, 0
			and r1, r0, r1
			mcr p15, 0, r1, c1, c0, 0
			isb

			;mrc p15, 0, r0, c2, c0, 2
			;ldr r1, [pc, #TLBCRPattern-$-8]
			;and r0, r0, r1
			;mcr p15, 0, r0, c2, c0, 2

			ldr r0, [FP, #translationBase]
			ldr	r1, [fp, #tbFlags]
			orr r0, r0, r1
			mcr p15, 0, r0, c2, c0, 0
			isb
			;mvn r0, #0 	; mmu domains: 16 x 11 = manager on all domains
			ldr r0, [pc, #domains-$-8]
			mcr p15, 0, r0, c3, c0, 0
			isb
			ldr r0, [FP, #mmuFlags]
			ldr r1, [FP, #sctlr-$-8]
			orr r0, r0, r1 ; 1 bits in SCTLR
			mcr p15, 0, r0, c1, c0, 0
			isb

			;dsb
			;isb

			b exit
		domains:	d32 55555555H		; Client on each domain
		pattern:	d32 0CFFFFFFFH	; NOT(AFE+TRE)
		sctlr:		d32 0C50078H
		TLBCRPattern: d32 0FFFFFFF8H
		exit:
		END;
		proc[ID()].mmu := TRUE
	END EnableMM;

	PROCEDURE InitMemory;
	VAR
		cr1: SET;
		i: SIGNED32;
		base: ADDRESS;
		coarseFlags, fineFlags, tbFlags: SIGNED32;
		trace: BOOLEAN;
		val: ARRAY 8 OF CHAR;
	BEGIN
		BootConfig.GetValue("TraceMemory", val);
		trace := val = '1';
		IF trace THEN
			(* Debug Tracing *)
			Trace.String("Memory Layout");
			IF ~enableCaching THEN Trace.String(" - WARNING: Caching Disabled") END;
			Trace.Ln;
			Trace.String("System Start:	"); Trace.Address(memSysLowStart); Trace.Ln;
			Trace.String("System Stop:	"); Trace.Address(memSysLowStop); Trace.Ln;
			Trace.String("System Size:	"); Trace.Address(memSysLowStop - memSysLowStart); Trace.Ln;
			Trace.String("	Interrupt Stack Start:		"); Trace.Address(sysIntStackStart); Trace.Ln;
			Trace.String("	Interrupt Stack Stop:		"); Trace.Address(sysIntStackStop); Trace.Ln;
			Trace.String("	Interrupt Stack Size:		"); Trace.Address(sysIntStackStop - sysIntStackStart); Trace.Ln;
			Trace.String("	First Page Table Start:	"); Trace.Address(sysFirstLvlPtStart); Trace.Ln;
			Trace.String("	First Page Table Stop:		"); Trace.Address(sysFirstLvlPtStop); Trace.Ln;
			Trace.String("	First Page Table Size:		"); Trace.Address(sysFirstLvlPtStop - sysFirstLvlPtStart); Trace.Ln;
			Trace.String("	Second Page Table Start:	"); Trace.Address(sysSecondLvlPtStart); Trace.Ln;
			Trace.String("	Second Page Table Stop:	"); Trace.Address(sysSecondLvlPtStop); Trace.Ln;
			Trace.String("	Second Page Table Size:	"); Trace.Address(sysSecondLvlPtStop - sysSecondLvlPtStart); Trace.Ln;
			Trace.String("Heap Start:		"); Trace.Address(memHeapStart); Trace.Ln;
			Trace.String("Heap Stop:		"); Trace.Address(memHeapStop); Trace.Ln;
			Trace.String("Heap Size:		"); Trace.Address(memHeapStop - memHeapStart); Trace.Ln;
			Trace.String("Stack Start:	"); Trace.Address(memStackStart); Trace.Ln;
			Trace.String("Stack Stop:		"); Trace.Address(memStackStop); Trace.Ln;
			Trace.String("Stack Size:		"); Trace.Address(memStackStop - memStackStart); Trace.Ln;
			Trace.String("Config Start:	"); Trace.Address(memConfigStart); Trace.Ln;
			Trace.String("Config Stop:	"); Trace.Address(memConfigStop); Trace.Ln;
			Trace.String("Config Size:	"); Trace.Address(memConfigStop - memConfigStart); Trace.Ln;
			Trace.String("I/O Start:		"); Trace.Address(memIOStart); Trace.Ln;
			Trace.String("I/O Stop:		"); Trace.Address(memIOStop); Trace.Ln;
			Trace.String("I/O Size:		"); Trace.Address(memIOStop - memIOStart); Trace.Ln;
			Trace.String("SysHigh Start:	"); Trace.Address(memSysHighStart); Trace.Ln;
			Trace.String("SysHigh Stop:	"); Trace.Hex(memSysHighStop - 1, -8); Trace.Ln;
			Trace.String("	Interrupt Vector Start:	"); Trace.Address(sysVectorStart); Trace.Ln;
			Trace.String("	Interrupt Vector Stop:	"); Trace.Address(sysVectorStop); Trace.Ln;
			Trace.String("	Interrupt Vector Size:	"); Trace.Address(sysVectorStop - sysVectorStart); Trace.Ln;
			Trace.String("	Cache References Start:	"); Trace.Address(sysCacheRefStart); Trace.Ln;
			Trace.String("	Cache References Stop:	"); Trace.Address(sysCacheRefStop); Trace.Ln;
			Trace.String("	Cache References Size:	"); Trace.Address(sysCacheRefSize); Trace.Ln;
			Trace.String("	Cache References Stack Offset:	"); Trace.Address(sysCacheStackOfs); Trace.Ln;
		END;

		(* disable caching & buffering globally *)
		cr1 := GetControlRegister();
		SetControlRegister(cr1 - {DCache, ICache});
		(*InvalidateDCache(dCacheBase);*)
		(*InvalidateDCacheRange(0, MemStackStop);*)
		InvalidateICache;
		DrainWriteBuffer;

		(* initialize memory ranges *)
		heapLow.physical := memHeapStart;
		heapLow.virtual := memHeapStart;
		heapHigh.physical := memHeapStop;
		heapHigh.virtual := memHeapStart;

		stackHigh.physical := memStackStop;
		stackHigh.virtual := memStackStop;
		stackLow.physical := memStackStop;
		stackLow.virtual := memStackStart;

		(* initialize global variables *)
		pageTable.virtual := sysFirstLvlPtStart;
		pageTable.memory := sysFirstLvlPtStart;
		stackPT := sysSecondLvlPtStart + 2 * k;
		freePage := NilAdr;

		(* Determine global caching parameter *)
		IF enableCaching THEN
			coarseFlags := Cacheable + Shareable;
			fineFlags := CB
		ELSE
			coarseFlags:= Shareable;
			fineFlags := 0;
		END;

		(* Clear first level page table *)
		Fill32(sysFirstLvlPtStart, sysFirstLvlPtStop - sysFirstLvlPtStart, 0);

		(* Clear second level page table *)
		Fill32(sysSecondLvlPtStart, sysSecondLvlPtStop - sysSecondLvlPtStart, 0);

		(* Map system area *)
		SetFirstLevelEntry(0, sysSecondLvlPtStart, 0, 0, flCoarse);
		FOR i := 1 TO 0FFH DO
			SetSecondLevelEntry(PS * i, PS * i, FullAccess + fineFlags);
		END;

		(* Map page for high part of OCM *)
		AllocateHeap(memSysHighStart, memSysHighStart, MAX(M, SIGNED32(memSysHighStop - memSysHighStart)), SrwUrw, coarseFlags);

		(* Map heap area *)
		AllocateHeap(memHeapStart, memHeapStart, memHeapStop - memHeapStart, SrwUrw, coarseFlags);

		(* Map I/O area, device-type, shared memory *)
		AllocateHeap(memIOStart, memIOStart, memIOStop - memIOStart, SrwUrw, Shareable + B);

		(* initialize stack & config page tables (excluding the last MB that is already initalized) *)
		base := opSHR(memStackStart, LogM);
		FOR i := memStackStart TO memConfigStop - 1 BY M DO
			SetFirstLevelEntry(i, sysSecondLvlPtStart + 2 * k + PTSize * (opSHR(i, LogM) - base), 0, 0, flCoarse)
		END;

		(* Map config region directly *)
		FOR i := 0 TO opSHR(memConfigStop - memConfigStart, PSlog2) - 1 DO
			SetSecondLevelEntry(memConfigStart + PS * i, memConfigStart + PS * i, FullAccess + fineFlags)
		END;

		(* flush all caches & the write buffer and invalidate both TLBs *)
		FlushDCacheRange(0, SYSTEM.VAL(ADDRESS, LastAddress));
		InvalidateICache;
		DrainWriteBuffer;
		InvalidateTLB;

		(* get memory size *)
		memory.size := memHeapStop - memHeapStart;
		memory.free := memory.size;

		(* get heap size (check how many MBs are allocated) *)
		heapLow.physical := 1*M; heapLow.virtual := memHeapStart;
		heapHigh.physical := 1*M;
		i := opSHR(memHeapStart, LogM);
		WHILE (SYSTEM.GET32(pageTable.virtual + i*4) MOD 4 = flSection) DO
			INC(heapHigh.physical, M);
			DEC(memory.free, M);
			INC(i)
		END;
		heapHigh.virtual := heapLow.virtual + heapHigh.physical - heapLow.physical;

		(* allocate empty memory block with enough space for at least one free block *)
		memBlockHead := SYSTEM.VAL (MemoryBlock, ADDRESSOF (initialMemBlock));
		memBlockTail := memBlockHead;
		initialMemBlock.beginBlockAdr := SYSTEM.VAL (ADDRESS, LastAddress);
		initialMemBlock.endBlockAdr := heapHigh.virtual;
		initialMemBlock.size := initialMemBlock.endBlockAdr - initialMemBlock.beginBlockAdr;
		initialMemBlock.next := NIL;
		freeStackIndex := 0;

		(* init stack bitmap *)
		FOR i := 0 TO (maxUserStacks) DIV 32 - 1 DO
			freeStack[i] := {0..31};
		END;
		freeStack[(maxUserStacks) DIV 32] := {0 .. (SIGNED32(maxUserStacks) MOD 32) - 1};
		freeStackIndex := 0;

		(* Init cache ref counts *)
		cacheRefs := sysCacheRefStart;
		Fill32(sysCacheRefStart, sysCacheRefSize, 0);

		IF enableCaching THEN
			tbFlags := 7BH
		ELSE
			tbFlags := 0
		END;

		(* Copy interrupt vector *)
		SYSTEM.MOVE(0, 0FFFF0000H, 4096);

		EnableMM(sysFirstLvlPtStart, tbFlags, 2000H + 1007H);
	END InitMemory;

	(** GetFreeK - returns information on free memory in Kbytes.*)
	PROCEDURE GetFreeK*(VAR total, lowFree, highFree: SIZE);
	BEGIN
		Acquire(Memory);
		total := opSHR(memory.size, 10);
		lowFree := 0;
		highFree := opSHR(memory.free, 10);
		Release(Memory)
	END GetFreeK;

	(* ===== Stack Management ===== *)
	(** Extend stack to address. Returns TRUE iff done.
	 * If a procedure that holds Memory needs triggers a stack extension, this procedure is called by the interrupt handler:
	 * we get a trap because Acquire is not reentrant. To solve this, we do not acquire memory iff:
	 *	- we are in interrupt mode
	 *	- the current processor holds Memory already
	 *)
	PROCEDURE ExtendStack*(VAR s: Stack; virtAdr: ADDRESS): BOOLEAN;
	VAR
		ok, doLock: BOOLEAN;
		access, psr, flags: SIGNED32;
	BEGIN
		IF enableCaching THEN
			flags := CB
		ELSE
			flags := 0
		END;

		SYSTEM.STPSR(0, psr);
		(* Need to acquire Memory: if we are not in interrupt mode or if we do not hold this lock yet. *)
		doLock := ~(Memory IN proc[ID()].locksHeld);
		IF doLock THEN Acquire(Memory) END;
		ok := FALSE;

		IF (virtAdr < s.high) & (virtAdr >= s.low) THEN
			(* Get page boundary *)
			DEC(virtAdr, virtAdr MOD PS);

			(* Check if page is mapped *)
			(*InvalidateDCacheRange(memSysLowStart, memSysLowStop - memSysLowStart);*)
			Initializer.InvalidateDCache;
			IF (GetSecondLevelEntry(virtAdr) MOD 4 = slSmall) THEN
				InvalidateTLBEntry(virtAdr);
				Acquire(TraceOutput);
				Trace.String("Stack address already mapped: ");
				Trace.Address(virtAdr); Trace.Ln;
				Release(TraceOutput)
			ELSE
				(* Allocate page: set different permissions for last stack page. *)
				(*IF (virtAdr <= s.low) THEN HALT(100) ELSE access := FullAccess END;*)
				access := FullAccess;

				ok := AllocatePage(virtAdr, access, flags);
				IF virtAdr < s.adr THEN
					s.adr := virtAdr
				END
			END
		ELSE
			Acquire(TraceOutput);
			Trace.StringLn("Address not in stack");Trace.Address(virtAdr);
			Release(TraceOutput);
			ok := FALSE
		END;
		IF doLock THEN Release(Memory) END;
		RETURN ok
	END ExtendStack;

	(** Create a new stack s, for process with the initial stack pointer initSP. *)
	PROCEDURE NewStack*(VAR s: Stack; process: ANY; VAR initSP: ADDRESS);
	VAR
		old, flags: SIGNED32;
		adr: ADDRESS;
		free: SET;
		b: BOOLEAN;
	BEGIN
		Acquire(Memory);
		old := freeStackIndex;
		IF enableCaching THEN
			flags := CB
		ELSE
			flags := 0
		END;
		LOOP
			free := freeStack[freeStackIndex];
			IF free # {} THEN
				(* Find the free stack space in that region and mark it as allocated *)
				adr := 0;
				WHILE ~(adr IN free) DO INC(adr) END;
				EXCL(freeStack[freeStackIndex], SIZE(adr));
				adr := memStackStart + (freeStackIndex * 32 + adr) * maxUserStackSize;

				EXIT
			END;
			INC(freeStackIndex);
			IF freeStackIndex = LEN(freeStack) THEN freeStackIndex := 0 END;
			IF freeStackIndex = old THEN HALT(1503) END
		END;
		s.high := adr + maxUserStackSize; s.low := adr + StackGuardSize;
		s.adr := s.high - InitStackSize;	(* at the top of the virtual area *)
		initSP := s.high;
		b := AllocatePage(s.adr, FullAccess, flags); (* allocate one physical page first *)

		ASSERT(b);
		FlushDCacheRange(sysSecondLvlPtStart, sysSecondLvlPtStop - sysSecondLvlPtStart);
		Release(Memory)
	END NewStack;

	PROCEDURE DisposeStack*(s: Stack);
	VAR
		adr: ADDRESS;
	BEGIN
		Acquire(Memory);
		adr := s.adr;
		WHILE adr # s.high DO
			DeallocatePage(adr);
			INC(adr, PS)
		END;

		adr := (adr - maxUserStacks - memStackStart) DIV maxUserStackSize;
		INCL(freeStack[adr DIV 32], SIZE(adr MOD 32));
		Release(Memory)
	END DisposeStack;

	(** Check if the specified stack is valid. *)
	PROCEDURE ValidStack*(CONST s: Stack; sp: ADDRESS): BOOLEAN;
	VAR valid: BOOLEAN;
	BEGIN
		Acquire(Memory);
		valid := (sp MOD 4 = 0) & (sp >= s.adr) & (sp <= s.high);
		WHILE valid & (sp < s.high) DO
			valid := GetSecondLevelEntry(sp) MOD 4 = slSmall;
			INC(sp, PS)
		END;
		Release(Memory);
		RETURN valid
	END ValidStack;

	PROCEDURE GetStack(adr: ADDRESS; VAR s: Stack): BOOLEAN;
	BEGIN
		IF (adr < memStackStart) OR (adr > memStackStop) THEN
			RETURN FALSE
		END;
		s.high := adr - PS;
		s.low := adr - 4;
		s.adr := adr;
		RETURN TRUE
	END GetStack;

	(* ===== Heap ===== *)
	PROCEDURE ValidHeapAddress*(p: ADDRESS): BOOLEAN;
	BEGIN
		RETURN (memHeapStart <= p) & (p < memHeapStop) & (p MOD 4 = 0)
	END ValidHeapAddress;

	(* Free unused memory block *)
	PROCEDURE FreeMemBlock*(memBlock: MemoryBlock);
	BEGIN
		HALT(515) (* impossible to free heap *)
	END FreeMemBlock;

	(** Set memory block end address *)
	PROCEDURE SetMemoryBlockEndAddress*(memBlock: MemoryBlock; endBlockAdr: ADDRESS);
	BEGIN
		ASSERT(endBlockAdr >= memBlock.beginBlockAdr);
		memBlock.endBlockAdr := endBlockAdr
	END SetMemoryBlockEndAddress;

	(* Policy decision for heap expansion. NewBlock for the same block has failed try times. *)
	(*PROCEDURE ExpandNow(try: SIGNED32): BOOLEAN;
	VAR size: SIZE;
	BEGIN
		size := LSH(memBlockTail.endBlockAdr - memBlockHead.beginBlockAdr, -10);	(* heap size in KB *)
		RETURN (~ODD(try) OR (size < heapMinKB)) & (size < heapMaxKB)
	END ExpandNow;*)

	(** Attempt to set the heap end address to the specified address. The returned value is the actual new end address (never smaller than previous value). *)
	(*PROCEDURE SetHeapEndAdr(VAR endAdr: ADDRESS);
	VAR n, m: SIZE;
	BEGIN
		HALT(100);
		Acquire(Memory);
		(*
		n := LSH(endAdr+(PS-1), -PSlog2) - LSH(heapEndAdr, -PSlog2);	(* pages requested *)
		m := LSH(pageHeapAdr, -PSlog2) - LSH(heapEndAdr, -PSlog2) - ReservedPages;	(* max pages *)
		IF n > m THEN n := m END;
		IF n > 0 THEN INC(heapEndAdr, n*PS); DEC(freeHighPages, n) END;
		endAdr := heapEndAdr;
		*)
		Release(Memory)
	END SetHeapEndAdr;*)

	(* Try to expand the heap by at least "size" bytes *)
	PROCEDURE ExpandHeap*(try: SIGNED32; size: SIZE; VAR memBlock: MemoryBlock; VAR beginBlockAdr, endBlockAdr: ADDRESS);
	BEGIN
		(*IF ExpandNow(try) THEN
			IF size < expandMin THEN size := expandMin END;
			beginBlockAdr := memBlockHead.endBlockAdr;
			endBlockAdr := beginBlockAdr;
			INC(endBlockAdr, size);
			SetHeapEndAdr(endBlockAdr);	(* in/out parameter *)
			memBlock := memBlockHead;
			(* endBlockAdr of memory block is set by caller after free block has been set in memory block - this process is part of lock-free heap expansion *)
		ELSE*)
			beginBlockAdr := memBlockHead.endBlockAdr;
			endBlockAdr := memBlockHead.endBlockAdr;
			memBlock := NIL
		(*END*)
	END ExpandHeap;

	(** GetStaticHeap - get page range (beginAdr..endAdr-1) and first and last block of static heap.*)
	PROCEDURE GetStaticHeap*(VAR beginBlockAdr, endBlockAdr, freeBlockAdr: ADDRESS);
	BEGIN
		beginBlockAdr := initialMemBlock.beginBlockAdr;
		endBlockAdr := initialMemBlock.endBlockAdr;
		freeBlockAdr := beginBlockAdr;
	END GetStaticHeap;

	(* ===== Caches, TLB & other ===== *)
	(** SHR - logical shift right *)
	PROCEDURE opSHR(value, shift: ADDRESS): SIGNED32;
	CODE
		LDR R0, [FP, #value]
		LDR R1, [FP, #shift]

		MOV R0, R0, LSR R1
	END opSHR;

	(** SHRL - shift right and left. Mask out 'shift' lowest bits *)
	PROCEDURE SHRL(value, shift: SIGNED32): SIGNED32;
	(*CODE
		LDR R0, [FP, #value]
		LDR R1, [FP, #shift]

		MOV R0, R0, LSR R1
		MOV R0, R0, LSL R1*)
	BEGIN
		value := LSH(value, -shift);
		value := LSH(value, shift);
		RETURN value
	END SHRL;

	(** Fills 'size' bytes with 'filler', from 'destAdr' on. size must be multiple of 4 *)
	PROCEDURE Fill32*(destAdr: ADDRESS; size: SIZE; filler: SIGNED32);
	CODE
		LDR	R0, [FP, #filler]
		LDR	R1, [FP, #size]
		LDR	R3, [FP, #destAdr]
		ADD	R4, R1, R3				; R4 = size + destAdr

		AND	R5, R3, #3				; R5 := R3 MOD 4
		CMP	R5, #0					; ASSERT(R5 = 0)
		BEQ	CheckSize
		SWI	#8

	CheckSize:
		AND	R5, R1, #3				; R5 := R1 MOD 4
		CMP	R5, #0					; ASSERT(R5 = 0)
		BEQ	Loop
		SWI	#8

	Loop:
		CMP	R4, R3
		BLS		Exit
		STR	R0, [R3, #0]			; put(destAdr + counter, filler)
		ADD	R3, R3, #4				; R3 := R3 + 4
		B		Loop
	Exit:
	END Fill32;

	(* GetPageTableBase - returns the memory address of the first level page table *)
	PROCEDURE -GetPageTableBase(): SIGNED32;
	CODE
		MRC p15, 0, R0, c2, c0, 0
		MOV R0, R0, LSR #14	; clear bits 13..0
		MOV R0, R0, LSL #14
	END GetPageTableBase;

	(** GC Initialization -- Set machine-dependent parameters gcThreshold, expandMin, heapMinKB and heapMaxKB *)
	PROCEDURE SetGCParams*;
	VAR size, t: SIZE;
	BEGIN
		GetFreeK(size, t, t);	(* size is total memory size in KB *)
		heapMinKB := size * HeapMin DIV 100;
		heapMaxKB := size * HeapMax DIV 100;
		expandMin := size * ExpandRate DIV 100 * 1024;
		IF expandMin < 0 THEN expandMin := MAX(SIGNED32) END;
		gcThreshold := size * Threshold DIV 100 * 1024;
		IF gcThreshold < 0 THEN gcThreshold := MAX(SIGNED32) END
	END SetGCParams;

	(** Called when spinning, just does a NOP *)
	PROCEDURE -SpinHint*;
	CODE
		MOV R0, R0
	END SpinHint;

	(** Convert a string to an integer. Parameter i specifies where in the string scanning should begin (usually 0 in the first call). Scanning stops at the first non-valid character, and i returns the updated position. Parameter s is the string to be scanned. The value is returned as result, or 0 if not valid. Syntax: number = ["-"] digit {digit} ["H" | "h"] . digit = "0" | ... "9" | "A" .. "F" | "a" .. "f" . If the number contains any hexdecimal letter, or if it ends in "H" or "h", it is interpreted as hexadecimal. *)
	PROCEDURE StrToInt* (VAR i: SIZE; CONST s: ARRAY OF CHAR): SIGNED32;
	VAR vd, vh, sgn, d: SIGNED32; hex: BOOLEAN;
	BEGIN
		vd := 0; vh := 0; hex := FALSE;
		IF s[i] = "-" THEN sgn := -1; INC (i) ELSE sgn := 1 END;
		LOOP
			IF (s[i] >= "0") & (s[i] <= "9") THEN d := ORD (s[i])-ORD ("0")
			ELSIF (CAP (s[i]) >= "A") & (CAP (s[i]) <= "F") THEN d := ORD (CAP (s[i]))-ORD ("A") + 10; hex := TRUE
			ELSE EXIT
			END;
			vd := 10*vd + d; vh := 16*vh + d;
			INC (i)
		END;
		IF CAP (s[i]) = "H" THEN hex := TRUE; INC (i) END;	(* optional H *)
		IF hex THEN vd := vh END;
		RETURN sgn * vd
	END StrToInt;

	(** Read Non Volatile memory. Not implemented. Required by clock. *)
	PROCEDURE GetNVByte* (ofs: SIGNED32): CHAR;
	BEGIN
		RETURN 10X
	END GetNVByte;

	(** Write Non Volatile memory. Not implemented. Required by clock. *)
	PROCEDURE PutNVByte* (ofs: SIGNED32; val: CHAR);
	END PutNVByte;

	(* empty section allocated at end of bootfile *)
	PROCEDURE {NOPAF, ALIGNED(32)} LastAddress;
	CODE
	END LastAddress;

	PROCEDURE GetConfig*(CONST name: ARRAY OF CHAR; VAR res: ARRAY OF CHAR);
	BEGIN
		BootConfig.GetValue(name, res)
	END GetConfig;

	PROCEDURE MulH * (x, y: SIGNED64): SIGNED64;
	BEGIN
		RETURN SIGNED32(x) * SIGNED32(y)
	END MulH;

	PROCEDURE DivH * (x, y: SIGNED64): SIGNED64;
	BEGIN
		RETURN x DIV y
	END DivH;

	(** Not implemented yet *)
	PROCEDURE  Portin8*(port: SIGNED32; VAR val: CHAR);
	END Portin8;

	PROCEDURE  Portout8*(port: SIGNED32; val: CHAR);
	END Portout8;

	PROCEDURE TraceState * (CONST state: State);
	BEGIN
		Trace.StringLn("General Purpose Registers");
		Trace.String("R0	"); Trace.Address(state.R[0]); Trace.Ln;
		Trace.String("R1	"); Trace.Address(state.R[1]); Trace.Ln;
		Trace.String("R2	"); Trace.Address(state.R[2]); Trace.Ln;
		Trace.String("R3	"); Trace.Address(state.R[3]); Trace.Ln;
		Trace.String("R4	"); Trace.Address(state.R[4]); Trace.Ln;
		Trace.String("R5	"); Trace.Address(state.R[5]); Trace.Ln;
		Trace.String("R6	"); Trace.Address(state.R[6]); Trace.Ln;
		Trace.String("R7	"); Trace.Address(state.R[7]); Trace.Ln;
		Trace.String("R8	"); Trace.Address(state.R[8]); Trace.Ln;
		Trace.String("R9	"); Trace.Address(state.R[9]); Trace.Ln;
		Trace.String("R10	"); Trace.Address(state.R[10]); Trace.Ln;
		Trace.String("R11	"); Trace.Address(state.R[11]); Trace.Ln;

		Trace.StringLn("Stack");
		Trace.String("SP	"); Trace.Address(state.SP); Trace.Ln;
		Trace.String("FP	"); Trace.Address(state.BP); Trace.Ln;

		Trace.StringLn("Code");
		Trace.String("LR	"); Trace.Address(state.LR); Trace.Ln;
		Trace.String("PC	"); Trace.Address(state.PC); Trace.Ln;

		Trace.Ln;
		Trace.String("PSR	"); Trace.Address(state.PSR); Trace.Ln;

		Trace.Ln;
		Trace.String("int	"); Trace.Address(state.INT); Trace.Ln;
	END TraceState;

	PROCEDURE ReadMemLayout;
	VAR
		value: ARRAY 64 OF CHAR;
		i: SIZE;
	BEGIN
		memSysLowStart := Platform.OCMStart;
		memSysLowStop := memSysLowStart + Platform.OCMSize;

		GetConfig("KernelLoadAdr", value);
		i := 0;
		memHeapStart := StrToInt(i, value);
		GetConfig("HeapSize", value);
		i := 0;
		memHeapStop := memHeapStart + StrToInt(i, value);

		GetConfig("DDRSize", value);
		i := 0;
		memConfigStop := Platform.DDRStart + StrToInt(i, value);
		GetConfig("ConfigSize", value);
		i := 0;
		memConfigStart := memConfigStop - StrToInt(i, value);

		memStackStart := memHeapStop;
		memStackStop := memConfigStart;

		memIOStart := Platform.IOStart;
		memIOStop := memIOStart + Platform.IOSize;

		memSysHighStart := ADDRESS(4 * G - M);
		memSysHighStop := 4 * G - 1;

		(* System Parameters *)
		sysIntStackStart := memSysLowStart + 1000H;
		sysIntStackStop := memSysLowStart + Platform.MaxCpuNb * 4 * 4 * k;

		(* The first level page table is always 16 k large, to map all 4 G of virtual memory space *)
		sysFirstLvlPtStop := memSysLowStop;
		sysFirstLvlPtStart := sysFirstLvlPtStop - 16 * k;
		(*
		 * Second Level Page Table:
		 *		- 2 * 256 entries for the system area (first and last MB of VMem)
		 *		- 256 entries for each MB of virtual stack space
		 * 256 entries take 1kB memory space.
		 *)
		sysSecondLvlPtStop := sysFirstLvlPtStart;
		sysSecondLvlPtStart := sysSecondLvlPtStop - (2 + (memStackStop - memStackStart + memConfigStop - memConfigStart) DIV M) * k;
		(*
		 * Interrupt Vector. Located at 0FFFFFFF0H
		 *)
		sysVectorStart := 0FFFF0000H;
		sysVectorStop := sysVectorStart + PS;
		sysCacheRefStart := 0FFFF1000H;
		(*
		 * Number of ref counters: 1 per 1st level heap page, 1 per 2nd level stack page.
		 * This memory region is organized as follows: the first part [0 .. SysCacheStackOfs) is used for heap pages,
		 * the second part, [SysCacheStackOfs .. SysCacheRefSize) is used for stack pages.
		 *)
		sysCacheRefSize := (memHeapStop - memHeapStart) DIV M + (memStackStop - memStackStart) DIV PS;
		INC(sysCacheRefSize, 4 - sysCacheRefSize MOD 4);
		(* Offset in the ref count table for stack pages. *)
		sysCacheStackOfs := (memHeapStop - memHeapStart) DIV M;

		sysCacheRefStop := sysCacheRefStart + sysCacheRefSize;

		(* Process stack system *)
		GetConfig("StackSize", value);
		i := 0;
		maxUserStackSize := StrToInt(i, value);
		maxUserStacks := (memStackStop - memStackStart) DIV maxUserStackSize;

		GetConfig("EnableCaching", value);
		enableCaching := value[0] # '0';

		traceInterrupts := BootConfig.GetBoolValue("TraceInterrupts")
	END ReadMemLayout;

	PROCEDURE GetProcessorNumber;
	VAR
		value: ARRAY 64 OF CHAR;
		i: SIZE;
	BEGIN
		FOR i := 0 TO 63 DO value[i] := 0X END;
		GetConfig("CpuNb", value);
		i := 0;
		numProcessors := StrToInt(i, value)
	END GetProcessorNumber;

	(** Analyse reasons for reset, print and record them. *)
	PROCEDURE ResetAnalysis;
	CONST
		(* We need these constants as Platform.slcr is not initialized yet *)
		SLCR_REBOOT_STATUS = ADDRESS(0F8000258H);
		SLCR_LOCK = ADDRESS(0F8000004H);
		SLCR_UNLOCK = ADDRESS(0F8000008H);
		Lock = SIGNED32(767BH);
		Unlock = SIGNED32(0DF0DH);
	VAR
		val: SET;
		error: SIGNED32;
	BEGIN
		SYSTEM.GET(SLCR_REBOOT_STATUS, val);
		IF 16 IN val THEN
			lastReboot := RebootSystemWatchdog;
			Trace.StringLn("Starting after system watchdog reset")
		END;
		IF 17 IN val THEN
			lastReboot := RebootWatchdogCPU0;
			Trace.StringLn("Starting after private watchdog reset on CPU0")
		END;
		IF 18 IN val THEN
			lastReboot := RebootWatchdogCPU1;
			Trace.StringLn("Starting after private watchdog reset on CPU1")
		END;
		IF 19 IN val THEN
			lastReboot := RebootSoftReset;
			Trace.StringLn("Starting after software reboot")
		END;
		IF 20 IN val THEN
			lastReboot := RebootDebug;
			Trace.StringLn("Starting after debug reset")
		END;
		IF 21 IN val THEN
			lastReboot := RebootHardReset;
			Trace.StringLn("Starting after hard reset")
		END;
		IF 22 IN val THEN
			lastReboot := RebootPowerOn;
			Trace.StringLn("Starting after power on")
		END;
		error := SYSTEM.VAL(SIGNED16, val);
		IF error # 0 THEN
			Trace.String("BootROM error code: "); Trace.Int(error, 0); Trace.Ln
		END;
		SYSTEM.PUT(SLCR_UNLOCK, Unlock);
		SYSTEM.PUT(SLCR_REBOOT_STATUS, SIGNED32(0));
		SYSTEM.PUT(SLCR_LOCK, Lock)
	END ResetAnalysis;

	PROCEDURE InitWatchdog;
	VAR val: ARRAY 32 OF CHAR;
	BEGIN
		GetConfig("EnableKernelWatchdog", val);
		enableWatchdog := val = '1';
		IF enableWatchdog THEN
			PrivateWatchdog.Init(BootConfig.GetIntValue("CpuClockHz") DIV 2);
			PrivateWatchdog.Start(PrivateWatchdog.Reset, Second)
		END
	END InitWatchdog;

	PROCEDURE Init;
	BEGIN
		BootConfig.Init;
		ReadMemLayout;

		sp := SYSTEM.GetStackPointer();
		fp := SYSTEM.GetFramePointer();

		SYSTEM.LDPSR( 0, Platform.IRQMode + Platform.FIQDisabled + Platform.IRQDisabled );
		SYSTEM.SETSP(sysIntStackStart + 1000H);

		SYSTEM.LDPSR( 0, Platform.UndefMode + Platform.FIQDisabled + Platform.IRQDisabled );
		SYSTEM.SETSP(sysIntStackStart + 1000H * 2);

		SYSTEM.LDPSR( 0, Platform.AbortMode + Platform.FIQDisabled + Platform.IRQDisabled );
		SYSTEM.SETSP(sysIntStackStart + 1000H * 3);

		SYSTEM.LDPSR( 0, Platform.SVCMode + Platform.FIQDisabled + Platform.IRQDisabled );
		SYSTEM.SETSP(sysIntStackStart + 1000H * 4);

		SYSTEM.LDPSR( 0, Platform.SystemMode + Platform.FIQDisabled + Platform.IRQDisabled );   (* Disable interrupts, init SP, FP *)
		SYSTEM.SETSP(sp);
		SYSTEM.SETFP(fp);

		TraceDevice.Install;
		Trace.String("Machine: "); Trace.StringLn (Version);
		version := Version;
		InitProcessor;
		InstallDefaultInterrupts;
		DisableInterrupts;
		ResetAnalysis;

		(* Ensure memory layout consistency *)
		ASSERT(sysIntStackStart >= 4 * k);
		ASSERT(sysIntStackStop <= sysSecondLvlPtStart);
		ASSERT(sysFirstLvlPtStart MOD (16 * k) = 0);
		ASSERT(memStackStop <= memIOStart);
		ASSERT(memIOStop <= memSysHighStart);
		ASSERT(sysVectorStop <= sysCacheRefStart);
		ASSERT(sysCacheRefStop <= memSysHighStop);

		InitMemory;
		GetProcessorNumber;
		InitLocks;
		InitGlobalTimer
	END Init;

	PROCEDURE {INITIAL} Initial;
	BEGIN
		Init;
	END Initial;

END Machine.
