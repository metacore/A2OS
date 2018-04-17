MODULE Machine;	(** AUTHOR "pjm, G.F."; PURPOSE "Bootstrapping, configuration and machine interface"; *)

IMPORT S := SYSTEM, Trace, Unix, Glue;

CONST
	DefaultConfig = "Color 0  StackSize 128";
	
	Version = "A2 Generic, ";

	DefaultObjectFileExtension* = ".GofUu";
	
	Second* = 1000; (* frequency of ticks increments in Hz *)

	(** bits in features variable *)
	MTTR* = 12;  MMX* = 23; 
	
	AddrSize = SIZEOF( ADDRESS );
	SizeSize = SIZEOF( SIZE );
	
	AddressSize = SIZEOF(ADDRESS);
	BlockHeaderSize = 2 * AddressSize;
	RecordDescSize = 4 * AddressSize;  (* needs to be adapted in case Heaps.RecordBlockDesc is changed *)
	StaticBlockSize = 8 * AddressSize;	(* static heap block size *)

	BlockSize = StaticBlockSize;
	MemBlockSize* = 64*1024*1024;
	
	TraceOutput* = 0;	(* Trace output *)
	Memory* = 1;		(*!  Virtual memory management, stack and page allocation,  not used in UnixAos *)
	Heaps* = 2;   		(* Storage allocation and Garbage collection *)
	Interrupts* = 3;		(*!  Interrupt handling,  not used in UnixAos *)
	Modules* = 4;		(* Module list *)
	Objects* = 5;		(*!  Ready queue,  not used in UnixAos *)
	Processors* = 6;	(*!  Interprocessor interrupts,  not used in UnixAos *)
	KernelLog* = 7;		(* Atomic output *)
	X11* = 8;				(* XWindows I/O *)
	MaxLocks* = 9;   (* { <= 32 } *)
	
	MaxCPU* = 4;
	IsCooperative* = FALSE;

	TraceMemBlocks = FALSE;

TYPE	
	Vendor* = ARRAY 13 OF CHAR;	

	MemoryBlock* = POINTER TO MemoryBlockDesc;
	MemoryBlockDesc* = RECORD
		next- {UNTRACED}: MemoryBlock;
		startAdr-: ADDRESS; 		(* sort key in linked list of memory blocks *)
		size-: SIZE; 					
		beginBlockAdr-, endBlockAdr-: ADDRESS
	END;
	
	(** processor state *)
	State* = RECORD	
		PC*, BP*, SP*: ADDRESS
	END;
	
	
VAR
	mtx	: ARRAY MaxLocks OF Unix.Mutex_t;
	
	version-: ARRAY 64 OF CHAR;	(** Aos version *)
	
	features-, features2 : SET;
	MMXSupport-	: BOOLEAN;
	SSESupport-	: BOOLEAN;
	SSE2Support-	: BOOLEAN;
	SSE3Support-	: BOOLEAN;
	SSSE3Support-	: BOOLEAN;
	SSE41Support-	: BOOLEAN;
	SSE42Support-	: BOOLEAN;
	SSE5Support-	: BOOLEAN;
	AVXSupport-		: BOOLEAN;
		
	ticks-: LONGINT;	(** timer ticks. Use Kernel.GetTicks() to read, don't write *)
	
	prioLow-, prioHigh-: LONGINT;	(* permitted thread priorities *)
	
	fcr-: SET;	(** default floating-point control register value (default rounding mode is towards -infinity, for ENTIER) *)
	mhz-: HUGEINT;	(** clock rate of GetTimer in MHz, or 0 if not known *)
	
	gcThreshold-: SIZE;
	memBlockHead-{UNTRACED}, memBlockTail-{UNTRACED}: MemoryBlock; (* head and tail of sorted list of memory blocks *)
	
	config: ARRAY 2048 OF CHAR;	(* config strings *)
	
	logname: ARRAY 32 OF CHAR;
	logfile: LONGINT;
	traceHeap: BOOLEAN;

	timer0	: HUGEINT;

	(** Return current processor ID (0 to MaxNum-1). *)
	PROCEDURE  ID* (): LONGINT;
	BEGIN
		RETURN 0
	END ID;

	(**
	 * Flush Data Cache for the specified virtual address range. If len is negative, flushes the whole cache.
	 * This is used on some architecture to interact with DMA hardware (e.g. Ethernet and USB. It can be
	 * left empty on Intel architecture.
	 *)
	PROCEDURE FlushDCacheRange * (adr: ADDRESS; len: LONGINT);
	END FlushDCacheRange;

	(**
	 * Invalidate Data Cache for the specified virtual address range. If len is negative, flushes the whole cache.
	 * This is used on some architecture to interact with DMA hardware (e.g. Ethernet and USB. It can be
	 * left empty on Intel architecture.
	 *)
	PROCEDURE InvalidateDCacheRange * (adr: ADDRESS; len: LONGINT);
	END InvalidateDCacheRange;

	(**
	 * Invalidate Instruction Cache for the specified virtual address range. If len is negative, flushes the whole cache.
	 * This is used on some architecture to interact with DMA hardware (e.g. Ethernet and USB. It can be
	 * left empty on Intel architecture.
	 *)
	PROCEDURE InvalidateICacheRange * (adr: ADDRESS; len: LONGINT);
	END InvalidateICacheRange;
	
	(* insert given memory block in sorted list of memory blocks, sort key is startAdr field - called during GC *)
	PROCEDURE InsertMemoryBlock(memBlock: MemoryBlock);
	VAR cur {UNTRACED}, prev {UNTRACED}: MemoryBlock;
	BEGIN
		cur := memBlockHead;
		prev := NIL;
		WHILE (cur # NIL) & (cur.startAdr < memBlock.startAdr) DO
			prev := cur;
			cur := cur.next
		END;
		IF prev = NIL THEN (* insert at head of list *)
			memBlock.next := memBlockHead;
			memBlockHead := memBlock
		ELSE (* insert in middle or at end of list *)
			prev.next := memBlock;
			memBlock.next := cur;
			IF cur = NIL THEN
				memBlockTail := memBlock
			END
		END
	END InsertMemoryBlock;

		
	(* Free unused memory block - called during GC *)
	PROCEDURE FreeMemBlock*(memBlock: MemoryBlock);
	VAR cur {UNTRACED}, prev {UNTRACED}: MemoryBlock;
	BEGIN
		cur := memBlockHead;
		prev := NIL;
		WHILE (cur # NIL) & (cur # memBlock) DO
			prev := cur;
			cur := cur.next
		END;
		IF cur = memBlock THEN 
			IF traceHeap THEN  
				Trace.String( "Release memory block " );  Trace.Hex( memBlock.startAdr, -8 );  Trace.Ln
			END;
			IF prev = NIL THEN
				memBlockHead := cur.next
			ELSE
				prev.next := cur.next;
				IF cur.next = NIL THEN
					memBlockTail := prev
				END
			END;
			Unix.free( memBlock.startAdr )
		ELSE
			HALT(535)	(* error in memory block management *)
		END;
	END FreeMemBlock;

	

	(* expand heap by allocating a new memory block *)
	PROCEDURE ExpandHeap*( dummy: LONGINT; size: SIZE; VAR memoryBlock: MemoryBlock; VAR beginBlockAdr, endBlockAdr: ADDRESS );
	VAR mBlock: MemoryBlock;  alloc, s: SIZE;  a, adr: ADDRESS; 
	BEGIN 
		IF size < (MemBlockSize - (2*BlockSize))  THEN  alloc := MemBlockSize  
		ELSE  alloc := size + (2*BlockSize);
		END;  
		INC( alloc, (-alloc) MOD Unix.PageSize );
		
		IF Unix.posix_memalign( adr, Unix.PageSize, alloc ) # 0 THEN
			Unix.Perror( "Machine.ExpandHeap: posix_memalign" );
			beginBlockAdr := 0;
			endBlockAdr := 0
		ELSE
			IF Unix.mprotect( adr, alloc, 7 (* READ WRITE EXEC *) ) # 0 THEN
				Unix.Perror( "Machine.ExpandHeap: mprotect" )
			END;
			
			mBlock := S.VAL( MemoryBlock, adr );  
			mBlock.next := NIL;  
			mBlock.startAdr := adr;
			mBlock.size := alloc;  
			mBlock.beginBlockAdr := adr + BlockSize - AddrSize;  
			
			ASSERT( (mBlock.beginBlockAdr + AddrSize) MOD BlockSize = 0 );  

			s := adr + alloc - mBlock.beginBlockAdr - BlockSize; 
			DEC( s, s MOD BlockSize );  
			ASSERT( s >= size );  
			mBlock.endBlockAdr := mBlock.beginBlockAdr + s; 
			
			InsertMemoryBlock( mBlock );
			IF traceHeap THEN TraceHeap( mBlock )  END;
			
			a := mBlock.beginBlockAdr;
			S.PUT( a, a + AddrSize );	(* tag *)
			S.PUT( a + AddrSize, s - AddrSize );  (* size *)
			S.PUT( a + AddrSize + SizeSize, S.VAL( ADDRESS, 0 ) ); (* next *)
			
			beginBlockAdr := mBlock.beginBlockAdr;
			endBlockAdr := mBlock.endBlockAdr;
			memoryBlock := mBlock;
		END  
	END ExpandHeap;
		
	(* Set memory block end address *)
	PROCEDURE SetMemoryBlockEndAddress*(memBlock: MemoryBlock; endBlockAdr: ADDRESS);
	BEGIN
		ASSERT(endBlockAdr >= memBlock.beginBlockAdr);
		memBlock.endBlockAdr := endBlockAdr
	END SetMemoryBlockEndAddress;

	PROCEDURE TraceHeap( new: MemoryBlock );
	VAR cur{UNTRACED}: MemoryBlock;
	BEGIN
		Trace.Ln;
		Trace.String( "Heap expanded" );  Trace.Ln;
		Trace.String("Static Heap: "); Trace.Hex(Glue.baseAdr, -8); Trace.String(" - "); Trace.Hex(Glue.endAdr, -8); 
		Trace.Ln;
		cur := memBlockHead;
		WHILE cur # NIL DO
			Trace.Hex( cur.startAdr, -8 );  Trace.String( "   " );  Trace.Hex( cur.startAdr + cur.size, -8 );
			IF cur = new THEN  Trace.String( "  (new)" )  END;
			Trace.Ln;
			cur := cur.next
		END
	END TraceHeap;

	(** Get first memory block and first free address, the first free address is identical to memBlockHead.endBlockAdr *)
	PROCEDURE GetStaticHeap*(VAR beginBlockAdr, endBlockAdr, freeBlockAdr: ADDRESS);
	BEGIN
		InitHeap(memBlockHead,beginBlockAdr, endBlockAdr);
		memBlockTail := memBlockHead;

		beginBlockAdr := memBlockHead.beginBlockAdr;
		endBlockAdr := memBlockHead.endBlockAdr;
		freeBlockAdr := beginBlockAdr;
	END GetStaticHeap;
	
	VAR Last: RECORD END; (* linked to the end *)

	(* returns if an address is a currently allocated heap address *)
	PROCEDURE ValidHeapAddress*( p: ADDRESS ): BOOLEAN;
	VAR mb: MemoryBlock; 
	BEGIN
		IF (p>=Glue.baseAdr) & (p<=Glue.endAdr) THEN RETURN TRUE END;
		mb := memBlockHead;  
		WHILE mb # NIL DO
			IF (p >= mb.beginBlockAdr) & (p <= mb.endBlockAdr) THEN  RETURN TRUE  END;  
			mb := mb.next;  
		END;  
		RETURN FALSE;
	END ValidHeapAddress;
	

	(** Return information on free memory in Kbytes. *)
	PROCEDURE GetFreeK*(VAR total, lowFree, highFree: SIZE);
	BEGIN
		(*! meaningless in Unix port, for interface compatibility only *)
		total := 0;
		lowFree := 0;
		highFree := 0
	END GetFreeK;
	
	

	(** Fill "size" bytes at "destAdr" with "filler". "size" must be multiple of 4. *)
	PROCEDURE  Fill32* (destAdr: ADDRESS; size: SIZE; filler: LONGINT);
	CODE {SYSTEM.AMD64}
		MOV RDI, [RBP + destAdr]
		MOV RCX, [RBP + size]
		MOV EAX, [RBP + filler]
		TEST RCX, 3
		JZ ok
		PUSH 8	; ASSERT failure
		INT 3
	ok:
		SHR RCX, 2
		CLD
		REP STOSD
	END Fill32;

PROCEDURE  Portin8*(port: LONGINT; VAR val: CHAR);
END Portin8;

PROCEDURE  Portin16*(port: LONGINT; VAR val: INTEGER);
END Portin16;

PROCEDURE  Portin32*(port: LONGINT; VAR val: LONGINT);
END Portin32;

PROCEDURE  Portout8*(port: LONGINT; val: CHAR);
END Portout8;

PROCEDURE  Portout16*(port: LONGINT; val: INTEGER);
END Portout16;

PROCEDURE  Portout32*(port: LONGINT; val: LONGINT);
END Portout32;


(** -- Atomic operations -- *)

(** Atomic INC(x). *)
PROCEDURE -AtomicInc*(VAR x: LONGINT);
CODE {SYSTEM.AMD64}
	POP RAX
	LOCK
	INC DWORD [RAX]
END AtomicInc;

(** Atomic DEC(x). *)
PROCEDURE -AtomicDec*(VAR x: LONGINT);
CODE {SYSTEM.AMD64}
	POP RAX
	LOCK
	DEC DWORD [RAX]
END AtomicDec;

(** Atomic INC(x, y). *)
PROCEDURE -AtomicAdd*(VAR x: LONGINT; y: LONGINT);
CODE {SYSTEM.AMD64}
	POP EBX
	POP RAX
	LOCK
	ADD DWORD [RAX], EBX
END AtomicAdd;


(** Atomic EXCL. *)
PROCEDURE AtomicExcl* (VAR s: SET; bit: LONGINT);
CODE {SYSTEM.AMD64}
	MOV EAX, [RBP + bit]
	MOV RBX, [RBP + s]
	LOCK
	BTR [RBX], EAX
END AtomicExcl;


(** Atomic test-and-set. Set x = TRUE and return old value of x. *)
PROCEDURE -AtomicTestSet*(VAR x: BOOLEAN): BOOLEAN;
CODE {SYSTEM.AMD64}
	POP RBX
	MOV AL, 1
	XCHG [RBX], AL
END AtomicTestSet;

(* Atomic compare-and-swap. Set x = new if x = old and return old value of x *)
PROCEDURE  -AtomicCAS* (VAR x: LONGINT; old, new: LONGINT): LONGINT;
CODE {SYSTEM.AMD64}
	POP EBX		; new
	POP EAX		; old
	POP RCX		; address of x
	LOCK CMPXCHG [RCX], EBX	; atomicly compare x with old and set it to new if equal
END AtomicCAS;


(* Return current instruction pointer *)
PROCEDURE  CurrentPC* (): ADDRESS;
CODE {SYSTEM.AMD64}
	MOV RAX, [RBP + 8]
END CurrentPC;

(* Return current frame pointer *)
PROCEDURE  -CurrentBP* (): ADDRESS;
CODE {SYSTEM.AMD64}
	MOV RAX, RBP
END CurrentBP;

(* Set current frame pointer *)
PROCEDURE  -SetBP* (bp: ADDRESS);
CODE {SYSTEM.AMD64}
	POP RBP
END SetBP;

(* Return current stack pointer *)
PROCEDURE  -CurrentSP* (): ADDRESS;
CODE {SYSTEM.AMD64}
	MOV RAX, RSP
END CurrentSP;

(* Set current stack pointer *)
PROCEDURE  -SetSP* (sp: ADDRESS);
CODE {SYSTEM.AMD64}
	POP RSP
END SetSP;

PROCEDURE -GetRAX*(): HUGEINT;
CODE{SYSTEM.AMD64}
END GetRAX;

PROCEDURE -GetRCX*(): HUGEINT;
CODE{SYSTEM.AMD64}
	MOV RAX,RCX
END GetRCX;

PROCEDURE -GetRSI*(): HUGEINT;
CODE{SYSTEM.AMD64}
	MOV RAX,RSI
END GetRSI;

PROCEDURE -GetRDI*(): HUGEINT;
CODE{SYSTEM.AMD64}
	MOV RAX,RDI
END GetRDI;


PROCEDURE -SetRAX*(n: HUGEINT);
CODE{SYSTEM.AMD64}	
	NOP
	POP RAX
END SetRAX;

PROCEDURE -SetRBX*(n: HUGEINT);
CODE{SYSTEM.AMD64}
	NOP
	POP RBX
END SetRBX;

PROCEDURE -SetRCX*(n: HUGEINT);
CODE{SYSTEM.AMD64}
	POP RCX
END SetRCX;

PROCEDURE -SetRDX*(n: HUGEINT);
CODE{SYSTEM.AMD64}
	POP RDX
END SetRDX;

PROCEDURE -SetRSI*(n: HUGEINT);
CODE{SYSTEM.AMD64}
	POP RSI
END SetRSI;

PROCEDURE -SetRDI*(n: HUGEINT);
CODE{SYSTEM.AMD64}
	POP RDI
END SetRDI;


PROCEDURE -GetTimer* (): HUGEINT;
CODE {SYSTEM.AMD64}
	XOR RAX, RAX
	RDTSC	; set EDX:EAX
	SHL RDX, 32
	OR RAX, RDX
END GetTimer;


	(** -- Configuration and bootstrapping -- *)

	(** Return the value of the configuration string specified by parameter name in parameter val. Returns val = "" if the string was not found, or has an empty value. *)
	PROCEDURE GetConfig* (CONST name: ARRAY OF CHAR; VAR val: ARRAY OF CHAR);
	VAR i, src: LONGINT; ch: CHAR;
	BEGIN
		ASSERT (name[0] # "=");	(* no longer supported, use GetInit instead *)
		
		src := -1;  val := "";
		LOOP
			REPEAT
				INC( src );  ch := config[src]; 
				IF ch = 0X THEN EXIT END;
			UNTIL ch > ' ';
			i := 0;
			LOOP
				ch := config[src];
				IF (ch # name[i]) OR (name[i] = 0X) THEN EXIT END;
				INC (i); INC (src)
			END;
			IF (ch <= ' ') & (name[i] = 0X) THEN	(* found *)
				i := 0;
				REPEAT
					INC (src); ch := config[src]; val[i] := ch; INC (i);
					IF i = LEN(val) THEN val[i - 1] := 0X; RETURN END	(* val too short *)
				UNTIL ch <= ' ';
				IF ch = ' ' THEN val[i -1] := 0X END; 
				RETURN
			ELSE
				WHILE ch > ' ' DO	(* skip to end of name *)
					INC (src); ch := config[src]
				END;
				INC (src);
				REPEAT	(* skip to end of value *)
					ch := config[src]; INC (src)
				UNTIL ch <= ' '
			END
		END;
		IF (name = "ObjectFileExtension") & (val = "") THEN  
			val := DefaultObjectFileExtension
		END;
	END GetConfig;


	(** Convert a string to an integer. Parameter i specifies where in the string scanning should begin (usually 0 in the first call). Scanning stops at the first non-valid character, and i returns the updated position. Parameter s is the string to be scanned. The value is returned as result, or 0 if not valid. Syntax: number = ["-"] digit {digit} ["H" | "h"] . digit = "0" | ... "9" | "A" .. "F" | "a" .. "f" . If the number contains any hexdecimal letter, or if it ends in "H" or "h", it is interpreted as hexadecimal. *)
	PROCEDURE StrToInt* (VAR i: LONGINT; CONST s: ARRAY OF CHAR): LONGINT;
	VAR vd, vh, sgn, d: LONGINT; hex: BOOLEAN;
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
	

	(* function returning the number of processors that are available to Aos *)
	PROCEDURE NumberOfProcessors*( ): LONGINT;
	VAR res: LONGINT;
	BEGIN
		res := Unix.getnprocs();
		RETURN res;
	END NumberOfProcessors;

	(*! non portable code, for native Aos only *)
	PROCEDURE SetNumberOfProcessors*( num: LONGINT );
	BEGIN
		(* numberOfProcessors := num; *)
	END SetNumberOfProcessors;

	(* function for changing byte order *)
	PROCEDURE ChangeByteOrder* (n: LONGINT): LONGINT;
	CODE {SYSTEM.AMD64}
		MOV EAX, [RBP + n]				; load n in eax
		BSWAP EAX						; swap byte order
	END ChangeByteOrder;


	(* Send and print character *)
	PROCEDURE TraceChar *(c: CHAR);
	BEGIN
		Trace.Char( c )
	END TraceChar;


	(** CPU identification *)

	PROCEDURE CPUID*( VAR vendor: Vendor;  VAR version: LONGINT;  VAR features1,features2: SET );
	CODE {SYSTEM.AMD64}
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
		MOV	[RSI], ECX
	end:
	END CPUID;
	

	(* If the CPUID instruction is supported, the ID flag (bit 21) of the EFLAGS register is r/w *)
	PROCEDURE CpuIdSupported( ) : BOOLEAN;
	CODE {SYSTEM.AMD64}
		PUSHFQ					; save RFLAGS
		POP RAX				; store RFLAGS in RAX
		MOV EBX, EAX			; save EBX for later testing
		XOR EAX, 00200000H	; toggle bit 21
		PUSH RAX				; push to stack
		POPFQ					; save changed RAX to RFLAGS
		PUSHFQ					; push RFLAGS to TOS
		POP RAX				; store RFLAGS in RAX
		CMP EAX, EBX			; see if bit 21 has changed
		SETNE AL;				; return TRUE if bit 21 has changed, FALSE otherwise
	END CpuIdSupported;

	
	(* setup MMX, SSE and SSE2..SSE5 and AVX extension *)

	PROCEDURE SetupSSE2Ext;
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
	BEGIN
		MMXSupport := MMXFlag IN features;
		SSESupport := SSEFlag IN features;
		SSE2Support := SSESupport & (SSE2Flag IN features);
		SSE3Support := SSE2Support & (SSE3Flag IN features2);
		SSSE3Support := SSE3Support & (SSSE3Flag IN features2); (* PH 04/11*)
		SSE41Support := SSE3Support & (SSE41Flag IN features2);
		SSE42Support := SSE3Support & (SSE42Flag IN features2);
		SSE5Support := SSE3Support & (SSE5Flag IN features2);
		AVXSupport := SSE3Support & (AVXFlag IN features2);

		IF SSESupport & (FXSRFlag IN features) THEN
			(* InitSSE(); *) (*! not privileged mode in Windows and Unix, not allowed *)
		END;
	END SetupSSE2Ext;
	

	(** -- Processor initialization -- *)
	PROCEDURE -SetFCR( s: SET );
	CODE {SYSTEM.AMD64, SYSTEM.FPU}
		FLDCW WORD [RSP]	; parameter s
		POP RAX
	END SetFCR;

	PROCEDURE -FCR( ): SET;
	CODE {SYSTEM.AMD64, SYSTEM.FPU}
		PUSH 0
		FNSTCW WORD [RSP]
		FWAIT
		POP RAX
	END FCR;

	PROCEDURE -InitFPU;
	CODE {SYSTEM.AMD64, SYSTEM.FPU}
		FNINIT
	END InitFPU;

	(** Setup FPU control word of current processor. *)
	PROCEDURE SetupFPU*;
	BEGIN
		InitFPU;  SetFCR( fcr )
	END SetupFPU;


	(* Initialize locks. *)
	PROCEDURE InitLocks;  
	VAR i: LONGINT; 
	BEGIN 
		i := 0;  
		WHILE i < MaxLocks DO  mtx[i] := Unix.NewMtx( );  INC( i )  END;   
	END InitLocks;  

	PROCEDURE CleanupLocks*;  
	VAR i: LONGINT;  
	BEGIN 
		i := 0;  
		WHILE i < MaxLocks DO  Unix.MtxDestroy( mtx[i] );  INC( i ) END;  	
	END CleanupLocks;  
	
	(** Acquire a spin-lock. *)
	PROCEDURE  Acquire*( level: LONGINT );   (* non reentrant lock *)
	BEGIN 
		Unix.MtxLock( mtx[level] );
	END Acquire;  

	(** Release a spin-lock. *)
	PROCEDURE  Release*( level: LONGINT );   
	BEGIN 
		Unix.MtxUnlock( mtx[level] );
	END Release;  
	
	
	PROCEDURE Shutdown*( reboot: BOOLEAN );
	VAR r: LONGINT;  logstat: Unix.Status;
	BEGIN
		r := Unix.fstat( logfile, logstat );
		r := Unix.close( logfile );
		IF logstat.size = 0 THEN  r := Unix.unlink( ADDRESSOF( logname) )  END;
		IF reboot THEN  Unix.exit( 0 )  ELSE  Unix.exit( 1 )  END;
	END Shutdown;
		

		

	(* Set machine-dependent parameter gcThreshold *)
	PROCEDURE SetGCParams*;
	BEGIN
		gcThreshold := 10*1024*1024; (* 10 MB *)
	END SetGCParams;

	(* expand heap by allocating a new memory block - called during GC *)
	PROCEDURE InitHeap(VAR memoryBlock: MemoryBlock; VAR beginBlockAdr, endBlockAdr: ADDRESS);
	CONST MemBlockHeaderSize = BlockHeaderSize + RecordDescSize + BlockHeaderSize;
		TypeDescOffset = -AddressSize; (* see Heaps.Mod *)
		HeapBlockOffset = - 2 * AddressSize; (* see Heaps.Mod *)
		DataAdrOffset = AddressSize; (* offset of dataAdr field in Heaps.HeapBlockDesc *)
	VAR memDescSize, memBlkSize, alignOffset: SIZE; adr, memHeaderAdr, memBlockAdr: ADDRESS;
		memBlock {UNTRACED}: MemoryBlock; size: LONGINT;
		initVal: LONGINT;
	BEGIN

		(*
			HeapBlockPtr -- bootHeapAdr
		8	Type
		16	Mark
		24	DataAdr
		32	Size
		40	HeapBlockPtr
		48	Type
		56	next  -- MemoryBlock
		64	startAdr
		72	size
		80	beginBlockAdr
		88	endBlockAdr
		96		--beginBlockAdr
		....
				--endBlockAdr

		*)
		size := 1;
		memDescSize := MemBlockHeaderSize + SIZEOF(MemoryBlockDesc);
		INC(memDescSize, (-memDescSize) MOD StaticBlockSize); 	(* round up to multiple of StaticBlockSize *)
		INC(size, (-size) MOD StaticBlockSize); (* round up to multiple of StaticBlockSize *)
		memBlkSize := memDescSize + size + StaticBlockSize; 		(* add StaticBlockSize to account for alignments different from multiples of StaticBlockSize *)
		IF memBlkSize < MemBlockSize THEN memBlkSize := MemBlockSize END; 	(* MemBlockSize implicitly multiple of StaticBlockSize *)

		IF Unix.posix_memalign( adr, Unix.PageSize, memBlkSize ) # 0 THEN
			Unix.Perror( "Machine.ExpandHeap: posix_memalign" );
			beginBlockAdr := 0;
			endBlockAdr := 0
		ELSE
			IF Unix.mprotect( adr, memBlkSize, 7 (* READ WRITE EXEC *) ) # 0 THEN
				Unix.Perror( "Machine.ExpandHeap: mprotect" )
			END;
			IF TraceMemBlocks THEN TRACE(adr, memBlkSize) END;
		END;

		IF TraceMemBlocks THEN
			Trace.String("first heap block intVal "); Trace.Int(initVal,1); Trace.Ln;
			Trace.String("first heap block memBlkSize "); Trace.Int(memBlkSize,1); Trace.Ln;
			Trace.String("first heap block adr "); Trace.Int(adr,1); Trace.Ln;
		END;
		ASSERT(adr # 0);

		alignOffset := (-adr) MOD StaticBlockSize;

		memHeaderAdr := adr + alignOffset;  	(* force alignment of memory block start *)
		memBlockAdr := memHeaderAdr + MemBlockHeaderSize;
		memBlock := S.VAL(MemoryBlock, memBlockAdr);
		beginBlockAdr := memHeaderAdr + memDescSize;

		memBlock.next := NIL;
		memBlock.startAdr := adr;
		memBlock.size := memBlkSize;

		beginBlockAdr := memHeaderAdr + memDescSize;
		endBlockAdr := adr + memBlkSize - alignOffset;
		memBlock.beginBlockAdr := beginBlockAdr;
		memBlock.endBlockAdr := endBlockAdr;

		(* correct fields *)
		S.PUT(memBlockAdr + HeapBlockOffset, memHeaderAdr + BlockHeaderSize);	(* set reference to header part of memory block correctly *)
		S.PUT(memBlockAdr + TypeDescOffset, 0);										(* set type descriptor field of memory block to default value, memory blocks are not traced by GC *)
		S.PUT(memHeaderAdr + BlockHeaderSize + DataAdrOffset, memBlockAdr);		(* set dataAdr of RecordBlockDesc to correct value *)
		S.PUT(memHeaderAdr + BlockHeaderSize + 2*AddressSize , memBlkSize);

		(* fill first heap block *)
		S.PUT(beginBlockAdr,0);
		S.PUT(beginBlockAdr+AddressSize,0);
		S.PUT(beginBlockAdr+2*AddressSize,0);
		S.PUT(beginBlockAdr+3*AddressSize,beginBlockAdr+7*AddressSize);
		S.PUT(beginBlockAdr+4*AddressSize,endBlockAdr-beginBlockAdr);
		S.PUT(beginBlockAdr+5*AddressSize,beginBlockAdr+2*AddressSize);
		S.PUT(beginBlockAdr+6*AddressSize,0);

		memoryBlock := memBlock;
	END InitHeap;


	PROCEDURE InitConfig;
	VAR a: ADDRESS;  i: LONGINT;  c: CHAR;
	BEGIN
		a := Unix.getenv( ADDRESSOF( "AOSCONFIG" ) );
		IF a = 0 THEN  config := DefaultConfig
		ELSE
			REPEAT
				S.GET( a, c );  INC( a );  config[i] := c;  INC( i )
			UNTIL c = 0X
		END
	END InitConfig;
	
	
	PROCEDURE UpdateTicks*;
	BEGIN
		ticks := SHORT( (GetTimer() - timer0) DIV (mhz * 1000) );
	END UpdateTicks;
	
	
	PROCEDURE InitThreads;
	VAR res: BOOLEAN; 
	BEGIN
		res := Unix.ThrInitialize( prioLow, prioHigh );
		IF ~res THEN
			Trace.StringLn( "Machine.InitThreads: no threads support in boot environment.  teminating" ); 
			Unix.exit( 1 )
		END;
		IF Glue.debug # {} THEN
			Trace.String( "Threads initialized, priorities low, high: " ); 
			Trace.Int( prioLow, 0 ); Trace.String( ", " ); Trace.Int( prioHigh, 0 );
			Trace.Ln
		END
	END InitThreads;
	
	PROCEDURE CPUSpeed;
	VAR t0, t1: HUGEINT; 
	BEGIN
		t0 := GetTimer();  Unix.ThrSleep( 100 );  t1 := GetTimer();
		mhz := (t1 - t0) DIV 100000;
		IF Glue.debug # {} THEN
			Trace.String( "CPU speed: ~" );  Trace.Int( SHORT( mhz ), 0);  Trace.String( " MHz" );  Trace.Ln
		END
	END CPUSpeed;
	
	PROCEDURE Log( c: CHAR );
	VAR ignore: LONGINT;
	BEGIN
		ignore := Unix.write( 1, ADDRESSOF( c ), 1 );
		ignore := Unix.write( logfile, ADDRESSOF( c ), 1 );
	END Log;
	
	PROCEDURE LogFileOnly( c: CHAR );
	VAR ignore: LONGINT;
	BEGIN
		ignore := Unix.write( logfile, ADDRESSOF( c ), 1 );
	END LogFileOnly;
	
	
	PROCEDURE InitLog;
	VAR pid, i: LONGINT; 
	BEGIN
		logname := "AOS.xxxxx.Log";
		pid := Unix.getpid();  i := 8;
		REPEAT
			logname[i] := CHR( pid MOD 10 + ORD( '0' ) );  DEC( i );
			pid := pid DIV 10;		
		UNTIL i = 3;
		logfile := Unix.open( ADDRESSOF( logname ), Unix.rdwr + Unix.creat + Unix.trunc, Unix.rwrwr );
		VerboseLog;	
	END InitLog;
	
	PROCEDURE SilentLog*;
	BEGIN
		Trace.Char := LogFileOnly
	END SilentLog;
	
	PROCEDURE VerboseLog*;
	BEGIN
		Trace.Char := Log
	END VerboseLog;

	
	PROCEDURE Append( VAR a: ARRAY OF CHAR; CONST this: ARRAY OF CHAR );
	VAR i, j: LONGINT;
	BEGIN
		i := 0;  j := 0;  
		WHILE a[i] # 0X DO  INC( i )  END;
		WHILE (i < LEN( a ) - 1) & (this[j] # 0X) DO a[i] := this[j];  INC( i );  INC( j )  END;
		a[i] := 0X
	END Append;
	

	PROCEDURE Init;
	VAR vendor: Vendor; ver: LONGINT;
	BEGIN		
		COPY( Unix.Version, version );  Append( version, Version ); Append(version, S.Date);
		
		timer0 := GetTimer( );  ticks := 0;
		InitThreads;
		InitLocks;
		traceHeap := 1 IN Glue.debug;
		InitConfig;
		InitLog;
		CPUSpeed;
		IF CpuIdSupported() THEN
			CPUID( vendor, ver, features, features2 );	 SetupSSE2Ext
		END;
		fcr := (FCR() - {0,2,3,10,11}) + {0..5,8,9};	(* default FCR RC=00B *)
	END Init;

	PROCEDURE {INITIAL} Init0;
	BEGIN
		Init;
	END Init0;
	
END Machine.

(*
03.03.1998	pjm	First version
30.06.1999	pjm	ProcessorID moved to AosProcessor
*)

(**
Notes

This module defines an interface to the boot environment of the system. The facilities provided here are only intended for the lowest levels of the system, and should never be directly imported by user modules (exceptions are noted below). They are highly specific to the system hardware and firmware architecture.

Typically a machine has some type of firmware that performs initial testing and setup of the system. The firmware initiates the operating system bootstrap loader, which loads the boot file. This module is the first module in the statically linked boot file that gets control.

There are two more-or-less general procedures in this module: GetConfig and StrToInt. GetConfig is used to query low-level system settings, e.g., the location of the boot file system. StrToInt is a utility procedure that parses numeric strings.

Config strings:

ExtMemSize	Specifies size of extended memory (above 1MB) in MB. This value is not checked for validity. Setting it false may cause the system to fail, possible after running for some time. The memory size is usually detected automatically, but if the detection does not work for some reason, or if you want to limit the amount of memory detected, this string can be set. For example, if the machine has 64MB of memory, this value can be set as ExtMemSize="63".
*)

