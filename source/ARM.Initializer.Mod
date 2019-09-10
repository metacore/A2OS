MODULE Initializer;
(**
	AUTHOR "Timothée Martiel";
	PURPOSE "Processor initialization code for ARM kernel";

	This module provides initialization for CPUs. It contains the initial procedure that begins the execution of
	the kernel. It also provides a mechanism for starting secondary processors: all processors should start executing
	at the beginning of the kernel image (i.e. Init): only CPU with id 0 will continue and start the kernel. The other
	processors will be sleeping in Init, waiting to be started later.
*)
IMPORT SYSTEM (* Needed to avoid Runtime importing Heaps *);
VAR
	(**
		Wakeup address for secondary processors: if set # 0, the CPU with id matching "secondaryProcId" will jump to
		that address.
	*)
	secondaryBootProc *: ADDRESS;
	(**
		Wakup id for secondary processors: when executing SEV, all CPUs wakup. Only the CPU with id matching this field
		will read and jump to "secondaryBootProc".
	*)
	secondaryProcId *: SIGNED32;

	(** Configuration string base address *)
	configBase *: ADDRESS;
	(** Configuration string size *)
	configSize *: SIGNED32;

	(**
		Initial kernel code: this code is placed at the beginning of the kernel image and is executed by all CPUs.
		This code:
			- sets up a stack
			- disables interrupts and MMU
			- sets the interrupt vector to 0
			- invalidates caches
			- put secondary processors into the sleeping loop
			- allow CPU0 to continue kernel initialization
	*)
	PROCEDURE {INITIAL,NOPAF} Init;
	CODE
		; set IRQ vector base register to zero
		MOV	R2, #0
		MCR	P15, 0, R2, C12, C0, 0

		; disable MMU
		MRC	P15, 0, R2, C1, C0, 0
		BIC		R2, R2, #1
		MCR	P15, 0, R2, C1, C0, 0

		LDR	FP, [pc, #InitialFP-$-8]				; set stack pointer
		LDR	SP, [pc, #InitialFP-$-8]				; set frame pointer

		B		getProcId
	InitialFP: 			d32 0001B000H				; initial frame pointer address, internal memory bank

		; Set SMP mode
		MRC p15, 0, R2, C1, C0, 1
		ORR R2, R2, #041H
		MCR p15, 0, R2, C1, C0, 1
		ISB

		; Filter CPUs: only CPU0 must initialize the kernel, other are started later on demand
		MOV	R2, #0

	getProcId:
		MRC	P15, 0, R3, C0, C0, 5
		AND	R3, R3, #0FH
		CMP	R3, #0
		BEQ	bootProc								; CPU 0 continues to booting the kernel

	secondaryProcLoop:								; Secondary CPUs (i.e. CPUs that do not start the kernel) are
		BL		InvalidateDCache
		WFE											; sleeping and waiting to be started by SEV.


		LDR	R0, [PC, #sndProcIdAdr-$-8]
		LDR	R0, [R0, #0]							; R0 := secondaryProcId

		MRC	P15, 0, R1, C0, C0, 5
		AND	R1, R1, #0FH							; R1 := CPU ID

		CMP	R0, R1									; IF R1 # R0: loop again
		BNE	secondaryProcLoop

		LDR	R0, [PC, #sndBootProcAdr-$-8]
		LDR	R1, [R0, #0]							; R1 := secondaryBootProc
		CMP	R1, #0									; IF R1 = 0: loop again
		BEQ	secondaryProcLoop
		BX		R1										; Jump to secondaryBootProc

	sndBootProcAdr:	d32 secondaryBootProc
	sndProcIdAdr:		d32 secondaryProcId

	bootProc:											; CPU0 continues executing the kernel image
		; Save configuration parameters
		LDR	R2, [PC, #CfgBase - 8 - $]
		STR	R0, [R2, #0]
		LDR	R2, [PC, #CfgSize - 8 - $]
		STR	R1, [R2, #0]

		BL		InvalidateDCache						; After invalidating DCache

		; Setup the interrupt vector: copy it from the data section below
		MOV	R0, #0									; R0 := dst
		LDR	R1, [PC, #intVecAdr - $ - 8]			; R1 := src
		MOV	R2, #fiq - RESET + 4					; R2 := LEN(src) in bytes

	copyInts:
		LDR	R4, [R1, #0]
		STR	R4, [R0, #0]
		ADD	R0, R0, #4
		ADD	R1, R1, #4
		SUBS	R2, R2, #4
		BNE	copyInts

		; Start the kernel now
		B		startKernel

	; Interrupt vector data: to install the interrupt vector, we just have to copy
	; from RESET to fiq (included) at address 0.
	RESET: 	LDR	PC, [PC, #reset-$-8]			; RESET
	UNDEF: 	LDR	PC, [PC, #undef-$-8]			; UNDEF
	SWI: 		LDR	PC, [PC, #swi-$-8]			; SWI
	PREF: 		LDR	PC, [PC, #prefetch-$-8]		; Prefetch Abort
	DATA: 		LDR	PC, [PC, #data-$-8]			; Data Abort
	INVALID: 	B		INVALID						; (not assigned)
	IRQ: 		LDR	PC, [PC, #irq-$-8]				; IRQ
	FIQ: 		LDR	PC, [PC, #fiq-$-8]				; FIQ
		; initial interrupt vector setup such that inifinte loop is triggered
	reset: 		d32 Init								; Reset starts the kernel
	undef: 		d32 04H
	swi: 		d32 08H
	prefetch: 	d32 0CH
	data: 		d32 10H
	empty:		d32 0
	irq: 		d32 14H
	fiq: 		d32 1CH

		; Address of the interrupt vector data to copy
	intVecAdr:	d32 RESET

	CfgBase:			d32 configBase
	CfgSize:			d32 configSize


	startKernel:
	END Init;

	PROCEDURE {NOPAF} InvalidateDCache *;
	CODE
		invalidate_dcache:
			mrc	p15, 1, r0, c0, c0, 1		; read CLIDR
			ands	r3, r0, #7000000H
			mov	r3, r3, lsr #23			; cache level value (naturally aligned)
			beq	finished
			mov	r10, #0					; start with level 0
		loop1:
			add	r2, r10, r10, lsr #1		; work out 3xcachelevel
			mov	r1, r0, lsr r2			; bottom 3 bits are the Cache type for this level
			and	r1, r1, #7				; get those 3 bits alone
			cmp	r1, #2
			blt		skip					; no cache or only instruction cache at this level
			mcr	p15, 2, r10, c0, c0, 0	; write the Cache Size selection register
			isb								 ; isb to sync the change to the CacheSizeID reg
			mrc	p15, 1, r1, c0, c0, 0		; reads current Cache Size ID register
			and	r2, r1, #7				; extract the line length field
			add	r2, r2, #4				; add 4 for the line length offset (log2 16 bytes)
			ldr	r4, [pc, #H0x3ff-$-8]
			ands	r4, r4, r1, lsr #3		; r4 is the max number on the way size (right aligned)
			clz	r5, r4						; r5 is the bit position of the way size increment
			ldr	r7, [pc, #H0x7fff-$-8]
			ands	r7, r7, r1, lsr #13		; r7 is the max number of the index size (right aligned)
		loop2:
			mov	r9, r4					; r9 working copy of the max way size (right aligned)
		loop3:
			orr		r11, r10, r9, lsl r5		; factor in the way number and cache number into r11
			orr		r11, r11, r7, lsl r2		; factor in the index number
			mcr	p15, 0, r11, c7, c14, 2	; clean & invalidate by set/way
			subs	r9, r9, #1				; decrement the way number
			bge		loop3
			subs	r7, r7, #1				; decrement the index
			bge		loop2
		skip:
			add	r10, r10, #2				; increment the cache number
			cmp	r3, r10
			bgt		loop1

		finished:
			mov	r10, #0					; swith back to cache level 0
			mcr	p15, 2, r10, c0, c0, 0	; select current cache level in cssr
			dsb								; dsb
			isb								; isb

			bx	lr

		H0x3ff:		d32 03FFH
		H0x7fff:	d32 07FFFH
	END InvalidateDCache;
END Initializer.

FoxARMInstructionSet.Disassemble A2.Bin -a=100120H ~
