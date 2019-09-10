MODULE Machine;

IMPORT CPU, Environment, Trace, Mutexes, Processors;

CONST
	Version = "A2 Cooperative Revision 5791";

	MaxCPU* = Processors.Maximum;	(* dummy definition to make GC for both Win32 and I386 work *)

	#IF UNIX THEN
		#IF AMD64 THEN
			DefaultObjectFileExtension* = ".GofUc";
		#ELSE
			DefaultObjectFileExtension* = ".GofU";
		#END
	#ELSE
		DefaultObjectFileExtension* = ".Obw";
	#END

	(** bits in features variable *)
	MTTR* = 12;  MMX* = 23;

	debug* = FALSE;   (** display more debug output during booting *)

CONST
(** standard lock levels (in order) *)  (* also refer to Traps.Show *)
	TraceOutput* = 0;   (* Trace output *)
	Memory* = 1;   (* Virtual memory management, stack and page allocation *)
	Heaps* = 2;   (* Storage allocation and Garbage collection *)
	Interrupts* = 3;   (* Interrupt handling. *)
	Modules* = 4;   (* Module list *)
	Objects* = 5;   (* Ready queue *)
	KernelLog* = 7;   (* Atomic output *)
	GC* = 8;
	X11* = 9;   (* XWindows I/O *)
	MaxLocks = 10;   (* { <= 32 } *)

	(* error codes *)
	Ok* = 0;
	NilAdr* = -1;	(* nil value for addresses (not same as pointer NIL value) *)

	IRQ0* = CPU.IRQ0;
	MaxIRQ* = CPU.IRQ15;

TYPE
	Vendor* = ARRAY 13 OF CHAR;
	IDMap* = ARRAY 16 OF SIGNED8;

	Range* = RECORD
		adr*: ADDRESS; size*: SIZE;
	END;

	MemoryBlock* = POINTER TO MemoryBlockDesc;
	MemoryBlockDesc* = RECORD
		next- {UNTRACED}: MemoryBlock;
		startAdr-: ADDRESS; 		(* sort key in linked list of memory blocks *)
		size-: SIZE;
		beginBlockAdr-, endBlockAdr-: ADDRESS
	END;

	(* dummy definition to make GC work for both I386 and Win32 - copied from BIOS.I386.Machine.Mod, but not really used *)
	Stack* = RECORD	(** values are read-only *)
			low: ADDRESS;		(* lowest virtual address that may be allocated for stack *)
		adr*: ADDRESS;		(* lowest address on allocated stack *)	(* exported for Objects only *)
		high*: ADDRESS;	(* next virtual address after stack *)	(* exported for Objects only *)
	END;

	Address32* = SIGNED32;

VAR



	MMXSupport*: BOOLEAN;
	SSESupport*: BOOLEAN;
	SSE2Support*: BOOLEAN;
	SSE3Support-: BOOLEAN; (* PH 04/11*)
	SSSE3Support-: BOOLEAN;
	SSE41Support-: BOOLEAN;
	SSE42Support-: BOOLEAN;
	SSE5Support-: BOOLEAN;
	AVXSupport-: BOOLEAN;

	version*: ARRAY 64 OF CHAR;   (** Aos version *)
	features*,features2*: SET;   (** processor features *)
	fcr*: SET;   (** default floating-point control register value (default rounding mode is towards -infinity, for ENTIER) *)
	mhz*: SIGNED64;   (** clock rate of GetTimer() in MHz, or 0 if not known *)
	boottime-: SIGNED64; (** in timer units *)

VAR
	lock-: ARRAY MaxLocks OF CHAR;  (* not implemented as SET because of shared access *)
	mutex: ARRAY MaxLocks OF Mutexes.Mutex;

	memBlockHead-{UNTRACED}, memBlockTail-{UNTRACED}: MemoryBlock; (* head and tail of sorted list of memory blocks *)


	(** Convert a string to an integer.  Parameter i specifies where in the string scanning should begin (usually 0 in the first call).  Scanning stops at the first non-valid character, and i returns the updated position.  Parameter s is the string to be scanned.  The value is returned as result, or 0 if not valid.  Syntax: number = ["-"] digit {digit} ["H" | "h"] .  digit = "0" | ... "9" | "A" .. "F" | "a" .. "f" .  If the number contains any hexdecimal letter, or if it ends in "H" or "h", it is interpreted as hexadecimal. *)

	PROCEDURE StrToInt*( VAR i: SIZE;  CONST s: ARRAY OF CHAR ): SIGNED32;
	VAR vd, vh, sgn, d: SIGNED32;  hex: BOOLEAN;
	BEGIN
		vd := 0;  vh := 0;  hex := FALSE;
		IF s[i] = "-" THEN sgn := -1;  INC( i ) ELSE sgn := 1 END;
		LOOP
			IF (s[i] >= "0") & (s[i] <= "9") THEN d := ORD( s[i] ) - ORD( "0" )
			ELSIF (CAP( s[i] ) >= "A") & (CAP( s[i] ) <= "F") THEN d := ORD( CAP( s[i] ) ) - ORD( "A" ) + 10;  hex := TRUE
			ELSE EXIT
			END;
			vd := 10 * vd + d;  vh := 16 * vh + d;  INC( i )
		END;
		IF CAP( s[i] ) = "H" THEN hex := TRUE;  INC( i ) END;   (* optional H *)
		IF hex THEN vd := vh END;
		RETURN sgn * vd
	END StrToInt;
	(** -- Atomic operations -- *)

(** This procedure should be called in all spin loops as a hint to the processor (e.g. Pentium 4). *)

PROCEDURE -SpinHint*;
CODE
#IF I386 THEN
	PAUSE
#ELSIF AMD64 THEN
	PAUSE
#ELSE
	unimplemented
#END
END SpinHint;

(* Return current instruction pointer *)
PROCEDURE CurrentPC* (): ADDRESS;
CODE
#IF I386 THEN
	MOV EAX, [EBP+4]
#ELSIF AMD64 THEN
	MOV RAX, [RBP + 8]
#ELSE
	unimplemented
#END
END CurrentPC;

PROCEDURE MapPhysical*(physAdr: ADDRESS; size: SIZE; VAR virtAdr: ADDRESS);
BEGIN
	virtAdr := physAdr;
END MapPhysical;

(** Unmap an area previously mapped with MapPhysical. *)
PROCEDURE UnmapPhysical*(virtAdr: ADDRESS; size: SIZE);
END UnmapPhysical;

(** Translate a virtual address range to num ranges of physical address. num returns 0 on error. *)
PROCEDURE TranslateVirtual*(virtAdr: ADDRESS; size: SIZE;  VAR num: SIGNED32; VAR physAdr: ARRAY OF Range);
CONST PS = 4096;
VAR ofs, phys1: ADDRESS; size1: SIZE;
BEGIN
	num := 0;
	LOOP
		IF size = 0 THEN EXIT END;
		IF num = LEN(physAdr) THEN num := 0; EXIT END;	(* index check *)
		ofs := virtAdr MOD PS;	(* offset in page *)
		size1 := PS - ofs;	(* distance to next page boundary *)
		IF size1 > size THEN size1 := size END;
		phys1 := virtAdr - ofs;
		physAdr[num].adr := phys1 - phys1 MOD PS + ofs;
		physAdr[num].size := size1; INC(num);
		INC(virtAdr, size1); DEC(size, size1)
	END;
	IF num = 0 THEN physAdr[0].adr := NilAdr; physAdr[0].size := 0 END;
END TranslateVirtual;

(** Get parameter values from Init string. If n = 0, return val = ASH(bx, 16) + ax, and if n = 1, return val = ASH(dx, 16) + cx, where ax, bx, cx, dx are the register values after the OBL boot loader or noboot.exe have executed the 16-bit x86 code in the Init string. *)
PROCEDURE GetInit* (n: SIGNED32; VAR val: SIGNED32);
BEGIN Environment.GetInit (n, val);
END GetInit;

(** Fill "size" bytes at "destAdr" with "filler".  "size" must be multiple of 4. *)

	PROCEDURE Fill32*(destAdr: ADDRESS; size: SIZE; filler: SIGNED32);
	CODE
	#IF I386 THEN
		#IF COOP THEN
			PUSH	ECX
		#END
		MOV	EDI, [EBP+destAdr]
		MOV	ECX, [EBP+size]
		MOV	EAX, [EBP+filler]
		TEST	ECX, 3
		JZ	ok
		PUSH	8	;  ASSERT failure
		INT	3
	ok:	SHR	ECX, 2
		CLD
		REP	STOSD
		#IF COOP THEN
			POP	ECX
		#END
	#ELSIF AMD64 THEN
		MOV	RDI, [RBP + destAdr]
		MOV	RCX, [RBP + size]
		MOV	EAX, [RBP + filler]
		TEST	RCX, 3
		JZ	ok
		PUSH	8	; ASSERT failure
		INT	3
	ok:	SHR	RCX, 2
		CLD
		REP	STOSD
	#ELSE
		unimplemented
	#END
	END Fill32;

(** -- Processor initialization -- *)

	PROCEDURE -SetFCR( s: SET );
	CODE
	#IF I386 THEN
		FLDCW	[ESP]	;  parameter s
		POP	EAX
	#ELSIF AMD64 THEN
		FLDCW	WORD [RSP]	; parameter s
		POP	RAX
	#ELSE
		unimplemented
	#END
	END SetFCR;

	PROCEDURE -FCR( ): SET;
	CODE
	#IF I386 THEN
		PUSH	0
		FNSTCW	[ESP]
		FWAIT
		POP	EAX
	#ELSIF AMD64 THEN
		PUSH	0
		FNSTCW	WORD [RSP]
		FWAIT
		POP	RAX
	#ELSE
		unimplemented
	#END
	END FCR;

	PROCEDURE -InitFPU;
	CODE
	#IF I386 THEN
		FNINIT
	#ELSIF AMD64 THEN
		FNINIT
	#ELSE
		unimplemented
	#END
	END InitFPU;

(** CPU identification. *)

	PROCEDURE CPUID*( VAR vendor: Vendor;  VAR version: SIGNED32;  VAR features1,features2: SET );
	CODE
	#IF I386 THEN
		#IF COOP THEN
			PUSH	ECX
		#END
		MOV	EAX, 0
		CPUID
		CMP	EAX, 0
		JNE	ok
		MOV	ESI, [EBP+vendor]
		MOV	[ESI], AL	;  AL = 0
		MOV	ESI, [EBP+version]
		MOV	[ESI], EAX	;  EAX = 0
		MOV	ESI, [EBP+features1]
		MOV	[ESI], EAX
		MOV	ESI, [EBP+features2]
		MOV	[ESI], EAX
		JMP	end
		ok:
		MOV	ESI, [EBP+vendor]
		MOV	[ESI], EBX
		MOV	[ESI+4], EDX
		MOV	[ESI+8], ECX
		MOV	BYTE [ESI+12], 0
		MOV	EAX, 1
		CPUID
		MOV	ESI, [EBP+version]
		MOV	[ESI], EAX
		MOV	ESI, [EBP+features1]
		MOV	[ESI], EDX
		MOV	ESI, [EBP+features2]
		MOV	[ESI], ECX
		end:
		#IF COOP THEN
			POP	ECX
		#END
	#ELSIF AMD64 THEN
		#IF COOP THEN
			PUSH	RBX
		#END
		MOV	EAX, 0
		CPUID
		CMP	EAX, 0
		JNE	ok
		MOV	RSI, [RBP+vendor]
		MOV	[RSI], AL	;  AL = 0
		MOV	RSI, [RBP+version]
		MOV	[RSI], EAX	;  EAX = 0
		MOV	RSI, [RBP+features1]
		MOV	[RSI], EAX
		MOV	RSI, [RBP+features2]
		MOV	[RSI], EAX
		JMP	end
		ok:
		MOV	RSI, [RBP+vendor]
		MOV	[RSI], EBX
		MOV	[RSI+4], EDX
		MOV	[RSI+8], ECX
		MOV	BYTE [RSI+12], 0
		MOV	EAX, 1
		CPUID
		MOV	RSI, [RBP+version]
		MOV	[RSI], EAX
		MOV	RSI, [RBP+features1]
		MOV	[RSI], EDX
		MOV	RSI, [RBP+features2]
		MOV	[RSI], RCX
		end:
		#IF COOP THEN
			POP	RBX
		#END
	#ELSE
		unimplemented
	#END
	END CPUID;

	PROCEDURE GetConfig* ( CONST name: ARRAY OF CHAR;  VAR val: ARRAY OF CHAR );
	BEGIN Environment.GetString (name, val);
	END GetConfig;

	PROCEDURE Shutdown*( restart: BOOLEAN );
	BEGIN
		IF restart THEN Environment.Reboot ELSE Environment.Shutdown END;
	END Shutdown;

PROCEDURE Cli*;
BEGIN HALT (1234);
END Cli;

PROCEDURE Sti*;
BEGIN HALT (1234);
END Sti;

(* Dan: from new Machine *)
PROCEDURE -GetTimer*(): SIGNED64;
CODE
#IF I386 THEN
	RDTSC	; set EDX:EAX
#ELSIF AMD64 THEN
	XOR RAX, RAX
	RDTSC	; set EDX:EAX
	SHL RDX, 32
	OR RAX, RDX
#ELSE
	unimplemented
#END
END GetTimer;

(** Disable interrupts and return old interrupt state. *)
PROCEDURE -DisableInterrupts* (): SET;
CODE
#IF I386 THEN
	PUSHFD
	CLI
	POP EAX
#ELSIF AMD64 THEN
	PUSHFQ
	CLI
	POP RAX
#ELSE
	unimplemented
#END
END DisableInterrupts;

(** Restore interrupt state. Parameter s must be return value of earlier DisableInterrupts call on same processor. *)
PROCEDURE -RestoreInterrupts* (s: SET);
CODE
#IF I386 THEN
	POPFD
#ELSIF AMD64 THEN
	POPFQ
#ELSE
	unimplemented
#END
END RestoreInterrupts;

PROCEDURE ID*(): SIZE;
BEGIN
	RETURN Processors.GetCurrentIndex ();
END ID;

(* setup MMX, SSE and SSE2..SSE5 and AVX extension *)

PROCEDURE -InitSSE;
CODE
#IF I386 THEN
	MOV	EAX, CR4
	OR	EAX, 00000200H		; set bit 9 (OSFXSR)
	AND	EAX, 0FFFFFBFFH	; delete bit 10 (OSXMMEXCPT)
	MOV	CR4, EAX
#ELSIF AMD64 THEN
	MOV	EAX, CR4
	OR	EAX, 00000200H		; set bit 9 (OSFXSR)
	AND	EAX, 0FFFFFBFFH	; delete bit 10 (OSXMMEXCPT)
	MOV	CR4, EAX
#ELSE
	unimplemented
#END
END InitSSE;

PROCEDURE InitBootProcessor-;
CONST
	MMXFlag=23;(*IN features from EBX*)
	FXSRFlag = 24;
	SSEFlag = 25;
	SSE2Flag = 26;
	SSE3Flag = 0; (*IN features2 from ECX*) (*PH 04/11*)
	SSSE3Flag =9;
	SSE41Flag =19;
	SSE42Flag =20;
	SSE5Flag = 11;
	AVXFlag = 28;
VAR vendor: Vendor; ver: SIGNED32;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	CPUID(vendor, ver, features,features2);
	MMXSupport := MMXFlag IN features;
	SSESupport := SSEFlag IN features;
	SSE2Support := SSESupport & (SSE2Flag IN features);
	SSE3Support := SSE2Support & (SSE3Flag IN features2);
	SSSE3Support := SSE3Support & (SSSE3Flag IN features2); (* PH 04/11*)
	SSE41Support := SSE3Support & (SSE41Flag IN features2);
	SSE42Support := SSE3Support & (SSE42Flag IN features2);
	SSE5Support := SSE3Support & (SSE5Flag IN features2);
	AVXSupport := SSE3Support & (AVXFlag IN features2);
	fcr := (FCR() - {0,2,3,10,11}) + {0..5,8,9};	(* default FCR RC=00B *)
	InitApplicationProcessor;
END InitBootProcessor;

PROCEDURE InitApplicationProcessor-;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	InitFPU;  SetFCR( fcr );
	IF Environment.IsNative & SSESupport THEN
		InitSSE();
	END;
END InitApplicationProcessor;

(** Acquire a spin-lock. *)
	PROCEDURE Acquire*( level: SIGNED32 );   (* non reentrant lock  (non reentrance "ensured" by ASSERT statement ), CriticalSections are reentrant *)
	BEGIN
		Mutexes.Acquire (mutex[level]);
	END Acquire;

(** Release a spin-lock. *)
	PROCEDURE Release*( level: SIGNED32 );   (* release lock *)
	BEGIN
		Mutexes.Release (mutex[level]);
	END Release;

(* returns if an address is a currently allocated heap address *)
PROCEDURE ValidHeapAddress*(p: ADDRESS): BOOLEAN;
BEGIN
	RETURN p # NIL;
END ValidHeapAddress;

PROCEDURE GetFreeK* (VAR total, lowFree, highFree: SIZE);
BEGIN
	total := 0; lowFree := 0; highFree := 0;
END GetFreeK;

PROCEDURE PhysicalAdr*(adr: ADDRESS; size: SIZE): ADDRESS;
BEGIN RETURN adr;
END PhysicalAdr;

	(** -- Atomic operations -- *)

(** Atomic INC(x). *)

	PROCEDURE -AtomicInc*( VAR x: SIGNED32 );
	CODE
	#IF I386 THEN
		POP	EAX
		LOCK
		INC	DWORD [EAX]
	#ELSIF AMD64 THEN
		POP	RAX
		LOCK
		INC	DWORD [RAX]
	#ELSE
		unimplemented
	#END
	END AtomicInc;

(** Atomic DEC(x). *)

	PROCEDURE -AtomicDec*( VAR x: SIGNED32 );
	CODE
	#IF I386 THEN
		POP	EAX
		LOCK
		DEC	DWORD [EAX]
	#ELSIF AMD64 THEN
		POP	RAX
		LOCK
		DEC	DWORD [RAX]
	#ELSE
		unimplemented
	#END
	END AtomicDec;

(** Atomic INC(x, y). *)

	PROCEDURE -AtomicAdd*( VAR x: SIGNED32;  y: SIGNED32 );
	CODE
	#IF I386 THEN
		POP	EBX
		POP	EAX
		LOCK
		ADD	DWORD [EAX], EBX
	#ELSIF AMD64 THEN
		POP	RCX
		POP	RAX
		LOCK
		ADD	DWORD [RAX], ECX
	#ELSE
		unimplemented
	#END
	END AtomicAdd;

(** Atomic test-and-set.  Set x = TRUE and return old value of x. *)

	PROCEDURE -AtomicTestSet*( VAR x: BOOLEAN ): BOOLEAN;
	CODE
	#IF I386 THEN
		POP	EBX
		MOV	AL, 1
		XCHG	[EBX], AL
	#ELSIF AMD64 THEN
		POP	RCX
		MOV	AL, 1
		XCHG	[RCX], AL
	#ELSE
		unimplemented
	#END
	END AtomicTestSet;

(* Atomic compare-and-swap. Set x = new if x = old and return old value of x *)

	PROCEDURE -AtomicCAS* (VAR x: SIGNED32; old, new: SIGNED32): SIGNED32;
	CODE
	#IF I386 THEN
		POP EBX		; new
		POP EAX		; old
		POP EDX		; address of x
		LOCK CMPXCHG [EDX], EBX	; atomicly compare x with old and set it to new if equal
	#ELSIF AMD64 THEN
		POP RCX		; new
		POP RAX		; old
		POP RDX		; address of x
		LOCK CMPXCHG [RDX], ECX	; atomicly compare x with old and set it to new if equal
	#ELSE
		unimplemented
	#END
	END AtomicCAS;

(* function returning the number of processors that are available to Aos *)
PROCEDURE NumberOfProcessors*( ): SIZE;
BEGIN
	RETURN Processors.count;
END NumberOfProcessors;

(* function for changing byte order *)
PROCEDURE ChangeByteOrder* (n: SIGNED32): SIGNED32;
CODE
#IF I386 THEN
	MOV EAX, [EBP+n]				; load n in eax
	BSWAP EAX						; swap byte order
#ELSIF AMD64 THEN
	MOV EAX, [RBP+n]				; load n in eax
	BSWAP EAX						; swap byte order
#ELSE
	unimplemented
#END
END ChangeByteOrder;

#IF I386 THEN

	PROCEDURE -GetEAX*(): SIGNED32;
	CODE
	END GetEAX;

	PROCEDURE -GetECX*(): SIGNED32;
	CODE MOV EAX,ECX
	END GetECX;

	PROCEDURE -SetEAX*(n: SIGNED32);
	CODE POP EAX
	END SetEAX;

	PROCEDURE -SetEBX*(n: SIGNED32);
	CODE POP EBX
	END SetEBX;

	PROCEDURE -SetECX*(n: SIGNED32);
	CODE POP ECX
	END SetECX;

	PROCEDURE -SetEDX*(n: SIGNED32);
	CODE POP EDX
	END SetEDX;

	PROCEDURE -SetESI*(n: SIGNED32);
	CODE POP ESI
	END SetESI;

	PROCEDURE -SetEDI*(n: SIGNED32);
	CODE POP EDI
	END SetEDI;

	PROCEDURE Portin8*(port: SIGNED32; VAR val: CHAR);
	CODE
		MOV EDX, [EBP+port]
		IN AL, DX
		MOV EBX, [EBP+val]
		MOV [EBX], AL
	END Portin8;

	PROCEDURE Portin16*(port: SIGNED32; VAR val: SIGNED16);
	CODE
		MOV EDX, [EBP+port]
		IN AX, DX
		MOV EBX, [EBP+val]
		MOV [EBX], AX
	END Portin16;

	PROCEDURE Portin32*(port: SIGNED32; VAR val: SIGNED32);
	CODE
		MOV EDX, [EBP+port]
		IN EAX, DX
		MOV EBX, [EBP+val]
		MOV [EBX], EAX
	END Portin32;

	PROCEDURE Portout8*(port: SIGNED32; val: CHAR);
	CODE
		MOV AL, [EBP+val]
		MOV EDX, [EBP+port]
		OUT DX, AL
	END Portout8;

	PROCEDURE Portout16*(port: SIGNED32; val: SIGNED16);
	CODE
		MOV AX, [EBP+val]
		MOV EDX, [EBP+port]
		OUT DX, AX
	END Portout16;

	PROCEDURE Portout32*(port: SIGNED32; val: SIGNED32);
	CODE
		MOV EAX, [EBP+val]
		MOV EDX, [EBP+port]
		OUT DX, EAX
	END Portout32;

#ELSIF AMD64 THEN

	PROCEDURE -GetRAX*(): SIGNED64;
	CODE
	END GetRAX;

	PROCEDURE -GetRCX*(): SIGNED64;
	CODE MOV RAX, RCX
	END GetRCX;

	PROCEDURE -SetRAX*(n: SIGNED64);
	CODE POP RAX
	END SetRAX;

	PROCEDURE -SetRBX*(n: SIGNED64);
	CODE POP RBX
	END SetRBX;

	PROCEDURE -SetRCX*(n: SIGNED64);
	CODE POP RCX
	END SetRCX;

	PROCEDURE -SetRDX*(n: SIGNED64);
	CODE POP RDX
	END SetRDX;

	PROCEDURE -SetRSI*(n: SIGNED64);
	CODE POP RSI
	END SetRSI;

	PROCEDURE -SetRDI*(n: SIGNED64);
	CODE POP RDI
	END SetRDI;

	PROCEDURE Portin8*(port: SIGNED32; VAR val: CHAR);
	CODE
		MOV EDX, [RBP+port]
		IN AL, DX
		MOV RCX, [RBP+val]
		MOV [RCX], AL
	END Portin8;

	PROCEDURE Portin16*(port: SIGNED32; VAR val: SIGNED16);
	CODE
		MOV EDX, [RBP+port]
		IN AX, DX
		MOV RCX, [RBP+val]
		MOV [RCX], AX
	END Portin16;

	PROCEDURE Portin32*(port: SIGNED32; VAR val: SIGNED32);
	CODE
		MOV EDX, [RBP+port]
		IN EAX, DX
		MOV RCX, [RBP+val]
		MOV [RCX], EAX
	END Portin32;

	PROCEDURE Portout8*(port: SIGNED32; val: CHAR);
	CODE
		MOV AL, [RBP+val]
		MOV EDX, [RBP+port]
		OUT DX, AL
	END Portout8;

	PROCEDURE Portout16*(port: SIGNED32; val: SIGNED16);
	CODE
		MOV AX, [RBP+val]
		MOV EDX, [RBP+port]
		OUT DX, AX
	END Portout16;

	PROCEDURE Portout32*(port: SIGNED32; val: SIGNED32);
	CODE
		MOV EAX, [RBP+val]
		MOV EDX, [RBP+port]
		OUT DX, EAX
	END Portout32;

#END

(* Delay for IO *)
PROCEDURE -Wait*;
CODE
#IF I386 THEN
	JMP 0
	JMP 0
	JMP 0
#ELSIF AMD64 THEN
	JMP 0
	JMP 0
	JMP 0
#ELSE
	unimplemented
#END
END Wait;

(** Read a byte from the non-volatile setup memory. *)
PROCEDURE GetNVByte* (ofs: SIGNED32): CHAR;
VAR c: CHAR;
BEGIN
	Portout8 (70H, CHR(ofs)); Wait; Portin8(71H, c);
	RETURN c
END GetNVByte;

(** Write a byte to the non-volatile setup memory. *)
PROCEDURE PutNVByte* (ofs: SIGNED32; val: CHAR);
BEGIN
	Portout8 (70H, CHR(ofs)); Wait; Portout8 (71H, val)
END PutNVByte;

PROCEDURE InvalidateDCacheRange*(a: ADDRESS; s: SIZE);
BEGIN

END InvalidateDCacheRange;

PROCEDURE FlushDCacheRange*(a: ADDRESS; s: SIZE);
BEGIN

END FlushDCacheRange;


BEGIN
	Trace.String("Machine: "); Trace.Blue; Trace.StringLn (Version); Trace.Default;
	boottime:=GetTimer();
	COPY( Version, version );
END Machine.
